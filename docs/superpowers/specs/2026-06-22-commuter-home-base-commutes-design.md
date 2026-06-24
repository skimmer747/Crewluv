# Commute Events for Home ≠ Base Commuters — Design

**Date:** 2026-06-22
**Status:** Approved design, pending implementation plan
**Scope:** Cross-repo — Duty (pilot app) and Crewluv (partner app), sibling repos sharing the `SharedPilotStatus` / `TripLeg` schema.

---

## 1. Summary

Pilots whose **home airport differs from their base** drive (or otherwise commute by ground) between their base and home around trips. Today they can create a manual "Driving home" event with a single location (e.g. MCO), which works *one way* because the partner only needs one anchor: "arrives home at X." The **return** drive is broken: a single-location event can't express *leaving* home and *arriving* at base to start a trip, so the partner either sees the pilot pinned at home or jumped to base — never "on the road, trip starts at X."

This feature adds a first-class **Commute** (a ground `from → to` leg with its own departure and arrival times) for both directions, surfaced and managed **only** inside Duty's **Partner Sharing** screen as a suggest-and-confirm flow. The partner sees an accurate **two-phase** display: a "heads to work in X" countdown while still home, then an on-the-road "back at SDF in X" view with a 🏠→🚗→🛫 progress timeline — and the mirror image (🛬→🚗→🏠) for the drive home.

## 2. Problem

- `ManualEvent` (Duty) has a single `location`. It cannot represent origin **and** destination, so the return-to-work commute has no way to say "left home (MCO), arriving base (SDF) at report time."
- There is **no** existing "driving to work" / outbound concept anywhere in either app. Duty's `isCommutingHome()` is inbound-only, jumpseat-only, and only fires when the pilot is already home (no current trip).
- Result: the partner can't tell when the pilot has left home or when the next trip actually begins.

## 3. Goals (v1) & Non-goals

**Goals**
- Let a commuter pilot add a `from → to` ground drive between trips, in **both** directions.
- Detect qualifying gaps and **suggest** commutes; never create or share anything silently.
- Show the partner an accurate two-phase status with correct timing for each direction.
- Reuse the existing CloudKit beacon — no new top-level CKRecord fields; the commute rides inside the existing `tripLegsJSON` blob as a new leg type.
- Degrade safely on older app versions (an unknown leg type never crashes the partner app).

**Non-goals (v1)**
- Non-base-anchored drives (trip ending/starting somewhere other than base). Base-anchored only.
- Transport modes other than driving (no "ride," "train," etc.) — modeled so a mode can be added later.
- Re-querying drive ETA for live traffic (drive time is fixed once confirmed).
- Multi-pilot-per-zone sharing (pre-existing single-pilot assumption is unchanged).
- Syncing the remembered per-route durations across devices (local app-group defaults for v1).

## 4. Locked product decisions

| Decision | Choice |
|---|---|
| Where it lives | A **Commutes** section inside Duty's **Partner Sharing** screen. No banner, no schedule-screen surfacing. |
| Creation model | **Suggest-and-confirm.** App proposes pre-filled commutes; pilot reviews/edits/confirms. Never silent. |
| Drive-time source | **Default 2 h**, editable, then **remembered per route**; **fixed** once confirmed. (No MapKit in v1 — auto-estimate may come later, §17.) |
| Eligibility gate | `effectiveHomeAirportCode != base`; gap **> 24 h**; trip endpoint **is base**; not already covered by a jumpseat or an existing managed commute. |
| Status modeling | **Dedicated statuses**: `Driving Home` and `Driving to Work`. |
| Existing manual "Driving home" | **Offer to convert** the manual event into a managed Commute; never double-emit for the same window. |

## 5. Architecture overview

```
Duty (pilot device)                                  Crewluv (partner device)
─────────────────────                                ────────────────────────
Commute (@Model, SwiftData)                          TripLeg(.drive) ─┐
   ▲ create/edit via Partner Sharing                                  │
CommuteSuggestionEngine ── gates/de-dup               PilotDisplayStatus
CommuteRouteStore (defaults) ── default 2 h,             .drivingHome / .drivingToWork
   remember per route                                 TripStateResolver  ── two-phase
   │                                                  NarrativeCardView / TimelineRow /
PartnerStatusGenerator                                   SunCircleView / CalendarDataBuilder
   ├─ buildTripLegsJSON → TripLeg(.drive)  ───────►  (decode tripLegsJSON)
   └─ displayStatus = "Driving Home"/"Driving to Work"  ───► rawDisplayString bridge
        │
PilotStatusBeaconManager → CloudKit (PartnerBeaconZone, record "pilot-status")
```

The commute is **carried by the leg** (`type=.drive`, `departureAirport`, `arrivalAirport`, `startTime`/`endTime`, direction-specific `label`). Crewluv derives narrative, icon, and countdowns from the **leg fields**, with the dedicated `displayStatus` string as a corroborating signal — not the sole source of truth. This is what lets a drive be distinguished from a jumpseat and lets both directions and both phases render correctly.

## 6. Data model (Duty)

### 6.1 `Commute` (new `@Model`)

```swift
@Model final class Commute: Syncable {   // Syncable = Supabase-readiness; mirror an existing model (e.g. Jumpseat)
    @Attribute(.unique) var id: String = UUID().uuidString
    var fromAirport: String = ""          // IATA — base for toHome, home for toWork
    var toAirport: String = ""            // IATA — home for toHome, base for toWork
    var directionRaw: String = CommuteDirection.toHome.rawValue   // "toHome" | "toWork"
    var departureTimeZulu: Date = Date()
    var arrivalTimeZulu: Date = Date()    // always > departureTimeZulu
    var driveDurationSeconds: TimeInterval = 0
    var sourceTripId: String? = nil       // the trip this commute brackets (for cleanup)
    var hiddenFromTimeline: Bool = false
    var createdAt: Date = Date()

    // Syncable conformance — copy field names/types from an existing synced model verbatim
    var syncID: String = UUID().uuidString
    var syncLastModified: Date = Date()
    var needsPush: Bool = false
    var deletedAt: Date? = nil            // soft-delete, matching Jumpseat

    var direction: CommuteDirection { CommuteDirection(rawValue: directionRaw) ?? .toHome }
}
enum CommuteDirection: String, Codable, Sendable { case toHome, toWork }
```

- **Every field optional or defaulted** → SwiftData lightweight migration cannot block launch.
- Conforms to **`Syncable`** (`syncID`, `syncLastModified`, `needsPush`, `deletedAt`) **exactly as `Jumpseat` does** — this is **required by the live Supabase backend** (§6.3), not optional. Verified by the existing `SyncableConformanceTests` (a non-conforming model compiles but crashes at `ModelContainer` init). See §6.3 for what syncs where.
- Standalone (not a `@Relationship` child of `Trip`); lifecycle managed by a cleanup service keyed on `sourceTripId`.

### 6.3 Sync surfaces — what changes where

Duty runs **two live data backends**, chosen per-pilot via `SyncBackendMode`: `.icloud` (default for new users) and `.supabase` (opt-in migration; **~30% of pilots are already on it**). A pilot creating a commute may be on **either**, so `Commute` must persist under both. The partner beacon is a third, independent surface.

**A. Partner beacon — CloudKit for 100% of pilots, no schema change.**
`SharedPilotStatus` → the `pilot-status` record in `PartnerBeaconZone` is written by `PilotStatusBeaconManager`, which uses a dedicated `CKContainer("iCloud.com.toddanderson.duty")` initialized **unconditionally, independent of `SyncBackendMode`** (enforced by the existing `PartnerBeaconModeIndependenceTests` no-regress contract). So even Supabase-backend pilots beacon to CloudKit, and Crewluv (CloudKit-only) keeps working for everyone. The commute rides inside the **existing** `tripLegsJSON` (Data) and `displayStatus` (String) fields — new *content*, **not** new CKRecord fields. **No beacon schema change, no backend provisioning** for the partner-facing payload. *(Verified against the live DB: Supabase has no partner/status/beacon table — only the 16 model tables + `profiles`.)*

**B. `.icloud`-backend pilots — CloudKit SwiftData mirror (new record type).**
The local SwiftData store is CloudKit-mirrored (`ModelConfiguration(cloudKitDatabase: .automatic)`) when `SyncBackendMode == .icloud`. Adding `Commute` to `SyncSchema.allModels` creates a new mirrored record type (`CD_Commute`). Auto-created in **development**; **must be deployed to CloudKit *production*** (Dashboard → Deploy Schema Changes) before the Duty release. All fields optional/defaulted → safe lightweight migration. Crewluv never sees this type.

**C. `.supabase`-backend pilots — new `commutes` table + DTO + engine registration.**
When `SyncBackendMode == .supabase` the CloudKit mirror is off and `SupabaseSyncEngine` pulls/pushes via PostgREST. `Commute` therefore needs, mirroring the **live `jumpseats` conventions** (verified):
- a **`commutes` Postgres table**: `id text` PK (app-generated), `user_id uuid NOT NULL`, snake_case domain columns (`from_airport`, `to_airport`, `direction`, `departure_time_zulu timestamptz`, `arrival_time_zulu timestamptz`, `drive_duration_seconds double precision`, `source_trip_id text`, `hidden_from_timeline boolean`, `created_at timestamptz`), `deleted_at timestamptz`, and `updated_at timestamptz NOT NULL DEFAULT now()` (the sync cursor);
- RLS policy `commutes_owner FOR ALL USING ((SELECT auth.uid()) = user_id) WITH CHECK (same)` — identical to `jumpseats_owner`;
- the **same `updated_at` cursor mechanism `jumpseats` uses** — replicate it exactly. (The MCP role saw no triggers and no tracked migrations, so the planner must confirm the real cursor/trigger setup against `jumpseats` with full privileges, and apply the schema via the team's actual process — dashboard SQL vs. a migrations folder.)
- a `CommuteRow: SyncableRow` DTO mapping model ↔ `commutes` columns (snake_case, ISO-8601 dates), mirroring `JumpseatRow`;
- registration in `SupabaseSyncEngine` — add `"commutes"` to `tableOrder` (root table, no FK children) and a pull + push call.

**There are two model registries, not one:** `SyncSchema.allModels` (CloudKit mirror) **and** `SupabaseSyncEngine`'s `tableOrder`/pull/push (Supabase). Miss either and that backend's pilots silently fail to sync commutes across their own devices. `Commute`'s `Syncable` conformance (`syncID`, `syncLastModified`, `needsPush`, `deletedAt`) is **required** by the Supabase path, not optional polish.

### 6.2 `CommuteRouteStore` (new)

- Remembers drive duration per `(fromAirport, toAirport)` route.
- Backed by **`SharedUserDefaults.shared`** (app group `group.com.ToddAnderson.Duty`), key prefix `commuteRoutes.duration.<FROM>-<TO>`. Must use the shared defaults (not `UserDefaults.standard`) for watch/widget parity.
- First use of a route → **default 2 h**; on confirm with an adjusted duration → overwrite. (A future version may seed this from a MapKit estimate.)

## 7. Detection & suggestion engine (Duty)

`CommuteSuggestionEngine` (new, under `Utils/PartnerBeacon/`). Pure read → returns suggestions; never writes.

**Gates (all must hold):**
1. `effectiveHomeAirportCode != base`.
2. A gap **> 24 h** between consecutive trips — in Duty, trips are discrete `Trip` records, so the gap is `nextTrip.startDate − prevTrip.endDate`. (24 h is a single tunable constant.)
3. **Base-anchored endpoint:** `toHome` only after a trip whose `endingAirport == base`; `toWork` only before a trip whose `startingAirport == base`.
4. **Not already covered:** no standalone jumpseat (`sourceTripId == nil`, not hidden) bridging the gap toward home (`toHome`) or from home (`toWork`); and no existing managed Commute for the gap.

**Output:** up to two suggestions per gap — a `toHome` after arrival at base, a `toWork` before the next departure. Suggestions are keyed on `(sourceTripId, direction, fromAirport, toAirport)` so repeated 2-minute refreshes surface the **same** suggestion (idempotent, never duplicated).

**Existing manual "Driving home" handling (convert):** if the gap already contains a `ManualEvent` whose title matches `driv`/`car`/`truck`, the engine does **not** offer a fresh suggestion; instead it offers **convert-to-Commute** (carry over location → set as the drive's destination, add the matching return drive). A confirmed Commute and a manual event are **never** both emitted for the same window.

## 8. Drive-time defaults (Duty)

No MapKit/network dependency in v1. Drive duration is a plain, editable value:

- **Default 2 h** for any new commute (`driveDurationSeconds = 7200`).
- `CommuteRouteStore` remembers the pilot's adjusted duration per `(fromAirport, toAirport)` route; the next commute on that route pre-fills the remembered value instead of 2 h.
- **Fixed once confirmed** — no live re-query. The add/edit sheet exposes the duration for manual override at any time.
- `arrivalTimeZulu = departureTimeZulu + driveDurationSeconds`. **Never persist** a Commute with `arrivalTime <= departureTime`.
- Display-time zones come from `TripParser`'s curated map (UTC fallback for uncovered airports, acceptable since base/home are typically curated). No new permissions or capabilities are added.

(An automatic estimate via MapKit `MKDirections` is deferred — see §17.)

## 9. Status, phases & wire format

### 9.1 New leg type — `.drive`

Add `case drive` to `TripLeg.LegType` in **both** repos, identical placement (after `base`, before `reserve`). Decoder unchanged — the existing unknown-raw-value fallback means an old build that doesn't know `.drive` decodes it to `.unknown` (safe, no crash; just not rendered specially).

### 9.2 Dedicated statuses (Crewluv `PilotDisplayStatus`)

Add `case drivingHome` (`"Driving Home"`) and `case drivingToWork` (`"Driving to Work"`). Duty emits these strings in `displayStatus`. New strings decode unknown-safe on older Crewluv builds.

### 9.3 Phase timeline (what the partner sees)

**Drive home** — trip ends at base, pilot drives base → home:
- After landing, before drive departs → status **Base**, "back home in X" (counts to drive **arrival**; `homeArrivalTime` = `commute.arrivalTimeZulu`).
- `departure ≤ now < arrival` → status **Driving Home**, "driving home — back at <home> in X", timeline 🛬→🚗→🏠.
- After arrival → status **Home**.

**Drive to work** — pilot drives home → base, trip starts at base:
- Still home, before drive departs → status **Home**, "heads to work in X" (counts to drive **departure**) + "drives to <base>, trip starts <time>". (`nextDepartureTime`/`nextDepartureLabel` set from the drive.)
- `departure ≤ now < arrival` → status **Driving to Work**, "driving to work — at <base> in X", timeline 🏠→🚗→🛫.
- After arrival, before report → status **Base**, "at base, trip starts in X".

## 10. Partner display (Crewluv)

Render from the active/upcoming `.drive` leg + corroborating status. Drive copy uses `status.homeArrivalTime` (drive home) and the upcoming drive leg's departure (drive to work). Icon: `car.fill` (reuse `eventIconOverride` car detection). Sun dial and timeline must render the drive leg sensibly rather than as a generic gray clock.

## 11. Duty UI — Partner Sharing "Commutes" section

- New `Section` after `partnersSection`, inside the `if beaconManager.isSharing` guard, **additionally gated on `home != base`** (hidden entirely for non-commuters).
- `@Query(filter: #Predicate<Commute> { $0.deletedAt == nil })` for saved commutes; `ForEach` rows show `from → to`, phase/direction label, and ETA, with swipe-to-delete (sets `deletedAt`).
- A pending-suggestions row from `CommuteSuggestionEngine` with **Confirm / Dismiss** (and **Convert** for matched manual events); a `+` to add manually.
- `AddCommuteSheet` / `EditCommuteSheet` (new): airport pickers seeded to base/home, **UTC** time pickers (env `timeZone` GMT 0), validate `from != to`, a **drive-duration field defaulting to the remembered route value or 2 h** (fully editable), local display strings via `TripParser` + `DateFormatter`. On save: insert/update `Commute`, refresh `CommuteRouteStore`.

## 12. Cross-repo change plan (per file)

### Duty
1. `Duty/Models/Commute.swift` **(new)** — the `@Model` + `CommuteDirection` (§6.1).
2. `Duty/Utils/CommuteRouteStore.swift` **(new)** — remembered durations in shared defaults; **default 2 h** on first use (§6.2).
3. `Duty/Utils/PartnerBeacon/CommuteSuggestionEngine.swift` **(new)** — gates, de-dup, convert (§7).
4. `Duty/Utils/Sync/SyncSchema.swift` — append `Commute.self` to `allModels` (the **CloudKit-mirror** registry; the Supabase registry is separate — item 12).
5. `Duty/Models/TripLeg.swift` — add `case drive` (byte-identical to Crewluv).
6. `Duty/Utils/PartnerBeacon/PartnerStatusGenerator.swift` —
   - `buildTripLegsJSON`: fetch active/relevant Commutes (`deletedAt == nil`, not hidden, within the existing time window) → append `TripLeg(type: .drive, …)` with cities (AirportDataProvider), tz (TripParser), direction label.
   - Override cascade: detect an active/imminent Commute and set `displayStatus` to `Driving Home`/`Driving to Work` **before** the base-between-trips override; tighten the base override so it does not fire when a `toHome` commute is active/upcoming.
   - `homeArrivalTime`: prefer `commute.arrivalTimeZulu` when a `toHome` commute follows the homeward flight; set `nextDeparture*` from a `toWork` commute.
7. `Duty/ViewModels/HiddenEventsManager.swift` — add `Commute` to `deriveSet()` (`commute_<id>`), `isCommuteHidden(_:in:)`, and `applyHidden()` for the `commute_` prefix.
8. `Duty/Views/Settings/PartnerSharingView.swift` — the Commutes section (§11).
9. `Duty/Views/Settings/AddCommuteSheet.swift` + `EditCommuteSheet.swift` **(new)**.
10. Cleanup service (e.g. alongside existing post-launch cleanups) — soft-delete Commutes whose `sourceTripId` references a soft-deleted/absent trip.
11. `Duty/Utils/Sync/DTO/CommuteRow.swift` **(new)** — `SyncableRow` mapping `Commute` ↔ the `commutes` table (snake_case columns, ISO-8601 dates); mirror `JumpseatRow`.
12. `Duty/Utils/Sync/SupabaseSyncEngine.swift` — register `commutes`: add `"commutes"` to `tableOrder` (root table, no FK children) + a pull and a push call. (The **Supabase** registry — separate from `SyncSchema.allModels`, item 4.)
13. **Supabase DB** — create the `commutes` table + `commutes_owner` RLS + the `updated_at` cursor mechanism, mirroring `jumpseats` exactly (§6.3); apply via the team's schema process.

### Crewluv
14. `Crewluv/Models/TripLeg.swift` — add `case drive` (identical placement).
15. `Crewluv/Models/PilotDisplayStatus.swift` — add `.drivingHome` / `.drivingToWork` + `rawDisplayString` mappings (unknown-safe).
16. `Crewluv/Models/TripStateResolver.swift` —
    - `displayStatus(for:)` — `case .drive:` (compile-forced).
    - `resolveHomeArrival()` — include `.drive` legs whose `arrivalAirport == home` (currently `.flight`/`.event` only) so "Back Home In" tracks the drive home.
    - `resolveGap()` — explicit `.drive` handling: completed drive sets location to its arrival airport/city and returns `.home`/`.base` instead of falling through to `.turn`.
    - Confirm `.drive` is selectable as the primary ground leg so the phase-2 countdown uses the drive `endTime`.
17. `Crewluv/Views/Status/NarrativeCardView.swift` — `commutingHomeNarrative` drive branch (active `.drive`, no next flight → drive copy via `homeArrivalTime`); add `.drivingHome`/`.drivingToWork` to `narrativeText`/`statusIcon`(`car.fill`)/`statusColor`; phase-1 "heads to work in X" from a future drive leg.
18. `Crewluv/Views/Schedule/TimelineRowView.swift` — explicit `.drive` cases for `staticIconName` (`car.fill`), `iconColor`, `title` (`leg.label ?? "Driving"`). **Default branch — no compile error; hand-audit.**
19. `Crewluv/Models/CalendarDataBuilder.swift` — explicit `.drive` case (currently `default: .onDuty`). **No compile error; hand-audit.**
20. `Crewluv/Models/SharedPilotStatus.swift` — `adjustLayoversForOverlappingFlights`: **exclude** `.drive` from overlap detection (a base↔home drive lives in a >24h gap, not inside a layover); document the decision.

### Both — tests (§15).

## 13. Break register & safeguards

| What could break | Likelihood | Mitigation |
|---|---|---|
| Version skew: new Duty emits `.drive` to old Crewluv → decodes `.unknown`, renders as gray clock, excluded from "Back Home In." | High | **Ship Crewluv `.drive` support first or simultaneously.** `.unknown` fallback guarantees no crash. Tie the two builds in release notes. |
| SwiftData migration on adding `Commute` blocks launch / breaks CloudKit sync if a field is required-without-default. | Medium | **Every field optional/defaulted** (lightweight migration). Verify `Syncable` via `SyncableConformanceTests`. Defer any backfill to existing post-launch pattern. |
| Duty's new `CD_Commute` CloudKit record type **not deployed to production** before the Duty release → production sync rejects the new model for `.icloud` App Store users. | Medium | Deploy schema changes in the CloudKit Dashboard (or via Xcode with container write access) as a hard release gate; verify in the **production** environment. The partner-beacon path is unaffected (no schema change). |
| `commutes` Supabase table / RLS missing or wrong in production → push 401/permission errors for the **~30% `.supabase`** pilots; their commutes silently never sync. | High | Create the `commutes` table + `commutes_owner` RLS mirroring `jumpseats` **before** the Duty release; verify with a `.supabase` test account. RLS must restrict to `auth.uid() = user_id`. |
| `Commute` registered in only **one** sync registry (`SyncSchema.allModels` *or* `SupabaseSyncEngine`, not both) → commutes don't sync for whichever backend was missed. | High | Register in **both**; add a test that exercises `Commute` round-trip under both `SyncBackendMode` values. |
| `displayStatus` collision (drive vs jumpseat "Commuting Home"). | High (avoided) | Dedicated `Driving Home`/`Driving to Work` statuses + render from leg fields, not status string alone. |
| Manual "Driving home" collides → double timeline entries / status masking (`activeManualEventStatus` runs first). | High | Suggestion engine detects manual driving events and offers convert/suppress; never double-emit. Document precedence. |
| Five default-bearing Crewluv switches silently misrender `.drive` (TimelineRowView, CalendarDataBuilder, `adjustLayovers`, `resolveGap`, `resolveHomeArrival`). | High | Enumerate all five in the PR checklist; hand-audit + a unit test per site. |
| Garbage drive duration (e.g. zero) → `arrival <= departure` → broken countdown. | Low | Validate in the editor and on save; **never persist** a Commute with `arrival <= departure`; default 2 h guarantees a positive duration. |
| Trip soft-delete orphans Commutes that keep appearing. | Medium | Cleanup service soft-deletes Commutes whose `sourceTripId` is deleted/absent. |
| HiddenEventsManager cache lacks `commute_` entries until first save. | Low | `deriveSet` runs on every save; new commutes start visible (correct); all hide/unhide on MainActor. |
| Fixed CloudKit record name `pilot-status` in multi-pilot zones. | Low | Pre-existing single-pilot assumption; commute rides the same record, inherits not worsens. Flag only if multi-pilot is introduced. |

## 14. Edge cases

- **Re-sync idempotency:** suggestions keyed on `(sourceTripId, direction, from, to)`; confirmed commutes are persisted, `tripLegsJSON` is a pure projection → stable across refreshes.
- **Overlapping jumpseat:** hard gate at suggestion time; if a jumpseat is added after confirmation, `homeArrivalTime` prefers whichever arrives earlier; timeline may show both but only one drives the countdown.
- **Trip not ending/starting at base:** no suggestion (base-anchored only).
- **Time zone / DST:** store absolute UTC; `arrival = departure + driveDurationSeconds` (DST-safe); display per-endpoint via `TripParser`.
- **Deleting a trip with an attached commute:** cleanup soft-deletes it; filtered from `buildTripLegsJSON` and `@Query` → vanishes from Duty UI and partner timeline next sync.
- **Existing manual "Driving home":** detect by keyword → offer convert; never both.
- **Completed drive in a gap:** `resolveGap` sets location to arrival airport, returns `.base`/`.home`.
- **Drive scheduled, not started (phase 1):** `now < departure` → still Home + "heads to work in X."
- **`home == base`:** inert everywhere (section hidden, engine returns nothing, no creation).
- **Gap < 24h:** no suggestion (too short to be worth a base↔home drive; the pilot stays near base).
- **Old Crewluv receives `.drive`:** `.unknown` fallback, degraded but no crash.

## 15. Testing

- `SyncableConformanceTests` covers `Commute`.
- Round-trip: a `.drive` `TripLeg` encodes/decodes; an old-build decode → `.unknown`.
- `TripStateResolver`: drive-home countdown; drive-to-work; completed-drive gap resolution; overlapping-jumpseat suppression.
- `CommuteSuggestionEngine` gates: `home == base` → none; `< 24h` gap → none; jumpseat-covered → none; manual-driving-event present → convert/suppress; idempotent re-run → same suggestion.
- `CommuteRouteStore`: default 2 h on first use of a route; remembers an adjusted duration and pre-fills it next time.
- Save-path guard: a Commute is never persisted with `arrival <= departure`.
- A unit test per default-bearing Crewluv site asserting drive-specific output.
- **Dual-backend:** `Commute` round-trips under `SyncBackendMode.icloud` (CloudKit mirror) **and** `.supabase` (`CommuteRow` ↔ `commutes` upsert/pull); confirm it's registered in both `SyncSchema.allModels` and `SupabaseSyncEngine`.
- **Beacon independence:** the commute appears on the CloudKit beacon under **both** backend modes (extend `PartnerBeaconModeIndependenceTests`).

## 16. Release sequencing

1. Ship **Crewluv** with full `.drive` support (all sites in §12, items 14–20) — it harmlessly ignores drives until Duty sends them. (No CloudKit schema change in Crewluv; works for all pilots via the CloudKit beacon.)
2. **Provision Duty's backend schema before the Duty release** — (a) deploy the `CD_Commute` record type to CloudKit **production** (for `.icloud` pilots); (b) create the `commutes` table + `commutes_owner` RLS in **Supabase** (for the ~30% `.supabase` pilots), mirroring `jumpseats` (§6.3). The partner beacon needs no schema change.
3. Then (after step 2) ship **Duty** with the `Commute` model, both sync registrations, suggestion engine, UI, and `.drive` emission.
4. Release notes (both apps, per the user's Apple Notes workflow) note the paired update.

## 17. Open items / future (not v1)

- **Automatic drive-time estimate via MapKit `MKDirections`** (replacing the fixed 2 h default), including live-traffic re-query near departure.
- Sync remembered route durations across devices.
- Non-base-anchored commutes (trip ends/starts off-base).
- Additional transport modes (ride/train) via a `mode` on `Commute` + new leg subtype or label.

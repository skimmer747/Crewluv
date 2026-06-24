# Commute Feature — RESUME / Handoff

**Last updated:** 2026-06-23. Read this first when resuming. It is the single source of truth for picking up the cross-repo "commute (base↔home drive)" feature.

## ⏩ ACTIVE — RESUME HERE (2026-06-23 display polish + countdown)

Stages 1–3c DONE + committed; prod provisioning (CloudKit `CD_Commute` + Supabase `commutes`) DONE. This block = **post-release on-device polish in the Duty repo, ALL UNCOMMITTED** (per rule #1, get per-commit user approval; the user has been verifying in Xcode/device each step).

**Done this session (uncommitted, Duty repo):**
- **Theme colors + date on commute times.** `Duty/Views/Settings/CommuteSheet.swift` (Zulu = `colorScheme == .dark ? .yellow : .blue`; local = `.primary`; new reusable `struct CommuteTimeText`), `Duty/Views/Settings/PartnerSharingView.swift` (rows show date + departure-airport-local time). ⚠️ "day and night" meant **light/dark MODE**, not airport sunrise/sunset — an earlier astronomical `SolarTime` util was WRONG, was **deleted**, and `FlightTimezoneInfoView` was reverted to HEAD.
- **Commutes in the under-calendar scrolling EVENT timeline** (NOT the `TripListView` ListItem row list — user was explicit it must be the event timeline). A commute is a **timeline-only `EventTimelineItem`**: `Duty/Views/Timeline/EventTimelineView.swift` (`case commute(Commute)` on the enum + id/date/endDate/stationCode arms + a `FetchDescriptor<Commute>(deletedAt==nil)` append inside `EventTimelineItem.from(...)`), `Duty/Views/Timeline/TimelineRowView.swift` (renders car.fill icon, `.cyan` accent [user to confirm color], "Driving home/to work", `FROM → TO`, UTC+local times — 9 `switch item` blocks all handle `.commute`), `Duty/ViewModels/EventTimelineFilter.swift` (`.commute` always matches), `Duty/Views/Trip/TripListView.swift` (`.commute` arms on its 6 `EventTimelineItem` switches; widget + watch INCLUDE commute; **countdown EXCLUDES it** — see NEXT TASK).
  - Exhaustiveness markers: an `EventTimelineItem` switch has BOTH `.vanTime` AND `.bidEvent` arms; a `ListItem` switch has `.incompleteTrip`. Verify new cases by reading every such switch (grouped `case a, b, .commute:` arms don't match a `grep "case \.commute"`).
- **Supabase 42P10 fix — ✅ APPLIED to prod 2026-06-23** (verified `commutes_user_id_id_key UNIQUE (user_id, id)` exists on `public.commutes`, project `corxvurxpnrzekbxdgye`). The engine upserts `onConflict: "user_id,id"` but the table only had PK on `id` → 42P10, commutes never synced. Fixed by adding the composite unique; the migration file `supabase/migrations/20260622170000_commutes_table.sql` is also updated for fresh environments. (SQL run, for the record: `alter table public.commutes add constraint commutes_user_id_id_key unique (user_id, id);`)

**NEXT TASK — ✅ DONE + COMMITTED `5240cf03`** (Duty branch `feature/supabase-account-backend`, **unpushed**). Added commutes to the **in-app countdown** so watch + widget + countdown all agree. All in `Duty/Views/Trip/TripListView.swift` (+84/−3):
1. `NextDepartureItem` enum gained `case commute(Commute)`; a `.commute` arm was added to **all 9** switches over it — `computeDescription` ("Driving home/to work — FROM → TO"), `getTargetTime` (`departureTimeZulu`), `updateHighlightedJumpseat` (nil — no row to highlight), the **three** switches in `updateCountdownIfNeeded` (active-ids cleared like vanTime / watch payload "Drive" FROM→TO / StandBy widget eventType `.manualEvent`), `scrollToNextItem`, and **both** switches in `CountdownHeaderView.formatCountdown` (`departureTime` + `baseColor` = `.cyan`).
2. `findNextDeparture` mapping: `.commute(let c)` → `return .commute(c)` (was nil).
3. `timerTarget(for:)`: `.commute(let c)` → `guard !isEventHidden("commute_\(c.id)")`, `guard c.departureTimeZulu > now`, `return c.departureTimeZulu` (was nil).
4. **Exhaustiveness sweep caught two switches not in the original task list** — `updateHighlightedJumpseat` (~L1539) and `formatCountdown` (~L4446); missing either would be a compile error.
5. `scrollToNextItem` `.commute` arm scrolls to `commute.sourceTripId` (guarded by `trips.contains`) — NOT a dead `"commute_…"` anchor (commutes have no row in the iPhone `ListItem` List), mirroring the vanTime fallback. (Caught by spec review.)

Verified via 3-lens adversarial review (compile / spec / quality — all PASS; one minor scroll-anchor fix applied; two nits declined with reasons: `→` and `.cyan` are the canonical commute conventions). **Not built by Claude** (rule #5) — no unit test covers this view-layer path; the existing `Commute*` suites are unaffected.

**COMMITTED `5240cf03`** (2026-06-23) = the whole commute display-polish set, 7 files, +214/−29: `EventTimelineFilter.swift`, `CommuteSheet.swift`, `PartnerSharingView.swift`, `EventTimelineView.swift`, `TimelineRowView.swift`, `TripListView.swift`, `supabase/migrations/20260622170000_commutes_table.sql`. User WIP (`PilotStatusBeaconManager.swift`, `SyncGuidanceCopy.swift`, `SyncGuidanceCopyTests.swift`) correctly left unstaged; no `project.pbxproj`.

**REMAINING:** (a) USER builds in Xcode (Cmd-B — the real exhaustive-switch check) + verifies on device that a commute shows in the countdown and watch/StandBy agree. (b) The **gated release is entirely the user's**: merge `feature/supabase-account-backend` → main + push (Duty), ship Crewluve first/alongside Crewlu so old partner apps decode `.drive` safely, then release notes per [[feedback_release_notes]] once builds are live. **Nothing pushed.**

Crewluv repo: uncommitted docs (`docs/superpowers/specs/2026-06-23-…ui-decisions.md`, `plans/2026-06-23-…ui.md`) — leave per the user.

---


## Feature in one line
Pilots whose **home airport ≠ base** can add a from→to ground **commute drive** between trips; their partner sees an accurate two-phase status ("heads to work" → "driving to work / back at SDF in X", and the mirror for driving home). Spans two sibling repos: **Crewluv** (partner app, read-only) and **Duty** (pilot app).

## Authoritative documents (in the Crewluv repo, `docs/superpowers/`)
- **Spec:** `specs/2026-06-22-commuter-home-base-commutes-design.md` — the full design (read §6.x, §7, §9, §11, §12, §13, §16). All decisions live here.
- **Plans:** `plans/2026-06-22-commute-stage1-crewluv-drive-support.md`, `…-stage2-duty-data-layer.md`, `…-stage3a-duty-status-emission.md`.

## Status

| Stage | What | State |
|---|---|---|
| **1** | Crewluv `.drive` rendering (two-phase display, statuses, timeline, calendar) | ✅ DONE |
| **2** | Duty `Commute` model + dual-backend sync + `commutes` migration FILE | ✅ DONE |
| **3a** | Duty status emission (`.drive` legs, `Driving Home/to Work` status, HiddenEventsManager) | ✅ DONE |
| **3b** | Duty **CommuteSuggestionEngine** (gap detection, jumpseat de-dup, convert) + orphan **cleanup** | ✅ DONE |
| **3c** | Duty **Partner Sharing "Commutes" UI** (section + sheet + suggestions; upcoming-only, local+Zulu, 2h report buffer, last-trip drive-home) | ✅ DONE (committed locally, unpushed) |
| **4** | Production provisioning (deploy `CD_Commute` to CloudKit prod; apply Supabase migration) + release | ⏳ GATED on explicit user OK |

## Git state (NOTHING PUSHED — all local commits)
- **Crewluv** branch `feature/commute-stage1-crewluv-drive` (off `main`): 7 commits, latest `d654c73`. Left as-is (user chose "keep branch"). Uncommitted: `Crewluv.xcodeproj/project.pbxproj` has the **user's** version bump 1.0.9→1.1.0 (leave untouched).
- **Duty** branch `feature/supabase-account-backend`: Stage 2 = `91a3960, 24e63e7d, f756325a, 2cb3f67f, 84b4773d`; Stage 3a = `d2b14e06, 550441fd`; **Stage 3b = `da56ba59` (CommuteSuggestionEngine + CommuteSuggestion + 13 tests), `69c2b8ea` (CommuteCleanupService + SoftDeleteService.softDelete(_ commute:) + 6 tests), `84475938` (DutyApp launch wiring, both backends), `bcfc9209` (review polish: gate-ordering test, needsPush assertion, comment)`. **Commit Stage 3b/3c directly onto this branch** (user's decision — it is the real iOS dev trunk; `main` lacks the Supabase layer and is ~361 commits behind / website work). **User merges to main + pushes themselves.** NOTHING pushed.
  - **Stage 3c = `a6538784` (CommuteSuggestionDismissalStore + 3 tests), `c8fff26d` (CommuteSheetModel + 8 tests), `674ee6ff` (engine refinement: 2h report buffer on drive-to-work + drive-home after the final trip + tests), `56200bac` (CommuteSheet add/edit/confirm/convert, local+Zulu), `e4218e7f` (PartnerSharingView Commutes section: upcoming-only filter, confirm/convert/dismiss/edit/swipe-delete, delete suppresses re-suggest), `fbe98e16` (CommuteCleanupIntegrationTests, closes the 3b deferral)`. Authoritative UI-decisions addendum: `docs/superpowers/specs/2026-06-23-commute-stage3c-ui-decisions.md`; plan: `docs/superpowers/plans/2026-06-23-commute-stage3c-partner-sharing-ui.md`. Verified on the user's device (suggestion count sane, report buffer + drive-home + local times correct).

## NON-NEGOTIABLE working rules (hard-won)
1. **Never push. Never merge. Confirm EVERY commit with the user before running it** — even though this doc previously said "commit per stage," that is NOT standing authorization (user correction, 2026-06-23). Make the edits, stop, and ask "commit X?". The user handles push/merge to main. (Stage 3b's 4 commits were already made & the user chose to keep them as-is.)
2. **Never `git add` the user's WIP** in the Duty tree: `Duty/Utils/PartnerBeacon/PilotStatusBeaconManager.swift` (M), `Duty/Utils/SyncGuidanceCopy.swift` (M), `DutyTests/SyncGuidanceCopyTests.swift` (??). These are the user's parallel `SyncGuidanceCopy` refactor — leave untouched. Stage only your named files.
3. **Never commit `project.pbxproj`.** Both `DutyTests` and `CrewluvTests` are `PBXFileSystemSynchronizedRootGroup`s — new test files auto-join the target, no pbxproj edit needed.
4. **Methodology:** stage plans just-in-time (write each against *current* code), then execute via **superpowers:subagent-driven-development** — fresh implementer subagent per task, then **spec-compliance review, then code-quality review** (two separate gates). Give subagents full task text inline (don't make them read the plan file).
5. **The USER runs builds/tests in Xcode — do NOT self-drive `xcodebuild` build/test loops** (user correction, 2026-06-23: "you are running too many tests on your own ... let me run the tests in xcode"). Write the code + tests, then hand off with the targeted class names for the user to run (Cmd-U), e.g. `DutyTests/<Class>`. Tell implementer/reviewer subagents NOT to run xcodebuild either. If a run is ever needed, ask first. (Reference only — if the user explicitly asks you to run one: `xcodebuild test -project Duty.xcodeproj -scheme Duty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DutyTests/<Class>`; `server died`/`Invalid device state` with 0 assertion failures = sim flake → `xcrun simctl shutdown all`.)
6. SwiftData test gotcha: a `ModelContext` does NOT retain its `ModelContainer`. Test helpers MUST retain the container (stored property + `tearDown`), or in-memory `save()` traps (`EXC_BREAKPOINT` in SwiftData). (Pattern already in `DutyTests/HiddenEventsManagerCommuteTests.swift`.)
7. `generateStatus` reads hidden ids from the UserDefaults cache (`HiddenEventsManager.loadHiddenIDs()`), kept current by the live `@Observable` instance. Tests must call `HiddenEventsManager.writeCache(HiddenEventsManager.deriveSet(from: ctx))` after `save()` (see `DutyTests/CommuteStatusEmissionTests.swift`).

## Architecture facts (verified against code)
- **Supabase is LIVE** (~30% of pilots). Adding a synced model needs BOTH registries: `SyncSchema.allModels` (CloudKit mirror) AND `SupabaseSyncEngine` (`tableOrder` + a `pullTable` + a `pushTable`) + a `<Model>Row` DTO + a Postgres migration. (All done for `Commute` in Stage 2.)
- **Partner beacon is CloudKit, independent of `SyncBackendMode`** (`PartnerBeaconModeIndependenceTests`) — so Crewluv works for ALL pilots. Commute data rides inside the existing `tripLegsJSON` (Data) + `displayStatus` (String) fields → **no beacon CKRecord schema change**.
- `Commute` model: standalone root, all properties defaulted, **NO `@Attribute(.unique)`** (CloudKit forbids), conforms to `Syncable` (mirrors `Jumpseat`). `SyncChangeTracker` flags any `Syncable` generically → commutes auto-flag `needsPush` on edit.
- Status strings (Duty emits, Crewluv `PilotDisplayStatus` bridge maps): **`"Driving Home"`** / **`"Driving to Work"`**. Leg labels: `"Driving home"` / `"Driving to work"`. Leg type `.drive` exists in BOTH repos' `TripLeg.LegType`.
- `Commute` fields: `id, fromAirport, toAirport, directionRaw (toHome|toWork), departureTimeZulu, arrivalTimeZulu, driveDurationSeconds (Double, default 7200), sourceTripId (String?), hiddenFromTimeline (Bool=false), createdAt, lastModifiedAt, deletedAt, needsPush`. `CommuteRouteStore` (Duty/Utils/) remembers per-route duration (2h default) in `SharedUserDefaults`.

## DONE: Stage 3b — Suggestion engine + cleanup (pure logic, unit-tested)
Per spec §7 and §12 items 3, 10. Plan: `plans/2026-06-22-commute-stage3b-suggestion-engine-cleanup.md`. Shipped (19 unit tests, all green; app builds):
- **`CommuteSuggestionEngine`** (`Duty/Utils/PartnerBeacon/`, pure read, `@MainActor func suggestions(for: PilotInfo) -> [CommuteSuggestion]`). Four gates: commuter (`effectiveHomeAirportCode != base.rawValue`), gap `> 24h` (`minimumGap`), base-anchored (`toHome` after a trip whose `endingAirport == base` keyed to prev.id; `toWork` before a trip whose `startingAirport == base` keyed to next.id), not-already-covered (no live managed `Commute` for `(sourceTripId, direction)`; no standalone+visible bridging `Jumpseat` — `toHome`: dest==home in gap, `toWork`: origin==home in gap). Driving `ManualEvent` (`driv`/`car`/`truck`, via `nonisolated static titleSuggestsDriving(_:)`) in the gap → suggestion `origin = .convert(manualEventID:)` else `.fresh`; gate-4a/4b suppress entirely (suppression wins over convert). Times: `toHome` dep=gapStart, arr=+`CommuteRouteStore.duration`; `toWork` arr=gapEnd, dep=−duration. Idempotency `id = sourceTripId|direction|from|to`.
- **`CommuteSuggestion`** value type (`Equatable/Identifiable/Sendable`, `Origin = .fresh | .convert(manualEventID:)`). **3c consumes this** — the UI surfaces suggestions, lets the user edit/confirm, and on confirm creates a `Commute` (and for `.convert`, hides/soft-deletes the source `ManualEvent`).
- **`CommuteCleanupService.cleanupOrphanedCommutes(in:)`** soft-deletes (via `SoftDeleteService.softDelete(_ commute:)` → `tombstone`) live commutes whose `sourceTripId` is absent/soft-deleted; keeps manual (nil) commutes. Wired into `DutyApp` 60s launch wave, both backends, behind `isSyncing || isSyncInFlight || hasFreshIncompleteOrRecoveryTrips` gate.
- Deferred to Stage 3c (reviewer-noted): integration test that a confirmed suggestion's `(sourceTripId, direction)` round-trips with the cleanup's "live" judgement.

## (prev) Stage 3b notes — kept for reference
Per spec §7 and §12 items 3, 10. Author the plan against current code, then subagent-driven.

**`CommuteSuggestionEngine`** (new, `Duty/Utils/PartnerBeacon/`). Pure read → returns suggestions; never writes. Gates (ALL):
- `pilotInfo.base.rawValue != pilotInfo.effectiveHomeAirportCode` (commuter).
- A gap **> 24h** between consecutive `Trip`s: `nextTrip.startDate − prevTrip.endDate`.
- **Base-anchored:** `toHome` only after a trip whose `endingAirport == base`; `toWork` only before a trip whose `startingAirport == base`. (`Trip` exposes `endingAirport`/`startingAirport` — confirm.)
- **Not already covered:** no standalone jumpseat bridging the gap toward home/from home (reuse the logic style of `PartnerStatusGenerator.isCommutingHome` / `findHomeJumpseatNearTripEnd` — already read; quoted in session), and no existing `Commute` for the gap.
- Output up to 2 suggestions per gap; key on `(sourceTripId, direction, fromAirport, toAirport)` for idempotency.
- **Convert flow:** if a `ManualEvent` with a `driv`/`car`/`truck` title sits in the gap, offer convert (don't double-suggest).

**Cleanup service:** soft-delete `Commute`s whose `sourceTripId` references a soft-deleted/absent `Trip` (mirror `Duty/Utils/Sync/SoftDeleteService.swift` patterns; run alongside existing post-launch cleanups).

**Files to read to author 3b:** `Duty/Models/Trip.swift` (endingAirport/startingAirport, startDate/endDate), `Duty/Models/PilotInfo.swift` (effectiveHomeAirportCode), `Duty/Utils/PartnerBeacon/PartnerStatusGenerator.swift` (isCommutingHome ~1158, findHomeJumpseatNearTripEnd ~1136 — for the dedup pattern), `Duty/Utils/Sync/SoftDeleteService.swift`, and how `ManualEvent` labels are matched (the `driv`/`car`/`truck` detection — see Crewluv `NarrativeCardView.eventIconOverride` for the keyword set).

## Stage 3c (after 3b) — Partner Sharing UI
A "Commutes" section in `Duty/Views/Settings/PartnerSharingView.swift` (1,753 lines) + `AddCommuteSheet.swift`/`EditCommuteSheet.swift` mirroring `Duty/Views/ManualEvent/AddManualEventView.swift` (2,149 lines). Suggest-and-confirm; gated on `home != base`; swipe-to-delete sets `deletedAt`; duration field defaults to remembered/2h. It consumes `CommuteSuggestion` from the Stage 3b engine (see the DONE section above for the API). This is the largest/most UI-heavy stage. **Verification & commits: the USER runs build/run in Xcode and approves each commit (rules #1 and #5) — do not auto-build or auto-commit.**

## Stage 4 (GATED) — provisioning + release
Only with explicit per-step user authorization:
1. ✅ **DONE 2026-06-23** — `CD_Commute` deployed to **CloudKit production** (container `iCloud.com.toddanderson.duty`). User registered the schema in Development by switching their phone to the iCloud backend + syncing, then deployed via Dashboard. The deploy also carried pre-existing Development drift (additive field/index adds on CD_DutyPeriod/Flight/Hotel/Jumpseat/JumpseatRider + standard `_world:read`/`_icloud:create`/`_creator:write` role grants for CD_Commute) — all additive/non-destructive, verified safe before deploying.
2. ✅ **DONE 2026-06-23** — `public.commutes` created in **production Supabase** (project `corxvurxpnrzekbxdgye`) via SQL Editor (user ran it; the MCP write was blocked by the auto-mode classifier). Verified read-only: table + `commutes_owner` RLS + `commutes_touch` trigger + `commutes_user_updated` index + `touch_updated_at()` all present. Security advisor: no `commutes`-specific findings (only pre-existing project-wide function-search_path / security-definer / leaked-password warnings). Migration file: `Duty/supabase/migrations/20260622170000_commutes_table.sql` (note: path is `Duty/supabase/…`, NOT `Duty/Duty/supabase/…`).
3. Release ordering: **Crewluv ships first or alongside Duty** (Crewluv's `.drive` support must be live before Duty emits drives; old Crewluv decodes `.drive` as `.unknown` safely).
4. Release notes in Apple Notes ("Crewluve revisions" + the Duty note), per the user's workflow.

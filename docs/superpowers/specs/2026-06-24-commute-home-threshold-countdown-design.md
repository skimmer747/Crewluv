# Design — Commute home-threshold countdown (top card = work, big block = home)

**Date:** 2026-06-24
**Repo:** Crewluv (partner app, read-only)
**Status:** Approved, ready to plan
**Related:** [[project_commute_feature]]; commute feature spec `2026-06-22-commuter-home-base-commutes-design.md`; RESUME `docs/superpowers/commute-feature-RESUME.md`

## Problem

When a commuter pilot (home airport ≠ base) is home before a trip, two distinct times are in play:

1. **Leave home** — when the pilot starts the ground drive from home to base (e.g. 12:05pm).
2. **Work starts** — when the trip's first flight departs base (e.g. 7:50pm / "19:50").

Today these land in the *wrong* sections of `PilotStatusView`:

| Section | Shows today | Time it uses |
|---|---|---|
| Top narrative card | "heads to work in **Louisville** … 19d 0h at 12:05pm" | the **drive** (leave-home) |
| Big "Leaves In" block | "19d 08h · Departs … 19:50" | the **flight** (work starts) |

The partner reads the big block as "when does Todd leave / get home" — the most emotionally relevant number — but it's showing the flight, while the top card buries the flight under the drive. They're swapped.

## Governing principle

> **The big countdown block is always the _home threshold_ — the moment the pilot physically leaves home or arrives home.** The top narrative card carries the _work_ story (where/when the trip begins).

- Leaving, with a commute → block = the **drive-to-work departure**.
- Leaving, no commute (home == base) → block = the **flight departure** (that *is* leaving home). Unchanged.
- Returning, with a commute home → block = the **drive-home arrival** (walks in the door).
- Returning, no commute → block = `homeArrivalTime` (flight lands at home). Unchanged.

## Data reality (verified)

- Duty's **raw** `homeArrivalTime` is computed from the **homeward flight / home jumpseat only** (`PartnerStatusGenerator.swift` ~L107–141). For a commuter the trip ends at **base**, so the raw field = *lands at base*, not *home after the drive*.
- **But Crewluv overrides it.** `PartnerStatusReceiver.resolveStatus` recomputes `homeArrivalTime`/`homeArrivalLabel`/`homeArrivalCity` via `TripStateResolver.resolveHomeArrival(...)` (`PartnerStatusReceiver.swift` ~L396–417), and `resolveHomeArrival` **already scans `.drive` legs arriving at home** (`TripStateResolver.swift:271–288`), returning the drive-home arrival time, `"Back Home In"`, and the home city. So **the returning block already counts to the drive-home arrival** — the return side is already implemented. It only needs verification, not new code.
- Duty emits the base↔home drive as a `.drive` leg inside `tripLegs` (`PartnerStatusGenerator.swift` ~L844–859: `type: .drive`, `endTime = c.arrivalTimeZulu`, with `departureAirport`/`arrivalAirport`).
- Crewluv already consumes those `.drive` legs — `NarrativeCardView.nextDriveToWork()` and the driving narratives prove the pattern.

**Net:** the only genuinely-missing behavior is the **leaving-for-work** side — top card and big block both reach for the flight instead of the drive.

## Approach — derive the threshold Crewluv-side (chosen)

Crewluv computes both home thresholds from the `.drive` legs it already receives, in the view that renders the block.

**Why, over changing Duty's `homeArrivalTime`:**
- Crewluv already has the drive legs — no new data needed.
- No Duty change → no two-app release coordination; ships independently.
- `homeArrivalTime` keeps its current meaning ("arrives at base/home-airport") for any other consumer (widget/watch); we don't repurpose a shared field.
- The home-threshold logic lives in one place — the block's host view.

Cost: a little date logic duplicated into `PilotStatusView`. Acceptable and small.

## Concrete changes

### 1. Top narrative card — `NarrativeCardView.homeNarrative` commute branch (currently ~L102–109)

Repoint from the *drive* to the *first flight*. Keep the live-countdown style and the "heads to work" phrasing.

- Before: `"\(name) is home — heads to work in \(driveArrivalCity) in \(countdown→drive.startTime) at \(driveStartTime)."`
- After: `"\(name) is home — heads to work in \(nextFlightCity()) in \(countdown→nextFlight.startTime) at \(formattedLocalTime(nextFlight.startTime))."`

Detection stays `nextDriveToWork() != nil` (commuter, drive-to-work pending) so non-commuters are untouched. Destination resolves via the existing `nextFlightCity()` (returns the first trip flight's arrival city, e.g. Dallas). Times render in the app's standard 12-hour home-local format ("7:50pm EDT").

### 2. Big block — leaving (`displayStatus == .home`) — `PilotStatusView` (currently ~L83–95)

- **Target:** drive-to-work start (`.drive` leg arriving at base, `start > now`) if present; else `delayedNextDepartureTime` (flight) — unchanged for non-commuters.
- **Title:** "Leaves Home In" when the tracked event departs from home (drive-to-work present, OR next flight departs from the home airport); else "Leaves In". (Generalizes the current `countdownTitle`.)
- **Icon:** `car.fill` when targeting a drive; else `airplane.departure`.
- **Subtitle:** "Departs {weekday} {Month} {day}{suffix} at {time}" for the chosen target, formatted in the home timezone (reuses `departureSubtitle` logic).

### 3. Big block — returning (`displayStatus != .home`) — **already implemented, verify only**

No code change. `PartnerStatusReceiver.resolveStatus` already overrides `homeArrivalTime`/`homeArrivalLabel`/`homeArrivalCity` with `TripStateResolver.resolveHomeArrival(...)`, which scans `.drive` legs arriving home (`TripStateResolver.swift:271–288`). So the returning block at `PilotStatusView` ~L114–131 already targets the drive-home arrival, with `homeArrivalLabel == "Back Home In"` → `house.fill` and the home city. Confirm on-device; no edit.

### Shared helper (new, on `TripStateResolver`)

Add one stateless method mirroring `resolveHomeArrival`, and route both views through it (DRY — removes the duplicate leg-scan):

```swift
/// The next upcoming drive from home to base ("leaving for work"), if any.
/// nil for non-commuters (no drive legs) — they leave home via the flight itself.
static func nextDriveToWork(legs: [TripLeg], baseAirportCode: String?, at now: Date) -> TripLeg?
```

- `NarrativeCardView.nextDriveToWork()` becomes a thin delegate (commute detector for the top card).
- `PilotStatusView` uses it for the leave-side target / icon / title.

The arrive-home side already has its resolver (`resolveHomeArrival`) — no new helper there.

## Copy — before / after (commuter)

**Leaving (home):**
- Top: "Todd is home — heads to work in **Dallas** … **19d 8h** at **7:50pm EDT**."
- Block: **Leaves Home In** · `car.fill` · **19d 0h** · "Departs Monday July 13th at **12:05pm**".

**Returning (on trip, drive home pending):**
- Block: **Back Home In** · `house.fill` · countdown to **drive-home arrival** · "Arrives … at … · {home city}".

## Edge cases

- **Active drive** (`.drivingToWork` / `.drivingHome`): the leg still satisfies `start > now` (to-work, not yet started) or `end > now` (home, in progress); the block tracks that drive's threshold. The driving narratives already own the top card here.
- **No commute** (home == base): no `.drive` legs → every branch hits the existing fallback. Zero behavior change.
- **Drive already past / trip with no homeward leg:** existing fallbacks (`delayedNextDepartureTime`, `homeArrivalTime`).
- **Base or home airport code missing:** guard returns nil → fallback.

## Verification

- Unit-test `TripStateResolver.nextDriveToWork` (deterministic; add to `CrewluvTests/CommuteDriveSupportTests.swift`).
- `SharedPilotStatus.demo` has no commute leg, so the leave side is verified with **real device data** (the screenshot proves commute data is flowing), not demo mode. Four states to eyeball on-device: home+commute (leaving), mid-drive-to-work, on-trip-returning (drive-home pending), mid-drive-home.
- User confirms each on-device in Xcode per the standing verify loop ([[feedback_let_user_run_tests]]) — Claude does not self-drive builds.

## Out of scope

- No change to Duty (`homeArrivalTime` semantics preserved).
- No change to the non-commuter narrative/longer "gone for N days" / homecoming sentences.
- Time format remains the app's 12-hour home-local convention; switching to 24-hour is a separate tweak if wanted.

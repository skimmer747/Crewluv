# Commute Home-Threshold Countdown — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a commuter pilot (home ≠ base) is home before a trip, make the top narrative card describe the *work* trip (first flight) and the big countdown block describe the *home threshold* (the commute drive's departure) — so the block always answers "when does Todd leave / get home."

**Architecture:** One new stateless helper on `TripStateResolver` finds the upcoming home→base drive. `NarrativeCardView` repoints its commute branch from the drive to the first flight. `PilotStatusView`'s leave-side block targets the drive's start (title "Leaves Home In", `car.fill`) when a commute exists, else the flight (unchanged). The arrive-home side already works (`PartnerStatusReceiver` overrides `homeArrivalTime` via `TripStateResolver.resolveHomeArrival`, which already scans `.drive` legs).

**Tech Stack:** Swift 5.9+, SwiftUI, XCTest. iOS 17+. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-06-24-commute-home-threshold-countdown-design.md`

---

## ⚠️ Project rules for the implementer (override the generic skill defaults)

1. **Do NOT run `xcodebuild` / `xcrun simctl` / any build or test command.** The USER runs all builds and tests in Xcode (Cmd-B / Cmd-U). "Run the test" steps below mean *hand the named test class to the user*. Implementer and reviewer subagents must not self-run xcodebuild either.
2. **Do NOT commit without explicit live user approval.** Each "Commit" step means: stage exactly the listed files and **ask the user to approve the commit** — do not run `git commit` autonomously. Never `git add` unrelated files; never touch `Crewluv.xcodeproj/project.pbxproj` (test files auto-join the synchronized `CrewluvTests` group).
3. After an approved commit, the user appends a plain-English entry to the Apple Notes "Crewluve revisions" note — surface a one-line summary for them.

---

## File structure

- **Modify** `Crewluv/Models/TripStateResolver.swift` — add `static func nextDriveToWork(legs:baseAirportCode:at:)`.
- **Modify** `CrewluvTests/CommuteDriveSupportTests.swift` — add unit tests for `nextDriveToWork`.
- **Modify** `Crewluv/Views/Status/NarrativeCardView.swift` — repoint the home-narrative commute branch to the first flight; make `nextDriveToWork()` delegate to the resolver.
- **Modify** `Crewluv/Views/Status/PilotStatusView.swift` — leave-side block target/title/icon, two new computed vars, `departureSubtitle` + `countdownTitle` generalization, and a View-Schedule-card guard.

No files created. No change to the arrive-home path (already correct).

---

## Task 1: `TripStateResolver.nextDriveToWork` (the leave-home leg finder)

**Files:**
- Modify: `Crewluv/Models/TripStateResolver.swift` (add after `resolveHomeArrival`, ~L288)
- Test: `CrewluvTests/CommuteDriveSupportTests.swift` (append new tests; reuse the existing `driveLeg(...)` helper at the top of the file)

- [ ] **Step 1: Write the failing tests**

Append to `CrewluvTests/CommuteDriveSupportTests.swift`, before the final closing `}`:

```swift
    // MARK: - nextDriveToWork (leave-home countdown)

    func test_nextDriveToWork_returnsUpcomingDriveToBase() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 3))
        let leg = TripStateResolver.nextDriveToWork(legs: [drive], baseAirportCode: "SDF", at: now)
        XCTAssertEqual(leg?.id, drive.id)
    }

    func test_nextDriveToWork_ignoresPastDrive() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(-3600 * 3), end: now.addingTimeInterval(-3600))
        XCTAssertNil(TripStateResolver.nextDriveToWork(legs: [drive], baseAirportCode: "SDF", at: now))
    }

    func test_nextDriveToWork_ignoresDriveHome() {
        let now = Date()
        let driveHome = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                                 start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 3))
        XCTAssertNil(TripStateResolver.nextDriveToWork(legs: [driveHome], baseAirportCode: "SDF", at: now))
    }

    func test_nextDriveToWork_nilBase_returnsNil() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 3))
        XCTAssertNil(TripStateResolver.nextDriveToWork(legs: [drive], baseAirportCode: nil, at: now))
    }

    func test_nextDriveToWork_picksEarliestOfMultiple() {
        let now = Date()
        let soon = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                            start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 3))
        let later = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(3600 * 10), end: now.addingTimeInterval(3600 * 12))
        let leg = TripStateResolver.nextDriveToWork(legs: [later, soon], baseAirportCode: "SDF", at: now)
        XCTAssertEqual(leg?.startTime, soon.startTime)
    }
```

- [ ] **Step 2: Verify the tests fail (user, in Xcode)**

Hand off: "Run `CrewluvTests/CommuteDriveSupportTests` in Xcode (Cmd-U)." Expected: the five new tests FAIL to compile with "type 'TripStateResolver' has no member 'nextDriveToWork'". Do not run xcodebuild yourself.

- [ ] **Step 3: Add the implementation**

In `Crewluv/Models/TripStateResolver.swift`, immediately after the `resolveHomeArrival(...)` method (the end of the `// MARK: - Home Arrival` section, ~L288), insert:

```swift
    // MARK: - Drive To Work (leave-home countdown)

    /// The next upcoming drive from home to base ("leaving for work"), if any.
    /// Returns `nil` for non-commuters (no drive legs) — they leave home via the
    /// flight itself, so the leave-home countdown falls back to the departure.
    static func nextDriveToWork(legs: [TripLeg], baseAirportCode: String?, at now: Date) -> TripLeg? {
        guard let base = baseAirportCode, !base.isEmpty else { return nil }
        return legs
            .filter { $0.type == .drive && $0.startTime > now && $0.arrivalAirport?.caseInsensitiveCompare(base) == .orderedSame }
            .min { $0.startTime < $1.startTime }
    }
```

- [ ] **Step 4: Verify the tests pass (user, in Xcode)**

Hand off: "Run `CrewluvTests/CommuteDriveSupportTests` (Cmd-U)." Expected: all tests PASS (5 new + the existing ones).

- [ ] **Step 5: Commit (ask the user first)**

Stage and propose:

```bash
git add Crewluv/Models/TripStateResolver.swift CrewluvTests/CommuteDriveSupportTests.swift
git commit -m "feat(crewluv): add TripStateResolver.nextDriveToWork leave-home finder"
```

Ask the user to approve before running the commit.

---

## Task 2: Top narrative card describes the work trip (first flight), not the drive

**Files:**
- Modify: `Crewluv/Views/Status/NarrativeCardView.swift` (commute branch ~L102-109; `nextDriveToWork()` ~L201-209)

No new unit test — narrative `Text` composition is verified on-device per project convention.

- [ ] **Step 1: Repoint the commute branch to the first flight**

In `NarrativeCardView.homeNarrative`, replace this block (currently ~L102-109):

```swift
        // Commuter about to drive to work: surface the drive countdown (phase 1).
        if let drive = nextDriveToWork() {
            let destCity = drive.arrivalCity
                ?? AirportDataProvider.shared.airportInfo(forIataCode: drive.arrivalAirport ?? "")?.city
                ?? "work"
            let depTimeStr = formattedLocalTime(drive.startTime)
            return Text("\(name) is home — heads to work in \(Text(destCity).bold()) in \(countdownText(to: drive.startTime)) at \(Text(depTimeStr).bold()).")
        }
```

with:

```swift
        // Commuter at home: the top card tells the WORK story (first flight); the
        // big "Leaves Home In" block carries the commute drive. Detect the commute
        // via the pending drive-to-work, then describe the flight.
        if nextDriveToWork() != nil, let flight = nextFlight() {
            let destCity = nextFlightCity() ?? "work"
            let depTimeStr = formattedLocalTime(flight.startTime)
            return Text("\(name) is home — heads to work in \(Text(destCity).bold()) in \(countdownText(to: flight.startTime)) at \(Text(depTimeStr).bold()).")
        }
```

- [ ] **Step 2: Delegate `nextDriveToWork()` to the resolver (DRY)**

Replace the existing helper (currently ~L201-209):

```swift
    /// The next upcoming drive whose destination is the base airport ("heads to work").
    private func nextDriveToWork() -> TripLeg? {
        guard let base = status.baseAirportCode, !base.isEmpty else { return nil }
        return sortedTripLegs.first(where: {
            $0.type == .drive
            && $0.startTime > now
            && $0.arrivalAirport?.caseInsensitiveCompare(base) == .orderedSame
        })
    }
```

with:

```swift
    /// The next upcoming drive whose destination is the base airport ("heads to work").
    private func nextDriveToWork() -> TripLeg? {
        TripStateResolver.nextDriveToWork(legs: status.tripLegs, baseAirportCode: status.baseAirportCode, at: now)
    }
```

- [ ] **Step 3: Build check (user, in Xcode)**

Hand off: "Cmd-B." Expected: compiles clean. (No behavior change for non-commuters: `nextDriveToWork()` is nil, so the branch is skipped exactly as before.)

- [ ] **Step 4: Commit (ask the user first)**

```bash
git add Crewluv/Views/Status/NarrativeCardView.swift
git commit -m "feat(crewluv): top card shows the work flight, not the commute drive"
```

Ask the user to approve before running the commit.

---

## Task 3: Leave-side block targets the commute drive ("Leaves Home In")

**Files:**
- Modify: `Crewluv/Views/Status/PilotStatusView.swift` — the home countdown card (~L82-95), `countdownTitle` (~L275-284), `departureSubtitle` (~L286-302), the View-Schedule card guard (~L147), plus two new computed vars near `delayedNextDepartureTime` (~L273).

No new unit test — view wiring is verified on-device.

- [ ] **Step 1: Add the leave-home computed vars**

In `PilotStatusView`, immediately after the `delayedNextDepartureTime` computed property (ends ~L273), insert:

```swift
    /// The next "leaving for work" commute drive (home → base), if the pilot commutes.
    /// nil for non-commuters, who leave home via the flight itself.
    private var leaveHomeDrive: TripLeg? {
        TripStateResolver.nextDriveToWork(legs: status.tripLegs, baseAirportCode: status.baseAirportCode, at: Date())
    }

    /// When the pilot physically leaves home: the commute drive's start when commuting,
    /// otherwise the next flight departure (delay-adjusted).
    private var leaveHomeTarget: Date? {
        leaveHomeDrive?.startTime ?? delayedNextDepartureTime
    }
```

- [ ] **Step 2: Point the home countdown card at the leave-home target**

Replace the home countdown card (currently ~L82-95):

```swift
                    // Next Departure (if at home) — taps open schedule
                    if status.displayStatus == .home, let departureTime = delayedNextDepartureTime {
                        scheduleLink {
                            CountdownCardView(
                                title: countdownTitle,
                                targetDate: departureTime,
                                icon: "airplane.departure",
                                color: status.hasFlightDelay ? (status.isEarlyDeparture ? .green : .orange) : .blue,
                                subtitle: departureSubtitle,
                                showChevron: !isCompanionLayout
                            )
                            .contentShape(.rect)
                        }
                    }
```

with:

```swift
                    // Leaving home (if at home) — the commute drive when commuting,
                    // otherwise the flight departure. Taps open schedule.
                    if status.displayStatus == .home, let departureTime = leaveHomeTarget {
                        scheduleLink {
                            CountdownCardView(
                                title: countdownTitle,
                                targetDate: departureTime,
                                icon: leaveHomeDrive != nil ? "car.fill" : "airplane.departure",
                                color: leaveHomeDrive != nil ? .blue : (status.hasFlightDelay ? (status.isEarlyDeparture ? .green : .orange) : .blue),
                                subtitle: departureSubtitle,
                                showChevron: !isCompanionLayout
                            )
                            .contentShape(.rect)
                        }
                    }
```

- [ ] **Step 3: Title — "Leaves Home In" when a commute drive is pending**

Replace `countdownTitle` (currently ~L275-284):

```swift
    private var countdownTitle: String {
        if let home = status.homeAirportCode {
            let sorted = status.tripLegs.sorted { $0.startTime < $1.startTime }
            if let nextFlight = sorted.first(where: { $0.type == .flight && $0.startTime > Date() }),
               nextFlight.departureAirport == home {
                return "Leaves Home In"
            }
        }
        return "Leaves In"
    }
```

with:

```swift
    private var countdownTitle: String {
        // A commute drive departs from home, so it is always "Leaves Home In".
        if leaveHomeDrive != nil { return "Leaves Home In" }
        if let home = status.homeAirportCode {
            let sorted = status.tripLegs.sorted { $0.startTime < $1.startTime }
            if let nextFlight = sorted.first(where: { $0.type == .flight && $0.startTime > Date() }),
               nextFlight.departureAirport == home {
                return "Leaves Home In"
            }
        }
        return "Leaves In"
    }
```

- [ ] **Step 4: Subtitle — format the chosen leave-home target**

In `departureSubtitle` (currently ~L286-302), change only the guard's source from `delayedNextDepartureTime` to `leaveHomeTarget`:

```swift
    private var departureSubtitle: String? {
        guard let departureTime = leaveHomeTarget else { return nil }
```

Leave the rest of the method unchanged (it already formats `departureTime` in the home timezone as `"Departs {weekday} {Month} {day}{suffix} at {h:mma}"`). For a commute drive this renders the drive's home-local start, e.g. "Departs Monday July 13th at 12:05pm".

- [ ] **Step 5: Don't show both the countdown and the "View Schedule" card**

In the View-Schedule card condition (currently ~L147):

```swift
                    if !isCompanionLayout, status.displayStatus.isSettled, status.nextDepartureTime == nil {
```

add a `leaveHomeTarget == nil` guard so a commuter whose `nextDepartureTime` is unset still shows the countdown (driven by the drive) rather than both cards:

```swift
                    if !isCompanionLayout, status.displayStatus.isSettled, status.nextDepartureTime == nil, leaveHomeTarget == nil {
```

- [ ] **Step 6: Build check (user, in Xcode)**

Hand off: "Cmd-B." Expected: compiles clean. Non-commuters: `leaveHomeDrive` is nil → `leaveHomeTarget == delayedNextDepartureTime`, `car.fill` path not taken, title/subtitle/guard all resolve to today's values — zero behavior change.

- [ ] **Step 7: Commit (ask the user first)**

```bash
git add Crewluv/Views/Status/PilotStatusView.swift
git commit -m "feat(crewluv): big block counts down to leaving home (commute drive)"
```

Ask the user to approve before running the commit.

---

## Task 4: On-device verification (user) + arrive-home confirmation

No code. The user verifies with real device data (the commute is already flowing — see the screenshot).

- [ ] **Step 1: Leaving for work (pilot home, commute pending)**

On-device, with a home+commute state, confirm:
- Top card: "{name} is home — heads to work in **{first flight city}** in **{countdown to flight}** at **{flight time}**." (the *flight*, e.g. 7:50pm — 12-hour home-local).
- Big block: title **"Leaves Home In"**, **car** icon, countdown to the **drive start**, subtitle "Departs … at **{drive time}**" (e.g. 12:05pm).
- The two times differ (drive earlier than flight) — that's correct.

- [ ] **Step 2: Mid-drive to work**

While the drive-to-work is in progress (`Driving to Work`), confirm the top driving narrative and that no duplicate/!contradictory countdown appears.

- [ ] **Step 3: On a trip, returning (drive-home pending)**

Confirm the big block reads **"Back Home In"**, **house** icon, and counts to the **drive-home arrival** (when he's actually home), with the home city in the subtitle — this is the already-implemented `resolveHomeArrival` path; it should need no change.

- [ ] **Step 4: Mid-drive home + non-commuter regression**

- Mid-drive-home (`Driving Home`): narrative + block consistent.
- A non-commuter (home == base) account: top card and block are identical to before this change.

- [ ] **Step 5: Release note**

After the commits are live, give the user a one-line plain-English summary to append to the Apple Notes "Crewluve revisions" note, e.g.: *"For commuters, the big countdown now shows when {pilot} leaves home for the drive to work (and gets home after), while the top line shows when the trip itself departs."*

---

## Self-review (done while writing)

- **Spec coverage:** §1 top card → Task 2. §2 leave block → Task 3. §3 return block → already implemented, confirmed in Task 4. Shared helper → Task 1. Edge cases (no commute, active drive, missing codes) → covered by nil-fallbacks in Tasks 1/3 + Task 4 regression. Verification → Tasks 1 & 4.
- **Placeholders:** none — every step has concrete code/commands.
- **Type consistency:** `nextDriveToWork(legs:baseAirportCode:at:)` signature identical across resolver (Task 1), `NarrativeCardView` (Task 2), and `PilotStatusView` (Task 3). `leaveHomeDrive`/`leaveHomeTarget` defined in Task 3 Step 1 before first use in Steps 2-5. `departureSubtitle`/`countdownTitle` reference `leaveHomeTarget`/`leaveHomeDrive` which exist after Task 3 Step 1.

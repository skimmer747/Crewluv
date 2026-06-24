# Commute — Stage 1: Crewluv `.drive` Rendering Support — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach the Crewluv partner app to render a new `.drive` trip-leg type and two new statuses (`Driving Home`, `Driving to Work`), so that when the Duty app later emits commute drives, the partner sees an accurate two-phase display — and so it degrades safely until then.

**Architecture:** Crewluv is read-only; it decodes `tripLegsJSON` + `displayStatus` from the CloudKit beacon. This stage adds the `.drive` `LegType`, the `.drivingHome`/`.drivingToWork` `PilotDisplayStatus` cases (string-bridged), drive handling in the stateless `TripStateResolver`, and drive rendering in `NarrativeCardView`, `TimelineRowView`, and `CalendarDataBuilder`. No Duty changes and no schema change — ships independently and stays inert until Duty sends a drive.

**Tech Stack:** Swift 5.9+, SwiftUI, XCTest. iOS 17+. No new dependencies.

**Spec:** [docs/superpowers/specs/2026-06-22-commuter-home-base-commutes-design.md](../specs/2026-06-22-commuter-home-base-commutes-design.md) — items 14–20 + §9.2 (statuses) + §10 (display).

**Compile-coupling rule (why tasks are grouped this way):** Swift `switch` over an enum is exhaustive. Adding a `LegType` case breaks `TripStateResolver.displayStatus(for:)` (no `default:`); adding `PilotDisplayStatus` cases breaks `NarrativeCardView`'s `narrativeText`/`statusIcon`/`statusColor` (no `default:`). The test target compiles the whole `Crewluv` module, so an enum case and **every exhaustive switch it forces must land in the same task** or nothing builds. Task 1 therefore introduces both new types *and* completes every exhaustive switch in one shot. Later tasks add only logic/handling (no new enum cases), so they stay compile-safe.

**Safety notes (per project workflow):**
- All work on a dedicated branch (Task 0). Commit locally per task; **do NOT push** without the user's explicit go-ahead.
- Logic tasks are TDD with XCTest. View-only changes are verified by build + simulator screenshot (the project's iOS verify loop).
- Backward-compatible: a beacon with no drive legs must render exactly as before (every change is gated on `leg.type == .drive` or a new status).

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Crewluv/Models/TripLeg.swift` | Wire model for a leg | Add `.drive` case |
| `Crewluv/Models/PilotDisplayStatus.swift` | Type-safe status + string bridge | Add `.drivingHome` / `.drivingToWork` |
| `Crewluv/Models/TripStateResolver.swift` | Derive live status from legs | Active drive, home-arrival, gap |
| `Crewluv/Views/Status/NarrativeCardView.swift` | "What's happening now" sentence + icon | Driving narratives, icon/color, phase-1 |
| `Crewluv/Views/Schedule/TimelineRowView.swift` | One leg row | Drive icon/color/title + homebound border |
| `Crewluv/Models/CalendarDataBuilder.swift` | Month calendar bars | Drive → off-duty (no silent `.onDuty`) |
| `Crewluv/Models/SharedPilotStatus.swift` | Beacon decode + leg post-processing | Document drive exclusion from overlap trim |
| `CrewluvTests/CommuteDriveSupportTests.swift` | Unit tests | New test file |

**Test command (reused throughout):**
`xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
Single-class: append `-only-testing:CrewluvTests/CommuteDriveSupportTests`.
Build only: `xcodebuild -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`

---

## Task 0: Branch setup

**Files:** none (git only)

- [ ] **Step 1: Create the feature branch**

```bash
cd /Users/toddanderson/Dev/Crewluv
git checkout -b feature/commute-stage1-crewluv-drive
```

- [ ] **Step 2: Confirm clean starting point**

Run: `git status`
Expected: on `feature/commute-stage1-crewluv-drive`; only pre-existing untracked `.claude/`, `.superpowers/`, `docs/`.

---

## Task 1: Foundation — new types + every exhaustive switch (compiles green)

Adds `.drive` (`LegType`), `.drivingHome`/`.drivingToWork` (`PilotDisplayStatus`), and completes **all** exhaustive switches those break, plus the active-drive resolver path and the driving narrative/icon/color. This is the only task that introduces new enum cases.

**Files:**
- Modify: `Crewluv/Models/TripLeg.swift:11-14`
- Modify: `Crewluv/Models/PilotDisplayStatus.swift:13-61`
- Modify: `Crewluv/Models/TripStateResolver.swift:128-129, 449-461`
- Modify: `Crewluv/Views/Status/NarrativeCardView.swift:42-66, 153-163, 709-739`
- Create: `CrewluvTests/CommuteDriveSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `CrewluvTests/CommuteDriveSupportTests.swift`:

```swift
import XCTest
@testable import Crewluv

final class CommuteDriveSupportTests: XCTestCase {

    // MARK: - Helpers

    private func driveLeg(
        from: String, to: String, arrivalCity: String? = nil,
        start: Date, end: Date, tripId: String? = nil, label: String? = "Driving"
    ) -> TripLeg {
        TripLeg(
            id: "drive-\(from)-\(to)", tripId: tripId, type: .drive,
            startTime: start, endTime: end,
            airportCode: nil, city: nil,
            timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil,
            flightNumber: nil, departureAirport: from, arrivalAirport: to,
            departureCity: nil, arrivalCity: arrivalCity,
            tripDayNumber: nil, tripTotalDays: nil, delayMinutes: nil,
            airlineCode: nil, label: label
        )
    }

    // MARK: - LegType decoding

    func test_legType_decodesDriveRawValue_asDrive() throws {
        let json = #"{"type":"drive"}"#.data(using: .utf8)!
        struct Wrapper: Decodable { let type: TripLeg.LegType }
        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: json).type, .drive)
    }

    func test_legType_decodesUnknownRawValue_asUnknown() throws {
        let json = #"{"type":"teleport"}"#.data(using: .utf8)!
        struct Wrapper: Decodable { let type: TripLeg.LegType }
        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: json).type, .unknown)
    }

    // MARK: - PilotDisplayStatus bridge

    func test_displayStatus_bridgesDrivingHome() {
        XCTAssertEqual(PilotDisplayStatus(rawDisplayString: "Driving Home"), .drivingHome)
        XCTAssertEqual(PilotDisplayStatus.drivingHome.rawDisplayString, "Driving Home")
    }

    func test_displayStatus_bridgesDrivingToWork() {
        XCTAssertEqual(PilotDisplayStatus(rawDisplayString: "Driving to Work"), .drivingToWork)
        XCTAssertEqual(PilotDisplayStatus.drivingToWork.rawDisplayString, "Driving to Work")
    }

    func test_displayStatus_unknownDrivingString_isPreserved() {
        XCTAssertEqual(PilotDisplayStatus(rawDisplayString: "Driving Sideways"),
                       .unknown("Driving Sideways"))
    }

    // MARK: - Active drive resolution

    func test_resolve_activeDriveToHome_isDrivingHome() {
        let now = Date()
        let leg = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                           start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let state = TripStateResolver.resolve(legs: [leg], homeAirportCode: "MCO", baseAirportCode: "SDF", at: now)
        XCTAssertEqual(state?.displayStatus, .drivingHome)
        XCTAssertEqual(state?.isInFlight, false)
    }

    func test_resolve_activeDriveToWork_isDrivingToWork() {
        let now = Date()
        let leg = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                           start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(3600))
        let state = TripStateResolver.resolve(legs: [leg], homeAirportCode: "MCO", baseAirportCode: "SDF", at: now)
        XCTAssertEqual(state?.displayStatus, .drivingToWork)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the single-class test command. Expected: FAIL — compile errors (`.drive`, `.drivingHome` undefined). That is the expected failing state.

- [ ] **Step 3: Add the `.drive` leg type**

`Crewluv/Models/TripLeg.swift` — change lines 11-14 from:

```swift
    enum LegType: String, Codable, Sendable {
        case flight, turn, layover, home, base
        case reserve, hotStandby, event  // future
        case unknown                     // forward compat
```

to:

```swift
    enum LegType: String, Codable, Sendable {
        case flight, turn, layover, home, base
        case drive                       // ground commute (base <-> home)
        case reserve, hotStandby, event  // future
        case unknown                     // forward compat
```

- [ ] **Step 4: Add the two statuses + string bridge**

`Crewluv/Models/PilotDisplayStatus.swift` — add cases after `case commutingHome` (line 16):

```swift
    case commutingHome
    case drivingHome
    case drivingToWork
```

In `init(rawDisplayString:)` after the `"Commuting Home"` line (35):

```swift
        case "Commuting Home": self = .commutingHome
        case "Driving Home":   self = .drivingHome
        case "Driving to Work": self = .drivingToWork
```

In `rawDisplayString` after the `.commutingHome` line (51):

```swift
        case .commutingHome:  "Commuting Home"
        case .drivingHome:    "Driving Home"
        case .drivingToWork:  "Driving to Work"
```

- [ ] **Step 5: Complete the `LegType` switch + direction-aware drive status**

`Crewluv/Models/TripStateResolver.swift` — change the call site (lines 128-129) from:

```swift
        return ActiveLegState(
            displayStatus: displayStatus(for: leg.type),
```

to:

```swift
        return ActiveLegState(
            displayStatus: leg.type == .drive
                ? driveStatus(for: leg, homeAirportCode: homeAirportCode, baseAirportCode: baseAirportCode)
                : displayStatus(for: leg.type),
```

Replace the `displayStatus(for:)` helper (lines 449-461) with:

```swift
    private static func displayStatus(for type: TripLeg.LegType) -> PilotDisplayStatus {
        switch type {
        case .flight:     .inFlight
        case .turn:       .turn
        case .layover:    .layover
        case .home:       .home
        case .base:       .base
        case .drive:      .drivingToWork
        case .reserve:    .reserve
        case .hotStandby: .hotStandby
        case .event:      .training
        case .unknown:    .unknown("On Duty")
        }
    }

    /// Direction of a drive leg from its arrival airport: home -> `.drivingHome`,
    /// otherwise `.drivingToWork`.
    private static func driveStatus(for leg: TripLeg, homeAirportCode: String?, baseAirportCode: String?) -> PilotDisplayStatus {
        if let home = homeAirportCode,
           leg.arrivalAirport?.caseInsensitiveCompare(home) == .orderedSame {
            return .drivingHome
        }
        return .drivingToWork
    }
```

- [ ] **Step 6: Complete the `PilotDisplayStatus` switches + driving narrative**

`Crewluv/Views/Status/NarrativeCardView.swift`:

(a) `narrativeText` (lines 42-66) — add after `.commutingHome` (line 46):

```swift
        case .commutingHome:
            commutingHomeNarrative
        case .drivingHome:
            drivingNarrative(toHome: true)
        case .drivingToWork:
            drivingNarrative(toHome: false)
```

(b) Insert after `commutingHomeNarrative` (after line 163):

```swift
    @ViewBuilder
    private func drivingNarrative(toHome: Bool) -> some View {
        let drive = activeDriveLeg()
        let destCity = drive?.arrivalCity
            ?? AirportDataProvider.shared.airportInfo(forIataCode: drive?.arrivalAirport ?? "")?.city
            ?? (toHome ? "home" : "work")
        if let arrival = drive?.endTime ?? status.homeArrivalTime {
            let arrTimeStr = formattedLocalTime(arrival)
            if toHome {
                Text("\(name) is driving home to \(Text(destCity).bold()) — back in \(countdownText(to: arrival, color: .green)) at \(Text(arrTimeStr).bold()).")
            } else {
                Text("\(name) is driving to work in \(Text(destCity).bold()) — arrives in \(countdownText(to: arrival)) at \(Text(arrTimeStr).bold()), then the trip starts.")
            }
        } else {
            Text(toHome ? "\(name) is driving home" : "\(name) is driving to work")
        }
    }

    /// The drive leg currently in progress (startTime <= now < endTime), if any.
    private func activeDriveLeg() -> TripLeg? {
        sortedTripLegs.first(where: { $0.type == .drive && $0.startTime <= now && now < $0.endTime })
    }
```

(c) `statusIcon` (lines 709-723) — add after `.commutingHome` (line 712):

```swift
        case .commutingHome: return "airplane"
        case .drivingHome: return "car.fill"
        case .drivingToWork: return "car.fill"
```

(d) `statusColor` (lines 725-739) — add after `.commutingHome` (line 728):

```swift
        case .commutingHome: return .blue
        case .drivingHome: return .green
        case .drivingToWork: return .blue
```

- [ ] **Step 7: Build the whole app and fix any other exhaustive switches**

Run the build-only command. If the compiler reports **other** non-exhaustive switches over `PilotDisplayStatus` or `TripLeg.LegType` anywhere (e.g. a notifier, the sun dial, a widget), add the new cases following the nearest existing pattern — `.drivingHome` ≈ treat like `.home`/green; `.drivingToWork` ≈ like `.commutingHome`/blue; `.drive` ≈ a ground/transition leg — and **report every such site** in your status. Re-run until BUILD SUCCEEDED.

- [ ] **Step 8: Run tests to verify they pass**

Run the single-class test command. Expected: all 7 tests PASS.

- [ ] **Step 9: Commit (local only)**

```bash
git add Crewluv/Models/TripLeg.swift Crewluv/Models/PilotDisplayStatus.swift Crewluv/Models/TripStateResolver.swift Crewluv/Views/Status/NarrativeCardView.swift CrewluvTests/CommuteDriveSupportTests.swift
git commit -m "feat(crewluv): add .drive type + Driving Home/to Work statuses with rendering"
```

> `CrewluvTests` is a `PBXFileSystemSynchronizedRootGroup`, so a new `.swift` file in the `CrewluvTests/` folder is auto-included in the test target — **do NOT** `git add Crewluv.xcodeproj/project.pbxproj` (it carries the user's unrelated 1.1.0 version bump; keep it out of feature commits).

---

## Task 2: Home-arrival countdown + gap resolution for drives

**Files:**
- Modify: `Crewluv/Models/TripStateResolver.swift:272-274` (home arrival), `:311` (gap location), `:378-390` (inferred home/base)
- Test: `CrewluvTests/CommuteDriveSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Append to `CommuteDriveSupportTests`:

```swift
    func test_resolveHomeArrival_includesDriveHomeLeg() {
        let now = Date()
        let drive = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                             start: now.addingTimeInterval(3600), end: now.addingTimeInterval(3600 * 6))
        let info = TripStateResolver.resolveHomeArrival(legs: [drive], homeAirportCode: "MCO", at: now)
        XCTAssertEqual(info?.arrivalTime, drive.endTime)
        XCTAssertEqual(info?.arrivalLabel, "Back Home In")
    }

    func test_resolveGap_afterCompletedDriveHome_isHome() {
        let now = Date()
        let drive = driveLeg(from: "SDF", to: "MCO", arrivalCity: "Orlando",
                             start: now.addingTimeInterval(-3600 * 6), end: now.addingTimeInterval(-3600))
        let state = TripStateResolver.resolve(legs: [drive], homeAirportCode: "MCO", baseAirportCode: "SDF", at: now)
        XCTAssertEqual(state?.displayStatus, .home)
        XCTAssertEqual(state?.currentAirport, "MCO")
    }

    func test_resolveGap_afterCompletedDriveToWork_beforeTrip_isBase() {
        let now = Date()
        let drive = driveLeg(from: "MCO", to: "SDF", arrivalCity: "Louisville",
                             start: now.addingTimeInterval(-3600 * 3), end: now.addingTimeInterval(-3600))
        let flight = TripLeg(
            id: "f1", tripId: "t1", type: .flight,
            startTime: now.addingTimeInterval(3600 * 2), endTime: now.addingTimeInterval(3600 * 4),
            airportCode: nil, city: nil, timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil,
            flightNumber: "DAL1", departureAirport: "SDF", arrivalAirport: "ATL",
            departureCity: "Louisville", arrivalCity: "Atlanta",
            tripDayNumber: 1, tripTotalDays: 3, delayMinutes: nil, airlineCode: nil, label: nil)
        let state = TripStateResolver.resolve(legs: [drive, flight], homeAirportCode: "MCO", baseAirportCode: "SDF", at: now)
        XCTAssertEqual(state?.displayStatus, .base)
        XCTAssertEqual(state?.currentAirport, "SDF")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run the single-class test command (or `-only-testing:.../test_resolveHomeArrival_includesDriveHomeLeg`). Expected: the three new tests FAIL.

- [ ] **Step 3: Include drives in the home-arrival scan**

`TripStateResolver.swift` lines 272-274 — change the filter from `($0.type == .flight || $0.type == .event)` to:

```swift
        guard let homeLeg = legs
            .filter({ ($0.type == .flight || $0.type == .event || $0.type == .drive) && $0.endTime > now && $0.arrivalAirport?.caseInsensitiveCompare(home) == .orderedSame })
            .min(by: { $0.startTime < $1.startTime })
```

- [ ] **Step 4: Treat a completed drive like a flight for gap location**

`TripStateResolver.swift` line 311 — change `if completedLeg.type == .flight {` to:

```swift
        if completedLeg.type == .flight || completedLeg.type == .drive {
```

- [ ] **Step 5: Infer home/base after a completed drive**

`TripStateResolver.swift` — in the `inferredHomeBase` closure (lines 378-390), add a `.drive` branch before `return nil`:

```swift
            if completedLeg.type == .drive, let apt = completedLeg.arrivalAirport {
                if let home = homeAirportCode, apt.caseInsensitiveCompare(home) == .orderedSame {
                    return .home
                }
                if let base = baseAirportCode, apt.caseInsensitiveCompare(base) == .orderedSame {
                    return .base
                }
            }
            return nil
        }()
```

- [ ] **Step 6: Run tests to verify they pass**

Run the single-class test command. Expected: all tests PASS (Task 1 + Task 2, no regressions).

- [ ] **Step 7: Commit (local only)**

```bash
git add Crewluv/Models/TripStateResolver.swift CrewluvTests/CommuteDriveSupportTests.swift
git commit -m "feat(crewluv): drives drive Back Home In + home/base gap resolution"
```

---

## Task 3: Narrative phase-1 ("heads to work" / "heads home")

**Files:**
- Modify: `Crewluv/Views/Status/NarrativeCardView.swift` — `homeNarrative` (line 97), `nextHomeEvent` (574-581); add `nextDriveToWork` helper.

> SwiftUI view — verified by build + simulator (Task 7).

- [ ] **Step 1: Add the `nextDriveToWork` helper**

Insert near `activeDriveLeg()` (added in Task 1, after line ~163):

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

- [ ] **Step 2: Phase-1 "heads to work" while home**

At the very top of `homeNarrative` (immediately after `private var homeNarrative: Text {`, line 97), insert:

```swift
    private var homeNarrative: Text {
        // Commuter about to drive to work: surface the drive countdown (phase 1).
        if let drive = nextDriveToWork() {
            let destCity = drive.arrivalCity
                ?? AirportDataProvider.shared.airportInfo(forIataCode: drive.arrivalAirport ?? "")?.city
                ?? "work"
            let depTimeStr = formattedLocalTime(drive.startTime)
            return Text("\(name) is home — heads to work in \(Text(destCity).bold()) in \(countdownText(to: drive.startTime)) at \(Text(depTimeStr).bold()).")
        }

        let hasPrevTrip = status.lastTripDurationDays != nil
```

- [ ] **Step 3: Let `nextHomeEvent` match a drive home (phase-1 at base)**

Change `nextHomeEvent()` (lines 574-581) — the predicate `$0.type == .event` becomes `($0.type == .event || $0.type == .drive)`:

```swift
    private func nextHomeEvent() -> TripLeg? {
        guard let home = status.homeAirportCode, !home.isEmpty else { return nil }
        return sortedTripLegs.first(where: {
            ($0.type == .event || $0.type == .drive)
            && $0.startTime > now
            && $0.arrivalAirport?.caseInsensitiveCompare(home) == .orderedSame
        })
    }
```

> This makes `baseNarrative`'s existing "heads home to X in <countdown>" copy fire for a commuter at base with an upcoming drive home.

- [ ] **Step 4: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit (local only)**

```bash
git add Crewluv/Views/Status/NarrativeCardView.swift
git commit -m "feat(crewluv): phase-1 heads-to-work / heads-home narrative for drives"
```

---

## Task 4: Timeline row — drive icon, color, title, homebound border

**Files:**
- Modify: `Crewluv/Views/Schedule/TimelineRowView.swift` — `isHomebound` (18-29), `staticIconName` (40-58), `iconName` (147-166), `iconColor` (168-187), `title` (191-236)

> SwiftUI view — verified by build + simulator (Task 7).

- [ ] **Step 1: Count a drive-home as homebound (green border)**

`isHomebound` (lines 18-29) — update the flight branch to include drive:

```swift
        if leg.type == .flight || leg.type == .drive, let arrival = leg.arrivalAirport {
            return arrival.caseInsensitiveCompare(home) == .orderedSame
        }
```

- [ ] **Step 2: Drive icon in both icon switches**

In `staticIconName` (40-58) add before `default`:

```swift
        case .drive:      return "car.fill"
        default:          return "clock"
```

In `iconName(isActive:)` (147-166) add before `default`:

```swift
        case .drive:      return "car.fill"
        default:          return "clock"
```

- [ ] **Step 3: Drive color**

In `iconColor` (168-187) add before `default`:

```swift
        case .drive:      return isHomebound ? .green : .blue
        default:          return .gray
```

- [ ] **Step 4: Drive title**

In `title` (191-236) add before `default`:

```swift
        case .drive:
            let prefix = leg.label ?? "Driving"
            let route = [leg.departureAirport, leg.arrivalAirport]
                .compactMap { $0 }
                .joined(separator: " → ")
            return route.isEmpty ? prefix : "\(prefix): \(route)"

        default:
            return "On Duty"
```

- [ ] **Step 5: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit (local only)**

```bash
git add Crewluv/Views/Schedule/TimelineRowView.swift
git commit -m "feat(crewluv): timeline row renders drive legs (car, route, homebound border)"
```

---

## Task 5: Calendar — drive maps to off-duty (not silent on-duty)

**Files:**
- Modify: `Crewluv/Models/CalendarDataBuilder.swift:208-214`

- [ ] **Step 1: Add the explicit `.drive` case**

In `buildSegments`, change the category switch (208-214) to add a `.drive` case:

```swift
                let category: CalendarBarSegment.Category = switch leg.type {
                case .layover: .offDuty
                case .drive: .offDuty   // personal commute time — not duty (dedicated category is future polish)
                case .reserve, .hotStandby: .reserve
                case .event: .training
                case .flight where leg.tripId == nil: .jumpseat
                default: .onDuty
                }
```

- [ ] **Step 2: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit (local only)**

```bash
git add Crewluv/Models/CalendarDataBuilder.swift
git commit -m "feat(crewluv): calendar shows drive legs as off-duty, not on-duty"
```

---

## Task 6: Document drive exclusion from layover-overlap trimming

**Files:**
- Modify: `Crewluv/Models/SharedPilotStatus.swift:199-204`

> `adjustLayoversForOverlappingFlights` only trims `.layover/.home/.base` legs and only when a `.flight` overlaps — `.drive` is already neither trimmed nor a trimmer. Record the decision.

- [ ] **Step 1: Add the clarifying comment**

Insert the comment just before `return legs.map { leg in` (line 203):

```swift
    private static func adjustLayoversForOverlappingFlights(_ legs: [TripLeg]) -> [TripLeg] {
        let flights = legs.filter { $0.type == .flight }
        guard !flights.isEmpty else { return legs }

        // `.drive` legs are intentionally excluded from overlap trimming, on both
        // sides: a base<->home commute drive lives in a >24h between-trips gap, never
        // inside a layover, so it neither trims nor is trimmed by flights.
        return legs.map { leg in
            guard leg.type == .layover || leg.type == .home || leg.type == .base else { return leg }
```

- [ ] **Step 2: Build**

Run the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit (local only)**

```bash
git add Crewluv/Models/SharedPilotStatus.swift
git commit -m "docs(crewluv): note drive legs are excluded from layover overlap trimming"
```

---

## Task 7: Full test pass + simulator verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full Crewluv test suite**

Run the full test command (no `-only-testing`). Expected: all tests PASS, including `CommuteDriveSupportTests` (8 tests) and the pre-existing suite (no regressions).

- [ ] **Step 2: Temporarily add a demo drive to confirm rendering (manual)**

Add a `.drive` leg (SDF→MCO, arrivalCity "Orlando", active now) to `SharedPilotStatus.demo` (near line 237). Build + run on the simulator (XcodeBuildMCP `build_run_sim`, then `screenshot`).
Expected: narrative card reads "…is driving home to **Orlando** — back in …" with a green car icon; the timeline row shows "Driving: SDF → MCO" with a car icon and green homebound border.

- [ ] **Step 3: Revert the temporary demo change**

```bash
git checkout Crewluv/Models/SharedPilotStatus.swift
```

(Restores demo data; Task 6's comment is already committed, so only the temporary demo leg is dropped.)

- [ ] **Step 4: Confirm backward compatibility (manual)**

With the demo drive removed, run once more and confirm a no-drive beacon renders exactly as before.

- [ ] **Step 5: Final state**

Run: `git log --oneline feature/commute-stage1-crewluv-drive -8`
Expected: per-task commits present. **Do not push** — await the user's go-ahead.

---

## Self-Review (completed)

- **Spec coverage:** item 14 (`.drive` LegType → T1), 15 (statuses → T1), 16 (`TripStateResolver`: active drive → T1; resolveHomeArrival + resolveGap → T2) ✓; 17 (`NarrativeCardView`: driving copy/icon/color → T1, phase-1 → T3) ✓; 18 (`TimelineRowView` → T4) ✓; 19 (`CalendarDataBuilder` → T5) ✓; 20 (`SharedPilotStatus` overlap → T6) ✓. §9.2 statuses + §10 two-phase display covered by T1/T2/T3.
- **Compile-safety:** every new enum case and its forced exhaustive switches land in T1; T2–T6 add only logic, so the module builds after each task. T1 Step 7 explicitly hunts for any other exhaustive switch over the new types.
- **Type consistency:** `driveStatus(...)`, `activeDriveLeg()`, `nextDriveToWork()`, `nextHomeEvent()`, cases `.drive`/`.drivingHome`/`.drivingToWork` used identically across tasks.
- **Backward compatibility:** every change gated on `leg.type == .drive` or a new status; no-drive beacons unaffected.

---

## Subsequent stages (written just-in-time, against current Duty code)

- **Plan 2 — Duty `Commute` data layer:** `Commute` `@Model` + `CommuteDirection`, `Syncable` conformance (mirror `Jumpseat`), `CommuteRouteStore` (default 2h), `SyncSchema.allModels` registration, `CommuteRow` DTO, `SupabaseSyncEngine` registration, the `commutes` Postgres table + `commutes_owner` RLS (mirror `jumpseats`). Spec §6.1–6.3, §12 items 1,2,4,5,11,12,13.
- **Plan 3 — Duty status emission + suggestion engine + UI:** `.drive` in Duty's `TripLeg`, `PartnerStatusGenerator` (emit drive leg + `Driving Home`/`Driving to Work` displayStatus + countdown fields), `HiddenEventsManager`, `CommuteSuggestionEngine` (gates + de-dup/convert), Partner Sharing "Commutes" section + add/edit sheets, cleanup service. Spec §7, §11, §12 items 3,6,7,8,9,10.
- **Plan 4 — Backend provisioning + release:** deploy `CD_Commute` to CloudKit production; create the `commutes` table/RLS in Supabase; release sequencing + release notes. Spec §13, §16.

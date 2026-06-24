# Commute — Stage 3a: Duty Status Emission — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox (`- [ ]`) steps.

**Goal:** Make a `Commute` visible to the partner once it exists: emit a `.drive` `TripLeg` into the beacon's `tripLegsJSON`, set the `Driving Home`/`Driving to Work` displayStatus while a drive is in progress, and teach `HiddenEventsManager` about commutes. No suggestion engine, no UI (those are 3b/3c). Testable by inserting a `Commute` directly.

**Architecture:** `Commute` is a standalone record (like a manual event / standalone jumpseat). `PartnerStatusGenerator.buildTripLegsJSON` already fetches standalone manual events / jumpseats and appends them as `TripLeg`s — we add a parallel block that fetches non-deleted, non-hidden `Commute`s and appends `.drive` legs (`tripId: nil`, `arrivalAirport` = the drive's destination so Crewluv derives direction). During an active drive the displayStatus override is set to the spec strings `Driving Home` / `Driving to Work` (which Crewluv's `PilotDisplayStatus` bridge already maps — Stage 1). Crewluv also computes the "Back Home In" countdown and the phase-1 "heads to work" copy from the emitted `.drive` leg (Stage 1), so the beacon's scalar countdown fields need no change here.

**Tech Stack:** Swift, SwiftData, XCTest.

**Spec:** Crewluv repo `docs/superpowers/specs/2026-06-22-commuter-home-base-commutes-design.md` §7 (emission parts), §9.3, §12 items 5, 6, 7 (partial — emission only). Pairs with Stage 1 (Crewluv `.drive` rendering) + Stage 2 (Commute model/sync).

---

## Working context & safety

- **Repo/branch:** `/Users/toddanderson/Dev/Duty`, **directly on `feature/supabase-account-backend`** (no new branch). **Local commits only — do NOT push.**
- **Untouched WIP:** never `git add` `Duty/Utils/PartnerBeacon/PilotStatusBeaconManager.swift`, `Duty/Utils/SyncGuidanceCopy.swift`, its test, or `project.pbxproj`. Stage only named files. (`DutyTests` is a synchronized group — new test files auto-join, no pbxproj edit.)
- **Tests:** use TARGETED test classes (`-only-testing:`), NOT the full suite (it's slow and the simulator can flake under repeated builds). One full run is the user's call at the end.
- **Verified facts** (from reading the code): `PartnerStatusGenerator` has `private let modelContext: ModelContext`; `airportDataProvider` + `timezoneForAirport(_:)` are available; the standalone manual-event append block is lines 762–806; the insertion point for a commute block is **after the TrainingEvents block (line ~840), before the "Final breakdown" at ~842**; standalone legs use `tripId: nil`; the override cascade is lines 70–84 (fires when `displayStatus == "Home"`).

**Commands** (from `/Users/toddanderson/Dev/Duty`):
- Build: `xcodebuild -project Duty.xcodeproj -scheme Duty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Targeted test: `xcodebuild test -project Duty.xcodeproj -scheme Duty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:DutyTests/<Class>`

---

## File Structure

| File | Change |
|---|---|
| `Duty/ViewModels/HiddenEventsManager.swift` | Add `Commute` to deriveSet / isCommuteHidden / applyHidden / clearAll |
| `Duty/Models/TripLeg.swift` | Add `case drive` to `LegType` |
| `Duty/Utils/PartnerBeacon/PartnerStatusGenerator.swift` | Emit `.drive` legs in `buildTripLegsJSON`; `activeCommuteStatus` + override-cascade entry |
| `DutyTests/HiddenEventsManagerCommuteTests.swift` | **New** |
| `DutyTests/CommuteStatusEmissionTests.swift` | **New** |

---

## Task 1: `HiddenEventsManager` Commute support

Must come first — the emission block (Task 2) calls `HiddenEventsManager.isCommuteHidden(...)`.

**Files:** Modify `Duty/ViewModels/HiddenEventsManager.swift`; Create `DutyTests/HiddenEventsManagerCommuteTests.swift`.

- [ ] **Step 1: Failing test** — create `DutyTests/HiddenEventsManagerCommuteTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

final class HiddenEventsManagerCommuteTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    @MainActor
    func test_deriveSet_includesHiddenCommute() throws {
        let ctx = try makeContext()
        let c = Commute()
        c.hiddenFromTimeline = true
        ctx.insert(c)
        try ctx.save()
        let ids = HiddenEventsManager.deriveSet(from: ctx)
        XCTAssertTrue(ids.contains("commute_\(c.id)"))
        XCTAssertTrue(HiddenEventsManager.isCommuteHidden(c.id, in: ids))
    }

    @MainActor
    func test_deriveSet_excludesVisibleAndDeletedCommute() throws {
        let ctx = try makeContext()
        let visible = Commute()                       // hiddenFromTimeline defaults false
        let deletedHidden = Commute()
        deletedHidden.hiddenFromTimeline = true
        deletedHidden.deletedAt = Date()              // tombstoned → excluded
        ctx.insert(visible); ctx.insert(deletedHidden)
        try ctx.save()
        let ids = HiddenEventsManager.deriveSet(from: ctx)
        XCTAssertFalse(ids.contains("commute_\(visible.id)"))
        XCTAssertFalse(ids.contains("commute_\(deletedHidden.id)"))
    }

    @MainActor
    func test_applyHidden_togglesCommuteFlag() throws {
        let ctx = try makeContext()
        let c = Commute()
        ctx.insert(c)
        try ctx.save()
        XCTAssertTrue(HiddenEventsManager.applyHidden("commute_\(c.id)", true, in: ctx))
        XCTAssertTrue(c.hiddenFromTimeline)
        XCTAssertTrue(HiddenEventsManager.applyHidden("commute_\(c.id)", false, in: ctx))
        XCTAssertFalse(c.hiddenFromTimeline)
    }
}
```

- [ ] **Step 2: Run** `-only-testing:DutyTests/HiddenEventsManagerCommuteTests` → expect FAIL (`isCommuteHidden` undefined).

- [ ] **Step 3: Edit `HiddenEventsManager.swift`** — four additions mirroring the `manual_`/`jumpseat_` handling:

(a) In `deriveSet(from:)`, after the `ManualEvent` loop (the block ending at the `manual_\(m.id)` insert, ~line 144), add:
```swift
        for c in (try? ctx.fetch(FetchDescriptor<Commute>(
            predicate: #Predicate { $0.hiddenFromTimeline == true && $0.deletedAt == nil }))) ?? [] {
            ids.insert("commute_\(c.id)")
        }
```

(b) Add a static predicate alongside the other `is*Hidden` helpers (after `isManualEventHidden`, ~line 113):
```swift
    nonisolated static func isCommuteHidden(_ commuteId: String, in hiddenIDs: Set<String>) -> Bool {
        hiddenIDs.contains("commute_\(commuteId)")
    }
```

(c) In `applyHidden(_:_:in:)`, add a branch before the `vanTime_` branch (after the `manual_` branch, ~line 175):
```swift
        if id.hasPrefix("commute_") {
            let raw = String(id.dropFirst("commute_".count))
            guard let e = fetchLive(FetchDescriptor<Commute>(predicate: #Predicate { $0.id == raw && $0.deletedAt == nil }), ctx) else { return false }
            e.hiddenFromTimeline = hidden; return true
        }
```

(d) In `clearAll(in:)`, add (after the `ManualEvent` line, ~line 192):
```swift
        for c in (try? ctx.fetch(FetchDescriptor<Commute>(predicate: #Predicate { $0.hiddenFromTimeline == true && $0.deletedAt == nil }))) ?? [] { c.hiddenFromTimeline = false }
```

Also update the file header's "Event IDs follow…" comment list to include `"commute_<id>"`.

- [ ] **Step 4: Run** the test class → expect PASS (3 tests).

- [ ] **Step 5: Commit:**
```bash
git add Duty/ViewModels/HiddenEventsManager.swift DutyTests/HiddenEventsManagerCommuteTests.swift
git commit -m "feat(duty): HiddenEventsManager handles commute_ ids"
```

---

## Task 2: Emit `.drive` legs + `Driving Home`/`Driving to Work` status

**Files:** Modify `Duty/Models/TripLeg.swift`, `Duty/Utils/PartnerBeacon/PartnerStatusGenerator.swift`; Create `DutyTests/CommuteStatusEmissionTests.swift`.

- [ ] **Step 1: Failing test** — create `DutyTests/CommuteStatusEmissionTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

final class CommuteStatusEmissionTests: XCTestCase {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    /// A commuter (home != base) actively driving home → status "Driving Home"
    /// and a `.drive` leg in tripLegsJSON arriving at the home airport.
    @MainActor
    func test_activeDriveHome_emitsStatusAndLeg() throws {
        let ctx = try makeContext()
        let pilot = PilotInfo()
        pilot.baseRawValue = PilotBase.sdf.rawValue   // base SDF
        pilot.homeAirportCode = "MCO"                 // home MCO (commuter)
        ctx.insert(pilot)

        let now = Date()
        let c = Commute()
        c.fromAirport = "SDF"; c.toAirport = "MCO"
        c.direction = .toHome
        c.departureTimeZulu = now.addingTimeInterval(-3600)   // started 1h ago
        c.arrivalTimeZulu = now.addingTimeInterval(3600)      // arrives in 1h
        ctx.insert(c)
        try ctx.save()

        let status = PartnerStatusGenerator(modelContext: ctx).generateStatus(for: pilot)
        XCTAssertEqual(status.displayStatus, "Driving Home")

        let legs = try XCTUnwrap(decodeLegs(status.tripLegsJSON))
        let drive = try XCTUnwrap(legs.first { $0.type == .drive })
        XCTAssertEqual(drive.arrivalAirport, "MCO")
        XCTAssertEqual(drive.departureAirport, "SDF")
        XCTAssertEqual(drive.tripId, nil)
    }

    @MainActor
    func test_activeDriveToWork_emitsStatus() throws {
        let ctx = try makeContext()
        let pilot = PilotInfo()
        pilot.baseRawValue = PilotBase.sdf.rawValue
        pilot.homeAirportCode = "MCO"
        ctx.insert(pilot)
        let now = Date()
        let c = Commute()
        c.fromAirport = "MCO"; c.toAirport = "SDF"
        c.direction = .toWork
        c.departureTimeZulu = now.addingTimeInterval(-1800)
        c.arrivalTimeZulu = now.addingTimeInterval(1800)
        ctx.insert(c)
        try ctx.save()
        let status = PartnerStatusGenerator(modelContext: ctx).generateStatus(for: pilot)
        XCTAssertEqual(status.displayStatus, "Driving to Work")
    }

    /// A hidden commute must NOT appear as a leg or drive the status.
    @MainActor
    func test_hiddenCommute_notEmitted() throws {
        let ctx = try makeContext()
        let pilot = PilotInfo()
        pilot.baseRawValue = PilotBase.sdf.rawValue
        pilot.homeAirportCode = "MCO"
        ctx.insert(pilot)
        let now = Date()
        let c = Commute()
        c.fromAirport = "SDF"; c.toAirport = "MCO"; c.direction = .toHome
        c.departureTimeZulu = now.addingTimeInterval(-3600)
        c.arrivalTimeZulu = now.addingTimeInterval(3600)
        c.hiddenFromTimeline = true
        ctx.insert(c)
        try ctx.save()
        let status = PartnerStatusGenerator(modelContext: ctx).generateStatus(for: pilot)
        XCTAssertNotEqual(status.displayStatus, "Driving Home")
        let legs = decodeLegs(status.tripLegsJSON) ?? []
        XCTAssertFalse(legs.contains { $0.type == .drive })
    }

    private func decodeLegs(_ data: Data?) -> [TripLeg]? {
        guard let data else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        return try? dec.decode([TripLeg].self, from: data)
    }
}
```

> Before relying on `PilotInfo()` / `PilotBase.sdf` / `pilot.baseRawValue` in the test, the implementer must confirm those exact symbols by reading `Duty/Models/PilotInfo.swift` (the test was written from the model summary — adjust the setup to the real initializer/property names if they differ, keeping the assertions identical: status strings and the `.drive` leg).

- [ ] **Step 2: Run** `-only-testing:DutyTests/CommuteStatusEmissionTests` → expect FAIL (`.drive` undefined / no emission).

- [ ] **Step 3: Add `case drive` to `Duty/Models/TripLeg.swift`** — byte-identical to Crewluv's:
```swift
    enum LegType: String, Codable, Sendable {
        case flight, turn, layover, home, base
        case drive                       // ground commute (base <-> home)
        case reserve, hotStandby, event  // future
        case unknown                     // forward compat
```
Then **build** (`xcodebuild ... build`). If the compiler flags any exhaustive `switch` over `LegType` in Duty (unlikely — Duty produces legs), add a `.drive` case matching the nearest pattern and report it. Expect BUILD SUCCEEDED.

- [ ] **Step 4: Emit commute legs in `buildTripLegsJSON`** — in `PartnerStatusGenerator.swift`, immediately AFTER the TrainingEvents `debugLog` (~line 840) and BEFORE the `// Final breakdown` comment (~842), insert:
```swift
        // Include standalone Commutes (base<->home drives) as .drive legs.
        let commuteDescriptor = FetchDescriptor<Commute>(
            predicate: #Predicate<Commute> { $0.arrivalTimeZulu >= historyStart && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.departureTimeZulu, order: .forward)]
        )
        let commutes = (try? modelContext.fetch(commuteDescriptor)) ?? []
        var commuteLegsAdded = 0
        for c in commutes where !HiddenEventsManager.isCommuteHidden(c.id, in: hiddenIDs) {
            let depInfo = airportDataProvider.airportInfo(forIataCode: c.fromAirport)
            let arrInfo = airportDataProvider.airportInfo(forIataCode: c.toAirport)
            allLegs.append(TripLeg(
                id: "commute-\(c.id)",
                tripId: nil,
                type: .drive,
                startTime: c.departureTimeZulu,
                endTime: c.arrivalTimeZulu,
                airportCode: c.fromAirport,
                city: depInfo?.city,
                timezoneIdentifier: timezoneForAirport(c.fromAirport),
                arrivalTimezoneIdentifier: timezoneForAirport(c.toAirport),
                flightNumber: nil,
                departureAirport: c.fromAirport,
                arrivalAirport: c.toAirport,
                departureCity: depInfo?.city,
                arrivalCity: arrInfo?.city,
                tripDayNumber: nil,
                tripTotalDays: nil,
                delayMinutes: nil,
                airlineCode: nil,
                label: c.direction == .toHome ? "Driving home" : "Driving to work"
            ))
            commuteLegsAdded += 1
        }
        debugLog("[TripLegs] Commute legs added: \(commuteLegsAdded)")
```

- [ ] **Step 5: Active-commute displayStatus override** — add a helper near `activeManualEventStatus` (~line 1076):
```swift
    /// "Driving Home" / "Driving to Work" when a commute drive is in progress now.
    private func activeCommuteStatus(at now: Date, hiddenIDs: Set<String>) -> String? {
        let descriptor = FetchDescriptor<Commute>(
            predicate: #Predicate<Commute> { $0.deletedAt == nil },
            sortBy: [SortDescriptor(\.departureTimeZulu, order: .forward)]
        )
        guard let commutes = try? modelContext.fetch(descriptor) else { return nil }
        guard let active = commutes.first(where: {
            $0.departureTimeZulu <= now && now < $0.arrivalTimeZulu
                && !HiddenEventsManager.isCommuteHidden($0.id, in: hiddenIDs)
        }) else { return nil }
        return active.direction == .toHome ? "Driving Home" : "Driving to Work"
    }
```
Then wire it into the override cascade (the `if displayStatus == "Home" {` block, ~lines 70–84) — add it as the FIRST branch so an in-progress drive wins over the jumpseat/base inferences:
```swift
        if displayStatus == "Home" {
            if let driveStatus = activeCommuteStatus(at: now, hiddenIDs: hiddenIDs) {
                displayStatus = driveStatus
            } else if let meStatus = activeManualEventStatus(at: now, hiddenIDs: hiddenIDs) {
                displayStatus = meStatus
            } else if let teStatus = activeTrainingEventStatus(at: now, hiddenIDs: hiddenIDs) {
                displayStatus = teStatus
            } else if isCommutingHome(at: now, effectiveHomeAirport: pilotInfo.effectiveHomeAirportCode, hiddenIDs: hiddenIDs, nextTripStart: completeTrips.first(where: { $0.startDate > now })?.startDate) {
                displayStatus = "Commuting Home"
            }
            else if pilotInfo.base.rawValue != pilotInfo.effectiveHomeAirportCode,
                    let lastTrip = lastCompletedTrip,
                    lastTrip.endingAirport == pilotInfo.base.rawValue {
                displayStatus = "Base"
            }
        }
```
(The exact existing lines are quoted in the plan context — preserve the other branches verbatim; only add the new first `if`.)

- [ ] **Step 6: Run** `-only-testing:DutyTests/CommuteStatusEmissionTests` → PASS (3 tests). Then **build** → BUILD SUCCEEDED.

- [ ] **Step 7: Commit:**
```bash
git add Duty/Models/TripLeg.swift Duty/Utils/PartnerBeacon/PartnerStatusGenerator.swift DutyTests/CommuteStatusEmissionTests.swift
git commit -m "feat(duty): emit .drive legs + Driving Home/to Work status for commutes"
```

---

## Task 3: Targeted verification + review

- [ ] **Step 1:** Run BOTH new classes:
`-only-testing:DutyTests/HiddenEventsManagerCommuteTests -only-testing:DutyTests/CommuteStatusEmissionTests` → `** TEST SUCCEEDED **`. Plus a clean `build`.
- [ ] **Step 2:** `git status --short` (WIP untouched), `git log --oneline -2` (2 new local commits, not pushed).
- [ ] **Step 3:** (controller) dispatch spec + quality review over `git diff` of the 2 commits.

---

## Self-Review (completed)

- **Spec coverage:** `.drive` emission (Task 2), `Driving Home`/`Driving to Work` status (Task 2), HiddenEventsManager (Task 1). Crewluv already renders all of this (Stage 1) and derives countdowns from the `.drive` leg, so no beacon scalar-field change needed here. ✓
- **Status strings** exactly match Crewluv's `PilotDisplayStatus` bridge (`"Driving Home"`, `"Driving to Work"`). ✓
- **Hidden + deleted** commutes excluded from both the leg and the status (tests assert). ✓
- **Standalone pattern** mirrors the manual-event/jumpseat blocks (`tripId: nil`, `arrivalAirport` = destination so Crewluv derives direction). ✓
- **Compile-safety:** Task 1 (HiddenEventsManager) before Task 2 (emission uses `isCommuteHidden`); `.drive` enum add builds the app to catch any switch. ✓

## Deferred to later stages
- 3b: `CommuteSuggestionEngine` (gates/de-dup/convert) + orphan cleanup service.
- 3c: Partner Sharing "Commutes" UI (section + add/edit sheets).
- Optional polish: prefer `commute.arrivalTimeZulu` for the beacon's `homeArrivalTime` scalar (currently Crewluv recomputes "Back Home In" from the `.drive` leg, so this is belt-and-suspenders).

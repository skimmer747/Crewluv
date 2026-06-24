# Commute Stage 3b — Suggestion Engine + Orphan Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Duty's `CommuteSuggestionEngine` (pure read → proposes base⇄home drive commutes for the gaps between trips) and a `CommuteCleanupService` (soft-deletes orphaned commutes), wired into the existing post-launch cleanup.

**Architecture:** Two new pure/standalone types under `Duty/Utils/PartnerBeacon/`, plus one tiny `SoftDeleteService` overload and one call site in `DutyApp`. The engine never writes — it returns `[CommuteSuggestion]` value types; confirming a suggestion (creating a `Commute`) is Stage 3c's UI job. The cleanup soft-deletes via the existing `SoftDeleteService.tombstone` so the tombstone syncs out on both backends and the phantom drive vanishes from the partner timeline. All logic is unit-tested; the only untested piece is the one-line app wiring, verified by compile + the cleanup unit tests.

**Tech Stack:** Swift 5.9+, SwiftData, XCTest. iOS 17+. Duty repo (`/Users/toddanderson/Dev/Duty`), branch `feature/supabase-account-backend`.

---

## Repo & working rules (NON-NEGOTIABLE — read before any commit)

- **All code lands in the DUTY repo** at `/Users/toddanderson/Dev/Duty` on branch `feature/supabase-account-backend`. This plan file lives in the Crewluv repo (the spec/plans home).
- **Never push, never merge.** Local commits only.
- **Stage ONLY the files this plan names.** Do NOT `git add -A`. In particular, NEVER stage the user's parallel WIP: `Duty/Utils/PartnerBeacon/PilotStatusBeaconManager.swift`, `Duty/Utils/SyncGuidanceCopy.swift`, `DutyTests/SyncGuidanceCopyTests.swift`, or `.superpowers/`.
- **Never commit `Duty.xcodeproj/project.pbxproj`.** Verified: the Duty project uses `PBXFileSystemSynchronizedRootGroup`s, and `Duty/Utils/PartnerBeacon/` + `DutyTests/` are synchronized — new `.swift` files in them auto-join the target with no pbxproj edit.
- **Test runs are TARGETED** (the full suite is slow and the sim flakes):
  ```bash
  xcodebuild test -project /Users/toddanderson/Dev/Duty/Duty.xcodeproj -scheme Duty \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:DutyTests/<ClassName>
  ```
  A `server died` / `Invalid device state` failure with **0 assertion failures** is an infra flake — reset with `xcrun simctl shutdown all` and re-run targeted.
- **SwiftData test gotcha:** a `ModelContext` does NOT retain its `ModelContainer`. The test helper MUST retain the container in a stored property and clear it in `tearDown`, or in-memory `save()` traps (`EXC_BREAKPOINT`). The scaffolding below already does this.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `Duty/Utils/PartnerBeacon/CommuteSuggestion.swift` | The `CommuteSuggestion` value type + `Origin` enum + idempotency `id`. | Create |
| `Duty/Utils/PartnerBeacon/CommuteSuggestionEngine.swift` | Pure read engine: gaps → suggestions, four gates, convert detection. | Create |
| `Duty/Utils/PartnerBeacon/CommuteCleanupService.swift` | Soft-deletes commutes whose `sourceTripId` is absent/soft-deleted. | Create |
| `Duty/Utils/Sync/SoftDeleteService.swift` | Add `softDelete(_ commute:)` overload (mirrors the per-type overloads). | Modify |
| `Duty/App/DutyApp.swift` | One call site in the 60s post-launch cleanup wave (both backends). | Modify |
| `DutyTests/CommuteSuggestionEngineTests.swift` | Unit tests for all four gates, convert, idempotency. | Create |
| `DutyTests/CommuteCleanupServiceTests.swift` | Unit tests for orphan / kept / idempotent cleanup. | Create |

---

## Verified facts this plan relies on (do not re-derive)

**Models (Duty):**
- `Commute` (`Duty/Models/Commute.swift`): `init() {}` only; props `id: String`, `fromAirport: String`, `toAirport: String`, `directionRaw: String`, `departureTimeZulu: Date`, `arrivalTimeZulu: Date`, `driveDurationSeconds: Double = 7200`, `sourceTripId: String? = nil`, `hiddenFromTimeline: Bool = false`, `createdAt`, `lastModifiedAt`, `deletedAt: Date? = nil`, `needsPush: Bool = false`; computed `var direction: CommuteDirection { get/set }`. `enum CommuteDirection: String, Codable, Sendable { case toHome, toWork }`.
- `Trip` (`Duty/Models/Trip.swift`): `var id: String`, `var startDate: Date`, `var endDate: Date`, `var deletedAt: Date? = nil`; `@Transient var startingAirport: String?` and `var endingAirport: String?` are **computed from** `dutyPeriods → flights` (first flight's `departure` / last flight's `arrival`, skipping tombstones). Parametrized init exists: `Trip(id:startDate:endDate:dutyTime:blockTime:creditTime:days:tafb:base:)`. `@Relationship var dutyPeriods: [DutyPeriod]? = []`.
- `PilotInfo` (`Duty/Models/PilotInfo.swift`): `var baseRawValue: String`, computed `var base: PilotBase { get/set }` (`base.rawValue` → IATA), `var homeAirportCode: String? = nil`, computed `var effectiveHomeAirportCode: String { homeAirportCode ?? base.rawValue }`. `PilotBase` is a `String` enum (`.sdf="SDF"`, …).
- `Jumpseat` (`Duty/Models/Jumpseat.swift`): `init() {}`; `var origin: String`, `var destination: String`, `var departureTimeZulu: Date`, `var arrivalTimeZulu: Date`, `var sourceTripId: String? = nil`, `var deletedAt: Date? = nil`, `var hiddenFromTimeline: Bool? = nil`, `var id: String`.
- `ManualEvent` (`Duty/Models/ManualEvent.swift`): `init() {}`; `var id: String`, `var title: String`, `var startTimeUTC: Date`, `var endTimeUTC: Date`, `var deletedAt: Date? = nil`.
- `DutyPeriod(day:dayOfWeek:startTime:endTime:dutyTime:blockTime:restTime:)`; `@Relationship var trip: Trip?`, `@Relationship var flights: [Flight]?`. `Flight(flightNumber:departure:arrival:blockOutTime:takeOffTime:landingTime:blockInTime:aircraftType:)`; `@Relationship var dutyPeriod: DutyPeriod?`. Relationships are NOT set in either init — wire them manually after construction.

**Helpers / services (Duty):**
- `CommuteRouteStore.duration(from:to:) -> TimeInterval` (returns remembered or `defaultDuration = 7200`). `CommuteRouteStore.defaultDuration`.
- `HiddenEventsManager` (`Duty/ViewModels/HiddenEventsManager.swift`, all `nonisolated static`): `loadHiddenIDs() -> Set<String>`, `isJumpseatHidden(_:in:) -> Bool` (`"jumpseat_<id>"`), `deriveSet(from:) -> Set<String>`, `writeCache(_:)`.
- `SoftDeleteService` (`Duty/Utils/Sync/SoftDeleteService.swift`): `static func tombstone(_ model: any Syncable, at now: Date)` sets `materializeSyncID()`, `deletedAt = now`, `needsPush = true`. Per-type `static func softDelete(_ trip: Trip, at now: Date = Date())` etc. exist.
- `SyncCoordinator.shared.isSyncing`, `SupabaseSyncEngine.shared.isSyncInFlight`, `DutyApp.hasFreshIncompleteOrRecoveryTrips(in:)` (**private static** — only callable from inside `DutyApp`), global `debugLog(_:)`.
- App launch cleanups live in `DutyApp.swift`; the 60-second wave (`DispatchQueue.main.asyncAfter(deadline: .now() + 60.0)`, ~line 153) runs `JumpseatCleanupService` + `DatabaseCleanupService` inside a `Task(priority: .background) { @MainActor in … }`, gated `if SyncBackendMode.current == .icloud { … }`.

**Test scaffolding pattern (from `DutyTests/CommuteStatusEmissionTests.swift` / `HiddenEventsManagerCommuteTests.swift`):** retain the in-memory `ModelContainer` in a stored property; `Schema(SyncSchema.allModels)`; after `ctx.save()` call `HiddenEventsManager.writeCache(HiddenEventsManager.deriveSet(from: ctx))` so off-main reads of the hidden cache are deterministic (and to reset cross-test UserDefaults pollution).

---

## Design decisions (locked; flagged for the spec-compliance reviewer)

1. **Pure, time-independent.** `suggestions(for:)` takes only the `PilotInfo` and reads the local store. It does **not** take `now` and does **not** filter to future gaps — the spec's four gates (§7) are not relative to "now," and a pure function is idempotent and trivially testable. Filtering to upcoming gaps for display is a Stage 3c (UI/caller) concern.
2. **Idempotency key** = `sourceTripId | direction.rawValue | fromAirport | toAirport` (spec §7), exposed as `CommuteSuggestion.id`. Suggestions are de-duped by this key within a single call (defensive; can't collide in a sorted unique trip list, but the spec demands "never duplicated").
3. **Anchor trip:** `toHome` is anchored to the trip that just ended at base (`prev.id`); `toWork` to the trip about to start at base (`next.id`). This matches `Commute.sourceTripId` semantics ("the trip this commute brackets").
4. **Convert vs fresh:** a suggestion's `origin` is `.convert(manualEventID:)` when a live `ManualEvent` whose title matches `driv`/`car`/`truck` overlaps the gap window (`startTimeUTC ∈ [gapStart, gapEnd]`); otherwise `.fresh`. The engine only *flags* the convert opportunity — the actual "carry over location / add the matching return drive" write happens on confirm in Stage 3c. An existing managed `Commute` or a bridging jumpseat **suppresses** the suggestion entirely (no convert, no fresh).
5. **Jumpseat bridging match:** `toHome` is covered by a standalone (`sourceTripId == nil`), visible (`!isJumpseatHidden`), live (`deletedAt == nil`) jumpseat whose `destination == home` arriving in the gap; `toWork` by one whose `origin == home` departing in the gap. Mirrors the proven `findHomeJumpseatNearTripEnd` / `isCommutingHome` style in `PartnerStatusGenerator`. Hidden jumpseats do NOT suppress (the user hid them, so they likely still want the drive).
6. **Cleanup is pure; gating is the caller's job.** `CommuteCleanupService.cleanupOrphanedCommutes(in:)` operates on whatever's in the context and soft-deletes orphans; the sync/recovery safety gate lives at the `DutyApp` call site (mirroring how `DatabaseCleanupService` is gated). Manual commutes (`sourceTripId == nil`) are never touched.

---

## Task 1: `CommuteSuggestionEngine` + `CommuteSuggestion`

**Files:**
- Create: `Duty/Utils/PartnerBeacon/CommuteSuggestion.swift`
- Create: `Duty/Utils/PartnerBeacon/CommuteSuggestionEngine.swift`
- Test: `DutyTests/CommuteSuggestionEngineTests.swift`

- [ ] **Step 1: Write the failing test file**

Create `DutyTests/CommuteSuggestionEngineTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

final class CommuteSuggestionEngineTests: XCTestCase {

    /// Retained for the lifetime of each test: a `ModelContext` does not keep its
    /// owning `ModelContainer` alive, so the container must outlive the context or
    /// the in-memory store is torn down before `save()` and SwiftData traps.
    private var container: ModelContainer?

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        self.container = container
        return container.mainContext
    }

    override func setUp() {
        super.setUp()
        // CommuteRouteStore is backed by SharedUserDefaults (persists across tests in
        // the process). Clear the routes these tests assert on so the 2h default applies
        // deterministically regardless of test ordering.
        CommuteRouteStore.clear(from: "SDF", to: "MCO")
        CommuteRouteStore.clear(from: "MCO", to: "SDF")
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    /// Resets the device-local hidden-id cache to match `ctx` (also clears any
    /// pollution left in UserDefaults by other tests in the process).
    private func syncHiddenCache(from ctx: ModelContext) {
        HiddenEventsManager.writeCache(HiddenEventsManager.deriveSet(from: ctx))
    }

    // MARK: - Fixtures

    /// SDF-based commuter whose home is MCO, unless overridden.
    private func makeCommuterPilot(base: String = "SDF", home: String? = "MCO",
                                   in ctx: ModelContext) -> PilotInfo {
        let pilot = PilotInfo()
        pilot.baseRawValue = base
        pilot.homeAirportCode = home
        ctx.insert(pilot)
        return pilot
    }

    /// Builds a Trip with one DutyPeriod and one Flight so `startingAirport` == `from`
    /// and `endingAirport` == `to`. Inserts and wires both sides of each relationship.
    @discardableResult
    private func makeTrip(id: String, start: Date, end: Date, from: String, to: String,
                          in ctx: ModelContext) -> Trip {
        let trip = Trip(id: id, startDate: start, endDate: end,
                        dutyTime: 0, blockTime: 0, creditTime: 0, days: 1, tafb: 0, base: from)
        ctx.insert(trip)
        let dp = DutyPeriod(day: 1, dayOfWeek: "MON", startTime: start, endTime: end,
                            dutyTime: 0, blockTime: 0, restTime: 0)
        ctx.insert(dp)
        dp.trip = trip
        let flight = Flight(flightNumber: "1", departure: from, arrival: to,
                            blockOutTime: start, takeOffTime: start,
                            landingTime: end, blockInTime: end, aircraftType: "76F")
        ctx.insert(flight)
        flight.dutyPeriod = dp
        dp.flights = [flight]
        trip.dutyPeriods = [dp]
        return trip
    }

    @discardableResult
    private func makeJumpseat(origin: String, destination: String,
                             departure: Date, arrival: Date,
                             sourceTripId: String? = nil, hidden: Bool = false,
                             in ctx: ModelContext) -> Jumpseat {
        let js = Jumpseat()
        js.origin = origin
        js.destination = destination
        js.departureTimeZulu = departure
        js.arrivalTimeZulu = arrival
        js.sourceTripId = sourceTripId
        js.hiddenFromTimeline = hidden
        ctx.insert(js)
        return js
    }

    @discardableResult
    private func makeCommute(sourceTripId: String, direction: CommuteDirection,
                            from: String, to: String, in ctx: ModelContext) -> Commute {
        let c = Commute()
        c.fromAirport = from
        c.toAirport = to
        c.direction = direction
        c.sourceTripId = sourceTripId
        ctx.insert(c)
        return c
    }

    @discardableResult
    private func makeManualEvent(title: String, start: Date, end: Date,
                                in ctx: ModelContext) -> ManualEvent {
        let e = ManualEvent()
        e.title = title
        e.startTimeUTC = start
        e.endTimeUTC = end
        ctx.insert(e)
        return e
    }

    /// Two SDF-anchored trips with a 48h gap between them:
    /// prev = …→SDF (ends at base), next = SDF→… (starts at base).
    /// Returns (prev, next, gapStart, gapEnd).
    @discardableResult
    private func makeAnchoredGap(in ctx: ModelContext)
        -> (prev: Trip, next: Trip, gapStart: Date, gapEnd: Date) {
        let day: TimeInterval = 24 * 60 * 60
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let prevStart = base
        let prevEnd = base.addingTimeInterval(2 * day)        // prev ends here
        let nextStart = prevEnd.addingTimeInterval(2 * day)   // 48h gap > 24h
        let nextEnd = nextStart.addingTimeInterval(2 * day)
        let prev = makeTrip(id: "prev", start: prevStart, end: prevEnd,
                            from: "DFW", to: "SDF", in: ctx)   // lands at base
        let next = makeTrip(id: "next", start: nextStart, end: nextEnd,
                            from: "SDF", to: "DFW", in: ctx)   // starts at base
        return (prev, next, prevEnd, nextStart)
    }

    // MARK: - Gate 1: commuter

    @MainActor
    func test_nonCommuter_returnsNoSuggestions() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(base: "SDF", home: nil, in: ctx) // effectiveHome == base
        _ = makeAnchoredGap(in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - Gate 2: gap threshold

    @MainActor
    func test_gapUnder24h_returnsNoSuggestions() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let prevEnd = base.addingTimeInterval(2 * 24 * 3600)
        makeTrip(id: "prev", start: base, end: prevEnd, from: "DFW", to: "SDF", in: ctx)
        let nextStart = prevEnd.addingTimeInterval(12 * 3600)            // only 12h gap
        makeTrip(id: "next", start: nextStart, end: nextStart.addingTimeInterval(2 * 24 * 3600),
                 from: "SDF", to: "DFW", in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertTrue(suggestions.isEmpty)
    }

    // MARK: - Gate 3 + emission

    @MainActor
    func test_qualifyingGap_suggestsDriveHomeAndDriveToWork() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let (prev, next, gapStart, gapEnd) = makeAnchoredGap(in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx)

        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertEqual(suggestions.count, 2)

        let toHome = try XCTUnwrap(suggestions.first { $0.direction == .toHome })
        XCTAssertEqual(toHome.sourceTripId, prev.id)
        XCTAssertEqual(toHome.fromAirport, "SDF")
        XCTAssertEqual(toHome.toAirport, "MCO")
        XCTAssertEqual(toHome.departureTimeZulu, gapStart)
        XCTAssertEqual(toHome.driveDurationSeconds, 7200)
        XCTAssertEqual(toHome.arrivalTimeZulu, gapStart.addingTimeInterval(7200))
        XCTAssertEqual(toHome.origin, .fresh)

        let toWork = try XCTUnwrap(suggestions.first { $0.direction == .toWork })
        XCTAssertEqual(toWork.sourceTripId, next.id)
        XCTAssertEqual(toWork.fromAirport, "MCO")
        XCTAssertEqual(toWork.toAirport, "SDF")
        XCTAssertEqual(toWork.arrivalTimeZulu, gapEnd)
        XCTAssertEqual(toWork.departureTimeZulu, gapEnd.addingTimeInterval(-7200))
        XCTAssertEqual(toWork.origin, .fresh)
    }

    @MainActor
    func test_gapNotBaseAnchored_returnsNoSuggestions() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let prevEnd = base.addingTimeInterval(2 * 24 * 3600)
        makeTrip(id: "prev", start: base, end: prevEnd, from: "DFW", to: "DFW", in: ctx) // ends DFW
        let nextStart = prevEnd.addingTimeInterval(2 * 24 * 3600)
        makeTrip(id: "next", start: nextStart, end: nextStart.addingTimeInterval(2 * 24 * 3600),
                 from: "DFW", to: "DFW", in: ctx) // starts DFW
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertTrue(suggestions.isEmpty)
    }

    @MainActor
    func test_suggestions_areIdempotent() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        _ = makeAnchoredGap(in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx)
        let engine = CommuteSuggestionEngine(modelContext: ctx)
        XCTAssertEqual(engine.suggestions(for: pilot), engine.suggestions(for: pilot))
    }

    // MARK: - Gate 4a: existing managed Commute

    @MainActor
    func test_existingToHomeCommute_suppressesToHomeOnly() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let (prev, _, _, _) = makeAnchoredGap(in: ctx)
        makeCommute(sourceTripId: prev.id, direction: .toHome, from: "SDF", to: "MCO", in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertNil(suggestions.first { $0.direction == .toHome })
        XCTAssertNotNil(suggestions.first { $0.direction == .toWork })
    }

    // MARK: - Gate 4b: bridging jumpseat

    @MainActor
    func test_bridgingHomeJumpseat_suppressesToHome() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let (_, _, gapStart, gapEnd) = makeAnchoredGap(in: ctx)
        // Standalone JS arriving home (MCO) inside the gap → no drive-home needed.
        makeJumpseat(origin: "SDF", destination: "MCO",
                     departure: gapStart.addingTimeInterval(3600),
                     arrival: gapStart.addingTimeInterval(2 * 3600),
                     in: ctx)
        _ = gapEnd
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertNil(suggestions.first { $0.direction == .toHome })
        XCTAssertNotNil(suggestions.first { $0.direction == .toWork })
    }

    @MainActor
    func test_bridgingFromHomeJumpseat_suppressesToWork() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let (_, _, _, gapEnd) = makeAnchoredGap(in: ctx)
        // Standalone JS leaving home (MCO) inside the gap → no drive-to-work needed.
        makeJumpseat(origin: "MCO", destination: "SDF",
                     departure: gapEnd.addingTimeInterval(-2 * 3600),
                     arrival: gapEnd.addingTimeInterval(-3600),
                     in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertNil(suggestions.first { $0.direction == .toWork })
        XCTAssertNotNil(suggestions.first { $0.direction == .toHome })
    }

    @MainActor
    func test_hiddenBridgingJumpseat_doesNotSuppress() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let (_, _, gapStart, _) = makeAnchoredGap(in: ctx)
        makeJumpseat(origin: "SDF", destination: "MCO",
                     departure: gapStart.addingTimeInterval(3600),
                     arrival: gapStart.addingTimeInterval(2 * 3600),
                     hidden: true, in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx) // picks up hiddenFromTimeline == true → "jumpseat_<id>"
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertNotNil(suggestions.first { $0.direction == .toHome })
    }

    @MainActor
    func test_tripSourcedJumpseat_doesNotSuppress() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let (_, _, gapStart, _) = makeAnchoredGap(in: ctx)
        makeJumpseat(origin: "SDF", destination: "MCO",
                     departure: gapStart.addingTimeInterval(3600),
                     arrival: gapStart.addingTimeInterval(2 * 3600),
                     sourceTripId: "prev", in: ctx) // not standalone
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        XCTAssertNotNil(suggestions.first { $0.direction == .toHome })
    }

    // MARK: - Convert flow

    func test_titleSuggestsDriving_keywordMatrix() {
        XCTAssertTrue(CommuteSuggestionEngine.titleSuggestsDriving("Driving home"))
        XCTAssertTrue(CommuteSuggestionEngine.titleSuggestsDriving("DRIVE to base"))
        XCTAssertTrue(CommuteSuggestionEngine.titleSuggestsDriving("Rental car"))
        XCTAssertTrue(CommuteSuggestionEngine.titleSuggestsDriving("U-Haul truck"))
        XCTAssertFalse(CommuteSuggestionEngine.titleSuggestsDriving("Dentist appointment"))
        XCTAssertFalse(CommuteSuggestionEngine.titleSuggestsDriving(""))
    }

    @MainActor
    func test_drivingManualEventInGap_marksConvert() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let (_, _, gapStart, _) = makeAnchoredGap(in: ctx)
        let event = makeManualEvent(title: "Driving home",
                                    start: gapStart.addingTimeInterval(3600),
                                    end: gapStart.addingTimeInterval(2 * 3600), in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        let toHome = try XCTUnwrap(suggestions.first { $0.direction == .toHome })
        XCTAssertEqual(toHome.origin, .convert(manualEventID: event.id))
    }

    @MainActor
    func test_nonDrivingManualEventInGap_staysFresh() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let (_, _, gapStart, _) = makeAnchoredGap(in: ctx)
        makeManualEvent(title: "Dentist appointment",
                        start: gapStart.addingTimeInterval(3600),
                        end: gapStart.addingTimeInterval(2 * 3600), in: ctx)
        try ctx.save()
        syncHiddenCache(from: ctx)
        let suggestions = CommuteSuggestionEngine(modelContext: ctx).suggestions(for: pilot)
        let toHome = try XCTUnwrap(suggestions.first { $0.direction == .toHome })
        XCTAssertEqual(toHome.origin, .fresh)
    }
}
```

- [ ] **Step 2: Run the test — verify it FAILS to compile**

Run:
```bash
xcodebuild test -project /Users/toddanderson/Dev/Duty/Duty.xcodeproj -scheme Duty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DutyTests/CommuteSuggestionEngineTests
```
Expected: build failure — `cannot find 'CommuteSuggestionEngine' in scope` / `cannot find type 'CommuteSuggestion'`.

- [ ] **Step 3: Create `CommuteSuggestion.swift`**

Create `Duty/Utils/PartnerBeacon/CommuteSuggestion.swift`:

```swift
//  CommuteSuggestion.swift
//  Duty
//
//  A proposed base⇄home ground commute that `CommuteSuggestionEngine` surfaces for a
//  gap between two trips. Pure value type — never persisted directly; the partner-
//  sharing UI (Stage 3c) turns a confirmed suggestion into a `Commute`.

import Foundation

struct CommuteSuggestion: Equatable, Identifiable, Sendable {

    /// Where the suggestion came from — a fresh gap, or an existing manual driving
    /// event the user can convert in place (carrying its details over on confirm).
    enum Origin: Equatable, Sendable {
        case fresh
        case convert(manualEventID: String)
    }

    let sourceTripId: String
    let direction: CommuteDirection
    let fromAirport: String
    let toAirport: String
    let departureTimeZulu: Date
    let arrivalTimeZulu: Date
    let driveDurationSeconds: TimeInterval
    let origin: Origin

    /// Idempotency key (spec §7): repeated refreshes of the same gap must surface the
    /// identical suggestion, so two suggestions are "the same" iff these four fields
    /// match. `origin` and the derived times are intentionally excluded.
    var id: String { "\(sourceTripId)|\(direction.rawValue)|\(fromAirport)|\(toAirport)" }
}
```

- [ ] **Step 4: Create `CommuteSuggestionEngine.swift`**

Create `Duty/Utils/PartnerBeacon/CommuteSuggestionEngine.swift`:

```swift
//  CommuteSuggestionEngine.swift
//  Duty
//
//  Pure, read-only engine (spec §7). Given a pilot and the local trip / jumpseat /
//  commute / manual-event data, it returns the base⇄home drive commutes worth
//  suggesting for the gaps between trips. It NEVER writes — confirming a suggestion
//  (creating the `Commute`) is the partner-sharing UI's job (Stage 3c).

import Foundation
import SwiftData

struct CommuteSuggestionEngine {

    let modelContext: ModelContext

    /// A gap must strictly exceed this to be commute-worthy (spec §7, gate 2).
    static let minimumGap: TimeInterval = 24 * 60 * 60

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Title keyword match for a manual "driving" event — mirrors Crewluv's
    /// `NarrativeCardView.eventIconOverride`: case-insensitive `driv` / `car` / `truck`.
    nonisolated static func titleSuggestsDriving(_ title: String) -> Bool {
        let lowered = title.lowercased()
        return lowered.contains("driv") || lowered.contains("car") || lowered.contains("truck")
    }

    /// All commute suggestions for this pilot, across every qualifying trip gap.
    /// Deterministic and idempotent (spec §7): a pure function of the local data.
    @MainActor
    func suggestions(for pilot: PilotInfo) -> [CommuteSuggestion] {
        // Gate 1 — commuters only.
        let base = pilot.base.rawValue
        let home = pilot.effectiveHomeAirportCode
        guard home != base else { return [] }

        // Live trips, chronological.
        guard let allTrips = try? modelContext.fetch(FetchDescriptor<Trip>()) else { return [] }
        let trips = allTrips
            .filter { $0.deletedAt == nil }
            .sorted { $0.startDate < $1.startDate }
        guard trips.count >= 2 else { return [] }

        let hiddenIDs = HiddenEventsManager.loadHiddenIDs()
        let jumpseats = ((try? modelContext.fetch(FetchDescriptor<Jumpseat>())) ?? [])
            .filter { $0.deletedAt == nil }
        let commutes = ((try? modelContext.fetch(FetchDescriptor<Commute>())) ?? [])
            .filter { $0.deletedAt == nil }
        let manualEvents = ((try? modelContext.fetch(FetchDescriptor<ManualEvent>())) ?? [])
            .filter { $0.deletedAt == nil }

        var result: [CommuteSuggestion] = []
        var seen: Set<String> = []

        for index in 0 ..< (trips.count - 1) {
            let prev = trips[index]
            let next = trips[index + 1]

            // Gate 2 — gap strictly greater than 24h.
            guard next.startDate.timeIntervalSince(prev.endDate) > Self.minimumGap else { continue }

            let gapStart = prev.endDate
            let gapEnd = next.startDate

            // toHome — drive base → home after a trip that LANDS at base (gate 3).
            if prev.endingAirport == base,
               let suggestion = makeSuggestion(direction: .toHome, anchorTripId: prev.id,
                                               from: base, to: home,
                                               gapStart: gapStart, gapEnd: gapEnd,
                                               home: home, base: base,
                                               jumpseats: jumpseats, commutes: commutes,
                                               manualEvents: manualEvents, hiddenIDs: hiddenIDs),
               seen.insert(suggestion.id).inserted {
                result.append(suggestion)
            }

            // toWork — drive home → base before a trip that STARTS at base (gate 3).
            if next.startingAirport == base,
               let suggestion = makeSuggestion(direction: .toWork, anchorTripId: next.id,
                                               from: home, to: base,
                                               gapStart: gapStart, gapEnd: gapEnd,
                                               home: home, base: base,
                                               jumpseats: jumpseats, commutes: commutes,
                                               manualEvents: manualEvents, hiddenIDs: hiddenIDs),
               seen.insert(suggestion.id).inserted {
                result.append(suggestion)
            }
        }
        return result
    }

    // MARK: - Per-direction construction

    private func makeSuggestion(direction: CommuteDirection, anchorTripId: String,
                                from: String, to: String,
                                gapStart: Date, gapEnd: Date,
                                home: String, base: String,
                                jumpseats: [Jumpseat], commutes: [Commute],
                                manualEvents: [ManualEvent], hiddenIDs: Set<String>) -> CommuteSuggestion? {

        // Gate 4a — already a managed Commute for this anchor + direction.
        if commutes.contains(where: { $0.sourceTripId == anchorTripId && $0.direction == direction }) {
            return nil
        }

        // Gate 4b — a standalone, visible jumpseat already bridges the gap.
        if hasBridgingJumpseat(direction: direction, gapStart: gapStart, gapEnd: gapEnd,
                               home: home, base: base, jumpseats: jumpseats, hiddenIDs: hiddenIDs) {
            return nil
        }

        // Times & remembered (or default 2h) drive duration.
        let duration = CommuteRouteStore.duration(from: from, to: to)
        let departure: Date
        let arrival: Date
        switch direction {
        case .toHome:
            departure = gapStart
            arrival = gapStart.addingTimeInterval(duration)
        case .toWork:
            arrival = gapEnd
            departure = gapEnd.addingTimeInterval(-duration)
        }

        // Convert in place when a manual driving event sits in the gap (spec §7).
        let origin: CommuteSuggestion.Origin
        if let drivingEvent = manualEvents.first(where: {
            Self.titleSuggestsDriving($0.title)
                && $0.startTimeUTC >= gapStart
                && $0.startTimeUTC <= gapEnd
        }) {
            origin = .convert(manualEventID: drivingEvent.id)
        } else {
            origin = .fresh
        }

        return CommuteSuggestion(sourceTripId: anchorTripId, direction: direction,
                                 fromAirport: from, toAirport: to,
                                 departureTimeZulu: departure, arrivalTimeZulu: arrival,
                                 driveDurationSeconds: duration, origin: origin)
    }

    private func hasBridgingJumpseat(direction: CommuteDirection,
                                     gapStart: Date, gapEnd: Date,
                                     home: String, base: String,
                                     jumpseats: [Jumpseat], hiddenIDs: Set<String>) -> Bool {
        jumpseats.contains { js in
            guard js.sourceTripId == nil,
                  !HiddenEventsManager.isJumpseatHidden(js.id, in: hiddenIDs) else { return false }
            switch direction {
            case .toHome:
                // Flies home during the gap → no drive-home needed.
                return js.destination == home
                    && js.arrivalTimeZulu > gapStart && js.arrivalTimeZulu <= gapEnd
            case .toWork:
                // Leaves home toward work during the gap → no drive-to-work needed.
                return js.origin == home
                    && js.departureTimeZulu >= gapStart && js.departureTimeZulu < gapEnd
            }
        }
    }
}
```

- [ ] **Step 5: Run the tests — verify they PASS**

Run:
```bash
xcodebuild test -project /Users/toddanderson/Dev/Duty/Duty.xcodeproj -scheme Duty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DutyTests/CommuteSuggestionEngineTests
```
Expected: all `CommuteSuggestionEngineTests` pass. (If you hit a `server died` / `Invalid device state` with 0 assertion failures, run `xcrun simctl shutdown all` and re-run — infra flake, not a code failure.)

- [ ] **Step 6: Commit**

```bash
cd /Users/toddanderson/Dev/Duty
git add Duty/Utils/PartnerBeacon/CommuteSuggestion.swift \
        Duty/Utils/PartnerBeacon/CommuteSuggestionEngine.swift \
        DutyTests/CommuteSuggestionEngineTests.swift
git commit -m "feat(duty): CommuteSuggestionEngine proposes base⇄home commutes per trip gap"
```

> Verify `git status` shows the user's WIP files (`PilotStatusBeaconManager.swift`, `SyncGuidanceCopy.swift`, `SyncGuidanceCopyTests.swift`) and `project.pbxproj` still **unstaged** before committing.

---

## Task 2: `CommuteCleanupService` + `SoftDeleteService` overload

**Files:**
- Modify: `Duty/Utils/Sync/SoftDeleteService.swift`
- Create: `Duty/Utils/PartnerBeacon/CommuteCleanupService.swift`
- Test: `DutyTests/CommuteCleanupServiceTests.swift`

- [ ] **Step 1: Write the failing test file**

Create `DutyTests/CommuteCleanupServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

final class CommuteCleanupServiceTests: XCTestCase {

    private var container: ModelContainer?

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        self.container = container
        return container.mainContext
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    @discardableResult
    private func makeTrip(id: String, deleted: Bool = false, in ctx: ModelContext) -> Trip {
        let trip = Trip(id: id, startDate: Date(), endDate: Date(),
                        dutyTime: 0, blockTime: 0, creditTime: 0, days: 1, tafb: 0, base: "SDF")
        if deleted { trip.deletedAt = Date() }
        ctx.insert(trip)
        return trip
    }

    @discardableResult
    private func makeCommute(sourceTripId: String?, in ctx: ModelContext) -> Commute {
        let c = Commute()
        c.fromAirport = "SDF"
        c.toAirport = "MCO"
        c.direction = .toHome
        c.sourceTripId = sourceTripId
        ctx.insert(c)
        return c
    }

    @MainActor
    func test_orphanCommute_absentTrip_isSoftDeleted() throws {
        let ctx = try makeContext()
        let c = makeCommute(sourceTripId: "ghost", in: ctx) // no such trip
        try ctx.save()
        let removed = CommuteCleanupService.cleanupOrphanedCommutes(in: ctx)
        XCTAssertEqual(removed, 1)
        XCTAssertNotNil(c.deletedAt)
        XCTAssertTrue(c.needsPush)
    }

    @MainActor
    func test_orphanCommute_softDeletedTrip_isSoftDeleted() throws {
        let ctx = try makeContext()
        let trip = makeTrip(id: "T1", deleted: true, in: ctx)
        let c = makeCommute(sourceTripId: trip.id, in: ctx)
        try ctx.save()
        let removed = CommuteCleanupService.cleanupOrphanedCommutes(in: ctx)
        XCTAssertEqual(removed, 1)
        XCTAssertNotNil(c.deletedAt)
    }

    @MainActor
    func test_commuteWithLiveTrip_isKept() throws {
        let ctx = try makeContext()
        let trip = makeTrip(id: "T1", in: ctx)
        let c = makeCommute(sourceTripId: trip.id, in: ctx)
        try ctx.save()
        let removed = CommuteCleanupService.cleanupOrphanedCommutes(in: ctx)
        XCTAssertEqual(removed, 0)
        XCTAssertNil(c.deletedAt)
    }

    @MainActor
    func test_manualCommute_nilSourceTrip_isKept() throws {
        let ctx = try makeContext()
        let c = makeCommute(sourceTripId: nil, in: ctx)
        try ctx.save()
        let removed = CommuteCleanupService.cleanupOrphanedCommutes(in: ctx)
        XCTAssertEqual(removed, 0)
        XCTAssertNil(c.deletedAt)
    }

    @MainActor
    func test_cleanup_isIdempotent() throws {
        let ctx = try makeContext()
        _ = makeCommute(sourceTripId: "ghost", in: ctx)
        try ctx.save()
        XCTAssertEqual(CommuteCleanupService.cleanupOrphanedCommutes(in: ctx), 1)
        XCTAssertEqual(CommuteCleanupService.cleanupOrphanedCommutes(in: ctx), 0)
    }
}
```

- [ ] **Step 2: Run the test — verify it FAILS to compile**

Run:
```bash
xcodebuild test -project /Users/toddanderson/Dev/Duty/Duty.xcodeproj -scheme Duty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DutyTests/CommuteCleanupServiceTests
```
Expected: build failure — `cannot find 'CommuteCleanupService' in scope`.

- [ ] **Step 3: Add the `SoftDeleteService.softDelete(_ commute:)` overload**

In `Duty/Utils/Sync/SoftDeleteService.swift`, alongside the other per-type `softDelete(_:)` overloads (e.g. next to `softDelete(_ jumpseat: Jumpseat, …)`), add:

```swift
    /// Soft-deletes a standalone `Commute`. It has no synced children, so this is a
    /// single tombstone (sets `deletedAt` + `needsPush` so the delete syncs out on
    /// both backends and the drive vanishes from the partner timeline).
    static func softDelete(_ commute: Commute, at now: Date = Date()) {
        tombstone(commute, at: now)
    }
```

- [ ] **Step 4: Create `CommuteCleanupService.swift`**

Create `Duty/Utils/PartnerBeacon/CommuteCleanupService.swift`:

```swift
//  CommuteCleanupService.swift
//  Duty
//
//  Soft-deletes orphaned commutes (spec §12 item 10, §13). A managed `Commute` whose
//  `sourceTripId` points at a trip that has been soft-deleted or no longer exists
//  would otherwise keep projecting a phantom drive onto the partner timeline. This is
//  a pure operation; the caller (DutyApp's post-launch cleanup) owns the sync/recovery
//  gating, mirroring how `DatabaseCleanupService` is invoked.

import Foundation
import SwiftData

enum CommuteCleanupService {

    /// Soft-deletes every live `Commute` whose `sourceTripId` references an absent or
    /// soft-deleted `Trip`. Manually-added commutes (`sourceTripId == nil`) are left
    /// untouched. Returns the number soft-deleted.
    @MainActor
    @discardableResult
    static func cleanupOrphanedCommutes(in modelContext: ModelContext, at now: Date = Date()) -> Int {
        guard let commutes = try? modelContext.fetch(
            FetchDescriptor<Commute>(predicate: #Predicate { $0.deletedAt == nil })),
              !commutes.isEmpty else { return 0 }

        guard let trips = try? modelContext.fetch(FetchDescriptor<Trip>()) else { return 0 }
        let liveTripIDs = Set(trips.filter { $0.deletedAt == nil }.map(\.id))

        var removed = 0
        for commute in commutes {
            guard let tripID = commute.sourceTripId else { continue } // manual commute — keep
            if !liveTripIDs.contains(tripID) {
                SoftDeleteService.softDelete(commute, at: now)
                removed += 1
            }
        }
        if removed > 0 { try? modelContext.save() }
        return removed
    }
}
```

- [ ] **Step 5: Run the tests — verify they PASS**

Run:
```bash
xcodebuild test -project /Users/toddanderson/Dev/Duty/Duty.xcodeproj -scheme Duty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DutyTests/CommuteCleanupServiceTests
```
Expected: all 5 tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/toddanderson/Dev/Duty
git add Duty/Utils/Sync/SoftDeleteService.swift \
        Duty/Utils/PartnerBeacon/CommuteCleanupService.swift \
        DutyTests/CommuteCleanupServiceTests.swift
git commit -m "feat(duty): CommuteCleanupService soft-deletes orphaned commutes"
```

---

## Task 3: Wire `CommuteCleanupService` into the launch cleanup

**Files:**
- Modify: `Duty/App/DutyApp.swift`

This is app glue (no unit test — verified by compile + Task 2's tests). The commute cleanup must run for **both** backends (commuters exist on Supabase too), so it goes OUTSIDE the existing `.icloud`-only block, behind the same sync/recovery safety gate.

- [ ] **Step 1: Locate the 60-second cleanup wave**

In `Duty/App/DutyApp.swift`, find the 60-second deferred cleanup (`DispatchQueue.main.asyncAfter(deadline: .now() + 60.0)`, ~line 153). Inside its `Task(priority: .background) { @MainActor in … }` closure, identify the closing brace of the `if SyncBackendMode.current == .icloud { … }` block and the subsequent `if bgTaskID != .invalid { … }` cleanup.

- [ ] **Step 2: Insert the commute cleanup call**

Immediately AFTER the closing brace of the `if SyncBackendMode.current == .icloud { … }` block and BEFORE the `if bgTaskID != .invalid { … }` block (still inside the `@MainActor` Task closure), insert:

```swift
            // Commute orphan cleanup — runs for BOTH backends (commuters exist on
            // Supabase too). Soft-deletes commutes whose source trip was deleted so a
            // phantom drive stops projecting onto the partner timeline. Gated like the
            // other launch cleanups so we never delete while a trip is mid-import.
            let commuteCtx = DutyApp.sharedModelContainer.mainContext
            if SyncCoordinator.shared.isSyncing
                || SupabaseSyncEngine.shared.isSyncInFlight
                || DutyApp.hasFreshIncompleteOrRecoveryTrips(in: commuteCtx) {
                debugLog("⏳ Skipping commute cleanup - sync active or recovery pending")
            } else {
                let removed = CommuteCleanupService.cleanupOrphanedCommutes(in: commuteCtx)
                if removed > 0 {
                    debugLog("🧹 Launch cleanup: soft-deleted \(removed) orphaned commute(s)")
                }
            }
```

> Notes: this is inside the `DutyApp` struct, so the **private** `hasFreshIncompleteOrRecoveryTrips(in:)` is accessible. The closure is already `@MainActor`, so the `@MainActor` `cleanupOrphanedCommutes` call is legal. Match the surrounding indentation exactly — if the real indentation differs from the 12 spaces above, adjust to fit.

- [ ] **Step 3: Build to verify it compiles**

Run:
```bash
xcodebuild build -project /Users/toddanderson/Dev/Duty/Duty.xcodeproj -scheme Duty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Re-run the cleanup unit tests (regression)**

Run:
```bash
xcodebuild test -project /Users/toddanderson/Dev/Duty/Duty.xcodeproj -scheme Duty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:DutyTests/CommuteCleanupServiceTests
```
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/toddanderson/Dev/Duty
git add Duty/App/DutyApp.swift
git commit -m "feat(duty): run commute orphan cleanup on launch (both backends)"
```

> Verify `git status` shows ONLY `Duty/App/DutyApp.swift` staged (plus nothing else), and the user's WIP files + `project.pbxproj` are untouched.

---

## Self-Review (run before dispatching execution)

**1. Spec coverage (§7, §12 items 3 & 10):**
- Gate 1 commuter (`effectiveHomeAirportCode != base`) → `test_nonCommuter_returnsNoSuggestions`. ✅
- Gate 2 gap `> 24h` → `test_gapUnder24h_returnsNoSuggestions` + qualifying-gap test. ✅
- Gate 3 base-anchored (`toHome` after `endingAirport == base`; `toWork` before `startingAirport == base`) → `test_qualifyingGap…` + `test_gapNotBaseAnchored…`. ✅
- Gate 4 not-already-covered (existing Commute + bridging jumpseat, hidden/trip-sourced excluded) → Tasks 4a/4b tests. ✅
- Output: ≤2 per gap, idempotency key `(sourceTripId, direction, from, to)` → `CommuteSuggestion.id` + `test_suggestions_areIdempotent`. ✅
- Convert flow (driving ManualEvent → convert, else fresh; existing Commute/JS still suppress) → convert tests. ✅ (Scoping note: engine only *flags* convert; the "carry location / add return drive" write is Stage 3c. Reviewer: confirm this boundary is acceptable per §7.)
- Cleanup soft-deletes orphans, keeps manual/live → Task 2 tests; wired alongside post-launch cleanups, both backends → Task 3. ✅

**2. Placeholder scan:** every step has real code/commands. No TBD/TODO. ✅

**3. Type consistency:** `CommuteDirection` (`.toHome`/`.toWork`), `Commute.direction`/`.sourceTripId`/`.deletedAt`/`.needsPush`, `Trip.startingAirport`/`.endingAirport`/`.startDate`/`.endDate`/`.id`, `PilotInfo.base.rawValue`/`.effectiveHomeAirportCode`, `Jumpseat.origin`/`.destination`/`.departureTimeZulu`/`.arrivalTimeZulu`/`.sourceTripId`/`.id`/`.hiddenFromTimeline`, `ManualEvent.title`/`.startTimeUTC`/`.id`, `CommuteRouteStore.duration(from:to:)`, `HiddenEventsManager.{loadHiddenIDs,isJumpseatHidden,deriveSet,writeCache}`, `SoftDeleteService.{tombstone,softDelete}` — all verified against current code. ✅

---

## Execution methodology (per resume doc rule #4)

Execute via **superpowers:subagent-driven-development**: a fresh implementer subagent per task (given the full task text inline — do NOT make it read this file), then **two separate review gates** — spec-compliance review, then code-quality review — before moving to the next task. Targeted test runs only.

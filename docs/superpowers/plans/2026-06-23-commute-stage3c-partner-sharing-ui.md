# Commute Stage 3c — Partner Sharing "Commutes" UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task (fresh implementer per task → spec-compliance review → code-quality review). Steps use checkbox (`- [ ]`) syntax.
>
> **WORKFLOW CONSTRAINTS (hard, from the project's working rules):**
> - **The USER runs all builds/tests in Xcode.** Implementer and reviewer subagents must **NOT** run `xcodebuild` / `xcrun` / `swift test`. Test-run steps below are marked **[USER-RUN]** — hand off the named `DutyTests/<Class>` for the user to run with Cmd-U.
> - **Never push, never merge, never auto-commit.** Each commit step is **[CONFIRM]** — propose the commit and wait for the user's explicit OK before running it.
> - **Never `git add`** the user's WIP: `Duty/Utils/PartnerBeacon/PilotStatusBeaconManager.swift`, `Duty/Utils/SyncGuidanceCopy.swift`, `DutyTests/SyncGuidanceCopyTests.swift`. Stage only the files each task names.
> - **Never commit `project.pbxproj`.** `DutyTests` is a `PBXFileSystemSynchronizedRootGroup` — new test files auto-join the target with no pbxproj edit.

**Goal:** Add the Duty pilot-app UI that lets a commuter (home airport ≠ base) review engine commute-suggestions and manage saved commutes from Partner Sharing.

**Architecture:** A `Commutes` section in `PartnerSharingView` (gated `isSharing && home != base`) renders persisted `Commute`s and de-duplicated `CommuteSuggestion`s. One unified `CommuteSheet` (add / edit / confirm / convert) is driven by a logic-bearing, unit-testable `CommuteSheetModel`. A small `CommuteSuggestionDismissalStore` remembers dismissed suggestions in `SharedUserDefaults`. The Stage-2/3a/3b data layer (model, engine, route store, soft-delete, hidden-events, sync) already exists and is **not** re-implemented.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, XCTest, iOS 17+. Sibling repo: `/Users/toddanderson/Dev/Duty` (branch `feature/supabase-account-backend`).

**Reference:** Design decisions in `docs/superpowers/specs/2026-06-23-commute-stage3c-ui-decisions.md`; master spec `…/2026-06-22-commuter-home-base-commutes-design.md` (§11, §7, §9.3).

---

## Existing APIs this plan consumes (verified against the Duty repo — do not redefine)

```
// Duty/Models/Commute.swift
final class Commute /* @Model */ {           // init() {} ; all fields defaulted; NO @Attribute(.unique)
  var id: String; var fromAirport: String; var toAirport: String
  var directionRaw: String                    // CommuteDirection.rawValue
  var departureTimeZulu: Date; var arrivalTimeZulu: Date
  var driveDurationSeconds: Double            // default 7200
  var sourceTripId: String?; var hiddenFromTimeline: Bool
  var createdAt: Date; var lastModifiedAt: Date; var deletedAt: Date?; var needsPush: Bool
  var direction: CommuteDirection { get/set }  // computed over directionRaw
}
enum CommuteDirection: String, Codable, Sendable { case toHome; case toWork }

// Duty/Utils/PartnerBeacon/CommuteSuggestion.swift
struct CommuteSuggestion: Equatable, Identifiable, Sendable {
  enum Origin: Equatable, Sendable { case fresh; case convert(manualEventID: String) }
  let sourceTripId: String; let direction: CommuteDirection
  let fromAirport: String; let toAirport: String
  let departureTimeZulu: Date; let arrivalTimeZulu: Date
  let driveDurationSeconds: TimeInterval; let origin: Origin
  var id: String { "\(sourceTripId)|\(direction.rawValue)|\(fromAirport)|\(toAirport)" }
}   // synthesized memberwise init (id is computed, not an init param)

// Duty/Utils/PartnerBeacon/CommuteSuggestionEngine.swift
struct CommuteSuggestionEngine {
  init(modelContext: ModelContext)
  @MainActor func suggestions(for pilot: PilotInfo) -> [CommuteSuggestion]
}

// Duty/Utils/CommuteRouteStore.swift
enum CommuteRouteStore {
  static let defaultDuration: TimeInterval            // 7200
  static func duration(from: String, to: String) -> TimeInterval
  static func setDuration(_ seconds: TimeInterval, from: String, to: String)
}

// Duty/Utils/Sync/SoftDeleteService.swift
enum SoftDeleteService {
  static func softDelete(_ commute: Commute, at now: Date = Date())
  static func softDelete(_ manualEvent: ManualEvent, at now: Date = Date(), in context: ModelContext)
}

// Duty/Utils/PartnerBeacon/CommuteCleanupService.swift   (already shipped in 3b)
enum CommuteCleanupService {
  @MainActor static func cleanupOrphanedCommutes(in: ModelContext) -> Int   // returns removed count
}

// Duty/ViewModels/HiddenEventsManager.swift  (static helpers are nonisolated)
static func applyHidden(_ id: String, _ hidden: Bool, in ctx: ModelContext) -> Bool   // @discardableResult
static func deriveSet(from ctx: ModelContext) -> Set<String>
static func writeCache(_ ids: Set<String>)
static func loadHiddenIDs() -> Set<String>
static func isManualEventHidden(_ eventId: String, in hiddenIDs: Set<String>) -> Bool
// id formats: "manual_<id>", "commute_<id>"

// Duty/Models/PilotInfo.swift
var base: PilotBase { get/set }                 // base.rawValue is the IATA code, e.g. "SDF"
var homeAirportCode: String?
var effectiveHomeAirportCode: String            // homeAirportCode ?? base.rawValue
var baseRawValue: String                        // stored; PilotBase(rawValue:) over it
init() // no-arg init available; tests set baseRawValue / homeAirportCode / isActive directly

// Duty/Models/Trip.swift
init(id: String, startDate: Date, endDate: Date, dutyTime: TimeInterval, blockTime: TimeInterval,
     creditTime: TimeInterval, days: Int, tafb: TimeInterval, base: String)
var deletedAt: Date?                            // soft-delete tombstone

// Duty/Utils/AirportDataProvider.swift
AirportDataProvider.shared.allAirportCodes() -> [String]
AirportDataProvider.shared.airportInfo(forIataCode: String) -> AirportData?   // .city, .name

// Duty/Views/Components/LocationPickerView.swift
struct LocationPickerView: View { @Binding var selection: String; let locationCodes: [String] }

// Duty/Utils/Sync/SyncSchema.swift
SyncSchema.allModels   // [any PersistentModel.Type] incl Commute — use Schema(SyncSchema.allModels) in tests
```

> Implementers: before writing each file, open the named source file and confirm the exact signature you depend on. Where this plan and the live code disagree, the live code wins — adapt and note it for the reviewer.

---

## File structure

| File | Action | Responsibility |
|---|---|---|
| `Duty/Utils/CommuteSuggestionDismissalStore.swift` | Create | Persist dismissed suggestion ids in `SharedUserDefaults` |
| `DutyTests/CommuteSuggestionDismissalStoreTests.swift` | Create | Unit tests for the store |
| `Duty/ViewModels/CommuteSheetModel.swift` | Create | Form state + validation + commit (create/update/convert) |
| `DutyTests/CommuteSheetModelTests.swift` | Create | Unit tests for the model |
| `Duty/Views/Settings/CommuteSheet.swift` | Create | Unified add/edit/confirm/convert sheet |
| `Duty/Views/Settings/PartnerSharingView.swift` | Modify | New `Commutes` section + suggestion/saved rows + sheet wiring |
| `DutyTests/CommuteCleanupIntegrationTests.swift` | Create | Deferred-from-3b: confirmed commute ↔ cleanup "live" judgement |

---

## Task 1: `CommuteSuggestionDismissalStore`

**Files:**
- Create: `Duty/Utils/CommuteSuggestionDismissalStore.swift`
- Test: `DutyTests/CommuteSuggestionDismissalStoreTests.swift`

- [ ] **Step 1: Open `Duty/Utils/CommuteRouteStore.swift`** and note exactly how it reaches the app-group store (the `SharedUserDefaults` accessor and suite). Use the identical accessor below — replace `SharedUserDefaults.shared` if `CommuteRouteStore` uses a different expression.

- [ ] **Step 2: Write the failing test**

`DutyTests/CommuteSuggestionDismissalStoreTests.swift`:

```swift
import XCTest
@testable import Duty

final class CommuteSuggestionDismissalStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        CommuteSuggestionDismissalStore.prune(activeKeys: [])   // start clean
    }

    override func tearDown() {
        CommuteSuggestionDismissalStore.prune(activeKeys: [])
        super.tearDown()
    }

    func test_dismiss_thenIsDismissed_returnsTrue() {
        let id = "TRIP1|toHome|SDF|ATL"
        XCTAssertFalse(CommuteSuggestionDismissalStore.isDismissed(id))
        CommuteSuggestionDismissalStore.dismiss(id)
        XCTAssertTrue(CommuteSuggestionDismissalStore.isDismissed(id))
    }

    func test_dismiss_isIdempotent() {
        let id = "TRIP1|toWork|ATL|SDF"
        CommuteSuggestionDismissalStore.dismiss(id)
        CommuteSuggestionDismissalStore.dismiss(id)
        XCTAssertEqual(CommuteSuggestionDismissalStore.dismissedIDs().filter { $0 == id }.count, 1)
    }

    func test_prune_dropsKeysNotInActiveSet() {
        CommuteSuggestionDismissalStore.dismiss("A|toHome|SDF|ATL")
        CommuteSuggestionDismissalStore.dismiss("B|toWork|ATL|SDF")
        CommuteSuggestionDismissalStore.prune(activeKeys: ["A|toHome|SDF|ATL"])
        XCTAssertTrue(CommuteSuggestionDismissalStore.isDismissed("A|toHome|SDF|ATL"))
        XCTAssertFalse(CommuteSuggestionDismissalStore.isDismissed("B|toWork|ATL|SDF"))
    }
}
```

- [ ] **Step 3: [USER-RUN]** In Xcode, Cmd-U on `DutyTests/CommuteSuggestionDismissalStoreTests`. Expected: **FAIL to compile** ("cannot find 'CommuteSuggestionDismissalStore'").

- [ ] **Step 4: Write the implementation**

`Duty/Utils/CommuteSuggestionDismissalStore.swift`:

```swift
import Foundation

/// Remembers commute suggestions the pilot has dismissed.
///
/// `CommuteSuggestionEngine` is idempotent — it re-emits the same suggestion every refresh —
/// so without memory a dismissed suggestion would reappear. Dismissals are keyed by
/// `CommuteSuggestion.id` ("<sourceTripId>|<direction>|<from>|<to>"), which is stable for a
/// given gap and changes if the bracketing trip changes; a dismissal therefore expires
/// naturally once the trip it referred to changes. Backed by the shared app-group store so
/// the value matches `CommuteRouteStore`.
enum CommuteSuggestionDismissalStore {

    private static let key = "commuteSuggestions.dismissed"

    // Mirror CommuteRouteStore's accessor exactly (see Step 1).
    private static var defaults: UserDefaults { SharedUserDefaults.shared }

    static func dismissedIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    static func isDismissed(_ id: String) -> Bool {
        dismissedIDs().contains(id)
    }

    static func dismiss(_ id: String) {
        var ids = dismissedIDs()
        guard ids.insert(id).inserted else { return }
        defaults.set(Array(ids), forKey: key)
    }

    /// Drops remembered dismissals whose ids are no longer among `activeKeys`,
    /// preventing unbounded growth as trips age out.
    static func prune(activeKeys: Set<String>) {
        defaults.set(Array(dismissedIDs().intersection(activeKeys)), forKey: key)
    }
}
```

- [ ] **Step 5: [USER-RUN]** In Xcode, Cmd-U on `DutyTests/CommuteSuggestionDismissalStoreTests`. Expected: **PASS** (3 tests).

- [ ] **Step 6: [CONFIRM] Commit** — propose to the user, then on OK:

```bash
git -C /Users/toddanderson/Dev/Duty add Duty/Utils/CommuteSuggestionDismissalStore.swift DutyTests/CommuteSuggestionDismissalStoreTests.swift
git -C /Users/toddanderson/Dev/Duty commit -m "feat(duty): persist dismissed commute suggestions in shared defaults"
```

---

## Task 2: `CommuteSheetModel`

**Files:**
- Create: `Duty/ViewModels/CommuteSheetModel.swift`
- Test: `DutyTests/CommuteSheetModelTests.swift`

- [ ] **Step 1: Note the test-container idiom.** The Duty commute tests (e.g. `DutyTests/CommuteCleanupServiceTests.swift`, `DutyTests/CommuteSuggestionEngineTests.swift`) all build the in-memory store the same way: a retained `private var container: ModelContainer?`, a `makeContext()` helper using `Schema(SyncSchema.allModels)` + `ModelConfiguration(isStoredInMemoryOnly: true)` returning `container.mainContext`, and `tearDown` nilling the container (SwiftData traps on `save()` if the container deallocates). The test below uses that exact idiom — there is no shared base helper, so it is reproduced inline.

- [ ] **Step 2: Write the failing test**

`DutyTests/CommuteSheetModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

@MainActor
final class CommuteSheetModelTests: XCTestCase {

    private var container: ModelContainer?   // retained — SwiftData traps on save() if it deallocates

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        self.container = container
        return container.mainContext
    }

    override func tearDown() { container = nil; super.tearDown() }

    private func makeCommuterPilot(in ctx: ModelContext) -> PilotInfo {
        let pilot = PilotInfo()
        pilot.baseRawValue = "SDF"
        pilot.homeAirportCode = "ATL"
        pilot.isActive = true
        ctx.insert(pilot)
        return pilot
    }

    private func suggestion(_ origin: CommuteSuggestion.Origin,
                            trip: String = "T1",
                            direction: CommuteDirection = .toHome,
                            from: String = "SDF", to: String = "ATL") -> CommuteSuggestion {
        let dep = Date(timeIntervalSince1970: 2_000_000)
        return CommuteSuggestion(sourceTripId: trip, direction: direction,
                                 fromAirport: from, toAirport: to,
                                 departureTimeZulu: dep,
                                 arrivalTimeZulu: dep.addingTimeInterval(7200),
                                 driveDurationSeconds: 7200, origin: origin)
    }

    func test_isValid_falseWhenAirportsEqual() throws {
        let ctx = try makeContext()
        let m = CommuteSheetModel(adding: makeCommuterPilot(in: ctx))
        m.fromAirport = "SDF"; m.toAirport = "SDF"
        XCTAssertFalse(m.isValid)
    }

    func test_isValid_falseWhenDurationNotPositive() throws {
        let ctx = try makeContext()
        let m = CommuteSheetModel(adding: makeCommuterPilot(in: ctx))
        m.durationSeconds = 0
        XCTAssertFalse(m.isValid)
    }

    func test_computedArrival_isDeparturePlusDuration() throws {
        let ctx = try makeContext()
        let m = CommuteSheetModel(adding: makeCommuterPilot(in: ctx))
        let dep = Date(timeIntervalSince1970: 1_000_000)
        m.departure = dep; m.durationSeconds = 3600
        XCTAssertEqual(m.computedArrival, dep.addingTimeInterval(3600))
    }

    func test_directionToggle_reseedsAirports() throws {
        let ctx = try makeContext()
        let m = CommuteSheetModel(adding: makeCommuterPilot(in: ctx))   // .toHome → SDF→ATL
        XCTAssertEqual(m.fromAirport, "SDF"); XCTAssertEqual(m.toAirport, "ATL")
        m.direction = .toWork                                           // → ATL→SDF
        XCTAssertEqual(m.fromAirport, "ATL"); XCTAssertEqual(m.toAirport, "SDF")
    }

    func test_commit_freshSuggestion_createsCommuteWithMappedFields() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let commute = CommuteSheetModel(suggestion: suggestion(.fresh), pilot: pilot).commit(into: ctx)
        XCTAssertEqual(commute.fromAirport, "SDF")
        XCTAssertEqual(commute.toAirport, "ATL")
        XCTAssertEqual(commute.direction, .toHome)
        XCTAssertEqual(commute.sourceTripId, "T1")
        XCTAssertEqual(commute.arrivalTimeZulu, commute.departureTimeZulu.addingTimeInterval(7200))
        XCTAssertTrue(commute.needsPush)
        XCTAssertNil(commute.deletedAt)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Commute>()).count, 1)
    }

    func test_commit_convert_softDeletesSourceManualEvent() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let event = ManualEvent()
        event.id = "ME1"; event.title = "Drive to SDF"
        event.startTimeUTC = Date(timeIntervalSince1970: 2_000_000)
        event.endTimeUTC = Date(timeIntervalSince1970: 2_007_200)
        ctx.insert(event); try ctx.save()

        let s = suggestion(.convert(manualEventID: "ME1"),
                           trip: "T2", direction: .toWork, from: "ATL", to: "SDF")
        _ = CommuteSheetModel(suggestion: s, pilot: pilot).commit(into: ctx)

        let me = try ctx.fetch(FetchDescriptor<ManualEvent>()).first { $0.id == "ME1" }
        XCTAssertNotNil(me?.deletedAt, "convert must soft-delete (retire) the source manual event")
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Commute>()).count, 1)
    }

    func test_commit_convert_missingManualEvent_degradesToPlainCreate() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let s = suggestion(.convert(manualEventID: "GONE"),
                           trip: "T3", direction: .toWork, from: "ATL", to: "SDF")
        let commute = CommuteSheetModel(suggestion: s, pilot: pilot).commit(into: ctx)   // must not crash
        XCTAssertEqual(commute.toAirport, "SDF")
    }

    func test_commit_edit_updatesExistingWithoutCreatingDuplicate() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)
        let existing = Commute()
        existing.fromAirport = "SDF"; existing.toAirport = "ATL"; existing.driveDurationSeconds = 7200
        ctx.insert(existing); try ctx.save()

        let m = CommuteSheetModel(editing: existing, pilot: pilot)
        m.durationSeconds = 9000
        _ = m.commit(into: ctx)

        let all = try ctx.fetch(FetchDescriptor<Commute>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.driveDurationSeconds, 9000)
    }
}
```

- [ ] **Step 3: [USER-RUN]** Cmd-U on `DutyTests/CommuteSheetModelTests`. Expected: **FAIL to compile** ("cannot find 'CommuteSheetModel'").

- [ ] **Step 4: Write the implementation**

`Duty/ViewModels/CommuteSheetModel.swift`:

```swift
import Foundation
import SwiftData

/// Backs `CommuteSheet`. Holds the editable form state, derives the arrival time and validity,
/// and on `commit` creates or updates the `Commute` (and, for a converted suggestion, retires the
/// source manual event). Keeping the logic here leaves the view declarative and lets us unit-test
/// validation and persistence without SwiftUI.
@MainActor
@Observable
final class CommuteSheetModel {

    var direction: CommuteDirection {
        didSet { if oldValue != direction { reseedAirportsForDirection() } }
    }
    var fromAirport: String
    var toAirport: String
    var departure: Date
    var durationSeconds: TimeInterval

    let baseCode: String
    let homeCode: String

    private let editingCommute: Commute?
    private let sourceTripId: String?
    private let convertManualEventID: String?

    var computedArrival: Date { departure.addingTimeInterval(durationSeconds) }

    /// A commute must go somewhere different and take positive time; we never persist
    /// `arrival <= departure`.
    var isValid: Bool { fromAirport != toAirport && durationSeconds > 0 }

    var isConvert: Bool { convertManualEventID != nil }
    var isEditing: Bool { editingCommute != nil }

    // MARK: - Init

    /// Blank add, seeded from the pilot's base/home and the remembered route duration.
    init(adding pilot: PilotInfo, now: Date = Date()) {
        let base = pilot.base.rawValue
        let home = pilot.effectiveHomeAirportCode
        baseCode = base; homeCode = home
        direction = .toHome
        fromAirport = base; toAirport = home
        departure = now
        durationSeconds = CommuteRouteStore.duration(from: base, to: home)
        editingCommute = nil; sourceTripId = nil; convertManualEventID = nil
    }

    /// Edit an existing saved commute.
    init(editing commute: Commute, pilot: PilotInfo) {
        baseCode = pilot.base.rawValue; homeCode = pilot.effectiveHomeAirportCode
        direction = commute.direction
        fromAirport = commute.fromAirport; toAirport = commute.toAirport
        departure = commute.departureTimeZulu
        durationSeconds = commute.driveDurationSeconds
        editingCommute = commute
        sourceTripId = commute.sourceTripId
        convertManualEventID = nil
    }

    /// Prefill from an engine suggestion (confirm = `.fresh`, convert = `.convert`).
    init(suggestion: CommuteSuggestion, pilot: PilotInfo) {
        baseCode = pilot.base.rawValue; homeCode = pilot.effectiveHomeAirportCode
        direction = suggestion.direction
        fromAirport = suggestion.fromAirport; toAirport = suggestion.toAirport
        departure = suggestion.departureTimeZulu
        durationSeconds = suggestion.driveDurationSeconds
        editingCommute = nil
        sourceTripId = suggestion.sourceTripId
        switch suggestion.origin {
        case .fresh:           convertManualEventID = nil
        case .convert(let id): convertManualEventID = id
        }
    }

    // MARK: - Behavior

    private func reseedAirportsForDirection() {
        switch direction {
        case .toHome: fromAirport = baseCode; toAirport = homeCode
        case .toWork: fromAirport = homeCode; toAirport = baseCode
        }
    }

    /// Persists the commute and returns it. Remembers the route duration; for a converted
    /// suggestion, soft-deletes (retires) the source manual event so the drive isn't double-listed.
    @discardableResult
    func commit(into context: ModelContext, now: Date = Date()) -> Commute {
        let commute = editingCommute ?? Commute()
        commute.fromAirport = fromAirport
        commute.toAirport = toAirport
        commute.direction = direction
        commute.departureTimeZulu = departure
        commute.arrivalTimeZulu = computedArrival
        commute.driveDurationSeconds = durationSeconds
        if editingCommute == nil {
            commute.sourceTripId = sourceTripId
            context.insert(commute)
        }
        commute.lastModifiedAt = now
        commute.needsPush = true

        if let manualEventID = convertManualEventID {
            retireManualEvent(id: manualEventID, in: context, now: now)
        }

        try? context.save()
        CommuteRouteStore.setDuration(durationSeconds, from: fromAirport, to: toAirport)
        return commute
    }

    private func retireManualEvent(id: String, in context: ModelContext, now: Date) {
        let descriptor = FetchDescriptor<ManualEvent>(
            predicate: #Predicate { $0.id == id && $0.deletedAt == nil }
        )
        guard let event = try? context.fetch(descriptor).first else { return }   // already gone → degrade to plain create
        // Soft-delete retires the manual event from the timeline and syncs the deletion, so the
        // drive isn't listed twice. No separate hide: a hidden flag is for events that still exist,
        // and both `HiddenEventsManager.applyHidden` and `deriveSet` filter on `deletedAt == nil`.
        SoftDeleteService.softDelete(event, at: now, in: context)
    }
}
```

- [ ] **Step 5: [USER-RUN]** Cmd-U on `DutyTests/CommuteSheetModelTests`. Expected: **PASS** (8 tests).

- [ ] **Step 6: [CONFIRM] Commit**

```bash
git -C /Users/toddanderson/Dev/Duty add Duty/ViewModels/CommuteSheetModel.swift DutyTests/CommuteSheetModelTests.swift
git -C /Users/toddanderson/Dev/Duty commit -m "feat(duty): CommuteSheetModel — validation + commit (create/update/convert)"
```

---

## Task 3: `CommuteSheet` view

**Files:**
- Create: `Duty/Views/Settings/CommuteSheet.swift`

No XCTest (SwiftUI view); verified by the user in Xcode together with Task 4. Mirror `Duty/Views/ManualEvent/AddManualEventView.swift` for the toolbar/save-button/overlay idiom and `Duty/Views/Components/LocationPickerView.swift` for the airport picker.

- [ ] **Step 1: Create the view**

`Duty/Views/Settings/CommuteSheet.swift`:

```swift
import SwiftUI
import SwiftData

/// Unified sheet for adding, editing, confirming, or converting a commute.
/// All four modes share the same form; only the title, the save-button label, and the
/// (convert-only) replacement note differ. Logic lives in `CommuteSheetModel`.
struct CommuteSheet: View {

    enum Mode: Identifiable {
        case add
        case edit(Commute)
        case confirm(CommuteSuggestion)
        case convert(CommuteSuggestion)

        var id: String {
            switch self {
            case .add:               return "add"
            case .edit(let c):       return "edit-\(c.id)"
            case .confirm(let s):    return "confirm-\(s.id)"
            case .convert(let s):    return "convert-\(s.id)"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var model: CommuteSheetModel
    private let kind: Kind
    private let airportCodes: [String]
    private let convertSourceTitle: String?

    private enum Kind { case add, edit, confirm, convert }

    init(mode: Mode, pilot: PilotInfo, airportCodes: [String], convertSourceTitle: String? = nil) {
        switch mode {
        case .add:
            _model = State(initialValue: CommuteSheetModel(adding: pilot)); kind = .add
        case .edit(let c):
            _model = State(initialValue: CommuteSheetModel(editing: c, pilot: pilot)); kind = .edit
        case .confirm(let s):
            _model = State(initialValue: CommuteSheetModel(suggestion: s, pilot: pilot)); kind = .confirm
        case .convert(let s):
            _model = State(initialValue: CommuteSheetModel(suggestion: s, pilot: pilot)); kind = .convert
        }
        self.airportCodes = airportCodes
        self.convertSourceTitle = convertSourceTitle
    }

    private var navTitle: String {
        switch kind {
        case .add:     return "New commute"
        case .edit:    return "Edit commute"
        case .confirm: return "Confirm commute"
        case .convert: return "Convert to commute"
        }
    }

    private var saveLabel: String {
        switch kind {
        case .add:     return "Add commute"
        case .edit:    return "Save"
        case .confirm: return "Confirm commute"
        case .convert: return "Convert"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if kind == .convert, let title = convertSourceTitle {
                        Label("Saving will replace your “\(title)” event.", systemImage: "arrow.left.right")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    directionSection
                    routeSection
                    timingSection
                    saveButton
                }
                .padding(.vertical)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var directionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Direction").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            Picker("Direction", selection: $model.direction) {
                Text("Driving home").tag(CommuteDirection.toHome)
                Text("Driving to work").tag(CommuteDirection.toWork)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
    }

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Route").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            VStack(spacing: 0) {
                HStack {
                    Text("From")
                    Spacer()
                    LocationPickerView(selection: $model.fromAirport, locationCodes: airportCodes)
                }
                .padding()
                Divider().padding(.leading)
                HStack {
                    Text("To")
                    Spacer()
                    LocationPickerView(selection: $model.toAirport, locationCodes: airportCodes)
                }
                .padding()
            }
            .background(.background.secondary, in: .rect(cornerRadius: 12))
            .padding(.horizontal)
            if model.fromAirport == model.toAirport {
                Text("Choose two different airports.")
                    .font(.footnote).foregroundStyle(.red).padding(.horizontal)
            }
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timing").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            VStack(spacing: 0) {
                DatePicker("Departs", selection: $model.departure)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    .padding()
                Divider().padding(.leading)
                DurationPicker(seconds: $model.durationSeconds).padding()
                Divider().padding(.leading)
                HStack {
                    Text("Arrives").foregroundStyle(.secondary)
                    Spacer()
                    Text(model.computedArrival, format: .dateTime.weekday().hour().minute())
                        .foregroundStyle(.secondary)
                }
                .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                .padding()
            }
            .background(.background.secondary, in: .rect(cornerRadius: 12))
            .padding(.horizontal)
            Text("Times shown in Zulu and stored as Zulu.")
                .font(.caption).foregroundStyle(.tertiary).padding(.horizontal)
        }
    }

    private var saveButton: some View {
        Button {
            model.commit(into: modelContext)
            NotificationCenter.default.post(name: .scheduleDidChange, object: nil)
            dismiss()
        } label: {
            Text(saveLabel).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!model.isValid)
        .padding(.horizontal)
    }
}

/// Two-menu hours/minutes editor over a `TimeInterval`. Minutes step by 5.
private struct DurationPicker: View {
    @Binding var seconds: TimeInterval

    private var hours: Int { Int(seconds) / 3600 }
    private var minutes: Int { (Int(seconds) % 3600) / 60 }

    var body: some View {
        HStack {
            Text("Drive time")
            Spacer()
            Picker("Hours", selection: Binding(
                get: { hours },
                set: { seconds = TimeInterval($0 * 3600 + minutes * 60) })) {
                ForEach(0..<13) { Text("\($0) h").tag($0) }
            }
            .pickerStyle(.menu)
            Picker("Minutes", selection: Binding(
                get: { minutes },
                set: { seconds = TimeInterval(hours * 3600 + $0 * 60) })) {
                ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0) m").tag($0) }
            }
            .pickerStyle(.menu)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Drive time")
        .accessibilityValue("\(hours) hours \(minutes) minutes")
    }
}
```

> Notes for the implementer: confirm `.scheduleDidChange` is the notification `AddManualEventView` posts after save (open that file). If `LocationPickerView`'s native presentation differs from a trailing menu, keep its presentation — don't restyle it. `.background(.background.secondary, in:)` requires iOS 17; if Settings uses a custom card modifier elsewhere, prefer that for visual consistency.

- [ ] **Step 2: [USER-RUN]** Build only (Cmd-B) to confirm `CommuteSheet` compiles. (Functional verification happens in Task 4, once it's presented.) Expected: build succeeds.

- [ ] **Step 3: [CONFIRM] Commit**

```bash
git -C /Users/toddanderson/Dev/Duty add Duty/Views/Settings/CommuteSheet.swift
git -C /Users/toddanderson/Dev/Duty commit -m "feat(duty): CommuteSheet — unified add/edit/confirm/convert commute sheet"
```

---

## Task 4: `PartnerSharingView` Commutes section

**Files:**
- Modify: `Duty/Views/Settings/PartnerSharingView.swift`

No XCTest; verified end-to-end by the user in Xcode.

- [ ] **Step 1: Add state and a computed gate.** Near the existing `@Query … pilots` (~line 17) and `activePilot` (~line 61), add:

```swift
@Query(filter: #Predicate<Commute> { $0.deletedAt == nil },
       sort: \Commute.departureTimeZulu, order: .forward)
private var commutes: [Commute]

@State private var commuteSuggestions: [CommuteSuggestion] = []
@State private var commuteSheet: CommuteSheet.Mode?

/// Commutes only make sense when the pilot's home differs from base.
private var isCommuter: Bool {
    guard let pilot = activePilot else { return false }
    return pilot.effectiveHomeAirportCode != pilot.base.rawValue
}
```

- [ ] **Step 2: Add the section builder and helpers.** Add these methods to `PartnerSharingView` (place near `partnersSection`, ~line 587):

```swift
@ViewBuilder
private var commutesSection: some View {
    if let pilot = activePilot, beaconManager.isSharing, isCommuter {
        Section {
            ForEach(commuteSuggestions) { suggestion in
                commuteSuggestionRow(suggestion, pilot: pilot)
            }
            ForEach(commutes) { commute in
                commuteRow(commute)
            }
            Button {
                commuteSheet = .add
            } label: {
                Label("Add commute", systemImage: "plus")
            }
        } header: {
            Text("Commutes")
        } footer: {
            Text("Shown because your home (\(pilot.effectiveHomeAirportCode)) differs from your base (\(pilot.base.rawValue)). Partners see these as “Driving home” / “Driving to work.”")
        }
    }
}

@ViewBuilder
private func commuteSuggestionRow(_ suggestion: CommuteSuggestion, pilot: PilotInfo) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Image(systemName: "car.fill").foregroundStyle(.tint)
            Text(suggestion.direction == .toHome ? "Driving home" : "Driving to work")
                .font(.headline)
            Spacer()
            Text(suggestion.origin.isConvert ? "From your event" : "Suggested")
                .font(.caption).foregroundStyle(.tint)
        }
        Text("\(suggestion.fromAirport) → \(suggestion.toAirport) · \(suggestion.departureTimeZulu.formatted(.dateTime.weekday().hour().minute()))")
            .font(.subheadline).foregroundStyle(.secondary)
        HStack {
            Button {
                commuteSheet = suggestion.origin.isConvert ? .convert(suggestion) : .confirm(suggestion)
            } label: {
                Label(suggestion.origin.isConvert ? "Convert" : "Confirm",
                      systemImage: suggestion.origin.isConvert ? "arrow.left.right" : "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Dismiss") {
                CommuteSuggestionDismissalStore.dismiss(suggestion.id)
                commuteSuggestions.removeAll { $0.id == suggestion.id }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    .padding(.vertical, 4)
}

@ViewBuilder
private func commuteRow(_ commute: Commute) -> some View {
    Button {
        commuteSheet = .edit(commute)
    } label: {
        HStack(spacing: 10) {
            Image(systemName: "car.fill").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(commute.direction == .toHome ? "Driving home" : "Driving to work")
                    .foregroundStyle(.primary)
                Text("\(commute.fromAirport) → \(commute.toAirport) · \(commute.departureTimeZulu.formatted(.dateTime.weekday().hour().minute()))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
        Button(role: .destructive) {
            SoftDeleteService.softDelete(commute)
            try? modelContext.save()
            refreshCommuteSuggestions()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

private func refreshCommuteSuggestions() {
    guard let pilot = activePilot, isCommuter else {
        commuteSuggestions = []
        return
    }
    let raw = CommuteSuggestionEngine(modelContext: modelContext).suggestions(for: pilot)
    CommuteSuggestionDismissalStore.prune(activeKeys: Set(raw.map(\.id)))
    commuteSuggestions = raw.filter { !CommuteSuggestionDismissalStore.isDismissed($0.id) }
}

private func titleForConvert(_ mode: CommuteSheet.Mode) -> String? {
    guard case .convert(let suggestion) = mode,
          case .convert(let manualEventID) = suggestion.origin else { return nil }
    let descriptor = FetchDescriptor<ManualEvent>(
        predicate: #Predicate { $0.id == manualEventID && $0.deletedAt == nil })
    return try? modelContext.fetch(descriptor).first?.title
}

/// All pickable airport codes, guaranteeing the pilot's base and home are present so the
/// From/To pickers always have a valid selection even if the provider omits a code.
private func commuteAirportCodes(for pilot: PilotInfo) -> [String] {
    var codes = Set(AirportDataProvider.shared.allAirportCodes())
    codes.insert(pilot.base.rawValue)
    codes.insert(pilot.effectiveHomeAirportCode)
    return codes.sorted()
}
```

Add a tiny convenience on the suggestion origin (same file, file-private — place at top level of the file, not inside the struct):

```swift
private extension CommuteSuggestion.Origin {
    var isConvert: Bool { if case .convert = self { return true }; return false }
}
```

- [ ] **Step 3: Render the section + present the sheet + refresh on appear.** In the main body's `List` (where `partnersSection` is rendered), add `commutesSection` immediately after `partnersSection`. On the same `List` (or the view), add:

```swift
.sheet(item: $commuteSheet) { mode in
    if let pilot = activePilot {
        CommuteSheet(mode: mode,
                     pilot: pilot,
                     airportCodes: commuteAirportCodes(for: pilot),
                     convertSourceTitle: titleForConvert(mode))
        .onDisappear { refreshCommuteSuggestions() }
    }
}
```

Then call `refreshCommuteSuggestions()` from the existing `handleOnAppear()` (~line 1035) and from the `.partnerDataDidChangeExternally` handler (~line 408) so the list stays current.

- [ ] **Step 4: [USER-RUN] Functional verification in Xcode (build_run_sim).** With a pilot whose home (e.g. ATL) ≠ base (e.g. SDF) and sharing ON, confirm:
  1. The `Commutes` section appears; it is **absent** when home == base or sharing is off.
  2. With a >24h base-anchored gap, a suggestion row shows; **Confirm** opens the prefilled sheet; saving adds a row.
  3. A manual event titled like "Drive home" in a gap shows a **Convert** row; converting creates the commute and the manual event disappears from the timeline.
  4. **Dismiss** removes the suggestion and it does not return after relaunch.
  5. Tapping a saved row opens **Edit**; swipe deletes it (row disappears; it's a soft delete).
  6. **Add commute** opens a blank sheet; `from == to` and zero duration disable Save.

- [ ] **Step 5: [CONFIRM] Commit**

```bash
git -C /Users/toddanderson/Dev/Duty add Duty/Views/Settings/PartnerSharingView.swift
git -C /Users/toddanderson/Dev/Duty commit -m "feat(duty): PartnerSharing Commutes section — suggestions, confirm/convert/dismiss, edit, delete"
```

---

## Task 5: Deferred-from-3b cleanup integration test

**Files:**
- Create: `DutyTests/CommuteCleanupIntegrationTests.swift`

Closes the Stage 3b reviewer note: a confirmed suggestion's `(sourceTripId, direction)` must round-trip with `CommuteCleanupService`'s "live" judgement. Cleanup judges "live" by **trip presence + `deletedAt`** (it does not re-check base-anchoring), so a plain `Trip(id:…, base:"SDF")` with no flight graph is sufficient — this mirrors `CommuteCleanupServiceTests`.

- [ ] **Step 1: Confirm against the live code.** Open `DutyTests/CommuteCleanupServiceTests.swift` and verify: the `makeContext()` container idiom (Schema(SyncSchema.allModels)), the `Trip(id:…, base:)` constructor, soft-delete via `trip.deletedAt = Date()`, and that `CommuteCleanupService.cleanupOrphanedCommutes(in:)` returns the removed count. Adapt the test below if any differ.

- [ ] **Step 2: Write the test**

`DutyTests/CommuteCleanupIntegrationTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

@MainActor
final class CommuteCleanupIntegrationTests: XCTestCase {

    private var container: ModelContainer?   // retained — SwiftData traps on save() if it deallocates

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        self.container = container
        return container.mainContext
    }

    override func tearDown() { container = nil; super.tearDown() }

    private func makeCommuterPilot(in ctx: ModelContext) -> PilotInfo {
        let pilot = PilotInfo()
        pilot.baseRawValue = "SDF"; pilot.homeAirportCode = "ATL"; pilot.isActive = true
        ctx.insert(pilot)
        return pilot
    }

    private func liveCommute(id: String, in ctx: ModelContext) throws -> Commute? {
        try ctx.fetch(FetchDescriptor<Commute>()).first { $0.id == id }
    }

    /// A commute confirmed from a suggestion (carrying that trip's id) survives cleanup while its
    /// source trip is live, and is reaped once that trip is soft-deleted — the round-trip the Stage
    /// 3b reviewer asked to verify: the confirm path's sourceTripId matches the cleanup's
    /// "live trip" judgement.
    func test_confirmedSuggestion_survivesWhileTripLive_thenReapedWhenTripDeleted() throws {
        let ctx = try makeContext()
        let pilot = makeCommuterPilot(in: ctx)

        let trip = Trip(id: "TRIP-X", startDate: Date(), endDate: Date(),
                        dutyTime: 0, blockTime: 0, creditTime: 0, days: 1, tafb: 0, base: "SDF")
        ctx.insert(trip)
        try ctx.save()

        // Confirm via the real model path.
        let dep = Date(timeIntervalSince1970: 5_000_000)
        let suggestion = CommuteSuggestion(
            sourceTripId: "TRIP-X", direction: .toHome, fromAirport: "SDF", toAirport: "ATL",
            departureTimeZulu: dep, arrivalTimeZulu: dep.addingTimeInterval(7200),
            driveDurationSeconds: 7200, origin: .fresh)
        let commute = CommuteSheetModel(suggestion: suggestion, pilot: pilot).commit(into: ctx)
        XCTAssertEqual(commute.sourceTripId, "TRIP-X")

        // Live trip → cleanup keeps it.
        let removedWhileLive = CommuteCleanupService.cleanupOrphanedCommutes(in: ctx)
        try ctx.save()
        XCTAssertEqual(removedWhileLive, 0, "commute must survive cleanup while its source trip is live")
        XCTAssertNil(try liveCommute(id: commute.id, in: ctx)?.deletedAt)

        // Soft-delete the trip → cleanup reaps the now-orphaned commute.
        trip.deletedAt = Date()
        try ctx.save()
        let removedWhenOrphan = CommuteCleanupService.cleanupOrphanedCommutes(in: ctx)
        try ctx.save()
        XCTAssertEqual(removedWhenOrphan, 1, "commute must be reaped once its source trip is gone")
        XCTAssertNotNil(try liveCommute(id: commute.id, in: ctx)?.deletedAt)
    }
}
```

- [ ] **Step 3: [USER-RUN]** Cmd-U on `DutyTests/CommuteCleanupIntegrationTests`. Expected: **PASS** (1 test).

- [ ] **Step 4: [CONFIRM] Commit**

```bash
git -C /Users/toddanderson/Dev/Duty add DutyTests/CommuteCleanupIntegrationTests.swift
git -C /Users/toddanderson/Dev/Duty commit -m "test(duty): confirmed commute round-trips with cleanup live judgement (closes 3b deferral)"
```

---

## Done-when
- `Commutes` section appears only for sharing commuters (home ≠ base); suggestions de-dup against persisted dismissals; Confirm/Convert open the editable sheet; Convert retires the source manual event; saved commutes edit/soft-delete; route durations are remembered.
- All four new `DutyTests` classes pass in Xcode.
- No `xcodebuild` run by agents; every commit confirmed live; `project.pbxproj` and the user's WIP files untouched.
- Stage 4 (production provisioning + release) remains GATED on explicit user authorization — out of scope here.

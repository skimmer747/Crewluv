# Commutes in the Trip List (Duty) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** List commute drives in Duty's `TripListView` so they behave like a manual event — tap to edit, swipe to delete — and deleting removes the commute everywhere (both sync backends + the partner beacon) and stops it being re-suggested.

**Architecture:** Make `Commute` a first-class `ListItem` (mirroring `ManualEvent`). Extract the delete/suggestion-key/airport-code logic that already lives privately in `PartnerSharingView` into shared, unit-tested helpers so the two surfaces cannot diverge (the spec's "reuse, don't re-derive"). The event timeline keeps its existing separate commute source; the new `ListItem.commute` arm in `EventTimelineItem.from` is a `break` so commutes are not double-counted.

**Tech Stack:** SwiftUI, SwiftData (`@Model`, `@Query`), XCTest. Targets iOS 17+.

**Working rules (carry into every task):**
- **The USER runs builds/tests in Xcode (Cmd-B / Cmd-U).** Do NOT run `xcodebuild`/`xcrun`; tell any subagent the same. "Verify" steps below mean *hand the named test class / a build to the user*.
- **Confirm every commit with the user before running it.** Commit steps are written out but are gated on the user's OK.
- Do not stage `project.pbxproj` or the user's WIP (`PilotStatusBeaconManager.swift`, `SyncGuidanceCopy.swift`, `SyncGuidanceCopyTests.swift`).
- Spec: [2026-06-23-commute-triplistview-list-design.md](../specs/2026-06-23-commute-triplistview-list-design.md).

---

## File Structure

- `Duty/Models/Commute.swift` — **modify**: add a `// MARK: - Trip-list & suggestion helpers` extension (`belongsInTripList`, `regeneratedSuggestionKey`).
- `Duty/Views/Settings/CommuteSheet.swift` — **modify**: add `static func airportCodes(for:)` (moved from PartnerSharingView).
- `Duty/Utils/PartnerBeacon/CommuteListActions.swift` — **create**: shared `delete(_:in:)`.
- `Duty/Views/Settings/PartnerSharingView.swift` — **modify**: call the shared helpers; remove the now-duplicated private ones.
- `Duty/Views/Trip/TripListView.swift` — **modify**: `ListItem.commute`, `@Query commutes`, `combinedItems`, `commuteRowView`, edit-sheet wiring, delete arm, scroll tidy-up.
- `Duty/Views/Timeline/EventTimelineView.swift` — **modify**: `from` loop `.commute: break`.
- `DutyTests/CommuteTripListSupportTests.swift` — **create**: model-helper tests.
- `DutyTests/CommuteListActionsTests.swift` — **create**: delete-path tests.

---

## Task 1: Shared commute helpers (model props + airport codes)

**Files:**
- Modify: `Duty/Models/Commute.swift` (append extension after the `Syncable` extension)
- Modify: `Duty/Views/Settings/CommuteSheet.swift` (add static helper)
- Modify: `Duty/Views/Settings/PartnerSharingView.swift` (call site ~398; remove private `commuteAirportCodes` ~774-779)
- Test: `DutyTests/CommuteTripListSupportTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DutyTests/CommuteTripListSupportTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

@MainActor
final class CommuteTripListSupportTests: XCTestCase {

    func test_regeneratedSuggestionKey_suggestedCommute_matchesEngineIdFormat() {
        let c = Commute()
        c.sourceTripId = "TRIP1"
        c.fromAirport = "SDF"
        c.toAirport = "SWF"
        c.direction = .toHome
        XCTAssertEqual(c.regeneratedSuggestionKey, "TRIP1|toHome|SDF|SWF")
    }

    func test_regeneratedSuggestionKey_manualCommute_isNil() {
        let c = Commute()            // sourceTripId defaults to nil
        c.fromAirport = "SWF"
        c.toAirport = "SDF"
        c.direction = .toWork
        XCTAssertNil(c.regeneratedSuggestionKey)
    }

    func test_belongsInTripList_liveVisible_isTrue() {
        XCTAssertTrue(Commute().belongsInTripList)
    }

    func test_belongsInTripList_hidden_isFalse() {
        let c = Commute(); c.hiddenFromTimeline = true
        XCTAssertFalse(c.belongsInTripList)
    }

    func test_belongsInTripList_deleted_isFalse() {
        let c = Commute(); c.deletedAt = Date()
        XCTAssertFalse(c.belongsInTripList)
    }
}
```

- [ ] **Step 2: Add the model helpers**

Append to `Duty/Models/Commute.swift` (after the `extension Commute: Syncable` block):

```swift
// MARK: - Trip-list & suggestion helpers

extension Commute {
    /// Whether this commute should appear in the pilot's trip list: live (not tombstoned)
    /// and not hidden from the timeline.
    var belongsInTripList: Bool {
        deletedAt == nil && !hiddenFromTimeline
    }

    /// The `CommuteSuggestion.id` this commute would regenerate, used to suppress immediate
    /// re-suggestion when it is deleted. `nil` for manually-added commutes (no source trip).
    /// Must stay in sync with `CommuteSuggestion.id` ("<sourceTripId>|<direction>|<from>|<to>").
    var regeneratedSuggestionKey: String? {
        guard let tripID = sourceTripId else { return nil }
        return "\(tripID)|\(direction.rawValue)|\(fromAirport)|\(toAirport)"
    }
}
```

- [ ] **Step 3: Add `CommuteSheet.airportCodes(for:)` and use it in PartnerSharingView**

Add to `Duty/Views/Settings/CommuteSheet.swift` (top-level, after the `CommuteSheet` struct):

```swift
extension CommuteSheet {
    /// All pickable airport codes, guaranteeing the pilot's base and home are present so the
    /// From/To pickers always have a valid selection even if the provider omits a code.
    static func airportCodes(for pilot: PilotInfo) -> [String] {
        var codes = Set(AirportDataProvider.shared.allAirportCodes())
        codes.insert(pilot.base.rawValue)
        codes.insert(pilot.effectiveHomeAirportCode)
        return codes.sorted()
    }
}
```

In `Duty/Views/Settings/PartnerSharingView.swift`, change the CommuteSheet presentation (≈line 398) from `airportCodes: commuteAirportCodes(for: pilot)` to `airportCodes: CommuteSheet.airportCodes(for: pilot)`, then **delete** the now-unused private `commuteAirportCodes(for:)` (≈lines 772-779). Leave `suggestionKey(for:)` for now (removed in Task 2).

- [ ] **Step 4: Verify (user)**

Hand off: "In Xcode, run `DutyTests/CommuteTripListSupportTests` (Cmd-U) and confirm a clean build." Expected: 5 tests PASS, project builds (PartnerSharingView still compiles with the relocated helper).

- [ ] **Step 5: Commit** (after user OK)

```bash
git -C /Users/toddanderson/Dev/Duty add Duty/Models/Commute.swift Duty/Views/Settings/CommuteSheet.swift Duty/Views/Settings/PartnerSharingView.swift DutyTests/CommuteTripListSupportTests.swift
git -C /Users/toddanderson/Dev/Duty commit -m "refactor(duty): extract shared commute helpers (belongsInTripList, regeneratedSuggestionKey, airportCodes)"
```

---

## Task 2: Shared commute delete action

**Files:**
- Create: `Duty/Utils/PartnerBeacon/CommuteListActions.swift`
- Modify: `Duty/Views/Settings/PartnerSharingView.swift` (swipe-delete ≈732-744; remove private `suggestionKey(for:)` ≈783-786)
- Test: `DutyTests/CommuteListActionsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `DutyTests/CommuteListActionsTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

@MainActor
final class CommuteListActionsTests: XCTestCase {

    /// Retained so the in-memory store outlives the context (SwiftData traps on save otherwise).
    private var container: ModelContainer?

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        self.container = container
        return container.mainContext
    }

    override func setUp() {
        super.setUp()
        CommuteSuggestionDismissalStore.prune(activeKeys: [])   // clear any remembered dismissals
    }

    override func tearDown() {
        CommuteSuggestionDismissalStore.prune(activeKeys: [])
        container = nil
        super.tearDown()
    }

    func test_delete_suggestedCommute_softDeletesAndSuppressesResuggest() throws {
        let ctx = try makeContext()
        let c = Commute()
        c.sourceTripId = "TRIP1"; c.fromAirport = "SDF"; c.toAirport = "SWF"; c.direction = .toHome
        ctx.insert(c)
        try ctx.save()

        CommuteListActions.delete(c, in: ctx)

        XCTAssertNotNil(c.deletedAt, "soft-delete should set the tombstone")
        XCTAssertTrue(CommuteSuggestionDismissalStore.isDismissed("TRIP1|toHome|SDF|SWF"))
    }

    func test_delete_manualCommute_softDeletesWithoutDismissal() throws {
        let ctx = try makeContext()
        let c = Commute()            // no sourceTripId -> no suggestion key
        c.fromAirport = "SWF"; c.toAirport = "SDF"; c.direction = .toWork
        ctx.insert(c)
        try ctx.save()

        CommuteListActions.delete(c, in: ctx)

        XCTAssertNotNil(c.deletedAt)
        XCTAssertTrue(CommuteSuggestionDismissalStore.dismissedIDs().isEmpty)
    }
}
```

- [ ] **Step 2: Create the shared delete action**

Create `Duty/Utils/PartnerBeacon/CommuteListActions.swift`:

```swift
//
//  CommuteListActions.swift
//  Duty
//

import Foundation
import SwiftData

/// Deletion shared by every surface that lists commutes (Partner Sharing + the trip list)
/// so the behavior cannot diverge. Soft-deletes the commute (tombstone -> syncs to both
/// backends, drops from the partner beacon) and, if it would be re-suggested, records the
/// dismissal so the suggestion engine does not re-offer it on the next refresh.
@MainActor
enum CommuteListActions {
    static func delete(_ commute: Commute, in context: ModelContext) {
        // A commute confirmed from a suggestion would otherwise be re-suggested on the very
        // next refresh; record it as dismissed. Manual commutes (no sourceTripId) have no key.
        if let key = commute.regeneratedSuggestionKey {
            CommuteSuggestionDismissalStore.dismiss(key)
        }
        SoftDeleteService.softDelete(commute)
        try? context.save()
    }
}
```

- [ ] **Step 3: Route PartnerSharingView's swipe-delete through the shared action**

In `Duty/Views/Settings/PartnerSharingView.swift`, replace the swipe-delete body (≈732-741) so the destructive button does:

```swift
Button(role: .destructive) {
    CommuteListActions.delete(commute, in: modelContext)
    refreshCommuteSuggestions()
} label: {
    Label("Delete", systemImage: "trash")
}
```

Then **delete** the now-unused private `suggestionKey(for:)` (≈783-786).

- [ ] **Step 4: Verify (user)**

Hand off: "Run `DutyTests/CommuteListActionsTests` (Cmd-U) and confirm a clean build." Expected: 2 tests PASS; PartnerSharingView delete still works (manually swipe-delete a commute on device if convenient).

- [ ] **Step 5: Commit** (after user OK)

```bash
git -C /Users/toddanderson/Dev/Duty add Duty/Utils/PartnerBeacon/CommuteListActions.swift Duty/Views/Settings/PartnerSharingView.swift DutyTests/CommuteListActionsTests.swift
git -C /Users/toddanderson/Dev/Duty commit -m "refactor(duty): shared CommuteListActions.delete (soft-delete + suppress re-suggest)"
```

---

## Task 3: List commutes in TripListView + edit/delete wiring

This task adds `ListItem.commute`, which makes every `switch` over `ListItem` non-exhaustive until each arm is added — so the project will not compile until all sub-steps land. Do them together, then build once.

**Files:**
- Modify: `Duty/Views/Trip/TripListView.swift`
- Modify: `Duty/Views/Timeline/EventTimelineView.swift`

- [ ] **Step 1: Add the enum case + id/date arms** (TripListView, `enum ListItem` ≈157)

Add the case after `case bidEvent(...)`:
```swift
        case commute(Commute)              // Base<->home ground commute drive
```
Add to the `id` switch:
```swift
            case .commute(let commute): return "commute_\(commute.id)"
```
Add to the `date` switch:
```swift
            case .commute(let commute): return commute.departureTimeZulu
```

- [ ] **Step 2: Add the `@Query` and append into `combinedItems`** (TripListView)

Add beside the other `@Query`s (≈line 69):
```swift
    @Query(filter: #Predicate<Commute> { $0.deletedAt == nil }, sort: [SortDescriptor(\Commute.departureTimeZulu, order: .forward)]) private var commutes: [Commute]
```
In `combinedItems`, before the final `return items.sorted...`, add:
```swift
        // Commute drives behave like manual events in the list. The @Query already excludes
        // tombstones; belongsInTripList also drops any hidden-from-timeline commute.
        items.append(contentsOf: commutes.filter { $0.belongsInTripList }.map { .commute($0) })
```

- [ ] **Step 3: Add edit-sheet state + plumbing**

In `TripListView` add `@State` beside `selectedManualEvent` (≈113):
```swift
    @State private var selectedCommute: Commute? = nil
```
In `TripListView`, beside the other `.sheet(item:)` modifiers (≈924-943), add:
```swift
        .sheet(item: $selectedCommute) { commute in
            if let pilot = pilots.first {
                CommuteSheet(mode: .edit(commute),
                             pilot: pilot,
                             airportCodes: CommuteSheet.airportCodes(for: pilot))
            }
        }
```
Where `TripListContentView(...)` is constructed (≈740, next to `selectedManualEvent: $selectedManualEvent,`), pass:
```swift
                    selectedCommute: $selectedCommute,
```
In `struct TripListContentView` add the binding beside `@Binding var selectedManualEvent: ManualEvent?` (≈2553):
```swift
    @Binding var selectedCommute: Commute?
```

- [ ] **Step 4: Add the row view** (TripListContentView, beside `manualEventRowView` ≈3667)

```swift
    private func commuteRowView(commute: Commute) -> some View {
        Button {
            selectedCommute = commute
        } label: {
            commuteRowContent(commute: commute)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func commuteRowContent(commute: Commute) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "car.fill")
                .font(.title2)
                .foregroundColor(.cyan)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(commute.direction == .toHome ? "Driving home" : "Driving to work")
                    .font(.headline)
                Text("\(commute.fromAirport) → \(commute.toAirport)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                CommuteTimeText(date: commute.departureTimeZulu, airportCode: commute.fromAirport)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(commute.direction == .toHome ? "Driving home" : "Driving to work"), \(commute.fromAirport) to \(commute.toAirport)")
        .accessibilityHint("Double tap to edit")
    }
```

- [ ] **Step 5: Add the render arm** (TripListContentView, `ForEach(combinedItems)` switch ≈2935, after the `.bidEvent` arm)

```swift
                            case .commute(let commute):
                                commuteRowView(commute: commute)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .id("commute_\(commute.id)")
```

- [ ] **Step 6: Add the delete arm** (TripListContentView, `deleteItems` switch ≈3048, after `.bidEvent`)

```swift
            case .commute(let commute):
                navigationPath = NavigationPath()
                CommuteListActions.delete(commute, in: modelContext)
```

- [ ] **Step 7: Revert the countdown scroll workaround** (TripListView, `scrollToNextItem` `.commute` arm)

Replace the existing `.commute` arm (which currently scrolls to `commute.sourceTripId`) with:
```swift
        case .commute(let commute):
            // Commutes now have a real list row; scroll straight to it.
            scrollToTripId = "commute_\(commute.id)"
```

- [ ] **Step 8: Stop the timeline double-counting** (EventTimelineView, `from` loop switch ≈170, after `.bidEvent`)

```swift
            case .commute:
                // Already sourced separately below (fetched live); skip to avoid double-counting.
                break
```

- [ ] **Step 9: Verify (user)**

Hand off: "Build in Xcode (Cmd-B). Fix any *other* `switch over ListItem` the compiler flags as non-exhaustive (expected sites are all handled: id, date, render, delete, and EventTimelineView.from). Then on device confirm: a commute appears in the trip list; tapping opens the editor; swipe-delete removes it from the list AND the timeline AND it doesn't reappear as a suggestion; each commute shows once in the timeline (not twice)."

- [ ] **Step 10: Commit** (after user OK)

```bash
git -C /Users/toddanderson/Dev/Duty add Duty/Views/Trip/TripListView.swift Duty/Views/Timeline/EventTimelineView.swift
git -C /Users/toddanderson/Dev/Duty commit -m "feat(duty): list commutes in TripListView (edit/swipe-delete like a manual event)"
```

---

## Self-Review notes (for the implementer)
- `ListItem` is `Identifiable` via its `id`; the new `"commute_\(id)"` is unique and matches the timeline/hidden-id convention, so countdown scroll-to-row resolves.
- `CommuteListActions.delete` is `@MainActor`; call sites (`deleteItems`, PartnerSharing swipe) are already main-actor SwiftUI contexts.
- The `@Query commutes` excludes tombstones; `belongsInTripList` re-applies `deletedAt == nil` plus `!hiddenFromTimeline` (defense-in-depth, mirroring the existing `liveTripStream` filter).
- Do NOT add a `.commute` arm that emits in `EventTimelineItem.from`; it must `break` (the separate fetch is the timeline's single source).

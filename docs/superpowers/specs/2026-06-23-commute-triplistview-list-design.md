# Commute in the Trip List (Duty) — Design

**Date:** 2026-06-23
**Status:** Approved (pending spec review) — implementation not started
**Repo:** Duty (`Duty/Views/Trip/TripListView.swift` + `Duty/Views/Timeline/EventTimelineView.swift`)
**Related:** [commute-feature-RESUME.md](../commute-feature-RESUME.md), [2026-06-22-commuter-home-base-commutes-design.md](2026-06-22-commuter-home-base-commutes-design.md)

## Motivation

This **reverses an earlier explicit decision** that commutes live *only* in the under-calendar event timeline and never in the `TripListView` `ListItem` row list. The user now wants commute drives listed in the trip list and behaving **like a manual event**: tap to edit, swipe to delete, and deleting removes it **everywhere** (all sync backends + the partner beacon).

## Decisions (from brainstorming Q&A)

1. **Where shown:** BOTH the trip list AND the event timeline — exactly like a manual event. (Not a move.)
2. **Row capability:** View + **edit** + delete. Tapping opens the existing `CommuteSheet` in edit mode. **No** create-from-list entry point — commutes are still created from suggestions / Partner Sharing.
3. **Hidden commutes:** A commute flagged `hiddenFromTimeline` is **also hidden from the trip list** (not just the timeline).
4. **Delete semantics:** Soft-delete (tombstone) → syncs to CloudKit + Supabase → drops from the partner beacon. Delete **also suppresses immediate re-suggestion** (mirrors the Partner Sharing delete).

## Design (Approach A — mirror the manual-event pattern)

`ManualEvent` is the template throughout: a `@Query`, an append into `combinedItems`, a `Button` row that opens an edit sheet, and a swipe-delete arm that routes to `SoftDeleteService`.

### 1. Data — commute as a `ListItem`
- Add `case commute(Commute)` to the `ListItem` enum, with:
  - `id` → `"commute_\(commute.id)"`
  - `date` → `commute.departureTimeZulu`
- Add to `TripListView`: `@Query(filter: #Predicate<Commute> { $0.deletedAt == nil }, sort: [SortDescriptor(\Commute.departureTimeZulu, order: .forward)]) private var commutes: [Commute]` (matches the existing `@Query` style for trips/jumpseats/etc.).
- In `combinedItems`, append: `commutes.filter { !$0.hiddenFromTimeline }.map { .commute($0) }`. (The `deletedAt == nil` filter is in the `@Query`; `hiddenFromTimeline` is filtered here so the predicate stays simple and the intent is visible.)

### 2. Row + tap-to-edit
- New `commuteRowView(commute:)` mirroring `manualEventRowView`'s shape and chrome: `car.fill` icon, `.cyan` accent, title "Driving home" / "Driving to work", route `FROM → TO`, departure–arrival times, drive duration.
- The row is a `Button` whose action sets `selectedCommute = commute`.
- Add `@State private var selectedCommute: Commute?` to `TripListView`, threaded as a `@Binding` into `TripListContentView` (mirror `selectedManualEvent`).
- Present `.sheet(item: $selectedCommute) { CommuteSheet(mode: .edit($0), pilot: activePilot, airportCodes: codes) }` in `TripListView` (mirror the `selectedManualEvent` sheet). `activePilot` is `pilots.first` (TripListView already `@Query`s `pilots`); `codes` (airport codes) reuse Partner Sharing's exact source — confirm during planning rather than re-derive.
- Render arm: `case .commute(let c): commuteRowView(commute: c).<list row modifiers>.id("commute_\(c.id)")`.

### 3. Delete everywhere (+ suppress re-suggest)
- `deleteItems` `.commute` arm mirrors Partner Sharing's delete:
  1. If the commute would regenerate a suggestion (its source-trip-derived `CommuteSuggestion.id`), call `CommuteSuggestionDismissalStore.dismiss(key)`. (Manual commutes with no source trip have no key — skip.)
  2. `SoftDeleteService.softDelete(commute)`.
  3. `try modelContext.save()` + `processPendingChanges()`.
- Effect: tombstone propagates to both sync backends and the partner beacon regenerates without it. The dismissal prevents the suggestion engine from re-offering the same commute on the next refresh.

### 4. No double-count in the timeline (the trap)
- The timeline is built by `EventTimelineItem.from(listItems:…)`, which loops the `ListItem`s **and then separately fetches live commutes** and appends them (EventTimelineView.swift ~L251).
- Adding `ListItem.commute` forces a new arm in that loop's `switch item`. It must be `case .commute: break` — the timeline keeps sourcing commutes from its existing separate fetch. Net result: each commute appears **once** in the list and **once** in the timeline.

### 5. Countdown scroll tidy-up (bonus, removes a prior workaround)
- Last session, because commutes had no list row, `scrollToNextItem`'s `.commute` arm scrolled to `commute.sourceTripId`. Now that a real row exists with id `"commute_\(id)"`, revert that arm to `scrollToTripId = "commute_\(commute.id)"` so the countdown scrolls to the commute itself.

### 6. Exhaustiveness
`ListItem` switches to update (compiler-enforced; a full sweep is part of implementation):
- `ListItem.id`, `ListItem.date`, `combinedItems` (TripListView)
- row renderer `switch item`, `deleteItems` `switch item` (TripListView)
- `EventTimelineItem.from` loop `switch item` (EventTimelineView)

## Non-goals (YAGNI)
- No create-a-commute entry point in the trip list (creation stays in suggestions / Partner Sharing).
- No extraction of a shared commute-row component for list + timeline (rows have different chrome; revisit only if they converge).
- No change to the timeline's existing commute source or to `CommuteSheet`/`SoftDeleteService`/`CommuteSuggestionDismissalStore` internals.

## Testing
- Unit: deleting a commute via the list path sets `deletedAt` and records the dismissal key (when one exists); `combinedItems` includes live, non-hidden commutes and excludes deleted / hidden ones.
- The **user** runs the build (exhaustive-switch compile check) + on-device verification in Xcode. Claude does not auto-build.

## Risks / edge cases
- **Double-count** in the timeline — addressed by the `break` arm (§4); verify the timeline shows each commute once.
- **Hidden commutes unreachable from the list** — by design they don't appear; un-hiding/management stays in the existing hidden-events / Partner Sharing surface.
- **Edit sheet inputs** — `CommuteSheet(.edit)` needs the active `PilotInfo` and airport codes; reuse Partner Sharing's exact sourcing to avoid a second, divergent path.
- **Suggestion key derivation** — reuse Partner Sharing's existing helper for the regenerated `CommuteSuggestion.id`; do not re-derive it independently.

## Files expected to change
- `Duty/Views/Trip/TripListView.swift` — enum case, `@Query`, `combinedItems`, row view, edit-sheet wiring, delete arm, scroll tidy-up.
- `Duty/Views/Timeline/EventTimelineView.swift` — `from` loop `.commute: break`.
- `DutyTests/` — new tests for the list delete path + `combinedItems` membership.

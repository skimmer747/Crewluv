# Commute Stage 3c — Partner Sharing "Commutes" UI: design decisions

**Date:** 2026-06-23. Addendum to the authoritative design spec
`docs/superpowers/specs/2026-06-22-commuter-home-base-commutes-design.md` (§11, §7, §9.3).
Records the UI decisions resolved in brainstorming for Stage 3c. The master spec governs everything
not restated here. Where this addendum and the master spec differ, **this addendum wins for Stage 3c UI**.

## Scope (what 3c actually builds)

Stage 3c is **purely the Duty pilot-app UI** that lets a commuter manage commutes and act on engine
suggestions. The data layer is already shipped:

- `Commute` `@Model`, `CommuteDirection`, `CommuteRouteStore`, `CommuteSuggestion`,
  `CommuteSuggestionEngine`, `CommuteCleanupService`, `SoftDeleteService.softDelete(_ commute:)`,
  `HiddenEventsManager` commute support, `SyncSchema`/`SupabaseSyncEngine`/`CommuteRow`/migration —
  all DONE in Stages 2 / 3a / 3b. **Do not re-implement them.**

In scope: `PartnerSharingView` Commutes section, a unified add/edit/confirm/convert sheet, a small
persistent dismissal store, and the deferred-from-3b cleanup integration test.

Out of scope (deferred per master spec §16): MapKit drive-time estimate, cross-device sync of
remembered durations, non-base-anchored *suggestions* (the manual editor may still set any airports),
transport modes other than driving.

## Resolved decisions

1. **Airports — editable pickers.** The sheet has explicit From and To airport pickers (reuse
   `LocationPickerView` + `AirportDataProvider`), seeded to base/home from the active `PilotInfo`.
   Validation: `from != to`. The *suggestion engine* remains base-anchored only; the *manual editor*
   may set any airports (a non-base-anchored commute simply won't be auto-suggested).

2. **Dismiss — persistent.** Dismissing a suggestion stores its stable id
   (`sourceTripId|direction|fromAirport|toAirport`, == `CommuteSuggestion.id`) in a new
   `CommuteSuggestionDismissalStore` backed by `SharedUserDefaults`. Dismissed suggestions are filtered
   out of the section until the underlying trip changes (the id changes). Mirrors `CommuteRouteStore`.

3. **Confirm / Convert — open the prefilled, editable sheet.** Both Confirm and Convert open the same
   sheet, prefilled from the suggestion, so the pilot can adjust airports and times before saving.
   - **Confirm** (`origin == .fresh`): on save, create the `Commute`.
   - **Convert** (`origin == .convert(manualEventID:)`): on save, create the `Commute` **and** retire the
     source manual event — fetch the `ManualEvent` by id; if present,
     `SoftDeleteService.softDelete(manualEvent:in:)` (this removes it from the timeline and syncs the
     deletion, so the drive isn't listed twice); if already gone, degrade silently to a plain create.
     **No separate hide** — a `hiddenFromTimeline` flag is for events that still exist, and both
     `HiddenEventsManager.applyHidden` and `deriveSet` filter on `deletedAt == nil`, so hiding a
     soft-deleted event is a no-op. The sheet shows a one-line note: "Saving will replace your '<title>' event."

4. **Timing — departure + duration.** The sheet edits departure date/time (Zulu, pickers shown in
   local zone via the env `timeZone` GMT-0 + local-aware display) and an editable **duration**
   (hours/minutes), seeded to the remembered route value or 2h. **Arrival is computed**
   (`departure + duration`) and shown read-only. The 2h default is only a seed — duration is always
   editable. Never persist `arrival <= departure` (duration must be > 0). On save,
   `CommuteRouteStore.setDuration(_, from:, to:)` remembers the per-route duration.

## Components

- **`PartnerSharingView.swift` (edit).** New `commutesSection` `@ViewBuilder` after `partnersSection`,
  inside the `beaconManager.isSharing` guard, gated `effectiveHomeAirportCode != base.rawValue`.
  `@Query(filter: #Predicate<Commute> { $0.deletedAt == nil })` sorted by `departureTimeZulu`.
  `@State suggestions: [CommuteSuggestion]`, `@State editingSheet: CommuteSheet.Mode?`. Recompute
  suggestions on appear / `.partnerDataDidChangeExternally`, filtering `CommuteSuggestionDismissalStore`.
  Rows: suggestion rows (Confirm/Dismiss or Convert/Dismiss), saved rows (tap → edit, swipe → soft-delete),
  Add row. Mirror existing patterns: `pendingInviteRow` (swipe + buttons), `partnersSection` (Section +
  empty state), `.sheet(item:)`, `statusRefreshTick` refresh idiom.
  - **Upcoming-only filter (presentation layer).** `CommuteSuggestionEngine` is time-agnostic by design
    (a pure, idempotent function of the local data) and emits a suggestion for *every* qualifying gap,
    including historical ones — so a pilot with a long trip history would otherwise see dozens of
    suggestions. "Now" lives in the view: `refreshCommuteSuggestions()` filters to drives that haven't
    finished (`arrivalTimeZulu >= Date()`). This keeps the engine pure (and its tests untouched) while the
    UI shows only upcoming/active commutes. Deleting a confirmed-from-suggestion commute also records its
    suggestion key in `CommuteSuggestionDismissalStore` so it isn't immediately re-suggested.

- **`CommuteSheet.swift` (new).** One view, `enum Mode { add, edit(Commute), confirm(CommuteSuggestion),
  convert(CommuteSuggestion) }` (Mode is `Identifiable` for `.sheet(item:)`). Consolidates the spec's
  `AddCommuteSheet`/`EditCommuteSheet` into one factored view. Mirrors `AddManualEventView` idioms
  (NavigationStack + ScrollView, Cancel in nav leading, prominent bottom Save button, UTC date/time
  pickers, success-overlay/dismiss). Decompose form into small subviews (direction / route / timing) to
  stay under ~300 lines.

- **`CommuteSheetModel` (new, `@Observable`).** Holds form state (direction, from, to, departure,
  durationSeconds), exposes `computedArrival`, `isValid` (`from != to && durationSeconds > 0`), and a
  `commit(into:)`/`makeOrUpdateCommute()` that creates/updates the `Commute`, sets sync metadata,
  remembers the route duration, and performs the convert retirement. View stays logic-free; this type is
  unit-testable without SwiftUI.

- **`CommuteSuggestionDismissalStore.swift` (new).** `enum`, static API over `SharedUserDefaults`:
  `isDismissed(_:) -> Bool`, `dismiss(_:)`, `prune(activeKeys:)` (cap unbounded growth). Key shape mirrors
  `CommuteRouteStore` (`commuteSuggestions.dismissed`).

## Tests (the USER runs these in Xcode — Cmd-U on the named classes)

- `DutyTests/CommuteSuggestionDismissalStoreTests` — round-trip persist, isDismissed, prune.
- `DutyTests/CommuteSheetModelTests` — validation gates; suggestion→Commute field mapping; arrival =
  departure + duration; convert path soft-deletes (retires) the source `ManualEvent`; degrade-to-fresh when
  the manual event is already gone.
- `DutyTests/CommuteCleanupIntegrationTests` (the deferred-from-3b item) — a confirmed suggestion's
  `(sourceTripId, direction)` round-trips with `CommuteCleanupService`'s "live" judgement: a commit-from-
  suggestion commute is NOT cleaned while its trip exists, and IS cleaned when the trip is soft-deleted/absent.

SwiftData test gotchas still apply (helper must retain the `ModelContainer`; call
`HiddenEventsManager.writeCache(deriveSet(from:))` after `save()` when asserting hidden state).

## Refinements from on-device testing (2026-06-23)

Surfaced when the user ran the build on their phone:

1. **Upcoming-only suggestions (presentation filter).** The engine is time-agnostic and emitted a
   suggestion for every historical gap (~50 on a real account). `refreshCommuteSuggestions()` filters to
   `arrivalTimeZulu >= Date()` (see the PartnerSharingView bullet above). Engine stays pure.
2. **"Drive to work" arrives before the flight, not at it (engine).** `CommuteSuggestionEngine.reportBuffer
   = 2h`; a `toWork` suggestion now arrives `gapEnd − reportBuffer` (and departs `arrival − duration`),
   so the pilot reaches base with prep/report margin. Editable per commute. (Decision: fixed 2h, the
   user's stated minimum, over the schedule's 60/90-min FAA pre-duty.)
3. **Drive home after the LAST trip (engine).** The pairwise gap loop never covered the final trip. An
   open-ended case after the loop suggests a `toHome` for the chronologically last trip whose
   `endingAirport == base` (`gapStart = last.endDate`, `gapEnd = .distantFuture`); the upcoming-only
   filter hides it if the drive already finished. The `trips.count >= 2` guard relaxed to `!trips.isEmpty`.
4. **Local + Zulu times (UI).** `CommuteSheet` shows Departs in the From airport's local zone and Arrives
   in the To airport's local zone (via `TripParser.getTimeZoneObjectForAirport`), each with a `HH:mmZ`
   Zulu reference; the list rows show `<from> → <to> · <local> · <Zulu>Z`. Still stored as Zulu.

## Working rules (unchanged, hard)

Never push/merge. Confirm EVERY commit live before running it. Never `git add` the user's WIP
(`PilotStatusBeaconManager.swift`, `SyncGuidanceCopy.swift`, `DutyTests/SyncGuidanceCopyTests.swift`).
Never commit `project.pbxproj`. The USER runs builds/tests in Xcode — implementer/reviewer subagents do
NOT run `xcodebuild`.

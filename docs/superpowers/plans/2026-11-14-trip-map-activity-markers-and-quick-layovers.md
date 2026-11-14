# Trip Map: What the Pilot Is Doing, and Quick Layovers (Crewluve) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The trip map's heart becomes a marker for what the pilot is doing (a layover, a turn, base or home). A replay hurries through each wait on the ground with a "Quick layovers" switch, the night sweeping by at up to 60 updates a second. The timeline becomes the app's own bar, colored by what the pilot is doing and measured in replay time.

**Architecture:**
- `TripMap` keeps CrewLu's ground legs as `GroundStop`s. `TripMap+Activity` finds the waits between moving legs (`TripWait`), names each by the ground leg that overlaps it most, and answers `activity(at:)`: a `TripActivity`, a kind and a place.
- `TripReplayClock` is given the waits and whether Quick layovers is on, and works out both paces up front. It switches pace keeping the moment, and places any moment along the timeline in replay time.
- `TripTimeline` turns the map and the clock into the bar's blocks. `TripTimelineBar` draws them in a `Canvas`, with a thumb and a drag, and is a `Slider` to VoiceOver (`accessibilityRepresentation`).
- `TripMapDrawing.pilot` replaces `pin`, and `TripMapMarker.pilot(kind)` replaces `.heart`.
- `TripMapScreen` keeps the switch in `@AppStorage("tripMapQuickLayovers")`. Its `TimelineView` runs on `.animation(minimumInterval:)`: 1/60 s while a replay plays, 1 s otherwise.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency in the app target (not in the test target), member import visibility, iOS 26, SwiftUI (`Canvas`, `TimelineView`, `accessibilityRepresentation`, `@AppStorage`), MapKit annotations hosting SwiftUI markers, XCTest.

**Sources:**
- The design, approved, the source of truth: `docs/superpowers/specs/2026-11-14-trip-map-activity-markers-and-quick-layovers-design.md`.
- The moving map spec, which this plan amends in §5.1, §6, §10, §14 and §15.1 (Task 10): `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`.
- The previous plan, whose code this builds on: `docs/superpowers/plans/2026-11-13-moving-map-own-night-drawing.md`.
- The website's half is built by its own session (`trip-map-web`), in its own repository and with its own plan. This plan doesn't touch it. It writes the two shared case files first (Task 2), so that session can start from them.

---

## Design

### What changes where

| Today | After |
|---|---|
| `TripMap.make` drops every leg that isn't a flight or a drive | It also keeps CrewLu's layover, turn, base and home legs as `groundStops: [GroundStop]`, at their scheduled times. They aren't drawn |
| `TripMap.pilotLocation(at:)` says where the pilot is on the ground | Unchanged. `TripMap.activity(at:)` (`TripMap+Activity.swift`) adds what they're doing: flying, driving, layover, turn, base or home, with the place |
| `TripMapDrawing.pin: AirportMark?` | `TripMapDrawing.pilot: TripActivity?`, nil while a leg moves |
| `TripMapMarker.heart`, named `heart` | `TripMapMarker.pilot(TripActivity.Kind)`, named `pilot` |
| `TripMapMarkers.Heart`: `heart.fill` on pink | `TripMapMarkers.Pilot(kind:)`: the kind's symbol on its color, in the heart's 24 pt circle, 11 pt bold symbol and 1.5 pt white ring |
| `TripReplayClock(span:legs:)`: short legs slow to 3 s, gaps play at a day in 48 s | `TripReplayClock(span:legs:waits:isQuickLayovers:)`, `setQuickLayovers(_:at:)`, `replayDuration`, `replayOffset(of:)`, `tripTime(atReplayOffset:)`, `progress(at:)` and `tripTime(atProgress:)` |
| A `Slider` over trip time, with "Fri 9:14 PM" under it | `TripTimelineBar` over replay time, with `TripTimeline`'s colored blocks, and "Fri 9:14 PM · Layover in Cologne" under it |
| The speeds alone | The "Quick layovers" switch beside the speeds, or above them when the two don't fit on one line |
| `TimelineView(.periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1))` on the screen and on the sheet | `TimelineView(.animation(minimumInterval: clock.isPlaying ? 1.0 / 60 : 1))` on both |

### What the pilot is doing (design §2.2)

`TripMap.activity(at:)`:
1. **A leg moving:** flying to its destination, or driving to it. Where a flight and a drive overlap, flying.
2. **Before the first departure:** home for a next trip. Otherwise the place is the first origin: home if it's the home airport, else base.
3. **From the last arrival on:** home for a recap. Otherwise the place is the last destination: home if it's the home airport, else base.
4. **In between, a wait:** the place is the earlier leg's destination (`pilotLocation(at:)`, unchanged, so the chips and the marker always agree), and the kind is the wait's.

`TripMap.waits` is every stretch of the span not covered by a moving leg. A leg with no length never moves. Each wait's kind is the kind of the ground stop that overlaps it most, the earlier on a tie. With none overlapping, it's a layover from 8 hours (`TripWait.shortestLayover`) and a turn below that. The marker, the bar and the line under it all read the same `waits`.

"The home airport" is `TripMap.home`. `TripMap(status:at:)` makes it from `homeAirportCode ?? baseAirportCode`, so for a pilot with no home set, base reads as home, as CrewLu's summary does.

### The pace (design §3.2)

The clock cuts the span at every leg's and wait's start and end. Each piece plays at a rate, in trip seconds per replay second at 1x:
- **Under a moving leg:** the slowest of 1,800 and each covering leg's length ÷ 3 s, as today.
- **In a wait, Quick layovers on:** `max(1,800, min(L ÷ 3, 86,400))`, where L is the whole wait's length. That's the design's `min(L ÷ 1,800, max(3, L ÷ 86,400))` replay seconds, turned into a rate. A wait cut in two by a leg with no length keeps its whole length's rate.
- **Otherwise:** 1,800.

Both paces are worked out when the clock is made. Switching keeps the trip moment and re-anchors a running replay, as `setSpeed` does. The speed multiplies everything.

The bar's positions are the clock's. `progress(at:)` is a moment's replay offset at 1x over the whole replay's, so the thumb crosses the bar at a steady pace at any one speed.

### The bar (design §4)

- **`TripTimeline(tripMap:clock:)`** cuts the span at every moving leg's start and end. Each piece is flying if a flight covers it, else driving if a drive does, else its wait's kind. Neighbors of the same kind merge. Each block's start and end are `clock.progress(at:)`. A wait's block carries its length label.
- **`TripTimelineTrack`** lays the timeline along the thumb's travel, inset by half the thumb at each end, as a slider does. The first and last blocks reach the bar's rounded ends.
- **`TripTimelineBlocks`** is a `Canvas`. The part ahead is drawn paler, as one layer at 35%, with labels in the primary text color. The part played, clipped at the thumb, is full color with white labels. A label is drawn only when its measured size fits inside its block, with 3 pt to spare each side, at the current text size. The bar is 24 pt tall at every text size.
- **`TripTimelineBar`** holds the blocks, a 28 pt white thumb, a drag that scrubs (`DragGesture(minimumDistance: 0)`), and a 44 pt touch height. To VoiceOver it's a `Slider` labelled "Trip time", whose value is "Saturday 1:40 PM, layover in Denver".

### Decisions the design left open

These are this plan's. Each is small to change, and the review (Task 11) and Todd's device check (Task 13) cover them.
1. **`GroundStop` holds a kind, a start and an end, and no airport.** The design puts the pilot at the earlier leg's destination, so a ground leg's own airport is never read. CrewLu often leaves it empty.
2. **A wait's label rounds to the nearest.** "20h" runs from 19 h 30 min to 20 h 29 min. From 48 rounded hours it's days to the nearest, so "2d" from 47 h 30 min. Halves round up. A wait that rounds to 0 hours gets no label. The website gets this rule through `waitLabels` in `replay-cases.json`. The design didn't list that array, but it keeps the two bars the same.
3. **The sheet updates 60 times a second during a replay too,** so its thumb moves as smoothly as the map under it. The design names only the map.
4. **The switch moves above the speeds** when the two don't fit on one line: at large text sizes, and probably in the 380 pt panel (`ViewThatFits`).
5. **A finished replay pauses at its end,** so the screen stops updating 60 times a second with nothing moving. Play still starts it over, and the button already showed Play.
6. **The clock is made with the remembered setting,** read in `init` from `UserDefaults.standard`, the store `@AppStorage` uses, since the property itself can't be read there yet. `onChange(of:initial: true)` keeps the clock in step with it after that. In previews, whose storage is their own, the first frame may use the default.
7. **Labels ahead of the thumb are in the primary text color, and played ones in white.** White on the paler blocks would fade into them.
8. **The kinds' symbols and colors are a SwiftUI extension in `Views/TripMap/`** (`TripActivity+Style.swift`), so `Services/` stays free of SwiftUI.
9. **The words are `TripActivity.words`.** The line under the timeline and its VoiceOver value are in `TripMapWording` (`timelineLine`, `timelineSpokenValue`), beside `timelineTime`.

### Spec amendments (applied in Task 10)

**Moving map spec, header.** After the paragraph that starts `**Amended 2026-11-13, our own night drawing:**`, add a blank line and:

```markdown
**Amended 2026-11-14, what the pilot is doing, and quick layovers:** §5.1, §6, §10, §14 and §15.1. From Todd's first look at the map on his iPad: the heart becomes a marker for what the pilot is doing, a replay hurries through each wait on the ground, and the timeline is colored by what the pilot is doing and measured in replay time. Design: `docs/superpowers/specs/2026-11-14-trip-map-activity-markers-and-quick-layovers-design.md`. Plan: `docs/superpowers/plans/2026-11-14-trip-map-activity-markers-and-quick-layovers.md`.
```

**§5.1.** Replace:

```markdown
- **On the ground, mid-trip (layover, turn, base):**
  - the whole trip is shown, with legs flown solid and legs still to come dashed;
  - a heart pin marks where the pilot is;
  - two chips: the city with its local time ("Cologne · 9:14 pm there"), and the next departure ("Next: Dubai, tomorrow 6:10 am").
- **Home, with a trip ahead:** the next trip's route, every leg dashed, with the heart pin at home ("Home · next trip Friday").
```

with:

```markdown
- **On the ground, mid-trip (layover, turn, base):**
  - the whole trip is shown, with legs flown solid and legs still to come dashed;
  - a marker shows where the pilot is and what they're doing there (amended 2026-11-14, activity markers design §2): a bed on a layover, an hourglass at a turn, a briefcase at base and a house at home, each a white symbol on its color (indigo, orange, teal, green) with a white ring. CrewLu's own ground legs name each wait; with none, 8 hours or more is a layover and less is a turn;
  - two chips: the city with its local time ("Cologne · 9:14 pm there"), and the next departure ("Next: Dubai, tomorrow 6:10 am").
- **Home, with a trip ahead:** the next trip's route, every leg dashed, with the home marker at home ("Home · next trip Friday").
```

**§6.** Replace:

```markdown
- **The timeline** covers the trip from its first departure to its last arrival.
  - Drag it to replay, with play at 1x, 2x, 5x or 10x as in CrewLu. At 1x a day passes in 48 s.
  - A leg in motion that would take less than 3 s at 1x slows so it takes 3 s; the speed setting multiplies that too. Between legs the replay keeps the normal rate, and where legs overlap the slowest wins (added 2026-11-13, as on the website: Crewluve Website `docs/superpowers/specs/2026-11-13-replay-short-legs-design.md`).
  - A Live button jumps back to now.
  - Replay moves the planes and the night. Live data affects only the present (§7.6).
```

with:

```markdown
- **The timeline** covers the trip from its first departure to its last arrival.
  - Drag it to replay, with play at 1x, 2x, 5x or 10x as in CrewLu. At 1x a day passes in 48 s.
  - A leg in motion that would take less than 3 s at 1x slows so it takes 3 s; the speed setting multiplies that too. Where legs overlap the slowest wins (added 2026-11-13, as on the website: Crewluve Website `docs/superpowers/specs/2026-11-13-replay-short-legs-design.md`).
  - **Quick layovers** (amended 2026-11-14, activity markers design §3): a switch beside the speeds, on by default and remembered for every trip. With it on, each wait on the ground takes a second a day, never under 3 s and never slower than the normal rate: a 15- to 27-hour layover takes 3 s, and a 4-day one 4 s. With it off, waits keep the normal rate. Switching it during a replay keeps the moment. Nothing is skipped: the night, the facts and the marker run through every minute of a wait.
  - **The bar** is the app's own (amended 2026-11-14, design §4). It measures replay time at 1x at the current pace, and is colored by what the pilot is doing: flying blue, driving gray, and each wait in its marker's color. The part played is full color and the part ahead paler. A wait's block shows its length, "20h" or "4d", when the label fits. The line under it says when and what: "Sat 1:40 PM · Layover in Denver".
  - A Live button jumps back to now.
  - Replay moves the planes and the night, up to 60 times a second (amended 2026-11-14). Live data affects only the present (§7.6).
```

**§10.** Replace:

```markdown
    - It sits just under the view MapKit keeps its annotation views in, so the planes, the heart, the cars and the airports stay bright at night.
```

with:

```markdown
    - It sits just under the view MapKit keeps its annotation views in, so the planes, the pilot's marker, the cars and the airports stay bright at night.
```

Then replace:

```markdown
  - **Markers:** the planes, the heart, the cars and the airports are MapKit annotations whose views host the app's SwiftUI markers. Each is hosted with no safe area, since SwiftUI otherwise moved a marker down by the status bar's height on the full-screen map.
```

with:

```markdown
  - **Markers:** the planes, the pilot's marker, the cars and the airports are MapKit annotations whose views host the app's SwiftUI markers. Each is hosted with no safe area, since SwiftUI otherwise moved a marker down by the status bar's height on the full-screen map.
```

Then replace:

```markdown
- **When the night is drawn:** for the map's exact time on every update. That's about 30 times a second during replay, every second on the full-screen map otherwise, and every 10 seconds on the card.
```

with:

```markdown
- **When the night is drawn:** for the map's exact time on every update. That's up to 60 times a second during replay (amended 2026-11-14, so the night sweeps smoothly through a quick layover), every second on the full-screen map otherwise, and every 10 seconds on the card.
- **What the pilot is doing** (amended 2026-11-14, activity markers design §6): `TripMap` keeps CrewLu's ground legs (`GroundStop`) and answers what the pilot is doing at any moment (`TripMap+Activity`, with `TripWait`, and `TripActivity` with its kinds' symbols, colors and words). `TripReplayClock` paces each wait with Quick layovers and gives the timeline's positions in replay time. `TripTimeline` is the bar's blocks, which `TripTimelineBar` draws, with `TripTimelineTrack` mapping the bar to the timeline.
```

**§14.** Replace:

```markdown
- **The timeline slider** reads its time as its value.
```

with:

```markdown
- **The timeline** reads as a slider (amended 2026-11-14, activity markers design §7). Its value is the moment and what the pilot is doing, "Saturday 1:40 PM, layover in Denver", and swiping up or down moves it. **Quick layovers** is a standard switch with its label. The bar's labels grow with the text size and drop out when they no longer fit; the bar's height stays the same.
```

Then replace:

```markdown
- **The map's markers:** on the full-screen map VoiceOver reads each airport's code, as it did before. The planes, the heart and the cars are described by the card's sentence and the facts rows. The night and the lines aren't read. On the card the map is hidden, and the card is its one sentence.
```

with:

```markdown
- **The map's markers:** on the full-screen map VoiceOver reads each airport's code, as it did before. The planes, the pilot's marker and the cars are described by the card's sentence and the facts rows. The night and the lines aren't read. On the card the map is hidden, and the card is its one sentence.
```

**§15.1.** Replace:

```markdown
- `facts-cases.json`: the geography lookup at given points, sunrise or sunset from the cockpit with the dip, milestones, comparisons and trip totals.
```

with:

```markdown
- `facts-cases.json`: the geography lookup at given points, sunrise or sunset from the cockpit with the dip, milestones, comparisons and trip totals.
- `replay-cases.json` (added 2026-11-14, activity markers design §5): the replay's pace through legs and waits with Quick layovers on and off, the trip moment at given replay seconds, each trip's whole replay length, and the lengths written on a wait's block.
- `activity-cases.json` (added 2026-11-14): sample trips with flights, drives and CrewLu's ground legs, and what the pilot is doing at given moments, with the words under the timeline.
```

---

## Ground rules for whoever runs this plan

These come from Todd's standing instructions. They override the skill's defaults.

1. **Don't run `xcodebuild` build or test loops,** and don't let subagents run them. Write the code and the tests. At each checkpoint Todd runs the named tests in Xcode, as below.
2. **Never commit without Todd's go-ahead in the conversation.** Each task ends with a suggested message. Ask, and commit only on a yes, and only the task's own files.
3. **After the last commit that changes what families see** (Task 13), draft the "Crewluve revisions" Apple Note entry in the "1.0.X Build YY" format, as the release-notes memory describes, and confirm the version and build with Todd.
4. **New files join their target on their own.** `Crewluv/` and `CrewluvTests/` are synchronized folders. Don't tick `CrewluveAlerts` on any new file: the helper doesn't use the map. The two JSON files are read from disk beside `TripMapFixtures.swift` (`#filePath`), as `progress-cases.json` is.
5. **Pure types are `nonisolated`,** and so are their nested types (`nonisolated struct`, `nonisolated enum`). An extension of a pure type, in its own file or in the same one, is written `nonisolated extension`. Otherwise its members default to the main actor and the tests can't call them.
6. **Member import visibility is on.** Each file imports the module behind every member it uses: `SwiftUI` for `Color`, `CoreGraphics` for `CGRect`'s and `CGFloat`'s members, `CoreLocation` for coordinates, `Foundation` for `Date`.
7. **Tests use XCTest,** with `@testable import Crewluv`, named `test_<methodOrBehavior>_<scenario>_<expectedResult>()`. Prefer `XCTAssertEqual` over `XCTAssertTrue`.
8. **The shared cases are the judge.** Every expected value in `replay-cases.json` and `activity-cases.json` is worked out in its `note`. If a case fails, the code is wrong. If you believe a case is wrong, STOP and tell Todd: the website keeps a copy, and both copies change together or not at all.
9. **Reviewers:** dispatch `superpowers:code-reviewer` with `model: "sonnet"`.
10. **The website's repository isn't this plan's.** Don't edit it.
11. **Work on `feature/trip-map-facts`.** The checkout is shared with other sessions (one committed while this plan was being written), so run `git status` before each commit and commit only this plan's files.

**Todd's test run.** Each checkpoint names the classes and how many tests each should have.
- **One class:** in Xcode, open the Test navigator (⌘6), find the class, and click the diamond beside its name. Paste me what it says.
- **Everything:**
  1. Choose an iPhone simulator beside **Crewluv** at the top of the window.
  2. Press **⌘U** and wait for the run to finish.
  3. Paste me the end of the test output.
- An open Xcode window can miss new test files. If a class is missing, close the project, open it again, and run once more.
- For any failure, read it and STOP. Never change a test's expected value, or a shared case, to make it pass.
- When a batch's tasks are carried out together, the batch's one run stands in for each task's.

## File map

| File | Status | Responsibility |
|---|---|---|
| `CrewluvTests/Fixtures/TripMap/replay-cases.json` | create | the replay's pace, its length and the waits' labels, shared with the website |
| `CrewluvTests/Fixtures/TripMap/activity-cases.json` | create | what the pilot is doing at given moments, shared with the website |
| `CrewluvTests/Helpers/TripMapFixtures.swift` | modify | reads the two new case files |
| `Crewluv/Services/TripMap/TripActivity.swift` | create | the kinds, the place, and the words under the timeline |
| `Crewluv/Views/TripMap/TripActivity+Style.swift` | create | each kind's symbol and color |
| `Crewluv/Services/TripMap/TripMapWording.swift` | modify | the line under the timeline, and its VoiceOver value |
| `CrewluvTests/TripActivityTests.swift` | create | 5 |
| `CrewluvTests/TripMapWordingTests.swift` | modify | 4 added |
| `Crewluv/Services/TripMap/GroundStop.swift` | create | one of CrewLu's ground legs |
| `Crewluv/Services/TripMap/TripWait.swift` | create | a stretch with no leg moving, and its kind |
| `Crewluv/Services/TripMap/TripMap.swift` | modify | keeps the ground stops |
| `Crewluv/Services/TripMap/TripMap+Activity.swift` | create | the waits, and what the pilot is doing at any moment |
| `CrewluvTests/Helpers/TripMap+HandMade.swift` | create | the facts tests' hand-made maps, with no ground stops |
| `CrewluvTests/TripMapActivityTests.swift` | create | 13 |
| `Crewluv/Services/TripMap/TripReplayClock.swift` | rewrite | Quick layovers' pace, and positions in replay time |
| `CrewluvTests/TripReplayClockPaceTests.swift` | create | 14 |
| `Crewluv/Services/TripMap/TripTimeline.swift` | create | the bar's blocks and the waits' labels |
| `Crewluv/Views/TripMap/TripTimelineTrack.swift` | create | where a point of the timeline sits across the bar, and back |
| `CrewluvTests/TripTimelineTests.swift` | create | 7 |
| `CrewluvTests/TripTimelineTrackTests.swift` | create | 4 |
| `Crewluv/Services/TripMap/TripMapDrawing.swift` | modify | `pilot` replaces `pin` |
| `Crewluv/Views/TripMap/TripMapMarker.swift` | rewrite | `.pilot(kind)` replaces `.heart` |
| `Crewluv/Views/TripMap/TripMapMarkers.swift` | modify | `Pilot` replaces `Heart` |
| `Crewluv/Views/TripMap/TripMapMarkerView.swift` | rewrite | shows `Pilot` |
| `Crewluv/Views/TripMap/TripMapAnnotationView.swift` | modify | the pilot's marker stands on its place, under the plane |
| `Crewluv/Views/TripMap/TripMapAnnotation.swift` | modify | its header's words |
| `Crewluv/Views/TripMap/TripMapCard.swift` | modify | its header's words |
| `CrewluvTests/TripMapMarkerTests.swift` | rewrite | 6 (it had 4) |
| `CrewluvTests/TripMapDrawingTests.swift` | modify | 6 (it had 5) |
| `CrewluvTests/TripMapStatusTests.swift` | modify | one message's words |
| `Crewluv/Views/TripMap/TripTimelineBlocks.swift` | create | the bar's colored blocks and their labels |
| `Crewluv/Views/TripMap/TripTimelineBar.swift` | create | the blocks, the thumb, the drag, and the slider VoiceOver reads |
| `Crewluv/Views/TripMap/TripTimelineControl.swift` | rewrite | the bar, the line under it, and the switch |
| `Crewluv/Views/TripMap/FactsHeader.swift` | rewrite | passes the blocks, the activity and the switch on |
| `Crewluv/Views/TripMap/FactsSheet.swift` | modify | the same, and 60 updates a second during a replay |
| `Crewluv/Views/TripMap/FactsPanel.swift` | rewrite | the same |
| `Crewluv/Views/TripMap/TripMapScreen.swift` | rewrite | the switch, the clock's waits, the blocks, 60 updates a second, a finished replay paused |
| `Crewluv/Views/TripMap/TripMapPreviews.swift` | rewrite | CrewLu's ground legs, a turn and base, and Quick layovers on and off |
| `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md` | modify | the header, §5.1, §6, §10, §14 and §15.1 |
| `CLAUDE.md` | modify | the Trip Map section |

`TripMapCoordinator`, `TripMapView`, `TripMapShapesView`, `PlaneMarker`, `TripMapPalette`, `TripMap+Status` and `TripReplayClockTests` don't change.

## Batches

- **A, the shared cases and the pure parts:** Tasks 2–6. Task 2 lands the two case files first, for the website. Review with `superpowers:code-reviewer` (sonnet), then Todd runs everything (⌘U).
- **B, the views:** Tasks 7–9. Task 7's markers build on their own; Tasks 8 and 9 build together. Todd builds, looks at the previews, and runs everything.
- **C, the docs and the close-out:** Task 10, then the review (Task 11), Todd's test run (Task 12), and Todd's device check with the close-out (Task 13, the last).

---

### Task 1: Before starting

**Files:** none.

- [ ] **Step 1: Check the branch and the tree.**

```bash
git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log -1 --format=%h && git -C /Users/toddanderson/Dev/Crewluv status --short
```

Expected: `feature/trip-map-facts`, then `6a2ecaf` or a later commit.
- Any other branch: STOP and ask Todd.
- A later commit is fine if Step 2's checks pass: another session shares this checkout.
- If `git status --short` lists any file this plan changes, other than this plan itself, someone is working on it. Ask Todd before going on. Leave every file that isn't this plan's alone, `.superpowers/` included.

- [ ] **Step 2: Check the files this plan rewrites are the versions it was written against.**

```bash
cd /Users/toddanderson/Dev/Crewluv && grep -c "case heart" Crewluv/Views/TripMap/TripMapMarker.swift && grep -c "periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1)" Crewluv/Views/TripMap/TripMapScreen.swift Crewluv/Views/TripMap/FactsSheet.swift && grep -c "replayLegs(of: tripMap)" Crewluv/Views/TripMap/TripMapScreen.swift && grep -cF 'TripTimelineControl(clock: $clock, time: time, now: now)' Crewluv/Views/TripMap/FactsPanel.swift Crewluv/Views/TripMap/FactsHeader.swift
```

Expected: `1`; `TripMapScreen.swift:1` and `FactsSheet.swift:1`; `2`; `FactsPanel.swift:1` and `FactsHeader.swift:1`.
- Anything else means the files have moved on. STOP: the whole-file versions below would undo someone's work.

- [ ] **Step 3: Check the case files aren't there yet.**

```bash
ls /Users/toddanderson/Dev/Crewluv/CrewluvTests/Fixtures/TripMap/
```

Expected: `facts-cases.json` and `progress-cases.json` only. If `replay-cases.json` or `activity-cases.json` is there, the website's session may have written one first. STOP and ask Todd which copy wins.

---

### Task 2: The shared case files

The website starts from these, so they come first and are committed on their own. Every expected number is worked out in its `note`. A Python model of the rules reproduced every one of them while this plan was written.

**Files:**
- Create: `CrewluvTests/Fixtures/TripMap/replay-cases.json`
- Create: `CrewluvTests/Fixtures/TripMap/activity-cases.json`
- Modify: `CrewluvTests/Helpers/TripMapFixtures.swift`

- [ ] **Step 1: Write the replay cases.** Create `CrewluvTests/Fixtures/TripMap/replay-cases.json`:

```json
{
  "about": "The trip map replay's pace (Crewluve activity markers design §3.2, §4.1): a day in 48 s at 1x; a leg in motion that would take under 3 s slows to 3 s, and where legs overlap the slowest wins; with Quick layovers on, a wait of L seconds plays in min(L / 1,800, max(3, L / 86,400)) seconds, a second a day, never under 3 s and never slower than a day in 48 s; with it off, a day in 48 s. The speed multiplies everything. Each case plays from the span's start at its speed, and each check is the trip time `seconds` real seconds after pressing play. replayLength is the whole replay at 1x. waitLabels are the lengths the timeline writes on a wait's block: whole hours to the nearest under 48 h, whole days to the nearest from 48 h, none when it rounds to 0 h (halves round up). The app's TripReplayClockPaceTests and TripTimelineTests and the website's tests run every case. Change both copies together.",
  "constants": { "baseRate": 1800, "legMinimumSeconds": 3, "waitMinimumSeconds": 3, "quickWaitRate": 86400 },
  "cases": [
    {
      "name": "Louisville, a day in Cologne, Dubai, 20 hours there, and home; Quick layovers on",
      "note": "Legs at a day in 48 s (1,800 trip s a replay s): 8 h = 28,800 s / 1,800 = 16 s, 6 h = 12 s, 14 h = 28 s. Waits: 24 h takes min(86,400 / 1,800 = 48 s, max(3 s, 1 s a day x 1 day = 1 s)) = 3 s, so 28,800 trip s a replay s; 20 h takes min(40 s, max(3 s, 0.83 s)) = 3 s, so 24,000 trip s a replay s. Whole: 16 + 3 + 12 + 3 + 28 = 62 s. At 8 s: 8 x 1,800 = 4 h. At 17.5 s: 8 h + 1.5 x 28,800 s (12 h) = 20 h. At 19 s: 32 h. At 31 s: 32 h + 12 s x 1,800 = 38 h. At 32.5 s: 38 h + 1.5 x 24,000 s (10 h) = 48 h. At 62 s and after: the end, 72 h.",
      "span": { "start": "2026-11-13T12:00:00Z", "end": "2026-11-16T12:00:00Z" },
      "legs": [{ "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T20:00:00Z" }, { "start": "2026-11-14T20:00:00Z", "end": "2026-11-15T02:00:00Z" }, { "start": "2026-11-15T22:00:00Z", "end": "2026-11-16T12:00:00Z" }],
      "waits": [{ "start": "2026-11-13T20:00:00Z", "end": "2026-11-14T20:00:00Z" }, { "start": "2026-11-15T02:00:00Z", "end": "2026-11-15T22:00:00Z" }],
      "quickLayovers": true, "speed": 1, "replayLength": 62,
      "checks": [
        { "seconds": 0, "at": "2026-11-13T12:00:00Z" },
        { "seconds": 8, "at": "2026-11-13T16:00:00Z" },
        { "seconds": 16, "at": "2026-11-13T20:00:00Z" },
        { "seconds": 17.5, "at": "2026-11-14T08:00:00Z" },
        { "seconds": 19, "at": "2026-11-14T20:00:00Z" },
        { "seconds": 31, "at": "2026-11-15T02:00:00Z" },
        { "seconds": 32.5, "at": "2026-11-15T12:00:00Z" },
        { "seconds": 62, "at": "2026-11-16T12:00:00Z" },
        { "seconds": 70, "at": "2026-11-16T12:00:00Z" }
      ]
    },
    {
      "name": "The same trip with Quick layovers off",
      "note": "Everything at a day in 48 s: 72 h = 259,200 s / 1,800 = 144 s. Legs 16 s, 12 s, 28 s; waits 24 h = 48 s and 20 h = 40 s. At 17.5 s: 8 h + 1.5 x 1,800 s (45 min) = 8 h 45 min. At 64 s: 16 + 48 = 32 h. At 76 s: 38 h. At 116 s: 76 + 40 = 58 h. At 144 s: 72 h.",
      "span": { "start": "2026-11-13T12:00:00Z", "end": "2026-11-16T12:00:00Z" },
      "legs": [{ "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T20:00:00Z" }, { "start": "2026-11-14T20:00:00Z", "end": "2026-11-15T02:00:00Z" }, { "start": "2026-11-15T22:00:00Z", "end": "2026-11-16T12:00:00Z" }],
      "waits": [{ "start": "2026-11-13T20:00:00Z", "end": "2026-11-14T20:00:00Z" }, { "start": "2026-11-15T02:00:00Z", "end": "2026-11-15T22:00:00Z" }],
      "quickLayovers": false, "speed": 1, "replayLength": 144,
      "checks": [
        { "seconds": 16, "at": "2026-11-13T20:00:00Z" },
        { "seconds": 17.5, "at": "2026-11-13T20:45:00Z" },
        { "seconds": 64, "at": "2026-11-14T20:00:00Z" },
        { "seconds": 76, "at": "2026-11-15T02:00:00Z" },
        { "seconds": 116, "at": "2026-11-15T22:00:00Z" },
        { "seconds": 144, "at": "2026-11-16T12:00:00Z" }
      ]
    },
    {
      "name": "The same trip with Quick layovers on, at 10x",
      "note": "The speed multiplies everything: each real second is 10 replay seconds at 1x (62 s in all, from the first case). At 1.6 s: 16 s, 8 h. At 1.75 s: 17.5 s, 20 h. At 1.9 s: 19 s, 32 h. At 6.2 s: 62 s, the end.",
      "span": { "start": "2026-11-13T12:00:00Z", "end": "2026-11-16T12:00:00Z" },
      "legs": [{ "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T20:00:00Z" }, { "start": "2026-11-14T20:00:00Z", "end": "2026-11-15T02:00:00Z" }, { "start": "2026-11-15T22:00:00Z", "end": "2026-11-16T12:00:00Z" }],
      "waits": [{ "start": "2026-11-13T20:00:00Z", "end": "2026-11-14T20:00:00Z" }, { "start": "2026-11-15T02:00:00Z", "end": "2026-11-15T22:00:00Z" }],
      "quickLayovers": true, "speed": 10, "replayLength": 62,
      "checks": [
        { "seconds": 1.6, "at": "2026-11-13T20:00:00Z" },
        { "seconds": 1.75, "at": "2026-11-14T08:00:00Z" },
        { "seconds": 1.9, "at": "2026-11-14T20:00:00Z" },
        { "seconds": 6.2, "at": "2026-11-16T12:00:00Z" }
      ]
    },
    {
      "name": "A four-day layover takes 4 s with Quick layovers on",
      "note": "Legs: 2 h = 7,200 s / 1,800 = 4 s each. The wait: 96 h = 345,600 s takes min(345,600 / 1,800 = 192 s, max(3 s, 1 s a day x 4 days = 4 s)) = 4 s, so 86,400 trip s a replay s, a day a second. Whole: 4 + 4 + 4 = 12 s. At 5 s: 2 h + 1 day = 26 h. At 6 s: 50 h. At 8 s: 98 h. At 12 s: 100 h.",
      "span": { "start": "2026-11-13T12:00:00Z", "end": "2026-11-17T16:00:00Z" },
      "legs": [{ "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T14:00:00Z" }, { "start": "2026-11-17T14:00:00Z", "end": "2026-11-17T16:00:00Z" }],
      "waits": [{ "start": "2026-11-13T14:00:00Z", "end": "2026-11-17T14:00:00Z" }],
      "quickLayovers": true, "speed": 1, "replayLength": 12,
      "checks": [
        { "seconds": 4, "at": "2026-11-13T14:00:00Z" },
        { "seconds": 5, "at": "2026-11-14T14:00:00Z" },
        { "seconds": 6, "at": "2026-11-15T14:00:00Z" },
        { "seconds": 8, "at": "2026-11-17T14:00:00Z" },
        { "seconds": 12, "at": "2026-11-17T16:00:00Z" }
      ]
    },
    {
      "name": "The four-day layover with Quick layovers off takes 3 min 12 s",
      "note": "Everything at a day in 48 s: the wait is 345,600 / 1,800 = 192 s (3 min 12 s); the legs 4 s each. Whole: 200 s. At 100 s: 2 h + 96 s x 1,800 = 2 h + 48 h = 50 h. At 196 s: 98 h. At 200 s: 100 h.",
      "span": { "start": "2026-11-13T12:00:00Z", "end": "2026-11-17T16:00:00Z" },
      "legs": [{ "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T14:00:00Z" }, { "start": "2026-11-17T14:00:00Z", "end": "2026-11-17T16:00:00Z" }],
      "waits": [{ "start": "2026-11-13T14:00:00Z", "end": "2026-11-17T14:00:00Z" }],
      "quickLayovers": false, "speed": 1, "replayLength": 200,
      "checks": [
        { "seconds": 4, "at": "2026-11-13T14:00:00Z" },
        { "seconds": 100, "at": "2026-11-15T14:00:00Z" },
        { "seconds": 196, "at": "2026-11-17T14:00:00Z" },
        { "seconds": 200, "at": "2026-11-17T16:00:00Z" }
      ]
    },
    {
      "name": "A 1-hour turn keeps its 2 s; a 2-hour wait takes 3 s",
      "note": "Legs: 2 h = 4 s each. The 1-hour turn: min(3,600 / 1,800 = 2 s, max(3 s, 0.04 s)) = 2 s, the normal rate, never slower. The 2-hour wait: min(4 s, max(3 s, 0.08 s)) = 3 s, so 7,200 / 3 = 2,400 trip s a replay s. Whole: 4 + 2 + 4 + 3 + 4 = 17 s. At 5 s: 2 h + 1 s x 1,800 = 2 h 30 min. At 6 s: 3 h. At 10 s: 5 h. At 11.5 s: 5 h + 1.5 x 2,400 s (1 h) = 6 h. At 13 s: 7 h. At 17 s: 9 h.",
      "span": { "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T21:00:00Z" },
      "legs": [{ "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T14:00:00Z" }, { "start": "2026-11-13T15:00:00Z", "end": "2026-11-13T17:00:00Z" }, { "start": "2026-11-13T19:00:00Z", "end": "2026-11-13T21:00:00Z" }],
      "waits": [{ "start": "2026-11-13T14:00:00Z", "end": "2026-11-13T15:00:00Z" }, { "start": "2026-11-13T17:00:00Z", "end": "2026-11-13T19:00:00Z" }],
      "quickLayovers": true, "speed": 1, "replayLength": 17,
      "checks": [
        { "seconds": 5, "at": "2026-11-13T14:30:00Z" },
        { "seconds": 6, "at": "2026-11-13T15:00:00Z" },
        { "seconds": 10, "at": "2026-11-13T17:00:00Z" },
        { "seconds": 11.5, "at": "2026-11-13T18:00:00Z" },
        { "seconds": 13, "at": "2026-11-13T19:00:00Z" },
        { "seconds": 17, "at": "2026-11-13T21:00:00Z" }
      ]
    },
    {
      "name": "Short legs still take 3 s, and waits under 90 minutes keep their pace with Quick layovers on",
      "note": "A 25-min drive (1,500 s / 1,800 = 0.83 s) slows to 3 s, 500 trip s a replay s. The 30-min wait: min(1 s, max(3 s, 0.02 s)) = 1 s. A 50-min hop (1.67 s) slows to 3 s, 1,000 trip s a replay s. The 1-hour wait: 2 s. The 8-hour flight: 16 s. Whole: 3 + 1 + 3 + 2 + 16 = 25 s, as with Quick layovers off. At 1.5 s: 1.5 x 500 s = 12 min 30 s. At 3 s: 25 min. At 4 s: 55 min. At 7 s: 1 h 45 min. At 9 s: 2 h 45 min. At 25 s: 10 h 45 min.",
      "span": { "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T22:45:00Z" },
      "legs": [{ "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T12:25:00Z" }, { "start": "2026-11-13T12:55:00Z", "end": "2026-11-13T13:45:00Z" }, { "start": "2026-11-13T14:45:00Z", "end": "2026-11-13T22:45:00Z" }],
      "waits": [{ "start": "2026-11-13T12:25:00Z", "end": "2026-11-13T12:55:00Z" }, { "start": "2026-11-13T13:45:00Z", "end": "2026-11-13T14:45:00Z" }],
      "quickLayovers": true, "speed": 1, "replayLength": 25,
      "checks": [
        { "seconds": 1.5, "at": "2026-11-13T12:12:30Z" },
        { "seconds": 3, "at": "2026-11-13T12:25:00Z" },
        { "seconds": 4, "at": "2026-11-13T12:55:00Z" },
        { "seconds": 7, "at": "2026-11-13T13:45:00Z" },
        { "seconds": 9, "at": "2026-11-13T14:45:00Z" },
        { "seconds": 25, "at": "2026-11-13T22:45:00Z" }
      ]
    },
    {
      "name": "A drive to base, a night there, then the flight; Quick layovers on",
      "note": "The 90-min drive: 5,400 / 1,800 = 3 s, already 3 s. The 12 h 30 min at base: min(45,000 / 1,800 = 25 s, max(3 s, 0.52 s)) = 3 s, so 15,000 trip s a replay s. The 8-hour flight: 16 s. Whole: 3 + 3 + 16 = 22 s. At 4.5 s: 1 h 30 min + 1.5 x 15,000 s (6 h 15 min) = 7 h 45 min. At 6 s: 14 h. At 22 s: 22 h.",
      "span": { "start": "2026-11-13T12:00:00Z", "end": "2026-11-14T10:00:00Z" },
      "legs": [{ "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T13:30:00Z" }, { "start": "2026-11-14T02:00:00Z", "end": "2026-11-14T10:00:00Z" }],
      "waits": [{ "start": "2026-11-13T13:30:00Z", "end": "2026-11-14T02:00:00Z" }],
      "quickLayovers": true, "speed": 1, "replayLength": 22,
      "checks": [
        { "seconds": 3, "at": "2026-11-13T13:30:00Z" },
        { "seconds": 4.5, "at": "2026-11-13T19:45:00Z" },
        { "seconds": 6, "at": "2026-11-14T02:00:00Z" },
        { "seconds": 22, "at": "2026-11-14T10:00:00Z" }
      ]
    }
  ],
  "waitLabels": [
    { "hours": 0.4, "label": null, "note": "24 min rounds to 0 h: no label" },
    { "hours": 0.5, "label": "1h", "note": "30 min rounds up to 1 h" },
    { "hours": 1, "label": "1h", "note": "whole hours" },
    { "hours": 20, "label": "20h", "note": "whole hours" },
    { "hours": 20.5, "label": "21h", "note": "20 h 30 min rounds up to 21 h" },
    { "hours": 24, "label": "24h", "note": "a day is still hours" },
    { "hours": 47.4, "label": "47h", "note": "rounds to 47 h" },
    { "hours": 47.5, "label": "2d", "note": "rounds to 48 h, so days: 1.98 d rounds to 2 d" },
    { "hours": 48, "label": "2d", "note": "2 days" },
    { "hours": 96, "label": "4d", "note": "4 days" },
    { "hours": 108, "label": "5d", "note": "4.5 days rounds up to 5 d" }
  ]
}
```

- [ ] **Step 2: Write the activity cases.** Create `CrewluvTests/Fixtures/TripMap/activity-cases.json`:

```json
{
  "about": "What the pilot is doing at a moment of the trip map (Crewluve activity markers design §2.2, §4.2): the marker's kind (flying and driving show the plane and the car; layover, turn, base and home are the ground markers) and the words under the timeline. Legs are as CrewLu sends them: flights and drives, which delayMinutes moves, and ground legs (layover, turn, base, home) at their scheduled times, which nothing moves. A wait is any stretch from one moving leg's end to the next one's start; the ground leg overlapping it most names it, the earlier on a tie, and with none it's a layover from 8 h and a turn under. Before the first departure: home for a nextTrip, else home or base by whether the first origin is the home airport. After the last arrival: home for a recap, else home or base by whether the last destination is. A place is its city, else its code. mode is trip, nextTrip or recap. Times are UTC. The app's TripMapActivityTests and the website's tests run every case. Change both copies together.",
  "constants": { "shortestLayoverHours": 8 },
  "airports": {
    "SDF": { "lat": 38.1746, "lon": -85.7382, "city": "Louisville" },
    "LEX": { "lat": 38.0365, "lon": -84.6059, "city": "Lexington" },
    "DEN": { "lat": 39.8561, "lon": -104.6737, "city": "Denver" },
    "SFO": { "lat": 37.6213, "lon": -122.379, "city": "San Francisco" },
    "ORD": { "lat": 41.9742, "lon": -87.9073, "city": "Chicago" },
    "COS": { "lat": 38.8058, "lon": -104.7008, "city": null }
  },
  "trips": [
    {
      "name": "Louisville to Denver and San Francisco, and home",
      "note": "Waits: Denver 15:00 to 11:00 the next day (20 h), named by CrewLu's layover l1, which covers all 20 h; San Francisco 13:30 to 14:30 (1 h), named by the turn t1. The trip starts and ends at home, Louisville.",
      "home": "SDF", "mode": "trip",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-14T11:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "SFO", "start": "2026-11-14T11:00:00Z", "end": "2026-11-14T13:30:00Z" },
        { "id": "t1", "type": "turn", "airport": "SFO", "start": "2026-11-14T13:30:00Z", "end": "2026-11-14T14:30:00Z" },
        { "id": "f3", "type": "flight", "from": "SFO", "to": "SDF", "start": "2026-11-14T14:30:00Z", "end": "2026-11-14T19:00:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T10:00:00Z", "kind": "home", "words": "Home", "note": "before the first departure, at its origin, SDF, the home airport: home" },
        { "at": "2026-11-13T13:00:00Z", "kind": "flying", "words": "Flying to Denver", "note": "f1 is between its gates" },
        { "at": "2026-11-13T15:00:00Z", "kind": "layover", "words": "Layover in Denver", "note": "f1 reached the gate at 15:00: the wait starts" },
        { "at": "2026-11-13T22:00:00Z", "kind": "layover", "words": "Layover in Denver", "note": "in the 20-hour wait, which CrewLu's layover overlaps for all 20 h" },
        { "at": "2026-11-14T12:00:00Z", "kind": "flying", "words": "Flying to San Francisco", "note": "f2 is between its gates" },
        { "at": "2026-11-14T14:00:00Z", "kind": "turn", "words": "Turn in San Francisco", "note": "in the 1-hour wait, which CrewLu's turn overlaps for all of it" },
        { "at": "2026-11-14T19:00:00Z", "kind": "home", "words": "Home", "note": "f3 reached the gate: after the last arrival, at SDF, the home airport: home" },
        { "at": "2026-11-15T04:00:00Z", "kind": "home", "words": "Home", "note": "after the last arrival, still home" }
      ]
    },
    {
      "name": "No ground legs: the wait's length decides",
      "note": "No ground legs. Waits: Denver 15:00 to 23:00 (8 h: 8 h or more is a layover), San Francisco 01:30 to 02:00 (30 min: a turn), Denver 04:30 to 12:24 (7 h 54 min: under 8 h, a turn).",
      "home": "SDF", "mode": "trip",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "SFO", "start": "2026-11-13T23:00:00Z", "end": "2026-11-14T01:30:00Z" },
        { "id": "f3", "type": "flight", "from": "SFO", "to": "DEN", "start": "2026-11-14T02:00:00Z", "end": "2026-11-14T04:30:00Z" },
        { "id": "f4", "type": "flight", "from": "DEN", "to": "SDF", "start": "2026-11-14T12:24:00Z", "end": "2026-11-14T15:00:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T17:00:00Z", "kind": "layover", "words": "Layover in Denver", "note": "in the 8-hour wait in Denver: exactly 8 h is a layover" },
        { "at": "2026-11-14T01:45:00Z", "kind": "turn", "words": "Turn in San Francisco", "note": "in the 30-minute wait in San Francisco: a turn" },
        { "at": "2026-11-14T08:00:00Z", "kind": "turn", "words": "Turn in Denver", "note": "in the 7 h 54 min wait in Denver: under 8 h, a turn" },
        { "at": "2026-11-14T16:00:00Z", "kind": "home", "words": "Home", "note": "after the last arrival, at SDF, the home airport: home" }
      ]
    },
    {
      "name": "A delay moves the flights, not CrewLu's ground legs",
      "note": "f2 leaves 90 min late: 17:30 to 20:00 instead of 16:00 to 18:30. CrewLu's turn (15:00 to 16:00) and layover (from 18:30) keep their scheduled times. The Denver wait, 15:00 to 17:30, overlaps the turn for 1 h and the layover not at all: a turn. The San Francisco wait, 20:00 to 10:00, overlaps the layover for 14 h: a layover.",
      "home": "SDF", "mode": "trip",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "t1", "type": "turn", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-13T16:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "SFO", "start": "2026-11-13T16:00:00Z", "end": "2026-11-13T18:30:00Z", "delayMinutes": 90 },
        { "id": "l1", "type": "layover", "airport": "SFO", "start": "2026-11-13T18:30:00Z", "end": "2026-11-14T10:00:00Z" },
        { "id": "f3", "type": "flight", "from": "SFO", "to": "SDF", "start": "2026-11-14T10:00:00Z", "end": "2026-11-14T14:30:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T15:30:00Z", "kind": "turn", "words": "Turn in Denver", "note": "in the Denver wait, during CrewLu's turn" },
        { "at": "2026-11-13T16:30:00Z", "kind": "turn", "words": "Turn in Denver", "note": "still waiting in Denver after CrewLu's turn has ended: the whole wait is a turn" },
        { "at": "2026-11-13T18:00:00Z", "kind": "flying", "words": "Flying to San Francisco", "note": "f2 is in the air, 90 minutes late" },
        { "at": "2026-11-13T19:30:00Z", "kind": "flying", "words": "Flying to San Francisco", "note": "f2 is still in the air, though CrewLu's layover began at 18:30" },
        { "at": "2026-11-13T22:00:00Z", "kind": "layover", "words": "Layover in San Francisco", "note": "in the San Francisco wait, which CrewLu's layover overlaps for 14 h" }
      ]
    },
    {
      "name": "Two ground legs share a wait equally: the earlier names it",
      "note": "One wait in Denver, 15:00 to 23:00 (8 h). CrewLu's turn covers 15:00 to 19:00 and its layover 19:00 to 23:00: 4 h each, a tie, so the earlier, the turn, names the whole wait.",
      "home": "SDF", "mode": "trip",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "t1", "type": "turn", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-13T19:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "DEN", "start": "2026-11-13T19:00:00Z", "end": "2026-11-13T23:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "SDF", "start": "2026-11-13T23:00:00Z", "end": "2026-11-14T01:30:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T17:00:00Z", "kind": "turn", "words": "Turn in Denver", "note": "during CrewLu's turn" },
        { "at": "2026-11-13T21:00:00Z", "kind": "turn", "words": "Turn in Denver", "note": "during CrewLu's layover, but the wait is one, and the turn names it" }
      ]
    },
    {
      "name": "A next trip shows home until it starts",
      "note": "A trip still ahead. Before its first departure the pilot is home. Replayed, it's as any trip.",
      "home": "SDF", "mode": "nextTrip",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-14T11:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "SDF", "start": "2026-11-14T11:00:00Z", "end": "2026-11-14T14:00:00Z" }
      ],
      "moments": [
        { "at": "2026-11-12T12:00:00Z", "kind": "home", "words": "Home", "note": "a day before the next trip: home" },
        { "at": "2026-11-13T22:00:00Z", "kind": "layover", "words": "Layover in Denver", "note": "replaying it: the 20-hour wait in Denver, named by CrewLu's layover" },
        { "at": "2026-11-14T15:00:00Z", "kind": "home", "words": "Home", "note": "after the last arrival, at SDF, the home airport: home" }
      ]
    },
    {
      "name": "A commuter: home, the drive to base, the trip, and the drive home",
      "note": "Home is Lexington (LEX); base is Louisville (SDF). Waits: SDF 10:30 to 12:00 (1 h 30, CrewLu's base stay b1), Denver 15:00 to 11:00 (20 h, layover l1), SDF 14:00 to 15:00 (1 h, base stay b2). The trip runs from the drive's start, 09:00, to the drive home's end, 16:30 the next day.",
      "home": "LEX", "mode": "trip",
      "legs": [
        { "id": "d1", "type": "drive", "from": "LEX", "to": "SDF", "start": "2026-11-13T09:00:00Z", "end": "2026-11-13T10:30:00Z" },
        { "id": "b1", "type": "base", "airport": "SDF", "start": "2026-11-13T10:30:00Z", "end": "2026-11-13T12:00:00Z" },
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-14T11:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "SDF", "start": "2026-11-14T11:00:00Z", "end": "2026-11-14T14:00:00Z" },
        { "id": "b2", "type": "base", "airport": "SDF", "start": "2026-11-14T14:00:00Z", "end": "2026-11-14T15:00:00Z" },
        { "id": "d2", "type": "drive", "from": "SDF", "to": "LEX", "start": "2026-11-14T15:00:00Z", "end": "2026-11-14T16:30:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T08:00:00Z", "kind": "home", "words": "Home", "note": "before the first departure, the drive, at its origin, LEX, the home airport: home" },
        { "at": "2026-11-13T10:00:00Z", "kind": "driving", "words": "Driving to Louisville", "note": "d1 is on the road" },
        { "at": "2026-11-13T11:00:00Z", "kind": "base", "words": "At base in Louisville", "note": "in the wait at Louisville, which CrewLu's base stay covers" },
        { "at": "2026-11-13T22:00:00Z", "kind": "layover", "words": "Layover in Denver", "note": "in the 20-hour wait in Denver" },
        { "at": "2026-11-14T14:30:00Z", "kind": "base", "words": "At base in Louisville", "note": "back at Louisville, in CrewLu's base stay" },
        { "at": "2026-11-14T16:00:00Z", "kind": "driving", "words": "Driving to Lexington", "note": "d2 is on the road home" },
        { "at": "2026-11-14T17:00:00Z", "kind": "home", "words": "Home", "note": "after the last arrival, at LEX, the home airport: home" }
      ]
    },
    {
      "name": "A trip from base, with no drive",
      "note": "Home is Lexington (LEX); the trip starts and ends at Louisville (SDF), so before and after it the pilot is at base.",
      "home": "LEX", "mode": "trip",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-14T11:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "SDF", "start": "2026-11-14T11:00:00Z", "end": "2026-11-14T14:00:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T10:00:00Z", "kind": "base", "words": "At base in Louisville", "note": "before the first departure, at its origin, SDF, not the home airport: base" },
        { "at": "2026-11-14T18:00:00Z", "kind": "base", "words": "At base in Louisville", "note": "after the last arrival, at SDF, not the home airport: base" }
      ]
    },
    {
      "name": "A recap shows home after the trip, wherever it ended",
      "note": "The trip ended in Chicago (ORD), but a recap is shown once the pilot is home, so after the last arrival the pilot is home.",
      "home": "SDF", "mode": "recap",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "DEN", "start": "2026-11-13T15:00:00Z", "end": "2026-11-14T11:00:00Z" },
        { "id": "f2", "type": "flight", "from": "DEN", "to": "ORD", "start": "2026-11-14T11:00:00Z", "end": "2026-11-14T13:30:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T22:00:00Z", "kind": "layover", "words": "Layover in Denver", "note": "replaying it: the 20-hour wait in Denver" },
        { "at": "2026-11-14T18:00:00Z", "kind": "home", "words": "Home", "note": "after the last arrival of a recap: home" }
      ]
    },
    {
      "name": "An airport with no city is named by its code",
      "note": "COS has no city in the airports above, so the words use its code.",
      "home": "SDF", "mode": "trip",
      "legs": [
        { "id": "f1", "type": "flight", "from": "SDF", "to": "COS", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T15:00:00Z" },
        { "id": "l1", "type": "layover", "airport": "COS", "start": "2026-11-13T15:00:00Z", "end": "2026-11-14T08:00:00Z" },
        { "id": "f2", "type": "flight", "from": "COS", "to": "SDF", "start": "2026-11-14T08:00:00Z", "end": "2026-11-14T11:00:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T22:00:00Z", "kind": "layover", "words": "Layover in COS", "note": "in the 17-hour wait at COS, named by CrewLu's layover" }
      ]
    },
    {
      "name": "A drive that runs into a flight: flying wins",
      "note": "The drive to Louisville runs 12:00 to 13:30 and the flight leaves at 13:00, so from 13:00 to 13:30 both move.",
      "home": "LEX", "mode": "trip",
      "legs": [
        { "id": "d1", "type": "drive", "from": "LEX", "to": "SDF", "start": "2026-11-13T12:00:00Z", "end": "2026-11-13T13:30:00Z" },
        { "id": "f1", "type": "flight", "from": "SDF", "to": "DEN", "start": "2026-11-13T13:00:00Z", "end": "2026-11-13T16:00:00Z" }
      ],
      "moments": [
        { "at": "2026-11-13T12:30:00Z", "kind": "driving", "words": "Driving to Louisville", "note": "only the drive moves" },
        { "at": "2026-11-13T13:15:00Z", "kind": "flying", "words": "Flying to Denver", "note": "the drive and the flight both move: flying wins" },
        { "at": "2026-11-13T14:00:00Z", "kind": "flying", "words": "Flying to Denver", "note": "only the flight moves" }
      ]
    }
  ]
}
```

- [ ] **Step 3: Check both are valid JSON.**

```bash
cd /Users/toddanderson/Dev/Crewluv && python3 -c 'import json, sys; [json.load(open(p)) for p in sys.argv[1:]]; print("valid")' CrewluvTests/Fixtures/TripMap/replay-cases.json CrewluvTests/Fixtures/TripMap/activity-cases.json
```

Expected: `valid`.

- [ ] **Step 4: Read them in the tests.** In `CrewluvTests/Helpers/TripMapFixtures.swift`, replace:

```swift
    static func factsCases() throws -> FactsCases {
        let data = try Data(contentsOf: folder.appending(path: "facts-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FactsCases.self, from: data)
    }
}
```

with:

```swift
    static func factsCases() throws -> FactsCases {
        let data = try Data(contentsOf: folder.appending(path: "facts-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FactsCases.self, from: data)
    }

    // MARK: - The replay's pace (activity markers design §3.2, §4.1, §5)

    struct ReplayCases: Decodable {
        struct Constants: Decodable {
            let baseRate: Double
            let legMinimumSeconds: Double
            let waitMinimumSeconds: Double
            let quickWaitRate: Double
        }

        struct Stretch: Decodable {
            let start: Date
            let end: Date

            var clockStretch: TripReplayClock.Stretch { TripReplayClock.Stretch(start: start, end: end) }
        }

        struct Check: Decodable {
            /// Real seconds after pressing play, at the case's speed.
            let seconds: Double
            let at: Date
        }

        struct Case: Decodable {
            let name: String
            let note: String
            let span: Stretch
            let legs: [Stretch]
            let waits: [Stretch]
            let quickLayovers: Bool
            let speed: Int
            /// The whole replay at 1x, in seconds.
            let replayLength: Double
            let checks: [Check]
        }

        struct WaitLabel: Decodable {
            let hours: Double
            let label: String?
            let note: String
        }

        let constants: Constants
        let cases: [Case]
        let waitLabels: [WaitLabel]
    }

    static func replayCases() throws -> ReplayCases {
        let data = try Data(contentsOf: folder.appending(path: "replay-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ReplayCases.self, from: data)
    }

    // MARK: - What the pilot is doing (activity markers design §2.2, §4.2, §5)

    struct ActivityCases: Decodable {
        struct Constants: Decodable {
            let shortestLayoverHours: Double
        }

        struct Airport: Decodable {
            let lat: Double
            let lon: Double
            let city: String?
        }

        enum Mode: String, Decodable {
            case trip, nextTrip, recap
        }

        struct Leg: Decodable {
            let id: String
            let type: TripLeg.LegType
            /// A flight's or a drive's airports.
            let from: String?
            let to: String?
            /// A ground leg's airport.
            let airport: String?
            let start: Date
            let end: Date
            let delayMinutes: Int?
        }

        struct Moment: Decodable {
            let at: Date
            /// `TripActivity.Kind`'s raw value.
            let kind: String
            let words: String
            let note: String
        }

        struct Trip: Decodable {
            let name: String
            let note: String
            let home: String
            let mode: Mode
            let legs: [Leg]
            let moments: [Moment]
        }

        let constants: Constants
        let airports: [String: Airport]
        let trips: [Trip]
    }

    static func activityCases() throws -> ActivityCases {
        let data = try Data(contentsOf: folder.appending(path: "activity-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ActivityCases.self, from: data)
    }
}
```

`ReplayCases.Stretch.clockStretch` names `TripReplayClock.Stretch`, which exists today, so this builds before Task 5.

- [ ] **Step 5: Nothing runs them yet.** Tasks 4, 5 and 6 do.

- [ ] **Step 6: Ask to commit.** Suggested message: `test(crewluv): the shared replay and activity cases for the trip map, ahead of the app and the website`. Stage only the two JSON files and `TripMapFixtures.swift`. Then tell Todd the website's session can copy both files into its `tests/fixtures/trip-map/` now.

---

### Task 3: `TripActivity`, and the timeline's words

**Files:**
- Create: `Crewluv/Services/TripMap/TripActivity.swift`
- Create: `Crewluv/Views/TripMap/TripActivity+Style.swift`
- Modify: `Crewluv/Services/TripMap/TripMapWording.swift`
- Test: `CrewluvTests/TripActivityTests.swift`
- Test: `CrewluvTests/TripMapWordingTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripActivityTests.swift`:

```swift
//
//  TripActivityTests.swift
//  CrewluvTests
//
//  What the pilot is doing, as the trip map draws it and says it (activity markers design §2.1, §4.2).
//

import XCTest
import CoreLocation
import SwiftUI
@testable import Crewluv

final class TripActivityTests: XCTestCase {

    private let denver = AirportMark(code: "DEN", city: "Denver",
                                     coordinate: CLLocationCoordinate2D(latitude: 39.8561, longitude: -104.6737), timeZone: nil)

    private func words(_ kind: TripActivity.Kind, at place: AirportMark? = nil) -> String {
        TripActivity(kind: kind, place: place ?? denver).words
    }

    func test_words_eachKind_readAsTheDesignSays() {
        XCTAssertEqual(words(.flying), "Flying to Denver")
        XCTAssertEqual(words(.driving), "Driving to Denver")
        XCTAssertEqual(words(.layover), "Layover in Denver")
        XCTAssertEqual(words(.turn), "Turn in Denver")
        XCTAssertEqual(words(.base), "At base in Denver")
        XCTAssertEqual(words(.home), "Home")
    }

    func test_words_aPlaceWithNoCity_isNamedByItsCode() {
        let springs = AirportMark(code: "COS", city: nil,
                                  coordinate: CLLocationCoordinate2D(latitude: 38.8058, longitude: -104.7008), timeZone: nil)
        XCTAssertEqual(words(.layover, at: springs), "Layover in COS")
    }

    func test_symbolName_eachKind_isTheDesignsSymbol() {
        XCTAssertEqual(TripActivity.Kind.allCases.map(\.symbolName),
                       ["airplane", "car.fill", "bed.double.fill", "hourglass", "briefcase.fill", "house.fill"])
    }

    func test_color_eachKind_isTheDesignsSystemColor() {
        XCTAssertEqual(TripActivity.Kind.allCases.map(\.color), [.blue, .gray, .indigo, .orange, .teal, .green])
    }

    func test_isMoving_onlyFlyingAndDriving() {
        XCTAssertEqual(TripActivity.Kind.allCases.filter(\.isMoving), [.flying, .driving])
    }
}
```

Then, in `CrewluvTests/TripMapWordingTests.swift`, replace:

```swift
    func test_timelineTime_weekdayAndTime() {
        XCTAssertEqual(plain(TripMapWording.timelineTime(now, calendar: calendar, locale: locale)), "Fri 3:14 PM")
    }
```

with:

```swift
    func test_timelineTime_weekdayAndTime() {
        XCTAssertEqual(plain(TripMapWording.timelineTime(now, calendar: calendar, locale: locale)), "Fri 3:14 PM")
    }

    // MARK: - The line under the timeline (activity markers design §4.2, §4.3)

    func test_timelineLine_isTheTimeAndWhatThePilotIsDoing() {
        let activity = TripActivity(kind: .layover, place: cologne)
        XCTAssertEqual(plain(TripMapWording.timelineLine(now, activity: activity, calendar: calendar, locale: locale)),
                       "Fri 3:14 PM · Layover in Cologne")
    }

    func test_timelineLine_noActivity_isTheTime() {
        XCTAssertEqual(plain(TripMapWording.timelineLine(now, activity: nil, calendar: calendar, locale: locale)), "Fri 3:14 PM")
    }

    func test_timelineSpokenValue_readsTheWholeDayAndTheActivity() {
        let activity = TripActivity(kind: .layover, place: cologne)
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(now, activity: activity, calendar: calendar, locale: locale)),
                       "Friday 3:14 PM, layover in Cologne")
    }

    func test_timelineSpokenValue_atHome_readsHome() {
        let activity = TripActivity(kind: .home, place: louisville)
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(now, activity: activity, calendar: calendar, locale: locale)),
                       "Friday 3:14 PM, home")
    }
```

- [ ] **Step 2: Run them, expecting a build failure** (`TripActivity` doesn't exist). Todd runs `TripActivityTests`.

- [ ] **Step 3: Write `TripActivity`.** Create `Crewluv/Services/TripMap/TripActivity.swift`:

```swift
//
//  TripActivity.swift
//  CrewLuve
//
//  What the pilot is doing at a moment of the trip, and where (activity markers design §2, §4.2): flying, driving, on
//  a layover, at a turn, at base or at home. The pilot's marker and the timeline's blocks draw the kind
//  (TripActivity+Style.swift), and the line under the timeline says it.
//

import Foundation

nonisolated struct TripActivity {

    /// The raw values are the shared cases' names (CrewluvTests/Fixtures/TripMap/activity-cases.json).
    nonisolated enum Kind: String, CaseIterable {
        case flying, driving, layover, turn, base, home

        /// Flying and driving show as the plane and the car. The rest are waits on the ground, with the pilot's marker.
        var isMoving: Bool {
            switch self {
            case .flying, .driving: true
            case .layover, .turn, .base, .home: false
            }
        }
    }

    let kind: Kind
    /// The flight's or the drive's destination, or where the pilot waits.
    let place: AirportMark

    /// The words under the timeline (design §4.2): "Flying to San Francisco", "Layover in Denver", "Home". A place is
    /// its city, else its code.
    var words: String {
        switch kind {
        case .flying: "Flying to \(place.name)"
        case .driving: "Driving to \(place.name)"
        case .layover: "Layover in \(place.name)"
        case .turn: "Turn in \(place.name)"
        case .base: "At base in \(place.name)"
        case .home: "Home"
        }
    }
}
```

- [ ] **Step 4: Write the kinds' symbols and colors.** Create `Crewluv/Views/TripMap/TripActivity+Style.swift`:

```swift
//
//  TripActivity+Style.swift
//  CrewLuve
//
//  How the trip map draws each kind of activity (activity markers design §2.1, §4.1): the SF Symbol on the pilot's
//  marker, and the color of the marker and of the timeline's blocks. They're system colors, so they adapt to Dark Mode,
//  and no wait's color is a route line's.
//

import SwiftUI

nonisolated extension TripActivity.Kind {

    /// The symbol on the pilot's marker. The plane and the car have markers of their own, and these match them.
    var symbolName: String {
        switch self {
        case .flying: "airplane"
        case .driving: "car.fill"
        case .layover: "bed.double.fill"
        case .turn: "hourglass"
        case .base: "briefcase.fill"
        case .home: "house.fill"
        }
    }

    /// The pilot's marker's circle, and the timeline block's fill.
    var color: Color {
        switch self {
        case .flying: .blue
        case .driving: .gray
        case .layover: .indigo
        case .turn: .orange
        case .base: .teal
        case .home: .green
        }
    }
}
```

- [ ] **Step 5: Write the timeline's line.** In `Crewluv/Services/TripMap/TripMapWording.swift`, replace:

```swift
    /// "Fri 9:14 PM", under the timeline and as the slider's VoiceOver value.
    static func timelineTime(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(style(calendar: calendar, locale: locale).weekday(.abbreviated).hour().minute())
    }
```

with:

```swift
    /// "Fri 9:14 PM", the time under the timeline.
    static func timelineTime(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        date.formatted(style(calendar: calendar, locale: locale).weekday(.abbreviated).hour().minute())
    }

    /// "Sat 1:40 PM · Layover in Denver": the line under the timeline, when and what (activity markers design §4.2).
    static func timelineLine(_ date: Date, activity: TripActivity?, calendar: Calendar = .current,
                             locale: Locale = .current) -> String {
        let time = timelineTime(date, calendar: calendar, locale: locale)
        guard let activity else { return time }
        return "\(time) · \(activity.words)"
    }

    /// "Saturday 1:40 PM, layover in Denver": the timeline's VoiceOver value (activity markers design §4.3).
    static func timelineSpokenValue(_ date: Date, activity: TripActivity?, calendar: Calendar = .current,
                                    locale: Locale = .current) -> String {
        let time = date.formatted(style(calendar: calendar, locale: locale).weekday(.wide).hour().minute())
        guard let activity else { return time }
        let words = activity.words
        return "\(time), \(words.prefix(1).lowercased() + words.dropFirst())"
    }
```

- [ ] **Step 6: Run the tests, expecting them to pass.** Todd runs `TripActivityTests` and `TripMapWordingTests`. Expected: `TripActivityTests` 5 tests, 0 failures; `TripMapWordingTests` 24 tests (it had 20), 0 failures.

- [ ] **Step 7: Ask to commit.** Suggested message: `feat(crewluv): TripActivity, what the pilot is doing, with each kind's symbol, color and words under the timeline`.

---

### Task 4: CrewLu's ground legs, the waits, and what the pilot is doing

`TripMap` gains a stored property, so its memberwise initializer gains a parameter. Seven of the facts tests make maps by hand; a test-only initializer keeps them as they are. Step 3's helper and Step 5's change to `TripMap` build only together.

**Files:**
- Create: `Crewluv/Services/TripMap/GroundStop.swift`
- Create: `Crewluv/Services/TripMap/TripWait.swift`
- Modify: `Crewluv/Services/TripMap/TripMap.swift`
- Create: `Crewluv/Services/TripMap/TripMap+Activity.swift`
- Create: `CrewluvTests/Helpers/TripMap+HandMade.swift`
- Test: `CrewluvTests/TripMapActivityTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripMapActivityTests.swift`:

```swift
//
//  TripMapActivityTests.swift
//  CrewluvTests
//
//  What the pilot is doing at any moment of the trip map (activity markers design §2.2): the waits between moving
//  legs, named by CrewLu's ground legs, and the activity before, during and after the trip. Held to the shared cases in
//  Fixtures/TripMap/activity-cases.json.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapActivityTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    /// Louisville to Cologne, a day there, Dubai, 20 hours there, and home, with CrewLu's two layovers.
    private func europe(isNextTrip: Bool = false) throws -> TripMap {
        try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: isNextTrip, at: hours(12)))
    }

    // MARK: - CrewLu's ground legs

    func test_make_keepsCrewLusGroundLegs_butDoesntDrawThem() throws {
        let map = try europe()
        XCTAssertEqual(map.groundStops.map(\.kind), [.layover, .layover])
        XCTAssertEqual(map.groundStops.first?.start, hours(8))
        XCTAssertEqual(map.legs.map(\.id), ["f1", "f2", "f3"])
    }

    func test_make_reserveAndEventLegs_arentKept() throws {
        let legs = TripMapTestLegs.europeTrip() + [
            TripMapTestLegs.leg("r1", .reserve, start: hours(80), hours: 12),
            TripMapTestLegs.leg("e1", .event, start: hours(100), hours: 2),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.groundStops.map(\.kind), [.layover, .layover])
    }

    // MARK: - The waits

    func test_waits_europeTrip_areItsTwoLayovers() throws {
        XCTAssertEqual(try europe().waits, [TripWait(start: hours(8), end: hours(32), kind: .layover),
                                            TripWait(start: hours(38), end: hours(58), kind: .layover)])
    }

    func test_waits_noGroundLeg_eightHoursIsALayover_andLessIsATurn() throws {
        let legs = [
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("f2", from: "CGN", to: "DXB", start: hours(16), hours: 6),
            TripMapTestLegs.leg("f3", from: "DXB", to: "SDF", start: hours(29.9), hours: 14),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.waits.map(\.kind), [.layover, .turn], "8 h in Cologne, 7 h 54 min in Dubai")
    }

    func test_waits_aDelay_namesEachWaitByTheGroundLegItOverlapsMost() throws {
        // f2 leaves 90 minutes late, at 10.5 h. Cologne's wait, 8 h to 10.5 h, overlaps CrewLu's turn for an hour and
        // its layover not at all. Dubai's, 16.5 h to 35 h, overlaps the layover, which began at f2's scheduled arrival.
        let legs = [
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("t1", .turn, start: hours(8), hours: 1),
            TripMapTestLegs.leg("f2", from: "CGN", to: "DXB", start: hours(9), hours: 6, delayMinutes: 90),
            TripMapTestLegs.leg("l1", .layover, start: hours(15), hours: 20),
            TripMapTestLegs.leg("f3", from: "DXB", to: "SDF", start: hours(35), hours: 14),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.waits, [TripWait(start: hours(8), end: hours(10.5), kind: .turn),
                                   TripWait(start: hours(16.5), end: hours(35), kind: .layover)])
    }

    func test_waits_twoGroundLegsTied_theEarlierNamesIt() throws {
        let legs = [
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8),
            TripMapTestLegs.leg("t1", .turn, start: hours(8), hours: 4),
            TripMapTestLegs.leg("l1", .layover, start: hours(12), hours: 4),
            TripMapTestLegs.leg("f2", from: "CGN", to: "SDF", start: hours(16), hours: 9),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(12)))
        XCTAssertEqual(map.waits.map(\.kind), [.turn], "4 hours each: the earlier names the whole wait")
    }

    // MARK: - What the pilot is doing

    func test_activity_inFlight_isFlyingToTheDestination() throws {
        let activity = try XCTUnwrap(try europe().activity(at: hours(4)))
        XCTAssertEqual(activity.kind, .flying)
        XCTAssertEqual(activity.words, "Flying to Cologne")
    }

    func test_activity_onTheLayover_isALayoverInCologne() throws {
        let activity = try XCTUnwrap(try europe().activity(at: hours(12)))
        XCTAssertEqual(activity.kind, .layover)
        XCTAssertEqual(activity.place.code, "CGN")
        XCTAssertEqual(activity.words, "Layover in Cologne")
    }

    func test_activity_beforeANextTrip_isHome() throws {
        let activity = try XCTUnwrap(try europe(isNextTrip: true).activity(at: hours(-48)))
        XCTAssertEqual(activity.kind, .home)
        XCTAssertEqual(activity.place.code, "SDF")
    }

    func test_activity_beforeATripFromBase_isAtBase() throws {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false, homeAirportCode: "LEX",
                                             legacyDelayMinutes: nil, at: hours(-2), coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.activity(at: hours(-2))?.kind, .base)
        XCTAssertEqual(map.activity(at: hours(-2))?.words, "At base in Louisville")
    }

    func test_activity_afterARecap_isHome_whereverTheTripEnded() throws {
        let legs = [TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8)]
        let map = try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, isRecap: true, homeAirportCode: "SDF",
                                             legacyDelayMinutes: nil, at: hours(10), coordinate: TripMapTestLegs.coordinate))
        XCTAssertEqual(map.activity(at: hours(10))?.kind, .home)
        XCTAssertEqual(map.activity(at: hours(10))?.place.code, "SDF")
    }

    func test_activity_aFlightOverlappingADrive_isFlying() throws {
        let legs = [
            TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 1.5),
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(1), hours: 8),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(1.25)))
        XCTAssertEqual(map.activity(at: hours(0.5))?.kind, .driving)
        XCTAssertEqual(map.activity(at: hours(1.25))?.kind, .flying)
    }

    // MARK: - The shared cases

    func test_activity_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.activityCases()
        XCTAssertEqual(TripWait.shortestLayover, cases.constants.shortestLayoverHours * 3600)
        XCTAssertFalse(cases.trips.isEmpty)
        for trip in cases.trips {
            let map = try XCTUnwrap(Self.map(of: trip, airports: cases.airports), trip.name)
            for moment in trip.moments {
                let activity = map.activity(at: moment.at)
                XCTAssertEqual(activity?.kind.rawValue, moment.kind, "\(trip.name), \(moment.note)")
                XCTAssertEqual(activity?.words, moment.words, "\(trip.name), \(moment.note)")
            }
        }
    }

    /// The trip's legs as CrewLu would send them, each city from the shared airports.
    private static func map(of trip: TripMapFixtures.ActivityCases.Trip,
                            airports: [String: TripMapFixtures.ActivityCases.Airport]) -> TripMap? {
        let legs = trip.legs.map { leg in
            TripLeg(id: leg.id, tripId: "T1", type: leg.type, startTime: leg.start, endTime: leg.end,
                    airportCode: leg.airport, city: leg.airport.flatMap { airports[$0]?.city },
                    timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil, flightNumber: nil,
                    departureAirport: leg.from, arrivalAirport: leg.to,
                    departureCity: leg.from.flatMap { airports[$0]?.city }, arrivalCity: leg.to.flatMap { airports[$0]?.city },
                    tripDayNumber: nil, tripTotalDays: nil, delayMinutes: leg.delayMinutes, airlineCode: nil, label: nil)
        }
        return TripMap.make(tripLegs: legs, isNextTrip: trip.mode == .nextTrip, isRecap: trip.mode == .recap,
                            homeAirportCode: trip.home, legacyDelayMinutes: nil, at: .distantPast,
                            coordinate: { code in airports[code].map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) } })
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure** (`groundStops`, `waits` and `activity(at:)` don't exist). Todd runs `TripMapActivityTests`.

- [ ] **Step 3: Keep the hand-made maps.** Create `CrewluvTests/Helpers/TripMap+HandMade.swift`:

```swift
//
//  TripMap+HandMade.swift
//  CrewluvTests
//
//  The facts' tests make maps by hand, with no ground legs from CrewLu. This keeps them as they were before `TripMap`
//  kept its ground stops (activity markers design §2.2).
//

import Foundation
@testable import Crewluv

extension TripMap {
    init(mode: Mode, legs: [MapLeg], home: AirportMark?, span: DateInterval, tripDays: Int?) {
        self.init(mode: mode, legs: legs, groundStops: [], home: home, span: span, tripDays: tripDays)
    }
}
```

- [ ] **Step 4: Write the ground stop and the wait.** Create `Crewluv/Services/TripMap/GroundStop.swift`:

```swift
//
//  GroundStop.swift
//  CrewLuve
//
//  One of CrewLu's own ground legs, which the trip map keeps to name each wait (activity markers design §2.2): a
//  layover, a turn, or a stay at base or at home, at its scheduled times. A delay moves the flights, never these.
//

import Foundation

nonisolated struct GroundStop {
    /// `.layover`, `.turn`, `.base` or `.home`.
    let kind: TripActivity.Kind
    let start: Date
    let end: Date
}

nonisolated extension GroundStop {
    /// The stop for CrewLu's layover, turn, base or home leg; nil for a flight, a drive or anything else.
    init?(leg: TripLeg) {
        let kind: TripActivity.Kind
        switch leg.type {
        case .layover: kind = .layover
        case .turn: kind = .turn
        case .base: kind = .base
        case .home: kind = .home
        case .flight, .drive, .reserve, .hotStandby, .event, .unknown: return nil
        }
        self.init(kind: kind, start: leg.startTime, end: leg.endTime)
    }
}
```

Create `Crewluv/Services/TripMap/TripWait.swift`:

```swift
//
//  TripWait.swift
//  CrewLuve
//
//  A stretch of the trip with no leg moving (activity markers design §2.2): from one leg's end, delay included, to the
//  next leg's start, and what the pilot does there. With Quick layovers on the replay hurries through it (§3.2), and
//  the timeline colors it (§4.1).
//

import Foundation

nonisolated struct TripWait: Equatable {
    /// With no ground leg from CrewLu to name it, a wait this long or longer is a layover, and a shorter one a turn.
    static let shortestLayover: TimeInterval = 8 * 3600

    let start: Date
    let end: Date
    /// `.layover`, `.turn`, `.base` or `.home`.
    let kind: TripActivity.Kind
}
```

- [ ] **Step 5: Keep the ground stops.** In `Crewluv/Services/TripMap/TripMap.swift`, make four replacements.

Replace:

```swift
//  The trip the map shows (moving map spec §5.1): its drawable legs, whether the pilot is flying, on the ground
//  mid-trip, or home with this trip ahead, and where the pilot is at any moment.
```

with:

```swift
//  The trip the map shows (moving map spec §5.1): its drawable legs, CrewLu's ground legs, whether the pilot is flying,
//  on the ground mid-trip, or home with this trip ahead, and where the pilot is at any moment. What they're doing there
//  is in TripMap+Activity.swift.
```

Replace:

```swift
    /// Never empty, earliest first.
    let legs: [MapLeg]
    let home: AirportMark?
```

with:

```swift
    /// Never empty, earliest first.
    let legs: [MapLeg]
    /// CrewLu's layovers, turns, and stays at base and home, earliest first. They name the waits between legs
    /// (activity markers design §2.2), and aren't drawn.
    let groundStops: [GroundStop]
    let home: AirportMark?
```

Replace:

```swift
        guard let first = legs.first else { return nil }
```

with:

```swift
        guard let first = legs.first else { return nil }
        let groundStops = sorted.compactMap(GroundStop.init(leg:))
```

Replace:

```swift
        return TripMap(mode: mode, legs: legs, home: home,
```

with:

```swift
        return TripMap(mode: mode, legs: legs, groundStops: groundStops, home: home,
```

- [ ] **Step 6: Write the activity.** Create `Crewluv/Services/TripMap/TripMap+Activity.swift`:

```swift
//
//  TripMap+Activity.swift
//  CrewLuve
//
//  What the pilot is doing at any moment of the trip map (activity markers design §2.2), for the pilot's marker, the
//  timeline's colors and the words under it. The shared cases are in CrewluvTests/Fixtures/TripMap/activity-cases.json.
//

import Foundation

nonisolated extension TripMap {

    /// Every stretch of the span with no leg moving, earliest first, each named by CrewLu's ground legs. A leg with no
    /// length never moves.
    var waits: [TripWait] {
        var waits: [TripWait] = []
        var movingUntil = span.start
        for leg in legs.sorted(by: { $0.start < $1.start }) where leg.end > leg.start {
            if leg.start > movingUntil {
                waits.append(makeWait(from: movingUntil, to: leg.start))
            }
            movingUntil = max(movingUntil, leg.end)
        }
        if span.end > movingUntil {
            waits.append(makeWait(from: movingUntil, to: span.end))
        }
        return waits
    }

    /// What the pilot is doing at `date`, and where. A flight wins over a drive that overlaps it. Nil only for a map
    /// with no legs, which `make` never returns.
    func activity(at date: Date) -> TripActivity? {
        let moving = legs.first { $0.kind == .flight && $0.isMoving(at: date) } ?? legInMotion(at: date)
        if let moving {
            return TripActivity(kind: moving.kind == .flight ? .flying : .driving, place: moving.destination)
        }
        guard let place = pilotLocation(at: date) else { return nil }
        return TripActivity(kind: groundKind(at: date, place: place), place: place)
    }

    // MARK: - On the ground

    /// Before the first departure, home for a next trip, else home or base by where the trip starts. From the last
    /// arrival on, home for a recap, else home or base by where it ends. In between, the wait's kind.
    private func groundKind(at date: Date, place: AirportMark) -> TripActivity.Kind {
        let isHomeAirport = place.code == home?.code
        if date < span.start { return (mode == .nextTrip || isHomeAirport) ? .home : .base }
        if date >= span.end { return (mode == .recap || isHomeAirport) ? .home : .base }
        // Inside the span with nothing moving, one of the waits holds `date`.
        return waits.first { $0.start <= date && date < $0.end }?.kind ?? .turn
    }

    /// The wait from `start` to `end`, named by the ground stop that overlaps it most, the earlier on a tie; with none,
    /// by its length.
    private func makeWait(from start: Date, to end: Date) -> TripWait {
        var best: (kind: TripActivity.Kind, overlap: TimeInterval, start: Date)?
        for stop in groundStops {
            let overlap = min(stop.end, end).timeIntervalSince(max(stop.start, start))
            guard overlap > 0 else { continue }
            if let current = best, overlap < current.overlap || (overlap == current.overlap && stop.start >= current.start) {
                continue
            }
            best = (stop.kind, overlap, stop.start)
        }
        let kind = best?.kind ?? (end.timeIntervalSince(start) >= TripWait.shortestLayover ? .layover : .turn)
        return TripWait(start: start, end: end, kind: kind)
    }
}
```

- [ ] **Step 7: Run the tests, expecting them to pass.** Todd runs `TripMapActivityTests`, then `TripMapTests`, `TripFactsTests`, `TripFactsRowsTests` and `FactsCasesTests`. Expected: `TripMapActivityTests` 13 tests, 0 failures. The other four pass as before, with the same counts: the hand-made maps use Step 3's initializer.

- [ ] **Step 8: Ask to commit.** Suggested message: `feat(crewluv): the trip map keeps CrewLu's ground legs and says what the pilot is doing at any moment`.

---

### Task 5: The clock's pace through waits, and positions in replay time

The whole file is rewritten. Against today's version, the changes are: `Stretch.duration`; the two new constants; `isQuickLayovers` and `setQuickLayovers(_:at:)`; the `waits` and `isQuickLayovers` parameters; two piece lists instead of one; and the positions, which are today's private `replayTime(at:)` and `tripTime(atReplay:)` made internal and renamed, with `replayDuration`, `progress(at:)` and `tripTime(atProgress:)` added. Every existing test in `TripReplayClockTests` passes unchanged: with no waits, or with Quick layovers off, the pace is today's.

**Files:**
- Rewrite: `Crewluv/Services/TripMap/TripReplayClock.swift`
- Test: `CrewluvTests/TripReplayClockPaceTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripReplayClockPaceTests.swift`:

```swift
//
//  TripReplayClockPaceTests.swift
//  CrewluvTests
//
//  The replay's pace through waits on the ground, with Quick layovers on and off, and the timeline's positions in
//  replay time (activity markers design §3.2, §4.3). Held to the shared cases in Fixtures/TripMap/replay-cases.json.
//

import XCTest
@testable import Crewluv

final class TripReplayClockPaceTests: XCTestCase {

    private let tripStart = TripMapTestLegs.tripStart
    /// The real time play is pressed.
    private let now = Date(timeIntervalSince1970: 1_800_050_000)

    private func hours(_ value: Double) -> Date { tripStart.addingTimeInterval(value * 3600) }

    private func stretch(_ start: Double, _ end: Double) -> TripReplayClock.Stretch {
        TripReplayClock.Stretch(start: hours(start), end: hours(end))
    }

    /// Louisville to Cologne (8 h), a day in Cologne, on to Dubai (6 h), 20 hours there, and home (14 h). At 1x with
    /// Quick layovers on: 16 s, 3 s, 12 s, 3 s and 28 s; off: 16 s, 48 s, 12 s, 40 s and 28 s.
    private func europe(isQuickLayovers: Bool) -> TripReplayClock {
        TripReplayClock(span: DateInterval(start: hours(0), end: hours(72)),
                        legs: [stretch(0, 8), stretch(32, 38), stretch(58, 72)],
                        waits: [stretch(8, 32), stretch(38, 58)], isQuickLayovers: isQuickLayovers)
    }

    private func playing(_ clock: TripReplayClock) -> TripReplayClock {
        var clock = clock
        clock.play(at: now)
        return clock
    }

    private func assertTime(_ clock: TripReplayClock, after seconds: TimeInterval, isHour hour: Double,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(seconds)).timeIntervalSince1970,
                       hours(hour).timeIntervalSince1970, accuracy: 0.01, file: file, line: line)
    }

    // MARK: - Quick layovers

    func test_play_quickLayovers_aDayInCologneTakes3Seconds() {
        let clock = playing(europe(isQuickLayovers: true))
        assertTime(clock, after: 16, isHour: 8)
        assertTime(clock, after: 17.5, isHour: 20)
        assertTime(clock, after: 19, isHour: 32)
    }

    func test_play_quickLayoversOff_aDayInCologneTakes48Seconds() {
        let clock = playing(europe(isQuickLayovers: false))
        assertTime(clock, after: 17.5, isHour: 8.75)
        assertTime(clock, after: 64, isHour: 32)
    }

    func test_play_quickLayovers_aFourDayLayoverTakes4Seconds() {
        let clock = playing(TripReplayClock(span: DateInterval(start: hours(0), end: hours(100)),
                                            legs: [stretch(0, 2), stretch(98, 100)], waits: [stretch(2, 98)],
                                            isQuickLayovers: true))
        assertTime(clock, after: 5, isHour: 26)
        assertTime(clock, after: 8, isHour: 98)
    }

    func test_play_quickLayovers_anHoursTurnKeepsItsNormal2Seconds_andTwoHoursTake3() {
        let clock = playing(TripReplayClock(span: DateInterval(start: hours(0), end: hours(9)),
                                            legs: [stretch(0, 2), stretch(3, 5), stretch(7, 9)],
                                            waits: [stretch(2, 3), stretch(5, 7)], isQuickLayovers: true))
        assertTime(clock, after: 6, isHour: 3)
        assertTime(clock, after: 11.5, isHour: 6)
        assertTime(clock, after: 13, isHour: 7)
    }

    func test_play_quickLayovers_atTenTimes_everyPartTakesATenth() {
        var clock = playing(europe(isQuickLayovers: true))
        clock.setSpeed(.ten, at: now)
        assertTime(clock, after: 1.6, isHour: 8)
        assertTime(clock, after: 1.9, isHour: 32)
    }

    func test_setQuickLayovers_whilePlaying_keepsTheMomentAndChangesThePace() {
        var clock = playing(europe(isQuickLayovers: true))
        let midLayover = now.addingTimeInterval(17.5)
        clock.setQuickLayovers(false, at: midLayover)
        XCTAssertFalse(clock.isQuickLayovers)
        XCTAssertEqual(clock.time(at: midLayover).timeIntervalSince1970, hours(20).timeIntervalSince1970, accuracy: 0.01)
        // The rest of the day in Cologne, 12 hours, at a day in 48 s: 24 s.
        XCTAssertEqual(clock.time(at: midLayover.addingTimeInterval(24)).timeIntervalSince1970,
                       hours(32).timeIntervalSince1970, accuracy: 0.01)
    }

    func test_setQuickLayovers_whilePaused_keepsTheMoment() {
        var clock = europe(isQuickLayovers: false)
        clock.scrub(to: hours(20))
        clock.setQuickLayovers(true, at: now)
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now.addingTimeInterval(60)), hours(20))
    }

    func test_pause_afterTheEnd_holdsTheEnd_andPlayStartsOver() {
        var clock = playing(europe(isQuickLayovers: true))
        let afterTheEnd = now.addingTimeInterval(70)
        clock.pause(at: afterTheEnd)
        XCTAssertEqual(clock.time(at: afterTheEnd), hours(72))
        XCTAssertFalse(clock.hasFinished(at: afterTheEnd), "paused, the replay isn't running")
        clock.play(at: afterTheEnd)
        XCTAssertEqual(clock.time(at: afterTheEnd), hours(0))
    }

    // MARK: - Positions in replay time

    func test_replayDuration_isTheWholeReplayAt1x_atEachPace() {
        XCTAssertEqual(europe(isQuickLayovers: true).replayDuration, 62, accuracy: 1e-9)
        XCTAssertEqual(europe(isQuickLayovers: false).replayDuration, 144, accuracy: 1e-9)
    }

    func test_replayOffset_andTripTimeAtReplayOffset_areInverses() {
        let clock = europe(isQuickLayovers: true)
        XCTAssertEqual(clock.replayOffset(of: hours(20)), 17.5, accuracy: 1e-9)
        XCTAssertEqual(clock.tripTime(atReplayOffset: 17.5).timeIntervalSince1970, hours(20).timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(clock.tripTime(atReplayOffset: 100), hours(72), "past the whole replay, the end")
    }

    func test_progress_isReplayTimeOverTheWhole_andIsHeldToTheEnds() {
        let clock = europe(isQuickLayovers: true)
        XCTAssertEqual(clock.progress(at: hours(8)), 16.0 / 62, accuracy: 1e-9)
        XCTAssertEqual(clock.progress(at: hours(-5)), 0)
        XCTAssertEqual(clock.progress(at: hours(99)), 1)
        XCTAssertEqual(clock.tripTime(atProgress: 31.0 / 62).timeIntervalSince1970, hours(38).timeIntervalSince1970, accuracy: 0.001)
    }

    func test_progress_aTripWithNoLength_isZero() {
        let clock = TripReplayClock(span: DateInterval(start: hours(0), end: hours(0)))
        XCTAssertEqual(clock.progress(at: hours(0)), 0)
    }

    // MARK: - The shared cases

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.replayCases().constants
        XCTAssertEqual(TripReplayClock.baseRate, constants.baseRate)
        XCTAssertEqual(TripReplayClock.legMinimumReplay, constants.legMinimumSeconds)
        XCTAssertEqual(TripReplayClock.waitMinimumReplay, constants.waitMinimumSeconds)
        XCTAssertEqual(TripReplayClock.quickWaitRate, constants.quickWaitRate)
    }

    func test_play_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.replayCases().cases
        XCTAssertFalse(cases.isEmpty)
        for replayCase in cases {
            let speed = try XCTUnwrap(TripReplayClock.Speed(rawValue: replayCase.speed), replayCase.name)
            var clock = TripReplayClock(span: DateInterval(start: replayCase.span.start, end: replayCase.span.end),
                                        legs: replayCase.legs.map(\.clockStretch), waits: replayCase.waits.map(\.clockStretch),
                                        isQuickLayovers: replayCase.quickLayovers)
            XCTAssertEqual(clock.replayDuration, replayCase.replayLength, accuracy: 1e-6, replayCase.name)
            clock.play(at: now)
            clock.setSpeed(speed, at: now)
            for check in replayCase.checks {
                XCTAssertEqual(clock.time(at: now.addingTimeInterval(check.seconds)).timeIntervalSince1970,
                               check.at.timeIntervalSince1970, accuracy: 0.01, "\(replayCase.name), at \(check.seconds) s")
            }
        }
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure** (`waits:`, `isQuickLayovers:` and the positions don't exist). Todd runs `TripReplayClockPaceTests`.

- [ ] **Step 3: Rewrite the clock.** Replace the whole of `Crewluv/Services/TripMap/TripReplayClock.swift` with:

```swift
//
//  TripReplayClock.swift
//  CrewLuve
//
//  The full-screen map's time (moving map spec §6): now, a moment dragged to, or a replay running at 1x to 10x.
//  A value: the screen keeps it in `@State` and reads `time(at:)` on each tick, so nothing mutates per frame.
//  The pace (activity markers design §3.2) is a day in 48 s. A leg in motion that would pass in under 3 s at 1x slows
//  so it takes 3 s, as on the website (Crewluve Website docs/superpowers/specs/2026-11-13-replay-short-legs-design.md).
//  With Quick layovers on, a wait on the ground takes a second a day, never under 3 s and never slower than a day in
//  48 s. The clock also places any moment along the timeline in replay time (§4.3). The shared cases are in
//  CrewluvTests/Fixtures/TripMap/replay-cases.json.
//

import Foundation

nonisolated struct TripReplayClock {

    nonisolated enum Speed: Int, CaseIterable, Identifiable {
        case one = 1, two = 2, five = 5, ten = 10
        var id: Int { rawValue }
    }

    /// A leg's or a wait's stretch of trip time, from its start to its end.
    nonisolated struct Stretch: Equatable {
        let start: Date
        let end: Date

        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    /// Seconds of trip per second of replay at 1x: a day in 48 seconds, as on CrewLu's moving map.
    static let baseRate: Double = 1_800
    /// The least replay time, in seconds at 1x, that a leg in motion takes, so a drive to work can be seen.
    static let legMinimumReplay: TimeInterval = 3
    /// The least replay time, in seconds at 1x, that a wait takes with Quick layovers on.
    static let waitMinimumReplay: TimeInterval = 3
    /// Seconds of trip per second of replay at 1x through a long wait with Quick layovers on: a day a second.
    static let quickWaitRate: Double = 86_400

    let span: DateInterval
    private(set) var speed: Speed = .one
    /// Whether waits on the ground hurry by (activity markers design §3.1).
    private(set) var isQuickLayovers: Bool

    /// The span cut at every leg's and wait's start and end, each piece with its rate, at the normal pace and with
    /// Quick layovers on. Both are worked out here, so switching costs nothing.
    private let normalPieces: [Piece]
    private let quickPieces: [Piece]

    /// Nil while live. Otherwise the trip time it was set to, and when it started playing from there.
    private var anchor: (tripTime: Date, playingSince: Date?)?

    /// - Parameters:
    ///   - legs: the trip's drives and flights. A short one slows the replay while it moves.
    ///   - waits: the stretches with no leg moving, which Quick layovers hurries through.
    ///   - isQuickLayovers: off unless asked, so a clock made as before plays as before.
    init(span: DateInterval, legs: [Stretch] = [], waits: [Stretch] = [], isQuickLayovers: Bool = false) {
        self.span = span
        self.isQuickLayovers = isQuickLayovers
        normalPieces = Self.pace(span: span, legs: legs, waits: waits, isQuickLayovers: false)
        quickPieces = Self.pace(span: span, legs: legs, waits: waits, isQuickLayovers: true)
    }

    /// Paused at `date`: the recap opens at its trip's start, ready to play (Stage 2 spec §6.5).
    init(span: DateInterval, legs: [Stretch] = [], waits: [Stretch] = [], isQuickLayovers: Bool = false,
         pausedAt date: Date) {
        self.init(span: span, legs: legs, waits: waits, isQuickLayovers: isQuickLayovers)
        scrub(to: date)
    }

    var isLive: Bool { anchor == nil }

    /// Whether a replay is running. It stays true once the replay reaches the trip's end, so the UI checks
    /// `hasFinished(at:)` to show Play again.
    var isPlaying: Bool { anchor?.playingSince != nil }

    /// The trip time to show at the real time `now`.
    func time(at now: Date) -> Date {
        guard let anchor else { return now }
        guard let playingSince = anchor.playingSince else { return anchor.tripTime }
        let elapsed = max(now.timeIntervalSince(playingSince), 0) * Double(speed.rawValue)
        return tripTime(atReplayOffset: replayOffset(of: anchor.tripTime) + elapsed)
    }

    /// True once a replay has run to the trip's end.
    func hasFinished(at now: Date) -> Bool {
        isPlaying && time(at: now) >= span.end
    }

    mutating func scrub(to date: Date) {
        anchor = (min(max(date, span.start), span.end), nil)
    }

    /// Plays from where it is, from the start when live, and again from the start once it has finished.
    mutating func play(at now: Date) {
        let current = isLive ? span.start : time(at: now)
        anchor = (current >= span.end ? span.start : current, now)
    }

    mutating func pause(at now: Date) {
        guard isPlaying else { return }
        anchor = (time(at: now), nil)
    }

    mutating func setSpeed(_ newSpeed: Speed, at now: Date) {
        if isPlaying { anchor = (time(at: now), now) }
        speed = newSpeed
    }

    /// Hurries through waits, or plays them at the normal rate, from the moment on screen (activity markers design
    /// §3.1). A replay carries on from there at the new pace.
    mutating func setQuickLayovers(_ isOn: Bool, at now: Date) {
        if isPlaying { anchor = (time(at: now), now) }
        isQuickLayovers = isOn
    }

    mutating func goLive() {
        anchor = nil
    }
}

// MARK: - Positions along the timeline (activity markers design §4.3)

nonisolated extension TripReplayClock {

    /// The whole replay at 1x, in seconds, at the current pace.
    var replayDuration: TimeInterval { replayOffset(of: span.end) }

    /// The replay seconds at 1x from the span's start to the trip time `date`, at the current pace.
    func replayOffset(of date: Date) -> TimeInterval {
        pieces.reduce(0) { sum, piece in sum + max(0, min(date, piece.end).timeIntervalSince(piece.start)) / piece.rate }
    }

    /// The trip time `offset` replay seconds at 1x after the span's start, at the current pace: the span's end once
    /// the whole replay has played.
    func tripTime(atReplayOffset offset: TimeInterval) -> Date {
        var left = offset
        for piece in pieces {
            let length = piece.end.timeIntervalSince(piece.start) / piece.rate
            if left < length { return piece.start.addingTimeInterval(max(left, 0) * piece.rate) }
            left -= length
        }
        return span.end
    }

    /// Where `date` sits along the timeline, 0 at the span's start and 1 at its end, in replay time at 1x. The bar's
    /// thumb and blocks are placed by it.
    func progress(at date: Date) -> Double {
        let duration = replayDuration
        guard duration > 0 else { return 0 }
        return min(max(replayOffset(of: date) / duration, 0), 1)
    }

    /// The trip time at `progress`, 0...1, along the timeline.
    func tripTime(atProgress progress: Double) -> Date {
        tripTime(atReplayOffset: min(max(progress, 0), 1) * replayDuration)
    }
}

// MARK: - The pace

nonisolated extension TripReplayClock {

    /// A stretch of the trip played at one rate: trip seconds per replay second at 1x.
    private nonisolated struct Piece {
        let start: Date
        let end: Date
        let rate: Double
    }

    /// The pieces at the pace in use.
    private var pieces: [Piece] { isQuickLayovers ? quickPieces : normalPieces }

    /// Each piece plays at the normal rate. While legs move through it, it plays at the slowest of their rates, a
    /// leg's length over 3 s; a leg with no length covers no piece, so it adds no time. Through a wait with Quick
    /// layovers on, it plays at the whole wait's quick rate.
    private static func pace(span: DateInterval, legs: [Stretch], waits: [Stretch], isQuickLayovers: Bool) -> [Piece] {
        let cuts = ([span.start, span.end] + (legs + waits).flatMap { [$0.start, $0.end] })
            .filter { span.start <= $0 && $0 <= span.end }
        let times = Set(cuts).sorted()
        return zip(times, times.dropFirst()).map { from, to in
            let moving = legs.filter { $0.start <= from && to <= $0.end }
            if !moving.isEmpty {
                return Piece(start: from, end: to, rate: moving.map { $0.duration / legMinimumReplay }.reduce(baseRate, min))
            }
            let wait = isQuickLayovers ? waits.first(where: { $0.start <= from && to <= $0.end }) : nil
            return Piece(start: from, end: to, rate: wait.map { quickRate(forWaitOf: $0.duration) } ?? baseRate)
        }
    }

    /// A wait of `length` trip seconds plays in min(length / 1,800, max(3, length / 86,400)) replay seconds at 1x: a
    /// second a day, never under 3 s, and never slower than the normal rate. As a rate, that's the wait's length over
    /// those seconds.
    private static func quickRate(forWaitOf length: TimeInterval) -> Double {
        max(baseRate, min(length / waitMinimumReplay, quickWaitRate))
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `TripReplayClockPaceTests` and `TripReplayClockTests`. Expected: `TripReplayClockPaceTests` 14 tests, 0 failures; `TripReplayClockTests` 16 tests, 0 failures, unchanged.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): the replay clock hurries through waits with Quick layovers and places any moment in replay time`.

---

### Task 6: The bar's blocks, and the track they're laid on

**Files:**
- Create: `Crewluv/Services/TripMap/TripTimeline.swift`
- Create: `Crewluv/Views/TripMap/TripTimelineTrack.swift`
- Test: `CrewluvTests/TripTimelineTests.swift`
- Test: `CrewluvTests/TripTimelineTrackTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripTimelineTests.swift`:

```swift
//
//  TripTimelineTests.swift
//  CrewluvTests
//
//  The timeline bar's blocks, in replay time and colored by what the pilot is doing, and the waits' lengths written on
//  them (activity markers design §4.1).
//

import XCTest
@testable import Crewluv

final class TripTimelineTests: XCTestCase {

    private typealias Expected = (kind: TripActivity.Kind, start: Double, end: Double, label: String?)

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    private func europe() throws -> TripMap {
        try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
    }

    private func clock(for map: TripMap, isQuickLayovers: Bool) -> TripReplayClock {
        TripReplayClock(span: map.span, legs: map.legs.map { .init(start: $0.start, end: $0.end) },
                        waits: map.waits.map { .init(start: $0.start, end: $0.end) }, isQuickLayovers: isQuickLayovers)
    }

    private func assertBlocks(_ blocks: [TripTimeline.Block], are expected: [Expected],
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(blocks.map(\.kind), expected.map { $0.kind }, file: file, line: line)
        for (block, want) in zip(blocks, expected) {
            XCTAssertEqual(block.start, want.start, accuracy: 1e-9, file: file, line: line)
            XCTAssertEqual(block.end, want.end, accuracy: 1e-9, file: file, line: line)
            XCTAssertEqual(block.label, want.label, file: file, line: line)
        }
    }

    // MARK: - Blocks

    func test_blocks_quickLayovers_areTheFlightsAndTwoSmallLayovers() throws {
        let map = try europe()
        // 16 s, 3 s, 12 s, 3 s and 28 s of a 62 s replay.
        assertBlocks(TripTimeline(tripMap: map, clock: clock(for: map, isQuickLayovers: true)).blocks, are: [
            (.flying, 0, 16.0 / 62, nil), (.layover, 16.0 / 62, 19.0 / 62, "24h"), (.flying, 19.0 / 62, 31.0 / 62, nil),
            (.layover, 31.0 / 62, 34.0 / 62, "20h"), (.flying, 34.0 / 62, 1, nil),
        ])
    }

    func test_blocks_quickLayoversOff_theLayoversTakeTheirFullShare() throws {
        let map = try europe()
        // 16 s, 48 s, 12 s, 40 s and 28 s of a 144 s replay.
        assertBlocks(TripTimeline(tripMap: map, clock: clock(for: map, isQuickLayovers: false)).blocks, are: [
            (.flying, 0, 16.0 / 144, nil), (.layover, 16.0 / 144, 64.0 / 144, "24h"), (.flying, 64.0 / 144, 76.0 / 144, nil),
            (.layover, 76.0 / 144, 116.0 / 144, "20h"), (.flying, 116.0 / 144, 1, nil),
        ])
    }

    func test_blocks_aFlightOverlappingADrive_isFlying() throws {
        let legs = [
            TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 1.5),
            TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(1), hours: 8),
        ]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(1)))
        // The drive alone for an hour (2 s), then both, then the flight: 18 s in all.
        assertBlocks(TripTimeline(tripMap: map, clock: clock(for: map, isQuickLayovers: true)).blocks, are: [
            (.driving, 0, 2.0 / 18, nil), (.flying, 2.0 / 18, 1, nil),
        ])
    }

    func test_blocks_aTripWithNoLength_isEmpty() {
        let leg = MapLeg(id: "f", kind: .flight,
                         origin: FactsTestData.mark("A", latitude: 0, longitude: 0),
                         destination: FactsTestData.mark("B", latitude: 0, longitude: 1),
                         start: start, end: start, flightNumber: nil)
        let map = TripMap(mode: .onTrip, legs: [leg], home: nil, span: DateInterval(start: start, end: start), tripDays: nil)
        XCTAssertEqual(TripTimeline(tripMap: map, clock: TripReplayClock(span: map.span)).blocks, [])
    }

    // MARK: - The waits' lengths

    func test_lengthLabel_hoursUnder48_daysFrom48() {
        XCTAssertEqual(TripTimeline.lengthLabel(for: 20 * 3600), "20h")
        XCTAssertEqual(TripTimeline.lengthLabel(for: 47 * 3600), "47h")
        XCTAssertEqual(TripTimeline.lengthLabel(for: 48 * 3600), "2d")
        XCTAssertEqual(TripTimeline.lengthLabel(for: 96 * 3600), "4d")
    }

    func test_lengthLabel_underHalfAnHour_isNil() {
        XCTAssertNil(TripTimeline.lengthLabel(for: 20 * 60))
    }

    func test_lengthLabel_everySharedCase_matches() throws {
        let labels = try TripMapFixtures.replayCases().waitLabels
        XCTAssertFalse(labels.isEmpty)
        for wait in labels {
            XCTAssertEqual(TripTimeline.lengthLabel(for: wait.hours * 3600), wait.label, "\(wait.hours) h: \(wait.note)")
        }
    }
}
```

The overlap case's numbers: the drive is 1.5 h, 3 s at the normal rate, so its 3 s floor leaves it at 1,800. Its first hour plays alone in 2 s. Then both move for half an hour, the slower of 1,800 and the flight's 28,800 ÷ 3 = 9,600, so 1,800: 1 s. Then the flight alone, 7.5 h: 15 s. That's 18 s, and the flying block starts at 2/18.

Create `CrewluvTests/TripTimelineTrackTests.swift`:

```swift
//
//  TripTimelineTrackTests.swift
//  CrewluvTests
//
//  Where a point of the timeline sits across the bar, and back (activity markers design §4.1): along the thumb's
//  travel, with the first and last blocks reaching the bar's ends.
//

import XCTest
import CoreGraphics
@testable import Crewluv

final class TripTimelineTrackTests: XCTestCase {

    /// A 228 pt bar with a 28 pt thumb: 200 pt of travel, from 14 to 214.
    private let track = TripTimelineTrack(width: 228, inset: 14)

    func test_x_runsAlongTheThumbsTravel_andIsHeldToItsEnds() {
        XCTAssertEqual(track.x(at: 0), 14)
        XCTAssertEqual(track.x(at: 0.5), 114)
        XCTAssertEqual(track.x(at: 1), 214)
        XCTAssertEqual(track.x(at: 1.5), 214)
    }

    func test_progressAtX_isTheInverse_andIsHeldToTheEnds() {
        XCTAssertEqual(track.progress(atX: 64), 0.25, accuracy: 1e-12)
        XCTAssertEqual(track.progress(atX: 0), 0)
        XCTAssertEqual(track.progress(atX: 300), 1)
    }

    func test_blockEdges_theFirstAndLastReachTheBarsEnds() {
        XCTAssertEqual(track.blockEdges(from: 0, to: 0.5).leading, 0)
        XCTAssertEqual(track.blockEdges(from: 0, to: 0.5).trailing, 114)
        XCTAssertEqual(track.blockEdges(from: 0.5, to: 1).trailing, 228)
    }

    func test_progressAtX_aBarNoWiderThanTheThumb_isZero() {
        XCTAssertEqual(TripTimelineTrack(width: 28, inset: 14).progress(atX: 20), 0)
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `TripTimelineTests` and `TripTimelineTrackTests`.

- [ ] **Step 3: Write `TripTimeline`.** Create `Crewluv/Services/TripMap/TripTimeline.swift`:

```swift
//
//  TripTimeline.swift
//  CrewLuve
//
//  The timeline bar's blocks (activity markers design §4.1): the trip's span in replay time at 1x, at the clock's pace,
//  each part colored by what the pilot is doing. A flight that overlaps a drive is flying. Each wait carries its real
//  length, "20h" or "4d", which the bar writes on it when it fits.
//

import Foundation

nonisolated struct TripTimeline {

    nonisolated struct Block: Equatable {
        let kind: TripActivity.Kind
        /// Where it starts and ends along the bar, 0...1: its replay time at 1x over the whole replay's.
        let start: Double
        let end: Double
        /// A wait's real length; nil for a flight or a drive, and for a wait under half an hour.
        let label: String?
    }

    /// Earliest first, end to end from 0 to 1. Empty for a trip with no length.
    let blocks: [Block]

    init(tripMap: TripMap, clock: TripReplayClock) {
        guard clock.replayDuration > 0 else {
            blocks = []
            return
        }
        let span = tripMap.span
        let moving = tripMap.legs.filter { $0.end > $0.start }
        let waits = tripMap.waits
        let cuts = Set(([span.start, span.end] + moving.flatMap { [$0.start, $0.end] })
            .filter { span.start <= $0 && $0 <= span.end }).sorted()
        var parts: [(kind: TripActivity.Kind, start: Date, end: Date)] = []
        for (from, to) in zip(cuts, cuts.dropFirst()) {
            let kind = Self.kind(from: from, to: to, moving: moving, waits: waits)
            if let last = parts.last, last.kind == kind {
                parts[parts.count - 1].end = to
            } else {
                parts.append((kind, from, to))
            }
        }
        blocks = parts.map { part in
            Block(kind: part.kind, start: clock.progress(at: part.start), end: clock.progress(at: part.end),
                  label: part.kind.isMoving ? nil : Self.lengthLabel(for: part.end.timeIntervalSince(part.start)))
        }
    }

    /// A wait's length on its block (design §4.1): whole hours under 48, whole days from 48, each to the nearest, halves
    /// up; nil when it rounds to no hours. The shared cases are `waitLabels` in
    /// CrewluvTests/Fixtures/TripMap/replay-cases.json.
    static func lengthLabel(for duration: TimeInterval) -> String? {
        let hours = Int((duration / 3600).rounded())
        guard hours > 0 else { return nil }
        guard hours >= 48 else { return "\(hours)h" }
        return "\(Int((duration / 86_400).rounded()))d"
    }

    /// Flying where any flight moves, else driving where a drive does, else the wait's kind.
    private static func kind(from: Date, to: Date, moving: [MapLeg], waits: [TripWait]) -> TripActivity.Kind {
        let covering = moving.filter { $0.start <= from && to <= $0.end }
        if covering.contains(where: { $0.kind == .flight }) { return .flying }
        if !covering.isEmpty { return .driving }
        // A stretch no moving leg covers is inside one of the map's waits.
        return waits.first { $0.start <= from && to <= $0.end }?.kind ?? .turn
    }
}
```

- [ ] **Step 4: Write the track.** Create `Crewluv/Views/TripMap/TripTimelineTrack.swift`:

```swift
//
//  TripTimelineTrack.swift
//  CrewLuve
//
//  Where a point of the timeline sits across the bar, and back (activity markers design §4.1). The thumb's centre
//  travels between the bar's ends, inset by half the thumb as a slider's is. The blocks are laid along that travel, and
//  the first and last reach the bar's rounded ends.
//

import CoreGraphics

nonisolated struct TripTimelineTrack {
    let width: CGFloat
    /// Half the thumb: how far in from each end its centre stops.
    let inset: CGFloat

    /// The x of `progress`, 0...1, along the bar.
    func x(at progress: Double) -> CGFloat {
        inset + CGFloat(min(max(progress, 0), 1)) * travel
    }

    /// The point of the timeline at `x`, 0...1.
    func progress(atX x: CGFloat) -> Double {
        guard travel > 0 else { return 0 }
        return Double(min(max((x - inset) / travel, 0), 1))
    }

    /// Where a block from `start` to `end` begins and ends across the bar. The first block starts at the bar's leading
    /// end, and the last ends at its trailing end.
    func blockEdges(from start: Double, to end: Double) -> (leading: CGFloat, trailing: CGFloat) {
        (start <= 0 ? 0 : x(at: start), end >= 1 ? width : x(at: end))
    }

    private var travel: CGFloat { max(width - 2 * inset, 0) }
}
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `TripTimelineTests` and `TripTimelineTrackTests`. Expected: 7 tests and 4 tests, 0 failures.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): the timeline's blocks in replay time, colored by what the pilot is doing, with each wait's length`.

**Batch A review:** dispatch `superpowers:code-reviewer` (sonnet) on Tasks 2–6. Give it the design (`docs/superpowers/specs/2026-11-14-trip-map-activity-markers-and-quick-layovers-design.md`), this plan's Design section, the two JSON files and the new and changed files. Ask it to check:
- `TripMap+Activity` follows design §2.2 exactly: the overlap, the tie to the earlier, the 8 hours, before the first departure and from the last arrival.
- The clock's quick rate is the design's `min(L ÷ 1,800, max(3, L ÷ 86,400))` seconds, a clock with no waits or with Quick layovers off paces as before, and `setQuickLayovers` keeps the moment.
- Three cases from each JSON file, chosen at random, recomputed by hand from their notes.
- `TripTimeline`: a flight over a drive is flying, neighbors merge, and labels are only on waits.
- Every pure type, nested type and extension is `nonisolated`, and each file imports what its members need.
- No `Int(...)` of a number that isn't finite, and no divide by zero (`progress(at:)`, `progress(atX:)`).

Handle what it finds as Task 11 says. Then Todd runs everything (⌘U, as in the ground rules). Expected: no failures, and the new classes `TripActivityTests` (5), `TripMapActivityTests` (13), `TripReplayClockPaceTests` (14), `TripTimelineTests` (7) and `TripTimelineTrackTests` (4). `TripMapWordingTests` has 24 (it had 20).

---

### Task 7: The pilot's marker

`TripMapDrawing.pin` and `TripMapMarker.heart` go, so their users change together. The marker keeps one name, `pilot`, as its kind changes: MapKit keeps the one annotation, and the coordinator already refreshes a marker's view when the marker changes in place.

**Files:**
- Modify: `Crewluv/Services/TripMap/TripMapDrawing.swift`
- Rewrite: `Crewluv/Views/TripMap/TripMapMarker.swift`
- Modify: `Crewluv/Views/TripMap/TripMapMarkers.swift`
- Rewrite: `Crewluv/Views/TripMap/TripMapMarkerView.swift`
- Modify: `Crewluv/Views/TripMap/TripMapAnnotationView.swift`
- Modify: `Crewluv/Views/TripMap/TripMapAnnotation.swift`
- Modify: `Crewluv/Views/TripMap/TripMapCard.swift`
- Test: `CrewluvTests/TripMapMarkerTests.swift`
- Test: `CrewluvTests/TripMapDrawingTests.swift`
- Test: `CrewluvTests/TripMapStatusTests.swift`

- [ ] **Step 1: Write the failing tests.** Replace the whole of `CrewluvTests/TripMapMarkerTests.swift` with:

```swift
//
//  TripMapMarkerTests.swift
//  CrewluvTests
//
//  Which markers the trip map shows at an instant, by names that stay the same while each is on the map (moving map
//  spec §5.1, §7.2), with the pilot's marker showing what they're doing (activity markers design §2).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapMarkerTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    private func markers(_ map: TripMap, at hour: Double, palette: TripMapPalette = .onDarkMap) -> [String: TripMapMarker.Placement] {
        TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: hours(hour)), palette: palette)
    }

    func test_placements_inFlight_areTheAirportsAndThePlane() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(4))
        let placements = TripMapMarker.placements(for: drawing, palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-CGN", "airport-DXB", "plane"])
        let plane = try XCTUnwrap(drawing.plane)
        XCTAssertEqual(placements["plane"]?.marker, .plane(angle: plane.angle))
        XCTAssertEqual(placements["plane"]?.coordinate.latitude ?? 0, plane.coordinate.latitude, accuracy: 1e-12)
    }

    func test_placements_onTheLayover_putTheLayoverMarkerOnCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let placements = markers(map, at: 12)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-CGN", "airport-DXB", "pilot"])
        let cgn = try XCTUnwrap(TripMapTestLegs.coordinate("CGN"))
        XCTAssertEqual(placements["pilot"]?.marker, .pilot(.layover))
        XCTAssertEqual(placements["pilot"]?.coordinate.latitude ?? 0, cgn.latitude, accuracy: 1e-12)
    }

    func test_placements_beforeANextTrip_putTheHomeMarkerAtHome() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: hours(-48)))
        let sdf = try XCTUnwrap(TripMapTestLegs.coordinate("SDF"))
        let pilot = try XCTUnwrap(markers(map, at: -48)["pilot"])
        XCTAssertEqual(pilot.marker, .pilot(.home))
        XCTAssertEqual(pilot.coordinate.latitude, sdf.latitude, accuracy: 1e-12)
    }

    func test_placements_pilot_keepsItsNameAsWhatTheyreDoingChanges() throws {
        // On the layover in Cologne, then home after the trip: one marker by one name, so MapKit keeps its annotation
        // and the coordinator refreshes its view.
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        XCTAssertEqual(markers(map, at: 12)["pilot"]?.marker, .pilot(.layover))
        XCTAssertEqual(markers(map, at: 80)["pilot"]?.marker, .pilot(.home))
    }

    func test_placements_drive_nameTheCarByItsDrive() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(-1)))
        XCTAssertEqual(markers(map, at: -1)["d1-car"]?.marker, .car)
    }

    func test_placements_airport_carriesTheMapsPalette() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let placements = markers(map, at: 12, palette: .onLightMap)
        XCTAssertEqual(placements["airport-CGN"]?.marker, .airport(code: "CGN", palette: .onLightMap))
        XCTAssertNotEqual(placements["airport-CGN"]?.marker, .airport(code: "CGN", palette: .onDarkMap))
    }
}
```

In `CrewluvTests/TripMapDrawingTests.swift`, make three replacements. Replace:

```swift
        XCTAssertNil(drawing.pin, "the plane shows where they are")
```

with:

```swift
        XCTAssertNil(drawing.pilot, "the plane shows where they are")
```

Replace:

```swift
    func test_init_onTheLayover_greysTheFlownLegAndPinsCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(12))
        XCTAssertEqual(styles(drawing), ["f1-flown": .flown, "f2-upcoming": .upcoming, "f3-upcoming": .upcoming])
        XCTAssertNil(drawing.plane)
        XCTAssertEqual(drawing.pin?.code, "CGN")
    }
```

with:

```swift
    func test_init_onTheLayover_greysTheFlownLegAndPutsThePilotOnALayoverInCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(12))
        XCTAssertEqual(styles(drawing), ["f1-flown": .flown, "f2-upcoming": .upcoming, "f3-upcoming": .upcoming])
        XCTAssertNil(drawing.plane)
        XCTAssertEqual(drawing.pilot?.place.code, "CGN")
        XCTAssertEqual(drawing.pilot?.kind, .layover)
    }
```

Replace:

```swift
        XCTAssertEqual(car.coordinate.longitude, middle.longitude, accuracy: 1e-9, "parked halfway when not driving")
    }
}
```

with:

```swift
        XCTAssertEqual(car.coordinate.longitude, middle.longitude, accuracy: 1e-9, "parked halfway when not driving")
    }

    func test_init_whileDriving_hasNoGroundMarker() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(1)))
        XCTAssertNil(TripMapDrawing(tripMap: map, at: hours(1)).pilot, "the car shows where they are")
    }
}
```

In `CrewluvTests/TripMapStatusTests.swift`, replace:

```swift
        #expect(map.pilotLocation(at: hours(36))?.code == "SDF", "the heart sits at home, where the last leg landed")
```

with:

```swift
        #expect(map.pilotLocation(at: hours(36))?.code == "SDF", "the pilot is at home, where the last leg landed")
```

- [ ] **Step 2: Run them, expecting a build failure** (`.pilot` and `drawing.pilot` don't exist). Todd runs `TripMapMarkerTests`.

- [ ] **Step 3: The drawing carries the activity.** In `Crewluv/Services/TripMap/TripMapDrawing.swift`, replace:

```swift
    let plane: PlaneMark?
    /// The heart: where the pilot is when nothing is moving.
    let pin: AirportMark?
```

with:

```swift
    let plane: PlaneMark?
    /// What the pilot is doing on the ground, and where (activity markers design §2): nil while a leg moves, when the
    /// plane or the car shows them.
    let pilot: TripActivity?
```

Then replace:

```swift
        self.pin = tripMap.pilotLocation(at: date)
```

with:

```swift
        self.pilot = tripMap.activity(at: date).flatMap { $0.kind.isMoving ? nil : $0 }
```

- [ ] **Step 4: The marker.** Replace the whole of `Crewluv/Views/TripMap/TripMapMarker.swift` with:

```swift
//
//  TripMapMarker.swift
//  CrewLuve
//
//  What each of the trip map's markers shows (moving map spec §5.1, §7.2; activity markers design §2), and which
//  markers a drawing has, by names that stay the same while a marker is on the map, so MapKit moves a marker instead of
//  replacing it.
//

import CoreLocation

nonisolated enum TripMapMarker: Equatable {
    /// An airport's dot, with its code under it.
    case airport(code: String, palette: TripMapPalette)
    /// A drive's car.
    case car
    /// Where the pilot is on the ground, showing what they're doing there: a layover, a turn, base or home.
    case pilot(TripActivity.Kind)
    /// The schedule's plane, pointing at `angle` (`PlaneHeading`).
    case plane(angle: Double)

    /// One marker, and where it goes.
    nonisolated struct Placement {
        let coordinate: CLLocationCoordinate2D
        let marker: TripMapMarker
    }

    /// Markers the same size share a key: a marker's view is measured again only when its key changes. Every kind of
    /// the pilot's marker is the same size.
    var sizeKey: String {
        switch self {
        case .airport(let code, _): "airport-\(code)"
        case .car: "car"
        case .pilot: "pilot"
        case .plane: "plane"
        }
    }

    /// Every marker `drawing` shows, by name: each airport by its code, each car by its drive's own id, and the
    /// pilot's marker and the plane by themselves. The pilot's marker keeps its name as its kind changes.
    static func placements(for drawing: TripMapDrawing, palette: TripMapPalette) -> [String: Placement] {
        var placements: [String: Placement] = [:]
        for airport in drawing.airports {
            placements["airport-\(airport.code)"] = Placement(coordinate: airport.coordinate,
                                                              marker: .airport(code: airport.code, palette: palette))
        }
        for car in drawing.cars {
            placements[car.id] = Placement(coordinate: car.coordinate, marker: .car)
        }
        if let pilot = drawing.pilot {
            placements["pilot"] = Placement(coordinate: pilot.place.coordinate, marker: .pilot(pilot.kind))
        }
        if let plane = drawing.plane {
            placements["plane"] = Placement(coordinate: plane.coordinate, marker: .plane(angle: plane.angle))
        }
        return placements
    }
}
```

- [ ] **Step 5: The marker's look.** In `Crewluv/Views/TripMap/TripMapMarkers.swift`, replace:

```swift
    /// Where the pilot is.
    struct Heart: View {
        var body: some View {
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.pink))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .accessibilityHidden(true)
        }
    }
```

with:

```swift
    /// Where the pilot is on the ground, and what they're doing there (activity markers design §2.1): a white symbol on
    /// the activity's color, with a white ring, in the heart's size and style.
    struct Pilot: View {
        let kind: TripActivity.Kind

        var body: some View {
            Image(systemName: kind.symbolName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(kind.color))
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .accessibilityHidden(true)
        }
    }
```

Replace the whole of `Crewluv/Views/TripMap/TripMapMarkerView.swift` with:

```swift
//
//  TripMapMarkerView.swift
//  CrewLuve
//
//  A trip map marker's SwiftUI view, by kind, for `TripMapAnnotationView` to host.
//

import SwiftUI

struct TripMapMarkerView: View {
    let marker: TripMapMarker

    var body: some View {
        switch marker {
        case .airport(let code, let palette):
            TripMapMarkers.AirportLabel(code: code, palette: palette)
        case .car:
            TripMapMarkers.Car()
        case .pilot(let kind):
            TripMapMarkers.Pilot(kind: kind)
        case .plane(let angle):
            PlaneMarker(angle: angle)
        }
    }
}
```

- [ ] **Step 6: Place it as the heart was.** In `Crewluv/Views/TripMap/TripMapAnnotationView.swift`, replace:

```swift
    /// Where the view's centre sits from its coordinate. The airport's dot sits on the airport with its code below;
    /// the heart stands on its place, as SwiftUI's bottom anchor had it.
    private static func centerOffset(of marker: TripMapMarker, size: CGSize) -> CGPoint {
        switch marker {
        case .airport: CGPoint(x: 0, y: size.height / 2 - TripMapMarkers.Airport.dotDiameter / 2)
        case .heart: CGPoint(x: 0, y: -size.height / 2)
        case .car, .plane: .zero
        }
    }

    /// The plane on top, then the heart, the cars and the airports.
    private static func zPriority(of marker: TripMapMarker) -> MKAnnotationViewZPriority {
        switch marker {
        case .plane: .max
        case .heart: MKAnnotationViewZPriority(rawValue: 900)
```

with:

```swift
    /// Where the view's centre sits from its coordinate. The airport's dot sits on the airport with its code below;
    /// the pilot's marker stands on its place, as the heart did.
    private static func centerOffset(of marker: TripMapMarker, size: CGSize) -> CGPoint {
        switch marker {
        case .airport: CGPoint(x: 0, y: size.height / 2 - TripMapMarkers.Airport.dotDiameter / 2)
        case .pilot: CGPoint(x: 0, y: -size.height / 2)
        case .car, .plane: .zero
        }
    }

    /// The plane on top, then the pilot's marker, the cars and the airports.
    private static func zPriority(of marker: TripMapMarker) -> MKAnnotationViewZPriority {
        switch marker {
        case .plane: .max
        case .pilot: MKAnnotationViewZPriority(rawValue: 900)
```

In `Crewluv/Views/TripMap/TripMapAnnotation.swift`, replace:

```swift
//  One marker on the trip map as MapKit holds it: an airport, a car, the heart or the plane. Its coordinate is
//  observable, so MapKit moves the marker's view when the coordinator moves it.
```

with:

```swift
//  One marker on the trip map as MapKit holds it: an airport, a car, the pilot's marker or the plane. Its coordinate is
//  observable, so MapKit moves the marker's view when the coordinator moves it.
```

In `Crewluv/Views/TripMap/TripMapCard.swift`, replace:

```swift
//  The trip map on the status screen (moving map spec §5, Stage 2 spec §6.4, §6.5). In flight it follows the plane,
//  with the headline fact on its chip; on the ground it shows the whole trip with a heart where the pilot is; at home,
//  the next trip, or for a day after a trip, its recap. Tapping the map opens it full screen.
```

with:

```swift
//  The trip map on the status screen (moving map spec §5, Stage 2 spec §6.4, §6.5). In flight it follows the plane,
//  with the headline fact on its chip; on the ground it shows the whole trip with a marker for what the pilot is doing
//  where they are (activity markers design §2); at home, the next trip, or for a day after a trip, its recap. Tapping
//  the map opens it full screen.
```

- [ ] **Step 7: Check nothing still names what went.**

```bash
cd /Users/toddanderson/Dev/Crewluv && grep -rnE "case heart|\.heart[^a-zA-Z.]|Heart\(\)|drawing\.pin|let pin" Crewluv/Views/TripMap Crewluv/Services/TripMap CrewluvTests
```

Expected: no lines. Any line is a leftover: fix it.

- [ ] **Step 8: Todd builds and runs the tests.** Todd presses ⌘B, then runs `TripMapMarkerTests` and `TripMapDrawingTests`. Expected: the build succeeds; `TripMapMarkerTests` 6 tests (it had 4) and `TripMapDrawingTests` 6 tests (it had 5), 0 failures.

- [ ] **Step 9: Ask to commit.** Suggested message: `feat(crewluv): the trip map's heart becomes a marker for what the pilot is doing: a layover, a turn, base or home`.

---

### Task 8: The bar

Two new views. Nothing uses them until Task 9, and Todd builds at its end.

**Files:**
- Create: `Crewluv/Views/TripMap/TripTimelineBlocks.swift`
- Create: `Crewluv/Views/TripMap/TripTimelineBar.swift`

- [ ] **Step 1: Write the blocks.** Create `Crewluv/Views/TripMap/TripTimelineBlocks.swift`:

```swift
//
//  TripTimelineBlocks.swift
//  CrewLuve
//
//  The timeline bar's colored blocks (activity markers design §4.1): flying blue, driving gray, and each wait in its
//  marker's color, in full color up to the thumb and paler ahead. A wait's length is written on its block when it fits
//  at the current text size. Drawn on every tick of a replay, so it's one `Canvas`.
//

import CoreGraphics
import SwiftUI

struct TripTimelineBlocks: View {
    let blocks: [TripTimeline.Block]
    /// Where the replay is, 0...1.
    let progress: Double
    /// Half the thumb: the bar lays its blocks along the thumb's travel (`TripTimelineTrack`).
    let inset: CGFloat

    /// The share of its color a block keeps ahead of the replay.
    private static let aheadOpacity = 0.35
    /// The least room each side of a length inside its block.
    private static let labelPadding: CGFloat = 3
    /// How far each block runs under the next, so no seam shows between them.
    private static let seamOverlap: CGFloat = 0.5

    var body: some View {
        Canvas { context, size in
            let track = TripTimelineTrack(width: size.width, inset: inset)
            let rects = blocks.map { block in
                let edges = track.blockEdges(from: block.start, to: block.end)
                return CGRect(x: edges.leading, y: 0, width: max(0, edges.trailing - edges.leading), height: size.height)
            }
            // Ahead: paler, as one layer, so the blocks' overlaps don't darken. Lengths in the text color.
            context.drawLayer { ahead in
                ahead.opacity = Self.aheadOpacity
                fill(rects, in: ahead)
            }
            writeLengths(in: rects, on: context, color: .primary)
            // Played: full color up to the thumb, with white lengths.
            var played = context
            played.clip(to: Path(CGRect(x: 0, y: 0, width: track.x(at: progress), height: size.height)))
            fill(rects, in: played)
            writeLengths(in: rects, on: played, color: .white)
        }
        .accessibilityHidden(true)
    }

    private func fill(_ rects: [CGRect], in context: GraphicsContext) {
        for (block, rect) in zip(blocks, rects) {
            let overlapping = CGRect(x: rect.minX, y: rect.minY, width: rect.width + Self.seamOverlap, height: rect.height)
            context.fill(Path(overlapping), with: .color(block.kind.color))
        }
    }

    /// Writes each wait's length in the middle of its block, when it fits with room to spare each side.
    private func writeLengths(in rects: [CGRect], on context: GraphicsContext, color: Color) {
        for (block, rect) in zip(blocks, rects) {
            guard let length = block.label else { continue }
            let text = context.resolve(Text(length).font(.caption2.weight(.semibold)).foregroundStyle(color))
            let size = text.measure(in: CGSize(width: CGFloat.infinity, height: CGFloat.infinity))
            guard size.width + 2 * Self.labelPadding <= rect.width, size.height <= rect.height else { continue }
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}
```

- [ ] **Step 2: Write the bar.** Create `Crewluv/Views/TripMap/TripTimelineBar.swift`:

```swift
//
//  TripTimelineBar.swift
//  CrewLuve
//
//  The timeline's bar (activity markers design §4.1, §4.3): the blocks, played and ahead, with a thumb where the replay
//  is. It's drawn by the app rather than `Slider`, so it can be colored by part. A drag moves through the trip in the
//  bar's measure, and VoiceOver reads and adjusts it as a slider. Its height is the same at every text size.
//

import SwiftUI

struct TripTimelineBar: View {
    let timeline: TripTimeline
    /// Where the replay is, 0...1.
    let progress: Double
    /// VoiceOver's value: "Saturday 1:40 PM, layover in Denver".
    let spokenValue: String
    /// Moves the replay to a point along the bar, 0...1.
    let onScrub: (Double) -> Void

    private static let barHeight: CGFloat = 24
    private static let thumbDiameter: CGFloat = 28
    /// The least touch target.
    private static let touchHeight: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            let track = TripTimelineTrack(width: proxy.size.width, inset: Self.thumbDiameter / 2)
            ZStack(alignment: .leading) {
                TripTimelineBlocks(blocks: timeline.blocks, progress: progress, inset: track.inset)
                    .frame(height: Self.barHeight)
                    .clipShape(.capsule)
                thumb
                    .offset(x: track.x(at: progress) - track.inset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { onScrub(track.progress(atX: $0.location.x)) })
        }
        .frame(height: Self.touchHeight)
        .accessibilityRepresentation {
            Slider(value: Binding(get: { progress }, set: onScrub), in: 0...1)
                .accessibilityLabel("Trip time")
                .accessibilityValue(spokenValue)
        }
    }

    private var thumb: some View {
        Circle()
            .fill(.white)
            .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .frame(width: Self.thumbDiameter, height: Self.thumbDiameter)
    }
}
```

- [ ] **Step 3: Nothing to run yet.** Todd builds at the end of Task 9.

---

### Task 9: The timeline, the sheet, the panel and the screen

These build together: `FactsHeader` and `TripTimelineControl` take new inputs, so their callers change in the same build.

**Files:**
- Rewrite: `Crewluv/Views/TripMap/TripTimelineControl.swift`
- Rewrite: `Crewluv/Views/TripMap/FactsHeader.swift`
- Modify: `Crewluv/Views/TripMap/FactsSheet.swift`
- Rewrite: `Crewluv/Views/TripMap/FactsPanel.swift`
- Rewrite: `Crewluv/Views/TripMap/TripMapScreen.swift`
- Rewrite: `Crewluv/Views/TripMap/TripMapPreviews.swift`

- [ ] **Step 1: The control.** Replace the whole of `Crewluv/Views/TripMap/TripTimelineControl.swift` with the following. Against today's version: the bar replaces the `Slider`, the line under it replaces the time, and the switch joins the speeds. The play button, Live and the speeds are unchanged.

```swift
//
//  TripTimelineControl.swift
//  CrewLuve
//
//  Play, drag through the trip, go back to Live, pick 1x to 10x, and hurry through waits on the ground (moving map
//  spec §6; activity markers design §3.1, §4). The bar measures replay time and is colored by what the pilot is doing;
//  the line under it says when and what.
//

import SwiftUI

struct TripTimelineControl: View {
    @Binding var clock: TripReplayClock
    @Binding var isQuickLayovers: Bool
    /// The bar's blocks, at the clock's pace.
    let timeline: TripTimeline
    /// What the pilot is doing at `time`.
    let activity: TripActivity?
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                playButton
                TripTimelineBar(timeline: timeline, progress: clock.progress(at: time),
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity),
                                onScrub: scrub(to:))
                if !clock.isLive {
                    Button("Live") { clock.goLive() }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Shows where things are now")
                }
            }
            Text(TripMapWording.timelineLine(time, activity: activity))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                // The bar's VoiceOver value says the same.
                .accessibilityHidden(true)
            paceControls
        }
    }

    /// Quick layovers beside the speeds, or above them when the two don't fit on one line.
    private var paceControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                quickLayoversToggle
                    .fixedSize()
                Spacer(minLength: 0)
                speedPicker
            }
            VStack(alignment: .leading, spacing: 8) {
                quickLayoversToggle
                speedPicker
            }
        }
    }

    private var quickLayoversToggle: some View {
        Toggle("Quick layovers", isOn: $isQuickLayovers)
            .font(.subheadline)
            .accessibilityHint("Plays the time on the ground faster")
    }

    /// A segmented control, or a menu at the largest text sizes where four segments won't fit.
    @ViewBuilder
    private var speedPicker: some View {
        let picker = Picker("Replay speed", selection: speed) {
            ForEach(TripReplayClock.Speed.allCases) { speed in
                Text("\(speed.rawValue)×").tag(speed)
            }
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu)
        } else {
            picker.pickerStyle(.segmented).fixedSize()
        }
    }

    private var isShowingPause: Bool {
        clock.isPlaying && !clock.hasFinished(at: now)
    }

    private var playButton: some View {
        Button {
            if isShowingPause { clock.pause(at: .now) } else { clock.play(at: .now) }
        } label: {
            Image(systemName: isShowingPause ? "pause.fill" : "play.fill")
                .imageScale(.large)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
        }
        .accessibilityLabel(isShowingPause ? "Pause replay" : "Replay the trip")
    }

    /// Moves the replay to `progress` along the bar, paused there.
    private func scrub(to progress: Double) {
        clock.scrub(to: clock.tripTime(atProgress: progress))
    }

    private var speed: Binding<TripReplayClock.Speed> {
        Binding(get: { clock.speed }, set: { clock.setSpeed($0, at: .now) })
    }
}
```

- [ ] **Step 2: The sheet's header.** Replace the whole of `Crewluv/Views/TripMap/FactsHeader.swift` with:

```swift
//
//  FactsHeader.swift
//  CrewLuve
//
//  The top of the iPhone sheet, all its small stop shows (Stage 2 spec §6.1): the headline and the timeline.
//

import SwiftUI

struct FactsHeader: View {
    let headline: String
    /// The timeline bar's blocks, at the clock's pace.
    let timeline: TripTimeline
    /// What the pilot is doing at `time`.
    let activity: TripActivity?
    @Binding var clock: TripReplayClock
    @Binding var isQuickLayovers: Bool
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headline)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            TripTimelineControl(clock: $clock, isQuickLayovers: $isQuickLayovers, timeline: timeline,
                                activity: activity, time: time, now: now)
        }
    }
}
```

- [ ] **Step 3: The sheet.** In `Crewluv/Views/TripMap/FactsSheet.swift`, replace:

```swift
    let facts: TripFacts
    @Binding var clock: TripReplayClock
    @Binding var stop: Stop
```

with:

```swift
    let facts: TripFacts
    /// The timeline bar's blocks, at the clock's pace.
    let timeline: TripTimeline
    @Binding var clock: TripReplayClock
    @Binding var isQuickLayovers: Bool
    @Binding var stop: Stop
```

Then replace:

```swift
        // Its own clock: a sheet is a separate presentation from the map under it.
        TimelineView(.periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1)) { context in
            let time = clock.time(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FactsHeader(headline: facts.sheetHeadline(at: time), clock: $clock, time: time, now: context.date)
```

with:

```swift
        // Its own clock: a sheet is a separate presentation from the map under it. Up to 60 times a second during a
        // replay, as the map, so the bar's thumb moves as smoothly.
        TimelineView(.animation(minimumInterval: clock.isPlaying ? 1.0 / 60 : 1)) { context in
            let time = clock.time(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FactsHeader(headline: facts.sheetHeadline(at: time), timeline: timeline,
                                activity: facts.tripMap.activity(at: time), clock: $clock,
                                isQuickLayovers: $isQuickLayovers, time: time, now: context.date)
```

- [ ] **Step 4: The panel.** Replace the whole of `Crewluv/Views/TripMap/FactsPanel.swift` with the following. Against today's version: `timeline` and `isQuickLayovers` are new, and the control's view is renamed `timelineControl`, since `timeline` is now the blocks.

```swift
//
//  FactsPanel.swift
//  CrewLuve
//
//  The facts on iPad and in landscape (Stage 2 spec §6.2): a panel down the leading edge. Its rows scroll between the
//  headline and the timeline, and the chevron folds it down to just those two. At the largest text sizes all of it
//  scrolls together.
//

import SwiftUI

struct FactsPanel: View {
    let facts: TripFacts
    /// The timeline bar's blocks, at the clock's pace.
    let timeline: TripTimeline
    @Binding var clock: TripReplayClock
    @Binding var isQuickLayovers: Bool
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        content
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // The headline and the timeline alone can be taller than a landscape screen, so all of it scrolls.
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if isExpanded { factsBody }
                    timelineControl
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                if isExpanded {
                    ScrollView { factsBody }
                        .frame(maxHeight: .infinity)
                }
                timelineControl
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(facts.sheetHeadline(at: time))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button(action: toggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(isExpanded ? "Hide facts" : "Show facts")
        }
    }

    private var factsBody: some View {
        FactsBody(rows: facts.rows(at: time, now: now), tripSoFar: facts.tripSoFar(at: time))
    }

    private var timelineControl: some View {
        TripTimelineControl(clock: $clock, isQuickLayovers: $isQuickLayovers, timeline: timeline,
                            activity: facts.tripMap.activity(at: time), time: time, now: now)
    }

    private func toggle() {
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.snappy) { isExpanded.toggle() }
        }
    }
}
```

- [ ] **Step 5: The screen.** Replace the whole of `Crewluv/Views/TripMap/TripMapScreen.swift` with the following. Against `6a2ecaf`'s version, checked in Task 1, the only changes are:
- `quickLayoversKey` and `@AppStorage` `isQuickLayovers`;
- the clock is made with the map's waits and Quick layovers (`clock(for:isQuickLayovers:)`), and switches pace in `onChange(of: isQuickLayovers, initial: true)`;
- `body` makes the timeline's blocks once per update, and passes them and the switch to the sheet and the panel;
- the `TimelineView` moves into `content(facts:timeline:)`, runs on `.animation(minimumInterval:)` at 1/60 s while playing and 1 s otherwise, and pauses a finished replay at its end.

```swift
//
//  TripMapScreen.swift
//  CrewLuve
//
//  The full-screen trip map (moving map spec §6, Stage 2 spec §6): pan and zoom, change the style, replay the trip and
//  read its facts. On iPhone the facts are a sheet you drag up; on iPad and in landscape, a panel down the leading
//  edge. A recap opens paused at its trip's start. Weather on landing is fetched while the screen is open. Quick
//  layovers, remembered for every trip, hurries a replay through the waits on the ground (activity markers design §3).
//

import SwiftUI

struct TripMapScreen: View {
    /// Where Quick layovers is remembered. It's on until the family turns it off (activity markers design §3.1).
    static let quickLayoversKey = "tripMapQuickLayovers"

    let tripMap: TripMap
    let storyStore: LegStoryStore
    let dayNumber: Int?
    let totalDays: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(TripMapScreen.quickLayoversKey) private var isQuickLayovers = true
    @State private var clock: TripReplayClock
    @State private var style: TripMapStyle = .hybrid
    @State private var camera: TripMapCamera
    @State private var weather = LandingWeather()
    @State private var sheetStop: FactsSheet.Stop = .small
    /// How far up the screen the sheet reaches.
    @State private var sheetHeight: CGFloat = 0
    /// The map's frame, the whole screen, in window coordinates.
    @State private var screenFrame: CGRect = .zero
    /// The side panel's trailing edge, in window coordinates.
    @State private var panelTrailingEdge: CGFloat = 0
    @State private var topBarHeight: CGFloat = 0
    @State private var isPanelExpanded = true
    @State private var isClosing = false

    private static let panelWidth: CGFloat = 380

    init(tripMap: TripMap, storyStore: LegStoryStore, dayNumber: Int?, totalDays: Int?) {
        self.tripMap = tripMap
        self.storyStore = storyStore
        self.dayNumber = dayNumber
        self.totalDays = totalDays
        // The remembered setting, read from the defaults `@AppStorage` uses, since the property can't be read yet.
        // `onChange(of: isQuickLayovers, initial: true)` keeps the clock in step with it from then on.
        let rememberedQuickLayovers = UserDefaults.standard.object(forKey: Self.quickLayoversKey) as? Bool ?? true
        _clock = State(initialValue: Self.clock(for: tripMap, isQuickLayovers: rememberedQuickLayovers))
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg)))
    }

    var body: some View {
        // Once per update, not per frame: the facts change as their stories and forecasts arrive, and the timeline's
        // blocks as the clock's pace does.
        let facts = self.facts
        let timeline = TripTimeline(tripMap: tripMap, clock: clock)
        content(facts: facts, timeline: timeline)
            .sheet(isPresented: isShowingSheet, onDismiss: finishClosing) {
                FactsSheet(facts: facts, timeline: timeline, clock: $clock, isQuickLayovers: $isQuickLayovers,
                           stop: $sheetStop, screenHeight: screenFrame.height, height: $sheetHeight)
            }
            // Both start again when a flight's route or times change, so a new delay fetches the new landing hour.
            .task(id: LegStoryStore.preparationKey(for: tripMap)) { await storyStore.prepare(tripMap) }
            .task(id: LegStoryStore.preparationKey(for: tripMap)) { await weather.keepRefreshing(for: tripMap) }
            .task(id: isClosing) {
                // Should the sheet never report going, as when Close comes while it's still sliding up, the map closes anyway.
                guard isClosing, (try? await Task.sleep(for: .seconds(1))) != nil else { return }
                dismiss()
            }
            .onChange(of: usesSidePanel) { _, isSidePanel in
                if !isSidePanel { sheetStop = .small }
            }
            .onChange(of: Self.replayLegs(of: tripMap)) {
                // A new schedule, such as a delay, gives the timeline new ends and a new pace.
                clock = Self.clock(for: tripMap, isQuickLayovers: isQuickLayovers)
            }
            .onChange(of: isQuickLayovers, initial: true) { _, isOn in
                // The replay carries on from the same moment at the new pace.
                clock.setQuickLayovers(isOn, at: .now)
            }
    }

    /// The map and its controls: every second live, and up to 60 times a second while a replay runs, so the night
    /// sweeps smoothly through a quick layover. The map draws its night and lines for each tick's time.
    private func content(facts: TripFacts, timeline: TripTimeline) -> some View {
        TimelineView(.animation(minimumInterval: clock.isPlaying ? 1.0 / 60 : 1)) { context in
            let time = clock.time(at: context.date)
            screen(time: time, now: context.date, facts: facts, timeline: timeline)
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID)
                }
                .onChange(of: clock.hasFinished(at: context.date)) { _, hasFinished in
                    // A finished replay holds its end, paused, so the map stops updating with nothing moving. Play
                    // starts it over, as before.
                    if hasFinished { clock.pause(at: .now) }
                }
        }
    }

    /// Live, or for a recap paused at its trip's start. A short leg slows the replay while it moves, and with Quick
    /// layovers on each wait hurries by.
    private static func clock(for tripMap: TripMap, isQuickLayovers: Bool) -> TripReplayClock {
        let legs = replayLegs(of: tripMap)
        let waits = tripMap.waits.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
        return tripMap.mode == .recap
            ? TripReplayClock(span: tripMap.span, legs: legs, waits: waits, isQuickLayovers: isQuickLayovers,
                              pausedAt: tripMap.span.start)
            : TripReplayClock(span: tripMap.span, legs: legs, waits: waits, isQuickLayovers: isQuickLayovers)
    }

    /// Each drive and flight, from its start to its end with any delay.
    private static func replayLegs(of tripMap: TripMap) -> [TripReplayClock.Stretch] {
        tripMap.legs.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
    }

    private var facts: TripFacts {
        storyStore.facts(for: tripMap, forecasts: weather.forecasts, dayNumber: dayNumber, totalDays: totalDays)
    }

    @ViewBuilder
    private func screen(time: Date, now: Date, facts: TripFacts, timeline: TripTimeline) -> some View {
        let base = ZStack(alignment: .top) {
            // The camera frames the trip in what the sheet or the panel leaves clear.
            TripMapView(tripMap: tripMap, date: time, style: style, camera: $camera,
                        clearance: TripMapClearance(leading: mapLeadingClearance, bottom: mapBottomClearance),
                        isFullScreen: true)
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
        }
        if usesSidePanel {
            base.overlay(alignment: .bottomLeading) {
                FactsPanel(facts: facts, timeline: timeline, clock: $clock, isQuickLayovers: $isQuickLayovers,
                           time: time, now: now, isExpanded: $isPanelExpanded)
                    .frame(width: Self.panelWidth)
                    .padding([.horizontal, .bottom])
                    .padding(.top, topBarHeight + 8)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxX } action: { panelTrailingEdge = $0 }
            }
        } else {
            base
        }
    }

    private func topBar(time: Date) -> some View {
        TripMapTopBar(
            pill: TripMapWording.topPill(for: tripMap, at: time, dayNumber: dayNumber, totalDays: totalDays),
            style: style,
            isShowingRecenter: camera.isPositionedByUser,
            onClose: close,
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, force: true) },
            onNextStyle: { style = style.next }
        )
    }

    /// iPad, and iPhone in landscape.
    private var usesSidePanel: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    /// The sheet's height, up to the middle stop: higher, the map is mostly covered and stays framed as it was.
    private var mapBottomClearance: CGFloat {
        usesSidePanel ? 0 : min(sheetHeight, screenFrame.height / 2)
    }

    /// From the screen's leading edge to the panel's trailing edge, open or folded, with its padding.
    private var mapLeadingClearance: CGFloat {
        usesSidePanel ? max(0, panelTrailingEdge - screenFrame.minX) : 0
    }

    /// The sheet shows on iPhone in portrait until Close. The family can't dismiss it themselves.
    private var isShowingSheet: Binding<Bool> {
        Binding(get: { !usesSidePanel && !isClosing }, set: { _ in })
    }

    /// With the sheet up, it goes first and the map follows in `finishClosing`.
    private func close() {
        if usesSidePanel {
            dismiss()
        } else {
            isClosing = true
        }
    }

    private func finishClosing() {
        if isClosing { dismiss() }
    }

    /// Frames the leg in motion, or the whole trip. Leaves a camera the family moved alone, unless they asked.
    private func refit(legID: String?, force: Bool = false) {
        guard force || !camera.isPositionedByUser else { return }
        let leg = legID.flatMap { id in tripMap.legs.first { $0.id == id } }
        camera.frame(tripMap.framingRect(focusingOn: leg), animated: !reduceMotion)
    }
}
```

- [ ] **Step 6: The previews.** Replace the whole of `Crewluv/Views/TripMap/TripMapPreviews.swift` with the following. The Europe trip gains CrewLu's two layovers, so the "Layover" preview shows the bed; "Turn" and "At base" are new; the two full-screen previews set Quick layovers on and off.

```swift
//
//  TripMapPreviews.swift
//  CrewLuve
//
//  The trip map card in each state, around the time the canvas opens: Louisville to Cologne to Dubai and home with
//  CrewLu's layovers, an hour's turn in Cologne, a commuter at base, Anchorage to Tokyo across the date line, and the
//  Europe trip's recap. The full-screen map shows with Quick layovers on and off. Each preview builds its own story
//  store.
//

#if DEBUG
import CoreLocation
import SwiftUI

private enum TripMapPreviewData {

    static func coordinate(_ code: String) -> CLLocationCoordinate2D? {
        AirportDataProvider.shared.airportInfo(forIataCode: code).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    static func flight(_ flightNumber: String, _ from: String, _ to: String, _ fromCity: String, _ toCity: String,
                       start: Date, hours: Double, zone: String, arrivalZone: String) -> TripLeg {
        TripLeg(id: flightNumber, tripId: "P1", type: .flight, startTime: start, endTime: start.addingTimeInterval(hours * 3600),
                airportCode: nil, city: nil, timezoneIdentifier: zone, arrivalTimezoneIdentifier: arrivalZone,
                flightNumber: flightNumber, departureAirport: from, arrivalAirport: to,
                departureCity: fromCity, arrivalCity: toCity, tripDayNumber: nil, tripTotalDays: nil,
                delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// One of CrewLu's ground legs at `code`: a layover, a turn, or a stay at base or home.
    static func ground(_ id: String, _ type: TripLeg.LegType, at code: String, _ city: String,
                       start: Date, hours: Double, zone: String) -> TripLeg {
        TripLeg(id: id, tripId: "P1", type: type, startTime: start, endTime: start.addingTimeInterval(hours * 3600),
                airportCode: code, city: city, timezoneIdentifier: zone, arrivalTimezoneIdentifier: nil,
                flightNumber: nil, departureAirport: nil, arrivalAirport: nil, departureCity: nil, arrivalCity: nil,
                tripDayNumber: nil, tripTotalDays: nil, delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// A commuter's 90-minute drive from Lexington to base in Louisville.
    static func driveToBase(start: Date) -> TripLeg {
        TripLeg(id: "D1", tripId: "P1", type: .drive, startTime: start, endTime: start.addingTimeInterval(1.5 * 3600),
                airportCode: nil, city: nil, timezoneIdentifier: "America/New_York", arrivalTimezoneIdentifier: "America/New_York",
                flightNumber: nil, departureAirport: "LEX", arrivalAirport: "SDF", departureCity: "Lexington", arrivalCity: "Louisville",
                tripDayNumber: nil, tripTotalDays: nil, delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// Louisville to Cologne, a day there, Dubai, 20 hours there, and home, from `start`.
    static func europeLegs(from start: Date) -> [TripLeg] {
        [
            flight("UPS207", "SDF", "CGN", "Louisville", "Cologne", start: start, hours: 8, zone: "America/New_York", arrivalZone: "Europe/Berlin"),
            ground("L1", .layover, at: "CGN", "Cologne", start: start.addingTimeInterval(8 * 3600), hours: 24, zone: "Europe/Berlin"),
            flight("UPS208", "CGN", "DXB", "Cologne", "Dubai", start: start.addingTimeInterval(32 * 3600), hours: 6, zone: "Europe/Berlin", arrivalZone: "Asia/Dubai"),
            ground("L2", .layover, at: "DXB", "Dubai", start: start.addingTimeInterval(38 * 3600), hours: 20, zone: "Asia/Dubai"),
            flight("UPS209", "DXB", "SDF", "Dubai", "Louisville", start: start.addingTimeInterval(58 * 3600), hours: 14, zone: "Asia/Dubai", arrivalZone: "America/New_York"),
        ]
    }

    /// The Europe trip, `hoursIn` hours after its first departure.
    static func europe(hoursIn: Double, isNextTrip: Bool = false, isRecap: Bool = false) -> TripMap? {
        let now = Date()
        return TripMap.make(tripLegs: europeLegs(from: now.addingTimeInterval(-hoursIn * 3600)), isNextTrip: isNextTrip,
                            isRecap: isRecap, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    /// Louisville to Cologne and straight back after an hour's turn, half an hour into the turn.
    static var turn: TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-8.5 * 3600)
        let legs = [
            flight("UPS207", "SDF", "CGN", "Louisville", "Cologne", start: start, hours: 8, zone: "America/New_York", arrivalZone: "Europe/Berlin"),
            ground("T1", .turn, at: "CGN", "Cologne", start: start.addingTimeInterval(8 * 3600), hours: 1, zone: "Europe/Berlin"),
            flight("UPS206", "CGN", "SDF", "Cologne", "Louisville", start: start.addingTimeInterval(9 * 3600), hours: 9, zone: "Europe/Berlin", arrivalZone: "America/New_York"),
        ]
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    /// A commuter who lives in Lexington, at base in Louisville, an hour and a half before the Europe trip.
    static var atBase: TripMap? {
        let now = Date()
        let legs = [driveToBase(start: now.addingTimeInterval(-2 * 3600)),
                    ground("B1", .base, at: "SDF", "Louisville", start: now.addingTimeInterval(-0.5 * 3600), hours: 2, zone: "America/New_York")]
            + europeLegs(from: now.addingTimeInterval(1.5 * 3600))
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "LEX", legacyDelayMinutes: nil, at: now, coordinate: { coordinate($0) })
    }

    static var pacific: TripMap? {
        let start = Date().addingTimeInterval(-3 * 3600)
        let legs = [flight("UPS61", "ANC", "NRT", "Anchorage", "Tokyo", start: start, hours: 8, zone: "America/Anchorage", arrivalZone: "Asia/Tokyo")]
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: Date(), coordinate: { coordinate($0) })
    }

    /// A store with Quick layovers set, so each full-screen preview shows its pace whatever the canvas remembered.
    static func storage(quickLayovers isOn: Bool) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "TripMapPreviews.quickLayovers.\(isOn)") ?? .standard
        defaults.set(isOn, forKey: TripMapScreen.quickLayoversKey)
        return defaults
    }
}

#Preview("In flight") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Layover") {
    if let map = TripMapPreviewData.europe(hoursIn: 12) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Turn") {
    if let map = TripMapPreviewData.turn {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("At base") {
    if let map = TripMapPreviewData.atBase {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Next trip") {
    if let map = TripMapPreviewData.europe(hoursIn: -48, isNextTrip: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Recap") {
    if let map = TripMapPreviewData.europe(hoursIn: 75, isRecap: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Across the date line") {
    if let map = TripMapPreviewData.pacific {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Full screen, in flight, Quick layovers on") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Full screen, recap, Quick layovers off") {
    if let map = TripMapPreviewData.europe(hoursIn: 75, isRecap: true) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: nil, totalDays: nil)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: false))
    }
}
#endif
```

- [ ] **Step 7: Check nothing still calls the old shapes.**

```bash
cd /Users/toddanderson/Dev/Crewluv && grep -rnF -e 'TripTimelineControl(clock: $clock, time:' -e 'FactsHeader(headline: facts.sheetHeadline(at: time), clock:' -e 'periodic(from: .now, by: clock.isPlaying' Crewluv
```

Expected: no lines.

- [ ] **Step 8: Todd builds and looks at the previews.** Todd presses ⌘B. Expected: the build succeeds, with no warnings in this plan's files. Then, in Xcode, open `TripMapPreviews.swift` and look at the canvas. Expected:
  - "Layover": an indigo bed on Cologne. "Turn": an orange hourglass on Cologne. "At base": a teal briefcase on Louisville, and the car parked halfway from Lexington. "Next trip" and "Recap": a green house on Louisville.
  - No heart anywhere.
  - "Full screen, in flight, Quick layovers on": under the map or in the panel, a bar of blue flights with two small indigo layover blocks labelled "24h" and "20h" where they fit, the thumb a little way along the first flight, "Fri 3:14 PM · Flying to Cologne" style words under it, and the switch on.
  - "Full screen, recap, Quick layovers off": the two layover blocks take about a third and just over a quarter of the bar (48 s and 40 s of 144 s), and the switch is off. Press play in the canvas: the replay crawls through Cologne. Turn the switch on: the map stays on the same moment and hurries on.

- [ ] **Step 9: Todd runs everything** (⌘U, as in the ground rules). Expected: no failures. Since Batch A's run: `TripMapMarkerTests` 6 (it had 4) and `TripMapDrawingTests` 6 (it had 5).

- [ ] **Step 10: Ask to commit Tasks 8 and 9 together.** Suggested message: `feat(crewluv): the trip map's timeline is colored by what the pilot is doing, measured in replay time, with Quick layovers and 60 updates a second during a replay`.

---

### Task 10: The docs

**Files:**
- Modify: `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Amend the moving map spec.** Apply each amendment in the Design section's "Spec amendments": the header, §5.1, §6, §10 (three), §14 (two) and §15.1. Each "Replace" block's text is in the spec as quoted. If one isn't found exactly, STOP: the spec has moved on since this plan.
- §7.1 and §11 still name the heart; the design's §10 doesn't list them, so leave them ("Seen, not fixed").

- [ ] **Step 2: Update `CLAUDE.md`'s Trip Map section.** Replace:

```markdown
- The status screen's map (moving map spec `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`): the whole trip on the ground with a heart where the pilot is, the next trip from home, and the plane in the air. In flight it takes the location card's place; on the ground it sits above it
```

with:

```markdown
- The status screen's map (moving map spec `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`): the whole trip on the ground with a marker for what the pilot is doing where they are, the next trip from home, and the plane in the air. In flight it takes the location card's place; on the ground it sits above it
- What the pilot is doing, and the replay's pace (activity markers design `docs/superpowers/specs/2026-11-14-trip-map-activity-markers-and-quick-layovers-design.md`): a bed on a layover, an hourglass at a turn, a briefcase at base and a house at home (`TripActivity`, `TripMapMarkers.Pilot`). Each wait between moving legs is named by the CrewLu ground leg that overlaps it most (`GroundStop`, `TripWait`, `TripMap+Activity`); with none, 8 hours or more is a layover. Quick layovers (`@AppStorage` `tripMapQuickLayovers`, on by default) hurries a replay through each wait, a second a day and never under 3 s, with the trip's clock still running through it. The timeline is the app's own bar (`TripTimelineBar`, `TripTimeline`), measured in replay time and colored by what the pilot is doing, and VoiceOver reads it as a slider. The full-screen map's `TimelineView` updates up to 60 times a second while a replay plays, and once a second otherwise
```

Then replace:

```markdown
- The logic is `nonisolated` and tested: `TripMap` (which legs, the mode, where the pilot is), `TripMapDrawing` (what to draw at an instant), `TripMapLine` (a route as flat-map points), `TripMapCamera`, `TripMapClearance`, `TripMapMarker`'s placements, `FlightProgress` (the schedule's plane, with taxi allowances), `TripReplayClock`, `TripMapWording`. The maths in `Utils/` (`NightShade`, `PlaneHeading`, `MapFit`, `MapProjection`, `GreatCircle`) came from CrewLu's moving map with its tests
```

with:

```markdown
- The logic is `nonisolated` and tested: `TripMap` (which legs, the mode, where the pilot is), `TripMap+Activity` (what the pilot is doing at any moment), `TripActivity`, `TripMapDrawing` (what to draw at an instant), `TripMapLine` (a route as flat-map points), `TripMapCamera`, `TripMapClearance`, `TripMapMarker`'s placements, `FlightProgress` (the schedule's plane, with taxi allowances), `TripReplayClock` (the pace, Quick layovers, and positions in replay time), `TripTimeline` (the bar's blocks), `TripTimelineTrack`, `TripMapWording`. The maths in `Utils/` (`NightShade`, `PlaneHeading`, `MapFit`, `MapProjection`, `GreatCircle`) came from CrewLu's moving map with its tests
```

Then replace:

```markdown
- `CrewluvTests/Fixtures/TripMap/progress-cases.json` holds the schedule's plane to the same answers as the website: change both copies together
```

with:

```markdown
- `CrewluvTests/Fixtures/TripMap/progress-cases.json` holds the schedule's plane to the same answers as the website, `replay-cases.json` the replay's pace with Quick layovers on and off and the waits' lengths, and `activity-cases.json` what the pilot is doing at any moment: change both copies of each together
```

Change only these three bullets.

- [ ] **Step 3: Ask to commit.** Suggested message: `docs(crewluv): the moving map spec and CLAUDE.md for the activity markers, the colored timeline and Quick layovers`. Stage only these two files. If `git diff` shows edits in either that aren't this task's, ask Todd how he wants them committed first.

---

### Task 11: Code review

**Files:** none change, unless a finding is real.

- [ ] **Step 1: Ask for a review.** Dispatch `superpowers:code-reviewer` with `model: "sonnet"`.
- Give it:
  - the design;
  - this plan's Design section;
  - every file Tasks 7–9 created or changed, and `TripReplayClock.swift` and `TripMap+Activity.swift` for reference.
- Ask it to check:
  - **The marker:** `pilot` keeps its name as its kind changes, so the coordinator refreshes the one annotation's view; the marker stands on its place and sits under the plane; VoiceOver doesn't read it.
  - **The clock on screen:** every path that makes a new clock passes the waits and the switch; switching keeps the moment; a finished replay pauses at its end and Play starts it over; the sheet and the screen share one clock.
  - **Per frame:** what runs on every tick at 60 a second. `TripTimeline` should be made once per update, not per tick; the `Canvas` should resolve and measure each label at most twice a tick.
  - **The bar:** the thumb's centre and the played edge meet at the same x; a drag scrubs and pauses; the `Slider` in `accessibilityRepresentation` reads "Trip time" with the spoken value and adjusts the clock.
  - **Accessibility and Dynamic Type:** the switch has a label and a hint; labels drop out rather than clip; the bar's height is fixed; the switch moves above the speeds when needed.
  - **Dark Mode:** the colors are system colors; the ahead labels use the primary text color.
  - **Isolation and imports:** pure types and their extensions are `nonisolated`; each file imports the modules its members come from.
  - **Leftovers:** nothing names `heart` or `pin`.

- [ ] **Step 2: Handle what it finds.** Check each finding against the code before acting on it. Keep a list for Todd of what was fixed and what was left, and why. A fix to a pure type means Todd runs its tests again.

---

### Task 12: Todd runs the tests

- [ ] **Step 1: The steps for Todd.**
  1. In Xcode, choose an iPhone simulator beside **Crewluv** at the top of the window.
  2. Press **⌘U** and wait for the run to finish.
  3. Paste me the end of the test output.

Expected: no failures.
- The new classes: `TripActivityTests` (5), `TripMapActivityTests` (13), `TripReplayClockPaceTests` (14), `TripTimelineTests` (7) and `TripTimelineTrackTests` (4). That's 43.
- Grown: `TripMapWordingTests` (24, it had 20), `TripMapMarkerTests` (6, it had 4) and `TripMapDrawingTests` (6, it had 5). That's 50 more tests in all.
- Unchanged, and passing: `TripReplayClockTests` (16), `TripMapTests`, `TripMapStatusTests` (one message reworded), `TripFactsTests`, `TripFactsRowsTests`, `FactsCasesTests` and `FlightProgressTests`.
- An open Xcode window can miss new test files. If a class is missing, close the project, open it again, and press ⌘U once more.
- For any failure, read it and STOP. Never change a test's expected value, or a shared case, to make it pass.

---

### Task 13: Todd's device check, then close out

The simulator can't show whether motion is smooth, and Todd saw the snapping night on his iPad. So the iPad comes first, then an iPhone. Run from Xcode, then press **⌘.** and open Crewluve from its icon: Xcode's debugger makes motion look worse than it is. Open the trip map from the status screen's card, during a trip or a recap; the demo status works too.

- [ ] **Step 1: On the iPad.**
  1. **The marker.** On the card and the full-screen map, the pilot's marker shows what they're doing: an indigo bed on a layover, an orange hourglass at a turn, a teal briefcase at base, a green house at home. No heart anywhere.
  2. **A replay at 1x, Quick layovers on.** Play. When a flight lands, the plane gives way to the bed. The layover passes in about 3 s, and the night sweeps across the map smoothly, without snapping. The bed gives way to the plane at the next departure.
  3. **At 10x.** Each part takes a tenth as long. The night still sweeps rather than jumps.
  4. **Quick layovers off, mid-replay.** Turn the switch off during a layover. The map stays on the same moment and the layover carries on at a day in 48 s. The bar's layover blocks grow, so the thumb moves to where that moment now sits. Turn it back on: the same, the other way.
  5. **The bar.** Flights blue, drives gray, layovers indigo, turns orange, base teal, home green. The played part is full color and the part ahead paler. A long enough layover shows "24h", "20h" or "4d" inside its block. The thumb moves steadily through flights and layovers alike: no stalls, no jumps.
  6. **The line under the bar.** "Sat 1:40 PM · Layover in Denver" style words, changing with the replay: "Flying to …", "Driving to …", "Turn in …", "At base in …", "Home".
  7. **Dragging.** Drag the thumb into a layover's block. The map shows the bed at that city and the night at that hour, and the line says "Layover in …".
  8. **Text size.** In Settings, Accessibility, Display & Text Size, Larger Text, turn the size up in steps. The labels on the bar grow, then drop out. The bar stays the same height. The switch moves above the speeds when they no longer fit beside each other.
  9. **Dark Mode.** The bar's colors and labels are clear in both.
  10. **VoiceOver.** On the bar it reads "Trip time", then the moment and what the pilot is doing, such as "Saturday 1:40 PM, layover in Denver", and that it's adjustable. Swiping up and down moves it. On the switch it reads "Quick layovers, switch button, on". On the map it doesn't read the pilot's marker.
  11. **Remembered.** Turn Quick layovers off, close the map, and open it again: it's still off. Turn it back on.
  12. **After a replay ends.** The play button shows, and play starts the trip over.
- [ ] **Step 2: On an iPhone.**
  13. **The sheet.** At its small stop it shows the headline, the bar, the line under it, and the switch with the speeds. The map is framed above it. Dragging on the bar moves the thumb, not the sheet.
  14. **A replay at 1x and 10x, Quick layovers on and off.** Smooth, as on the iPad. Pull the sheet to the middle stop during a replay: the rows keep up, and the map and the thumb stay smooth.
  15. **Landscape.** The panel shows, as on the iPad.

**STOP and come back to Todd if:**
- the night snaps or stutters through a quick layover, at 1x or 10x;
- the marker doesn't change as the replay moves through the trip, or a heart shows;
- the thumb stalls or jumps at one speed, other than when the switch changes;
- the map or the sheet drops frames during a replay (Risks, item 1);
- VoiceOver can't read or move the bar.

To send a screenshot, press the side or top button and volume up together.

Once every check passes, close out:

- [ ] **Step 3: Tell Todd, and wait for the yes.** Say what's ready, what the review fixed or left, and what the device check showed. Ask whether to commit anything not yet committed. Don't push without his word.

- [ ] **Step 4: Mark the spec.** In the moving map spec's 2026-11-14 amendment paragraph (Task 10), add one sentence with the device check's result and the day it was done, such as "Checked on Todd's iPad and iPhone, 15 Nov 2026: the night sweeps smoothly through a quick layover at 1x and 10x." Tick this plan's steps. Both go in a commit, on Todd's yes.

- [ ] **Step 5: The revision note.** Draft the "Crewluve revisions" entry in the "1.0.X Build YY" format, as the release-notes memory describes. Confirm the version and build with Todd. Print it for him to paste rather than writing to the note by script. Suggested text:

```
The trip map now shows what your pilot is doing: a bed on a layover, an hourglass at a turn, a briefcase at base and a house at home. Replays hurry through long layovers with the new Quick layovers switch, as the night sweeps by, and the timeline is colored by flights, drives and time on the ground.
```

---

## Risks

1. **The cost of 60 updates a second.**
   - Each tick rebuilds the screen's body inside the `TimelineView`: the map's drawing, markers and night (well under a millisecond, per the previous plan), the bar's `Canvas`, and, with the iPad's panel or the sheet at its middle stop, the facts rows (`facts.rows(at:now:)`) and their text.
   - That's twice today's work. An iPad showing the panel with its rows during a 10x replay is the heaviest case. Checks 2, 3 and 14 cover it.
   - The knobs, in order: the sheet's `TimelineView` back to 1/30 s (its thumb then steps at 30 a second); the rows fed a time that changes ten times a second; Instruments' SwiftUI template to find what's slow.
2. **Labels that depend on the text size.** The `Canvas` measures each label in its own environment, so labels follow Dynamic Type. Two things to watch:
   - White caption text on orange, green or teal is low-contrast. It's only the played part, and the marker uses the same white-on-color by design. If Todd finds it hard to read, the labels can drop the played half's white for the primary color with a halo.
   - A label won't flicker as the thumb crosses it: whether it fits depends only on its block's width and the text size, never on the thumb. It changes only when the pace or the text size does.
3. **Ground legs that don't line up with the flights.**
   - A delay moves the flights and not CrewLu's ground legs. The overlap rule takes care of that (`activity-cases.json`'s delay case).
   - `SharedPilotStatus` cuts a layover, base or home leg short at a flight that starts inside it, before the map sees it. That only sharpens the overlap.
   - A CrewLu that sends no ground legs, or ground legs with no overlap, falls back to the 8-hour rule.
   - A ground leg that overlaps two waits names both, which is right for a layover split by a short positioning flight.
4. **A drag inside the sheet.** `DragGesture(minimumDistance: 0)` on the bar takes touches that start on it. In the sheet's scroll view, a scroll or a resize can't start on the bar. The `Slider` took those touches too. Check 13 covers it.
5. **The first frame's pace.** For a family who turned Quick layovers off, the bar may show the quick widths for one frame as the map opens (Design, decision 6). The screen slides in as it's presented, so it shouldn't show. If it does, the screen can read `UserDefaults` for the key in `init`.
6. **The display link when live.** `.animation(minimumInterval: 1)` runs on the display's clock and fires once a second, where `.periodic` used a timer. It's the one schedule that gives 60 a second during a replay without swapping the `TimelineView` (swapping would make a new `MKMapView`). The cost while the map is open live is small.
7. **VoiceOver's steps.** A `Slider` moves by a tenth of its range for each swipe. With Quick layovers on, a layover is about a twentieth of the bar, so a swipe can pass over one. The words still say where the swipe landed. Stepping by block, through `accessibilityAdjustableAction`, is the follow-up if Todd finds it awkward (check 10).

## Self-critique

**Is this wise?**
- It does what Todd asked for, in the design's words, with nothing extra: no new settings screen, no skipped time, no change to the facts or the camera.
- The rules live in pure, tested types (`TripMap+Activity`, `TripReplayClock`, `TripTimeline`, `TripTimelineTrack`). The views only draw what those say. The shared cases hold the app and the website to the same answers, and a Python model of the rules reproduced every expected number while this plan was written.
- If a rule is wrong, the cost is a wrong icon or a wrong pace on one screen. Nothing is stored except one switch.

**Will it break anything?**
- **The replay clock** is rewritten, but a clock given no waits, or with Quick layovers off, paces exactly as before: its 16 tests run unchanged.
- **`TripMap` gains a stored property,** which changes its memberwise initializer. The seven hand-made maps in the facts tests keep compiling through a test-only initializer, rather than seven edits.
- **The heart's users** were all found by search: `TripMapDrawing.pin`, `TripMapMarker.heart`, `TripMapMarkers.Heart`, `TripMapMarkerView`, `TripMapAnnotationView`, two headers, two tests and one test message. Task 7's search catches any left.
- **The sheet grows by a row** (the switch). Its small stop is measured, so it fits, and it stays under 45% of the screen; at the largest sizes the header scrolls, as it already could.
- **A finished replay now pauses at its end.** Play behaves as before: it starts over.

**Is this what a brilliant Apple engineer would do?**
- The bar is SwiftUI's own pattern for a custom control: drawn with `Canvas`, made a `Slider` for VoiceOver with `accessibilityRepresentation`, with a 44 pt touch height and system colors. `Slider` can't color its track by part; a `UISlider` with track images would mean a representable and new images for every pace.
- `Canvas` draws the blocks and measures each label in one pass per tick, with no view per block to diff 60 times a second.
- One `TimelineView` schedule for both states keeps the `MKMapView` in place; swapping schedules would rebuild it.
- `Services/` stays free of SwiftUI: the kinds' symbols and colors are a view-side extension.
- The waits are worked out in one place, `TripMap.waits`, and the marker, the bar, the clock and the words all read them, so they can't disagree.

**Disease or symptom?** The night "snapping" through a layover was a symptom of a replay that either crawled through a wait (a day in 48 s) or would have had to skip it. The cure is a pace that hurries through a wait without skipping it, plus enough updates a second to show the hurry. Both are in.

**Fixed while writing this plan:**
- The screen kept updating 30 a second after a replay ended, and would have kept updating 60. A finished replay now pauses at its end, with a test.
- Symbols and colors first sat in the `Services/` type with `import SwiftUI`. They moved to a view-side extension.
- `groundKind` first found its wait with its own search. It now reads `waits`, so the marker and the bar always agree.
- Labels ahead of the thumb were first white, which fades on the paler blocks. They're in the primary text color.
- `TripMap`'s new property first meant editing seven test call sites. A test-only initializer keeps them as they are.
- The marker tests' helper was first named `placements`, the same as a local in each test, which doesn't compile. It's `markers(_:at:)`.

**Alternatives considered and turned down:**
- **Skipping waits.** Todd wants the time to pass, not vanish (design §9).
- **A `UISlider` with colored track images.** It needs a representable and images remade for every pace, and its track can't show labels.
- **One `Rectangle` view per block with `ViewThatFits` labels.** Cleaner to read, but it diffs a view per block 60 times a second and can't clip one label in two colors at the thumb.
- **Letting the clock find the waits itself.** The design gives them to it, and it can't name them without the map.

**Deliberately left out:**
- The website's half (its own session).
- VoiceOver steps by block (Risks, item 7).
- Right-to-left: the bar runs left to right, like the map's panel measure. Crewluve is English-only today.

## Seen, not fixed

- **The moving map spec's §7.1 and §11, and the Stage 2 spec, still name the heart.** The design's §10 lists only §5.1, §6, §10, §14 and §15.1. §11 is the website's, which its session amends. A one-word follow-up could change "the heart" to "the pilot's marker" in §7.1 and the Stage 2 spec's recap lines.
- **With no home airport set, base reads as home.** `TripMap(status:at:)` uses `homeAirportCode ?? baseAirportCode`, as CrewLu's summary conflates them, so before and after a trip from base the marker shows the house.
- **The bar's blocks aren't in the shared cases,** only the pace and the labels they're built from. The website builds them from the same rules.

---

## Changes made during execution

The code, not the blocks above, is the reference for these.

### Batch A (Tasks 2–6)

The blocks were copied from this plan by script, and every replacement matched once. The review (sonnet) found nothing critical or important.
- **The shared cases check out.** An independent model of the rules reproduced all 8 replay cases (42 checks), the 11 wait labels, and all 10 activity trips (37 moments).
- **Left as they are:**
  - `Piece` is `private` in an extension and used by `private` stored properties. The clock did the same before this plan and built.
  - `waits` is worked out again on each read, as often as 60 times a second in a replay. That's trivial for a trip's handful of legs.
  - `replay-cases.json` has no overlapping legs. The app and the website already test overlap separately, with the same numbers.

### Batch B (Tasks 7–9)

The blocks were copied from this plan by script, and every replacement matched once. Today's `UIHostingController` marker fix (`safeAreaRegions = []`, `updateTraitsIfNeeded()`) is intact. The review (sonnet) found nothing critical or important and no regressions.
- **Fixed:**
  - `TripTimelineBlocks` measures a length only in the pass that shows it. The ahead pass skips blocks already wholly played, and the played pass skips blocks the thumb hasn't reached. Before, every label was resolved and measured twice on every tick.
  - At accessibility text sizes, Live goes under the bar. Beside it, Live could squeeze the bar to a few points.
- **Left:**
  - `activity(at:)` and `waits` are worked out again on each tick, by the map, the sheet and the panel. That's cheap at a trip's size.
  - `TripTimeline` is rebuilt in `body`, so again on each camera or sheet change. It isn't rebuilt per frame.
  - White symbols and lengths on orange, teal and green are low contrast, about 2:1 on orange. These are the design's colors. The words under the bar and VoiceOver carry the kind. Check on device.
  - The previews' own storage isn't read by the screen's `init`, so a preview's first frame may use the default pace.

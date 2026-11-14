# Moving Map: Our Own Night Drawing (Crewluve) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The trip map's night and route lines glide during a replay with no flashing, on iPhone and iPad, by drawing them ourselves the way CrewLu's moving map does.

**Architecture:**
- `TripMapView` becomes a `UIViewRepresentable` around an `MKMapView`, run by `TripMapCoordinator`.
- The markers (plane, heart, airports, cars) stay MapKit annotations. Their views host the existing SwiftUI markers through `UIHostingConfiguration`.
- The night's seven layers and every route line are `CAShapeLayer`s in one view of ours, `TripMapShapesView`. It sits just under MapKit's annotation container, so the markers stay bright and Apple's logo and Legal link stay on top. Every update gives the same layers new outlines; nothing is swapped.
- Where each place is on screen comes from three places the map is asked about: `MapProjection`, ported from CrewLu's `FlatMapFit` with its tests.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency in the app target (not in the test target), member import visibility, iOS 26, MapKit (`MKMapView`), Core Animation shape layers, SwiftUI hosted with `UIHostingConfiguration`, XCTest.

**Sources:**
- The moving map spec: `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`. This plan amends §6, §7.1, §10, §12, §14 and §15.2 (Task 12).
- The Stage 2 spec: `docs/superpowers/specs/2026-11-13-crewluve-moving-map-stage2-facts-design.md`. This plan amends §6.1 and §6.2.
- CrewLu's fix, in `/Users/toddanderson/Dev/Duty`. That repo is **read only**: never edit it, never commit there.
  - The one-sun spec: `docs/superpowers/specs/2026-11-10-moving-map-one-sun-design.md`, §3 (the flicker measurements) and §4.7 (our own drawing).
  - The one-sun plan: `docs/superpowers/plans/2026-11-10-moving-map-one-sun.md`, part two, Tasks 11 to 18.
  - The code: `Duty/Views/Map/FlightMapUIView.swift`, `FlightMapShapesView.swift`, `FlatMapFit.swift` and `DutyTests/FlatMapFitTests.swift`.

---

## Design

### Why

On Todd's iPad the night flashes all through a replay. `TripMapView` draws it as seven `MapPolygon`s, and the full-screen map redraws them about 10 times a second (`nightStep`). MapKit can't move an overlay. It can only replace one, and each replacement blinks: it draws overlays a tile at a time off the main thread, and the tiles catch up at different moments.

CrewLu measured this on 10 Nov 2026 (one-sun spec §3):

| How the night was drawn | Flash frames a second |
|---|---|
| Seven overlays swapped 30 times a second | 23.5 |
| The same, 20 a second | 16.8 |
| The same, 2 a second | 1.6 |
| One overlay that redraws itself | 0, at about 6 times the processor of the next row |
| Our own layers over the map, every frame | 0 |

Stepping the night every 2 seconds was tried here and Todd turned it down. Crewluve's route lines are swapped on every tick too, because the leg in the air is split at the moving plane. Todd chose to port CrewLu's approach.

This reverses one line of Stage 1A's plan: "no `UIViewRepresentable`, no private MapKit views". We still name no private MapKit class. The one step Apple doesn't document is putting our view next to MapKit's annotation container. That step is guarded, and has a fallback.

### What moves where

| Today (SwiftUI `Map`) | After |
|---|---|
| `Map(position:interactionModes:)` | `MKMapView` in `TripMapContainerView`, wrapped by `TripMapView` (`UIViewRepresentable`) and run by `TripMapCoordinator` |
| Night: `ForEach(NightBand.bands(...))` of `MapPolygon` | Seven `CAShapeLayer`s in `TripMapShapesView`, filled with `TripMapPalette.night` (7.5% each) |
| Routes: one `MapPolyline` per `RouteSegment`, geodesic or straight | One `CAShapeLayer` per `RouteSegment.Style` in `TripMapShapesView`. Each segment becomes flat-map points (`TripMapLine`): a flight follows its great circle in stretches of at most 1°, and a drive is drawn straight. Dashes and dots are baked into each piece, laid from the line's far end |
| `Annotation` with `TripMapMarkers` and `PlaneMarker` | `TripMapAnnotation` (`MKAnnotation`) and `TripMapAnnotationView`, which hosts `TripMapMarkerView`, which shows the same SwiftUI markers |
| Airport codes drawn by `Map` as annotation titles | `TripMapMarkers.AirportLabel`: the dot with the code under it, coloured from the palette |
| `.mapStyle(style.mapStyle)` | `mapView.preferredConfiguration = style.configuration`, always flat and without points of interest |
| `@Binding var position: MapCameraPosition`, `position.positionedByUser` | `@Binding var camera: TripMapCamera`, and `camera.isPositionedByUser` |
| `.safeAreaPadding(.bottom/.leading, …)` | `TripMapClearance`: the map's layout margins (where MapKit puts its logo and Legal link) and the camera's edge padding |
| `nightStep`, `TripMapDrawing.nightDate(for:step:)`, `NightBand` | Removed. The night is drawn for each update's exact time |

### How each Stage 1 behaviour is kept

**Camera.** SwiftUI's `MapCameraPosition` can't be rebuilt by hand with `positionedByUser` set, so it gives way to our own small value, `TripMapCamera`:
- It holds:
  - `rect`, from `MapFit` through `TripMap.framingRect(focusingOn:)`;
  - `isAnimated`;
  - `isPositionedByUser`;
  - `framingNumber`, which goes up with every `frame(_:animated:)`, so asking for the same rectangle again still moves the map.
- `TripMapCameraController` frames once per new `framingNumber`, with `setVisibleMapRect(_:edgePadding:animated:)`. The first framing, as the map opens, is never animated.
- It frames again without animation when the map's size, safe area or clearance changes and the family hasn't moved the map. So the map follows the sheet as it's dragged up to its middle stop, and reframes after a rotation, as SwiftUI's map did.
- **Who moved the map.** Four recognizers are added beside MapKit's: pan (trackpad scrolling included), pinch, double tap and two-finger tap. Each recognizes alongside MapKit's, never cancels or delays a touch, and only reports. The first report sets `isPositionedByUser` through the binding, which shows the recenter button and stops automatic refits.
- **Recenter and leg changes.** Both call `camera.frame(...)`, animated unless Reduce Motion is on. That replaces `withAnimation(.smooth) { position = camera }`. MapKit animates the move itself.
- **Clearances.** `TripMapScreen` measures the sheet and the panel from the screen's edges, as it does now, and passes `TripMapClearance(leading:bottom:)`.
  - The safe area is already counted: UIKit adds it to the layout margins itself, and the framing padding starts from it. So only the part of each clearance beyond the safe area is added. CrewLu does the same with its bar (`max(0, bar - safeArea.bottom)`).
  - Apple's logo and Legal link therefore sit just above the sheet, or beside the panel. The camera frames the trip in what the sheet or panel leaves clear.

**Map styles.** `TripMapStyle.configuration` returns `MKHybridMapConfiguration`, `MKStandardMapConfiguration` or `MKImageryMapConfiguration`, all `elevationStyle: .flat`, with points of interest off for hybrid and standard. The style button and its VoiceOver value don't change. CrewLu found its view stayed in place across a style change. We also check the placement on every draw.

**Markers.** One annotation per marker, keyed by a name that stays the same while the marker is on the map: `airport-CGN`, the car's own id, `heart` and `plane`. So MapKit moves a marker rather than replacing it.
- Each update adds what's new, removes what's gone, sets `coordinate` (KVO-observable) when it changes, and refreshes the view when the marker itself changes. The plane's angle changes on every tick of a replay.
- `TripMapAnnotationView` hosts `TripMapMarkerView` through `UIHostingConfiguration(...).margins(.all, 0).minSize(width: 0, height: 0).makeContentView()`.
  - It measures with `systemLayoutSizeFitting`, again only when the marker's kind, its code or the text size changes.
  - It replaces the configuration rather than the view, so SwiftUI keeps the plane's `@State` and `PlaneMarker` still turns the short way round with `.snappy`.
- Placing them:
  - the heart's centre offset stands it on its place, as `anchor: .bottom` did;
  - the airport's dot sits on the airport, with its code below;
  - every marker gets `displayPriority = .required`;
  - `zPriority` stacks the plane above the heart, the heart above the cars, and the cars above the airports.

**Dark Mode.**
- Hybrid and imagery look the same in both modes, and the standard map follows the system, as `MKMapView` does by itself.
- The palette still comes from `style.palette(for: colorScheme)`. The coordinator reads `context.environment.colorScheme` on every update, so a change of look flips the line colours and the airport codes.
- `TripMapShapesView` resolves each line colour with its own `traitCollection`, and again on a change of look, because `.blue` and `.gray` are system colours.
- The night's navy and the markers' white-on-colour are the same in both modes, as today.

**Accessibility.**
- On the card the map is hidden from VoiceOver (`accessibilityElementsHidden`). The button's sentence stays the card's one element (spec §14).
- On the full-screen map each airport's view is an element labelled with its code, as SwiftUI's annotation titles were read. The plane, the heart and the cars aren't elements: the card's sentence and the facts describe them. Our drawing view is hidden.
- The airport code is `.caption2`. It scales with Dynamic Type up to `.accessibility1`, and the view is measured again when the text size changes.
- Reduce Motion: camera moves jump, and the plane's turn doesn't animate (`PlaneMarker`, unchanged).

**The card and the full screen.** `TripMapView.isInteractive` is renamed `isFullScreen`, because it now decides three things.
- **Full screen:** the family can pan and zoom, VoiceOver can explore the map, and the margins and framing keep clear of the safe area and the clearance.
- **Card:**
  - no interaction, `allowsHitTesting(false)` as before, so a tap is the card's button;
  - hidden from VoiceOver;
  - the safe area is ignored, so a card scrolled under the status bar keeps its camera and logo where they are;
  - no clearance.
- Both are north up, never tilted, same drawing. The card ticks every 10 seconds and the screen 1 or 30 times a second, as today.

**When it's drawn.** A draw where neither the map, the time nor the lines have changed sets no layer.

| Trigger | From | What happens |
|---|---|---|
| Every SwiftUI update: each `TimelineView` tick (about 30 a second in replay, every second live, every 10 s on the card), a scrub, Live, a style or look change, a sheet drag | `updateUIView` → `TripMapCoordinator.update` | Style and palette. Markers added, moved or removed. The night for the exact `date`, worked out again only when the time has moved. Lines rebuilt (cheap), and only laid if they changed. Camera. Then `draw()` |
| Pan, pinch, double tap, an animated camera move | `mapViewDidChangeVisibleRegion` | `draw()` with the new projection |
| The map settles | `mapView(_:regionDidChangeAnimated:)` | `draw()` |
| The map's size or safe area changes | `TripMapContainerView.onLayoutChange` | Margins, a refit unless the family moved the map, `draw()` |
| Our view's size changes | `TripMapShapesView.layoutSubviews` → `onNeedsRedraw` | Everything laid again |
| Light or dark | trait registration in `TripMapShapesView` | Line colours resolved again |
| MapKit shows a marker's view | `mapView(_:didAdd:)` | Its container noted, our view moved under it, `draw()` |
| A framing without animation | `TripMapCameraController.onFramedWithoutAnimation` | `draw()`. MapKit needn't report a move that isn't animated |

**`nightStep` goes.** It existed to keep MapKit's overlay swaps rare. Now a night update costs `NightShade.layers` (about 2,500 trig calls) plus projecting and clipping seven shapes, well under a millisecond, with no MapKit work. So `TripMapView`'s `nightStep`, `TripMapScreen.nightStep`, `TripMapDrawing.nightDate(for:step:)` with its test, and `NightBand` with its test are all removed.

The replay clock stays the screen's `TimelineView` at 30 a second, rather than CrewLu's display link. At 1x the night moves about 0.25° a tick, under a point at trip zoom. If 10x looks steppy on the device (not flashing), see Risks.

**If MapKit's annotation container can't be found.** This is ported from CrewLu's `placeShapesView`.
- The container is reached through any marker's view (`view(for:)?.superview`, or `mapView(_:didAdd:)`). No private name is used.
- Our view is checked on every draw: still inside the map, still just under the container, sized to its holder. MapKit's content view doesn't resize what's put in it.
- Until a marker's view exists, our view sits just above the map's own content. Nothing is there yet to cover.
- If a container is found but can't hold a sibling, our view stays above the map's content and the night dims the markers. `debugLog` writes "Trip map: no view to put the night under" once.
- The night and the lines always show.

**What people will notice.**
- The night's edge glides, and nothing on the map flashes, the route lines included.
- Apple's own place names dim a little under the night. SwiftUI drew its polygons beneath the labels; MapKit's labels are now in the base map under our layer. The plane, the heart, the cars and the airport codes stay bright. CrewLu took the same trade.
- The airport codes are our own text, a little different from SwiftUI's titles.
- Dashes stay put on the map as the plane moves along. Before, they were laid again from the plane on every tick.

### Spec amendments (applied in Task 12)

**Moving map spec, header.** After the `Status:` paragraph, add:

```markdown
**Amended 2026-11-13, our own night drawing:** §6, §7.1, §10, §12, §14 and §15.2. On Todd's iPad the SwiftUI map's night flashed all through a replay: MapKit can't move an overlay, only replace it, and each replacement blinks. The map is now an `MKMapView` with the night and the route lines drawn by the app, as CrewLu's moving map draws them. Plan: `docs/superpowers/plans/2026-11-13-moving-map-own-night-drawing.md`.
```

**§6.** Replace:

```markdown
- **The map fills the screen.**
  - Top left: close.
  - Top right: a style button that cycles hybrid, standard and imagery, as in CrewLu. Hybrid is the default.
  - A recenter button appears once the map is panned away from the plane.
```

with:

```markdown
- **The map fills the screen.**
  - It pans and zooms. It doesn't turn or tilt (§10).
  - Top left: close.
  - Top right: a style button that cycles hybrid, standard and imagery, as in CrewLu. Hybrid is the default.
  - A recenter button appears once the family pans, pinches or double-taps the map. It frames the leg in motion, or the whole trip, again.
```

**§7.1.** After the bullet "**Drives** are a dotted line with a small car, and never get live data.", add:

```markdown
- **Drawn by the app,** over Apple's map and under the planes, the heart, the cars and the airports, as the night is (§10). Dashes and dots are laid from each line's far end, so they stay put on the map while the plane eats into the line still to fly, and while the map pans.
```

**§10.** Replace:

```markdown
- **The map is SwiftUI's `Map`,** not a port of CrewLu's `MKMapView`. It covers everything with public API:
  - `.mapStyle(.hybrid(elevation: .flat))`, `.standard` and `.imagery`;
  - `MapPolyline` for routes, trails and drives;
  - `MapPolygon` for the night bands;
  - `Annotation` for the planes and the heart pin;
  - `MapCameraPosition` for fitting.
- **Ported from CrewLu, with their tests:** `NightShade`, `PlaneHeading`, the subsolar point in `SolarPosition`, and the date-line fit from `FlatMapFit`. Night refreshes about 10 times a second during replay, and once a minute otherwise.
- **`Views/TripMap/`:** `TripMapCard`, `TripMapScreen`, `TripMapView` (the `Map` and its content), `FactsSheet`, `TripTimeline`, `HeadlineFactChip`, `TripRecapView`, and their small subviews.
```

with:

```markdown
- **The map is an `MKMapView`,** wrapped for SwiftUI by `TripMapView`, and drawn the way CrewLu's moving map is. This was amended on 2026-11-13: SwiftUI's map can only replace an overlay, and on Todd's iPad each replacement blinked. Apple's map, its logo and Legal link, and the markers stay MapKit's. The night and the route lines are the app's own.
  - **Styles:** `MKHybridMapConfiguration`, `MKStandardMapConfiguration` and `MKImageryMapConfiguration`, all with `elevationStyle: .flat`.
  - **The app's drawing:** the night's seven layers and every route, trail and drive line are `CAShapeLayer`s in one view of the app's, `TripMapShapesView`.
    - It sits just under the view MapKit keeps its annotation views in, so the planes, the heart, the cars and the airports stay bright at night.
    - Every update gives the same shapes new outlines. Nothing is taken off the map or put on it.
  - **Markers:** the planes, the heart, the cars and the airports are MapKit annotations whose views host the app's SwiftUI markers.
  - **Camera:** `TripMapCamera`. The map frames each new request once, with `MapFit`'s rectangle. A pan, pinch or double tap makes the camera the family's until they recenter.
  - **Where things are on screen:** `MapProjection`, ported from CrewLu's `FlatMapFit`, works this out from three places the map is asked about.
    - Each shape is drawn once for each copy of the world on screen across the date line.
    - Every shape is cut off just outside the view.
    - The map pans and zooms but never turns or tilts. The arithmetic is right only for a map seen from straight above, north up.
  - **Fallback:** if a later iOS keeps its annotation views differently and that view can't be found, the night and the lines are drawn over the map's own content, and so over the markers. That's logged.
- **Ported from CrewLu, with their tests:** `NightShade`, `PlaneHeading`, the subsolar point in `SolarPosition`, the date-line fit (`MapFit`), and the screen projection and clipping (`MapProjection`, from `FlatMapFit`).
- **When the night is drawn:** for the map's exact time on every update. That's about 30 times a second during replay, every second on the full-screen map otherwise, and every 10 seconds on the card.
- **`Views/TripMap/`:** `TripMapCard`, `TripMapScreen`, `TripMapView` (the `MKMapView`, run by `TripMapCoordinator`, with `TripMapShapesView` and the markers' annotations), `FactsSheet`, `TripTimeline`, `HeadlineFactChip`, `TripRecapView`, and their small subviews.
```

**§12.** Replace:

```markdown
- **The date line, and polar or long legs:** these are handled by the ported date-line fit and geodesic lines. Web Mercator stops at ±85°, so near-polar paths are drawn clamped.
```

with:

```markdown
- **The date line, and polar or long legs:**
  - the camera's rectangle takes the short way round (`MapFit`);
  - the night and the routes are drawn once for each copy of the world on screen, each route laid out in one piece across the line (`MapProjection`);
  - flights are drawn along their great circle in stretches of at most a degree (`TripMapLine`).
  - Web Mercator stops at ±85°, so near-polar paths are drawn clamped.
```

**§14.** After the bullet "**The buttons** have labels: close, map style, recenter, Live, play.", add:

```markdown
- **The map's markers:** on the full-screen map VoiceOver reads each airport's code, as it did before. The planes, the heart and the cars are described by the card's sentence and the facts rows. The night and the lines aren't read. On the card the map is hidden, and the card is its one sentence.
```

**§15.2.** Replace:

```markdown
- the ported maths, with CrewLu's tests: `NightShade`, `PlaneHeading`, subsolar point, date-line fit;
```

with:

```markdown
- the ported maths, with CrewLu's tests: `NightShade`, `PlaneHeading`, subsolar point, date-line fit, and `MapProjection` (CrewLu's `FlatMapFit`);
- the drawing's pure parts: `TripMapLine`, `TripMapCamera`, `TripMapClearance` and `TripMapMarker`'s placements;
```

**Stage 2 spec §6.1.** Replace:

```markdown
- **The sheet reports its height** (`onGeometryChange`). The map takes it as bottom safe-area padding, so the camera frames the plane above the sheet.
```

with:

```markdown
- **The sheet reports its height** (`onGeometryChange`). The map takes it as its bottom clearance (`TripMapClearance`, amended 2026-11-13 with the map's own night drawing): the camera frames the plane above the sheet, and Apple's logo and Legal link sit above it, in the map's layout margins.
```

**Stage 2 spec §6.2.** Replace:

```markdown
- **The map** takes the panel's width as leading safe-area padding.
```

with:

```markdown
- **The map** takes the panel's width, padding included, as its leading clearance (`TripMapClearance`): the camera frames the trip beside the panel, and Apple's logo and Legal link sit beside it.
```

### Naming: `MapProjection`, not `FlatMapFit`

Crewluve already has `MapFit`: the camera's rectangle, taken the short way round the world. CrewLu's `FlatMapFit` is something else, a projection from the flat map to the screen built from three probes. With both in one module, `MapFit` and `FlatMapFit` would read as two versions of one thing.

So the port is `MapProjection`, which says what it is at the call site: `projection.screenPoint(for:)`, `projection.outlines(of:in:)`, `MapProjection.unwrapped(_:)`. `FlatMapPoint` keeps its name, since it doesn't clash.

The members keep CrewLu's names, and the header names the source file. A diff against CrewLu's file, after replacing `FlatMapFit` with `MapProjection`, shows only the header, the `nonisolated` keywords, `FlatMapPoint` moving to its own file, and the lines' half moving to `MapProjection+Lines.swift`.

---

## Ground rules for whoever runs this plan

These come from Todd's standing instructions. They override the skill's defaults.

1. **Don't run `xcodebuild` build or test loops,** and don't let subagents run them. Write the code and tests. At each checkpoint, Todd runs the named tests in Xcode, or with the command below.
2. **Never commit without Todd's go-ahead in the conversation.** Each task ends with a suggested message. Ask, then commit only on a yes, and only the task's own files.
3. **After the commit that changes what families see** (Task 15, step 6), draft the "Crewluve revisions" Apple Note entry in the "1.0.X Build YY" format, as the release-notes memory describes, and confirm the version with Todd.
4. **New files join the app target on their own.** `Crewluv/` and `CrewluvTests/` are synchronized folders. Don't tick `CrewluveAlerts` on any new file: the helper doesn't use the map.
5. **Pure types are `nonisolated`,** and so are their nested types (`nonisolated struct`, `nonisolated enum`). An extension of a pure type in another file is written `nonisolated extension`. Otherwise its members default to the main actor and the tests can't call them.
6. **Member import visibility is on.** Each file imports the module behind every member it uses. Examples: `CoreGraphics` for `CGPath.copy(dashingWithPhase:lengths:)` and `CGMutablePath.addLines(between:)`, `SwiftUI` for `UIColor(Color)`, and `Foundation` for `hypot`.
7. **Tests use XCTest,** with `@testable import Crewluv`, named `test_<methodOrBehavior>_<scenario>_<expectedResult>()`. Prefer `XCTAssertEqual` over `XCTAssertTrue`.
8. **The ported tests are the judge.** `MapProjectionTests` and `MapProjectionClippingTests` are CrewLu's `FlatMapFitTests`, renamed and split. Every expected value in them is plain geometry worked out in the test. If one fails, the code is wrong. If you believe a test is wrong, STOP and tell Todd. Don't change it.
9. **Reviewers:** dispatch `superpowers:code-reviewer` with `model: "sonnet"`.
10. **`/Users/toddanderson/Dev/Duty` is read only.** Read it, never edit it, never commit there.
11. **Work on `feature/trip-map-facts`.** The checkout is shared with other sessions, so commit only this plan's files.

Test command for Todd, one class per checkpoint:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CrewluvTests/<TestClass>
```

## File map

| File | Status | Responsibility |
|---|---|---|
| `Crewluv/Utils/FlatMapPoint.swift` | create | a place on the flat map |
| `Crewluv/Utils/MapProjection.swift` | create | CrewLu's `FlatMapFit`: places, probes, the projection, copies of the world, outlines, the date line, cutting shapes |
| `Crewluv/Utils/MapProjection+Lines.swift` | create | lines cut to the view, how far along each piece starts, and its dash phase |
| `Crewluv/Services/TripMap/TripMapLine.swift` | create | a `RouteSegment` as flat-map points |
| `Crewluv/Services/TripMap/TripMapCamera.swift` | create | what to frame, and whether the family moved the map |
| `Crewluv/Views/TripMap/TripMap+Camera.swift` | modify | `framingRect(focusingOn:)` replaces `camera(focusingOn:)` |
| `Crewluv/Views/TripMap/TripMapClearance.swift` | create | the sheet or panel, as margins and framing padding |
| `Crewluv/Views/TripMap/TripMapPalette.swift` | modify | `nonisolated`, `Equatable`, the airport codes' colours |
| `Crewluv/Views/TripMap/TripMapMarker.swift` | create | what each marker shows, and a drawing's markers by name |
| `Crewluv/Views/TripMap/TripMapShapesView.swift` | create | the night and the lines as `CAShapeLayer`s |
| `Crewluv/Views/TripMap/TripMapMarkers.swift` | modify | `AirportLabel`; `Airport.dotDiameter` |
| `Crewluv/Views/TripMap/TripMapMarkerView.swift` | create | the SwiftUI view for each marker |
| `Crewluv/Views/TripMap/TripMapAnnotation.swift` | create | a marker as MapKit holds it |
| `Crewluv/Views/TripMap/TripMapAnnotationView.swift` | create | the marker's SwiftUI view, hosted |
| `Crewluv/Views/TripMap/TripMapContainerView.swift` | create | holds the `MKMapView`, reports size and safe area changes |
| `Crewluv/Views/TripMap/TripMapShapesController.swift` | create | our view under MapKit's markers; the projection; when to draw |
| `Crewluv/Views/TripMap/TripMapCameraController.swift` | create | margins, framing, noticing the family move the map |
| `Crewluv/Views/TripMap/TripMapCoordinator.swift` | create | the map's delegate, style, markers and updates |
| `Crewluv/Views/TripMap/TripMapView.swift` | rewrite | the `UIViewRepresentable` |
| `Crewluv/Views/TripMap/TripMapStyle.swift` | modify | `configuration` replaces `mapStyle` |
| `Crewluv/Views/TripMap/TripMapCard.swift` | modify | `TripMapCamera` |
| `Crewluv/Views/TripMap/TripMapScreen.swift` | modify | `TripMapCamera`, `TripMapClearance`, no `nightStep` |
| `Crewluv/Services/TripMap/TripMapDrawing.swift` | modify | `nightDate(for:step:)` removed |
| `Crewluv/Services/TripMap/NightBand.swift` | delete | only `ForEach` needed it |
| `CrewluvTests/Helpers/MadeUpMap.swift` | create | the made-up map from CrewLu's tests |
| `CrewluvTests/Helpers/ProjectionTestGeometry.swift` | create | the view, places, squares, areas, inside-the-rectangle |
| `CrewluvTests/MapProjectionTests.swift` | create | ported: places, probes, the projection, copies, outlines (19) |
| `CrewluvTests/MapProjectionClippingTests.swift` | create | ported: cutting, the date line, pieces (18), and 6 for dashes |
| `CrewluvTests/TripMapLineTests.swift` | create | 5 |
| `CrewluvTests/TripMapCameraTests.swift` | create | 5 |
| `CrewluvTests/TripMapClearanceTests.swift` | create | 5 |
| `CrewluvTests/TripMapMarkerTests.swift` | create | 4 |
| `CrewluvTests/TripMapDrawingTests.swift` | modify | the `nightDate` and `NightBand` tests removed (2) |
| `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md` | modify | §6, §7.1, §10, §12, §14, §15.2 |
| `docs/superpowers/specs/2026-11-13-crewluve-moving-map-stage2-facts-design.md` | modify | §6.1, §6.2 |
| `CLAUDE.md` | modify | the Trip Map section |

`PlaneMarker.swift`, `TripMapPreviews.swift`, `NightShade.swift`, `MapFit.swift`, `PlaneHeading.swift` and `GreatCircle.swift` don't change.

## Batches

- **A, the pure parts:** Tasks 2–7. Review with `superpowers:code-reviewer` (sonnet). Then Todd runs `MapProjectionTests`, `MapProjectionClippingTests`, `TripMapLineTests`, `TripMapCameraTests`, `TripMapClearanceTests` and `TripMapMarkerTests`.
- **B, the UIKit pieces:** Tasks 8–10. They compile but aren't used yet. Todd builds (⌘B).
- **C, the swap and the docs:** Tasks 11–12. Then the review (Task 13), Todd's test run (Task 14), and Todd's device check with the close-out (Task 15, the last).

---

### Task 1: Before starting

**Files:** none.

- [ ] **Step 1: Check the branch and the tree.**

```bash
git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv status --short
```

Expected: `feature/trip-map-facts`.
- Anything else: STOP and ask Todd.
- This plan was written against `30cb4dd`. Stage 2A's last fixes are in `ce6c308` (the card and the screen) and `30cb4dd` (`CLAUDE.md`, the 2A plan). This plan's full-file versions of `TripMapCard.swift` and `TripMapScreen.swift` (Task 11) include them.
- If `git status --short` lists any file this plan changes, other than this plan itself, someone is working on it. Ask Todd before going on. Leave every file that isn't this plan's alone.

- [ ] **Step 2: Check `TripMapCard` and `TripMapScreen` are the versions this plan was written against.**

```bash
cd /Users/toddanderson/Dev/Crewluv && grep -c "LegStoryStore.preparationKey(for: tripMap)" Crewluv/Views/TripMap/TripMapCard.swift Crewluv/Views/TripMap/TripMapScreen.swift && grep -c "task(id: isClosing)" Crewluv/Views/TripMap/TripMapScreen.swift
```

Expected: `TripMapCard.swift:1`, `TripMapScreen.swift:2`, then `1`.
- Anything else means the files have moved on. STOP: Task 11's full-file versions would undo someone's work.

- [ ] **Step 3: Check CrewLu's source is the one this plan ported.** Read only.

```bash
git -C /Users/toddanderson/Dev/Duty log -1 --format=%h -- Duty/Views/Map/FlatMapFit.swift Duty/Views/Map/FlightMapShapesView.swift Duty/Views/Map/FlightMapUIView.swift DutyTests/FlatMapFitTests.swift
```

Expected: `ba6a2d18`.
- A newer commit means CrewLu changed its drawing after this plan. Read the change and tell Todd before going on.

---

### Task 2: `FlatMapPoint` and `MapProjection`

The projection's core, ported from CrewLu's `FlatMapFit` (one-sun plan, Task 11). Its line half comes in Task 3.

**Files:**
- Create: `Crewluv/Utils/FlatMapPoint.swift`
- Create: `Crewluv/Utils/MapProjection.swift`
- Create: `CrewluvTests/Helpers/MadeUpMap.swift`
- Create: `CrewluvTests/Helpers/ProjectionTestGeometry.swift`
- Test: `CrewluvTests/MapProjectionTests.swift`

- [ ] **Step 1: Write the test helpers.** Create `CrewluvTests/Helpers/MadeUpMap.swift`:

```swift
//
//  MadeUpMap.swift
//  CrewluvTests
//
//  A stand-in for the real map in `MapProjection`'s tests, ported from CrewLu's FlatMapFitTests. It slides, scales
//  and turns, and nothing else. The tests ask it about three places, as the app asks the real map, and then check
//  every other place against it.
//

import CoreGraphics
import Foundation
@testable import Crewluv

/// Shows the flat-map place `center` at `origin`, with one whole world `worldWidth` points wide, turned clockwise by
/// `degrees` as a twist of a real map would turn it.
struct MadeUpMap {
    let center: FlatMapPoint
    let origin: CGPoint
    let worldWidth: Double
    let degrees: Double

    func screen(_ point: FlatMapPoint) -> CGPoint {
        let dx = (point.x - center.x) * worldWidth
        let dy = (point.y - center.y) * worldWidth
        let turn = degrees * .pi / 180
        return CGPoint(x: Double(origin.x) + dx * cos(turn) - dy * sin(turn),
                       y: Double(origin.y) + dx * sin(turn) + dy * cos(turn))
    }

    /// The projection made the way the app makes it: ask about the centre and the two places `probes` gives.
    func projection(step: Double = 0.05) -> MapProjection? {
        let probes = MapProjection.probes(around: center, step: step)
        return MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                             centerOnScreen: screen(center), eastOnScreen: screen(probes.east),
                             southOnScreen: screen(probes.south))
    }
}
```

Create `CrewluvTests/Helpers/ProjectionTestGeometry.swift`:

```swift
//
//  ProjectionTestGeometry.swift
//  CrewluvTests
//
//  Plain geometry for `MapProjection`'s tests, ported from CrewLu's FlatMapFitTests: the view they draw into,
//  places, squares, the area inside an outline, and whether an outline stays inside a rectangle.
//

import XCTest
import CoreGraphics
import CoreLocation

enum ProjectionTestGeometry {

    /// The view every test draws into.
    static let view = CGRect(x: 0, y: 0, width: 1000, height: 600)

    static func place(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// The area inside a closed outline, by the shoelace rule.
    static func area(_ outline: [CGPoint]) -> Double {
        guard outline.count >= 3 else { return 0 }
        var sum = 0.0
        for index in outline.indices {
            let a = outline[index]
            let b = outline[(index + 1) % outline.count]
            sum += Double(a.x * b.y - b.x * a.y)
        }
        return abs(sum) / 2
    }

    static func square(_ x: Double, _ y: Double, _ side: Double) -> [CGPoint] {
        [CGPoint(x: x, y: y), CGPoint(x: x + side, y: y), CGPoint(x: x + side, y: y + side), CGPoint(x: x, y: y + side)]
    }

    static func assertInside(_ outline: [CGPoint], _ rect: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        for point in outline {
            XCTAssertTrue(point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY,
                          "\(point) is outside \(rect)", file: file, line: line)
        }
    }
}
```

- [ ] **Step 2: Write the failing tests.** Create `CrewluvTests/MapProjectionTests.swift`. These are CrewLu's `FlatMapFitTests` (places, probes, the fit, copies, outlines), renamed to Crewluve's test naming:

```swift
//
//  MapProjectionTests.swift
//  CrewluvTests
//
//  Where places on the flat map are on screen, worked out from three places the map is asked about (moving map spec
//  §10). Ported from CrewLu's FlatMapFitTests; cutting off, the date line and the route lines are in
//  MapProjectionClippingTests. Every expected value is plain geometry worked out here, none copied from the code
//  under test.
//

import XCTest
import CoreGraphics
import CoreLocation
@testable import Crewluv

final class MapProjectionTests: XCTestCase {

    private let view = ProjectionTestGeometry.view

    private func place(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        ProjectionTestGeometry.place(latitude, longitude)
    }

    private func area(_ outline: [CGPoint]) -> Double {
        ProjectionTestGeometry.area(outline)
    }

    private func assertInside(_ outline: [CGPoint], _ rect: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        ProjectionTestGeometry.assertInside(outline, rect, file: file, line: line)
    }

    // MARK: - Places on the flat map

    func test_point_middleAndEdges_landWhereTheMapHasThem() {
        let middle = MapProjection.point(for: place(0, 0))
        XCTAssertEqual(middle.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(middle.y, 0.5, accuracy: 1e-12)
        XCTAssertEqual(MapProjection.point(for: place(0, -180)).x, 0, accuracy: 1e-12)
        XCTAssertEqual(MapProjection.point(for: place(0, 180)).x, 1, accuracy: 1e-12)
        XCTAssertEqual(MapProjection.point(for: place(0, 90)).x, 0.75, accuracy: 1e-12)
    }

    func test_point_north_isTowardsTheTopOfASquareMap() {
        let north = MapProjection.point(for: place(60, 0))
        let south = MapProjection.point(for: place(-60, 0))
        XCTAssertLessThan(north.y, 0.5)
        XCTAssertEqual(north.y + south.y, 1, accuracy: 1e-12)
        // The flat map's top edge is where the map is as tall as it is wide: latitude atan(sinh(pi)).
        let topEdge = atan(sinh(Double.pi)) * 180 / .pi
        XCTAssertEqual(topEdge, 85.0511, accuracy: 0.0001)
        // The app's own limit is a touch inside that edge, so its y is a touch more than nothing.
        let held = MapProjection.point(for: place(NightShade.maxLatitude, 0)).y
        XCTAssertGreaterThanOrEqual(held, 0)
        XCTAssertLessThan(held, 0.0001)
    }

    func test_point_beyondTheMapsEdge_isHeldAtTheEdge() {
        XCTAssertEqual(MapProjection.point(for: place(90, 10)).y, MapProjection.point(for: place(NightShade.maxLatitude, 10)).y)
        XCTAssertEqual(MapProjection.point(for: place(-90, 10)).y, MapProjection.point(for: place(-NightShade.maxLatitude, 10)).y)
    }

    func test_coordinate_ofAPoint_isThePlaceItCameFrom() {
        for latitude in stride(from: -80.0, through: 80.0, by: 20.0) {
            for longitude in stride(from: -170.0, through: 170.0, by: 34.0) {
                let back = MapProjection.coordinate(for: MapProjection.point(for: place(latitude, longitude)))
                XCTAssertEqual(back.latitude, latitude, accuracy: 1e-9)
                XCTAssertEqual(back.longitude, longitude, accuracy: 1e-9)
            }
        }
    }

    // MARK: - The two other places

    func test_probes_awayFromTheEdges_stepEastAndSouth() {
        let probes = MapProjection.probes(around: FlatMapPoint(x: 0.5, y: 0.5), step: 0.1)
        XCTAssertEqual(probes.east.x, 0.6, accuracy: 1e-12)
        XCTAssertEqual(probes.east.y, 0.5, accuracy: 1e-12)
        XCTAssertEqual(probes.south.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(probes.south.y, 0.6, accuracy: 1e-12)
    }

    func test_probes_nextToAnEdge_stepTheOtherWay() {
        let probes = MapProjection.probes(around: FlatMapPoint(x: 0.95, y: 0.97), step: 0.1)
        XCTAssertEqual(probes.east.x, 0.85, accuracy: 1e-12)
        XCTAssertEqual(probes.south.y, 0.87, accuracy: 1e-12)
        // Never across the date line from the centre, and never off the map.
        for x in stride(from: 0.0, through: 1.0, by: 0.01) {
            for y in stride(from: 0.0, through: 1.0, by: 0.05) {
                let pair = MapProjection.probes(around: FlatMapPoint(x: x, y: y), step: 0.25)
                XCTAssertTrue((0...1).contains(pair.east.x), "east probe at \(pair.east.x) from \(x)")
                XCTAssertTrue((0...1).contains(pair.south.y), "south probe at \(pair.south.y) from \(y)")
                XCTAssertNotEqual(pair.east.x, x)
                XCTAssertNotEqual(pair.south.y, y)
            }
        }
    }

    // MARK: - The projection

    func test_init_slidScaledAndTurnedMap_matchesEveryPlace() throws {
        let centers = [FlatMapPoint(x: 0.5, y: 0.5), FlatMapPoint(x: 0.999, y: 0.4), FlatMapPoint(x: 0.001, y: 0.6),
                       FlatMapPoint(x: 0.3, y: 0.99), FlatMapPoint(x: 0.7, y: 0.01)]
        let places = [FlatMapPoint(x: 0.5, y: 0.5), FlatMapPoint(x: 0, y: 0), FlatMapPoint(x: 1, y: 1),
                      FlatMapPoint(x: 0.123, y: 0.876), FlatMapPoint(x: 1.4, y: 0.3), FlatMapPoint(x: -0.6, y: 0.7)]
        for center in centers {
            for degrees in [0.0, 37.0, 90.0, 180.0, -120.0] {
                for worldWidth in [400.0, 5_000.0] {
                    let map = MadeUpMap(center: center, origin: CGPoint(x: 480, y: 290), worldWidth: worldWidth, degrees: degrees)
                    let projection = try XCTUnwrap(map.projection(), "no projection at \(center), \(degrees) degrees")
                    for place in places {
                        let ours = projection.screenPoint(for: place)
                        let theirs = map.screen(place)
                        XCTAssertEqual(Double(ours.x), Double(theirs.x), accuracy: 0.001, "\(center) \(degrees) \(place)")
                        XCTAssertEqual(Double(ours.y), Double(theirs.y), accuracy: 0.001, "\(center) \(degrees) \(place)")
                    }
                }
            }
        }
    }

    func test_screenPoint_northUp_putsEastRightAndSouthDown() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        // Tokyo is east of the middle of the map and north of it: right of centre and above it.
        let tokyo = projection.screenPoint(for: MapProjection.point(for: place(35.68, 139.69)))
        XCTAssertGreaterThan(tokyo.x, 500)
        XCTAssertLessThan(tokyo.y, 300)
        // A quarter of the world east of the middle is a quarter of 400 points to the right.
        let quarter = projection.screenPoint(for: FlatMapPoint(x: 0.75, y: 0.5))
        XCTAssertEqual(Double(quarter.x), 600, accuracy: 1e-9)
        XCTAssertEqual(Double(quarter.y), 300, accuracy: 1e-9)
    }

    func test_screenPoint_nextCopyOfTheWorld_isOneWorldAlong() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        let here = projection.screenPoint(for: FlatMapPoint(x: 0.2, y: 0.5))
        XCTAssertEqual(Double(projection.screenPoint(for: FlatMapPoint(x: 0.2, y: 0.5), copy: 1).x), Double(here.x) + 400, accuracy: 1e-9)
        XCTAssertEqual(Double(projection.screenPoint(for: FlatMapPoint(x: 0.2, y: 0.5), copy: -1).x), Double(here.x) - 400, accuracy: 1e-9)
    }

    func test_flatPoint_ofAScreenPoint_isThePlaceItCameFrom() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.31, y: 0.44), origin: CGPoint(x: 400, y: 250), worldWidth: 2_000, degrees: 37)
        let projection = try XCTUnwrap(map.projection())
        for place in [FlatMapPoint(x: 0.31, y: 0.44), FlatMapPoint(x: 0.9, y: 0.1), FlatMapPoint(x: 1.7, y: 0.8)] {
            let back = projection.flatPoint(at: projection.screenPoint(for: place))
            XCTAssertEqual(back.x, place.x, accuracy: 1e-9)
            XCTAssertEqual(back.y, place.y, accuracy: 1e-9)
        }
    }

    func test_init_threePlacesThatFixNoMap_isNil() {
        let center = FlatMapPoint(x: 0.5, y: 0.5)
        let probes = MapProjection.probes(around: center, step: 0.05)
        let spot = CGPoint(x: 100, y: 100)
        // A map with no size yet puts everything on one point.
        XCTAssertNil(MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: spot, southOnScreen: spot))
        // All three on one line.
        XCTAssertNil(MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: CGPoint(x: 200, y: 100), southOnScreen: CGPoint(x: 300, y: 100)))
        // Not a number.
        XCTAssertNil(MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: CGPoint(x: CGFloat.nan, y: 100), eastOnScreen: CGPoint(x: 200, y: 100),
                                   southOnScreen: CGPoint(x: 100, y: 200)))
        XCTAssertNil(MapProjection(center: FlatMapPoint(x: .nan, y: 0.5), eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: CGPoint(x: 200, y: 100), southOnScreen: CGPoint(x: 100, y: 200)))
        // Screen points so far apart that the size of the world they give is past what a number can hold.
        XCTAssertNil(MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: CGPoint(x: 1e200, y: 100), southOnScreen: CGPoint(x: 100, y: 1e200)))
        // The two other places must not be the centre itself.
        XCTAssertNil(MapProjection(center: center, eastProbe: center, southProbe: probes.south,
                                   centerOnScreen: spot, eastOnScreen: CGPoint(x: 200, y: 100), southOnScreen: CGPoint(x: 100, y: 200)))
    }

    func test_equality_sameMap_isTheSameProjection() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        XCTAssertEqual(try XCTUnwrap(map.projection()), try XCTUnwrap(map.projection()))
        let moved = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 501, y: 300), worldWidth: 400, degrees: 0)
        XCTAssertNotEqual(try XCTUnwrap(map.projection()), try XCTUnwrap(moved.projection()))
    }

    // MARK: - Copies of the world

    func test_copies_zoomedOut_everyCopyOnScreen() throws {
        // One world is 400 points wide and the view 1000: the view shows from 0.75 of a world west of the map's
        // left edge to 0.75 east of its right edge. That is three copies.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), -1...1)
        XCTAssertEqual(projection.copies(touching: view, margin: 1), -2...2)
    }

    func test_copies_zoomedIn_onlyTheOne() throws {
        let map = MadeUpMap(center: FlatMapPoint(x: 0.3, y: 0.4), origin: CGPoint(x: 500, y: 300), worldWidth: 2_000_000, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), 0...0)
        XCTAssertEqual(projection.copies(touching: view, margin: 1), -1...1)
    }

    func test_copies_overTheDateLine_bothSides() throws {
        // Centred just west of the date line, with a tenth of a world on screen: this copy and the next one east.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.99, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 10_000, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), 0...1)
    }

    func test_copies_turnedMap_goesByWhatIsEastAndWestOnScreen() throws {
        // A tall, narrow view, 300 points wide and 1000 tall, centred on the middle of a world 400 points wide.
        let tall = CGRect(x: 350, y: -200, width: 300, height: 1000)
        // North up, its 300-point width shows three quarters of one world: one copy.
        let upright = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        XCTAssertEqual(try XCTUnwrap(upright.projection()).copies(touching: tall), 0...0)
        // Turned a quarter turn, east and west run up and down the screen: its 1000-point height shows two and a
        // half worlds, which is three copies.
        let turned = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 90)
        XCTAssertEqual(try XCTUnwrap(turned.projection()).copies(touching: tall), -1...1)
    }

    func test_copies_tinyWorld_neverPassTheLimit() throws {
        // A world two points wide would put five hundred copies in the view.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 2, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), -MapProjection.copiesEachSide...MapProjection.copiesEachSide)
        XCTAssertEqual(projection.copies(touching: view, margin: 1), -MapProjection.copiesEachSide...MapProjection.copiesEachSide)
    }

    // MARK: - Shapes on screen

    func test_outlines_aBandRoundTheWorld_fillsTheViewFromSideToSide() throws {
        // One world is 400 points wide, so the 1000-point view shows three copies. A band round the middle half
        // of the world is 200 points tall here, and must cover the view's whole width with no gap between copies.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 400, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        let band = [FlatMapPoint(x: 0, y: 0.25), FlatMapPoint(x: 1, y: 0.25), FlatMapPoint(x: 1, y: 0.75), FlatMapPoint(x: 0, y: 0.75)]
        let outlines = projection.outlines(of: band, in: view)
        XCTAssertEqual(outlines.count, 3)
        XCTAssertEqual(outlines.map { area($0) }.reduce(0, +), 1000 * 200, accuracy: 1e-6)
        for outline in outlines { assertInside(outline, view) }
    }

    func test_outlines_zoomedFarIn_onNight_isTheWholeView() throws {
        // A world 200 million points wide: the view is a few city blocks, well inside the band.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.4, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 200_000_000, degrees: 37)
        let projection = try XCTUnwrap(map.projection())
        let band = [FlatMapPoint(x: 0, y: 0.25), FlatMapPoint(x: 1, y: 0.25), FlatMapPoint(x: 1, y: 0.75), FlatMapPoint(x: 0, y: 0.75)]
        let outlines = projection.outlines(of: band, in: view)
        XCTAssertEqual(outlines.count, 1)
        XCTAssertEqual(area(outlines.first ?? []), 1000 * 600, accuracy: 0.01)
        for outline in outlines { assertInside(outline, view) }
        // And well outside it there is nothing to draw.
        let elsewhere = [FlatMapPoint(x: 0.6, y: 0.25), FlatMapPoint(x: 0.9, y: 0.25), FlatMapPoint(x: 0.9, y: 0.75), FlatMapPoint(x: 0.6, y: 0.75)]
        XCTAssertTrue(projection.outlines(of: elsewhere, in: view).isEmpty)
    }
}
```

- [ ] **Step 3: Run them, expecting a build failure** (`MapProjection` doesn't exist). Todd runs `MapProjectionTests`.

- [ ] **Step 4: Write `FlatMapPoint`.** Create `Crewluv/Utils/FlatMapPoint.swift`:

```swift
//
//  FlatMapPoint.swift
//  CrewLuve
//
//  A place on the flat map, for the trip map's own drawing (`MapProjection`). Ported from CrewLu's moving map
//  (Duty/Duty/Views/Map/FlatMapFit.swift), where it shares a file with the fit.
//

import Foundation

/// A place on the flat map. `x` runs from 0 at 180 degrees west to 1 at 180 degrees east. `y` runs from 0 at the
/// map's top edge to 1 at its bottom edge. One whole world is 1 wide and 1 tall. An `x` outside 0...1 is the same
/// place on another copy of the world, further along.
nonisolated struct FlatMapPoint: Equatable {
    let x: Double
    let y: Double
}
```

- [ ] **Step 5: Write `MapProjection`.** Create `Crewluv/Utils/MapProjection.swift`:

```swift
//
//  MapProjection.swift
//  CrewLuve
//
//  Where places on the flat map are on screen, for the trip map's own drawing of the night and the routes (moving
//  map spec §10). Ported from CrewLu's moving map (Duty/Duty/Views/Map/FlatMapFit.swift) and renamed, because
//  Crewluve's `MapFit` is already the camera's rectangle. The members keep CrewLu's names, so the two files still
//  read side by side. The route lines' half is in `MapProjection+Lines.swift`.
//
//  Pure: no MapKit and no views. `TripMapShapesController` asks the map where three places near the middle of the
//  screen are, and this works out where every other place is from those three. A flat map seen from straight
//  above is only ever slid, scaled and turned, so three places fix all the others. That isn't true of a tilted
//  map, which is why the trip map never tilts.
//

import CoreGraphics
import CoreLocation
import Foundation

nonisolated struct MapProjection: Equatable {
    /// How far from the centre the other two places are asked for, as a share of the width the screen shows.
    static let probeShare: Double = 0.25

    /// The most copies of the world drawn either side of the one the projection was made on.
    static let copiesEachSide = 3

    /// The place the projection was made around.
    let center: FlatMapPoint
    /// Where `center` is on screen.
    private let originX: Double
    private let originY: Double
    /// How far a place moves on screen for one whole world to the east.
    private let eastX: Double
    private let eastY: Double
    /// How far a place moves on screen for one whole world to the south.
    private let southX: Double
    private let southY: Double

    // MARK: - Places

    /// Where a coordinate is on the flat map. A latitude beyond the map's top or bottom edge is held at that edge.
    static func point(for coordinate: CLLocationCoordinate2D) -> FlatMapPoint {
        let latitude = min(max(coordinate.latitude, -NightShade.maxLatitude), NightShade.maxLatitude)
        let y = 0.5 - log(tan(.pi / 4 + latitude * .pi / 360)) / (2 * .pi)
        return FlatMapPoint(x: coordinate.longitude / 360 + 0.5, y: y)
    }

    /// The coordinate of a place on the flat map.
    static func coordinate(for point: FlatMapPoint) -> CLLocationCoordinate2D {
        let latitude = (2 * atan(exp((0.5 - point.y) * 2 * .pi)) - .pi / 2) * 180 / .pi
        return CLLocationCoordinate2D(latitude: latitude, longitude: (point.x - 0.5) * 360)
    }

    /// The two other places to ask the map about: one `step` to the east of `center` and one `step` to the south
    /// of it. Near the map's right or bottom edge the step is taken the other way, so neither place is ever
    /// across the date line from the centre or off the map.
    static func probes(around center: FlatMapPoint, step: Double) -> (east: FlatMapPoint, south: FlatMapPoint) {
        let dx = center.x + step < 1 ? step : -step
        let dy = center.y + step < 1 ? step : -step
        return (FlatMapPoint(x: center.x + dx, y: center.y), FlatMapPoint(x: center.x, y: center.y + dy))
    }

    // MARK: - The projection

    /// The projection for a map that shows `center` at `centerOnScreen` and the two other places where the map
    /// said they are. Nil when the three don't fix a map: a number that isn't a number, or all three on one line,
    /// as when the map has no size yet.
    init?(center: FlatMapPoint, eastProbe: FlatMapPoint, southProbe: FlatMapPoint,
          centerOnScreen: CGPoint, eastOnScreen: CGPoint, southOnScreen: CGPoint) {
        let dx = eastProbe.x - center.x
        let dy = southProbe.y - center.y
        guard dx != 0, dy != 0 else { return nil }
        self.center = center
        originX = Double(centerOnScreen.x)
        originY = Double(centerOnScreen.y)
        eastX = Double(eastOnScreen.x - centerOnScreen.x) / dx
        eastY = Double(eastOnScreen.y - centerOnScreen.y) / dx
        southX = Double(southOnScreen.x - centerOnScreen.x) / dy
        southY = Double(southOnScreen.y - centerOnScreen.y) / dy
        let numbers = [center.x, center.y, originX, originY, eastX, eastY, southX, southY]
        // A whole world smaller than one square point is no map at all, and neither is one too big to measure.
        guard numbers.allSatisfy({ $0.isFinite }), worldArea.isFinite, abs(worldArea) >= 1 else { return nil }
    }

    /// The area one whole world covers on screen, in square points. Negative when the map is mirrored, which a
    /// real map never is.
    private var worldArea: Double { eastX * southY - eastY * southX }

    /// Where a place is on screen, on the copy of the world `copy` worlds to the east of the one the projection was
    /// made on.
    func screenPoint(for point: FlatMapPoint, copy: Int = 0) -> CGPoint {
        let dx = point.x + Double(copy) - center.x
        let dy = point.y - center.y
        return CGPoint(x: originX + dx * eastX + dy * southX, y: originY + dx * eastY + dy * southY)
    }

    /// The place on the flat map that is at a screen point. Its `x` isn't brought back into 0...1: the whole
    /// number part says which copy of the world the point is on.
    func flatPoint(at screenPoint: CGPoint) -> FlatMapPoint {
        let sx = Double(screenPoint.x) - originX
        let sy = Double(screenPoint.y) - originY
        return FlatMapPoint(x: center.x + (sx * southY - sy * southX) / worldArea,
                            y: center.y + (sy * eastX - sx * eastY) / worldArea)
    }

    /// The copies of the world that can show inside `rect`. 0 is the copy the projection was made on, 1 the next
    /// one to the east. `margin` adds that many copies each side, for a route line laid out past the edge of its
    /// own copy. Never more than `copiesEachSide` either side of the centre's copy, margin included.
    func copies(touching rect: CGRect, margin: Int = 0) -> ClosedRange<Int> {
        let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                       CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
        let xs = corners.map { flatPoint(at: $0).x }
        let home = center.x.rounded(.down)
        let limit = Double(Self.copiesEachSide)
        guard let west = xs.min(), let east = xs.max(), west.isFinite, east.isFinite else { return 0...0 }
        let lowest = min(max(west.rounded(.down) - Double(margin), home - limit), home + limit)
        let highest = max(min(east.rounded(.down) + Double(margin), home + limit), lowest)
        return Int(lowest)...Int(highest)
    }

    /// A closed shape on the map as the outlines to fill on screen: one for each copy of the world that shows
    /// inside `rect`, each cut off at `rect`. Copies that don't show give nothing.
    func outlines(of polygon: [FlatMapPoint], in rect: CGRect) -> [[CGPoint]] {
        guard polygon.count >= 3 else { return [] }
        var outlines: [[CGPoint]] = []
        for copy in copies(touching: rect) {
            let outline = Self.clipped(polygon: polygon.map { screenPoint(for: $0, copy: copy) }, to: rect)
            if !outline.isEmpty { outlines.append(outline) }
        }
        return outlines
    }

    // MARK: - Across the date line

    /// Lays a line out in one piece: each point is moved by a whole world, if need be, to be within half a world
    /// of the point before it. So a leg across the date line runs on past the map's edge, and doesn't jump back
    /// across the whole map. Every `x` given must be within 0...1.
    static func unwrapped(_ points: [FlatMapPoint]) -> [FlatMapPoint] {
        var result: [FlatMapPoint] = []
        result.reserveCapacity(points.count)
        var shift = 0.0
        for point in points {
            if let previous = result.last {
                // Two points within 0...1 are never more than one world apart, so one step is always enough.
                let gap = point.x + shift - previous.x
                if gap > 0.5 { shift -= 1 } else if gap < -0.5 { shift += 1 }
            }
            result.append(FlatMapPoint(x: point.x + shift, y: point.y))
        }
        return result
    }

    // MARK: - Cutting a shape off at the edge of the view

    /// The part of a closed shape that lies inside `rect`. Zoomed far in, a shape's corners can be millions of
    /// points off screen; what comes back never leaves `rect`. Where a dented shape is cut into separate parts,
    /// they come back joined by edges that run along the sides of `rect`. Filled, those edges add nothing.
    static func clipped(polygon: [CGPoint], to rect: CGRect) -> [CGPoint] {
        guard polygon.count >= 3 else { return [] }
        var allInside = true
        var allLeft = true, allRight = true, allAbove = true, allBelow = true
        for point in polygon {
            if point.x >= rect.minX { allLeft = false } else { allInside = false }
            if point.x <= rect.maxX { allRight = false } else { allInside = false }
            if point.y >= rect.minY { allAbove = false } else { allInside = false }
            if point.y <= rect.maxY { allBelow = false } else { allInside = false }
        }
        if allInside { return polygon }
        if allLeft || allRight || allAbove || allBelow { return [] }

        // One pass for each side of the rectangle: keep what's on the inner side of it, and add a corner
        // wherever an edge crosses it.
        var points = polygon
        for side in RectSide.allCases {
            guard var previous = points.last else { return [] }
            var previousInside = side.keeps(previous, in: rect)
            var kept: [CGPoint] = []
            kept.reserveCapacity(points.count + 4)
            for point in points {
                let inside = side.keeps(point, in: rect)
                if inside != previousInside { kept.append(side.crossing(from: previous, to: point, in: rect)) }
                if inside { kept.append(point) }
                previous = point
                previousInside = inside
            }
            points = kept
        }
        return points.count >= 3 ? points : []
    }

    private nonisolated enum RectSide: CaseIterable {
        case left, right, top, bottom

        func keeps(_ point: CGPoint, in rect: CGRect) -> Bool {
            switch self {
            case .left: return point.x >= rect.minX
            case .right: return point.x <= rect.maxX
            case .top: return point.y >= rect.minY
            case .bottom: return point.y <= rect.maxY
            }
        }

        /// Where the stretch from `a` to `b` crosses this side. The point is put exactly on the side.
        func crossing(from a: CGPoint, to b: CGPoint, in rect: CGRect) -> CGPoint {
            switch self {
            case .left: return CGPoint(x: rect.minX, y: a.y + (rect.minX - a.x) / (b.x - a.x) * (b.y - a.y))
            case .right: return CGPoint(x: rect.maxX, y: a.y + (rect.maxX - a.x) / (b.x - a.x) * (b.y - a.y))
            case .top: return CGPoint(x: a.x + (rect.minY - a.y) / (b.y - a.y) * (b.x - a.x), y: rect.minY)
            case .bottom: return CGPoint(x: a.x + (rect.maxY - a.y) / (b.y - a.y) * (b.x - a.x), y: rect.maxY)
            }
        }
    }
}
```

How to read it: a `FlatMapPoint` is a place on the flat map, with the whole world 1 wide and 1 tall. The projection keeps where its centre is on screen and two arrows: how far the picture moves for one whole world east, and for one whole world south. Any place is the centre plus so much of each arrow. `copies` turns the view's four corners back into places and reads off which copies of the world they fall on.

- [ ] **Step 6: Run the tests, expecting them to pass.** Todd runs `MapProjectionTests`. Expected: 19 tests, 0 failures.

- [ ] **Step 7: Ask to commit.** Suggested message: `feat(crewluv): MapProjection, CrewLu's FlatMapFit ported with its tests: where places on the flat map are on screen`.

---

### Task 3: `MapProjection`'s lines, and where each piece starts

The route lines' half of `FlatMapFit`, plus one Crewluve addition. Crewluve's lines are dashed and dotted, so each piece needs to know how far along its whole line it starts. That way a dash can be laid from the line's far end, and it stays put on the map when the near end moves or is cut off somewhere new.

**Files:**
- Create: `Crewluv/Utils/MapProjection+Lines.swift`
- Test: `CrewluvTests/MapProjectionClippingTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/MapProjectionClippingTests.swift`:

```swift
//
//  MapProjectionClippingTests.swift
//  CrewluvTests
//
//  Cutting shapes and lines off at the edge of the view, laying routes out across the date line, and where each
//  piece of a line starts, for its dashes (moving map spec §7.1, §10). Ported from CrewLu's FlatMapFitTests, with the
//  dash tests added for Crewluve's dashed and dotted lines. Every expected value is plain geometry worked out here.
//

import XCTest
import CoreGraphics
import CoreLocation
@testable import Crewluv

final class MapProjectionClippingTests: XCTestCase {

    private let view = ProjectionTestGeometry.view

    private func place(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        ProjectionTestGeometry.place(latitude, longitude)
    }

    private func area(_ outline: [CGPoint]) -> Double {
        ProjectionTestGeometry.area(outline)
    }

    private func square(_ x: Double, _ y: Double, _ side: Double) -> [CGPoint] {
        ProjectionTestGeometry.square(x, y, side)
    }

    private func assertInside(_ outline: [CGPoint], _ rect: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        ProjectionTestGeometry.assertInside(outline, rect, file: file, line: line)
    }

    /// Where in a dash pattern `patternLength` long a horizontal piece is at screen `x`.
    private func patternPosition(of piece: MapProjection.LinePiece, atX x: Double, patternLength: Double) -> Double {
        let start = Double(piece.points.first?.x ?? 0)
        let position = (Double(piece.dashPhase(patternLength: patternLength)) + x - start).truncatingRemainder(dividingBy: patternLength)
        return position < 0 ? position + patternLength : position
    }

    // MARK: - Cutting a shape off at the edge of the view

    func test_clippedPolygon_insideTheView_isUnchanged() {
        let shape = square(100, 100, 200)
        XCTAssertEqual(MapProjection.clipped(polygon: shape, to: view), shape)
    }

    func test_clippedPolygon_outsideTheView_isGone() {
        XCTAssertTrue(MapProjection.clipped(polygon: square(1100, 100, 200), to: view).isEmpty)
        XCTAssertTrue(MapProjection.clipped(polygon: square(100, -500, 200), to: view).isEmpty)
        // Outside, but not wholly to one side of the view: past the top right corner.
        let pastTheCorner = [CGPoint(x: 900, y: -300), CGPoint(x: 1300, y: 100), CGPoint(x: 1300, y: -300)]
        XCTAssertTrue(MapProjection.clipped(polygon: pastTheCorner, to: view).isEmpty)
    }

    func test_clippedPolygon_coveringTheView_becomesTheView() {
        let cut = MapProjection.clipped(polygon: square(-5_000, -5_000, 20_000), to: view)
        XCTAssertEqual(area(cut), 1000 * 600, accuracy: 1e-6)
        assertInside(cut, view)
    }

    func test_clippedPolygon_halfIn_keepsTheHalf() {
        // A 200 square, half of it past the view's right edge.
        let cut = MapProjection.clipped(polygon: square(900, 100, 200), to: view)
        XCTAssertEqual(area(cut), 100 * 200, accuracy: 1e-6)
        assertInside(cut, view)
    }

    func test_clippedPolygon_cornersAThousandMillionPointsAway_staysInsideTheView() {
        let far = 1e9
        let huge = [CGPoint(x: -far, y: -far), CGPoint(x: far, y: -far), CGPoint(x: far, y: far), CGPoint(x: -far, y: far)]
        let cut = MapProjection.clipped(polygon: huge, to: view)
        XCTAssertEqual(area(cut), 1000 * 600, accuracy: 1e-3)
        assertInside(cut, view)
        // A slanted edge from far away still crosses the view where it should: this shape is everything below
        // the line from the view's bottom left corner to its top right one.
        let half = [CGPoint(x: -far, y: 600 + far * 0.6), CGPoint(x: far + 1000, y: -far * 0.6),
                    CGPoint(x: far + 1000, y: far), CGPoint(x: -far, y: far)]
        let cutHalf = MapProjection.clipped(polygon: half, to: view)
        XCTAssertEqual(area(cutHalf), 1000 * 600 / 2, accuracy: 1)
        assertInside(cutHalf, view)
    }

    func test_clippedPolygon_dentedShape_keepsTheCorrectArea() {
        // A U: two legs 100 wide that reach down into the view, joined by a bar above it. Only the legs show.
        let u = [CGPoint(x: 200, y: -200), CGPoint(x: 600, y: -200), CGPoint(x: 600, y: 300), CGPoint(x: 500, y: 300),
                 CGPoint(x: 500, y: -100), CGPoint(x: 300, y: -100), CGPoint(x: 300, y: 300), CGPoint(x: 200, y: 300)]
        let cut = MapProjection.clipped(polygon: u, to: view)
        XCTAssertEqual(area(cut), 2 * 100 * 300, accuracy: 1e-6)
        assertInside(cut, view)
    }

    func test_clippedPolygon_tooFewCorners_isGone() {
        XCTAssertTrue(MapProjection.clipped(polygon: [CGPoint(x: 1, y: 1), CGPoint(x: 5, y: 5)], to: view).isEmpty)
        XCTAssertTrue(MapProjection.clipped(polygon: [], to: view).isEmpty)
    }

    // MARK: - Cutting a line off at the edge of the view

    func test_clippedLine_insideTheView_isUnchanged() {
        let line = [CGPoint(x: 100, y: 100), CGPoint(x: 300, y: 200), CGPoint(x: 500, y: 100)]
        XCTAssertEqual(MapProjection.clipped(line: line, to: view), [line])
    }

    func test_clippedLine_throughTheView_keepsThePartInside() {
        let line = [CGPoint(x: -500, y: 300), CGPoint(x: 1500, y: 300)]
        XCTAssertEqual(MapProjection.clipped(line: line, to: view), [[CGPoint(x: 0, y: 300), CGPoint(x: 1000, y: 300)]])
    }

    func test_clippedLine_leavesAndComesBack_givesTwoPieces() {
        let line = [CGPoint(x: 100, y: 100), CGPoint(x: 100, y: -100), CGPoint(x: 300, y: -100), CGPoint(x: 300, y: 100)]
        XCTAssertEqual(MapProjection.clipped(line: line, to: view),
                       [[CGPoint(x: 100, y: 100), CGPoint(x: 100, y: 0)], [CGPoint(x: 300, y: 0), CGPoint(x: 300, y: 100)]])
    }

    func test_clippedLine_missesTheView_givesNothing() {
        XCTAssertTrue(MapProjection.clipped(line: [CGPoint(x: -500, y: -10), CGPoint(x: 1500, y: -10)], to: view).isEmpty)
        // Both ends outside, on different sides, and the line passes outside the corner.
        XCTAssertTrue(MapProjection.clipped(line: [CGPoint(x: -100, y: 50), CGPoint(x: 50, y: -100)], to: view).isEmpty)
        XCTAssertTrue(MapProjection.clipped(line: [CGPoint(x: 5, y: 5)], to: view).isEmpty)
    }

    func test_clippedLine_fromFarAway_crossesWhereItShould() {
        let far = 1e9
        // The view's long slanted line, bottom left corner to top right, carried on a thousand million points each way.
        let pieces = MapProjection.clipped(line: [CGPoint(x: -far, y: 600 + far * 0.6), CGPoint(x: 1000 + far, y: -far * 0.6)], to: view)
        XCTAssertEqual(pieces.count, 1)
        let piece = pieces.first ?? []
        XCTAssertEqual(piece.count, 2)
        XCTAssertEqual(Double(piece.first?.x ?? -1), 0, accuracy: 0.001)
        XCTAssertEqual(Double(piece.first?.y ?? -1), 600, accuracy: 0.001)
        XCTAssertEqual(Double(piece.last?.x ?? -1), 1000, accuracy: 0.001)
        XCTAssertEqual(Double(piece.last?.y ?? -1), 0, accuracy: 0.001)
    }

    // MARK: - Where each piece of a line starts, for its dashes

    func test_clippedPieces_insideTheView_startAtTheBeginningAndKnowTheWholeLength() {
        // The long side of a 3-4-5 triangle, 500 points.
        let pieces = MapProjection.clippedPieces(line: [CGPoint(x: 100, y: 100), CGPoint(x: 400, y: 500)], to: view)
        XCTAssertEqual(pieces.count, 1)
        XCTAssertEqual(pieces.first?.startDistance ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(pieces.first?.lineLength ?? -1, 500, accuracy: 1e-9)
    }

    func test_clippedPieces_cutAtTheLeftEdge_startWhereTheCutIs() {
        let pieces = MapProjection.clippedPieces(line: [CGPoint(x: -300, y: 300), CGPoint(x: 700, y: 300)], to: view)
        XCTAssertEqual(pieces.count, 1)
        XCTAssertEqual(Double(pieces.first?.points.first?.x ?? -1), 0, accuracy: 1e-9)
        XCTAssertEqual(pieces.first?.startDistance ?? -1, 300, accuracy: 1e-9)
        XCTAssertEqual(pieces.first?.lineLength ?? -1, 1000, accuracy: 1e-9)
    }

    func test_clippedPieces_leavesAndComesBack_countTheWayRound() {
        // Up out of the view, along above it and back down: three stretches of 200 points. The second piece starts
        // where the line comes back in, 100 points down the last stretch.
        let pieces = MapProjection.clippedPieces(line: [CGPoint(x: 100, y: 100), CGPoint(x: 100, y: -100),
                                                        CGPoint(x: 300, y: -100), CGPoint(x: 300, y: 100)], to: view)
        XCTAssertEqual(pieces.map(\.startDistance), [0, 500])
        XCTAssertEqual(pieces.map(\.lineLength), [600, 600])
    }

    func test_dashPhase_isLaidFromTheLinesFarEnd() {
        let piece = MapProjection.LinePiece(points: [CGPoint(x: 0, y: 300), CGPoint(x: 700, y: 300)], startDistance: 300, lineLength: 1000)
        // 300 - 1000 = -700, which is 8 more than a whole number of 12s.
        XCTAssertEqual(Double(piece.dashPhase(patternLength: 12)), 8, accuracy: 1e-9)
        // So the pattern starts afresh exactly at the line's end, at x 700.
        XCTAssertEqual(patternPosition(of: piece, atX: 700, patternLength: 12), 0, accuracy: 1e-9)
    }

    func test_dashPhase_aPanThatMovesTheCut_keepsEachDashOnTheMap() throws {
        let line = [CGPoint(x: -300, y: 300), CGPoint(x: 700, y: 300)]
        let panned = line.map { CGPoint(x: $0.x + 50, y: $0.y) }
        let before = try XCTUnwrap(MapProjection.clippedPieces(line: line, to: view).first)
        let after = try XCTUnwrap(MapProjection.clippedPieces(line: panned, to: view).first)
        // The same place on the map is at x 401 before the pan and x 451 after it.
        XCTAssertEqual(patternPosition(of: before, atX: 401, patternLength: 12),
                       patternPosition(of: after, atX: 451, patternLength: 12), accuracy: 1e-9)
    }

    func test_dashPhase_lineShortenedAtItsStart_keepsEachDashOnTheMap() throws {
        // The line still to fly, before and after the plane has moved 37 points along it.
        let before = try XCTUnwrap(MapProjection.clippedPieces(line: [CGPoint(x: 100, y: 300), CGPoint(x: 900, y: 300)], to: view).first)
        let after = try XCTUnwrap(MapProjection.clippedPieces(line: [CGPoint(x: 137, y: 300), CGPoint(x: 900, y: 300)], to: view).first)
        XCTAssertEqual(patternPosition(of: before, atX: 500, patternLength: 12),
                       patternPosition(of: after, atX: 500, patternLength: 12), accuracy: 1e-9)
    }

    // MARK: - Across the date line

    func test_unwrapped_eastAcrossTheDateLine_runsOnPastTheEdge() {
        // Tokyo to Anchorage: longitudes 139.7 east, 170 east, 170 west, 150 west.
        let leg = [139.7, 170.0, -170.0, -150.0].map { MapProjection.point(for: place(40, $0)) }
        let xs = MapProjection.unwrapped(leg).map(\.x)
        XCTAssertEqual(xs[0], 139.7 / 360 + 0.5, accuracy: 1e-12)
        XCTAssertEqual(xs[1], 170.0 / 360 + 0.5, accuracy: 1e-12)
        XCTAssertEqual(xs[2], 190.0 / 360 + 0.5, accuracy: 1e-12)
        XCTAssertEqual(xs[3], 210.0 / 360 + 0.5, accuracy: 1e-12)
    }

    func test_unwrapped_westAcrossTheDateLine_runsOnPastTheEdge() {
        let leg = [-150.0, -170.0, 170.0, 139.7].map { MapProjection.point(for: place(40, $0)) }
        let xs = MapProjection.unwrapped(leg).map(\.x)
        XCTAssertEqual(xs[2], -190.0 / 360 + 0.5, accuracy: 1e-12)
        XCTAssertEqual(xs[3], -220.3 / 360 + 0.5, accuracy: 1e-12)
    }

    func test_unwrapped_awayFromTheDateLine_isUnchanged() {
        let leg = [FlatMapPoint(x: 0.2, y: 0.4), FlatMapPoint(x: 0.45, y: 0.3), FlatMapPoint(x: 0.69, y: 0.35)]
        XCTAssertEqual(MapProjection.unwrapped(leg), leg)
        XCTAssertTrue(MapProjection.unwrapped([]).isEmpty)
    }

    // MARK: - Lines on screen

    func test_pieces_aLegAcrossTheDateLine_isDrawnOnBothSidesOfTheMap() throws {
        // The whole world on screen, 800 points wide, centred on the middle of the map. A leg from 170 east to 170
        // west shows twice: running off the right edge of the map, and coming in at the left edge.
        let map = MadeUpMap(center: FlatMapPoint(x: 0.5, y: 0.5), origin: CGPoint(x: 500, y: 300), worldWidth: 800, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        let leg = MapProjection.unwrapped([170.0, 180.0, -170.0].map { MapProjection.point(for: place(0, $0)) })
        let pieces = projection.pieces(of: leg, in: view)
        // 170 east is 20/360 of 800 points inside the map's right edge, which is at 900: from 877.8 to 922.2.
        // The same leg one world to the west runs from 77.8 to 122.2.
        let spans = pieces.map { piece in (Double(piece.map(\.x).min() ?? 0), Double(piece.map(\.x).max() ?? 0)) }.sorted { $0.0 < $1.0 }
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].0, 100 - 800.0 * 10 / 360, accuracy: 1e-6)
        XCTAssertEqual(spans[0].1, 100 + 800.0 * 10 / 360, accuracy: 1e-6)
        XCTAssertEqual(spans[1].0, 900 - 800.0 * 10 / 360, accuracy: 1e-6)
        XCTAssertEqual(spans[1].1, 900 + 800.0 * 10 / 360, accuracy: 1e-6)
    }

    func test_pieces_justEastOfTheDateLine_drawsALegThatBeganWestOfIt() throws {
        // Zoomed in on the equator at 178 west: the view is 1.8 degrees wide, so all of it is east of the date
        // line. A leg from 170 east to 170 west is laid out running on past the map's right edge, so the part of
        // it seen here belongs to the copy of the world one to the west, which no corner of the view is on.
        let center = MapProjection.point(for: place(0, -178))
        let map = MadeUpMap(center: center, origin: CGPoint(x: 500, y: 300), worldWidth: 200_000, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        XCTAssertEqual(projection.copies(touching: view), 0...0)
        let leg = MapProjection.unwrapped([170.0, 180.0, -170.0].map { MapProjection.point(for: place(0, $0)) })
        let pieces = projection.pieces(of: leg, in: view)
        XCTAssertEqual(pieces.count, 1)
        let piece = pieces.first ?? []
        XCTAssertEqual(Double(piece.map(\.x).min() ?? -1), 0, accuracy: 1e-6)
        XCTAssertEqual(Double(piece.map(\.x).max() ?? -1), 1000, accuracy: 1e-6)
        for point in piece { XCTAssertEqual(Double(point.y), 300, accuracy: 1e-6) }
    }

    func test_pieces_zoomedFarIn_staysInsideTheView() throws {
        let center = MapProjection.point(for: place(40, -100))
        let map = MadeUpMap(center: center, origin: CGPoint(x: 500, y: 300), worldWidth: 200_000_000, degrees: 0)
        let projection = try XCTUnwrap(map.projection())
        // A leg along the 40th parallel passes straight through the middle of the view.
        let leg = MapProjection.unwrapped([-120.0, -100.0, -80.0].map { MapProjection.point(for: place(40, $0)) })
        let pieces = projection.pieces(of: leg, in: view)
        XCTAssertEqual(pieces.count, 1)
        let piece = pieces.first ?? []
        assertInside(piece, view)
        XCTAssertEqual(Double(piece.map(\.x).min() ?? -1), 0, accuracy: 1e-6)
        XCTAssertEqual(Double(piece.map(\.x).max() ?? -1), 1000, accuracy: 1e-6)
        for point in piece { XCTAssertEqual(Double(point.y), 300, accuracy: 0.01) }
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure** (`MapProjection.clipped(line:to:)` doesn't exist). Todd runs `MapProjectionClippingTests`.

- [ ] **Step 3: Write the lines' half.** Create `Crewluv/Utils/MapProjection+Lines.swift`:

```swift
//
//  MapProjection+Lines.swift
//  CrewLuve
//
//  Route lines on screen (moving map spec §7.1, §10): each copy of the world's pieces, cut off at the edge of the
//  view, ported from CrewLu's FlatMapFit. Added for Crewluve's dashed and dotted lines, which CrewLu's solid ones
//  don't need: how far along its whole line each piece starts, so a dash can be laid from the line's far end and
//  stays put on the map when the near end moves.
//

import CoreGraphics
import Foundation

nonisolated extension MapProjection {

    /// One piece of a line on screen, inside the view.
    nonisolated struct LinePiece: Equatable {
        let points: [CGPoint]
        /// How far along the whole line, uncut and on screen, `points.first` is, in points.
        let startDistance: Double
        /// The whole line's length on screen, uncut, in points.
        let lineLength: Double

        /// The phase to dash this piece with, so the pattern is laid from the line's far end. A dash then stays put
        /// on the map while the near end moves, as the plane eats into the line still to fly, or is cut off in a new
        /// place, as the map pans. `patternLength` is the pattern's dashes and gaps added up.
        func dashPhase(patternLength: Double) -> CGFloat {
            guard patternLength > 0, startDistance.isFinite, lineLength.isFinite else { return 0 }
            let phase = (startDistance - lineLength).truncatingRemainder(dividingBy: patternLength)
            return CGFloat(phase < 0 ? phase + patternLength : phase)
        }
    }

    /// A line on the map as the pieces to draw on screen: for each copy of the world near `rect`, the parts of
    /// the line inside `rect`. `line` must already be laid out in one piece (`unwrapped`).
    func pieces(of line: [FlatMapPoint], in rect: CGRect) -> [[CGPoint]] {
        linePieces(of: line, in: rect).map(\.points)
    }

    /// `pieces(of:in:)`, with how far along the line each piece starts.
    func linePieces(of line: [FlatMapPoint], in rect: CGRect) -> [LinePiece] {
        guard line.count >= 2 else { return [] }
        var pieces: [LinePiece] = []
        for copy in copies(touching: rect, margin: 1) {
            pieces += Self.clippedPieces(line: line.map { screenPoint(for: $0, copy: copy) }, to: rect)
        }
        return pieces
    }

    /// The parts of a line that lie inside `rect`, as separate pieces, in the line's own order.
    static func clipped(line: [CGPoint], to rect: CGRect) -> [[CGPoint]] {
        clippedPieces(line: line, to: rect).map(\.points)
    }

    /// `clipped(line:to:)`, with how far along the line each piece starts. Each straight stretch is cut on its own,
    /// and stretches that still share an end are joined up again.
    static func clippedPieces(line: [CGPoint], to rect: CGRect) -> [LinePiece] {
        let lineLength = zip(line, line.dropFirst()).reduce(0.0) { $0 + length(from: $1.0, to: $1.1) }
        var pieces: [LinePiece] = []
        var piece: [CGPoint] = []
        var pieceStart = 0.0
        // How far along the line the stretch being cut starts.
        var travelled = 0.0
        func finishPiece() {
            if !piece.isEmpty {
                pieces.append(LinePiece(points: piece, startDistance: pieceStart, lineLength: lineLength))
            }
            piece = []
        }
        for index in line.indices.dropFirst() {
            let a = line[index - 1]
            let b = line[index]
            defer { travelled += length(from: a, to: b) }
            guard let part = clipped(from: a, to: b, in: rect) else {
                finishPiece()
                continue
            }
            if let last = piece.last, last == part.from {
                piece.append(part.to)
            } else {
                finishPiece()
                piece = [part.from, part.to]
                pieceStart = travelled + length(from: a, to: part.from)
            }
        }
        finishPiece()
        return pieces
    }

    /// The part of one straight stretch that lies inside `rect`, or nil when none of it does. An end that is
    /// inside comes back exactly as given, so stretches that share an end can be joined up again.
    private static func clipped(from a: CGPoint, to b: CGPoint, in rect: CGRect) -> (from: CGPoint, to: CGPoint)? {
        let ax = Double(a.x), ay = Double(a.y)
        let dx = Double(b.x) - ax, dy = Double(b.y) - ay
        // `t` runs from 0 at `a` to 1 at `b`. Each side of the rectangle keeps the part where p * t <= q.
        var t0 = 0.0, t1 = 1.0
        let sides = [(-dx, ax - Double(rect.minX)), (dx, Double(rect.maxX) - ax),
                     (-dy, ay - Double(rect.minY)), (dy, Double(rect.maxY) - ay)]
        for (p, q) in sides {
            if p == 0 {
                if q < 0 { return nil }
                continue
            }
            let t = q / p
            if p < 0 {
                if t > t1 { return nil }
                t0 = max(t0, t)
            } else {
                if t < t0 { return nil }
                t1 = min(t1, t)
            }
        }
        let from = t0 <= 0 ? a : CGPoint(x: ax + t0 * dx, y: ay + t0 * dy)
        let to = t1 >= 1 ? b : CGPoint(x: ax + t1 * dx, y: ay + t1 * dy)
        return (from, to)
    }

    private static func length(from a: CGPoint, to b: CGPoint) -> Double {
        hypot(Double(b.x - a.x), Double(b.y - a.y))
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `MapProjectionClippingTests`. Expected: 24 tests, 0 failures.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): MapProjection's route lines, cut to the view, with where each piece starts so dashes stay on the map`.

---

### Task 4: `TripMapLine`

A `RouteSegment` as our drawing takes it. SwiftUI's `MapPolyline(contourStyle: .geodesic)` used to bend each flight for us. Now we break the great circle into short stretches ourselves.

**Files:**
- Create: `Crewluv/Services/TripMap/TripMapLine.swift`
- Test: `CrewluvTests/TripMapLineTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripMapLineTests.swift`:

```swift
//
//  TripMapLineTests.swift
//  CrewluvTests
//
//  Route lines as the trip map's own drawing takes them (moving map spec §7.1, §10): drives straight, flights along
//  their great circle in short stretches, and in one piece across the date line.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapLineTests: XCTestCase {

    private func airport(_ code: String) throws -> CLLocationCoordinate2D {
        try XCTUnwrap(TripMapTestLegs.coordinate(code))
    }

    private func degreesOfArc(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        GreatCircle.distance(from: start, to: end) / GreatCircle.earthRadius * 180 / .pi
    }

    func test_init_drive_isItsTwoEndsDrawnStraight() throws {
        let lex = try airport("LEX")
        let sdf = try airport("SDF")
        let line = TripMapLine(segment: RouteSegment(id: "d1-drive", coordinates: [lex, sdf], style: .drive))
        XCTAssertEqual(line.points, [MapProjection.point(for: lex), MapProjection.point(for: sdf)])
        XCTAssertEqual(line.style, .drive)
    }

    func test_init_flight_followsItsGreatCircleInStretchesOfADegreeAtMost() throws {
        let sdf = try airport("SDF")
        let cgn = try airport("CGN")
        let line = TripMapLine(segment: RouteSegment(id: "f1-upcoming", coordinates: [sdf, cgn], style: .upcoming))
        XCTAssertEqual(line.points.first, MapProjection.point(for: sdf))
        XCTAssertEqual(line.points.last, MapProjection.point(for: cgn))
        // Every point is on the great circle: going through it adds nothing to the distance.
        let total = GreatCircle.distance(from: sdf, to: cgn)
        for point in line.points {
            let place = MapProjection.coordinate(for: point)
            XCTAssertEqual(GreatCircle.distance(from: sdf, to: place) + GreatCircle.distance(from: place, to: cgn), total,
                           accuracy: 1, "\(place) is off the great circle")
        }
        for (a, b) in zip(line.points, line.points.dropFirst()) {
            XCTAssertLessThanOrEqual(degreesOfArc(from: MapProjection.coordinate(for: a), to: MapProjection.coordinate(for: b)),
                                     TripMapLine.arcStep + 1e-9)
        }
    }

    func test_init_anchorageToTokyo_runsOnPastTheDateLineInOnePiece() throws {
        let anc = try airport("ANC")
        let nrt = try airport("NRT")
        let line = TripMapLine(segment: RouteSegment(id: "f1-upcoming", coordinates: [anc, nrt], style: .upcoming))
        for (a, b) in zip(line.points, line.points.dropFirst()) {
            XCTAssertLessThan(abs(b.x - a.x), 0.5, "a jump back across the map")
        }
        // West over the date line, so Tokyo is laid out one world west of where it is.
        XCTAssertEqual(line.points.last?.x ?? 0, MapProjection.point(for: nrt).x - 1, accuracy: 1e-12)
    }

    func test_init_legSplitAtThePlane_joinsWhereThePlaneIs() throws {
        let now = TripMapTestLegs.tripStart.addingTimeInterval(4 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: now))
        let drawing = TripMapDrawing(tripMap: map, at: now)
        let flying = try XCTUnwrap(drawing.segments.first { $0.id == "f1-flying" })
        let upcoming = try XCTUnwrap(drawing.segments.first { $0.id == "f1-upcoming" })
        let flown = TripMapLine(segment: flying)
        let ahead = TripMapLine(segment: upcoming)
        XCTAssertEqual(flown.points.last, ahead.points.first)
        XCTAssertEqual(flown.style, .flying)
        XCTAssertEqual(ahead.style, .upcoming)
    }

    func test_equality_sameSegment_givesTheSameLine() throws {
        let sdf = try airport("SDF")
        let cgn = try airport("CGN")
        let segment = RouteSegment(id: "f1-flown", coordinates: [sdf, cgn], style: .flown)
        let other = RouteSegment(id: "f1-upcoming", coordinates: [sdf, cgn], style: .upcoming)
        XCTAssertEqual(TripMapLine(segment: segment), TripMapLine(segment: segment))
        XCTAssertNotEqual(TripMapLine(segment: segment), TripMapLine(segment: other))
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `TripMapLineTests`.

- [ ] **Step 3: Write `TripMapLine`.** Create `Crewluv/Services/TripMap/TripMapLine.swift`:

```swift
//
//  TripMapLine.swift
//  CrewLuve
//
//  One route line as the trip map's own drawing takes it (moving map spec §7.1, §10): places on the flat map, laid
//  out in one piece across the date line. A flight follows its great circle in straight stretches of at most a
//  degree; a drive is drawn straight, as SwiftUI's map drew it.
//

import CoreLocation

nonisolated struct TripMapLine: Equatable {
    /// The most arc between two neighbouring points of a flight's line, in degrees: about 69 miles.
    static let arcStep: Double = 1

    let style: RouteSegment.Style
    /// Each point within half a world of the one before (`MapProjection.unwrapped`).
    let points: [FlatMapPoint]

    init(segment: RouteSegment) {
        let coordinates = segment.isGeodesic ? Self.greatCircle(through: segment.coordinates) : segment.coordinates
        style = segment.style
        points = MapProjection.unwrapped(coordinates.filter(CLLocationCoordinate2DIsValid).map(MapProjection.point(for:)))
    }

    /// The great circle between each pair of neighbouring coordinates, as points at most `arcStep` apart. Every
    /// given coordinate is kept exactly, so a leg split at the plane meets at the plane.
    private static func greatCircle(through coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard let first = coordinates.first else { return [] }
        var points = [first]
        for (start, end) in zip(coordinates, coordinates.dropFirst()) {
            let degrees = GreatCircle.distance(from: start, to: end) / GreatCircle.earthRadius * 180 / .pi
            let count = max(2, Int((degrees / arcStep).rounded(.up)) + 1)
            points += GreatCircle.points(from: start, to: end, count: count).dropFirst().dropLast()
            points.append(end)
        }
        return points
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `TripMapLineTests`. Expected: 5 tests, 0 failures.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): TripMapLine, each route as flat-map points along its great circle`.

---

### Task 5: `TripMapCamera`, and `TripMap.framingRect`

Our camera value replaces SwiftUI's `MapCameraPosition` in Task 11. Until then, `camera(focusingOn:)` stays, built on the new `framingRect`, so the app keeps building.

**Files:**
- Create: `Crewluv/Services/TripMap/TripMapCamera.swift`
- Modify: `Crewluv/Views/TripMap/TripMap+Camera.swift`
- Test: `CrewluvTests/TripMapCameraTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripMapCameraTests.swift`:

```swift
//
//  TripMapCameraTests.swift
//  CrewluvTests
//
//  The trip map's camera (moving map spec §6): each framing is a new request that takes the camera back from the
//  family, and what it frames is the leg in the air or the whole trip and home.
//

import XCTest
import MapKit
@testable import Crewluv

final class TripMapCameraTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }
    private let rect = MKMapRect(x: 1_000, y: 2_000, width: 3_000, height: 4_000)

    func test_init_newCamera_isNotTheFamilysAndHasNotBeenFramedAgain() {
        let camera = TripMapCamera(framing: rect)
        XCTAssertEqual(camera.rect?.minX, 1_000)
        XCTAssertEqual(camera.rect?.minY, 2_000)
        XCTAssertEqual(camera.rect?.width, 3_000)
        XCTAssertEqual(camera.rect?.height, 4_000)
        XCTAssertFalse(camera.isPositionedByUser)
        XCTAssertFalse(camera.isAnimated)
        XCTAssertEqual(camera.framingNumber, 0)
    }

    func test_frame_afterTheFamilyMovedIt_takesTheCameraBackAsANewRequest() {
        var camera = TripMapCamera(framing: rect)
        camera.markPositionedByUser()
        camera.frame(rect, animated: true)
        XCTAssertFalse(camera.isPositionedByUser)
        XCTAssertTrue(camera.isAnimated)
        XCTAssertEqual(camera.framingNumber, 1, "the same rectangle again still moves the map")
    }

    func test_markPositionedByUser_keepsTheRequest() {
        var camera = TripMapCamera(framing: rect)
        camera.frame(nil, animated: false)
        camera.markPositionedByUser()
        XCTAssertTrue(camera.isPositionedByUser)
        XCTAssertEqual(camera.framingNumber, 1)
        XCTAssertNil(camera.rect)
    }

    func test_framingRect_inFlight_holdsTheLegAndNotTheRestOfTheTrip() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let framed = try XCTUnwrap(map.framingRect(focusingOn: map.currentLeg))
        let sdf = try XCTUnwrap(TripMapTestLegs.coordinate("SDF"))
        let cgn = try XCTUnwrap(TripMapTestLegs.coordinate("CGN"))
        let dxb = try XCTUnwrap(TripMapTestLegs.coordinate("DXB"))
        XCTAssertTrue(framed.contains(MKMapPoint(sdf)))
        XCTAssertTrue(framed.contains(MKMapPoint(cgn)))
        XCTAssertFalse(framed.contains(MKMapPoint(dxb)))
    }

    func test_framingRect_onTheGround_holdsTheWholeTripAndHome() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let framed = try XCTUnwrap(map.framingRect(focusingOn: nil))
        for code in ["SDF", "CGN", "DXB"] {
            let coordinate = try XCTUnwrap(TripMapTestLegs.coordinate(code))
            XCTAssertTrue(framed.contains(MKMapPoint(coordinate)), code)
        }
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `TripMapCameraTests`.

- [ ] **Step 3: Write `TripMapCamera`.** Create `Crewluv/Services/TripMap/TripMapCamera.swift`:

```swift
//
//  TripMapCamera.swift
//  CrewLuve
//
//  What the trip map's camera should frame, and whether the family has moved it since (moving map spec §6). The map
//  frames each new request once. A pan, pinch or double tap makes the camera the family's: the recenter button shows,
//  and automatic refits leave it alone until they ask.
//

import MapKit

nonisolated struct TripMapCamera {
    /// The flat-map rectangle to frame (`MapFit`), or nil to leave the camera where it is.
    private(set) var rect: MKMapRect?
    /// Whether moving to `rect` animates. A map's first framing never does.
    private(set) var isAnimated = false
    /// True once the family has panned or zoomed since the camera was last framed.
    private(set) var isPositionedByUser = false
    /// Goes up with every framing, so asking for the same rectangle again still moves the map.
    private(set) var framingNumber = 0

    init(framing rect: MKMapRect?) {
        self.rect = rect
    }

    /// Frames `rect` afresh, taking the camera back from the family.
    mutating func frame(_ rect: MKMapRect?, animated: Bool) {
        self.rect = rect
        isAnimated = animated
        isPositionedByUser = false
        framingNumber += 1
    }

    /// The family moved the map.
    mutating func markPositionedByUser() {
        isPositionedByUser = true
    }
}
```

- [ ] **Step 4: Add `framingRect`.** Replace the whole of `Crewluv/Views/TripMap/TripMap+Camera.swift` with:

```swift
//
//  TripMap+Camera.swift
//  CrewLuve
//
//  Where the trip map's camera looks (moving map spec §6): one leg, or the whole trip and home.
//

import MapKit
import SwiftUI

nonisolated extension TripMap {
    /// The flat-map rectangle that frames `leg`, or the whole trip and home when there's none (`MapFit`).
    func framingRect(focusingOn leg: MapLeg?) -> MKMapRect? {
        MapFit.rect(enclosing: framingCoordinates(focusingOn: leg))
    }
}

extension TripMap {
    /// SwiftUI's camera for the same rectangle.
    func camera(focusingOn leg: MapLeg?) -> MapCameraPosition {
        guard let rect = framingRect(focusingOn: leg) else { return .automatic }
        return .rect(rect)
    }
}
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `TripMapCameraTests`. Expected: 5 tests, 0 failures.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): TripMapCamera, the trip map's framing requests and whether the family moved the map`.

---

### Task 6: `TripMapClearance`

How the map keeps clear of the facts sheet or panel, without counting the safe area twice.

**Files:**
- Create: `Crewluv/Views/TripMap/TripMapClearance.swift`
- Test: `CrewluvTests/TripMapClearanceTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripMapClearanceTests.swift`:

```swift
//
//  TripMapClearanceTests.swift
//  CrewluvTests
//
//  How the full-screen map keeps clear of the facts sheet or panel (Stage 2 spec §6.1, §6.2): the margins Apple's logo
//  sits in, and the padding the camera frames inside, with the safe area counted once.
//

import XCTest
import UIKit
@testable import Crewluv

final class TripMapClearanceTests: XCTestCase {

    /// An iPhone in portrait: the Dynamic Island above, the home indicator below.
    private let portrait = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    /// An iPhone in landscape: the camera housing to one side, the home indicator below.
    private let landscape = UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59)

    func test_marginsBeyondSafeArea_noClearance_addNothing() {
        XCTAssertEqual(TripMapClearance.none.marginsBeyondSafeArea(portrait, isRightToLeft: false), .zero)
        XCTAssertEqual(TripMapClearance.none.framingPadding(safeArea: portrait, isRightToLeft: false), portrait)
    }

    func test_marginsBeyondSafeArea_sheetAboveTheHomeIndicator_addOnlyThePartAboveIt() {
        let clearance = TripMapClearance(leading: 0, bottom: 300)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(portrait, isRightToLeft: false),
                       NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 266, trailing: 0))
        XCTAssertEqual(clearance.framingPadding(safeArea: portrait, isRightToLeft: false),
                       UIEdgeInsets(top: 59, left: 0, bottom: 300, right: 0))
    }

    func test_marginsBeyondSafeArea_sheetLowerThanTheHomeIndicator_addNothing() {
        let clearance = TripMapClearance(leading: 0, bottom: 20)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(portrait, isRightToLeft: false), .zero)
        XCTAssertEqual(clearance.framingPadding(safeArea: portrait, isRightToLeft: false), portrait)
    }

    func test_framingPadding_panelOnTheLeadingEdge_framesBesideIt() {
        // The panel's trailing edge from the screen's leading edge: 59 of safe area, 16 of padding, 380 of panel
        // and 16 more.
        let clearance = TripMapClearance(leading: 471, bottom: 0)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(landscape, isRightToLeft: false),
                       NSDirectionalEdgeInsets(top: 0, leading: 412, bottom: 0, trailing: 0))
        XCTAssertEqual(clearance.framingPadding(safeArea: landscape, isRightToLeft: false),
                       UIEdgeInsets(top: 0, left: 471, bottom: 21, right: 59))
    }

    func test_framingPadding_rightToLeft_framesLeftOfThePanel() {
        let clearance = TripMapClearance(leading: 471, bottom: 0)
        XCTAssertEqual(clearance.marginsBeyondSafeArea(landscape, isRightToLeft: true),
                       NSDirectionalEdgeInsets(top: 0, leading: 412, bottom: 0, trailing: 0))
        XCTAssertEqual(clearance.framingPadding(safeArea: landscape, isRightToLeft: true),
                       UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 471))
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `TripMapClearanceTests`.

- [ ] **Step 3: Write `TripMapClearance`.** Create `Crewluv/Views/TripMap/TripMapClearance.swift`:

```swift
//
//  TripMapClearance.swift
//  CrewLuve
//
//  What the facts sheet or side panel covers of the full-screen map (Stage 2 spec §6.1, §6.2), and how the map keeps
//  clear of it: in its layout margins, where MapKit puts Apple's logo and Legal link, and in the padding the camera
//  frames inside. Both are measured from the screen's edges, so the safe area under them is counted only once.
//

import UIKit

nonisolated struct TripMapClearance: Equatable {
    /// From the map's leading edge to the panel's trailing edge, padding included.
    let leading: CGFloat
    /// From the map's bottom edge to the top of the sheet.
    let bottom: CGFloat

    static let none = TripMapClearance(leading: 0, bottom: 0)

    /// What the clearance adds to the map's layout margins: the part of each beyond the safe area, since UIKit
    /// already puts the safe area in the margins.
    func marginsBeyondSafeArea(_ safeArea: UIEdgeInsets, isRightToLeft: Bool) -> NSDirectionalEdgeInsets {
        let leadingSafeArea = isRightToLeft ? safeArea.right : safeArea.left
        return NSDirectionalEdgeInsets(top: 0, leading: max(0, leading - leadingSafeArea),
                                       bottom: max(0, bottom - safeArea.bottom), trailing: 0)
    }

    /// The padding the camera frames the trip inside: the safe area, or the sheet and the panel where they reach
    /// further. Left and right, as MapKit takes it.
    func framingPadding(safeArea: UIEdgeInsets, isRightToLeft: Bool) -> UIEdgeInsets {
        var padding = safeArea
        padding.bottom = max(safeArea.bottom, bottom)
        if isRightToLeft {
            padding.right = max(safeArea.right, leading)
        } else {
            padding.left = max(safeArea.left, leading)
        }
        return padding
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `TripMapClearanceTests`. Expected: 5 tests, 0 failures.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): TripMapClearance, the facts sheet or panel as map margins and framing padding`.

---

### Task 7: `TripMapPalette` and `TripMapMarker`

The palette becomes a `nonisolated`, `Equatable` value with colours for the airport codes. Markers carry it, so each code's colour changes with the map's style and look. `TripMapMarker` names a drawing's markers, so MapKit moves them rather than replacing them.

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapPalette.swift`
- Create: `Crewluv/Views/TripMap/TripMapMarker.swift`
- Test: `CrewluvTests/TripMapMarkerTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripMapMarkerTests.swift`:

```swift
//
//  TripMapMarkerTests.swift
//  CrewluvTests
//
//  Which markers the trip map shows at an instant, by names that stay the same while each is on the map (moving map
//  spec §5.1, §7.2).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class TripMapMarkerTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    func test_placements_inFlight_areTheAirportsAndThePlane() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let drawing = TripMapDrawing(tripMap: map, at: hours(4))
        let placements = TripMapMarker.placements(for: drawing, palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-CGN", "airport-DXB", "plane"])
        let plane = try XCTUnwrap(drawing.plane)
        XCTAssertEqual(placements["plane"]?.marker, .plane(angle: plane.angle))
        XCTAssertEqual(placements["plane"]?.coordinate.latitude ?? 0, plane.coordinate.latitude, accuracy: 1e-12)
    }

    func test_placements_onTheLayover_putTheHeartOnCologne() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: hours(12)), palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-CGN", "airport-DXB", "heart"])
        let cgn = try XCTUnwrap(TripMapTestLegs.coordinate("CGN"))
        XCTAssertEqual(placements["heart"]?.marker, .heart)
        XCTAssertEqual(placements["heart"]?.coordinate.latitude ?? 0, cgn.latitude, accuracy: 1e-12)
    }

    func test_placements_drive_nameTheCarByItsDrive() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(-1)))
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: hours(-1)), palette: .onDarkMap)
        XCTAssertEqual(placements["d1-car"]?.marker, .car)
    }

    func test_placements_airport_carriesTheMapsPalette() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(12)))
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: hours(12)), palette: .onLightMap)
        XCTAssertEqual(placements["airport-CGN"]?.marker, .airport(code: "CGN", palette: .onLightMap))
        XCTAssertNotEqual(placements["airport-CGN"]?.marker, .airport(code: "CGN", palette: .onDarkMap))
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `TripMapMarkerTests`.

- [ ] **Step 3: Rewrite the palette.** Replace the whole of `Crewluv/Views/TripMap/TripMapPalette.swift` with:

```swift
//
//  TripMapPalette.swift
//  CrewLuve
//
//  The trip map's line colours and strokes, and its airport codes' colours (moving map spec §7.1). Satellite and
//  hybrid maps are dark in both light and dark mode, so their lines and codes are light; the standard map gets the
//  system blue and dark codes in light mode.
//

import SwiftUI

nonisolated struct TripMapPalette: Equatable {
    let upcoming: Color
    let flying: Color
    let flown: Color
    let drive: Color
    /// An airport's code, and the halo that keeps it readable over the map.
    let label: Color
    let labelHalo: Color

    /// One night layer. `NightShade` stacks seven of these.
    static let night = Color(red: 0.02, green: 0.05, blue: 0.16).opacity(NightShade.layerAlpha)

    static let onDarkMap = TripMapPalette(
        upcoming: Color(red: 0.62, green: 0.76, blue: 1.0),
        flying: Color(red: 0.62, green: 0.76, blue: 1.0),
        flown: Color(white: 0.82),
        drive: .white,
        label: .white,
        labelHalo: .black.opacity(0.75)
    )

    static let onLightMap = TripMapPalette(
        upcoming: .blue.opacity(0.6),
        flying: .blue,
        flown: .gray,
        drive: .gray,
        label: Color(white: 0.12),
        labelHalo: .white
    )

    func color(for style: RouteSegment.Style) -> Color {
        switch style {
        case .upcoming: upcoming
        case .flying: flying
        case .flown: flown
        case .drive: drive
        }
    }

    func stroke(for style: RouteSegment.Style) -> StrokeStyle {
        switch style {
        case .upcoming: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 6])
        case .flying: StrokeStyle(lineWidth: 3, lineCap: .round)
        case .flown: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        case .drive: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6])
        }
    }
}
```

- [ ] **Step 4: Write `TripMapMarker`.** Create `Crewluv/Views/TripMap/TripMapMarker.swift`:

```swift
//
//  TripMapMarker.swift
//  CrewLuve
//
//  What each of the trip map's markers shows (moving map spec §5.1, §7.2), and which markers a drawing has, by names
//  that stay the same while a marker is on the map, so MapKit moves a marker instead of replacing it.
//

import CoreLocation

nonisolated enum TripMapMarker: Equatable {
    /// An airport's dot, with its code under it.
    case airport(code: String, palette: TripMapPalette)
    /// A drive's car.
    case car
    /// Where the pilot is.
    case heart
    /// The schedule's plane, pointing at `angle` (`PlaneHeading`).
    case plane(angle: Double)

    /// One marker, and where it goes.
    nonisolated struct Placement {
        let coordinate: CLLocationCoordinate2D
        let marker: TripMapMarker
    }

    /// Markers the same size share a key: a marker's view is measured again only when its key changes.
    var sizeKey: String {
        switch self {
        case .airport(let code, _): "airport-\(code)"
        case .car: "car"
        case .heart: "heart"
        case .plane: "plane"
        }
    }

    /// Every marker `drawing` shows, by name: each airport by its code, each car by its drive's own id, and the
    /// heart and the plane by themselves.
    static func placements(for drawing: TripMapDrawing, palette: TripMapPalette) -> [String: Placement] {
        var placements: [String: Placement] = [:]
        for airport in drawing.airports {
            placements["airport-\(airport.code)"] = Placement(coordinate: airport.coordinate,
                                                              marker: .airport(code: airport.code, palette: palette))
        }
        for car in drawing.cars {
            placements[car.id] = Placement(coordinate: car.coordinate, marker: .car)
        }
        if let pin = drawing.pin {
            placements["heart"] = Placement(coordinate: pin.coordinate, marker: .heart)
        }
        if let plane = drawing.plane {
            placements["plane"] = Placement(coordinate: plane.coordinate, marker: .plane(angle: plane.angle))
        }
        return placements
    }
}
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `TripMapMarkerTests`. Expected: 4 tests, 0 failures.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): TripMapMarker, the trip map's markers by name, and the airport codes' colours`.

**Batch A review:** dispatch `superpowers:code-reviewer` (sonnet) on Tasks 2–7. Give it this plan's Design section, CrewLu's `Duty/Views/Map/FlatMapFit.swift` and `DutyTests/FlatMapFitTests.swift` (read only), and the new files. Ask it to check:
- `MapProjection` matches `FlatMapFit` line for line, apart from the renames and `nonisolated`.
- No `Int(...)` of a number that isn't finite, and no divide by zero that reaches a layer.
- `clippedPieces` gives exactly the points `FlatMapFit.clipped(line:to:)` gave, with correct distances.
- Every pure type and nested type is `nonisolated`.
- Each file imports what its members need.

Handle findings, then Todd runs `MapProjectionTests`, `MapProjectionClippingTests`, `TripMapLineTests`, `TripMapCameraTests`, `TripMapClearanceTests` and `TripMapMarkerTests`.

---

### Task 8: `TripMapShapesView`

The view that draws, ported from CrewLu's `FlightMapShapesView` (one-sun plan, Task 12). Crewluve has no sun button and no fade between legs: its replay never jumps over a layover. So `clearNight` and `setNightOpacity` aren't ported. One line layer per style replaces one per leg, and dashes are baked in piece by piece.

**Files:**
- Create: `Crewluv/Views/TripMap/TripMapShapesView.swift`

- [ ] **Step 1: Write the view.** Create `Crewluv/Views/TripMap/TripMapShapesView.swift`:

```swift
//
//  TripMapShapesView.swift
//  CrewLuve
//
//  The trip map's own drawing: the night and the route lines (moving map spec §7.1, §10). Ported from CrewLu's
//  moving map (Duty/Duty/Views/Map/FlightMapShapesView.swift). MapKit keeps the base map and the markers. This view
//  sits just under the markers, takes no touches, and draws what `TripMapShapesController` hands it.
//
//  MapKit's own overlays flash when they're taken off and put on many times a second, so anything on the map that
//  changes over time is drawn here: the same layers are given new outlines, and nothing is swapped.
//

import CoreGraphics
import SwiftUI
import UIKit

final class TripMapShapesView: UIView {
    /// Shapes and lines are cut off this far outside the view, so nothing handed to the layers has a corner far
    /// off screen. It's more than half the widest line, so a cut end never shows.
    static let clipMargin: CGFloat = 50

    /// How the lines stack, bottom first: the line being flown on top.
    private static let lineOrder: [RouteSegment.Style] = [.flown, .drive, .upcoming, .flying]

    /// Called when what's drawn must be laid again: the view has changed size.
    var onNeedsRedraw: (() -> Void)?

    /// One for each of the night's sun heights, the shallowest first. They sit under the lines.
    private let nightLayers: [CAShapeLayer]
    /// One for each style of line, above the night.
    private let lineLayers: [RouteSegment.Style: CAShapeLayer]
    private var palette = TripMapPalette.onDarkMap
    private var laidOutSize: CGSize = .zero

    init(nightLayerCount: Int, nightFill: UIColor) {
        nightLayers = (0..<nightLayerCount).map { _ in
            let layer = CAShapeLayer()
            layer.fillColor = nightFill.cgColor
            layer.strokeColor = nil
            return layer
        }
        lineLayers = Dictionary(uniqueKeysWithValues: Self.lineOrder.map { style in
            let layer = CAShapeLayer()
            layer.fillColor = nil
            layer.lineJoin = .round
            return (style, layer)
        })
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = true
        isOpaque = false
        backgroundColor = .clear
        accessibilityElementsHidden = true
        for nightLayer in nightLayers { layer.addSublayer(nightLayer) }
        for lineLayer in Self.lineOrder.compactMap({ lineLayers[$0] }) { layer.addSublayer(lineLayer) }
        applyPalette()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TripMapShapesView, _: UITraitCollection) in
            // System colours differ between light and dark, so the lines' colours are resolved again.
            view.applyPalette()
        }
    }

    /// This view is only ever made in code.
    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        onNeedsRedraw?()
    }

    /// Everything is cut off at the edge of this rectangle.
    private var clipRect: CGRect {
        bounds.insetBy(dx: -Self.clipMargin, dy: -Self.clipMargin)
    }

    /// Layers animate a change of path, colour or opacity unless told not to. Here every change is one frame of a
    /// drawing that's already moving, so none of them may.
    private func withoutAnimation(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }

    // MARK: - The night

    /// Draws the night. `layers` holds one entry for each night layer, and each entry is that layer's closed
    /// shapes as places on the flat map.
    func drawNight(_ layers: [[[FlatMapPoint]]], projection: MapProjection) {
        let rect = clipRect
        withoutAnimation {
            for (index, nightLayer) in nightLayers.enumerated() {
                let path = CGMutablePath()
                if index < layers.count {
                    for shape in layers[index] {
                        for outline in projection.outlines(of: shape, in: rect) {
                            path.addLines(between: outline)
                            path.closeSubpath()
                        }
                    }
                }
                nightLayer.path = path
            }
        }
    }

    // MARK: - The lines

    /// Gives the lines their colours, widths and ends. Their dashes are laid when they're drawn.
    func setPalette(_ newPalette: TripMapPalette) {
        guard newPalette != palette else { return }
        palette = newPalette
        applyPalette()
    }

    /// Draws the route lines, each already laid out in one piece (`TripMapLine`). Dashed and dotted styles are dashed
    /// here, piece by piece, from each line's far end, so a dash stays put on the map while the plane eats into the
    /// line or a pan moves where the line is cut off.
    func drawLines(_ lines: [TripMapLine], projection: MapProjection) {
        let rect = clipRect
        var paths: [RouteSegment.Style: CGMutablePath] = [:]
        for line in lines {
            let path = paths[line.style] ?? CGMutablePath()
            let dash = palette.stroke(for: line.style).dash
            let patternLength = Double(dash.reduce(0, +))
            for piece in projection.linePieces(of: line.points, in: rect) {
                let stretch = CGMutablePath()
                stretch.addLines(between: piece.points)
                if patternLength > 0 {
                    path.addPath(stretch.copy(dashingWithPhase: piece.dashPhase(patternLength: patternLength), lengths: dash))
                } else {
                    path.addPath(stretch)
                }
            }
            paths[line.style] = path
        }
        withoutAnimation {
            for (style, lineLayer) in lineLayers {
                lineLayer.path = paths[style]
            }
        }
    }

    /// Colours are resolved with this view's own traits: a plain `cgColor` would use whatever look happened to be
    /// current when the frame ran.
    private func applyPalette() {
        withoutAnimation {
            for (style, lineLayer) in lineLayers {
                let stroke = palette.stroke(for: style)
                lineLayer.strokeColor = UIColor(palette.color(for: style)).resolvedColor(with: traitCollection).cgColor
                lineLayer.lineWidth = stroke.lineWidth
                lineLayer.lineCap = Self.layerCap(stroke.lineCap)
            }
        }
    }

    private static func layerCap(_ cap: CGLineCap) -> CAShapeLayerLineCap {
        switch cap {
        case .round: .round
        case .square: .square
        case .butt: .butt
        @unknown default: .butt
        }
    }
}
```

Three things here are easy to get wrong, and each is on purpose (CrewLu's notes):
- Every change to a layer goes through `withoutAnimation`. A bare `CAShapeLayer` animates a change of path, opacity or colour over a quarter of a second by itself, which would smear every frame.
- A line's colour is resolved with the view's own `traitCollection`.
- `init?(coder:)` returns nil. The view is only made in code, and returning nil is safer than stopping the app.

Two more, from Crewluve:
- Dashes are baked into each piece's path (`copy(dashingWithPhase:lengths:)`), not set as the layer's `lineDashPattern`. A layer has one phase, but each piece needs its own to keep its dashes on the map.
- The round cap applies to each baked dash, which is what turns the drive's `[0.5, 6]` into dots.

- [ ] **Step 2: Nothing to run yet.** Nothing uses the view until Task 11. Todd builds at the end of batch B.

---

### Task 9: Markers on MapKit

The annotation, the view that hosts the SwiftUI marker, the per-kind SwiftUI view, and the airport label. SwiftUI's map used to draw the label itself as each annotation's title.

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapMarkers.swift`
- Create: `Crewluv/Views/TripMap/TripMapMarkerView.swift`
- Create: `Crewluv/Views/TripMap/TripMapAnnotation.swift`
- Create: `Crewluv/Views/TripMap/TripMapAnnotationView.swift`

- [ ] **Step 1: Add the airport label.** Replace the whole of `Crewluv/Views/TripMap/TripMapMarkers.swift` with the following. `Airport` keeps its look; the old `TripMapView` still uses it until Task 11.

```swift
//
//  TripMapMarkers.swift
//  CrewLuve
//
//  The trip map's small fixed-size markers (moving map spec §5.1, §7.1). MapKit shows them through
//  `TripMapAnnotationView`. VoiceOver reads the card's sentence instead of these, and on the full-screen map each
//  airport's code.
//

import SwiftUI

enum TripMapMarkers {

    /// A white dot on each airport.
    struct Airport: View {
        static let dotDiameter: CGFloat = 7

        var body: some View {
            Circle()
                .fill(.white)
                .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 0.5))
                .accessibilityHidden(true)
        }
    }

    /// An airport's dot with its code under it. SwiftUI's map used to write the code itself, as each annotation's
    /// title.
    struct AirportLabel: View {
        let code: String
        let palette: TripMapPalette

        var body: some View {
            VStack(spacing: 2) {
                Airport()
                Text(code)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.label)
                    .shadow(color: palette.labelHalo, radius: 1)
                    .shadow(color: palette.labelHalo, radius: 1)
            }
            .fixedSize()
            // Grows with the text size, up to where a code would start to cover the route.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityHidden(true)
        }
    }

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

    /// A drive, parked halfway along it, or where the pilot is while driving.
    struct Car: View {
        var body: some View {
            Image(systemName: "car.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.black.opacity(0.45)))
                .overlay(Circle().stroke(.white, lineWidth: 1))
                .accessibilityHidden(true)
        }
    }
}
```

- [ ] **Step 2: Write the per-kind view.** Create `Crewluv/Views/TripMap/TripMapMarkerView.swift`:

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
        markerView
            // A marker near the screen's edge is drawn where it is, not pushed inside the safe area.
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var markerView: some View {
        switch marker {
        case .airport(let code, let palette):
            TripMapMarkers.AirportLabel(code: code, palette: palette)
        case .car:
            TripMapMarkers.Car()
        case .heart:
            TripMapMarkers.Heart()
        case .plane(let angle):
            PlaneMarker(angle: angle)
        }
    }
}
```

- [ ] **Step 3: Write the annotation.** Create `Crewluv/Views/TripMap/TripMapAnnotation.swift`:

```swift
//
//  TripMapAnnotation.swift
//  CrewLuve
//
//  One marker on the trip map as MapKit holds it: an airport, a car, the heart or the plane. Its coordinate is
//  observable, so MapKit moves the marker's view when the coordinator moves it.
//

import MapKit

/// Not isolated to the main actor: `MKAnnotation` isn't, and MapKit reads `coordinate` through Objective-C. Only the
/// coordinator, on the main actor, changes it.
nonisolated final class TripMapAnnotation: NSObject, MKAnnotation {
    /// The marker's name in `TripMapMarker.placements`.
    let id: String
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var marker: TripMapMarker

    init(id: String, coordinate: CLLocationCoordinate2D, marker: TripMapMarker) {
        self.id = id
        self.coordinate = coordinate
        self.marker = marker
    }
}
```

- [ ] **Step 4: Write the annotation view.** Create `Crewluv/Views/TripMap/TripMapAnnotationView.swift`:

```swift
//
//  TripMapAnnotationView.swift
//  CrewLuve
//
//  The view MapKit shows for a `TripMapAnnotation` (moving map spec §5.1, §7.2): the marker's SwiftUI view,
//  `TripMapMarkerView`, hosted through a `UIHostingConfiguration`, so the markers are the views SwiftUI's map drew.
//  MapKit keeps these views above the app's own drawing of the night, so they stay bright.
//

import MapKit
import SwiftUI
import UIKit

final class TripMapAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "TripMapAnnotationView"

    /// The marker's SwiftUI view: made on first use, and given each new marker after that.
    private var hostedView: (any UIView & UIContentView)?
    /// The `TripMapMarker.sizeKey` the view was last measured for.
    private var measuredSizeKey: String?

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        canShowCallout = false
        // Every marker always shows: MapKit never hides one for crowding another.
        displayPriority = .required
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: TripMapAnnotationView, _: UITraitCollection) in
            // An airport's code grows and shrinks with the text size.
            view.measuredSizeKey = nil
            view.refresh()
        }
        refresh()
    }

    /// This view is only ever made in code.
    required init?(coder: NSCoder) {
        return nil
    }

    override var annotation: (any MKAnnotation)? {
        didSet { refresh() }
    }

    /// Shows the annotation's marker as it is now. MapKit triggers this through `annotation`. The coordinator calls
    /// it after changing a marker in place, such as the plane's angle.
    func refresh() {
        guard let marker = (annotation as? TripMapAnnotation)?.marker else { return }
        let hosted = hostedView(showing: marker)
        zPriority = Self.zPriority(of: marker)
        accessibilityLabel = Self.accessibilityLabel(of: marker)
        isAccessibilityElement = accessibilityLabel != nil
        guard marker.sizeKey != measuredSizeKey else { return }
        measuredSizeKey = marker.sizeKey
        let size = hosted.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        hosted.frame = CGRect(origin: .zero, size: size)
        bounds.size = size
        centerOffset = Self.centerOffset(of: marker, size: size)
    }

    /// The hosted view, showing `marker`. Its configuration is replaced rather than the view, which keeps the SwiftUI
    /// view's state, such as where the plane is in its turn.
    private func hostedView(showing marker: TripMapMarker) -> any UIView & UIContentView {
        let configuration = UIHostingConfiguration { TripMapMarkerView(marker: marker) }
            .margins(.all, 0)
            .minSize(width: 0, height: 0)
        if let hostedView {
            hostedView.configuration = configuration
            return hostedView
        }
        let hosted = configuration.makeContentView()
        hosted.backgroundColor = .clear
        addSubview(hosted)
        hostedView = hosted
        return hosted
    }

    // MARK: - Placing each marker

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
        case .car: MKAnnotationViewZPriority(rawValue: 700)
        case .airport: .defaultUnselected
        }
    }

    /// VoiceOver reads each airport's code, as SwiftUI's map read its titles. The card's sentence and the facts
    /// describe the rest.
    private static func accessibilityLabel(of marker: TripMapMarker) -> String? {
        guard case .airport(let code, _) = marker else { return nil }
        return code
    }
}
```

- [ ] **Step 5: Nothing to run yet.** Todd builds at the end of batch B.

---

### Task 10: The map's container, our drawing's controller, and the camera's controller

The parts of CrewLu's coordinator that aren't the delegate, split into three types with private state. `TripMapShapesController` is CrewLu's `drawShapes`, `currentFit` and `placeShapesView`. `TripMapCameraController` is new: CrewLu sets regions directly and has no recenter button.

**Files:**
- Create: `Crewluv/Views/TripMap/TripMapContainerView.swift`
- Create: `Crewluv/Views/TripMap/TripMapShapesController.swift`
- Create: `Crewluv/Views/TripMap/TripMapCameraController.swift`

- [ ] **Step 1: Write the container.** Create `Crewluv/Views/TripMap/TripMapContainerView.swift`:

```swift
//
//  TripMapContainerView.swift
//  CrewLuve
//
//  Holds the trip map's `MKMapView` and says when its size or safe area changes, so the camera can frame the trip
//  for the new shape. MapKit's view isn't meant to be subclassed, so this is the view SwiftUI holds.
//

import MapKit
import UIKit

final class TripMapContainerView: UIView {
    let mapView = MKMapView()
    /// Called when the map's size or safe area changes, its first layout included.
    var onLayoutChange: (() -> Void)?
    private var laidOutSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(mapView)
    }

    /// This view is only ever made in code.
    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mapView.frame = bounds
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        mapView.layoutIfNeeded()
        onLayoutChange?()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onLayoutChange?()
    }
}
```

- [ ] **Step 2: Write the drawing's controller.** Create `Crewluv/Views/TripMap/TripMapShapesController.swift`:

```swift
//
//  TripMapShapesController.swift
//  CrewLuve
//
//  Keeps the trip map's own drawing (`TripMapShapesView`) just under MapKit's markers and laid where the map is now
//  (moving map spec §10). Ported from CrewLu's `FlightMapUIView.Coordinator` (`drawShapes`, `currentFit` and
//  `placeShapesView`), without the sun button and the fade between legs, which Crewluve's map doesn't have.
//

import CoreGraphics
import Foundation
import MapKit
import SwiftUI
import UIKit

final class TripMapShapesController {
    private let shapesView = TripMapShapesView(nightLayerCount: NightShade.sunDepths.count,
                                               nightFill: UIColor(TripMapPalette.night))
    private weak var mapView: MKMapView?
    /// The view MapKit keeps the markers' views in. Our drawing sits just under it.
    private weak var annotationContainer: UIView?
    private var hasLoggedFallback = false
    /// The night's shapes on the flat map, one entry for each of `NightShade.sunDepths`, and the moment they're for.
    private var nightShapes: [[[FlatMapPoint]]] = []
    private var nightDate: Date?
    private var lines: [TripMapLine] = []
    /// The projection the layers were last laid with, and whether the night and the lines have been laid since they
    /// last changed. A draw that would change none of these leaves the layers alone.
    private var drawnProjection: MapProjection?
    private var isNightDrawn = false
    private var areLinesDrawn = false

    init(mapView: MKMapView) {
        self.mapView = mapView
        shapesView.onNeedsRedraw = { [weak self] in self?.redrawEverything() }
    }

    func tearDown() {
        shapesView.onNeedsRedraw = nil
        shapesView.removeFromSuperview()
    }

    // MARK: - What to draw

    func setPalette(_ palette: TripMapPalette) {
        shapesView.setPalette(palette)
    }

    /// The night for `date`, worked out again only when the time has moved.
    func setNight(at date: Date) {
        guard date != nightDate else { return }
        nightShapes = NightShade.layers(at: date).map { layer in
            layer.map { shape in shape.map(MapProjection.point(for:)) }
        }
        nightDate = date
        isNightDrawn = false
    }

    func setLines(_ newLines: [TripMapLine]) {
        guard newLines != lines else { return }
        lines = newLines
        areLinesDrawn = false
    }

    /// MapKit has shown a marker's view. The view holding it is where every marker is kept.
    func noteAnnotationContainer(_ container: UIView?) {
        guard let container else { return }
        annotationContainer = container
        draw()
    }

    // MARK: - Drawing

    /// Draws the night and the lines where the map shows them now. Called on every update, all through a pan, pinch
    /// or camera move, when the map settles, and when the map or our view changes size. The layers are laid again
    /// only when the map, the night or the lines have changed since the last draw.
    func draw() {
        guard let mapView else { return }
        placeShapesView(in: mapView)
        guard shapesView.superview != nil, let projection = currentProjection(in: mapView) else { return }
        let mapMoved = projection != drawnProjection
        drawnProjection = projection
        if mapMoved || !isNightDrawn {
            shapesView.drawNight(nightShapes, projection: projection)
            isNightDrawn = true
        }
        if mapMoved || !areLinesDrawn {
            shapesView.drawLines(lines, projection: projection)
            areLinesDrawn = true
        }
    }

    /// Our view has changed size: everything is laid again.
    private func redrawEverything() {
        drawnProjection = nil
        draw()
    }

    /// Asks the map where three places are on screen: the middle of what it shows, a place a short way east of that,
    /// and a place a short way south of it. Where everything else is follows from those three (`MapProjection`). Nil
    /// while the map has no size.
    private func currentProjection(in mapView: MKMapView) -> MapProjection? {
        guard shapesView.bounds.width > 0, shapesView.bounds.height > 0 else { return nil }
        // How much of one world's width the map is showing.
        let shown = mapView.visibleMapRect.size.width / MKMapSize.world.width
        guard shown.isFinite, shown > 0 else { return nil }
        let center = MapProjection.point(for: mapView.centerCoordinate)
        let probes = MapProjection.probes(around: center, step: min(shown, 1) * MapProjection.probeShare)
        func onScreen(_ point: FlatMapPoint) -> CGPoint {
            mapView.convert(MapProjection.coordinate(for: point), toPointTo: shapesView)
        }
        return MapProjection(center: center, eastProbe: probes.east, southProbe: probes.south,
                             centerOnScreen: onScreen(center), eastOnScreen: onScreen(probes.east),
                             southOnScreen: onScreen(probes.south))
    }

    /// Keeps our drawing just under the view the map holds its markers' views in, so the markers stay above the
    /// night. That view is reached through a marker view's own parent, so no private name is used. Until the map has
    /// made a marker's view there's nothing to go under, and our drawing goes just above the map's own content.
    private func placeShapesView(in mapView: MKMapView) {
        // The map's own content view doesn't resize what's put in it. So on every draw, whatever holds our view, our
        // view is given its size.
        defer {
            if let holder = shapesView.superview, shapesView.frame != holder.bounds {
                shapesView.frame = holder.bounds
                drawnProjection = nil
            }
        }
        if let container = annotationContainer, !container.isDescendant(of: mapView) {
            // The map has thrown that view away. Look again.
            annotationContainer = nil
        }
        if annotationContainer == nil {
            annotationContainer = mapView.annotations.lazy.compactMap { mapView.view(for: $0)?.superview }.first
        }
        if let container = annotationContainer {
            if container !== mapView, let host = container.superview {
                let siblings = host.subviews
                let ours = siblings.firstIndex(of: shapesView)
                if ours == nil || ours.map({ $0 + 1 }) != siblings.firstIndex(of: container) {
                    host.insertSubview(shapesView, belowSubview: container)
                    drawnProjection = nil
                }
                return
            }
            // The markers aren't kept the way this was written for. The night would dim them.
            if !hasLoggedFallback {
                hasLoggedFallback = true
                debugLog("Trip map: no view to put the night under. It's drawn over the markers.")
            }
        }
        if !shapesView.isDescendant(of: mapView) {
            mapView.insertSubview(shapesView, at: min(1, mapView.subviews.count))
            drawnProjection = nil
        }
    }
}
```

- [ ] **Step 3: Write the camera's controller.** Create `Crewluv/Views/TripMap/TripMapCameraController.swift`:

```swift
//
//  TripMapCameraController.swift
//  CrewLuve
//
//  The trip map's camera (moving map spec §6, Stage 2 spec §6.1, §6.2). It frames each new `TripMapCamera` request,
//  keeps the map's margins (where MapKit puts Apple's logo and Legal link) and its framing clear of the facts sheet or
//  panel, and notices when the family moves the map themselves.
//

import MapKit
import UIKit

final class TripMapCameraController: NSObject, UIGestureRecognizerDelegate {
    /// The family has panned, pinched or double-tapped the map.
    var onUserMoved: (() -> Void)?
    /// The camera was framed without an animation, which MapKit needn't report.
    var onFramedWithoutAnimation: (() -> Void)?

    private weak var mapView: MKMapView?
    /// The map's own margins, read before it's on screen, so they hold no safe area.
    private let baseMargins: NSDirectionalEdgeInsets
    private var clearance = TripMapClearance.none
    /// The full-screen map keeps clear of the screen's safe area. The card's map ignores it, so a card scrolled under
    /// the status bar keeps its camera and its logo where they are.
    private var respectsSafeArea = false
    private var appliedMargins: NSDirectionalEdgeInsets?
    /// The request last framed, and the size and padding it was framed for.
    private var framedNumber: Int?
    private var framedSize: CGSize = .zero
    private var framedPadding: UIEdgeInsets = .zero

    init(mapView: MKMapView) {
        self.mapView = mapView
        baseMargins = mapView.directionalLayoutMargins
        super.init()
        observeGestures(on: mapView)
    }

    // MARK: - Updates

    /// SwiftUI's latest camera, clearance and kind of map.
    func update(camera: TripMapCamera, clearance newClearance: TripMapClearance, respectsSafeArea newRespectsSafeArea: Bool) {
        clearance = newClearance
        respectsSafeArea = newRespectsSafeArea
        applyMargins()
        frameIfNeeded(camera)
    }

    /// The map's size or safe area has changed.
    func layoutDidChange(camera: TripMapCamera) {
        applyMargins()
        frameIfNeeded(camera)
    }

    // MARK: - Margins and framing

    private var safeArea: UIEdgeInsets {
        respectsSafeArea ? (mapView?.safeAreaInsets ?? .zero) : .zero
    }

    private var isRightToLeft: Bool {
        mapView?.effectiveUserInterfaceLayoutDirection == .rightToLeft
    }

    /// UIKit adds the safe area to the margins itself, so only the clearance beyond it goes on.
    private func applyMargins() {
        guard let mapView else { return }
        if mapView.insetsLayoutMarginsFromSafeArea != respectsSafeArea {
            mapView.insetsLayoutMarginsFromSafeArea = respectsSafeArea
        }
        let extra = clearance.marginsBeyondSafeArea(safeArea, isRightToLeft: isRightToLeft)
        let margins = NSDirectionalEdgeInsets(top: baseMargins.top + extra.top,
                                              leading: baseMargins.leading + extra.leading,
                                              bottom: baseMargins.bottom + extra.bottom,
                                              trailing: baseMargins.trailing + extra.trailing)
        guard margins != appliedMargins else { return }
        appliedMargins = margins
        mapView.directionalLayoutMargins = margins
    }

    /// Frames the camera's rectangle when it's a new request, or when the map's size, safe area or clearance has
    /// changed and the family hasn't moved the map. The first framing, as the map opens, is never animated.
    private func frameIfNeeded(_ camera: TripMapCamera) {
        guard let mapView, mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }
        let padding = clearance.framingPadding(safeArea: safeArea, isRightToLeft: isRightToLeft)
        let isNewRequest = camera.framingNumber != framedNumber
        let hasLayoutChanged = mapView.bounds.size != framedSize || padding != framedPadding
        guard isNewRequest || (hasLayoutChanged && !camera.isPositionedByUser) else { return }
        let isAnimated = isNewRequest && framedNumber != nil && camera.isAnimated
        framedNumber = camera.framingNumber
        framedSize = mapView.bounds.size
        framedPadding = padding
        guard let rect = camera.rect else { return }
        mapView.setVisibleMapRect(rect, edgePadding: padding, animated: isAnimated)
        if !isAnimated { onFramedWithoutAnimation?() }
    }

    // MARK: - The family moving the map

    /// Watches for the map's own gestures without taking part in them: each recognizer works alongside MapKit's and
    /// never cancels or holds back a touch.
    private func observeGestures(on mapView: MKMapView) {
        let pan = UIPanGestureRecognizer()
        // A trackpad's two-finger scroll pans the map on iPad too.
        pan.allowedScrollTypesMask = .all
        let doubleTap = UITapGestureRecognizer()
        doubleTap.numberOfTapsRequired = 2
        let twoFingerTap = UITapGestureRecognizer()
        twoFingerTap.numberOfTouchesRequired = 2
        for recognizer in [pan, UIPinchGestureRecognizer(), doubleTap, twoFingerTap] {
            recognizer.addTarget(self, action: #selector(mapGestureChanged(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            mapView.addGestureRecognizer(recognizer)
        }
    }

    /// A pan or pinch says so as it begins, a tap once it's recognized.
    @objc private func mapGestureChanged(_ recognizer: UIGestureRecognizer) {
        guard recognizer.state == .began || recognizer.state == .ended else { return }
        onUserMoved?()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}
```

- [ ] **Step 4: Todd builds.** Todd presses ⌘B in Xcode with the Crewluv scheme. Expected: the build succeeds, with no warnings in the new files. The old `TripMapView` still draws the map, because nothing uses these yet.
  - A build error in a new file: fix it here.
  - A warning about actor isolation: check ground rule 5 first.

- [ ] **Step 5: Ask to commit Tasks 8–10 together.** Suggested message: `feat(crewluv): the trip map's own drawing view, MapKit markers that host the SwiftUI ones, and the camera and drawing controllers (not used yet)`.

---

### Task 11: The swap

Everything that changes at once for the app to keep building: the style's configuration, the coordinator, `TripMapView`, the card, the screen, the camera extension, and the removals.

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapStyle.swift`
- Create: `Crewluv/Views/TripMap/TripMapCoordinator.swift`
- Rewrite: `Crewluv/Views/TripMap/TripMapView.swift`
- Modify: `Crewluv/Views/TripMap/TripMap+Camera.swift`
- Modify: `Crewluv/Views/TripMap/TripMapCard.swift`
- Modify: `Crewluv/Views/TripMap/TripMapScreen.swift`
- Modify: `Crewluv/Services/TripMap/TripMapDrawing.swift`
- Delete: `Crewluv/Services/TripMap/NightBand.swift`
- Modify: `CrewluvTests/TripMapDrawingTests.swift`

- [ ] **Step 1: Give the styles their MapKit configuration.** Replace the whole of `Crewluv/Views/TripMap/TripMapStyle.swift` with:

```swift
//
//  TripMapStyle.swift
//  CrewLuve
//
//  The map styles the full-screen map's style button cycles through, as on CrewLu's moving map (moving map spec §6).
//  Kept flat: Apple lights its 3D globe for the real clock, never the replay's, so the night drawn here is the only one.
//

import MapKit
import SwiftUI

enum TripMapStyle: CaseIterable {
    case hybrid, standard, imagery

    var next: TripMapStyle {
        switch self {
        case .hybrid: .standard
        case .standard: .imagery
        case .imagery: .hybrid
        }
    }

    /// The style's name for VoiceOver.
    var name: String {
        switch self {
        case .hybrid: "Hybrid"
        case .standard: "Map"
        case .imagery: "Satellite"
        }
    }

    /// MapKit's configuration for the style, flat and without points of interest.
    var configuration: MKMapConfiguration {
        switch self {
        case .hybrid:
            let configuration = MKHybridMapConfiguration(elevationStyle: .flat)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        case .standard:
            let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        case .imagery:
            return MKImageryMapConfiguration(elevationStyle: .flat)
        }
    }

    /// The standard map is light only in light mode; hybrid and satellite are always dark.
    func palette(for colorScheme: ColorScheme) -> TripMapPalette {
        self == .standard && colorScheme == .light ? .onLightMap : .onDarkMap
    }
}
```

- [ ] **Step 2: Write the coordinator.** Create `Crewluv/Views/TripMap/TripMapCoordinator.swift`:

```swift
//
//  TripMapCoordinator.swift
//  CrewLuve
//
//  Runs the trip map's `MKMapView` for `TripMapView` (moving map spec §7.1, §10): the style, the markers as
//  annotations, and each update's drawing. The night and the lines are `TripMapShapesController`'s, and the camera is
//  `TripMapCameraController`'s. In shape it's CrewLu's `FlightMapUIView.Coordinator` without its display link: the
//  screen's and the card's timelines drive every update.
//

import MapKit
import SwiftUI
import UIKit

final class TripMapCoordinator: NSObject, MKMapViewDelegate {
    var parent: TripMapView

    private weak var container: TripMapContainerView?
    private var shapes: TripMapShapesController?
    private var cameraController: TripMapCameraController?
    /// The markers on the map, by `TripMapMarker.placements`' names.
    private var annotations: [String: TripMapAnnotation] = [:]
    private var appliedStyle: TripMapStyle?

    private var mapView: MKMapView? { container?.mapView }

    init(parent: TripMapView) {
        self.parent = parent
        super.init()
    }

    // MARK: - Lifecycle

    /// Sets up a new map. Called once, from `makeUIView`, before the map is on screen: the camera reads the map's own
    /// margins then, before any safe area is in them.
    func attach(to container: TripMapContainerView) {
        self.container = container
        let mapView = container.mapView
        mapView.delegate = self
        mapView.register(TripMapAnnotationView.self, forAnnotationViewWithReuseIdentifier: TripMapAnnotationView.reuseIdentifier)
        mapView.showsCompass = false
        mapView.showsScale = false
        // North stays up and the map never tilts: `PlaneHeading` aims the plane from coordinates alone, and
        // `MapProjection` is right only for a map seen from straight above.
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        shapes = TripMapShapesController(mapView: mapView)
        let cameraController = TripMapCameraController(mapView: mapView)
        cameraController.onUserMoved = { [weak self] in self?.cameraWasMovedByUser() }
        cameraController.onFramedWithoutAnimation = { [weak self] in self?.shapes?.draw() }
        self.cameraController = cameraController
        container.onLayoutChange = { [weak self] in self?.layoutDidChange() }
    }

    /// Lets go of the map. Nothing calls back into this coordinator afterwards.
    func tearDown() {
        container?.onLayoutChange = nil
        mapView?.delegate = nil
        shapes?.tearDown()
        shapes = nil
        cameraController = nil
    }

    // MARK: - Updates

    /// Brings the map up to date with SwiftUI's latest: every tick of the screen's or the card's timeline, and every
    /// change of camera, clearance, style or look.
    func update(colorScheme: ColorScheme) {
        guard let mapView else { return }
        let isFullScreen = parent.isFullScreen
        mapView.isUserInteractionEnabled = isFullScreen
        // On the card, the card is one VoiceOver element: its button's sentence (moving map spec §14).
        mapView.accessibilityElementsHidden = !isFullScreen
        if appliedStyle != parent.style {
            appliedStyle = parent.style
            mapView.preferredConfiguration = parent.style.configuration
        }
        let palette = parent.style.palette(for: colorScheme)
        shapes?.setPalette(palette)
        let drawing = TripMapDrawing(tripMap: parent.tripMap, at: parent.date)
        syncAnnotations(with: TripMapMarker.placements(for: drawing, palette: palette), on: mapView)
        shapes?.setNight(at: parent.date)
        shapes?.setLines(drawing.segments.map(TripMapLine.init(segment:)))
        cameraController?.update(camera: parent.camera, clearance: parent.clearance, respectsSafeArea: isFullScreen)
        shapes?.draw()
    }

    /// The map's size or safe area has changed.
    private func layoutDidChange() {
        cameraController?.layoutDidChange(camera: parent.camera)
        shapes?.draw()
    }

    /// The family moved the map: the recenter button shows, and automatic refits leave it alone.
    private func cameraWasMovedByUser() {
        guard !parent.camera.isPositionedByUser else { return }
        parent.camera.markPositionedByUser()
    }

    /// Adds, moves, changes and removes markers to match `placements`. A marker that stays keeps its annotation, so
    /// MapKit moves its view.
    private func syncAnnotations(with placements: [String: TripMapMarker.Placement], on mapView: MKMapView) {
        let gone = annotations.keys.filter { placements[$0] == nil }
        mapView.removeAnnotations(gone.compactMap { annotations.removeValue(forKey: $0) })
        var added: [TripMapAnnotation] = []
        for (id, placement) in placements {
            guard let annotation = annotations[id] else {
                let annotation = TripMapAnnotation(id: id, coordinate: placement.coordinate, marker: placement.marker)
                annotations[id] = annotation
                added.append(annotation)
                continue
            }
            if annotation.coordinate.latitude != placement.coordinate.latitude
                || annotation.coordinate.longitude != placement.coordinate.longitude {
                annotation.coordinate = placement.coordinate
            }
            if annotation.marker != placement.marker {
                annotation.marker = placement.marker
                (mapView.view(for: annotation) as? TripMapAnnotationView)?.refresh()
            }
        }
        mapView.addAnnotations(added)
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        guard annotation is TripMapAnnotation else { return nil }
        return mapView.dequeueReusableAnnotationView(withIdentifier: TripMapAnnotationView.reuseIdentifier, for: annotation)
    }

    /// Any marker's view shows where MapKit keeps them all. Our drawing goes just under that view.
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        shapes?.noteAnnotationContainer(views.first?.superview)
    }

    /// Called all through a pan, pinch or camera move: our drawing is laid where the map now is.
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        shapes?.draw()
    }

    /// Called once the map has settled after any change in what it shows. When the map itself changes size this is
    /// the call MapKit makes (CrewLu found this), so the drawing is laid again here too.
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        shapes?.draw()
    }
}
```

- [ ] **Step 3: Rewrite `TripMapView`.** Replace the whole of `Crewluv/Views/TripMap/TripMapView.swift` with:

```swift
//
//  TripMapView.swift
//  CrewLuve
//
//  The trip map itself (moving map spec §7.1, §10): Apple's map in an `MKMapView`, with the markers as MapKit
//  annotations and the night and the route lines drawn in our own view just under them, so nothing on the map is
//  swapped as a replay runs. It renders `TripMapDrawing` and decides nothing. North stays up and the map never tilts:
//  `PlaneHeading` aims the plane from coordinates alone, and `MapProjection` is right only for a map seen from
//  straight above.
//

import SwiftUI

struct TripMapView: UIViewRepresentable {
    let tripMap: TripMap
    let date: Date
    let style: TripMapStyle
    @Binding var camera: TripMapCamera
    /// What the facts sheet or panel covers: the camera frames the trip clear of it, and Apple's logo sits beside it.
    var clearance: TripMapClearance = .none
    /// The full-screen map: it pans and zooms, VoiceOver can explore it, and it keeps clear of the safe area. The
    /// card's map does none of these.
    var isFullScreen = false

    func makeCoordinator() -> TripMapCoordinator {
        TripMapCoordinator(parent: self)
    }

    func makeUIView(context: Context) -> TripMapContainerView {
        let container = TripMapContainerView()
        context.coordinator.attach(to: container)
        return container
    }

    func updateUIView(_ container: TripMapContainerView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(colorScheme: context.environment.colorScheme)
    }

    static func dismantleUIView(_ container: TripMapContainerView, coordinator: TripMapCoordinator) {
        coordinator.tearDown()
    }
}
```

- [ ] **Step 4: Drop SwiftUI's camera.** Replace the whole of `Crewluv/Views/TripMap/TripMap+Camera.swift` with:

```swift
//
//  TripMap+Camera.swift
//  CrewLuve
//
//  Where the trip map's camera looks (moving map spec §6): one leg, or the whole trip and home.
//

import MapKit

nonisolated extension TripMap {
    /// The flat-map rectangle that frames `leg`, or the whole trip and home when there's none (`MapFit`).
    func framingRect(focusingOn leg: MapLeg?) -> MKMapRect? {
        MapFit.rect(enclosing: framingCoordinates(focusingOn: leg))
    }
}
```

- [ ] **Step 5: The card.** Replace the whole of `Crewluv/Views/TripMap/TripMapCard.swift` with the following. Against `30cb4dd`'s version, checked in Task 1, the only changes are: `camera` replaces `position`, `refit()` is new, the `TripMapView` call changes, and `import MapKit` goes.

```swift
//
//  TripMapCard.swift
//  CrewLuve
//
//  The trip map on the status screen (moving map spec §5, Stage 2 spec §6.4, §6.5). In flight it follows the plane,
//  with the headline fact on its chip; on the ground it shows the whole trip with a heart where the pilot is; at home,
//  the next trip, or for a day after a trip, its recap. Tapping the map opens it full screen.
//

import SwiftUI

struct TripMapCard: View {
    let tripMap: TripMap
    let status: SharedPilotStatus
    let storyStore: LegStoryStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var camera: TripMapCamera
    @State private var isShowingFullScreen = false

    init(tripMap: TripMap, status: SharedPilotStatus, storyStore: LegStoryStore) {
        self.tripMap = tripMap
        self.status = status
        self.storyStore = storyStore
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg)))
    }

    var body: some View {
        // Read outside the timeline, so the card updates as soon as the stories arrive, not at the next tick.
        let facts = storyStore.facts(for: tripMap, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
        // The plane moves about a pixel in ten seconds at this size, as today's map refreshed.
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let cardChips = chips(from: facts, at: context.date)
            VStack(spacing: 0) {
                mapButton(facts: facts, chips: cardChips, at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(cardChips)
                }
                if tripMap.isInFlight, status.hasFlightDelay, let delay = status.effectiveFlightDelayMinutes {
                    FlightDelayBanner(delayMinutes: delay)
                }
                bar(facts: facts, at: context.date)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .task(id: LegStoryStore.preparationKey(for: tripMap)) {
            await storyStore.prepare(tripMap)
        }
        .onChange(of: tripMap.mode) { refit() }
        .onChange(of: tripMap.legs.map(\.id)) { refit() }
        .fullScreenCover(isPresented: $isShowingFullScreen) {
            TripMapScreen(tripMap: tripMap, storyStore: storyStore, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
        }
    }

    /// Frames the leg in the air, or the whole trip, afresh when the trip's state or legs change.
    private func refit() {
        camera.frame(tripMap.framingRect(focusingOn: tripMap.currentLeg), animated: false)
    }

    /// Stage 1's chips, with the headline fact on the bottom one in flight.
    private func chips(from facts: TripFacts, at date: Date) -> (top: String?, bottom: String?) {
        let chips = TripMapWording.cardChips(for: tripMap, at: date)
        guard tripMap.isInFlight else { return chips }
        return (chips.top, facts.headline(at: date) ?? chips.bottom)
    }

    private func mapButton(facts: TripFacts, chips: (top: String?, bottom: String?), at date: Date) -> some View {
        Button {
            isShowingFullScreen = true
        } label: {
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, camera: $camera)
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top) }
                .overlay(alignment: .bottomLeading) { overlayChip(chips.bottom, systemImage: bottomChipSymbol) }
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(facts.cardSummary(now: date, pilotName: status.pilotFirstName))
        .accessibilityHint(tripMap.mode == .recap ? "Opens the map to replay the trip" : "Opens the full-screen map")
    }

    @ViewBuilder
    private func bar(facts: TripFacts, at date: Date) -> some View {
        if let leg = tripMap.currentLeg {
            TripMapInFlightBar(leg: leg)
        } else if tripMap.mode == .recap {
            TripRecapBar(tiles: facts.recapTiles, longest: facts.recapLongestLine)
        } else {
            TripMapStatsBar(items: TripMapWording.statsItems(for: tripMap, at: date,
                                                             dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays))
        }
    }

    @ViewBuilder
    private func overlayChip(_ text: String?, systemImage: String? = nil) -> some View {
        if let text, !dynamicTypeSize.isAccessibilitySize {
            TripMapChip(text: text, systemImage: systemImage)
                .padding(10)
        }
    }

    /// The recap's "Replay the trip" plays.
    private var bottomChipSymbol: String? {
        tripMap.mode == .recap ? "play.fill" : nil
    }

    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14).
    private func stackedChips(_ chips: (top: String?, bottom: String?)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let top = chips.top {
                Text(top)
            }
            if let bottom = chips.bottom {
                if let bottomChipSymbol {
                    Label(bottom, systemImage: bottomChipSymbol)
                } else {
                    Text(bottom)
                }
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 10)
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 6: The screen.** Replace the whole of `Crewluv/Views/TripMap/TripMapScreen.swift` with the following. Against `30cb4dd`'s version, checked in Task 1, the only changes are:
  - `camera` replaces `position`;
  - the `TripMapView` call takes the camera and the clearance, and loses the two `.safeAreaPadding`s;
  - `isShowingRecenter` reads `camera.isPositionedByUser`;
  - `nightStep` goes;
  - `refit` calls `camera.frame`;
  - `import MapKit` goes.

```swift
//
//  TripMapScreen.swift
//  CrewLuve
//
//  The full-screen trip map (moving map spec §6, Stage 2 spec §6): pan and zoom, change the style, replay the trip and
//  read its facts. On iPhone the facts are a sheet you drag up; on iPad and in landscape, a panel down the leading
//  edge. A recap opens paused at its trip's start. Weather on landing is fetched while the screen is open.
//

import SwiftUI

struct TripMapScreen: View {
    let tripMap: TripMap
    let storyStore: LegStoryStore
    let dayNumber: Int?
    let totalDays: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        _clock = State(initialValue: Self.clock(for: tripMap))
        _camera = State(initialValue: TripMapCamera(framing: tripMap.framingRect(focusingOn: tripMap.currentLeg)))
    }

    var body: some View {
        // Once per update, not per frame: the facts change as their stories and forecasts arrive.
        let facts = self.facts
        // Every second live; about 30 times a second while a replay runs. The map draws its night and lines for each
        // tick's time.
        TimelineView(.periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1)) { context in
            let time = clock.time(at: context.date)
            screen(time: time, now: context.date, facts: facts)
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID)
                }
        }
        .sheet(isPresented: isShowingSheet, onDismiss: finishClosing) {
            FactsSheet(facts: facts, clock: $clock, stop: $sheetStop, screenHeight: screenFrame.height, height: $sheetHeight)
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
            clock = Self.clock(for: tripMap)
        }
    }

    /// Live, or for a recap paused at its trip's start. A short leg slows the replay while it moves.
    private static func clock(for tripMap: TripMap) -> TripReplayClock {
        let legs = replayLegs(of: tripMap)
        return tripMap.mode == .recap
            ? TripReplayClock(span: tripMap.span, legs: legs, pausedAt: tripMap.span.start)
            : TripReplayClock(span: tripMap.span, legs: legs)
    }

    /// Each drive and flight, from its start to its end with any delay.
    private static func replayLegs(of tripMap: TripMap) -> [TripReplayClock.Stretch] {
        tripMap.legs.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
    }

    private var facts: TripFacts {
        storyStore.facts(for: tripMap, forecasts: weather.forecasts, dayNumber: dayNumber, totalDays: totalDays)
    }

    @ViewBuilder
    private func screen(time: Date, now: Date, facts: TripFacts) -> some View {
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
                FactsPanel(facts: facts, clock: $clock, time: time, now: now, isExpanded: $isPanelExpanded)
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

- [ ] **Step 7: Remove the night's step.** In `Crewluv/Services/TripMap/TripMapDrawing.swift`, replace:

```swift
        self.pin = tripMap.pilotLocation(at: date)
    }

    /// `date` held back to a whole number of `step` seconds, so the night is redrawn only once it has moved enough
    /// to see (moving map spec §10): every minute live, about ten times a second in replay.
    static func nightDate(for date: Date, step: TimeInterval) -> Date {
        guard step > 0 else { return date }
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded(.down) * step)
    }
}
```

with:

```swift
        self.pin = tripMap.pilotLocation(at: date)
    }
}
```

In `CrewluvTests/TripMapDrawingTests.swift`, replace:

```swift
        XCTAssertEqual(car.coordinate.longitude, middle.longitude, accuracy: 1e-9, "parked halfway when not driving")
    }

    func test_nightDate_holdsBackToTheStep() {
        let date = Date(timeIntervalSince1970: 1_000_059)
        XCTAssertEqual(TripMapDrawing.nightDate(for: date, step: 60), Date(timeIntervalSince1970: 1_000_020))
        XCTAssertEqual(TripMapDrawing.nightDate(for: date, step: 0), date)
    }

    func test_nightBands_haveUniqueIDs_andEveryShape() {
        let date = Date(timeIntervalSince1970: 1_794_571_200)
        let bands = NightBand.bands(at: date)
        XCTAssertEqual(bands.count, NightShade.layers(at: date).map(\.count).reduce(0, +))
        XCTAssertEqual(Set(bands.map(\.id)).count, bands.count)
    }
}
```

with:

```swift
        XCTAssertEqual(car.coordinate.longitude, middle.longitude, accuracy: 1e-9, "parked halfway when not driving")
    }
}
```

Delete `NightBand.swift`:

```bash
rm /Users/toddanderson/Dev/Crewluv/Crewluv/Services/TripMap/NightBand.swift
```

- [ ] **Step 8: Check nothing still names what went.**

```bash
cd /Users/toddanderson/Dev/Crewluv && grep -rn -E "MapCameraPosition|positionedByUser|nightStep|NightBand|nightDate|\.mapStyle|safeAreaPadding|isInteractive|camera\(focusingOn" Crewluv/Views/TripMap Crewluv/Services/TripMap CrewluvTests
```

Expected: no lines. `isPositionedByUser` has a capital P and doesn't match. Any line is a leftover: fix it.

- [ ] **Step 9: Todd builds and runs the drawing tests.** Todd presses ⌘B, then runs `TripMapDrawingTests`. Expected: the build succeeds, and `TripMapDrawingTests` passes 5 tests, 0 failures (it had 7; the two removed tests were the night's).

- [ ] **Step 10: Todd opens the previews.** In Xcode, open `TripMapPreviews.swift` and look at the canvas: "In flight", "Layover", "Next trip", "Recap", "Across the date line", "Full screen, in flight" and "Full screen, recap". Expected:
  - every preview shows the map with its night, lines, airport codes and markers;
  - the plane on its line in flight;
  - the heart on Cologne on the layover;
  - Anchorage to Tokyo in one piece across the Pacific.
  - A blank map, or night over the markers: STOP and look at the console for "Trip map: no view to put the night under".

- [ ] **Step 11: Ask to commit.** Suggested message: `fix(crewluv): the trip map draws its own night and route lines on MKMapView, so nothing flashes during a replay`.

---

### Task 12: The docs

**Files:**
- Modify: `docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`
- Modify: `docs/superpowers/specs/2026-11-13-crewluve-moving-map-stage2-facts-design.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Amend the moving map spec.** Apply each amendment in the Design section's "Spec amendments" as an exact replacement or insertion: the header, §6, §7.1, §10, §12, §14 and §15.2. Each "Replace" block's text is in the file as quoted. If one isn't found exactly, STOP: the spec has moved on since this plan.

- [ ] **Step 2: Amend the Stage 2 spec.** Apply the §6.1 and §6.2 replacements the same way.

- [ ] **Step 3: Update `CLAUDE.md`'s Trip Map section.** Replace:

```markdown
- Built on SwiftUI's `Map` (`MapPolyline`, `MapPolygon`, `Annotation`); north stays up, so `PlaneHeading` aims the plane from coordinates alone
```

with:

```markdown
- Built on `MKMapView` (`TripMapView`, a `UIViewRepresentable` run by `TripMapCoordinator`), drawn the way CrewLu's moving map is. The markers are MapKit annotations whose views host the SwiftUI markers (`TripMapAnnotationView`). The night and the route lines are `CAShapeLayer`s in `TripMapShapesView`, kept just under MapKit's annotation container by `TripMapShapesController` and given new outlines on every update. MapKit overlays can't move, only be replaced, and each replacement flashes: don't put anything that changes over time back in an overlay
- North stays up and the map never tilts, so `PlaneHeading` aims the plane from coordinates alone and `MapProjection` (CrewLu's `FlatMapFit`) places everything from three points the map is asked about. The camera is `TripMapCamera`: a pan, pinch or double tap makes it the family's until they recenter. `TripMapClearance` keeps the map's framing and Apple's logo clear of the facts sheet or panel
```

Then replace:

```markdown
- The logic is `nonisolated` and tested: `TripMap` (which legs, the mode, where the pilot is), `TripMapDrawing` (what to draw at an instant), `FlightProgress` (the schedule's plane, with taxi allowances), `TripReplayClock`, `TripMapWording`. The maths in `Utils/` (`NightShade`, `PlaneHeading`, `MapFit`, `GreatCircle`) came from CrewLu's moving map with its tests
```

with:

```markdown
- The logic is `nonisolated` and tested: `TripMap` (which legs, the mode, where the pilot is), `TripMapDrawing` (what to draw at an instant), `TripMapLine` (a route as flat-map points), `TripMapCamera`, `TripMapClearance`, `TripMapMarker`'s placements, `FlightProgress` (the schedule's plane, with taxi allowances), `TripReplayClock`, `TripMapWording`. The maths in `Utils/` (`NightShade`, `PlaneHeading`, `MapFit`, `MapProjection`, `GreatCircle`) came from CrewLu's moving map with its tests
```

Change only these two bullets.

- [ ] **Step 4: Ask to commit.** Suggested message: `docs(crewluv): the moving map spec, Stage 2 spec and CLAUDE.md for the map's own night drawing`. Stage only this task's three files. If `git diff` shows edits in any of them that aren't this task's, ask Todd how he wants them committed first.

---

### Task 13: Code review

**Files:** none change, unless a finding is real.

- [ ] **Step 1: Ask for a review.** Dispatch `superpowers:code-reviewer` with `model: "sonnet"`.
- Give it:
  - this plan's Design section;
  - CrewLu's one-sun spec §4.7 (read only, in `/Users/toddanderson/Dev/Duty`);
  - every file Tasks 8–11 created or changed.
- Ask it to check:
  - **Draws:** every path that changes the time, the camera, the clearance, the style, the look or the size ends in `draw()`, and none can leave the night drawn for an old time. The paths: a replay, a scrub, Live, a leg change with its camera move, the sheet dragged, a rotation, a style change.
  - **`placeShapesView`:** it can't put our view outside the map view, can't loop (a draw that moves the view causes a layout, which causes a draw), and leaves the view in place when no marker is on screen.
  - **Layers:** no layer property is set outside `withoutAnimation`.
  - **The camera:**
    - the first framing is never animated;
    - a camera the family moved is never refit, except by recenter or a new request;
    - a sheet drag reframes only a camera the family hasn't moved;
    - the card ignores the safe area.
  - **Gestures:** the observers never block MapKit's gestures or touches, the Legal link included.
  - **Markers:**
    - names stay stable;
    - a plane angle change refreshes the hosted view without making a new one;
    - every closure that captures `self` does it weakly;
    - `tearDown` leaves nothing that can call back into the coordinator.
  - **Isolation:** pure types and their nested types are `nonisolated`; `TripMapAnnotation` is `nonisolated` for `MKAnnotation`; nothing main-actor is called from a `nonisolated` context.
  - **Imports:** each file imports the modules its members come from (member import visibility).

- [ ] **Step 2: Handle what it finds.** Check each finding against the code before acting on it. Keep a list for Todd of what was fixed and what was left, and why. A fix to a pure type means Todd runs its tests again.

---

### Task 14: Todd runs the tests

- [ ] **Step 1: The steps for Todd.**
  1. In Xcode, choose an iPhone simulator next to **Crewluv** at the top of the window.
  2. Press **⌘U** and wait for the run to finish.
  3. Paste me the end of the test output.

Expected: no failures.
- The new classes: `MapProjectionTests` (19), `MapProjectionClippingTests` (24), `TripMapLineTests` (5), `TripMapCameraTests` (5), `TripMapClearanceTests` (5) and `TripMapMarkerTests` (4). That's 62 new tests.
- `TripMapDrawingTests` has 2 fewer.
- An open Xcode window can miss new test files. If a class is missing, close the project, open it again, and press ⌘U once more.
- For any failure, read it and STOP. Never change a test's expected value to make it pass.

---

### Task 15: Todd's device check, then close out

The simulator can't tell whether motion is smooth, and Todd saw the flash on his real iPad. So the iPad comes first, then an iPhone. Run from Xcode, then press **⌘.** and open Crewluve from its icon: Xcode's debugger makes motion look worse than it is. Open the trip map from the status screen's card, during a trip or a recap.

- [ ] **Step 1: On the iPad.**
  1. **The flash.** Open the full-screen map and press play at 1x. The night's edge glides across the map, and nothing flashes: not the night, not the route lines.
  2. **At 10x.** The night sweeps fast. Nothing flashes or stutters.
  3. **At night.** The plane, the heart, the airport dots and codes, and the cars are as bright at night as by day. Apple's own place names dim a little under the night. That's expected (Design, "What people will notice").
  4. **Pan, pinch, double tap.** The night and the lines stay stuck to the map the whole time. The recenter button appears. Tap it: the map frames the leg or the trip again, and the button goes.
  5. **A leg change during the replay.** The map moves to the next leg, and the lines and the night stay on the map all the way. With Reduce Motion on (Settings, Accessibility, Motion), the map jumps instead.
  6. **The styles.** Tap the map button three times. Each style shows the night and the lines, under the markers. On the Map style the airport codes are dark in light mode and light in dark mode.
  7. **The panel.** The trip is framed to the right of the panel. Apple's logo and Legal link sit to its right, at the bottom. Tap Legal: Apple's legal notices open.
  8. **Dashes.** Zoom in until the dashed leg's far end is off the screen, then drag. The dashes ride with the map and don't crawl along the line. During a replay, the dashes ahead of the plane stay still as the plane eats them.
  9. **Turning.** Pause, then turn the iPad. The night fills the screen, the lines sit on their airports, and the trip is framed for the new shape (unless you'd moved the map).
- [ ] **Step 2: On an iPhone.**
  10. **Portrait.** With the sheet small, the trip is framed above it and Apple's logo sits just above the sheet's top. Drag the sheet to the middle: the map moves up with it. Above the middle it stays.
  11. **Landscape.** The panel shows, as on the iPad, with the trip and the logo beside it.
  12. **Replay at 1x and 10x.** No flash.
  13. **The card.** On the status screen, the card's map is framed on the leg or the trip, with its chips over it. Tap it: the full-screen map opens. Scroll the card up under the top of the screen: its map doesn't shift.
  14. **VoiceOver.** On the card, VoiceOver reads the card's sentence and nothing from the map. On the full-screen map, swiping reaches the airport codes, but not the plane or the heart.
- [ ] **Step 3: The log.** Run from Xcode once more, open the full-screen map, and search the console for `no view to put the night under`. Expected: not there.

**STOP and come back to Todd if:**
- anything flashes, at 1x or 10x;
- the night or the lines come away from the map during a pan, pinch or camera move;
- a marker is dimmed by the night, or the log line appears (the fallback is in use);
- the map won't pan or zoom, or Legal can't be tapped;
- the logo or the framing ends up under the sheet, the panel, the status bar or the home indicator.

**If 10x is smooth but visibly steppy** (no flash, just jumps), that's the 30-a-second tick (Risks, item 4). Tell Todd and offer the display-rate schedule.

To send a screenshot, press the side or top button and volume up together.

Once every check passes, close out:

- [ ] **Step 4: Tell Todd, and wait for the yes.** Say what's ready, what the review fixed or left, and what the device check showed. Ask whether to commit anything not yet committed. Don't push without his word.

- [ ] **Step 5: Mark the spec.** In the moving map spec's amendment paragraph (Task 12), add one sentence with the device check's result and the day it was done, such as "Todd's iPad and iPhone, 14 Nov 2026: no flash at 1x or 10x". Tick this plan's steps. Both go in the commit, on Todd's yes.

- [ ] **Step 6: The revision note.** Draft the "Crewluve revisions" entry in the "1.0.X Build YY" format, as the release-notes memory describes. Confirm the version and build with Todd. Print it for him to paste rather than writing to the note by script. Suggested text:

```
The trip map's night now glides smoothly when you replay a trip, with no flashing, on iPhone and iPad. Dashed routes stay put as the plane flies along them.
```

- [ ] **Step 7: Memory.** Add a project memory for Crewluv: "MapKit overlays can't animate. Anything on the trip map that changes over time is drawn in `TripMapShapesView`, under MapKit's annotation container; the fallback logs 'no view to put the night under'." Add its line to `MEMORY.md`.

---

## Risks

1. **MapKit's view tree on iOS 26.**
   - CrewLu proved the placement on iOS 27.2. Crewluve's deployment target is iOS 26, so a family on 26.x may have a different tree.
   - If the container isn't found, the fallback still draws the night and the lines, but over the markers, and logs it.
   - We can't see it from here. If Todd has an iOS 26 device or simulator, one look at the previews settles it.
2. **`UIHostingConfiguration` outside a cell.** Apple documents it for cells, but its content view is a plain `UIContentView`. Three things could go wrong:
   - it measures wrongly (`minSize(width: 0, height: 0)` guards against the cell minimum);
   - it pushes content inside the safe area near the screen's edge (`.ignoresSafeArea()` guards against that);
   - it drops the plane's `@State` when the configuration is replaced, so the turn snaps instead of easing.

   The fallback is `UIHostingController` with `sizingOptions = .intrinsicContentSize`, or UIKit markers as CrewLu's `AircraftAnnotationView` draws them. Either stays inside `TripMapAnnotationView`.
3. **The safe area under `.ignoresSafeArea()`.** The plan relies on UIKit giving the full-screen `MKMapView` the device's safe area. If SwiftUI didn't pass it down, the logo would sit on the home indicator and the camera would frame under the status bar. Checks 7, 10 and 11 cover this. The fix is to pass SwiftUI's safe area in with the clearance.
4. **30 updates a second at 10x.** At 10x the night moves about 2.5° a tick, which on an iPad showing the whole trip is several points. That's no flash, but it could look steppy on a 120 Hz screen.
   - The knob: during replay, `TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !clock.isPlaying))`.
   - That costs a full SwiftUI body update per frame.
   - The real cure is CrewLu's display link inside the coordinator, reading the clock directly. That's left out on purpose (below).
5. **The gesture observers.** They can miss a way of moving the map: a keyboard shortcut, or VoiceOver's map gestures. Then the recenter button doesn't show, and an automatic refit takes the camera back. They can't block MapKit's own gestures: they never cancel or delay touches, and always recognize alongside.
6. **Apple's place names dim at night.** This is inherent: they're in MapKit's base map, under anything we draw. CrewLu took the same trade.
7. **Hit testing on the card.** A UIKit view inside a SwiftUI `Button` label with `.allowsHitTesting(false)` should leave the tap to the button. Check 13 confirms it.
8. **Dash spacing during a pinch.** Dashes are measured in screen points from each line's far end. During a pinch they slide along the line as it grows, as any screen-space dash does. They stay put during pans and as the plane moves, which is when the eye is on them.

## Self-critique

**Is this wise?**
- It fixes the one fault Todd named, the flash, with the approach CrewLu measured at zero flashes and verified on Todd's phone three days ago.
- The arithmetic is ported with its 37 tests rather than rewritten. The dash and clearance logic is new and has its own tests.
- What it costs:
  - SwiftUI's `Map` and its camera API, replaced by a `UIViewRepresentable` and our own camera value;
  - Apple's place names dimming at night;
  - one undocumented placement, guarded and with a fallback.
- If the arithmetic is wrong, the cost is lines drawn in the wrong place on one screen. Nothing is stored.

**Will it break anything?**
- **The camera** is the part with most to lose: framing with the sheet and panel, recenter, refit on leg change. It's rewritten, not ported. `TripMapCamera` and `TripMapClearance` are unit-tested. The rest is checked by hand: checks 4, 5, 7, 9, 10 and 11.
- **Airport codes** are now ours, not SwiftUI's titles. They'll look slightly different.
- **The card** keeps its size, chips, tap, VoiceOver sentence and 10-second tick.
- **Previews** need no changes (Task 11, step 10).
- **Stage 3** will need a live trail (solid white), an estimated path (dotted), and the ghost and live planes. Each fits: a `RouteSegment.Style` with a layer in `lineOrder`, and a `TripMapMarker` case. Stage 3's plan should say so.

**Is this what a brilliant Apple engineer would do?**
- For something that changes every frame on a map, yes. MapKit's overlays are for things that stay put, and shape layers are the system's tool for moving outlines.
- Markers stay MapKit annotations, so they get MapKit's own placement, collision and hit testing, and they're the same SwiftUI views as before.
- The coordinator is split into three small types with private state, rather than CrewLu's 900-line coordinator, which this project's ~300-line rule wouldn't allow.
- The one step not by the book, placing our view beside MapKit's annotation container, names no private class and has a fallback.

**Disease or symptom?** The symptom is the flash. The disease is animating by swapping overlays. Slowing the swaps (`nightStep`, the 2-second step Todd turned down) treated the symptom. This removes the swapping.

**Alternatives considered and turned down:**
- **Keep SwiftUI's `Map` and step the night less often.** Todd turned this down.
- **One `MKOverlay` whose renderer redraws itself.** It doesn't flash. But CrewLu measured about 6 times the processor of our own layers, and the route lines would still be swapped.
- **SwiftUI's `Map` with a `Canvas` over it, through `MapReader`.**
  - The canvas would sit over the markers, which are inside the map, so the night would dim the plane.
  - It would lag a frame behind every pan, because SwiftUI hears about camera changes after MapKit has drawn them.
  - Drawing the markers in the canvas too would lose MapKit's handling of them.
- **Our own globe.** A separate project, as on CrewLu.

**Deliberately left out:**
- **CrewLu's display link.** The map draws at the screen's 30-a-second tick (Risks, 4). A display link would mean passing the clock into `TripMapView` and redoing the drawing and markers per frame. It's worth doing only if 10x looks steppy on the iPad.
- **The night's fade around a jump in time.** Crewluve's replay runs through layovers at the same speed and never jumps between legs. A scrub doesn't fade on CrewLu either.
- **The sun button** (`clearNight`, `setNightOpacity`). Crewluve has none.
- **Drawing the markers ourselves.** MapKit keeps them, as on CrewLu.
- **Unit tests for the UIKit glue** (`TripMapCoordinator`, the two controllers, `TripMapShapesView`, `TripMapAnnotationView`). Their logic is in the pure types, which are tested. What's left is MapKit and Core Animation behaviour, which only a device shows. Task 15 covers it.
- **Throttling the live night.** On the full-screen map, live, the night is laid again every second. It moves less than a point, but costs well under a millisecond, and one rule ("the night is drawn for each update's time") is simpler than two.

## Seen, not fixed

- **The card's bottom chip covers Apple's logo.** The chip sits at the bottom leading corner with 10 points of padding, where MapKit puts the logo. It was so with SwiftUI's map too. Apple's MapKit terms want the logo visible. A follow-up could give the card's map a bottom layout margin above the chip, or move the chip.
- **Right-to-left screens.** `TripMapScreen` measures the panel with `.global` frames, which run left to right. The new `TripMapClearance` handles right-to-left correctly, but its input from the screen may not. Crewluve is English-only today.
- **MapKit won't zoom out far enough for a very wide trip.** Measured on Todd's phone (2026-11-14), with a next trip of Louisville, Anchorage, the Philippines and Taiwan that spans about 220°:
  - We asked to fit 0.61 of the world's width. The card (350 × 220) showed 0.34, and the full-screen map (466 × 678) showed 0.30.
  - The preview's full-screen Louisville to Cologne leg was also cut off at both ends.
  - MapKit's `cameraZoomRange` is unset by default (−1). Setting a 50,000 km maximum didn't help: the full-screen map then showed 0.27. So the limit is MapKit's own, for this flat map.
  - SwiftUI's map is the same `MKMapView` underneath, so this is very likely as before.
  - A follow-up could frame what fits, such as the leg in motion or the first leg from home, when the whole trip can't be shown.
- **VoiceOver's map scroll doesn't count as the family moving the map.** The observers see touches and a trackpad. VoiceOver's three-finger scroll moves `MKMapView` directly, so the recenter button doesn't show, and the next sheet drag or rotation refits the camera. A flag around our own framing, read in `mapView(_:regionWillChangeAnimated:)`, could catch it.
- **The panel's clearance doesn't change when the panel folds.** It's measured "open or folded", as Stage 2A chose, so the trip stays framed beside the full-width panel.

---

## Changes made during execution

The code, not the blocks above, is the reference for these.

### Batch A (Tasks 2–7)

The files were copied from the plan's code by script. The review (sonnet) found nothing critical. Changes since:
- **`TripMapLine` keeps a coordinate that isn't a number** as a point, without a great circle, and leaves the projection to drop it. Before, it relied on `GreatCircle` clamping NaN to 180°.
- **`FlatMapPoint`'s `x` and `y` are `let`, not CrewLu's `var`.** Nothing in this plan changes a point after it's made.
- **To confirm in Task 15:**
  - `TripMapClearance` adds only the part of a clearance beyond the safe area, because UIKit adds layout margins on top of the safe area (`insetsLayoutMarginsFromSafeArea`, as CrewLu relies on).
  - Each dashed line ends in a gap at its far end, so a dash or dot doesn't touch the destination. That's a visual choice to check.

### Batch B (Tasks 8–10)

The files were copied from the plan's code by script. The review (sonnet) found nothing critical. Changes since:
- **`TripMapContainerView` reports a safe-area change from its next layout,** like a size change, and `TripMapCameraController` reads the safe area from the container. As the device turned, the map's own copy could lag a layout behind, leaving the logo and the framing a step late.
- **Markers can't be selected** (`isEnabled = false`, and the hosted view takes no touches). A tap on a car would have lifted it above the plane.
- **`TripMapShapesController` looks only at `TripMapAnnotation` views** when it finds MapKit's annotation container.
- **`TripMapShapesView` imports `QuartzCore`** for its layers.
- **Left as they are:**
  - The one-finger double-tap-and-drag zoom is caught only by the pan recognizer. If that pan doesn't begin, the zoom goes unreported and the recenter button doesn't show. Check it in Task 15.
  - The camera controller's gesture recognizers aren't removed on teardown. That's harmless, since they go with the map view and hold the controller only through their targets.

### Batch C (Task 11)

The whole-file blocks were copied from the plan by script. Step 7's two replacements each matched once.
- **Step 8's search still finds `TripMapShapesController`'s own `nightDate`.** That private property is the moment the night was last drawn for, not the removed `TripMapDrawing.nightDate(for:step:)`, so it stays.
- **Each marker is hosted in a `UIHostingController` with `safeAreaRegions = []`, not a `UIHostingConfiguration`.**
  - The full-screen map's preview showed the plane and CGN about a status bar's height (~60 pt) below their places, while the lines sat right on the map.
  - A marker view inherits the map's safe area, and SwiftUI moved the hosted marker down by it. `.ignoresSafeArea()` on `TripMapMarkerView` didn't stop it, so that modifier went.
  - CrewLu's markers are plain UIKit views, so CrewLu never hit this. The cards were unaffected because their map has no safe area.
  - Swapping the root view keeps the SwiftUI state, as the configuration did.
- **Task 13's review (sonnet) found nothing critical.** Every draw path, the camera rules, the gestures, the isolation and the imports checked out.
  - **Fixed:** when the text size changes, the marker's hosted view now takes the new traits (`updateTraitsIfNeeded()`) before it's measured. Before, an airport code could be measured at its old size, which put its dot off the airport.
  - **Left:**
    - The plane's first turn may not ease the short way round if `PlaneMarker`'s `onChange(initial:)` doesn't fire without a parent view controller. The plane still points the right way. Watch for it in Task 15.
    - Every route's `TripMapLine` is rebuilt on each update. That's about 0.2 ms at 30 fps; a cache by segment would remove it.
    - A rotation frames once with the old clearance, then again with the new one. Both are unanimated. Watch for a jump in Task 15.
    - VoiceOver's three-finger scroll isn't seen as the family moving the map (see "Seen, not fixed").
    - The controllers have no unit tests. `frameIfNeeded`'s decision could be pulled out into a pure function and tested.

### Short legs in a replay, from the website (2026-11-13)

Todd asked, through the website's session, for the app's replay to match the website's. While a leg moves, 1x plays at the slower of a day in 48 s and the leg's length over 3 s. Between legs it plays at a day in 48 s. The speed multiplies both, and where legs overlap the slowest wins. Sources: Crewluve Website `docs/superpowers/specs/2026-11-13-replay-short-legs-design.md`, `src/map/replayClock.ts`, and `tests/map/replayClock.test.ts`.
- `TripReplayClock` takes `legs: [Stretch]`. Its pace is cut at every leg's start and end, as the website's `pace()`.
- The app has no `finishesAt`, so the website's rounding trap doesn't apply: `time(at:)` reads the end once the replay time reaches it.
- Eight tests mirror the website's numbers: 3 s, 1 s, 3 s, 2 s and 16 s.
- `TripMapScreen` gives the clock its legs (`replayLegs(of:)`), and makes a new clock when they change. Task 11's full-file `TripMapScreen` above has the same change.
- The moving map spec's §6 says so.

# An Air Return (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A plane that takes off and lands back at its departure airport reads "Returned to Rockford", not "Still on the ground", and a second takeoff starts its path afresh, by a rule in the shared engine that the website then follows.

**Architecture:**
- **The rule** (`Crewluv/Services/TripMap/Live/LiveFlight+Return.swift`, and `scripts/live-cases/live.mjs`): a plane on the ground within 10 nm of its departure airport whose whole trail has climbed 1,000 ft, its highest point over its lowest, is back (`LiveFlight.isBack`). The trail's latest try (`LiveFlight.latestTry`) starts again at a place seen in the air within 30 nm of the airport more than 10 minutes after the point before it, which was within 10 nm, once the try before had climbed; the fix in the air can start one before any new point; while the plane is back, it has no points.
- **The engine:** `FlightPath` is made from the latest try alone, so its record and own speed are too. `LiveProgress` has a new phase, `returned`: the real plane at its fix, no ghost, and the landing estimate as a plane still on the ground has it. `LiveLabel.returned` is "Returned", whatever the gap. `MapFlight.isAtDeparture` counts a returned plane, so the facts treat it as one still at the gate, and `MapFlight.hasReturned` says which words.
- **The words:** "Returned to Rockford" on the card's bar, in the popup, the card's sentence for VoiceOver, the facts' headline and first row, and under the timeline, where one enum, `FlightOnGround`, now carries "On the ground in", "Returned to" and "Landed in" in place of two airports. The status sentence says "has returned to" (`PartnerStatusReceiver.hasReturned`). Two previews show it.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS 26, SwiftUI, XCTest, Node for the shared cases.

**Sources:**
- **The design:** `docs/superpowers/specs/2026-11-17-air-return-design.md` (Todd, 17 Nov 2026, `2973e93`): the rule's climb ("Climbed 1,000 ft"), the words ("Returned to Rockford"), and the path afresh on a second takeoff. Task 5 sets its names to the code's.
- **The request:** the website session, which follows the app's rule and shared cases with a plan of its own.
- **The model:** "still on the ground" (which plane plan, `docs/superpowers/plans/2026-11-16-which-plane-and-the-gate.md`) and "landed before the gate" (`docs/superpowers/plans/2026-11-17-landed-before-gate.md`). This plan's names and tests follow theirs.

**How this plan was checked.**
- **A scratch Swift package** with the app target's settings, made from the repo at `2973e93`: 611 XCTest and 71 Swift Testing tests before, 631 and 71 with this plan, all passing, no warnings.
- **Task by task:** after Task 1 the shared cases fail the Swift as they should (71 of 611 XCTest tests fail, every one on a new case); then 623 XCTest tests after Task 2 and 631 after Task 3 (Task 4 is views alone), all passing.
- **35 deliberate breaks** were made in the new Swift, one at a time, and every one fails at least one test: back without a climb, anywhere, or while in the air; a climb of over 1,000 ft, a height in place of a climb, or no height as sea level; never starting again, the trail kept while back, starting again from further out, only within 10 nm, anywhere, at any gap, before a climb, or never at the fix; the trail unsorted; the path from the whole trail; never returned; no estimate, a ghost or no plane while back; returned only with a gap; back not at departure, or at departure as returned; the bar, the card's sentence and the popup saying only "Returned"; the sentence telling what's below; the timeline saying "On the ground in", still in for a returned plane, or no longer landed first; the facts or the first row saying still on the ground; the timeline's words in a replay; and "Returned at". Two breaks were left out: a ghost's list without `returned` doesn't build, and `MapLeg.hasReturned` after the gate can't be seen, as every caller asks only between the gates.
- **The whole app was type-checked for iOS** with `swiftc` outside Xcode after Tasks 3 and 4, and compiled for the iOS simulator with the whole plan in: no errors and no warnings. The views, the status sentence and the previews are checked that way only.
- **The plan was followed by a script** on the repo at `2973e93`, the shared cases written by its own reference: all 34 files came out the same as the tested ones.
- **The shared cases:** the 30 flights there were, and every plan, gap and window, come out unchanged; four flights and two labels are new.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together: nothing critical, and the Swift and the reference agree on every rule (the sort, the climb with missing heights, the restart, the order of the phase's checks). From its points: a second try's first point may be up to 30 nm out, and the fix in the air can start the try before any new point, so the path is right from the second takeoff (with a shared case, "seen only at its fix"); and tests for an unsorted trail that starts again and a height that's missing. Left, with reasons, under Left for later: the facts' story for a minute after a second takeoff, and the "still on the ground" names.
- **Not checked:** nothing ran on a simulator or a device, and no view was seen.

**Where this plan settles details.**
- **The constants live on `LiveFlight`** (`returnClimbFeet`, `restartGap`), beside the trail they read, not on `LiveProgress` and `FlightPath` as the design first named them. Task 5 sets the design's names.
- **A returned plane is at the start of its path,** as a plane still on the ground is, so its facts are a plane at the gate's: no sky row, nothing below, "1,382 mi to go", and its plane row with no height or speed.
- **While it's back, the path is the great circle** and there's no record: the way out and back isn't drawn, and the list leaves the flight out until it takes off again.
- **"Returned" is the label,** whatever the gap, and the shared cases say just that. The airport is the app's: the bar and the popup say "Returned to Rockford".
- **The card's sentence for VoiceOver** says "UPS2963 to Anchorage, returned to Rockford. Lands about 9:11 AM your time.", with nothing of what's below.
- **`FlightOnGround`** takes "still on the ground"'s and "landed"'s airports with it, which the landed plan left for a later tidy. `TripMap.stillOnGroundAirport` and `landedAirport` stay, and make it; `TripFacts`' two go.
- **A second try's first point may be up to 30 nm out,** as a first point that tells the takeoff may, and the fix in the air can start the try before any new trail point: both from the plan's review, so the path is right from the second takeoff. Task 5 puts both in the design.
- **Two previews,** "Real plane, returned to the gate" on the card and full screen: 40 minutes after the plan's takeoff, back after 30 nm out and back.

---

## Ground rules

1. **Don't run `xcodebuild` build or test loops.** Todd runs the tests (Task 6).
2. **Never commit without Todd's go-ahead,** and then only this plan's files, by path. **Never push** without a fresh yes.
3. **Copy the code as written.** A replacement is exact: if its text isn't in the file once (or twice, where it says "both places"), stop.
4. **Never edit `live-cases.json` by hand.** `node scripts/live-cases/generate.mjs` writes it.
5. **Work on `feature/trip-map-live`.** Never stash, reset or switch branches.

## File map

| File | Task | What changes |
|---|---|---|
| `scripts/live-cases/live.mjs`, `generate.mjs`, `CrewluvTests/Fixtures/TripMap/live-cases.json` (written) | 1 | the rule and its shared cases |
| `Crewluv/Services/TripMap/Live/LiveFlight+Return.swift` (new), `FlightPath.swift`, `LiveProgress.swift`, `LiveLabel.swift`, `MapFlight.swift`, `Crewluv/Services/TripMap/TripMapWording.swift`, `PlanePopupWords.swift` | 2 | the engine |
| `Crewluv/Services/TripMap/FlightOnGround.swift` (new), `MapLeg.swift`, `TripMap+Activity.swift`, `TripMapWording.swift`, `PlanePopupWords.swift`, `Crewluv/Services/TripMap/Facts/FactsWording.swift`, `TripFacts.swift`, `TripFacts+Rows.swift`, `Crewluv/Views/TripMap/TripTimelineControl.swift`, `FactsHeader.swift`, `FactsPanel.swift`, `FactsSheet.swift` | 3 | "Returned to Rockford" |
| `Crewluv/Services/PartnerStatusReceiver.swift`, `Crewluv/Views/Welcome/ContentView.swift`, `Crewluv/Views/Status/PilotStatusView.swift`, `NarrativeCardView.swift`, `Crewluv/Views/TripMap/TripMapPreviews.swift` | 4 | the status sentence and the previews |
| `CrewluvTests/AirReturnTests.swift`, `AirReturnWordsTests.swift` (new), `Helpers/LiveCases.swift`, `StillOnGroundTests.swift`, `StillOnGroundFactsTests.swift`, `LandedBeforeGateFactsTests.swift`, `LandedBeforeGateWordsTests.swift` | 2, 3 | the tests |
| `CLAUDE.md`, `docs/superpowers/specs/2026-11-17-air-return-design.md` | 5 | the docs |

---

### Task 1: Before starting, and the shared cases (design §2 to §5)

- [ ] **Step 1:** The branch is `feature/trip-map-live`, at `2973e93` or later, and none of this plan's files has changed since.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

- [ ] **Step 2: The rule in the reference.** It reads each trail point's height now, which it never needed before.

In `scripts/live-cases/live.mjs`:

Replace:

```swift
export const OWN_SPEED_AHEAD = 2 * 3600
```

with:

```swift
export const OWN_SPEED_AHEAD = 2 * 3600
export const RETURN_CLIMB_FEET = 1000
export const RESTART_GAP = 10 * 60
```

Replace:

```swift
  const trail = wire.trail.map((p) => ({ time: p[0] / 1000, at: [p[1], p[2]] }))
```

with:

```swift
  const trail = wire.trail.map((p) => ({ time: p[0] / 1000, at: [p[1], p[2]], feet: p[3] }))
```

Replace:

```swift
// MARK: The path (spec §6.1)

export function makePath(origin, destination, flight) {
  const seen = flight ? flight.trail.map((p) => ({ at: p.at, time: p.time })) : []
```

with:

```swift
// MARK: An air return (air return design §2, §4)

/// Whether the highest of `points` is RETURN_CLIMB_FEET or more above the lowest. Points with no height don't count.
export function hasClimbed(points) {
  const feet = points.map((p) => p.feet).filter((f) => f !== null && f !== undefined)
  return feet.length > 0 && Math.max(...feet) - Math.min(...feet) >= RETURN_CLIMB_FEET
}

/// Whether the plane is back on the ground at its departure airport after flying: on the ground by Crewlu Cloud's
/// state, its last fix within 10 nm of the airport, and its whole trail climbed RETURN_CLIMB_FEET. How old the fix is
/// isn't asked: `progress` asks that.
export function isBack(flight, origin) {
  return flight?.state === 'ground' && !!flight.fix && distance(flight.fix.at, origin) <= AIRPORT_RADIUS
    && hasClimbed(flight.trail)
}

/// The trail points of the flight's latest try. A try starts again at a place seen in the air within FIRST_POINT_RADIUS
/// of the departure airport more than RESTART_GAP after the point before it, which was within 10 nm of it, once the try
/// before had climbed. The fix in the air, when it's newer than the trail, can start one too, with no points yet. While
/// the plane is back on the ground there, none.
export function latestTry(flight, origin) {
  if (!flight || isBack(flight, origin)) return []
  const trail = flight.trail
  const last = trail[trail.length - 1]
  const fix = flight.fix
  const places = fix && !fix.onGround && (!last || fix.seenAt > last.time) ? [...trail, { time: fix.seenAt, at: fix.at }] : trail
  let start = 0
  for (let i = 1; i < places.length; i++) {
    const earlier = places[i - 1], later = places[i]
    if (later.time - earlier.time > RESTART_GAP && distance(earlier.at, origin) <= AIRPORT_RADIUS
        && distance(later.at, origin) <= FIRST_POINT_RADIUS && hasClimbed(trail.slice(start, i))) start = i
  }
  return trail.slice(start)
}

// MARK: The path (spec §6.1)

export function makePath(origin, destination, flight) {
  // The latest try alone: an air return and the wait after it aren't the flight's path (air return design §4).
  const seen = latestTry(flight, origin).map((p) => ({ at: p.at, time: p.time }))
```

Replace:

```swift
export function labelFor(phase, gap) {
  if (gap === null) return null
```

with:

```swift
export function labelFor(phase, gap) {
  // Back at the departure airport, whatever the gap: the words name the airport (air return design §3).
  if (phase === 'returned') return 'Returned'
  if (gap === null) return null
```

Replace:

```swift
    else if (flight.state === 'ground' && isFresh) {
      phase = distance(fix.at, path.origin) <= AIRPORT_RADIUS ? 'onGround' : 'elsewhere'
    }
```

with:

```swift
    else if (flight.state === 'ground' && isFresh) {
      if (distance(fix.at, path.origin) > AIRPORT_RADIUS) phase = 'elsewhere'
      else phase = isBack(flight, path.origin) ? 'returned' : 'onGround'
    }
```

Replace:

```swift
  if (phase === 'onGround' && now >= plan.takeoff) touchdown = now + (plan.touchdown - plan.takeoff)
```

with:

```swift
  // Past the plan's takeoff, a plane at the departure airport, still or again, takes off this moment.
  if ((phase === 'onGround' || phase === 'returned') && now >= plan.takeoff) touchdown = now + (plan.touchdown - plan.takeoff)
```

Replace:

```swift
  if (phase === 'onGround') { planeAlong = 0; plane = fix.at }
```

with:

```swift
  if (phase === 'onGround' || phase === 'returned') { planeAlong = 0; plane = fix.at }
```

- [ ] **Step 3: Three flights, two labels, the constants and the cases' about text.**

In `scripts/live-cases/generate.mjs`:

Replace:

```swift
const holdFix = { ...airFix(toPhiladelphia, 240, offAt, t('2026-11-13T13:17:40Z'), 12000),
                  lat: holdPlace(t('2026-11-13T13:17:40Z'))[0], lon: holdPlace(t('2026-11-13T13:17:40Z'))[1] }
```

with:

```swift
const holdFix = { ...airFix(toPhiladelphia, 240, offAt, t('2026-11-13T13:17:40Z'), 12000),
                  lat: holdPlace(t('2026-11-13T13:17:40Z'))[0], lon: holdPlace(t('2026-11-13T13:17:40Z'))[1] }

// An air return (air return design §5): off at 12:04:34, out 40 nm toward Philadelphia at 250 kt and straight back,
// climbing to 8,500 ft halfway and down again, and back on the ground at 12:23:46.
const airReturn = [airports.SDF, alongRoute(toPhiladelphia, 40 * NM), airports.SDF]
const airReturnKnots = 250
const airReturnFor = routeLength(airReturn) / (airReturnKnots * NM / 3600)
const airReturnFeet = (time) => Math.round(500 + 16000 * Math.min(time - offAt, offAt + airReturnFor - time) / airReturnFor)
const airReturnTimes = []
for (let time = t('2026-11-13T12:05:00Z'); time <= t('2026-11-13T12:23:00Z'); time += 120) airReturnTimes.push(time)
const airReturnTrail = airReturnTimes.map((time) => trailPoint(airReturn, airReturnKnots, offAt, time, airReturnFeet(time)))
// Off again at 13:20 toward Philadelphia at 430 kt, climbing, first seen at 13:22:30, 18 nm out, and every 2 minutes on.
const secondOffAt = t('2026-11-13T13:20:00Z')
const secondTimes = []
for (let time = t('2026-11-13T13:22:30Z'); time <= t('2026-11-13T13:40:30Z'); time += 120) secondTimes.push(time)
const secondTrail = secondTimes.map((time, i) => trailPoint(toPhiladelphia, phlKnots, secondOffAt, time, Math.min(35000, 2000 + i * 4000)))
```

Replace:

```swift
  flightCase({
    name: 'landed, seen all the way', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
```

with:

```swift
  flightCase({
    name: 'an air return, back on the ground', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Off at 12:04:34, out 40 nm and straight back, climbing to 8,500 ft and down again, and on the ground at Louisville at 12:40. Its trail climbed 1,000 ft or more, so it has returned: the label is "Returned", the real plane is at its fix with no ghost, and touchdown is now plus the plan\'s 83 minutes in the air, as for a plane still on the ground. The way out and back isn\'t its path: the path is the great circle, and there\'s no record.',
    flight: wire('leg-phl', 'UPS1234', 'ground', groundFix([38.18, -85.73], t('2026-11-13T12:40:00Z')), null, airReturnTrail),
    moments: [
      ['2026-11-13T12:41:00Z', 'Back at the airport, 26 minutes after the plan\'s takeoff.'],
      ['2026-11-13T12:43:01Z', 'The ground fix is just over 3 minutes old: not live.'],
    ],
  }),
  flightCase({
    name: 'an air return, then off again', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'The same air return, then off again at 13:20. Its first point after the wait is 18 nm from Louisville, within 30 nm, an hour after the last point of the return, which was 3 nm out: the trail starts again there. Its path, record, own speed, landing estimate and ghost are made from the second try alone.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, secondOffAt, t('2026-11-13T13:41:30Z'), 35000), null,
                 [...airReturnTrail, ...secondTrail]),
    moments: [['2026-11-13T13:41:40Z', 'In the air again, and very late.']],
    places: ['2026-11-13T13:25:00Z', '2026-11-13T13:41:00Z'],
    distancesNm: [50, 150],
  }),
  flightCase({
    name: 'an air return, then off again and seen only at its fix', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'The same air return, then off again at 13:20 and seen in the air at 13:21:30, 11 nm out, before its first new trail point. The fix starts the trail again by itself: the path is the fix\'s alone, with nothing of the way out and back.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, secondOffAt, t('2026-11-13T13:21:30Z'), 4000), null, airReturnTrail),
    moments: [['2026-11-13T13:21:40Z', 'In the air again, an hour late.']],
  }),
  flightCase({
    name: 'a stray point while taxiing', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'One point in the air at 500 ft while the plane taxied, and on the ground ever since. One point can\'t climb, so it hasn\'t returned: it\'s still on the ground.',
    flight: wire('leg-phl', 'UPS1234', 'ground', groundFix([38.18, -85.73], t('2026-11-13T12:20:00Z')), null,
                 [[Math.round(t('2026-11-13T12:10:00Z') * 1000), 38.176, -85.733, 500]]),
    moments: [['2026-11-13T12:20:30Z', 'Five and a half minutes after the plan\'s takeoff: still on the ground, 6 minutes behind.']],
  }),
  flightCase({
    name: 'landed, seen all the way', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
```

Replace:

```swift
  labelCase('elsewhere', null), labelCase('notLive', null),
```

with:

```swift
  labelCase('returned', null), labelCase('returned', -26),
  labelCase('elsewhere', null), labelCase('notLive', null),
```

Replace:

```swift
  about: 'The real plane (Crewluve moving map Stage 3 spec §4 to §7, §10.2). Made by a reference written apart from the app and the website, and run by both: the app\'s FlightPlanTests, FlightPathTests, FlightRecordTests, LiveProgressTests, LiveLabelTests and LiveWindowTests, and the website\'s tests. Change both copies together. Every `at`, and every time in an answer, is an ISO 8601 time with milliseconds. A `flight` is one entry of partner_live\'s `flights`, exactly as the door answers it, with times in milliseconds since 1970, or null where the door answers none. Distances are nautical miles of 1,852 m along a sphere of radius 6,371,008.8 m, to the nearest thousandth; places are [latitude, longitude]. A gap is the plan\'s touchdown minus the estimated one in minutes, rounded to the nearest with halves away from zero; ahead is positive. A path\'s `ownSpeedKt` is the plane\'s own speed over its cruise so far, or null when too little of it has been seen, and a flight\'s `flownSpeedKt` is the speed its estimate, its estimated plane and its ghost fly the cruise at. When its own speed is from 0.7 of the plan\'s to 1.5 of it, the cruise left from the last place it was seen is flown at its own speed for `ownSpeedAheadMinutes`, or all the way when that\'s further, and at the plan\'s after that, and `flownSpeedKt` is the one speed that flies it all in the same time. Otherwise it\'s the plan\'s. Compare speeds to 0.01 kt. Compare distances to 0.01 nm, times to 0.05 s and places to 0.0001 of a degree.',
```

with:

```swift
  about: 'The real plane (Crewluve moving map Stage 3 spec §4 to §7, §10.2). Made by a reference written apart from the app and the website, and run by both: the app\'s FlightPlanTests, FlightPathTests, FlightRecordTests, LiveProgressTests, LiveLabelTests and LiveWindowTests, and the website\'s tests. Change both copies together. Every `at`, and every time in an answer, is an ISO 8601 time with milliseconds. A `flight` is one entry of partner_live\'s `flights`, exactly as the door answers it, with times in milliseconds since 1970, or null where the door answers none. Distances are nautical miles of 1,852 m along a sphere of radius 6,371,008.8 m, to the nearest thousandth; places are [latitude, longitude]. A gap is the plan\'s touchdown minus the estimated one in minutes, rounded to the nearest with halves away from zero; ahead is positive. A path\'s `ownSpeedKt` is the plane\'s own speed over its cruise so far, or null when too little of it has been seen, and a flight\'s `flownSpeedKt` is the speed its estimate, its estimated plane and its ghost fly the cruise at. When its own speed is from 0.7 of the plan\'s to 1.5 of it, the cruise left from the last place it was seen is flown at its own speed for `ownSpeedAheadMinutes`, or all the way when that\'s further, and at the plan\'s after that, and `flownSpeedKt` is the one speed that flies it all in the same time. Otherwise it\'s the plan\'s. A plane on the ground within 10 nm of its departure airport has returned when its whole trail has climbed `returnClimbFeet` or more, its highest point over its lowest, and its label is "Returned". A path, its record and its own speed are made from the trail\'s latest try, which starts again at a place seen in the air within `firstPointRadiusNm` of the departure airport more than `restartGapMinutes` after the point before it, which was within `airportRadiusNm`, once the try before had climbed `returnClimbFeet`; the fix in the air, when it\'s newer than the trail, can start one with no trail points yet; while the plane is back there, from no points. Compare speeds to 0.01 kt. Compare distances to 0.01 nm, times to 0.05 s and places to 0.0001 of a degree.',
```

Replace:

```swift
    ownSpeedAheadMinutes: live.OWN_SPEED_AHEAD / 60,
```

with:

```swift
    ownSpeedAheadMinutes: live.OWN_SPEED_AHEAD / 60,
    returnClimbFeet: live.RETURN_CLIMB_FEET, restartGapMinutes: live.RESTART_GAP / 60,
```

- [ ] **Step 4: Write the cases.**

```bash
cd /Users/toddanderson/Dev/Crewluv && node scripts/live-cases/generate.mjs && git diff --stat CrewluvTests/Fixtures/TripMap/live-cases.json
```

Expected: `7 plans, 34 flights, 31 labels, 12 gaps, 12 windows`, then a line for each flight, among them:

```
- an air return, back on the ground: path 499.713 nm (1 stretches, unseen 0), own null kt, flown at 397.705 kt, 12:41:00 returned gap -26 "Returned" plane 0 ghost null | 12:43:01 notLive gap null "null" plane null ghost null
- an air return, then off again: path 501.65 nm (12 stretches, unseen 0), own null kt, flown at 397.705 kt, 13:41:40 inAir gap -64 "1 h 4 min behind" plane 154.083 ghost 501.65
- an air return, then off again and seen only at its fix: path 499.809 nm (2 stretches, unseen 0), own null kt, flown at 397.705 kt, 13:21:40 inAir gap -65 "1 h 5 min behind" plane 10.75 ghost 423.587
- a stray point while taxiing: path 499.723 nm (2 stretches, unseen 0), own null kt, flown at 397.705 kt, 12:20:30 onGround gap -6 "Still on the ground · 6 min behind" plane 0 ghost 36.466
```

The app's tests now fail on the new cases until Task 2: that's expected.

---

### Task 2: The engine (design §2 to §4)

- [ ] **Step 1: The tests.**

Create `CrewluvTests/AirReturnTests.swift`:

```swift
//
//  AirReturnTests.swift
//  CrewluvTests
//
//  An air return (air return design §2 to §4): a plane back on the ground at its departure airport after flying, and
//  the trail of its latest try. The shared cases hold the phase, the label, the path and the record; these hold the
//  rest.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class AirReturnTests: XCTestCase {

    private let louisville = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.736)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func point(_ minutes: Double, milesOut: Double, feet: Double?) -> LiveFlight.TrailPoint {
        // Due east of Louisville: a degree of longitude there is about 47 nautical miles.
        LiveFlight.TrailPoint(time: start.addingTimeInterval(minutes * 60), latitude: louisville.latitude,
                              longitude: louisville.longitude + milesOut / 47, altitudeFeet: feet)
    }

    private func flight(_ state: LiveFlight.State, onGroundAt milesOut: Double? = nil,
                        trail: [LiveFlight.TrailPoint]) -> LiveFlight {
        let fix = milesOut.map {
            LiveFlight.Fix(latitude: louisville.latitude, longitude: louisville.longitude + $0 / 47, altitudeFeet: nil,
                           groundSpeedKnots: 0, trackDegrees: nil, isOnGround: true, registration: "N370UP",
                           typeCode: "B763", seenAt: start.addingTimeInterval(60 * 60))
        }
        return LiveFlight(legID: "f1", callsign: "UPS1234", state: state, fix: fix, landedAt: nil, trail: trail)
    }

    /// Out 40 nm and back, from 500 ft up to 8,500 and down again.
    private var outAndBack: [LiveFlight.TrailPoint] {
        [point(1, milesOut: 2, feet: 900), point(5, milesOut: 20, feet: 6_000), point(9, milesOut: 38, feet: 8_500),
         point(13, milesOut: 20, feet: 6_000), point(18, milesOut: 3, feet: 1_000)]
    }

    // MARK: - The constants

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(LiveFlight.returnClimbFeet, constants.returnClimbFeet)
        XCTAssertEqual(LiveFlight.restartGap, constants.restartGapMinutes * 60)
    }

    // MARK: - Back at the airport

    func test_isBack_onTheGroundNearTheAirport_afterTheTrailClimbed() {
        XCTAssertTrue(flight(.ground, onGroundAt: 0.5, trail: outAndBack).isBack(at: louisville))
        XCTAssertFalse(flight(.ground, onGroundAt: 15, trail: outAndBack).isBack(at: louisville), "a diversion")
        XCTAssertFalse(flight(.airborne, trail: outAndBack).isBack(at: louisville))
        XCTAssertFalse(flight(.airborne, onGroundAt: 0.5, trail: outAndBack).isBack(at: louisville), "in the air by its state")
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: []).isBack(at: louisville), "never flew")
    }

    func test_isBack_needsAClimbOfAThousandFeet_notAHeight() {
        // A stray point at Denver's height, 5,400 ft from sea level, climbs nothing.
        let stray = [point(1, milesOut: 0.2, feet: 5_400)]
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: stray).isBack(at: louisville))
        let level = [point(1, milesOut: 2, feet: 5_400), point(5, milesOut: 20, feet: 6_399)]
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: level).isBack(at: louisville), "999 ft")
        let climbed = [point(1, milesOut: 2, feet: 5_400), point(5, milesOut: 20, feet: 6_400)]
        XCTAssertTrue(flight(.ground, onGroundAt: 0.5, trail: climbed).isBack(at: louisville))
        let noHeights = [point(1, milesOut: 2, feet: nil), point(5, milesOut: 20, feet: nil)]
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: noHeights).isBack(at: louisville))
        // A point with no height isn't at sea level: one height left climbs nothing.
        let oneHeight = [point(1, milesOut: 2, feet: nil), point(5, milesOut: 20, feet: 1_200)]
        XCTAssertFalse(flight(.ground, onGroundAt: 0.5, trail: oneHeight).isBack(at: louisville))
    }

    // MARK: - The latest try

    func test_latestTry_isNone_whileThePlaneIsBack() {
        XCTAssertEqual(flight(.ground, onGroundAt: 0.5, trail: outAndBack).latestTry(from: louisville), [])
    }

    func test_latestTry_startsAgain_nearTheAirport_afterTenMinutes() {
        let again = [point(40, milesOut: 6, feet: 3_000), point(42, milesOut: 20, feet: 9_000)]
        let tries = flight(.airborne, trail: outAndBack + again).latestTry(from: louisville)
        XCTAssertEqual(tries, again)
    }

    func test_latestTry_startsAgain_atAFirstPointUpTo30NauticalMilesOut() {
        // Coverage low down can miss the first minutes of the climb.
        let again = [point(42, milesOut: 28, feet: 9_000), point(44, milesOut: 40, feet: 14_000)]
        XCTAssertEqual(flight(.airborne, trail: outAndBack + again).latestTry(from: louisville), again)
        let unsorted = (outAndBack + again).reversed()
        XCTAssertEqual(flight(.airborne, trail: Array(unsorted)).latestTry(from: louisville), again, "sorted first")
    }

    func test_latestTry_startsAgain_atTheFixInTheAir_beforeAnyNewPoint() {
        let fix = LiveFlight.Fix(latitude: louisville.latitude, longitude: louisville.longitude + 8.0 / 47, altitudeFeet: 3_000,
                                 groundSpeedKnots: 250, trackDegrees: 90, isOnGround: false, registration: "N370UP",
                                 typeCode: "B763", seenAt: start.addingTimeInterval(40 * 60))
        let flying = LiveFlight(legID: "f1", callsign: "UPS1234", state: .airborne, fix: fix, landedAt: nil, trail: outAndBack)
        XCTAssertEqual(flying.latestTry(from: louisville), [])
        let soon = LiveFlight(legID: "f1", callsign: "UPS1234", state: .airborne,
                              fix: LiveFlight.Fix(latitude: fix.latitude, longitude: fix.longitude, altitudeFeet: 3_000,
                                                  groundSpeedKnots: 250, trackDegrees: 90, isOnGround: false,
                                                  registration: "N370UP", typeCode: "B763",
                                                  seenAt: start.addingTimeInterval(25 * 60)),
                              landedAt: nil, trail: outAndBack)
        XCTAssertEqual(soon.latestTry(from: louisville), outAndBack, "seven minutes on: the same try")
    }

    func test_latestTry_isTheWholeTrail_withoutAGapNearTheAirport() {
        // Ten minutes or less, or a gap that ends further out, is the same try.
        let soon = [point(28, milesOut: 6, feet: 3_000)]
        XCTAssertEqual(flight(.airborne, trail: outAndBack + soon).latestTry(from: louisville), outAndBack + soon)
        let further = [point(40, milesOut: 32, feet: 9_000)]
        XCTAssertEqual(flight(.airborne, trail: outAndBack + further).latestTry(from: louisville), outAndBack + further)
        // Nor does one that comes back near the airport from further out, as a plane unseen on its way back would.
        let fromFurther = [point(1, milesOut: 2, feet: 900), point(5, milesOut: 20, feet: 8_000), point(20, milesOut: 5, feet: 3_000)]
        XCTAssertEqual(flight(.airborne, trail: fromFurther).latestTry(from: louisville), fromFurther)
    }

    func test_latestTry_doesntStartAgain_beforeTheFirstTryClimbed() {
        // A stray point while taxiing, then the real takeoff half an hour later.
        let trail = [point(1, milesOut: 0.2, feet: 500), point(31, milesOut: 2, feet: 1_200), point(33, milesOut: 15, feet: 7_000)]
        XCTAssertEqual(flight(.airborne, trail: trail).latestTry(from: louisville), trail)
    }

    func test_latestTry_sortsTheTrail_byTime() {
        let trail = outAndBack
        XCTAssertEqual(flight(.airborne, trail: trail.reversed()).latestTry(from: louisville), trail)
    }

    // MARK: - The label and the flight

    func test_label_isReturned_whateverTheGap() {
        XCTAssertEqual(LiveLabel(phase: .returned, gapMinutes: nil), .returned)
        XCTAssertEqual(LiveLabel(phase: .returned, gapMinutes: -26), .returned)
    }

    func test_mapFlight_hasReturned_andIsAtDeparture_onlyWhileBack() throws {
        let cases = try TripMapFixtures.liveCases()
        let back = try cases.flight(named: "an air return, back on the ground")
        let backFlight = try cases.mapFlight(back)
        let now = try cases.moment("13T12:41:00", of: back).at
        XCTAssertTrue(backFlight.hasReturned(at: now))
        XCTAssertTrue(backFlight.isAtDeparture(at: now))

        let again = try cases.flight(named: "an air return, then off again")
        let againAt = try cases.moment("13T13:41:40", of: again).at
        XCTAssertFalse(try cases.mapFlight(again).hasReturned(at: againAt))

        let stray = try cases.flight(named: "a stray point while taxiing")
        let strayAt = try cases.moment("13T12:20:30", of: stray).at
        XCTAssertFalse(try cases.mapFlight(stray).hasReturned(at: strayAt))
        XCTAssertTrue(try cases.mapFlight(stray).isAtDeparture(at: strayAt), "still on the ground")
    }
}
```

In `CrewluvTests/Helpers/LiveCases.swift`:

Replace:

```swift
            let ownSpeedAheadMinutes: Double
```

with:

```swift
            let ownSpeedAheadMinutes: Double
            let returnClimbFeet: Double
            let restartGapMinutes: Double
```

A plane back at the gate after an air return is at its departure airport too:

In `CrewluvTests/StillOnGroundTests.swift`:

Replace:

```swift
                let expected = moment.phase == "onGround" && (moment.label?.hasPrefix("Still on the ground") ?? false)
```

with:

```swift
                // A plane back at the gate after an air return is at its departure airport too (air return design §3).
                let expected = moment.phase == "onGround" && (moment.label?.hasPrefix("Still on the ground") ?? false)
                    || moment.phase == "returned"
```

- [ ] **Step 2: Back at the airport, and the latest try.**

Create `Crewluv/Services/TripMap/Live/LiveFlight+Return.swift`:

```swift
//
//  LiveFlight+Return.swift
//  CrewLuve
//
//  An air return (air return design §2, §4): a plane back on the ground at its departure airport after flying, and
//  the trail of its latest try, which its path is made from.
//

import CoreLocation

nonisolated extension LiveFlight {

    /// A trail whose highest point is this much above its lowest has flown: 1,000 ft. Heights are from sea level, and
    /// a plane taxiing at Denver reads 5,400 ft, so it's a climb, not a height.
    static let returnClimbFeet: Double = 1000

    /// A point near the departure airport this long after the one before it, which was near it too, starts the trail
    /// again: 10 minutes. Points come every 2 minutes in the air, so a hold near the airport never leaves this gap.
    static let restartGap: TimeInterval = 10 * 60

    /// The trail oldest first, with two points of one time in the order they came.
    var sortedTrail: [TrailPoint] {
        trail.enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map(\.element)
    }

    /// Whether the plane is back on the ground at its departure airport, at `origin`, after flying: on the ground by
    /// Crewlu Cloud's state, its fix within `LiveProgress.airportRadius` of the airport, and its whole trail climbed
    /// `returnClimbFeet`. How old the fix is isn't asked: `LiveProgress` asks that.
    func isBack(at origin: CLLocationCoordinate2D) -> Bool {
        guard state == .ground, let fix else { return false }
        return GreatCircle.distance(from: fix.coordinate, to: origin) <= LiveProgress.airportRadius && Self.hasClimbed(trail)
    }

    /// The trail of the flight's latest try, oldest first. A try starts again at a place seen in the air within
    /// `FlightPath.firstPointRadius` of `origin` more than `restartGap` after the point before it, which was within
    /// `LiveProgress.airportRadius`, once the try before had climbed `returnClimbFeet`. The fix in the air, when it's
    /// newer than the trail, can start one too, with no trail points yet. None while the plane is back on the ground
    /// there.
    func latestTry(from origin: CLLocationCoordinate2D) -> [TrailPoint] {
        guard !isBack(at: origin) else { return [] }
        let points = sortedTrail
        var places = points.map { (time: $0.time, coordinate: $0.coordinate) }
        if let fix, !fix.isOnGround, fix.seenAt > points.last?.time ?? .distantPast {
            places.append((fix.seenAt, fix.coordinate))
        }
        func distance(_ coordinate: CLLocationCoordinate2D) -> Double { GreatCircle.distance(from: coordinate, to: origin) }
        var start = 0
        for index in places.indices.dropFirst() {
            let earlier = places[index - 1], later = places[index]
            if later.time.timeIntervalSince(earlier.time) > Self.restartGap,
               distance(earlier.coordinate) <= LiveProgress.airportRadius,
               distance(later.coordinate) <= FlightPath.firstPointRadius,
               Self.hasClimbed(points[start..<index]) {
                start = index
            }
        }
        return Array(points[start...])
    }

    /// Whether the highest of `points` is `returnClimbFeet` or more above the lowest. Points with no height don't
    /// count.
    private static func hasClimbed(_ points: some Collection<TrailPoint>) -> Bool {
        let feet = points.compactMap(\.altitudeFeet)
        guard let highest = feet.max(), let lowest = feet.min() else { return false }
        return highest - lowest >= returnClimbFeet
    }
}
```

- [ ] **Step 3: The path from the latest try.**

In `Crewluv/Services/TripMap/Live/FlightPath.swift`:

Replace:

```swift
    /// The path of a flight from `origin` to `destination`: the real one when `flight` has been seen in the air.
    init(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, flight: LiveFlight? = nil) {
        self.origin = origin
        self.destination = destination
        let seen = Self.sightings(of: flight)
```

with:

```swift
    /// The path of a flight from `origin` to `destination`: the real one when `flight` has been seen in the air on
    /// its latest try (air return design §4).
    init(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, flight: LiveFlight? = nil) {
        self.origin = origin
        self.destination = destination
        let seen = Self.sightings(of: flight, from: origin)
```

Replace:

```swift
    /// Each place `flight` was seen in the air, oldest first: its trail's points, with two of one time in the order
    /// they came, and then its fix, when that's in the air and newer than the last of them.
    private static func sightings(of flight: LiveFlight?) -> [Sighting] {
        var seen: [Sighting] = (flight?.trail ?? []).enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }
            .map { ($0.element.coordinate, $0.element.time) }
```

with:

```swift
    /// Each place `flight` from `origin` was seen in the air on its latest try, oldest first: that try's trail points
    /// (`LiveFlight.latestTry`), and then its fix, when that's in the air and newer than the last of them. An air
    /// return and the wait after it aren't the flight's path (air return design §4).
    private static func sightings(of flight: LiveFlight?, from origin: CLLocationCoordinate2D) -> [Sighting] {
        var seen: [Sighting] = (flight?.latestTry(from: origin) ?? []).map { ($0.coordinate, $0.time) }
```

- [ ] **Step 4: The phase, its estimate, its plane and no ghost.**

In `Crewluv/Services/TripMap/Live/LiveProgress.swift`:

Replace:

```swift
        /// Seen on the ground at the departure airport.
        case onGround
```

with:

```swift
        /// Seen on the ground at the departure airport.
        case onGround
        /// Seen on the ground at the departure airport again, after flying: an air return (air return design §2).
        case returned
```

Replace:

```swift
        case .onGround:
            // Past the plan's takeoff, it's as if the plane took off this moment.
            return now >= plan.takeoff ? now.addingTimeInterval(plan.timeInAir) : nil
```

with:

```swift
        case .onGround, .returned:
            // Past the plan's takeoff, it's as if the plane, still or again at the departure airport, took off this
            // moment (air return design §3).
            return now >= plan.takeoff ? now.addingTimeInterval(plan.timeInAir) : nil
```

Replace:

```swift
        case .onGround:
            return (0, fix?.coordinate)
```

with:

```swift
        case .onGround, .returned:
            return (0, fix?.coordinate)
```

Replace:

```swift
        case .landed, .elsewhere, .notLive:
            return nil
```

with:

```swift
        case .landed, .returned, .elsewhere, .notLive:
            // A plane back at its departure airport after an air return has no schedule left to be measured against
            // (air return design §3).
            return nil
```

Replace:

```swift
            guard isFresh else { return .notLive }
            return GreatCircle.distance(from: fix.coordinate, to: origin) <= airportRadius ? .onGround : .elsewhere
```

with:

```swift
            guard isFresh else { return .notLive }
            guard GreatCircle.distance(from: fix.coordinate, to: origin) <= airportRadius else { return .elsewhere }
            return flight.isBack(at: origin) ? .returned : .onGround
```

- [ ] **Step 5: The label.**

In `Crewluv/Services/TripMap/Live/LiveLabel.swift`:

Replace:

```swift
    case stillOnGround(minutesBehind: Int?)
```

with:

```swift
    case stillOnGround(minutesBehind: Int?)
    /// Back on the ground at the departure airport after an air return, whatever the gap (air return design §3). Its
    /// words name the airport.
    case returned
```

Replace:

```swift
    init?(phase: LiveProgress.Phase, gapMinutes: Int?) {
        guard let gapMinutes else { return nil }
```

with:

```swift
    init?(phase: LiveProgress.Phase, gapMinutes: Int?) {
        if phase == .returned {
            self = .returned
            return
        }
        guard let gapMinutes else { return nil }
```

Replace:

```swift
        case .notLive, .elsewhere:
            return nil
```

with:

```swift
        case .notLive, .elsewhere, .returned:
            // `.returned` is answered above.
            return nil
```

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
        case .stillOnGround(let minutesBehind):
            return minutesBehind.map { "Still on the ground · \(minutesText($0)) behind" } ?? "Still on the ground"
```

with:

```swift
        case .stillOnGround(let minutesBehind):
            return minutesBehind.map { "Still on the ground · \(minutesText($0)) behind" } ?? "Still on the ground"
        case .returned:
            return "Returned"
```

Replace:

```swift
        case .stillOnGround(let minutesBehind):
            return minutesBehind.map { "still on the ground, \(spokenMinutes($0)) behind schedule" } ?? "still on the ground"
```

with:

```swift
        case .stillOnGround(let minutesBehind):
            return minutesBehind.map { "still on the ground, \(spokenMinutes($0)) behind schedule" } ?? "still on the ground"
        case .returned:
            return "returned"
```

Replace:

```swift
        case .stillOnGround, .landedOnTime, .landedEarly, .landedLate: false
```

with:

```swift
        case .stillOnGround, .returned, .landedOnTime, .landedEarly, .landedLate: false
```

Replace:

```swift
        case .onSchedule, .ahead, .behind, .stillOnGround:
            arrival = "Lands \(leg.isArrivalEstimated ? "about" : "at") \(time) your time."
```

with:

```swift
        case .onSchedule, .ahead, .behind, .stillOnGround, .returned:
            arrival = "Lands \(leg.isArrivalEstimated ? "about" : "at") \(time) your time."
```

In `Crewluv/Services/TripMap/PlanePopupWords.swift`:

Replace:

```swift
        case .onGround, .inAir:
```

with:

```swift
        case .onGround, .returned, .inAir:
```

- [ ] **Step 6: The flight at its departure airport, still or again.**

In `Crewluv/Services/TripMap/Live/MapFlight.swift`:

Replace:

```swift
    /// Whether the real plane is still on the ground at its departure airport after the plan's takeoff time, when
    /// this device's clock says `now`: seen there lately, not yet in the air (spec §5.1's `onGround`), and late
    /// leaving, as its bar says "Still on the ground". Before the plan's takeoff it's taxiing as the schedule has it,
    /// and nothing says so (which plane design §4).
    func isAtDeparture(at now: Date) -> Bool {
        let progress = self.progress(at: now)
        guard progress.phase == .onGround, case .stillOnGround = progress.label else { return false }
        return true
    }
```

with:

```swift
    /// Whether the real plane is still on the ground at its departure airport after the plan's takeoff time, when
    /// this device's clock says `now`: seen there lately, not yet in the air (spec §5.1's `onGround`), and late
    /// leaving, as its bar says "Still on the ground". Before the plan's takeoff it's taxiing as the schedule has it,
    /// and nothing says so (which plane design §4). A plane back there after an air return is at it too, at any time
    /// (air return design §3).
    func isAtDeparture(at now: Date) -> Bool {
        let progress = self.progress(at: now)
        if progress.phase == .returned { return true }
        guard progress.phase == .onGround, case .stillOnGround = progress.label else { return false }
        return true
    }

    /// Whether the real plane is back on the ground at its departure airport after flying, when this device's clock
    /// says `now` (air return design §2): the words say "Returned to Rockford" in place of "Still on the ground".
    func hasReturned(at now: Date) -> Bool {
        progress(at: now).phase == .returned
    }
```

---

### Task 3: "Returned to Rockford" on the map's card, the facts and the timeline (design §3)

- [ ] **Step 1: The tests.**

Create `CrewluvTests/AirReturnWordsTests.swift`:

```swift
//
//  AirReturnWordsTests.swift
//  CrewluvTests
//
//  "Returned to Rockford" (air return design §3), in US English for a family in Louisville: on the card's bar, in the
//  plane's popup, in the card's sentence for VoiceOver, under the timeline, and in the facts. The shared case "an air
//  return, back on the ground" is from SDF, and the facts' flight is `FactsTestData`'s equator flight from E0.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class AirReturnWordsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// The shared case's plane back at Louisville at 12:41, as a leg of the map.
    private func returned() throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "an air return, back on the ground")
        let moment = try cases.moment("13T12:41:00", of: flightCase)
        return (try cases.mapLeg(flightCase, at: moment), moment.at)
    }

    private func map(of leg: MapLeg) -> TripMap {
        TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    private let rockford = AirportMark(code: "RFD", city: "Rockford", coordinate: CLLocationCoordinate2D(latitude: 42.2, longitude: -89.1),
                                       timeZone: TimeZone(identifier: "America/Chicago"))

    // MARK: - The card and the popup

    func test_bar_saysReturnedToTheDepartureAirport_nowOnly() throws {
        let (leg, at) = try returned()
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "Returned to SDF")
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at, isReplay: true), "In flight")
    }

    func test_cardSummary_saysItReturned_andLandsAbout() throws {
        let (leg, at) = try returned()
        // Touchdown is 12:41 plus the plan's 83 minutes in the air, and the gate 7 minutes on: 14:11 UTC, 9:11 AM.
        XCTAssertEqual(plain(TripMapWording.liveSummary(for: leg, over: "Indiana", lastSeen: "near Louisville", now: at,
                                                        calendar: calendar, locale: locale)),
                       "UPS207 to PHL, returned to SDF. Lands about 9:11 AM your time.")
    }

    func test_popup_saysItReturned_andWhenItLands() throws {
        let (leg, at) = try returned()
        let words = PlanePopupWords(leg: leg, plane: .realPlane, at: at, isReplay: false, calendar: calendar, locale: locale)
        XCTAssertEqual(words.lines.map { plain($0) }, ["Returned to SDF", "Lands about 9:11 AM"])
    }

    // MARK: - The timeline

    func test_flightOnGround_isReturnedToTheDepartureAirport() throws {
        let (leg, at) = try returned()
        let onGround = map(of: leg).flightOnGround(at: at)
        guard case .returnedTo(let airport) = onGround else { return XCTFail("\(String(describing: onGround))") }
        XCTAssertEqual(airport.code, "SDF")
    }

    func test_timeline_saysReturned_inPlaceOfFlying() {
        // 5:21 PM UTC is 12:21 PM in Louisville.
        let date = FactsTestData.date("2026-11-13T17:21:00Z")
        let flying = TripActivity(kind: .flying, place: rockford)
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, onGround: .returnedTo(rockford),
                                                         calendar: calendar, locale: locale)),
                       "Fri 12:21 PM · Returned to Rockford")
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, onGround: .returnedTo(rockford),
                                                                calendar: calendar, locale: locale)),
                       "Friday 12:21 PM, returned to Rockford")
    }

    // MARK: - The facts

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    /// The equator flight's real plane back at E0 half a minute before `now`, after flying out 20 nm and back, from
    /// 1,000 ft up to 8,000 and down to 1,500.
    private func backAtE0(_ now: String) -> LiveFlight {
        let trail = [(10.5, 0.05, 1_000.0), (10.6, 0.33, 8_000.0), (10.7, 0.05, 1_500.0)].map { hours, longitude, feet in
            LiveFlight.TrailPoint(time: at("10:00").addingTimeInterval((hours - 10) * 3600), latitude: 0, longitude: longitude,
                                  altitudeFeet: feet)
        }
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: "N370UP", typeCode: "B763", seenAt: at(now).addingTimeInterval(-30))
        return LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: trail)
    }

    private func facts(backAt now: String, isReplay: Bool = false) throws -> TripFacts {
        let leg = try FactsTestData.equatorLiveLeg(backAtE0(now), at: at(now))
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], dayNumber: 1, totalDays: 1,
                         calendar: calendar, locale: locale, isReplay: isReplay)
    }

    func test_facts_sayReturned_asStillOnTheGroundWould_withNoSky() throws {
        let facts = try facts(backAt: "11:20")
        XCTAssertEqual(facts.headline(at: at("11:20")), "Returned to E0")
        let rows = facts.rows(at: at("11:20"), now: at("11:20"))
        XCTAssertEqual(try XCTUnwrap(rows.first { $0.kind == .below }).title, "Returned to E0")
        XCTAssertNil(rows.first { $0.kind == .sky })
        XCTAssertEqual(try XCTUnwrap(rows.first { $0.kind == .distance }).title, "1,382 mi to go")
        XCTAssertNil(try XCTUnwrap(rows.first { $0.kind == .plane }).detail, "no height or speed on the ground")
        XCTAssertEqual(facts.tripSoFar(at: at("11:20")).flights.count, 0, "the way out and back isn't the flight")
    }

    func test_facts_inAReplay_areAsBefore() throws {
        let replay = try facts(backAt: "11:20", isReplay: true)
        XCTAssertNotEqual(replay.headline(at: at("11:20")), "Returned to E0")
        XCTAssertNil(replay.flightOnGround(at: at("11:20")))
    }

    func test_factsWords_sayReturnedTo() {
        XCTAssertEqual(FactsWording.returned(to: rockford), "Returned to Rockford")
    }
}
```

The older tests that named the two airports apart:

In `CrewluvTests/StillOnGroundTests.swift`:

Replace:

```swift
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, stillOnGroundIn: rockford, calendar: calendar, locale: locale)),
```

with:

```swift
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, onGround: .stillIn(rockford), calendar: calendar, locale: locale)),
```

Replace:

```swift
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, stillOnGroundIn: rockford, calendar: calendar, locale: locale)),
```

with:

```swift
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, onGround: .stillIn(rockford), calendar: calendar, locale: locale)),
```

In `CrewluvTests/LandedBeforeGateWordsTests.swift`:

Replace:

```swift
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, landedIn: anchorage, calendar: calendar, locale: locale)),
```

with:

```swift
        XCTAssertEqual(plain(TripMapWording.timelineLine(date, activity: flying, onGround: .landedIn(anchorage), calendar: calendar, locale: locale)),
```

Replace:

```swift
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, landedIn: anchorage, calendar: calendar, locale: locale)),
```

with:

```swift
        XCTAssertEqual(plain(TripMapWording.timelineSpokenValue(date, activity: flying, onGround: .landedIn(anchorage), calendar: calendar, locale: locale)),
```

In `CrewluvTests/StillOnGroundFactsTests.swift`:

Replace:

```swift
    func test_stillOnGroundAirport_isTheDepartureAirport_nowOnly() throws {
        XCTAssertEqual(try facts(atTheGate: "11:20").stillOnGroundAirport(at: at("11:20"))?.code, "E0")
        XCTAssertNil(try facts(atTheGate: "11:20", isReplay: true).stillOnGroundAirport(at: at("11:20")))
        XCTAssertNil(try facts(atTheGate: "10:10").stillOnGroundAirport(at: at("10:10")))
```

with:

```swift
    func test_flightOnGround_isStillInTheDepartureAirport_nowOnly() throws {
        let onGround = try facts(atTheGate: "11:20").flightOnGround(at: at("11:20"))
        guard case .stillIn(let airport) = onGround else { return XCTFail("\(String(describing: onGround))") }
        XCTAssertEqual(airport.code, "E0")
        XCTAssertNil(try facts(atTheGate: "11:20", isReplay: true).flightOnGround(at: at("11:20")))
        XCTAssertNil(try facts(atTheGate: "10:10").flightOnGround(at: at("10:10")))
```

In `CrewluvTests/LandedBeforeGateFactsTests.swift`:

Replace:

```swift
        XCTAssertNil(replay.landedAirport(at: at("12:58")))
```

with:

```swift
        XCTAssertNil(replay.flightOnGround(at: at("12:58")))
```

Replace:

```swift
    func test_landedAirport_isTheArrivalAirport_now() throws {
        XCTAssertEqual(try facts(landedAt: "12:58").landedAirport(at: at("12:58"))?.code, "E20")
```

with:

```swift
    func test_flightOnGround_isLandedInTheArrivalAirport_now() throws {
        let onGround = try facts(landedAt: "12:58").flightOnGround(at: at("12:58"))
        guard case .landedIn(let airport) = onGround else { return XCTFail("\(String(describing: onGround))") }
        XCTAssertEqual(airport.code, "E20")
```

- [ ] **Step 2: The words.**

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    /// "Landed in Anchorage": the real plane is down, and not yet at the gate (landed before the gate design §3).
```

with:

```swift
    /// In place of what's below, a real plane back on the ground at its departure airport after an air return:
    /// "Returned to Rockford" (air return design §3).
    static func returned(to airport: AirportMark) -> String {
        "Returned to \(airport.name)"
    }

    /// "Landed in Anchorage": the real plane is down, and not yet at the gate (landed before the gate design §3).
```

- [ ] **Step 3: Where the plane is on the ground, as one enum.**

Create `Crewluv/Services/TripMap/FlightOnGround.swift`:

```swift
//
//  FlightOnGround.swift
//  CrewLuve
//
//  A flight between its gates whose real plane is on the ground now, as the line under the timeline names it in place
//  of "Flying to" (which plane design §4, landed before the gate design §3, air return design §3).
//

nonisolated enum FlightOnGround {
    /// Still at its departure airport after the plan's takeoff time: "On the ground in Rockford".
    case stillIn(AirportMark)
    /// Back at its departure airport after an air return: "Returned to Rockford".
    case returnedTo(AirportMark)
    /// Down at its arrival airport, before the gate: "Landed in Anchorage".
    case landedIn(AirportMark)

    /// The airport it's on the ground at.
    var airport: AirportMark {
        switch self {
        case .stillIn(let airport), .returnedTo(let airport), .landedIn(let airport): airport
        }
    }
}
```

In `Crewluv/Services/TripMap/MapLeg.swift`:

Replace:

```swift
    /// Whether the flight is between its gates at `date` with its real plane already down (`MapFlight.hasLanded`):
```

with:

```swift
    /// Whether the flight is between its gates at `date` with its real plane back on the ground at its departure
    /// airport after an air return (`MapFlight.hasReturned`, air return design §2).
    func hasReturned(at date: Date) -> Bool {
        isMoving(at: date) && (flight?.hasReturned(at: date) ?? false)
    }

    /// Whether the flight is between its gates at `date` with its real plane already down (`MapFlight.hasLanded`):
```

In `Crewluv/Services/TripMap/TripMap+Activity.swift`:

Replace:

```swift
    func landedAirport(at date: Date) -> AirportMark? {
        guard let flight = flightInMotion(at: date), flight.isLandedBeforeGate(at: date) else { return nil }
        return flight.destination
    }
```

with:

```swift
    func landedAirport(at date: Date) -> AirportMark? {
        guard let flight = flightInMotion(at: date), flight.isLandedBeforeGate(at: date) else { return nil }
        return flight.destination
    }

    /// Where the flight between its gates at `date` has its real plane on the ground, as the line under the timeline
    /// names it in place of "Flying to": still at its departure airport, back there after an air return, or down at
    /// its arrival airport before the gate. Nil otherwise.
    func flightOnGround(at date: Date) -> FlightOnGround? {
        if let arrival = landedAirport(at: date) { return .landedIn(arrival) }
        guard let flight = flightInMotion(at: date), let departure = stillOnGroundAirport(at: date) else { return nil }
        return flight.hasReturned(at: date) ? .returnedTo(departure) : .stillIn(departure)
    }
```

- [ ] **Step 4: The card's bar, its sentence, the popup and the timeline.**

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
    /// plane's label, or "In flight" when it has none. A moment of the replay is always "In flight" (§7.3).
    /// - Parameter now: the moment, by this device's clock.
    static func flightStatus(for leg: MapLeg, at now: Date, isReplay: Bool = false) -> String {
        guard !isReplay, let label = leg.flight?.progress(at: now).label else { return "In flight" }
        return liveLabel(label)
    }
```

with:

```swift
    /// plane's label, or "In flight" when it has none. A moment of the replay is always "In flight" (§7.3). A plane
    /// back at its departure airport after an air return names it: "Returned to Rockford" (air return design §3).
    /// - Parameter now: the moment, by this device's clock.
    static func flightStatus(for leg: MapLeg, at now: Date, isReplay: Bool = false) -> String {
        guard !isReplay, let label = leg.flight?.progress(at: now).label else { return "In flight" }
        return label == .returned ? FactsWording.returned(to: leg.origin) : liveLabel(label)
    }
```

Replace:

```swift
        return "\(lead) \(leg.destination.name), \(spokenLiveLabel(label))\(over). \(arrival)"
```

with:

```swift
        // A plane back at its departure airport after an air return names it (air return design §3).
        let spoken = label == .returned ? "returned to \(leg.origin.name)" : spokenLiveLabel(label)
        return "\(lead) \(leg.destination.name), \(spoken)\(over). \(arrival)"
```

Replace:

```swift
    /// "Sat 1:40 PM · Layover in Denver": the line under the timeline, when and what (activity markers design §4.2).
    /// While the flight's real plane is still on the ground at its departure airport, `stillOnGroundIn`: "Mon 12:21 PM
    /// · On the ground in Rockford". Once it's down at the arrival airport, before the gate, `landedIn`: "Mon 7:45 PM ·
    /// Landed in Anchorage".
    static func timelineLine(_ date: Date, activity: TripActivity?, stillOnGroundIn airport: AirportMark? = nil,
                             landedIn arrival: AirportMark? = nil,
                             calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = timelineTime(date, calendar: calendar, locale: locale)
        guard let words = timelineWords(activity, stillOnGroundIn: airport, landedIn: arrival) else { return time }
        return "\(time) · \(words)"
    }
```

with:

```swift
    /// "Sat 1:40 PM · Layover in Denver": the line under the timeline, when and what (activity markers design §4.2).
    /// While the flight's real plane is on the ground, `onGround`: "Mon 12:21 PM · On the ground in Rockford", "Mon
    /// 12:21 PM · Returned to Rockford" or "Mon 7:45 PM · Landed in Anchorage".
    static func timelineLine(_ date: Date, activity: TripActivity?, onGround: FlightOnGround? = nil,
                             calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = timelineTime(date, calendar: calendar, locale: locale)
        guard let words = timelineWords(activity, onGround: onGround) else { return time }
        return "\(time) · \(words)"
    }
```

Replace:

```swift
    static func timelineSpokenValue(_ date: Date, activity: TripActivity?, stillOnGroundIn airport: AirportMark? = nil,
                                    landedIn arrival: AirportMark? = nil,
                                    calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = date.formatted(style(calendar: calendar, locale: locale).weekday(.wide).hour().minute())
        guard let words = timelineWords(activity, stillOnGroundIn: airport, landedIn: arrival) else { return time }
```

with:

```swift
    static func timelineSpokenValue(_ date: Date, activity: TripActivity?, onGround: FlightOnGround? = nil,
                                    calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = date.formatted(style(calendar: calendar, locale: locale).weekday(.wide).hour().minute())
        guard let words = timelineWords(activity, onGround: onGround) else { return time }
```

Replace:

```swift
    /// What the pilot is doing, or "On the ground in Rockford" where the flight's real plane is still on the ground at
    /// its departure airport (which plane design §4), or "Landed in Anchorage" where it's down at the arrival airport,
    /// before the gate (landed before the gate design §3).
    private static func timelineWords(_ activity: TripActivity?, stillOnGroundIn airport: AirportMark?,
                                      landedIn arrival: AirportMark?) -> String? {
        if let airport { return "On the ground in \(airport.name)" }
        if let arrival { return FactsWording.landed(in: arrival) }
        return activity?.words
    }
```

with:

```swift
    /// What the pilot is doing, or where the flight's real plane is on the ground: "On the ground in Rockford" while
    /// it's still at its departure airport (which plane design §4), "Returned to Rockford" once it's back there after
    /// an air return (air return design §3), or "Landed in Anchorage" where it's down at the arrival airport, before the
    /// gate (landed before the gate design §3).
    private static func timelineWords(_ activity: TripActivity?, onGround: FlightOnGround?) -> String? {
        switch onGround {
        case .stillIn(let airport): "On the ground in \(airport.name)"
        case .returnedTo(let airport): FactsWording.returned(to: airport)
        case .landedIn(let airport): FactsWording.landed(in: airport)
        case nil: activity?.words
        }
    }
```

In `Crewluv/Services/TripMap/PlanePopupWords.swift`:

Replace:

```swift
        case .onGround, .returned, .inAir:
            self.init(title: title, lines: [label, TripMapWording.landsAt(for: leg, calendar: calendar, locale: locale)].compactMap { $0 })
```

with:

```swift
        case .onGround, .inAir:
            self.init(title: title, lines: [label, TripMapWording.landsAt(for: leg, calendar: calendar, locale: locale)].compactMap { $0 })
        case .returned:
            // Back at its departure airport after an air return, which it names (air return design §3).
            self.init(title: title, lines: [FactsWording.returned(to: leg.origin),
                                            TripMapWording.landsAt(for: leg, calendar: calendar, locale: locale)])
```

- [ ] **Step 5: The facts.**

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
        if isStillOnGround(leg, at: date) {
            return FactsWording.stillOnGround(in: leg.origin)
        }
```

with:

```swift
        if isStillOnGround(leg, at: date) {
            return atDepartureWords(on: leg, at: date)
        }
```

Replace:

```swift
    /// The airport where the flight between its gates at `date` waits, while its real plane is still on the ground
    /// there after the plan's takeoff time: the line under the timeline names it (which plane design §4). Nil in a
    /// replay, whose moment is flying, as the map has the plane.
    func stillOnGroundAirport(at date: Date) -> AirportMark? {
        isReplay ? nil : tripMap.stillOnGroundAirport(at: date)
    }
```

with:

```swift
    /// "Still on the ground in Rockford" for the real plane of `leg` at its departure airport at `date` (which plane
    /// design §4), or "Returned to Rockford" once it's back there after an air return (air return design §3).
    func atDepartureWords(on leg: MapLeg, at date: Date) -> String {
        leg.hasReturned(at: date) ? FactsWording.returned(to: leg.origin) : FactsWording.stillOnGround(in: leg.origin)
    }
```

Replace:

```swift
    /// The arrival airport where the flight between its gates at `date` has landed, before the gate: the line under
    /// the timeline names it (landed before the gate design §3). Nil in a replay.
    func landedAirport(at date: Date) -> AirportMark? {
        isReplay ? nil : tripMap.landedAirport(at: date)
    }
```

with:

```swift
    /// Where the flight between its gates at `date` has its real plane on the ground: the line under the timeline names
    /// it (which plane design §4, landed before the gate design §3, air return design §3). Nil in a replay, whose
    /// moment is where the map has the plane.
    func flightOnGround(at date: Date) -> FlightOnGround? {
        isReplay ? nil : tripMap.flightOnGround(at: date)
    }
```

In `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`:

Replace:

```swift
        let place = isStillOnGround(leg, at: date) ? FactsWording.stillOnGround(in: leg.origin) : belowText(on: leg, at: date)
```

with:

```swift
        let place = isStillOnGround(leg, at: date) ? atDepartureWords(on: leg, at: date) : belowText(on: leg, at: date)
```

Replace:

```swift
    /// first of them that there is leads the row. A real plane still at its departure airport says so in place of
    /// what's below (which plane design §4). A real plane down at the arrival airport before the gate says that alone
```

with:

```swift
    /// first of them that there is leads the row. A real plane still at its departure airport, or back there after an
    /// air return, says so in place of what's below (which plane design §4, air return design §3). A real plane down at
    /// the arrival airport before the gate says that alone
```

- [ ] **Step 6: The views that hand the timeline its words.** No tests: SwiftUI.

In `Crewluv/Views/TripMap/TripTimelineControl.swift`:

Replace:

```swift
    /// Where the flight's real plane is still on the ground at its departure airport, now: the line under the bar names
    /// it in place of flying (which plane design §4).
    let stillOnGroundIn: AirportMark?
    /// Where the flight's real plane is down at the arrival airport, before the gate, now: the line under the bar says
    /// "Landed in" it (landed before the gate design §3).
    let landedIn: AirportMark?
```

with:

```swift
    /// Where the flight's real plane is on the ground, now: the line under the bar names it in place of flying.
    let onGround: FlightOnGround?
```

Replace:

```swift
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity, stillOnGroundIn: stillOnGroundIn,
                                                                                landedIn: landedIn),
```

with:

```swift
                                spokenValue: TripMapWording.timelineSpokenValue(time, activity: activity, onGround: onGround),
```

Replace:

```swift
            Text(TripMapWording.timelineLine(time, activity: activity, stillOnGroundIn: stillOnGroundIn, landedIn: landedIn))
```

with:

```swift
            Text(TripMapWording.timelineLine(time, activity: activity, onGround: onGround))
```

In `Crewluv/Views/TripMap/FactsHeader.swift`:

Replace:

```swift
    /// Where the flight's real plane is still on the ground at its departure airport, now.
    let stillOnGroundIn: AirportMark?
    /// Where the flight's real plane is down at the arrival airport, before the gate, now.
    let landedIn: AirportMark?
```

with:

```swift
    /// Where the flight's real plane is on the ground, now.
    let onGround: FlightOnGround?
```

Replace:

```swift
                                activity: activity, stillOnGroundIn: stillOnGroundIn, landedIn: landedIn, time: time, now: now)
```

with:

```swift
                                activity: activity, onGround: onGround, time: time, now: now)
```

In `Crewluv/Views/TripMap/FactsPanel.swift`:

Replace:

```swift
                            activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                            landedIn: facts.landedAirport(at: time), time: time, now: now)
```

with:

```swift
                            activity: facts.tripMap.activity(at: time), onGround: facts.flightOnGround(at: time),
                            time: time, now: now)
```

In `Crewluv/Views/TripMap/FactsSheet.swift`:

Replace:

```swift
                                activity: facts.tripMap.activity(at: time), stillOnGroundIn: facts.stillOnGroundAirport(at: time),
                                landedIn: facts.landedAirport(at: time), clock: $clock,
```

with:

```swift
                                activity: facts.tripMap.activity(at: time), onGround: facts.flightOnGround(at: time),
                                clock: $clock,
```

---

### Task 4: The status sentence and the previews (design §3)

- [ ] **Step 1: The status sentence.** No tests: SwiftUI. It says "Alex has returned to Rockford on UPS flight 2963 to Anchorage — landing in …".

In `Crewluv/Services/PartnerStatusReceiver.swift`:

Replace:

```swift
    private(set) var isStillOnGround = false
```

with:

```swift
    private(set) var isStillOnGround = false
    /// Whether that real plane at its departure airport is back there after an air return: the narrative says
    /// "has returned to" in place of "is still on the ground in" (air return design §3).
    private(set) var hasReturned = false
```

Replace:

```swift
        isStillOnGround = LiveLegs.stillOnGroundFlight(in: legs, flights: flights, at: now) != nil
```

with:

```swift
        let atDeparture = LiveLegs.stillOnGroundFlight(in: legs, flights: flights, at: now)
        isStillOnGround = atDeparture != nil
        hasReturned = atDeparture.flatMap { flights[$0] }?.hasReturned(at: now) ?? false
```

Replace:

```swift
        isStillOnGround = false
        isLandedBeforeGate = false
```

with:

```swift
        isStillOnGround = false
        hasReturned = false
        isLandedBeforeGate = false
```

In `Crewluv/Views/Welcome/ContentView.swift`:

Replace both places:

```swift
isStillOnGround: receiver.isStillOnGround,
```

with:

```swift
isStillOnGround: receiver.isStillOnGround, hasReturned: receiver.hasReturned,
```

In `Crewluv/Views/Status/PilotStatusView.swift`:

Replace:

```swift
    var isStillOnGround = false
```

with:

```swift
    var isStillOnGround = false
    /// Whether that real plane is back at its departure airport after an air return (air return design §3).
    var hasReturned = false
```

Replace:

```swift
                                      isStillOnGround: isStillOnGround, isLandedBeforeGate: isLandedBeforeGate)
```

with:

```swift
                                      isStillOnGround: isStillOnGround, hasReturned: hasReturned,
                                      isLandedBeforeGate: isLandedBeforeGate)
```

In `Crewluv/Views/Status/NarrativeCardView.swift`:

Replace:

```swift
    var isStillOnGround = false
```

with:

```swift
    var isStillOnGround = false
    /// That real plane at its departure airport is back there after an air return: "Alex has returned to Rockford on
    /// UPS flight 2963 to Anchorage" (air return design §3).
    var hasReturned = false
```

Replace:

```swift
                    } else if isStillOnGround, let dep, let dest {
                        Text("\(name) is still on the ground in \(Text(dep).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(about)\(Text(arrTimeStr).bold()).")
```

with:

```swift
                    } else if isStillOnGround, let dep, let dest {
                        Text("\(name) \(atDeparturePhrase) \(Text(dep).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: shiftedArr, color: countdownColor)) which is \(about)\(Text(arrTimeStr).bold()).")
```

Replace:

```swift
            } else if isStillOnGround, let dep {
                Text("\(name) is still on the ground in \(Text(dep).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: arrTime)) which is \(about)\(Text(arrTimeStr).bold()).")
```

with:

```swift
            } else if isStillOnGround, let dep {
                Text("\(name) \(atDeparturePhrase) \(Text(dep).bold())\(fltStr.isEmpty ? " on the flight" : fltStr) to \(Text(dest).bold()) — landing in \(countdownText(to: arrTime)) which is \(about)\(Text(arrTimeStr).bold()).")
```

Replace:

```swift
    /// "Alex has landed in Anchorage on UPS flight 2963 — at the gate in 8m which is 7:52pm EST.", with the gate's
```

with:

```swift
    /// "is still on the ground in" Rockford, or "has returned to" it after an air return (air return design §3).
    private var atDeparturePhrase: String {
        hasReturned ? "has returned to" : "is still on the ground in"
    }

    /// "Alex has landed in Anchorage on UPS flight 2963 — at the gate in 8m which is 7:52pm EST.", with the gate's
```

- [ ] **Step 2: The previews.**

In `Crewluv/Views/TripMap/TripMapPreviews.swift`:

Replace:

```swift
    /// The Europe trip `minutesLate` minutes after its first flight's takeoff time, with its real plane still at the
    /// gate in Louisville (which plane design §4).
    static func europeAtTheGate(minutesLate: Double) -> TripMap? {
```

with:

```swift
    /// The Europe trip `minutesLate` minutes after its first flight's takeoff time, with its real plane still at the
    /// gate in Louisville (which plane design §4), or back there after an air return when `hasReturned`: out 30 nm and
    /// back, up to 9,000 ft (air return design §3).
    static func europeAtTheGate(minutesLate: Double, hasReturned: Bool = false) -> TripMap? {
```

Replace:

```swift
        let live = LiveFlight(legID: "UPS207", callsign: "UPS207", state: .ground, fix: fix, landedAt: nil, trail: [])
```

with:

```swift
        let outAndBack = [(0.1, 2_000.0), (0.4, 7_000.0), (0.6, 9_000.0), (0.4, 6_000.0), (0.1, 1_500.0)]
        let trail = hasReturned ? outAndBack.enumerated().map { index, step in
            LiveFlight.TrailPoint(time: start.addingTimeInterval(FlightProgress.taxiOutAllowance + Double(index + 1) * 120),
                                  latitude: origin.latitude, longitude: origin.longitude + step.0, altitudeFeet: step.1)
        } : []
        let live = LiveFlight(legID: "UPS207", callsign: "UPS207", state: .ground, fix: fix, landedAt: nil, trail: trail)
```

Replace:

```swift
#Preview("Real plane, landed, not yet at the gate") {
```

with:

```swift
#Preview("Real plane, returned to the gate") {
    if let map = TripMapPreviewData.europeAtTheGate(minutesLate: 40, hasReturned: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Full screen, real plane returned to the gate") {
    if let map = TripMapPreviewData.europeAtTheGate(minutesLate: 40, hasReturned: true) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Real plane, landed, not yet at the gate") {
```

---

### Task 5: The docs

- [ ] **Step 1: The design's names, as the code has them.**

In `docs/superpowers/specs/2026-11-17-air-return-design.md`:

Replace:

```swift
  (`LiveProgress.returnClimb`, `RETURN_CLIMB`). Points with no height don't count.
```

with:

```swift
  (`LiveFlight.returnClimbFeet`, `RETURN_CLIMB_FEET`). Points with no height don't count.
```

Replace:

```swift
- is within 10 nm of the departure airport,
- comes more than 10 minutes after the point before it (`FlightPath.restartGap`, `RESTART_GAP`), and
- comes after the trail had climbed 1,000 ft (§2), with the point before it also within 10 nm.
```

with:

```swift
- is within 30 nm of the departure airport (`FlightPath.firstPointRadius`, as for a first point that tells the
  takeoff), since coverage low down can miss the first minutes of the climb,
- comes more than 10 minutes after the point before it (`LiveFlight.restartGap`, `RESTART_GAP`), and
- comes after the trail had climbed 1,000 ft (§2), with the point before it within 10 nm.

The plane's fix in the air, when it's newer than the trail, can start one too, so the path is right from the takeoff,
before its first new point (from the plan's review).
```

Replace:

```swift
- **The real plane** is drawn where its fix is, at the departure airport, as `onGround` draws it. **No ghost**, and no
  distance along the path.
```

with:

```swift
- **The real plane** is drawn where its fix is, at the departure airport, at the start of its path, as `onGround` draws
  it. **No ghost.**
```

Replace:

```swift
| The line under the timeline (and the slider's spoken value) | "Mon 12:21 PM · Still on the ground in Rockford" | **Mon 12:21 PM · Returned to Rockford** |
```

with:

```swift
| The line under the timeline (and the slider's spoken value) | "Mon 12:21 PM · On the ground in Rockford" | **Mon 12:21 PM · Returned to Rockford** |
```

Replace:

```swift
| VoiceOver's label | "still on the ground" | **returned to Rockford** |
```

with:

```swift
| The plane's popup | "Still on the ground · 40 min behind", "Lands about 9:11 AM" | **Returned to Rockford**, "Lands about 9:11 AM" |
| VoiceOver's label | "still on the ground" | **returned to Rockford** |
```

- [ ] **Step 2:**

In `CLAUDE.md`:

Replace:

```swift
- The real plane's engine (Stage 3 spec `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`) is in `Services/TripMap/Live/`. `FlightPlan` is the schedule's plan the real plane is measured against, and `flown(along:)` is that plan as the plane flies it: at the plane's own speed for 2 hours of its cruise on from where it was last seen, and the schedule's after that, once ten minutes of its cruise have been seen (best guesses after a long gap design `docs/superpowers/specs/2026-11-17-crewluve-best-guesses-after-a-long-gap-design.md`). The landing estimate, the ghost and the record all fly that one. `FlightPath` is a flight's path, real once the plane has been seen in the air, and `FlightRecord` where it was at any moment. `LiveProgress` is the real plane at one moment: live, estimated or landed, its landing estimate and label, where the ghost flies, and the leg's real times. `LiveFlightSource` asks Crewlu Cloud's `partner_live` once when the screen comes to the front and every 30 seconds while a flight's window is open (`LiveWindow`). The call is `LiveFlightDoor`, apart from `PartnerDoor`, so none of the helper's 15 files needs the live plane's types
```

with:

```swift
- The real plane's engine (Stage 3 spec `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`) is in `Services/TripMap/Live/`. `FlightPlan` is the schedule's plan the real plane is measured against, and `flown(along:)` is that plan as the plane flies it: at the plane's own speed for 2 hours of its cruise on from where it was last seen, and the schedule's after that, once ten minutes of its cruise have been seen (best guesses after a long gap design `docs/superpowers/specs/2026-11-17-crewluve-best-guesses-after-a-long-gap-design.md`). The landing estimate, the ghost and the record all fly that one. `FlightPath` is a flight's path, real once the plane has been seen in the air, and `FlightRecord` where it was at any moment. `LiveProgress` is the real plane at one moment: live, estimated or landed, its landing estimate and label, where the ghost flies, and the leg's real times. `LiveFlightSource` asks Crewlu Cloud's `partner_live` once when the screen comes to the front and every 30 seconds while a flight's window is open (`LiveWindow`). The call is `LiveFlightDoor`, apart from `PartnerDoor`, so none of the helper's 15 files needs the live plane's types. A plane on the ground near its departure airport whose trail has climbed 1,000 ft has flown and come back (`LiveFlight.isBack`, air return design `docs/superpowers/specs/2026-11-17-air-return-design.md`): its phase is `returned`, with no ghost and the leg held open as for a plane still at the gate, and it reads "Returned to Rockford" on the bar, in the popup, the facts, under the timeline (`FlightOnGround`, which also names "On the ground in" and "Landed in") and in the status sentence. A path and its record are made from the trail's latest try (`LiveFlight.latestTry`), so a second takeoff starts the path afresh
```

---

### Task 6: Todd's run, the commits, the website and a look

- [ ] **Step 1: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`, with 1,192 tests in the result bundle (1,172 before).

- [ ] **Step 2: Ask to commit:** one commit for each of Tasks 1 to 4, then Task 5 with this plan. Then ask whether to add a line to the 1.4 (49) release note: "If a flight turns back and lands where it left from, Crewluve says \"Returned to Rockford\" in place of still on the ground, and starts its path afresh when it takes off again."

- [ ] **Step 3: Send the website session** the rule, the commits, and that `live-cases.json` has four new flights and two new labels to copy, for its own plan.

- [ ] **Step 4: Todd looks** at the previews "Real plane, returned to the gate" and "Full screen, real plane returned to the gate": "Returned to Louisville" on the card's bar, the chip, the sheet's first row, under the timeline and in the real plane's popup; no ghost; no sky row.

## Left for later

- **A return to another airport** stays a diversion (`elsewhere`), as today.
- **A flight cancelled after a return** reads "Returned to Rockford" until Crewlu Cloud stops watching it.
- **The first trip out and back** drawn as a faint line.
- **The facts' story** of the way out and back can show for up to a minute after a second takeoff, until `LegStoryStore` makes the new path's (from the plan's review): it's read by distance, so only briefly wrong.
- **The names** `isStillOnGround`, `stillOnGroundAirport` and `stillOnGroundFlight` now cover a plane back at the gate too, as their comments say: a rename to "at departure" is a tidy for later.

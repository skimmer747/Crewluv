# Best Guesses After a Long Gap (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The real plane's landing estimate flies its own speed for only the next 2 hours from where it was last tracked, and the schedule's after that; and past 2 hours out of tracking range, the facts name only an ocean and hold their events until the plane is tracked again, or the flight is over.

**Architecture:**
- **The speed:** `FlightPlan.flown(along:)` makes the plane's own speed for 2 hours and the schedule's after into one cruise speed, `FlightPlan.cruiseSpeed(over:own:planned:)`. The estimate, the estimated plane, the ghost and the record already fly that one plan, so nothing else changes. The shared reference, `scripts/live-cases/live.mjs`, does the same, and writes the cases both the app and the website run.
- **The words:** `PlanePosition.isPastGuessHorizon` says the plane has been out of range more than 2 hours. `TripFacts` then names only an ocean under it (`Geography.Place.isOcean`), with no city. While the flight is in the air, `TripFacts.milestones(on:at:)` leaves out an event guessed more than 2 hours after the plane was last seen, until a new sighting moves that on; once the flight is over, they're all told.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS 26, XCTest, Node for the shared reference.

**Source:** the best guesses after a long gap design, `docs/superpowers/specs/2026-11-17-crewluve-best-guesses-after-a-long-gap-design.md`, approved by Todd on 17 Nov 2026.

**How this plan was checked.**
- **A scratch Swift package** with the app target's settings, made from the repo at `ef21b82`: 582 XCTest and 71 Swift Testing tests before, 596 and 71 with this plan, all passing, no warnings.
- **Task by task:** the package was run as it stood after Task 2 and after Task 3, all passing: 585 XCTest tests after Task 2, and 596 after Task 3.
- **20 deliberate breaks** were made in the new code, one at a time, and every one fails at least one test: its own speed all the way, or the plan's; an hour in place of 2; the descent counted as cruise; the two speeds swapped or averaged; no cruise left flown at the plan's speed; no event held, or every guess; held events told by the headline, the banner or the list; events still held after the flight is over; a city, a sea or land named past 2 hours, or not even an ocean; a misspelt ocean; and the 2 hours counted from the moment the plane was seen.
- **The whole app was type-checked for iOS** with `swiftc` outside Xcode, and compiled for the iOS simulator with the whole plan in: no errors and no warnings.
- **The plan was followed by a script** on the repo at `ef21b82`, running the reference as Task 2 says: all 15 files came out the same as the tested ones.
- **UPS96 and UPS82 were run through the reference again** from Crewlu Cloud's record of them, as the design asks: at the last sighting before each long gap, UPS96 goes from 42 minutes early to 17, touching down about 07:59 UTC and reaching the gate about 3:06 AM EST, and UPS82 stays 5 minutes late. Those are the design's numbers.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together: nothing critical. It confirmed that the Swift and the reference agree, and that only a guess ahead of the last sighting can be held. From its points: held events are told once the flight is over, so a plane never tracked again doesn't lose them for good, halfway among them; a replay of a gap closed by a new sighting has a test; the method that names what's below no longer shares its name with a constant; the 2-hour edge has a test; and the new shared case goes last, so the website's cases keep their places. Left, with reasons: sun countdowns still read the guessed course past 2 hours, which moves them by minutes at most; and the fix and the path's last sighting stay two readings of one moment, as before.
- **Not checked:** nothing ran on a simulator or a device, and no view was seen.

**Where this plan settles details.**
- **The speed is worked out from the path,** not the fix: the cruise left is the path ahead of the last place the plane was seen, less the descent's 120 nm, as the record already measures it. The landing estimate measures from the fix, which is that same place.
- **One rule holds the events back:** an event whose time is more than 2 hours after the plane was last seen, while the flight is in the air. Every event up to the last sighting happened before it, so only a guess ahead can be held, and a landed flight's last sighting is its landing, so it holds nothing. `Milestone.milestones` still gives the story's every milestone, for the shared cases; `TripFacts` decides which are told.
- **A plane never tracked again:** once its flight is over, by its estimate, the held events are all told as best guesses, so the list isn't missing them for good. The design didn't say; Todd's review of the plan can change it. The design gets a line saying so (Task 4).
- **A replay of a gap closed by a new sighting** reads the straight join between the two places the plane was seen, as the best guesses design §3 has it, with cities. Only the open end of a gap, past the last sighting, is held to 2 hours.
- **The oceans are named as geography.json names them:** "the Pacific", "the Atlantic", "the Indian Ocean", "the Arctic Ocean" and "the Southern Ocean". A test holds the list to the file, so a rename there can't quietly stop them being named.
- **The existing Cologne case lands a minute sooner:** its last 79 nm past 2 hours of its own 479.6 kt now go at the plan's 508.1. The words tests that read it change from 3:55 to 3:54.

---

## Ground rules

1. **Don't run `xcodebuild` build or test loops.** Todd runs the tests (Task 5).
2. **Never commit without Todd's go-ahead,** and then only this plan's files, by path. **Never push** without a fresh yes.
3. **Copy the code as written.** A replacement is exact: if its text isn't in the file once, stop.
4. **Never edit `live-cases.json` by hand.** It's written by `node scripts/live-cases/generate.mjs` from the reference.
5. **Work on `feature/trip-map-live`.** Never stash, reset or switch branches.

## File map

| File | Task | What changes |
|---|---|---|
| `scripts/live-cases/live.mjs`, `generate.mjs`, `CrewluvTests/Fixtures/TripMap/live-cases.json` | 2 | the reference's speed, a long ocean gap case, and the cases it writes |
| `Crewluv/Services/TripMap/Live/FlightPlan.swift` | 2 | its own speed for 2 hours, the plan's after |
| `CrewluvTests/Helpers/LiveCases.swift`, `FlightPlanTests.swift`, `LiveWordingTests.swift` | 2 | the new constant, the speed's tests, and a minute sooner for the Cologne case |
| `Crewluv/Services/TripMap/Facts/PlanePosition.swift`, `Geography.swift`, `TripFacts.swift` | 3 | past 2 hours: only an ocean, and events held |
| `CrewluvTests/LongGapFactsTests.swift` (new) | 3 | the words' tests |
| `CLAUDE.md`, `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`, `2026-11-15-crewluve-facts-best-guesses-design.md`, `2026-11-17-crewluve-best-guesses-after-a-long-gap-design.md` | 4 | the docs |

---

### Task 1: Before starting

- [x] **Step 1:** The branch is `feature/trip-map-live`, at `ef21b82` or later, and none of this plan's files has changed since.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

---

### Task 2: The plane's own speed for 2 hours, the plan's after (design §2)

- [x] **Step 1: The reference.**

In `scripts/live-cases/live.mjs`:

Replace:

```swift
export const OWN_SPEED_MOST_SHARE = 1.5
```

with:

```swift
export const OWN_SPEED_MOST_SHARE = 1.5
export const OWN_SPEED_AHEAD = 2 * 3600
```

Replace:

```swift
/// The schedule's plan with the plane's own speed for its cruise, once that's known and could be right: from 0.7 of
/// the plan's cruise speed to 1.5 of it. Its takeoff and touchdown are still the schedule's.
export function flownPlan(plan, path) {
  if (plan.cruise === null) return plan
  const own = ownSpeed(path)
  if (own === null || !(own >= plan.cruise * OWN_SPEED_LEAST_SHARE && own <= plan.cruise * OWN_SPEED_MOST_SHARE)) return plan
  return { ...plan, cruise: own }
}
```

with:

```swift
/// The schedule's plan with the plane's own speed for its cruise, once that's known and could be right: from 0.7 of
/// the plan's cruise speed to 1.5 of it. The cruise left from the last place the plane was seen is flown at its own
/// speed for two hours, or all the way when that's further, and at the plan's after that: the plan's cruise is the one
/// speed that flies it all in the same time (long gap design §2). Its takeoff and touchdown are still the schedule's.
export function flownPlan(plan, path) {
  if (plan.cruise === null) return plan
  const own = ownSpeed(path)
  if (own === null || !(own >= plan.cruise * OWN_SPEED_LEAST_SHARE && own <= plan.cruise * OWN_SPEED_MOST_SHARE)) return plan
  const cruiseLeft = path.length - path.flown - DESCENT_DISTANCE
  if (!(cruiseLeft > 0)) return { ...plan, cruise: own }
  const atOwn = Math.min(cruiseLeft, own * OWN_SPEED_AHEAD)
  return { ...plan, cruise: cruiseLeft / (atOwn / own + (cruiseLeft - atOwn) / plan.cruise) }
}
```

In `scripts/live-cases/generate.mjs`:

Replace:

```swift
// A hold inside the last 120 nm: 430 kt to 135 nm short of Philadelphia, then 240 kt out to the north and back.
```

with:

```swift
// Louisville to Cologne on time and faster than the plan, seen over land, and then never again over the ocean.
const gapRoute = [airports.SDF, airports.CGN]
const gapOffAt = t('2026-11-13T18:15:00Z')
const gapKnots = 560
const gapTimes = []
for (let time = t('2026-11-13T18:19:00Z'); time <= t('2026-11-13T19:39:00Z'); time += 240) gapTimes.push(time)
const gapTrail = gapTimes.map((time) => trailPoint(gapRoute, gapKnots, gapOffAt, time, 37000))

// A hold inside the last 120 nm: 430 kt to 135 nm short of Philadelphia, then 240 kt out to the north and back.
```

Replace:

```swift
    flight: null,
    moments: [['2026-11-13T12:30:00Z', 'Not live.']],
  }),
]
```

with:

```swift
    flight: null,
    moments: [['2026-11-13T12:30:00Z', 'Not live.']],
  }),
  flightCase({
    name: 'faster than the plan, then a long ocean gap', from: 'SDF', to: 'CGN', departure: '2026-11-13T18:00:00Z', arrival: '2026-11-14T02:00:00Z',
    note: 'Off on time along the great circle at 560 kt, faster than the plan\'s 508.1 kt, seen every 4 minutes until 19:39 and at the fix at 19:39:30, and never again. 2,872 nm of its cruise is left from the fix: the first 1,120 nm, 2 hours of it, are flown at its own 560 kt and the rest at the plan\'s, which is one speed of 527.1 kt over all of it and a touchdown at 01:32, 21 minutes ahead. At its own speed all the way it would be 01:13. The landing estimate, the estimated plane and the ghost all fly the one speed, and the estimate holds still through the gap.',
    flight: wire('leg-cgn', 'UPS207', 'airborne', airFix(gapRoute, gapKnots, gapOffAt, t('2026-11-13T19:39:30Z'), 37000), null, gapTrail),
    moments: [
      ['2026-11-13T19:39:40Z', 'In the air, at the fix.'],
      ['2026-11-13T19:42:31Z', 'The fix is just over 3 minutes old: estimated, with the same estimate.'],
      ['2026-11-13T21:39:30Z', 'Two hours on from the fix, far out over the ocean.'],
      ['2026-11-14T01:00:00Z', 'Nearly there, still unseen: the estimate is the same as at the fix.'],
    ],
    places: ['2026-11-13T19:00:00Z', '2026-11-13T21:39:30Z', '2026-11-14T01:00:00Z'],
    distancesNm: [500, 2000, 3500],
  }),
]
```

Replace:

```swift
  about: 'The real plane (Crewluve moving map Stage 3 spec §4 to §7, §10.2). Made by a reference written apart from the app and the website, and run by both: the app\'s FlightPlanTests, FlightPathTests, FlightRecordTests, LiveProgressTests, LiveLabelTests and LiveWindowTests, and the website\'s tests. Change both copies together. Every `at`, and every time in an answer, is an ISO 8601 time with milliseconds. A `flight` is one entry of partner_live\'s `flights`, exactly as the door answers it, with times in milliseconds since 1970, or null where the door answers none. Distances are nautical miles of 1,852 m along a sphere of radius 6,371,008.8 m, to the nearest thousandth; places are [latitude, longitude]. A gap is the plan\'s touchdown minus the estimated one in minutes, rounded to the nearest with halves away from zero; ahead is positive. A path\'s `ownSpeedKt` is the plane\'s own speed over its cruise so far, or null when too little of it has been seen, and a flight\'s `flownSpeedKt` is the speed its estimate, its estimated plane and its ghost fly the cruise at: that one when it\'s from 0.7 of the plan\'s to 1.5 of it, and the plan\'s otherwise. Compare speeds to 0.01 kt. Compare distances to 0.01 nm, times to 0.05 s and places to 0.0001 of a degree.',
```

with:

```swift
  about: 'The real plane (Crewluve moving map Stage 3 spec §4 to §7, §10.2). Made by a reference written apart from the app and the website, and run by both: the app\'s FlightPlanTests, FlightPathTests, FlightRecordTests, LiveProgressTests, LiveLabelTests and LiveWindowTests, and the website\'s tests. Change both copies together. Every `at`, and every time in an answer, is an ISO 8601 time with milliseconds. A `flight` is one entry of partner_live\'s `flights`, exactly as the door answers it, with times in milliseconds since 1970, or null where the door answers none. Distances are nautical miles of 1,852 m along a sphere of radius 6,371,008.8 m, to the nearest thousandth; places are [latitude, longitude]. A gap is the plan\'s touchdown minus the estimated one in minutes, rounded to the nearest with halves away from zero; ahead is positive. A path\'s `ownSpeedKt` is the plane\'s own speed over its cruise so far, or null when too little of it has been seen, and a flight\'s `flownSpeedKt` is the speed its estimate, its estimated plane and its ghost fly the cruise at. When its own speed is from 0.7 of the plan\'s to 1.5 of it, the cruise left from the last place it was seen is flown at its own speed for `ownSpeedAheadMinutes`, or all the way when that\'s further, and at the plan\'s after that, and `flownSpeedKt` is the one speed that flies it all in the same time. Otherwise it\'s the plan\'s. Compare speeds to 0.01 kt. Compare distances to 0.01 nm, times to 0.05 s and places to 0.0001 of a degree.',
```

Replace:

```swift
    ownSpeedLeastMinutes: live.OWN_SPEED_LEAST / 60, ownSpeedLeastShare: live.OWN_SPEED_LEAST_SHARE, ownSpeedMostShare: live.OWN_SPEED_MOST_SHARE,
```

with:

```swift
    ownSpeedLeastMinutes: live.OWN_SPEED_LEAST / 60, ownSpeedLeastShare: live.OWN_SPEED_LEAST_SHARE, ownSpeedMostShare: live.OWN_SPEED_MOST_SHARE,
    ownSpeedAheadMinutes: live.OWN_SPEED_AHEAD / 60,
```

- [x] **Step 2: Write the shared cases from it.**

```bash
cd /Users/toddanderson/Dev/Crewluv && node scripts/live-cases/generate.mjs | grep -E "^[0-9]+ plans|long ocean gap|unseen ocean"
```

Expected:

```
7 plans, 30 flights, 29 labels, 12 gaps, 12 windows; 119343 bytes
- behind, with a late first point and an unseen ocean: path 3816.226 nm (22 stretches, unseen 1502.018), own 479.55 kt, flown at 481.62 kt, 00:13:00 inAir gap -55 "55 min behind" plane 2657.657 ghost 3099.935 | 00:20:00 estimated gap -55 "About 55 min behind" plane 2717.859 ghost 3156.124
- faster than the plan, then a long ocean gap: path 3780.621 nm (23 stretches, unseen 37.333), own 560 kt, flown at 527.142 kt, 19:39:40 inAir gap 21 "21 min ahead" plane 788.667 ghost 606.545 | 19:42:31 estimated gap 21 "About 21 min ahead" plane 815.17 ghost 631.584 | 21:39:30 estimated gap 21 "About 21 min ahead" plane 1842.95 ghost 1659.364 | 01:00:00 estimated gap 21 "About 21 min ahead" plane 3604.483 ghost 3420.897
```

- [x] **Step 3: The tests.**

In `CrewluvTests/Helpers/LiveCases.swift`:

Replace:

```swift
            let ownSpeedMostShare: Double
```

with:

```swift
            let ownSpeedMostShare: Double
            let ownSpeedAheadMinutes: Double
```

In `CrewluvTests/FlightPlanTests.swift`:

Replace:

```swift
        XCTAssertEqual(FlightPlan.ownSpeedShares, constants.ownSpeedLeastShare...constants.ownSpeedMostShare)
    }
```

with:

```swift
        XCTAssertEqual(FlightPlan.ownSpeedShares, constants.ownSpeedLeastShare...constants.ownSpeedMostShare)
        XCTAssertEqual(FlightPlan.ownSpeedAhead, constants.ownSpeedAheadMinutes * 60)
    }

    // MARK: - Its own speed for 2 hours, and the plan's after (long gap design §2)

    private var knot: Double { nauticalMile / 3600 }

    func test_cruiseSpeed_withUnderTwoHoursOfCruiseLeft_isThePlanesOwn() {
        // 800 nm at its own 450 kt is 1 h 47 min.
        XCTAssertEqual(FlightPlan.cruiseSpeed(over: 800 * nauticalMile, own: 450 * knot, planned: 500 * knot) / knot, 450, accuracy: 1e-9)
    }

    func test_cruiseSpeed_pastTwoHours_fliesThePlansSpeedForTheRest() {
        // 2,000 nm: 900 at its own 450 kt in 2 hours, and 1,100 at the plan's 500 kt in 2.2 hours. 2,000 nm in 4.2 hours.
        XCTAssertEqual(FlightPlan.cruiseSpeed(over: 2000 * nauticalMile, own: 450 * knot, planned: 500 * knot) / knot, 2000 / 4.2, accuracy: 1e-9)
        // Faster than the plan: 1,100 at its own 550 kt in 2 hours, and 900 at the plan's 500 in 1.8.
        XCTAssertEqual(FlightPlan.cruiseSpeed(over: 2000 * nauticalMile, own: 550 * knot, planned: 500 * knot) / knot, 2000 / 3.8, accuracy: 1e-9)
    }

    func test_cruiseSpeed_withNoCruiseLeft_isThePlanesOwn() {
        XCTAssertEqual(FlightPlan.cruiseSpeed(over: 0, own: 450 * knot, planned: 500 * knot), 450 * knot)
        XCTAssertEqual(FlightPlan.cruiseSpeed(over: -10 * nauticalMile, own: 450 * knot, planned: 500 * knot), 450 * knot)
    }
```

In `CrewluvTests/LiveWordingTests.swift`:

Replace:

```swift
                       "Lands Cologne about 3:55 AM · 9:55 PM your time")
```

with:

```swift
                       "Lands Cologne about 3:54 AM · 9:54 PM your time")
```

Replace:

```swift
        XCTAssertEqual(plain(FactsWording.lands(toCologne, calendar: calendar, locale: locale)), "lands about 3:55 AM there")
```

with:

```swift
        XCTAssertEqual(plain(FactsWording.lands(toCologne, calendar: calendar, locale: locale)), "lands about 3:54 AM there")
```

Replace:

```swift
                       "UPS207 to Cologne, 55 minutes behind schedule, over Québec. Lands about 9:55 PM your time.")
```

with:

```swift
                       "UPS207 to Cologne, 55 minutes behind schedule, over Québec. Lands about 9:54 PM your time.")
```

Replace:

```swift
                       "UPS207 to Cologne, 55 minutes behind schedule. Lands about 9:55 PM your time.")
```

with:

```swift
                       "UPS207 to Cologne, 55 minutes behind schedule. Lands about 9:54 PM your time.")
```

- [x] **Step 4: The app.**

In `Crewluv/Services/TripMap/Live/FlightPlan.swift`:

Replace:

```swift
//  it flies in between. The real plane is measured against it, flown at the plane's own speed once that's known.
```

with:

```swift
//  it flies in between. The real plane is measured against it, flown at the plane's own speed for the next 2 hours
//  once that's known, and at the schedule's after that.
```

Replace:

```swift
    static let ownSpeedShares: ClosedRange<Double> = 0.7...1.5
```

with:

```swift
    static let ownSpeedShares: ClosedRange<Double> = 0.7...1.5

    /// How far ahead of the last place the plane was seen its own speed is trusted: 2 hours of its cruise. Past that,
    /// the winds it meets are the schedule's to know, and so is its speed (long gap design §2).
    static let ownSpeedAhead: TimeInterval = 2 * 60 * 60
```

Replace:

```swift
    /// This plan as the plane flies it: with the plane's own speed over its cruise so far in place of the schedule's,
    /// once `path` has one that could be right. The takeoff and the touchdown stay the schedule's, and a leg flown at
    /// one steady speed keeps it. The landing estimate, the estimated plane and the ghost all fly this plan, so the
    /// gap between the two planes is still the label.
    func flown(along path: FlightPath) -> FlightPlan {
        guard !isSteady, let own = path.ownSpeed else { return self }
        let believed = speed * Self.ownSpeedShares.lowerBound...speed * Self.ownSpeedShares.upperBound
        guard believed.contains(own) else { return self }
        return FlightPlan(self, speed: own)
    }
```

with:

```swift
    /// This plan as the plane flies it, once `path` has an own speed that could be right: that speed for the next
    /// `ownSpeedAhead` of the cruise left from the last place the plane was seen, and the schedule's after, made into
    /// the one speed that flies the cruise left in the same time (long gap design §2). The takeoff and the touchdown
    /// stay the schedule's, and a leg flown at one steady speed keeps it. The landing estimate, the estimated plane
    /// and the ghost all fly this plan, so the gap between the two planes is still the label. Only the time is meant:
    /// in its first 2 hours unseen, the estimated plane is a little behind where its own speed would have it.
    func flown(along path: FlightPath) -> FlightPlan {
        guard !isSteady, let own = path.ownSpeed else { return self }
        let believed = speed * Self.ownSpeedShares.lowerBound...speed * Self.ownSpeedShares.upperBound
        guard believed.contains(own) else { return self }
        // The way left from the last place it was seen is the great circle, and its last 120 nm the descent.
        let cruiseLeft = path.length - path.flownLength - Self.descentDistance
        return FlightPlan(self, speed: Self.cruiseSpeed(over: cruiseLeft, own: own, planned: speed))
    }

    /// The one speed that flies `cruise` meters in the time it takes at `own` for `ownSpeedAhead`, or all the way when
    /// that's further, and at `planned` for the rest. With no cruise left, `own`.
    static func cruiseSpeed(over cruise: Double, own: Double, planned: Double) -> Double {
        guard cruise > 0 else { return own }
        let atOwnSpeed = min(cruise, own * ownSpeedAhead)
        return cruise / (atOwnSpeed / own + (cruise - atOwnSpeed) / planned)
    }
```

---

### Task 3: Past 2 hours, only an ocean, and events held (design §3)

- [x] **Step 1: The tests.**

Create `CrewluvTests/LongGapFactsTests.swift`:

```swift
//
//  LongGapFactsTests.swift
//  CrewluvTests
//
//  The facts past 2 hours out of tracking range (long gap design §3), in US English for a family in Louisville. The
//  made-up flight is `FactsTestData`'s equator flight, to 24° E: in the air from 10:15 to 13:15 UTC by the schedule,
//  whose cruise is 513.7 kt. The real plane flies a degree every 8 minutes (450 kt) and is last seen at 3.75° E at
//  10:45. From there it's flown on at 450 kt for 2 hours of its cruise and at the plan's after, one speed of 460.2 kt,
//  so it touches down at 13:33.6 by its estimate and is guessed at 19.1° E at 12:45, 2 hours after it was last seen.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LongGapFactsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    /// Along the equator: Alpha to 5° E, Bravo to 10° E, the Atlantic to 20° E, the Test Sea to 21° E and Delta to
    /// 25° E, with Portville 0.1° north of 19.1° E.
    private let geography = Geography(
        areas: [FactsTestData.box("Alpha", .country, west: -1, east: 5),
                FactsTestData.box("Bravo", .country, west: 5, east: 10),
                FactsTestData.box("the Atlantic", .water, west: 10, east: 20),
                FactsTestData.box("the Test Sea", .water, west: 20, east: 21),
                FactsTestData.box("Delta", .country, west: 21, east: 25)],
        cities: [Geography.City(name: "Portville", lat: 0.1, lon: 19.1)]
    )

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// The facts of a map of the one flight, last seen at `seenUntil` and nobody seeing it over `unseen`, made at `now`.
    private func facts(seenUntil: String = "10:45", now: String, unseen: ClosedRange<Double>? = nil,
                       isReplay: Bool = false) throws -> TripFacts {
        let live = FactsTestData.equatorLive(seenUntil: at(seenUntil), unseen: unseen)
        let leg = try FactsTestData.equatorLiveLeg(live, at: at(now), to: 24)
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: geography, comparisons: nil,
                         stories: [leg.id: LegStory(leg: leg, geography: geography, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], calendar: calendar, locale: locale,
                         isReplay: isReplay)
    }

    private func events(_ facts: TripFacts, at time: String) -> [String?]? {
        facts.tripSoFar(at: at(time)).flights.first?.events.map { plain($0.text) }
    }

    // MARK: - What's below

    func test_below_pastTwoHoursOutOfRange_namesTheOcean_withNoCity() throws {
        // At 12:43, 1 h 58 min after it was last seen, it's guessed at 18.8° E, 20 mi from Portville.
        XCTAssertEqual(try facts(now: "12:43").headline(at: at("12:43")), "Over the Atlantic, near Portville")
        // At 12:48, 2 h 3 min after, at 19.5° E: still 26 mi from Portville, but past 2 hours no city is told.
        XCTAssertEqual(try facts(now: "12:48").headline(at: at("12:48")), "Over the Atlantic")
    }

    func test_below_pastTwoHoursOutOfRange_overASeaOrLand_namesNothing_andTheHeadlineIsTheLandingCountdown() throws {
        // It reaches the gate at 13:40.6 by its estimate. At 12:58 it's guessed at 20.75° E, over the Test Sea.
        XCTAssertEqual(try facts(now: "12:58").headline(at: at("12:58")), "Landing in 43 min")
        // At 13:10, at 22.2° E, over Delta.
        let overDelta = try facts(now: "13:10")
        XCTAssertEqual(overDelta.headline(at: at("13:10")), "Landing in 31 min")
        XCTAssertNil(overDelta.belowText(on: try XCTUnwrap(overDelta.tripMap.currentLeg), at: at("13:10")))
        // Within 2 hours of the last sighting, land is named as before.
        let near = try facts(seenUntil: "11:20", now: "13:10")
        XCTAssertEqual(near.headline(at: at("13:10")), "Over Delta")
    }

    func test_below_inAReplay_pastTwoHoursAfterTheLastSighting_namesOnlyTheOcean() throws {
        let replay = try facts(now: "13:10", isReplay: true)
        XCTAssertEqual(replay.headline(at: at("12:43")), "Over the Atlantic, near Portville")
        XCTAssertEqual(replay.headline(at: at("12:48")), "Over the Atlantic")
    }

    func test_below_inAReplay_ofAGapClosedByANewSighting_isWhatsOnTheStraightJoin() throws {
        // Seen again at 20.5° E at 12:59, the gap is a straight join between two places the plane was seen, so at
        // 12:50, at 19.4° E on it, the city by it is told as ever.
        let replay = try facts(seenUntil: "13:05", now: "13:05", unseen: 3.8...20.5, isReplay: true)
        XCTAssertEqual(replay.headline(at: at("12:50")), "Over the Atlantic, near Portville")
    }

    func test_isPastGuessHorizon_fromTwoHoursOutOfRange() {
        let place = CLLocationCoordinate2D(latitude: 0, longitude: 10)
        func plane(unseenFor: TimeInterval?) -> PlanePosition {
            PlanePosition(distance: 0, coordinate: place, unseenFor: unseenFor, isSeenInAir: false)
        }
        XCTAssertFalse(plane(unseenFor: nil).isPastGuessHorizon)
        XCTAssertFalse(plane(unseenFor: 2 * 60 * 60).isPastGuessHorizon)
        XCTAssertTrue(plane(unseenFor: 2 * 60 * 60 + 1).isPastGuessHorizon)
    }

    // MARK: - Events

    func test_events_guessedPastTwoHoursAfterTheLastSighting_areHeld() throws {
        // By the guess it crosses into Delta at 21° E just before 13:00, over 2 hours after it was last seen: not told. The
        // others were guessed within the 2 hours, and are told with "about".
        let guessed = try facts(now: "13:10")
        XCTAssertEqual(events(guessed, at: "13:10"), [
            "Closest to home, 35 mi · about 8:05 AM", "Halfway · about 7:49 AM", "Out over the Atlantic · about 7:34 AM",
            "Crossed into Bravo · about 6:54 AM",
        ])
        XCTAssertEqual(guessed.latestEvent(at: at("13:10"))?.title, "Closest to home, 35 mi")
        XCTAssertNotEqual(guessed.headline(at: at("13:02")), "Just crossed into Delta")
    }

    func test_events_neverTrackedAgain_areAllToldAsBestGuesses_onceTheFlightIsOver() throws {
        // It reaches the gate at 13:40.6 by its estimate. After that the crossing into Delta is told too.
        let over = try facts(now: "13:45")
        XCTAssertEqual(events(over, at: "13:45")?.first, "Crossed into Delta · about 8:59 AM")
        XCTAssertEqual(over.tripSoFar(at: at("13:45")).flights.first?.events.count, 5)
    }

    func test_events_onceThePlaneIsTrackedAgain_areToldOnTheStraightJoin() throws {
        // Nobody saw it from 3.75° E at 10:45 to 20.5° E at 12:59. Seen again, it crossed into Delta just before
        // 13:03, and what it passed in the gap is told on the straight join between the two, with "about".
        let trackedAgain = try facts(seenUntil: "13:05", now: "13:05", unseen: 3.8...20.5)
        XCTAssertEqual(events(trackedAgain, at: "13:05"), [
            "Crossed into Delta · 9:02 AM", "Closest to home, 35 mi · about 8:06 AM", "Halfway · about 7:51 AM",
            "Out over the Atlantic · about 7:35 AM", "Crossed into Bravo · about 6:55 AM",
        ])
    }

    // MARK: - The card for VoiceOver

    func test_cardSummary_pastTwoHoursOverLand_leavesOutWhatsBelow() throws {
        XCTAssertEqual(plain(try facts(now: "13:10").cardSummary(now: at("13:10"), pilotName: "Alex")),
                       "TST1 to E24, about 19 minutes behind schedule, last tracked over Alpha. Lands about 9:40 AM your time. Latest: closest to home, 35 miles, about 1 hour 5 minutes ago.")
        XCTAssertTrue(try XCTUnwrap(plain(try facts(now: "12:48").cardSummary(now: at("12:48"), pilotName: "Alex")))
                        .hasPrefix("TST1 to E24, about 19 minutes behind schedule, over the Atlantic, last tracked over Alpha. "))
    }

    // MARK: - The oceans

    func test_isOcean_isTrueOfTheFiveOceansOnly() {
        XCTAssertTrue(Geography.Place(name: "the Pacific", kind: .water, country: nil).isOcean)
        XCTAssertFalse(Geography.Place(name: "the Sea of Okhotsk", kind: .water, country: nil).isOcean)
        XCTAssertFalse(Geography.Place(name: "Japan", kind: .country, country: "Japan").isOcean)
    }

    func test_oceanNames_areAllInTheAppsGeography() throws {
        let waters = Set(try FactsTestData.appGeography().areas.filter { $0.kind == .water }.map(\.name))
        XCTAssertEqual(Geography.Place.oceanNames.subtracting(waters), [])
    }
}
```

- [x] **Step 2: How long the guesses are told in full.**

In `Crewluv/Services/TripMap/Facts/PlanePosition.swift`:

Replace:

```swift
nonisolated struct PlanePosition: Sendable {
    /// How far along the leg's path, in meters.
```

with:

```swift
nonisolated struct PlanePosition: Sendable {
    /// How long out of tracking range the facts tell the plane's best guesses in full: the 2 hours its own speed is
    /// trusted for, deliberately the same. Past them, where it's guessed to be can be hundreds of miles from where it
    /// is, so the facts name only an ocean under it, and hold their events until it's tracked again or the flight is
    /// over (long gap design §3).
    static let guessHorizon: TimeInterval = FlightPlan.ownSpeedAhead

    /// How far along the leg's path, in meters.
```

Replace:

```swift
    var isEstimated: Bool { unseenFor != nil }
```

with:

```swift
    var isEstimated: Bool { unseenFor != nil }

    /// Whether the real plane has been out of tracking range for longer than `guessHorizon`.
    var isPastGuessHorizon: Bool { unseenFor.map { $0 > Self.guessHorizon } ?? false }
```

- [x] **Step 3: The oceans.**

In `Crewluv/Services/TripMap/Facts/Geography.swift`:

Replace:

```swift
        var isWater: Bool { kind == .water }
    }
```

with:

```swift
        var isWater: Bool { kind == .water }

        /// One of the five oceans: past 2 hours out of tracking range, the only places wide enough to be named under
        /// a guessed plane (long gap design §3).
        var isOcean: Bool { isWater && Self.oceanNames.contains(name) }

        /// The five oceans, by the names geography.json gives them.
        static let oceanNames: Set<String> = ["the Pacific", "the Atlantic", "the Indian Ocean", "the Arctic Ocean", "the Southern Ocean"]
    }
```

- [x] **Step 4: What's below, and events held.**

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
    /// "Over Kansas", "Over Québec, near Montréal", from the flight's story, read where the plane is. A real plane
    /// that's out of sight is where the plan has it, flying on from the last place it was seen, and reads the same.
    func belowText(on leg: MapLeg, at date: Date) -> String? {
        let plane = leg.plane(at: date, isReplay: isReplay)
        guard let place = stories[leg.id]?.place(atDistance: plane.distance) else { return nil }
        return FactsWording.below(place, near: geography?.city(near: plane.coordinate))
    }
```

with:

```swift
    /// "Over Kansas", "Over Québec, near Montréal", from the flight's story, read where the plane is. A real plane
    /// that's out of sight is where the plan has it, flying on from the last place it was seen, and reads the same,
    /// but for one out of tracking range for more than 2 hours: only an ocean, with no city (long gap design §3).
    func belowText(on leg: MapLeg, at date: Date) -> String? {
        let plane = leg.plane(at: date, isReplay: isReplay)
        guard let place = placeBelow(plane, on: leg) else { return nil }
        let city = plane.isPastGuessHorizon ? nil : geography?.city(near: plane.coordinate)
        return FactsWording.below(place, near: city)
    }

    /// What's under `plane`. Past `PlanePosition.guessHorizon` out of tracking range, the guess can be hundreds of
    /// miles from the plane, and only an ocean is wide enough to be right (long gap design §3).
    private func placeBelow(_ plane: PlanePosition, on leg: MapLeg) -> Geography.Place? {
        guard let place = stories[leg.id]?.place(atDistance: plane.distance) else { return nil }
        return !plane.isPastGuessHorizon || place.isOcean ? place : nil
    }
```

Replace:

```swift
        let belowPlace = stories[leg.id]?.place(atDistance: plane.distance)
```

with:

```swift
        let belowPlace = placeBelow(plane, on: leg)
```

Replace:

```swift
    func milestones(on leg: MapLeg) -> [Milestone] {
        stories[leg.id].map { Milestone.milestones(on: leg, story: $0) } ?? []
    }
```

with:

```swift
    func milestones(on leg: MapLeg) -> [Milestone] {
        stories[leg.id].map { Milestone.milestones(on: leg, story: $0) } ?? []
    }

    /// The flight's milestones as they're told at `date`. While the flight is in the air, one guessed more than 2
    /// hours after the plane was last seen waits until it's tracked again, as it can be hundreds of miles out. Once
    /// the flight is over they're all told, as best guesses (long gap design §3). Everything up to the last place the
    /// plane was seen happened before it, so only a guess ahead can be held.
    func milestones(on leg: MapLeg, at date: Date) -> [Milestone] {
        let all = milestones(on: leg)
        guard date < leg.end, let lastSeen = leg.flight?.path.knots.last?.time else { return all }
        return all.filter { $0.time.timeIntervalSince(lastSeen) <= PlanePosition.guessHorizon }
    }
```

Replace:

```swift
        let recent = milestones(on: leg).last { $0.time <= date && date.timeIntervalSince($0.time) < Milestone.headlineDuration }
```

with:

```swift
        let recent = milestones(on: leg, at: date).last { $0.time <= date && date.timeIntervalSince($0.time) < Milestone.headlineDuration }
```

Replace:

```swift
        guard let newest = milestones(on: leg).filter({ $0.time <= date }).max(by: { $0.time < $1.time }) else { return nil }
```

with:

```swift
        guard let newest = milestones(on: leg, at: date).filter({ $0.time <= date }).max(by: { $0.time < $1.time }) else { return nil }
```

Replace:

```swift
            let events = milestones(on: leg).filter { $0.time <= date }.enumerated().reversed().map { place, milestone in
```

with:

```swift
            let events = milestones(on: leg, at: date).filter { $0.time <= date }.enumerated().reversed().map { place, milestone in
```

---

### Task 4: The docs

- [x] **Step 1:**

In `CLAUDE.md`:

Replace:

```swift
- The real plane's engine (Stage 3 spec `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`) is in `Services/TripMap/Live/`, and nothing shows it yet. `FlightPlan` is the schedule's plan the real plane is measured against, and `flown(along:)` is that plan as the plane flies it: at the plane's own speed over its cruise, once ten minutes of it have been seen. The landing estimate, the ghost and the record all fly that one. `FlightPath` is a flight's path, real once the plane has been seen in the air, and `FlightRecord` where it was at any moment. `LiveProgress` is the real plane at one moment: live, estimated or landed, its landing estimate and label, where the ghost flies, and the leg's real times. `LiveFlightSource` asks Crewlu Cloud's `partner_live` once when the screen comes to the front and every 30 seconds while a flight's window is open (`LiveWindow`). The call is `LiveFlightDoor`, apart from `PartnerDoor`, so none of the helper's 15 files needs the live plane's types
```

with:

```swift
- The real plane's engine (Stage 3 spec `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`) is in `Services/TripMap/Live/`, and nothing shows it yet. `FlightPlan` is the schedule's plan the real plane is measured against, and `flown(along:)` is that plan as the plane flies it: at the plane's own speed for 2 hours of its cruise on from where it was last seen, and the schedule's after that, once ten minutes of its cruise have been seen (best guesses after a long gap design `docs/superpowers/specs/2026-11-17-crewluve-best-guesses-after-a-long-gap-design.md`). The landing estimate, the ghost and the record all fly that one. `FlightPath` is a flight's path, real once the plane has been seen in the air, and `FlightRecord` where it was at any moment. `LiveProgress` is the real plane at one moment: live, estimated or landed, its landing estimate and label, where the ghost flies, and the leg's real times. `LiveFlightSource` asks Crewlu Cloud's `partner_live` once when the screen comes to the front and every 30 seconds while a flight's window is open (`LiveWindow`). The call is `LiveFlightDoor`, apart from `PartnerDoor`, so none of the helper's 15 files needs the live plane's types
```

Replace:

```swift
- The facts on the real path (plan `docs/superpowers/plans/2026-11-15-moving-map-stage3b3-app-facts.md`, Stage 3 spec §8, best guesses design `docs/superpowers/specs/2026-11-15-crewluve-facts-best-guesses-design.md`). `MapLeg.plane(at:isReplay:)` is where the facts have the plane (`PlanePosition`): the real one wherever the map draws it, by `FlightDrawing`'s rule, which `PlanePositionTests` holds it to. `MapLeg+Course.swift` gives a leg its path and its times, by its record or by the schedule. `MapLeg`'s own `progress(at:)` and `position(at:)` stay the schedule's. `LegStory` is made along the leg's path and read by distance, since a real path grows. Every event is told: one where nobody saw the plane (`MapLeg.isSeen(atDistance:)`) is a best guess (`Milestone.isEstimate`), and its time reads "about". A plane out of sight is read where the map flies it on, in the same plain words, with "Last tracked near …" under it ("tracked", never "seen", so a family doesn't fear the plane is missing). `LegStoryStore` makes a real path's story again as the path grows, at most once a minute, and keeps one set of sun events to a flight, which shows until the next is ready: don't key them by the leg's times again, or the sky row blinks at each new landing estimate. The plane's row is `AircraftTypeNames`' name and the registration, with the height and speed only while the plane is seen in the air now. `TripFacts.isReplay` says the moments are a replay's. adsb.lol is credited under the facts (`FactsFooter`) whenever a flight with live data shows
```

with:

```swift
- The facts on the real path (plan `docs/superpowers/plans/2026-11-15-moving-map-stage3b3-app-facts.md`, Stage 3 spec §8, best guesses design `docs/superpowers/specs/2026-11-15-crewluve-facts-best-guesses-design.md`). `MapLeg.plane(at:isReplay:)` is where the facts have the plane (`PlanePosition`): the real one wherever the map draws it, by `FlightDrawing`'s rule, which `PlanePositionTests` holds it to. `MapLeg+Course.swift` gives a leg its path and its times, by its record or by the schedule. `MapLeg`'s own `progress(at:)` and `position(at:)` stay the schedule's. `LegStory` is made along the leg's path and read by distance, since a real path grows. Every event is told: one where nobody saw the plane (`MapLeg.isSeen(atDistance:)`) is a best guess (`Milestone.isEstimate`), and its time reads "about". A plane out of sight is read where the map flies it on, in the same plain words, with "Last tracked near …" under it ("tracked", never "seen", so a family doesn't fear the plane is missing). Past 2 hours out of range (`PlanePosition.guessHorizon`), the guess can be hundreds of miles off: what's below names only an ocean, with no city (`Geography.Place.isOcean`), and an event guessed more than 2 hours after the last sighting waits until the plane is tracked again, or the flight is over (`TripFacts.milestones(on:at:)`). `LegStoryStore` makes a real path's story again as the path grows, at most once a minute, and keeps one set of sun events to a flight, which shows until the next is ready: don't key them by the leg's times again, or the sky row blinks at each new landing estimate. The plane's row is `AircraftTypeNames`' name and the registration, with the height and speed only while the plane is seen in the air now. `TripFacts.isReplay` says the moments are a replay's. adsb.lol is credited under the facts (`FactsFooter`) whenever a flight with live data shows
```

In `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`:

Replace:

```swift
- **The plan as the plane flies it** has the plane's own speed in place of the cruise speed, once that's known. Its takeoff and touchdown stay the schedule's, and so does the descent.
```

with:

```swift
- **The plan as the plane flies it** has the plane's own speed in place of the cruise speed, once that's known: for the next 2 hours of the cruise left from the last place it was seen, and the schedule's after that, made into the one speed that flies it all in the same time (amended 2026-11-17, best guesses after a long gap design §2). Its takeoff and touchdown stay the schedule's, and so does the descent.
```

In `docs/superpowers/specs/2026-11-15-crewluve-facts-best-guesses-design.md`:

Replace:

```swift
Status: approved by Todd on 15 Nov 2026, from a sketch of the facts sheet during an ocean flight, the night before a flight from Anchorage across the Pacific. It refines the Stage 3 spec (`2026-11-14-crewluve-moving-map-stage3-live-design.md`) §8, §9 and §15, as plan 3B-3 built them. Where they differ, this wins.
```

with:

```swift
Status: approved by Todd on 15 Nov 2026, from a sketch of the facts sheet during an ocean flight, the night before a flight from Anchorage across the Pacific. It refines the Stage 3 spec (`2026-11-14-crewluve-moving-map-stage3-live-design.md`) §8, §9 and §15, as plan 3B-3 built them. Where they differ, this wins. For a plane out of tracking range more than 2 hours, the best guesses after a long gap design (`2026-11-17-crewluve-best-guesses-after-a-long-gap-design.md`) refines §2 and §3.
```

In `docs/superpowers/specs/2026-11-17-crewluve-best-guesses-after-a-long-gap-design.md`:

Replace:

```swift
- **Once the plane is tracked again,** the events in the gap are told as best guesses on the straight join between the two places it was tracked, with "about" (best guesses design §3). They're in the past by then, so they take their places in the list, and the banner shows the newest event.
```

with:

```swift
- **Once the plane is tracked again,** the events in the gap are told as best guesses on the straight join between the two places it was tracked, with "about" (best guesses design §3). They're in the past by then, so they take their places in the list, and the banner shows the newest event. If it's never tracked again, they're all told as best guesses once the flight is over, so the list isn't missing them for good (added 17 Nov 2026, from the plan's review).
```

---

### Task 5: Todd's run, the commits, a look, and the website

- [x] **Step 1: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`, with 1,157 tests in the result bundle (1,143 before).

Todd's run, 17 Nov 2026: `** TEST SUCCEEDED **`, 1,157 passed, none failed or skipped.

- [ ] **Step 2: Ask to commit:** one commit for Task 2, one for Task 3, then Task 4 with this plan. Then ask whether to add a line to the 1.4 (49) release note: "Over the ocean, once the plane has been out of tracking range for a couple of hours, the landing time leans on the schedule, and the map names only the ocean until the plane is tracked again."

- [ ] **Step 3: Todd looks,** on a flight out of tracking range for more than 2 hours: what's below names only an ocean, or nothing, and no new event comes in until the plane is tracked again.

- [ ] **Step 4: The website** gets the same rules: ask Todd whether to hand them to the website's session, with the new `live-cases.json` to copy and this plan's tests to match.

## Left for later

- **Routes:** the guess still flies the shortest route on from the last sighting.
- **Tuning the 2 hours** on more flights, once Crewlu Cloud has recorded more.

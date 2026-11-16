# Moving Map Stage 3B-3 (Crewluve App, the Facts) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tell the facts about the real plane. Where Crewlu Cloud has seen the pilot's flight, the facts follow the path it really flew: what's below it, the borders it really crossed and when, the sun from where it really was, and the miles it really flew. The sheet gains a row for the plane itself, a plane that's out of sight says where it was last seen, and adsb.lol is credited.

**Architecture:**
- **One place says where the plane is.** `PlanePosition` is the plane at a moment, as the facts read it: how far along its path, and where. `MapLeg.plane(at:isReplay:)` gives the real plane wherever the map draws one, placed by the same rule as `FlightDrawing`, and the schedule's plane otherwise. A test holds the two together at every moment of the shared cases.
- **The leg answers for its path.** `MapLeg+Course.swift` gives a leg its path, the time it reaches any distance along it, whether that time is an estimate, and whether the plane was seen there. A flight with a record answers from the record. Any other answers from the schedule, exactly as before. So the facts needn't know which kind of flight they have.
- **`LegStory` is made along the leg's path,** and read by distance along it. A real path only grows at its far end, so a story stays right for the part already flown.
- **`Milestone` tells a crossing only where the plane was seen.** The times are the real plane's.
- **`SkyFacts` follows the record:** the sun's times come from where the real plane was, and when.
- **`LegStoryStore`** makes a real path's story again as the path grows, at most once a minute. It keeps one set of sun events for each flight, and shows what it has until the next is ready, so nothing blinks.
- **`TripFacts`** learns whether its moments are a replay's, and writes the headline, the rows and the card's sentence from the real plane.
- **The words** are `FactsWording`'s. `AircraftTypeNames` turns a type code into a name.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency in the app target (not in the test target), iOS 26, SwiftUI, Observation, XCTest.

**Spec:** `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md` ("the spec"), §8, §9, §11, §15 and §16.3. The facts as they were are in the Stage 2 spec, `docs/superpowers/specs/2026-11-13-crewluve-moving-map-stage2-facts-design.md`. This plan builds on plan 3B-1 (the engine) and plan 3B-2 (the map), both in `docs/superpowers/plans/`.

**This is the third of three plans for the app** (Todd's choice, 15 Nov 2026):
- **3B-1, the engine:** done, on this branch.
- **3B-2, the map:** its code is done, on this branch. Its last two tasks wait for Todd's next real flight.
- **3B-3, the facts:** this plan. It was written against the branch at `295b81f`.

**How this plan was checked.** Every code block here comes from a file that was built and run before the plan was put together. Nothing in it was typed into the plan by hand.
- **A scratch Swift package** with the app target's settings (macOS, Swift 6.4, language mode 5, the main actor by default, approachable concurrency) holds real copies of the map's model, its facts and the engine, and 42 of their test classes, with this plan's files laid over them. It's this plan's own package, made from the repo at `295b81f`. Plan 3B-2's package wasn't touched.
  - Before this plan's changes: 409 XCTest tests and 71 Swift Testing tests, all passing. That's the count the engine's last change was checked at.
  - With them: 504 XCTest tests and 71 Swift Testing tests, all passing, with no warnings. 95 of the XCTest tests are new.
  - Every test that was there before still passes unchanged, but for one this plan rewrites on purpose: the store's sun events no longer vanish for a moment when a flight's times change.
  - The new tests run the shared cases (`live-cases.json`) through the new code: at every moment the cases have of a flight between its gates, the facts' plane is where the map draws the plane, and as far along the path as the case says.
- **92 deliberate breaks** were made in the new code, one at a time. Each fails at least one test. Six slipped through at first. Five of them showed a test that wasn't sharp enough, and each now has a sharper one. The sixth changed a key that says the same thing twice over, so no test could see it: it was made into a break one can see. One more made a test hang, and that test now fails instead. One is caught and then stops the run short, because a test that was there before this plan crashes on the wrong answer.
- **The code was reviewed before the plan was put together** (`superpowers:code-reviewer`, sonnet), against the spec's §8, §9, §11 and §15. It found nothing critical, and found a flight with no live data unchanged. Three things were mended, each with a test:
  - A flight whose live data went and came back with the very same path kept the schedule's sun events until its next fix. The store now forgets a path's story was made once the flight is back on the schedule.
  - A phone clock set back could hold a new story up for as long as the clock had gone back. Only a story made in the last minute holds one up now.
  - `B77L` is one code for the 777-200LR and the 777 Freighter. It read "Boeing 777-200LR", and now reads "Boeing 777-200", which is true of both.
- **The whole app was type-checked for iOS** with `swiftc` against the iOS 27.2 simulator SDK and the app's own settings, outside Xcode: all 180 of its Swift files, with this plan's files in place. No errors and no warnings. The app as it is today passes the same check (177 files). With every task in, the app was also compiled to an object file for the simulator, without linking: again no errors and no warnings.
- **Task by task:** the package was rebuilt and its tests run, and the whole app type-checked, as they stand after each of Tasks 2 to 8. Every one passed: the XCTest count went 435, 446, 458, 473, 493, 504, 504 as each task's tests came in. So the app's code is whole after every task.
- **The plan itself was followed by a script,** on the repo's files as they are at `295b81f`: every file it says to create, and every replacement it says to make. All 31 files came out the same as the ones that were tested.
- **Not checked, because nothing outside Xcode can check it:**
  - Nothing was run on a simulator or a device. No view was seen: the plane's row, the credit, and how a long "Estimated · last seen" line fits on the card's chip.
  - The tests ran on a Mac, not on the iPhone simulator. Todd's runs in Xcode are the real ones.
  - `AircraftTypeNames`' table was written from memory of ICAO's list of type codes (Doc 8643). A code it has wrong shows a wrong name, and one it lacks shows as itself. Task 5's review should check it against a source.
  - Task 9 is how Todd checks the rest: the previews, and a real flight.

**Where this plan settles what the spec left open, or differs from it:**
- **`MapLeg`'s own questions stay the schedule's.** The spec (§11) has `progress(at:)`, `position(at:)`, `time(atFraction:)`, `heading(at:)` and `distance` ask the path and the record. Plan 3B-2 left them, and so does this one: the schedule's plane on the map and the replay's clock read them. The facts ask new questions beside them (`plane(at:isReplay:)`, `time(atDistance:)`, `pathLength` and the rest of `MapLeg+Course.swift`).
- **The facts' plane is the one the map draws.**
  - Now, it's the real plane as `LiveProgress` has it: at its last fix while it's seen, and flying the plan from there once it's an estimate.
  - In a replay, it's where the record has it.
  - Where the map shows the schedule's plane, so do the facts.
- **The story is read by distance, not by a fraction of the way.** `LegStory` keeps its fractions and gains the length of the path it was made along. A real path's length changes as it grows, so a fraction of it would slide. A distance along the part already flown doesn't.
- **"Which stretches were seen" is asked of the leg's path when a milestone is read,** not kept in the story (the spec, §11, has the story mark them). The story can be up to a minute old, and the path is always the newest.
- **A crossing is told once the plane is seen past it.** The way ahead of the last place seen isn't "seen", so while the plane is an estimate no crossing is told, and none is told across a stretch nobody saw. Halfway is always told: it's timed by the plan, as the spec has it.
- **The closest point to home** shows in the "below" row where the plane was seen, or while it's still ahead, with "about". Where nobody saw the plane pass, it's left out.
- **"About"** goes before the halfway time and the closest-to-home time while they're ahead of the real plane (§9). The sun's times keep their words: "Sunset in 25 min".
- **"Estimated · last seen near Gander" can't be written.** The app's geography has only cities of a million or more, with states, provinces, countries and seas. So it's "near Montréal" by such a city, else "over Québec", else "2 h ago" (question 1). A replay says it too, at a moment past where the plane was last seen.
- **The height the sky is seen from** is the real plane's only while it's at its cruise, from 25,000 to 60,000 ft. The spec (§8) has the last fix's height whenever the plane is in the air.
  - On the way up, the sunset ahead will be seen from the cruise, not from where the plane is now. At 8,000 ft the horizon is 1.6° higher than at 35,000 ft. Near Anchorage in November the sun takes 15 to 30 minutes to move that far, so "Sunset from the cockpit in 6 min" would become "in 25 min" a few minutes later.
  - At a cruise, the real height moves a sunset by a minute or two at most, and it's used.
- **The plane's row** shows for any flight Crewlu Cloud has a fix for.
  - Its second line, the height and the speed, shows only while the plane is seen in the air right now. An estimated plane and a replay have the first line alone.
  - The height is to the nearest 100 ft and the speed to the nearest 10 mph. A height outside 0 to 60,000 ft, or a speed outside 0 to 800 kt, is left out.
  - With no type and no registration, the height and speed lead the row. With none of them, there's no row.
- **"To go"** is the rest of the path, which for a real plane is the great circle from where it is to the arrival airport (§8). The comparison ("like driving coast to coast") is of the path's whole length.
- **The sun events are kept one set to a flight,** by its leg's id. Before, they were kept under every landing estimate. What a flight has shows until the next is ready.
- **A real path's sun events are made with its story,** so they follow the same pace: at most once a minute.
- **Until a real path's first story is ready, the route's stands in,** where the flight had one from before it was seen. That's some tens of milliseconds, once, and it's read by distance near the departure airport, where the two agree. A flight first met with a real path, as when the app opens in mid-flight, has no story for that moment, and its facts are left out as they always were.
- **The credit shows under the facts whenever a flight of the trip on screen has live data:** a fix, or a real path. "Estimated from the schedule" stays above it: the flights ahead, and the times ahead, still are. It isn't on the status screen's card, which is too small for it (Todd, 15 Nov 2026).
- **A flight that isn't live but has a real path** (back at the gate after a return) shows the schedule's plane on the map. Its facts read the same share of the way along its real path.
- **Weather on landing** is already the forecast for the live arrival: plan 3B-2 gave the leg its real times, and the forecast is asked for the leg's end.
- **No new shared cases.** The spec (§16.1) has `facts-cases.json` unchanged, and it is. The facts' plane is held to `live-cases.json`'s own `planeAlongNm` and `plane`.

**Questions for Todd, before this plan runs:**
1. **What a plane that's out of sight says.** The spec's example is "Estimated · last seen near Gander". The app can't name a town that small: it knows cities of a million or more, and states, provinces, countries and seas. This plan writes "Estimated · last seen near Montréal" by a big city, "Estimated · last seen over Québec" otherwise, and "Estimated · last seen 2 h ago" where it knows no place. Are those the words? **Answered 15 Nov 2026: yes, those words.**
2. **The credit on the card.** The spec puts "Live position: adsb.lol" in the facts' footer, which is on the full-screen map with the sheet pulled up. The real plane also shows on the status screen's card, with no credit near it. Should the card carry the line too? **Answered 15 Nov 2026: no, the card is too small. The credit is under the facts, as the spec has it.**
3. **The release note.** Task 10 drafts one for "Crewluve revisions". Which version and build does it go under? **Todd doesn't know yet (15 Nov 2026). Ask again when Task 10 runs.**
4. **When to run it.** This plan changes two files that plan 3B-2 also changed (`TripMapWording.swift` and `TripMapScreen.swift`). If Todd's flight on 16 Nov turns up a fix in one of them, this plan's replacements there are checked again first (Task 1). Run it before that flight, or after? **Answered 15 Nov 2026: before, as soon as possible.**

---

## Ground rules for whoever runs this plan

These come from Todd's standing instructions. They override the skill's defaults.

1. **Don't run `xcodebuild` build or test loops,** and don't let subagents run them. Write the code and tests. At each batch's checkpoint, Todd runs the named tests in Xcode, or with the command there.
2. **The tests are written first, and run once.** The code and its tests were already run together in the scratch package, so a first run that only fails to build would tell Todd nothing. Todd runs each batch's tests after its code is in.
3. **Never commit without Todd's go-ahead in the conversation.** Each task ends with a suggested commit message. Ask, then commit only on a yes, and only the task's own files, by path. Never `.superpowers/`.
4. **One release note, at the end** (Task 10). After Todd's OK to commit the last task, draft it for the Apple Note "Crewluve revisions" and ask before writing it.
5. **New files join their target on their own.** `Crewluv/` and `CrewluvTests/` are synchronized folders. Don't tick `CrewluveAlerts` on any new file: none of the helper's 15 files changes in this plan, and none of them needs a new one.
6. **Mark pure types `nonisolated`** (`nonisolated struct` / `nonisolated enum`). A conformance or a member in an extension is written `nonisolated extension`, or it defaults to the main actor and the tests can't call it.
7. **Copy the code as written.** It was compiled with the app's settings. If something doesn't build in Xcode, stop and say what the compiler said before changing it.
8. **A replacement is exact.** Where a step says "replace", the text to find is in the file once. If it isn't there, stop: the file has changed since this plan was written.
9. **Nothing here calls Crewlu Cloud or adsb.lol** but the app itself, run by Todd in Task 9. Every test uses made-up data. Change nothing in Crewlu Cloud's live project, and don't read it with the Supabase tools.
10. **Reviewers:** dispatch `superpowers:code-reviewer` with `model: "sonnet"`.
11. **Work on `feature/trip-map-live`,** never on `main` (Task 1). The checkout is shared with other sessions, so commit only this plan's files, and never stash, reset or switch branches.
12. **Don't change files while Todd is running tests,** and don't ask for a run until the files are final.

Test command for Todd. The OS is named because Todd's iPhone 17 Pro simulator is on iOS 26.5, and without it `xcodebuild` looks for one on the newest iOS and finds none:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:CrewluvTests/<TestClass>
```

If a run sits at "Testing started", the Mac is likely out of memory from simulators left on. Look at `uptime` and at `xcrun simctl --set testing list devices | grep Booted` before anything else, and never click Run on a command while another is still running: that stops the first.

## File map

| File | Status | Responsibility |
|---|---|---|
| `Crewluv/Services/TripMap/Facts/PlanePosition.swift` | create | where the facts have the plane at a moment |
| `Crewluv/Services/TripMap/Facts/MapLeg+Course.swift` | create | a leg's path and its times, as the facts follow them |
| `Crewluv/Services/TripMap/Facts/AircraftTypeNames.swift` | create | an aircraft's name from its type code |
| `Crewluv/Services/TripMap/Facts/LegStory.swift` | modify | made along the leg's path, and read by distance |
| `Crewluv/Services/TripMap/Facts/Milestone.swift` | modify | the real plane's times, and only the crossings it was seen to make |
| `Crewluv/Services/TripMap/Facts/SkyFacts.swift` | modify | the sun along the record, from the real plane's height at its cruise |
| `Crewluv/Services/TripMap/Facts/TripTotals.swift`, `FactsWording+Trip.swift` | modify | the miles along real paths |
| `Crewluv/Services/TripMap/TripMapWording.swift` | modify | the miles flown, and the card's sentence for a plane out of sight |
| `Crewluv/Services/TripMap/Facts/FactsWording.swift` | modify | "Estimated · last seen", the plane's row, "about", and the credit |
| `Crewluv/Services/TripMap/Facts/FactRow.swift` | modify | the plane's row's kind |
| `Crewluv/Services/TripMap/Facts/TripFacts.swift`, `TripFacts+Rows.swift` | modify | the headline, the rows and the card's sentence, from the real plane |
| `Crewluv/Services/TripMap/Facts/LegStoryStore.swift` | replace | a real path's story as it grows, and sun events that don't blink |
| `Crewluv/Views/TripMap/FactsFooter.swift`, `FactsBody.swift`, `FactsSheet.swift`, `FactsPanel.swift` | modify | the credit under the facts |
| `Crewluv/Views/TripMap/TripMapScreen.swift` | modify | tells the facts when its moments are a replay's |
| `CrewluvTests/Helpers/FactsTestData+Live.swift` | create | a made-up real plane the tests can work out by hand |
| `CrewluvTests/PlanePositionTests.swift`, `MapLegCourseTests.swift`, `LiveStoryTests.swift`, `LiveSkyFactsTests.swift`, `LiveTripTotalsTests.swift`, `AircraftTypeNamesTests.swift`, `LiveTripFactsTests.swift` | create | one class for each new piece |
| `CrewluvTests/LegStoryTests.swift`, `FactsWordingTests.swift`, `LiveWordingTests.swift`, `LegStoryStoreTests.swift` | modify | tests added, and one rewritten |
| `CLAUDE.md` | modify | the facts on the real path, in Key Components |

## Batches

Review with `superpowers:code-reviewer` (sonnet) after each batch, then Todd runs that batch's tests:

- **A, the pieces:** Tasks 2 to 5. The milestones and the sun already follow a real path after these. The headline and the rows don't yet.
- **B, the facts and their store:** Tasks 6 and 7. After Task 7 the facts are on the real path.
- **C, the views:** Task 8. The credit shows, and a replay's facts are a replay's.

Then Task 9, what Todd looks at, and Task 10.

**Between Task 3 and Task 7 the app is whole but half way.** A real path's story is made once and not again as the path grows, and the headline still reads the schedule's place. Don't hand anyone a build from in between.

---

### Task 1: Before starting

**Files:** none.

- [x] **Step 1: Check the branch and the tree.**

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

  - If the branch is `feature/trip-map-live`, stay on it. The last commit should be `295b81f` or later.
  - Anything else: stop and ask Todd.
  - Other changed files that aren't this plan's are left alone. Another session may share this checkout.

- [x] **Step 2: See what has changed since this plan was written.**

```bash
git -C /Users/toddanderson/Dev/Crewluv diff --stat 295b81f -- Crewluv/Services/TripMap Crewluv/Views/TripMap CrewluvTests
```

  - Nothing listed: go on.
  - A file this plan changes is listed (see the file map): read what changed. Each replacement here is exact, so one that no longer fits will stop its step. Tell Todd before going on.
  - If plan 3B-2's Task 10 or 11 is still open, say so to Todd: this plan and that session would be changing the same checkout.

- [x] **Step 3: Check the questions.** Todd's answers to the four questions above may change a task.
  - Question 1 is answered: the words stand as they're written here.
  - Question 2 is answered: the credit goes under the facts, and not on the card.
  - Question 3 is still open: ask for the version and build when Task 10 reaches the release note.
  - Question 4 is answered: it runs before the flight of 16 Nov. So plan 3B-2's last two tasks are still open while this one runs: its session is told what goes into the checkout.

- [x] **Step 4: Read the code this plan builds on.** `Crewluv/Services/TripMap/Facts/` (above all `LegStory.swift`, `Milestone.swift`, `TripFacts.swift` and `LegStoryStore.swift`), and in `Crewluv/Services/TripMap/Live/`: `FlightPath.swift`, `FlightRecord.swift`, `LiveProgress.swift` and `MapFlight.swift`. Then `FlightDrawing.swift`, whose rule for where the real plane is this plan repeats for the facts.

---

### Task 2: Where the plane is, and the leg as the facts follow it

Two new files, and nothing reads them yet.
- `PlanePosition` is the plane at a moment: how far along its path, where, and whether it's an estimate.
- `MapLeg+Course.swift` gives a leg its path and its times. A flight with a record answers from it. Any other answers from the schedule.

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/PlanePosition.swift`
- Create: `Crewluv/Services/TripMap/Facts/MapLeg+Course.swift`
- Create: `CrewluvTests/Helpers/FactsTestData+Live.swift`
- Create: `CrewluvTests/PlanePositionTests.swift`
- Create: `CrewluvTests/MapLegCourseTests.swift`

- [x] **Step 1: A made-up real plane for the tests.** The facts' tests already have a flight along the equator, where a fraction of the way is a fraction of the longitude. This gives it a real plane that flies a degree every 8 minutes, so every expected value can be worked out by hand. It can leave the great circle, and it can go unseen for a stretch.

Create `CrewluvTests/Helpers/FactsTestData+Live.swift`:

```swift
//
//  FactsTestData+Live.swift
//  CrewluvTests
//
//  A made-up real plane for the equator flight (Stage 3 spec §8), so the facts on a real path can be worked out by
//  hand. The schedule has the flight in the air from 10:15 to 13:15 UTC, and its plan cruises at about 420 kt. The
//  real plane leaves 0° E at 10:15 too, and flies a degree of longitude every 8 minutes (450 kt): it's at 5° E at
//  10:55, 10° E at 11:35, 14° E at 12:07 and 20° E at 12:55. It's seen every 2 minutes from 10:17.
//

import CoreLocation
import Foundation
@testable import Crewluv

extension FactsTestData {

    /// When the real plane leaves the ground: 10:15 UTC.
    static let liveTakeoff = equinox.addingTimeInterval(15 * 60)

    /// The real plane takes this long for each degree of longitude.
    static let liveSecondsADegree: TimeInterval = 480

    /// One degree along the equator, in meters and in miles.
    static let metersADegree = GreatCircle.earthRadius * .pi / 180
    static let milesADegree = metersADegree / GreatCircle.metersPerMile

    static func liveLongitude(at date: Date) -> Double {
        date.timeIntervalSince(liveTakeoff) / liveSecondsADegree
    }

    static func liveTime(atLongitude degrees: Double) -> Date {
        liveTakeoff.addingTimeInterval(degrees * liveSecondsADegree)
    }

    /// The real plane's live data as Crewlu Cloud has it once it was last seen at `seenUntil`.
    /// - Parameters:
    ///   - unseen: longitudes between which nobody saw it.
    ///   - landedAt: when it was seen on the ground at the arrival airport, for a flight that has landed.
    ///   - latitude: how far north of the equator it flies at a longitude, for a path that leaves the great circle.
    static func equatorLive(
        seenUntil: Date, unseen: ClosedRange<Double>? = nil, landedAt: Date? = nil, altitudeFeet: Double? = 36_000,
        typeCode: String? = "B763", registration: String? = "N370UP", latitude: (Double) -> Double = { _ in 0 }
    ) -> LiveFlight {
        var trail: [LiveFlight.TrailPoint] = []
        var time = liveTakeoff.addingTimeInterval(120)
        while time <= seenUntil {
            let longitude = liveLongitude(at: time)
            let isSeen = unseen.map { !($0.lowerBound < longitude && longitude < $0.upperBound) } ?? true
            if isSeen {
                trail.append(LiveFlight.TrailPoint(time: time, latitude: latitude(longitude), longitude: longitude,
                                                   altitudeFeet: altitudeFeet))
            }
            time = time.addingTimeInterval(120)
        }
        let longitude = liveLongitude(at: seenUntil)
        let fix = landedAt.map {
            LiveFlight.Fix(latitude: 0, longitude: 20, altitudeFeet: nil, groundSpeedKnots: 30, trackDegrees: nil,
                           isOnGround: true, registration: registration, typeCode: typeCode, seenAt: $0)
        } ?? LiveFlight.Fix(latitude: latitude(longitude), longitude: longitude, altitudeFeet: altitudeFeet,
                            groundSpeedKnots: 450, trackDegrees: 90, isOnGround: false, registration: registration,
                            typeCode: typeCode, seenAt: seenUntil)
        return LiveFlight(legID: "eq", callsign: "TST1", state: landedAt == nil ? .airborne : .landed, fix: fix,
                          landedAt: landedAt, trail: trail)
    }

    /// The equator flight with `live` for its real plane, as the status screen's model hands it on at `now`:
    /// between the real plane's times.
    static func equatorLiveLeg(_ live: LiveFlight?, at now: Date, to east: Double = 20, id: String = "eq",
                               clockOffset: TimeInterval = 0) throws -> MapLeg {
        let scheduled = equatorFlight(from: 0, to: east, id: id)
        let flight = MapFlight(departure: scheduled.start, arrival: scheduled.end, from: scheduled.origin.coordinate,
                               to: scheduled.destination.coordinate, live: live, clockOffset: clockOffset)
        guard let flight else { throw TripMapFixtures.MissingPlan(name: "the equator flight") }
        let progress = flight.progress(at: now)
        return MapLeg(id: scheduled.id, kind: .flight, origin: scheduled.origin, destination: scheduled.destination,
                      start: progress.start, end: progress.end, flightNumber: scheduled.flightNumber, flight: flight)
    }

    /// Home, half a degree north of 14° E: the equator flight passes 35 mi from it.
    static let homeByTheEquator = mark("HOME", latitude: 0.5, longitude: 14)

    /// A path that leaves the great circle: north from 6° E to 2° N by 7° E, along it to 9° E, and back to the
    /// equator by 10° E.
    static func dogLeg(_ longitude: Double) -> Double {
        max(0, min(longitude - 6, 10 - longitude, 1)) * 2
    }
}
```

- [x] **Step 2: The tests.**

Create `CrewluvTests/PlanePositionTests.swift`:

```swift
//
//  PlanePositionTests.swift
//  CrewluvTests
//
//  Where the facts have a flight's plane (Stage 3 spec §8): wherever the map draws it, for every moment of the
//  shared cases in Fixtures/TripMap/live-cases.json, and where the record has it in a replay.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class PlanePositionTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile

    private func assertSame(_ place: CLLocationCoordinate2D?, _ expected: CLLocationCoordinate2D?, _ name: String,
                            accuracy: Double = 1e-9, file: StaticString = #filePath, line: UInt = #line) {
        guard let place, let expected else {
            XCTFail("a place is missing: \(name)", file: file, line: line)
            return
        }
        XCTAssertEqual(place.latitude, expected.latitude, accuracy: accuracy, name, file: file, line: line)
        XCTAssertEqual(place.longitude, expected.longitude, accuracy: accuracy, name, file: file, line: line)
    }

    // MARK: - Now

    func test_now_everySharedMoment_isWhereTheMapDrawsThePlane() throws {
        let cases = try TripMapFixtures.liveCases()
        var real = 0
        var scheduled = 0
        for flightCase in cases.flights {
            for moment in flightCase.moments {
                let name = "\(flightCase.name) at \(moment.at)"
                let leg = try cases.mapLeg(flightCase, at: moment)
                guard leg.isMoving(at: moment.at) else { continue }
                let drawing = FlightDrawing(leg: leg, at: moment.at, isReplay: false)
                let plane = leg.plane(at: moment.at, isReplay: false)
                if let drawn = drawing.realPlane {
                    assertSame(plane.coordinate, drawn.coordinate, name)
                    XCTAssertEqual(plane.isEstimated, drawn.isEstimated, name)
                    XCTAssertEqual(plane.isEstimated, moment.phase == "estimated", name)
                    XCTAssertEqual(plane.isSeenInAir, moment.phase == "inAir", name)
                    // A plane on the ground somewhere else isn't on the path: it counts as far as it was last seen.
                    XCTAssertEqual(plane.distance / nauticalMile, moment.planeAlongNm ?? flightCase.path.flownNm, accuracy: 0.01, name)
                    real += 1
                } else {
                    assertSame(plane.coordinate, drawing.plane?.coordinate, name)
                    XCTAssertEqual(plane.distance, leg.progress(at: moment.at) * leg.pathLength, accuracy: 0.001, name)
                    XCTAssertFalse(plane.isEstimated, name)
                    XCTAssertFalse(plane.isSeenInAir, name)
                    scheduled += 1
                }
            }
        }
        XCTAssertGreaterThan(real, 20, "the cases' real planes")
        XCTAssertGreaterThan(scheduled, 2, "and the moments with the schedule's plane alone")
    }

    func test_now_anEstimatedPlane_saysHowLongAgoItWasSeen_byCrewluCloudsClock() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let seenAt = try XCTUnwrap(flightCase.flight?.fix?.seenAt)

        let estimated = try cases.moment("13T12:45:00", of: flightCase)
        let plane = try cases.mapFlight(flightCase).plane(at: estimated.at, isReplay: false)
        XCTAssertEqual(try XCTUnwrap(plane?.unseenFor), estimated.at.timeIntervalSince(seenAt), accuracy: 0.001)

        // This phone's clock is ten minutes slow: by Crewlu Cloud's the plane was last seen ten minutes longer ago.
        let inAir = try cases.moment("13T12:41:50", of: flightCase)
        let slow = try cases.mapFlight(flightCase, clockOffset: 600).plane(at: inAir.at, isReplay: false)
        XCTAssertEqual(try XCTUnwrap(slow?.unseenFor), inAir.at.timeIntervalSince(seenAt) + 600, accuracy: 0.001)
        XCTAssertEqual(slow?.isSeenInAir, false)
    }

    func test_now_aPlaneSeenInTheAir_isNoEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let plane = try XCTUnwrap(try cases.mapFlight(flightCase).plane(at: moment.at, isReplay: false))
        XCTAssertNil(plane.unseenFor)
        XCTAssertTrue(plane.isSeenInAir)
    }

    func test_now_onTheGroundSomewhereElse_countsAsFarAsItWasLastSeenFlying() throws {
        // It was seen flying as far as 6.75° E, and came down at a field off its path.
        let flown = FactsTestData.equatorLive(seenUntil: FactsTestData.date("2026-03-20T11:09:00Z"))
        let down = FactsTestData.date("2026-03-20T11:30:00Z")
        let fix = LiveFlight.Fix(latitude: 1.5, longitude: 7, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: nil, typeCode: nil, seenAt: down)
        let live = LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: flown.trail)
        let leg = try FactsTestData.equatorLiveLeg(live, at: down)

        let plane = leg.plane(at: down, isReplay: false)
        assertSame(plane.coordinate, fix.coordinate, "where it is")
        XCTAssertEqual(plane.distance, leg.path.flownLength, accuracy: 0.001)
        XCTAssertEqual(plane.distance, 6.75 * FactsTestData.metersADegree, accuracy: 1_000)
        XCTAssertFalse(plane.isEstimated)
        XCTAssertFalse(plane.isSeenInAir)
    }

    func test_now_aFlightThatIsntLive_withARealPath_isTheSchedulesPlane_thatShareOfTheWayAlongIt() throws {
        // It flew north of the great circle as far as 8° E, went back, and has sat at the gate unseen for ten minutes.
        let flown = FactsTestData.equatorLive(seenUntil: FactsTestData.liveTime(atLongitude: 8), latitude: FactsTestData.dogLeg)
        let now = FactsTestData.date("2026-03-20T12:00:00Z")
        let fix = LiveFlight.Fix(latitude: 0, longitude: 0, altitudeFeet: nil, groundSpeedKnots: 0, trackDegrees: nil,
                                 isOnGround: true, registration: nil, typeCode: nil, seenAt: now.addingTimeInterval(-600))
        let live = LiveFlight(legID: "eq", callsign: "TST1", state: .ground, fix: fix, landedAt: nil, trail: flown.trail)
        let leg = try FactsTestData.equatorLiveLeg(live, at: now)
        XCTAssertNil(leg.flight?.plane(at: now, isReplay: false), "no real plane shows")
        XCTAssertGreaterThan(leg.pathLength, leg.distance)

        let plane = leg.plane(at: now, isReplay: false)
        assertSame(plane.coordinate, FlightDrawing(leg: leg, at: now, isReplay: false).plane?.coordinate, "where the map draws the schedule's plane")
        XCTAssertEqual(plane.distance, leg.progress(at: now) * leg.pathLength, accuracy: 0.001)
        XCTAssertFalse(plane.isEstimated)
    }

    // MARK: - A replay

    func test_replay_everyPlaceOfTheSharedRecords_isWhereTheRecordHasIt() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights {
            guard let record = flightCase.record else { continue }
            let flight = try cases.mapFlight(flightCase)
            for place in record.places {
                let name = "\(flightCase.name) at \(place.at)"
                let plane = try XCTUnwrap(flight.plane(at: place.at, isReplay: true), name)
                XCTAssertEqual(plane.distance / nauticalMile, place.alongNm, accuracy: 0.01, name)
                assertSame(plane.coordinate, CLLocationCoordinate2D(latitude: place.point[0], longitude: place.point[1]), name, accuracy: 0.0001)
                XCTAssertFalse(plane.isSeenInAir, "its height and speed are for now only: \(name)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 20, "the cases' places")
    }

    func test_replay_pastWhereItWasLastSeen_isAnEstimate_andSaysForHowLong() throws {
        let cases = try TripMapFixtures.liveCases()
        let flight = try cases.mapFlight(try cases.flight(named: "ahead, in the air"))
        let lastSeen = try XCTUnwrap(flight.path.knots.last).time

        let before = try XCTUnwrap(flight.plane(at: lastSeen.addingTimeInterval(-300), isReplay: true))
        XCTAssertNil(before.unseenFor, "where it was seen, the replay shows it as it was")

        let after = try XCTUnwrap(flight.plane(at: lastSeen.addingTimeInterval(1200), isReplay: true))
        XCTAssertEqual(try XCTUnwrap(after.unseenFor), 1200, accuracy: 0.001)
        XCTAssertGreaterThan(after.distance, flight.path.flownLength)
    }

    func test_replay_aFlightThatLanded_isNeverAnEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flight = try cases.mapFlight(try cases.flight(named: "landed, seen all the way"))
        let touchdown = try XCTUnwrap(flight.record).touchdown
        let plane = try XCTUnwrap(flight.plane(at: touchdown.addingTimeInterval(3600), isReplay: true))
        XCTAssertNil(plane.unseenFor)
        XCTAssertEqual(plane.distance, flight.path.length, accuracy: 0.001)
    }

    func test_replay_withNoRecord_isTheSchedulesPlane() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "no live data")
        XCTAssertNil(try cases.mapFlight(flightCase).plane(at: flightCase.departure.addingTimeInterval(3600), isReplay: true))

        let leg = try cases.mapLeg(flightCase, at: try XCTUnwrap(flightCase.moments.first))
        let at = flightCase.departure.addingTimeInterval(3600)
        let plane = leg.plane(at: at, isReplay: true)
        XCTAssertEqual(plane.distance, leg.progress(at: at) * leg.distance, accuracy: 0.001)
        assertSame(plane.coordinate, leg.position(at: at), "the schedule's plane")
    }

    // MARK: - A leg made by hand

    func test_aLegWithNoFlight_isTheSchedulesPlane() {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let at = FactsTestData.date("2026-03-20T11:45:00Z")
        let plane = leg.plane(at: at, isReplay: false)
        XCTAssertEqual(plane.distance, leg.distance / 2, accuracy: 0.001, "halfway through its time in the air")
        assertSame(plane.coordinate, CLLocationCoordinate2D(latitude: 0, longitude: 10), "10° E", accuracy: 1e-6)
    }
}
```

Create `CrewluvTests/MapLegCourseTests.swift`:

```swift
//
//  MapLegCourseTests.swift
//  CrewluvTests
//
//  A leg as the facts follow it (Stage 3 spec §8): its path, and its times by its record or by the schedule.
//  The made-up real plane is `FactsTestData`'s: a degree of longitude every 8 minutes from 10:15 UTC.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class MapLegCourseTests: XCTestCase {

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private let schedule = FactsTestData.equatorFlight(from: 0, to: 20)

    /// The real plane, last seen at `seenUntil`, with the leg as it's handed on then.
    private func live(seenUntil: String, unseen: ClosedRange<Double>? = nil) throws -> MapLeg {
        try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at(seenUntil), unseen: unseen), at: at(seenUntil))
    }

    private func meters(_ degrees: Double) -> Double { degrees * FactsTestData.metersADegree }

    // MARK: - The path

    func test_path_withNoFlight_isTheGreatCircle() {
        XCTAssertFalse(schedule.path.isReal)
        XCTAssertEqual(schedule.path.length, schedule.distance)
        XCTAssertEqual(schedule.pathLength, schedule.distance)
    }

    func test_pathLength_ofARealPathThatLeavesTheGreatCircle_isLonger() throws {
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)
        XCTAssertTrue(leg.path.isReal)
        // Each ramp is the long side of a 1° by 2° triangle: about 1.24° more than the degree it covers.
        XCTAssertEqual(leg.pathLength - leg.distance, meters(2 * (5.0.squareRoot() - 1)), accuracy: meters(0.05))
    }

    func test_kindAtDistance_readsThePathsStretches() throws {
        let leg = try live(seenUntil: "11:10", unseen: 4...6.5)
        XCTAssertEqual(leg.path.kind(atDistance: meters(3)), .seen)
        XCTAssertEqual(leg.path.kind(atDistance: meters(5)), .unseen, "nobody saw it from 4° E to 6.5° E")
        XCTAssertEqual(leg.path.kind(atDistance: meters(6.7)), .seen)
        XCTAssertEqual(leg.path.kind(atDistance: meters(15)), .planned, "the way ahead")
        XCTAssertEqual(schedule.path.kind(atDistance: meters(5)), .planned)
    }

    func test_hasLiveData_onceCrewluCloudHasSeenTheFlight() throws {
        XCTAssertFalse(schedule.hasLiveData, "a leg made by hand")
        XCTAssertFalse(try FactsTestData.equatorLiveLeg(nil, at: at("11:10")).hasLiveData, "no answer for the leg")
        let waiting = LiveFlight(legID: "eq", callsign: "TST1", state: .waiting, fix: nil, landedAt: nil, trail: [])
        XCTAssertFalse(try FactsTestData.equatorLiveLeg(waiting, at: at("11:10")).hasLiveData, "watched, and never seen")
        XCTAssertTrue(try live(seenUntil: "11:10").hasLiveData)
    }

    // MARK: - Its times

    func test_timeAtDistance_withARecord_isTheRecords_forEverySharedCase() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights {
            guard let record = flightCase.record, let moment = flightCase.moments.first else { continue }
            let leg = try cases.mapLeg(flightCase, at: moment)
            for time in record.times {
                let found = try XCTUnwrap(leg.time(atDistance: time.alongNm * TripMapFixtures.nauticalMile), flightCase.name)
                XCTAssertEqual(found.timeIntervalSince1970, time.at.timeIntervalSince1970, accuracy: 0.5, "\(flightCase.name) at \(time.alongNm) nm")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 15, "the cases' times")
    }

    func test_timeAtDistance_onTheSchedule_isThatShareOfItsTimeInTheAir() {
        XCTAssertEqual(schedule.time(atDistance: schedule.distance / 4), at("11:00"), "a quarter of three hours after 10:15")
        XCTAssertEqual(schedule.time(atDistance: 0), at("10:15"))
        XCTAssertEqual(schedule.time(atDistance: schedule.distance), at("13:15"))
    }

    func test_timeAtDistance_ofALegThatGoesNowhere_isItsTakeoff() {
        let nowhere = FactsTestData.equatorFlight(from: 0, to: 0)
        XCTAssertEqual(nowhere.pathLength, 0)
        XCTAssertEqual(nowhere.time(atDistance: 0), at("10:15"))
        XCTAssertEqual(nowhere.halfwayTime, at("11:45"), "halfway through its time in the air, as before")
    }

    func test_timeAtDistance_withARecord_isWhenTheRealPlaneWasThere() throws {
        let leg = try live(seenUntil: "11:10")
        XCTAssertEqual(try XCTUnwrap(leg.time(atDistance: meters(5))).timeIntervalSince1970, at("10:55").timeIntervalSince1970, accuracy: 2)
        XCTAssertEqual(schedule.time(atDistance: meters(5)), at("11:00"), "the schedule's plane is there five minutes later")
    }

    func test_halfwayTime_onTheSchedule_isTheMiddleOfItsTimeInTheAir() {
        XCTAssertEqual(schedule.halfwayTime, at("11:45"))
    }

    func test_halfwayTime_withARecord_isWhenTheRealPlaneIsHalfwayAlongItsPath() throws {
        // Seen as far as 6.875° E. At its own 450 kt it's at 10° E 25 minutes later.
        let leg = try live(seenUntil: "11:10")
        XCTAssertEqual(try XCTUnwrap(leg.halfwayTime).timeIntervalSince1970, at("11:35").timeIntervalSince1970, accuracy: 30)
    }

    func test_isTimeEstimated_aheadOfWhereTheRealPlaneWasLastSeen() throws {
        let leg = try live(seenUntil: "11:10")
        XCTAssertFalse(leg.isTimeEstimated(atDistance: meters(5)), "it was seen there")
        XCTAssertTrue(leg.isTimeEstimated(atDistance: meters(10)), "it isn't there yet")
        XCTAssertFalse(schedule.isTimeEstimated(atDistance: meters(10)), "the schedule's times aren't the real plane's estimate")

        let landedAt = FactsTestData.liveTime(atLongitude: 20)
        let landed = try FactsTestData.equatorLiveLeg(
            FactsTestData.equatorLive(seenUntil: FactsTestData.liveTime(atLongitude: 19.75), landedAt: landedAt), at: landedAt)
        XCTAssertFalse(landed.isTimeEstimated(atDistance: meters(19.9)), "it has landed: every time is real")
    }

    func test_isSeen_onlyWhereTheRealPlaneWasSeen() throws {
        let leg = try live(seenUntil: "11:10", unseen: 4...6.5)
        XCTAssertTrue(leg.isSeen(atDistance: meters(3)))
        XCTAssertFalse(leg.isSeen(atDistance: meters(5)), "nobody saw it cross 5° E")
        XCTAssertTrue(leg.isSeen(atDistance: meters(6.7)))
        XCTAssertFalse(leg.isSeen(atDistance: meters(15)), "it isn't there yet")
        XCTAssertTrue(schedule.isSeen(atDistance: meters(5)), "the schedule tells every crossing")
    }

    // MARK: - The sky's questions

    func test_airborne_onTheSchedule_isItsTimeInTheAir() {
        XCTAssertEqual(schedule.airborne, DateInterval(start: at("10:15"), end: at("13:15")))
    }

    func test_airborne_withARecord_isFromLeavingTheAirportToItsTouchdown() throws {
        let leg = try live(seenUntil: "11:10")
        let record = try XCTUnwrap(leg.flight?.record)
        let airborne = try XCTUnwrap(leg.airborne)
        // The first place it was seen is 15 nm out at 10:17. At the plan's 420 kt it left about two minutes before.
        XCTAssertEqual(airborne.start.timeIntervalSince1970, at("10:15").timeIntervalSince1970, accuracy: 30)
        XCTAssertEqual(airborne.end, record.touchdown)
        XCTAssertLessThan(airborne.end, at("13:15"), "it's ahead of the schedule")
    }

    func test_coursePosition_keepsMovingAfterThePlaneWasLastSeen() throws {
        let leg = try live(seenUntil: "11:10")
        XCTAssertEqual(leg.coursePosition(at: at("11:10")).longitude, 6.875, accuracy: 0.001)
        XCTAssertEqual(leg.coursePosition(at: at("11:12")).longitude, 7.125, accuracy: 0.01, "two more minutes at 450 kt")
        XCTAssertEqual(leg.plane(at: at("11:12"), isReplay: false).coordinate.longitude, 6.875, accuracy: 0.001,
                       "while the plane the map draws waits where it was last seen")
    }

    func test_coursePosition_onTheSchedule_isTheSchedulesPlane() {
        XCTAssertEqual(schedule.coursePosition(at: at("11:45")).longitude, 10, accuracy: 1e-6)
    }
}
```

- [x] **Step 3: Where the plane is.** `MapFlight.plane(at:isReplay:)` repeats `FlightDrawing`'s rule for the real plane, and the first test above holds the two together at every moment of the shared cases.

Create `Crewluv/Services/TripMap/Facts/PlanePosition.swift`:

```swift
//
//  PlanePosition.swift
//  CrewLuve
//
//  Where the facts have a flight's plane at a moment (Stage 3 spec §8): the real plane wherever the map draws one,
//  placed as `FlightDrawing` places it so the two agree, and otherwise the schedule's.
//

import CoreLocation

nonisolated struct PlanePosition: Sendable {
    /// How far along the leg's path, in meters.
    let distance: Double
    let coordinate: CLLocationCoordinate2D
    /// Set while the real plane is an estimate: how long ago it was last seen. It's where the plan has it by now.
    let unseenFor: TimeInterval?
    /// The real plane, seen in the air just now. Never in a replay: what only the newest fix tells, its height and
    /// its speed, is for now only.
    let isSeenInAir: Bool

    var isEstimated: Bool { unseenFor != nil }
}

nonisolated extension MapFlight {

    /// The real plane at `date`, or nil where the schedule's plane shows instead: the flight isn't live now, or has
    /// no record to replay.
    /// - Parameters:
    ///   - date: now by this device's clock, or a moment of the replay.
    ///   - isReplay: `date` is a moment of the replay, not now. The plane is then where its record has it.
    func plane(at date: Date, isReplay: Bool) -> PlanePosition? {
        if isReplay {
            guard let record, let lastSeen = path.knots.last else { return nil }
            let distance = record.distance(at: date)
            // Past the last place it was seen, the record flies the plan: an estimate.
            let isEstimated = !path.hasLanded && distance > path.flownLength
            return PlanePosition(distance: distance, coordinate: path.point(atDistance: distance),
                                 unseenFor: isEstimated ? max(0, date.timeIntervalSince(lastSeen.time)) : nil,
                                 isSeenInAir: false)
        }
        let progress = progress(at: date)
        guard let place = progress.plane else { return nil }
        // Crewlu Cloud's clock ages the fix, as it decides the phase.
        let unseenFor = progress.phase == .estimated
            ? live?.fix.map { max(0, date.addingTimeInterval(clockOffset).timeIntervalSince($0.seenAt)) }
            : nil
        // A plane on the ground somewhere else isn't on the path: it counts as far as it was last seen flying.
        return PlanePosition(distance: progress.planeDistance ?? path.flownLength, coordinate: place,
                             unseenFor: unseenFor, isSeenInAir: progress.phase == .inAir)
    }
}

nonisolated extension MapLeg {

    /// Where the plane is at `date`: the real one where the map draws it, and otherwise the schedule's, where the
    /// map draws that. The schedule's plane counts as far along the leg's path as the schedule has it along the
    /// great circle, which without a real path is the same thing.
    func plane(at date: Date, isReplay: Bool) -> PlanePosition {
        if let real = flight?.plane(at: date, isReplay: isReplay) { return real }
        let fraction = progress(at: date)
        return PlanePosition(distance: fraction * pathLength, coordinate: position(atFraction: fraction),
                             unseenFor: nil, isSeenInAir: false)
    }
}
```

- [x] **Step 4: The leg as the facts follow it.**

Create `Crewluv/Services/TripMap/Facts/MapLeg+Course.swift`:

```swift
//
//  MapLeg+Course.swift
//  CrewLuve
//
//  A leg as the facts follow it (Stage 3 spec §8): along its real path at the times of its record, once the plane
//  has been seen in the air, and otherwise along the great circle on the schedule. The facts ask these, so they
//  needn't know which kind of flight it is. `MapLeg`'s own `progress(at:)` and `position(at:)` stay the schedule's.
//

import CoreLocation

nonisolated extension MapLeg {

    // MARK: - The path

    /// The path the facts follow: the flight's own, real once the plane has been seen in the air, else the great
    /// circle between the airports.
    var path: FlightPath {
        flight?.path ?? FlightPath(from: origin.coordinate, to: destination.coordinate)
    }

    /// The path's whole length in meters, flown and ahead. Without a real path, the great-circle distance.
    var pathLength: Double {
        flight?.path.length ?? distance
    }

    /// Whether Crewlu Cloud has seen this flight: it knows a place it was last seen, or the path it flew.
    var hasLiveData: Bool {
        guard let flight else { return false }
        return flight.live?.fix != nil || flight.path.isReal
    }

    // MARK: - Its times

    /// When the plane was, or is expected to be, `distance` meters along its path: by its record, and without one
    /// by the schedule. Nil for a flight with no time in the air.
    func time(atDistance distance: Double) -> Date? {
        if let record = flight?.record { return record.time(atDistance: distance) }
        let length = pathLength
        return time(atFraction: length > 0 ? distance / length : 0)
    }

    /// When the plane is halfway along its path, flown and ahead: by its record, else the middle of the schedule's
    /// time in the air.
    var halfwayTime: Date? {
        if let record = flight?.record { return record.time(atDistance: record.path.length / 2) }
        return time(atFraction: 0.5)
    }

    /// Whether the time the plane reaches `distance` meters along its path is an estimate, which the words mark
    /// with "about" (spec §9): it's ahead of where the real plane was last seen.
    func isTimeEstimated(atDistance distance: Double) -> Bool {
        guard let path = flight?.path, path.isReal else { return false }
        return !path.hasLanded && distance > path.flownLength
    }

    /// Whether the plane was seen `distance` meters along its path, so a crossing there can be told. Where nobody
    /// saw it the straight join is a guess, and a crossing is a claim. A flight with no real path flies the
    /// schedule, which tells every one.
    func isSeen(atDistance distance: Double) -> Bool {
        guard let path = flight?.path, path.isReal else { return true }
        return path.kind(atDistance: distance) == .seen
    }

    // MARK: - The sky's questions

    /// When the plane is in the air. With a record, from leaving the departure airport to its touchdown, real or
    /// estimated. Otherwise the schedule's time in the air. Nil for a flight that arrives no later than it leaves.
    var airborne: DateInterval? {
        guard let record = flight?.record else { return FlightProgress.airborneWindow(departure: start, arrival: end) }
        let takeoff = record.time(atDistance: 0)
        return record.touchdown > takeoff ? DateInterval(start: takeoff, end: record.touchdown) : nil
    }

    /// Where the plane was, or is expected to be, at `date`: by its record, else by the schedule. Unlike
    /// `plane(at:isReplay:)` it keeps moving between the places the real plane is seen, which the sun's times and
    /// the plane's speed across the sky need.
    func coursePosition(at date: Date) -> CLLocationCoordinate2D {
        flight?.record?.position(at: date) ?? position(at: date)
    }
}

nonisolated extension FlightPath {

    /// The kind of the path `distance` meters along it: the stretch `point(atDistance:)` reads there.
    func kind(atDistance distance: Double) -> Kind {
        let far = min(max(distance, 0), length)
        return stretches.first { far <= $0.startDistance + $0.length }?.kind ?? .planned
    }
}
```

- [ ] **Step 5: Ask to commit,** after batch A's checkpoint (Task 5). Suggested message: `feat(crewluv): where the facts have the plane, the real one wherever the map draws it, and a leg's path and times as the facts follow them (Stage 3 spec §8)`.

---

### Task 3: The story along the path

`LegStory` is made along the leg's path, and gains the path's length so it can be read by distance. `Milestone` takes its times from the leg, and tells a crossing, or the closest point to home, only where the plane was seen.

A flight with no live data comes out as before: its path is the great circle, and its times are the schedule's. Every test that was there still passes unchanged.

**Files:**
- Modify: `Crewluv/Services/TripMap/Facts/LegStory.swift`
- Modify: `Crewluv/Services/TripMap/Facts/Milestone.swift`
- Modify: `CrewluvTests/LegStoryTests.swift`
- Create: `CrewluvTests/LiveStoryTests.swift`

- [x] **Step 1: The tests.**

In `CrewluvTests/LegStoryTests.swift`:

Replace:

```swift
    func test_closestToHome_besideTheRoute_isWhereItPasses() throws {
```

with:

```swift
    func test_placeAtDistance_readsTheStretchesByMeters() {
        let equatorStory = story()
        XCTAssertEqual(equatorStory.length, GreatCircle.distance(from: at(0, 0), to: at(0, 20)))
        XCTAssertEqual(equatorStory.place(atDistance: 0.1 * equatorStory.length)?.name, "Alpha")
        XCTAssertEqual(equatorStory.place(atDistance: 0.46 * equatorStory.length)?.name, "Bravo")
        XCTAssertEqual(equatorStory.place(atDistance: 0.9 * equatorStory.length)?.name, "the Test Sea")
        XCTAssertEqual(equatorStory.place(atDistance: 2 * equatorStory.length)?.name, "the Test Sea", "past the arrival airport")
    }

    func test_closestToHome_besideTheRoute_isWhereItPasses() throws {
```

Create `CrewluvTests/LiveStoryTests.swift`:

```swift
//
//  LiveStoryTests.swift
//  CrewluvTests
//
//  A flight's story and milestones along its real path (Stage 3 spec §8, §16.3): the places under the path it
//  really flew, the real plane's times, and nothing told of a stretch nobody saw. The made-up real plane is
//  `FactsTestData`'s: a degree of longitude every 8 minutes from 10:15 UTC.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveStoryTests: XCTestCase {

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private let home = FactsTestData.homeByTheEquator

    /// The real plane last seen at `seenUntil`, as the leg is handed on then.
    private func leg(seenUntil: String, unseen: ClosedRange<Double>? = nil) throws -> MapLeg {
        try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at(seenUntil), unseen: unseen), at: at(seenUntil))
    }

    private func milestones(_ leg: MapLeg, home: AirportMark? = nil) -> [Milestone] {
        Milestone.milestones(on: leg, story: LegStory(leg: leg, geography: FactsTestData.equator, home: home))
    }

    private func assertMilestone(_ milestone: Milestone, _ kind: Milestone.Kind, at iso: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(milestone.kind, kind, file: file, line: line)
        XCTAssertEqual(milestone.time.timeIntervalSince1970, FactsTestData.date(iso).timeIntervalSince1970, accuracy: 5, file: file, line: line)
    }

    // MARK: - The story

    func test_story_followsTheRealPath_notTheGreatCircle() throws {
        // North of Bravo, where the great circle never goes.
        let geography = Geography(areas: FactsTestData.equator.areas + [FactsTestData.box("Charlie", .country, west: 5.5, east: 10.5, south: 1, north: 3)],
                                  cities: [])
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)

        let story = LegStory(leg: leg, geography: geography, home: nil)
        XCTAssertEqual(story.stretches.map(\.place.name), ["Alpha", "Bravo", "Charlie", "Bravo", "the Test Sea"])
        XCTAssertEqual(story.length, leg.pathLength)

        let scheduled = LegStory(leg: FactsTestData.equatorFlight(from: 0, to: 20), geography: geography, home: nil)
        XCTAssertEqual(scheduled.stretches.map(\.place.name), ["Alpha", "Bravo", "the Test Sea"], "the great circle stays on the equator")
    }

    func test_placeAtDistance_readsThePathByItsMeters() throws {
        let leg = try leg(seenUntil: "11:10")
        let story = LegStory(leg: leg, geography: FactsTestData.equator, home: nil)
        XCTAssertEqual(story.place(atDistance: 3 * FactsTestData.metersADegree)?.name, "Alpha")
        XCTAssertEqual(story.place(atDistance: 7 * FactsTestData.metersADegree)?.name, "Bravo")
        XCTAssertEqual(story.place(atDistance: 15 * FactsTestData.metersADegree)?.name, "the Test Sea")
    }

    func test_placeAtDistance_ofAStoryMadeForAShorterPath_isStillRightWhereThePlaneHasFlown() throws {
        // The story was made when the path was shorter. A place this far along it is still this far along it.
        let geography = Geography(areas: FactsTestData.equator.areas + [FactsTestData.box("Charlie", .country, west: 5.5, east: 10.5, south: 1, north: 3)],
                                  cities: [])
        let early = FactsTestData.liveTime(atLongitude: 8)
        let earlier = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: early, latitude: FactsTestData.dogLeg), at: early)
        let late = FactsTestData.liveTime(atLongitude: 13)
        let later = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: late, latitude: FactsTestData.dogLeg), at: late)
        XCTAssertNotEqual(earlier.pathLength, later.pathLength)

        let old = LegStory(leg: earlier, geography: geography, home: nil)
        let new = LegStory(leg: later, geography: geography, home: nil)
        for degrees in stride(from: 0.5, through: 7.5, by: 0.5) {
            let far = later.path.knots[Int(degrees * 4) - 1].distance
            XCTAssertEqual(old.place(atDistance: far), new.place(atDistance: far), "\(degrees)° E")
        }
    }

    func test_closestToHome_isMeasuredAlongTheRealPath() throws {
        // Home is 2.4° N of 8° E: 166 mi from the great circle, and 28 mi from the path that goes north to 2° N.
        let homeUpNorth = CLLocationCoordinate2D(latitude: 2.4, longitude: 8)
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)

        let closest = try XCTUnwrap(LegStory(along: leg.path, geography: nil, home: homeUpNorth).closestToHome)
        XCTAssertEqual(closest.meters, 0.4 * FactsTestData.metersADegree, accuracy: 500)
        XCTAssertEqual(leg.path.point(atDistance: closest.fraction * leg.pathLength).longitude, 8, accuracy: 0.05)
        XCTAssertNil(LegStory(along: FactsTestData.equatorFlight(from: 0, to: 20).path, geography: nil, home: homeUpNorth).closestToHome,
                     "too far from the great circle")
    }

    // MARK: - The milestones

    func test_milestones_onARealPath_haveTheRealPlanesTimes() throws {
        // The real plane is faster than the plan: it crosses into Bravo at 10:55, where the schedule has 11:00.
        let found = milestones(try leg(seenUntil: "12:30"), home: home)
        guard found.count == 4 else { return XCTFail("\(found.count) milestones, not 4: \(found.map(\.kind))") }
        assertMilestone(found[0], .crossedInto("Bravo"), at: "2026-03-20T10:55:00Z")
        assertMilestone(found[1], .halfway, at: "2026-03-20T11:35:00Z")
        assertMilestone(found[2], .outOver("the Test Sea"), at: "2026-03-20T11:51:35Z") // 5 mi offshore, by the coast snap
        assertMilestone(found[3], .closestToHome(miles: 35), at: "2026-03-20T12:07:00Z")
    }

    func test_milestones_aCrossingNobodySaw_isNotTold() throws {
        // Nobody saw it from 4° E to 6.5° E, where it crossed into Bravo.
        let found = milestones(try leg(seenUntil: "12:30", unseen: 4...6.5), home: home)
        XCTAssertEqual(found.map(\.kind), [.halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
    }

    func test_milestones_theClosestPointToHome_whereNobodySawIt_isNotTold() throws {
        // Nobody saw it from 13° E to 15° E, where it passed home.
        let found = milestones(try leg(seenUntil: "12:30", unseen: 13...15), home: home)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea")])
    }

    func test_milestones_aheadOfTheRealPlane_onlyHalfwayIsTold_andItsTimeIsAnEstimate() throws {
        // Last seen at 3.75° E. Every crossing is still ahead: it isn't told until the plane is seen past it.
        let leg = try leg(seenUntil: "10:45")
        let found = milestones(leg, home: home)
        XCTAssertEqual(found.map(\.kind), [.halfway])
        XCTAssertTrue(leg.isTimeEstimated(atDistance: leg.pathLength / 2))
        XCTAssertGreaterThan(try XCTUnwrap(found.first).time, at("10:45"))
    }

    func test_milestones_halfway_isHalfThePathsWholeLength() throws {
        // The path north to 2° N and back is about 22.5° long. Its half, 11.24° along it, is on the way back
        // down, at about 9.45° E: before 10° E, the great circle's halfway, which the real plane passes at 11:35.
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)
        let halfway = try XCTUnwrap(milestones(leg).first { $0.kind == .halfway })
        let place = leg.path.point(atDistance: leg.pathLength / 2)
        XCTAssertEqual(place.longitude, 9.45, accuracy: 0.05)
        XCTAssertEqual(halfway.time.timeIntervalSince1970, FactsTestData.liveTime(atLongitude: place.longitude).timeIntervalSince1970, accuracy: 5)
        XCTAssertLessThan(halfway.time, at("11:32"))
    }

    func test_milestones_withNoLiveData_areTheSchedules_asBefore() throws {
        let scheduled = FactsTestData.equatorFlight(from: 0, to: 20)
        let withNoAnswer = try FactsTestData.equatorLiveLeg(nil, at: at("11:10"))
        let before = milestones(scheduled, home: home)
        let after = milestones(withNoAnswer, home: home)
        XCTAssertEqual(before.map(\.kind), after.map(\.kind))
        for (earlier, later) in zip(before, after) {
            XCTAssertEqual(earlier.time.timeIntervalSince1970, later.time.timeIntervalSince1970, accuracy: 0.001)
        }
        XCTAssertEqual(before.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        if let first = before.first { assertMilestone(first, .crossedInto("Bravo"), at: "2026-03-20T11:00:00Z") }
    }
}
```

- [x] **Step 2: The story.**

In `Crewluv/Services/TripMap/Facts/LegStory.swift`:

Replace:

```swift
//  A flight's story, worked out once (Stage 2 spec §4.2): the places under its route and its closest point to home,
//  as fractions of the way along, 0 at the departure airport and 1 at the arrival. The schedule turns a fraction into
//  a time (`MapLeg.time(atFraction:)`), so a new delay moves every time without redoing the geography.
```

with:

```swift
//  A flight's story (Stage 2 spec §4.2, Stage 3 spec §8): the places under its path and its closest point to home,
//  as fractions of the way along, 0 at the departure airport and 1 at the arrival. The path is the great circle
//  until the plane has been seen in the air, and its real path from then on, when the story is made again as the
//  path grows. The leg turns a distance along its path into a time (`MapLeg.time(atDistance:)`), so a new delay
//  moves every time without redoing the geography.
```

Replace:

```swift
    /// In order. The first starts at 0. Empty without geography.
    let stretches: [Stretch]
    let closestToHome: ClosestToHome?

    init(stretches: [Stretch], closestToHome: ClosestToHome?) {
        self.stretches = stretches
        self.closestToHome = closestToHome
    }

    /// - Parameter home: where home is, or nil for a flight that starts or ends there.
    init(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, geography: Geography?, home: CLLocationCoordinate2D?) {
        let route = Route(origin: origin, destination: destination)
        stretches = geography.map { Self.stretches(along: route, in: $0) } ?? []
        closestToHome = home.flatMap { Self.closestPoint(of: route, to: $0) }
    }

    /// A flight's story. Home counts only when the flight doesn't start or end there.
    init(leg: MapLeg, geography: Geography?, home: AirportMark?) {
        let isHomeLeg = home.map { $0.code == leg.origin.code || $0.code == leg.destination.code } ?? true
        self.init(from: leg.origin.coordinate, to: leg.destination.coordinate, geography: geography,
                  home: isHomeLeg ? nil : home?.coordinate)
    }

    /// The place `fraction` of the way along.
    func place(atFraction fraction: Double) -> Geography.Place? {
        stretches.last { $0.start <= fraction }?.place
    }
```

with:

```swift
    /// In order. The first starts at 0. Empty without geography.
    let stretches: [Stretch]
    let closestToHome: ClosestToHome?
    /// The length of the path the story was made along, in meters: a fraction of the way is that share of it. A
    /// real path grows at its far end, and a place this far along it stays this far along it, so the story is
    /// read by distance.
    let length: Double

    init(stretches: [Stretch], closestToHome: ClosestToHome?, length: Double) {
        self.stretches = stretches
        self.closestToHome = closestToHome
        self.length = length
    }

    /// The story along `path`.
    /// - Parameter home: where home is, or nil for a flight that starts or ends there.
    init(along path: FlightPath, geography: Geography?, home: CLLocationCoordinate2D?) {
        let route = Route(path: path)
        stretches = geography.map { Self.stretches(along: route, in: $0) } ?? []
        closestToHome = home.flatMap { Self.closestPoint(of: route, to: $0) }
        length = path.length
    }

    /// The story along the great circle between two places.
    init(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, geography: Geography?, home: CLLocationCoordinate2D?) {
        self.init(along: FlightPath(from: origin, to: destination), geography: geography, home: home)
    }

    /// A flight's story, along its path. Home counts only when the flight doesn't start or end there.
    init(leg: MapLeg, geography: Geography?, home: AirportMark?) {
        let isHomeLeg = home.map { $0.code == leg.origin.code || $0.code == leg.destination.code } ?? true
        self.init(along: leg.path, geography: geography, home: isHomeLeg ? nil : home?.coordinate)
    }

    /// The place `fraction` of the way along.
    func place(atFraction fraction: Double) -> Geography.Place? {
        stretches.last { $0.start <= fraction }?.place
    }

    /// The place `distance` meters along the path.
    func place(atDistance distance: Double) -> Geography.Place? {
        place(atFraction: length > 0 ? distance / length : 0)
    }
```

Replace:

```swift
    private struct Route {
        let origin: CLLocationCoordinate2D
        let destination: CLLocationCoordinate2D
        let length: Double
        let sampleCount: Int

        init(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
            self.origin = origin
            self.destination = destination
            length = GreatCircle.distance(from: origin, to: destination)
            sampleCount = max(LegStory.minimumSamples, Int((length / LegStory.sampleSpacing).rounded(.up)) + 1)
        }

        var step: Double { 1 / Double(sampleCount - 1) }

        func point(at fraction: Double) -> CLLocationCoordinate2D {
            GreatCircle.point(from: origin, to: destination, fraction: fraction)
        }
    }
```

with:

```swift
    /// A path as the story samples it, by the fraction of the way along.
    private struct Route {
        let path: FlightPath
        let length: Double
        let sampleCount: Int

        init(path: FlightPath) {
            self.path = path
            length = path.length
            sampleCount = max(LegStory.minimumSamples, Int((length / LegStory.sampleSpacing).rounded(.up)) + 1)
        }

        var step: Double { 1 / Double(sampleCount - 1) }

        func point(at fraction: Double) -> CLLocationCoordinate2D {
            path.point(atDistance: fraction * length)
        }
    }
```

- [x] **Step 3: The milestones.**

In `Crewluv/Services/TripMap/Facts/Milestone.swift`:

Replace:

```swift
    /// A flight's milestones in time order, from its story and its delay-shifted times.
    static func milestones(on leg: MapLeg, story: LegStory) -> [Milestone] {
        var found: [(kind: Kind, fraction: Double)] = []
```

with:

```swift
    /// A flight's milestones in time order, from its story and the leg's own times: the real plane's along a real
    /// path, else the schedule's. On a real path a crossing, or the closest point to home, counts only where the
    /// plane was seen (Stage 3 spec §8): where nobody saw it the straight join is a guess, and a crossing is a
    /// claim. Halfway is half the path's whole length, flown and ahead.
    static func milestones(on leg: MapLeg, story: LegStory) -> [Milestone] {
        var found: [(kind: Kind, distance: Double, time: Date?)] = []
```

Replace:

```swift
            if let kind = crossingKind(from: previous.place, to: next.place) {
                found.append((kind, next.start))
            }
        }
        found.append((.halfway, 0.5))
        if let closest = story.closestToHome {
            found.append((.closestToHome(miles: roundedMiles(closest.meters)), closest.fraction))
        }
        return found.enumerated()
            .sorted { ($0.element.fraction, $0.offset) < ($1.element.fraction, $1.offset) }
            .compactMap { item in
                leg.time(atFraction: item.element.fraction).map { Milestone(kind: item.element.kind, time: $0) }
            }
    }
```

with:

```swift
            let distance = next.start * story.length
            if let kind = crossingKind(from: previous.place, to: next.place), leg.isSeen(atDistance: distance) {
                found.append((kind, distance, leg.time(atDistance: distance)))
            }
        }
        found.append((.halfway, leg.pathLength / 2, leg.halfwayTime))
        if let closest = story.closestToHome {
            let distance = closest.fraction * story.length
            if leg.isSeen(atDistance: distance) {
                found.append((.closestToHome(miles: roundedMiles(closest.meters)), distance, leg.time(atDistance: distance)))
            }
        }
        return found.enumerated()
            .sorted { ($0.element.distance, $0.offset) < ($1.element.distance, $1.offset) }
            .compactMap { item in item.element.time.map { Milestone(kind: item.element.kind, time: $0) } }
    }
```

- [ ] **Step 4: Ask to commit,** after batch A's checkpoint (Task 5). Suggested message: `feat(crewluv): a flight's story follows the path it really flew, with the real plane's times, and tells a crossing only where the plane was seen (Stage 3 spec §8)`.

---

### Task 4: The sky, and the miles

- The sun's times are worked out along the record: where the real plane was, when it was there.
- The horizon is seen from the real plane's height while it's at its cruise, and from 35,000 ft otherwise.
- A flight with a real path counts the miles along it: in the trip's totals, the longest flight, and the miles flown so far.

**Files:**
- Modify: `Crewluv/Services/TripMap/Facts/SkyFacts.swift`
- Modify: `Crewluv/Services/TripMap/TripMapWording.swift`
- Modify: `Crewluv/Services/TripMap/Facts/TripTotals.swift`
- Modify: `Crewluv/Services/TripMap/Facts/FactsWording+Trip.swift`
- Create: `CrewluvTests/LiveSkyFactsTests.swift`
- Create: `CrewluvTests/LiveTripTotalsTests.swift`

- [x] **Step 1: The tests.**

Create `CrewluvTests/LiveSkyFactsTests.swift`:

```swift
//
//  LiveSkyFactsTests.swift
//  CrewluvTests
//
//  The sky from the cockpit of a real plane (Stage 3 spec §8): its sunrises and sunsets along the path it really
//  flew, at the times it was really there, seen from the height it's really at.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveSkyFactsTests: XCTestCase {

    private func flight(departing iso: String, hours: Double = 8) -> MapLeg {
        let start = FactsTestData.date(iso)
        return MapLeg(id: "SDFCGN", kind: .flight,
                      origin: AirportMark(code: "SDF", city: nil, coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                      destination: AirportMark(code: "CGN", city: nil, coordinate: TripMapTestLegs.airports["CGN"]!, timeZone: nil),
                      start: start, end: start.addingTimeInterval(hours * 3600), flightNumber: nil)
    }

    /// The flight to Cologne, scheduled out at 18:00 UTC unless the test says, with a real plane that flies as the
    /// schedule has it but `late` seconds behind: seen every 2 minutes for its first five hours in the air.
    private func liveFlight(late: TimeInterval, altitudeFeet: Double = 35_000, state: LiveFlight.State = .airborne,
                            departing iso: String = "2026-11-13T18:00:00Z") throws -> MapLeg {
        let scheduled = flight(departing: iso)
        let asFlown = flight(departing: iso).delayed(by: late)
        let takeoff = try XCTUnwrap(asFlown.airborne).start
        let seenUntil = takeoff.addingTimeInterval(5 * 3600)
        var trail: [LiveFlight.TrailPoint] = []
        var time = takeoff.addingTimeInterval(120)
        while time <= seenUntil {
            let here = asFlown.position(at: time)
            trail.append(LiveFlight.TrailPoint(time: time, latitude: here.latitude, longitude: here.longitude, altitudeFeet: altitudeFeet))
            time = time.addingTimeInterval(120)
        }
        let last = try XCTUnwrap(trail.last)
        let fix = LiveFlight.Fix(latitude: last.latitude, longitude: last.longitude, altitudeFeet: altitudeFeet, groundSpeedKnots: 480,
                                 trackDegrees: 60, isOnGround: false, registration: "N370UP", typeCode: "B763", seenAt: last.time)
        let live = LiveFlight(legID: scheduled.id, callsign: "UPS207", state: state, fix: fix, landedAt: nil, trail: trail)
        let mapFlight = try XCTUnwrap(MapFlight(departure: scheduled.start, arrival: scheduled.end, from: scheduled.origin.coordinate,
                                                to: scheduled.destination.coordinate, live: live))
        let progress = mapFlight.progress(at: last.time)
        return MapLeg(id: scheduled.id, kind: .flight, origin: scheduled.origin, destination: scheduled.destination,
                      start: progress.start, end: progress.end, flightNumber: nil, flight: mapFlight)
    }

    // MARK: - The height it's seen from

    func test_cockpitHorizon_isFromTheRealPlanesHeight_whileItsAtItsCruise() throws {
        let high = try liveFlight(late: 0, altitudeFeet: 38_000)
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: high), SkyFacts.groundHorizon - SkyFacts.horizonDip(feet: 38_000), accuracy: 1e-9)
        XCTAssertLessThan(SkyFacts.cockpitHorizon(for: high), SkyFacts.cockpitHorizon, "higher up, the horizon is lower")
    }

    func test_cockpitHorizon_isFrom35000Feet_whileItClimbsOrComesDown() throws {
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 8_000)), SkyFacts.cockpitHorizon)
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 24_999)), SkyFacts.cockpitHorizon)
        XCTAssertNotEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 25_000)), SkyFacts.cockpitHorizon)
        XCTAssertNotEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 60_000)), SkyFacts.cockpitHorizon)
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 60_001)), SkyFacts.cockpitHorizon)
    }

    func test_cockpitHorizon_isFrom35000Feet_withNoPlaneInTheAir_orAHeightThatCantBeRight() throws {
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: flight(departing: "2026-11-13T18:00:00Z")), SkyFacts.cockpitHorizon, "no live data")
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 38_000, state: .landed)), SkyFacts.cockpitHorizon, "it's down")
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: 1e12)), SkyFacts.cockpitHorizon)
        XCTAssertEqual(SkyFacts.cockpitHorizon(for: try liveFlight(late: 0, altitudeFeet: .nan)), SkyFacts.cockpitHorizon)
    }

    // MARK: - Sunrise and sunset along the record

    func test_sunEvents_alongARecord_areWhereAndWhenTheRealPlaneWas() throws {
        // The real plane is 40 minutes behind the schedule. Its sunset is the one a flight scheduled 40 minutes
        // later would see, not the schedule's.
        let scheduled = try XCTUnwrap(SkyFacts.sunEvents(on: flight(departing: "2026-11-13T18:00:00Z")).first)
        let delayed = try XCTUnwrap(SkyFacts.sunEvents(on: flight(departing: "2026-11-13T18:40:00Z")).first)
        let events = SkyFacts.sunEvents(on: try liveFlight(late: 40 * 60))
        let real = try XCTUnwrap(events.first)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(real.kind, .sunset)
        XCTAssertEqual(real.time.timeIntervalSince1970, delayed.time.timeIntervalSince1970, accuracy: 60)
        XCTAssertGreaterThan(abs(real.time.timeIntervalSince(scheduled.time)), 5 * 60, "the schedule's sunset is minutes off")
        XCTAssertEqual(try XCTUnwrap(real.peopleBelowGap), try XCTUnwrap(delayed.peopleBelowGap), accuracy: 60)
    }

    func test_airborne_ofAPlaneThatLeftLate_beginsWhenItReallyLeft() throws {
        // The schedule has it off the ground at 18:15. It left 40 minutes after that.
        let airborne = try XCTUnwrap(try liveFlight(late: 40 * 60).airborne)
        XCTAssertEqual(airborne.start.timeIntervalSince1970, FactsTestData.date("2026-11-13T18:55:00Z").timeIntervalSince1970, accuracy: 120)
    }

    func test_sunEvents_ofAPlaneThatLeftAfterDark_haveNoSunset_thoughTheScheduleHadItOffBefore() throws {
        // The schedule has it off at 22:35 UTC, minutes after sunset in Louisville, with the sun still above the
        // cockpit's horizon at cruise: its plane sees a sunset. The real plane left 40 minutes later, in the dark.
        let scheduled = SkyFacts.sunEvents(on: flight(departing: "2026-11-13T22:20:00Z"))
        XCTAssertEqual(scheduled.first?.kind, .sunset)
        let real = SkyFacts.sunEvents(on: try liveFlight(late: 40 * 60, departing: "2026-11-13T22:20:00Z"))
        XCTAssertFalse(real.contains { $0.kind == .sunset }, "\(real)")
    }

    func test_sunEvents_seenFromHigherUp_setLater() throws {
        let lower = try XCTUnwrap(SkyFacts.sunEvents(on: try liveFlight(late: 0, altitudeFeet: 30_000)).first)
        let higher = try XCTUnwrap(SkyFacts.sunEvents(on: try liveFlight(late: 0, altitudeFeet: 41_000)).first)
        XCTAssertGreaterThan(higher.time, lower.time)
        XCTAssertLessThan(higher.time.timeIntervalSince(lower.time), 5 * 60, "by a minute or two")
    }

    func test_sunEvents_withNoLiveData_areTheSchedules_asBefore() throws {
        let scheduled = flight(departing: "2026-11-13T18:00:00Z")
        let withNoAnswer = MapLeg(id: scheduled.id, kind: .flight, origin: scheduled.origin, destination: scheduled.destination,
                                  start: scheduled.start, end: scheduled.end, flightNumber: nil,
                                  flight: MapFlight(departure: scheduled.start, arrival: scheduled.end, from: scheduled.origin.coordinate,
                                                    to: scheduled.destination.coordinate))
        XCTAssertEqual(SkyFacts.sunEvents(on: withNoAnswer), SkyFacts.sunEvents(on: scheduled))
    }

    func test_sunAltitude_isAtTheRecordsPlace() throws {
        let leg = try liveFlight(late: 40 * 60)
        let at = FactsTestData.date("2026-11-13T21:00:00Z")
        let here = try XCTUnwrap(leg.flight?.record).position(at: at)
        XCTAssertEqual(SkyFacts.sunAltitude(on: leg, at: at), SolarPosition.altitude(latitude: here.latitude, longitude: here.longitude, at: at))
    }
}

private extension MapLeg {
    /// The same leg, `seconds` later.
    func delayed(by seconds: TimeInterval) -> MapLeg {
        MapLeg(id: id, kind: kind, origin: origin, destination: destination, start: start.addingTimeInterval(seconds),
               end: end.addingTimeInterval(seconds), flightNumber: flightNumber)
    }
}
```

Create `CrewluvTests/LiveTripTotalsTests.swift`:

```swift
//
//  LiveTripTotalsTests.swift
//  CrewluvTests
//
//  The trip's miles along real paths (Stage 3 spec §8). The made-up real plane is `FactsTestData`'s: a degree of
//  longitude every 8 minutes from 10:15 UTC. One degree along the equator is 69.09 mi, and the flight is 1,382 mi.
//

import XCTest
@testable import Crewluv

final class LiveTripTotalsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    func test_totalMiles_andTheLongestFlight_countAlongTheRealPath() throws {
        // The flight north to 2° N and back is about 171 mi longer than its great circle: longer than a flight to
        // 20.5° E, whose airports are further apart.
        let seenUntil = FactsTestData.liveTime(atLongitude: 13)
        let wandering = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: seenUntil, latitude: FactsTestData.dogLeg), at: seenUntil)
        let straight = FactsTestData.equatorFlight(from: 0, to: 20.5, id: "straight")
        XCTAssertLessThan(wandering.distance, straight.distance)

        XCTAssertEqual(TripTotals.longestFlight(of: [straight, wandering])?.id, wandering.id)
        XCTAssertEqual(TripMapWording.totalMiles(of: [wandering]), Int((wandering.pathLength / GreatCircle.metersPerMile).rounded()))
        XCTAssertGreaterThan(TripMapWording.totalMiles(of: [wandering]), 1_382 + 150)
        XCTAssertEqual(TripMapWording.milesFlown(by: wandering.end, on: [wandering]), TripMapWording.totalMiles(of: [wandering]),
                       "once it's in, every mile of its path counts")
        XCTAssertEqual(FactsWording.longest(wandering, locale: locale), "E0 → E20, \(TripMapWording.milesText(TripMapWording.totalMiles(of: [wandering]), locale: locale))")
    }

    func test_milesFlown_ofAFlightInTheAir_isAsFarAsTheRealPlaneIs() throws {
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("11:10")), at: at("11:10"))
        XCTAssertEqual(TripMapWording.milesFlown(by: at("11:10"), on: [leg]), 475)
        XCTAssertEqual(TripMapWording.milesFlown(by: at("10:35"), on: [leg], isReplay: true), 173)
        XCTAssertEqual(TripMapWording.milesFlown(by: leg.start.addingTimeInterval(-60), on: [leg]), 0)
        XCTAssertEqual(TripMapWording.milesFlown(by: leg.end, on: [leg]), 1_382)
    }

    func test_soFar_inAReplay_countsAsFarAsTheRecordHasThePlane() throws {
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("11:10")), at: at("11:10"))
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        XCTAssertEqual(TripTotals.soFar(on: map, at: at("11:10"), sunEvents: [:]).miles, 475)
        XCTAssertEqual(TripTotals.soFar(on: map, at: at("10:35"), sunEvents: [:], isReplay: true).miles, 173)
    }
}
```

- [x] **Step 2: The sky.**

In `Crewluv/Services/TripMap/Facts/SkyFacts.swift`:

Replace:

```swift
    /// The schedule's height in the air. Stage 3 uses the live altitude.
    static let cruiseAltitudeFeet: Double = 35_000
```

with:

```swift
    /// The schedule's height in the air. It also stands in for a real plane that's climbing or coming down.
    static let cruiseAltitudeFeet: Double = 35_000
    /// A real plane's own height counts while it's at its cruise: between these, in feet. Lower, it's on its way
    /// up or down, and the sunrises and sunsets ahead are seen from the cruise it's climbing to. Higher can't be
    /// right.
    static let cruiseAltitudesFeet: ClosedRange<Double> = 25_000...60_000
```

Replace:

```swift
    /// The sun's altitude at the schedule's plane, in degrees.
    static func sunAltitude(on leg: MapLeg, at date: Date) -> Double {
        let here = leg.position(at: date)
        return SolarPosition.altitude(latitude: here.latitude, longitude: here.longitude, at: date)
    }
```

with:

```swift
    /// The sun's altitude at a cockpit sunrise or sunset on `leg` (Stage 3 spec §8): from the height the real
    /// plane was last seen at, while it's in the air at its cruise, and from 35,000 ft otherwise.
    static func cockpitHorizon(for leg: MapLeg) -> Double {
        guard let live = leg.flight?.live, live.state == .airborne, let fix = live.fix, !fix.isOnGround,
              let feet = fix.altitudeFeet, cruiseAltitudesFeet.contains(feet) else { return cockpitHorizon }
        return groundHorizon - horizonDip(feet: feet)
    }

    /// The sun's altitude at the plane, in degrees: where its record has it, else where the schedule does.
    static func sunAltitude(on leg: MapLeg, at date: Date) -> Double {
        let here = leg.coursePosition(at: date)
        return SolarPosition.altitude(latitude: here.latitude, longitude: here.longitude, at: date)
    }
```

Replace:

```swift
    /// The sunrises and sunsets the cockpit sees while the schedule has the flight in the air, in order: sampled every
    /// 2 minutes and narrowed to 5 seconds.
    static func sunEvents(on leg: MapLeg) -> [SunEvent] {
        guard leg.kind == .flight, let window = FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end) else { return [] }
        let height: (Date) -> Double = { sunAltitude(on: leg, at: $0) - cockpitHorizon }
```

with:

```swift
    /// The sunrises and sunsets the cockpit sees while the flight is in the air, in order: sampled every 2 minutes
    /// and narrowed to 5 seconds. A flight with a record is followed along its real path, at its real times.
    static func sunEvents(on leg: MapLeg) -> [SunEvent] {
        guard leg.kind == .flight, let window = leg.airborne else { return [] }
        let horizon = cockpitHorizon(for: leg)
        let height: (Date) -> Double = { sunAltitude(on: leg, at: $0) - horizon }
```

Replace:

```swift
                            peopleBelowGap: peopleBelowGap(at: leg.position(at: eventTime), cockpitTime: eventTime, isSunrise: isRising))
```

with:

```swift
                            peopleBelowGap: peopleBelowGap(at: leg.coursePosition(at: eventTime), cockpitTime: eventTime, isSunrise: isRising))
```

Replace:

```swift
        guard leg.kind == .flight, let window = FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end),
              window.contains(date), sunAltitude(on: leg, at: date) > cockpitHorizon else { return nil }
        let here = leg.position(at: date)
        let soon = leg.position(at: date.addingTimeInterval(60))
```

with:

```swift
        guard leg.kind == .flight, let window = leg.airborne,
              window.contains(date), sunAltitude(on: leg, at: date) > cockpitHorizon(for: leg) else { return nil }
        let here = leg.coursePosition(at: date)
        let soon = leg.coursePosition(at: date.addingTimeInterval(60))
```

Replace:

```swift
        guard leg.kind == .flight, sunAltitude(on: leg, at: date) <= cockpitHorizon else { return nil }
        let here = leg.position(at: date)
```

with:

```swift
        guard leg.kind == .flight, sunAltitude(on: leg, at: date) <= cockpitHorizon(for: leg) else { return nil }
        let here = leg.coursePosition(at: date)
```

- [x] **Step 3: The miles.**

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
    /// Miles flown by `date`, counting the part of a flight that's in the air.
    static func milesFlown(by date: Date, on legs: [MapLeg]) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { $0 + $1.distance * $1.progress(at: date) }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }

    static func totalMiles(of legs: [MapLeg]) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { $0 + $1.distance }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }
```

with:

```swift
    /// Miles flown by `date`, counting the part of a flight that's in the air. A flight with a real path counts
    /// the miles along it (Stage 3 spec §8).
    /// - Parameter isReplay: `date` is a moment of the replay, not now.
    static func milesFlown(by date: Date, on legs: [MapLeg], isReplay: Bool = false) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { total, leg in
            if date >= leg.end { return total + leg.pathLength }
            if date < leg.start { return total }
            return total + leg.plane(at: date, isReplay: isReplay).distance
        }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }

    /// The trip's miles, along each flight's real path where it has one.
    static func totalMiles(of legs: [MapLeg]) -> Int {
        let meters = legs.filter { $0.kind == .flight }.reduce(0) { $0 + $1.pathLength }
        return Int((meters / GreatCircle.metersPerMile).rounded())
    }
```

In `Crewluv/Services/TripMap/Facts/TripTotals.swift`:

Replace:

```swift
    /// Up to `date`: finished flights, and the miles of the one in the air.
    static func soFar(on tripMap: TripMap, at date: Date, sunEvents: [String: [SkyFacts.SunEvent]]) -> TripTotals {
        let finished = tripMap.legs.filter { $0.kind == .flight && $0.end <= date }
        return TripTotals(
            cities: TripMapWording.destinations(of: finished, leavingOut: homeCodes(of: tripMap)).count,
            miles: TripMapWording.milesFlown(by: date, on: tripMap.legs),
```

with:

```swift
    /// Up to `date`: finished flights, and the miles of the one in the air.
    /// - Parameter isReplay: `date` is a moment of the replay, not now.
    static func soFar(on tripMap: TripMap, at date: Date, sunEvents: [String: [SkyFacts.SunEvent]],
                      isReplay: Bool = false) -> TripTotals {
        let finished = tripMap.legs.filter { $0.kind == .flight && $0.end <= date }
        return TripTotals(
            cities: TripMapWording.destinations(of: finished, leavingOut: homeCodes(of: tripMap)).count,
            miles: TripMapWording.milesFlown(by: date, on: tripMap.legs, isReplay: isReplay),
```

Replace:

```swift
    static func longestFlight(of legs: [MapLeg]) -> MapLeg? {
        legs.filter { $0.kind == .flight }.max { $0.distance < $1.distance }
    }
```

with:

```swift
    /// The flight with the most miles, along its real path where it has one.
    static func longestFlight(of legs: [MapLeg]) -> MapLeg? {
        legs.filter { $0.kind == .flight }.max { $0.pathLength < $1.pathLength }
    }
```

In `Crewluv/Services/TripMap/Facts/FactsWording+Trip.swift`:

Replace:

```swift
        Int((leg.distance / GreatCircle.metersPerMile).rounded())
```

with:

```swift
        Int((leg.pathLength / GreatCircle.metersPerMile).rounded())
```

- [ ] **Step 4: Ask to commit,** after batch A's checkpoint (Task 5). Suggested message: `feat(crewluv): the sun's times follow the real plane's record, seen from its own height at its cruise, and the trip's miles count along real paths (Stage 3 spec §8)`.

---

### Task 5: The words, and the aircraft's names

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/AircraftTypeNames.swift`
- Modify: `Crewluv/Services/TripMap/Facts/FactsWording.swift`
- Modify: `Crewluv/Services/TripMap/TripMapWording.swift`
- Modify: `Crewluv/Services/TripMap/Facts/FactRow.swift`
- Create: `CrewluvTests/AircraftTypeNamesTests.swift`
- Modify: `CrewluvTests/FactsWordingTests.swift`
- Modify: `CrewluvTests/LiveWordingTests.swift`

- [x] **Step 1: The tests.**

Create `CrewluvTests/AircraftTypeNamesTests.swift`:

```swift
//
//  AircraftTypeNamesTests.swift
//  CrewluvTests
//
//  An aircraft's name from its type code (Stage 3 spec §8).
//

import XCTest
@testable import Crewluv

final class AircraftTypeNamesTests: XCTestCase {

    func test_name_theFreightersAPilotsFamilySees() {
        XCTAssertEqual(AircraftTypeNames.name(for: "B763"), "Boeing 767-300")
        XCTAssertEqual(AircraftTypeNames.name(for: "B748"), "Boeing 747-8")
        XCTAssertEqual(AircraftTypeNames.name(for: "B744"), "Boeing 747-400")
        XCTAssertEqual(AircraftTypeNames.name(for: "B752"), "Boeing 757-200")
        XCTAssertEqual(AircraftTypeNames.name(for: "A306"), "Airbus A300-600")
        XCTAssertEqual(AircraftTypeNames.name(for: "MD11"), "McDonnell Douglas MD-11")
        // One code for the 777-200LR and the 777 Freighter, which is built on it.
        XCTAssertEqual(AircraftTypeNames.name(for: "B77L"), "Boeing 777-200")
    }

    func test_name_anAirliner() {
        XCTAssertEqual(AircraftTypeNames.name(for: "B738"), "Boeing 737-800")
        XCTAssertEqual(AircraftTypeNames.name(for: "A20N"), "Airbus A320neo")
        XCTAssertEqual(AircraftTypeNames.name(for: "E75L"), "Embraer 175")
        XCTAssertEqual(AircraftTypeNames.name(for: "CRJ9"), "Bombardier CRJ900")
    }

    func test_name_anUnknownCode_showsAsItself() {
        XCTAssertEqual(AircraftTypeNames.name(for: "ZZZZ"), "ZZZZ")
        XCTAssertEqual(AircraftTypeNames.name(for: "GLF6"), "GLF6")
    }

    func test_name_readsACodeInAnyCase_withSpacesAroundIt() {
        XCTAssertEqual(AircraftTypeNames.name(for: " b763 "), "Boeing 767-300")
        XCTAssertEqual(AircraftTypeNames.name(for: "zzzz"), "ZZZZ")
    }
}
```

In `CrewluvTests/FactsWordingTests.swift`:

Replace:

```swift
    // MARK: - The sky
```

with:

```swift
    func test_closestToHome_aheadOfARealPlane_saysAbout() {
        let later = now.addingTimeInterval(3600)
        XCTAssertEqual(plain(FactsWording.closestToHome(miles: 40, at: later, now: now, isEstimate: true, calendar: calendar, locale: locale)),
                       "Passes 40 mi from home at about 4:14 PM")
        XCTAssertEqual(plain(FactsWording.closestToHome(miles: 40, at: now, now: later, isEstimate: true, calendar: calendar, locale: locale)),
                       "Closest to home was 40 mi at 3:14 PM")
    }

    // MARK: - The real plane (Stage 3 spec §8)

    func test_lastSeen_theCityByIt_elseThePlaceUnderIt_elseHowLongAgo() {
        let place = Geography.Place(name: "Québec", kind: .province, country: "Canada")
        let city = Geography.City(name: "Montréal", lat: 45.5, lon: -73.57)
        XCTAssertEqual(FactsWording.lastSeen(place, near: city, ago: 600), "near Montréal")
        XCTAssertEqual(FactsWording.lastSeen(place, near: nil, ago: 600), "over Québec")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: 600), "10 min ago")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: 7_200), "2 h ago")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: 7_800), "2 h 10 min ago")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: 7_800, isSpoken: true), "2 hours 10 minutes ago")
    }

    func test_lastSeen_aTimeThatCantBeRight_isHeldFromAMinuteToAYear() {
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: 20), "1 min ago")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: -500), "1 min ago")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: .infinity), "8760 h ago")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: .nan), "1 min ago")
    }

    func test_estimated_saysSoFirst() {
        XCTAssertEqual(FactsWording.estimated(lastSeen: "near Montréal"), "Estimated · last seen near Montréal")
    }

    func test_aircraft_itsTypeAndRegistration_eachWhereItsKnown() {
        XCTAssertEqual(FactsWording.aircraft(typeCode: "B763", registration: "N370UP"), "Boeing 767-300 · N370UP")
        XCTAssertEqual(FactsWording.aircraft(typeCode: "ZZZZ", registration: "N370UP"), "ZZZZ · N370UP", "an unknown type shows as itself")
        XCTAssertEqual(FactsWording.aircraft(typeCode: "B763", registration: nil), "Boeing 767-300")
        XCTAssertEqual(FactsWording.aircraft(typeCode: nil, registration: "N370UP"), "N370UP")
        XCTAssertNil(FactsWording.aircraft(typeCode: nil, registration: nil))
        XCTAssertNil(FactsWording.aircraft(typeCode: "  ", registration: ""))
    }

    func test_heightAndSpeed_toTheNearest100FeetAnd10MilesAnHour() {
        // 470 kt is 540.9 mph.
        XCTAssertEqual(FactsWording.heightAndSpeed(altitudeFeet: 34_975, groundSpeedKnots: 470, locale: locale), "35,000 ft · 540 mph")
        XCTAssertEqual(FactsWording.heightAndSpeed(altitudeFeet: 35_000, groundSpeedKnots: nil, locale: locale), "35,000 ft")
        XCTAssertEqual(FactsWording.heightAndSpeed(altitudeFeet: nil, groundSpeedKnots: 470, locale: locale), "540 mph")
        XCTAssertNil(FactsWording.heightAndSpeed(altitudeFeet: nil, groundSpeedKnots: nil, locale: locale))
    }

    func test_heightAndSpeed_atTheEdgesOfWhatsBelieved_show() {
        XCTAssertEqual(FactsWording.heightAndSpeed(altitudeFeet: 0, groundSpeedKnots: 0, locale: locale), "0 ft · 0 mph")
        // 800 kt is 920.6 mph.
        XCTAssertEqual(FactsWording.heightAndSpeed(altitudeFeet: 60_000, groundSpeedKnots: 800, locale: locale), "60,000 ft · 920 mph")
        XCTAssertNil(FactsWording.heightAndSpeed(altitudeFeet: 60_001, groundSpeedKnots: 801, locale: locale))
    }

    func test_heightAndSpeed_aNumberThatCantBeRight_isLeftOut() {
        XCTAssertEqual(FactsWording.heightAndSpeed(altitudeFeet: 1e12, groundSpeedKnots: 470, locale: locale), "540 mph")
        XCTAssertEqual(FactsWording.heightAndSpeed(altitudeFeet: -500, groundSpeedKnots: 470, locale: locale), "540 mph")
        XCTAssertEqual(FactsWording.heightAndSpeed(altitudeFeet: 35_000, groundSpeedKnots: 5_000, locale: locale), "35,000 ft")
        XCTAssertNil(FactsWording.heightAndSpeed(altitudeFeet: .nan, groundSpeedKnots: .infinity, locale: locale))
    }

    func test_halfway_withTheRealPlanesEstimate_saysAbout() {
        XCTAssertEqual(plain(FactsWording.halfway(at: now, calendar: calendar, locale: locale)), "Halfway at 3:14 PM")
        XCTAssertEqual(plain(FactsWording.halfway(at: now, isEstimate: true, calendar: calendar, locale: locale)), "Halfway at about 3:14 PM")
    }

    func test_liveCredit_namesAdsbLol() {
        XCTAssertEqual(FactsWording.liveCredit, "Live position: adsb.lol")
        XCTAssertEqual(FactsWording.spokenLiveCredit, "Live position from adsb.lol.")
    }

    // MARK: - The sky
```

In `CrewluvTests/LiveWordingTests.swift`:

Replace:

```swift
    func test_liveSummary_stillOnTheGround_saysSo_andWhenItWillLand() throws {
```

with:

```swift
    func test_liveSummary_whileEstimated_saysWhereItWasLastSeen_inPlaceOfWhatsBelow() throws {
        let (leg, at) = try leg(of: "ahead, in the air", at: "13T12:45:00")
        let summary = TripMapWording.liveSummary(for: leg, over: "Ohio", lastSeen: "near Columbus", now: at, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(try XCTUnwrap(summary)),
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, last seen near Columbus. Lands about 8:30 AM your time.")
    }

    func test_liveSummary_stillOnTheGround_saysSo_andWhenItWillLand() throws {
```

- [x] **Step 2: The aircraft's names.** The codes are ICAO's type designators. This table was written from memory: have the review check it against ICAO's Doc 8643 or another source. `B77L` is one code for the 777-200LR and the 777 Freighter, so it reads "Boeing 777-200".

Create `Crewluv/Services/TripMap/Facts/AircraftTypeNames.swift`:

```swift
//
//  AircraftTypeNames.swift
//  CrewLuve
//
//  An aircraft's name from the type code it broadcasts (Stage 3 spec §8): "Boeing 767-300" for "B763". The codes
//  are ICAO's type designators (Doc 8643), for the airliners and freighters a pilot's family is likely to see.
//

import Foundation

nonisolated enum AircraftTypeNames {

    /// The name for `typeCode`, or the code itself, in capitals, when it isn't one of these.
    static func name(for typeCode: String) -> String {
        let code = typeCode.trimmingCharacters(in: .whitespaces).uppercased()
        return names[code] ?? code
    }

    private static let names: [String: String] = [
        // Airbus
        "A306": "Airbus A300-600", "A30B": "Airbus A300", "A310": "Airbus A310",
        "A318": "Airbus A318", "A319": "Airbus A319", "A320": "Airbus A320", "A321": "Airbus A321",
        "A19N": "Airbus A319neo", "A20N": "Airbus A320neo", "A21N": "Airbus A321neo",
        "A332": "Airbus A330-200", "A333": "Airbus A330-300", "A338": "Airbus A330-800", "A339": "Airbus A330-900",
        "A342": "Airbus A340-200", "A343": "Airbus A340-300", "A345": "Airbus A340-500", "A346": "Airbus A340-600",
        "A359": "Airbus A350-900", "A35K": "Airbus A350-1000", "A388": "Airbus A380",
        "BCS1": "Airbus A220-100", "BCS3": "Airbus A220-300",
        // Boeing
        "B712": "Boeing 717",
        "B722": "Boeing 727-200",
        "B733": "Boeing 737-300", "B734": "Boeing 737-400", "B735": "Boeing 737-500", "B736": "Boeing 737-600",
        "B737": "Boeing 737-700", "B738": "Boeing 737-800", "B739": "Boeing 737-900",
        "B37M": "Boeing 737 MAX 7", "B38M": "Boeing 737 MAX 8", "B39M": "Boeing 737 MAX 9", "B3XM": "Boeing 737 MAX 10",
        "B742": "Boeing 747-200", "B744": "Boeing 747-400", "B748": "Boeing 747-8",
        "B752": "Boeing 757-200", "B753": "Boeing 757-300",
        "B762": "Boeing 767-200", "B763": "Boeing 767-300", "B764": "Boeing 767-400",
        "B772": "Boeing 777-200", "B77L": "Boeing 777-200", "B773": "Boeing 777-300", "B77W": "Boeing 777-300ER",
        "B778": "Boeing 777-8", "B779": "Boeing 777-9",
        "B788": "Boeing 787-8", "B789": "Boeing 787-9", "B78X": "Boeing 787-10",
        // McDonnell Douglas
        "DC10": "McDonnell Douglas DC-10", "MD11": "McDonnell Douglas MD-11",
        "MD82": "McDonnell Douglas MD-82", "MD83": "McDonnell Douglas MD-83", "MD88": "McDonnell Douglas MD-88",
        "MD90": "McDonnell Douglas MD-90",
        // Embraer
        "E135": "Embraer ERJ 135", "E145": "Embraer ERJ 145", "E45X": "Embraer ERJ 145",
        "E170": "Embraer 170", "E75L": "Embraer 175", "E75S": "Embraer 175",
        "E190": "Embraer 190", "E195": "Embraer 195", "E290": "Embraer E190-E2", "E295": "Embraer E195-E2",
        // Bombardier and De Havilland Canada
        "CRJ2": "Bombardier CRJ200", "CRJ7": "Bombardier CRJ700", "CRJ9": "Bombardier CRJ900", "CRJX": "Bombardier CRJ1000",
        "DH8C": "De Havilland Dash 8-300", "DH8D": "De Havilland Dash 8-400",
        // ATR and the feeders
        "AT43": "ATR 42", "AT45": "ATR 42", "AT46": "ATR 42-600",
        "AT72": "ATR 72", "AT75": "ATR 72", "AT76": "ATR 72-600",
        "C208": "Cessna Caravan", "SF34": "Saab 340", "B190": "Beechcraft 1900",
    ]
}
```

- [x] **Step 3: The facts' words.** The words for a plane that's out of sight are the ones Todd said yes to (question 1).

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed.
    static func closestToHome(miles: Int, at time: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let clock = TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale)
        return time > now ? "Passes \(miles) mi from home at \(clock)" : "Closest to home was \(miles) mi at \(clock)"
    }
```

with:

```swift
    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed. Ahead of a
    /// real plane the time is its estimate: "Passes 40 mi from home at about 1:05 PM" (Stage 3 spec §9).
    static func closestToHome(miles: Int, at time: Date, now: Date, isEstimate: Bool = false,
                              calendar: Calendar = .current, locale: Locale = .current) -> String {
        let clock = TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale)
        guard time > now else { return "Closest to home was \(miles) mi at \(clock)" }
        return "Passes \(miles) mi from home at \(isEstimate ? "about " : "")\(clock)"
    }

    // MARK: - The real plane (Stage 3 spec §8)

    /// The headline and the "below" row while the real plane is an estimate: "Estimated · last seen near Montréal".
    static func estimated(lastSeen: String) -> String {
        "Estimated · last seen \(lastSeen)"
    }

    /// Where an estimated plane was last seen: "near Montréal" by a city of a million or more, else "over Québec",
    /// else how long ago, "2 h ago". `isSpoken` writes that out for VoiceOver: "2 hours ago".
    static func lastSeen(_ place: Geography.Place?, near city: Geography.City?, ago: TimeInterval, isSpoken: Bool = false) -> String {
        if let city { return "near \(city.name)" }
        if let place { return "over \(place.name)" }
        // Held from a minute to a year, so a time that can't be right never overflows.
        let asked = (ago / 60).rounded()
        let minutes = asked.isNaN ? 1 : Int(min(max(asked, 1), 365 * 24 * 60))
        return "\(isSpoken ? TripMapWording.spokenMinutes(minutes) : TripMapWording.minutesText(minutes)) ago"
    }

    /// The plane's row: "Boeing 767-300 · N370UP". An unknown type code shows as itself, and a missing type or
    /// registration is left out. Nil with neither.
    static func aircraft(typeCode: String?, registration: String?) -> String? {
        let parts = [typeCode.flatMap(nonEmpty).map(AircraftTypeNames.name(for:)), registration.flatMap(nonEmpty)].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "35,000 ft · 540 mph": the real plane's height to the nearest 100 ft and its speed over the ground to the
    /// nearest 10 mph, each where the plane sent one that could be right. Nil with neither.
    static func heightAndSpeed(altitudeFeet: Double?, groundSpeedKnots: Double?, locale: Locale = .current) -> String? {
        let height = altitudeFeet.flatMap { feet in
            believedHeightsFeet.contains(feet) ? "\(number(Int((feet / 100).rounded()) * 100, locale: locale)) ft" : nil
        }
        let speed = groundSpeedKnots.flatMap { knots -> String? in
            guard believedSpeedsKnots.contains(knots) else { return nil }
            let milesPerHour = knots * GreatCircle.metersPerNauticalMile / GreatCircle.metersPerMile
            return "\(number(Int((milesPerHour / 10).rounded()) * 10, locale: locale)) mph"
        }
        let parts = [height, speed].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// A height or a speed outside these is left out: no airliner sends one, and a number that can't be right
    /// mustn't reach the screen.
    static let believedHeightsFeet: ClosedRange<Double> = 0...60_000
    static let believedSpeedsKnots: ClosedRange<Double> = 0...800

    /// The credit under the facts wherever a flight with live data shows: adsb.lol's data is under the ODbL.
    static let liveCredit = "Live position: adsb.lol"
    /// The credit as VoiceOver reads it.
    static let spokenLiveCredit = "Live position from adsb.lol."
```

Replace:

```swift
    static func halfway(at time: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Halfway at \(TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale))"
    }
```

with:

```swift
    /// "Halfway at 4:12 PM", or with the real plane's estimate "Halfway at about 12:05 PM" (Stage 3 spec §8).
    static func halfway(at time: Date, isEstimate: Bool = false, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Halfway at \(isEstimate ? "about " : "")\(TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale))"
    }
```

Replace:

```swift
    private static func name(of kind: SkyFacts.SunEvent.Kind) -> String {
        kind == .sunrise ? "Sunrise" : "Sunset"
    }
```

with:

```swift
    private static func name(of kind: SkyFacts.SunEvent.Kind) -> String {
        kind == .sunrise ? "Sunrise" : "Sunset"
    }

    /// `text` without the spaces around it, or nil when nothing is left.
    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
```

- [x] **Step 4: The card's sentence, and the plane's row's kind.**

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
    /// - Parameter place: what's below the plane, when the facts know.
    static func liveSummary(for leg: MapLeg, over place: String? = nil, now: Date,
                            calendar: Calendar = .current, locale: Locale = .current) -> String? {
        guard let label = leg.flight?.progress(at: now).label else { return nil }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        let over = place.map { ", over \($0)" } ?? ""
```

with:

```swift
    /// - Parameters:
    ///   - place: what's below the plane, when the facts know.
    ///   - lastSeen: where an estimated plane was last seen, as `FactsWording.lastSeen` words it: "near Montréal",
    ///     "over Québec" or "2 hours ago". It takes the place of what's below (Stage 3 spec §15).
    static func liveSummary(for leg: MapLeg, over place: String? = nil, lastSeen: String? = nil, now: Date,
                            calendar: Calendar = .current, locale: Locale = .current) -> String? {
        guard let label = leg.flight?.progress(at: now).label else { return nil }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        let over = lastSeen.map { ", last seen \($0)" } ?? place.map { ", over \($0)" } ?? ""
```

In `Crewluv/Services/TripMap/Facts/FactRow.swift`:

Replace:

```swift
        // In flight (§5.1)
        case below, sky, distance, headed
```

with:

```swift
        // In flight (§5.1), with the plane's row for a flight with live data (Stage 3 spec §8)
        case below, plane, sky, distance, headed
```

- [x] **Step 5: Review batch A.** Dispatch `superpowers:code-reviewer` (sonnet) on Tasks 2 to 5, with the spec's §8 and §9, the Stage 2 spec's §4, and this plan's list of where it differs. Ask it in particular:
  - Is there a moment where the facts' plane and the map's plane could be in two places?
  - Does a flight with no live data come out exactly as before, to the last bit that matters?
  - Is every code in `AircraftTypeNames` ICAO's, with the right name?
  - Can any number from Crewlu Cloud (a height, a speed, a time) crash a conversion to `Int`?

  Use `superpowers:receiving-code-review` on what comes back.

- [x] **Step 6: Checkpoint, batch A.** Todd runs the six new classes (52 tests) and the eleven classes of the code these tasks changed (192 tests in all):

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:CrewluvTests/PlanePositionTests -only-testing:CrewluvTests/MapLegCourseTests -only-testing:CrewluvTests/LiveStoryTests -only-testing:CrewluvTests/LiveSkyFactsTests -only-testing:CrewluvTests/LiveTripTotalsTests -only-testing:CrewluvTests/AircraftTypeNamesTests -only-testing:CrewluvTests/LegStoryTests -only-testing:CrewluvTests/MilestoneTests -only-testing:CrewluvTests/SkyFactsTests -only-testing:CrewluvTests/TripTotalsTests -only-testing:CrewluvTests/FactsWordingTests -only-testing:CrewluvTests/LiveWordingTests -only-testing:CrewluvTests/TripMapWordingTests -only-testing:CrewluvTests/FactsCasesTests -only-testing:CrewluvTests/TripFactsTests -only-testing:CrewluvTests/TripFactsRowsTests -only-testing:CrewluvTests/LegStoryStoreTests
```

Expected: every test passes.

- [ ] **Step 7: Ask to commit Tasks 2 to 5,** one commit each, each with its own files. Suggested message for this task: `feat(crewluv): the words for a plane that's out of sight, the plane's own row and the credit to adsb.lol, and an aircraft's name from its type code (Stage 3 spec §8, §9)`.

---

### Task 6: The headline, the rows and the card's sentence

`TripFacts` learns whether its moments are a replay's (`isReplay`), and reads everything where the real plane is.
- **The headline** keeps its order. While the plane is an estimate, "Estimated · last seen …" takes what's below's turn, so the landing countdown never shows then.
- **The rows** gain the plane's row, second. The distance is along the path. "Averaging about" shows only with no live data.
- **The card's sentence** for VoiceOver says where an estimated plane was last seen.

**Files:**
- Modify: `Crewluv/Services/TripMap/Facts/TripFacts.swift`
- Modify: `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`
- Create: `CrewluvTests/LiveTripFactsTests.swift`

- [x] **Step 1: The tests.** Each expected value is worked out in the comment beside it.

Create `CrewluvTests/LiveTripFactsTests.swift`:

```swift
//
//  LiveTripFactsTests.swift
//  CrewluvTests
//
//  The headline, the rows and the card's sentence for a flight with a real plane (Stage 3 spec §8, §9, §15), in US
//  English for a family in Louisville. The made-up real plane is `FactsTestData`'s: a degree of longitude every
//  8 minutes from 10:15 UTC, so it's at 5° E at 10:55 (6:55 AM in Louisville), 10° E at 11:35 and 14° E at 12:07.
//  One degree along the equator is 69.09 mi, and the flight is 1,382 mi.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveTripFactsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// The facts of a map of the one flight, with the real plane last seen at `seenUntil` and the map made at `now`.
    private func facts(seenUntil: String, now: String? = nil, unseen: ClosedRange<Double>? = nil, landed: Bool = false,
                       hasStory: Bool = true, isReplay: Bool = false, typeCode: String? = "B763",
                       registration: String? = "N370UP") throws -> TripFacts {
        let landedAt = landed ? FactsTestData.liveTime(atLongitude: 20) : nil
        let live = FactsTestData.equatorLive(seenUntil: at(seenUntil), unseen: unseen, landedAt: landedAt,
                                             typeCode: typeCode, registration: registration)
        return try facts(of: try FactsTestData.equatorLiveLeg(live, at: at(now ?? seenUntil)), hasStory: hasStory, isReplay: isReplay)
    }

    private func facts(of leg: MapLeg, hasStory: Bool = true, isReplay: Bool = false) throws -> TripFacts {
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: hasStory ? FactsTestData.equator : nil, comparisons: try FactsTestData.appComparisons(),
                         stories: hasStory ? [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)] : [:],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], dayNumber: 1, totalDays: 1,
                         calendar: calendar, locale: locale, isReplay: isReplay)
    }

    private func row(_ kind: FactRow.Kind, in rows: [FactRow]) throws -> FactRow {
        try XCTUnwrap(rows.first { $0.kind == kind }, "no \(kind) row")
    }

    // MARK: - The headline (§8, §9)

    func test_headline_isWhatsBelowTheRealPlane_notTheSchedules() throws {
        // At 11:10 the real plane is at 6.875° E, 64 mi from Testville. The schedule's is at 6.1° E, beside it.
        XCTAssertEqual(try facts(seenUntil: "11:10").headline(at: at("11:10")), "Over Bravo")
        let scheduled = try facts(of: FactsTestData.equatorFlight(from: 0, to: 20))
        XCTAssertEqual(scheduled.headline(at: at("11:10")), "Over Bravo, near Testville")
    }

    func test_headline_aCrossing_leadsWhenTheRealPlaneCrosses() throws {
        // It crossed into Bravo at 10:55. The schedule's plane crosses at 11:00.
        XCTAssertEqual(try facts(seenUntil: "10:57").headline(at: at("10:57")), "Just crossed into Bravo")
        XCTAssertEqual(try facts(seenUntil: "10:53").headline(at: at("10:53")), "Over Alpha")
        // At 10:57 the real plane is over Bravo, at 5.25° E. The schedule's is still over Alpha, at 4.7° E.
        let rows = try facts(seenUntil: "10:57").rows(at: at("10:57"), now: at("10:57"))
        XCTAssertEqual(try row(.below, in: rows).title, "Over Bravo")
    }

    func test_headline_whileEstimated_isWhereItWasLastSeen() throws {
        // Last seen at 6.875° E ten minutes ago: no city within 40 mi.
        XCTAssertEqual(try facts(seenUntil: "11:10", now: "11:20").headline(at: at("11:20")), "Estimated · last seen over Bravo")
        // Last seen at 6° E, 21 mi from Testville.
        XCTAssertEqual(try facts(seenUntil: "11:03", now: "11:13").headline(at: at("11:13")), "Estimated · last seen near Testville")
    }

    func test_headline_whileEstimated_withNoPlaceKnown_isHowLongAgo_neverTheCountdown() throws {
        let facts = try facts(seenUntil: "11:10", now: "11:20", hasStory: false)
        XCTAssertEqual(facts.headline(at: at("11:20")), "Estimated · last seen 10 min ago")
    }

    func test_headline_whileEstimated_keepsItsOrder() throws {
        // Last seen at 9.375° E at 11:30. By its estimate it's halfway at 11:35: a milestone still leads for five
        // minutes, and then where it was last seen takes what's below's place.
        let facts = try facts(seenUntil: "11:30", now: "11:37")
        XCTAssertEqual(facts.headline(at: at("11:37")), "Halfway!")
        XCTAssertEqual(facts.headline(at: at("11:41")), "Estimated · last seen over Bravo")
    }

    func test_headline_whileEstimated_tellsNoCrossingNobodySaw() throws {
        // Last seen at 4.375° E at 10:50. By 11:00 its estimate is past the border at 5° E, and nobody saw it cross.
        XCTAssertEqual(try facts(seenUntil: "10:50", now: "11:00").headline(at: at("11:00")), "Estimated · last seen over Alpha")
    }

    func test_headline_inAReplay_isWhereTheRecordHasThePlane() throws {
        let facts = try facts(seenUntil: "11:10", isReplay: true)
        XCTAssertEqual(facts.headline(at: at("10:35")), "Over Alpha", "2.5° E at 10:35")
        XCTAssertEqual(facts.headline(at: at("11:25")), "Estimated · last seen over Bravo", "past where it was last seen")
    }

    // MARK: - The rows (§8)

    func test_rows_inTheAir_haveThePlanesRowSecond() throws {
        let rows = try facts(seenUntil: "11:10").rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(rows.map(\.kind), [.below, .plane, .distance, .headed])

        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Over Bravo")
        XCTAssertEqual(plain(below.detail), "Passes 35 mi from home at about 8:07 AM", "14° E is still ahead: its time is the estimate")

        let plane = try row(.plane, in: rows)
        XCTAssertEqual(plane.title, "Boeing 767-300 · N370UP")
        XCTAssertEqual(plane.detail, "36,000 ft · 520 mph", "450 kt")
        XCTAssertEqual(plane.symbolName, "airplane")
        XCTAssertEqual(plane.sentence, "Boeing 767-300 · N370UP. 36,000 ft, 520 mph")

        // 6.875° is 475 mi, of 1,382. No "Averaging about": that's the schedule's speed.
        let distance = try row(.distance, in: rows)
        XCTAssertEqual(distance.title, "475 mi flown · 907 to go")
        XCTAssertEqual(plain(distance.detail), "Halfway at about 7:35 AM · like driving the Alaska Highway")

        // 788 nm to go: the last 120 at 280 kt and the rest at its own 450 is 1 h 55 min, and 7 minutes to the gate.
        XCTAssertEqual(plain(try row(.headed, in: rows).title), "Lands E20 about 9:11 AM")
    }

    func test_rows_whileEstimated_sayWhereItWasLastSeen_andLeaveOutItsHeightAndSpeed() throws {
        let rows = try facts(seenUntil: "11:10", now: "11:20").rows(at: at("11:20"), now: at("11:20"))
        XCTAssertEqual(try row(.below, in: rows).title, "Estimated · last seen over Bravo")

        let plane = try row(.plane, in: rows)
        XCTAssertEqual(plane.title, "Boeing 767-300 · N370UP")
        XCTAssertNil(plane.detail)

        // Ten more minutes at 450 kt from 6.875° E is 8.125° E: 561 mi.
        XCTAssertEqual(try row(.distance, in: rows).title, "561 mi flown · 821 to go")
    }

    func test_rows_inAReplay_haveNoHeightOrSpeed() throws {
        let rows = try facts(seenUntil: "11:10", isReplay: true).rows(at: at("10:35"), now: at("11:10"))
        let plane = try row(.plane, in: rows)
        XCTAssertEqual(plane.title, "Boeing 767-300 · N370UP")
        XCTAssertNil(plane.detail, "its height and speed are for now only")
        XCTAssertEqual(try row(.below, in: rows).title, "Over Alpha")
        XCTAssertEqual(try row(.distance, in: rows).title, "173 mi flown · 1,209 to go", "2.5° E at 10:35")
    }

    func test_rows_ofAFlightThatHasLanded_haveRealTimes_withNoAbout() throws {
        let facts = try facts(seenUntil: "12:53", now: "12:56", landed: true, isReplay: true)
        let rows = facts.rows(at: at("11:00"), now: at("12:56"))
        XCTAssertEqual(plain(try row(.below, in: rows).detail), "Passes 35 mi from home at 8:07 AM")
        XCTAssertEqual(plain(try row(.distance, in: rows).detail), "Halfway at 7:35 AM · like driving the Alaska Highway")
    }

    func test_rows_theClosestPointToHome_whereNobodySawIt_isLeftOut() throws {
        // Nobody saw it from 13° E to 15° E, where it passed home.
        let rows = try facts(seenUntil: "12:30", unseen: 13...15).rows(at: at("12:30"), now: at("12:30"))
        XCTAssertNil(try row(.below, in: rows).detail)
        // Seen all the way, it's told with its real time.
        let seen = try facts(seenUntil: "12:30").rows(at: at("12:30"), now: at("12:30"))
        XCTAssertEqual(plain(try row(.below, in: seen).detail), "Closest to home was 35 mi at 8:07 AM")
    }

    func test_rows_thePlanesRow_showsAnUnknownTypeAsItself_andLeavesOutWhatsMissing() throws {
        let unknown = try facts(seenUntil: "11:10", typeCode: "ZZZZ").rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(try row(.plane, in: unknown).title, "ZZZZ · N370UP")

        let noRegistration = try facts(seenUntil: "11:10", registration: nil).rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(try row(.plane, in: noRegistration).title, "Boeing 767-300")

        let neither = try facts(seenUntil: "11:10", typeCode: nil, registration: nil).rows(at: at("11:10"), now: at("11:10"))
        let plane = try row(.plane, in: neither)
        XCTAssertEqual(plane.title, "36,000 ft · 520 mph", "what it has leads the row")
        XCTAssertNil(plane.detail)
    }

    func test_rows_withNoLiveData_areTheSchedules_asBefore() throws {
        let rows = try facts(of: try FactsTestData.equatorLiveLeg(nil, at: at("11:10"))).rows(at: at("11:10"), now: at("11:10"))
        XCTAssertEqual(rows.map(\.kind), [.below, .distance, .headed], "no plane's row")
        XCTAssertEqual(try row(.below, in: rows).title, "Over Bravo, near Testville")
        XCTAssertEqual(try row(.distance, in: rows).title, "422 mi flown · 960 to go")
        XCTAssertEqual(plain(try row(.distance, in: rows).detail), "Halfway at 7:45 AM · Averaging about 460 mph · like driving the Alaska Highway")
    }

    // MARK: - The trip so far, and the credit

    func test_tripSoFar_countsTheMilesAlongTheRealPath_andListsRealTimes() throws {
        let tripSoFar = try facts(seenUntil: "11:10").tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights.first?.milestones.map { plain($0) }, ["Crossed into Bravo · 6:55 AM"])
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 475 mi")
    }

    func test_tripSoFar_inAReplay_countsAsFarAsTheRecordHasThePlane() throws {
        let tripSoFar = try facts(seenUntil: "11:10", isReplay: true).tripSoFar(at: at("10:35"))
        XCTAssertEqual(tripSoFar.flights, [], "at 10:35 it hadn't crossed into Bravo yet")
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 173 mi")
    }

    func test_tripSoFar_aCrossingNobodySaw_isNotListed() throws {
        let tripSoFar = try facts(seenUntil: "11:10", unseen: 4...6.5).tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights, [])
    }

    func test_showsLiveData_whenAFlightOfTheTripHasIt() throws {
        XCTAssertTrue(try facts(seenUntil: "11:10").showsLiveData)
        XCTAssertFalse(try facts(of: FactsTestData.equatorFlight(from: 0, to: 20)).showsLiveData)
        XCTAssertFalse(try facts(of: try FactsTestData.equatorLiveLeg(nil, at: at("11:10"))).showsLiveData)
    }

    // MARK: - The card for VoiceOver (§9, §15)

    func test_cardSummary_inTheAir_saysWhatsBelowTheRealPlane() throws {
        // It lands at 13:05 by its estimate, where the plan has 13:15.
        XCTAssertEqual(plain(try facts(seenUntil: "11:10").cardSummary(now: at("11:10"), pilotName: "Alex")),
                       "TST1 to E20, 10 minutes ahead of schedule, over Bravo. Lands about 9:11 AM your time.")
    }

    func test_cardSummary_whileEstimated_saysAbout_andWhereItWasLastSeen() throws {
        XCTAssertEqual(plain(try facts(seenUntil: "11:10", now: "11:20").cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last seen over Bravo. Lands about 9:11 AM your time.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:03", now: "11:13").cardSummary(now: at("11:13"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last seen near Testville. Lands about 9:11 AM your time.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:10", now: "11:20", hasStory: false).cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last seen 10 minutes ago. Lands about 9:11 AM your time.")
    }
}
```

- [x] **Step 2: The headline, what's below, and the card's sentence.**

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
//  Everything the facts say about a trip at a moment (Stage 2 spec §3.1, §4.4, §5): the headline, the rows
//  (TripFacts+Rows.swift), the trip so far and the recap's numbers. Each answer is a lookup in the flights' stories and
//  sun events, so replay and scrubbing need nothing extra (§4.10).
```

with:

```swift
//  Everything the facts say about a trip at a moment (Stage 2 spec §3.1, §4.4, §5): the headline, the rows
//  (TripFacts+Rows.swift), the trip so far and the recap's numbers. Each answer is a lookup in the flights' stories and
//  sun events, so replay and scrubbing need nothing extra (§4.10). A flight with a real plane is read where the real
//  plane is, along the path it really flew (Stage 3 spec §8).
```

Replace:

```swift
    var calendar: Calendar = .current
    var locale: Locale = .current
```

with:

```swift
    var calendar: Calendar = .current
    var locale: Locale = .current
    /// The moments asked about are a replay's, not now: the full-screen map's clock isn't live. A real plane is
    /// then where its record has it, and what only its newest fix tells is left out (Stage 3 spec §7.3).
    var isReplay = false
```

Replace:

```swift
    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. Nil on the ground and on a drive, where Stage 1's words stay.
```

with:

```swift
    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. While the real plane is an estimate, where it was last seen takes the
    /// place below's turn (Stage 3 spec §9). Nil on the ground and on a drive, where Stage 1's words stay.
```

Replace:

```swift
    /// "Over Kansas", "Over Québec, near Montréal", from the flight's story.
    func belowText(on leg: MapLeg, at date: Date) -> String? {
        guard let place = stories[leg.id]?.place(atFraction: leg.progress(at: date)) else { return nil }
        return FactsWording.below(place, near: geography?.city(near: leg.position(at: date)))
    }
```

with:

```swift
    /// "Over Kansas", "Over Québec, near Montréal", from the flight's story, read where the plane is. While the
    /// real plane is an estimate, "Estimated · last seen near Montréal" (Stage 3 spec §8).
    func belowText(on leg: MapLeg, at date: Date) -> String? {
        let plane = leg.plane(at: date, isReplay: isReplay)
        if let unseenFor = plane.unseenFor {
            return FactsWording.estimated(lastSeen: lastSeen(on: leg, ago: unseenFor))
        }
        guard let place = stories[leg.id]?.place(atDistance: plane.distance) else { return nil }
        return FactsWording.below(place, near: geography?.city(near: plane.coordinate))
    }

    /// Where an estimated plane was last seen: the city by it, else the place under it, else how long ago.
    func lastSeen(on leg: MapLeg, ago: TimeInterval, isSpoken: Bool = false) -> String {
        let path = leg.path
        return FactsWording.lastSeen(stories[leg.id]?.place(atDistance: path.flownLength),
                                     near: geography?.city(near: path.point(atDistance: path.flownLength)),
                                     ago: ago, isSpoken: isSpoken)
    }

    /// Whether a flight with live data shows, which adsb.lol is credited for (Stage 3 spec §8).
    var showsLiveData: Bool {
        tripMap.legs.contains(where: \.hasLiveData)
    }
```

Replace:

```swift
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents)
        return TripSoFar(flights: flights, totalsTitle: "Trip so far",
```

with:

```swift
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents, isReplay: isReplay)
        return TripSoFar(flights: flights, totalsTitle: "Trip so far",
```

Replace:

```swift
                let below = stories[leg.id]?.place(atFraction: leg.progress(at: now))?.name
                // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9).
                if let live = TripMapWording.liveSummary(for: leg, over: below, now: now, calendar: calendar, locale: locale) {
                    return live
                }
```

with:

```swift
                let plane = leg.plane(at: now, isReplay: isReplay)
                let below = stories[leg.id]?.place(atDistance: plane.distance)?.name
                // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9), and
                // while it's an estimate, where it was last seen (§15).
                let lastSeen = plane.unseenFor.map { lastSeen(on: leg, ago: $0, isSpoken: true) }
                if let live = TripMapWording.liveSummary(for: leg, over: below, lastSeen: lastSeen, now: now,
                                                         calendar: calendar, locale: locale) {
                    return live
                }
```

- [x] **Step 3: The rows.**

In `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`:

Replace:

```swift
//  The facts sheet's rows (Stage 2 spec §5): in flight, "now, then where to"; on a layover, where they are, the next
//  flight and the trip so far; at home, the trip ahead and its forecast; after a recap's trip, the trip. A row with
//  nothing to say is left out.
```

with:

```swift
//  The facts sheet's rows (Stage 2 spec §5): in flight, "now, then where to"; on a layover, where they are, the next
//  flight and the trip so far; at home, the trip ahead and its forecast; after a recap's trip, the trip. A row with
//  nothing to say is left out. A flight with live data has the plane's row second (Stage 3 spec §8).
```

Replace:

```swift
    private func flightRows(on leg: MapLeg, at date: Date, now: Date) -> [FactRow] {
        [belowRow(on: leg, at: date), skyRow(on: leg, at: date), distanceRow(on: leg, at: date), headedRow(on: leg, now: now)]
            .compactMap { $0 }
    }

    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let closest = stories[leg.id]?.closestToHome.flatMap { closest in
            leg.time(atFraction: closest.fraction).map {
                FactsWording.closestToHome(miles: Milestone.roundedMiles(closest.meters), at: $0, now: date, calendar: calendar, locale: locale)
            }
        }
        if let place = belowText(on: leg, at: date) {
            return FactRow(.below, symbol: "mappin.and.ellipse", title: place, details: [closest])
        }
        return closest.map { FactRow(.below, symbol: "mappin.and.ellipse", title: $0) }
    }
```

with:

```swift
    private func flightRows(on leg: MapLeg, at date: Date, now: Date) -> [FactRow] {
        let plane = leg.plane(at: date, isReplay: isReplay)
        return [belowRow(on: leg, at: date), planeRow(on: leg, plane: plane), skyRow(on: leg, at: date),
                distanceRow(on: leg, plane: plane, at: date), headedRow(on: leg, now: now)]
            .compactMap { $0 }
    }

    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let closest = closestToHomeLine(on: leg, at: date)
        if let place = belowText(on: leg, at: date) {
            return FactRow(.below, symbol: "mappin.and.ellipse", title: place, details: [closest])
        }
        return closest.map { FactRow(.below, symbol: "mappin.and.ellipse", title: $0) }
    }

    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed. On a real
    /// path it's told only where the plane was seen, or as what's still ahead of it, with "about": where nobody saw
    /// the plane, the join is a guess (Stage 3 spec §8).
    private func closestToHomeLine(on leg: MapLeg, at date: Date) -> String? {
        guard let story = stories[leg.id], let closest = story.closestToHome else { return nil }
        let distance = closest.fraction * story.length
        guard let time = leg.time(atDistance: distance) else { return nil }
        let isAhead = leg.isTimeEstimated(atDistance: distance)
        guard leg.isSeen(atDistance: distance) || (isAhead && time > date) else { return nil }
        return FactsWording.closestToHome(miles: Milestone.roundedMiles(closest.meters), at: time, now: date,
                                          isEstimate: isAhead, calendar: calendar, locale: locale)
    }

    /// The plane's row, for a flight Crewlu Cloud has seen (Stage 3 spec §8): "Boeing 767-300 · N370UP", then
    /// "35,000 ft · 540 mph" while the plane is seen in the air. Its height and speed are for now only, so a
    /// replay and an estimated plane have the first line alone.
    private func planeRow(on leg: MapLeg, plane: PlanePosition) -> FactRow? {
        guard let fix = leg.flight?.live?.fix else { return nil }
        let flying = plane.isSeenInAir
            ? FactsWording.heightAndSpeed(altitudeFeet: fix.altitudeFeet, groundSpeedKnots: fix.groundSpeedKnots, locale: locale)
            : nil
        let parts = [FactsWording.aircraft(typeCode: fix.typeCode, registration: fix.registration), flying].compactMap { $0 }
        guard let title = parts.first else { return nil }
        return FactRow(.plane, symbol: "airplane", title: title, details: Array(parts.dropFirst()))
    }
```

Replace:

```swift
            symbol = SkyFacts.sunAltitude(on: leg, at: date) > SkyFacts.cockpitHorizon ? "sun.max.fill" : "moon.stars.fill"
```

with:

```swift
            symbol = SkyFacts.sunAltitude(on: leg, at: date) > SkyFacts.cockpitHorizon(for: leg) ? "sun.max.fill" : "moon.stars.fill"
```

Replace:

```swift
    private func distanceRow(on leg: MapLeg, at date: Date) -> FactRow {
        let totalMiles = leg.distance / GreatCircle.metersPerMile
        let flown = Int((totalMiles * leg.progress(at: date)).rounded())
        let halfway = leg.time(atFraction: 0.5).flatMap { $0 > date ? FactsWording.halfway(at: $0, calendar: calendar, locale: locale) : nil }
        let speed = FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end)
            .map { FactsWording.averageSpeed(milesPerHour: totalMiles / ($0.duration / 3600)) }
```

with:

```swift
    /// "1,140 mi flown · 3,010 to go": flown along the path so far, and to go along the rest of it, which for a
    /// real plane is the great circle from where it is to the arrival airport (Stage 3 spec §8).
    private func distanceRow(on leg: MapLeg, plane: PlanePosition, at date: Date) -> FactRow {
        let totalMiles = leg.pathLength / GreatCircle.metersPerMile
        let flown = Int((plane.distance / GreatCircle.metersPerMile).rounded())
        let halfway = leg.halfwayTime.flatMap {
            $0 > date ? FactsWording.halfway(at: $0, isEstimate: leg.isTimeEstimated(atDistance: leg.pathLength / 2),
                                             calendar: calendar, locale: locale) : nil
        }
        // The schedule's speed is told only of a flight with no live data: a real plane's row has its own.
        let speed = leg.hasLiveData ? nil : FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end)
            .map { FactsWording.averageSpeed(milesPerHour: totalMiles / ($0.duration / 3600)) }
```

Replace:

```swift
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents)
        guard let line = FactsWording.soFar(totals, dayNumber: dayNumber, totalDays: totalDays, locale: locale) else { return nil }
```

with:

```swift
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents, isReplay: isReplay)
        guard let line = FactsWording.soFar(totals, dayNumber: dayNumber, totalDays: totalDays, locale: locale) else { return nil }
```

- [ ] **Step 4: Ask to commit,** after batch B's checkpoint (Task 7). Suggested message: `feat(crewluv): the facts read where the real plane is: what's below it, where it was last seen while it's out of sight, its own row, and the miles along its path (Stage 3 spec §8, §9, §15)`.

---

### Task 7: The store

`LegStoryStore` is replaced whole. What changes:
- **A flight with a real path has a story of its own,** by its leg's id, made again when the path changes. If the path changes within a minute of the last story, `prepare` waits the rest of the minute first. The views start `prepare` again with `.task(id:)` when the path changes, which ends a wait under way.
- **Sun events are kept one set to a flight.** `facts(for:)` hands on what the flight has, whatever times it was worked out for, and `prepare` replaces it. So the sky row and the trip's sunset count don't blink at each new landing estimate, and the store no longer grows by an entry at each one.
- **`preparationKey` changes when a real path does:** a new place seen, a new landing estimate, or another height.
- **Its clock and its wait are handed in,** so the tests need neither.

**Files:**
- Replace: `Crewluv/Services/TripMap/Facts/LegStoryStore.swift`
- Modify: `CrewluvTests/LegStoryStoreTests.swift`

- [x] **Step 1: The tests.** One test is rewritten: it held that a flight's sun events vanish when its times change, which is the blink this task takes away.

In `CrewluvTests/LegStoryStoreTests.swift`:

Replace:

```swift
    func test_prepare_aNewDelay_keepsTheRouteButRedoesTheSun() async throws {
        let store = makeStore()
        await store.prepare(try europe())
        let delayed = try europe(firstDelayMinutes: 90)

        let before = store.facts(for: delayed)
        XCTAssertNotNil(before.stories["f1"], "same route")
        XCTAssertNil(before.sunEvents["f1"], "new times")

        await store.prepare(delayed)
        XCTAssertNotNil(store.facts(for: delayed).sunEvents["f1"])
    }
```

with:

```swift
    func test_prepare_aNewDelay_keepsTheRoute_andShowsTheSunEventsItHasUntilTheNewAreReady() async throws {
        let store = makeStore()
        let onTime = try europe()
        await store.prepare(onTime)
        let sunset = try XCTUnwrap(store.facts(for: onTime).sunEvents["f1"]?.first)
        let delayed = try europe(firstDelayMinutes: 90)

        // Nothing blinks: what it has shows while the new times' events are worked out.
        let before = store.facts(for: delayed)
        XCTAssertNotNil(before.stories["f1"], "same route")
        XCTAssertEqual(before.sunEvents["f1"], [sunset], "the old times', for a moment")

        await store.prepare(delayed)
        let after = try XCTUnwrap(store.facts(for: delayed).sunEvents["f1"]?.first)
        XCTAssertNotEqual(after.time, sunset.time, "the new times'")
    }
```

Replace:

```swift
    func test_routeKey_namesHomeOnlyWhenTheFlightPassesIt() throws {
```

with:

```swift
    // MARK: - A real path (Stage 3 spec §8)

    /// A clock the tests move by hand, and the waits the store asked for.
    private final class TestClock {
        var now = FactsTestData.equinox
        var waits: [TimeInterval] = []
        /// The task that's waiting has been stopped, as when the path changes again.
        var isStopped = false
    }

    private func liveStore(_ clock: TestClock) -> LegStoryStore {
        LegStoryStore(loadFiles: { (FactsTestData.equator, nil) }, now: { clock.now }, sleep: { seconds in
            clock.waits.append(seconds)
            // A store that carries on after its wait was stopped is let through on the fifth, so its test fails
            // instead of hanging.
            if clock.isStopped, clock.waits.count < 5 { throw CancellationError() }
            clock.now = clock.now.addingTimeInterval(seconds)
        })
    }

    /// The equator flight alone, with a real plane that left the great circle and was last seen at `longitude`° E.
    private func liveMap(seenUntil longitude: Double, altitudeFeet: Double = 36_000) throws -> TripMap {
        let seenUntil = FactsTestData.liveTime(atLongitude: longitude)
        let live = FactsTestData.equatorLive(seenUntil: seenUntil, altitudeFeet: altitudeFeet, latitude: FactsTestData.dogLeg)
        let leg = try FactsTestData.equatorLiveLeg(live, at: seenUntil)
        return TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    func test_prepare_aRealPath_hasAStoryOfItsOwn_alongThePath() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let map = try liveMap(seenUntil: 13)
        await store.prepare(map)

        let facts = store.facts(for: map)
        XCTAssertEqual(facts.stories["eq"]?.length, map.legs[0].pathLength)
        XCTAssertGreaterThan(try XCTUnwrap(facts.stories["eq"]).length, map.legs[0].distance, "not the route's, along the great circle")
        XCTAssertNotNil(facts.sunEvents["eq"])
        XCTAssertEqual(clock.waits, [])
    }

    func test_prepare_whenThePathGrowsWithinAMinute_waitsTheMinuteOut_thenMakesTheStoryAgain() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let first = try liveMap(seenUntil: 8)
        await store.prepare(first)

        // A new place 20 seconds later.
        clock.now = clock.now.addingTimeInterval(20)
        let grown = try liveMap(seenUntil: 8.25)
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, first.legs[0].pathLength, "the story it has shows meanwhile")

        await store.prepare(grown)
        XCTAssertEqual(clock.waits, [40], "the rest of the minute")
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, grown.legs[0].pathLength)
    }

    func test_prepare_whenThePathGrowsAMinuteLater_makesTheStoryAtOnce() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        await store.prepare(try liveMap(seenUntil: 8))

        clock.now = clock.now.addingTimeInterval(60)
        let grown = try liveMap(seenUntil: 9)
        await store.prepare(grown)
        XCTAssertEqual(clock.waits, [])
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, grown.legs[0].pathLength)
    }

    func test_prepare_stoppedWhileItWaits_makesNothing_andTheNextOneDoes() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let first = try liveMap(seenUntil: 8)
        await store.prepare(first)

        clock.now = clock.now.addingTimeInterval(20)
        clock.isStopped = true
        let grown = try liveMap(seenUntil: 8.25)
        await store.prepare(grown)
        XCTAssertEqual(clock.waits, [40])
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, first.legs[0].pathLength, "still the story it had")

        // The path changes again, which starts `prepare` afresh: it waits what's left of the minute.
        clock.isStopped = false
        clock.now = clock.now.addingTimeInterval(10)
        let grownAgain = try liveMap(seenUntil: 8.5)
        await store.prepare(grownAgain)
        XCTAssertEqual(clock.waits, [40, 30])
        XCTAssertEqual(store.facts(for: grownAgain).stories["eq"]?.length, grownAgain.legs[0].pathLength)
    }

    func test_prepare_theSamePathAgain_makesNothing() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let map = try liveMap(seenUntil: 8)
        await store.prepare(map)
        clock.now = clock.now.addingTimeInterval(5)
        await store.prepare(try liveMap(seenUntil: 8))
        XCTAssertEqual(clock.waits, [], "nothing to wait for: the path is the one its story was made from")
    }

    func test_facts_aFlightBackOnTheSchedule_hasItsRoutesStoryAgain() async throws {
        // Its live data is gone, as after Disconnect: the leg flies the great circle again.
        let clock = TestClock()
        let store = liveStore(clock)
        await store.prepare(try liveMap(seenUntil: 13))

        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let scheduled = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        await store.prepare(scheduled)
        XCTAssertEqual(store.facts(for: scheduled).stories["eq"]?.length, leg.distance)
    }

    func test_prepare_aFlightBackOnItsRealPath_afterATurnOnTheSchedule_hasItsOwnSunEventsAgain() async throws {
        // The equator flight seven hours later, into the evening: the real plane and the schedule's each see the
        // sun set, at different times. Its live data goes, and comes back with the very same path.
        let evening: TimeInterval = 7 * 3600
        let flown = FactsTestData.equatorLive(seenUntil: FactsTestData.liveTime(atLongitude: 13))
        let fix = try XCTUnwrap(flown.fix)
        let live = LiveFlight(
            legID: flown.legID, callsign: flown.callsign, state: flown.state,
            fix: LiveFlight.Fix(latitude: fix.latitude, longitude: fix.longitude, altitudeFeet: fix.altitudeFeet,
                                groundSpeedKnots: fix.groundSpeedKnots, trackDegrees: fix.trackDegrees, isOnGround: false,
                                registration: fix.registration, typeCode: fix.typeCode, seenAt: fix.seenAt.addingTimeInterval(evening)),
            landedAt: nil,
            trail: flown.trail.map {
                LiveFlight.TrailPoint(time: $0.time.addingTimeInterval(evening), latitude: $0.latitude, longitude: $0.longitude,
                                      altitudeFeet: $0.altitudeFeet)
            })
        func map(_ live: LiveFlight?) throws -> TripMap {
            let scheduled = FactsTestData.equatorFlight(from: 0, to: 20, departure: FactsTestData.equinox.addingTimeInterval(evening))
            let flight = try XCTUnwrap(MapFlight(departure: scheduled.start, arrival: scheduled.end, from: scheduled.origin.coordinate,
                                                 to: scheduled.destination.coordinate, live: live))
            let progress = flight.progress(at: fix.seenAt.addingTimeInterval(evening))
            let leg = MapLeg(id: scheduled.id, kind: .flight, origin: scheduled.origin, destination: scheduled.destination,
                             start: progress.start, end: progress.end, flightNumber: scheduled.flightNumber, flight: flight)
            return TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        }
        let clock = TestClock()
        let store = liveStore(clock)

        await store.prepare(try map(live))
        let real = try XCTUnwrap(store.facts(for: try map(live)).sunEvents["eq"])
        XCTAssertEqual(real.map(\.kind), [.sunset])

        await store.prepare(try map(nil))
        let planned = try XCTUnwrap(store.facts(for: try map(nil)).sunEvents["eq"])
        XCTAssertNotEqual(planned.first?.time, real.first?.time, "the schedule's plane is elsewhere when the sun sets")

        clock.now = clock.now.addingTimeInterval(5)
        await store.prepare(try map(live))
        XCTAssertEqual(store.facts(for: try map(live)).sunEvents["eq"], real, "its own again, not the schedule's")
        XCTAssertEqual(clock.waits, [], "and at once: it's a flight newly seen")
    }

    func test_prepare_whenTheClockWasSetBack_doesntHoldTheStoryUp() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        await store.prepare(try liveMap(seenUntil: 8))

        // The phone's clock goes back five minutes. The last story now looks as if it were made in the future.
        clock.now = clock.now.addingTimeInterval(-300)
        let grown = try liveMap(seenUntil: 8.25)
        await store.prepare(grown)
        XCTAssertEqual(clock.waits, [])
        XCTAssertEqual(store.facts(for: grown).stories["eq"]?.length, grown.legs[0].pathLength)
    }

    func test_facts_handOnWhetherItsAReplay() throws {
        XCTAssertFalse(makeStore().facts(for: try europe()).isReplay)
        XCTAssertTrue(makeStore().facts(for: try europe(), isReplay: true).isReplay)
    }

    func test_preparationKey_changesWhenARealPathGrows_orItsSkyIsSeenFromAnotherHeight() throws {
        let key = LegStoryStore.preparationKey(for: try liveMap(seenUntil: 8))
        XCTAssertEqual(key, LegStoryStore.preparationKey(for: try liveMap(seenUntil: 8)))
        XCTAssertNotEqual(key, LegStoryStore.preparationKey(for: try liveMap(seenUntil: 8.25)))
        XCTAssertNotEqual(key, LegStoryStore.preparationKey(for: try liveMap(seenUntil: 8, altitudeFeet: 38_000)))
    }

    func test_pathKey_isOnlyForAFlightWithARealPath() throws {
        XCTAssertNil(LegStoryStore.pathKey(for: FactsTestData.equatorFlight(from: 0, to: 20)))
        XCTAssertNil(LegStoryStore.pathKey(for: try FactsTestData.equatorLiveLeg(nil, at: FactsTestData.equinox)))
        XCTAssertNotNil(LegStoryStore.pathKey(for: try liveMap(seenUntil: 8).legs[0]))
    }

    func test_routeKey_namesHomeOnlyWhenTheFlightPassesIt() throws {
```

- [x] **Step 2: The store.**

Replace the whole of `Crewluv/Services/TripMap/Facts/LegStoryStore.swift` with:

```swift
//
//  LegStoryStore.swift
//  CrewLuve
//
//  Builds each flight's story and sun events off the main actor, and keeps them (Stage 2 spec §3.2, Stage 3 spec §8).
//  The status screen owns one and hands it to the card and the full-screen map, so both read the same facts.
//  - A flight on the schedule has its route's story, since the screen rebuilds its TripMap on every render, and its
//    sun events by its delay-shifted times.
//  - A flight with a real path has a story of its own, made again as the path grows, at most once a minute, with
//    its sun events.
//  What a flight already has shows until the next is ready, so nothing blinks while it's worked out.
//

import Foundation
import Observation

@Observable
@MainActor
final class LegStoryStore {

    typealias FileLoader = @Sendable () -> (geography: Geography?, comparisons: ComparisonPicker?)

    /// A flight with a real path gets its story again no sooner than this after the last one was started
    /// (Stage 3 spec §8).
    nonisolated static let pathStoryInterval: TimeInterval = 60

    private let loadFiles: FileLoader
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: (TimeInterval) async throws -> Void
    /// The one load of the data files, shared by every `prepare` that's waiting for it.
    @ObservationIgnored private var filesTask: Task<(geography: Geography?, comparisons: ComparisonPicker?), Never>?
    @ObservationIgnored private var hasLoadedFiles = false
    private var geography: Geography?
    private var comparisons: ComparisonPicker?
    private var storiesByRoute: [String: LegStory] = [:]
    /// The story of each flight with a real path, by leg id.
    private var storiesByPath: [String: LegStory] = [:]
    /// Each flight's sun events, by leg id: one set a flight, replaced when its times or its path change.
    private var sunEventsByLeg: [String: [SkyFacts.SunEvent]] = [:]
    /// What each flight's sun events were last worked out from, by leg id.
    @ObservationIgnored private var sunKeys: [String: String] = [:]
    /// The newest path each flight's story was started for, by leg id, and when.
    @ObservationIgnored private var pathBuilds: [String: (key: String, at: Date)] = [:]

    /// - Parameters:
    ///   - loadFiles: reads geography.json and comparisons.json; the app's bundled copies unless a test says.
    ///   - now: this device's clock.
    ///   - sleep: waits that many seconds, and throws if its task is cancelled meanwhile.
    init(
        loadFiles: @escaping FileLoader = { (Geography.loadBundled(), ComparisonPicker.loadBundled()) },
        now: @escaping () -> Date = { Date() },
        sleep: @escaping (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.loadFiles = loadFiles
        self.now = now
        self.sleep = sleep
    }

    /// Builds whatever `tripMap`'s flights are missing. Anything already built is kept, so calling it again is cheap.
    /// A real path that grew within a minute of its last story waits the minute out first: the views start
    /// `prepare` again with `.task(id:)` when the path changes, which ends the wait.
    func prepare(_ tripMap: TripMap) async {
        await loadFilesOnce()
        let home = tripMap.home
        let flights = tripMap.legs.filter { $0.kind == .flight }
        while !Task.isCancelled {
            let work = claimWork(for: flights, home: home, at: now())
            await build(work, home: home)
            guard let wait = work.wait else { return }
            do { try await sleep(wait) } catch { return }
        }
    }

    /// The facts for `tripMap` from what's built so far.
    /// - Parameter isReplay: the moments asked about are a replay's, not now.
    func facts(for tripMap: TripMap, forecasts: [String: LandingForecast] = [:], dayNumber: Int? = nil, totalDays: Int? = nil,
               isReplay: Bool = false) -> TripFacts {
        var stories: [String: LegStory] = [:]
        var sunEvents: [String: [SkyFacts.SunEvent]] = [:]
        for leg in tripMap.legs where leg.kind == .flight {
            let route = storiesByRoute[Self.routeKey(for: leg, home: tripMap.home)]
            // A real path has its own story. Until the first is ready the route's stands in, where the flight had
            // one from before it was seen: it's read by distance, which is near enough where a real path begins.
            stories[leg.id] = Self.pathKey(for: leg) == nil ? route : storiesByPath[leg.id] ?? route
            sunEvents[leg.id] = sunEventsByLeg[leg.id]
        }
        return TripFacts(tripMap: tripMap, geography: geography, comparisons: comparisons, stories: stories,
                         sunEvents: sunEvents, forecasts: forecasts, dayNumber: dayNumber, totalDays: totalDays,
                         isReplay: isReplay)
    }

    /// The route, and home when the flight passes it by: home changes the closest-point fact.
    nonisolated static func routeKey(for leg: MapLeg, home: AirportMark?) -> String {
        let route = "\(leg.origin.code)-\(leg.destination.code)"
        guard let home, home.code != leg.origin.code, home.code != leg.destination.code else { return route }
        return "\(route)|\(home.code)"
    }

    /// What `prepare` builds from: each leg's route and delay-shifted times, its real path where it has one, and
    /// home. The views start `prepare` again with `.task(id:)` whenever it changes.
    nonisolated static func preparationKey(for tripMap: TripMap) -> [String] {
        tripMap.legs.map { leg in [timesKey(for: leg), pathKey(for: leg)].compactMap { $0 }.joined(separator: "|") }
            + [tripMap.home?.code ?? ""]
    }

    /// The flight, its route and its delay-shifted times: a new delay moves the sun events.
    nonisolated static func timesKey(for leg: MapLeg) -> String {
        "\(leg.id)|\(leg.origin.code)-\(leg.destination.code)|\(leg.start.timeIntervalSince1970)|\(leg.end.timeIntervalSince1970)"
    }

    /// What tells one state of a flight's real path from the next, or nil for a flight without one: the places it
    /// was seen, its landing, real or estimated, and the height its sky is seen from. Its story and its sun events
    /// are made from these, so they're made again when it changes.
    nonisolated static func pathKey(for leg: MapLeg) -> String? {
        guard let flight = leg.flight, let record = flight.record else { return nil }
        let path = flight.path
        return [leg.id, "\(path.knots.count)", "\(path.flownLength)", "\(path.length)", "\(path.hasLanded)",
                "\(record.touchdown.timeIntervalSince1970)", "\(SkyFacts.cockpitHorizon(for: leg))"].joined(separator: "|")
    }

    // MARK: - Private

    /// What one pass of `prepare` builds, and how long until the next has something to build.
    private struct Work {
        /// One leg for each route with no story yet, even when the trip flies it twice.
        var routes: [String: MapLeg] = [:]
        /// Each flight whose real path changed, with the path's key.
        var paths: [(key: String, leg: MapLeg)] = []
        /// Each flight on the schedule whose times changed, with their key.
        var timed: [(key: String, leg: MapLeg)] = []
        /// The seconds until a real path that grew too soon after its last story can have its next.
        var wait: TimeInterval?

        var isEmpty: Bool { routes.isEmpty && paths.isEmpty && timed.isEmpty }
    }

    /// What `flights` are missing at `now`. Each thing to build is claimed here, before any waiting, so a second
    /// `prepare` running beside this one doesn't build it too.
    private func claimWork(for flights: [MapLeg], home: AirportMark?, at now: Date) -> Work {
        var work = Work()
        for leg in flights {
            guard let pathKey = Self.pathKey(for: leg) else {
                // Back on the schedule, as when its live data goes: should the same path come back, its story
                // and its sun events are made afresh.
                pathBuilds[leg.id] = nil
                let route = Self.routeKey(for: leg, home: home)
                if storiesByRoute[route] == nil, work.routes[route] == nil { work.routes[route] = leg }
                let times = Self.timesKey(for: leg)
                if sunKeys[leg.id] != times {
                    sunKeys[leg.id] = times
                    work.timed.append((times, leg))
                }
                continue
            }
            guard pathBuilds[leg.id]?.key != pathKey else { continue }
            // A clock that was set back doesn't hold a story up: only a build in the last minute does.
            if let last = pathBuilds[leg.id], (0..<Self.pathStoryInterval).contains(now.timeIntervalSince(last.at)) {
                let left = Self.pathStoryInterval - now.timeIntervalSince(last.at)
                work.wait = min(work.wait ?? left, left)
                continue
            }
            pathBuilds[leg.id] = (pathKey, now)
            sunKeys[leg.id] = pathKey
            work.paths.append((pathKey, leg))
        }
        return work
    }

    /// Builds `work` off the main actor, and keeps what comes back.
    private func build(_ work: Work, home: AirportMark?) async {
        guard !work.isEmpty else { return }
        let geography = self.geography
        let built = await Task.detached(priority: .utility) {
            (routes: work.routes.map { key, leg in (key, LegStory(leg: leg, geography: geography, home: home)) },
             paths: work.paths.map { ($0.key, $0.leg.id, LegStory(leg: $0.leg, geography: geography, home: home)) },
             sunEvents: (work.timed + work.paths).map { ($0.key, $0.leg.id, SkyFacts.sunEvents(on: $0.leg)) })
        }.value
        for (key, story) in built.routes { storiesByRoute[key] = story }
        // Only the newest asked for is kept, should an older one finish last.
        for (key, legID, story) in built.paths where pathBuilds[legID]?.key == key { storiesByPath[legID] = story }
        for (key, legID, events) in built.sunEvents where sunKeys[legID] == key { sunEventsByLeg[legID] = events }
    }

    private func loadFilesOnce() async {
        guard !hasLoadedFiles else { return }
        let loadFiles = self.loadFiles
        let task = filesTask ?? Task.detached(priority: .utility) { loadFiles() }
        filesTask = task
        let files = await task.value
        if !hasLoadedFiles {
            geography = files.geography
            comparisons = files.comparisons
            hasLoadedFiles = true
        }
    }
}
```

- [x] **Step 3: Review batch B.** Dispatch `superpowers:code-reviewer` (sonnet) on Tasks 6 and 7, with the spec's §8, §9 and §15 and this plan's list. Ask it in particular about the store:
  - Is there an order of two `prepare` calls (the card's and the full-screen map's run side by side) that makes a story twice, loses the newest, or leaves one waiting for ever?
  - Can a stopped wait leave a story that's never made?
  - Does anything still read a flight's schedule place where the real plane's is known?

- [x] **Step 4: Checkpoint, batch B.** Todd runs the new class and the classes of the code these tasks changed (120 tests):

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:CrewluvTests/LiveTripFactsTests -only-testing:CrewluvTests/LegStoryStoreTests -only-testing:CrewluvTests/TripFactsTests -only-testing:CrewluvTests/TripFactsRowsTests -only-testing:CrewluvTests/FactsCasesTests -only-testing:CrewluvTests/LiveWordingTests -only-testing:CrewluvTests/TripMapRecapTests -only-testing:CrewluvTests/TripMapWordingTests
```

Expected: every test passes.

- [ ] **Step 5: Ask to commit Tasks 6 and 7,** one commit each. Suggested message for this task: `feat(crewluv): a real path's story is made again as the path grows, at most once a minute, and a flight's sun events show until the next are ready, so the sky row doesn't blink (Stage 3 spec §8)`.

---

### Task 8: The views

No tests: these are SwiftUI. They were type-checked for iOS with the rest of the app. Todd sees them in Task 9.

**Files:**
- Modify: `Crewluv/Views/TripMap/FactsFooter.swift`
- Modify: `Crewluv/Views/TripMap/FactsBody.swift`
- Modify: `Crewluv/Views/TripMap/FactsSheet.swift`
- Modify: `Crewluv/Views/TripMap/FactsPanel.swift`
- Modify: `Crewluv/Views/TripMap/TripMapScreen.swift`

- [x] **Step 1: The credit, under the facts.** One line in the footer of the sheet and of the panel, whenever a flight with live data shows, with a sentence for VoiceOver (§15). It isn't on the card: Todd's answer to question 2.

In `Crewluv/Views/TripMap/FactsFooter.swift`:

Replace:

```swift
//  Under the facts (Stage 2 spec §5.2, §7.2): they're estimated from the schedule, and Apple's Weather mark and legal
//  link whenever a WeatherKit forecast shows.
//

import SwiftUI

struct FactsFooter: View {
    let showsWeather: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimated from the schedule")
                .font(.caption)
                .foregroundStyle(.secondary)
            if showsWeather {
```

with:

```swift
//  Under the facts (Stage 2 spec §5.2, §7.2; Stage 3 spec §8): they're estimated from the schedule, the credit to
//  adsb.lol whenever a flight with live data shows, and Apple's Weather mark and legal link whenever a WeatherKit
//  forecast shows.
//

import SwiftUI

struct FactsFooter: View {
    let showsWeather: Bool
    /// A flight with live data shows: its position is adsb.lol's.
    let showsLiveCredit: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimated from the schedule")
                .font(.caption)
                .foregroundStyle(.secondary)
            if showsLiveCredit {
                Text(FactsWording.liveCredit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(FactsWording.spokenLiveCredit)
            }
            if showsWeather {
```

In `Crewluv/Views/TripMap/FactsBody.swift`:

Replace:

```swift
    let rows: [FactRow]
    let tripSoFar: TripSoFar
```

with:

```swift
    let rows: [FactRow]
    let tripSoFar: TripSoFar
    /// A flight with live data shows, which the footer credits adsb.lol for.
    let showsLiveCredit: Bool
```

Replace:

```swift
            FactsFooter(showsWeather: rows.contains(where: \.hasWeather))
```

with:

```swift
            FactsFooter(showsWeather: rows.contains(where: \.hasWeather), showsLiveCredit: showsLiveCredit)
```

In `Crewluv/Views/TripMap/FactsSheet.swift`:

Replace:

```swift
                    FactsBody(rows: facts.rows(at: time, now: context.date), tripSoFar: facts.tripSoFar(at: time))
```

with:

```swift
                    FactsBody(rows: facts.rows(at: time, now: context.date), tripSoFar: facts.tripSoFar(at: time),
                              showsLiveCredit: facts.showsLiveData)
```

In `Crewluv/Views/TripMap/FactsPanel.swift`:

Replace:

```swift
        FactsBody(rows: facts.rows(at: time, now: now), tripSoFar: facts.tripSoFar(at: time))
```

with:

```swift
        FactsBody(rows: facts.rows(at: time, now: now), tripSoFar: facts.tripSoFar(at: time),
                  showsLiveCredit: facts.showsLiveData)
```

- [x] **Step 2: Tell the facts when the full-screen map shows a replay.** The card needs nothing: it's always now.

In `Crewluv/Views/TripMap/TripMapScreen.swift`:

Replace:

```swift
    private var facts: TripFacts {
        storyStore.facts(for: tripMap, forecasts: weather.forecasts, dayNumber: dayNumber, totalDays: totalDays)
    }
```

with:

```swift
    /// The facts at the clock's moments. They're a replay's while the clock isn't live: a real plane is then where
    /// its record has it, with no height or speed (Stage 3 spec §7.3).
    private var facts: TripFacts {
        storyStore.facts(for: tripMap, forecasts: weather.forecasts, dayNumber: dayNumber, totalDays: totalDays,
                         isReplay: !clock.isLive)
    }
```

- [x] **Step 3: Review batch C.** Dispatch `superpowers:code-reviewer` (sonnet) on Task 8, with the spec's §8 and §15. Ask whether the credit shows under the facts whenever a flight with live data does, whether VoiceOver reads it as a sentence, and whether every place that makes the facts for a replay says so.

- [x] **Step 4: Checkpoint, batch C.** Todd runs every test of the app once:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: every test passes. Todd's last whole run was 970 tests, and this plan adds 95: 1,065 in all. The count is in the result bundle, read with `xcrun xcresulttool get test-results summary --path <bundle>`.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): adsb.lol is credited under the facts whenever a flight with live data shows, and a replay's facts are the replay's (Stage 3 spec §7.3, §8)`.

---

### Task 9: What Todd looks at

Nothing but a look can check these. Todd has said no TestFlight or App Store build goes out until the credit is in, and after Task 8 it is.

**Files:** none, unless something is wrong.

- [ ] **Step 1: The previews,** in Xcode's canvas for `TripMapPreviews.swift`. The three with a made-up real plane now have its facts.
  - On the card, the chip reads what's below the blue plane, not the outlined one. In the preview with the faded plane it reads "Estimated · last seen …". Say if the line is cut off.
  - On the full-screen map, pull the sheet to its middle stop. The second row is the plane's: its type and registration, and under them its height and speed. In the preview with the faded plane, the second line is gone.
  - Scroll to the foot of the sheet: "Live position: adsb.lol" is under "Estimated from the schedule". Say if the two read oddly together.

- [ ] **Step 2: On a real flight,** with the app built from Xcode on a device or a simulator that follows Todd's account as a partner, with that account listed on Crewlu Cloud's switch:
  - **In the air.** The chip's place is under the blue plane. Open a map app beside it if in doubt. The plane's row names the aircraft that's flying it.
  - **A border.** Within a minute or two of the plane crossing a state line or a border, the chip reads "Just crossed into …". The sheet pulled all the way up lists it with its time.
  - **Out of sight** for more than three minutes: the chip and the first row read "Estimated · last seen …", the plane's row loses its height and speed, and no crossing is announced until it's seen again.
  - **The sky row.** Watch it through two or three minutes while the landing time changes. It doesn't vanish and come back.
  - **The distance row.** "Flown" and "to go" add up to about the same total all flight. "Averaging about" isn't there.
  - **The replay.** Drag the timeline back into the flight: the rows are for that moment, and the plane's row has no height or speed. Drag past now: "Estimated · last seen …".
  - **After landing,** the trip's miles count the path really flown. They're a little more than before.
  - **VoiceOver** on the card: one sentence. While the plane is out of sight it says "about" and "last seen".
  - **The credit** is in the footer whenever the trip has a flight with live data.

- [ ] **Step 3: Write down what was wrong.** Anything that needs a change goes in "Changes made during execution", is fixed in its own task's files, and has Todd run that task's tests again.

---

### Task 10: Review, the docs and the record

**Files:**
- Modify: `CLAUDE.md`
- Modify: this plan

- [ ] **Step 1: Review the whole branch.** Dispatch `superpowers:code-reviewer` (sonnet) on this plan's commits, with the spec's §8, §9, §11, §15 and §16.3, and this plan's list of where it differs. Use `superpowers:receiving-code-review` on what comes back.

- [ ] **Step 2: Todd runs every test once more,** with the command of Task 8's checkpoint, if the review changed any code.

- [ ] **Step 3: Update `CLAUDE.md`.** Plan 3B-2's last task writes there too, so read the "#### Trip Map" section first and work from what it holds.

  - If the bullet that begins "The real plane on the map" ends with this sentence, take the sentence out:

```markdown
The facts still follow the great circle, and adsb.lol isn't credited yet: both are plan 3B-3's
```

  - After the bullet that begins "The facts (Stage 2 spec", add:

```markdown
- The facts on the real path (plan `docs/superpowers/plans/2026-11-15-moving-map-stage3b3-app-facts.md`, Stage 3 spec §8). `MapLeg.plane(at:isReplay:)` is where the facts have the plane (`PlanePosition`): the real one wherever the map draws it, by `FlightDrawing`'s rule, which `PlanePositionTests` holds it to. `MapLeg+Course.swift` gives a leg its path and its times, by its record or by the schedule. `MapLeg`'s own `progress(at:)` and `position(at:)` stay the schedule's. `LegStory` is made along the leg's path and read by distance, since a real path grows. A crossing is told only where the plane was seen (`MapLeg.isSeen(atDistance:)`). `LegStoryStore` makes a real path's story again as the path grows, at most once a minute, and keeps one set of sun events to a flight, which shows until the next is ready: don't key them by the leg's times again, or the sky row blinks at each new landing estimate. A plane out of sight reads "Estimated · last seen …". The plane's row is `AircraftTypeNames`' name and the registration, with the height and speed only while the plane is seen in the air now. `TripFacts.isReplay` says the moments are a replay's. adsb.lol is credited under the facts (`FactsFooter`) whenever a flight with live data shows
```

- [ ] **Step 4: Record what changed.** Add "## Changes made during execution" to the end of this plan: each review's changes, what Task 9 turned up, and anything a step did differently. If any of it changes what the spec says, change the spec to match, and say so in the list.

- [ ] **Step 5: Ask to commit.** Suggested message: `docs(crewluv): the facts on the real path in CLAUDE.md, and the Stage 3B-3 plan as it was built`.

- [ ] **Step 6: The release note.** Draft one entry for the Apple Note "Crewluve revisions", in plain words for a pilot's family, under the version and build Todd names. A draft to start from: "The facts now follow the real plane. When your pilot's flight can be seen from the ground, the map tells you what's really below it and when it really crossed a border, and a new row names the aircraft with its height and speed. When the plane is out of sight for a while, the map says where it was last seen." Show Todd the draft and ask before writing it to the note.

---

## Changes made during execution

- **Todd's answers (15 Nov 2026).**
  - The words for a plane that's out of sight stand as written.
  - The credit isn't on the status screen's card, which is too small. The card's task was taken out before anything ran, and the credit's one line went straight into the facts' footer. So there are ten tasks, where the first draft had eleven.
  - The release note's version and build aren't known yet.
  - Run it before the flight of 16 Nov, as soon as possible.
- **Tasks 2 to 8 went in together (15 Nov 2026),** on that last answer, so that one run of every test could stand in for the three batch runs. Each file is the tested one, compared byte for byte after it was put in the repo. The commits are still one to a task.
- **The reviews.** The code was reviewed whole before the plan was put together (see "How this plan was checked"), and that review answered each of batch A's questions. Its three fixes went into the store and the aircraft's names after it had read them, and the store's `prepare` was then split into two smaller functions. So the same reviewer was asked for a second look at the store and the footer before Todd's run.
  - **Its second look: ready, with nothing to fix.** Splitting `prepare` changed nothing it does: every claim is still made before any wait, and a result is still kept only if it's the newest asked for. The check on the clock is right at its edges: a story made exactly a minute ago holds nothing up, and neither does one that looks as if it were made in the future.
  - One thing it noted is in "Left for later": a flight whose live data goes and comes back within a minute has its story made again at once.
  - That stands for the reviews of batches A, B and C. The review of the whole branch (Task 10) is still to come.
- **Todd's run (15 Nov 2026, 9:28 pm EST):** every test of the app, with all of Tasks 2 to 8 in. All 1,065 passed on the iPhone 17 Pro simulator, iOS 26.5: the 970 of the run before this plan, and its 95. The count is from the result bundle, `Test-Crewluv-2026.11.15_21-28-40--0500.xcresult`. The run started after the last file was put in, and the files were compared with the tested ones again after it.

## What the website's plan takes from this one

- **The rules above are the website's too,** so the two stay alike: the list of where this plan differs from the spec applies to `src/facts/` as it stands.
- **Where the plane is:** now, the real plane as the live progress has it. In a replay, where the record has it. Otherwise the schedule's. Flown is `planeAlongNm` of the shared cases, and to go is the path's length less that.
- **The story is read by distance along the path,** and made again as the path grows, at most once a minute.
- **A crossing, or the closest point to home, is told only on a stretch of kind `seen`.** The way ahead, kind `planned`, isn't told until it's flown. Halfway is half the path's whole length, timed by the record.
- **"About"** goes before a halfway or closest-to-home time that's past the last place seen, on a flight that hasn't landed.
- **The sky** follows the record's places and times, from the record's start to its touchdown. The height is the last fix's from 25,000 to 60,000 ft on a flight in the air, else 35,000 ft.
- **The words:** "Estimated · last seen near Montréal", "… over Québec", "… 2 h ago"; "Boeing 767-300 · N370UP"; "35,000 ft · 540 mph" to the nearest 100 ft and 10 mph; "Halfway at about 12:05 PM"; "Passes 40 mi from home at about 1:05 PM"; "Live position: adsb.lol".
- **`AircraftTypeNames`' table** is copied as it is, once its review has checked it.
- **A height outside 0 to 60,000 ft or a speed outside 0 to 800 kt is left out.**
- **The sun events show until the next are ready,** so nothing blinks at a new landing estimate.

## Self-review

- **Spec coverage.**
  - §8, the story along the path, made again as it grows, at most once a minute: Tasks 3 and 7.
  - §8, what's below, in the air and estimated: Tasks 2, 5 and 6.
  - §8, crossings and the closest point to home only where the plane was seen, with the real times: Task 3, and Task 6 for the row.
  - §8, halfway as half the path's whole length, with "about" before it's reached: Tasks 2, 3, 5 and 6.
  - §8, the distance row: Task 6. The plane's row with `AircraftTypeNames`: Tasks 5 and 6.
  - §8, the sky and the sun along the path, with the record's times: Task 4. The height differs from the spec's, as the list above says.
  - §8, weather on landing for the live arrival: already so since plan 3B-2. The schedule-only speed line: Task 6.
  - §8, the trip's totals and the recap along real paths: Task 4.
  - §8, the credit: Tasks 5 and 8.
  - §9, the headline chip's order, and the card's sentence: Task 6. The other words of §9 are plan 3B-2's.
  - §11, `LegStory` and `LegStoryStore`: Tasks 3 and 7. `FactsWording` and `FactsFooter`: Tasks 5 and 8. `AircraftTypeNames`: Task 5.
  - §15, the card's sentence while estimated, and the plane's row and the credit as sentences: Tasks 6 and 8.
  - §16.3's tests for this part: `LegStory` along a path with an unseen stretch (Task 3), the words (Tasks 5 and 6), and `AircraftTypeNames` (Task 5).
- **Not covered here, on purpose:** the website (plan 3C), and anything of the map's drawing or the status screen, which are plan 3B-2's.
- **Names** are the same in every task: `PlanePosition(distance:coordinate:unseenFor:isSeenInAir:)` and `isEstimated`, `MapFlight.plane(at:isReplay:)`, `MapLeg.plane(at:isReplay:)`, `path`, `pathLength`, `hasLiveData`, `time(atDistance:)`, `halfwayTime`, `isTimeEstimated(atDistance:)`, `isSeen(atDistance:)`, `airborne`, `coursePosition(at:)`, `FlightPath.kind(atDistance:)`, `LegStory(along:geography:home:)`, `length` and `place(atDistance:)`, `SkyFacts.cockpitHorizon(for:)` and `cruiseAltitudesFeet`, `TripMapWording.milesFlown(by:on:isReplay:)` and `liveSummary(for:over:lastSeen:now:calendar:locale:)`, `TripTotals.soFar(on:at:sunEvents:isReplay:)`, `AircraftTypeNames.name(for:)`, `FactsWording.estimated(lastSeen:)`, `lastSeen(_:near:ago:isSpoken:)`, `aircraft(typeCode:registration:)`, `heightAndSpeed(altitudeFeet:groundSpeedKnots:locale:)`, `halfway(at:isEstimate:calendar:locale:)`, `closestToHome(miles:at:now:isEstimate:calendar:locale:)`, `liveCredit` and `spokenLiveCredit`, `FactRow.Kind.plane`, `TripFacts.isReplay`, `lastSeen(on:ago:isSpoken:)` and `showsLiveData`, `LegStoryStore(loadFiles:now:sleep:)`, `pathStoryInterval`, `pathKey(for:)` and `facts(for:forecasts:dayNumber:totalDays:isReplay:)`, `FactsFooter(showsWeather:showsLiveCredit:)` and `FactsBody(rows:tripSoFar:showsLiveCredit:)`.
- **Is it the right size?** Three new types and one file of extensions, each with one job. Nothing is built ahead of its use. Left out on purpose: shared cases for the facts on a real path, the plane's height at each past moment, and a place smaller than a city of a million. Each is in "Left for later".
- **What could it break?**
  - A flight with no live data must read exactly as before. Its path is the great circle, its times are the schedule's, and its plane is the schedule's. Every test of the facts that was there passes unchanged, the shared `facts-cases.json` among them, and three new tests pin it: the milestones, the sun events and the rows of a flight with no answer are the ones a leg made by hand has.
  - The store changes for everyone, not only listed pilots: a flight's sun events are kept by its id now. With no real path, `prepare` builds what it built before, and never waits.
  - `prepare` can now wait up to a minute. It waits only for a flight with a real path, and its task is stopped when the view goes or the path changes.
  - The helper target is untouched: none of its 15 files changes.
- **Is it what an Apple engineer would write?** Value types that are `nonisolated` and `Sendable` for everything that can be tested. The views render what `TripFacts` hands them and decide nothing. The store's wait is structured: it lives in the view's own task, and ends with it. Its clock and its wait are handed in, as `LiveFlightSource`'s are.

## Left for later

- **A long last-seen line on the card's chip.** "Estimated · last seen over Newfoundland and Labrador" is about as long as the chip holds. It shrinks a little and is then cut off. Todd looks in Task 9.
- **A place smaller than a city of a million.** "Last seen near Gander" would need towns in `geography.json`.
- **The plane's height at each past moment.** The sun's events use one height for the whole flight: the newest fix's, at its cruise. The trail has each point's height, and the path doesn't carry it.
- **"Halfway!" can lead twice.** Halfway is half the path's whole length, which grows a little as the plane leaves the great circle. A plane just past it can be just short of it after a wide turn.
- **A replay through a stretch nobody saw** reads what's below from the straight join across it. Nothing is announced there, and the place is still named.
- **A story up to a minute old** is right for the path already flown, and reads the way ahead from where the plane was a minute ago.
- **Shared cases for the facts on a real path.** The website's plan may want them: what's told on which stretch, and the halfway time. They'd be written by the reference in `scripts/live-cases/`.
- **The card's and the full-screen map's `prepare` each wait** when a path grows within a minute. Only the first to wake makes the story, and the other finds it made.
- **VoiceOver reads a row's " · " as it stands** in a title, as it always has in the distance row. The plane's row has one too.
- **Weather is asked again at each new landing estimate,** as plan 3B-2 notes. It's kept by airport and hour, so that costs nothing.
- **`MapLeg`'s five schedule questions** could ask the path and the record, as the spec has it, once nothing needs the schedule's plane from them.
- **A plane on the ground somewhere else that was never seen in the air** counts as nothing flown, so what's below is read at the departure airport, with the city by the plane. A diverted plane that was seen flying reads where it was last seen flying.
- **The record is read by this device's clock.** Only a fix's age is measured by Crewlu Cloud's. A phone whose clock is minutes wrong reads the sun a little early or late, as it reads which leg is under way.
- **The views' hand-offs have no tests:** the full-screen map telling the facts it's a replay, and the credit's flag reaching the footer. Todd sees both in Task 9.
- **No test runs two `prepare` calls at once.** The review walked through the orders they can run in and found none that makes a path's story twice or keeps an older one. Two calls can still make one route's story twice, as they always could.
- **`TripMapWording.swift` is past 300 lines** (359, from 349). Its miles and its sentences could be two files.
- **The once-a-minute rule isn't kept across a turn on the schedule.** A flight whose live data goes and comes back has its path's story made again at once, however lately the last was made. That happens no oftener than the live plane is asked for, every 30 seconds.
- **The engine's and the map's own "Left for later"** are otherwise as they were.

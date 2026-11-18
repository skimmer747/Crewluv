# Facts: Best Guesses Over the Ocean, and the Newest First (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** While the real plane is out of sight, as it will be over the Pacific on Todd's flight of 16 Nov 2026, the facts tell their best guess in plain words, from where the map flies the plane on. The list of what has happened puts the newest first, and the flight in the air stands out.

**Architecture:**
- **`Milestone` gains `isEstimate`.** Every crossing, halfway and closest point to home is told, on a real path too. One the plane wasn't seen at is a best guess: its time is where the plan has the plane, and the words say "about".
- **What's below is read where the map draws the plane,** seen or not (`MapLeg.plane(at:isReplay:)`, from plan 3B-3). A new line, `TripFacts.lastSeenLine`, says where and when the plane was last seen. It sits under what's below.
- **`TripSoFar` carries events, not strings,** each with `isEstimate`, newest first, and a `tag` on the flight between its gates. `TripSoFarList` draws a guess lighter and slanted, and puts a border round the flight in the air.
- **"Trip so far" is said once:** `TripFacts.hasTripSoFarRow(at:)` says when the rows have one, and the list leaves its own out then.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency in the app target (not in the test target), iOS 26, SwiftUI, XCTest.

**Design:** `docs/superpowers/specs/2026-11-15-crewluve-facts-best-guesses-design.md` ("the design"). It refines the Stage 3 spec's §8, §9 and §15, as plan 3B-3 (`docs/superpowers/plans/2026-11-15-moving-map-stage3b3-app-facts.md`) built them.

**Todd's choices (15 Nov 2026):** tell the best guess, marked "about"; no "probably", and no "estimated" in front: plain words, worked out from the last position along the great circle; the latest event shown large on the map waits until after the flight; build it before the flight.

**How this plan was checked.** Every code block here comes from a file that was built and run before the plan was put together.
- **A scratch Swift package** with the app target's settings, made from the repo at `59c998e`, holds real copies of the map's model, its facts and the engine, and 49 of their test classes, with this plan's files laid over them.
  - Before: 504 XCTest and 71 Swift Testing tests, all passing.
  - With this plan: 512 XCTest and 71 Swift Testing tests, all passing, with no warnings.
- **31 deliberate breaks** were made in the new code, one at a time. Each fails at least one test. Two slipped through at first: halfway on a leg that goes nowhere, and "Trip so far" in a recap. Each now has a test that catches it.
- **The whole app was type-checked and compiled for iOS** with `swiftc`, outside Xcode, as it stands after each task: 180 files, no errors and no warnings.
- **The plan itself was followed by a script** on the repo's files at `59c998e`: all 14 files came out the same as the tested ones.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together: nothing critical. It asked for a test that `hasTripSoFarRow` agrees with the rows at every moment, which is in Task 3, and a test of a landing nobody saw, in Task 2. What it noted and was left is in "Left for later".
- **Not checked:** nothing ran on a simulator or a device, and no view was seen: the border, the tag and the lighter lines are Todd's to look at (Task 4).

**Where this plan settles what the design left open:**
- **A guess stays a guess.** An event on a stretch nobody saw keeps its "about" after the plane is seen again: it's on the straight join between the two places it was seen.
- **The headline says a guessed event plainly,** for 5 minutes from the time the plan has it, like any other. Its time is the estimate's, so if the plane turns up somewhere else, a guessed event ahead can move.
- **With no place known** while the plane is out of sight, the chip is the landing countdown, as it is for a plane that's seen. The sheet's first row is then "Last seen 2 h ago".
- **A replay** reads the same way at a moment past where the plane was last seen. Its flight's tag is "In the air", since that moment isn't now.
- **"Trip so far" under the list** is left out wherever the rows have that row: on a layover, and on a drive. Where the rows' own row has nothing to say, neither has the list's.

---

## Ground rules for whoever runs this plan

1. **Don't run `xcodebuild` build or test loops,** and don't let subagents run them. Todd runs the tests, with the command in Task 4.
2. **Never commit without Todd's go-ahead in the conversation,** and then only this plan's files, by path. Never `.superpowers/`.
3. **No release note of its own.** It goes in with plan 3B-3's.
4. **Mark pure types `nonisolated`,** and copy the code as written. A replacement is exact: if its text isn't in the file once, stop.
5. **Reviewers:** `superpowers:code-reviewer` with `model: "sonnet"`.
6. **Work on `feature/trip-map-live`.** The checkout is shared: never stash, reset or switch branches.

## File map

| File | Task | What changes |
|---|---|---|
| `Crewluv/Services/TripMap/Facts/Milestone.swift` | 2 | every event is told, and one nobody saw is a best guess (`isEstimate`) |
| `Crewluv/Services/TripMap/Facts/MapLeg+Course.swift` | 2 | `isSeen(atDistance:)`'s comment says what it's for now |
| `Crewluv/Services/TripMap/Facts/FactsWording.swift` | 2 | "about" in the list and on the closest point, the last-seen line, "In the air now" |
| `Crewluv/Services/TripMap/TripMapWording.swift` | 2 | VoiceOver says what's below, then where the plane was last seen |
| `Crewluv/Services/TripMap/Facts/TripFacts.swift`, `TripFacts+Rows.swift` | 2, 3 | what's below where the map has the plane, the last-seen line, the list newest first, "Trip so far" once |
| `Crewluv/Services/TripMap/Facts/TripSoFar.swift` | 3 | events with `isEstimate`, and a tag on the flight in the air |
| `Crewluv/Views/TripMap/TripSoFarList.swift` | 3 | a border round the flight in the air, and guesses lighter and slanted |
| `CrewluvTests/LiveStoryTests.swift`, `MapLegCourseTests.swift`, `FactsWordingTests.swift`, `LiveWordingTests.swift`, `LiveTripFactsTests.swift`, `TripFactsTests.swift` | 2, 3 | the tests |

---

### Task 1: Before starting

- [ ] **Step 1: Check the branch and the tree.**

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

The branch is `feature/trip-map-live`, at `59c998e` or later. Anything this plan changes that has changed since `59c998e` is read before going on.

---

### Task 2: A best guess where nobody saw the plane

**Files:** `Crewluv/Services/TripMap/Facts/Milestone.swift`, `MapLeg+Course.swift`, `FactsWording.swift`, `TripFacts.swift`, `TripFacts+Rows.swift`; `Crewluv/Services/TripMap/TripMapWording.swift`; tests `CrewluvTests/LiveStoryTests.swift`, `MapLegCourseTests.swift`, `FactsWordingTests.swift`, `LiveWordingTests.swift`, `LiveTripFactsTests.swift`.

- [ ] **Step 1: The tests.** Several tests of plan 3B-3 held the old rule (nothing told where nobody saw the plane, and "Estimated · last seen" in front). They're rewritten for the new one.

In `CrewluvTests/LiveStoryTests.swift`:

Replace:

```swift
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
```

with:

```swift
        assertMilestone(found[3], .closestToHome(miles: 35), at: "2026-03-20T12:07:00Z")
        XCTAssertEqual(found.map(\.isEstimate), [false, false, false, false], "it was seen all the way")
    }

    func test_milestones_aCrossingNobodySaw_isABestGuess() throws {
        // Nobody saw it from 4° E (10:47) to 6.5° E (11:07), where it crossed into Bravo. On the straight join
        // between the two it's at 5° E at 10:55.
        let found = milestones(try leg(seenUntil: "12:30", unseen: 4...6.5), home: home)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        XCTAssertEqual(found.map(\.isEstimate), [true, false, false, false])
        if let crossing = found.first { assertMilestone(crossing, .crossedInto("Bravo"), at: "2026-03-20T10:55:00Z") }
    }

    func test_milestones_theClosestPointToHome_whereNobodySawIt_isABestGuess() throws {
        // Nobody saw it from 13° E to 15° E, where it passed home.
        let found = milestones(try leg(seenUntil: "12:30", unseen: 13...15), home: home)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        XCTAssertEqual(found.map(\.isEstimate), [false, false, false, true])
    }

    func test_milestones_ofALegThatGoesNowhere_areHalfwayInTheMiddleOfItsTimeInTheAir() {
        // It has no length, so halfway is timed as it always was: half its time in the air, 10:15 to 13:15.
        let nowhere = FactsTestData.equatorFlight(from: 0, to: 0)
        let found = milestones(nowhere)
        XCTAssertEqual(found.map(\.kind), [.halfway])
        if let halfway = found.first { assertMilestone(halfway, .halfway, at: "2026-03-20T11:45:00Z") }
    }

    func test_milestones_aheadOfWhereThePlaneWasLastSeen_areBestGuesses() throws {
        // Last seen at 3.75° E at 10:45. Everything is still ahead, where the plan has the plane flying on.
        let found = milestones(try leg(seenUntil: "10:45"), home: home)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        XCTAssertEqual(found.map(\.isEstimate), [true, true, true, true])
        XCTAssertTrue(found.allSatisfy { $0.time > at("10:45") })
        // At its own 450 kt it's at 5° E ten minutes after it was last seen.
        if let crossing = found.first { assertMilestone(crossing, .crossedInto("Bravo"), at: "2026-03-20T10:55:00Z") }
    }
```

Replace:

```swift
        XCTAssertEqual(before.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        if let first = before.first { assertMilestone(first, .crossedInto("Bravo"), at: "2026-03-20T11:00:00Z") }
```

with:

```swift
        XCTAssertEqual(before.map(\.kind), [.crossedInto("Bravo"), .halfway, .outOver("the Test Sea"), .closestToHome(miles: 35)])
        XCTAssertEqual(after.map(\.isEstimate), [false, false, false, false], "the schedule is told as it is")
        if let first = before.first { assertMilestone(first, .crossedInto("Bravo"), at: "2026-03-20T11:00:00Z") }
```

In `CrewluvTests/MapLegCourseTests.swift`:

Replace:

```swift
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
```

with:

```swift
    func test_isSeen_ofAFlightSeenToItsLanding_isTrueAllTheWay() throws {
        let landedAt = FactsTestData.liveTime(atLongitude: 20)
        let landed = try FactsTestData.equatorLiveLeg(
            FactsTestData.equatorLive(seenUntil: FactsTestData.liveTime(atLongitude: 19.75), landedAt: landedAt), at: landedAt)
        XCTAssertTrue(landed.isSeen(atDistance: meters(5)))
        XCTAssertTrue(landed.isSeen(atDistance: meters(19.9)), "it was seen down two minutes after it was last seen in the air")
    }

    func test_isSeen_overALandingNobodySaw_isFalse() throws {
        // Last seen at 15.625° E at 12:30, and seen down at 20° E 25 minutes later: nobody saw its approach.
        let landedAt = FactsTestData.liveTime(atLongitude: 20)
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("12:30"), landedAt: landedAt), at: landedAt)
        XCTAssertTrue(leg.isSeen(atDistance: meters(15)))
        XCTAssertFalse(leg.isSeen(atDistance: meters(18)))
    }

    func test_isSeen_onlyWhereTheRealPlaneWasSeen() throws {
```

In `CrewluvTests/FactsWordingTests.swift`:

Replace:

```swift
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
```

with:

```swift
        XCTAssertEqual(plain(FactsWording.closestToHome(miles: 40, at: now, now: later, isEstimate: true, calendar: calendar, locale: locale)),
                       "Closest to home was 40 mi at about 3:14 PM", "where nobody saw the plane pass, it's still a best guess")
    }

    func test_listLine_aBestGuess_saysAboutBeforeItsTime() {
        let seen = Milestone(kind: .outOver("the Pacific"), time: now)
        let guessed = Milestone(kind: .outOver("the Pacific"), time: now, isEstimate: true)
        XCTAssertEqual(plain(FactsWording.listLine(for: seen, calendar: calendar, locale: locale)), "Out over the Pacific · 3:14 PM")
        XCTAssertEqual(plain(FactsWording.listLine(for: guessed, calendar: calendar, locale: locale)), "Out over the Pacific · about 3:14 PM")
        let halfway = Milestone(kind: .halfway, time: now, isEstimate: true)
        XCTAssertEqual(plain(FactsWording.listLine(for: halfway, calendar: calendar, locale: locale)), "Halfway · about 3:14 PM")
    }

    // MARK: - The real plane (Stage 3 spec §8, best guesses design §2)

    func test_lastSeenLine_theCityByIt_elseThePlaceUnderIt_andHowLongAgo() {
        let place = Geography.Place(name: "Québec", kind: .province, country: "Canada")
        let city = Geography.City(name: "Montréal", lat: 45.5, lon: -73.57)
        XCTAssertEqual(FactsWording.lastSeenLine(place, near: city, ago: 600), "Last seen near Montréal · 10 min ago")
        XCTAssertEqual(FactsWording.lastSeenLine(place, near: nil, ago: 7_800), "Last seen over Québec · 2 h 10 min ago")
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: 7_200), "Last seen 2 h ago")
    }

    func test_lastSeen_forVoiceOver_theCityByIt_elseThePlaceUnderIt_elseHowLongAgo() {
        let place = Geography.Place(name: "Québec", kind: .province, country: "Canada")
        let city = Geography.City(name: "Montréal", lat: 45.5, lon: -73.57)
        XCTAssertEqual(FactsWording.lastSeen(place, near: city, ago: 600), "near Montréal")
        XCTAssertEqual(FactsWording.lastSeen(place, near: nil, ago: 600), "over Québec")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: 600), "10 minutes ago")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: 7_800), "2 hours 10 minutes ago")
    }

    func test_lastSeen_aTimeThatCantBeRight_isHeldFromAMinuteToAYear() {
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: 20), "Last seen 1 min ago")
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: -500), "Last seen 1 min ago")
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: .infinity), "Last seen 8760 h ago")
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: .nan), "Last seen 1 min ago")
        XCTAssertEqual(FactsWording.lastSeen(nil, near: nil, ago: .nan), "1 minute ago")
    }

    func test_inTheAir_saysNow_butNotInAReplay() {
        XCTAssertEqual(FactsWording.inTheAir(isReplay: false), "In the air now")
        XCTAssertEqual(FactsWording.inTheAir(isReplay: true), "In the air")
    }
```

In `CrewluvTests/LiveWordingTests.swift`:

Replace:

```swift
    func test_liveSummary_whileEstimated_saysWhereItWasLastSeen_inPlaceOfWhatsBelow() throws {
        let (leg, at) = try leg(of: "ahead, in the air", at: "13T12:45:00")
        let summary = TripMapWording.liveSummary(for: leg, over: "Ohio", lastSeen: "near Columbus", now: at, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(try XCTUnwrap(summary)),
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, last seen near Columbus. Lands about 8:30 AM your time.")
    }
```

with:

```swift
    func test_liveSummary_whileOutOfSight_saysWhatsBelowByThePlan_andWhereItWasLastSeen() throws {
        let (leg, at) = try leg(of: "ahead, in the air", at: "13T12:45:00")
        let summary = TripMapWording.liveSummary(for: leg, over: "Ohio", lastSeen: "near Columbus", now: at, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(try XCTUnwrap(summary)),
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, over Ohio, last seen near Columbus. Lands about 8:30 AM your time.")
        let noPlace = TripMapWording.liveSummary(for: leg, lastSeen: "12 minutes ago", now: at, calendar: calendar, locale: locale)
        XCTAssertEqual(plain(try XCTUnwrap(noPlace)),
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, last seen 12 minutes ago. Lands about 8:30 AM your time.")
    }
```

In `CrewluvTests/LiveTripFactsTests.swift`:

Replace:

```swift
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
```

with:

```swift
    func test_headline_whileOutOfSight_isWhatsBelowWhereThePlanHasThePlane() throws {
        // Last seen over Alpha, at 4.375° E at 10:50. Eleven minutes on at its own 450 kt it's at 5.75° E: over
        // Bravo, 25 mi from Testville. The words are as plain as when it's seen.
        XCTAssertEqual(try facts(seenUntil: "10:50", now: "11:01").headline(at: at("11:01")), "Over Bravo, near Testville")
        // Last seen at 6.875° E ten minutes ago, it's at 8.125° E by now: no city within 40 mi.
        XCTAssertEqual(try facts(seenUntil: "11:10", now: "11:20").headline(at: at("11:20")), "Over Bravo")
    }

    func test_headline_whileOutOfSight_withNoPlaceKnown_isTheLandingCountdown() throws {
        // It lands at 13:11:47 by its estimate: 112 minutes after 11:20.
        let facts = try facts(seenUntil: "11:10", now: "11:20", hasStory: false)
        XCTAssertEqual(facts.headline(at: at("11:20")), "Landing in 1 h 52 min")
    }

    func test_headline_whileOutOfSight_keepsItsOrder() throws {
        // Last seen at 9.375° E at 11:30. By the plan it's halfway at 11:35: that leads for five minutes, and then
        // what's below does.
        let facts = try facts(seenUntil: "11:30", now: "11:37")
        XCTAssertEqual(facts.headline(at: at("11:37")), "Halfway!")
        XCTAssertEqual(facts.headline(at: at("11:41")), "Over Bravo")
    }

    func test_headline_whileOutOfSight_tellsACrossingAsItsBestGuess() throws {
        // Last seen at 4.375° E at 10:50. By the plan it crosses the border at 5° E at 10:55, and nobody saw it.
        XCTAssertEqual(try facts(seenUntil: "10:50", now: "10:58").headline(at: at("10:58")), "Just crossed into Bravo")
        XCTAssertEqual(try facts(seenUntil: "10:50", now: "10:54").headline(at: at("10:54")), "Over Alpha", "not there yet, by the plan")
    }

    func test_headline_inAReplay_isWhereTheRecordHasThePlane() throws {
        let facts = try facts(seenUntil: "11:10", isReplay: true)
        XCTAssertEqual(facts.headline(at: at("10:35")), "Over Alpha", "2.5° E at 10:35")
        XCTAssertEqual(facts.headline(at: at("11:25")), "Over Bravo", "past where it was last seen, at 8.75° E by the plan")
    }
```

Replace:

```swift
    func test_rows_whileEstimated_sayWhereItWasLastSeen_andLeaveOutItsHeightAndSpeed() throws {
        let rows = try facts(seenUntil: "11:10", now: "11:20").rows(at: at("11:20"), now: at("11:20"))
        XCTAssertEqual(try row(.below, in: rows).title, "Estimated · last seen over Bravo")
```

with:

```swift
    func test_rows_whileOutOfSight_sayWhereItWasLastSeenUnderWhatsBelow_andLeaveOutItsHeightAndSpeed() throws {
        let rows = try facts(seenUntil: "11:10", now: "11:20").rows(at: at("11:20"), now: at("11:20"))
        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Over Bravo")
        XCTAssertEqual(plain(below.detail), "Last seen over Bravo · 10 min ago · Passes 35 mi from home at about 8:07 AM")

        // Last seen at 6° E, 21 mi from Testville.
        let byACity = try facts(seenUntil: "11:03", now: "11:13").rows(at: at("11:13"), now: at("11:13"))
        XCTAssertEqual(plain(try row(.below, in: byACity).detail), "Last seen near Testville · 10 min ago · Passes 35 mi from home at about 8:07 AM")

        // With no place known, when it was last seen leads the row.
        let noPlace = try facts(seenUntil: "11:10", now: "11:20", hasStory: false).rows(at: at("11:20"), now: at("11:20"))
        XCTAssertEqual(try row(.below, in: noPlace).title, "Last seen 10 min ago")
        XCTAssertNil(try row(.below, in: noPlace).detail)
```

Replace:

```swift
    func test_rows_theClosestPointToHome_whereNobodySawIt_isLeftOut() throws {
        // Nobody saw it from 13° E to 15° E, where it passed home.
        let rows = try facts(seenUntil: "12:30", unseen: 13...15).rows(at: at("12:30"), now: at("12:30"))
        XCTAssertNil(try row(.below, in: rows).detail)
```

with:

```swift
    func test_rows_theClosestPointToHome_whereNobodySawIt_isABestGuess_withAbout() throws {
        // Nobody saw it from 13° E to 15° E, where it passed home.
        let rows = try facts(seenUntil: "12:30", unseen: 13...15).rows(at: at("12:30"), now: at("12:30"))
        XCTAssertEqual(plain(try row(.below, in: rows).detail), "Closest to home was 35 mi at about 8:07 AM")
```

Replace:

```swift
    func test_cardSummary_whileEstimated_saysAbout_andWhereItWasLastSeen() throws {
        XCTAssertEqual(plain(try facts(seenUntil: "11:10", now: "11:20").cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last seen over Bravo. Lands about 9:11 AM your time.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:03", now: "11:13").cardSummary(now: at("11:13"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last seen near Testville. Lands about 9:11 AM your time.")
```

with:

```swift
    func test_cardSummary_whileOutOfSight_saysAbout_whatsBelowByThePlan_andWhereItWasLastSeen() throws {
        XCTAssertEqual(plain(try facts(seenUntil: "10:50", now: "11:01").cardSummary(now: at("11:01"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen over Alpha. Lands about 9:11 AM your time.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:03", now: "11:13").cardSummary(now: at("11:13"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen near Testville. Lands about 9:11 AM your time.")
```

Replace:

```swift
    func test_tripSoFar_aCrossingNobodySaw_isNotListed() throws {
        let tripSoFar = try facts(seenUntil: "11:10", unseen: 4...6.5).tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights, [])
    }
```

with:

```swift
    func test_tripSoFar_aCrossingNobodySaw_isListedWithAbout() throws {
        let tripSoFar = try facts(seenUntil: "11:10", unseen: 4...6.5).tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights.first?.milestones.map { plain($0) }, ["Crossed into Bravo · about 6:55 AM"])
    }
```

- [ ] **Step 2: The milestones.**

In `Crewluv/Services/TripMap/Facts/Milestone.swift`:

Replace:

```swift
    let kind: Kind
    let time: Date

    /// How long a milestone leads the headline.
```

with:

```swift
    let kind: Kind
    let time: Date
    /// Nobody saw the plane where this happened, so it's a best guess from where the plan has the plane, and its
    /// time reads "about" (best guesses design §2).
    let isEstimate: Bool

    init(kind: Kind, time: Date, isEstimate: Bool = false) {
        self.kind = kind
        self.time = time
        self.isEstimate = isEstimate
    }

    /// How long a milestone leads the headline.
```

Replace:

```swift
    /// A flight's milestones in time order, from its story and the leg's own times: the real plane's along a real
    /// path, else the schedule's. On a real path a crossing, or the closest point to home, counts only where the
    /// plane was seen (Stage 3 spec §8): where nobody saw it the straight join is a guess, and a crossing is a
    /// claim. Halfway is half the path's whole length, flown and ahead.
    static func milestones(on leg: MapLeg, story: LegStory) -> [Milestone] {
        var found: [(kind: Kind, distance: Double, time: Date?)] = []
```

with:

```swift
    /// A flight's milestones in time order, from its story and the leg's own times: the real plane's along a real
    /// path, else the schedule's. Where nobody saw the real plane, on a stretch with no coverage or past the last
    /// place it was seen, a milestone is a best guess from where the plan has the plane, and says so
    /// (`isEstimate`). Halfway is half the path's whole length, flown and ahead.
    static func milestones(on leg: MapLeg, story: LegStory) -> [Milestone] {
        var found: [(kind: Kind, distance: Double)] = []
```

Replace:

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

with:

```swift
            if let kind = crossingKind(from: previous.place, to: next.place) {
                found.append((kind, next.start * story.length))
            }
        }
        found.append((.halfway, leg.pathLength / 2))
        if let closest = story.closestToHome {
            found.append((.closestToHome(miles: roundedMiles(closest.meters)), closest.fraction * story.length))
        }
        return found.enumerated()
            .sorted { ($0.element.distance, $0.offset) < ($1.element.distance, $1.offset) }
            .compactMap { item in
                let time = item.element.kind == .halfway ? leg.halfwayTime : leg.time(atDistance: item.element.distance)
                return time.map {
                    Milestone(kind: item.element.kind, time: $0, isEstimate: !leg.isSeen(atDistance: item.element.distance))
                }
            }
    }
```

In `Crewluv/Services/TripMap/Facts/MapLeg+Course.swift`:

Replace:

```swift
    /// Whether the time the plane reaches `distance` meters along its path is an estimate, which the words mark
    /// with "about" (spec §9): it's ahead of where the real plane was last seen.
    func isTimeEstimated(atDistance distance: Double) -> Bool {
        guard let path = flight?.path, path.isReal else { return false }
        return !path.hasLanded && distance > path.flownLength
    }

    /// Whether the plane was seen `distance` meters along its path, so a crossing there can be told. Where nobody
    /// saw it the straight join is a guess, and a crossing is a claim. A flight with no real path flies the
    /// schedule, which tells every one.
```

with:

```swift
    /// Whether the plane was seen `distance` meters along its path. Where nobody saw it, on a stretch with no
    /// coverage or past the last place it was seen, what happens there is a best guess, and its time reads
    /// "about" (best guesses design §1). A flight with no real path flies the schedule, which is told as it is.
```

- [ ] **Step 3: The words.**

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    /// The tall stop's list: "Crossed into Kansas · 1:12 PM".
    static func listLine(for milestone: Milestone, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = TripMapWording.clockTime(milestone.time, in: calendar.timeZone, locale: locale)
```

with:

```swift
    /// The tall stop's list: "Crossed into Kansas · 1:12 PM". A best guess reads "about": "Out over the Pacific ·
    /// about 4:05 PM" (best guesses design §2).
    static func listLine(for milestone: Milestone, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = (milestone.isEstimate ? "about " : "") + TripMapWording.clockTime(milestone.time, in: calendar.timeZone, locale: locale)
```

Replace:

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
```

with:

```swift
    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed. Where
    /// nobody saw the real plane the time is a best guess: "Passes 40 mi from home at about 1:05 PM".
    static func closestToHome(miles: Int, at time: Date, now: Date, isEstimate: Bool = false,
                              calendar: Calendar = .current, locale: Locale = .current) -> String {
        let clock = (isEstimate ? "about " : "") + TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale)
        return time > now ? "Passes \(miles) mi from home at \(clock)" : "Closest to home was \(miles) mi at \(clock)"
    }

    // MARK: - The real plane (Stage 3 spec §8)

    /// Under what's below, while the real plane is out of sight: "Last seen near Montréal · 12 min ago", by a
    /// city of a million or more, else "Last seen over Québec · 12 min ago", else "Last seen 12 min ago". It's the
    /// one line that says the place above it is worked out, not seen (best guesses design §2).
    static func lastSeenLine(_ place: Geography.Place?, near city: Geography.City?, ago: TimeInterval) -> String {
        let time = "\(TripMapWording.minutesText(minutes(ago: ago))) ago"
        if let city { return "Last seen near \(city.name) · \(time)" }
        if let place { return "Last seen over \(place.name) · \(time)" }
        return "Last seen \(time)"
    }

    /// Where a plane that's out of sight was last seen, for VoiceOver's sentence: "near Montréal" by a city of a
    /// million or more, else "over Québec", else how long ago, "2 hours ago".
    static func lastSeen(_ place: Geography.Place?, near city: Geography.City?, ago: TimeInterval) -> String {
        if let city { return "near \(city.name)" }
        if let place { return "over \(place.name)" }
        return "\(TripMapWording.spokenMinutes(minutes(ago: ago))) ago"
    }

    /// The tag on the flight between its gates, in the list: "In the air now", or "In the air" at a moment of
    /// the replay (best guesses design §4).
    static func inTheAir(isReplay: Bool) -> String {
        isReplay ? "In the air" : "In the air now"
    }
```

Replace:

```swift
    /// `text` without the spaces around it, or nil when nothing is left.
```

with:

```swift
    /// Whole minutes for a length of time, held from a minute to a year, so one that can't be right never
    /// overflows.
    private static func minutes(ago: TimeInterval) -> Int {
        let asked = (ago / 60).rounded()
        return asked.isNaN ? 1 : Int(min(max(asked, 1), 365 * 24 * 60))
    }

    /// `text` without the spaces around it, or nil when nothing is left.
```

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
    ///   - lastSeen: where an estimated plane was last seen, as `FactsWording.lastSeen` words it: "near Montréal",
    ///     "over Québec" or "2 hours ago". It takes the place of what's below (Stage 3 spec §15).
```

with:

```swift
    ///   - lastSeen: where a plane that's out of sight was last seen, as `FactsWording.lastSeen` words it: "near
    ///     Montréal", "over Québec" or "2 hours ago". It follows what's below, which is then a best guess
    ///     (Stage 3 spec §15, best guesses design §2).
```

Replace:

```swift
        let over = lastSeen.map { ", last seen \($0)" } ?? place.map { ", over \($0)" } ?? ""
```

with:

```swift
        let over = (place.map { ", over \($0)" } ?? "") + (lastSeen.map { ", last seen \($0)" } ?? "")
```

- [ ] **Step 4: The headline, the rows and the card's sentence.**

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. While the real plane is an estimate, where it was last seen takes the
    /// place below's turn (Stage 3 spec §9). Nil on the ground and on a drive, where Stage 1's words stay.
```

with:

```swift
    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. While the real plane is out of sight they're its best guesses, in the same
    /// plain words (best guesses design §2). Nil on the ground and on a drive, where Stage 1's words stay.
```

Replace:

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
```

with:

```swift
    /// "Over Kansas", "Over Québec, near Montréal", from the flight's story, read where the plane is. A real plane
    /// that's out of sight is where the plan has it, flying on from the last place it was seen, and reads the same.
    func belowText(on leg: MapLeg, at date: Date) -> String? {
        let plane = leg.plane(at: date, isReplay: isReplay)
        guard let place = stories[leg.id]?.place(atDistance: plane.distance) else { return nil }
        return FactsWording.below(place, near: geography?.city(near: plane.coordinate))
    }

    /// "Last seen near Montréal · 12 min ago", while the real plane is out of sight, or nil while it's seen.
    func lastSeenLine(on leg: MapLeg, at date: Date) -> String? {
        guard let unseenFor = leg.plane(at: date, isReplay: isReplay).unseenFor else { return nil }
        let seen = lastSeenPlace(on: leg)
        return FactsWording.lastSeenLine(seen.place, near: seen.city, ago: unseenFor)
    }

    /// What was under the real plane where it was last seen, and the city by it.
    private func lastSeenPlace(on leg: MapLeg) -> (place: Geography.Place?, city: Geography.City?) {
        let path = leg.path
        return (stories[leg.id]?.place(atDistance: path.flownLength),
                geography?.city(near: path.point(atDistance: path.flownLength)))
    }
```

Replace:

```swift
                // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9), and
                // while it's an estimate, where it was last seen (§15).
                let lastSeen = plane.unseenFor.map { lastSeen(on: leg, ago: $0, isSpoken: true) }
```

with:

```swift
                // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9), and
                // while it's out of sight, where it was last seen (§15).
                let lastSeen = plane.unseenFor.map { ago -> String in
                    let seen = lastSeenPlace(on: leg)
                    return FactsWording.lastSeen(seen.place, near: seen.city, ago: ago)
                }
```

In `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`:

Replace:

```swift
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
```

with:

```swift
    /// What's below, then where a plane that's out of sight was last seen, then the closest point to home. The
    /// first of them that there is leads the row.
    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let lines = [belowText(on: leg, at: date), lastSeenLine(on: leg, at: date), closestToHomeLine(on: leg, at: date)]
            .compactMap { $0 }
        guard let title = lines.first else { return nil }
        return FactRow(.below, symbol: "mappin.and.ellipse", title: title, details: Array(lines.dropFirst()))
    }

    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed. Where
    /// nobody saw the real plane it's a best guess, and its time reads "about" (best guesses design §2).
    private func closestToHomeLine(on leg: MapLeg, at date: Date) -> String? {
        guard let story = stories[leg.id], let closest = story.closestToHome else { return nil }
        let distance = closest.fraction * story.length
        guard let time = leg.time(atDistance: distance) else { return nil }
        return FactsWording.closestToHome(miles: Milestone.roundedMiles(closest.meters), at: time, now: date,
                                          isEstimate: !leg.isSeen(atDistance: distance), calendar: calendar, locale: locale)
    }
```

Replace:

```swift
            $0 > date ? FactsWording.halfway(at: $0, isEstimate: leg.isTimeEstimated(atDistance: leg.pathLength / 2),
                                             calendar: calendar, locale: locale) : nil
```

with:

```swift
            $0 > date ? FactsWording.halfway(at: $0, isEstimate: !leg.isSeen(atDistance: leg.pathLength / 2),
                                             calendar: calendar, locale: locale) : nil
```

---

### Task 3: The list: newest first, the flight in the air set apart, and "Trip so far" once

**Files:** `Crewluv/Services/TripMap/Facts/TripSoFar.swift` (replaced whole), `TripFacts.swift`, `TripFacts+Rows.swift`; `Crewluv/Views/TripMap/TripSoFarList.swift` (replaced whole); tests `CrewluvTests/LiveTripFactsTests.swift`, `TripFactsTests.swift`.

- [ ] **Step 1: The tests.**

In `CrewluvTests/LiveTripFactsTests.swift`:

Replace:

```swift
        XCTAssertEqual(tripSoFar.flights.first?.milestones.map { plain($0) }, ["Crossed into Bravo · 6:55 AM"])
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 475 mi")
    }

    func test_tripSoFar_inAReplay_countsAsFarAsTheRecordHasThePlane() throws {
        let tripSoFar = try facts(seenUntil: "11:10", isReplay: true).tripSoFar(at: at("10:35"))
        XCTAssertEqual(tripSoFar.flights, [], "at 10:35 it hadn't crossed into Bravo yet")
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 173 mi")
    }

    func test_tripSoFar_aCrossingNobodySaw_isListedWithAbout() throws {
        let tripSoFar = try facts(seenUntil: "11:10", unseen: 4...6.5).tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights.first?.milestones.map { plain($0) }, ["Crossed into Bravo · about 6:55 AM"])
    }
```

with:

```swift
        XCTAssertEqual(tripSoFar.flights.first?.events.map { plain($0.text) }, ["Crossed into Bravo · 6:55 AM"])
        XCTAssertEqual(tripSoFar.flights.first?.events.map(\.isEstimate), [false])
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 475 mi")
    }

    func test_tripSoFar_theFlightInTheAir_isSetApart_evenBeforeItsFirstEvent() throws {
        let now = try facts(seenUntil: "10:35").tripSoFar(at: at("10:35"))
        XCTAssertEqual(now.flights.map(\.tag), ["In the air now"])
        XCTAssertEqual(now.flights.first?.events, [], "at 10:35 it hasn't crossed into Bravo yet")

        let replayed = try facts(seenUntil: "11:10", isReplay: true).tripSoFar(at: at("10:35"))
        XCTAssertEqual(replayed.flights.map(\.tag), ["In the air"], "a replay's moment isn't now")
        XCTAssertEqual(replayed.totals, "Day 1 of 1 · 173 mi")
    }

    func test_tripSoFar_listsTheNewestEventFirst() throws {
        let tripSoFar = try facts(seenUntil: "12:30").tripSoFar(at: at("12:30"))
        XCTAssertEqual(tripSoFar.flights.first?.events.map { plain($0.text) }, [
            "Closest to home, 35 mi · 8:07 AM", "Out over the Test Sea · 7:51 AM", "Halfway · 7:35 AM", "Crossed into Bravo · 6:55 AM",
        ])
    }

    func test_tripSoFar_aCrossingNobodySaw_isListedAsABestGuess() throws {
        // Nobody saw it from 4° E to 6.5° E. On the straight join it crossed into Bravo at 10:55.
        let tripSoFar = try facts(seenUntil: "11:10", unseen: 4...6.5).tripSoFar(at: at("11:10"))
        XCTAssertEqual(tripSoFar.flights.first?.events.map { plain($0.text) }, ["Crossed into Bravo · about 6:55 AM"])
        XCTAssertEqual(tripSoFar.flights.first?.events.map(\.isEstimate), [true])
    }

    func test_tripSoFar_whileOutOfSight_listsWhatThePlanHasHappened() throws {
        // Last seen at 4.375° E at 10:50. By the plan it crossed into Bravo at 10:55.
        let tripSoFar = try facts(seenUntil: "10:50", now: "11:01").tripSoFar(at: at("11:01"))
        XCTAssertEqual(tripSoFar.flights.first?.events.map { plain($0.text) }, ["Crossed into Bravo · about 6:55 AM"])
    }
```

In `CrewluvTests/TripFactsTests.swift`:

Replace:

```swift
        XCTAssertEqual(tripSoFar.flights.first?.milestones.map { plain($0) }, [
            "Crossed into Bravo · 7:00 AM", "Halfway · 7:45 AM", "Out over the Test Sea · 8:03 AM", "Closest to home, 35 mi · 8:21 AM",
        ])
```

with:

```swift
        // Newest first (best guesses design §3), and the flight is the one in the air.
        XCTAssertEqual(tripSoFar.flights.first?.events.map { plain($0.text) }, [
            "Closest to home, 35 mi · 8:21 AM", "Out over the Test Sea · 8:03 AM", "Halfway · 7:45 AM", "Crossed into Bravo · 7:00 AM",
        ])
        XCTAssertEqual(tripSoFar.flights.first?.events.map(\.isEstimate), [false, false, false, false], "the schedule is told as it is")
        XCTAssertEqual(tripSoFar.flights.first?.tag, "In the air now")
```

Replace:

```swift
        XCTAssertEqual(equatorFacts().tripSoFar(at: at("11:50")).flights.first?.milestones.count, 2)
    }
```

with:

```swift
        XCTAssertEqual(equatorFacts().tripSoFar(at: at("11:50")).flights.first?.events.count, 2)
    }

    func test_tripSoFar_onALayover_saysTripSoFarOnce_inTheRows() throws {
        // The rows have "Trip so far" on a layover, so it isn't said again under the list (best guesses design §5).
        let at = TripMapTestLegs.tripStart.addingTimeInterval(12 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: at))
        let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: sunEvents,
                              calendar: calendar, locale: locale)
        XCTAssertTrue(facts.rows(at: at, now: at).contains { $0.kind == .tripSoFar })
        XCTAssertTrue(facts.hasTripSoFarRow(at: at))
        XCTAssertNil(facts.tripSoFar(at: at).totals)
        XCTAssertEqual(facts.tripSoFar(at: at).flights.map(\.tag), [], "a finished flight with no event isn't listed")

        // In flight the rows have none, so it's under the list.
        let inFlight = TripMapTestLegs.tripStart.addingTimeInterval(4 * 3600)
        XCTAssertFalse(facts.rows(at: inFlight, now: inFlight).contains { $0.kind == .tripSoFar })
        XCTAssertNotNil(facts.tripSoFar(at: inFlight).totals)
    }

    func test_hasTripSoFarRow_isWhetherTheRowsHaveIt_atEveryMoment() throws {
        let start = TripMapTestLegs.tripStart
        let trip = TripMapTestLegs.europeTrip()
        let drive = MapLeg(id: "d", kind: .drive,
                           origin: FactsTestData.mark("LEX", latitude: 38.04, longitude: -84.61, city: "Lexington"),
                           destination: FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74, city: "Louisville"),
                           start: start, end: start.addingTimeInterval(3600), flightNumber: nil)
        let maps = [
            try XCTUnwrap(TripMapTestLegs.map(trip, at: start)),
            try XCTUnwrap(TripMapTestLegs.map(trip, isNextTrip: true, at: start.addingTimeInterval(-86_400))),
            try XCTUnwrap(TripMap.make(tripLegs: trip, isNextTrip: false, isRecap: true, homeAirportCode: "SDF",
                                       legacyDelayMinutes: nil, at: start, coordinate: TripMapTestLegs.coordinate)),
            TripMap(mode: .onTrip, legs: [drive], home: nil, span: DateInterval(start: drive.start, end: drive.end), tripDays: nil),
        ]
        var checked = 0
        for map in maps {
            let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
            // With a day to tell, a "Trip so far" row always has something to say where there is one.
            let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: sunEvents,
                                  dayNumber: 1, totalDays: 4, calendar: calendar, locale: locale)
            for half in stride(from: -60, through: 200, by: 1) {
                let at = start.addingTimeInterval(Double(half) * 1800)
                XCTAssertEqual(facts.hasTripSoFarRow(at: at), facts.rows(at: at, now: at).contains { $0.kind == .tripSoFar },
                               "\(map.mode) at \(half) half hours")
                checked += 1
            }
        }
        XCTAssertEqual(checked, 4 * 261)
    }
```

- [ ] **Step 2: The list's model.**

Replace the whole of `Crewluv/Services/TripMap/Facts/TripSoFar.swift` with:

```swift
//
//  TripSoFar.swift
//  CrewLuve
//
//  The facts sheet dragged all the way up (Stage 2 spec §5.2, §5.5; best guesses design §3, §4): the flight between
//  its gates, set apart, and each earlier flight, newest first. Under each, what has happened, newest first. Then
//  the totals.
//

nonisolated struct TripSoFar: Equatable, Sendable {

    /// One line of a flight's list: "Crossed into Canada · 1:12 PM".
    nonisolated struct Event: Equatable, Sendable {
        let text: String
        /// A best guess, where nobody saw the plane. Its time reads "about", and it's drawn lighter.
        let isEstimate: Bool
    }

    nonisolated struct Flight: Identifiable, Equatable, Sendable {
        let id: String
        /// "UPS207 · Louisville → Cologne".
        let title: String
        /// "In the air now" for the flight between its gates, which the list sets apart. Nil for any other.
        let tag: String?
        /// What has happened so far, newest first.
        let events: [Event]
    }

    /// The flight between its gates, and each earlier flight with at least one event so far.
    let flights: [Flight]
    /// "Trip so far", or "Trip recap" once a recap's trip is over.
    let totalsTitle: String
    /// Nil with nothing to say, and where the rows above already have a "Trip so far" row.
    let totals: String?
}
```

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
        let flights = started.compactMap { leg -> TripSoFar.Flight? in
            let lines = milestones(on: leg).filter { $0.time <= date }.map { FactsWording.listLine(for: $0, calendar: calendar, locale: locale) }
            return lines.isEmpty ? nil : TripSoFar.Flight(id: leg.id, title: FactsWording.flightTitle(leg), milestones: lines)
        }
```

with:

```swift
        let flights = started.compactMap { leg -> TripSoFar.Flight? in
            // Newest first, so the latest is at the top (best guesses design §3).
            let events = milestones(on: leg).filter { $0.time <= date }.reversed().map {
                TripSoFar.Event(text: FactsWording.listLine(for: $0, calendar: calendar, locale: locale), isEstimate: $0.isEstimate)
            }
            // The flight between its gates is always listed, and set apart (§4).
            let tag = leg.isMoving(at: date) ? FactsWording.inTheAir(isReplay: isReplay) : nil
            guard tag != nil || !events.isEmpty else { return nil }
            return TripSoFar.Flight(id: leg.id, title: FactsWording.flightTitle(leg), tag: tag, events: Array(events))
        }
```

Replace:

```swift
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents, isReplay: isReplay)
        return TripSoFar(flights: flights, totalsTitle: "Trip so far",
                         totals: FactsWording.soFar(totals, dayNumber: dayNumber, totalDays: totalDays, locale: locale))
    }
```

with:

```swift
        // Where the rows already have a "Trip so far" row, it isn't said again under the list (§5).
        let totals = hasTripSoFarRow(at: date) ? nil : FactsWording.soFar(
            TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents, isReplay: isReplay),
            dayNumber: dayNumber, totalDays: totalDays, locale: locale)
        return TripSoFar(flights: flights, totalsTitle: "Trip so far", totals: totals)
    }
```

In `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`:

Replace:

```swift
    // MARK: - In flight (§5.1)
```

with:

```swift
    /// Whether the rows at `date` have a "Trip so far" row: on a drive, and on a layover.
    func hasTripSoFarRow(at date: Date) -> Bool {
        if let leg = tripMap.legInMotion(at: date) { return leg.kind == .drive }
        if isRecapOver(at: date) { return false }
        return !(tripMap.mode == .nextTrip && date < tripMap.span.start)
    }

    // MARK: - In flight (§5.1)
```

- [ ] **Step 3: The list's view.** The flight in the air has a border in the accent colour, and its tag sits beside its name, or under it at the largest text sizes. A guess is lighter and slanted, as well as saying "about", so it doesn't rely on looks alone.

Replace the whole of `Crewluv/Views/TripMap/TripSoFarList.swift` with:

```swift
//
//  TripSoFarList.swift
//  CrewLuve
//
//  The facts dragged all the way up (Stage 2 spec §5.2; best guesses design §3, §4): each flight's events under its
//  name, newest first, then the trip's totals. The flight between its gates has a border and a tag, so it stands
//  out from the flights before it. A best guess is drawn lighter, and slanted.
//

import SwiftUI

struct TripSoFarList: View {
    let tripSoFar: TripSoFar

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(tripSoFar.flights) { flight in
                if let tag = flight.tag {
                    inTheAir(flight, tag: tag)
                } else {
                    section(flight.title, events: flight.events)
                }
            }
            if let totals = tripSoFar.totals {
                section(tripSoFar.totalsTitle, events: [TripSoFar.Event(text: totals, isEstimate: false)])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The flight between its gates: a border around it, with its tag beside its name, or under it where the
    /// text is too large for one line.
    private func inTheAir(_ flight: TripSoFar.Flight, tag: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    title(flight.title)
                    Spacer(minLength: 8)
                    tagLabel(tag)
                }
                VStack(alignment: .leading, spacing: 4) {
                    title(flight.title)
                    tagLabel(tag)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            lines(flight.events)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor, lineWidth: 1.5)
        }
    }

    private func section(_ name: String, events: [TripSoFar.Event]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            title(name)
                .accessibilityAddTraits(.isHeader)
            lines(events)
        }
    }

    private func title(_ name: String) -> some View {
        Text(name)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func tagLabel(_ tag: String) -> some View {
        Text(tag)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15), in: .capsule)
    }

    private func lines(_ events: [TripSoFar.Event]) -> some View {
        ForEach(Array(events.enumerated()), id: \.offset) { _, event in
            Text(event.text)
                .font(.subheadline)
                .italic(event.isEstimate)
                .foregroundStyle(event.isEstimate ? .secondary : .primary)
        }
    }
}
```

---

### Task 4: Todd's run, the commit, and a look

- [ ] **Step 1: Review.** `superpowers:code-reviewer` (sonnet) on Tasks 2 and 3, with the design.

- [ ] **Step 2: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`, with 1,073 tests in the result bundle (1,065 before this plan).

- [ ] **Step 3: Ask to commit,** two commits and the docs:
  - Task 2: `feat(crewluv): while the real plane is out of sight the facts tell their best guess in plain words, from where the map flies it on, with "about" before a guessed time and a line saying where it was last seen (best guesses design §2, §3)`
  - Task 3: `feat(crewluv): the facts' list puts the newest event first, sets the flight in the air apart with a border and "In the air now", and says "Trip so far" once (best guesses design §4)`
  - The design and this plan: `docs(crewluv): the best guesses design and its plan`

- [ ] **Step 4: Todd looks,** in the previews and on the flight of 16 Nov:
  - The sheet pulled all the way up: the flight in the air has a border and "In the air now", and its newest event is at the top.
  - Over the ocean, out of sight: the chip and the first row read the place in plain words, "Last seen near …" is under it, and the list's guessed events say "about" and look lighter.
  - On a layover, "Trip so far" shows once.

## Changes made during execution

- **Todd's run (15 Nov 2026, 10:08 pm EST):** every test of the app with Tasks 2 and 3 in. All 1,073 passed on the iPhone 17 Pro simulator, iOS 26.5, read from the result bundle `Test-Crewluv-2026.11.15_22-08-26--0500.xcresult`: the 1,065 of the run before, and this plan's 8. The files were compared with the tested ones again after it.
- **A test moved from Task 3 to Task 2,** before anything ran: plan 3B-3's test that a crossing nobody saw isn't listed fails once Task 2 is in, so Task 2 rewrites it, and Task 3 rewrites it again for the list's new shape.

## Left for later

- **The latest event shown large on the map,** after the flight.
- **The website,** with the same rules, in its own plan.
- **A guessed event ahead of the plane can move,** or come and go, as the estimate moves. The plane turning up off its great circle moves every guess ahead of it.
- **A guessed event can lead the chip twice.** If the plane is seen again and the straight join puts a crossing it guessed within the last 5 minutes, it leads again for what's left of them.
- **A replay on a stretch nobody saw** reads the place on the straight join, with no "Last seen" line: the line is for a plane past where it was last seen. The list's events there still say "about".
- **The story can be a minute behind the path** (plan 3B-3's rule). Guessed events ahead of the plane can then be a minute's flying off, until the next story.
- **The flight stays "In the air now" while it taxis in,** up to the gate, as the rest of the map has it.
- **Plan 3B-3's last task** (the record, `CLAUDE.md` and the spec) takes in this design too: the Stage 3 spec's §8 still says a crossing nobody saw isn't told.

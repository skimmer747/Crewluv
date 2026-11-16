# The Latest Event, Shown Large (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The newest event of the flight in the air shows large on the card and the full-screen map, with how long ago it was, until the next one.

**Architecture:**
- **`TripFacts.latestEvent(at:)`** gives a `LatestEvent`: its title, when it was, and its sentence for VoiceOver. `FactsWording` writes all three.
- **`LatestEventBanner`** shows it: in the card's top corner, and centred under the full-screen map's pill.
- **`TripFacts.headline(at:includesEvents:)`:** beside the banner, the card's bottom chip and the sheet's first line leave events out. The default is unchanged, so the cases the website shares read as before.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS 26, SwiftUI, XCTest.

**Design:** `docs/superpowers/specs/2026-11-15-crewluve-latest-event-design.md`. Todd's choices (15 Nov 2026): the card and the full-screen map; it stays until the next event.

**How this plan was checked.**
- **A scratch Swift package** with the app target's settings, made from the repo at `c20da62`: 512 XCTest and 71 Swift Testing tests before, 525 and 71 with this plan, all passing, no warnings.
- **16 deliberate breaks,** each caught by a test.
- **The whole app was type-checked and compiled for iOS** with `swiftc` outside Xcode, as it stands after each task: no errors and no warnings.
- **The plan was followed by a script** on the repo at `c20da62`: all 9 files came out the same as the tested ones.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together: nothing critical. Three things were mended: the side panel no longer moves when the banner shows, the banner's title wraps at the largest text sizes, and four tests were added (a flight with no story yet, an early landing, minutes to the nearest, and a time held to a year).
- **Not checked:** nothing ran on a simulator or a device, and no view was seen.

---

## Ground rules

1. **Don't run `xcodebuild` build or test loops.** Todd runs the tests (Task 4).
2. **Never commit without Todd's go-ahead,** and then only this plan's files, by path.
3. **Copy the code as written.** A replacement is exact: if its text isn't in the file once, stop.
4. **Reviewers:** `superpowers:code-reviewer` with `model: "sonnet"`.
5. **Work on `feature/trip-map-live`.** Never stash, reset or switch branches.

## File map

| File | Task | What changes |
|---|---|---|
| `Crewluv/Services/TripMap/Facts/LatestEvent.swift` | 2 | new: the latest event's title, when, and sentence |
| `Crewluv/Services/TripMap/Facts/FactsWording.swift` | 2 | an event's title, when it was, and its sentence |
| `Crewluv/Services/TripMap/Facts/TripFacts.swift` | 2 | `latestEvent(at:)`, the headline without events, and the card's sentence |
| `Crewluv/Views/TripMap/LatestEventBanner.swift` | 3 | new: the banner |
| `Crewluv/Views/TripMap/TripMapCard.swift`, `TripMapScreen.swift` | 3 | the banner on the card and the full-screen map |
| `CrewluvTests/FactsWordingTests.swift`, `TripFactsTests.swift`, `LiveTripFactsTests.swift` | 2 | the tests |

---

### Task 1: Before starting

- [x] **Step 1:** The branch is `feature/trip-map-live`, at `c20da62` or later.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

---

### Task 2: The latest event, worked out and worded

- [x] **Step 1: The tests.** The card's sentence gains the latest event, so the tests that hold the sentence gain it too.

In `CrewluvTests/FactsWordingTests.swift`:

Replace:

```swift
    func test_inTheAir_saysNow_butNotInAReplay() {
```

with:

```swift
    // MARK: - The latest event (latest event design §1)

    func test_eventTitle_eachKind() {
        XCTAssertEqual(FactsWording.eventTitle(for: .crossedInto("Canada")), "Crossed into Canada")
        XCTAssertEqual(FactsWording.eventTitle(for: .outOver("the Pacific")), "Out over the Pacific")
        XCTAssertEqual(FactsWording.eventTitle(for: .halfway), "Halfway")
        XCTAssertEqual(FactsWording.eventTitle(for: .closestToHome(miles: 35)), "Closest to home, 35 mi")
    }

    func test_eventWhen_justNow_thenMinutesAgo_toTheNearest() {
        let crossed = Milestone(kind: .crossedInto("Canada"), time: now)
        XCTAssertEqual(FactsWording.eventWhen(crossed, at: now), "Just now")
        XCTAssertEqual(FactsWording.eventWhen(crossed, at: now.addingTimeInterval(59)), "Just now")
        XCTAssertEqual(FactsWording.eventWhen(crossed, at: now.addingTimeInterval(60)), "1 min ago")
        XCTAssertEqual(FactsWording.eventWhen(crossed, at: now.addingTimeInterval(12 * 60 - 1)), "12 min ago", "to the nearest minute")
        XCTAssertEqual(FactsWording.eventWhen(crossed, at: now.addingTimeInterval(89)), "1 min ago")
        XCTAssertEqual(FactsWording.eventWhen(crossed, at: now.addingTimeInterval(90)), "2 min ago")
        XCTAssertEqual(FactsWording.eventWhen(crossed, at: now.addingTimeInterval(130 * 60)), "2 h 10 min ago")
        XCTAssertEqual(FactsWording.eventWhen(crossed, at: now.addingTimeInterval(2 * 365 * 86_400)), "8760 h ago", "held to a year")
    }

    func test_eventWhen_aBestGuess_saysAbout() {
        let guessed = Milestone(kind: .outOver("the Pacific"), time: now, isEstimate: true)
        XCTAssertEqual(FactsWording.eventWhen(guessed, at: now.addingTimeInterval(20)), "About now")
        XCTAssertEqual(FactsWording.eventWhen(guessed, at: now.addingTimeInterval(40 * 60)), "About 40 min ago")
    }

    func test_eventWhen_inAReplay_isTheClockTime() {
        let crossed = Milestone(kind: .crossedInto("Canada"), time: now)
        let guessed = Milestone(kind: .crossedInto("Canada"), time: now, isEstimate: true)
        let later = now.addingTimeInterval(600)
        XCTAssertEqual(plain(FactsWording.eventWhen(crossed, at: later, isReplay: true, calendar: calendar, locale: locale)), "3:14 PM")
        XCTAssertEqual(plain(FactsWording.eventWhen(guessed, at: later, isReplay: true, calendar: calendar, locale: locale)), "About 3:14 PM")
    }

    func test_spokenLatestEvent_isASentence() {
        let crossed = Milestone(kind: .crossedInto("Canada"), time: now)
        XCTAssertEqual(FactsWording.spokenLatestEvent(crossed, at: now.addingTimeInterval(12 * 60)), "Latest: crossed into Canada, 12 minutes ago.")
        XCTAssertEqual(FactsWording.spokenLatestEvent(crossed, at: now), "Latest: crossed into Canada, just now.")
        let closest = Milestone(kind: .closestToHome(miles: 35), time: now, isEstimate: true)
        XCTAssertEqual(FactsWording.spokenLatestEvent(closest, at: now.addingTimeInterval(3600)), "Latest: closest to home, 35 miles, about 1 hour ago.")
        XCTAssertEqual(FactsWording.spokenLatestEvent(closest, at: now), "Latest: closest to home, 35 miles, about now.")
        let halfway = Milestone(kind: .halfway, time: now)
        XCTAssertEqual(plain(FactsWording.spokenLatestEvent(halfway, at: now.addingTimeInterval(600), isReplay: true, calendar: calendar, locale: locale)),
                       "Latest: halfway, at 3:14 PM.")
    }

    func test_inTheAir_saysNow_butNotInAReplay() {
```

In `CrewluvTests/TripFactsTests.swift`:

Replace:

```swift
    func test_cardSummary_inFlight_addsThePlaceBelow() {
        XCTAssertEqual(plain(equatorFacts().cardSummary(now: at("11:10"), pilotName: "Alex")),
                       "TST1 to E20, over Bravo. Lands at 9:22 AM your time. Estimated from the schedule.")
    }
```

with:

```swift
    func test_cardSummary_inFlight_addsThePlaceBelow_andTheLatestEvent() {
        XCTAssertEqual(plain(equatorFacts().cardSummary(now: at("11:10"), pilotName: "Alex")),
                       "TST1 to E20, over Bravo. Lands at 9:22 AM your time. Estimated from the schedule. Latest: crossed into Bravo, 10 minutes ago.")
        XCTAssertEqual(plain(equatorFacts().cardSummary(now: at("10:50"), pilotName: "Alex")),
                       "TST1 to E20, over Alpha. Lands at 9:22 AM your time. Estimated from the schedule.", "before its first event")
    }

    // MARK: - The latest event (latest event design §1)

    func test_latestEvent_isTheNewest_untilTheNext() throws {
        let facts = equatorFacts()
        XCTAssertNil(facts.latestEvent(at: at("10:59")), "before the first event")
        let crossed = try XCTUnwrap(facts.latestEvent(at: FactsTestData.date("2026-03-20T11:00:30Z")))
        XCTAssertEqual(crossed, LatestEvent(title: "Crossed into Bravo", when: "Just now", sentence: "Latest: crossed into Bravo, just now."))
        XCTAssertEqual(facts.latestEvent(at: at("11:12"))?.when, "12 min ago")
        XCTAssertEqual(facts.latestEvent(at: at("11:44"))?.title, "Crossed into Bravo", "it stays until the next")
        XCTAssertEqual(facts.latestEvent(at: at("11:46"))?.title, "Halfway")
        XCTAssertEqual(facts.latestEvent(at: at("12:10"))?.title, "Out over the Test Sea")
        let closest = try XCTUnwrap(facts.latestEvent(at: at("12:40")))
        XCTAssertEqual(closest.title, "Closest to home, 35 mi")
        XCTAssertEqual(closest.when, "19 min ago")
        XCTAssertEqual(closest.sentence, "Latest: closest to home, 35 miles, 19 minutes ago.")
        XCTAssertNil(facts.latestEvent(at: at("13:30")), "it has reached the gate")
    }

    func test_latestEvent_beforeTheStoryIsReady_isNil_andTheCardSaysNothingOfIt() {
        let facts = equatorFacts(hasStory: false)
        XCTAssertNil(facts.latestEvent(at: at("11:10")))
        XCTAssertEqual(plain(facts.cardSummary(now: at("11:10"), pilotName: "Alex")),
                       "TST1 to E20. Lands at 9:22 AM your time. Estimated from the schedule.")
    }

    func test_latestEvent_inAReplay_saysItsClockTime() {
        var facts = equatorFacts()
        facts.isReplay = true
        XCTAssertEqual(plain(facts.latestEvent(at: at("11:12"))?.when), "7:00 AM")
    }

    func test_latestEvent_onTheGround_isNil() throws {
        let at = TripMapTestLegs.tripStart.addingTimeInterval(12 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: at))
        let facts = TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: nil,
                              stories: Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, LegStory(leg: $0, geography: FactsTestData.equator, home: nil)) }),
                              sunEvents: [:])
        XCTAssertNil(facts.latestEvent(at: at))
    }

    func test_headline_besideTheBanner_leavesEventsOut() {
        let facts = equatorFacts()
        XCTAssertEqual(facts.headline(at: at("11:02")), "Just crossed into Bravo", "as before, where the shared cases read it")
        XCTAssertEqual(facts.headline(at: at("11:02"), includesEvents: false), "Over Bravo")
        XCTAssertEqual(facts.headline(at: at("11:46"), includesEvents: false), "Over Bravo")
        XCTAssertEqual(facts.sheetHeadline(at: at("11:02")), "Over Bravo", "the banner is on the map above the sheet")
    }
```

In `CrewluvTests/LiveTripFactsTests.swift`:

Replace:

```swift
                       "TST1 to E20, 10 minutes ahead of schedule, over Bravo. Lands about 9:11 AM your time.")
    }
```

with:

```swift
                       "TST1 to E20, 10 minutes ahead of schedule, over Bravo. Lands about 9:11 AM your time. Latest: crossed into Bravo, 15 minutes ago.")
    }

    func test_latestEvent_whileOutOfSight_isABestGuess_withAbout() throws {
        // Last seen at 4.375° E at 10:50. By the plan it crossed into Bravo at 10:55.
        let event = try XCTUnwrap(try facts(seenUntil: "10:50", now: "11:01").latestEvent(at: at("11:01")))
        XCTAssertEqual(event, LatestEvent(title: "Crossed into Bravo", when: "About 6 min ago",
                                          sentence: "Latest: crossed into Bravo, about 6 minutes ago."))
    }

    func test_latestEvent_ofAFlightThatLandedEarly_goesAtItsRealGateArrival() throws {
        // Seen down at 20° E at 12:55, ten minutes ahead of the plan: it reaches the gate at 13:02.
        let facts = try facts(seenUntil: "12:53", now: "13:05", landed: true)
        XCTAssertEqual(facts.latestEvent(at: at("12:58"))?.title, "Closest to home, 35 mi")
        XCTAssertNil(facts.latestEvent(at: at("13:03")), "at the gate")
    }

    func test_latestEvent_inAReplay_isTheRecordsNewest_atItsClockTime() throws {
        let seen = try facts(seenUntil: "11:10", isReplay: true)
        XCTAssertEqual(plain(seen.latestEvent(at: at("11:25"))?.when), "6:55 AM")
        XCTAssertNil(seen.latestEvent(at: at("10:50")), "before it crossed")
        let guessed = try facts(seenUntil: "10:50", isReplay: true)
        XCTAssertEqual(plain(guessed.latestEvent(at: at("11:01"))?.when), "About 6:55 AM")
    }
```

Replace:

```swift
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen over Alpha. Lands about 9:11 AM your time.")
```

with:

```swift
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen over Alpha. Lands about 9:11 AM your time. Latest: crossed into Bravo, about 6 minutes ago.")
```

Replace:

```swift
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen near Testville. Lands about 9:11 AM your time.")
```

with:

```swift
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen near Testville. Lands about 9:11 AM your time. Latest: crossed into Bravo, 18 minutes ago.")
```

- [x] **Step 2: The model.**

Create `Crewluv/Services/TripMap/Facts/LatestEvent.swift`:

```swift
//
//  LatestEvent.swift
//  CrewLuve
//
//  The newest event of the flight in the air, as the banner shows it large on the card and the full-screen map
//  (latest event design §1): what it was, and how long ago.
//

nonisolated struct LatestEvent: Equatable, Sendable {
    /// "Crossed into Canada", "Out over the Pacific", "Halfway" or "Closest to home, 35 mi".
    let title: String
    /// "12 min ago", "Just now", or "About 12 min ago" for a best guess. In a replay, its clock time: "10:37 AM".
    let when: String
    /// The banner as VoiceOver reads it, as its own sentence: "Latest: crossed into Canada, 12 minutes ago."
    let sentence: String
}
```

- [x] **Step 3: The words.**

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    /// The tall stop's list: "Crossed into Kansas · 1:12 PM". A best guess reads "about": "Out over the Pacific ·
    /// about 4:05 PM" (best guesses design §2).
    static func listLine(for milestone: Milestone, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = (milestone.isEstimate ? "about " : "") + TripMapWording.clockTime(milestone.time, in: calendar.timeZone, locale: locale)
        switch milestone.kind {
        case .crossedInto(let name): return "Crossed into \(name) · \(time)"
        case .outOver(let name): return "Out over \(name) · \(time)"
        case .halfway: return "Halfway · \(time)"
        case .closestToHome(let miles): return "Closest to home, \(miles) mi · \(time)"
        }
    }
```

with:

```swift
    /// The tall stop's list: "Crossed into Kansas · 1:12 PM". A best guess reads "about": "Out over the Pacific ·
    /// about 4:05 PM" (best guesses design §2).
    static func listLine(for milestone: Milestone, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "\(eventTitle(for: milestone.kind)) · \(clock(of: milestone, calendar: calendar, locale: locale))"
    }

    /// What an event was, on its own: "Crossed into Kansas", "Out over the Atlantic", "Halfway", "Closest to home,
    /// 40 mi". The latest event's banner shows it large (latest event design §1).
    static func eventTitle(for kind: Milestone.Kind) -> String {
        switch kind {
        case .crossedInto(let name): "Crossed into \(name)"
        case .outOver(let name): "Out over \(name)"
        case .halfway: "Halfway"
        case .closestToHome(let miles): "Closest to home, \(miles) mi"
        }
    }

    /// When an event was, under it in the banner: "Just now" in its first minute, then "12 min ago". A best guess
    /// says so: "About now", "About 12 min ago". At a moment of the replay, where "ago" means nothing, its clock
    /// time: "10:37 AM", "About 10:37 AM".
    static func eventWhen(_ milestone: Milestone, at date: Date, isReplay: Bool = false,
                          calendar: Calendar = .current, locale: Locale = .current) -> String {
        let about = milestone.isEstimate ? "About " : ""
        if isReplay {
            return about + TripMapWording.clockTime(milestone.time, in: calendar.timeZone, locale: locale)
        }
        guard let minutes = minutesSince(milestone.time, at: date) else { return milestone.isEstimate ? "About now" : "Just now" }
        return "\(about)\(TripMapWording.minutesText(minutes)) ago"
    }

    /// The banner as VoiceOver reads it: "Latest: crossed into Canada, 12 minutes ago.", "Latest: halfway, about
    /// 40 minutes ago.", or at a moment of the replay "Latest: crossed into Canada, at 10:37 AM."
    static func spokenLatestEvent(_ milestone: Milestone, at date: Date, isReplay: Bool = false,
                                  calendar: Calendar = .current, locale: Locale = .current) -> String {
        let what: String
        switch milestone.kind {
        case .closestToHome(let miles): what = "closest to home, \(miles) miles"
        default:
            let title = eventTitle(for: milestone.kind)
            what = title.prefix(1).lowercased() + title.dropFirst()
        }
        let about = milestone.isEstimate ? "about " : ""
        let when: String
        if isReplay {
            when = "at \(about)\(TripMapWording.clockTime(milestone.time, in: calendar.timeZone, locale: locale))"
        } else if let minutes = minutesSince(milestone.time, at: date) {
            when = "\(about)\(TripMapWording.spokenMinutes(minutes)) ago"
        } else {
            when = milestone.isEstimate ? "about now" : "just now"
        }
        return "Latest: \(what), \(when)."
    }
```

Replace:

```swift
    /// Whole minutes for a length of time, held from a minute to a year, so one that can't be right never
    /// overflows.
```

with:

```swift
    /// "1:12 PM", or "about 1:12 PM" for a best guess.
    private static func clock(of milestone: Milestone, calendar: Calendar, locale: Locale) -> String {
        (milestone.isEstimate ? "about " : "") + TripMapWording.clockTime(milestone.time, in: calendar.timeZone, locale: locale)
    }

    /// The minutes from `time` to `date`, to the nearest, held to a year. Nil under a minute.
    private static func minutesSince(_ time: Date, at date: Date) -> Int? {
        let seconds = date.timeIntervalSince(time)
        guard seconds >= 60 else { return nil }
        return Int(min((seconds / 60).rounded(), 365 * 24 * 60))
    }

    /// Whole minutes for a length of time, held from a minute to a year, so one that can't be right never
    /// overflows.
```

- [x] **Step 4: The facts.**

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. While the real plane is out of sight they're its best guesses, in the same
    /// plain words (best guesses design §2). Nil on the ground and on a drive, where Stage 1's words stay.
    func headline(at date: Date) -> String? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
        let recent = milestones(on: leg).last { $0.time <= date && date.timeIntervalSince($0.time) < Milestone.headlineDuration }
        if let recent {
            return FactsWording.headline(for: recent.kind)
        }
```

with:

```swift
    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. While the real plane is out of sight they're its best guesses, in the same
    /// plain words (best guesses design §2). Nil on the ground and on a drive, where Stage 1's words stay.
    /// - Parameter includesEvents: false beside the latest event's banner, which shows the milestone already
    ///   (latest event design §2).
    func headline(at date: Date, includesEvents: Bool = true) -> String? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
        let recent = milestones(on: leg).last { $0.time <= date && date.timeIntervalSince($0.time) < Milestone.headlineDuration }
        if includesEvents, let recent {
            return FactsWording.headline(for: recent.kind)
        }
```

Replace:

```swift
    /// The sheet's first line: the headline in flight, "Home from 4 days away" after a recap's trip, else Stage 1's.
    func sheetHeadline(at date: Date) -> String {
        if let headline = headline(at: date) { return headline }
```

with:

```swift
    /// The sheet's first line: the headline in flight, "Home from 4 days away" after a recap's trip, else Stage 1's.
    /// The latest event's banner is on the map above it, so the headline here leaves events out.
    func sheetHeadline(at date: Date) -> String {
        if let headline = headline(at: date, includesEvents: false) { return headline }
```

Replace:

```swift
    /// Whether a flight with live data shows, which adsb.lol is credited for (Stage 3 spec §8).
```

with:

```swift
    /// The newest event of the flight between its gates at `date`, for the banner (latest event design §1). Nil on
    /// the ground, on a drive, and before the flight's first event.
    func latestEvent(at date: Date) -> LatestEvent? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
        // By time, not by the way along: a best guess and a sighting can disagree a little.
        guard let newest = milestones(on: leg).filter({ $0.time <= date }).max(by: { $0.time < $1.time }) else { return nil }
        return LatestEvent(
            title: FactsWording.eventTitle(for: newest.kind),
            when: FactsWording.eventWhen(newest, at: date, isReplay: isReplay, calendar: calendar, locale: locale),
            sentence: FactsWording.spokenLatestEvent(newest, at: date, isReplay: isReplay, calendar: calendar, locale: locale))
    }

    /// Whether a flight with live data shows, which adsb.lol is credited for (Stage 3 spec §8).
```

Replace:

```swift
    /// The card as one sentence for VoiceOver.
    func cardSummary(now: Date, pilotName: String) -> String {
        switch tripMap.mode {
        case .inFlight:
            if let leg = tripMap.currentLeg {
```

with:

```swift
    /// The card as one sentence for VoiceOver, and in flight the latest event's banner after it.
    func cardSummary(now: Date, pilotName: String) -> String {
        switch tripMap.mode {
        case .inFlight:
            if let leg = tripMap.currentLeg {
                return [flightSummary(of: leg, now: now), latestEvent(at: now)?.sentence].compactMap { $0 }.joined(separator: " ")
            }
        case .recap:
            return FactsWording.recapSummary(days: tripMap.dayCount(in: calendar), totals: TripTotals.whole(tripMap, sunEvents: sunEvents),
                                             longest: TripTotals.longestFlight(of: tripMap.legs), locale: locale)
        case .onTrip, .nextTrip:
            break
        }
        return TripMapWording.cardSummary(for: tripMap, now: now, pilotName: pilotName, calendar: calendar, locale: locale)
    }

    /// The flight in the air as one sentence: where it is and when it lands.
    private func flightSummary(of leg: MapLeg, now: Date) -> String {
```

Replace:

```swift
                let plane = leg.plane(at: now, isReplay: isReplay)
                let below = stories[leg.id]?.place(atDistance: plane.distance)?.name
                // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9), and
                // while it's out of sight, where it was last seen (§15).
                let lastSeen = plane.unseenFor.map { ago -> String in
                    let seen = lastSeenPlace(on: leg)
                    return FactsWording.lastSeen(seen.place, near: seen.city, ago: ago)
                }
                if let live = TripMapWording.liveSummary(for: leg, over: below, lastSeen: lastSeen, now: now,
                                                         calendar: calendar, locale: locale) {
                    return live
                }
                let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
                let over = below.map { ", over \($0)" } ?? ""
                let landing = TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale)
                return "\(lead) \(leg.destination.name)\(over). Lands at \(landing) your time. Estimated from the schedule."
            }
        case .recap:
            return FactsWording.recapSummary(days: tripMap.dayCount(in: calendar), totals: TripTotals.whole(tripMap, sunEvents: sunEvents),
                                             longest: TripTotals.longestFlight(of: tripMap.legs), locale: locale)
        case .onTrip, .nextTrip:
            break
        }
        return TripMapWording.cardSummary(for: tripMap, now: now, pilotName: pilotName, calendar: calendar, locale: locale)
    }
```

with:

```swift
        let plane = leg.plane(at: now, isReplay: isReplay)
        let below = stories[leg.id]?.place(atDistance: plane.distance)?.name
        // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9), and while
        // it's out of sight, where it was last seen (§15).
        let lastSeen = plane.unseenFor.map { ago -> String in
            let seen = lastSeenPlace(on: leg)
            return FactsWording.lastSeen(seen.place, near: seen.city, ago: ago)
        }
        if let live = TripMapWording.liveSummary(for: leg, over: below, lastSeen: lastSeen, now: now,
                                                 calendar: calendar, locale: locale) {
            return live
        }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        let over = below.map { ", over \($0)" } ?? ""
        let landing = TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale)
        return "\(lead) \(leg.destination.name)\(over). Lands at \(landing) your time. Estimated from the schedule."
    }
```

---

### Task 3: The banner on the card and the full-screen map

No tests: SwiftUI. Type-checked for iOS with the rest of the app.

- [x] **Step 1: The banner.**

Create `Crewluv/Views/TripMap/LatestEventBanner.swift`:

```swift
//
//  LatestEventBanner.swift
//  CrewLuve
//
//  The newest event of the flight in the air, shown large (latest event design §1): on the card's map in its top
//  corner, and on the full-screen map under the pill. It stays until the next event.
//

import SwiftUI

struct LatestEventBanner: View {
    let event: LatestEvent
    /// Leading on the card, centred under the full-screen map's pill.
    var alignment: HorizontalAlignment = .leading

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(event.title)
                .font(.headline)
                // A long place name shrinks a little before it's cut off. At the largest text sizes it wraps instead.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
            Text(event.when)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(event.sentence)
    }
}
```

- [x] **Step 2: The card.**

In `Crewluv/Views/TripMap/TripMapCard.swift`:

Replace:

```swift
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let cardChips = chips(from: facts, at: context.date)
            VStack(spacing: 0) {
                mapButton(facts: facts, chips: cardChips, at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(cardChips)
                }
```

with:

```swift
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let cardChips = chips(from: facts, at: context.date)
            let latest = facts.latestEvent(at: context.date)
            VStack(spacing: 0) {
                mapButton(facts: facts, chips: cardChips, latest: latest, at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(cardChips, latest: latest)
                }
```

Replace:

```swift
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
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, camera: $camera, clearance: clearance(for: chips))
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top, height: $topChipHeight) }
```

with:

```swift
    /// Stage 1's chips, with the headline fact on the bottom one in flight. The latest event's banner is at the top,
    /// so the headline leaves events out (latest event design §2).
    private func chips(from facts: TripFacts, at date: Date) -> (top: String?, bottom: String?) {
        let chips = TripMapWording.cardChips(for: tripMap, at: date)
        guard tripMap.isInFlight else { return chips }
        return (chips.top, facts.headline(at: date, includesEvents: false) ?? chips.bottom)
    }

    private func mapButton(facts: TripFacts, chips: (top: String?, bottom: String?), latest: LatestEvent?, at date: Date) -> some View {
        Button {
            isShowingFullScreen = true
        } label: {
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, camera: $camera,
                        clearance: clearance(for: chips, hasBanner: latest != nil))
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { topOverlay(chips.top, latest: latest) }
```

Replace:

```swift
    /// A chip on the map, its height measured into `height`.
```

with:

```swift
    /// The top corner: in flight, the latest event's banner (latest event design §1), else Stage 1's top chip. Its
    /// height is measured into `topChipHeight`.
    @ViewBuilder
    private func topOverlay(_ chip: String?, latest: LatestEvent?) -> some View {
        if let latest, !dynamicTypeSize.isAccessibilitySize {
            LatestEventBanner(event: latest)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topChipHeight = $0 }
                .padding(Self.chipInset)
        } else {
            overlayChip(chip, height: $topChipHeight)
        }
    }

    /// A chip on the map, its height measured into `height`.
```

Replace:

```swift
    /// The band between the chips on the map: from each edge to the far side of its chip, and a gap. With no chip on
    /// the map at an edge, nothing there.
    private func clearance(for chips: (top: String?, bottom: String?)) -> TripMapClearance {
        guard !dynamicTypeSize.isAccessibilitySize else { return .none }
        func depth(of chip: String?, height: CGFloat) -> CGFloat {
            chip == nil ? 0 : Self.chipInset + height + Self.chipGap
        }
        return TripMapClearance(top: depth(of: chips.top, height: topChipHeight),
                                bottom: depth(of: chips.bottom, height: bottomChipHeight))
    }
```

with:

```swift
    /// The band between the chips on the map: from each edge to the far side of its chip, and a gap. With no chip on
    /// the map at an edge, nothing there. The latest event's banner is the top chip while it shows.
    private func clearance(for chips: (top: String?, bottom: String?), hasBanner: Bool) -> TripMapClearance {
        guard !dynamicTypeSize.isAccessibilitySize else { return .none }
        func depth(isShown: Bool, height: CGFloat) -> CGFloat {
            isShown ? Self.chipInset + height + Self.chipGap : 0
        }
        return TripMapClearance(top: depth(isShown: chips.top != nil || hasBanner, height: topChipHeight),
                                bottom: depth(isShown: chips.bottom != nil, height: bottomChipHeight))
    }
```

Replace:

```swift
    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14).
    private func stackedChips(_ chips: (top: String?, bottom: String?)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let top = chips.top {
```

with:

```swift
    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14), the
    /// latest event first.
    private func stackedChips(_ chips: (top: String?, bottom: String?), latest: LatestEvent?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let latest {
                Text("\(latest.title) · \(latest.when)")
                    .font(.headline)
            }
            if let top = chips.top {
```

- [x] **Step 3: The full-screen map.** The camera keeps clear of the banner. Only the top bar pads the side panel, since the banner is centred.

In `Crewluv/Views/TripMap/TripMapScreen.swift`:

Replace:

```swift
    @State private var topBarHeight: CGFloat = 0
```

with:

```swift
    @State private var topBarHeight: CGFloat = 0
    /// The bottom of the top bar and the latest event's banner under it, in window coordinates.
    @State private var topChromeBottom: CGFloat = 0
```

Replace:

```swift
    private func screen(time: Date, now: Date, facts: TripFacts, timeline: TripTimeline) -> some View {
        let base = ZStack(alignment: .top) {
            // The camera frames the trip in what the sheet or the panel leaves clear.
            TripMapView(tripMap: tripMap, date: time, style: style, camera: $camera,
                        clearance: TripMapClearance(leading: mapLeadingClearance, bottom: mapBottomClearance),
                        isFullScreen: true, isReplay: !clock.isLive)
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
        }
```

with:

```swift
    private func screen(time: Date, now: Date, facts: TripFacts, timeline: TripTimeline) -> some View {
        let latest = facts.latestEvent(at: time)
        let base = ZStack(alignment: .top) {
            // The camera frames the trip in what the sheet or the panel leaves clear, and under the latest event.
            TripMapView(tripMap: tripMap, date: time, style: style, camera: $camera,
                        clearance: TripMapClearance(top: latest == nil ? 0 : mapTopClearance, leading: mapLeadingClearance,
                                                    bottom: mapBottomClearance),
                        isFullScreen: true, isReplay: !clock.isLive)
                .ignoresSafeArea()
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            topChrome(time: time, latest: latest)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { topChromeBottom = $0 }
        }
```

Replace:

```swift
    private func topBar(time: Date) -> some View {
```

with:

```swift
    /// The top bar, and in flight the latest event's banner under its pill (latest event design §1). Only the bar
    /// pads the side panel: the banner is centred, clear of it.
    private func topChrome(time: Date, latest: LatestEvent?) -> some View {
        VStack(spacing: 8) {
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
            if let latest {
                LatestEventBanner(event: latest, alignment: .center)
                    .padding(.horizontal)
            }
        }
    }

    private func topBar(time: Date) -> some View {
```

Replace:

```swift
    /// From the screen's leading edge to the panel's trailing edge, open or folded, with its padding.
```

with:

```swift
    /// From the screen's top edge to a little below the latest event's banner.
    private var mapTopClearance: CGFloat {
        max(0, topChromeBottom - screenFrame.minY) + 8
    }

    /// From the screen's leading edge to the panel's trailing edge, open or folded, with its padding.
```

---

### Task 4: Todd's run, the commit, and a look

- [x] **Step 1: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`, with 1,086 tests in the result bundle (1,073 before).

- [ ] **Step 2: Ask to commit:** Task 2, Task 3, and the design with this plan.

- [ ] **Step 3: Todd looks,** in the previews and in flight: the banner in the card's top corner and under the full-screen map's pill, the bottom chip not repeating it, and at the largest text size the banner under the card's map.

## Changes made during execution

- **Todd's run (15 Nov 2026, 10:32 pm EST):** every test of the app with Tasks 2 and 3 in. All 1,086 passed on the iPhone 17 Pro simulator, iOS 26.5, read from the result bundle `Test-Crewluv-2026.11.15_22-31-59--0500.xcresult`: the 1,073 of the run before, and this plan's 13. The files were compared with the tested ones again after it.


## Left for later

- **A flag on the map where the event happened.**
- **The website.**
- **The map can move a little when the banner appears and goes,** at the flight's first event and at the gate, as it makes room. It doesn't move if the family has moved the map themselves.
- **"Just now" can show for up to 70 seconds** on the card, which updates every 10.

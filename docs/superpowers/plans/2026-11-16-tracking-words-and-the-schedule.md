# "Tracked", Not "Seen", "About" on the Schedule, and the Review's Fixes (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A plane out of reach of the receivers reads "Out of tracking range" and "Last tracked", never "seen", so no family fears it's missing; the schedule's list says "about" before an arrival that's the real plane's estimate, as the website's does; and the fixes from plan 3B-3's whole-branch review go in.

**Architecture:**
- **The words** stay where they are: `PlanePopupWords`, `FactsWording.lastSeenLine` and `TripMapWording.liveSummary`. The code's names keep "seen", as they say what the receivers saw. `TripFacts.flightSummary` says a place once when it's both what's below and where the plane was last tracked.
- **The schedule's "about":** `LiveLegs.estimatedArrivals(in:flights:)` names the legs whose arrival is the real plane's estimate, by `isArrivalEstimated`, the rule every card uses. `EventTimelineView` hands it to each `TimelineRowView`.
- **The review's fixes:** beside the side panel the full-screen map's banner is centred over the open map; `LegStoryStore` makes a real path's story again for a new home; `TripSoFarList` keeps each line by its words.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, iOS 26, SwiftUI, XCTest.

**Sources:**
- **Todd's choice (16 Nov 2026):** "Tracking": the popup's "Out of tracking range since 7:41 PM, so it's shown where it should be by now", and the facts' "Last tracked over the Bering Sea · 3 h 41 min ago". "Not seen since" and "Last seen" could make a family fear the plane was missing. It's the receivers that lose it, not air traffic control.
- **The website's plan 3C-3, Task 9** (Crewluve Website repo, `docs/superpowers/plans/2026-11-16-moving-map-stage3c3-website-facts.md`): the Schedule page's "7:00am est – about 9:10am est", which Todd approved for the website. The app's rows write their times the same way.
- **Plan 3B-3's whole-branch review** (16 Nov 2026), recorded in Task 5.

**How this plan was checked.**
- **A scratch Swift package** with the app target's settings, made from the repo at `430d5fb`: 577 XCTest and 71 Swift Testing tests before, 582 and 71 with this plan, all passing, no warnings.
- **Task by task:** the package was kept as it stood after each of Tasks 2 to 4 and run each time, all passing: 579 XCTest tests after Task 2, 580 after Task 3 and 582 after Task 4.
- **14 deliberate breaks** were made in the new code, one at a time, and every one fails at least one test: each of the old words put back, the place said twice or a place dropped, places compared by name alone, every or no flight given "about", the story's key without home, and the list's lines numbered wrong.
- **The whole app was type-checked for iOS** with `swiftc` outside Xcode after each task, and compiled for the iOS simulator with the whole plan in: no errors and no warnings.
- **The plan was followed by a script** on the repo at `430d5fb`: all 23 files came out the same as the tested ones.
- **Reviewed** by `superpowers:code-reviewer` (sonnet) before the plan was put together: nothing critical. Two important points were mended: beside the side panel the banner's inset is the panel's width, which reads the same either way round, in place of a left-to-right measurement that would have squeezed it in a right-to-left language (the map's leading clearance had the same flaw, and is mended with it); and each line of the list has its own id, its place among its flight's events, since two can read the same. From its minor points: the card's sentence compares the places, not their words, and a test line that proved nothing went. Left, with reasons: a home change also makes the flight's sun events again, which is harmless and rare; the schedule works out its estimates once a section, a handful of times.
- **Not checked:** nothing ran on a simulator or a device, and no view was seen: the banner beside the side panel, the schedule's rows and the list.

**Where this plan settles details.**
- **"Shown",** not "drawn", in the popup: the words a family reads, as Todd's answer had it.
- **The card's sentence says a place once:** where what's below is the place the plane was last tracked over, "…, last tracked over Québec." It still says the plane is out of range. The places are compared by name, kind and country, as the website compares them, so a country and a province that share a name are both said.
- **The schedule's "about"** reads the legs as the status screen carries them, as every card does, so it's on exactly the flight whose cards say "about".
- **The banner beside the side panel** is centred over the open map, as the website's is. The map's leading clearance now reads right to left too.

---

## Ground rules

1. **Don't run `xcodebuild` build or test loops.** Todd runs the tests (Task 6).
2. **Never commit without Todd's go-ahead,** and then only this plan's files, by path. **Never push** without a fresh yes.
3. **Copy the code as written.** A replacement is exact: if its text isn't in the file once, stop.
4. **Work on `feature/trip-map-live`.** Never stash, reset or switch branches.

## File map

| File | Task | What changes |
|---|---|---|
| `Crewluv/Services/TripMap/PlanePopupWords.swift`, `Crewluv/Views/TripMap/PlanePopup.swift`, `Crewluv/Services/TripMap/Facts/FactsWording.swift`, `Crewluv/Services/TripMap/TripMapWording.swift`, `Crewluv/Services/TripMap/Facts/TripFacts.swift` | 2 | "Out of tracking range" and "Last tracked", and a place said once |
| `CLAUDE.md`, `docs/superpowers/specs/2026-11-15-crewluve-facts-best-guesses-design.md`, `2026-11-14-crewluve-moving-map-stage3-live-design.md`, `2026-11-16-crewluve-which-plane-design.md` | 2 | the words they quote |
| `Crewluv/Services/TripMap/Live/LiveLegs.swift`, `Crewluv/Views/Schedule/EventTimelineView.swift`, `TimelineRowView.swift` | 3 | "about" on the schedule |
| `Crewluv/Views/TripMap/TripMapScreen.swift`, `Crewluv/Services/TripMap/Facts/LegStoryStore.swift`, `TripSoFar.swift`, `TripFacts.swift`, `Crewluv/Views/TripMap/TripSoFarList.swift` | 4 | the review's fixes |
| `CrewluvTests/FactsWordingTests.swift`, `PlanePopupWordsTests.swift`, `LiveTripFactsTests.swift`, `LiveWordingTests.swift`, `LiveLegsTests.swift`, `LegStoryStoreTests.swift` | 2, 3, 4 | the tests |
| `docs/superpowers/plans/2026-11-15-moving-map-stage3b3-app-facts.md` | 5 | plan 3B-3's record of its review |

---

### Task 1: Before starting

- [x] **Step 1:** The branch is `feature/trip-map-live`, at `430d5fb` or later, and none of this plan's files has changed since.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

---

### Task 2: "Out of tracking range" and "Last tracked"

- [x] **Step 1: The tests.**

In `CrewluvTests/FactsWordingTests.swift`:

Replace:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(place, near: city, ago: 600), "Last seen near Montréal · 10 min ago")
```

with:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(place, near: city, ago: 600), "Last tracked near Montréal · 10 min ago")
```

Replace:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(place, near: nil, ago: 7_800), "Last seen over Québec · 2 h 10 min ago")
```

with:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(place, near: nil, ago: 7_800), "Last tracked over Québec · 2 h 10 min ago")
```

Replace:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: 7_200), "Last seen 2 h ago")
```

with:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: 7_200), "Last tracked 2 h ago")
```

Replace:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: .infinity), "Last seen 8760 h ago")
```

with:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: .infinity), "Last tracked 8760 h ago")
```

Replace:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: 20), "Last seen 1 min ago")
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: -500), "Last seen 1 min ago")
```

with:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: 20), "Last tracked 1 min ago")
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: -500), "Last tracked 1 min ago")
```

Replace:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: .nan), "Last seen 1 min ago")
```

with:

```swift
        XCTAssertEqual(FactsWording.lastSeenLine(nil, near: nil, ago: .nan), "Last tracked 1 min ago")
```

In `CrewluvTests/PlanePopupWordsTests.swift`:

Replace:

```swift
                                       lines: ["Not seen since 7:41 AM, so it's drawn where it should be by now",
```

with:

```swift
                                       lines: ["Out of tracking range since 7:41 AM, so it's shown where it should be by now",
```

Replace:

```swift
    func test_fadedPlane_isABestGuess_saysWhenItWasLastSeen_andLandsAbout() throws {
```

with:

```swift
    func test_fadedPlane_isABestGuess_saysWhenItWentOutOfTrackingRange_andLandsAbout() throws {
```

In `CrewluvTests/LiveTripFactsTests.swift`:

Replace:

```swift
        XCTAssertEqual(plain(below.detail), "Last seen over Bravo · 10 min ago · Passes 35 mi from home at about 8:07 AM")
```

with:

```swift
        XCTAssertEqual(plain(below.detail), "Last tracked over Bravo · 10 min ago · Passes 35 mi from home at about 8:07 AM")
```

Replace:

```swift
        XCTAssertEqual(plain(try row(.below, in: byACity).detail), "Last seen near Testville · 10 min ago · Passes 35 mi from home at about 8:07 AM")
```

with:

```swift
        XCTAssertEqual(plain(try row(.below, in: byACity).detail), "Last tracked near Testville · 10 min ago · Passes 35 mi from home at about 8:07 AM")
```

Replace:

```swift
        XCTAssertEqual(try row(.below, in: noPlace).title, "Last seen 10 min ago")
```

with:

```swift
        XCTAssertEqual(try row(.below, in: noPlace).title, "Last tracked 10 min ago")
```

Replace:

```swift
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen over Alpha. Lands about 9:11 AM your time. Latest: crossed into Bravo, about 6 minutes ago.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:03", now: "11:13").cardSummary(now: at("11:13"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last seen near Testville. Lands about 9:11 AM your time. Latest: crossed into Bravo, 18 minutes ago.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:10", now: "11:20", hasStory: false).cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last seen 10 minutes ago. Lands about 9:11 AM your time.")
    }
```

with:

```swift
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last tracked over Alpha. Lands about 9:11 AM your time. Latest: crossed into Bravo, about 6 minutes ago.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:03", now: "11:13").cardSummary(now: at("11:13"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last tracked near Testville. Lands about 9:11 AM your time. Latest: crossed into Bravo, 18 minutes ago.")
        XCTAssertEqual(plain(try facts(seenUntil: "11:10", now: "11:20", hasStory: false).cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last tracked 10 minutes ago. Lands about 9:11 AM your time.")
    }

    func test_cardSummary_whileOutOfSightOverWhereItWasLastTracked_saysThePlaceOnce() throws {
        // Last tracked over Bravo at 11:10, at 6.875° E, and by the plan still over Bravo at 11:20, at 8.125° E, with
        // no city near either.
        XCTAssertEqual(plain(try facts(seenUntil: "11:10", now: "11:20").cardSummary(now: at("11:20"), pilotName: "Alex")),
                       "TST1 to E20, about 10 minutes ahead of schedule, last tracked over Bravo. Lands about 9:11 AM your time. Latest: crossed into Bravo, 25 minutes ago.")
    }

    func test_cardSummary_whileOutOfSightOverAnotherPlaceOfTheSameName_saysBoth() throws {
        // A country called Bravo to 7.5° E, and past it a province of another country, also called Bravo. Last
        // tracked over the country at 6.875° E, the plane is over the province by 11:20, at 8.125° E.
        let twoBravos = Geography(areas: [FactsTestData.box("Alpha", .country, west: -1, east: 5),
                                          FactsTestData.box("Bravo", .country, west: 5, east: 7.5),
                                          FactsTestData.box("Bravo", .province, country: "Charlie", west: 7.5, east: 12),
                                          FactsTestData.box("the Test Sea", .water, west: 12, east: 21)],
                                  cities: [])
        let leg = try FactsTestData.equatorLiveLeg(FactsTestData.equatorLive(seenUntil: at("11:10")), at: at("11:20"))
        let home = FactsTestData.homeByTheEquator
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        let facts = TripFacts(tripMap: map, geography: twoBravos, comparisons: nil,
                              stories: [leg.id: LegStory(leg: leg, geography: twoBravos, home: home)], sunEvents: [:],
                              calendar: calendar, locale: locale)
        XCTAssertTrue(try XCTUnwrap(plain(facts.cardSummary(now: at("11:20"), pilotName: "Alex")))
                        .hasPrefix("TST1 to E20, about 10 minutes ahead of schedule, over Bravo, last tracked over Bravo. "))
    }
```

In `CrewluvTests/LiveWordingTests.swift`:

Replace:

```swift
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, over Ohio, last seen near Columbus. Lands about 8:30 AM your time.")
```

with:

```swift
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, over Ohio, last tracked near Columbus. Lands about 8:30 AM your time.")
```

Replace:

```swift
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, last seen 12 minutes ago. Lands about 8:30 AM your time.")
```

with:

```swift
                       "UPS207 to Philadelphia, about 14 minutes ahead of schedule, last tracked 12 minutes ago. Lands about 8:30 AM your time.")
```

- [x] **Step 2: The words.**

In `Crewluv/Services/TripMap/PlanePopupWords.swift`:

Replace:

```swift
            let seen = flight.live?.fix.map { "Not seen since \(time($0.seenAt)), so it's drawn where it should be by now" }
```

with:

```swift
            let seen = flight.live?.fix.map { "Out of tracking range since \(time($0.seenAt)), so it's shown where it should be by now" }
```

In `Crewluv/Views/TripMap/PlanePopup.swift`:

Replace:

```swift
                                      lines: ["Not seen since 4:05 PM, so it's drawn where it should be by now",
```

with:

```swift
                                      lines: ["Out of tracking range since 4:05 PM, so it's shown where it should be by now",
```

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    /// Under what's below, while the real plane is out of sight: "Last seen near Montréal · 12 min ago", by a
    /// city of a million or more, else "Last seen over Québec · 12 min ago", else "Last seen 12 min ago". It's the
    /// one line that says the place above it is worked out, not seen (best guesses design §2).
    static func lastSeenLine(_ place: Geography.Place?, near city: Geography.City?, ago: TimeInterval) -> String {
        let time = "\(TripMapWording.minutesText(minutes(ago: ago))) ago"
        if let city { return "Last seen near \(city.name) · \(time)" }
        if let place { return "Last seen over \(place.name) · \(time)" }
        return "Last seen \(time)"
    }
```

with:

```swift
    /// Under what's below, while the real plane is out of tracking range: "Last tracked near Montréal · 12 min ago",
    /// by a city of a million or more, else "Last tracked over Québec · 12 min ago", else "Last tracked 12 min ago".
    /// It's the one line that says the place above it is worked out (best guesses design §2). "Tracked", never
    /// "seen": it's the receivers that lose the plane, not air traffic control, and a family shouldn't fear it's
    /// missing.
    static func lastSeenLine(_ place: Geography.Place?, near city: Geography.City?, ago: TimeInterval) -> String {
        let time = "\(TripMapWording.minutesText(minutes(ago: ago))) ago"
        if let city { return "Last tracked near \(city.name) · \(time)" }
        if let place { return "Last tracked over \(place.name) · \(time)" }
        return "Last tracked \(time)"
    }
```

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
        let over = isFlying ? (place.map { ", over \($0)" } ?? "") + (lastSeen.map { ", last seen \($0)" } ?? "") : ""
```

with:

```swift
        let over = isFlying ? (place.map { ", over \($0)" } ?? "") + (lastSeen.map { ", last tracked \($0)" } ?? "") : ""
```

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
    /// "Last seen near Montréal · 12 min ago", while the real plane is out of sight, or nil while it's seen.
```

with:

```swift
    /// "Last tracked near Montréal · 12 min ago", while the real plane is out of tracking range, or nil while it's seen.
```

Replace:

```swift
        let below = stories[leg.id]?.place(atDistance: plane.distance)?.name
```

with:

```swift
        let belowPlace = stories[leg.id]?.place(atDistance: plane.distance)
        let below = belowPlace?.name
```

Replace:

```swift
        let lastSeen = plane.unseenFor.map { ago -> String in
            let seen = lastSeenPlace(on: leg)
            return FactsWording.lastSeen(seen.place, near: seen.city, ago: ago)
        }
        if let live = TripMapWording.liveSummary(for: leg, over: below, lastSeen: lastSeen, now: now,
                                                 calendar: calendar, locale: locale) {
```

with:

```swift
        let unseen = plane.unseenFor.map { (seen: lastSeenPlace(on: leg), ago: $0) }
        let lastSeen = unseen.map { FactsWording.lastSeen($0.seen.place, near: $0.seen.city, ago: $0.ago) }
        // "Over Québec, last tracked over Québec" says one place twice: the second says it all.
        let isOverWhereLastTracked = unseen.map { $0.seen.city == nil && $0.seen.place.map { $0 == belowPlace } == true } ?? false
        if let live = TripMapWording.liveSummary(for: leg, over: isOverWhereLastTracked ? nil : below, lastSeen: lastSeen,
                                                 now: now, calendar: calendar, locale: locale) {
```

- [x] **Step 3: The docs that quote them.**

In `CLAUDE.md`:

Replace:

```swift
- The facts on the real path (plan `docs/superpowers/plans/2026-11-15-moving-map-stage3b3-app-facts.md`, Stage 3 spec §8, best guesses design `docs/superpowers/specs/2026-11-15-crewluve-facts-best-guesses-design.md`). `MapLeg.plane(at:isReplay:)` is where the facts have the plane (`PlanePosition`): the real one wherever the map draws it, by `FlightDrawing`'s rule, which `PlanePositionTests` holds it to. `MapLeg+Course.swift` gives a leg its path and its times, by its record or by the schedule. `MapLeg`'s own `progress(at:)` and `position(at:)` stay the schedule's. `LegStory` is made along the leg's path and read by distance, since a real path grows. Every event is told: one where nobody saw the plane (`MapLeg.isSeen(atDistance:)`) is a best guess (`Milestone.isEstimate`), and its time reads "about". A plane out of sight is read where the map flies it on, in the same plain words, with "Last seen near …" under it. `LegStoryStore` makes a real path's story again as the path grows, at most once a minute, and keeps one set of sun events to a flight, which shows until the next is ready: don't key them by the leg's times again, or the sky row blinks at each new landing estimate. The plane's row is `AircraftTypeNames`' name and the registration, with the height and speed only while the plane is seen in the air now. `TripFacts.isReplay` says the moments are a replay's. adsb.lol is credited under the facts (`FactsFooter`) whenever a flight with live data shows
```

with:

```swift
- The facts on the real path (plan `docs/superpowers/plans/2026-11-15-moving-map-stage3b3-app-facts.md`, Stage 3 spec §8, best guesses design `docs/superpowers/specs/2026-11-15-crewluve-facts-best-guesses-design.md`). `MapLeg.plane(at:isReplay:)` is where the facts have the plane (`PlanePosition`): the real one wherever the map draws it, by `FlightDrawing`'s rule, which `PlanePositionTests` holds it to. `MapLeg+Course.swift` gives a leg its path and its times, by its record or by the schedule. `MapLeg`'s own `progress(at:)` and `position(at:)` stay the schedule's. `LegStory` is made along the leg's path and read by distance, since a real path grows. Every event is told: one where nobody saw the plane (`MapLeg.isSeen(atDistance:)`) is a best guess (`Milestone.isEstimate`), and its time reads "about". A plane out of sight is read where the map flies it on, in the same plain words, with "Last tracked near …" under it ("tracked", never "seen", so a family doesn't fear the plane is missing). `LegStoryStore` makes a real path's story again as the path grows, at most once a minute, and keeps one set of sun events to a flight, which shows until the next is ready: don't key them by the leg's times again, or the sky row blinks at each new landing estimate. The plane's row is `AircraftTypeNames`' name and the registration, with the height and speed only while the plane is seen in the air now. `TripFacts.isReplay` says the moments are a replay's. adsb.lol is credited under the facts (`FactsFooter`) whenever a flight with live data shows
```

In `docs/superpowers/specs/2026-11-15-crewluve-facts-best-guesses-design.md`:

Replace:

```swift
- **One line says it's an estimate:** "Last seen near Anchorage · 2 h 10 min ago", by a city of a million or more, else "Last seen over Alaska · 2 h 10 min ago", else "Last seen 2 h 10 min ago". It's in the first row of the sheet, under what's below.
```

with:

```swift
- **One line says it's an estimate:** "Last tracked near Anchorage · 2 h 10 min ago", by a city of a million or more, else "Last tracked over Alaska · 2 h 10 min ago", else "Last tracked 2 h 10 min ago". It's in the first row of the sheet, under what's below. ("Last tracked" since 16 Nov 2026, in place of "Last seen", which Todd found could make a family fear the plane was missing. It's the receivers that lose it, not air traffic control.)
```

Replace:

```swift
- **VoiceOver:** "UPS207 to Cologne, about 12 minutes ahead of schedule, over the Atlantic, last seen near Montréal. Lands about 3:18 PM your time."
```

with:

```swift
- **VoiceOver:** "UPS207 to Cologne, about 12 minutes ahead of schedule, over the Atlantic, last tracked near Montréal. Lands about 3:18 PM your time." Where what's below is where it was last tracked, it's said once: "…, last tracked over Québec."
```

In `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`:

Replace:

```swift
  - estimated: looked up where the map draws the faded plane, flown on from the last place it was seen along the great circle, in the same plain words. Under it, "Last seen near Gander · 2 h 10 min ago", by the place under the last fix, else "Last seen over Newfoundland · …", else "Last seen 2 h 10 min ago" (best guesses design §2);
```

with:

```swift
  - estimated: looked up where the map draws the faded plane, flown on from the last place it was seen along the great circle, in the same plain words. Under it, "Last tracked near Gander · 2 h 10 min ago", by the place under the last fix, else "Last tracked over Newfoundland · …", else "Last tracked 2 h 10 min ago" (best guesses design §2);
```

Replace:

```swift
- **The card** is one VoiceOver element with §9's sentence. While estimated it says "about" and "last seen near Gander". What's below and where it was last seen are said only while the plane flies, not at its gate nor once it's down (which plane design §4), and the sentence ends with the latest event: "Latest: crossed into Canada, 12 minutes ago." (latest event design §3).
```

with:

```swift
- **The card** is one VoiceOver element with §9's sentence. While estimated it says "about" and "last tracked near Gander". What's below and where it was last seen are said only while the plane flies, not at its gate nor once it's down (which plane design §4), and the sentence ends with the latest event: "Latest: crossed into Canada, 12 minutes ago." (latest event design §3).
```

In `docs/superpowers/specs/2026-11-16-crewluve-which-plane-design.md`:

Replace:

```swift
| The real plane, estimated (faded) | {flight} · best guess | Not seen since {seen}, so it's drawn where it should be by now / {label} · lands {about}{landing} |
```

with:

```swift
| The real plane, estimated (faded) | {flight} · best guess | Out of tracking range since {seen}, so it's shown where it should be by now / {label} · lands {about}{landing} |
```

---

### Task 3: "About" on the schedule

- [x] **Step 1: The test.**

In `CrewluvTests/LiveLegsTests.swift`:

Replace:

```swift
        XCTAssertTrue(LiveLegs.isArrivalEstimated(of: read[0], in: made), "it's still marked an estimate after the status carried it")
        XCTAssertEqual(LiveLegs.blob(replaced), blob, "the same legs, the same bytes")
    }
}
```

with:

```swift
        XCTAssertTrue(LiveLegs.isArrivalEstimated(of: read[0], in: made), "it's still marked an estimate after the status carried it")
        XCTAssertEqual(LiveLegs.blob(replaced), blob, "the same legs, the same bytes")
    }

    // MARK: - The schedule's "about"

    @MainActor
    func test_estimatedArrivals_areTheLegsWhoseArrivalIsTheRealPlanesEstimate_asTheStatusCarriesThem() throws {
        let cases = try TripMapFixtures.liveCases()
        func estimated(_ name: String, at time: String) throws -> Set<String> {
            let flightCase = try cases.flight(named: name)
            let moment = try cases.moment(time, of: flightCase)
            let legs = [cases.tripLeg(flightCase)]
            let made = flights(cases, for: legs, answered: cases.live(flightCase).map { ["f1": $0] } ?? [:])
            return LiveLegs.estimatedArrivals(in: readBack(LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)), flights: made)
        }
        XCTAssertEqual(try estimated("ahead, in the air", at: "13T12:41:50"), ["f1"])
        XCTAssertEqual(try estimated("still on the ground twenty minutes after", at: "13T12:35:00"), ["f1"])
        XCTAssertEqual(try estimated("landed, seen all the way", at: "13T13:30:00"), [], "a landed plane's arrival is real")
        XCTAssertEqual(try estimated("on the ground before the plan's takeoff", at: "13T12:10:00"), [], "still the plan's")
        XCTAssertEqual(try estimated("no live data", at: "13T12:30:00"), [])
    }
}
```

- [x] **Step 2: Which arrivals are estimates.**

In `Crewluv/Services/TripMap/Live/LiveLegs.swift`:

Replace:

```swift
    /// When the flight between its gates at `now` reaches its gate, while that time is the real plane's estimate:
```

with:

```swift
    /// The legs whose gate arrival, as `legs` show it, is the real plane's estimate, by id: the schedule's list says
    /// "about" before it, "7:00am est – about 9:10am est", as the status screen does (Stage 3 spec §9).
    static func estimatedArrivals(in legs: [TripLeg], flights: [String: MapFlight]) -> Set<String> {
        guard !flights.isEmpty else { return [] }
        return Set(legs.filter { isArrivalEstimated(of: $0, in: flights) }.map(\.id))
    }

    /// When the flight between its gates at `now` reaches its gate, while that time is the real plane's estimate:
```

- [x] **Step 3: The rows.** No tests: SwiftUI.

In `Crewluv/Views/Schedule/EventTimelineView.swift`:

Replace:

```swift
    private var legs: [TripLeg] {
        LiveLegs.forTheSchedule(status.tripLegs, with: flights).sorted { $0.startTime < $1.startTime }
    }
```

with:

```swift
    private var legs: [TripLeg] {
        LiveLegs.forTheSchedule(status.tripLegs, with: flights).sorted { $0.startTime < $1.startTime }
    }

    /// The legs whose arrival is the real plane's estimate, by id: their rows say "about" before it.
    private var estimatedArrivals: Set<String> {
        LiveLegs.estimatedArrivals(in: status.tripLegs, flights: flights)
    }
```

Replace:

```swift
    private func sectionContent(_ section: DateSection, upNextID: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(section.legs.enumerated()), id: \.element.id) { index, leg in
                TimelineRowView(
                    leg: leg,
                    homeAirportCode: status.homeAirportCode,
                    baseAirportCode: status.baseAirportCode,
                    isUpNext: leg.id == upNextID
                )
```

with:

```swift
    private func sectionContent(_ section: DateSection, upNextID: String?) -> some View {
        let estimatedArrivals = self.estimatedArrivals
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(section.legs.enumerated()), id: \.element.id) { index, leg in
                TimelineRowView(
                    leg: leg,
                    homeAirportCode: status.homeAirportCode,
                    baseAirportCode: status.baseAirportCode,
                    isUpNext: leg.id == upNextID,
                    isArrivalEstimated: estimatedArrivals.contains(leg.id)
                )
```

In `Crewluv/Views/Schedule/TimelineRowView.swift`:

Replace:

```swift
    var baseAirportCode: String?
    var isUpNext: Bool = false
```

with:

```swift
    var baseAirportCode: String?
    var isUpNext: Bool = false
    /// The arrival is the real plane's estimate: it reads "about" (Stage 3 spec §9).
    var isArrivalEstimated = false
```

Replace:

```swift
        let end = fmt.string(from: leg.endTime).lowercased()
        return "\(start) \(tzAbbr) – \(end) \(tzAbbr)"
```

with:

```swift
        let end = fmt.string(from: leg.endTime).lowercased()
        return "\(start) \(tzAbbr) – \(isArrivalEstimated ? "about " : "")\(end) \(tzAbbr)"
```

---

### Task 4: The review's fixes

- [x] **Step 1: The tests.**

In `CrewluvTests/LegStoryStoreTests.swift`:

Replace:

```swift
    func test_prepare_whenThePathGrowsAMinuteLater_makesTheStoryAtOnce() async throws {
```

with:

```swift
    func test_prepare_anotherHome_makesARealPathsStoryAgain_withItsClosestPoint() async throws {
        let clock = TestClock()
        let store = liveStore(clock)
        let map = try liveMap(seenUntil: 8)
        await store.prepare(map)
        XCTAssertNil(store.facts(for: map).stories["eq"]?.closestToHome)

        clock.now = clock.now.addingTimeInterval(60)
        let withHome = TripMap(mode: map.mode, legs: map.legs, home: FactsTestData.homeByTheEquator, span: map.span, tripDays: nil)
        await store.prepare(withHome)
        XCTAssertNotNil(store.facts(for: withHome).stories["eq"]?.closestToHome, "the same path, made again for the new home")
    }

    func test_prepare_whenThePathGrowsAMinuteLater_makesTheStoryAtOnce() async throws {
```

In `CrewluvTests/LiveTripFactsTests.swift`:

Replace:

```swift
    func test_showsLiveData_whenAFlightOfTheTripHasIt() throws {
```

with:

```swift
    func test_tripSoFar_eachEventKeepsItsPlace_asNewerOnesComeInAboveIt() throws {
        let earlier = try XCTUnwrap(try facts(seenUntil: "11:20").tripSoFar(at: at("11:20")).flights.first).events
        let later = try XCTUnwrap(try facts(seenUntil: "12:30").tripSoFar(at: at("12:30")).flights.first).events
        XCTAssertGreaterThan(later.count, earlier.count)
        // Newest first: the earlier ones are at the foot, as they were.
        XCTAssertEqual(later.suffix(earlier.count).map(\.id), earlier.map(\.id))
        XCTAssertEqual(later.suffix(earlier.count).map(\.text), earlier.map(\.text))
        XCTAssertEqual(Set(later.map(\.id)).count, later.count, "each line its own")
    }

    func test_showsLiveData_whenAFlightOfTheTripHasIt() throws {
```

- [x] **Step 2: A new home makes a real path's story again.**

In `Crewluv/Services/TripMap/Facts/LegStoryStore.swift`:

Replace:

```swift
            guard pathBuilds[leg.id]?.key != pathKey else { continue }
```

with:

```swift
            // Home is in the story too, as the closest point to it: another home makes the story again.
            let storyKey = "\(pathKey)|\(Self.routeKey(for: leg, home: home))"
            guard pathBuilds[leg.id]?.key != storyKey else { continue }
```

Replace:

```swift
            pathBuilds[leg.id] = (pathKey, now)
            sunKeys[leg.id] = pathKey
            work.paths.append((pathKey, leg))
```

with:

```swift
            pathBuilds[leg.id] = (storyKey, now)
            sunKeys[leg.id] = storyKey
            work.paths.append((storyKey, leg))
```

- [x] **Step 3: The banner beside the side panel.** No tests: SwiftUI.

In `Crewluv/Views/TripMap/TripMapScreen.swift`:

Replace:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

with:

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
```

Replace:

```swift
    /// The side panel's trailing edge, in window coordinates.
    @State private var panelTrailingEdge: CGFloat = 0
```

with:

```swift
    /// The side panel's frame with its padding, in window coordinates.
    @State private var panelFrame: CGRect = .zero
```

Replace:

```swift
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxX } action: { panelTrailingEdge = $0 }
```

with:

```swift
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { panelFrame = $0 }
```

Replace:

```swift
    /// The top bar, and in flight the latest event's banner under its pill (latest event design §1) with the key to
    /// the two planes under the buttons (which plane design §2). Only the bar pads the side panel: the banner is
    /// centred and the key at the trailing edge, clear of it.
    private func topChrome(time: Date, latest: LatestEvent?, showsKey: Bool) -> some View {
        VStack(spacing: 8) {
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
            if latest != nil || showsKey {
                TripMapCorner(latest: latest, showsKey: showsKey, isCentered: true)
                    .padding(.horizontal)
            }
        }
    }
```

with:

```swift
    /// The top bar, and in flight the latest event's banner under its pill (latest event design §1) with the key to
    /// the two planes under the buttons (which plane design §2). Only the bar pads the side panel. Beside the panel
    /// the banner is centred over the open map, clear of it, as the website's is, and the key keeps to the trailing
    /// edge. The panel and the top bar share a leading edge, so the panel's width with its padding is how far in the
    /// corner starts, whichever way the screen reads.
    private func topChrome(time: Date, latest: LatestEvent?, showsKey: Bool) -> some View {
        VStack(spacing: 8) {
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
            if latest != nil || showsKey {
                TripMapCorner(latest: latest, showsKey: showsKey, isCentered: true)
                    .padding(.horizontal)
                    .padding(.leading, usesSidePanel ? panelFrame.width : 0)
            }
        }
    }
```

Replace:

```swift
    /// From the screen's leading edge to the panel's trailing edge, open or folded, with its padding.
    private var mapLeadingClearance: CGFloat {
        usesSidePanel ? max(0, panelTrailingEdge - screenFrame.minX) : 0
    }
```

with:

```swift
    /// From the screen's leading edge to the panel's trailing edge, open or folded, with its padding. Leading is the
    /// right in a right-to-left language, where the panel sits at the right.
    private var mapLeadingClearance: CGFloat {
        guard usesSidePanel else { return 0 }
        let clearance = layoutDirection == .rightToLeft ? screenFrame.maxX - panelFrame.minX : panelFrame.maxX - screenFrame.minX
        return max(0, clearance)
    }
```

- [x] **Step 4: The list keeps each line.**

In `Crewluv/Services/TripMap/Facts/TripSoFar.swift`:

Replace:

```swift
    /// One line of a flight's list: "Crossed into Canada · 1:12 PM".
    nonisolated struct Event: Equatable, Sendable {
        let text: String
        /// A best guess, where nobody saw the plane. Its time reads "about", and it's drawn lighter.
        let isEstimate: Bool
    }
```

with:

```swift
    /// One line of a flight's list: "Crossed into Canada · 1:12 PM".
    nonisolated struct Event: Identifiable, Equatable, Sendable {
        /// Its place among its flight's events, oldest first, so it keeps it as newer ones come in above it. Two
        /// lines can read the same: a coast crossed twice in a minute.
        let id: Int
        let text: String
        /// A best guess, where nobody saw the plane. Its time reads "about", and it's drawn lighter.
        let isEstimate: Bool

        init(id: Int = 0, text: String, isEstimate: Bool) {
            self.id = id
            self.text = text
            self.isEstimate = isEstimate
        }
    }
```

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
            let events = milestones(on: leg).filter { $0.time <= date }.reversed().map {
                TripSoFar.Event(text: FactsWording.listLine(for: $0, calendar: calendar, locale: locale), isEstimate: $0.isEstimate)
            }
```

with:

```swift
            let events = milestones(on: leg).filter { $0.time <= date }.enumerated().reversed().map { place, milestone in
                TripSoFar.Event(id: place, text: FactsWording.listLine(for: milestone, calendar: calendar, locale: locale),
                                isEstimate: milestone.isEstimate)
            }
```

In `Crewluv/Views/TripMap/TripSoFarList.swift`:

Replace:

```swift
        ForEach(Array(events.enumerated()), id: \.offset) { _, event in
```

with:

```swift
        // Each line by its place among its flight's events: a new event at the top doesn't make every line below a
        // new one.
        ForEach(events) { event in
```

---

### Task 5: Plan 3B-3's record of its review

- [x] **Step 1:**

In `docs/superpowers/plans/2026-11-15-moving-map-stage3b3-app-facts.md`:

Replace:

```swift
- [ ] **Step 1: Review the whole branch.** Dispatch `superpowers:code-reviewer` (sonnet) on this plan's commits, with the spec's §8, §9, §11, §15 and §16.3, and this plan's list of where it differs. Use `superpowers:receiving-code-review` on what comes back.
```

with:

```swift
- [x] **Step 1: Review the whole branch.** Dispatch `superpowers:code-reviewer` (sonnet) on this plan's commits, with the spec's §8, §9, §11, §15 and §16.3, and this plan's list of where it differs. Use `superpowers:receiving-code-review` on what comes back.
```

Replace:

```swift
- **Task 10 Step 1, the review of the whole branch, hasn't run yet:** on 16 Nov the call to the reviewer was stopped twice before it started, as a plugin's hook rewrote it after auto mode had checked it.
```

with:

```swift
- **Task 10 Step 1, the review of the whole branch (16 Nov 2026, evening),** by `superpowers:code-reviewer` (sonnet) on `295b81f..9f06e71`, this plan with the best guesses and the latest event: nothing critical. Mended in `docs/superpowers/plans/2026-11-16-tracking-words-and-the-schedule.md`, Task 4: the latest event's banner sat partly under the side panel on iPhone in landscape and iPad in portrait; a real path's story wasn't made again for a new home; the list's lines changed identity with each new event. And in its Task 2, the card's sentence no longer says one place twice ("over Québec, last tracked over Québec"). Left, each for its reason: halfway can un-happen after a wide detour, as the path's whole length grows, which is more than "a guessed event can lead the chip twice" says, and a fix needs a choice of rule; at the largest text sizes short of the accessibility ones, the card's banner, key and chip can leave a thin band, for Todd's look; a flight with a real path but no live plane reads its place along the real path and its city on the great circle; and the store keeps a flight's old story when its live data goes, for the screen's life. The first two tries to start it were stopped before they began: a plugin's hook rewrote the call after auto mode had checked it.
```

---

### Task 6: Todd's run, the commits, and a look

- [x] **Step 1: Todd runs every test of the app once:**

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)"
```

Expected: `** TEST SUCCEEDED **`, with 1,143 tests in the result bundle (1,138 before).

Todd's run, 17 Nov 2026: `** TEST SUCCEEDED **`, 1,143 passed, none failed or skipped.

- [x] **Step 2: Ask to commit:** one commit for each of Tasks 2, 3 and 4, then plan 3B-3's record with this plan.

- [ ] **Step 3: Todd looks:**
  - "Real plane, estimated past an unseen ocean": the sheet's first row reads "Last tracked …", and a tap on the faded plane on the full-screen map reads "Out of tracking range since …".
  - The full-screen map on iPhone in landscape, or on iPad in portrait, with a latest event: the banner over the open map, clear of the panel.
  - The schedule with a flight in the air on Crewlu Cloud: "– about …" on its arrival.

- [ ] **Step 4: The website** gets the same words, and says a place once in its card's sentence: ask Todd whether to hand that to the website's session.


## Left for later

- **Halfway can un-happen after a wide detour,** as the path's whole length grows. A fix needs a choice of rule: hold it once passed, or measure it along the great circle until landing.
- **The card at the largest text sizes short of the accessibility ones:** its banner, key and chip may leave a thin band of map. For Todd's look at xxxLarge.
- **A flight with a real path but no live plane** reads its place along the real path and its city on the great circle.
- **The store keeps a flight's old story** when its live data goes, for the screen's life.

# Moving Map Stage 3B-2 (Crewluve App, the Map) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the real plane in the app. Where Crewlu Cloud has seen the pilot's flight, the family sees the path it really flew, the real plane on it with the schedule's ghost beside it, how far ahead or behind it is, and one landing time on every card.

**Architecture:**
- **One landing time** is worked out in one place. `LiveLegs`, a pure type, gives each flight with live data the real plane's times in place of the schedule's, in the legs the status screen's model (`PartnerStatusReceiver`) hands on. The status, the map, the countdown, the narrative and the trip cards all read those legs, so none of them works a time out itself. Alerts read the status source, not the model, so they stay on the schedule.
- **`MapFlight`** is a flight's plan, path and record, made together from one answer. Every flight leg of the map carries one, on `MapLeg.flight`. A flight with no live data has the schedule's plan and the great circle.
- **`FlightDrawing`** says what one flight draws at a moment, by `LiveProgress.phase`: the real path (solid where the plane was seen, dotted where it wasn't), the real plane, and the ghost. Any other flight draws as before. `TripMapDrawing` puts the flights together, and the views render it.
- **The status screen's model owns the `LiveFlightSource`.** It tells the source when its screen comes to the front and leaves it, where it already starts and stops the 60-second check, and resolves again at each new answer.
- **The words** are `TripMapWording`'s: the label on the card's bar and the pill, and "about" before a landing time that's the real plane's estimate.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency in the app target (not in the test target), iOS 26, SwiftUI, MapKit (`MKMapView`), Observation, XCTest for the pure types and Swift Testing for `LiveFlightSource` (as its tests already are).

**Spec:** `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md` ("the spec"), §5 to §7, §9, §11, §13, §15 and §16.3. The engine this plan builds on is plan 3B-1, `docs/superpowers/plans/2026-11-15-moving-map-stage3b1-app-engine.md`.

**This is the second of three plans for the app** (Todd's choice, 15 Nov 2026), each written when it's about to start:
- **3B-1, the engine:** done, on this branch.
- **3B-2, the map:** this plan.
- **3B-3, the facts:** the story along the real path, the plane's row with `AircraftTypeNames`, and the credit to adsb.lol.

**How this plan was checked.** Every code block here comes from a file that was built and run before the plan was put together. Nothing in it was typed into the plan by hand.
- **A scratch Swift package** with the app target's settings (macOS, Swift 6.4, language mode 5, the main actor by default, approachable concurrency) holds real copies of the map's model, its facts and the engine, and 35 of their test classes, with this plan's files laid over them.
  - Before this plan's changes: 292 XCTest tests and 69 Swift Testing tests, all passing.
  - With them: 381 XCTest tests and 71 Swift Testing tests, all passing, with no warnings. 89 of the XCTest tests and 2 of the Swift Testing tests are new, and every test that was there before still passes unchanged, but for the one this plan rewrites.
  - The new tests run the shared cases (`live-cases.json`) through the new code: every flight and every moment of them is drawn, worded and given its real times, and compared with what the cases expect.
- **45 deliberate breaks** were made in the new code, one at a time. Each fails at least one test. One slipped through at first: with two legs that are one flight, the test tried them in only one order. It now tries both, and catches it. And the three new tests of `LiveFlightSource` fail against the engine's code as it is today.
- **The whole app was type-checked for iOS** with `swiftc` against the iOS 27.2 simulator SDK and the app's own settings, outside Xcode: all 177 of its Swift files, with this plan's files in place. No errors and no warnings. The app as it is today passes the same check, so the check means something. With every task in, the app was also compiled all the way to an object file for the simulator, without linking, since a type-check can't see a value used before it's set: again no errors and no warnings.
- **Task by task:** the package was rebuilt and its tests run as it stands after each of Tasks 2 to 7, and the whole app type-checked as it stands after each of Tasks 2 to 9. Every one passed: the XCTest count went 292, 311, 330, 344, 364 and 381 as each task's tests came in, and the app type-checked with no errors and no warnings each time. So the app's code is whole after every task, not only at the end.
- **The plan itself was followed by a script,** on the repo's files as they are at `f65ef7d`: every file it says to create, and every replacement it says to make. All 41 files came out the same as the ones that were tested.
- **Not checked, because nothing outside Xcode can check it:**
  - Nothing was run on a simulator or a device. No view was seen. The colours, the planes' looks and the dotted lines are as the spec's words have them, and nobody has looked at them yet.
  - The status screen's model (`PartnerStatusReceiver`) has no unit tests, before this plan or after it: it's made with the real iCloud container. Its new code was type-checked, and the logic it calls (`LiveLegs`) is tested.
  - The tests ran on a Mac, not on the iPhone simulator. Todd's runs in Xcode are the real ones.
  - Task 10 is how Todd checks the rest: the previews, and one real flight.

**Where this plan settles what the spec left open, or differs from it:**
- **`MapLeg`'s own questions stay the schedule's.** The spec (§11) has `progress(at:)`, `position(at:)`, `time(atFraction:)`, `heading(at:)` and `distance` ask the path and the record. Here the drawing asks `MapLeg.flight`, and those five stay as they are, between the leg's gate times. The facts read them, and the facts on the real path are 3B-3's. Until then the facts follow the great circle between the real plane's times: "Over Québec" can name a place the real plane isn't over.
- **A leg's delay stays on it.** Every reader of a leg moves its times by its delay. So a flight's real times are written as the real time less the delay, and each reader lands on the real time without knowing.
- **The waits either side** (spec §7.1) are CrewLu's turn, layover, base and home legs next in line before and after the flight. One moves only when its flight's own edge did, and only when the wait's edge was where the flight's was, within a minute. So a layover that starts after half an hour's training isn't pulled back over the training when the flight lands early.
- **A summary-wide delay gets no live data.** That's the delay of a CrewLu that doesn't tag legs, with no leg tagged. There's no leg to hold the real times against, so the schedule shows. A leg with its own delay is unaffected.
- **A time that changes by itself can be a minute late.** The model resolves at each new answer about the live plane, and at each read of the status, which on Crewlu Cloud comes every 60 seconds while the screen is in front. A plane on the ground whose fix goes stale is the case: its landing time goes back to the schedule's at the next of those.
- **The real plane shows from gate to gate.** The spec (§5.1) has it at the gate whenever it's seen on the ground there, which is up to 30 minutes before the flight leaves. Before the leg starts, the pilot's marker already stands on that airport, so the plane and its ghost wait for the leg.
- **A flight that isn't live draws the schedule,** even when it has a real path: after a return to the gate, or in a state this Crewluve doesn't know. That's the engine plan's rule.
- **The plan's line behind the plane is dotted** wherever the plane is only said to have flown it: behind an estimated plane (the spec's case), behind a plane that landed without being seen in the air, and in a replay, at a moment after the plane was last seen.
- **In a replay, the path ahead of the plane is dashed along the real path,** not along the great circle. A moment after the plane was last seen shows it faded, as an estimate.
- **The plane in the air points the way it's really going** (the fix's track). Without a track, and in every other state, it points along its path.
- **The planes don't slide between fixes.** A new fix moves the plane less than a point at the map's usual zoom, so the plane is simply put at its new place, as the schedule's plane is today. So Reduce Motion (§15) needs nothing new.
- **On the light map** (the standard style in light mode) the real path is blue, since white wouldn't show.
- **"About" is read from the leg itself.** A landing time is the real plane's estimate when it isn't the plan's (by a second or more) and the plane hasn't landed. So the same leg reads the same at every moment of a replay.
- **A real plane with no label** (on the ground before the plan's takeoff, or somewhere else) keeps the schedule's VoiceOver sentence, with "Estimated from the schedule."
- **The delay banner stays.** With a reported delay it still says so, beside a label that's measured against the plan with that delay in it (spec §13).
- **`FactsWording.lands` says "about" too,** since it words a leg's landing time for the facts' next-flight row.
- **Pull to refresh and the refresh button wait for the live plane:** `PartnerStatusReceiver.refreshByHand()`. Coming to the front asks through `screenCameToFront()`, as the engine has it, so the status read and the live plane don't wait on each other.
- **`LiveFlightSource.ask()` makes its call in a task of its own,** and a second caller waits for it. That closes both things the engine plan left: a call the 30-second check made no longer ends unanswered when the check is stopped mid-call, and `ask()` no longer returns before the answer.
- **A replay keeps its moment when the trip's times change.** Each new landing estimate changes the current leg's end, and the full-screen map made a new clock whenever a leg's times changed, which sent a replay back to live. `TripReplayClock.carried(to:legs:waits:at:)` makes the new clock at the same moment, playing or paused. A new delay now does the same.
- **The card frames the trip again when a real path grows past its frame.** The full-screen map doesn't: its camera may be the family's, and Recenter frames the real path.
- **Legs that are one flight:** only the first of their ids is watched, as the engine plan asks. The other leg shows the schedule.
- **The countdown and narrative cards** say "about" through one flag from the status screen: the flight between its gates has an estimated landing.
- **"One landing time through the status screen's model"** (§16.3) is tested through `LiveLegs` and `TripStateResolver` together. The model's own lines are type-checked and seen on a real flight.
- **Left to 3B-3:** "Estimated · last seen near Gander" on the headline chip (§8, §9), the plane's row, and the credit.

**Questions for Todd, before this plan runs:**
1. **The credit.** Crewlu Cloud's contract says to credit adsb.lol wherever a flight with live data shows, and the credit is 3B-3's. Until then only Todd's own account is listed, so only his family's devices can show a real plane. Is that all right for his next flight, with no TestFlight or App Store build of 3B-2 until the credit is in? The other way is a small extra task here: one line in the facts' footer.
2. **Asking with nothing to hear.** Until the switch is `all`, every other pilot's partners ask every 30 seconds while a flight's window is open and their screen is in front, and get no flights. The engine plan left this for Todd: leave it (each call is small), or have the source ask less often after an empty answer? This plan leaves it.
3. **A real flight in the previews.** Task 8's previews use a made-up plane. UPS82's real snapshot is in a scratchpad and could be a preview, which would put a real flight's data in the repo. This plan doesn't.
4. **The release note.** This is the first of Stage 3's plans that changes what a family sees, though only for a listed pilot. Task 11 drafts the note for "Crewluve revisions": which version and build does it go under?
5. **Who watches the flight.** Task 10 needs someone looking at the app while Todd's flight is between its gates, and Todd is flying it. Someone at home with a build from Xcode, or the session running the plan, driving the simulator and saving a screenshot at each step?

**For the record, not a question:** `LiveProgress.freshFor` stays 2 minutes, as Todd said on 15 Nov. If Crewlu Cloud's pause after a refusal from adsb.lol ends up longer than about 90 seconds, a plane in the air will show as estimated for part of every few minutes: faded, with "About" on its label. Nothing here depends on the number.

---

## Ground rules for whoever runs this plan

These come from Todd's standing instructions. They override the skill's defaults.

1. **Don't run `xcodebuild` build or test loops,** and don't let subagents run them. Write the code and tests. At each batch's checkpoint, Todd runs the named tests in Xcode, or with the command there.
2. **The tests are written first, and run once.** The code and its tests were already run together in the scratch package, so a first run that only fails to build would tell Todd nothing. He runs each batch's tests after its code is in.
3. **Never commit without Todd's go-ahead in the conversation.** Each task ends with a suggested commit message. Ask, then commit only on a yes, and only the task's own files.
4. **One release note, at the end** (Task 11). After Todd's OK to commit the last task, draft it for the Apple Note "Crewluve revisions" and ask before writing it.
5. **New files join their target on their own.** `Crewluv/` and `CrewluvTests/` are synchronized folders. Don't tick `CrewluveAlerts` on any new file: none of the helper's 15 files changes in this plan, and none of them needs a new one.
6. **Mark pure types `nonisolated`** (`nonisolated struct` / `nonisolated enum`). A conformance or a member in an extension is written `nonisolated extension`, or it defaults to the main actor and the tests can't call it.
7. **Copy the code as written.** It was compiled with the app's settings. If something doesn't build in Xcode, stop and say what the compiler said before changing it.
8. **A replacement is exact.** Where a step says "replace", the text to find is in the file once, unless the step says how many times. If it isn't there, stop: the file has changed since this plan was written.
9. **Nothing here calls Crewlu Cloud or adsb.lol** but the app itself, run by Todd in Task 10. Every test uses a stand-in. Change nothing in Crewlu Cloud's live project, and don't read it with the Supabase tools.
10. **Reviewers:** dispatch `superpowers:code-reviewer` with `model: "sonnet"`.
11. **Work on `feature/trip-map-live`,** never on `main` (Task 1). The checkout is shared with other sessions, so commit only this plan's files, and never stash, reset or switch branches.

Test command for Todd. The OS is named because his iPhone 17 Pro simulator is on iOS 26.5, and without it `xcodebuild` looks for one on the newest iOS and finds none:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:CrewluvTests/<TestClass>
```

## File map

| File | Status | Responsibility |
|---|---|---|
| `Crewluv/Services/TripMap/Live/LiveFlightSource.swift` | modify | `ask()` in a task of its own, and a second caller waits |
| `Crewluv/Services/TripMap/Live/MapFlight.swift` | create | a flight's plan, path and record, made together |
| `Crewluv/Services/TripMap/Live/FlightPath+Drawing.swift` | create | the path's places, its runs by kind, its framing, and a plane's heading on it |
| `Crewluv/Services/TripMap/Live/LiveLegs.swift` | create | one landing time: which legs are watched, each flight's `MapFlight`, and the legs at their real times |
| `Crewluv/Services/TripMap/MapLeg.swift` | modify | carries `flight`, and says whether its end is an estimate |
| `Crewluv/Services/TripMap/TripMap.swift` | modify | `make` takes the flights, and the camera frames each flight's path |
| `Crewluv/Services/TripMap/TripMap+Status.swift` | modify | the status screen's map takes the flights |
| `Crewluv/Views/TripMap/TripMap+Camera.swift` | modify | `framingKey`, so the card can tell when its frame changed |
| `Crewluv/Services/TripMap/TripReplayClock.swift` | modify | `carried(to:legs:waits:at:)` |
| `Crewluv/Services/TripMap/FlightDrawing.swift` | create | one flight's lines and planes at a moment |
| `Crewluv/Services/TripMap/TripMapDrawing.swift` | modify | the two new line styles, the real plane and the ghost, and `isReplay` |
| `Crewluv/Views/TripMap/TripMapPalette.swift` | modify | the two new lines' colours and strokes |
| `Crewluv/Views/TripMap/TripMapMarker.swift` | modify | the real plane's and the ghost's markers |
| `Crewluv/Views/TripMap/TripMapMarkerView.swift`, `PlaneMarker.swift`, `TripMapAnnotationView.swift`, `TripMapShapesView.swift` | modify | the planes' looks, where they stack, and the new lines' layers |
| `Crewluv/Services/TripMap/TripMapWording.swift` | modify | the label for the bar and the pill, "about", and the VoiceOver sentence |
| `Crewluv/Services/TripMap/Facts/TripFacts.swift`, `FactsWording.swift` | modify | the card's sentence with a real plane, and "about" on a landing time |
| `Crewluv/Views/TripMap/TripMapView.swift`, `TripMapCoordinator.swift` | modify | `isReplay` reaches the drawing |
| `Crewluv/Views/TripMap/TripMapCard.swift`, `TripMapInFlightBar.swift` | modify | the label on the bar, and framing a path that grew |
| `Crewluv/Views/TripMap/TripMapScreen.swift` | modify | the replay: `isReplay`, the pill, and a clock that carries on |
| `Crewluv/Views/TripMap/TripMapPreviews.swift` | modify | three previews with a made-up real plane |
| `Crewluv/Services/PartnerStatusReceiver.swift` | modify | owns the `LiveFlightSource`, and hands on the legs at their real times |
| `Crewluv/Views/Welcome/ContentView.swift` | modify | hands the flights to the status screen, and refreshes by hand |
| `Crewluv/Views/Status/PilotStatusView.swift`, `NarrativeCardView.swift` | modify | the map takes the flights, and the cards say "about" |
| `CrewluvTests/Helpers/PartnerCloudStandIns.swift` | modify | the stand-in door fails a call whose task was stopped |
| `CrewluvTests/LiveFlightSourceTests.swift` | modify | one test rewritten, two added |
| `CrewluvTests/Helpers/LiveCaseLegs.swift` | create | the shared cases' flights as the map and the model take them |
| `CrewluvTests/MapFlightTests.swift`, `FlightPathDrawingTests.swift`, `LiveLegsTests.swift`, `LiveTripMapTests.swift`, `TripReplayClockCarryTests.swift`, `FlightDrawingTests.swift`, `LiveMarkerTests.swift`, `LiveWordingTests.swift` | create | one class for each new piece |
| `CLAUDE.md` | modify | the real plane on the map, in Key Components |

## Batches

Review with `superpowers:code-reviewer` (sonnet) after each batch, then Todd runs that batch's tests:

- **A, the pieces:** Tasks 2 to 4. Nothing a family sees changes.
- **B, the map's model, its drawing and its words:** Tasks 5 to 7. The app builds after each, and still shows no real plane: nothing hands the map a flight yet.
- **C, the views and the status screen:** Tasks 8 and 9. After Task 9 the real plane shows.

Then Task 10, on a real flight, and Task 11.

---

### Task 1: Before starting

**Files:** none.

- [ ] **Step 1: Check the branch and the tree.**

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current && git -C /Users/toddanderson/Dev/Crewluv log --oneline -1
```

  - If the branch is `feature/trip-map-live`, stay on it. The last commit should be `f65ef7d` or later.
  - Anything else: stop and ask Todd.
  - Other changed files that aren't this plan's are left alone. Another session may share this checkout.

- [ ] **Step 2: Check the questions.** Todd's answers to the five questions above may change a task. If the credit is to go in here, stop and add its task before starting.

- [ ] **Step 3: Read the engine.** The eight files in `Crewluv/Services/TripMap/Live/`, and "What 3B-2, 3B-3 and the website's plan take from this one" in plan 3B-1.

---

### Task 2: `LiveFlightSource.ask()` waits for its answer

The engine left two things for this plan. A call the 30-second check made ended unanswered when the check was stopped mid-call, because the call ran inside the check's own task. And `ask()` came back at once when a call was under way, so a pull to refresh could end before the answer. Now the call runs in a task of its own, and anyone who asks meanwhile waits for it.

**Files:**
- Modify: `CrewluvTests/Helpers/PartnerCloudStandIns.swift`
- Modify: `CrewluvTests/LiveFlightSourceTests.swift`
- Modify: `Crewluv/Services/TripMap/Live/LiveFlightSource.swift`

- [ ] **Step 1: Make the stand-in door fail a stopped call,** as the real door does: URLSession ends a call whose task was cancelled, and `LivePartnerDoor` reports that as out of reach. Without this, the tests below would pass against the old code.

In `CrewluvTests/Helpers/PartnerCloudStandIns.swift`:

Replace:

```swift
        if holdsLives {
            await withCheckedContinuation { held.append($0) }
        }
        guard !liveAnswers.isEmpty else { throw .unavailable }
```

with:

```swift
        if holdsLives {
            await withCheckedContinuation { held.append($0) }
        }
        // A call whose task was stopped fails, as URLSession's does.
        guard !Task.isCancelled else { throw .unavailable }
        guard !liveAnswers.isEmpty else { throw .unavailable }
```

- [ ] **Step 2: Write the tests.** One is rewritten: a second `ask()` now waits. Two are new.

In `CrewluvTests/LiveFlightSourceTests.swift`:

Replace:

```swift
    @Test func test_ask_whileOneIsUnderWay_asksNothingMore() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        // In a task of its own: a second call that did go out would wait on the door, and must fail here, not hang.
        let again = Task { await source.ask() }
        for _ in 0..<100 {
            await Task.yield()
        }

        #expect(door.lives.count == 1)
        door.release()
        await asking.value
        await again.value
        #expect(minutes(of: "leg-1", in: source) == [0])
    }
```

with:

```swift
    @Test func test_ask_whileOneIsUnderWay_asksNothingMore_andWaitsForItsAnswer() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        // In a task of its own: a second call that did go out would wait on the door, and must fail here, not hang.
        var isSecondBack = false
        let again = Task {
            await source.ask()
            isSecondBack = true
        }
        for _ in 0..<100 {
            await Task.yield()
        }

        #expect(door.lives.count == 1)
        #expect(!isSecondBack, "it waits for the call under way")
        door.release()
        await asking.value
        await again.value
        #expect(door.lives.count == 1)
        #expect(minutes(of: "leg-1", in: source) == [0])
    }

    @Test func test_ask_whoeverAskedIsStopped_theCallStillBringsItsAnswer() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        asking.cancel()
        door.release()
        await asking.value

        #expect(minutes(of: "leg-1", in: source) == [0])
    }
```

Replace:

```swift
    @Test func test_screenLeftFront_stopsTheCheck() async {
```

with:

```swift
    @Test func test_screenLeftFront_whileTheCheckIsAsking_stillTakesTheAnswer() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])]), answer(cursor: 9, [flight("leg-1", points: [2], count: 2)])]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(-3600), arrival: now.addingTimeInterval(3600))])
        await source.screenCameToFront()
        door.holdsLives = true

        await eventually { clock.waitingCount == 1 }
        clock.tick()
        await eventually { door.lives.count == 2 }
        source.screenLeftFront()
        door.release()
        await eventually { minutes(of: "leg-1", in: source) == [0, 2] }

        #expect(door.lives.map(\.after) == [nil, 7])
        #expect(clock.waitingCount == 0, "and the check has stopped")
    }

    @Test func test_screenLeftFront_stopsTheCheck() async {
```

Against the engine's code as it is, all three fail: the second `ask()` is back at once, and the two stopped calls bring no answer.

- [ ] **Step 3: Change `ask()`.**

In `Crewluv/Services/TripMap/Live/LiveFlightSource.swift`:

Replace:

```swift
/// The 30-second check runs only between `screenCameToFront()` and `screenLeftFront()`: the screen keeps it out of
/// the background by saying when it leaves the front. It never asks while this device follows its pilot through
/// iCloud.
```

with:

```swift
/// The 30-second check runs only between `screenCameToFront()` and `screenLeftFront()`: the screen keeps it out of
/// the background by saying when it leaves the front. A call already under way when the screen leaves still brings
/// its answer. It never asks while this device follows its pilot through iCloud.
```

Replace:

```swift
    @ObservationIgnored private var isAsking = false
```

with:

```swift
    /// The call under way, when there is one. It runs in a task of its own, so stopping the 30-second check that
    /// started it doesn't stop the call.
    @ObservationIgnored private var asking: Task<Void, Never>?
```

Replace:

```swift
    /// Asks Crewlu Cloud once, and takes its answer. While a call is under way, another asks nothing: the one under
    /// way brings the answer. The exception is a call the 30-second check made, which ends unanswered when the check
    /// is stopped or started again: an `ask()` that found it under way gets no answer either, until the next check.
    func ask() async {
        guard !isAsking else { return }
        guard isOnCrewluCloud() else {
            forget()
            return
        }
```

with:

```swift
    /// Asks Crewlu Cloud once, takes its answer, and returns when it has. While a call is under way, another asks
    /// nothing more and waits for that one's answer: so a pull to refresh ends when the live plane is up to date,
    /// whoever asked for it.
    func ask() async {
        if let asking {
            await asking.value
            return
        }
        let call = Task { [weak self] in
            await self?.askCrewluCloud()
            self?.asking = nil
        }
        asking = call
        await call.value
    }

    // MARK: - Private

    /// One call to Crewlu Cloud, and what's kept of its answer.
    private func askCrewluCloud() async {
        guard isOnCrewluCloud() else {
            forget()
            return
        }
```

Replace:

```swift
        isAsking = true
        defer { isAsking = false }
        let sent = cursor
```

with:

```swift
        let sent = cursor
```

Replace:

```swift
    }

    // MARK: - Private

    /// The 30-second check:
```

with:

```swift
    }

    /// The 30-second check:
```

The whole class is on the main actor, so the task's closure is too, and `asking` is only ever touched there. `self` is held weakly: a source let go mid-call lives until the call ends and no longer.

- [ ] **Step 4: Checkpoint.** `LiveFlightSourceTests` has 31 tests. Todd runs it with batch A, after Task 4.

- [ ] **Step 5: Ask to commit.** Suggested message: `fix(crewluv): LiveFlightSource makes its call in a task of its own, so a call the 30-second check made still brings its answer when the check is stopped, and a second ask waits for the answer (Stage 3 spec §11)`.

---

### Task 3: `MapFlight`, and the path as the map draws it

`MapFlight` keeps a flight's plan, path and record together, as the engine plan asks: they're made from one answer, so they can't disagree. It also keeps Crewlu Cloud's clock, so whoever asks it for the real plane can hand it this device's time. `FlightPath` gains what the drawing and the camera need. `MapLeg` carries the flight.

**Files:**
- Create: `CrewluvTests/Helpers/LiveCaseLegs.swift`
- Create: `CrewluvTests/MapFlightTests.swift`
- Create: `CrewluvTests/FlightPathDrawingTests.swift`
- Create: `Crewluv/Services/TripMap/Live/MapFlight.swift`
- Create: `Crewluv/Services/TripMap/Live/FlightPath+Drawing.swift`
- Modify: `Crewluv/Services/TripMap/MapLeg.swift`

- [ ] **Step 1: Write the helper** that turns a shared case's flight into the map's flight, a leg of the map, and a leg of the summary. Every later task's tests use it.

Create `CrewluvTests/Helpers/LiveCaseLegs.swift`:

```swift
//
//  LiveCaseLegs.swift
//  CrewluvTests
//
//  The shared cases' flights (Fixtures/TripMap/live-cases.json) as the trip map and the status screen's model take
//  them: the map's flight, a leg of the map, and a leg of the pilot's summary.
//

import CoreLocation
import Foundation
@testable import Crewluv

extension TripMapFixtures.LiveCases {

    struct MissingFlight: Error {
        let name: String
    }

    func flight(named name: String) throws -> Flight {
        guard let flight = flights.first(where: { $0.name == name }) else { throw MissingFlight(name: name) }
        return flight
    }

    func moment(_ time: String, of flight: Flight) throws -> Flight.Moment {
        let at = try Date("2026-11-\(time)Z", strategy: .iso8601)
        guard let moment = flight.moments.first(where: { $0.at == at }) else { throw MissingFlight(name: "\(flight.name) at \(time)") }
        return moment
    }

    /// A flight case's live data, as `LiveFlightSource` keeps it. Nil where the door answers none for the leg.
    func live(_ flight: Flight) -> LiveFlight? {
        flight.flight.map { LiveFlight($0, trail: $0.trail) }
    }

    /// A flight case as the map's flight: its plan, its path and its record, made together.
    func mapFlight(_ flight: Flight, clockOffset: TimeInterval = 0) throws -> MapFlight {
        let made = MapFlight(departure: flight.departure, arrival: flight.arrival,
                             from: try coordinate(of: flight.from), to: try coordinate(of: flight.to),
                             live: live(flight), clockOffset: clockOffset)
        guard let made else { throw TripMapFixtures.MissingPlan(name: flight.name) }
        return made
    }

    /// A flight case as a leg of the map, between the gates at the times the case expects at `moment`: the real
    /// plane's, as the status screen's model hands them on.
    func mapLeg(_ flight: Flight, at moment: Flight.Moment, id: String = "f1") throws -> MapLeg {
        MapLeg(id: id, kind: .flight,
               origin: AirportMark(code: flight.from, city: nil, coordinate: try coordinate(of: flight.from), timeZone: nil),
               destination: AirportMark(code: flight.to, city: nil, coordinate: try coordinate(of: flight.to), timeZone: nil),
               start: moment.start, end: moment.end, flightNumber: "UPS207", flight: try mapFlight(flight))
    }

    /// A flight case as a leg of the pilot's summary. The case's gate times are the schedule's moved by any
    /// reported delay, so the leg's own are `delayMinutes` earlier.
    func tripLeg(_ flight: Flight, id: String = "f1", delayMinutes: Int? = nil) -> TripLeg {
        let delay = TimeInterval((delayMinutes ?? 0) * 60)
        return TripLeg(id: id, tripId: "T1", type: .flight, startTime: flight.departure.addingTimeInterval(-delay),
                       endTime: flight.arrival.addingTimeInterval(-delay), airportCode: nil, city: nil,
                       timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil, flightNumber: "UPS207",
                       departureAirport: flight.from, arrivalAirport: flight.to, departureCity: nil, arrivalCity: nil,
                       tripDayNumber: nil, tripTotalDays: nil, delayMinutes: delayMinutes, airlineCode: nil, label: nil)
    }

    /// One of CrewLu's waits on the ground, from `start` to `end`.
    func wait(_ id: String, _ type: TripLeg.LegType, at code: String, from start: Date, to end: Date) -> TripLeg {
        TripLeg(id: id, tripId: "T1", type: type, startTime: start, endTime: end, airportCode: code, city: nil,
                timezoneIdentifier: nil, arrivalTimezoneIdentifier: nil, flightNumber: nil, departureAirport: nil,
                arrivalAirport: nil, departureCity: nil, arrivalCity: nil, tripDayNumber: nil, tripTotalDays: nil,
                delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// Where an airport of the cases is, by code, as `TripMap.make` and `LiveLegs.flights` ask.
    func coordinateOrNil(_ code: String) -> CLLocationCoordinate2D? {
        try? coordinate(of: code)
    }
}
```

- [ ] **Step 2: Write the tests.**

Create `CrewluvTests/MapFlightTests.swift`:

```swift
//
//  MapFlightTests.swift
//  CrewluvTests
//
//  A flight as the trip map measures and draws it: its plan, path and record made together (Stage 3 spec §11),
//  held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class MapFlightTests: XCTestCase {

    private let departure = TripMapTestLegs.tripStart
    private var arrival: Date { departure.addingTimeInterval(8 * 3600) }
    private let louisville = TripMapTestLegs.airports["SDF"]!
    private let cologne = TripMapTestLegs.airports["CGN"]!

    func test_init_withNoLiveData_hasTheSchedulesPlan_theGreatCircle_andNoRecord() throws {
        let flight = try XCTUnwrap(MapFlight(departure: departure, arrival: arrival, from: louisville, to: cologne))
        XCTAssertEqual(flight.plan.departure, departure)
        XCTAssertEqual(flight.plan.arrival, arrival)
        XCTAssertEqual(flight.plan.distance, GreatCircle.distance(from: louisville, to: cologne), accuracy: 1e-6)
        XCTAssertFalse(flight.path.isReal)
        XCTAssertEqual(flight.path.stretches.map(\.kind), [.planned])
        XCTAssertNil(flight.record)
        XCTAssertNil(flight.live)
        XCTAssertEqual(flight.progress(at: departure.addingTimeInterval(3600)).phase, .notLive)
    }

    func test_init_aLegThatArrivesNoLaterThanItLeaves_isNil() {
        XCTAssertNil(MapFlight(departure: departure, arrival: departure, from: louisville, to: cologne))
        XCTAssertNil(MapFlight(departure: arrival, arrival: departure, from: louisville, to: cologne))
    }

    func test_init_everySharedCase_makesThePathAndTheRecordTheCaseExpects() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertFalse(cases.flights.isEmpty)
        for flightCase in cases.flights {
            let flight = try cases.mapFlight(flightCase)
            XCTAssertEqual(flight.path.isReal, flightCase.path.isReal, flightCase.name)
            XCTAssertEqual(flight.path.stretches.map(\.kind.rawValue), flightCase.path.stretchKinds, flightCase.name)
            XCTAssertEqual(flight.record != nil, flightCase.record != nil, flightCase.name)
        }
    }

    func test_progress_everySharedMoment_matchesTheCase() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights {
            let flight = try cases.mapFlight(flightCase)
            for moment in flightCase.moments {
                let name = "\(flightCase.name) at \(moment.at)"
                let progress = flight.progress(at: moment.at)
                XCTAssertEqual(progress.phase.rawValue, moment.phase, name)
                XCTAssertEqual(progress.label.map(TripMapWording.liveLabel), moment.label, name)
                XCTAssertEqual(progress.start.timeIntervalSince1970, moment.start.timeIntervalSince1970, accuracy: 0.05, name)
                XCTAssertEqual(progress.end.timeIntervalSince1970, moment.end.timeIntervalSince1970, accuracy: 0.05, name)
                checked += 1
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 20)
    }

    func test_progress_measuresAFixsAgeByCrewluCloudsClock() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        // This phone's clock is 10 minutes slow. By it, the fix would be in the future.
        let flight = try cases.mapFlight(flightCase, clockOffset: 600)
        for moment in flightCase.moments {
            let progress = flight.progress(at: moment.at.addingTimeInterval(-600))
            XCTAssertEqual(progress.phase.rawValue, moment.phase, "\(moment.at)")
        }
    }

    func test_isEstimate_isTrueOfATimeThatIsntThePlans_untilThePlaneHasLanded() throws {
        let cases = try TripMapFixtures.liveCases()
        let inTheAir = try cases.mapFlight(cases.flight(named: "ahead, in the air"))
        XCTAssertFalse(inTheAir.isEstimate(inTheAir.plan.arrival), "the schedule's own time")
        XCTAssertFalse(inTheAir.isEstimate(inTheAir.plan.arrival.addingTimeInterval(0.5)), "the same time, but for rounding")
        XCTAssertTrue(inTheAir.isEstimate(inTheAir.plan.arrival.addingTimeInterval(-13 * 60)))
        let landed = try cases.mapFlight(cases.flight(named: "landed, seen all the way"))
        XCTAssertFalse(landed.isEstimate(landed.plan.arrival.addingTimeInterval(-23 * 60)), "a landing that was seen is no estimate")
        let none = try cases.mapFlight(cases.flight(named: "no live data"))
        XCTAssertFalse(none.isEstimate(none.plan.arrival))
    }
}
```

Create `CrewluvTests/FlightPathDrawingTests.swift`:

```swift
//
//  FlightPathDrawingTests.swift
//  CrewluvTests
//
//  A flight's path as the trip map draws and frames it (Stage 3 spec §6.2), on the shared cases' paths.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightPathDrawingTests: XCTestCase {

    private let louisville = TripMapTestLegs.airports["SDF"]!
    private let cologne = TripMapTestLegs.airports["CGN"]!
    private var greatCircle: FlightPath { FlightPath(from: louisville, to: cologne) }

    private func assertSame(_ place: CLLocationCoordinate2D?, _ expected: CLLocationCoordinate2D?, _ name: String = "",
                            file: StaticString = #filePath, line: UInt = #line) {
        guard let place, let expected else {
            XCTFail("a place is missing: \(name)", file: file, line: line)
            return
        }
        XCTAssertEqual(place.latitude, expected.latitude, accuracy: 1e-9, name, file: file, line: line)
        XCTAssertEqual(place.longitude, expected.longitude, accuracy: 1e-9, name, file: file, line: line)
    }

    /// The kinds of a path's stretches with neighbours of one kind counted once.
    private func kindsInOrder(_ path: FlightPath) -> [FlightPath.Kind] {
        path.stretches.map(\.kind).reduce(into: []) { kinds, kind in
            if kinds.last != kind { kinds.append(kind) }
        }
    }

    // MARK: - The places it passes

    func test_coordinates_aGreatCircle_isItsTwoAirports() {
        let places = greatCircle.coordinates
        XCTAssertEqual(places.count, 2)
        assertSame(places.first, louisville)
        assertSame(places.last, cologne)
    }

    func test_coordinates_aRealPath_passesEveryPlaceThePlaneWasSeen() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let path = try cases.made(flightCase).path
        let places = path.coordinates
        XCTAssertEqual(places.count, path.stretches.count + 1)
        assertSame(places.first, path.origin)
        assertSame(places.last, path.destination)
        for (place, stretch) in zip(places, path.stretches) {
            assertSame(place, stretch.start)
        }
    }

    // MARK: - Runs

    func test_runs_ofTheWholePath_areItsKindsInOrder_eachBeginningWhereTheLastEnded() throws {
        let cases = try TripMapFixtures.liveCases()
        for flightCase in cases.flights {
            let path = try cases.made(flightCase).path
            let runs = path.runs(from: 0, to: path.length)
            XCTAssertEqual(runs.map(\.kind), kindsInOrder(path), flightCase.name)
            assertSame(runs.first?.coordinates.first, path.origin, flightCase.name)
            assertSame(runs.last?.coordinates.last, path.destination, flightCase.name)
            for (earlier, later) in zip(runs, runs.dropFirst()) {
                assertSame(later.coordinates.first, earlier.coordinates.last, flightCase.name)
            }
            XCTAssertEqual(runs.reduce(0) { $0 + $1.coordinates.count - 1 }, path.stretches.count, flightCase.name)
        }
    }

    func test_runs_cutInsideAStretch_endAtThePlaceThatFarAlong() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "behind, with a late first point and an unseen ocean")).path
        let cut = path.flownLength * 0.4
        let behind = path.runs(from: 0, to: cut)
        let ahead = path.runs(from: cut, to: path.length)
        assertSame(behind.last?.coordinates.last, path.point(atDistance: cut))
        assertSame(ahead.first?.coordinates.first, path.point(atDistance: cut))
        XCTAssertEqual(behind.first?.kind, .unseen, "the first place it was seen was far from the airport")
        XCTAssertEqual(ahead.last?.kind, .planned)
        XCTAssertFalse(behind.contains { $0.kind == .planned }, "nothing behind the cut is the way ahead")
    }

    func test_runs_upToWhereThePlaneWasLastSeen_leaveOutTheWayAhead() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "ahead, in the air")).path
        XCTAssertEqual(path.runs(from: 0, to: path.flownLength).map(\.kind), [.seen])
        XCTAssertEqual(path.runs(from: path.flownLength, to: path.length).map(\.kind), [.planned])
        XCTAssertEqual(path.runs(from: path.flownLength, to: path.length).first?.coordinates.count, 2)
    }

    func test_runs_withNoLength_areEmpty() {
        XCTAssertTrue(greatCircle.runs(from: 0, to: 0).isEmpty)
        XCTAssertTrue(greatCircle.runs(from: 500_000, to: 500_000).isEmpty)
        XCTAssertTrue(greatCircle.runs(from: 500_000, to: 100_000).isEmpty)
        XCTAssertTrue(greatCircle.runs(from: greatCircle.length, to: greatCircle.length * 2).isEmpty)
        XCTAssertTrue(greatCircle.coordinates(from: 0, to: 0).isEmpty)
    }

    func test_coordinatesFromTo_areTheRunsJoined_withoutTheirSharedPlacesTwice() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "behind, with a late first point and an unseen ocean")).path
        let whole = path.coordinates(from: 0, to: path.length)
        XCTAssertEqual(whole.count, path.stretches.count + 1)
        for (place, expected) in zip(whole, path.coordinates) {
            assertSame(place, expected)
        }
    }

    // MARK: - Framing

    func test_framingCoordinates_aGreatCircle_areThe33PlacesOfBefore() {
        let places = greatCircle.framingCoordinates
        let before = GreatCircle.points(from: louisville, to: cologne, count: 33)
        XCTAssertEqual(places.count, 33)
        for (place, expected) in zip(places, before) {
            assertSame(place, expected)
        }
    }

    func test_framingCoordinates_aRealPath_holdEveryPlaceThePlaneWasSeen() throws {
        let cases = try TripMapFixtures.liveCases()
        let path = try cases.made(cases.flight(named: "off early and the long way round")).path
        let places = path.framingCoordinates
        for stretch in path.stretches {
            XCTAssertTrue(places.contains { abs($0.latitude - stretch.start.latitude) < 1e-9 && abs($0.longitude - stretch.start.longitude) < 1e-9 })
        }
        assertSame(places.first, path.origin)
        assertSame(places.last, path.destination)
    }

    func test_framingCoordinates_aPathThatGoesNowhere_isItsAirport() {
        let places = FlightPath(from: louisville, to: louisville).framingCoordinates
        XCTAssertEqual(places.count, 2)
        assertSame(places.first, louisville)
    }

    // MARK: - Which way a plane on it points

    func test_heading_alongAGreatCircle_isTheWayAhead() throws {
        let path = greatCircle
        let look = PlaneHeading.lookAhead * path.length
        let expected = try XCTUnwrap(PlaneHeading.flatMapAngle(from: path.point(atDistance: path.length / 2),
                                                               to: path.point(atDistance: path.length / 2 + look)))
        XCTAssertEqual(try XCTUnwrap(path.heading(atDistance: path.length / 2)), expected, accuracy: 1e-9)
    }

    func test_heading_atTheEnd_isAlongTheLastOfThePath() throws {
        let path = greatCircle
        let look = PlaneHeading.lookAhead * path.length
        let expected = try XCTUnwrap(PlaneHeading.flatMapAngle(from: path.point(atDistance: path.length - look), to: cologne))
        XCTAssertEqual(try XCTUnwrap(path.heading(atDistance: path.length)), expected, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(path.heading(atDistance: path.length * 2)), expected, accuracy: 1e-9)
    }

    func test_heading_aPathThatGoesNowhere_isNil() {
        XCTAssertNil(FlightPath(from: louisville, to: louisville).heading(atDistance: 0))
    }
}
```

- [ ] **Step 3: Write `MapFlight` and the path's extension.**

Create `Crewluv/Services/TripMap/Live/MapFlight.swift`:

```swift
//
//  MapFlight.swift
//  CrewLuve
//
//  A flight leg as the trip map measures and draws it (Stage 3 spec §11): the schedule's plan, the path, and once
//  the plane has been seen in the air, its record. The three are made together from one answer of Crewlu Cloud's,
//  so they always agree.
//

import CoreLocation

nonisolated struct MapFlight: Sendable {
    /// The schedule's plan, from the leg's scheduled times moved by its reported delay and by nothing else.
    let plan: FlightPlan
    /// The real path once the plane has been seen in the air, else the great circle between the airports.
    let path: FlightPath
    /// Where the plane was at any moment. Nil without a real path.
    let record: FlightRecord?
    /// The flight's live data, or nil when Crewlu Cloud answered none for its leg.
    let live: LiveFlight?
    /// Crewlu Cloud's clock minus this device's, as of the answer `live` came in.
    let clockOffset: TimeInterval

    /// Nil for a leg that arrives no later than it leaves.
    /// - Parameters:
    ///   - departure: leaving the gate, moved by any reported delay.
    ///   - arrival: reaching the gate, moved by any reported delay.
    init?(
        departure: Date, arrival: Date, from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D,
        live: LiveFlight? = nil, clockOffset: TimeInterval = 0
    ) {
        let distance = GreatCircle.distance(from: origin, to: destination)
        guard let plan = FlightPlan(departure: departure, arrival: arrival, distance: distance) else { return nil }
        let path = FlightPath(from: origin, to: destination, flight: live)
        self.plan = plan
        self.path = path
        record = FlightRecord(path: path, plan: plan)
        self.live = live
        self.clockOffset = clockOffset
    }

    /// The real plane when this device's clock says `now`. A fix's age is measured by Crewlu Cloud's clock, so a
    /// wrong phone clock doesn't age it.
    func progress(at now: Date) -> LiveProgress {
        LiveProgress(plan: plan, path: path, record: record, flight: live, at: now.addingTimeInterval(clockOffset))
    }

    /// Whether `arrival`, the leg's gate arrival as it's shown, is the real plane's estimate, which the words mark
    /// with "about" (spec §9): it isn't the plan's, and the plane hasn't landed.
    func isEstimate(_ arrival: Date) -> Bool {
        live?.state != .landed && abs(arrival.timeIntervalSince(plan.arrival)) >= 1
    }
}
```

Create `Crewluv/Services/TripMap/Live/FlightPath+Drawing.swift`:

```swift
//
//  FlightPath+Drawing.swift
//  CrewLuve
//
//  A flight's path as the trip map draws and frames it (Stage 3 spec §6.2): the places it passes, any part of it
//  between two distances, and the way a plane on it points.
//

import CoreLocation

nonisolated extension FlightPath {

    /// A part of the path that's all one kind, as the places it passes.
    nonisolated struct Run {
        let kind: Kind
        let coordinates: [CLLocationCoordinate2D]
    }

    /// Every place the path passes, from the departure airport to the arrival airport.
    var coordinates: [CLLocationCoordinate2D] {
        stretches.map(\.start) + [destination]
    }

    /// The path between `start` and `end` meters along it, cut wherever its kind changes. Each run begins where the
    /// one before it ended. Empty when `end` isn't past `start`.
    func runs(from start: Double, to end: Double) -> [Run] {
        let from = min(max(start, 0), length)
        let to = min(max(end, 0), length)
        guard to > from else { return [] }
        var runs: [Run] = []
        for stretch in stretches {
            let stretchEnd = stretch.startDistance + stretch.length
            guard stretchEnd > from, stretch.startDistance < to else { continue }
            let first = stretch.startDistance >= from ? stretch.start : point(atDistance: from)
            let last = stretchEnd <= to ? stretch.end : point(atDistance: to)
            if let run = runs.last, run.kind == stretch.kind {
                runs[runs.count - 1] = Run(kind: run.kind, coordinates: run.coordinates + [last])
            } else {
                runs.append(Run(kind: stretch.kind, coordinates: [first, last]))
            }
        }
        return runs
    }

    /// The places the path passes between `start` and `end` meters along it, both ends included. Empty when `end`
    /// isn't past `start`.
    func coordinates(from start: Double, to end: Double) -> [CLLocationCoordinate2D] {
        let runs = runs(from: start, to: end)
        guard let first = runs.first else { return [] }
        return runs.dropFirst().reduce(into: first.coordinates) { $0 += $1.coordinates.dropFirst() }
    }

    /// Places all along the path for the camera to frame (spec §6.2): 33 along a great circle, as before, and every
    /// place a real path passes.
    var framingCoordinates: [CLLocationCoordinate2D] {
        guard length > 0 else { return [origin, destination] }
        return stretches.reduce(into: [origin]) { places, stretch in
            let count = max(Int((stretch.length / length * 32).rounded(.up)), 1) + 1
            places += GreatCircle.points(from: stretch.start, to: stretch.end, count: count).dropFirst()
        }
    }

    /// The angle a plane `distance` meters along the path points at, on a map with north up (`PlaneHeading`): along
    /// the path just ahead of it, or along the last of the path at its end. Nil where the path has no direction.
    func heading(atDistance distance: Double) -> Double? {
        let look = PlaneHeading.lookAhead * length
        guard look > 0 else { return nil }
        let from = min(min(max(distance, 0), length), length - look)
        return PlaneHeading.flatMapAngle(from: point(atDistance: from), to: point(atDistance: from + look))
    }
}
```

`framingCoordinates` gives a great circle the same 33 places the camera framed before, so a flight with no live data is framed exactly as it was.

- [ ] **Step 4: Give `MapLeg` its flight.** The initializer is written out so the tests that make a leg by hand, with no flight, still build.

In `Crewluv/Services/TripMap/MapLeg.swift`:

Replace:

```swift
//  One drawable leg of the trip map: a flight or a drive between two known airports, at its delay-shifted times
//  (moving map spec §7.1, §7.3).
//
```

with:

```swift
//  One drawable leg of the trip map: a flight or a drive between two known airports, at its delay-shifted times
//  (moving map spec §7.1, §7.3). A flight carries its plan, its path and its record (Stage 3 spec §11), and a
//  flight with a real plane has the real plane's times (Stage 3 spec §7.1).
//
```

Replace:

```swift
    let flightNumber: String?

    /// The great-circle distance
```

with:

```swift
    let flightNumber: String?
    /// A flight's plan, its path and, once it's been seen in the air, its record. Nil for a drive, and for a flight
    /// that arrives no later than it leaves.
    let flight: MapFlight?

    init(
        id: String, kind: Kind, origin: AirportMark, destination: AirportMark, start: Date, end: Date,
        flightNumber: String?, flight: MapFlight? = nil
    ) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.destination = destination
        self.start = start
        self.end = end
        self.flightNumber = flightNumber
        self.flight = flight
    }

    /// Whether `end` is the real plane's estimate, which the words mark with "about" (Stage 3 spec §9).
    var isArrivalEstimated: Bool { flight?.isEstimate(end) ?? false }

    /// The great-circle distance
```

- [ ] **Step 5: Checkpoint.** `MapFlightTests` has 6 tests and `FlightPathDrawingTests` 13. Todd runs them with batch A, after Task 4.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): MapFlight keeps a flight's plan, path and record together, FlightPath says what the map draws and frames of it, and MapLeg carries its flight (Stage 3 spec §6.2, §11)`.

---

### Task 4: One landing time: `LiveLegs`

The pure half of spec §7.1. Given the summary's legs and what Crewlu Cloud answered, it says which legs to watch, makes each live flight's `MapFlight`, and writes the legs again with the real plane's times. The status screen's model calls it in Task 9. Until then nothing uses it.

**Files:**
- Create: `CrewluvTests/LiveLegsTests.swift`
- Create: `Crewluv/Services/TripMap/Live/LiveLegs.swift`

- [ ] **Step 1: Write the tests.** `test_replacingTimes_everySharedMoment_givesTheLegTheCasesTimes` runs every moment of every shared flight three times, with no delay, 20 minutes late and 10 minutes early. `test_replacingTimes_theStatusIsInFlightUntilTheRealPlaneArrives_andNoLonger` is the one that goes through `TripStateResolver`.

Create `CrewluvTests/LiveLegsTests.swift`:

```swift
//
//  LiveLegsTests.swift
//  CrewluvTests
//
//  One landing time (Stage 3 spec §7.1): a live flight's real times in place of the schedule's, in the legs the
//  status screen's model hands on. Held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveLegsTests: XCTestCase {

    private func assertEqual(_ date: Date, _ expected: Date, _ name: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.05, name, file: file, line: line)
    }

    /// The flights of `legs` that the case's answer covers, as the model makes them.
    private func flights(
        _ cases: TripMapFixtures.LiveCases, for legs: [TripLeg], answered: [String: LiveFlight], legacyDelayMinutes: Int? = nil
    ) -> [String: MapFlight] {
        LiveLegs.flights(for: legs, legacyDelayMinutes: legacyDelayMinutes, answered: answered, clockOffset: 0,
                         coordinate: cases.coordinateOrNil)
    }

    // MARK: - Which flights are watched

    func test_watched_areTheFlights_atTheirTimesMovedByTheirDelay() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let legs = [
            cases.wait("w1", .base, at: "SDF", from: flightCase.departure.addingTimeInterval(-7200), to: flightCase.departure),
            cases.tripLeg(flightCase, id: "f1", delayMinutes: 20),
            cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400)),
        ]
        XCTAssertEqual(LiveLegs.watched(in: legs),
                       [LiveFlightSource.Leg(id: "f1", departure: flightCase.departure, arrival: flightCase.arrival)])
    }

    func test_watched_legsThatAreOneFlight_areWatchedOnce_underTheFirstOfTheirIDs() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let later = TripMapTestLegs.leg("a-later", from: "SDF", to: "CGN", start: flightCase.arrival.addingTimeInterval(86_400), hours: 8,
                                        flightNumber: "UPS208")
        let legs = [cases.tripLeg(flightCase, id: "twin-b"), later, cases.tripLeg(flightCase, id: "twin-a")]
        XCTAssertEqual(LiveLegs.watched(in: legs).map(\.id), ["twin-a", "a-later"])
        // Whichever comes first in the summary.
        XCTAssertEqual(LiveLegs.watched(in: legs.reversed()).map(\.id), ["twin-a", "a-later"])
    }

    // MARK: - Each flight with live data

    func test_flights_areOnlyTheFlightsCrewluCloudAnswered() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let legs = [cases.tripLeg(flightCase, id: "f1"), cases.tripLeg(flightCase, id: "f2")]
        let made = flights(cases, for: legs, answered: ["f1": live, "gone": live])
        XCTAssertEqual(Array(made.keys), ["f1"])
        XCTAssertEqual(made["f1"]?.live, live)
        XCTAssertEqual(made["f1"]?.path.isReal, true)
        XCTAssertNotNil(made["f1"]?.record)
        XCTAssertTrue(flights(cases, for: legs, answered: [:]).isEmpty)
    }

    func test_flights_planIsTheScheduleMovedByTheLegsOwnDelay() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let made = flights(cases, for: [cases.tripLeg(flightCase, id: "f1", delayMinutes: 20)], answered: ["f1": live])
        XCTAssertEqual(made["f1"]?.plan.departure, flightCase.departure)
        XCTAssertEqual(made["f1"]?.plan.arrival, flightCase.arrival)
    }

    func test_flights_whileADelayIsSummaryWide_areNone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let untagged = [cases.tripLeg(flightCase, id: "f1")]
        XCTAssertTrue(flights(cases, for: untagged, answered: ["f1": live], legacyDelayMinutes: 20).isEmpty)
        XCTAssertEqual(flights(cases, for: untagged, answered: ["f1": live], legacyDelayMinutes: 0).count, 1)
        // A leg that carries its own delay says which flight is late, whatever the summary says.
        let tagged = [cases.tripLeg(flightCase, id: "f1", delayMinutes: 20)]
        XCTAssertEqual(flights(cases, for: tagged, answered: ["f1": live], legacyDelayMinutes: 20).count, 1)
    }

    func test_flights_aLegWithAnAirportThatIsntKnown_hasNone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let live = try XCTUnwrap(cases.live(flightCase))
        let leg = TripMapTestLegs.leg("f1", from: "SDF", to: "XXX", start: flightCase.departure, hours: 2)
        XCTAssertTrue(flights(cases, for: [leg], answered: ["f1": live]).isEmpty)
    }

    // MARK: - The real times

    func test_replacingTimes_withNoLiveData_changesNothing() {
        let legs = TripMapTestLegs.europeTrip()
        XCTAssertEqual(LiveLegs.replacingTimes(in: legs, with: [:], at: TripMapTestLegs.tripStart.addingTimeInterval(3600)), legs)
    }

    func test_replacingTimes_everySharedMoment_givesTheLegTheCasesTimes() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for delayMinutes in [nil, 20, -10] as [Int?] {
            for flightCase in cases.flights {
                let leg = cases.tripLeg(flightCase, delayMinutes: delayMinutes)
                let made = flights(cases, for: [leg], answered: cases.live(flightCase).map { ["f1": $0] } ?? [:])
                for moment in flightCase.moments {
                    let name = "\(flightCase.name) at \(moment.at), delayed \(delayMinutes ?? 0)"
                    let replaced = try XCTUnwrap(LiveLegs.replacingTimes(in: [leg], with: made, at: moment.at).first)
                    let delay = TimeInterval((delayMinutes ?? 0) * 60)
                    // Every reader moves a leg's times by its delay: that must land on the real ones.
                    assertEqual(replaced.startTime.addingTimeInterval(delay), moment.start, name)
                    assertEqual(replaced.endTime.addingTimeInterval(delay), moment.end, name)
                    XCTAssertEqual(replaced.delayMinutes, delayMinutes, name)
                    XCTAssertEqual(replaced.id, leg.id, name)
                    checked += 1
                }
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 60)
    }

    func test_replacingTimes_aFlightWithNothingReal_keepsItsLegUntouched() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "waiting to be seen")
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(LiveLegs.replacingTimes(in: [leg], with: made, at: flightCase.moments[0].at), [leg])
    }

    func test_replacingTimes_theWaitBeforeEnds_andTheWaitAfterStarts_whereTheFlightDoes() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let before = cases.wait("w1", .base, at: "SDF", from: flightCase.departure.addingTimeInterval(-7200), to: flightCase.departure)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [before, cases.tripLeg(flightCase), after]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        XCTAssertEqual(replaced.map(\.id), ["w1", "f1", "w2"])
        // It left 10 minutes early and is 13 minutes ahead.
        XCTAssertEqual(replaced[0].startTime, before.startTime)
        assertEqual(replaced[0].endTime, moment.start)
        assertEqual(replaced[1].startTime, moment.start)
        assertEqual(replaced[1].endTime, moment.end)
        assertEqual(replaced[2].startTime, moment.end)
        XCTAssertEqual(replaced[2].endTime, after.endTime)
    }

    func test_replacingTimes_aLateArrival_startsTheWaitAfterItLater_andLeavesTheWaitBeforeAlone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "off late, and seen from the start")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let before = cases.wait("w1", .turn, at: "SDF", from: flightCase.departure.addingTimeInterval(-3600), to: flightCase.departure)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [before, cases.tripLeg(flightCase), after]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        XCTAssertEqual(replaced[0], before, "a late departure doesn't move the leg's start")
        XCTAssertEqual(replaced[1].startTime, flightCase.departure)
        assertEqual(replaced[1].endTime, moment.end)
        assertEqual(replaced[2].startTime, moment.end)
        XCTAssertGreaterThan(replaced[2].startTime, after.startTime)
    }

    func test_replacingTimes_movesOnlyTheWaitsBesideTheFlight() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let drive = TripMapTestLegs.leg("d1", .drive, from: "CVG", to: "SDF", start: flightCase.departure.addingTimeInterval(-7200), hours: 2)
        let nextFlight = TripMapTestLegs.leg("f2", from: "PHL", to: "SDF", start: flightCase.arrival.addingTimeInterval(3600), hours: 2)
        let home = cases.wait("w3", .home, at: "SDF", from: nextFlight.endTime, to: nextFlight.endTime.addingTimeInterval(86_400))
        let event = cases.wait("e1", .event, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(1800))
        let legs = [drive, cases.tripLeg(flightCase), event, nextFlight, home]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        XCTAssertEqual(replaced[0], drive, "a drive isn't a wait")
        XCTAssertEqual(replaced[2], event, "nor is an event")
        XCTAssertEqual(replaced[3], nextFlight)
        XCTAssertEqual(replaced[4], home, "the wait after another flight")
    }

    func test_replacingTimes_aWaitThatDoesntMeetTheFlight_isLeftAlone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        // Training for half an hour after the flight, and only then the layover.
        let event = cases.wait("e1", .event, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(1800))
        let layover = cases.wait("w2", .layover, at: "PHL", from: event.endTime, to: flightCase.arrival.addingTimeInterval(86_400))
        // And the pilot reached base an hour before the flight, with the wait there written as ending early.
        let base = cases.wait("w1", .base, at: "SDF", from: flightCase.departure.addingTimeInterval(-7200),
                              to: flightCase.departure.addingTimeInterval(-1800))
        let legs = [base, cases.tripLeg(flightCase), event, layover]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        XCTAssertEqual(replaced[0], base)
        XCTAssertEqual(replaced[2], event)
        XCTAssertEqual(replaced[3], layover, "moved to the early arrival, it would start before the training does")
        assertEqual(replaced[1].endTime, moment.end)
    }

    func test_replacingTimes_aWaitMeetsADelayedFlight_atItsScheduledTimeOrItsDelayedOne() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let flight = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [flight], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        for (name, start) in [("as scheduled", flight.endTime), ("as delayed", flightCase.arrival)] {
            let after = cases.wait("w2", .layover, at: "PHL", from: start, to: flightCase.arrival.addingTimeInterval(86_400))
            let replaced = LiveLegs.replacingTimes(in: [flight, after], with: made, at: moment.at)
            assertEqual(replaced[1].startTime, moment.end, name)
        }
    }

    func test_replacingTimes_aWaitBetweenTwoLiveFlights_takesBothItsEdges() throws {
        let cases = try TripMapFixtures.liveCases()
        let first = try cases.flight(named: "landed, seen all the way")
        let second = try cases.flight(named: "ahead, in the air")
        // The second flight is the next day's: the same case, a day on.
        let day: TimeInterval = 86_400
        let firstLeg = cases.tripLeg(first, id: "f1")
        let wait = cases.wait("w1", .layover, at: "PHL", from: first.arrival, to: second.departure.addingTimeInterval(day))
        let secondLeg = TripLeg(id: "f2", tripId: "T1", type: .flight, startTime: second.departure.addingTimeInterval(day),
                                endTime: second.arrival.addingTimeInterval(day), airportCode: nil, city: nil, timezoneIdentifier: nil,
                                arrivalTimezoneIdentifier: nil, flightNumber: "UPS208", departureAirport: second.from,
                                arrivalAirport: second.to, departureCity: nil, arrivalCity: nil, tripDayNumber: nil, tripTotalDays: nil,
                                delayMinutes: nil, airlineCode: nil, label: nil)
        let secondAnswer = try XCTUnwrap(second.flight)
        let aDayOn = LiveFlight(
            legID: "f2", callsign: secondAnswer.callsign, state: secondAnswer.state,
            fix: secondAnswer.fix.map {
                LiveFlight.Fix(latitude: $0.latitude, longitude: $0.longitude, altitudeFeet: $0.altitudeFeet,
                               groundSpeedKnots: $0.groundSpeedKnots, trackDegrees: $0.trackDegrees, isOnGround: $0.isOnGround,
                               registration: $0.registration, typeCode: $0.typeCode, seenAt: $0.seenAt.addingTimeInterval(day))
            },
            landedAt: nil,
            trail: secondAnswer.trail.map {
                LiveFlight.TrailPoint(time: $0.time.addingTimeInterval(day), latitude: $0.latitude, longitude: $0.longitude,
                                      altitudeFeet: $0.altitudeFeet)
            })
        let legs = [firstLeg, wait, secondLeg]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(first)), "f2": aDayOn])
        let moment = try cases.moment("13T12:41:50", of: second)

        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at.addingTimeInterval(day))

        assertEqual(replaced[1].startTime, replaced[0].endTime, "it starts where the first flight ended")
        assertEqual(replaced[1].endTime, replaced[2].startTime, "and ends where the second began")
        XCTAssertLessThan(replaced[1].startTime, wait.startTime)
        XCTAssertLessThan(replaced[1].endTime, wait.endTime)
    }

    @MainActor
    func test_replacingTimes_theStatusIsInFlightUntilTheRealPlaneArrives_andNoLonger() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let after = cases.wait("w2", .layover, at: "PHL", from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [cases.tripLeg(flightCase), after]
        let made = flights(cases, for: legs, answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: legs, with: made, at: moment.at)

        // The plane is 13 minutes ahead. Five minutes before the scheduled arrival it has already reached the gate.
        let fiveBefore = flightCase.arrival.addingTimeInterval(-300)
        XCTAssertEqual(TripStateResolver.resolve(legs: legs, at: fiveBefore)?.displayStatus, .inFlight, "by the schedule")
        XCTAssertEqual(TripStateResolver.resolve(legs: replaced, at: fiveBefore)?.displayStatus, .layover, "by the real plane")
        let stillFlying = moment.end.addingTimeInterval(-60)
        XCTAssertEqual(TripStateResolver.resolve(legs: replaced, at: stillFlying)?.displayStatus, .inFlight)
        // And it left 10 minutes early: five minutes before the scheduled departure it's already under way.
        let fiveBeforeLeaving = flightCase.departure.addingTimeInterval(-300)
        XCTAssertNil(TripStateResolver.resolve(legs: legs, at: fiveBeforeLeaving), "by the schedule, nothing has started")
        XCTAssertEqual(TripStateResolver.resolve(legs: replaced, at: fiveBeforeLeaving)?.displayStatus, .inFlight)
    }

    // MARK: - "About"

    func test_isArrivalEstimated_isTrueOfALegWhoseEndIsTheRealPlanesEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = try XCTUnwrap(LiveLegs.replacingTimes(in: [leg], with: made, at: moment.at).first)
        XCTAssertFalse(LiveLegs.isArrivalEstimated(of: leg, in: made), "the schedule's time")
        XCTAssertTrue(LiveLegs.isArrivalEstimated(of: replaced, in: made))
        XCTAssertFalse(LiveLegs.isArrivalEstimated(of: replaced, in: [:]), "a flight with no live data")
    }

    func test_isArrivalEstimated_isFalseOnceThePlaneHasLanded() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "landed, seen all the way")
        let leg = cases.tripLeg(flightCase)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = try XCTUnwrap(LiveLegs.replacingTimes(in: [leg], with: made, at: flightCase.moments[0].at).first)
        XCTAssertNotEqual(replaced.endTime, leg.endTime)
        XCTAssertFalse(LiveLegs.isArrivalEstimated(of: replaced, in: made))
    }

    // MARK: - The legs as the status carries them

    func test_blob_isReadBackAsTheSameLegs() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = cases.tripLeg(flightCase, delayMinutes: 20)
        let made = flights(cases, for: [leg], answered: ["f1": try XCTUnwrap(cases.live(flightCase))])
        let replaced = LiveLegs.replacingTimes(in: [leg], with: made, at: moment.at)

        let blob = try XCTUnwrap(LiveLegs.blob(replaced))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let read = try decoder.decode([TripLeg].self, from: blob)

        XCTAssertEqual(read.count, 1)
        assertEqual(read[0].endTime.addingTimeInterval(20 * 60), moment.end)
        XCTAssertTrue(LiveLegs.isArrivalEstimated(of: read[0], in: made), "it's still marked an estimate after the status carried it")
        XCTAssertEqual(LiveLegs.blob(replaced), blob, "the same legs, the same bytes")
    }
}
```

- [ ] **Step 2: Write `LiveLegs`.**

Create `Crewluv/Services/TripMap/Live/LiveLegs.swift`:

```swift
//
//  LiveLegs.swift
//  CrewLuve
//
//  One landing time (Stage 3 spec §7.1). The status screen's model hands the summary's legs to everything that
//  reads them: the status, the map, the countdown, the narrative and the trip cards. Before it does, each flight
//  with live data gets its real times here in place of the schedule's, so no card works them out itself.
//

import CoreLocation

nonisolated enum LiveLegs {

    /// The summary's flights for `LiveFlightSource` to watch: each one's id, and its gate times moved by its delay.
    /// Legs that are one flight, with the same number, departure airport and scheduled departure, are answered
    /// once by Crewlu Cloud, under the first of their ids in text order: only that one is watched, or the others'
    /// windows would stay open after the flight had landed.
    static func watched(in legs: [TripLeg]) -> [LiveFlightSource.Leg] {
        var firstOfEachFlight: [String: TripLeg] = [:]
        for leg in legs where leg.type == .flight {
            let flight = "\(leg.flightNumber ?? "")|\(leg.departureAirport ?? "")|\(leg.startTime.timeIntervalSince1970)"
            if let kept = firstOfEachFlight[flight], kept.id <= leg.id { continue }
            firstOfEachFlight[flight] = leg
        }
        return firstOfEachFlight.values
            .sorted { ($0.startTime, $0.id) < ($1.startTime, $1.id) }
            .map {
                LiveFlightSource.Leg(id: $0.id, departure: $0.effectiveStart, arrival: $0.effectiveEnd)
            }
    }

    /// Each flight of `legs` that Crewlu Cloud answered, by its leg's id: its plan, from its scheduled times moved
    /// by its own delay, with the path and the record made from the answer.
    /// - Parameters:
    ///   - legacyDelayMinutes: the summary-wide delay of a CrewLu that doesn't tag legs. While one is in effect
    ///     there's no leg to hold the real times against, so no flight has live data and the schedule shows.
    ///   - answered: `LiveFlightSource.flights`.
    ///   - clockOffset: `LiveFlightSource.clockOffset`.
    ///   - coordinate: where an airport is, by code.
    static func flights(
        for legs: [TripLeg], legacyDelayMinutes: Int?, answered: [String: LiveFlight], clockOffset: TimeInterval,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> [String: MapFlight] {
        let isDelaySummaryWide = (legacyDelayMinutes ?? 0) != 0 && !legs.contains { ($0.delayMinutes ?? 0) != 0 }
        guard !answered.isEmpty, !isDelaySummaryWide else { return [:] }
        var flights: [String: MapFlight] = [:]
        for leg in legs where leg.type == .flight {
            guard let live = answered[leg.id],
                  let origin = leg.departureAirport.flatMap(coordinate),
                  let destination = leg.arrivalAirport.flatMap(coordinate) else { continue }
            flights[leg.id] = MapFlight(departure: leg.effectiveStart, arrival: leg.effectiveEnd,
                                        from: origin, to: destination, live: live, clockOffset: clockOffset)
        }
        return flights
    }

    /// `legs` with each live flight's real times at `now`, this device's time, in place of the schedule's
    /// (`LiveProgress.start` and `.end`). The wait before such a flight ends, and the wait after it starts, where
    /// the flight does: the wait next in line, when its own edge is where the flight's was. A leg's delay stays on
    /// it, and its times are set so that the delay moves them to the real ones, as every reader of a leg expects.
    static func replacingTimes(in legs: [TripLeg], with flights: [String: MapFlight], at now: Date) -> [TripLeg] {
        guard !flights.isEmpty else { return legs }
        var replaced = legs
        // The legs that follow one another: flights, drives and CrewLu's waits, in the order they start.
        let chain = legs.indices
            .filter { legs[$0].type == .flight || legs[$0].type == .drive || waitTypes.contains(legs[$0].type) }
            .sorted { (legs[$0].startTime, $0) < (legs[$1].startTime, $1) }
        for (place, index) in chain.enumerated() {
            let leg = legs[index]
            guard leg.type == .flight, let flight = flights[leg.id] else { continue }
            let progress = flight.progress(at: now)
            let isStartReal = progress.start != flight.plan.departure
            let isEndReal = progress.end != flight.plan.arrival
            guard isStartReal || isEndReal, progress.end > progress.start else { continue }
            replaced[index] = leg.with(startTime: isStartReal ? progress.start.addingTimeInterval(-leg.delay) : leg.startTime,
                                       endTime: isEndReal ? progress.end.addingTimeInterval(-leg.delay) : leg.endTime)
            if isStartReal, place > 0 {
                let before = replaced[chain[place - 1]]
                if waitTypes.contains(before.type), meets(before.endTime, leg.startTime, leg.effectiveStart),
                   progress.start > before.startTime {
                    replaced[chain[place - 1]] = before.with(startTime: before.startTime, endTime: progress.start)
                }
            }
            if isEndReal, place + 1 < chain.count {
                let after = replaced[chain[place + 1]]
                if waitTypes.contains(after.type), meets(after.startTime, leg.endTime, leg.effectiveEnd),
                   progress.end < after.endTime {
                    replaced[chain[place + 1]] = after.with(startTime: progress.end, endTime: after.endTime)
                }
            }
        }
        return replaced
    }

    /// Whether the gate arrival `leg` shows is the real plane's estimate, which the words mark with "about"
    /// (spec §9).
    static func isArrivalEstimated(of leg: TripLeg, in flights: [String: MapFlight]) -> Bool {
        flights[leg.id]?.isEstimate(leg.effectiveEnd) ?? false
    }

    /// The legs as the status carries them, written as `CloudSummary` writes them: sorted keys give the same legs
    /// the same bytes on every run.
    static func blob(_ legs: [TripLeg]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(legs)
    }

    // MARK: - Private

    /// CrewLu's waits on the ground, which a flight's real times move the edges of.
    private static let waitTypes: Set<TripLeg.LegType> = [.turn, .layover, .home, .base]

    /// Whether a wait's `edge` is where its flight's was, within a minute: at the scheduled time, as CrewLu writes
    /// its waits, or at that time moved by the flight's delay. A wait that begins later, after an event say, isn't
    /// the flight's to move.
    private static func meets(_ edge: Date, _ scheduled: Date, _ delayed: Date) -> Bool {
        abs(edge.timeIntervalSince(scheduled)) <= 60 || abs(edge.timeIntervalSince(delayed)) <= 60
    }
}

nonisolated private extension TripLeg {
    /// The leg's own reported delay, in seconds: early when negative.
    var delay: TimeInterval { TimeInterval((delayMinutes ?? 0) * 60) }

    /// Leaving the gate and reaching it, moved by the leg's own delay, as `TripStateResolver` moves them.
    var effectiveStart: Date { startTime.addingTimeInterval(delay) }
    var effectiveEnd: Date { endTime.addingTimeInterval(delay) }

    /// The leg at other times.
    func with(startTime: Date, endTime: Date) -> TripLeg {
        TripLeg(id: id, tripId: tripId, type: type, startTime: startTime, endTime: endTime, airportCode: airportCode,
                city: city, timezoneIdentifier: timezoneIdentifier, arrivalTimezoneIdentifier: arrivalTimezoneIdentifier,
                flightNumber: flightNumber, departureAirport: departureAirport, arrivalAirport: arrivalAirport,
                departureCity: departureCity, arrivalCity: arrivalCity, tripDayNumber: tripDayNumber,
                tripTotalDays: tripTotalDays, delayMinutes: delayMinutes, airlineCode: airlineCode, label: label)
    }
}
```

It doesn't call `TripStateResolver.effectiveStart(of:)`: that type is on the main actor, and this one isn't. The extension at the foot moves a leg's times by its delay the same way.

- [ ] **Step 3: Review batch A.** Dispatch `superpowers:code-reviewer` (sonnet) on Tasks 2 to 4, with the spec's §6.1, §7.1 and §11 and this plan's list of where it differs. Use `superpowers:receiving-code-review` on what comes back.

- [ ] **Step 4: Checkpoint, batch A.** Todd runs:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:CrewluvTests/LiveFlightSourceTests -only-testing:CrewluvTests/MapFlightTests -only-testing:CrewluvTests/FlightPathDrawingTests -only-testing:CrewluvTests/LiveLegsTests
```

Expected: 69 tests pass (31, 6, 13 and 19).

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): LiveLegs gives each flight with live data the real plane's times in the legs, with the waits either side moved to meet them, and says which legs to watch (Stage 3 spec §7.1)`.

---

### Task 5: The map takes the flights, the camera frames their paths, and the replay's clock carries on

**Files:**
- Create: `CrewluvTests/LiveTripMapTests.swift`
- Create: `CrewluvTests/TripReplayClockCarryTests.swift`
- Modify: `Crewluv/Services/TripMap/TripMap.swift`
- Modify: `Crewluv/Services/TripMap/TripMap+Status.swift`
- Modify: `Crewluv/Views/TripMap/TripMap+Camera.swift`
- Modify: `Crewluv/Services/TripMap/TripReplayClock.swift`

- [ ] **Step 1: Write the tests.**

Create `CrewluvTests/LiveTripMapTests.swift`:

```swift
//
//  LiveTripMapTests.swift
//  CrewluvTests
//
//  The trip map with a real plane (Stage 3 spec §6.2, §11): each flight carries its plan, path and record, and the
//  camera frames the real path.
//

import XCTest
import CoreLocation
import MapKit
@testable import Crewluv

final class LiveTripMapTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { start.addingTimeInterval(value * 3600) }

    /// The map the status screen would make of a shared case's flight at one of its moments: the model's flights,
    /// its legs at their real times, and the map from both.
    private func map(of name: String, at time: String) throws -> (map: TripMap, moment: TripMapFixtures.LiveCases.Flight.Moment) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let after = cases.wait("w2", .layover, at: flightCase.to, from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [cases.tripLeg(flightCase), after]
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: cases.live(flightCase).map { ["f1": $0] } ?? [:],
                                       clockOffset: 0, coordinate: cases.coordinateOrNil)
        let replaced = LiveLegs.replacingTimes(in: legs, with: flights, at: moment.at)
        let map = try XCTUnwrap(TripMap.make(tripLegs: replaced, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                                             flights: flights, at: moment.at, coordinate: cases.coordinateOrNil))
        return (map, moment)
    }

    // MARK: - What each leg carries

    func test_make_aFlightWithNoLiveData_carriesTheSchedulesPlanAndTheGreatCircle() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(firstDelayMinutes: 20), at: hours(4)))
        let leg = try XCTUnwrap(map.legs.first)
        let flight = try XCTUnwrap(leg.flight)
        XCTAssertEqual(flight.plan.departure, leg.start, "the plan is the schedule moved by the delay")
        XCTAssertEqual(flight.plan.arrival, leg.end)
        XCTAssertFalse(flight.path.isReal)
        XCTAssertNil(flight.record)
        XCTAssertNil(flight.live)
        XCTAssertFalse(leg.isArrivalEstimated)
    }

    func test_make_aDrive_carriesNoFlight() throws {
        let legs = [TripMapTestLegs.leg("d1", .drive, from: "LEX", to: "SDF", start: hours(0), hours: 2)]
        let map = try XCTUnwrap(TripMapTestLegs.map(legs, at: hours(1)))
        XCTAssertNil(map.legs.first?.flight)
    }

    func test_make_aFlightWithLiveData_carriesItsRealPath_atTheRealPlanesTimes() throws {
        let (map, moment) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let leg = try XCTUnwrap(map.legs.first)
        XCTAssertEqual(map.mode, .inFlight(legID: "f1"))
        XCTAssertEqual(leg.start.timeIntervalSince1970, moment.start.timeIntervalSince1970, accuracy: 0.05)
        XCTAssertEqual(leg.end.timeIntervalSince1970, moment.end.timeIntervalSince1970, accuracy: 0.05)
        let flight = try XCTUnwrap(leg.flight)
        XCTAssertTrue(flight.path.isReal)
        XCTAssertNotNil(flight.record)
        XCTAssertNotEqual(flight.plan.arrival, leg.end, "the plan keeps the schedule's times")
        XCTAssertTrue(leg.isArrivalEstimated)
    }

    func test_make_aLandedFlight_hasNoEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "landed, seen all the way")
        let moment = flightCase.moments[0]
        let leg = try cases.mapLeg(flightCase, at: moment)
        XCTAssertNotEqual(leg.end, flightCase.arrival)
        XCTAssertFalse(leg.isArrivalEstimated)
    }

    // MARK: - The camera

    func test_framingCoordinates_ofAFlightWithNoLiveData_areTheGreatCirclesOfBefore() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: hours(4)))
        let leg = try XCTUnwrap(map.currentLeg)
        let before = GreatCircle.points(from: leg.origin.coordinate, to: leg.destination.coordinate, count: 33)
        let places = map.framingCoordinates(focusingOn: leg)
        XCTAssertEqual(places.count, 33)
        for (place, expected) in zip(places, before) {
            XCTAssertEqual(place.latitude, expected.latitude, accuracy: 1e-9)
            XCTAssertEqual(place.longitude, expected.longitude, accuracy: 1e-9)
        }
    }

    func test_framingRect_ofAFlightWithARealPath_holdsEveryPlaceItWasSeen() throws {
        let (map, _) = try map(of: "off early and the long way round", at: "13T12:15:20")
        let leg = try XCTUnwrap(map.currentLeg)
        let path = try XCTUnwrap(leg.flight?.path)
        let rect = try XCTUnwrap(map.framingRect(focusingOn: leg))
        for stretch in path.stretches {
            XCTAssertTrue(rect.contains(MKMapPoint(stretch.start)), "\(stretch.start)")
        }
    }

    func test_framingRect_ofAPathFarFromTheGreatCircle_reachesIt() throws {
        // Louisville to Cologne by way of Iceland, well north of the straight line between them.
        let louisville = try XCTUnwrap(TripMapTestLegs.coordinate("SDF"))
        let cologne = try XCTUnwrap(TripMapTestLegs.coordinate("CGN"))
        let iceland = CLLocationCoordinate2D(latitude: 66, longitude: -20)
        let seen = LiveFlight.TrailPoint(time: hours(4), latitude: iceland.latitude, longitude: iceland.longitude, altitudeFeet: 38_000)
        let live = LiveFlight(legID: "f1", callsign: "UPS207", state: .airborne, fix: nil, landedAt: nil, trail: [seen])
        let flight = try XCTUnwrap(MapFlight(departure: hours(0), arrival: hours(8), from: louisville, to: cologne, live: live))
        let legs = [TripMapTestLegs.leg("f1", from: "SDF", to: "CGN", start: hours(0), hours: 8)]
        let map = try XCTUnwrap(TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                                             flights: ["f1": flight], at: hours(4), coordinate: TripMapTestLegs.coordinate))
        let leg = try XCTUnwrap(map.currentLeg)

        let straight = try XCTUnwrap(MapFit.rect(enclosing: GreatCircle.points(from: louisville, to: cologne, count: 33)))
        XCTAssertFalse(straight.contains(MKMapPoint(iceland)), "the straight line's frame leaves Iceland out")
        XCTAssertTrue(try XCTUnwrap(map.framingRect(focusingOn: leg)).contains(MKMapPoint(iceland)))
        XCTAssertTrue(try XCTUnwrap(map.framingRect(focusingOn: nil)).contains(MKMapPoint(iceland)), "and so does the whole trip's")
    }

    func test_framingKey_isTheFramingRectAsNumbers_andChangesWhenItDoes() throws {
        let (straight, _) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let (longWay, _) = try map(of: "off early and the long way round", at: "13T12:15:20")
        let leg = try XCTUnwrap(straight.currentLeg)
        let rect = try XCTUnwrap(straight.framingRect(focusingOn: leg))
        XCTAssertEqual(straight.framingKey(focusingOn: leg), [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height])
        XCTAssertNotEqual(straight.framingKey(focusingOn: leg), longWay.framingKey(focusingOn: try XCTUnwrap(longWay.currentLeg)))
    }
}
```

Create `CrewluvTests/TripReplayClockCarryTests.swift`:

```swift
//
//  TripReplayClockCarryTests.swift
//  CrewluvTests
//
//  The full-screen map's clock when the trip's times change under it, as they do with each new landing estimate
//  of the real plane (Stage 3 spec §7.3): the replay carries on from the same moment.
//

import XCTest
@testable import Crewluv

final class TripReplayClockCarryTests: XCTestCase {

    private let span = DateInterval(start: Date(timeIntervalSince1970: 1_800_000_000), duration: 2 * 86_400)
    private let now = Date(timeIntervalSince1970: 1_800_050_000)
    /// The same trip, ending 20 minutes sooner.
    private var sooner: DateInterval { DateInterval(start: span.start, end: span.end.addingTimeInterval(-1200)) }

    func test_carried_aLiveClock_staysLive() {
        let clock = TripReplayClock(span: span).carried(to: sooner, legs: [], waits: [], at: now)
        XCTAssertTrue(clock.isLive)
        XCTAssertEqual(clock.span, sooner)
        XCTAssertEqual(clock.time(at: now), now)
    }

    func test_carried_aPausedClock_staysAtItsMoment() {
        var clock = TripReplayClock(span: span)
        let moment = span.start.addingTimeInterval(30_000)
        clock.scrub(to: moment)

        let carried = clock.carried(to: sooner, legs: [], waits: [], at: now)

        XCTAssertFalse(carried.isLive)
        XCTAssertFalse(carried.isPlaying)
        XCTAssertEqual(carried.time(at: now), moment)
        XCTAssertEqual(carried.time(at: now.addingTimeInterval(60)), moment, "and stays paused")
    }

    func test_carried_aPlayingClock_playsOnFromTheSameMoment_atTheSameSpeed() {
        var clock = TripReplayClock(span: span)
        clock.play(at: now)
        clock.setSpeed(.five, at: now)
        let later = now.addingTimeInterval(10)
        let moment = clock.time(at: later)

        let carried = clock.carried(to: sooner, legs: [], waits: [], at: later)

        XCTAssertTrue(carried.isPlaying)
        XCTAssertEqual(carried.speed, .five)
        XCTAssertEqual(carried.time(at: later), moment)
        XCTAssertEqual(carried.time(at: later.addingTimeInterval(2)), moment.addingTimeInterval(2 * 5 * TripReplayClock.baseRate))
    }

    func test_carried_aMomentPastTheNewEnd_isHeldToIt() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.end)
        XCTAssertEqual(clock.carried(to: sooner, legs: [], waits: [], at: now).time(at: now), sooner.end)
    }

    func test_carried_aFinishedReplay_staysAtTheEnd_paused() {
        var clock = TripReplayClock(span: span)
        clock.scrub(to: span.end.addingTimeInterval(-TripReplayClock.baseRate))
        clock.play(at: now)
        let after = now.addingTimeInterval(5)
        XCTAssertTrue(clock.hasFinished(at: after))

        let carried = clock.carried(to: span, legs: [], waits: [], at: after)

        XCTAssertFalse(carried.isPlaying, "it doesn't start over by itself")
        XCTAssertEqual(carried.time(at: after), span.end)
    }

    func test_carried_keepsQuickLayovers_andTakesTheNewLegsPace() {
        let wait = TripReplayClock.Stretch(start: span.start.addingTimeInterval(3600), end: span.end.addingTimeInterval(-3600))
        let flight = TripReplayClock.Stretch(start: span.start, end: wait.start)
        var clock = TripReplayClock(span: span, isQuickLayovers: true)
        clock.scrub(to: span.start)

        let carried = clock.carried(to: span, legs: [flight], waits: [wait], at: now)

        XCTAssertTrue(carried.isQuickLayovers)
        XCTAssertLessThan(carried.replayDuration, clock.replayDuration, "the new clock hurries through the wait")
    }
}
```

- [ ] **Step 2: Hand the flights to the map.** `make` takes them with a default of none, so every caller there is today still builds. A flight with none gets its `MapFlight` here, from its own times.

In `Crewluv/Services/TripMap/TripMap.swift`:

Replace:

```swift
    /// The places the camera must show: one leg's arc, or every leg's arcs and home.
    func framingCoordinates(focusingOn leg: MapLeg?) -> [CLLocationCoordinate2D] {
        let shown = leg.map { [$0] } ?? legs
        var coordinates = shown.flatMap {
            GreatCircle.points(from: $0.origin.coordinate, to: $0.destination.coordinate, count: 33)
        }
```

with:

```swift
    /// The places the camera must show: one leg's path, or every leg's paths and home. A flight's path is its real
    /// one once the plane has been seen in the air (Stage 3 spec §6.2).
    func framingCoordinates(focusingOn leg: MapLeg?) -> [CLLocationCoordinate2D] {
        let shown = leg.map { [$0] } ?? legs
        var coordinates = shown.flatMap {
            $0.flight?.path.framingCoordinates
                ?? GreatCircle.points(from: $0.origin.coordinate, to: $0.destination.coordinate, count: 33)
        }
```

Replace:

```swift
    /// - `coordinate`: where an airport is, by code.
    static func make(
```

with:

```swift
    /// - `flights`: each flight with live data, by its leg's id (`LiveLegs.flights`). Such a leg's times in
    ///   `tripLegs` are already the real plane's (`LiveLegs.replacingTimes`).
    /// - `coordinate`: where an airport is, by code.
    static func make(
```

Replace:

```swift
        legacyDelayMinutes: Int?,
        at now: Date,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> TripMap? {
```

with:

```swift
        legacyDelayMinutes: Int?,
        flights: [String: MapFlight] = [:],
        at now: Date,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> TripMap? {
```

Replace:

```swift
                   extraDelayMinutes: leg.id == legacyDelay?.legID ? legacyDelay?.minutes : nil,
                   coordinate: coordinate)
```

with:

```swift
                   extraDelayMinutes: leg.id == legacyDelay?.legID ? legacyDelay?.minutes : nil,
                   flights: flights,
                   coordinate: coordinate)
```

Replace:

```swift
        extraDelayMinutes: Int?,
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> MapLeg? {
```

with:

```swift
        extraDelayMinutes: Int?,
        flights: [String: MapFlight],
        coordinate: (String) -> CLLocationCoordinate2D?
    ) -> MapLeg? {
```

Replace:

```swift
        return MapLeg(
            id: leg.id,
            kind: kind,
            origin: AirportMark(code: originCode, city: leg.departureCity, coordinate: originCoordinate, timeZone: originZone),
            destination: AirportMark(code: destinationCode, city: leg.arrivalCity, coordinate: destinationCoordinate, timeZone: destinationZone),
            start: leg.startTime.addingTimeInterval(delay),
            end: leg.endTime.addingTimeInterval(delay),
            flightNumber: leg.flightNumber
        )
```

with:

```swift
        let start = leg.startTime.addingTimeInterval(delay)
        let end = leg.endTime.addingTimeInterval(delay)
        // A flight with no live data has the schedule's plan and the great circle.
        let flight = kind == .flight
            ? flights[leg.id] ?? MapFlight(departure: start, arrival: end, from: originCoordinate, to: destinationCoordinate)
            : nil
        return MapLeg(
            id: leg.id,
            kind: kind,
            origin: AirportMark(code: originCode, city: leg.departureCity, coordinate: originCoordinate, timeZone: originZone),
            destination: AirportMark(code: destinationCode, city: leg.arrivalCity, coordinate: destinationCoordinate, timeZone: destinationZone),
            start: start,
            end: end,
            flightNumber: leg.flightNumber,
            flight: flight
        )
```

In `Crewluv/Services/TripMap/TripMap+Status.swift`:

Replace:

```swift
    /// The status screen's trip map, or nil when there's nothing to draw.
    init?(status: SharedPilotStatus, at now: Date) {
```

with:

```swift
    /// The status screen's trip map, or nil when there's nothing to draw. `flights` is each flight with live data,
    /// by its leg's id, as the screen's model hands them on with the status (Stage 3 spec §11).
    init?(status: SharedPilotStatus, flights: [String: MapFlight] = [:], at now: Date) {
```

Replace:

```swift
                                     legacyDelayMinutes: status.flightDelayMinutes, at: now, coordinate: coordinate) else { return nil }
```

with:

```swift
                                     legacyDelayMinutes: status.flightDelayMinutes, flights: flights, at: now,
                                     coordinate: coordinate) else { return nil }
```

In `Crewluv/Views/TripMap/TripMap+Camera.swift`:

Replace:

```swift
        MapFit.rect(enclosing: framingCoordinates(focusingOn: leg))
    }
```

with:

```swift
        MapFit.rect(enclosing: framingCoordinates(focusingOn: leg))
    }

    /// `framingRect` as numbers a view can compare, so the card frames the trip again when a real path grows past
    /// what it showed (Stage 3 spec §6.2). Empty when there's nothing to frame.
    func framingKey(focusingOn leg: MapLeg?) -> [Double] {
        guard let rect = framingRect(focusingOn: leg) else { return [] }
        return [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
    }
```

- [ ] **Step 3: Let the clock carry on.**

In `Crewluv/Services/TripMap/TripReplayClock.swift`:

Replace:

```swift
    mutating func goLive() {
        anchor = nil
    }
}
```

with:

```swift
    mutating func goLive() {
        anchor = nil
    }

    /// The clock for the same trip with new times, such as the real plane's newest landing estimate (Stage 3 spec
    /// §7.3): at the same moment, playing or paused as this one is, at the same speed and pace. A live clock stays
    /// live.
    func carried(to span: DateInterval, legs: [Stretch], waits: [Stretch], at now: Date) -> TripReplayClock {
        var clock = TripReplayClock(span: span, legs: legs, waits: waits, isQuickLayovers: isQuickLayovers)
        clock.speed = speed
        guard !isLive else { return clock }
        clock.scrub(to: time(at: now))
        if isPlaying, !hasFinished(at: now) {
            clock.play(at: now)
        }
        return clock
    }
}
```

- [ ] **Step 4: Checkpoint.** `LiveTripMapTests` has 8 tests and `TripReplayClockCarryTests` 6. Todd runs them with batch B, after Task 7.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): the trip map takes each flight's plan, path and record, its camera frames the real path, and the replay's clock keeps its moment when the trip's times change (Stage 3 spec §6.2, §7.3, §11)`.

---

### Task 6: The drawing: the real path, the real plane and the ghost

`FlightDrawing` is where the map chooses what to draw of a flight, by `LiveProgress.phase`. Four view files change with it, because two enums gain cases and their switches must cover them: the app doesn't build between them.

| The flight is | Lines | Planes |
|---|---|---|
| past its gate | one grey line along its path, real or not | none |
| still to leave its gate | dashed along its path | none |
| between its gates, not live | as before: the great circle, flown and ahead | the schedule's |
| on the ground at the departure airport | the whole path dashed | the real plane at its fix, and the ghost |
| in the air | solid where it was seen, dotted where it wasn't, dashed ahead | the real plane at its fix, and the ghost |
| estimated | the same, with the plan's line dotted from its last fix to it | the real plane faded, and the ghost |
| landed | the whole path flown | the real plane at the arrival airport |
| on the ground somewhere else | flown as far as it was seen, dashed from there | the real plane where it is |
| at a moment of the replay, with a record | flown as far as the record has it, dashed from there | the real plane alone |

**Files:**
- Create: `CrewluvTests/FlightDrawingTests.swift`
- Create: `CrewluvTests/LiveMarkerTests.swift`
- Create: `Crewluv/Services/TripMap/FlightDrawing.swift`
- Modify: `Crewluv/Services/TripMap/TripMapDrawing.swift`
- Modify: `Crewluv/Views/TripMap/TripMapPalette.swift`
- Modify: `Crewluv/Views/TripMap/TripMapMarker.swift`
- Modify: `Crewluv/Views/TripMap/TripMapMarkerView.swift`
- Modify: `Crewluv/Views/TripMap/PlaneMarker.swift`
- Modify: `Crewluv/Views/TripMap/TripMapAnnotationView.swift`
- Modify: `Crewluv/Views/TripMap/TripMapShapesView.swift`

- [ ] **Step 1: Write the tests.** `test_now_everySharedMoment_drawsThePlanesTheCaseExpects` draws every moment of every shared flight, and checks the planes against the case's own places and the lines for a break.

Create `CrewluvTests/FlightDrawingTests.swift`:

```swift
//
//  FlightDrawingTests.swift
//  CrewluvTests
//
//  What one flight draws at a moment (Stage 3 spec §5.1, §6.2, §7.3): the real path and the two planes, by what
//  the live data says, and the schedule's plane where there's none. Held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightDrawingTests: XCTestCase {

    private typealias Moment = TripMapFixtures.LiveCases.Flight.Moment

    private func assertSame(_ place: CLLocationCoordinate2D?, _ expected: CLLocationCoordinate2D?, _ name: String = "",
                            accuracy: Double = 1e-9, file: StaticString = #filePath, line: UInt = #line) {
        guard let place, let expected else {
            XCTFail("a place is missing: \(name)", file: file, line: line)
            return
        }
        XCTAssertEqual(place.latitude, expected.latitude, accuracy: accuracy, name, file: file, line: line)
        XCTAssertEqual(place.longitude, expected.longitude, accuracy: accuracy, name, file: file, line: line)
    }

    private func place(_ pair: [Double]?) -> CLLocationCoordinate2D? {
        pair.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
    }

    /// The leg of a shared case at one of its moments, and its drawing then.
    private func drawing(of name: String, at time: String, isReplay: Bool = false) throws -> (drawing: FlightDrawing, leg: MapLeg, moment: Moment) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        return (FlightDrawing(leg: leg, at: moment.at, isReplay: isReplay), leg, moment)
    }

    // MARK: - Now

    func test_now_everySharedMoment_drawsThePlanesTheCaseExpects() throws {
        let cases = try TripMapFixtures.liveCases()
        var real = 0
        var scheduled = 0
        for flightCase in cases.flights {
            for moment in flightCase.moments {
                let name = "\(flightCase.name) at \(moment.at)"
                let leg = try cases.mapLeg(flightCase, at: moment)
                guard leg.isMoving(at: moment.at) else { continue }
                let drawing = FlightDrawing(leg: leg, at: moment.at, isReplay: false)
                if let plane = place(moment.plane) {
                    assertSame(drawing.realPlane?.coordinate, plane, name, accuracy: 0.0001)
                    XCTAssertEqual(drawing.realPlane?.isEstimated, moment.phase == "estimated", name)
                    XCTAssertNil(drawing.plane, name)
                    if let ghost = place(moment.ghost) {
                        assertSame(drawing.ghost?.coordinate, ghost, name, accuracy: 0.0001)
                    } else {
                        XCTAssertNil(drawing.ghost, name)
                    }
                    real += 1
                } else {
                    XCTAssertNotNil(drawing.plane, name)
                    XCTAssertNil(drawing.realPlane, name)
                    XCTAssertNil(drawing.ghost, name)
                    scheduled += 1
                }
                // The lines run from the departure airport to the arrival airport without a break.
                assertSame(drawing.segments.first?.coordinates.first, leg.origin.coordinate, name)
                assertSame(drawing.segments.last?.coordinates.last, leg.destination.coordinate, name)
                for (earlier, later) in zip(drawing.segments, drawing.segments.dropFirst()) {
                    assertSame(later.coordinates.first, earlier.coordinates.last, name)
                }
            }
        }
        XCTAssertGreaterThanOrEqual(real, 12)
        XCTAssertGreaterThanOrEqual(scheduled, 3)
    }

    func test_now_inTheAir_theRealPathIsSolidBehindThePlane_andDashedAhead() throws {
        let (drawing, leg, _) = try drawing(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(drawing.segments.map(\.style), [.seen, .upcoming])
        XCTAssertEqual(drawing.segments.map(\.id), ["f1-seen-0", "f1-upcoming"])
        let path = try XCTUnwrap(leg.flight?.path)
        XCTAssertEqual(drawing.segments[0].coordinates.count, path.knots.count + 1, "the airport, and every place it was seen")
        assertSame(drawing.segments[0].coordinates.last, drawing.realPlane?.coordinate, "the line meets the plane")
        XCTAssertEqual(drawing.segments[1].coordinates.count, 2, "from the plane straight to the airport")
        XCTAssertTrue(drawing.segments.allSatisfy(\.isGeodesic))
    }

    func test_now_inTheAir_thePlanePointsTheWayItsReallyGoing() throws {
        let (drawing, leg, _) = try drawing(of: "ahead, in the air", at: "13T12:41:50")
        let track = try XCTUnwrap(leg.flight?.live?.fix?.trackDegrees)
        XCTAssertEqual(try XCTUnwrap(drawing.realPlane?.angle), (track - 90) * .pi / 180, accuracy: 1e-9)
    }

    func test_now_aStretchNobodySaw_isDotted() throws {
        let (drawing, leg, _) = try drawing(of: "behind, with a late first point and an unseen ocean", at: "14T00:13:00")
        let path = try XCTUnwrap(leg.flight?.path)
        var expected: [RouteSegment.Style] = []
        for stretch in path.stretches where stretch.kind != .planned {
            let style: RouteSegment.Style = stretch.kind == .seen ? .seen : .unseen
            if expected.last != style { expected.append(style) }
        }
        XCTAssertEqual(drawing.segments.map(\.style), expected + [.upcoming])
        XCTAssertEqual(drawing.segments.first?.style, .unseen, "it was first seen far from the airport")
        XCTAssertGreaterThanOrEqual(drawing.segments.filter { $0.style == .unseen }.count, 2, "and not at all over the ocean")
    }

    func test_now_estimated_thePlanIsDottedBehindThePlane_whichIsFaded() throws {
        let (drawing, leg, _) = try drawing(of: "ahead, in the air", at: "13T12:45:00")
        XCTAssertEqual(drawing.segments.map(\.style), [.seen, .unseen, .upcoming])
        let path = try XCTUnwrap(leg.flight?.path)
        assertSame(drawing.segments[1].coordinates.first, path.point(atDistance: path.flownLength), "from where it was last seen")
        assertSame(drawing.segments[1].coordinates.last, drawing.realPlane?.coordinate, "to where the plan has it now")
        XCTAssertEqual(drawing.realPlane?.isEstimated, true)
        XCTAssertNotNil(drawing.ghost)
    }

    func test_now_onTheGroundPastThePlansTakeoff_theWholePathIsAhead_andTheGhostHasLeft() throws {
        let (drawing, leg, _) = try drawing(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(drawing.segments.map(\.style), [.upcoming])
        let fix = try XCTUnwrap(leg.flight?.live?.fix)
        assertSame(drawing.realPlane?.coordinate, fix.coordinate)
        XCTAssertEqual(drawing.realPlane?.isEstimated, false)
        let ghost = try XCTUnwrap(drawing.ghost)
        XCTAssertGreaterThan(GreatCircle.distance(from: ghost.coordinate, to: leg.origin.coordinate), 100 * GreatCircle.metersPerNauticalMile)
    }

    func test_now_landedAndNeverSeenInTheAir_theGreatCircleIsDotted_withThePlaneAtTheAirport() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "landed, and never seen in the air")
        let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
        // Two minutes before it reaches the gate.
        let drawing = FlightDrawing(leg: leg, at: leg.end.addingTimeInterval(-120), isReplay: false)
        XCTAssertEqual(drawing.segments.map(\.style), [.unseen])
        assertSame(drawing.realPlane?.coordinate, leg.destination.coordinate)
        XCTAssertNil(drawing.ghost, "a landed flight has no ghost")
    }

    func test_now_onTheGroundSomewhereElse_showsTheRealPlaneWhereItIs_withNoGhost() throws {
        let (drawing, leg, _) = try drawing(of: "on the ground somewhere else", at: "13T13:21:00")
        let fix = try XCTUnwrap(leg.flight?.live?.fix)
        assertSame(drawing.realPlane?.coordinate, fix.coordinate)
        XCTAssertNil(drawing.ghost)
        XCTAssertNil(drawing.plane)
        XCTAssertEqual(drawing.segments.map(\.style), [.upcoming])
    }

    func test_now_aFlightThatIsntLive_drawsTheSchedulesPlane_asBefore() throws {
        for (name, time) in [("waiting to be seen", "13T12:30:00"), ("no live data", "13T12:30:00"),
                             ("on the ground before the plan's takeoff", "13T12:12:00")] {
            let (drawing, leg, moment) = try drawing(of: name, at: time)
            // The schedule's plane taxis for its first 15 minutes, with nothing flown behind it.
            let isTaxiingOut = leg.progress(at: moment.at) == 0
            XCTAssertEqual(drawing.segments.map(\.id), isTaxiingOut ? ["f1-upcoming"] : ["f1-flying", "f1-upcoming"], name)
            XCTAssertEqual(drawing.segments.map(\.style), isTaxiingOut ? [.upcoming] : [.flying, .upcoming], name)
            assertSame(drawing.plane?.coordinate, leg.position(at: moment.at), name)
            XCTAssertNil(drawing.realPlane, name)
            XCTAssertNil(drawing.ghost, name)
        }
    }

    // MARK: - Before and after

    func test_afterItReachesTheGate_isOneGreyLineAlongItsRealPath() throws {
        let (drawing, leg, moment) = try drawing(of: "landed, seen all the way", at: "13T13:30:00")
        XCTAssertGreaterThanOrEqual(moment.at, leg.end)
        XCTAssertEqual(drawing.segments.map(\.id), ["f1-flown"])
        XCTAssertEqual(drawing.segments.map(\.style), [.flown])
        XCTAssertEqual(drawing.segments[0].coordinates.count, try XCTUnwrap(leg.flight?.path.stretches.count) + 1)
        XCTAssertNil(drawing.realPlane)
        XCTAssertNil(drawing.plane)
    }

    func test_beforeItLeavesTheGate_isDashedAlongItsPath_withNoPlane() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "on the ground before the plan's takeoff")
        let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
        // Seen on the ground at the gate, ten minutes before it's due to leave.
        let drawing = FlightDrawing(leg: leg, at: leg.start.addingTimeInterval(-600), isReplay: false)
        XCTAssertEqual(drawing.segments.map(\.id), ["f1-upcoming"])
        XCTAssertEqual(drawing.segments.map(\.style), [.upcoming])
        XCTAssertNil(drawing.realPlane, "the real plane shows from the gate to the gate")
        XCTAssertNil(drawing.ghost)
        XCTAssertNil(drawing.plane)
    }

    // MARK: - The replay

    func test_replay_aFlightWithARecord_fliesIt_alone() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        let record = try XCTUnwrap(leg.flight?.record)
        let path = try XCTUnwrap(leg.flight?.path)
        let earlier = moment.at.addingTimeInterval(-900)

        let drawing = FlightDrawing(leg: leg, at: earlier, isReplay: true)

        assertSame(drawing.realPlane?.coordinate, record.position(at: earlier))
        XCTAssertEqual(drawing.realPlane?.isEstimated, false)
        XCTAssertNil(drawing.ghost, "the ghost is for now only")
        XCTAssertNil(drawing.plane)
        XCTAssertEqual(drawing.segments.map(\.style), [.seen, .upcoming])
        XCTAssertLessThan(drawing.segments[0].coordinates.count, path.knots.count + 1, "only as far as it had flown then")
        assertSame(drawing.segments[0].coordinates.last, drawing.realPlane?.coordinate)
        XCTAssertEqual(try XCTUnwrap(drawing.realPlane?.angle), try XCTUnwrap(path.heading(atDistance: record.distance(at: earlier))), accuracy: 1e-9)
    }

    func test_replay_aheadOfWhereItWasLastSeen_isAnEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "ahead, in the air")
        let moment = try cases.moment("13T12:41:50", of: flightCase)
        let leg = try cases.mapLeg(flightCase, at: moment)
        let later = moment.at.addingTimeInterval(1200)

        let drawing = FlightDrawing(leg: leg, at: later, isReplay: true)

        XCTAssertEqual(drawing.realPlane?.isEstimated, true)
        XCTAssertEqual(drawing.segments.map(\.style), [.seen, .unseen, .upcoming])
        XCTAssertNil(drawing.ghost)
    }

    func test_replay_aLandedFlight_isNeverAnEstimate() throws {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: "landed, seen all the way")
        let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
        for minutes in stride(from: 1.0, to: leg.end.timeIntervalSince(leg.start) / 60, by: 7) {
            let drawing = FlightDrawing(leg: leg, at: leg.start.addingTimeInterval(minutes * 60), isReplay: true)
            XCTAssertEqual(drawing.realPlane?.isEstimated, false, "\(minutes) minutes in")
            XCTAssertFalse(drawing.segments.contains { $0.style == .unseen }, "\(minutes) minutes in")
        }
    }

    func test_replay_aFlightWithNoRecord_drawsTheSchedulesPlane() throws {
        for name in ["no live data", "still on the ground twenty minutes after"] {
            let cases = try TripMapFixtures.liveCases()
            let flightCase = try cases.flight(named: name)
            let leg = try cases.mapLeg(flightCase, at: flightCase.moments[0])
            let drawing = FlightDrawing(leg: leg, at: leg.start.addingTimeInterval(1800), isReplay: true)
            XCTAssertNotNil(drawing.plane, name)
            XCTAssertNil(drawing.realPlane, name)
            XCTAssertEqual(drawing.segments.map(\.style), [.flying, .upcoming], name)
        }
    }

    // MARK: - A leg made by hand

    func test_aLegWithNoFlight_drawsTheSchedulesPlane() {
        let leg = MapLeg(id: "f", kind: .flight,
                         origin: AirportMark(code: "SDF", city: nil, coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                         destination: AirportMark(code: "CGN", city: nil, coordinate: TripMapTestLegs.airports["CGN"]!, timeZone: nil),
                         start: TripMapTestLegs.tripStart, end: TripMapTestLegs.tripStart.addingTimeInterval(8 * 3600), flightNumber: nil)
        let drawing = FlightDrawing(leg: leg, at: TripMapTestLegs.tripStart.addingTimeInterval(4 * 3600), isReplay: false)
        XCTAssertEqual(drawing.segments.map(\.style), [.flying, .upcoming])
        XCTAssertNotNil(drawing.plane)
    }
}
```

Create `CrewluvTests/LiveMarkerTests.swift`:

```swift
//
//  LiveMarkerTests.swift
//  CrewluvTests
//
//  The trip map's markers with a real plane (Stage 3 spec §5.4): the real plane and its ghost, by names that stay
//  the same while each is on the map.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveMarkerTests: XCTestCase {

    /// The map the status screen would make of a shared case's flight at one of its moments: the model's flights,
    /// its legs at their real times, and the map from both.
    private func map(of name: String, at time: String) throws -> (map: TripMap, moment: TripMapFixtures.LiveCases.Flight.Moment) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let after = cases.wait("w2", .layover, at: flightCase.to, from: flightCase.arrival, to: flightCase.arrival.addingTimeInterval(86_400))
        let legs = [cases.tripLeg(flightCase), after]
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: cases.live(flightCase).map { ["f1": $0] } ?? [:],
                                       clockOffset: 0, coordinate: cases.coordinateOrNil)
        let replaced = LiveLegs.replacingTimes(in: legs, with: flights, at: moment.at)
        let map = try XCTUnwrap(TripMap.make(tripLegs: replaced, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                                             flights: flights, at: moment.at, coordinate: cases.coordinateOrNil))
        return (map, moment)
    }

    func test_placements_withARealPlane_areItAndItsGhost_andNoSchedulesPlane() throws {
        let (map, moment) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let drawing = TripMapDrawing(tripMap: map, at: moment.at)
        let placements = TripMapMarker.placements(for: drawing, palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-PHL", "real-plane", "ghost"])
        let realPlane = try XCTUnwrap(drawing.realPlane)
        let ghost = try XCTUnwrap(drawing.ghost)
        XCTAssertEqual(placements["real-plane"]?.marker, .realPlane(angle: realPlane.angle, isEstimated: false))
        XCTAssertEqual(placements["ghost"]?.marker, .ghost(angle: ghost.angle))
        let plane = try XCTUnwrap(moment.plane)
        XCTAssertEqual(placements["real-plane"]?.coordinate.latitude ?? 0, plane[0], accuracy: 0.0001)
        XCTAssertEqual(placements["real-plane"]?.coordinate.longitude ?? 0, plane[1], accuracy: 0.0001)
        XCTAssertNil(drawing.pilot, "the plane shows where they are")
    }

    func test_placements_anEstimatedPlane_isMarkedAsOne() throws {
        let (map, moment) = try map(of: "ahead, in the air", at: "13T12:45:00")
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: moment.at), palette: .onDarkMap)
        guard case .realPlane(_, isEstimated: true)? = placements["real-plane"]?.marker else {
            return XCTFail("the plane hasn't been seen for over two minutes")
        }
    }

    func test_placements_inAReplay_areTheRealPlaneAlone() throws {
        let (map, moment) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let earlier = moment.at.addingTimeInterval(-600)
        let placements = TripMapMarker.placements(for: TripMapDrawing(tripMap: map, at: earlier, isReplay: true), palette: .onDarkMap)
        XCTAssertEqual(Set(placements.keys), ["airport-SDF", "airport-PHL", "real-plane"])
    }

    func test_markers_thePlanesAreOneSize() {
        XCTAssertEqual(TripMapMarker.realPlane(angle: 1, isEstimated: false).sizeKey, TripMapMarker.plane(angle: 0).sizeKey)
        XCTAssertEqual(TripMapMarker.ghost(angle: 1).sizeKey, TripMapMarker.plane(angle: 0).sizeKey)
    }
}
```

- [ ] **Step 2: Write `FlightDrawing`.**

Create `Crewluv/Services/TripMap/FlightDrawing.swift`:

```swift
//
//  FlightDrawing.swift
//  CrewLuve
//
//  What one flight draws at a moment (moving map spec §7.1, §7.2; Stage 3 spec §5.1, §6.2, §7.3): its lines and
//  its planes. A flight with a real plane draws its real path, solid where the plane was seen and dotted where it
//  wasn't, with the real plane on it and the schedule's ghost beside it. Any other flight draws the great circle
//  and the schedule's plane, as before.
//

import CoreLocation

nonisolated struct FlightDrawing {
    let segments: [RouteSegment]
    /// The schedule's plane, alone: the flight has no real plane at this moment.
    let plane: PlaneMark?
    let realPlane: RealPlaneMark?
    /// Where an on-schedule plane would be, beside the real one. Now only: a replay has none.
    let ghost: PlaneMark?

    /// - Parameters:
    ///   - date: the moment, by this device's clock.
    ///   - isReplay: `date` is a moment of the replay, not now. The real plane then flies its record, alone.
    init(leg: MapLeg, at date: Date, isReplay: Bool) {
        let path = leg.flight?.path
        let wholePath = path?.coordinates ?? [leg.origin.coordinate, leg.destination.coordinate]
        if date >= leg.end {
            segments = [RouteSegment(id: "\(leg.id)-flown", coordinates: wholePath, style: .flown)]
            (plane, realPlane, ghost) = (nil, nil, nil)
        } else if !leg.isMoving(at: date) {
            segments = [RouteSegment(id: "\(leg.id)-upcoming", coordinates: wholePath, style: .upcoming)]
            (plane, realPlane, ghost) = (nil, nil, nil)
        } else if let path, let sighting = leg.flight.flatMap({ Self.sighting(of: $0, at: date, isReplay: isReplay) }) {
            segments = Self.segments(of: leg.id, along: path, flownTo: sighting.distance)
            (plane, realPlane, ghost) = (nil, sighting.plane, sighting.ghost)
        } else {
            // The schedule's plane on the great circle, as before Stage 3.
            let fraction = leg.progress(at: date)
            let here = leg.position(atFraction: fraction)
            var segments: [RouteSegment] = []
            if fraction > 0 {
                segments.append(RouteSegment(id: "\(leg.id)-flying", coordinates: [leg.origin.coordinate, here], style: .flying))
            }
            if fraction < 1 {
                segments.append(RouteSegment(id: "\(leg.id)-upcoming", coordinates: [here, leg.destination.coordinate], style: .upcoming))
            }
            self.segments = segments
            (plane, realPlane, ghost) = (PlaneMark(coordinate: here, angle: leg.heading(at: date) ?? 0), nil, nil)
        }
    }

    // MARK: - Private

    /// The real plane of a flight between its gates.
    private struct Sighting {
        /// How far along the path the lines turn from flown to still to come.
        let distance: Double
        let plane: RealPlaneMark
        let ghost: PlaneMark?
    }

    /// The real plane at `date`, or nil when the schedule's plane shows instead: the flight isn't live now, or has
    /// no record to replay.
    private static func sighting(of flight: MapFlight, at date: Date, isReplay: Bool) -> Sighting? {
        let path = flight.path
        if isReplay {
            guard let record = flight.record else { return nil }
            let distance = record.distance(at: date)
            // Past the last place it was seen, the record flies the plan: an estimate, drawn as one.
            let isEstimated = !path.hasLanded && distance > path.flownLength
            let plane = RealPlaneMark(coordinate: path.point(atDistance: distance),
                                      angle: path.heading(atDistance: distance) ?? 0, isEstimated: isEstimated)
            return Sighting(distance: distance, plane: plane, ghost: nil)
        }
        let progress = flight.progress(at: date)
        guard let place = progress.plane else { return nil }
        // A plane on the ground somewhere else isn't on the path: the lines stay as it was last seen flying them.
        let distance = progress.planeDistance ?? path.flownLength
        // In the air the plane points the way it's really going, and otherwise along its path.
        let track = progress.phase == .inAir ? flight.live?.fix?.trackDegrees : nil
        let angle = track.map { ($0 - 90) * .pi / 180 } ?? path.heading(atDistance: distance) ?? 0
        let ghost = progress.ghostDistance.map {
            PlaneMark(coordinate: path.point(atDistance: $0), angle: path.heading(atDistance: $0) ?? 0)
        }
        let plane = RealPlaneMark(coordinate: place, angle: angle, isEstimated: progress.phase == .estimated)
        return Sighting(distance: distance, plane: plane, ghost: ghost)
    }

    /// The path's lines with the plane `distance` meters along it (spec §6.2). Behind the plane the path is flown:
    /// solid where the plane was seen, and dotted where nobody saw it, which is also the plan's line behind a plane
    /// that's only estimated to have flown it. Ahead of the plane it's still to come.
    private static func segments(of legID: String, along path: FlightPath, flownTo distance: Double) -> [RouteSegment] {
        var segments: [RouteSegment] = []
        for run in path.runs(from: 0, to: distance) {
            let style: RouteSegment.Style = run.kind == .seen ? .seen : .unseen
            if let last = segments.last, last.style == style {
                // Two runs drawn the same way are one line, so its dots don't start again where they meet.
                segments[segments.count - 1] = RouteSegment(id: last.id, coordinates: last.coordinates + run.coordinates.dropFirst(),
                                                            style: style)
            } else {
                segments.append(RouteSegment(id: "\(legID)-\(style == .seen ? "seen" : "unseen")-\(segments.count)",
                                             coordinates: run.coordinates, style: style))
            }
        }
        let ahead = path.coordinates(from: distance, to: path.length)
        if !ahead.isEmpty {
            segments.append(RouteSegment(id: "\(legID)-upcoming", coordinates: ahead, style: .upcoming))
        }
        return segments
    }
}
```

- [ ] **Step 3: Have `TripMapDrawing` use it.** The flight's three cases become one. The lines of a flight with no live data keep their names and styles, so `TripMapDrawingTests` passes unchanged.

In `Crewluv/Services/TripMap/TripMapDrawing.swift`:

Replace:

```swift
//  Everything the trip map draws at one instant (moving map spec §7.1, §7.2), worked out here so `TripMapView`
//  only renders it.
//
```

with:

```swift
//  Everything the trip map draws at one instant (moving map spec §7.1, §7.2), worked out here so `TripMapView`
//  only renders it. Each flight's lines and planes are `FlightDrawing`'s.
//
```

Replace:

```swift
        /// A leg already flown: grey.
        case flown
        /// A drive: dotted.
        case drive
    }
```

with:

```swift
        /// A leg already flown: grey.
        case flown
        /// A drive: dotted.
        case drive
        /// The real path flown, where the plane was seen: solid (Stage 3 spec §6.2).
        case seen
        /// The real path flown, where nobody saw the plane, and the plan's line behind an estimated plane: dotted.
        case unseen
    }
```

Replace:

```swift
/// The schedule's plane and the way it points (`PlaneHeading`'s angle).
nonisolated struct PlaneMark {
    let coordinate: CLLocationCoordinate2D
    let angle: Double
}
```

with:

```swift
/// The schedule's plane and the way it points (`PlaneHeading`'s angle).
nonisolated struct PlaneMark {
    let coordinate: CLLocationCoordinate2D
    let angle: Double
}

/// The real plane and the way it points (Stage 3 spec §5.4).
nonisolated struct RealPlaneMark {
    let coordinate: CLLocationCoordinate2D
    let angle: Double
    /// It hasn't been seen for a while, or the moment is ahead of where it was last seen: it's drawn faded, where
    /// the plan has it.
    let isEstimated: Bool
}
```

Replace:

```swift
    let plane: PlaneMark?
    /// What the pilot is doing on the ground
```

with:

```swift
    /// The schedule's plane, alone: the flight in the air has no real plane at this moment.
    let plane: PlaneMark?
    /// The real plane (Stage 3 spec §5.1).
    let realPlane: RealPlaneMark?
    /// Where an on-schedule plane would be, beside the real one (Stage 3 spec §5.4).
    let ghost: PlaneMark?
    /// What the pilot is doing on the ground
```

Replace:

```swift
    init(tripMap: TripMap, at date: Date) {
        var segments: [RouteSegment] = []
        var cars: [TripMapPoint] = []
        var plane: PlaneMark?
        for leg in tripMap.legs {
```

with:

```swift
    /// - Parameter isReplay: `date` is a moment of the replay, not now: a flight with a record shows its real plane
    ///   alone, where the record has it (Stage 3 spec §7.3).
    init(tripMap: TripMap, at date: Date, isReplay: Bool = false) {
        var segments: [RouteSegment] = []
        var cars: [TripMapPoint] = []
        var plane: PlaneMark?
        var realPlane: RealPlaneMark?
        var ghost: PlaneMark?
        for leg in tripMap.legs {
```

Replace:

```swift
            case .flight where date >= leg.end:
                segments.append(RouteSegment(id: "\(leg.id)-flown", coordinates: [origin, destination], style: .flown))
            case .flight where leg.isMoving(at: date):
                let fraction = leg.progress(at: date)
                let here = leg.position(atFraction: fraction)
                if fraction > 0 {
                    segments.append(RouteSegment(id: "\(leg.id)-flying", coordinates: [origin, here], style: .flying))
                }
                if fraction < 1 {
                    segments.append(RouteSegment(id: "\(leg.id)-upcoming", coordinates: [here, destination], style: .upcoming))
                }
                plane = PlaneMark(coordinate: here, angle: leg.heading(at: date) ?? 0)
            case .flight:
                segments.append(RouteSegment(id: "\(leg.id)-upcoming", coordinates: [origin, destination], style: .upcoming))
            }
```

with:

```swift
            case .flight:
                let flight = FlightDrawing(leg: leg, at: date, isReplay: isReplay)
                segments += flight.segments
                plane = flight.plane ?? plane
                realPlane = flight.realPlane ?? realPlane
                ghost = flight.ghost ?? ghost
            }
```

Replace:

```swift
        self.plane = plane
        self.pilot =
```

with:

```swift
        self.plane = plane
        self.realPlane = realPlane
        self.ghost = ghost
        self.pilot =
```

- [ ] **Step 4: Give the new lines their colours and strokes.**

In `Crewluv/Views/TripMap/TripMapPalette.swift`:

Replace:

```swift
    let drive: Color
    /// An airport's code
```

with:

```swift
    let drive: Color
    /// The real path flown (Stage 3 spec §6.2): where the plane was seen, and where it wasn't.
    let seen: Color
    let unseen: Color
    /// An airport's code
```

Replace:

```swift
        drive: .white,
        label: .white,
```

with:

```swift
        drive: .white,
        seen: .white,
        unseen: .white,
        label: .white,
```

Replace:

```swift
        drive: .gray,
        label: Color(white: 0.12),
```

with:

```swift
        drive: .gray,
        seen: .blue,
        unseen: .blue,
        label: Color(white: 0.12),
```

Replace:

```swift
        case .drive: drive
        }
    }
```

with:

```swift
        case .drive: drive
        case .seen: seen
        case .unseen: unseen
        }
    }
```

Replace:

```swift
        case .drive: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6])
        }
```

with:

```swift
        case .drive: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6])
        case .seen: StrokeStyle(lineWidth: 3, lineCap: .round)
        case .unseen: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6])
        }
```

- [ ] **Step 5: Give the planes their markers.**

In `Crewluv/Views/TripMap/TripMapMarker.swift`:

Replace:

```swift
    /// The schedule's plane, pointing at `angle` (`PlaneHeading`).
    case plane(angle: Double)
```

with:

```swift
    /// The schedule's plane, alone, pointing at `angle` (`PlaneHeading`).
    case plane(angle: Double)
    /// The real plane (Stage 3 spec §5.4), faded while it's an estimate of where the plane is.
    case realPlane(angle: Double, isEstimated: Bool)
    /// Where an on-schedule plane would be, beside the real one.
    case ghost(angle: Double)
```

Replace:

```swift
        case .pilot: "pilot"
        case .plane: "plane"
        }
```

with:

```swift
        case .pilot: "pilot"
        case .plane, .realPlane, .ghost: "plane"
        }
```

Replace:

```swift
    /// Every marker `drawing` shows, by name: each airport by its code, each car by its drive's own id, and the
    /// pilot's marker and the plane by themselves. The pilot's marker keeps its name as its kind changes.
```

with:

```swift
    /// Every marker `drawing` shows, by name: each airport by its code, each car by its drive's own id, and the
    /// pilot's marker and each of the planes by themselves. The pilot's marker keeps its name as its kind changes.
```

Replace:

```swift
            placements["plane"] = Placement(coordinate: plane.coordinate, marker: .plane(angle: plane.angle))
        }
```

with:

```swift
            placements["plane"] = Placement(coordinate: plane.coordinate, marker: .plane(angle: plane.angle))
        }
        if let ghost = drawing.ghost {
            placements["ghost"] = Placement(coordinate: ghost.coordinate, marker: .ghost(angle: ghost.angle))
        }
        if let realPlane = drawing.realPlane {
            placements["real-plane"] = Placement(coordinate: realPlane.coordinate,
                                                 marker: .realPlane(angle: realPlane.angle, isEstimated: realPlane.isEstimated))
        }
```

- [ ] **Step 6: Draw them.** The real plane is filled blue with a white border, at 60% while it's an estimate. The ghost is a dashed white outline with a faint plane. The real plane goes on top, the ghost just under it. The seen line is drawn above every other line.

In `Crewluv/Views/TripMap/TripMapMarkerView.swift`:

Replace:

```swift
        case .plane(let angle):
            PlaneMarker(angle: angle)
        }
```

with:

```swift
        case .plane(let angle):
            PlaneMarker(angle: angle)
        case .realPlane(let angle, let isEstimated):
            PlaneMarker(angle: angle, look: .real(isEstimated: isEstimated))
        case .ghost(let angle):
            PlaneMarker(angle: angle, look: .ghost)
        }
```

In `Crewluv/Views/TripMap/PlaneMarker.swift`:

Replace:

```swift
//  The schedule's plane (moving map spec §7.2): a white outline circle, turning the short way round between legs.
//  Stage 3 adds the filled live plane beside it.
//
```

with:

```swift
//  The trip map's planes (moving map spec §7.2, Stage 3 spec §5.4), each turning the short way round as its angle
//  changes: the schedule's plane alone, a white outline; the real plane, filled blue, and faded while it's an
//  estimate; and the ghost beside it, a dashed outline where an on-schedule plane would be.
//
```

Replace:

```swift
struct PlaneMarker: View {
    /// `PlaneHeading`'s angle: 0 points east, positive turns clockwise.
    let angle: Double
```

with:

```swift
struct PlaneMarker: View {

    enum Look: Equatable {
        /// The schedule's plane, alone.
        case schedule
        /// The real plane. `isEstimated` once it hasn't been seen for a while.
        case real(isEstimated: Bool)
        /// Where an on-schedule plane would be, beside the real one.
        case ghost
    }

    /// `PlaneHeading`'s angle: 0 points east, positive turns clockwise.
    let angle: Double
    var look: Look = .schedule
```

Replace:

```swift
            .foregroundStyle(.white)
            .rotationEffect(.radians(shownAngle ?? angle))
            .frame(width: 26, height: 26)
            .background(Circle().fill(.black.opacity(0.35)))
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .animation(
```

with:

```swift
            .foregroundStyle(.white.opacity(look == .ghost ? 0.6 : 1))
            .rotationEffect(.radians(shownAngle ?? angle))
            .frame(width: 26, height: 26)
            .background(Circle().fill(fill))
            .overlay(Circle().stroke(.white, style: outline))
            .opacity(look == .real(isEstimated: true) ? 0.6 : 1)
            .animation(
```

Replace:

```swift
            .accessibilityHidden(true)
    }
}
```

with:

```swift
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch look {
        case .schedule: .black.opacity(0.35)
        case .real: .blue
        case .ghost: .black.opacity(0.15)
        }
    }

    private var outline: StrokeStyle {
        look == .ghost ? StrokeStyle(lineWidth: 1.5, dash: [3, 3]) : StrokeStyle(lineWidth: 1.5)
    }
}
```

In `Crewluv/Views/TripMap/TripMapAnnotationView.swift`:

Replace:

```swift
        case .car, .plane: .zero
        }
```

with:

```swift
        case .car, .plane, .realPlane, .ghost: .zero
        }
```

Replace:

```swift
    /// The plane on top, then the pilot's marker, the cars and the airports.
    private static func zPriority(of marker: TripMapMarker) -> MKAnnotationViewZPriority {
        switch marker {
        case .plane: .max
        case .pilot:
```

with:

```swift
    /// The plane on top, real or the schedule's, then the ghost beside the real one, the pilot's marker, the cars
    /// and the airports.
    private static func zPriority(of marker: TripMapMarker) -> MKAnnotationViewZPriority {
        switch marker {
        case .plane, .realPlane: .max
        case .ghost: MKAnnotationViewZPriority(rawValue: 950)
        case .pilot:
```

In `Crewluv/Views/TripMap/TripMapShapesView.swift`:

Replace:

```swift
    /// How the lines stack, bottom first: the line being flown on top.
    private static let lineOrder: [RouteSegment.Style] = [.flown, .drive, .upcoming, .flying]
```

with:

```swift
    /// How the lines stack, bottom first: the line being flown on top.
    private static let lineOrder: [RouteSegment.Style] = [.flown, .drive, .upcoming, .unseen, .flying, .seen]
```

- [ ] **Step 7: Checkpoint.** `FlightDrawingTests` has 16 tests and `LiveMarkerTests` 4. Todd runs them with batch B, after Task 7.

- [ ] **Step 8: Ask to commit.** Suggested message: `feat(crewluv): FlightDrawing draws a flight by what the live data says: the real path, solid where the plane was seen and dotted where it wasn't, the real plane and the schedule's ghost, and in a replay the real plane alone (Stage 3 spec §5.1, §5.4, §6.2, §7.3)`.

---

### Task 7: The words

Spec §9. The label goes on the card's bar and the full-screen pill, through `TripMapWording.liveLabel`, which the engine already has. A landing time that's the real plane's estimate gains "about" wherever `TripMapWording` or `FactsWording` writes it. The landing countdown needs no change: it counts to the leg's end, which is already the live arrival.

**Files:**
- Create: `CrewluvTests/LiveWordingTests.swift`
- Modify: `Crewluv/Services/TripMap/TripMapWording.swift`
- Modify: `Crewluv/Services/TripMap/Facts/TripFacts.swift`
- Modify: `Crewluv/Services/TripMap/Facts/FactsWording.swift`

- [ ] **Step 1: Write the tests.**

Create `CrewluvTests/LiveWordingTests.swift`:

```swift
//
//  LiveWordingTests.swift
//  CrewluvTests
//
//  The trip map's words for a flight with a real plane (Stage 3 spec §9, §15), in US English for a family in
//  Louisville, on the shared cases' flights.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveWordingTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    /// iOS writes a narrow no-break space before AM and PM; the tests read it as a plain space.
    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// A shared case's flight at one of its moments, as a leg of the map between named airports.
    private func leg(of name: String, at time: String) throws -> (leg: MapLeg, at: Date) {
        let cases = try TripMapFixtures.liveCases()
        let flightCase = try cases.flight(named: name)
        let moment = try cases.moment(time, of: flightCase)
        let cities = ["SDF": ("Louisville", "America/New_York"), "PHL": ("Philadelphia", "America/New_York"), "CGN": ("Cologne", "Europe/Berlin")]
        func mark(_ code: String) throws -> AirportMark {
            AirportMark(code: code, city: cities[code]?.0, coordinate: try cases.coordinate(of: code),
                        timeZone: cities[code].flatMap { TimeZone(identifier: $0.1) })
        }
        let leg = MapLeg(id: "f1", kind: .flight, origin: try mark(flightCase.from), destination: try mark(flightCase.to),
                         start: moment.start, end: moment.end, flightNumber: "UPS207", flight: try cases.mapFlight(flightCase))
        return (leg, moment.at)
    }

    /// The map of that one flight.
    private func map(of name: String, at time: String) throws -> (map: TripMap, at: Date) {
        let (leg, at) = try leg(of: name, at: time)
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: leg.origin,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return (map, at)
    }

    // MARK: - The card's bar and the pill

    func test_flightStatus_isTheRealPlanesLabel() throws {
        func status(_ name: String, _ time: String) throws -> String {
            let (leg, at) = try leg(of: name, at: time)
            return TripMapWording.flightStatus(for: leg, at: at)
        }
        XCTAssertEqual(try status("ahead, in the air", "13T12:41:50"), "13 min ahead")
        XCTAssertEqual(try status("ahead, in the air", "13T12:45:00"), "About 13 min ahead")
        XCTAssertEqual(try status("off early and the long way round", "13T12:15:20"), "On schedule")
        XCTAssertEqual(try status("behind, with a late first point and an unseen ocean", "14T00:13:00"), "48 min behind")
        XCTAssertEqual(try status("still on the ground just after the plan's takeoff", "13T12:18:00"), "Still on the ground")
        XCTAssertEqual(try status("still on the ground twenty minutes after", "13T12:35:00"), "Still on the ground · 20 min behind")
    }

    func test_flightStatus_withNoLabel_isInFlight_asBefore() throws {
        for (name, time) in [("no live data", "13T12:30:00"), ("waiting to be seen", "13T12:30:00"),
                             ("on the ground somewhere else", "13T13:21:00"), ("on the ground before the plan's takeoff", "13T12:10:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at), "In flight", name)
        }
    }

    func test_flightStatus_inAReplay_isInFlight() throws {
        let (leg, at) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.flightStatus(for: leg, at: at, isReplay: true), "In flight")
    }

    func test_topPill_withARealPlane_saysHowItsDoing_andInAReplayInFlight() throws {
        let (map, at) = try map(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(TripMapWording.topPill(for: map, at: at, dayNumber: 1, totalDays: 4), "UPS207 · 13 min ahead")
        XCTAssertEqual(TripMapWording.topPill(for: map, at: at, dayNumber: 1, totalDays: 4, isReplay: true), "UPS207 · In flight")
    }

    func test_topPill_withNoLiveData_isInFlight_asBefore() throws {
        let (map, at) = try map(of: "no live data", at: "13T12:30:00")
        XCTAssertEqual(TripMapWording.topPill(for: map, at: at, dayNumber: 1, totalDays: 4), "UPS207 · In flight")
    }

    // MARK: - "About"

    func test_landsAt_theRealPlanesEstimate_saysAbout() throws {
        let (ahead, _) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: ahead, calendar: calendar, locale: locale)), "Lands about 8:32 AM")
        let (late, _) = try leg(of: "still on the ground twenty minutes after", at: "13T12:35:00")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: late, calendar: calendar, locale: locale)), "Lands about 9:05 AM")
    }

    func test_landsAt_theSchedulesTime_andALandedFlights_haveNoAbout() throws {
        let (scheduled, _) = try leg(of: "no live data", at: "13T12:30:00")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: scheduled, calendar: calendar, locale: locale)), "Lands 8:45 AM")
        let (early, _) = try leg(of: "on the ground before the plan's takeoff", at: "13T12:10:00")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: early, calendar: calendar, locale: locale)), "Lands 8:45 AM")
        let (landed, _) = try leg(of: "landed, seen all the way", at: "13T13:30:00")
        XCTAssertEqual(plain(TripMapWording.landsAt(for: landed, calendar: calendar, locale: locale)), "Lands 8:21 AM")
    }

    func test_landingLine_theRealPlanesEstimate_saysAboutOnce() throws {
        let (toCologne, _) = try leg(of: "behind, with a late first point and an unseen ocean", at: "14T00:13:00")
        XCTAssertEqual(plain(TripMapWording.landingLine(for: toCologne, calendar: calendar, locale: locale)),
                       "Lands Cologne about 3:47 AM · 9:47 PM your time")
        let (toPhiladelphia, _) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(plain(TripMapWording.landingLine(for: toPhiladelphia, calendar: calendar, locale: locale)),
                       "Lands Philadelphia about 8:32 AM")
    }

    func test_factsLands_theRealPlanesEstimate_saysAbout() throws {
        let (toCologne, _) = try leg(of: "behind, with a late first point and an unseen ocean", at: "14T00:13:00")
        XCTAssertEqual(plain(FactsWording.lands(toCologne, calendar: calendar, locale: locale)), "lands about 3:47 AM there")
        let (toPhiladelphia, _) = try leg(of: "ahead, in the air", at: "13T12:41:50")
        XCTAssertEqual(plain(FactsWording.lands(toPhiladelphia, calendar: calendar, locale: locale)), "lands about 8:32 AM")
    }

    func test_landingCountdown_countsToTheRealPlanesArrival() throws {
        let (map, at) = try map(of: "ahead, in the air", at: "13T12:41:50")
        // The schedule says 64 minutes. The real plane reaches the gate in 50 and a bit.
        XCTAssertEqual(TripMapWording.cardChips(for: map, at: at, calendar: calendar, locale: locale).bottom, "Landing in 51 min")
    }

    // MARK: - VoiceOver

    func test_spokenLiveLabel_saysEachLabelInFull() {
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.onSchedule), "on schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.ahead(minutes: 12, isEstimated: false)), "12 minutes ahead of schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.ahead(minutes: 12, isEstimated: true)), "about 12 minutes ahead of schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.behind(minutes: 75, isEstimated: false)), "1 hour 15 minutes behind schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.behind(minutes: 20, isEstimated: true)), "about 20 minutes behind schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.stillOnGround(minutesBehind: nil)), "still on the ground")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.stillOnGround(minutesBehind: 20)), "still on the ground, 20 minutes behind schedule")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.landedOnTime), "landed on time")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.landedEarly(minutes: 8)), "landed 8 minutes early")
        XCTAssertEqual(TripMapWording.spokenLiveLabel(.landedLate(minutes: 15)), "landed 15 minutes late")
    }

    func test_spokenMinutes_countsHoursAndMinutes() {
        XCTAssertEqual(TripMapWording.spokenMinutes(1), "1 minute")
        XCTAssertEqual(TripMapWording.spokenMinutes(45), "45 minutes")
        XCTAssertEqual(TripMapWording.spokenMinutes(60), "1 hour")
        XCTAssertEqual(TripMapWording.spokenMinutes(61), "1 hour 1 minute")
        XCTAssertEqual(TripMapWording.spokenMinutes(130), "2 hours 10 minutes")
    }

    func test_liveSummary_saysHowThePlaneIsDoing_andWhatsBelow() throws {
        let (leg, at) = try leg(of: "behind, with a late first point and an unseen ocean", at: "14T00:13:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: leg, over: "Québec", now: at, calendar: calendar, locale: locale))),
                       "UPS207 to Cologne, 48 minutes behind schedule, over Québec. Lands about 9:47 PM your time.")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale))),
                       "UPS207 to Cologne, 48 minutes behind schedule. Lands about 9:47 PM your time.")
    }

    func test_liveSummary_whileEstimated_saysAbout() throws {
        let (leg, at) = try leg(of: "ahead, in the air", at: "13T12:45:00")
        XCTAssertEqual(plain(try XCTUnwrap(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale))),
                       "UPS207 to Philadelphia, about 13 minutes ahead of schedule. Lands about 8:32 AM your time.")
    }

    func test_liveSummary_withNoLabel_isNil() throws {
        for (name, time) in [("no live data", "13T12:30:00"), ("on the ground somewhere else", "13T13:21:00")] {
            let (leg, at) = try leg(of: name, at: time)
            XCTAssertNil(TripMapWording.liveSummary(for: leg, now: at, calendar: calendar, locale: locale), name)
        }
    }

    func test_cardSummary_withARealPlane_isTheLiveSentence() throws {
        let (map, at) = try map(of: "ahead, in the air", at: "13T12:41:50")
        let expected = "UPS207 to Philadelphia, 13 minutes ahead of schedule. Lands about 8:32 AM your time."
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map, now: at, pilotName: "Alex", calendar: calendar, locale: locale)), expected)
        var facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [:])
        facts.calendar = calendar
        facts.locale = locale
        XCTAssertEqual(plain(facts.cardSummary(now: at, pilotName: "Alex")), expected)
    }

    func test_cardSummary_withNoLiveData_isTheSchedulesSentence_asBefore() throws {
        let (map, at) = try map(of: "no live data", at: "13T12:30:00")
        XCTAssertEqual(plain(TripMapWording.cardSummary(for: map, now: at, pilotName: "Alex", calendar: calendar, locale: locale)),
                       "UPS207 to Philadelphia, landing at 8:45 AM your time. Estimated from the schedule.")
        var facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [:])
        facts.calendar = calendar
        facts.locale = locale
        XCTAssertEqual(plain(facts.cardSummary(now: at, pilotName: "Alex")),
                       "UPS207 to Philadelphia. Lands at 8:45 AM your time. Estimated from the schedule.")
    }
}
```

- [ ] **Step 2: Add the words.**

In `Crewluv/Services/TripMap/TripMapWording.swift`:

Replace:

```swift
//  Every sentence the trip map shows or speaks (moving map spec §5, §6, §14). Times are the family's own, in
//  `calendar.timeZone`, unless the words say "there".
//
```

with:

```swift
//  Every sentence the trip map shows or speaks (moving map spec §5, §6, §14; Stage 3 spec §9). Times are the
//  family's own, in `calendar.timeZone`, unless the words say "there". A landing time that's the real plane's
//  estimate is marked "about".
//
```

Replace:

```swift
    /// "Lands Cologne 9:30 PM · 3:30 PM your time", or one time when the destination keeps the family's.
    static func landingLine(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let yours = clockTime(leg.end, in: calendar.timeZone, locale: locale)
        guard let there = arrivalLocalClock(for: leg, calendar: calendar, locale: locale) else {
            return "Lands \(leg.destination.name) \(yours)"
        }
        return "Lands \(leg.destination.name) \(there) · \(yours) your time"
    }

    /// "Lands 3:30 PM", for the card's bar.
    static func landsAt(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Lands \(clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }
```

with:

```swift
    /// "Lands Cologne 9:30 PM · 3:30 PM your time", or one time when the destination keeps the family's. With the
    /// real plane's estimate, "Lands Cologne about 9:18 PM · 3:18 PM your time".
    static func landingLine(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let yours = clockTime(leg.end, in: calendar.timeZone, locale: locale)
        guard let there = arrivalLocalClock(for: leg, calendar: calendar, locale: locale) else {
            return "Lands \(leg.destination.name) \(about(leg))\(yours)"
        }
        return "Lands \(leg.destination.name) \(about(leg))\(there) · \(yours) your time"
    }

    /// "Lands 3:30 PM", for the card's bar. With the real plane's estimate, "Lands about 3:18 PM".
    static func landsAt(for leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Lands \(about(leg))\(clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }
```

Replace:

```swift
    // MARK: - The real plane

    /// "12 min ahead"
```

with:

```swift
    // MARK: - The real plane

    /// What the card's bar and the full-screen pill say of a flight between its gates (Stage 3 spec §9): the real
    /// plane's label, or "In flight" when it has none. A moment of the replay is always "In flight" (§7.3).
    /// - Parameter now: the moment, by this device's clock.
    static func flightStatus(for leg: MapLeg, at now: Date, isReplay: Bool = false) -> String {
        guard !isReplay, let label = leg.flight?.progress(at: now).label else { return "In flight" }
        return liveLabel(label)
    }

    /// "12 min ahead"
```

Replace:

```swift
        case .landedLate(let minutes):
            return "Landed \(minutesText(minutes)) late"
        }
    }
```

with:

```swift
        case .landedLate(let minutes):
            return "Landed \(minutesText(minutes)) late"
        }
    }

    /// The label as VoiceOver says it in the card's sentence: "12 minutes ahead of schedule", "about 20 minutes
    /// behind schedule", "still on the ground" or "landed 8 minutes early".
    static func spokenLiveLabel(_ label: LiveLabel) -> String {
        switch label {
        case .onSchedule:
            return "on schedule"
        case .ahead(let minutes, let isEstimated):
            return "\(isEstimated ? "about " : "")\(spokenMinutes(minutes)) ahead of schedule"
        case .behind(let minutes, let isEstimated):
            return "\(isEstimated ? "about " : "")\(spokenMinutes(minutes)) behind schedule"
        case .stillOnGround(let minutesBehind):
            return minutesBehind.map { "still on the ground, \(spokenMinutes($0)) behind schedule" } ?? "still on the ground"
        case .landedOnTime:
            return "landed on time"
        case .landedEarly(let minutes):
            return "landed \(spokenMinutes(minutes)) early"
        case .landedLate(let minutes):
            return "landed \(spokenMinutes(minutes)) late"
        }
    }

    /// The card's sentence for a flight with a real plane (Stage 3 spec §9, §15): "UPS207 to Cologne, 12 minutes
    /// ahead of schedule, over Québec. Lands about 3:18 PM your time." Nil when the plane has no label, and the
    /// schedule's sentence stands.
    /// - Parameter place: what's below the plane, when the facts know.
    static func liveSummary(for leg: MapLeg, over place: String? = nil, now: Date,
                            calendar: Calendar = .current, locale: Locale = .current) -> String? {
        guard let label = leg.flight?.progress(at: now).label else { return nil }
        let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
        let over = place.map { ", over \($0)" } ?? ""
        let landing = clockTime(leg.end, in: calendar.timeZone, locale: locale)
        return "\(lead) \(leg.destination.name), \(spokenLiveLabel(label))\(over). Lands \(leg.isArrivalEstimated ? "about" : "at") \(landing) your time."
    }
```

Replace:

```swift
    /// The pill at the top: "UPS207 · In flight", "Driving to Louisville", "Day 2 of 4" or "Next trip".
    static func topPill(for tripMap: TripMap, at date: Date, dayNumber: Int?, totalDays: Int?) -> String {
        if tripMap.mode == .recap, date >= tripMap.span.end { return "Trip recap" }
        if let leg = tripMap.legInMotion(at: date) {
            switch leg.kind {
            case .flight: return [leg.flightNumber, "In flight"].compactMap { $0 }.joined(separator: " · ")
```

with:

```swift
    /// The pill at the top: "UPS207 · In flight", "UPS207 · 12 min ahead" with a real plane, "Driving to
    /// Louisville", "Day 2 of 4" or "Next trip".
    /// - Parameter isReplay: `date` is a moment of the replay, not now: a flight is "In flight" (Stage 3 spec §7.3).
    static func topPill(for tripMap: TripMap, at date: Date, dayNumber: Int?, totalDays: Int?, isReplay: Bool = false) -> String {
        if tripMap.mode == .recap, date >= tripMap.span.end { return "Trip recap" }
        if let leg = tripMap.legInMotion(at: date) {
            switch leg.kind {
            case .flight:
                return [leg.flightNumber, flightStatus(for: leg, at: date, isReplay: isReplay)].compactMap { $0 }.joined(separator: " · ")
```

Replace:

```swift
            guard let leg = tripMap.currentLeg else { return "Trip map" }
            let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
```

with:

```swift
            guard let leg = tripMap.currentLeg else { return "Trip map" }
            if let live = liveSummary(for: leg, now: now, calendar: calendar, locale: locale) { return live }
            let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
```

Replace:

```swift
        if rest == 0 { return "\(hours) h" }
        return "\(hours) h \(rest) min"
    }
```

with:

```swift
        if rest == 0 { return "\(hours) h" }
        return "\(hours) h \(rest) min"
    }

    /// "1 minute", "45 minutes", "2 hours" or "2 hours 10 minutes": a length as VoiceOver says it.
    static func spokenMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        let hoursText = hours == 1 ? "1 hour" : "\(hours) hours"
        let restText = rest == 1 ? "1 minute" : "\(rest) minutes"
        if hours == 0 { return restText }
        if rest == 0 { return hoursText }
        return "\(hoursText) \(restText)"
    }

    /// "about " before a landing time that's the real plane's estimate, else nothing (Stage 3 spec §9).
    static func about(_ leg: MapLeg) -> String {
        leg.isArrivalEstimated ? "about " : ""
    }
```

In `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

Replace:

```swift
            if let leg = tripMap.currentLeg {
                let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
                let over = stories[leg.id]?.place(atFraction: leg.progress(at: now)).map { ", over \($0.name)" } ?? ""
```

with:

```swift
            if let leg = tripMap.currentLeg {
                let below = stories[leg.id]?.place(atFraction: leg.progress(at: now))?.name
                // With a real plane the sentence says how it's doing against the schedule (Stage 3 spec §9).
                if let live = TripMapWording.liveSummary(for: leg, over: below, now: now, calendar: calendar, locale: locale) {
                    return live
                }
                let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
                let over = below.map { ", over \($0)" } ?? ""
```

In `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

Replace:

```swift
    /// "lands 4:05 PM there", or in the family's time when the destination keeps it or its zone isn't known.
    static func lands(_ leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if let there = leg.destination.timeZone,
           there.secondsFromGMT(for: leg.end) != calendar.timeZone.secondsFromGMT(for: leg.end) {
            return "lands \(TripMapWording.clockTime(leg.end, in: there, locale: locale)) there"
        }
        return "lands \(TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }
```

with:

```swift
    /// "lands 4:05 PM there", or in the family's time when the destination keeps it or its zone isn't known. With
    /// the real plane's estimate, "lands about 3:52 PM there" (Stage 3 spec §9).
    static func lands(_ leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let about = TripMapWording.about(leg)
        if let there = leg.destination.timeZone,
           there.secondsFromGMT(for: leg.end) != calendar.timeZone.secondsFromGMT(for: leg.end) {
            return "lands \(about)\(TripMapWording.clockTime(leg.end, in: there, locale: locale)) there"
        }
        return "lands \(about)\(TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }
```

- [ ] **Step 3: Review batch B.** Dispatch `superpowers:code-reviewer` (sonnet) on Tasks 5 to 7, with the spec's §5, §6.2, §7.3, §9 and §15 and this plan's list of where it differs.

- [ ] **Step 4: Checkpoint, batch B.** Todd runs the five new classes, and the classes of the code these tasks changed:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:CrewluvTests/LiveTripMapTests -only-testing:CrewluvTests/TripReplayClockCarryTests -only-testing:CrewluvTests/FlightDrawingTests -only-testing:CrewluvTests/LiveMarkerTests -only-testing:CrewluvTests/LiveWordingTests -only-testing:CrewluvTests/TripMapTests -only-testing:CrewluvTests/TripMapStatusTests -only-testing:CrewluvTests/TripMapDrawingTests -only-testing:CrewluvTests/TripMapMarkerTests -only-testing:CrewluvTests/TripMapLineTests -only-testing:CrewluvTests/TripMapWordingTests -only-testing:CrewluvTests/TripFactsTests -only-testing:CrewluvTests/TripFactsRowsTests -only-testing:CrewluvTests/FactsWordingTests -only-testing:CrewluvTests/TripReplayClockTests -only-testing:CrewluvTests/TripReplayClockPaceTests -only-testing:CrewluvTests/TripTimelineTests -only-testing:CrewluvTests/TripMapCameraTests
```

Expected: every test passes. The five new classes have 51 tests (8, 6, 16, 4 and 17). The thirteen others are as they were.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): the trip map's words for a real plane: its label for the bar and the pill, "about" before a landing time that's its estimate, and the card's sentence for VoiceOver (Stage 3 spec §9, §15)`.

---

### Task 8: The map's views

No tests: these are SwiftUI and MapKit. They were type-checked for iOS with the rest of the app. Todd sees them in the previews here and on a real flight in Task 10.

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapView.swift`
- Modify: `Crewluv/Views/TripMap/TripMapCoordinator.swift`
- Modify: `Crewluv/Views/TripMap/TripMapInFlightBar.swift`
- Modify: `Crewluv/Views/TripMap/TripMapCard.swift`
- Modify: `Crewluv/Views/TripMap/TripMapScreen.swift`
- Modify: `Crewluv/Views/TripMap/TripMapPreviews.swift`

- [ ] **Step 1: Let the map know when it shows a replay.**

In `Crewluv/Views/TripMap/TripMapView.swift`:

Replace:

```swift
    var isFullScreen = false
```

with:

```swift
    var isFullScreen = false
    /// `date` is a moment of the replay, not now: a flight with a record shows its real plane alone, where the
    /// record has it (Stage 3 spec §7.3).
    var isReplay = false
```

In `Crewluv/Views/TripMap/TripMapCoordinator.swift`:

Replace:

```swift
        let drawing = TripMapDrawing(tripMap: parent.tripMap, at: parent.date)
```

with:

```swift
        let drawing = TripMapDrawing(tripMap: parent.tripMap, at: parent.date, isReplay: parent.isReplay)
```

- [ ] **Step 2: Put the label on the card's bar, and frame a path that grew.** The card's own timeline ticks every 10 seconds, so the label is at most that old.

In `Crewluv/Views/TripMap/TripMapCard.swift`:

Replace:

```swift
        .onChange(of: tripMap.legs.map(\.id)) { refit() }
```

with:

```swift
        .onChange(of: tripMap.legs.map(\.id)) { refit() }
        // A real path can grow past what the card framed (Stage 3 spec §6.2).
        .onChange(of: tripMap.framingKey(focusingOn: tripMap.currentLeg)) { refit() }
```

Replace:

```swift
            TripMapInFlightBar(leg: leg)
```

with:

```swift
            TripMapInFlightBar(leg: leg, status: TripMapWording.flightStatus(for: leg, at: date))
```

In `Crewluv/Views/TripMap/TripMapInFlightBar.swift`:

Replace:

```swift
//  The bar under the card's map in flight (moving map spec §5.3): the flight number, which opens the tracking links
//  as before, and the landing time, in the family's time and the destination's.
//
```

with:

```swift
//  The bar under the card's map in flight (moving map spec §5.3, Stage 3 spec §9): the flight number, which opens
//  the tracking links as before, how the real plane is doing against the schedule, and the landing time, in the
//  family's time and the destination's.
//
```

Replace:

```swift
    let leg: MapLeg

    @State private var isShowingTracking = false
```

with:

```swift
    let leg: MapLeg
    /// "In flight", or the real plane against the schedule: "12 min ahead" (`TripMapWording.flightStatus`).
    let status: String

    @State private var isShowingTracking = false
```

Replace:

```swift
            Text("In flight")
                .font(.caption)
```

with:

```swift
            Text(status)
                .font(.caption)
```

- [ ] **Step 3: The full-screen map.** A clock that isn't live is a replay. The pill says so, the map draws it, and the clock carries on through a change of times.

In `Crewluv/Views/TripMap/TripMapScreen.swift`:

Replace:

```swift
            .onChange(of: Self.replayLegs(of: tripMap)) {
                // A new schedule, such as a delay, gives the timeline new ends and a new pace.
                clock = Self.clock(for: tripMap, isQuickLayovers: isQuickLayovers)
            }
```

with:

```swift
            .onChange(of: Self.replayLegs(of: tripMap)) {
                // New times, such as a delay or the real plane's newest landing estimate, give the timeline new ends
                // and a new pace. A replay carries on from the moment it was at (Stage 3 spec §7.3).
                clock = clock.carried(to: tripMap.span, legs: Self.replayLegs(of: tripMap),
                                      waits: Self.replayWaits(of: tripMap), at: .now)
            }
```

Replace:

```swift
        let legs = replayLegs(of: tripMap)
        let waits = tripMap.waits.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
        return tripMap.mode == .recap
```

with:

```swift
        let legs = replayLegs(of: tripMap)
        let waits = replayWaits(of: tripMap)
        return tripMap.mode == .recap
```

Replace:

```swift
    private static func replayLegs(of tripMap: TripMap) -> [TripReplayClock.Stretch] {
        tripMap.legs.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
    }
```

with:

```swift
    private static func replayLegs(of tripMap: TripMap) -> [TripReplayClock.Stretch] {
        tripMap.legs.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
    }

    /// Each wait on the ground, from its start to its end.
    private static func replayWaits(of tripMap: TripMap) -> [TripReplayClock.Stretch] {
        tripMap.waits.map { TripReplayClock.Stretch(start: $0.start, end: $0.end) }
    }
```

Replace:

```swift
                        clearance: TripMapClearance(leading: mapLeadingClearance, bottom: mapBottomClearance),
                        isFullScreen: true)
```

with:

```swift
                        clearance: TripMapClearance(leading: mapLeadingClearance, bottom: mapBottomClearance),
                        isFullScreen: true, isReplay: !clock.isLive)
```

Replace:

```swift
            pill: TripMapWording.topPill(for: tripMap, at: time, dayNumber: dayNumber, totalDays: totalDays),
```

with:

```swift
            pill: TripMapWording.topPill(for: tripMap, at: time, dayNumber: dayNumber, totalDays: totalDays,
                                         isReplay: !clock.isLive),
```

- [ ] **Step 4: Add the previews.** The plane is made up: off ten minutes early, by way of a place south of Greenland, seen every two minutes.

In `Crewluv/Views/TripMap/TripMapPreviews.swift`:

Replace:

```swift
//  Europe trip's recap. The full-screen map shows with Quick layovers on and off. Each preview builds its own story
//  store.
//
```

with:

```swift
//  Europe trip's recap. The full-screen map shows with Quick layovers on and off. Three more show a real plane,
//  made up here: in the air and ahead, estimated after an ocean nobody saw it over, and full screen. Each preview
//  builds its own story store.
//
```

Replace:

```swift
    /// A store with Quick layovers set,
```

with:

```swift
    /// A made-up real plane from `origin` to `destination` by way of `waypoint`, off at `takeoff` and seen every two
    /// minutes until `lastSeen`, except through `unseen`.
    static func liveFlight(legID: String, from origin: CLLocationCoordinate2D, via waypoint: CLLocationCoordinate2D,
                           to destination: CLLocationCoordinate2D, takeoff: Date, lastSeen: Date,
                           unseen: ClosedRange<Date>? = nil) -> LiveFlight {
        let speed = 560 * GreatCircle.metersPerNauticalMile / 3600
        let firstPart = GreatCircle.distance(from: origin, to: waypoint)
        let secondPart = GreatCircle.distance(from: waypoint, to: destination)
        func place(at time: Date) -> CLLocationCoordinate2D {
            let flown = min(time.timeIntervalSince(takeoff) * speed, firstPart + secondPart)
            return flown <= firstPart
                ? GreatCircle.point(from: origin, to: waypoint, fraction: flown / firstPart)
                : GreatCircle.point(from: waypoint, to: destination, fraction: (flown - firstPart) / secondPart)
        }
        let trail = stride(from: takeoff.addingTimeInterval(60), through: lastSeen, by: 120)
            .filter { !(unseen?.contains($0) ?? false) }
            .map { time -> LiveFlight.TrailPoint in
                let here = place(at: time)
                return LiveFlight.TrailPoint(time: time, latitude: here.latitude, longitude: here.longitude, altitudeFeet: 38_000)
            }
        let last = place(at: lastSeen)
        let fix = LiveFlight.Fix(latitude: last.latitude, longitude: last.longitude, altitudeFeet: 38_000, groundSpeedKnots: 560,
                                 trackDegrees: nil, isOnGround: false, registration: "N605UP", typeCode: "B748", seenAt: lastSeen)
        return LiveFlight(legID: legID, callsign: "UPS207", state: .airborne, fix: fix, landedAt: nil, trail: trail)
    }

    /// The Europe trip `hoursIn` hours after its first departure, with a real plane on the first flight: off ten
    /// minutes early, north of the great circle, and last seen `lastSeenMinutesAgo` minutes ago.
    static func europeLive(hoursIn: Double, lastSeenMinutesAgo: Double, hasUnseenOcean: Bool = false) -> TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-hoursIn * 3600)
        let legs = europeLegs(from: start)
        guard let origin = coordinate("SDF"), let destination = coordinate("CGN") else { return nil }
        let takeoff = start.addingTimeInterval(5 * 60)
        let unseen = hasUnseenOcean ? takeoff.addingTimeInterval(1.5 * 3600)...takeoff.addingTimeInterval(2.5 * 3600) : nil
        let live = liveFlight(legID: "UPS207", from: origin, via: CLLocationCoordinate2D(latitude: 58, longitude: -45),
                              to: destination, takeoff: takeoff, lastSeen: now.addingTimeInterval(-lastSeenMinutesAgo * 60),
                              unseen: unseen)
        let flights = LiveLegs.flights(for: legs, legacyDelayMinutes: nil, answered: ["UPS207": live], clockOffset: 0,
                                       coordinate: { coordinate($0) })
        return TripMap.make(tripLegs: LiveLegs.replacingTimes(in: legs, with: flights, at: now), isNextTrip: false,
                            homeAirportCode: "SDF", legacyDelayMinutes: nil, flights: flights, at: now,
                            coordinate: { coordinate($0) })
    }

    /// A store with Quick layovers set,
```

Replace:

```swift
#Preview("Full screen, in flight, Quick layovers on") {
```

with:

```swift
#Preview("Real plane, in the air") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 4, lastSeenMinutesAgo: 0.5) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Real plane, estimated past an unseen ocean") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 4, lastSeenMinutesAgo: 25, hasUnseenOcean: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Full screen, real plane") {
    if let map = TripMapPreviewData.europeLive(hoursIn: 4, lastSeenMinutesAgo: 0.5, hasUnseenOcean: true) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
            .defaultAppStorage(TripMapPreviewData.storage(quickLayovers: true))
    }
}

#Preview("Full screen, in flight, Quick layovers on") {
```

- [ ] **Step 5: Todd looks at the three new previews in Xcode's canvas.**
  - **"Real plane, in the air":** a solid white path from Louisville that bends north of the straight line, the blue plane at its end, a dashed blue line on to Cologne, and the dashed-outline ghost behind it on the path. The bar reads how far ahead the plane is, where it read "In flight", and "Lands about" a time.
  - **"Real plane, estimated past an unseen ocean":** the same, with a dotted stretch in the middle of the path, a dotted stretch from the path's end to the plane, and the plane faded. The bar's label starts with "About".
  - **"Full screen, real plane":** the pill reads the flight and its label. Drag the timeline back: the ghost goes, the pill reads "In flight", and the blue plane flies the path. Play it: it keeps playing.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): the trip map's card and full-screen map show the real plane: its label on the bar and the pill, a replay that shows it alone and carries on through a new landing estimate, and three previews (Stage 3 spec §7.3, §9)`.

---

### Task 9: The status screen's model, and the cards

This is the task that turns it on. `PartnerStatusReceiver` gets its `LiveFlightSource`, and from here a listed pilot's family sees the real plane.

**Files:**
- Modify: `Crewluv/Services/PartnerStatusReceiver.swift`
- Modify: `Crewluv/Views/Welcome/ContentView.swift`
- Modify: `Crewluv/Views/Status/PilotStatusView.swift`
- Modify: `Crewluv/Views/Status/NarrativeCardView.swift`

- [ ] **Step 1: The model.**
  - It makes its source in `init`, and starts following its flights there.
  - `startPeriodicCheck()` and `stopPeriodicCheck()` are already called when the screen comes to the front and leaves it. They now tell the source too. The task that tells it the screen came to the front checks that the screen is still there, since it may run after the screen has left again.
  - `resolveAndSchedule()` gives the source the legs to watch, makes the flights, and resolves from the legs at their real times. The status it publishes carries those legs, so every card reads them.
  - `followLiveFlights()` uses Observation: it resolves again whenever the source's flights change, and never while the demo shows or with no status up.

In `Crewluv/Services/PartnerStatusReceiver.swift`:

Replace:

```swift
//  The status screen's model: the pilot's status as PilotStatusSource reads it
//

import Foundation
import CloudKit
import Observation
```

with:

```swift
//  The status screen's model: the pilot's status as PilotStatusSource reads it, with the real plane's times in
//  place of the schedule's where Crewlu Cloud has seen the flight (Stage 3 spec §7.1)
//

import Foundation
import CloudKit
import CoreLocation
import Observation
```

Replace:

```swift
    private let statusSource: PilotStatusSource
    private var transitionTask: Task<Void, Never>?

    init(shareManager: CloudKitShareManager) {
        statusSource = .shared
```

with:

```swift
    private let statusSource: PilotStatusSource
    private var transitionTask: Task<Void, Never>?

    /// Asks Crewlu Cloud for the pilot's flights with live data while this screen is in front (Stage 3 spec §11).
    private let liveSource: LiveFlightSource
    /// Whether this screen is in front, as it last said.
    private var isInFront = false

    /// Each flight with live data, by its leg's id: its plan, path and record, for the trip map. The legs in
    /// `pilotStatus` already carry the real plane's times (Stage 3 spec §7.1).
    private(set) var flights: [String: MapFlight] = [:]

    init(shareManager: CloudKitShareManager) {
        statusSource = .shared
        liveSource = LiveFlightSource()
```

Replace:

```swift
        // Wait for any in-progress share acceptance to complete before checking
        Task {
```

with:

```swift
        followLiveFlights()

        // Wait for any in-progress share acceptance to complete before checking
        Task {
```

Replace:

```swift
    func enterDemoMode() {
        isInDemoMode = true
        pilotStatus = .demo
```

with:

```swift
    func enterDemoMode() {
        isInDemoMode = true
        flights = [:]
        pilotStatus = .demo
```

Replace:

```swift
    /// Pulls the persisted data source out of UserDefaults and applies it to the in-memory
```

with:

```swift
    /// Pull to refresh and the refresh button: reads the status, then asks for the live plane, and ends when both
    /// are in.
    func refreshByHand() async {
        await refresh()
        guard !isInDemoMode else { return }
        await liveSource.ask()
    }

    /// Pulls the persisted data source out of UserDefaults and applies it to the in-memory
```

Replace:

```swift
    /// Resolve current state from trip legs and schedule next transition.
    /// Trusts Duty's pre-computed fields; only overrides displayStatus and location
    /// when the resolver finds an active leg for real-time transitions.
    private func resolveAndSchedule() {
        let now = Date()
        guard let reading = statusSource.reading else {
            pilotStatus = nil
            return
        }
```

with:

```swift
    /// Resolve current state from trip legs and schedule next transition.
    /// Trusts Duty's pre-computed fields; only overrides displayStatus and location
    /// when the resolver finds an active leg for real-time transitions.
    ///
    /// One landing time (Stage 3 spec §7.1): a flight with live data gets the real plane's times here, before
    /// anything reads the legs, so the status, the map and every card agree. It runs again at each new answer about
    /// the live plane, and at each read of the status, which on Crewlu Cloud comes every 60 seconds while the screen
    /// is in front: a time that changes by itself, as when a plane on the ground stops being seen, is at most that late.
    private func resolveAndSchedule() {
        let now = Date()
        guard let reading = statusSource.reading else {
            pilotStatus = nil
            flights = [:]
            return
        }
```

Replace:

```swift
        guard raw.hasTripLegs else {
            debugLog("[Resolve] No trip legs, using raw status")
            pilotStatus = raw.named(displayName)
```

with:

```swift
        guard raw.hasTripLegs else {
            debugLog("[Resolve] No trip legs, using raw status")
            liveSource.watch([])
            flights = [:]
            pilotStatus = raw.named(displayName)
```

Replace:

```swift
        let legs = raw.tripLegs
        debugLog("[Resolve] Passing \(legs.count) legs to TripStateResolver")
```

with:

```swift
        let scheduledLegs = raw.tripLegs
        liveSource.watch(LiveLegs.watched(in: scheduledLegs))
        let flights = LiveLegs.flights(for: scheduledLegs, legacyDelayMinutes: raw.flightDelayMinutes,
                                       answered: liveSource.flights, clockOffset: liveSource.clockOffset,
                                       coordinate: Self.airportCoordinate)
        let legs = LiveLegs.replacingTimes(in: scheduledLegs, with: flights, at: now)
        self.flights = flights
        debugLog("[Resolve] Passing \(legs.count) legs to TripStateResolver, \(flights.count) with live data")
```

Replace:

```swift
            tripLegsJSON: raw.tripLegsJSON,
            quickStatus: raw.quickStatus,
```

with:

```swift
            tripLegsJSON: legs == scheduledLegs ? raw.tripLegsJSON : LiveLegs.blob(legs) ?? raw.tripLegsJSON,
            quickStatus: raw.quickStatus,
```

Replace:

```swift
    func startPeriodicCheck() {
        statusSource.startPeriodicCheck(for: self, pausedWhile: { [weak self] in self?.isInDemoMode ?? true })
    }

    /// This screen left the front. The check stops once no screen is in front.
    func stopPeriodicCheck() {
        statusSource.stopPeriodicCheck(for: self)
    }
}
```

with:

```swift
    /// The live plane is asked for once now, and every 30 seconds while a flight's window is open (Stage 3 spec §11).
    func startPeriodicCheck() {
        statusSource.startPeriodicCheck(for: self, pausedWhile: { [weak self] in self?.isInDemoMode ?? true })
        isInFront = true
        Task { [weak self] in
            // The screen may have left the front again before this runs.
            guard let self, self.isInFront else { return }
            await self.liveSource.screenCameToFront()
        }
    }

    /// This screen left the front. The check stops once no screen is in front, and the live plane isn't asked for
    /// until this screen is back.
    func stopPeriodicCheck() {
        statusSource.stopPeriodicCheck(for: self)
        isInFront = false
        liveSource.screenLeftFront()
    }

    // MARK: - The Live Plane

    /// Resolves again at each new answer about the live plane, so the legs' times follow it (Stage 3 spec §7.1).
    private func followLiveFlights() {
        withObservationTracking {
            _ = liveSource.flights
        } onChange: { [weak self] in
            // Called just before the flights change: wait until they have.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.pilotStatus != nil, !self.isInDemoMode {
                    self.resolveAndSchedule()
                }
                self.followLiveFlights()
            }
        }
    }

    private static func airportCoordinate(_ code: String) -> CLLocationCoordinate2D? {
        AirportDataProvider.shared.airportInfo(forIataCode: code).map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }
}
```

- [ ] **Step 2: The screen.** It hands the flights down beside the status, and its three refreshes by hand (pull to refresh, and the refresh button on iPhone and on iPad) wait for the live plane too.

In `Crewluv/Views/Welcome/ContentView.swift`:

Replace:

```swift
                                isOnCrewluCloud: receiver.isOnCrewluCloud,
                                onExitDemo:
```

with:

```swift
                                isOnCrewluCloud: receiver.isOnCrewluCloud,
                                flights: receiver.flights,
                                onExitDemo:
```

Replace:

```swift
                    isOnCrewluCloud: receiver.isOnCrewluCloud,
                    onExitDemo:
```

with:

```swift
                    isOnCrewluCloud: receiver.isOnCrewluCloud,
                    flights: receiver.flights,
                    onExitDemo:
```

In each of the 2 places it comes, replace:

```swift
onRefresh: { Task { await receiver.refresh() } }
```

with:

```swift
onRefresh: { Task { await receiver.refreshByHand() } }
```

Replace:

```swift
            .refreshable {
                await receiver.refresh()
            }
```

with:

```swift
            .refreshable {
                await receiver.refreshByHand()
            }
```

- [ ] **Step 3: The status view and its cards.** The map takes the flights. The narrative and the countdown say "about" of a landing time that's the real plane's estimate.

In `Crewluv/Views/Status/PilotStatusView.swift`:

Replace:

```swift
    var isOnCrewluCloud: Bool = false
    var onExitDemo: (() -> Void)? = nil
```

with:

```swift
    var isOnCrewluCloud: Bool = false
    /// Each flight with live data, by its leg's id, from the screen's model (Stage 3 spec §11): the trip map draws
    /// its real plane, and the cards say "about" of a landing time that's its estimate.
    var flights: [String: MapFlight] = [:]
    var onExitDemo: (() -> Void)? = nil
```

Replace:

```swift
    /// Days home since the pilot actually reached home.
```

with:

```swift
    /// The flight between its gates whose landing time is the real plane's estimate, when there is one (Stage 3
    /// spec §9).
    private var estimatedFlight: TripLeg? {
        guard !flights.isEmpty else { return nil }
        let now = Date()
        return status.tripLegs.first { leg in
            leg.type == .flight
                && TripStateResolver.effectiveStart(of: leg) <= now && now < TripStateResolver.effectiveEnd(of: leg)
                && LiveLegs.isArrivalEstimated(of: leg, in: flights)
        }
    }

    /// Days home since the pilot actually reached home.
```

Replace:

```swift
                    NarrativeCardView(status: status, upcomingTrip: upcomingTrip)
```

with:

```swift
                    NarrativeCardView(status: status, upcomingTrip: upcomingTrip, isLandingEstimated: estimatedFlight != nil)
```

Replace:

```swift
                        let dateStr = Self.formatHomeArrival(homeTime, homeTimezone: status.homeTimezone)
                        let arrivalSubtitle =
```

with:

```swift
                        // A time that's the real plane's estimate reads "about" (Stage 3 spec §9).
                        let isEstimate = estimatedFlight.map {
                            abs(TripStateResolver.effectiveEnd(of: $0).timeIntervalSince(homeTime)) < 1
                        } ?? false
                        let dateStr = (isEstimate ? "About " : "") + Self.formatHomeArrival(homeTime, homeTimezone: status.homeTimezone)
                        let arrivalSubtitle =
```

Replace:

```swift
                    let tripMap = TripMap(status: status, at: Date())
```

with:

```swift
                    let tripMap = TripMap(status: status, flights: flights, at: Date())
```

In `Crewluv/Views/Status/NarrativeCardView.swift`:

Replace:

```swift
    let status: SharedPilotStatus
    var upcomingTrip: UpcomingTripInfo? = nil
```

with:

```swift
    let status: SharedPilotStatus
    var upcomingTrip: UpcomingTripInfo? = nil
    /// The flight in the air lands at the real plane's estimate, so its time reads "about 3:18 PM" (Stage 3 spec §9).
    var isLandingEstimated = false
```

Replace:

```swift
    private var inFlightNarrative: some View {
        let verb = currentFlightIsCommercial ? "riding" : "flying"
```

with:

```swift
    private var inFlightNarrative: some View {
        let verb = currentFlightIsCommercial ? "riding" : "flying"
        let about = isLandingEstimated ? "about " : ""
```

In each of the 5 places it comes, replace:

```swift
 which is \(Text(arrTimeStr).bold()).")
```

with:

```swift
 which is \(about)\(Text(arrTimeStr).bold()).")
```

- [ ] **Step 4: Review batch C.** Dispatch `superpowers:code-reviewer` (sonnet) on Tasks 8 and 9, with the spec's §7, §9, §11 and §13 and this plan's list. Ask it in particular about the model: an order of events that leaves the source asking in the background, a resolve that runs while the demo shows, and anything that reads the schedule's times after this task.

- [ ] **Step 5: Checkpoint, batch C.** Todd runs every test of the app once, since this task touches the screen everything hangs from:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

Expected: every test passes.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): the status screen asks Crewlu Cloud for the live plane while it's in front and gives each flight it has seen the real plane's times, so the status, the map and every card show one landing time (Stage 3 spec §7.1, §11)`.

---

### Task 10: On a real flight

What nothing but a real flight can show. It needs a flight of Todd's between its gates, his account listed on Crewlu Cloud's switch, and the app built from Xcode on a device or a simulator that follows him as one of his partners. Todd is the pilot on that flight, so before it he says who watches: someone at home, or the session running this plan, with the simulator's panel open and a screenshot at each step. The spec asks for this before the switch goes to everyone (§16.5).

**Files:** none, unless something is wrong.

- [ ] **Step 1: Before the flight leaves,** with the app open on the status screen within 30 minutes of the departure:
  - The map shows the trip as before, with the pilot's marker at the airport. No plane yet.
  - In Xcode's console, `[Resolve]` lines end "0 with live data", and then "1 with live data" once Crewlu Cloud has seen the aircraft on the ground.

- [ ] **Step 2: From the gate to the takeoff.**
  - Once the flight's departure time passes, the blue plane sits at the airport, where the aircraft really is, and the bar still reads "In flight". If the aircraft can't be seen on the ground there, the schedule's outlined plane shows instead, as today.
  - Fifteen minutes after the departure time, if it's still on the ground: the ghost leaves along the dashed line, and the bar reads "Still on the ground", then "Still on the ground · 20 min behind". "Lands about" slides later each time the screen updates.

- [ ] **Step 3: In the air.**
  - The path is solid white behind the plane and follows where it really flew. The dashed line runs from the plane to the arrival airport.
  - The bar reads "12 min ahead", "20 min behind" or "On schedule", and the pill on the full-screen map reads the same after the flight number.
  - The landing time is the same on the map's bar, the narrative card ("which is about ..."), the countdown card when this flight is the one home, and the full-screen map's landing line.
  - The plane points the way it's going.
  - Leave the app open for five minutes. The plane moves on, and the landing time doesn't jump by more than a minute or two at a time.
  - Pull to refresh: the spinner ends after the plane has moved, not before.
  - Put the app in the background for five minutes and bring it back: the plane is up to date within a few seconds.

- [ ] **Step 4: Out of sight.** Over the ocean, or anywhere adsb.lol loses the plane for more than two minutes:
  - The plane fades. A dotted line runs from the end of the solid path to it. The label starts with "About".
  - When it's seen again, it's solid again, and the stretch nobody saw stays dotted if it was more than ten minutes.

- [ ] **Step 5: The replay,** on the full-screen map while the flight is in the air:
  - Drag the timeline back into the flight. The ghost goes, the pill reads "In flight", and the plane is where it really was.
  - Press play and wait two minutes, through at least one new fix. The replay keeps playing from where it was. Before this plan it would have gone back to live.
  - Drag past now: the plane is faded and flies the dotted line.

- [ ] **Step 6: Landing.**
  - Once the plane is seen on the ground at the arrival airport, the bar reads "Landed 8 min early" or the like, and the landing time loses its "about".
  - Seven minutes after touchdown the status changes to the layover or to home, and the flight's line turns grey along the path it really flew.
  - If the landing was never seen: the plane reaches the airport at its estimate and the status changes seven minutes later.

- [ ] **Step 7: The looks.** On the card and full screen, in hybrid, standard (light and dark) and satellite:
  - The real plane, the ghost and the three kinds of line can each be told apart.
  - On the standard map in light mode the real path is blue. Say if the ghost is too faint there.
  - VoiceOver on the card reads one sentence: the flight, its label in full ("12 minutes ahead of schedule"), and "Lands about" a time.
  - At the largest text sizes the bar's label wraps under the flight number and nothing is cut off.

- [ ] **Step 8: Write down what was wrong.** Anything that needs a change goes in "Changes made during execution", is fixed in its own task's files, and has Todd run that task's tests again. A change to an answer the website shares (a label, a phase, a time) starts in the reference, `scripts/live-cases/live.mjs`, then the cases, then the Swift, as in plan 3B-1: never in the JSON alone.

---

### Task 11: Review, the docs and the record

**Files:**
- Modify: `CLAUDE.md`
- Modify: this plan

- [ ] **Step 1: Review the whole branch.** Dispatch `superpowers:code-reviewer` (sonnet) on this plan's commits, with the spec's §5 to §9, §11, §13 and §15, and this plan's list of where it differs. Use `superpowers:receiving-code-review` on what comes back.

- [ ] **Step 2: Todd runs every test once more,** with the command of Task 9's checkpoint.

- [ ] **Step 3: Update `CLAUDE.md`.** Under "#### Trip Map", in the bullet that begins "The real plane's engine", replace:

```markdown
is in `Services/TripMap/Live/`, and nothing shows it yet. `FlightPlan` is
```

with:

```markdown
is in `Services/TripMap/Live/`. `FlightPlan` is
```

After that bullet, add:

```markdown
- The real plane on the map (plan `docs/superpowers/plans/2026-11-15-moving-map-stage3b2-app-map.md`). `PartnerStatusReceiver` owns the `LiveFlightSource`, tells it when the screen comes to the front and leaves it, and resolves again at each of its answers. One landing time: before anything reads the legs, `LiveLegs` gives each flight with live data the real plane's times in place of the schedule's, and moves the waits either side to meet them, so the status, the map and every card agree. A leg keeps its delay, and its times are written so the delay moves them to the real ones. Alerts read the status source, so they stay on the schedule. `MapFlight` is a flight's plan, path and record made together, on `MapLeg.flight`. `FlightDrawing` draws a flight by `LiveProgress.phase`: the real path, solid where the plane was seen and dotted where it wasn't, the real plane (faded while it's an estimate) and the schedule's ghost. A moment of the replay shows the real plane alone, where its record has it. A landing time that's the real plane's estimate reads "about" (`MapLeg.isArrivalEstimated`). The facts still follow the great circle, and adsb.lol isn't credited yet: both are plan 3B-3's
```

Under "#### Status Management", replace:

```markdown
- `PartnerStatusReceiver` is the screen's model: it shows how every read went
```

with:

```markdown
- `PartnerStatusReceiver` is the screen's model: it shows how every read went, and hands on the legs with the real plane's times where Crewlu Cloud has seen a flight (`LiveLegs`)
```

- [ ] **Step 4: Record what changed.** Add "## Changes made during execution" to the end of this plan: each review's changes, what Task 10 turned up, and anything a step did differently. If any of it changes what the spec says, change the spec to match, and say so in the list.

- [ ] **Step 5: Ask to commit.** Suggested message: `docs(crewluv): the real plane on the map in CLAUDE.md, and the Stage 3B-2 plan as it was built`.

- [ ] **Step 6: The release note.** Draft one entry for the Apple Note "Crewluve revisions", in plain words for a pilot's family, under the version and build Todd names. A draft to start from: "When your pilot's flight can be seen from the ground, the map now shows the real plane and the path it really flew, with a faint second plane where the schedule says it should be. The card tells you how far ahead or behind the flight is, and every landing time on the screen follows the real plane." Show Todd the draft and ask before writing it to the note.

---

## What 3B-3 and the website's plan take from this one

- **`MapLeg.flight`** is where a flight's plan, path and record are. `MapLeg`'s own `progress(at:)`, `position(at:)`, `time(atFraction:)`, `heading(at:)` and `distance` are still the schedule's along the great circle, between the leg's real gate times. 3B-3 moves the facts to the path and the record, and may then move those five.
- **The moment.** `MapFlight.progress(at:)` takes this device's time and adds Crewlu Cloud's clock itself. `MapFlight.record` takes the trip's own time: a replay hands it the moment on the timeline.
- **Whether a moment is now or a replay** is `isReplay`, from the full-screen map's clock (`!clock.isLive`). The card is always now. 3B-3's rows that are "for now only", like the plane's height and speed, need it.
- **`MapLeg.isArrivalEstimated`** says whether to write "about". `TripMapWording.about(_:)` writes it.
- **The sun events and the landing forecast are made again at each new landing estimate,** since `LegStoryStore.preparationKey` holds each leg's times. The forecast is kept by airport and hour, so that costs nothing. The sun events are worked out again, and kept under each estimate's key for as long as the screen is: a few hundred small entries on a long flight. 3B-3 moves them to the record, and should key them by the path then.
- **"Estimated · last seen near Gander"** (§8, §9) and the headline chip's order are 3B-3's, with the story along the path.
- **The credit** goes in the facts' footer whenever a leg has `flight?.live`.
- **The website** does the same in `src/engine/` and `src/map/`: the real times are written where a summary becomes the engine's schedule, and the drawing chooses by the phase. The table at the head of Task 6 is the drawing's whole rule, and the list of where this plan differs from the spec applies to the website too, so the two stay alike.

## Self-review

- **Spec coverage.**
  - §5.1, what shows in each state: Task 6. §5.3, the label: Task 7, with the engine's `LiveLabel`. §5.4 and §5.5, the ghost and the estimated plane, and their looks: Task 6.
  - §6.2, how the path is drawn, and the camera framing it: Tasks 3, 5 and 6.
  - §7.1, the real times and the waits either side: Task 4, and Task 9 where the model uses it. Alerts on the schedule: they read `PilotStatusSource`, which this plan doesn't touch.
  - §7.3, the replay: Task 6 (the real plane alone, on its record), Task 7 (the pill), Task 5 and Task 8 (the clock carries on). The timeline's blocks use the legs' times, which are the real ones.
  - §9, the words: Task 7 for the map's, Task 9 for the countdown and narrative cards.
  - §11: `LiveFlightSource` owned by the status screen's model, Task 9. `MapLeg` carries its path and its record, Task 3. `TripMapDrawing`, `TripMapShapesView` and the markers, Task 6. One landing time, Tasks 4 and 9.
  - §13, what can go wrong: no coverage at either airport, a plane seen again after its estimate, a return, a diversion and a wrong phone clock are each a shared case or a rule of the engine's that the drawing follows. Task 6's tests draw every one of the shared cases.
  - §15: the card's one sentence, Task 7. The label's words, not colour. The planes aren't VoiceOver elements: `PlaneMarker` stays hidden from it.
  - §16.3's tests for this part: `TripMapDrawing`'s lines and planes (Task 6), the words (Task 7), and one landing time (Task 4).
- **Not covered here, on purpose:** §8's facts, the plane's row, `AircraftTypeNames`, the credit, and "last seen near". They're 3B-3's.
- **Names** are the same in every task: `MapFlight(departure:arrival:from:to:live:clockOffset:)`, `progress(at:)`, `isEstimate(_:)`, `FlightPath.coordinates`, `runs(from:to:)`, `coordinates(from:to:)`, `framingCoordinates`, `heading(atDistance:)`, `MapLeg.flight`, `MapLeg.isArrivalEstimated`, `LiveLegs.watched(in:)`, `flights(for:legacyDelayMinutes:answered:clockOffset:coordinate:)`, `replacingTimes(in:with:at:)`, `isArrivalEstimated(of:in:)`, `blob(_:)`, `TripMap.make(... flights: ...)`, `TripMap(status:flights:at:)`, `framingKey(focusingOn:)`, `TripReplayClock.carried(to:legs:waits:at:)`, `FlightDrawing(leg:at:isReplay:)`, `TripMapDrawing(tripMap:at:isReplay:)`, `RealPlaneMark`, `TripMapMarker.realPlane(angle:isEstimated:)` and `.ghost(angle:)`, `PlaneMarker.Look`, `TripMapWording.flightStatus(for:at:isReplay:)`, `spokenLiveLabel(_:)`, `spokenMinutes(_:)`, `liveSummary(for:over:now:calendar:locale:)`, `about(_:)`, `topPill(... isReplay:)`, `PartnerStatusReceiver.flights` and `refreshByHand()`.
- **Is it the right size?** Three new types, each with one job, and one new file of extensions. Nothing is built ahead of its use but `LiveLegs.blob`, used in Task 9. What was left out on purpose: sliding the plane between fixes, a real plane parked before its leg starts, live data under a summary-wide delay, and the second of two legs that are one flight. Each is in the list of where this plan differs, or in "Left for later".
- **What could it break?**
  - A flight with no live data must draw, frame and read exactly as before. The existing tests of the drawing, the markers, the lines, the map, the words and the facts pass unchanged, and three new tests pin it: the 33 framing places, the lines' names, and the schedule's sentence.
  - The status screen's model changes for everyone on Crewlu Cloud, not only listed pilots. With no flights answered, `LiveLegs.flights` is empty, `replacingTimes` hands back the same legs, and the status carries the same bytes as before.
  - On iCloud the source asks nothing and its flights stay empty, so the model never resolves on its account.
  - While a real plane is being seen, the model resolves at each new answer, up to every 30 seconds. It already resolved at each read of the status, every 60.
  - The helper target is untouched: none of its 15 files changes.
  - A replay's clock now keeps its moment through a new delay. Before, it went back to live. That's a change for families with no live data too, and a better one.
- **Is it what an Apple engineer would write?** Value types that are `nonisolated` and `Sendable` for everything that can be tested. The view layer renders a drawing it's handed and decides nothing. Observation, not a second callback, tells the model its source changed. The source's call is an unstructured task because it must outlive whoever asked, and it holds the source weakly. Standard MapKit annotations and the app's own layers, as the map already has them.

## Left for later

- **The facts on the real path,** the plane's row and the credit: plan 3B-3.
- **A real plane parked at the gate before its leg starts** isn't shown. The spec has it shown whenever it's seen there.
- **The planes don't slide between fixes.** Zoomed far in on the full-screen map, the plane steps from fix to fix. If it should glide, the coordinator can animate the real plane's annotation, off under Reduce Motion.
- **Live data under a summary-wide delay.** Today's CrewLu tags the flight's own leg whenever it sends the summary-wide delay (`PartnerStatusGenerator`), so this is only for an older CrewLu.
- **Legs of a summary that are one flight:** the second shows the schedule, as in the engine plan.
- **Two windows on iPad** each have a model, so each has a source and each asks.
- **A device with a wrong clock** still decides which leg is under way by its own time, as it always has. Only a fix's age is measured by Crewlu Cloud's.
- **A time that changes by itself** waits for the next answer or the next read of the status, up to a minute.
- **The sun events are kept under each landing estimate** while the screen is up (see what 3B-3 takes).
- **The engine's own "Left for later"** is otherwise as it was: asks that come back empty until the switch is `all`, a flight back on the ground after a return, and a trail count that stays wrong.

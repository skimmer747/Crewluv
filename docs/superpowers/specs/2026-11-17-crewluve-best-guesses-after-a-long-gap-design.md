# Crewluve's Best Guesses After a Long Gap: the Schedule's Speed, and Only the Ocean

Status: approved by Todd on 17 Nov 2026, after the check of UPS96 (Anchorage to Clark, 16–17 Nov) against Crewlu Cloud's record of it. It refines the Stage 3 spec (`2026-11-14-crewluve-moving-map-stage3-live-design.md`) §4, on the plane's own speed, and the best guesses design (`2026-11-15-crewluve-facts-best-guesses-design.md`) §2 and §3. Where they differ, this wins.

## 1. Why

UPS96 went out of tracking range over the Bering Sea at 6:08 PM EST and was heard again just off Miyagi, Japan, at 10:49 PM: 4 h 42 min later. Two things went wrong in that gap.

- **The landing estimate was 42 min early:** "about 2:41 AM" at the gate, against a real 3:23 AM. The app flew the whole ocean at the speed it had measured over Alaska, 532 mph, where the plane had a tailwind. The schedule's speed was 496 mph, and over Japan the plane really made 479.
- **The places were wrong:** at 9:49 PM the app said "Crossed into Japan · About now", over Hokkaido. The real plane was over the Pacific about 250 mi east, and crossed into Japan at 11:06 PM near Iwaki, where it was being tracked. The guess flies the shortest route on from the last sighting, which crosses the Sea of Okhotsk and Russia's Kuril Islands; UPS96 went down the ocean side of the Kurils.

The guesses said "about", which was honest. But past a couple of hours, both the speed and the route are the schedule's to know, not the last sighting's.

## 2. The speed

- **The plane's own speed for the next 2 hours of flying, and the schedule's after that.** From the last place the plane was tracked, the cruise left is flown at the plane's own speed for 2 hours, or all of it when less is left, and the rest at the schedule's speed. The last 120 nm stay the descent, at 280 kt.
- **One speed for the plan.** The two are made into the one cruise speed that takes the same time over the cruise left. The landing estimate, the estimated plane, the ghost and the record all fly it, as they fly the plane's own speed now (Stage 3 spec §4), so the gap between the two planes is still the label. Only the time is meant: inside the gap, the estimated plane is a little off where a plane flying two speeds would be, which nobody can see.
- **The same rule, tracked or not.** A tracked plane is measured from its newest place, so its estimate settles on its own speed as it nears the destination. Nothing jumps when it goes out of range: the estimate made at the last sighting holds still through the gap, as now.
- **Unchanged:** how the plane's own speed is measured (over 10 minutes of its cruise or more) and when it's believed (from 0.7 of the schedule's speed to 1.5 of it, else the schedule's stands for both); a leg flown at one steady speed; a plane on the ground; a plane that has landed.

### 2.1 What it would have done

Crewlu Cloud has recorded two flights: UPS82 (Louisville to Anchorage, 15 Nov, touchdown 20:03 UTC) and UPS96 (touchdown about 08:16 UTC, from its last fix on final approach). Each was estimated again from every place it was tracked, and the estimates were compared with its real touchdown.

At the last sighting before each flight's long gap (+ is late, − is early):

| | Own speed all the way (now) | Own speed for 2 h, then the schedule's | The schedule's speed all the way |
|---|---|---|---|
| UPS96 at 23:08 UTC, 9.1 h to go, 532 mph against the schedule's 496 | 42 min early | 17 min early | 8 min early |
| UPS82 at 17:38 UTC, 2.4 h to go, 537 mph against the schedule's 486 | 5 min late | 5 min late | 18 min late |

- **The cost:** UPS82 kept its tailwind across Canada, so 5 to 7 hours out its estimates average 32 min late, against 24 now. In the last 2 hours every rule gives the same answer.
- **UPS96's 17 minutes left** are its route, 69 mi longer than the great circle (about 8 min), and the slower winds over Japan.
- **Two flights prove no rule.** Todd chose this one because it more than halves UPS96's miss and keeps UPS82's. It's worth testing again as Crewlu Cloud records more flights.

## 3. The words, past 2 hours

The same 2 hours. Past them, the place the guess names can be hundreds of miles from the plane.

- **Events are held.** A crossing, "Out over", halfway or the closest point to home ahead of the last sighting isn't told when its guessed time is more than 2 hours after the last sighting: not in the list, the banner, the headline, the chip or VoiceOver. Those guessed within the 2 hours are told as now.
- **Once the plane is tracked again,** the events in the gap are told as best guesses on the straight join between the two places it was tracked, with "about" (best guesses design §3). They're in the past by then, so they take their places in the list, and the banner shows the newest event.
- **What's below names only an ocean:** the Pacific, the Atlantic, the Indian Ocean, the Arctic Ocean or the Southern Ocean, with no city near it: "Over the Pacific". Over a sea, a bay or land, nothing is named. The headline and the chip go on to the landing countdown, and the card's sentence and VoiceOver leave "over …" out.
  - **Why not the seas.** Under the new speed, UPS96's guess would cross the Sea of Okhotsk from about 8:45 to 10 PM, while the real plane stayed over the Pacific. Only an ocean is wide enough to be right that far out.
- **Unchanged:** the "Last tracked over the Bering Sea · 3 h 41 min ago" line, the faded plane on the map, and the sheet's rows for halfway and the closest point to home, which already say "about".

### 3.1 UPS96 under these rules

- **6:08 to 8:08 PM EST:** within the 2 hours, as now: "Over the Bering Sea", then "Over the Pacific", with any event told.
- **8:08 to 10:49 PM:** "Over the Pacific" while the guess is over it, else the landing countdown. No crossing into Russia or Japan is told. "Last tracked over the Bering Sea · … ago" stays in the sheet.
- **From 10:49 PM:** tracked again. The gap's events are told on the straight join, with "about", and "Crossed into Japan" comes at 11:06 PM, tracked, with its plain time.
- **The landing estimate** reads about 3:06 AM at the gate from 6:08 PM on, against the real 3:23 AM, in place of 2:41 AM.

## 4. The website

The website follows with the same two rules, in its own plan.

- **The speed** goes into the reference that writes `CrewluvTests/Fixtures/TripMap/live-cases.json` (`scripts/live-cases/live.mjs`), with the 2 hours among its constants and a case of a long ocean gap. The JSON is written by `node scripts/live-cases/generate.mjs`, never by hand, and copied to the website.
- **The words** are tested by each side's own tests with the same answers, as the best guesses were: `facts-cases.json` holds stories without a real plane.

## 5. Not in this design

- **Routes:** the guess still flies the shortest route on from the last sighting. Real routes keep clear of airspace a carrier can't use, such as Russia's for UPS, and follow the oceanic tracks of the day. Neither is known to Crewlu Cloud.
- **A flight Crewlu Cloud never marks landed,** as UPS96 wasn't: no receiver near Clark heard it on the ground. The app's estimate carries it to the gate.
- **Tuning the 2 hours** on more flights, once there are more.

## 6. Testing

- **XCTest, run by Todd,** with the shared live cases:
  - the plan's speed with the 2 hours: less than 2 hours of cruise left, more, a plane slower than the schedule, a leg flown steadily;
  - an estimate that holds still through a long gap and doesn't jump when the plane goes out of range;
  - events held past 2 hours, and told on the straight join once the plane is tracked again;
  - an ocean named past 2 hours, and a sea, a country or a state not named;
  - the headline, the card's sentence and VoiceOver without a place.
- **UPS96 and UPS82** are run through the new rule again from their record before the plan is done, to see the numbers in §2.1 and §3.1 come out.

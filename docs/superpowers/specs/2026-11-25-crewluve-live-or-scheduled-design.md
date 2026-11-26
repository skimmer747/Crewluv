# Crewluve Trip Map: Live or Scheduled, Said Everywhere

Status: decided by Todd on 25 Nov 2026, for the website and the app together. It adds to the Stage 3 spec (`2026-11-14-crewluve-moving-map-stage3-live-design.md`), §5.1 (what a device knows) and §9 (the words), and to the which plane design (`2026-11-16-crewluve-which-plane-design.md`), §4 (a plane still at its gate), whose rule that "before the plan's takeoff … nothing changes" it replaces.

## 1. Why

Todd opened the website's full map at 3:12 PM on UPS70, Louisville to Honolulu, while the plane was still at its gate. Crewlu Cloud had never seen it, so the map drew the schedule's plane alone, and everything said it was flying: "UPS70 · In flight", "In the air now", "Over Indiana", "Flying into the night", "Flying to Honolulu". Todd: "This plane hasn't taken off yet it says it has. It has to explain whether something is live or scheduled."

- With no live data, every word followed the schedule's gate times: once the gate departure passed, the flight was "in flight". Only a real plane Crewlu Cloud saw at its gate after the plan's takeoff said otherwise.
- The schedule's popup, "UPS70 · by the schedule" (which plane design §3), needs a tap. The footer's "Estimated from the schedule" shows on every flight, live or not, so it tells nothing.
- Even by the schedule it hadn't taken off: its gate time, 2:59 PM, plus the 15 minutes of taxi the map allows (`TAXI_OUT_MS`, `FlightProgress`) is 3:14 PM. At 3:12 the schedule's plane was taxiing, and still read "In the air now".
- "Over Indiana" at Louisville: a story drops any place the route crosses for under 25 miles (the hold rule), and Kentucky is a few miles to the Ohio River. Right just after takeoff, wrong on the ground.

## 2. How a flight is known

A flight between its gates is in one of three states, now (never in a replay), from Stage 3 §5.1's phases:

| State | When | Phases |
|---|---|---|
| **Tracked live** | Crewlu Cloud saw the plane in the last 3 minutes | `onGround`, `inAir`, `landed`, `returned`, `elsewhere` |
| **Best guess** | Last seen in the air over 3 minutes ago: the faded plane | `estimated` |
| **Not tracked live** | No live data for the flight, never seen, or a fix on the ground over 3 minutes old | `notLive`, or no live data |

- **Waiting for the first answer.** From the moment the page or screen comes to the front until Crewlu Cloud's first answer to it, or that ask fails, a flight reads as not tracked live, but the pill and the card's bar show no source words and the facts no source row, so nothing flips from "Not tracked live" to "Live" in the first second. A failed ask is an answer: not tracked live.
- **On iCloud** the app never asks Crewlu Cloud: every flight is not tracked live, with no wait.

## 3. On the ground at departure

A flight between its gates is on the ground at its departure airport, now, when:

- **tracked live** and its plane is `onGround` there, at any time, or `returned` there after an air return; or
- **not tracked live** and it's before the schedule's takeoff, its gate departure plus the taxi allowance (`airborneWindow`'s start). A block too short for the allowances has none: its takeoff is its gate departure.

A plane on the ground at departure never reads "Over …", "In the air now" or "Flying into the night", and has no latest event: it has passed nothing yet. The which plane design's "still on the ground" (§4) becomes one case of it.

## 4. The words

### 4.1 In the air, by the real plane or by the schedule

| Where | Tracked live | Best guess | Not tracked live |
|---|---|---|---|
| The full map's pill | UPS70 · Live · 12 min ahead | UPS70 · About 12 min ahead (as today) | UPS70 · Not tracked live |
| The card's bar, middle | Live · 12 min ahead | About 12 min ahead (as today) | Not tracked live |
| The facts, first row | **Tracked live** | none: what's below has "Last tracked near Montréal · 12 min ago" under it (as today) | **Not tracked live** / Shown where the schedule has it / If it's running late, it may still be at the gate |
| The list's tag | In the air now | In the air now | By the schedule |
| Under the timeline | Flying to Honolulu | Flying to Honolulu | Should be flying to Honolulu |
| The status sentence | as today | as today | Alex should be flying to Honolulu on UPS flight 70 from Louisville — not tracked live — landing in 8h 59m which is 12:11 AM. |

- **"Live"** comes before the real plane's label: "Live · On schedule", "Live · Landed 8 min early", "Live · Returned to Rockford". With no label (a plane down somewhere else), "Live" alone: "UPS70 · Live".
- **With no flight number** the pill is "Live · 12 min ahead" or "Not tracked live".
- **The rest of the facts** (what's below, the sky, the distance, the landing) stay as they are, under the source row. The plane's row for a live flight stays right after what's below.
- **The delayed sentence,** not tracked live: "Alex was delayed in Louisville and should be flying to Honolulu on UPS flight 70 — not tracked live — landing in …", and "pushed early in" likewise. Riding as a deadhead: "should be riding to".
- **The source row's icon:** a broadcast mark for tracked live, a calendar for not tracked live, in each platform's own set.

### 4.2 On the ground at departure (§3)

| Where | Not tracked live, before the schedule's takeoff | Tracked live, seen at the gate |
|---|---|---|
| The pill | UPS70 · Not tracked live | UPS70 · Live, or UPS70 · Live · Still on the ground · 20 min behind after the plan's takeoff |
| The headline, the card's bottom chip, and the place row | Scheduled to take off about 3:14 PM L | On the ground in Louisville, then Still on the ground in Louisville after the plan's takeoff, or Returned to Rockford |
| The facts' first row | Not tracked live, as §4.1 | Tracked live |
| The distance row | 4,376 mi to go | 4,376 mi to go |
| The sky row, the takeoff row, the latest event | none | none |
| The list | UPS70 tagged "By the schedule", with no events yet | left out until it takes off (as today, now from the gate on) |
| Under the timeline | Scheduled to fly to Honolulu | On the ground in Louisville |
| The status sentence | Alex is due to take off from Louisville on UPS flight 70 to Honolulu — landing in 8h 59m which is 12:11 AM. | Alex is on the ground in Louisville on UPS flight 70 to Honolulu — landing in …, then "is still on the ground in" after the plan's takeoff (as today) |

- **"about"** before the scheduled takeoff: it's the gate time plus the map's own taxi allowance, an estimate. The time is the family's, marked "L" (time labels design §3.2).
- **The delayed sentence** before the takeoff: "Alex was delayed in Louisville and is due to take off on UPS flight 70 to Honolulu — landing in …".
- **Halfway and the closest point to home** keep "about" on the ground, as a plane still at its gate has them today (which plane design §4), and the closest point is left out once its guessed time has gone by.

## 5. A flight's events, not tracked live

A flight that's not tracked live now was seen by nobody: each of its events is the schedule's guess, and reads "about", as an unseen stretch's do (best guesses design §2).

- **The banner:** "Just crossed into Missouri" / "About 5 min ago".
- **The list:** "about 3:45 PM".
- **The rows:** "Halfway at about 7:39 PM L", "Passes 40 mi from home at about 5:05 PM".
- **Now only, and only the flight between its gates.** Earlier flights of the trip, the recap and a replay read as today.
- **The shared cases don't change:** every headline case is well past its takeoff, and a headline has no time.

## 6. A replay

- **No source row:** it says how a flight is known now.
- **The pill and the card's bar:** "UPS70 · In flight" for a flight with a real path (as today, Stage 3 §7.3), "UPS70 · By the schedule" for one without.
- **The list's tag:** "In the air" for a flight with a real path, "By the schedule" for one without.
- **The popup** already says which (which plane design §3).

## 7. Screen readers and VoiceOver

- **The card's sentence** ends with its source in place of "Estimated from the schedule.":
  - not tracked live: "UPS70 to Honolulu, over Indiana. Lands at 12:11 AM your time. Not tracked live, so it's shown where the schedule has it."
  - not tracked live, before the schedule's takeoff: "UPS70 to Honolulu, scheduled to take off about 3:14 PM your time. Lands at 12:11 AM your time. Not tracked live, so it's shown where the schedule has it."
  - tracked live: today's sentence, then "Tracked live."; seen at the gate before the plan's takeoff, "UPS70 to Honolulu, on the ground in Louisville. Lands at … Tracked live."
  - the latest event's sentence, then what the card opens, follow as today.
- **The pill and the bar** are read as they're shown: "UPS70 · Live · 12 min ahead", "Not tracked live".
- **The source row** is read as one element, its lines in order.
- **The website's card heading:** "Not tracked live" or "On the ground" where it said "In flight", "Landed" as today, else "In flight". The app's card has no heading (which plane design §5).

## 8. What stays

- **The map's drawing:** the schedule's plane is drawn as today, taxiing at the gate until the schedule's takeoff and flying after. Only the words change.
- **The footer's "Estimated from the schedule"** stays: times past a plane's last sighting are still the schedule's. "Live position: adsb.lol" shows beside it as today.
- **Alerts** stay on the schedule (they read the status source).
- **"Live"** is plain words, not a badge. The card's bar is checked on a narrow phone and, in the app, at the largest text sizes, where today's longest label, "Still on the ground · 20 min behind", already has to fit.

## 9. Where it lives

Each platform gains one rule, a flight's state of §2 with its waiting time, and widens "on the ground at departure" to §3. Every surface reads them, so none can say otherwise.

- **Website (Crewluve Website):** `src/map/mapFlight.ts` (the state and the widened rule), `src/map/tripMap.ts` (the leg's helpers), `src/copy/tripMap.ts` (the pill, the bar, the timeline line, the card heading and sentence), `src/copy/facts.ts` (the source row, the tag), `src/facts/tripFacts.ts` and `tripFactsRows.ts` (the headline, the rows, the list, the events), `src/copy/narrative.ts` and `src/ui/PilotPages.tsx` (the status sentence), and the live source's first answer for §2's wait.
- **App (Crewluv):** `MapFlight`, `TripMapWording`, `FactsWording`, `TripFacts` and its rows, `TripSoFar`, `LiveLegs` and `PartnerStatusReceiver` (the status sentence's flight, as `stillOnGroundFlight` is today), `NarrativeCardView`, and `LiveFlightSource`'s first answer for §2's wait.
- **The website first,** then the app, each on a `fix/live-or-scheduled` branch, committed only when Todd says.

## 10. Testing

- **Website:** vitest, run with `npm test`: each state of §2 at each surface of §4, now and in a replay, before and after the schedule's takeoff, in both clocks; the wait of §2; the events' "about" of §5, and earlier flights unchanged; the status sentence, delayed, early and riding. The demo gains a scene for the schedule's plane alone, a few minutes after its gate time.
- **App:** XCTest, run by Todd in Xcode, on the same cases as the website's.
- **The shared cases** (`facts-cases.json`, `live-cases.json`, `progress-cases.json`, `replay-cases.json`, `activity-cases.json`) don't change.

## 11. Not in this design

- The hold rule's "Over Indiana" just after takeoff from Louisville: right once the plane is in the air.
- Asking Crewlu Cloud why it never saw UPS70: whether adsb.lol had it at the gate, or the flight wasn't watched.
- "About" on earlier flights' and the recap's schedule-only events.
- A "Live" badge or color.

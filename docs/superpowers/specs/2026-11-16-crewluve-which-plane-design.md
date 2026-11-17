# Crewluve Trip Map: Which Plane Is Which, and a Plane Still at Its Gate

Status: decided by Todd for the website on 16 Nov 2026, with the app to follow "with the key and popup". The website's design is `docs/superpowers/specs/2026-11-16-trip-map-which-plane-design.md` in the Crewluve Website repo, and its plans 3C-2 (Task 11), 3C-3 (Tasks 9 and 10) and 3C-4 built it. This is the app's half, in the website's words and rules. It adds to the Stage 3 spec (`2026-11-14-crewluve-moving-map-stage3-live-design.md`), §5.4 (the ghost), §9 (the words) and §15 (accessibility), the best guesses design (§4, the list) and the latest event design (§2, where the banner goes).

## 1. Why

A flight Crewlu Cloud sees draws two planes: the real one, a filled blue circle, and its ghost, a dashed outline where an on-schedule plane would be. On the website's demo Todd couldn't tell them apart: "It's not sure which plane is which, the scheduled or the real time." And a plane still at its gate after its takeoff time was said to be flying, by the schedule's times: over places it hadn't reached, past borders it hadn't crossed.

## 2. The key

- **What it says:** the real plane's mark beside "Real plane", and the ghost's beside "On schedule", each drawn as on the map.
- **When it shows:** while the map draws both the real plane and its ghost. That's now, never in a replay, for a flight Crewlu Cloud has seen at its departure airport, in the air, or not for a while. A flight with no live data, a landed plane and a plane down somewhere else have no ghost, and no key.
- **Where:** on the card, at the map's top trailing corner; on the full-screen map, under the top bar's buttons. In the glass of the map's buttons, in light and dark.
- **Beside the latest event's banner** (Todd, "A: key just under the banner"): the key stays where it is where it fits beside the banner with a gap, else it moves just under the banner, still at the trailing edge. It goes by the widest the banner can be while the same event shows ("About 88 h 88 min ago"), so it doesn't move as the minutes count up.
- **The camera** keeps the plane clear of the banner and the key, as it keeps it clear of the banner alone.
- **At the largest text sizes** the card's chips move below its map, and the key goes with them, after the latest event.
- **It takes no taps,** nor does the banner: a tap on either goes on to the map. VoiceOver doesn't see the key: it's the key to a picture VoiceOver doesn't see. The card's sentence and the pill say how the real plane is doing.

## 3. The popup

- **Where:** the full-screen map, on the real plane and its ghost. The schedule's own plane, alone on a flight with no live data, has none.
- **How it opens and closes:** a tap on a plane opens it. A tap anywhere else on the map closes it, and a tap on the other plane moves it there. One at a time. It closes when its plane is no longer drawn, and when a replay starts or stops, since what it says changes.
- **It moves with its plane,** just above its mark, and its words change as the map's do. Near the top of the clear part of the map, below the top bar, the banner and the key, it goes under the plane, and near a side it slides in. It closes when the next flight's planes take its plane's place.
- **VoiceOver doesn't see it,** as it doesn't see the key.
- **The words,** as the website's, in this device's time zone and clock. A title, then a line or two:

| The plane | Title | Lines |
|---|---|---|
| The ghost | On schedule | Where {flight} was scheduled to be |
| The real plane, at its departure airport or in the air | {flight} · real plane | {label} / Lands {about}{landing} |
| The real plane, estimated (faded) | {flight} · best guess | Not seen since {seen}, so it's drawn where it should be by now / {label} · lands {about}{landing} |
| The real plane, landed | {flight} · real plane | {label} / Reaches the gate {at or about}{landing} |
| The real plane, down somewhere else | {flight} · real plane | nothing more |
| The real plane in a replay | {flight} · real plane | Where it was at {moment} |

- `{flight}` is the flight number, or "the flight" with none. `{label}` is the card's bar's words, left out with none. `{about}` is "about " when the landing time is the real plane's estimate.

## 4. A plane still at its gate

A flight between its gates whose real plane is still on the ground at its departure airport after the plan's takeoff time, as its bar says "Still on the ground" (Todd, "Yes, these words"). Now only: a replay reads where the map has the plane. Before the plan's takeoff it's taxiing as the schedule has it, and nothing changes.

- **The facts:** the headline and the first row, "Still on the ground in Rockford", ahead of any event or sun countdown; the distance row, "2,788 mi to go"; no sky row; halfway and the closest point to home said with "about", and the closest point left out once its guessed time has gone by.
- **The latest event:** none: it has passed nothing yet, whatever the schedule's times say.
- **The list:** its flight is left out until it takes off, with no "In the air now" (Todd, "Leave it out until it takes off").
- **Under the full-screen map's timeline:** "On the ground in Rockford", and VoiceOver's value says the same.
- **The status sentence:** "Alex is still on the ground in Rockford on UPS flight 2963 to Anchorage — landing in 5h 37m which is about 6:58 PM.", delayed or not. With no flight number, "on the flight to Anchorage".
- **The card's VoiceOver sentence** says what's below and where the plane was last seen only while it flies: not at its gate, nor once it's down.

## 5. Where the app settles details

- **No card heading.** The website's card has a heading for screen readers, "On the ground"; the app's card is one VoiceOver element, whose sentence already says "still on the ground".
- **The popup opens on a tap only,** on iPad too: the app has no pointer popups.
- **The popup is the app's own,** in the map's glass, not MapKit's callout: its words change every second, and it goes under its plane near the top.
- **A plane takes a tap on its mark,** 26 points across. A wider area would let the real plane's cover the ghost's where the two are close.
- **The key counts in the card's top clearance even with no banner,** as the top chip always has.
- **The camera needs no slide for the planes.** MapKit fits the leg in flight inside the map's margins, which hold the banner, the key and the bottom chip, and keeps Apple's logo inside them. The website's map needed one.

## 6. Testing

XCTest, run by Todd: every row of §3's table on the shared cases' flights, now and in a replay, in both clocks; the key's rule at every shared moment, and its place beside the banner or under it; the popup's place; each of §4's words, at the gate after the plan's takeoff time and not before it, now and not in a replay. A flight with no live data reads as before.

## 7. Not in this design

- The website's slide that keeps the planes in view on a thin card.
- The Schedule page's "about" before a landing estimate.
- A popup on an airport, the pilot's marker or the schedule's own plane.
- A flag on the map where an event happened.

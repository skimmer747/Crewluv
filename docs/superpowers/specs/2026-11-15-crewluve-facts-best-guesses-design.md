# Crewluve Facts: Best Guesses Over the Ocean, and the Newest First

Status: approved by Todd on 15 Nov 2026, from a sketch of the facts sheet during an ocean flight, the night before a flight from Anchorage across the Pacific. It refines the Stage 3 spec (`2026-11-14-crewluve-moving-map-stage3-live-design.md`) §8, §9 and §15, as plan 3B-3 built them. Where they differ, this wins.

## 1. Why

Plan 3B-3 told a border crossing only where the real plane was seen, since a crossing nobody saw is a guess. Over an ocean the plane goes unseen for hours. The chip then read "Estimated · last seen near Anchorage" for the whole crossing, and nothing new was ever said: duller than the map was before it had a real plane.

The app already knows where the plane most likely is: it flies the plane on from the last place it was seen, along the great circle, at the plan's speed. That's the faded plane on the map. The facts now read from there too.

## 2. A plane that's out of sight

- **What's below** is read where the map draws the plane: "Over the Pacific". The words are the same as when the plane is seen. There's no "probably" and no "estimated" in front: plain words, which anyone can read.
- **One line says it's an estimate:** "Last tracked near Anchorage · 2 h 10 min ago", by a city of a million or more, else "Last tracked over Alaska · 2 h 10 min ago", else "Last tracked 2 h 10 min ago". It's in the first row of the sheet, under what's below. ("Last tracked" since 16 Nov 2026, in place of "Last seen", which Todd found could make a family fear the plane was missing. It's the receivers that lose it, not air traffic control.)
- **The chip** reads what's below, or a new event, in plain words, in its usual order: an event from the last 5 minutes, a cockpit sunrise or sunset in the next 30, what's below, the landing countdown.
- **VoiceOver:** "UPS207 to Cologne, about 12 minutes ahead of schedule, over the Atlantic, last tracked near Montréal. Lands about 3:18 PM your time." Where what's below is where it was last tracked, it's said once: "…, last tracked over Québec."

## 3. Events nobody saw

- **An event is a best guess** where nobody saw the plane: on a stretch with no coverage, or past the last place it was seen.
- **It's told,** as a crossing, halfway or the closest point to home always was, at the time the plan has the plane there.
- **In the list its time reads "about":** "Out over the Pacific · about 4:05 PM", drawn lighter and slanted. An event the plane was seen at has its plain time.
- **"Closest to home" and "Halfway"** in the rows say "about" in the same way.
- **When the plane is seen again,** events on the stretch nobody saw stay best guesses, on the straight join between the two places it was seen. If it turns up somewhere the plan didn't have it, the guesses ahead of it are worked out again and can move.

## 4. The list

- **Under each flight, the newest event is first,** so the latest is at the top without scrolling.
- **The flight between its gates stands out:** a border, and an "In the air now" tag ("In the air" in a replay). It's listed even before its first event.
- **Earlier flights** sit plain underneath, newest first.
- **"Trip so far" shows once.** Where the rows already have a "Trip so far" row (on a layover, on a drive), it isn't said again under the list.

## 5. Not in this design

- **The latest event shown large on the map.** After the flight of 16 Nov.
- **The website.** It follows in its own plan, with this design's rules.

## 6. Testing

XCTest, run by Todd: best guesses on a stretch nobody saw and past the last sighting; the plain headline and the last-seen line; "about" in the list and the rows; VoiceOver's sentence; the list newest first; the flight in the air set apart; "Trip so far" once. A flight with no live data reads as before, but for the list's order and "Trip so far" said once.

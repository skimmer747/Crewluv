# Crewluve Trip Map: Landed, Not Yet at the Gate

Status: approved by Todd on 17 Nov 2026, from a sketch of three wordings ("A: 'Landed in Anchorage'"), for the website and the
app. This is the app's copy of the website's design (Crewluve Website repo, the same path, at `329ce7a`), with §6 for where
the words go in the app. Todd settled two details on 17 Nov 2026, from the website's plan: "at", not "about", once the plane
is down, as the card's sentence and the popup say it; and the bar's right side, "At the gate 8:47 AM".

## 1. Why

For the few minutes between touchdown and the gate, the flight's bar, the card's sentence and the plane's popup already say
the plane is down ("Landed 8 min early", "…, landed 8 minutes early. Reaches the gate at 7:52 PM your time."). Everything
else still talks as if it were flying: "Over Alaska", "2,788 mi flown · 0 to go", "Lands Anchorage about 3:52 PM", the
list's "In the air now", "Flying to Anchorage" under the timeline, and "Alex is flying to Anchorage … — landing in 8m". A
family reading two of them at once gets two stories.

## 2. When

- **The real plane has landed:** Crewlu Cloud's state for the flight is "landed" (the engine's `landed` phase), and
- **it isn't at the gate yet:** the moment is before the leg's gate arrival (`leg.end`, the real plane's estimate where
  there is one, as every card has it).
- **Now only,** as "Still on the ground" is: a replay reads the map's plane, as before.
- A flight with no live data never knows its touchdown, so it reads as it always has.

## 3. The words

| Where | Today | In that window |
|---|---|---|
| The facts' headline, their first row, and the card's bottom chip | "Over Alaska" | **Landed in Anchorage** |
| The distance row | "2,788 mi flown · 0 to go" | **2,788 mi flown** (its comparison line as before) |
| The sky row | shown | **left out**, as at the gate |
| The landing row | "Lands Anchorage about 3:52 PM · 7:52 PM your time" | **Reaches the gate at 3:52 PM · 7:52 PM your time** ("at", as the card's sentence and the popup say it once the plane is down); the weather line under it as before |
| The card's bar, its right side | "Lands 8:47 AM" | **At the gate 8:47 AM** (the city's own time under it as before) |
| The list's tag on the flight | "In the air now" | **Landed** (its border kept) |
| The line under the timeline (and the slider's spoken value) | "Flying to Anchorage" | **Landed in Anchorage** |
| The status page's sentence | "Alex is flying to Anchorage on UPS flight 2963 from Rockford — landing in 8m which is about 7:52pm EST." | **Alex has landed in Anchorage on UPS flight 2963 — at the gate in 8m which is 7:52pm EST.** (with no flight number, "on the flight") |
| The card's heading for screen readers | "In flight" | **Landed** |

"Anchorage" is the arrival airport's city, as everywhere else. The first row's other lines (where the plane was last
tracked, the closest point to home) are left out with what's below, as "Still on the ground" does.

## 4. Unchanged

- The flight's bar's left side ("Landed 8 min early", "Landed on time", "Landed 8 min late").
- The card's sentence for screen readers ("…, landed 8 minutes early. Reaches the gate at 7:52 PM your time.").
- The plane's popup ("Reaches the gate at …").
- The latest event's banner, which the latest event design keeps until the gate.
- The plane's own row: the aircraft's name, with no height or speed (the plane isn't in the air).

## 5. Not in this design

- A plane that lands somewhere other than its arrival airport (a diversion): the engine's phases don't tell it apart today.
- An air return (back down at the departure airport): left for later in plan 3C-3.
- The app's words: its own plan, `docs/superpowers/plans/2026-11-17-landed-before-gate.md`, from this design.

## 6. In the app

- **The rule:** `MapFlight.hasLanded` (Crewlu Cloud's state "landed"), `MapLeg.isLandedBeforeGate` (and the leg is between its gates), `TripFacts.isLandedBeforeGate` (and the facts aren't a replay's), `TripMap.landedAirport` for the line under the timeline, and `LiveLegs.landedFlight` for the status sentence.
- **The card's bottom chip** is the facts' headline, so it says "Landed in Anchorage" with them.
- **The card's bar** is `TripMapInFlightBar`: its right side reads "At the gate 8:47 AM" (`TripMapWording.barArrival`), with the city's own time under it as before.
- **The card has no heading of its own,** so §3's row for it is the website's only: the app's VoiceOver label is the card's sentence, which §4 leaves as it is.
- **A diversion the app can tell:** a plane last seen on the ground away from its arrival airport isn't "Landed in Anchorage", and reads as before (`MapFlight.hasLanded`). One with no such fix can't be told apart, as §5 says.
- **The status sentence** is `NarrativeCardView`'s, delayed or not, with its red or green countdown kept.
- **Previews:** "Real plane, landed, not yet at the gate", on the card and full screen, in place of the website's demo scene.

# Trip Map: What the Pilot Is Doing, and Quick Layovers

Status: approved in brainstorming with Todd on 2026-11-14, from his first look at the trip map on his iPad. It covers the Crewluve app and the Crewluve website, which keep matching. It amends the moving map spec (`docs/superpowers/specs/2026-11-13-crewluve-moving-map-design.md`) §5.1, §6, §10, §14 and §15.1.

## 1. Goal

Todd's notes, in his words:
- **The heart:** "Needs to be something showing what's going on. Like a plane, a car, a bed."
- **Long layovers in a replay:** "The user doesn't want to sit and wait for the layover to end."
- **The timeline:** "Change the colors to show when in the air or laying over."
- **The night during a layover:** "Speed the day night shadow up so it doesn't just snap into place. It will give a better illusion of time passage."

So:
- **The pilot's marker shows what they're doing:** on a layover, at a turn, at base or at home. The plane and the car already show them moving.
- **A replay hurries through each wait on the ground,** with the clock still running through it, so the night sweeps by like a time-lapse.
- **The timeline is colored by what the pilot is doing,** sized by how long each part takes to replay.

## 2. The pilot's marker

### 2.1 The markers

Each ground marker is a white symbol on a colored circle with a white ring, the size and style of today's heart. The colors are system colors, so they adapt to dark mode, and none matches a route line.

| What the pilot is doing | Symbol | Color |
|---|---|---|
| On a layover | `bed.double.fill` | indigo |
| At a turn, waiting to fly again | `hourglass` | orange |
| At base, not home | `briefcase.fill` | teal |
| At home | `house.fill` | green |

The plane (in flight) and the car (driving) are unchanged. The heart goes: the rules below give every moment a marker.

### 2.2 Which marker

The marker is decided for any moment, so a replay changes it as it goes. While a leg is moving, the plane or the car shows and there's no ground marker, as today.

- **A wait** is any stretch of the trip where no leg is moving: from one leg's end, delay included, to the next leg's start. The pilot is at the earlier leg's destination.
- **Its kind comes from CrewLu's own ground legs.** CrewLu sends layovers, turns, and base and home stays as legs of their own (`TripLeg.LegType` `.layover`, `.turn`, `.base`, `.home`). The map keeps them now, where today it drops every leg that isn't a flight or a drive.
  - The ground leg that overlaps the wait the most gives its kind. A tie goes to the earlier leg.
  - With no ground leg overlapping, the wait is home at the home airport and base at the base airport (amended 2026-11-14, base waits and card framing design §2). Elsewhere its length decides: 8 hours or more is a layover, less is a turn.
- **Before the trip's first departure:**
  - **A next trip** (the pilot at home with this trip ahead) shows home, or base while the status says the pilot waits there (amended 2026-11-14, base waits and card framing design §3).
  - **Otherwise** the pilot is at the first leg's origin. That's home if it's the home airport, and base if it isn't.
- **After the trip's last arrival:**
  - **A recap** shows home.
  - **Otherwise** the pilot is at the last leg's destination. That's home if it's the home airport, and base if it isn't.

The marker shows on the card and on the full-screen map.

## 3. The replay's pace

### 3.1 Quick layovers

- **A switch, "Quick layovers",** sits beside the speeds. It's on by default.
- **The app remembers it** (`@AppStorage`), and so does the website (its browser storage). It's the same for every trip.
- **Turning it on or off during a replay** keeps the map on the same moment and carries on from there at the new pace.

### 3.2 The rules

The replay plays the trip's span, from its first departure to its last arrival, in stretches. At 1x:

- **Normal rate:** a day in 48 s, 1,800 s of trip a second.
- **A leg in motion:** as today. A leg that would take under 3 s slows so it takes 3 s, and where legs overlap the slowest wins.
- **A wait, with Quick layovers on:** it takes 1 s for each day of the wait, and never less than 3 s.
  - It's never slower than the normal rate, so a wait that already passes in under 3 s keeps its pace. A 1-hour turn still takes 2 s.
  - So a 15- to 27-hour layover takes 3 s, a 4-day one takes 4 s, and a 2-hour turn takes 3 s.
- **A wait, with Quick layovers off:** the normal rate, as today.

The speed multiplies everything: at 10x a 3 s layover takes 0.3 s.

Nothing is skipped. The trip's clock runs through every minute of a wait, so the night, the facts and the marker move through it, fast.

### 3.3 Smooth enough to see

- **During a replay,** the full-screen map updates up to 60 times a second, where it updated 30.
  - A 27-hour layover in 3 s turns the night 405°, about 135° a second. At 30 updates a second its edge would step about 4.5° at a time, which shows.
  - At 60 the steps are about 2°, and 10x looks smoother too.
- **Live or paused,** the map updates once a second, as today.

## 4. The timeline

### 4.1 The bar

- **The bar measures replay time.** Each part's width is how long it takes to replay at 1x at the current pace.
  - **With Quick layovers on,** layovers are small blocks and the flights fill most of the bar.
  - **With it off,** a 4-day layover takes its full share, as it would take 3 minutes and 12 seconds to play.
  - **During a replay** the thumb crosses the bar at a steady pace at any one speed: no stalls through a layover, no jumps.
- **Its colors are the markers':**
  - **Flying:** blue.
  - **Driving:** gray.
  - **A wait:** its marker's color: indigo for a layover, orange for a turn, teal for base, green for home.
  - Where a flight and a drive overlap, the flight's blue wins.
- **Progress:** the part already played is full color, and the part ahead is paler.
- **Layover lengths:** a wait's block shows its real length, such as "20h" or "4d", when the label fits inside the block at the current text size. Otherwise the block stays plain.
  - Under 48 hours it's whole hours, and from 48 hours whole days.

### 4.2 Around the bar

- **The line under the bar** says when and what, such as "Sat 1:40 PM · Layover in Denver". Its wording:
  - "Flying to San Francisco";
  - "Driving to Louisville";
  - "Layover in Denver";
  - "Turn in Denver";
  - "At base in Louisville";
  - "Home".
- **Dragging** moves through the trip in the bar's measure. Dragged into a layover's block, the map shows the pilot at that point in the layover.
- **Unchanged:** Live, play and pause, and 1x to 10x.

### 4.3 Built from the clock

- **The bar is drawn by the app,** not by `Slider`, so it can be colored by part.
- **For VoiceOver it's a slider** (`accessibilityRepresentation`), with the moment and the activity as its value: "Saturday 1:40 PM, layover in Denver".
- **The bar's positions come from the replay clock,** which already works out how long each part takes. The clock now also says where each part starts and ends in replay time, and turns a position on the bar back into a moment of the trip.

## 5. The website

- **The same changes:** the markers and their colors, the colored timeline, Quick layovers (on by default, remembered in the browser), the same pace and the same words.
- **The website session** (`trip-map-web`) builds the website's half from this design, in its own repository and with its own plan. This session doesn't touch the website.
- **Two shared case files hold the app and the website to the same answers,** as `progress-cases.json` does today. Each repository keeps a copy, and a change to one is made to both.
  - `CrewluvTests/Fixtures/TripMap/replay-cases.json`: sample trips with their legs and waits, Quick layovers on or off, and the trip moment the replay reaches at given replay seconds, with each trip's whole replay length.
  - `CrewluvTests/Fixtures/TripMap/activity-cases.json`: sample trips with their flights, drives and CrewLu's ground legs, and the marker and the under-bar line at given moments.
- **The app's plan writes both files first,** so the website can start from them while the app is built.

## 6. The app's parts

- **`TripMap`** keeps CrewLu's ground legs and answers what the pilot is doing at any moment (§2.2).
- **A pure type for the activity:**
  - the kinds: flying, driving, layover, turn, base, home;
  - each kind's symbol and color;
  - the under-bar words.
- **`TripReplayClock`** paces waits by §3.2:
  - it's given the waits and whether Quick layovers is on;
  - it can switch pace at a moment;
  - it says where each part starts and ends in replay time, and the trip moment at any replay position.
- **A pure type for the bar's blocks:** each part's kind, start and end in replay time, and its label.
- **`TripMapMarker`** shows the activity's marker where the heart was. `TripMapDrawing` carries the activity with the pilot's place.
- **The timeline control:**
  - draws the bar;
  - adds the switch;
  - moves the slider in replay time;
  - writes the under-bar line.
- **`TripMapScreen`** builds the clock with the waits and the switch, and updates up to 60 times a second while a replay plays.

## 7. Accessibility

- **The switch** is a standard toggle, labeled "Quick layovers".
- **The bar** reads as a slider whose value is the moment and the activity.
- **Text size:** labels on the bar grow with the text size and drop out when they no longer fit. The bar's height doesn't change.
- **On the map** VoiceOver doesn't read the ground markers, as it didn't read the heart. The card's sentence and the facts rows already say where the pilot is.
- **Reduce Motion** changes nothing here. A replay is started by the family, and the camera's moves between legs already respect it.

## 8. Testing

- **App unit tests:**
  - the activity rule (§2.2), against `activity-cases.json` and on its own;
  - the clock's new pace and its replay positions, against `replay-cases.json` and on its own;
  - the bar's blocks and labels;
  - the under-bar words.
- **Previews:** the card on a layover, a turn, at base and at home; the full-screen map with Quick layovers on and off.
- **On Todd's iPad and iPhone:**
  - a replay at 1x and at 10x, Quick layovers on and off;
  - the night sweeping smoothly through a layover;
  - the marker changing as the replay moves through the trip;
  - the bar's colors, labels and steady thumb;
  - VoiceOver on the bar.

## 9. Not in this design

- Skipping waits outright. Todd wants the time to pass, not vanish.
- A different pace for each trip, or a setting outside the map.
- Changes to the card's chips, the facts or the camera.
- Live data's real plane. That's Stage 3.

## 10. Amendments to the moving map spec

Applied in the app's plan:
- **§5.1:** the heart pin becomes the activity marker (§2 here).
- **§6:** the timeline's colors and measure, Quick layovers, and 60 updates a second during a replay (§3 and §4 here).
- **§10:** the new parts (§6 here).
- **§14:** the bar's VoiceOver value and the switch (§7 here).
- **§15.1:** the two new shared case files (§5 here).

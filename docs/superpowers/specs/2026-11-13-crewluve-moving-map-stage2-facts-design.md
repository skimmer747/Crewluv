# Crewluve Moving Map, Stage 2: The Facts

Status: approved in brainstorming on 2026-11-13, from mockups of the facts sheet at each height, the iPad and landscape panel, the rows on the ground and at home, the recap card and the website's narrow panel.

It builds on the moving map spec, `2026-11-13-crewluve-moving-map-design.md` (here "the map spec"), and refines its §5.2, §6, §8, §10, §11 and §15 for Stage 2. Where the two differ, this one wins. Stage 1 is built: the app on Crewluv `feature/trip-map`, the website on its `trip-map` branch.

## 1. Goal

Give the trip map the facts families enjoy, in the app and on the website:

- what's below the plane, and when it crosses into somewhere new;
- the sun and moon from the cockpit;
- how far, how fast, and what that distance is like;
- when and how they land, with the weather there;
- the trip so far, a forecast of a trip ahead, and a recap once it's over.

Everything comes from the schedule. Stage 3's live data later makes the same facts more exact without changing how they read.

## 2. Decisions (brainstorm, 2026-11-13)

1. **The full-screen map's panel becomes a sheet you drag up,** like Apple Maps. Small, it shows the headline and the timeline. In the middle, a row per kind of fact. Dragged all the way up, the trip so far, or the recap.
2. **On iPad, iPhone in landscape and the website at 900 px or wider, it's a side panel** at the leading edge, full height. Its rows scroll, the timeline is pinned at the bottom, and a chevron collapses it to the headline and timeline.
3. **In flight the rows run "now, then where to":** below the plane, the sky, distance, where they're headed. Stage 3 puts the plane's type and tail after "below".
4. **The sheet has rows on the ground too:** on a layover, at home before a trip, and in the recap (§5). The home sheet forecasts the trip ahead's time zones and cockpit sunsets.
5. **Milestones show on screen only.** No alerts.
6. **Weather on landing** for the flight in the air, and for the next flight when it lands within 48 hours.
7. **The recap is the map card itself,** for 24 hours after the trip ends, with a replay.
8. **`geography.json` comes from Natural Earth 1:50m,** with cities from 1:10m, simplified to about 500 KB. Todd OK'd the download for when the plan reaches it.
9. **`comparisons.json` is the eleven entries in §9.2.**
10. **The website mirrors all of it.** Under 900 px its panel opens with a "More facts" button.
11. **Each leg's story is worked out once** (`LegStory`, §4.2), and every fact at any moment is a lookup in it. The map spec's `MilestoneDetector` is renamed `LegStory`.

## 3. The parts (app)

### 3.1 Pure logic

`nonisolated` value types in `Services/TripMap/Facts/`, each with XCTest. The app target defaults to the main actor, so each is marked `nonisolated`, as Stage 1's are.

| Unit | What it does |
|---|---|
| `Geography` | Decodes the bundled `geography.json` once. `place(at:)` gives the state or province, else the country, else the named water, else nil. `city(near:)` gives a city of 1 million or more within 40 mi. |
| `LegStory` | One flight's events, as fractions along its route: the crossings, halfway and the closest point to home (§4.2). |
| `SkyFacts` | Cockpit sunrises and sunsets, the people below, into the night or morning, chasing the sun, and the moon (§4.5). |
| `MoonPosition` | The moon's phase, and the point it's straight above. A port of the website's `moonPhase` and `crewlu-globe`'s `subLunarPoint`. |
| `TripTotals` | Cities, miles, time zones and cockpit sunsets, up to a moment or for the whole trip, and the longest flight (§4.8). |
| `ComparisonPicker` | Decodes `comparisons.json` and picks a comparison for a distance (§4.9). |
| `TripFacts` | The trip map with its stories and any forecasts. It answers, for any moment: `headline(at:)`, `rows(at:now:)`, `tripSoFar(at:)` and the recap. |
| `FactsWording` | Every sentence the facts show or speak, as `TripMapWording` is for Stage 1. |

### 3.2 Models

`@Observable`, `@MainActor`:

- **`LegStoryStore`** builds stories off the main actor and keeps them by route: origin, destination and home. The status screen owns it and passes it to the card and the full-screen map.
  - It exists because the status screen rebuilds `TripMap` on every render, so the geography is never redone for a route it already has.
  - Sun events depend on each leg's delay-shifted times. They're cheap, so they're worked out fresh against the leg in hand.
- **`LandingWeather`** fetches landing-hour forecasts while the full-screen map is open (§7).

### 3.3 The flow

1. The card runs `.task(id:)` on the trip's routes, which asks `LegStoryStore` to build any missing story.
2. The card and the full-screen map read `TripFacts`, so the chip and the sheet always agree.
3. Until a story is ready, which takes tens of milliseconds, the facts that need it are left out, and the chip shows the landing countdown as in Stage 1.

### 3.4 Changes to Stage 1

- **`TripMap.Mode`** gains `.recap` (§8).
- **`FlightProgress`** gains the inverse of `scheduledFraction`: the time the schedule's plane is at a fraction.
- **`WeatherService`** gains `landingForecast(forAirport:latitude:longitude:at:)` (§7).
- **`TripReplayClock`** can start paused at a given moment.
- **`TripMapPanel` is deleted.** The sheet and the side panel replace it (§6).
- **`TripMapScreen`** presents the sheet, or shows the side panel.
- **`TripMapCard`'s bottom chip** shows the headline in flight.
- **`TripMapWording`** handles `.recap`. Its card summary adds the place below.
- **`TripMap+Status`** picks the recap's trip (§8.1). It builds on the mid-trip-at-home fix in progress there: a night at home mid-trip is that trip under way, not a next trip.

## 4. The facts engine

### 4.1 Geography

- **The order:** a state or province first, then a country, then a named water.
  - "Over Kansas", "Over Ontario", "Over Germany", "Over the Labrador Sea".
  - Over the US or Canada but in a gap between simplified states, it gives the country.
  - With nothing found, it gives nil.
- **The city:** within 40 mi of a city of 1 million or more, the place adds "near Montréal".
- **The test for inside:** an area holds a point when an odd number of its rings do. That handles holes, like Lesotho inside South Africa.
- **Speed:** each area carries its bounding box, and only areas whose box holds the point are tested.
- **Longitudes** are kept within −180…180. Natural Earth splits its shapes at the date line.

### 4.2 The leg's story

`LegStory` is built for a flight leg from its two airports, the geography and home. Its events are fractions along the route: 0 is the departure airport, 1 the arrival.

- **Sampling:** the great circle is sampled every 10 mi, with at least 16 samples, and each sample's place is looked up.
- **Runs:** samples with the same place make a run. A nil sample belongs to no run and changes nothing.
- **The hold rule:** a run shorter than 25 mi is dropped. A route hugging a border doesn't flicker in and out.
- **Crossings:** where one run ends and the next begins, the boundary is narrowed by bisection to within 0.1 mi.
- **Halfway:** the fraction 0.5.
- **Closest to home:**
  - only for a leg whose origin and destination aren't home;
  - the closest point of the route to home, found from the samples and then refined;
  - kept only if it's within 100 mi and not at either end of the route.
- **Times:** `FlightProgress`'s inverse turns a fraction into the time the schedule's plane gets there: the airborne window's start, plus the fraction times its length. A new delay moves every time without redoing the geography.
- **Stage 3** rebuilds a leg's story from the live trail and position.

### 4.3 Milestones

From the story. Each leads the headline for 5 minutes after it happens.

| Event | Headline | Listed afterwards |
|---|---|---|
| A new country | Just crossed into Canada | Crossed into Canada · 1:12 PM |
| A new state or province, same country | Just crossed into Kansas | Crossed into Kansas · 1:12 PM |
| From land onto a named water | Out over the Atlantic | Out over the Atlantic · 2:40 PM |
| Halfway | Halfway! | Halfway · 4:12 PM |
| Closest to home | Closest to home: 40 mi, wave! | Closest to home, 40 mi · 1:05 PM |

- **An international border names the country,** and a state line names the state. Coming in from the sea counts as a new country: "Just crossed into the United States".
- **One water into another** changes the "below" row but isn't a milestone. Otherwise a transatlantic flight would fire five times.
- **The first place under the route** isn't a milestone.
- **Distance to home** is rounded to the nearest 5 mi, and never shown as less than 5.
- **Times** are the family's own.

### 4.4 The headline

In flight, the first of these:

1. a milestone from the last 5 minutes;
2. a cockpit sunrise or sunset in the next 30 minutes: "Sunset from the cockpit in 25 min";
3. the place below: "Over Newfoundland", or "Over Quebec, near Montréal";
4. "Landing in 2 h 10 min", Stage 1's countdown.

On the ground, the headline is Stage 1's: the place and its local time, the next trip, or "Driving to …". In the recap, after the trip's end, it reads "Home from 4 days away".

### 4.5 The sky

- **Cockpit sunrise and sunset:**
  - The moment the sun's altitude at the plane crosses −(0.833° + dip). The dip is 1.76′ × √(height in m).
  - The height is 35,000 ft (`cruiseAltitude`), which makes the dip about 3.03°. Stage 3 uses the live altitude.
  - It's found only inside the airborne window. The window is sampled every 2 minutes, and each crossing is narrowed by bisection to 5 seconds.
- **The people below:** the ground under the event's point sees the same event (at −0.833°) at another time.
  - When that's 5 minutes or more apart, the line adds "about 12 min after the people below" for a sunset, or "about 12 min before the people below" for a sunrise.
- **Into the night or the morning:** when the next cockpit event falls inside the leg, "Flying into the night" before a sunset, or "Flying into the morning" before a sunrise.
- **Chasing the sun:**
  - It applies while the sun is up at the plane and its local hour angle there changes at under 7.5°/h. That's half the usual 15°/h.
  - The rate is 15°/h plus the plane's change in longitude per hour, measured over the next minute.
  - It reads "Chasing the sun: their afternoon is stretching", or "their morning" while the sun is east of the plane's meridian.
- **The moon,** only while the sun is below the cockpit horizon:
  - "Waxing gibbous moon, up", or "Waxing gibbous moon, below the horizon".
  - The phase comes from the website's eight-part `moonPhase`, named with the app's existing `MoonPhase.displayName`.
  - Its altitude at the plane comes from the sub-lunar point, as the sun's does. The moon's parallax, about 1°, is ignored.

### 4.6 Distance

- "2,140 mi flown · 1,960 to go", in statute miles, along the planned route.
- "Halfway at 4:12 PM", until halfway.
- "Averaging about 510 mph": the planned miles over the airborne window, to the nearest 10 mph.
- The leg's comparison (§4.9). Mid-line it starts lowercase: "like driving coast to coast".

### 4.7 Where they're headed

- **The landing line:** Stage 1's "Lands Cologne 9:30 PM · 3:30 PM your time".
- **The weather (§7):** "48°F and rain on landing", in the family's units. The condition is WeatherKit's description, lowercased.
- **The time difference** at the landing time:
  - "6 hours ahead of you", "3 hours behind you", "5½ hours ahead of you", "1 hour ahead of you";
  - nothing when the times match, or when the destination's time zone isn't known.

### 4.8 Totals

- **Cities:** the destinations of finished flights, each once, home left out, as Stage 1 counts them.
- **Miles:** Stage 1's `milesFlown(by:)` up to a moment, and `totalMiles` for the whole trip.
- **Time zones:**
  - each finished flight's change in UTC offset, from departure to arrival, taken as a positive number;
  - summed in seconds and rounded to the nearest whole hour at the end;
  - a flight with an unknown time zone at either end adds nothing.
- **Cockpit sunsets:** the cockpit sunsets in finished flights, or up to the moment.
- **The forecast for a trip ahead:** the same totals over every flight in it.
- **The longest flight:** the flight with the greatest distance, "Dubai → Louisville, 7,640 mi".

### 4.9 Comparisons

For a distance:

- each entry's multiple is the distance over the entry's miles;
- the pick is the entry whose multiple is closest to a whole number from 1 to 10;
- ties go to the smaller whole number, then to the earlier entry.

The multiple is the nearest whole number: 1 uses the entry's `one` phrase, and 2 to 10 its `many` phrase. With no multiple from 1 to 10, there's no comparison.

### 4.10 Replay

Every fact is a lookup at the moment the timeline shows, so replay and scrubbing need nothing extra:

- the rows and the headline follow the timeline;
- the tall stop lists the milestones up to that moment;
- the weather is the exception (§7.3).

## 5. What the sheet shows

### 5.1 In flight

The rows in order. A row with nothing to say is left out. The first part of each row is its title, and the rest are its second line.

1. **Below:** "Over Newfoundland", then the closest-to-home line, "Passes 40 mi from home at 1:05 PM" or "Closest to home was 40 mi at 1:05 PM".
2. *(Stage 3: the plane, "Boeing 767-300 · N370UP".)*
3. **Sky:** "Flying into the night", then "Sunset in 25 min, about 12 min after the people below · Waxing gibbous moon, up". The parts:
   - into the night or the morning;
   - the next cockpit event in the leg, as "in 25 min" under an hour and "at 7:40 PM" otherwise;
   - chasing the sun;
   - the moon.
4. **Distance:** "2,140 mi flown · 1,960 to go", then "Halfway at 4:12 PM · Averaging about 510 mph · like sailing the length of the Nile" (4,100 mi over the Nile's 4,130 is 0.99).
5. **Where they're headed:** the landing line, then "48°F and rain on landing · 6 hours ahead of you".

### 5.2 Dragged all the way up

- **Each flight that has started by that moment, newest first,** under its name: "UPS 207 · Louisville → Cologne", or "Louisville → Cologne" without a flight number.
  - Under it, its milestones up to that moment, with their times.
  - A flight with none is left out.
- **"Trip so far":** "Day 1 of 4 · 1 city · 2,140 mi · 6 time zones · 1 sunset from the cockpit". The day comes from the status, as in Stage 1's bar, and zeros are left out.
- **The footer:** "Estimated from the schedule", and the weather attribution when a weather line shows (§7.2).

### 5.3 On a layover

1. **"In Cologne"**, then "6 hours ahead of you · sunrise at 7:02 AM there".
   - The next ground sunrise or sunset at the airport, from `SolarPosition`, in its time zone.
   - Without a time zone, the second line is left out.
2. **"Next: Dubai, tomorrow 6:10 AM"** (Stage 1's chip), then "2,980 mi, like driving coast to coast · lands 4:05 PM there · 86°F and sunny on landing".
   - "there" is dropped when Dubai keeps the family's time.
   - The weather is shown when the flight lands within 48 hours.
3. **"Trip so far"**, then the totals, as in §5.2.

While a drive is under way, the rows are the trip so far only.

### 5.4 At home before a trip

1. **"Leaves Friday 6:10 AM"**, then "UPS 207 to Cologne · 48°F and rain on landing". The weather shows when the first flight lands within 48 hours.
2. **"The trip ahead"**, then "4 days · Cologne, Dubai · 9,800 mi · like driving the Alaska Highway 7 times" (9,800 over 1,390 is 7.05).
3. **"On the way"**, then "8 time zones · about 2 sunsets from the cockpit". The row is left out when both are zero.

### 5.5 The recap

- **Before the trip's end,** the timeline is mid-trip, and the sheet reads as §5.1 or §5.3 did then.
- **At or after the end:**
  - the rows are "The trip" (as in §5.4's "The trip ahead"), "On the way" without "about", and "Longest flight: Dubai → Louisville, 7,640 mi";
  - dragged up, "Trip recap" lists every flight's milestones, then the totals.

## 6. The views (app)

`Views/TripMap/`. Small views, each under ~300 lines, with Dynamic Type, Dark Mode and VoiceOver from the start.

### 6.1 The iPhone sheet, `FactsSheet`

- **It's SwiftUI's sheet,** presented from `TripMapScreen` while the screen isn't using the side panel. Turning the phone to landscape dismisses it and shows the panel. Turning back presents it again at the small stop.
- **Three stops:**
  - a custom detent measured to fit `FactsHeader`, so it grows with Dynamic Type;
  - `.medium`;
  - `.large`.
- **Behavior:**
  - `presentationBackgroundInteraction(.enabled(upThrough: .medium))` keeps the map usable;
  - `interactiveDismissDisabled()` keeps the sheet from being swiped away;
  - the drag indicator is visible;
  - iOS 26's glass sheet background is used unchanged.
- **The sheet reports its height** (`onGeometryChange`). The map takes it as bottom safe-area padding, so the camera frames the plane above the sheet.
- **Close** dismisses the full-screen map with the sheet up. Todd checks this on the simulator.

### 6.2 The side panel, `FactsPanel`

- It's used on iPad, and on iPhone in landscape: where Stage 1 floated its panel.
- **Shape:** full height at the leading edge, about 380 pt wide, on glass.
- **Contents:** `FactsHeader` at the top, the rows in a `ScrollView`, and the timeline pinned at the bottom.
- **The chevron** collapses it to the headline and timeline. Its label is "Hide facts" or "Show facts".
- **The map** takes the panel's width as leading safe-area padding.

### 6.3 Shared parts

- **`FactsHeader`:** the headline, and Stage 1's `TripTimelineControl`.
- **`FactRow`:** an SF Symbol, a title and a second line in `.secondary`. VoiceOver reads it as one element, one sentence. The symbols:
  - below: `mappin.and.ellipse`;
  - sky: `sunset.fill`, `sunrise.fill` or `moon.stars.fill`;
  - distance: `point.topleft.down.to.point.bottomright.curvepath`;
  - headed: `airplane.arrival`;
  - next flight: `airplane.departure`;
  - where they are: `mappin.and.ellipse`;
  - trip ahead: `globe.americas.fill`;
  - on the way and trip so far: `chart.bar.fill`;
  - longest flight: `arrow.left.and.right`.
- **`TripSoFarList`:** the tall stop (§5.2).
- **The footer:** "Estimated from the schedule", and `WeatherAttributionView` when weather shows.

### 6.4 The card

- **In flight,** the bottom chip is the headline (§4.4).
- **VoiceOver:** "UPS 207 to Cologne, over Newfoundland. Lands at 3:30 PM your time. Estimated from the schedule."
- **On the ground,** nothing changes from Stage 1.

### 6.5 The recap card

- **The map:** every leg drawn as flown, with the heart at home.
- **The chips:**
  - "Home from 4 days away" at the top, or "Home from a day away";
  - "Replay the trip", with `play.fill`, at the bottom.
  - The chips are labels: the whole card is the button.
- **`TripRecapBar`:** up to four tiles (cities, miles, time zones, "sunsets aloft"), with zeros left out, and the longest flight underneath.
  - "Sunsets aloft" is used only in the tile. Everywhere else it's "sunsets from the cockpit".
  - At accessibility text sizes the tiles stack, as Stage 1's bar does.
- **VoiceOver** reads one sentence: "Trip recap: home from 4 days away. 2 cities, 9,800 miles, 18 time zones, 2 sunsets from the cockpit. Longest flight, Dubai to Louisville, 7,640 miles." The hint: "Opens the map to replay the trip".
- **Tapping it** opens the full-screen map paused at the trip's start. Live jumps to now, after the trip, and the pill reads "Trip recap".

## 7. Weather on landing

### 7.1 Fetching

- **The call:** `WeatherService.landingForecast(forAirport:latitude:longitude:at:)` asks WeatherKit for one hour, with `.hourly(startDate:endDate:)`: the hour holding the landing time.
- **The answer** is a temperature, formatted as today's current weather is, and the condition's description.
- **Caching:** by airport and hour, for 30 minutes.
- **Failures** are logged and give nil.

### 7.2 Showing it

- **Which flights:** the flight in the air now, and the next flight when it lands within 48 hours of now.
- **Where:** the rows only, never the card. So the weather is fetched only while the full-screen map is open.
- **`LandingWeather`** fetches when the screen opens, and every 30 minutes while it's open.
- **Attribution:** Apple requires the  Weather mark and its legal link wherever WeatherKit data shows. The sheet and the panel show `WeatherAttributionView` whenever a weather line is showing.

### 7.3 In replay

Weather shows for a flight only when its landing is between the real now and 48 hours after it, whatever moment the timeline shows. A forecast can't describe a landing that's already happened.

## 8. The recap

### 8.1 When

In `TripMap+Status`, when the pilot is settled at home or base:

- **The recap's trip** is the one (by `tripId`) whose last leg ended in the past 24 hours, and none of whose legs is still to come.
- **The next trip wins instead** when its first departure is within 12 hours.
- **Legs with no `tripId`,** like a standalone jumpseat, aren't a trip.
- **"Home from 4 days away"** uses the largest `tripTotalDays` among the legs, else the calendar days the trip spans.

### 8.2 What it draws

- `TripMapDrawing` at any moment after the trip's end draws every leg as flown.
- In `.recap` the heart is at home when home is known, else at the last arrival.

## 9. The data files

`Crewluv/Resources/TripMap/`, in the app target only (not `CrewluveAlerts`). The website keeps copies in `public/data/`.

### 9.1 `geography.json`

```json
{"source": "Natural Earth 1:50m and 1:10m, v5.1.2, public domain",
 "areas": [{"name": "Kansas", "kind": "state", "country": "the United States", "box": [-102.05, 36.99, -94.59, 40.0],
            "rings": [[-102.05, 40.0, -95.31, 40.0, ...], ...]}],
 "cities": [{"name": "Montréal", "lat": 45.5, "lon": -73.57}]}
```

- **`kind`** is `state`, `province`, `country` or `water`.
  - States and provinces carry their `country`.
  - `box` is west, south, east, north.
  - A ring is a flat list of longitude, latitude pairs.
- **Names carry their article** from a table in the script: "the United States", "the Netherlands", "the Labrador Sea".
  - Oceans are shortened: "North Atlantic Ocean" becomes "the Atlantic".
  - Otherwise names are Natural Earth's English names.
- **`scripts/build-geography.mjs`** builds it. It runs on plain Node, with no npm packages.
  - **It reads** four files from `nvkelso/natural-earth-vector` v5.1.2 (GeoJSON), saved under `scripts/` and kept out of git:
    - `ne_50m_admin_0_countries`;
    - `ne_50m_admin_1_states_provinces`, keeping the US and Canada;
    - `ne_50m_geography_marine_polys`;
    - `ne_10m_populated_places_simple`, keeping places with a `pop_max` of 1 million or more.
  - **It simplifies** each ring with its own Douglas–Peucker, raising the tolerance until the file is about 500 KB or less. It rounds coordinates to 2 decimals, about 1 km.
  - **It prints** the counts and the size.
- **Downloading the four files** has Todd's OK. The plan still stops to say it's about to.

### 9.2 `comparisons.json`

`[{"miles": 26.2, "one": "Like running a marathon", "many": "Like running {n} marathons"}, …]`

In `many`, `{n}` is the number, and `{times}` is "twice" for 2 or "3 times" from 3 up.

| Miles | `one` | `many` |
|---|---|---|
| 26.2 | Like running a marathon | Like running {n} marathons |
| 51 | Like sailing the Panama Canal | Like sailing the Panama Canal {times} |
| 277 | Like rafting the Grand Canyon | Like rafting the Grand Canyon {times} |
| 880 | Like driving across Texas | Like driving across Texas {times} |
| 1,390 | Like driving the Alaska Highway | Like driving the Alaska Highway {times} |
| 2,340 | Like floating down the Mississippi | Like floating down the Mississippi {times} |
| 2,800 | Like driving coast to coast | Like driving coast to coast {times} |
| 4,130 | Like sailing the length of the Nile | Like sailing the length of the Nile {times} |
| 5,500 | Like walking the Great Wall of China | Like walking the Great Wall of China {times} |
| 7,918 | Like digging straight through the Earth | Like digging straight through the Earth {times} |
| 24,901 | Like going once around the Earth | Like going around the Earth {times} |

## 10. The website (Stage 2B)

Planned once Stage 1B is merged. It mirrors the app:

- **`src/facts/`:** the engine in TypeScript, held to the shared cases (§12.1).
- **`public/data/`:**
  - copies of `geography.json` and `comparisons.json`;
  - `geography.json` is fetched from the site itself, only while a flight is in the air or the map page is open.
  - The Content-Security-Policy is unchanged.
- **The moon** comes from `crewlu-globe`'s `subLunarPoint`, with the site's own `moonPhase`.
- **Weather** comes from Open-Meteo's hourly forecast, which the site already uses and credits, under §7's rules.
- **The card:** the headline chip in flight, and the recap card.
- **The map page:**
  - at 900 px or wider, the collapsible side panel;
  - below that, a bottom panel whose "More facts" button opens the rows and the trip so far, scrolling inside it, and "Fewer facts" closes it.
- **The camera's fit** allows for the panel. That closes 1B's "left for later" note about the wide panel.

## 11. What can go wrong

- **No geography:** this can't happen with a bundled file. If it does, it's logged, and the facts go on without places: no "below" row, and the only milestones are halfway and closest to home.
- **A story not ready yet:** the facts that need it are left out, and the chip is Stage 1's.
- **An unknown airport:** there's no map leg, so no story (map spec §12).
- **An unknown time zone:** that flight adds no time-zone fact, and the time difference and "there" times are left out.
- **No airborne window** (a block of 0 or less): no story or sky facts for that leg.
- **Weather fails or is out of range:** the line is left out, and the failure is logged.
- **The date line and the poles:**
  - the story works on the sphere;
  - the geography is split at the date line;
  - Stage 1 already draws near-polar paths clamped.

## 12. Testing

### 12.1 The shared cases

`CrewluvTests/Fixtures/TripMap/facts-cases.json`, with the website's copy in `tests/fixtures/trip-map/` (map spec §15.1). They cover:

- places and nearby cities at given points, against the real `geography.json`;
- each test leg's milestones, as kind, place and time;
- each test leg's cockpit sun events, including the people below;
- the moon's phase at given moments;
- comparisons for given distances;
- totals for given trips;
- the headline's exact words at given moments, in `en_US` and `America/New_York`.

Times match to within a minute, since Swift and TypeScript round differently.

### 12.2 Crewluve

XCTest, run in Xcode by Todd. It covers:

- every pure unit in §3.1;
- `FlightProgress`'s inverse;
- `TripReplayClock` starting paused;
- choosing the recap in `TripMap+Status`, including a night at home mid-trip and a next trip within 12 hours;
- which flights get weather (the 48-hour rule, and replay);
- the bundled files: both decode, and `geography.json` holds Kansas, Ontario, Germany, the Labrador Sea and Montréal.

Views are checked on the simulator: the sheet's stops, Close with the sheet up, the side panel, the recap card, the largest text size, and Dark Mode.

### 12.3 Website

vitest on the shared cases. The panels are checked by eye in the demo scenes.

## 13. Accessibility

- **Rows:** each is one sentence.
- **The chevron and "More facts":** labelled buttons.
- **The small stop** grows with Dynamic Type. At the largest sizes the card's chip moves below the map, as in Stage 1.
- **The recap bar** is one element.
- **Reduce Motion:** as Stage 1.

## 14. Not in this design

- **Milestone alerts.** A "Closest to home, wave!" alert is an idea for after Stage 3, once live data makes its timing right.
- **Milestones from one water into another.**
- **Weather on the card,** or beyond 48 hours.
- **The moon's parallax,** and chasing the sun at night.
- **Sharing the recap** as an image (map spec §16).

## 15. The plans

1. **Stage 2A, the app:**
   - the script and data files;
   - the engine and the shared cases;
   - weather;
   - the sheet, the side panel, the card's chip and the recap.

   It's written now, in `docs/superpowers/plans/`.
2. **Stage 2B, the website:** written after Stage 1B is merged.

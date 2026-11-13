# Crewluve Moving Map: The Trip Map, Its Facts, and the Real Plane

Status: approved in brainstorming on 2026-11-13, from mockups of where the map lives, the card in each trip state, the full-screen map, the ghost and live planes, and the live-data relay. It covers the Crewluve app, the Crewluve website, and one new piece of CrewLu Cloud. It's built in three stages (§4), each with its own implementation plan.

## 1. Goal

Give the pilot's family a moving map that's fun to look at, in the app and on the website. It's built from CrewLu's rebuilt moving map:

- **One map for the whole trip.** On the ground it shows every city on the trip and where the pilot sleeps tonight. In the air it follows the plane.
- **Facts for the family.** What's below the plane, the sun and moon from the cockpit, miles and milestones, and the weather where they're landing.
- **The real plane racing the schedule.** Where live data from adsb.lol is available, the real plane flies solid and the schedule flies beside it as a ghost. The family can see at a glance whether the flight is ahead or behind.

## 2. What's there now (checked 2026-11-13)

### 2.1 CrewLu's moving map

`Duty/Duty/Views/Map/`, reached from the globe button on CrewLu's graphical timeline.

- **Apple's map,** `MKMapView` in a `UIViewRepresentable`, in hybrid, standard or imagery styles, kept flat.
- **One great-circle line per leg,** coloured by state: flown, in progress, jumpseat, still to come.
- **Night as seven stacked shapes** at sun depths from 0° to 18°, each 7.5% navy, which gives a soft twilight edge (`Utils/NightShade.swift`).
- **The plane** points along its leg and turns between legs the short way round (`PlaneHeading.swift`).
- **A timeline** with play and pause, a slider, and 1x, 2x, 5x and 10x speeds. At 1x a day passes in 48 s.
- **The position comes from the schedule:** elapsed block time over the great circle. There's no live feed.
- **The pure parts have tests and no MapKit:** `SolarPosition` (subsolar point, sun altitude), `NightShade`, `PlaneHeading` and `FlatMapFit` (Web Mercator, date-line unwrapping).
- **One part isn't safe to copy:** the drawing view is slipped in among MapKit's own views, which Apple doesn't document.

### 2.2 Crewluve's map today

- **App:** `FlightRouteMapView.swift` (670 lines), drawn by hand in SwiftUI, 200 pt tall.
  - It shows one leg, a day or night sky gradient, two airport pins and a plane placed from the schedule and the delay, refreshed every 10 s.
  - It shows only in flight, in the location card's place.
  - The flight number opens `FlightTrackingPopupView` (FlightRadar24 and FlightAware).
- **Website:** `src/ui/FlightMap.tsx`, an SVG port of the app's map (slice 2C spec), with the same card and popup.

### 2.3 What families receive

- **Trip legs:** flight, turn, layover, home, base, drive, reserve, hot standby and event. Each has scheduled times, the delay, airports, cities, time zones, flight number and airline code.
- **The pilot's home and base airports,** and the current leg's `currentFlight*` fields.
- **Nothing live:** no aircraft type, tail number, altitude, speed or tracked position.
- **Airports:**
  - the app's `AirportDataProvider` has about 306, with no time zones;
  - the website's `public/data/airports.json` has 9,056, with time zones.

### 2.4 adsb.lol

A free, community-run ADS-B network. Volunteers' receivers hear each airliner's broadcast position, altitude, speed and callsign and share it openly. A pilot tester suggested it. It powers his kitchen display, which looks up his flight by callsign.

- **The lookup:** `https://api.adsb.lol/v2/callsign/{callsign}` gives position, barometric altitude, ground speed, track, registration (`r`) and ICAO type code (`t`) for each aircraft using that callsign.
- **No key is needed today.** The project says one will be needed "in the future", earned by feeding data. It asks for reasonable polling and limits by load.
- **The data is ODbL.** We credit "adsb.lol" wherever live data shows.
- **No CORS header,** checked 2026-11-13. A browser on crewluve.crewlu.net can't call it directly.
- **Gaps:**
  - no receivers mid-ocean, so a crossing goes dark for hours;
  - it sees touchdown, not gate arrival;
  - it's a volunteer project, with no guarantees.

## 3. Decisions (brainstorm, 2026-11-13)

1. **Both, one map.** The map shows the whole trip, zooms to the live leg while they're flying, and replays the trip with a timeline.
2. **All four kinds of facts:** what's below the plane, sky and sun, numbers and milestones, and where they're headed.
3. **A bigger card that opens full screen.** It goes in the location card's place on the status screen. No new tab, and no map behind the whole screen.
4. **Home is the pilot's home airport,** or base when home isn't set. There's no location permission.
5. **Approach 1:** Apple's map on both platforms, with live data relayed by CrewLu Cloud. iCloud families get the same map driven by the schedule.
6. **The schedule as a ghost.** It shows next to the real plane, so families can see whether the flight is ahead or behind.
7. **One landing time everywhere.** Once live data is in, its landing estimate drives the countdown and narrative cards too.
8. **No line about the destination city for now.** It would mean writing and checking about 300 airports' worth of content.
9. **Build in three stages:** the map, then the facts, then live (§4).

## 4. The parts

| Stage | Crewluve app | Website | CrewLu Cloud (`Duty/supabase`) |
|---|---|---|---|
| 1. The map, from the schedule | §5, §6, §7.1–§7.3 (schedule plane), §10 | §5, §6, §7.1–§7.3, §11 | nothing (§9.7) |
| 2. The facts | §8, §10 | §8, §11 | nothing |
| 3. Live | §7 (live plane, ghost, §7.4–§7.6), §10 | the same, §11 | `flight-live`, `live_flights`, `partner_live` (§9.1–§9.6) |

Stages 1 and 2 work for every family, iCloud included. Stage 3 adds live data for families on CrewLu Cloud. Each stage gets its own implementation plan and ships on its own.

## 5. The card

In flight it takes the location card's place. On the ground it sits just above the location card, which keeps its weather, local time, time difference, quick status and sun circle. Either way it's below the countdown and above the trip cards.

This was clarified while planning Stage 1 (2026-11-13). Replacing the whole location card on the ground would have dropped the weather and sun circle that families use today.

### 5.1 Its states

- **In flight:** the map zooms to the leg in progress.
  - The rest of the trip shows faintly for context.
  - The planes are drawn as §7 says.
  - The headline fact chip sits on the map (§5.2).
- **On the ground, mid-trip (layover, turn, base):**
  - the whole trip is shown, with legs flown solid and legs still to come dashed;
  - a heart pin marks where the pilot is;
  - two chips: the city with its local time ("Cologne · 9:14 pm there"), and the next departure ("Next: Dubai, tomorrow 6:10 am").
- **Home, with a trip ahead:** the next trip's route, every leg dashed, with the heart pin at home ("Home · next trip Friday").
- **Home, nothing ahead,** or no leg that can be drawn: no map. The card is today's location card.

### 5.2 The headline fact

One chip, chosen by priority. It doesn't rotate through facts. The priority:

1. a milestone from the last 5 minutes (§8.3);
2. a sunrise or sunset from the cockpit within 30 minutes;
3. what's below the plane;
4. the landing time.

The chip appears from Stage 2. In Stage 1, the in-flight chip shows the landing time.

### 5.3 The bar under the map

- **In flight:** the flight number as a button that opens the tracking popup (unchanged), and "Lands 3:30". In the middle: the ahead or behind label (§7.4) with live data, and "In flight" without it.
- **On the ground, mid-trip:** "Day 2 of 4", the number of cities, and miles so far.
- **Home, with a trip ahead:** the trip's dates, its cities, and its total miles.

### 5.4 Size and tap

- **The map is 220 pt tall.** Today's is 200 pt.
- **Tapping the card opens the full-screen map** (§6). The flight number button keeps opening the tracking popup.

## 6. The full-screen map

- **Opens on the leg in progress,** or on the whole trip when they're on the ground.
- **The map fills the screen.**
  - Top left: close.
  - Top right: a style button that cycles hybrid, standard and imagery, as in CrewLu. Hybrid is the default.
  - A recenter button appears once the map is panned away from the plane.
  - A pill at the top: "UPS 207 · 12 min ahead" with live data, and "UPS 207 · In flight" without it.
- **The facts sheet.** It's a bottom sheet with two stops.
  - Small: the headline fact, the landing line ("Lands Cologne 9:30 pm · 3:30 pm your time") and the timeline.
  - Pulled up: one row per kind of fact (§8), and the adsb.lol credit when live data shows.
  - On iPad, in landscape, and on the website at 900 px wide or more, the facts are a side panel instead.
- **The timeline** covers the trip from its first departure to its last arrival.
  - Drag it to replay, with play at 1x, 2x, 5x or 10x as in CrewLu.
  - A Live button jumps back to now.
  - Replay moves the planes and the night. Live data affects only the present (§7.6).
- **"Your time"** is the device's time zone, as the alerts already use.

## 7. The schedule and the real plane

### 7.1 Route lines

- **The planned route** of a leg is a great circle.
  - Its part still to come is dashed light blue.
  - With no live data, the part already flown is solid light blue.
- **The actual path** (live trail, §9.4) is solid white.
- **Legs flown earlier in the trip** are solid grey along their planned route.
- **Drives** are a dotted line with a small car, and never get live data.

### 7.2 The planes

- **Live plane:** a filled blue circle with a white border and a white plane, drawn on top.
- **Ghost:** a dashed white outline with a faint white plane, at the schedule's position. It's always shown when there's a live plane.
- **Schedule only:** one plane, a solid white outline with a white plane. With no live data it makes no claim of being on time: no ahead or behind label. The facts panel and VoiceOver say "Estimated from the schedule".
- **Turning:** each plane points along its path using CrewLu's `PlaneHeading`. Reduce Motion makes planes jump to position instead of sliding.

### 7.3 Where the ghost is

The ghost follows what Crewluve already promises: the scheduled times shifted by the pilot's reported delay (the effective times).

- **Before the effective departure plus taxi-out:** at the departure airport.
- **After the effective arrival minus taxi-in:** at the arrival airport.
- **In between:** at constant speed along the great circle.
- **If the block time is shorter than the two allowances plus 10 minutes,** the ghost moves the whole block at constant speed.
- **Constants:** `taxiOutAllowance` = 15 min and `taxiInAllowance` = 7 min. Both are written in the shared cases (§15.1).

### 7.4 Ahead or behind

- **Airborne:** the gap is the live plane's distance along the route minus the ghost's, divided by the live ground speed, in minutes.
  - Ahead is positive.
  - Within ±5 minutes, the label reads "On schedule".
  - Otherwise it reads "12 min ahead" or "20 min behind".
  - When the live plane is estimated (§7.5), it reads "About 12 min ahead".
- **Still on the ground at departure after the ghost has taken off:** "Still on the ground · 20 min behind", counted from the ghost's takeoff.
- **Landed:** "Landed 8 min early" or "Landed 15 min late", against the effective arrival minus taxi-in. Then the card hands over to the existing arrival celebration.
- **Before the ghost's takeoff, with the live plane on the ground:** no label.

### 7.5 Out of range

- A fix older than 2 minutes, measured with `partner_live`'s `now` (§9.5), makes the live plane estimated.
- **The estimated plane** keeps moving along the great circle from the last fix to the destination, at the last ground speed.
  - It's drawn at 60% opacity.
  - Its path from the last fix is dotted.
  - The trail ends where receivers lost it.
- **The chip** reads "Estimated · last seen near Gander", with the place from §8.1. Where §8.1 finds no place, it reads "Estimated · last seen 2 h ago".
- **A new fix** makes it live again.

### 7.6 The landing time, and one landing time everywhere

- **Live landing estimate:**
  - touchdown = now + (the remaining distance minus 120 nm) at the last ground speed + 120 nm at `approachSpeed` = 280 kt;
  - gate arrival = touchdown + `taxiInAllowance`.
  - Under 120 nm left, it uses `approachSpeed` alone.
  - The constants are in the shared cases.
- **One landing time:** while a live landing estimate exists, live or estimated, it is the arrival time across the status screen.
  - It's used by the map, the narrative card and the countdown card, read as "about 3:30".
  - Otherwise those use the effective schedule, as today.
- **Alerts stay schedule-based** in this design (§16).
- **Replay** uses the schedule for every time in the past. If a trail exists, it's drawn for the flown part.

## 8. The facts

The app and the website each have one pure facts engine, held to the same answers by shared cases (§15.1). Everything comes from the route, the clock, the sun, the moon, the bundled files (§8.7) and, where it exists, the live fix.

### 8.1 What's below the plane

- **The place:** the plane's position is looked up in `geography.json` on the device.
  - First, a US state or Canadian province: "Over Kansas".
  - Else a country: "Over Germany".
  - Else a named ocean or sea: "Over the Labrador Sea".
  - Else nothing.
- **Near a big city:** within 40 mi of a city of 1 million or more, the line adds "near Montréal".
- **Closest to home:** for a leg that doesn't start or end at home.
  - It counts if the leg's planned route passes within 100 mi of home.
  - When the plane reaches that closest point (live, estimated or schedule), it reads "Closest to home: 40 mi, wave!".
  - It fires once per leg.

### 8.2 Sky and sun

- **Sun:** `SolarPosition` gains CrewLu's subsolar point, and the sun's altitude is worked out along the plane's predicted path.
- **Sunrise or sunset from the cockpit:** the moment the sun crosses −(0.833° + horizon dip). The dip is about 1.76′ × √(height in m): about 3° at 35,000 ft.
  - Height is the live altitude when there is one, else 35,000 ft while the schedule has the plane airborne (§7.3).
  - It reads "Sunset from the cockpit in 25 min".
  - When the dip makes it 5 minutes or more later than at ground level below, the row adds "about 12 min after the people below".
- **Day or night:** "Flying into the night" or "Flying into the morning", when the next sun event is within the leg.
- **Moon:** its phase, and whether it's up at the plane, on the night side.
  - The website already has phase maths (`src/time/moon.ts`).
  - The moon's position comes from `crewlu-globe/src/astro`.
  - The app ports both.
- **Chasing the sun:** on a westbound leg where the sun's local hour angle at the plane moves at under half its usual rate: "Chasing the sun: their afternoon is stretching".

### 8.3 Numbers and milestones

- **Distance:** "2,140 mi flown · 1,960 to go".
  - Flown is along the trail when live, else along the planned route.
  - Miles are statute miles, as families think in.
- **Speed and height:**
  - live: "35,000 ft · 540 mph";
  - schedule only: "Averaging about 510 mph", the planned distance over the time between the allowances.
- **The plane:** live only, "Boeing 767-300 · N370UP", from `AircraftTypeNames`. An unknown type code shows the code itself.
- **Halfway:** "Halfway at 4:12 pm", or "Halfway!" as a milestone when it happens.
- **Comparisons:** "Like driving coast to coast", from `comparisons.json`.
  - The pick is the entry whose multiple of the leg's distance is closest to a whole number between 1 and 10. Ties go to the smaller multiple.
- **Milestones:** "Just crossed into Germany" (a new country, state or province), "Out over the Atlantic" (onto a named ocean or sea), "Halfway!" and "Closest to home".
  - Each leads the chip for 5 minutes.
  - The facts panel lists earlier ones: "Crossed into Canada at 1:12 pm".
- **Trip totals:** cities, miles, time zones crossed and sunsets from the cockpit.
  - Time zones crossed is the sum, over flight legs, of the change in UTC offset between departure and arrival, in whole hours.

### 8.4 Where they're headed

- **"Cologne: 48°F and rain on landing."** It's the hourly forecast at the landing time (§7.6): WeatherKit in the app, Open-Meteo on the website, as each already uses. Past the forecast's range, the row leaves weather out.
- **"9:30 pm there · 6 hours ahead of you."**

### 8.5 The trip recap

For 24 hours after the trip's last leg reaches home, the card shows a recap: cities, miles, time zones crossed, sunsets from the cockpit and the longest leg. It sits beside the existing celebration.

### 8.6 The facts panel rows

In order, each one a sentence for VoiceOver:

1. what's below, plus closest to home;
2. the plane (live only);
3. sky and sun;
4. distance, halfway and comparison;
5. where they're headed.

A row with nothing to say is left out.

### 8.7 The data files

They're made by scripts, the way `airports.json` is today, and bundled in the app and on the website:

- **`geography.json`:**
  - countries, US states and Canadian provinces, named oceans and seas, and cities of 1 million or more;
  - taken from Natural Earth (public domain, 1:50m);
  - simplified to about 500 KB or less.
- **`comparisons.json`:** a short curated list, such as coast to coast, the Mississippi's length and once around the Earth, each with a distance in statute miles.
- **`AircraftTypeNames`:** a small table in code. It covers each airline's fleet that CrewLu pilots fly, plus the common passenger types for deadheads.

## 9. CrewLu Cloud (`Duty/supabase`)

### 9.1 The watch list

Every 30 seconds, pg_cron drives the edge function `flight-live`, the same way `partner-push` is driven. Each run, it:

- reads the latest summary of every pilot with at least one partner device;
- picks flight legs, deadheads included, whose **window** is open. The window runs from 30 minutes before the effective departure to the first of two moments: landing seen, or 2 hours after the effective arrival;
- builds each leg's **callsign**:
  - the airline's ICAO prefix, from the flight number's prefix through a server-side IATA → ICAO table (today's 15 airlines, and more);
  - then the number without leading zeros: UPS0207 → UPS207;
- keys each leg as callsign + departure airport + scheduled departure. A captain and first officer on the same flight share one key and one row.

At today's scale reading every summary each run is fine. If it grows, keep an index of upcoming windows instead.

### 9.2 Each run

- **Polling:** each open row is polled when due. That's every 60 s before a fix shows it airborne, and every 30 s while airborne. It stops once landing is seen.
- **Pacing:** at most 4 requests at a time, with a 10 s timeout each. The `User-Agent` names CrewLu Cloud.
- **A good answer:** after the match check (§9.3), the row's fix is updated and a trail point is added.
- **Landing seen:** the first fix on the ground at the arrival airport after one airborne.

### 9.3 The match check

A fix is kept only when it's within 250 nm of the leg's planned great circle, or within 10 nm of either airport, inside the window. Anything else is dropped and logged. Two things can't then hijack the map:

- a reused flight number on another plane;
- a fix for a different leg with the same number.

### 9.4 What it keeps

`private.live_flights`, one row per key:

- the leg: callsign, airports, scheduled departure, window;
- `state`: `waiting`, `ground`, `airborne`, `landed` or `lost`. Lost means 3 failed polls in a row;
- the latest fix: latitude, longitude, altitude in feet (null on the ground), ground speed in knots, track in degrees, registration, type code, and when it was seen. Seen time is the poll time minus adsb.lol's `seen_pos`;
- the trail: a point about every 2 minutes, `[time, latitude, longitude, altitude]`;
- bookkeeping: `polled_at`, `next_poll_at`, `failures`.

Only public ADS-B data is stored. Rows are deleted 24 hours after landing is seen, or 24 hours after the window closes without it.

### 9.5 `partner_live`

A new partner RPC beside `partner_view`. `partner_view` and its `unchanged` shortcut don't change.

- **Parameters:** `p_key`.
- **Answer:**

  ```json
  {"now": <ms>, "flights": [{"departure", "arrival", "scheduledDeparture", "flightNumber", "callsign",
     "state", "fix": {"lat", "lon", "altitudeFt", "groundSpeedKt", "trackDeg", "registration", "typeCode", "seenAt"} | null,
     "trail": [[ms, lat, lon, ft], ...]}]}
  ```

  - `flights` holds only that partner's pilot's legs in the current summary that have a row.
  - `now` is the server's clock, which clients measure fix ages against.
- **Errors:** the same as `partner_view`, including `sharing_ended`.
- **When clients call it:** every 30 s, only while a leg's window is open (they work it out from the legs, with §9.1's rule) and the screen is in front. The app doesn't poll in the background. Silent pushes and alert pushes stay as they are.
- `partner-api.md` gains its row and rules.

### 9.6 Failures

- **A timeout or error:** keeps the last fix and counts a failure. After 3 in a row the row goes `lost`, and is polled every 2 minutes until the window closes.
- **A 429:** backs off every row for 2 minutes.
- **If adsb.lol starts needing a key:** it goes in the function's secrets. Nothing ships in an app.
- **If adsb.lol is gone for good:** turning `flight-live` off leaves every family on the schedule, with nothing else broken.

### 9.7 No `mapkit-token` (decided 2026-11-13, planning Stage 1B)

The website draws its own map (§11), so it needs no MapKit JS token, and CrewLu Cloud gains no function in Stage 1.

MapKit JS would have needed the site's Content-Security-Policy loosened:
- Apple's script, running in the page that holds the device key;
- Apple's servers added for connections and images;
- inline styles allowed;
- blob workers allowed.

The site's policy is deliberately tight. It allows its own scripts only, and connections to just the four partner door addresses and Open-Meteo.

## 10. The app

iOS 17, SwiftUI, and the project's rules: one type per file, under ~300 lines each.

- **The map is SwiftUI's `Map`,** not a port of CrewLu's `MKMapView`. It covers everything with public API:
  - `.mapStyle(.hybrid(elevation: .flat))`, `.standard` and `.imagery`;
  - `MapPolyline` for routes, trails and drives;
  - `MapPolygon` for the night bands;
  - `Annotation` for the planes and the heart pin;
  - `MapCameraPosition` for fitting.
- **Ported from CrewLu, with their tests:** `NightShade`, `PlaneHeading`, the subsolar point in `SolarPosition`, and the date-line fit from `FlatMapFit`. Night refreshes about 10 times a second during replay, and once a minute otherwise.
- **`Views/TripMap/`:** `TripMapCard`, `TripMapScreen`, `TripMapView` (the `Map` and its content), `FactsSheet`, `TripTimeline`, `HeadlineFactChip`, `TripRecapView`, and their small subviews.
- **`Services/TripMap/`:**
  - `TripRoute`: legs to drawable routes, using `AirportDataProvider`.
  - `FlightProgress`: the ghost, live and estimated positions, ahead or behind, and the landing estimate (§7).
  - `LiveFlightSource`, an `@Observable` `@MainActor` model. It calls `partner_live` (§9.5) through the partner door's client.
  - The facts engine: `GeographyLookup`, `SkyFacts`, `TripDistances`, `MilestoneDetector` and `ComparisonPicker`.
  - `AircraftTypeNames`.
- **Bundled:** `geography.json` and `comparisons.json`.
- **One landing time:** `FlightProgress`'s landing estimate reaches the narrative and countdown cards through the status screen's model, so no card works it out itself.
- **`FlightRouteMapView` is deleted** once the card replaces it. `FlightTrackingHelper` stays for the popup, and gains leading-zero stripping.
- **Weather on landing** uses the app's WeatherKit service.

## 11. The website

- **The site draws the map itself in SVG,** as its in-flight map already does, with no map service and no third-party code. The Content-Security-Policy is unchanged (§9.7). The drawing:
  - a simple world: land outlines from a small bundled Natural Earth file (public domain, 1:110m) on an ocean colour, in Web Mercator clipped at ±85°, like the app's map;
  - routes as great circles split into 101 points;
  - night as `NightShade`'s seven layers ported to TypeScript, filled the same way;
  - the planes, the heart pin and the airport dots as SVG marks;
  - the camera as `MapFit` ported: the leg or the trip, the short way across the date line.
- **Not Apple's satellite look,** and the full-screen map doesn't pan or zoom in Stage 1. It fits the leg or the trip, as the card does, and follows the replay from leg to leg.
- **`src/map/`:** the card, and the full-screen page at `#map`. Back and Escape close it.
- **`src/facts/`:** the TypeScript facts engine and `flightProgress.ts`, matching §7 and §8.
- **`src/partner/live.ts`:** `partner_live` polling while the page is visible and a window is open.
- **`public/data/`:** `geography.json` and `comparisons.json`, from the same scripts.
- **Engine:** `src/engine/` uses the landing estimate for one landing time (§7.6).
- **Removed:** `FlightMap.tsx`, `flightMapGeometry.ts` and `flightSky.ts`.
- **Demo scenes:** Stage 1 uses the existing ones, which already show every state: `flying`, `layover`, `home`, `delayed` and `driving-home`. Stage 3 adds `live-ahead`, `live-ocean-gap`, `live-on-ground-late` and `schedule-only`, with recorded live data.

## 12. What can go wrong

- **Unknown airport:** a leg with an airport missing from the platform's list isn't drawn. If that's the leg in the air, the card shows today's fallback ("SDF → CGN"). The app has about 306 airports and the website 9,056, so the app hits this more often (§16).
- **No legs** (CrewLu versions that don't send them): the map draws only the current leg, from `currentFlight*`. On the ground with no legs, there's no map.
- **The date line, and polar or long legs:** these are handled by the ported date-line fit and geodesic lines. Web Mercator stops at ±85°, so near-polar paths are drawn clamped.
- **Diversion:** the live plane stays while it's within 250 nm of the route. Beyond that, fixes are dropped and it goes estimated. It never shows a wrong position.
- **The same flight number on back-to-back legs:** the window and the match check pick the right leg.
- **A wrong phone clock:** fix ages use `partner_live`'s `now`.
- **A reported delay that disagrees with live data:** live wins for the landing time. The ghost keeps the effective schedule.
- **adsb.lol down, slow or gone:** families see the schedule plane (§9.6).

## 13. Security and privacy

- **What's stored and served:** only public ADS-B data, for flights already in the pilot's summary.
- **What partners see:** only their own pilot's flights, through their device key. A key that's been let go gets `sharing_ended`.
- **What adsb.lol and Apple see:** only callsigns. No partner or pilot detail is sent to adsb.lol. In the app, Apple sees only MapKit's own map requests.
- **The website loads no third-party code for the map** (§9.7). Its Content-Security-Policy is unchanged, so the device key in its local storage is no more exposed than before.
- **Logs** show callsigns and leg keys, never device keys.

## 14. Accessibility

- **The card** is one VoiceOver element, read as a sentence: "UPS 207 to Cologne, 12 minutes ahead of schedule, over Newfoundland. Lands about 3:30 pm."
- **Each facts row** is a sentence.
- **The timeline slider** reads its time as its value.
- **The buttons** have labels: close, map style, recenter, Live, play.
- **Dynamic Type:** the chips and rows scale. At the largest sizes the headline chip moves below the map.
- **Dark Mode:** the card's frame and the sheet adapt. Hybrid and imagery look the same in both, and standard follows the system.
- **Reduce Motion:** planes don't slide (§7.2). Replay still works, without animated camera moves.
- **The website** follows the same rules: the card is `role="img"` with the same sentence, the rows are text, and the controls are labelled buttons.

## 15. Testing

### 15.1 The shared cases

`CrewluvTests/Fixtures/TripMap/`:

- `progress-cases.json`: the ghost's timing, the allowances, the ±5 min band, ahead or behind, still on the ground, landed early or late, estimated movement and the landing estimate.
- `facts-cases.json`: the geography lookup at given points, sunrise or sunset from the cockpit with the dip, milestones, comparisons and trip totals.

The website keeps a copy in `tests/fixtures/trip-map/`. Both suites run every case. A change goes into both copies in the same pair of commits.

### 15.2 Crewluve

XCTest, run in Xcode by Todd. It covers:

- the ported maths, with CrewLu's tests: `NightShade`, `PlaneHeading`, subsolar point, date-line fit;
- `FlightProgress` and the facts engine, through the shared cases;
- `TripRoute`: legs, drives, unknown airports;
- `LiveFlightSource`: when it polls, `sharing_ended`, a stale fix;
- `AircraftTypeNames`, and leading-zero stripping;
- one landing time: the narrative and countdown cards with and without a live estimate.

### 15.3 Website

vitest on the shared cases, live polling, and the engine's landing time. The demo scenes are checked by eye.

### 15.4 CrewLu Cloud

- **SQL tests** in `Duty/supabase/tests`: `partner_live` answers only the partner's own pilot's flights, `sharing_ended`, and row cleanup.
- **Function tests** on recorded adsb.lol answers, never live calls:
  - callsign building;
  - the window;
  - the match check, including a reused flight number and a diversion;
  - landing seen;
  - failures, `lost` and the 429 back-off.

### 15.5 On real flights

After Stage 3, follow one real flight from gate to gate, preferably transatlantic so the ocean gap shows, in the app and on the website side by side.

## 16. Not in this design

- **"Landed, for real" alert pushes** driven by live data.
- **A line about each destination city** (decision 8).
- **The app reading the website's 9,056-airport file** instead of its own list.
- **Location permission** for an exact home (decision 4).
- **Live data for iCloud families** (decision 5).
- **Sharing the trip recap as an image or video.** `crewlu-globe` has the pieces for later.
- **CrewLu's own moving map using live data.**

## 17. The plans

1. **Stage 1, the map, from the schedule:** the app's `Views/TripMap/` and `TripRoute` and the ported maths (plan 1A), and the website's self-drawn `src/map/` (plan 1B).
2. **Stage 2, the facts:** the data files and scripts, the facts engines in Swift and TypeScript, the shared cases, the chip, the sheet's rows and the recap.
3. **Stage 3, live:** `flight-live`, `live_flights` and `partner_live` in `Duty/supabase`, then `LiveFlightSource` and the website's `live.ts`, the ghost and live planes, and one landing time.

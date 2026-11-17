# Crewluve Moving Map, Stage 3: The Real Plane

Status: approved in brainstorming on 2026-11-14, from mockups of the two planes on the card, the real path beside the great circle, the label beside the landing time, the facts sheet with the plane's row, and the relay. It refines the moving map spec (`2026-11-13-crewluve-moving-map-design.md`) §5.2, §5.3, §6, §7, §8, §9, §10, §11, §12 and §15. Where they differ, this wins. It covers one new piece of CrewLu Cloud, the Crewluve app and the Crewluve website, each with its own implementation plan (§19).

## 1. Goal

Where adsb.lol can see the pilot's flight, the family sees the real plane: where it really is, the path it really flew, and when it will really land. The schedule flies beside it as a ghost, so they can see at a glance whether the flight is ahead or behind.

Families on iCloud, and flights adsb.lol can't see, keep today's map from the schedule.

## 2. What's there now (checked 2026-11-14)

### 2.1 adsb.lol

- **One request can ask for many callsigns.** `https://api.adsb.lol/v2/callsign/FDX147,FDX131,UPS207` answered with the two that were flying. The moving map spec assumed one request per flight.
- **The answer** is `{"ac": [...], "now": <ms>, ...}`. Each aircraft has:
  - `hex`, the airframe's 24-bit address, which doesn't change during a flight;
  - `flight`, the callsign padded with spaces to 8 characters;
  - `r` (registration) and `t` (ICAO type code);
  - `lat` and `lon`, and `seen_pos`, the position's age in seconds;
  - `alt_baro`, in feet, or the string `"ground"`;
  - `gs` (knots) and `track` (degrees). `track` can be missing on the ground.
- **Still no CORS header and no key.** A callsign nobody is broadcasting is simply absent from `ac`.
- **It counts requests by the clock's minute** (found on the first real flight, 15 Nov 2026). What it allows is shared with others who call it from the same addresses. A request in a minute's first ten seconds was never refused (0 of 52), and one in its last ten usually was (21 of 30). A 429's `Retry-After` was the seconds left in the minute.
- **It has no receivers over parts of northern Canada.** The same flight went unseen for 52 minutes there, 433 nm of its path.

### 2.2 The map and the facts (Stages 1 and 2, merged)

- **The app** draws on `MKMapView`: the night and the lines are the app's own `CAShapeLayer`s, and the markers are annotations (`Views/TripMap/`).
- **The website** draws on Apple's map too (MapKit JS), with its own SVG map as the fallback. Its Content-Security-Policy is built from the list of partner-door calls it allows (`DOOR_RPCS` in `src/partner/doorGuard.ts`), so adding a call to that list allows it.
- **A leg is a great circle.** `MapLeg` places the plane by `FlightProgress.scheduledFraction`: at the departure airport for 15 minutes, then one steady speed, landing 7 minutes before the gate arrival.
- **The facts** work out each flight's story once, along that great circle: the places below, the crossings and the closest point to home, as fractions of the way along (`LegStory`). The schedule turns a fraction into a time.
- **The status screen** reads the trip's legs through `TripStateResolver` (the app) and `src/engine/` (the website). A flight's arrival is its scheduled time moved by the pilot's reported delay: the effective arrival.

### 2.3 CrewLu Cloud

- **`partner-push`** is the pattern: pg_cron runs a check in SQL, which calls an Edge Function through pg_net with a password from the Vault. The function claims its work with one RPC and reports with another. It's one file with no imports, tested under Node with stand-ins for fetch.
- **A summary's flight leg** has `id`, `type`, `startTime`, `endTime`, `flightNumber`, `airlineCode`, `departureAirport`, `arrivalAirport` and `delayMinutes`. CrewLu writes a company flight's number as "UPS" and the digits, and another airline's as its code and the digits. A leg by van or bus is a flight leg numbered `GND`.
- **CrewLu Cloud has no airport positions.**

## 3. Decisions (brainstorm, 2026-11-14)

1. **The picture is the moving map spec's:** two planes, the path flown, a label and one landing time.
2. **The real path replaces the great circle** for a flight with live data: on the map, in the facts and under the ghost. Real routes can be hundreds of miles from the great circle, so the facts would otherwise name places the plane never crossed.
3. **The landing estimate is anchored on the takeoff,** and flies the rest at the plane's own speed once that's known. The takeoff time is what moves a landing most.
   - The brainstorm had it fly the schedule's speed throughout, taking the schedule's flight time to have the usual winds built in. The first real flight (15 Nov 2026) left about 35 minutes late and landed on time: its schedule's flight time comes to 423 kt, and it flew 450 to over 500. The estimate ran 37 minutes late at the start and 20 in the middle.
   - With the plane's own speed over its cruise so far, the same flight's estimate is 16 minutes late when the speed is first known, half an hour after it was first seen, 6 by the middle, and within 5 from there to its descent. Todd chose this on 15 Nov 2026.
4. **The ghost flies the same plan,** at the plane's own speed too, so the gap between the planes, the label and the landing time always agree. The words stay "12 min ahead", "20 min behind" and "On schedule".
5. **The real path is kept for the whole trip and its recap,** so the replay, "Trip so far" and the recap show where the plane really went.
6. **One landing time moves the whole status screen.** It stays "in flight" until the real plane arrives, and arrives early when it does.
7. **One request per run** covers every pilot's flight.
8. **A fix is matched by following the aircraft,** not by a corridor around the great circle.
9. **A switch** turns the relay on for nobody, for listed pilots, or for everyone.

## 4. The schedule's flight plan

Everything in §5 measures the real plane against one plan, made from the leg's effective times and the great-circle distance between its airports, `L`.

- **Takeoff and touchdown** are Stage 1's: the effective departure plus `taxiOutAllowance` (15 min), and the effective arrival minus `taxiInAllowance` (7 min). A block shorter than both plus `shortestCruise` (10 min) has neither allowance. The time between them is the plan's time in the air, `A`.
- **The descent:** the last `descentDistance` (120 nm) is flown at `descentSpeed` (280 kt), which takes 25.7 minutes.
- **The cruise:** everything before that is flown at one speed, `(L − 120 nm) ÷ (A − 25.7 min)`.
- **A short leg has one steady speed,** `L ÷ A`, when `L` is 120 nm or less, when `A` is 25.7 minutes or less, or when the cruise speed above would be 280 kt or less.
- **Two answers come from it:**
  - `timeToFly(distance)`: how long an on-schedule plane needs to fly `distance` to touchdown;
  - `distanceLeft(time)`: how far from touchdown an on-schedule plane is, `time` before it. It's the first one's inverse.
  - Both work for a distance greater than `L`: the extra is flown at the cruise speed, or at a short leg's steady speed.
- **The plan as the plane flies it** has the plane's own speed in place of the cruise speed, once that's known. Its takeoff and touchdown stay the schedule's, and so does the descent.
  - **The plane's own speed** is the distance it flew along its path (§6) over the time it took, counted over its cruise: each stretch between two neighbouring places that were both seen 120 nm or more from both airports, in a straight line. That leaves out the climb and the descent. A hold or a pattern near the arrival airport can't bring its places in, and neither can a return to the departure airport and the wait there.
  - It's known once those stretches come to 10 minutes or more. A stretch nobody saw counts, as its straight join, when both its ends are in the cruise.
  - `timeToFly` and `distanceLeft` answer for a plane flying this plan, as they do for an on-schedule plane flying the schedule's.
  - It's believed from 0.7 of the plan's cruise speed to 1.5 of it, which the strongest winds stay inside. Outside that the places can't be right, and the plan's speed stands.
  - A short leg keeps its one steady speed.
  - The landing estimate (§5.2), the ghost (§5.4), the estimated plane (§5.5) and the record after the last place seen (§7.2) all fly this plan.
- **Stage 1's lone schedule plane doesn't change.** It keeps one steady speed, and `progress-cases.json` stays as it is. Only a flight with live data uses the plan.

All of its constants are written in the shared cases (§16.1).

## 5. The real plane

### 5.1 What a device knows

`partner_live` (§10.6) gives each flight a state, its latest fix, and its trail. A device works out the rest. Fix ages are measured against the server's clock (§11).

| The flight is | When | What shows |
|---|---|---|
| **Not live** | No flight in the answer; never seen; or a fix on the ground that's over 3 minutes old | The schedule's plane alone, as today |
| **On the ground** | Seen on the ground within 10 nm of the departure airport, under 3 minutes ago | The real plane at the gate, and the ghost |
| **In the air** | Seen in the air under 3 minutes ago | The real plane, and the ghost |
| **Estimated** | Last seen in the air over 3 minutes ago | The real plane faded, flying the plan from its last fix, and the ghost |
| **Landed** | Seen on the ground within 10 nm of the arrival airport, after being in the air | The real plane at the arrival airport |
| **Elsewhere** | On the ground anywhere else: a diversion | The real plane where it is. The label and the times are the schedule's |

Three minutes, because CrewLu Cloud asks adsb.lol once a minute (§10.3): one answer that doesn't come leaves a fix 2 minutes old, and that shouldn't fade the plane. It was 2 minutes while CrewLu Cloud asked every 30 seconds.

### 5.2 The landing estimate

- **In the air or estimated:** touchdown is the last fix's time plus `timeToFly` of the great-circle distance from that fix to the arrival airport, by the plan as the plane flies it (§4).
  - At the first fix after takeoff, that's the real takeoff plus the plan's time in the air.
  - After that, a plane further along than planned lands sooner, and one less far along lands later.
  - Once the plane's own speed is known, about ten minutes into its cruise, the estimate moves to it in one step. Before that it flies the schedule's.
  - The speed in a single fix isn't used. Between fixes, and while estimated, the estimate holds still.
  - The winds ahead aren't known, and neither is the approach's pattern: the first real flight's estimate ran up to 9 minutes early over its last half hour, on an approach about 25 nm longer than the straight line.
- **On the ground after the plan's takeoff:** touchdown is now plus the plan's time in the air, as if it took off this moment. It slides later until the plane is seen in the air.
- **On the ground before the plan's takeoff:** there's no estimate. The schedule stands.
- **Landed:** touchdown is when it was first seen on the ground at the arrival airport.
- **Not live, or elsewhere:** there's no estimate.
- **The live arrival** is touchdown plus `taxiInAllowance`, wherever there's an estimate.

### 5.3 Ahead or behind

The gap is the plan's touchdown minus the estimated touchdown, rounded to the nearest minute. Ahead is positive.

| The flight is | The label |
|---|---|
| In the air, gap within ±5 | "On schedule" |
| In the air, otherwise | "12 min ahead" or "20 min behind" |
| Estimated | "About 12 min ahead", "About 20 min behind", or "On schedule" |
| On the ground, before the plan's takeoff | none |
| On the ground, up to 5 minutes after it | "Still on the ground" |
| On the ground, later | "Still on the ground · 20 min behind", counted from the plan's takeoff |
| Landed | "Landed 8 min early", "Landed 15 min late", or "Landed on time" within ±5, against the plan's touchdown |
| Not live, or elsewhere | none: "In flight", as today |

### 5.4 The ghost

- **It's where a plane that lands on schedule would be right now,** flying as the real one does, on the real plane's path (§6): as far from the arrival airport, measured along the path, as `distanceLeft` of the time until the plan's touchdown, by the plan as the plane flies it (§4).
  - Before the plan's takeoff it's at the departure airport, and after the plan's touchdown at the arrival airport.
  - It's behind the real plane on the path flown when the flight is ahead, and in front of it on the path ahead when the flight is behind.
  - A real path is longer than the planned distance, so just after the plan's takeoff the ghost is that much along it, while the schedule's speed stands.
  - When the plane's own speed becomes known, the ghost moves in one step with the estimate: back when the plane is faster than the schedule, since a plane that fast could have left later, and on when it's slower.
- **The gap between the planes is the label.** It's the distance the plan, as the plane flies it, flies in that many minutes.
- **It's always shown with a real plane,** in the air, estimated or on the ground. It isn't shown once the flight has landed, or elsewhere.
- **It looks as the moving map spec has it** (§7.2 there): a dashed white outline with a faint white plane. The real plane is a filled blue circle with a white border and a white plane, drawn on top, at 60% opacity while estimated.

### 5.5 The estimated plane

- **It flies the plan from its last fix,** as the plane flies it (§4): along the great circle from that fix to the arrival airport, as far from the airport as `distanceLeft` of the time until the estimated touchdown. The moving map spec carried it on at its last ground speed, which would disagree with the landing estimate.
- **It reaches the arrival airport at the estimated touchdown,** and stays there.
- **A new fix** makes it live again, and corrects the estimate.

## 6. The path

### 6.1 What it is

- **A flight with no trail** has the great circle between its airports, as today.
- **A flight with a trail** has its real path:
  1. the departure airport;
  2. the trail's points, in order, each joined to the next by a great circle;
  3. the latest fix, when it's in the air and newer than the trail's last point;
  4. the great circle from there to the arrival airport: the path ahead. A landed flight's path ends at the arrival airport instead.
- **An unseen stretch** is a join nobody saw:
  - two neighbouring points more than 10 minutes apart;
  - the join from the departure airport to a first point more than 30 nm from it;
  - the join from the last point to the arrival airport, on a flight that landed unseen.
- **Distance along the path** takes the place of the fraction along the great circle everywhere a leg is asked where it is (§11).

### 6.2 How it's drawn

| Part | Line |
|---|---|
| The path flown, seen | Solid white |
| An unseen stretch | Dotted white |
| From the last fix to an estimated plane | Dotted white |
| The path ahead, from the real or estimated plane | Dashed light blue, as today's line still to come |
| A flight earlier in the trip | Solid grey along its real path |
| A flight with no live data | As today |

The planned great circle isn't drawn for a flight with a real path. The camera frames the leg's path, not just its two airports.

## 7. The record: the times, the status screen and the replay

### 7.1 A flight's real times

A flight with live data has a record of where it was and when. Its real times replace the schedule's in one place, where the status screen's model hands the legs to everything that reads them (§11, §12).

- **Its arrival is the live arrival** (§5.2), whenever there is one.
- **Its departure moves earlier,** to the takeoff minus `taxiOutAllowance`, when that's before the effective departure. The takeoff is the time of the trail's first point, when that point is within 30 nm of the departure airport. A late departure doesn't move the leg: the label says "Still on the ground".
- **The wait before it ends, and the wait after it starts, where the flight does.**
- **Without live data** nothing is replaced.

So the status screen keeps "in flight" with the countdown running until the real plane arrives, and it arrives early when the plane does. Every card reads the same times: the map, the countdown, the narrative and the trip cards.

**Alerts stay on the schedule.** An arrival alert can come some minutes before or after the screen changes.

### 7.2 Where the plane was at any moment

For a flight with a record, at a moment `t`:

- **Before its first point:** it flies from the departure airport at the plan's cruise speed, timed to reach the first point when it was seen there, and waits at the airport before that.
- **Among its points:** between the two points either side of `t`, in proportion to the time.
- **After its last fix, not landed:** the estimated plane's place at `t` (§5.5).
- **After it landed:** at the arrival airport.

The same record answers the other way round: when the plane was a given distance along its path. The facts use that for their times (§8).

### 7.3 The replay

- **A flight with a record replays its record:** the real plane on its real path, at its real times.
- **The ghost and the label are for now only.** A moment in the replay shows the real plane alone, and the pill reads "In flight".
- **Every other flight** replays the schedule, as today.
- **The timeline's blocks** use each flight's real times.
- **Ahead of now,** the current flight flies the plan from its last fix, as the plane flies it (§4), and later flights fly the schedule.

A flight's record is kept for 16 days (§10.5). After that it replays the schedule.

## 8. The facts on the real path

The facts engine keeps its shape: a story per flight, and answers looked up in it. A flight with live data gets its story from its real path.

- **The story is made along the path,** sampled as today, and made again as the path grows: at most once a minute for a flight.
*Mended 16 Nov 2026: the best guesses design (`2026-11-15-crewluve-facts-best-guesses-design.md`) changed what's below an estimated plane and the crossings nobody saw, after plan 3B-3 had built them as first written here; the which plane design (`2026-11-16-crewluve-which-plane-design.md`) added a plane still at its gate. This section says what the app does now.*

- **What's below:**
  - in the air: looked up at the real plane's position, "Over Québec, near Montréal";
  - estimated: looked up where the map draws the faded plane, flown on from the last place it was seen along the great circle, in the same plain words. Under it, "Last tracked near Gander · 2 h 10 min ago", by the place under the last fix, else "Last tracked over Newfoundland · …", else "Last tracked 2 h 10 min ago" (best guesses design §2);
  - still at its departure airport after the plan's takeoff time: "Still on the ground in Rockford", ahead of any event or sun countdown, with no sky row and "2,788 mi to go" (which plane design §4).
- **Crossings** ("Just crossed into Germany", "Out over the Atlantic") are told when the real plane crosses, and listed with the real time.
  - A crossing on a stretch nobody saw, or past the last place the plane was seen, is a best guess: it's told at the time the plan has the plane there, and its time reads "about", drawn lighter in the list (best guesses design §3).
  - A plane still at its gate has passed none: its flight is left out of the list until it takes off (which plane design §4).
- **Closest to home** is measured along the path, and fires when the real plane passes that point. Where nobody saw it there, its time reads "about", as a crossing's does.
- **Halfway** is half the path's whole length, flown and ahead. Before it's reached the row reads "Halfway at about 12:05 PM", timed by the plan.
- **Distance:** "1,140 mi flown · 3,010 to go". Flown is along the path so far. To go is the great circle from the plane to the arrival airport.
- **The plane's row,** second, with live data only:
  - "Boeing 767-300 · N370UP", from `AircraftTypeNames`. An unknown type code shows as itself. A missing registration is left out.
  - "35,000 ft · 540 mph" under it, in the air only. Estimated, it's left out.
- **Sky and sun:** worked out along the path, with the record's times. The horizon dip uses the last fix's altitude in the air, and 35,000 ft otherwise.
- **Weather on landing** is the forecast for the live arrival.
- **The schedule-only speed line** ("Averaging about 510 mph") shows only without live data.
- **Trip totals and the recap** count miles along real paths where there are records.
- **The credit:** "Live position: adsb.lol" in the facts sheet's and panel's footer, beside the weather credit, whenever a flight with live data shows.

## 9. The words

| Where | Without live data (today) | With live data |
|---|---|---|
| The card's bar, middle | "In flight" | The label (§5.3) |
| The card's bar, right | "Lands 3:30 PM" | "Lands about 3:18 PM" |
| The card's bottom chip | "Landing in 2 h 10 min" | The same, counted to the live arrival |
| The full-screen pill | "UPS207 · In flight" | "UPS207 · 12 min ahead" |
| The landing line | "Lands Cologne 9:30 PM · 3:30 PM your time" | "Lands Cologne about 9:18 PM · 3:18 PM your time" |
| The card for VoiceOver | "UPS207 to Cologne, over Québec. Lands at 3:30 PM your time. Estimated from the schedule." | "UPS207 to Cologne, 12 minutes ahead of schedule, over Québec. Lands about 3:18 PM your time." |
| The countdown and narrative cards | The effective arrival | The live arrival, read as "about 3:18 PM" |

- **"About"** marks every time that comes from the live estimate. A landed flight's times have no "about".
- **The headline chip** keeps its order: a milestone from the last 5 minutes, a cockpit sunrise or sunset within 30, what's below, then the landing countdown. While the plane is out of sight, what's below is read where the map has it, in the same words (best guesses design §2). Beside the latest event's banner the card's chip and the sheet's first line leave events out (latest event design §2).

## 10. CrewLu Cloud (`Duty/supabase`)

### 10.1 The parts

| Part | What it is |
|---|---|
| `private.airports` | Each airport's code and position, filled by a second script made from the website's `public/data/airports.json` (9,056 airports) |
| `private.live_flights` | One row per pilot's watched flight: its key, airports and their positions, effective times, state, aircraft and latest fix |
| `private.live_flight_points` | The trails: one row per point |
| `private.flight_live_state` | One row: the switch, the listed pilots, and the pause after failures |
| `private.flight_legs(status)` | A summary's flight legs that can be watched, each with its callsign. The check and `partner_live` both use it |
| `private.open_live_flights()` | The flights whose window is open. The check and the claim both use it |
| `private.flight_live_switch(mode, pilots)` | Sets the switch, from the SQL editor |
| `private.flight_live_tick()` | The check, run by pg_cron once a minute |
| `flight-live` | The Edge Function: one file with no imports, like `partner-push` |
| `flight_live_claim`, `flight_live_report` | Its two RPCs, for `service_role` with a Vault password of their own |
| `partner_live` | The partner RPC |

### 10.2 Which flights are watched

`private.flight_legs` reads a summary's `tripLegs` and keeps a leg when all of these hold:

- **It's a flight** with both airports in `private.airports`. An airport written with UPS's trailing Z is read without it, as the website reads it.
- **It has a callsign,** built as the website builds its tracking number (`toMove` in `src/partner/convert.ts`, `trackingFlightNumber`):
  1. take the flight number in capitals without spaces, and take off the leg's airline code from the front when it starts with it;
  2. it must then be an optional airline prefix and digits. `GND`, and a number ending in `CML`, have no callsign;
  3. the airline is the leg's airline code, else the prefix, else UPS;
  4. a two-character airline code becomes its ICAO code from a table in the SQL: today's 15 airlines, and the cargo and regional airlines the website names. A three-letter code is used as it is. An airline not in the table has no callsign;
  5. the callsign is the ICAO code and the digits without leading zeros: `UPS0207` becomes `UPS207`. One longer than 8 characters, which no aircraft can broadcast, isn't a callsign.
- **Its times are moved by its own delay.** A summary-wide delay from a CrewLu that doesn't tag legs isn't counted: the window is wide enough without it.
- **Nothing a summary holds can stop the check,** which reads every pilot's summary together. A time counts only as a number of seconds from 1970 to 2100, an arrival must be after its departure and within a day of it, and a delay counts only within a week either way. A leg that fails the first two is left out, and any other delay is none.

The table holds each airline's real ICAO code, so PSA Airlines is `JIA`. The app's tracking links have `PSA` for it, which is another airline's.

**The window.** A leg is watched from 30 minutes before its effective departure until the first of: landing seen, or 2 hours after its effective arrival. A flight still being seen in the air keeps its window open until 30 minutes after its last fix, to at most 12 hours after its effective arrival.

**The key** is the pilot, the callsign, the departure airport and the scheduled departure. Each pilot has rows of their own, even for a flight two of them are on, so nothing in one pilot's summary can change what another pilot's family sees. The moving map spec had crew share a row, which let one pilot's summary set another's arrival airport and window. Sharing saved nothing: a callsign goes to adsb.lol once however many rows have it.

**Whose flights.** The check watches a pilot's flights only when:

- the switch allows that pilot (§10.7); and
- one of their partners has a device seen in the last 30 days.

At most 8 of a pilot's flights are watched at once, the earliest to leave. That's more than a pilot can have open, and it keeps a summary gone wrong from making `flight-live` ask adsb.lol for thousands. The limit holds where flights are handed to `flight-live`, however many rows a pilot's summaries have made.

**A flight that leaves its pilot's summary** stops being watched at the next check. If nobody ever saw it, its row is deleted. If somebody did, it keeps its row and trail, and is watched again if it comes back. The same happens when the switch stops allowing a pilot, or their partners' devices go unseen for 30 days.

### 10.3 Each run

At second 0 of every minute, pg_cron runs `private.flight_live_tick()`. It:

1. stops if the switch is off or the pause hasn't run out;
2. makes or updates each pilot's row for every leg of theirs whose window is open, and lets go of the flights that have left their pilot's summary;
3. calls `flight-live` through pg_net with the Vault password, if any row's window is open and it hasn't landed.

`flight-live` then:

1. **claims** the open rows: each one's callsign, airports' positions, effective departure, state and aircraft;
2. **asks adsb.lol once** for every callsign: `GET https://api.adsb.lol/v2/callsign/<a>,<b>,…`, with a 10-second timeout and a `User-Agent` that names CrewLu Cloud. More than 100 callsigns go in further requests, one after another;
3. **judges** each row's answer (§10.4);
4. **reports** what's new, and how the request went: a new state, another aircraft, or a fix seen at least a second later than the one the flight has. The database adds the trail points.

A run starts no request later than 20 seconds after it began, and reports that as a failure: runs that piled up would ask adsb.lol twice over just when it's slow. A call with no password is refused before anything else.

With no window open there are no requests. Otherwise there's 1 a minute, however many pilots are flying.

**Why the top of the minute.** adsb.lol counts requests by the clock's minute (§2.1), so a request at a minute's start finds its allowance whole. The check first ran every 30 seconds. pg_cron's 30-second schedule drifts, about 6 seconds an hour, and on the first real flight it slid from :01 and :31 to :22 and :52, where about half its requests were refused. A cron minute doesn't drift. Asked at second 0, 46 requests in a row had no refusal. So a fix is new at most once a minute, and one missed answer leaves it 2 minutes old.

### 10.4 The match: following the aircraft

For a row, the candidates are the aircraft in the answer whose callsign, trimmed, is the row's, with a position on the Earth seen in the last 60 seconds, and either a height or "ground". An aircraft that sends neither can't be told to be flying, and is passed over, as is any entry that isn't an aircraft. Each row is judged on its own, so one that can't be doesn't cost the others their fixes.

- **Before it's seen in the air** (`waiting`, or `ground`, which is also a flight down again after a return or a diversion), in this order:
  1. its own aircraft in the air has taken off: `airborne`;
  2. a candidate on the ground within 10 nm of the departure airport is the flight, and the row takes that aircraft: `ground`. Its own comes first while it's seen there, else another, as when the airline swaps aircraft;
  3. its own aircraft on the ground anywhere else, as after a diversion, stays `ground` with its newest fix. No other plane with its number takes its place while it's seen;
  4. any other candidate in the air is the flight only from 20 minutes before the effective departure, only between the two airports, and only when it isn't heading for the departure airport. The row takes that aircraft: `airborne`.
     - Between means its distance from the departure airport plus its distance to the arrival airport is no more than 1.3 times the distance between them plus 200 nm.
     - Heading for means its track is within 90° of the bearing to the airport. That's the plane still flying the leg before, under the same number and running late. An aircraft that sends no track is taken.
- **Once it's in the air,** only the row's aircraft counts, wherever it goes:
  - in the air: the fix is kept;
  - on the ground within 10 nm of the arrival airport: `landed`, with the time. The row is finished;
  - on the ground anywhere else: `ground`. That's a return to the departure airport, or a diversion.
- **Anything else is ignored,** and the row keeps what it has.

So a reused flight number on another plane, and a different leg with the same number, can't take over the map. A wide routing or a diversion still shows, which the moving map spec's corridor of 250 nm would have dropped.

### 10.5 What it keeps

- **The latest fix:** latitude, longitude, altitude in feet (null on the ground), ground speed in knots, track in degrees (null when missing), whether it's on the ground, registration, type code, and when it was seen. Seen time is when the answer came, minus `seen_pos`. A fix older than the one a flight has is left alone.
- **The trail:** a point for the first fix in the air, then one whenever the last is 110 seconds old or more: `[time, latitude, longitude, altitude]`. Fixes on the ground aren't trail points.
- **A report is checked before it's kept.** An entry that can't be read is passed over. A fix is rebuilt from its nine fields, each within reason, so nothing else can reach a partner through it. One dated more than 5 minutes ahead is refused, since it would hold off every fix after it.
- **Two runs that overlap can't add a point twice.** A report locks its flights in order, keeps only a newer fix, and adds its trail points in a step of their own.
- **For 16 days.** A daily job deletes a row, with its points, 16 days after it landed, or after its effective arrival if it never did. That covers the longest trip and its recap day. A ten-hour flight is about 300 points. A pilot who deletes their account takes their rows with them.
- **Only public ADS-B data,** in the `private` schema, which the API doesn't expose.

### 10.6 `partner_live`

A new partner RPC beside `partner_view`, called the same way. `partner_view` doesn't change.

- **Parameters:** `p_key`, and `p_after` (optional: the last answer's `cursor`).
- **Answer:**

  ```json
  {"now": <ms>, "cursor": <integer>,
   "flights": [{"leg_id", "callsign", "state",
     "fix": {"lat", "lon", "altitude_ft", "ground_speed_kt", "track_deg", "on_ground",
             "registration", "type_code", "seen_at"} | null,
     "landed_at": <ms> | null,
     "trail": [[<ms>, <lat>, <lon>, <ft>], ...],
     "trail_count": <integer>}]}
  ```

  - `flights` holds a row for each flight leg in the pilot's current summary that has one, matched by the leg's key through `private.flight_legs`. `leg_id` is that leg's `id`. A leg the pilot hides or removes stops being answered at once, and nothing else needs to be kept in step.
  - `state` is `waiting`, `ground`, `airborne` or `landed`.
  - `trail` holds the points newer than `p_after`, oldest first, or all of them without it. `trail_count` is how many points the flight has in all. A device whose own count doesn't match asks again without `p_after`.
  - `cursor` goes back as the next `p_after`.
  - `now` is the server's clock. Every time is milliseconds since 1970.
  - The fields are named with underscores, as the partner door's other answers are.
- **Errors:** as `partner_view`: `sharing_ended` for a key that's been let go.
- **The switch applies here too:** off answers no flights, and listed answers only listed pilots' partners.
- **It doesn't count as the device being seen.** `partner_view` does that.
- **It's called by POST only.** It only reads, but it isn't marked `stable`: PostgREST would then take it by GET, which puts the device's key in an address.
- **Devices keep asking past a window's 2 hours** while the last answer shows the flight `airborne` with a fix under 30 minutes old, as the check keeps watching it (§10.2).
- `partner-api.md` gains its row and rules.

### 10.7 The switch and failures

- **The switch** is `off`, `listed` or `all`, with a list of pilots for `listed`. It ships `off`. It's changed in the SQL editor, with `private.flight_live_switch`.
- **A timeout, an error or an answer that doesn't read:** nothing is kept from that run, and the next run tries again. After 5 in a row, polling pauses for 5 minutes.
- **A 429** costs that one check. The next is a minute later, which is later than any 429 seen so far has asked for. A 429 counts with the failures: 5 checks in a row that fail or are refused pause polling for 5 minutes. It first paused polling for 2 minutes, ten times what adsb.lol asked, which left a fix 3 minutes old each time. `flight-live` logs what each 429 asks for.
- **The devices need no failure state.** A fix that stops arriving makes the plane estimated by itself.
- **If adsb.lol starts needing a key,** it goes in the function's secrets.
- **If adsb.lol is gone for good,** the switch goes off and every family is on the schedule, with nothing else broken.

### 10.8 Setting it up

Three scripts, each run in the SQL editor with its undo in its header, as the push service's is: the live plane's, which makes its own Vault password and the function's address, then the airports', then the one that sets the check to once a minute and a 429 to cost one check (§10.3, §10.7). `flight-live` is added in the dashboard. Nothing is applied to CrewLu Cloud without Todd's OK at each step (§17).

## 11. The app

- **`PartnerDoor` gains `live(key:after:)`,** and `LivePartnerDoor` its call.
- **`LiveFlightSource`** (`Services/TripMap/`), an `@Observable` `@MainActor` model owned by the status screen.
  - It asks every 30 seconds while the screen is in front and a flight's window is open (§10.2's rule, worked out from the legs), and once each time the screen comes to the front.
  - It never asks in the background, and never on iCloud.
  - It keeps each flight by leg id, adds new trail points to the ones it has, and checks `trail_count`.
  - It keeps the difference between the server's clock and the device's, so a wrong phone clock doesn't age a fix.
  - `sharing_ended` goes to `CrewluCloudDevice`, as `partner_view`'s does. Any other failure keeps what it has.
- **New pure types,** `nonisolated` and tested:
  - `FlightPlan`: §4.
  - `FlightPath`: §6.1, with the distance along it, the point at a distance, and its unseen stretches.
  - `LiveFlight`: one flight from `partner_live`.
  - `LiveProgress`: §5, for a leg, its live flight and a moment.
  - `FlightRecord`: §7.2.
  - `AircraftTypeNames`.
- **`MapLeg` carries its path and, with live data, its record.** Its `progress(at:)`, `position(at:)`, `time(atFraction:)`, `heading(at:)` and `distance` ask them, so `TripMapDrawing`, the camera, `LegStory` and the facts follow the real path without knowing which kind it is.
- **`TripMapDrawing`** gains the real plane, the ghost and §6.2's lines. `TripMapShapesView` draws the new lines with its existing layers, and `TripMapMarkers` gains the two planes.
- **`LegStory`** samples the leg's path, and marks which stretches were seen. `LegStoryStore` makes a flight's story again when its path grows, off the main actor, at most once a minute.
- **One landing time:** the status screen's model replaces a live flight's times (§7.1) in the legs before `TripStateResolver`, `TripMap` and the cards read them. No card works it out itself.
- **Words:** `TripMapWording` and `FactsWording` gain §9's and §8's. `FactsFooter` gains the credit.
- **The helper target** (`CrewluveAlerts`) is untouched: none of its 15 files change.

## 12. The website

The same design in TypeScript, held to the same answers by the shared cases.

- **`src/partner/`:** `partner_live` joins `DOOR_RPCS`, which also allows it in the Content-Security-Policy. `live.ts` polls as the app does, while the page is visible.
- **`src/map/`:** `flightPlan.ts`, `flightPath.ts`, `liveProgress.ts` and `flightRecord.ts`. `tripMap.ts` and `tripMapDrawing.ts` carry the path and the two planes.
- **The drawing:** `appleMapPlan.ts` and `AppleTripMap.tsx` gain the lines and the planes on Apple's map, and `TripMapSvg.tsx` on the fallback.
- **`src/facts/`:** `legStory.ts` along the path, and the rows.
- **`src/engine/`:** a live flight's times replace the schedule's where a summary becomes the engine's schedule, so the countdown and narrative need no change of their own.
- **`src/copy/`:** the words, and the credit in the panel.
- **Demo scenes,** with recorded live data: `live-ahead`, `live-ocean-gap` and `live-on-ground-late`. `flying` stays the schedule-only scene.

## 13. What can go wrong

- **No coverage at the departure airport:** the flight is first seen in the air. Its first stretch is unseen, and its departure doesn't move.
- **No coverage at the arrival airport:** landing is never seen. The estimated plane reaches the airport at the estimate, the leg ends then, and the row closes with its window.
- **A plane seen again after its estimate has passed,** as after a hold: the estimate moves later and the flight is in the air again, even if the screen had moved on.
- **A return to the departure airport:** the trail keeps both attempts. The flight is on the ground, then in the air again.
- **A diversion:** §5.1's last row. CrewLu sends the new plan when the pilot has it.
- **The same flight number on back-to-back legs:** each leg's row takes the aircraft only at its own departure airport, or in the air near its own departure time and not heading for that airport.
- **Two airports within 10 nm of each other,** or a flight that lands where it left: the first fix on the ground after takeoff reads as landed.
- **An airline that flies under another's callsign,** as a regional does for a major: the callsign doesn't match, and the flight stays on the schedule.
- **The schedule changes** (a new scheduled departure): the leg gets a new row, and the old one is deleted with the others after 16 days.
- **A reported delay that disagrees with the real plane:** the real plane wins for the times. The ghost and the label measure against the reported delay.
- **A wrong phone clock:** fix ages use the server's clock.
- **The date line and long legs:** the path's joins are drawn as today's lines are, in stretches of at most a degree, once for each copy of the world on screen.
- **adsb.lol down, slow or gone:** §10.7.
- **adsb.lol refusing some requests:** the check asks at each minute's start, where it isn't refused (§10.3). A refused check leaves the fix a minute older, and nothing else changes.
- **A long stretch with no receivers,** as over northern Canada or an ocean: the plane is estimated until it's seen again, and that stretch of its path is unseen (§5.5, §6.1).

## 14. Security and privacy

- **What's stored and served:** only public ADS-B data, for flights in a pilot's summary.
- **What partners see:** only their own pilot's flights, through their device key, and only legs in the pilot's current summary.
- **What adsb.lol sees:** callsigns, from CrewLu Cloud. Nothing about a pilot or a partner, and nothing from a device.
- **The website's Content-Security-Policy** gains only the one new partner-door address.
- **`flight_live_claim` and `flight_live_report`** are for `service_role` and need the Vault password, as the push service's are.
- **Logs** show callsigns and counts, never device keys.

## 15. Accessibility

- **The card** is one VoiceOver element with §9's sentence. While estimated it says "about" and "last tracked near Gander". What's below and where it was last seen are said only while the plane flies, not at its gate nor once it's down (which plane design §4), and the sentence ends with the latest event: "Latest: crossed into Canada, 12 minutes ago." (latest event design §3).
- **The plane's row and the credit** are sentences, like the other rows.
- **The two planes** aren't separate VoiceOver elements: the card's sentence and the rows describe them, as the moving map spec has it.
- **The label doesn't rely on color.** Its words carry it.
- **Reduce Motion:** the planes jump to each new position instead of sliding.
- **Dynamic Type and Dark Mode:** as the rows and chips already behave.
- **The website** follows the same rules.

## 16. Testing

### 16.1 The shared cases

A new `CrewluvTests/Fixtures/TripMap/live-cases.json`, copied to the website's `tests/fixtures/trip-map/`. Both suites run every case. It holds:

- the constants, and the plan: `timeToFly` and `distanceLeft` for a long leg, a short leg and a leg under both allowances;
- the plane's own speed (§4): known and a second short of known, believed and not at both ends of its range, with a hold near the arrival airport, with a return and a wait at the departure airport, and on a slow leg that keeps its one speed;
- the landing estimate in the air, on the ground before and after the plan's takeoff, estimated, and landed;
- every label in §5.3, with the ±5 edges;
- the ghost's distance from the arrival airport, ahead of and behind the real plane;
- the estimated plane's place, to its arrival;
- paths from trails: joined points, an unseen stretch in the middle, a late first point, and a landing nobody saw;
- the record: where the plane was at given moments, and when it was at given distances;
- a flight's real times: an early takeoff, a late arrival and an early one;
- the window.

`progress-cases.json`, `facts-cases.json`, `replay-cases.json` and `activity-cases.json` don't change.

### 16.2 CrewLu Cloud

- **SQL tests** in `Duty/supabase/tests`, in PGlite:
  - `private.flight_legs`: callsigns for company flights, other airlines, leading zeros, `GND` and `CML`, and unknown airports;
  - the check: the window, each pilot's own rows, the cap of 8, the 30-day rule, the switch's three settings, and the pause;
  - claim and report: the password, and what each writes;
  - `partner_live`: only the partner's own pilot's flights, a hidden leg, `sharing_ended`, `p_after`, `trail_count`, and the switch;
  - the daily delete;
  - the migration's second run and its undo, and the advisor, privilege and safeupdate guards, which load every migration.
- **Function tests** under Node, on recorded adsb.lol answers and never live calls:
  - one request for several callsigns, and the split after 100;
  - the match: taking the aircraft on the ground, takeoff, a first sighting in the air, the 20-minute rule, between the airports, a reused flight number, an aircraft swap, landing seen, a return and a diversion;
  - trail points every 110 seconds;
  - a timeout, a bad answer, 5 failures in a row, and a 429.

### 16.3 Crewluve

XCTest, run in Xcode by Todd: the shared cases through `FlightPlan`, `FlightPath`, `LiveProgress` and `FlightRecord`; `LiveFlightSource` (when it asks, new points, a `trail_count` mismatch, `sharing_ended`, the clock difference); `LegStory` along a path with an unseen stretch; `TripMapDrawing`'s lines and planes; the words; `AircraftTypeNames`; and one landing time through the status screen's model.

### 16.4 The website

vitest on the shared cases, the polling, the engine's times and the words. The demo scenes are checked by eye, on Apple's map and on the fallback.

### 16.5 On a real flight

Before the switch goes to everyone, follow one real flight from gate to gate, preferably across the ocean so the gap shows, in the app and on the website side by side.

## 17. Rollout

Each step waits for Todd's OK.

1. **CrewLu Cloud** goes live with the switch `off`: the migration, then `flight-live`. `partner-api.md`'s checks gain `partner_live`'s.
2. **The switch goes to `listed`** with Todd's own account.
3. **The app** on TestFlight follows a real flight (§16.5).
4. **The website** follows.
5. **The switch goes to `all`.**

An older Crewluve never calls `partner_live`, and shows the schedule as it does today.

## 18. Not in this design

- **Live data for iCloud families.**
- **Alerts driven by live data,** such as "Landed, for real".
- **Real filed routes.** Nothing free gives them, so the path ahead is a great circle from the plane.
- **Polling in the background,** or live data in the alert pushes' helper.
- **A change to Stage 1's schedule plane** (§4).
- **CrewLu's own moving map using live data,** and anything else in CrewLu.
- **A setting for the pilot to turn the live plane off.** The data is public, and the family can already open the flight on FlightRadar24.

## 19. The plans

1. **Stage 3A, CrewLu Cloud:** `Duty/supabase`: the migration, `flight-live`, their tests, and `partner-api.md`.
2. **Stage 3B, the app:** the shared cases, the pure types, `LiveFlightSource`, the drawing, the facts, one landing time and the words.
3. **Stage 3C, the website:** the same in TypeScript, with the demo scenes.

3A is written first. 3B and 3C are each written when they're about to start, since each depends on what the one before it settled.

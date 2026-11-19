# Every time says whose time it is — design

**Date:** 19 Nov 2026
**Repos:** Crewluv (the app) and Crewluve Website, together
**Asked for by:** Todd, after following UPS95 Taipei → Anchorage on the TestFlight build 1.3.4 (49)

## 1. Why

On the flight, Todd couldn't tell whose time each time was. The trip map shows almost every time in the family's own time, with no label. The landing row shows two times, and only the second one says so ("Lands Anchorage about 12:35 PM · 4:35 PM your time"). The status screen labels times a third way, with the zone's abbreviation ("4:35pm EST"). The pilot's own clocks (the location card, the sun dial) are in the pilot's time, also unlabelled.

He also asked what "about 31 min before the people below" means on the sky row. At cruise the cockpit sees the sunrise before the ground below it does, and sees the sunset after it. The words should say that plainly (§3.6).

## 2. The rules

1. **The family's own time gets an "L".** For example: "Out over the Philippine Sea · 9:22 AM L". L means the viewer's own time: the device's zone in the app, and the browser's zone on the website. It takes the place of "your time" and of the zone abbreviations ("EST", "est").
2. **A time in another zone gets the city's name after it.** For example: "sunrise at 7:02 AM Cologne". It takes the place of "there".
3. **A line that already starts with the city doesn't repeat it.** For example: "Cologne · 9:14 PM" and "Lands Anchorage about 12:35 PM · 4:35 PM L".
4. **Takeoff and landing show both times when the city's clock differs from the family's at that moment.** The city's time comes first and the L time second. When the clocks match, only the L time shows: "Lands Louisville 3:30 PM L".
5. **The pilot's own clocks stay in the pilot's time and name the city once.** That's the location card's clock, the sun dial and the sun detail screen.
6. **The lock-screen alerts don't change** (§6).
7. **Twelve- and 24-hour time both work.** The L follows either one: "16:35 L". Apple's formatter writes a morning hour without a leading zero in 24-hour time ("5:35"), and the website matches it.

## 3. What changes, place by place

The inventory below was taken on `main` at `6b78381`. Line numbers are as of that commit.

### 3.1 One helper writes every time

- **App:** a new `nonisolated` `ClockLabel` in `Crewluv/Services/` (file `ClockLabel.swift`). It sits beside `TripMapWording.clockTime`, which stays the one place that formats a clock time. It is the one place that adds a label to one.
  - `yours(_ date:, calendar:, locale:) -> String`: "4:35 PM L".
  - `place(_ date:, zone:, city:, locale:) -> String`: "7:02 AM Cologne".
  - `pair(_ date:, zone:, calendar:, locale:) -> String`: "12:35 PM · 4:35 PM L", or "4:35 PM L" when the zone keeps the family's offset at `date`. The caller writes the city before it.
  - `key(calendar:, locale:) -> String`: "L = your time (Eastern Standard Time)", with the zone's long name from `TimeZone.localizedName(for: .standard or .daylightSaving, locale:)` for the current moment.
  - `zoneName(_ zone:, at:, locale:) -> String`: the long name, for the hover tip.
- **Website:** the same five functions in `src/copy/clockLabel.ts`, next to `copy/format.ts`.
- **Shared cases:** `clock-label-cases.json`, kept as `CrewluvTests/Fixtures/TripMap/clock-label-cases.json` in the app and `tests/fixtures/trip-map/clock-label-cases.json` on the website. Both copies are identical. Each case gives an instant, the viewer's zone, an optional place zone and city, and a 12- or 24-hour flag, with the expected words. Cases to include:
  - a city on the family's clock;
  - a city on a different clock;
  - a half-hour zone (Kolkata);
  - each side of a daylight-saving change;
  - a time past midnight;
  - 24-hour time.

### 3.2 The trip map

The app's wording is in `TripMapWording.swift`, `Facts/FactsWording.swift`, `Facts/TripFacts+Rows.swift`, `Facts/TripFacts.swift` and `PlanePopupWords.swift`. The website's counterparts are in `copy/tripMap.ts`, `copy/facts.ts`, `facts/tripFactsRows.ts`, `facts/tripFacts.ts` and `copy/planePopup.ts`.

| Where | Today | After |
|---|---|---|
| Card chip on a layover, panel headline on the ground (`placeChip`) | "Cologne · 9:14 PM there" | "Cologne · 9:14 PM" |
| Card chip, next flight (`nextDepartureChip`), facts' next-flight row title | "Next: Dubai, tomorrow 6:10 AM" | "Next: Dubai, tomorrow 6:10 AM L" |
| Facts landing row, full-screen headline in flight (`landingLine`) | "Lands Anchorage about 12:35 PM · 4:35 PM your time" | "Lands Anchorage about 12:35 PM · 4:35 PM L" |
| Facts landing row once down (`gateLine`) | "Reaches the gate at 3:52 PM · 7:52 PM your time" | "Reaches the gate in Anchorage at 3:52 PM · 7:52 PM L": it names the city, so its first time is labelled |
| Card's in-flight bar (`landsAt`, `barArrival`) | "Lands about 3:18 PM" | "Lands about 3:18 PM L" |
| Caption under the bar (`arrivalLocalTime`) | "9:30 PM in Cologne" | unchanged: the city already names it |
| Line under the replay timeline (`timelineLine`) | "Sat 1:40 PM · Layover in Denver" | "Sat 1:40 PM L · Layover in Denver" |
| Flight's events list (`listLine`) | "Out over the Philippine Sea · 9:22 AM" | "Out over the Philippine Sea · 9:22 AM L" |
| Latest event banner in a replay (`eventWhen`) | "About 10:37 AM" | "About 10:37 AM L" |
| Facts below row (`closestToHome`) | "Passes 40 mi from home at about 1:05 PM" | "… at about 1:05 PM L" |
| Facts sky row's detail (`cockpitEvent`, new `cockpitGap`) | "Sunrise at 2:40 PM, about 31 min before the people below" | "Sunrise at 2:40 PM L · The pilot sees it 31 min before the ground does" (§3.6) |
| Facts where-they-are row (`groundSun`) | "sunrise at 7:02 AM there" | "sunrise at 7:02 AM Cologne" |
| Facts distance row (`halfway`) | "Halfway at about 12:05 PM" | "Halfway at about 12:05 PM L" |
| Facts next-flight detail (`lands`) | "lands 4:05 PM there" | "lands 4:05 PM Dubai", or "lands 4:05 PM L" on the family's clock |
| Facts at home (`leavesRow`) | "Leaves tomorrow 6:10 AM" | "Leaves tomorrow 6:10 AM L" |
| Plane popup (all lines) | "Where it was at 10:37 AM", "… lands about 3:18 PM" | the same with " L" after each time |
| Spoken card sentences (`liveSummary`, `flightSummary`, TripMapWording :348) | "Lands about 3:18 PM your time." | unchanged: VoiceOver reads "your time" aloud, which is clearer spoken than "L" |
| Spoken latest event in a replay (`spokenLatestEvent`) | "Latest: halfway, at 3:14 PM." | "Latest: halfway, at 3:14 PM your time." |

Everything else VoiceOver reads from these words (the rows, the headline, the events list, the card's bar) goes through `ClockLabel.spoken`, which reads each "L" after a time as "your time".

On the website, the events list in `facts/tripFacts.ts` keeps its long-gap rule (`toldMilestones`). Only the words change.

### 3.3 The takeoff row (new)

- **When:** in flight, the facts get a row just above the landing row. That's `headedRow` in `TripFacts+Rows.swift`, and `facts/tripFactsRows.ts` on the website. It doesn't show on the ground, before takeoff or after the gate.
- **Words:**
  - "Took off Taipei 7:42 PM · 6:42 AM L" when the real plane's takeoff was seen (`FlightRecord.takeoff`).
  - "Took off Taipei about 7:42 PM · 6:42 AM L" from the schedule's takeoff (`FlightPlan.takeoff`) otherwise.
  - Only "Took off Louisville 9:05 AM L" when Louisville keeps the family's clock.
- **Left out** for a real plane first seen more than 30 nm from its departure airport (`FlightRecord.takeoff` is nil): when it left can't be told, and for a late flight the schedule's time could be an hour off.
- **Weather at takeoff** (asked for by Todd after his first look): the row's second line is the weather in the hour it took off, "84°F and clear at takeoff". `LandingWeather` asks WeatherKit for it beside the landing weather, only while the full-screen map is open and only for the flight in the air, at `MapLeg.takeoff`'s time. Apple's Weather attribution shows under the facts, as for landing. With no answer, the row has no second line.
- **Look:** a takeoff symbol, `airplane.departure`, beside the landing row's `airplane.arrival`.
- **Replay:** the row follows the replay's clock, like every facts row.
- **VoiceOver:** "Took off Taipei 7:42 PM, 6:42 AM your time", from the row's sentence.

### 3.4 The current event is bold

- In the flight's events list, the newest event of the flight under way is bold. Live, that's the top line of the "In the air now" section.
- In a replay, the newest event at the replay's moment is bold.
- Older flights' sections have no bold line.
- An estimated event ("about") that is the newest stays italic and is bold too.
- **App:** `TripSoFar.Event` gains `isCurrent: Bool`, set in `TripFacts.tripSoFar(at:)`. `TripSoFarList` adds `.bold(event.isCurrent)`.
- **Website:** the event gains `isCurrent`, and `ui/TripSoFarList.tsx` adds a `current` class with `font-weight: 600` in `styles/tripMap.css`.
- VoiceOver adds "latest" after the current event's line.

### 3.5 The key and the hover tip

- **The key:** "L = your time (Eastern Standard Time)", from `ClockLabel.key`, in caption type and secondary color. It shows once at the bottom of the facts sheet or panel, and once at the bottom of the status screen, above anything that sits at the very bottom today.
- **Website hover:** every L time, and every city time, is wrapped in `<time datetime="…" title="4:35 PM Eastern Standard Time">`. That gives a mouse the full zone name, and screen readers the instant.
- **App hover:** a facts row, the headline, an event line or the card bar's landing time that holds an L time gets the key, "L = your time (Eastern Standard Time)", as its `.help` tip (`View.clockLabelHelp(for:)`). It shows on an iPad with a pointer and does nothing on an iPhone.

### 3.6 The sky row says it plainly

- **Today:** the row's title is "Flying into the morning", and its detail starts "Sunrise at 2:40 PM, about 31 min before the people below".
- **After:** the title stays. The detail reads "Sunrise at 2:40 PM L · The pilot sees it 31 min before the ground does", or for a sunset "… 12 min after the ground does", then the moon as today.
- Under an hour away, the countdown stays: "Sunrise in 25 min".

### 3.7 The status screen and the schedule

Today these label times with the zone's abbreviation. After this change, they use L.

- **Status sentence:** `NarrativeCardView.formattedLocalTime` and `homecomingText` in the app, `copy/narrative.ts` `.time()` and `longDateTimeText` on the website. "…which is 4:35pm EST" becomes "…which is 4:35 PM L".
- **Home sentence:** `formattedDepartureDate`, and `departureText` on the website. "Heading to Dubai Sunday the 1st at 6:00am" becomes "… at 6:00 AM L".
- **Upcoming trip card:** `UpcomingTripCard.formattedDeparture`, `tripCardDepartsText` on the website. It becomes "Departs Tue Nov 25 at 6:00 AM L". This also mends two things:
  - The app's card ignores 24-hour time. It goes through `ClockLabel` now.
  - The website's card is in the home airport's zone, where the app's is in the device's zone. The website moves to the viewer's zone, so the L is true.
- **Countdown cards:** `PilotStatusView.formatHomeArrival` and `departureSubtitle`, and on the website `arrivalWhenText`, `tripDepartsText` and `leaveWhenText`. These are in the home airport's zone today. They move to the viewer's zone with an L, so they agree with the status sentence.
- **Schedule list:** `TimelineRowView` (:260-283) and `copy/schedule.ts` `legTimes`. "9:02am est – about 1:15pm est" becomes "9:02 AM – about 1:15 PM L", with one L at the end of the range.
- **Website footer:** `ui/Footer.tsx` becomes "Offline — showing the schedule from Thu 7:59 AM L".
- **Last sync** (`ContentView.swift:201`): it becomes "Last sync: 9:22:15 AM L".

### 3.8 The pilot's own clocks

- **Location card:**
  - "Current time: 3:45 PM" becomes "Current time in Taipei: 3:45 PM".
  - In flight, the clock beside the location icon (the arrival airport's time) stays as it is: the airport's code is already under it.
  - Code: `PilotStatusView` in the app; `ui/LocationCard.tsx` on the website.
- **Sun dial:**
  - A small caption, "Taipei time", goes under the dial on the status screen. The dial's own labels ("6:41a") stay as they are.
  - The city comes from the status's current city. With none known, the caption says "Pilot's time".
  - Code: `PilotStatusView`, and `ui/SunDial.tsx` on the website.
- **Sun detail screen:** the pilot's clock reads "3:45 PM Taipei". The home clock keeps its house symbol, which already says whose time it is.
- **Already-formatted times:** when the app only has `localTimeAtPilot`, the string from the pilot's device, it shows as it is.

## 4. Data and behaviour

- **No new data.** The zones are already on hand. The airport's `timeZone` on `MapLeg`'s ends covers the trip map. On the status screen, `SharedPilotStatus.currentTimezone` covers the pilot and the home airport's zone covers home.
- **City names** come from the same place the facts already get them (`leg.destination.name`, `leg.origin.name`). The pilot's city comes from the status's current airport.
- **Unknown zone:** when a place's zone is unknown, the time is shown in L time instead of an unlabelled guess.

## 5. Testing

- **The shared cases** (§3.1) hold `ClockLabel` and `clockLabel.ts` to the same words. Each side runs every case.
- **Unit tests** in the app (`ClockLabelTests`, plus updated wording tests) and on the website cover:
  - every row in the tables of §3.2 and §3.7;
  - the takeoff row's three forms;
  - `isCurrent`: live, in a replay, an estimated newest event, and older sections;
  - the key's long name in winter and summer.
- **Existing tests that expect "your time", "there" or "EST"** are changed to the new words. That's the trip map wording tests, the facts tests and the narrative tests. The VoiceOver sentences keep "your time".
- **`alert-cases.json` doesn't change**, and neither does any alert test.
- **Previews:** the existing "Full screen, real plane" and "Across the date line" previews show the takeoff row, the bold current event and the key. Todd looks at them, then checks it all on a real flight.

## 6. Not in this change

- **Lock-screen alerts** (`AlertWording`, `AlertPushWriter`, `StatusChangeNotifier`). Crewlu Cloud's partner-push shares their wording rules through `alert-cases.json`, and a lock screen has no key to explain the L.
- **The sun dial's own small labels.** They keep their short form. The caption names whose time they are.
- **The diagnostics screen** and debug logs.

## 7. Release note

A family sees this, so it gets a release note when it ships. The version and build are Todd's call.

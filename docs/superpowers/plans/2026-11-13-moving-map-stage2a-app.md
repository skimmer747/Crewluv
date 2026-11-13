# Moving Map Stage 2A (Crewluve App) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the trip map its facts: what's below the plane and when it crosses somewhere new, the sun and moon from the cockpit, distance and comparisons, weather on landing, the trip so far, a forecast of a trip ahead, and a recap. They show in a sheet you drag up on iPhone, a side panel on iPad and in landscape, the card's chip, and a recap card.

**Architecture:**
- **Pure logic** goes in `nonisolated` value types in `Services/TripMap/Facts/`, each with XCTest:
  - `Geography` reads the bundled `geography.json`;
  - `LegStory` works out each flight's places and closest point to home once, as fractions along the route;
  - `Milestone`, `SkyFacts`, `MoonPosition`, `TripTotals` and `ComparisonPicker` are the other facts;
  - `TripFacts` answers every question at any moment, and `FactsWording` holds every sentence.
- **Two `@MainActor @Observable` models:**
  - `LegStoryStore`, owned by the status screen, builds stories off the main actor and caches them;
  - `LandingWeather` fetches landing-hour forecasts while the full-screen map is open.
- **Views** in `Views/TripMap/` render what `TripFacts` says:
  - `FactsSheet` (SwiftUI's sheet with detents);
  - `FactsPanel` (the side panel);
  - `FactRowView`, `TripSoFarList`, `TripRecapBar`.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` in the app target (not in the test target), iOS 26, SwiftUI, MapKit for SwiftUI, WeatherKit, XCTest. Node (no npm packages) for the data script.

**Spec:** `docs/superpowers/specs/2026-11-13-crewluve-moving-map-stage2-facts-design.md` ("the Stage 2 spec"), which refines `2026-11-13-crewluve-moving-map-design.md` ("the map spec"). This plan is Stage 2A, the app. Stage 2B, the website, gets its own plan after Stage 1B is merged.

**Where this plan settles details the spec left open, or differs from it in small ways:**
- **Moon names:** `FactsWording.moonName` writes them in sentence case ("Waxing gibbous moon"). The spec named `MoonPhase.displayName`, but that's in title case ("Waxing Gibbous") and isolated to the main actor in `WeatherService.swift`.
- **The sheet's small stop:** a `@ScaledMetric` height, 160 pt at the default text size, grown with Dynamic Type. The spec had it measured from the header, but a detent whose height changes as it's measured changes identity, which breaks the sheet's `selection` binding.
- **The row view's name:** `FactRowView`. `FactRow` is the row's data.
- **Temperatures:** "48°F" (`.abbreviated`). The location card shows "48°" (`.narrow`).
- **Place names:** countries come from Natural Earth's English names (`NAME_EN`) through a short rename table, and states and provinces keep Natural Earth's own: "Newfoundland and Labrador", "Québec".
- **`FactsHeader`:** the iPhone sheet's top only. The side panel lays out its headline, chevron and pinned timeline itself.

---

## Ground rules for whoever runs this plan

These come from Todd's standing instructions. They override the skill's defaults.

1. **Don't run `xcodebuild` build or test loops,** and don't let subagents run them. Write the code and tests. At each task's checkpoint, Todd runs the named tests in Xcode, or with the command below.
2. **Never commit without Todd's go-ahead in the conversation.** Each task ends with a suggested commit message. Ask, then commit only on a yes, and only the task's own files.
3. **After a commit that changes what families see** (Tasks 19–21), draft the "Crewluve revisions" Apple Note entry as the release-notes memory describes, and confirm the version with Todd.
4. **New files join the app target on their own.** `Crewluv/` is a synchronized folder, and the JSON files in `Crewluv/Resources/TripMap/` become app resources the same way. Don't tick `CrewluveAlerts` on any new file: the helper doesn't use the map.
5. **Mark pure types `nonisolated`** (`nonisolated struct` / `nonisolated enum`), as `TripMap` and `SolarPosition` are. An extension of a pure type in another file is written `nonisolated extension`, or its members default to the main actor and the tests can't call them.
6. **Tests use XCTest,** named `test_<methodOrBehavior>_<scenario>_<expectedResult>()`, with `XCTAssertEqual` over `XCTAssertTrue`.
7. **Downloading the Natural Earth files has Todd's OK** from the design (Stage 2 spec §9.1). Still say so in the conversation just before Task 2 downloads them.
8. **Reviewers:** dispatch `superpowers:code-reviewer` with `model: "sonnet"`.
9. **Work on `feature/trip-map-facts`,** never on `main` (Task 1). The checkout is shared with other sessions, so commit only this plan's files.

Test command for Todd, one class per checkpoint:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:CrewluvTests/<TestClass>
```

## File map

| File | Status | Responsibility |
|---|---|---|
| `scripts/build-geography.mjs` | create | Natural Earth → `geography.json` |
| `scripts/natural-earth/` | create, ignored | the four downloaded GeoJSON files |
| `.gitignore` | modify | ignore `scripts/natural-earth/` |
| `Crewluv/Resources/TripMap/geography.json` | create (generated) | states, provinces, countries, waters, cities |
| `Crewluv/Resources/TripMap/comparisons.json` | create | the eleven comparisons |
| `Crewluv/Services/TripMap/Facts/ComparisonPicker.swift` | create | "Like driving coast to coast" |
| `Crewluv/Services/TripMap/Facts/Geography.swift` | create | what's under a point; nearby cities |
| `Crewluv/Services/TripMap/FlightProgress.swift` | modify | `scheduledTime(atFraction:…)` |
| `Crewluv/Services/TripMap/MapLeg.swift` | modify | `time(atFraction:)` |
| `Crewluv/Services/TripMap/Facts/LunarPhase.swift` | create | the moon's eight phases |
| `Crewluv/Services/TripMap/Facts/MoonPosition.swift` | create | phase, sub-lunar point, altitude |
| `Crewluv/Services/TripMap/Facts/LegStory.swift` | create | a flight's places and closest point to home |
| `Crewluv/Services/TripMap/Facts/Milestone.swift` | create | crossings, halfway, closest to home, as times |
| `Crewluv/Services/TripMap/Facts/SkyFacts.swift` | create | cockpit sun events, people below, chasing the sun, the moon, ground sun events |
| `Crewluv/Services/TripMap/Facts/TripTotals.swift` | create | cities, miles, time zones, cockpit sunsets, longest flight |
| `Crewluv/Services/TripMap/Facts/LandingForecast.swift` | create | a landing-hour forecast |
| `Crewluv/Services/TripMap/Facts/RecapTile.swift` | create | one number on the recap card |
| `Crewluv/Services/TripMap/Facts/FactsWording.swift` | create | milestone, below, sky, distance and landing sentences |
| `Crewluv/Services/TripMap/Facts/FactsWording+Trip.swift` | create | totals, trip, recap sentences |
| `Crewluv/Services/TripMap/TripMapWording.swift` | modify | helpers made internal; `.recap` |
| `Crewluv/Services/TripMap/TripMap.swift` | modify | `.recap` mode, `tripDays`, `dayCount(in:)` |
| `Crewluv/Services/TripMap/TripMap+Status.swift` | modify | choose the recap's trip |
| `Crewluv/Services/TripMap/TripReplayClock.swift` | modify | start paused at a moment |
| `Crewluv/Services/TripMap/Facts/FactRow.swift` | create | one row of the sheet |
| `Crewluv/Services/TripMap/Facts/TripSoFar.swift` | create | the sheet's tall stop |
| `Crewluv/Services/TripMap/Facts/TripFacts.swift` | create | headline, card summary, trip so far, recap numbers |
| `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift` | create | the rows in flight, on a layover, at home and in the recap |
| `Crewluv/Services/TripMap/Facts/LegStoryStore.swift` | create | builds and caches stories and sun events |
| `Crewluv/Services/TripMap/Facts/LandingWeather.swift` | create | which flights get weather, and fetching it |
| `Crewluv/Services/WeatherService.swift` | modify | `landingForecast(forAirport:latitude:longitude:at:)` |
| `Crewluv/Views/TripMap/FactRowView.swift` | create | a row: symbol, title, detail |
| `Crewluv/Views/TripMap/FactsHeader.swift` | create | the sheet's headline and timeline |
| `Crewluv/Views/TripMap/FactsBody.swift` | create | the rows, trip so far and footer |
| `Crewluv/Views/TripMap/TripSoFarList.swift` | create | milestones by flight, then totals |
| `Crewluv/Views/TripMap/FactsFooter.swift` | create | "Estimated from the schedule", weather attribution |
| `Crewluv/Views/TripMap/FactsSheet.swift` | create | the iPhone sheet |
| `Crewluv/Views/TripMap/FactsPanel.swift` | create | the side panel |
| `Crewluv/Views/TripMap/TripMapPanel.swift` | delete | replaced by the sheet and panel |
| `Crewluv/Views/TripMap/TripMapScreen.swift` | modify | sheet or panel, weather, recap start, Close |
| `Crewluv/Views/TripMap/TripMapCard.swift` | modify | headline chip, recap, story store |
| `Crewluv/Views/TripMap/TripMapChip.swift` | modify | optional symbol |
| `Crewluv/Views/TripMap/TripRecapBar.swift` | create | the recap's tiles and longest flight |
| `Crewluv/Views/TripMap/TripMapPreviews.swift` | modify | story store; a recap preview |
| `Crewluv/Views/Status/PilotStatusView.swift` | modify | owns the `LegStoryStore` |
| `CrewluvTests/Fixtures/TripMap/facts-cases.json` | create | the shared facts cases (2B copies them) |
| `CrewluvTests/Helpers/TripMapFixtures.swift` | modify | reads the facts cases |
| `CrewluvTests/Helpers/FactsTestData.swift` | create | test geography, legs along the equator |
| `CrewluvTests/Helpers/TripMapTestLegs.swift` | modify | a `tripTotalDays` parameter |
| `CrewluvTests/*Tests.swift` | create or modify | one class per type above |
| `CLAUDE.md` | modify | the facts in Key Components and File Structure |

## Batches

Review with `superpowers:code-reviewer` (sonnet) after each batch, then Todd runs that batch's tests:

- **A, data and maths:** Tasks 2–6.
- **B, the stories:** Tasks 7–10.
- **C, words and the recap:** Tasks 11–15.
- **D, models and weather:** Tasks 16–17.
- **E, views:** Tasks 18–21.

---

### Task 1: Before starting

**Files:** none.

- [ ] **Step 1: Check the branch and the tree.** Stage 1 and the mid-trip-at-home fix (`8d02c08`) are merged into `main` (PR #4, `984e87c`). Stage 2A goes on its own branch, `feature/trip-map-facts`, which this plan's own commit may already have made.

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current
```

  - If the branch is `feature/trip-map-facts`, stay on it.
  - If it's `main`, make the branch: `git -C /Users/toddanderson/Dev/Crewluv switch -c feature/trip-map-facts`.
  - Anything else: stop and ask Todd.
  - Other changed files that aren't this plan's are left alone. Another session may share this checkout.

---

### Task 2: `geography.json` from Natural Earth

The facts look up what's under the plane in a bundled file (Stage 2 spec §4.1, §9.1). This task writes the script, downloads its sources, and makes the file.

**Files:**
- Create: `scripts/build-geography.mjs`
- Create (generated): `Crewluv/Resources/TripMap/geography.json`
- Modify: `.gitignore`

- [ ] **Step 1: Ignore the sources.** Add to the end of `/Users/toddanderson/Dev/Crewluv/.gitignore`:

```gitignore

# Natural Earth sources for scripts/build-geography.mjs (public domain, downloaded, not committed)
scripts/natural-earth/
```

- [ ] **Step 2: Say you're about to download, then download.** Tell Todd in one line: "Downloading the four Natural Earth GeoJSON files (about 10 MB, public domain) from nvkelso/natural-earth-vector v5.1.2, as approved." Then:

```bash
mkdir -p /Users/toddanderson/Dev/Crewluv/scripts/natural-earth && cd /Users/toddanderson/Dev/Crewluv/scripts/natural-earth && for name in ne_50m_admin_0_countries ne_50m_admin_1_states_provinces ne_50m_geography_marine_polys ne_10m_populated_places_simple; do curl -fsSLO "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/$name.geojson" || echo "FAILED $name"; done; ls -l
```

  - Expected: four `.geojson` files, each over 100 KB, and no `FAILED` line.

- [ ] **Step 3: Write the script.** Create `scripts/build-geography.mjs`:

```js
// Writes Crewluv/Resources/TripMap/geography.json (moving map Stage 2 spec §9.1): US states, Canadian provinces,
// countries, named seas and oceans, and cities of a million or more, from Natural Earth (public domain).
// Reads scripts/natural-earth/*.geojson (downloaded, not committed). Run: node scripts/build-geography.mjs
import { readFileSync, writeFileSync } from 'node:fs'

const read = name => JSON.parse(readFileSync(new URL(`./natural-earth/${name}.geojson`, import.meta.url), 'utf8'))
const target = new URL('../Crewluv/Resources/TripMap/geography.json', import.meta.url)
const largestFile = 500_000

// Natural Earth's field names are upper case in some files and lower case in others.
const field = (feature, key) => feature.properties[key] ?? feature.properties[key.toUpperCase()] ?? feature.properties[key.toLowerCase()]

// Countries whose names read with "the": "Over the Netherlands".
const withThe = new Set([
  'United States', 'United Kingdom', 'Netherlands', 'Philippines', 'Bahamas', 'Gambia', 'Maldives', 'Marshall Islands',
  'Solomon Islands', 'Comoros', 'Seychelles', 'Czech Republic', 'Dominican Republic', 'Central African Republic',
  'Democratic Republic of the Congo', 'Republic of the Congo', 'United Arab Emirates', 'Faroe Islands', 'Falkland Islands',
  'Cayman Islands', 'Cook Islands', 'Turks and Caicos Islands', 'British Virgin Islands', 'United States Virgin Islands',
  'Northern Mariana Islands', 'Vatican City',
])
const renamed = {
  'United States of America': 'United States',
  "People's Republic of China": 'China',
  'Federated States of Micronesia': 'Micronesia',
}
const oceans = {
  'North Atlantic Ocean': 'the Atlantic', 'South Atlantic Ocean': 'the Atlantic',
  'North Pacific Ocean': 'the Pacific', 'South Pacific Ocean': 'the Pacific',
  'Indian Ocean': 'the Indian Ocean', 'Arctic Ocean': 'the Arctic Ocean', 'Southern Ocean': 'the Southern Ocean',
}

function countryName(raw) {
  const name = renamed[raw] ?? raw.replace(/^The /, '')
  return withThe.has(name) ? `the ${name}` : name
}

function waterName(raw) {
  return oceans[raw] ?? `the ${raw.replace(/^The /, '')}`
}

// A polygon's or multipolygon's rings, outer and holes alike: the app tests them even-odd.
function ringsOf(geometry) {
  if (geometry?.type === 'Polygon') return geometry.coordinates
  if (geometry?.type === 'MultiPolygon') return geometry.coordinates.flat()
  return []
}

function perpendicular(point, start, end) {
  const dx = end[0] - start[0], dy = end[1] - start[1]
  const length = Math.hypot(dx, dy)
  if (length === 0) return Math.hypot(point[0] - start[0], point[1] - start[1])
  return Math.abs(dy * point[0] - dx * point[1] + end[0] * start[1] - end[1] * start[0]) / length
}

// Douglas–Peucker on an open line.
function simplifyLine(points, tolerance) {
  if (points.length < 3) return points
  let index = 0, farthest = 0
  for (let i = 1; i < points.length - 1; i++) {
    const distance = perpendicular(points[i], points[0], points[points.length - 1])
    if (distance > farthest) { farthest = distance; index = i }
  }
  if (farthest <= tolerance) return [points[0], points[points.length - 1]]
  const left = simplifyLine(points.slice(0, index + 1), tolerance)
  const right = simplifyLine(points.slice(index), tolerance)
  return [...left.slice(0, -1), ...right]
}

// A closed ring, split at the point farthest from its start so each half is an open line.
function simplifyRing(ring, tolerance) {
  const open = ring.slice(0, -1)
  if (open.length < 4) return open.length >= 3 ? open : null
  let split = 0, farthest = 0
  open.forEach((point, i) => {
    const distance = Math.hypot(point[0] - open[0][0], point[1] - open[0][1])
    if (distance > farthest) { farthest = distance; split = i }
  })
  const first = simplifyLine(open.slice(0, split + 1), tolerance)
  const second = simplifyLine([...open.slice(split), open[0]], tolerance)
  const rounded = [...first.slice(0, -1), ...second.slice(0, -1)]
    .map(([lon, lat]) => [Math.round(lon * 100) / 100, Math.round(lat * 100) / 100])
    .filter((point, i, all) => i === 0 || point[0] !== all[i - 1][0] || point[1] !== all[i - 1][1])
  return rounded.length >= 3 ? rounded : null
}

function area(name, kind, country, geometry, tolerance) {
  const rings = ringsOf(geometry).map(ring => simplifyRing(ring, tolerance)).filter(Boolean)
  if (rings.length === 0) return null
  const points = rings.flat()
  const box = [
    Math.min(...points.map(p => p[0])), Math.min(...points.map(p => p[1])),
    Math.max(...points.map(p => p[0])), Math.max(...points.map(p => p[1])),
  ]
  return { name, kind, ...(country ? { country } : {}), box, rings: rings.map(ring => ring.flat()) }
}

const countries = read('ne_50m_admin_0_countries').features
const regions = read('ne_50m_admin_1_states_provinces').features.filter(f => ['US', 'CA'].includes(field(f, 'iso_a2')))
const waters = read('ne_50m_geography_marine_polys').features.filter(f => field(f, 'name'))
const cities = read('ne_10m_populated_places_simple').features
  .filter(f => Number(field(f, 'pop_max')) >= 1_000_000)
  .map(f => ({
    name: field(f, 'name'),
    lat: Math.round(f.geometry.coordinates[1] * 100) / 100,
    lon: Math.round(f.geometry.coordinates[0] * 100) / 100,
  }))

function build(tolerance) {
  const areas = [
    ...regions.map(f => {
      const isUS = field(f, 'iso_a2') === 'US'
      return area(field(f, 'name'), isUS ? 'state' : 'province', isUS ? 'the United States' : 'Canada', f.geometry, tolerance)
    }),
    ...countries.map(f => area(countryName(field(f, 'name_en') ?? field(f, 'name')), 'country', null, f.geometry, tolerance)),
    ...waters.map(f => area(waterName(field(f, 'name')), 'water', null, f.geometry, tolerance)),
  ].filter(Boolean)
  return { source: 'Natural Earth 1:50m and 1:10m, v5.1.2, public domain', areas, cities }
}

let tolerance = 0.01
let geography = build(tolerance)
let json = JSON.stringify(geography)
while (json.length > largestFile) {
  tolerance *= 1.25
  geography = build(tolerance)
  json = JSON.stringify(geography)
}
writeFileSync(target, json)

const count = kind => geography.areas.filter(a => a.kind === kind).length
console.log(`geography.json: ${count('state')} states, ${count('province')} provinces, ${count('country')} countries, ` +
  `${count('water')} waters, ${geography.cities.length} cities; tolerance ${tolerance.toFixed(3)}°; ${json.length} bytes`)
console.log('Countries:', geography.areas.filter(a => a.kind === 'country').map(a => a.name).join(', '))
```

- [ ] **Step 4: Run it.**

```bash
mkdir -p /Users/toddanderson/Dev/Crewluv/Crewluv/Resources/TripMap && node /Users/toddanderson/Dev/Crewluv/scripts/build-geography.mjs
```

  - Expected: a line like `geography.json: 51 states, 13 provinces, 2xx countries, 2xx waters, 5xx cities; tolerance 0.0xx°; 49xxxx bytes`, then the country names.
  - Read the country names for odd ones: an abbreviation like "Dem. Rep. Congo", or a missing "the". Fix them in `renamed` or `withThe` and run again.
  - Then check these names are present:

```bash
cd /Users/toddanderson/Dev/Crewluv && for name in '"Kansas"' '"Ontario"' '"Germany"' '"the Netherlands"' '"the Labrador Sea"' '"the Atlantic"' '"the Pacific"' '"the Bay of Biscay"' '"Montréal"' '"New York"'; do grep -q "$name" Crewluv/Resources/TripMap/geography.json && echo "ok $name" || echo "MISSING $name"; done
```

  - Expected: ten `ok` lines. If one is missing, look up what Natural Earth calls it, and tell Todd before changing `facts-cases.json` (Task 15), which expects these names.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): geography.json for the trip map's facts, from Natural Earth, and the script that makes it (Stage 2 spec §9.1)`. The files are `.gitignore`, `scripts/build-geography.mjs` and `Crewluv/Resources/TripMap/geography.json`.

---

### Task 3: `comparisons.json` and `ComparisonPicker`

"Like driving coast to coast" (Stage 2 spec §4.9, §9.2).

**Files:**
- Create: `Crewluv/Resources/TripMap/comparisons.json`
- Create: `Crewluv/Services/TripMap/Facts/ComparisonPicker.swift`
- Test: `CrewluvTests/ComparisonPickerTests.swift`

- [ ] **Step 1: Write the data.** Create `Crewluv/Resources/TripMap/comparisons.json`:

```json
[
  {"miles": 26.2, "one": "Like running a marathon", "many": "Like running {n} marathons"},
  {"miles": 51, "one": "Like sailing the Panama Canal", "many": "Like sailing the Panama Canal {times}"},
  {"miles": 277, "one": "Like rafting the Grand Canyon", "many": "Like rafting the Grand Canyon {times}"},
  {"miles": 880, "one": "Like driving across Texas", "many": "Like driving across Texas {times}"},
  {"miles": 1390, "one": "Like driving the Alaska Highway", "many": "Like driving the Alaska Highway {times}"},
  {"miles": 2340, "one": "Like floating down the Mississippi", "many": "Like floating down the Mississippi {times}"},
  {"miles": 2800, "one": "Like driving coast to coast", "many": "Like driving coast to coast {times}"},
  {"miles": 4130, "one": "Like sailing the length of the Nile", "many": "Like sailing the length of the Nile {times}"},
  {"miles": 5500, "one": "Like walking the Great Wall of China", "many": "Like walking the Great Wall of China {times}"},
  {"miles": 7918, "one": "Like digging straight through the Earth", "many": "Like digging straight through the Earth {times}"},
  {"miles": 24901, "one": "Like going once around the Earth", "many": "Like going around the Earth {times}"}
]
```

- [ ] **Step 2: Write the failing tests.** Create `CrewluvTests/ComparisonPickerTests.swift`:

```swift
//
//  ComparisonPickerTests.swift
//  CrewluvTests
//
//  Picking a comparison for a distance (Stage 2 spec §4.9), from the app's comparisons.json.
//

import XCTest
@testable import Crewluv

final class ComparisonPickerTests: XCTestCase {

    private func picker() throws -> ComparisonPicker {
        let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Crewluv/Resources/TripMap/comparisons.json")
        return try ComparisonPicker(data: Data(contentsOf: url))
    }

    func test_init_theAppsFile_hasElevenEntries() throws {
        XCTAssertEqual(try picker().entries.count, 11)
    }

    func test_phrase_aboutOnce_usesTheOnePhrase() throws {
        XCTAssertEqual(try picker().phrase(forMiles: 4_100), "Like sailing the length of the Nile")
        XCTAssertEqual(try picker().phrase(forMiles: 2_980), "Like driving coast to coast")
    }

    func test_phrase_twice_saysTwice() throws {
        XCTAssertEqual(try picker().phrase(forMiles: 600), "Like rafting the Grand Canyon twice")
    }

    func test_phrase_severalTimes_saysTheCount() throws {
        XCTAssertEqual(try picker().phrase(forMiles: 9_800), "Like driving the Alaska Highway 7 times")
        XCTAssertEqual(try picker().phrase(forMiles: 200), "Like sailing the Panama Canal 4 times")
    }

    func test_phrase_marathons_putsTheNumberInTheMiddle() {
        let picker = ComparisonPicker(entries: [.init(miles: 26.2, one: "Like running a marathon", many: "Like running {n} marathons")])
        XCTAssertEqual(picker.phrase(forMiles: 26.2 * 7), "Like running 7 marathons")
    }

    func test_phrase_noEntryOneToTenTimes_isNil() throws {
        XCTAssertNil(try picker().phrase(forMiles: 10))
        XCTAssertNil(try picker().phrase(forMiles: 300_000))
    }

    func test_phrase_aHalf_goesToTheSmallerNumber() {
        let picker = ComparisonPicker(entries: [.init(miles: 100, one: "Once", many: "{n} times")])
        XCTAssertEqual(picker.phrase(forMiles: 150), "Once")
        XCTAssertEqual(picker.phrase(forMiles: 151), "2 times")
    }

    func test_phrase_aTie_goesToTheSmallerNumberThenTheEarlierEntry() {
        let picker = ComparisonPicker(entries: [
            .init(miles: 100, one: "A once", many: "A {n}"),
            .init(miles: 50, one: "B once", many: "B {n}"),
            .init(miles: 100, one: "C once", many: "C {n}"),
        ])
        // 200 mi is exactly 2 × A, 4 × B and 2 × C: the smaller number wins, then the earlier entry.
        XCTAssertEqual(picker.phrase(forMiles: 200), "A 2")
    }

    func test_times_twoIsTwice() {
        XCTAssertEqual(ComparisonPicker.times(2), "twice")
        XCTAssertEqual(ComparisonPicker.times(3), "3 times")
    }
}
```

- [ ] **Step 3: Run them, expecting a build failure** (`ComparisonPicker` doesn't exist). Todd runs `ComparisonPickerTests`.

- [ ] **Step 4: Write `ComparisonPicker`.** Create `Crewluv/Services/TripMap/Facts/ComparisonPicker.swift`:

```swift
//
//  ComparisonPicker.swift
//  CrewLuve
//
//  What a distance is like (Stage 2 spec §4.9): "Like driving coast to coast", "Like rafting the Grand Canyon twice".
//  The entries are the app's comparisons.json, which the website shares.
//

import Foundation

nonisolated struct ComparisonPicker: Sendable {

    nonisolated struct Entry: Decodable, Sendable {
        let miles: Double
        /// Used once: "Like driving coast to coast".
        let one: String
        /// Used 2 to 10 times. `{n}` is the number and `{times}` is "twice" or "3 times".
        let many: String
    }

    let entries: [Entry]

    init(entries: [Entry]) {
        self.entries = entries
    }

    init(data: Data) throws {
        entries = try JSONDecoder().decode([Entry].self, from: data)
    }

    /// The app's copy, or nil (logged) if it's missing or unreadable.
    static func loadBundled(from bundle: Bundle = .main) -> ComparisonPicker? {
        guard let url = bundle.url(forResource: "comparisons", withExtension: "json") else {
            debugLog("ComparisonPicker: comparisons.json isn't in the bundle")
            return nil
        }
        do {
            return try ComparisonPicker(data: Data(contentsOf: url))
        } catch {
            debugLog("ComparisonPicker: couldn't read comparisons.json: \(error)")
            return nil
        }
    }

    /// The entry whose multiple is closest to a whole number from 1 to 10. Ties go to the smaller number, then to the
    /// earlier entry. Nil when no entry fits.
    func phrase(forMiles miles: Double) -> String? {
        var best: (entry: Entry, count: Int, error: Double)?
        for entry in entries where entry.miles > 0 {
            let multiple = miles / entry.miles
            // The nearest whole number, with a half going to the smaller one.
            let count = Int((multiple - 0.5).rounded(.up))
            guard (1...10).contains(count) else { continue }
            let error = abs(multiple - Double(count))
            if let current = best, error > current.error || (error == current.error && count >= current.count) { continue }
            best = (entry, count, error)
        }
        guard let best else { return nil }
        guard best.count > 1 else { return best.entry.one }
        return best.entry.many
            .replacingOccurrences(of: "{n}", with: "\(best.count)")
            .replacingOccurrences(of: "{times}", with: Self.times(best.count))
    }

    /// "twice", "3 times".
    static func times(_ count: Int) -> String {
        count == 2 ? "twice" : "\(count) times"
    }
}
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `ComparisonPickerTests`.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): comparisons.json and ComparisonPicker, "Like driving coast to coast" (Stage 2 spec §4.9, §9.2)`.

---
### Task 4: `Geography`

What's under a point (Stage 2 spec §4.1): a state or province, else a country, else a named water, and a city of a million or more within 40 mi. This task also adds the tests' shared helpers.

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/Geography.swift`
- Create: `CrewluvTests/Helpers/FactsTestData.swift`
- Test: `CrewluvTests/GeographyTests.swift`

- [ ] **Step 1: Write the test helpers.** Create `CrewluvTests/Helpers/FactsTestData.swift`:

```swift
//
//  FactsTestData.swift
//  CrewluvTests
//
//  Made-up places along the equator, where a fraction of the way is a fraction of the longitude, and flights across
//  them at the March equinox: the facts' tests can then be worked out by hand (Stage 2 spec §12).
//

import CoreLocation
@testable import Crewluv

enum FactsTestData {

    /// A rectangle a degree either side of the equator.
    static func box(_ name: String, _ kind: Geography.Kind, country: String? = nil,
                    west: Double, east: Double, south: Double = -1, north: Double = 1) -> Geography.Area {
        Geography.Area(name: name, kind: kind, country: country, box: [west, south, east, north],
                       rings: [[west, south, east, south, east, north, west, north]])
    }

    /// Along the equator: Alpha to 5° E; Bravo to 12° E, with a Wedge 0.3° (about 21 mi) wide at 9° E that the hold rule
    /// drops; then the Test Sea to 21° E. Testville sits 0.3° north of 6° E.
    static let equator = Geography(
        areas: [
            box("Wedge", .country, west: 9, east: 9.3),
            box("Alpha", .country, west: -1, east: 5),
            box("Bravo", .country, west: 5, east: 12),
            box("the Test Sea", .water, west: 12, east: 21),
        ],
        cities: [Geography.City(name: "Testville", lat: 0.3, lon: 6)]
    )

    static func mark(_ code: String, latitude: Double, longitude: Double, city: String? = nil, zone: String? = nil) -> AirportMark {
        AirportMark(code: code, city: city, coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    timeZone: zone.flatMap(TimeZone.init(identifier:)))
    }

    /// 2026-03-20 10:00 UTC, the March equinox: 6:00 AM in Louisville.
    static let equinox = Date(timeIntervalSince1970: 1_774_000_800)

    /// A flight along the equator from `west`° to `east`° longitude: 3 h 22 min from gate to gate, so in the air from
    /// 10:15 to 13:15 UTC with the taxi allowances, a tenth of the way every 18 minutes.
    static func equatorFlight(from west: Double, to east: Double, departure: Date = equinox, id: String = "eq") -> MapLeg {
        MapLeg(id: id, kind: .flight,
               origin: mark("E\(Int(west))", latitude: 0, longitude: west),
               destination: mark("E\(Int(east))", latitude: 0, longitude: east),
               start: departure, end: departure.addingTimeInterval(202 * 60), flightNumber: "TST1")
    }

    static func date(_ iso: String) -> Date {
        ISO8601DateFormatter().date(from: iso)!
    }

    private static let repository = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The app's geography.json, read from the repository on the Mac's disk.
    static func appGeography() throws -> Geography {
        try Geography(data: Data(contentsOf: repository.appending(path: "Crewluv/Resources/TripMap/geography.json")))
    }

    static func appComparisons() throws -> ComparisonPicker {
        try ComparisonPicker(data: Data(contentsOf: repository.appending(path: "Crewluv/Resources/TripMap/comparisons.json")))
    }
}
```

- [ ] **Step 2: Write the failing tests.** Create `CrewluvTests/GeographyTests.swift`:

```swift
//
//  GeographyTests.swift
//  CrewluvTests
//
//  What's under a point (Stage 2 spec §4.1).
//

import XCTest
import CoreLocation
@testable import Crewluv

final class GeographyTests: XCTestCase {

    private func at(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func test_place_aStateInsideItsCountry_givesTheState() {
        let geography = Geography(areas: [
            FactsTestData.box("Delta", .country, west: 0, east: 10),
            FactsTestData.box("North", .state, country: "Delta", west: 0, east: 5),
        ], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 2)), Geography.Place(name: "North", kind: .state, country: "Delta"))
        XCTAssertEqual(geography.place(at: at(0, 7)), Geography.Place(name: "Delta", kind: .country, country: "Delta"))
    }

    func test_place_landBeforeWater() {
        let geography = Geography(areas: [
            FactsTestData.box("the Sea", .water, west: 0, east: 10),
            FactsTestData.box("Island", .country, west: 4, east: 6),
        ], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 5))?.name, "Island")
        XCTAssertEqual(geography.place(at: at(0, 8)), Geography.Place(name: "the Sea", kind: .water, country: nil))
    }

    func test_place_outsideEverything_isNil() {
        XCTAssertNil(FactsTestData.equator.place(at: at(10, 5)))
    }

    func test_place_inAHole_isOutside() {
        let ringed = Geography.Area(name: "Ring", kind: .country, country: nil, box: [0, -5, 10, 5],
                                    rings: [[0, -5, 10, -5, 10, 5, 0, 5], [4, -1, 6, -1, 6, 1, 4, 1]])
        let geography = Geography(areas: [ringed], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 2))?.name, "Ring")
        XCTAssertNil(geography.place(at: at(0, 5)), "the hole")
    }

    func test_place_twoSeparateRings_bothCount() {
        let twoParts = Geography.Area(name: "Islands", kind: .country, country: nil, box: [0, -1, 20, 1],
                                      rings: [[0, -1, 2, -1, 2, 1, 0, 1], [18, -1, 20, -1, 20, 1, 18, 1]])
        let geography = Geography(areas: [twoParts], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 1))?.name, "Islands")
        XCTAssertEqual(geography.place(at: at(0, 19))?.name, "Islands")
        XCTAssertNil(geography.place(at: at(0, 10)))
    }

    func test_place_aLongitudePastTheDateLine_isWrapped() {
        let geography = Geography(areas: [FactsTestData.box("East", .country, west: -175, east: -165)], cities: [])
        XCTAssertEqual(geography.place(at: at(0, 190))?.name, "East")
    }

    func test_city_within40Miles_isTheNearest() {
        let geography = Geography(areas: [], cities: [
            Geography.City(name: "Near", lat: 0.3, lon: 6),
            Geography.City(name: "Nearer", lat: 0.1, lon: 6),
        ])
        XCTAssertEqual(geography.city(near: at(0, 6))?.name, "Nearer")
    }

    func test_city_farther_isNil() {
        // 0.6° of latitude is about 41 mi.
        XCTAssertNil(FactsTestData.equator.city(near: at(-0.3, 6)))
    }

    func test_init_decodesTheFileFormat() throws {
        let json = """
        {"source": "test", "areas": [{"name": "Kansas", "kind": "state", "country": "the United States",
          "box": [-102, 37, -94.6, 40], "rings": [[-102, 37, -94.6, 37, -94.6, 40, -102, 40]]}],
         "cities": [{"name": "Wichita", "lat": 37.69, "lon": -97.34}]}
        """
        let geography = try Geography(data: Data(json.utf8))
        XCTAssertEqual(geography.place(at: at(38.5, -98.5)), Geography.Place(name: "Kansas", kind: .state, country: "the United States"))
        XCTAssertEqual(geography.cities.map(\.name), ["Wichita"])
    }

    func test_appGeography_findsAStateACountryAndASea() throws {
        let geography = try FactsTestData.appGeography()
        XCTAssertEqual(geography.place(at: at(38.5, -98.5))?.name, "Kansas")
        XCTAssertEqual(geography.place(at: at(51.0, 10.0))?.name, "Germany")
        XCTAssertEqual(geography.place(at: at(58.0, -54.0))?.name, "the Labrador Sea")
    }

    /// The tests run inside the app, so its bundle is `Bundle.main`.
    func test_loadBundled_theAppCarriesBothFiles() {
        XCTAssertNotNil(Geography.loadBundled())
        XCTAssertNotNil(ComparisonPicker.loadBundled())
    }
}
```

- [ ] **Step 3: Run them, expecting a build failure.** Todd runs `GeographyTests`.

- [ ] **Step 4: Write `Geography`.** Create `Crewluv/Services/TripMap/Facts/Geography.swift`:

```swift
//
//  Geography.swift
//  CrewLuve
//
//  What's under a point on the earth (Stage 2 spec §4.1): a US state or Canadian province, else a country, else a
//  named sea or ocean, and any city of a million or more within 40 mi. Read from the bundled geography.json, which
//  scripts/build-geography.mjs makes from Natural Earth.
//

import CoreLocation

nonisolated struct Geography: Decodable, Sendable {

    nonisolated enum Kind: String, Decodable, Sendable {
        case state, province, country, water
    }

    /// What's under a point, named as the facts read it: "Kansas", "the Netherlands", "the Labrador Sea".
    nonisolated struct Place: Equatable, Sendable {
        let name: String
        let kind: Kind
        /// The country a state or province is in, or the country itself. Nil over water.
        let country: String?

        var isWater: Bool { kind == .water }
    }

    nonisolated struct Area: Decodable, Sendable {
        let name: String
        let kind: Kind
        /// For a state or province, its country.
        let country: String?
        /// West, south, east and north edges, in degrees.
        let box: [Double]
        /// Each ring as longitude, latitude, longitude, latitude, …
        let rings: [[Double]]

        var place: Place {
            Place(name: name, kind: kind, country: kind == .water ? nil : (country ?? name))
        }

        /// Inside when an odd number of the rings hold the point, so a hole (Lesotho in South Africa) is outside.
        func contains(latitude: Double, longitude: Double) -> Bool {
            guard box.count == 4, longitude >= box[0], latitude >= box[1], longitude <= box[2], latitude <= box[3] else { return false }
            let holding = rings.filter { Self.ring($0, contains: latitude, longitude) }.count
            return holding % 2 == 1
        }

        /// Even-odd ray casting on longitude and latitude, which works for rings that don't cross the date line:
        /// Natural Earth splits its shapes there.
        private static func ring(_ ring: [Double], contains latitude: Double, _ longitude: Double) -> Bool {
            let count = ring.count / 2
            guard count >= 3 else { return false }
            var isInside = false
            var previous = count - 1
            for current in 0..<count {
                let currentLongitude = ring[2 * current], currentLatitude = ring[2 * current + 1]
                let previousLongitude = ring[2 * previous], previousLatitude = ring[2 * previous + 1]
                if (currentLatitude > latitude) != (previousLatitude > latitude) {
                    let crossing = (previousLongitude - currentLongitude) * (latitude - currentLatitude)
                        / (previousLatitude - currentLatitude) + currentLongitude
                    if longitude < crossing { isInside.toggle() }
                }
                previous = current
            }
            return isInside
        }
    }

    nonisolated struct City: Decodable, Sendable {
        let name: String
        let lat: Double
        let lon: Double

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
    }

    /// A city of a million or more this close adds "near Montréal" (§4.1).
    static let cityRadius: Double = 40 * GreatCircle.metersPerMile

    let areas: [Area]
    let cities: [City]
    /// The areas in the order they're tried: states and provinces, then countries, then waters.
    private let lookupOrder: [[Area]]

    init(areas: [Area], cities: [City]) {
        self.areas = areas
        self.cities = cities
        lookupOrder = [
            areas.filter { $0.kind == .state || $0.kind == .province },
            areas.filter { $0.kind == .country },
            areas.filter { $0.kind == .water },
        ]
    }

    private enum CodingKeys: String, CodingKey {
        case areas, cities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(areas: try container.decode([Area].self, forKey: .areas),
                  cities: try container.decodeIfPresent([City].self, forKey: .cities) ?? [])
    }

    init(data: Data) throws {
        self = try JSONDecoder().decode(Geography.self, from: data)
    }

    /// The app's copy, or nil (logged) if it's missing or unreadable.
    static func loadBundled(from bundle: Bundle = .main) -> Geography? {
        guard let url = bundle.url(forResource: "geography", withExtension: "json") else {
            debugLog("Geography: geography.json isn't in the bundle")
            return nil
        }
        do {
            return try Geography(data: Data(contentsOf: url))
        } catch {
            debugLog("Geography: couldn't read geography.json: \(error)")
            return nil
        }
    }

    /// The state or province, else the country, else the named water under `coordinate`, or nil.
    func place(at coordinate: CLLocationCoordinate2D) -> Place? {
        let longitude = Self.wrapped(coordinate.longitude)
        for areas in lookupOrder {
            if let area = areas.first(where: { $0.contains(latitude: coordinate.latitude, longitude: longitude) }) {
                return area.place
            }
        }
        return nil
    }

    /// The nearest city of a million or more within 40 mi.
    func city(near coordinate: CLLocationCoordinate2D) -> City? {
        cities
            .map { (city: $0, meters: GreatCircle.distance(from: coordinate, to: $0.coordinate)) }
            .filter { $0.meters <= Self.cityRadius }
            .min { $0.meters < $1.meters }?
            .city
    }

    /// A longitude within −180..<180.
    private static func wrapped(_ longitude: Double) -> Double {
        let shifted = (longitude + 180).truncatingRemainder(dividingBy: 360)
        return (shifted < 0 ? shifted + 360 : shifted) - 180
    }
}
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `GeographyTests`.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): Geography, what's under the plane: state or province, country, or named water, and a nearby city (Stage 2 spec §4.1)`.

---

### Task 5: Times along a flight

A story keeps fractions along the route. The schedule turns them into times (Stage 2 spec §4.2).

**Files:**
- Modify: `Crewluv/Services/TripMap/FlightProgress.swift` (add after `scheduledFraction`)
- Modify: `Crewluv/Services/TripMap/MapLeg.swift` (add after `progress(at:)`)
- Test: `CrewluvTests/FlightProgressTests.swift` (add at the end of the class)

- [ ] **Step 1: Write the failing tests.** Add inside `final class FlightProgressTests`, before its closing brace:

```swift
    // MARK: - From a fraction to a time (Stage 2 spec §4.2)

    func test_scheduledTime_alongTheWindow_isSteady() {
        let departure = FactsTestData.equinox
        let arrival = departure.addingTimeInterval(202 * 60)
        XCTAssertEqual(FlightProgress.scheduledTime(atFraction: 0, departure: departure, arrival: arrival), departure.addingTimeInterval(15 * 60))
        XCTAssertEqual(FlightProgress.scheduledTime(atFraction: 0.5, departure: departure, arrival: arrival), departure.addingTimeInterval(105 * 60))
        XCTAssertEqual(FlightProgress.scheduledTime(atFraction: 1, departure: departure, arrival: arrival), departure.addingTimeInterval(195 * 60))
    }

    func test_scheduledTime_isTheInverseOfScheduledFraction() throws {
        let departure = FactsTestData.equinox
        let arrival = departure.addingTimeInterval(8 * 3600)
        let time = try XCTUnwrap(FlightProgress.scheduledTime(atFraction: 0.37, departure: departure, arrival: arrival))
        XCTAssertEqual(FlightProgress.scheduledFraction(departure: departure, arrival: arrival, at: time), 0.37, accuracy: 1e-9)
    }

    func test_scheduledTime_aShortBlock_usesTheWholeBlock() {
        let departure = FactsTestData.equinox
        let arrival = departure.addingTimeInterval(20 * 60)
        XCTAssertEqual(FlightProgress.scheduledTime(atFraction: 0.5, departure: departure, arrival: arrival), departure.addingTimeInterval(10 * 60))
    }

    func test_scheduledTime_noBlock_isNil() {
        XCTAssertNil(FlightProgress.scheduledTime(atFraction: 0.5, departure: FactsTestData.equinox, arrival: FactsTestData.equinox))
    }

    func test_mapLegTime_aDrive_isSteadyFromStartToEnd() {
        let drive = MapLeg(id: "d", kind: .drive,
                           origin: FactsTestData.mark("LEX", latitude: 38.04, longitude: -84.61),
                           destination: FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74),
                           start: FactsTestData.equinox, end: FactsTestData.equinox.addingTimeInterval(3600), flightNumber: nil)
        XCTAssertEqual(drive.time(atFraction: 0.25), FactsTestData.equinox.addingTimeInterval(900))
    }
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `FlightProgressTests`.

- [ ] **Step 3: Add the inverse to `FlightProgress`,** after `scheduledFraction(departure:arrival:at:)`:

```swift
    /// When the schedule's plane is `fraction` of the way along its route: the inverse of `scheduledFraction`, for the
    /// facts' milestones (Stage 2 spec §4.2). Nil when the flight has no time in the air.
    static func scheduledTime(atFraction fraction: Double, departure: Date, arrival: Date) -> Date? {
        guard let window = airborneWindow(departure: departure, arrival: arrival) else { return nil }
        return window.start.addingTimeInterval(min(max(fraction, 0), 1) * window.duration)
    }
```

- [ ] **Step 4: Add `time(atFraction:)` to `MapLeg`,** after `progress(at:)`:

```swift
    /// When the schedule has the pilot `fraction` of the way along: in the air for a flight, steadily for a drive.
    func time(atFraction fraction: Double) -> Date? {
        switch kind {
        case .flight:
            return FlightProgress.scheduledTime(atFraction: fraction, departure: start, arrival: end)
        case .drive:
            return start.addingTimeInterval(min(max(fraction, 0), 1) * end.timeIntervalSince(start))
        }
    }
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `FlightProgressTests`.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): the time the schedule's plane reaches a fraction of its route (Stage 2 spec §4.2)`.

---

### Task 6: The moon

Its phase, and whether it's up at the plane (Stage 2 spec §4.5). The phase is the website's `src/time/moon.ts`. The sub-lunar point is `crewlu-globe/src/astro/moon.ts`'s `subLunarPoint`, ported as is.

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/LunarPhase.swift`
- Create: `Crewluv/Services/TripMap/Facts/MoonPosition.swift`
- Test: `CrewluvTests/MoonPositionTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/MoonPositionTests.swift`:

```swift
//
//  MoonPositionTests.swift
//  CrewluvTests
//
//  The moon's phase and position (Stage 2 spec §4.5). The phase dates are the middles of each phase in November
//  2026, by the mean cycle the website uses; the full moon is within two hours of the real one (Nov 24, 14:53 UTC).
//

import XCTest
@testable import Crewluv

final class MoonPositionTests: XCTestCase {

    func test_phase_atTheMiddleOfEachPhase_isThatPhase() {
        let middles: [(String, LunarPhase)] = [
            ("2026-11-09T21:58:00Z", .new),
            ("2026-11-13T14:33:00Z", .waxingCrescent),
            ("2026-11-17T07:09:00Z", .firstQuarter),
            ("2026-11-20T23:44:00Z", .waxingGibbous),
            ("2026-11-24T16:20:00Z", .full),
            ("2026-11-28T08:55:00Z", .waningGibbous),
            ("2026-12-02T01:31:00Z", .lastQuarter),
            ("2026-12-05T18:06:00Z", .waningCrescent),
        ]
        for (iso, phase) in middles {
            XCTAssertEqual(MoonPosition.phase(at: FactsTestData.date(iso)), phase, iso)
        }
    }

    func test_cycle_atTheKnownNewMoon_isZero() {
        XCTAssertEqual(MoonPosition.cycle(at: MoonPosition.knownNewMoon), 0, accuracy: 1e-12)
    }

    func test_subLunarPoint_staysWithinTheMoonsReach() {
        let start = FactsTestData.date("2026-01-01T00:00:00Z")
        for day in 0..<60 {
            let point = MoonPosition.subLunarPoint(at: start.addingTimeInterval(Double(day) * 86_400))
            XCTAssertLessThanOrEqual(abs(point.latitude), 29)
            XCTAssertLessThanOrEqual(abs(point.longitude), 180)
        }
    }

    func test_altitude_aWaxingGibbousEveningOverCologne_isHigh() {
        let altitude = MoonPosition.altitude(latitude: 50.87, longitude: 7.14, at: FactsTestData.date("2026-11-20T21:00:00Z"))
        XCTAssertEqual(altitude, 44.3, accuracy: 2)
    }

    func test_altitude_atDawnOverTheNetherlands_isBelowTheHorizon() {
        let altitude = MoonPosition.altitude(latitude: 51.79, longitude: 4.25, at: FactsTestData.date("2026-11-14T06:38:00Z"))
        XCTAssertEqual(altitude, -45.5, accuracy: 2)
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `MoonPositionTests`.

- [ ] **Step 3: Write `LunarPhase`.** Create `Crewluv/Services/TripMap/Facts/LunarPhase.swift`:

```swift
//
//  LunarPhase.swift
//  CrewLuve
//
//  The moon's eight phases, in order from new moon, as the website's moonPhase names them (Stage 2 spec §4.5).
//

nonisolated enum LunarPhase: Int, CaseIterable, Sendable {
    case new, waxingCrescent, firstQuarter, waxingGibbous, full, waningGibbous, lastQuarter, waningCrescent
}
```

- [ ] **Step 4: Write `MoonPosition`.** Create `Crewluv/Services/TripMap/Facts/MoonPosition.swift`:

```swift
//
//  MoonPosition.swift
//  CrewLuve
//
//  Where the moon is (Stage 2 spec §4.5): its phase from the mean cycle, as the website's src/time/moon.ts works it
//  out, and the point it's straight above, ported from crewlu-globe's subLunarPoint (Paul Schlyter's method, good to
//  a degree or two, which is plenty to say whether it's up).
//

import Foundation

nonisolated enum MoonPosition {

    /// The mean length of the moon's cycle, new moon to new moon, in days.
    static let synodicMonth = 29.530588853

    /// A new moon to count from: 6 January 2000 at 18:14 UTC.
    static let knownNewMoon = Date(timeIntervalSince1970: 947_182_440)

    /// How far through its cycle the moon is: 0 at new moon, 0.5 at full.
    static func cycle(at date: Date) -> Double {
        let cycles = date.timeIntervalSince(knownNewMoon) / 86_400 / synodicMonth
        return cycles - cycles.rounded(.down)
    }

    /// Eight equal parts of the cycle, each centred on its own point.
    static func phase(at date: Date) -> LunarPhase {
        LunarPhase(rawValue: Int((cycle(at: date) * 8 + 0.5).rounded(.down)) % 8) ?? .new
    }

    /// The point on the earth with the moon straight overhead, in degrees, longitude positive east.
    static func subLunarPoint(at date: Date) -> (latitude: Double, longitude: Double) {
        let days = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_543.5
        let node = revolution(125.1228 - 0.0529538083 * days)
        let inclination = 5.1454
        let perigee = revolution(318.0634 + 0.1643573223 * days)
        let meanDistance = 60.2666
        let eccentricity = 0.0549
        let meanAnomaly = revolution(115.3654 + 13.0649929509 * days)

        var eccentricAnomaly = meanAnomaly
            + degrees(eccentricity * sin(radians(meanAnomaly)) * (1 + eccentricity * cos(radians(meanAnomaly))))
        for _ in 0..<4 {
            eccentricAnomaly -= (eccentricAnomaly - degrees(eccentricity * sin(radians(eccentricAnomaly))) - meanAnomaly)
                / (1 - eccentricity * cos(radians(eccentricAnomaly)))
        }

        let x = meanDistance * (cos(radians(eccentricAnomaly)) - eccentricity)
        let y = meanDistance * (1 - eccentricity * eccentricity).squareRoot() * sin(radians(eccentricAnomaly))
        let trueAnomaly = revolution(degrees(atan2(y, x)))
        let distance = (x * x + y * y).squareRoot()
        let argument = radians(trueAnomaly + perigee)

        let xh = distance * (cos(radians(node)) * cos(argument) - sin(radians(node)) * sin(argument) * cos(radians(inclination)))
        let yh = distance * (sin(radians(node)) * cos(argument) + cos(radians(node)) * sin(argument) * cos(radians(inclination)))
        let zh = distance * sin(argument) * sin(radians(inclination))
        let eclipticLongitude = radians(revolution(degrees(atan2(yh, xh))))
        let eclipticLatitude = atan2(zh, (xh * xh + yh * yh).squareRoot())

        let obliquity = radians(23.4393 - 3.563e-7 * days)
        let xe = cos(eclipticLongitude) * cos(eclipticLatitude)
        let ye = sin(eclipticLongitude) * cos(eclipticLatitude) * cos(obliquity) - sin(eclipticLatitude) * sin(obliquity)
        let ze = sin(eclipticLongitude) * cos(eclipticLatitude) * sin(obliquity) + sin(eclipticLatitude) * cos(obliquity)
        let rightAscension = revolution(degrees(atan2(ye, xe)))
        let declination = degrees(atan2(ze, (xe * xe + ye * ye).squareRoot()))

        let daysSinceJ2000 = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0
        let siderealTime = revolution(280.46061837 + 360.98564736629 * daysSinceJ2000)
        let longitude = (rightAscension - siderealTime + 540).truncatingRemainder(dividingBy: 360) - 180
        return (declination, longitude)
    }

    /// The moon's altitude above the horizon at a place, in degrees. Its parallax, about a degree, is left out.
    static func altitude(latitude: Double, longitude: Double, at date: Date) -> Double {
        let moon = subLunarPoint(at: date)
        let sine = sin(radians(latitude)) * sin(radians(moon.latitude))
            + cos(radians(latitude)) * cos(radians(moon.latitude)) * cos(radians(longitude - moon.longitude))
        return degrees(asin(min(max(sine, -1), 1)))
    }

    // MARK: - Private

    /// An angle within 0..<360.
    private static func revolution(_ degrees: Double) -> Double {
        let remainder = degrees.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `MoonPositionTests`.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): the moon's phase and position, ported from the website and crewlu-globe (Stage 2 spec §4.5)`.

**Batch A review:** dispatch `superpowers:code-reviewer` (sonnet) on Tasks 2–6, then Todd runs `ComparisonPickerTests`, `GeographyTests`, `FlightProgressTests` and `MoonPositionTests`.

---
### Task 7: `LegStory`

A flight's places and its closest point to home, as fractions along its route, worked out once (Stage 2 spec §4.2).

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/LegStory.swift`
- Test: `CrewluvTests/LegStoryTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/LegStoryTests.swift`:

```swift
//
//  LegStoryTests.swift
//  CrewluvTests
//
//  A flight's places and closest point to home (Stage 2 spec §4.2), along the equator, where a fraction of the way
//  is a fraction of the longitude.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LegStoryTests: XCTestCase {

    private func at(_ latitude: Double, _ longitude: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private func story(_ geography: Geography? = FactsTestData.equator, home: CLLocationCoordinate2D? = nil) -> LegStory {
        LegStory(from: at(0, 0), to: at(0, 20), geography: geography, home: home)
    }

    func test_stretches_alongTheEquator_areEachPlaceFromWhereItStarts() {
        let stretches = story().stretches
        XCTAssertEqual(stretches.map(\.place.name), ["Alpha", "Bravo", "the Test Sea"], "the 21-mile Wedge is dropped")
        XCTAssertEqual(stretches[0].start, 0)
        XCTAssertEqual(stretches[1].start, 0.25, accuracy: 0.001)
        XCTAssertEqual(stretches[2].start, 0.6, accuracy: 0.001)
    }

    func test_stretches_aGapWithNoPlace_changesNothing() {
        let geography = Geography(areas: [
            FactsTestData.box("Alpha", .country, west: -1, east: 5),
            FactsTestData.box("Alpha", .country, west: 7, east: 21),
        ], cities: [])
        XCTAssertEqual(story(geography).stretches.map(\.place.name), ["Alpha"])
    }

    func test_stretches_aPlaceHeldFor25MilesOrMore_counts() {
        let geography = Geography(areas: [
            FactsTestData.box("Wide", .country, west: 9, east: 9.5),
            FactsTestData.box("Alpha", .country, west: -1, east: 21),
        ], cities: [])
        // 0.5° is about 35 mi.
        XCTAssertEqual(story(geography).stretches.map(\.place.name), ["Alpha", "Wide", "Alpha"])
    }

    func test_stretches_noGeography_isEmpty() {
        XCTAssertEqual(story(nil).stretches, [])
    }

    func test_placeAtFraction_readsTheStretches() {
        let equatorStory = story()
        XCTAssertEqual(equatorStory.place(atFraction: 0.1)?.name, "Alpha")
        XCTAssertEqual(equatorStory.place(atFraction: 0.46)?.name, "Bravo", "inside the dropped Wedge")
        XCTAssertEqual(equatorStory.place(atFraction: 0.9)?.name, "the Test Sea")
    }

    func test_closestToHome_besideTheRoute_isWhereItPasses() throws {
        let closest = try XCTUnwrap(story(home: at(0.5, 14)).closestToHome)
        XCTAssertEqual(closest.fraction, 0.7, accuracy: 0.001)
        XCTAssertEqual(closest.meters, 55_597, accuracy: 100, "half a degree")
    }

    func test_closestToHome_over100MilesAway_isNil() {
        XCTAssertNil(story(home: at(2, 14)).closestToHome, "2° is about 138 mi")
    }

    func test_closestToHome_atAnEndOfTheRoute_isNil() {
        XCTAssertNil(story(home: at(0.5, 21)).closestToHome, "past the arrival airport")
    }

    func test_initLeg_aFlightFromHome_hasNoClosestPoint() {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        XCTAssertNil(LegStory(leg: leg, geography: nil, home: leg.origin).closestToHome)
        let home = FactsTestData.mark("HOME", latitude: 0.5, longitude: 14)
        XCTAssertNotNil(LegStory(leg: leg, geography: nil, home: home).closestToHome)
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `LegStoryTests`.

- [ ] **Step 3: Write `LegStory`.** Create `Crewluv/Services/TripMap/Facts/LegStory.swift`:

```swift
//
//  LegStory.swift
//  CrewLuve
//
//  A flight's story, worked out once (Stage 2 spec §4.2): the places under its route and its closest point to home,
//  as fractions of the way along, 0 at the departure airport and 1 at the arrival. The schedule turns a fraction into
//  a time (`MapLeg.time(atFraction:)`), so a new delay moves every time without redoing the geography.
//

import CoreLocation

nonisolated struct LegStory: Sendable {

    /// A place under the route, from where it starts.
    nonisolated struct Stretch: Equatable, Sendable {
        let place: Geography.Place
        let start: Double
    }

    /// The route's closest point to home.
    nonisolated struct ClosestToHome: Equatable, Sendable {
        let fraction: Double
        let meters: Double
    }

    /// The route is looked up this often.
    static let sampleSpacing: Double = 10 * GreatCircle.metersPerMile
    static let minimumSamples = 16
    /// A place counts once the route stays in it this far, so a route along a border doesn't flicker.
    static let holdDistance: Double = 25 * GreatCircle.metersPerMile
    /// Crossings and the closest point are narrowed down to this.
    static let precision: Double = 0.1 * GreatCircle.metersPerMile
    /// Home counts when the route passes this close.
    static let homeRadius: Double = 100 * GreatCircle.metersPerMile

    /// In order. The first starts at 0. Empty without geography.
    let stretches: [Stretch]
    let closestToHome: ClosestToHome?

    init(stretches: [Stretch], closestToHome: ClosestToHome?) {
        self.stretches = stretches
        self.closestToHome = closestToHome
    }

    /// - Parameter home: where home is, or nil for a flight that starts or ends there.
    init(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, geography: Geography?, home: CLLocationCoordinate2D?) {
        let route = Route(origin: origin, destination: destination)
        stretches = geography.map { Self.stretches(along: route, in: $0) } ?? []
        closestToHome = home.flatMap { Self.closestPoint(of: route, to: $0) }
    }

    /// A flight's story. Home counts only when the flight doesn't start or end there.
    init(leg: MapLeg, geography: Geography?, home: AirportMark?) {
        let isHomeLeg = home.map { $0.code == leg.origin.code || $0.code == leg.destination.code } ?? true
        self.init(from: leg.origin.coordinate, to: leg.destination.coordinate, geography: geography,
                  home: isHomeLeg ? nil : home?.coordinate)
    }

    /// The place `fraction` of the way along.
    func place(atFraction fraction: Double) -> Geography.Place? {
        stretches.last { $0.start <= fraction }?.place
    }

    // MARK: - Private

    private struct Route {
        let origin: CLLocationCoordinate2D
        let destination: CLLocationCoordinate2D
        let length: Double
        let sampleCount: Int

        init(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
            self.origin = origin
            self.destination = destination
            length = GreatCircle.distance(from: origin, to: destination)
            sampleCount = max(LegStory.minimumSamples, Int((length / LegStory.sampleSpacing).rounded(.up)) + 1)
        }

        var step: Double { 1 / Double(sampleCount - 1) }

        func point(at fraction: Double) -> CLLocationCoordinate2D {
            GreatCircle.point(from: origin, to: destination, fraction: fraction)
        }
    }

    private struct Run {
        let place: Geography.Place
        let first: Int
        var last: Int
    }

    private static func stretches(along route: Route, in geography: Geography) -> [Stretch] {
        let places = (0..<route.sampleCount).map { geography.place(at: route.point(at: Double($0) * route.step)) }

        // Runs of one place. A sample with no place joins no run, so a gap changes nothing.
        var runs: [Run] = []
        for (index, place) in places.enumerated() {
            guard let place else { continue }
            if runs.last?.place == place {
                runs[runs.count - 1].last = index
            } else {
                runs.append(Run(place: place, first: index, last: index))
            }
        }

        // The hold rule: a run shorter than 25 mi goes, and the runs either side of it join if they're one place.
        let spacing = route.length * route.step
        var held: [Run] = []
        for run in runs where Double(run.last - run.first + 1) * spacing >= holdDistance {
            if held.last?.place == run.place {
                held[held.count - 1].last = run.last
            } else {
                held.append(run)
            }
        }

        guard let first = held.first else { return [] }
        var stretches = [Stretch(place: first.place, start: 0)]
        for (previous, next) in zip(held, held.dropFirst()) {
            let start = boundary(of: next.place, after: Double(previous.last) * route.step, before: Double(next.first) * route.step,
                                 along: route, in: geography)
            stretches.append(Stretch(place: next.place, start: start))
        }
        return stretches
    }

    /// Where `place` begins between two fractions, by bisection.
    private static func boundary(of place: Geography.Place, after low: Double, before high: Double,
                                 along route: Route, in geography: Geography) -> Double {
        var low = low
        var high = high
        while (high - low) * route.length > precision {
            let middle = (low + high) / 2
            if geography.place(at: route.point(at: middle)) == place {
                high = middle
            } else {
                low = middle
            }
        }
        return high
    }

    private static func closestPoint(of route: Route, to home: CLLocationCoordinate2D) -> ClosestToHome? {
        let distances = (0..<route.sampleCount).map { GreatCircle.distance(from: route.point(at: Double($0) * route.step), to: home) }
        guard let nearest = distances.indices.min(by: { distances[$0] < distances[$1] }),
              nearest > 0, nearest < route.sampleCount - 1 else { return nil }

        // The distance has one minimum between the nearest sample's neighbours: narrow it down by thirds.
        var low = Double(nearest - 1) * route.step
        var high = Double(nearest + 1) * route.step
        while (high - low) * route.length > precision {
            let third = (high - low) / 3
            if GreatCircle.distance(from: route.point(at: low + third), to: home) < GreatCircle.distance(from: route.point(at: high - third), to: home) {
                high -= third
            } else {
                low += third
            }
        }
        let fraction = (low + high) / 2
        let meters = GreatCircle.distance(from: route.point(at: fraction), to: home)
        return meters <= homeRadius ? ClosestToHome(fraction: fraction, meters: meters) : nil
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `LegStoryTests`.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): LegStory, a flight's places and closest point to home, worked out once (Stage 2 spec §4.2)`.

---

### Task 8: `Milestone`

Crossings, halfway and closest to home, as times (Stage 2 spec §4.3).

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/Milestone.swift`
- Test: `CrewluvTests/MilestoneTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/MilestoneTests.swift`:

```swift
//
//  MilestoneTests.swift
//  CrewluvTests
//
//  A flight's milestones (Stage 2 spec §4.3). The flights along the equator are in the air from 10:15 UTC for three
//  hours, so each tenth of the way is 18 minutes.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class MilestoneTests: XCTestCase {

    private func milestones(_ leg: MapLeg, _ geography: Geography, home: AirportMark? = nil) -> [Milestone] {
        Milestone.milestones(on: leg, story: LegStory(leg: leg, geography: geography, home: home))
    }

    private func assert(_ milestone: Milestone, _ kind: Milestone.Kind, at iso: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(milestone.kind, kind, file: file, line: line)
        XCTAssertEqual(milestone.time.timeIntervalSince1970, FactsTestData.date(iso).timeIntervalSince1970, accuracy: 5, file: file, line: line)
    }

    func test_milestones_alongTheEquator_areTheCrossingsHalfwayAndHome() {
        let home = FactsTestData.mark("HOME", latitude: 0.5, longitude: 14)
        let found = milestones(FactsTestData.equatorFlight(from: 0, to: 20), FactsTestData.equator, home: home)
        XCTAssertEqual(found.count, 4)
        assert(found[0], .crossedInto("Bravo"), at: "2026-03-20T11:00:00Z")
        assert(found[1], .halfway, at: "2026-03-20T11:45:00Z")
        assert(found[2], .outOver("the Test Sea"), at: "2026-03-20T12:03:00Z")
        assert(found[3], .closestToHome(miles: 35), at: "2026-03-20T12:21:00Z")
    }

    func test_milestones_aStateLineInOneCountry_namesTheState_aBorderNamesTheCountry() {
        let geography = Geography(areas: [
            FactsTestData.box("North", .state, country: "Delta", west: 29, east: 35.5),
            FactsTestData.box("South", .state, country: "Delta", west: 35.5, east: 37),
            FactsTestData.box("Delta", .country, west: 29, east: 37),
            FactsTestData.box("Echo", .country, west: 37, east: 41),
        ], cities: [])
        let leg = FactsTestData.equatorFlight(from: 30, to: 40, departure: FactsTestData.equinox.addingTimeInterval(4 * 3600))
        let found = milestones(leg, geography)
        XCTAssertEqual(found.map(\.kind), [.halfway, .crossedInto("South"), .crossedInto("Echo")])
        assert(found[1], .crossedInto("South"), at: "2026-03-20T15:54:00Z")
        assert(found[2], .crossedInto("Echo"), at: "2026-03-20T16:21:00Z")
    }

    func test_milestones_oneSeaIntoAnother_isNone_butLandAfterIt_isTheCountry() {
        let geography = Geography(areas: [
            FactsTestData.box("the Test Sea", .water, west: 49, east: 53),
            FactsTestData.box("the Other Sea", .water, west: 53, east: 56),
            FactsTestData.box("Foxtrot", .country, west: 56, east: 61),
        ], cities: [])
        let leg = FactsTestData.equatorFlight(from: 50, to: 60, departure: FactsTestData.equinox.addingTimeInterval(8 * 3600))
        let found = milestones(leg, geography)
        XCTAssertEqual(found.map(\.kind), [.halfway, .crossedInto("Foxtrot")])
        assert(found[1], .crossedInto("Foxtrot"), at: "2026-03-20T20:03:00Z")
    }

    func test_milestones_aGapWhereOnlyTheCountryIsKnown_isNotAMilestone() {
        let geography = Geography(areas: [
            FactsTestData.box("Kansas", .state, country: "the United States", west: -1, east: 5),
            FactsTestData.box("Nebraska", .state, country: "the United States", west: 6, east: 21),
            FactsTestData.box("the United States", .country, west: -1, east: 21),
        ], cities: [])
        let found = milestones(FactsTestData.equatorFlight(from: 0, to: 20), geography)
        XCTAssertEqual(found.map(\.kind), [.crossedInto("Nebraska"), .halfway])
    }

    func test_roundedMiles_toTheNearest5_neverUnder5() {
        let mile = GreatCircle.metersPerMile
        XCTAssertEqual(Milestone.roundedMiles(34.55 * mile), 35)
        XCTAssertEqual(Milestone.roundedMiles(52 * mile), 50)
        XCTAssertEqual(Milestone.roundedMiles(53 * mile), 55)
        XCTAssertEqual(Milestone.roundedMiles(2 * mile), 5)
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `MilestoneTests`.

- [ ] **Step 3: Write `Milestone`.** Create `Crewluv/Services/TripMap/Facts/Milestone.swift`:

```swift
//
//  Milestone.swift
//  CrewLuve
//
//  A moment worth a line on a flight (Stage 2 spec §4.3): crossing into a new country, state or province, out over a
//  named sea, halfway, and the closest point to home. Each leads the headline for 5 minutes.
//

import Foundation

nonisolated struct Milestone: Equatable, Sendable {

    nonisolated enum Kind: Equatable, Sendable {
        /// A new country, or a new state or province in the same country: "Just crossed into Kansas".
        case crossedInto(String)
        /// From land onto a named water: "Out over the Atlantic".
        case outOver(String)
        case halfway
        /// The closest the route comes to home, to the nearest 5 mi.
        case closestToHome(miles: Int)
    }

    let kind: Kind
    let time: Date

    /// How long a milestone leads the headline.
    static let headlineDuration: TimeInterval = 5 * 60

    /// A flight's milestones in time order, from its story and its delay-shifted times.
    static func milestones(on leg: MapLeg, story: LegStory) -> [Milestone] {
        var found: [(kind: Kind, fraction: Double)] = []
        for (previous, next) in zip(story.stretches, story.stretches.dropFirst()) {
            if let kind = crossingKind(from: previous.place, to: next.place) {
                found.append((kind, next.start))
            }
        }
        found.append((.halfway, 0.5))
        if let closest = story.closestToHome {
            found.append((.closestToHome(miles: roundedMiles(closest.meters)), closest.fraction))
        }
        return found.enumerated()
            .sorted { ($0.element.fraction, $0.offset) < ($1.element.fraction, $1.offset) }
            .compactMap { item in
                leg.time(atFraction: item.element.fraction).map { Milestone(kind: item.element.kind, time: $0) }
            }
    }

    /// To the nearest 5 mi, and never under 5.
    static func roundedMiles(_ meters: Double) -> Int {
        max(5, Int((meters / GreatCircle.metersPerMile / 5).rounded()) * 5)
    }

    // MARK: - Private

    /// What moving from one place to the next means, if anything.
    private static func crossingKind(from previous: Geography.Place, to next: Geography.Place) -> Kind? {
        if next.isWater {
            // One sea into another changes the "below" row but isn't a milestone.
            return previous.isWater ? nil : .outOver(next.name)
        }
        if next.country != previous.country {
            // An international border, or landfall, names the country.
            return .crossedInto(next.country ?? next.name)
        }
        // The same country: a new state or province counts. A gap between two, where only the country is known, doesn't.
        return next.kind == .country ? nil : .crossedInto(next.name)
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `MilestoneTests`.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): a flight's milestones: crossings, halfway and closest to home (Stage 2 spec §4.3)`.

---

### Task 9: `SkyFacts`

The sky from the cockpit (Stage 2 spec §4.5) and the next sunrise or sunset at an airport (§5.3). The expected times came from a JavaScript copy of `SolarPosition`, `GreatCircle` and `FlightProgress`, and the website's shared cases will hold its engine to the same answers.

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/SkyFacts.swift`
- Test: `CrewluvTests/SkyFactsTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/SkyFactsTests.swift`:

```swift
//
//  SkyFactsTests.swift
//  CrewluvTests
//
//  Sunrises and sunsets from the cockpit, the people below, chasing the sun and the moon (Stage 2 spec §4.5), on
//  Louisville–Cologne flights in mid-November.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class SkyFactsTests: XCTestCase {

    private func flight(_ from: String, _ to: String, departing iso: String, hours: Double) -> MapLeg {
        let start = FactsTestData.date(iso)
        return MapLeg(id: "\(from)\(to)", kind: .flight,
                      origin: AirportMark(code: from, city: nil, coordinate: TripMapTestLegs.airports[from]!, timeZone: nil),
                      destination: AirportMark(code: to, city: nil, coordinate: TripMapTestLegs.airports[to]!, timeZone: nil),
                      start: start, end: start.addingTimeInterval(hours * 3600), flightNumber: nil)
    }

    func test_cockpitHorizon_at35000Feet_isAbout3Point86DegreesDown() {
        XCTAssertEqual(SkyFacts.horizonDip(feet: 35_000), 3.03, accuracy: 0.01)
        XCTAssertEqual(SkyFacts.cockpitHorizon, -3.863, accuracy: 0.001)
    }

    func test_sunEvents_anEveningFlightToEurope_seesOneSunset_about21MinutesAfterThePeopleBelow() throws {
        let events = SkyFacts.sunEvents(on: flight("SDF", "CGN", departing: "2026-11-13T18:00:00Z", hours: 8))
        let sunset = try XCTUnwrap(events.first)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(sunset.kind, .sunset)
        XCTAssertEqual(sunset.time.timeIntervalSince1970, FactsTestData.date("2026-11-13T20:46:17Z").timeIntervalSince1970, accuracy: 60)
        XCTAssertEqual(try XCTUnwrap(sunset.peopleBelowGap) / 60, 21.4, accuracy: 1)
    }

    func test_sunEvents_anOvernightFlightToEurope_seesOneSunrise_about22MinutesBeforeThePeopleBelow() throws {
        let events = SkyFacts.sunEvents(on: flight("SDF", "CGN", departing: "2026-11-13T23:00:00Z", hours: 8))
        let sunrise = try XCTUnwrap(events.first)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(sunrise.kind, .sunrise)
        XCTAssertEqual(sunrise.time.timeIntervalSince1970, FactsTestData.date("2026-11-14T06:38:13Z").timeIntervalSince1970, accuracy: 60)
        XCTAssertEqual(try XCTUnwrap(sunrise.peopleBelowGap) / 60, 22.0, accuracy: 1)
    }

    func test_sunEvents_aDaylightFlightWest_seesNone() {
        XCTAssertEqual(SkyFacts.sunEvents(on: flight("CGN", "SDF", departing: "2026-11-14T13:00:00Z", hours: 9)), [])
    }

    func test_sunEvents_aDrive_isNone() {
        let drive = MapLeg(id: "d", kind: .drive,
                           origin: AirportMark(code: "LEX", city: nil, coordinate: TripMapTestLegs.airports["LEX"]!, timeZone: nil),
                           destination: AirportMark(code: "SDF", city: nil, coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                           start: FactsTestData.date("2026-11-13T21:00:00Z"), end: FactsTestData.date("2026-11-13T23:00:00Z"), flightNumber: nil)
        XCTAssertEqual(SkyFacts.sunEvents(on: drive), [])
    }

    func test_chase_westboundOverTheAtlanticInTheAfternoon_isTheAfternoon() {
        let leg = flight("CGN", "SDF", departing: "2026-11-14T13:00:00Z", hours: 9)
        XCTAssertEqual(SkyFacts.chase(on: leg, at: FactsTestData.date("2026-11-14T15:00:00Z")), .afternoon)
    }

    func test_chase_eastbound_isNil() {
        let leg = flight("SDF", "CGN", departing: "2026-11-13T12:00:00Z", hours: 8)
        XCTAssertNil(SkyFacts.chase(on: leg, at: FactsTestData.date("2026-11-13T15:00:00Z")))
    }

    func test_moon_inDaylight_isNil() {
        let leg = flight("CGN", "SDF", departing: "2026-11-14T13:00:00Z", hours: 9)
        XCTAssertNil(SkyFacts.moon(on: leg, at: FactsTestData.date("2026-11-14T15:00:00Z")))
    }

    func test_moon_onANightLeavingCologne_isAWaxingGibbousMoonUp() {
        let leg = flight("CGN", "DXB", departing: "2026-11-20T20:00:00Z", hours: 6)
        XCTAssertEqual(SkyFacts.moon(on: leg, at: FactsTestData.date("2026-11-20T20:30:00Z")),
                       SkyFacts.Moon(phase: .waxingGibbous, isUp: true))
    }

    func test_nextGroundSunEvent_inCologneAtNight_isTomorrowsSunrise() throws {
        let event = try XCTUnwrap(SkyFacts.nextGroundSunEvent(at: TripMapTestLegs.airports["CGN"]!, after: FactsTestData.date("2026-11-13T20:14:00Z")))
        XCTAssertEqual(event.kind, .sunrise)
        XCTAssertEqual(event.time.timeIntervalSince1970, FactsTestData.date("2026-11-14T06:45:24Z").timeIntervalSince1970, accuracy: 60)
    }

    func test_nextGroundSunEvent_inCologneAtNoon_isThatEveningsSunset() throws {
        let event = try XCTUnwrap(SkyFacts.nextGroundSunEvent(at: TripMapTestLegs.airports["CGN"]!, after: FactsTestData.date("2026-11-14T12:00:00Z")))
        XCTAssertEqual(event.kind, .sunset)
        XCTAssertEqual(event.time.timeIntervalSince1970, FactsTestData.date("2026-11-14T15:45:47Z").timeIntervalSince1970, accuracy: 60)
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `SkyFactsTests`.

- [ ] **Step 3: Write `SkyFacts`.** Create `Crewluv/Services/TripMap/Facts/SkyFacts.swift`:

```swift
//
//  SkyFacts.swift
//  CrewLuve
//
//  The sky from the cockpit (Stage 2 spec §4.5): sunrises and sunsets at cruise, when the people below see them,
//  chasing the sun, and the moon. Also the next sunrise or sunset on the ground at an airport (§5.3).
//

import CoreLocation

nonisolated enum SkyFacts {

    nonisolated struct SunEvent: Equatable, Sendable {
        nonisolated enum Kind: Equatable, Sendable {
            case sunrise, sunset
        }

        let kind: Kind
        let time: Date
        /// How much later than the people below the cockpit sees a sunset, or how much earlier a sunrise, when that's
        /// 5 minutes or more.
        let peopleBelowGap: TimeInterval?
    }

    /// Which part of the day stretches while the plane chases the sun.
    nonisolated enum Chase: Equatable, Sendable {
        case morning, afternoon
    }

    nonisolated struct Moon: Equatable, Sendable {
        let phase: LunarPhase
        let isUp: Bool
    }

    /// The sun's centre at sunrise and sunset on the ground, after refraction.
    static let groundHorizon = -0.833
    /// The schedule's height in the air. Stage 3 uses the live altitude.
    static let cruiseAltitudeFeet: Double = 35_000
    /// The sun's altitude at a cockpit sunrise or sunset at cruise: about −3.86°.
    static let cockpitHorizon = groundHorizon - horizonDip(feet: cruiseAltitudeFeet)
    /// Under this, the cockpit and the people below see it at about the same time.
    static let peopleBelowThreshold: TimeInterval = 5 * 60
    /// Chasing the sun: its hour angle at the plane moving at under half its usual 15° an hour.
    static let chaseRate: Double = 7.5

    private static let sampleStep: TimeInterval = 120
    private static let groundSearch: TimeInterval = 3 * 3600
    private static let groundStep: TimeInterval = 600

    /// How far below level the horizon lies from `feet` up, in degrees: 1.76′ × √(height in m).
    static func horizonDip(feet: Double) -> Double {
        1.76 / 60 * (max(feet, 0) * 0.3048).squareRoot()
    }

    /// The sun's altitude at the schedule's plane, in degrees.
    static func sunAltitude(on leg: MapLeg, at date: Date) -> Double {
        let here = leg.position(at: date)
        return SolarPosition.altitude(latitude: here.latitude, longitude: here.longitude, at: date)
    }

    // MARK: - Sunrise and sunset from the cockpit

    /// The sunrises and sunsets the cockpit sees while the schedule has the flight in the air, in order: sampled every
    /// 2 minutes and narrowed to 5 seconds.
    static func sunEvents(on leg: MapLeg) -> [SunEvent] {
        guard leg.kind == .flight, let window = FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end) else { return [] }
        let height: (Date) -> Double = { sunAltitude(on: leg, at: $0) - cockpitHorizon }
        var times: [Date] = []
        var time = window.start
        while time < window.end {
            times.append(time)
            time += sampleStep
        }
        times.append(window.end)
        let heights = times.map(height)
        return times.indices.dropFirst().compactMap { index -> SunEvent? in
            let isRising = heights[index - 1] <= 0 && heights[index] > 0
            let isSetting = heights[index - 1] > 0 && heights[index] <= 0
            guard isRising || isSetting else { return nil }
            let eventTime = crossing(of: height, from: times[index - 1], to: times[index], isRising: isRising, precision: 5)
            return SunEvent(kind: isRising ? .sunrise : .sunset, time: eventTime,
                            peopleBelowGap: peopleBelowGap(at: leg.position(at: eventTime), cockpitTime: eventTime, isSunrise: isRising))
        }
    }

    // MARK: - Chasing the sun

    /// While the sun's up at the plane and its hour angle there changes at under 7.5° an hour: the afternoon, or the
    /// morning while the sun is east of the plane's meridian.
    static func chase(on leg: MapLeg, at date: Date) -> Chase? {
        guard leg.kind == .flight, let window = FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end),
              window.contains(date), sunAltitude(on: leg, at: date) > cockpitHorizon else { return nil }
        let here = leg.position(at: date)
        let soon = leg.position(at: date.addingTimeInterval(60))
        let degreesPerHour = 15 + wrapped(soon.longitude - here.longitude) * 60
        guard abs(degreesPerHour) < chaseRate else { return nil }
        let hourAngle = wrapped(here.longitude - SolarPosition.subsolarPoint(at: date).longitude)
        return hourAngle < 0 ? .morning : .afternoon
    }

    // MARK: - The moon

    /// The moon while the sun is below the cockpit's horizon, or nil in daylight.
    static func moon(on leg: MapLeg, at date: Date) -> Moon? {
        guard leg.kind == .flight, sunAltitude(on: leg, at: date) <= cockpitHorizon else { return nil }
        let here = leg.position(at: date)
        return Moon(phase: MoonPosition.phase(at: date),
                    isUp: MoonPosition.altitude(latitude: here.latitude, longitude: here.longitude, at: date) > 0)
    }

    // MARK: - On the ground

    /// The next sunrise or sunset on the ground at `place` within a day of `date`: sampled every 10 minutes and narrowed
    /// to 30 seconds.
    static func nextGroundSunEvent(at place: CLLocationCoordinate2D, after date: Date) -> (kind: SunEvent.Kind, time: Date)? {
        let height = groundHeight(at: place)
        var earlier = date
        while earlier.timeIntervalSince(date) < 86_400 {
            let later = earlier.addingTimeInterval(groundStep)
            let before = height(earlier)
            let after = height(later)
            if (before <= 0) != (after <= 0) {
                let isRising = after > 0
                let kind: SunEvent.Kind = isRising ? .sunrise : .sunset
                return (kind, crossing(of: height, from: earlier, to: later, isRising: isRising, precision: 30))
            }
            earlier = later
        }
        return nil
    }

    // MARK: - Private

    /// The sun's height above the ground's sunrise altitude at `place`.
    private static func groundHeight(at place: CLLocationCoordinate2D) -> (Date) -> Double {
        { SolarPosition.altitude(latitude: place.latitude, longitude: place.longitude, at: $0) - groundHorizon }
    }

    /// When the ground under a cockpit event sees the same event. A sunset reaches the ground first and a sunrise
    /// last, so it steps that way until the sun's on the other side of the ground's horizon, up to 3 hours.
    private static func peopleBelowGap(at point: CLLocationCoordinate2D, cockpitTime: Date, isSunrise: Bool) -> TimeInterval? {
        let height = groundHeight(at: point)
        let step = isSunrise ? sampleStep : -sampleStep
        var near = cockpitTime
        while abs(near.timeIntervalSince(cockpitTime)) < groundSearch {
            let far = near.addingTimeInterval(step)
            if height(far) > 0 {
                let ground = isSunrise
                    ? crossing(of: height, from: near, to: far, isRising: true, precision: 5)
                    : crossing(of: height, from: far, to: near, isRising: false, precision: 5)
                let gap = abs(cockpitTime.timeIntervalSince(ground))
                return gap >= peopleBelowThreshold ? gap : nil
            }
            near = far
        }
        return nil
    }

    /// Narrows a change of sign in `height` between two moments to `precision` seconds, and gives the middle.
    private static func crossing(of height: (Date) -> Double, from earlier: Date, to later: Date,
                                 isRising: Bool, precision: TimeInterval) -> Date {
        var low = earlier
        var high = later
        while high.timeIntervalSince(low) > precision {
            let middle = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if (height(middle) > 0) == isRising {
                high = middle
            } else {
                low = middle
            }
        }
        return low.addingTimeInterval(high.timeIntervalSince(low) / 2)
    }

    /// A longitude difference within −180..<180.
    private static func wrapped(_ degrees: Double) -> Double {
        let shifted = (degrees + 180).truncatingRemainder(dividingBy: 360)
        return (shifted < 0 ? shifted + 360 : shifted) - 180
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `SkyFactsTests`.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): SkyFacts: cockpit sunrises and sunsets, the people below, chasing the sun and the moon (Stage 2 spec §4.5)`.

---

### Task 10: `TripTotals`

Cities, miles, time zones and cockpit sunsets, so far or for the whole trip, and the longest flight (Stage 2 spec §4.8).

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/TripTotals.swift`
- Test: `CrewluvTests/TripTotalsTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripTotalsTests.swift`:

```swift
//
//  TripTotalsTests.swift
//  CrewluvTests
//
//  A trip's totals (Stage 2 spec §4.8): Louisville to Cologne to Dubai and home, from 2026-11-13 12:00 UTC.
//  Its one cockpit sunset is on the first flight, at 17:45 UTC.
//

import XCTest
@testable import Crewluv

final class TripTotalsTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart

    private func europe() throws -> (map: TripMap, sunEvents: [String: [SkyFacts.SunEvent]]) {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: start))
        let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        return (map, sunEvents)
    }

    func test_whole_theEuropeTrip() throws {
        let trip = try europe()
        XCTAssertEqual(TripTotals.whole(trip.map, sunEvents: trip.sunEvents),
                       TripTotals(cities: 2, miles: 14_819, timeZones: 18, cockpitSunsets: 1))
    }

    func test_soFar_afterTheFirstFlight_countsIt() throws {
        let trip = try europe()
        XCTAssertEqual(TripTotals.soFar(on: trip.map, at: start.addingTimeInterval(12 * 3600), sunEvents: trip.sunEvents),
                       TripTotals(cities: 1, miles: 4_351, timeZones: 6, cockpitSunsets: 1))
    }

    func test_soFar_midFirstFlightBeforeSunset_countsOnlyMiles() throws {
        let trip = try europe()
        let totals = TripTotals.soFar(on: trip.map, at: start.addingTimeInterval(4 * 3600), sunEvents: trip.sunEvents)
        XCTAssertEqual(totals.cities, 0)
        XCTAssertEqual(totals.timeZones, 0)
        XCTAssertEqual(totals.cockpitSunsets, 0)
        XCTAssertGreaterThan(totals.miles, 0)
    }

    func test_timeZonesCrossed_halfHours_roundAtTheEnd() {
        func leg(_ id: String, from: String, to: String) -> MapLeg {
            MapLeg(id: id, kind: .flight,
                   origin: FactsTestData.mark("A", latitude: 0, longitude: 0, zone: from),
                   destination: FactsTestData.mark("B", latitude: 0, longitude: 10, zone: to),
                   start: start, end: start.addingTimeInterval(3600), flightNumber: nil)
        }
        XCTAssertEqual(TripTotals.timeZonesCrossed(by: [leg("1", from: "America/New_York", to: "Asia/Kolkata")]), 11, "10½ hours")
        XCTAssertEqual(TripTotals.timeZonesCrossed(by: [leg("1", from: "Asia/Kolkata", to: "Asia/Dubai"),
                                                        leg("2", from: "Asia/Dubai", to: "Asia/Kolkata")]), 3, "1½ and 1½")
    }

    func test_timeZonesCrossed_anUnknownZone_addsNothing() {
        let leg = MapLeg(id: "1", kind: .flight,
                         origin: FactsTestData.mark("A", latitude: 0, longitude: 0, zone: "America/New_York"),
                         destination: FactsTestData.mark("B", latitude: 0, longitude: 10),
                         start: start, end: start.addingTimeInterval(3600), flightNumber: nil)
        XCTAssertEqual(TripTotals.timeZonesCrossed(by: [leg]), 0)
    }

    func test_longestFlight_isDubaiToLouisville() throws {
        XCTAssertEqual(TripTotals.longestFlight(of: try europe().map.legs)?.id, "f3")
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `TripTotalsTests`.

- [ ] **Step 3: Write `TripTotals`.** Create `Crewluv/Services/TripMap/Facts/TripTotals.swift`:

```swift
//
//  TripTotals.swift
//  CrewLuve
//
//  A trip's numbers (Stage 2 spec §4.8): cities, miles, time zones crossed and sunsets from the cockpit, so far or for
//  the whole trip (a recap, or a forecast of a trip ahead), and its longest flight.
//

import Foundation

nonisolated struct TripTotals: Equatable, Sendable {
    let cities: Int
    let miles: Int
    let timeZones: Int
    let cockpitSunsets: Int

    /// Up to `date`: finished flights, and the miles of the one in the air.
    static func soFar(on tripMap: TripMap, at date: Date, sunEvents: [String: [SkyFacts.SunEvent]]) -> TripTotals {
        let finished = tripMap.legs.filter { $0.kind == .flight && $0.end <= date }
        return TripTotals(
            cities: TripMapWording.destinations(of: finished, leavingOut: homeCodes(of: tripMap)).count,
            miles: TripMapWording.milesFlown(by: date, on: tripMap.legs),
            timeZones: timeZonesCrossed(by: finished),
            cockpitSunsets: sunsets(on: tripMap.legs, by: date, in: sunEvents)
        )
    }

    /// The whole trip.
    static func whole(_ tripMap: TripMap, sunEvents: [String: [SkyFacts.SunEvent]]) -> TripTotals {
        TripTotals(
            cities: TripMapWording.destinations(of: tripMap.legs, leavingOut: homeCodes(of: tripMap)).count,
            miles: TripMapWording.totalMiles(of: tripMap.legs),
            timeZones: timeZonesCrossed(by: tripMap.legs),
            cockpitSunsets: sunsets(on: tripMap.legs, by: .distantFuture, in: sunEvents)
        )
    }

    /// Each flight's change in UTC offset as a positive number, summed in seconds and rounded to the nearest hour at
    /// the end. A flight with an unknown time zone at either end adds nothing.
    static func timeZonesCrossed(by legs: [MapLeg]) -> Int {
        let seconds = legs.filter { $0.kind == .flight }.reduce(0) { total, leg in
            guard let from = leg.origin.timeZone, let to = leg.destination.timeZone else { return total }
            return total + abs(to.secondsFromGMT(for: leg.end) - from.secondsFromGMT(for: leg.start))
        }
        return Int((Double(seconds) / 3600).rounded())
    }

    static func longestFlight(of legs: [MapLeg]) -> MapLeg? {
        legs.filter { $0.kind == .flight }.max { $0.distance < $1.distance }
    }

    // MARK: - Private

    private static func sunsets(on legs: [MapLeg], by date: Date, in sunEvents: [String: [SkyFacts.SunEvent]]) -> Int {
        legs.reduce(0) { count, leg in
            count + (sunEvents[leg.id] ?? []).filter { $0.kind == .sunset && $0.time <= date }.count
        }
    }

    private static func homeCodes(of tripMap: TripMap) -> Set<String> {
        Set([tripMap.home?.code].compactMap { $0 })
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `TripTotalsTests`.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): TripTotals: cities, miles, time zones and cockpit sunsets (Stage 2 spec §4.8)`.

**Batch B review:** dispatch `superpowers:code-reviewer` (sonnet) on Tasks 7–10, then Todd runs `LegStoryTests`, `MilestoneTests`, `SkyFactsTests` and `TripTotalsTests`.

---
### Task 11: `FactsWording`

Every sentence the facts show or speak (Stage 2 spec §4, §5, §6.5), and the small values they use.

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/LandingForecast.swift`
- Create: `Crewluv/Services/TripMap/Facts/RecapTile.swift`
- Create: `Crewluv/Services/TripMap/Facts/FactsWording.swift`
- Create: `Crewluv/Services/TripMap/Facts/FactsWording+Trip.swift`
- Modify: `Crewluv/Services/TripMap/TripMapWording.swift` (three helpers become internal)
- Test: `CrewluvTests/FactsWordingTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/FactsWordingTests.swift`:

```swift
//
//  FactsWordingTests.swift
//  CrewluvTests
//
//  The facts' sentences (Stage 2 spec §4, §5, §6.5), in US English for a family in Louisville.
//

import XCTest
@testable import Crewluv

final class FactsWordingTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
    /// Friday 2026-11-13, 3:14 PM in Louisville.
    private let now = Date(timeIntervalSince1970: 1_794_600_840)

    /// iOS writes a narrow no-break space before AM and PM; the tests read it as a plain space.
    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func zone(_ identifier: String) -> TimeZone { TimeZone(identifier: identifier)! }

    // MARK: - Milestones

    func test_headline_eachMilestone() {
        XCTAssertEqual(FactsWording.headline(for: .crossedInto("Kansas")), "Just crossed into Kansas")
        XCTAssertEqual(FactsWording.headline(for: .outOver("the Atlantic")), "Out over the Atlantic")
        XCTAssertEqual(FactsWording.headline(for: .halfway), "Halfway!")
        XCTAssertEqual(FactsWording.headline(for: .closestToHome(miles: 40)), "Closest to home: 40 mi, wave!")
    }

    func test_listLine_addsTheTimeInYourZone() {
        let milestone = Milestone(kind: .crossedInto("Canada"), time: now)
        XCTAssertEqual(plain(FactsWording.listLine(for: milestone, calendar: calendar, locale: locale)), "Crossed into Canada · 3:14 PM")
        let closest = Milestone(kind: .closestToHome(miles: 40), time: now)
        XCTAssertEqual(plain(FactsWording.listLine(for: closest, calendar: calendar, locale: locale)), "Closest to home, 40 mi · 3:14 PM")
    }

    func test_below_withAndWithoutACity() {
        let place = Geography.Place(name: "Québec", kind: .province, country: "Canada")
        XCTAssertEqual(FactsWording.below(place, near: nil), "Over Québec")
        XCTAssertEqual(FactsWording.below(place, near: Geography.City(name: "Montréal", lat: 45.5, lon: -73.57)), "Over Québec, near Montréal")
    }

    func test_closestToHome_beforeAndAfter() {
        let later = now.addingTimeInterval(3600)
        XCTAssertEqual(plain(FactsWording.closestToHome(miles: 40, at: later, now: now, calendar: calendar, locale: locale)),
                       "Passes 40 mi from home at 4:14 PM")
        XCTAssertEqual(plain(FactsWording.closestToHome(miles: 40, at: now, now: later, calendar: calendar, locale: locale)),
                       "Closest to home was 40 mi at 3:14 PM")
    }

    // MARK: - The sky

    func test_cockpitCountdown_roundsUp() {
        let sunset = SkyFacts.SunEvent(kind: .sunset, time: now.addingTimeInterval(24.5 * 60), peopleBelowGap: nil)
        XCTAssertEqual(FactsWording.cockpitCountdown(sunset, now: now), "Sunset from the cockpit in 25 min")
    }

    func test_cockpitEvent_soonWithThePeopleBelow() {
        let sunset = SkyFacts.SunEvent(kind: .sunset, time: now.addingTimeInterval(24.5 * 60), peopleBelowGap: 12.2 * 60)
        XCTAssertEqual(FactsWording.cockpitEvent(sunset, now: now, calendar: calendar, locale: locale),
                       "Sunset in 25 min, about 12 min after the people below")
    }

    func test_cockpitEvent_anHourOrMoreAway_givesTheTime() {
        let sunrise = SkyFacts.SunEvent(kind: .sunrise, time: now.addingTimeInterval(2 * 3600), peopleBelowGap: 22 * 60)
        XCTAssertEqual(plain(FactsWording.cockpitEvent(sunrise, now: now, calendar: calendar, locale: locale)),
                       "Sunrise at 5:14 PM, about 22 min before the people below")
    }

    func test_skyLines() {
        XCTAssertEqual(FactsWording.flyingInto(.sunset), "Flying into the night")
        XCTAssertEqual(FactsWording.flyingInto(.sunrise), "Flying into the morning")
        XCTAssertEqual(FactsWording.chase(.afternoon), "Chasing the sun: their afternoon is stretching")
        XCTAssertEqual(FactsWording.moon(SkyFacts.Moon(phase: .waxingGibbous, isUp: true)), "Waxing gibbous moon, up")
        XCTAssertEqual(FactsWording.moon(SkyFacts.Moon(phase: .full, isUp: false)), "Full moon, below the horizon")
        XCTAssertEqual(plain(FactsWording.groundSun(.sunrise, at: now, in: zone("Europe/Berlin"), locale: locale)), "sunrise at 9:14 PM there")
    }

    // MARK: - Distance and landing

    func test_distance_andSpeed() {
        XCTAssertEqual(FactsWording.distance(flownMiles: 2_140, toGoMiles: 1_960, locale: locale), "2,140 mi flown · 1,960 to go")
        XCTAssertEqual(FactsWording.averageSpeed(milesPerHour: 504), "Averaging about 500 mph")
        XCTAssertEqual(FactsWording.averageSpeed(milesPerHour: 506), "Averaging about 510 mph")
        XCTAssertEqual(FactsWording.midLine("Like driving coast to coast"), "like driving coast to coast")
    }

    func test_weather() {
        XCTAssertEqual(FactsWording.weather(LandingForecast(temperature: "48°F", condition: "rain")), "48°F and rain on landing")
    }

    func test_timeDifference() {
        let yours = zone("America/New_York")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("Europe/Berlin"), to: yours, at: now), "6 hours ahead of you")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("America/Los_Angeles"), to: yours, at: now), "3 hours behind you")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("Asia/Kolkata"), to: yours, at: now), "10½ hours ahead of you")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("America/St_Johns"), to: zone("America/Halifax"), at: now), "½ hour ahead of you")
        XCTAssertEqual(FactsWording.timeDifference(from: zone("America/Chicago"), to: yours, at: now), "1 hour behind you")
        XCTAssertNil(FactsWording.timeDifference(from: zone("America/Detroit"), to: yours, at: now))
    }

    func test_lands_thereOrYourTime() {
        let cologne = MapLeg(id: "f", kind: .flight,
                             origin: FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74, city: "Louisville", zone: "America/New_York"),
                             destination: FactsTestData.mark("CGN", latitude: 50.87, longitude: 7.14, city: "Cologne", zone: "Europe/Berlin"),
                             start: now.addingTimeInterval(-3600), end: now, flightNumber: "UPS207")
        XCTAssertEqual(plain(FactsWording.lands(cologne, calendar: calendar, locale: locale)), "lands 9:14 PM there")
        XCTAssertEqual(FactsWording.flightTitle(cologne), "UPS207 · Louisville → Cologne")
        let home = MapLeg(id: "f", kind: .flight, origin: cologne.destination, destination: cologne.origin,
                          start: now.addingTimeInterval(-3600), end: now, flightNumber: nil)
        XCTAssertEqual(plain(FactsWording.lands(home, calendar: calendar, locale: locale)), "lands 3:14 PM")
        XCTAssertEqual(FactsWording.flightTitle(home), "Cologne → Louisville")
    }

    // MARK: - Totals and the recap

    func test_soFar_leavesOutZeros() {
        let totals = TripTotals(cities: 1, miles: 4_351, timeZones: 6, cockpitSunsets: 0)
        XCTAssertEqual(FactsWording.soFar(totals, dayNumber: 2, totalDays: 4, locale: locale), "Day 2 of 4 · 1 city · 4,351 mi · 6 time zones")
        XCTAssertNil(FactsWording.soFar(TripTotals(cities: 0, miles: 0, timeZones: 0, cockpitSunsets: 0), dayNumber: nil, totalDays: nil, locale: locale))
    }

    func test_onTheWay_aForecastSaysAbout() {
        let totals = TripTotals(cities: 2, miles: 9_800, timeZones: 8, cockpitSunsets: 2)
        XCTAssertEqual(FactsWording.onTheWay(totals, isForecast: true, locale: locale), "8 time zones · about 2 sunsets from the cockpit")
        XCTAssertEqual(FactsWording.onTheWay(totals, isForecast: false, locale: locale), "8 time zones · 2 sunsets from the cockpit")
        XCTAssertNil(FactsWording.onTheWay(TripTotals(cities: 1, miles: 100, timeZones: 0, cockpitSunsets: 0), isForecast: true, locale: locale))
    }

    func test_recapChip_oneDayOrMore() {
        XCTAssertEqual(FactsWording.recapChip(days: 1), "Home from a day away")
        XCTAssertEqual(FactsWording.recapChip(days: 4), "Home from 4 days away")
    }

    func test_recapTiles_leaveOutZeros_andSayOneSunset() {
        let tiles = FactsWording.recapTiles(TripTotals(cities: 2, miles: 14_819, timeZones: 0, cockpitSunsets: 1), locale: locale)
        XCTAssertEqual(tiles, [RecapTile(value: "2", label: "cities"), RecapTile(value: "14,819", label: "miles"),
                               RecapTile(value: "1", label: "sunset aloft")])
    }

    func test_recapSummary_isOneParagraph() {
        let longest = MapLeg(id: "f3", kind: .flight,
                             origin: FactsTestData.mark("DXB", latitude: 25.2532, longitude: 55.3657, city: "Dubai"),
                             destination: FactsTestData.mark("SDF", latitude: 38.1744, longitude: -85.7360, city: "Louisville"),
                             start: now, end: now.addingTimeInterval(14 * 3600), flightNumber: "UPS209")
        let totals = TripTotals(cities: 2, miles: 14_819, timeZones: 18, cockpitSunsets: 1)
        XCTAssertEqual(FactsWording.recapSummary(days: 4, totals: totals, longest: longest, locale: locale),
                       "Trip recap: home from 4 days away. 2 cities, 14,819 miles, 18 time zones, 1 sunset from the cockpit. Longest flight, Dubai to Louisville, 7,382 miles.")
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `FactsWordingTests`.

- [ ] **Step 3: Write the two small values.** Create `Crewluv/Services/TripMap/Facts/LandingForecast.swift`:

```swift
//
//  LandingForecast.swift
//  CrewLuve
//
//  The weather forecast for the hour a flight lands (Stage 2 spec §7).
//

nonisolated struct LandingForecast: Equatable, Sendable {
    /// "48°F", in the family's units.
    let temperature: String
    /// WeatherKit's description, lowercased: "rain", "mostly cloudy".
    let condition: String
}
```

Create `Crewluv/Services/TripMap/Facts/RecapTile.swift`:

```swift
//
//  RecapTile.swift
//  CrewLuve
//
//  One number on the recap card (Stage 2 spec §6.5): "2 cities", "14,819 miles".
//

nonisolated struct RecapTile: Identifiable, Equatable, Sendable {
    let value: String
    let label: String

    var id: String { label }
}
```

- [ ] **Step 4: Make three `TripMapWording` helpers internal.** In `Crewluv/Services/TripMap/TripMapWording.swift`:
  - replace `    // MARK: - Private` with `    // MARK: - Helpers, shared with FactsWording`;
  - replace `    private static func destinationNames(` with `    static func destinationNames(`;
  - replace `    private static func milesText(` with `    static func milesText(`;
  - replace `    private static func clockTime(` with `    static func clockTime(`.

  `arrivalLocalClock` and `style` stay private.

- [ ] **Step 5: Write `FactsWording`.** Create `Crewluv/Services/TripMap/Facts/FactsWording.swift`:

```swift
//
//  FactsWording.swift
//  CrewLuve
//
//  The facts' sentences (Stage 2 spec §4, §5): milestones, what's below, the sky, distance and landing. Times are the
//  family's own, in `calendar.timeZone`, unless the words say "there". Totals and the recap are in
//  FactsWording+Trip.swift.
//

import Foundation

nonisolated enum FactsWording {

    // MARK: - Milestones (§4.3)

    /// The headline: "Just crossed into Kansas", "Out over the Atlantic", "Halfway!", "Closest to home: 40 mi, wave!".
    static func headline(for kind: Milestone.Kind) -> String {
        switch kind {
        case .crossedInto(let name): "Just crossed into \(name)"
        case .outOver(let name): "Out over \(name)"
        case .halfway: "Halfway!"
        case .closestToHome(let miles): "Closest to home: \(miles) mi, wave!"
        }
    }

    /// The tall stop's list: "Crossed into Kansas · 1:12 PM".
    static func listLine(for milestone: Milestone, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let time = TripMapWording.clockTime(milestone.time, in: calendar.timeZone, locale: locale)
        switch milestone.kind {
        case .crossedInto(let name): return "Crossed into \(name) · \(time)"
        case .outOver(let name): return "Out over \(name) · \(time)"
        case .halfway: return "Halfway · \(time)"
        case .closestToHome(let miles): return "Closest to home, \(miles) mi · \(time)"
        }
    }

    /// "UPS207 · Louisville → Cologne", or the cities alone without a flight number.
    static func flightTitle(_ leg: MapLeg) -> String {
        let route = "\(leg.origin.name) → \(leg.destination.name)"
        return leg.flightNumber.map { "\($0) · \(route)" } ?? route
    }

    // MARK: - Below (§4.1)

    /// "Over Kansas", "Over Québec, near Montréal".
    static func below(_ place: Geography.Place, near city: Geography.City?) -> String {
        city.map { "Over \(place.name), near \($0.name)" } ?? "Over \(place.name)"
    }

    /// "Passes 40 mi from home at 1:05 PM", or "Closest to home was 40 mi at 1:05 PM" once it's passed.
    static func closestToHome(miles: Int, at time: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let clock = TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale)
        return time > now ? "Passes \(miles) mi from home at \(clock)" : "Closest to home was \(miles) mi at \(clock)"
    }

    // MARK: - The sky (§4.5)

    /// The headline: "Sunset from the cockpit in 25 min".
    static func cockpitCountdown(_ event: SkyFacts.SunEvent, now: Date) -> String {
        "\(name(of: event.kind)) from the cockpit in \(minutes(from: now, to: event.time)) min"
    }

    /// The sky row: "Sunset in 25 min, about 12 min after the people below", or "Sunrise at 6:38 AM" an hour or more
    /// ahead.
    static func cockpitEvent(_ event: SkyFacts.SunEvent, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let when = event.time.timeIntervalSince(now) < 3600
            ? "in \(minutes(from: now, to: event.time)) min"
            : "at \(TripMapWording.clockTime(event.time, in: calendar.timeZone, locale: locale))"
        guard let gap = event.peopleBelowGap else { return "\(name(of: event.kind)) \(when)" }
        let side = event.kind == .sunset ? "after" : "before"
        return "\(name(of: event.kind)) \(when), about \(Int((gap / 60).rounded())) min \(side) the people below"
    }

    static func flyingInto(_ kind: SkyFacts.SunEvent.Kind) -> String {
        kind == .sunset ? "Flying into the night" : "Flying into the morning"
    }

    static func chase(_ chase: SkyFacts.Chase) -> String {
        "Chasing the sun: their \(chase == .afternoon ? "afternoon" : "morning") is stretching"
    }

    /// "Waxing gibbous moon, up", "Full moon, below the horizon".
    static func moon(_ moon: SkyFacts.Moon) -> String {
        "\(moonName(moon.phase)), \(moon.isUp ? "up" : "below the horizon")"
    }

    static func moonName(_ phase: LunarPhase) -> String {
        switch phase {
        case .new: "New moon"
        case .waxingCrescent: "Waxing crescent moon"
        case .firstQuarter: "First quarter moon"
        case .waxingGibbous: "Waxing gibbous moon"
        case .full: "Full moon"
        case .waningGibbous: "Waning gibbous moon"
        case .lastQuarter: "Last quarter moon"
        case .waningCrescent: "Waning crescent moon"
        }
    }

    /// On the ground at an airport: "sunrise at 7:02 AM there".
    static func groundSun(_ kind: SkyFacts.SunEvent.Kind, at time: Date, in zone: TimeZone, locale: Locale = .current) -> String {
        "\(kind == .sunrise ? "sunrise" : "sunset") at \(TripMapWording.clockTime(time, in: zone, locale: locale)) there"
    }

    // MARK: - Distance (§4.6)

    /// "2,140 mi flown · 1,960 to go".
    static func distance(flownMiles: Int, toGoMiles: Int, locale: Locale = .current) -> String {
        "\(number(flownMiles, locale: locale)) mi flown · \(number(toGoMiles, locale: locale)) to go"
    }

    static func halfway(at time: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        "Halfway at \(TripMapWording.clockTime(time, in: calendar.timeZone, locale: locale))"
    }

    /// "Averaging about 510 mph", to the nearest 10.
    static func averageSpeed(milesPerHour: Double) -> String {
        "Averaging about \(Int((milesPerHour / 10).rounded()) * 10) mph"
    }

    /// A comparison in the middle of a line: "like driving coast to coast".
    static func midLine(_ phrase: String) -> String {
        phrase.prefix(1).lowercased() + phrase.dropFirst()
    }

    // MARK: - Where they're headed (§4.7)

    /// "48°F and rain on landing".
    static func weather(_ forecast: LandingForecast) -> String {
        "\(forecast.temperature) and \(forecast.condition) on landing"
    }

    /// "6 hours ahead of you", "5½ hours behind you", "½ hour ahead of you", or nil when the clocks match.
    static func timeDifference(from zone: TimeZone, to yours: TimeZone, at date: Date) -> String? {
        let seconds = zone.secondsFromGMT(for: date) - yours.secondsFromGMT(for: date)
        guard seconds != 0 else { return nil }
        let quarters = abs(seconds) / 900
        let whole = quarters / 4
        let part = ["", "¼", "½", "¾"][quarters % 4]
        let amount = whole == 0 ? part : "\(whole)\(part)"
        let unit = quarters <= 4 ? "hour" : "hours"
        return "\(amount) \(unit) \(seconds > 0 ? "ahead of" : "behind") you"
    }

    /// "lands 4:05 PM there", or in the family's time when the destination keeps it or its zone isn't known.
    static func lands(_ leg: MapLeg, calendar: Calendar = .current, locale: Locale = .current) -> String {
        if let there = leg.destination.timeZone,
           there.secondsFromGMT(for: leg.end) != calendar.timeZone.secondsFromGMT(for: leg.end) {
            return "lands \(TripMapWording.clockTime(leg.end, in: there, locale: locale)) there"
        }
        return "lands \(TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale))"
    }

    // MARK: - Helpers

    static func number(_ value: Int, locale: Locale = .current) -> String {
        value.formatted(.number.locale(locale))
    }

    /// Whole minutes until `time`, rounded up, and at least 1.
    private static func minutes(from now: Date, to time: Date) -> Int {
        max(1, Int((time.timeIntervalSince(now) / 60).rounded(.up)))
    }

    private static func name(of kind: SkyFacts.SunEvent.Kind) -> String {
        kind == .sunrise ? "Sunrise" : "Sunset"
    }
}
```

- [ ] **Step 6: Write the trip sentences.** Create `Crewluv/Services/TripMap/Facts/FactsWording+Trip.swift`:

```swift
//
//  FactsWording+Trip.swift
//  CrewLuve
//
//  The facts' sentences about the whole trip (Stage 2 spec §4.8, §5, §6.5): totals so far, a trip ahead's forecast,
//  and the recap.
//

import Foundation

nonisolated extension FactsWording {

    /// "1 city", "2 cities".
    static func count(_ value: Int, _ one: String, _ many: String, locale: Locale = .current) -> String {
        "\(number(value, locale: locale)) \(value == 1 ? one : many)"
    }

    /// "1 day", "4 days".
    static func days(_ value: Int) -> String {
        value == 1 ? "1 day" : "\(value) days"
    }

    // MARK: - Totals

    /// "Day 2 of 4 · 1 city · 4,350 mi · 6 time zones · 1 sunset from the cockpit", with zeros left out. Nil when there's
    /// nothing to say.
    static func soFar(_ totals: TripTotals, dayNumber: Int?, totalDays: Int?, locale: Locale = .current) -> String? {
        var parts: [String] = []
        if let dayNumber, let totalDays { parts.append("Day \(dayNumber) of \(totalDays)") }
        if totals.cities > 0 { parts.append(count(totals.cities, "city", "cities", locale: locale)) }
        if totals.miles > 0 { parts.append(TripMapWording.milesText(totals.miles, locale: locale)) }
        if let onTheWay = onTheWay(totals, isForecast: false, locale: locale) { parts.append(onTheWay) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "8 time zones · about 2 sunsets from the cockpit" for a trip ahead, without "about" once flown. Nil when both
    /// are zero.
    static func onTheWay(_ totals: TripTotals, isForecast: Bool, locale: Locale = .current) -> String? {
        var parts: [String] = []
        if totals.timeZones > 0 {
            parts.append(count(totals.timeZones, "time zone", "time zones", locale: locale))
        }
        if totals.cockpitSunsets > 0 {
            let sunsets = count(totals.cockpitSunsets, "sunset from the cockpit", "sunsets from the cockpit", locale: locale)
            parts.append(isForecast ? "about \(sunsets)" : sunsets)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "Dubai → Louisville, 7,382 mi".
    static func longest(_ leg: MapLeg, locale: Locale = .current) -> String {
        "\(leg.origin.name) → \(leg.destination.name), \(TripMapWording.milesText(miles(of: leg), locale: locale))"
    }

    // MARK: - The recap (§6.5)

    /// "Home from 4 days away", or "Home from a day away".
    static func recapChip(days: Int) -> String {
        days == 1 ? "Home from a day away" : "Home from \(days) days away"
    }

    /// Up to four numbers, with zeros left out.
    static func recapTiles(_ totals: TripTotals, locale: Locale = .current) -> [RecapTile] {
        let tiles: [(value: Int, one: String, many: String)] = [
            (totals.cities, "city", "cities"),
            (totals.miles, "mile", "miles"),
            (totals.timeZones, "time zone", "time zones"),
            (totals.cockpitSunsets, "sunset aloft", "sunsets aloft"),
        ]
        return tiles.filter { $0.value > 0 }.map {
            RecapTile(value: number($0.value, locale: locale), label: $0.value == 1 ? $0.one : $0.many)
        }
    }

    /// The recap card as VoiceOver reads it: "Trip recap: home from 4 days away. 2 cities, 14,819 miles,
    /// 18 time zones, 1 sunset from the cockpit. Longest flight, Dubai to Louisville, 7,382 miles."
    static func recapSummary(days: Int, totals: TripTotals, longest: MapLeg?, locale: Locale = .current) -> String {
        let chip = recapChip(days: days)
        var sentences = ["Trip recap: \(chip.prefix(1).lowercased() + chip.dropFirst())."]
        let counts = [
            totals.cities > 0 ? count(totals.cities, "city", "cities", locale: locale) : nil,
            totals.miles > 0 ? count(totals.miles, "mile", "miles", locale: locale) : nil,
            totals.timeZones > 0 ? count(totals.timeZones, "time zone", "time zones", locale: locale) : nil,
            totals.cockpitSunsets > 0 ? count(totals.cockpitSunsets, "sunset from the cockpit", "sunsets from the cockpit", locale: locale) : nil,
        ].compactMap { $0 }
        if !counts.isEmpty {
            sentences.append(counts.joined(separator: ", ") + ".")
        }
        if let longest {
            let longestMiles = number(miles(of: longest), locale: locale)
            sentences.append("Longest flight, \(longest.origin.name) to \(longest.destination.name), \(longestMiles) miles.")
        }
        return sentences.joined(separator: " ")
    }

    // MARK: - Private

    private static func miles(of leg: MapLeg) -> Int {
        Int((leg.distance / GreatCircle.metersPerMile).rounded())
    }
}
```

- [ ] **Step 7: Run the tests, expecting them to pass.** Todd runs `FactsWordingTests`, and `TripMapWordingTests` to check nothing moved.

- [ ] **Step 8: Ask to commit.** Suggested message: `feat(crewluv): FactsWording, every sentence the facts say (Stage 2 spec §4, §5, §6.5)`.

---

### Task 12: The recap mode

For 24 hours after a trip ends, the card is that trip's recap (Stage 2 spec §8). This task adds the mode, picks the trip, starts the replay paused at the trip's start, and gives Stage 1's words their recap cases.

**Files:**
- Modify: `Crewluv/Services/TripMap/TripMap.swift`
- Modify: `Crewluv/Services/TripMap/TripMap+Status.swift`
- Modify: `Crewluv/Services/TripMap/TripReplayClock.swift`
- Modify: `Crewluv/Services/TripMap/TripMapWording.swift`
- Modify: `CrewluvTests/Helpers/TripMapTestLegs.swift` (a `tripTotalDays` parameter)
- Test: `CrewluvTests/TripMapRecapTests.swift`, `CrewluvTests/TripReplayClockTests.swift`, `CrewluvTests/TripMapWordingTests.swift`

- [ ] **Step 1: Let the test legs carry a trip length.** In `CrewluvTests/Helpers/TripMapTestLegs.swift`, in `leg(...)`:
  - add a last parameter `tripTotalDays: Int? = nil` after `tripId: String? = "T1"`;
  - pass `tripTotalDays: tripTotalDays` in place of `tripTotalDays: nil`.

  Existing callers are unchanged.

- [ ] **Step 2: Write the failing tests.** Create `CrewluvTests/TripMapRecapTests.swift`:

```swift
//
//  TripMapRecapTests.swift
//  CrewluvTests
//
//  The recap (Stage 2 spec §8): for 24 hours after a trip ends at home, the map is that trip, unless the next trip
//  leaves within 12 hours.
//

import XCTest
@testable import Crewluv

final class TripMapRecapTests: XCTestCase {

    private let now = TripMapTestLegs.tripStart
    private func hours(_ value: Double) -> Date { now.addingTimeInterval(value * 3600) }

    /// The Europe trip (72 hours) ending `hoursAgo` hours before now.
    private func trip(endingHoursAgo hoursAgo: Double) -> [TripLeg] {
        TripMapTestLegs.europeTrip(startingAt: hours(-72 - hoursAgo))
    }

    private func nextTrip(leavingIn hoursAhead: Double) -> [TripLeg] {
        [TripMapTestLegs.leg("n1", from: "SDF", to: "ANC", start: hours(hoursAhead), hours: 6, tripId: "T2")]
    }

    func test_initStatus_aTripEnded3HoursAgo_isItsRecap() throws {
        let map = try XCTUnwrap(TripMap(status: status(legs: trip(endingHoursAgo: 3)), at: now))
        XCTAssertEqual(map.mode, .recap)
        XCTAssertEqual(map.legs.map(\.id), ["f1", "f2", "f3"])
    }

    func test_initStatus_aTripEnded30HoursAgo_isNoRecap() {
        XCTAssertNil(TripMap(status: status(legs: trip(endingHoursAgo: 30)), at: now), "nothing ahead either")
    }

    func test_initStatus_theNextTripLeavingWithin12Hours_winsOverTheRecap() throws {
        let map = try XCTUnwrap(TripMap(status: status(legs: trip(endingHoursAgo: 3) + nextTrip(leavingIn: 10)), at: now))
        XCTAssertEqual(map.mode, .nextTrip)
        XCTAssertEqual(map.legs.map(\.id), ["n1"])
    }

    func test_initStatus_theNextTripLeavingLater_leavesTheRecap() throws {
        let map = try XCTUnwrap(TripMap(status: status(legs: trip(endingHoursAgo: 3) + nextTrip(leavingIn: 14)), at: now))
        XCTAssertEqual(map.mode, .recap)
    }

    func test_initStatus_aNightAtHomeMidTrip_isNoRecap() {
        let legs = [
            TripMapTestLegs.leg("h1", from: "SDF", to: "CGN", start: hours(-30), hours: 8),
            TripMapTestLegs.leg("h2", from: "CGN", to: "SDF", start: hours(-14), hours: 9),
            TripMapTestLegs.leg("n", .home, start: hours(-5), hours: 15),
            TripMapTestLegs.leg("h3", from: "SDF", to: "DXB", start: hours(10), hours: 13),
        ]
        XCTAssertNotEqual(TripMap(status: status(legs: legs), at: now)?.mode, .recap)
    }

    func test_pilotLocation_afterTheRecapsTrip_isHome() throws {
        let map = try XCTUnwrap(TripMap(status: status(legs: trip(endingHoursAgo: 3)), at: now))
        XCTAssertEqual(map.pilotLocation(at: now)?.code, "SDF")
    }

    func test_dayCount_crewLusCount_elseCalendarDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let counted = TripMapTestLegs.europeTrip().enumerated().map { index, leg in
            index == 0 ? TripMapTestLegs.leg(leg.id, leg.type, from: leg.departureAirport, to: leg.arrivalAirport, start: leg.startTime,
                                             hours: leg.endTime.timeIntervalSince(leg.startTime) / 3600, tripTotalDays: 5) : leg
        }
        XCTAssertEqual(try XCTUnwrap(TripMapTestLegs.map(counted, at: now)).dayCount(in: calendar), 5)
        XCTAssertEqual(try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: now)).dayCount(in: calendar), 4,
                       "Friday 7 AM to Monday 7 AM in Louisville")
    }

    // MARK: - Status

    /// A status at home, as `PartnerStatusReceiver` publishes it.
    private func status(legs: [TripLeg]) -> SharedPilotStatus {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return SharedPilotStatus(
            pilotId: "pilot", pilotFirstName: "Alex", homeAirportCode: "SDF", baseAirportCode: "SDF",
            homeTimezone: "America/Kentucky/Louisville", displayStatus: .home, isSleeping: false, isHome: true,
            isInFlight: false, isOnDuty: false, currentAirport: "SDF", currentCity: "Louisville",
            currentTimezone: "America/Kentucky/Louisville", localTimeAtPilot: nil, currentLatitude: nil,
            currentLongitude: nil, currentFlightNumber: nil, currentFlightDeparture: nil, currentFlightArrival: nil,
            currentFlightDepartureTime: nil, currentFlightArrivalTime: nil, currentFlightArrivalTimezone: nil,
            homeArrivalTime: nil, homeArrivalLabel: nil, homeArrivalCity: nil, nextDepartureTime: nil,
            nextFlightNumber: nil, nextFlightDestination: nil, nextDepartureLabel: nil, lastTripEndDate: nil,
            lastTripDurationDays: nil, currentTripId: nil, tripDayNumber: nil, tripTotalDays: nil, upcomingCities: [],
            tripLegsJSON: try? encoder.encode(legs), quickStatus: nil, quickStatusIcon: nil, quickStatusExpiry: nil,
            flightDelayMinutes: nil, displayNameByPartnerJSON: nil, lastUpdated: now, appVersion: "test"
        )
    }
}
```

  Add to `TripReplayClockTests`, before its closing brace:

```swift
    func test_initPausedAt_isPausedThere() {
        let clock = TripReplayClock(span: span, pausedAt: span.start)
        XCTAssertFalse(clock.isLive)
        XCTAssertFalse(clock.isPlaying)
        XCTAssertEqual(clock.time(at: now), span.start)
    }
```

  Add to `TripMapWordingTests`, before its closing brace:

```swift
    // MARK: - The recap (Stage 2 spec §6.5)

    private func recap() throws -> TripMap {
        try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false, isRecap: true, homeAirportCode: "SDF",
                                   legacyDelayMinutes: nil, at: now, coordinate: TripMapTestLegs.coordinate))
    }

    func test_cardChips_recap_homeFromDaysAway_andReplay() throws {
        let map = try recap()
        let chips = TripMapWording.cardChips(for: map, at: map.span.end.addingTimeInterval(3600), calendar: calendar, locale: locale)
        XCTAssertEqual(chips.top, "Home from 4 days away")
        XCTAssertEqual(chips.bottom, "Replay the trip")
    }

    func test_topPill_recapAfterTheTrip_isTripRecap() throws {
        let map = try recap()
        XCTAssertEqual(TripMapWording.topPill(for: map, at: map.span.end, dayNumber: nil, totalDays: nil), "Trip recap")
    }

    func test_statsItems_recap_isEmpty() throws {
        let map = try recap()
        XCTAssertEqual(TripMapWording.statsItems(for: map, at: map.span.end, dayNumber: nil, totalDays: nil), [])
    }
```

- [ ] **Step 3: Run them, expecting a build failure.** Todd runs `TripMapRecapTests`, `TripReplayClockTests` and `TripMapWordingTests`.

- [ ] **Step 4: Add the mode to `TripMap`.** In `Crewluv/Services/TripMap/TripMap.swift`:
  - In `enum Mode`, after `case nextTrip`, add:

```swift
        /// Home, within a day of this trip ending: its recap (Stage 2 spec §8).
        case recap
```

  - After `let span: DateInterval`, add:

```swift
    /// CrewLu's count of the trip's days, when the legs carry it.
    let tripDays: Int?
```

  - After `nextFlight(after:)`, add:

```swift
    /// The trip's days: CrewLu's count when the legs carry it, else the calendar days it spans.
    func dayCount(in calendar: Calendar) -> Int {
        if let tripDays { return tripDays }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: span.start), to: calendar.startOfDay(for: span.end)).day ?? 0
        return days + 1
    }
```

  - In `pilotLocation(at:)`, before its `if mode == .nextTrip` line, add:

```swift
        if mode == .recap, date >= span.end { return home ?? legs.last?.destination }
```

  - In `make(...)`, add `isRecap: Bool = false,` after `isNextTrip: Bool,` in the parameters, add `/// - isRecap: the legs are a trip just finished, shown as its recap.` to its doc comment, and replace the mode choice and the return with:

```swift
        let mode: Mode
        if isRecap {
            mode = .recap
        } else if isNextTrip {
            mode = .nextTrip
        } else if let flying = legs.first(where: { $0.kind == .flight && $0.isMoving(at: now) }) {
            mode = .inFlight(legID: flying.id)
        } else {
            mode = .onTrip
        }
        let firstDeparture = legs.map(\.start).min() ?? first.start
        return TripMap(mode: mode, legs: legs, home: home,
                       span: DateInterval(start: firstDeparture, end: max(lastArrival, firstDeparture)),
                       tripDays: tripLegs.compactMap(\.tripTotalDays).max())
```

- [ ] **Step 5: Pick the recap's trip in `TripMap+Status`.** In `Crewluv/Services/TripMap/TripMap+Status.swift`:
  - In the header comment, add a line after the first bullet: `//  - at home or base within a day of a trip ending, that trip's recap, unless the next trip leaves within 12 hours;`
  - In `init?(status:at:)`, replace everything from `let isSettled = status.displayStatus.isSettled` through the `guard let map = TripMap.make(` statement with:

```swift
        let isSettled = status.displayStatus.isSettled
        let recapLegs = isSettled ? Self.recapLegs(in: status.tripLegs, at: now) : nil
        let legs: [TripLeg]
        if let recapLegs {
            legs = recapLegs
        } else if isSettled {
            guard let trip = UpcomingTripInfo.from(tripLegs: status.tripLegs, at: now, homeAirportCode: status.homeAirportCode) else { return nil }
            legs = status.tripLegs.filter { $0.tripId == trip.tripId }
        } else if status.hasTripLegs {
            let segment = TripStateResolver.contiguousSegment(covering: now, in: status.tripLegs)
            // Legs that no longer cover now (stale, or a flight running late past them) still leave the
            // summary's flight in the air to draw, as the old in-flight map did.
            legs = segment.isEmpty ? (Self.currentFlightLeg(of: status).map { [$0] } ?? []) : segment
        } else {
            legs = Self.currentFlightLeg(of: status).map { [$0] } ?? []
        }
        // A night at home or base in the middle of a trip (CrewLu's `.home` or `.base` leg between two duty periods)
        // reads as settled, and its upcoming trip is the rest of the trip under way. Only a trip with no leg started yet
        // is the next trip; shown as one, the trip under way would start on a date already past.
        let isNextTrip = recapLegs == nil && isSettled && legs.allSatisfy { $0.startTime > now }
        guard let map = TripMap.make(tripLegs: legs, isNextTrip: isNextTrip, isRecap: recapLegs != nil,
                                     homeAirportCode: status.homeAirportCode ?? status.baseAirportCode,
                                     legacyDelayMinutes: status.flightDelayMinutes, at: now, coordinate: coordinate) else { return nil }
```

  The block being replaced is the one the mid-trip-at-home fix (`8d02c08`) left. Its logic stays: only the `recapLegs` lines are new.

  - After `init?(status:at:)`, add:

```swift
    /// How long a recap shows after its trip's last leg ends (Stage 2 spec §8.1).
    static let recapDuration: TimeInterval = 24 * 3600
    /// A next trip leaving this soon takes over from the recap.
    static let recapYieldsWithin: TimeInterval = 12 * 3600

    /// The legs of the trip whose last leg ended in the past 24 hours, or nil when there's none or the next trip leaves
    /// within 12 hours. Legs with no trip, like a standalone jumpseat, aren't a trip.
    static func recapLegs(in tripLegs: [TripLeg], at now: Date) -> [TripLeg]? {
        let trips = Dictionary(grouping: tripLegs.filter { $0.tripId != nil }, by: \.tripId)
        let finished = trips.values.compactMap { legs -> (legs: [TripLeg], end: Date)? in
            guard let end = legs.map(\.endTime).max(), end <= now, now.timeIntervalSince(end) < recapDuration else { return nil }
            return (legs, end)
        }
        guard let recap = finished.max(by: { $0.end < $1.end }) else { return nil }
        let nextDeparture = tripLegs.filter { $0.tripId != nil && $0.startTime > now }.map(\.startTime).min()
        if let nextDeparture, nextDeparture.timeIntervalSince(now) <= recapYieldsWithin { return nil }
        return recap.legs
    }
```

- [ ] **Step 6: Start the replay paused.** In `Crewluv/Services/TripMap/TripReplayClock.swift`, after `init(span:)`, add:

```swift
    /// Paused at `date`: the recap opens at its trip's start, ready to play (Stage 2 spec §6.5).
    init(span: DateInterval, pausedAt date: Date) {
        self.init(span: span)
        scrub(to: date)
    }
```

- [ ] **Step 7: Give Stage 1's words their recap cases.** In `Crewluv/Services/TripMap/TripMapWording.swift`:
  - In `cardChips(for:at:calendar:locale:)`, add a case after `.nextTrip`'s:

```swift
        case .recap:
            return (FactsWording.recapChip(days: tripMap.dayCount(in: calendar)), "Replay the trip")
```

  - In `statsItems(for:at:dayNumber:totalDays:calendar:locale:)`, change `case .inFlight:` to `case .inFlight, .recap:`. The recap card shows `TripRecapBar` in its place.
  - In `topPill(for:at:dayNumber:totalDays:)`, add as its first line:

```swift
        if tripMap.mode == .recap, date >= tripMap.span.end { return "Trip recap" }
```

  - In `cardSummary(for:now:pilotName:calendar:locale:)`, add a case after `.nextTrip`'s. The card reads `TripFacts.cardSummary`, which gives the full sentence; this is the short fallback:

```swift
        case .recap:
            let chip = FactsWording.recapChip(days: tripMap.dayCount(in: calendar))
            return "Trip recap: \(chip.prefix(1).lowercased() + chip.dropFirst())."
```

- [ ] **Step 8: Run the tests, expecting them to pass.** Todd runs `TripMapRecapTests`, `TripReplayClockTests`, `TripMapWordingTests`, `TripMapTests` and `TripMapStatusTests`.

- [ ] **Step 9: Ask to commit.** Suggested message: `feat(crewluv): the trip map's recap mode, for a day after a trip ends, and the replay that opens paused at its start (Stage 2 spec §8)`.

---
### Task 13: `TripFacts`: the headline, the tall stop and the card

`TripFacts` answers the facts' questions at any moment (Stage 2 spec §3.1, §4.4, §5.2). This task adds its core. Task 14 adds the rows.

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/FactRow.swift`
- Create: `Crewluv/Services/TripMap/Facts/TripSoFar.swift`
- Create: `Crewluv/Services/TripMap/Facts/TripFacts.swift`
- Test: `CrewluvTests/TripFactsTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripFactsTests.swift`:

```swift
//
//  TripFactsTests.swift
//  CrewluvTests
//
//  The headline, the tall stop, weather's window and the card's words (Stage 2 spec §4.4, §5.2, §6, §7.3). The
//  flight along the equator crosses into Bravo at 11:00 UTC, is halfway at 11:45, out over the Test Sea at 12:03 and
//  closest to home (35 mi) at 12:21: 7:00, 7:45, 8:03 and 8:21 AM in Louisville.
//

import XCTest
@testable import Crewluv

final class TripFactsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func at(_ time: String) -> Date { FactsTestData.date("2026-03-20T\(time):00Z") }

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func equatorFacts(hasStory: Bool = true, forecasts: [String: LandingForecast] = [:]) -> TripFacts {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        let home = FactsTestData.mark("HOME", latitude: 0.5, longitude: 14)
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: nil,
                         stories: hasStory ? [leg.id: LegStory(leg: leg, geography: FactsTestData.equator, home: home)] : [:],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], forecasts: forecasts,
                         dayNumber: 1, totalDays: 1, calendar: calendar, locale: locale)
    }

    private func europeRecap() throws -> TripFacts {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false, isRecap: true,
                                             homeAirportCode: "SDF", legacyDelayMinutes: nil, at: TripMapTestLegs.tripStart,
                                             coordinate: TripMapTestLegs.coordinate))
        let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        return TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: sunEvents,
                         calendar: calendar, locale: locale)
    }

    // MARK: - The headline (§4.4)

    func test_headline_inPriorityOrder() {
        let facts = equatorFacts()
        XCTAssertEqual(facts.headline(at: at("11:02")), "Just crossed into Bravo")
        XCTAssertEqual(facts.headline(at: at("11:10")), "Over Bravo, near Testville", "the crossing was 10 minutes ago")
        XCTAssertEqual(facts.headline(at: at("11:46")), "Halfway!")
        XCTAssertEqual(facts.headline(at: at("12:05")), "Out over the Test Sea")
        XCTAssertEqual(facts.headline(at: at("12:22")), "Closest to home: 35 mi, wave!")
        XCTAssertEqual(facts.headline(at: at("12:40")), "Over the Test Sea")
    }

    func test_headline_beforeTheStoryIsReady_isTheLandingCountdown() {
        XCTAssertEqual(equatorFacts(hasStory: false).headline(at: at("12:10")), "Landing in 1 h 12 min")
    }

    func test_headline_aCockpitSunriseWithin30Minutes_comesBeforeThePlace() {
        let start = FactsTestData.date("2026-11-13T23:00:00Z")
        let leg = MapLeg(id: "night", kind: .flight,
                         origin: AirportMark(code: "SDF", city: "Louisville", coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                         destination: AirportMark(code: "CGN", city: "Cologne", coordinate: TripMapTestLegs.airports["CGN"]!, timeZone: nil),
                         start: start, end: start.addingTimeInterval(8 * 3600), flightNumber: "UPS207")
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)])
        XCTAssertEqual(facts.headline(at: FactsTestData.date("2026-11-14T06:17:43Z")), "Sunrise from the cockpit in 21 min")
    }

    func test_headline_onTheGround_isNil() throws {
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: TripMapTestLegs.tripStart.addingTimeInterval(12 * 3600)))
        let facts = TripFacts(tripMap: map, geography: nil, comparisons: nil, stories: [:], sunEvents: [:])
        XCTAssertNil(facts.headline(at: TripMapTestLegs.tripStart.addingTimeInterval(12 * 3600)))
    }

    // MARK: - Weather's window (§7.3)

    func test_forecast_onlyForALandingWithin48HoursOfNow() {
        let facts = equatorFacts(forecasts: ["eq": LandingForecast(temperature: "81°F", condition: "clear")])
        let leg = facts.tripMap.legs[0]
        XCTAssertNotNil(facts.forecast(for: leg, now: at("11:10")))
        XCTAssertNil(facts.forecast(for: leg, now: at("13:30")), "already landed")
        XCTAssertNil(facts.forecast(for: leg, now: leg.end.addingTimeInterval(-49 * 3600)), "more than 48 hours out")
    }

    // MARK: - The tall stop (§5.2)

    func test_tripSoFar_listsThisFlightsMilestones_thenTheTotals() {
        let tripSoFar = equatorFacts().tripSoFar(at: at("12:30"))
        XCTAssertEqual(tripSoFar.flights.map(\.title), ["TST1 · E0 → E20"])
        XCTAssertEqual(tripSoFar.flights.first?.milestones.map { plain($0) }, [
            "Crossed into Bravo · 7:00 AM", "Halfway · 7:45 AM", "Out over the Test Sea · 8:03 AM", "Closest to home, 35 mi · 8:21 AM",
        ])
        XCTAssertEqual(tripSoFar.totalsTitle, "Trip so far")
        XCTAssertEqual(tripSoFar.totals, "Day 1 of 1 · 1,036 mi")
    }

    func test_tripSoFar_onlyMilestonesThatHaveHappened() {
        XCTAssertEqual(equatorFacts().tripSoFar(at: at("11:50")).flights.first?.milestones.count, 2)
    }

    func test_tripSoFar_afterARecapsTrip_isTheRecap() throws {
        let facts = try europeRecap()
        let tripSoFar = facts.tripSoFar(at: facts.tripMap.span.end.addingTimeInterval(3600))
        XCTAssertEqual(tripSoFar.totalsTitle, "Trip recap")
        XCTAssertEqual(tripSoFar.totals, "2 cities · 14,819 mi · 18 time zones · 1 sunset from the cockpit")
    }

    // MARK: - The card (§6.4, §6.5)

    func test_cardSummary_inFlight_addsThePlaceBelow() {
        XCTAssertEqual(plain(equatorFacts().cardSummary(now: at("11:10"), pilotName: "Alex")),
                       "TST1 to E20, over Bravo. Lands at 9:22 AM your time. Estimated from the schedule.")
    }

    func test_recap_tilesLongestAndSummary() throws {
        let facts = try europeRecap()
        XCTAssertEqual(facts.recapTiles, [RecapTile(value: "2", label: "cities"), RecapTile(value: "14,819", label: "miles"),
                                          RecapTile(value: "18", label: "time zones"), RecapTile(value: "1", label: "sunset aloft")])
        XCTAssertEqual(facts.recapLongestLine, "Longest: Dubai → Louisville, 7,382 mi")
        XCTAssertEqual(facts.cardSummary(now: facts.tripMap.span.end, pilotName: "Alex"),
                       "Trip recap: home from 4 days away. 2 cities, 14,819 miles, 18 time zones, 1 sunset from the cockpit. Longest flight, Dubai to Louisville, 7,382 miles.")
    }

    func test_sheetHeadline_afterARecapsTrip_isHomeFromDaysAway() throws {
        let facts = try europeRecap()
        XCTAssertTrue(facts.isRecapOver(at: facts.tripMap.span.end))
        XCTAssertEqual(facts.sheetHeadline(at: facts.tripMap.span.end.addingTimeInterval(3600)), "Home from 4 days away")
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `TripFactsTests`.

- [ ] **Step 3: Write `FactRow`.** Create `Crewluv/Services/TripMap/Facts/FactRow.swift`:

```swift
//
//  FactRow.swift
//  CrewLuve
//
//  One row of the facts sheet (Stage 2 spec §5): a symbol, a title and a second line made of the row's other parts.
//

nonisolated struct FactRow: Identifiable, Equatable, Sendable {

    nonisolated enum Kind: String, Sendable {
        // In flight (§5.1)
        case below, sky, distance, headed
        // On a layover (§5.3), at home before a trip (§5.4) and in the recap (§5.5)
        case whereTheyAre, nextFlight, leaves, tripAhead, theTrip, onTheWay, tripSoFar, longestFlight
    }

    let kind: Kind
    /// An SF Symbol.
    let symbolName: String
    let title: String
    /// The other parts, joined by " · ", or nil when there are none.
    let detail: String?
    /// True when the row shows a WeatherKit forecast, which needs Apple's attribution (§7.2).
    let hasWeather: Bool

    var id: Kind { kind }

    /// The row as VoiceOver reads it.
    var sentence: String {
        [title, detail].compactMap { $0 }.joined(separator: ". ")
    }

    /// A row whose second line is `details` without the nils.
    init(_ kind: Kind, symbol: String, title: String, details: [String?] = [], hasWeather: Bool = false) {
        self.kind = kind
        symbolName = symbol
        self.title = title
        let parts = details.compactMap { $0 }
        detail = parts.isEmpty ? nil : parts.joined(separator: " · ")
        self.hasWeather = hasWeather
    }
}
```

- [ ] **Step 4: Write `TripSoFar`.** Create `Crewluv/Services/TripMap/Facts/TripSoFar.swift`:

```swift
//
//  TripSoFar.swift
//  CrewLuve
//
//  The facts sheet dragged all the way up (Stage 2 spec §5.2, §5.5): each started flight's milestones, newest flight
//  first, then the totals.
//

nonisolated struct TripSoFar: Equatable, Sendable {

    nonisolated struct Flight: Identifiable, Equatable, Sendable {
        let id: String
        /// "UPS207 · Louisville → Cologne".
        let title: String
        /// "Crossed into Canada · 1:12 PM", in order.
        let milestones: [String]
    }

    /// Flights with at least one milestone so far.
    let flights: [Flight]
    /// "Trip so far", or "Trip recap" once a recap's trip is over.
    let totalsTitle: String
    let totals: String?
}
```

- [ ] **Step 5: Write `TripFacts`.** Create `Crewluv/Services/TripMap/Facts/TripFacts.swift`:

```swift
//
//  TripFacts.swift
//  CrewLuve
//
//  Everything the facts say about a trip at a moment (Stage 2 spec §3.1, §4.4, §5): the headline, the rows
//  (TripFacts+Rows.swift), the trip so far and the recap's numbers. Each answer is a lookup in the flights' stories and
//  sun events, so replay and scrubbing need nothing extra (§4.10).
//

import Foundation

nonisolated struct TripFacts {
    let tripMap: TripMap
    let geography: Geography?
    let comparisons: ComparisonPicker?
    /// By leg id, for the flights whose story is ready.
    let stories: [String: LegStory]
    /// Each flight's cockpit sunrises and sunsets, by leg id.
    let sunEvents: [String: [SkyFacts.SunEvent]]
    /// Landing-hour forecasts, by leg id.
    var forecasts: [String: LandingForecast] = [:]
    /// The status's trip day, for "Day 2 of 4".
    var dayNumber: Int?
    var totalDays: Int?
    var calendar: Calendar = .current
    var locale: Locale = .current

    /// Weather shows for a flight landing within this of now (§7.2).
    static let weatherHorizon: TimeInterval = 48 * 3600
    /// A cockpit sunrise or sunset this close leads the headline.
    static let sunHeadlineWindow: TimeInterval = 30 * 60

    // MARK: - Milestones

    func milestones(on leg: MapLeg) -> [Milestone] {
        stories[leg.id].map { Milestone.milestones(on: leg, story: $0) } ?? []
    }

    // MARK: - The headline (§4.4)

    /// In flight: a milestone from the last 5 minutes, else a cockpit sunrise or sunset in the next 30, else the place
    /// below, else the landing countdown. Nil on the ground and on a drive, where Stage 1's words stay.
    func headline(at date: Date) -> String? {
        guard let leg = tripMap.legInMotion(at: date), leg.kind == .flight else { return nil }
        let recent = milestones(on: leg).last { $0.time <= date && date.timeIntervalSince($0.time) < Milestone.headlineDuration }
        if let recent {
            return FactsWording.headline(for: recent.kind)
        }
        let soon = sunEvents[leg.id]?.first { $0.time > date && $0.time.timeIntervalSince(date) <= Self.sunHeadlineWindow }
        if let soon {
            return FactsWording.cockpitCountdown(soon, now: date)
        }
        return belowText(on: leg, at: date) ?? TripMapWording.landingCountdown(for: leg, now: date)
    }

    /// The sheet's first line: the headline in flight, "Home from 4 days away" after a recap's trip, else Stage 1's.
    func sheetHeadline(at date: Date) -> String {
        if let headline = headline(at: date) { return headline }
        if isRecapOver(at: date) { return FactsWording.recapChip(days: tripMap.dayCount(in: calendar)) }
        return TripMapWording.panelHeadline(for: tripMap, at: date, calendar: calendar, locale: locale)
    }

    /// "Over Kansas", "Over Québec, near Montréal", from the flight's story.
    func belowText(on leg: MapLeg, at date: Date) -> String? {
        guard let place = stories[leg.id]?.place(atFraction: leg.progress(at: date)) else { return nil }
        return FactsWording.below(place, near: geography?.city(near: leg.position(at: date)))
    }

    // MARK: - Weather (§7.3)

    /// The forecast for `leg` when it lands between the real `now` and 48 hours on, whatever moment the timeline shows.
    func forecast(for leg: MapLeg, now: Date) -> LandingForecast? {
        guard leg.end > now, leg.end.timeIntervalSince(now) <= Self.weatherHorizon else { return nil }
        return forecasts[leg.id]
    }

    // MARK: - The tall stop (§5.2, §5.5)

    func tripSoFar(at date: Date) -> TripSoFar {
        let started = tripMap.legs.filter { $0.kind == .flight && $0.start <= date }.reversed()
        let flights = started.compactMap { leg -> TripSoFar.Flight? in
            let lines = milestones(on: leg).filter { $0.time <= date }.map { FactsWording.listLine(for: $0, calendar: calendar, locale: locale) }
            return lines.isEmpty ? nil : TripSoFar.Flight(id: leg.id, title: FactsWording.flightTitle(leg), milestones: lines)
        }
        if isRecapOver(at: date) {
            let totals = TripTotals.whole(tripMap, sunEvents: sunEvents)
            return TripSoFar(flights: flights, totalsTitle: "Trip recap",
                             totals: FactsWording.soFar(totals, dayNumber: nil, totalDays: nil, locale: locale))
        }
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents)
        return TripSoFar(flights: flights, totalsTitle: "Trip so far",
                         totals: FactsWording.soFar(totals, dayNumber: dayNumber, totalDays: totalDays, locale: locale))
    }

    /// True once a recap's trip is over at `date`.
    func isRecapOver(at date: Date) -> Bool {
        tripMap.mode == .recap && date >= tripMap.span.end
    }

    // MARK: - The card (§6.4, §6.5)

    /// The card as one sentence for VoiceOver.
    func cardSummary(now: Date, pilotName: String) -> String {
        switch tripMap.mode {
        case .inFlight:
            if let leg = tripMap.currentLeg {
                let lead = leg.flightNumber.map { "\($0) to" } ?? "Flying to"
                let over = stories[leg.id]?.place(atFraction: leg.progress(at: now)).map { ", over \($0.name)" } ?? ""
                let landing = TripMapWording.clockTime(leg.end, in: calendar.timeZone, locale: locale)
                return "\(lead) \(leg.destination.name)\(over). Lands at \(landing) your time. Estimated from the schedule."
            }
        case .recap:
            return FactsWording.recapSummary(days: tripMap.dayCount(in: calendar), totals: TripTotals.whole(tripMap, sunEvents: sunEvents),
                                             longest: TripTotals.longestFlight(of: tripMap.legs), locale: locale)
        case .onTrip, .nextTrip:
            break
        }
        return TripMapWording.cardSummary(for: tripMap, now: now, pilotName: pilotName, calendar: calendar, locale: locale)
    }

    var recapTiles: [RecapTile] {
        FactsWording.recapTiles(TripTotals.whole(tripMap, sunEvents: sunEvents), locale: locale)
    }

    /// "Longest: Dubai → Louisville, 7,382 mi".
    var recapLongestLine: String? {
        TripTotals.longestFlight(of: tripMap.legs).map { "Longest: \(FactsWording.longest($0, locale: locale))" }
    }
}
```

- [ ] **Step 6: Run the tests, expecting them to pass.** Todd runs `TripFactsTests`.

- [ ] **Step 7: Ask to commit.** Suggested message: `feat(crewluv): TripFacts: the headline, the trip so far and the card's words (Stage 2 spec §4.4, §5.2, §6)`.

---

### Task 14: `TripFacts`: the rows

The sheet's rows at any moment: in flight, on a layover, at home before a trip and after a recap's trip (Stage 2 spec §5).

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`
- Test: `CrewluvTests/TripFactsRowsTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/TripFactsRowsTests.swift`:

```swift
//
//  TripFactsRowsTests.swift
//  CrewluvTests
//
//  The sheet's rows (Stage 2 spec §5), in US English for a family in Louisville.
//

import XCTest
@testable import Crewluv

final class TripFactsRowsTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }
    private let start = TripMapTestLegs.tripStart

    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func facts(_ map: TripMap, forecasts: [String: LandingForecast] = [:]) throws -> TripFacts {
        let home = map.home
        let stories = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, LegStory(leg: $0, geography: FactsTestData.equator, home: home)) })
        let sunEvents = Dictionary(uniqueKeysWithValues: map.legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        return TripFacts(tripMap: map, geography: FactsTestData.equator, comparisons: try FactsTestData.appComparisons(),
                         stories: stories, sunEvents: sunEvents, forecasts: forecasts, calendar: calendar, locale: locale)
    }

    private func equatorMap() -> TripMap {
        let leg = FactsTestData.equatorFlight(from: 0, to: 20)
        return TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: FactsTestData.mark("HOME", latitude: 0.5, longitude: 14),
                       span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
    }

    private func row(_ kind: FactRow.Kind, in rows: [FactRow]) throws -> FactRow {
        try XCTUnwrap(rows.first { $0.kind == kind }, "no \(kind) row")
    }

    // MARK: - In flight (§5.1)

    func test_rows_inFlight_belowDistanceAndLanding() throws {
        let rows = try facts(equatorMap()).rows(at: FactsTestData.date("2026-03-20T11:10:00Z"), now: FactsTestData.date("2026-03-20T11:10:00Z"))
        XCTAssertEqual(rows.map(\.kind), [.below, .distance, .headed], "no sky row: midday, eastbound, and no moon")

        let below = try row(.below, in: rows)
        XCTAssertEqual(below.title, "Over Bravo, near Testville")
        XCTAssertEqual(plain(below.detail), "Passes 35 mi from home at 8:21 AM")

        let distance = try row(.distance, in: rows)
        XCTAssertEqual(distance.title, "422 mi flown · 960 to go")
        XCTAssertEqual(plain(distance.detail), "Halfway at 7:45 AM · Averaging about 460 mph · like driving the Alaska Highway")

        let headed = try row(.headed, in: rows)
        XCTAssertEqual(plain(headed.title), "Lands E20 9:22 AM")
        XCTAssertNil(headed.detail)
    }

    func test_rows_inFlight_weatherOnlyForALandingStillAhead() throws {
        let withWeather = try facts(equatorMap(), forecasts: ["eq": LandingForecast(temperature: "81°F", condition: "clear")])
        let shown = FactsTestData.date("2026-03-20T11:10:00Z")

        let live = try row(.headed, in: withWeather.rows(at: shown, now: shown))
        XCTAssertEqual(live.detail, "81°F and clear on landing")
        XCTAssertTrue(live.hasWeather)

        let replayed = try row(.headed, in: withWeather.rows(at: shown, now: FactsTestData.date("2026-03-20T14:00:00Z")))
        XCTAssertNil(replayed.detail, "the landing has happened in real time")
        XCTAssertFalse(replayed.hasWeather)
    }

    func test_rows_inFlight_theSkyBeforeACockpitSunset() throws {
        let departure = FactsTestData.date("2026-11-13T18:00:00Z")
        let leg = MapLeg(id: "evening", kind: .flight,
                         origin: AirportMark(code: "SDF", city: "Louisville", coordinate: TripMapTestLegs.airports["SDF"]!, timeZone: nil),
                         destination: AirportMark(code: "CGN", city: "Cologne", coordinate: TripMapTestLegs.airports["CGN"]!, timeZone: nil),
                         start: departure, end: departure.addingTimeInterval(8 * 3600), flightNumber: "UPS207")
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: nil, span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        let at = FactsTestData.date("2026-11-13T20:30:00Z")
        let sky = try row(.sky, in: try facts(map).rows(at: at, now: at))
        XCTAssertEqual(sky.title, "Flying into the night")
        XCTAssertEqual(sky.detail, "Sunset in 17 min, about 21 min after the people below")
        XCTAssertEqual(sky.symbolName, "sunset.fill")
    }

    // MARK: - On a layover (§5.3)

    func test_rows_onALayoverInCologne() throws {
        let at = start.addingTimeInterval(12 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: at))
        let rows = try facts(map).rows(at: at, now: at)
        XCTAssertEqual(rows.map(\.kind), [.whereTheyAre, .nextFlight, .tripSoFar])

        let here = try row(.whereTheyAre, in: rows)
        XCTAssertEqual(here.title, "In Cologne")
        XCTAssertEqual(plain(here.detail), "6 hours ahead of you · sunrise at 7:45 AM there")

        let next = try row(.nextFlight, in: rows)
        XCTAssertEqual(plain(next.title), "Next: Dubai, tomorrow 3:00 PM")
        XCTAssertEqual(plain(next.detail), "3,086 mi, like driving coast to coast · lands 6:00 AM there")

        XCTAssertEqual(try row(.tripSoFar, in: rows).detail, "1 city · 4,351 mi · 6 time zones · 1 sunset from the cockpit")
    }

    // MARK: - At home before a trip (§5.4)

    func test_rows_atHomeTheDayBefore() throws {
        let at = start.addingTimeInterval(-24 * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), isNextTrip: true, at: at))
        let rows = try facts(map).rows(at: at, now: at)
        XCTAssertEqual(rows.map(\.kind), [.leaves, .tripAhead, .onTheWay])

        let leaves = try row(.leaves, in: rows)
        XCTAssertEqual(plain(leaves.title), "Leaves tomorrow 7:00 AM")
        XCTAssertEqual(leaves.detail, "UPS207 to Cologne")

        XCTAssertEqual(try row(.tripAhead, in: rows).detail, "4 days · Cologne, Dubai · 14,819 mi · like digging straight through the Earth twice")
        XCTAssertEqual(try row(.onTheWay, in: rows).detail, "18 time zones · about 1 sunset from the cockpit")
    }

    // MARK: - The recap (§5.5)

    func test_rows_afterARecapsTrip() throws {
        let map = try XCTUnwrap(TripMap.make(tripLegs: TripMapTestLegs.europeTrip(), isNextTrip: false, isRecap: true, homeAirportCode: "SDF",
                                             legacyDelayMinutes: nil, at: start, coordinate: TripMapTestLegs.coordinate))
        let at = map.span.end.addingTimeInterval(3600)
        let rows = try facts(map).rows(at: at, now: at)
        XCTAssertEqual(rows.map(\.kind), [.theTrip, .onTheWay, .longestFlight])
        XCTAssertEqual(try row(.theTrip, in: rows).detail, "4 days · Cologne, Dubai · 14,819 mi · like digging straight through the Earth twice")
        XCTAssertEqual(try row(.onTheWay, in: rows).detail, "18 time zones · 1 sunset from the cockpit")
        XCTAssertEqual(try row(.longestFlight, in: rows).detail, "Dubai → Louisville, 7,382 mi")
    }

    // MARK: - On a drive

    func test_rows_onADriveWithNothingFlown_isEmpty() throws {
        let drive = MapLeg(id: "d", kind: .drive,
                           origin: FactsTestData.mark("LEX", latitude: 38.04, longitude: -84.61, city: "Lexington"),
                           destination: FactsTestData.mark("SDF", latitude: 38.17, longitude: -85.74, city: "Louisville"),
                           start: start, end: start.addingTimeInterval(3600), flightNumber: nil)
        let map = TripMap(mode: .onTrip, legs: [drive], home: nil, span: DateInterval(start: drive.start, end: drive.end), tripDays: nil)
        let at = start.addingTimeInterval(1800)
        XCTAssertEqual(try facts(map).rows(at: at, now: at), [])
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `TripFactsRowsTests`.

- [ ] **Step 3: Write the rows.** Create `Crewluv/Services/TripMap/Facts/TripFacts+Rows.swift`:

```swift
//
//  TripFacts+Rows.swift
//  CrewLuve
//
//  The facts sheet's rows (Stage 2 spec §5): in flight, "now, then where to"; on a layover, where they are, the next
//  flight and the trip so far; at home, the trip ahead and its forecast; after a recap's trip, the trip. A row with
//  nothing to say is left out.
//

import Foundation

nonisolated extension TripFacts {

    /// The rows at `date` on the timeline, with `now` the real time (for weather).
    func rows(at date: Date, now: Date) -> [FactRow] {
        if let leg = tripMap.legInMotion(at: date) {
            return leg.kind == .flight ? flightRows(on: leg, at: date, now: now) : [tripSoFarRow(at: date)].compactMap { $0 }
        }
        if isRecapOver(at: date) { return recapRows() }
        if tripMap.mode == .nextTrip, date < tripMap.span.start { return homeRows(at: date, now: now) }
        return layoverRows(at: date, now: now)
    }

    // MARK: - In flight (§5.1)

    private func flightRows(on leg: MapLeg, at date: Date, now: Date) -> [FactRow] {
        [belowRow(on: leg, at: date), skyRow(on: leg, at: date), distanceRow(on: leg, at: date), headedRow(on: leg, now: now)]
            .compactMap { $0 }
    }

    private func belowRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let closest = stories[leg.id]?.closestToHome.flatMap { closest in
            leg.time(atFraction: closest.fraction).map {
                FactsWording.closestToHome(miles: Milestone.roundedMiles(closest.meters), at: $0, now: date, calendar: calendar, locale: locale)
            }
        }
        if let place = belowText(on: leg, at: date) {
            return FactRow(.below, symbol: "mappin.and.ellipse", title: place, details: [closest])
        }
        return closest.map { FactRow(.below, symbol: "mappin.and.ellipse", title: $0) }
    }

    private func skyRow(on leg: MapLeg, at date: Date) -> FactRow? {
        let next = sunEvents[leg.id]?.first { $0.time > date }
        let parts = [
            next.map { FactsWording.flyingInto($0.kind) },
            next.map { FactsWording.cockpitEvent($0, now: date, calendar: calendar, locale: locale) },
            SkyFacts.chase(on: leg, at: date).map(FactsWording.chase),
            SkyFacts.moon(on: leg, at: date).map(FactsWording.moon),
        ].compactMap { $0 }
        guard let title = parts.first else { return nil }
        let symbol: String
        if let next {
            symbol = next.kind == .sunset ? "sunset.fill" : "sunrise.fill"
        } else {
            symbol = SkyFacts.sunAltitude(on: leg, at: date) > SkyFacts.cockpitHorizon ? "sun.max.fill" : "moon.stars.fill"
        }
        return FactRow(.sky, symbol: symbol, title: title, details: Array(parts.dropFirst()))
    }

    private func distanceRow(on leg: MapLeg, at date: Date) -> FactRow {
        let totalMiles = leg.distance / GreatCircle.metersPerMile
        let flown = Int((totalMiles * leg.progress(at: date)).rounded())
        let halfway = leg.time(atFraction: 0.5).flatMap { $0 > date ? FactsWording.halfway(at: $0, calendar: calendar, locale: locale) : nil }
        let speed = FlightProgress.airborneWindow(departure: leg.start, arrival: leg.end)
            .map { FactsWording.averageSpeed(milesPerHour: totalMiles / ($0.duration / 3600)) }
        return FactRow(.distance, symbol: "point.topleft.down.to.point.bottomright.curvepath",
                       title: FactsWording.distance(flownMiles: flown, toGoMiles: Int(totalMiles.rounded()) - flown, locale: locale),
                       details: [halfway, speed, comparisons?.phrase(forMiles: totalMiles).map(FactsWording.midLine)])
    }

    private func headedRow(on leg: MapLeg, now: Date) -> FactRow {
        let landingWeather = forecast(for: leg, now: now)
        return FactRow(.headed, symbol: "airplane.arrival",
                       title: TripMapWording.landingLine(for: leg, calendar: calendar, locale: locale),
                       details: [landingWeather.map(FactsWording.weather),
                                 leg.destination.timeZone.flatMap { FactsWording.timeDifference(from: $0, to: calendar.timeZone, at: leg.end) }],
                       hasWeather: landingWeather != nil)
    }

    // MARK: - On a layover (§5.3)

    private func layoverRows(at date: Date, now: Date) -> [FactRow] {
        [whereTheyAreRow(at: date), nextFlightRow(at: date, now: now), tripSoFarRow(at: date)].compactMap { $0 }
    }

    private func whereTheyAreRow(at date: Date) -> FactRow? {
        guard let place = tripMap.pilotLocation(at: date) else { return nil }
        let difference = place.timeZone.flatMap { FactsWording.timeDifference(from: $0, to: calendar.timeZone, at: date) }
        let sun = place.timeZone.flatMap { zone in
            SkyFacts.nextGroundSunEvent(at: place.coordinate, after: date).map {
                FactsWording.groundSun($0.kind, at: $0.time, in: zone, locale: locale)
            }
        }
        return FactRow(.whereTheyAre, symbol: "mappin.and.ellipse", title: "In \(place.name)", details: [difference, sun])
    }

    private func nextFlightRow(at date: Date, now: Date) -> FactRow? {
        guard let next = tripMap.nextFlight(after: date) else { return nil }
        let miles = next.distance / GreatCircle.metersPerMile
        let distance = [TripMapWording.milesText(Int(miles.rounded()), locale: locale),
                        comparisons?.phrase(forMiles: miles).map(FactsWording.midLine)]
            .compactMap { $0 }
            .joined(separator: ", ")
        let landingWeather = forecast(for: next, now: now)
        return FactRow(.nextFlight, symbol: "airplane.departure",
                       title: TripMapWording.nextDepartureChip(for: next, now: date, calendar: calendar, locale: locale),
                       details: [distance, FactsWording.lands(next, calendar: calendar, locale: locale), landingWeather.map(FactsWording.weather)],
                       hasWeather: landingWeather != nil)
    }

    private func tripSoFarRow(at date: Date) -> FactRow? {
        let totals = TripTotals.soFar(on: tripMap, at: date, sunEvents: sunEvents)
        guard let line = FactsWording.soFar(totals, dayNumber: dayNumber, totalDays: totalDays, locale: locale) else { return nil }
        return FactRow(.tripSoFar, symbol: "chart.bar.fill", title: "Trip so far", details: [line])
    }

    // MARK: - At home before a trip (§5.4)

    private func homeRows(at date: Date, now: Date) -> [FactRow] {
        let whole = TripTotals.whole(tripMap, sunEvents: sunEvents)
        return [leavesRow(at: date, now: now), tripRow(.tripAhead, title: "The trip ahead", totals: whole),
                onTheWayRow(whole, isForecast: true)].compactMap { $0 }
    }

    private func leavesRow(at date: Date, now: Date) -> FactRow? {
        guard let first = tripMap.nextFlight(after: date) else { return nil }
        let day = TripMapWording.dayPhrase(for: first.start, now: date, calendar: calendar, locale: locale)
        let clock = TripMapWording.clockTime(first.start, in: calendar.timeZone, locale: locale)
        let flight = first.flightNumber.map { "\($0) to \(first.destination.name)" } ?? "Flying to \(first.destination.name)"
        let landingWeather = forecast(for: first, now: now)
        return FactRow(.leaves, symbol: "airplane.departure", title: "Leaves \(day) \(clock)",
                       details: [flight, landingWeather.map(FactsWording.weather)], hasWeather: landingWeather != nil)
    }

    // MARK: - After a recap's trip (§5.5)

    private func recapRows() -> [FactRow] {
        let whole = TripTotals.whole(tripMap, sunEvents: sunEvents)
        let longest = TripTotals.longestFlight(of: tripMap.legs).map {
            FactRow(.longestFlight, symbol: "arrow.left.and.right", title: "Longest flight", details: [FactsWording.longest($0, locale: locale)])
        }
        return [tripRow(.theTrip, title: "The trip", totals: whole), onTheWayRow(whole, isForecast: false), longest].compactMap { $0 }
    }

    // MARK: - Shared

    /// "4 days · Cologne, Dubai · 9,800 mi · like driving the Alaska Highway 7 times".
    private func tripRow(_ kind: FactRow.Kind, title: String, totals: TripTotals) -> FactRow {
        let cities = TripMapWording.destinationNames(of: tripMap.legs, leavingOut: Set([tripMap.home?.code].compactMap { $0 }))
        return FactRow(kind, symbol: "globe.americas.fill", title: title, details: [
            FactsWording.days(tripMap.dayCount(in: calendar)),
            cities.isEmpty ? nil : cities.joined(separator: ", "),
            totals.miles > 0 ? TripMapWording.milesText(totals.miles, locale: locale) : nil,
            comparisons?.phrase(forMiles: Double(totals.miles)).map(FactsWording.midLine),
        ])
    }

    private func onTheWayRow(_ totals: TripTotals, isForecast: Bool) -> FactRow? {
        FactsWording.onTheWay(totals, isForecast: isForecast, locale: locale).map {
            FactRow(.onTheWay, symbol: "chart.bar.fill", title: "On the way", details: [$0])
        }
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `TripFactsRowsTests`.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): the facts sheet's rows in flight, on a layover, at home and in the recap (Stage 2 spec §5)`.

---
### Task 15: The shared facts cases

`facts-cases.json` holds the app and the website to the same answers (Stage 2 spec §12.1). The website's Stage 2B plan copies it to `tests/fixtures/trip-map/`.

The cases' answers:
- **Comparisons, totals and moon phases** are worked out by hand from the rules.
- **Story milestones** are along the equator in made-up places, where a fraction of the way is a fraction of the longitude.
- **Sun events and ground sunrises** came from a JavaScript copy of `SolarPosition`, `GreatCircle` and `FlightProgress`.
- **Places and cities** are in the real `geography.json`, and they double as a check on Task 2's script.

Times match to within a minute.

**Files:**
- Create: `CrewluvTests/Fixtures/TripMap/facts-cases.json`
- Modify: `CrewluvTests/Helpers/TripMapFixtures.swift`
- Test: `CrewluvTests/FactsCasesTests.swift`

- [ ] **Step 1: Write the cases.** Create `CrewluvTests/Fixtures/TripMap/facts-cases.json`:

```json
{
  "about": "The trip map's facts (moving map Stage 2 spec §12.1). The app runs every case in FactsCasesTests; the website keeps a copy in tests/fixtures/trip-map/. Change both copies together. Times match to within 60 seconds; words are en_US in America/New_York.",
  "constants": {
    "cockpitHorizonDegrees": -3.8627, "milestoneMinutes": 5, "sunHeadlineMinutes": 30, "sampleMiles": 10,
    "holdMiles": 25, "homeRadiusMiles": 100, "cityRadiusMiles": 40, "weatherHours": 48
  },
  "comparisons": [
    {"miles": 10, "phrase": null},
    {"miles": 20, "phrase": "Like running a marathon"},
    {"miles": 200, "phrase": "Like sailing the Panama Canal 4 times"},
    {"miles": 600, "phrase": "Like rafting the Grand Canyon twice"},
    {"miles": 1381.9, "phrase": "Like driving the Alaska Highway"},
    {"miles": 2980, "phrase": "Like driving coast to coast"},
    {"miles": 4100, "phrase": "Like sailing the length of the Nile"},
    {"miles": 9800, "phrase": "Like driving the Alaska Highway 7 times"},
    {"miles": 14819, "phrase": "Like digging straight through the Earth twice"},
    {"miles": 26000, "phrase": "Like going once around the Earth"},
    {"miles": 300000, "phrase": null}
  ],
  "places": [
    {"lat": 38.5, "lon": -98.5, "place": "Kansas", "kind": "state", "country": "the United States"},
    {"lat": 50.0, "lon": -85.0, "place": "Ontario", "kind": "province", "country": "Canada"},
    {"lat": 51.0, "lon": 10.0, "place": "Germany", "kind": "country", "country": "Germany"},
    {"lat": 52.2, "lon": 5.5, "place": "the Netherlands", "kind": "country", "country": "the Netherlands"},
    {"lat": 58.0, "lon": -54.0, "place": "the Labrador Sea", "kind": "water", "country": null},
    {"lat": 40.0, "lon": -40.0, "place": "the Atlantic", "kind": "water", "country": null},
    {"lat": 30.0, "lon": -150.0, "place": "the Pacific", "kind": "water", "country": null},
    {"lat": 45.5, "lon": -4.5, "place": "the Bay of Biscay", "kind": "water", "country": null}
  ],
  "cities": [
    {"lat": 45.55, "lon": -73.70, "city": "Montréal"},
    {"lat": 40.70, "lon": -74.05, "city": "New York"},
    {"lat": 45.0, "lon": -30.0, "city": null}
  ],
  "testGeography": {
    "areas": [
      {"name": "Wedge", "kind": "country", "box": [9, -1, 9.3, 1], "rings": [[9, -1, 9.3, -1, 9.3, 1, 9, 1]]},
      {"name": "Alpha", "kind": "country", "box": [-1, -1, 5, 1], "rings": [[-1, -1, 5, -1, 5, 1, -1, 1]]},
      {"name": "Bravo", "kind": "country", "box": [5, -1, 12, 1], "rings": [[5, -1, 12, -1, 12, 1, 5, 1]]},
      {"name": "North", "kind": "state", "country": "Delta", "box": [29, -1, 35.5, 1], "rings": [[29, -1, 35.5, -1, 35.5, 1, 29, 1]]},
      {"name": "South", "kind": "state", "country": "Delta", "box": [35.5, -1, 37, 1], "rings": [[35.5, -1, 37, -1, 37, 1, 35.5, 1]]},
      {"name": "Delta", "kind": "country", "box": [29, -1, 37, 1], "rings": [[29, -1, 37, -1, 37, 1, 29, 1]]},
      {"name": "Echo", "kind": "country", "box": [37, -1, 41, 1], "rings": [[37, -1, 41, -1, 41, 1, 37, 1]]},
      {"name": "Foxtrot", "kind": "country", "box": [56, -1, 61, 1], "rings": [[56, -1, 61, -1, 61, 1, 56, 1]]},
      {"name": "the Test Sea", "kind": "water", "box": [12, -1, 53, 1], "rings": [[12, -1, 21, -1, 21, 1, 12, 1], [49, -1, 53, -1, 53, 1, 49, 1]]},
      {"name": "the Other Sea", "kind": "water", "box": [53, -1, 56, 1], "rings": [[53, -1, 56, -1, 56, 1, 53, 1]]}
    ],
    "cities": []
  },
  "stories": [
    {"name": "equator", "from": [0, 0], "to": [0, 20], "departure": "2026-03-20T10:00:00Z", "arrival": "2026-03-20T13:22:00Z", "home": [0.5, 14],
     "milestones": [
       {"kind": "crossedInto", "name": "Bravo", "time": "2026-03-20T11:00:00Z"},
       {"kind": "halfway", "time": "2026-03-20T11:45:00Z"},
       {"kind": "outOver", "name": "the Test Sea", "time": "2026-03-20T12:03:00Z"},
       {"kind": "closestToHome", "miles": 35, "time": "2026-03-20T12:21:00Z"}
     ]},
    {"name": "states", "from": [0, 30], "to": [0, 40], "departure": "2026-03-20T14:00:00Z", "arrival": "2026-03-20T17:22:00Z", "home": null,
     "milestones": [
       {"kind": "halfway", "time": "2026-03-20T15:45:00Z"},
       {"kind": "crossedInto", "name": "South", "time": "2026-03-20T15:54:00Z"},
       {"kind": "crossedInto", "name": "Echo", "time": "2026-03-20T16:21:00Z"}
     ]},
    {"name": "seas", "from": [0, 50], "to": [0, 60], "departure": "2026-03-20T18:00:00Z", "arrival": "2026-03-20T21:22:00Z", "home": null,
     "milestones": [
       {"kind": "halfway", "time": "2026-03-20T19:45:00Z"},
       {"kind": "crossedInto", "name": "Foxtrot", "time": "2026-03-20T20:03:00Z"}
     ]},
    {"name": "nowhere", "from": [10, 0], "to": [10, 20], "departure": "2026-03-20T10:00:00Z", "arrival": "2026-03-20T13:22:00Z", "home": null,
     "milestones": [
       {"kind": "halfway", "time": "2026-03-20T11:45:00Z"}
     ]},
    {"name": "sunrise", "from": [38.1744, -85.7360], "to": [50.8659, 7.1427], "departure": "2026-11-13T23:00:00Z", "arrival": "2026-11-14T07:00:00Z", "home": null,
     "milestones": [
       {"kind": "halfway", "time": "2026-11-14T03:04:00Z"}
     ]}
  ],
  "headlines": [
    {"story": "equator", "at": "2026-03-20T11:02:00Z", "text": "Just crossed into Bravo"},
    {"story": "equator", "at": "2026-03-20T11:10:00Z", "text": "Over Bravo"},
    {"story": "equator", "at": "2026-03-20T11:46:00Z", "text": "Halfway!"},
    {"story": "equator", "at": "2026-03-20T12:05:00Z", "text": "Out over the Test Sea"},
    {"story": "equator", "at": "2026-03-20T12:22:00Z", "text": "Closest to home: 35 mi, wave!"},
    {"story": "equator", "at": "2026-03-20T12:40:00Z", "text": "Over the Test Sea"},
    {"story": "nowhere", "at": "2026-03-20T12:10:00Z", "text": "Landing in 1 h 12 min"},
    {"story": "sunrise", "at": "2026-11-14T06:17:43Z", "text": "Sunrise from the cockpit in 21 min"}
  ],
  "sunEvents": [
    {"name": "Louisville to Cologne, evening", "from": [38.1744, -85.7360], "to": [50.8659, 7.1427],
     "departure": "2026-11-13T18:00:00Z", "arrival": "2026-11-14T02:00:00Z",
     "events": [{"kind": "sunset", "time": "2026-11-13T20:46:17Z", "peopleBelowMinutes": 21.4}]},
    {"name": "Louisville to Cologne, overnight", "from": [38.1744, -85.7360], "to": [50.8659, 7.1427],
     "departure": "2026-11-13T23:00:00Z", "arrival": "2026-11-14T07:00:00Z",
     "events": [{"kind": "sunrise", "time": "2026-11-14T06:38:13Z", "peopleBelowMinutes": 22.0}]},
    {"name": "Cologne to Louisville, all daylight", "from": [50.8659, 7.1427], "to": [38.1744, -85.7360],
     "departure": "2026-11-14T13:00:00Z", "arrival": "2026-11-14T22:00:00Z",
     "events": []}
  ],
  "moonPhases": [
    {"at": "2026-11-09T21:58:00Z", "phase": "new"},
    {"at": "2026-11-13T14:33:00Z", "phase": "waxingCrescent"},
    {"at": "2026-11-17T07:09:00Z", "phase": "firstQuarter"},
    {"at": "2026-11-20T23:44:00Z", "phase": "waxingGibbous"},
    {"at": "2026-11-24T16:20:00Z", "phase": "full"},
    {"at": "2026-11-28T08:55:00Z", "phase": "waningGibbous"},
    {"at": "2026-12-02T01:31:00Z", "phase": "lastQuarter"},
    {"at": "2026-12-05T18:06:00Z", "phase": "waningCrescent"}
  ],
  "moonUp": [
    {"lat": 50.87, "lon": 7.14, "at": "2026-11-20T21:00:00Z", "isUp": true},
    {"lat": 51.79, "lon": 4.25, "at": "2026-11-14T06:38:00Z", "isUp": false}
  ],
  "groundSun": [
    {"lat": 50.8659, "lon": 7.1427, "after": "2026-11-13T20:14:00Z", "kind": "sunrise", "time": "2026-11-14T06:45:24Z"},
    {"lat": 50.8659, "lon": 7.1427, "after": "2026-11-14T12:00:00Z", "kind": "sunset", "time": "2026-11-14T15:45:47Z"}
  ],
  "totals": {
    "airports": {"SDF": [38.1744, -85.7360], "CGN": [50.8659, 7.1427], "DXB": [25.2532, 55.3657]},
    "home": "SDF",
    "legs": [
      {"id": "f1", "from": "SDF", "to": "CGN", "departure": "2026-11-13T12:00:00Z", "arrival": "2026-11-13T20:00:00Z", "fromZone": "America/New_York", "toZone": "Europe/Berlin"},
      {"id": "f2", "from": "CGN", "to": "DXB", "departure": "2026-11-14T20:00:00Z", "arrival": "2026-11-15T02:00:00Z", "fromZone": "Europe/Berlin", "toZone": "Asia/Dubai"},
      {"id": "f3", "from": "DXB", "to": "SDF", "departure": "2026-11-15T22:00:00Z", "arrival": "2026-11-16T12:00:00Z", "fromZone": "Asia/Dubai", "toZone": "America/New_York"}
    ],
    "cities": 2, "miles": 14819, "timeZones": 18, "cockpitSunsets": 1
  }
}
```

- [ ] **Step 2: Read the cases.** In `CrewluvTests/Helpers/TripMapFixtures.swift`, add inside `enum TripMapFixtures`, after `progressCases()`:

```swift
    // MARK: - The facts (Stage 2 spec §12.1)

    struct FactsCases: Decodable {
        struct Constants: Decodable {
            let cockpitHorizonDegrees: Double
            let milestoneMinutes: Double
            let sunHeadlineMinutes: Double
            let sampleMiles: Double
            let holdMiles: Double
            let homeRadiusMiles: Double
            let cityRadiusMiles: Double
            let weatherHours: Double
        }

        struct Comparison: Decodable {
            let miles: Double
            let phrase: String?
        }

        struct PlaceCase: Decodable {
            let lat: Double
            let lon: Double
            let place: String
            let kind: String
            let country: String?
        }

        struct CityCase: Decodable {
            let lat: Double
            let lon: Double
            let city: String?
        }

        struct Story: Decodable {
            struct Expected: Decodable {
                let kind: String
                let name: String?
                let miles: Int?
                let time: Date
            }

            let name: String
            /// Latitude, longitude.
            let from: [Double]
            let to: [Double]
            let departure: Date
            let arrival: Date
            let home: [Double]?
            let milestones: [Expected]
        }

        struct Headline: Decodable {
            let story: String
            let at: Date
            let text: String
        }

        struct SunCase: Decodable {
            struct Expected: Decodable {
                let kind: String
                let time: Date
                let peopleBelowMinutes: Double?
            }

            let name: String
            let from: [Double]
            let to: [Double]
            let departure: Date
            let arrival: Date
            let events: [Expected]
        }

        struct MoonPhaseCase: Decodable {
            let at: Date
            let phase: String
        }

        struct MoonUpCase: Decodable {
            let lat: Double
            let lon: Double
            let at: Date
            let isUp: Bool
        }

        struct GroundSunCase: Decodable {
            let lat: Double
            let lon: Double
            let after: Date
            let kind: String
            let time: Date
        }

        struct TotalsCase: Decodable {
            struct Leg: Decodable {
                let id: String
                let from: String
                let to: String
                let departure: Date
                let arrival: Date
                let fromZone: String
                let toZone: String
            }

            let airports: [String: [Double]]
            let home: String
            let legs: [Leg]
            let cities: Int
            let miles: Int
            let timeZones: Int
            let cockpitSunsets: Int
        }

        let constants: Constants
        let comparisons: [Comparison]
        let places: [PlaceCase]
        let cities: [CityCase]
        let testGeography: Geography
        let stories: [Story]
        let headlines: [Headline]
        let sunEvents: [SunCase]
        let moonPhases: [MoonPhaseCase]
        let moonUp: [MoonUpCase]
        let groundSun: [GroundSunCase]
        let totals: TotalsCase
    }

    static func factsCases() throws -> FactsCases {
        let data = try Data(contentsOf: folder.appending(path: "facts-cases.json"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FactsCases.self, from: data)
    }
```

- [ ] **Step 3: Write the tests.** Create `CrewluvTests/FactsCasesTests.swift`:

```swift
//
//  FactsCasesTests.swift
//  CrewluvTests
//
//  The shared facts cases (Stage 2 spec §12.1), which the website runs too.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FactsCasesTests: XCTestCase {

    private let locale = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    private func coordinate(_ pair: [Double]) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
    }

    private func flight(_ id: String, from: [Double], to: [Double], departure: Date, arrival: Date) -> MapLeg {
        MapLeg(id: id, kind: .flight,
               origin: AirportMark(code: "\(id)-from", city: nil, coordinate: coordinate(from), timeZone: nil),
               destination: AirportMark(code: "\(id)-to", city: nil, coordinate: coordinate(to), timeZone: nil),
               start: departure, end: arrival, flightNumber: nil)
    }

    private func facts(for story: TripMapFixtures.FactsCases.Story, in geography: Geography) -> TripFacts {
        let leg = flight(story.name, from: story.from, to: story.to, departure: story.departure, arrival: story.arrival)
        let home = story.home.map { AirportMark(code: "HOME", city: nil, coordinate: coordinate($0), timeZone: nil) }
        let map = TripMap(mode: .inFlight(legID: leg.id), legs: [leg], home: home,
                          span: DateInterval(start: leg.start, end: leg.end), tripDays: nil)
        return TripFacts(tripMap: map, geography: geography, comparisons: nil,
                         stories: [leg.id: LegStory(leg: leg, geography: geography, home: home)],
                         sunEvents: [leg.id: SkyFacts.sunEvents(on: leg)], calendar: calendar, locale: locale)
    }

    private func describe(_ kind: Milestone.Kind) -> (kind: String, name: String?, miles: Int?) {
        switch kind {
        case .crossedInto(let name): ("crossedInto", name, nil)
        case .outOver(let name): ("outOver", name, nil)
        case .halfway: ("halfway", nil, nil)
        case .closestToHome(let miles): ("closestToHome", nil, miles)
        }
    }

    private func kindName(_ kind: SkyFacts.SunEvent.Kind) -> String {
        kind == .sunrise ? "sunrise" : "sunset"
    }

    func test_constants_matchTheApp() throws {
        let constants = try TripMapFixtures.factsCases().constants
        let mile = GreatCircle.metersPerMile
        XCTAssertEqual(SkyFacts.cockpitHorizon, constants.cockpitHorizonDegrees, accuracy: 0.0001)
        XCTAssertEqual(Milestone.headlineDuration, constants.milestoneMinutes * 60)
        XCTAssertEqual(TripFacts.sunHeadlineWindow, constants.sunHeadlineMinutes * 60)
        XCTAssertEqual(LegStory.sampleSpacing, constants.sampleMiles * mile)
        XCTAssertEqual(LegStory.holdDistance, constants.holdMiles * mile)
        XCTAssertEqual(LegStory.homeRadius, constants.homeRadiusMiles * mile)
        XCTAssertEqual(Geography.cityRadius, constants.cityRadiusMiles * mile)
        XCTAssertEqual(TripFacts.weatherHorizon, constants.weatherHours * 3600)
    }

    func test_comparisons() throws {
        let picker = try FactsTestData.appComparisons()
        for comparison in try TripMapFixtures.factsCases().comparisons {
            XCTAssertEqual(picker.phrase(forMiles: comparison.miles), comparison.phrase, "\(comparison.miles) mi")
        }
    }

    func test_places_inTheAppsGeography() throws {
        let geography = try FactsTestData.appGeography()
        for expected in try TripMapFixtures.factsCases().places {
            let place = geography.place(at: CLLocationCoordinate2D(latitude: expected.lat, longitude: expected.lon))
            XCTAssertEqual(place?.name, expected.place)
            XCTAssertEqual(place?.kind.rawValue, expected.kind, expected.place)
            XCTAssertEqual(place?.country, expected.country, expected.place)
        }
    }

    func test_cities_inTheAppsGeography() throws {
        let geography = try FactsTestData.appGeography()
        for expected in try TripMapFixtures.factsCases().cities {
            XCTAssertEqual(geography.city(near: CLLocationCoordinate2D(latitude: expected.lat, longitude: expected.lon))?.name, expected.city,
                           "\(expected.lat), \(expected.lon)")
        }
    }

    func test_stories_milestones() throws {
        let cases = try TripMapFixtures.factsCases()
        for story in cases.stories {
            let storyFacts = facts(for: story, in: cases.testGeography)
            let found = storyFacts.milestones(on: storyFacts.tripMap.legs[0])
            XCTAssertEqual(found.count, story.milestones.count, story.name)
            for (milestone, expected) in zip(found, story.milestones) {
                let actual = describe(milestone.kind)
                XCTAssertEqual(actual.kind, expected.kind, story.name)
                XCTAssertEqual(actual.name, expected.name, story.name)
                XCTAssertEqual(actual.miles, expected.miles, story.name)
                XCTAssertEqual(milestone.time.timeIntervalSince1970, expected.time.timeIntervalSince1970, accuracy: 60, story.name)
            }
        }
    }

    func test_headlines() throws {
        let cases = try TripMapFixtures.factsCases()
        for headline in cases.headlines {
            let story = try XCTUnwrap(cases.stories.first { $0.name == headline.story })
            XCTAssertEqual(facts(for: story, in: cases.testGeography).headline(at: headline.at), headline.text, "\(headline.story) at \(headline.at)")
        }
    }

    func test_sunEvents() throws {
        for expected in try TripMapFixtures.factsCases().sunEvents {
            let events = SkyFacts.sunEvents(on: flight("sun", from: expected.from, to: expected.to, departure: expected.departure, arrival: expected.arrival))
            XCTAssertEqual(events.count, expected.events.count, expected.name)
            for (event, wanted) in zip(events, expected.events) {
                XCTAssertEqual(kindName(event.kind), wanted.kind, expected.name)
                XCTAssertEqual(event.time.timeIntervalSince1970, wanted.time.timeIntervalSince1970, accuracy: 60, expected.name)
                XCTAssertEqual((event.peopleBelowGap ?? 0) / 60, wanted.peopleBelowMinutes ?? 0, accuracy: 1, expected.name)
            }
        }
    }

    func test_moonPhases() throws {
        for expected in try TripMapFixtures.factsCases().moonPhases {
            XCTAssertEqual("\(MoonPosition.phase(at: expected.at))", expected.phase, "\(expected.at)")
        }
    }

    func test_moonUp() throws {
        for expected in try TripMapFixtures.factsCases().moonUp {
            XCTAssertEqual(MoonPosition.altitude(latitude: expected.lat, longitude: expected.lon, at: expected.at) > 0, expected.isUp, "\(expected.at)")
        }
    }

    func test_groundSun() throws {
        for expected in try TripMapFixtures.factsCases().groundSun {
            let event = try XCTUnwrap(SkyFacts.nextGroundSunEvent(at: CLLocationCoordinate2D(latitude: expected.lat, longitude: expected.lon), after: expected.after))
            XCTAssertEqual(kindName(event.kind), expected.kind)
            XCTAssertEqual(event.time.timeIntervalSince1970, expected.time.timeIntervalSince1970, accuracy: 60)
        }
    }

    func test_totals() throws {
        let expected = try TripMapFixtures.factsCases().totals
        func mark(_ code: String, zone: String? = nil) -> AirportMark {
            AirportMark(code: code, city: nil, coordinate: coordinate(expected.airports[code]!), timeZone: zone.flatMap(TimeZone.init(identifier:)))
        }
        let legs = expected.legs.map {
            MapLeg(id: $0.id, kind: .flight, origin: mark($0.from, zone: $0.fromZone), destination: mark($0.to, zone: $0.toZone),
                   start: $0.departure, end: $0.arrival, flightNumber: nil)
        }
        let map = TripMap(mode: .onTrip, legs: legs, home: mark(expected.home),
                          span: DateInterval(start: legs[0].start, end: legs[legs.count - 1].end), tripDays: nil)
        let sunEvents = Dictionary(uniqueKeysWithValues: legs.map { ($0.id, SkyFacts.sunEvents(on: $0)) })
        XCTAssertEqual(TripTotals.whole(map, sunEvents: sunEvents),
                       TripTotals(cities: expected.cities, miles: expected.miles, timeZones: expected.timeZones, cockpitSunsets: expected.cockpitSunsets))
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `FactsCasesTests`.
  - If a `places` or `cities` case fails, the generated file names that place differently. Tell Todd what it says, and change the case or the script's tables with him.
  - Don't widen a time tolerance to make a case pass.

- [ ] **Step 5: Ask to commit.** Suggested message: `test(crewluv): the shared facts cases, which the website runs too (Stage 2 spec §12.1)`.

**Batch C review:** dispatch `superpowers:code-reviewer` (sonnet) on Tasks 11–15, then Todd runs `FactsWordingTests`, `TripMapRecapTests`, `TripReplayClockTests`, `TripMapWordingTests`, `TripMapTests`, `TripMapStatusTests`, `TripFactsTests`, `TripFactsRowsTests` and `FactsCasesTests`.

---
### Task 16: `LegStoryStore`

Builds stories and sun events off the main actor and keeps them (Stage 2 spec §3.2, §3.3). The status screen owns one, so the card and the full-screen map read the same facts.

**Files:**
- Create: `Crewluv/Services/TripMap/Facts/LegStoryStore.swift`
- Test: `CrewluvTests/LegStoryStoreTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/LegStoryStoreTests.swift`:

```swift
//
//  LegStoryStoreTests.swift
//  CrewluvTests
//
//  Building and keeping the stories (Stage 2 spec §3.2), with the repository's data files.
//

import XCTest
@testable import Crewluv

@MainActor
final class LegStoryStoreTests: XCTestCase {

    private func makeStore() -> LegStoryStore {
        LegStoryStore(loadFiles: { (try? FactsTestData.appGeography(), try? FactsTestData.appComparisons()) })
    }

    private func europe(firstDelayMinutes: Int? = nil) throws -> TripMap {
        try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(firstDelayMinutes: firstDelayMinutes), at: TripMapTestLegs.tripStart))
    }

    func test_facts_beforePrepare_haveNoStoriesOrSunEvents() throws {
        let facts = makeStore().facts(for: try europe())
        XCTAssertTrue(facts.stories.isEmpty)
        XCTAssertTrue(facts.sunEvents.isEmpty)
        XCTAssertNil(facts.geography)
    }

    func test_prepare_buildsEveryFlight() async throws {
        let store = makeStore()
        let map = try europe()
        await store.prepare(map)
        let facts = store.facts(for: map)
        XCTAssertEqual(Set(facts.stories.keys), ["f1", "f2", "f3"])
        XCTAssertEqual(facts.sunEvents["f1"]?.count, 1, "the cockpit sunset over the Atlantic")
        XCTAssertNotNil(facts.geography)
        XCTAssertNotNil(facts.comparisons)
    }

    func test_prepare_aNewDelay_keepsTheRouteButRedoesTheSun() async throws {
        let store = makeStore()
        await store.prepare(try europe())
        let delayed = try europe(firstDelayMinutes: 90)

        let before = store.facts(for: delayed)
        XCTAssertNotNil(before.stories["f1"], "same route")
        XCTAssertNil(before.sunEvents["f1"], "new times")

        await store.prepare(delayed)
        XCTAssertNotNil(store.facts(for: delayed).sunEvents["f1"])
    }

    func test_facts_passTheForecastsAndDay() throws {
        let forecast = LandingForecast(temperature: "48°F", condition: "rain")
        let facts = makeStore().facts(for: try europe(), forecasts: ["f1": forecast], dayNumber: 1, totalDays: 4)
        XCTAssertEqual(facts.forecasts["f1"], forecast)
        XCTAssertEqual(facts.dayNumber, 1)
        XCTAssertEqual(facts.totalDays, 4)
    }

    func test_routeKey_namesHomeOnlyWhenTheFlightPassesIt() throws {
        let map = try europe()
        XCTAssertEqual(LegStoryStore.routeKey(for: map.legs[0], home: map.home), "SDF-CGN")
        XCTAssertEqual(LegStoryStore.routeKey(for: map.legs[1], home: map.home), "CGN-DXB|SDF")
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `LegStoryStoreTests`.

- [ ] **Step 3: Write `LegStoryStore`.** Create `Crewluv/Services/TripMap/Facts/LegStoryStore.swift`:

```swift
//
//  LegStoryStore.swift
//  CrewLuve
//
//  Builds each flight's story and sun events off the main actor, and keeps them (Stage 2 spec §3.2). The status
//  screen owns one and hands it to the card and the full-screen map, so both read the same facts. Stories are kept
//  by route, since the screen rebuilds its TripMap on every render; sun events by flight and its delay-shifted times.
//

import Foundation
import Observation

@Observable
@MainActor
final class LegStoryStore {

    typealias FileLoader = @Sendable () -> (geography: Geography?, comparisons: ComparisonPicker?)

    private let loadFiles: FileLoader
    private var hasLoadedFiles = false
    private var geography: Geography?
    private var comparisons: ComparisonPicker?
    private var storiesByRoute: [String: LegStory] = [:]
    private var sunEventsByLeg: [String: [SkyFacts.SunEvent]] = [:]

    /// - Parameter loadFiles: reads geography.json and comparisons.json; the app's bundled copies unless a test says.
    init(loadFiles: @escaping FileLoader = { (Geography.loadBundled(), ComparisonPicker.loadBundled()) }) {
        self.loadFiles = loadFiles
    }

    /// Builds whatever `tripMap`'s flights are missing. Anything already built is kept, so calling it again is cheap.
    func prepare(_ tripMap: TripMap) async {
        if !hasLoadedFiles {
            let loadFiles = self.loadFiles
            let files = await Task.detached(priority: .utility) { loadFiles() }.value
            geography = files.geography
            comparisons = files.comparisons
            hasLoadedFiles = true
        }
        let home = tripMap.home
        let flights = tripMap.legs.filter { $0.kind == .flight }
        let routes = flights.filter { storiesByRoute[Self.routeKey(for: $0, home: home)] == nil }
        let timed = flights.filter { sunEventsByLeg[Self.timesKey(for: $0)] == nil }
        guard !routes.isEmpty || !timed.isEmpty else { return }
        let geography = self.geography
        let built = await Task.detached(priority: .utility) {
            (stories: routes.map { (Self.routeKey(for: $0, home: home), LegStory(leg: $0, geography: geography, home: home)) },
             sunEvents: timed.map { (Self.timesKey(for: $0), SkyFacts.sunEvents(on: $0)) })
        }.value
        for (key, story) in built.stories { storiesByRoute[key] = story }
        for (key, events) in built.sunEvents { sunEventsByLeg[key] = events }
    }

    /// The facts for `tripMap` from what's built so far.
    func facts(for tripMap: TripMap, forecasts: [String: LandingForecast] = [:], dayNumber: Int? = nil, totalDays: Int? = nil) -> TripFacts {
        var stories: [String: LegStory] = [:]
        var sunEvents: [String: [SkyFacts.SunEvent]] = [:]
        for leg in tripMap.legs where leg.kind == .flight {
            stories[leg.id] = storiesByRoute[Self.routeKey(for: leg, home: tripMap.home)]
            sunEvents[leg.id] = sunEventsByLeg[Self.timesKey(for: leg)]
        }
        return TripFacts(tripMap: tripMap, geography: geography, comparisons: comparisons, stories: stories,
                         sunEvents: sunEvents, forecasts: forecasts, dayNumber: dayNumber, totalDays: totalDays)
    }

    /// The route, and home when the flight passes it by: home changes the closest-point fact.
    nonisolated static func routeKey(for leg: MapLeg, home: AirportMark?) -> String {
        let route = "\(leg.origin.code)-\(leg.destination.code)"
        guard let home, home.code != leg.origin.code, home.code != leg.destination.code else { return route }
        return "\(route)|\(home.code)"
    }

    /// The flight, its route and its delay-shifted times: a new delay moves the sun events.
    nonisolated static func timesKey(for leg: MapLeg) -> String {
        "\(leg.id)|\(leg.origin.code)-\(leg.destination.code)|\(leg.start.timeIntervalSince1970)|\(leg.end.timeIntervalSince1970)"
    }
}
```

- [ ] **Step 4: Run the tests, expecting them to pass.** Todd runs `LegStoryStoreTests`.

- [ ] **Step 5: Ask to commit.** Suggested message: `feat(crewluv): LegStoryStore builds the facts' stories off the main actor and keeps them (Stage 2 spec §3.2)`.

---

### Task 17: Weather on landing

WeatherKit's forecast for the landing hour, for the flight in the air and for the next flight when it lands within 48 hours (Stage 2 spec §7).

**Files:**
- Modify: `Crewluv/Services/WeatherService.swift`
- Create: `Crewluv/Services/TripMap/Facts/LandingWeather.swift`
- Test: `CrewluvTests/LandingWeatherTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/LandingWeatherTests.swift`. The fetching calls WeatherKit, so Todd checks it on the simulator in Task 21. These tests cover which flights get weather:

```swift
//
//  LandingWeatherTests.swift
//  CrewluvTests
//
//  Which flights get weather on landing (Stage 2 spec §7.2): the one in the air, and the next when it lands within
//  48 hours. The Europe trip's flights land at +8, +38 and +72 hours.
//

import XCTest
@testable import Crewluv

final class LandingWeatherTests: XCTestCase {

    private let start = TripMapTestLegs.tripStart

    private func ids(at hours: Double) throws -> [String] {
        let now = start.addingTimeInterval(hours * 3600)
        let map = try XCTUnwrap(TripMapTestLegs.map(TripMapTestLegs.europeTrip(), at: now))
        return LandingWeather.flightsToForecast(in: map, now: now).map(\.id)
    }

    func test_flightsToForecast_inTheAir_thisFlightAndTheNext() throws {
        XCTAssertEqual(try ids(at: 4), ["f1", "f2"])
    }

    func test_flightsToForecast_onALayover_theNextFlight() throws {
        XCTAssertEqual(try ids(at: 12), ["f2"])
    }

    func test_flightsToForecast_aFlightLandingMoreThan48HoursOut_isLeftOut() throws {
        XCTAssertEqual(try ids(at: -24), ["f1"], "lands 32 hours out")
        XCTAssertEqual(try ids(at: -48), [], "lands 56 hours out")
    }
}
```

- [ ] **Step 2: Run them, expecting a build failure.** Todd runs `LandingWeatherTests`.

- [ ] **Step 3: Add the landing forecast to `WeatherService`.** In `Crewluv/Services/WeatherService.swift`, inside `final class WeatherService`:
  - after `private static let cacheDuration…`, add:

```swift
    private var landingCache: [String: (forecast: LandingForecast, fetchedAt: Date)] = [:]
    private static let landingCacheDuration: TimeInterval = 30 * 60 // 30 minutes
```

  - after `currentWeather(forAirport:latitude:longitude:)`, add:

```swift
    /// The forecast for the hour holding `landing` at an airport (moving map Stage 2 spec §7.1): one hour of WeatherKit's
    /// hourly forecast, cached by airport and hour for 30 minutes. Nil, logged, when WeatherKit can't give one.
    func landingForecast(forAirport iata: String, latitude: Double, longitude: Double, at landing: Date) async -> LandingForecast? {
        let hour = Date(timeIntervalSince1970: (landing.timeIntervalSince1970 / 3600).rounded(.down) * 3600)
        let key = "\(iata)@\(Int(hour.timeIntervalSince1970))"
        if let cached = landingCache[key], Date().timeIntervalSince(cached.fetchedAt) < Self.landingCacheDuration {
            return cached.forecast
        }
        do {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let hours = try await WeatherKit.WeatherService.shared.weather(
                for: location, including: .hourly(startDate: hour, endDate: hour.addingTimeInterval(3600)))
            guard let forecastHour = hours.first else { return nil }
            let forecast = LandingForecast(
                temperature: forecastHour.temperature.formatted(
                    .measurement(width: .abbreviated, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))),
                condition: forecastHour.condition.description.lowercased()
            )
            landingCache[key] = (forecast, Date())
            return forecast
        } catch {
            debugLog("WeatherService: no landing forecast for \(iata): \(error)")
            return nil
        }
    }
```

- [ ] **Step 4: Write `LandingWeather`.** Create `Crewluv/Services/TripMap/Facts/LandingWeather.swift`:

```swift
//
//  LandingWeather.swift
//  CrewLuve
//
//  Weather on landing (Stage 2 spec §7): which flights get it, and fetching it while the full-screen map is open, now
//  and every 30 minutes. The card never shows weather, so nothing is fetched until the map opens.
//

import Foundation
import Observation

@Observable
@MainActor
final class LandingWeather {

    /// Landing-hour forecasts, by leg id.
    private(set) var forecasts: [String: LandingForecast] = [:]

    private static let refreshInterval: Duration = .seconds(30 * 60)

    /// The flight in the air at `now`, and the next flight, each only when it lands within 48 hours of `now`.
    nonisolated static func flightsToForecast(in tripMap: TripMap, now: Date) -> [MapLeg] {
        let flights = tripMap.legs.filter { $0.kind == .flight }
        let inAir = flights.first { $0.isMoving(at: now) }
        let next = flights.first { $0.start > now }
        return [inAir, next].compactMap { $0 }.filter { $0.end.timeIntervalSince(now) <= TripFacts.weatherHorizon }
    }

    /// Fetches the forecasts now, then every 30 minutes until the task is cancelled, when the map closes.
    func keepRefreshing(for tripMap: TripMap) async {
        while !Task.isCancelled {
            await refresh(for: tripMap, now: .now)
            try? await Task.sleep(for: Self.refreshInterval)
        }
    }

    private func refresh(for tripMap: TripMap, now: Date) async {
        for leg in Self.flightsToForecast(in: tripMap, now: now) {
            let place = leg.destination.coordinate
            if let forecast = await WeatherService.shared.landingForecast(forAirport: leg.destination.code, latitude: place.latitude,
                                                                          longitude: place.longitude, at: leg.end) {
                forecasts[leg.id] = forecast
            }
        }
    }
}
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `LandingWeatherTests`.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): weather on landing from WeatherKit's hourly forecast, for the flight in the air and the next one within 48 hours (Stage 2 spec §7)`.

**Batch D review:** dispatch `superpowers:code-reviewer` (sonnet) on Tasks 16–17, then Todd runs `LegStoryStoreTests` and `LandingWeatherTests`.

---
### Task 18: The rows' views

The pieces the sheet and the panel share (Stage 2 spec §6.3). Views only render what `TripFacts` says, so there are no unit tests. Task 21 checks them on the simulator.

**Files:**
- Create: `Crewluv/Views/TripMap/FactRowView.swift`
- Create: `Crewluv/Views/TripMap/TripSoFarList.swift`
- Create: `Crewluv/Views/TripMap/FactsFooter.swift`
- Create: `Crewluv/Views/TripMap/FactsBody.swift`
- Create: `Crewluv/Views/TripMap/FactsHeader.swift`

- [ ] **Step 1: Write `FactRowView`.** Create `Crewluv/Views/TripMap/FactRowView.swift`:

```swift
//
//  FactRowView.swift
//  CrewLuve
//
//  One row of the facts (Stage 2 spec §6.3): a symbol, a title and a second line, which VoiceOver reads as one
//  sentence.
//

import SwiftUI

struct FactRowView: View {
    let row: FactRow

    @ScaledMetric(relativeTo: .subheadline) private var symbolWidth: CGFloat = 24

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: row.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: symbolWidth)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                if let detail = row.detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.sentence)
    }
}
```

- [ ] **Step 2: Write `TripSoFarList`.** Create `Crewluv/Views/TripMap/TripSoFarList.swift`:

```swift
//
//  TripSoFarList.swift
//  CrewLuve
//
//  The facts dragged all the way up (Stage 2 spec §5.2): each started flight's milestones under its name, newest
//  flight first, then the trip's totals.
//

import SwiftUI

struct TripSoFarList: View {
    let tripSoFar: TripSoFar

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(tripSoFar.flights) { flight in
                section(flight.title, lines: flight.milestones)
            }
            if let totals = tripSoFar.totals {
                section(tripSoFar.totalsTitle, lines: [totals])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.subheadline)
            }
        }
    }
}
```

- [ ] **Step 3: Write `FactsFooter`.** Create `Crewluv/Views/TripMap/FactsFooter.swift`:

```swift
//
//  FactsFooter.swift
//  CrewLuve
//
//  Under the facts (Stage 2 spec §5.2, §7.2): they're estimated from the schedule, and Apple's Weather mark and legal
//  link whenever a WeatherKit forecast shows.
//

import SwiftUI

struct FactsFooter: View {
    let showsWeather: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Estimated from the schedule")
                .font(.caption)
                .foregroundStyle(.secondary)
            if showsWeather {
                WeatherAttributionView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 4: Write `FactsBody`.** Create `Crewluv/Views/TripMap/FactsBody.swift`:

```swift
//
//  FactsBody.swift
//  CrewLuve
//
//  The facts below the headline and timeline (Stage 2 spec §5): the rows, then the trip so far and the footer. The
//  sheet scrolls it with its header; the side panel scrolls it between its headline and its timeline.
//

import SwiftUI

struct FactsBody: View {
    let rows: [FactRow]
    let tripSoFar: TripSoFar

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            Divider()
                        }
                        FactRowView(row: row)
                    }
                }
            }
            TripSoFarList(tripSoFar: tripSoFar)
            FactsFooter(showsWeather: rows.contains(where: \.hasWeather))
        }
    }
}
```

- [ ] **Step 5: Write `FactsHeader`.** Create `Crewluv/Views/TripMap/FactsHeader.swift`:

```swift
//
//  FactsHeader.swift
//  CrewLuve
//
//  The top of the iPhone sheet, all its small stop shows (Stage 2 spec §6.1): the headline and the timeline.
//

import SwiftUI

struct FactsHeader: View {
    let headline: String
    @Binding var clock: TripReplayClock
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headline)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            TripTimelineControl(clock: $clock, time: time, now: now)
        }
    }
}
```

- [ ] **Step 6: Don't commit yet.** These views have no caller until Task 19, and the app builds again only after Task 20, so Tasks 18–20 are one commit. Go straight on to Task 19.

---

### Task 19: The sheet, the side panel and the full-screen map

On iPhone the facts are SwiftUI's sheet with three stops. On iPad and in landscape they're a side panel the full height of the leading edge (Stage 2 spec §6.1, §6.2). The full-screen map presents one or shows the other, fetches weather, opens a recap paused at its start, and closes the sheet before itself.

**Files:**
- Create: `Crewluv/Views/TripMap/FactsSheet.swift`
- Create: `Crewluv/Views/TripMap/FactsPanel.swift`
- Modify (replace): `Crewluv/Views/TripMap/TripMapScreen.swift`
- Delete: `Crewluv/Views/TripMap/TripMapPanel.swift`

- [ ] **Step 1: Write `FactsSheet`.** Create `Crewluv/Views/TripMap/FactsSheet.swift`:

```swift
//
//  FactsSheet.swift
//  CrewLuve
//
//  The facts on iPhone (Stage 2 spec §6.1): SwiftUI's sheet over the full-screen map, in three stops. Small, the
//  headline and the timeline; in the middle, a row per kind of fact; all the way up, the trip so far. The map stays
//  usable up to the middle stop, and the sheet can't be swiped away: Close dismisses it.
//

import SwiftUI

struct FactsSheet: View {
    let facts: TripFacts
    @Binding var clock: TripReplayClock
    @Binding var detent: PresentationDetent
    /// The small stop, which grows with the text size.
    let smallDetent: PresentationDetent
    /// The sheet's height on screen, which the map keeps clear.
    @Binding var height: CGFloat

    var body: some View {
        // Its own clock: a sheet is a separate presentation from the map under it.
        TimelineView(.periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1)) { context in
            let time = clock.time(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    FactsHeader(headline: facts.sheetHeadline(at: time), clock: $clock, time: time, now: context.date)
                    FactsBody(rows: facts.rows(at: time, now: context.date), tripSoFar: facts.tripSoFar(at: time))
                }
                .padding()
            }
            .scrollDisabled(detent == smallDetent)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .presentationDetents([smallDetent, .medium, .large], selection: $detent)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }
}
```

- [ ] **Step 2: Write `FactsPanel`.** Create `Crewluv/Views/TripMap/FactsPanel.swift`:

```swift
//
//  FactsPanel.swift
//  CrewLuve
//
//  The facts on iPad and in landscape (Stage 2 spec §6.2): a panel down the leading edge. Its rows scroll between the
//  headline and the timeline, and the chevron folds it down to just those two.
//

import SwiftUI

struct FactsPanel: View {
    let facts: TripFacts
    @Binding var clock: TripReplayClock
    /// The trip time on screen.
    let time: Date
    /// The real time of this tick.
    let now: Date
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(facts.sheetHeadline(at: time))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button(action: toggle) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(isExpanded ? "Hide facts" : "Show facts")
            }
            if isExpanded {
                ScrollView {
                    FactsBody(rows: facts.rows(at: time, now: now), tripSoFar: facts.tripSoFar(at: time))
                }
                .frame(maxHeight: .infinity)
            }
            TripTimelineControl(clock: $clock, time: time, now: now)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func toggle() {
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.snappy) { isExpanded.toggle() }
        }
    }
}
```

- [ ] **Step 3: Replace `TripMapScreen`.** Replace the whole of `Crewluv/Views/TripMap/TripMapScreen.swift` with:

```swift
//
//  TripMapScreen.swift
//  CrewLuve
//
//  The full-screen trip map (moving map spec §6, Stage 2 spec §6): pan and zoom, change the style, replay the trip and
//  read its facts. On iPhone the facts are a sheet you drag up; on iPad and in landscape, a panel down the leading
//  edge. A recap opens paused at its trip's start. Weather on landing is fetched while the screen is open.
//

import MapKit
import SwiftUI

struct TripMapScreen: View {
    let tripMap: TripMap
    let storyStore: LegStoryStore
    let dayNumber: Int?
    let totalDays: Int?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The sheet's small stop: the headline and the timeline, growing with the text size.
    @ScaledMetric(relativeTo: .headline) private var smallSheetHeight: CGFloat = 160
    @State private var clock: TripReplayClock
    @State private var style: TripMapStyle = .hybrid
    @State private var position: MapCameraPosition
    @State private var weather = LandingWeather()
    @State private var detent: PresentationDetent = .medium
    @State private var sheetHeight: CGFloat = 0
    @State private var topBarHeight: CGFloat = 0
    @State private var isPanelExpanded = true
    @State private var isClosing = false

    private static let panelWidth: CGFloat = 380

    init(tripMap: TripMap, storyStore: LegStoryStore, dayNumber: Int?, totalDays: Int?) {
        self.tripMap = tripMap
        self.storyStore = storyStore
        self.dayNumber = dayNumber
        self.totalDays = totalDays
        let clock = tripMap.mode == .recap
            ? TripReplayClock(span: tripMap.span, pausedAt: tripMap.span.start)
            : TripReplayClock(span: tripMap.span)
        _clock = State(initialValue: clock)
        _position = State(initialValue: tripMap.camera(focusingOn: tripMap.currentLeg))
    }

    var body: some View {
        // Every second live; about 30 times a second while a replay runs.
        TimelineView(.periodic(from: .now, by: clock.isPlaying ? 1.0 / 30 : 1)) { context in
            let time = clock.time(at: context.date)
            screen(time: time, now: context.date)
                .onChange(of: tripMap.legInMotion(at: time)?.id) { _, legID in
                    refit(legID: legID)
                }
        }
        .sheet(isPresented: isShowingSheet, onDismiss: finishClosing) {
            FactsSheet(facts: facts, clock: $clock, detent: $detent, smallDetent: smallDetent, height: $sheetHeight)
        }
        .task { await storyStore.prepare(tripMap) }
        .task { await weather.keepRefreshing(for: tripMap) }
        .onAppear { detent = smallDetent }
        .onChange(of: usesSidePanel) { _, isSidePanel in
            if !isSidePanel { detent = smallDetent }
        }
    }

    private var facts: TripFacts {
        storyStore.facts(for: tripMap, forecasts: weather.forecasts, dayNumber: dayNumber, totalDays: totalDays)
    }

    @ViewBuilder
    private func screen(time: Date, now: Date) -> some View {
        let base = ZStack(alignment: .top) {
            TripMapView(tripMap: tripMap, date: time, style: style, nightStep: nightStep,
                        position: $position, isInteractive: true)
                // The camera frames the trip in what the sheet or the panel leaves clear.
                .safeAreaPadding(.bottom, usesSidePanel ? 0 : sheetHeight)
                .safeAreaPadding(.leading, usesSidePanel && isPanelExpanded ? Self.panelWidth : 0)
                .ignoresSafeArea()
            topBar(time: time)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topBarHeight = $0 }
        }
        if usesSidePanel {
            base.overlay(alignment: .bottomLeading) {
                FactsPanel(facts: facts, clock: $clock, time: time, now: now, isExpanded: $isPanelExpanded)
                    .frame(width: Self.panelWidth)
                    .padding([.horizontal, .bottom])
                    .padding(.top, topBarHeight + 8)
            }
        } else {
            base
        }
    }

    private func topBar(time: Date) -> some View {
        TripMapTopBar(
            pill: TripMapWording.topPill(for: tripMap, at: time, dayNumber: dayNumber, totalDays: totalDays),
            style: style,
            isShowingRecenter: position.positionedByUser,
            onClose: close,
            onRecenter: { refit(legID: tripMap.legInMotion(at: time)?.id, force: true) },
            onNextStyle: { style = style.next }
        )
    }

    /// iPad, and iPhone in landscape.
    private var usesSidePanel: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    private var smallDetent: PresentationDetent {
        .height(smallSheetHeight)
    }

    /// The sheet shows on iPhone in portrait until Close. The family can't dismiss it themselves.
    private var isShowingSheet: Binding<Bool> {
        Binding(get: { !usesSidePanel && !isClosing }, set: { _ in })
    }

    /// With the sheet up, it goes first and the map follows in `finishClosing`.
    private func close() {
        if usesSidePanel {
            dismiss()
        } else {
            isClosing = true
        }
    }

    private func finishClosing() {
        if isClosing { dismiss() }
    }

    /// Night moves about a degree every four minutes. Live it's redrawn each minute; in replay about ten times a
    /// second of real time, whatever the speed (moving map spec §10).
    private var nightStep: TimeInterval {
        clock.isPlaying ? TripReplayClock.baseRate / 10 * Double(clock.speed.rawValue) : 60
    }

    /// Frames the leg in motion, or the whole trip. Leaves a camera the family moved alone, unless they asked.
    private func refit(legID: String?, force: Bool = false) {
        guard force || !position.positionedByUser else { return }
        let leg = legID.flatMap { id in tripMap.legs.first { $0.id == id } }
        let camera = tripMap.camera(focusingOn: leg)
        if reduceMotion {
            position = camera
        } else {
            withAnimation(.smooth) { position = camera }
        }
    }
}
```

- [ ] **Step 4: Delete the Stage 1 panel.**

```bash
git -C /Users/toddanderson/Dev/Crewluv rm Crewluv/Views/TripMap/TripMapPanel.swift
```

- [ ] **Step 5: Build in Xcode.** `TripMapCard` and the previews still call `TripMapScreen(tripMap:dayNumber:totalDays:)`, so the build fails until Task 20. Go straight on to Task 20, and Todd builds after it.

---

### Task 20: The card, the recap card and the status screen

The card's chip shows the headline in flight. For a day after a trip, the card is its recap. The status screen owns the story store (Stage 2 spec §6.4, §6.5, §3.3).

**Files:**
- Modify: `Crewluv/Views/TripMap/TripMapChip.swift`
- Create: `Crewluv/Views/TripMap/TripRecapBar.swift`
- Modify (replace): `Crewluv/Views/TripMap/TripMapCard.swift`
- Modify (replace): `Crewluv/Views/TripMap/TripMapPreviews.swift`
- Modify: `Crewluv/Views/Status/PilotStatusView.swift`

- [ ] **Step 1: Let a chip carry a symbol.** Replace the body of `TripMapChip` in `Crewluv/Views/TripMap/TripMapChip.swift` (keep the header comment) with:

```swift
struct TripMapChip: View {
    let text: String
    /// An SF Symbol before the text: the recap's "Replay the trip" plays.
    var systemImage: String? = nil

    var body: some View {
        label
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private var label: some View {
        if let systemImage {
            Label(text, systemImage: systemImage)
        } else {
            Text(text)
        }
    }
}
```

- [ ] **Step 2: Write `TripRecapBar`.** Create `Crewluv/Views/TripMap/TripRecapBar.swift`:

```swift
//
//  TripRecapBar.swift
//  CrewLuve
//
//  The bar under the recap card's map (Stage 2 spec §6.5): up to four numbers, then the longest flight. At the
//  largest text sizes the numbers stack. VoiceOver reads the card's button, which says all of it in one sentence.
//

import SwiftUI

struct TripRecapBar: View {
    let tiles: [RecapTile]
    let longest: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            tileLayout {
                ForEach(tiles) { tile in
                    VStack(spacing: 2) {
                        Text(tile.value)
                            .font(.headline)
                            .monospacedDigit()
                        Text(tile.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
                }
            }
            if let longest {
                Text(longest)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .accessibilityHidden(true)
    }

    private var tileLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 8))
    }
}
```

- [ ] **Step 3: Replace `TripMapCard`.** Replace the whole of `Crewluv/Views/TripMap/TripMapCard.swift` with:

```swift
//
//  TripMapCard.swift
//  CrewLuve
//
//  The trip map on the status screen (moving map spec §5, Stage 2 spec §6.4, §6.5). In flight it follows the plane,
//  with the headline fact on its chip; on the ground it shows the whole trip with a heart where the pilot is; at home,
//  the next trip, or for a day after a trip, its recap. Tapping the map opens it full screen.
//

import MapKit
import SwiftUI

struct TripMapCard: View {
    let tripMap: TripMap
    let status: SharedPilotStatus
    let storyStore: LegStoryStore

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var position: MapCameraPosition
    @State private var isShowingFullScreen = false

    init(tripMap: TripMap, status: SharedPilotStatus, storyStore: LegStoryStore) {
        self.tripMap = tripMap
        self.status = status
        self.storyStore = storyStore
        _position = State(initialValue: tripMap.camera(focusingOn: tripMap.currentLeg))
    }

    var body: some View {
        // The plane moves about a pixel in ten seconds at this size, as today's map refreshed.
        TimelineView(.periodic(from: .now, by: 10)) { context in
            let facts = storyStore.facts(for: tripMap, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
            let cardChips = chips(from: facts, at: context.date)
            VStack(spacing: 0) {
                mapButton(facts: facts, chips: cardChips, at: context.date)
                if dynamicTypeSize.isAccessibilitySize {
                    stackedChips(cardChips)
                }
                if tripMap.isInFlight, status.hasFlightDelay, let delay = status.effectiveFlightDelayMinutes {
                    FlightDelayBanner(delayMinutes: delay)
                }
                bar(facts: facts, at: context.date)
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .task(id: storyKey) {
            await storyStore.prepare(tripMap)
        }
        .onChange(of: tripMap.mode) {
            position = tripMap.camera(focusingOn: tripMap.currentLeg)
        }
        .onChange(of: tripMap.legs.map(\.id)) {
            position = tripMap.camera(focusingOn: tripMap.currentLeg)
        }
        .fullScreenCover(isPresented: $isShowingFullScreen) {
            TripMapScreen(tripMap: tripMap, storyStore: storyStore, dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays)
        }
    }

    /// The flights, their routes and their times: a new route or delay builds again.
    private var storyKey: [String] {
        tripMap.legs.map(LegStoryStore.timesKey(for:))
    }

    /// Stage 1's chips, with the headline fact on the bottom one in flight.
    private func chips(from facts: TripFacts, at date: Date) -> (top: String?, bottom: String?) {
        let chips = TripMapWording.cardChips(for: tripMap, at: date)
        guard tripMap.isInFlight else { return chips }
        return (chips.top, facts.headline(at: date) ?? chips.bottom)
    }

    private func mapButton(facts: TripFacts, chips: (top: String?, bottom: String?), at date: Date) -> some View {
        Button {
            isShowingFullScreen = true
        } label: {
            TripMapView(tripMap: tripMap, date: date, style: .hybrid, position: $position)
                .allowsHitTesting(false)
                .frame(height: 220)
                .overlay(alignment: .topLeading) { overlayChip(chips.top) }
                .overlay(alignment: .bottomLeading) {
                    overlayChip(chips.bottom, systemImage: tripMap.mode == .recap ? "play.fill" : nil)
                }
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(facts.cardSummary(now: date, pilotName: status.pilotFirstName))
        .accessibilityHint(tripMap.mode == .recap ? "Opens the map to replay the trip" : "Opens the full-screen map")
    }

    @ViewBuilder
    private func bar(facts: TripFacts, at date: Date) -> some View {
        if let leg = tripMap.currentLeg {
            TripMapInFlightBar(leg: leg)
        } else if tripMap.mode == .recap {
            TripRecapBar(tiles: facts.recapTiles, longest: facts.recapLongestLine)
        } else {
            TripMapStatsBar(items: TripMapWording.statsItems(for: tripMap, at: date,
                                                             dayNumber: status.tripDayNumber, totalDays: status.tripTotalDays))
        }
    }

    @ViewBuilder
    private func overlayChip(_ text: String?, systemImage: String? = nil) -> some View {
        if let text, !dynamicTypeSize.isAccessibilitySize {
            TripMapChip(text: text, systemImage: systemImage)
                .padding(10)
        }
    }

    /// At the largest text sizes the chips would cover the map, so they move below it (moving map spec §14).
    private func stackedChips(_ chips: (top: String?, bottom: String?)) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach([chips.top, chips.bottom].compactMap { $0 }, id: \.self) { chip in
                Text(chip).font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 10)
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 4: The status screen owns the store.** In `Crewluv/Views/Status/PilotStatusView.swift`:
  - after `    @State private var showSchedule = false`, add:

```swift
    /// The trip map's stories, kept while the screen is (moving map Stage 2 spec §3.3).
    @State private var legStoryStore = LegStoryStore()
```

  - replace `TripMapCard(tripMap: tripMap, status: status)` with `TripMapCard(tripMap: tripMap, status: status, storyStore: legStoryStore)`.

- [ ] **Step 5: Update the previews.** Replace the whole of `Crewluv/Views/TripMap/TripMapPreviews.swift` with:

```swift
//
//  TripMapPreviews.swift
//  CrewLuve
//
//  The trip map card in each state, around the time the canvas opens: Louisville to Cologne to Dubai and home,
//  Anchorage to Tokyo across the date line, and the Europe trip's recap. Each preview builds its own story store.
//

#if DEBUG
import CoreLocation
import SwiftUI

private enum TripMapPreviewData {

    static func coordinate(_ code: String) -> CLLocationCoordinate2D? {
        AirportDataProvider.shared.airportInfo(forIataCode: code).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    static func flight(_ flightNumber: String, _ from: String, _ to: String, _ fromCity: String, _ toCity: String,
                       start: Date, hours: Double, zone: String, arrivalZone: String) -> TripLeg {
        TripLeg(id: flightNumber, tripId: "P1", type: .flight, startTime: start, endTime: start.addingTimeInterval(hours * 3600),
                airportCode: nil, city: nil, timezoneIdentifier: zone, arrivalTimezoneIdentifier: arrivalZone,
                flightNumber: flightNumber, departureAirport: from, arrivalAirport: to,
                departureCity: fromCity, arrivalCity: toCity, tripDayNumber: nil, tripTotalDays: nil,
                delayMinutes: nil, airlineCode: nil, label: nil)
    }

    /// The Europe trip, `hoursIn` hours after its first departure.
    static func europe(hoursIn: Double, isNextTrip: Bool = false, isRecap: Bool = false) -> TripMap? {
        let now = Date()
        let start = now.addingTimeInterval(-hoursIn * 3600)
        let legs = [
            flight("UPS207", "SDF", "CGN", "Louisville", "Cologne", start: start, hours: 8, zone: "America/New_York", arrivalZone: "Europe/Berlin"),
            flight("UPS208", "CGN", "DXB", "Cologne", "Dubai", start: start.addingTimeInterval(32 * 3600), hours: 6, zone: "Europe/Berlin", arrivalZone: "Asia/Dubai"),
            flight("UPS209", "DXB", "SDF", "Dubai", "Louisville", start: start.addingTimeInterval(58 * 3600), hours: 14, zone: "Asia/Dubai", arrivalZone: "America/New_York"),
        ]
        return TripMap.make(tripLegs: legs, isNextTrip: isNextTrip, isRecap: isRecap, homeAirportCode: "SDF", legacyDelayMinutes: nil,
                            at: now, coordinate: { coordinate($0) })
    }

    static var pacific: TripMap? {
        let start = Date().addingTimeInterval(-3 * 3600)
        let legs = [flight("UPS61", "ANC", "NRT", "Anchorage", "Tokyo", start: start, hours: 8, zone: "America/Anchorage", arrivalZone: "Asia/Tokyo")]
        return TripMap.make(tripLegs: legs, isNextTrip: false, homeAirportCode: "SDF", legacyDelayMinutes: nil, at: Date(), coordinate: { coordinate($0) })
    }
}

#Preview("In flight") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Layover") {
    if let map = TripMapPreviewData.europe(hoursIn: 12) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Next trip") {
    if let map = TripMapPreviewData.europe(hoursIn: -48, isNextTrip: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Recap") {
    if let map = TripMapPreviewData.europe(hoursIn: 75, isRecap: true) {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Across the date line") {
    if let map = TripMapPreviewData.pacific {
        TripMapCard(tripMap: map, status: .demo, storyStore: LegStoryStore()).padding()
    }
}

#Preview("Full screen, in flight") {
    if let map = TripMapPreviewData.europe(hoursIn: 4) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: 1, totalDays: 4)
    }
}

#Preview("Full screen, recap") {
    if let map = TripMapPreviewData.europe(hoursIn: 75, isRecap: true) {
        TripMapScreen(tripMap: map, storyStore: LegStoryStore(), dayNumber: nil, totalDays: nil)
    }
}
#endif
```

- [ ] **Step 6: Build.** Todd builds the app in Xcode (⌘B) and runs the whole `CrewluvTests` suite once.

- [ ] **Step 7: Ask to commit Tasks 18–20 together.** Suggested message: `feat(crewluv): the trip map's facts: a sheet you drag up on iPhone, a side panel on iPad and in landscape, the headline on the card, and the recap card (Stage 2 spec §6)`. This commit changes what families see: draft the "Crewluve revisions" Apple Note entry (release-notes memory) and confirm the version with Todd.

---

### Task 21: Check it on the simulator, and the docs

**Files:**
- Modify: `CLAUDE.md`
- Modify: this plan (a "Changes made during execution" section at the end)

- [ ] **Step 1: Update `CLAUDE.md`.** In the `#### Trip Map (Services/TripMap/, Views/TripMap/)` section, after its last bullet, add:

```markdown
- The facts (Stage 2 spec `docs/superpowers/specs/2026-11-13-crewluve-moving-map-stage2-facts-design.md`) are in `Services/TripMap/Facts/`. `LegStory` works out each flight's places and closest point to home once, as fractions along its route; `TripFacts` answers the headline, the rows and the recap at any moment from the stories, so replay needs nothing extra. `LegStoryStore`, owned by the status screen, builds the stories off the main actor
- The facts show in `FactsSheet` (iPhone, SwiftUI's sheet with three stops) or `FactsPanel` (iPad and landscape), on the card's chip in flight, and as the recap card for a day after a trip ends. Weather on landing (`LandingWeather`, WeatherKit) is fetched only while the full-screen map is open, with Apple's attribution under the rows
- `Crewluv/Resources/TripMap/geography.json` is made from Natural Earth by `node scripts/build-geography.mjs`, whose downloaded sources go in the ignored `scripts/natural-earth/`. `comparisons.json` is written by hand. `CrewluvTests/Fixtures/TripMap/facts-cases.json` holds the facts to the website's answers: change both copies together
```

  In the File Structure block:
  - after the line `│   ├── TripMap/                      # The trip map's model, drawing, clock and words`, add `│   │   └── Facts/                    # The facts: geography, stories, sky, totals, words`;
  - before the line `└── Utils/                    # Utilities`, add `├── Resources/TripMap/        # geography.json and comparisons.json`.

- [ ] **Step 2: Todd checks it on the simulator.** Run the app in demo mode, and open the previews, on an iPhone 17 Pro and an iPad. Check:
  1. **In flight:** the card's chip follows the headline: a milestone, then the place below, then the landing countdown.
  2. **The iPhone sheet:**
     - the full-screen map opens with the sheet at its small stop: the headline and timeline;
     - it drags to the middle (the rows) and to the top (the trip so far);
     - the map pans while the sheet is small or in the middle, and the plane is framed above the sheet;
     - Close works with the sheet up.
  3. **Landscape on iPhone:**
     - the sheet goes and the panel shows, below the top bar;
     - the chevron hides and shows the rows;
     - turning back brings the sheet at its small stop.
  4. **iPad:** the panel, with the close button clear of it.
  5. **Replay:** the rows follow the timeline. Weather doesn't show for a landing already past.
  6. **Weather:** the landing line shows "… on landing", with the  Weather mark under the rows.
  7. **The recap preview:**
     - the tiles and the longest flight show;
     - "Replay the trip" opens the map paused at the start, and Play replays it;
     - after the end, the sheet reads "Home from 4 days away".
  8. **The largest text size:** the chips move under the map, the recap tiles stack, and the sheet's small stop still fits its headline and timeline.
  9. **Dark Mode, and VoiceOver** on the card, the rows and the chevron.

  Fix anything found in the task it belongs to, and note it under "Changes made during execution".

- [ ] **Step 3: Final review.** Dispatch `superpowers:code-reviewer` (sonnet) on the whole of Stage 2A against the Stage 2 spec. Apply the fixes Todd agrees to, and list them under "Changes made during execution" at the end of this plan.

- [ ] **Step 4: Ask to commit.** Suggested message: `docs(crewluv): the trip map's facts in CLAUDE.md, and the Stage 2A plan's record of changes`.

- [ ] **Step 5: Hand over.** The website's Stage 2B plan starts once Stage 1B is merged. It copies `geography.json`, `comparisons.json` and `facts-cases.json`, and ports `Services/TripMap/Facts/` to `src/facts/`.

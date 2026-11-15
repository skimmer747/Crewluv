# Moving Map Stage 3B-1 (Crewluve App, the Engine) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the app everything it needs to know about the real plane, with nothing a family sees changing yet: the shared cases, the schedule's flight plan, the real path and its record, the plane's progress and its label, the door's `partner_live` call, and the model that asks for it.

**Architecture:**
- **A reference in JavaScript** (`scripts/live-cases/`) writes `live-cases.json`. It's written apart from the app's Swift and the website's TypeScript, so both are held to answers neither wrote.
- **Pure logic** goes in `nonisolated` value types in a new `Services/TripMap/Live/`, each with XCTest held to the shared cases:
  - `FlightPlan` is the schedule's plan (spec §4);
  - `LiveFlight` is one flight's live data;
  - `FlightPath` is the path, real once the plane has been seen in the air (§6.1);
  - `FlightRecord` says where the plane was at any moment, and when it was any distance along (§7.2);
  - `LiveProgress` is the real plane at one moment: its phase, landing estimate, gap, label, the two planes' places, and the leg's real times (§5, §7.1);
  - `LiveLabel` is ahead or behind, and `LiveWindow` is when to ask (§5.3, §10.2).
- **The door:** `LiveFlightDoor` is `partner_live`, apart from `PartnerDoor`, with `LivePartnerDoor`'s call in an extension. `PartnerLiveAnswer` reads the answer.
- **One model:** `LiveFlightSource`, `@Observable` on the main actor, asks once when the screen comes to the front and every 30 seconds while a flight's window is open. Nothing owns one yet: plan 3B-2 gives it to the status screen.

**Tech Stack:** Swift 5 language mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and approachable concurrency in the app target (not in the test target), iOS 26, XCTest for the pure types, Swift Testing for the door and the source (as `LivePartnerDoorTests` and `CrewluCloudDeviceTests` are), Node 23 with no packages for the reference.

**Spec:** `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md` ("the spec"), §4 to §7, §10.6, §11 and §16.1. The door's contract is CrewLu's `supabase/partner-api.md`, section "The live plane", on `feature/flight-live` in `~/Dev/Duty-flight-live`.

**This is the first of three plans for the app** (Todd's choice, 15 Nov 2026), each written when it's about to start:
- **3B-1, the engine:** this plan.
- **3B-2, the map:** one landing time, the real path and the two planes on the map, the card's words, and the replay. It gives the status screen its `LiveFlightSource`.
- **3B-3, the facts:** the story along the real path, the plane's row with `AircraftTypeNames`, and the credit.

**How this plan was checked.** Every code block here was built and run in a scratch Swift package with the app target's settings (macOS, Swift 6.4, language mode 5, the main actor by default, approachable concurrency), beside copies of the 15 app files the helper builds:
- 38 XCTest tests and 45 Swift Testing tests pass, with no warnings.
- The package was rebuilt as it stands after each of Tasks 3 to 8, in order, and passed each time.
- The Swift agreed with the JavaScript reference on every shared case at its first run.
- Ten deliberate breaks were tried, and each now fails a test. Two passed when first tried, or would have: the ghost before the plan's takeoff, and a late takeoff moving the leg's start. The cases gained a flight for each.
- Not checked: the two edits to `TripMapWording.swift` and the real `TripMapFixtures`, which need the whole app. A stand-in with the same two functions was used.

**Where this plan settles details the spec left open, or differs from it in small ways:**
- **`LiveFlightDoor`, not `PartnerDoor`.** The spec has `PartnerDoor` gain `live(key:after:)`, and also has none of the helper's 15 files change. `PartnerDoor.swift` and `LivePartnerDoor.swift` are two of the 15, and the helper must compile with only those files, so the call can't go in them. It's a protocol of its own, with `LivePartnerDoor`'s call in an extension the helper doesn't build.
- **One word changes in one of the helper's files:** `LivePartnerDoor.call` loses `private`, so the extension can use it. No file joins the helper.
- **`sharing_ended`** goes to `PilotStatusSource.endSharing()`, as the push registration's does. That forgets the key through `CrewluCloudDevice` and tells the screen. `LiveFlightSource` reads the key itself, as `PushRegistrar` does, and takes no answer for a key the device has since replaced.
- **`LiveFlightSource` has no `@MainActor` written on it.** The app's default puts it on the main actor, as it does `PilotStatusSource`. Written out, its initializer's defaults are worked out off the main actor, and the compiler warns.
- **A block too short for the taxi allowances** has none, as in Stage 1. So its live arrival is its touchdown: the spec's "plus `taxiInAllowance`" is the plan's own taxi in.
- **A leg that goes nowhere** (the same airport at both ends) has no speed of its own, so 280 kt stands in.
- **The gap rounds halves away from zero,** and every label reads the rounded gap. So "up to 5 minutes" on the ground is up to 5 min 29 s.
- **A fix exactly 2 minutes old is still live.** The spec says "under" and "over".
- **A label of an hour or more** is written as the landing countdown writes it: "1 h 15 min behind". `TripMapWording.minutesText` now writes both.
- **The label's words are here,** in `TripMapWording.liveLabel`, since the shared cases hold them. The card's other words are 3B-2's.
- **A flight in the air with no trail point yet** has a real path from its fix.
- **"In the air", for the path's last place, is the fix's own word** (`on_ground` is false), whatever the flight's state.
- **The takeoff is the first place the plane was seen,** a trail point or, with no trail yet, the fix, when it's within 30 nm of the departure airport.
- **The takeoff and the record differ a little.** The takeoff is the first place's time (§7.1). The record has the plane leave the airport before that, at the plan's speed, to reach the first place on time (§7.2): half a minute for a first place 3 nm out.
- **A landing more than 10 minutes after the last place seen** ends the path with an unseen stretch, and the record crosses it in proportion to the time.
- **A landed flight's touchdown is its record's,** where it has one, so the estimate and the record can't disagree. A landing time before the last point counts as the last point's.
- **A landing nobody saw** needs no path of its own. The path's last stretch stays the planned great circle, and the estimated plane's place along it says how much is behind the plane. 3B-2 draws that part dotted.
- **A leg's start moves earlier whenever its takeoff is known,** in every phase.
- **On the ground, the real plane is at its fix,** and counts as 0 along the path.
- **`LiveWindow` has Crewlu Cloud's own edges,** with its 12-hour end.
- **A state this Crewluve doesn't know** reads as `waiting`, so a newer Crewlu Cloud shows the schedule instead of failing the whole answer.
- **The trail is sorted by time** before the path is made.
- **`AircraftTypeNames` waits for 3B-3,** where the plane's row uses it.
- **The website's copy of `live-cases.json`** is plan 3C's first step.

**One open question for Todd, before 3B-2.** On 15 Nov, with the relay live for his account, adsb.lol answered 429 to some runs. Each one pauses the relay for 2 minutes, which makes the next fix 3 minutes after the last. `LiveProgress.freshFor` is 2 minutes, so in such a stretch the plane would flip between live and estimated. The choices are a shorter pause in the relay, a longer `freshFor` (one constant here and one in the cases), or leaving it. It doesn't change this plan.

---

## Ground rules for whoever runs this plan

These come from Todd's standing instructions. They override the skill's defaults.

1. **Don't run `xcodebuild` build or test loops,** and don't let subagents run them. Write the code and tests. At each task's checkpoint, Todd runs the named tests in Xcode, or with the command below.
2. **The tests are written first, and run once.** The code and its tests were already run together in the scratch package, so a first run that only fails to build would tell Todd nothing. He runs each task's tests after its code is in.
3. **Never commit without Todd's go-ahead in the conversation.** Each task ends with a suggested commit message. Ask, then commit only on a yes, and only the task's own files.
4. **No release note.** Nothing here changes what families see.
5. **New files join their target on their own.** `Crewluv/` and `CrewluvTests/` are synchronized folders. Don't tick `CrewluveAlerts` on any new file.
6. **Mark pure types `nonisolated`** (`nonisolated struct` / `nonisolated enum`). A conformance or a member in an extension is written `nonisolated extension`, or it defaults to the main actor and the tests can't call it.
7. **Copy the code as written.** It was compiled with the app's settings. If something doesn't build in Xcode, stop and say what the compiler said before changing it.
8. **Nothing here calls Crewlu Cloud or adsb.lol.** Every test uses a stand-in.
9. **Reviewers:** dispatch `superpowers:code-reviewer` with `model: "sonnet"`.
10. **Work on `feature/trip-map-live`,** never on `main` (Task 1). The checkout is shared with other sessions, so commit only this plan's files, and never stash, reset or switch branches.

Test command for Todd, one class per checkpoint. The OS is named because Todd's iPhone 17 Pro simulator is on iOS 26.5, and without it `xcodebuild` looks for one on the newest iOS and finds none:

```bash
xcodebuild test -project Crewluv.xcodeproj -scheme Crewluv -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:CrewluvTests/<TestClass>
```

## File map

| File | Status | Responsibility |
|---|---|---|
| `scripts/live-cases/live.mjs` | create | the reference: plan, path, record, progress, label, window |
| `scripts/live-cases/generate.mjs` | create | the made-up flights, and writing the cases |
| `CrewluvTests/Fixtures/TripMap/live-cases.json` | create (generated) | the shared cases (3C copies them) |
| `Crewluv/Services/TripMap/Live/LiveFlight.swift` | create | one flight's live data |
| `Crewluv/Services/PartnerCloud/PartnerLiveAnswer.swift` | create | `partner_live`'s answer, and reading it |
| `Crewluv/Services/PartnerCloud/LiveFlightDoor.swift` | create | the door's call for the live plane |
| `Crewluv/Services/PartnerCloud/LivePartnerDoor.swift` | modify | `call` loses `private` |
| `Crewluv/Utils/GreatCircle.swift` | modify | `metersPerNauticalMile` |
| `Crewluv/Services/TripMap/Live/FlightPlan.swift` | create | the schedule's plan |
| `Crewluv/Services/TripMap/Live/FlightPath.swift` | create | the path, and the place any distance along it |
| `Crewluv/Services/TripMap/Live/FlightRecord.swift` | create | where the plane was when |
| `Crewluv/Services/TripMap/Live/LiveLabel.swift` | create | ahead of the schedule or behind it |
| `Crewluv/Services/TripMap/Live/LiveProgress.swift` | create | the real plane at one moment |
| `Crewluv/Services/TripMap/TripMapWording.swift` | modify | `liveLabel`, `minutesText` |
| `Crewluv/Services/TripMap/Live/LiveWindow.swift` | create | when to ask |
| `Crewluv/Services/TripMap/Live/LiveFlightSource.swift` | create | asks, and keeps each flight |
| `CrewluvTests/Helpers/LiveCases.swift` | create | reads the shared cases |
| `CrewluvTests/Helpers/PartnerCloudStandIns.swift` | modify | the stand-in door answers `live` |
| `CrewluvTests/LivePartnerDoorTests.swift` | modify | the live call's request and answers |
| `CrewluvTests/FlightPlanTests.swift`, `FlightPathTests.swift`, `FlightRecordTests.swift`, `LiveProgressTests.swift`, `LiveLabelTests.swift`, `LiveWindowTests.swift`, `LiveFlightSourceTests.swift` | create | one class per type |
| `CLAUDE.md` | modify | the engine in Key Components and File Structure |

## Batches

Review with `superpowers:code-reviewer` (sonnet) after each batch, then Todd runs that batch's tests:

- **A, the cases and the door:** Tasks 2 and 3.
- **B, the maths:** Tasks 4 to 7.
- **C, the model:** Task 8.

---

### Task 1: Before starting

**Files:** none.

- [x] **Step 1: Check the branch and the tree.**

```bash
git -C /Users/toddanderson/Dev/Crewluv status --short && git -C /Users/toddanderson/Dev/Crewluv branch --show-current
```

  - If the branch is `feature/trip-map-live`, stay on it.
  - Anything else: stop and ask Todd.
  - Other changed files that aren't this plan's are left alone. Another session may share this checkout.

- [x] **Step 2: Check Node.** `node --version` should say v20 or later. The reference uses nothing but Node itself.

- [x] **Step 3: Read the door's contract.** `~/Dev/Duty-flight-live/supabase/partner-api.md`, section "The live plane". If that worktree is gone, the branch `feature/flight-live` of CrewLu's repo has it.

---

### Task 2: The reference and the shared cases

**Files:**
- Create: `scripts/live-cases/live.mjs`
- Create: `scripts/live-cases/generate.mjs`
- Create (generated): `CrewluvTests/Fixtures/TripMap/live-cases.json`

The reference is the spec's §4 to §7 in plain JavaScript, with no shared code with the app or the website. `generate.mjs` makes up flights (a trail every 2 minutes along a route, a late first point, an ocean nobody saw, a landing), runs them through the reference, and writes each answer down.

- [x] **Step 1: Write the reference.** Create `scripts/live-cases/live.mjs`:

```js
// The reference for live-cases.json: Stage 3's flight plan, path, record and progress (spec §4 to §7), written
// apart from the app's Swift and the website's TypeScript, so both are held to answers neither wrote.
// Distances are metres and times are seconds since 1970 unless a name says otherwise.

export const EARTH_RADIUS = 6371008.8
export const NM = 1852
export const TAXI_OUT = 15 * 60
export const TAXI_IN = 7 * 60
export const SHORTEST_CRUISE = 10 * 60
export const DESCENT_DISTANCE = 120 * NM
export const DESCENT_SPEED = 280 * NM / 3600
export const DESCENT_TIME = DESCENT_DISTANCE / DESCENT_SPEED
export const FRESH = 120
export const AIRPORT_RADIUS = 10 * NM
export const ON_SCHEDULE_MINUTES = 5
export const UNSEEN_GAP = 10 * 60
export const FIRST_POINT_RADIUS = 30 * NM
export const WINDOW_OPENS_BEFORE = 30 * 60
export const WINDOW_CLOSES_AFTER = 2 * 3600
export const WINDOW_KEEPS_FOR = 30 * 60
export const WINDOW_ENDS_AFTER = 12 * 3600

const rad = (d) => d * Math.PI / 180
const deg = (r) => r * 180 / Math.PI

// MARK: Great circles, as Utils/GreatCircle.swift. A place is [latitude, longitude].

function centralAngle(a, b) {
  const lat1 = rad(a[0]), lat2 = rad(b[0])
  const dLat = lat2 - lat1, dLon = rad(b[1] - a[1])
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2
  return 2 * Math.asin(Math.min(1, Math.sqrt(h)))
}

export function distance(a, b) { return EARTH_RADIUS * centralAngle(a, b) }

export function pointBetween(a, b, fraction) {
  const share = Math.min(Math.max(fraction, 0), 1)
  const angle = centralAngle(a, b)
  if (!(angle > 1e-9)) return a
  const wa = Math.sin((1 - share) * angle) / Math.sin(angle)
  const wb = Math.sin(share * angle) / Math.sin(angle)
  const v = (p) => [Math.cos(rad(p[0])) * Math.cos(rad(p[1])), Math.cos(rad(p[0])) * Math.sin(rad(p[1])), Math.sin(rad(p[0]))]
  const va = v(a), vb = v(b)
  const x = wa * va[0] + wb * vb[0], y = wa * va[1] + wb * vb[1], z = wa * va[2] + wb * vb[2]
  return [deg(Math.atan2(z, Math.sqrt(x * x + y * y))), deg(Math.atan2(y, x))]
}

// MARK: The schedule's flight plan (spec §4)

export function makePlan(departure, arrival, length) {
  const block = arrival - departure
  if (!(block > 0)) return null
  const hasAllowances = block >= TAXI_OUT + TAXI_IN + SHORTEST_CRUISE
  const takeoff = hasAllowances ? departure + TAXI_OUT : departure
  const touchdown = hasAllowances ? arrival - TAXI_IN : arrival
  const inAir = touchdown - takeoff
  let cruise = null
  if (length > DESCENT_DISTANCE && inAir > DESCENT_TIME) {
    const speed = (length - DESCENT_DISTANCE) / (inAir - DESCENT_TIME)
    if (speed > DESCENT_SPEED) cruise = speed
  }
  // A short leg's one speed. A leg that goes nowhere has none of its own: the descent's stands in.
  const steady = cruise === null ? (length / inAir > 0 ? length / inAir : DESCENT_SPEED) : null
  return { departure, arrival, takeoff, touchdown, length, cruise, steady }
}

export const planSpeed = (plan) => plan.cruise ?? plan.steady

export function timeToFly(plan, far) {
  const d = Math.max(far, 0)
  if (plan.steady !== null) return d / plan.steady
  return d <= DESCENT_DISTANCE ? d / DESCENT_SPEED : DESCENT_TIME + (d - DESCENT_DISTANCE) / plan.cruise
}

export function distanceLeft(plan, time) {
  const t = Math.max(time, 0)
  if (plan.steady !== null) return t * plan.steady
  return t <= DESCENT_TIME ? t * DESCENT_SPEED : DESCENT_DISTANCE + (t - DESCENT_TIME) * plan.cruise
}

// MARK: A flight as partner_live answers it, read into seconds

export function readFlight(wire) {
  if (!wire) return null
  const fix = wire.fix && {
    at: [wire.fix.lat, wire.fix.lon], onGround: wire.fix.on_ground, seenAt: wire.fix.seen_at / 1000,
  }
  const trail = wire.trail.map((p) => ({ time: p[0] / 1000, at: [p[1], p[2]] }))
  // Oldest first, keeping the door's order between points of one time.
  const sorted = trail.map((p, i) => [p, i]).sort((a, b) => a[0].time - b[0].time || a[1] - b[1]).map((e) => e[0])
  return { state: wire.state, fix, landedAt: wire.landed_at === null ? null : wire.landed_at / 1000, trail: sorted }
}

// MARK: The path (spec §6.1)

export function makePath(origin, destination, flight) {
  const seen = flight ? flight.trail.map((p) => ({ at: p.at, time: p.time })) : []
  const last = seen[seen.length - 1]
  if (flight?.fix && !flight.fix.onGround && (!last || flight.fix.seenAt > last.time)) {
    seen.push({ at: flight.fix.at, time: flight.fix.seenAt })
  }
  if (seen.length === 0) {
    const length = distance(origin, destination)
    return { origin, destination, isReal: false, length, flown: 0, knots: [],
             stretches: [{ from: origin, to: destination, kind: 'planned', start: 0, length }] }
  }
  const stretches = []
  const knots = []
  let along = 0
  const add = (from, to, kind) => {
    const length = distance(from, to)
    stretches.push({ from, to, kind, start: along, length })
    along += length
  }
  add(origin, seen[0].at, distance(origin, seen[0].at) > FIRST_POINT_RADIUS ? 'unseen' : 'seen')
  knots.push({ time: seen[0].time, along })
  for (let i = 1; i < seen.length; i++) {
    add(seen[i - 1].at, seen[i].at, seen[i].time - seen[i - 1].time > UNSEEN_GAP ? 'unseen' : 'seen')
    knots.push({ time: seen[i].time, along })
  }
  const flownBeforeLanding = along
  const final = seen[seen.length - 1]
  const landed = flight.state === 'landed'
  if (landed) {
    const landedAt = Math.max(flight.landedAt ?? flight.fix?.seenAt ?? final.time, final.time)
    add(final.at, destination, landedAt - final.time > UNSEEN_GAP ? 'unseen' : 'seen')
    knots.push({ time: landedAt, along })
  } else {
    add(final.at, destination, 'planned')
  }
  return { origin, destination, isReal: true, length: along, flown: landed ? along : flownBeforeLanding, knots, stretches,
           landed, firstPointAlong: knots[0].along }
}

export function pointAt(path, far) {
  const d = Math.min(Math.max(far, 0), path.length)
  for (const s of path.stretches) {
    if (d <= s.start + s.length) {
      return s.length > 0 ? pointBetween(s.from, s.to, (d - s.start) / s.length) : s.from
    }
  }
  return path.destination
}

// MARK: The record (spec §7.2)

export function makeRecord(path, plan) {
  if (!path.isReal) return null
  const knots = path.knots
  const first = knots[0], last = knots[knots.length - 1]
  const touchdown = path.landed ? last.time : last.time + timeToFly(plan, path.length - last.along)
  // The takeoff, when the first point was seen close enough to the airport to tell (spec §7.1).
  const takeoff = first.along <= FIRST_POINT_RADIUS ? first.time : null
  return { path, plan, knots, touchdown, takeoff }
}

export function alongAt(record, time) {
  const { path, plan, knots } = record
  const first = knots[0], last = knots[knots.length - 1]
  if (time <= first.time) return Math.max(0, first.along - (first.time - time) * planSpeed(plan))
  if (time >= last.time) {
    if (path.landed) return path.length
    return Math.min(Math.max(path.length - distanceLeft(plan, record.touchdown - time), last.along), path.length)
  }
  for (let i = 1; i < knots.length; i++) {
    if (time < knots[i].time) {
      const a = knots[i - 1], b = knots[i]
      return a.along + (b.along - a.along) * (time - a.time) / (b.time - a.time)
    }
  }
  return last.along
}

export function timeAt(record, far) {
  const { path, plan, knots } = record
  const d = Math.min(Math.max(far, 0), path.length)
  const first = knots[0], last = knots[knots.length - 1]
  if (d <= first.along) return first.time - (first.along - d) / planSpeed(plan)
  if (d >= last.along) return path.landed ? last.time : record.touchdown - timeToFly(plan, path.length - d)
  for (let i = 1; i < knots.length; i++) {
    if (d <= knots[i].along) {
      const a = knots[i - 1], b = knots[i]
      return b.along > a.along ? a.time + (b.time - a.time) * (d - a.along) / (b.along - a.along) : a.time
    }
  }
  return last.time
}

// MARK: Progress (spec §5)

export function roundHalfAway(x) { return Math.sign(x) * Math.floor(Math.abs(x) + 0.5) || 0 }

export function minutesText(minutes) {
  const hours = Math.floor(minutes / 60), rest = minutes % 60
  if (hours === 0) return `${rest} min`
  if (rest === 0) return `${hours} h`
  return `${hours} h ${rest} min`
}

export function labelFor(phase, gap) {
  if (gap === null) return null
  const size = Math.abs(gap)
  const onSchedule = size <= ON_SCHEDULE_MINUTES
  switch (phase) {
    case 'inAir': return onSchedule ? 'On schedule' : `${minutesText(size)} ${gap > 0 ? 'ahead' : 'behind'}`
    case 'estimated': return onSchedule ? 'On schedule' : `About ${minutesText(size)} ${gap > 0 ? 'ahead' : 'behind'}`
    case 'onGround': return onSchedule ? 'Still on the ground' : `Still on the ground · ${minutesText(size)} behind`
    case 'landed': return onSchedule ? 'Landed on time' : `Landed ${minutesText(size)} ${gap > 0 ? 'early' : 'late'}`
    default: return null
  }
}

export function progress(plan, path, record, flight, now) {
  let phase = 'notLive'
  const fix = flight?.fix
  if (fix) {
    const isFresh = now - fix.seenAt <= FRESH
    if (flight.state === 'landed') phase = 'landed'
    else if (flight.state === 'airborne') phase = isFresh ? 'inAir' : 'estimated'
    else if (flight.state === 'ground' && isFresh) {
      phase = distance(fix.at, path.origin) <= AIRPORT_RADIUS ? 'onGround' : 'elsewhere'
    }
  }
  let touchdown = null
  if (phase === 'inAir' || phase === 'estimated') touchdown = fix.seenAt + timeToFly(plan, distance(fix.at, path.destination))
  if (phase === 'onGround' && now >= plan.takeoff) touchdown = now + (plan.touchdown - plan.takeoff)
  // A landed flight's touchdown is its record's, where it has one, so the two can't disagree.
  if (phase === 'landed') touchdown = record ? record.touchdown : (flight.landedAt ?? fix.seenAt)
  const liveArrival = touchdown === null ? null : touchdown + (plan.arrival - plan.touchdown)
  const gap = touchdown === null ? null : roundHalfAway((plan.touchdown - touchdown) / 60)

  let planeAlong = null, plane = null
  if (phase === 'inAir') { planeAlong = path.flown; plane = fix.at }
  if (phase === 'estimated') {
    planeAlong = Math.min(Math.max(path.length - distanceLeft(plan, touchdown - now), path.flown), path.length)
    plane = pointAt(path, planeAlong)
  }
  if (phase === 'landed') { planeAlong = path.length; plane = path.destination }
  if (phase === 'onGround') { planeAlong = 0; plane = fix.at }
  if (phase === 'elsewhere') plane = fix.at

  let ghostAlong = null
  if (phase === 'inAir' || phase === 'estimated' || phase === 'onGround') {
    if (now < plan.takeoff) ghostAlong = 0
    else ghostAlong = Math.max(0, path.length - distanceLeft(plan, plan.touchdown - now))
  }

  // The leg's real times (spec §7.1).
  const takeoff = record?.takeoff ?? null
  const earlyStart = takeoff === null ? null : takeoff - (plan.takeoff - plan.departure)
  const start = earlyStart !== null && earlyStart < plan.departure ? earlyStart : plan.departure
  const end = liveArrival ?? plan.arrival

  return { phase, touchdown, liveArrival, gap, label: labelFor(phase, gap), planeAlong, plane, ghostAlong,
           ghost: ghostAlong === null ? null : pointAt(path, ghostAlong), start, end }
}

// MARK: The window (spec §10.2, partner-api.md)

export function isWindowOpen(departure, arrival, flight, now) {
  if (now < departure - WINDOW_OPENS_BEFORE) return false
  if (flight?.state === 'landed') return false
  if (now < arrival + WINDOW_CLOSES_AFTER) return true
  return flight?.state === 'airborne' && !!flight.fix && flight.fix.seenAt > now - WINDOW_KEEPS_FOR
    && now < arrival + WINDOW_ENDS_AFTER
}
```

- [x] **Step 2: Write the generator.** Create `scripts/live-cases/generate.mjs`:

```js
// Writes CrewluvTests/Fixtures/TripMap/live-cases.json from the reference in live.mjs.
// Run from anywhere: node scripts/live-cases/generate.mjs
import { writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import * as live from './live.mjs'

const { NM } = live
const t = (iso) => Date.parse(iso) / 1000
const iso = (seconds) => (seconds === null ? null : new Date(Math.round(seconds * 1000)).toISOString())
const round = (x, places) => (x === null ? null : Number(x.toFixed(places)))
const nm = (metres) => round(metres === null ? null : metres / NM, 3)
const place = (p) => (p === null ? null : [round(p[0], 5), round(p[1], 5)])

const airports = {
  SDF: [38.1744, -85.736],
  PHL: [39.8719, -75.2411],
  CGN: [50.8659, 7.1427],
  CVG: [39.0488, -84.6678],
  PIT: [40.4915, -80.2329],
}

// MARK: Made-up flights

/// Where a plane is `seconds` after leaving the first place of `route` at `knots`, and how high.
function flown(route, knots, seconds) {
  let left = knots * NM / 3600 * seconds
  for (let i = 1; i < route.length; i++) {
    const leg = live.distance(route[i - 1], route[i])
    if (left <= leg) return live.pointBetween(route[i - 1], route[i], leg > 0 ? left / leg : 0)
    left -= leg
  }
  return route[route.length - 1]
}

function routeLength(route) {
  let total = 0
  for (let i = 1; i < route.length; i++) total += live.distance(route[i - 1], route[i])
  return total
}

/// A trail point as the door answers it: [ms, lat, lon, ft], the place to a millionth of a degree.
function trailPoint(route, knots, offAt, time, feet) {
  const at = flown(route, knots, time - offAt)
  return [Math.round(time * 1000), round(at[0], 6), round(at[1], 6), feet]
}

function airFix(route, knots, offAt, time, feet, extra = {}) {
  const at = flown(route, knots, time - offAt)
  return { lat: round(at[0], 6), lon: round(at[1], 6), altitude_ft: feet, ground_speed_kt: knots, track_deg: 80,
           on_ground: false, registration: 'N370UP', type_code: 'B763', seen_at: Math.round(time * 1000), ...extra }
}

function groundFix(at, time) {
  return { lat: at[0], lon: at[1], altitude_ft: null, ground_speed_kt: 0, track_deg: null, on_ground: true,
           registration: 'N370UP', type_code: 'B763', seen_at: Math.round(time * 1000) }
}

function wire(legID, callsign, state, fix, landedAt, trail) {
  return { leg_id: legID, callsign, state, fix, landed_at: landedAt === null ? null : Math.round(landedAt * 1000),
           trail, trail_count: trail.length }
}

// MARK: What a case expects

function expectedPath(path) {
  const total = (kind) => nm(path.stretches.filter((s) => s.kind === kind).reduce((sum, s) => sum + s.length, 0))
  return { isReal: path.isReal, lengthNm: nm(path.length), flownNm: nm(path.flown),
           stretchKinds: path.stretches.map((s) => s.kind),
           seenNm: total('seen'), unseenNm: total('unseen'), plannedNm: total('planned') }
}

function expectedMoment(plan, path, record, flight, at, note) {
  const p = live.progress(plan, path, record, flight, t(at))
  return { at: iso(t(at)), note, phase: p.phase, touchdown: iso(p.touchdown), liveArrival: iso(p.liveArrival),
           gapMinutes: p.gap, label: p.label, planeAlongNm: nm(p.planeAlong), plane: place(p.plane),
           ghostAlongNm: nm(p.ghostAlong), ghost: place(p.ghost), start: iso(p.start), end: iso(p.end) }
}

function expectedRecord(record, places, distancesNm) {
  if (!record) return null
  return {
    takeoff: iso(record.takeoff), touchdown: iso(record.touchdown),
    places: places.map((at) => {
      const along = live.alongAt(record, t(at))
      return { at: iso(t(at)), alongNm: nm(along), point: place(live.pointAt(record.path, along)) }
    }),
    times: distancesNm.map((d) => ({ alongNm: d, at: iso(live.timeAt(record, d * NM)) })),
  }
}

function flightCase({ name, note, from, to, departure, arrival, flight, moments, places = [], distancesNm = [] }) {
  const origin = airports[from], destination = airports[to]
  const plan = live.makePlan(t(departure), t(arrival), live.distance(origin, destination))
  const read = live.readFlight(flight)
  const path = live.makePath(origin, destination, read)
  const record = live.makeRecord(path, plan)
  return { name, note, from, to, departure: iso(t(departure)), arrival: iso(t(arrival)), flight,
           path: expectedPath(path),
           moments: moments.map(([at, momentNote]) => expectedMoment(plan, path, record, read, at, momentNote)),
           record: expectedRecord(record, places, distancesNm) }
}

// MARK: The plans

function planCase(name, note, from, to, departure, arrival, distancesNm, minutes) {
  const length = live.distance(airports[from], airports[to])
  const plan = live.makePlan(t(departure), t(arrival), length)
  return {
    name, note, from, to, departure: iso(t(departure)), arrival: iso(t(arrival)),
    lengthNm: nm(length), takeoff: iso(plan.takeoff), touchdown: iso(plan.touchdown),
    isShort: plan.steady !== null, speedKt: round(live.planSpeed(plan) * 3600 / NM, 3),
    timeToFly: distancesNm.map((d) => ({ distanceNm: d, seconds: round(live.timeToFly(plan, d * NM), 3) })),
    distanceLeft: minutes.map((m) => ({ minutes: m, distanceNm: nm(live.distanceLeft(plan, m * 60)) })),
  }
}

const plans = [
  planCase('a long leg', 'Louisville to Cologne in 8 h: 15 min out and 7 in leave 7 h 38 min in the air. The last 120 nm take 25.7 min at 280 kt, and the rest is one faster speed.',
    'SDF', 'CGN', '2026-11-13T18:00:00Z', '2026-11-14T02:00:00Z', [-10, 0, 60, 120, 121, 1000, 3800, 4200], [-5, 0, 10, 25, 26, 240, 458, 500]),
  planCase('a leg of an hour and three quarters', 'Louisville to Philadelphia: the descent rule still applies, with a cruise a little over 400 kt.',
    'SDF', 'PHL', '2026-11-13T12:00:00Z', '2026-11-13T13:45:00Z', [0, 100, 120, 300, 600], [0, 20, 30, 83, 100]),
  planCase('a short leg', 'Louisville to Cincinnati is under 120 nm, so it has one steady speed from takeoff to touchdown.',
    'SDF', 'CVG', '2026-11-13T12:00:00Z', '2026-11-13T12:45:00Z', [0, 30, 100], [0, 10, 23, 30]),
  planCase('a leg under both allowances', 'A 30-minute block is too short for the taxi allowances, so the plane flies from gate to gate at one speed.',
    'SDF', 'CVG', '2026-11-13T12:00:00Z', '2026-11-13T12:30:00Z', [0, 30, 100], [0, 15, 30, 40]),
  planCase('a block of exactly 32 minutes', 'Just long enough for both allowances and the shortest cruise: 15 min out, 7 in, and 10 in the air.',
    'SDF', 'CVG', '2026-11-13T12:00:00Z', '2026-11-13T12:32:00Z', [0, 30, 72], [0, 5, 10]),
  planCase('a slow leg', 'Louisville to Philadelphia in 3 h: the cruise would be under 280 kt, so the whole leg is one steady speed.',
    'SDF', 'PHL', '2026-11-13T12:00:00Z', '2026-11-13T15:00:00Z', [0, 120, 300, 600], [0, 25, 158, 170]),
  planCase('a leg that goes nowhere', 'The same airport at both ends has no speed of its own, so 280 kt stands in.',
    'SDF', 'SDF', '2026-11-13T12:00:00Z', '2026-11-13T13:00:00Z', [0, 28], [0, 6]),
]

// MARK: The flights

// Louisville to Philadelphia by way of a point north of the straight line.
const toPhiladelphia = [airports.SDF, [39.6, -81.0], airports.PHL]
const offAt = t('2026-11-13T12:04:34Z')
const phlKnots = 430
const phlTimes = []
for (let time = t('2026-11-13T12:05:00Z'); time <= t('2026-11-13T12:41:00Z'); time += 120) phlTimes.push(time)
const phlTrail = phlTimes.map((time, i) => trailPoint(toPhiladelphia, phlKnots, offAt, time, Math.min(35000, 2000 + i * 4000)))
const phlLandsAt = offAt + routeLength(toPhiladelphia) / (phlKnots * NM / 3600)
const phlWholeTimes = []
for (let time = t('2026-11-13T12:05:00Z'); time < phlLandsAt; time += 120) phlWholeTimes.push(time)
const phlWholeTrail = phlWholeTimes.map((time, i) =>
  trailPoint(toPhiladelphia, phlKnots, offAt, time, Math.max(3000, Math.min(35000, 2000 + i * 4000, (phlWholeTimes.length - i) * 3000))))
const phlLandedAt = Math.ceil(phlLandsAt)

// Louisville to Philadelphia again, leaving early and to the west before turning back: a path well longer than the plan's.
const theLongWayRound = [airports.SDF, [38.1, -86.6], [38.9, -86.0], airports.PHL]
const earlyOffAt = t('2026-11-13T12:02:00Z')
const earlyTimes = []
for (let time = t('2026-11-13T12:03:00Z'); time <= t('2026-11-13T12:13:00Z'); time += 120) earlyTimes.push(time)
const earlyTrail = earlyTimes.map((time, i) => trailPoint(theLongWayRound, 300, earlyOffAt, time, 3000 + i * 3000))

// Louisville to Philadelphia, off ten minutes after the plan's takeoff and seen from the start.
const lateOffAt = t('2026-11-13T12:24:34Z')
const lateTimes = []
for (let time = t('2026-11-13T12:25:00Z'); time <= t('2026-11-13T12:41:00Z'); time += 120) lateTimes.push(time)
const lateTrail = lateTimes.map((time, i) => trailPoint(toPhiladelphia, phlKnots, lateOffAt, time, Math.min(35000, 2000 + i * 4000)))

// Louisville to Cincinnati on a 30-minute block, off two minutes before it.
const toCincinnati = [airports.SDF, airports.CVG]
const hopOffAt = t('2026-11-13T11:57:40Z')
const hopTimes = []
for (let time = t('2026-11-13T11:58:00Z'); time <= t('2026-11-13T12:08:00Z'); time += 120) hopTimes.push(time)
const hopTrail = hopTimes.map((time, i) => trailPoint(toCincinnati, 200, hopOffAt, time, 2000 + i * 1500))

// The ahead flight's points ten minutes apart, as the door might send them: out of order, and two with one time.
const tenMinutes = ['2026-11-13T12:05:00Z', '2026-11-13T12:15:00Z', '2026-11-13T12:25:00Z', '2026-11-13T12:35:00Z']
  .map((at) => trailPoint(toPhiladelphia, phlKnots, offAt, t(at), 33000))
const secondAtOnce = trailPoint(toPhiladelphia, phlKnots, offAt, t('2026-11-13T12:25:10Z'), 33000)
secondAtOnce[0] = tenMinutes[2][0]
const outOfOrder = [tenMinutes[0], tenMinutes[2], tenMinutes[1], tenMinutes[3], secondAtOnce]

// Louisville to Cologne, taking off 25 minutes late, first seen well out, and unseen over the ocean.
const toCologne = [airports.SDF, [43.5, -70.0], [49.5, -52.0], [54.0, -20.0], airports.CGN]
const cgnOffAt = t('2026-11-13T18:40:00Z')
const cgnKnots = 480
const cgnTimes = []
for (let time = t('2026-11-13T18:52:00Z'); time <= t('2026-11-13T20:44:00Z'); time += 480) cgnTimes.push(time)
for (let time = t('2026-11-13T23:40:00Z'); time <= t('2026-11-14T00:12:00Z'); time += 480) cgnTimes.push(time)
const cgnTrail = cgnTimes.map((time) => trailPoint(toCologne, cgnKnots, cgnOffAt, time, 37000))

const flights = [
  flightCase({
    name: 'ahead, in the air', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Off the ground about ten minutes before the plan, by way of a point north of the straight line, with a trail point every 2 minutes and a fix 40 s after the last. The first point is under 30 nm out, so its time is the takeoff and the leg starts early. The landing estimate is the fix plus the plan\'s time for the straight distance left.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, offAt, t('2026-11-13T12:41:40Z'), 35000), null, phlTrail),
    moments: [
      ['2026-11-13T12:41:50Z', 'The fix is 10 s old: in the air, at the fix. The ghost is behind the real plane.'],
      ['2026-11-13T12:43:40Z', 'The fix is exactly 2 minutes old: still in the air.'],
      ['2026-11-13T12:45:00Z', 'The fix is over 2 minutes old: estimated, flying the plan from the fix. The estimate holds still.'],
      ['2026-11-13T13:40:00Z', 'Past the estimated touchdown with no landing seen: the estimated plane is at Philadelphia, and the leg has ended at the live arrival.'],
    ],
    places: ['2026-11-13T12:00:00Z', '2026-11-13T12:04:50Z', '2026-11-13T12:20:00Z', '2026-11-13T12:41:20Z', '2026-11-13T12:50:00Z', '2026-11-13T14:00:00Z'],
    distancesNm: [0, 1, 100, 300, 500],
  }),
  flightCase({
    name: 'off early and the long way round', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'In the air 13 minutes before the plan\'s takeoff, heading west before turning back, so its path is longer than the straight distance. Until the plan\'s takeoff the ghost waits at Louisville. Just after it, the ghost is already as far along the path as the path is longer than the plan.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(theLongWayRound, 300, earlyOffAt, t('2026-11-13T12:13:30Z'), 18000), null, earlyTrail),
    moments: [
      ['2026-11-13T12:14:00Z', 'A minute before the plan\'s takeoff: the ghost is still at the airport.'],
      ['2026-11-13T12:15:20Z', 'Twenty seconds after it: the ghost has jumped along the path.'],
    ],
    places: ['2026-11-13T12:02:30Z', '2026-11-13T12:10:00Z'],
    distancesNm: [20],
  }),
  flightCase({
    name: 'off late, and seen from the start', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Its first point is 3 nm out at 12:25, ten minutes after the plan\'s takeoff. The takeoff is known and late, and a late departure doesn\'t move the leg: its start stays at 12:00.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, lateOffAt, t('2026-11-13T12:41:40Z'), 35000), null, lateTrail),
    moments: [['2026-11-13T12:41:50Z', 'In the air, with the start where the schedule has it.']],
    places: ['2026-11-13T12:20:00Z', '2026-11-13T12:30:00Z'],
    distancesNm: [50],
  }),
  flightCase({
    name: 'a short hop, off two minutes early', from: 'SDF', to: 'CVG', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T12:30:00Z',
    note: 'A 30-minute block has no taxi allowances and one steady speed. So the leg starts at the takeoff itself, and the live arrival is the touchdown.',
    flight: wire('leg-cvg', 'UPS1236', 'airborne', airFix(toCincinnati, 200, hopOffAt, t('2026-11-13T12:08:30Z'), 9000), null, hopTrail),
    moments: [['2026-11-13T12:08:40Z', 'In the air: the start is the takeoff, and the end is the touchdown.']],
    places: ['2026-11-13T11:57:50Z', '2026-11-13T12:05:00Z'],
    distancesNm: [10, 60],
  }),
  flightCase({
    name: 'in the air, with no trail point yet', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'A fix in the air and an empty trail. The path is real from the fix: Louisville to the fix, then the great circle on. The fix is under 30 nm out, so its time is the takeoff.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, t('2026-11-13T12:15:30Z'), t('2026-11-13T12:16:10Z'), 2500), null, []),
    moments: [['2026-11-13T12:16:20Z', 'In the air, at the fix.']],
    places: ['2026-11-13T12:16:00Z', '2026-11-13T12:30:00Z'],
    distancesNm: [2],
  }),
  flightCase({
    name: 'the fix is the last trail point', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Right after a trail point is written, the fix has its place and its time. It adds nothing to the path: one stretch fewer than the ahead flight, whose fix is 40 s newer.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, offAt, t('2026-11-13T12:41:00Z'), 35000), null, phlTrail),
    moments: [['2026-11-13T12:41:30Z', 'In the air, at the last trail point.']],
  }),
  flightCase({
    name: 'points out of order, ten minutes apart, and two at once', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'The trail comes as 12:05, 12:25, 12:15, 12:35 and a second point stamped 12:25 a little further on. It\'s put in order of time, with the two of one time in the order they came. Points exactly 10 minutes apart are seen: only more than 10 is unseen. At 12:25 the plane is at the second of the two.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, offAt, t('2026-11-13T12:35:20Z'), 33000), null, outOfOrder),
    moments: [['2026-11-13T12:35:30Z', 'In the air.']],
    places: ['2026-11-13T12:10:00Z', '2026-11-13T12:25:00Z', '2026-11-13T12:30:00Z'],
    distancesNm: [100, 146.5],
  }),
  flightCase({
    name: 'behind, with a late first point and an unseen ocean', from: 'SDF', to: 'CGN', departure: '2026-11-13T18:00:00Z', arrival: '2026-11-14T02:00:00Z',
    note: 'Off 25 minutes after the plan and slower than it. The first point is 96 nm out, so the join from Louisville is unseen and the takeoff isn\'t known: the leg\'s start stays. Nobody saw it for nearly 3 hours over the ocean: one unseen join. The ghost is ahead of the real plane, and the leg ends late.',
    flight: wire('leg-cgn', 'UPS207', 'airborne', airFix(toCologne, cgnKnots, cgnOffAt, t('2026-11-14T00:12:30Z'), 37000), null, cgnTrail),
    moments: [
      ['2026-11-14T00:13:00Z', 'In the air and behind: the ghost is further along the path than the real plane.'],
      ['2026-11-14T00:20:00Z', 'Estimated: "About" joins the label.'],
    ],
    places: ['2026-11-13T18:30:00Z', '2026-11-13T18:45:00Z', '2026-11-13T22:00:00Z', '2026-11-14T00:12:15Z'],
    distancesNm: [50, 500, 1500, 2700],
  }),
  flightCase({
    name: 'on the ground before the plan\'s takeoff', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Seen on the ground half a mile from Louisville\'s airport. Before 12:15 there\'s no estimate and no label, and the schedule stands. A ground fix over 2 minutes old isn\'t live.',
    flight: wire('leg-phl', 'UPS1234', 'ground', groundFix([38.18, -85.73], t('2026-11-13T12:09:30Z')), null, []),
    moments: [
      ['2026-11-13T12:10:00Z', 'On the ground, before the plan\'s takeoff: the ghost waits at the airport too.'],
      ['2026-11-13T12:12:00Z', 'The ground fix is 2.5 minutes old: not live.'],
    ],
  }),
  flightCase({
    name: 'still on the ground just after the plan\'s takeoff', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Three minutes after the plan\'s takeoff, touchdown is now plus the plan\'s 83 minutes in the air, and the label has no number yet.',
    flight: wire('leg-phl', 'UPS1234', 'ground', groundFix([38.18, -85.73], t('2026-11-13T12:17:45Z')), null, []),
    moments: [['2026-11-13T12:18:00Z', 'Three minutes late: within 5, so just "Still on the ground".']],
  }),
  flightCase({
    name: 'still on the ground twenty minutes after', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Twenty minutes after the plan\'s takeoff the label counts from it, and the leg\'s end has slid 20 minutes later.',
    flight: wire('leg-phl', 'UPS1234', 'ground', groundFix([38.18, -85.73], t('2026-11-13T12:34:50Z')), null, []),
    moments: [['2026-11-13T12:35:00Z', 'Twenty minutes late.']],
  }),
  flightCase({
    name: 'landed, seen all the way', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'The same flight, followed to Philadelphia and seen on the ground there. Its path ends at the airport with nothing planned, the landing is when it was first seen down, and the leg ends 7 minutes after that.',
    flight: wire('leg-phl', 'UPS1234', 'landed', groundFix([39.87, -75.24], phlLandedAt + 90), phlLandedAt, phlWholeTrail),
    moments: [['2026-11-13T13:30:00Z', 'Landed: early, with no "about".']],
    places: ['2026-11-13T12:30:00Z', '2026-11-13T13:30:00Z'],
    distancesNm: [200, 480],
  }),
  flightCase({
    name: 'landed, with the approach unseen', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Seen to 12:41, then not again until it was on the ground at Philadelphia: the last join is unseen.',
    flight: wire('leg-phl', 'UPS1234', 'landed', groundFix([39.87, -75.24], phlLandedAt + 90), phlLandedAt, phlTrail),
    moments: [['2026-11-13T13:30:00Z', 'Landed.']],
    places: ['2026-11-13T13:00:00Z'],
    distancesNm: [400],
  }),
  flightCase({
    name: 'landed, with a landing time before its last point', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Crewlu Cloud never sends this, and a record can\'t run backwards: the landing counts as no earlier than the last point, 12:41, for the record and the estimate alike.',
    flight: wire('leg-phl', 'UPS1234', 'landed', groundFix([39.87, -75.24], t('2026-11-13T12:42:00Z')), t('2026-11-13T12:40:00Z'), phlTrail),
    moments: [['2026-11-13T13:00:00Z', 'Landed at 12:41, not 12:40.']],
    places: ['2026-11-13T12:40:30Z', '2026-11-13T12:41:00Z'],
    distancesNm: [400],
  }),
  flightCase({
    name: 'landed, and never seen in the air', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Landed with an empty trail: there\'s no real path and no record, the real plane is at Philadelphia, and the leg ends 7 minutes after the landing.',
    flight: wire('leg-phl', 'UPS1234', 'landed', groundFix([39.87, -75.24], t('2026-11-13T13:21:30Z')), t('2026-11-13T13:20:00Z'), []),
    moments: [['2026-11-13T13:30:00Z', 'Landed, on the great circle.']],
  }),
  flightCase({
    name: 'on the ground somewhere else', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Seen on the ground at Pittsburgh, which is neither airport: a diversion. The real plane shows where it is, with no estimate, label or ghost.',
    flight: wire('leg-phl', 'UPS1234', 'ground', groundFix(airports.PIT, t('2026-11-13T13:20:00Z')), null, []),
    moments: [['2026-11-13T13:21:00Z', 'Elsewhere.']],
  }),
  flightCase({
    name: 'waiting to be seen', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'CrewLu Cloud is watching, and nobody has seen it: the schedule\'s plane alone.',
    flight: wire('leg-phl', 'UPS1234', 'waiting', null, null, []),
    moments: [['2026-11-13T12:30:00Z', 'Not live.']],
  }),
  flightCase({
    name: 'no live data', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'The answer has no flight for the leg.',
    flight: null,
    moments: [['2026-11-13T12:30:00Z', 'Not live.']],
  }),
]

// MARK: The labels, the rounding and the window

const labelCase = (phase, gapMinutes) => ({ phase, gapMinutes, label: live.labelFor(phase, gapMinutes) })
const labels = [
  labelCase('inAir', 0), labelCase('inAir', 5), labelCase('inAir', -5), labelCase('inAir', 6), labelCase('inAir', -6),
  labelCase('inAir', 12), labelCase('inAir', -20), labelCase('inAir', 75), labelCase('inAir', -120),
  labelCase('estimated', 5), labelCase('estimated', -5), labelCase('estimated', 6), labelCase('estimated', 12),
  labelCase('estimated', -20), labelCase('estimated', -6),
  labelCase('onGround', null), labelCase('onGround', 0), labelCase('onGround', -5), labelCase('onGround', -6),
  labelCase('onGround', -20), labelCase('onGround', -95),
  labelCase('landed', 8), labelCase('landed', -15), labelCase('landed', 5), labelCase('landed', -5), labelCase('landed', 6),
  labelCase('landed', -61),
  labelCase('elsewhere', null), labelCase('notLive', null),
]

const gaps = [0, 29, 30, 89, 90, 329, 330, -29, -30, -90, -329, -330].map((seconds) =>
  ({ aheadSeconds: seconds, gapMinutes: live.roundHalfAway(seconds / 60) }))

const windowCase = (name, at, flight) => {
  const departure = t('2026-11-13T18:00:00Z'), arrival = t('2026-11-14T02:00:00Z')
  return { name, departure: iso(departure), arrival: iso(arrival), at: iso(t(at)), flight,
           isOpen: live.isWindowOpen(departure, arrival, live.readFlight(flight), t(at)) }
}
const cologneFix = (time) => airFix(toCologne, cgnKnots, cgnOffAt, t(time), 37000)
const windows = [
  windowCase('31 minutes before the departure', '2026-11-13T17:29:00Z', null),
  windowCase('30 minutes before the departure', '2026-11-13T17:30:00Z', null),
  windowCase('in the middle, never seen', '2026-11-13T22:00:00Z', wire('leg-cgn', 'UPS207', 'waiting', null, null, [])),
  windowCase('landed, well before the arrival', '2026-11-14T01:30:00Z',
    wire('leg-cgn', 'UPS207', 'landed', groundFix(airports.CGN, t('2026-11-14T01:20:00Z')), t('2026-11-14T01:19:00Z'), [])),
  windowCase('a second under 2 hours after the arrival', '2026-11-14T03:59:59Z', null),
  windowCase('2 hours after the arrival', '2026-11-14T04:00:00Z', null),
  windowCase('3 hours after, in the air with a fix 10 minutes old', '2026-11-14T05:00:00Z',
    wire('leg-cgn', 'UPS207', 'airborne', cologneFix('2026-11-14T04:50:00Z'), null, [])),
  windowCase('3 hours after, in the air with a fix 31 minutes old', '2026-11-14T05:00:00Z',
    wire('leg-cgn', 'UPS207', 'airborne', cologneFix('2026-11-14T04:29:00Z'), null, [])),
  windowCase('3 hours after, in the air with a fix exactly 30 minutes old', '2026-11-14T05:00:00Z',
    wire('leg-cgn', 'UPS207', 'airborne', cologneFix('2026-11-14T04:30:00Z'), null, [])),
  windowCase('3 hours after, on the ground with a new fix', '2026-11-14T05:00:00Z',
    wire('leg-cgn', 'UPS207', 'ground', groundFix(airports.PIT, t('2026-11-14T04:59:00Z')), null, [])),
  windowCase('a minute under 12 hours after, still in the air', '2026-11-14T13:59:00Z',
    wire('leg-cgn', 'UPS207', 'airborne', cologneFix('2026-11-14T13:58:00Z'), null, [])),
  windowCase('12 hours after, still in the air', '2026-11-14T14:00:00Z',
    wire('leg-cgn', 'UPS207', 'airborne', cologneFix('2026-11-14T13:59:00Z'), null, [])),
]

const cases = {
  about: 'The real plane (Crewluve moving map Stage 3 spec §4 to §7, §10.2). Made by a reference written apart from the app and the website, and run by both: the app\'s FlightPlanTests, FlightPathTests, FlightRecordTests, LiveProgressTests, LiveLabelTests and LiveWindowTests, and the website\'s tests. Change both copies together. Every `at`, and every time in an answer, is an ISO 8601 time with milliseconds. A `flight` is one entry of partner_live\'s `flights`, exactly as the door answers it, with times in milliseconds since 1970, or null where the door answers none. Distances are nautical miles of 1,852 m along a sphere of radius 6,371,008.8 m, to the nearest thousandth; places are [latitude, longitude]. A gap is the plan\'s touchdown minus the estimated one in minutes, rounded to the nearest with halves away from zero; ahead is positive. Compare distances to 0.01 nm, times to 0.05 s and places to 0.0001 of a degree.',
  constants: {
    taxiOutMinutes: 15, taxiInMinutes: 7, shortestCruiseMinutes: 10, descentDistanceNm: 120, descentSpeedKt: 280,
    freshSeconds: live.FRESH, airportRadiusNm: 10, onScheduleMinutes: live.ON_SCHEDULE_MINUTES,
    unseenGapMinutes: 10, firstPointRadiusNm: 30,
    windowOpensMinutesBefore: 30, windowClosesHoursAfter: 2, windowKeepsMinutes: 30, windowEndsHoursAfter: 12,
  },
  airports,
  plans,
  flights,
  labels,
  gaps,
  windows,
}

const text = JSON.stringify(cases, null, 2)
  // One line for each place and each trail point, as the other shared cases are written.
  .replace(/\[\s*(-?[\d.]+),\s*(-?[\d.]+)\s*\]/g, '[$1, $2]')
  .replace(/\[\s*(\d+),\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+|null)\s*\]/g, '[$1, $2, $3, $4]')
const output = process.argv[2] ?? fileURLToPath(new URL('../../CrewluvTests/Fixtures/TripMap/live-cases.json', import.meta.url))
writeFileSync(output, text + '\n')
console.log(`${plans.length} plans, ${flights.length} flights, ${labels.length} labels, ${gaps.length} gaps, ${windows.length} windows; ${text.length} bytes`)
for (const f of flights) {
  console.log(`- ${f.name}: path ${f.path.lengthNm} nm (${f.path.stretchKinds.length} stretches, unseen ${f.path.unseenNm}), ` +
    f.moments.map((m) => `${m.at.slice(11, 19)} ${m.phase} gap ${m.gapMinutes} "${m.label}" plane ${m.planeAlongNm} ghost ${m.ghostAlongNm}`).join(' | '))
}
```

- [x] **Step 3: Write the cases.**

```bash
cd /Users/toddanderson/Dev/Crewluv && node scripts/live-cases/generate.mjs
```

Expected, on the first line: `7 plans, 18 flights, 29 labels, 12 gaps, 12 windows; 72721 bytes`. Then a line for each flight, among them:

```
- off early and the long way round: path 581.109 nm (8 stretches, unseen 0), 12:14:00 inAir gap -3 "On schedule" plane 52.356 ghost 0 | 12:15:20 inAir gap -3 "On schedule" plane 52.356 ghost 83.605
```

- [x] **Step 4: Check the file.**

```bash
shasum -a 256 CrewluvTests/Fixtures/TripMap/live-cases.json
```

Expected: `f55edd91ab8dc37634ae8b2bfd0912dcde79c757d426f08a85b6aba18f6dde30`. Another Node's maths can differ in a last digit, which changes the hash and nothing that matters: if the first line above matched, go on, and say so when asking to commit.

- [x] **Step 5: Ask to commit.** Suggested message: `test(crewluv): the real plane's shared cases, made by a reference written apart from the app and the website: the schedule's plan, paths from trails, the record, the landing estimate, every label and the window (Stage 3 spec §16.1)`.

---

### Task 3: The door's call and its answer

**Files:**
- Create: `Crewluv/Services/TripMap/Live/LiveFlight.swift`
- Create: `Crewluv/Services/PartnerCloud/PartnerLiveAnswer.swift`
- Create: `Crewluv/Services/PartnerCloud/LiveFlightDoor.swift`
- Modify: `Crewluv/Services/PartnerCloud/LivePartnerDoor.swift`
- Modify: `CrewluvTests/Helpers/PartnerCloudStandIns.swift`
- Test: `CrewluvTests/LivePartnerDoorTests.swift`

`partner_live` answers `{"now", "cursor", "flights": [...]}`, with every time in milliseconds since 1970. The door's decoder reads dates as seconds, so these types read the numbers themselves.

- [x] **Step 1: Write the failing tests.** In `CrewluvTests/LivePartnerDoorTests.swift`, the last test of `LivePartnerDoorTests` is `test_anAnswerThatDoesntDecode_isUnavailable`. After its closing brace, and before the brace that closes the struct, add:

```swift
    // MARK: - The Live Plane

    private static let liveAnswer = #"""
        {"now": 1794601935000, "cursor": 412, "flights": [
          {"leg_id": "leg-1", "callsign": "UPS207", "state": "airborne",
           "fix": {"lat": 46.812345, "lon": -71.5, "altitude_ft": 35000, "ground_speed_kt": 468, "track_deg": 61,
                   "on_ground": false, "registration": "N370UP", "type_code": "B763", "seen_at": 1794601920000},
           "landed_at": null,
           "trail": [[1794601680000, 46.5, -72.25, 34975], [1794601800000, 46.65, -71.9, null]],
           "trail_count": 9},
          {"leg_id": "leg-2", "callsign": "UPS208", "state": "waiting", "fix": null, "landed_at": null,
           "trail": [], "trail_count": 0}
        ]}
        """#

    @Test func test_live_postsTheKey_andNoCursorWithoutOne() async throws {
        let network = StandInNetwork(body: #"{"now": 1794601935000, "cursor": 0, "flights": []}"#)
        _ = try await network.door.live(key: Self.key, after: nil)

        let request = try #require(network.requests.first)
        #expect(network.requests.count == 1)
        #expect(request.url?.absoluteString == "https://corxvurxpnrzekbxdgye.supabase.co/rest/v1/rpc/partner_live")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "apikey") == LivePartnerDoor.publishableKey)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(try network.parameters(request) == ["p_key": Self.key])
    }

    @Test func test_live_sendsTheCursorBack() async throws {
        let network = StandInNetwork(body: #"{"now": 1794601935000, "cursor": 412, "flights": []}"#)
        _ = try await network.door.live(key: Self.key, after: 412)

        let body = try #require(network.requests.first?.httpBody)
        let parameters = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(parameters["p_key"] as? String == Self.key)
        #expect(parameters["p_after"] as? Int == 412)
        #expect(parameters.count == 2)
    }

    @Test func test_live_readsTheClockTheCursorAndEachFlight() async throws {
        let answer = try await StandInNetwork(body: Self.liveAnswer).door.live(key: Self.key, after: nil)

        #expect(answer.now == Date(timeIntervalSince1970: 1_794_601_935))
        #expect(answer.cursor == 412)
        #expect(answer.flights.map(\.legID) == ["leg-1", "leg-2"])
        let flight = try #require(answer.flights.first)
        #expect(flight.callsign == "UPS207")
        #expect(flight.state == .airborne)
        #expect(flight.landedAt == nil)
        #expect(flight.trailCount == 9)
        #expect(flight.fix == LiveFlight.Fix(
            latitude: 46.812345, longitude: -71.5, altitudeFeet: 35000, groundSpeedKnots: 468, trackDegrees: 61,
            isOnGround: false, registration: "N370UP", typeCode: "B763", seenAt: Date(timeIntervalSince1970: 1_794_601_920)
        ))
        #expect(flight.trail == [
            LiveFlight.TrailPoint(time: Date(timeIntervalSince1970: 1_794_601_680), latitude: 46.5, longitude: -72.25, altitudeFeet: 34975),
            LiveFlight.TrailPoint(time: Date(timeIntervalSince1970: 1_794_601_800), latitude: 46.65, longitude: -71.9, altitudeFeet: nil),
        ])
        let waiting = try #require(answer.flights.last)
        #expect(waiting.state == .waiting)
        #expect(waiting.fix == nil)
        #expect(waiting.trail.isEmpty)
        #expect(waiting.trailCount == 0)
    }

    @Test func test_live_aLandedFlight_hasItsLandingTime_andAFixOnTheGround() async throws {
        let body = #"""
            {"now": 1794601935000, "cursor": 0, "flights": [
              {"leg_id": "leg-1", "callsign": "UPS207", "state": "landed",
               "fix": {"lat": 50.87, "lon": 7.14, "altitude_ft": null, "ground_speed_kt": null, "track_deg": null,
                       "on_ground": true, "registration": null, "type_code": null, "seen_at": 1794601920500},
               "landed_at": 1794601800250, "trail": [], "trail_count": 0}
            ]}
            """#
        let flight = try #require(try await StandInNetwork(body: body).door.live(key: Self.key, after: nil).flights.first)

        #expect(flight.state == .landed)
        #expect(flight.landedAt == Date(timeIntervalSince1970: 1_794_601_800.25))
        #expect(flight.fix == LiveFlight.Fix(
            latitude: 50.87, longitude: 7.14, altitudeFeet: nil, groundSpeedKnots: nil, trackDegrees: nil,
            isOnGround: true, registration: nil, typeCode: nil, seenAt: Date(timeIntervalSince1970: 1_794_601_920.5)
        ))
    }

    @Test func test_live_aStateThisAppDoesntKnow_readsAsWaiting() async throws {
        let body = #"""
            {"now": 1794601935000, "cursor": 0, "flights": [
              {"leg_id": "leg-1", "callsign": "UPS207", "state": "holding", "fix": null, "landed_at": null,
               "trail": [], "trail_count": 0}
            ]}
            """#
        let answer = try await StandInNetwork(body: body).door.live(key: Self.key, after: nil)

        #expect(answer.flights.map(\.state) == [.waiting])
    }

    @Test func test_live_sharingEnded_isRefused() async {
        let network = StandInNetwork(body: #"{"error": "sharing_ended"}"#)

        await #expect(throws: PartnerDoorError.refused(.sharingEnded)) { try await network.door.live(key: Self.key, after: 412) }
    }

    @Test(arguments: [
        "<html>Bad gateway</html>",
        #"{"cursor": 0, "flights": []}"#,
        #"{"now": 1794601935000, "cursor": 0, "flights": [{"leg_id": "leg-1", "callsign": "UPS207", "state": "airborne"}]}"#,
        #"{"now": 1794601935000, "cursor": 0, "flights": [{"leg_id": "leg-1", "callsign": "UPS207", "state": "airborne", "fix": null, "landed_at": null, "trail": [[1794601680000, 46.5]], "trail_count": 1}]}"#,
    ])
    func test_live_anAnswerThatDoesntDecode_isUnavailable(body: String) async {
        let network = StandInNetwork(body: body)

        await #expect(throws: PartnerDoorError.unavailable) { try await network.door.live(key: Self.key, after: nil) }
    }
```

- [x] **Step 2: Give the stand-in door the call.** In `CrewluvTests/Helpers/PartnerCloudStandIns.swift`, make five changes to `StandInPartnerDoor`.

Its first line becomes:

```swift
final class StandInPartnerDoor: PartnerDoor, LiveFlightDoor {
```

After `var leaveAnswers: [Result<Void, PartnerDoorError>] = []`, add:

```swift
    /// The answers to `live`, in order. With none left, the door can't be reached.
    var liveAnswers: [Result<PartnerLiveAnswer, PartnerDoorError>] = []
```

After `var holdsHandOffs = false`, add:

```swift
    /// While true, each `live` waits for `release()`.
    var holdsLives = false
```

After `private(set) var leaves: [String] = []`, add:

```swift
    /// Each `live`: the key and the cursor it sent.
    private(set) var lives: [(key: String, after: Int?)] = []
```

Before `private func nextJoinAnswer()`, add:

```swift
    func live(key: String, after cursor: Int?) async throws(PartnerDoorError) -> PartnerLiveAnswer {
        lives.append((key, cursor))
        if holdsLives {
            await withCheckedContinuation { held.append($0) }
        }
        guard !liveAnswers.isEmpty else { throw .unavailable }
        return try liveAnswers.removeFirst().get()
    }

```

- [x] **Step 3: Write `LiveFlight`.** Create `Crewluv/Services/TripMap/Live/LiveFlight.swift`:

```swift
//
//  LiveFlight.swift
//  CrewLuve
//
//  One flight's live data, as Crewlu Cloud keeps it from adsb.lol (Stage 3 spec §10.5, §10.6): its state, the last
//  place it was seen, and the path it flew.
//

import CoreLocation

nonisolated struct LiveFlight: Equatable, Sendable {

    nonisolated enum State: String, Sendable {
        /// Watched, and never seen.
        case waiting
        /// On the ground: at the departure airport, or somewhere else after a diversion.
        case ground
        case airborne
        /// Seen on the ground at the arrival airport, after being in the air.
        case landed
    }

    /// The last place the aircraft was seen.
    nonisolated struct Fix: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
        /// Nil on the ground.
        let altitudeFeet: Double?
        let groundSpeedKnots: Double?
        /// 0 to 360, or nil when the aircraft sent none.
        let trackDegrees: Double?
        let isOnGround: Bool
        let registration: String?
        /// The aircraft's ICAO type code, like "B763".
        let typeCode: String?
        /// By Crewlu Cloud's clock.
        let seenAt: Date

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }

    /// One point of the path flown: about one every 2 minutes while the flight is seen in the air.
    nonisolated struct TrailPoint: Equatable, Sendable {
        let time: Date
        let latitude: Double
        let longitude: Double
        let altitudeFeet: Double?

        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }

    /// The id of the flight's leg in the pilot's summary.
    let legID: String
    let callsign: String
    let state: State
    /// Nil before the flight is first seen.
    let fix: Fix?
    /// When it was first seen on the ground at the arrival airport.
    let landedAt: Date?
    /// Every point of the path flown, as Crewlu Cloud sent them.
    let trail: [TrailPoint]
}

nonisolated extension LiveFlight {
    /// One of partner_live's flights, with the whole of its `trail`: an answer may bring only the newest points.
    init(_ answered: PartnerLiveAnswer.Flight, trail: [TrailPoint]) {
        self.init(legID: answered.legID, callsign: answered.callsign, state: answered.state, fix: answered.fix,
                  landedAt: answered.landedAt, trail: trail)
    }
}
```

- [x] **Step 4: Write the answer.** Create `Crewluv/Services/PartnerCloud/PartnerLiveAnswer.swift`:

```swift
//
//  PartnerLiveAnswer.swift
//  CrewLuve
//
//  partner_live's answer, as Crewlu Cloud writes it (CrewLu's supabase/partner-api.md, "The live plane")
//

import Foundation

/// partner_live's answer: Crewlu Cloud's clock, the cursor to send back, and each of the pilot's flights with live
/// data. Every time in it is milliseconds since 1970, unlike the summary's seconds.
nonisolated struct PartnerLiveAnswer: Equatable, Sendable {

    nonisolated struct Flight: Equatable, Sendable {
        /// The id of the flight's leg in the pilot's summary.
        let legID: String
        let callsign: String
        let state: LiveFlight.State
        let fix: LiveFlight.Fix?
        let landedAt: Date?
        /// The points after the cursor the call sent, or every point when it sent none.
        let trail: [LiveFlight.TrailPoint]
        /// How many points the flight has in all.
        let trailCount: Int
    }

    /// Crewlu Cloud's clock when it answered.
    let now: Date
    /// Sent back with the next call, so only the points after these come.
    let cursor: Int
    let flights: [Flight]
}

// MARK: - Reading It

nonisolated extension PartnerLiveAnswer: Decodable {
    private enum CodingKeys: String, CodingKey {
        case now, cursor, flights
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        now = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .now) / 1000)
        cursor = try container.decode(Int.self, forKey: .cursor)
        flights = try container.decode([Flight].self, forKey: .flights)
    }
}

nonisolated extension PartnerLiveAnswer.Flight: Decodable {
    private enum CodingKeys: String, CodingKey {
        case legID = "leg_id"
        case callsign, state, fix
        case landedAt = "landed_at"
        case trail
        case trailCount = "trail_count"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        legID = try container.decode(String.self, forKey: .legID)
        callsign = try container.decode(String.self, forKey: .callsign)
        // A state this Crewluve doesn't know is one it can't draw: the schedule's plane shows.
        state = LiveFlight.State(rawValue: try container.decode(String.self, forKey: .state)) ?? .waiting
        fix = try container.decodeIfPresent(LiveFlight.Fix.self, forKey: .fix)
        landedAt = try container.decodeIfPresent(Double.self, forKey: .landedAt).map { Date(timeIntervalSince1970: $0 / 1000) }
        trail = try container.decode([LiveFlight.TrailPoint].self, forKey: .trail)
        trailCount = try container.decode(Int.self, forKey: .trailCount)
    }
}

nonisolated extension LiveFlight.Fix: Decodable {
    private enum CodingKeys: String, CodingKey {
        case latitude = "lat"
        case longitude = "lon"
        case altitudeFeet = "altitude_ft"
        case groundSpeedKnots = "ground_speed_kt"
        case trackDegrees = "track_deg"
        case isOnGround = "on_ground"
        case registration
        case typeCode = "type_code"
        case seenAt = "seen_at"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        altitudeFeet = try container.decodeIfPresent(Double.self, forKey: .altitudeFeet)
        groundSpeedKnots = try container.decodeIfPresent(Double.self, forKey: .groundSpeedKnots)
        trackDegrees = try container.decodeIfPresent(Double.self, forKey: .trackDegrees)
        isOnGround = try container.decode(Bool.self, forKey: .isOnGround)
        registration = try container.decodeIfPresent(String.self, forKey: .registration)
        typeCode = try container.decodeIfPresent(String.self, forKey: .typeCode)
        seenAt = Date(timeIntervalSince1970: try container.decode(Double.self, forKey: .seenAt) / 1000)
    }
}

/// A trail point comes as `[time, latitude, longitude, altitude in feet]`, the altitude null when adsb.lol sent none.
nonisolated extension LiveFlight.TrailPoint: Decodable {
    init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        time = Date(timeIntervalSince1970: try values.decode(Double.self) / 1000)
        latitude = try values.decode(Double.self)
        longitude = try values.decode(Double.self)
        altitudeFeet = try values.decodeIfPresent(Double.self)
    }
}
```

- [x] **Step 5: Let the call be used from another file.** In `Crewluv/Services/PartnerCloud/LivePartnerDoor.swift`, replace:

```swift
    /// Posts one RPC and decodes its answer, or the door's refusal. A failure is logged with the
    /// RPC's name and why, but never the request, which holds the key and the token.
    private func call<Answer: Decodable>(
```

with:

```swift
    /// Posts one RPC and decodes its answer, or the door's refusal. A failure is logged with the
    /// RPC's name and why, but never the request, which holds the key and the token. Not private, so
    /// the live plane's call can be written in a file the alert pushes' helper doesn't build.
    func call<Answer: Decodable>(
```

This is one of the helper's 15 files. Nothing else in it changes, and it needs no new file.

- [x] **Step 6: Write the door's call.** Create `Crewluv/Services/PartnerCloud/LiveFlightDoor.swift`:

```swift
//
//  LiveFlightDoor.swift
//  CrewLuve
//
//  The partner door's call for the live plane
//

import Foundation

/// partner_live: the pilot's flights with live data, for the partner whose device holds `key` (CrewLu's
/// `supabase/partner-api.md`, "The live plane"). It's apart from `PartnerDoor`, whose file the alert pushes' helper
/// builds: the helper has no use for the live plane, and so needs none of its types.
protocol LiveFlightDoor {
    /// `cursor` is the last answer's, so only the trail points since then come, or nil for every point.
    func live(key: String, after cursor: Int?) async throws(PartnerDoorError) -> PartnerLiveAnswer
}

extension LivePartnerDoor: LiveFlightDoor {
    func live(key: String, after cursor: Int?) async throws(PartnerDoorError) -> PartnerLiveAnswer {
        try await call("partner_live", LiveParameters(key: key, after: cursor))
    }
}

private struct LiveParameters: Encodable {
    let key: String
    /// Left out when nil, so the door sends every point.
    let after: Int?

    enum CodingKeys: String, CodingKey {
        case key = "p_key"
        case after = "p_after"
    }
}
```

- [x] **Step 7: Run the tests, expecting them to pass.** Todd runs `LivePartnerDoorTests`: its 17 tests from before and these 7. Building the app for the tests builds the helper with it, so a run that starts also shows the helper still compiles with its 15 files.

- [x] **Step 8: Ask to commit.** Suggested message: `feat(crewluv): the partner door's call for the live plane, apart from PartnerDoor so the alert pushes' helper needs none of it, and partner_live's answer read from milliseconds (Stage 3 spec §10.6, §11)`.

---

### Task 4: `FlightPlan`

**Files:**
- Modify: `Crewluv/Utils/GreatCircle.swift`
- Create: `Crewluv/Services/TripMap/Live/FlightPlan.swift`
- Create: `CrewluvTests/Helpers/LiveCases.swift`
- Test: `CrewluvTests/FlightPlanTests.swift`

The plan is Stage 1's takeoff and touchdown, with the last 120 nm flown at 280 kt and everything before at one faster speed. A short or slow leg has one steady speed. Two answers come from it, each the other's inverse.

- [ ] **Step 1: Write the cases' reader.** Create `CrewluvTests/Helpers/LiveCases.swift`. Task 5 adds to it.

```swift
//
//  LiveCases.swift
//  CrewluvTests
//
//  Reads Fixtures/TripMap/live-cases.json: the real plane's shared cases, which the website runs too (Stage 3 spec
//  §16.1). Its distances are nautical miles, and its flights are entries of partner_live's answer as the door sends them.
//

import CoreLocation
import Foundation
@testable import Crewluv

extension TripMapFixtures {

    struct LiveCases: Decodable {
        struct Constants: Decodable {
            let taxiOutMinutes: Double
            let taxiInMinutes: Double
            let shortestCruiseMinutes: Double
            let descentDistanceNm: Double
            let descentSpeedKt: Double
            let freshSeconds: Double
            let airportRadiusNm: Double
            let onScheduleMinutes: Int
            let unseenGapMinutes: Double
            let firstPointRadiusNm: Double
            let windowOpensMinutesBefore: Double
            let windowClosesHoursAfter: Double
            let windowKeepsMinutes: Double
            let windowEndsHoursAfter: Double
        }

        struct Plan: Decodable {
            struct TimeToFly: Decodable {
                let distanceNm: Double
                let seconds: Double
            }

            struct DistanceLeft: Decodable {
                let minutes: Double
                let distanceNm: Double
            }

            let name: String
            let from: String
            let to: String
            let departure: Date
            let arrival: Date
            let lengthNm: Double
            let takeoff: Date
            let touchdown: Date
            let isShort: Bool
            let speedKt: Double
            let timeToFly: [TimeToFly]
            let distanceLeft: [DistanceLeft]
        }

        struct Flight: Decodable {
            struct Path: Decodable {
                let isReal: Bool
                let lengthNm: Double
                let flownNm: Double
                /// `FlightPath.Kind`'s raw values, one for each stretch.
                let stretchKinds: [String]
                let seenNm: Double
                let unseenNm: Double
                let plannedNm: Double
            }

            struct Moment: Decodable {
                let at: Date
                let note: String
                /// `LiveProgress.Phase`'s raw value.
                let phase: String
                let touchdown: Date?
                let liveArrival: Date?
                let gapMinutes: Int?
                let label: String?
                let planeAlongNm: Double?
                let plane: [Double]?
                let ghostAlongNm: Double?
                let ghost: [Double]?
                let start: Date
                let end: Date
            }

            struct Record: Decodable {
                struct Place: Decodable {
                    let at: Date
                    let alongNm: Double
                    let point: [Double]
                }

                struct Time: Decodable {
                    let alongNm: Double
                    let at: Date
                }

                let takeoff: Date?
                let touchdown: Date
                let places: [Place]
                let times: [Time]
            }

            let name: String
            let from: String
            let to: String
            let departure: Date
            let arrival: Date
            /// One entry of partner_live's `flights`, or nil where the door answers none for the leg.
            let flight: PartnerLiveAnswer.Flight?
            let path: Path
            let moments: [Moment]
            let record: Record?
        }

        struct Label: Decodable {
            let phase: String
            let gapMinutes: Int?
            let label: String?
        }

        struct Gap: Decodable {
            let aheadSeconds: Double
            let gapMinutes: Int
        }

        struct Window: Decodable {
            let name: String
            let departure: Date
            let arrival: Date
            let at: Date
            let flight: PartnerLiveAnswer.Flight?
            let isOpen: Bool
        }

        let constants: Constants
        /// Latitude, longitude.
        let airports: [String: [Double]]
        let plans: [Plan]
        let flights: [Flight]
        let labels: [Label]
        let gaps: [Gap]
        let windows: [Window]

        func coordinate(of code: String) throws -> CLLocationCoordinate2D {
            guard let place = airports[code], place.count == 2 else { throw MissingAirport(code: code) }
            return CLLocationCoordinate2D(latitude: place[0], longitude: place[1])
        }
    }

    struct MissingAirport: Error {
        let code: String
    }

    /// One nautical mile in meters, for comparing with the cases.
    static let nauticalMile = GreatCircle.metersPerNauticalMile

    static func liveCases() throws -> LiveCases {
        let data = try Data(contentsOf: folder.appending(path: "live-cases.json"))
        let decoder = JSONDecoder()
        // The cases' times have milliseconds, which `.iso8601` doesn't read.
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        }
        return try decoder.decode(LiveCases.self, from: data)
    }
}
```

- [ ] **Step 2: Write the failing tests.** Create `CrewluvTests/FlightPlanTests.swift`:

```swift
//
//  FlightPlanTests.swift
//  CrewluvTests
//
//  The schedule's flight plan (Stage 3 spec §4), held to the shared cases in Fixtures/TripMap.
//

import XCTest
@testable import Crewluv

final class FlightPlanTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(FlightProgress.taxiOutAllowance, constants.taxiOutMinutes * 60)
        XCTAssertEqual(FlightProgress.taxiInAllowance, constants.taxiInMinutes * 60)
        XCTAssertEqual(FlightProgress.shortestCruise, constants.shortestCruiseMinutes * 60)
        XCTAssertEqual(FlightPlan.descentDistance, constants.descentDistanceNm * nauticalMile)
        XCTAssertEqual(FlightPlan.descentSpeed, constants.descentSpeedKt * nauticalMile / 3600, accuracy: 1e-9)
    }

    func test_plans_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertFalse(cases.plans.isEmpty)
        for planCase in cases.plans {
            let distance = GreatCircle.distance(from: try cases.coordinate(of: planCase.from), to: try cases.coordinate(of: planCase.to))
            let plan = try XCTUnwrap(FlightPlan(departure: planCase.departure, arrival: planCase.arrival, distance: distance), planCase.name)
            XCTAssertEqual(plan.distance / nauticalMile, planCase.lengthNm, accuracy: 0.01, planCase.name)
            XCTAssertEqual(plan.takeoff, planCase.takeoff, planCase.name)
            XCTAssertEqual(plan.touchdown, planCase.touchdown, planCase.name)
            XCTAssertEqual(plan.isSteady, planCase.isShort, planCase.name)
            XCTAssertEqual(plan.speed * 3600 / nauticalMile, planCase.speedKt, accuracy: 0.01, planCase.name)
            for check in planCase.timeToFly {
                XCTAssertEqual(plan.timeToFly(check.distanceNm * nauticalMile), check.seconds, accuracy: 0.05,
                               "\(planCase.name): \(check.distanceNm) nm")
            }
            for check in planCase.distanceLeft {
                XCTAssertEqual(plan.distanceLeft(check.minutes * 60) / nauticalMile, check.distanceNm, accuracy: 0.01,
                               "\(planCase.name): \(check.minutes) min")
            }
        }
    }

    func test_timeToFly_theWholeLeg_isThePlansTimeInTheAir() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(8 * 3600), distance: 7_000_000))
        XCTAssertFalse(plan.isSteady)
        XCTAssertEqual(plan.timeToFly(plan.distance), plan.timeInAir, accuracy: 1e-6)
        XCTAssertEqual(plan.distanceLeft(plan.timeInAir), plan.distance, accuracy: 1e-6)
    }

    func test_distanceLeft_isTheInverseOfTimeToFly() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(8 * 3600), distance: 7_000_000))
        for distance in [50_000.0, 222_240, 1_000_000, 7_000_000, 7_500_000] {
            XCTAssertEqual(plan.distanceLeft(plan.timeToFly(distance)), distance, accuracy: 1e-6)
        }
    }

    func test_taxi_aLongBlock_hasBothAllowances() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(8 * 3600), distance: 7_000_000))
        XCTAssertEqual(plan.taxiOut, 15 * 60)
        XCTAssertEqual(plan.taxiIn, 7 * 60)
        XCTAssertEqual(plan.timeInAir, 8 * 3600 - 22 * 60)
    }

    func test_taxi_aBlockTooShortForTheAllowances_hasNone() throws {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(30 * 60), distance: 100_000))
        XCTAssertEqual(plan.taxiOut, 0)
        XCTAssertEqual(plan.taxiIn, 0)
    }

    func test_init_arrivalNoLaterThanDeparture_isNil() {
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertNil(FlightPlan(departure: departure, arrival: departure, distance: 1_000_000))
        XCTAssertNil(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(-60), distance: 1_000_000))
    }
}
```

- [ ] **Step 3: Add the nautical mile.** In `Crewluv/Utils/GreatCircle.swift`, after:

```swift
    /// One statute mile, in meters. Families think in miles (moving map spec §8.3).
    static let metersPerMile: Double = 1_609.344
```

add:

```swift

    /// One nautical mile, in meters. The flight plan's distances and speeds are in them (Stage 3 spec §4).
    static let metersPerNauticalMile: Double = 1_852
```

- [ ] **Step 4: Write `FlightPlan`.** Create `Crewluv/Services/TripMap/Live/FlightPlan.swift`:

```swift
//
//  FlightPlan.swift
//  CrewLuve
//
//  The schedule's flight plan (Stage 3 spec §4): when an on-schedule plane takes off and touches down, and how fast
//  it flies in between. The real plane is measured against it. The constants are written down in
//  CrewluvTests/Fixtures/TripMap/live-cases.json, which the website shares.
//

import Foundation

nonisolated struct FlightPlan: Equatable, Sendable {

    /// The last stretch before touchdown, flown at `descentSpeed`: 120 nautical miles, in meters.
    static let descentDistance: Double = 120 * GreatCircle.metersPerNauticalMile

    /// 280 knots, in meters a second.
    static let descentSpeed: Double = 280 * GreatCircle.metersPerNauticalMile / 3600

    /// How long the descent takes: 25.7 minutes.
    static let descentTime: TimeInterval = descentDistance / descentSpeed

    /// Leaving the gate and reaching it, both moved by any reported delay.
    let departure: Date
    let arrival: Date
    /// Wheels up and wheels down, as Stage 1's schedule plane has them (`FlightProgress.airborneWindow`).
    let takeoff: Date
    let touchdown: Date
    /// The great-circle distance between the leg's airports, in meters.
    let distance: Double
    /// The speed before the descent, in meters a second: the cruise, or a short leg's one speed.
    let speed: Double
    /// Whether the whole leg is flown at `speed`, with no descent of its own: a short leg.
    let isSteady: Bool

    /// The plan of a leg between airports `distance` meters apart. Nil when it arrives no later than it leaves.
    init?(departure: Date, arrival: Date, distance: Double) {
        guard let window = FlightProgress.airborneWindow(departure: departure, arrival: arrival) else { return nil }
        self.departure = departure
        self.arrival = arrival
        takeoff = window.start
        touchdown = window.end
        self.distance = distance
        let cruise = (distance - Self.descentDistance) / (window.duration - Self.descentTime)
        if distance > Self.descentDistance, window.duration > Self.descentTime, cruise > Self.descentSpeed {
            speed = cruise
            isSteady = false
        } else {
            // A leg that goes nowhere has no speed of its own: the descent's stands in.
            let steady = distance / window.duration
            speed = steady > 0 ? steady : Self.descentSpeed
            isSteady = true
        }
    }

    /// The plan's time in the air.
    var timeInAir: TimeInterval { touchdown.timeIntervalSince(takeoff) }

    /// From the gate to wheels up: Stage 1's allowance, or nothing on a block too short for it.
    var taxiOut: TimeInterval { takeoff.timeIntervalSince(departure) }

    /// From wheels down to the gate.
    var taxiIn: TimeInterval { arrival.timeIntervalSince(touchdown) }

    /// How long an on-schedule plane needs to fly `distance` meters to touchdown. Further than the whole leg, the
    /// extra is flown at `speed`.
    func timeToFly(_ distance: Double) -> TimeInterval {
        let far = max(distance, 0)
        if isSteady { return far / speed }
        if far <= Self.descentDistance { return far / Self.descentSpeed }
        return Self.descentTime + (far - Self.descentDistance) / speed
    }

    /// How far from touchdown an on-schedule plane is, `time` seconds before it: `timeToFly`'s inverse.
    func distanceLeft(_ time: TimeInterval) -> Double {
        let left = max(time, 0)
        if isSteady { return left * speed }
        if left <= Self.descentTime { return left * Self.descentSpeed }
        return Self.descentDistance + (left - Self.descentTime) * speed
    }
}
```

- [ ] **Step 5: Run the tests, expecting them to pass.** Todd runs `FlightPlanTests`: 7 tests.

- [ ] **Step 6: Ask to commit.** Suggested message: `feat(crewluv): FlightPlan, the schedule's plan the real plane is measured against: Stage 1's takeoff and touchdown, a descent of 120 nm at 280 kt, and one speed before it (Stage 3 spec §4)`.

---

### Task 5: `FlightPath` and `FlightRecord`

**Files:**
- Create: `Crewluv/Services/TripMap/Live/FlightPath.swift`
- Create: `Crewluv/Services/TripMap/Live/FlightRecord.swift`
- Modify: `CrewluvTests/Helpers/LiveCases.swift`
- Test: `CrewluvTests/FlightPathTests.swift`, `CrewluvTests/FlightRecordTests.swift`

The path is a list of great-circle stretches from the departure airport to the arrival airport, each seen, unseen or planned. Its knots are the places the plane was seen, each with its time and its distance along. The record reads the knots: between two it's in proportion to the time, before the first it flies in at the plan's speed, and after the last it flies the plan to the airport.

- [ ] **Step 1: Let the reader make a case's path and record.** `LiveCases` gains `made(_:)`, and beside it come `Made` and `MissingPlan`. Replace the whole of `CrewluvTests/Helpers/LiveCases.swift` with:

```swift
//
//  LiveCases.swift
//  CrewluvTests
//
//  Reads Fixtures/TripMap/live-cases.json: the real plane's shared cases, which the website runs too (Stage 3 spec
//  §16.1). Its distances are nautical miles, and its flights are entries of partner_live's answer as the door sends them.
//

import CoreLocation
import Foundation
@testable import Crewluv

extension TripMapFixtures {

    struct LiveCases: Decodable {
        struct Constants: Decodable {
            let taxiOutMinutes: Double
            let taxiInMinutes: Double
            let shortestCruiseMinutes: Double
            let descentDistanceNm: Double
            let descentSpeedKt: Double
            let freshSeconds: Double
            let airportRadiusNm: Double
            let onScheduleMinutes: Int
            let unseenGapMinutes: Double
            let firstPointRadiusNm: Double
            let windowOpensMinutesBefore: Double
            let windowClosesHoursAfter: Double
            let windowKeepsMinutes: Double
            let windowEndsHoursAfter: Double
        }

        struct Plan: Decodable {
            struct TimeToFly: Decodable {
                let distanceNm: Double
                let seconds: Double
            }

            struct DistanceLeft: Decodable {
                let minutes: Double
                let distanceNm: Double
            }

            let name: String
            let from: String
            let to: String
            let departure: Date
            let arrival: Date
            let lengthNm: Double
            let takeoff: Date
            let touchdown: Date
            let isShort: Bool
            let speedKt: Double
            let timeToFly: [TimeToFly]
            let distanceLeft: [DistanceLeft]
        }

        struct Flight: Decodable {
            struct Path: Decodable {
                let isReal: Bool
                let lengthNm: Double
                let flownNm: Double
                /// `FlightPath.Kind`'s raw values, one for each stretch.
                let stretchKinds: [String]
                let seenNm: Double
                let unseenNm: Double
                let plannedNm: Double
            }

            struct Moment: Decodable {
                let at: Date
                let note: String
                /// `LiveProgress.Phase`'s raw value.
                let phase: String
                let touchdown: Date?
                let liveArrival: Date?
                let gapMinutes: Int?
                let label: String?
                let planeAlongNm: Double?
                let plane: [Double]?
                let ghostAlongNm: Double?
                let ghost: [Double]?
                let start: Date
                let end: Date
            }

            struct Record: Decodable {
                struct Place: Decodable {
                    let at: Date
                    let alongNm: Double
                    let point: [Double]
                }

                struct Time: Decodable {
                    let alongNm: Double
                    let at: Date
                }

                let takeoff: Date?
                let touchdown: Date
                let places: [Place]
                let times: [Time]
            }

            let name: String
            let from: String
            let to: String
            let departure: Date
            let arrival: Date
            /// One entry of partner_live's `flights`, or nil where the door answers none for the leg.
            let flight: PartnerLiveAnswer.Flight?
            let path: Path
            let moments: [Moment]
            let record: Record?
        }

        struct Label: Decodable {
            let phase: String
            let gapMinutes: Int?
            let label: String?
        }

        struct Gap: Decodable {
            let aheadSeconds: Double
            let gapMinutes: Int
        }

        struct Window: Decodable {
            let name: String
            let departure: Date
            let arrival: Date
            let at: Date
            let flight: PartnerLiveAnswer.Flight?
            let isOpen: Bool
        }

        let constants: Constants
        /// Latitude, longitude.
        let airports: [String: [Double]]
        let plans: [Plan]
        let flights: [Flight]
        let labels: [Label]
        let gaps: [Gap]
        let windows: [Window]

        func coordinate(of code: String) throws -> CLLocationCoordinate2D {
            guard let place = airports[code], place.count == 2 else { throw MissingAirport(code: code) }
            return CLLocationCoordinate2D(latitude: place[0], longitude: place[1])
        }

        /// A flight case as the app's types: its plan, its live data, and the path and record made from them.
        func made(_ flight: Flight) throws -> Made {
            let origin = try coordinate(of: flight.from)
            let destination = try coordinate(of: flight.to)
            let distance = GreatCircle.distance(from: origin, to: destination)
            guard let plan = FlightPlan(departure: flight.departure, arrival: flight.arrival, distance: distance) else {
                throw MissingPlan(name: flight.name)
            }
            let live = flight.flight.map { LiveFlight($0, trail: $0.trail) }
            let path = FlightPath(from: origin, to: destination, flight: live)
            return Made(plan: plan, flight: live, path: path, record: FlightRecord(path: path, plan: plan))
        }
    }

    struct Made {
        let plan: FlightPlan
        let flight: LiveFlight?
        let path: FlightPath
        let record: FlightRecord?
    }

    struct MissingAirport: Error {
        let code: String
    }

    struct MissingPlan: Error {
        let name: String
    }

    /// One nautical mile in meters, for comparing with the cases.
    static let nauticalMile = GreatCircle.metersPerNauticalMile

    static func liveCases() throws -> LiveCases {
        let data = try Data(contentsOf: folder.appending(path: "live-cases.json"))
        let decoder = JSONDecoder()
        // The cases' times have milliseconds, which `.iso8601` doesn't read.
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
        }
        return try decoder.decode(LiveCases.self, from: data)
    }
}
```

- [ ] **Step 2: Write the path's failing tests.** Create `CrewluvTests/FlightPathTests.swift`:

```swift
//
//  FlightPathTests.swift
//  CrewluvTests
//
//  The path a flight is drawn and measured along (Stage 3 spec §6.1), held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightPathTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile
    private let louisville = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.736)
    private let philadelphia = CLLocationCoordinate2D(latitude: 39.8719, longitude: -75.2411)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func point(_ minutes: Double, _ latitude: Double, _ longitude: Double) -> LiveFlight.TrailPoint {
        LiveFlight.TrailPoint(time: start.addingTimeInterval(minutes * 60), latitude: latitude, longitude: longitude, altitudeFeet: 30_000)
    }

    private func flight(state: LiveFlight.State = .airborne, fix: LiveFlight.Fix? = nil, landedAt: Date? = nil,
                        trail: [LiveFlight.TrailPoint]) -> LiveFlight {
        LiveFlight(legID: "leg", callsign: "UPS1234", state: state, fix: fix, landedAt: landedAt, trail: trail)
    }

    private func fix(_ minutes: Double, _ latitude: Double, _ longitude: Double, isOnGround: Bool = false) -> LiveFlight.Fix {
        LiveFlight.Fix(latitude: latitude, longitude: longitude, altitudeFeet: isOnGround ? nil : 30_000, groundSpeedKnots: 430,
                       trackDegrees: 80, isOnGround: isOnGround, registration: nil, typeCode: nil,
                       seenAt: start.addingTimeInterval(minutes * 60))
    }

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(FlightPath.unseenGap, constants.unseenGapMinutes * 60)
        XCTAssertEqual(FlightPath.firstPointRadius, constants.firstPointRadiusNm * nauticalMile)
    }

    func test_paths_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertFalse(cases.flights.isEmpty)
        for flightCase in cases.flights {
            let path = try cases.made(flightCase).path
            let expected = flightCase.path
            XCTAssertEqual(path.isReal, expected.isReal, flightCase.name)
            XCTAssertEqual(path.length / nauticalMile, expected.lengthNm, accuracy: 0.01, flightCase.name)
            XCTAssertEqual(path.flownLength / nauticalMile, expected.flownNm, accuracy: 0.01, flightCase.name)
            XCTAssertEqual(path.stretches.map(\.kind.rawValue), expected.stretchKinds, flightCase.name)
            func total(_ kind: FlightPath.Kind) -> Double {
                path.stretches.filter { $0.kind == kind }.map(\.length).reduce(0, +) / nauticalMile
            }
            XCTAssertEqual(total(.seen), expected.seenNm, accuracy: 0.01, flightCase.name)
            XCTAssertEqual(total(.unseen), expected.unseenNm, accuracy: 0.01, flightCase.name)
            XCTAssertEqual(total(.planned), expected.plannedNm, accuracy: 0.01, flightCase.name)
        }
    }

    func test_init_noFlight_isTheGreatCircle() {
        let path = FlightPath(from: louisville, to: philadelphia)
        XCTAssertFalse(path.isReal)
        XCTAssertEqual(path.stretches.map(\.kind), [.planned])
        XCTAssertEqual(path.length, GreatCircle.distance(from: louisville, to: philadelphia), accuracy: 1e-6)
        XCTAssertEqual(path.flownLength, 0)
        XCTAssertEqual(path.knots, [])
    }

    func test_init_stretchesFollowOneAnother() {
        let path = FlightPath(from: louisville, to: philadelphia,
                              flight: flight(trail: [point(0, 38.3, -85.4), point(2, 38.6, -85.0), point(4, 38.9, -84.6)]))
        XCTAssertEqual(path.stretches.count, 4)
        var distance = 0.0
        for stretch in path.stretches {
            XCTAssertEqual(stretch.startDistance, distance, accuracy: 1e-6)
            distance += stretch.length
        }
        XCTAssertEqual(path.length, distance, accuracy: 1e-6)
        XCTAssertEqual(path.knots.map(\.distance), path.stretches.dropLast().map { $0.startDistance + $0.length })
    }

    func test_init_aTrailOutOfOrder_isSortedByTime() {
        let inOrder = [point(0, 38.3, -85.4), point(2, 38.6, -85.0), point(4, 38.9, -84.6)]
        let sorted = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: inOrder))
        let shuffled = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [inOrder[2], inOrder[0], inOrder[1]]))
        XCTAssertEqual(shuffled.knots, sorted.knots)
        XCTAssertEqual(shuffled.length, sorted.length, accuracy: 1e-6)
    }

    func test_init_aFixInTheAirNewerThanTheTrail_isTheLastPlaceSeen() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(fix: fix(2.5, 38.7, -84.9), trail: trail))
        XCTAssertEqual(path.knots.count, 3)
        XCTAssertEqual(path.knots.last?.time, start.addingTimeInterval(150))
        XCTAssertEqual(path.stretches.map(\.kind), [.seen, .seen, .seen, .planned])
    }

    func test_init_aFixNoNewerThanTheTrail_addsNothing() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(fix: fix(2, 38.6, -85.0), trail: trail))
        XCTAssertEqual(path.knots.count, 2)
    }

    func test_init_aFixOnTheGround_addsNothing() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let path = FlightPath(from: louisville, to: philadelphia,
                              flight: flight(state: .ground, fix: fix(30, 38.18, -85.73, isOnGround: true), trail: trail))
        XCTAssertEqual(path.knots.count, 2)
        XCTAssertEqual(path.stretches.last?.kind, .planned)
    }

    func test_init_inTheAirWithNoTrailYet_startsFromTheFix() {
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(fix: fix(1, 38.3, -85.4), trail: []))
        XCTAssertTrue(path.isReal)
        XCTAssertEqual(path.stretches.map(\.kind), [.seen, .planned])
    }

    func test_init_onTheGroundWithNoTrail_isTheGreatCircle() {
        let path = FlightPath(from: louisville, to: philadelphia,
                              flight: flight(state: .ground, fix: fix(1, 38.18, -85.73, isOnGround: true), trail: []))
        XCTAssertFalse(path.isReal)
    }

    func test_init_landed_endsAtTheArrivalAirport_withNothingPlanned() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let landed = flight(state: .landed, fix: fix(9, 39.87, -75.24, isOnGround: true), landedAt: start.addingTimeInterval(8 * 60), trail: trail)
        let path = FlightPath(from: louisville, to: philadelphia, flight: landed)
        XCTAssertTrue(path.hasLanded)
        XCTAssertEqual(path.stretches.map(\.kind), [.seen, .seen, .seen])
        XCTAssertEqual(path.flownLength, path.length)
        XCTAssertEqual(path.knots.last, FlightPath.Knot(time: start.addingTimeInterval(8 * 60), distance: path.length))
    }

    func test_init_landedLongAfterTheLastPoint_endsUnseen() {
        let trail = [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]
        let landed = flight(state: .landed, fix: fix(40, 39.87, -75.24, isOnGround: true), landedAt: start.addingTimeInterval(13 * 60), trail: trail)
        XCTAssertEqual(FlightPath(from: louisville, to: philadelphia, flight: landed).stretches.map(\.kind), [.seen, .seen, .unseen])
    }

    func test_init_pointsExactlyTenMinutesApart_areSeen() {
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [point(0, 38.3, -85.4), point(10, 39.0, -83.0)]))
        XCTAssertEqual(path.stretches.map(\.kind), [.seen, .seen, .planned])
    }

    func test_point_atEachEndAndBeyond_isAnAirport() {
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]))
        for (distance, airport) in [(-10.0, louisville), (0, louisville), (path.length, philadelphia), (path.length + 10, philadelphia)] {
            let place = path.point(atDistance: distance)
            XCTAssertEqual(place.latitude, airport.latitude, accuracy: 1e-9)
            XCTAssertEqual(place.longitude, airport.longitude, accuracy: 1e-9)
        }
    }

    func test_point_atAKnot_isThePlaceSeen() {
        let path = FlightPath(from: louisville, to: philadelphia, flight: flight(trail: [point(0, 38.3, -85.4), point(2, 38.6, -85.0)]))
        let place = path.point(atDistance: path.knots[1].distance)
        XCTAssertEqual(place.latitude, 38.6, accuracy: 1e-6)
        XCTAssertEqual(place.longitude, -85.0, accuracy: 1e-6)
    }
}
```

- [ ] **Step 3: Write the record's failing tests.** Create `CrewluvTests/FlightRecordTests.swift`:

```swift
//
//  FlightRecordTests.swift
//  CrewluvTests
//
//  Where a flight was at any moment, and when it was any distance along (Stage 3 spec §7.2), held to the shared
//  cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class FlightRecordTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile

    func test_records_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertTrue(cases.flights.contains { $0.record != nil })
        for flightCase in cases.flights {
            let record = try cases.made(flightCase).record
            guard let expected = flightCase.record else {
                XCTAssertNil(record, flightCase.name)
                continue
            }
            let made = try XCTUnwrap(record, flightCase.name)
            XCTAssertEqual(made.takeoff?.timeIntervalSince1970 ?? -1, expected.takeoff?.timeIntervalSince1970 ?? -1, accuracy: 0.05, flightCase.name)
            XCTAssertEqual(made.touchdown.timeIntervalSince1970, expected.touchdown.timeIntervalSince1970, accuracy: 0.05, flightCase.name)
            for place in expected.places {
                let name = "\(flightCase.name) at \(place.at)"
                XCTAssertEqual(made.distance(at: place.at) / nauticalMile, place.alongNm, accuracy: 0.01, name)
                let position = made.position(at: place.at)
                XCTAssertEqual(position.latitude, place.point[0], accuracy: 0.0001, name)
                XCTAssertEqual(position.longitude, place.point[1], accuracy: 0.0001, name)
            }
            for time in expected.times {
                XCTAssertEqual(made.time(atDistance: time.alongNm * nauticalMile).timeIntervalSince1970, time.at.timeIntervalSince1970,
                               accuracy: 0.05, "\(flightCase.name) at \(time.alongNm) nm")
            }
        }
    }

    /// Two places seen at one time are a jump, and no moment is part way across it. Everywhere else, the record's two
    /// answers are each other's inverse.
    func test_time_isTheInverseOfDistance_whereverThePlaneDidntJump() throws {
        let cases = try TripMapFixtures.liveCases()
        for flightCase in cases.flights {
            guard let record = try cases.made(flightCase).record else { continue }
            let knots = record.path.knots
            let jumps = zip(knots, knots.dropFirst()).filter { $0.time == $1.time }.map { $0.distance...$1.distance }
            for share in stride(from: 0.01, through: 0.99, by: 0.07) {
                let distance = record.path.length * share
                guard !jumps.contains(where: { $0.contains(distance) }) else { continue }
                XCTAssertEqual(record.distance(at: record.time(atDistance: distance)), distance, accuracy: 0.5,
                               "\(flightCase.name) at \(share)")
            }
        }
    }

    func test_distance_neverGoesBackwards() throws {
        let cases = try TripMapFixtures.liveCases()
        for flightCase in cases.flights {
            guard let record = try cases.made(flightCase).record else { continue }
            var last = -1.0
            var date = flightCase.departure.addingTimeInterval(-3600)
            while date < flightCase.arrival.addingTimeInterval(3 * 3600) {
                let distance = record.distance(at: date)
                XCTAssertGreaterThanOrEqual(distance, last, "\(flightCase.name) at \(date)")
                last = distance
                date.addTimeInterval(97)
            }
            XCTAssertEqual(last, record.path.length, accuracy: 1e-6, flightCase.name)
        }
    }

    func test_init_aPathWithNoPlaceSeen_isNil() throws {
        let origin = CLLocationCoordinate2D(latitude: 38.1744, longitude: -85.736)
        let destination = CLLocationCoordinate2D(latitude: 39.8719, longitude: -75.2411)
        let path = FlightPath(from: origin, to: destination)
        let departure = Date(timeIntervalSince1970: 1_800_000_000)
        let plan = try XCTUnwrap(FlightPlan(departure: departure, arrival: departure.addingTimeInterval(6300), distance: path.length))
        XCTAssertNil(FlightRecord(path: path, plan: plan))
    }
}
```

- [ ] **Step 4: Write `FlightPath`.** Create `Crewluv/Services/TripMap/Live/FlightPath.swift`:

```swift
//
//  FlightPath.swift
//  CrewLuve
//
//  The path a flight is drawn and measured along (Stage 3 spec §6.1). With no live data it's the great circle
//  between the airports, as before. With a trail it's the real path: the departure airport, each place the plane
//  was seen, and the great circle from the last of them to the arrival airport.
//

import CoreLocation

nonisolated struct FlightPath: Sendable {

    nonisolated enum Kind: String, Sendable {
        /// Flown, between two places the plane was seen close enough together.
        case seen
        /// Flown, and nobody saw it: the straight join is a guess.
        case unseen
        /// The great circle the schedule flies: a flight with no trail, or the way ahead of a real plane.
        case planned
    }

    /// One join of the path, a great circle between two places.
    nonisolated struct Stretch: Sendable {
        let start: CLLocationCoordinate2D
        let end: CLLocationCoordinate2D
        let kind: Kind
        /// How far along the path it starts, in meters.
        let startDistance: Double
        let length: Double
    }

    /// A place the plane was seen: when, and how far along the path.
    nonisolated struct Knot: Equatable, Sendable {
        let time: Date
        let distance: Double
    }

    /// Two neighbouring places seen further apart in time than this have an unseen join between them.
    static let unseenGap: TimeInterval = 10 * 60

    /// A first place further than this from the departure airport is joined to it unseen, and doesn't tell the
    /// takeoff's time: 30 nautical miles, in meters.
    static let firstPointRadius: Double = 30 * GreatCircle.metersPerNauticalMile

    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    /// Never empty, from the departure airport to the arrival airport.
    let stretches: [Stretch]
    /// Each place the plane was seen, oldest first, and its landing when that was seen. Empty with no trail.
    let knots: [Knot]
    /// The whole path, flown and ahead, in meters.
    let length: Double
    /// How far along the path the plane was last seen: where the way ahead begins. The whole path once it has landed.
    let flownLength: Double
    /// Whether the flight was seen on the ground at the arrival airport, which ends the path there.
    let hasLanded: Bool

    /// Whether it's a real path, from places the plane was seen.
    var isReal: Bool { !knots.isEmpty }

    /// The path of a flight from `origin` to `destination`: the real one when `flight` has been seen in the air.
    init(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, flight: LiveFlight? = nil) {
        self.origin = origin
        self.destination = destination
        // Oldest first. A stable sort keeps the door's order between points of one time.
        var seen = (flight?.trail ?? []).map { (coordinate: $0.coordinate, time: $0.time) }.sorted { $0.time < $1.time }
        if let fix = flight?.fix, !fix.isOnGround, seen.last.map({ fix.seenAt > $0.time }) ?? true {
            seen.append((fix.coordinate, fix.seenAt))
        }
        guard let first = seen.first, let last = seen.last else {
            let length = GreatCircle.distance(from: origin, to: destination)
            stretches = [Stretch(start: origin, end: destination, kind: .planned, startDistance: 0, length: length)]
            knots = []
            self.length = length
            flownLength = 0
            hasLanded = false
            return
        }
        var stretches: [Stretch] = []
        var knots: [Knot] = []
        var distance = 0.0
        func add(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, _ kind: Kind) {
            let length = GreatCircle.distance(from: start, to: end)
            stretches.append(Stretch(start: start, end: end, kind: kind, startDistance: distance, length: length))
            distance += length
        }
        let isFirstFar = GreatCircle.distance(from: origin, to: first.coordinate) > Self.firstPointRadius
        add(from: origin, to: first.coordinate, isFirstFar ? .unseen : .seen)
        knots.append(Knot(time: first.time, distance: distance))
        for (earlier, later) in zip(seen, seen.dropFirst()) {
            let isGap = later.time.timeIntervalSince(earlier.time) > Self.unseenGap
            add(from: earlier.coordinate, to: later.coordinate, isGap ? .unseen : .seen)
            knots.append(Knot(time: later.time, distance: distance))
        }
        let lastSeenDistance = distance
        if flight?.state == .landed {
            let landedAt = max(flight?.landedAt ?? flight?.fix?.seenAt ?? last.time, last.time)
            let isGap = landedAt.timeIntervalSince(last.time) > Self.unseenGap
            add(from: last.coordinate, to: destination, isGap ? .unseen : .seen)
            knots.append(Knot(time: landedAt, distance: distance))
            hasLanded = true
            flownLength = distance
        } else {
            add(from: last.coordinate, to: destination, .planned)
            hasLanded = false
            flownLength = lastSeenDistance
        }
        self.stretches = stretches
        self.knots = knots
        length = distance
    }

    /// The place `distance` meters along the path. Before its start that's the departure airport, and past its end
    /// the arrival airport.
    func point(atDistance distance: Double) -> CLLocationCoordinate2D {
        let far = min(max(distance, 0), length)
        guard let stretch = stretches.first(where: { far <= $0.startDistance + $0.length }) else { return destination }
        guard stretch.length > 0 else { return stretch.start }
        return GreatCircle.point(from: stretch.start, to: stretch.end, fraction: (far - stretch.startDistance) / stretch.length)
    }
}
```

- [ ] **Step 5: Write `FlightRecord`.** Create `Crewluv/Services/TripMap/Live/FlightRecord.swift`:

```swift
//
//  FlightRecord.swift
//  CrewLuve
//
//  Where a flight with a real path was at any moment, and when it was any distance along it (Stage 3 spec §7.2).
//  The replay, the facts' times and the estimated plane all read it.
//

import CoreLocation

nonisolated struct FlightRecord: Sendable {
    let path: FlightPath
    let plan: FlightPlan
    /// When it left the ground: the time of the first place it was seen, when that's close enough to the departure
    /// airport to tell (spec §7.1).
    let takeoff: Date?
    /// When it touched down, or is estimated to: the last place it was seen, plus the plan's time for the rest.
    let touchdown: Date

    /// Nil for a path with no place the plane was seen: such a flight has no record.
    init?(path: FlightPath, plan: FlightPlan) {
        guard let first = path.knots.first, let last = path.knots.last else { return nil }
        self.path = path
        self.plan = plan
        takeoff = first.distance <= FlightPath.firstPointRadius ? first.time : nil
        touchdown = path.hasLanded ? last.time : last.time.addingTimeInterval(plan.timeToFly(path.length - last.distance))
    }

    /// How far along its path the plane was at `date`, in meters.
    /// - Before the first place it was seen, it flies there from the departure airport at the plan's speed, and
    ///   waits at the airport before that.
    /// - Among the places it was seen, it's between the two either side of `date`, in proportion to the time.
    /// - After the last, it flies the plan to the arrival airport, and stays there. A flight that landed is there.
    func distance(at date: Date) -> Double {
        let knots = path.knots
        guard let first = knots.first, let last = knots.last else { return 0 }
        if date <= first.time {
            return max(0, first.distance - first.time.timeIntervalSince(date) * plan.speed)
        }
        if date >= last.time {
            guard !path.hasLanded else { return path.length }
            let estimated = path.length - plan.distanceLeft(touchdown.timeIntervalSince(date))
            return min(max(estimated, last.distance), path.length)
        }
        for (earlier, later) in zip(knots, knots.dropFirst()) where date < later.time {
            let share = date.timeIntervalSince(earlier.time) / later.time.timeIntervalSince(earlier.time)
            return earlier.distance + (later.distance - earlier.distance) * share
        }
        return last.distance
    }

    /// Where the plane was at `date`.
    func position(at date: Date) -> CLLocationCoordinate2D {
        path.point(atDistance: distance(at: date))
    }

    /// When the plane was `distance` meters along its path: `distance(at:)` the other way round.
    func time(atDistance distance: Double) -> Date {
        let knots = path.knots
        guard let first = knots.first, let last = knots.last else { return touchdown }
        let far = min(max(distance, 0), path.length)
        if far <= first.distance {
            return first.time.addingTimeInterval(-(first.distance - far) / plan.speed)
        }
        if far >= last.distance {
            return path.hasLanded ? last.time : touchdown.addingTimeInterval(-plan.timeToFly(path.length - far))
        }
        for (earlier, later) in zip(knots, knots.dropFirst()) where far <= later.distance {
            guard later.distance > earlier.distance else { return earlier.time }
            let share = (far - earlier.distance) / (later.distance - earlier.distance)
            return earlier.time.addingTimeInterval(later.time.timeIntervalSince(earlier.time) * share)
        }
        return last.time
    }
}
```

- [ ] **Step 6: Run the tests, expecting them to pass.** Todd runs `FlightPathTests` (15 tests) and `FlightRecordTests` (4 tests).

- [ ] **Step 7: Ask to commit.** Suggested message: `feat(crewluv): FlightPath and FlightRecord: a flight's real path from the places it was seen, with the stretches nobody saw, and where the plane was at any moment along it (Stage 3 spec §6.1, §7.2)`.

---

### Task 6: `LiveLabel`, `LiveProgress` and the label's words

**Files:**
- Create: `Crewluv/Services/TripMap/Live/LiveLabel.swift`
- Create: `Crewluv/Services/TripMap/Live/LiveProgress.swift`
- Modify: `Crewluv/Services/TripMap/TripMapWording.swift`
- Test: `CrewluvTests/LiveProgressTests.swift`, `CrewluvTests/LiveLabelTests.swift`

`LiveProgress` is everything about a flight's real plane at one moment. Its plan comes from the leg's scheduled times moved by the reported delay, never from the real times it works out: the ghost and the label measure against the reported delay (spec §13).

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/LiveProgressTests.swift`:

```swift
//
//  LiveProgressTests.swift
//  CrewluvTests
//
//  The real plane at a moment (Stage 3 spec §5, §7.1), held to the shared cases in Fixtures/TripMap.
//

import XCTest
import CoreLocation
@testable import Crewluv

final class LiveProgressTests: XCTestCase {

    private let nauticalMile = TripMapFixtures.nauticalMile

    private func assertEqual(_ date: Date?, _ expected: Date?, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let date, let expected else {
            XCTAssertEqual(date == nil, expected == nil, name, file: file, line: line)
            return
        }
        XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.05, name, file: file, line: line)
    }

    private func assertEqual(_ distance: Double?, nauticalMiles expected: Double?, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let distance, let expected else {
            XCTAssertEqual(distance == nil, expected == nil, name, file: file, line: line)
            return
        }
        XCTAssertEqual(distance / nauticalMile, expected, accuracy: 0.01, name, file: file, line: line)
    }

    private func assertEqual(_ place: CLLocationCoordinate2D?, _ expected: [Double]?, _ name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let place, let expected else {
            XCTAssertEqual(place == nil, expected == nil, name, file: file, line: line)
            return
        }
        XCTAssertEqual(place.latitude, expected[0], accuracy: 0.0001, name, file: file, line: line)
        XCTAssertEqual(place.longitude, expected[1], accuracy: 0.0001, name, file: file, line: line)
    }

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(LiveProgress.freshFor, constants.freshSeconds)
        XCTAssertEqual(LiveProgress.airportRadius, constants.airportRadiusNm * nauticalMile)
    }

    func test_moments_everySharedCase_matches() throws {
        let cases = try TripMapFixtures.liveCases()
        XCTAssertFalse(cases.flights.isEmpty)
        for flightCase in cases.flights {
            let made = try cases.made(flightCase)
            XCTAssertFalse(flightCase.moments.isEmpty, flightCase.name)
            for moment in flightCase.moments {
                let name = "\(flightCase.name) at \(moment.at)"
                let progress = LiveProgress(plan: made.plan, path: made.path, record: made.record, flight: made.flight, at: moment.at)
                XCTAssertEqual(progress.phase.rawValue, moment.phase, name)
                assertEqual(progress.touchdown, moment.touchdown, name)
                assertEqual(progress.liveArrival, moment.liveArrival, name)
                XCTAssertEqual(progress.gapMinutes, moment.gapMinutes, name)
                XCTAssertEqual(progress.label.map(TripMapWording.liveLabel), moment.label, name)
                assertEqual(progress.planeDistance, nauticalMiles: moment.planeAlongNm, name)
                assertEqual(progress.plane, moment.plane, name)
                assertEqual(progress.ghostDistance, nauticalMiles: moment.ghostAlongNm, name)
                assertEqual(progress.ghostDistance.map(made.path.point(atDistance:)), moment.ghost, name)
                assertEqual(progress.start, moment.start, name)
                assertEqual(progress.end, moment.end, name)
            }
        }
    }

    func test_gapMinutes_everySharedCase_roundsHalvesAwayFromZero() throws {
        let gaps = try TripMapFixtures.liveCases().gaps
        XCTAssertFalse(gaps.isEmpty)
        for gap in gaps {
            XCTAssertEqual(LiveProgress.gapMinutes(aheadBy: gap.aheadSeconds), gap.gapMinutes, "\(gap.aheadSeconds) s")
        }
    }

    func test_estimatedPlane_agreesWithTheRecord() throws {
        let cases = try TripMapFixtures.liveCases()
        var checked = 0
        for flightCase in cases.flights {
            let made = try cases.made(flightCase)
            for moment in flightCase.moments where moment.phase == LiveProgress.Phase.estimated.rawValue {
                let progress = LiveProgress(plan: made.plan, path: made.path, record: made.record, flight: made.flight, at: moment.at)
                let record = try XCTUnwrap(made.record)
                XCTAssertEqual(try XCTUnwrap(progress.planeDistance), record.distance(at: moment.at), accuracy: 0.001, flightCase.name)
                XCTAssertEqual(try XCTUnwrap(progress.touchdown).timeIntervalSince1970, record.touchdown.timeIntervalSince1970, accuracy: 0.001)
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }
}
```

Create `CrewluvTests/LiveLabelTests.swift`:

```swift
//
//  LiveLabelTests.swift
//  CrewluvTests
//
//  Ahead of the schedule or behind it, and its words (Stage 3 spec §5.3), held to the shared cases in Fixtures/TripMap.
//

import XCTest
@testable import Crewluv

final class LiveLabelTests: XCTestCase {

    func test_constants_matchTheSharedCases() throws {
        XCTAssertEqual(LiveLabel.onScheduleWithin, try TripMapFixtures.liveCases().constants.onScheduleMinutes)
    }

    func test_labels_everySharedCase_matches() throws {
        let labels = try TripMapFixtures.liveCases().labels
        XCTAssertFalse(labels.isEmpty)
        for labelCase in labels {
            let phase = try XCTUnwrap(LiveProgress.Phase(rawValue: labelCase.phase), labelCase.phase)
            let label = LiveLabel(phase: phase, gapMinutes: labelCase.gapMinutes)
            XCTAssertEqual(label.map(TripMapWording.liveLabel), labelCase.label,
                           "\(labelCase.phase), \(labelCase.gapMinutes.map(String.init) ?? "no gap")")
        }
    }

    func test_init_inTheAir_sixMinutesEitherWay_isAheadOrBehind() {
        XCTAssertEqual(LiveLabel(phase: .inAir, gapMinutes: 6), .ahead(minutes: 6, isEstimated: false))
        XCTAssertEqual(LiveLabel(phase: .inAir, gapMinutes: -6), .behind(minutes: 6, isEstimated: false))
        XCTAssertEqual(LiveLabel(phase: .estimated, gapMinutes: -6), .behind(minutes: 6, isEstimated: true))
    }

    func test_init_withinFiveMinutes_isOnSchedule() {
        XCTAssertEqual(LiveLabel(phase: .inAir, gapMinutes: 5), .onSchedule)
        XCTAssertEqual(LiveLabel(phase: .estimated, gapMinutes: -5), .onSchedule)
        XCTAssertEqual(LiveLabel(phase: .landed, gapMinutes: -5), .landedOnTime)
        XCTAssertEqual(LiveLabel(phase: .onGround, gapMinutes: -5), .stillOnGround(minutesBehind: nil))
    }

    func test_init_noGap_orNotOnTheMap_isNil() {
        XCTAssertNil(LiveLabel(phase: .inAir, gapMinutes: nil))
        XCTAssertNil(LiveLabel(phase: .onGround, gapMinutes: nil))
        XCTAssertNil(LiveLabel(phase: .notLive, gapMinutes: 12))
        XCTAssertNil(LiveLabel(phase: .elsewhere, gapMinutes: 12))
    }

    func test_minutesText_writesHoursAsTheCountdownDoes() {
        XCTAssertEqual(TripMapWording.minutesText(45), "45 min")
        XCTAssertEqual(TripMapWording.minutesText(120), "2 h")
        XCTAssertEqual(TripMapWording.minutesText(130), "2 h 10 min")
    }
}
```

- [ ] **Step 2: Write `LiveLabel`.** Create `Crewluv/Services/TripMap/Live/LiveLabel.swift`:

```swift
//
//  LiveLabel.swift
//  CrewLuve
//
//  Whether the real plane is ahead of the schedule or behind it (Stage 3 spec §5.3). `TripMapWording` writes it.
//

import Foundation

nonisolated enum LiveLabel: Equatable, Sendable {
    case onSchedule
    /// `isEstimated` once the plane hasn't been seen for a while: the words gain "About".
    case ahead(minutes: Int, isEstimated: Bool)
    case behind(minutes: Int, isEstimated: Bool)
    /// Past the plan's takeoff and not off the ground. `minutesBehind` is nil for the first few minutes.
    case stillOnGround(minutesBehind: Int?)
    case landedOnTime
    case landedEarly(minutes: Int)
    case landedLate(minutes: Int)

    /// A gap of this many minutes or fewer, either way, is on schedule.
    static let onScheduleWithin = 5

    /// The label for a flight in `phase`, `gapMinutes` ahead of the plan (behind when negative). Nil where there's
    /// no gap to tell, and for a flight that isn't live or is somewhere else.
    init?(phase: LiveProgress.Phase, gapMinutes: Int?) {
        guard let gapMinutes else { return nil }
        let size = abs(gapMinutes)
        let isOnSchedule = size <= Self.onScheduleWithin
        switch phase {
        case .inAir, .estimated:
            let isEstimated = phase == .estimated
            if isOnSchedule {
                self = .onSchedule
            } else if gapMinutes > 0 {
                self = .ahead(minutes: size, isEstimated: isEstimated)
            } else {
                self = .behind(minutes: size, isEstimated: isEstimated)
            }
        case .onGround:
            self = .stillOnGround(minutesBehind: isOnSchedule ? nil : size)
        case .landed:
            if isOnSchedule {
                self = .landedOnTime
            } else if gapMinutes > 0 {
                self = .landedEarly(minutes: size)
            } else {
                self = .landedLate(minutes: size)
            }
        case .notLive, .elsewhere:
            return nil
        }
    }
}
```

- [ ] **Step 3: Write `LiveProgress`.** Create `Crewluv/Services/TripMap/Live/LiveProgress.swift`:

```swift
//
//  LiveProgress.swift
//  CrewLuve
//
//  A flight's real plane at one moment (Stage 3 spec §5, §7.1): whether it's live, when it will land, how far
//  ahead of the schedule or behind it that is, where the real plane and the ghost are, and the leg's real times.
//

import CoreLocation

nonisolated struct LiveProgress: Sendable {

    nonisolated enum Phase: String, Sendable {
        /// No live data, never seen, or last seen on the ground too long ago: the schedule's plane alone.
        case notLive
        /// Seen on the ground at the departure airport.
        case onGround
        case inAir
        /// Last seen in the air too long ago: the real plane flies the plan from there.
        case estimated
        case landed
        /// On the ground anywhere else: a diversion.
        case elsewhere
    }

    /// A fix this old or newer is live, by Crewlu Cloud's clock.
    static let freshFor: TimeInterval = 120

    /// On the ground this close to the departure airport is at it: 10 nautical miles, in meters.
    static let airportRadius: Double = 10 * GreatCircle.metersPerNauticalMile

    let phase: Phase
    /// When the real plane touches down, or did. Nil where there's no estimate.
    let touchdown: Date?
    /// When it reaches the gate: `touchdown` plus the plan's taxi in.
    let liveArrival: Date?
    /// The plan's touchdown minus `touchdown`, to the nearest minute. Ahead is positive.
    let gapMinutes: Int?
    let label: LiveLabel?
    /// How far along the path the real plane is, in meters. Nil when it isn't shown, or isn't on the path.
    let planeDistance: Double?
    /// Where the real plane is. Nil when it isn't shown.
    let plane: CLLocationCoordinate2D?
    /// How far along the path an on-schedule plane would be. Nil when the ghost isn't shown.
    let ghostDistance: Double?
    /// The leg's real times (spec §7.1): its start, moved earlier by an early takeoff, and its end, the live arrival
    /// where there is one. Otherwise they're the plan's.
    let start: Date
    let end: Date

    /// - Parameters:
    ///   - plan: the leg's plan, from its scheduled times moved by the reported delay.
    ///   - path: the leg's path, made from `flight`.
    ///   - record: the path's record, when it's a real one.
    ///   - flight: the leg's live data, or nil when Crewlu Cloud answered none.
    ///   - now: the moment, by Crewlu Cloud's clock.
    init(plan: FlightPlan, path: FlightPath, record: FlightRecord?, flight: LiveFlight?, at now: Date) {
        let fix = flight?.fix
        let phase = Self.phase(of: flight, origin: path.origin, at: now)
        self.phase = phase

        var touchdown: Date?
        switch phase {
        case .inAir, .estimated:
            touchdown = fix.map {
                $0.seenAt.addingTimeInterval(plan.timeToFly(GreatCircle.distance(from: $0.coordinate, to: path.destination)))
            }
        case .onGround:
            touchdown = now >= plan.takeoff ? now.addingTimeInterval(plan.timeInAir) : nil
        case .landed:
            // The record's landing, where there is one, so the two can't disagree.
            touchdown = record?.touchdown ?? flight?.landedAt ?? fix?.seenAt
        case .notLive, .elsewhere:
            touchdown = nil
        }
        self.touchdown = touchdown
        liveArrival = touchdown?.addingTimeInterval(plan.taxiIn)
        gapMinutes = touchdown.map { Self.gapMinutes(aheadBy: plan.touchdown.timeIntervalSince($0)) }
        label = LiveLabel(phase: phase, gapMinutes: gapMinutes)

        switch phase {
        case .inAir:
            planeDistance = path.flownLength
            plane = fix?.coordinate
        case .estimated:
            let left = touchdown.map { plan.distanceLeft($0.timeIntervalSince(now)) } ?? 0
            let distance = min(max(path.length - left, path.flownLength), path.length)
            planeDistance = distance
            plane = path.point(atDistance: distance)
        case .landed:
            planeDistance = path.length
            plane = path.destination
        case .onGround:
            planeDistance = 0
            plane = fix?.coordinate
        case .elsewhere:
            planeDistance = nil
            plane = fix?.coordinate
        case .notLive:
            planeDistance = nil
            plane = nil
        }

        switch phase {
        case .inAir, .estimated, .onGround:
            ghostDistance = now < plan.takeoff ? 0 : max(0, path.length - plan.distanceLeft(plan.touchdown.timeIntervalSince(now)))
        case .landed, .elsewhere, .notLive:
            ghostDistance = nil
        }

        let earlyStart = record?.takeoff?.addingTimeInterval(-plan.taxiOut)
        start = earlyStart.map { min($0, plan.departure) } ?? plan.departure
        end = liveArrival ?? plan.arrival
    }

    /// A gap of `seconds` ahead (behind when negative) in whole minutes, halves away from zero.
    static func gapMinutes(aheadBy seconds: TimeInterval) -> Int {
        Int((seconds / 60).rounded(.toNearestOrAwayFromZero))
    }

    /// What the live data says of a flight from `origin` at `now` (spec §5.1).
    private static func phase(of flight: LiveFlight?, origin: CLLocationCoordinate2D, at now: Date) -> Phase {
        guard let flight, let fix = flight.fix else { return .notLive }
        let isFresh = now.timeIntervalSince(fix.seenAt) <= freshFor
        switch flight.state {
        case .waiting:
            return .notLive
        case .landed:
            return .landed
        case .airborne:
            return isFresh ? .inAir : .estimated
        case .ground:
            guard isFresh else { return .notLive }
            return GreatCircle.distance(from: fix.coordinate, to: origin) <= airportRadius ? .onGround : .elsewhere
        }
    }
}
```

- [ ] **Step 4: Write the label's words.** In `Crewluv/Services/TripMap/TripMapWording.swift`, just before the line `    // MARK: - The bar under the map`, add this and a blank line after it:

```swift
    // MARK: - The real plane

    /// "12 min ahead", "About 20 min behind", "Still on the ground · 20 min behind" or "Landed 8 min early": the real
    /// plane against the schedule (Stage 3 spec §5.3).
    static func liveLabel(_ label: LiveLabel) -> String {
        switch label {
        case .onSchedule:
            return "On schedule"
        case .ahead(let minutes, let isEstimated):
            return "\(isEstimated ? "About " : "")\(minutesText(minutes)) ahead"
        case .behind(let minutes, let isEstimated):
            return "\(isEstimated ? "About " : "")\(minutesText(minutes)) behind"
        case .stillOnGround(let minutesBehind):
            return minutesBehind.map { "Still on the ground · \(minutesText($0)) behind" } ?? "Still on the ground"
        case .landedOnTime:
            return "Landed on time"
        case .landedEarly(let minutes):
            return "Landed \(minutesText(minutes)) early"
        case .landedLate(let minutes):
            return "Landed \(minutesText(minutes)) late"
        }
    }

    /// "45 min", "2 h" or "2 h 10 min".
    static func minutesText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        if rest == 0 { return "\(hours) h" }
        return "\(hours) h \(rest) min"
    }
```

- [ ] **Step 5: Let the countdown use the same words.** In the same file, replace:

```swift
        guard minutes > 0 else { return "Landing now" }
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "Landing in \(rest) min" }
        if rest == 0 { return "Landing in \(hours) h" }
        return "Landing in \(hours) h \(rest) min"
    }
```

with:

```swift
        guard minutes > 0 else { return "Landing now" }
        return "Landing in \(minutesText(minutes))"
    }
```

- [ ] **Step 6: Run the tests, expecting them to pass.** Todd runs `LiveProgressTests` (4 tests), `LiveLabelTests` (6 tests), and `TripMapWordingTests` and `TripFactsTests`, which hold the countdown's words as they were.

- [ ] **Step 7: Ask to commit.** Suggested message: `feat(crewluv): LiveProgress, the real plane at a moment: live, estimated or landed, a landing estimate anchored on the takeoff, how far ahead or behind that is in words, where the ghost flies, and the leg's real times (Stage 3 spec §5, §7.1)`.

---

### Task 7: `LiveWindow`

**Files:**
- Create: `Crewluv/Services/TripMap/Live/LiveWindow.swift`
- Test: `CrewluvTests/LiveWindowTests.swift`

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/LiveWindowTests.swift`:

```swift
//
//  LiveWindowTests.swift
//  CrewluvTests
//
//  When a flight's live data is asked for (Stage 3 spec §10.2), held to the shared cases in Fixtures/TripMap.
//

import XCTest
@testable import Crewluv

final class LiveWindowTests: XCTestCase {

    func test_constants_matchTheSharedCases() throws {
        let constants = try TripMapFixtures.liveCases().constants
        XCTAssertEqual(LiveWindow.opensBefore, constants.windowOpensMinutesBefore * 60)
        XCTAssertEqual(LiveWindow.closesAfter, constants.windowClosesHoursAfter * 3600)
        XCTAssertEqual(LiveWindow.keepsFor, constants.windowKeepsMinutes * 60)
        XCTAssertEqual(LiveWindow.endsAfter, constants.windowEndsHoursAfter * 3600)
    }

    func test_isOpen_everySharedCase_matches() throws {
        let windows = try TripMapFixtures.liveCases().windows
        XCTAssertFalse(windows.isEmpty)
        for window in windows {
            let flight = window.flight.map { LiveFlight($0, trail: $0.trail) }
            XCTAssertEqual(LiveWindow.isOpen(departure: window.departure, arrival: window.arrival, flight: flight, at: window.at),
                           window.isOpen, window.name)
        }
    }
}
```

- [ ] **Step 2: Write `LiveWindow`.** Create `Crewluv/Services/TripMap/Live/LiveWindow.swift`:

```swift
//
//  LiveWindow.swift
//  CrewLuve
//
//  When a flight's live data is worth asking for (Stage 3 spec §10.2, and CrewLu's partner-api.md): the same
//  window Crewlu Cloud watches it in.
//

import Foundation

nonisolated enum LiveWindow {

    /// It opens this long before the flight leaves the gate.
    static let opensBefore: TimeInterval = 30 * 60

    /// It closes this long after the flight reaches the gate.
    static let closesAfter: TimeInterval = 2 * 3600

    /// Past that, it stays open while the flight is in the air with a fix newer than this.
    static let keepsFor: TimeInterval = 30 * 60

    /// And never longer than this after the flight reaches the gate.
    static let endsAfter: TimeInterval = 12 * 3600

    /// Whether the window of a flight leaving the gate at `departure` and reaching it at `arrival`, both moved by any
    /// reported delay, is open at `now`. `flight` is its live data so far.
    static func isOpen(departure: Date, arrival: Date, flight: LiveFlight?, at now: Date) -> Bool {
        guard now >= departure.addingTimeInterval(-opensBefore), flight?.state != .landed else { return false }
        if now < arrival.addingTimeInterval(closesAfter) { return true }
        guard flight?.state == .airborne, let fix = flight?.fix else { return false }
        return fix.seenAt > now.addingTimeInterval(-keepsFor) && now < arrival.addingTimeInterval(endsAfter)
    }
}
```

- [ ] **Step 3: Run the tests, expecting them to pass.** Todd runs `LiveWindowTests`: 2 tests.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): LiveWindow, when a flight's live data is worth asking for: from 30 minutes before it leaves to 2 hours after it arrives, and longer while it's still seen in the air (Stage 3 spec §10.2)`.

---

### Task 8: `LiveFlightSource`

**Files:**
- Create: `Crewluv/Services/TripMap/Live/LiveFlightSource.swift`
- Test: `CrewluvTests/LiveFlightSourceTests.swift`

The source keeps each flight by its leg's id. It sends the last answer's cursor back, adds the new trail points to the ones it has, and asks again for every point when a trail doesn't add up to the count Crewlu Cloud gives. It takes no answer for a key this device has since replaced, and starts again from nothing under another key.

Don't write `@MainActor` on the class (see "Where this plan settles details").

- [ ] **Step 1: Write the failing tests.** Create `CrewluvTests/LiveFlightSourceTests.swift`:

```swift
//
//  LiveFlightSourceTests.swift
//  CrewluvTests
//
//  When the live plane is asked for, and what's kept of each answer (Stage 3 spec §11)
//

import Foundation
import Testing
@testable import Crewluv

@MainActor
final class LiveFlightSourceTests {
    private let door = StandInPartnerDoor()
    private let keys = InMemoryDeviceKeyStore()
    private let clock = HandClock()
    private var isOnCrewluCloud = true
    private var timesSharingEnded = 0
    /// This device's clock.
    private var now = Date(timeIntervalSince1970: 1_794_600_000)

    init() {
        keys.key = Make.key
    }

    private func source() -> LiveFlightSource {
        LiveFlightSource(
            door: door, keys: keys,
            isOnCrewluCloud: { self.isOnCrewluCloud },
            endSharing: { self.timesSharingEnded += 1 },
            timer: RepeatingRefresh(interval: LiveFlightSource.interval, sleep: clock.sleep),
            now: { self.now }
        )
    }

    /// A trail point `minutes` after the test's start.
    private func point(_ minutes: Double) -> LiveFlight.TrailPoint {
        LiveFlight.TrailPoint(time: now.addingTimeInterval(minutes * 60), latitude: 38 + minutes / 10, longitude: -85, altitudeFeet: 30_000)
    }

    /// One of an answer's flights, with trail points at `minutes`. `count` is what Crewlu Cloud says the flight has in
    /// all: as many as the answer brings, unless said.
    private func flight(
        _ legID: String, state: LiveFlight.State = .airborne, points minutes: [Double] = [], count: Int? = nil, seenAt: Date? = nil
    ) -> PartnerLiveAnswer.Flight {
        let fix = state == .waiting ? nil : LiveFlight.Fix(
            latitude: 39, longitude: -85, altitudeFeet: 30_000, groundSpeedKnots: 430, trackDegrees: 80,
            isOnGround: false, registration: nil, typeCode: nil, seenAt: seenAt ?? now
        )
        return PartnerLiveAnswer.Flight(legID: legID, callsign: "UPS207", state: state, fix: fix, landedAt: nil,
                                        trail: minutes.map(point), trailCount: count ?? minutes.count)
    }

    private func answer(
        cursor: Int, _ flights: [PartnerLiveAnswer.Flight] = [], now serverNow: Date? = nil
    ) -> Result<PartnerLiveAnswer, PartnerDoorError> {
        .success(PartnerLiveAnswer(now: serverNow ?? now, cursor: cursor, flights: flights))
    }

    /// The times of a flight's trail, in minutes after the test's start.
    private func minutes(of legID: String, in source: LiveFlightSource) -> [Double]? {
        source.flights[legID]?.trail.map { $0.time.timeIntervalSince(now) / 60 }
    }

    // MARK: - Asking

    @Test func test_screenCameToFront_asksOnce_withThisDevicesKey_andNoCursor() async {
        door.liveAnswers = [answer(cursor: 0)]
        let source = source()

        await source.screenCameToFront()

        #expect(door.lives.map(\.key) == [Make.key])
        #expect(door.lives.map(\.after) == [nil])
        source.screenLeftFront()
    }

    @Test func test_ask_keepsEachFlightByItsLegsID() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0, 2]), flight("leg-2", state: .waiting)])]
        let source = source()

        await source.ask()

        #expect(Set(source.flights.keys) == ["leg-1", "leg-2"])
        #expect(source.flights["leg-1"]?.callsign == "UPS207")
        #expect(source.flights["leg-1"]?.state == .airborne)
        #expect(minutes(of: "leg-1", in: source) == [0, 2])
        #expect(source.flights["leg-2"]?.state == .waiting)
        #expect(source.flights["leg-2"]?.fix == nil)
    }

    @Test func test_ask_sendsTheLastCursorBack_andAddsTheNewPoints() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0, 2])]),
            answer(cursor: 9, [flight("leg-1", points: [4], count: 3)]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4])
    }

    @Test func test_ask_aTrailThatDoesntAddUp_asksAgainForEveryPoint() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0, 2])]),
            // Two points here and one new make three, and Crewlu Cloud says the flight has four.
            answer(cursor: 9, [flight("leg-1", points: [6], count: 4)]),
            answer(cursor: 9, [flight("leg-1", points: [0, 2, 4, 6])]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7, nil])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4, 6])
    }

    @Test func test_ask_aFlightFirstAnsweredAfterTheCursor_asksAgainForEveryPoint() async {
        door.liveAnswers = [
            answer(cursor: 7),
            // Its points from before the cursor didn't come.
            answer(cursor: 9, [flight("leg-1", points: [4], count: 3)]),
            answer(cursor: 9, [flight("leg-1", points: [0, 2, 4])]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7, nil])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4])
    }

    @Test func test_ask_aWholeAnswer_isTakenAsItComes() async {
        // Asked without a cursor, there's nothing to ask again for.
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0, 2], count: 5)])]
        let source = source()

        await source.ask()

        #expect(door.lives.count == 1)
        #expect(minutes(of: "leg-1", in: source) == [0, 2])
    }

    @Test func test_ask_aFlightNoLongerAnswered_isForgotten() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0]), flight("leg-2", points: [2])]),
            answer(cursor: 7, [flight("leg-1", count: 1)]),
        ]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(Set(source.flights.keys) == ["leg-1"])
        #expect(minutes(of: "leg-1", in: source) == [0])
    }

    @Test func test_ask_whenCrewluCloudCantBeReached_keepsWhatItHas() async {
        door.liveAnswers = [
            answer(cursor: 7, [flight("leg-1", points: [0, 2])]),
            .failure(.unavailable),
            .failure(.refused(.tryLater)),
            answer(cursor: 9, [flight("leg-1", points: [4], count: 3)]),
        ]
        let source = source()

        await source.ask()
        await source.ask()
        await source.ask()

        #expect(minutes(of: "leg-1", in: source) == [0, 2])
        #expect(timesSharingEnded == 0)

        await source.ask()

        #expect(door.lives.map(\.after) == [nil, 7, 7, 7])
        #expect(minutes(of: "leg-1", in: source) == [0, 2, 4])
    }

    @Test func test_ask_whileOneIsUnderWay_asksNothingMore() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        await source.ask()

        #expect(door.lives.count == 1)
        door.release()
        await asking.value
        #expect(minutes(of: "leg-1", in: source) == [0])
    }

    // MARK: - The Connection

    @Test func test_ask_sharingEnded_forgetsTheFlights_andTellsTheStatusSource() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])]), .failure(.refused(.sharingEnded))]
        let source = source()

        await source.ask()
        await source.ask()

        #expect(source.flights.isEmpty)
        #expect(timesSharingEnded == 1)
    }

    @Test func test_ask_sharingEnded_forAKeySinceReplaced_endsNothing() async {
        door.liveAnswers = [.failure(.refused(.sharingEnded))]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        keys.key = String(repeating: "7a", count: 32)
        door.release()
        await asking.value

        #expect(timesSharingEnded == 0)
    }

    @Test func test_ask_anAnswerForAKeySinceReplaced_isLeftOut() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        door.holdsLives = true
        let source = source()

        let asking = Task { await source.ask() }
        await eventually { door.lives.count == 1 }
        keys.key = String(repeating: "7a", count: 32)
        door.release()
        await asking.value

        #expect(source.flights.isEmpty)
    }

    @Test func test_ask_withAnotherKey_startsAgainFromNothing() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])]), answer(cursor: 3, [flight("leg-9", points: [2])])]
        let source = source()
        let other = String(repeating: "7a", count: 32)

        await source.ask()
        keys.key = other
        await source.ask()

        #expect(door.lives.map(\.key) == [Make.key, other])
        #expect(door.lives.map(\.after) == [nil, nil])
        #expect(Set(source.flights.keys) == ["leg-9"])
    }

    @Test func test_ask_onICloud_asksNothing_andForgetsTheFlights() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        let source = source()

        await source.ask()
        isOnCrewluCloud = false
        await source.ask()

        #expect(door.lives.count == 1)
        #expect(source.flights.isEmpty)
    }

    @Test func test_ask_withAKeyThatCantBeRead_asksNothing_andKeepsWhatItHas() async {
        door.liveAnswers = [answer(cursor: 7, [flight("leg-1", points: [0])])]
        let source = source()

        await source.ask()
        keys.readFails = true
        await source.ask()

        #expect(door.lives.count == 1)
        #expect(minutes(of: "leg-1", in: source) == [0])
    }

    // MARK: - Crewlu Cloud's Clock

    @Test func test_serverTime_followsCrewluCloudsClock() async {
        door.liveAnswers = [answer(cursor: 0, now: now.addingTimeInterval(90))]
        let source = source()

        #expect(source.serverTime(at: now) == now)
        await source.ask()

        #expect(source.clockOffset == 90)
        #expect(source.serverTime(at: now.addingTimeInterval(10)) == now.addingTimeInterval(100))
    }

    // MARK: - The 30-Second Check

    @Test func test_check_withAWindowOpen_asksEvery30Seconds() async {
        door.liveAnswers = [answer(cursor: 0), answer(cursor: 0), answer(cursor: 0)]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(-3600), arrival: now.addingTimeInterval(3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        #expect(clock.sleeps == [.seconds(30)])
        clock.tick()
        await eventually { door.lives.count == 2 }
        await eventually { clock.waitingCount == 1 }
        clock.tick()
        await eventually { door.lives.count == 3 }

        source.screenLeftFront()
    }

    @Test func test_check_withNoWindowOpen_asksNothing() async {
        door.liveAnswers = [answer(cursor: 0), answer(cursor: 0)]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(2 * 3600), arrival: now.addingTimeInterval(4 * 3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        clock.tick()
        // The check has run and gone back to sleep.
        await eventually { clock.sleeps.count == 2 }

        #expect(door.lives.count == 1)
        source.screenLeftFront()
    }

    @Test func test_check_pastTheWindow_whileTheFlightIsStillSeenInTheAir_keepsAsking() async {
        let seenAt = now.addingTimeInterval(-5 * 60)
        door.liveAnswers = [answer(cursor: 0, [flight("leg-1", seenAt: seenAt)]), answer(cursor: 0, [flight("leg-1", seenAt: seenAt)])]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(-11 * 3600), arrival: now.addingTimeInterval(-3 * 3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        clock.tick()
        await eventually { door.lives.count == 2 }

        source.screenLeftFront()
    }

    @Test func test_check_measuresTheWindowByCrewluCloudsClock() async {
        // This device's clock is two hours slow: by it, the flight's window hasn't opened.
        door.liveAnswers = [answer(cursor: 0, now: now.addingTimeInterval(2 * 3600)), answer(cursor: 0, now: now.addingTimeInterval(2 * 3600))]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(3600), arrival: now.addingTimeInterval(5 * 3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        clock.tick()
        await eventually { door.lives.count == 2 }

        source.screenLeftFront()
    }

    @Test func test_screenLeftFront_stopsTheCheck() async {
        door.liveAnswers = [answer(cursor: 0)]
        let source = source()
        source.watch([LiveFlightSource.Leg(id: "leg-1", departure: now.addingTimeInterval(-3600), arrival: now.addingTimeInterval(3600))])

        await source.screenCameToFront()
        await eventually { clock.waitingCount == 1 }
        source.screenLeftFront()
        await eventually { clock.waitingCount == 0 }

        #expect(door.lives.count == 1)
    }
}
```

- [ ] **Step 2: Write `LiveFlightSource`.** Create `Crewluv/Services/TripMap/Live/LiveFlightSource.swift`:

```swift
//
//  LiveFlightSource.swift
//  CrewLuve
//
//  Asks Crewlu Cloud for the live plane while the status screen is in front
//

import Foundation
import Observation

/// The pilot's flights with live data, for one status screen (Stage 3 spec §11). It asks Crewlu Cloud's
/// partner_live once each time the screen comes to the front, and every 30 seconds while a flight's window is open.
/// It never asks in the background, and never while this device follows its pilot through iCloud.
@Observable
final class LiveFlightSource {

    /// A flight leg of the summary to ask about: its id, and its gate times moved by any reported delay.
    nonisolated struct Leg: Equatable, Sendable {
        let id: String
        let departure: Date
        let arrival: Date
    }

    /// How often it asks while a flight's window is open.
    static let interval: Duration = .seconds(30)

    /// Each flight Crewlu Cloud answered, by its leg's id. A leg with none has no live data.
    private(set) var flights: [String: LiveFlight] = [:]

    /// Crewlu Cloud's clock minus this device's, as of the last answer, so a wrong phone clock doesn't age a fix.
    @ObservationIgnored private(set) var clockOffset: TimeInterval = 0

    @ObservationIgnored private let door: LiveFlightDoor
    @ObservationIgnored private let keys: DeviceKeyStore
    @ObservationIgnored private let isOnCrewluCloud: () -> Bool
    @ObservationIgnored private let endSharing: () -> Void
    @ObservationIgnored private let timer: RepeatingRefresh
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var legs: [Leg] = []
    /// The last answer's cursor, sent back so only the trail points since then come.
    @ObservationIgnored private var cursor: Int?
    /// The key the flights were answered for. Another key's flights are another connection's.
    @ObservationIgnored private var answeredKey: String?
    @ObservationIgnored private var isAsking = false

    /// - Parameters:
    ///   - isOnCrewluCloud: whether this device follows its pilot through Crewlu Cloud.
    ///   - endSharing: tells the status source the pilot stopped sharing with this device.
    ///   - timer: runs the 30-second check.
    ///   - now: this device's clock.
    init(
        door: LiveFlightDoor = LivePartnerDoor(),
        keys: DeviceKeyStore = KeychainDeviceKeyStore(),
        isOnCrewluCloud: @escaping () -> Bool = { PilotStatusSource.shared.isOnCrewluCloud },
        endSharing: @escaping () -> Void = { PilotStatusSource.shared.endSharing() },
        timer: RepeatingRefresh = RepeatingRefresh(interval: LiveFlightSource.interval),
        now: @escaping () -> Date = { Date() }
    ) {
        self.door = door
        self.keys = keys
        self.isOnCrewluCloud = isOnCrewluCloud
        self.endSharing = endSharing
        self.timer = timer
        self.now = now
    }

    /// Crewlu Cloud's time when this device's clock says `date`. Fix ages and windows are measured against it.
    func serverTime(at date: Date) -> Date {
        date.addingTimeInterval(clockOffset)
    }

    /// The summary's flight legs, whenever they change: the 30-second check asks while one's window is open.
    func watch(_ legs: [Leg]) {
        self.legs = legs
    }

    /// The screen came to the front: asks once, then every 30 seconds while a flight's window is open.
    func screenCameToFront() async {
        timer.start { [weak self] in
            await self?.check()
        }
        await ask()
    }

    /// The screen left the front: nothing is asked until it's back.
    func screenLeftFront() {
        timer.stop()
    }

    /// Asks Crewlu Cloud once, and takes its answer. A call under way is left to finish.
    func ask() async {
        guard !isAsking else { return }
        guard isOnCrewluCloud() else {
            forget()
            return
        }
        guard let key = try? keys.deviceKey() else { return }
        if key != answeredKey {
            forget()
        }
        isAsking = true
        defer { isAsking = false }
        let sent = cursor
        do {
            let answer = try await door.live(key: key, after: sent)
            // An answer for a key this device has since replaced, say by switching, is another connection's.
            guard (try? keys.deviceKey()) == key else { return }
            if !take(answer, isWhole: sent == nil) {
                // A trail doesn't add up: a point reached Crewlu Cloud after one with a later id, or the flight is
                // new here and has points from before the cursor. Every point, then.
                let whole = try await door.live(key: key, after: nil)
                guard (try? keys.deviceKey()) == key else { return }
                _ = take(whole, isWhole: true)
            }
            answeredKey = key
        } catch .refused(.sharingEnded) {
            // A refusal for a key this device has since replaced ends nothing.
            guard (try? keys.deviceKey()) == key else { return }
            forget()
            endSharing()
        } catch {
            // Crewlu Cloud couldn't be reached, or refused for another reason: what's here stays.
        }
    }

    // MARK: - Private

    /// The 30-second check: asks while any flight's window is open.
    private func check() async {
        let now = serverTime(at: now())
        let isAnyWindowOpen = legs.contains {
            LiveWindow.isOpen(departure: $0.departure, arrival: $0.arrival, flight: flights[$0.id], at: now)
        }
        guard isAnyWindowOpen else { return }
        await ask()
    }

    /// Makes `answer` the flights. One that isn't whole brings each flight's points since the cursor, which go after
    /// the points already here. False, changing nothing, when a trail then holds another number of points than
    /// Crewlu Cloud says the flight has. A whole answer is taken as it comes.
    private func take(_ answer: PartnerLiveAnswer, isWhole: Bool) -> Bool {
        var answered: [String: LiveFlight] = [:]
        for flight in answer.flights {
            let trail = isWhole ? flight.trail : (flights[flight.legID]?.trail ?? []) + flight.trail
            guard isWhole || trail.count == flight.trailCount else { return false }
            answered[flight.legID] = LiveFlight(flight, trail: trail)
        }
        if flights != answered {
            flights = answered
        }
        cursor = answer.cursor
        clockOffset = answer.now.timeIntervalSince(now())
        return true
    }

    /// Forgets the flights and the cursor: they were another connection's, or sharing has ended.
    private func forget() {
        if !flights.isEmpty {
            flights = [:]
        }
        cursor = nil
        answeredKey = nil
    }
}
```

- [ ] **Step 3: Run the tests, expecting them to pass.** Todd runs `LiveFlightSourceTests`: 21 tests.

- [ ] **Step 4: Ask to commit.** Suggested message: `feat(crewluv): LiveFlightSource asks Crewlu Cloud for the live plane when the status screen comes to the front and every 30 seconds while a flight's window is open, keeps each flight's trail whole, and measures by Crewlu Cloud's clock (Stage 3 spec §11)`.

---

### Task 9: Review, the docs and the record

**Files:**
- Modify: `CLAUDE.md`
- Modify: this plan

- [ ] **Step 1: Review the whole branch.** Dispatch `superpowers:code-reviewer` (sonnet) on this plan's commits, with the spec's §4 to §7, §10.6 and §11, and this plan's list of where it differs. Use `superpowers:receiving-code-review` on what comes back. A fix that changes an answer goes in the reference first, then the cases are written again (Task 2, Step 3), then the Swift.

- [ ] **Step 2: Todd runs every test class of this plan once more,** and the whole `CrewluvTests` scheme if he wants the rest checked too.

- [ ] **Step 3: Update `CLAUDE.md`.** Under "#### Trip Map", after the bullet that begins "`CrewluvTests/Fixtures/TripMap/progress-cases.json` holds", add:

```markdown
- The real plane's engine (Stage 3 spec `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`) is in `Services/TripMap/Live/`, and nothing shows it yet. `FlightPlan` is the schedule's plan the real plane is measured against. `FlightPath` is a flight's path, real once the plane has been seen in the air, and `FlightRecord` where it was at any moment. `LiveProgress` is the real plane at one moment: live, estimated or landed, its landing estimate and label, where the ghost flies, and the leg's real times. `LiveFlightSource` asks Crewlu Cloud's `partner_live` once when the screen comes to the front and every 30 seconds while a flight's window is open (`LiveWindow`). The call is `LiveFlightDoor`, apart from `PartnerDoor`, so none of the helper's 15 files needs the live plane's types
- `CrewluvTests/Fixtures/TripMap/live-cases.json` holds the real plane to the same answers as the website. It's written by `node scripts/live-cases/generate.mjs` from a reference apart from both: change the reference, never the JSON, then copy the JSON to the website
```

In "## File Structure", replace:

```
│   ├── TripMap/                      # The trip map's model, drawing, clock and words
│   │   └── Facts/                    # The facts: geography, stories, sky, totals, words
```

with:

```
│   ├── TripMap/                      # The trip map's model, drawing, clock and words
│   │   ├── Live/                     # The real plane: its plan, path, record and progress, and asking for it
│   │   └── Facts/                    # The facts: geography, stories, sky, totals, words
```

- [ ] **Step 4: Record what changed.** Add "## Changes made during execution" to the end of this plan: the review's changes, and anything a step did differently. If any of it changes what the spec says, change the spec to match, and say so in the list.

- [ ] **Step 5: Ask to commit.** Suggested message: `docs(crewluv): the real plane's engine in CLAUDE.md, and the Stage 3B-1 plan as it was built`.

---

## What 3B-2, 3B-3 and the website's plan take from this one

- **`MapLeg` will carry a `FlightPlan`, a `FlightPath` and, with a real path, a `FlightRecord`** (spec §11). The plan is made from the leg's scheduled times moved by the reported delay, before any real time replaces them.
- **One landing time** is `LiveProgress.start` and `.end`, worked out where the status screen's model hands the legs on (`PartnerStatusReceiver`, before `TripStateResolver.resolve`).
- **The moment is Crewlu Cloud's:** `LiveFlightSource.serverTime(at:)`.
- **The source's legs** are `LiveFlightSource.Leg`: each flight leg's id and its gate times moved by its delay. The status screen calls `watch(_:)` when they change, `screenCameToFront()` and `screenLeftFront()`.
- **A flight that isn't live can still have a real path and a record:** on the ground after a return, in a state this Crewluve doesn't know, or flown days ago. The map chooses what to draw by `LiveProgress.phase`, not by whether there's a path.
- **Drawing:** `FlightPath.stretches` with their kinds, `LiveProgress.planeDistance` and `.ghostDistance` along the path, and `FlightPath.point(atDistance:)`. The planned stretch behind an estimated plane, from `flownLength` to `planeDistance`, is dotted.
- **The words** for the label are `TripMapWording.liveLabel`.
- **The website** copies `live-cases.json` to `tests/fixtures/trip-map/` and runs every case. `scripts/live-cases/live.mjs` is a reference to check against, not code to import.
- **A real answer to record,** for the demo scenes: Crewlu Cloud has watched Todd's flights since 15 Nov 2026 and keeps each trail for 16 days.

## Changes made during execution

- **Batch A's review (15 Nov 2026)** found nothing wrong in the Swift or in any expected value, and found behaviours the shared cases didn't pin. So before Tasks 2 and 3 were committed:
  - the cases gained seven flights (off late and seen from the start; a short hop off two minutes early; in the air with no trail point yet; the fix is the last trail point; points out of order, ten minutes apart, and two at once; landed with a landing time before its last point; landed and never seen in the air), a plan (a block of exactly 32 minutes), two labels and two windows;
  - a landed flight's touchdown became its record's, in the reference and in `LiveProgress`;
  - `FlightRecordTests`' inverse test leaves out the distances inside a jump, where two places were seen at one time;
  - five choices the reference had made without saying are now in this plan's list of settled details.
- **The test command names the simulator's OS.** Todd's first run found no iPhone 17 Pro on the newest iOS.

## Self-review

- **Spec coverage.**
  - §4, the plan: Task 4. §5.1 to §5.5, the phases, the estimate, the label, the ghost and the estimated plane: Task 6. §6.1, the path: Task 5. §7.1, the real times: Task 6. §7.2, the record: Task 5. §10.2's window as a device keeps it: Task 7. §10.6, the answer: Task 3. §11's `LiveFlightSource`, the clock difference and `sharing_ended`: Task 8. §16.1, the shared cases: Task 2, and every item of its list has a case.
  - §16.3's tests for this part: the shared cases through `FlightPlan`, `FlightPath`, `LiveProgress` and `FlightRecord` (Tasks 4 to 6), and `LiveFlightSource`'s five (Task 8).
- **Not covered here, on purpose:** §6.2's drawing, §7.3's replay, §8's facts, §9's other words, `AircraftTypeNames`, and one landing time through the status screen's model. They're 3B-2's and 3B-3's.
- **Names** are the same in every task: `FlightPlan(departure:arrival:distance:)`, `timeToFly(_:)`, `distanceLeft(_:)`, `FlightPath(from:to:flight:)`, `point(atDistance:)`, `FlightRecord(path:plan:)`, `distance(at:)`, `time(atDistance:)`, `LiveProgress(plan:path:record:flight:at:)`, `LiveLabel(phase:gapMinutes:)`, `LiveWindow.isOpen(departure:arrival:flight:at:)`, `LiveFlightDoor.live(key:after:)`, `LiveFlightSource.watch(_:)`, `screenCameToFront()`, `screenLeftFront()`, `ask()` and `serverTime(at:)`.
- **Is it wise?** It adds eight small types, each with one job, and no new dependency. The one thing built ahead of its use is `LiveFlightSource`, which nothing owns until 3B-2: it's here because its rules (the cursor, the count, the key) are the engine's, and they're tested here.
- **Will it break anything?** It changes three things that already ran: `LivePartnerDoor.call`'s access, which the helper builds; the countdown's wording, which keeps its tests; and the stand-in door, in the tests only. It touches no stored data, no alerts and no view. Nothing reads the new types until 3B-2, so nothing a family sees can change.
- **Is it what an Apple engineer would write?** Value types that are `nonisolated` and `Sendable`, typed throws at the door, Observation for the one model, and a clock and a timer handed in so the tests need neither. The door's call follows `PushRegistrar`'s pattern for a key that changes mid-call instead of inventing one.

## Left for later

- **A flight back on the ground after a return to its departure airport** keeps its first attempt's trail, and its record flies the plan on from there until it's seen in the air again. The real plane itself shows at the gate.
- **Legs of a summary that are one flight** are answered once, under the first of their ids. The other leg shows the schedule.
- **A flight leg with no callsign** (a van, or an airline Crewlu Cloud doesn't know) still opens a window, so the source asks every 30 seconds and gets no flight for it.
- **The source asks again for every point at most once a run.** If that answer's count is off too, it's taken as it comes.

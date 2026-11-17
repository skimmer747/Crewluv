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
  const own = live.ownSpeed(path)
  return { isReal: path.isReal, lengthNm: nm(path.length), flownNm: nm(path.flown),
           ownSpeedKt: own === null ? null : round(own * 3600 / NM, 3),
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
           flownSpeedKt: round(live.planSpeed(live.flownPlan(plan, path)) * 3600 / NM, 3),
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

// Ten minutes of the cruise seen, to the second, and a second under: the first place past 120 nm is at 12:22.
const tenOfCruise = ['2026-11-13T12:06:00Z', '2026-11-13T12:14:00Z', '2026-11-13T12:22:00Z', '2026-11-13T12:32:00Z']
  .map((at) => trailPoint(toPhiladelphia, phlKnots, offAt, t(at), 33000))
const underTenOfCruise = ['2026-11-13T12:06:00Z', '2026-11-13T12:14:00Z', '2026-11-13T12:22:01Z', '2026-11-13T12:32:00Z']
  .map((at) => trailPoint(toPhiladelphia, phlKnots, offAt, t(at), 33000))

// The ahead flight followed into its descent: 430 kt for 384 nm, then 240 kt, and last seen under 120 nm from Philadelphia.
const slowsAfter = 384 * NM
const slowsAt = offAt + slowsAfter / (phlKnots * NM / 3600)
const descending = (time) => (time <= slowsAt ? phlKnots * NM / 3600 * (time - offAt) : slowsAfter + 240 * NM / 3600 * (time - slowsAt))
/// The place `metres` along `route`.
const alongRoute = (route, metres) => flown(route, 1, metres / NM * 3600)
const descentPlace = (time) => { const at = alongRoute(toPhiladelphia, descending(time)); return [round(at[0], 6), round(at[1], 6)] }
const descentTimes = []
for (let time = t('2026-11-13T12:05:00Z'); time <= t('2026-11-13T13:05:00Z'); time += 120) descentTimes.push(time)
const descentTrail = descentTimes.map((time, i) =>
  [Math.round(time * 1000), ...descentPlace(time), Math.max(9000, Math.min(35000, 2000 + i * 4000, (descentTimes.length + 3 - i) * 3000))])
const descentFix = { ...airFix(toPhiladelphia, 240, offAt, t('2026-11-13T13:05:40Z'), 9000),
                     lat: descentPlace(t('2026-11-13T13:05:40Z'))[0], lon: descentPlace(t('2026-11-13T13:05:40Z'))[1] }

// Speeds either side of what's believed, which is 0.7 to 1.5 of the plan's 397.7 kt: 278.4 to 596.6 kt.
function steadyFlight(knots, lastAt, every) {
  const times = []
  for (let time = t('2026-11-13T12:05:00Z'); time <= t(lastAt); time += every) times.push(time)
  const fixAt = t(lastAt) + 30
  return wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, knots, offAt, fixAt, 35000), null,
              times.map((time) => trailPoint(toPhiladelphia, knots, offAt, time, 35000)))
}

// Out to the west and back over Louisville before setting off: 120 nm flown, and still at the airport.
const outAndBack = [airports.SDF, [38.1744, -87.007], airports.SDF, [39.6, -81.0], airports.PHL]
const outAndBackOffAt = t('2026-11-13T12:02:00Z')
const outAndBackTimes = []
for (let time = t('2026-11-13T12:03:00Z'); time <= t('2026-11-13T12:39:00Z'); time += 120) outAndBackTimes.push(time)
const outAndBackTrail = outAndBackTimes.map((time) => trailPoint(outAndBack, phlKnots, outAndBackOffAt, time, 33000))

// A return: out to 150 nm, back to 60 nm from Louisville, twenty minutes there that nobody saw, and out again.
const outTo = alongRoute(toPhiladelphia, 150 * NM), backTo = alongRoute(toPhiladelphia, 60 * NM)
const withAReturn = [airports.SDF, outTo, backTo, [39.6, -81.0], airports.PHL]
const waitsAfter = 240 * NM, waitsFor = 20 * 60
const waitsAt = offAt + waitsAfter / (phlKnots * NM / 3600)
const returning = (time) => phlKnots * NM / 3600 * ((time <= waitsAt ? time : Math.max(waitsAt, time - waitsFor)) - offAt)
const returnPlace = (time) => { const at = alongRoute(withAReturn, returning(time)); return [round(at[0], 6), round(at[1], 6)] }
const returnTimes = []
for (let time = t('2026-11-13T12:05:00Z'); time <= t('2026-11-13T13:41:00Z'); time += 120) {
  if (time <= waitsAt || time >= waitsAt + waitsFor) returnTimes.push(time)
}
const returnTrail = returnTimes.map((time) => [Math.round(time * 1000), ...returnPlace(time), 33000])
const returnFix = { ...airFix(toPhiladelphia, phlKnots, offAt, t('2026-11-13T13:41:30Z'), 33000),
                    lat: returnPlace(t('2026-11-13T13:41:30Z'))[0], lon: returnPlace(t('2026-11-13T13:41:30Z'))[1] }

// Louisville to Cologne on time and faster than the plan, seen over land, and then never again over the ocean.
const gapRoute = [airports.SDF, airports.CGN]
const gapOffAt = t('2026-11-13T18:15:00Z')
const gapKnots = 560
const gapTimes = []
for (let time = t('2026-11-13T18:19:00Z'); time <= t('2026-11-13T19:39:00Z'); time += 240) gapTimes.push(time)
const gapTrail = gapTimes.map((time) => trailPoint(gapRoute, gapKnots, gapOffAt, time, 37000))

// A hold inside the last 120 nm: 430 kt to 135 nm short of Philadelphia, then 240 kt out to the north and back.
const holdEntry = [39.95, -77.3], holdOut = [40.2, -77.7], holdBack = [39.7, -77.45]
const withAHold = [airports.SDF, [39.6, -81.0], holdEntry, holdOut, holdBack, airports.PHL]
const holdSlowsAfter = routeLength([airports.SDF, [39.6, -81.0], holdEntry]) - 40 * NM
const holdSlowsAt = offAt + holdSlowsAfter / (phlKnots * NM / 3600)
const holding = (time) => (time <= holdSlowsAt ? phlKnots * NM / 3600 * (time - offAt) : holdSlowsAfter + 240 * NM / 3600 * (time - holdSlowsAt))
const holdPlace = (time) => { const at = alongRoute(withAHold, holding(time)); return [round(at[0], 6), round(at[1], 6)] }
const holdTimes = []
for (let time = t('2026-11-13T12:05:00Z'); time <= t('2026-11-13T13:17:00Z'); time += 120) holdTimes.push(time)
const holdTrail = holdTimes.map((time) => [Math.round(time * 1000), ...holdPlace(time), time <= holdSlowsAt ? 35000 : 12000])
const holdFix = { ...airFix(toPhiladelphia, 240, offAt, t('2026-11-13T13:17:40Z'), 12000),
                  lat: holdPlace(t('2026-11-13T13:17:40Z'))[0], lon: holdPlace(t('2026-11-13T13:17:40Z'))[1] }

const flights = [
  flightCase({
    name: 'ahead, in the air', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Off the ground about ten minutes before the plan, by way of a point north of the straight line, with a trail point every 2 minutes and a fix 40 s after the last. The first point is under 30 nm out, so its time is the takeoff and the leg starts early. It has been seen for 18 minutes of its cruise, 120 nm or more from both airports, so its own speed, 430 kt, stands in for the plan\'s: the landing estimate is the fix plus the time for the straight distance left at that speed, with the last 120 nm at 280 kt. The ghost flies the same, so the gap between the planes is still the label.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, offAt, t('2026-11-13T12:41:40Z'), 35000), null, phlTrail),
    moments: [
      ['2026-11-13T12:41:50Z', 'The fix is 10 s old: in the air, at the fix. The ghost is behind the real plane.'],
      ['2026-11-13T12:44:40Z', 'The fix is exactly 3 minutes old: still in the air.'],
      ['2026-11-13T12:44:41Z', 'A second more: estimated.'],
      ['2026-11-13T12:45:00Z', 'The fix is over 3 minutes old: estimated, flying on from the fix at its own speed. The estimate holds still.'],
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
    note: 'Its first point is 3 nm out at 12:25, ten minutes after the plan\'s takeoff. The takeoff is known and late, and a late departure doesn\'t move the leg: its start stays at 12:00. Only its newest place is 120 nm from Louisville or more, so its own speed isn\'t known yet and the plan\'s stands.',
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
    note: 'Off 25 minutes after the plan and slower than it. The first point is 96 nm out, so the join from Louisville is unseen and the takeoff isn\'t known: the leg\'s start stays. Nobody saw it for nearly 3 hours over the ocean: one unseen join. Its own speed is measured across that join too, from the first place 120 nm or more from Louisville to the last, and it\'s slower than the plan\'s, so it lands later still. The ghost is ahead of the real plane, and the leg ends late.',
    flight: wire('leg-cgn', 'UPS207', 'airborne', airFix(toCologne, cgnKnots, cgnOffAt, t('2026-11-14T00:12:30Z'), 37000), null, cgnTrail),
    moments: [
      ['2026-11-14T00:13:00Z', 'In the air and behind: the ghost is further along the path than the real plane.'],
      ['2026-11-14T00:20:00Z', 'Estimated: "About" joins the label.'],
    ],
    places: ['2026-11-13T18:30:00Z', '2026-11-13T18:45:00Z', '2026-11-13T22:00:00Z', '2026-11-14T00:12:15Z'],
    distancesNm: [50, 500, 1500, 2700],
  }),
  flightCase({
    name: 'ten minutes of its cruise seen', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Its first place 120 nm or more from Louisville was seen at 12:22:00 and its newest at 12:32:00: ten minutes of its cruise, which is enough. Its own speed stands in for the plan\'s.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, offAt, t('2026-11-13T12:32:00Z'), 33000), null, tenOfCruise),
    moments: [['2026-11-13T12:32:10Z', 'In the air, by its own speed.']],
  }),
  flightCase({
    name: 'a second under ten minutes of its cruise seen', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'The same, with the first place 120 nm or more from Louisville seen a second later. That isn\'t enough yet: the plan\'s speed stands, and the estimate is later than its own speed would have it.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(toPhiladelphia, phlKnots, offAt, t('2026-11-13T12:32:00Z'), 33000), null, underTenOfCruise),
    moments: [['2026-11-13T12:32:10Z', 'In the air, by the plan\'s speed.']],
  }),
  flightCase({
    name: 'in its descent, with the ghost still in the cruise', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'It flew 430 kt for 384 nm and has slowed to 240 kt, under 120 nm from Philadelphia. Its own speed was measured to the last place it was seen 120 nm or more from Philadelphia, and the slower places since don\'t change it. The estimate needs only the descent\'s 280 kt now. The ghost, 32 minutes from the plan\'s touchdown, is still in the cruise, at the plane\'s own speed.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', descentFix, null, descentTrail),
    moments: [['2026-11-13T13:05:50Z', 'In the air, in its descent.']],
    places: ['2026-11-13T13:10:00Z'],
    distancesNm: [450],
  }),
  flightCase({
    name: 'out and back before it leaves', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'It flew 60 nm west and back over Louisville before setting off, so it has 265 nm behind it along its path and is only 145 nm from Louisville. Its cruise is counted from 120 nm from the airport in a straight line, not along the path: it has been seen for under three minutes of that, so its own speed isn\'t known yet and the plan\'s stands.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', airFix(outAndBack, phlKnots, outAndBackOffAt, t('2026-11-13T12:39:30Z'), 33000), null, outAndBackTrail),
    moments: [['2026-11-13T12:39:40Z', 'In the air, by the plan\'s speed.']],
  }),
  flightCase({
    name: 'a return, a wait and a second start', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'It flew out to 150 nm, came back to 60 nm from Louisville, wasn\'t seen for twenty minutes there, and set off again. Its own speed counts only the stretches between two places seen in its cruise: six minutes of the first start and all of the second, and none of the way back inside 120 nm or the wait. It comes to 419 kt, a little under the 430 kt it flew, because it turned back between two places seen two minutes apart, which are closer together than the way it flew between them.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', returnFix, null, returnTrail),
    moments: [['2026-11-13T13:41:40Z', 'In the air, and very late.']],
  }),
  flightCase({
    name: 'a hold inside the last 120 nm', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'It slowed to 240 kt 135 nm short of Philadelphia, and then flew out to the north and back, inside 120 nm of the airport, which made its path longer. The places seen in the hold are all under 120 nm from Philadelphia, so they never count towards its own speed, however long the path grows.',
    flight: wire('leg-phl', 'UPS1234', 'airborne', holdFix, null, holdTrail),
    moments: [['2026-11-13T13:17:50Z', 'In the air, holding.']],
  }),
  flightCase({
    name: 'much faster than the plan, and believed', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'At 557 kt, 1.4 times the plan\'s cruise speed: a strong wind behind it. That\'s believed.',
    flight: steadyFlight(557, '2026-11-13T12:31:00Z', 120),
    moments: [['2026-11-13T12:31:40Z', 'In the air, by its own speed.']],
  }),
  flightCase({
    name: 'too fast to be right', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Places that put it at 640 kt, 1.6 times the plan\'s cruise speed. Over 1.5 times isn\'t believed: something is wrong with the places, and the plan\'s speed stands.',
    flight: steadyFlight(640, '2026-11-13T12:29:00Z', 120),
    moments: [['2026-11-13T12:29:40Z', 'In the air, by the plan\'s speed.']],
  }),
  flightCase({
    name: 'much slower than the plan, and believed', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'At 300 kt, three quarters of the plan\'s cruise speed: a strong wind against it. That\'s believed.',
    flight: steadyFlight(300, '2026-11-13T12:47:00Z', 360),
    moments: [['2026-11-13T12:47:40Z', 'In the air, by its own speed.']],
  }),
  flightCase({
    name: 'too slow to be right', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Places that put it at 255 kt, 0.64 of the plan\'s cruise speed. Under 0.7 isn\'t believed either, and the plan\'s speed stands.',
    flight: steadyFlight(255, '2026-11-13T12:53:00Z', 360),
    moments: [['2026-11-13T12:53:40Z', 'In the air, by the plan\'s speed.']],
  }),
  flightCase({
    name: 'a slow leg keeps its one speed', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T14:15:00Z',
    note: 'A 300 kt flight on a block of 2 h 15 min, whose plan is one steady speed of 265 kt with no descent of its own. Its own speed is known, and near the plan\'s, and still isn\'t used: a leg with one steady speed keeps it.',
    flight: steadyFlight(300, '2026-11-13T12:47:00Z', 360),
    moments: [['2026-11-13T12:47:40Z', 'In the air, by the plan\'s one speed.']],
  }),
  flightCase({
    name: 'on the ground before the plan\'s takeoff', from: 'SDF', to: 'PHL', departure: '2026-11-13T12:00:00Z', arrival: '2026-11-13T13:45:00Z',
    note: 'Seen on the ground half a mile from Louisville\'s airport. Before 12:15 there\'s no estimate and no label, and the schedule stands. A ground fix over 3 minutes old isn\'t live.',
    flight: wire('leg-phl', 'UPS1234', 'ground', groundFix([38.18, -85.73], t('2026-11-13T12:09:30Z')), null, []),
    moments: [
      ['2026-11-13T12:10:00Z', 'On the ground, before the plan\'s takeoff: the ghost waits at the airport too.'],
      ['2026-11-13T12:12:30Z', 'The ground fix is exactly 3 minutes old: still on the ground.'],
      ['2026-11-13T12:12:31Z', 'A second more: not live.'],
      ['2026-11-13T12:13:00Z', 'The ground fix is 3.5 minutes old: not live.'],
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
  flightCase({
    name: 'faster than the plan, then a long ocean gap', from: 'SDF', to: 'CGN', departure: '2026-11-13T18:00:00Z', arrival: '2026-11-14T02:00:00Z',
    note: 'Off on time along the great circle at 560 kt, faster than the plan\'s 508.1 kt, seen every 4 minutes until 19:39 and at the fix at 19:39:30, and never again. 2,872 nm of its cruise is left from the fix: the first 1,120 nm, 2 hours of it, are flown at its own 560 kt and the rest at the plan\'s, which is one speed of 527.1 kt over all of it and a touchdown at 01:32, 21 minutes ahead. At its own speed all the way it would be 01:13. The landing estimate, the estimated plane and the ghost all fly the one speed, and the estimate holds still through the gap.',
    flight: wire('leg-cgn', 'UPS207', 'airborne', airFix(gapRoute, gapKnots, gapOffAt, t('2026-11-13T19:39:30Z'), 37000), null, gapTrail),
    moments: [
      ['2026-11-13T19:39:40Z', 'In the air, at the fix.'],
      ['2026-11-13T19:42:31Z', 'The fix is just over 3 minutes old: estimated, with the same estimate.'],
      ['2026-11-13T21:39:30Z', 'Two hours on from the fix, far out over the ocean.'],
      ['2026-11-14T01:00:00Z', 'Nearly there, still unseen: the estimate is the same as at the fix.'],
    ],
    places: ['2026-11-13T19:00:00Z', '2026-11-13T21:39:30Z', '2026-11-14T01:00:00Z'],
    distancesNm: [500, 2000, 3500],
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
  about: 'The real plane (Crewluve moving map Stage 3 spec §4 to §7, §10.2). Made by a reference written apart from the app and the website, and run by both: the app\'s FlightPlanTests, FlightPathTests, FlightRecordTests, LiveProgressTests, LiveLabelTests and LiveWindowTests, and the website\'s tests. Change both copies together. Every `at`, and every time in an answer, is an ISO 8601 time with milliseconds. A `flight` is one entry of partner_live\'s `flights`, exactly as the door answers it, with times in milliseconds since 1970, or null where the door answers none. Distances are nautical miles of 1,852 m along a sphere of radius 6,371,008.8 m, to the nearest thousandth; places are [latitude, longitude]. A gap is the plan\'s touchdown minus the estimated one in minutes, rounded to the nearest with halves away from zero; ahead is positive. A path\'s `ownSpeedKt` is the plane\'s own speed over its cruise so far, or null when too little of it has been seen, and a flight\'s `flownSpeedKt` is the speed its estimate, its estimated plane and its ghost fly the cruise at. When its own speed is from 0.7 of the plan\'s to 1.5 of it, the cruise left from the last place it was seen is flown at its own speed for `ownSpeedAheadMinutes`, or all the way when that\'s further, and at the plan\'s after that, and `flownSpeedKt` is the one speed that flies it all in the same time. Otherwise it\'s the plan\'s. Compare speeds to 0.01 kt. Compare distances to 0.01 nm, times to 0.05 s and places to 0.0001 of a degree.',
  constants: {
    taxiOutMinutes: 15, taxiInMinutes: 7, shortestCruiseMinutes: 10, descentDistanceNm: 120, descentSpeedKt: 280,
    freshSeconds: live.FRESH, airportRadiusNm: 10, onScheduleMinutes: live.ON_SCHEDULE_MINUTES,
    unseenGapMinutes: 10, firstPointRadiusNm: 30,
    ownSpeedLeastMinutes: live.OWN_SPEED_LEAST / 60, ownSpeedLeastShare: live.OWN_SPEED_LEAST_SHARE, ownSpeedMostShare: live.OWN_SPEED_MOST_SHARE,
    ownSpeedAheadMinutes: live.OWN_SPEED_AHEAD / 60,
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
    `own ${f.path.ownSpeedKt} kt, flown at ${f.flownSpeedKt} kt, ` +
    f.moments.map((m) => `${m.at.slice(11, 19)} ${m.phase} gap ${m.gapMinutes} "${m.label}" plane ${m.planeAlongNm} ghost ${m.ghostAlongNm}`).join(' | '))
}

# Moving Map Stage 3A: CrewLu Cloud's Live Relay — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CrewLu Cloud finds where each pilot's flight really is, from adsb.lol, and hands it to that pilot's partners' devices through a new partner RPC, `partner_live`, behind a switch that ships off.

**Architecture:**
- **A small check, every 30 seconds.** `pg_cron` runs `private.flight_live_tick()`. With the switch on, it keeps a row in `private.live_flights` for every flight in a pilot's summary whose window is open, and calls the Edge Function `flight-live` through `pg_net`, with a password from the Vault.
- **Two RPCs only `flight-live` can use.** `flight_live_claim` hands it the open flights. `flight_live_report` keeps what it judged: each flight's state, aircraft and latest fix. The database adds the trail points and counts the failures. Both need the password and the secret key.
- **`flight-live` is one file with no imports,** pasted into Supabase's editor, like `partner-push`. It asks adsb.lol once for every open flight's callsign, and judges which aircraft in the answer is each flight by following the aircraft, not a corridor. Its tests import the same file under Node, with stand-ins for adsb.lol, and then run it against the real SQL in PGlite.
- **`partner_live`** answers a partner's device with its own pilot's flights: each one's state, fix and trail, tied to the leg's `id` in the summary.
- **Set up by Todd:** the function, the two SQL scripts, and the switch, first for his own account only.

**Tech stack:** Postgres 17 on Supabase with `pg_cron`, `pg_net` and the Vault; a Supabase Edge Function in TypeScript on Deno, using `fetch`; adsb.lol's public API. Tests: PGlite 0.5.8 and Node 23's test runner.

**Design:** `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md` in this repo (Crewluv), §10, with §13, §14, §16.2 and §17. A plain "spec §" below names its sections. The API contract is `supabase/partner-api.md` in CrewLu.

---

## Before you start

- **Two repos.**
  - The code goes in CrewLu (`~/Dev/Duty`), on the new branch `feature/flight-live`, in a worktree beside it: `~/Dev/Duty-flight-live` (Task 0).
  - This plan and the spec live in `~/Dev/Crewluv`, on the branch `feature/trip-map-live`.
  - Paths are relative to `~/Dev/Duty-flight-live` unless they start with `~`.
- **Only `supabase/` changes,** so no CrewLu build is affected. `~/Dev/Duty` stays on `feature/supabase-account-backend`, and Xcode never sees the branch.
- **Leave `~/Dev/Duty`'s Xcode scheme files alone.** It has uncommitted changes to `Duty.xcodeproj/xcshareddata/xcschemes/*` that aren't part of this work. Never run `git add -A` or `git add .`: add the exact paths each step lists.
- **The tests need only Node** (23.6 or later). They run in PGlite from `supabase/tests` with `npm test`, which is `node --no-maglev --test`. No Xcode, no Docker, no Deno, and no connection to CrewLu Cloud or adsb.lol. Claude runs them.
- **Nothing is downloaded.** Task 0 copies `node_modules` from `~/Dev/Duty`. If that folder isn't there, ask Todd before running `npm install`.
- **No test and no task calls adsb.lol.** The function's tests use records of its answers.
- **CrewLu Cloud changes only in Task 12, by Todd,** one step at a time on his OK. Until then nothing here touches the live project.
- **Every commit waits for Todd's OK.** Ask at each task's commit step. If he says at the start that this plan's commits may go ahead, that covers this plan only. Never push.
- **Code review subagents** (`superpowers:code-reviewer`) get `model: "sonnet"`.
- **Shell variables don't carry from one command to the next** in Claude's Bash tool, so every command here names its folder.
- **If an expected value doesn't match, stop and ask.** Never change a test to make it pass.
- **The code in Tasks 1 to 10 has been run.** On 14 Nov 2026 every block was put together in a copy of `supabase/`, in this plan's order, and the tests were run after each task: 396 of 396 passed at the end. So a failure is most likely a slip in copying. Compare with the block before changing anything.

## Decisions made while planning

These refine the spec, and its §10 already has them.

1. **`partner_live`'s fields have underscores** (`leg_id`, `altitude_ft`, `trail_count`), as every other partner-door answer has. Times are milliseconds since 1970.
2. **Two scripts.** The live plane's script makes an empty `private.airports`. A second script, made from the Crewluve website's `airports.json` by `tests/helpers/airports_seed.js`, fills it with 9,056 airports. Its name has no `_partner_links_`, so the tests' `freshDb()` doesn't load 231 KB for every test: each test puts in the few airports it flies between.
3. **The database adds the trail points,** not `flight-live`. `flight_live_report` adds one when a fix is in the air and the trail's last point is 110 seconds older or more. Two runs that overlap can't then add the same point twice.
4. **A fix older than the one a flight has is left alone,** and a landed flight never changes.
5. **The callsign's airline table is in `private.flight_callsign`,** as SQL. It holds each airline's real ICAO code, so PSA Airlines is `JIA`. The app's tracking links have `PSA` for it.
6. **A summary-wide delay isn't counted** in a leg's window: only the leg's own `delayMinutes`. The window is 30 minutes and 2 hours wide.
7. **The match has a fourth rule before takeoff:** a flight's own aircraft on the ground somewhere other than the departure airport, as after a diversion, keeps the state `ground` with its newest fix.
8. **`private.flight_live_switch(mode, pilots)`** sets the switch from the SQL editor.
9. **`flight-live` needs no secrets of its own.** It reads `SUPABASE_URL` and `SUPABASE_SECRET_KEYS`, which Supabase supplies. The password is the Vault's `flight_live_secret`, which the script makes.
10. **The password helper is the push service's.** `private.push_secret(name)` reads a Vault secret by name, so the live plane's script runs after the push service's.
11. **The `User-Agent` names `https://crewlu.net`** as where adsb.lol can find CrewLu Cloud. Todd confirmed the address on 14 Nov 2026.

## File structure

| File | What it is |
|---|---|
| `supabase/migrations/20261114120000_partner_links_flight_live.sql` | New. The tables, the helpers, the check, claim and report, `partner_live`, and the three cron jobs. Its undo is in its header |
| `supabase/migrations/20261114120100_flight_live_airports.sql` | New, made by a script. Fills `private.airports` |
| `supabase/functions/flight-live/index.ts` | New. The Edge Function |
| `supabase/tests/flight_live.test.js` | New. The SQL's tests |
| `supabase/tests/flight_live_airports.test.js` | New. The airports' tests |
| `supabase/tests/flight_live_function.test.js` | New. The function's tests |
| `supabase/tests/helpers/airports_seed.js` | New. Makes the airports script |
| `supabase/tests/package.json` | Gains `npm run airports-seed` |
| `supabase/tests/privileges.test.js`, `advisors.test.js` | Their lists of functions and tables gain the new ones |
| `supabase/partner-api.md`, `supabase/tests/README.md` | `partner_live`'s contract, and what the new tests cover |

Each part of a file below is separated from the part before it by exactly one blank line.

---

### Task 0: The worktree

**Files:** none yet.

- [ ] **Step 1: Ask Todd**

This makes a new branch and a worktree in CrewLu's repo. Ask before making them.

- [ ] **Step 2: Make the worktree**

Run:

```bash
git -C ~/Dev/Duty worktree add ~/Dev/Duty-flight-live -b feature/flight-live feature/supabase-account-backend
```

Expected: `Preparing worktree (new branch 'feature/flight-live')`, then a `HEAD is now at` line.

- [ ] **Step 3: Copy the tests' `node_modules`**

Run:

```bash
cp -c -R ~/Dev/Duty/supabase/tests/node_modules ~/Dev/Duty-flight-live/supabase/tests/node_modules && ls ~/Dev/Duty-flight-live/supabase/tests/node_modules | head -3
```

Expected: `@electric-sql`, `ajv` and one more name. `node_modules` is ignored by git.

- [ ] **Step 4: Run the tests as they are**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && npm test 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected, after about a minute: `ℹ tests 313`, `ℹ pass 313`, `ℹ fail 0`.

---

### Task 1: The tables, the callsign and a summary's flight legs

**Files:**
- Create: `supabase/tests/flight_live.test.js`
- Create: `supabase/migrations/20261114120000_partner_links_flight_live.sql`
- Modify: `supabase/tests/privileges.test.js`

- [ ] **Step 1: Write the failing tests**

Create `supabase/tests/flight_live.test.js`. Its helpers are for every task's tests, so some aren't used until later.

```js
// The live plane's SQL (supabase/migrations/20261114120000_partner_links_flight_live.sql): which flights are watched,
// the 30-second check, the claim and report calls flight-live makes, partner_live, the daily delete, and the script's
// second run and undo. Its spec, whose sections "spec §" names, is Crewluv
// docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md.
// Each test builds its own database, because the check reads every pilot in it.
import assert from 'node:assert/strict'
import { describe, test } from 'node:test'
import { asAdmin, asAnon, asService, freshDb, migrationPath, partnerDbUpTo, read } from './helpers/db.js'
import { connected, setStatus } from './helpers/rpc.js'

const FILE = '20261114120000_partner_links_flight_live.sql'
const migration = migrationPath(FILE)

/** The undo SQL: the indented comment lines under "-- Undo" in the migration's header. */
function undoSql() {
  const lines = read(migration).split('\n')
  const start = lines.findIndex((line) => line.startsWith('-- Undo'))
  assert.ok(start >= 0, 'the migration has an "-- Undo" section')
  const undo = []
  for (const line of lines.slice(start + 1)) {
    if (!line.startsWith('--   ')) break
    undo.push(line.slice('--   '.length))
  }
  return undo.join('\n')
}

/** The airports the tests fly between. */
const AIRPORTS = { SDF: [38.1744, -85.736], CGN: [50.8659, 7.1427], RFD: [42.1954, -89.0972], ONT: [34.056, -117.6012] }

/** A fresh database for one test, with the tests' airports, closed when the test ends. */
async function db(t) {
  const fresh = await freshDb()
  t.after(() => fresh.close())
  for (const [code, [lat, lon]] of Object.entries(AIRPORTS)) {
    await asAdmin(fresh, 'insert into private.airports (code, lat, lon) values ($1, $2, $3)', [code, lat, lon])
  }
  return fresh
}

/** Seconds since 1970, `minutes` from now: how a summary writes a time. */
const at = (minutes) => Math.floor(Date.now() / 1000) + minutes * 60

/** A summary's flight leg, UPS207 from Louisville to Cologne unless fields say otherwise. */
const leg = (startsIn, endsIn, fields = {}) => ({
  id: 'trip-leg-0',
  type: 'flight',
  startTime: at(startsIn),
  endTime: at(endsIn),
  flightNumber: 'UPS0207',
  airlineCode: null,
  departureAirport: 'SDF',
  arrivalAirport: 'CGN',
  delayMinutes: null,
  ...fields,
})

/** A pilot with a partner's device, whose summary holds `legs`. */
async function pilotWith(d, legs) {
  const pilot = await connected(d)
  await setStatus(d, pilot.pilot, { tripLegs: legs }, 1)
  return pilot
}

const switchTo = (d, mode, pilots = []) => asAdmin(d, 'select private.flight_live_switch($1, $2::uuid[])', [mode, pilots])
const tick = (d) => asAdmin(d, 'select private.flight_live_tick()')
const flights = (d) =>
  asAdmin(d, 'select id::int, callsign, departure, arrival, state, hex, fix from private.live_flights order by id')
const points = (d) => asAdmin(d, 'select flight_id::int as flight, lat, lon, altitude_ft from private.live_flight_points order by id')
const requests = (d) => asAdmin(d, 'select url, headers, body, timeout_milliseconds from net.http_request_queue order by id')
const state = async (d) => (await asAdmin(d, 'select mode, pilots, failures, paused_until > now() as paused from private.flight_live_state'))[0]
const password = async (d) =>
  (await asAdmin(d, "select decrypted_secret as s from vault.decrypted_secrets where name = 'flight_live_secret'"))[0]?.s

/** flight_live_claim and flight_live_report, called the way flight-live calls them. */
const claim = (d, secret) => asService(d, 'select public.flight_live_claim($1) as r', [secret]).then((rows) => rows[0].r)
const report = (d, secret, judged = [], outcome = 'ok') =>
  asService(d, 'select public.flight_live_report($1, $2::jsonb, $3) as r', [secret, JSON.stringify(judged), outcome]).then((rows) => rows[0].r)

/** partner_live, called the way Crewluve and the website call it. */
const live = (d, key, after) =>
  (after === undefined
    ? asAnon(d, 'select public.partner_live($1::text) as r', [key])
    : asAnon(d, 'select public.partner_live($1::text, $2::bigint) as r', [key, after])
  ).then((rows) => rows[0].r)

/** A fix as flight-live reports it, seen `secondsAgo` ago, in the air over Indiana unless fields say otherwise. */
const fix = (secondsAgo, fields = {}) => ({
  lat: 39.3,
  lon: -85.7,
  altitude_ft: 38000,
  ground_speed_kt: 465,
  track_deg: 62,
  on_ground: false,
  registration: 'N370UP',
  type_code: 'B763',
  seen_at: Date.now() - secondsAgo * 1000,
  ...fields,
})

/** A database with one watched flight, UPS207, that left 10 minutes ago: its pilot, the password, and its row's id. */
async function watching(t) {
  const d = await db(t)
  await switchTo(d, 'all')
  const pilot = await pilotWith(d, [leg(-10, 500)])
  await tick(d)
  const [{ id }] = await flights(d)
  return { d, pilot, secret: await password(d), id }
}

describe('private.flight_callsign and private.airport_code (spec §10.2)', () => {
  test('the callsign is the airline’s ICAO code and the digits without leading zeros', async (t) => {
    const d = await db(t)
    const cases = [
      // CrewLu writes a company flight as "UPS" and the digits, or the digits alone.
      ['UPS0207', null, 'UPS207'],
      ['UPS2961', null, 'UPS2961'],
      ['0207', null, 'UPS207'],
      ['ups 207', null, 'UPS207'],
      ['UPS0000', null, 'UPS0'],
      // Another airline's, as its code and the digits, with or without the leg's airline code.
      ['DL1234', null, 'DAL1234'],
      ['DL1234', 'DL', 'DAL1234'],
      ['1234', 'dl ', 'DAL1234'],
      ['B6 0456', null, 'JBU456'],
      ['5X207', null, 'UPS207'],
      ['9E5123', '9E', 'EDV5123'],
      ['OH5301', null, 'JIA5301'],
      // An ICAO code is used as it is.
      ['FDX147', null, 'FDX147'],
      ['147', 'FDX', 'FDX147'],
      // No callsign: ground transport, a commercial ticket, an airline that isn't in the table, nothing to read.
      ['GND', null, null],
      ['UPSGND', null, null],
      ['UPS1234CML', null, null],
      ['ZZ123', null, null],
      ['123', 'ZZ', null],
      ['DL12A', null, null],
      ['', null, null],
      [null, null, null],
    ]
    for (const [number, airline, expected] of cases) {
      const [{ c }] = await asAdmin(d, 'select private.flight_callsign($1, $2) as c', [number, airline])
      assert.equal(c, expected, `${number} with ${airline}`)
    }
  })

  test('an airport code is three characters in capitals, and a UPS base may end in Z', async (t) => {
    const d = await db(t)
    for (const [code, expected] of [['SDF', 'SDF'], [' sdf ', 'SDF'], ['SDFZ', 'SDF'], ['ANCZ', 'ANC'], ['CGNZ', null], ['KSDF', null], ['', null], [null, null]]) {
      const [{ c }] = await asAdmin(d, 'select private.airport_code($1) as c', [code])
      assert.equal(c, expected, String(code))
    }
  })
})

describe('private.flight_legs (spec §10.2)', () => {
  const legsOf = (d, status) =>
    asAdmin(
      d,
      `select leg_id, callsign, departure, arrival, extract(epoch from scheduled_departure)::int as scheduled,
              extract(epoch from effective_departure)::int as departs, extract(epoch from effective_arrival)::int as arrives
         from private.flight_legs($1::jsonb) order by scheduled_departure`,
      [JSON.stringify(status)],
    )

  test('a flight leg has its key, and its times moved by the delay the pilot reported', async (t) => {
    const d = await db(t)
    const one = leg(60, 560, { id: 'a', delayMinutes: 25, departureAirport: 'SDFZ' })
    assert.deepEqual(await legsOf(d, { tripLegs: [one] }), [
      {
        leg_id: 'a',
        callsign: 'UPS207',
        departure: 'SDF',
        arrival: 'CGN',
        scheduled: one.startTime,
        departs: one.startTime + 25 * 60,
        arrives: one.endTime + 25 * 60,
      },
    ])
  })

  test('only flights that can be watched are legs: not a layover, a van, a leg missing a time, an airport or its id', async (t) => {
    const d = await db(t)
    const legs = [
      leg(0, 60, { id: 'layover', type: 'layover' }),
      leg(0, 60, { id: 'van', flightNumber: 'GND' }),
      leg(0, 60, { id: 'no-start', startTime: null }),
      leg(0, 60, { id: 'text-end', endTime: 'soon' }),
      leg(0, 60, { id: 'no-airport', arrivalAirport: null }),
      leg(0, 60, { id: null }),
      leg(0, 60, { id: 'kept' }),
    ]
    assert.deepEqual((await legsOf(d, { tripLegs: legs })).map((l) => l.leg_id), ['kept'])
  })

  test('a summary with no legs, or legs that aren’t a list, has none', async (t) => {
    const d = await db(t)
    for (const status of [{}, { tripLegs: null }, { tripLegs: 'none' }, { tripLegs: {} }]) {
      assert.deepEqual(await legsOf(d, status), [])
    }
  })
})
```

- [ ] **Step 2: Run them, and see them fail**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 5`, `ℹ pass 0`, `ℹ fail 5`. Each fails with `relation "private.airports" does not exist`.

- [ ] **Step 3: Write the script's first part**

Create `supabase/migrations/20261114120000_partner_links_flight_live.sql`. Its header names everything the finished script makes, and holds the undo, which Task 5 tests.

```sql
-- Partner links: the live plane (Crewluv docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md, §10,
-- whose sections a plain "spec §" names). Every 30 seconds pg_cron runs private.flight_live_tick(). It keeps a row in
-- private.live_flights for every flight in a pilot's summary whose window is open, and calls the flight-live Edge
-- Function through pg_net. flight-live claims the open flights (flight_live_claim), asks adsb.lol once for all their
-- callsigns, judges which aircraft is each flight, and reports the fixes back (flight_live_report). A partner's device
-- reads its own pilot's flights with partner_live. A password this script makes and keeps in the Vault gates claim and
-- report, so only the check can set flight-live off.
--
-- Plan: Crewluv docs/superpowers/plans/2026-11-14-moving-map-stage3a-crewlu-cloud.md. Tests: supabase/tests/flight_live.test.js
-- and flight_live_function.test.js.
-- Run it once, in the SQL editor, after the partner-links scripts: a second run fails at its first create table and
-- changes nothing. Then run 20261114120100_flight_live_airports.sql, which fills private.airports. The switch starts
-- off: nothing is watched and partner_live answers no flights until private.flight_live_switch turns it on.
--
-- Undo, in the SQL editor, then delete flight-live in the dashboard:
--   select cron.unschedule('flight-live');
--   select cron.unschedule('flight-live-cleanup');
--   select cron.unschedule('flight-live-history');
--   drop function public.partner_live(text, bigint), public.flight_live_report(text, jsonb, text),
--     public.flight_live_claim(text), private.flight_live_tick(), private.call_flight_live(),
--     private.flight_live_switch(text, uuid[]), private.open_live_flights(), private.require_flight_live_password(text, text),
--     private.flight_legs(jsonb), private.flight_callsign(text, text), private.airport_code(text);
--   drop table private.live_flight_points, private.live_flights, private.flight_live_state, private.airports;
--   delete from vault.secrets where name in ('flight_live_secret', 'flight_live_url');

-- Where each airport is, by its three-character code: the match (spec §10.4) measures from them. Filled by
-- 20261114120100_flight_live_airports.sql from the Crewluve website's airports.json.
create table private.airports (
  code text primary key check (code ~ '^[A-Z0-9]{3}$'),
  lat double precision not null check (lat between -90 and 90),
  lon double precision not null check (lon between -180 and 180)
);

-- One row per watched flight (spec §10.2, §10.5). Its key is the callsign, the departure airport and the scheduled
-- departure, so a captain and a first officer on one flight share a row. fix is the latest fix, as partner_live answers
-- it, and seen_at its time.
create table private.live_flights (
  id bigint generated always as identity primary key,
  callsign text not null,
  departure text not null,
  arrival text not null,
  scheduled_departure timestamptz not null,
  effective_departure timestamptz not null,
  effective_arrival timestamptz not null,
  dep_lat double precision not null,
  dep_lon double precision not null,
  arr_lat double precision not null,
  arr_lon double precision not null,
  state text not null default 'waiting' check (state in ('waiting', 'ground', 'airborne', 'landed')),
  hex text,
  fix jsonb,
  seen_at timestamptz,
  landed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (callsign, departure, scheduled_departure)
);

-- The trails (spec §10.5): a point for the first fix in the air, then one whenever the last is 110 seconds old or more.
-- Their ids only grow, so partner_live can hand a device the points after the last one it has.
create table private.live_flight_points (
  id bigint generated always as identity primary key,
  flight_id bigint not null references private.live_flights (id) on delete cascade,
  at timestamptz not null,
  lat double precision not null,
  lon double precision not null,
  altitude_ft integer
);
create index live_flight_points_flight_id_idx on private.live_flight_points (flight_id, id);

-- The switch (spec §10.7), the pilots it lists, and the pause after adsb.lol fails or says to slow down. One row.
create table private.flight_live_state (
  only_row boolean primary key default true check (only_row),
  mode text not null default 'off' check (mode in ('off', 'listed', 'all')),
  pilots uuid[] not null default '{}',
  failures integer not null default 0,
  paused_until timestamptz
);
insert into private.flight_live_state default values;

alter table private.airports enable row level security;
alter table private.live_flights enable row level security;
alter table private.live_flight_points enable row level security;
alter table private.flight_live_state enable row level security;
revoke all on private.airports, private.live_flights, private.live_flight_points, private.flight_live_state
  from public, anon, authenticated;

-- The password the check sends, and claim and report require: 32 random bytes, made here, so nobody sees or types it.
-- And flight-live's address, for the check. It's Crewlu Cloud's own: a database built from these migrations anywhere
-- else would call Crewlu Cloud's flight-live, so change it there.
select vault.create_secret(encode(extensions.gen_random_bytes(32), 'hex'), 'flight_live_secret',
  'The live plane: the check sends it to flight-live, and flight_live_claim and flight_live_report require it.');
select vault.create_secret('https://corxvurxpnrzekbxdgye.supabase.co/functions/v1/flight-live', 'flight_live_url',
  'The live plane: where the check calls flight-live.');

-- An airport's code as private.airports has it: three characters in capitals. A UPS base written with a trailing Z
-- ("SDFZ") is its code, as the Crewluve website reads it (toIata). Anything else is null.
create function private.airport_code(p_code text) returns text
language sql immutable set search_path = '' as $$
  select case
    when upper(btrim(p_code)) ~ '^[A-Z0-9]{3}$' then upper(btrim(p_code))
    when upper(btrim(p_code)) ~ '^(SDF|ANC|ONT|MIA)Z$' then left(upper(btrim(p_code)), 3)
  end
$$;

-- The callsign a flight broadcasts (spec §10.2), built as the Crewluve website builds its tracking number (toMove and
-- trackingFlightNumber): the airline's ICAO code and the flight number's digits without leading zeros. CrewLu writes a
-- company flight's number as "UPS" and the digits, and another airline's as its code and the digits. Null when the
-- number isn't an optional airline and digits (GND, a number ending in CML), or the airline's ICAO code isn't known.
create function private.flight_callsign(p_flight_number text, p_airline_code text) returns text
language plpgsql immutable set search_path = '' as $$
declare
  v_raw text := upper(regexp_replace(coalesce(p_flight_number, ''), '\s+', '', 'g'));
  v_entered text := nullif(upper(btrim(coalesce(p_airline_code, ''))), '');
  v_parts text[];
  v_airline text;
  v_icao text;
begin
  if v_entered is not null and left(v_raw, char_length(v_entered)) = v_entered then
    v_raw := substr(v_raw, char_length(v_entered) + 1);
  end if;
  v_parts := regexp_match(v_raw, '^([A-Z]{3}|[A-Z][A-Z0-9]|[0-9][A-Z])?([0-9]+)$');
  if v_parts is null then
    return null;
  end if;
  v_airline := coalesce(v_entered, case when v_parts[1] is null or v_parts[1] = 'UPS' then '5X' else v_parts[1] end);
  v_icao := case
    when v_airline ~ '^[A-Z]{3}$' then v_airline
    else case v_airline
      -- Cargo.
      when '5X' then 'UPS' when 'FX' then 'FDX' when '5Y' then 'GTI' when 'K4' then 'CKS' when 'PO' then 'PAC'
      -- The United States and Canada.
      when 'AA' then 'AAL' when 'DL' then 'DAL' when 'UA' then 'UAL' when 'WN' then 'SWA' when 'B6' then 'JBU'
      when 'NK' then 'NKS' when 'F9' then 'FFT' when 'AS' then 'ASA' when 'HA' then 'HAL' when 'G4' then 'AAY'
      when 'MX' then 'MXY' when 'XP' then 'VXP' when 'SY' then 'SCX' when 'AC' then 'ACA' when 'WS' then 'WJA'
      -- Their regional airlines, which fly under their own callsigns.
      when 'OO' then 'SKW' when 'YX' then 'RPA' when 'MQ' then 'ENY' when 'OH' then 'JIA' when '9E' then 'EDV'
      when 'QX' then 'QXE' when 'ZW' then 'AWI' when 'G7' then 'GJS' when 'YV' then 'ASH' when 'C5' then 'UCA'
      when 'PT' then 'PDT'
      -- The rest of the world.
      when 'LH' then 'DLH' when 'BA' then 'BAW' when 'AF' then 'AFR' when 'KL' then 'KLM' when 'LX' then 'SWR'
      when 'OS' then 'AUA' when 'AZ' then 'ITY' when 'IB' then 'IBE' when 'SK' then 'SAS' when 'AY' then 'FIN'
      when 'EI' then 'EIN' when 'VS' then 'VIR' when 'TK' then 'THY' when 'EK' then 'UAE' when 'QR' then 'QTR'
      when 'EY' then 'ETD' when 'CX' then 'CPA' when 'SQ' then 'SIA' when 'NH' then 'ANA' when 'JL' then 'JAL'
      when 'KE' then 'KAL' when 'OZ' then 'AAR' when 'CI' then 'CAL' when 'BR' then 'EVA' when 'TG' then 'THA'
      when 'MH' then 'MAS' when 'QF' then 'QFA' when 'VA' then 'VOZ' when 'NZ' then 'ANZ' when 'AM' then 'AMX'
      when 'LA' then 'LAN' when 'CM' then 'CMP' when 'AV' then 'AVA'
    end
  end;
  if v_icao is null then
    return null;
  end if;
  return v_icao || coalesce(nullif(ltrim(v_parts[2], '0'), ''), '0');
end
$$;

-- A summary's flight legs that can be watched (spec §10.2), each with its key and its times moved by the delay the
-- pilot reported. The check and partner_live both read them here, so a leg has one key. A leg with no callsign, a
-- missing time or a missing airport code isn't one. A summary-wide delay from a CrewLu that doesn't tag legs isn't
-- counted: the window is wide enough without it.
create function private.flight_legs(p_status jsonb)
returns table (leg_id text, callsign text, departure text, arrival text, scheduled_departure timestamptz,
               effective_departure timestamptz, effective_arrival timestamptz)
language sql stable set search_path = '' as $$
  select r.leg_id, r.callsign, r.departure, r.arrival, to_timestamp(r.starts),
         to_timestamp(r.starts + r.delay), to_timestamp(r.ends + r.delay)
    from (
      select l.leg ->> 'id' as leg_id,
             private.flight_callsign(l.leg ->> 'flightNumber', l.leg ->> 'airlineCode') as callsign,
             private.airport_code(l.leg ->> 'departureAirport') as departure,
             private.airport_code(l.leg ->> 'arrivalAirport') as arrival,
             case when jsonb_typeof(l.leg -> 'startTime') = 'number' then (l.leg ->> 'startTime')::double precision end as starts,
             case when jsonb_typeof(l.leg -> 'endTime') = 'number' then (l.leg ->> 'endTime')::double precision end as ends,
             case when jsonb_typeof(l.leg -> 'delayMinutes') = 'number' then (l.leg ->> 'delayMinutes')::double precision * 60 else 0 end as delay
        from jsonb_array_elements(
               case when jsonb_typeof(p_status -> 'tripLegs') = 'array' then p_status -> 'tripLegs' else '[]'::jsonb end
             ) as l(leg)
       where l.leg ->> 'type' = 'flight'
    ) r
   where r.leg_id is not null and r.callsign is not null and r.departure is not null and r.arrival is not null
     and r.starts is not null and r.ends is not null
$$;

revoke all on all functions in schema private from public, anon, authenticated;
```

- [ ] **Step 4: List the new tables in the privileges guard**

In `supabase/tests/privileges.test.js`, replace:

```js
    'partner_push_retries',
  ]
```

with:

```js
    'partner_push_retries',
    // The live plane (20261114120000_partner_links_flight_live.sql).
    'airports',
    'live_flights',
    'live_flight_points',
    'flight_live_state',
  ]
```

- [ ] **Step 5: Run the tests, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js privileges.test.js advisors.test.js safeupdate.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 21`, `ℹ pass 21`, `ℹ fail 0`.

- [ ] **Step 6: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/migrations/20261114120000_partner_links_flight_live.sql supabase/tests/flight_live.test.js supabase/tests/privileges.test.js && git commit -m "feat(cloud): the live plane's tables, a flight's callsign, and a summary's flight legs that can be watched"
```

End the commit message with the session's `Co-Authored-By` line, here and in every commit below.

---

### Task 2: The 30-second check

**Files:**
- Modify: `supabase/tests/flight_live.test.js` (append)
- Modify: `supabase/migrations/20261114120000_partner_links_flight_live.sql` (append)

- [ ] **Step 1: Write the failing tests**

Append to the end of `supabase/tests/flight_live.test.js`:

```js
describe('the 30-second check (spec §10.2, §10.3)', () => {
  test('the script keeps flight-live’s password and address in the Vault, and the switch starts off', async (t) => {
    const d = await db(t)
    assert.match(await password(d), /^[0-9a-f]{64}$/)
    const [{ url }] = await asAdmin(d, "select decrypted_secret as url from vault.decrypted_secrets where name = 'flight_live_url'")
    assert.equal(url, 'https://corxvurxpnrzekbxdgye.supabase.co/functions/v1/flight-live')
    assert.deepEqual(await state(d), { mode: 'off', pilots: [], failures: 0, paused: null })
  })

  test('with the switch off it watches nothing and calls nothing', async (t) => {
    const d = await db(t)
    await pilotWith(d, [leg(-10, 500)])
    await tick(d)
    assert.deepEqual(await flights(d), [])
    assert.deepEqual(await requests(d), [])
  })

  test('with it on, a leg in its window gets a row with its airports’ positions, and flight-live is called with the password', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    await pilotWith(d, [leg(-10, 500)])
    await tick(d)
    assert.deepEqual(await flights(d), [{ id: 1, callsign: 'UPS207', departure: 'SDF', arrival: 'CGN', state: 'waiting', hex: null, fix: null }])
    const [row] = await asAdmin(d, 'select dep_lat, dep_lon, arr_lat, arr_lon from private.live_flights')
    assert.deepEqual(row, { dep_lat: 38.1744, dep_lon: -85.736, arr_lat: 50.8659, arr_lon: 7.1427 })
    assert.deepEqual(await requests(d), [
      {
        url: 'https://corxvurxpnrzekbxdgye.supabase.co/functions/v1/flight-live',
        headers: { 'content-type': 'application/json', 'x-flight-live-secret': await password(d) },
        body: {},
        timeout_milliseconds: 30000,
      },
    ])
  })

  test('the window opens 30 minutes before the effective departure and closes 2 hours after the effective arrival', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    await pilotWith(d, [
      leg(31, 500, { id: 'too-early', flightNumber: 'UPS1' }),
      leg(29, 500, { id: 'opening', flightNumber: 'UPS2' }),
      leg(-600, -119, { id: 'closing', flightNumber: 'UPS3' }),
      leg(-600, -121, { id: 'closed', flightNumber: 'UPS4' }),
      // A reported delay moves the window with it.
      leg(-10, 500, { id: 'held', flightNumber: 'UPS5', delayMinutes: 45 }),
      leg(-600, -150, { id: 'late', flightNumber: 'UPS6', delayMinutes: 45 }),
    ])
    await tick(d)
    assert.deepEqual((await flights(d)).map((f) => f.callsign).sort(), ['UPS2', 'UPS3', 'UPS6'])
  })

  test('a leg with an airport the table doesn’t have isn’t watched', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    await pilotWith(d, [leg(-10, 500, { arrivalAirport: 'XXX' })])
    await tick(d)
    assert.deepEqual(await flights(d), [])
    assert.deepEqual(await requests(d), [])
  })

  test('two pilots on one flight share a row, with the earliest departure and the latest arrival', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    const captain = leg(-10, 500, { id: 'captain' })
    await pilotWith(d, [captain])
    await pilotWith(d, [{ ...captain, id: 'first-officer', delayMinutes: 20 }])
    await tick(d)
    const rows = await asAdmin(
      d,
      'select extract(epoch from effective_departure)::int as departs, extract(epoch from effective_arrival)::int as arrives from private.live_flights',
    )
    assert.deepEqual(rows, [{ departs: captain.startTime, arrives: captain.endTime + 20 * 60 }])
  })

  test('a new delay moves the row’s times, and the row keeps its id', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    const one = leg(-10, 500)
    const { pilot } = await pilotWith(d, [one])
    await tick(d)
    await setStatus(d, pilot, { tripLegs: [{ ...one, delayMinutes: 15 }] }, 1)
    await tick(d)
    const rows = await asAdmin(d, 'select id::int, extract(epoch from effective_departure)::int as departs from private.live_flights')
    assert.deepEqual(rows, [{ id: 1, departs: one.startTime + 15 * 60 }])
  })

  test('a leg whose scheduled departure changes gets a new row, and the old one stays until the daily delete', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    const one = leg(-10, 500)
    const { pilot } = await pilotWith(d, [one])
    await tick(d)
    await setStatus(d, pilot, { tripLegs: [{ ...one, startTime: one.startTime + 300 }] }, 1)
    await tick(d)
    assert.deepEqual((await flights(d)).map((f) => f.id), [1, 2])
  })

  test('a pilot whose partners’ devices were all last seen over 30 days ago isn’t watched', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    const { deviceId } = await pilotWith(d, [leg(-10, 500)])
    await asAdmin(d, "update public.partner_devices set last_seen_at = now() - interval '31 days' where id = $1", [deviceId])
    await tick(d)
    assert.deepEqual(await flights(d), [])
    await asAdmin(d, "update public.partner_devices set last_seen_at = now() - interval '29 days' where id = $1", [deviceId])
    await tick(d)
    assert.equal((await flights(d)).length, 1)
  })

  test('switched to listed, only the listed pilots are watched', async (t) => {
    const d = await db(t)
    const listed = await pilotWith(d, [leg(-10, 500, { flightNumber: 'UPS1' })])
    await pilotWith(d, [leg(-10, 500, { flightNumber: 'UPS2' })])
    await switchTo(d, 'listed', [listed.pilot])
    await tick(d)
    assert.deepEqual((await flights(d)).map((f) => f.callsign), ['UPS1'])
    assert.deepEqual(await state(d), { mode: 'listed', pilots: [listed.pilot], failures: 0, paused: null })
  })

  test('the switch takes only off, listed or all', async (t) => {
    const d = await db(t)
    await assert.rejects(switchTo(d, 'on'), /flight_live_state_mode_check/)
    assert.equal((await state(d)).mode, 'off')
  })

  test('during a pause it watches nothing and calls nothing', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    await pilotWith(d, [leg(-10, 500)])
    await asAdmin(d, "update private.flight_live_state set paused_until = now() + interval '1 minute' where only_row")
    await tick(d)
    assert.deepEqual(await flights(d), [])
    assert.deepEqual(await requests(d), [])
    await asAdmin(d, "update private.flight_live_state set paused_until = now() - interval '1 second' where only_row")
    await tick(d)
    assert.equal((await requests(d)).length, 1)
  })

  test('a flight still seen in the air stays open after its window, a landed one doesn’t, and neither does one unseen for 30 minutes', async (t) => {
    const d = await db(t)
    await switchTo(d, 'all')
    const { pilot } = await pilotWith(d, [leg(-600, -100)])
    await tick(d)
    assert.equal((await requests(d)).length, 1)
    // The summary moves on, so the check no longer sets the row's times from it.
    await setStatus(d, pilot, { tripLegs: [] }, 1)
    // Three hours after its arrival, still in the air and seen a minute ago.
    await asAdmin(
      d,
      `update private.live_flights set effective_arrival = now() - interval '3 hours', state = 'airborne',
              seen_at = now() - interval '1 minute' where id = 1`,
    )
    await tick(d)
    assert.equal((await requests(d)).length, 2)
    await asAdmin(d, "update private.live_flights set seen_at = now() - interval '31 minutes' where id = 1")
    await tick(d)
    assert.equal((await requests(d)).length, 2)
    await asAdmin(d, "update private.live_flights set seen_at = now(), effective_arrival = now() - interval '13 hours' where id = 1")
    await tick(d)
    assert.equal((await requests(d)).length, 2)
    await asAdmin(d, "update private.live_flights set effective_arrival = now() + interval '1 hour', state = 'landed' where id = 1")
    await tick(d)
    assert.equal((await requests(d)).length, 2)
  })
})
```

- [ ] **Step 2: Run them, and see the new ones fail**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 18`, `ℹ pass 6`, `ℹ fail 12`. The new ones fail with `function private.flight_live_tick() does not exist`, or `private.flight_live_switch`. The one new test that passes checks the Vault and the switch's row, which Task 1 made.

- [ ] **Step 3: Write the check**

Append to the end of the script:

```sql
-- The flights whose window is open (spec §10.2): from 30 minutes before the effective departure until landing is seen
-- or 2 hours after the effective arrival. A flight still being seen in the air stays open until 30 minutes after its
-- last fix, to at most 12 hours after its effective arrival.
create function private.open_live_flights() returns setof private.live_flights
language sql stable set search_path = '' as $$
  select f.*
    from private.live_flights f
   where f.state <> 'landed'
     and now() >= f.effective_departure - interval '30 minutes'
     and (now() < f.effective_arrival + interval '2 hours'
          or (f.state = 'airborne' and f.seen_at > now() - interval '30 minutes'
              and now() < f.effective_arrival + interval '12 hours'))
$$;

-- Sets the switch (spec §10.7), in the SQL editor: 'off', 'listed' with the pilots' account ids, or 'all'.
--   select private.flight_live_switch('listed', array['00000000-0000-0000-0000-000000000000']::uuid[]);
create function private.flight_live_switch(p_mode text, p_pilots uuid[] default '{}') returns text
language plpgsql set search_path = '' as $$
begin
  update private.flight_live_state set mode = p_mode, pilots = coalesce(p_pilots, '{}') where only_row;
  return p_mode;
end
$$;

-- Calls flight-live with the password, and returns pg_net's request id. The body is empty: flight-live claims its work.
create function private.call_flight_live() returns bigint
language sql set search_path = '' as $$
  select net.http_post(
    url := private.push_secret('flight_live_url'),
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'content-type', 'application/json',
      'x-flight-live-secret', private.push_secret('flight_live_secret')
    ),
    timeout_milliseconds := 30000
  )
$$;

-- The 30-second check (spec §10.3), which pg_cron runs as postgres. With the switch on and no pause, it makes or updates
-- a row for every leg whose window is open, of the pilots the switch allows who have a partner's device seen in the
-- last 30 days. Pilots who share a flight share its row, with the earliest effective departure and the latest effective
-- arrival among them. Then, if any flight is open, it calls flight-live.
create function private.flight_live_tick() returns void
language plpgsql set search_path = '' as $$
declare
  v_state private.flight_live_state%rowtype;
begin
  select * into v_state from private.flight_live_state where only_row;
  if not found or v_state.mode = 'off' or (v_state.paused_until is not null and v_state.paused_until > now()) then
    return;
  end if;
  insert into private.live_flights as f (callsign, departure, arrival, scheduled_departure, effective_departure,
                                         effective_arrival, dep_lat, dep_lon, arr_lat, arr_lon)
  select w.callsign, w.departure, w.arrival, w.scheduled_departure, w.effective_departure, w.effective_arrival,
         d.lat, d.lon, a.lat, a.lon
    from (
      select l.callsign, l.departure, l.scheduled_departure, min(l.arrival) as arrival,
             min(l.effective_departure) as effective_departure, max(l.effective_arrival) as effective_arrival
        from public.partner_status ps
        cross join lateral private.flight_legs(ps.status) l
       where (v_state.mode = 'all' or ps.user_id = any (v_state.pilots))
         and exists (select 1 from public.partner_devices pd
                      where pd.owner_id = ps.user_id and pd.last_seen_at > now() - interval '30 days')
         and now() >= l.effective_departure - interval '30 minutes'
         and now() < l.effective_arrival + interval '2 hours'
       group by l.callsign, l.departure, l.scheduled_departure
    ) w
    join private.airports d on d.code = w.departure
    join private.airports a on a.code = w.arrival
  on conflict (callsign, departure, scheduled_departure) do update
    set arrival = excluded.arrival, arr_lat = excluded.arr_lat, arr_lon = excluded.arr_lon,
        effective_departure = excluded.effective_departure, effective_arrival = excluded.effective_arrival
    where (f.arrival, f.effective_departure, f.effective_arrival)
          is distinct from (excluded.arrival, excluded.effective_departure, excluded.effective_arrival);
  if exists (select 1 from private.open_live_flights()) then
    perform private.call_flight_live();
  end if;
end
$$;

revoke all on all functions in schema private from public, anon, authenticated;
```

- [ ] **Step 4: Run the tests, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js privileges.test.js advisors.test.js safeupdate.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 34`, `ℹ pass 34`, `ℹ fail 0`.

- [ ] **Step 5: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/migrations/20261114120000_partner_links_flight_live.sql supabase/tests/flight_live.test.js && git commit -m "feat(cloud): the live plane's 30-second check keeps a row for every flight whose window is open, behind a switch that starts off"
```

---

### Task 3: Claim and report

**Files:**
- Modify: `supabase/tests/flight_live.test.js` (append)
- Modify: `supabase/migrations/20261114120000_partner_links_flight_live.sql` (append)
- Modify: `supabase/tests/privileges.test.js`

- [ ] **Step 1: Write the failing tests**

Append to the end of `supabase/tests/flight_live.test.js`:

```js
describe('flight_live_claim and flight_live_report (spec §10.3, §10.5, §10.7)', () => {
  test('they refuse a wrong or missing password', async (t) => {
    const { d, id } = await watching(t)
    await assert.rejects(claim(d, 'wrong'), /flight_live_claim: wrong password/)
    await assert.rejects(claim(d, null), /flight_live_claim: wrong password/)
    await assert.rejects(report(d, 'wrong', [{ id, state: 'airborne', hex: 'a1', fix: fix(5) }]), /flight_live_report: wrong password/)
    assert.equal((await flights(d))[0].state, 'waiting')
    // The push service's password isn't this one's.
    const [{ s }] = await asAdmin(d, "select decrypted_secret as s from vault.decrypted_secrets where name = 'partner_push_secret'")
    await assert.rejects(claim(d, s), /flight_live_claim: wrong password/)
  })

  test('claim hands out the open flights, each with what the match needs', async (t) => {
    const { d, secret, id } = await watching(t)
    const [{ departs }] = await asAdmin(d, 'select (extract(epoch from effective_departure) * 1000)::float8 as departs from private.live_flights')
    assert.deepEqual(await claim(d, secret), {
      flights: [
        {
          id,
          callsign: 'UPS207',
          departure: { lat: 38.1744, lon: -85.736 },
          arrival: { lat: 50.8659, lon: 7.1427 },
          effective_departure: departs,
          state: 'waiting',
          hex: null,
        },
      ],
    })
    await asAdmin(d, "update private.live_flights set state = 'landed' where id = $1", [id])
    assert.deepEqual(await claim(d, secret), { flights: [] })
  })

  test('a fix in the air is kept, with a trail point for the first and then one every 110 seconds', async (t) => {
    const { d, secret, id } = await watching(t)
    const first = fix(300)
    assert.deepEqual(await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: first }]), { ok: true })
    assert.deepEqual(await flights(d), [{ id, callsign: 'UPS207', departure: 'SDF', arrival: 'CGN', state: 'airborne', hex: 'a82952', fix: first }])
    assert.deepEqual(await points(d), [{ flight: id, lat: 39.3, lon: -85.7, altitude_ft: 38000 }])
    // 109 seconds on: the fix moves, the trail doesn't.
    const second = fix(191, { lat: 39.5 })
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: second }])
    assert.deepEqual((await flights(d))[0].fix, second)
    assert.equal((await points(d)).length, 1)
    // 110 seconds on: a second point.
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: fix(190, { lat: 39.6, altitude_ft: 38012.4 }) }])
    assert.deepEqual(await points(d), [
      { flight: id, lat: 39.3, lon: -85.7, altitude_ft: 38000 },
      { flight: id, lat: 39.6, lon: -85.7, altitude_ft: 38012 },
    ])
  })

  test('a fix on the ground is kept, and adds no trail point', async (t) => {
    const { d, secret, id } = await watching(t)
    const parked = fix(5, { lat: 38.17, lon: -85.73, altitude_ft: null, ground_speed_kt: 0, track_deg: null, on_ground: true })
    await report(d, secret, [{ id, state: 'ground', hex: 'a82952', fix: parked }])
    assert.deepEqual((await flights(d))[0], { id, callsign: 'UPS207', departure: 'SDF', arrival: 'CGN', state: 'ground', hex: 'a82952', fix: parked })
    assert.deepEqual(await points(d), [])
  })

  test('a fix older than the one the flight has is left alone', async (t) => {
    const { d, secret, id } = await watching(t)
    const newer = fix(10)
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: newer }])
    await report(d, secret, [{ id, state: 'ground', hex: 'ffffff', fix: fix(60, { on_ground: true }) }])
    assert.deepEqual((await flights(d))[0].fix, newer)
    assert.equal((await flights(d))[0].state, 'airborne')
  })

  test('a landing is kept with its time, and the flight is finished: later fixes change nothing', async (t) => {
    const { d, secret, id } = await watching(t)
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: fix(400) }])
    const down = fix(30, { lat: 50.87, lon: 7.14, altitude_ft: null, on_ground: true })
    await report(d, secret, [{ id, state: 'landed', hex: 'a82952', fix: down }])
    const [row] = await asAdmin(d, 'select state, (extract(epoch from landed_at) * 1000)::float8 as landed from private.live_flights')
    assert.deepEqual(row, { state: 'landed', landed: down.seen_at })
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: fix(1) }])
    assert.deepEqual((await flights(d))[0].fix, down)
    assert.equal((await points(d)).length, 1)
    assert.deepEqual(await claim(d, secret), { flights: [] })
  })

  test('the fifth failure in a row pauses the check for 5 minutes, and a good answer starts the count again', async (t) => {
    const { d, secret } = await watching(t)
    for (let n = 1; n <= 4; n++) {
      await report(d, secret, [], 'failed')
      assert.deepEqual(await state(d), { mode: 'all', pilots: [], failures: n, paused: null })
    }
    await report(d, secret, [], 'ok')
    assert.equal((await state(d)).failures, 0)
    for (let n = 1; n <= 5; n++) await report(d, secret, [], 'failed')
    assert.deepEqual(await state(d), { mode: 'all', pilots: [], failures: 0, paused: true })
    const [{ minutes }] = await asAdmin(d, 'select round(extract(epoch from paused_until - now()) / 60)::int as minutes from private.flight_live_state')
    assert.equal(minutes, 5)
  })

  test('a 429 pauses the check for 2 minutes', async (t) => {
    const { d, secret } = await watching(t)
    await report(d, secret, [], 'limited')
    assert.equal((await state(d)).paused, true)
    const [{ minutes }] = await asAdmin(d, 'select round(extract(epoch from paused_until - now()) / 60)::int as minutes from private.flight_live_state')
    assert.equal(minutes, 2)
  })

  test('report refuses an outcome it doesn’t know', async (t) => {
    const { d, secret } = await watching(t)
    await assert.rejects(report(d, secret, [], 'fine'), (error) => error.code === '22023')
    await assert.rejects(report(d, secret, [], null), (error) => error.code === '22023')
  })
})
```

- [ ] **Step 2: Run them, and see the new ones fail**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 27`, `ℹ pass 18`, `ℹ fail 9`. The new ones fail because `public.flight_live_claim` and `public.flight_live_report` don't exist yet.

- [ ] **Step 3: Write claim and report**

Append to the end of the script:

```sql
-- Raises unless p_secret is the Vault's flight_live_secret.
create function private.require_flight_live_password(p_secret text, p_caller text) returns void
language plpgsql stable set search_path = '' as $$
begin
  if p_secret is null or p_secret is distinct from private.push_secret('flight_live_secret') then
    raise exception '%: wrong password', p_caller using errcode = '28000';
  end if;
end
$$;
revoke all on function private.require_flight_live_password(text, text) from public, anon, authenticated;

-- flight-live's first call each run (spec §10.3): the open flights, each with what the match needs. Times are
-- milliseconds since 1970.
create function public.flight_live_claim(p_secret text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_flight_live_password(p_secret, 'flight_live_claim');
  return jsonb_build_object('flights', coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', f.id,
             'callsign', f.callsign,
             'departure', jsonb_build_object('lat', f.dep_lat, 'lon', f.dep_lon),
             'arrival', jsonb_build_object('lat', f.arr_lat, 'lon', f.arr_lon),
             'effective_departure', (extract(epoch from f.effective_departure) * 1000)::bigint,
             'state', f.state,
             'hex', f.hex) order by f.id)
      from private.open_live_flights() f), '[]'::jsonb));
end
$$;
revoke all on function public.flight_live_claim(text) from public, anon, authenticated;
grant execute on function public.flight_live_claim(text) to service_role;

-- flight-live's last call each run (spec §10.3, §10.5, §10.7). p_flights is what it judged: [{id, state, hex, fix}],
-- only the flights with a new fix. A flight that has landed, and a fix older than the one a flight has, are left alone.
-- A fix in the air adds a trail point when the trail's last one is 110 seconds older or more. p_outcome is how asking
-- adsb.lol went: 'ok'; 'failed', which pauses the check for 5 minutes at the fifth in a row; or 'limited' (HTTP 429),
-- which pauses it for 2 minutes.
create function public.flight_live_report(p_secret text, p_flights jsonb, p_outcome text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_flight_live_password(p_secret, 'flight_live_report');
  if p_outcome is null or p_outcome not in ('ok', 'failed', 'limited') then
    raise exception 'flight_live_report: outcome must be ok, failed or limited' using errcode = '22023';
  end if;

  with judged as (
    select u.id, u.state, u.hex, u.fix, to_timestamp((u.fix ->> 'seen_at')::double precision / 1000) as seen_at
      from jsonb_to_recordset(coalesce(p_flights, '[]'::jsonb)) as u(id bigint, state text, hex text, fix jsonb)
  ), kept as (
    update private.live_flights f
       set state = j.state, hex = j.hex, fix = j.fix, seen_at = j.seen_at,
           landed_at = case when j.state = 'landed' then j.seen_at end
      from judged j
     where f.id = j.id and f.state <> 'landed' and (f.seen_at is null or j.seen_at >= f.seen_at)
    returning f.id, f.state, f.fix, f.seen_at
  )
  insert into private.live_flight_points (flight_id, at, lat, lon, altitude_ft)
  select k.id, k.seen_at, (k.fix ->> 'lat')::double precision, (k.fix ->> 'lon')::double precision,
         round((k.fix ->> 'altitude_ft')::numeric)::integer
    from kept k
   where k.state = 'airborne' and (k.fix ->> 'on_ground')::boolean is not true
     and not exists (select 1 from private.live_flight_points p
                      where p.flight_id = k.id and p.at > k.seen_at - interval '110 seconds');

  update private.flight_live_state
     set failures = case when p_outcome = 'failed' and failures < 4 then failures + 1 else 0 end,
         paused_until = case
           when p_outcome = 'limited' then now() + interval '2 minutes'
           when p_outcome = 'failed' and failures >= 4 then now() + interval '5 minutes'
           else paused_until
         end
   where only_row;
  return jsonb_build_object('ok', true);
end
$$;
revoke all on function public.flight_live_report(text, jsonb, text) from public, anon, authenticated;
grant execute on function public.flight_live_report(text, jsonb, text) to service_role;
```

- [ ] **Step 4: List the two RPCs in the privileges guard**

In `supabase/tests/privileges.test.js`, replace:

```js
  // partner-push's calls (piece 3, as the alert pushes left them): the service role only, which partner-push uses.
  const SERVICE_RPCS = ['partner_push_claim(text, boolean)', 'partner_push_report(text, text[], jsonb, text)']
```

with:

```js
  // partner-push's calls (piece 3, as the alert pushes left them) and flight-live's: the service role only, which both
  // functions use.
  const SERVICE_RPCS = [
    'partner_push_claim(text, boolean)',
    'partner_push_report(text, text[], jsonb, text)',
    'flight_live_claim(text)',
    'flight_live_report(text, jsonb, text)',
  ]
```

In `supabase/tests/privileges.test.js`, replace:

```js
  test("service RPCs: partner-push's service role only", async () => {
```

with:

```js
  test('service RPCs: the service role only, which partner-push and flight-live use', async () => {
```

- [ ] **Step 5: Run the tests, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js privileges.test.js advisors.test.js safeupdate.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 43`, `ℹ pass 43`, `ℹ fail 0`.

- [ ] **Step 6: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/migrations/20261114120000_partner_links_flight_live.sql supabase/tests/flight_live.test.js supabase/tests/privileges.test.js && git commit -m "feat(cloud): flight-live's claim and report: the open flights out, and each one's state, fix and trail in"
```

---

### Task 4: `partner_live`

**Files:**
- Modify: `supabase/tests/flight_live.test.js` (append)
- Modify: `supabase/migrations/20261114120000_partner_links_flight_live.sql` (append)
- Modify: `supabase/tests/privileges.test.js`, `supabase/tests/advisors.test.js`

- [ ] **Step 1: Write the failing tests**

Append to the end of `supabase/tests/flight_live.test.js`:

```js
describe('partner_live (spec §10.6)', () => {
  test('a key that isn’t a device’s answers sharing_ended', async (t) => {
    const d = await db(t)
    assert.deepEqual(await live(d, '0'.repeat(64)), { error: 'sharing_ended' })
    assert.deepEqual(await live(d, 'not a key'), { error: 'sharing_ended' })
  })

  test('it answers the pilot’s watched flight with its leg, fix and trail, and the server’s clock', async (t) => {
    const { d, pilot, secret, id } = await watching(t)
    const before = Date.now()
    const waiting = await live(d, pilot.key)
    assert.ok(waiting.now >= before - 1000 && waiting.now <= Date.now() + 1000, 'now is the clock, in milliseconds')
    assert.deepEqual(waiting, {
      now: waiting.now,
      cursor: 0,
      flights: [{ leg_id: 'trip-leg-0', callsign: 'UPS207', state: 'waiting', fix: null, landed_at: null, trail: [], trail_count: 0 }],
    })
    const seen = fix(5)
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: seen }])
    const flying = await live(d, pilot.key)
    assert.deepEqual(flying.flights, [
      { leg_id: 'trip-leg-0', callsign: 'UPS207', state: 'airborne', fix: seen, landed_at: null, trail: [[seen.seen_at, 39.3, -85.7, 38000]], trail_count: 1 },
    ])
    assert.equal(flying.cursor, 1)
  })

  test('with the last answer’s cursor it hands over only the newer points, and still counts them all', async (t) => {
    const { d, pilot, secret, id } = await watching(t)
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: fix(400) }])
    const first = await live(d, pilot.key)
    assert.equal(first.flights[0].trail.length, 1)
    const later = fix(200, { lat: 40.1 })
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: later }])
    const second = await live(d, pilot.key, first.cursor)
    assert.deepEqual(second.flights[0].trail, [[later.seen_at, 40.1, -85.7, 38000]])
    assert.equal(second.flights[0].trail_count, 2)
    assert.equal(second.cursor, 2)
    // Nothing new: the cursor stays, and the trail is empty.
    const third = await live(d, pilot.key, second.cursor)
    assert.deepEqual([third.cursor, third.flights[0].trail, third.flights[0].trail_count], [2, [], 2])
  })

  test('a landed flight carries its landing time', async (t) => {
    const { d, pilot, secret, id } = await watching(t)
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: fix(400) }])
    const down = fix(30, { altitude_ft: null, on_ground: true })
    await report(d, secret, [{ id, state: 'landed', hex: 'a82952', fix: down }])
    const [flight] = (await live(d, pilot.key)).flights
    assert.deepEqual([flight.state, flight.landed_at, flight.fix], ['landed', down.seen_at, down])
  })

  test('a partner sees only their own pilot’s flights', async (t) => {
    const { d, secret, id } = await watching(t)
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: fix(5) }])
    const other = await pilotWith(d, [leg(-10, 500, { id: 'other', flightNumber: 'UPS9' })])
    assert.deepEqual((await live(d, other.key)).flights, [])
    // Once the other pilot's flight is watched too, each partner still sees one.
    await tick(d)
    assert.deepEqual((await live(d, other.key)).flights.map((f) => f.callsign), ['UPS9'])
  })

  test('a first officer on the captain’s flight sees the same row under their own leg', async (t) => {
    const { d, secret, id } = await watching(t)
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: fix(5) }])
    const firstOfficer = await pilotWith(d, [leg(-10, 500, { id: 'fo-leg' })])
    const [flight] = (await live(d, firstOfficer.key)).flights
    assert.deepEqual([flight.leg_id, flight.state, flight.trail_count], ['fo-leg', 'airborne', 1])
  })

  test('a leg the pilot removes stops being answered at once', async (t) => {
    const { d, pilot } = await watching(t)
    assert.equal((await live(d, pilot.key)).flights.length, 1)
    await setStatus(d, pilot.pilot, { tripLegs: [] }, 1)
    assert.deepEqual((await live(d, pilot.key)).flights, [])
  })

  test('with the switch off it answers no flights, and listed answers only the listed pilots’ partners', async (t) => {
    const { d, pilot } = await watching(t)
    await switchTo(d, 'off')
    assert.deepEqual((await live(d, pilot.key)).flights, [])
    await switchTo(d, 'listed', ['00000000-0000-0000-0000-000000000000'])
    assert.deepEqual((await live(d, pilot.key)).flights, [])
    await switchTo(d, 'listed', [pilot.pilot])
    assert.equal((await live(d, pilot.key)).flights.length, 1)
  })

  test('it doesn’t count as the device being seen', async (t) => {
    const { d, pilot } = await watching(t)
    await asAdmin(d, "update public.partner_devices set last_seen_at = now() - interval '1 day' where id = $1", [pilot.deviceId])
    await live(d, pilot.key)
    const [{ seen }] = await asAdmin(d, "select last_seen_at < now() - interval '23 hours' as seen from public.partner_devices where id = $1", [pilot.deviceId])
    assert.equal(seen, true)
  })
})
```

- [ ] **Step 2: Run them, and see the new ones fail**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 36`, `ℹ pass 27`, `ℹ fail 9`. The new ones fail with `function public.partner_live(text) does not exist`.

- [ ] **Step 3: Write `partner_live`**

Append to the end of the script:

```sql
-- The pilot's flights with live data, for one of their partners' devices (spec §10.6):
--   {"now", "cursor", "flights": [{"leg_id", "callsign", "state", "fix", "landed_at", "trail", "trail_count"}]}
-- A flight is answered for each flight leg in the pilot's summary now whose key has a row, so a leg the pilot hides or
-- removes stops at once. trail holds the points after p_after, the last answer's cursor, or every point without it;
-- trail_count is how many the flight has, so a device can tell when it has missed some. Times are milliseconds since
-- 1970. With the switch off, or the pilot not listed, it answers no flights. It doesn't count as the device being seen:
-- partner_view does that.
create function public.partner_live(p_key text, p_after bigint default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_device record;
  v_state private.flight_live_state%rowtype;
  v_flights jsonb := '[]'::jsonb;
  v_cursor bigint := coalesce(p_after, 0);
begin
  select * into v_device from private.device_for_key(p_key);
  if not found then
    return jsonb_build_object('error', 'sharing_ended');
  end if;
  select * into v_state from private.flight_live_state where only_row;
  if found and (v_state.mode = 'all' or (v_state.mode = 'listed' and v_device.owner_id = any (v_state.pilots))) then
    select coalesce(jsonb_agg(a.flight order by a.scheduled_departure, a.leg_id), '[]'::jsonb),
           greatest(coalesce(p_after, 0), coalesce(max(a.last_point), 0))
      into v_flights, v_cursor
      from (
        select l.leg_id, f.scheduled_departure,
               (select max(p.id) from private.live_flight_points p where p.flight_id = f.id) as last_point,
               jsonb_build_object(
                 'leg_id', l.leg_id,
                 'callsign', f.callsign,
                 'state', f.state,
                 'fix', f.fix,
                 'landed_at', (extract(epoch from f.landed_at) * 1000)::bigint,
                 'trail', coalesce((
                   select jsonb_agg(jsonb_build_array((extract(epoch from p.at) * 1000)::bigint, p.lat, p.lon, p.altitude_ft)
                                    order by p.id)
                     from private.live_flight_points p
                    where p.flight_id = f.id and p.id > coalesce(p_after, 0)), '[]'::jsonb),
                 'trail_count', (select count(*) from private.live_flight_points p where p.flight_id = f.id)) as flight
          from public.partner_status ps
          cross join lateral private.flight_legs(ps.status) l
          join private.live_flights f
            on f.callsign = l.callsign and f.departure = l.departure and f.scheduled_departure = l.scheduled_departure
         where ps.user_id = v_device.owner_id
      ) a;
  end if;
  return jsonb_build_object(
    'now', (extract(epoch from clock_timestamp()) * 1000)::bigint,
    'cursor', v_cursor,
    'flights', v_flights);
end
$$;
revoke all on function public.partner_live(text, bigint) from public, anon, authenticated;
grant execute on function public.partner_live(text, bigint) to anon, authenticated;
```

- [ ] **Step 4: List it in the privileges and advisor guards**

It's a security definer function the publishable key can call, like the other partner RPCs, so the advisor's lists gain it on purpose.

In `supabase/tests/privileges.test.js`, replace:

```js
    'partner_set_push(text, text, text, boolean)',
  ]
```

with:

```js
    'partner_set_push(text, text, text, boolean)',
    // The live plane (20261114120000_partner_links_flight_live.sql).
    'partner_live(text, bigint)',
  ]
```

In `supabase/tests/advisors.test.js`, replace:

```js
// p_alerts with the alert pushes (20261023120000_partner_links_alert_pushes.sql).
const SET_PUSH = 'public.partner_set_push(text, text, text, boolean)'
const PARTNER_RPCS = [
  'public.partner_handoff_create(text)',
  'public.partner_handoff_redeem(text, text, text, text)',
  'public.partner_join(text, text, text, text)',
  'public.partner_leave(text)',
  SET_PUSH,
  'public.partner_view(text, timestamp with time zone)',
]
/** The partner RPCs as CrewLu Cloud had them before the alert pushes. */
const PARTNER_RPCS_BEFORE_ALERTS = PARTNER_RPCS.map((fn) => (fn === SET_PUSH ? 'public.partner_set_push(text, text, text)' : fn))
```

with:

```js
// p_alerts with the alert pushes (20261023120000_partner_links_alert_pushes.sql), and partner_live came with the live
// plane (20261114120000_partner_links_flight_live.sql).
const SET_PUSH = 'public.partner_set_push(text, text, text, boolean)'
const LIVE = 'public.partner_live(text, bigint)'
const PARTNER_RPCS = [
  'public.partner_handoff_create(text)',
  'public.partner_handoff_redeem(text, text, text, text)',
  'public.partner_join(text, text, text, text)',
  'public.partner_leave(text)',
  LIVE,
  SET_PUSH,
  'public.partner_view(text, timestamp with time zone)',
]
/** The partner RPCs as CrewLu Cloud had them before the alert pushes: no partner_live, and partner_set_push without p_alerts. */
const PARTNER_RPCS_BEFORE_ALERTS = PARTNER_RPCS.filter((fn) => fn !== LIVE).map((fn) =>
  fn === SET_PUSH ? 'public.partner_set_push(text, text, text)' : fn,
)
```

In `supabase/tests/advisors.test.js`, replace:

```js
test('0028 anon_security_definer_function_executable: only the 6 partner RPCs', async () => {
```

with:

```js
test('0028 anon_security_definer_function_executable: only the 7 partner RPCs', async () => {
```

In `supabase/tests/advisors.test.js`, replace:

```js
test('0029 authenticated_security_definer_function_executable: the 14 partner-links RPCs and delete_my_account', async () => {
```

with:

```js
test('0029 authenticated_security_definer_function_executable: the 15 partner-links RPCs and delete_my_account', async () => {
```

- [ ] **Step 5: Run the tests, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js privileges.test.js advisors.test.js safeupdate.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 52`, `ℹ pass 52`, `ℹ fail 0`.

- [ ] **Step 6: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/migrations/20261114120000_partner_links_flight_live.sql supabase/tests/flight_live.test.js supabase/tests/privileges.test.js supabase/tests/advisors.test.js && git commit -m "feat(cloud): partner_live answers a partner's device with its own pilot's flights: each one's state, fix and trail, by leg"
```

---

### Task 5: The schedule, the daily delete, and the script's second run and undo

**Files:**
- Modify: `supabase/tests/flight_live.test.js` (append)
- Modify: `supabase/migrations/20261114120000_partner_links_flight_live.sql` (append)

- [ ] **Step 1: Write the failing tests**

Append to the end of `supabase/tests/flight_live.test.js`:

```js
describe('the schedule and the daily delete (spec §10.3, §10.5)', () => {
  test('pg_cron runs the check every 30 seconds, and two clean-ups once a day', async (t) => {
    const d = await db(t)
    assert.deepEqual(await asAdmin(d, "select jobname, schedule from cron.job where jobname like 'flight-live%' order by jobname"), [
      { jobname: 'flight-live', schedule: '30 seconds' },
      { jobname: 'flight-live-cleanup', schedule: '23 4 * * *' },
      { jobname: 'flight-live-history', schedule: '19 4 * * *' },
    ])
    const [{ command }] = await asAdmin(d, "select command from cron.job where jobname = 'flight-live'")
    assert.equal(command, 'select private.flight_live_tick()')
  })

  test('a flight and its trail go 16 days after it landed, or after its arrival if it never did', async (t) => {
    const { d, secret, id } = await watching(t)
    await report(d, secret, [{ id, state: 'airborne', hex: 'a82952', fix: fix(5) }])
    const add = (callsign, landed, arrival) =>
      asAdmin(
        d,
        `insert into private.live_flights (callsign, departure, arrival, scheduled_departure, effective_departure, effective_arrival,
                                           dep_lat, dep_lon, arr_lat, arr_lon, landed_at)
         values ($1, 'SDF', 'CGN', now(), now(), now() + $3::interval, 0, 0, 0, 0, now() + $2::interval)`,
        [callsign, landed, arrival],
      )
    await add('OLD1', '-17 days', '-17 days')
    await add('NEW1', '-15 days', '-17 days')
    await add('OLD2', null, '-17 days')
    await add('NEW2', null, '-15 days')
    await asAdmin(d, "insert into private.live_flight_points (flight_id, at, lat, lon) select id, now(), 0, 0 from private.live_flights where callsign = 'OLD1'")
    const [{ command }] = await asAdmin(d, "select command from cron.job where jobname = 'flight-live-cleanup'")
    await d.exec(command)
    assert.deepEqual((await flights(d)).map((f) => f.callsign), ['UPS207', 'NEW1', 'NEW2'])
    assert.deepEqual((await points(d)).map((p) => p.flight), [id])
  })

  test('the history clean-up keeps a day of this piece’s runs, and leaves other jobs’ alone', async (t) => {
    const d = await db(t)
    const [{ check }] = await asAdmin(d, "select jobid::int as check from cron.job where jobname = 'flight-live'")
    await asAdmin(
      d,
      `insert into cron.job_run_details (jobid, status, end_time)
       values ($1, 'succeeded', now() - interval '25 hours'), ($1, 'succeeded', now() - interval '23 hours'),
              (999, 'succeeded', now() - interval '2 days')`,
      [check],
    )
    const [{ command }] = await asAdmin(d, "select command from cron.job where jobname = 'flight-live-history'")
    await d.exec(command)
    assert.deepEqual(await asAdmin(d, 'select jobid::int as job from cron.job_run_details order by runid'), [{ job: check }, { job: 999 }])
  })
})

describe('the script, run again and undone', () => {
  const made = (d) =>
    asAdmin(
      d,
      `select (select count(*)::int from pg_proc where proname in ('partner_live', 'flight_live_claim', 'flight_live_report',
                'flight_live_tick', 'call_flight_live', 'flight_live_switch', 'open_live_flights',
                'require_flight_live_password', 'flight_legs', 'flight_callsign', 'airport_code')) as functions,
              (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'private' and c.relkind = 'r'
                  and c.relname in ('airports', 'live_flights', 'live_flight_points', 'flight_live_state')) as tables,
              (select count(*)::int from vault.secrets where name like 'flight_live%') as secrets,
              (select count(*)::int from cron.job where jobname like 'flight-live%') as jobs`,
    ).then((rows) => rows[0])

  test('running it a second time fails at its first create table, and changes nothing', async (t) => {
    const d = await partnerDbUpTo(FILE)
    t.after(() => d.close())
    const before = await made(d)
    assert.deepEqual(before, { functions: 11, tables: 4, secrets: 2, jobs: 3 })
    await assert.rejects(d.exec(read(migration)), /relation "airports" already exists/)
    assert.deepEqual(await made(d), before)
  })

  test('the undo in its header removes everything it added, and nothing of the push service’s', async (t) => {
    const d = await partnerDbUpTo(FILE)
    t.after(() => d.close())
    await d.exec(undoSql())
    assert.deepEqual(await made(d), { functions: 0, tables: 0, secrets: 0, jobs: 0 })
    const [kept] = await asAdmin(
      d,
      `select to_regprocedure('public.partner_view(text, timestamptz)') is not null as view,
              to_regprocedure('private.push_secret(text)') is not null as secret,
              (select count(*)::int from cron.job where jobname like 'partner-push%') as jobs,
              (select count(*)::int from vault.secrets where name like 'partner_push%') as secrets`,
    )
    assert.deepEqual(kept, { view: true, secret: true, jobs: 2, secrets: 2 })
    // And it can be run again after its undo.
    await d.exec(read(migration))
    assert.deepEqual(await made(d), { functions: 11, tables: 4, secrets: 2, jobs: 3 })
  })
})
```

- [ ] **Step 2: Run them, and see the new ones fail**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 41`, `ℹ pass 36`, `ℹ fail 5`. The new ones fail because no cron job is scheduled yet, so the script still makes 0 of its 3.

- [ ] **Step 3: Write the schedule**

Append to the end of the script:

```sql
select cron.schedule('flight-live', '30 seconds', 'select private.flight_live_tick()');
-- A flight's row and its trail go 16 days after it landed, or after its effective arrival if it never did (spec §10.5):
-- the longest trip and its recap day. Deleted at 04:23 UTC.
select cron.schedule('flight-live-cleanup', '23 4 * * *', $$
  delete from private.live_flights
   where coalesce(landed_at, effective_arrival) < now() - interval '16 days'
$$);
-- pg_cron logs every run, about 2,900 a day for the check. This keeps a day of this piece's, deleted at 04:19 UTC.
select cron.schedule('flight-live-history', '19 4 * * *', $$
  delete from cron.job_run_details
   where end_time < now() - interval '1 day'
     and jobid in (select jobid from cron.job where jobname in ('flight-live', 'flight-live-cleanup', 'flight-live-history'))
$$);
```

- [ ] **Step 4: Run the tests, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live.test.js privileges.test.js advisors.test.js safeupdate.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 57`, `ℹ pass 57`, `ℹ fail 0`.

- [ ] **Step 5: Check the two files are whole**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase && shasum -a 256 migrations/20261114120000_partner_links_flight_live.sql tests/flight_live.test.js
```

Expected:

```
1b15bf69ca41aa5bf8c5fed367328dd8e901f943ccf489c2d3c71afe824cef27  migrations/20261114120000_partner_links_flight_live.sql
6e6608799c78c9ca4ef8e0cfcf247e256429c387a775e506e79b880d12cf6dfa  tests/flight_live.test.js
```

A different sum with passing tests means a difference in spacing where two parts join. That's harmless: note it and go on.

- [ ] **Step 6: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/migrations/20261114120000_partner_links_flight_live.sql supabase/tests/flight_live.test.js && git commit -m "feat(cloud): the live plane's check runs every 30 seconds, a flight and its trail go after 16 days, and the script's second run and undo are tested"
```

---

### Task 6: The airports

**Files:**
- Create: `supabase/tests/helpers/airports_seed.js`
- Create: `supabase/tests/flight_live_airports.test.js`
- Create: `supabase/migrations/20261114120100_flight_live_airports.sql` (made by the script)
- Modify: `supabase/tests/package.json`

The script reads `~/Dev/Crewluve Website/public/data/airports.json`: 9,056 airports as `[code, name, country, lat, lon, time zone]`. If that file isn't there, stop and ask.

- [ ] **Step 1: Write the failing tests**

Create `supabase/tests/flight_live_airports.test.js`:

```js
// The live plane's airports (supabase/migrations/20261114120100_flight_live_airports.sql), which fill private.airports
// from the Crewluve website's airports.json, and the script that makes the file (helpers/airports_seed.js). Spec:
// Crewluv docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md §10.1.
import assert from 'node:assert/strict'
import { existsSync } from 'node:fs'
import { describe, test } from 'node:test'
import { AIRPORTS_SEED, WEBSITE_AIRPORTS, airportsSeedSql } from './helpers/airports_seed.js'
import { asAdmin, cloudDb, migrationPath, partnerMigrations, read } from './helpers/db.js'

const seed = migrationPath(AIRPORTS_SEED)

/** A database with the partner-links migrations and the seed, closed when the test ends. */
async function seeded(t) {
  const d = await cloudDb([...partnerMigrations(), AIRPORTS_SEED])
  t.after(() => d.close())
  return d
}

const count = async (d) => (await asAdmin(d, 'select count(*)::int as n from private.airports'))[0].n

describe("the live plane's airports (spec §10.1)", () => {
  test("the seed fills private.airports with the website's 9,056 airports", async (t) => {
    const d = await seeded(t)
    assert.equal(await count(d), 9056)
    assert.deepEqual(await asAdmin(d, "select code, lat, lon from private.airports where code in ('SDF', 'CGN', 'ANC') order by code"), [
      { code: 'ANC', lat: 61.1744, lon: -149.9983 },
      { code: 'CGN', lat: 50.8659, lon: 7.1427 },
      { code: 'SDF', lat: 38.1746, lon: -85.7382 },
    ])
  })

  test('running it a second time fails, and changes nothing', async (t) => {
    const d = await seeded(t)
    await assert.rejects(d.exec(read(seed)), /duplicate key value violates unique constraint "airports_pkey"/)
    assert.equal(await count(d), 9056)
  })

  test('the undo in its header empties the table, and the seed can run again', async (t) => {
    const d = await seeded(t)
    const lines = read(seed).split('\n')
    const undo = lines.slice(lines.findIndex((line) => line.startsWith('-- Undo')) + 1).filter((line) => line.startsWith('--   '))
    assert.deepEqual(undo, ['--   truncate private.airports;'])
    await d.exec(undo[0].slice('--   '.length))
    assert.equal(await count(d), 0)
    await d.exec(read(seed))
    assert.equal(await count(d), 9056)
  })

  test("the file is what the script makes from the website's airports.json", { skip: !existsSync(WEBSITE_AIRPORTS) && "the website's repo isn't beside this one" }, () => {
    assert.equal(read(seed), airportsSeedSql(JSON.parse(read(WEBSITE_AIRPORTS))))
  })

  test("the script refuses an airport the table can't hold", () => {
    assert.match(airportsSeedSql([['SDF', 'Louisville', 'USA', 38.1746, -85.7382, 'America/Kentucky/Louisville']]), /\('SDF',38\.1746,-85\.7382\);\n$/)
    for (const bad of [['KSDF', '', '', 38, -85], ["A'B", '', '', 38, -85], ['SDF', '', '', 91, -85], ['SDF', '', '', 38, 181], ['SDF', '', '', null, -85]]) {
      assert.throws(() => airportsSeedSql([bad]), /an airport the table can't hold/)
    }
  })
})
```

- [ ] **Step 2: Write the script that makes the file**

Create `supabase/tests/helpers/airports_seed.js`:

```js
// Makes supabase/migrations/20261114120100_flight_live_airports.sql, which fills private.airports, from the Crewluve
// website's airports.json: its 9,056 airports as [code, name, country, lat, lon, time zone]. Run it again when the
// website's file changes, with `npm run airports-seed` from supabase/tests, and commit what it writes.
import { readFileSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { migrationPath } from './db.js'

/** The seed's file name, and where the website keeps the airports it's made from. */
export const AIRPORTS_SEED = '20261114120100_flight_live_airports.sql'
export const WEBSITE_AIRPORTS = join(homedir(), 'Dev', 'Crewluve Website', 'public', 'data', 'airports.json')

const HEADER = `-- The live plane's airports (Crewluv docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md §10.1):
-- each airport's code and position, from the Crewluve website's public/data/airports.json. Made by
-- supabase/tests/helpers/airports_seed.js: change it there, never by hand.
--
-- Run it once, in the SQL editor, after 20261114120000_partner_links_flight_live.sql: a second run fails, since the
-- codes are there already, and changes nothing.
--
-- Undo, in the SQL editor:
--   truncate private.airports;
`

/** The seed's SQL for the website's airports: one insert, a row for each, in the file's order. */
export function airportsSeedSql(airports) {
  const rows = airports.map(([code, , , lat, lon]) => {
    const inRange = typeof lat === 'number' && typeof lon === 'number' && Math.abs(lat) <= 90 && Math.abs(lon) <= 180
    if (!/^[A-Z0-9]{3}$/.test(String(code)) || !inRange) {
      throw new Error(`airports.json has an airport the table can't hold: ${JSON.stringify([code, lat, lon])}`)
    }
    return `('${code}',${lat},${lon})`
  })
  return `${HEADER}\ninsert into private.airports (code, lat, lon) values\n${rows.join(',\n')};\n`
}

// Run as a script, it writes the seed.
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const airports = JSON.parse(readFileSync(WEBSITE_AIRPORTS, 'utf8'))
  writeFileSync(migrationPath(AIRPORTS_SEED), airportsSeedSql(airports))
  console.log(`${AIRPORTS_SEED}: ${airports.length} airports`)
}
```

- [ ] **Step 3: Add its `npm` script**

In `supabase/tests/package.json`, replace:

```json
    "test": "node --no-maglev --test"
```

with:

```json
    "test": "node --no-maglev --test",
    "airports-seed": "node helpers/airports_seed.js"
```

- [ ] **Step 4: Run the tests, and see them fail**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live_airports.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 5`, `ℹ pass 1`, `ℹ fail 4`: the file isn't made yet, and only the test of the script itself passes.

- [ ] **Step 5: Make the file**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && npm run airports-seed 2>&1 | tail -1 && shasum -a 256 ../migrations/20261114120100_flight_live_airports.sql
```

Expected:

```
20261114120100_flight_live_airports.sql: 9056 airports
4623413c992dba30053d10e010ff0d5851ab569bd2b95c8f80d610329833b1e2  ../migrations/20261114120100_flight_live_airports.sql
```

A different sum means the website's `airports.json` has changed since 14 Nov 2026. Say so to Todd and go on: the tests hold the file to the website's.

- [ ] **Step 6: Run the tests, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live_airports.test.js advisors.test.js safeupdate.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ fail 0`, and `ℹ tests` equal to `ℹ pass`. The advisor and safeupdate guards load every migration, so they now load the airports too.

- [ ] **Step 7: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/migrations/20261114120100_flight_live_airports.sql supabase/tests/helpers/airports_seed.js supabase/tests/flight_live_airports.test.js supabase/tests/package.json && git commit -m "feat(cloud): the live plane's airports, 9,056 of them from the Crewluve website's file, and the script that makes them"
```

---

### Task 7: `flight-live`'s parts and the match

**Files:**
- Create: `supabase/tests/flight_live_function.test.js`
- Create: `supabase/functions/flight-live/index.ts`

- [ ] **Step 1: Write the failing tests**

Create `supabase/tests/flight_live_function.test.js`. `RECORDED` is a real aircraft from adsb.lol's answer, so the tests read the fields as adsb.lol sends them.

```js
// flight-live (supabase/functions/flight-live/index.ts), run under Node. Stand-ins take the place of adsb.lol and of
// the database's claim and report, and the last tests run it against the real ones in PGlite. No test calls adsb.lol:
// its answers here are records of real ones. Spec: Crewluv
// docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md, §10.3, §10.4 and §10.7.
import assert from 'node:assert/strict'
import { describe, test } from 'node:test'
import { distanceNm, fixOf, isBetween, judge } from '../functions/flight-live/index.ts'

const SDF = { lat: 38.1744, lon: -85.736 }
const CGN = { lat: 50.8659, lon: 7.1427 }
const NOW_MS = 1_794_713_157_000
const MINUTE = 60_000

/**
 * One aircraft from adsb.lol's answer to /v2/callsign/FDX147, recorded on 15 Nov 2026 over Indiana, with the fields
 * flight-live doesn't read left out. The callsign is padded to 8 characters, as adsb.lol sends it.
 */
const RECORDED = {
  hex: 'a82952',
  type: 'adsb_icao',
  flight: 'FDX147  ',
  r: 'N625FE',
  t: 'MD11',
  alt_baro: 38000,
  alt_geom: 38075,
  gs: 464.4,
  track: 229.28,
  lat: 39.365876,
  lon: -85.678162,
  seen_pos: 0.0,
  seen: 0.0,
}

/** The same record's shape on the ground, from an aircraft parked at St. Louis in the same answer: no track, alt_baro "ground". */
const RECORDED_ON_GROUND = { hex: 'ab525f', type: 'adsb_icao', flight: 'AAL772  ', r: 'N829AW', t: 'A319', alt_baro: 'ground', gs: 0.0, lat: 38.743833, lon: -90.364532, seen_pos: 3.567, seen: 1.7 }

/** UPS207 in the air over Indiana, as adsb.lol would answer it, with fields over it. */
const flying = (fields = {}) => ({ ...RECORDED, flight: 'UPS207  ', r: 'N370UP', t: 'B763', ...fields })
/** UPS207 on the ground at Louisville's ramp, with fields over it. */
const parked = (fields = {}) => ({ ...RECORDED_ON_GROUND, hex: 'a82952', flight: 'UPS207  ', r: 'N370UP', t: 'B763', lat: 38.17, lon: -85.73, ...fields })

/** UPS207 from Louisville to Cologne, leaving at NOW_MS, as claim hands it out, with fields over it. */
const flight = (fields = {}) => ({ id: 7, callsign: 'UPS207', departure: SDF, arrival: CGN, effective_departure: NOW_MS, state: 'waiting', hex: null, ...fields })

describe("flight-live's parts (spec §10.4)", () => {
  test('distanceNm is the great-circle distance in nautical miles', () => {
    assert.ok(Math.abs(distanceNm(SDF, CGN) - 3780.6) < 0.1)
    assert.equal(distanceNm(SDF, SDF), 0)
    // Across the date line, the short way round.
    assert.ok(Math.abs(distanceNm({ lat: 0, lon: 179 }, { lat: 0, lon: -179 }) - 120.1) < 0.1)
  })

  test('between the airports allows a wide routing, and not a place far off to one side', () => {
    const gander = { lat: 48.95, lon: -54.57 }
    const reykjavik = { lat: 64.13, lon: -21.9 }
    const azores = { lat: 37.74, lon: -25.67 }
    const dakar = { lat: 14.7, lon: -17.4 }
    assert.deepEqual([gander, reykjavik, azores, SDF, CGN].map((place) => isBetween(flight(), place)), [true, true, true, true, true])
    assert.equal(isBetween(flight(), dakar), false)
  })

  test("a fix in the air has the aircraft's position, height, speed, track, tail and type, seen seen_pos seconds before the answer", () => {
    assert.deepEqual(fixOf({ ...RECORDED, seen_pos: 2.5 }, NOW_MS), {
      lat: 39.365876,
      lon: -85.678162,
      altitude_ft: 38000,
      ground_speed_kt: 464,
      track_deg: 229,
      on_ground: false,
      registration: 'N625FE',
      type_code: 'MD11',
      seen_at: NOW_MS - 2500,
    })
  })

  test('a fix on the ground has no height, and no track when adsb.lol sends none', () => {
    assert.deepEqual(fixOf(RECORDED_ON_GROUND, NOW_MS), {
      lat: 38.743833,
      lon: -90.364532,
      altitude_ft: null,
      ground_speed_kt: 0,
      track_deg: null,
      on_ground: true,
      registration: 'N829AW',
      type_code: 'A319',
      seen_at: NOW_MS - 3567,
    })
  })

  test('a fix leaves out a blank tail or type, and a height that isn’t a number', () => {
    const bare = fixOf({ hex: 'a1', lat: 1, lon: 2, seen_pos: 0, r: '  ', alt_baro: undefined }, NOW_MS)
    assert.deepEqual([bare.registration, bare.type_code, bare.altitude_ft, bare.ground_speed_kt, bare.on_ground], [null, null, null, null, false])
  })
})

describe('the match (spec §10.4)', () => {
  const judged = (state, aircraft) => ({ id: 7, state, hex: aircraft.hex, fix: fixOf(aircraft, NOW_MS) })

  test('an aircraft on the ground at the departure airport is the flight, and the flight takes it', () => {
    assert.deepEqual(judge(flight(), [parked()], NOW_MS), judged('ground', parked()))
    // 9 nm from the airport still counts, and 11 nm doesn't.
    assert.deepEqual(judge(flight(), [parked({ lat: 38.3244, lon: -85.736 })], NOW_MS)?.state, 'ground')
    assert.equal(judge(flight({ effective_departure: NOW_MS + 60 * MINUTE }), [parked({ lat: 38.3577, lon: -85.736 })], NOW_MS), null)
  })

  test('its own aircraft, then seen in the air, has taken off, however early', () => {
    const early = flight({ state: 'ground', hex: 'a82952', effective_departure: NOW_MS + 40 * MINUTE })
    assert.deepEqual(judge(early, [flying()], NOW_MS), judged('airborne', flying()))
  })

  test('another callsign, or the same letters inside a longer one, is never the flight', () => {
    assert.equal(judge(flight(), [flying({ flight: 'UPS2070 ' }), flying({ flight: 'FDX207  ' }), flying({ flight: undefined })], NOW_MS), null)
  })

  test('an aircraft with no address, no position or a position over a minute old is no candidate', () => {
    const stale = [flying({ seen_pos: 61 }), flying({ lat: undefined }), flying({ hex: undefined }), flying({ seen_pos: undefined })]
    assert.equal(judge(flight(), stale, NOW_MS), null)
    assert.deepEqual(judge(flight(), [flying({ seen_pos: 60 })], NOW_MS)?.state, 'airborne')
  })

  test('first seen in the air, it is the flight only from 20 minutes before its effective departure', () => {
    assert.equal(judge(flight({ effective_departure: NOW_MS + 21 * MINUTE }), [flying()], NOW_MS), null)
    assert.deepEqual(judge(flight({ effective_departure: NOW_MS + 20 * MINUTE }), [flying()], NOW_MS), judged('airborne', flying()))
    assert.deepEqual(judge(flight({ effective_departure: NOW_MS - 300 * MINUTE }), [flying()], NOW_MS)?.state, 'airborne')
  })

  test('first seen in the air, it is the flight only between its airports: a reused flight number elsewhere is not', () => {
    const overDakar = flying({ hex: 'c0ffee', lat: 14.7, lon: -17.4 })
    assert.equal(judge(flight(), [overDakar], NOW_MS), null)
    // With both in the answer, the one between the airports is taken.
    assert.deepEqual(judge(flight(), [overDakar, flying()], NOW_MS)?.hex, 'a82952')
  })

  test('before it has flown, an aircraft at the gate takes the place of the one it had: an aircraft swap', () => {
    const swapped = flight({ state: 'ground', hex: '0ld0ne' })
    assert.deepEqual(judge(swapped, [parked({ hex: 'a82952' })], NOW_MS)?.hex, 'a82952')
    // With both at the gate, it keeps its own.
    assert.deepEqual(judge(swapped, [parked({ hex: 'a82952' }), parked({ hex: '0ld0ne' })], NOW_MS)?.hex, '0ld0ne')
  })

  test('once in the air it follows its own aircraft wherever it goes, and no other', () => {
    const inAir = flight({ state: 'airborne', hex: 'a82952' })
    const farOff = flying({ lat: 14.7, lon: -17.4 })
    assert.deepEqual(judge(inAir, [farOff], NOW_MS), judged('airborne', farOff))
    assert.equal(judge(inAir, [flying({ hex: 'c0ffee' }), parked({ hex: 'c0ffee' })], NOW_MS), null)
    assert.equal(judge(inAir, [], NOW_MS), null)
  })

  test('down within 10 nm of the arrival airport, it has landed', () => {
    const inAir = flight({ state: 'airborne', hex: 'a82952' })
    const atCologne = parked({ lat: 50.87, lon: 7.14 })
    assert.deepEqual(judge(inAir, [atCologne], NOW_MS), judged('landed', atCologne))
  })

  test('down anywhere else it is on the ground again: a return to the departure airport, or a diversion', () => {
    const inAir = flight({ state: 'airborne', hex: 'a82952' })
    assert.deepEqual(judge(inAir, [parked()], NOW_MS)?.state, 'ground')
    const atGander = parked({ lat: 48.94, lon: -54.57 })
    assert.deepEqual(judge(inAir, [atGander], NOW_MS), judged('ground', atGander))
    // Still there on the next run, its fix is kept fresh, and when it flies again it is in the air again.
    const diverted = flight({ state: 'ground', hex: 'a82952' })
    assert.deepEqual(judge(diverted, [atGander], NOW_MS), judged('ground', atGander))
    assert.deepEqual(judge(diverted, [flying({ lat: 49.5, lon: -50 })], NOW_MS)?.state, 'airborne')
  })

  test('back-to-back legs with one flight number: the next leg doesn’t take the plane still flying the one before', () => {
    // UPS207 again from Cologne in 3 hours. The plane is still over the Atlantic, inbound.
    const next = flight({ id: 8, departure: CGN, arrival: { lat: 25.2528, lon: 55.3644 }, effective_departure: NOW_MS + 180 * MINUTE })
    assert.equal(judge(next, [flying({ lat: 51.5, lon: -20 })], NOW_MS), null)
    // Once it's parked at Cologne, the next leg takes it.
    assert.deepEqual(judge(next, [parked({ lat: 50.87, lon: 7.14 })], NOW_MS)?.state, 'ground')
  })
})
```

- [ ] **Step 2: Run them, and see them fail**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live_function.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail\|ERR_MODULE_NOT_FOUND" | head -4
```

Expected: `ERR_MODULE_NOT_FOUND`, with `ℹ pass 0` and `ℹ fail 1`: the function's file isn't there.

- [ ] **Step 3: Write the parts and the match**

Create `supabase/functions/flight-live/index.ts`:

```ts
// flight-live: finds where pilots' flights really are, for the Crewluve moving map (Crewluv
// docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md §10, whose sections a plain "spec §"
// names). The 30-second check, private.flight_live_tick(), calls it with the Vault's password. It claims the flights
// whose window is open (flight_live_claim), asks adsb.lol once for all their callsigns, judges which aircraft in the
// answer is each flight, and reports the fixes back (flight_live_report).
//
// One file with no imports, so it can be pasted whole into Supabase's function editor. Its tests run it under Node
// (supabase/tests/flight_live_function.test.js), so it serves only where Deno is.

/** adsb.lol's lookup by callsign. It takes several, with commas between them (spec §2.1). */
export const ADSB_URL = 'https://api.adsb.lol/v2/callsign/'

/** Who's asking, for adsb.lol's logs: they ask callers to say. */
export const USER_AGENT = 'CrewLuCloud-flight-live/1 (+https://crewlu.net)'

/** How many callsigns go in one request, and how long each request may take (spec §10.3). */
export const CALLSIGNS_PER_REQUEST = 100
export const ADSB_TIMEOUT_MS = 10_000

/** How long a call to Crewlu Cloud may take, so one held up in the database can't hold a run up for minutes. */
export const RPC_TIMEOUT_MS = 20_000

/** A position older than this isn't a fix (spec §10.4), in seconds. */
export const FRESH_S = 60

/** How near an airport a plane on the ground must be to be at it, in nautical miles. */
export const AIRPORT_RADIUS_NM = 10

/** A flight first seen in the air counts only from this long before its effective departure. */
export const EARLY_SIGHTING_MS = 20 * 60_000

/**
 * Between the two airports: a place's distance from one plus its distance to the other is no more than this many times
 * the distance between them, plus this margin in nautical miles. Wide enough for a routing around closed airspace.
 */
export const BETWEEN_FACTOR = 1.3
export const BETWEEN_MARGIN_NM = 200

/** A place on the Earth, in degrees. */
export type Place = { lat: number; lon: number }

/** What flight-live knows of a flight: never seen, on the ground, in the air, or landed at its arrival airport. */
export type State = 'waiting' | 'ground' | 'airborne' | 'landed'

/** A flight flight_live_claim hands out. effective_departure is milliseconds since 1970; hex is its aircraft, once one is taken. */
export type Flight = {
  id: number
  callsign: string
  departure: Place
  arrival: Place
  effective_departure: number
  state: State
  hex: string | null
}

/** One aircraft in adsb.lol's answer: the fields flight-live reads (spec §2.1). */
export type Aircraft = {
  hex?: string
  flight?: string
  r?: string
  t?: string
  lat?: number
  lon?: number
  alt_baro?: number | 'ground'
  gs?: number
  track?: number
  seen_pos?: number
}

/** A fix, as live_flights keeps it and partner_live answers it (spec §10.5). seen_at is milliseconds since 1970. */
export type Fix = {
  lat: number
  lon: number
  altitude_ft: number | null
  ground_speed_kt: number | null
  track_deg: number | null
  on_ground: boolean
  registration: string | null
  type_code: string | null
  seen_at: number
}

/** What flight-live judged of one flight: its new state, the aircraft it is, and that aircraft's fix. */
export type Update = { id: number; state: State; hex: string; fix: Fix }

/** How asking adsb.lol went: answered, failed, or told to slow down (HTTP 429). */
export type Outcome = 'ok' | 'failed' | 'limited'

const EARTH_RADIUS_NM = 3440.065
const radians = (degrees: number) => (degrees * Math.PI) / 180

/** The great-circle distance between two places, in nautical miles. */
export function distanceNm(from: Place, to: Place): number {
  const dLat = radians(to.lat - from.lat)
  const dLon = radians(to.lon - from.lon)
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(radians(from.lat)) * Math.cos(radians(to.lat)) * Math.sin(dLon / 2) ** 2
  return 2 * EARTH_RADIUS_NM * Math.asin(Math.min(1, Math.sqrt(h)))
}

/** Whether a place is between a flight's two airports (spec §10.4). */
export function isBetween(flight: Flight, place: Place): boolean {
  const direct = distanceNm(flight.departure, flight.arrival)
  return distanceNm(flight.departure, place) + distanceNm(place, flight.arrival) <= BETWEEN_FACTOR * direct + BETWEEN_MARGIN_NM
}

/** An aircraft with what a fix needs: its address, and a position seen in the last minute. */
type Seen = Aircraft & { hex: string; lat: number; lon: number; seen_pos: number }

const isSeen = (aircraft: Aircraft): aircraft is Seen =>
  typeof aircraft.hex === 'string' &&
  aircraft.hex !== '' &&
  typeof aircraft.lat === 'number' &&
  typeof aircraft.lon === 'number' &&
  typeof aircraft.seen_pos === 'number' &&
  aircraft.seen_pos >= 0 &&
  aircraft.seen_pos <= FRESH_S

const onGround = (aircraft: Aircraft) => aircraft.alt_baro === 'ground'
const whole = (value: unknown) => (typeof value === 'number' && Number.isFinite(value) ? Math.round(value) : null)
const text = (value: unknown) => (typeof value === 'string' && value.trim() !== '' ? value.trim() : null)

/** An aircraft's fix. Its position was seen seen_pos seconds before the answer came, at answeredAt. */
export function fixOf(aircraft: Seen, answeredAt: number): Fix {
  return {
    lat: aircraft.lat,
    lon: aircraft.lon,
    altitude_ft: onGround(aircraft) ? null : whole(aircraft.alt_baro),
    ground_speed_kt: whole(aircraft.gs),
    track_deg: whole(aircraft.track),
    on_ground: onGround(aircraft),
    registration: text(aircraft.r),
    type_code: text(aircraft.t),
    seen_at: Math.round(answeredAt - aircraft.seen_pos * 1000),
  }
}

/**
 * The match (spec §10.4): which aircraft in adsb.lol's answer is this flight, and what that makes its state. Null when
 * none is, and the flight keeps what it has. A flight follows one aircraft once it's seen in the air, wherever it goes,
 * so a reused flight number on another plane, or another leg with the same number, can't take its place.
 */
export function judge(flight: Flight, answer: Aircraft[], answeredAt: number): Update | null {
  const candidates = answer.filter((aircraft): aircraft is Seen => isSeen(aircraft) && aircraft.flight?.trim() === flight.callsign)
  const own = candidates.find((aircraft) => aircraft.hex === flight.hex)
  const judged = (aircraft: Seen, state: State): Update => ({ id: flight.id, state, hex: aircraft.hex, fix: fixOf(aircraft, answeredAt) })
  const isAt = (aircraft: Seen, airport: Place) => distanceNm(aircraft, airport) <= AIRPORT_RADIUS_NM

  if (flight.state === 'airborne') {
    if (!own) return null
    if (!onGround(own)) return judged(own, 'airborne')
    // Down at the arrival airport, it has landed. Down anywhere else is a return or a diversion.
    return judged(own, isAt(own, flight.arrival) ? 'landed' : 'ground')
  }

  // Not yet seen in the air. Its own aircraft, now in the air, has taken off.
  if (own && !onGround(own)) return judged(own, 'airborne')
  // An aircraft on the ground at the departure airport is the flight: its own first, else another, as after a swap.
  const atDeparture = candidates.filter((aircraft) => onGround(aircraft) && isAt(aircraft, flight.departure))
  const parked = atDeparture.find((aircraft) => aircraft.hex === flight.hex) ?? atDeparture[0]
  if (parked) return judged(parked, 'ground')
  // Another aircraft in the air is the flight only near its departure time or after, and only between its airports.
  if (answeredAt >= flight.effective_departure - EARLY_SIGHTING_MS) {
    const flying = candidates.find((aircraft) => !onGround(aircraft) && isBetween(flight, aircraft))
    if (flying) return judged(flying, 'airborne')
  }
  // Its own aircraft, still on the ground somewhere else after a diversion.
  if (own) return judged(own, 'ground')
  return null
}
```

- [ ] **Step 4: Run the tests, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live_function.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 16`, `ℹ pass 16`, `ℹ fail 0`. Node warns that type stripping is experimental: that's expected.

- [ ] **Step 5: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/functions/flight-live/index.ts supabase/tests/flight_live_function.test.js && git commit -m "feat(cloud): flight-live's match follows the aircraft: taken at the departure airport or between the airports near departure time, then wherever it goes"
```

---

### Task 8: `flight-live`'s run

**Files:**
- Modify: `supabase/tests/flight_live_function.test.js`
- Modify: `supabase/functions/flight-live/index.ts` (append)

- [ ] **Step 1: Write the failing tests**

In `supabase/tests/flight_live_function.test.js`, replace this line:

```js
import { distanceNm, fixOf, isBetween, judge } from '../functions/flight-live/index.ts'
```

with:

```js
import {
  ADSB_TIMEOUT_MS,
  ADSB_URL,
  CALLSIGNS_PER_REQUEST,
  RPC_TIMEOUT_MS,
  USER_AGENT,
  configFromEnv,
  distanceNm,
  fixOf,
  isBetween,
  judge,
  makeHandler,
} from '../functions/flight-live/index.ts'
```

Then append to the end of the file:

```js
const SUPABASE_URL = 'https://cloud.test'
const SECRET = 'the-vault-password'
const settings = () => ({ supabaseUrl: SUPABASE_URL, serviceKey: 'sb_secret_test' })

/**
 * A stand-in for fetch that records every request. Crewlu Cloud's functions answer through rpc(name, args), and
 * adsb.lol through adsb(callsigns, init), which returns {status, body} or throws, as fetch does when a connection fails.
 */
function standIns({ rpc, adsb = () => ({ status: 200, body: { ac: [] } }) }) {
  const requests = []
  const rpcPath = `${SUPABASE_URL}/rest/v1/rpc/`
  async function fetch(url, init) {
    requests.push({ url, init })
    if (url.startsWith(rpcPath)) {
      const { status = 200, body } = await rpc(url.slice(rpcPath.length), JSON.parse(init.body))
      return Response.json(body, { status })
    }
    assert.ok(url.startsWith(ADSB_URL), `an unexpected address: ${url}`)
    const { status = 200, body, text } = await adsb(url.slice(ADSB_URL.length).split(','), init)
    return new Response(text ?? JSON.stringify(body), { status })
  }
  return {
    fetch,
    requests,
    asked: () => requests.filter(({ url }) => url.startsWith(ADSB_URL)),
    calls: (name) => requests.filter(({ url }) => url === rpcPath + name).map(({ init }) => JSON.parse(init.body)),
  }
}

/** claim's and report's stand-ins. Like the real ones, they refuse any password but SECRET with SQLSTATE 28000, which PostgREST answers with 403. */
const cloud =
  ({ flights = [], reportStatus = 200 } = {}) =>
  (name, args) => {
    if (args.p_secret !== SECRET) return { status: 403, body: { code: '28000', message: `${name}: wrong password` } }
    if (name === 'flight_live_claim') return { body: { flights } }
    return { status: reportStatus, body: reportStatus === 200 ? { ok: true } : { message: 'unavailable' } }
  }

/** One run of flight-live, called the way the check calls it: the password in its header, and the body {}. */
async function run(fetch, { secret = SECRET, config = settings(), log = () => {} } = {}) {
  const handle = makeHandler({ config, fetch, now: () => NOW_MS, log })
  const headers = { 'content-type': 'application/json' }
  if (secret !== null) headers['x-flight-live-secret'] = secret
  const response = await handle(new Request('https://cloud.test/functions/v1/flight-live', { method: 'POST', headers, body: '{}' }))
  return { status: response.status, body: await response.json() }
}

describe("flight-live's run (spec §10.3, §10.7)", () => {
  test('it asks adsb.lol once for every open flight’s callsign, and reports what it judged', async () => {
    const flights = [flight(), flight({ id: 8, callsign: 'UPS2961' }), flight({ id: 9, callsign: 'FDX147' })]
    const fake = standIns({ rpc: cloud({ flights }), adsb: () => ({ body: { ac: [flying(), RECORDED], now: NOW_MS } }) })
    assert.deepEqual(await run(fake.fetch), { status: 200, body: { flights: 3, requests: 1, fixes: 2, outcome: 'ok' } })
    const [asked] = fake.asked()
    assert.equal(asked.url, 'https://api.adsb.lol/v2/callsign/UPS207,UPS2961,FDX147')
    assert.equal(asked.init.method, 'GET')
    assert.deepEqual(asked.init.headers, { accept: 'application/json', 'user-agent': USER_AGENT })
    assert.match(USER_AGENT, /CrewLuCloud/)
    assert.deepEqual(fake.calls('flight_live_report'), [
      {
        p_secret: SECRET,
        p_flights: [
          { id: 7, state: 'airborne', hex: 'a82952', fix: fixOf(flying(), NOW_MS) },
          { id: 9, state: 'airborne', hex: 'a82952', fix: fixOf(RECORDED, NOW_MS) },
        ],
        p_outcome: 'ok',
      },
    ])
  })

  test('flights that share a callsign are asked for once', async () => {
    const flights = [flight(), flight({ id: 8, departure: CGN, arrival: SDF, effective_departure: NOW_MS + 600 * MINUTE })]
    const fake = standIns({ rpc: cloud({ flights }), adsb: () => ({ body: { ac: [parked()] } }) })
    assert.deepEqual((await run(fake.fetch)).body, { flights: 2, requests: 1, fixes: 1, outcome: 'ok' })
    assert.equal(fake.asked()[0].url, `${ADSB_URL}UPS207`)
  })

  test('more than 100 callsigns go in further requests, one after another', async () => {
    const flights = Array.from({ length: 2 * CALLSIGNS_PER_REQUEST + 1 }, (_, n) => flight({ id: n + 1, callsign: `UPS${n + 1}` }))
    let inFlight = 0
    const fake = standIns({
      rpc: cloud({ flights }),
      adsb: async (callsigns) => {
        assert.equal(++inFlight, 1, 'one request at a time')
        await new Promise((done) => setTimeout(done, 5))
        inFlight -= 1
        return { body: { ac: callsigns.slice(0, 1).map((callsign) => parked({ flight: callsign })) } }
      },
    })
    assert.deepEqual((await run(fake.fetch)).body, { flights: 201, requests: 3, fixes: 3, outcome: 'ok' })
    assert.deepEqual(fake.asked().map(({ url }) => url.slice(ADSB_URL.length).split(',').length), [100, 100, 1])
  })

  test('a callsign that isn’t letters and digits never goes in an address', async () => {
    const fake = standIns({ rpc: cloud({ flights: [flight({ callsign: 'UPS207/../x' }), flight({ id: 8, callsign: 'UPS2961' })] }) })
    await run(fake.fetch)
    assert.deepEqual(fake.asked().map(({ url }) => url), [`${ADSB_URL}UPS2961`])
  })

  test('with no flight open it asks nothing and reports nothing', async () => {
    const fake = standIns({ rpc: cloud() })
    assert.deepEqual(await run(fake.fetch), { status: 200, body: { flights: 0, requests: 0, fixes: 0, outcome: 'ok' } })
    assert.deepEqual([fake.asked(), fake.calls('flight_live_report')], [[], []])
  })

  test('a wrong or missing password is refused by claim, and nothing is asked', async () => {
    for (const secret of ['wrong', null]) {
      const fake = standIns({ rpc: cloud({ flights: [flight()] }) })
      assert.deepEqual(await run(fake.fetch, { secret }), { status: 401, body: { error: 'claim answered 403' } })
      assert.deepEqual(fake.asked(), [])
    }
  })

  test('each request has a time limit: 10 seconds for adsb.lol and 20 for Crewlu Cloud', async () => {
    const fake = standIns({ rpc: cloud({ flights: [flight()] }) })
    await run(fake.fetch)
    assert.ok(fake.requests.every(({ init }) => init.signal instanceof AbortSignal))
    assert.deepEqual([ADSB_TIMEOUT_MS, RPC_TIMEOUT_MS], [10_000, 20_000])
  })

  const failures = [
    ['a timeout', () => { throw new DOMException('timed out', 'TimeoutError') }, 'failed'],
    ['an error status', () => ({ status: 503, body: {} }), 'failed'],
    ['an answer that isn’t JSON', () => ({ text: '<html>' }), 'failed'],
    ['an answer with no aircraft list', () => ({ body: { msg: 'No error' } }), 'failed'],
    ['a 429', () => ({ status: 429, body: {} }), 'limited'],
  ]
  for (const [what, adsb, outcome] of failures) {
    test(`${what} from adsb.lol keeps nothing from the run, and is reported as ${outcome}`, async () => {
      const fake = standIns({ rpc: cloud({ flights: [flight()] }), adsb })
      assert.deepEqual(await run(fake.fetch), { status: 200, body: { flights: 1, requests: 1, fixes: 0, outcome } })
      assert.deepEqual(fake.calls('flight_live_report'), [{ p_secret: SECRET, p_flights: [], p_outcome: outcome }])
    })
  }

  test('a failure in a later request keeps nothing from the earlier ones', async () => {
    const flights = Array.from({ length: CALLSIGNS_PER_REQUEST + 1 }, (_, n) => flight({ id: n + 1, callsign: `UPS${n + 1}` }))
    let request = 0
    const fake = standIns({ rpc: cloud({ flights }), adsb: () => (++request === 1 ? { body: { ac: [parked({ flight: 'UPS1' })] } } : { status: 500, body: {} }) })
    assert.deepEqual((await run(fake.fetch)).body, { flights: 101, requests: 2, fixes: 0, outcome: 'failed' })
  })

  test('a report Crewlu Cloud turns away answers 502', async () => {
    const fake = standIns({ rpc: cloud({ flights: [flight()], reportStatus: 500 }) })
    assert.deepEqual(await run(fake.fetch), { status: 502, body: { error: 'report answered 500', flights: 1, requests: 1, fixes: 0, outcome: 'ok' } })
  })

  test('a missing setting answers 500, naming it, and calls nothing', async () => {
    const fake = standIns({ rpc: cloud() })
    const lines = []
    const answered = await run(fake.fetch, { config: { supabaseUrl: SUPABASE_URL }, log: (line) => lines.push(line) })
    assert.deepEqual(answered, { status: 500, body: { error: 'flight-live is missing SUPABASE_SECRET_KEYS' } })
    assert.deepEqual([fake.requests, lines], [[], ['flight-live is missing SUPABASE_SECRET_KEYS']])
  })

  test('its settings come from the environment: the address, and the default secret key', () => {
    const env = { SUPABASE_URL, SUPABASE_SECRET_KEYS: JSON.stringify({ default: 'sb_secret_test', other: 'x' }) }
    assert.deepEqual(configFromEnv((name) => env[name]), settings())
    assert.deepEqual(configFromEnv(() => undefined), { supabaseUrl: undefined, serviceKey: undefined })
    assert.equal(configFromEnv((name) => ({ SUPABASE_SECRET_KEYS: 'not json' })[name]).serviceKey, undefined)
  })

  test('the log holds counts and error names, never the password or an address', async () => {
    const lines = []
    const fake = standIns({ rpc: cloud({ flights: [flight()] }), adsb: () => { throw new TypeError(`fetch failed for ${ADSB_URL}UPS207 with ${SECRET}`) } })
    await run(fake.fetch, { log: (line) => lines.push(line) })
    assert.deepEqual(lines, ['flight-live: asking adsb.lol was stopped by a TypeError', 'flight-live: 1 flights, 1 requests, 0 fixes, failed'])
  })
})
```

- [ ] **Step 2: Run them, and see them fail**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live_function.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail\|does not provide an export" | head -4
```

Expected: `does not provide an export named 'ADSB_TIMEOUT_MS'`, with `ℹ pass 0` and `ℹ fail 1`.

- [ ] **Step 3: Write the run**

Append to the end of `supabase/functions/flight-live/index.ts`:

```ts
/** flight-live's settings, and the names they're set under. Supabase supplies both. */
const SETTING_NAMES = {
  supabaseUrl: 'SUPABASE_URL',
  serviceKey: 'SUPABASE_SECRET_KEYS',
} as const

export type Config = { [setting in keyof typeof SETTING_NAMES]?: string }

/** What a run needs: its settings, and fetch, the clock and the log, which the tests stand in for. */
export type Deps = {
  config: Config
  fetch: (url: string, init: RequestInit) => Promise<Response>
  now: () => number
  log: (line: string) => void
}

/** flight-live itself: one run per call from the check (spec §10.3). */
export function makeHandler({ config, fetch, now, log }: Deps) {
  const answer = (status: number, body: object) => Response.json(body, { status })

  /** Calls one of Crewlu Cloud's functions through PostgREST, as the service role. */
  async function rpc(name: string, args: object) {
    const response = await fetch(`${config.supabaseUrl}/rest/v1/rpc/${name}`, {
      method: 'POST',
      // A new secret key goes in the apikey header only: Supabase refuses one in Authorization.
      headers: { apikey: config.serviceKey!, 'content-type': 'application/json' },
      body: JSON.stringify(args),
      signal: AbortSignal.timeout(RPC_TIMEOUT_MS),
    })
    const body = await response.text()
    return { ok: response.ok, status: response.status, body: body ? JSON.parse(body) : null }
  }

  /**
   * Asks adsb.lol for every callsign, 100 to a request, one request after another. A request that fails, or is told
   * to slow down, ends the asking: nothing is judged from part of an answer.
   */
  async function ask(callsigns: string[]): Promise<{ outcome: Outcome; aircraft: Aircraft[]; answeredAt: number; requests: number }> {
    const aircraft: Aircraft[] = []
    let requests = 0
    for (let first = 0; first < callsigns.length; first += CALLSIGNS_PER_REQUEST) {
      requests += 1
      const stopped = (outcome: Outcome) => ({ outcome, aircraft: [], answeredAt: now(), requests })
      try {
        const response = await fetch(ADSB_URL + callsigns.slice(first, first + CALLSIGNS_PER_REQUEST).join(','), {
          method: 'GET',
          headers: { accept: 'application/json', 'user-agent': USER_AGENT },
          signal: AbortSignal.timeout(ADSB_TIMEOUT_MS),
        })
        if (response.status === 429) return stopped('limited')
        if (!response.ok) {
          log(`flight-live: adsb.lol answered ${response.status}`)
          return stopped('failed')
        }
        const body = await response.json()
        if (!Array.isArray(body?.ac)) {
          log("flight-live: adsb.lol's answer has no aircraft list")
          return stopped('failed')
        }
        aircraft.push(...body.ac)
      } catch (error) {
        // A timeout, a network error, or an answer that isn't JSON.
        log(`flight-live: asking adsb.lol was stopped by a ${(error as Error).name}`)
        return stopped('failed')
      }
    }
    return { outcome: 'ok', aircraft, answeredAt: now(), requests }
  }

  return async function handle(request: Request): Promise<Response> {
    try {
      const missing = Object.entries(SETTING_NAMES)
        .filter(([setting]) => !config[setting as keyof Config])
        .map(([, name]) => name)
      if (missing.length > 0) {
        const error = `flight-live is missing ${missing.join(', ')}`
        log(error)
        return answer(500, { error })
      }

      const secret = request.headers.get('x-flight-live-secret')
      const claimed = await rpc('flight_live_claim', { p_secret: secret })
      if (!claimed.ok) {
        log(`flight-live: claim answered ${claimed.status}`)
        return answer(claimed.status === 403 ? 401 : 502, { error: `claim answered ${claimed.status}` })
      }
      const flights: Flight[] = claimed.body.flights
      if (flights.length === 0) return answer(200, { flights: 0, requests: 0, fixes: 0, outcome: 'ok' })

      // Each callsign once, however many flights share it, and only ones that are letters and digits: they go in an address.
      const callsigns = [...new Set(flights.map((flight) => flight.callsign))].filter((callsign) => /^[A-Z0-9]{2,8}$/.test(callsign))
      const asked = await ask(callsigns)
      const updates = asked.outcome === 'ok' ? flights.flatMap((flight) => judge(flight, asked.aircraft, asked.answeredAt) ?? []) : []

      const reported = await rpc('flight_live_report', { p_secret: secret, p_flights: updates, p_outcome: asked.outcome })
      const counts = { flights: flights.length, requests: asked.requests, fixes: updates.length, outcome: asked.outcome }
      if (!reported.ok) {
        log(`flight-live: report answered ${reported.status}`)
        return answer(502, { error: `report answered ${reported.status}`, ...counts })
      }
      log(`flight-live: ${counts.flights} flights, ${counts.requests} requests, ${counts.fixes} fixes, ${counts.outcome}`)
      return answer(200, counts)
    } catch (error) {
      // Only the error's name: a message can quote an address or an answer.
      log(`flight-live: stopped by a ${(error as Error).name}`)
      return answer(502, { error: (error as Error).name })
    }
  }
}

/** flight-live's settings, from its environment. */
export function configFromEnv(get: (name: string) => string | undefined): Config {
  return {
    supabaseUrl: get('SUPABASE_URL'),
    serviceKey: defaultSecretKey(get('SUPABASE_SECRET_KEYS')),
  }
}

/**
 * The default key in SUPABASE_SECRET_KEYS, the project's secret keys by name, which Supabase supplies. The legacy
 * SUPABASE_SERVICE_ROLE_KEY isn't used: Supabase stops the legacy keys at the end of 2026.
 */
function defaultSecretKey(keys: string | undefined): string | undefined {
  try {
    return JSON.parse(keys ?? '{}').default
  } catch {
    return undefined
  }
}

// In Supabase, Deno runs this file, and it serves every call, reading its settings each time. Under Node, in the
// tests, there's no Deno, so nothing is served.
const deno = (globalThis as any).Deno
if (deno) {
  deno.serve((request: Request) =>
    makeHandler({
      config: configFromEnv((name) => deno.env.get(name)),
      fetch: (url, init) => fetch(url, init),
      now: () => Date.now(),
      log: (line) => console.log(line),
    })(request),
  )
}
```

- [ ] **Step 4: Run the tests, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live_function.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ tests 33`, `ℹ pass 33`, `ℹ fail 0`.

- [ ] **Step 5: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/functions/flight-live/index.ts supabase/tests/flight_live_function.test.js && git commit -m "feat(cloud): flight-live asks adsb.lol once for every open flight's callsign, and reports what it judged and how the asking went"
```

---

### Task 9: `flight-live` against the real claim and report

**Files:**
- Modify: `supabase/tests/flight_live_function.test.js`

These tests join Tasks 1 to 8: the check queues a call, `flight-live` runs on it against the real SQL in PGlite, and `partner_live` shows the fix. They need no new code, so they should pass at once. If one fails, the two halves disagree: stop and ask.

- [ ] **Step 1: Write the tests**

In `supabase/tests/flight_live_function.test.js`, add these two lines right under the import from `../functions/flight-live/index.ts`:

```js
import { asAdmin, asAnon, asService, freshDb } from './helpers/db.js'
import { connected, setStatus } from './helpers/rpc.js'
```

Then append to the end of the file:

```js
/**
 * Crewlu Cloud's RPC door, as PostgREST runs it for the secret key: the body's keys are the function's named
 * arguments, and an error comes back as JSON, with PostgREST's status for its SQLSTATE (28000 is 403).
 */
function postgrest(database) {
  const casts = { p_flights: '::jsonb' }
  return async (name, args) => {
    const names = Object.keys(args)
    const call = names.map((arg, i) => `${arg} => $${i + 1}${casts[arg] ?? ''}`).join(', ')
    try {
      const values = names.map((arg) => (casts[arg] === '::jsonb' ? JSON.stringify(args[arg]) : args[arg]))
      const [{ r }] = await asService(database, `select public.${name}(${call}) as r`, values)
      return { body: r }
    } catch (error) {
      return { status: { 28000: 403, 42883: 404 }[error.code] ?? 400, body: { code: error.code, message: error.message } }
    }
  }
}

/** The call the check asked pg_net to make, as flight-live receives it. */
async function queued(database) {
  const rows = await asAdmin(database, 'select url, headers, body from net.http_request_queue order by id')
  return rows.map(({ url, headers, body }) => new Request(url, { method: 'POST', headers, body: JSON.stringify(body) }))
}

describe('flight-live against the real claim and report', () => {
  /** A database with the switch on and a pilot whose UPS207 left Louisville for Cologne 10 minutes ago. */
  async function watching(t) {
    const d = await freshDb()
    t.after(() => d.close())
    await asAdmin(d, "insert into private.airports (code, lat, lon) values ('SDF', 38.1744, -85.736), ('CGN', 50.8659, 7.1427)")
    await asAdmin(d, "select private.flight_live_switch('all')")
    const pilot = await connected(d)
    const seconds = (minutes) => Math.floor(Date.now() / 1000) + minutes * 60
    const leg = { id: 'leg-1', type: 'flight', startTime: seconds(-10), endTime: seconds(500), flightNumber: 'UPS0207', departureAirport: 'SDF', arrivalAirport: 'CGN' }
    await setStatus(d, pilot.pilot, { tripLegs: [leg] }, 1)
    return { d, pilot }
  }

  /** The check, then flight-live on the call it queued, with adsb.lol answering `aircraft`. Its clock is the real one, as the database's is. */
  async function runOnce(d, aircraft) {
    await asAdmin(d, 'select private.flight_live_tick()')
    const calls = await queued(d)
    const fake = standIns({ rpc: postgrest(d), adsb: () => ({ body: { ac: aircraft } }) })
    const response = await makeHandler({ config: settings(), fetch: fake.fetch, now: () => Date.now(), log: () => {} })(calls.at(-1))
    return { fake, status: response.status, body: await response.json() }
  }

  const live = (d, key) => asAnon(d, 'select public.partner_live($1::text) as r', [key]).then((rows) => rows[0].r)

  test('the check’s call carries the password claim wants, and a fix reaches the partner’s device', async (t) => {
    const { d, pilot } = await watching(t)
    const first = await runOnce(d, [parked()])
    assert.deepEqual([first.status, first.body], [200, { flights: 1, requests: 1, fixes: 1, outcome: 'ok' }])
    assert.equal(first.fake.asked()[0].url, `${ADSB_URL}UPS207`)
    const [atGate] = (await live(d, pilot.key)).flights
    assert.deepEqual([atGate.leg_id, atGate.state, atGate.fix.on_ground, atGate.trail_count], ['leg-1', 'ground', true, 0])

    const second = await runOnce(d, [flying()])
    assert.equal(second.body.fixes, 1)
    const [inAir] = (await live(d, pilot.key)).flights
    assert.deepEqual([inAir.state, inAir.fix.registration, inAir.fix.altitude_ft, inAir.trail_count], ['airborne', 'N370UP', 38000, 1])
    assert.deepEqual(inAir.trail[0].slice(1), [39.365876, -85.678162, 38000])
  })

  test('it follows the flight to its landing, after which the check calls it no more', async (t) => {
    const { d, pilot } = await watching(t)
    await runOnce(d, [flying()])
    // Seen this instant: a position older than the fix the flight has would be left alone.
    await runOnce(d, [parked({ lat: 50.87, lon: 7.14, seen_pos: 0 })])
    const [landed] = (await live(d, pilot.key)).flights
    assert.equal(landed.state, 'landed')
    assert.ok(Math.abs(landed.landed_at - Date.now()) < 10_000)
    const before = (await queued(d)).length
    await asAdmin(d, 'select private.flight_live_tick()')
    assert.equal((await queued(d)).length, before)
  })

  test('a 429 from adsb.lol pauses the check', async (t) => {
    const { d } = await watching(t)
    await asAdmin(d, 'select private.flight_live_tick()')
    const [call] = await queued(d)
    const fake = standIns({ rpc: postgrest(d), adsb: () => ({ status: 429, body: {} }) })
    const response = await makeHandler({ config: settings(), fetch: fake.fetch, now: () => Date.now(), log: () => {} })(call)
    assert.deepEqual(await response.json(), { flights: 1, requests: 1, fixes: 0, outcome: 'limited' })
    await asAdmin(d, 'select private.flight_live_tick()')
    assert.equal((await queued(d)).length, 1)
  })

  test('a call with the wrong password is refused by the real claim', async (t) => {
    const { d } = await watching(t)
    await asAdmin(d, 'select private.flight_live_tick()')
    const fake = standIns({ rpc: postgrest(d) })
    const request = new Request('https://cloud.test/functions/v1/flight-live', { method: 'POST', headers: { 'x-flight-live-secret': 'wrong' }, body: '{}' })
    const response = await makeHandler({ config: settings(), fetch: fake.fetch, now: () => Date.now(), log: () => {} })(request)
    assert.equal(response.status, 401)
    assert.deepEqual(fake.asked(), [])
  })
})
```

- [ ] **Step 2: Run them, and see them pass**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && node --no-maglev --test flight_live_function.test.js 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail" && shasum -a 256 flight_live_function.test.js ../functions/flight-live/index.ts
```

Expected: `ℹ tests 37`, `ℹ pass 37`, `ℹ fail 0`, then:

```
97870a81a2a208707f3913a43132f9ef71b63f17306368aad67df363fce0e869  flight_live_function.test.js
daa241bcbe4876bfa79cf3b715c483d9ea5d812860f9ef1706eeb475ccb7165a  ../functions/flight-live/index.ts
```

As in Task 5, a different sum with passing tests is a difference in spacing: note it and go on.

- [ ] **Step 3: Check the function's types**

Node strips the types without checking them. The Crewluve website has TypeScript installed. Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && ~/Dev/"Crewluve Website"/node_modules/.bin/tsc --noEmit --strict --noUnusedLocals --noUnusedParameters --target es2022 --lib es2022,dom --skipLibCheck ../functions/flight-live/index.ts && echo types-ok
```

Expected: `types-ok`, with nothing before it.

- [ ] **Step 4: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/tests/flight_live_function.test.js && git commit -m "test(cloud): flight-live against the real claim and report: from the check's call to the fix a partner's device reads"
```

---

### Task 10: The contract and the tests' README

**Files:**
- Modify: `supabase/partner-api.md`
- Modify: `supabase/tests/README.md`

- [ ] **Step 1: Make the edits**

Each edit replaces text that appears once.

In `supabase/partner-api.md`, replace:

```markdown
- **The pushes' sender:** the Edge Function `partner-push`, `functions/partner-push/index.ts`. Its tests are in `tests/` too. Its alert pushes follow `docs/superpowers/specs/2026-10-23-partner-alert-pushes-design.md` in the same repo as the design.
```

with:

```markdown
- **The pushes' sender:** the Edge Function `partner-push`, `functions/partner-push/index.ts`. Its tests are in `tests/` too. Its alert pushes follow `docs/superpowers/specs/2026-10-23-partner-alert-pushes-design.md` in the same repo as the design.
- **The live plane's finder:** the Edge Function `flight-live`, `functions/flight-live/index.ts`, with `migrations/20261114120000_partner_links_flight_live.sql` and its airports in `migrations/20261114120100_flight_live_airports.sql`. Its design is §10 of `docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md` in the Crewluv repo.
```

In `supabase/partner-api.md`, replace:

```markdown
- **Forget the device key only when a call that takes just `p_key` answers `sharing_ended`.** Those calls are `partner_view`, `partner_handoff_create` and `partner_set_push`. Then show "Sharing has ended".
```

with:

```markdown
- **Forget the device key only when a call made with just the device's key answers `sharing_ended`.** Those calls are `partner_view`, `partner_live`, `partner_handoff_create` and `partner_set_push`. Then show "Sharing has ended".
```

In `supabase/partner-api.md`, replace:

```markdown
- **The one exception to answers:** a `p_since` that isn't a timestamp comes back as HTTP 400.
```

with:

```markdown
- **The two exceptions to answers:** a `p_since` that isn't a timestamp, and a `p_after` that isn't a whole number, come back as HTTP 400.
```

In `supabase/partner-api.md`, replace:

```markdown
| `partner_leave` | `p_key` | `{"ok": true}` |
```

with:

```markdown
| `partner_leave` | `p_key` | `{"ok": true}` |
| `partner_live` | `p_key`, `p_after` (optional: the last answer's `cursor`, sent back exactly as received) | `{"now", "cursor", "flights"}`: the pilot's flights with live data. See "The live plane". |
```

In `supabase/partner-api.md`, replace:

```markdown
## The summary JSON (`p_status`)
```

with:

````markdown
## The live plane

Where adsb.lol can see a pilot's flight, CrewLu Cloud keeps its real position and the path it flew, and `partner_live` hands them to that pilot's partners:

```
{"now": <ms>, "cursor": <integer>,
 "flights": [{"leg_id", "callsign", "state",
   "fix": {"lat", "lon", "altitude_ft", "ground_speed_kt", "track_deg", "on_ground",
           "registration", "type_code", "seen_at"} | null,
   "landed_at": <ms> | null,
   "trail": [[<ms>, <lat>, <lon>, <ft>], ...],
   "trail_count": <integer>}]}
```

- **Times are milliseconds since 1970,** unlike the summary's seconds. `now` is CrewLu Cloud's clock: measure a fix's age against it, not against the device's.
- **`flights`** has one entry for each flight leg in the pilot's summary that CrewLu Cloud is watching, or watched in the last 16 days. `leg_id` is that leg's `id` in the summary's `tripLegs`. A leg with no entry has no live data: show the schedule.
- **`state`:** `waiting` (never seen), `ground` (on the ground: at the departure airport, or somewhere else after a diversion), `airborne`, or `landed` (seen on the ground at the arrival airport, at `landed_at`).
- **`fix`** is the last position seen, or null before the first. `altitude_ft` is null on the ground. `ground_speed_kt`, `track_deg`, `registration` and `type_code` are null when adsb.lol didn't send them.
- **`trail`** is the path flown, oldest first, with a point about every 2 minutes while the flight is seen in the air. Each point is `[time, latitude, longitude, altitude in feet]`.
  - Without `p_after` it's every point. With the last answer's `cursor` it's only the points since.
  - Keep the points you have and add the new ones. If you then hold a different number than `trail_count`, ask again without `p_after`.
- **When to call it:** every 30 seconds while the screen is in front and a flight's window is open, and once each time the screen comes to the front. A window runs from 30 minutes before a flight's effective departure to its landing, or to 2 hours after its effective arrival. Never in the background.
- **It doesn't count as the device being seen.** `partner_view` does that.
- **The switch.** CrewLu Cloud watches flights for nobody (`off`), for listed pilots (`listed`) or for everyone (`all`). It's set in the SQL editor with `select private.flight_live_switch('listed', array['<the pilot's account id>']::uuid[]);`. While it's off, or the pilot isn't listed, `flights` is empty.
- **Credit adsb.lol** wherever a flight with live data shows: its data is under the ODbL.

## The summary JSON (`p_status`)
````

In `supabase/partner-api.md`, replace:

```markdown
curl -s -X POST "$URL/rest/v1/rpc/partner_set_push" -H "apikey: $KEY" -H "Content-Type: application/json" -d "{\"p_key\":\"$ZEROS\",\"p_token\":\"$ZEROS\",\"p_env\":\"production\",\"p_alerts\":true}"
```

with:

```markdown
curl -s -X POST "$URL/rest/v1/rpc/partner_set_push" -H "apikey: $KEY" -H "Content-Type: application/json" -d "{\"p_key\":\"$ZEROS\",\"p_token\":\"$ZEROS\",\"p_env\":\"production\",\"p_alerts\":true}"
curl -s -X POST "$URL/rest/v1/rpc/partner_live" -H "apikey: $KEY" -H "Content-Type: application/json" -d "{\"p_key\":\"$ZEROS\"}"
```

In `supabase/partner-api.md`, replace:

```markdown
9. `{"error": "sharing_ended"}`: so does Crewluve 1.3's, with it.
```

with:

```markdown
9. `{"error": "sharing_ended"}`: so does Crewluve 1.3's, with it.
10. `{"error": "sharing_ended"}`: `partner_live` is there, and knows a key that isn't a device's.
```

In `supabase/partner-api.md`, replace:

```markdown
**Undo the pushes first.** First the alert pushes,
```

with:

```markdown
**Undo the live plane before the pushes.** Its undo is in the header of `migrations/20261114120000_partner_links_flight_live.sql`; then delete `flight-live` in the dashboard. Its check reads its password with the push service's Vault helper, and its tables in `private` stop this undo while they're there.

**Then undo the pushes.** First the alert pushes,
```

In `supabase/tests/README.md`, replace:

```markdown
- the 2026-10-15 search_path fix (`20261015230000_function_search_path_and_signup_trigger_grant.sql`)
```

with:

```markdown
- the live plane (`20261114120000_partner_links_flight_live.sql`), in `flight_live.test.js`: which flights are watched, the 30-second check, claim and report, `partner_live`, the daily delete, and a second run and the undo;
- its airports (`20261114120100_flight_live_airports.sql`), in `flight_live_airports.test.js`: the seed, a second run and its undo, and that the file is what `helpers/airports_seed.js` makes from the Crewluve website's `airports.json`;
- flight-live, the Edge Function that finds pilots' flights on adsb.lol (`../functions/flight-live/index.ts`), in `flight_live_function.test.js`: run under Node with stand-ins for adsb.lol, on records of its real answers, then against the real claim and report;
- the 2026-10-15 search_path fix (`20261015230000_function_search_path_and_signup_trigger_grant.sql`)
```

In `supabase/tests/README.md`, replace:

```markdown
313 tests run in about a minute, each test file in its own process.
```

with:

```markdown
396 tests run in a little over a minute, each test file in its own process.
```

In `supabase/tests/README.md`, replace:

```markdown
- **`helpers/seed.js`** writes partner-links rows directly, for tests that need them without going through the RPCs.
```

with:

```markdown
- **`helpers/seed.js`** writes partner-links rows directly, for tests that need them without going through the RPCs.
- **`helpers/airports_seed.js`** makes the live plane's airports file from the Crewluve website's `airports.json`: `npm run airports-seed`. The tests of the live plane put in the few airports they fly between themselves, so only `flight_live_airports.test.js` loads all 9,056.
```

In `supabase/tests/README.md`, replace:

```markdown
- **pg_cron and pg_net.** The shim only records what they're given.
```

with:

```markdown
- **flight-live's types.** As partner-push's, with `../functions/flight-live/index.ts` in the file's place.
- **adsb.lol.** No test calls it. flight-live's tests use records of its answers, and a real flight is followed after the setup.
- **pg_cron and pg_net.** The shim only records what they're given.
```

- [ ] **Step 2: Run every test**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && npm test 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected, after a little over a minute: `ℹ tests 396`, `ℹ pass 396`, `ℹ fail 0`. That's the 313 from Task 0 and 83 new ones, the number the README now gives.

- [ ] **Step 3: Commit, with Todd's OK**

```bash
cd ~/Dev/Duty-flight-live && git add supabase/partner-api.md supabase/tests/README.md && git commit -m "docs(cloud): partner_live in the partner door's contract, and the live plane's tests in the tests' README"
```

---

### Task 11: Review

**Files:** whatever the review changes.

- [ ] **Step 1: Ask for a review**

Dispatch `superpowers:code-reviewer` with `model: "sonnet"`. Give it the spec's §10, §13, §14 and §16.2, this plan, and the branch's diff:

```bash
git -C ~/Dev/Duty-flight-live diff feature/supabase-account-backend...feature/flight-live -- supabase ':!supabase/migrations/20261114120100_flight_live_airports.sql'
```

Ask it to look hardest at:
- whether a partner can ever be answered a flight that isn't in their own pilot's summary;
- whether anything but `flight-live` can call claim or report, and whether a log line can hold a device key or the password;
- the match's rules against the spec's §10.4, case by case;
- what two runs that overlap can do to a flight's row and its trail;
- SQL that could raise on a summary's odd leg, and so stop the check for everyone.

- [ ] **Step 2: Weigh what it finds**

Use `superpowers:receiving-code-review`. For each finding, check it against the code before changing anything. Fix what's real, with a test that fails first. Tell Todd what was found, what was changed, and what was left and why.

- [ ] **Step 3: Run every test, and commit with Todd's OK**

Run:

```bash
cd ~/Dev/Duty-flight-live/supabase/tests && npm test 2>&1 | grep "^ℹ tests\|^ℹ pass\|^ℹ fail"
```

Expected: `ℹ fail 0`. Commit the changes with a message that says what the review changed. If a test was added, put the new count in `supabase/tests/README.md`.

---

### Task 12: Todd's setup

**Files:** none. CrewLu Cloud changes here, by Todd's hands, one step at a time (spec §17, steps 1 and 2). Claude changes nothing on CrewLu Cloud. With Todd's yes, Claude may read what the setup made.

- [ ] **Step 1: Ask before going live**

Ask Todd one question: set it up now? After the scripts, the check runs every 30 seconds, but with the switch off it does nothing: no flight is watched, adsb.lol is never asked, and `partner_live` answers no flights. If not now, stop here.

- [ ] **Step 2: `flight-live` in Supabase**

Claude puts the function's file on the clipboard. Run it with the sandbox off: from inside it, `pbcopy` doesn't reach Todd's clipboard.

```bash
pbcopy < ~/Dev/Duty-flight-live/supabase/functions/flight-live/index.ts && echo copied
```

Expected: `copied`.

Then send Todd these steps:

1. Open supabase.com/dashboard and the CrewLu Cloud project.
2. In the left sidebar, click **Edge Functions**.
3. Click **Deploy a new function**, then **Via Editor**.
4. Click in the editor, select all the example code (⌘A) and paste (⌘V).
5. Name the function `flight-live`, exactly: the address the SQL script stores ends with that name.
6. Click **Deploy function**, and wait for the success message.
7. On flight-live's page, open its settings (the **Details** tab), turn off the switch for JWT verification (labeled like **Verify JWT**), and save. The check sends no sign-in: the password guards flight-live instead.
8. Under **Edge Functions**, open **Secrets**, and check that `SUPABASE_URL` and `SUPABASE_SECRET_KEYS` are in the list Supabase supplies. flight-live needs no secret of its own.

- [ ] **Step 3: The live plane's script**

Claude puts the script on the clipboard, again with the sandbox off:

```bash
pbcopy < ~/Dev/Duty-flight-live/supabase/migrations/20261114120000_partner_links_flight_live.sql && echo copied
```

Expected: `copied`.

Then send Todd these steps:

1. In the left sidebar, click **SQL Editor**, and start a new query.
2. Paste (⌘V) and click **Run**.
3. If it warns about a destructive operation, that's the two clean-up jobs' `delete`s, which run once a day: confirm it.
4. Expected: the result of the script's last `select`, a `schedule` column holding a number (the last clean-up job's). If it says `relation "airports" already exists`, the script ran before: stop and ask.

- [ ] **Step 4: The airports' script**

Claude puts it on the clipboard, with the sandbox off:

```bash
pbcopy < ~/Dev/Duty-flight-live/supabase/migrations/20261114120100_flight_live_airports.sql && echo copied
```

Expected: `copied`.

Then send Todd these steps:

1. Start a new query in the **SQL Editor**, paste (⌘V) and click **Run**. It's 231 KB, so the paste takes a moment.
2. Expected: `Success. No rows returned`.
3. In a new query, run `select count(*) from private.airports;`. Expected: `9056`.

- [ ] **Step 5: Check it's there, and off**

Send Todd this, for a new query:

```sql
select mode, pilots, failures, paused_until from private.flight_live_state;
select jobname, schedule, active from cron.job where jobname like 'flight-live%' order by jobname;
```

Expected: one row, `off` with an empty list, `0` and nothing; then three jobs, `flight-live` at `30 seconds`, `flight-live-cleanup` at `23 4 * * *` and `flight-live-history` at `19 4 * * *`, all active.

Then Claude runs `partner-api.md`'s new check, which only reads:

```bash
URL=https://corxvurxpnrzekbxdgye.supabase.co
KEY=$(sed -n "s/^export const SUPABASE_PUBLISHABLE_KEY = '\(.*\)'$/\1/p" ~/Dev/"Crewluve Website"/src/cloud.ts)
ZEROS=0000000000000000000000000000000000000000000000000000000000000000
curl -s -X POST "$URL/rest/v1/rpc/partner_live" -H "apikey: $KEY" -H "Content-Type: application/json" -d "{\"p_key\":\"$ZEROS\"}"
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$URL/rest/v1/rpc/flight_live_claim" -H "apikey: $KEY" -H "Content-Type: application/json" -d '{"p_secret":"x"}'
```

Expected: `{"error": "sharing_ended"}`, then `401`: the publishable key can't call claim.

Ask Todd to open **Advisors** → **Security** in the dashboard. Expected: two new findings, both about `public.partner_live`: a security definer function that `anon` can call, and that `authenticated` can. They're on purpose, as for the other partner RPCs. Any other new finding: stop and ask.

- [ ] **Step 6: Turn it on for Todd's account**

This is the first step that reaches adsb.lol. It needs Todd's account to have a partner whose device was seen in the last 30 days, and a flight within its window: 30 minutes before its departure to 2 hours after its arrival.

Send Todd this, for a new query, with his CrewLu sign-in email in place of `EMAIL`:

```sql
select private.flight_live_switch('listed', array(select id from auth.users where email = 'EMAIL'));
select mode, cardinality(pilots) as pilots from private.flight_live_state;
```

Expected: `listed`, then `listed` and `1`. If it's `0`, the email matched no account: the switch is on for nobody, so nothing is asked. Fix the email and run it again.

- [ ] **Step 7: Watch a flight**

While one of Todd's flights is in its window, send Todd this:

```sql
select callsign, departure, arrival, state, hex, seen_at, fix ->> 'altitude_ft' as feet,
       (select count(*) from private.live_flight_points p where p.flight_id = f.id) as points
  from private.live_flights f order by id desc limit 5;
select status_code, content::text, timed_out, error_msg from net._http_response order by id desc limit 5;
```

Expected:
- a row for the flight, `waiting` until adsb.lol sees it, then `ground` or `airborne` with a `seen_at` under a minute old, and `points` growing by one about every 2 minutes in the air;
- pg_net's last answers with `200` and `{"flights":1,"requests":1,"fixes":…,"outcome":"ok"}`.

If the answers show `"outcome":"failed"` or `"limited"`, or a status other than 200, stop and ask. flight-live's **Logs** tab in the dashboard has a line for each run.

- [ ] **Step 8: Write down what happened**

Add a section "## Setup, as it went" to the end of this plan, with the date, each step's result, and anything that differed. Then tick the boxes.

The switch stays on `listed` until the app (plan 3B) and the website (plan 3C) have followed a real flight. Turning it to `all` is the spec's last rollout step, on Todd's OK:

```sql
select private.flight_live_switch('all');
```

To turn everything off at any time:

```sql
select private.flight_live_switch('off');
```

---

### Task 13: Record, and hand over

**Files:**
- Modify: this plan
- Modify: `~/Dev/Crewluv/docs/superpowers/specs/2026-11-14-crewluve-moving-map-stage3-live-design.md`, only if something changed

- [ ] **Step 1: Record what changed**

Add "## Changes made during execution" to the end of this plan: the review's changes, and anything a step did differently. If any of it changes what the spec's §10 says, change the spec to match, and say so in the list.

- [ ] **Step 2: Note what plans 3B and 3C need**

Add "## For the app and the website" to the end of this plan:
- the final `partner_live` answer, copied from `supabase/partner-api.md`;
- the switch's state on CrewLu Cloud;
- one real answer from `partner_live` for a flight in the air, with the device key left out, to record as the demo scenes' and the shared cases' starting point. Todd's own Crewluve can get it once plan 3B's door call exists, so this may wait for 3B.

- [ ] **Step 3: Commit, with Todd's OK**

Commit this plan and any spec change in `~/Dev/Crewluv`, on `feature/trip-map-live`. In CrewLu, ask Todd how he wants `feature/flight-live` merged: use `superpowers:finishing-a-development-branch`.

---

## Self-review

- **Spec coverage.**
  - §10.1's parts: Tasks 1 to 6. §10.2's legs, callsign, window and whose flights: Tasks 1 and 2. §10.3's run: Tasks 2, 3 and 8. §10.4's match: Task 7. §10.5's fix, trail and 16 days: Tasks 3 and 5. §10.6's `partner_live`: Task 4. §10.7's switch and failures: Tasks 2, 3 and 8. §10.8's setup: Task 12.
  - §13, the server's part: the same flight number on back-to-back legs, a return, a diversion and an aircraft swap (Task 7); a new scheduled departure (Task 2); adsb.lol down or slow (Tasks 3 and 8).
  - §14: partners see only their own pilot's legs (Task 4); claim and report need the service role and the password (Task 3, and the guards); adsb.lol sees callsigns only, and the log holds no key (Task 8).
  - §16.2: every test it lists is in Tasks 1 to 9.
  - §17: steps 1 and 2 are Task 12. Steps 3 to 5 belong to plans 3B and 3C.
- **Not covered here, on purpose:** the app and the website (plans 3B and 3C); PostgREST's own answer to a `p_after` that isn't a number, which the tests can't reach and `partner-api.md` documents; Supabase's Deno and adsb.lol themselves, which Task 12 proves on a real flight.
- **Names** are the same in every task: `flight_live_claim(p_secret)`, `flight_live_report(p_secret, p_flights, p_outcome)`, `partner_live(p_key, p_after)`, `private.flight_live_tick()`, `private.flight_live_switch(p_mode, p_pilots)`, and the header `x-flight-live-secret`. A fix's fields are the same in the function's `Fix`, the report's SQL and `partner_live`'s answer.

## Left for later

- **A flight whose airline flies under another's callsign,** as a regional does for a major, isn't found. The table in `private.flight_callsign` can gain operators as they turn up.
- **A pilot removed from the list while a flight is open** is still asked about until that flight's window closes.
- **If adsb.lol starts needing a key,** `flight-live` gains a secret and a header in `ask`.
- **The check reads every allowed pilot's summary every 30 seconds.** That's fine at today's numbers. If it grows slow, read only the summaries that changed since the last run, and keep each pilot's upcoming flights in a table.

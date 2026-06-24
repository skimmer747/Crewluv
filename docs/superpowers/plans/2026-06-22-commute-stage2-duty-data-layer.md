# Commute — Stage 2: Duty `Commute` Data Layer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add a `Commute` SwiftData model to the Duty app and wire it into **both** sync backends (CloudKit mirror + Supabase), plus a remembered-drive-duration store — so the pilot's base↔home commute drives persist and sync across their devices on whichever backend they're on. No status emission, no UI, no partner-beacon work yet (those are Stage 3).

**Architecture:** `Commute` is a standalone root `@Model` (no relationships), mirroring `Jumpseat`'s shape and `Syncable` conformance. It joins `SyncSchema.allModels` (the CloudKit-mirror registry) and gets a `CommuteRow` DTO + `tableOrder`/pull/push registration in `SupabaseSyncEngine` (the Supabase registry). `SyncChangeTracker` already flags any `Syncable` on edit generically — no change needed. A `CommuteRouteStore` remembers per-route drive duration (default 2 h) in the app-group `SharedUserDefaults`.

**Tech Stack:** Swift 5.9+, SwiftData, Supabase-swift (PostgREST), XCTest. iOS 17+.

**Spec:** `Crewluv` repo → `docs/superpowers/specs/2026-06-22-commuter-home-base-commutes-design.md` (§6.1–6.3, §12 items 1,2,4,5,11,12,13). Pairs with Stage 1 (Crewluv `.drive` rendering, already implemented).

---

## Working context & safety (READ FIRST)

- **Repo/branch:** Work in `/Users/toddanderson/Dev/Duty`, **directly on the existing branch `feature/supabase-account-backend`** (the user's decision — it is the active iOS dev trunk where the Supabase sync layer lives; `main` lacks it). **Do NOT create a new branch. Do NOT push.** Local commits only; the user merges to `main`.
- **Untouched WIP:** the working tree has the user's in-flight `M Duty/Utils/SyncGuidanceCopy.swift` and untracked `DutyTests/SyncGuidanceCopyTests.swift`. **Never `git add` these.** Each task stages only its own named files.
- **Client-only scope:** This stage writes Swift + a migration **file**. It does **NOT** apply any migration to the live Supabase DB and does **NOT** deploy CloudKit production schema. Those are Stage 4, gated on explicit user authorization. (Consequence: the Duty build must not ship until Stage 4 provisions both backends — that's the release gate.)
- **No compile-coupling:** `Commute` is a new model type, not a new case in any exhaustive `enum`/`switch`, so each task builds green on its own.

**Commands** (run from `/Users/toddanderson/Dev/Duty`):
- Build: `xcodebuild -project Duty.xcodeproj -scheme Duty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
- Test (all): `xcodebuild test -project Duty.xcodeproj -scheme Duty -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
- Test (one class): append `-only-testing:DutyTests/CommuteDataLayerTests`
- These are slow (minutes). Run them; don't skip.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `Duty/Models/Commute.swift` | The `Commute` `@Model` + `CommuteDirection` + `Syncable` | **New** |
| `Duty/Utils/CommuteRouteStore.swift` | Remembered drive duration per route (default 2 h) | **New** |
| `Duty/Utils/Sync/SyncSchema.swift` | CloudKit-mirror model registry | Add `Commute.self` |
| `Duty/Utils/Sync/DTO/CommuteRow.swift` | Supabase wire DTO for `Commute` | **New** |
| `Duty/Utils/Sync/SupabaseSyncEngine.swift` | Supabase registry (tableOrder + pull + push) | Register `commutes` |
| `supabase/migrations/20260622170000_commutes_table.sql` | `commutes` table + RLS + trigger + index | **New (file only, not applied)** |
| `DutyTests/CommuteDataLayerTests.swift` | Unit tests | **New** |
| `DutyTests/SyncSchemaTests.swift`, `DutyTests/SyncableConformanceTests.swift` | Existing schema/conformance tests | Update for `Commute` if they assert a count/list |

---

## Task 0: Pre-flight — confirm branch + green baseline

**Files:** none

- [ ] **Step 1: Confirm branch & untouched WIP**

Run: `cd /Users/toddanderson/Dev/Duty && git branch --show-current && git status --short`
Expected: on `feature/supabase-account-backend`; the only pre-existing changes are `M Duty/Utils/SyncGuidanceCopy.swift` and `?? DutyTests/SyncGuidanceCopyTests.swift` (leave both alone) plus `?? .superpowers/`.

- [ ] **Step 2: Establish a green baseline BEFORE any change**

Run the full test command. Expected: `** TEST SUCCEEDED **`. If the baseline is already red, STOP and report — do not layer commute work onto a broken tree.

---

## Task 1: `Commute` model + `CommuteDirection` + `Syncable`

**Files:**
- Create: `Duty/Models/Commute.swift`
- Create: `DutyTests/CommuteDataLayerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `DutyTests/CommuteDataLayerTests.swift`:

```swift
import XCTest
import SwiftData
@testable import Duty

final class CommuteDataLayerTests: XCTestCase {

    // MARK: - Model + Syncable

    func test_commute_defaults() {
        let c = Commute()
        XCTAssertEqual(c.driveDurationSeconds, 7200)          // 2h default
        XCTAssertEqual(c.hiddenFromTimeline, false)
        XCTAssertNil(c.deletedAt)
        XCTAssertFalse(c.needsPush)
        XCTAssertEqual(c.direction, .toHome)                  // default direction
    }

    func test_commute_directionRawRoundTrips() {
        let c = Commute()
        c.directionRaw = CommuteDirection.toWork.rawValue
        XCTAssertEqual(c.direction, .toWork)
    }

    func test_commute_syncableConformance() {
        let c = Commute()
        XCTAssertEqual(c.syncID, c.id)                        // id-having
        let stamp = Date(timeIntervalSince1970: 1_000_000)
        c.syncLastModified = stamp
        XCTAssertEqual(c.lastModifiedAt, stamp)               // mapped onto lastModifiedAt
        XCTAssertEqual(c.syncLastModified, stamp)
    }
}
```

- [ ] **Step 2: Run it — expect FAIL** (compile error: no `Commute`). Run the `-only-testing:DutyTests/CommuteDataLayerTests` command.

- [ ] **Step 3: Create `Duty/Models/Commute.swift`** — mirrors `Jumpseat`'s shape exactly (all stored properties defaulted, **no `@Attribute(.unique)`** because CloudKit mirroring forbids it; `directionRaw` String for CloudKit compatibility; `Syncable` via an extension mapping `syncLastModified` onto `lastModifiedAt`):

```swift
//
//  Commute.swift
//  Duty
//
//  A base<->home ground commute drive for pilots whose home airport differs
//  from their base. Standalone root model (no relationships), mirroring the
//  Jumpseat shape and Syncable conformance. Synced on BOTH backends:
//   • CloudKit mirror — via SyncSchema.allModels.
//   • Supabase — via CommuteRow (DTO) + SupabaseSyncEngine registration.
//

import Foundation
import SwiftData

/// Direction of a commute drive. Stored as `directionRaw` (String) for CloudKit
/// compatibility — read/write via the `direction` computed property.
enum CommuteDirection: String, Codable, Sendable {
    case toHome   // base -> home (after a trip lands at base)
    case toWork   // home -> base (before a trip starts at base)
}

/// @Model marks this as a SwiftData persistent object with CloudKit sync.
@Model
final class Commute {
    /// Stable id (= Postgres primary key / syncID). NO @Attribute(.unique):
    /// CloudKit mirroring rejects unique constraints.
    var id: String = UUID().uuidString

    /// IATA origin — base for `.toHome`, home for `.toWork`.
    var fromAirport: String = ""
    /// IATA destination — home for `.toHome`, base for `.toWork`.
    var toAirport: String = ""

    /// Direction stored as raw String (see `direction`).
    var directionRaw: String = CommuteDirection.toHome.rawValue

    /// Departure (UTC).
    var departureTimeZulu: Date = Date()
    /// Arrival (UTC). Invariant: always > departureTimeZulu.
    var arrivalTimeZulu: Date = Date()
    /// Remembered drive length in seconds (default 2h). arrival = departure + this.
    var driveDurationSeconds: Double = 7200

    /// The trip this commute brackets (denormalized soft ref, NOT an FK). Used by
    /// the Stage-3 cleanup service to remove orphaned commutes.
    var sourceTripId: String? = nil

    /// Hidden from the partner timeline (Stage-3 HiddenEventsManager reads this).
    var hiddenFromTimeline: Bool = false

    var createdAt: Date = Date()

    // MARK: - Syncable metadata (mirror Jumpseat)
    /// Local edit timestamp; `syncLastModified` maps onto this.
    var lastModifiedAt: Date = Date()
    /// Soft-delete tombstone. nil = live.
    var deletedAt: Date? = nil
    /// Local dirty flag (set by SyncChangeTracker on edit; cleared on push).
    var needsPush: Bool = false

    /// Type-safe accessor for the stored `directionRaw`.
    var direction: CommuteDirection {
        get { CommuteDirection(rawValue: directionRaw) ?? .toHome }
        set { directionRaw = newValue.rawValue }
    }

    init() {}
}

// MARK: - Syncable

extension Commute: Syncable {
    var syncID: String { id }
    var syncLastModified: Date {
        get { lastModifiedAt }
        set { lastModifiedAt = newValue }
    }
    // deletedAt, needsPush satisfied by stored properties.
    // materializeSyncID(): default no-op (id-having model) — inherited.
}
```

- [ ] **Step 4: Run the `-only-testing:DutyTests/CommuteDataLayerTests` command — expect PASS (3 tests).**

- [ ] **Step 5: Commit (local only):**

```bash
git add Duty/Models/Commute.swift DutyTests/CommuteDataLayerTests.swift
git commit -m "feat(duty): add Commute model with Syncable conformance"
```

> If `DutyTests` is NOT a `PBXFileSystemSynchronizedRootGroup`, the new test file must be added to the `DutyTests` target — check with `grep -c PBXFileSystemSynchronizedRootGroup Duty.xcodeproj/project.pbxproj` and whether the `DutyTests` group uses it. If you must touch `project.pbxproj`, stage ONLY the file-reference hunks for the new test file — never unrelated hunks.

---

## Task 2: `CommuteRouteStore` (default 2 h, remembered per route)

**Files:**
- Create: `Duty/Utils/CommuteRouteStore.swift`
- Test: `DutyTests/CommuteDataLayerTests.swift` (append)

- [ ] **Step 1: Append failing tests**

```swift
    // MARK: - CommuteRouteStore

    func test_routeStore_defaultsToTwoHours_whenUnset() {
        let from = "ZZA", to = "ZZB"   // unlikely-used codes to avoid collisions
        CommuteRouteStore.clear(from: from, to: to)
        XCTAssertEqual(CommuteRouteStore.duration(from: from, to: to), 7200, accuracy: 0.5)
    }

    func test_routeStore_remembersAdjustedDuration() {
        let from = "ZZC", to = "ZZD"
        CommuteRouteStore.setDuration(5400, from: from, to: to)   // 1.5h
        XCTAssertEqual(CommuteRouteStore.duration(from: from, to: to), 5400, accuracy: 0.5)
        XCTAssertEqual(CommuteRouteStore.duration(from: "zzc", to: "zzd"), 5400, accuracy: 0.5) // case-insensitive
        CommuteRouteStore.clear(from: from, to: to)
    }
```

- [ ] **Step 2: Run it — expect FAIL** (no `CommuteRouteStore`).

- [ ] **Step 3: Create `Duty/Utils/CommuteRouteStore.swift`** (uses the app-group `SharedUserDefaults`, per spec §6.2):

```swift
//
//  CommuteRouteStore.swift
//  Duty
//
//  Remembers the drive duration per (from,to) route so the next commute on that
//  route pre-fills the user's adjusted time instead of the 2h default. Stored in
//  the app-group SharedUserDefaults (watch/widget parity). No MapKit in v1 (a
//  future version may seed the first estimate — spec §17).
//

import Foundation

enum CommuteRouteStore {
    /// Default drive length when a route has no remembered value (2 hours).
    static let defaultDuration: TimeInterval = 2 * 60 * 60

    private static let keyPrefix = "commuteRoutes.duration."

    private static func key(from: String, to: String) -> String {
        "\(keyPrefix)\(from.uppercased())-\(to.uppercased())"
    }

    /// Remembered duration for the route, or `defaultDuration` if none stored.
    static func duration(from: String, to: String) -> TimeInterval {
        let stored = SharedUserDefaults.shared.double(forKey: key(from: from, to: to))
        return stored > 0 ? stored : defaultDuration
    }

    /// Remember an adjusted duration for the route.
    static func setDuration(_ seconds: TimeInterval, from: String, to: String) {
        SharedUserDefaults.shared.set(seconds, forKey: key(from: from, to: to))
    }

    /// Forget a route's remembered duration (next read falls back to default).
    static func clear(from: String, to: String) {
        SharedUserDefaults.shared.removeObject(forKey: key(from: from, to: to))
    }
}
```

- [ ] **Step 4: Run the `-only-testing:DutyTests/CommuteDataLayerTests` command — expect PASS (all 5).**

- [ ] **Step 5: Commit:**

```bash
git add Duty/Utils/CommuteRouteStore.swift DutyTests/CommuteDataLayerTests.swift
git commit -m "feat(duty): CommuteRouteStore with 2h default, remembered per route"
```

---

## Task 3: Register `Commute` in the CloudKit-mirror schema

**Files:**
- Modify: `Duty/Utils/Sync/SyncSchema.swift`
- Modify (if they assert a count/list): `DutyTests/SyncSchemaTests.swift`, `DutyTests/SyncableConformanceTests.swift`
- Test: `DutyTests/CommuteDataLayerTests.swift` (append)

> Adding `Commute` to `allModels` makes it a CloudKit-mirrored type (`CD_Commute`). Local migration is lightweight & non-blocking (all fields optional/defaulted, no `@Attribute(.unique)`). The CloudKit **production** schema deploy is Stage 4 (gated).

- [ ] **Step 1: Append a container-builds-with-Commute test**

```swift
    // MARK: - Schema registration

    @MainActor
    func test_commute_isInSyncSchema_andContainerInsertsFetches() throws {
        XCTAssertTrue(SyncSchema.allModels.contains { $0 == Commute.self },
                      "Commute must be registered in SyncSchema.allModels")
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let c = Commute()
        c.fromAirport = "SDF"; c.toAirport = "MCO"
        ctx.insert(c)
        try ctx.save()
        let fetched = try ctx.fetch(FetchDescriptor<Commute>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.toAirport, "MCO")
    }
```

- [ ] **Step 2: Run it — expect FAIL** (Commute not in allModels).

- [ ] **Step 3: Add `Commute.self` to `SyncSchema.allModels`** — append at the end of the array in `Duty/Utils/Sync/SyncSchema.swift`:

```swift
        PersistentCircadianState.self, ManualEvent.self, EventCategory.self,
        JumpseatChange.self, FatigueScorePoint.self,
        Commute.self,
    ]
```

- [ ] **Step 4: Update existing schema/conformance tests if needed**

Read `DutyTests/SyncSchemaTests.swift` and `DutyTests/SyncableConformanceTests.swift`. If either asserts an exact model **count** (e.g. `allModels.count == 22`) or enumerates an explicit list, update it to include `Commute` (count → +1; add `Commute.self` to any expected list; if `SyncableConformanceTests` verifies each synced model conforms to `Syncable`, ensure `Commute` is covered). If they derive from `allModels` dynamically, no change needed. Make the minimal edit and note exactly what you changed.

- [ ] **Step 5: Run the full test suite** (these touch the container/schema broadly):
Run the full test command. Expect `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit:**

```bash
git add Duty/Utils/Sync/SyncSchema.swift DutyTests/CommuteDataLayerTests.swift
# add SyncSchemaTests.swift / SyncableConformanceTests.swift ONLY if you edited them
git commit -m "feat(duty): register Commute in SyncSchema (CloudKit mirror)"
```

---

## Task 4: `CommuteRow` DTO + Supabase engine registration

**Files:**
- Create: `Duty/Utils/Sync/DTO/CommuteRow.swift`
- Modify: `Duty/Utils/Sync/SupabaseSyncEngine.swift` (`tableOrder`, `pullAllTables`, `pushAllTables`)
- Test: `DutyTests/CommuteDataLayerTests.swift` (append)

- [ ] **Step 1: Append a round-trip test**

```swift
    // MARK: - CommuteRow wire round-trip

    @MainActor
    func test_commuteRow_roundTripsThroughWire() throws {
        let container = try ModelContainer(
            for: Schema(SyncSchema.allModels),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext

        let dep = Date(timeIntervalSince1970: 1_700_000_000)
        let arr = dep.addingTimeInterval(7200)
        let src = Commute()
        src.fromAirport = "SDF"; src.toAirport = "MCO"
        src.direction = .toHome
        src.departureTimeZulu = dep; src.arrivalTimeZulu = arr
        src.driveDurationSeconds = 7200
        src.sourceTripId = "trip-123"
        src.hiddenFromTimeline = true

        let row = CommuteRow(from: src, userID: "user-1")
        XCTAssertEqual(row.id, src.id)
        XCTAssertEqual(row.user_id, "user-1")
        XCTAssertEqual(row.direction, "toHome")
        XCTAssertNil(row.updated_at)   // server-set; never authored on push

        let dst = Commute()
        ctx.insert(dst)
        row.apply(to: dst, in: ctx)
        XCTAssertEqual(dst.id, src.id)
        XCTAssertEqual(dst.fromAirport, "SDF")
        XCTAssertEqual(dst.toAirport, "MCO")
        XCTAssertEqual(dst.direction, .toHome)
        XCTAssertEqual(dst.departureTimeZulu.timeIntervalSince1970, dep.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(dst.arrivalTimeZulu.timeIntervalSince1970, arr.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(dst.driveDurationSeconds, 7200, accuracy: 0.5)
        XCTAssertEqual(dst.sourceTripId, "trip-123")
        XCTAssertEqual(dst.hiddenFromTimeline, true)
    }
```

- [ ] **Step 2: Run it — expect FAIL** (no `CommuteRow`).

- [ ] **Step 3: Create `Duty/Utils/Sync/DTO/CommuteRow.swift`** (mirror `JumpseatRow` conventions exactly: snake_case == columns, `id`/`user_id` non-optional, every domain field optional, dates via `SyncISO`, `updated_at = nil` on push; apply() coalesces non-optional model fields, assigns optional ones directly):

```swift
//
//  CommuteRow.swift
//  Duty
//
//  Wire DTO for Commute. Table: public.commutes (root — no parent FK).
//  Mirrors the JumpseatRow pattern (see that file / TripRow for the template).
//

import Foundation
import SwiftData

struct CommuteRow: SyncableRow {
    let id: String
    let user_id: String

    let from_airport: String?
    let to_airport: String?
    let direction: String?
    let departure_time_zulu: String?
    let arrival_time_zulu: String?
    let drive_duration_seconds: Double?
    let source_trip_id: String?
    let hidden_from_timeline: Bool?
    let created_at: String?

    let deleted_at: String?
    let updated_at: String?

    init(from c: Commute, userID: String) {
        id = c.syncID
        user_id = userID
        from_airport = c.fromAirport
        to_airport = c.toAirport
        direction = c.directionRaw
        departure_time_zulu = SyncISO.string(from: c.departureTimeZulu)
        arrival_time_zulu = SyncISO.string(from: c.arrivalTimeZulu)
        drive_duration_seconds = c.driveDurationSeconds
        source_trip_id = c.sourceTripId
        hidden_from_timeline = c.hiddenFromTimeline
        created_at = SyncISO.string(from: c.createdAt)
        deleted_at = SyncISO.string(from: c.deletedAt)
        updated_at = nil   // server-set; never authored on push
    }

    func apply(to c: Commute, in context: ModelContext) {
        c.id = id   // identity (id-having model)
        // optional model fields → assign directly (remote wins, incl. nil)
        c.sourceTripId = source_trip_id
        c.deletedAt = SyncISO.date(from: deleted_at)
        // non-optional model fields → coalesce (a NULL keeps the local value)
        c.fromAirport = from_airport ?? c.fromAirport
        c.toAirport = to_airport ?? c.toAirport
        c.directionRaw = direction ?? c.directionRaw
        c.departureTimeZulu = SyncISO.date(from: departure_time_zulu) ?? c.departureTimeZulu
        c.arrivalTimeZulu = SyncISO.date(from: arrival_time_zulu) ?? c.arrivalTimeZulu
        c.driveDurationSeconds = drive_duration_seconds ?? c.driveDurationSeconds
        c.hiddenFromTimeline = hidden_from_timeline ?? c.hiddenFromTimeline
        c.createdAt = SyncISO.date(from: created_at) ?? c.createdAt
    }
}
```

- [ ] **Step 4: Register `commutes` in `SupabaseSyncEngine.swift`** — three edits, all mirroring the `jumpseats` (root, no children) lines:

(a) `tableOrder` (currently `"jumpseats", "jumpseat_riders",`) — add `"commutes",`:

```swift
        "jumpseats", "jumpseat_riders",
        "commutes",
        "event_categories", "manual_events", "hot_standbys", "crew_members",
```

(b) In `pullAllTables`, right after the `jumpseat_riders` `pullTable(...)` block, add:

```swift
        // commutes (root — base<->home drive; no parent FK)
        try await pullTable(CommuteRow.self, "commutes",
            make: { Commute() }, wire: { _, _ in true },
            transport: transport, uid: uid, cursorDate: cursorDate, cursorStr: cursorStr, into: pc)
```

(c) In `pushAllTables`, right after the `jumpseat_riders` `pushTable(...)` call, add:

```swift
        try await pushTable(CommuteRow.self, "commutes", guardOK: { _ in true },
                            transport: transport, uid: uid, into: pc)
```

- [ ] **Step 5: Run the `-only-testing:DutyTests/CommuteDataLayerTests` command — expect PASS — then a full build** (`xcodebuild ... build`) to confirm the engine edits compile. Expect `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit:**

```bash
git add Duty/Utils/Sync/DTO/CommuteRow.swift Duty/Utils/Sync/SupabaseSyncEngine.swift DutyTests/CommuteDataLayerTests.swift
git commit -m "feat(duty): CommuteRow DTO + register commutes in SupabaseSyncEngine"
```

---

## Task 5: Supabase `commutes` migration file (NOT applied)

**Files:**
- Create: `supabase/migrations/20260622170000_commutes_table.sql`

> This commits the schema as a migration file mirroring the phase-2 envelope (it reuses the existing `public.touch_updated_at()` trigger function and the same RLS/trigger/index shape the phase-2 DO-loop applies to every table). It is **idempotent & re-runnable** but is **NOT applied to the live database in this stage** — application is Stage 4, gated on explicit user authorization (the user manages `supabase db push` / SQL Editor). No build/test impact.

- [ ] **Step 1: Create `supabase/migrations/20260622170000_commutes_table.sql`:**

```sql
-- ============================================================================
-- Commute (base<->home ground commute drive) — sync table.
-- Mirrors the Phase 2F envelope (id text PK, user_id uuid, all domain columns
-- nullable, deleted_at, server-set updated_at). Idempotent & re-runnable.
-- NOT a structural FK: source_trip_id is a denormalized soft ref.
-- ============================================================================

create table if not exists public.commutes (
  id                      text primary key,                       -- = Commute.id (syncID)
  user_id                 uuid not null references auth.users(id) on delete cascade,
  from_airport            text,                                   -- base for toHome, home for toWork
  to_airport              text,                                   -- home for toHome, base for toWork
  direction               text,                                   -- toHome|toWork
  departure_time_zulu     timestamptz,
  arrival_time_zulu       timestamptz,
  drive_duration_seconds  double precision,
  source_trip_id          text,                                   -- denormalized soft ref (NOT an FK)
  hidden_from_timeline    boolean,
  created_at              timestamptz,
  deleted_at              timestamptz,
  updated_at              timestamptz not null default now()      -- SERVER-set by trigger; clients never send it
);

-- RLS owner policy + server-authoritative updated_at trigger + pull-cursor index.
-- (touch_updated_at() is defined by the phase-2 migration; reused here.)
alter table public.commutes enable row level security;
drop policy if exists commutes_owner on public.commutes;
create policy commutes_owner on public.commutes for all
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop trigger if exists commutes_touch on public.commutes;
create trigger commutes_touch before insert or update on public.commutes
  for each row execute function public.touch_updated_at();

create index if not exists commutes_user_updated on public.commutes (user_id, updated_at);
```

- [ ] **Step 2: Commit (file only — do NOT apply):**

```bash
git add supabase/migrations/20260622170000_commutes_table.sql
git commit -m "feat(duty): commutes Supabase migration (file only; apply in Stage 4)"
```

---

## Task 6: Full suite + final review

**Files:** none

- [ ] **Step 1: Full Duty test suite**
Run the full test command. Expect `** TEST SUCCEEDED **`, including `CommuteDataLayerTests` (6 tests) and no regressions vs the Task 0 baseline.

- [ ] **Step 2: Confirm scope hygiene**
Run: `git status --short` and `git log --oneline -6`. Confirm: the user's `SyncGuidanceCopy` WIP is still unstaged/uncommitted; the 5 commute commits are present; nothing pushed.

---

## Self-Review (completed)

- **Spec coverage:** §6.1 `Commute` model (T1), §6.2 `CommuteRouteStore` (T2), §6.3/§12-item-4 CloudKit-mirror registry (T3), §12-items-11/12 `CommuteRow` + Supabase engine registration (T4), §12-item-13 / §6.3 the `commutes` table migration (T5). ✓
- **`Syncable` correctness:** mirrors `Jumpseat` exactly (`syncID == id`, `syncLastModified`↔`lastModifiedAt`, stored `deletedAt`/`needsPush`, default no-op `materializeSyncID`); `SyncChangeTracker.markChanged` is generic over `any Syncable`, so commutes auto-flag on edit — verified, no tracker change. ✓
- **CloudKit safety:** all properties defaulted, **no `@Attribute(.unique)`**, no relationships → lightweight, non-blocking local migration. ✓
- **Dual-registry:** registered in BOTH `SyncSchema.allModels` (T3) and `SupabaseSyncEngine` tableOrder/pull/push (T4) — the spec's explicit must-do-both. ✓
- **No production mutation:** migration is a committed file only; no live DB apply, no CloudKit prod deploy — both gated to Stage 4. ✓
- **Scope hygiene:** every commit stages only its named files; the user's `SyncGuidanceCopy` WIP and `project.pbxproj` are never swept in. ✓

---

## Stage gate before release (carry to Stage 4)
The Duty build must NOT ship until: (a) the `commutes` table migration is applied to **production** Supabase, and (b) `CD_Commute` is deployed to **production** CloudKit. Until then a shipped build would error on commute push for live users. Stage 3 (status emission + suggestion engine + UI) can proceed on the branch regardless, since nothing emits/creates a `Commute` until that UI exists.

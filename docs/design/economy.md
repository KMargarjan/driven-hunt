# Design: economy (coins per drive, a balance that survives the session)

Task 170. Written to `reviews/task-170/BRIEF.md`, which is the Director's and Karen's input and
overrides anything older. Read that brief and `docs/research/2026-10-13-coins-persistence.md` first:
section 4 of the note is the pattern and is **not re-opened here**. What this file adds is the owner
ruling, the module layout, the interface symbol by symbol, the lifecycle, the wire delta, the seams
and the hazards.

This is a **new system document** and a **delta** to `docs/design/drive.md` (§7, §9.1, §9.2, §11.3,
§12) and to `GAME_DESIGN.md`'s *System owners* table. Section 12 lists every delta so nothing is
discovered at merge time.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Pay coins for a drive, off the board `Match.Score` already produces.** `points × COINS_PER_POINT`,
   plus `PARTICIPATION`, plus `FIRST_PLACE` to the top hunter **and** the top beater. Karen,
   2026-10-11: *"Scoring - yes get money when shoot boar not much but get money and first place ofc
   more legendary more ect"*.
2. **Pay once per drive, at its end.** The single door is `Phase.enterScoring`
   (`src/server/Match/Phase.luau`, `enterScoring`, whose own comment says *"The clock and the
   beaters' crossing both come through `enterScoring`, so one emit here is one signal per drive
   end"*).
3. **Keep the balance between sessions**, through ProfileStore 1.0.3 and nothing of our own.
4. **Floor the balance at 0** while allowing a drive's own coin line to be negative (two piglets and
   a safety violation is −30 points, −50 coins).
5. **Show two rankings** — hunters and beaters — each with its own first place, off one unchanged
   `Score.leaderboard`. Karen, 2026-10-12.
6. **Make a piglet cost points**: `Match.CONFIG.POINTS.KIND.cub` goes `2 → -10`, and `QUARRY_NOTE`
   changes in the same commit, which is what that field's own comment in
   `src/server/Match/init.luau` already promised.
7. **Put the balance and this drive's earnings on screen**, on the existing snapshot rows.

### 1.2 Must not

1. **Must not be a second scoring system.** No coin is awarded anywhere a point is not. The only
   input to the conversion is `{ Score.Row }`.
2. **Must not add a client → server remote.** `src/client/Match/init.luau`'s header records that
   *"this whole system has no client -> server remote at all, so its inbound exploit surface is
   zero"*. Spending re-opens that deliberately, in its own task.
3. **Must not write a DataStore key from Studio**, with or without *Enable Studio Access to API
   Services*, and **must not require ProfileStore in Studio at all** — the require itself performs a
   real `SetAsync` (note §2.1 item 2).
4. **Must not yield in a caller's thread.** The pay-out runs inside `Match`'s `dispatch`, before
   `applyEffects`; a yield there applies the drive's effects late. Every DataStore call is inside a
   thread this system spawns itself. The one exception is `Economy.closeAll`, called only from
   `BindToClose`, which must yield (§5, row 4).
5. **Must not call a DataStore per coin, per kill or per frame** (note §2.4, and Roblox's own
   best-practices page: *"Update the local copy instead of sending a data store request for every
   change"*).
6. **Must not give a bot a row, and must not add a predicate to prevent it.** `docs/design/bots.md`
   §2: *"no row in `Score`, no DataStore"*; the mechanism is structural.
7. **Must not hold a `Player`.** Keyed by `userId` only, the discipline
   `src/server/Match/Score.luau`'s header already states.
8. **Must not own a clock.** No `Heartbeat`, no `task.delay`, no auto-save of our own: the auto-save
   period is ProfileStore's default and we call no `SetConstant` (note §3).
9. **Must not replicate a rule number.** `COINS_PER_POINT`, `PARTICIPATION` and `FIRST_PLACE` stay on
   the server in `Economy.CONFIG`, never in `Drive.CONFIG` —
   `tests/client/match_client.spec.luau` already asserts that no points number is on the wire.

### 1.3 Out of scope, named so the design is not blamed for omitting them

Spending, a shop and the inbound remote it needs; trophies; a cross-server `OrderedDataStore`
leaderboard; Robux; the legendary animal (`POINTS.KIND.legendary = 25` is a price with no animal, and
it pays 50 coins the day one exists, with nothing here to change). Note §6.

---

## 2. The owner (brief §2.1), and the pure/impure split

### 2.1 Ruling: a new system, `ServerScriptService.Economy`, at `src/server/Economy/`

**Not** `Match.Coins`. Three pieces of evidence, each from this repo:

1. **Nothing under `src/server/Match/` connects anything.** That is written down as the reason
   `Bots` is its own owner: `GAME_DESIGN.md` row *Bots that fill the drive* — *"It has its own 5 Hz
   clock (`STEP_HZ`), which is why it is not a module under `src/server/Match/`: nothing under there
   connects anything."* The economy connects three things (`Players.PlayerAdded`,
   `Players.PlayerRemoving`, and one `Profile.OnSessionEnd` per player) and spawns threads that
   yield. `Match`'s own sub-modules are `Phase`, `Roster`, `Score` (pure), `Markers` (read-only),
   `Penalty` (pure), `Body` and `Scene` (writers of Instances, no connections of their own).
2. **A profile outlives a drive and outlives `Match.stop()`.** `Match.stop` (`src/server/Match/init.luau`,
   `Match.stop`) clears `config`, `world`, `remotes`, `markerSet` and every connection; a session
   lock that died with it would be dropped every time a spec stopped the drive, and a session lock
   dropped without `EndSession` is exactly the loss ProfileStore exists to prevent.
3. **`src/server/Match/init.luau` is 2,478 lines** and is on `TWO_PLAYER_PATHS`. Persistence inside
   it buys nothing and makes every later economy change a two-player change.

The composition roots already carry the shape: `MatchBoot` wires four owners that require none of
each other (`Boar`, `Weapon`, `Bots`, `HitLog`). Economy is the fifth, wired the same way.

### 2.2 Files, and which half each one is

| File | Studio | Pure? | Owns |
|---|---|---|---|
| `src/server/Economy/init.luau` | `ServerScriptService.Economy` | **impure** | the balances, the sessions, the per-drive earnings, the connections, the flag read, the one `print` |
| `src/server/Economy/Coins.luau` | `…Economy.Coins` | **PURE** | what a drive is worth to whom |
| `src/server/Economy/Store.luau` | `…Economy.Store` | mixed, stated below | the narrow store interface, its two implementations, the profile template and the missing-key rule |
| `src/shared/Drive/Rank.luau` | `ReplicatedStorage.Drive.Rank` | **PURE** | the partition by team and "who is first" — **one implementation, two readers** (§4.3) |

**`Coins` is pure to exactly the standard `Match.Score` is held to**, quoted from that file's header:
*"no service, no clock, no Player, no Instance, no Random; `config` is a parameter, not a lookup"*.
It returns a frozen table and never mutates its input.

**`Store` is split inside itself and the split is named**: `Store.TEMPLATE`, `Store.read`,
`Store.keyFor` are **pure**; `Store.memory()` touches only in-process tables (no service, no
yield except by contract); `Store.live()` is the **only place in the repository that requires
ProfileStore** and the only thing that can reach `DataStoreService`. It requires the library
**inside the function body**, not at the top of the file, because the require itself writes a key
(note §2.1 item 2).

**`Economy` (init.luau) holds every piece of state**, and there is exactly one of each:

| Table | Fact |
|---|---|
| `balances: { [number]: number }` | the in-memory balance, the one the wire reports |
| `sessions: { [number]: true }` | whose profile is open. A pay-out without one is refused |
| `earned: { [number]: number }` | what the LAST paid drive was worth to each row. Replaced whole by each pay-out, so nothing lingers |
| `lastPaidDrive: number` | the double-pay guard (§11 hazard 1) |

Nothing else in the repository may write any of them. `Economy.balances()` and `Economy.earned()`
return frozen copies.

---

## 3. The flag (the Architect's ruling, not in the brief)

**`COINS`, born OFF**, one row in `src/shared/Flags/init.luau`:

```
COINS = { default = false, owner = "ServerScriptService.Economy",
          born = "2026-10-13 task 170", expires = "2026-11-03",
          why = "A drive pays coins and the balance is saved between sessions. OFF is exactly the "
             .. "game before task 170: nothing is loaded, nothing is saved, no coin is awarded and "
             .. "the score panel is the one-table board of task 159." }
```

Why, in CLAUDE.md's own terms: *"A new feel-critical path is born OFF"*. Three of the four numbers
here are Karen's to retune after one drive, and — the stronger reason — **this is the first thing in
the project that can write to a player's permanent record.** With the row at `false` a live server
opens no session and writes no key, so the flag is also the kill switch and the rollback. 11 flags
against `Flags.MAX_FLAGS = 12`.

**One read, at the boundary, passed inward** — the only permitted shape:

* `Economy.CONFIG.ENABLED = Flags.isOn("COINS")`, in `src/server/Economy/init.luau` beside the rest
  of `Economy.CONFIG`, exactly as `Match.CONFIG.TIE_UNTIL_DRIVE_END` and
  `Match.CONFIG.BOTS.ENABLED` are read.
* `Economy.start(world)` resolves it as
  `local enabled = if world.enabled ~= nil then world.enabled else config.ENABLED`, which is the one
  line that makes **both states reachable by parameter while the flag sits at one of them** — the
  rule a flagged path must satisfy or its two states cannot be tested.
* **Nothing else reads the flag.** `Match` does not; the client does not.

**OFF is today's game bit for bit, and the mechanism is the absence of data, not a second
renderer.** With the flag off `Economy.start` connects nothing, loads nothing and returns a view
whose `payDrive` is a no-op and whose `balances`/`earned` are empty, so `Match.snapshot()`'s row
fields `coins` and `earned` are **absent** (§6), and the Hud draws the coins column only for a row
that carries the field — a data question, not a flag question, and the same shape
`scoreRowText` already uses for `row.team` and `row.left`. The client reads no flag for this.

---

## 4. The interface, symbol by symbol

Types are Luau annotations: `luau-lsp analyze` is not in CI, so they are documentation plus editor
checking, not a gate (the wording `docs/design/drive.md` §9 already uses).

### 4.1 `src/server/Economy/Coins.luau` — PURE

```luau
export type Row = Score.Row            -- userId, name, team, points, kills, …, left
export type Breakdown = {
    coins: { [number]: number },       -- userId -> coins for THIS drive (may be negative)
    firstHunter: number?,              -- userId, or nil for a tie at the top / an all-noughts list
    firstBeater: number?,
    skippedLeft: number,
    skippedNotAPlayer: number,
}

Coins.forDrive(rows: { Row }, config): Breakdown
Coins.forRow(points: number, isFirst: boolean, config): number
Coins.credit(balance: number, delta: number, config): number
```

* **`Coins.forDrive`** is the whole conversion and the only caller of the other two. `rows` is
  `Score.leaderboard(board)` — already sorted, already frozen. It
  1. partitions with `Rank.splitByTeam(rows)` (§4.3),
  2. asks `Rank.firstPlaceRank` **once per ranking**, never per row,
  3. calls `Coins.forRow` for every eligible row,
  4. returns a **frozen** `Breakdown` and never mutates `rows`.
* **What it refuses, and counts rather than hides:**
  * a row with `left == true` → **not paid**, `skippedLeft += 1`. `PARTICIPATION` is, in the note's
    own words, *"for turning up **and finishing** the drive"*, and the player is not on the server:
    crediting him means writing a profile whose session this server has already ended (§5 row 3).
    One predicate, one line, and Karen's to overrule (§13 item 2).
  * a row whose `userId` is not a positive integer → **not paid**,
    `skippedNotAPlayer += 1`. Bots cannot reach here (`Match.pushCreditable` and
    `Phase.participantIds` already refuse a non-numeric id), so this is a tripwire with a number on
    it, not a filter the game depends on.
  * `row.team == nil` → paid points and participation, **no first-place bonus**, and listed under
    `others` by the partition. A row can have no team: `watchPlayer` calls
    `Score.join(board, …, state.assignment[userId])` and `Phase.step`'s `join` branch assigns a team
    only in `Assigning`/`Running`.
* **`Coins.forRow(points, isFirst, config)`** = `points * COINS_PER_POINT + PARTICIPATION +
  (if isFirst then FIRST_PLACE else 0)`. No clamp here: **the drive's line may be negative** and the
  clamp belongs to the balance.
* **`Coins.credit(balance, delta, config)`** = `math.max(config.FLOOR, balance + delta)`. The one
  place the floor exists. It returns the new balance and says nothing about whether it clamped; the
  owner compares and counts (`coinsClamped`).

### 4.2 `src/server/Economy/Store.luau`

The narrow interface is the note's, name for name (note §4 item 3: *"`load(userId) -> balance`,
`save(userId, balance)`, `release(userId)`"*), plus the two things a session lock forces.

```luau
export type Store = {
    kind: string,                                   -- "memory" | "live"
    load: (userId: number) -> number?,              -- YIELDS. nil = no session (lock refused or failed)
    save: (userId: number, balance: number) -> boolean,   -- writes the LOCAL copy. No network call
    release: (userId: number) -> boolean,           -- ends the session, which saves
    releaseAll: () -> number,                       -- YIELDS. shutdown only; how many it ended
    setOnLost: (handler: (userId: number) -> ()) -> (),   -- one setter, one handler
}

Store.TEMPLATE: { schema: number, coins: number, coinsEarnedTotal: number, drivesPaid: number }
Store.keyFor(userId: number): string                -- PURE: "player_<userId>"
Store.read(data: any): { [string]: any }            -- PURE: the missing-key rule (§9)
Store.memory(options: { seed: { [number]: number }?, refuse: { [number]: boolean }? }?): Store
Store.live(storeName: string): Store                -- the ONLY require of ProfileStore
```

* **`load` returns `nil` for two different failures and the owner treats them the same**: a refused
  session lock (`StartSessionAsync` *"can return nil when another remote Roblox server attempts to
  start a session for the same profile at the same time"*) and a thrown error inside a `pcall`.
  Both mean **no session**, so **no earning and no saving** for that player until a retry succeeds.
  The owner counts them apart (`loadsRefused`, `loadsFailed`).
* **`save` is not a network call.** For `Store.live` it is `profile.Data.coins = balance` plus the
  derived fields; ProfileStore's own auto-save and its `EndSession` do the writing. That is Roblox's
  own advice and ProfileStore's whole purpose, so there is no retry loop, no backoff and no
  `UpdateAsync` of ours anywhere (note §3).
* **`setOnLost`** is how `Profile.OnSessionEnd` reaches the owner. The note quotes the rule it
  enforces: *"after the `Profile.OnSessionEnd` signal is fired, no further changes to `Profile.Data`
  should be made"*. On that callback the owner drops `sessions[userId]` and `balances[userId]`
  immediately, so the next pay-out refuses him instead of writing into a dead table.
* **`Store.memory` is the double AND the Studio path**, which is why its two options are not a
  production test seam: `seed` gives a userId a starting balance and `refuse` makes `load` answer
  `nil`, so a spec can drive the refused-lock branch without a second server. It is never reachable
  on a live server (§7).
* **`Store.live(storeName)`** contains the only `require(ServerStorage.ServerPackages.ProfileStore)`
  in the repository, **inside the function body**, and `ProfileStore.New(storeName, Store.TEMPLATE)`
  is called once. `ProfileStore.Mock` is **not used** — reaching it still means requiring the
  library in Studio (brief §1 item 3).

### 4.3 `src/shared/Drive/Rank.luau` — PURE, and the reason it exists

```luau
Rank.splitByTeam(rows): ({ Row }, { Row }, { Row })   -- hunters (Shooters), beaters (Drivers), others
Rank.firstPlaceRank(rows): number?                     -- 1, or nil
```

**Why it moves out of the Hud.** `Hud.firstPlaceRank` (`src/client/Hud/init.luau`) is today the one
implementation of *"a tie at the top is not a first place"*, after ioquake3's `RANK_TIED_FLAG`. From
this task **the server pays a bonus off the same question** and the client draws a badge off it. Two
implementations of one rule is this project's named failure mode: `docs/PROJECT_CONTEXT.md`, *"Most
of the worst bugs were two correct pieces of code disagreeing"*. So there is one implementation, in
the one module both sides already require (`Match` requires `Drive`; `Hud` requires `Drive`).

**It leaks nothing.** `ReplicatedStorage.Drive`'s header states the rule — *"THE RULE NUMBERS ARE
NOT HERE"* — and `Rank` holds **no number at all**: it is a predicate over rows the client is
already sent. It is the client's own function of today, moved to where the server can see it.

**`Hud.firstPlaceRank` is retired, not kept as an alias** (an alias is two names for one rule). Its
body and its comment — which carry the ioquake3 citation and the round-1 finding about *"ahead of
the second row, not above zero"* — move verbatim into `Rank.firstPlaceRank`, and the old function is
archived under `backups/` with a note (rule 7).

**`splitByTeam` is total**: every row lands in exactly one of the three lists, order preserved from
`Score.leaderboard`, so neither ranking re-sorts and the drive's total order still decides inside
each. A third list is not decoration: it is what makes "no row can be lost" provable in one
assertion (`#hunters + #beaters + #others == #rows`).

### 4.4 `src/server/Economy/init.luau` — the owner

```luau
Economy.CONFIG                        -- frozen; §8 is the table, field for field
Economy.Coins / Economy.Store         -- exported for specs ONLY, as Match.Score and Boar.Brain are

Economy.start(injected: World?)       -- asserts it is not started twice. NOTHING HAPPENS ON REQUIRE
Economy.stop()                        -- disconnects everything it connected; releases every session
Economy.view(): View                  -- the read-only view the drive is handed

Economy.payDrive(driveNumber: number, rows: { Score.Row }): Receipt   -- NEVER YIELDS
Economy.onDriveStart()                -- level-triggered retry; spawns its own thread
Economy.load(player: Player)          -- spawns its own thread; idempotent per userId
Economy.release(userId: number)       -- spawns its own thread; idempotent
Economy.closeAll()                    -- BindToClose ONLY. YIELDS, bounded

Economy.balanceOf(userId: number): number?     -- nil = no session, which is NOT zero
Economy.earnedOf(userId: number): number?
Economy.balances(): { [number]: number }       -- a frozen copy
Economy.earned(): { [number]: number }         -- a frozen copy
Economy.storeKind(): string                    -- "memory" | "live" | "injected" | "off"
Economy.storeKindFor(isStudio: boolean): string -- PURE, exported: "memory" | "live"
Economy.stats()

export type World = { store: Store?, players: Players?, enabled: boolean? }
export type View  = {
    payDrive: (driveNumber: number, rows: { Score.Row }) -> (),
    balances: () -> { [number]: number },
    earned:   () -> { [number]: number },
}
export type Receipt = {
    driveNumber: number, paid: number, coins: number,
    skippedLeft: number, skippedNoProfile: number, skippedNotAPlayer: number,
    clamped: number, duplicate: boolean,
}
```

* **`Economy.view()` has no `start`, no `stop`, no store and no setter** — the
  `ForestTest.readOnlyBoars` / `Bots.view()` idiom, named in `MatchBoot`'s own comments. It is what
  the drive is given, so the drive cannot open a session, cannot write a balance and cannot see the
  library.
* **`Economy.storeKindFor(isStudio)` is pure and exported for one reason**, and it is
  `Match.quickTestEnabled(flagOn, isStudio)`'s reason verbatim (that function's own comment: *"Pure
  and exported so the guard itself is testable … which is the assertion that says a live server can
  never run this however the attribute got there"*). Inside Studio `RunService:IsStudio()` is always
  true and no harness run can make it false, so the **live** branch is provable only as a pure
  predicate: `storeKindFor(false) == "live"`, `storeKindFor(true) == "memory"`.
* **`payDrive` never yields** and touches only the four tables in §2.2 — it runs inside `Match`'s
  `dispatch` before `applyEffects`, and `applyEffects` is where `placePlayers` and the forced
  broadcast happen.
* **`Economy.balanceOf` answers `nil`, not `0`, for a player with no session.** `0` would be a
  statement that he has no coins; `nil` is the truth, and the Hud draws it as `--` (§6, §7).

### 4.5 `ServerScriptService.Match` — what changes (and what does not)

`Match` gains **no state, no table and no clock**. Three edits:

1. **`Match.CONFIG.POINTS.KIND.cub`: `2 → -10`**, and `Match.CONFIG.QUARRY_NOTE` changes in the same
   commit. `Match.quarryLines` already prints each kind with its price, so the start card reads
   `WILD BOAR, POINTS: male 10, female 6, cub -10` for free — which is the test that task 158 built
   that card correctly. The new note must state the rule as it now is, e.g.
   `"a piglet costs you - leave them"`. Karen's wording is hers to give (§13 item 5); the old value
   and sentence are archived under `backups/` with the rollback (rule 7).
2. **`world.economy`**, a fourth injected view beside `boars`, `weapon`, `bots`. Absent → this file
   before task 170, by every branch.
3. **One call in `dispatch`, and its POSITION IS THE DESIGN.** Immediately beside the existing
   `Assigning` edge block — *"BEFORE applyEffects, AND THAT IS THE WHOLE POINT (TASKS.md 32a(c))"* —
   add the mirror-image `Scoring` edge:

   ```
   if state.phase ~= before and state.phase == "Scoring" and world and world.economy then
       world.economy.payDrive(state.driveNumber, Score.leaderboard(board))
       snapshotCache = nil
   end
   ```

   **Why there and nowhere else.** `enterScoring` emits `{ kind = "broadcast", force = true }`, and
   `broadcast` builds the snapshot from `board`. Pay after `applyEffects` and the first — forced —
   snapshot of the results scene carries no earnings, and nothing forces another until the next
   drive's `enterAssigning`: Karen would read a results table with an empty coins column for up to
   `STATE_HEARTBEAT = 5` of the scene's 25 seconds. That is the identical defect this file already
   records as measured for the board itself (`dispatch`, TASKS.md 32a(c)). Paying on the edge, before
   the effects, makes the pay-out part of the same push.
   **It is also what makes one pay-out per drive structural**: the edge
   `state.phase ~= before and state.phase == "Scoring"` can fire at most once per `Scoring`, and
   `enterScoring` is the only door into `Scoring`.
   `Score.leaderboard(board)` is passed, **not `Match.snapshot()`**: building the snapshot here would
   cache a pre-pay-out copy, and the pure board is what the pure conversion wants.
4. **`Match.snapshot()`**: two row fields, §6.

No new `Match` effect kind, no `Phase` change, no `Match.CONFIG` block for the economy's own numbers
(they are `Economy.CONFIG`'s, on the server, unreplicated).

### 4.6 The composition roots

Identical lines in `src/server/MatchBoot.server.luau` and `src/server/ForestTestBoot.server.luau` —
Karen plays in the Forest Test, so it gets the economy too, and the forest's shorter drive
(`DRIVE_SECONDS = 300`) and `BOARS_PER_DRIVE = 0` change nothing here: participation and first place
still pay.

```
Economy.start()                               -- before Match.start: a player already on the server
                                              -- must have a session open before the first dispatch
Match.start({ …, economy = Economy.view() })
Match.PhaseChanged:Connect(function(_before, phase)
    if phase == "Assigning" then Economy.onDriveStart() end   -- the level-triggered retry
end)
game:BindToClose(Economy.closeAll)            -- the ONE BindToClose in the repository
```

**`BindToClose` is registered by the root and never by `Economy.start`.** `BindToClose` cannot be
disconnected ([DataModel:BindToClose](https://create.roblox.com/docs/reference/engine/classes/DataModel#BindToClose)),
and every spec starts and stops this owner; a registration inside `start` would leave one callback
per spec run bound for the rest of the session. `Economy.closeAll()` is safe to call when nothing was
ever started (it releases nothing and returns 0), which is what makes the root's unconditional
registration correct. Exactly one root runs per place: `MatchBoot` returns early when
`Map.EXPECTED_WORLD == "forest-test"`.

The `Match.PhaseChanged` connection is `HitLog`'s idiom in the same file
(`HitLog.openDrive`/`closeDrive`), so neither owner requires the other.

---

## 5. The lifecycle (brief §2.2): moment, owner, call, failure

| Moment | Who triggers | Who owns the state | Call | Failure behaviour |
|---|---|---|---|---|
| **join** | `Players.PlayerAdded`, connected by `Economy.start` (and `Economy.start` sweeps `GetPlayers()` once, as `Match.start` does) | `Economy` | `Economy.load(player)` → `task.spawn` → `Store.load(userId)` → `sessions[userId] = true`, `balances[userId] = Store.read(data).coins` | `nil` → **no session**: no row in `balances`, so the wire sends no `coins` for him, the Hud reads `--`, and he earns nothing. `loadsRefused`/`loadsFailed` += 1 and **one `warn` naming the userId**. Retried at the next drive start |
| **mid-drive join** | the same signal | — | the same call | A player who arrives mid-drive has his balance on screen as soon as the load returns and the next broadcast goes out (≤ `STATE_HEARTBEAT = 5 s`, and sooner on any event). No special case: `Match`'s `join` already forces a broadcast |
| **retry** | `Match.PhaseChanged` → `Assigning` → `Economy.onDriveStart()` | `Economy` | for every player in `players:GetPlayers()` with no `sessions` row, `Economy.load(player)` | Level-triggered and idempotent — the `Weapon.refreshArming` / `syncBots` discipline, because *"every edge-triggered grant in this repo has been measured missing one"* (`Match`'s `syncBots` comment). A transient Roblox outage costs one drive's coins, not the session's |
| **drive end** | `Match`'s `dispatch`, on the `Scoring` edge, before `applyEffects` | `Economy` | `view.payDrive(driveNumber, Score.leaderboard(board))` | A row with no session is **skipped and counted** (`skippedNoProfile`), never written. A repeated `driveNumber` is refused whole (`duplicate = true`) and nothing is written |
| **leave** | `Players.PlayerRemoving`, connected by `Economy.start` | `Economy` | `Economy.release(userId)` → `task.spawn` → `Store.release(userId)` (which saves) → drop `sessions`, `balances`, `earned` rows | Idempotent: a second release answers `false`. `Match.forget` is untouched and is not the trigger — it is `Match`'s own tear-down of *its* tables (`names`, `heldStill`, `tied`, `pushCredit`, `characterWatch`), and the two owners each clean up their own on the same engine signal |
| **session lost to another server** | `Profile.OnSessionEnd`, through `Store.setOnLost` | `Economy` | drop `sessions[userId]` and `balances[userId]` at once | He stops earning and his `coins` reads `--`. No write is ever attempted after `OnSessionEnd`, which is the library's own stated rule |
| **server shutdown** | `game:BindToClose(Economy.closeAll)`, registered by the composition root | `Economy` | `Store.releaseAll()` — `EndSession` for every open session | The one function here that **yields** (`BindToClose` is given time to finish) and the one that is bounded: it stops after `CONFIG.CLOSE_TIMEOUT_SECONDS` and `warn`s how many it could not end |
| **`Economy.stop()`** (specs only) | a spec | `Economy` | disconnect everything, `Store.releaseAll()`, clear all four tables, `lastPaidDrive = 0` | A spec that stops this owner must not leave a session open or a `lastPaidDrive` that refuses the next spec's drive 1 |

**May a player whose balance did not load still earn?** **No.** The three options were: earn and lose
it silently (a lie on screen), earn into a queue (a second store of the same fact, and a write for a
player who may never come back), or not earn, visibly. The third is the only one this repo's rules
permit — *"a number in the harness report, not a safety rule that silently never fires"*
(`Match.start`'s own warning idiom) — and the retry makes the window one drive, not a session.

---

## 6. The wire (brief §2.3)

**Both numbers are row fields on the existing `MatchSnapshot`. No new remote, no second channel, no
inbound anything.**

`src/shared/Drive/init.luau`, `ScoreRow`, gains exactly two optional fields:

```luau
export type ScoreRow = {
    userId: number, name: string, team: TeamName?,
    points: number, kills: number, assists: number, pushes: number,
    violations: number, left: boolean,
    -- TASK 170. Both ABSENT when the economy is off or this player has no profile: absent is
    -- "unknown", which is not the same fact as 0, and the Hud draws it as "--".
    coins: number?,     -- the BALANCE, after this drive's pay-out. On screen at all times
    earned: number?,    -- what THIS drive paid him. May be negative. The results table's "+N"
}
```

`Match.snapshot()` fills them from the injected view, two table reads per snapshot build:

```
local balances = if world and world.economy then world.economy.balances() else nil
local earned   = if world and world.economy then world.economy.earned()   else nil
… coins = balances and balances[row.userId], earned = earned and earned[row.userId] …
```

**The consequence, accepted and stated: every client learns every player's balance.** It is accepted
for three reasons. (1) The panel is a **shared table by design** — it already publishes everybody's
points, kills, assists, pushes and violations to everybody, and task 159 made it Karen's results
table. (2) A balance is a cosmetics currency, not a credential; nothing in §1.2 is weakened by
knowing it, and no rule number joins it. (3) The alternative — `FireClient` per player with his own
balance — is **a second wire carrying a fact the first wire already carries**, which doubles the
number of answers to "what is my balance" for the sake of hiding a number from the people standing
next to you at the results scene. If the Director wants it hidden, the cheap version is *draw* only
the local player's (the panel keeps `earned`, the bar keeps `coins`), with **no wire change at all** —
written down here so the decision stays reversible without a redesign.

`MatchEvent`/`FeedEntry` is **unchanged**: no coin line in the feed. A per-award coin entry would be
a second announcement of the points line that already exists.

---

## 7. The two rankings and the panel (brief §2.4)

`Hud.renderScore` stays **the one writer of the score panel**. The split is a **pure exported
function**, which is the repo's habit for this panel for a stated reason — *"Pure and exported … no
harness run ever reaches the `Scoring` phase"* — and the words live in `Drive.CONFIG`, which is where
*"every word this Hud draws is written down"*.

### 7.1 `Hud.scorePanelLines(snapshot, myUserId): { Line }` — PURE, exported

```luau
export type Line = { text: string, heading: boolean, mine: boolean }
```

It returns the panel's body, in order:

```
-- HUNTERS --
1  KAREN             2      16   +42
2  BOT-NAME          0       3   +16
-- BEATERS --
1  SECOND            0      12   +34
-- OTHERS --            (only when that list is non-empty)
```

* the rank restarts at 1 **within each ranking**, because that is what "two first places" means;
* `Rank.firstPlaceRank` is asked **once per ranking** (and never of `others`), and the row it names
  wears `Drive.CONFIG.SCORE_FIRST_BADGE`. A tie at the top of a ranking gets no badge **and no
  bonus** — one rule, one implementation, §4.3;
* `heading` lets the renderer dim a heading with `SCORE_HEADER_TRANSPARENCY`; `mine` lets it colour
  the local player's row with `SCORE_HIGHLIGHT_COLOR`. The renderer writes `.Text`, `.TextColor3`,
  `.TextTransparency` and `.Visible` and decides nothing;
* an `others` heading is emitted **only** when that list is non-empty — the rule
  `Match.quarryLines` already applies to its `POINTS` label: *"THE WORD ONLY WHEN THERE IS A NUMBER
  UNDER IT"*.

### 7.2 The row, and why the TEAM column goes

```
header:  "#  NAME             KILLS  POINTS   COINS"
row:     string.format("%-2d %-16s %5d %7d %7s%s%s", rank, name, kills, points, coinsText, badge, gone)
```

**The `TEAM` column is removed, and that is what pays for the coins column.** With a `-- HUNTERS --`
heading over the list, a `SHOOTER` on every row under it prints the same fact twice. The arithmetic,
because the panel is `Enum.Font.Code` at `SCORE_TEXT_SIZE = 16` (≈ 8 px per glyph) inside
`SCORE_PANEL_WIDTH - 32 = 448` px:

| | chars | px |
|---|---|---|
| today's row + badge + star | 42 + 5 + 2 = 49 | 392 |
| **this design's row** + badge + star | 41 + 5 + 2 = 48 | **384** |

So **`SCORE_PANEL_WIDTH` does not change** — which matters, because at 480 it is already wider than
the 400-px screen `tests/client/hud_clarity.spec.luau` asserts against, and widening it further would
make an existing problem worse for no gain.

`coinsText` is `"+42"` / `"-18"` / `Drive.CONFIG.SCORE_COINS_UNKNOWN` (`"--"`) when `row.earned` is
absent. It is **this drive's earnings**, not the balance: the brief asks for *"+N coins"* on the
results scene, and the balance has a better home (§7.4).

### 7.3 The row budget

`SCORE_ROWS_MAX`: **16 → 20**. Three headings plus `MAX_PLAYERS = 16` rows is 19, and 20 leaves one
spare. The panel's own height formula is unchanged (`64 + rows * rowHeight + 30`) and grows 16 → 20
rows = 534 px, inside the 800-px screen the clarity spec uses. `scorePanelLines` **truncates at
`SCORE_ROWS_MAX` by dropping trailing ROWS and never a heading**, and the arithmetic that makes that
unreachable is asserted on the server, where both numbers are visible:
`Drive.CONFIG.SCORE_ROWS_MAX >= Match.CONFIG.MAX_PLAYERS + 3`.

### 7.4 The balance on the HUD at all times

One more piece on the drive bar, from the local player's own row — the bar is already built from the
snapshot in `renderDrive`, and the local row is the only row it needs:

```luau
Hud.coinsText(snapshot, userId): string   -- PURE, exported: "COINS 1240", "COINS --", or ""
```

`""` when the snapshot carries no row for him at all (which is the whole of today's game with the
flag off), so `Hud.driveBarText()` is byte-identical to today in that state. It is appended after
the team badge, in every phase, because the brief asks for the balance *"at all times"*. Where it
sits is a feel question (§13 item 3); that it is one `table.insert` in `renderDrive` and one pure
formatter is what makes moving it free.

### 7.5 New words in `Drive.CONFIG` — layout and wording only

`SCORE_HUNTERS_HEADING = "-- HUNTERS --"`, `SCORE_BEATERS_HEADING = "-- BEATERS --"`,
`SCORE_OTHERS_HEADING = "-- OTHERS --"`, `SCORE_COINS_UNKNOWN = "--"`,
`SCORE_EARNED_FORMAT = "%+d"`, `SCORE_COINS_LABEL = "COINS"`, and `SCORE_ROWS_MAX = 20`.
**No economy number goes here** — `tests/client/match_client.spec.luau` already asserts that no
points or safety number is on the wire, and that assertion must be extended to `COINS_PER_POINT`,
`PARTICIPATION`, `FIRST_PLACE` and `FLOOR` by pattern.

**The headings use Karen's words, HUNTERS and BEATERS, not the team names.** `Hud.roleWord` already
maps `Shooters → HUNTER` and `Drivers → BEATER` in one place and the start card already speaks them;
the row's `TEAM` column — the only place the panel said `SHOOTER`/`DRIVER` — is gone. Which
vocabulary the *whole* Hud speaks is still Karen's open question (`TASKS.md` row 158a) and this
settles nothing beyond this panel.

---

## 8. `Economy.CONFIG`, field for field (brief §2.5 and the numeric targets)

Server-only, deep-frozen (`Drive.deepFreeze`, required not copied), **never replicated**.

| Field | Value | K? | Reads as |
|---|---|---|---|
| `ENABLED` | `Flags.isOn("COINS")` | | the one flag read, §3 |
| `COINS_PER_POINT` | `2` | K | *"not much but get money"*. A male boar is 10 points, so a boar is **20 coins** — a round number, and `POINTS.KIND` stays the one place the ratios live |
| `PARTICIPATION` | `10` | K | half a boar for turning up and finishing. The reason a beater whose animals nobody shot does not read a nought |
| `FIRST_PLACE` | `25` | K | 1.25 boars, **per ranking** — hunters and beaters each pay one. *"first place ofc more"* |
| `FLOOR` | `0` | K | a balance never goes below zero; a drive's own line may |
| `STORE_NAME` | `"DrivenHuntPlayer_v1"` | | §9 |
| `KEY_FORMAT` | `"player_%d"` | | §9 |
| `KEY_MAX` | `50` | | Roblox's documented cap, asserted against the longest possible userId |
| `CLOSE_TIMEOUT_SECONDS` | `20` | | the bound on `closeAll`, inside `BindToClose`'s own window |

And in `Match.CONFIG.POINTS`: **`KIND.cub = -10`** — K, one whole male, the figure `SAFETY_PENALTY`
already uses for the other thing you must not shoot. A cub was `+2`; `-10` is a 12-point swing,
which is what makes it a mistake rather than a smaller prize.

### Numeric targets, each one checkable

| Target | Value | Checked by |
|---|---|---|
| a male boar's kill | 10 points → **30 coins** (20 + 10 participation) | `economy.spec`, pure |
| top hunter, 16 points | 32 + 10 + 25 = **67 coins** | `economy.spec`, pure |
| two piglets + one safety violation | −30 points → **−50 coins**, balance floored at 0 | `economy.spec`, pure |
| a drive's coin spread | 10 to ~105 per player (0–40 points, §scoring note) | `economy.spec`, pure |
| DataStore requests per minute, 16 players | 1 `StartSessionAsync` per join + 1 `EndSession` per leave + ProfileStore's own auto-saves ≈ **under 40**, against the documented `60 + numPlayers × 40 = 700` | arithmetic, stated; not measurable in Studio |
| DataStore calls per coin / kill / frame | **0** | `economy.spec`: a pay-out performs no store call at all (`Store.memory` counts its calls) |
| key length | `"player_" + ≤ 19 digits = ≤ 26` chars, cap **50** | `economy.spec`, pure |
| value size | balance + 3 integers + schema ≈ **under 200 bytes**, cap 4,194,304 | stated |
| `payDrive` cost | ≤ 16 rows, no yield, no allocation per row beyond one table, **< 0.5 ms** | `economy.spec` times it |
| snapshot growth | **2 numbers × ≤ 16 rows** on a snapshot that already carries 9 fields per row | stated |
| panel row width | 48 chars = **384 px** inside 448 | `match_client.spec` asserts the formatted length |
| row budget | `SCORE_ROWS_MAX (20) >= MAX_PLAYERS (16) + 3` | `match_config.spec` |
| double pay | **exactly one** pay-out per `driveNumber` | `economy.spec` + `zz_drive_boundary.spec` (`stats().drivesPaid == stats().drives` over the run) |

---

## 9. The profile: shape, key, store name, migration (brief §2.5)

```luau
Store.TEMPLATE = {
    schema = 1,              -- what this build expects. A BREAKING change bumps STORE_NAME, not this
    coins = 0,               -- the balance
    coinsEarnedTotal = 0,    -- lifetime earnings. The one number spending destroys and cannot rebuild
    drivesPaid = 0,          -- how many drives this player has been paid for: the double-pay forensic
}
```

* **Store name `"DrivenHuntPlayer_v1"`.** Versioned in the NAME, because that is the only migration
  tool that cannot corrupt live data: a change this design cannot make additively bumps to `_v2` and
  leaves every `_v1` key untouched and readable. It is not `"Coins"` because the next thing into this
  table is *"Progress trophys"* and a table named after one of its columns forces either a second
  store or a lie.
* **Key `"player_<userId>"`**, `Store.keyFor` — the note's own choice, 26 characters at worst against
  the documented 50.
* **Adding a field later is additive and needs no new store**: add a row to `TEMPLATE`. `Store.read`
  is what makes that safe:

  ```luau
  -- PURE. Every key the template names, from `data` if it has one and from the template if it does
  -- not; every key the template does NOT name is kept as it is.
  Store.read(data) -> { [string]: any }
  ```

  Two halves, each with a reason. **Filling a missing key** is what lets a profile written by an
  older build be read by this one — and it is **written here rather than assumed of the library**:
  whether ProfileStore reconciles a template on load is **NOT VERIFIED** (§14), and twelve lines of
  pure code make the answer irrelevant. **Keeping an unknown key** is what lets a ROLLBACK be
  survivable: a build that does not know about `trophies` must not delete the trophies a newer build
  wrote. That is the one piece of this design that is invented rather than borrowed, and this
  paragraph is the written reason rule 2 requires.
* **`schema` is read and never acted on in this task.** It is the number a later migration branches
  on; branching on it now would be a migration with nothing to migrate.

---

## 10. The seams, and the spec claim each one buys (brief §2.6)

**First, a correction to the brief's premise, with evidence.** The brief says *"A drive is 600
seconds, so no harness run ever reaches `Scoring`"*. That is true of the **client** and false of the
**server**: `Match.advanceForTests(seconds)` moves this owner's own clock
(`src/server/Match/init.luau`, `Match.advanceForTests`, gated on Studio plus `TestKit.activeToken()`)
and `tests/server/zz_drive_boundary.spec.luau` already drives `Running → Scoring → Assigning` on the
**real production `Match`** — *"with the real numbers, the real effects and the real players"* (that
file's header). It runs last (the `zz_` prefix) and waits for every client suite to finish, which is
precisely why the *client* cannot assert on that transition.

So the pay-out is provable end to end on the server in a harness run, and only the drawing needs a
synthetic snapshot.

| Seam (symbol) | Where | What it makes assertable in seconds |
|---|---|---|
| `Coins.forDrive(rows, config)` | `Economy.Coins`, PURE | every number in §8; the two first places; a tie at the top paying nobody; a negative drive line; `left` skipped; a non-numeric userId skipped; `others` paid without a bonus. No world, no store, no clock |
| `Coins.credit(balance, delta, config)` | PURE | the floor at 0, and that it is the only clamp |
| `Rank.splitByTeam` / `Rank.firstPlaceRank` | `Drive.Rank`, PURE | the partition is total (`#h + #b + #o == #rows`) and order-preserving; every case the retired `Hud.firstPlaceRank` had, moved verbatim |
| `Store.memory{ seed, refuse }` | `Economy.Store` | a seeded balance, and **the refused-session branch** without a second Roblox server |
| `Economy.start{ store = Store.memory(), enabled = true/false }` | the owner | the whole owner with no library, no network and no flag flip: `payDrive` → `balanceOf`; a second `payDrive` with the same drive number refused; a userId with no session skipped and counted; the flag-off branch connecting nothing |
| `Economy.payDrive(7, rows)` | the owner | **the pay-out without a drive.** The brief's hazard list becomes five assertions over a table |
| `Economy.storeKindFor(isStudio)` | PURE, exported | that a live server takes the real store and Studio can never, provable from inside Studio where `IsStudio()` is always true |
| `Store.read(data)` | PURE | a missing key filled from the template; an unknown key kept |
| `Store.keyFor(userId)` | PURE | the key cap, at the longest userId Roblox can issue |
| `Match.advanceForTests` + `Match.PhaseChanged` | existing | `Economy.stats().drivesPaid` rises by exactly 1 per drive boundary, and `Match.snapshot().rows[1].earned` is a number after it — on production `Match`, with the real `Economy` the composition root wired |
| `Hud.scorePanelLines(snapshot, userId)` / `Hud.coinsText` | PURE, exported | the two rankings, the restarting ranks, the badge, the `--`, the row width — handed a hand-built `Scoring` snapshot, which is how `Hud.renderScore` is already tested |
| `Hud.renderScore(snapshot, secondsLeft)` + `Hud.scoreRowText()` | existing | that the strings really reached the labels and the panel is really visible (the task-159 lesson: *"the panel reads, the words do not"*) |

**No production path exists for a test's benefit.** Everything above is either pure, or the
read-only view the drive is handed anyway, or `Store.memory` — which is **the Studio path by the
brief's own decision 3**, not a test fixture. Its `seed`/`refuse` options configure a module that
never runs on a live server. `Match.advanceForTests` is the existing gated seam. Nothing new is
gated, and nothing new is Studio-only in production code. (The rule this is held to is the one that
sent `TASKS.md` 36a's hit-marker race back.)

### 10.1 The spec files

| File | Side | Covers |
|---|---|---|
| `tests/server/economy.spec.luau` | server | `Coins` whole, `Economy` against `Store.memory`, the flag-off branch, every refusal counted, the double-pay guard, `storeKindFor` both ways, the budget timing |
| `tests/server/economy_store.spec.luau` | server | `Store.memory`'s contract (load/save/release/releaseAll/setOnLost, a second load is the same session, release twice), `Store.read`, `Store.keyFor`, `Store.TEMPLATE`, and `Economy.closeAll()` on a never-started owner |
| `tests/server/match_score.spec.luau` | server, CHANGED | `POINTS.KIND.cub == -10`; `Match.quarryLines` prints `cub -10` and the new `QUARRY_NOTE` |
| `tests/server/match_config.spec.luau` | server, CHANGED | `SCORE_ROWS_MAX >= MAX_PLAYERS + 3`; no economy key is on `Match.WORLD_OVERRIDABLE` |
| `tests/server/zz_drive_boundary.spec.luau` | server, CHANGED | the real boundary pays exactly once; `drivesPaid == drives`; the snapshot's rows carry `earned` |
| `tests/client/match_client.spec.luau` | client, CHANGED | `Rank.firstPlaceRank`'s cases (moved from `Hud.firstPlaceRank`); `scorePanelLines`; the panel's visible strings; `Hud.coinsText`; and the extended "no economy number on the wire" pattern assertion |

**Harness and scope:** `tools/studio_mcp.py` gains `("src/server/Economy/", "economy")` in
`BLAST_RADIUS` and `"economy": ("tests/server/economy.spec.luau", "tests/server/economy_store.spec.luau")`
in `SCOPE_SPECS`. `selftest` fails if a spec belongs to no scope, so the two new files must be added
in the same commit. `src/shared/Drive/` already maps to `match`, which covers `Rank.luau`.

**Two players.** This task touches `src/server/Match/`, `src/shared/Drive/`,
`tests/server/match_*.spec.luau`, `zz_drive_boundary.spec.luau` and
`tests/client/match_client.spec.luau` — **five entries on `TWO_PLAYER_PATHS`** — so it needs the
`[harness2]` line for the PR to `main`, and that is not avoidable: the wire contract and the drive's
own dispatch are where this system attaches. A review round may use a `scope=auto:…` line instead.
And the two-player run is where the board has something on it, which is where the pay-out is worth
asserting.

**Screenshot (rule 5).** The panel changes shape, so one capture of the results scene with both
rankings and a coins column is required, inspected, with the flag on
(`python tools/flags.py set COINS on`, play to a drive end, `python tools/flags.py clear` before the
harness).

---

## 11. Hazards (brief §3 item 8)

| Hazard | Mechanism that closes it | What says it stayed closed |
|---|---|---|
| **1. Double pay** | `enterScoring` is the one door into `Scoring`; `Match` pays on the **phase edge** (`state.phase ~= before and state.phase == "Scoring"`); and `Economy` refuses a `driveNumber` it has already paid (`lastPaidDrive`, reset by `start`/`stop`). The last is a belt over a brace, and it is justified: `Match.start` resets `driveNumber` to 0, so two worlds in one process both count from 1 | `stats().duplicatePayouts`; `drivesPaid == drives` in `zz_drive_boundary.spec` |
| **2. A balance goes negative** | `Coins.credit` is the only writer of `balances` and applies `math.max(FLOOR, …)`. The drive's own line is allowed to be negative and is carried in `earned`, not in `coins` | `stats().coinsClamped`; the pure case `20 + (−50) → 0` |
| **3. A leaver paid twice, or not at all** | Paid **never**: `Coins.forDrive` skips `row.left`. Released exactly once: `Economy.release` is idempotent and keyed on `sessions[userId]` | `skippedLeft`, `stats().releases`; a spec releases twice and gets `false` |
| **4. Two servers for one player** | ProfileStore's session lock, untouched and un-tuned (no `SetConstant`). On our side: a refused `StartSessionAsync` means **no session, no earning, no writing**, and `Profile.OnSessionEnd` drops our row the instant ownership moves — the library's own rule, *"no further changes to `Profile.Data` should be made"* | `loadsRefused`, `sessionsLost`; the `refuse` branch of `Store.memory`. **The real two-server case cannot be tested here** (§14) |
| **5. A Studio run reaching a live key** | Three layers: `Store.live` is reached only when `storeKindFor(RunService:IsStudio()) == "live"`; the `require` of ProfileStore is **inside `Store.live`'s body**, so a Studio session never performs the library's require-time `SetAsync`; and the flag is born OFF, so even a live server writes nothing until the default flips | `storeKindFor(true) == "memory"`; `storeKind()` is `"memory"` in every harness run; the one `print` naming the store taken |
| **6. A bot acquiring a row** | Structural, with no new filter: a bot has no `Player` and no userId, so `Phase.participantIds`, `Match.pushCreditable` and `Score`'s own keying already refuse it. `Coins.forDrive` additionally **counts** a non-numeric id rather than paying it | `skippedNotAPlayer`; a drive with `DRIVE_BOTS` on has no non-numeric key in `Economy.balances()` |
| **7. The results table shows no coins for 5 seconds** | The pay-out is on the edge **before** `applyEffects`, so the forced broadcast of `enterScoring` already carries `earned`. This is the measured defect of TASKS.md 32a(c), avoided by position | `Match.lastSent().rows[1].earned` is a number immediately after the boundary |
| **8. `payDrive` yields and the drive's effects land late** | `payDrive` touches four in-memory tables and calls `Store.save`, which performs no network call. Every yielding call (`load`, `release`, `releaseAll`) is inside a thread `Economy` spawns itself | a spec calls `payDrive` and asserts it returned within one frame; `Store.memory` counts its own calls |
| **9. A `BindToClose` per spec run** | Registered by the composition root, **never** by `Economy.start`, because `BindToClose` cannot be disconnected | stated; `Economy.closeAll()` on a never-started owner is a no-op, asserted |
| **10. A stale `earned` on the wire** | `payDrive` **replaces** the `earned` table whole and writes an entry for every row it saw, including 0 | a second `payDrive` with a different roster leaves no entry for the first roster |
| **11. The licence obligation** | Apache-2.0 §4(a) wants the licence copy to travel with the distribution, and the package's nested project file syncs only `ProfileStore.luau` — so the place carries the code and not the notice | §13 item 7: a before-release item with the fix named. `CREDITS.md` carries the attribution **now** |

---

## 12. Deltas: every file this design changes

**New**

* `src/server/Economy/init.luau`, `Coins.luau`, `Store.luau`
* `src/shared/Drive/Rank.luau`
* `tests/server/economy.spec.luau`, `tests/server/economy_store.spec.luau`
* `backups/2026-10-13_task-170_*` — the retired `Hud.firstPlaceRank`, the old `KIND.cub = 2` and the
  old `QUARRY_NOTE`, each with its rollback (rule 7)

**Changed**

| File | What |
|---|---|
| `src/server/Match/init.luau` | `POINTS.KIND.cub`, `QUARRY_NOTE`, `world.economy`, the `Scoring` edge in `dispatch`, the two snapshot row fields |
| `src/shared/Drive/init.luau` | `ScoreRow` gains `coins?`/`earned?`; `MatchSnapshot` comment; `Drive.Rank` re-exported; the seven new `CONFIG` words; `SCORE_ROWS_MAX` 16 → 20 |
| `src/client/Hud/init.luau` | `Hud.firstPlaceRank` retired → `Rank.firstPlaceRank`; `scoreRowText` loses `TEAM` and gains `COINS`; new `Hud.scorePanelLines` and `Hud.coinsText`; `renderScore` lays out lines instead of rows; the header string; one piece in `renderDrive`'s bar |
| `src/server/MatchBoot.server.luau`, `src/server/ForestTestBoot.server.luau` | `Economy.start()`, `economy = Economy.view()`, the `Assigning` retry, `game:BindToClose` |
| `src/shared/Flags/init.luau` | the `COINS` row |
| `tools/studio_mcp.py` | `BLAST_RADIUS` + `SCOPE_SPECS` for the `economy` scope |
| `CREDITS.md` | a new `## Code and libraries` section: ProfileStore 1.0.3, MadStudioRoblox, Apache-2.0, with the link |
| the six specs in §10.1 | |

**`docs/design/drive.md` — the Architect's own file, and this design is its delta.** It is already
stale: `src/server/Match/Score.luau`'s header and `Match.CONFIG.POINTS`'s comment both say so, and
`docs/research/2026-10-12-scoring.md` §5 queued it.

* **§7.1 — the points table is stale as a whole** (it still lists `KILL.head/chest/body/legs`,
  `PUSH = 25`, `ASSIST = 10`, `SAFETY_PENALTY = −50`). It must be replaced by `POINTS.KIND`
  (`male 10, female 6, cub -10, legendary 25, unknown 6`), `ASSIST 3`, `BEATER_PUSH 3`,
  `SAFETY_PENALTY −10`, and a line pointing at `Economy.CONFIG` for the coin rates. **Task 170
  changes `cub` only; the rest of that table went stale in task 160 and the correction belongs in the
  same edit.**
* **§7.3 — the leaderboard** gains: `Score.leaderboard` is unchanged and still total; the SPLIT into
  two rankings is `Drive.Rank.splitByTeam` of its output and is not a second sort.
* **§9.1 — the wire**: `ScoreRow`'s two new fields, and the note that there is still no inbound
  remote.
* **§9.2 — `Match`**: `World` gains `economy`; `Match.stats()` is unchanged.
* **§9.3 — the client**: the panel draws two rankings and a coins column; the bar carries the
  balance.
* **§11.3** points at §7.1; **§11.5** unchanged (no new remote, no new rate).
* **§12.3** `match_score.spec` covers the cub; a new line for `economy.spec`.
* **§14** the open decisions below.

**`GAME_DESIGN.md` — System owners.** One new row and four amendments:

1. **NEW:** *"**A player's coins and the saved profile** (the balance, this drive's earnings, the
   ProfileStore session and the DataStore key)"* → owner `ServerScriptService.Economy`, started once
   by each world's composition root and handed to the drive as a read-only **view** (`Economy.view()`
   — the `Bots.view()` / `ForestTest.readOnlyBoars` idiom). Inside it: `Economy.Coins` is the pure
   conversion, `Economy.Store` is the only thing that can reach `DataStoreService` and the **only
   place in the repository that requires ProfileStore**, lazily and never in Studio. It owns no
   clock, writes nothing drawn, no character, no boar, no weapon, and fires no remote. Location
   `src/server/Economy/`, wired in `MatchBoot`/`ForestTestBoot`. Flag `COINS`, born OFF. Note
   `docs/research/2026-10-13-coins-persistence.md`, design `docs/design/economy.md`.
2. **Game state / the drive** (`ServerScriptService.Match`): add that a drive end pays coins through
   the injected view on the `Scoring` edge before its effects, that `POINTS.KIND.cub` is now a
   penalty, and that `Match` writes **no** balance and holds no profile.
3. **Drive wire contract** (`ReplicatedStorage.Drive`): the two row fields, and `Drive.Rank` as the
   **one implementation** of "who is first", read by the server (the bonus) and the client (the
   badge).
4. **UI / anything drawn** (`PlayerScripts.Hud`): the panel draws two rankings with one first place
   each, the row's `TEAM` column is gone and a `COINS` column replaces it, the bar carries the local
   player's balance, and `Hud.firstPlaceRank` has moved to `Drive.Rank`.
5. **Bots:** the existing row's *"no row in `Score`, no DataStore"* is now a live claim rather than a
   statement about a system that does not exist; a spec asserts it.

`docs/research/INDEX.md` gains the note (the Builder's file).

---

## 13. Open decisions

**None of them blocks building.** Every one is one line of data or one predicate, and the design
states the value it ships with.

### Karen (feel / design)

1. **The three numbers**: `COINS_PER_POINT = 2`, `PARTICIPATION = 10`, `FIRST_PLACE = 25`, after one
   drive. A boar is 20 coins and a good drive is ~100. One line each.
2. **Is a leaver paid?** This design says **no** — the note's own words are *"for turning up **and
   finishing** the drive"*, and paying an absent player means writing a profile whose session is
   closed. One predicate in `Coins.forDrive` if she disagrees.
3. **Does the balance belong on the drive bar during the drive**, or only on the results table?
   Shipped on the bar in every phase, per the brief's *"HUD, at all times"*. One `table.insert`.
4. **`-- HUNTERS --` / `-- BEATERS --` on the panel headings**, which is her vocabulary against the
   board's old `SHOOTER`/`DRIVER`. `TASKS.md` row 158a is the standing question about the whole Hud
   and this settles only this panel.
5. **The piglet rule.** `cub = -10` makes shooting one a mistake; her doc says *"NOT
   piglets/cubs"*, which could instead mean the shot is **refused**. A refusal is a weapon-side rule
   and its own task; the price is this one. She also owns the new `QUARRY_NOTE` wording.

### Director (scope)

6. **When `COINS`' default flips to `true`.** Born OFF (§3), so a live server writes nothing until a
   one-line commit after Karen's OK. `expires = 2026-11-03` forces the question within 21 days.
7. **The Apache-2.0 notice in the published place** (hazard 11). `CREDITS.md` carries the attribution
   in this task; shipping the licence text with the place is a before-release item, cheap, and it
   belongs with the publish step that already has to strip the test code (`TASKS.md` row 2).
8. **Spending, trophies, a cross-server leaderboard, Robux** — confirmed out of scope (brief §4).
   `coinsEarnedTotal` and `drivesPaid` are in the template so the first two cost no migration.
9. **Whether every client should see every balance** (§6). Shipped visible, with the cheaper
   draw-only-your-own variant written down so it needs no redesign.

---

## 14. What I could not verify (rule 8)

* **The live store path is exercised by nothing in the suite, by design.** No spec requires
  ProfileStore and no spec touches `DataStoreService`. Its only evidence is the pure
  `storeKindFor(false) == "live"`, the one `print` naming the store taken, and Karen's own live
  session after the default flips. That is the price of brief decision 3 and it is the right price:
  the alternative is a harness run that writes live keys.
* **Whether ProfileStore reconciles a template on load is not verified.** `Store.read` makes the
  answer irrelevant (§9) and that is why it exists.
* **The two-server session-steal case cannot be reproduced here.** One Studio session is one server.
  The library's own documented behaviour (*"gracefully switches ownership from one server to the
  other"*) is taken on its author's word; what is testable is **our** reaction to it — a refused
  load and an `OnSessionEnd` — through `Store.memory`'s `refuse` option and `setOnLost`.
* **The request budget is arithmetic, not a measurement.** Studio with API access off issues no
  requests at all.
* **The glyph width used in §7.2 (≈ 8 px at `TextSize = 16`, `Enum.Font.Code`) is an estimate.** The
  spec must assert the formatted string's **character count**, and the screenshot is what settles
  the pixels. The design is built with 8 px of headroom per row at the worst case, and it narrows
  the row rather than widening the panel precisely so a wrong estimate costs a column and not a
  layout.
* **The sources below were fetched by the Builder on 2026-10-13 and are quoted from
  `docs/research/2026-10-13-coins-persistence.md`, not re-fetched by this run** — this session has
  Read, Grep and Glob only. Licences and dates are that note's, which states it read ProfileStore's
  shipped source and `LICENSE` file directly.

---

## 15. External sources

### 15.1 ProfileStore — MadStudioRoblox — **the pattern adopted for the save layer**

<https://github.com/MadStudioRoblox/ProfileStore> · docs <https://madstudioroblox.github.io/ProfileStore/>
· **Apache-2.0** · **maintained** (last commit on `main` 2025-07-31, 32 commits; the library its own
predecessor points new projects at). Pinned as `lm-loleris/profilestore@1.0.3` under
`[server-dependencies]` in `wally.toml`, with `wally.lock` committed and `ServerPackages/` pinned by
`serverpackages.sha256`.

*Its own description:* *"Periodic DataStore saving solution with session locking"*, which
*"prevents other game servers from accessing this data too soon by establishing a session lock"*.

**Well:** it is exactly the shape of the problem — load once per server, keep a local table,
auto-save periodically, save on leave, refuse a second server — in one standalone ModuleScript, on
Wally, with a documented fake store. **Badly, and both were found by reading its source rather than
its docs:** it does **not** fall back to a mock by itself, and its Studio API-access probe is a real
`DataStoreService:GetDataStore("____PS"):SetAsync("____PS", os.time())` fired by the **require**.

**Adopted whole, reached only through `Store.live`**, which requires it lazily and is selected only
when `RunService:IsStudio()` is false. We call no `SetConstant`: the auto-save period and the steal
timings are the author's tested defaults, and a number we picked would be a number nobody measured.
`ProfileStore.Mock` is deliberately **not** the mechanism — reaching it still means requiring the
library in Studio.

### 15.2 ProfileService — MadStudioRoblox — rejected

<https://github.com/MadStudioRoblox/ProfileService> · **Apache-2.0** · **deprecated by its own
author**: *"FOR NEW PROJECTS - USE ProfileStore"*, *"This project is no longer supported"*.

**Well:** it is the origin of the pattern and states the reason better than its successor —
*"session-locking is essential to keeping your data protected from multiple server editing - this is
a potential cause of item loss or item duplication loopholes."* That sentence is why §11 hazard 4
exists. **Badly:** unsupported, by its author, in its README's first line. **Rejected for that alone.**

### 15.3 Roblox — data stores, Studio API access, limits, best practices — current, no licence granted

<https://create.roblox.com/docs/cloud-services/data-stores> ·
<https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits> ·
<https://create.roblox.com/docs/cloud-services/data-stores/best-practices>

*Verbatim:* *"By default, games tested in Studio can't access data stores… Accessing data stores in
Studio can be dangerous for live games because Studio accesses the same data stores as the client
application."* · budgets `"60 + numPlayers x 40"` per minute, keys cap at `"50"` characters, values
at `"4,194,304"` · *"Load a player's data at the start of a session and keep a server-local copy for
gameplay. Update the local copy instead of sending a data store request for every change"* and
*"Save it periodically, when the player leaves, when the server shuts down, and at critical
checkpoints."*

**Well:** it is the authority for the budget (§8), the key cap (§9) and the whole §1.2 item 3 — one
key space shared by Studio and the live game. The best-practices page **is** ProfileStore's feature
list restated as advice, which is the strongest argument available for borrowing it (§5's lifecycle
table is that paragraph, made into a table with an owner per row). **Badly:** on two servers writing
one key it gets only as far as recommending `UpdateAsync` to *"handle multi-server attempts"* —
**that is one safe write, not a session lock**, which is why raw `DataStoreService` is rejected.

### 15.4 DataKeep — noahrepublic — weighed and rejected

<https://github.com/noahrepublic/DataKeep> · **MIT** · active (301 commits, not archived).
*"A Promised-base auto-saving DataStore library"*.

**Well:** MIT is a simpler licence than Apache-2.0, and it is maintained. **Badly, for us:** its
README does not mention session locking at all, and session locking is the one property this task is
buying; and it is Promise-based, which would pull a Promise library into a repo whose every system is
plain Luau with an injected seam. **Rejected.**

### 15.5 ioquake3, `code/game/g_main.c` — `CalculateRanks` / `RANK_TIED_FLAG` — **the rank rule**

<https://github.com/ioquake/ioq3> · **GPL-2.0** · maintained. The repo this project has already
borrowed from twice (the results-scene intermission, and `Hud.firstPlaceRank` itself in task 160).

**Well:** *"we are tied with the previous client"* sets `rank | RANK_TIED_FLAG` on **both** rows, and
the flag is also set when `numPlayingClients == 1` — **a tie at the top is not a first place, and a
lone player is marked tied rather than winning, in the DATA rather than in the drawing.** That is
the whole of `Rank.firstPlaceRank`, and §4.3 is the decision to have **one** implementation of it now
that the server pays money off it. **Badly:** it ranks one list, and this game has two. The pattern
is adopted and the partition (`Rank.splitByTeam`) is ours — total by construction, order-preserving,
and the rule asked once per list.

### 15.6 Roblox — `DataModel:BindToClose` — current, no licence granted

<https://create.roblox.com/docs/reference/engine/classes/DataModel#BindToClose>

**Well:** it is the only hook for the shutdown row of §5, and the repository has none today.
**Badly, and it decides §4.6:** a bound callback **cannot be disconnected**, so registering one
inside `Economy.start` would leave one per spec run bound for the rest of the session. It is
therefore registered by the composition root, once, and `Economy.closeAll()` is safe on a
never-started owner.

### 15.7 Borrowed from inside this repo (rule 2 applies to internal patterns too)

* **the pure decision module beside the impure owner** — `src/server/Match/Score.luau` and
  `src/server/Match/init.luau`, at a fourth instance (`Boar.Brain`, `Weapon.StateMachine`,
  `Match.Phase` are the others);
* **the read-only view handed to another owner** — `Bots.view()` and
  `ForestTest.readOnlyBoars(runtime)`, named as the idiom in `MatchBoot`'s own comments;
* **the level-triggered, idempotent refresh** instead of an edge-triggered grant —
  `Weapon.refreshArming` and `Match`'s `syncBots`, whose comment carries the reason: *"every
  edge-triggered grant in this repo has been measured missing one"*;
* **the pure Studio guard as an exported predicate** — `Match.quickTestEnabled(flagOn, isStudio)`,
  which is `Economy.storeKindFor` exactly;
* **the one boundary flag read passed inward** — `Match.CONFIG.TIE_UNTIL_DRIVE_END`,
  `Match.CONFIG.BOTS.ENABLED`;
* **the pure formatter returning `{ string }` for a renderer to lay out** —
  `Match.quarryLines` on the server, `Hud.startCardLines` on the client.

### 15.8 Invented, with the written reason rule 2 requires

* **`Store.read`'s missing-key / keep-unknown rule** (§9): because whether ProfileStore reconciles a
  template is unverified, and because a rollback must not delete a newer build's field. Twelve pure
  lines against an unverified dependency behaviour.
* **`lastPaidDrive`** (§11 hazard 1): a belt over the brace of a single phase edge, because
  `Match.start` resets `driveNumber` and because a pay-out is the one thing here that cannot be
  undone.

### The pattern adopted overall

**ProfileStore 1.0.3, pinned through Wally, reached only through one narrow store interface that the
specs and Studio replace with an in-memory double; coins are a pure function of the drive's own
board, paid once on the `Scoring` edge by a new server owner that the drive is handed a read-only
view of; and "who is first" is one shared pure rule the server pays off and the client draws.**

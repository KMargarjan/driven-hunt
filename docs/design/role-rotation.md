# Design: role rotation (a player alternates hunter / beater, and the turn survives a logout)

Task 217. Written to `reviews/task-217/BRIEF.md`, which overrides anything older in `docs/`,
`TASKS.md` and any earlier design. Note: `docs/research/2026-10-20-role-rotation.md`.

Karen, 2026-10-11, carried forward on the v1 plan of 2026-10-19:

> *"ROLES ROTATE: you start as a hunter, next round you are a beater; it is REMEMBERED across
> logout/login (no cheating back to hunter) — persistent per player (DataStore)."*

**This is not a new system.** The drive already alternates roles inside one server session
(`Match.CONFIG.SWAP_TEAMS_EACH_DRIVE = true`, honoured by `Roster.assign`'s `previous` swap), and
persistence already has exactly one owner (`ServerScriptService.Economy`, task 170). What this task
adds is the join between them: **the turn becomes a per-player fact that outlives the session.**

---

## 1. What it must do, and what it must not do

### 1.1 Must do

1. **Alternate per completed drive, per player.** Shot in drive *N* → pushes in *N+1* → shoots in
   *N+2*. Two roles, a strict 2-cycle, no randomness.
2. **Remember across logout/login.** Leaving the server and coming back must not hand a beater a
   gun. This is the anti-cheat half and the reason the fact is persisted at all.
3. **Never break the teams the drive needs.** `|Drivers − Shooters| <= 1` is Karen's older rule and
   it is older than this one. A turn the roster could not honour is **not consumed**.
4. **Leaving mid-drive must not advance the turn.** A beater who disconnects at 00:30 and rejoins is
   still a beater.
5. **The Studio test switches still win for the drive they are used in.** `DHForestStartRole` and
   `/beater` (tasks 153, 157, 214) move THIS drive; the record then mirrors the role he actually
   played, so the next drive rotates off it.
6. **Bots fill as today.** `src/server/Bots/` is untouched.
7. **One owner each, everywhere.** One persistence owner, one roster, one writer of `Player.Team`.

### 1.2 Must not

* **No second DataStore, no second store name, no second key per player.** One additive field on the
  one profile table. `DataStoreService` is still reachable from `Economy.Store` and nowhere else.
* **No new clock.** No `Heartbeat`, no `task.delay`, no auto-save of ours. `Store.save` performs no
  network call by contract; ProfileStore owns the period.
* **No new source of truth for "which side is he on".** That is `Phase.State.assignment`. The
  persisted field is a **mirror of it**, written where the drive already writes a team.
* **Nothing new on the wire.** No remote, no `MatchSnapshot` field, no client module, no drawing.
* **No new feature flag row.** `Flags.MAX_FLAGS` is 14 with 14 rows and a bump is the Director's call
  (`TASKS.md` 215a(a)).
* **No new spec file**, so `SCOPE_SPECS` needs no new key (one existing key gains one existing file —
  §11.7).
* **It must not fix 214a(a) or build 214b.** The seam is shaped for 214b and neither is touched.

---

## 2. Owners: who writes what, and why no two of them can disagree

| Fact | The one writer | On disk |
|---|---|---|
| **The rotation RULE** — what the other role is, how a stored turn folds into a split | `Match.Roster` (PURE: no services, no Instances, no clock, no Random, keyed by userId) | `src/server/Match/Roster.luau` |
| **WHO IS ON WHICH SIDE this drive** | `Match.Phase` decides it (`enterAssigning`, the `join` branch, the `team` branch) and it lives in `Phase.State.assignment` | `src/server/Match/Phase.luau` |
| **`Player.Team`** | `Match.Body.setTeam`, whose only callers are `applyAssignTeams` and `applyUnassign` | `src/server/Match/Body.luau` |
| **The persisted RECORD of the turn** | `ServerScriptService.Economy` — `Economy.noteNextTeams` is the only writer of the field, and `Economy.Store` is the only thing in the repository that may reach `DataStoreService` | `src/server/Economy/init.luau`, `src/server/Economy/Store.luau` |
| **The two shared team strings, as a runtime set** | `ReplicatedStorage.Drive` (frozen data, no writer) | `src/shared/Drive/init.luau` |

**The sentence that says no two of them can disagree.** There is exactly one place a team is
written (`applyAssignTeams`), and the record is written **in that function, beside that write**, so
the two cannot be separated without touching the same four lines. The record is never READ to decide
anything except as a *suggestion* to `Roster.assign`, which may overrule it; so a stale record cannot
contradict the live assignment — it can only ask for something the roster then refuses. And at the
end of every drive the record is rewritten **whole** from `state.assignment` (§5.2), so any drift
accumulated inside a drive is corrected once per drive by construction.

`Economy` does not require `Match`, `Match` does not require `Economy`. The drive is handed a
read-only-plus-one-named-event **view** (`Economy.view()`), exactly as task 170 and task 178 left it.

---

## 3. The record: one field

### 3.1 The field

```luau
Store.TEMPLATE = {
    schema = 1,
    coins = 0,
    coinsEarnedTotal = 0,
    drivesPaid = 0,
    owned = {},
    nextTeam = "",   -- NEW (task 217)
}
```

| | |
|---|---|
| **Name** | `nextTeam` |
| **Type** | `string` |
| **Legal values** | `"Drivers"`, `"Shooters"`, or `""` |
| **Default for a brand-new player** | `""` — *no turn stored* |
| **Meaning** | **the team this player must be given at the next assignment he takes part in.** During a drive it is the team he is PLAYING (a rejoin resumes the drive he left — requirement 1.1.4); from the `Scoring` edge of a completed drive it is the OTHER one (requirement 1.1.1) |
| **Validator** | `Economy.teamFromRecord(value)`, PURE and exported, at the `Economy` boundary and nowhere else. Returns the value when it is one of the two team names, otherwise `nil` |
| **An unknown or corrupted value** | `""`, `nil`, `"hunter"`, `7`, `true`, `{}` all answer `nil` from the validator, which means *no turn stored* — the brand-new-player case, which already has to work. Never an error, never a crash, never a guess |
| **`schema`** | **unchanged at 1, still read and never acted on.** The field is additive: a profile without it means *no turn stored*. Branching on `schema` here would be a migration with nothing to migrate |
| **`Economy.CONFIG.STORE_NAME`** | **unchanged**, `"DrivenHuntPlayer_v1"`. Versioning in the name is for a change `Store.read` cannot make additively; this one it can |

### 3.2 Why the TEAM NAME and not Karen's word (brief §3.2, ruled)

**The team name.** `"Drivers"` / `"Shooters"` are what `Player.Team.Name`, `Score`'s rows,
`Roster.TeamName`, `Drive.TeamName`, the wire and a dozen specs already say. Storing Karen's word
would put a second vocabulary into the persisted record and a second translator (`Body.teamForWord`)
on the hot path of every drive boundary. A DataStore dump is read by one person twice a year;
`Body.ROLE_WORDS` already translates for the screen.

### 3.3 Why `""` and not a missing key

`Store.TEMPLATE` is **enumerated** by `Store.read`'s fill-missing half (`for key, value in
pairs(Store.TEMPLATE)`). A key whose default were `nil` cannot exist in a Lua table, so the template
would not name the field at all, `ProfileStore.New(storeName, Store.TEMPLATE)` would not know it, and
a reader of the template would not see the profile's real shape. `""` is a plain scalar, so:

* `Store.read`'s clone branch is `type(value) == "table"` — not taken. **Hazard 1 (the shared frozen
  table) cannot recur for this field**, and that is structural, not a promise.
* `Drive.deepFreeze(Store.TEMPLATE)` freezes one more scalar. No change.
* An empty string survives a DataStore round trip; an empty *table* is the thing nobody here has
  verified, and that is why `owned` is type-checked and this is not.

### 3.4 The runtime half of the team names

`src/shared/Drive/init.luau` already exports `export type TeamName = "Drivers" | "Shooters"` and no
runtime equivalent. Add one, beside the type:

```luau
-- The runtime half of `Drive.TeamName`: the membership test, so a validator does not need a sixth
-- copy of the two strings. Frozen shared DATA with no writer, the discipline the rest of this
-- module follows.
Drive.TEAMS = table.freeze({ Drivers = true, Shooters = true })
```

`Economy.teamFromRecord` reads it. `Economy` already requires `ReplicatedStorage.Drive` (for
`deepFreeze`), so this adds no owner edge. `Roster`'s own `DRIVERS` / `SHOOTERS` locals stay as they
are: `match_roster.spec` pins them at every size from 2 to 16, and rewriting a pinned pure module to
save two literals is a bigger change than the feature.

---

## 4. The interface: every symbol added or changed, by name and signature

### 4.1 `src/server/Match/Roster.luau` — PURE, four new functions

```luau
-- The other side. nil in, nil out, so a corrupted value drops a row rather than inventing one.
function Roster.other(team: TeamName?): TeamName?

-- Every row flipped, as a NEW table. The input is never written (it is usually `state.assignment`,
-- which is frozen).
function Roster.invert(assignment: Assignment): Assignment

-- THE STORED TURN, FOLDED IN AS A SYNTHETIC `previous`.
--   * `owed` nil or empty -> `previous` is returned BY IDENTITY. Nothing is allocated and the game
--     is bit-for-bit what it is today.
--   * otherwise -> a new table: `previous`'s rows, with `other(owed[u])` written over the row of
--     every player who is owed a turn. `previous` may be nil; then the result holds only the owed
--     rows, which is what makes the FIRST drive after a rejoin honour the turn.
-- THE INVERSION IS HERE AND ONLY HERE, and it is the one trap in this design: `Roster.assign`'s
-- swap gives a player the OPPOSITE of his `previous` row, so to land him on the team he is OWED the
-- synthetic row must be the other one. `Roster.joinTeam` below does NOT invert, because it places a
-- man directly.
function Roster.previousFrom(previous: Assignment?, owed: { [number]: TeamName }?): Assignment?

-- WHICH TEAM A LATE ARRIVAL GETS. `Roster.smallerTeam` unless the two sides are EQUAL, in which
-- case the owed team costs the balance nothing and wins. `owed` nil answers `smallerTeam` exactly,
-- which is this function before task 217.
function Roster.joinTeam(counts: { [string]: number }, owed: TeamName?, config): TeamName
```

`Roster.assign`, `Roster.counts` and `Roster.smallerTeam` are **not touched**. Their algorithm, the
`|Drivers − Shooters| <= 1` balance check and the plain-split fallback are unchanged, so the suite's
2..16 sweep still pins exactly what it pins today.

### 4.2 `src/server/Match/Phase.luau` — PURE, one field and two call sites

```luau
export type Event = {
    ...
    -- WHAT EACH PLAYER IS OWED, filled by the owner on EVERY event (the `aliveBoars` idiom, and the
    -- shape TASKS.md 214b prescribes). A FROZEN table the owner memoises; this machine only reads
    -- it and never stores it in the state. Absent or empty = nobody is owed anything, and every
    -- answer below is then today's answer by identity.
    owed: { [number]: TeamName }?,
}
```

Two readers, and no third:

```luau
-- enterAssigning gains the table as a parameter (it is called from Phase.step's `Waiting` and
-- `Scoring` exits, both of which have the event in hand).
local function enterAssigning(state, effects, now, config, owed)
    ...
    local previous = Roster.previousFrom(state.previousAssignment, owed)
    state.assignment = Roster.assign(userIds, previous, config)
    ...
end

-- the `join` branch:
local team = Roster.joinTeam(Roster.counts(next_.assignment), owed and owed[event.userId], config)
```

**What `Phase` does when `owed` is absent:** `previousFrom(prev, nil)` returns `prev` by identity and
`joinTeam(counts, nil, config)` returns `Roster.smallerTeam(counts, config)`. Both are today's lines.

**`owed` is never written into `Phase.State`.** It is a per-event fact, like `aliveBoars`. A field on
the state would need a writer, and the only honest writer would be the owner — which is the owner
holding the same fact twice.

`Phase.State` gains no field. No new effect kind. `freezeState` is unchanged.

### 4.3 `src/server/Match/init.luau` — the owner: one fill, two edges

**The per-event fill**, in `dispatch`, beside the four that are already there:

```luau
-- ...AND WHAT EACH PLAYER IS OWED (task 217), on every event for `aliveBoars`' reason: an
-- assignment can happen on a join as well as on a tick. The view's answer is a MEMOISED FROZEN
-- table, so this is one table read and no clone -- which matters while TASKS.md 214a(a) is open and
-- this dispatch is stepped at ~15x MATCH_STEP_HZ.
if filled.owed == nil and world and world.economy and world.economy.owedTeams then
    filled.owed = world.economy.owedTeams()
end
```

**Write edge 1 — wherever the drive already writes a team**, in `applyAssignTeams`:

```luau
local function applyAssignTeams(assignment)
    for userId, team in pairs(assignment) do
        local player = playersService():GetPlayerByUserId(userId)
        if player then
            Body.setTeam(player, team, config)
        end
        board = Score.setTeam(board, userId, team)
    end
    -- THE RECORD MIRRORS THE ROLE HE IS ACTUALLY PLAYING (task 217, decision 10). It is HERE, beside
    -- `Body.setTeam`, because this is the one place a team is written -- so an assignment this
    -- design did not think of (a mid-drive join, a `/beater` request, a second placement) cannot
    -- leave the record stale. The owner writes nothing derived: it is handed the table and stores it.
    if world and world.economy and world.economy.noteNextTeams then
        world.economy.noteNextTeams(assignment)
    end
end
```

`assignment` here is sometimes the whole table and sometimes one row (`{ [userId] = team }`). Both
are correct inputs: the record is per-player and a partial update is a partial update.

**`applyUnassign` deliberately does NOT touch the record.** It hands back `Player.Team`; it does not
hand back the turn. Wiping the turn when the server empties (`enterWaiting`) or when a player sits
out a drive is exactly the "cheating back to hunter" the feature exists to prevent.

**Write edge 2 — the `Scoring` edge, before `applyEffects`**, inside the existing pay-out block:

```luau
if state.phase ~= before and state.phase == "Scoring" and world and world.economy then
    world.economy.payDrive(state.driveNumber, Score.leaderboard(board))
    -- ...AND THE TURN FLIPS, on the same edge and for a related reason (task 217). The value is
    -- `other(the role he ACTUALLY played)`, computed WHOLE from the final assignment -- so a turn
    -- the balance rule could not honour is still owed, with no second field and no "was it
    -- honoured" flag to get wrong, and so any drift inside the drive is reconciled once per drive.
    if world.economy.noteNextTeams then
        world.economy.noteNextTeams(Roster.invert(state.assignment))
    end
    snapshotCache = nil
end
```

**Why BEFORE `applyEffects`, stated honestly.** The measured precedent beside it (TASKS.md 32a(c),
and economy.md §4.5) is about the forced broadcast carrying fresh data — **that argument does not
apply here, because nothing about the turn goes on the wire.** The reason it goes before the effects
is different and is its own: `applyEffects` at this edge applies `release`, `clearBoars`, `hold` and
`scene`, and `applyScene` moves every character. If anything in that list yields, a
`Players.PlayerRemoving` landing in the window would reach `Economy.release` and drop the session
before the flip was written — and the flip for a man who was there when the drive ended would be
lost. Writing first closes that window, and it costs nothing.

`state.assignment` and not `state.previousAssignment`: `enterScoring` sets
`state.previousAssignment = state.assignment` and clears neither, so the two are the same table at
this instant. The live one is the one to read.

**Nothing else in `Match` changes.** No new state, no new table, no new clock, no new effect kind,
no `Match.CONFIG` key, no `WORLD_OVERRIDABLE` key, no snapshot field.

### 4.4 `src/server/Economy/init.luau` — the record's owner

```luau
-- PURE, exported. The ONE validator, at this owner's boundary -- the discipline `Economy.load`'s
-- four `type(...)` checks already follow. Anything that is not one of the two team names is `nil`,
-- which MEANS no turn stored.
function Economy.teamFromRecord(value: any): Drive.TeamName?

-- WHAT EACH OPEN PROFILE IS OWED: userId -> team. A FROZEN table, MEMOISED and rebuilt (never
-- mutated) on a write that changes a row -- the `Economy.balances()` idiom with a cache, because
-- `Match.dispatch` asks for it on every event. Empty when the flag is off, when no profile is open,
-- and in every spec that starts no money.
function Economy.owedTeams(): { [number]: Drive.TeamName }

-- THE ONE WRITER OF `nextTeam`, AND IT DERIVES NOTHING (hazard 2's lesson, which is why
-- `Store.save` stopped deriving in task 178): it is told each player's next team and it stores
-- exactly that. Returns how many rows it wrote, so a spec can assert a number.
--   * a userId with no open session is skipped and counted (`nextTeamSkippedNoProfile`);
--   * a value `teamFromRecord` refuses is skipped and counted (`nextTeamRefused`);
--   * the caller's table is READ and never retained.
function Economy.noteNextTeams(teams: { [number]: Drive.TeamName }): number
```

`Economy.stats()` gains `nextTeamsWritten`, `nextTeamSkippedNoProfile`, `nextTeamRefused`.
`resetStats` zeroes them with the rest.

`Economy.load`'s projection gains one line, the fifth type-checked field:

```luau
nextTeams[userId] = Economy.teamFromRecord(data.nextTeam)
```

`Economy.release`, `closeAll`, `stop`, `start` and the `setOnLost` handler each clear the row and
invalidate the memo, beside the five tables they already clear. A session another server takes off us
therefore reads as *no turn stored* — he gets the smaller side and his record is untouched on disk.

**`payDrive` and `purchase` do NOT touch `nextTeam`.** Coupling the turn to the pay-out loop would
make the rotation depend on `skippedLeft`, the clamp and the double-pay guard — the exact shape
hazard 2 was written for.

**The view** (`Economy.view()`), two more functions and no setter:

```luau
export type View = {
    payDrive:      (driveNumber: number, rows: any) -> (),
    balances:      () -> { [number]: number },
    earned:        () -> { [number]: number },
    enabled:       () -> boolean,
    ownedOf:       (userId: number) -> { [string]: boolean }?,
    owedTeams:     () -> { [number]: Drive.TeamName },          -- NEW: the read
    noteNextTeams: (teams: { [number]: Drive.TeamName }) -> (), -- NEW: the one named write
}
```

**What the drive still cannot do through it** (brief §3.7): open a session, end one, read or write a
balance, read or write a hunt count, buy or grant anything, name a profile field, reach `Store`,
reach ProfileStore, reach `DataStoreService`, start or stop this owner, or write any row for a
userId whose profile is not open. `noteNextTeams` is a named domain statement, not a setter: the
field it writes is chosen by this owner and cannot be named by the caller.

**No `Economy.owedOf(userId)` is added.** The drive wants the table, not a per-player question, and a
second shape would be a second reader of one fact.

### 4.5 `src/server/Economy/Store.luau` — one template row

The `nextTeam = ""` row of §3.1, with the comment that says what `""` means and why it is a string.
Nothing else in the file changes: `read`, `memory`, `live`, `keyFor`, `save`, `peek` and the frozen
template all behave as written.

---

## 5. The edges, in order, with the reason each is where it is

### 5.1 The read edge: `enterAssigning`

| When | What |
|---|---|
| `dispatch` fills `event.owed` | one read of the memoised frozen table |
| `Phase.step` → `enterAssigning` | `Roster.previousFrom(state.previousAssignment, owed)` → `Roster.assign(...)` |
| `Phase.step` → the `join` branch | `Roster.joinTeam(counts, owed[u], config)` |

It is read in exactly those two branches. Nothing else in `Phase` looks at it.

### 5.2 The two write edges

| Order within one drive | Where | Value written | Why there |
|---|---|---|---|
| **1** | `applyAssignTeams`, inside `applyEffects` | the team he is NOW playing | It is the one place a team is written. A rejoin must resume the drive he left (1.1.4), so during a drive the owed team IS the team he is playing. Covers `enterAssigning`'s whole-roster `assignTeams`, the `join` branch's one row and the `team` branch's one row, with no new call site |
| **2** | `dispatch`'s `Scoring` edge, before `applyEffects` | `Roster.invert(state.assignment)` — the OTHER role, for everybody still in the drive | A drive that reached `Scoring` is a drive he completed. Computed WHOLE from the final assignment, so it also reconciles the drive's mid-flight writes (§5.4) |

### 5.3 Why the turn is NOT consumed when balance overrules it (brief decision 4, ruled)

**Nothing consumes it. There is no consume step.** `Roster.previousFrom` only READS the table;
`Roster.assign` may then ignore the synthetic rows entirely (the plain-split fallback discards the
whole swap). The only thing that ever writes the record is `other(what he ACTUALLY played)` at edge 2.

So a man owed beater whom the balance rule made a hunter is written `other("Shooters") = "Drivers"`
at the end of that drive — **owed beater again**, which is indistinguishable from the ordinary
rotation and needs no second field and no "was it honoured" flag. The single value that carries the
fact is `nextTeam`, and the design's claim is that there is nothing else to get wrong.

Worked case, four players, all owed `"Drivers"`:
`previousFrom(nil, owed)` → all `"Shooters"` → `assign`'s swap → all `"Drivers"`, counts 4/0 →
`|4 − 0| > 1` → plain split → ids 1,2 `Drivers`, ids 3,4 `Shooters`. At `Scoring`: 1,2 owed
`Shooters`; **3,4 owed `Drivers` again**. Next drive: synthetic previous 1,2 `Drivers` / 3,4
`Shooters` → swap → 1,2 `Shooters` / 3,4 `Drivers`, counts 2/2, balanced, **honoured**. The turn
survived one drive and was paid the next.

### 5.4 The self-healing property, stated because it is load-bearing

Edge 1 can MISS a player: `Economy.load` runs in a spawned thread and the store yields, so a player
who joins a `MIN_PLAYERS = 1` server can be assigned before his profile answers. `noteNextTeams` then
skips him (no session) and counts it — **his stored turn is not overwritten.** When his session opens
mid-drive, edge 2 writes `other(what he played)`, which for a turn that was not honoured is the turn
itself (§5.3). So:

> **A race on the profile costs exactly one drive on the wrong side and can never corrupt the
> record.**

That is the same arithmetic as §5.3 and it is why edge 2 is computed whole rather than incrementally.
The cost in the game is real and is named in §9 hazard 7 and §14 item 4.

---

## 6. The `Store.TEMPLATE` enumeration check, written out (brief §4 item 5; L-030 / L-096)

`Store.TEMPLATE` is `Drive.deepFreeze`d and **enumerated**. Every consumer, and what each does with
`nextTeam = ""`:

| Consumer (symbol) | What it does with the new key | Changes needed |
|---|---|---|
| `Store.read`, fill-missing half (`for key, value in pairs(Store.TEMPLATE)`) | fills `""` when the key is absent. `type(value) == "table"` is false, so the clone branch and the wrong-type-replacement branch are both skipped | none |
| `Store.read`, keep-unknown half | a build that predates this task keeps whatever a newer one wrote — the rollback half | none |
| `Drive.deepFreeze(Store.TEMPLATE)` | freezes one more scalar | none |
| `Store.memory`'s `seed` (`saved[key] = Store.read(seeded)`) | a seeded profile gains `nextTeam = ""` unless the seed names it. The NUMBER shorthand (`seed = { [7] = 500 }` → `{ coins = 500 }`) still works and still fills | none; specs may now seed `{ [7] = { nextTeam = "Drivers" } }` |
| `Store.memory`'s `peek` | answers `Store.read(saved[key])`, so it carries `nextTeam` — **this is the round-trip seam** | none |
| `Store.memory`'s `save` | `data[field] = value` for exactly the fields named | none |
| `Store.live`'s `ProfileStore.New(storeName, Store.TEMPLATE)` | the library's template gains one scalar key. Additive, no store-name bump | none |
| `Store.live`'s `load` (`profile.Data = Store.read(profile.Data)`) | an existing live key gains `nextTeam = ""` in the server-local copy at load | none |
| `Economy.load`'s projection | **one new line**, the fifth type-checked field | `nextTeams[userId] = Economy.teamFromRecord(data.nextTeam)` |
| `tests/server/economy_store.spec.luau` | **asserts the template's shape field by field and does NOT count keys**, so adding a row does not break it. Its hazard-1 case asserts `owned` specifically and is unaffected | one new case; the title *"holds the balance, lifetime earnings and the drive count, and a schema number"* becomes incomplete and must name the turn |
| `tests/server/economy.spec.luau` | drives the owner against `Store.memory` | new cases (§11.3) |
| `tests/server/shop.spec.luau` | reads `ShopData` and `Economy.purchase`; it seeds profiles but does not enumerate the template | none |

**No consumer counts the template's keys and no consumer iterates a profile expecting a fixed set.**
That is the check task 196 rewrote rule B for, and it passes.

---

## 7. The flag-off / no-economy story, stated as an identity

> With no economy injected, or with `COINS` off, **the drive's assignment is what it is today, value
> for value.**

The mechanism, in three links:

1. `Economy.owedTeams()` answers an **empty frozen table** when `enabled` is false (no session is
   ever opened, so no row exists), and `world.economy` absent means `dispatch` never sets
   `filled.owed` at all.
2. `Roster.previousFrom(previous, nil)` and `Roster.previousFrom(previous, {})` return `previous`
   **by identity** — the same table, not a copy — so `Roster.assign` receives byte-for-byte what it
   receives today.
3. `Roster.joinTeam(counts, nil, config)` **is** `Roster.smallerTeam(counts, config)`.

**The assertions that prove it, rather than hoping:**

* `expect(Roster.previousFrom(prev, nil)).to.equal(prev)` and the same for `{}` — raw table identity,
  which is stronger than a deep compare and is the whole claim.
* For every roster size 2..16: `Roster.assign(ids, Roster.previousFrom(prev, nil), config)` deep-
  equals `Roster.assign(ids, prev, config)`. The existing sweep is the regression and is not edited.
* `match_phase.spec`'s existing `enterAssigning` cases, run with no `owed` on the event, are the
  unchanged-machine assertion.
* `zz_drive_boundary.spec`, on the production drive with the default build: `Economy.owedTeams()` is
  empty and the assignment is the roster's alone — *off is the game before this task*, measured at
  the one boundary that could break it, in the shape that file already uses for the pay-out.

---

## 8. The brief's eight open decisions, ruled

**8.1 Does persistence ride the `COINS` flag? — YES, and it is accepted and said out loud.**

The profile session is gated by `Economy.CONFIG.ENABLED`, whose row promises that OFF means *"no
session is opened, no DataStore key is written"*. Opening sessions with `COINS` off would break that
flag's stated meaning and destroy its kill-switch property, which is the one thing standing between a
bug and a player's permanent record; a separate store is forbidden by decision 2. So the ruling is to
accept the coupling.

**What the player sees, in each of the three states:**

| State | Within one server session | Across logout / login |
|---|---|---|
| `COINS` off (today's git default, and every harness run) | roles alternate exactly as today, from `Phase.State.previousAssignment` | **the turn is forgotten.** A rejoiner is unknown to `assign` and fills the smaller side |
| `COINS` on, profile open | roles alternate | **the turn is kept.** Karen's sentence is true |
| `COINS` on, session refused or lost (another server holds the lock, or Roblox is down) | roles alternate | the turn is forgotten for that player, counted in `stats().loadsRefused` / `loadsFailed` / `sessionsLost`, and his record on disk is untouched |

Karen's own Forest Test place carries `DHFlag_COINS = true`, so it is true where she plays. **Flipping
the default is the Director's, in a task of its own** (§15 item 1) — and it is now a bigger decision
than it was, because it gates two features instead of one.

**8.2 What is stored, and in what vocabulary — the team name.** §3.1 and §3.2 are the ruling: field
`nextTeam`, type `string`, default `""`, validator `Economy.teamFromRecord`, an unknown value means
*no turn stored*, `schema` unchanged.

**8.3 Where the stored turn reaches the pure machine — ON THE EVENT.** `Phase.Event.owed`, filled by
`Match.dispatch` on every event, the `aliveBoars` / `boarEntries` / `beaters` idiom this owner uses
four times already and the shape TASKS.md 214b prescribes. Read in `enterAssigning` and in the `join`
branch, and nowhere else. Absent → today's answer by identity (§7). Rejected: a field on
`Phase.State` (it would need a writer, and the only honest writer is the owner, which is the owner
holding one fact twice) and a reader in `config` (frozen once at `start`, so it cannot carry
per-player data at all).

**8.4 A synthetic `previous`, not a fourth `assign` parameter.** `Roster.previousFrom`, pure. It
leaves `Roster.assign`'s algorithm, its balance check and its plain-split fallback untouched, so the
suite's 2..16 sweep still pins what it pins. The alternative — an `owed` parameter honoured up to each
side's capacity — honours more turns in the unbalanced-previous case, but it replaces a function the
suite pins at every size and changes today's behaviour, which is a bigger change than the feature.
The cost is named: in the unbalanced case the whole swap is discarded, owed rows included, and those
turns are simply not consumed (§5.3).

**8.5 A mid-drive join honours the turn only on a TIE.** `Roster.joinTeam`. On a tie both sides are
equal, so honouring the turn costs the balance nothing — the result differs by one either way; off a
tie the smaller team wins and the turn is not consumed. **What the lobby means for Karen's sentence:**
with tasks 177 and 209 a player walks onto a truck pad mid-intermission, so this branch is now the
NORMAL way into a drive, not an edge case — which means for a player who enrols mid-drive Karen's
sentence holds **when the sides are level and at the next drive otherwise.** That is a real
weakening of the promise and it is named here rather than discovered: §15 item 2 asks the Director
whether a joiner should instead wait for the next `Assigning`, which would honour every turn and
would cost him a drive.

**8.6 When it is written, and what a drive costs.** `Store.save(userId, { nextTeam = team })` at each
of the two edges. **0 network calls**, by `Store.save`'s contract (ProfileStore's own auto-save and
`EndSession` do the writing). The local figure, for a spec to assert through `store.calls()`:
**`save` rises by exactly `2 × N`** over one complete drive of `N` players with open sessions (one at
edge 1, one at edge 2), on top of `payDrive`'s existing `N`, **plus one per mid-drive `assignTeams`**
(a join or a `team` request).

**8.7 The view gains a read and ONE named write.** `owedTeams()` and `noteNextTeams(teams)`; §4.4
names what the drive still cannot do. The write takes the VALUE, computed by the pure
`Roster.invert` at the caller, so this owner derives nothing — the discipline task 178 forced onto
`Store.save` after a purchase started counting as a completed hunt.

**8.8 A drive with ONE player.** A solo player is `Shooters` on drive 1 (`ODD_PLAYER_TEAM`,
`MIN_PLAYERS = 1`) and `Drivers` on drive 2. **A solo beater drive — zero hunters — IS the accepted
behaviour** and it is NOT what decision 4's guard is about: that guard is `Roster.assign`'s
`|Drivers − Shooters| <= 1` check and nothing else, and for one player it reads `|1 − 0| = 1` and
passes. `stats().emptyTeamDrives` already counts such a drive and **nothing more is wanted.** One
consequence to expect in the live run rather than be surprised by: as the only beater he can end
drive 2 early by crossing the hunters' line (`Phase.beatersThrough`, `END_ON_BEATERS_CROSS`).

---

## 9. Hazards

| # | Hazard | What closes it | What says it stayed closed |
|---|---|---|---|
| 1 | **A stale mirror after an assignment nobody thought of** (decision 10, and the root cause of task 214 in this code path) | The write is **co-located with `Body.setTeam` inside `applyAssignTeams`**, the one place a team is written — so a join, a `/beater` request and a second placement all mirror with no new call site. It is co-location, not structural enforcement, and the second half is: edge 2 rewrites the record WHOLE from `state.assignment` once per drive, so drift self-heals within one drive | `match_teams.spec` / `economy.spec`: the number of rows written equals the number of rows assigned. The live Forest Test probe reads `Economy.owedTeams()` against `Player.Team` for every player |
| 2 | **Two players sharing one owed table reference** (`Store.TEMPLATE`'s hazard 1, the frozen-table lesson) | Structural: `nextTeam`'s default is a **string**, so `Store.read`'s clone branch (`type(value) == "table"`) is never entered for it. `owedTeams()` hands out ONE frozen table shared by every reader, **rebuilt and never mutated** on a write — the `Economy.balances()` idiom | `economy_store.spec`: the existing hazard-1 case, plus `type(Store.TEMPLATE.nextTeam) == "string"`. `economy.spec`: writing into the table `owedTeams()` returned throws |
| 3 | **A turn written for a player whose session was refused or lost mid-drive** | `noteNextTeams` writes only for `sessions[userId] ~= nil`, and `Store.save` answers `false` with no session anyway. `setOnLost` drops the row and invalidates the memo, so he reads as *no turn stored* and his key on disk is untouched | `stats().nextTeamSkippedNoProfile`; `economy.spec` drives the refused branch through `Store.memory{ refuse }` and the lost branch through `loseSession` |
| 4 | **`DHForestStartRole` / `/beater` becoming a sticky preference** (decision 7) | The switch reaches the drive through `Match.requestTeam` → the `team` branch, which emits `assignTeams` → edge 1 writes *the role he is actually playing*. At that drive's `Scoring` the record flips. So the switch wins for ITS drive and the next drive rotates off it, and **the switch cannot be used to cheat back to hunter permanently either** | `match_phase.spec`: a `team` event overrides an opposite `owed` for that drive; the record then flips |
| 5 | **The cost of the per-event read while 214a(a) is open** | `owedTeams()` is **memoised and frozen**: one table read, no clone, no freeze per call. The memo is rebuilt only on a write that changes a row (≤ 2 per drive, plus one per join / leave / `team` request / session change). At the ~15× `MATCH_STEP_HZ` that 214a(a) produces, that is ~60 reads of one reference per second | `economy.spec`: two consecutive `owedTeams()` calls return the SAME table (identity) while nothing writes, and a different one after a write that changed a row |
| 6 | **The record overwritten by the pay-out or by a purchase** | `payDrive` and `purchase` name their fields explicitly and do not name `nextTeam`. `Store.save` writes exactly the fields it is told and derives nothing (task 178, hazard 2) | `economy.spec`: a purchase and a pay-out leave `peek(userId).nextTeam` unchanged |
| 7 | **A race on the profile load putting a rejoiner on the wrong side** | Accepted, bounded and arithmetically safe: edge 1 skips him (no session), so the stored turn is NOT overwritten, and edge 2's `other(what he played)` restores the same value (§5.4). **One drive on the wrong side, never a corrupted record** | `economy.spec`: `noteNextTeams` for a userId with no session writes nothing; the stored value is still there after the next `load` |
| 8 | **A corrupted or foreign value in the key** (`"hunter"`, a number, a table, a stale `""`) | `Economy.teamFromRecord` is the one validator and answers `nil`, which means *no turn stored* — the brand-new-player path, which already has to work | `economy.spec`: a table of six bad values, each answering nil |
| 9 | **The inversion asymmetry** — `previousFrom` inverts, `joinTeam` does not | One sentence in both headers (§4.1), and a spec that asserts both directions on the same owed value | `match_roster.spec`: `previousFrom(nil, { [7] = "Drivers" })[7] == "Shooters"` AND `joinTeam(equalCounts, "Drivers", config) == "Drivers"` |
| 10 | **A FALSE-PASS PATH, and it is the sharpest thing in this design.** *"Two drives in a row: hunter then beater"* is **already true today** from the in-memory swap. A frame pair of two start cards proves NOTHING about this task | The only evidence of the feature is a **release-and-reload round trip**: `peek` before, `release`, `load`, `peek` after. Named in §11 as the one claim that must not be substituted | `economy_store.spec`'s round-trip case; the live probe's `Store.peek` read, not the frames |
| 11 | **A second false-PASS path: the harness can never run the ON branch.** `test` and `test2` both REFUSE to start while a `DHFlag_` override is set, so no harness run can ever have `COINS` on | Both branches are reachable **by parameter** — `Economy.start({ enabled = true, store = Store.memory() })` — which is `docs/design/feature-flags.md`'s own rule. Every ON claim in the suite is driven that way, and `zz_drive_boundary` keeps its `if Economy.isEnabled()` conditional rather than pretending | §11.6: the production-path ON claim is the live Forest Test run and is labelled as such |
| 12 | **The record outliving the game** — a player away for a month returns owed whatever he was owed | Accepted: that is the feature. `Store.read`'s keep-unknown half also means a rollback to a build without this task leaves the field intact | stated |

---

## 10. Numeric targets, each one checkable

| Target | Value | How it is checked |
|---|---|---|
| New DataStore names | **0** | `Economy.CONFIG.STORE_NAME` unchanged, asserted in `economy_store.spec` today |
| New keys per player | **0** (one field on the one key) | `Store.keyFor` unchanged |
| New profile fields | **1** (`nextTeam`), additive, default `""` = no turn | `economy_store.spec`: an old key round-trips unchanged |
| Network calls added per drive | **0** | `Store.save`'s contract; `store.calls()` has no network counter because there is no network call |
| Local `save` calls added per complete drive of N players with sessions | **exactly 2N**, plus 1 per mid-drive `assignTeams` | `store.calls().save` in `economy.spec` |
| Extra work per event in `dispatch` | **1 table read, 0 clones, 0 freezes** | `economy.spec`: two reads return the same table by identity |
| Memo rebuilds per drive | **≤ 2**, plus one per join / leave / `team` request / session change | the identity assertion above, driven across a simulated drive |
| Teams differ by at most | **1 player**, every roster size 2..16 | `match_roster.spec`'s existing sweep, **unedited** |
| A turn the balance rule could not honour | **not consumed** | `match_roster.spec` (the split) + `economy.spec` (the record after the flip) |
| Roles alternate over two completed drives for one player | hunter → beater | `match_phase.spec`; live, two drives in the Forest Test. **NOT evidence of this task on its own** (hazard 10) |
| A rejoin keeps the turn | the same value before `release` and after `load` | `economy_store.spec`'s round trip; live through the owner's own seam. **THIS is the feature's evidence** |
| Behaviour with no economy, or with `COINS` off | **identical to today, value for value** | §7's three assertions |
| New remotes / wire fields / drawn things | **0 / 0 / 0** | nothing is added to `Drive`'s remotes or to `MatchSnapshot` |
| New flag rows | **0** (`Flags.MAX_FLAGS` stays 14 with 14 rows) | `flags.spec` |
| New clocks | **0** | no `Heartbeat`, no `task.delay`, no `SetConstant` |
| New `Phase.Effect` kinds / `Phase.State` fields | **0 / 0** | `match_phase.spec`'s effect-list cases |
| New `Phase.Event` fields | **1** (`owed`) | the type |
| New spec files | **0** | §11 |

---

## 11. How it is tested

**No new spec file.** Every claim lands inside an existing file's stated subject, and a new file
would have to be registered in `SCOPE_SPECS` (rule G, task 198) for no new subject. What each file
buys, and — as important — what it CANNOT buy:

### 11.1 `tests/server/match_roster.spec.luau` — PURE, no world, no store (scope `match`)

* `Roster.other` both ways; `other(nil)` and `other("hunter")` are nil.
* `previousFrom(prev, nil)` and `previousFrom(prev, {})` return `prev` **by identity**;
  `previousFrom(nil, nil)` is nil.
* `previousFrom(nil, { [7] = "Drivers" })` is `{ [7] = "Shooters" }`, and
  `Roster.assign({ 7 }, that, config)` gives `{ [7] = "Drivers" }` — **the inversion, end to end.**
* `previousFrom` writes neither input (both may be frozen).
* `invert` is a new table with every row flipped and the input untouched.
* `joinTeam`: on a tie the owed team wins; off a tie `smallerTeam` wins; `owed = nil` is
  `smallerTeam` exactly.
* **The balance override**: owed `"Drivers"` for all N, N ≥ 4 → the plain-split fallback → teams
  equal to within 1.
* The existing 2..16 sweep, **unedited**, plus the §7 identity line.

### 11.2 `tests/server/match_phase.spec.luau` — PURE (scopes `match`, `lobby`)

* **The stored turn, ISOLATED from the in-memory swap**: `previousAssignment = nil`, `event.owed`
  set → every owed player gets his owed team. This is the only place the two can be told apart, and
  it is why this claim is here and not on the live drive (§11.6).
* `event.owed` absent → the file's existing `enterAssigning` cases are the regression.
* A mid-drive `join` in `Running`: equal sides → the owed team; unequal → the smaller team.
* A `team` event (the Studio switch) beats an opposite `owed` for that drive (hazard 4).

### 11.3 `tests/server/economy.spec.luau` — the owner against `Store.memory` (scopes `economy`, `shop`)

* `teamFromRecord` over six bad values and the two good ones.
* `load` installs the row from a seeded profile; `owedTeams()[7] == "Drivers"`.
* `owedTeams()` is frozen; writing into it throws; two reads return the same table by identity; a
  write that changes a row returns a different one.
* `noteNextTeams` writes, returns the count, reaches `store.peek`, and raises `save` by exactly one
  per row.
* `noteNextTeams` for a userId with no session: nothing written, `nextTeamSkippedNoProfile == 1`.
* `noteNextTeams` with a value the validator refuses: nothing written, `nextTeamRefused == 1`.
* `noteNextTeams` does not retain the caller's table (mutate it afterwards; `owedTeams()` unchanged).
* `release`, `loseSession`, `closeAll` and `stop` each drop the row and invalidate the memo.
* **Flag off** (`Economy.start({ enabled = false })`): `owedTeams()` empty and frozen,
  `noteNextTeams` writes nothing, no session, no store.
* `payDrive` and `purchase` leave `nextTeam` alone (hazard 6).
* **The view's exact key set** — seven names and no eighth — so a setter cannot be slipped onto it
  later without a failing case.

### 11.4 `tests/server/economy_store.spec.luau` — the record (scopes `economy`, `shop`)

* `Store.TEMPLATE.nextTeam == ""`, `type` is `"string"`, the template still frozen.
* `Store.read` fills it when absent, keeps it when present, and the keep-unknown case is unchanged.
* **THE ROUND TRIP, and it is the feature**: `load(7)` → `save(7, { nextTeam = "Drivers" })` →
  `peek(7).nextTeam == "Drivers"` → `release(7)` → `load(7)` → still `"Drivers"`. The memory store's
  `saved` closure outlives a release, so this is a real round trip and not a simulation.
* The number-shorthand seed still works and fills `""`.

### 11.5 `tests/server/match_live.spec.luau` and `tests/server/match_teams.spec.luau` — unchanged in subject

Both assert on the **production** `Match` that `MatchBoot` started, so neither can inject an economy.
With `COINS` off they prove exactly one thing about this task and it is worth having: the real
session's teams came from the roster alone and nothing about this change moved them.
`match_live.spec` is added to `SCOPE_SPECS["economy"]` (§11.7) so a future `Economy`-only change
still plays it.

### 11.6 `tests/server/zz_drive_boundary.spec.luau` — the real boundary (scope `match`)

Two cases in the shape this file already uses for the pay-out, and it does **not** restart `Economy`
(restarting the real owner mid-suite while production `Match` holds its view would drop the live
player's balance):

```luau
if Economy.isEnabled() then
    -- after the Scoring edge, every row's record is the inverse of the team he played
else
    -- COINS is born OFF, so the honest assertion is that owedTeams() is EMPTY and the
    -- assignment came from the roster alone: "off is the game before this task", at the one
    -- boundary that could break it.
end
```

**What the harness therefore cannot prove, stated rather than papered over:** the two production
call sites (§4.3) are exercised in a harness run only through the OFF branch, because no harness run
can have `COINS` on (hazard 11). Their ON evidence is §11.8's live run.

### 11.7 Harness and scope

* **No new spec file, so no new `SCOPE_SPECS` key and no new `BLAST_RADIUS` prefix.** The changed
  paths already map: `src/server/Match/` and `src/shared/Drive/` → `match`, `src/server/Economy/` →
  `economy`.
* **One line added**: `tests/server/match_live.spec.luau` joins `SCOPE_SPECS["economy"]`. This task
  is what creates the dependency in that direction — `Economy.owedTeams` is now read by the drive —
  and the dual-membership idiom (`zz_horn`, `boar_hit`, `boar_shot`, `shoot_boar`) is the table's
  own. The cost: `tools/studio_mcp.py` maps to `all`, so a `--scope auto` review run becomes a full
  one. With `src/server/Match/` in the change the scoped set was nearly the whole server suite
  anyway.
* **Two players.** `src/server/Match/` and `src/shared/Drive/` are both in `TWO_PLAYER_PATHS`, so
  `[harness2]` is required for the PR to `main`. The Builder stops at `NEEDS TEST2 217 <sha>` and
  the **Director** runs it (brief §6).
* **Harness input (`tests/client/input_scenarios.txt`): none.** Nothing here is typed, clicked or
  aimed. `/beater` is a server-side `Chatted` handler in the Forest Test and the harness cannot
  drive chat (TASKS.md tasks 6–7).
* **Client specs: none changed.** Nothing goes on the wire and nothing is drawn. The regression is
  `tests/client/match_client.spec.luau`'s existing "no economy number on the wire" pattern assertion
  (named in economy.md §10.1): this task adds no snapshot field, so that case is what says so.

### 11.8 The live run, and what a frame can and cannot show (rule 5)

In the Forest Test (place `130094961655666`), through the literal steps of brief §6 (Learning Agent
L-095): `lobby-go.luau` first — a player starts UNENROLLED at the lodge, so without it there is no
drive to be a hunter in.

| Evidence | What it proves | What it does NOT prove |
|---|---|---|
| A frame of the start card at drive 1 and at drive 2, at the player's own eye height (rule F), each showing the HUD role badge | the rotation is visible to Karen, and the right kit is in his hands (gun vs horn, hat vs vest) | **nothing about this task** — the in-memory swap already does this (hazard 10) |
| `ftplay.py server <probe>.luau` reading `Economy.owedTeams()` and `Economy.Store` `peek` at each edge | the two call sites fire, with the right values, on the real production path with `COINS` on | — |
| A **release-and-reload** through the owner's own seam (`Economy.release(userId)` then `Economy.load(player)`), then a third drive | **the feature**: the turn survived the round trip | that a LIVE DataStore key kept it — Studio is `Store.memory` by construction (§13 item 1) |
| `bash smoke.sh 80` → SMOKE PASS (rule A) | nothing regressed | — |

Karen's attributes (`DHFlag_COINS`, `DHFlag_DRIVE_BOTS`, `DHForestStartRole`, `DHFlag_SHOP`) are
captured first and **read back** after restoring, before stopping.

---

## 12. External sources

### 12.1 ioquake3 — `code/game/g_team.c`, `PickTeam` / `TeamCount` — **the ordering adopted**

<https://github.com/ioquake/ioq3> — **GPL-2.0, maintained** (active commits). This repo already
borrows its `CalculateRanks` / `RANK_TIED_FLAG` rule in `src/shared/Drive/Rank.luau`.
`PickTeam` counts both sides and answers the smaller; a *requested* team is honoured by the layer
above only when it does not unbalance the match.
**Good:** the preference is advisory and the count is authoritative — exactly Karen's ordering, equal
teams first and rotation second, and exactly what `Roster.joinTeam` and the plain-split fallback do.
**Bad for us:** it has no notion of a turn that persists (a Q3 player's team dies with his client), so
only the ORDERING is borrowed and nothing is copied.

### 12.2 Xonotic — `qcsrc/server/teamplay.qc`, `g_balance_teams_prevent_imbalance`

<https://gitlab.com/xonotic/xonotic-data.pk3dir> — **GPL-2.0, maintained**. Its documented rule is
the same one as a cvar: a team change, including the auto-balance shuffle *between rounds*, is
refused when it would create an imbalance.
**Good:** it names the per-round case explicitly — sides are re-decided every round and balance is
checked at that moment rather than carried forward, which is why `previousFrom` is a SUGGESTION
re-checked by `assign` every drive and not a state the machine carries.
**Bad for us:** the shuffle is RANDOM, which Karen's rule is not, and it is QuakeC.
**Honesty (rule 8):** the source file was not read; the rule is taken from its public cvar
documentation and is cited as corroboration of the shape, not as a thing copied.

### 12.3 ProfileStore 1.0.3 — MadStudioRoblox — **the save layer, already adopted**

<https://github.com/MadStudioRoblox/ProfileStore> — **Apache-2.0, maintained**; API docs
<https://madstudioroblox.github.io/ProfileStore/api/>. Pinned through Wally
(`lm-loleris/profilestore@1.0.3`) and already the only save layer in this repo.
**Good:** session locking, a server-local copy, periodic saving and `EndSession` are all its job, so
a new field costs **zero** DataStore requests — `Store.save` writes the local table and nothing else.
**Bad:** nothing new; the one hazard is ours, and it is that `Store.TEMPLATE` is frozen and
enumerated, which §3.3 and §6 answer.

### 12.4 Roblox Creator Docs — data stores, best practices

<https://create.roblox.com/docs/cloud-services/data-stores/best-practices> — **current, no licence
granted.** *"Load a player's data at the start of a session and keep a server-local copy for
gameplay. Update the local copy instead of sending a data store request for every change."*
**Good:** the direct authority for "extend the existing record, do not open a second store", which is
also the Director's instruction (brief decision 2).
**Bad:** it says nothing about game rules; it is a constraint, not a pattern.

### 12.5 Roblox Creator Docs — `Teams`, `Team`, `Player.Team`

<https://create.roblox.com/docs/reference/engine/classes/Team> — **current, no licence granted.**
Already source A of `docs/design/drive.md` §16. Relevant here only for what it forbids: `Player.Team`
replicates free and a client cannot write it, and `AutoAssignable = false` is what stops Roblox
becoming a second writer. **This design adds no second writer**, which is the reason the record is a
mirror of `state.assignment` and never the thing a team is read from.

### 12.6 Borrowed from inside this repo (rule 2 applies to internal patterns too)

* **`aliveBoars` on the event** (`Match.dispatch`): how a world fact reaches the pure machine.
* **`payDrive` on the `Scoring` edge, before `applyEffects`** (task 170): where a per-drive call into
  the persistence owner goes — the POSITION is borrowed, the REASON here is its own (§4.3).
* **`Economy.view()`** (tasks 170, 178): the read-only-plus-named-events view a world is handed.
* **`Economy.balances()`** (task 170): a frozen copy handed out, so a reader cannot write what it was
  given — `owedTeams()` is that with a memo.
* **`Store.read`'s fill-missing / keep-unknown** (task 170): how an additive field survives both an
  older build and a rollback.
* **`Store.save` derives nothing** (task 178, hazard 2): why `noteNextTeams` is told the value.

### 12.7 Invented, with the reason rule 2 requires

`Roster.other`, `Roster.invert`, `Roster.previousFrom` and `Roster.joinTeam` are ours. No library has
them; they are a few lines of pure Luau each. The alternative — a second assignment algorithm
honouring preferences up to a capacity — would replace a function the suite pins at every roster size
from 2 to 16, which is a bigger change than the feature itself (§8.4).

---

## 13. What I could not verify (rule 8)

1. **Whether a LIVE DataStore round trip keeps the field.** Studio takes `Store.memory` by
   construction (`Economy.storeKindFor`, and the `require` of ProfileStore lives inside `Store.live`'s
   body), so nothing in a playtest or a harness run touches a real key. The round trip is proved
   against the memory store and against `Store.read`'s contract; the live path is the same
   `Store.save` call the balance already uses, and has the same evidence the balance has.
2. **Whether ProfileStore reconciles a new template key on an existing profile.** Not verified by
   this repo (economy.md §14) and deliberately made irrelevant: `Store.read`'s fill-missing half is
   twelve lines of our own pure code and runs on every load.
3. **Xonotic's source** (§12.2): cited from its cvar documentation, not read.
4. **Whether Karen reads "the turn was not consumed" as correct** when the balance rule overrules
   rotation, and whether she reads the mid-drive-join tie rule as correct. She has not seen either.
5. **The size of the profile-load race in practice** (§5.4). The arithmetic says it costs one drive
   and never the record; the actual window between `PlayerAdded` and the owed row appearing has not
   been measured. The Builder should print it once in the live run.
6. **Nothing here was run.** This is a read-only design session: the evidence is the symbols cited,
   `.agent-evidence/`, and the two existing designs.

---

## 14. What this design deliberately leaves alone

1. **TASKS.md 214a(a)** — the Forest Test sweep offering a refused ask on every Heartbeat, stepping
   the match at ~15× `MATCH_STEP_HZ`. **Not fixed.** It is designed AROUND: the per-event read is one
   table read of a memo with no clone, so it is cheap enough to be stepped at that rate (§9 hazard 5).
2. **TASKS.md 214b** — the role ask as an INPUT to `Roster.assign`, one placement instead of two.
   **Not built.** The seam is shaped for it: `Phase.Event.owed` is exactly the per-event injected
   reader 214b prescribes, and a one-shot role ask can be merged into that table at the fill site in
   `dispatch` with no change to `Roster`, `Phase` or the record.
3. **TASKS.md 214a(b)** — `honour` swallowing the `hunter` direction of the start switch in the
   lobby. Untouched.
4. **Flipping `COINS`'s default**, bumping `Flags.MAX_FLAGS`, retiring any flag row. All the
   Director's.
5. **Which stand, which lane, which layout** a player gets — `docs/design/drive-layouts.md`.
6. **Money, licences, the shop, outfits, dogs, scoring, the boar, the weapon, the camera, the Hud,
   the lobby's geometry.** None is touched.
7. **A migration of existing saved keys.** The field is additive; a profile without it means *no turn
   stored*, which is the brand-new-player case and already has to work.
8. **Renaming `Drivers` / `Shooters` to Karen's words.** That is `docs/design/drive.md` §17 item 5's
   own task; this design spends one frozen table (`Drive.TEAMS`) to avoid adding a sixth copy of the
   two literals in the meantime.
9. **Telling the player whose turn is next** on the start card or the HUD. Not built; §15 item 3.

---

## 15. Open decisions

**None of them blocks building.** Every one is one line of data or one predicate, and this design
states the value it ships with.

### Karen (feel / design)

1. **With `COINS` off, the turn is forgotten when the server empties.** Her Forest Test has
   `DHFlag_COINS = true` so it is true where she plays, but a public server would not remember until
   the default flips. Does she accept shipping the rotation before the memory?
2. **A man can be a hunter twice in a row when the sides demand it** (§5.3). The turn is not lost —
   he is first in line next drive — but the drive he was owed did not happen. This is the Director's
   decision as written; she has not seen it.
3. **Should the results scene or the start card say whose turn is next** (*"NEXT DRIVE: BEATER"*)?
   Not built, and it is the obvious thing to want the first time the rotation surprises somebody. One
   string and one snapshot field, so it is a task of its own and not a redesign.
4. **Does `/beater` winning for one drive and then rotating off it feel right** (decision 7, hazard
   4)? It is what she asked for twice over, read together; she has not seen the two rules interact.

### Director (scope)

1. **When `COINS`'s default flips to `true`.** It is now the switch for TWO features, not one, and
   it is the only thing that makes Karen's *"remembered across logout/login"* true on a live server.
   `expires` forces the question anyway; this design raises its weight and does not touch it.
2. **Should a mid-drive joiner who cannot be honoured wait for the next `Assigning` instead?**
   (§8.5.) It would honour every turn at the cost of making a man who walked onto a truck pad stand
   out a drive. Shipped as "the smaller team wins", which is drive.md §1.2's own rule.
3. **`SCOPE_SPECS["economy"]` gains `tests/server/match_live.spec.luau`** (§11.7). One line in
   `tools/studio_mcp.py`, which makes a `--scope auto` review run resolve to `all`. The Director may
   veto it; the dependency it covers exists either way.
4. **214a(a) and 214b stay open.** This task shapes the seam for 214b and fixes neither (§14).

---

## 16. THE DELTA TABLE: what this design supersedes in the designs that already exist

`tools/agents.py` writes exactly `docs/design/role-rotation.md` and
`reviews/task-217/ARCH_RESULT.md`. It cannot edit a second design, so **this table is the only record
of these deltas** and each row is one `TASKS.md` entry for the Builder to queue (L-071: deltas from
tasks 191, 213 and 214 sat unqueued for days).

### `docs/design/economy.md`

| § | What it says now | What it says after this task |
|---|---|---|
| **9** | `Store.TEMPLATE` is five keys (`schema`, `coins`, `coinsEarnedTotal`, `drivesPaid`, `owned`) | six: `nextTeam = ""`, with §3.1's table. Store name, key and `schema` unchanged; the "adding a field later is additive" paragraph now has its second instance and may cite it |
| **4.4** | the printed `Economy` list and `View` type. **Already stale**: the `View` shows three functions and the code has five (`enabled`, `ownedOf`), and `World` is missing `testGrant` | the `View` is SEVEN (`owedTeams`, `noteNextTeams`); `Economy` gains `owedTeams()`, `noteNextTeams(teams)` and the pure `teamFromRecord(value)`; `stats()` gains three counters. Fix the pre-existing staleness in the same edit |
| **4.5** | *"`Match` gains no state, no table and no clock. Three edits"*, and *"No new `Match` effect kind, **no `Phase` change**"* | **FIVE edits** (the per-event `owed` fill in `dispatch`, the `noteNextTeams` call in `applyAssignTeams`, the second call on the `Scoring` edge), and the closing sentence is now **FALSE**: `Phase` gains one `Event` field, `enterAssigning` gains a parameter and the `join` branch changes. Still no new effect kind, still no state, no table and no clock |
| **10** | the seams table | four new rows: `Roster.previousFrom` / `other` / `invert` / `joinTeam` (pure); `Economy.owedTeams` / `noteNextTeams` against `Store.memory`; `Economy.teamFromRecord` (pure); and `Store.memory`'s `peek` across a `release` + `load` — **the round trip, which is the feature's only evidence** |
| **10.1** | six spec files | the same six: `match_roster`, `match_phase`, `economy`, `economy_store` gain cases; `zz_drive_boundary` gains the conditional pair; `match_live` and `match_teams` are unchanged in subject. **No new file.** `SCOPE_SPECS["economy"]` gains `tests/server/match_live.spec.luau` |
| **11** | eleven hazards | six more — §9 rows 1, 2, 3, 7, 10, 11 (the stale mirror, the shared table, the lost session, the load race, and the two false-PASS paths) |
| **12** | the Changed table | add `src/server/Match/Roster.luau`, `src/server/Match/Phase.luau`, `src/server/Match/init.luau`, `src/server/Economy/init.luau`, `src/server/Economy/Store.luau`, `src/shared/Drive/init.luau`, `tools/studio_mcp.py`, and the five spec files. The `GAME_DESIGN.md` Economy owner row gains *"and the role a player is owed at his next drive"* |
| **13** | nine open decisions | item 6 (`COINS`'s default) is **promoted**: it now gates two features. Add §15's four Karen items and four Director items |

### `docs/design/drive.md`

| § | What it says now | What it says after this task |
|---|---|---|
| **5.2** | `Roster` is three functions and four numbered rules | **seven functions** (§4.1) and a fifth rule: *a stored turn, when one is supplied, is folded in as a synthetic `previous`, and `assign`'s balance check still wins — a turn it could not honour is not consumed* |
| **5.3** | *"`Roster.assign` → `Body.setTeam` for everybody → `Body.place` → …"* | *"`Roster.previousFrom(state.previousAssignment, event.owed)` → `Roster.assign` → `Body.setTeam` **and the record mirrored to the persistence owner** → …"*. **ALSO already stale** and to be corrected in the same edit: the real order is `clearScene`, `free`, `unassign`, `assignTeams`, `clearBoars`, `hold`, `placePlayers`, `refreshArming` (tasks 158, 159, 177), and `hold` before `placePlayers` is a measurement |
| **4.2** | the `Event` type | gains `owed: { [number]: TeamName }?`, **filled on EVERY event** by the owner, the same rule and the same reason the paragraph below it already gives for `aliveBoars`. **ALSO already stale**: the printed `kind` union lacks `"team"` (task 157) and `"dismiss"` (task 177) |
| **9.2** | the `Match` interface and `World` | the drive now makes two calls into `world.economy` (`owedTeams`, `noteNextTeams`). **ALSO already stale**: the printed `World` lacks `economy`, `bots`, `placement`, `config`, `enrol` and `groundAt` |
| **3.4 / 9.1** | the one shared frozen table | `src/shared/Drive` gains `Drive.TEAMS`, the frozen runtime half of the `Drive.TeamName` type that already lives there — the ONE membership test, so no file needs a sixth copy of the two strings. **Nothing new on the wire** |

### `docs/design/forest-drive.md`

| § | What it says now | What it says after this task |
|---|---|---|
| **5.2 / 5.3** | the `DHForestStartRole` / `/beater` request is a one-shot that *"only decides the parity of the first drive"* | **No rule change — decision 7 is upheld and the switch is still not a sticky preference.** One sentence to add: *the switch moves THIS drive, the record then mirrors the role he actually played, and the next drive rotates off it — so the switch cannot become a permanent preference and a stored turn cannot swallow the switch.* Stack it on the staleness already queued as TASKS.md **214a(e)** (§5.2 item 5 and §5.3's table still say the request is replayed on entering `Running`, which task 214 deleted) |

# Design: bots — the drive is always 4 hunters and 4 beaters

Task 161. Written from `reviews/task-161/BRIEF.md` and `docs/research/2026-10-12-bots.md`, which this
document does not re-decide: the brief's §1 decisions and the note's §3 pattern are inputs. What this
document adds is the two owner rulings the brief asks for (§2.1, §2.2), the interface symbol by
symbol, and the hazards the note did not reach.

It is also a **delta** to `docs/design/drive.md` (§3.2, §3.5, §5.3, §9.2, §11), to
`docs/design/forest-drive.md` (§4.3, §6, §9.3) and to `GAME_DESIGN.md`'s *System owners* table. §18
lists every edit, so nothing is discovered at merge time.

---

## 1. What it must do

1. **Fill.** A drive wants `TARGET.hunters` hunters and `TARGET.beaters` beaters. Every slot no real
   player fills is filled by a bot, **per side**; a bot gives the slot back the moment a real player
   takes it. Karen, 2026-10-11: *"Let's make 4 hunters 4 beaters"*.
2. **Bot beaters are visible R15 rigs** in the beater outfit, standing abreast on the drive's own
   beater start through the countdown, walking down a per-bot lane to the hunters' line at beater
   pace when the drive starts, blowing the real horn now and then.
3. **Bot hunters are visible R15 rigs** in the hunter outfit, standing on the stands no real hunter
   has, facing the drive. **They do not shoot** (brief §1.6; a shooting bot is TASKS.md 161a).
4. **A bot beater's walk and horn push boars through the doors a real beater's already go through** —
   the world's threat list with `kind = "driver"` and no `phantom` mark, and `Weapon.Horn.Blown`.
   No second push source, no second radius, no second spook rule.
5. **Bot beaters count as beaters for the end of a drive.** §5.2 rules on this and gives the
   arithmetic.
6. **They are in the results scene**, standing in the ring after the players.
7. **Built and destroyed every drive.** No pool (note §2.2's rejected last line).
8. **A switch turns the whole thing off and OFF is today's game bit for bit** — including the drive's
   ending, the Forest Test's phantom beaters, and every number in every spec.

## 2. What it must not do

Each line is a thing a reader could reasonably expect and must not get.

* **A bot is never a player.** No `Player` object, no userId, no `Team` membership, no row in
  `state.participants`, no row in `Score`, no DataStore, no `Match.forget`. The mechanism is
  structural, not a filter: a bot's id is a non-numeric string (`"bot-beater-1"`), and
  `Match.playerDrivers` (`tonumber(driver.id)`), `Match.pushCreditable`
  (`type(userId) == "number"`) and `Phase.participantIds` (reads `state.participants`, which only
  `watchPlayer` writes) each already refuse it. **No new "is this a bot" predicate is written
  anywhere** (brief §1.3).
* **A bot never starts a drive.** `Phase.waitingFor` compares `Phase.participantCount` against
  `MIN_PLAYERS`, and `participants` holds players only — so an empty server cannot run drives for
  ever. Said out loud because it is the first thing a reader fears about a filler mechanism.
* **It does not move, dress, hold, tie or respawn a PLAYER's character.** `Match.Body` keeps that
  whole job (§3).
* **It does not decide a phase**, a score, a penalty, a point, a boar spawn, or when a drive ends.
  It answers counts and positions; `Phase` still decides.
* **It draws no UI and changes no wire.** `MatchSnapshot` gains no field. A bot is a body in the
  world, not a row on a screen (and a row would be a fake player in Karen's results table — the one
  thing ioquake3's own bots do that she must not get, note §2.1).
* **No `.rbxm`, no `.rbxmx`, no script-like instance created in Studio or at run time.** The rig
  comes from the engine's own builder (§11); `Instance.new("Script")` cannot carry source at run
  time and is not attempted.
* **No pool, no rig carried across a drive boundary**, and no state in this system that outlives
  `Bots.clear()`.
* **No bot shoots, and no bot is protected by the safety rule** in this task. Declared, not
  discovered: §17.3 and TASKS.md 161a.

---

## 3. Owner — one writer each, named

The note's §6 table is **adopted** and extended. Two rows are new rulings, and one existing
ownership sentence has to be **restated** (not quietly broken) — see §3.2.

| Thing | Owner | Where |
|---|---|---|
| **how many bots there are** | `Bots.Fill.counts` — pure, called by the drive at its own boundary | `src/server/Bots/Fill.luau` |
| **which lane / which slot a bot takes, and its next step** | `Bots.Lane` — pure | `src/server/Bots/Lane.luau` |
| **a bot rig's Instances, and `Workspace.DriveBots`** | `Bots.Rig` — the only writer | `src/server/Bots/Rig.luau` |
| **a bot's lifetime, its movement, its horn rhythm, its clock** | `Bots` (the owner module) | `src/server/Bots/init.luau` → `ServerScriptService.Bots` |
| **what a bot WEARS** | `Match.Body`, unchanged — `Body.dress(rig, team, config)` already takes a **Model** | `src/server/Match/Body.luau` |
| **the horn Tool a bot carries, its voice, its cooldown, its blast signal** | `Weapon.Horn`, unchanged in owner, two new entry points (§9) | `src/server/Weapon/Horn.luau` |
| **WHERE a bot stands at the start, and in the results ring** | the **drive** answers (through `world.placement` / `Scene.ringLayout`); `Bots.Rig` writes it. `Bots` never reads a marker | `src/server/Match/init.luau` + `Bots/Rig.luau` |
| **whether a drive has ended** | `Phase.beatersThrough`, unchanged — it still only compares two numbers | `src/server/Match/Phase.luau` |
| **what a boar can perceive** | the world's threat list, unchanged in shape — a bot is one more entry (§10) | `Match.boarThreats` / `ForestTest.boarThreats` |
| **whether bots exist at all** | `Match.CONFIG.BOTS.ENABLED`, one flag read at one boundary | `src/server/Match/init.luau` |
| **wiring the three systems together** | the two composition roots, which own nothing | `MatchBoot.server.luau`, `ForestTestBoot.server.luau` |

### 3.1 `Bots` is its own owner, NOT a module under `src/server/Match/`

Ruled, with the reason, because `Match.Body` and `Match.Scene` are precedents for "a Match submodule
that writes Instances" and a reader will ask why this is different:

* **It needs its own clock.** `STEP_HZ = 5` against the drive's `MATCH_STEP_HZ = 4`. Today **no**
  module under `src/server/Match/` connects anything — `Match/init.luau` is the only connector and
  `Phase`, `Roster`, `Score`, `Penalty` are pure while `Body` and `Scene` are passive writers the
  owner calls. A self-stepping child would break the shape that file's own header states.
* **`Match`'s header says it writes "nothing drawn"**, and eight rigs are drawn. `Match.Scene` is the
  one exception and it holds no clock and is driven by an effect.
* **The build can yield.** `Players:CreateHumanoidModelFromDescription` is documented to load assets
  (§11.5), and a yield inside `Match:step` is the hazard `Phase`'s own ordering comment was paid for
  twice. A separate owner with its own stepper puts the yield where nothing is waiting on it.
* It gives the change its own blast-radius scope (§15) and keeps the `src/server/Match/` diff small.

### 3.2 One ownership sentence must be RESTATED, not broken

`src/server/Match/Body.luau`'s header claims to be *"the only writer of a player's TEAM and of where
their character stands"*, and task 158's comment claims **`Body` is the only writer of `WalkSpeed` in
`src/` (grepped)**. `Bots.Rig` writes a bot rig's `WalkSpeed`, `Anchored` and `CFrame`.

**The boundary is the PLAYER, and the Builder must say so in `Body.luau`'s own header** (the
task-151-round-1 rule: do not leave the older sentence standing):

* `Match.Body` — the only writer of a **Player's** character: its team, its position, its freeze, its
  clothes, and the one `held` table keyed by **userId**.
* `Bots.Rig` — the only writer of a **bot rig's** Instances. It never touches `Body`'s `held` table
  (a bot has no userId to key it with) and never calls `Body.place`, `Body.hold`, `Body.stand`,
  `Body.tie` or `Body.dressWhenLoaded`.
* The **one** thing they share is the outfit, and it is `Body`'s: `Bots.Rig` calls
  `Body.dress(rig, team, config)` through an injected seam (§7). There is no second dressing path and
  no copy of the outfit rows.

`Body.dress` is already correct for this: it takes a `Model`, requires only `character.Parent ~= nil`,
finds limbs by name with an R6 fallback, paints `BodyColors`, and wears a real catalog accessory
through `Humanoid:AddAccessory` when `Body.setAccessorySource` has been wired — otherwise the plates
Karen has already signed off. `Body.dressWhenLoaded` is **not** used: it takes a `Player` and exists
for the avatar appearance race, which a rig built from a `HumanoidDescription` we wrote does not have.

**Accepted side effect, stated rather than discovered:** `Body.accessoriesWorn()`,
`Body.slotsFellBack()` and `Body.repaints()` will count bots as well as players. `Bots.stats()`
counts its own dressings separately so the two questions stay separable.

---

## 4. Module layout

```
src/server/Bots/init.luau    ServerScriptService.Bots   the owner: CONFIG, state, the Heartbeat,
                                                        the view handed to the drive, stats
src/server/Bots/Fill.luau    pure   the fill arithmetic (ioquake3, re-pointed)
src/server/Bots/Lane.luau    pure   the lane geometry, the next aim point, the side-step, "arrived"
src/server/Bots/Rig.luau     writes the ONLY writer of a bot rig's Instances and of Workspace.DriveBots
```

The house shape, at a fourth instance: **a folder module that owns state over pure decision modules
driven by an injected world** — `Match`, `Boar` and `Weapon` are the first three. **Nothing happens on
`require`**: only `Bots.start(world)` begins production, which is what lets every spec in §16 run with
no Play, no avatar service and no clock. `Fill`, `Lane` and `Rig` are exported as `Bots.Fill`,
`Bots.Lane`, `Bots.Rig` for specs, exactly as `Match.Phase` and `Boar.Brain` are.

`Workspace.DriveBots` is the one run-time container, destroyed and rebuilt whole (the
`Body.OUTFIT_NAME` / `Scene.FOLDER_NAME` discipline). `Workspace` is not Rojo-owned and the harness
compares the **Edit** DataModel, so a run-time rig cannot dirty a run — exactly as
`Workspace.DriveMarkers`, `DriveScene`, `ForestMarkers`, `WeaponEffects` and `Boars` do not. No
`default.project.json` change, so **no re-Connect click is needed** for this task.

---

## 5. The two rulings the brief asks for

### 5.1 Where the fill is called from — **`world.bots`, injected into `Match.start`**

The brief's alternative (drive the bots entirely from the composition root off `Match.PhaseChanged`,
with no change to `Match`) is **rejected**, and the reason is decision §5.2 below, which is not
optional because a drive needs *some* end:

* `Match.beaterCrossing` is the measurement behind `Phase.beatersThrough`. It reads
  `driverPositions()` → `Match.playerDrivers(Match.driverThreats())`, which filters by
  `tonumber(driver.id)`. A bot has **no numeric id by design** (brief §1.3), so a bot beater is
  invisible to it by construction. A `PhaseChanged` listener cannot fix that from outside: the only
  ways would be to give bots fake userIds (forbidden) or to weaken `playerDrivers`'s filter (which is
  the one structural guarantee that keeps a phantom out of the score and the safety rule).
* `PhaseChanged` fires **after** `applyEffects` in `dispatch`, so a root-driven fill would also be
  building the line after the drive had already placed the real players and already force-broadcast
  the new drive. That is the exact class of ordering defect `Phase.enterAssigning`'s comment records
  being measured twice.
* A world that injects **nothing** gets today's drive with no new code path — the switch's second
  half, and the property `Match.config() == Match.CONFIG` already proves for config.

It is the same seam the drive already has for another owner's world: `boars = runtime` in `MatchBoot`
and `boars = ForestTest.readOnlyBoars(runtime)` in `ForestTestBoot`. **No owner requires another
owner**: `Match` does not require `Bots`, `Bots` does not require `Match`, `Weapon` or `ForestTest`,
and each composition root wires them.

### 5.2 Whether bot beaters end the drive — **yes, and here is the number that decision costs**

Adopted as the brief says. Karen's rule is *"Timer or when all beaters cross line of hunters"*, and
with a line of bots walking beside her *"all beaters"* is the **line** — so her own crossing ends
nothing (TASKS.md 159a(f), her open complaint) and the drive ends when the last of the line is past.
`Match.beaterCrossing` is the measurement; `Phase.beatersThrough` is untouched.

**The arithmetic, because it is large and nobody has seen it yet.** In the Forest Test a beater starts
`LINE.spawnNorthStuds + BEATER.behindLineStuds` = **240 studs** north of the road
(`ForestTest.beaterStart`), and the goal is `GOAL_PAST_LINE_STUDS` (20) beyond the stand. At
`WALK_SPEED = 9`:

* a bot line reaches the goal in **(240 + 20) / 9 ≈ 29 seconds**;
* Karen, a real beater at the place's own 16 studs/s, reaches the road in **15 seconds** and then
  waits about 14 for the line — which is the improvement over 159a(f), measured rather than hoped;
* the Forest Test's clock is `Data.DRIVE.seconds = 300`, so **with bots on, a drive there ends at
  about 0:29 instead of 5:00**, every drive, and in the DEV arena at whatever the pad-to-line
  distance over 9 comes to.

That is Karen's two sentences composed, and it is a **feel** number, not a bug — but it is big enough
that it must not arrive as a surprise. It is handled three ways and none of them blocks building:

1. the flag is born **OFF**, so nothing changes until the Director turns it on for a playtest;
2. the three dials are named and each is one line: where the line starts (the world's own beater
   placement), `WALK_SPEED`, and `Match.CONFIG.END_ON_BEATERS_CROSS` (already exists, already not
   world-overridable);
3. `[bots]`'s per-drive line prints the measured walk seconds (§14), so the next conversation has a
   number in it. Karen's call is §17.1 item 1.

---

## 6. The interface, symbol by symbol

### 6.1 Types

```luau
export type TeamName = "Drivers" | "Shooters"        -- Match.Roster's strings, carried not invented
export type Counts   = { hunters: number, beaters: number }
export type Fill     = { hunters: number, beaters: number }
export type Threat   = { id: string, position: Vector3, kind: string }   -- Body.boarStimuli's shape

-- ONE BOT, as the DRIVE describes it. `from` is the world's own placement answer; `to` is nil for a
-- bot that stands. `Bots` decides walk-vs-stand from `to`, so it never learns what a beater is.
export type Slot = {
    id: string,            -- non-numeric, always: "bot-hunter-2", "bot-beater-3"
    team: TeamName,        -- for the outfit and for the horn's own carry policy
    from: CFrame,          -- where it starts (a beater's is the LANE BASE; Lane spreads from it)
    to: Vector3?,          -- where it walks to (the lane base's goal); nil = it stands
    lane: number,          -- 0 for a stander; 1..n for a beater, Lane.offsetFor's argument
}
```

### 6.2 `ServerScriptService.Bots` — the owner

```luau
Bots.CONFIG                                  -- deep-frozen (Drive.deepFreeze); §14
Bots.Fill / Bots.Lane / Bots.Rig             -- exported for specs

Bots.start(world: World)                     -- once; asserts it is not started twice
Bots.stop()                                  -- disconnects the Heartbeat, clears every rig
Bots.step(dt: number)                        -- the whole tick; the Heartbeat calls it, a spec drives it

Bots.fillCounts(real: Counts, config, standsFree: number): Fill    -- PURE; = Bots.Fill.counts
Bots.fill(slots: { Slot }, config): Fill     -- level-triggered, idempotent, NEVER YIELDS
Bots.gather(ring: { CFrame }, from: number): number   -- the results scene; stops the walk
Bots.clear(): number                         -- destroys every rig and the folder; returns how many
Bots.count(team: TeamName?): number          -- rigs that EXIST now
Bots.desired(team: TeamName?): number        -- slots WANTED now (so a build failure is visible)
Bots.beaters(): { { id: string, position: Vector3 } }  -- bot beaters with a body
Bots.threats(): { Threat }                   -- every bot with a body, each carrying its kind
Bots.view(): View                            -- the narrow table handed to Match.start
Bots.setRigSource(fn: ((HumanoidDescription, Enum.HumanoidRigType) -> Model?)?)
Bots.rigSource()
Bots.blowFor(id: string, now: number): boolean   -- the horn rhythm's one write, exported for a spec
Bots.stats()                                 -- §14
Bots.report(driveNumber: number): string     -- the ONE console line per drive
```

`World`, every field optional, every one a seam a spec replaces with a table:

```luau
{
    dress:       ((rig: Model, team: TeamName, config: any) -> boolean)?,  -- Match.Body.dress
    horn:        { give: (rig: Model, team: TeamName) -> any?,             -- Weapon.Horn.giveTo + carriesFor
                   blow: (handle: any, key: string, now: number?) -> boolean }?,  -- Weapon.Horn.blowTool
    groundAt:    ((x: number, z: number) -> number?)?,     -- the WORLD's one ground reader
    roomToStand: ((point: Vector3, radius: number) -> boolean)?,  -- the WORLD's one clearance reader
    now:         (() -> number)?,
    heartbeat:   boolean?,                                 -- false: a spec drives Bots.step itself
}
```

`groundAt` and `roomToStand` are injected rather than re-derived, and that is the whole reason they
are seams: the Forest Test already has **one** answer to each (`ForestTest.Data.groundAt` and
`ForestTest.roomToStand`, the two functions it already hands to `Markers.setReaders` and to the boar
world), and a third copy of either would be two definitions of *"where is the ground"* — this
project's named failure mode. With neither injected (the DEV arena, flat at one `groundY`) a lane
point keeps its base's Y and every point is clear, which is today's arena exactly.

### 6.3 `Bots.view()` — what the drive may do, enforced by the shape of the table

The `ForestTest.readOnlyBoars` idiom: the drive gets no `step`, no `start`, no rig and no setter.

```luau
{ fillCounts, fill, gather, clear, count, beaters, threats }
```

### 6.4 `ServerScriptService.Match` — added (delta to `drive.md` §9.2)

```luau
-- PURE and exported, beside Match.crossedLine / gatherSpotFor / quickSpawnFor:
Match.lineReferenceFor(position: Vector3?, line, posts): (Vector3?, Vector3?)
    -- (reference, normal) -- WHERE THE HUNTERS' LINE IS FOR THIS BEATER: the stand nearest him
    -- LATERALLY, else the line marker's own position. FACTORED OUT of Match.crossedLine, whose
    -- behaviour and signature do not change, and now shared with beaterGoalFor below -- so there is
    -- ONE answer to that question instead of two that can drift.
Match.beaterGoalFor(from: Vector3?, line, posts, marginStuds: number?): Vector3?
    -- where a beater on this lane walks TO: the reference above, `marginStuds` PAST it along -normal,
    -- at the reference's own Y. nil when there is no line to measure from.
Match.botSlotsFor(markers, place, real: Counts, want: Fill, cfg): { Slot }
    -- PURE given `place`. The drive's own geometry, as a slot list:
    --   a bot HUNTER per post:  place(markers, "Shooters", real.hunters + i, cfg), lane = 0, to = nil
    --   the bot BEATERS' BASE:  place(markers, "Drivers", real.beaters + 1, cfg) ONCE, for all of
    --                           them, with lane = 1..want.beaters and
    --                           to = Match.beaterGoalFor(base.Position, line, posts,
    --                                                    cfg.BOTS.GOAL_PAST_LINE_STUDS)
Match.botCount(): number       -- read-only passthrough to world.bots.count(), for a spec and the report
```

Changed inside `Match`:

* `Match.CONFIG.BOTS` — the flag read and the per-drive targets (§13, §14). **Not** on
  `Match.WORLD_OVERRIDABLE`; it is a table, and `mergeConfig` already refuses tables, so no world can
  give it a second value. `Match.config() == Match.CONFIG` still holds in DEV.
* `Match.beaterCrossing()` — counts bot beaters into **both** numbers it already returns, from
  `world.bots.beaters()`, against the same `Match.crossedLine` predicate. `Match.playerDrivers`,
  `driverPositions`, `samplePush`, `Penalty` and `Phase.beatersThrough` are all untouched.
* `applyScene()` — the ring is `#ids + botCount` wide (`Scene.ringLayout` already takes a count);
  players take slots `1..#ids` through `Body.stand` as today, then
  `world.bots.gather(ring, #ids + 1)`.
* `Match.boarThreats()` — appends `world.bots.threats()`. `Match.driverThreats` is **not** changed:
  it answers *"who is pushing, and who may be tied"* and that must stay a question about people
  (`Body.boarStimuli`'s own header says why one predicate must not answer two questions).
* `syncBots()` — a new local, called once at the end of `dispatch` (§8).
* `Match.stop()` — `world.bots.clear()`, beside `applyClearScene()`, for the same reason: a spec that
  stops the drive must not leave eight rigs standing in the world.

### 6.5 `Weapon.Horn` — added (two symbols, one blast implementation)

```luau
Horn.blowTool(tool: Tool?, key: string, blowerUserId: number?, now: number?): boolean
Horn.giveTo(character: Model): Tool?
```

`Horn.blow(player, now)` becomes a two-line wrapper:
`Horn.blowTool(Horn.held(player), tostring(player.UserId), player.UserId, now)`. `lastBlast` re-keys
from `userId` to that **string** key, and `Horn.forget`/`Horn.ready` follow it. `Horn.readyAt` is pure
and untouched.

Everything a blast is stays in one place: one cooldown table, one measured 1.0 s cut of the asset, one
`GRIP_BLOW` tilt, one `Blown` signal. §9 says why this and not a second blast path.

### 6.6 `ServerScriptService.ForestTest` — added (delta to `forest-drive.md` §9.3)

```luau
ForestTest.setBotThreats(fn: (() -> { Threat })?)   -- the ONE injected bot source, set at the root
ForestTest.botThreats(): { Threat }                 -- what that source answers now, or {}
```

`ForestTest.realBeaters()` appends the `kind == "driver"` subset of `botThreats()` — so *"who is
pushing"* stays **one** list with two sources, read by the two things that already read it
(`boarThreats` and `stepLines`'s flush), and `spookNearBeaters` gains bot beaters for free.
`ForestTest.boarThreats(now)` keeps its signature and decides the phantom suppression itself (§10).

### 6.7 The two composition roots — wiring only

`MatchBoot.server.luau`:

```luau
Bots.start({
    dress = Match.Body.dress,
    horn = {
        give = function(rig, team)
            -- THE HORN'S OWN CARRY POLICY, the same pure function and the same ONE boundary read of
            -- the same flag that decides for a player. Nothing new decides who carries a horn.
            return if HornData.carriesFor(hornOn, team) then Weapon.Horn.giveTo(rig) else nil
        end,
        blow = Weapon.Horn.blowTool,
    },
    now = function() return os.clock() end,
})
Match.start({ boars = runtime, weapon = Weapon, bots = Bots.view(), now = ... })
```

`world.threats = Match.boarThreats` is **unchanged** (it now appends the bots itself).

`ForestTestBoot.server.luau`: the same `Bots.start` block plus this world's two readers —
`groundAt = Data.groundAt`, `roomToStand = ForestTest.roomToStand` — then
`ForestTest.setBotThreats(Bots.threats)` and `bots = Bots.view()` on the existing `Match.start` call.
Its `world.threats` closure and its `Weapon.Horn.Blown` handler are **unchanged** (§9, §10).

---

## 7. The fill — ioquake3's `G_CheckMinimumPlayers`, re-pointed

`Bots.Fill.counts(real, config, standsFree)`, pure, no state, no clock:

```
if not config.BOTS.ENABLED            -> { 0, 0 }
hunters = max(0, TARGET.hunters - real.hunters)      -- target 0 is off for that side, structurally
beaters = max(0, TARGET.beaters - real.beaters)
hunters = min(hunters, max(0, standsFree))           -- a bot hunter needs a stand of its own
if hunters + beaters > MAX_BOTS       -> trim BEATERS first, then hunters (deterministic)
```

What is borrowed and what is changed (rule 2):

* **borrowed:** the per-team target rather than a per-server one (`TEAM_RED` and `TEAM_BLUE` counted
  and filled separately — Karen's "4 hunters 4 beaters", not "8 bodies"); `humans + bots` against the
  target so the arithmetic is one subtraction; **add and remove symmetric**, so a bot is pushed out
  the moment a human takes the slot; **target 0 is the switch**, not a second boolean beside it; and
  the refusal to fill while the roster is unsettled.
* **changed, with the reason:** ioquake3 polls *"only check once each 10 seconds"* and refuses during
  `level.intermissiontime`. We have the boundary the poll is approximating — `Phase`'s own transitions
  — so the fill is **level-triggered at the drive's boundaries** (§8) and a timer here would be a
  second answer to *"is the roster settled"*. And its slot reserve (`minplayers >= maxclients/2`) is
  **dropped**: a Quake bot occupies a client slot, so a connecting human can be locked out; our rigs
  are not clients and cannot consume a connection, and the symmetric removal already hands the slot
  back. The clamp that replaces it is `standsFree`, which is about **stands**, not connections.
* `TARGET.hunters + TARGET.beaters <= MAX_BOTS` is asserted in a spec, the
  `MAX_ALIVE_BOARS >= SOUNDER.MAX_SIZE` idiom: the trim above is then unreachable with the shipped
  numbers, and unreachable is a claim, not a guarantee.

---

## 8. The four phase boundaries, and an early end

`syncBots()` is **level-triggered and idempotent**, called once at the end of `Match`'s `dispatch`
after `applyEffects` — the `Horn.refreshCarry` / `Weapon.refreshArming` discipline, because every
edge-triggered grant in this repo has been measured missing one. It reads `state.phase`,
`Roster.counts(state.assignment)` and `markerSet`, and does exactly one thing:

| Phase | `syncBots()` does | Why |
|---|---|---|
| `Waiting` | `world.bots.clear()` | no drive, no roster, nothing to fill. A server that empties out is not left with eight rigs standing in the wood (`enterWaiting`'s own `clearScene` reasoning) |
| `Assigning` | `fillCounts` → `botSlotsFor` → `fill` | the roster for **this** drive has just been decided by `Roster.assign` in `enterAssigning`. This is ioquake3's "not during the intermission" read forwards: never fill while the roster is unknown |
| `Running` | the same `fill` (level) | a `join`, a `leave` or a `Match.requestTeam` inside the drive changes a side's real count, and the fill is symmetric. One call site handles all four events |
| `Scoring` | nothing | the rigs are standing in the ring, moved by `applyScene`'s `gather` inside the same dispatch. They are destroyed by the **next** `Assigning`'s fill, which rebuilds from scratch — "removed and re-placed every drive" (note §1.6), and no pool |

**Rebuild, not re-use.** `Bots.fill` compares the slot list it is given against the rigs it holds **by
slot id**; a slot that is gone is destroyed, a slot that is new is built, a slot whose `from`/`to`
changed is re-placed. At a drive boundary every id is rebuilt because `botSlotsFor` re-reads the
world's geometry and the roster, so a bot cannot be left standing on a stand a real hunter now owns.

**GO and the hold.** A bot is not in `heldStill` and gets no `Body.hold`: that table is keyed by
userId. A bot beater simply **does not walk until the drive is `Running`** — `Bots.step` only moves a
walker while the drive has told it to, which is the `to` it was given at `Assigning` plus
`Bots.release()`… and that is one call too many, so it is derived instead: `fill` carries the slots
and `gather` stops them, and `Bots.CONFIG.WALK_FROM_FILL = false` means a filled walker waits for
`Bots.go()`. **Ruled: `Bots.go()` is the GO call**, made by `syncBots()` on the `Running` branch —
one more line, level-triggered like the rest, and it is what makes "held through the countdown exactly
as a player is" true for a bot without touching `heldStill`.

**An early end** (`Phase.beatersThrough`) takes exactly the same path as the clock: `enterScoring`
emits `release`, `clearBoars`, `hold`, `scene`, and `applyScene`'s `gather` stops the walk and stands
the rigs in the ring. There is one scene either way, as §159's own design says.

**A bot that arrives** at its goal before the drive ends stops there and stands, facing the line. It
does not walk on, and it does not go home.

---

## 9. The walk, the stand, and the horn

### 9.1 The walk — `Humanoid:MoveTo` re-issued down a lane

Per note §3, `PathfindingService` is rejected (the line is the feature; eight shortest paths are eight
detours; the cost is undocumented; the obstacle case is smaller for a person than for an animal and is
already solved in this repo).

Each `Bots.step` (5 Hz), per walker:

1. `arrived = Lane.arrived(at, goal, ARRIVE_STUDS)` → stop, anchor nothing, done.
2. `aim = Lane.aimFor(at, goal, AHEAD_STUDS)` — the next point down its own lane, flat in XZ.
3. if `world.roomToStand(aim, LANE_CLEAR_STUDS)` is false, try
   `Lane.sideStep(aim, at, goal, try, config)` for `try = 1..SIDE_TRIES` — `±SIDE_STEP_STUDS`
   perpendicular to the lane, alternating, nearest first. This is `ForestTest.beaterStartPosition`'s
   own search re-pointed at a lane point (borrowed from inside this repo, rule 2), and it asks the
   world's **one** clearance question rather than casting a new ray.
4. if `now - lastMoveAt >= MOVE_REISSUE_SECONDS` (2, well inside the engine's documented 8-second
   `MoveTo` timeout), `humanoid:MoveTo(aim)`.
5. stuck: moved less than `STUCK_STUDS` in `STUCK_SECONDS` → force a side-step and count it. The count
   is printed every drive, so note §3's escape hatch (SimplePath) is opened by a number and not a
   feeling.

The lane, pure, in `Bots.Lane`:

```
offsetFor(slot, config) = ceil(slot/2) * LANE_SPACING_STUDS * (slot odd ? +1 : -1)   -- +18, -18, +36, -36
startFor(base, slot, config) = base * CFrame.new(offsetFor(slot, config), 0, 0)
goalFor(baseGoal, base, slot, config) = baseGoal + base.RightVector * offsetFor(slot, config)
```

Three properties that are the reason it is written this way:

* **Lane 0 is left empty, for the real beaters.** The forest puts every real beater on one measured
  point (`beaterStartPosition` ignores its index) and the arena spreads them 3.5 studs apart about the
  pad centre; by starting the bots at `±LANE_SPACING_STUDS` the people keep the middle — which in the
  forest is the push line through the stand the drive aims every wave at.
* **The spread is along the base's own `RightVector`**, so the forest's road-facing look (a sine whose
  tangent swings ±23°) carries the whole line with it, and the lanes stay parallel to the push.
* **The goal is offset by the same amount**, so a line that sets off abreast arrives abreast.

The Y of a lane start is `world.groundAt(x, z) + DROP_STUDS` when a reader is injected, else the base's
own Y, and a nil answer is counted (`groundMissing`) and falls back to the base's Y. Without this a
lane 36 studs sideways on terrain that climbs 56 studs in 400 puts a rig 5 studs under or over the
ground — which is the defect `ForestTest.terrainYAt`'s own header records being measured.

### 9.2 The stand — the vendor's own sentence, taken as far as the outfit allows

A bot hunter: root `Anchored = true` (the same reason `Body.holdCharacter` anchors first — a
character's physics is owned by a client, so a server-side pivot alone is a suggestion),
`Humanoid.EvaluateStateMachine = false`, every `HumanoidStateType` disabled via `SetStateEnabled`,
nothing animated from the server, `Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None`
(eight name tags over the stands is eight things Karen did not ask to see).

Roblox's own *"static NPCs that do not move generally have no need for the Humanoid class"* is honoured
as far as it can be: the class stays because `Humanoid:AddAccessory` needs it and the outfit is
`Body`'s, unchanged, with one dressing path.

### 9.3 The horn — the existing door, through the horn's own owner

The constraint (brief §3.4) is the real reach, the real cooldown and the one signal both roots already
connect — and `Horn.blow(player)` takes a `Player` and a held `Tool`, which a bot has neither of.

**Ruled: a bot beater really carries a built horn, and the blast goes through one new non-player entry
point on the horn's own owner.** Not a second blast path:

* `Horn.giveTo(rig)` builds `Horn.build()` and `humanoid:EquipTool(tool)`. The Tool is the horn's, the
  rig is `Bots.Rig`'s — the same split a player has (`Match.Body` owns the character, `Weapon.Horn`
  owns the Tool in its hand). The 3D `Sound` hangs on the Handle as it always has, so the blast is
  heard **from where the bot is standing** with no new code.
* `Horn.blowTool(tool, key, blowerUserId, now)` is `Horn.blow`'s body, factored out and keyed by a
  string. `Horn.blow(player)` calls it. **One** cooldown table, **one** measured 1.0 s cut, **one**
  `GRIP_BLOW` tilt, **one** `Blown` signal.
* `key` for a bot is its own id (`"bot-beater-3"`), so a bot is held to the real
  `Horn.CONFIG.COOLDOWN` by the same table as a player. `EVERY_SECONDS` (18–35, jittered) is far above
  1.5, so a bot can never be the thing that tests the cooldown — and a spec asserts
  `EVERY_SECONDS.min > COOLDOWN` rather than trusting it.
* **`blowerUserId` is `nil` for a bot**, and the drive already refuses it:
  `Match.creditPush(nil, ids)` → `Match.pushCreditable(nil, nil, live)` → `type(nil) == "number"` is
  false → `0`. Checked against the code, not assumed, and asserted in a spec. So the existing handler
  in **both** roots — `Weapon.Horn.Blown:Connect(... runtime:hearHorn(blast.at, HornData.spookStuds(HornData.CONFIG)) ... Match.creditPush(blast.blowerUserId, ids))` —
  needs **no change at all**: a bot's blast travels the wire Karen's own `/beater` blast travels, with
  the real reach, and pays nobody.
* **Who may carry one is not a new rule.** The root's `give` seam asks `HornData.carriesFor(hornOn, team)`
  — the same pure function and the same single boundary read of the same `HORN` flag that decides for
  a player. With `HORN` off, a bot beater carries nothing and blows nothing, exactly as a player does.

The rhythm (which bot blows when) is `Bots`'s, per the owner table: `Bots.blowFor(id, now)` picks the
next jittered due time per bot from its own deterministic hash (the `Phase.unitHash` discipline — a
`Random` here would make a bug report unreproducible).

---

## 10. What the phantoms become

The Forest Test's wave mode invents a phantom beater 11 studs behind each herd
(`ForestTest.boarThreats`, `phantom = true`, `id = wave.id`). The LINE mode never had any (TASKS.md
153b), so nothing there changes.

**Decided by `ForestTest`, inside `ForestTest.boarThreats`, off the one injected bot source** — and
not by the composition root, and not by `Bots`:

* the phantoms are the Forest Test's own invention, so only their owner may retire them;
* the rule is level-triggered off a live fact rather than a boolean somebody passes in, so a drive
  with the flag on but no rig built yet still gets its phantoms and the push never gaps;
* the root then needs no new argument and its `world.threats` closure is unchanged.

The rule: **while `ForestTest.botThreats()` answers any `kind == "driver"` entry, the wave phantoms are
suppressed.** A body Karen can see pushes; a phantom 11 studs behind the herd does not push at the same
time. With no bots, `botThreats()` is empty and the file is today's file.

A bot's threat entry: `{ id = "bot-beater-1", position = <root>, kind = "driver" }` with **no
`phantom` mark**, because somebody IS standing there — so `Boar.CONFIG.PACE`'s existing branch for a
real driver inside `DRIVER_RUN_STUDS` applies, which is the whole point of a visible beater. A bot
hunter is `kind = "shooter"`, exactly as `Body.boarStimuli` maps a real one: noticed at 25 studs,
flushing only at 15, so a boar can still come down the corridor to the line.

---

## 11. The rig

### 11.1 The source is an injected seam

Default `Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)`
— the engine's own R15 builder, an empty description (no bundle, no clothing, nothing to fetch), and
`Body.dress` then paints the green and wears the hat and vest.

`Bots.setRigSource(fn)` is the seam, the shape `Boar.setModelSource` and `Body.setAccessorySource`
already have — so **every spec builds bots from a fake rig with no avatar service, no web call and no
Play**.

### 11.2 Build order, and the epoch

Parent before dress (`Body.dress` refuses a parentless Model), place after dress:

```
build (may yield, off the step loop) -> parent to Workspace.DriveBots -> properties -> dress -> place
-> (beater) horn
```

`Bots.fill` **never yields**: it records the slot list, returns the counts, and the stepper spawns at
most `BUILD_PER_STEP` build tasks. Each build task carries the `epoch` current when it started; a
task whose epoch is stale when its rig arrives **destroys the rig** and counts it. That is the
`Body.dressWhenLoaded` (`watching[userId] ~= row`) and `Horn.blow` (`lastBlast == at`) guard, applied
to a yield that crosses a drive boundary.

### 11.3 Properties, and the one that is a declared measurement

* `Humanoid.WalkSpeed = WALK_SPEED` for a walker; root anchored and the state machine off for a
  stander (§9.2).
* `Humanoid.DisplayDistanceType = None` on both.
* `CanTouch = false` on every part: a body should not fire `Touched` at anything.
* **`SHOOTABLE = false` → every part `CanQuery = false`**, and this is the repo's own stated reason,
  not tidiness: *"a prop that stops a pellet changes what the shot hit, and what the shot hit is what
  the safety rule and the hit record read"* (`Match.Scene`, `Match.Body`, `ForestTest.Markers` all say
  it). Three facts become true at once with one property instead of a filter in three places: a bot
  cannot be credited a hit, cannot appear in the drive report, and cannot stop a shot that is
  otherwise legal. §17.3 names what it costs and what flips it.
* **The measurement this one needs (rule 6):** I could not verify from here whether a `Humanoid` walks
  normally with `CanQuery = false` on its own parts (no Studio in this run). If the bots do not walk,
  `SHOOTABLE = true` is the fallback — the walk is the feature — and then the bogus-row hazard in
  §17.3 is live and must be reported with the measurement beside it. The Builder **looks** before
  claiming either.

### 11.4 The legs do not move, and that is said out loud

A rig from `CreateHumanoidModelFromDescription` carries no `Animate` script (that comes from
`StarterCharacterScripts`, which only a player's character gets), and a run-time `Instance.new("Script")`
cannot be given source. So **a bot walks upright without a walk animation: it slides.** The brief's §4
excludes bot animations from this task, so this is in scope — but it is exactly the class of failure
`docs/PROJECT_CONTEXT.md` names (*"things measured correct and looked wrong"*), so:

* it goes on the **screenshot** check (§16.4), which is the one thing that can catch it;
* the fix is named and queued (TASKS.md 161a): one `Animator:LoadAnimation` per walker with Roblox's
  own default R15 walk, after verifying that asset is public the way task 142 and task 152 verified
  theirs. It is not done here because a server-side animation is the vendor's own named cost (§12.2)
  and because one task is one task.

### 11.5 Sources for the rig

* `Players:CreateHumanoidModelFromDescription` —
  <https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescription>,
  vendor docs, current. **Well:** one call is a complete R15 rig with a `Humanoid`, so there is no
  hand-built rig, no `.rbxm` and no 60-line model file. **Badly:** it is documented to load assets, so
  it can **yield** — which is why §11.2 keeps it off the step loop — and the page says nothing about
  whether the model carries an `Animate` script, which is exactly the question §11.4 is about and
  which I could not answer from here.

---

## 12. External sources

Carried from `docs/research/2026-10-12-bots.md` §2, which fetched and quoted them on 2026-10-12. Listed
here with what each does well and badly **for this design**, and what was taken.

### 12.1 ioquake3, `code/game/g_bot.c` — `G_CheckMinimumPlayers`

<https://github.com/ioquake/ioq3/blob/main/code/game/g_bot.c> — **GPL-2.0**, actively maintained
(commits through 2026). This repo already borrows from it (tasks 159 and 160 quote `g_main.c` and
`g_team.h`).

**Well:** it is the whole fill design, shipped and twenty years old — per-team target, `humans + bots`
against it, add and remove symmetric, `minplayers <= 0` as the switch, and a refusal to act while the
roster is unsettled. **Badly:** its bots are **clients** — `G_AddRandomBot` goes through `ClientBegin`,
so a Quake bot has a client number, a name, a score and a place on the scoreboard. That is the one
thing Karen's bots must not do: her results table is the board she reads at the end of every drive.
And its clock is a 10-second poll, where we have the boundary the poll approximates.
**Adopted:** §7, re-pointed at a phase boundary and at rigs that are not clients.

### 12.2 Roblox, "Improve performance"

<https://create.roblox.com/docs/performance-optimization/improve> — vendor docs, current.

**Well:** it splits our two bot kinds for us. *"Humanoid … comes with a significant computation
cost"*, *"There is a performance cost to leaving certain HumanoidStateTypes enabled"*, *"Static NPCs
that do not move generally have no need for the Humanoid class"*, *"NPC animations that run on the
server need to be simulated on the server and replicated to the client"*. §9.2 is that page, taken as
far as wearing the outfit allows, and §11.4 is why there is no server animation yet.
**Badly:** it contains **no numbers**, so *"eight humanoids is cheap"* is not a claim it can support.
**Adopted:** the state-machine and animation advice; **rejected and said out loud:** its last line,
pooling — the warning is about *frequent* respawning and this builds eight rigs once per drive, while
a pool would be live state carried across the one boundary that exists to reset it. The honest version
of the cost claim is a **measurement**, which is why the stepper times itself (§14).

### 12.3 Roblox, "Character pathfinding" and the `Humanoid:MoveTo` reference

<https://create.roblox.com/docs/characters/pathfinding> and
<https://create.roblox.com/docs/reference/engine/classes/Humanoid#MoveTo> — vendor docs, current.

**Well:** one hard number decides our loop — **`MoveTo` times out after 8 seconds**, and the timeout is
reset by calling it again, which is what the official sample does. A beater has ~240 studs to cross at
a walk, so one `MoveTo` cannot do it and the loop must re-issue whatever route it follows.
`MOVE_REISSUE_SECONDS = 2` is that number with room to spare. **Badly:** the pathfinding half is
written for **one agent chasing one target**; it says nothing about a line of agents abreast, which is
the only thing a beater line is — and a shortest path is per agent, so eight of them are eight
detours. It also states no cost, throttle or limit for `ComputeAsync`.
**Adopted:** the re-issued `MoveTo` loop and the 8-second bound. **Rejected:** `PathfindingService`
(note §3's three reasons).

### 12.4 SimplePath, `ahmicy/simplepath`

<https://github.com/ahmicy/simplepath> — **MIT**, ~70 stars, last pushed 2026-06-12, not archived.

**Well:** it proves the loop's shape (a `MoveToFinished` chain rather than a `wait` per leg, a
`Path.Blocked` handler that only fires for a waypoint ahead) and, more usefully, it proves that the
expensive operation needs a **declared floor** (`TIME_VARIANCE = 0.07`, a throttle written as data).
**Badly:** it is a *pathfinding* module, and §9.1 rejects pathfinding for the line — adopting it would
adopt the per-agent `ComputeAsync` we are avoiding. It is also one object per agent with its own
connections and its own clock, where this system wants **one stepper over all eight bots**: one
Heartbeat, not eight.
**Adopted:** the principle that the expensive thing gets a declared interval (`MOVE_REISSUE_SECONDS`,
`BUILD_PER_STEP`, `STEP_HZ` — all data). **Not adopted:** the module. It stays the named escape hatch
if the straight walk is ever measured getting stuck, and `stuck` is the number that opens it.

### 12.5 `Players:CreateHumanoidModelFromDescription` — §11.5.

### 12.6 Borrowed from inside this repo (rule 2 points here first)

* `ForestTest.beaterStartPosition` — the ±10…±40 side search for a clear spot, re-pointed at a lane
  point (§9.1). `ForestTest.roomToStand` and `Data.groundAt` are **injected, not copied**, because two
  definitions of *"where is the ground"* is this project's named failure mode.
* `ForestTest.standIndexFor` — the centre-out index, which `Bots.Lane.offsetFor` is the same shape of,
  and which gives a solo hunter stand 5 and the bots 4, 6, 3, 7 for free.
* `Match.Body.dress(model, team, config)` — already takes a Model, so the outfit needs no change at
  all (§3.2).
* `ForestTest.readOnlyBoars` — the narrow view handed across an owner boundary; `Bots.view()` is it
  again.
* `Boar.setModelSource` / `Body.setAccessorySource` — the injected-source seam; `Bots.setRigSource` is
  it again.
* `Phase.unitHash` — deterministic jitter, so a horn rhythm is reproducible in a bug report.

---

## 13. The flag

Per CLAUDE.md *"Feature flags"*: bots change how the drive **feels**, so the row is born OFF.

```luau
DRIVE_BOTS = {
    default = false,
    owner = "ServerScriptService.Match",     -- it reads it at Match.CONFIG's boundary
    born = "2026-10-12 task 161",
    expires = "2026-11-02",                  -- 21 days, feature-flags.md section 12
    why = "A drive is always 4 hunters and 4 beaters: every slot no real player fills is a visible "
        .. "R15 bot -- beaters in orange vests walking the wood and blowing the horn, hunters "
        .. "standing on the stands. OFF is exactly the game before task 161: nobody is built, the "
        .. "Forest Test's phantom beaters push as they do today, and only real beaters can end a drive.",
}
```

Ten flags against `Flags.MAX_FLAGS = 12`.

**The only permitted shape**, read once at the boundary and passed inward as a parameter:

```luau
Match.CONFIG.BOTS = {
    ENABLED = Flags.isOn("DRIVE_BOTS"),
    TARGET = { hunters = 4, beaters = 4 },
    MAX_BOTS = 8,
    GOAL_PAST_LINE_STUDS = 20,
}
```

`Bots.Fill.counts(real, config, standsFree)` takes that `config`, so a spec drives the **ON** branch
with `{ BOTS = { ENABLED = true, TARGET = … } }` while the flag itself sits OFF — the reachability
condition CLAUDE.md requires. `BOTS` is a nested table and `Match.mergeConfig` refuses tables, so no
world can give it a second value.

**OFF must mean today bit for bit, and the proof is three assertions, not a feeling:** no rig is
built; `world.bots.fillCounts` answers `{0, 0}` so `botSlotsFor` is never called; `Match.beaterCrossing`
adds 0 to both numbers, so `Phase.beatersThrough`'s "no real beater ⇒ false" clause holds as today;
`ForestTest.botThreats()` is empty, so the wave phantoms are untouched; `Match.config() == Match.CONFIG`.

The playtest path is the designed one: `python tools/flags.py set DRIVE_BOTS on`, play, look,
`python tools/flags.py clear` before the next harness run.

---

## 14. Numeric targets

`Match.CONFIG.BOTS` holds **how many and whether** (the drive's question). `Bots.CONFIG` holds **how
they behave** (the bots' question). Two tables, disjoint facts — the split `Match.CONFIG.SOUNDER` and
`Boar.CONFIG.SOUNDER` already have (`drive.md` §6.6/§6.7).

| Number | Value | Where | Why |
|---|---|---|---|
| `TARGET.hunters` | 4 | `Match.CONFIG.BOTS` | Karen, 2026-10-11: *"Let's make 4 hunters 4 beaters"* |
| `TARGET.beaters` | 4 | " | the same sentence |
| `MAX_BOTS` | 8 | " | the two targets summed; a ceiling that holds whatever the targets say |
| `ENABLED` | the flag | " | §13; `TARGET.* = 0` is off per side |
| `GOAL_PAST_LINE_STUDS` | 20 | " | 2 × `BEATER_CROSS_MARGIN_STUDS` (10), so arriving at the goal means **crossed** with margin and the drive's end is not a coin flip on one stud |
| `WALK_SPEED` | 9 | `Bots.CONFIG` | a walk, not a jog. `Body.defaultWalkSpeed()` is 16, which reads as a man in a hurry. **K**: Karen's eye decides, one line |
| `STEP_HZ` | 5 | " | this system's own clock, declared. The drive's is 4, the boar runtime has its own; this is a third |
| `MOVE_REISSUE_SECONDS` | 2 | " | well inside the engine's documented 8-second `MoveTo` timeout (§12.3) |
| `AHEAD_STUDS` | 12 | " | 1.3 s of walking at 9 studs/s, so the aim point is always ahead of the bot between re-issues |
| `ARRIVE_STUDS` | 4 | " | a character's own width: "it is standing on the goal", not "its root is on the point" |
| `LANE_SPACING_STUDS` | 18 | " | wide enough to read as a line from a stand 200 studs away, tight enough that four cover one crossing. Four bots span 72 studs |
| `LANE_CLEAR_STUDS` | 6 | " | `ForestTest.BEATER.clearStuds`: a body's width of clearance, the same question answered by the same number |
| `SIDE_STEP_STUDS` / `SIDE_TRIES` | 10 / 4 | " | `ForestTest.BEATER.sideStepStuds`, halved tries: a lane point needs a nudge, not a search |
| `DROP_STUDS` | 4 | " | `ForestTest.BEATER.dropStuds`: dropped onto the ground, not into it |
| `STUCK_SECONDS` / `STUCK_STUDS` | 4 / 3 | " | at 9 studs/s four seconds is 36 studs, so 3 is unambiguously "not walking" |
| `HORN.EVERY_SECONDS` | 18…35, jittered | " | *"blow the horn now and then"*. The floor is the real `Horn.CONFIG.COOLDOWN` (1.5), far below, so a bot can never be the thing that tests the cooldown — asserted, not assumed |
| horn reach | `Horn.spookStuds(Horn.CONFIG)` | — | the REAL reach, read from the horn's own data. No second number |
| `BUILD_PER_STEP` | 2 | `Bots.CONFIG` | eight rigs over four steps (0.8 s) instead of one hitch, and the declared floor §12.4 argues for |
| `SHOOTABLE` | false | " | §11.3, with the measurement it needs |
| the step's own cost | **printed, not asserted** | — | §12.2 has no numbers, so this one is MEASURED. Karen's rule: one line of numbers, not a frame hunt |
| the walk's own seconds | **printed** | — | the §5.2 number, per drive, so the feel conversation has arithmetic in it |

`Bots.stats()`: `fills`, `built`, `destroyed`, `buildsFailed`, `staleBuilds`, `dressed`, `dressFailed`,
`hornsGiven`, `blasts`, `blastsRefused`, `walking`, `arrived`, `walkSeconds`, `stuck`, `sideSteps`,
`groundMissing`, `gathered`, `epoch`, `stepMsAvg`, `stepMsMax`.

`Bots.report(driveNumber)`, one line per drive, printed by the composition root (the module never
prints — a tool that `require`s it over StudioMCP gets a sandboxed copy with empty state, measured in
task 122, so the server's own console is the only honest channel):

```
[bots] drive 3: 4 hunters, 4 beaters (0 failed, 0 stale) | walk 260 studs, 4/4 arrived in 29.3 s |
       0 stuck, 2 side-steps, 0 no-ground | 3 blasts | step 0.6 ms avg, 1.9 ms max
```

---

## 15. Blast radius

**`TWO_PLAYER_PATHS` (`tools/agents.py`): `src/server/Bots/` is NOT added**, and neither are its
specs. The Builder's provisional answer is adopted, with the reason: a bot is not a player, a second
human changes nothing about what a rig does, and the one question a second client answers — *who the
OTHER player is* — is answered for bots by a **pure** function a spec drives at every real-player
count from 0 to 8. **This task needs `test2` anyway**, because it touches `src/server/Match/`, which is
in the list.

**`BLAST_RADIUS` (`tools/studio_mcp.py`): yes, a new scope.**

```python
("src/server/Bots/", "bots"),
```
```python
"bots": ("tests/server/bots_fill.spec.luau", "tests/server/bots_lane.spec.luau",
         "tests/server/bots_live.spec.luau"),
```

and the three new specs are added to the **`match`** tuple as well (the dual membership `zz_horn`,
`boar_hit` and `shoot_boar` already use), because `src/server/Match/` now calls the view and is what
can break it. `selftest` requires every spec to belong to at least one scope, and these do.
`src/server/Weapon/Horn.luau` already resolves to `weapon` (whose tuple already names `zz_horn.spec`),
and `src/server/ForestTest/` already resolves to `match`.

---

## 16. How it is tested

Karen's rule holds: specs for the **logic**, no frames, no long traces.

### 16.1 Server specs, pure — no world, no rig, no clock

`tests/server/bots_fill.spec.luau`
* `Fill.counts` at every real count 0…8 per side, both sides at once;
* flag off ⇒ `{0, 0}`; `TARGET.hunters = 0` ⇒ no bot hunters and beaters unaffected (target 0 is the
  switch, per side);
* a real player joining takes a bot's slot back (the symmetry);
* `standsFree` caps the hunters; `standsFree = 0` ⇒ none;
* `MAX_BOTS` trim is deterministic, **and** `TARGET.hunters + TARGET.beaters <= MAX_BOTS` so the trim
  is unreachable with the shipped numbers.

`tests/server/bots_lane.spec.luau`
* `Lane.offsetFor` is `+18, −18, +36, −36`; lane 0 is never issued;
* `Lane.startFor`/`goalFor` spread along the base's own `RightVector` and stay parallel (a rotated
  base, which is the forest's sine road);
* `Lane.aimFor` never overshoots the goal; `Lane.sideStep` alternates nearest-first;
* `Lane.arrived` at the `ARRIVE_STUDS` boundary;
* `Match.beaterGoalFor` and `Match.lineReferenceFor` with hand-written `Vector3`s and hand-written
  post lists — including the forest's case (the plane 30 studs off the road, the nearest stand
  **laterally** rather than nearest overall) — and `Match.crossedLine`'s existing cases still pass
  unchanged after the factoring.

### 16.2 Server spec, live — Instances, but no Play and no frames

`tests/server/bots_live.spec.luau`, with `Bots.start({ heartbeat = false, … })` and a **fake rig
source** (a Model with a `Humanoid`, a `HumanoidRootPart`, a `Head` and an `UpperTorso` — enough for
`Body.dress` to find its limbs), a fake `dress`, a fake `horn`, and fake `groundAt`/`roomToStand`:

* `fill` then `Bots.step` ⇒ the rigs exist under `Workspace.DriveBots`, one per slot, and `fill`
  **did not yield**;
* every id is non-numeric: `tonumber(id) == nil` for all of them, and `Match.playerDrivers` returns
  nothing for the whole threat list;
* `threats()` kinds are `driver` for beaters and `shooter` for hunters, with **no `phantom` field**;
* `beaters()` is the driver-kind subset, with positions;
* `fill` with fewer slots removes the extras; with the same slots builds nothing new (idempotent);
* `gather(ring, from)` stands them on the given CFrames and stops the walk;
* `clear()` destroys the folder, and `Bots.count() == 0`; `stop()` leaves nothing behind and no
  connection (the `Match.stop` teardown assertion's shape);
* a build that lands after `clear()` (stale epoch) destroys its own rig: `staleBuilds == 1`, and no
  rig is left in the world;
* the horn rhythm: with a fake `blow` that always succeeds, blasts are `EVERY_SECONDS` apart and
  `EVERY_SECONDS.min > Horn.CONFIG.COOLDOWN`;
* the walk: `groundAt` nil once ⇒ `groundMissing == 1` and the rig is still placed; `roomToStand`
  false at the first lane point ⇒ a side-step, counted;
* `Body.dress` is called **once per rig** with the rig's own team (no second dressing path).

### 16.3 Additions to specs that already exist

* `match_live.spec.luau` — with a fake `world.bots`: `Match.beaterCrossing` counts a bot beater into
  both numbers; a solo hunter plus four bot beaters ends the drive **early** when all four are across
  and **not** before; with `world.bots` absent, every number is what it is today.
* `match_phase.spec.luau` — **untouched**, and that is the claim: `Phase` learns nothing about bots.
* `match_score.spec.luau` — a drive with bots has no extra row in `Match.snapshot().rows`,
  `Phase.participantIds` is unchanged, and `Match.creditPush(nil, { "b1" })` returns `0`.
* `match_scene.spec.luau` — `Scene.ringLayout(spot, #ids + botCount, cfg)` and the bots take the
  slots after the players, in index order.
* `match_config.spec.luau` — `Match.config() == Match.CONFIG`; `BOTS` is not in
  `Match.WORLD_OVERRIDABLE`; a world that tries to override it is **refused** (the table rule).
* `zz_horn.spec.luau` — `Horn.blowTool` with a built Tool and a string key: one blast, the cooldown
  refuses the second, `Blown` carries `blowerUserId = nil`; `Horn.blow(player)` behaves exactly as
  before the factoring; `Horn.giveTo(rig)` equips one Tool and only one.
* `forest_stand.spec.luau` — `ForestTest.setBotThreats` with one driver-kind entry ⇒
  `ForestTest.boarThreats` contains **no** `phantom = true` entry and does contain the bot;
  with the source cleared ⇒ the phantoms are back, exactly as today; `ForestTest.realBeaters()`
  includes the bot beater and `spookNearBeaters` flushes from it.

### 16.4 Client specs, the harness, and the screenshot

* **No client spec and no client file.** The wire gains no field (§2), so there is nothing new for a
  client to read. Said plainly so nobody adds a "bots" field nothing asked for.
* **The gate:** the full one-player `python tools/studio_mcp.py test`, **and `test2`**, because
  `src/server/Match/` is in `TWO_PLAYER_PATHS`. A scoped `test --scope auto` line
  (`scope=auto:bots,match,weapon`) is acceptable for a review round only.
* **Harness input (Task 6):** nothing here needs driven input. A bot is server-side; no key, no mouse
  button and no mouse move is involved. What the harness **cannot** do is relevant twice:
  `start_stop_play` has no player-count argument and `datamodel_type` has no index, so it cannot drive
  two independent clients — which is why the two-player line still costs Karen a click — and it
  cannot judge a look.
* **The screenshot (rule 5, Task 7):** one capture, in the Forest Test, with `DRIVE_BOTS` on:
  `python tools/studio_mcp.py capture bots-on-the-line <camera x,y,z> <look-at x,y,z>` from a stand
  looking up the drive, at GO. **Three things must be looked at in it, not measured:** four beaters
  abreast in orange vests at 18-stud spacing (not four bodies in one place and not a straggling file);
  bot hunters standing on the stands beside the player's; and §11.4 — **do the walkers look like
  people walking, or like statues sliding?** That last one is the only question in this task a number
  cannot answer, and it is the one PROJECT_CONTEXT exists about. It needs Karen's Play session and her
  flag switch, so it is a `NEEDS KAREN` step, not a thing the Builder can produce alone.

---

## 17. Open decisions

### 17.1 Karen (feel) — none of these blocks building; the flag is OFF and each is one line

1. **A drive now ends when the bot line is through, which is ~29 s in the Forest Test against its
   300-second clock** (§5.2 has the arithmetic). Is that the drive you want? The three dials are
   where the line starts, `WALK_SPEED`, and `END_ON_BEATERS_CROSS`.
2. **`WALK_SPEED = 9`.** A bot walks; you walk at 16, so you will reach the road about 14 s before the
   line does. Too slow, too fast, or right?
3. **Four and four.** Your sentence, taken literally. On a 10-player server there are no bots at all —
   is that right, or should a drive always show eight bodies?
4. **The horn rhythm, 18–35 s jittered.** Too much horn, too little?
5. **The sliding walk** (§11.4). If it reads wrong, 161a is one line and one asset check.
6. **The bot's face and name.** Default avatar, no name tag. If eight identical blank people read
   wrong, a `HumanoidDescription` per bot is data, not code.

### 17.2 Director (scope)

1. **TASKS.md 161a** collects: a bot that shoots; the walk animation; whether a pool is ever needed
   (only with a measurement beside it); and SimplePath if `stuck` is ever non-zero.
2. **The DEV arena's lanes.** The arena's `DriverStart` pad is 60 studs wide and the outer lanes sit at
   ±36, so a bot can stand just off the pad on arena ground. Flat at one `groundY`, so harmless —
   stated rather than discovered. If it matters, the pad widens in the map generator, not here.

### 17.3 A hole this task inherits and does not open — for the audit, not for this task

`HitLog.recordHit` makes a drive-report row for **any** reported `BasePart`, keyed by `part.Name`, so a
pellet that strikes a body produces an "animal" row called `UpperTorso`. **That is true today for a
second player's character** and is not caused by bots. With `SHOOTABLE = false` (§11.3) bots cannot
reach it; if the `CanQuery` measurement forces `SHOOTABLE = true`, they can, and with **one** player —
which it was not before. Either way the fix belongs to `HitLog`'s owner and to a Karen decision about
whether shooting a bot beater should tie a hunter to a tree (161a). Named here so the next reader finds
it written down rather than in a playtest.

---

## 18. Deltas — every document this design changes

| File | Change |
|---|---|
| `docs/design/drive.md` §3.2 | a row for `world.bots` in the owner's table, and `Match` is named as a **reader** of bot counts and positions, never a writer of a rig |
| " §3.5 | `MatchBoot` gains `Bots.start{…}` and `bots = Bots.view()`; `world.threats = Match.boarThreats` is unchanged |
| " §5.3 | `Assigning` gains, **after** the roster and outside the effect list: `fillCounts` → `botSlotsFor` → `fill`. The hold, the placement and the arming are untouched |
| " §7.1 | one sentence: a bot earns and costs **nothing**, structurally — no userId, so `pushCreditable` and `playerDrivers` refuse it |
| " §9.2 | `Match.lineReferenceFor`, `Match.beaterGoalFor`, `Match.botSlotsFor`, `Match.botCount`; `World` gains `bots?` |
| " §11 | `Match.CONFIG.BOTS` (§14) |
| `docs/design/forest-drive.md` §4.3 | the placement seam now answers for bot slots too, with the beater **base** taken once and `Bots.Lane` spreading from it |
| " §6 | *"this world's beaters are phantoms with nobody standing on them"* stops being true wherever it still stands (§10, and the task-151-round-1 rule). The safety arc is unchanged: a bot has no userId, so `Penalty.judge` can never find one |
| " §9.3 | `ForestTest.setBotThreats`, `ForestTest.botThreats`; `realBeaters` gains a second source |
| `docs/design/beater-kit.md` | one sentence in the ownership section: `Body.dress` dresses a bot rig as it dresses a player, and `Weapon.Horn` owns a bot's horn Tool — *worn is Body's, carried is Weapon's*, unchanged |
| `GAME_DESIGN.md` | a *System owners* row: **bots → `ServerScriptService.Bots`** (rule 3) |
| `src/server/Match/Body.luau` header | restate the boundary as the **PLAYER's** character and `WalkSpeed` (§3.2). Do not leave the older sentence standing |
| `docs/research/INDEX.md` | already carries `2026-10-12-bots.md` (commit 43e0103) |
| `tools/studio_mcp.py` | `BLAST_RADIUS` + `SCOPE_SPECS` (§15) |
| `tools/agents.py` | **no change**: `src/server/Bots/` is deliberately not in `TWO_PLAYER_PATHS` (§15) |
| `default.project.json` | **no change** — `src/server/` is already mapped, so no re-Connect click |

---

## 19. What I could not verify (rule 8)

Read-only run: Read, Grep and Glob, the precomputed `.agent-evidence/` for commit `43e0103`, no Studio
and no network. Specifically:

1. **Whether a `Humanoid` walks normally with `CanQuery = false` on its parts** (§11.3). Declared as a
   switch with a fallback and a required measurement, not asserted.
2. **Whether `CreateHumanoidModelFromDescription` yields, and whether its model carries an `Animate`
   script** (§11.4, §11.5). The design is written so that **either answer is safe**: the build is kept
   off the step loop regardless, and the walk animation is out of scope either way. The claim "the
   legs do not move" is an inference from where `Animate` comes from, and the screenshot is what
   settles it.
3. **Every claim about existing code in this document is from the file and the symbol**, not from a
   line number, and was read in this run: `Match.CONFIG`, `Match.beaterCrossing`, `Match.crossedLine`,
   `Match.playerDrivers`, `Match.pushCreditable`, `Match.creditPush`, `Match.boarThreats`,
   `applyScene`, `applyPlace`, `dispatch`, `Match.stop`, `Phase.beatersThrough`,
   `Phase.participantIds`, `Phase.heldUserIds`, `Body.dress`, `Body.holdCharacter`,
   `Body.placementFor`, `Body.boarStimuli`, `Body.driverPositions`, `Scene.ringLayout`, `Horn.blow`,
   `Horn.grant`, `Horn.carriesFor`, `Horn.spookStuds`, `Runtime:hearHorn`, `Boar.setModelSource`,
   `ForestTest.realBeaters`, `ForestTest.boarThreats`, `ForestTest.spookNearBeaters`,
   `ForestTest.beaterStartPosition`, `ForestTest.roomToStand`, `ForestTest.standIndexFor`,
   `ForestTest.readOnlyBoars`, `ForestTest.Markers.build`, `Data.beaterStart`, `Data.DRIVE`,
   `HitLog.recordHit`, `Flags.DEFAULTS`, `TWO_PLAYER_PATHS`, `BLAST_RADIUS`, `SCOPE_SPECS`.
4. **No harness claim is made here.** The gate numbers in §16.4 are what the rules require, not a run
   I performed.

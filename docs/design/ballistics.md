# Design: ballistics — a shot that takes time to arrive, and the lead a running animal needs

Task 185. Written to `reviews/task-185/BRIEF.md` (Builder carrying the Director, 2026-10-14) and to
`docs/research/2026-10-14-ballistics-lead.md`. The brief's twelve decisions are not re-opened.

**v2, Task 256 (2026-10-24): the lag correction.** `reviews/task-256/BRIEF.md` carries the Director's
decision of 2026-10-24: **forward prediction of the shot by the shooter's measured delay is ALLOWED;
rewinding targets is still FORBIDDEN.** What changed in this file: §1.1 item 9 and §1.2's first
"must not" (rewinding named as the thing forbidden, in the words it was always forbidden in), §2.2
(where each piece of the correction lives), §3.2 (two new numbers), §4.2 and §4.3 (the stale module
contracts — `Flight.launch` has a fourth argument, `Flight.stats` a sixth field, `Flight.substeps`
is new), **§5.1 (the mechanism, the bound and its measured limit)**, §9 sources B, F and G and the
pattern line, §10, §11.2, §13, §15 and §16. **Every other section is Task 185's, unchanged.** The
ballistics themselves — time of flight, drag, the zero, `GRAVITY_SCALE`, the pattern — are not
touched by Task 256 and were re-measured as already correct
(`docs/research/2026-10-24-real-shooting.md` §§3, 4).

This file is the design for **one new system (the flight of a shot)** and a **delta** to
`docs/design/shotgun.md` (3.1, 5.3, 5.5, 11, 11.1, 13) and `docs/design/rifle.md` (4). Where it
disagrees with either, this file wins for the flight and those files win for everything else.

Karen, 2026-10-14 ~20:15: *"another thing it has to be real like in a life when I shoot in running
animal I need to aim a bit in front based on speed distance ect I wan to have that feeling"*, and
~20:20: *"same with s/s"*. Karen, 2026-10-24: *"all shooting has to be like in real life / this is a
key of this game"*.

---

## 1. What the system must do, and must not do

### 1.1 Must do

1. **A shot takes time to arrive.** Today it does not: `Weapon.onFireRequest`
   (`src/server/Weapon/init.luau`) calls `Hits.resolve` in the trigger's own frame. From this task
   the server steps a projectile and the hit is judged where the target is **when the bullet gets
   there**.
2. **The time is per weapon per ammo**, from a real cartridge's muzzle velocity and its real loss of
   speed down range, so the lead a player holds is the lead the real gun needs: more at distance,
   more with the shotgun than with the rifle.
3. **A target that moved out of the path is not hit; one that moved into it is.** That is the whole
   feature. It is what makes aiming ahead *work* rather than merely making the shot late.
4. **Gravity drop as data**, zeroed at a stated distance per ammo, dead centre there.
5. **Task 183's still-target accuracy is preserved by construction.** `Rifle.CONFIG.SPREAD_FULL_DEG`
   is `{ Slug = 0 }`; the launch direction is today's `aim` elevated so that the drop cancels at the
   zero, so a still target at the zero is hit dead centre as a consequence of the arithmetic, not of
   a tolerance.
6. **Only the hit and the dust wait for the bullet.** The rate limit, the validator, the state
   machine, the ignore list, the aim ray, `Rules.refuse`, `SafetyArc`, the spent shell, the bang, the
   flash, the smoke, the recoil and the bolt are all at the trigger and stay there, in the same frame
   and in the same order.
7. **A hit's `distance` is measured from the MUZZLE.** `Cast.world` returns `distance` relative to the
   ray it was given, and a flight casts one short **segment** per step — so the raw number is at most
   one step long and is meaningless as "how far was that shot". `Flight` converts it before anybody
   sees it. `HitReport.nearest` is read by `MatchBoot` (`distance = report.nearest` into
   `runtime:takeHit`), by `HitLog` and by the drive report's metres, and all three would otherwise be
   silently wrong. This is the one place this change could have been correct by measurement and wrong
   on screen, which is the failure `docs/PROJECT_CONTEXT.md` is about.
8. **Cheap and leak-proof.** Up to nine pellets a shot, 16 players, one drive. No projectile may
   survive its own range or a hard time ceiling.
9. **(v2, Task 256) The lead a player must learn is the REAL lead, and only the real lead.** The lead
   is `Ballistics.timeToRange × the animal's speed`. The player's own connection must not be a second
   term in it. The shot is therefore **forward-predicted by the shooter's measured delay, bounded**,
   through the step this system already takes — §5.1. Karen, 2026-10-24: *"all shooting has to be
   like in real life / this is a key of this game"*; the measurement that this was 70 % of the lead
   again at a 60 ms one-way trip is `docs/research/2026-10-24-real-shooting.md` §§5.1, 5.3.

### 1.2 Must not

- **No client-side hit detection and no new trust in the client.** The client still sends one
  `FireRequest` with `{ origin, direction }` and nothing else (`docs/design/shotgun.md` 5.7). *(v2:
  the lag correction does not weaken this. It is measured on the SERVER, from
  `Player:GetNetworkPing()`, which the client never sends and therefore cannot spoof; there is no
  client timestamp anywhere in this system.)*
- **No Instance per projectile.** Nine replicating Parts a shot is refused here and now. The
  projectile is invisible maths on the server.
- **No REWINDING of targets, and no position history of one** *(v2, Task 256 — the prohibition is
  unchanged and is stated in the words it has always been stated in)*:
  **No lag compensation.** Rewinding hitboxes exists to remove the feeling Karen asked for.
  A rewind also needs a per-target position store, and `Boar.Body` is the one writer and the one
  store of where a boar is — *"two systems wrote the creature's position"*
  (`docs/PROJECT_CONTEXT.md`). Nothing under `src/server/Weapon/` may read or keep a target's past
  position, and no shot may be resolved against a rewound world. **What IS allowed is the opposite
  mechanism with the opposite effect: forward prediction of the PROJECTILE, which preserves the true
  lead and removes only the ping** (§5.1, the Director's decision of 2026-10-24,
  `reviews/task-256/BRIEF.md` §1). §9 source B is the rewind, named and refused; §9 source F is what
  was adopted instead.
- **No second writer of hits.** `ServerScriptService.Weapon` stays the one owner and
  `Weapon.Cast` stays the ONE caller of `Workspace:Raycast` under `src/server/Weapon/`. *(v2: this
  rule is the positive argument for where the lag correction lives — §2.2.)*
- **No feature flag** (brief 1.12): hitscan and flight are two answers to "where did the bullet go",
  and a flag would mean two hit owners. *(v2: the lag correction needs none either, and for a
  stronger reason — `FLIGHT_CATCHUP_PING_FACTOR = 0` and `catchUpSeconds = 0` are each bit-for-bit
  today's flight, proved by `weapon_hits.spec`'s "ZERO IS BIT-FOR-BIT TODAY'S FLIGHT" case, so the
  off state is reachable by data and by parameter without a second path.)*
- **Nothing under `src/server/Match/` is touched.** The safety verdict, the penalty and the tie stay
  exactly where they are (brief 1.10, note section 5). The launch direction differs from `aim` by
  **0.144°** against `SAFETY_ARC_HALF_DEG = 45`, so the arc's answer is identical.
- **No visible bullet, no drop reticle, no lead indicator.** Karen asked to *feel* the lead, not to be
  told it.
- **`RANGE_STUDS`, `PELLETS` and `SPREAD_FULL_DEG` do not move.** Tasks 183 and 184 set them and she
  has played them.
- **The camera, the Hud and the boar are untouched.**

---

## 2. Owners — one writer each, named

| Thing | The one writer | On disk | New? |
|---|---|---|---|
| **The ballistics maths** (time of flight, remaining speed, drop, the launch elevation, one step) | `ReplicatedStorage.Ballistics` — frozen numbers plus pure functions, **no state, no clock, no service except the one `require` of `ReplicatedStorage.Report` for `METRES_PER_STUD`** | `src/shared/Ballistics/init.luau` | **new** |
| **The live projectiles** (the list, each shot's record, each shot's accumulated impacts, "has this shot finished", **and what lag it still owes its shooter** — v2) | `ServerScriptService.Weapon.Flight` — one instance per owner, created by `Weapon`; holds state, holds no clock and no cast | `src/server/Weapon/Flight.luau` | **new** |
| **The clock that advances them**, and every signal, remote, counter and report that follows, **and the latency measurement** (v2) | `ServerScriptService.Weapon` (`src/server/Weapon/init.luau`) — **unchanged as the owner**. One `RunService.Heartbeat`, connected in `Weapon.start`, the only caller of `flight:advance`; and `Weapon.catchUpFor`, the only reader of `Player:GetNetworkPing()` in `src/` | `src/server/Weapon/init.luau` | existing |
| **The drawn dust at the landing point** | `PlayerScripts.Weapon.Effects` — **unchanged as the owner**, one new function | `src/client/Weapon/Effects.luau` | existing |
| **The `ShotLanded` RemoteEvent** | `ServerScriptService.Weapon` is the only firer; `ReplicatedStorage.Shotgun.Remotes` is where it is declared and `Shotgun.remotes()` the one place its path is spelled | `src/shared/Shotgun/Remotes.model.json`, `src/shared/Shotgun/init.luau` | **new remote, existing owner** |
| **The per-weapon ballistic numbers** | each gun's own frozen CONFIG (`Shotgun.CONFIG`, `Rifle.CONFIG`), surfaced through `Weapons.ROWS`, **never copied** | `src/shared/Shotgun/init.luau`, `src/shared/Rifle/init.luau`, `src/shared/Weapons/init.luau` | existing |

**Why `Ballistics` is not a second writer of anything.** It writes nothing at all. It is the same
shape as `ReplicatedStorage.Gun`, `Horn` and `Shop`: frozen data plus pure functions, no run-time
writer (`GAME_DESIGN.md` already has three rows of exactly that kind). It is **shared** rather than
server-only for one reason: if Karen ever asks for a tracer, the drawn path must come from the same
arithmetic as the hit, not from a second copy of it.

**Why `Flight` is not a second writer of hits.** It produces `Impact` records and nothing else. It
never calls `Workspace:Raycast` (the cast is a parameter), never builds a `HitReport` (`Hits.group`
stays the one constructor), never fires a signal, never touches a `Tool`, a state, a remote or a
counter. The owner does all of that, exactly as it does today — the only thing that changed is
*which frame* it does it in.

**Why `Flight` holds state when every other module in that folder is pure.** It holds a list, and
the repo's precedent for "stateful, still testable with no world" is `Weapon.Registry`:
`Registry.new()` returns an instance, keys by any value, and `weapon_state.spec` drives it with
stand-in keys. `Flight.new()` is the same thing: production holds one instance, a spec makes its own,
and the two never meet.

**`Weapon.Cast` stays the only caller of `Workspace:Raycast` under `src/server/Weapon/`.** A grep must
still find `Cast.luau` alone (`docs/design/shotgun.md` 13.5). `Flight` takes `cast` as a parameter,
and the owner passes the same `castFn` that `Weapon.setCast` already governs — so there is one cast
seam in the system, not two.

### 2.2 The lag correction — the owner does not move, and why that is not a fudge (v2, Task 256)

The correction is **one multiplication into a loop `Weapon.Flight` already runs, over the cast seam
the system already has.** Four pieces, each with exactly one home, all of them inside the owner that
already decides what a shot hit:

| Piece | File → symbol | What it is |
|---|---|---|
| the measurement and the conversion | `src/server/Weapon/init.luau` → `Weapon.catchUpFor(player, ping, config)` | **the one thing that computes the correction**, and the **only reader of `Player:GetNetworkPing()` in `src/`** (grep). Pure when `ping` is supplied. A negative, a NaN or a missing ping returns **0**, so this feature's failure mode is "the game shoots exactly as it did yesterday" |
| the clamp | `src/server/Weapon/Flight.luau` → `Flight.launch(shot, directions, ballistic, catchUpSeconds)` | the bound is applied **at the one door into the module**, with `math.clamp(catchUpSeconds, 0, FLIGHT_CATCHUP_MAX_SECONDS)`, so no caller can hand in a negative (a bullet that starts in the past) or an unbounded one |
| spending it | `src/server/Weapon/Flight.luau` → `live.catchUp`, read and zeroed in `Flight.advance` | added to **that shot's own `dt`** on the first `advance` and set to 0 there, so a shot cannot be compensated twice however many Heartbeats it lives for |
| the sub-step split | `src/server/Weapon/Flight.luau` → `Flight.substeps(total, config)` | pure and exported, because the split became a **per-shot** question. One copy of the arithmetic, so there is one answer to how far a bullet moved |
| what it granted | `Flight.stats().catchUpSeconds` → `Weapon.stats().flightCatchUpSeconds` | the number a harness run reads. Mirrored, never written twice |
| the one call site | `src/server/Weapon/init.luau` → `flight:launch(…, Weapon.catchUpFor(player, nil, CONFIG))` in the fire-request path | one production `Flight.new(CONFIG)` instance, one launch site |

**Why here and not somewhere else.** §1.2's neighbouring rule — *"No second writer of hits"* — is the
argument for keeping it where the hit already lives. The catch-up is not a teleport: it is the same
simulation run for longer, through the same sub-stepped **segment** casts, so a bullet caught up into
a tree trunk still stops at the trunk and a bullet caught up into an animal still hits the animal
(`weapon_hits.spec`, "CANNOT TUNNEL: a wall between the muzzle and the animal still stops the
caught-up shot"). A correction that needed a target's position, a client timestamp or a clock of its
own would need a different owner, and would be the rewind §1.2 forbids. **This one needs nothing the
weapon does not already own and adds no writer anywhere else:** no boar state is read, no position is
stored, `Boar.Body` is still the only store of where an animal is, and nothing under `src/client/`
knows this mechanism exists.

`docs/design/shotgun.md` §11.1 item 3 states the same table from the weapon's side; the two must stay
in step, and the single source for both is this section plus
`docs/research/2026-10-24-real-shooting.md` §5.

### 2.1 Files on disk

```
src/shared/Ballistics/
  init.luau                  -> ReplicatedStorage.Ballistics        (NEW: frozen numbers + pure maths)
src/shared/Shotgun/
  init.luau                  -> ReplicatedStorage.Shotgun           (+3 ballistic rows, +4 flight numbers,
                                                                     + ShotLanded in remotes())
  Remotes.model.json         -> ...Shotgun.Remotes                  (+1 RemoteEvent: ShotLanded)
src/shared/Rifle/init.luau   -> ReplicatedStorage.Rifle             (+3 ballistic rows)
src/shared/Weapons/init.luau -> ReplicatedStorage.Weapons           (+3 fields on Row, built from each CONFIG)
src/server/Weapon/
  Flight.luau                -> ServerScriptService.Weapon.Flight   (NEW: the live projectiles)
  init.luau                  -> ServerScriptService.Weapon          (the Heartbeat; launch instead of resolve)
  Hits.luau                  -> ...Weapon.Hits                      (`resolve` ARCHIVED; `targetOf`/`group` unchanged)
src/client/Weapon/
  init.luau                  -> PlayerScripts.Weapon                (+1 remote connection)
  Effects.luau               -> PlayerScripts.Weapon.Effects        (+`playLanded`; `play` unchanged)
tests/server/ballistics.spec.luau   (NEW, pure)
tests/server/weapon_hits.spec.luau  (the Flight cases, over the injected cast and an injected dt)
tests/server/weapon_shot.spec.luau  (the sight-line case waits for the flight to drain)
tests/server/rifle.spec.luau        (the three new row fields, field by field)
tests/client/weapon_client.spec.luau (the new remote, and what Effects draws)
tests/client/shoot_boar.spec.luau   (leads the boar — section 11.4)
tools/studio_mcp.py                 (BLAST_RADIUS + SCOPE_SPECS rows — section 12)
backups/2026-10-14-hitscan-resolve.md  (the archived `Hits.resolve`, rule 7)
```

**v2, Task 256 adds NO file.** It changes `src/shared/Shotgun/init.luau` (two config rows),
`src/server/Weapon/Flight.luau` (the fourth argument, `live.catchUp`, `Flight.substeps`,
`catchUpSeconds`), `src/server/Weapon/init.luau` (`Weapon.catchUpFor`, the call site,
`stats.flightCatchUpSeconds`) and two server specs. No new folder, no project edit, no `rojo serve`
restart, no Connect click.

`ReplicatedStorage.$path` is `src/shared` in `default.project.json`, so **a new folder under
`src/shared/` needs no project edit** — and therefore no `rojo serve` restart and no Connect click
from Karen. Likewise `src/server/Weapon/Flight.luau` is a child of an existing folder module.
`Remotes.model.json` DOES change, and that is a `.model.json` whose contents Rojo live-syncs, so it
needs no restart either; the harness compares it child by child.

**`Hits.resolve` is archived, not kept.** It is the hitscan resolver: one cast per direction, the
whole range, in one frame. Leaving it callable beside the stepper is two answers to "where did the
bullet go" in one folder, which is the exact failure `docs/PROJECT_CONTEXT.md` records ("two systems
wrote the creature's position... two correct pieces of code disagreeing"). Rule 7: it is written into
`backups/2026-10-14-hitscan-resolve.md` with the commit that had it and the reason, and removed from
the module. `Hits.targetOf` and `Hits.group` are **untouched**.

---

## 3. The data: which number lives where

### 3.1 Three new numbers per weapon, per ammo — in each gun's own CONFIG

Keyed by `AmmoKind`, like `RANGE_STUDS`, so nothing branches on ammo. The unit is in the name, which
is this repo's rule since Task 150 (`SPOOK_M`/`SPOOK_STUDS`, `SPREAD_FULL_DEG`, `RANGE_STUDS`).

| Field | Unit | `Shotgun.CONFIG` | `Rifle.CONFIG` |
|---|---|---|---|
| `MUZZLE_STUDS_PER_S` | studs/s | `{ Slug = 1752, Buck = 1442 }` | `{ Slug = 2612 }` |
| `DRAG_PER_STUD` | 1/stud | `{ Slug = 1.059e-3, Buck = 2.631e-3 }` | `{ Slug = 4.29e-4 }` |
| `ZERO_STUDS` | studs | `{ Slug = 180, Buck = 70 }` | `{ Slug = 714 }` |

### 3.2 The numbers for the SYSTEM — in `Shotgun.CONFIG`, not in a row

The rule `src/shared/Weapons/init.luau` already states in its header: *"the safety arc, the camera
origin tolerance, the rate limits, `AUTO_EQUIP` and `shouldArm` are rules of the DRIVE and of the
PROTOCOL, not properties of a gun... A per-weapon `SAFETY_ARC_HALF_DEG` would let a new weapon widen
its own licence"*. How finely the server integrates, how many pellets it will carry at once, and
**how much of a shooter's connection it is willing to give back** are properties of the SERVER. A
per-weapon step cap would let a new gun buy itself more server time; a per-weapon catch-up cap would
let a new gun buy its owner more free lead.

| Field | Value | What it is |
|---|---|---|
| `FLIGHT_STEP_MAX_SECONDS` | `1/30` | the longest sub-step; a longer `dt` is split |
| `FLIGHT_MAX_SUBSTEPS` | `8` | how much catch-up one Heartbeat may buy (0.267 s) |
| `FLIGHT_MAX_SECONDS` | `2.0` | the hard ceiling: a projectile older than this is resolved as a miss and counted |
| `FLIGHT_MAX_LIVE_PELLETS` | `512` | the global cap on live projectiles |
| **`FLIGHT_CATCHUP_MAX_SECONDS`** *(v2)* | `0.15` | **the bound on forward prediction.** 0.15 × `Boar.CONFIG.SPRINT_SPEED` (38) = **5.7 studs**, about one `BODY_SIZE` (5.5) — the most a mistake here may ever be worth. It fits the existing budget rather than widening it: `Flight.substeps(1/60 + 0.15)` is 5 of the 8 `FLIGHT_MAX_SUBSTEPS`, and 0.15 is far under `FLIGHT_MAX_SECONDS`. §5.1 item 4 |
| **`FLIGHT_CATCHUP_PING_FACTOR`** *(v2)* | `1.0` | **the conversion from `Player:GetNetworkPing()` to the correction**, and the one genuinely uncertain number in the system: the engine's docs do not say whether their number is the round trip or one way. A row and not a literal, for the reason `GRAVITY_SCALE` is one. §5.1 item 6 |

Both new rows sit in `Shotgun.CONFIG` beside the other four, where `Flight` already reads its limits
(`self._config`), so a spec reaches both at values the shipped game never produces.

### 3.3 Gravity — derived once, in `Ballistics`, from `Report.CONFIG.METRES_PER_STUD`

```luau
Ballistics.CONFIG = {
    METRES_PER_STUD      = Report.CONFIG.METRES_PER_STUD,   -- 0.28
    GRAVITY_M_PER_S2     = 9.81,
    GRAVITY_STUDS_PER_S2 = 9.81 / Report.CONFIG.METRES_PER_STUD,  -- 35.0357...
}
```

`ReplicatedStorage.Report` requires nothing, so this is a leaf dependency and cannot cycle. It is the
one metre/stud conversion in the repo (`Horn.CONFIG`, `Boar.CONFIG.SENSE` and `ForestTest.SPOOK` all
publish the same 0.28 and `tests/server/zz_horn.spec.luau` asserts they agree). **No other module
multiplies by `METRES_PER_STUD` and no other module writes a gravity**, which is `Horn.spookStuds`'s
rule applied to a second quantity.

`g` is a **parameter with a default** on every function that uses it, for the reason
`Weapon.equipDelayFor` and `Weapons.loadoutFor` state: a constant that can only be read at one value
cannot be tested at another. *(v2: `Weapon.catchUpFor`'s `ping` parameter is the same discipline
applied to the engine's ping — and in that case it is not a convenience but the only way to reach the
function's interesting half at all, because a loopback session reads 1–2 ms.)*

---

## 4. Public interface

### 4.1 `ReplicatedStorage.Ballistics` — pure, no state, no clock

```luau
export type Shot = { v0: number, k: number, zeroStuds: number }

Ballistics.CONFIG                                        -- section 3.3, deep-frozen

Ballistics.shotFor(row: any, ammo: string): Shot?
    -- the three numbers off a Weapons.Row, as one frozen table. nil when the row does not carry
    -- all three for that ammo. nil is a DATA FAULT, never a fallback (section 6.5).

Ballistics.timeToRange(shot: Shot, studs: number): number
    -- (exp(k*s) - 1) / (k*v0). Seconds to travel `studs` of path. s <= 0 -> 0.

Ballistics.speedAt(shot: Shot, studs: number): number    -- v0 * exp(-k*s)

Ballistics.dropAt(shot: Shot, studs: number, g: number?): number
    -- 0.5 * g * timeToRange(s)^2 : studs BELOW the launch line at that range. Always >= 0.

Ballistics.elevationTangent(shot: Shot, g: number?): number
    -- dropAt(zeroStuds) / zeroStuds. The tangent of the launch elevation. zeroStuds <= 0 -> 0.

Ballistics.launchDirection(aim: Vector3, shot: Shot, g: number?): Vector3
    -- the unit launch direction: (aim.Unit * zeroStuds + Vector3.yAxis * dropAt(zeroStuds)).Unit
    -- The velocity is this times v0; the PATTERN is built around this, so one function answers
    -- both and there is no second elevation. `aim` straight up is not degenerate: the result is
    -- `aim` (no elevation is possible, and none is wanted).

Ballistics.sightOffsetAt(shot: Shot, studs: number, g: number?): number
    -- studs ABOVE (+) or BELOW (-) the sight line at that range:
    -- elevationTangent * studs - dropAt(studs). Exactly 0 at the zero. This is the quantity a
    -- player feels, and it has one definition so no spec re-derives the sign.

Ballistics.advance(p: Vector3, v: Vector3, dt: number, shot: Shot, g: number?): (Vector3, Vector3)
    -- ONE step (section 5). Returns the new position and the new velocity. Two return values and
    -- no table, so stepping allocates nothing.
```

Every function is a pure function of its arguments. Nothing in this module reads a clock, a service,
`Workspace` or a `Player`. `Ballistics.CONFIG` is deep-frozen with `Shotgun.deepFreeze`, which is
what `Shotgun.CONFIG`, `Weapons.ROWS` and `Report.CONFIG` already do.

**`Ballistics` is untouched by v2.** The lag correction is a span of time handed to the stepper; the
maths of a projectile does not know it exists.

### 4.2 `ServerScriptService.Weapon.Flight` — the live projectiles

```luau
export type Impact = Shotgun.Impact   -- { instance, position, normal, distance }

export type ShotRecord = {
    shooter: Player,            -- may have left, died or been revoked by the time it lands
    shooterUserId: number,      -- taken at the TRIGGER, so a departed shooter is still identifiable
    weapon: string,             -- the Weapons.WeaponId
    ammo: string,
    muzzle: Vector3,
    ignore: { Instance },       -- the SAME table the trigger built; never modified afterwards
    rangeStuds: number,
    firedAt: number,            -- os.clock() at the trigger. This becomes HitReport.at.
    epoch: number,              -- the gun's epoch at the trigger, for the record only (section 6.4)
}

export type Resolution = { shot: ShotRecord, impacts: { Impact } }

Flight.new(config: any?): Flight      -- nil means Shotgun.CONFIG. One per owner; a spec makes its own.

Flight:launch(shot: ShotRecord, directions: { Vector3 }, ballistic: Ballistics.Shot,
              catchUpSeconds: number?): number
    -- one projectile per direction, each with v = direction.Unit * ballistic.v0, p = shot.muzzle.
    -- Returns how many were launched. 0 means the global cap refused it, and then the shot is
    -- resolved with no impacts on the next `advance` -- a refusal is a miss, never a silent nothing.
    --
    -- (v2, Task 256) `catchUpSeconds` is THE FOURTH ARGUMENT: the shooter's lag correction in
    -- seconds, OPTIONAL. nil or 0 is every caller written before Task 256 and is bit-for-bit
    -- today's flight. It is CLAMPED HERE, at the one door into the module, to
    -- [0, FLIGHT_CATCHUP_MAX_SECONDS] -- so no caller can hand in a negative (a bullet that starts
    -- in the past), a NaN, or an unbounded one. A shot the global cap REFUSED is granted 0: it has
    -- no projectiles to advance, and crediting it would put a number in `catchUpSeconds` that
    -- bought nothing.

Flight.substeps(total: number, config: any): (number, number)        -- (v2) NEW, PURE, static
    -- how a span of time is cut: subs = clamp(ceil(total / FLIGHT_STEP_MAX_SECONDS), 1,
    -- FLIGHT_MAX_SUBSTEPS), step = min(total / subs, FLIGHT_STEP_MAX_SECONDS). total <= 0 -> (1, 0).
    -- Exported because the catch-up made the split a PER-SHOT question, and two copies of this
    -- arithmetic would be two answers to how far a bullet moved. NO SUB-STEP IS EVER LONGER THAN
    -- THE CAP, and that `min` is the whole of "the remainder past the cap is discarded".

Flight:advance(dt: number, cast: Shotgun.CastFn): { Resolution }
    -- steps every live projectile (section 5) and returns one Resolution per shot whose LAST
    -- projectile resolved -- hit, out of range, or out of time. Shots still in the air are not in
    -- the list. The returned table is fresh; its `impacts` are Flight's, handed over and then
    -- forgotten.
    --
    -- (v2) Each live shot advances by `dt + live.catchUp`, and `live.catchUp` is set to 0 as it is
    -- read -- SPENT ONCE, however many Heartbeats the shot lives for. The split is therefore
    -- computed PER SHOT, through `Flight.substeps`, and the catch-up goes through the SAME
    -- sub-stepped segment casts as any other span of time.

Flight:count(): number        -- live projectiles. The leak instrument.
Flight:shots(): number        -- shots still in the air.
Flight:stats(): { launched: number, resolved: number, timedOut: number, refused: number,
                  casts: number, catchUpSeconds: number }
    -- (v2) SIX fields. `catchUpSeconds` is the total this instance has GRANTED, summed over the
    -- shots that actually launched -- the only instrument anybody has for what the correction is
    -- buying on a real server.
```

`Flight` requires `ReplicatedStorage.Ballistics` and `ReplicatedStorage.Shotgun` (for the types) and
nothing else. **It does not require `RunService`, `Workspace`, `Players` or `Weapon`.** In particular
it **does not read `Player:GetNetworkPing()`**: it receives a number of seconds, already measured, and
its only opinion about it is the clamp.

### 4.3 `ServerScriptService.Weapon` — what changes

```luau
-- unchanged, and the Reviewer should check they are: start, grant, revoke, forget, getSnapshot,
-- stats, markHit, refreshArming, refillForDrive, armingAction, reachable, roundsLeft, heldId,
-- rowOf, setCast, setDriveLineProvider, setArmingPolicy, setTargetProvider, setStandProvider,
-- setLicenceProvider, setEntitlementProvider, setDriveOpenProvider, onActionRequest, runCycle,
-- HitReported, SafetyViolated, ShotFired.

Weapon.Flight = Flight          -- the MODULE, exported for specs: the Registry/Pattern/Hits idiom
Weapon.Ballistics = Ballistics  -- likewise, so a spec reaches it without a second require path
Weapon.flightCount(): number    -- the live instance's projectile count. READ ONLY.
Weapon.flightShots(): number    -- shots in the air. READ ONLY.

-- (v2, Task 256)
Weapon.catchUpFor(player: Player?, ping: number?, config: any?): number
    -- THE ONE THING THAT COMPUTES THE CORRECTION, and the only reader of `Player:GetNetworkPing()`
    -- in `src/` (a grep must find one site, in this function). `ping` is a PARAMETER WITH A
    -- DEFAULT: supplied, the function is pure and both readings of the engine's number are
    -- reachable from a spec; omitted, it reads the player's ping inside a `pcall`.
    -- Returns clamp(seconds * FLIGHT_CATCHUP_PING_FACTOR, 0, FLIGHT_CATCHUP_MAX_SECONDS).
    -- A nil player, a failed read, a non-number, a NaN, a negative or a zero returns 0 -- never a
    -- fallback guess, because 0 is exactly today's behaviour.
```

`Weapon.stats()` gains `inFlight`, `shotsResolved`, `flightTimeouts`, `flightRefused` and
`noBallistics`, **and (v2) `flightCatchUpSeconds`**, mirrored off `Flight.catchUpSeconds` so one
`stats()` still answers everything and the number is written in one place. `stats.shots` keeps its
meaning — accepted trigger pulls — so `shots` now leads `shotsResolved` by up to 0.37 s, and that is
the instrument for "a shot that never landed".

**There is no `Weapon.advanceFlight` and no way to step the live flight from outside.** The one
caller of `flight:advance` is the Heartbeat in `Weapon.start`; a grep for `flight:advance` under
`src/` must find one site. Exporting a second driver would let a spec and the Heartbeat step the same
list in the same frame, which is a second writer bought for nothing: a **pure** spec makes its own
`Flight.new()`, and a **live** spec waits on `Weapon.flightCount()`. **The same holds for the
correction (v2): there is no setter for it, no remote that carries it and no way for a client to
influence it.** The one production call site is `flight:launch(…, Weapon.catchUpFor(player, nil,
CONFIG))` inside the fire-request path.

### 4.4 The remotes — six, not five

`Shotgun.remotes()` gains one entry and `Remotes.model.json` one child:

```json
{ "name": "ShotLanded", "className": "RemoteEvent" }
```

```luau
-- server -> ALL clients, once per RESOLVED shot, fired by ServerScriptService.Weapon alone:
{ shooterUserId: number, impacts: { Vector3 } }
```

One way. It carries no target, no zone, no damage and no state — it is where the dust goes, and
nothing else. The client never fires it. **v2 adds no remote and no field:** the lag correction is
server-side arithmetic and nothing about it crosses the wire in either direction.

---

## 5. The step, written out

Per live projectile, per sub-step, with `up = Vector3.yAxis`:

```
a  = -g * up - k * |v| * v
p' = p + v*dt + 0.5*a*dt^2
v' = v + a*dt
impact = cast(p, p' - p, shot.ignore)          -- the SEGMENT just travelled
```

- **A hit** is the first thing the segment met. The projectile is retired, and its `Impact` is
  appended to the shot's list with **`distance` rewritten to `travelled + impact.distance`** — path
  studs from the muzzle (section 1.1 item 7). `position` and `normal` are the cast's, unchanged.
- **No hit:** `p, v = p', v'`; `travelled += |p' - p|`; `elapsed += dt`.
- **The range cap:** `travelled >= shot.rangeStuds` retires the projectile with no impact. This is
  the same `RANGE_STUDS[ammo]` the hitscan path used, so "how far a shot reaches" is unchanged. The
  cap is **exact**, not "whichever sub-step first overshot it": a step that would carry the
  projectile past its range casts only the piece that is left and retires either way.
- **The flight ceiling:** `elapsed > FLIGHT_MAX_SECONDS` retires it with no impact and counts
  `timedOut`. Nothing legitimate reaches it (section 10), so a non-zero counter is a bug, said out
  loud rather than leaked.
- **A shot resolves** when its last projectile has retired. The owner is handed one `Resolution`.

**`dt` and the split.** The split is `Flight.substeps(total, config)` and nothing else computes it
(v2, §4.2): `n = clamp(ceil(total / FLIGHT_STEP_MAX_SECONDS), 1, FLIGHT_MAX_SUBSTEPS)` sub-steps of
`min(total / n, FLIGHT_STEP_MAX_SECONDS)` — equal sub-steps, so the simulated clock and the real one
agree whenever `n` is not capped. Beyond the cap the remainder is **discarded**: on a hitch longer
than 0.267 s a projectile arrives slightly late rather than the server casting hundreds of rays in
one frame. That is a deliberate, stated degradation, and it cannot leak a projectile because
`travelled` and `elapsed` still rise on every sub-step. The `min` is the whole of "discarded", and it
is there because without it a 0.5 s `dt` took eight 62.5 ms steps — longer than the cap, throwing away
the two guarantees the cap exists for, on the frame already in trouble (`weapon_hits.spec`, "discards
the rest past the cap").

**Why a long `dt` cannot tunnel through a wall, and what it actually costs.** The cast is of the
segment, so for *any* `dt` the first solid thing on the chord is found — FastCast's whole point
(source A). What a long step really costs is two things the cap is sized against:

- **the chord instead of the arc.** The sag inside one step is at most `0.5*g*dt²`: at `dt = 1/60`
  that is **0.0049 studs**; at the cap `1/30`, **0.019 studs**; at a 0.25 s hitch, **1.10 studs**.
- **time resolution against a moving animal.** A boar at `Boar.CONFIG.SPRINT_SPEED = 38` studs/s
  moves **0.63 studs** in 1/60 s, **1.27 studs** at the cap, **9.5 studs** in 0.25 s. A boar's trunk
  is about 4 studs long, so 1.27 studs is well inside the body and 9.5 studs is the feature broken.

`1/30` is therefore the cap: half a frame of a 60 Hz server's worst normal frame, one third of a boar
at a sprint, and 0.019 studs of path error.

### 5.1 The lag correction: forward prediction of the shot, bounded (v2, Task 256)

**This is the Director's decision of 2026-10-24** (`reviews/task-256/BRIEF.md` §1), and it is not
re-opened here: *"forward prediction of the shot by the shooter's measured one-way delay
(`FLIGHT_CATCHUP_PING_FACTOR`, shipped at 1.0) is ALLOWED, because it preserves the lead. What the
designs forbid, and still forbid, is REWINDING targets (that deletes the lead Karen asked for)."*

**1. Rewinding targets is still forbidden, for the reason it was always forbidden.** §1.2 keeps the
sentence it has always kept — *"No lag compensation. Rewinding hitboxes exists to remove the feeling
Karen asked for"* — and §9 source B keeps its verdict: *"per-target position history, a trusted client
timestamp and a rewind window — and it exists to defeat exactly the feeling Karen asked FOR.
Lag-compensated hitscan removes lead."* Both hold. A rewind would also be a second store of where
each animal was, and `Boar.Body` is the one writer and one store of that
(`docs/PROJECT_CONTEXT.md`: *"two systems wrote the creature's position"*).

**2. Forward prediction of the shot is ADOPTED, because it is the opposite mechanism with the
opposite effect.** It advances **the projectile**, by the shooter's measured delay, at launch. It
touches no target, keeps no history, reads no client clock and rewinds nothing — so **it preserves
the true lead and removes only the ping.** That is what *"like in real life"* means arithmetically
(Karen, 2026-10-24: *"all shooting has to be like in real life / this is a key of this game"*): the
lead a player must learn becomes `Ballistics.timeToRange × the animal's speed`, the real lead,
instead of the real lead plus his own connection. §9 source B's own closing sentence was already half
of this answer — *"Source's own projectile classes are not lag-compensated, and that is the shape we
want."* Our projectile classes are not lag-compensated either; **the launch is.**

**The error it removes, derived** (`docs/research/2026-10-24-real-shooting.md` §5.1). Let `L` be the
one-way trip. The client draws the animal at `P(t − L)`; the player leads by the flight time and
clicks at `P(t − L) + tof·v`; the request arrives at `t`, the server launches, the bullet arrives at
`t + tof` when the animal is at `P(t + tof)`. The miss is `L·v` per trip, and the player feels the
full round trip **`2L·v`** — once because his click took `L` to arrive, once because the picture he
aimed at was already `L` old. Measured against the true lead:

| one-way `L` | boar at `SPRINT_SPEED` (10.6 m/s) | deer (15 m/s) | against the rifle's true 91 cm lead at 60 m |
|---|---|---|---|
| 30 ms | 32 cm | 45 cm | +35 % |
| 60 ms | 64 cm | 90 cm | **+70 %** |
| 100 ms | 106 cm | 150 cm | +116 % |

**3. Where it lives, and why that is not "a fudge inside the weapon".** §2.2 is the table of pieces.
The owner does not move: it is `ServerScriptService.Weapon`, the same single writer that already
decides what a shot hit. `docs/design/shotgun.md` §11's v3 wording — *"never a fudge inside the
weapon"* — was written against a **rewind** smuggled into the shot path, and what ships is not that:
the correction is **one multiplication into a loop `Weapon.Flight` already runs, over the cast seam
the system already has**, sub-stepped by the same `Flight.substeps` and cast as the same segments.
§1.2's neighbouring rule, **"No second writer of hits"**, is the positive argument for keeping it
here: moving it elsewhere would create a second thing with an opinion about where a projectile is.

**4. The bound, and why it exists.** `FLIGHT_CATCHUP_MAX_SECONDS = 0.15`. Unbounded forward
prediction is the one way this mechanism can be abused: a 400 ms client would reach a third of a
second into the future and collect free lead that other players would see as a shot which hit nothing
(source F's own objection). 0.15 s covers a bad connection and caps the reach at **5.7 studs on a
sprinting boar — about one `BODY_SIZE` (5.5)**, which is the most a mistake here may ever be worth.
It also fits the existing flight budget rather than widening it: `Flight.substeps(1/60 + 0.15)` is 5
of the 8 `FLIGHT_MAX_SUBSTEPS`, and 0.15 s is far under `FLIGHT_MAX_SECONDS = 2.0`, so **no number
above this section moves.** It is clamped twice — in `Weapon.catchUpFor` and again in
`Flight.launch`, at the one door into the module. **It is invented, it is the only invented number in
this mechanism**, and it says so here, in `Shotgun.CONFIG`'s own comment, and in
`docs/research/2026-10-24-real-shooting.md` §5.4.

**5. The limit, which is a real property of the mechanism and was found by measurement, not by
reasoning.** **Forward prediction can only give back time the bullet actually SPENDS in the air.** If
the round trip exceeds the flight time, the bullet reaches the animal's distance before the world has
caught up with the picture the player aimed at, and there is no flight left to spend — so the
correction is **partial**. This was not anticipated when the mechanism was designed: the first version
of the spec asserted a hit at every range and **failed at the shortest one**, which is how it is known
(research note §5.5; simulated against the real stepper, rifle, boar at `SPRINT_SPEED`, 100 ms round
trip):

| range | flight time | ping error | miss, uncompensated | miss, compensated |
|---|---|---|---|---|
| 179 studs (50 m) | **71 ms** *(< 100 ms)* | 3.80 studs | 4.26 studs | **1.73 studs — still a miss** |
| 357 studs (100 m) | 148 ms | 3.80 | 3.89 | **0.10 — a hit** |
| 536 studs (150 m) | 231 ms | 3.80 | 3.90 | **0.11 — a hit** |
| 714 studs (200 m) | 320 ms | 3.80 | 4.31 | **0.51 — a hit** |

So the correction is **exact beyond about 100 m and partial inside it**, and even at 50 m it cuts the
miss by 59 % (1.19 m → 48 cm, about one chest zone on a boar). **This is in the design because it is a
thing a player can feel:** close shots on fast animals will still read slightly behind. It is the
right way round — the shortfall is largest where the lead is smallest, so what is left over is a
fraction of a small number — and **nothing can be done about it inside this mechanism**, because
giving back more time than the bullet flies means resolving against a rewound world, which is item 1.
If Karen reports that close fast shots still feel behind, that table is the starting point of
reopening the trade, not a bug report (§16, Karen 8). The case is asserted by name, so the degradation
is a number in the harness rather than a sentence in a document: `weapon_hits.spec`, **"CANNOT GIVE
BACK MORE PING THAN THE BULLET SPENDS IN THE AIR, and that is stated"**.

**6. The one uncertain number, carried as a data row.** `Player:GetNetworkPing()`'s own documentation
says only *"the network ping in seconds"* and **does not state whether that is the round trip or one
way**, while the derivation in item 2 shows the correction wanted is the **round trip** (`2L`). That
ambiguity is therefore the config row **`FLIGHT_CATCHUP_PING_FACTOR`, shipped at the conservative
1.0** — treat the engine's number as the round trip, because over-correcting hands out free lead
while under-correcting merely leaves some of today's error in place. **2.0 is the value if it turns
out to be one way.** It **cannot be settled on this PC:** a loopback Studio Play session reads
**1–2 ms**, measured in round 2 at **1.70 ms of total compensation across one run's shots** — 0.065
studs on a sprinting boar, far too small to tell 1.0 from 2.0. It needs a real server and it is the
Director's to confirm (§16, Director 9). *(`reviews/task-256/BRIEF.md` item 6 quotes "0.51 ms per
shot"; the measured figure in the research note §5.5 is **1.70 ms total**, and 0.51 is the studs value
in that section's 200 m row. Recorded here because a design must carry the number that was actually
measured.)*

**What it is NOT, said once.** No position history. No client timestamp. No second clock. No new
remote and no new field on an existing one. No feature flag — `catchUpSeconds = 0` and
`FLIGHT_CATCHUP_PING_FACTOR = 0` each reproduce today's flight bit for bit, so the off state is
reachable by data and by parameter without a second code path. No cost outside the launch frame:
`Flight.substeps(1/60 + 0.15)` is 5 sub-steps where `1/60` alone is 1, so the correction adds **at
most 4 extra segment casts per pellet, once per shot** (≤ 36 for buckshot), and nothing at all on
every later Heartbeat because `live.catchUp` is spent once.

---

## 6. The life of one shot

### 6.1 At the trigger — unchanged up to the pellets

`onFireRequest` keeps every step of `docs/design/shotgun.md` 5.5 in the same order: rate limit →
weapon id and row → `Validator.checkShot` → `StateMachine.apply{Fire}` → muzzle → the aim ray and
`aimPoint` → `aim` (with the `MIN_AIM_DISTANCE` guard) → `Rules.refuse` → `setState(fired)`.

Then, instead of `Hits.resolve` + `Hits.group`:

```luau
local ballistic = Ballistics.shotFor(row, ammo)
if ballistic == nil then                       -- a DATA fault, not a shot (section 6.5)
    publish(player, id, state)                 -- `state`, not `fired`: the shell is NOT spent
    stats.noBallistics += 1
    return "no-ballistics"
end
local bore = Ballistics.launchDirection(aim, ballistic)
local directions = Pattern.directions(ammo, bore, rng, row)
flight:launch({ shooter = player, shooterUserId = player.UserId, weapon = id, ammo = ammo,
                muzzle = muzzle, ignore = ignore, rangeStuds = range,
                firedAt = now, epoch = fired.epoch }, directions, ballistic,
              Weapon.catchUpFor(player, nil, CONFIG))   -- (v2, Task 256) the fourth argument
stats.shots += 1
```

**The elevation is applied ONCE, to `aim`, before the pattern.** The cone then spreads around the
elevated bore, which is what a real elevated barrel does, and `Pattern.directions` is untouched. The
alternative — pattern first, then elevate nine directions — is nine elevations and a second place for
the sign to be wrong.

**(v2) The catch-up is measured here and nowhere else**, in the frame the request arrived, which is
the only frame in which the shooter's delay is the delay of *this* shot. It is one argument on one
call. Nothing else in this handler changes.

Everything after that in the handler is **exactly as it is today and in the same frame**:
`SafetyArc.isForbidden(aim, line, CONFIG.SAFETY_ARC_HALF_DEG)` with `stopAt` still the
muzzle-to-aim-point distance; `publish(player, id, fired, true)`; the `AUTO_CYCLE` bolt spawn keyed
on `fired.epoch`; `Weapon.ShotFired` (the BindableEvent) with `at = aimPoint`, so a boar still hears
the bang and the strike at the trigger; and `ShotFired:FireAllClients` with the muzzle, the barrel,
the `muzzleCFrame` and **`impacts = {}`**.

`onFireRequest` still returns `nil` when the shot was taken. It now means *the shot left the gun*,
which is the only thing knowable in that frame.

### 6.2 In the air

```luau
RunService.Heartbeat:Connect(function(dt)
    local resolved = flight:advance(dt, castFn)
    for _, res in ipairs(resolved) do onShotLanded(res) end
end)
```

One connection for the whole server, made in `Weapon.start` and nowhere else. `castFn` is the same
module local `Weapon.setCast` writes, so a spec's injected cast is used by the flight too — which is
what makes section 11.2's assertions possible. **(v2) The catch-up is spent inside the first
`advance` a shot sees**, added to that shot's own `dt`, which is why the sub-step split is per shot
and not per frame; this Heartbeat is unchanged.

### 6.3 When it lands

```luau
local function onShotLanded(res)
    local reports = Hits.group(res.shot.shooter, res.impacts, res.shot.ammo,
                               res.shot.firedAt, res.shot.weapon)
    stats.shotsResolved += 1
    stats.reports += #reports
    for _, report in ipairs(reports) do
        hitSignal:Fire(report)
        Weapon.markHit(res.shot.shooter, "hit", report.zone)
    end
    local channel = remotes or Shotgun.remotes()
    channel.ShotLanded:FireAllClients({ shooterUserId = res.shot.shooterUserId,
                                        impacts = positionsOf(res.impacts) })
end
```

- **The group is formed when the shot's LAST projectile has resolved.** So today's contract is
  preserved exactly: nine pellets on one boar is **ONE** `HitReport` with `pellets = 9`, never nine.
  `HitLog`, `Match`, `ForestTest` and the hit marker all depend on that and none of them changes.
- **`report.at` is the SHOT's time** (`res.shot.firedAt`), not the arrival's. `HitLog.recordHit` uses
  it as "when in this drive was this shot taken" (`at = report.at or now`, then
  `sinceOpen`), and that is the question the drive report asks. A 0.3 s change there is invisible; a
  report with two clocks in it is not. `Hits.group` already takes `now` as a parameter, so this is a
  decision, not an accident. **(v2) The catch-up does not touch it either:** it moves the bullet, not
  the clock the report is stamped with.
- **`markHit` arrives when the bullet does**, which is correct: the tick is the confirmation that
  something was hit, and it was not hit yet.

### 6.4 The shooter dies, is revoked, respawns or leaves between the trigger and the arrival

**The bullet still flies and still hits.** It has left the gun. `Flight` does not look at `epoch`,
at the player's character, at the gun or at the registry. **(v2) Nor at the player's ping:** the
correction was measured at the trigger and is a number on the record, so a shooter who leaves
mid-flight cannot make `Flight` touch a `Player` object.

That is the deliberate opposite of `runCycle`, which *does* check `epoch` before every step and
abandons the sequence — because that is the GUN's own movement, and a gun that has been destroyed has
no bolt to work. `epoch` is on the record for the report only.

What follows, explicitly:

- **`HitReported` still fires**, so the boar is still damaged and the hit is still recorded.
  `MatchBoot`'s listener already tolerates a shooter with no character (`local root = character and
  character.PrimaryPart`, `shooterPosition = root and root.Position`), and `HitLog` and `Score` key
  by `shooterUserId`, which was taken at the trigger.
- **The hit MARKER to a player who has gone is dropped.** `Weapon.markHit` gains one clause beside
  the two it has: a `Player` whose `Parent` is `nil` has left `Players`, and `FireClient` to it is
  meaningless. One line, in the same owner, in the function that already guards "a player who left
  mid-shot".
- **`Weapon.forget` is unchanged and defect (c) is unaffected.** The claim it asserts is that no table
  in this system is *keyed by* that player; `Registry:count()` is what `weapon_state.spec` reads.
  `Flight` is keyed by shot, holds at most `FLIGHT_MAX_SECONDS` of records, and drains on its own —
  so it is a queue, not a registry. Section 11.2 asserts it drains.
- **A tied shooter's penalty has already happened**, at the trigger, which is brief 1.10.

### 6.5 A row with no ballistic numbers

`Ballistics.shotFor` returning `nil` **refuses the shot** (`"no-ballistics"`), publishes the UNFIRED
state so the shell is not spent, counts it and warns once. It does not fall back to a straight line:
a fallback would be a second answer to "where did the bullet go", reachable by a typo in a data table.

This is the rule `onFireRequest` already applies to a gun with no muzzle: *"no muzzle is a HARDWARE
fault, and the player should not pay for one."* Both shipped rows carry all three numbers and
`rifle.spec` asserts it field by field, so the branch is unreachable in the shipped build — which is
the point.

**(v2) The same rule, in its gentlest form, for a ping that cannot be read.** `Weapon.catchUpFor`
returns **0** for a nil player, a `pcall` that failed, a non-number, a NaN, a negative or a zero. 0 is
exactly today's behaviour, so a failure to measure latency costs a player nothing but the correction
he could not be given — **the failure mode of this whole feature is "the game shoots as it did
yesterday"**. It does not refuse the shot, because unlike a missing muzzle velocity a missing ping is
not a data fault: it is an absent measurement, and the game is playable without it.

---

## 7. The dust where the shot lands — option (b), decided

`ShotFired` carries `impacts` today and `Effects.play` draws a tracer bar and an impact cube from each
one. With flight those positions do not exist at the trigger. The brief offered three options.

**Adopted: (b) one new RemoteEvent, `ShotLanded`, fired when the shot resolves, from which `Effects`
draws the impact cubes and no tracer.**

Why:

1. **It is honest.** The bang is now and the dust is when the bullet arrives. That is also the one
   thing on screen that tells a player the shot takes time, without a tracer and without a number.
2. **(a) is a visible regression** — the only mark a miss leaves today is that cube, and a player
   with no feedback at all cannot tell "I missed" from "the gun did nothing", which is the exact
   complaint that produced the hit marker in Milestone 1.5.
3. **Nothing moves to the new remote that should stay at the trigger.** `ShotFired` keeps the muzzle,
   the barrel and the `muzzleCFrame`, so the flash, the smoke, the sound and
   `Weapon.Fired → Camera.kick` are untouched, in the same frame, from the same payload.
4. **It keeps the tracer code dead rather than wrong.** `Effects.play` already reads
   `payload.impacts or {}`, so with an empty list it draws the flash and the smoke and never enters
   the tracer branch. **`Effects.play` therefore needs no change at all.** If Karen ever asks for a
   tracer, its honest home is a drawn path from the same `Ballistics` arithmetic, and that is a
   separate task — not a bar drawn between two points the bullet never occupied at the same time.

New client function, in the owner that already owns everything in `Workspace.WeaponEffects`:

```luau
Effects.playLanded(payload: any)
    -- one "Impact" Part per position, EFFECT_MAX_PER_SHOT and IMPACT_LIFETIME as today, through the
    -- same `part()` helper and the same Debris call. No Flash, no Smoke, no Tracer, ever.
```

`src/client/Weapon/init.luau` connects `remotes.ShotLanded.OnClientEvent` to it. **It must not fire
`firedSignal`**: `Weapon.Fired` is the recoil/sound trigger (`CameraBoot`), and the kick belongs to
the trigger. A grep for `firedSignal:Fire` in that file must find one site, inside the `ShotFired`
handler.

*(Task 256 part 1 item 5 changes where that dust is PARENTED — onto the part that was hit, with
`LockedToPart`, so it rides a running animal instead of hanging in the air. That is
`src/client/Weapon/Effects.luau` and `docs/research/2026-10-24-real-shooting.md` §8; it changes no
claim in this section and no claim in this design, which is why the brief keeps it out of here.)*

---

## 8. What it reads from and writes to other systems

### 8.1 Reads

| What | From | Its owner |
|---|---|---|
| `METRES_PER_STUD` | `Report.CONFIG` | `ReplicatedStorage.Report` — frozen data, no run-time writer |
| the three ballistic numbers, `RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG` | `Weapons.ROWS` | `ReplicatedStorage.Weapons` — frozen, built from each gun's CONFIG |
| the four flight numbers, **the two catch-up numbers (v2)**, the arc, the limits | `Shotgun.CONFIG` | `ReplicatedStorage.Shotgun` — deep-frozen, no writer |
| **the shooter's network delay (v2)** | `Player:GetNetworkPing()`, inside a `pcall`, **in `Weapon.catchUpFor` and nowhere else in `src/`** | the engine. The client never sends it, so it cannot be spoofed, and nothing on the client reads it |
| where the target IS, right now | `cast(...)` → `Workspace:Raycast` | the world. For a boar that is `ServerScriptService.Boar` (`Boar.Body` moves the trunk with a `LinearVelocity` constraint and the zone parts are welded to it), so the weapon reads **the world through one ray** and never reads boar state |
| `Damageable` / `HitZone` | attributes on the instance the ray met | the target's own owner (`Boar.Body`) — `Hits.targetOf`, unchanged |
| the drive line | `driveLineProvider()` | `ServerScriptService.Match` — injected, unchanged |

**What this system still does NOT read, and must never start reading (v2):** a target's past
position. There is no history buffer anywhere under `src/server/Weapon/`, and §13 item 11 is the grep
that keeps it that way.

### 8.2 Writes

| What | Who reads it | Their owner |
|---|---|---|
| `Weapon.HitReported(report)` — now fired at the ARRIVAL, with `at` = the shot's time | `MatchBoot` → `runtime:takeHit` + `HitLog.recordHit`; `ForestTestBoot` likewise | `ServerScriptService.Boar`, `ServerScriptService.HitLog` |
| `HitMarker:FireClient` — now at the arrival | `PlayerScripts.Hud` | `PlayerScripts.Hud` |
| `ShotLanded:FireAllClients` — **new** | `PlayerScripts.Weapon` → `Effects.playLanded` | `PlayerScripts.Weapon.Effects` |
| `ShotFired:FireAllClients` — unchanged, `impacts` now always empty | `PlayerScripts.Weapon` → `Effects.play`, `Weapon.Fired` → the camera's kick | as today |
| `Weapon.ShotFired` (BindableEvent) — unchanged, at the TRIGGER | `MatchBoot` → `runtime:hearShot(muzzle, at)` | `ServerScriptService.Boar` |
| `Weapon.SafetyViolated` — unchanged, at the TRIGGER | `MatchBoot` → `Match.Penalty` | `ServerScriptService.Match` |
| **`Weapon.stats().flightCatchUpSeconds` (v2)** — mirrored off `Flight.stats().catchUpSeconds` | `weapon_state.spec`, and a harness run's `[catchup]` note | `ServerScriptService.Weapon` — a counter, not a state |

**Nothing else.** This task writes no boar state, no camera, no Hud, no team, no score, no penalty and
no `Tool`. **(v2) The lag correction writes nothing at all outside this system:** one number on a
shot record that is destroyed when the shot resolves, and one counter.

**One consequence, named rather than discovered.** A boar hears the bang at the trigger and takes the
hit 0.1–0.37 s later. That is correct for a real shot and it is below the animal's own reaction path
(`Brain`'s alert delay), so the sprint is already under way when the bullet lands — which is the
feeling asked for. It is decision 9 applied as written; nothing in `src/server/Boar/` changes. *(v2:
the catch-up shortens that gap by up to 0.15 s and cannot reverse it, so nothing in this paragraph
changes either.)*

---

## 9. External sources

### A. FastCast / FastCast Redux — the algorithm, **adopted as a pattern, NOT vendored**

- Docs: <https://etithespir.it/FastCastAPIDocs/>. Docs repo
  <https://github.com/EtiTheSpirit/FastCastAPIDocs> — **licence MPL-2.0**; its README says *"This is
  obsolete"*.
- **Maintenance: not maintained by its author.** The living forks are
  <https://github.com/010DevX101/FastCastRedux> (**MIT-0**, release v13.2.1, 2025-01-25) and
  <https://github.com/Shellworks-Development/FastCast2> (statically typed, parallel Luau).
  Creator Store listing: <https://create.roblox.com/store/asset/4453855787/FastCast-Redux>.
- **Well:** it is the right algorithm and the one every Roblox shooter uses — *"to emulate bullet
  physics and hit detection in pure Lua"*. It splits the line travelled this frame into a segment and
  raycasts that segment, so a fast projectile cannot tunnel a thin wall and a target that moved is
  met where it now is. It takes a velocity and an acceleration, so drop is free.
- **Badly, for us:** it ships as a Roblox model (`.rbxm`), which **this repo bans** — binary,
  unreviewable in a PR; CI and the harness both fail on it (`CLAUDE.md`, "File types in Rojo-owned
  paths"). It is not on Wally, so it cannot be pinned the way TestEZ is. And it is far more than we
  need: `ActiveCast` objects, a `PartCache` cosmetic-bullet system, `CanPierceFunction`, a
  `LengthChanged` signal per segment per frame, its own `RunService` connection, and a documented
  "high velocity, low simulation rate" caveat.
- **Adopted (rule 2, and the written reason):** three sentences of it — step by `v*dt + 0.5*a*dt²`,
  raycast the **segment just travelled**, stop at the first hit. That is section 5, about forty lines,
  and it is testable with no world because the cast is already an injected seam in this system
  (`Weapon.setCast`). The module is refused because the repo bans its distribution format and Wally
  has no package for it, and because its cosmetic half is the thing we have decided not to have.
- **(v2) It is also what makes the catch-up safe.** Because the cast is of the segment, running the
  simulation for 0.15 s longer is still a chain of segment casts, so a caught-up bullet cannot tunnel
  a wall and cannot skip a target. FastCast's own documented caveat ("high velocity, low simulation
  rate") is exactly what `FLIGHT_STEP_MAX_SECONDS` and `Flight.substeps` exist to bound.

### B. Valve / Source-engine lag compensation — **the REWIND, named and deliberately not adopted**

- <https://github.com/ValveSoftware/Source-1-Games/issues/2230> ("[TF2] Add lag compensation for
  projectiles") — an issue tracker, no code taken, **no licence relied on**; the issue is open and
  stale. The canonical description of the technique is Valve's own developer wiki,
  <https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking> (public developer wiki,
  maintained; *"the server moves the player hitboxes back in time to where they were when the player
  fired"*). An engine-side write-up of the same technique:
  <https://snapnet.dev/blog/performing-lag-compensation-in-unreal-engine-5/> (article, all rights
  reserved; read as prose, nothing copied).
- **Well:** it is the correct answer for a competitive hitscan shooter, where a 60 ms ping must not
  cost a head shot on another player. It is also the right **analysis** — and it names the term
  everybody else forgets: the client's interpolation delay, not only the ping.
- **Badly, for us:** per-target position history, a trusted client timestamp and a rewind window —
  and it exists to defeat exactly the feeling Karen asked FOR. Lag-compensated hitscan removes lead.
  The target here is an AI boar, nobody shoots players, and a drive is not ranked. **Source's own
  projectile classes are not lag-compensated**, and that is the shape we want. The history buffer is
  additionally a second store of where every animal was, against `Boar.Body` as the one store of
  where an animal is — `docs/PROJECT_CONTEXT.md`'s *"two systems wrote the creature's position"*.
- **Adopted:** one sentence — the server is the single source of truth for the projectile's position
  and for the hit. **The rewind is dropped, and §1.2 keeps it dropped.** *(v2, Task 256: this verdict
  is unchanged and is not what the Director's decision touched. The ANALYSIS is adopted — the error
  is the round trip times the target's speed, §5.1 item 2 — and the MECHANISM stays refused. What
  was adopted instead is source F, forward prediction, which has the opposite effect on the lead.)*

### C. Real cartridge data — the numbers

- **Rifle, .416 Rigby, 400 gr at 2400 fps** (the rifle's `AMMO_LABEL` is already `".416"`):
  <https://en.wikipedia.org/wiki/.416_Rigby> (**CC BY-SA 4.0**, actively maintained),
  <https://chuckhawks.com/416_caliber_family.html> (proprietary, static),
  <https://www.americanhunter.org/content/head-to-head-375-h-h-magnum-vs-416-rigby/> (proprietary,
  maintained publication). Muzzle 2400 fps = 731.5 m/s; 2086 fps at 100 yd, 1797 fps at 200 yd.
- **12 ga rifled slug:**
  <https://le.vistaoutdoor.com/ammunition/federal/slug/details.aspx?id=126> (manufacturer spec
  sheet, proprietary, maintained by Federal), the Chuck Hawks slug trajectory table
  <http://www.wainsworld.org/Guns/PDF/Expanded%20Shotgun%20Slug%20Trajectory%20Table.pdf>
  (proprietary, static), <https://en.wikipedia.org/wiki/Shotgun_slug> (**CC BY-SA 4.0**). Muzzle
  1610 fps; 1139 fps at 100 yd; drop −5.7 in at 100 yd off a 50 yd zero.
- **12 ga 00 buckshot:** <https://en.wikipedia.org/wiki/Military_12-gauge_cartridges>
  (**CC BY-SA 4.0**). Muzzle 1325 fps; a .33" lead sphere is down to ~940 fps by 40 yd.
- **Well:** it is the ground truth, and it already explains the feel Karen asked for — the slug
  leaves at two thirds of the rifle's speed and loses it four times as fast, so a crossing boar needs
  noticeably more lead with the shotgun. That difference IS her *"same with s/s"*.
- **Badly:** a published table is for one barrel, one bullet and one BC. We are not reproducing a
  table; we are reproducing the two things a player feels — time of flight and drop.

### D. Quadratic drag as one coefficient — the model, and why not a table

- <https://en.wikipedia.org/wiki/Drag_equation> and
  <https://en.wikipedia.org/wiki/External_ballistics> (**CC BY-SA 4.0**, actively maintained).
  `v(s) = v0·exp(-k·s)` is the closed form of `dv/dt = -k·v²` written against distance instead of
  time, and drag goes as `v²` at these Reynolds numbers.
- **Well:** one number per ammo; a closed form for the time to any range, so a spec can assert flight
  time without stepping anything; and the stepper needs no table lookup — the acceleration is
  `-g·up - k·|v|·v`, which is the same `k`. Fitted to source C it reproduces the published remaining
  velocities to about 1%: fit the rifle's `k` to 2400 → 2086 fps over 100 yd, then **predict** 200 yd
  and get 1974 studs/s against the published 1956 — **0.9% high, with nothing fitted to that point.**
- **Badly:** it ignores transonic behaviour and it is not a G1/G7 drag function. It would be wrong at
  1000 m. The longest shot in this game is 800 studs (224 m).

### E. Borrowed from inside this repo (rule 2 applies to internal patterns too)

- **The injected cast seam.** `Weapon.Hits` already takes `cast` as a parameter and `Weapon.setCast`
  already exists. `Flight:advance(dt, cast)` takes the same seam, so every flight assertion runs with
  no world and there is still one cast seam.
- **Pure core, impure owner.** `Pattern`, `Hits`, `SafetyArc`, `StateMachine`, `Validator` and
  `Limits` are pure and take `now` as a parameter (`docs/design/shotgun.md` 5.3). `Ballistics`
  follows exactly: pure, and the clock lives in the owner. **(v2) `Flight.substeps` is pure and
  static for the same reason, and `Weapon.catchUpFor` is pure whenever its `ping` is supplied.**
- **A stateful instance that needs no world:** `Registry.new()`. `Flight.new()` is the same shape.
- **Numbers as a frozen row, never copied:** `Weapons.ROWS` is built from each gun's own CONFIG and
  `tests/server/rifle.spec.luau` asserts it field by field.
- **One conversion, in one place:** `Horn.spookStuds` and `Report.CONFIG.METRES_PER_STUD`. Gravity is
  derived in `Ballistics` and nowhere else.
- **(v2) A number that can only be read at one value cannot be tested at another.**
  `Weapon.equipDelayFor`'s and `Ballistics.dropAt`'s own rule, applied to the engine's ping
  (`catchUpFor(player, ping, config)`) and to the factor (`FLIGHT_CATCHUP_PING_FACTOR` as a config
  row, so a spec reaches 2.0 while the game ships 1.0).
- **(v2) The failure mode is yesterday's behaviour.** `Weapons.loadoutFor`'s discipline for the flag:
  a path that cannot resolve its input falls back to the state the game already had, not to a guess.
  `catchUpFor` returning 0 is exactly that.

### F. Unreal Engine — forward-predicted projectiles. **ADOPTED, bounded** (v2, Task 256)

- <https://dev.epicgames.com/documentation/en-us/unreal-engine/networking-overview-for-unreal-engine>
  — Epic Games' own engine documentation. **Licence: proprietary** (Epic documentation terms); read
  as prose, **no code taken**. **Maintenance: actively maintained**, versioned with each engine
  release.
- The forward-prediction half of the same problem source B analyses: rather than rewinding the world,
  a projectile is **advanced by the owner's latency at spawn** so that it arrives where the firing
  client predicted it would.
- **Well:** it needs no history, no second position store and no new clock. The correction is one
  number multiplied into a simulation the system already runs — and `Weapon.Flight` is already
  exactly that shape, because `Flight.advance(dt, cast)` steps every projectile over an **injected**
  `dt` through an **injected** segment cast. So "catch this shot up by `L`" is not a new mechanism at
  all: it is the step this module already takes, taken once more at launch, under the same sub-step
  cap and through the same casts. It also **preserves the lead**, which is the whole reason it is
  allowed here and the rewind is not.
- **Badly:** the catch-up stretch is resolved against **one** world state rather than a rewound one,
  so it is an approximation — §5.1 item 5 measures exactly where that shows (inside ~100 m the
  correction is partial). And unbounded it would let a high-ping client reach arbitrarily far into
  the future for free lead, which is its own documented objection.
- **Adopted:** forward prediction of the launch, **bounded** at `FLIGHT_CATCHUP_MAX_SECONDS = 0.15`,
  clamped at the one door into `Flight` and spent once per shot. The bound is ours and is the only
  invented number in the mechanism (§5.1 item 4).

### G. Roblox — `Player:GetNetworkPing` and network ownership (v2, Task 256)

- <https://create.roblox.com/docs/reference/engine/classes/Player#GetNetworkPing> and
  <https://create.roblox.com/docs/physics/network-ownership>. **Licence: the documentation source
  repo <https://github.com/Roblox/creator-docs> is CC BY 4.0**; the engine itself is proprietary.
  **Maintenance: actively maintained** by Roblox alongside the engine.
- **Well:** it is the engine's own measurement and the **only latency number a server can read
  without a protocol of our own** — no wire format, no clock to synchronise, no new remote, and
  **unspoofable, because the client never sends it**. That property is what lets §1.2's "no new trust
  in the client" survive this feature intact.
- **Badly:** the documentation says only *"the network ping in seconds"* and **does not state whether
  that is the round trip or one way**, while the derivation in §5.1 item 2 shows the correction wanted
  is the round trip. It is also a smoothed average, so a single shot's own trip is not knowable from
  it.
- **Adopted:** read in **exactly one function**, `Weapon.catchUpFor`, with the ambiguity exposed as
  the config row `FLIGHT_CATCHUP_PING_FACTOR` (shipped at 1.0) rather than buried in a literal, and
  with every bad reading mapped to 0. The smoothing is accepted: a smoothed trip is a better estimate
  of a connection than a single sample, and the bound limits what a wrong estimate can be worth.

### The pattern adopted

**Server-side projectile simulation on one `RunService.Heartbeat`, one segment raycast per projectile
per step** — FastCast's algorithm (A) in this repo's own idiom (E) rather than vendored, with a
one-coefficient drag model (D) fitted to real cartridge data (C), the launch direction elevated so
the drop cancels at the zero, **and (v2, Task 256) the launch forward-predicted by the shooter's
measured delay (F) over the engine's own ping (G), bounded at 0.15 s and clamped at the one door into
`Flight` — with the REWIND (B) named and refused, because it is the mechanism that would delete the
lead this whole system exists to create.**

---

## 10. Numeric targets

`g = 9.81 / 0.28 = 35.0357 studs/s²`, derived from `Report.CONFIG.METRES_PER_STUD` and nothing else.

| | rifle Slug | shotgun Slug | shotgun Buck |
|---|---|---|---|
| cartridge | .416 Rigby 400 gr | 12 ga rifled slug | 12 ga 00 buck |
| muzzle | **2612** studs/s | **1752** | **1442** |
| drag `k` | **4.29e-4** /stud | **1.059e-3** | **2.631e-3** |
| zero | **714** studs (200 m) | **180** (50 m) | **70** (20 m) |
| range cap (unchanged) | 800 | 330 | 100 |

**Flight time**, from `t = (exp(k·s) − 1)/(k·v0)`:

| range | rifle | slug | buck |
|---|---|---|---|
| 179 studs (50 m) | 0.071 s | 0.113 s | — |
| 357 studs (100 m) | **0.148 s** | — | — |
| 714 studs (200 m) | **0.320 s** | — | — |
| the ammo's cap | 0.365 s @ 800 | **0.225 s** @ 330 | **0.079 s** @ 100 |

**Lead a boar at `SPRINT_SPEED` (38 studs/s) crossing square-on needs:**

| | 50 m | 100 m | 200 m | at the cap |
|---|---|---|---|---|
| rifle | 2.7 studs | **5.6 studs (1.57 m)** | **12.2 studs (3.40 m)** | 13.9 studs |
| slug | 4.3 studs | — | — | **8.6 studs (2.40 m)** |
| buck | — | — | — | **3.0 studs (0.84 m)** |

A boar is about 1.5 m long: half a body at buckshot range, one body with the rifle at 100 m, **more
than two bodies at 200 m**, and the slug needs ~60% more lead than the rifle at the same distance.
**(v2) That is the lead the player must learn, and since Task 256 it is the ONLY lead he must learn:
his own connection is no longer a second term in it** (§5.1).

**`Ballistics.sightOffsetAt`** (+ above the sight line, − below):

| | 100 m | 200 m | the cap |
|---|---|---|---|
| rifle (zero 200 m) | **+0.51 studs (+14 cm)** | **0** | −0.33 studs (−9 cm @ 224 m) |
| slug (zero 50 m) | — | — | **−0.48 studs (−13.4 cm @ 92 m)** |
| buck (zero 20 m) | — | — | −0.04 studs (−1 cm @ 28 m) |

The slug figure is the sanity check on the whole model: Federal publishes **−5.7 in (−14.5 cm) at
100 yd** for a 50 yd zero and the model says **−13.4 cm at 92 m**, having been fitted to neither.
*(Since tasks 189/224 each weapon also carries a `GRAVITY_SCALE`, and
`docs/research/2026-10-24-real-shooting.md` §4 re-measured the shipped rows through it: inside 60 m
every weapon and every load is within **1.6 cm** of the reticle. Karen's *"drop not needed"* is
already true as a matter of measurement, and Task 256 changes nothing here.)*

**Launch elevation.** Rifle: `elevationTangent = 2.509e-3`, **0.1438°** — against
`SAFETY_ARC_HALF_DEG = 45`, which is why the arc's verdict is identical and why it stays at the
trigger.

**The step.** `FLIGHT_STEP_MAX_SECONDS = 1/30`, `FLIGHT_MAX_SUBSTEPS = 8`,
`FLIGHT_MAX_SECONDS = 2.0` (5.5× the longest legitimate flight, so nothing reaches it),
`FLIGHT_MAX_LIVE_PELLETS = 512`. **(v2) The catch-up.** `FLIGHT_CATCHUP_MAX_SECONDS = 0.15`,
`FLIGHT_CATCHUP_PING_FACTOR = 1.0`.

**Load, derived rather than guessed.** `FIRE_RATE_LIMIT` is 6 requests/s, but a break action fires two
shells and then reloads for `RELOAD_TOTAL = 2.0 s`, so a shooter sustains about one shot a second.
Buck flies 0.079 s ≈ 5 frames at 60 Hz. So one shooter costs about **0.75 pellet-steps per frame**,
and 16 shooters about **12 casts per Heartbeat** on average. The absolute burst — all 16 firing both
barrels inside one flight time — is 16 × 9 × 2 = **288 live projectiles**, which is why the cap is 512
and can never be reached by the game. **(v2) The catch-up's cost is bounded and lives only in the
launch frame:** `Flight.substeps(1/60 + 0.15)` is 5 sub-steps where `1/60` alone is 1, so **at most 4
extra segment casts per pellet, once per shot** — ≤ 36 for a buckshot shell, and 0 on every later
Heartbeat because `live.catchUp` is spent once.

| Target | How it is measured |
|---|---|
| **average under 0.1 ms per Heartbeat**, 16 shooters in a drive | `Flight:stats().casts` and a wall-clock sum around `flight:advance`, reported from a Forest Test run |
| **burst under 1.0 ms per Heartbeat** at 288 live projectiles | a pure spec: 288 projectiles, 60 `advance` calls with a stub cast, wall clock / 60 |
| **no table allocated per projectile per step** | `Ballistics.advance` returns two values, not a table; projectile records are mutated in place; Vector3 arithmetic is Luau's native vector type. One table per `advance` call plus one per resolved shot |
| a still target at the zero is hit **within 0.05 studs** of dead centre | pure, stepped at `dt = 1/240` (section 11.1) |
| the stepper agrees with the closed form **within 1%** | pure; they differ only because the stepper's `\|v\|` includes the vertical component, which is ~0.002% of the horizontal |
| `Workspace:Raycast` appears **once** under `src/server/Weapon/` | grep (`Cast.luau` alone) |
| `flight:advance` appears **once** under `src/` | grep |
| **a boar at 38 studs/s is met where it is**, to better than 1.3 studs | the cap's arithmetic above, asserted in section 11.2 |
| **(v2) the ping's contribution to the lead at a 60 ms one-way trip: 64 cm → 0** | §5.1 item 2's derivation; `weapon_hits.spec`'s "THE CORE CLAIM" case, where the TRUE lead hits a boar it otherwise misses |
| **(v2) the correction granted per shot ≤ `FLIGHT_CATCHUP_MAX_SECONDS` (0.15 s = 5.7 studs on a sprinting boar)** | `Flight.launch`'s clamp, `Weapon.catchUpFor`'s clamp, and `weapon_state.spec`'s per-shot bound on `Weapon.stats().flightCatchUpSeconds` |
| **(v2) a catch-up of 0 is bit-for-bit today's flight** | `weapon_hits.spec`, "ZERO IS BIT-FOR-BIT TODAY'S FLIGHT: same casts, same segments, same end state" |
| **(v2) extra casts the correction may add: ≤ 4 per pellet, once per shot, ≤ 36 per shell** | arithmetic from the two caps, and `weapon_hits.spec` counting casts through the injected cast while asserting `Flight.substeps` never exceeds `FLIGHT_MAX_SUBSTEPS` |
| **(v2) the correction is partial where the round trip exceeds the flight time: 59 % of the miss removed at 50 m, exact beyond ~100 m** | §5.1 item 5's table; `weapon_hits.spec`, "CANNOT GIVE BACK MORE PING THAN THE BULLET SPENDS IN THE AIR" |
| **(v2) 0 stored target positions, 0 rewound casts** | by construction and by grep (§13 item 11) |
| **(v2) `Player:GetNetworkPing()` is read in exactly one function** | grep: `Weapon.catchUpFor` in `src/server/Weapon/init.luau`, and nowhere on the client |

**What must NOT change, and is measured to prove it:** a still target at the zero is hit dead centre;
the bang, flash, smoke, recoil, shell and bolt are at the trigger; one `HitReport` per (shot, target)
with `pellets` counted; `report.nearest` is studs from the muzzle; `Weapon.Cast` is the only
`Workspace:Raycast`. **(v2) And the catch-up changes none of them:** `report.at` is still the shot's
time, the safety verdict is still taken on `aim` at the trigger, and `FLIGHT_MAX_SECONDS`,
`FLIGHT_MAX_SUBSTEPS`, `FLIGHT_STEP_MAX_SECONDS` and `FLIGHT_MAX_LIVE_PELLETS` all keep their values.

---

## 11. How it is tested

### 11.1 `tests/server/ballistics.spec.luau` — NEW, pure, no world, no clock

1. **The data, through the closed form.** `timeToRange` at the named ranges equals the section-10
   table to ±0.001 s, per weapon per ammo. Not a tautology: it pins the three numbers against the
   research note, so a muzzle velocity that drifts fails the harness.
2. **External validation.** `speedAt(0) == v0`; and the rifle's speed at 200 yd (653.2 studs) is
   within **1%** of the published 1797 fps (1956 studs/s) — the one assertion in this spec whose right
   answer came from outside the repo.
3. **`sightOffsetAt(zero) == 0`** within 1e-6, for all three ammos.
4. **The drop table:** rifle +0.51 @ 357 and −0.33 @ 800; slug −0.48 @ 330; buck −0.04 @ 100, each
   within 0.02 studs. Includes the slug's **−13.4 cm at 92 m**.
5. **The launch direction.** `|launchDirection| == 1`; the angle between it and `aim` equals
   `atan(elevationTangent)` within 1e-4 degrees (0.1438° for the rifle); it is in the plane of `aim`
   and `up`; `aim` straight up returns `aim` and no NaN; a `Shot` with `zeroStuds = 0` returns `aim`.
6. **Task 183, preserved by construction.** Step from a muzzle with `advance` at `dt = 1/240` along
   `launchDirection(aim, shot)`: the closest approach to `muzzle + aim * zeroStuds` is **under
   0.05 studs**, for all three ammos and for `aim` horizontal, 20° up and 20° down. This is the case
   that would catch an elevation with the wrong sign.
7. **The stepper agrees with the closed form.** Stepping to the range cap, the elapsed time is within
   1% of `timeToRange(range)`, all three ammos.
8. **Gravity has one source.** `Ballistics.CONFIG.METRES_PER_STUD == Report.CONFIG.METRES_PER_STUD`
   and `GRAVITY_STUDS_PER_S2 == 9.81 / that` — the idiom `zz_horn.spec` already uses for the same
   number. And `advance` with `g = 0` drops nothing, which is what makes `g` a parameter.
9. **`shotFor` off the real rows:** `Weapons.ROWS.rifle` and `.shotgun` give the section-10 numbers;
   an unknown ammo gives `nil`; a row missing any one of the three gives `nil`.

**v2 adds nothing here.** `Ballistics` does not know the correction exists, and a spec that asserted
on it from this file would be asserting in the wrong place.

### 11.2 `tests/server/weapon_hits.spec.luau` — the Flight cases, pure, over the injected cast and an injected `dt`

Driven through `Flight.new(config)` with a hand-written config and a scripted cast. No Studio, no
Heartbeat, no boar, no player.

1. **THE CORE CLAIM — a target that moves is judged where it is when the bullet arrives.** The stub
   cast holds a mutable `boarX` which the spec advances by `38 * dt` between `advance` calls, and
   answers a hit only when the segment crosses the boar's current position. Then, at **179, 357 and
   714 studs** with the rifle:
   - aiming **AT** the boar's position at the trigger → **no impact** (it has moved out of the path);
   - aiming **AHEAD** by `38 * timeToRange(shot, range)` → **one impact**.
   This is the feature, and it is provable with no world because the stub's answer depends on the
   step's own time.
2. **`distance` is from the MUZZLE.** A boar hit at 300 studs reports `nearest ≈ 300` (±1 stud), not
   the segment length. The case asserts the raw cast returned a small `distance` and the delivered
   `Impact.distance` did not — so the conversion is proved, not assumed.
3. **One report per (shot, target), `pellets = 9`.** Nine directions, a stub answering the same boar
   part for all nine → exactly **one** `Resolution`, and `Hits.group` over its impacts gives one
   report with `pellets == 9`. Unchanged contract.
4. **The group waits for the LAST pellet.** Nine pellets, one hitting at 20 studs and eight missing to
   the 100-stud cap: `advance` returns **nothing** on the early steps and exactly one `Resolution`
   once the eight have run out of range.
5. **`report.at` is the shot's time.** `firedAt = 1000`, stepped from a clock at 2000 →
   `report.at == 1000`.
6. **The `dt` cap and the split.** With `FLIGHT_STEP_MAX_SECONDS = 1/30` and
   `FLIGHT_MAX_SUBSTEPS = 8`: `advance(1/15)` casts twice for one projectile; `advance(0.5)` casts
   exactly 8 times and advances the simulated clock by 8/30, not 0.5 ("discards the rest past the
   cap"). And the chord sag inside one capped step is under 0.02 studs.
7. **The range cap** retires a projectile with no impact and `count()` returns to 0.
8. **The flight ceiling** retires a projectile whose `elapsed` passes `FLIGHT_MAX_SECONDS` (driven
   with a tiny value), counts `timedOut`, and `count()` returns to 0. **Nothing leaks.**
9. **The live cap:** with `FLIGHT_MAX_LIVE_PELLETS = 2`, a nine-pellet `launch` returns 0, counts
   `refused`, and the shot still resolves — with no impacts, which is a miss.
10. **The segment and the ignore list.** The cast is called with `(p, p' - p, ignore)` and the ignore
    table is the SAME table, unmodified — the assertion this spec already makes for `Hits.resolve`,
    moved to the stepper.
11. **A shot whose shooter has gone still resolves.** A `ShotRecord` whose `shooter` is a parentless
    stand-in produces its `Resolution` and its report; `Weapon.markHit` with that stand-in sends
    nothing and does not error (`stats.markers` does not move).
12. **The grep claims:** `Workspace:Raycast` appears once under `src/server/Weapon/` (in `Cast.luau`);
    `flight:advance` appears once under `src/`.
13. **The burst budget:** 288 projectiles, 60 `advance` calls with a stub cast, under 1.0 ms per call
    (reported with `TestKit.note` as a number, not only as a pass).

**(v2, Task 256) The lag-correction block in the same file**, driven through the same
`Flight.new(config)` and the same scripted cast, with `FLIGHT_CATCHUP_MAX_SECONDS` and
`FLIGHT_CATCHUP_PING_FACTOR` read off `Shotgun.CONFIG` so the shipped numbers are what is exercised:

14. **"THE CORE CLAIM: with the catch-up, the TRUE lead hits a boar it otherwise misses."** The same
    moving-stub machinery as case 1, with the aim held at the TRUE lead and the world one round trip
    ahead: uncompensated it misses, compensated it hits. This is the feature, and the round trip used
    is asserted to be inside `FLIGHT_CATCHUP_MAX_SECONDS` so the case cannot pass by exceeding the
    bound.
15. **"CANNOT GIVE BACK MORE PING THAN THE BULLET SPENDS IN THE AIR, and that is stated."** §5.1
    item 5's table, asserted: the closest approach at 50 m is still a miss and the longer ranges are
    hits. The degradation is a number in the harness rather than a sentence in a document.
16. **"ZERO IS BIT-FOR-BIT TODAY'S FLIGHT: same casts, same segments, same end state."** Traces a
    shot with no catch-up against one with `nil`, and asserts `stats().catchUpSeconds == 0`. This is
    what makes the feature's off state provable without a flag.
17. **"IS SPENT ONCE, however many frames the shot lives for."** `live.catchUp` is zeroed as it is
    read, so a long-lived shot is compensated on its first `advance` and never again.
18. **"IS CLAMPED AT THE CAP, and a negative or a NaN is zero."** `Flight.launch` clamps at the one
    door; `Weapon.catchUpFor(nil, 10, CONFIG)` returns the cap.
19. **"A SHOT THE GLOBAL CAP REFUSED IS GRANTED NOTHING."** `catchUpSeconds` does not move for a shot
    with no projectiles — the counter can never contain time that bought nothing.
20. **"CANNOT TUNNEL: a wall between the muzzle and the animal still stops the caught-up shot."** The
    safety argument for the whole mechanism, asserted rather than argued: the catch-up goes through
    the same sub-stepped segment casts.
21. **"`Flight.substeps` never exceeds the cap and is the vacuum limit at 0."** Pure: never more than
    `FLIGHT_MAX_SUBSTEPS` sub-steps, never a sub-step longer than `FLIGHT_STEP_MAX_SECONDS`, and
    `(1, 0)` at `total <= 0`.
22. **"`Weapon.catchUpFor` converts a ping, clamps it, and refuses a bad one."** With `ping` supplied
    the function is pure, so a config with `FLIGHT_CATCHUP_PING_FACTOR = 2.0` doubles the result —
    **both readings of the engine's number are reachable by parameter while the shipped row sits at
    one of them** — and a nil, a negative, a NaN and a non-number all return 0.

### 11.3 Existing server specs that must change

- **`tests/server/rifle.spec.luau`:** every row carries `MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD` and
  `ZERO_STUDS`, **field by field against that gun's own CONFIG** (never a literal); every `AMMO_KINDS`
  entry has all three; `ZERO_STUDS[ammo] <= RANGE_STUDS[ammo]` for every row and ammo (a zero beyond
  the range cap is a data fault); and **no row carries a flight number or a gravity** — the existing
  "no row has `SAFETY_ARC_HALF_DEG`" case, extended. **(v2: and no row carries a catch-up number
  either — the bound and the factor are the SERVER's, §3.2, so a new weapon cannot widen its own
  licence to reach into the future.)**
- **`tests/server/weapon_shot.spec.luau`:** the Task 183 sight-line case is LIVE and today restores
  `Weapon.setCast(nil)` in the frame after the trigger. The pellet cast now happens on a later
  Heartbeat, so the case must **wait for the flight to drain** — poll `Weapon.flightCount() == 0` with
  a bounded wait (0.5 s covers the rifle's 800-stud cap at 0.365 s) before restoring the cast and the
  providers. Without that change the second cast is never recorded and the spec goes red for a reason
  that has nothing to do with aiming. The case's claim is unchanged: the pellet leaves the MUZZLE and
  is aimed at the point the camera ray hit.
- **`tests/server/weapon_state.spec.luau`:** the defect-(c) leak case is unchanged (it reads
  `Registry:count()`), plus one line: `Weapon.flightCount()` is 0 at the end of the spec. **(v2) Plus
  the catch-up instrument: `Weapon.stats().flightCatchUpSeconds` is asserted `>= 0` and, divided by
  `stats().shots`, under a **per-shot bound of 10 ms** — and it is a BOUND, NOT ZERO, because a
  loopback Studio Play session does not read a zero ping. The first version of that assertion
  asserted exactly 0 and FAILED, measuring 1.70 ms of total compensation across one run's shots
  (0.065 studs on a sprinting boar). 10 ms is ~50× this machine and 15× under the cap: loose enough
  never to flake, tight enough that a wrong `FLIGHT_CATCHUP_PING_FACTOR` or a seconds/milliseconds
  mix-up trips it. The run also prints a `[catchup]` `TestKit.note` with the measured number, because
  on a real server that note is the only instrument anybody has for what the factor is buying.**

### 11.4 Client specs

- **`tests/client/weapon_client.spec.luau`:** `remotes.ShotLanded:IsA("RemoteEvent")`;
  `Effects.playLanded({ impacts = { p } })` creates exactly one `Impact` Part under
  `Workspace.WeaponEffects` and **no `Tracer`, no `Flash`, no `Smoke`**; `Effects.play` with
  `impacts = {}` still draws the flash and the smoke and no tracer; `EFFECT_MAX_PER_SHOT` still caps
  `playLanded`. Plus the grep claim that `firedSignal:Fire` appears once in
  `src/client/Weapon/init.luau`, inside the `ShotFired` handler — the recoil is still at the trigger.
- **`tests/client/shoot_boar.spec.luau` — this spec WILL go red unless it leads, and that is the
  point.** It replays a real click at a real boar and keeps the camera on it; a boar runs at 28+
  studs/s as soon as a player appears, so an aim held ON the animal now misses by `v·t`. The fix is
  the feature: the tracking function measures the boar's velocity itself (finite difference of its
  position across `RenderStepped`, so it needs no replicated velocity field), reads the loaded ammo
  off `Weapon.get()` and the row off `ReplicatedStorage.Weapons`, and aims at
  `boarPosition + boarVelocity * Ballistics.timeToRange(shot, distance)`. **That makes this the
  end-to-end proof on the player's path**: a real click, led by the real arithmetic, through the real
  server, onto a real boar, home as a real hit marker. Its window (`TRACK_SECONDS = 15`) already
  absorbs the extra 0.1 s.
  The matching **negative** — aiming at the animal misses — is asserted in 11.2 case 1 and NOT live:
  buckshot's 1.6° cone at close range can still clip a boar that moved two studs, so a live negative
  would be flaky and would prove nothing.
- **`tests/client/hit_marker.spec.luau` is unaffected:** its server end is `weapon_hits.spec` calling
  `Weapon.markHit` directly.
- **(v2) NO client spec for the lag correction, and that is deliberate.** Nothing about it is
  client-side: the client sends `{origin, direction}` and nothing else, the ping is read on the
  server, and the correction is spent on the server. A client assertion here would be an assertion
  about the engine's own ping, measured on a loopback where it is 1–2 ms — a number that cannot fail
  a wrong factor and would therefore be a false PASS path.

### 11.5 Harness input and screenshots — what they can and cannot do

- **Harness input (`tests/client/input_scenarios.txt`).** It can replay the click and the `stage`
  block can place the character and take the first aim. It **cannot** aim at a moving animal on a
  schedule, and it cannot express "lead this target by this much" — the scenario file is keys, mouse
  buttons, moves and gaps (`tools/studio_mcp.py` docstring; TASKS.md Tasks 6–7). So the lead is
  computed **in the spec**, through the camera owner's own `LookAtRequest`, which is exactly how
  `shoot_boar.spec` already keeps the aim on a running boar. No new harness capability is needed and
  none is claimed. **(v2) The harness also cannot produce latency**: there is no way to ask StudioMCP
  for a 60 ms connection, which is why the correction is proved by injected `catchUp` values in a
  pure spec and only *bounded* in the live one.
- **Screenshot (rule 5).** One capture of a shot's impact dust at the landing point, inspected, since
  `ShotLanded` draws something new. **A screenshot cannot show a 0.3 s delay or a lead**, and this
  design does not pretend otherwise: the thing Karen asked for is a *feeling*, and the only
  verification of it is her playing it. That is section 16 item 1, not a checkbox here. **(v2) The
  lag correction needs no screenshot at all**: nothing on screen differs frame to frame, and what IS
  visible — whether a lead that looks right now connects — is a **playtest on a real server**, not a
  capture.
- **What cannot be tested at all, said plainly:** the `"no-ballistics"` branch is unreachable in the
  shipped build (both rows carry all three numbers and `rifle.spec` asserts it), so it is proved only
  as `shotFor` returning `nil` for a hand-written row plus the Reviewer reading the guard. And the
  average-cost target needs a live drive with players in it, so it is **reported** from a Forest Test
  run rather than asserted by a spec. **(v2) And the live magnitude of the catch-up cannot be
  measured on this PC**: a loopback session reads 1–2 ms (measured: 1.70 ms total over a run), which
  cannot distinguish `FLIGHT_CATCHUP_PING_FACTOR = 1.0` from 2.0. §16, Director 9.

---

## 12. The harness tables, and the gate

### 12.1 `tools/studio_mcp.py`

**`BLAST_RADIUS`** — one new row. `src/shared/Ballistics/` resolves to **`weapon`**, not `gun`: `gun`
is the drawn gun's geometry (`gun.spec`, `gun_client.spec`) and has nothing to do with flight, while
the flight is stepped by `src/server/Weapon/`, which already resolves to `weapon`.

```python
    ("src/shared/Ballistics/", "weapon"),
```

**`SCOPE_SPECS`** — `tests/server/ballistics.spec.luau` must belong to at least one scope or
`selftest` fails. It goes in **`weapon`**, and — using the dual-membership idiom the table already
uses for `zz_horn`, `boar_hit`, `boar_shot` and `shoot_boar` — also in **`gun`**, because the three
ballistic numbers live in `src/shared/Shotgun/` and `src/shared/Rifle/`, both of which resolve to
`gun`.

**And one pre-existing hole this task closes, because this task walks into it.**
`src/shared/Rifle/` → `gun`, whose tuple is only `(gun.spec, gun_client.spec)` — so a `--scope auto`
run over a change to `Rifle.CONFIG` does **not** play `tests/server/rifle.spec.luau`, the spec that
exists to assert that row. Task 183 changed exactly that file. Add `tests/server/rifle.spec.luau`
(and `tests/server/ballistics.spec.luau`) to the `gun` tuple. `selftest` stays green: every spec
still belongs to a scope and every named file still exists.

**(v2) Task 256 needs no new table row.** Its files are `src/shared/Shotgun/` → `gun`,
`src/server/Weapon/` → `weapon`, and the two server specs already in those scopes. The two scopes
between them play `weapon_hits.spec`, `weapon_state.spec` and `ballistics.spec`, which is where every
catch-up assertion lives.

### 12.2 Which gate this task needs

**One player only.** The files touched are `src/shared/Ballistics/`, `src/shared/Shotgun/`,
`src/shared/Rifle/`, `src/shared/Weapons/`, `src/server/Weapon/`, `src/client/Weapon/`,
`tools/studio_mcp.py` and their specs. **Not one of them is in `TWO_PLAYER_PATHS`** —
`src/server/Match/`, `src/server/MatchBoot.server.luau`, `src/client/Match/`,
`src/client/MatchBoot.client.luau`, `src/shared/Drive/`, `tests/client/Role.luau`,
`tests/server/match_*.spec.luau`, `zz_drive_boundary.spec.luau`,
`tests/client/match_client.spec.luau`, `outfit_client.spec.luau`, `zz_tie_to_a_tree.spec.luau`. The
design agrees with the Builder's reading, and that is a direct consequence of brief decision 1.10:
**leaving the safety verdict at the trigger is what keeps this task off that list.** `test2` is N/A
with that as the reason.

Because the task changes `tools/studio_mcp.py`, which is in `FAIL_SAFE_PATHS`, **`--scope auto`
resolves to `all` anyway** — so the review round and the PR both get the full run and the line reads
`scope=all`.

**(v2) Task 256 is the same answer for a simpler reason.** It touches `src/shared/Shotgun/init.luau`,
`src/server/Weapon/` and two `tests/server/` specs, and **none of them is in `TWO_PLAYER_PATHS`**: the
correction is a property of ONE shooter's connection, and a second client would render a second copy
of the same answer. The one-player line is required, as always. `test2` is N/A, with that as the
reason. **A playtest on a real server is a separate thing from the gate** — it is what §16 Director 9
asks for, and it is not a merge condition (CLAUDE.md, "Feature flags": feel-critical work does not
wait for a playtest to merge).

---

## 13. The Reviewer's checklist — what must not have changed

1. `Workspace:Raycast` appears under `src/server/Weapon/` only in `Cast.luau`.
2. `flight:advance` has exactly one caller, the `RunService.Heartbeat` in `Weapon.start`.
3. The trigger frame still does, in this order: rate limit, validate, reduce, muzzle, aim ray, `aim`,
   `Rules.refuse`, `setState`, `SafetyArc` (on `aim`, with `stopAt` = muzzle→aim-point), publish,
   `AUTO_CYCLE` bolt, `Weapon.ShotFired` (with `at = aimPoint`), `ShotFired:FireAllClients`.
4. `Hits.group` is still the only constructor of a `HitReport`, and still makes **one per
   (shot, target)** with `pellets` counted.
5. `report.at` is the SHOT's time; `report.nearest` is studs from the MUZZLE.
6. `RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG`, `SAFETY_ARC_HALF_DEG` and every timing are unchanged.
7. Nothing under `src/server/Match/`, `src/server/Boar/`, `src/client/Camera/` or `src/client/Hud/`
   is touched.
8. No new feature flag, no `.rbxm`, no vendored module, no Instance per projectile.
9. `Hits.resolve` is archived under `backups/` with its commit, not deleted silently (rule 7).
10. `Weapon.stats()` still returns a copy, and `refusedBy` is still copied by hand.

**(v2, Task 256) The lag correction:**

11. **No rewind and no history.** Nothing under `src/server/Weapon/` reads, stores or interpolates a
    target's past position, and no shot is resolved against anything but the world as it is in the
    sub-step being cast. `Boar.Body` is still the only store of where an animal is.
12. **`Player:GetNetworkPing()` appears exactly once in `src/`** — in `Weapon.catchUpFor`
    (`src/server/Weapon/init.luau`) — and nowhere under `src/client/`. No remote carries a ping, a
    latency or a client timestamp in either direction.
13. **The clamp is at the one door.** `Flight.launch` clamps `catchUpSeconds` to
    `[0, FLIGHT_CATCHUP_MAX_SECONDS]` and rejects a NaN; `Weapon.catchUpFor` clamps as well and maps a
    nil, a failed read, a negative, a zero and a NaN to **0**.
14. **Spent once.** `live.catchUp` is set to 0 in the same statement that reads it, inside
    `Flight.advance`; a shot cannot be compensated on a second Heartbeat.
15. **One split.** `Flight.substeps` is the only place the sub-step arithmetic appears, and it is
    pure, exported and never returns a sub-step longer than `FLIGHT_STEP_MAX_SECONDS` or more than
    `FLIGHT_MAX_SUBSTEPS` of them.
16. **One launch site.** `flight:launch(…, Weapon.catchUpFor(player, nil, CONFIG))` appears once, in
    the fire-request path, over one production `Flight.new(CONFIG)`.
17. **The two numbers are in `Shotgun.CONFIG`, not in a weapon row**, and `rifle.spec` asserts no row
    carries either.
18. **Nothing above §5.1 moved:** `FLIGHT_STEP_MAX_SECONDS`, `FLIGHT_MAX_SUBSTEPS`,
    `FLIGHT_MAX_SECONDS` and `FLIGHT_MAX_LIVE_PELLETS` are at their Task 185 values.
19. **`Weapon.stats().flightCatchUpSeconds` is a mirror, not a second counter:** it is assigned from
    `flight.catchUpSeconds` and written nowhere else.
20. **The guard in `weapon_state.spec` is a per-shot BOUND, not an equality with zero** — a loopback
    session measures 1.70 ms, and an assertion of exactly 0 is a known-false claim.

---

## 14. `GAME_DESIGN.md` — the rows that change

**One new row:**

> **Ballistics** (time of flight, remaining speed, drop, the launch elevation, one step) —
> `ReplicatedStorage.Ballistics`: pure maths plus deep-frozen numbers with **no run-time writer at
> all**, the shape `Gun`, `Horn`, `Report` and `Shop` already have. Gravity is derived HERE and
> nowhere else, from `Report.CONFIG.METRES_PER_STUD`. `src/shared/Ballistics/init.luau` —
> [ballistics](docs/research/2026-10-14-ballistics-lead.md),
> [design](docs/design/ballistics.md)

**One new row:**

> **The projectiles in the air** (the list, each shot's record, its accumulated impacts, whether it
> has finished, and **what lag it still owes its shooter**) — `ServerScriptService.Weapon.Flight`,
> over an **injected cast** and an **injected `dt`**. It calls no raycast, builds no report, fires no
> signal and holds no clock; the one caller of `flight:advance` is the single
> `RunService.Heartbeat` in `Weapon.start`. `src/server/Weapon/Flight.luau` —
> [design](docs/design/ballistics.md) sections 2, 5

**(v2, Task 256) One new row:**

> **The lag correction** (how much of a shooter's connection a shot is given back) —
> `ServerScriptService.Weapon`: `Weapon.catchUpFor` is the **one reader of
> `Player:GetNetworkPing()`** in the repo and the one thing that computes the number;
> `Flight.launch` clamps it at the one door; `Flight.advance` spends it once. **Forward prediction of
> the PROJECTILE, bounded at `FLIGHT_CATCHUP_MAX_SECONDS = 0.15`; rewinding a target, or storing its
> past position, is FORBIDDEN** — `Boar.Body` is the only store of where an animal is.
> `src/server/Weapon/init.luau`, `src/server/Weapon/Flight.luau` —
> [research](docs/research/2026-10-24-real-shooting.md) §5,
> [design](docs/design/ballistics.md) §5.1, [weapon](docs/design/shotgun.md) §11.1

**The weapon row (row 41), amended:** add — *"Since Task 185 a shot is a PROJECTILE the server steps,
not a hitscan ray: the hit is judged where the target is when the bullet gets there (`Weapon.Flight`
over `Weapon.Cast`), and the `HitReport` is made once the shot's LAST pellet has resolved, with
`at` = the time of the SHOT and `nearest` = studs from the MUZZLE. The safety verdict, the penalty,
the bang, the flash, the recoil, the shell and the bolt all stay at the TRIGGER. Since Task 256 the
LAUNCH is forward-predicted by the shooter's measured delay, bounded at 0.15 s, so the lead a player
learns is the real lead and not the real lead plus his ping."*

**The shotgun-numbers row (row 44), amended:** six RemoteEvents, not five (the sixth, `ShotLanded`,
arrived with the flight), and `Shotgun.CONFIG` now also carries the shotgun's three ballistic numbers,
the four system-wide flight numbers **and the two system-wide catch-up numbers
(`FLIGHT_CATCHUP_MAX_SECONDS`, `FLIGHT_CATCHUP_PING_FACTOR`)**.

**The shot-cosmetics row (row 43), amended:** *"the impact dust is drawn from `ShotLanded`, when the
bullet arrives; the flash and the smoke are drawn from `ShotFired`, at the trigger. `ShotFired`'s
`impacts` list is always empty since Task 185."*

---

## 15. What I could not verify (rule 8)

1. **Roblox Studio is not available to this run** (`.agent-evidence/INDEX.md`), so no number here was
   measured in a session. Every ballistic figure in section 10 is arithmetic over the research note's
   data, recomputed here from the closed form and found self-consistent; every cost figure is a
   derivation from the rate limits and the flight times, and is written as a **target to be measured**,
   not as a result.
2. **The real cost of 288 raycasts in one Heartbeat in a built forest is unknown to me.** A Roblox
   raycast is cheap but scene-dependent. The average case (≈12 casts/frame) has a large margin; the
   burst does not. If the measured burst exceeds 1.0 ms, the honest knob is Karen's `PELLETS` or a
   queued task that steps a buckshot pattern as one projectile — **not** a quietly coarser step.
   *(v2: the catch-up adds at most 4 sub-steps per pellet and only in the launch frame, which is a
   worst case of 36 extra casts on the frame a buckshot shell is fired. It is derived, not measured.)*
3. **Whether a `LinearVelocity`-driven boar's welded zone parts are where the server thinks they are,
   sub-frame.** The weapon reads the world through one ray and never reads boar state, so this is the
   engine's answer and not ours; but the 1.27-stud resolution claim assumes the parts move smoothly
   between Heartbeats.
4. **The 14 cm mid-range rise at 100 m is larger than a real .416's ~7 cm**, because this model has no
   scope-height offset. That is a modelling simplification, written down rather than hidden, and it is
   one number to change (section 16 item 1). *(Since tasks 189/224 `GRAVITY_SCALE` has reduced the
   shipped figure; `docs/research/2026-10-24-real-shooting.md` §4 re-measures the rifle's worst at
   **1.5 cm at 105 m**.)*
5. **`Effects.playLanded` has not been looked at on screen** by me; rule 5 is the Builder's, with the
   capture named in 11.5.
6. **(v2) Whether `Player:GetNetworkPing()` is the round trip or one way.** It is the one genuinely
   uncertain number in §5.1, it cannot be settled on this PC (a loopback session reads 1–2 ms;
   measured 1.70 ms total over one run), and it is carried as `FLIGHT_CATCHUP_PING_FACTOR = 1.0`
   rather than resolved. §16 Director 9.
7. **(v2) Whether the correction feels right.** The arithmetic says the ping stops being a term in the
   lead; whether a lead that looks right then connects is Karen's, on a real server, and no spec and
   no screenshot can answer it. §16 Karen 8.
8. **(v2) Two stale comments in the shipped code, found while reading it for this design, and NOT
   fixed here because this is a design run.** `src/server/Weapon/Flight.luau` says, in `Flight.new`'s
   `catchUpSeconds` comment, *"In a Studio harness run there is no network, so this must stay 0"*, and
   in `Flight.launch`'s, *"with no network this must read 0.000, so a non-zero total in a Studio
   harness run is this feature firing where there is no lag to compensate — a bug"*. **Both are now
   known false**: round 2 measured 1.70 ms, `src/server/Weapon/init.luau`'s own
   `flightCatchUpSeconds` comment has been corrected to say so, and `weapon_state.spec` asserts a
   bound rather than zero. Two code comments asserting "this must be 0" against a spec that asserts it
   is not is exactly the kind of disagreement rule 9 exists to prevent, and the fix is two comment
   edits in `Flight.luau` naming the measured 1.70 ms. **Non-blocking** — it is a comment, not a
   behaviour, no owner boundary moves, and the brief forbids widening this run's scope — so it belongs
   in `TASKS.md` under the task, not in `ARCH_RESULT.md`.

---

## 16. Open decisions

### For Karen — feel. **None blocks building:** each ships at a stated default.

1. **The rifle's zero: 200 m (shipped) or 150 m?** 200 m is dead-on where she asked
   (*"precist and on 200m acurat"*, Task 183) and keeps 183's measured result at that distance. The
   price is **+14 cm at 100 m**. A 150 m zero puts the whole band inside ±16 cm from 0 to 200 m. One
   line in `Rifle.CONFIG.ZERO_STUDS` either way.
2. **A visible tracer: NONE (shipped)** — the Director's dispatch; hers to change later. The bullet is
   invisible maths and the dust is drawn when it arrives.
3. **Muzzle velocities are dials.** If 200 m feels like too much lead, the honest knob is the
   cartridge, not the physics.
4. **Is the lead right at 50 m with buckshot?** 3.0 studs is half a boar. If it feels like nothing,
   `DRAG_PER_STUD.Buck` is the number — and making it slower is making it more real, not less.
8. **(v2) Do close shots on fast animals still feel behind?** §5.1 item 5 says they will, by design
   and by measurement: inside ~100 m the correction is partial, and at 50 m it leaves **1.73 studs
   (48 cm)** of the 4.26 it started with. If she reports it, **that table is the starting point of
   reopening the trade, not a bug report** — and the only thing that would remove the remainder is
   resolving against a rewound world, which §1.2 forbids and the Director has not reopened. The
   honest dials short of that are `MUZZLE_STUDS_PER_S` (a faster bullet spends less time in the air
   and needs less correction) and the slug `Spherecast` idea in `docs/design/shotgun.md` §11, which
   forgives the *pattern* rather than the clock.

### For the Director — scope. **None blocks building.**

5. **`Match.CONFIG.SAFETY_RANGE_STUDS` is still 330** while the rifle reaches 800 (already queued as
   TASKS.md 183a). This task does not touch it, for brief 1.10's reason: `src/server/Match/` is a
   `TWO_PLAYER_PATH`. Unchanged, named again here because the flight makes the mismatch no better.
6. **Should a boar hear the STRIKE when the bullet lands rather than at the trigger?** Decision 9 says
   no and this design obeys it. The 0.1–0.37 s is below the animal's own reaction path, so nothing
   observable turns on it. If the Director ever wants it moved, it is one line in the resolution
   handler and it would need `boar_behaviour.spec` to follow.
7. **Filtering the TestEZ suite by scope** (TASKS.md 113a) would make the new spec's 288-projectile
   budget case cheap to run alone. Not this task.
9. **(v2) CONFIRM `FLIGHT_CATCHUP_PING_FACTOR` ON A REAL SERVER.** Shipped at **1.0** (treat the
   engine's number as the round trip, the conservative reading); **2.0** if it turns out to be one
   way. **This PC cannot answer it** — a loopback Play session reads 1–2 ms, measured at 1.70 ms of
   total compensation over one run, which is 0.065 studs on a sprinting boar. What to do: publish to
   the DEV place, join from a real client, fire a few shots, and read
   `Weapon.stats().flightCatchUpSeconds` divided by `stats().shots` against a known ping (the
   `[catchup]` note in `weapon_state.spec` prints exactly that pair). If the per-shot figure is about
   **half** the client's displayed ping, the engine's number is the round trip and 1.0 is right; if it
   is about the whole of it, the engine's number is one way and the factor should be 2.0. One line in
   `Shotgun.CONFIG` either way, with the one-player gate. `docs/design/shotgun.md` §15 H is the same
   item from the weapon's side.
10. **(v2) Is the 0.15 s bound the right ceiling?** It is the only invented number in the mechanism
    (§5.1 item 4): it covers a 150 ms trip and caps the reach at one boar body length. A player on a
    300 ms connection gets half his error corrected and no more. Raising it buys worse connections a
    better game and buys everyone else a shot that other players see hitting nothing; lowering it does
    the reverse. The Director's, and it needs the answer to item 9 first.

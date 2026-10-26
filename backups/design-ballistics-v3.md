# Design: ballistics — a shot hits what the shooter saw. The client claims; the server validates by rewinding

**v3, Task 266 (2026-10-25).** Written to `reviews/task-266/BRIEF.md` (the Builder carrying the
Director, 2026-10-25), which **overrides** `docs/design/ballistics.md` v2 §1.2's *"No REWINDING of
targets, and no position history of one"* and §9 source B's refusal of *"per-target position history,
a trusted client timestamp and a rewind window"* **by name**. Those two passages are replaced by
section 1.3 of this file. Everything else in v2 — the drag, the drop, the zero, `GRAVITY_SCALE`, the
pattern, `Ballistics.timeToRange`, the forward prediction of Task 256 — stands unchanged and is not
re-derived here.

Karen, 2026-10-24 and 2026-10-25:

> *"it seems there is a bit off"* · *"we need to aim in empty space to get hit in head neck or heart
> like in real life"* · *"this signe where we shot ... shows we hit empty space and died"* ·
> *"all shooting has to be like in real life / this is a key of this game"*

Asked which of several fixes to take: *"the best way"*.

This file is the design for the flight of a shot AND the **delta to `docs/design/shotgun.md`**
(§§3.1, 5.3, 5.5, **5.7**, 11, 13.1, 13.2, 15 — section 14 below). Where it disagrees with
`shotgun.md` or `rifle.md`, this file wins for the flight and for the claim, and those files win for
everything else.

---

## 1. What the system must do, and must not do

### 1.1 Must do — unchanged from v2

Items 1–9 of v2 §1.1 stand word for word: a shot takes time to arrive; the time is per weapon per
ammo; a target that moved out of the path is not hit and one that moved into it is; gravity drop as
data; Task 183's still-target accuracy by construction; **only the hit and the dust wait for the
bullet**; a hit's `distance` is measured from the bore; cheap and leak-proof; and the lead a player
learns is the real lead.

### 1.2 Must do — new in v3

10. **A SHOT HITS WHAT THE SHOOTER SAW.** The player's screen is the only picture he can aim at. The
    shot is therefore simulated **on his own client, against his own view, over the real flight
    time**, and the client sends a **hit claim**. The server **validates** it against its own recent
    position history and accepts or refuses. Nothing is taken on trust: every field of the claim is
    judged (section 5), and the one thing the client is believed about is **which animal it saw, and
    where**.
11. **The view error goes; the lead stays.** See 1.4 — this is the distinction the whole design turns
    on, and it must not be summarised away.
12. **A refused claim costs the player nothing he had before.** The shot still happens and still
    resolves exactly as it does today, by the server's own flight (section 5.3). The failure mode of
    this whole feature is *"the game shoots as it did yesterday"* — the discipline v2 §6.5 already
    states for `Weapon.catchUpFor`.
13. **One line for the safety lock and the penalty**, fixing 259b in passing (section 8).

### 1.3 Must not — v2's rewind rule, replaced

v2 §1.2 carried this, and the Director has lifted it for this task:

> **No REWINDING of targets, and no position history of one.** … Nothing under
> `src/server/Weapon/` may read or keep a target's past position, and no shot may be resolved against
> a rewound world.

**The replacement rule, which is narrower and keeps the owner boundary the old rule was really
protecting:**

- **A per-animal position history EXISTS, and `ServerScriptService.Boar` is its one writer and one
  reader.** It is a ring buffer on the animal's own record, sampled in the `Runtime:step` the Boar
  already runs (`src/server/Boar/init.luau` → `Runtime:step`, which already builds a per-animal
  `snapshot` of `Body.position`/`Body.velocity` every Heartbeat). `Boar.Body` stays the only writer of
  where an animal **is**; the history is the Boar's own record of where it **was**, in the same owner,
  written in the same function, from the same read.
- **Nothing under `src/server/Weapon/` keeps, samples or interpolates a target's position.** The
  weapon **asks**, through an injected provider, exactly as it already asks the drive four questions
  (`Weapon.setTargetProvider`, `setStandProvider`, `setDriveOpenProvider`,
  `setSafetyLineProvider`). A `Rewind.luau` under `src/server/Weapon/` that sampled Workspace itself
  would be a second reader of the animal's position and is refused — that is the failure
  `docs/PROJECT_CONTEXT.md` is named after, and it is what the old rule was for.
- **No shot is resolved against a rewound world by raycast.** There is no rewound cast anywhere: the
  server's own `Flight` still casts the live world, and the claim is judged by **arithmetic** over one
  stored `CFrame` per animal per sample (section 5.2). `Weapon.Cast` remains the ONE caller of
  `Workspace:Raycast` under `src/server/Weapon/`.

### 1.4 Why this does NOT delete the lead Karen asked for

v2 §9 source B refused the rewind because **"lag-compensated hitscan removes lead"**. That is true of
hitscan and it is false here, and the difference must survive every later reading of this file:

- The projectile still takes its **real flight time**. `Ballistics.timeToRange` is untouched, the
  muzzle velocities and drag coefficients are untouched, and `Flight` still steps the shot over that
  time on the server.
- The simulation the claim comes from is **the same flight, run on the client, against the animal the
  player can actually see**. **Aiming AT a running animal still misses** — the client's own bullet
  arrives where the animal is not, so **no claim is produced at all** and the shot is today's miss.
  **Aiming ahead by `v · t` still hits.** The lead is preserved *exactly*, because the lead IS the
  flight time and the flight time has not changed. The lead is now **enforced by the client's own
  simulation**, with the same numbers out of the same module.
- What is removed is only the **view error**: the difference between where the player's screen draws
  the animal and where the server holds it. That is not lead. It is a disagreement about the present
  moment, and it is the thing Karen calls *"a bit off"*.

Source-engine lag compensation rewinds so that **hitscan** hits what was drawn. We rewind so that a
**projectile fired at what was drawn** can be checked for plausibility. The two look identical in a
one-line summary and are opposite in effect.

### 1.5 Must not — the rest, unchanged from v2

- **No Instance per projectile.** The projectile is invisible maths, on the server and on the client.
- **No second writer of hits.** `ServerScriptService.Weapon` is the one owner of whether a shot
  happened and what it hit; `Hits.group` is the ONE constructor of a `HitReport`, still **one per
  (shot, target)** with `pellets` counted.
- **No client-side copy of the ballistic arithmetic.** The client runs the *same functions* out of
  `ReplicatedStorage.Ballistics` (section 4.1). A second stepper on the client would be two answers
  to "where did the bullet go".
- **No second id table.** The claim names an **Instance**, which Roblox replicates on a remote, and
  the server re-derives the animal from it with `Hits.targetOf` — the rule
  `docs/design/map-generator.md` §12.2 states.
- **The client never names a zone, a damage number or a target root.** It names a **part**; the zone
  is the `HitZone` attribute the animal's own owner wrote, read by `Hits.targetOf` on the server, and
  unchanged.
- **No vendored FastCast. No `.rbxm`.** Nothing under `src/server/Match/` or `src/client/Camera/`
  changes. `RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG`, `SAFETY_ARC_HALF_DEG`, `GRAVITY_SCALE`,
  `FLIGHT_*` keep their values.
- **Everything at the trigger stays at the trigger** (v2 §1.1 item 6): the rate limit, the validator,
  the state machine, the aim ray, `Rules.refuse` including the safety lock, `SafetyArc`, the shell,
  the bang, the flash, the smoke, the recoil and the bolt.

---

## 2. Owners — one writer each, named

| Thing | The one writer | On disk | New? |
|---|---|---|---|
| **The ballistics maths** (time of flight, remaining speed, drop, the launch elevation, the bore, **one sub-step's geometry and its exact range cap** — new) | `ReplicatedStorage.Ballistics` — frozen numbers plus pure functions, no state, no clock, no service | `src/shared/Ballistics/init.luau` | existing, +1 function |
| **The live projectiles on the server** (the list, each shot's record, its impacts, how far it got, what lag it owes) | `ServerScriptService.Weapon.Flight` | `src/server/Weapon/Flight.luau` | existing |
| **The clock that advances them, every signal, remote, counter and report, the latency measurement, and — new — WHETHER A CLAIM IS ACCEPTED** | `ServerScriptService.Weapon` (`src/server/Weapon/init.luau`) — **unchanged as the owner** | `src/server/Weapon/init.luau` | existing |
| **The verdict on one payload** (the shot request AND the claim) | `ServerScriptService.Weapon.Validator` — pure, no Instance, no service, no clock | `src/server/Weapon/Validator.luau` | existing, +2 functions |
| **Where an animal IS** | `ServerScriptService.Boar` → `Boar.Body` (a `LinearVelocity` on the trunk; the zone parts are welded to it) | `src/server/Boar/Body.luau` | existing, untouched |
| **Where an animal WAS** (the ring buffer, the sampling, the lookup, the rewound part CFrame) | `ServerScriptService.Boar` → `Runtime:step` writes it, `Runtime:cframeAt` reads it. **The only store and the only reader.** The weapon is handed an answer, never the buffer | `src/server/Boar/init.luau` | **new** |
| **The client's own simulation of its own shot, and the claim it produces** | `PlayerScripts.Weapon.Claim` — no state, no remote, no draw, no camera. One function plus one cast helper | `src/client/Weapon/Claim.luau` | **new** |
| **The one firer of `FireRequest`** | `PlayerScripts.Weapon.Input` — **unchanged as the owner**; `Input.fire` gains one field on the payload it already sends | `src/client/Weapon/Input.luau` | existing |
| **The drawn dust at the landing point** | `PlayerScripts.Weapon.Effects` — **unchanged, and NOT touched by this task** | `src/client/Weapon/Effects.luau` | existing |
| **The `HIT_CLAIM` flag's declaration** | nobody at run time; `src/shared/Flags/init.luau` is frozen data | `src/shared/Flags/init.luau` | +1 row |

### 2.1 Why each new thing is not a second writer

- **`Boar.Runtime`'s history** writes no position and moves no animal. It is a record of a read the
  step already makes (`Body.position(entry.body)` into `snapshot`, `Runtime:step`). `Boar.Body`
  remains the one thing that *moves* an animal. One owner, two tenses.
- **`Weapon` does not read boar state.** It calls one provider and gets a `CFrame` back
  (`Weapon.setHistoryProvider`). It cannot enumerate animals, cannot ask where one is *now*, and
  holds nothing between shots except the claim already riding its own `ShotRecord`.
- **`Claim` is not a second answer to "where did the bullet go".** It runs
  `Ballistics.segment` and `Ballistics.advance` — the same functions the server's `Flight` runs — over
  an **injected** cast. It produces a *claim*, which is an input to `onFireRequest`, never a second
  path into `Hits.group`.
- **`Flight` never reads the claim.** It carries it on the `ShotRecord` opaquely, exactly as it
  already carries `epoch` *"for the record only"* (`src/server/Weapon/Flight.luau` → `ShotRecord`).
- **There is still exactly ONE constructor of a `HitReport`** (`Hits.group`) and it is still called
  once per shot, from `onShotLanded`.

### 2.2 Files on disk

```
src/shared/Ballistics/init.luau   -> ReplicatedStorage.Ballistics   (+Ballistics.segment; the one
                                                                     sub-step's geometry, moved OUT of
                                                                     Flight.advance so both sides step
                                                                     one bullet with one function)
src/shared/Shotgun/init.luau      -> ReplicatedStorage.Shotgun      (+CONFIG.CLAIM, +Shotgun.muzzleOf,
                                                                     +the HitClaim type, +ShotRequest.claim)
src/shared/Flags/init.luau        -> ReplicatedStorage.Flags        (+HIT_CLAIM row, MAX_FLAGS 17->18)
src/server/Weapon/init.luau       -> ServerScriptService.Weapon     (the claim gate, setHistoryProvider,
                                                                     setClaimPolicy, the 259b line, stats)
src/server/Weapon/Validator.luau  -> ...Weapon.Validator            (+checkClaim, +judgeClaim; both pure)
src/server/Weapon/Flight.luau     -> ...Weapon.Flight               (ShotRecord.claim carried opaquely,
                                                                     Resolution.reachedStuds, the inner
                                                                     sub-step through Ballistics.segment)
src/server/Weapon/Hardware.luau   -> ...Weapon.Hardware             (muzzlePosition delegates to
                                                                     Shotgun.muzzleOf: one definition)
src/server/Boar/init.luau         -> ServerScriptService.Boar       (the ring buffer, Boar.sampleAt,
                                                                     Runtime:cframeAt, CONFIG.HISTORY)
src/server/MatchBoot.server.luau  -> the composition root           (+2 lines: the history provider)
src/server/ForestTestBoot.server.luau -> the Forest Test's root     (+2 lines, the same)
src/client/Weapon/Claim.luau      -> PlayerScripts.Weapon.Claim     (NEW)
src/client/Weapon/init.luau       -> PlayerScripts.Weapon           (+Weapon.Claim export, one boundary
                                                                     read of the flag)
src/client/Weapon/Input.luau      -> PlayerScripts.Weapon.Input     (Input.fire attaches the claim)
tests/server/weapon_hits.spec.luau    (the pure judge, Flight's new field, the truncation rule)
tests/server/ballistics.spec.luau     (Ballistics.segment, and that it reproduces today's step)
tests/server/boar_history.spec.luau   (NEW, pure: Boar.sampleAt, the ring, the rewound part CFrame)
tests/server/zz_claim_window.spec.luau (NEW: the cross-system invariant, section 3.3)
tests/server/weapon_shot.spec.luau    (the LIVE forged-claim case)
tests/client/weapon_client.spec.luau  (Claim.simulate over an injected cast; what Input.fire sends)
tools/studio_mcp.py                   (SCOPE_SPECS rows for the two new specs)
```

No new folder under a mapped path needs a project edit (`ReplicatedStorage.$path` is `src/shared`,
`StarterPlayerScripts.$path` is `src/client`), so **no `rojo serve` restart and no Connect click**.
`Remotes.model.json` does **not** change: there is no new remote.

---

## 3. The data: which number lives where

### 3.1 The protocol's numbers — `Shotgun.CONFIG.CLAIM`

The rule `src/shared/Weapons/init.luau`'s header states and v2 §3.2 applies: the safety arc, the
camera origin tolerance and the rate limits are *"rules of the DRIVE and of the PROTOCOL, not
properties of a gun"*. **How much a server is willing to believe a client is a property of the
SERVER.** A per-weapon claim tolerance would let a new gun widen its own licence to claim hits.

| Field | Value | Unit | What it is, and where the number comes from |
|---|---|---|---|
| `SKIN_STUDS` | `0.15` | studs | how far outside the claimed part's own half-extents the claimed object-space offset may lie. Both sides read the same `Size`, so this absorbs floating point and nothing else |
| `POSITION_TOLERANCE_STUDS` | `6.0` | studs | check 2: the claimed world point against the server's own reconstruction from history. **One `Boar.CONFIG.BODY_SIZE` (5.5), rounded up**: the claim must be about the same animal in the same place, NOT about the same millisecond. It is deliberately loose because the shared clock is **unestablished** (task 265 item 3, section 15 item 1) and a tight bound here would silently refuse every honest claim. `stats.claimWorstStuds` reports the worst ACCEPTED disagreement so a real server can argue it down — the instrument idiom `stats.originFarthest` already uses (task 260) |
| `LINE_TOLERANCE_STUDS` | `2.0` | studs | check 3, **the check that makes the zone geometric rather than chosen**: the distance from the server's own trajectory, at the claimed arrival time, to the claimed point on the claimed box. 2.0 studs is under half a boar's trunk. It must absorb the client's straight-line animal step (section 5.4, up to ~2 studs over the rifle's longest flight) and the history's own interpolation (≈0.3 studs); tighter refuses honest shots at turning animals, looser lets a modified client shift a zone (section 5.2). The dial is the Director's |
| `AGE_MAX_SECONDS` | `0.5` | s | check 5: how old the claimed arrival may be when the shot resolves. The depth is **one upward trip plus clock skew**, not a flight time (section 5.1), so 0.5 s covers a bad connection with room |
| `FLIGHT_TOLERANCE_SECONDS` | `0.03` | s | check 6: `|claim.flightSeconds − Ballistics.timeToRange(shot, claim.distanceStuds)|`. One `FLIGHT_STEP_MAX_SECONDS` (1/30). It exists to refuse a nonsense claim, not to pin the geometry — check 3 does that |
| `REACH_SLACK_STUDS` | `1.0` | studs | check 4: the server's own shot must have travelled at least `distanceStuds − this` before it stopped — **or, when what stopped it is the claimed animal itself, at least `distanceStuds − (2·max(partHalf) + this)`** (task 269b) |
| `MAX_TARGETS` | `8` | count | the client's own bound: how many animals one simulation may test. The nearest N inside the ammo's range |
| `MAX_SUBSTEPS` | `16` | count | the client's own bound on one simulation's sub-steps. **Not `FLIGHT_MAX_SUBSTEPS` (8)**, and the difference is deliberate: the server's 8 bounds one HEARTBEAT's work across every live shot, while this bounds ONE shot's whole flight in one frame — 16 × `FLIGHT_STEP_MAX_SECONDS` = 0.53 s, above the rifle's longest 0.365 s |

### 3.2 The animal's memory — `Boar.CONFIG.HISTORY`

| Field | Value | What it is |
|---|---|---|
| `SAMPLES` | `64` | the ring's length, **in samples and not in seconds**, so it is leak-proof by construction and preallocated. One sample per `Runtime:step`, which is one per `RunService.Heartbeat` (`Runtime:run`): **1.07 s at 60 Hz, 2.1 s at 30 Hz** — a slower server remembers *longer*, which is the safe direction |
| `ENABLED` | `true`, always | **not behind the flag**, and that is deliberate: the reason `DEER_ROAD_LEAP`'s own row gives for not flagging its clip — *"a row that exists and a clip nothing asks for cost nothing"*. The cost is one table write per animal per step, inside a loop that already writes a `snapshot` entry per animal per step, and flagging data as well as behaviour would be two switches for one feature |

### 3.3 The one cross-system invariant, and the spec that holds it

`Shotgun.CONFIG.CLAIM.AGE_MAX_SECONDS` is the weapon's; `Boar.CONFIG.HISTORY.SAMPLES` is the
animal's. **A claim the weapon is willing to judge must be inside the span the animal can remember**,
or the feature fails silently as "every claim refused".

```
HISTORY.SAMPLES / 60  >=  CLAIM.AGE_MAX_SECONDS + 1/60
        1.067         >=        0.5167                   OK, 2x margin
```

Asserted in `tests/server/zz_claim_window.spec.luau` — the `zz_horn.spec` idiom, which already holds
`Horn`, `Boar.CONFIG.SENSE` and `ForestTest.SPOOK` to one `METRES_PER_STUD`.

### 3.4 The flag

A new feel-critical path is **born OFF** (CLAUDE.md, "Feature flags"; `docs/design/feature-flags.md`
§11 step 1):

```luau
HIT_CLAIM = {
    default = false,
    owner = "ServerScriptService.Weapon (and PlayerScripts.Weapon, for whether a claim is sent)",
    born = "2026-10-25 task 266",
    expires = "2026-11-15",   -- 21 days: the ceiling in feature-flags.md section 12
    why = "A shot hits what the shooter saw: the client simulates its own bullet against its own "
       .. "view and claims the hit, and the server validates it by rewinding the animal. OFF is "
       .. "exactly the game before task 266 -- no claim is sent, none is accepted, and the shot is "
       .. "resolved by the server's own flight alone.",
}
```

- **It is read ONCE, at each boundary, and the value is passed inward** — the only permitted shape.
  Server: a module-local in `src/server/Weapon/init.luau`, exactly as `ORIGIN_TOLERANCE_STUDS` already
  resolves `FIRST_PERSON` there (task 260). Client: a module-local in `src/client/Weapon/init.luau`,
  handed to `Input` once at `start`.
- **Both states are reachable BY PARAMETER while the row sits at one of them**, which CLAUDE.md
  requires: `Validator.checkClaim` and `Validator.judgeClaim` are pure and always reachable, and
  `Weapon.setClaimPolicy(enabled: boolean?)` is the seam a live spec switches for one case and
  restores — the shape `Weapon.setArmingPolicy` and `Weapon.setCast` already have.
- **`Flags.MAX_FLAGS` must go 17 -> 18.** Seventeen rows are declared and the cap is seventeen, so
  `tests/server/flags.spec.luau`'s rot tripwire refuses an eighteenth. The two ways out are the two
  tasks 238, 245b and 251 each wrote down: retire the three lit rows queued as TASKS.md 82b (the
  Director's call, one archived branch per retirement), or bump the cap and say so. **This design
  takes the bump under a stated assumption**, as those three tasks did; section 16 Director 2 is where
  the Director overrules it.

---

## 4. Public interface

### 4.1 `ReplicatedStorage.Ballistics` — one new function, and it is a MOVE

```luau
export type Pellet = { position: Vector3, velocity: Vector3, travelled: number, elapsed: number }

Ballistics.segment(pellet: Pellet, step: number, shot: Shot, rangeStuds: number, g: number?)
    : (Vector3, Vector3, Vector3, number, boolean)
    -- ONE SUB-STEP'S GEOMETRY, PURE, AND NOTHING ELSE. Returns
    --   (nextPosition, nextVelocity, segment, length, capped)
    -- where `segment` is the piece of path just travelled -- the thing to cast -- and `capped` says
    -- the ammo's range ran out inside this sub-step, in which case `segment` has already been cut to
    -- exactly `rangeStuds - pellet.travelled`. It MUTATES NOTHING and allocates no table (five
    -- return values, the idiom `Ballistics.advance`'s two already set).
    --
    -- IT IS MOVED OUT OF `Flight.advance`, NOT WRITTEN AGAIN. Before task 266 this arithmetic was
    -- inline in the server's stepper; the client now has to step the same bullet, and a second copy
    -- would be two answers to "where did the bullet go" -- the failure
    -- `docs/PROJECT_CONTEXT.md` records. `Flight.advance` keeps its own list, timeout, catch-up and
    -- stats and calls this for the geometry; `Claim.simulate` calls the same function.
```

Everything else in `Ballistics` is untouched: `CONFIG`, `shotFor`, `timeToRange`, `speedAt`,
`dropAt`, `elevationTangent`, `launchDirection`, `sightOffsetAt`, `advance`, `boreOrigin`,
`convergeAim`, `leadStuds`. **The exact range cap, `distance = travelled + impact.distance`, and the
chord-not-arc behaviour are preserved by construction**, because the lines that implement them move
without changing — and `weapon_hits.spec`'s existing cases 2, 6, 7 and 10 are the regression proof
(section 12).

### 4.2 `ReplicatedStorage.Shotgun` — the payload, and one accessor

```luau
-- THE SHOT REQUEST, with ONE new OPTIONAL field. Absent is every client written before task 266 and
-- is bit-for-bit today's game.
export type ShotRequest = { origin: Vector3, direction: Vector3, claim: HitClaim? }

export type HitClaim = {
    part: Instance,          -- the HitZone part the CLIENT's own bullet struck, as an Instance
                             -- reference across the remote. No id, no name, no table (CLAUDE.md:
                             -- no second id table; docs/design/map-generator.md 12.2)
    offset: Vector3,         -- the hit point in THAT PART's object space (`part:PointToObjectSpace`).
                             -- Object space, so it is independent of where the animal was, and it is
                             -- what makes "is the claimed point ON the claimed box" a pure check
    point: Vector3,          -- the same point in WORLD space, as the client drew it. The server
                             -- rebuilds it from its own history and compares (check 2). This is the
                             -- ONLY field that exists to be DISAGREED with, and its counter is the
                             -- one instrument anybody has for client/server view error
    firedAtView: number,     -- workspace:GetServerTimeNow() in the client's TRIGGER frame
    flightSeconds: number,   -- how long the client's own simulation flew before it struck
    distanceStuds: number,   -- the path studs it flew, from the bore
}
```

- **One claim per shot, and it is ONE point.** Section 6 says why, and why buckshot sends none.
- **No zone, no damage, no target root, no velocity, no ping, no pattern.** The zone is read off the
  claimed part's own `HitZone` attribute, on the server, by `Hits.targetOf`, unchanged.
- **The arrival instant is derived, never sent:** `arrivalAt = firedAtView + flightSeconds`. One
  fewer field to lie about independently, and check 6 binds the pair to the server's own
  `Ballistics.timeToRange`.

```luau
Shotgun.muzzleOf(tool: Instance?): Vector3?
    -- `tool.Handle.Muzzle.WorldPosition`, or nil. ONE DEFINITION OF WHERE THE MUZZLE IS, for both
    -- sides: `Hardware.muzzlePosition` delegates to it (it is the server's existing reader) and
    -- `Claim.simulate` uses the same function, so the client's bore and the server's cannot drift.
```

`Shotgun.remotes()` is **unchanged — six remotes, no new one.** The claim rides `FireRequest`, so it
is bounded by `FIRE_RATE_LIMIT` (6/s) with no new door for a client to push on and no second message
to match to a shot.

### 4.3 `ServerScriptService.Weapon.Validator` — pure, and still the one place a payload is judged

```luau
Validator.checkShot(req, rootPosition, config, toleranceStuds?)   -- UNCHANGED, bit for bit

Validator.checkClaim(claim: any, limits: any, pellets: number?): (boolean, string?)
    -- THE SHAPE AND THE NUMBERS. Pure, touches no Instance method, no service and no clock -- this
    -- module's own header. It checks: `claim` is a table; `claim.part` is an Instance (`typeof`, the
    -- same test `checkShot` makes of a Vector3); `offset` and `point` are finite Vector3s;
    -- `firedAtView`, `flightSeconds`, `distanceStuds` are finite non-negative numbers;
    -- `flightSeconds <= FLIGHT_MAX_SECONDS`; and `pellets == 1` (section 6).
    -- Reasons, each its own string so `stats.refusedClaimBy` names the fault:
    --   "claim-type" "claim-part" "claim-nan" "claim-flight" "claim-range" "claim-pattern"

Validator.judgeClaim(facts: {
    offset: Vector3,            -- the claim's, already shape-checked
    partHalf: Vector3,          -- the claimed part's own Size/2, read by the OWNER
    clientPoint: Vector3,       -- the claim's `point`
    serverPoint: Vector3,       -- the owner's rebuild: rewoundPartCFrame * offset
    trajectoryPoint: Vector3,   -- the SERVER's own trajectory at the claimed flight time
    reachedStuds: number,       -- how far the server's own shot got before it stopped
    claimedStuds: number,
    ageSeconds: number,         -- resolutionTime - arrivalAt. Negative means the FUTURE
    flightSeconds: number,
    expectedFlightSeconds: number,   -- Ballistics.timeToRange(shot, claimedStuds)
}, limits: any): (boolean, string?)
    -- THE SIX CHECKS, IN ONE PURE FUNCTION, DRIVEABLE WITH NUMBERS AND NO WORLD. Every tolerance is
    -- a named field of `limits` (= Shotgun.CONFIG.CLAIM), so a spec reaches both sides of each
    -- boundary at values the shipped game never produces.
    --   "claim-offset"  the offset is off the claimed box     (1)
    --   "claim-moved"   the client's point and the server's history disagree   (2)
    --   "claim-line"    the server's own trajectory did not pass the claimed point  (3)
    --   "claim-blocked" the server's own shot stopped short of the claimed distance (4)
    --   "claim-stale" / "claim-future"   the arrival time is outside the window     (5)
    --   "claim-time"    the claimed flight time is not this weapon's for that range (6)
```

### 4.4 `ServerScriptService.Weapon` — what changes

```luau
-- unchanged, and the Reviewer should check they are: start, grant, revoke, forget, getSnapshot,
-- markHit, refreshArming, refillForDrive, armingAction, reachable, roundsLeft, heldId, rowOf,
-- setCast, setDriveLineProvider, setArmingPolicy, setTargetProvider, setStandProvider,
-- setLicenceProvider, setEntitlementProvider, setDriveOpenProvider, setSafetyLineProvider,
-- onActionRequest, runCycle, catchUpFor, flightCount, flightShots, HitReported, SafetyViolated,
-- ShotFired.

Weapon.setHistoryProvider(provider: ((Instance, number) -> CFrame?)?)
    -- WHERE WAS THIS INSTANCE AT THIS SERVER TIME? The SEVENTH injected provider on this owner, in
    -- the shape the six above have, and the only one whose answer comes from the BOAR rather than
    -- the drive. Given any Instance that belongs to an animal and a `GetServerTimeNow()` stamp, it
    -- answers THAT INSTANCE'S own CFrame at that time, or nil.
    --
    -- nil IS "I DO NOT KNOW", AND IT IS FOUR DIFFERENT FACTS WITH ONE ANSWER: the instance is not an
    -- animal's, the animal is down or gone, the time is outside the ring's span, or no provider is
    -- wired at all. Every one of them REFUSES the claim, which is the weapon's own default for every
    -- provider: unwired means today's game. Called through `pcall`, like all six others.

Weapon.setClaimPolicy(enabled: boolean?): boolean?
    -- WHETHER THIS SERVER ACCEPTS CLAIMS. nil restores the boundary's own answer, which is
    -- `Flags.isOn("HIT_CLAIM")` read once at load. It exists because CLAUDE.md requires a flagged
    -- path to be reachable by PARAMETER as well as by flag, and because the live forged-claim case
    -- in `weapon_shot.spec` has to reach the ON branch while the row sits at OFF.

Weapon.stats()  -- gains, beside the existing counters:
    claims: number,              -- claims that arrived
    claimsIgnored: number,       -- arrived with the policy off (the OFF state's own instrument)
    claimsAccepted: number,
    claimsRefused: number,
    refusedClaimBy: { [string]: number },   -- by reason, copied by hand like `refusedBy`
    claimWorstStuds: number,     -- the worst ACCEPTED check-2 disagreement (the view-error meter)
    claimWorstLineStuds: number, -- the worst ACCEPTED check-3 distance (how close 2.0 really is)
```

There is **no setter for the history itself, no way to write a sample, and no remote that carries a
position, a time or a ping in either direction** except the one optional claim field above.

### 4.5 `ServerScriptService.Weapon.Flight` — two fields, no new behaviour

```luau
export type ShotRecord = {
    ... as today ...,
    claim: Shotgun.HitClaim?,   -- CARRIED AND NEVER READ by this module, exactly as `epoch` is
                                -- "for the record only". The owner judges it at the resolution.
}

export type Resolution = {
    shot: ShotRecord,
    impacts: { Impact },
    reachedStuds: number,       -- NEW: the greatest path distance any of this shot's projectiles
                                -- travelled before it retired. An unobstructed shot reaches its
                                -- range cap. It is the LINE-OF-SIGHT fact the claim is checked
                                -- against (check 4) -- measured by the flight the server already
                                -- runs, so the design adds NO cast and `Weapon.Cast` stays the one
                                -- caller of `Workspace:Raycast` under this folder.
}
```

`Flight.launch`, `Flight.substeps`, `Flight.advance`, `count`, `shots`, `stats` keep their
signatures. Inside `Flight.advance`, the sub-step's geometry becomes `Ballistics.segment` (4.1) and
`reachedStuds` is one `math.max` on a loop that already tracks `pellet.travelled`.

### 4.6 `ServerScriptService.Boar` — the memory

```luau
Boar.CONFIG.HISTORY = { SAMPLES = 64, ENABLED = true }     -- section 3.2

Boar.sampleAt(ring: { { at: number, cframe: CFrame } }, count: number, at: number): CFrame?
    -- PURE, STATIC, AND THE WHOLE OF THE REWIND. Linear interpolation between the two samples that
    -- BRACKET `at`; nil when `at` is outside the ring's own span, which is a REFUSAL and never an
    -- extrapolation -- a guess about where an animal was is exactly the thing this design must not
    -- make. Driveable with hand-written samples and no world, which is what `boar_history.spec`
    -- does.

Runtime:cframeAt(instance: Instance, at: number): CFrame?
    -- THE PROVIDER'S IMPLEMENTATION, and the one reader of the ring. It finds the entry whose
    -- `body.part` is `instance` or is its ancestor (the same walk `Hits.targetOf` makes for
    -- `Damageable`, and the same key `Runtime:takeHit` already matches on); answers nil for an
    -- entry that is dead, DOWN or GONE; interpolates the TRUNK's history with `Boar.sampleAt`; and
    -- then applies the instance's own offset in trunk space.
    --
    -- ONE CFRAME PER ANIMAL PER SAMPLE IS ENOUGH, AND THAT IS A PROPERTY OF THE BODY: every zone
    -- part is created at `trunk.CFrame * CFrame.new(spec.offset)` and WELDED to the trunk
    -- (`Body.buildZones` -> `WeldConstraint`), so its offset in trunk space is CONSTANT and can be
    -- read live: `trunk.CFrame:Inverse() * instance.CFrame`. The ring holds the trunk and nothing
    -- else -- four zones' worth of memory for the price of one.

Runtime:stats()  -- gains `historySamples` and `historyMisses` (lookups outside the span)
```

The sample is written in `Runtime:step`, in the loop that already reads every animal's position into
`snapshot`, stamped with **one** read of the server clock per step — `world.serverTime` if the world
provides it, else `Workspace:GetServerTimeNow()`. That seam is borrowed verbatim from
`src/server/Match/init.luau` → `serverTimeFor`, and the "one reading per scan, not one per member"
rule is `src/server/Lobby/init.luau`'s, which paid for it: *"two men on one pad got deadlines four
microseconds apart, because each conversion called `GetServerTimeNow()` again"*.

### 4.7 `PlayerScripts.Weapon.Claim` — the client's own shot, simulated

```luau
Claim.world(origin: Vector3, direction: Vector3, ignore: { Instance }): Shotgun.Impact?
    -- The ONLY caller of `Workspace:Raycast` under `src/client/Weapon/`, and the exact shape of
    -- `Weapon.Cast.world` on the server: RaycastParams, FilterType = Exclude, rebuilt per call.
    -- (`src/client/Camera/Rig.luau` casts too, for occlusion -- a different question with a
    -- different owner, named here so the grep claim is honest.)

Claim.only(instance: Instance): (origin, direction, ignore) -> Shotgun.Impact?
    -- The same cast with FilterType = Include and one instance: "did this segment meet THIS animal".

Claim.simulate(opts: {
    origin: Vector3, aim: Vector3,        -- the bore and the converged aim, from `Ballistics`
    shot: Ballistics.Shot, rangeStuds: number,
    targets: { { root: Instance, velocity: Vector3 } },   -- what the client can SEE, bounded
    ignore: { Instance },
    cast: Shotgun.CastFn?, castOnly: ((Instance) -> Shotgun.CastFn)?,   -- injected seams
    firedAtView: number, limits: any,
}): Shotgun.HitClaim?
    -- ONE PELLET, THE REAL FLIGHT TIME, THE CLIENT'S OWN VIEW. Pure over its injected casts: no
    -- state, no clock of its own, no camera, no remote, no Instance created, nothing drawn.
    --
    -- PER SUB-STEP (`Ballistics.segment`, the SAME function the server steps with):
    --   1. the STATIC pass: `cast(position, segment, ignore + every target)`. A tree, the ground or
    --      a post stops the simulation and there is NO CLAIM -- the client refuses to claim a hit
    --      it could not have made, which is the same line of sight check 4 makes on the server.
    --   2. the TARGET pass, for each of at most `CLAIM.MAX_TARGETS`: the segment is TRANSLATED by
    --      `-velocity * elapsed` and cast Include-filtered against that animal alone. Translating
    --      the segment is the animal's own frame; the bullet's position, velocity, drag and drop
    --      stay exactly the server's arithmetic, because they are `Ballistics.segment`'s. The
    --      impact point is translated back by `+velocity * elapsed`.
    -- The first target impact wins. `nil` means "my own bullet hit nothing I can see", and nil is
    -- the common case: a miss, a shot into the wood, and EVERY shot aimed AT a running animal
    -- instead of ahead of it (section 1.4).
```

`Input.fire` changes by one expression and keeps every property its header claims — it is still the
one firer of `FireRequest`, the hold is still checked there, and the touch door still calls the same
function:

```luau
remotes().FireRequest:FireServer({
    origin = cframe.Position,
    direction = cframe.LookVector.Unit,
    claim = if claimsOn then Claim.forCamera(cframe) else nil,   -- nil is today, bit for bit
})
```

`Claim.forCamera` is the thin gatherer: it reads the equipped Tool's muzzle through
`Shotgun.muzzleOf`, builds the bore with `Ballistics.boreOrigin` and the aim with
`Ballistics.convergeAim` (**the same two functions `onFireRequest` uses**), reads the row and the
loaded ammo off `Weapon.get()` and `ReplicatedStorage.Weapons`, collects the visible animals, and
calls `Claim.simulate`. It does not touch the camera beyond the CFrame it is handed.

**Why the client's bore and the server's agree by construction and not by luck:**
`CONFIG.BORE_ON_SIGHT_LINE` ships `true` (`src/shared/Shotgun/init.luau`, since task 260), so
`Ballistics.boreOrigin` projects the muzzle onto the camera ray and `Ballistics.convergeAim` returns
the camera's own direction *whatever the ray hit* — which is the whole of task 259/260. The two sides
therefore compute the same trajectory from the same two numbers. **With that parameter `false` they
could diverge by the 0.73 studs across the sight line**, so this design has a stated dependency on it
staying `true`; `sights.spec` is where the `false` branch is still driven.

---

## 5. The life of one shot

### 5.1 The order, end to end

| # | Where | What | Changed? |
|---|---|---|---|
| 1 | client, trigger frame | `Input.fire` → `Claim.forCamera` → `Claim.simulate`. **The whole simulation is in this one frame**, so nothing the player feels is delayed | **new** |
| 2 | wire | one `FireRequest`, `{ origin, direction, claim? }` | +1 optional field |
| 3 | server, trigger frame | rate limit → weapon id and row → `Validator.checkShot` → `StateMachine.apply{Fire}` → muzzle → the aim ray (`lookAhead`) → `origin`/`aim` (`boreOrigin`, `convergeAim`) → `stopAt` → `Rules.refuse` (including the safety lock) → `setState` → `Ballistics.shotFor` | **unchanged** |
| 4 | server, trigger frame | `Validator.checkClaim` on the claim's SHAPE. A fault counts `refusedClaimBy[reason]` and **drops the claim**; the shot proceeds | **new** |
| 5 | server, trigger frame | `flight:launch(record-with-claim, Pattern.directions(...), ballistic, catchUpFor(...))`, then `SafetyArc` → `safetySignal:Fire(player, aim, **origin**, stopAt)` (section 8) → `publish` → the bolt → `Weapon.ShotFired` → `ShotFired:FireAllClients` | unchanged but for one argument |
| 6 | server, later Heartbeats | `flight:advance(dt, castFn)` — unchanged; `Resolution.reachedStuds` is new bookkeeping | unchanged |
| 7 | server, at the resolution | `onShotLanded`: **judge the claim** (5.2), then `Hits.group` **once**, `HitReported`, `markHit`, `ShotLanded` | **new step, same shape** |

**Why step 7 and not step 4 is where the claim is judged, and why that needs no new state.** The
claimed arrival is `firedAtView + flightSeconds`, which at step 4 is still in the server's **future**
whenever the flight is longer than the upward trip — the usual case. At step 7 it is in the past by
exactly that trip, and the history covers it. **The shot in the air IS the pending queue**: the claim
rides a record `Flight` already holds for exactly the right length of time. No second remote, no shot
id, no pending table, no timeout, no race between a claim and a resolution.

### 5.2 The verdict, in the Director's order

With the shot resolved, the owner gathers the facts and `Validator.judgeClaim` decides:

0. **the policy is on** (`Weapon.setClaimPolicy` / `Flags.isOn("HIT_CLAIM")`), else `claimsIgnored`;
1. **the claimed part belongs to a live animal the server knows** — `Hits.targetOf(claim.part)`
   answers a root carrying `Damageable == true` (the attribute only the animal's own owner writes),
   and `historyProvider(claim.part, arrivalAt)` answers a CFrame. One `pcall`, one provider;
2. **the offset is on that part** — `|claim.offset|` componentwise `<= part.Size/2 + SKIN_STUDS`;
3. **the client and the server agree about where it was** —
   `|claim.point − rewoundCFrame * claim.offset| <= POSITION_TOLERANCE_STUDS`;
4. **the shot went there** — the server's own trajectory (`Ballistics.advance` from `origin` along
   `launchDirection(aim, ballistic)` for `flightSeconds`) passes within `LINE_TOLERANCE_STUDS` of
   `rewoundCFrame * claim.offset`. **This is the check that makes the ZONE geometric rather than
   chosen**, and it is checked against the server's own rewind, never the client's point;
5. **the bullet got there** — `reachedStuds + REACH_SLACK_STUDS >= claim.distanceStuds`. A tree
   between the muzzle and the animal stopped the server's own shot, so the claim dies with it. This
   is the line of sight, measured by the flight that already ran;
   **…unless the thing that stopped it IS the claimed animal, and the shortfall is inside that
   animal's own body** (task 269b): `stoppedByClaimedTarget and claimedStuds − reachedStuds <=
   2·max(partHalf) + REACH_SLACK_STUDS`. MEASURED in the Forest Test with the claim on and a deer
   running at 30 studs/s: `claim-blocked worst 2.137/1.000 (reached 11.26 of 13.40 studs)` — the
   server's own flight stopped two studs short **on the animal the claim was about**, because its
   copy of that deer sits a replication interval further along the ray than the client's. That is
   the same bullet measured twice, not a blocked line of sight. The waiver is bounded by the
   claimed part's own largest extent, so it can never excuse a claim about a bullet that went
   somewhere else; the owner decides the identity (`Hits.targetOf(firstImpact.instance) == target`)
   because it needs Instances;
6. **the clock is sane** — `0 <= ageSeconds <= AGE_MAX_SECONDS`, and
   `|flightSeconds − timeToRange(shot, distanceStuds)| <= FLIGHT_TOLERANCE_SECONDS`.

**Accepted** → the shot is **TRUNCATED**: its impact list becomes exactly one impact,

```luau
{ instance = claim.part,
  position = claim.part.CFrame * claim.offset,   -- the LIVE CFrame with the validated offset, so
                                                 -- the dust lands on the same spot of the same
                                                 -- animal the client will draw it on
  normal   = -aim,                               -- the shot's own direction, reversed: the only
                                                 -- honest normal a claim has, and what `takeHit`
                                                 -- reads it for
  distance = claim.distanceStuds,                -- path studs from the BORE (v2 1.1 item 7)
  material = claim.part.Material }
```

and `Hits.group` runs over that one impact. **Truncation is the whole of the single-answer rule:**
the claim says where the bullet actually stopped, so every impact the flight found farther out never
happened. Because a claimable shot is single-pellet (section 6), the flight had at most one impact,
and the rule reduces to *"the accepted claim replaces it"* — there is no merging, no second report,
and `pellets` is 1, as it is today for a slug.

**Refused** → counted in `claimsRefused` and `refusedClaimBy[reason]`, and **the shot resolves
exactly as it does today, from the flight's own impacts.** Section 5.3.

### 5.3 What a refused claim's shot does, and why

**It flies as an ordinary server-side flight and resolves on the server's own impacts.** Not a
forced miss, and not a silent nothing.

- It is the **only** answer that cannot be gamed. If a refusal were a miss, withholding or
  deliberately corrupting a claim would be a way to *deny* damage — and worse, every honest player on
  a bad connection would lose hits he can see. If a refusal were a hit, the checks would be
  decoration.
- It is the **only** answer that makes the flag's OFF state honest: with `HIT_CLAIM` off every claim
  is ignored, so "ignored" and "today" must be the same code path, bit for bit.
- It is the **only** answer that keeps one owner. The flight is still the server's answer to "what
  did this bullet meet"; the claim only ever replaces that answer when the server has satisfied
  itself the shooter's picture was true.

So the player's experience of a refusal is the game he has today: a shot that hits what the *server*
saw. `claimsRefused` and `refusedClaimBy` are how anybody finds out it is happening.

### 5.4 The worst thing a modified client can do with this payload, and the bound that stops it

**It can also overstate `distanceStuds` by up to one body length plus the slack, and only when the
server's own bullet stopped on that same animal** (check 5's waiver, task 269b) — which moves the
accepted impact's `distance` and nothing else: no damage, score or payout reads it.

**It can shift the zone it is credited with, by up to `LINE_TOLERANCE_STUDS` (2.0 studs), on an
animal the shot genuinely passed within 2 studs of, at a moment the server's own history agrees the
animal was there.** On a boar that is about one zone box: a gut shot claimed as a chest shot. It
cannot do any of the following, and each is a numbered check rather than a hope:

- **claim a hit on an animal it did not shoot at** — check 4 tests the server's own trajectory
  against the server's own rewind; a line that missed by more than 2 studs is refused;
- **claim through a wall, a tree or a post** — check 5: the server's own bullet stopped there, and
  that stopper is not the claimed animal, so the waiver above does not apply and
  `reachedStuds` is short and the claim dies;
- **claim an animal that was somewhere else** — check 3 against the server's history (the brief's
  acceptance 3, a probe at 30 studs, is refused by a factor of five over the tolerance);
- **claim a hit the gun could not have made** — check 6 against `Ballistics.timeToRange`, and
  `Validator.checkClaim`'s range and `pellets == 1` tests;
- **claim nine pellets, or claim a pattern** — `pellets == 1` is a shape check on the SERVER, read
  off the weapon's own row (section 6). The spread is still the server's secret
  (`docs/design/shotgun.md` §5.7);
- **name a zone, a damage number or a target root** — those are not fields of the payload;
- **claim a part it invented** — a locally created Instance does not survive the remote, and
  `Hits.targetOf` requires `Damageable == true`, which only the animal's owner writes;
- **spam claims** — the claim rides `FireRequest`, inside `FIRE_RATE_LIMIT` (6/s), behind
  `StateMachine.apply{Fire}` and an actual loaded shell;
- **help itself by replaying an old claim** — check 6's window is 0.5 s.

**What was already true and still is** (`shotgun.md` §5.7, unchanged and not weakened by this task):
*"the aim direction is unknowable to the server, so an aimbot passes every check"*. This design does
not make aim-botting easier — an aimbot already hits what the server sees. It makes **zone selection**
cheaper, by 2 studs. Nobody should later believe this validation is stronger than that.

### 5.5 What the client's straight-line step gets wrong, named rather than discovered

The client steps each visible animal at the velocity it is **drawn** moving at. An animal that
**turns** during the flight is therefore mispredicted, by the turn's own sagitta: a boar at
`Boar.CONFIG.SPRINT_SPEED` (38 studs/s) turning at the `PACE` row's run-turn rate is some tenths of a
stud out over buckshot's 0.079 s and of the order of 2 studs out over the rifle's 0.32 s at 200 m.

**Check 4 is what stops that becoming a free hit**, and the direction of the failure is the right
one: a mispredicted claim is **refused**, the shot falls back to the server's own flight, and the
player gets a miss — which is what a real shot at an animal that jinked does. The cost is that some
honest hits on hard-turning animals at long range will read as misses. That is a feel question for
Karen (section 16, Karen 1) and the dial is `LINE_TOLERANCE_STUDS`.

### 5.6 Three shapes I considered and rejected

- **A second remote, with the claim sent when the client's own bullet lands** (the faithful version:
  the client steps over real time, so an animal that turns is followed exactly). **Rejected**: it
  needs a shot id, a server-side pending table with a timeout, a new rate-limited inbound door, and a
  **race** — the claim arrives at `trigger + flight + trip` and the server's own flight resolves at
  the same instant, so "whichever came first" would decide the damage. Two correct pieces of code
  disagreeing is the failure `docs/PROJECT_CONTEXT.md` is named after. What it buys is section 5.5's
  turn error, and what that error costs is a refusal, not a wrong hit.
- **Nine claimed pellets for buckshot.** **Rejected**: the client would have to know the pattern,
  which `shotgun.md` §5.7 refuses by name (*"hands the client the pattern in advance"*), and a
  per-pellet cone check would let a modified client put all nine in one zone inside a 1.6° cone.
  Section 6 is the alternative.
- **Not flying the shot on the server at all for a claimed shot.** **Rejected**: the flight is what
  times the resolution, what answers an unclaimed shot, and — checks 4 and 5 — what proves the line of
  sight without a single new raycast. Removing it would need a hand-written segment-versus-box
  intersection test on the server, which is an invented foundation (`PROJECT_CONTEXT.md`), and would
  split the hit path in two.

---

## 6. Buckshot, and what happens to `Flight` — the coherence question, answered

**A claim is one line and one point, and it exists only where the shot IS one line and one point:
`row.PELLETS[ammo] == 1`.** That is the rifle's slug, the lever's, the shotgun's slug and the
semi-auto's slug — `src/shared/Rifle/init.luau` `PELLETS = { Slug = 1 }`,
`src/shared/Lever/init.luau` the same, `src/shared/Shotgun/init.luau`
`PELLETS = { Slug = 1, Buck = 9 }`. **It is exactly the case Karen named** (*"aim in empty space to
get hit in head neck or heart"*).

**Buckshot sends no claim and accepts none.** `Validator.checkClaim` refuses one with
`"claim-pattern"`, read off the weapon's own row on the server — so this is **data, not a bit the
client chooses**, and a client cannot select its mechanism by lying.

Why that is the right line and not a gap:

- the pattern is the server's and must stay so (`shotgun.md` §5.7);
- buckshot's whole reach is 100 studs and its flight there is **0.079 s** (v2 §10). The view error it
  would remove is a fraction of a boar, while its 1.6° full cone at that range already spans about
  **2.8 studs** — the error is *inside the pattern*;
- `Hits.group`'s contract is untouched: nine pellets on one boar stay **one** report with
  `pellets = 9`, grouped when the last pellet lands.

**So `Flight` keeps every job it has:**

| Shot | What `Flight` does | What decides the hit |
|---|---|---|
| single pellet, claim accepted | flies it, reports `reachedStuds`, provides checks 4 and 5 and the resolution clock | the **claim** (the impact list is truncated to it) |
| single pellet, claim refused or absent | flies it, exactly as today | the **flight** |
| buckshot (9 pellets) | flies all nine, exactly as today | the **flight** |
| a shot the global cap refused | resolves with no impacts, exactly as today — a refusal is a miss | nothing |

One shot, one `Hits.group`, one report per (shot, target), one owner.

---

## 7. The dust, and the mark Karen is complaining about

Karen, 2026-10-24: *"this signe where we shot ... shows we hit empty space and died"*.

- **The dust is drawn, as it is today, by `PlayerScripts.Weapon.Effects` from `ShotLanded`.** The
  payload is unchanged — `{ shooterUserId, impacts, normals, materials, parts }` — and the **`parts`
  array is exactly why this works**: task 256 added it so the client could parent the dust to the part
  that was struck and let it ride a running animal. For an accepted claim, `parts[1]` **is the animal
  the shooter saw** and `impacts[1]` is `part.CFrame * claim.offset`, so the puff lands on the right
  spot of the right animal and moves with it. The empty space is gone because the claim is the thing
  that put the impact on the animal.
- **No second drawer, and that is a deliberate deviation from the brief's bullet 3** (*"the HIT MARK
  is drawn on the client from its own claim"*). A client-local draw PLUS `ShotLanded` would be two
  things drawing one puff — the overlapping-owner failure this project is named after — and the
  shooter would see two. The claim still decides what is drawn and where; it goes through the server,
  which is also what makes the drawing honest: **a refused claim does not draw a hit.** The cost is
  one round trip, which is exactly what the dust already costs today.
- **The hit MARK (`HitMarker` → the Hud's crosshair tick) is untouched.** It is a screen-space tick,
  not a world point, and it cannot be "in empty space"; it still arrives when the bullet does, from
  `Weapon.markHit`, one per (shot, target).
- **`Effects.luau`, `Effects.play`, `Effects.playLanded` and `src/client/Hud/` are not touched by
  this task.**

---

## 8. 259b, fixed in passing: one line for the safety lock and the penalty

**The defect, measured and live** (`reviews/task-266/BRIEF.md` §3 item 4): in
`src/server/Weapon/init.luau` → `onFireRequest`,

- the **lock** asks `askLineUnsafe(player, origin, aim, stopAt)` — from `origin`, the bore, which with
  `BORE_ON_SIGHT_LINE = true` is on the sight line;
- the **penalty** is published by `safetySignal:Fire(player, aim, muzzle, stopAt)` — from `muzzle`,
  the Tool's attachment.

Same `aim`, different start, so the two rays are **parallel and 0.73 studs apart at every range**, and
`Match.Penalty.judge`'s perpendicular distance differs by up to that much — a range-independent flip
band around `SAFETY_MISS_STUDS`.

**The fix is one line: `safetySignal:Fire(player, aim, origin, stopAt)`.** The line tested and the
line published are then the same line, which is the rule the `lineUnsafe` comment already states —
*"what is refused is what would have been fired"*. `Match.onSafetyViolation(player, aim, muzzle,
stopAt)` and `Match.lineIsUnsafe` are **unchanged**: both already take the ray's start as an argument
and build a `Penalty.Shot` from it, so nothing under `src/server/Match/` is touched.

`ShotFired` and `ShotLanded` keep the Tool's `muzzle`, and that asymmetry is deliberate and already
written into the code: **a flash has to come out of the gun; a penalty has to measure the bullet's
own line.**

---

## 9. What it reads from and writes to other systems

### 9.1 Reads

| What | From | Its owner |
|---|---|---|
| the ballistic rows, `RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG`, `GRAVITY_SCALE` | `Weapons.ROWS` | `ReplicatedStorage.Weapons` — frozen, built from each gun's CONFIG |
| the flight limits, the catch-up numbers, **`CONFIG.CLAIM`** | `Shotgun.CONFIG` | `ReplicatedStorage.Shotgun` — deep-frozen, no writer |
| `HIT_CLAIM` | `Flags.isOn`, **once per boundary** (server: `src/server/Weapon/init.luau`; client: `src/client/Weapon/init.luau`) | `ReplicatedStorage.Flags` — resolved once per process, no setter |
| **where an animal WAS** | `historyProvider(instance, at)` → `Runtime:cframeAt` | `ServerScriptService.Boar` — the one store and the one reader |
| where the target IS, right now | `cast(...)` → `Workspace:Raycast` | the world (the trunk is `Boar.Body`'s) |
| `Damageable` / `HitZone` | attributes on the instance | the target's own owner — `Hits.targetOf`, unchanged |
| the shared clock | `Workspace:GetServerTimeNow()` — one read per Boar step, one per client trigger frame | the engine. **Its tightness is UNESTABLISHED**: section 15 item 1 |
| the equipped Tool's muzzle | `Shotgun.muzzleOf` | `ReplicatedStorage.Shotgun` — one definition, both sides |
| the drive line, the stand, the target, the licence, the entitlement, the drive phase, the safety line | the six existing providers | `ServerScriptService.Match` — unchanged |

**What this system still does NOT read:** boar state (velocity, brain, wound, id), another player's
view, a ping sent by a client, or any client-supplied zone, damage or target root.

### 9.2 Writes

| What | Who reads it | Their owner |
|---|---|---|
| `Weapon.HitReported(report)` — at the arrival, with `at` = the shot's time, **and its one impact now the claimed one when a claim was accepted** | `MatchBoot` → `runtime:takeHit` + `HitLog.recordHit` | `ServerScriptService.Boar`, `ServerScriptService.HitLog` |
| `HitMarker:FireClient` — at the arrival, unchanged | `PlayerScripts.Hud` | `PlayerScripts.Hud` |
| `ShotLanded:FireAllClients` — **unchanged payload**, with `parts[1]` naming the claimed animal | `PlayerScripts.Weapon` → `Effects.playLanded` | `PlayerScripts.Weapon.Effects` |
| `ShotFired:FireAllClients` — unchanged, `impacts` still always empty | the flash, the smoke, the sound, the kick | as today |
| `Weapon.ShotFired` (Bindable) — unchanged, at the TRIGGER | `MatchBoot` → `runtime:hearShot` | `ServerScriptService.Boar` |
| `Weapon.SafetyViolated` — unchanged signal, **the third argument is now `origin`** (section 8) | `MatchBoot` → `Match.Penalty` | `ServerScriptService.Match` |
| the claim counters | `weapon_state.spec`, a harness note | `ServerScriptService.Weapon` |
| the ring buffer | `Runtime:cframeAt` alone | `ServerScriptService.Boar` |

**Nothing else.** This task writes no boar state, no camera, no Hud, no team, no score, no penalty
and no `Tool`.

---

## 10. External sources

### A. FastCast / FastCast Redux — the segment cast, **adopted as a pattern, still NOT vendored**

- Docs <https://etithespir.it/FastCastAPIDocs/>; docs repo
  <https://github.com/EtiTheSpirit/FastCastAPIDocs> — **MPL-2.0**, README says *"This is obsolete"*.
  Living fork <https://github.com/010DevX101/FastCastRedux> — **MIT-0**, released 2025-01-25.
- **Well:** the right algorithm, and the reason this design can rewind at all **without a rewound
  cast**: because each step casts only the segment just travelled, a *translated* segment is a cast in
  another body's frame — which is how the client tests a moving animal with the engine's own geometry
  instead of a hand-written intersection test.
- **Badly:** ships as `.rbxm`, which this repo bans; not on Wally; far more than we need.
- **Adopted:** three sentences of it, now living in **one** place (`Ballistics.segment`, section 4.1)
  rather than inline in the server's stepper, so the server and the client step one bullet with one
  function.

### B. Valve / Source-engine lag compensation — **the rewind: analysis adopted, and now the MECHANISM is adopted TOO, bounded**

- <https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking> (public developer wiki,
  maintained; *"the server moves the player hitboxes back in time to where they were when the player
  fired"*). <https://github.com/ValveSoftware/Source-1-Games/issues/2230> ("[TF2] Add lag
  compensation for projectiles") — issue tracker, open and stale, **no code taken, no licence relied
  on**.
- **This source's verdict is REVERSED by this task, and that must be said in its own entry.** v2 §9 B
  refused it in these words: *"per-target position history, a trusted client timestamp and a rewind
  window — and it exists to defeat exactly the feeling Karen asked FOR. Lag-compensated hitscan
  removes lead."* The Director lifted that refusal on 2026-10-25
  (`reviews/task-266/BRIEF.md` §2), and **the sentence is still true of hitscan and false here**: our
  projectile keeps its real flight time, so the rewind cannot remove a lead that lives in the flight
  (section 1.4).
- **Well:** it is the correct analysis of the error — the client's picture is old by a trip plus its
  own interpolation, and no amount of server-side cleverness can make the player's screen newer. It
  also names the term everybody forgets: the interpolation delay, not only the ping.
- **Badly, and what we took instead of its shape:** Source rewinds **hitboxes and casts against
  them**, which needs a second position store per target *and* a geometry test in the rewound world.
  Roblox cannot raycast a past world, and a hand-written segment-versus-box test is an invented
  foundation. So we rewind **one `CFrame` per animal** and check the claim by **arithmetic**
  (section 5.2), and the line of sight comes from the flight the server already ran.
- **Adopted:** the rewind window and the bounded history, with the history kept by **the target's own
  owner** (`Boar`) and never by the weapon — which is the half of the old objection that still
  stands: *"two systems wrote the creature's position"* (`docs/PROJECT_CONTEXT.md`).

### C. Epic Games — Gameplay Ability System **target data**: the client computes the hit, the server validates it. **ADOPTED**

- <https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-ability-system-for-unreal-engine>
  and <https://dev.epicgames.com/documentation/en-us/unreal-engine/networking-overview-for-unreal-engine>
  — Epic's own engine documentation. **Licence: proprietary** (Epic documentation terms); read as
  prose, **no code taken**. **Maintenance: actively maintained**, versioned with each engine release.
- The shape: the owning client produces *target data* for an ability — what it hit, in its own view —
  and sends it with the activation; the server runs the ability authoritatively and may validate or
  discard that data. The engine's own guidance is that target data from a client is **a claim to be
  checked**, not a result.
- **Well:** it is exactly this design's division of labour, and it comes with the right warning —
  client-supplied target data is the single biggest trust surface an ability system has, so it is
  accepted only inside bounds the server can check for itself. It also matches the shape this repo
  already has: a **pure validator** (`Weapon.Validator`) judging a payload, with the owner deciding.
- **Badly, for us:** it is a framework, in C++, for PvP games with a replication graph; its
  prediction keys, prediction windows and rollback machinery are an entire subsystem we would be
  inventing a Luau copy of. And "validate" is left to the game: the checks are ours to design, which
  is what section 5.2 is.
- **Adopted:** the pattern — **client target data + server validation + a named refusal path** — with
  our own six checks, our own bounds table (`Shotgun.CONFIG.CLAIM`) and no prediction machinery at all
  (the client predicts *nothing it is believed about*: it is believed about the past, and the past is
  checked against the server's history).

### D. Riot Games — "Peeking into VALORANT's Netcode". **Named, and its conclusion deliberately NOT followed**

- <https://technology.riotgames.com/news/peeking-valorants-netcode> — Riot's engineering blog
  (article, all rights reserved; read as prose, nothing copied). **Maintenance:** a dated article on a
  maintained publication.
- **Well:** the clearest published statement of the opposite policy — a competitive shooter rewinds on
  the **server** with a bounded window and refuses to let the client decide what it hit, because in
  PvP a client-authoritative hit is a cheat that cannot be detected after the fact. It is also good on
  *why* a window must be bounded and on favour-the-shooter's cost to the victim.
- **Badly, for us — and this is the reason its conclusion does not transfer:** there is **no victim
  here**. The target is an AI boar, nobody shoots players, a drive is not ranked, and the worst a
  forged claim can win is points in a co-operative hunt (section 5.4). Its own cost analysis is about
  a human being shot behind cover; ours is about a wild animal being credited to the wrong zone.
- **Adopted:** the **bounded window** and the discipline of counting refusals
  (`refusedClaimBy`), from a source that argues against the mechanism. Its conclusion is refused with
  the reason written here, so nobody later cites it as though it had been overlooked.

### E. Glenn Fiedler — "What every programmer needs to know about game networking"

- <https://gafferongames.com/post/what_every_programmer_needs_to_know_about_game_networking/> —
  article; the site's sample code is **BSD-licensed**, nothing taken. **Maintenance:** a standing
  reference, still maintained and still cited.
- **Well:** the framing this design needs in one sentence — the client's view is *authoritative about
  itself and nothing else*, and every networked game has to choose which questions it will answer from
  which clock. It is also where the "do not interpolate what you can derive" discipline comes from,
  which is why the claim carries an arrival time and a flight time and **not** the animal's velocity.
- **Badly:** it is about deterministic lock-step and physics authority in symmetric games; it has no
  opinion about validating an asymmetric PvE hit claim, and no code to borrow.
- **Adopted:** one rule, stated as this design's own — **the client is believed only about what it
  SAW, never about what that means**: it names a part and a moment, and the server derives the zone,
  the damage, the distance and the verdict.

### F. Roblox engine — the clock, the cast, the remote

- <https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow>,
  <https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams>,
  <https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast>,
  <https://create.roblox.com/docs/reference/engine/classes/RemoteEvent>,
  <https://create.roblox.com/docs/reference/engine/classes/Instance#GetAttribute>. **Licence:** the
  documentation source repo <https://github.com/Roblox/creator-docs> is **CC BY 4.0**; the engine is
  proprietary. **Maintenance: actively maintained** with the engine.
- **Well:** `GetServerTimeNow()` is the one clock both sides can name without a protocol of our own,
  and this repo already trusts it across the wire for the drive's countdown
  (`src/client/Match/init.luau` → `Match.secondsLeft`, against `serverTimeFor` on the server).
  `FilterType = Include` is what lets one animal be tested in isolation. An **Instance** reference
  crosses a `RemoteEvent` intact, which is why the claim needs no id table.
- **Badly:** the documentation makes **no promise about how tightly `GetServerTimeNow()` agrees
  between a server and a client**, and task 265 could not establish it (`ESCALATE.md`, 2026-10-25:
  a ~0.17 s offset measured, *not established*, because the only control was a motionless part).
  **So the design never uses it as a precision input**: it is used inside a window
  (`AGE_MAX_SECONDS`) and a tolerance (`POSITION_TOLERANCE_STUDS = 6.0`, one body length), and the
  disagreement is **measured** by `claimWorstStuds` rather than assumed.
- **Adopted:** the clock inside a window, `Include`-filtered casts for the per-animal test, Instance
  references instead of ids, and attributes as the one description of a target.

### G. Borrowed from inside this repo (rule 2 applies to internal patterns too)

- **The injected provider.** `Weapon.setTargetProvider`, `setStandProvider`, `setDriveOpenProvider`,
  `setSafetyLineProvider` — each a `pcall`, each defaulting to "no restriction".
  `setHistoryProvider` is the seventh, and its default (nil → refuse the claim) is the same
  discipline.
- **The injected cast.** `Weapon.setCast` / `Shotgun.CastFn`. `Claim.simulate` takes the same seam, so
  the client's simulation is driveable with a scripted world and no Workspace.
- **Pure core, impure owner.** `Pattern`, `Hits`, `SafetyArc`, `StateMachine`, `Validator`, `Limits`
  are pure and take `now` as a parameter. `Validator.judgeClaim` and `Boar.sampleAt` follow exactly.
- **A number that can only be read at one value cannot be tested at another.**
  `Ballistics.dropAt`'s `g`, `Weapon.equipDelayFor`, `Validator.checkShot`'s fourth argument (task
  260), `Weapon.catchUpFor`'s `ping`. Every tolerance here is a field of a `limits` table a spec
  supplies.
- **The flag read once at the boundary and passed inward**, with a `set*Policy` seam so both states
  are reachable by parameter: `Weapon.setArmingPolicy`, `Camera.Config.FIRST_PERSON`,
  `Weapons.loadoutFor`.
- **One reading of the server clock per pass**, from `src/server/Lobby/init.luau` — which paid for the
  lesson: *"two men on one pad got deadlines four microseconds apart"*.
- **The worst-case counter as the argument for a bound.** `stats.originFarthest` /
  `originRefusedFarthest` (task 260). `claimWorstStuds` and `claimWorstLineStuds` are the same
  instrument for the two tolerances this design invents.
- **One cross-module invariant, asserted.** `tests/server/zz_horn.spec.luau` holds three modules to
  one `METRES_PER_STUD`; `zz_claim_window.spec` holds the weapon's window inside the animal's memory.

### The pattern adopted

**Client-simulated projectile with a server-validated hit claim, over a bounded per-animal position
history owned by the animal** — Epic's target-data division (C) with Valve's rewind window (B)
reduced to one `CFrame` per animal and judged by arithmetic, FastCast's segment cast (A) as the one
stepper both sides share, the engine's own clock used only inside a window (F), and VALORANT's
contrary conclusion (D) named and refused for a stated reason — **with the flight time, the drag, the
drop, the zero and the pattern untouched, so the lead this whole system exists to create is
preserved.**

---

## 11. Numeric targets

| Target | How it is measured |
|---|---|
| **a STILL animal, 3 chest shots: chest hits, dust on the chest** | reads `CLAIM.SKIN_STUDS`, `LINE_TOLERANCE_STUDS`, `POSITION_TOLERANCE_STUDS`; acceptance 1 (section 16) |
| **a RUNNING animal, aim AT the chest → miss behind by ≈ `v × timeToRange`** | reads nothing new: `Claim.simulate` produces **no claim**, so the shot is today's flight. Acceptance 2a |
| **a RUNNING animal, aim AHEAD by `v × timeToRange` → chest hit, dust on the chest** | reads `CLAIM.LINE_TOLERANCE_STUDS` (2.0) and `POSITION_TOLERANCE_STUDS` (6.0) and `Boar.CONFIG.HISTORY.SAMPLES` (64). Acceptance 2b |
| **a FORGED claim, an animal 30 studs from where it was → REFUSED** | 30 studs against `POSITION_TOLERANCE_STUDS = 6.0` — a factor of **5** — and against `LINE_TOLERANCE_STUDS = 2.0`, a factor of **15**. Acceptance 3 |
| the rewind depth a claim actually needs | **one upward trip plus skew**, not a flight time (section 5.1). Measured as `claimWorstStuds` and as the age distribution behind `AGE_MAX_SECONDS = 0.5` |
| **history memory**: ≤ 64 CFrames per animal, preallocated, **0 allocations per step after the first ring fill** | `Runtime:stats().historySamples`; a pure spec fills a ring 10 000 times and asserts the table's length never exceeds `SAMPLES` |
| **history cost** ≤ 0.02 ms per step for 24 animals | one table-field write per animal inside a loop that already writes a `snapshot` entry per animal; reported from a Forest Test run with a wall clock around `Runtime:step` |
| **the claim's cost on the client**: ≤ `MAX_TARGETS × MAX_SUBSTEPS` + `MAX_SUBSTEPS` casts in one frame = **≤ 144** | `weapon_client.spec` counts the injected cast's calls and asserts the bound; the shipped worst case is one frame per trigger pull, at most 6/s |
| **the claim's cost on the server**: **0 new raycasts**, O(1) arithmetic per claimed shot | grep: `Workspace:Raycast` appears once under `src/server/Weapon/` (`Cast.luau`); the LOS comes from `Resolution.reachedStuds` |
| `Ballistics.segment` reproduces today's step **exactly** | `ballistics.spec`: 2 000 sub-steps through `segment` against the same sequence composed from `Ballistics.advance` by hand, equal to 1e-9; `weapon_hits.spec`'s cases 2, 6, 7 and 10 unchanged and still green |
| the flight time, the drop, the zero, the pattern, `GRAVITY_SCALE` | **unchanged**, and `ballistics.spec` cases 1–9 are untouched |
| `Hits.group` is the only `HitReport` constructor; **one per (shot, target)**; `pellets` counted | grep plus `weapon_hits.spec` cases 3 and 4, unchanged |
| `report.nearest` is path studs from the BORE, for a claimed hit too | `claim.distanceStuds` is the only source, asserted in `weapon_hits.spec` |
| **0 new remotes, 0 new rate-limited doors, 0 client-supplied zones** | grep on `Shotgun.remotes` (six) and on the `HitClaim` type's fields |
| **the OFF state is bit-for-bit today's game** | `HIT_CLAIM = false` → `claimsIgnored` rises and nothing else moves; `weapon_shot.spec` asserts the claimed and unclaimed paths give identical impacts with the policy off |

---

## 12. How it is tested

### 12.1 `tests/server/weapon_hits.spec.luau` — pure, over the injected cast and an injected `dt`

Cases 1–22 stay as they are (the flight, the group, the caps, the catch-up). Added:

23. **`Validator.checkClaim` refuses every shape fault by name**: a non-table, a missing part, a
    non-Vector3 offset, a NaN, a negative flight, a flight over `FLIGHT_MAX_SECONDS`, a distance over
    the row's range, and `pellets = 9` → `"claim-pattern"`. Each reason asserted as a string, because
    `refusedClaimBy` is keyed by it.
24. **`Validator.judgeClaim` — each of the six checks, on both sides of its boundary.** Twelve
    assertions from hand-written numbers with no world: the offset just inside and just outside
    `partHalf + SKIN_STUDS`; a 5.9-stud and a 6.1-stud disagreement; a 1.9-stud and a 2.1-stud line;
    `reachedStuds` one stud short and one stud long; an age of −0.01 (`claim-future`) and of 0.51
    (`claim-stale`); a flight 0.02 s and 0.04 s out.
25. **THE FORGED CLAIM, as the brief's acceptance 3, purely**: a claim whose point is 30 studs from
    the history's answer is refused `"claim-moved"`, and the margin is asserted as a ratio over the
    tolerance so the case cannot pass by the tolerance being widened.
26. **The truncation rule**: an accepted claim replaces the flight's impact list with exactly one
    impact whose `instance` is the claimed part and whose `distance` is `claim.distanceStuds`;
    `Hits.group` over it gives one report, `pellets = 1`, the zone read from the part's `HitZone`
    attribute and **not** from the claim.
27. **A refused claim changes nothing**: the same shot, the same scripted cast, with the claim
    refused — the impacts, the report, `nearest`, the zone and `markHit` are **identical** to the same
    shot with no claim at all.
28. **`Resolution.reachedStuds`**: a pellet stopped by the stub at 40 studs reports 40; an
    unobstructed pellet reports its range cap; nine pellets report the greatest.
29. **`Flight` never reads the claim**: a `ShotRecord` whose `claim` is a deliberately hostile table
    (a metatable with an erroring `__index`) flies and resolves without touching it.

### 12.2 `tests/server/boar_history.spec.luau` — NEW, pure, no world, no clock

1. **`Boar.sampleAt` interpolates** between two bracketing samples and is exact at a sample.
2. **It REFUSES outside the span** — before the oldest and after the newest — and never extrapolates.
3. **The ring wraps** and never grows past `HISTORY.SAMPLES`; 10 000 writes leave 64 entries.
4. **The rewound part CFrame** = the trunk's rewound CFrame times the part's constant trunk-space
   offset, asserted against a hand-built trunk and child at three times.
5. **A down, dead or unknown animal answers nil**, and so does an unknown Instance.

### 12.3 `tests/server/zz_claim_window.spec.luau` — NEW, the cross-system invariant

`Boar.CONFIG.HISTORY.SAMPLES / 60 >= Shotgun.CONFIG.CLAIM.AGE_MAX_SECONDS + 1/60`, and
`CLAIM.LINE_TOLERANCE_STUDS < Boar.CONFIG.BODY_SIZE / 2` (a tolerance wider than half a body would
let a claim name the wrong end of the animal).

### 12.4 `tests/server/ballistics.spec.luau`

Cases 1–9 unchanged. Added: **`Ballistics.segment` reproduces today's step** (section 11), the exact
range cap (`capped` true with the segment cut to exactly the remainder), the chord sag at the cap
(< 0.02 studs), and that it allocates no table (five return values).

### 12.5 `tests/server/weapon_shot.spec.luau` — the LIVE cases, on the player's path

- The sight-line case is unchanged, including its drain of `Weapon.flightCount()`.
- **NEW, the forged claim through the real handler**: with `Weapon.setClaimPolicy(true)` and a
  scripted cast, `Weapon.onFireRequest(subject, { origin, direction, claim = <a hand-built claim
  naming a real HitZone part at a point 30 studs from it> })` → the shot is **taken** (the return is
  `nil`), the flight drains, `stats.claimsRefused` has moved by one, `refusedClaimBy` names the
  reason, and **no `HitReported` fired**. Then `setClaimPolicy(nil)` restores the boundary's answer.
  This is the brief's acceptance 3 **inside the gate**, and it needs no second player and no world.
- **NEW, the OFF state**: with the policy off, the same request's result is byte-identical to the same
  request with no claim, and `claimsIgnored` is what moved.

### 12.6 `tests/client/weapon_client.spec.luau`

- **`Claim.simulate` over an injected cast and a scripted world** — the client half of the core
  claim, and it is provable with no boar and no server, because the stub's answer depends on the
  step's own time exactly as `weapon_hits.spec` case 1's does:
  - aiming **AT** a target moving at 38 studs/s → **nil**, no claim;
  - aiming **AHEAD** by `Ballistics.leadStuds(shot, distance, 38)` → a claim whose `part` is the
    chest part, whose `offset` is inside the part's half-extents, whose `distanceStuds` is within a
    stud of the range and whose `flightSeconds` is within 0.01 s of `timeToRange`;
  - a **static obstruction** between the bore and the target → **nil** (the client refuses to claim
    through a tree);
  - the cast count is under the `MAX_TARGETS × MAX_SUBSTEPS` bound.
- **`Input.fire` sends the claim only when the policy is on**, and the payload still carries exactly
  `origin` and `direction` otherwise (the `shotgun.md` §5.7 shape).
- **The grep claims**: `Workspace:Raycast` under `src/client/Weapon/` appears only in `Claim.luau`;
  `firedSignal:Fire` still appears once in `src/client/Weapon/init.luau`, in the `ShotFired` handler.

### 12.7 `tests/client/shoot_boar.spec.luau`

**Unchanged.** It already leads with `Ballistics.timeToRange` through the camera owner's
`LookAtRequest`, which is the end-to-end proof on the player's path, and it is the one case that
proves the lead still has to be held. With `HIT_CLAIM` dark it exercises today's path; with the
override on it exercises the claim path and should keep passing — stated as what the Director's
acceptance run looks for, not as a gate condition.

### 12.8 Harness input, screenshots, and what cannot be tested

- **Harness input** (`tests/client/input_scenarios.txt`) can replay the click and stage the character.
  It **cannot** aim at a moving animal on a schedule and cannot express "lead this target by this
  much" (`tools/studio_mcp.py` docstring; TASKS.md Tasks 6–7), so the lead is computed **in the
  spec**, as `shoot_boar.spec` already does. **No new harness capability is needed and none is
  claimed.**
- **The harness cannot produce latency or clock skew.** A loopback Studio session reads 1–2 ms of
  ping (measured, task 256 round 2), so the claim path's *magnitude* cannot be exercised here at all.
  Everything about it is proved by **injected** times and positions in the pure specs, and only
  *bounded* in the live ones.
- **Screenshot (rule 5): required.** One capture of a slug hit on a running animal with the override
  on, inspected, showing the dust **on the animal** rather than behind it — that is the visible change
  and it is Karen's own complaint. A screenshot **cannot** show a 0.17 s view error or a lead, and
  this design does not pretend otherwise.
- **What cannot be tested at all, said plainly:** whether the shot now *feels* right, and whether
  `GetServerTimeNow()` is tight between a real client and a real server. Both are section 15.

---

## 13. The harness tables, and the gate

### 13.1 `tools/studio_mcp.py`

`BLAST_RADIUS` needs **no new row**: `src/shared/Ballistics/` → `weapon`, `src/shared/Shotgun/` →
`gun`, `src/client/Weapon` and `src/server/Weapon` → `weapon`, `src/server/Boar` → `boar`,
`src/shared/Flags` → `flags`, and `src/server/MatchBoot.server.luau` is under `src/` and so resolves
to `all`.

`SCOPE_SPECS` needs **two rows**, or `selftest` fails (every spec must belong to a scope):
`tests/server/boar_history.spec.luau` → **`boar`**; `tests/server/zz_claim_window.spec.luau` → both
**`weapon`** and **`boar`**, the dual-membership idiom the table already uses for `zz_horn`.

### 13.2 Which gate this task needs — **`test2` IS required, and that is a cost**

The files touched include **`src/server/MatchBoot.server.luau`**, which is in `TWO_PLAYER_PATHS`
(`tools/agents.py`; CLAUDE.md, "Run / test"). So the PR needs **both** lines:

```
[harness]  PASS: n/n checks @ <code commit> (clean tree) scope=all
[harness2] PASS: n/n checks @ <same commit> (clean tree)
```

**It cannot be avoided, and the reason is the design's own owner rule.** The weapon must be handed
the Boar's history, and only a composition root knows both systems — `Boar` must not require
`Weapon` and `Weapon` must not require `Boar` (`docs/design/shotgun.md` §6.3: *"neither owner depends
on the other"*). Two lines in `MatchBoot.server.luau` and two in `ForestTestBoot.server.luau` are the
whole of it. That is one human click per PR; section 16 Director 3 is where the Director may decide
otherwise (the only alternative I can see is a `Boar`-side registration, which inverts the dependency
and is worse).

Because `tools/studio_mcp.py` changes, `--scope auto` resolves to `all` anyway (`FAIL_SAFE_PATHS`),
so the review round and the PR both get the full run.

### 13.3 Build order — four commits, each green on its own

CLAUDE.md rule 4 is one task per round, and this design is bigger than one round. It splits cleanly,
and **every step before the last is invisible to the player**:

1. **`Ballistics.segment`** — the move out of `Flight.advance`, plus `Resolution.reachedStuds` and
   `Shotgun.muzzleOf`. No behaviour change at all; the proof is the existing specs plus section 12.4.
2. **The Boar's memory** — `CONFIG.HISTORY`, the ring, `Boar.sampleAt`, `Runtime:cframeAt`,
   `boar_history.spec`. Nothing reads it yet.
3. **The server's verdict** — `Validator.checkClaim`/`judgeClaim`, `setHistoryProvider`,
   `setClaimPolicy`, the counters, the truncation rule, the two composition-root lines, the
   `HIT_CLAIM` row (dark), `zz_claim_window.spec`, the live forged-claim case. **No client sends a
   claim yet, so the game is unchanged.**
4. **The client's claim** — `Claim.luau`, `Input.fire`'s one field, `weapon_client.spec`. Still dark.
   Then the Director's acceptance run with the override on, then Karen.

**Section 8's one-line 259b fix belongs in step 3** (it is in the same function and the same
`safetySignal` call) and is the only part of this task that changes the shipped game with the flag
off. It is sub-stud, it is a fix, and `match_safety.spec` is where its two rays are already measured.

---

## 14. The delta to `docs/design/shotgun.md` — stated here, so no second design run is made

| `shotgun.md` | What this design changes |
|---|---|
| **§3.1 The one server owner** | add: `Weapon.Validator` gains `checkClaim` and `judgeClaim` and is **still the one place a payload is judged**; `Weapon` gains a **seventh** provider (`setHistoryProvider`) and one policy seam (`setClaimPolicy`). The owner does not move |
| **§5.1 Shared types** | `ShotRequest` gains `claim: HitClaim?` (optional; absent is every client before task 266). `HitClaim` is new and is listed in full in section 4.2 above |
| **§5.3 The pure core** | `Validator`'s two new functions, and the division stated: **the pure half judges the numbers, the owner does the Instance reads** — `Validator` still touches no Instance method, no service and no clock |
| **§5.5 The shot, step by step** | the order is **unchanged**; one step is appended at the trigger (the claim's shape check, step 4 of section 5.1) and one at the resolution (the verdict, step 7). `safetySignal:Fire`'s third argument becomes `origin` (section 8) |
| **§5.7 "The client never names a target, and never casts"** | **REVERSED, deliberately, and this is the sentence that has to be rewritten rather than quietly contradicted.** It read: *"the client sends `{origin, direction}` and nothing else … there is then nothing to reconcile"*. From task 266 the client **does** cast, in its own view, and **does** name a part — and the tolerance that paragraph was proud of removing is back, as six named checks with their own counters. The rest of the paragraph still stands word for word, including its warning: *"the aim direction is unknowable to the server, so an aimbot passes every check. Nobody should later believe this validation is stronger than that."* What is gained is the only thing the old shape could not give: **a shot that hits what the shooter saw** |
| **§11 Numeric targets — the one config table** | `Shotgun.CONFIG` gains the `CLAIM` sub-table (section 3.1). No existing number moves |
| **§11.1 Lag** | its mitigation list gains item (4): **the claim and the rewind, bounded, task 266** — above the forward prediction of task 256, which stays exactly as it is and is **not** replaced. The two compose: the catch-up removes ping from the *server's own* flight for an unclaimed shot; the claim removes the view error for a claimed one |
| **§13.1 / §13.2 specs** | the cases in sections 12.1, 12.5 and 12.6 above |
| **§15 Open decisions** | gains the three in section 16 below |

**`GAME_DESIGN.md` rows:**

- **new row — "Where an animal WAS"**: *`ServerScriptService.Boar` — a ring of `Boar.CONFIG.HISTORY.SAMPLES`
  trunk CFrames per animal, written in `Runtime:step` and read only by `Runtime:cframeAt`. The weapon
  is handed an answer through `Weapon.setHistoryProvider` and never the buffer. `Boar.Body` is still
  the one writer of where an animal IS. `src/server/Boar/init.luau` — design
  `docs/design/ballistics.md` §§1.3, 4.6*
- **new row — "The client's claim"**: *`PlayerScripts.Weapon.Claim` — the client simulates its own
  bullet against its own view with `ReplicatedStorage.Ballistics` over an injected cast, and produces
  a claim. It draws nothing, writes nothing, fires no remote; `PlayerScripts.Weapon.Input` is still
  the one firer of `FireRequest`. `src/client/Weapon/Claim.luau` — design §4.7*
- **the weapon row (41), amended**: *"Since task 266 a single-pellet shot may carry a HIT CLAIM from
  the shooter's client — which part it struck, where on it, and when — and `ServerScriptService.Weapon`
  validates it against the Boar's position history with six checks before it becomes the shot's one
  impact. A refused claim is logged and the shot resolves from the server's own flight, exactly as
  before. Buckshot carries no claim. Behind `HIT_CLAIM`, born off."*
- **the shotgun-numbers row (44), amended**: `Shotgun.CONFIG` also carries the `CLAIM` tolerances and
  window; still six RemoteEvents.

---

## 15. What I could not verify (rule 8)

1. **THE SHARED CLOCK, first and loudest.** I cannot establish how tightly
   `Workspace:GetServerTimeNow()` agrees between a client and a server. Task 265 measured a ~0.17 s
   client/server position offset across five animals and **could not establish it** — the only control
   was a motionless part, which reads 0.000 under any clock skew (`ESCALATE.md`, 2026-10-25). Roblox's
   own documentation promises nothing about it. **The design does not depend on the number's size or
   sign** — it is used only inside `AGE_MAX_SECONDS` and against a 6.0-stud tolerance — but **if the
   skew is real and large, check 3 refuses honest claims** and the feature reads as "nothing changed".
   The instrument for exactly that is `claimWorstStuds` and `refusedClaimBy["claim-moved"]`, and the
   first thing to read after the Director's acceptance run is those two numbers. **If `claim-moved`
   dominates, the skew is real and `POSITION_TOLERANCE_STUDS` is the dial — not the design.**
2. **Roblox Studio is not available to this run** (`.agent-evidence/INDEX.md`). No number here was
   measured in a session. Every tolerance in section 3.1 is a derivation from numbers already in the
   tree (`BODY_SIZE`, `SPRINT_SPEED`, `FLIGHT_STEP_MAX_SECONDS`, the §10 flight times) and is written
   as **a bound to be measured**, not as a result.
3. **The unexplained 3-stud rump hit of task 265 item 2 is NOT explained by this design and is not
   claimed to be.** A chest-aimed shot on a moving hind landed at trunk z +2.915 against a chest
   spanning −1.625..−0.086, and the brief records it as UNEXPLAINED — not the animal's travel, not
   distance along the ray, not excluded as an instrument mispairing. If it is a view error, this
   design removes it; **if it is something else, this design hides it**, because a claim accepted at a
   2.0-stud line tolerance would absorb a 3-stud fault into "the client saw it there". That is the one
   way this task could make a real bug harder to find, and `claimWorstLineStuds` is the number that
   would show it (a worst accepted line distance sitting near the tolerance means the tolerance is
   doing work it should not have to).
4. **Whether the client's view of a `LinearVelocity`-driven trunk and its welded zone parts is
   coherent sub-frame.** The claim's offset is computed against the client's drawn part; the server
   rebuilds it against its own history. The weld makes the offset constant *by construction*
   (`Body.buildZones`), but I have not seen it on screen, and with `BOAR_MODEL` on the drawn mesh is a
   separate non-queryable child whose animation does **not** move the zone boxes — so the client aims
   at a box that may be a few centimetres from the limb it is drawn over. That is today's game and not
   this task's, but a claim makes it *the thing being claimed*.
5. **The cost of up to 144 client raycasts in one frame in a built forest** is unknown to me. A
   Roblox raycast is cheap but scene-dependent, and this is one frame per trigger pull at ≤ 6/s. If it
   measures badly the honest knob is `CLAIM.MAX_TARGETS`, not a coarser step.
6. **Whether the refusal is invisible.** A refused claim is a miss. If refusals are common for an
   honest player, the game will feel *less* reliable, not more, and no spec can tell me that — only
   Karen playing it and the counters beside her. Section 16, Karen 1.
7. **`Ballistics.segment`'s move is the one place this design touches code that is currently correct.**
   I have read `Flight.advance` and the move is mechanical, but I have not run it. Section 12.4's
   bit-for-bit case is the guard, and step 1 of the build order exists so that the move ships alone.

---

## 16. Open decisions

### For Karen — feel. **None blocks building.**

1. **Does the shot now land where she aimed, and does anything feel *less* reliable?** The one
   question this task exists for. What to do: `python tools/flags.py set HIT_CLAIM on`, play, then
   read `Weapon.stats()` — `claimsAccepted` against `claimsRefused`, and `refusedClaimBy`. *"It still
   feels behind"* and *"sometimes it does not register"* are **different** answers with different
   dials: the first is `LINE_TOLERANCE_STUDS`, the second is `POSITION_TOLERANCE_STUDS` or the clock
   (section 15 item 1).
2. **Close shots on fast animals.** v2 §5.1 item 5's table still holds for the *forward prediction*,
   and the claim now removes the view error on top of it. If close fast shots still read behind, that
   table is still the starting point of reopening the trade, not a bug report.
3. **Buckshot is unchanged, deliberately** (section 6). If she reports that buckshot specifically
   feels off on running animals, the honest knob is `DRAG_PER_STUD.Buck` or the slug `Spherecast`
   idea — **not** nine claimed pellets, which would hand the client the pattern.

### For the Director — scope. **None blocks building.**

1. **`LINE_TOLERANCE_STUDS = 2.0` is the one invented number in this mechanism**, and it is the
   cheat/feel trade in a single field: lower refuses honest shots at turning animals (section 5.5),
   higher lets a modified client shift the credited zone (section 5.4). It should be argued down from
   `claimWorstLineStuds` after a real session, exactly as `CAMERA_ORIGIN_TOLERANCE` was argued from
   `originFarthest`.
2. **`Flags.MAX_FLAGS` 17 → 18, or retire TASKS.md 82b first?** Section 3.4. The design assumes the
   bump, as tasks 238, 245b and 251 each did verbatim and for the same stated reason. One line either
   way, in the same commit as those retirements if he prefers.
3. **`test2`'s human click** (section 13.2). The composition roots must be edited, so
   `src/server/MatchBoot.server.luau` puts this task on the two-player list. I see no better place for
   the wiring that does not invert the `Boar`/`Weapon` dependency. If the Director wants to avoid the
   click, the decision is his to make explicitly — it is a rule, not an accident.
4. **When to flip `HIT_CLAIM`'s default.** It is born off and expires 2026-11-15. Karen's OK is the
   three-line commit; a refusal retires the row and archives the claim path under `backups/` (rule 7).
5. **`Match.CONFIG.SAFETY_RANGE_STUDS` is still 330 while the rifle reaches 800** (TASKS.md 183a,
   still open). Untouched again here, for the same reason: `src/server/Match/` is a
   `TWO_PLAYER_PATH` and its consumers are the drive's. Named because section 8's fix makes the
   penalty's geometry *correct*, which makes its *range* the next thing anyone will notice.
6. **Task 265's unexplained 3-stud rump hit** (section 15 item 3) is now at risk of being absorbed
   rather than found. If the Director wants it closed first, this task should wait behind it.

---

Archived 2026-10-26 by the Builder, task 271, CLAUDE.md rule 7 and this file's own v4 preamble: v3 of `docs/design/ballistics.md` as it stood at `e464c0f7`, before the Architect replaced it in place with v4 (the view instant, section 5.2.1).

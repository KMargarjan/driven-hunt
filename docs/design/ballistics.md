# Design: ballistics — a shot hits what the shooter saw. The client claims; the server validates by rewinding

**v4, Task 271 (2026-10-26).** Written to `reviews/task-271/BRIEF.md`, which **overrides** anything
older in `docs/`, `TASKS.md` and v3 of this file (CLAUDE.md, the BRIEF row).

v4 changes **one thing in the mechanism** and fixes three pieces of stale paperwork. The mechanism
change is the answer to the brief's only question — *which point check 4 is measured against* — and
it is **neither Candidate A nor Candidate B**. It is a third shape, section 5.2.1, which the brief's
own words authorise (*"offered for the Architect to accept, bound or refuse"*).

**RULE 7. v3 of this file is not deleted, it is replaced in place by the Architect script.** The
Builder must recover it from git (`git show e464c0f7:docs/design/ballistics.md`) into
`backups/design-ballistics-v3.md` with a one-line note, in the same commit as the first code change
of this task. I cannot write files.

Karen, 2026-10-24 / 2026-10-25, unchanged as the reason this system exists:

> *"it seems there is a bit off"* · *"we need to aim in empty space to get hit in head neck or heart
> like in real life"* · *"all shooting has to be like in real life / this is a key of this game"*

This file is the design for the flight of a shot AND the **delta to `docs/design/shotgun.md`**
(§§3.1, 5.1, 5.3, 5.5, **5.7**, 11, 11.1, 13.1, 13.2, 15 — section 14). Where it disagrees with
`shotgun.md` or `rifle.md`, this file wins for the flight and the claim; those win for everything
else.

---

## 0. What v4 changes, in one page

| # | What | Where |
|---|---|---|
| 1 | **THE VIEW INSTANT.** The geometric checks (3 and 4) are no longer evaluated at the single instant `arrivalAt`. The server sweeps its **own** history backwards over a bounded window, and judges at the one instant **its own trajectory** came closest to the claimed part — among the instants that pass check 3. Check 4's target is still the **server's own rewind**, never the client's point | 5.2.1, 4.4, 4.9 |
| 2 | `Shotgun.CONFIG.CLAIM` gains four rows: `VIEW_LAG_BASE_SECONDS`, `VIEW_LAG_MAX_SECONDS`, `VIEW_LAG_STEP_SECONDS`, `VIEW_LAG_MAX_SAMPLES` | 3.1 |
| 3 | `Boar.CONFIG.HISTORY.SAMPLES` **64 → 96**, forced by `zz_claim_window.spec`'s own 1.5× margin rule once the window is added to the span | 3.2, 3.3 |
| 4 | **`Validator.judgeClaim` is unchanged, bit for bit.** Two pure helpers are **moved** out of the owner into `Validator` (`closestOnSegments`, `pickViewInstant`), not written again | 4.3 |
| 5 | **Candidate A is refused**, with the arithmetic (5.6). **Candidate B is refused** (5.6). The refusals are written down so nobody re-proposes them as overlooked | 5.6 |
| 6 | §1.4's *"aiming AT a running animal still misses"* was **absolute and wrong**. Bounded, with the crossover arithmetic | 1.4 |
| 7 | §4.7 step 2 and §5.5 are brought up to the code: the two-pass refinement at the **arrival** instant, and *a refined cast that finds nothing is a MISS* | 4.7, 5.5 |
| 8 | The **check numbering** in §3.1 and §4.3 was the pre-266b scheme while §5.2, `Shotgun.CONFIG.CLAIM` and `Validator.judgeClaim` used the current one. One scheme now, §5.2's, everywhere | 3.1, 4.3 |
| 9 | A **named prediction**: `claim-future` is the next refusal to appear on a real connection, because `Weapon.catchUpFor` deliberately resolves the shot early. Not built now; the condition and the fix are written down | 5.7, 16 |

Not changed, and the brief forbids changing them: `LINE_TOLERANCE_STUDS` stays **2.0**,
`POSITION_TOLERANCE_STUDS` stays **6.0**, `AGE_MAX_SECONDS` stays **0.5**, the payload gains **no
field**, there is **no new remote** and **no new flag**.

---

## 1. What the system must do, and must not do

### 1.1 Must do — unchanged from v2

Items 1–9 of v2 §1.1 stand word for word: a shot takes time to arrive; the time is per weapon per
ammo; a target that moved out of the path is not hit and one that moved into it is; gravity drop as
data; Task 183's still-target accuracy by construction; **only the hit and the dust wait for the
bullet**; a hit's `distance` is measured from the bore; cheap and leak-proof; and the lead a player
learns is the real lead.

### 1.2 Must do — from v3

10. **A SHOT HITS WHAT THE SHOOTER SAW.** The player's screen is the only picture he can aim at. The
    shot is simulated **on his own client, against his own view, over the real flight time**, and
    the client sends a **hit claim**. The server **validates** it against its own recent position
    history. The one thing the client is believed about is **which animal it saw, and where**.
11. **The view error goes; the lead stays** (1.4).
12. **A refused claim costs the player nothing he had before.** The shot still resolves by the
    server's own flight (5.3).
13. **One line for the safety lock and the penalty** (section 8, shipped).

### 1.2a Must do — new in v4

14. **THE SERVER MUST BE ABLE TO SAY WHICH PICTURE IT BELIEVED, AND HOW OLD IT WAS.** Five tasks
    (266b, 268, 269, 269b, 270) failed to land one accepted chest claim on a running deer, and until
    271 item 1 **nothing recorded which way the gap lay**. The view lag is the quantity this whole
    feature is about, and until v4 it was neither bounded nor measured — only paid for. From v4 it
    is a server-side budget (`VIEW_LAG_*`), a per-shot measurement (`lineLagSeconds`) and a
    high-water mark (`stats.claimWorstLagSeconds`).
15. **IF THE MECHANISM CARRIES NOTHING, IT IS DELETED.** Task 269b's backward search was deleted
    because `match=0.000s` on every claim of every live trial: it loosened a rule and moved no
    number. The same standard binds this one. **If `claimWorstLagSeconds` reads under 0.02 s across
    a live trial, the sweep carried nothing and must be removed**, and the defect is elsewhere.

### 1.3 Must not — v2's rewind rule, replaced (v3, unchanged)

- **A per-animal position history EXISTS, and `ServerScriptService.Boar` is its one writer and one
  reader.** A ring buffer on the animal's own record, sampled in `src/server/Boar/init.luau` →
  `Runtime:step`, which already builds a per-animal `snapshot` of `Body.position`/`Body.velocity`
  every Heartbeat. `Boar.Body` stays the only writer of where an animal **is**; the history is the
  Boar's own record of where it **was** — one owner, two tenses.
- **Nothing under `src/server/Weapon/` keeps, samples or interpolates a target's position.** The
  weapon **asks**, through `Weapon.setHistoryProvider`, exactly as it already asks the drive six
  questions (`setTargetProvider`, `setStandProvider`, `setDriveOpenProvider`, `setSafetyLineProvider`,
  `setLicenceProvider`, `setEntitlementProvider`). A `Rewind.luau` under `src/server/Weapon/` that
  sampled Workspace itself is refused.
- **No shot is resolved against a rewound world by raycast.** `Weapon.Cast` remains the ONE caller
  of `Workspace:Raycast` under `src/server/Weapon/`. The claim is judged by **arithmetic** over
  stored `CFrame`s.

**v4's addition to this rule, because the sweep asks the provider up to 28 times instead of once:**
**the weapon chooses the instants; the Boar chooses the answers.** The weapon may not learn the
ring's length, its sample stamps, its density or its span — it asks about instants on its own grid
and gets a `CFrame?` back, exactly as it does today for one instant. **A provider that returned a
best instant, a path, or a list would be the Boar deciding a weapon question** (which instant the
*trajectory* came closest at), and the Boar must not know what a trajectory is. That is refused in
5.6 with the alternative spelled out.

### 1.4 Why this does NOT delete the lead Karen asked for — **BOUNDED, because v3's version was absolute and false**

v2 §9 source B refused the rewind because *"lag-compensated hitscan removes lead"*. That is true of
hitscan and it is false here:

- The projectile takes its **real flight time**. `Ballistics.timeToRange` is untouched, the muzzle
  velocities and drag coefficients are untouched, and `Flight` still steps the shot over that time.
- The claim comes from **the same flight, run on the client, against the animal the player can
  actually see** (`src/client/Weapon/Claim.luau` → `Claim.simulate`, which calls
  `Ballistics.segment` and `Ballistics.advance` — the server's own functions).
- What is removed is only the **view error**: the difference between where the player's screen draws
  the animal and where the server holds it. Measured at **0.178 s** on Karen's own machine
  (`reviews/task-271/BRIEF.md`, `DHClaimStats`), which at 28.7 studs/s is **5.106 studs**.

**WHAT v3 GOT WRONG.** v3 §1.4 said *"**Aiming AT a running animal still misses** — the client's own
bullet arrives where the animal is not, so no claim is produced at all"*. That sentence is absolute
and the deterministic case refutes it. `Claim.simulate` translates the animal to the **arrival**
instant and casts against its box. The claim is produced **whenever the lead fits inside the box**,
and then it names the trailing part of the body:

```
lead = v * timeToRange(shot, range)      claim exists  <=>  lead < (the box's half-extent along v)
```

For a red deer (`Boar.CONFIG.SPECIES.reddeer.BODY_SIZE = (1.8, 4.8, 7.05)`, so 3.5 studs of
half-length) crossing at 28.7 studs/s, with the slug's `MUZZLE_STUDS_PER_S = 1752`:

| range | flight (ignoring drag) | lead | aiming AT the chest |
|---|---|---|---|
| 60 studs | 0.034 s | 0.98 studs | **claims** — a hit, one stud back from the aim point |
| 120 | 0.069 | 1.97 | **claims** — the back of the chest |
| 180 | 0.103 | 2.95 | **claims** — the gut, marginal |
| 250 | 0.143 | 4.10 | **no claim** — the bullet passes behind the animal |

**So the true statement is:** *aiming AT a running animal is punished in proportion to the lead it
should have held, and becomes an outright miss once that lead exceeds the body it was aimed at.*
That is what a real shot does, and it is what the hit **zones** make interesting — at 60 studs the
careless shooter gets a gut shot instead of a heart shot, not a miss. **The crossover range is a
number to be measured, not asserted**: the table above ignores drag, which lengthens the flight and
therefore moves the crossover nearer. Section 12.6 is where it is driven.

Source-engine lag compensation rewinds so that **hitscan** hits what was drawn. We rewind so that a
**projectile fired at what was drawn** can be checked for plausibility. Identical in a one-line
summary, opposite in effect.

### 1.5 Must not — the rest, unchanged

- **No Instance per projectile.** The projectile is invisible maths on both sides.
- **No second writer of hits.** `ServerScriptService.Weapon` owns whether a shot happened and what
  it hit; `Hits.group` is the ONE constructor of a `HitReport`, **one per (shot, target)**.
- **No client-side copy of the ballistic arithmetic.** The client runs the *same functions* out of
  `ReplicatedStorage.Ballistics`.
- **No second id table.** The claim names an **Instance** (`docs/design/map-generator.md` §12.2).
- **The client never names a zone, a damage number or a target root.** It names a **part**; the zone
  is the `HitZone` attribute the animal's owner wrote, read on the server by `Hits.targetOf`.
- **No vendored FastCast. No `.rbxm`.** `RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG`,
  `SAFETY_ARC_HALF_DEG`, `GRAVITY_SCALE`, `FLIGHT_*` keep their values.
- **Everything at the trigger stays at the trigger.**
- **NEW in v4: no second clock and no second latency estimate.** `Player:GetNetworkPing()` is read in
  exactly one new place (`Weapon.viewWindowFor`), through the same `pcall`-and-clamp shape
  `Weapon.catchUpFor` already has, and the client never sends a ping.

---

## 2. Owners — one writer each, named

| Thing | The one writer | On disk | v4? |
|---|---|---|---|
| **The ballistics maths** (time of flight, remaining speed, drop, launch elevation, the bore, one sub-step's geometry and its range cap) | `ReplicatedStorage.Ballistics` — frozen numbers plus pure functions, no state, no clock, no service | `src/shared/Ballistics/init.luau` | unchanged |
| **The live projectiles on the server** | `ServerScriptService.Weapon.Flight` | `src/server/Weapon/Flight.luau` | unchanged |
| **The clock that advances them, every signal, remote, counter and report, the latency measurement, and WHETHER A CLAIM IS ACCEPTED** | `ServerScriptService.Weapon` | `src/server/Weapon/init.luau` | **+ the sweep's fact-gathering, + `viewWindowFor`** |
| **The verdict on one payload** (the shot request AND the claim) | `ServerScriptService.Weapon.Validator` — pure, no Instance, no service, no clock | `src/server/Weapon/Validator.luau` | **+2 pure functions, both MOVED** |
| **Where an animal IS** | `ServerScriptService.Boar` → `Boar.Body` | `src/server/Boar/Body.luau` | unchanged, untouched |
| **Where an animal WAS** (the ring, the sampling, the lookup, the rewound part CFrame) | `ServerScriptService.Boar` → `Runtime:step` writes, `Runtime:cframeAt` reads. **The only store and the only reader** | `src/server/Boar/init.luau` | **`SAMPLES` 64→96 only. No code change** |
| **The client's own simulation of its own shot, and the claim it produces** | `PlayerScripts.Weapon.Claim` | `src/client/Weapon/Claim.luau` | unchanged by v4 |
| **The one firer of `FireRequest`** | `PlayerScripts.Weapon.Input` | `src/client/Weapon/Input.luau` | unchanged |
| **The drawn dust at the landing point** | `PlayerScripts.Weapon.Effects` | `src/client/Weapon/Effects.luau` | unchanged, untouched |
| **The `HIT_CLAIM` flag's declaration** | nobody at run time; frozen data | `src/shared/Flags/init.luau` | unchanged |

### 2.1 Why the sweep is not a second reader of boar state

- **The weapon still holds nothing.** It asks `historyProvider(part, t)` for each `t` it chose and
  keeps the best answer **for the duration of one `onShotLanded` call**. Nothing survives the
  function. It cannot enumerate animals, cannot ask where one is *now*, and learns nothing about the
  ring.
- **`Validator` is still pure.** `pickViewInstant` takes `{ { at: number, point: Vector3 } }` — the
  owner did the Instance work. The module still touches no Instance method, no service and no clock
  (its own header rule).
- **`Boar` is unchanged except for one data row.** `Runtime:cframeAt` is called more often. That is
  it. **No new function, no new owner surface, no inverted dependency.**
- **There is still exactly ONE constructor of a `HitReport`** (`Hits.group`), called once per shot
  from `onShotLanded`.

### 2.2 Files on disk — v4's diff

```
src/shared/Shotgun/init.luau      -> ReplicatedStorage.Shotgun   (+4 CONFIG.CLAIM rows; NO type change)
src/server/Weapon/Validator.luau  -> ...Weapon.Validator         (+closestOnSegments, +pickViewInstant;
                                                                  BOTH MOVED out of the owner.
                                                                  judgeClaim UNCHANGED)
src/server/Weapon/init.luau       -> ServerScriptService.Weapon  (the sweep in the claim's fact-gathering,
                                                                  +Weapon.viewWindowFor, +3 stats fields,
                                                                  the refusal note's lag pair)
src/server/Boar/init.luau         -> ServerScriptService.Boar    (CONFIG.HISTORY.SAMPLES 64 -> 96. One row)
tests/server/weapon_hits.spec.luau     (pickViewInstant and closestOnSegments, both sides of every rule)
tests/server/zz_claim_window.spec.luau (the span now covers AGE_MAX + VIEW_LAG_MAX + 1/60)
tests/server/weapon_shot.spec.luau     (the LIVE non-regression case and the LIVE accepted-at-lag case)
tests/client/weapon_client.spec.luau   (section 1.4's crossover, driven)
tools/studio_mcp.py                    (no change: every file above is already in a scope)
```

**Nothing under `src/client/`, `src/server/Match/`, `src/server/Boar/Body.luau` or
`src/server/MatchBoot.server.luau` is touched by v4.** The composition roots already wire the
provider (task 266). **So v4 is NOT in `TWO_PLAYER_PATHS`** — see 13.2, which is a change from v3.

---

## 3. The data: which number lives where

### 3.1 The protocol's numbers — `Shotgun.CONFIG.CLAIM`

**How much a server is willing to believe a client is a property of the SERVER**, not of a gun
(`src/shared/Weapons/init.luau`'s header; v2 §3.2). A per-weapon claim tolerance would let a new gun
widen its own licence to claim hits.

**THE CHECK NUMBERS BELOW ARE §5.2's, AND THEY ARE THE ONLY SCHEME IN THIS FILE.** v3 carried two:
§5.2 and the shipped code used 2–6, while §3.1 and §4.3 still used the pre-266b 1–6. The comment in
`src/server/Weapon/Validator.luau` → `judgeClaim` records what that cost (*"the Reviewer carried that
from round 2 to round 3"*). One scheme: **2 offset · 3 moved · 4 line · 5 blocked · 6 clock**, with
0 the policy and 1 the identity, both done by the owner.

| Field | Value | Unit | What it is |
|---|---|---|---|
| `SKIN_STUDS` | `0.15` | studs | **check 2**: how far outside the claimed part's own half-extents the claimed object-space offset may lie. Both sides read the same `Size`, so this absorbs floating point and nothing else |
| `POSITION_TOLERANCE_STUDS` | `6.0` | studs | **check 3**: the claimed world point against the server's own reconstruction from history, **at the view instant** (5.2.1). One `Boar.CONFIG.BODY_SIZE` (5.5) rounded up: *the same animal in the same place*, not the same millisecond. **v4 expects this to become loose by a factor of ten** and §16 Director 1 is where it is argued down from `claimWorstStuds` |
| `LINE_TOLERANCE_STUDS` | `2.0` | studs | **check 4, the check that makes the zone geometric rather than chosen**: the perpendicular distance from the server's own trajectory to the server's own rewind of the claimed point, **at the view instant**. Under half a boar's trunk. **Unchanged by the brief's instruction**, and v4's whole argument is that it was never the wrong number — it was being measured against the wrong instant |
| `AGE_MAX_SECONDS` | `0.5` | s | **check 6**: how old the claimed arrival may be when the shot resolves. One upward trip plus clock skew, not a flight time |
| `FLIGHT_TOLERANCE_SECONDS` | `0.03` | s | **check 6's other half**: `\|flightSeconds − timeToRange(shot, distanceStuds)\|`. One `FLIGHT_STEP_MAX_SECONDS` (1/30). It refuses a nonsense claim; it does not pin the geometry |
| `REACH_SLACK_STUDS` | `1.0` | studs | **check 5**: the server's own shot must have travelled at least `distanceStuds − this`, **or, when what stopped it is the claimed animal itself**, at least `distanceStuds − (2·max(partHalf) + this)` (task 269b) |
| `MAX_TARGETS` | `8` | count | the client's bound: how many animals one simulation may test |
| `MAX_SUBSTEPS` | `16` | count | the client's bound on one simulation's sub-steps, and the server's bound on the trajectory walk. **Not `FLIGHT_MAX_SUBSTEPS` (8)**: the server's 8 bounds one HEARTBEAT across every live shot; this bounds ONE shot's whole flight |
| **`VIEW_LAG_BASE_SECONDS`** | **`0.30`** | s | **NEW.** How far back the server will look **before** any ping is added: the engine's own replication and interpolation delay plus clock skew. **MEASURED at 0.178 s** on Karen's own machine with `Player:GetNetworkPing()` reading 1.7 ms (task 256 round 2) — so this is almost entirely *not* ping, and 0.30 is that measurement with 1.7× margin. It is the one genuinely invented number in v4 and `claimWorstLagSeconds` is the instrument that argues it down |
| **`VIEW_LAG_MAX_SECONDS`** | **`0.45`** | s | **NEW.** The hard cap on the window after the ping is added, and the thing the ring's span is sized against. Source's `sv_maxunlag` plays this role and ships at **1.0 s**; we are 2.2× tighter (source B) |
| **`VIEW_LAG_STEP_SECONDS`** | **`1/60`** | s | **NEW.** The sweep's grid. One Heartbeat, which is the ring's own sampling rate (`Runtime:step` runs on `RunService.Heartbeat`), so the grid cannot be finer than the data. The quantisation error is `v · this` — **0.63 studs at `SPRINT_SPEED` 38** — and it is **conservative by construction**: a sampled minimum is never below the true minimum, so the grid can only refuse, never accept |
| **`VIEW_LAG_MAX_SAMPLES`** | **`28`** | count | **NEW.** The loop's hard cap, so the sweep is leak-proof whatever the two seconds-valued rows say. `0.45 / (1/60) = 27`, plus the arrival instant itself. `zz_claim_window.spec` asserts `VIEW_LAG_MAX_SAMPLES >= VIEW_LAG_MAX_SECONDS / VIEW_LAG_STEP_SECONDS + 1`, so the cap can never silently truncate the window |

### 3.2 The animal's memory — `Boar.CONFIG.HISTORY`

| Field | Value | What it is |
|---|---|---|
| `SAMPLES` | **`96`** (was 64) | the ring's length, **in samples and not in seconds**, so it is leak-proof by construction and preallocated. One sample per `Runtime:step` = one per Heartbeat: **1.60 s at 60 Hz, 3.2 s at 30 Hz** — a slower server remembers *longer*, the safe direction. **64 no longer satisfies §3.3** once the window is part of the span, and the number is forced by the spec's own margin rule, not chosen (3.3) |
| `ENABLED` | `true`, always | **not behind the flag.** One table write per animal per step, inside a loop that already writes a `snapshot` entry per animal per step. Flagging data as well as behaviour would be two switches for one feature |

**Cost of the change:** 32 more `{ at, cframe }` entries per animal. At 24 animals that is 768
entries, written once at ring fill and overwritten thereafter — **0 allocations per step after the
first fill**, unchanged (section 11).

### 3.3 The cross-system invariant, and the spec that holds it — **RE-DERIVED**

`Shotgun.CONFIG.CLAIM` is the weapon's; `Boar.CONFIG.HISTORY.SAMPLES` is the animal's. **A claim the
weapon is willing to judge must be inside the span the animal can remember**, or the feature fails
silently as "every claim refused". v4 makes the oldest instant the weapon can ask about
`arrivalAt − VIEW_LAG_MAX_SECONDS`, so the window grows:

```
v3:  SAMPLES/60 >= AGE_MAX + 1/60
     64/60 = 1.067  >=  0.5167                      ratio 2.07
v4:  SAMPLES/60 >= AGE_MAX + VIEW_LAG_MAX + 1/60
     64/60 = 1.067  >=  0.9667                      ratio 1.10  -- FAILS the spec's 1.5x margin
     96/60 = 1.600  >=  0.9667                      ratio 1.65  -- OK
```

`tests/server/zz_claim_window.spec.luau` already asserts `span / window >= 1.5` as well as
`span >= window`. **96 is therefore not a choice, it is the smallest multiple of the ring's own
granularity that keeps the margin the spec already demands.** The spec's `window` expression gains
`+ CLAIM.VIEW_LAG_MAX_SECONDS` and nothing else moves. Its other two assertions
(`LINE_TOLERANCE_STUDS < BODY_SIZE/2`, `POSITION_TOLERANCE_STUDS` within `[body, 2·body]`) are
untouched, and a third is added for `VIEW_LAG_MAX_SAMPLES` (3.1).

### 3.4 The flag — unchanged, and **no new flag**

`HIT_CLAIM` (`src/shared/Flags/init.luau`, born 2026-10-25 task 266, `expires = "2026-11-15"`,
default `false`) already covers every line v4 touches: the sweep lives inside
`onShotLanded`'s claim path, which does not run with the policy off. **A second flag for the view
instant would be two switches for one feature**, and `docs/design/feature-flags.md` refuses that.

The parameter reachability CLAUDE.md requires is already there and v4 strengthens it:
`Weapon.setClaimPolicy(enabled)` reaches both states of the flag, and
**`VIEW_LAG_BASE_SECONDS = 0` plus `VIEW_LAG_MAX_SECONDS = 0` reproduces v3's single-instant check
exactly** — one candidate, `arrivalAt`, the identical `serverPoint`, the identical `judgeClaim` call.
That is the non-regression proof (12.1 case 32) and it means the mechanism has a dial that turns it
fully off without touching the flag.

**`expires` is 2026-11-15 and today is 2026-10-26.** v4 does not move it. If v4's acceptance run
slips past that date, moving the date is one line and `tests/server/flags.spec.luau` will say so.

---

## 4. Public interface

### 4.1 `ReplicatedStorage.Ballistics` — unchanged in v4

```luau
export type Pellet = { position: Vector3, velocity: Vector3, travelled: number, elapsed: number }

Ballistics.segment(pellet: Pellet, step: number, shot: Shot, rangeStuds: number, g: number?)
    : (Vector3, Vector3, Vector3, number, boolean)
    -- (nextPosition, nextVelocity, segment, length, capped). ONE SUB-STEP'S GEOMETRY, PURE.
    -- Mutates nothing, allocates no table. MOVED out of `Flight.advance` in task 266, so the
    -- server's stepper and the client's simulation step one bullet with one function.
```

`CONFIG`, `shotFor`, `timeToRange`, `speedAt`, `dropAt`, `elevationTangent`, `launchDirection`,
`sightOffsetAt`, `advance`, `boreOrigin`, `convergeAim`, `leadStuds`: untouched by v4.

### 4.2 `ReplicatedStorage.Shotgun` — **the payload is unchanged**

```luau
export type ShotRequest = { origin: Vector3, direction: Vector3, claim: HitClaim? }

export type HitClaim = {
    part: Instance,          -- the HitZone part the CLIENT's own bullet struck
    offset: Vector3,         -- the hit point in THAT PART's object space
    point: Vector3,          -- the same point in WORLD space, as the client drew it
    firedAtView: number,     -- workspace:GetServerTimeNow() in the client's TRIGGER frame
    flightSeconds: number,   -- how long the client's own simulation flew before it struck
    distanceStuds: number,   -- the path studs it flew, from the bore
}
```

**NO NEW FIELD, and that is the heart of v4's answer to the brief.** Candidate B would have added
`viewLag` — a number the client chooses, inside a `VIEW_LAG_MAX_SECONDS` clamp. The window is a
property of the **server's** willingness to look back, so the server owns it; a client-supplied lag
would be one more thing to lie about and would buy nothing the sweep does not already give
(5.6 B).

`Shotgun.muzzleOf(tool)` and `Shotgun.remotes()` (**six remotes, no new one**) are unchanged. The
claim rides `FireRequest` inside `FIRE_RATE_LIMIT` (6/s).

### 4.3 `ServerScriptService.Weapon.Validator` — pure, +2 functions, **both MOVED**

```luau
Validator.checkShot(req, rootPosition, config, toleranceStuds?)        -- UNCHANGED
Validator.checkClaim(claim, limits, pellets?): (boolean, string?)      -- UNCHANGED
Validator.judgeClaim(facts, limits): (boolean, string?, number?, number?)  -- UNCHANGED, BIT FOR BIT
```

**`judgeClaim` does not change.** The whole of v4 is *which* `serverPoint` and `trajectoryPoint` the
owner hands it. That is the smallest possible diff for a change of this kind and it is deliberate:
the six checks, their reasons, their (measured, budget) pairs and all twelve boundary cases in
`weapon_hits.spec` case 24 stay green unedited.

```luau
export type Segment = { from: Vector3, to: Vector3 }

Validator.closestOnSegments(segments: { Segment }, point: Vector3): (Vector3, number)
    -- THE NEAREST POINT ON A POLYLINE, AND ITS DISTANCE. Pure. The standard clamped projection
    -- per segment, the smallest kept.
    --
    -- **IT IS MOVED, NOT WRITTEN AGAIN.** This arithmetic is inline in
    -- `src/server/Weapon/init.luau`'s claim path today (the loop that builds `closest` and
    -- `closestStuds`). v4 has to run it once per candidate instant instead of once per claim, so
    -- it becomes a function -- the same reason `Ballistics.segment` left `Flight.advance` in task
    -- 266. A second copy would be two answers to "how close did the shot pass", which is the
    -- failure `docs/PROJECT_CONTEXT.md` is named after.

Validator.pickViewInstant(
    candidates: { { at: number, point: Vector3 } },   -- NEWEST FIRST. `point` is the server's own
                                                      -- rewind of the claimed offset at `at`
    segments: { Segment },                            -- the SERVER's own trajectory, walked once
    clientPoint: Vector3,
    limits: any
): (number?, Vector3?, number?, number?, boolean)
    -- WHICH PICTURE THE SERVER WILL JUDGE AGAINST. Returns
    --   (index, trajectoryPoint, lineStuds, movedStuds, anyPassedCheck3)
    -- or (nil, nil, nil, nil, false) for an empty candidate list.
    --
    -- THE RULE, AND IT IS ORDER-INDEPENDENT AND A STRICT SUPERSET OF v3:
    --   among the candidates whose `|clientPoint - point|` is within `POSITION_TOLERANCE_STUDS`
    --   (check 3), pick the one whose `closestOnSegments(segments, point)` distance is smallest
    --   (check 4). If NONE passes check 3, pick the one with the smallest `movedStuds` -- so the
    --   refusal `judgeClaim` names is `claim-moved` with the best number the server could find,
    --   not an arbitrary one.
    --
    -- WHY FILTER ON CHECK 3 FIRST AND MINIMISE CHECK 4 SECOND. Minimising check 4 alone could pick
    -- an instant that fails check 3 where `arrivalAt` would have passed it -- an animal circling
    -- across the line of fire crosses the trajectory twice. Filtering first makes the result a
    -- STRICT SUPERSET of v3: `arrivalAt` is always candidate 1, so anything v3 accepted, v4
    -- accepts. That is asserted, not hoped (12.1 case 31).
    --
    -- PURE: no Instance, no provider, no clock, no service. The owner did the Instance work and
    -- hands numbers in, which is this module's own header rule and what makes 12.1 case 30
    -- driveable with hand-written points and no world.
```

### 4.4 `ServerScriptService.Weapon` — what changes

```luau
-- UNCHANGED, and the Reviewer should check they are: start, grant, revoke, forget, getSnapshot,
-- markHit, refreshArming, refillForDrive, armingAction, reachable, roundsLeft, heldId, rowOf,
-- setCast, setDriveLineProvider, setArmingPolicy, setTargetProvider, setStandProvider,
-- setLicenceProvider, setEntitlementProvider, setDriveOpenProvider, setSafetyLineProvider,
-- setHistoryProvider, setClaimPolicy, onActionRequest, onFireRequest, runCycle, catchUpFor,
-- flightCount, flightShots, HitReported, SafetyViolated, ShotFired.

Weapon.viewWindowFor(player: Player?, ping: number?, config: any?): number
    -- HOW FAR BACK THIS SERVER WILL LOOK FOR THIS SHOOTER, in seconds.
    --
    --   math.clamp(CLAIM.VIEW_LAG_BASE_SECONDS + ping * FLIGHT_CATCHUP_PING_FACTOR,
    --              0, CLAIM.VIEW_LAG_MAX_SECONDS)
    --
    -- **THE SHAPE IS `Weapon.catchUpFor`'s, DELIBERATELY AND LINE FOR LINE**: `ping` is a
    -- PARAMETER with a `Player:GetNetworkPing()` fallback inside a `pcall`; a negative, a NaN or a
    -- missing ping contributes ZERO rather than a guess; the result is clamped at one named
    -- ceiling. A number that can only be read at one value cannot be tested at another, and a
    -- loopback Studio session reads 1-2 ms (measured, task 256 round 2), so a spec that could not
    -- supply its own ping could not reach this function's interesting half at all.
    --
    -- **IT REUSES `FLIGHT_CATCHUP_PING_FACTOR` AND DOES NOT ADD A SECOND ONE.** That row exists
    -- because the engine's docs say only *"the network ping in seconds"* and do NOT say whether it
    -- is the round trip or one way. There is exactly one uncertainty and it must have exactly one
    -- dial; a second row would let the two readings of the same engine number drift apart.
    --
    -- THE BASE IS NOT PING. The 0.178 s measured in Karen's Forest Test was measured at 1.7 ms of
    -- ping, so the overwhelming majority of the view lag is the ENGINE's own replication and
    -- interpolation, which no latency reading reports. `VIEW_LAG_BASE_SECONDS` is that, and the
    -- ping term is what a real connection adds on top.

Weapon.stats()  -- gains, beside the existing claim counters:
    claimWorstLagSeconds: number,  -- the worst ACCEPTED `arrivalAt - tView`. **THE INSTRUMENT THIS
                                   -- WHOLE TASK EXISTS TO CREATE**: the first direct measurement of
                                   -- the view lag, and the number `VIEW_LAG_BASE_SECONDS` is to be
                                   -- argued down from. The `stats.originFarthest` idiom (task 260)
    claimLagAtEdge: number,        -- claims whose chosen instant was the OLDEST in the window. A
                                   -- non-zero value says the WINDOW is the binding constraint and
                                   -- not the tolerance -- the one reading that tells a sixth task
                                   -- apart from a seventh
    claimViewWindowMax: number,    -- the largest window handed out, so a ping-factor or a
                                   -- seconds/milliseconds mix-up is visible as a number
```

Existing claim counters are unchanged: `claims`, `claimsIgnored`, `claimsAccepted`, `claimsRefused`,
`refusedClaimBy`, `claimWorstStuds`, `claimWorstLineStuds`, `claimWorstEndStuds`, `claimAgeMin`,
`claimAgeMax`, `claimHistoryWhy`.

**No setter for the history, no way to write a sample, and no remote carrying a position, a time or
a ping in either direction** except the one optional claim field.

### 4.5 `ServerScriptService.Weapon.Flight` — unchanged in v4

```luau
export type ShotRecord = { ..., claim: Shotgun.HitClaim? }   -- carried, NEVER read by this module
export type Resolution = { shot, impacts, reachedStuds }     -- reachedStuds is check 5's fact
```

`Flight.launch`, `substeps`, `advance`, `count`, `shots`, `stats`: untouched.

### 4.6 `ServerScriptService.Boar` — one data row

```luau
Boar.CONFIG.HISTORY = { SAMPLES = 96, ENABLED = true }     -- 3.2

Boar.sampleAt(ring, count, at): CFrame?     -- UNCHANGED. Linear interpolation between the two
                                            -- samples that BRACKET `at`; nil outside the span,
                                            -- which is a REFUSAL and never an extrapolation
Runtime:cframeAt(instance, at): CFrame?     -- UNCHANGED. The one reader of the ring
Runtime:stats()                             -- UNCHANGED: historySamples, historyMisses
```

**`historyMisses` must not inflate**, and that is a constraint on the *caller*, not on this module
(4.9). The sweep stops at the first nil going backwards once it has had a non-nil answer, so at most
one miss per sweep reaches here.

### 4.7 `PlayerScripts.Weapon.Claim` — **unchanged by v4, and brought up to date here**

v3 §4.7 described the target pass as translating by `-velocity * elapsed`. **The shipped code
translates by `-velocity * (elapsed + along / speed)` and has since task 270**, and v3 was never
amended. The brief lists that as owed. The accurate description:

```luau
Claim.world(origin, direction, ignore): Shotgun.Impact?
    -- The ONLY caller of `Workspace:Raycast` under `src/client/Weapon/`, and the exact shape of
    -- `Weapon.Cast.world`: RaycastParams, FilterType = Exclude, rebuilt per call.
    -- (`src/client/Camera/Rig.luau` casts too, for occlusion -- a different question with a
    -- different owner, named here so the grep claim is honest.)

Claim.only(instance): Shotgun.CastFn
    -- The same cast, FilterType = Include, one instance: "did this segment meet THIS animal".

Claim.visibleTargets(origin, rangeStuds): { Target }
    -- `Damageable == true` and `Carcass ~= true` off the instance's own attributes, nearest first,
    -- bounded by `CLAIM.MAX_TARGETS`. No visibility test here: that is the simulation's static pass.

Claim.simulate(opts): Shotgun.HitClaim?
Claim.forCamera(cframe, snapshot?, firedAtView?): Shotgun.HitClaim?
```

**`Claim.simulate`, per sub-step (`Ballistics.segment`, the server's own function):**

1. **THE STATIC PASS.** `cast(position, segment, ignore + every target)`. **Its DISTANCE matters,
   not its existence** — one sub-step at the rifle's 2612 studs/s is `FLIGHT_STEP_MAX_SECONDS`, which
   is **87 studs**, so the ground beyond the animal is almost always inside the *same* segment as the
   animal. Returning nil on any static answer made the feature inert by construction and no spec
   could see it (measured 2026-10-25). The nearest thing in the sub-step wins. A tree **in front of**
   the animal still kills the claim — the same line of sight check 5 tests from the server's side.
2. **THE TARGET PASS, TWO PASSES, AND THE SECOND IS THE ANSWER.** For each of at most `MAX_TARGETS`,
   the segment is translated into the animal's own frame and cast Include-filtered against that
   animal alone. **The translation is `-velocity * (elapsed + along / speed)` — the instant the
   bullet ARRIVES, not the sub-step's first edge.** `along` is the cast's own answer, so it cannot be
   known before the cast: the first pass finds it, the second re-asks with the animal moved there.
   One refinement converges, because the correction to `along` is second order.
   **A REFINED CAST THAT FINDS NOTHING IS A MISS AND NO CLAIM IS MADE FOR THAT TARGET.** Keeping the
   first pass's hit would claim a hit at a coarse instant the bullet never occupied — measured at
   v = 20, d = 150, where the lead (1.186 studs) is wider than the box's own half-extent: the first
   pass hit at the quantised 0.667 and the true shot passed behind the animal altogether.

   With `elapsed` alone the lead was quantised to whole sub-steps. **MEASURED** (`weapon_client.spec`,
   a target crossing at 30 studs/s):

   | range | the lead that exists | the lead the old pass applied | error |
   |---|---|---|---|
   | 40 | 0.463 studs | 0.000 (sub-step 1) | 0.463 — **the whole lead** |
   | 100 | 1.174 | 1.000 (sub-step 2) | 0.174 |
   | 150 | 1.779 | 1.000 (sub-step 2) | 0.779 |
   | 200 | 2.399 | 2.000 (sub-step 3) | 0.398 |

   The old cases never saw it because all of them were at 200, where the quantised value is 83 % of
   the real one.

The first target impact nearer than the static block wins. **`nil` is the common case and is not a
failure**: a miss, a shot into the wood, and a shot aimed AT a running animal once the lead exceeds
the body (1.4).

**Why the client's bore and the server's agree by construction:** `CONFIG.BORE_ON_SIGHT_LINE` ships
`true` (`src/shared/Shotgun/init.luau`, task 260), so `Ballistics.boreOrigin` projects the muzzle
onto the camera ray and `Ballistics.convergeAim` returns the camera's own direction *whatever the ray
hit*. Both sides compute one trajectory from the same two numbers. **With it `false` they diverge by
0.73 studs across the sight line**, so this design has a stated dependency on it staying `true`.
`reviews/task-271/BRIEF.md` confirms this held in the live measurement: **of a 5.120-stud gap, 5.106
lay along the animal and the shot's own line was not the defect.**

### 4.8 `PlayerScripts.Weapon.Input` — unchanged

`Input.fire` is still the one firer of `FireRequest` and attaches `claim` only when the boundary read
of `HIT_CLAIM` said so. `nil` is today's payload bit for bit.

### 4.9 The sweep, in the owner — the exact shape the Builder writes

This is `onShotLanded`'s claim path, in `src/server/Weapon/init.luau`. Everything above the sweep
(the policy, `Hits.targetOf`, `claim.part:IsA("BasePart")`, `arrivalAt`, `age` and its min/max) is
**unchanged**.

```
arrivalAt = claim.firedAtView + claim.flightSeconds           -- UNCHANGED, still derived
age       = Workspace:GetServerTimeNow() - arrivalAt          -- UNCHANGED, still on arrivalAt
window    = Weapon.viewWindowFor(player)                      -- NEW

-- ONE WALK OF THE SERVER'S OWN TRAJECTORY, CACHED. `Ballistics.advance` from the shot's own bore
-- along `launchDirection(aim, ballistic)`, for exactly `claim.flightSeconds`, at most
-- `CLAIM.MAX_SUBSTEPS` segments. Walked ONCE instead of once per candidate: 16 `advance` calls
-- per claimed shot, not 448.
segments = walk(shot, claim.flightSeconds)

-- THE CANDIDATES, NEWEST FIRST, AT MOST `VIEW_LAG_MAX_SAMPLES`.
candidates = {}
lastWhy = nil
for k = 0, VIEW_LAG_MAX_SAMPLES - 1 do
    t = arrivalAt - k * VIEW_LAG_STEP_SECONDS
    if arrivalAt - t > window then break end
    where = askWhereWas(claim.part, t)
    if where == nil then
        lastWhy = <the reason askWhereWas recorded>
        -- GOING BACKWARDS, ONCE THE RING'S SPAN IS LEFT IT IS LEFT FOR GOOD, so stop -- but only
        -- AFTER a non-nil answer. `arrivalAt` itself can sit up to one Heartbeat past the newest
        -- sample, which `Boar.sampleAt` refuses rather than extrapolates, and that must not end
        -- the sweep before it starts.
        if #candidates > 0 then break else continue end
    end
    candidates[#candidates + 1] = { at = t, point = where * claim.offset }
end
if #candidates == 0 then
    stats.claimHistoryWhy = lastWhy      -- PUBLISHED ONLY HERE (see below)
    return refuse("claim-history")
end

index, trajectoryPoint, lineStuds, movedStuds, anyPassed =
    Validator.pickViewInstant(candidates, segments, claim.point, CONFIG.CLAIM)

serverPoint    = candidates[index].point
lineLagSeconds = arrivalAt - candidates[index].at
atEdge         = (index == #candidates) and lineLagSeconds > 0

ok, reason, measured, budget = Validator.judgeClaim({
    offset = claim.offset, partHalf = part.Size / 2,
    clientPoint = claim.point,
    serverPoint = serverPoint,            -- THE VIEW INSTANT'S. Checks 3 AND 4 use this one point
    trajectoryPoint = trajectoryPoint,
    reachedStuds = res.reachedStuds, claimedStuds = claim.distanceStuds,
    ageSeconds = age,                     -- STILL ON `arrivalAt`. The sweep cannot reach the future
    stoppedByClaimedTarget = stoppedBySame,
    flightSeconds = claim.flightSeconds,
    expectedFlightSeconds = Ballistics.timeToRange(ballistic, claim.distanceStuds),
}, CONFIG.CLAIM)
```

Four details that are rules, not implementation taste:

- **`stats.claimHistoryWhy` is published only when NO candidate answered.** Today `askWhereWas` sets
  it on every nil. With a sweep the oldest candidate legitimately answers nil at the ring's edge, so
  an *accepted* claim would leave a stale `"unwired"`-shaped string behind and the one diagnostic
  that told an unwired root apart from an unplaceable animal (task 266b, which cost a live session)
  would be destroyed. The sweep keeps the last reason locally and publishes it only on
  `claim-history`.
- **`Runtime:stats().historyMisses` must not inflate.** The break rule above bounds the sweep to at
  most one out-of-span lookup, so the counter keeps meaning "a claim reached past the ring".
- **The trajectory walk is NOT extended beyond `claim.flightSeconds`.** It is tempting to add one
  sub-step so the closest approach is an interior minimum, and it is wrong: one sub-step at the
  slug's `MUZZLE_STUDS_PER_S = 1752` is 58 studs of extra line, which is 58 studs of free licence for
  a forged claim that understates its flight time. The walk is the right length by construction,
  because `claim.flightSeconds` is the **client's own** and corresponds to the **client's own**
  (older, and therefore possibly farther) picture. Written down so nobody adds it later.
- **The refusal note carries the pair.** Task 271 item 1's three-axis decomposition stays exactly as
  it is, and gains `lag <lineLagSeconds>/<window>` and `atEdge`. A `claim-line` refusal that says
  `atEdge=true` means **the window is too short**; one that says `atEdge=false` means **the geometry
  is wrong**. Those are different defects and a scalar cannot tell them apart — the lesson of task
  269 (`claim-line=4` with no magnitude) and of task 270 (a magnitude with no axis).

---

## 5. The life of one shot

### 5.1 The order, end to end

| # | Where | What | v4? |
|---|---|---|---|
| 1 | client, trigger frame | `Input.fire` → `Claim.forCamera` → `Claim.simulate`. **The whole simulation is in this one frame** | unchanged |
| 2 | wire | one `FireRequest`, `{ origin, direction, claim? }` | unchanged |
| 3 | server, trigger frame | rate limit → weapon id and row → `Validator.checkShot` → `StateMachine.apply{Fire}` → muzzle → the aim ray → `boreOrigin`/`convergeAim` → `stopAt` → `Rules.refuse` → `setState` → `Ballistics.shotFor` | unchanged |
| 4 | server, trigger frame | `Validator.checkClaim` on the claim's SHAPE. A fault counts `refusedClaimBy[reason]` and **drops the claim**; the shot proceeds | unchanged |
| 5 | server, trigger frame | `flight:launch(record-with-claim, Pattern.directions(...), ballistic, catchUpFor(...))`, then `SafetyArc` → `safetySignal:Fire(player, aim, origin, stopAt)` → `publish` → the bolt → `ShotFired` | unchanged |
| 6 | server, later Heartbeats | `flight:advance(dt, castFn)`; `Resolution.reachedStuds` | unchanged |
| 7 | server, at the resolution | `onShotLanded`: **the sweep (4.9) → judge the claim (5.2) → `Hits.group` once → `HitReported`, `markHit`, `ShotLanded`** | **the sweep is new; the shape is not** |

**Why step 7 and not step 4.** The claimed arrival is `firedAtView + flightSeconds`, which at step 4
is still in the server's **future** whenever the flight is longer than the upward trip. At step 7 it
is in the past by exactly that trip, and the history covers it. **The shot in the air IS the pending
queue.** No second remote, no shot id, no pending table, no timeout, no race.

### 5.2 The verdict, in the Director's order

0. **the policy is on** (`Weapon.setClaimPolicy` / `Flags.isOn("HIT_CLAIM")`), else `claimsIgnored`;
1. **the claimed part belongs to a live animal the server knows** — `Hits.targetOf(claim.part)`
   answers a root carrying `Damageable == true`, and the history answers at least one CFrame inside
   the window. One `pcall` per lookup, one provider;
2. **the offset is on that part** — `|claim.offset|` componentwise `<= part.Size/2 + SKIN_STUDS`
   → `claim-offset`;
3. **the client and the server agree about where it was** —
   `|claim.point − serverPoint| <= POSITION_TOLERANCE_STUDS` → `claim-moved`;
4. **the shot went there** — the server's own trajectory passes within `LINE_TOLERANCE_STUDS` of
   `serverPoint` → `claim-line`. **This is the check that makes the ZONE geometric rather than
   chosen**;
5. **the bullet got there** — `reachedStuds + REACH_SLACK_STUDS >= claim.distanceStuds`, **unless
   what stopped it IS the claimed animal and the shortfall is inside that animal's own body**
   (task 269b, measured: `claim-blocked worst 2.137/1.000`) → `claim-blocked`;
6. **the clock is sane** — `0 <= ageSeconds <= AGE_MAX_SECONDS` → `claim-future` / `claim-stale`, and
   `|flightSeconds − timeToRange(shot, distanceStuds)| <= FLIGHT_TOLERANCE_SECONDS` → `claim-time`.

**Accepted** → the shot is **TRUNCATED** to exactly one impact:

```luau
{ instance = claim.part,
  position = claim.part.CFrame * claim.offset,   -- the LIVE CFrame with the validated offset
  normal   = -aim,
  distance = claim.distanceStuds,                -- path studs from the BORE
  material = claim.part.Material }
```

and `Hits.group` runs over that one impact. A claimable shot is single-pellet (section 6), so the
flight had at most one impact and this is *"the accepted claim replaces it"* — no merging, no second
report, `pellets = 1`.

**Refused** → `claimsRefused`, `refusedClaimBy[reason]`, and **the shot resolves exactly as it does
today** (5.3).

### 5.2.1 **THE VIEW INSTANT — the brief's question, answered**

> *Which point is check 4 measured against, and why?*

**Check 4 is measured against the SERVER's own rewind of the claimed point, exactly as it always
was. What changes is WHICH INSTANT that rewind is taken at.**

> **ONE INSTANT, CHOSEN BY THE SERVER'S OWN TRAJECTORY FROM THE SERVER'S OWN HISTORY, INSIDE A
> SERVER-OWNED WINDOW — AND EVERY GEOMETRIC CHECK IS EVALUATED AT IT.**

Formally, the claim is accepted iff

```
EXISTS t in [arrivalAt - window, arrivalAt]  such that
    |claim.point - rewound(t) * claim.offset|                  <= POSITION_TOLERANCE_STUDS   (3)
AND dist(server's own trajectory, rewound(t) * claim.offset)    <= LINE_TOLERANCE_STUDS       (4)
```

with `window = Weapon.viewWindowFor(player)` and the reported instant the one minimising (4) among
those satisfying (3).

**WHY. The measurement forces it and nothing else in the chain does.**
`reviews/task-271/BRIEF.md`, live, `HIT_CLAIM` on:

```
claim-line=1 worst 5.457/2.000
  gap 5.120 = along -2.079, across 4.679, ALONG THE ANIMAL +5.106   (v 28.7 studs/s, 0.178 s of it)
```

**5.106 of 5.120 studs — 99.7 % — lies along the animal's own velocity.** The shot's line is not the
defect: both sides build the bore from the same two numbers and `BORE_ON_SIGHT_LINE` ships `true`.
`serverPoint` was the animal at `firedAtView + flightSeconds`, and the animal the shooter **drew** was
replicated state 0.178 s older. v3 rewound to an instant the shooter never saw and then charged him
for the difference. **A tolerance cannot fix a wrong instant; it can only hide one.**

Decompose the measured gap on the animal's own axes: the along-animal component is 5.106, so the
residual perpendicular to the animal's path is `sqrt(5.120² − 5.106²) = 0.38 studs`. **At the right
instant this claim passes check 4 using 0.4 studs of its 2.0 budget**, plus up to 0.63 studs of grid
quantisation (3.1) — comfortably inside. That is why `LINE_TOLERANCE_STUDS` does not have to move and
why the brief was right to forbid moving it.

**WHAT A MODIFIED CLIENT GETS, AND WHY THIS IS THE SMALLEST LICENCE THAT ADMITS THE MEASUREMENT.**
The licence is *"any picture of the animal within the last `window` seconds"*, which is:

| | shipped v3 | **v4 (this design)** | Candidate A |
|---|---|---|---|
| across the animal's own path | 2.0 studs | **2.0 studs** | 8.0 studs |
| along the animal's own path | 2.0 studs | **`v · window`**: 8.6 at 28.7 studs/s, 11.4 at `SPRINT_SPEED` 38, 17.1 at the 0.45 cap | 8.0 studs |
| oldest picture creditable | the arrival instant only | **`window`** (0.30 s + ping, capped 0.45) | the arrival instant only |
| the honest measured shot (0.178 s, 5.46/2.00) | **REFUSED** | **accepted, ~0.4 of 2.0 used** | accepted |
| is check 4 still a server-side geometric test? | yes | **yes** | **no** (5.6 A) |

**The along-track licence is irreducible and every candidate pays it.** The server cannot distinguish
*"my picture was 0.178 s old"* from *"I did not lead and want credit anyway"* — they are the same
quantity. Any mechanism that accepts the measured honest gap accepts that much dishonest no-lead.
What v4 declines to pay is the **across-track** licence, which is the one that converts a clean miss
into a hit, and which Candidate A would quadruple.

**WHY THIS IS NOT TASK 269b's REFUSED SEARCH.** Round 1 of 269b put a backward search in the same
place and the Reviewer was right to refuse it. Four differences, each checkable:

1. **269b minimised check 3's own expression** (`|rewound(t)*offset − claim.point|`), so check 3
   became *"the best of thirteen"* and measured nothing. **v4 minimises check 4's expression**, whose
   left-hand side is the **server's own re-step of the shot**. `claim.point` appears in neither term
   of the thing being minimised. Check 3 is still a real comparison, at an instant the client does
   not choose.
2. **269b made `claim-future` unreachable** by stepping back until an instant answered. **v4's window
   extends only BACKWARD from `arrivalAt`, never forward**, and `ageSeconds` is still
   `resolutionTime − arrivalAt`. A client that puts `firedAtView` ahead of the server clock is still
   refused `claim-future` (12.1 case 33 asserts it).
3. **269b carried nothing**: `match=0.000s` on every claim of every live trial. **v4 is required to
   carry 0.178 s**, and §1.2a item 15 binds this design to the same standard: if
   `claimWorstLagSeconds` reads under 0.02 s across a live trial, **delete the sweep**.
4. **269b widened an accept rule with no instrument.** v4 ships three (`claimWorstLagSeconds`,
   `claimLagAtEdge`, `claimViewWindowMax`) and **predicts that `claimWorstStuds` collapses**: with
   check 3 evaluated at the view instant, the honest client/server disagreement should fall from the
   measured 5.120 studs to well under 1.0. If it does, **`POSITION_TOLERANCE_STUDS` 6.0 → 2.0 becomes
   arguable from evidence** and the system ends up *tighter* than v3 on the one axis v3 was loosest.
   That is §16 Director 1, and it is the opposite direction from Candidate A.

**THE BORROWED PATTERN.** This is Source-engine lag compensation's window, reduced to the only thing
Roblox can do: the server rewinds its own record of the target, clamps the rewind to the client's own
measured latency plus a fixed interpolation allowance, and caps it hard (`sv_maxunlag`, 1.0 s in
Source; 0.45 s here). Section 10 B and H.

### 5.3 What a refused claim's shot does, and why

**It flies as an ordinary server-side flight and resolves on the server's own impacts.** Not a forced
miss, not a silent nothing.

- It is the **only** answer that cannot be gamed. If a refusal were a miss, withholding or corrupting
  a claim would *deny* damage, and every honest player on a bad connection would lose hits he can
  see. If a refusal were a hit, the checks would be decoration.
- It is the **only** answer that makes the flag's OFF state honest: *ignored* and *today* must be the
  same code path, bit for bit.
- It is the **only** answer that keeps one owner. The flight is still the server's answer to "what
  did this bullet meet"; the claim replaces it only when the server has satisfied itself.

`claimsRefused` and `refusedClaimBy` are how anybody finds out it is happening.

### 5.4 The worst thing a modified client can do with this payload — **the enumerated bound, rewritten for v4**

**It can be credited against any picture of the animal from the last `window` seconds** (0.30 s plus
its own ping, capped at 0.45). Along the animal's own path that is `v · window`: **8.6 studs on a
28.7 studs/s deer, 11.4 on a `SPRINT_SPEED` boar, 17.1 at the cap.** Two things follow and both must
be said plainly:

- it can **claim any zone of an animal it genuinely shot at**, because an animal's zones are arranged
  head-to-tail along the axis it runs on, which is exactly the axis this licence lies on. A gut shot
  claimed as a heart shot. v3's licence for the same cheat was 2.0 studs, so on a 7.05-stud deer v3
  made it marginal and v4 makes it free;
- it can **skip the lead** and still be credited, up to `v · window` of lead. For a deer at 28.7
  studs/s that is the lead owed at about 180 studs with a slug (1.4's table). **A modified client can
  therefore play the game Karen designed against, inside that range.** An honest client cannot: its
  own simulation produces no claim.

**It can also overstate `distanceStuds`** by up to one body length plus the slack, and only when the
server's own bullet stopped on that same animal (check 5's 269b waiver) — which moves the accepted
impact's `distance` and nothing else: no damage, score or payout reads it.

**It cannot do any of the following, and each is a numbered check rather than a hope:**

- **claim a hit on an animal the bullet passed to the SIDE of** — check 4 is still the server's own
  trajectory against the server's own rewind, and 2.0 studs across the animal's path is unchanged
  from v3. **This is the property Candidate A would have destroyed**;
- **claim a hit on an animal that was never there** — check 3 against the server's own history. A
  point 30 studs from the animal is refused by a factor of five, at every instant in the window;
- **claim a picture OLDER than the window** — the sweep's loop cannot ask for one, and
  `claimLagAtEdge` reports when a claim pressed against the edge;
- **claim a picture from the FUTURE** — the window runs backward only, and `ageSeconds` is still
  measured on `arrivalAt`;
- **claim through a wall, a tree or a post** — check 5: the server's own bullet stopped there, that
  stopper is not the claimed animal, the waiver does not apply, `reachedStuds` is short;
- **claim a hit the gun could not have made** — check 6 against `Ballistics.timeToRange`, plus
  `checkClaim`'s range test;
- **claim nine pellets, or claim a pattern** — `pellets == 1` read off the weapon's own row **on the
  server** (section 6). The spread stays the server's secret;
- **name a zone, a damage number or a target root** — not fields of the payload;
- **claim a part it invented** — a locally created Instance does not survive the remote, and
  `Hits.targetOf` requires `Damageable == true`;
- **spam claims** — the claim rides `FireRequest`, inside `FIRE_RATE_LIMIT` (6/s), behind
  `StateMachine.apply{Fire}` and an actual loaded shell;
- **choose its own window** — it is `Weapon.viewWindowFor`'s, from a server constant and a server-read
  ping. The client sends no timing hint beyond `firedAtView`, which check 6 bounds.

**What was already true and still is** (`shotgun.md` §5.7): *"the aim direction is unknowable to the
server, so an aimbot passes every check"*. v4 does not make aim-botting easier. It makes **zone
selection** free on an animal the shooter genuinely engaged, and it makes **not leading** free inside
`v · window`. **Nobody should later believe this validation is stronger than that.** The reason this
is accepted is source D's: there is **no victim** — the target is an AI animal, nobody shoots players,
a drive is not ranked, and the worst a forged claim wins is points in a co-operative hunt.

### 5.5 What the client's straight-line step gets wrong, named rather than discovered

`Claim.simulate` steps each visible animal in a **straight line** at the velocity it is **drawn**
moving at, to the arrival instant (4.7). An animal that **turns** during the flight is mispredicted by
the turn's sagitta: tenths of a stud over buckshot's 0.079 s, of the order of 2 studs over the rifle's
longest 0.365 s.

**Check 4 is what stops that becoming a free hit, and the direction of the failure is the right one:**
a mispredicted claim is **refused**, the shot falls back to the server's own flight, and the player
gets a miss — which is what a real shot at an animal that jinked does.

**v4 improves this and the improvement is free.** The sweep walks the animal's **real recorded path**
out of the ring rather than a straight line, so the turn error no longer has to fit inside
`LINE_TOLERANCE_STUDS` all by itself: only the residual between the client's straight-line prediction
and the real path at the chosen instant does. The claim's own simulation is still a straight line —
that is the client's limitation and it is unchanged — but the server now judges it against the truth
instead of against a second linearisation.

The cost remains that some honest hits on hard-turning animals at long range read as misses. That is
a feel question for Karen (§16 Karen 1) and the dial is `LINE_TOLERANCE_STUDS`.

### 5.6 Shapes considered and rejected

**Candidate A — check 4 measured against the CLIENT's claimed point. REFUSED.**
The brief offers it as the Builder's reading, *"offered for the Architect to accept, bound or
refuse"*. The arithmetic refuses it:

- **It deletes check 4 rather than relocating it.** The server's "own" trajectory is re-stepped from
  `req.origin` and `req.direction` — **both supplied by the client** (`onFireRequest`, and
  `Validator.checkShot` bounds only the origin against the character root, never the direction;
  `shotgun.md` §5.7 says so in as many words). Measuring that line against the client's own point
  asks *"are your three numbers mutually consistent?"*, which a modified client satisfies by
  construction. The only server fact left in the check is the ballistic curve — it forces the point
  to lie on the declared trajectory rather than merely near the declared line. That is worth
  roughly nothing against the threat check 4 exists for.
- **It moves all the geometric weight onto check 3's 6.0-stud sphere**, and then check 4 adds 2.0 on
  top, so the effective bound becomes **8.0 studs in EVERY direction** — four times v4's across-track
  licence. A bullet that passed 7 studs to the side of an animal becomes a chest hit.
- The Director's dispatch was *"fix it by construction… **keep the anti-cheat property**"*. A has the
  first half and not the second.
- Its one real virtue — that it needs no window, no new row and no sweep — is worth about forty lines
  of owner code, which is not the right price for the only geometric check the server owns.

**Candidate B — the claim carries its own view lag, clamped. REFUSED.**
It is honest and it would work. It is refused because the window is a statement about *how much the
server is willing to believe*, which makes it the server's number — `Shotgun.CONFIG.CLAIM`'s own
header rule (3.1: *"a per-weapon claim tolerance would let a new gun widen its own licence"*; a
per-client one is worse). A client-chosen lag buys nothing the sweep does not already give: the sweep
**finds** the lag the client actually had and **reports** it (`claimWorstLagSeconds`), where B would
have the client assert it and the server merely bound the assertion. One fewer field to lie about,
one more number measured.

**A second remote, with the claim sent when the client's own bullet lands. REFUSED** (v3). It needs a
shot id, a server-side pending table with a timeout, a new rate-limited inbound door, and a **race**
between the claim and the resolution. Two correct pieces of code disagreeing is the failure
`docs/PROJECT_CONTEXT.md` is named after.

**Nine claimed pellets for buckshot. REFUSED** (v3). The client would need the pattern, which
`shotgun.md` §5.7 refuses by name, and a per-pellet cone check would let a modified client put all
nine in one zone inside a 1.6° cone.

**Not flying the shot on the server at all for a claimed shot. REFUSED** (v3). The flight times the
resolution, answers an unclaimed shot, and — checks 4 and 5 — proves the line of sight without a
single new raycast.

**A `Boar`-side provider that returns the best instant or the whole path. REFUSED, new in v4.** It
would halve the provider calls. It also requires the Boar to know what a trajectory is, or to return a
list the weapon then has to interpret — which is either the Boar answering a weapon question or the
weapon holding the buffer, and §1.3 refuses both. 28 `pcall`s at ≤6 claimed shots per second is not a
cost worth an owner boundary.

### 5.7 **A named prediction: `claim-future` is the next refusal, and v4 does not fix it**

Read off the code rather than measured, and written here so a seventh task does not discover it:

- `Weapon.catchUpFor(player, ping, config)` advances the server's own flight by up to
  `FLIGHT_CATCHUP_MAX_SECONDS` (0.15) so the bullet **resolves early** (task 256).
- `age = Workspace:GetServerTimeNow() − arrivalAt` is measured at that early resolution.
- `firedAtView` is the client's `GetServerTimeNow()`, which the engine already offsets to server
  time. So, roughly, `age ≈ (the request's upward trip) − catchUp`. With
  `FLIGHT_CATCHUP_PING_FACTOR = 1.0` the catch-up is a full round trip and the upward trip is half
  of one, so **`age` goes negative on any real connection** and check 6 refuses `claim-future`.
- On Karen's loopback it does not: the brief measures `age +0.075` with a 1.7 ms ping.

**v4 does not change this**, because fixing it means allowing a bounded negative age, which is a
tolerance change the brief excludes. **The instrument already exists**: `stats.claimAgeMin`.

> **The condition and the fix, decided in advance.** If a live trial on a real connection reports
> `claimAgeMin < 0` together with a non-zero `refusedClaimBy["claim-future"]`, the fix is one line in
> `judgeClaim`: the floor becomes `-FLIGHT_CATCHUP_MAX_SECONDS` instead of `0`, because the server
> resolved early **on purpose** and must not then charge the shooter for its own generosity. It is a
> `claim-early` reason of its own so the two cases stay distinguishable. That is a task, not a dial.

---

## 6. Buckshot, and what happens to `Flight`

**A claim is one line and one point, and it exists only where the shot IS one line and one point:
`row.PELLETS[ammo] == 1`** — the rifle's slug, the lever's, the shotgun's slug and the semi-auto's
slug (`src/shared/Rifle/init.luau`, `src/shared/Lever/init.luau`, `src/shared/Shotgun/init.luau`
`PELLETS = { Slug = 1, Buck = 9 }`). It is exactly the case Karen named.

**Buckshot sends no claim and accepts none.** `Validator.checkClaim` refuses one with
`"claim-pattern"`, read off the weapon's own row **on the server** — data, not a bit the client
chooses. Why that is the right line:

- the pattern is the server's and must stay so (`shotgun.md` §5.7);
- buckshot's whole reach is 100 studs and its flight there is **0.079 s**. The view error it would
  remove is a fraction of a boar, while its 1.6° full cone at that range already spans about **2.8
  studs** — the error is *inside the pattern*;
- `Hits.group`'s contract is untouched: nine pellets on one boar stay **one** report with
  `pellets = 9`, grouped when the last pellet lands.

| Shot | What `Flight` does | What decides the hit |
|---|---|---|
| single pellet, claim accepted | flies it, reports `reachedStuds`, provides checks 4 and 5 and the resolution clock | the **claim** (the impact list is truncated to it) |
| single pellet, claim refused or absent | flies it, exactly as today | the **flight** |
| buckshot (9 pellets) | flies all nine, exactly as today | the **flight** |
| a shot the global cap refused | resolves with no impacts — a refusal is a miss | nothing |

One shot, one `Hits.group`, one report per (shot, target), one owner.

---

## 7. The dust, and the mark Karen is complaining about

- **The dust is drawn by `PlayerScripts.Weapon.Effects` from `ShotLanded`**, payload unchanged
  (`{ shooterUserId, impacts, normals, materials, parts }`). For an accepted claim, `parts[1]` **is
  the animal the shooter saw** and `impacts[1]` is `part.CFrame * claim.offset`, so the puff lands on
  the right spot of the right animal and rides it.
- **No second drawer**, and that is a deliberate deviation from task 266's brief. A client-local draw
  **plus** `ShotLanded` would be two things drawing one puff — the overlapping-owner failure this
  project is named after — and the shooter would see two. Going through the server is also what makes
  the drawing honest: **a refused claim does not draw a hit.**
- **The hit MARK (`HitMarker` → the Hud's crosshair tick) is untouched.**
- **`Effects.luau` and `src/client/Hud/` are not touched by this task.**

---

## 8. 259b, fixed in task 266 and recorded here

`src/server/Weapon/init.luau` → `onFireRequest` published the penalty's ray from `muzzle` while the
lock tested it from `origin`. With `BORE_ON_SIGHT_LINE = true` the two rays are parallel and **0.73
studs apart at every range**, so `Match.Penalty.judge`'s perpendicular distance differed by up to
that much — a range-independent flip band around `SAFETY_MISS_STUDS`.

**The fix was one line: `safetySignal:Fire(player, aim, origin, stopAt)`.** The line tested and the
line published are the same line. `Match.onSafetyViolation` and `Match.lineIsUnsafe` are unchanged.
`ShotFired` and `ShotLanded` keep the Tool's `muzzle`, and that asymmetry is deliberate: **a flash has
to come out of the gun; a penalty has to measure the bullet's own line.** Not touched by v4.

---

## 9. What it reads from and writes to other systems

### 9.1 Reads

| What | From | Its owner |
|---|---|---|
| the ballistic rows, `RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG`, `GRAVITY_SCALE` | `Weapons.ROWS` | `ReplicatedStorage.Weapons` — frozen |
| the flight limits, the catch-up numbers, **`CONFIG.CLAIM` incl. the four `VIEW_LAG_*` rows** | `Shotgun.CONFIG` | `ReplicatedStorage.Shotgun` — deep-frozen, no writer |
| `HIT_CLAIM` | `Flags.isOn`, **once per boundary** (server `src/server/Weapon/init.luau`; client `src/client/Weapon/init.luau`) | `ReplicatedStorage.Flags` |
| **where an animal WAS, at up to `VIEW_LAG_MAX_SAMPLES` instants per claimed shot** | `historyProvider(instance, at)` → `Runtime:cframeAt` | `ServerScriptService.Boar` — the one store and the one reader |
| where the target IS, right now | `cast(...)` → `Workspace:Raycast` | the world (the trunk is `Boar.Body`'s) |
| `Damageable` / `HitZone` | attributes on the instance | the target's own owner — `Hits.targetOf` |
| the shared clock | `Workspace:GetServerTimeNow()` — one read per Boar step, one per claim resolution, one per client trigger frame | the engine. **Its tightness is UNESTABLISHED**: §15 item 1 |
| **the shooter's latency** | `Player:GetNetworkPing()` through `Weapon.viewWindowFor`, `pcall`'d, parameterised, converted by the **existing** `FLIGHT_CATCHUP_PING_FACTOR` | the engine. Unspoofable here because the client never sends it |
| the equipped Tool's muzzle | `Shotgun.muzzleOf` | `ReplicatedStorage.Shotgun` — one definition, both sides |
| the drive line, the stand, the target, the licence, the entitlement, the drive phase, the safety line | the six existing providers | `ServerScriptService.Match` |

**Still NOT read:** boar state (velocity, brain, wound, id), another player's view, a ping sent by a
client, any client-supplied zone, damage, target root or view lag.

### 9.2 Writes

| What | Who reads it | Their owner |
|---|---|---|
| `Weapon.HitReported(report)` — its one impact the claimed one when a claim was accepted | `MatchBoot` → `runtime:takeHit` + `HitLog.recordHit` | `ServerScriptService.Boar`, `ServerScriptService.HitLog` |
| `HitMarker:FireClient` — unchanged | `PlayerScripts.Hud` | `PlayerScripts.Hud` |
| `ShotLanded:FireAllClients` — unchanged payload, `parts[1]` naming the claimed animal | `PlayerScripts.Weapon` → `Effects.playLanded` | `PlayerScripts.Weapon.Effects` |
| `ShotFired:FireAllClients` / `Weapon.ShotFired` (Bindable) — unchanged | the flash, the smoke, the sound, the kick; `runtime:hearShot` | as today |
| `Weapon.SafetyViolated` — unchanged since task 266 (third argument `origin`) | `MatchBoot` → `Match.Penalty` | `ServerScriptService.Match` |
| the claim counters, **+ `claimWorstLagSeconds`, `claimLagAtEdge`, `claimViewWindowMax`** | `weapon_state.spec`, the `DHClaimStats` attribute, a harness note | `ServerScriptService.Weapon` |
| the ring buffer | `Runtime:cframeAt` alone | `ServerScriptService.Boar` |

**Nothing else.** v4 writes no boar state, no camera, no Hud, no team, no score, no penalty, no
`Tool`, and no new remote.

---

## 10. External sources

### A. FastCast / FastCast Redux — the segment cast, adopted as a pattern, **not vendored**

- Docs <https://etithespir.it/FastCastAPIDocs/>; docs repo
  <https://github.com/EtiTheSpirit/FastCastAPIDocs> — **MPL-2.0**, README says *"This is obsolete"*.
  Living fork <https://github.com/010DevX101/FastCastRedux> — **MIT-0**, released 2025-01-25.
- **Well:** the right algorithm, and the reason this design can rewind **without a rewound cast** —
  each step casts only the segment just travelled, so a *translated* segment is a cast in another
  body's frame.
- **Badly:** ships as `.rbxm`, which this repo bans; not on Wally; far more than we need.
- **Adopted:** three sentences of it, in **one** place (`Ballistics.segment`), so the server and the
  client step one bullet with one function.

### B. Valve — Source multiplayer networking and lag compensation. **The window, and v4's cap**

- <https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking> and
  <https://developer.valvesoftware.com/wiki/Lag_compensation>. **Licence:** Valve Developer Community
  wiki text, **CC BY-NC-SA 2.5** per the site's own footer; read as prose, **nothing copied**.
  **Maintenance:** actively edited community wiki.
  <https://github.com/ValveSoftware/Source-1-Games/issues/2230> ("[TF2] Add lag compensation for
  projectiles") — issue tracker, open and stale, no code taken.
- **This source's verdict was REVERSED in v3 and v4 leans on it harder.** v2 §9 B refused it as
  *"per-target position history, a trusted client timestamp and a rewind window… lag-compensated
  hitscan removes lead."* True of hitscan, false here: our projectile keeps its real flight time, so
  the rewind cannot remove a lead that lives in the flight (1.4).
- **Well:** the correct analysis of the error — the client's picture is old by a trip **plus its own
  interpolation**, and no server-side cleverness makes the player's screen newer. It names the term
  everybody forgets (the interpolation delay), and **it is the source of the exact shape v4 adopts:
  the rewind amount is clamped to the client's own measured latency plus its interpolation amount,
  and then capped hard by `sv_maxunlag` (1.0 s by default).** `Weapon.viewWindowFor` is that
  sentence: `BASE + ping`, clamped at `VIEW_LAG_MAX_SECONDS = 0.45`, **2.2× tighter than Source's
  default** because our window costs honest players nothing above about 0.25 s.
- **Badly, and what we took instead of its shape:** Source rewinds **hitboxes and casts against
  them**, which needs a second position store per target *and* a geometry test in a rewound world.
  Roblox cannot raycast a past world, and a hand-written segment-versus-box test is an invented
  foundation. So we rewind **one `CFrame` per animal** and judge by **arithmetic**, and the line of
  sight comes from the flight the server already ran. Source also rewinds *everything* at once; we
  rewind one part for one claim.
- **Adopted:** the bounded window, clamped by measured latency, capped by a constant, with the history
  kept by **the target's own owner** (`Boar`) and never by the weapon — the half of the old objection
  that still stands (*"two systems wrote the creature's position"*, `PROJECT_CONTEXT.md`).

### C. Epic Games — Gameplay Ability System **target data**: the client computes, the server validates

- <https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-ability-system-for-unreal-engine>
  and <https://dev.epicgames.com/documentation/en-us/unreal-engine/networking-overview-for-unreal-engine>.
  **Licence: proprietary** (Epic documentation terms); read as prose, **no code taken**.
  **Maintenance: actively maintained**, versioned with each engine release.
- The shape: the owning client produces *target data* — what it hit, in its own view — and sends it
  with the activation; the server runs the ability authoritatively and may validate or discard that
  data.
- **Well:** exactly this design's division of labour, with the right warning: client-supplied target
  data is the single biggest trust surface an ability system has, accepted only inside bounds the
  server can check **for itself**. **That warning is the whole argument against Candidate A** (5.6):
  a bound the server checks against a number the client also supplied is not a bound.
- **Badly, for us:** a C++ framework with prediction keys, prediction windows and rollback machinery
  we would be inventing a Luau copy of. And "validate" is left to the game.
- **Adopted:** the pattern — **client target data + server validation + a named refusal path** — with
  our own six checks, our own bounds table, and no prediction machinery.

### D. Riot Games — "Peeking into VALORANT's Netcode". **Named, and its conclusion deliberately NOT followed**

- <https://technology.riotgames.com/news/peeking-valorants-netcode>. **Licence:** article, all rights
  reserved; read as prose, nothing copied. **Maintenance:** a dated (2020) article on a maintained
  publication.
- **Well:** the clearest published statement of the opposite policy — a competitive shooter rewinds on
  the **server** with a bounded window and refuses to let the client decide what it hit, because in
  PvP a client-authoritative hit is a cheat that cannot be detected after the fact. It is also good on
  *why* a window must be bounded, and on favour-the-shooter's cost to the victim.
- **Badly, for us, and this is why its conclusion does not transfer:** there is **no victim here**.
  The target is an AI boar, nobody shoots players, a drive is not ranked, and the worst a forged claim
  wins is points in a co-operative hunt. Its cost analysis is about a human being shot behind cover;
  ours is about a wild animal credited to the wrong zone. **v4 pays that cost knowingly and writes the
  size of it in 5.4.**
- **Adopted:** the bounded window and the discipline of counting refusals, from a source that argues
  against the mechanism. Its conclusion is refused with the reason written here, so nobody later cites
  it as though it had been overlooked.

### E. Glenn Fiedler — "What every programmer needs to know about game networking"

- <https://gafferongames.com/post/what_every_programmer_needs_to_know_about_game_networking/>.
  **Licence:** article; the site's sample code is **BSD**, nothing taken. **Maintenance:** a standing
  reference, still maintained and still cited.
- **Well:** the framing in one sentence — the client's view is *authoritative about itself and nothing
  else*, and every networked game must choose which questions it answers from which clock. Also the
  source of *"do not interpolate what you can derive"*, which is why the claim carries an arrival time
  and a flight time and **not** the animal's velocity — **and, in v4, why it does not carry its own
  view lag either** (5.6 B).
- **Badly:** about deterministic lock-step and physics authority in symmetric games; no opinion on
  validating an asymmetric PvE hit claim, no code to borrow.
- **Adopted:** one rule, as this design's own — **the client is believed only about what it SAW, never
  about what that means**.

### F. Roblox engine — the clock, the cast, the remote, the ping

- <https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow>,
  <https://create.roblox.com/docs/reference/engine/classes/Player#GetNetworkPing>,
  <https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams>,
  <https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast>,
  <https://create.roblox.com/docs/reference/engine/classes/RemoteEvent>.
  **Licence:** the documentation source repo <https://github.com/Roblox/creator-docs> is **CC BY 4.0**;
  the engine is proprietary. **Maintenance: actively maintained** with the engine.
- **Well:** `GetServerTimeNow()` is the one clock both sides can name without a protocol of our own,
  and this repo already trusts it across the wire for the drive's countdown
  (`src/client/Match/init.luau` → `Match.secondsLeft`). `FilterType = Include` lets one animal be
  tested in isolation. An **Instance** reference crosses a `RemoteEvent` intact, which is why the
  claim needs no id table.
- **Badly:** the documentation makes **no promise about how tightly `GetServerTimeNow()` agrees**
  between a server and a client, and task 265 could not establish it (`ESCALATE.md`, 2026-10-25: a
  ~0.17 s offset measured, *not established*, because the only control was a motionless part). It also
  says only *"the network ping in seconds"* for `GetNetworkPing` and **does not say whether that is a
  round trip or one way** — which is why `FLIGHT_CATCHUP_PING_FACTOR` exists as a data row, and why
  `Weapon.viewWindowFor` reuses it rather than adding a second one.
- **Adopted:** the clock inside a window, `Include`-filtered casts, Instance references instead of
  ids, attributes as the one description of a target, and the ping as a **clamped** term with a
  documented unit uncertainty.

### H. Gabriel Gambetta — "Fast-Paced Multiplayer, Part IV: Lag Compensation". **NEW in v4**

- <https://www.gabrielgambetta.com/lag-compensation.html> (the series index:
  <https://www.gabrielgambetta.com/client-server-game-architecture.html>). **Licence:** article, all
  rights reserved; the accompanying live demos' source is published separately and **nothing is
  taken**. **Maintenance:** a standing reference, still online, still updated and still the article
  everybody links.
- **Well:** the single clearest statement of the thing v4 turns on — **the server must judge the shot
  against the picture the shooter actually had, and that means reconstructing the world at
  `now − (latency + interpolation)` rather than at `now`.** It is also honest about the consequence in
  one line: the victim gets shot after reaching cover. That is exactly the trade 5.4 enumerates, and
  it is why D's conclusion is refused here rather than ignored — **we have no victim to pay it.**
- **Badly:** hitscan only, no projectiles, no discussion of what a *modified* client gains from the
  window, and no treatment of the case where the client, not the server, computes the hit. The cheat
  analysis in 5.4 is ours.
- **Adopted:** the reconstruction instant itself — *the shooter's own picture, not the present* — and
  the insistence that the amount be derived from measured latency rather than assumed. v4 adds what
  the article does not have: the instant is chosen by the **server's own trajectory** out of the
  **server's own history**, so the client never names it.

### G. Borrowed from inside this repo (rule 2 applies to internal patterns too)

- **The injected provider.** `Weapon.setTargetProvider`, `setStandProvider`, `setDriveOpenProvider`,
  `setSafetyLineProvider`, `setHistoryProvider` — each a `pcall`, each defaulting to the strongest
  answer (for the claim: refuse).
- **The injected cast.** `Weapon.setCast` / `Shotgun.CastFn`; `Claim.simulate` takes the same seam.
- **Pure core, impure owner.** `Pattern`, `Hits`, `SafetyArc`, `StateMachine`, `Validator`, `Limits`
  are pure and take `now` as a parameter. `Validator.pickViewInstant` and `closestOnSegments` follow
  exactly: the owner does the Instance work, the pure half does the arithmetic.
- **A number that can only be read at one value cannot be tested at another.** `Ballistics.dropAt`'s
  `g`, `Weapon.equipDelayFor`, `Validator.checkShot`'s fourth argument, **`Weapon.catchUpFor`'s
  `ping` — which `Weapon.viewWindowFor` copies line for line.**
- **Moving arithmetic out rather than writing it twice.** `Ballistics.segment` left `Flight.advance`
  in task 266 for exactly the reason `closestOnSegments` leaves the owner in task 271.
- **The worst-case counter as the argument for a bound.** `stats.originFarthest` /
  `originRefusedFarthest` (task 260) → `claimWorstStuds`, `claimWorstLineStuds`,
  **`claimWorstLagSeconds`**.
- **A mechanism that loosens a rule and moves no number is deleted** — task 269b's backward search.
  §1.2a item 15 binds v4 to the same test in advance.
- **One cross-module invariant, asserted.** `tests/server/zz_horn.spec.luau` holds three modules to
  one `METRES_PER_STUD`; `zz_claim_window.spec` holds the weapon's window inside the animal's memory.

### The pattern adopted

**Client-simulated projectile with a server-validated hit claim, judged against the server's own
rewind at a VIEW INSTANT the server chooses from its own history inside a latency-clamped window** —
Epic's target-data division (C), Valve's and Gambetta's lag-compensation window reduced to one
`CFrame` per animal and judged by arithmetic (B, H), FastCast's segment cast as the one stepper both
sides share (A), the engine's clock and ping used only inside clamps (F), and VALORANT's contrary
conclusion (D) named and refused for a stated reason — **with the flight time, the drag, the drop, the
zero and the pattern untouched, so the lead this whole system exists to create is preserved.**

---

## 11. Numeric targets

| Target | How it is measured |
|---|---|
| **THE CORE: ≥ 4 of 5 led shots at a staged running deer are ACCEPTED claims naming the chest**, with the mark on the chest and an inspected frame | the request's own instrument: five led shots in the Forest Test with `HIT_CLAIM` on, `DHClaimStats` read live. This is the acceptance five tasks have failed |
| **`claimWorstLagSeconds` lands in 0.10–0.30 s on a loopback session** | the brief measured 0.178 s of view lag once, as a refusal. If the sweep reports **under 0.02 s**, the mechanism carried nothing and §1.2a item 15 says delete it. If it reports **at or above `window`** with `claimLagAtEdge > 0`, `VIEW_LAG_BASE_SECONDS` is too small |
| **`claimWorstLineStuds` falls from 5.46 to under 1.0 stud** | the decomposition says the across-path residual is 0.38 studs plus up to 0.63 of grid. Anything near 2.0 means the tolerance is doing work it should not have to (§15 item 3) |
| **`claimWorstStuds` falls from ~5.12 to under 1.0 stud** | check 3 is now evaluated at the view instant. **This is the measurement that makes `POSITION_TOLERANCE_STUDS` 6.0 → 2.0 arguable**, §16 Director 1 |
| **a STILL animal, 3 chest shots: chest hits, dust on the chest** | reads `SKIN_STUDS`, `LINE_TOLERANCE_STUDS`, `POSITION_TOLERANCE_STUDS`. The window contributes nothing at v = 0, which is itself the check |
| **a FORGED claim, an animal 30 studs from where it was → REFUSED** at every instant in the window | 30 studs against `POSITION_TOLERANCE_STUDS = 6.0` is a factor of 5, and `v · 0.45 = 17.1` studs of path still leaves it outside |
| **non-regression: `VIEW_LAG_BASE_SECONDS = VIEW_LAG_MAX_SECONDS = 0` reproduces v3 exactly** | one candidate, the identical `serverPoint`, the identical `judgeClaim` call, identical impacts. 12.1 case 32 |
| **the sweep's cost on the server: 0 new raycasts** | grep: `Workspace:Raycast` appears once under `src/server/Weapon/` (`Cast.luau`) |
| **the sweep's cost: ≤ 28 provider calls, ≤ 16 `Ballistics.advance` calls, ≤ 448 point-to-segment projections, and ONE ≤16-entry table, per CLAIMED shot** | `MAX_SUBSTEPS` × `VIEW_LAG_MAX_SAMPLES`. Single-pellet only, at most 6/s, so ≤ 2688 projections/s worst case: float arithmetic, no allocation in the inner loop. `weapon_hits.spec` counts the injected provider's calls and asserts the bound |
| **`Runtime:stats().historyMisses` rises by at most 1 per claimed shot** | the break rule (4.9). Asserted in 12.1 case 34 |
| **history memory: ≤ 96 CFrames per animal, preallocated, 0 allocations per step after the first ring fill** | `Runtime:stats().historySamples`; a pure spec fills a ring 10 000 times and asserts the length never exceeds `SAMPLES` |
| **history cost ≤ 0.03 ms per step for 24 animals** | one table-field write per animal in a loop that already writes a `snapshot` entry per animal; a wall clock around `Runtime:step` in a Forest Test run |
| the flight time, the drop, the zero, the pattern, `GRAVITY_SCALE` | **unchanged**; `ballistics.spec` cases 1–9 untouched |
| `Hits.group` is the only `HitReport` constructor; one per (shot, target); `pellets` counted | grep plus `weapon_hits.spec` cases 3 and 4, unchanged |
| **0 new remotes, 0 new rate-limited doors, 0 new payload fields, 0 new flags** | grep on `Shotgun.remotes` (six), on the `HitClaim` type's six fields, and on `Flags.MAX_FLAGS` (unchanged) |
| **the OFF state is bit-for-bit today's game** | `HIT_CLAIM = false` → `claimsIgnored` rises and nothing else moves |

---

## 12. How it is tested

### 12.1 `tests/server/weapon_hits.spec.luau` — pure, over the injected cast, provider and `dt`

Cases 1–29 stay as they are, **including case 24's twelve `judgeClaim` boundary assertions, which
must not need editing** — that is the proof that `judgeClaim` did not change. Added:

30. **`Validator.pickViewInstant`, every rule, on both sides.** Hand-written candidates and segments,
    no world:
    - the newest candidate wins when it is also the closest;
    - an **older** candidate wins when the trajectory passes nearer to it — the whole point;
    - a candidate that fails check 3 is **not** chosen even when it minimises check 4
      (the circling-animal case);
    - when **no** candidate passes check 3, the one with the smallest `movedStuds` is returned with
      `anyPassedCheck3 = false`, so `judgeClaim` names `claim-moved` with the best number;
    - an empty list returns `nil` and does not error.
31. **STRICT SUPERSET, asserted and not hoped**: for 200 randomised candidate sets that include
    `arrivalAt` as candidate 1, anything v3's single-instant rule accepted, `pickViewInstant` +
    `judgeClaim` also accepts.
32. **NON-REGRESSION BY PARAMETER**: with `VIEW_LAG_BASE_SECONDS = VIEW_LAG_MAX_SECONDS = 0`, the
    whole claim path produces **byte-identical** impacts, reasons, measured values and budgets to the
    same inputs through v3's single-instant code.
33. **THE WINDOW RUNS BACKWARD ONLY**: a claim whose `firedAtView` is ahead of the server clock is
    refused `claim-future` with the window at its full 0.45 — the sweep cannot rescue it.
34. **THE SWEEP'S HOUSEKEEPING**: a provider that answers nil for the first candidate and a CFrame
    for the second does **not** end the sweep; a provider that answers nil after a CFrame **does**;
    `claimHistoryWhy` is written **only** when every candidate answered nil; the provider is called at
    most `VIEW_LAG_MAX_SAMPLES` times.
35. **`Validator.closestOnSegments` reproduces today's inline loop exactly**: 2 000 random
    (polyline, point) pairs against the expression lifted from `src/server/Weapon/init.luau`, equal to
    1e-9. The MOVE's regression proof, the same discipline `Ballistics.segment` got in task 266.
36. **`Weapon.viewWindowFor`**: `nil`, negative, NaN and absent pings all contribute zero; a 0.08 s
    ping gives `BASE + 0.08`; a 1.0 s ping clamps at `VIEW_LAG_MAX_SECONDS`; the result is never
    negative and never above the cap.
37. **THE MEASURED CASE, REPRODUCED PURELY**: a target crossing at 28.7 studs/s, a history that places
    it 5.106 studs back at `arrivalAt − 0.178`, a trajectory through that older point. v3's rule gives
    `claim-line 5.46/2.00`; v4's **accepts**, with `lineStuds < 1.0` and `lineLagSeconds` within one
    grid step of 0.178. **This is the brief's measurement turned into a spec, so the fix cannot
    silently stop working.**

### 12.2 `tests/server/boar_history.spec.luau` — pure, no world, no clock

Unchanged in substance; the ring-length assertions read `HISTORY.SAMPLES` rather than a literal, so
64 → 96 needs no edit. If any literal 64 is present, it is replaced by the config read — a literal
there is itself a defect.

1. `Boar.sampleAt` interpolates between bracketing samples and is exact at a sample.
2. It **refuses** outside the span, before the oldest and after the newest, and never extrapolates.
3. The ring wraps and never grows past `HISTORY.SAMPLES`; 10 000 writes leave `SAMPLES` entries.
4. The rewound part CFrame = the trunk's rewound CFrame times the part's constant trunk-space offset.
5. A down, dead or unknown animal answers nil, and so does an unknown Instance.
6. **NEW: the ring spans `AGE_MAX_SECONDS + VIEW_LAG_MAX_SECONDS` of samples at 60 Hz** — the
   consumer-side half of 3.3, so a future `SAMPLES` cut fails here as well as in `zz_claim_window`.

### 12.3 `tests/server/zz_claim_window.spec.luau` — the cross-system invariant, widened

- `HISTORY.SAMPLES / 60 >= CLAIM.AGE_MAX_SECONDS + CLAIM.VIEW_LAG_MAX_SECONDS + 1/60`, **and the
  existing `span / window >= 1.5` margin** (which is what forces 96, 3.3);
- `CLAIM.VIEW_LAG_MAX_SAMPLES >= CLAIM.VIEW_LAG_MAX_SECONDS / CLAIM.VIEW_LAG_STEP_SECONDS + 1` — the
  cap can never silently truncate the window;
- `CLAIM.VIEW_LAG_BASE_SECONDS <= CLAIM.VIEW_LAG_MAX_SECONDS`;
- `CLAIM.VIEW_LAG_STEP_SECONDS <= 1/60` — the grid is never coarser than the ring;
- unchanged: `LINE_TOLERANCE_STUDS < BODY_SIZE.Z/2`, `POSITION_TOLERANCE_STUDS` within
  `[BODY_SIZE.Z, 2·BODY_SIZE.Z]`, the reach-versus-longest-flight case.

### 12.4 `tests/server/ballistics.spec.luau` — unchanged by v4

Cases 1–9 and the task-266 `Ballistics.segment` cases stay as they are. v4 touches no function here.

### 12.5 `tests/server/weapon_shot.spec.luau` — the LIVE cases, on the player's path

- The sight-line case and the task-266 forged-claim case are **unchanged**, including the drain of
  `Weapon.flightCount()`.
- **NEW, the live accepted-at-lag case**: with `Weapon.setClaimPolicy(true)`, a scripted cast, and a
  history provider that returns a part moving at 30 studs/s, a hand-built claim whose point is where
  that part was **0.18 s before the claimed arrival** → the shot is taken, `stats.claimsAccepted`
  moves by one, `HitReported` fires once with the claimed part, and `claimWorstLagSeconds` is within
  one grid step of 0.18.
- **NEW, the live non-regression case**: the same claim with the window parameterised to 0 →
  refused `claim-line`, the impacts identical to the same shot with no claim at all. **The two cases
  together are the whole of v4, through the real handler, with no world and no second player.**
- **NEW, the live forged-at-every-instant case**: a claim 30 studs off is refused `claim-moved` at the
  full 0.45 window, and the margin is asserted as a ratio over the tolerance so it cannot pass by the
  tolerance being widened.
- The OFF-state case is unchanged.

### 12.6 `tests/client/weapon_client.spec.luau` — unchanged mechanism, one added case

- `Claim.simulate` over an injected cast and a scripted world: aiming **AHEAD** by
  `Ballistics.leadStuds` produces a chest claim; a **static obstruction** gives nil; the cast count is
  under the `MAX_TARGETS × MAX_SUBSTEPS` bound; the two-pass lead table of 4.7 holds at 40, 100, 150
  and 200 studs.
- **NEW, section 1.4's crossover, driven rather than asserted in prose**: with a 7.05-stud box
  crossing at 28.7 studs/s, aiming **AT** the chest produces a claim at 60 and 120 studs (naming a
  point behind the aim point by `v · t`) and produces **nil** at 250. The range at which it flips is
  **reported by the spec**, not hard-coded, so the number in 1.4's table is a measurement rather than
  my arithmetic.
- `Input.fire` sends the claim only when the policy is on.
- The grep claims: `Workspace:Raycast` under `src/client/Weapon/` appears only in `Claim.luau`.

### 12.7 `tests/client/shoot_boar.spec.luau` — unchanged

It already leads with `Ballistics.timeToRange` through the camera owner's `LookAtRequest` — the
end-to-end proof on the player's path, and the one case that proves the lead still has to be held.

### 12.8 Harness input, screenshots, and what cannot be tested

- **Harness input** (`tests/client/input_scenarios.txt`) can replay the click and stage the character.
  It **cannot** aim at a moving animal on a schedule and cannot express "lead this target by this
  much" (`tools/studio_mcp.py` docstring; TASKS.md Tasks 6–7), so the lead is computed **in the
  spec**. **No new harness capability is needed and none is claimed.**
- **The harness cannot produce latency or clock skew.** A loopback Studio session reads 1–2 ms of ping
  (measured, task 256 round 2), so the *magnitude* of the view lag cannot be exercised by the gate at
  all — only by Karen's own session, which is where the 0.178 s came from. Everything about the
  mechanism is proved by **injected** times, pings and positions in the pure specs, and only *bounded*
  in the live ones. **This is the single biggest limitation of this design's evidence and it is why
  §11's first row is a Director acceptance run and not a spec.**
- **Screenshot (rule 5): required.** One capture of a slug hit on a running deer with the override on,
  inspected, showing the dust **on the chest** rather than behind it. A screenshot **cannot** show a
  0.178 s view lag, and this design does not pretend otherwise.
- **What cannot be tested at all, said plainly:** whether the shot now *feels* right, and whether
  `GetServerTimeNow()` is tight between a real client and a real server. Both are §15.

---

## 13. The harness tables, and the gate

### 13.1 `tools/studio_mcp.py` — **no change**

`BLAST_RADIUS` already maps every file v4 touches: `src/shared/Shotgun/` → `gun`,
`src/server/Weapon` → `weapon`, `src/server/Boar` → `boar`. `SCOPE_SPECS` already holds
`boar_history.spec` (`boar`) and `zz_claim_window.spec` (`weapon` and `boar`). **No new spec file, so
no new row, and `selftest` cannot fail on this task.**

### 13.2 Which gate this task needs — **`test2` is NOT required, and that is a change from v3**

v3 needed `test2` because task 266 edited `src/server/MatchBoot.server.luau`, which is in
`TWO_PLAYER_PATHS`. **v4 edits no composition root** — the history provider is already wired. The
files are `src/shared/Shotgun/init.luau`, `src/server/Weapon/{init,Validator}.luau`,
`src/server/Boar/init.luau` and their specs, and **not one of them is in `TWO_PLAYER_PATHS`**
(`tools/agents.py`; CLAUDE.md, "Run / test": *weapon, viewmodel, camera, boar, hud, sound and tools
need the one-player line only, for the PR to `main` as well*).

```
[harness] PASS: n/n checks @ <code commit> (clean tree) scope=all      <- the PR to main
```

A review round may use `scope=auto:gun,weapon,boar`. **The Builder must not paste a `[harness2]` line
and must mark that box N/A with this reason.** A second player answers exactly one class of question —
who the OTHER player is — and nothing in v4 asks it.

### 13.3 Build order — three commits, each green on its own

CLAUDE.md rule 4 is one task per round. v4 splits, and **every step before the last is invisible with
the flag off**:

1. **The MOVE and the rows.** `Validator.closestOnSegments` (lifted out of
   `src/server/Weapon/init.luau`, the owner calling it with a one-segment-at-a-time list so the result
   is identical), the four `CONFIG.CLAIM` rows, `Boar.CONFIG.HISTORY.SAMPLES` 64 → 96,
   `zz_claim_window.spec`'s widened invariant, `weapon_hits.spec` case 35. **No behaviour change at
   all.**
2. **`Validator.pickViewInstant` and `Weapon.viewWindowFor`**, with cases 30, 31, 36 — **pure, and
   nothing calls `pickViewInstant` yet.**
3. **The sweep in the owner**: the candidate loop, the break rule, `claimHistoryWhy`'s new publication
   point, the three stats fields, the refusal note's `lag`/`atEdge` pair, and cases 32, 33, 34, 37 plus
   the three live cases in 12.5 and the client crossover case in 12.6. Then the Director's acceptance
   run with the override on, then Karen.

Step 1 touches `src/server/Boar/init.luau` and step 3 does not, so the two scopes differ; both resolve
inside `gun`, `weapon` and `boar`.

---

## 14. The delta to `docs/design/shotgun.md` and `GAME_DESIGN.md`

| `shotgun.md` | What v4 changes on top of v3's delta |
|---|---|
| **§3.1 The one server owner** | add: `Weapon.Validator` gains `closestOnSegments` and `pickViewInstant`, both **moved**, both pure, and is **still the one place a payload is judged**. `Weapon` gains `viewWindowFor` — a latency read in the `catchUpFor` shape, not a new owner. **No new provider** (`setHistoryProvider` already exists) |
| **§5.1 Shared types** | **no change.** `HitClaim` keeps its six fields |
| **§5.3 The pure core** | `judgeClaim` is unchanged; the two new helpers follow the same division — **the pure half judges the numbers, the owner does the Instance reads** |
| **§5.5 The shot, step by step** | step 7 gains the sweep before the verdict. The order is otherwise unchanged |
| **§5.7 "The client never names a target, and never casts"** | already REVERSED in v3. v4 adds one sentence: **the server now also chooses WHICH MOMENT it judges against, from its own history, inside a window clamped by the shooter's own measured latency** — and the enumerated cost of that is §5.4, including the two things it hands a modified client (free zone selection on an animal it engaged, and free no-lead inside `v · window`) |
| **§11 Numeric targets — the one config table** | `CONFIG.CLAIM` gains four `VIEW_LAG_*` rows. **No existing number moves** |
| **§11.1 Lag** | item (4) now reads: *the claim and the rewind, bounded, tasks 266 and 271 — judged at a view instant the server chooses inside a latency-clamped window.* The task-256 forward prediction is **not** replaced: the catch-up removes ping from the *server's own* flight for an unclaimed shot; the claim removes the view error for a claimed one. **Their interaction is a named open risk** (5.7) |
| **§13.1 / §13.2 specs** | the cases in 12.1, 12.3, 12.5 and 12.6 |
| **§15 Open decisions** | gains section 16 below |

**`GAME_DESIGN.md` rows:**

- **"Where an animal WAS" (task 266), amended**: *a ring of `Boar.CONFIG.HISTORY.SAMPLES` (**96**,
  1.6 s at 60 Hz) trunk CFrames per animal, written in `Runtime:step` and read only by
  `Runtime:cframeAt`. The weapon is handed an answer per instant it asks about, never the buffer.
  `Boar.Body` is still the one writer of where an animal IS. Design `docs/design/ballistics.md`
  §§1.3, 4.6, 4.9.*
- **the weapon row (41), amended**: *"…and `ServerScriptService.Weapon` validates it against the
  Boar's position history with six checks before it becomes the shot's one impact. **Since task 271
  the geometric checks are evaluated at a VIEW INSTANT the server picks from its own history, inside a
  window clamped by the shooter's own measured latency (`Weapon.viewWindowFor`), because the picture
  the shooter aimed at is older than the server's present — measured at 0.178 s.** A refused claim is
  logged and the shot resolves from the server's own flight. Buckshot carries no claim. Behind
  `HIT_CLAIM`, born off."*
- **the shotgun-numbers row (44), amended**: `Shotgun.CONFIG.CLAIM` also carries the four `VIEW_LAG_*`
  rows; still six RemoteEvents.
- **the "client's claim" row (task 266)**: unchanged.

---

## 15. What I could not verify (rule 8)

1. **THE SHARED CLOCK, first and loudest.** I cannot establish how tightly
   `Workspace:GetServerTimeNow()` agrees between a client and a server. Task 265 measured a ~0.17 s
   client/server position offset and **could not establish it** — the only control was a motionless
   part, which reads 0.000 under any clock skew (`ESCALATE.md`, 2026-10-25). **v4 makes this matter
   MORE, not less**, and that must be said: if some of the 0.178 s is clock skew rather than view lag,
   the sweep is compensating for a clock error by looking at an older picture, which is wrong in
   principle and right in effect. **`claimWorstLagSeconds` cannot tell the two apart.** The experiment
   that could is a client and a server reporting `GetServerTimeNow()` for the same `Heartbeat`, and
   nobody has run it. It is §16 Director 4.
2. **Roblox Studio is not available to this run** (`.agent-evidence/INDEX.md`). **No number in this
   file was measured by me.** 0.178 s, 28.7 studs/s, 5.106/5.120 and 5.457/2.000 are all read off
   `reviews/task-271/BRIEF.md`'s quoted `DHClaimStats` line; 1.7 ms of ping is task 256 round 2;
   2.137/1.000 is task 269b. Every `VIEW_LAG_*` value is a derivation from those, written as **a bound
   to be measured**, not as a result.
3. **I derived the across-path residual (0.38 studs) from a single refusal.** `sqrt(5.120² − 5.106²)`
   is arithmetic on two numbers from one shot. **One shot is not a distribution.** If the residual is
   routinely larger than that — a turning animal, a mis-set `BORE_ON_SIGHT_LINE`, a zone box that does
   not follow the drawn mesh (item 5) — `LINE_TOLERANCE_STUDS = 2.0` will still refuse, and the
   refusal will now say `atEdge=false`, which is the reading that sends this back to the geometry.
4. **The grid's quantisation bound is arithmetic, not a measurement.** `v · VIEW_LAG_STEP_SECONDS` is
   0.63 studs at 38 studs/s, and I argued it is conservative because a sampled minimum is never below
   the true minimum. That is true of the *minimum*; it is not a proof that the chosen *instant* is the
   one a finer grid would choose. Case 30 drives the rule; nothing drives the grid's fineness against
   a continuous ground truth.
5. **Whether the client's view of a `LinearVelocity`-driven trunk and its welded zone parts is
   coherent sub-frame.** The weld makes the offset constant *by construction* (`Body.buildZones`), but
   I have not seen it on screen, and with `BOAR_MODEL` on the drawn mesh is a separate non-queryable
   child whose animation does **not** move the zone boxes — so the client aims at a box that may be a
   few centimetres from the limb it is drawn over. That is today's game and not this task's, but a
   claim makes it *the thing being claimed*.
6. **Task 265's unexplained 3-stud rump hit is NOT explained by this design and is not claimed to
   be.** A chest-aimed shot on a moving hind landed at trunk z +2.915 against a chest spanning
   −1.625..−0.086. **v4 makes it easier to hide than v3 did**, because the view instant absorbs
   along-the-body error that v3 would have refused. `claimWorstLineStuds` is still the number that
   would show it, and it is now a weaker detector. §16 Director 5.
7. **`Weapon.viewWindowFor`'s ping term is untested against a real connection** and reuses a factor
   whose units the engine does not document (`FLIGHT_CATCHUP_PING_FACTOR`, *"the network ping in
   seconds"*, round trip or one way unknown). On a loopback session the term contributes 1.7 ms and
   the base does everything, so **the gate cannot distinguish a correct ping term from a dead one.**
   `claimViewWindowMax` is the only thing that will.
8. **I did not re-read `Flight.advance`, `Hits.group` or `Runtime:step` line by line in this run.** I
   read `Validator.judgeClaim`, the claim path in `src/server/Weapon/init.luau`, `Claim.luau` in full,
   `Shotgun.CONFIG.CLAIM` and `zz_claim_window.spec`'s assertions. Statements about the other three
   are carried from v3 and from their symbol names, not re-verified.

---

## 16. Open decisions

### For Karen — feel. **None blocks building.**

1. **Does the shot now land where she aimed?** The question this task exists for, on its sixth
   attempt. `python tools/flags.py set HIT_CLAIM on`, play, then read `Weapon.stats()`:
   `claimsAccepted` against `claimsRefused`, `refusedClaimBy`, and **`claimWorstLagSeconds`**.
   *"It still feels behind"* and *"sometimes it does not register"* are **different** answers with
   different dials: the first is `LINE_TOLERANCE_STUDS` or the client's own simulation, the second is
   the window (`claimLagAtEdge > 0`) or the clock.
2. **Does free zone selection matter to her?** 5.4 says a modified client can claim any zone of an
   animal it genuinely shot at. The game is co-operative PvE and this design treats that as acceptable
   (source D). **It is her game.** If she wants it closed, the answer is a smaller window, which costs
   honest high-ping players hits — the trade, not a bug.
3. **Close shots on fast animals, and buckshot**, both unchanged from v3. If buckshot specifically
   feels off on running animals, the honest knob is `DRAG_PER_STUD.Buck`, **not** nine claimed pellets.

### For the Director — scope. **None blocks building.**

1. **`POSITION_TOLERANCE_STUDS` 6.0 → 2.0, after the acceptance run.** v4 predicts `claimWorstStuds`
   collapses from ~5.12 to under 1.0 because check 3 is now evaluated at the right instant. If it
   does, 6.0 is ten times looser than it needs to be and tightening it **removes most of what
   Candidate A would have given away**, making the whole system tighter than v3. Argued from the
   measurement, exactly as `CAMERA_ORIGIN_TOLERANCE` was argued from `originFarthest`. **A separate
   task; this design does not take it**, because the brief says no tolerance change.
2. **`VIEW_LAG_BASE_SECONDS = 0.30` is the one invented number in v4.** It is the measured 0.178 s with
   1.7× margin. Lower refuses honest shots on a slow frame; higher hands a modified client more
   no-lead. Argue it down from `claimWorstLagSeconds` after one real session.
3. **The next tightening available, named and not built:** a **per-player** window, clamped to that
   player's own recent median `lineLagSeconds` plus slack, instead of one constant for everybody. It
   would make a low-ping cheater's licence smaller than a high-ping honest player's, which is the
   correct shape. It needs per-player state in the weapon, which this task declines to add.
4. **The clock experiment** (§15 item 1). A client and a server reporting `GetServerTimeNow()` for the
   same `Heartbeat` would say how much of the 0.178 s is view lag and how much is skew. Until it is
   run, v4 compensates for both with one number. Worth a task of its own; **it does not block this
   one**, because the sweep is right for view lag and harmless for skew.
5. **Task 265's unexplained 3-stud rump hit is now harder to find, not easier** (§15 item 6). If the
   Director wants it closed first, this task waits behind it. My reading: it should not — five tasks
   have failed to land one accepted claim, and the instrument that would find the rump hit
   (`claimWorstLineStuds`) is only readable once claims are *accepted*.
6. **`claim-future` on a real connection** (5.7). The condition and the one-line fix are written down.
   It is a task when `claimAgeMin` goes negative, not before.
7. **When to flip `HIT_CLAIM`'s default.** Born off, `expires = "2026-11-15"`, three weeks after
   2026-10-25. **Today is 2026-10-26 and v4 does not move the date.** Karen's OK is the three-line
   commit; a refusal retires the row and archives the claim path under `backups/` (rule 7).
8. **`Match.CONFIG.SAFETY_RANGE_STUDS` is still 330 while the rifle reaches 800** (TASKS.md 183a, still
   open). Untouched again, for the same reason: `src/server/Match/` is a `TWO_PLAYER_PATH`.

# Design: ballistics — one rule set an honest claim passes by construction

**v5, Task 277 (2026-10-26).** Written to `reviews/task-277/BRIEF.md`, which **overrides** anything
older in `docs/`, `TASKS.md` and v4 of this file. Direction **A** (claim validation) and the half of
direction **C** this document is accountable for. Direction **B** is `docs/design/hit-zones.md`,
written by run 2 of the same task.

**RULE 7. v4 of this file is not deleted — the Architect script replaces it in place.** The Builder
must recover it into `backups/design-ballistics-v4.md` with a one-line note
(`git show a3b6663e:docs/design/ballistics.md`), in the same commit as the first code change of the
build task. I cannot write files. v3 is already archived at `backups/design-ballistics-v3.md`.

Karen, the key of the game, verbatim:

> *"all shooting has to be like in real life"* · *"when boar is running we need to aim in empty space
> to get hit in head neck or heart like in real life smae with other animals"* · *"I need quality
> results"*

---

## 0. What v5 changes, in one page

v4's mechanism is kept — the client simulates its own shot, the server validates the claim against
its own history inside a latency-clamped window. **What changes is the rule set.** Tasks 269b–276
iterated the checks one at a time without converging; this rewrites them as a set, each check with
the cheat behind it and the honest worst case it must pass.

| # | What | Where |
|---|---|---|
| 1 | **Old check 4 (`claim-line`) is DELETED.** It measured `(trajectoryPoint − serverPoint).Magnitude` — the SERVER's own re-step against the SERVER's own rewind. Neither operand is the claim. It is the quantity that read 4.09 of 2.00 on honest chest claims and refused 2 of 2 in task 276 | 5.2, **5.4** |
| 2 | **A new check 4, "the claim's own line":** the claimed point lies on the claim's OWN ballistic path, at the claimed distance along it. An honest client satisfies it to float, by construction (4.4) | 3.1, 5.2 |
| 3 | **Check 5 becomes direction A's existential:** the claimed target was within a **body-sized** tolerance of the claimed point at SOME instant in the window. It replaces `POSITION_TOLERANCE_STUDS = 6.0` with a per-kind number derived from the trunk the zones actually have (2.00–3.71 studs) | 3.1, 3.2, 5.2 |
| 4 | **Check 6 becomes an explicit line-of-sight CAST**, muzzle to the chosen instant's point, through the existing `castFn` seam. The reach arithmetic and the whole self-block waiver (`stoppedByClaimedTarget`, `span + REACH_SLACK_STUDS + displacementStuds`) are **deleted**: 273a(b) 4.105/3.40 and 274a(b) 7.275/3.40 are resolved by deletion, not by a bigger bound | 5.2, 5.6 |
| 5 | **ONE CLOCK.** Exactly two checks have an instant (5 and 6) and they share `t*`, chosen once by `Validator.nearestInstant`. Checks 3, 4 and 7 have no instant at all | 4.3, 4.9, 5.3 |
| 6 | `Shotgun.CONFIG.CLAIM` loses `LINE_TOLERANCE_STUDS`, `POSITION_TOLERANCE_STUDS` and `REACH_SLACK_STUDS`; gains `CLAIM_LINE_STUDS`, `CLAIM_PATH_TOLERANCE_STUDS`, `BODY_TOLERANCE_FACTOR`, `BODY_TOLERANCE_MIN_STUDS`, `LOS_SLACK_STUDS`. The four `VIEW_LAG_*` rows are unchanged | 3.1 |
| 7 | **`static-blocked` is a wrong word and the conclusion drawn from it does not follow.** `Claim.simulate` returns it whenever NO target was struck in the sub-step and anything static was — which includes a plain miss. Task 275's *"the client's own line of sight closed on grass or a trunk"* is one of three readings of that string (5.7) | 5.7, 12.6 |
| 8 | **The shooter's lead is NOT applied twice**, and 275's suspicion is refused with the arithmetic. The compensation to remove is the view lag (`v × 0.19 s`, 5.4–7.2 studs), which is 5× the lead in dispute (`v × flight`, 0.79–2.47 studs at 20–60 m) | 5.5 |
| 9 | The carried items of the 265–276 run are each placed or explicitly deferred, by name | 16 |

**Unchanged and not up for discussion here:** the flight times, the drag, the drop, the zero, the
pattern, `GRAVITY_SCALE`, `Ballistics` in its entirety, `Flight`, `Hits.group` as the one
`HitReport` constructor, the six remotes, the `HitClaim` payload's six fields, and the
`HIT_CLAIM` flag.

---

## 1. What the system must do, and must not do

### 1.1 Must do

1. A shot takes time to arrive; the time is per weapon per ammo; a target that moved out of the path
   is not hit and one that moved into it is; gravity drop as data; a still target is hit by
   construction; only the hit and the dust wait for the bullet; a hit's `distance` is measured from
   the bore; cheap and leak-proof. (v2 §1.1 items 1–9, word for word.)
2. **A shot hits what the shooter saw.** The shot is simulated on the shooter's own client against
   his own view over the real flight time; the client sends a hit claim; the server validates it
   against its own position history. The one thing the client is believed about is **which animal it
   saw, and where**.
3. **The lead stays; the view error goes** (5.5).
4. **A refused claim costs the player nothing he had before** — the shot still resolves from the
   server's own flight (5.8).
5. **NEW, and this is the whole of v5: an honest claim passes BY CONSTRUCTION.** Every check is
   either something an honest client satisfies to floating point (checks 3, 4, 7) or something the
   SERVER's own record satisfies with a budget derived from the animal's own measured body (checks
   5, 6). **A check whose honest worst case is a number nobody has measured is a check that will
   refuse honest claims**, and that is how nine tasks were spent.
6. **NEW: every check names the cheat it stops.** A check with no cheat behind it is deleted here,
   not kept "for safety" (direction A).

### 1.2 Must not

- **No second writer of hits.** `ServerScriptService.Weapon` owns whether a shot happened and what
  it hit; `Hits.group` is the ONE constructor of a `HitReport`, one per (shot, target).
- **No per-animal position store under `src/server/Weapon/`.** The weapon asks
  `historyProvider(part, t)` and keeps nothing past one `judgeClaimFor` call. `ServerScriptService.Boar`
  is the one store and the one reader of the ring (`Runtime:step` writes, `Runtime:cframeAt` reads).
- **No rewound-world raycast.** The LOS cast added by v5 is against the **present** world and is
  valid for a past instant only because everything it may hit is `Anchored` (5.6). It goes through
  the **existing** `castFn` seam, so `Workspace:Raycast` still appears once under
  `src/server/Weapon/` (`Cast.luau`).
- **No Instance per projectile. No client-side copy of the ballistic arithmetic. No second id
  table** — the claim names an Instance. **No vendored FastCast, no `.rbxm`.**
- **The client never names a zone, a damage number or a target root.** It names a **part**; the zone
  is that part's own `HitZone`, read on the server by `Hits.targetOf`.
- **NEW: the weapon never learns what a boar is.** The LOS cast's exclude list is `shot.ignore`
  (built at the trigger by `ignoreFor(player)`) plus the one `target` that `Hits.targetOf` already
  returned. **No `Workspace.Boars` lookup, no folder name, no eighth provider.**
- **No second clock, no second latency estimate, no new remote, no new payload field, no new flag.**

---

## 2. Owners — one writer each, named

| Thing | The one writer | On disk | v5? |
|---|---|---|---|
| The ballistics maths (flight time, remaining speed, drop, elevation, the bore, one sub-step) | `ReplicatedStorage.Ballistics` — frozen numbers, pure functions, no state, no clock, no service | `src/shared/Ballistics/init.luau` | **untouched** |
| The protocol's numbers (`CONFIG.CLAIM`) | `ReplicatedStorage.Shotgun` — deep-frozen, no writer at run time | `src/shared/Shotgun/init.luau` | **five rows in, three out (3.1)** |
| The live projectiles on the server | `ServerScriptService.Weapon.Flight` | `src/server/Weapon/Flight.luau` | **untouched** |
| The clock that advances them, every signal, remote, counter and report, the latency measurement, the LOS cast, **and whether a claim is accepted** | `ServerScriptService.Weapon` | `src/server/Weapon/init.luau` | **`judgeClaimFor` rewritten** |
| The verdict on one payload — pure, no Instance, no service, no clock | `ServerScriptService.Weapon.Validator` | `src/server/Weapon/Validator.luau` | **`judgeClaim` rewritten; `pickViewInstant` → `nearestInstant`** |
| The one caller of `Workspace:Raycast` under `src/server/Weapon/` | `ServerScriptService.Weapon.Cast` | `src/server/Weapon/Cast.luau` | **untouched** (the LOS cast goes through `castFn`) |
| Where an animal IS | `ServerScriptService.Boar` → `Boar.Body` | `src/server/Boar/Body.luau` | **untouched** |
| Where an animal WAS (the ring, the sampling, the lookup, the rewound part CFrame) | `ServerScriptService.Boar` → `Runtime:step` writes, `Runtime:cframeAt` reads | `src/server/Boar/init.luau` | **untouched** |
| The hit ZONES on an animal, and what `HitZone` means | `ServerScriptService.Boar` → `Boar.Body.buildZones` | `src/server/Boar/Body.luau` | **`docs/design/hit-zones.md` owns it, not this file** |
| The client's own simulation of its own shot, and the claim it produces | `PlayerScripts.Weapon.Claim` | `src/client/Weapon/Claim.luau` | **the no-claim reason strings (5.7); the coarse pass's first guess (16.2)** |
| The one firer of `FireRequest` | `PlayerScripts.Weapon.Input` | `src/client/Weapon/Input.luau` | **untouched** |
| **The drawn dust and where it sits on the animal** | `PlayerScripts.Weapon.Effects` → `puff` | `src/client/Weapon/Effects.luau` | **NOT this task (16.6). It is a drawing defect, not a validation one** |
| The `HIT_CLAIM` flag's declaration | nobody at run time; frozen data | `src/shared/Flags/init.luau` | **untouched** |

### 2.1 Files on disk — v5's diff

```
src/shared/Shotgun/init.luau      -> ReplicatedStorage.Shotgun   (CONFIG.CLAIM: +5 rows, -3 rows)
src/server/Weapon/Validator.luau  -> ...Weapon.Validator         (judgeClaim rewritten; pickViewInstant
                                                                  -> nearestInstant; closestOnSegments
                                                                  and claimImpact unchanged)
src/server/Weapon/init.luau       -> ServerScriptService.Weapon  (judgeClaimFor rewritten: the claim's
                                                                  own path, the existential, the LOS
                                                                  cast; the stats rename; the dead
                                                                  `reason == "moved"` fixed)
src/client/Weapon/Claim.luau      -> PlayerScripts.Weapon.Claim  (the no-claim reason split, 5.7;
                                                                  the coarse pass's midpoint guess)
tests/server/weapon_hits.spec.luau      (every check, both sides, pure)
tests/server/weapon_shot.spec.luau      (the live accept, the live refuse, the forged cases)
tests/server/zz_claim_window.spec.luau  (the cross-owner invariant, re-derived against the new names)
tests/client/weapon_client.spec.luau    (direction C4: the lead is the flight time and nothing else)
```

**Nothing under `src/server/Match/`, `src/server/Boar/`, `src/server/MatchBoot.server.luau`,
`src/client/Match/` or `src/shared/Drive/` is touched.** None of the files above is in
`TWO_PLAYER_PATHS` (`tools/agents.py`), so `test2` is **N/A** with that as the reason. No new spec
FILE, so `SCOPE_SPECS` and `BLAST_RADIUS` in `tools/studio_mcp.py` need no row and `selftest` cannot
fail on this task.

---

## 3. The data: which number lives where

### 3.1 `Shotgun.CONFIG.CLAIM` after v5

**How much a server is willing to believe a client is a property of the SERVER, not of a gun**
(`src/shared/Weapons/init.luau`'s header). A per-weapon claim tolerance would let a new gun widen
its own licence.

| Field | Value | Unit | Check | What it is |
|---|---|---|---|---|
| `SKIN_STUDS` | `0.15` | studs | 3 | **kept.** How far outside the claimed part's own half-extents the claimed object-space offset may lie. Both sides read the same `Size`; this absorbs floating point and nothing else |
| **`CLAIM_LINE_STUDS`** | **`0.50`** | studs | 4 | **NEW.** The perpendicular distance from the **claim's own** ballistic path to `claim.point`. An honest client's cast returned a point ON that path, and both sides build the path from the same two wire numbers (4.4), so the honest value is float noise. 0.50 is 18× the 0.027 studs measured on a still animal in task 266b |
| **`CLAIM_PATH_TOLERANCE_STUDS`** | **`1.00`** | studs | 4 | **NEW.** `\|along(claim.point) − claim.distanceStuds\|`. It binds the one payload number that `Validator.claimImpact` writes into the report's `distance`, and it closes the "overstate `distanceStuds` by a body length" licence v4 §5.4 admitted |
| **`BODY_TOLERANCE_FACTOR`** | **`0.5`** | — | 5 | **NEW.** Half the claimed animal's own longest trunk extent, which is the body-sized tolerance direction A's fourth bullet asks for, derived from the box rather than guessed (3.2) |
| **`BODY_TOLERANCE_MIN_STUDS`** | **`2.00`** | studs | 5 | **NEW.** The floor, because the honest residual does not shrink with the animal: the grid is `v × VIEW_LAG_STEP_SECONDS` = **0.63 studs at `SPRINT_SPEED` 38**, the ring's linear interpolation is of the order of 0.1, and the client's straight-line prediction over the flight adds the turn's sagitta. A cub's half-trunk is 1.24 studs and would be under all three |
| **`LOS_SLACK_STUDS`** | **`0.50`** | studs | 6 | **NEW.** How far short of the chosen instant's point the LOS cast may stop before the claim is refused `claim-blocked`. It replaces `REACH_SLACK_STUDS` **and the whole self-block waiver** |
| `AGE_MAX_SECONDS` | `0.5` | s | 7 | **kept.** One upward trip plus clock skew, not a flight time |
| `FLIGHT_TOLERANCE_SECONDS` | `0.03` | s | 7 | **kept.** One `FLIGHT_STEP_MAX_SECONDS` (1/30) |
| `MAX_TARGETS` | `8` | count | — | **kept.** The client's bound |
| `MAX_SUBSTEPS` | `16` | count | — | **kept.** The client's bound on one simulation, and the server's bound on the path walk |
| `VIEW_LAG_BASE_SECONDS` | `0.30` | s | 5, 6 | **kept.** The measured 0.178 s of view lag with 1.7× margin |
| `VIEW_LAG_MAX_SECONDS` | `0.45` | s | 5, 6 | **kept.** 2.2× tighter than Source's `sv_maxunlag` (10 B) |
| `VIEW_LAG_STEP_SECONDS` | `1/60` | s | 5, 6 | **kept.** One Heartbeat — the ring's own sampling rate, so the grid is never finer than the data |
| `VIEW_LAG_MAX_SAMPLES` | `28` | count | 5, 6 | **kept.** `0.45 / (1/60) = 27`, plus the arrival instant |

**DELETED, with the reason beside each:**

| Gone | Why |
|---|---|
| `LINE_TOLERANCE_STUDS = 2.0` | its check is deleted (5.4). The name must go with it: a reader who finds `LINE_TOLERANCE_STUDS` next to `CLAIM_LINE_STUDS` will carry the old meaning into the new check |
| `POSITION_TOLERANCE_STUDS = 6.0` | replaced by the per-kind body tolerance, which is **tighter for every one of the seven kinds** (3.2) |
| `REACH_SLACK_STUDS = 1.0` | its check is replaced by an explicit cast (5.6). With it go `stoppedByClaimedTarget`, `span = 2·max(partHalf)` and `displacementStuds` — the three pieces of the self-block waiver that tasks 269b, 273a(b), 274a(b) and 275 each widened by hand |

### 3.2 The body-sized tolerance, per kind, off the measured boxes

Direction A's fourth bullet asks for *"a body-sized tolerance"*. The BRIEF asks it be derived from
the trunk the zones actually have, not guessed. The owner reads it off the claimed animal's **own
trunk Part** — the Instance `Hits.targetOf(claim.part)` already returned, which is the
`Damageable` box `Boar.Body.create` sized as `config.BODY_SIZE * scale` (`Body.kindGeometry`):

```
bodyToleranceStuds = math.max(
    CLAIM.BODY_TOLERANCE_MIN_STUDS,
    CLAIM.BODY_TOLERANCE_FACTOR * math.max(trunk.Size.X, trunk.Size.Y, trunk.Size.Z)
)
```

`Boar.CONFIG.BODY_SIZE = (2, 3, 5.5)` for the boar kinds; `Boar.CONFIG.SPECIES.reddeer.BODY_SIZE =
(1.8, 4.8, 7.05)` for the three deer kinds; `Boar.CONFIG.KINDS.<kind>.scale` scales both
(`Body.kindGeometry` → `bodySize = config.BODY_SIZE * scale`):

| kind | scale | trunk length | half | **tolerance** |
|---|---|---|---|---|
| `male` | 1.0 | 5.50 | 2.75 | **2.75** |
| `female` | 0.85 | 4.675 | 2.34 | **2.34** |
| `cub` | 0.45 | 2.475 | 1.24 | **2.00** (floored) |
| `legendary` | 1.35 | 7.425 | 3.71 | **3.71** |
| `stag` | 1.0 | 7.05 | 3.525 | **3.53** |
| `hind` | 0.8553 | **6.030** | 3.015 | **3.02** |
| `calf` | 0.495 | 3.490 | 1.745 | **2.00** (floored) |

The hind's 6.030 is the BRIEF's own measured 6.03-stud trunk, which is where the rule is anchored.
**Every one of the seven is tighter than the 6.0 it replaces**, and the two kinds the floor catches
are the two smallest and slowest animals in the game.

It is a **fact measured by the owner and handed in**, not a config read inside `Validator` — the
same reason `Validator.checkShot` takes `toleranceStuds` as its fourth argument since task 260: a
bound that can only be read at one value cannot be driven at another.

### 3.3 The animal's memory — `Boar.CONFIG.HISTORY`, unchanged

`SAMPLES = 96` (1.60 s at 60 Hz), `ENABLED = true`. The cross-owner invariant in
`tests/server/zz_claim_window.spec.luau` is unchanged in substance:
`SAMPLES/60 ≥ AGE_MAX_SECONDS + VIEW_LAG_MAX_SECONDS + 1/60`, with the existing `span/window ≥ 1.5`
margin — `1.600 / 0.9667 = 1.655`. **Its other two assertions must be rewritten**, because both name
rows that no longer exist (12.3).

### 3.4 The flag — unchanged, and no new flag

`HIT_CLAIM` (`src/shared/Flags/init.luau`, born 2026-10-25 task 266, default `false`) covers every
line v5 touches. The parameter reachability CLAUDE.md requires is already there:
`Weapon.setClaimPolicy(enabled)` reaches both states, and `Weapon.setViewWindow(0)` collapses the
window to the arrival instant alone.

**`expires = "2026-11-15"` and today is 2026-10-26.** v5 does not move it.
`tests/server/flags.spec.luau` fails the harness on a past date, so the build task either ships
before then or moves the date in one line and says why.

---

## 4. Public interface

### 4.1 `ReplicatedStorage.Ballistics` — unchanged

`CONFIG`, `shotFor`, `timeToRange`, `speedAt`, `dropAt`, `elevationTangent`, `launchDirection`,
`sightOffsetAt`, `advance`, `segment`, `boreOrigin`, `convergeAim`, `leadStuds`: **not touched by
v5.** Task 273 settled that the error is not vertical and not ballistic drop
(`sightOffsetAt(150) = +0.034` studs ABOVE the sight line with `GRAVITY_SCALE = 0.12`).

### 4.2 `ReplicatedStorage.Shotgun` — the payload is unchanged

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

**No new field.** `Shotgun.muzzleOf(tool)` and `Shotgun.remotes()` (six remotes) unchanged. The
claim rides `FireRequest` inside `FIRE_RATE_LIMIT` (6/s). Only `CONFIG.CLAIM`'s rows move (3.1).

### 4.3 `ServerScriptService.Weapon.Validator` — pure

```luau
Validator.checkShot(req, rootPosition, config, toleranceStuds?)   -- UNCHANGED (check 2)
Validator.checkClaim(claim, config, pellets?)                     -- UNCHANGED (shape, at the trigger)
Validator.closestOnSegments(segments, point): (Vector3?, number)  -- UNCHANGED. Now serves check 4
Validator.claimImpact(claim, partCFrame, bore, material?)         -- UNCHANGED

Validator.nearestInstant(candidates: { { at: number, point: Vector3 } }, clientPoint: Vector3)
    : (number?, number?)
    -- WHICH PICTURE THE SERVER JUDGES AGAINST. Returns (index, studs) -- the candidate minimising
    -- |clientPoint - point|, and that minimum. (nil, nil) for an empty list.
    --
    -- IT REPLACES `pickViewInstant`, WHICH HAD TWO CRITERIA. The old one filtered on check 3 and
    -- then minimised check 4's expression; with check 4 deleted there is only one quantity left to
    -- minimise, and a rule with one criterion cannot disagree with itself. `limits` and `segments`
    -- are no longer parameters: the ACCEPT/REFUSE decision is `judgeClaim`'s alone, and this
    -- function now only answers "which instant".
    --
    -- **THIS IS TASK 269b's REFUSED BACKWARD SEARCH, AND IT IS CORRECT NOW FOR A STATED REASON.**
    -- 269b was refused because it widened check 3 into "the best of thirteen" while check 4 still
    -- carried the geometric weight -- so the only check being minimised was the one that had
    -- stopped measuring. Check 4 is gone (5.4), the existential IS the positional check, and its
    -- licence is enumerated in 5.9 rather than left implicit. A mechanism is not wrong for being
    -- a search; it is wrong for being a search nobody bounded.

Validator.judgeClaim(facts, limits): (boolean, string?, number?, number?)
    -- REWRITTEN. Checks 3, 4, 5, 6 and 7 (5.2). The (measured, budget) pair is kept as the third
    -- and fourth returns, in each rule's own unit, and nil/nil for a rule whose refusal is not a
    -- magnitude. Every fact is a number or a Vector3; this module still touches no Instance, no
    -- service and no clock.
```

`facts` after v5:

```luau
{
    offset: Vector3, partHalf: Vector3,        -- check 3
    clientPoint: Vector3,                       -- checks 4, 5
    pathStuds: number, pathAlongStuds: number,  -- check 4: the owner walked the claim's own path
    claimedStuds: number,                       -- checks 4, 7
    proximityStuds: number,                     -- check 5: the MINIMUM over the window
    bodyToleranceStuds: number,                 -- check 5: 3.2's per-kind number, measured by the owner
    losReachStuds: number, losTargetStuds: number,  -- check 6: how far the cast got, how far it had to
    ageSeconds: number,                         -- check 7
    flightSeconds: number, expectedFlightSeconds: number,  -- check 7
}
```

**Gone from `facts`:** `serverPoint`, `trajectoryPoint`, `reachedStuds`, `stoppedByClaimedTarget`,
`displacementStuds`. The first two were old check 4's two operands; the last three were the reach
rule and its waiver.

### 4.4 `ServerScriptService.Weapon` — what changes

```luau
-- UNCHANGED: start, grant, revoke, forget, getSnapshot, markHit, refreshArming, refillForDrive,
-- armingAction, reachable, roundsLeft, heldId, rowOf, setCast, setDriveLineProvider,
-- setArmingPolicy, setTargetProvider, setStandProvider, setLicenceProvider, setEntitlementProvider,
-- setDriveOpenProvider, setSafetyLineProvider, setHistoryProvider, setClaimPolicy, setViewWindow,
-- viewWindowFor, catchUpFor, onActionRequest, onFireRequest, runCycle, flightCount, flightShots,
-- publishClaimStats, claimLine, HitReported, SafetyViolated, ShotFired.
```

`Weapon.stats()` — the claim counters after v5:

| kept | `claims`, `claimsIgnored`, `claimsAccepted`, `claimsRefused`, `refusedClaimBy`, `refusedClaimWorst`, `claimAgeMin`, `claimAgeMax`, `claimAges`, `claimHistoryWhy`, `claimLastPart`, `claimSweepFound`, `claimSweepAsked`, `claimSweepWindow`, `claimSweepIndex`, `claimWorstLagSeconds` |
|---|---|
| **NEW** | `claimBestProximityStuds` — **the minimum over the window, written for EVERY claim that reached the sweep, accepted or refused.** This is the quantity check 5 budgets and **it has never been published**; task 274's reading of 274a(a) is the whole argument for writing it before the survivors are counted |
| **NEW** | `claimWorstPathStuds` — check 4's worst, over every claim. If this is not near zero on honest claims, the two sides are not flying the same line and the defect is 259b's, not the view lag's |
| **gone** | `claimWorstStuds` (old check 3's quantity), `claimWorstLineStuds` and `claimWorstEndStuds` (271 round-1 finding 5: the two are now **identically the same expression** — `closestStuds` and `(position − serverPoint).Magnitude` with `position = closest` — so one of the three published numbers is a duplicate), `claimSweepSpread`, `claimSweepBestLine`, `claimSweepBestIndex`, `claimSweepPassed`, `claimSweepSegments`, `claimLastDisplacement` — every one of them measures a check that no longer exists |
| **retired, not built** | `claimLagAtEdge` and `claimViewWindowMax` (271 round-1 finding 6) are **withdrawn as names**: task 272 shipped `claimSweepIndex`, `claimSweepFound` and `claimSweepWindow`, which answer the same two questions (`atEdge` is `claimSweepIndex == claimSweepFound`). Two names for one reading is the failure this project is named after |

**No setter for the history, no way to write a sample, and no remote carrying a position, a time or
a ping in either direction** beyond the one optional claim field.

### 4.5 `ServerScriptService.Boar` — not touched

```luau
Boar.CONFIG.HISTORY = { SAMPLES = 96, ENABLED = true }
Boar.sampleAt(ring, count, at): CFrame?   -- linear interpolation between BRACKETING samples; nil
                                          -- outside the span, which is a REFUSAL, never an extrapolation
Runtime:cframeAt(instance, at): CFrame?   -- the one reader of the ring
Runtime:stats()                           -- historySamples, historyMisses
```

### 4.6 `PlayerScripts.Weapon.Claim` — two changes, both about honesty of the reason

`Claim.world`, `Claim.only`, `Claim.visibleTargets`, `Claim.simulate` and `Claim.forCamera` keep
their signatures. Two behaviours change (5.7, 16.2) and both are about the **second return**, the
no-claim reason `Input.fire` writes to the Studio-only `DHClaimWhy`:

```luau
Claim.simulate(opts): (Shotgun.HitClaim?, string?)
    -- The second return is DECLARED now. Today the function returns `nil, "static-blocked"` while
    -- its signature says `Shotgun.HitClaim?`, so the reason is undeclared API that two tasks have
    -- already drawn conclusions from.
    --
    -- THE REASONS, AND "static-blocked" IS SPLIT (5.7):
    --   "no-target" | "no-segment" | "range-capped" | "out-of-substeps"  -- unchanged
    --   "blocked"       the nearest TARGET impact exists and a static impact is NEARER. A tree, a
    --                   post or the ground genuinely in front of the animal
    --   "no-intersect"  no target impact in this sub-step at all. The bullet, as this client drew
    --                   it, did not meet the animal. THIS IS A MISS, and it is the reading task 275
    --                   reported as "static-blocked"
    --   "refined-nil"   unchanged (task 270's drop-on-nil rule fired)
```

### 4.7 Why the client's line and the server's agree by construction

This is what makes check 4 (4.4) an honest-by-construction check rather than a tolerance, and it is
read off the code, not assumed:

- `Shotgun.CONFIG.BORE_ON_SIGHT_LINE` ships **`true`** since task 260.
- Client: `origin = Ballistics.boreOrigin(cframe.Position, cframe.LookVector, muzzle, true)` —
  the Tool's muzzle **projected onto the camera ray** (`Claim.forCamera`).
- Server: `origin = Ballistics.boreOrigin(req.origin, req.direction, muzzle, CONFIG.BORE_ON_SIGHT_LINE)`
  and `shot.muzzle = origin` (`Weapon.onFireRequest`). `req.origin` and `req.direction` are the
  client's **own** two numbers, over the wire.
- Both then take `convergeAim(origin, aimPoint, direction, MIN_AIM_DISTANCE)`, which with the bore on
  the sight line returns the camera's own direction *whatever the ray hit*, and
  `launchDirection(aim, ballistic)` to elevate.

**So the two polylines are the same curve, and the only disagreement — the Tool muzzle's own
replication — is a projection onto the SAME ray, which is a shift ALONG the line and contributes
nothing perpendicular to it.** That is why `CLAIM_LINE_STUDS` can be 0.50 and why task 266b measured
the across-track distance at **0.027 studs of a 2.0 budget** on a still animal. **This design has a
stated dependency on `BORE_ON_SIGHT_LINE` staying `true`**; at `false` the two bores diverge by the
measured 0.73 studs across the sight line and check 4's budget would have to carry it.

### 4.8 `PlayerScripts.Weapon.Input`, `Flight`, `Hits`, `Effects` — unchanged by v5

`Input.fire` is still the one firer of `FireRequest`. `Flight.launch/advance/count/shots/stats` are
untouched; `Resolution.reachedStuds` is **no longer read by the claim path** and stays only as the
flight's own report. `Hits.group` is still the one `HitReport` constructor.
`src/client/Weapon/Effects.luau` is **not touched by this task** (16.6).

### 4.9 `judgeClaimFor`, the exact shape the Builder writes

In `src/server/Weapon/init.luau`. Everything above the sweep (the policy, `Hits.targetOf`,
`claim.part:IsA("BasePart")`, `claimLastPart`, `arrivalAt`, `age` and its min/max) is **unchanged**.

```
-- 0 POLICY / 1 IDENTITY -- unchanged
target        = Hits.targetOf(claim.part)                 -- the trunk, carrying `Damageable`
part          = claim.part :: BasePart
arrivalAt     = claim.firedAtView + claim.flightSeconds    -- DERIVED, never sent
age           = Workspace:GetServerTimeNow() - arrivalAt

-- THE CLAIM'S OWN PATH, WALKED ONCE (check 4). `Ballistics.advance` from `shot.muzzle` along
-- `shot.bore` for exactly `claim.flightSeconds`, at most `CLAIM.MAX_SUBSTEPS` segments, each
-- `math.min(remaining, CONFIG.FLIGHT_STEP_MAX_SECONDS)`. This is the loop that is already there.
--
-- IT IS NOT EXTENDED BEYOND `claim.flightSeconds`, and that is a rule: one sub-step at the slug's
-- 1752 studs/s is 58 studs of extra line, which is 58 studs of free licence for a claim that
-- understates its flight time. The walk is the right length by construction.
segments, pathEndStuds = walk(shot, claim.flightSeconds)
_, pathStuds           = Validator.closestOnSegments(segments, claim.point)
pathAlongStuds         = alongOf(segments, claim.point)   -- path studs from the bore to the
                                                          -- projection of `claim.point`

-- THE CANDIDATES, NEWEST FIRST, AT MOST `VIEW_LAG_MAX_SAMPLES`. Unchanged from v4, including the
-- break rule and `claimHistoryWhy`'s publication point.
window    = Weapon.viewWindowFor(shooter)
candidates = { ... { at = t, point = askWhereWas(claim.part, t) * claim.offset } ... }
if #candidates == 0 then return refuse("claim-history") end

-- ONE INSTANT, CHOSEN ONCE, AND IT IS THE ONLY CLOCK IN THE RULE SET (5.3).
index, proximityStuds = Validator.nearestInstant(candidates, claim.point)
serverPoint     = candidates[index].point
lineLagSeconds  = arrivalAt - candidates[index].at

-- THE LINE OF SIGHT, AT THAT SAME INSTANT (check 6), THROUGH THE EXISTING `castFn` SEAM (5.6).
to            = serverPoint - shot.muzzle
losTargetStuds = to.Magnitude
ignore        = table.clone(shot.ignore); table.insert(ignore, target)
blockHit      = castFn(shot.muzzle, to, ignore)
losReachStuds = if blockHit ~= nil then blockHit.distance else losTargetStuds

ok, reason, measured, budget = Validator.judgeClaim({
    offset = claim.offset, partHalf = part.Size / 2,
    clientPoint = claim.point,
    pathStuds = pathStuds, pathAlongStuds = pathAlongStuds, claimedStuds = claim.distanceStuds,
    proximityStuds = proximityStuds,
    bodyToleranceStuds = bodyToleranceOf(target),          -- 3.2
    losReachStuds = losReachStuds, losTargetStuds = losTargetStuds,
    ageSeconds = age,
    flightSeconds = claim.flightSeconds,
    expectedFlightSeconds = Ballistics.timeToRange(ballistic, claim.distanceStuds),
}, CONFIG.CLAIM)
```

Four details that are rules, not implementation taste:

- **`stats.claimBestProximityStuds` and `stats.claimWorstPathStuds` are written BEFORE the verdict**,
  for every claim that reached the sweep. 274a(a) is the reason: a field that records only the
  survivors measures the filter, not the thing — the same lesson `claimLastPart` was moved for.
- **`stats.claimHistoryWhy` is published only when NO candidate answered.** Unchanged from v4,
  including the `whyBefore`/`lastWhy` restore. Deleting it destroys the one diagnostic that tells an
  unwired root from an unplaceable animal (task 266b, which cost a live session).
- **The LOS cast is made once, after the instant is chosen, and only if the claim has got that far.**
  At most one extra cast per claimed shot, single-pellet only, at most 6/s.
- **The refusal note's decomposition keeps its three axes and its `reason == "claim-moved"` is
  FIXED.** Today the branch reads `reason == "claim-line" or reason == "moved"`; `judgeClaim` has
  never returned `"moved"` (271 round-1 finding 7, still unfixed at `a3b6663e`), so the only refusal
  the fallback was written to explain carries a nil note.

---

## 5. The rule set

### 5.1 The order, end to end

| # | Where | What | v5? |
|---|---|---|---|
| 1 | client, trigger frame | `Input.fire` → `Claim.forCamera` → `Claim.simulate`. The whole simulation is in this one frame | reason strings only |
| 2 | wire | one `FireRequest`, `{ origin, direction, claim? }` | unchanged |
| 3 | server, trigger frame | rate limit → weapon id and row → `Validator.checkShot` (**check 2**) → `StateMachine.apply{Fire}` (**check 1**) → muzzle → aim ray → `boreOrigin`/`convergeAim` → `stopAt` → `Rules.refuse` → `setState` → `Ballistics.shotFor` | unchanged |
| 4 | server, trigger frame | `Validator.checkClaim` on the claim's SHAPE and the weapon's `PELLETS` row. A fault counts `refusedClaimBy[reason]` and **drops the claim**; the shot proceeds | unchanged |
| 5 | server, trigger frame | `flight:launch(...)` → `SafetyArc` → `safetySignal:Fire(player, aim, origin, stopAt)` → publish → bolt → `ShotFired` | unchanged |
| 6 | server, later Heartbeats | `flight:advance(dt, castFn)` | unchanged |
| 7 | server, at the resolution | `onShotLanded` → `judgeClaimFor`: **the sweep → the instant → the LOS cast → `judgeClaim` (checks 3–7) → `Hits.group` once** | the rule set is new |

**Why step 7 and not step 4.** The claimed arrival is `firedAtView + flightSeconds`, which at step 4
is still in the server's **future** whenever the flight is longer than the upward trip. At step 7 it
is in the past and the history covers it. **The shot in the air IS the pending queue** — no second
remote, no shot id, no pending table, no timeout, no race.

### 5.2 The seven checks, each with its cheat and its honest worst case

Direction A's five bullets, as a numbered list. Bullets 1 and 2 are checks 1 and 2 and already
exist, at the trigger; bullet 3 is checks 3 and 4; bullet 4 is check 5; bullet 5 is check 6.
Check 7 is not in the direction's list and is kept because it stops three named cheats.

---

**CHECK 1 — THE SHOOTER COULD FIRE.** `FIRE_RATE_LIMIT` (6/s) → `Validator.checkRequest` →
`StateMachine.apply{Fire}` (a chambered shell, a closed action) → `Rules.refuse` (the licence, the
entitlement, the drive phase, the stand) → the safety lock (`SafetyArc` + `askLineUnsafe`).
*Owner:* `Weapon.onFireRequest`. *Refusals:* the existing `badRequests` / `refusedBy` counters.

- **Cheat:** a claim about a shot that never happened — firing faster than the gun cycles, with an
  empty chamber, outside a drive, or through the drive line without the penalty.
- **Worst honest case:** `FIRE_RATE_LIMIT` 6/s against the rifle's real cycle time; a player on a
  bad connection whose requests bunch.
- **Measured / budget:** requests per second / 6. **Unchanged, and no claim reaches check 3 without
  passing it** — a claim cannot exist without a shot.

---

**CHECK 2 — THE CLAIMED MUZZLE IS WHERE THE SHOOTER IS.** `Validator.checkShot(req, rootPosition,
CONFIG, toleranceStuds)`: `|req.origin − rootPosition| ≤ tolerance`, plus the finite and unit tests.
*Owner:* `Weapon.onFireRequest`, at the trigger.

- **Cheat:** shooting from somewhere the player is not — round a corner, from the far stand, from
  inside a tree.
- **Worst honest case:** the stock third-person camera is MEANT to be behind the character; the
  owner passes the **first-person** number when the camera is first person, because the two branches
  put the eye in genuinely different places (1.99 studs from the root against the third-person
  clamp's 14.5).
- **Measured / budget:** `|req.origin − root|` / `CAMERA_ORIGIN_TOLERANCE`, with
  `stats.originFarthest` and `originRefusedFarthest` as the instruments (task 260).
  **Unchanged by v5.** The claim carries no muzzle of its own, so there is nothing new to check.

---

**CHECK 3 — THE OFFSET IS ON THE CLAIMED BOX.** `|claim.offset|` componentwise
`≤ part.Size/2 + SKIN_STUDS`. *Owner:* `Validator.judgeClaim`. *Refusal:* `claim-offset`.

- **Cheat:** naming a point that is not on the thing the claim says it hit — a point ten studs above
  the animal, chosen because the sky has a clear line of sight to it and the box does not.
- **Worst honest case:** both sides read the same `Size`, and the client's own
  `part.CFrame:PointToObjectSpace(hit.position)` returns a point on the surface the cast struck.
  The disagreement is floating point.
- **Measured / budget:** the worst axis's overhang / `SKIN_STUDS = 0.15`. **Unchanged by v5.**

---

**CHECK 4 — THE CLAIM'S OWN LINE.** Two parts, both against the claim's **own** ballistic path:

```
pathStuds       = dist(path(shot.muzzle, shot.bore, claim.flightSeconds), claim.point)
                  <= CLAIM_LINE_STUDS                                  -> "claim-line"
|pathAlongStuds - claim.distanceStuds| <= CLAIM_PATH_TOLERANCE_STUDS   -> "claim-path"
```

*Owner:* the owner walks the path and measures; `Validator.judgeClaim` judges.

- **Cheat:** a payload whose numbers describe three different shots — a point lifted from one frame
  with a direction from another, or a `distanceStuds` inflated to move the report's `distance`.
  `Validator.claimImpact` writes `claim.distanceStuds` straight into the `HitReport`.
- **Worst honest case:** §4.7 — the two sides build one curve from the same two wire numbers with
  `BORE_ON_SIGHT_LINE = true`, so the only divergence is a shift ALONG the line. The client's own
  cast returned a point ON its own segment, and the sub-step grid is the same
  `FLIGHT_STEP_MAX_SECONDS` on both sides.
- **Measured / budget:** `pathStuds` / 0.50 and the along-error / 1.00. **Measured honest value:
  0.027 studs** on a still animal (task 266b, with the meter corrected in the same round).
- **What this check does NOT do, said once so nobody believes otherwise:** it is a
  self-consistency test. `req.direction` is unbounded (`Validator.checkShot` bounds the origin and
  nothing else), so a modified client satisfies it by construction. It is kept because it costs one
  already-existing walk and it is the only thing binding `distanceStuds` — **not because it stops an
  aimbot.** 5.9.

---

**CHECK 5 — THE TARGET WAS THERE.** Direction A's fourth bullet, as an existential over the window:

```
proximityStuds = min over t in [arrivalAt - window, arrivalAt] of
                     | rewound(t) * claim.offset - claim.point |
                 <= bodyToleranceStuds                           -> "claim-moved"
```

with `window = Weapon.viewWindowFor(shooter)` and `bodyToleranceStuds` from 3.2.
*Owner:* the owner builds the candidates and asks `Validator.nearestInstant`;
`Validator.judgeClaim` judges the minimum. **This is the only positional check in the rule set.**

- **Cheat:** claiming a hit on an animal that was never near the claimed point — an animal 30 studs
  away, an animal in another part of the wood, or a point in empty space.
- **Worst honest case, term by term:** the client's straight-line prediction over the flight
  (`Claim.simulate` steps each animal at the velocity it is **drawn** moving at, so an animal that
  turns is mispredicted by the turn's sagitta: **negligible at 20–60 m**, where the rifle's flight
  is 0.028–0.086 s, and of the order of 2 studs only at the 800-stud cap's 0.365 s); the sweep's
  grid, `v × VIEW_LAG_STEP_SECONDS` = **0.63 studs at `SPRINT_SPEED` 38**; the ring's linear
  interpolation between 60 Hz samples, of the order of 0.1 studs; and the drawn velocity against the
  server's. Sum at the criterion's ranges: **about 1 stud.**
- **Measured / budget:** `proximityStuds` / 2.00–3.71 by kind. **This exact quantity has never been
  published** — `claimWorstStuds` was the value at the chosen instant on ACCEPTED claims only — so
  `stats.claimBestProximityStuds` ships with the check and writes on every claim (4.9). The number
  the window has to remove is the **5.120-stud** arrival-instant gap measured in task 271.
- **Refusing at the minimum is the whole point.** `refusedClaimBy["claim-moved"]` with
  `claimBestProximityStuds` beside it says, in one reading, that **no** picture of the animal in the
  last 0.30–0.45 s was within a body of the claimed point.

---

**CHECK 6 — THE LINE OF SIGHT, AT THAT INSTANT.** One cast, from `shot.muzzle` towards
`serverPoint = candidates[t*].point`, through `castFn`:

```
losReachStuds + LOS_SLACK_STUDS >= losTargetStuds     -> "claim-blocked"
```

*Owner:* the owner makes the cast (it needs Instances); `Validator.judgeClaim` compares the two
numbers. 5.6 is the mechanism and the exclusions.

- **Cheat:** claiming through a wall, a trunk, a stand post, a high-seat deck or a hill.
- **Worst honest case:** the claimed animal's own parts (**excluded by name**, 5.6); foliage
  (**already non-blocking**, 5.6); the ground under a deer crossing low ground — which must still
  block, and does not, because the cast **ends at the animal** rather than running the full
  sub-step. A second animal genuinely between muzzle and target still refuses, which is correct.
- **Measured / budget:** `losTargetStuds − losReachStuds` / `LOS_SLACK_STUDS = 0.50`.
- **It replaces the reach rule AND the waiver.** The quantities that forced the waiver bigger three
  times — 269b's 2.137/1.000, 273a(b)'s 4.105/3.40, 274a(b)'s **7.275/3.40, stopped by the claimed
  animal's own `ZoneChest`** — are all the same fault: the server's own bullet stopped on the
  claimed animal, and an arithmetic comparison of two travel distances cannot tell that from a tree.
  A cast that **excludes the claimed animal** cannot have the fault at all.

---

**CHECK 7 — THE CLOCK AND THE CARTRIDGE.** Unchanged:

```
ageSeconds < 0                            -> "claim-future"
ageSeconds > AGE_MAX_SECONDS              -> "claim-stale"
|flightSeconds - timeToRange(shot, distanceStuds)| > FLIGHT_TOLERANCE_SECONDS -> "claim-time"
```

- **Cheats:** an arrival in the server's future (a clock pushed ahead); a claim replayed from
  minutes ago, outside the span the animal remembers; and a claimed flight time that does not belong
  to the claimed distance — which, with check 4's `claim-path`, is what makes `distanceStuds`
  derived rather than free.
- **Worst honest case:** one upward trip plus clock skew / 0.5 s; one `FLIGHT_STEP_MAX_SECONDS`
  (1/30) of sub-step granularity / 0.03 s. Measured `age` on a loopback: **+0.007 to +0.075 s**.
- **Named and deferred:** `Weapon.catchUpFor` resolves the shot EARLY by up to
  `FLIGHT_CATCHUP_MAX_SECONDS` (0.15), so on a real connection `age` is expected to go **negative**
  and `claim-future` to appear. The fix is one line — the floor becomes
  `−FLIGHT_CATCHUP_MAX_SECONDS`, under a `claim-early` reason of its own, because the server
  resolved early on purpose and must not charge the shooter for its own generosity. The condition is
  `stats.claimAgeMin < 0` together with a non-zero `refusedClaimBy["claim-future"]`. **A task, not a
  dial, and not this one.**

### 5.3 One clock, and only two checks have it

| check | depends on an instant? |
|---|---|
| 1 shooter could fire | no — the trigger frame |
| 2 muzzle near the character | no — the trigger frame |
| 3 offset on the box | **no.** A constant of the animal's own body |
| 4 the claim's own line | **no.** The path and `claim.point` are both in the claim's own frame |
| 5 the target was there | **yes — `t*`** |
| 6 the line of sight | **yes — the same `t*`** |
| 7 the clock and the cartridge | no — `arrivalAt`, which is derived and bounded by check 7 itself |

`t*` is chosen **once**, by `Validator.nearestInstant`, called **once**, from `judgeClaimFor`. There
is no second search and no second lookup. This is BRIEF item 4 answered: task 275 found `claim-line`
already at the swept instant and `claim-blocked` reading the flight's own reach — **two clocks**.
v5 removes one of them by removing the check that used it.

### 5.4 `claim-line` resolved by name — BRIEF item 2

> Today (`Validator.judgeClaim`, check 4) it measures `(facts.trajectoryPoint − facts.serverPoint).Magnitude`
> against `limits.LINE_TOLERANCE_STUDS`.

**That check is DELETED.** Not redefined in place, not kept with a derived budget. Both of its
operands are **server-side reconstructions**:

- `trajectoryPoint` is the closest point on the server's own re-step of the shot, which the server
  built from `req.origin` and `req.direction` — **both supplied by the client**;
- `serverPoint` is the server's own rewind of the claimed offset at an instant the server chose.

**It therefore measures the disagreement between two of the server's own reconstructions, and the
claim appears in neither operand.** An honest client has no way to satisfy it except by luck, and
the magnitude it accumulates is the sum of: the re-step's own error, the ring's sampling and
interpolation, the grid, the client's straight-line prediction, and — the dominant term — **the
mismatch between the animal's pose the client predicted and ANY pose the server recorded**. That
last term is check 5's business and is budgeted there at a body. Charging it to a 2.0-stud "line"
tolerance is what produced **4.09 of 2.00 in task 274 and 2 of 2 refused in task 276**, while task
272 proved the sweep healthy (`sweep=19/19 win=0.301s spread=8.046`) and `took == best` on every
trial. **The sweep found the best instant available and the best was still refused: the rule, not
the search, was wrong.**

**WHICH REMAINING CHECK STOPS THE CHEAT IT WAS STOPPING.** The cheat v4 §5.4 claimed for it was
*"claim a hit on an animal the bullet passed to the SIDE of"*. The honest answer, which v4 did not
give:

> **Nothing stopped that cheat, including the check itself.** `Validator.checkShot` bounds
> `req.origin` against the character root and bounds `req.direction` **not at all** — `shotgun.md`
> §5.7 already says *"the aim direction is unknowable to the server, so an aimbot passes every
> check"*. A modified client that wants credit for an animal its bullet passed beside simply sends
> a direction AT the animal, and the server's "own" trajectory then passes through it. The old check
> stopped exactly one thing: a modified client that could not be bothered to send a consistent
> direction.

What the other checks do stop, with the direction free, is enumerated in 5.9. The three that carry
real weight are **check 5** (the point must be within a body of a pose the SERVER recorded, at some
instant in a window the SERVER owns), **check 6** (the server's own cast must reach it), and
**check 3** (the point must be on the claimed box). None of those is weakened by deleting check 4.

**The name `claim-line` is REUSED for the new check 4** (the claim's own line), and
`LINE_TOLERANCE_STUDS` is deleted rather than renamed in place, so a stale reader cannot carry the
old budget into the new rule. Every caller and spec must be re-grepped: 13.3.

### 5.5 The lead, and whether it is applied twice — BRIEF item 6

**It is not.** Direction C's *"the lead equals the bullet's flight time only"* is a statement about
the shooter, and the client's own simulation already demands exactly that lead — once.

`Claim.simulate` casts each sub-step's segment translated by `−velocity × (elapsed + along/speed)`
into the animal's own frame, which is **algebraically identical** to advancing the animal forward to
the instant the bullet arrives. So the simulation asks: *does the bullet, at the moment it gets
there, meet the animal where the animal will then be?* The answer is yes **only if the shooter led
by `v × flight`**. That is the flight-time physics, and removing it would delete the lead Karen
asked for, not a duplicate of it. Task 270 measured the reconstruction to **worst |error| 0.009
studs over twelve rows**, three speeds × four ranges.

**What task 275 saw was a 5-stud error, and the lead in dispute is 1 stud.** The arithmetic, with
the repo's own numbers (`METRES_PER_STUD = 0.28`; rifle `MUZZLE_STUDS_PER_S = 2612`,
`DRAG_PER_STUD = 4.29e-4`, so `t = (e^{ks} − 1)/(k·v0)`):

| range | studs | flight | lead at `v = 28.7` | **view lag `v × 0.19 s`** |
|---|---|---|---|---|
| 20 m | 71.4 | 0.0277 s | **0.79 studs** | **5.45 studs** |
| 40 m | 142.9 | 0.0558 s | **1.60 studs** | **5.45 studs** |
| 60 m | 214.3 | 0.0859 s | **2.47 studs** | **5.45 studs** |

At `SPRINT_SPEED` 38 the lead runs 1.05 → 3.27 and the view lag 7.22. **The view lag is 2–7× the
lead and does not shrink with range; the lead does.** Task 276 measured the impact's signed offset
along the animal's velocity at **−3.6 to −7.1 studs in BOTH arms**, unled mean −5.19 against led
mean −5.49 — a difference of 0.30 studs against a 3.5-stud spread. That is the lead being applied
once, correctly, and being swamped.

**So nothing is removed, and nobody owns a removal.** `Claim.simulate`'s advance stays; the
shooter's lead stays; what goes is the **view error**, and checks 5 and 6's shared window is the
only mechanism in this design that removes it. Task 275's *"a shooter who also leads applies it
twice"* is **withdrawn**, and task 276 already withdrew the 0/5-vs-2/5 signal that suggested it as
sampling (1 of 5 against 1 of 5).

### 5.6 "Ignoring the target's own parts and foliage" — the exact mechanism — BRIEF item 5

**The mechanism, verified against this repo before it is asserted:**

```luau
-- `castFn` is the module-level seam `Weapon.setCast` writes and `flight:advance` reads per frame
-- (src/server/Weapon/init.luau). In production it is `Cast.world`:
--   params = RaycastParams.new()
--   params.FilterType = Enum.RaycastFilterType.Exclude
--   params.FilterDescendantsInstances = ignore
--   params.IgnoreWater = true
--   Workspace:Raycast(origin, direction, params)
local ignore = table.clone(shot.ignore)   -- `ignoreFor(player)`, set at the trigger
table.insert(ignore, target)              -- the trunk `Hits.targetOf` already returned
local blockHit = castFn(shot.muzzle, serverPoint - shot.muzzle, ignore)
```

**Four properties, each with its evidence:**

1. **The target's own parts are excluded by excluding the trunk.** The four zone parts are
   `zonePart.Parent = trunk` (`Boar.Body.buildZones`), and `FilterDescendantsInstances` is a
   DESCENDANT filter — so one entry covers the trunk and all four zones. No list, no name matching.
2. **It is not a new raycast owner.** `Cast.world` stays the only caller of `Workspace:Raycast`
   under `src/server/Weapon/`, and the cast is injectable, so every case in `weapon_hits.spec` and
   `weapon_shot.spec` drives it with a scripted world and no boar.
3. **Foliage needs no filter, because it is already non-blocking in the world.**
   `src/server/Places/init.luau` → `Places.unblockFoliage` clears **both** `CanQuery` and
   `CanCollide` on any part whose name matches `Places.FOLIAGE_WORDS`, and runs over
   `Places.foliageRoots(root)` — `Workspace.OurForest` and `Workspace.Session`, the standing Studio
   wood Karen walks through. **This is load-bearing and the repo measured why:** the same file
   records a two-cast control from `driven-hunt-runs/260-why.luau` showing
   `OurForest.SilverBirch_Var11_LOD_0.Branch.001` with `CanQuery=false, CanCollide=TRUE` **HIT**, and
   `SM_AspenTree_Var02.SM_Leaves` with both false **no hit** — so **`CanQuery = false` does not
   exempt a part from a raycast while it still collides**, in the Studio this game is built on.
   **This design therefore depends on that sweep having run in the session**; `report.unblocked` is
   the number that says it did, and 15.3 is the probe.
4. **A present-time cast is a valid answer for a past instant because everything it may hit is
   anchored.** The map's ground, trees, posts and high seats are `Anchored`
   (`Effects.ridesWith`'s own discriminator rests on the same fact), so the static world is
   identical at every instant in a 0.45 s window. **The only movers are animals and players, and
   they are NOT excluded** — a second animal or another hunter genuinely between the muzzle and the
   target refuses the claim, which is correct, with the bounded error that the blocker has also
   moved by up to `v × window` ≈ 17 studs since `t*`. That is a false refusal in rare near-collinear
   geometry, it is in the honest direction (a refused claim falls back to the server's own flight),
   and it is written down here rather than discovered.

**The waiver does not survive.** `stoppedByClaimedTarget`, `span = 2·max(partHalf)`,
`REACH_SLACK_STUDS` and `displacementStuds` are all deleted. They existed only because the reach
rule could not tell "my own target stopped my bullet" from "a tree stopped my bullet"; the cast can,
by construction.

### 5.7 `static-blocked` is a wrong word, and the reading taken from it does not follow

`Claim.simulate`, as shipped:

```luau
if bestHit == nil then
    if static ~= nil then
        return nil, if refinedNil then "refined-nil" else "static-blocked"
    end
end
```

`bestHit` is nil when **no target impact was found at all** in this sub-step, or when every target
impact was farther along than the static one. `static` is non-nil when anything static is anywhere
in the sub-step — and one sub-step at the rifle's 2612 studs/s is `FLIGHT_STEP_MAX_SECONDS`, which
is **87 studs**, so the ground is in it on nearly every shot. **Therefore `"static-blocked"` is
returned for a plain miss.**

Task 275 read *"every no-claim shot in ten reads `static-blocked`"* and concluded *"the CLIENT's own
line of sight closed on the grass or a trunk in front of a deer crossing low ground"*. That is one
of three readings and nothing separated them. Task 276 then measured that **6 of 10 shots were
tail-on at the trigger although all 10 passed a chest gate** — and a shot at an animal that has
turned and run 30–60 studs since the gate is exactly a miss. **The commonest no-claim cause is not
established**, and 275a(c) must be read as "unknown" until the split lands.

**The fix is 4.6's reason split**, in `PlayerScripts.Weapon.Claim`: `"blocked"` only when a target
impact exists and a static one is nearer; `"no-intersect"` when the target cast found nothing. Two
words, one `if`, and the next live trial answers the question instead of restating it.

### 5.8 What a refused claim's shot does, and why

**It flies as an ordinary server-side flight and resolves on the server's own impacts.** Unchanged,
and the reasons are unchanged:

- it is the only answer that cannot be gamed — if a refusal were a miss, withholding or corrupting a
  claim would *deny* damage; if a refusal were a hit, the checks would be decoration;
- it is the only answer that makes the flag's OFF state honest: *ignored* and *today* are one code
  path, bit for bit;
- it is the only answer that keeps one owner.

`claimsRefused` and `refusedClaimBy` are how anybody finds out it is happening.

### 5.9 The worst thing a modified client can do with this payload — the enumerated bound, rewritten

This replaces v4 §5.4 entirely (BRIEF item 2 requires it be rewritten, not cited).

**The licence, in one sentence:** *credit for any point on the box of any animal it genuinely has in
front of it, within a body of some pose that animal held in the last `window` seconds, with a clear
line of sight from the shooter's own position.*

| | shipped v4 | **v5** | why the change |
|---|---|---|---|
| across the animal's own path | 2.0 studs | **2.00–3.71 by kind** (3.2) | old check 4's 2.0 was never a real bound: the direction is client-supplied (5.4) |
| along the animal's own path | `v · window` — 8.6 at 28.7, 11.4 at `SPRINT_SPEED` 38, 17.1 at the cap | **the same, plus the body tolerance** | irreducible: the server cannot distinguish *"my picture was 0.19 s old"* from *"I did not lead"* |
| oldest picture creditable | `window` (0.30 + ping, capped 0.45) | **unchanged** | the window is the server's, read from a server constant and a server-read ping |
| overstating `distanceStuds` | up to one body plus the slack, under the waiver | **`CLAIM_PATH_TOLERANCE_STUDS` = 1.0 stud, always** | **tighter.** Check 4's second half binds it to the claim's own path |
| the claimed animal blocking itself | the waiver, widened three times to 7.275 studs | **not a case at all** | the cast excludes the claimed animal |

**Two things it gets for free, and both must be said plainly:**

- it can **claim any zone of an animal it genuinely engaged**, because the zones are arranged
  head-to-tail along the axis the animal runs on, which is the axis the window's licence lies on. A
  gut shot claimed as a heart shot. v4 said the same; v5 does not make it worse.
- it can **skip the lead** and be credited, up to `v · window` of lead — the lead owed at about 180
  studs with a slug. **A modified client can play the game Karen designed against, inside that
  range.** An honest client cannot: its own simulation produces no claim.

**It cannot do any of the following, and each is a numbered check rather than a hope:**

- **claim a hit on an animal that was never there** — check 5, at a body, at **every** instant in
  the window. A point 30 studs off is refused by a factor of eight on the hind;
- **claim a point that is not on the box it names** — check 3;
- **claim a picture OLDER than the window, or from the FUTURE** — the loop cannot ask for one, and
  `ageSeconds` is still measured on `arrivalAt`;
- **claim through a wall, a tree, a post or a hill** — check 6, a real cast through the real world;
- **claim a hit the gun could not have made, at a distance it did not fly** — check 7 plus check 4's
  `claim-path`;
- **claim nine pellets, or claim a pattern** — `pellets == 1` read off the weapon's own row **on the
  server** (section 6). The spread stays the server's secret;
- **name a zone, a damage number or a target root** — not fields of the payload;
- **claim a part it invented** — a locally created Instance does not survive the remote, and
  `Hits.targetOf` requires `Damageable == true`;
- **spam claims** — the claim rides `FireRequest`, inside `FIRE_RATE_LIMIT` (6/s), behind
  `StateMachine.apply{Fire}` and an actual loaded shell;
- **choose its own window** — `Weapon.viewWindowFor`'s, from a server constant and a server-read
  ping. The client sends no timing hint beyond `firedAtView`, which check 7 bounds.

**What this validation is not.** It does not stop an aimbot, and nothing server-side can while the
aim direction crosses the wire. **Nobody should later believe it is stronger than this.** The reason
that is accepted is source D's: there is **no victim** — the target is an AI animal, nobody shoots
players, a drive is not ranked, and the worst a forged claim wins is points in a co-operative hunt.

### 5.10 Shapes considered and rejected

**Keeping old check 4 with a derived budget. REFUSED.** The budget would have to carry the
animal-position term, which is check 5's and is body-sized — so the derived budget is the body
tolerance, and the check becomes check 5 measured against the wrong operand. Two checks with one
budget and different operands is the overlapping-owner failure in miniature.

**Relocating old check 4 onto the client's point (v4's "Candidate A"). REFUSED, for the reason v4
gave and one more.** v4's reason stands: *a bound the server checks against a number the client also
supplied is not a bound* (source C). The extra reason is that v5 already has that check, cheaper and
named for what it is: check 4 is exactly "are your three numbers mutually consistent", kept at 0.50
studs and advertised as self-consistency rather than as anti-cheat.

**A per-claim `viewLag` field (v4's "Candidate B"). REFUSED, unchanged.** The window is a statement
about how much the SERVER is willing to believe. One fewer field to lie about, one more number
measured.

**A `Boar`-side provider returning the best instant or the whole path. REFUSED, unchanged.** It
would need the Boar to know what a claim is, or the weapon to hold the buffer. 28 `pcall`s at ≤6
claimed shots per second is not a cost worth an owner boundary.

**Casting the LOS against a rewound world. REFUSED, and it is not possible.** Roblox cannot raycast
a past world. 5.6 item 4 is the reduction that makes a present cast sound.

**Excluding every unanchored part from the LOS cast. REFUSED.** It would make an animal behind an
animal a free hit and, worse, would need the weapon to enumerate what moves. Excluding the one
claimed target is the smallest exclusion that removes the measured fault.

**A second remote carrying the claim when the client's bullet lands. REFUSED (v3).** A shot id, a
pending table, a timeout and a race.

**Nine claimed pellets for buckshot. REFUSED (v3).** The client would need the pattern, which
`shotgun.md` §5.7 refuses by name.

---

## 6. Buckshot, and what happens to `Flight` — unchanged

**A claim is one line and one point, and it exists only where the shot IS one line and one point:**
`row.PELLETS[ammo] == 1` — the rifle's slug, the lever's, the shotgun's slug and the semi-auto's
slug. `Validator.checkClaim` refuses a pattern with `"claim-pattern"`, read off the weapon's own row
**on the server**. Buckshot's whole reach is 100 studs and its flight there is 0.079 s; its 1.6°
cone at that range already spans about 2.8 studs, so the error a claim would remove is *inside the
pattern*.

| Shot | What `Flight` does | What decides the hit |
|---|---|---|
| single pellet, claim accepted | flies it, times the resolution | the **claim** (impacts truncated to it) |
| single pellet, claim refused or absent | flies it, exactly as today | the **flight** |
| buckshot (9 pellets) | flies all nine, exactly as today | the **flight** |

`Hits.group`'s contract is untouched: nine pellets on one boar stay **one** report with `pellets = 9`.

---

## 7. The dust and the mark — named, not changed here

- The dust is drawn by `PlayerScripts.Weapon.Effects` from `ShotLanded`, payload unchanged. For an
  accepted claim, `parts[1]` is the animal the shooter saw and `impacts[1]` is
  `part.CFrame * claim.offset`.
- **No second drawer**, deliberately: a client-local draw plus `ShotLanded` would be two things
  drawing one puff, and the shooter would see two. Going through the server is also what makes the
  drawing honest — **a refused claim does not draw a hit.**
- **`src/client/Weapon/Effects.luau` and `src/client/Hud/` are NOT touched by this task.** 276a(c)'s
  defect is placed at 16.6 with its owner, and it is a drawing defect, not a validation one.

---

## 8. 259b, closed in task 266 and recorded here

`onFireRequest` published the penalty's ray from `muzzle` while the lock tested it from `origin`;
with `BORE_ON_SIGHT_LINE = true` the two rays are parallel and 0.73 studs apart at every range. The
fix was one line: `safetySignal:Fire(player, aim, origin, stopAt)`. `ShotFired` and `ShotLanded`
keep the Tool's muzzle, and that asymmetry is deliberate: **a flash has to come out of the gun; a
penalty has to measure the bullet's own line.** Not touched by v5.

---

## 9. What it reads from and writes to other systems

### 9.1 Reads

| What | From | Its owner |
|---|---|---|
| the ballistic rows, `RANGE_STUDS`, `PELLETS`, `SPREAD_FULL_DEG`, `GRAVITY_SCALE` | `Weapons.ROWS` | `ReplicatedStorage.Weapons` — frozen |
| the flight limits, the catch-up numbers, **`CONFIG.CLAIM` as rewritten by 3.1** | `Shotgun.CONFIG` | `ReplicatedStorage.Shotgun` — deep-frozen |
| `HIT_CLAIM` | `Flags.isOn`, **once per boundary** (server `src/server/Weapon/init.luau`; client `src/client/Weapon/init.luau`) | `ReplicatedStorage.Flags` |
| where an animal WAS, at up to `VIEW_LAG_MAX_SAMPLES` instants per claimed shot | `historyProvider(instance, at)` → `Runtime:cframeAt` | `ServerScriptService.Boar` |
| **the claimed animal's own trunk box** (check 5's tolerance, 3.2) | `(Hits.targetOf(claim.part)).Size` | `ServerScriptService.Boar` → `Boar.Body.create` writes it |
| `Damageable` / `HitZone` | attributes on the instance | the target's own owner, read by `Hits.targetOf`. **The zone VOLUMES are `docs/design/hit-zones.md`'s** |
| **whether the muzzle can see the point** (check 6) | `castFn(...)` → `Cast.world` → `Workspace:Raycast` | the world. Its foliage flags are `src/server/Places/init.luau`'s (5.6) |
| the shared clock | `Workspace:GetServerTimeNow()` | the engine. **Its tightness is UNESTABLISHED**: 15.1 |
| the shooter's latency | `Player:GetNetworkPing()` through `Weapon.viewWindowFor`, `pcall`'d, parameterised, converted by the existing `FLIGHT_CATCHUP_PING_FACTOR` | the engine. Unspoofable: the client never sends it |
| the equipped Tool's muzzle | `Hardware.muzzlePosition` / `Shotgun.muzzleOf` | `ReplicatedStorage.Shotgun` — one definition, both sides |
| the drive line, the stand, the target, the licence, the entitlement, the drive phase, the safety line | the six existing providers | `ServerScriptService.Match` |

**Still NOT read:** boar state (velocity, brain, wound, id), another player's view, a ping sent by a
client, any client-supplied zone, damage, target root or view lag. **And after v5, not
`part.AssemblyLinearVelocity` either** — the refusal note's decomposition takes the animal's travel
from the sweep's own two rewinds (`candidates[1]` and `candidates[index]`), which closes 271 round-2
note 18 (*"the weapon cannot ask where one is now"*).

### 9.2 Writes

| What | Who reads it | Their owner |
|---|---|---|
| `Weapon.HitReported(report)` | `MatchBoot` → `runtime:takeHit` + `HitLog.recordHit` | `ServerScriptService.Boar`, `ServerScriptService.HitLog` |
| `HitMarker:FireClient` | `PlayerScripts.Hud` | `PlayerScripts.Hud` |
| `ShotLanded:FireAllClients` — unchanged payload | `PlayerScripts.Weapon` → `Effects.playLanded` | `PlayerScripts.Weapon.Effects` |
| `ShotFired:FireAllClients` / `Weapon.ShotFired` | the flash, the smoke, the sound, the kick; `runtime:hearShot` | as today |
| `Weapon.SafetyViolated` | `MatchBoot` → `Match.Penalty` | `ServerScriptService.Match` |
| the claim counters as rewritten by 4.4, and `ServerStorage.DHClaimStats` in Studio | `weapon_state.spec`, the live probe, a harness note | `ServerScriptService.Weapon` |
| the ring buffer | `Runtime:cframeAt` alone | `ServerScriptService.Boar` |

**Nothing else.** v5 writes no boar state, no camera, no Hud, no team, no score, no penalty, no
Tool, no new remote.

---

## 10. External sources

### A. FastCast / FastCast Redux — the segment cast, adopted as a pattern, not vendored

- Docs <https://etithespir.it/FastCastAPIDocs/>; docs repo
  <https://github.com/EtiTheSpirit/FastCastAPIDocs> — **MPL-2.0**, README says *"This is obsolete"*.
  Living fork <https://github.com/010DevX101/FastCastRedux> — **MIT-0**, released 2025-01-25.
- **Well:** the right algorithm, and the reason this design can rewind *without* a rewound cast —
  each step casts only the segment just travelled, so a translated segment is a cast in another
  body's frame. That is exactly what `Claim.simulate` does.
- **Badly:** ships as `.rbxm`, which this repo bans; not on Wally; far more than we need.
- **Adopted:** three sentences of it, in **one** place (`Ballistics.segment`), so the server's
  stepper and the client's simulation step one bullet with one function. Unchanged by v5.

### B. Valve — Source multiplayer networking and lag compensation. The window and its cap

- <https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking> and
  <https://developer.valvesoftware.com/wiki/Lag_compensation>. **Licence:** Valve Developer Community
  wiki text, **CC BY-NC-SA 2.5** per the site's own footer; read as prose, nothing copied.
  **Maintenance:** actively edited community wiki.
- **Well:** the correct analysis of the error — the client's picture is old by a trip **plus its own
  interpolation**, and no server-side cleverness makes the player's screen newer. It names the term
  everybody forgets, and it is the source of the shape `Weapon.viewWindowFor` has: the rewind is
  clamped to the client's own measured latency plus a fixed interpolation allowance and then capped
  hard by `sv_maxunlag` (1.0 s by default; ours is 0.45, **2.2× tighter**).
- **Badly:** Source rewinds *hitboxes* and casts against them, which needs a geometry test in a
  rewound world. Roblox cannot raycast a past world. It also rewinds everything at once; we rewind
  one part for one claim.
- **Adopted:** the bounded window, clamped by measured latency, capped by a constant, with the
  history kept by **the target's own owner** (`Boar`) and never by the weapon.

### C. Epic Games — Gameplay Ability System *target data*: the client computes, the server validates

- <https://dev.epicgames.com/documentation/en-us/unreal-engine/gameplay-ability-system-for-unreal-engine>
  and <https://dev.epicgames.com/documentation/en-us/unreal-engine/networking-overview-for-unreal-engine>.
  **Licence: proprietary** (Epic documentation terms); read as prose, no code taken.
  **Maintenance: actively maintained**, versioned with each engine release.
- **Well:** exactly this design's division of labour, with the right warning — client-supplied target
  data is the single biggest trust surface an ability system has, accepted only inside bounds the
  server can check **for itself**. **That warning is the argument v5 turns on**: it is why old check
  4 is deleted rather than relocated. Both of its operands were server reconstructions of
  client-supplied numbers, so it was never a bound the server could check for itself.
- **Badly, for us:** a C++ framework with prediction keys, prediction windows and rollback machinery
  we would be inventing a Luau copy of. And "validate" is left to the game.
- **Adopted:** the pattern — **client target data + server validation + a named refusal path** — with
  our own seven checks, our own bounds table, and no prediction machinery.

### D. Riot Games — "Peeking into VALORANT's Netcode". Named, and its conclusion deliberately NOT followed

- <https://technology.riotgames.com/news/peeking-valorants-netcode>. **Licence:** article, all rights
  reserved; read as prose, nothing copied. **Maintenance:** a dated (2020) article on a maintained
  publication.
- **Well:** the clearest published statement of the opposite policy — a competitive shooter rewinds
  on the **server** with a bounded window and refuses to let the client decide what it hit, because
  in PvP a client-authoritative hit is a cheat that cannot be detected after the fact. Good also on
  *why* a window must be bounded, and on favour-the-shooter's cost to the victim.
- **Badly, for us, and this is why its conclusion does not transfer:** there is **no victim here**.
  The target is an AI animal, nobody shoots players, a drive is not ranked.
- **Adopted:** the bounded window and the discipline of counting refusals, from a source that argues
  against the mechanism. **Its conclusion is refused with the reason written in 5.9**, so nobody
  later cites it as though it had been overlooked.

### E. Glenn Fiedler — "What every programmer needs to know about game networking"

- <https://gafferongames.com/post/what_every_programmer_needs_to_know_about_game_networking/>.
  **Licence:** article; the site's sample code is **BSD**, nothing taken. **Maintenance:** a standing
  reference, still maintained and still cited.
- **Well:** the framing in one sentence — the client's view is *authoritative about itself and
  nothing else*. Also the source of *"do not interpolate what you can derive"*, which is why
  `arrivalAt` is derived from `firedAtView + flightSeconds` rather than sent, and why the claim
  carries no velocity and no view lag.
- **Badly:** about deterministic lock-step and physics authority in symmetric games; no opinion on
  validating an asymmetric PvE hit claim.
- **Adopted:** one rule, as this design's own — **the client is believed only about what it SAW,
  never about what that means.**

### F. Roblox engine — the clock, the cast, the filter, the remote, the ping

- <https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams>,
  <https://create.roblox.com/docs/reference/engine/classes/WorldRoot#Raycast>,
  <https://create.roblox.com/docs/reference/engine/classes/Workspace#GetServerTimeNow>,
  <https://create.roblox.com/docs/reference/engine/classes/Player#GetNetworkPing>,
  <https://create.roblox.com/docs/reference/engine/classes/RemoteEvent>.
  **Licence:** the documentation source repo <https://github.com/Roblox/creator-docs> is **CC BY 4.0**;
  the engine is proprietary. **Maintenance: actively maintained** with the engine.
- **Well:** `FilterType = Exclude` with `FilterDescendantsInstances` is a **descendant** filter, which
  is what makes check 6's exclusion of the claimed animal one table entry rather than a list of five
  parts. `GetServerTimeNow()` is the one clock both sides can name without a protocol of our own,
  and this repo already trusts it across the wire for the drive's countdown. An **Instance**
  reference crosses a `RemoteEvent` intact, which is why the claim needs no id table.
- **Badly:** the documentation makes **no promise about how tightly `GetServerTimeNow()` agrees**
  between a server and a client (15.1), and says only *"the network ping in seconds"* for
  `GetNetworkPing` — **not whether that is a round trip or one way**, which is why
  `FLIGHT_CATCHUP_PING_FACTOR` exists as a data row and `viewWindowFor` reuses it rather than adding
  a second. **And the engine's own `CanQuery` does not behave as documented in this Studio while
  `CanCollide` is true** — the repo measured it with a control (5.6 item 3), which is why this
  design leans on `Places.unblockFoliage` rather than on the property.
- **Adopted:** the clock inside a window, descendant-filtered casts, Instance references instead of
  ids, attributes as the one description of a target, and the ping as a **clamped** term with a
  documented unit uncertainty.

### G. Gabriel Gambetta — "Fast-Paced Multiplayer, Part IV: Lag Compensation"

- <https://www.gabrielgambetta.com/lag-compensation.html> (series index:
  <https://www.gabrielgambetta.com/client-server-game-architecture.html>). **Licence:** article, all
  rights reserved; the demos' source is published separately and nothing is taken.
  **Maintenance:** a standing reference, still online and still the article everybody links.
- **Well:** the clearest statement of the thing both v4 and v5 turn on — **the server must judge the
  shot against the picture the shooter actually had, which means reconstructing the world at
  `now − (latency + interpolation)` rather than at `now`.** Honest about the consequence in one
  line: the victim gets shot after reaching cover.
- **Badly:** hitscan only, no projectiles, no treatment of a *modified* client inside the window, and
  no case where the client, not the server, computes the hit. The cheat analysis in 5.9 is ours.
- **Adopted:** the reconstruction instant itself, and the insistence that the amount be derived from
  measured latency rather than assumed.

### H. **NEW in v5.** ioquake3 (id Tech 3) — `g_antilag`, `G_TimeShiftAllClients`

- <https://github.com/ioquake/ioq3>. **Licence: GPL-2.0** — so **nothing may be copied into this
  repo at all**, and it is read as prose only. **Maintenance:** actively maintained community fork of
  id's 2005 GPL release.
- **Well:** the simplest working antilag in a shipped engine, and the clearest statement of the
  alternative v5 refuses. The server keeps a short per-client position history, time-shifts every
  other client back to **one** instant derived from the client's own command stamp, runs the trace,
  and shifts them forward again — with the shift **hard-clamped** server-side. Two things transfer:
  the clamp is the server's and never the client's, and **one instant is enough** when the server
  owns the trace.
- **Badly, and this is why its shape is not adopted:** the server re-runs the client's *command*,
  including the aim, so the client never names a hit at all. Roblox cannot replay a client command,
  and the aim already crosses our wire. It is also hitscan-only, and GPL-2.0 puts even its structure
  off limits as code.
- **Adopted:** nothing in code. One argument: **the clamp belongs to the server and the client never
  names the instant.** It is why `Weapon.viewWindowFor` has no client-supplied term and why
  `Validator.nearestInstant` is handed candidates the owner chose.

### I. **NEW in v5.** Mirror (Unity) — lag compensation over a bounded history

- <https://github.com/MirrorNetworking/Mirror>. **Licence: MIT.** **Maintenance:** actively
  maintained, the most used open-source networking library for Unity.
- **Well:** the one widely used OSS implementation of the thing check 5 is — a **bounded** ring of
  past bounds per object, a lookup by estimated client timestamp, and an **explicit tolerance** on
  the comparison rather than an exact match. It also keeps the history on the *object*, not on the
  weapon, which is the owner boundary §1.2 states.
- **Badly, for us:** C# and Unity colliders; it rewinds so the **server** can do a physics test
  (Source's shape), not so it can validate a claim the client already made; and its bounds are AABBs
  where ours is one `CFrame` plus a constant object-space offset.
- **Adopted:** the discipline of a **bounded** history plus an **explicit named tolerance** on the
  sample comparison, which is `bodyToleranceStuds`. **I could not verify its exact API names from
  this run** (no network access) and none is cited here; see 15.5.

### J. Borrowed from inside this repo (rule 2 applies to internal patterns too)

- **The injected provider.** `setTargetProvider`, `setStandProvider`, `setDriveOpenProvider`,
  `setSafetyLineProvider`, `setHistoryProvider` — each a `pcall`, each defaulting to the strongest
  answer (for the claim: refuse).
- **The injected cast.** `Weapon.setCast` / `Shotgun.CastFn`; **check 6 uses it rather than adding a
  second raycast door**, and `Claim.simulate` takes the same seam.
- **Pure core, impure owner.** `Pattern`, `Hits`, `SafetyArc`, `StateMachine`, `Validator`, `Limits`
  are pure and take `now` as a parameter. `Validator.nearestInstant` and `closestOnSegments` follow:
  the owner does the Instance work, the pure half does the arithmetic.
- **A number that can only be read at one value cannot be tested at another.** `Ballistics.dropAt`'s
  `g`, `Weapon.equipDelayFor`, `Validator.checkShot`'s fourth argument, `Weapon.catchUpFor`'s `ping`,
  `Weapon.setViewWindow` — and now `bodyToleranceStuds` as a fact rather than a config read (3.2).
- **The worst-case counter as the argument for a bound.** `stats.originFarthest` (task 260) →
  `claimBestProximityStuds`, `claimWorstPathStuds`.
- **A field that records only the survivors measures the filter, not the thing** — task 274's
  `claimLastPart`, which reversed what task 272 looked like. 4.9 applies it to the two new counters.
- **A mechanism that loosens a rule and moves no number is deleted** — task 269b's backward search,
  and task 271's own §1.2a item 15. 12.7 binds v5 to the same test in advance.
- **One cross-module invariant, asserted in one file.** `zz_horn.spec` holds three modules to one
  `METRES_PER_STUD`; `zz_claim_window.spec` holds the weapon's window inside the animal's memory.

### The pattern adopted

**Client-simulated projectile with a server-validated hit claim, judged by a rule set in which every
check is either exactly satisfiable by an honest client or budgeted against the animal's own
measured body, at one instant the server chooses from its own history inside a latency-clamped
window** — Epic's target-data division and its warning about client-supplied bounds (C), Valve's and
Gambetta's lag-compensation window reduced to one `CFrame` per animal (B, G), id Tech 3's
server-owned clamp (H), Mirror's bounded history with a named tolerance (I), FastCast's segment cast
as the one stepper both sides share (A), the engine's own descendant filter for the line-of-sight
cast (F), and VALORANT's contrary conclusion (D) named and refused for a stated reason — **with the
flight time, the drag, the drop, the zero and the pattern untouched, so the lead this whole system
exists to create is preserved.**

---

## 11. Numeric targets

### 11.1 Direction C — the four acceptance criteria, and the half `ballistics` is accountable for

| # | Criterion | The assertion | The instrument that reads it | Spec, or live only? |
|---|---|---|---|---|
| **C1** | honest claims accepted **≥ 95 %** on running animals at **20–60 m** | `claimsAccepted / (claimsAccepted + claimsRefused) ≥ 0.95` over a trial of ≥ 20 shots at animals moving at `TROT_SPEED` 18 to `SPRINT_SPEED` 38, at 71–214 studs, with `HIT_CLAIM` on | `Weapon.stats()` → `claims`, `claimsAccepted`, `claimsRefused`, `refusedClaimBy`, `refusedClaimWorst`, published as `ServerStorage.DHClaimStats` by `publishClaimStats` | **LIVE ONLY for the rate.** A spec can hold the *constructed* version — each check's stated honest worst case passes (12.1 case H) — but the RATE is a distribution and no spec produces latency: a loopback Studio session reads **1–2 ms of ping** (task 256 round 2) |
| **C2** | a forged claim refused | a claim whose point is 30 studs from the animal is refused `claim-moved` **at every instant in the full 0.45 s window**, with the margin asserted as a RATIO over the tolerance so it cannot pass by the tolerance being widened. One forged case per deleted check as well: a point off the box (`claim-offset`), a point off the claim's own path (`claim-line`), an inflated `distanceStuds` (`claim-path`), a point behind a wall (`claim-blocked`), a future arrival (`claim-future`) | `weapon_shot.spec`'s live forged cases through `onFireRequest`; `weapon_hits.spec`'s pure cases through `judgeClaim` | **SPEC.** Six cases, all driveable with an injected cast, an injected provider and hand-written numbers |
| **C3** | the vitals hit from **broadside, quartering and frontal** aspects | **`ballistics` is accountable for exactly one half: `refusedClaimBy` must be INDEPENDENT of the animal's aspect at the trigger.** The geometry half — that a frontal path reaches the heart and lungs at all — is `docs/design/hit-zones.md`'s and is stated there in degrees against task 276's measured 40–115° window | the aspect at the trigger, in the animal's own frame, beside each claim's verdict | **NEITHER, TODAY. THE INSTRUMENT DOES NOT EXIST**: 11.3 |
| **C4** | **the lead equals the bullet's flight time only** | with the claim path on and an injected cast: a shot led by exactly `Ballistics.leadStuds(v, range)` produces a claim naming the aimed zone at 71, 143 and 214 studs for `v` in {18, 28.7, 38}; a shot led by **2×** that produces none; a shot with **no** lead produces one only while `v × flight` is inside the body's own half-extent, and the crossover range is **reported by the spec, not hard-coded** | `tests/client/weapon_client.spec.luau` over `Claim.simulate` with a scripted world. The existing two-pass lead table (worst \|error\| 0.009 studs over twelve rows, task 270) is half of it already | **SPEC for the arithmetic; LIVE for whether it feels right.** 16.1 Karen 1 |

### 11.2 The rest

| Target | How it is measured |
|---|---|
| **`claimWorstPathStuds` under 0.10 studs across a live trial** | check 4's honest value is float noise (4.7). Anything near 0.50 means the two sides are not flying one line and the defect is 259b's, not the view lag's |
| **`claimBestProximityStuds` under 1.5 studs across a live trial** | check 5's honest worst case is about 1 stud (5.2). Against a 2.00–3.71 budget that is 2–3.7× of margin. **If it reads above the budget on honest claims the floor rises to the measured worst plus 50 %, one row, and the reason is written in advance** |
| **`claimWorstLagSeconds` lands in 0.10–0.30 s on a loopback session** | the measured view lag is 0.178–0.19 s. **Under 0.02 s means the window carried nothing and is deleted** (271 §1.2a item 15 still binds). At or above `window` with `claimSweepIndex == claimSweepFound` means `VIEW_LAG_BASE_SECONDS` is too small |
| **a STILL animal, 3 chest shots: chest hits, dust on the chest** | reads `SKIN_STUDS`, `CLAIM_LINE_STUDS` and the LOS cast. The window contributes nothing at `v = 0`, which is itself the check. Task 266b already met this (three of three `ZoneChest`) and it must not regress |
| **non-regression: `Weapon.setViewWindow(0)` collapses to the arrival instant alone** | one candidate, `nearestInstant` returns index 1, identical `judgeClaim` call. The dial that turns the window off without touching the flag |
| **the cost: ≤ 28 provider calls, ≤ 16 `Ballistics.advance` calls, ONE extra raycast, per CLAIMED shot** | single-pellet only, at most 6/s. `weapon_hits.spec` counts the injected provider's and the injected cast's calls and asserts both bounds. **The old cost — ≤ 448 point-to-segment projections — FALLS to ≤ 16**, because the path is walked once and `closestOnSegments` is called once, not once per candidate |
| **`Runtime:stats().historyMisses` rises by at most 1 per claimed shot** | the break rule (4.9). The exception 271 round-2 note 14 found survives: a down, dead or unknown animal answers nil at all 19 instants and books 19. Fixed by breaking on the FIRST nil when `#candidates == 0` and the reason is not `"no-sample"` — queued, not built (16.9) |
| **0 new remotes, 0 new rate-limited doors, 0 new payload fields, 0 new flags, 0 new raycast owners** | grep on `Shotgun.remotes` (six), on `HitClaim`'s six fields, on `Flags.MAX_FLAGS` (18), and on `Workspace:Raycast` under `src/server/Weapon/` (one, in `Cast.luau`) |
| **the OFF state is bit-for-bit today's game** | `HIT_CLAIM = false` → `claimsIgnored` rises and nothing else moves |
| the flight time, the drop, the zero, the pattern, `GRAVITY_SCALE` | **unchanged**; `ballistics.spec` cases 1–9 untouched |

### 11.3 The instrument C3 needs and does not have

Task 276a(a) measured it: **1–2 seconds pass between the instrument's chest-gate reading and the
real focused click** (MCP round trips plus `park`/`click`), and a deer at 28 studs/s covers 30–60
studs and turns in that time — **6 of 10 shots were tail-on at the trigger although all 10 passed a
chest gate.** So no trial driven from outside the game loop can hold an aspect, and C3 cannot be
read today, by a spec or by a live run.

**What it would take, as two options, neither built by this task:**

1. **A trigger inside the frame that reads the gate.** A Studio-only client module under the Forest
   Test seam that, each `RenderStepped`, computes the aspect of the tracked animal in its own frame
   and calls `Input.fire` in the **same frame** the aspect enters the asked-for band. That removes
   the round trip entirely. It is a new instrument, it lives outside `src/` only if the Forest Test
   can host it, and it needs its own task.
2. **A slower animal.** Stage the release at `Boar.CONFIG.PACE.TROT_SPEED` 11 or `WALK_SPEED` 4.5
   instead of `SPRINT_SPEED` 38 — the gate-to-trigger travel falls by 3.5× to 8.4×, from 30–60 studs
   to 4–17, which is inside the aspect band. Cheaper, available today through `DHTestRelease`, and
   it changes what is being measured (a walking animal is not the shot Karen is complaining about).

**My reading: do (2) first to get a number at all, then (1) to get the number C3 actually asks
for.** Either way, **C3 is not a merge gate for the build task**; it is an acceptance criterion the
Director reads after.

---

## 12. How it is tested

### 12.1 `tests/server/weapon_hits.spec.luau` — pure, over the injected cast, provider and `dt`

Case 24's twelve `judgeClaim` boundary assertions **must be rewritten**, because five of the facts
they drive no longer exist. That is the honest cost of the rule change and it is stated rather than
hidden: the proof is no longer *"`judgeClaim` did not change"*, it is *"every check is driven on both
sides".*

- **A. Check 3 both sides.** An offset on the box, an offset one skin over, an offset one skin under.
- **B. Check 4 both sides, both halves.** A point on the claim's own path (`pathStuds` ≈ 0 → pass);
  a point 0.51 studs off it → `claim-line`; a `distanceStuds` 1.01 studs from `pathAlongStuds` →
  `claim-path`. The budget is read from `limits`, never a literal.
- **C. `Validator.nearestInstant`, every rule.** Hand-written candidates, no world: the newest wins
  when it is nearest; an **older** candidate wins when it is nearer — the whole point; the minimum
  is returned alongside the index; an empty list returns `(nil, nil)` and does not error; the
  function makes exactly one pass and no `limits` are consulted.
- **D. Check 5 both sides, per kind.** A proximity of `bodyTolerance − 0.01` passes and
  `bodyTolerance + 0.01` refuses `claim-moved`, driven **for each of the seven tolerances in 3.2**,
  read from `Boar.CONFIG` rather than typed again. Plus the floor: a cub's and a calf's tolerance IS
  `BODY_TOLERANCE_MIN_STUDS`, so the floor is reachable and not decorative.
- **E. Check 6 both sides.** `losReach = losTarget` passes; `losReach = losTarget − 0.49` passes;
  `losReach = losTarget − 0.51` refuses `claim-blocked`. Driven as two numbers, with no cast.
- **F. Check 6's exclude list, through the owner, with an injected cast.** The cast is handed a list
  and the case asserts that the list **contains the claimed target** and the shooter's ignore list.
  **Deleting `table.insert(ignore, target)` must red this case** — the self-block fault
  (269b, 273a(b), 274a(b)) is exactly what that one line removes.
- **G. Check 7 both sides.** Unchanged: the age floor, the age ceiling, the flight tolerance.
- **H. THE HONEST WORST CASE PASSES, AS ONE CASE** (direction A's own demand, and C1's constructible
  half). Every check at its stated honest worst simultaneously: `pathStuds = 0.027` (task 266b's
  measurement), `proximityStuds = 1.0`, `losReach = losTarget − 0.4`, `age = +0.075`, offset at the
  box surface. **The claim is ACCEPTED.** If any budget is later tightened below its honest worst,
  this case reds.
- **I. `Validator.closestOnSegments` is unchanged**, re-asserted against 2 000 random
  (polyline, point) pairs to 1e-9. It is the only piece of arithmetic carried across from v4.
- **J. `Weapon.viewWindowFor`.** `nil`, negative, NaN and absent pings contribute zero; a 0.08 s ping
  gives `BASE + 0.08`; a 1.0 s ping clamps at `VIEW_LAG_MAX_SECONDS`; `setViewWindow` overrides and
  `setViewWindow(nil)` restores. **271 round-1 finding 1 said this function had ZERO cases and the
  seam was dead production API; that must not ship twice.**
- **K. The sweep's housekeeping.** A provider answering nil for the first candidate and a CFrame for
  the second does **not** end the sweep; nil after a CFrame **does**; `claimHistoryWhy` is written
  **only** when every candidate answered nil; the provider is called at most `VIEW_LAG_MAX_SAMPLES`
  times.
- **L. The degenerate claim.** `claim.flightSeconds == 0` → the path is empty. **271 round-2 note 13
  measured that this refuses `claim-history` with no number** under v4. Under v5 it must refuse
  `claim-time` (a zero flight cannot match any `timeToRange` for a positive distance), which is the
  cause rather than a symptom. Asserted.

### 12.2 `tests/server/weapon_shot.spec.luau` — the LIVE cases, on the player's path

These are the cases that matter, because **271 round-1 finding 1 proved that the whole sweep could
be deleted with the suite green.** Each case below must red when its line is deleted, and the
request must say which line it deleted to prove it.

- **The live ACCEPT at lag.** `setClaimPolicy(true)`, a scripted cast, a history provider that
  ANSWERS `at` (`zone.CFrame * CFrame.new(travel * (at − now))`), the weapon loaded through
  `refillForDrive` plus a real Reload (269b's escape), and a hand-built claim whose point is where
  that part was **0.18 s before** `arrivalAt`. → the shot is taken, `claimsAccepted` moves by one,
  `HitReported` fires once with the claimed part, `claimWorstLagSeconds` is within one grid step of
  0.18, and `claimBestProximityStuds` is under 0.1.
- **The live non-regression.** The same claim with `Weapon.setViewWindow(0)` → refused
  `claim-moved`, with `claimBestProximityStuds` ≈ `v × 0.18` = 5.2 studs, and the impacts identical
  to the same shot with no claim at all. **The two cases together are the whole of v5 through the
  real handler, with no world and no second player.** **272a(b) is fixed here**: task 272's window-0
  case was written to refuse and ACCEPTED (`best 1@0.550`), so it proved the sweep ran and not that
  it changed a verdict. This pair does, because the two verdicts differ.
- **The live LOS refusal.** The same accepted claim with the injected cast returning a block at
  60 % of `losTargetStuds` → refused `claim-blocked`, note names the blocker's `GetFullName()`.
- **The live SELF-BLOCK non-refusal.** The injected cast returns a hit on **the claimed animal's own
  zone part** → the cast never sees it, because the exclude list contains the target, so the claim
  is **accepted**. This is 274a(b)'s 7.275-stud refusal, turned into a case.
- **The live forged claim.** 30 studs off → refused `claim-moved` at the full 0.45 window, the margin
  asserted as a ratio.
- **The OFF-state case.** Unchanged.
- **`Weapon.claimLine`'s string.** Every counter it prints is asserted, including the two new ones.
  271 round-2 note 16 found `lag=%.3fs` shipped with no assertion at all.

### 12.3 `tests/server/zz_claim_window.spec.luau` — the cross-owner invariant, re-derived

Two of its four assertions name rows that v5 deletes and must be rewritten, not merely edited:

- **kept:** `HISTORY.SAMPLES / 60 >= AGE_MAX_SECONDS + VIEW_LAG_MAX_SECONDS + 1/60`, and the
  `span / window >= 1.5` margin (1.655 today);
- **kept:** `VIEW_LAG_MAX_SAMPLES >= VIEW_LAG_MAX_SECONDS / VIEW_LAG_STEP_SECONDS + 1`;
- **added, and 271 round-2 note 17 says they were specified and not built:**
  `VIEW_LAG_BASE_SECONDS <= VIEW_LAG_MAX_SECONDS` and `VIEW_LAG_STEP_SECONDS <= 1/60`;
- **replaces** *"the line tolerance is under half a boar's own body"* (`LINE_TOLERANCE_STUDS <
  BODY_SIZE.Z/2`) with **`CLAIM_LINE_STUDS < BODY_TOLERANCE_MIN_STUDS`** — the self-consistency
  budget must be far under the positional one, or the two checks stop being different questions;
- **replaces** *"the position tolerance is about one body, not two"* with the body rule itself:
  **for every kind in `Boar.CONFIG.KINDS.ORDER`, `BODY_TOLERANCE_FACTOR × trunkLength(kind)` floored
  at `BODY_TOLERANCE_MIN_STUDS` is at least `BODY_TOLERANCE_MIN_STUDS` and at most one trunk
  length.** It walks `ORDER`, so a new kind with no box fails here.
- **added:** `MAX_SUBSTEPS × FLIGHT_STEP_MAX_SECONDS > timeToRange(rifle, 800)` — kept from today.
- **added:** `LOS_SLACK_STUDS < BODY_TOLERANCE_MIN_STUDS` — a line-of-sight slack wider than the
  positional budget would let a claim through a wall it is standing against.

### 12.4 `tests/server/boar_history.spec.luau` — unchanged in substance

`Boar.sampleAt` interpolates between bracketing samples and is exact at a sample; it **refuses**
outside the span and never extrapolates; the ring wraps and never grows past `HISTORY.SAMPLES`; the
rewound part CFrame is the trunk's rewound CFrame times the part's constant trunk-space offset; a
down, dead or unknown animal answers nil. **The ring-length assertions must read `HISTORY.SAMPLES`
rather than the literal `1.6`** — 271 round-2 note 17 found the literal `1.0667` had simply been
edited to `1.6`, which is the same defect one commit later.

### 12.5 `tests/server/ballistics.spec.luau` — unchanged by v5

Cases 1–9 and the task-266 `Ballistics.segment` cases stay as they are. v5 touches no function here.

### 12.6 `tests/client/weapon_client.spec.luau` — direction C4, and the reason split

- **C4's table**, 11.1. Three speeds × three ranges, led / double-led / unled, with the crossover
  range **reported by the spec**.
- **The reason split (5.7).** A target impact with a nearer static impact answers `"blocked"`; no
  target impact at all with a static one answers `"no-intersect"`; the string `"static-blocked"`
  appears nowhere in `src/` after this task. **`tests/client/weapon_client.spec.luau` and
  `src/client/Weapon/Claim.luau` are the only two files that mention it today.**
- **The coarse gate (16.2).** With the animal's half-extent along `v` set to `v × FLIGHT_STEP_MAX_SECONDS`
  exactly, the coarse pass is on the boundary; with the midpoint first guess it is inside by 2×.
- The cast count stays under `MAX_TARGETS × MAX_SUBSTEPS × 2`.
- The grep claim: `Workspace:Raycast` under `src/client/Weapon/` appears only in `Claim.luau`.
  (`src/client/Camera/Rig.luau` casts too, for occlusion — a different question with a different
  owner, named so the claim is honest.)

### 12.7 The delete-or-keep test, binding in advance

271's §1.2a item 15 bound the sweep to a standard and it is kept: **if `claimWorstLagSeconds` reads
under 0.02 s across a live trial, the window carried nothing and the sweep is deleted**, with
`VIEW_LAG_*` and the ring's extra 32 samples going with it. v5 adds a second: **if
`claimBestProximityStuds` and `claimWorstPathStuds` are both under 0.5 studs while `claimsRefused`
is non-zero, the refusing check is not in this rule set** and the next task looks at the client's
own simulation, not at the validator.

### 12.8 Harness input, screenshots, and what cannot be tested

- **Harness input** (`tests/client/input_scenarios.txt`) can replay the click and stage the
  character. It **cannot** aim at a moving animal on a schedule and cannot express "lead this target
  by this much" (the `tools/studio_mcp.py` docstring; TASKS.md Tasks 6–7), so every lead is computed
  **in the spec**. **No new harness capability is needed for the build and none is claimed.** The
  instrument C3 needs is a different thing and is 11.3.
- **The harness cannot produce latency or clock skew.** A loopback Studio session reads 1–2 ms of
  ping, so the *magnitude* of the view lag cannot be exercised by the gate at all — only by Karen's
  own session, which is where 0.178 s came from. Everything about the mechanism is proved by
  **injected** times, pings, casts and positions in the pure specs, and only *bounded* in the live
  ones. **This is the single biggest limitation of this design's evidence.**
- **Screenshot (rule 5): required.** One capture of a slug hit on a running animal with the override
  on, inspected, showing the dust on the zone the card names. **And it must be read with 16.6 in
  hand**: the mark is drawn a body length behind the zone it names today, so a frame showing the
  mark behind the chest is evidence of the DRAWING defect and not of this rule set.
- **What cannot be tested at all, said plainly:** whether the shot now *feels* right, and whether
  `GetServerTimeNow()` is tight between a real client and a real server. Both are section 15.

---

## 13. The harness, the gate, and the build order

### 13.1 `tools/studio_mcp.py` — no change

`BLAST_RADIUS` already maps every file v5 touches: `src/shared/Shotgun/` → `gun`,
`src/server/Weapon` → `weapon`, `src/client/Weapon` → `weapon`. `SCOPE_SPECS` already holds every
spec file named above. **No new spec FILE, so no new row, and `selftest` cannot fail on this task.**
If the Builder decides to add a spec file anyway, `SCOPE_SPECS` needs the row in the same commit or
`selftest` fails — which is the system working.

### 13.2 Which gate — `test2` is N/A

**Not one file in 2.1 is in `TWO_PLAYER_PATHS`** (`tools/agents.py`): no `src/server/Match/`, no
`MatchBoot`, no `src/client/Match/`, no `src/shared/Drive/`, no `tests/client/Role.luau`, none of the
named specs. CLAUDE.md, "Run / test": *weapon, viewmodel, camera, boar, hud, sound and tools need the
one-player line only, for the PR to `main` as well.*

```
[harness] PASS: n/n checks @ <code commit> (clean tree) scope=all      <- the PR to main
```

A review round may use `scope=auto:gun,weapon`. **The Builder must not paste a `[harness2]` line and
must mark that box N/A with this reason.**

### 13.3 CARRY FORWARD, NOT ABSORB — the grep the build task owes (BRIEF item 13)

`claim-line` changes meaning and `LINE_TOLERANCE_STUDS`, `POSITION_TOLERANCE_STUDS` and
`REACH_SLACK_STUDS` cease to exist. **Before the first behaviour change, the build task greps every
one of them and lists what it found.** Measured at `a3b6663e`, 88 occurrences across eight files:

| file | what is there | what it becomes |
|---|---|---|
| `src/server/Weapon/Validator.luau` (15) | `judgeClaim`'s checks 3–5 and their comments | rewritten (4.3) |
| `src/shared/Shotgun/init.luau` (6) | the three deleted rows and their headers | 3.1 |
| `src/server/Weapon/init.luau` (8) | `judgeClaimFor`'s facts, the note branch, the counters | 4.9 |
| `tests/server/weapon_shot.spec.luau` (47) | the live cases | 12.2 |
| `tests/server/weapon_hits.spec.luau` (7) | case 24's boundaries | 12.1 |
| `tests/server/zz_claim_window.spec.luau` (3) | two assertions that name deleted rows | 12.3 |
| `src/client/Weapon/Claim.luau` (1) | a comment naming check 4 as what stops a mispredicted claim | **now check 5** |
| `tests/client/weapon_client.spec.luau` (1) | a comment | 12.6 |

**This design-only task does not do it.** It is step 0 of the build.

### 13.4 Build order — three commits, each green on its own

CLAUDE.md rule 4 is one task per round; this splits inside one task and **every step before the last
is invisible with the flag off.**

0. **The grep and the archive.** 13.3's list, plus `backups/design-ballistics-v4.md` with its
   one-line note (rule 7, the header of this file).
1. **The rows and the pure half.** `CONFIG.CLAIM`'s five in and three out;
   `Validator.nearestInstant` replacing `pickViewInstant`; `judgeClaim` rewritten; the
   `zz_claim_window` invariant re-derived; `weapon_hits.spec` cases A–E, G, I–L. **Nothing calls the
   new `judgeClaim` with the new facts yet, so the game does not move.**
2. **The owner.** `judgeClaimFor`'s rewrite: the path walk, the existential, the LOS cast, the
   exclude list, the two new counters, the dead `reason == "moved"` fixed, the old counters removed.
   `weapon_hits.spec` case F and H; all of `weapon_shot.spec` 12.2.
3. **The client's reasons and the coarse gate.** `Claim.simulate`'s declared second return, the
   `"blocked"` / `"no-intersect"` split, the midpoint first guess; `weapon_client.spec` 12.6
   including C4's table. Then the Director's acceptance run with the override on, then Karen.

Step 3 touches `src/client/Weapon/` and steps 1–2 do not, so the scopes differ; all three resolve
inside `gun` and `weapon`.

---

## 14. The delta to `docs/design/shotgun.md` and `GAME_DESIGN.md`

| `shotgun.md` | What v5 changes |
|---|---|
| **§3.1 The one server owner** | `Weapon.Validator` keeps `closestOnSegments` and `claimImpact`, loses `pickViewInstant` and gains `nearestInstant`, and is **still the one place a payload is judged**. `Weapon` keeps `viewWindowFor` and `setViewWindow`. **No new provider and no new raycast owner** — check 6 goes through `setCast`'s existing seam |
| **§5.1 Shared types** | **no change.** `HitClaim` keeps its six fields |
| **§5.3 The pure core** | `judgeClaim` is rewritten; the division is unchanged — the pure half judges the numbers, the owner does the Instance reads and the one cast |
| **§5.5 The shot, step by step** | step 7 is the rule set of 5.2. The order is otherwise unchanged |
| **§5.7 "The client never names a target, and never casts"** | already REVERSED in v3. v5 adds one sentence and it is a weakening, said plainly: **`req.direction` is unbounded, so the geometric check that claimed to stop "a hit on an animal the bullet passed beside" never did, and v5 deletes it rather than keep the claim.** The enumerated cost is 5.9 |
| **§11 Numeric targets — the one config table** | `CONFIG.CLAIM` gains `CLAIM_LINE_STUDS`, `CLAIM_PATH_TOLERANCE_STUDS`, `BODY_TOLERANCE_FACTOR`, `BODY_TOLERANCE_MIN_STUDS`, `LOS_SLACK_STUDS`; loses `LINE_TOLERANCE_STUDS`, `POSITION_TOLERANCE_STUDS`, `REACH_SLACK_STUDS`. The four `VIEW_LAG_*` rows are unchanged |
| **§11.1 Lag** | item (4) reads: *the claim and the rewind, bounded, tasks 266, 271 and 277 — judged at one instant the server chooses inside a latency-clamped window, with the positional budget derived from the animal's own trunk.* The task-256 forward prediction is not replaced; their interaction is a named open risk (5.2 check 7) |
| **§13.1 / §13.2 specs** | the cases in 12.1–12.6 |
| **§15 Open decisions** | gains section 16 below |

**`GAME_DESIGN.md` rows:**

- **the weapon row (41), amended:** *"…and `ServerScriptService.Weapon` validates it against the
  Boar's position history before it becomes the shot's one impact. **Since task 277 the rule set is
  seven checks, each named for the cheat it stops: an honest claim passes by construction, and the
  positional budget is the claimed animal's own trunk (2.00–3.71 studs by kind) at one instant the
  server picks from its own history inside a latency-clamped window. The line of sight is a real
  cast from the muzzle, excluding the claimed animal itself.** A refused claim is logged and the
  shot resolves from the server's own flight. Buckshot carries no claim. Behind `HIT_CLAIM`, born
  off."*
- **the shotgun-numbers row (44), amended:** `Shotgun.CONFIG.CLAIM`'s rows per 3.1; still six
  RemoteEvents.
- **"Where an animal WAS" (task 266):** unchanged.
- **the "client's claim" row (task 266):** unchanged.

---

## 15. What I could not verify (rule 8)

1. **THE SHARED CLOCK, first and loudest.** I cannot establish how tightly
   `Workspace:GetServerTimeNow()` agrees between a client and a server. Task 265 measured a ~0.17 s
   client/server position offset and **could not establish it** — the only control was a motionless
   part, which reads 0.000 under any clock skew (`ESCALATE.md`, 2026-10-25). If some of the measured
   0.19 s is clock skew rather than view lag, the window is compensating for a clock error by looking
   at an older picture, which is wrong in principle and right in effect. **No counter in this design
   can tell the two apart.** The experiment that could is a client and a server reporting
   `GetServerTimeNow()` for the same `Heartbeat`; nobody has run it. 16.3 Director 4.

2. **THE "~5 STUDS BEHIND" AND THE MARK DEFECT MAY BE THE SAME 5 STUDS, MEASURED TWICE.** The BRIEF's
   MEASURED NOW 1 reports the impact landing −3.6 to −7.1 studs along the animal's velocity, and
   276a(c) reports the drawn mark sitting **5.033 studs** behind the zone it names because
   `Effects.puff` converts the world point with the part's **current** CFrame. Those are the same
   magnitude and the same sign. **Nothing in the ledgers separates them**, and I did not read the
   instrument (it lives in `<runs-dir>/`, outside the repo). **The probe that settles it:** compare
   the impact's world point against the claimed part's CFrame **as it was at the resolution instant**
   (`candidates[1]`'s rewind), not as it is when the listener reads it — if the gap collapses, the
   5 studs is an instrument and a drawing defect, and this design's premise about the view lag's
   *magnitude* needs re-measuring before `VIEW_LAG_BASE_SECONDS = 0.30` is defended. **The design
   does not depend on the magnitude** — the window is a server-owned bound, and `claimWorstLagSeconds`
   argues it down from evidence — but the acceptance run does.

3. **WHETHER `Places.unblockFoliage` HAS RUN IN THE SESSION KAREN PLAYS.** Check 6 depends on it
   (5.6 item 3). I verified the function, its measured justification and its call site
   (`Places.foliageRoots(root)` inside the planting path), but **not that the planting path runs in
   the Forest Test session** — and the sweep is the only thing that stops a colliding `Branch` from
   refusing an honest claim, because `CanQuery = false` demonstrably does not. **The probe:** read
   `report.unblocked` in the live session; a 0 in Karen's wood means 623 foliage parts and 127
   colliding branches are still blocking and check 6 will refuse honest shots at animals behind
   leaves. **If it has not run, the build task must not ship check 6 without it.**

4. **I HAVE NOT MEASURED CHECK 5's QUANTITY.** `proximityStuds` — the minimum over the window of
   `|rewound(t)·offset − claim.point|` — has never been published by any build. My honest worst case
   (about 1 stud, 5.2) is arithmetic over four named terms, not a reading. The budget's floor is set
   at 2.0 and the per-kind values run to 3.71, which is 2–3.7× that arithmetic, and
   `claimBestProximityStuds` ships with the check precisely so the first live trial argues it.
   **If the first trial reads above the budget on honest claims, the floor rises to the measured
   worst plus 50 % — one row, decided in advance, not another task.**

5. **TWO OF THE TEN SOURCES ARE CITED AT A LEVEL I COULD NOT CHECK FROM THIS RUN.** This session has
   no network access. The FastCast, Valve, Epic, Riot, Fiedler, Roblox and Gambetta entries carry
   forward from v4 with their licences and maintenance as recorded there. **ioquake3 (H)** and
   **Mirror (I)** are new in v5: I am confident of each project's identity, repository and licence
   (GPL-2.0 and MIT), and I have deliberately **named no API, no file and no function** in either —
   what is adopted from each is an argument, not an interface. A reader who wants the API names must
   open the repositories.

6. **ROBLOX STUDIO IS NOT AVAILABLE TO THIS RUN** (`.agent-evidence/INDEX.md`). **No number in this
   file was measured by me.** 0.178 s, 0.19 s, 28.7 studs/s, 5.120, 5.457/2.000, 4.09/2.00,
   2.137/1.000, 4.105/3.40, 7.275/3.40, 0.027, `sweep=19/19 win=0.301s spread=8.046`, `took == best`,
   6-of-10 tail-on and 5.033 are all read off `TASKS.md` rows 265–276a and
   `reviews/task-271/{BRIEF,RESULT}.md`. The box sizes, scales, config values and code behaviours are
   read off the files named beside them at `a3b6663e`. Every derived number (the lead table, the
   flight times, the seven tolerances, the grid's 0.63) is arithmetic over those, shown rather than
   asserted.

7. **I DID NOT RE-READ `Flight.advance`, `Hits.group`, `Runtime:step` OR `Pattern.directions` LINE BY
   LINE.** I read `Validator` in full, `judgeClaimFor` and `viewWindowFor` in full,
   `src/client/Weapon/Claim.luau` in full, `Cast.world`, `Hits.targetOf`, `Boar.Body.buildZones` and
   `Body.create`, `Boar.CONFIG.ZONES` / `SPECIES.reddeer.ZONES` / `KINDS`, `Shotgun.CONFIG.CLAIM`,
   `Places.unblockFoliage`, `Effects.puff` and `zz_claim_window.spec`. Statements about the other
   four are carried from v4 and from their symbol names.

8. **271 ROUND-1 FINDING 1 IS THE RISK THIS DESIGN CARRIES INTO THE BUILD.** The Reviewer proved that
   v4's entire behaviour change could be deleted with the suite green. v5 adds more owner-side code
   than v4 did (the path walk, the LOS cast, the exclude list). **I cannot test, so 12.2's "each case
   must red when its line is deleted" is an instruction, not a verification**, and the review request
   must name which line it deleted for each.

---

## 16. Open decisions, and every carried item placed

### 16.1 For Karen — feel. **None blocks building.**

1. **Does the shot land where she aimed?** The question this system exists for, on its seventh
   attempt. `python tools/flags.py set HIT_CLAIM on`, play, then read `Weapon.stats()`:
   `claimsAccepted` against `claimsRefused`, `refusedClaimBy`, `claimBestProximityStuds`,
   `claimWorstPathStuds`, `claimWorstLagSeconds`. *"It still feels behind"* and *"sometimes it does
   not register"* are **different** answers with different dials: the first is the client's own
   simulation or the drawing (16.6), the second is the window or the clock.
2. **Does free zone selection matter to her?** 5.9 says a modified client can claim any zone of an
   animal it genuinely engaged. The game is co-operative PvE and this design treats that as
   acceptable (source D). **It is her game.** If she wants it closed, the answer is a smaller window,
   which costs honest high-ping players hits — the trade, not a bug.
3. **Close shots on fast animals, and buckshot.** Unchanged. If buckshot specifically feels off on
   running animals, the honest knob is `DRAG_PER_STUD.Buck`, **not** nine claimed pellets.

### 16.2 For the Director — scope. **None blocks building.**

1. **`VIEW_LAG_BASE_SECONDS = 0.30` is still the one invented number**, and 15.2 says its justifying
   measurement may be confounded with a drawing defect. Argue it down from `claimWorstLagSeconds`
   after one real session, and re-measure the view lag against the resolution-instant CFrame first.
2. **`claim-future` on a real connection.** `Weapon.catchUpFor` resolves early on purpose, so `age`
   is expected to go negative. The condition (`claimAgeMin < 0` with a non-zero
   `refusedClaimBy["claim-future"]`) and the one-line fix (`claim-early`, floored at
   `−FLIGHT_CATCHUP_MAX_SECONDS`) are written in 5.2 check 7. **A task when the reading appears, not
   before.**
3. **A per-player window**, clamped to that player's own recent median lag plus slack, instead of one
   constant for everybody. It would make a low-ping cheater's licence smaller than a high-ping honest
   player's, which is the correct shape. It needs per-player state in the weapon; this design
   declines to add it.
4. **The clock experiment** (15.1). Worth a task of its own; it does not block this one, because the
   window is right for view lag and harmless for skew.
5. **The instrument C3 needs** (11.3), as its own task. My reading: take the cheap option first (a
   walking animal) to get any aspect-resolved number at all, then build the in-frame trigger.
6. **When to flip `HIT_CLAIM`'s default.** Born off, `expires = "2026-11-15"`. Karen's OK is a
   three-line commit; a refusal retires the row and archives the claim path under `backups/` (rule 7).
7. **`Match.CONFIG.SAFETY_RANGE_STUDS` is still 330 while the rifle reaches 800** (TASKS.md 183a,
   still open). Untouched again, for the same reason: `src/server/Match/` is a `TWO_PLAYER_PATH`.

### 16.3 Carried from the 265–276 run — every item placed, none dropped (BRIEF item 14)

| item | what it is | **placed where** |
|---|---|---|
| **269a(b)** | the client builds no claim when the snapshot's chamber reads empty (`Claim.forCamera` → `"no-ammo"`), so a hunter who fires without the snapshot having caught up silently gets the server's own resolution | **PLACED, build step 3.** The owner is `PlayerScripts.Weapon.Claim` → `Claim.forCamera`. The ammo is read **only** to pick the ballistic row and to refuse a pattern, and **the server re-checks both off its own row** (`Validator.checkClaim`'s `pellets`, and check 7's `timeToRange`). So the client may fall back to the **last chamber kind it saw** instead of refusing: a wrong guess can only produce a claim the server refuses on its own data. One client case: a nil snapshot after a Reload still builds a claim, and a pattern load still does not |
| **270a(a)** | the coarse pass's gate: the first cast uses `velocity × pellet.elapsed`, so a correctly led shot can be gated out before the refinement | **PLACED, build step 3, with the arithmetic.** The error is bounded by `v × FLIGHT_STEP_MAX_SECONDS` = **1.27 studs at `SPRINT_SPEED` 38** — not by the whole lead, which is what 270's own note implied. Against the smallest trunk half-length in the game (**cub, 1.24 studs**) it bites **exactly**, and against every other kind it does not. The fix is one expression: the first guess becomes the sub-step's **midpoint**, `elapsed + (length/2)/speed`, which halves it to 0.63 |
| **271 round-1 finding 5** | `claimWorstEndStuds` and `claimWorstLineStuds` are now **identically the same expression**, and the along-track instrument is gone | **RESOLVED BY DELETION, build step 2.** Both counters measure old check 4 and go with it (4.4) |
| **271 round-1 finding 6** | `claimLagAtEdge` and `claimViewWindowMax` were specified by v4 and never built | **WITHDRAWN AS NAMES, build step 2.** Task 272 shipped `claimSweepIndex`, `claimSweepFound` and `claimSweepWindow`, which answer the same two questions (`atEdge` is `claimSweepIndex == claimSweepFound`). Two names for one reading is the failure this project is named after. Grep confirms neither name exists in `src/` at `a3b6663e` |
| **271 round-1 finding 7** | `if reason == "claim-line" or reason == "moved"` — `judgeClaim` never returns `"moved"`, so the only refusal the fallback was written to explain carries a nil note. **Still unfixed at `a3b6663e`** | **PLACED, build step 2.** `"claim-moved"`. One word |
| **272a(b)** | the window-0 half of the owner case was written to refuse and ACCEPTS, so the case proves the sweep RUNS but not that it changes a verdict | **PLACED, build step 2** — 12.2's accept/refuse pair is written so the two verdicts differ, and the case names which line it deleted to prove it |
| **273a(b), 274a(b)** | `claim-blocked` at 4.105 and at **7.275** against a 3.40 bound, stopped by the claimed animal's own chest zone | **RESOLVED BY DELETION, build step 2.** The reach rule and the entire waiver go; the LOS cast excludes the claimed animal, so the case cannot arise (5.6). `weapon_shot.spec`'s live self-block case is 12.2 |
| **275a(c)** | `static-blocked` is the commonest no-claim cause | **REFUTED AS A READING, 5.7, and placed as build step 3.** The string is returned for a plain miss. The split into `"blocked"` / `"no-intersect"` is what makes the next trial answer the question |
| **275a(a)** | a shooter who also leads applies the compensation twice | **REFUTED, 5.5, with the arithmetic.** 276 already withdrew the 0/5-vs-2/5 signal as sampling. Nothing is removed and nobody owns a removal |
| **276a(c)** | **the mark is drawn a body length behind the zone it names** — `Effects.puff` converts the hit's world position with the part's CURRENT CFrame and then locks the emitter to the part, so it is off by the animal's travel (5.033 studs, measured) | **NAMED, NOT FOLDED IN, as the BRIEF instructs.** Owner: **`PlayerScripts.Weapon.Effects` → `puff`**, at `attachment.CFrame = attachTo.CFrame:ToObjectSpace(frame)`. It is a **client drawing defect, not a validation one**, and it needs its own task: either carry the hit CFrame on `ShotLanded` and convert with that, or draw the card's zone from the point. **It also confounds the measurement this whole run rests on** — 15.2 |
| **276a(d)** | *is a head-on chest shot supposed to read `body`?* | **DIRECTION B's**, answered in `docs/design/hit-zones.md`. `ballistics` is accountable only for C3's other half: the accept rate must not depend on aspect (11.1) |
| **271 round-2 note 13** | `claim.flightSeconds == 0` refuses `claim-history` with no number | **PLACED, 12.1 case L.** Under v5 it refuses `claim-time`, which is the cause |
| **271 round-2 note 14** | a down, dead or unknown animal books up to 19 `historyMisses` and 19 ancestor walks instead of 1 | **QUEUED, not built.** The fix is to break on the FIRST nil when `#candidates == 0` and the reason is `"no-sample"` rather than a provider error. One `if`; it changes no verdict, only a counter's meaning. TASKS.md, before release |
| **271 round-2 note 15** | on the no-candidate path the published reason is the OLDEST instant's, not the arrival instant's | **QUEUED, not built.** Same string in every case anyone has constructed; worth one comment |
| **271 round-2 note 18** | the refusal note reads `part.AssemblyLinearVelocity`, which is the weapon asking where an animal is **now** | **PLACED, build step 2.** The note takes the travel from the sweep's own two rewinds instead (9.1) |
| **271 round-2 note 19** | `viewWindowFor` is inserted between `catchUpFor` and `catchUpFor`'s own header, so the task-256 doc block reads as the wrong function's preamble | **PLACED, build step 2.** Move the header back |
| **271 round-2 note 21** | *"v4 is a strict superset of v3, asserted"* overstated the case; the 200 randomised sets never shipped | **MOOT.** v5 is **not** a superset of v4 and does not claim to be: it deletes a check. 12.1 case H is the property that replaces the claim — the honest worst case is accepted, driven, on one case |

---

**What this document is accountable for, in one sentence:** that an honest client's claim passes,
that each refusal names a cheat, that one instant serves both checks that need one, and that the
lead a player must hold is the bullet's flight time and nothing else. **The zones it lands in are
`docs/design/hit-zones.md`'s.**

# Design: boar-behaviour (Task 118)

System: `boar-behaviour` — **when a boar leaves being calm, what it does about it, and how that spreads
through a sounder.** Karen's scene, in states: calm → alert → spooked → the approach to the line →
the reaction to a hunter who moves → sprint at a shot → wounded/crippled/down as today.

Input: `reviews/task-118/BRIEF.md` (the Director, carrying Karen, 2026-10-03). That brief overrides
`docs/design/boar-ai.md` where they disagree, and this design is written to it.

Written against commit `ea28152e3d222d9cdf5e93bad25192a710a1c269` (`.agent-evidence/INDEX.md`).
Read-only session: Read, Grep, Glob. No Studio, no network. See **§16 Not verified**.

**Task 117 (the calm boar) is NOT in this worktree.** `reviews/` holds task-111…116 and task-118;
there is no `reviews/task-117/`, and no `graze`/`root`/`smell` row exists in `Boar.CONFIG.MODEL.CLIPS`
(`src/server/Boar/init.luau`, `BOAR_CLIPS`). So this design is written against the merged code and is
built so that nothing in it depends on 117's internals: 117 owns **what IDLE draws and does**, 118 owns
**when IDLE is left** (brief decision 4). Every point where the two meet is a config **string** or a
config **number**, never a code path (§3.6, §7.4).

---

## 1. What it must do

1. **Notice.** A calm boar notices a standing person at ~25 studs and a moving person at ~60 studs
   (brief decision 1, Karen: "agree"). One function answers "what can this boar perceive, and how
   close is it", for people now and dogs later.
2. **Go alert.** Head up, stop, turn to face the cause, hold it for a couple of seconds, then settle.
   That is Karen's "it can be they relaxed if hunter doesnt move".
3. **React when the cause moves.** "once move it start to run or turn around and go another
   direction": inside the close band it runs (today's FLEE, unchanged); in the outer band it **turns
   away and trots off** on a new heading — a new state, because "away from the man" and "toward the
   exit line" are different destinations.
4. **Flush.** A dog, a driver or anyone close enough spooks it into today's FLEE with today's route to
   the exit line.
5. **Sprint at a shot.** Any shot inside an audible radius, hit or miss, makes it run flat out for a
   few seconds ("so after shoot they will start sprint").
6. **Spread panic through the sounder**, member to member with a short delay so it reads as spreading
   rather than as a group teleporting into panic (brief decision 2, Karen: "spreading agree with
   you").
7. **Move as a sounder in single file or as a loose group, chosen per sounder** ("they usually do one
   line each after another or mixed like in real life").
8. Work for **one boar** and for a sounder of the male model, on the same brain and the same body
   (brief decision 3).
9. Keep **exactly one writer** for every new piece of state (CLAUDE.md rule 3), and ship **born OFF**
   (brief decision 6, resolved in §6).

## 2. What it must not do

- **It must not touch the body, the wounds or the death.** The physics box, the four hit zones, the
  damage model, the collapse, the carcass anchor and every sound of Tasks 115–116 are untouched.
  `Boar.Body` stays the only writer of a boar's Instances (`src/server/Boar/Body.luau` header) and
  `Boar.Brain` stays the only writer of a boar's decision state (brief decision 5).
- **It must not change any existing number.** `DETECT_RADIUS`, `CALM_RADIUS`, `CALM_TIME`,
  `SENSE_INTERVAL`, `TROT_SPEED`, `SPRINT_SPEED`, the `WOUND` block and the `SOUNDER` block keep their
  values and their homes in `Boar.CONFIG`. New numbers go in a new block (§7.1). A number that moves
  file silently changes every reader.
- **It must not add a second panic path.** Today `Brain:step`'s herd-panic branch reads
  `obs.sounder.leaderState == "FLEE" or "WOUNDED"`. With the new flag ON that branch is **replaced**
  by the alarm in §5.2 — not run alongside it. Two correct rules disagreeing is this project's named
  killer (`docs/PROJECT_CONTEXT.md`).
- **It must not write a player, a team or a character.** It reads positions and nothing else.
- **It must not own dogs, routing, the female, the cub, the map, or `BOAR_MODEL`'s default** (brief,
  "Out of scope"). Dogs appear only as a `kind` string a later task fills in.
- **It must not add a remote.** Nothing in it is client code, exactly as `boar-ai.md` §2 established.
- **It must not call `PathfindingService` more often than today.** AVOID does not path (§4.4); the
  existing `LEADER_PATHS_ONLY` invariant and the measured `PATH_START_AHEAD` fix are untouched.
- **It must not react to a hit later than it does today.** Hits still run at the top of `Brain:step`,
  before the sense gate.

---

## 3. The states and the transitions

### 3.1 The state set

`Brain:state()` today returns `IDLE`, `FLEE`, `WOUNDED`, `CRIPPLED`, `DOWN`, `GONE`
(`src/server/Boar/Brain.luau`: `Brain.new`, `_reactToHit`, `_collapse`, `step`). Two are added:

| State | Meaning | Speed setpoint | Paths? | New? |
|---|---|---|---|---|
| `IDLE` | calm. **Task 117's repertoire lives inside it** | `WANDER_SPEED`, 0 while grazing | no | no |
| `ALERT` | head up, stopped, turned to the cause | **0** | no | **yes** |
| `AVOID` | turned away, trotting off on a new heading | `TROT_SPEED` | **no** | **yes** |
| `FLEE` | spooked; route to the exit line | `SPRINT_SPEED` inside the flush band, else `TROT_SPEED` | yes | no |
| `WOUNDED` | FLEE that never calms, speed scaled by the wound | wound-scaled | yes | no |
| `CRIPPLED` | back end gone; circles where it stands | `CRIPPLE_SPEED` | no | no |
| `DOWN` | carcass | 0 | no | no |
| `GONE` | terminal | 0 | no | no |

**One table says which states are calm and which are panicked**, and every consumer reads it, so a
seventh state cannot be forgotten in one predicate:

```luau
Brain.CLASS = {
    IDLE = "calm", ALERT = "calm", AVOID = "disturbed",
    FLEE = "panicked", WOUNDED = "panicked",
    CRIPPLED = "down", DOWN = "down", GONE = "gone",
}
Brain.classOf(state: string): string
```
`Match` is unaffected: its only read of boar state is `handle.state() ~= "DOWN" and ~= "GONE"` for the
alive count (`src/server/Match/init.luau`, the `MAX_ALIVE_BOARS` branch), and `ALERT`/`AVOID` are
alive. Verified by grep: no other module outside `src/server/Boar/` compares a boar state string.

### 3.2 Precedence — read top to bottom, first match wins

This is the whole state machine. Everything above rule 7 is today's code, unchanged.

| # | Condition | Result |
|---|---|---|
| 1 | `_outcome(position)` says escaped / outOfBounds | `GONE`, despawn once |
| 2 | already `DOWN` | carcass countdown, then `GONE` with `reason = "killed"` |
| 3 | a hit event this tick (`obs.hitEvents`) or `obs.wound.collapse` | today's `_reactToHit` / `_collapse` |
| 4 | `CRIPPLED` | circles; **ignores every stimulus and every sound** |
| 5 | `WOUNDED` | never returns to a calm state |
| 6 | `_boltFor > 0` (hit bolt **or** heard shot, §4.5) | `FLEE`, sprint, threat point = the shot point |
| 7 | `perception.reaction == "flee"` | `FLEE` |
| 8 | `obs.sounder.alarm` (panic has reached this member, §5.2) | `FLEE` |
| 9 | `perception.reaction == "avoid"` | `AVOID` |
| 10 | `perception.reaction == "alert"` and the refractory timer has run out | `ALERT` |
| 11 | otherwise, and the calm test in §4.3 passes | `IDLE` |

Rules 7–10 are evaluated **only on a sense tick** (`SENSE_INTERVAL = 0.2 s`), exactly as the
IDLE→FLEE test is today, so the reaction budget is unchanged: ≤ 0.2 s + one frame.

### 3.3 Leaving ALERT

| From ALERT | To | When |
|---|---|---|
| the cause closes inside its flush radius, or any other stimulus does | `FLEE` | next sense tick |
| the cause starts moving (`speed ≥ MOVING_SPEED`) and is inside `NOTICE_MOVING` | `AVOID` | next sense tick |
| a shot is heard | `FLEE` + sprint | same tick |
| the sounder alarm arrives | `FLEE` | next sense tick |
| `ALERT_SECONDS` elapsed, nothing changed | `IDLE`, `_home` reset to the current position, **and the refractory timer set to `ALERT_REFRACTORY_SECONDS`** | timer |

The refractory timer exists because without it a boar standing 20 studs from a motionless hunter
flips IDLE→ALERT→IDLE every 2.5 s for ever. With it the animal grazes and lifts its head
occasionally, which is both what a real boar does and what Karen asked for ("they relaxed").

### 3.4 Leaving AVOID

| From AVOID | To | When |
|---|---|---|
| the cause (or another stimulus) is inside a flush radius | `FLEE` | next sense tick |
| a shot is heard, or the alarm arrives | `FLEE` + sprint | same / next tick |
| `AVOID_SECONDS` have passed since the last tick any stimulus was noticed | `IDLE`, `_home` reset | timer |
| it crosses the exit line | `GONE`, `reason = "escaped"` | immediately |

**AVOID counts as escaping.** `Brain:_outcome` today tests `self._state == "FLEE" or "WOUNDED"`;
`AVOID` joins that list. The line is the line: how the animal got over it does not change that it is
over it, and the drive already scores on `Despawned`'s `reason`. An `IDLE` boar wandering over the
line still does **not** escape (`boar-ai.md` review round 2, finding 6, preserved).

### 3.5 The approach to the line is not a state

Karen's "comes line to hunter… relaxed" is `FLEE`'s existing far-from-threat branch: with no stimulus
inside a flush radius the setpoint is `TROT_SPEED` and the route is the navmesh path to `exitZ`. No new
state, no new number. What changes is only that a **standing shooter on a post is now perceivable and
does not flush the boar** (he is noticed at 25 and flushes only at 15), which is what makes the
relaxed approach possible at all — today shooters are invisible to boars, because `MatchBoot` wires
`world.threats = Match.driverThreats` (drivers only).

### 3.6 What the drawn animal does (behind `BOAR_MODEL`, unchanged mechanism)

Exactly two additions, both inside the existing seam:

1. `Runtime:step` adds one field to the table it already builds for `Body.stepVisual`:
   `alert = intent.state == "ALERT"` — the same shape as the existing `crippled = intent.state == "CRIPPLED"`.
2. `Body.clipFor` gains one branch **inside `wanted()`**, after the three gaits and after the turn
   hysteresis, before `idle`:
   `if info.alert and Body.hasClip(model.ALERT_CLIP, config) then return model.ALERT_CLIP, 1 end`.

`CONFIG.MODEL.ALERT_CLIP` is a **string naming a row in `CLIPS`**, default `"alert"`. That is the
whole of this design's dependency on Task 117 and on the Director's publishing: if 117 lands a
`smell` row, `ALERT_CLIP = "smell"` is a one-word data change; if no clip is published,
`Body.hasClip` is false, the animal plays `idle`, and the behaviour is unchanged — the same
"if an id is missing, the current behaviour stays" rule the file already rests on (`Body.hasClip`).
The turn clips still play while the boar swings round to face the cause, because ALERT's facing goes
through the existing `TURN_RATE` slew and `Body.stepVisual` derives `yawRate` from the trunk's own
facing.

**The clip this design wants, for the Director:** one standing clip with the head raised — scenting,
listening or head-up. It is one of the package's other 64 (`tools/boar_prep.py`'s comment names
"swimming, digging, eating, jumping, attacking" among them; the full list is not in this repo, §16).
Publishing it means adding its name to `DEFAULT_CLIPS` in `tools/boar_prep.py` with a reason —
`validate` refuses any clip not in that tuple — then the usual Animation-Editor publish. If the
package has none, the fallback is an authored clip through the existing `SYNTH_CLIPS` mechanism
(`Idle_1` with the neck and head blended toward the alert pose), which is how Tasks 116's three
authored clips were made. **No behaviour in this design blocks on it.**

---

## 4. Perception: ONE function

### 4.1 The seam, and why its name does not change

The brief asks for perception as one function, on "the existing 'who is a threat' seam in
`boar-ai.md` §4". That seam is `world.threats()` → `{ { id, position } }`, produced in production by
`Match.driverThreats` and consumed only by `Runtime:step` (`self._world.threats()`), which hands it to
every Brain as `obs.threats`.

**The field keeps the name `threats` and the record grows two fields.** The alternative — renaming it
`stimuli` — is a better word and costs 37 edits across 12 files (24 occurrences in 8 spec files, 13 in
4 source files, by grep), every one of them in the files whose job is to prove that **the flag-OFF
world is byte-for-byte today's world**. The word is worth less than that proof. The record is
documented as "anything a boar can perceive":

```luau
export type Kind = "driver" | "shooter" | "dog"
export type Threat = {
    id: string,
    position: Vector3,
    kind: Kind?,     -- nil means "driver": today's meaning, so old callers are unchanged
    speed: number?,  -- studs/s, flat. FILLED BY THE RUNTIME, never by the provider (§4.6)
}
```

### 4.2 The one function

```luau
export type Reaction = "flee" | "avoid" | "alert" | "none"
export type Perception = {
    reaction: Reaction,
    cause: Threat?,          -- the stimulus that produced the reaction
    distance: number,        -- flat distance to `cause`, math.huge when there is none
    centroid: Vector3?,      -- XZ centroid of everything inside a FLEE radius; the route's anchor
    nearest: Vector3?,       -- nearest stimulus of any kind, flat
    nearestDistance: number,
    calm: boolean,           -- nothing inside noticeRadius + CALM_MARGIN (§4.3)
}

Brain.isMoving(threat: Threat, config): boolean      -- (threat.speed or 0) >= SENSE.MOVING_SPEED
Brain.noticeRadius(threat: Threat, config): number
Brain.fleeRadius(threat: Threat, config): number
Brain.perceive(position: Vector3, threats: { Threat }, config, probe: Probe?): Perception
```

All four are **pure, module-level and exported on `Brain`**, for the reason `Brain` and `Wound` are
already exported: a spec drives every band with no boar in the world (`src/server/Boar/init.luau`,
`Boar.Brain` / `Boar.Wound` exports).

Two radii per stimulus, and that is the whole of Karen's scene:

| | notice (head up / turn away) | flush (run) |
|---|---|---|
| standing (`speed < MOVING_SPEED`) | `NOTICE_STANDING` = 25 | `FLUSH_STUDS` = 15 |
| moving | `NOTICE_MOVING` = 60 | `DETECT_RADIUS` = 40 (today's number, unchanged) |
| dog (always counted as moving) | `NOTICE_MOVING × DOG_NOTICE_SCALE` | `DETECT_RADIUS × DOG_NOTICE_SCALE` |

```
for each threat:  d = flatDistance(position, threat.position)
    d <= fleeRadius(threat)    -> "flee"   (and it joins the centroid)
    d <= noticeRadius(threat)  -> moving and "avoid"  or  standing and "alert"
the strongest reaction wins (flee > avoid > alert > none); ties go to the nearest.
```

**With `SENSE.ENABLED == false` the function is today's rule and nothing else:** every stimulus whose
`kind` is not `"driver"` is dropped, every radius is `DETECT_RADIUS`, the only reactions are `"flee"`
and `"none"`, and `centroid`/`nearestDistance` are what `Brain:_threatInfo` returns today.
`_threatInfo` is **folded into `perceive`** rather than left beside it — one function, not two
answering the same question.

### 4.3 The calm test, and the one relationship that must not drift

Today: `nearestDistance > CALM_RADIUS` for `CALM_TIME` → `IDLE`. With shooters perceivable that
hysteresis is wrong — a boar that has crossed the line would never calm down with a shooter standing
30 studs behind it. So:

```
calm = no threat with  d <= noticeRadius(threat) + SENSE.CALM_MARGIN
```

`CALM_MARGIN = 30`, which is exactly `CALM_RADIUS − DETECT_RADIUS` (70 − 40), so **the flag-OFF branch
is arithmetically identical to today**. A spec asserts
`CONFIG.CALM_RADIUS - CONFIG.DETECT_RADIUS == CONFIG.SENSE.CALM_MARGIN` so the two can never drift
apart silently (§12, pure case 11).

### 4.4 Where ALERT and AVOID point

- **ALERT.** `desiredDirection = unit(cause.position − position)`, `desiredSpeed = 0`. Both go through
  the existing `TURN_RATE` slew and `ACCEL` ramp, so the animal turns at ≤ 4 rad/s (a 180° turn takes
  0.79 s) and stops at ≤ 60 studs/s². No new mechanism, and both limits stay assertable with no
  physics.
- **AVOID.** `Brain._avoidTarget(position, cause, rng)`:
  ```
  away   = unit(flat(position) - flat(cause.position))
  turn   = rad(AVOID_TURN_DEG) * sign      -- sign drawn ONCE on entering AVOID, kept in _avoidTurn
  target = clamp(position + rotateY(away, turn) * AVOID_STUDS, bounds inset by EDGE_MARGIN)
  ```
  Steering is the existing Reynolds fallback toward `target`, with the existing `blockedAhead` probe
  turn. **`pathRequest` is never set in AVOID**: it lasts `AVOID_SECONDS`, it is local, and
  `ComputeAsync` is the system's one expensive call — the path budget must not change in a behaviour
  task. For a driver standing behind a boar, "away from the cause ±120°" points up the corridor, so
  AVOID *is* the gentle push; `Match.CONFIG.POINTS.PUSH_RADIUS = 60` ("1.5x `Boar.CONFIG.DETECT_RADIUS`")
  already agrees with `NOTICE_MOVING = 60`, so push credit and the boar's own reaction start at the
  same distance.

**"Where they run" stays as it is** (brief item 4). The hooks a later routing task replaces are
exactly two named functions: `Brain:_routeTarget` (FLEE, unchanged) and `Brain._avoidTarget` (new).
Nothing else in the system computes a destination.

### 4.5 A shot is a sound, not a hit

There is **no server-side "a shot was fired" signal today**: `src/server/Weapon/init.luau` publishes
`Weapon.HitReported` (per hit) and `Weapon.SafetyViolated`, and fires the client remote
`channel.ShotFired:FireAllClients` inside `onFireRequest`. A miss is therefore invisible to the server
outside the weapon.

**Weapon gains one event, in the shape it already uses twice:**
```luau
-- ServerScriptService.Weapon  (owner: Weapon. Boar never requires Weapon, and Weapon never requires Boar.)
Weapon.ShotFired: RBXScriptSignal  -- fires ({ shooterUserId: number, muzzle: Vector3, ammo: string })
```
One `BindableEvent` beside `hitSignal`/`safetySignal`, fired once per **accepted** shot in
`onFireRequest` next to the existing `FireAllClients` (so a rate-limited, invalid or unarmed click
makes no sound). The name deliberately matches the client remote: one fact, two audiences, exactly as
`HitReported` sits beside the `HitMarker` remote.

`MatchBoot` — already the one composition root that wires `Weapon.HitReported` into
`runtime:takeHit` — adds the mirror line:
```luau
Weapon.ShotFired:Connect(function(shot) runtime:hearShot(shot.muzzle) end)
```

The Brain is told through the same door hits use:
```luau
export type Sound = { kind: "shot", position: Vector3 }
-- obs.sounds: { Sound }?   drained per step by the Runtime, exactly like obs.hitEvents
```
A boar whose flat distance to the shot is `≤ SENSE.SHOT_AUDIBLE_STUDS` sets
`_boltFor = max(_boltFor, SHOT_SPRINT_SECONDS)`, `_lastShotPoint = position`, and enters `FLEE` from
`IDLE`/`ALERT`/`AVOID`. That is the **existing** bolt mechanism (`_reactToHit`'s documented single
`ACCEL` bypass, and `Brain:step`'s "while bolting, the shot point IS the threat"), reused with its own
duration — no second sprint rule. `DOWN`, `GONE` and `CRIPPLED` ignore sounds, with the same guard
`_reactToHit` uses.

**A heard shot does not scatter a sounder.** `SCATTER_ON_HIT` stays what it is: being *hit* breaks a
group up, hearing a shot makes the group run together, which is what Karen asked for. One rule each,
and `stats().scatters` keeps meaning what it means.

### 4.6 Motion is measured by the Runtime, not reported by the provider

`speed` is filled in one place: `Runtime:step`, from a `self._motion[id] = { position, speed }` table it
owns, as an exponential average over `SENSE.SPEED_SMOOTH_SECONDS` of the flat displacement between
steps. Three reasons, all of them things this repo has already paid for:

1. **One writer.** A provider that forgets `speed` cannot make every boar think a sprinting driver is
   standing still.
2. **It cannot be faked.** A character's `AssemblyLinearVelocity` is network-owned by its own client;
   a server-measured displacement of the replicated position is not. A client that wants to be
   unnoticed has to actually stand still.
3. **It is smoothed for the same measured reason `MODEL.YAW_SMOOTH_SECONDS` exists** — one frame's
   delta on a physics body is noise, not a rate (`Body.stepVisual`'s yaw comment: ±170 °/s on a
   standing animal).

The Runtime builds **new** records rather than mutating the provider's (a provider may cache one day),
which costs ≤ 16 small tables per step. A stimulus seen for the first time has no previous sample and
reads as standing for exactly one step (16 ms): it can only ever under-react, never over-react.

### 4.7 Line of sight: no, and here is the hook

`world.probe` exists and is cheap — one `Workspace:Raycast` with the boar folder excluded
(`Boar.defaultWorld`'s `probe`) — so it *is* available. It is **not used for noticing**, by decision:
a boar is a nose and a pair of ears first, and a hedge does not hide a man from one. `boar-ai.md` §12
item 3 left this as Karen's feel call with "no line-of-sight" as the default; this design keeps that
default and makes it a dial instead of an argument: `SENSE.REQUIRE_SIGHT = false`. When true,
`Brain.perceive` requires `probe(position + up, towards(cause), distance) == false` before a notice,
and because it is a config value both branches are reachable by parameter and both get a spec case.
The probe keeps its existing job (obstacle avoidance) either way.

---

## 5. The sounder

### 5.1 Single file or loose, chosen per sounder

Today the moving shape is always the wedge in `CONFIG.SOUNDER.FORMATION`, with a **column** only while
`blockedAhead` latches it for `COLUMN_LATCH_SECONDS` (`Brain:_slotPoint`, `drive.md` §6.7). Karen:
"they usually do one line each after another or mixed like in real life".

- `record.formation` is `"column"` or `"wedge"`, **drawn once in `Runtime:spawnSounder`** with
  `rng:NextNumber() < SOUNDER.COLUMN_CHANCE`, and never written again. The Runtime owns the sounder
  record (`self._sounders`), so this is its field and nobody else's.
- It reaches the Brain as a plain value on the existing observation: `obs.sounder.formation`.
- `Brain:_slotPoint` chooses the column offsets when `formation == "column"` **or** the probe latch is
  active, and the wedge otherwise. One expression, no new function.
- Idle grouping is unchanged: `_idleSounderDirection` already keeps a grazing sounder a loose group.
- With `SENSE.ENABLED == false`, `formation` is always `"wedge"` and the latch is the only column, i.e.
  today.

### 5.2 Panic spreads, member to member, with a delay

Replaces the leader-only rule in `Brain:step` (`leaderPanicked`, and the `leaderCalm` half of the
calm-down branch) when the flag is ON.

Written in `Runtime:_stepSounders`, which already rebuilds membership from the boars every step and
already has the one position snapshot:

1. When any member's `Brain.classOf(state) == "panicked"` and no alarm is running for that sounder,
   the Runtime orders the other members by flat distance **from that member** and sets
   `entry.alarmIn = min(PANIC_DELAY_SECONDS * rank, PANIC_DELAY_MAX)`, rank 1…n−1.
2. Each step it counts `alarmIn` down by `dt` (not by a clock, so a spec is deterministic) and passes
   `obs.sounder.alarm = (armed and alarmIn <= 0)`.
3. `alarm` clears when every member is calm again. A member that leaves the sounder loses it with its
   `sounderId`, through the existing `_leaveSounder`.
4. Herd calm becomes: a follower settles when its own `CALM_TIME` has run **and**
   `Brain.classOf(obs.sounder.leaderState) == "calm"` — the one table from §3.1, so a leader that is
   `ALERT` no longer pins the whole group in `FLEE` for ever.

**ALERT does not spread.** One animal with its head up while the others graze is what a sounder
actually looks like, and it is also the conservative choice: only panic is contagious (brief decision
2 says panic).

---

## 6. The flag

**A new flag, `BOAR_BEHAVIOUR`, born OFF.** Brief decision 6 allows a separate flag if the behaviour
is independent of the drawn model, and it is: every state, radius and timer in this design is
`Brain`/`Runtime` state and is fully exercised on the grey box. Only §3.6's two lines sit behind
`BOAR_MODEL`, where they already are.

Row for `src/shared/Flags/init.luau` (`Flags.DEFAULTS`), in the shape `BOAR_MODEL` already has:

```
BOAR_BEHAVIOUR = {
    default = false,
    owner   = "ServerScriptService.Boar",   -- reads it once at Boar.CONFIG.SENSE.ENABLED
    born    = "2026-10-04 task 118",
    expires = "2026-10-25",                 -- 21 days: feature-flags.md section 12
    why     = "A boar notices a standing person at 25 studs and a moving one at 60, goes head-up, "
           .. "turns away or runs, sprints at a shot, and panics through its sounder. OFF is the "
           .. "40-stud drivers-only flush of Milestone 1.2.",
}
```
Seven flags → nine attributes on `ReplicatedStorage.Flags.State`, inside the ≤ 14 the design and
`flags.spec` enforce (`docs/design/feature-flags.md` §12).

**Read once, at the boundary, passed inward as config** — the only permitted shape:
`Boar.CONFIG.SENSE.ENABLED = Flags.isOn("BOAR_BEHAVIOUR")`, beside the existing
`Boar.CONFIG.MODEL.ENABLED`. Every function takes the value through `config`, so both branches are
reachable by parameter while the flag sits at one of them — which is the only way either branch can be
tested, because `python tools/studio_mcp.py test` **refuses to start while an override is set**
(CLAUDE.md, feature flags). A harness run can therefore only ever see the OFF default; the ON branch
is proved by specs that pass their own config, and *felt* in a playtest with the override.

**`newRuntime` must merge the `SENSE` block key by key** over the default, the way it already clones
`MODEL` (`Boar.newRuntime`'s "A MODEL BLOCK OF ITS OWN, because `table.clone` is SHALLOW"). Without
that, a spec passing `config = { SENSE = { ENABLED = true } }` replaces the whole block and every
radius reads nil. One loop, and §12 pure case 14 proves it.

---

## 7. Interface, numbers and owners

### 7.1 `Boar.CONFIG.SENSE` — every new number, in one block

| Name | Value | Basis |
|---|---|---|
| `ENABLED` | `Flags.isOn("BOAR_BEHAVIOUR")` | the one read of the flag |
| `NOTICE_STANDING` | 25 studs | **Karen** (brief decision 1, "agree") |
| `NOTICE_MOVING` | 60 studs | **Karen**; equals `Match.CONFIG.POINTS.PUSH_RADIUS`, so push credit and the boar's reaction begin together |
| `FLUSH_STUDS` | 15 studs | 0.6 × `NOTICE_STANDING`: a 10-stud band of "head up" before the bolt. A man this close bolts a boar whatever it is doing (source 6) |
| `MOVING_SPEED` | 2 studs/s | default `Humanoid.WalkSpeed` is 16 (source 4); measured server-side displacement of a standing character stays well under 1 |
| `SPEED_SMOOTH_SECONDS` | 0.3 | one frame's delta is noise; the same reason as `MODEL.YAW_SMOOTH_SECONDS = 0.2`, with a longer window because this is a gameplay threshold |
| `CALM_MARGIN` | 30 studs | **= `CALM_RADIUS − DETECT_RADIUS`**, so the OFF branch is today's hysteresis exactly (§4.3) |
| `ALERT_SECONDS` | 2.5 | a 180° turn costs 0.79 s at `TURN_RATE` 4 rad/s, leaving ~1.7 s of head-up hold. Karen's dial |
| `ALERT_REFRACTORY_SECONDS` | 8 | stops a 2.5 s IDLE↔ALERT flip-flop in front of a motionless hunter (§3.3) |
| `AVOID_SECONDS` | 4 | = `CALM_TIME`: the same "it has stopped caring" span the system already uses |
| `AVOID_TURN_DEG` | 120 | "turn around and go another direction" — past 90°, so it is visibly a refusal, not a sidestep |
| `AVOID_STUDS` | 80 | 2 s of trot at 18 studs/s + margin; one steering target, re-evaluated on entry |
| `SHOT_AUDIBLE_STUDS` | 350 | ~98 m at 1 stud = 0.28 m (source 4). A 12-gauge is really audible for kilometres; the whole 1,240 × 1,680 corridor bolting at the first shot would end a drive in 30 s. **Gameplay number, Karen's dial** (§15) |
| `SHOT_SPRINT_SECONDS` | 4 | one second longer than `WOUND.BOLT_SECONDS = 3`: a hit boar carries on because it is hurt, an unhit one only has the bang |
| `PANIC_DELAY_SECONDS` | 0.15 | per hop, nearest first. ~9 frames: visible as spreading, under a sense tick's worth of lag per animal |
| `PANIC_DELAY_MAX` | 0.6 | a sounder of 5 is fully alarmed inside 0.6 s, i.e. inside one `CALM_TIME`-free beat |
| `DOG_NOTICE_SCALE` | 1.5 | hook only; dogs are out of scope (brief). A dog is a flusher, so its radii are half again a person's |
| `REQUIRE_SIGHT` | `false` | §4.7. `true` gates a notice on `world.probe` |

In `Boar.CONFIG.SOUNDER` (the behaviour half of the sounder, which this file already owns):

| Name | Value | Basis |
|---|---|---|
| `COLUMN_CHANCE` | 0.5 | "one line each after another or mixed" — half and half. Karen's dial |
| `COLUMN_SPACING_STUDS` | 9 (**existing**) | single file spacing, 1.6 body lengths; `drive.md` §11.7 |

In `Boar.CONFIG.MODEL`: `ALERT_CLIP = "alert"` (§3.6).

### 7.2 Public interface, in full

```luau
-- ServerScriptService.Boar
export type State  = "IDLE" | "ALERT" | "AVOID" | "FLEE" | "WOUNDED" | "CRIPPLED" | "DOWN" | "GONE"
export type Kind   = "driver" | "shooter" | "dog"
export type Threat = { id: string, position: Vector3, kind: Kind?, speed: number? }
export type Sound  = { kind: "shot", position: Vector3 }

Boar.CONFIG.SENSE : SenseConfig                 -- §7.1
Boar.Brain.CLASS, Boar.Brain.classOf(state)     -- §3.1
Boar.Brain.isMoving / noticeRadius / fleeRadius / perceive   -- §4.2, pure
Boar.Brain.avoidTarget(position, cause, config, rng)         -- the routing hook, pure

-- Runtime (one new entry point, two new readers; no setter for any of them)
Runtime:hearShot(at: Vector3): number           -- boars that will be told; fans into obs.sounds
Runtime:perceptionOf(id: string): Perception?   -- a COPY of a boar's last perception, for specs
Runtime:stats()                                 -- gains shotsHeard, alarms, alerts, avoids
Runtime:sounders()                              -- the view gains `formation`
```
`Runtime:perceptionOf` follows `Runtime:woundOf` and `Runtime:animationOf` exactly: a copy, no setter,
nothing in the game reads it. It exists so a live spec can prove *why* a boar did something instead of
inferring it from velocity.

```luau
-- ServerScriptService.Weapon  (§4.5)
Weapon.ShotFired: RBXScriptSignal  -- ({ shooterUserId: number, muzzle: Vector3, ammo: string })

-- ServerScriptService.Match  (§8)
Match.boarThreats(): { Threat }                 -- drivers (kind="driver") + shooters (kind="shooter")
Match.Body.boarStimuli(teamOf, service?): { Threat }
```

**Remotes: none.** **New client code: none.**

### 7.3 Owner table rows (CLAUDE.md rule 3; mirror in `GAME_DESIGN.md`)

| State | The one writer | Readers | Where |
|---|---|---|---|
| a boar's behaviour state, its perception, its alert/avoid/refractory/bolt timers | `Boar.Brain` (per boar) | `Runtime` (through the Intent), specs through `Brain` | `src/server/Boar/Brain.luau` |
| every stimulus's **measured speed** (`self._motion`) | `Boar` (`Runtime:step`) | the Brains, as `obs.threats[i].speed` | `src/server/Boar/init.luau` |
| heard shots in flight (`self._sounds`) | `Boar` (`Runtime:hearShot`, drained by `Runtime:step`) | the Brains, as `obs.sounds` | `src/server/Boar/init.luau` |
| a sounder's `formation` and every member's `alarmIn` | `Boar` (`Runtime:spawnSounder`, `Runtime:_stepSounders`) | the Brains, as `obs.sounder.formation` / `.alarm` | `src/server/Boar/init.luau` |
| "a shot was fired" | `ServerScriptService.Weapon` | `MatchBoot`, which calls `runtime:hearShot` | `src/server/Weapon/init.luau` |
| "which people a boar can perceive, and what kind each is" | `ServerScriptService.Match` (`boarThreats`, over `Match.Body.boarStimuli`) | the boar world, injected at `MatchBoot` | `src/server/Match/`, `src/server/MatchBoot.server.luau` |
| `BOAR_BEHAVIOUR`'s resolved value | `Boar.CONFIG.SENSE.ENABLED`, read once | everything inward, as `config` | `src/server/Boar/init.luau` |

Amended `GAME_DESIGN.md` row (the existing Boar row, extended — the Builder mirrors it):

> | Boar AI: state, **behaviour, perception**, movement and lifetime of every boar (`Workspace.Boars` and everything in it) | `ServerScriptService.Boar`, booted once by `ServerScriptService.MatchBoot`. `Boar.Brain` (decisions, perception) and `Boar.Body` (instances) are private to it. It writes nothing else in Workspace, and it reads a stimulus list it never writes | `src/server/Boar/` | [boar-ai](docs/research/2026-09-24-boar-ai.md), [designs](docs/design/boar-behaviour.md) |

### 7.4 What this supersedes

| Where | What | Now |
|---|---|---|
| `boar-ai.md` §4, "Who is a threat — the one function" | `threats()` returns `{ id, position }`; `isThreat` is the only classifier | §4.1–4.2 here: the record carries `kind`, the Runtime fills `speed`, and `Brain.perceive` is the one decider. `CONFIG.isThreat` keeps its job (who is in the list at all) |
| `boar-ai.md` §5, the state table ("Three states") | IDLE / FLEE / GONE, one `DETECT_RADIUS` | §3 here (and `hit-zones.md` §6 for WOUNDED/CRIPPLED/DOWN, unchanged) |
| `boar-ai.md` §12 item 3 | line of sight is Karen's open question | §4.7: no sight check, with `SENSE.REQUIRE_SIGHT` as the dial |
| `drive.md` "the sounder's behaviour", §6.7 | the leader-panic transition; the column only via the probe latch | §5.1–5.2 here when the flag is ON. The record gains `formation`; `drive.md`'s record shape and `Match.CONFIG.SOUNDER` (the release half) are otherwise untouched |

Everything else in `boar-ai.md`, `hit-zones.md` and `drive.md` stands.

---

## 8. Cross-system reads and writes

| Direction | What | Owner of the other side |
|---|---|---|
| reads | `world.threats()` — positions and kinds only | `ServerScriptService.Match` (`boarThreats`), injected at `MatchBoot`. The boar never requires Match |
| reads | `player.Team` **indirectly**, never itself: the kind comes from Match's own assignment | `Match.Body.setTeam` is the only writer of `player.Team` |
| reads | `Weapon.ShotFired` **indirectly**: `MatchBoot` connects it to `runtime:hearShot` | `ServerScriptService.Weapon` |
| reads | `Workspace:Raycast` through `world.probe`; `PathfindingService` through `world.requestPath` | Roblox engine, read-only |
| writes | `Workspace.Boars` and its descendants, through `Boar.Body` only | this system |
| writes | `Despawned` / `Hit` / `Downed` (unchanged payloads; `reason = "escaped"` can now come from AVOID) | this system; the Match reads them |
| writes | nothing else, anywhere | — |

**The shooters list is why this task touches `src/server/Match/`.** The boar needs to know that the
person at the line is a shooter and the person behind it is a driver, and team assignment has exactly
one owner (`Match`, `state.assignment`, surfaced by `Match.Body.setTeam` on `player.Team`). So:

- `Match.Body.boarStimuli(teamOf, service)` — **a new function beside `Body.driverPositions`, not a
  change to it.** `driverPositions` answers "who is pushing, and who may be tied"; `boarStimuli`
  answers "what can a boar perceive". One predicate answering two unrelated questions is a named
  cause of death of the previous project, and `Match.playerDrivers` / `Penalty` keep reading the old
  one unchanged.
- `Match.boarThreats()` wraps it and keeps the quick-test phantom (`Match.quickTestPhantom`), which
  must stay a `kind = "driver"` stimulus with a non-numeric id — the filter in `Match.playerDrivers`
  that exists because of that id is untouched.
- `MatchBoot` changes **one line**: `world.threats = Match.boarThreats`. It is wired
  unconditionally; the flag decision stays in the Brain (`SENSE.ENABLED == false` drops every
  non-driver kind), so the composition root keeps no conditional and "with the flag off a shooter is
  not a threat" is one assertion in a pure spec instead of a boot-time branch nobody can test.

**Consequence the Builder must plan for.** `src/server/Match/` and `src/server/MatchBoot.server.luau`
are both in `TWO_PLAYER_PATHS` (CLAUDE.md, "Run / test"). So:

- **review rounds:** `python tools/studio_mcp.py test --scope auto` produces a `scope=auto:…` line and
  `tools/agents.py` then asks for **no** `[harness2]` line at all. No human click per round.
- **the PR to main:** the full `test` **and** `test2`, i.e. **one Karen click, once.** That is the
  honest price of a boar that can tell a shooter from a driver, and a second player is in fact the
  only thing that can show both kinds in one session. The Director may instead split the wiring into a
  one-line follow-up task (§15, Director decision 3); the default is to do it here, because without it
  Karen's central scene — the boar at the line — is unreachable in a playtest.

---

## 9. Performance targets, each one an assertion

| Target | How it is checked |
|---|---|
| `Brain:step` ≤ 15 µs with `SENSE` ON and 4 stimuli | pure spec: 10 000 steps under 150 ms wall clock (today's budget is 10 µs / 100 ms with one threat) |
| perception runs on the sense tick, not per frame | pure spec: a counting `probe` is called ≤ `1 + elapsed / SENSE_INTERVAL` times with `REQUIRE_SIGHT = true` |
| **path requests do not increase**: ≤ 1 in flight per boar, ≤ 2/s while fleeing, **0 in ALERT and 0 in AVOID** | `stats().pathRequests` across a timed live run |
| reaction ≤ 0.2 s + one frame for every transition in §3.2 | pure spec, exact, per transition |
| a sounder of 5 is fully alarmed within `PANIC_DELAY_MAX` + one sense tick, and **not on one tick** | live spec: at least one step where one member is panicked and another is not |
| motion measurement costs one pass over ≤ 16 stimuli per step | code shape; no assertion needed |
| zero errors and zero skipped tests | `tests/TestKit.luau` fails the run otherwise |

---

## 10. External sources

Rule 1 and rule 2. Sources 1, 2 and 4 are carried over from `docs/research/2026-09-24-boar-ai.md` and
`docs/design/boar-ai.md` §8 (that is where they were assessed; this design does not re-derive them).
3, 5, 6 and 7 are added by this design.

| # | Source | Licence | Maintenance |
|---|---|---|---|
| 1 | Craig Reynolds, *Steering Behaviors For Autonomous Characters* (GDC 1999) — <https://www.red3d.com/cwr/steer/gdc99/>, and *Boids* — <https://www.red3d.com/cwr/boids/> | published paper, freely readable; technique taken, no code | frozen (1987/1999); the standard reference |
| 2 | Mat Buckland, *Programming Game AI by Example* (Wordware, 2005), ch. 2 (state machines), ch. 3 (steering) | book | 2005, no updates; the pattern is stable |
| 3 | **Tom Leonard, "Building an AI Sensory System: Examining the Design of Thief: The Dark Project" (GDC 2003 / Game Developer)** — <https://www.gamedeveloper.com/programming/building-an-ai-sensory-system-examining-the-design-of-i-thief-the-dark-project-i-> | article, freely readable; design taken, no code | frozen (2003); still the canonical write-up |
| 4 | Roblox engine docs: `Humanoid` (`WalkSpeed`) — <https://create.roblox.com/docs/reference/engine/classes/Humanoid>; `BasePart.AssemblyLinearVelocity` — <https://create.roblox.com/docs/reference/engine/classes/BasePart>; units (1 stud ≈ 28 cm) — <https://create.roblox.com/docs/art/modeling/roblox-units>; `BindableEvent` — <https://create.roblox.com/docs/reference/engine/classes/BindableEvent> | first-party (creator-docs CC BY 4.0) | actively maintained |
| 5 | **Unreal Engine AIPerception (`UAIPerceptionComponent`, `UAISenseConfig_Sight`/`_Hearing`)** — <https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine> | Unreal Engine EULA; **pattern only, no code** | actively maintained by Epic |
| 6 | **T. Stankowich & D. T. Blumstein, "Fear in animals: a meta-analysis and review of risk assessment", *Proc. R. Soc. B* 272 (2005) 2627–2634** — flight-initiation-distance theory: FID rises with the approacher's speed, directness and conspicuousness | copyrighted paper; cited for the relationship, not reproduced | published, stable; the standard FID reference |
| 7 | **H. Thurfjell, G. Spong, G. Ericsson, "Effects of hunting on wild boar *Sus scrofa* behaviour", *Wildlife Biology* 19 (2013) 87–93**, with M. Scillitani, A. Monaco, S. Toso, "Do intensive drive hunts affect wild boar distribution?", *Eur. J. Wildlife Res.* 56 (2010) 307–318 | copyrighted papers; cited for the behaviour, not reproduced | published, stable |

**What each does well and badly, for this system**

- **1 (Reynolds).** Good: flee, wander, arrival and "sum the behaviours with weights" are already the
  Brain's vocabulary, so AVOID is a new target for machinery that exists. Bad: steering has no
  *awareness* — nothing in it says when to stop grazing. **Adopted for AVOID's steering and for the
  sounder terms, unchanged.**
- **2 (Buckland).** Good: the explicit FSM with engine calls kept out, which is why a spec can drive
  10 000 ticks. Bad: its FSM class hierarchy is far heavier than eight states need, and it has no
  notion of a sensory system. **Pattern adopted, code not.**
- **3 (Thief).** Good: the design this state machine *is* — one sensory system feeding discrete
  awareness levels (idle → suspicious → searching → combat), each with a dwell time and hysteresis so
  the AI cannot chatter between levels; and the insistence that hearing is a world event with a
  radius, not a query. ALERT, `ALERT_SECONDS`, `ALERT_REFRACTORY_SECONDS` and the `obs.sounds` shape
  are all this. Bad: it is a stealth game — its levels converge on searching for a hidden player,
  which a boar never does, and its sound propagation walks a room graph this game does not have.
  **Adopted: awareness levels with dwell and refractory, one sensory function, hearing as an event.**
- **4 (Roblox docs).** Good: fixes the two numbers the thresholds hang on (`WalkSpeed` 16, 1 stud ≈
  0.28 m) and the `BindableEvent` idiom `Weapon.ShotFired` copies from its own neighbours. Bad: the
  unit figure is an art convention the engine does not enforce, which is why it is written down once;
  and `AssemblyLinearVelocity` on a player character is client-authoritative, which is exactly why
  §4.6 measures displacement instead. **Adopted.**
- **5 (Unreal AIPerception).** Good: the strongest existing argument for the shape chosen here — one
  perception component per agent, **per-sense configs with their own radii**, a separate "lose" radius
  from the "gain" radius, and a stimulus **age** after which it is forgotten. `noticeRadius`/
  `fleeRadius`/`CALM_MARGIN`/`ALERT_SECONDS` are that model with four numbers instead of forty. Bad:
  it is a large C++ subsystem with teams, affiliations and a listener registry; and licensing makes
  the code unusable here regardless. **Pattern adopted (per-sense radii, gain ≠ lose, stimulus age),
  code not.**
- **6 (Stankowich & Blumstein).** Good: says, with a meta-analysis behind it, that flight distance
  grows with the approacher's **speed** and **directness** — which is precisely Karen's 25-vs-60 split,
  independently arrived at. It also justifies `FLUSH_STUDS` existing at all: FID is a distribution, not
  a line, so a close band where flight is certain is the right shape. Bad: it is about real distances
  in metres in real habitats; a hunted boar's FID for a walking human is tens to hundreds of metres,
  far beyond anything a 1,240-stud corridor can hold. **Adopted as the relationship, not the
  magnitudes** — the magnitudes are Karen's.
- **7 (Thurfjell / Scillitani).** Good: both measure wild boar under *drive hunting* specifically —
  boars increase movement rate and displacement during and after drives, react to disturbance across
  the drive area rather than only to the nearest beater, and return afterwards. That is the evidence
  for panic spreading through a group and for a heard shot mattering well past the shooter. Bad:
  neither gives a reaction radius in anything a game can use (GPS fixes at minute-to-hour intervals),
  so `SHOT_AUDIBLE_STUDS` is a gameplay choice and is labelled one. **Adopted as the justification for
  sound-at-a-distance and group panic.**

**Pattern adopted:** Thief's awareness levels with dwell and refractory (3) + Unreal's per-sense
notice/flush radii and stimulus age (5), decided by one pure function, over the existing Reynolds
steering (1) and explicit FSM with an injected world (2), with thresholds anchored on Karen's numbers
and shaped by the FID relationship (6) and drive-hunt field data (7).

**Invented here, with the reason (rule 2):** `Brain.avoidTarget`'s formula (away from the cause,
rotated by a fixed angle, clamped to the field) — no source addresses "flee *at an angle* rather than
away", it is three lines of arithmetic, and it is one spec assertion. Everything else is borrowed.

---

## 11. What the Builder owes the notes

- A new note, `docs/research/2026-10-04-boar-behaviour.md`, plus its `docs/research/INDEX.md` row
  (rule 1; the Builder owns research notes). It must carry: the confirmed URL, licence and maintenance
  line for sources 3, 5, 6 and 7 (this session had no network, §16); the measured standing-character
  speed in a live session, against `MOVING_SPEED = 2`; and whichever clip the Director published for
  ALERT, with its measured length.
- Rule 9: `Brain.luau` and `init.luau` headers gain the pattern name ("awareness levels with dwell and
  refractory, per-sense notice/flush radii"), the links for sources 3 and 5, and this design's path.
- `tools/studio_mcp.py`: both new spec files added to `SCOPE_SPECS["boar"]`. `selftest` fails if a spec
  belongs to no scope, so this is not optional.

---

## 12. How it is tested

One player throughout. Both branches of the flag are reached **by parameter**, because a harness run
can never see the flag ON (§6).

### `tests/server/boar_behaviour.spec.luau` — NEW, pure: no physics, no Workspace, no waiting

Drives `Brain:step(1/60, obs)` with `Random.new(1)` and hand-written observations, and `Brain.perceive`
directly. It writes its own numbers out where the requirement is absolute and reads `CONFIG` where the
assertion is a relationship — the convention `boar_brain.spec` already follows.

1. **Flag OFF is today's world.** With `SENSE.ENABLED = false`: a `kind = "shooter"` stimulus standing
   30 studs away never leaves `IDLE` over 600 steps; a driver at 39 studs enters `FLEE` within 0.25 s;
   `leaderState = "FLEE"` still panics an IDLE follower.
2. **`Brain.perceive`, table-driven**, flag ON: standing at 26 → `none`; 24 → `alert`; 14 → `flee`;
   moving at 61 → `none`; 59 → `avoid`; 39 → `flee`; dog moving at 80 → `avoid`; two stimuli where the
   far one would flee and the near one only alert → `flee` (strongest wins).
3. **ALERT.** Enters within 0.25 s of a standing cause at 24 studs; `targetVelocity` is zero on every
   tick; `facing` reaches within 10° of the cause inside 1.0 s and never turns faster than
   `TURN_RATE * dt`; after `ALERT_SECONDS` the state is `IDLE` and `debug().home` is the current
   position.
4. **The refractory.** With the cause still standing, no second `ALERT` for
   `ALERT_REFRACTORY_SECONDS`, and one immediately after it.
5. **ALERT → FLEE** when the cause closes to 14 studs, within 0.25 s. **ALERT → AVOID** when the cause
   gains `speed = 5` at 30 studs.
6. **AVOID.** Heading turns ≥ 90° away from the cause within 1.0 s; the speed setpoint converges on
   `TROT_SPEED` and never rises faster than `ACCEL * dt`; `pathRequest` is nil on all 600 steps; the
   flat distance to the cause grows ≥ 20 studs in 2 s; with the cause removed, `IDLE` after
   `AVOID_SECONDS`; crossing `exitZ` gives `despawn = true, reason = "escaped"` exactly once.
7. **A shot.** `obs.sounds = {{ kind = "shot", position = 340 studs away }}` → `FLEE` on the same tick
   with the setpoint ≥ `SPRINT_SPEED * BOLT_KICK`, and sprint held for `SHOT_SPRINT_SECONDS`; at 360
   studs nothing happens; routes away from the shot point while bolting.
8. **Sounds are ignored** by `DOWN`, `GONE` and `CRIPPLED`, and `WOUNDED` never returns to a calm
   state after one.
9. **Precedence (§3.2) as a table**: a crippled boar ignores every stimulus and every sound; a hit
   still beats every perception on the tick it lands.
10. **The alarm.** `obs.sounder.alarm = true` moves an `IDLE` member to `FLEE` within one sense tick;
    with the flag ON, `leaderState = "FLEE"` **alone** does not (one panic path, §2); `leaderCalm` now
    accepts an `ALERT` leader.
11. `CONFIG.CALM_RADIUS - CONFIG.DETECT_RADIUS == CONFIG.SENSE.CALM_MARGIN`.
12. **Determinism**: two brains, one seed, identical intent sequences over 600 steps with `SENSE` ON.
13. **Cost**: 10 000 steps with 4 stimuli under 150 ms.
14. **A partial `SENSE` override keeps every other number** (`newRuntime`'s merge, §6).
15. `REQUIRE_SIGHT = true` with a `probe` that always reports something solid: no notice at any
    distance; with a probe that reports clear: unchanged.

### `tests/server/boar_behaviour_live.spec.luau` — NEW, physically simulated, ~20 s

Builds **its own** world: an anchored 160 × 160 plate at **y = 900** (clear of `boar_body.spec`'s 500
and `match_live.spec`'s 700), a spec-owned folder, `field = { bounds = ±75, exitZ = -60, groundY = 900 }`,
a scripted `threats()` the spec moves itself, and `config = { SENSE = { ENABLED = true } }`. Through the
public interface only:

1. **ALERT, on a real body.** A standing stimulus at 22 studs: within 1.5 s the trunk's
   `CFrame.LookVector` is within 15° of it, `AssemblyLinearVelocity` stays under `WANDER_SPEED`, and
   `runtime:perceptionOf(id).reaction == "alert"`.
2. **Measured motion.** The spec moves the stimulus at ~10 studs/s at 50 studs: within
   `SPEED_SMOOTH_SECONDS * 3` the perception reads `avoid`, and the boar's flat distance to it grows.
   Stop moving it: within the same window the reaction falls back to `none` at 50 studs.
3. **AVOID costs no paths**: `stats().pathRequests` is unchanged across 3 s of AVOID.
4. **Hearing.** Two boars, 30 and 400 studs from a point; `runtime:hearShot(point)` returns 1, the near
   one is `FLEE` within 0.25 s with speed ≥ 0.5 × `SPRINT_SPEED` inside 1.0 s, the far one is still
   `IDLE` after 2 s.
5. **Panic spreads and is visible as spreading.** `spawnSounder(centre, 3)`, then one member takes a
   non-lethal hit through `takeHit`: every member is panicked within `PANIC_DELAY_MAX` + one sense
   tick, and there is at least one sampled step where one member is panicked and another is not.
6. **Single file.** A sounder whose `sounders()[1].formation == "column"` (forced by a seeded `rng`)
   has, after 3 s of fleeing, lateral spread < 7 studs about the leader's axis and consecutive gaps
   within `COLUMN_SPACING_STUDS ± 4`.
7. `afterAll` destroys the runtime and the spec's folder. Production's runtime is untouched.

### Existing specs

`boar_brain`, `boar_sounder`, `boar_body`, `boar_hit`, `boar_shot`, `boar_zones`, `boar_wound`,
`boar_model`, `match_live` and `tests/client/shoot_boar.spec.luau` must pass **unchanged**. That is the
point of the flag: with `SENSE.ENABLED == false` every one of them is testing the same world it tested
before. If any of them has to change, the OFF branch is not equivalent and that is a defect, not a
spec update.

One interaction to note rather than fix: `shoot_boar.spec`'s header says "the boar RUNS as soon as a
player appears within `DETECT_RADIUS`". With the flag ON and the staged player **standing** 22 studs
away, the boar goes `ALERT` instead — which makes that spec easier, not harder, and it asserts the hit
marker, not the running. The Builder must re-read it when the flag's default flips.

### Client spec: none

This system has no client code. **Harness input: not needed and not possible** — the real-stimulus
path with the flag ON cannot run under the harness at all, because `test` and `test2` refuse to start
while an override is set. A new scenario in `tests/client/input_scenarios.txt` would only ever exercise
the OFF branch, which `shoot_boar.spec` already covers; adding one would be a test of the harness, not
of the player's path (rule 6).

### Screenshots (rule 5) — three, from a flag-ON Play session

`python tools/studio_mcp.py capture <name> [camera] [look-at]` works during Play (TASKS Task 7, closed
2026-09-25). The sequence: `python tools/flags.py set BOAR_BEHAVIOUR on`, start the session, walk to a
boar, then `python tools/flags.py clear` before any harness run.

1. **ALERT**: a boar stopped at ~25 studs, head up, **facing the player**. The claim is the facing, and
   it is checkable in the frame.
2. **AVOID**: the same boar, one step later, turned away and trotting off at an angle — not straight
   away, not toward the camera.
3. **Single file**: a sounder crossing in front of a post in a line.

**Starting a Play session with an override set is a human click** (the harness cannot be used for it,
because it refuses the override). If the Builder cannot press Play itself, that is a `NEEDS KAREN`
entry with the exact clicks — not a claim of a screenshot it did not take
(`docs/PROJECT_CONTEXT.md`). Feel — are 25 and 60 right, is the head-up long enough, does the sprint
read — is Karen's, and only hers.

---

## 13. Build order (one task, four commits' worth of work, in this order)

1. `Boar.CONFIG.SENSE` + the `Flags` row + the `newRuntime` merge. Nothing behaves differently.
2. `Brain.CLASS`, `Brain.classOf`, `Brain.isMoving`, `noticeRadius`, `fleeRadius`, `perceive`
   (folding in `_threatInfo`), `avoidTarget`. Pure, flag-OFF equivalent. The pure spec lands here.
3. `ALERT`, `AVOID`, the heard shot, the alarm and the formation, in `Brain:step`, `Runtime:step`,
   `Runtime:hearShot`, `Runtime:_stepSounders`, `Runtime:spawnSounder`, `Runtime:perceptionOf`. The
   live spec lands here.
4. `Weapon.ShotFired`, `Match.Body.boarStimuli`, `Match.boarThreats`, the one `MatchBoot` line, and
   §3.6's two lines behind `BOAR_MODEL`. **This is the commit that puts the task in
   `TWO_PLAYER_PATHS`** (§8).

**Hazards.** (a) The `Runtime` field/method clash guard (`Boar.fieldMethodClashes`) asserts at
construction: `_motion`, `_sounds` and `_alarm*` must not collide with a method name — `sounders` is a
method, `_sounds` is not it, and the guard proves it either way. (b) Rojo 7.7.0 crashes when watched
files disappear; stop `rojo serve` before switching branches and expect a Connect click. (c) New spec
files must be added to `SCOPE_SPECS` or `tools/studio_mcp.py selftest` fails in CI.

---

## 14. Numeric summary of Karen's scene, end to end

A boar grazing in the corridor. A driver walks in at 60 studs → `AVOID`, turns ~120° off and trots at
18 studs/s. The driver closes to 40 → `FLEE`, sprints at 38 studs/s along a navmesh route to
`exitZ = -820`, and the three other members of its sounder are running inside 0.45 s. It reaches the
line, the driver falls behind, and 4 s past `noticeRadius + 30` it drops to `IDLE`. A shooter is
standing on a post 25 studs away → `ALERT`: it stops, turns its head up to him over 0.8 s, holds 1.7 s,
then grazes again and will not re-alert for 8 s. The shooter shifts his feet → `AVOID` at 18 studs/s
across his front. He fires and misses → every boar inside 350 studs is in `FLEE` at 38 studs/s for 4 s.
He hits the rear → `CRIPPLED`, circling, exactly as Task 116 left it.

---

## 15. Open decisions

None of these blocks building: every one has a default in `CONFIG` or in this document.

**Karen (feel) — the "check this" list for the first flag-ON playtest:**
1. `NOTICE_STANDING = 25` / `NOTICE_MOVING = 60` are hers already. The question the playtest answers is
   the **third** number, `FLUSH_STUDS = 15`: how close can you get to a standing boar before it bolts?
2. `ALERT_SECONDS = 2.5` and `ALERT_REFRACTORY_SECONDS = 8`: does the head-up read, and does the animal
   look relaxed between them or twitchy?
3. `AVOID_TURN_DEG = 120` and `AVOID_SECONDS = 4`: is "turn around and go another direction" what she
   meant, or should it be a wider swing / a longer commitment?
4. `SHOT_AUDIBLE_STUDS = 350`: should the whole drive hear the first shot, or only the sounder being
   shot at? This is the one number in the design with no real-world anchor (source 7 cannot supply
   one) and the one most likely to change how a drive plays.
5. `SOUNDER.COLUMN_CHANCE = 0.5`: how often single file, how often a loose group?
6. **Should an alert boar be silent?** Today the calm grunt loop keeps running while it stands
   (`SOUND.GRUNTS.MAX_SPEED = 6`). A real boar that has winded you goes quiet and then blows one
   alarm snort. **No sound change is in this task**; it is one data row when she says so.

**Director (scope):**
1. **Which clip is ALERT** (§3.6). Published → one word in `MODEL.ALERT_CLIP`. Not published → the
   animal plays `idle` and every behaviour is unchanged. No code either way.
2. **Task 117's overlap.** If 117 lands a head-up/scenting activity inside IDLE, it may own that
   posture and `ALERT_CLIP` points at its clip. 118 must not grow its own idle repertoire.
3. **The two-player click.** Keep the `Match`/`MatchBoot` wiring in this task (default: yes, one click
   at merge, §8), or split it into a one-line follow-up task and accept that the boar cannot see
   shooters until that lands — which leaves Karen's central scene unplayable.
4. **Dogs.** `kind = "dog"` and `DOG_NOTICE_SCALE` are hooks with no producer. The first dog task fills
   them in and touches nothing else here.
5. **When the flag's default flips**, the losing branch (drivers-only, one `DETECT_RADIUS`, the
   leader-panic rule) is archived under `backups/` with a note and the row is retired (rule 7,
   `feature-flags.md` lifecycle step 7).

---

## 16. Not verified

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  statement about how a character's replicated position behaves on the server, how `AlignOrientation`
  turns a body toward a new facing, and what a standing character's measured displacement actually
  reads is from documentation and from this repo's own recorded measurements — not observed here.
  `MOVING_SPEED = 2` is the one number in §7.1 that a live session should confirm before the playtest;
  §11 asks the Builder to record it.
- **The URLs, licences and maintenance status of sources 3, 5, 6 and 7.** No network access; those four
  are from my own knowledge, including the two paper citations (authors, journal, year and the
  *relationship* they report are what the design leans on; the page numbers may be off). Sources 1, 2
  and 4 are verified only as cited in this repo. The Builder confirms all seven in the note (§11).
- **The package's other 64 clip names.** `tools/boar_prep.py` validates only against `DEFAULT_CLIPS`
  and its comment names a few of the rest in prose; the full list is not in the repo. So the design
  cannot name the ALERT clip, only describe it (§3.6).
- **Task 117's code.** Not in this worktree (no `reviews/task-117/`, no calm-repertoire rows in
  `BOAR_CLIPS`). The seams in §3.6 and §15 are designed so that whatever 117 landed, 118 needs no
  change — but I have not read 117.
- **Whether the Builder can enter Play with a flag override set without a human click.** `test`/`test2`
  refuse to start with an override, and no other harness command starts Play. §12 therefore treats the
  flag-ON screenshots as possibly needing Karen.
- **`SignalBehavior` of the DEV place.** Not a repo file. `Weapon.ShotFired` is a `BindableEvent` like
  its two neighbours, so a listener may run deferred; `MatchBoot`'s handler only calls
  `runtime:hearShot`, which is order-independent, and the live spec polls rather than asserting on the
  next line.
- **Lint and build at this commit are clean** (`.agent-evidence/lint-selene.txt`,
  `.agent-evidence/rojo-build.txt`, both exit 0). No harness or CI output is in `.agent-evidence/`, so
  nothing here is claimed about the suite's current state.

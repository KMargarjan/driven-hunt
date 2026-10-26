# Design: hit-zones (boar wounding, grey box, v1)

System: `hit-zones` — where a shot landed on a boar, what that does to it, how it behaves while it
dies or gets away, and the one event the score system (1.7) will consume. ROADMAP step 1.5
(`ROADMAP.md`, Milestone 1 table). Task 27.

Architect, 2026-09-25, read-only session: Read, Grep, Glob only. No Studio, no network. Evidence
precomputed in `.agent-evidence/` (`INDEX.md`), commit `67bb585e5d35dfe9fcb6601ed948d6736b006f3f`.

Inputs, in precedence order: `reviews/task-27/BRIEF.md` (the Director's and Karen's decisions), the
boar code on `main` (`src/server/Boar/init.luau`, `Brain.luau`, `Body.luau`,
`src/server/BoarBoot.server.luau`), `docs/design/shotgun.md` §6 (the damage seam),
`docs/design/boar-ai.md`, `docs/design/camera.md` §9.3 (what harness-driven input can and cannot do),
`CLAUDE.md`, `docs/PROJECT_CONTEXT.md`.

**Test of this document:** a Builder can build hit zones and wounded running from it without asking a
question. Every number is here, every owner is named, every interface is written out.

---

## 0. Build precondition, stated first because it decides the branch

Task 24 (the shotgun) is on branch `task-24-shotgun` and is **not merged**. This design's entry point
is the seam that task builds: `Boar.Body` publishing the attributes `Damageable` and `HitZone`,
`Runtime:takeHit(part, hit)` with `hit = { zone, ammo, pellets, at }`, and the wiring from
`Weapon.HitReported` in `BoarBoot.server.luau` (`reviews/task-27/BRIEF.md`; `docs/design/shotgun.md`
§6.3, §6.4, §6.5).

**I could not read that branch.** The Architect session is one worktree at one commit with Read, Grep
and Glob (`CLAUDE.md`, "The agent scripts"), and at this commit `src/server/Boar/Body.luau` sets no
attributes and `src/server/Boar/init.luau` has no `takeHit`. So everything this design says about the
shotgun side is read from `docs/design/shotgun.md` and the brief, not from code. §2 states exactly
what it assumes and what the Builder must check first; §15 repeats it as a non-verification.

Therefore: **branch `task-27-hit-zones` from `task-24-shotgun` (a stacked PR) if Task 24 is still
unmerged when this is built, and say so in the review request.** Every change in §3.4 is inside
`src/server/Boar/` plus the two wiring lines in `BoarBoot`, all of which Task 24 also touches, so
building on `main` would mean merging the same files twice.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

From Karen's v1 spec as the brief states it, and `ROADMAP.md` row 1.5:

1. **Four zones on the boar.** HEAD and CHEST (heart/lungs) kill. BODY (belly, flank, rear) wounds:
   the boar runs a **short** way and drops. LEGS / hindquarters: several hits needed; it runs **far**
   before dropping, **or escapes**.
2. **Per-pellet zones.** A buckshot shot puts its pellets in different zones and each one counts; a
   slug is one hit in one zone.
3. **One owner for boar health and wound state**, and it is the boar's own runtime, not the weapon
   (rule 3; brief).
4. **A visible reaction to every hit**, so Karen can answer the question her playtest left open ("too
   early to say if I can hit anything"). Visible means: the boar bolts the instant it is hit, whatever
   it was doing, and it flashes.
5. **A carcass.** A killed boar stays in the world as a carcass for a configured time before it is
   removed.
6. **A kill event and an escape event**, carrying everything the score system (1.7) needs: who shot
   it, which zone, which ammo, at what distance, the killing shot versus the wounds before it, and —
   for an escape — whether it got away wounded.
7. Every number in **one config table**, with Karen's feel values marked (brief).

### 1.2 Must not

Each row is a named failure of the previous project (`docs/PROJECT_CONTEXT.md`, "Why the rules exist")
or a boundary an existing design already drew, written as a prohibition.

| Prohibition | Why | Whose job instead |
|---|---|---|
| The weapon must not gain a damage number, a zone table or a health concept | "One predicate answered two unrelated questions"; and `docs/design/shotgun.md` §1.2 already forbids the weapon a zone→reaction table | `ServerScriptService.Boar` (§3.1) |
| Nothing outside `Boar.Body` may create, destroy, colour, weld or move a boar Instance — including the new zone parts | `Boar.Body` is "the only writer of a boar's Instances" (`src/server/Boar/Body.luau` header) | `Boar.Body` |
| The `Brain` must stay pure: no services, no clocks, no Instances, no `os.clock`, no randomness but the injected `Random` | it is what lets `tests/server/boar_brain.spec.luau` drive 10 000 ticks with no physics | the Runtime injects; the Brain decides |
| The `Wound` module must be pure and must own **no** state: it takes a wound state and returns a new one | one decision in one place, and the whole damage model testable with no world | `Runtime:takeHit` is the only place a wound state is stored |
| No client code at all: no LocalScript, no RemoteEvent, no hit marker, no damage number on screen, no blood | `docs/design/boar-ai.md` §2 keeps this system server-only; anything drawn belongs to `PlayerScripts.Hud` (`docs/design/shotgun.md` §3.4) | §14 Director item C if a hit marker is wanted |
| No blood trail, no tracking, no dogs | v1.1 (`ROADMAP.md` scope table; brief) | — |
| No score, no points, no teams, no respawn, no spawn waves | 1.7 (`ROADMAP.md`) | this system publishes `Downed` and `Despawned` and stops there |
| No `Humanoid`, no `Health` property, no `TakeDamage` | the boar is a driven Part, not a character (`docs/design/boar-ai.md` §2); a `Humanoid` would bring Roblox's own state machine as a second writer | the `Wound` module's damage points |
| No `.model.json` or `.meta.json` for the zone parts | the harness fails typed property values as "cannot compare" (`tools/studio_mcp.py` docstring, check 4); audit-002 must-fix 1 is open (`TASKS.md` row 16) | §4: zone parts are built in code, as the body and the arena already are |
| No new Wally package, no `default.project.json` change | `wally.lock` and `devpackages.sha256` are pinned against the commit, and a project-file change costs Karen a Connect click (`CLAUDE.md`, Toolchain) | nothing here needs either |
| A dead boar must not keep taking hits or fire a second kill | a double-count in 1.7's score is a bug that looks like a cheat | §7.2: `Damageable` goes false on collapse, and `takeHit` refuses a downed boar |
| The boar must not be despawned at the moment of death | the carcass is the point (brief item 5) | §7.3: `Downed` at death, `Despawned` at `CARCASS_SECONDS` |

**One predicate answers one question.** `Wound.severity` says how badly hurt the boar is. It does not
say whether the boar is fleeing, whether it is visible, whether it may be shot again, or whether the
score should count it. Those are four different questions with four different answers in §8.

---

## 2. The seam this design builds on, and what it assumes about it

### 2.1 What Task 24 delivers (assumed, from `docs/design/shotgun.md` §6 and the brief)

- `Boar.Body.create` sets, on the boar's Part: `Damageable = true`, `HitZone = "body"`.
- `Runtime:takeHit(part: BasePart, hit: Hit): boolean` — `true` when the part is one of its live
  boars. Its v1 body increments counters, stores `lastHit`, fires `Runtime.Hit` and changes nothing
  about the boar's state, speed or lifetime (`docs/design/shotgun.md` §6.5).
- `Hit = { zone: string, ammo: string, pellets: number, at: number }`, `zone = "body"` today.
- `BoarBoot.server.luau` connects `Weapon.HitReported` to `runtime:takeHit`, so neither owner requires
  the other.
- `Weapon.HitReported` carries a `HitReport` with, among others: `shooter: Player`, `target: Instance`,
  `zone: string` (dominant), `zones: { [string]: number }` (the full per-pellet tally), `pellets`,
  `nearest: number` (studs, muzzle to the closest impact), `position: Vector3`, `normal: Vector3`,
  `ammo`, `at` (`docs/design/shotgun.md` §5.1).

### 2.2 What this design changes about it, and what it deliberately does not

**The weapon does not change at all.** Not one file under `src/server/Weapon/`, `src/client/Weapon/`
or `src/shared/Shotgun/`. That is the test `docs/design/shotgun.md` §6.4 set for its own seam — "when
Milestone 1.5 replaces the box with a multi-part body, each part carries its own `HitZone` and
**nothing in the weapon changes**" — and this design is the task that either passes it or exposes it.
If the Builder finds it cannot be done without touching the weapon, that is a finding about the seam
and belongs in `ESCALATE.md`, not a quiet edit.

**Two things widen, both additively:**

1. `Hit` gains optional fields (§8.1). Task 24's four fields keep their names and meanings, so Task
   24's `tests/server/boar_hit.spec.luau` keeps passing unchanged. Everything new is optional and has
   a stated fallback, so a `takeHit` call written against the Task 24 shape still works.
2. `BoarBoot`'s one connection maps more of the `HitReport` it already receives into that payload
   (§9.2). No new read of another system's internals: every field already exists on the report.

### 2.3 What the Builder checks before writing anything

Rule 8, and the reason §15 exists. On the branch, confirm and report:

- the real field names on `HitReport` and on `takeHit`'s `hit` argument (this design's names come from
  a design document, not from code);
- that `Hits.targetOf` walks **ancestors** for `Damageable == true` and reads `HitZone` from the **hit
  instance first**, falling back to the root. §4 depends on exactly that: the zone parts are children
  of the boar's Part, so the ancestor walk must find the Part and the zone must come from the child.
  If Task 24 implemented it as "read `HitZone` from the root only", §4 does not work and the one-line
  fix is in `Hits.targetOf` — a weapon change, which §2.2 forbids without an escalation;
- that `report.zones` really carries the per-pellet tally (item 2 of §1.1 depends on it; without it
  buckshot degrades to "all pellets in the dominant zone", which §5.4 makes the explicit fallback).

---

## 3. Ownership

Rule 3: exactly one writer per system, named here, mirrored into `GAME_DESIGN.md` (§13).

### 3.1 No new system owner, and that is the decision

Hit zones, damage, wounded running and death are **boar state**. Boar state has one writer and it is
already named: `ServerScriptService.Boar` (`GAME_DESIGN.md`, Boar row; `docs/design/boar-ai.md` §3).
This design adds a private module to it and widens its published events. It does **not** create a
"damage system", a "health service" or a "combat manager".

Stated so it is overruled on purpose rather than by accident: a damage/health system of its own is the
right answer when there are three animals, two weapons and a player damage model. Today there is one
animal and one weapon, and a third owner between them would be the "invented foundations" failure at
small scale (`docs/PROJECT_CONTEXT.md`). `docs/design/shotgun.md` §6.2 made the same call about a
damage router and §15 item B queued the revisit; this design does not re-open it. §14, Director item
A, is where it is revisited.

### 3.2 The modules

| Module | Is | Never |
|---|---|---|
| `src/server/Boar/init.luau` → `ServerScriptService.Boar` | **the owner**: `CONFIG` (now including `ZONES` and `WOUND`), the runtime list, each boar's **wound state**, the Heartbeat loop, the `Despawned`, `Hit` and new `Downed` signals | decides damage numbers itself; touches Instances directly |
| `src/server/Boar/Wound.luau` → `…Boar.Wound` **(new)** | **pure**: the whole damage model. `(woundState, hit, config) -> (woundState, event)`, plus `severity`, `flightStuds`, `speedScale`, `advance`, `killRecord` | holds state, touches Instances, services, clocks, `Player` or `Random` |
| `src/server/Boar/Brain.luau` → `…Boar.Brain` | boar **decision** state; gains the `WOUNDED` and `DOWN` states and the bolt reaction | knows a damage number, a zone name's meaning, or the config's `DAMAGE` table |
| `src/server/Boar/Body.luau` → `…Boar.Body` | **every boar Instance**, now including the three zone parts, their welds, their attributes, the hit flash and the collapse | decides anything; reads the wound state |
| `src/server/BoarBoot.server.luau` | nothing. Boot and wiring only | owns state |

`Boar.Wound` is exported as `Boar.Wound` for specs, exactly as `Boar.Brain` already is
(`src/server/Boar/init.luau`, `Boar.Brain = Brain`), and for the same reason: the pure core must be
drivable with no world.

**Why `Wound` is a module and not ten lines inside `takeHit`.** The damage table, the two thresholds,
the flight formula and the speed ramp are the numbers Karen will retune after every playtest. Pure and
separate, they are 30 assertions in a spec that runs in microseconds; inside `takeHit` they are
testable only with a live boar and a physics frame. This is the same split
`docs/design/boar-ai.md` §3 already made between `Brain` and the Runtime.

### 3.3 Who writes what, within the system

| Thing | Sole writer | Read by |
|---|---|---|
| `entry.wound` (one frozen `WoundState` per boar) | `Runtime:takeHit` and `Runtime:step` (through `Wound`'s pure returns) | the Brain, as a summary in the Observation; `Runtime:woundOf` returns a copy |
| boar decision state (`_state`, heading, flight timers) | `Brain` | `Runtime`, through the `Intent` |
| every boar Instance, attribute, colour and weld | `Body` | nothing writes them; the weapon **reads** two attributes |
| `Hit`, `Downed`, `Despawned` | `Runtime` | 1.7's score, later. Nothing writes back |

The Brain never writes the wound state and the Wound module never decides a state transition. That
boundary is the one thing in this design that must not be blurred at build time: two systems writing
one creature's state is the named cause of death of the previous project.

### 3.4 Files on disk

```
src/server/Boar/
  init.luau        CHANGED  owner: CONFIG.ZONES, CONFIG.WOUND, entry.wound, takeHit, Downed, stats
  Wound.luau       NEW      the pure wound model
  Brain.luau       CHANGED  WOUNDED and DOWN states, the bolt reaction, the carcass timer
  Body.luau        CHANGED  zone parts + welds + attributes, flash, collapse, carcass marking
src/server/BoarBoot.server.luau   CHANGED  two more fields in the existing takeHit call (§9.2)
tests/server/boar_wound.spec.luau NEW      pure: the damage model
tests/server/boar_brain.spec.luau CHANGED  pure: the new states and the reaction
tests/server/boar_zones.spec.luau NEW      live: zone geometry, proved with real rays
tests/server/boar_hit.spec.luau   CHANGED  live: the seam, the kill event, the carcass
docs/research/2026-09-25-hit-zones.md NEW  rule 1 (§10 is its starting source set)
```

No new `default.project.json` mapping: a folder with `init.luau` takes its siblings as children, which
`src/server/Boar/` already proves (`Brain.luau`, `Body.luau` compare green — `TASKS.md` row 18).

**Rule 1, and it is the Builder's, not mine.** `docs/research/` belongs to the Builder (`CLAUDE.md`,
Roles). Before code, write `docs/research/2026-09-25-hit-zones.md` with the sources in §10 — confirming
each URL, licence and maintenance status, which I could not (§15) — and index it in
`docs/research/INDEX.md`. Rule 9: `Wound.luau` carries the pattern name, its source links and that note
path in its header, as `Brain.luau` and `Body.luau` already do.

---

## 4. Zone geometry on the grey-box boar

### 4.1 The problem a naive version gets wrong

The boar is **one** `Part`, 2 × 3 × 5.5 studs, built by `Body.create`
(`Boar.CONFIG.BODY_SIZE = Vector3.new(2, 3, 5.5)`; width X, height Y, length Z, with a Part's
`LookVector` its −Z, so **−Z is the boar's front**). The weapon finds a zone by reading the `HitZone`
attribute of the instance the ray hit (`docs/design/shotgun.md` §6.4). One part carries one attribute,
so one part is one zone.

The obvious fix — put four zone parts **inside** the box — does not work, and this is the trap worth
naming: a raycast returns the first surface it meets, which is the outer box. Every shot would report
`body`. A spec that called `takeHit` directly with `zone = "head"` would pass while no player could
ever produce a head hit. That is "the harness was wrong as often as the game"
(`docs/PROJECT_CONTEXT.md`), and §12.3 is the spec written specifically to make it impossible.

### 4.2 The shape: one trunk, three zone parts that protrude

The trunk Part stays exactly what it is — the physics body, the assembly root, the network-owned
thing, the target root carrying `Damageable` — and keeps `HitZone = "body"`. It is therefore the
**default zone**: belly, flank, rear and brisket are whatever no zone part covers, which is precisely
Karen's BODY definition.

Three child parts cover the zones that differ, each **protruding past the trunk surface on every face
a pellet can arrive from**, so the ray meets the zone part first.

Local coordinates: origin at the trunk's centre; x ∈ [−1, 1], y ∈ [−1.5, 1.5], z ∈ [−2.75, 2.75];
**−Z is forward**, +Y is up.

| Part | `HitZone` | Size (studs) | Centre offset (local) | Occupies | Why |
|---|---|---|---|---|---|
| `ZoneHead` | `head` | `(1.2, 1.2, 1.4)` | `(0, 0.5, -3.2)` | x ±0.6, y −0.1…1.1, z −3.9…−2.5 | a real head: **1.15 studs proud of the front face**, so it is hit from the front, both sides and above — and the boar visibly has a front, which the plain box never did |
| `ZoneChest` | `chest` | `(2.12, 2.01, 1.7)` | `(0, 0.555, -1.6)` | x ±1.06, y −0.45…1.56, z −2.45…−0.75 | heart/lungs behind the shoulder. Proud by 0.06 on both flanks **and the top**, so a broadside or a downhill shot lands in it |
| `ZoneLegs` | `legs` | `(2.12, 1.0, 5.4)` | `(0, -1.0, 0.15)` | x ±1.06, y −1.5…−0.5, z −2.55…2.85 | the bottom third over the whole length, proud by 0.06 on both flanks and **0.1 past the rear face** — so a shot at the hindquarters from behind reads `legs`, which is the brief's "LEGS / hindquarters" |

Everything else is the trunk: `body`. A flank shot between y = −0.5 and y = +1.5 behind z = −0.75,
the belly seen from below behind the legs band, the rear above the hams, the brisket low at the front.

**Where the brief is ambiguous, and how it is resolved.** It says "BODY (belly, flank, **rear**)" and
also "LEGS / **hindquarters**". This design splits them by height, not by front/back: the rear *above*
the legs band is `body`, the rear *within* it (the hams and the back legs) is `legs`. That is the
reading that makes both sentences true at once, and it is one number (`ZoneLegs` height) if Karen
disagrees — §14, Karen item 3.

### 4.3 Properties of the zone parts, and why each one

Built in code in `Body.create`, after the trunk is parented (a `WeldConstraint` needs both parts in
the DataModel), and parented **to the trunk Part**, not to the folder:

| Property | Value | Reason |
|---|---|---|
| `Parent` | the trunk Part | `Hits.targetOf` walks **ancestors** for `Damageable == true`; a child of the trunk resolves to the trunk as the target, and its own `HitZone` as the zone. This is what keeps `takeHit(part, hit)` taking the same `BasePart` as today |
| `Massless` | `true` | the assembly's mass, centre of mass and inertia stay what they were, so `MAX_FORCE`, `MAX_TORQUE` and `ACCEL` in `Boar.CONFIG` remain correct and `tests/server/boar_body.spec.luau` keeps passing (§10 source A) |
| `CanCollide` | `false` | the collision body stays the trunk box. A protruding head that collided would catch on the arena's cover blocks and change how the boar routes — a movement change smuggled in by a hit-zone task |
| `CanQuery` | `true` | it must be raycastable; that is its whole purpose |
| `CanTouch` | `false` | nothing uses `Touched`, and leaving it on costs touch events per frame |
| `Anchored` | `false` | an anchored child welded to the assembly would anchor the boar (§10 source A) |
| joint | one `WeldConstraint` per zone part, `Part0` = trunk, `Part1` = zone part | rigid, no joint maths, the documented modern way (§10 source A) |
| `Color` | `CONFIG.WOUND.ZONE_TINT and CONFIG.ZONES[zone].tint or CONFIG.BODY_COLOR` | grey-box teaching aid; one boolean turns it off (§11, Karen's dial) |
| `Material` | `SmoothPlastic` | matches the trunk and the arena idiom |
| attribute `HitZone` | `"head"` / `"chest"` / `"legs"` | the weapon's contract (`docs/design/shotgun.md` §6.4 source E) |
| attribute `Damageable` | **not set** | it belongs on the target root only. Two `Damageable` instances in one ancestor chain is an ambiguity, not a feature |
| `Name` | `ZoneHead` / `ZoneChest` / `ZoneLegs` | greppable; a spec finds them by name |

The trunk keeps `Damageable = true` and `HitZone = "body"` exactly as Task 24 sets them.

### 4.4 What this does not disturb, checked against the code on `main`

- `tests/server/boar_body.spec.luau` counts `BasePart` **children of the runtime's folder** and
  expects 1. Zone parts are children of the trunk, not of the folder, so the count stays 1. This is
  the kind of detail that turns a green run red for a reason unrelated to the change, so it is written
  down rather than discovered.
- `Body.destroy` destroys the trunk; children go with it. Unchanged.
- `Body.drive` writes `handle.mover.PlaneVelocity` and `handle.upright.CFrame`. Unchanged.
- `part:SetNetworkOwner(nil)` is per **assembly**, so the welded zone parts follow. Unchanged.
- `Boar.defaultWorld().probe` excludes the whole boar folder, so a boar never probes its own or
  another boar's zone parts. Unchanged.
- The camera's occlusion ray (`docs/design/camera.md` §7 source G) can now hit a protruding head. That
  is the same thing as hitting the boar; no behaviour is different.

### 4.5 When art arrives (Milestone 2)

`Body.create` clones a template instead of building a box (`docs/design/boar-ai.md` §9), and the
template's parts carry their own `HitZone` attributes. Nothing in `Wound`, `Brain`, the weapon or this
design's numbers changes, because none of them names a part — they name a **zone string**. The zone
strings are the durable contract; the boxes are grey-box geometry.

---

## 5. The wound model

### 5.1 The two quantities, and why there are two

A single health pool cannot express Karen's spec. Under one pool, more damage always means a shorter
run — so a leg hit, which needs *more* hits, would drop the boar *sooner* than a body hit. Her spec
says the opposite: legs run far. So the model carries two numbers per zone:

- **damage** (points, toward death), which decides *whether* it dies;
- **flight** (studs), which decides *how far it gets first*.

That split is the model, and it is the one thing in §5 worth arguing about. It matches how hunters
describe it and how the wounding literature measures it — flight distance is a property of **where**
the animal was hit, not only of how hard (§10 sources C and D).

### 5.2 The table

`Boar.CONFIG.WOUND.DAMAGE[zone]`, points. One slug is one hit; each buckshot pellet is counted
separately.

| Zone | Slug | Buckshot pellet | Flight (studs) |
|---|---|---|---|
| `head` | 100 | 34 | 0 |
| `chest` | 100 | 25 | 0 |
| `body` | 55 | 11 | 120 |
| `legs` | 30 | 6 | 420 |
| `unknown` | uses the `body` row | uses the `body` row | uses the `body` row |

`LETHAL = 100`, `MORTAL = 50`.

`unknown` is the zone the weapon reports when no `HitZone` attribute was found
(`docs/design/shotgun.md` §5.3, `Hits.targetOf`). It must never crash and must never be silently
free: it is charged as `body` **and** counted in `Runtime:stats().unknownZoneHits`, so a typo in an
attribute name shows up as a number instead of as an animal that will not die.

### 5.3 The rules

```
damage      = sum over every pellet of DAMAGE[zone][ammo]
severity    = "lethal"  if damage >= LETHAL
            = "mortal"  if damage >= MORTAL
            = "grazed"  if damage >  0
            = "healthy" otherwise

maxFlight   = max FLIGHT[zone] over zones with damage > 0
span        = LETHAL - MORTAL                              -- 50
over        = clamp(damage - MORTAL, 0, span)
flightStuds = maxFlight * (1 - over / span)                -- studs it runs before collapsing
```

- **lethal** → it drops where it stands, this tick. `flightStuds` is 0 by construction.
- **mortal** → it will die. It bolts and runs; when the distance it has run since the mortal wound
  reaches `flightStuds`, it collapses. `BLEED_OUT_MAX_SECONDS` is a hard ceiling so a wounded boar
  wedged against a wall cannot live forever.
- **grazed** → it is hurt but will not die of it. It bolts and keeps going, and it can escape. More
  hits accumulate into the same total.

A later hit **never lengthens** the run: `flightStuds` is a decreasing function of `damage`, and the
distance already run is not reset. That property is one assertion, not a comment (§12.1 item 9).

Worked, so the numbers can be argued with rather than trusted:

| Shot | damage | severity | flight | Reads as |
|---|---|---|---|---|
| slug, head | 100 | lethal | 0 | drops on the spot ✔ Karen's spec |
| slug, chest | 100 | lethal | 0 | drops on the spot ✔ |
| slug, body | 55 | mortal | 120 × (1 − 5/50) = **108 studs** ≈ 4 s | "runs a short way, then drops" ✔ |
| slug, legs | 30 | grazed | — | runs on; one leg hit is not enough ✔ |
| 2 × slug, legs | 60 | mortal | 420 × (1 − 10/50) = **336 studs** ≈ 16 s | "several hits, runs far — or escapes" ✔ (336 studs in a 400-stud arena usually means it reaches the exit line first) |
| slug body + slug legs | 85 | mortal | 420 × (1 − 35/50) = **126 studs** | a second hit shortens the run ✔ |
| 9 buck pellets, chest, close | 225 | lethal | 0 | drops ✔ |
| 3 buck pellets, chest, far | 75 | mortal | 0 (chest flight is 0) | drops ✔ — a lung hit is a lung hit |
| 1 buck pellet, head, far | 34 | grazed | — | runs on. A single pellet in the head at distance is not a kill, and should not be |
| 4 pellets body + 2 legs, mixed | 44 + 12 = 56 | mortal | 420 × (1 − 6/50) = **370 studs** | a pattern that caught the hindquarters tracks a long way ✔ |

### 5.4 Buckshot: per-pellet zones, and the honest fallback

`Wound.apply` uses `hit.zones` — the per-zone pellet tally from the weapon's `HitReport` — when it is
present, charging `DAMAGE[zone].Pellet` once per pellet in that zone. That is brief item "Buckshot
pellets each hit a zone".

If `hit.zones` is absent (a slug, an older caller, or Task 24 not carrying it), every pellet is
charged at the **dominant** `hit.zone`. Stated, not silent: `Runtime:stats().tallylessHits` counts it,
so "buckshot zones do not work" is a number in the harness report rather than a feeling in a playtest.

### 5.5 Speed while wounded — the second visible signal

```
bleed = WOUND_SPEED_START + (WOUND_SPEED_END - WOUND_SPEED_START) * clamp(flightRun / flightStuds, 0, 1)
        -- 1.0 -> 0.45 over the flight; 1.0 when not mortal
limp  = LIMP_SCALE if damage in the `legs` zone > 0 else 1.0
speedScale = bleed * limp
```

Applied by the Brain to its speed **setpoint** in `FLEE` and `WOUNDED` — never to the physics, exactly
as `TURN_RATE` and `ACCEL` are applied to the setpoint today (`docs/design/boar-ai.md` §5). So it is
assertable with no physics at all.

Why it earns its place: a leg-shot boar that visibly slows is the difference between "I hit it" and
"nothing happened" at 80 studs, and `SPRINT_SPEED * LIMP_SCALE = 28.5` studs/s is still well above a
player's walk speed of 16, so a limping boar is not a free kill — it is a boar you can now keep up
with. That is the drive mechanic in miniature, and it is one number if Karen disagrees.

---

## 6. The Brain: new states, and how they reuse flee and route

### 6.1 States

`State = "IDLE" | "FLEE" | "WOUNDED" | "DOWN" | "GONE"` — two added to the three in
`docs/design/boar-ai.md` §5.

| State | Speed setpoint | Path | Leaves when |
|---|---|---|---|
| `IDLE` | unchanged | none | unchanged; **plus**: any hit → `FLEE` or `WOUNDED` or `DOWN`, immediately |
| `FLEE` | unchanged, × `speedScale` | unchanged | unchanged; **plus**: a mortal wound → `WOUNDED`; a lethal wound → `DOWN` |
| `WOUNDED` | `SPRINT_SPEED` × `speedScale` while bolting, then exactly `FLEE`'s rule × `speedScale` | **identical to `FLEE`**: same `_fleeDirection`, same `_routeTarget`, same repath interval, same stuck handling | `flightRun ≥ flightStuds` or `woundedFor ≥ BLEED_OUT_MAX_SECONDS` → `DOWN`; crossing `exitZ` → `GONE` with reason `escaped`; **never returns to `IDLE`** |
| `DOWN` | 0 | none | `CARCASS_SECONDS` elapsed → `despawn = true, reason = "killed"` → `GONE` |
| `GONE` | 0 | none | terminal, unchanged |

**`WOUNDED` is `FLEE` with three differences and no fourth.** It does not calm down (a mortally wounded
animal does not go back to grazing); its speed is scaled; and it is counting studs. Everything about
where it runs — the route to the exit line, the sideways bias away from the threat, the doubled bias
when a threat is in the way, the navmesh waypoints, the Reynolds fallback when a path fails, the stuck
sidestep — is the existing code, called from the existing place. That is brief item "how they reuse
flee/route", and it is also the reason this task does not re-open a tested state machine.

### 6.2 The reaction to being hit — before the sense gate, and that is the point

`Brain:step` senses on a `SENSE_INTERVAL = 0.2 s` accumulator. A reaction that waited for the next
sense tick would be up to 200 ms late and would sometimes look like nothing happened.

So: **hit events are handled at the top of `Brain:step`, before the sense gate, before anything else
but the despawn check.** For every hit in `obs.hitEvents` (a list, because two pellets from two
shooters can land in one tick):

1. Record the shot point: `self._lastShotPoint = event.from` (flat), if given.
2. `severity == "lethal"` → `self._state = "DOWN"`, and nothing else matters this tick.
3. otherwise → `self._state = "WOUNDED"` if `severity == "mortal"`, else `"FLEE"` if currently `IDLE`
   or `FLEE`. A `WOUNDED` boar stays `WOUNDED`.
4. **Bolt:** `self._boltFor = BOLT_SECONDS`; `self._grazeFor = 0`; `self._sinceCalm = 0`;
   `self._sinceRepath = math.huge` (path immediately, as the IDLE→FLEE transition already does); and
   `self._speed = math.max(self._speed, SPRINT_SPEED * BOLT_KICK)` — a single documented bypass of the
   `ACCEL` ramp, because a shot animal does not accelerate over 0.63 s. It is the one place in the
   system where the ramp is skipped, and it is skipped once per hit, by assignment, not by a new rule.
5. While `_boltFor > 0`, the boar sprints and is treated as threatened whether or not a player is
   inside `DETECT_RADIUS`, and `_threatPoint` falls back to `_lastShotPoint`. So the existing
   `_routeTarget` runs the boar away from **the shooter**, using code that already works, even when
   the shooter is 200 studs away and would never have registered as a threat.

**Numeric target:** the state change is visible within **one Heartbeat tick (≤ 17 ms at 60 Hz)** of
`takeHit`, not one sense interval. Asserted in the pure spec (§12.1 item 5) and in the live spec.

### 6.3 Escape, and what happens to a boar that gets away hurt

`Brain:_outcome` currently returns `escaped` only in `FLEE`. It gains `WOUNDED`:

```luau
if (self._state == "FLEE" or self._state == "WOUNDED") and position.Z <= field.exitZ then
    return "escaped"
end
```

The out-of-bounds rule is unchanged and still applies in any state. A `DOWN` boar is stationary and
inside the field by construction, so the carcass never trips either.

An escaped boar that was mortally wounded still fires `Despawned` once, with `reason = "escaped"` and
the wound payload attached (§8.3). That is the brief's "An escaped wounded boar is also an event": 1.7
decides whether it is a penalty, a partial score or nothing. This system does not decide, and must
not.

### 6.4 `DOWN` and the carcass timer

`DOWN` is entered from any live state. On entry (once, guarded by a flag exactly as `_despawned`
already guards the despawn report):

- `intent.downed = true` — the Runtime's signal to collapse the body and publish the kill;
- `intent.targetVelocity = Vector3.zero` and `intent.facing = nil` for every subsequent tick;
- `self._carcassFor = CARCASS_SECONDS`, counted down with `dt` (the same clamped `dt` the rest of the
  Brain uses, so the pure spec can run it in simulated time);
- at zero: `intent.despawn = true, intent.reason = "killed"`, `state = "GONE"` — reusing the despawn
  path that already exists, including `Body.destroy`, `releasePath` and the `Despawned` signal.

No `task.delay`, no `os.clock`, no `Debris` inside the Brain. The Brain stays pure; §12.1 item 12
runs a whole carcass lifetime in a few milliseconds of simulated ticks.

---

## 7. The Body: flash, collapse, carcass

All three are `Boar.Body`, which is the only writer of a boar's Instances.

### 7.1 The hit flash

`Body.setFlash(handle, seconds)` starts it; `Body.stepFlash(handle, dt)` is called once per boar per
Runtime step and **writes a colour only on a transition** (flash on, flash off) — not every frame.
Two property writes per hit, not 120.

It flashes the trunk **and** the zone parts to `FLASH_COLOR`, then restores each part's own base
colour, which `Body` remembers per part when it creates them (so the zone tint survives a flash —
restoring everything to `BODY_COLOR` would silently erase the tint after the first hit).

Why it exists: a 0.25 s red flash is the cheapest unambiguous answer to "did I hit it?" at 100 studs
with no sound, no animation and no hit marker, and it costs no new owner — colour on a boar part is
already `Body`'s.

### 7.2 The collapse

`Body.collapse(handle)`, called by the Runtime when `intent.downed` arrives, exactly once:

1. `mover.PlaneVelocity = Vector2.zero`, then `mover.Enabled = false` — the drive stops.
2. `upright.Enabled = false` — the `AlignOrientation` that keeps the box upright lets go, so the boar
   **topples** instead of standing dead. That is the visible difference between "dropped" and
   "paused", and it costs one property.
3. `part:ApplyAngularImpulse(right * COLLAPSE_ANGULAR_IMPULSE)` where `right` is the body's local X
   axis — one nudge so it reliably falls on a side rather than balancing. A physics number: §15 marks
   it unverified and §12.4 puts it in a screenshot.
4. `part:SetAttribute("Damageable", false)` — the weapon's `targetOf` now finds no damageable root, so
   further pellets are a miss and produce no report. No second kill can be counted.
5. `part:SetAttribute("Carcass", true)` — a marker for 1.7 and for any later score UI, readable
   without requiring `Boar`. An attribute rather than a `CollectionService` tag because the harness
   compares attributes and does not compare tags (`docs/design/shotgun.md` §10 source E).
6. `CanCollide` stays `true`, so the carcass lies on the ground instead of falling through it.

`takeHit` also refuses a boar whose state is `DOWN` or `GONE` and returns `false`. Belt and braces:
the attribute stops the weapon reporting, and the runtime check stops anything else that calls the
seam directly.

### 7.3 The carcass

It is just the collapsed body, kept for `CARCASS_SECONDS`, then destroyed by the existing despawn
path. It is not a new Instance, not a new folder and not a new owner. `maxBoars` already bounds how
many can exist.

---

## 8. Public interface

Types are Luau annotations. `luau-lsp analyze` is not in CI (`TASKS.md` row 3), so they are
documentation plus editor checking, not a gate — the status `docs/design/boar-ai.md` §4 records.

### 8.1 Shared types

```luau
-- ServerScriptService.Boar
export type State = "IDLE" | "FLEE" | "WOUNDED" | "DOWN" | "GONE"
export type DespawnReason = "escaped" | "outOfBounds" | "killed"
export type HitZone = "head" | "chest" | "body" | "legs" | "unknown"
export type Severity = "healthy" | "grazed" | "mortal" | "lethal"

-- What arrives at the seam. Task 24's four fields are unchanged; everything else is optional.
export type Hit = {
    zone: HitZone,                      -- the dominant zone (Task 24)
    ammo: string,                       -- "Slug" | "Buck" (Task 24)
    pellets: number,                    -- total on this target (Task 24)
    at: number,                         -- os.clock() on the server (Task 24)
    zones: { [string]: number }?,       -- pellets per zone; nil -> all pellets at `zone` (§5.4)
    distance: number?,                  -- studs, muzzle to nearest impact (HitReport.nearest)
    shooterUserId: number?,             -- durable identity; NOT the Player instance (§8.4)
    shooterName: string?,
    shooterPosition: Vector3?,          -- best effort, for the bolt direction
    normal: Vector3?,                   -- fallback bolt direction when shooterPosition is nil
}

export type WoundRecord = {             -- one per takeHit that landed
    at: number,
    zone: HitZone,
    ammo: string,
    pellets: number,
    damage: number,                     -- points this hit added
    distance: number?,
    shooterUserId: number?,
    shooterName: string?,
}

export type WoundState = {              -- frozen; one per live boar; only the Runtime holds one
    damage: number,
    byZone: { [string]: number },       -- damage per zone
    severity: Severity,
    flightStuds: number,                -- 0 when not mortal
    flightRun: number,                  -- studs run since the mortal wound
    flightSeconds: number,
    wounds: { WoundRecord },            -- in order
    contributors: { [number]: number }, -- userId -> damage points
    mortalWound: WoundRecord?,          -- the hit that crossed MORTAL or LETHAL
}

export type KillRecord = {
    id: string,
    at: number,
    position: Vector3,
    killedByUserId: number?,
    killedByName: string?,
    killingZone: HitZone,
    killingAmmo: string,
    killingDistance: number?,
    instant: boolean,                   -- true = dropped on the spot (lethal), false = bled out
    flightStuds: number,                -- how far it ran after the mortal wound
    flightSeconds: number,
    damage: number,
    shots: number,                      -- how many takeHits landed
    wounds: { WoundRecord },
    contributors: { [number]: number },
    aliveFor: number,
}
```

### 8.2 `Boar.Wound` — pure, and the whole damage model

```luau
Wound.new(): WoundState                                          -- frozen, zero
Wound.damageFor(zone: HitZone, ammo: string, pellets: number, config): number
Wound.apply(state: WoundState, hit: Hit, config): (WoundState, Severity)
    -- returns a NEW frozen state and the severity AFTER the hit. Never mutates its input.
Wound.severity(state: WoundState, config): Severity
Wound.flightStuds(state: WoundState, config): number
Wound.speedScale(state: WoundState, config): number              -- §5.5, 1.0 when healthy
Wound.advance(state: WoundState, movedStuds: number, dt: number, config): (WoundState, boolean)
    -- accumulates flightRun/flightSeconds while mortal; the boolean is "collapse now"
Wound.killRecord(state: WoundState, id: string, position: Vector3, aliveFor: number): KillRecord
```

No `game:GetService`, no clock, no `Player`, no `Instance`, no `Random`. `config` is a parameter, not a
lookup, so a spec passes its own table and the whole model is testable in microseconds — the same
discipline `Brain` is already held to.

### 8.3 `ServerScriptService.Boar` — the owner

```luau
Runtime:takeHit(part: BasePart, hit: Hit): boolean
    -- true  = one of MY live boars and the hit was recorded
    -- false = not mine, already despawned, or already DOWN
Runtime:woundOf(id: string): WoundState?          -- a copy; there is no setter
Runtime.Hit: RBXScriptSignal        -- (record) EXTENDED: id, zone, zones, ammo, pellets, damage,
                                    --   severity, distance, shooterUserId, at
Runtime.Downed: RBXScriptSignal     -- NEW: (record: KillRecord), exactly once per boar
Runtime.Despawned: RBXScriptSignal  -- EXTENDED DespawnRecord: the existing id/reason/position/aliveFor
                                    --   plus wounded: boolean, mortallyWounded: boolean,
                                    --   damage: number, wounds, contributors
Runtime:stats()                     -- EXTENDED: hits, pelletsTaken, damageTaken, downed, killed,
                                    --   escapedWounded, zoneHits (per zone), unknownZoneHits,
                                    --   tallylessHits, plus the existing path/spawn counters
Boar.Wound                          -- the pure module, exported for specs
Boar.CONFIG.ZONES, Boar.CONFIG.WOUND
```

`Downed` and `Despawned` are two events on purpose. The score (1.7) must be able to award a kill at
the moment the boar dies, not `CARCASS_SECONDS` later; and the body leaving the world is a different
fact from the animal dying. A killed boar therefore fires `Downed` at *t* and `Despawned(reason =
"killed")` at *t* + `CARCASS_SECONDS`.

Signals stay `BindableEvent.Event`, as `Despawned` already is, with the two consequences
`docs/design/boar-ai.md` §4 records: payload tables are copied, so no metatables and no mixed-key
tables (`wounds` is an array, `contributors` a number-keyed map, and they are separate fields for
exactly that reason); and under `SignalBehavior = Deferred` a listener does not run inside `Fire`, so
live specs poll.

### 8.4 `Player` is not stored, and that is deliberate

The wound record keeps `shooterUserId` and `shooterName`, never the `Player` instance. A boar that is
wounded and runs for 16 s outlives plenty of disconnects, and holding a `Player` reference pins the
instance — the leak `reviews/task-23/RESULT.md` note (c) raised against the weapon's per-player state
(`TASKS.md` row 23a). `Runtime.Hit` may carry the live `Player` as an extra field for a listener that
wants it *now*; nothing stored keeps it.

### 8.5 `Boar.Brain` — the additions

```luau
export type HitEvent = { severity: Severity, zone: HitZone, from: Vector3? }

-- Observation gains:
    hitEvents: { HitEvent }?,       -- hits since the last step; usually empty
    wound: { severity: Severity, speedScale: number, collapse: boolean }?,

-- Intent gains:
    downed: boolean,                -- true exactly once, the tick the boar collapses
```

The Brain is told a **severity and a direction**, never a damage number and never a table lookup. It
cannot be made to disagree with the wound model because it does not hold a copy of it. `collapse`
comes from `Wound.advance`, so the "has it run far enough" arithmetic lives in the pure wound module
and the Brain only reacts to a boolean.

---

## 9. What it reads, what it writes, and who owns the other end

### 9.1 The table

| Direction | What | Owner of the other end | Status |
|---|---|---|---|
| reads | `hit` payloads through `Runtime:takeHit` | `ServerScriptService.Weapon` (`docs/design/shotgun.md` §3.1), via `BoarBoot` | Task 24 |
| reads | `shooter.Character.PrimaryPart.Position`, **in `BoarBoot` only**, best effort | Roblox character replication | engine |
| reads | `Players:GetPlayers()` for threats, `PathfindingService`, `Workspace:Raycast` for the probe | engine | unchanged |
| writes | `Workspace.Boars` and its descendants, including the new zone parts, the flash colour, the collapse and the `Carcass` attribute | **this system** (`Boar.Body`) | — |
| writes | attributes `Damageable` (true at spawn, false on collapse) and `HitZone` (per part) | **this system**; the weapon only ever reads them | — |
| writes | `Hit`, `Downed`, `Despawned` | **this system**. Future listener: the score (1.7), which reads and never writes back | — |
| writes | nothing else, anywhere. No client, no remote, no UI, no camera, no character | — | — |

`Boar` never requires `Weapon`, and `Weapon` never requires `Boar`. The composition root knows both;
neither owner knows the other (`docs/design/shotgun.md` §6.3).

### 9.2 The wiring, in `BoarBoot.server.luau`, which owns nothing

The existing connection widens. Every field it adds already exists on the `HitReport` it is handed:

```luau
Weapon.HitReported:Connect(function(report)
    if not report.target:IsA("BasePart") then
        return
    end
    local shooter = report.shooter
    local character = shooter and shooter.Character
    local root = character and character.PrimaryPart
    runtime:takeHit(report.target, {
        zone = report.zone,
        zones = report.zones,
        ammo = report.ammo,
        pellets = report.pellets,
        at = report.at,
        distance = report.nearest,
        shooterUserId = shooter and shooter.UserId,
        shooterName = shooter and shooter.Name,
        shooterPosition = root and root.Position,
        normal = report.normal,
    })
end)
```

That is the whole cross-system change. `takeHit` still returns `false` for a part that is not one of
its boars, so `BoarBoot` needs no filtering and a shot into a wall still costs one table lookup.

---

## 10. External sources

Rule 1 and rule 2 — this is where the design borrows, and where it says so. Sources A, B and G carry
the structure; C and D carry the numbers and the behaviour; E and F are named and deliberately not
adopted. §15 records that I could not fetch any of them this session; the Builder confirms each URL,
licence and maintenance status in the research note before relying on it.

### A. Roblox `WeldConstraint`, assemblies and `Massless`
<https://create.roblox.com/docs/reference/engine/classes/WeldConstraint> ·
<https://create.roblox.com/docs/physics/assemblies> · first-party creator docs (creator-docs is
CC BY 4.0); the API ships with the engine · actively maintained.
**Good:** rigidly attaches a part to another with no offset maths and no legacy `Weld`; the welded
parts become one assembly, so `SetNetworkOwner`, `AssemblyLinearVelocity` and the existing
`LinearVelocity`/`AlignOrientation` drive keep working untouched; `Massless` excludes a welded part
from the assembly's mass and inertia, which is exactly what keeps `MAX_FORCE`/`MAX_TORQUE`/`ACCEL`
valid after three parts are added.
**Bad:** an anchored part welded into an assembly anchors the whole thing — a real way to freeze the
boar by accident; `WeldConstraint` needs both parts in the DataModel, so creation order matters
(§4.3); and the assembly root is chosen by the engine, so nothing in the code may assume the trunk is
the root without checking.
**Adopted:** three massless, non-colliding, welded zone parts on the existing trunk, created after the
trunk is parented.

### B. Roblox raycasting, `CanQuery` and `CanCollide`
<https://create.roblox.com/docs/workspace/raycasting> ·
<https://create.roblox.com/docs/reference/engine/classes/BasePart> · first-party (CC BY 4.0) ·
actively maintained.
**Good:** gives the split this design needs — the **collision** body and the **queryable** body are
different properties of different parts, so a hit box can protrude where a collision box must not;
`RaycastResult.Instance` is exactly the handle the weapon's `targetOf` walks from.
**Bad:** a ray returns the **first** surface only, which is the whole reason zone parts must protrude
rather than nest (§4.1) — the single most likely way to build this wrong; `CanQuery = false` hides a
part from *every* consumer, including the camera's occlusion cast, so it is not a per-system filter;
and coplanar faces make the winner arbitrary, which is why `ZoneLegs` is offset rather than flush at
both ends.
**Adopted:** protruding, queryable, non-colliding zone parts; the trunk stays both collidable and
queryable and is the default `body` zone.

### C. Stokke, Arnemo, Brainerd et al., on incapacitation time and flight distance in hunted ungulates
*Scientific Reports* (Nature), 2018 — "Defining animal welfare standards in hunting: body mass
determines thresholds for incapacitation time and flight distance"; open access, CC BY 4.0 ·
published, not maintained (a paper).
**Good:** it is the only source in this set that measures the quantity this design is inventing
numbers for — how far a wounded animal travels before it goes down, as a function of body mass and
shot placement — and it supports the model's core split: placement, not only energy, decides flight
distance, and thoracic hits incapacitate on the spot far more often than abdominal or limb hits.
**Bad:** it is about rifle hunting of moose, red deer and reindeer, not shotgun slugs at boar
distances; its distances are metres of real animals, not studs of a 10-minute arcade drive; and a
straight transcription would give tracking distances far beyond a 400-stud arena.
**Adopted:** the *shape* of the model — vital → immediate, body → short, limb → long — and the
ordering of magnitudes. The actual studs are compressed to the arena and are Karen's feel values (§11).

### D. Hit-sign ("Schusszeichen") guidance from hunting associations, e.g. Deutscher Jagdverband
<https://www.jagdverband.de/> (their "Schusszeichen" material) · copyrighted web content; **facts and
technique taken, no text and no code** · maintained as public guidance.
**Good:** describes exactly the observable reaction this design has to reproduce, and it is the sort
of thing Karen (whose game this is) will recognise or reject immediately: a chest-hit boar typically
bolts hard and collapses within a short distance; a gut-shot animal humps up and moves off slowly; a
leg-hit animal breaks away fast and may travel a very long way.
**Bad:** qualitative, regionally variable, and written for tracking with a dog — which v1 explicitly
cuts (`ROADMAP.md` scope table). It gives no numbers a config can hold.
**Adopted:** the reaction vocabulary — **bolt on any hit**, slow while bleeding out, limp when the
legs are hit — which is §5.5 and §6.2. Nothing else.

### E. `RaycastHitbox` (Swordphin123) — named, deliberately not adopted
<https://github.com/Swordphin123/raycast-hitbox> · MIT · community module, widely used, on Wally.
**Good:** the standard Roblox answer to "attach hit detection to a moving object" — attachment-driven
raycasts, per-part tagging, debug visualisation.
**Bad:** it solves the *melee/fast-projectile* problem (sweeping a weapon's own rays between frames),
not this one. Here the weapon already casts (`docs/design/shotgun.md` §5.4) and the boar only needs to
*be* hittable. Adopting it would add a Wally dependency, a `default.project.json` mapping and a Connect
click (`CLAUDE.md`, Toolchain) to replace three `Instance.new` calls, and it would put a second system
in the hit path.
**Decision:** not adopted, reason recorded here so it is not re-researched. Revisit if a future weapon
needs swept hit detection.

### F. *theHunter: Call of the Wild* (Expansive Worlds/Avalanche) — behaviour precedent, not code
<https://www.thehunter.com/> · proprietary, all rights reserved; **nothing is copied** · actively
maintained commercial game.
**Good:** the best-known player-facing contract for exactly this mechanic — vital hits drop the animal
quickly, non-vital hits produce a long track, and the game tells the player which happened. It is
worth naming because it sets the expectation Karen's players will arrive with.
**Bad:** its whole loop is *tracking* — blood trails, scent, a dog — which v1 cuts to v1.1 (brief). Its
distances assume a several-square-kilometre map; ours is 400 × 400 studs. Proprietary, so nothing may
be taken but the observation.
**Decision:** informs §14's open decision about whether an escaped wounded boar should leave anything
findable; nothing adopted now.

### G. Borrowed from inside this repo (rule 2 applies to internal patterns too)
`src/server/Boar/init.luau`, `Brain.luau`, `Body.luau` and `docs/design/boar-ai.md`: the owner module
that does nothing on `require`, a pure decision module driven by an injected world, one module that is
the only writer of Instances, every number in one `CONFIG`, one named function for a policy a later
milestone replaces (`CONFIG.isThreat`). `docs/design/shotgun.md` §6.4: attributes as the cross-system
data contract, because the harness compares them and does not compare tags. `docs/design/camera.md`
§10.1: a counter for the failure case (`unknownZoneHits`, `tallylessHits`) so a silent degradation
becomes a number in the harness report.
**Adopted whole.** The third system in a repo either keeps the conventions or starts eroding them.

**Pattern adopted overall:** protruding, massless, welded, queryable zone parts on the existing physics
trunk (A, B); a two-quantity wound model — damage decides *whether*, flight decides *how far* — with
the shape taken from the wounding literature (C) and the reactions from hunting practice (D), all of
it in one pure module inside the boar's existing owner (G). Nothing is invented except the flight
formula in §5.3, which exists because no source gives studs for a 400-stud arena, and whose entire
content is a clamp and a linear interpolation — one spec assertion.

---

## 11. Numeric targets — the one config table

Everything lives in `Boar.CONFIG`, which is already "every number the system has"
(`src/server/Boar/init.luau`). Two new sub-tables, `ZONES` and `WOUND`. **No magic number anywhere
else.** **K** marks Karen's feel values (brief: "mark which are Karen's feel values").

**Note for the Builder:** `Boar.newRuntime` does `table.clone(Boar.CONFIG)` and then a shallow merge of
`world.config`. `table.clone` is shallow, so a spec that overrides `WOUND` replaces the **whole**
sub-table, and a spec that mutates `config.WOUND.DAMAGE` mutates production's table. Specs must pass a
complete replacement sub-table, and `Wound` must never write into the config it is handed.

### 11.1 `CONFIG.ZONES` — geometry (§4.2)

| Field | Value | K? | Basis |
|---|---|---|---|
| `head.size` / `head.offset` | `(1.2, 1.2, 1.4)` / `(0, 0.5, -3.2)` | K (look) | 1.15 studs proud of the front face; ≈34 cm at 1 stud = 0.28 m, a boar's head |
| `chest.size` / `chest.offset` | `(2.12, 2.01, 1.7)` / `(0, 0.555, -1.6)` | K | heart/lungs behind the shoulder; proud 0.06 on both flanks and the top |
| `legs.size` / `legs.offset` | `(2.12, 1.0, 5.4)` / `(0, -1.0, 0.15)` | K | bottom third over the whole length; proud 0.06 on the flanks and 0.1 past the rear |
| `PROTRUSION` | 0.06 studs | | the margin every zone part stands proud by, so the ray meets it first; one named number rather than six hand-tuned sizes |
| `head.tint` / `chest.tint` / `legs.tint` | `RGB(206, 120, 120)` / `RGB(198, 150, 150)` / `RGB(150, 128, 104)` | K | grey-box teaching aid, readable against `BODY_COLOR = RGB(198, 158, 110)` and the grey plate. **Check on screen** — `BODY_COLOR` itself had to be measured on screen once already (`TASKS.md` row 22) |
| `ZONE_TINT` | `true` | K | one boolean; `false` gives a uniform boar. Default on because Karen's open question is "can I hit anything", and a visible head answers half of it before she fires |

### 11.2 `CONFIG.WOUND` — the model (§5)

| Field | Value | K? | Basis |
|---|---|---|---|
| `LETHAL` | 100 | K | the scale everything else is expressed in |
| `MORTAL` | 50 | K | at or above, the boar will die |
| `DAMAGE.head` | `{ Slug = 100, Pellet = 34 }` | K | slug kills; 3 pellets kill |
| `DAMAGE.chest` | `{ Slug = 100, Pellet = 25 }` | K | slug kills; 4 pellets kill; 2 pellets are already mortal with flight 0 |
| `DAMAGE.body` | `{ Slug = 55, Pellet = 11 }` | K | one slug is mortal; 5 pellets are mortal |
| `DAMAGE.legs` | `{ Slug = 30, Pellet = 6 }` | K | one slug is **not** enough — the brief's "several hits needed" |
| `DAMAGE.unknown` | the `body` row | | never free, never a crash (§5.2) |
| `FLIGHT.head` / `FLIGHT.chest` | 0 / 0 | K | drops on the spot |
| `FLIGHT.body` | 120 studs | K | ≈34 m; ~4 s at sprint. "A short way" |
| `FLIGHT.legs` | 420 studs | K | > the 400-stud arena span, so a leg-shot boar usually reaches the exit line first: "runs far — or escapes" |
| `BLEED_OUT_MAX_SECONDS` | 25 | K | ceiling; covers 420 studs at the wounded speed with margin. A stuck wounded boar still dies |
| `WOUND_SPEED_START` / `WOUND_SPEED_END` | 1.0 / 0.45 | K | 38 → 17 studs/s over the flight |
| `LIMP_SCALE` | 0.75 | K | 28.5 studs/s: still faster than a player's 16, so a limping boar is catchable, not caught |
| `BOLT_SECONDS` | 3.0 | K | sprint away from the shot point regardless of threats |
| `BOLT_KICK` | 0.8 | K | the speed setpoint jumps to 0.8 × sprint on the hit tick — the one documented bypass of `ACCEL` (§6.2) |
| `FLASH_COLOR` | `RGB(190, 40, 40)` | K | **check on screen** against `BODY_COLOR` and the tints |
| `FLASH_SECONDS` | 0.25 | K | long enough to read at 60 fps (15 frames); short enough not to look like a state |
| `CARCASS_SECONDS` | 120 | K | a carcass outlives a drive's local action but not the 10-minute drive. 1.7 may want it to last the whole drive (§14, Director item B) |
| `COLLAPSE_ANGULAR_IMPULSE` | 1200 | | one nudge so it falls on a side. A physics number: unverified (§15), checked in a screenshot |

### 11.3 Performance and correctness targets, each one an assertion

| Target | How it is checked |
|---|---|
| `Wound.apply` ≤ 10 µs | `boar_wound.spec`: 10 000 applies under 100 ms (the method `boar_brain.spec` already uses) |
| `Brain:step` still ≤ 10 µs with wounds | `boar_brain.spec`: the existing 10 000-step assertion, unchanged and still passing |
| Parts per boar == 4, `BasePart` children of the folder == 1 | `boar_zones.spec` |
| Every zone is reachable by a real ray from outside | `boar_zones.spec` (§12.3) — the assertion that makes §4.1's trap impossible |
| Reaction: the state changes within **one tick (≤ 17 ms)** of `takeHit`, not one `SENSE_INTERVAL` | pure spec, exact; live spec, measured |
| A head or chest slug kills; a single leg slug does not | pure and live spec (brief: "a spec that a head hit kills and a leg hit does not") |
| Body-slug flight is 108 ± 5 studs; two leg slugs give 336 ± 5 | pure spec, exact arithmetic |
| `Downed` fires **exactly once** per boar; `stats().downed == stats().killed` | live spec, polled |
| A downed boar accepts no further hits and reports `Damageable == false` | live spec |
| The carcass exists for `CARCASS_SECONDS` ± 1 s, then is gone | pure spec in simulated time; live spec with a shortened config |
| Property writes per hit for the flash ≤ 2 per part | read the code; `stepFlash` writes only on a transition |
| Zero extra raycasts per tick | the Runtime adds none; `probe` is unchanged |
| `unknownZoneHits == 0` and `tallylessHits == 0` in a live buckshot run | live spec / the Builder's report — a silent degradation becomes a number |
| Zero errors, zero skipped tests | `tests/TestKit.luau` fails the run otherwise |

---

## 12. How it is tested

`tests/server/` → `ServerStorage.Tests` (`CLAUDE.md`, Layout). Specs write their own numbers rather
than importing `CONFIG` for the assertion, following `tests/server/test_arena.spec.luau`, so a spec
disagreeing with the config is a finding and not a tautology. Rule 6: these test the boar's path, not
the harness.

### 12.1 `tests/server/boar_wound.spec.luau` — NEW, pure, no Instances, no physics, no waiting

Requires `ServerScriptService.Boar` (side-effect-free on require) and drives `Boar.Wound` with a
hand-written config:

1. `Wound.new()` is frozen, `damage == 0`, `severity == "healthy"`, `flightStuds == 0`;
2. the damage table: a slug in each of the four zones gives exactly the §11.2 values; a pellet gives
   the pellet value; `zone = "unknown"` is charged at the `body` row;
3. thresholds: head slug → `"lethal"`; body slug → `"mortal"`; legs slug → `"grazed"`; two legs slugs
   → `"mortal"`;
4. flight: body slug → 108; two leg slugs → 336; body+legs → 126; any lethal → 0; chest, two pellets
   → mortal with flight 0;
5. **buckshot tallies:** `zones = { chest = 4, body = 3, legs = 2 }` with `pellets = 9` charges
   4 × 25 + 3 × 11 + 2 × 6 = 145 → lethal; the same hit with `zones = nil` charges 9 × the dominant
   zone's pellet value, and the `tallyless` flag is set;
6. `apply` never mutates its input: the input table is unchanged afterwards and the result is a
   different, frozen table (a write to it errors);
7. `contributors` accumulates per `shooterUserId` across hits from two shooters, and `wounds` is an
   array in order;
8. `speedScale`: 1.0 healthy; `LIMP_SCALE` after any leg damage; ramps 1.0 → 0.45 × limp across
   `flightRun` 0 → `flightStuds`; never 0 and never negative;
9. **a later hit never lengthens the run:** mortal from a leg hit (flight 336), run 100 studs, then a
   body hit → `flightStuds` drops and `flightRun` is not reset, so the remaining distance is strictly
   smaller;
10. `advance` returns `collapse == true` exactly when `flightRun ≥ flightStuds` or
    `flightSeconds ≥ BLEED_OUT_MAX_SECONDS`, and never for a `grazed` or `healthy` boar;
11. `killRecord` carries the killing shot's zone, ammo, distance and shooter, `instant == true` only
    for a lethal hit, and `shots == #wounds`;
12. 10 000 `apply` calls under 100 ms.

### 12.2 `tests/server/boar_brain.spec.luau` — CHANGED, pure, the states and the reaction

Added to the existing file, which already drives `Brain:step(1/60, obs)` with `Random.new(1)`:

1. **a head hit kills and a leg hit does not** (the brief's named assertion, at the Brain level): a
   `lethal` hit event → `state == "DOWN"` and `intent.downed == true` **on the same tick**; a `grazed`
   hit event → `state == "FLEE"`, `downed == false`, and the boar is still moving 5 s later;
2. **reaction within one tick:** from `IDLE` with no threat anywhere, one hit event → the very next
   returned `intent.state` is not `IDLE` and `|targetVelocity|` is ≥ `SPRINT_SPEED * BOLT_KICK * 0.9`
   — i.e. it did **not** wait for the sense tick and did **not** ramp through `ACCEL`;
3. the bolt runs **away from the shot point**: with `from` behind the boar and no threats at all, the
   flat distance to `from` grows over 30 steps;
4. `WOUNDED` never returns to `IDLE`: 30 s of simulated steps with no threat inside `CALM_RADIUS`
   leaves it `WOUNDED` (a `FLEE` boar in the same conditions calms, which the existing test already
   asserts — so the two together prove the difference is the wound, not the timer);
5. `WOUNDED` still routes: `pathRequest` is on the exit line and inside the bounds minus
   `EDGE_MARGIN`, exactly as the existing `FLEE` assertion requires — the proof it reuses the route
   rather than re-implementing it;
6. `speedScale` is applied to the setpoint: with `wound.speedScale = 0.5`, the steady-state
   `|targetVelocity|` is half the unwounded value, and the per-step change still never exceeds
   `ACCEL * dt` (the ramp is not bypassed except on the hit tick);
7. `collapse == true` in the observation → `DOWN` with `downed == true` once, then `downed == false`
   forever after and `targetVelocity == Vector3.zero` every subsequent tick;
8. `DOWN` → after `CARCASS_SECONDS` of simulated dt, exactly one `despawn = true, reason = "killed"`,
   then `GONE` forever;
9. a `WOUNDED` boar crossing `exitZ` gives `despawn = true, reason = "escaped"` once (not `killed`);
10. a hit arriving while `GONE` or `DOWN` changes nothing and never re-animates the boar;
11. two hit events in one observation are both consumed, and the most severe wins;
12. determinism: two brains with the same seed and the same hit sequence produce identical intent
    sequences;
13. `dt = 5` is still clamped in `WOUNDED` and `DOWN` — a hitch cannot skip the whole flight or the
    whole carcass time in one step;
14. the existing 10 000-step performance assertion still passes.

### 12.3 `tests/server/boar_zones.spec.luau` — NEW, live, and the most valuable spec here

One real boar in the spec's own folder (the pattern `tests/server/boar_body.spec.luau` already uses:
its own plate at y = 500, its own field, teardown in `afterAll`). It proves the geometry **with real
rays**, which is the only way to catch §4.1:

1. the boar has exactly 4 `BasePart`s: the trunk plus `ZoneHead`, `ZoneChest`, `ZoneLegs`; the
   runtime's folder still has exactly **one** `BasePart` child;
2. the trunk carries `Damageable == true` and `HitZone == "body"`; each zone part carries its own
   `HitZone` and **no** `Damageable`; each is `Massless`, `CanCollide == false`, `CanQuery == true`,
   `Anchored == false`, and is joined by a `WeldConstraint` to the trunk;
3. **the ancestor walk works:** for each zone part, walking `Parent` upward reaches an instance with
   `Damageable == true`, and that instance is the trunk — i.e. the weapon's `targetOf` will return the
   part `takeHit` expects, with the child's zone;
4. **rays, from outside, in the boar's own local frame** (computed from `part.CFrame` so the test does
   not depend on which way the boar happens to be facing): a ray at the head from the front, from
   above and from each side hits an instance whose `HitZone` is `head`; at the chest from both flanks
   and from above → `chest`; low on both flanks and at the rear-low → `legs`; mid-flank behind the
   chest, the belly from below behind the legs band, and the rear above the hams → `body`. **Nine
   directions minimum.** This is the assertion that fails loudly if a future change nests a zone part
   inside the trunk or shrinks the protrusion;
5. the boar still drives: after 1 s the assembly is moving and `CFrame.UpVector.Y > 0.9` — the zone
   parts did not tip it, anchor it or slow it;
6. `part:GetNetworkOwner() == nil` still holds with the welded children (assembly ownership).

### 12.4 `tests/server/boar_hit.spec.luau` — CHANGED, live, the seam and the kill

Task 24's six assertions stay and must still pass unchanged (that is the `Hit` back-compatibility
claim in §2.2). Added, with a spec-owned config whose `CARCASS_SECONDS` is 2 so the test takes seconds:

1. `takeHit(trunk, { zone = "head", ammo = "Slug", pellets = 1, at = os.clock() })` → `true`; within
   0.2 s the boar's state is `DOWN`; `stats().downed == 1`;
2. `Downed` fires **exactly once** (polled, deferred signals) with `killingZone == "head"`,
   `instant == true`, `flightStuds == 0`, `killedByUserId` as supplied, `#wounds == 1`;
3. the body **collapsed**: the `AlignOrientation` is disabled, the mover is disabled,
   `GetAttribute("Damageable") == false`, `GetAttribute("Carcass") == true`, and the part is still in
   the folder;
4. a further `takeHit` on the carcass → `false`, no counter moves, no second `Downed`;
5. after `CARCASS_SECONDS`, `Despawned` fires once with `reason == "killed"` and the part is gone;
6. a **second boar**, one `legs` slug: it is **not** down after 3 s, its state is `FLEE`, and
   `woundOf(id).severity == "grazed"` — the brief's "a leg hit does not kill", at the live seam;
7. that boar, hit again in the legs, becomes `WOUNDED`, and its flat speed over the next second is
   measurably below an unwounded boar's sprint (the limp and the bleed ramp, at the physics level);
8. a mortally wounded boar driven over the exit line fires `Despawned` with `reason == "escaped"`,
   `mortallyWounded == true` and the wound payload attached — the brief's "an escaped wounded boar is
   also an event";
9. `stats()` reports `zoneHits` per zone, `unknownZoneHits == 0` and `tallylessHits` matching the
   number of tally-free calls the spec made.

### 12.5 Client spec: none, and harness-driven input: what it can and cannot prove

**No client spec.** This system has no client code (§1.2), so `tests/client/` is unchanged. Adding one
would test the weapon, which Task 24 already tests.

**What harness-driven input can do today** (Task 6 landed; `TASKS.md` rows 6 and 6a;
`tools/studio_mcp.py` docstring): replay keyboard and mouse steps with gaps into the Play client, and
assert in a client spec on what `ContextActionService` and `UserInputService` delivered.

**What it cannot do, and this system needs** — say it plainly rather than build a test that looks like
proof (rule 6):

- it **cannot place the player's character**, so it cannot guarantee a boar is in front of the muzzle;
- it **cannot aim**: `moveTo` is absolute, and under the camera's `MouseBehavior = LockCenter` it may
  deliver no usable `InputObject.Delta` at all (`docs/design/camera.md` §9.3);
- it cannot order a client scenario against a **server** spec's actions: the two reports are
  independent;
- the boar moves, so even a lucky alignment is not repeatable.

So there is **no honest end-to-end "shoot the boar in the head from the client" test today**, and this
design does not pretend otherwise. What is added instead:

**One scenario, for the part that is real** — that firing from the real input path reaches the server
and produces a hit *when it hits*, appended to `tests/client/input_scenarios.txt`:

```json
{ "name": "fire-at-boar", "spec": "ClientTests.weapon_client.spec", "steps": [
  { "device": "keyboard", "action": "keyPress", "key": "One" },
  { "device": "wait", "ms": 400 },
  { "device": "mouse", "action": "moveTo", "x": 400, "y": 300 },
  { "device": "wait", "ms": 200 },
  { "device": "mouse", "action": "mouseButtonDown", "button": "left" },
  { "device": "mouse", "action": "mouseButtonUp", "button": "left" },
  { "device": "wait", "ms": 800 } ] }
```

It asserts the weapon's own state changed (Task 24's assertions), **not** that a boar was hit. Whether
the boar was hit is `Runtime:stats().hits` in the server report, which the Builder reports as an
observation, never as a passing assertion. If the `One` keypress does not reach the CoreGui backpack,
that is a harness fault and gets reported (`docs/design/camera.md` §9.3 flags the same unknown).

**Queued, not built here** (§14, Director item D): the smallest harness step that *would* make this
testable end to end is "place the local character at a given CFrame and point the camera at a given
point, during Play". That is one StudioMCP call and one gate, it is the blocker for every future
"shoot X" test, and it belongs to a harness task, not to this one.

### 12.6 Screenshots (rule 5) — four, inspected by the Builder

`python tools/studio_mcp.py capture <name> [camera x,y,z] [look-at x,y,z]` works during Play
(`TASKS.md` row 7, closed; used in Tasks 17, 18, 22). This task changes how the boar **looks** (a head,
tinted zones) and how it **behaves when shot**, so:

1. **The boar from the side and from the front**, idling: it has a head that protrudes, the chest and
   leg bands are distinguishable from the trunk, and the whole thing still reads as one animal rather
   than four boxes. This is the `ZONE_TINT` decision on screen.
2. **A carcass**: after a chest hit, the boar lying on its side on the ground, not standing, not
   sunk into the plate, not floating. The `COLLAPSE_ANGULAR_IMPULSE` check.
3. **Before / after a shot**, the same camera, ~1 s apart: the boar grazing, then sprinting away. This
   is the "can I tell I hit it" evidence that Karen's playtest asked for.
4. **The flash**, best effort: a capture timed inside `FLASH_SECONDS`. **Say plainly if it could not be
   caught** — 0.25 s against a manual capture is a lottery, the spec covers the property change, and a
   missed capture is reported, never implied.

Describe what is actually on screen, not what should be. A number is not a verification
(`docs/PROJECT_CONTEXT.md`).

### 12.7 Process hazards, named so the task does not stall on them

- **Rojo.** This task adds `Wound.luau` to a watched folder and needs a branch switch to get it.
  `rojo serve` 7.7.0 panics when watched files vanish and a large branch switch alone crashed it once
  (`CLAUDE.md`, "Known Rojo 7.7.0 crash"). Stop `rojo serve` before switching; expect a
  **NEEDS KAREN** Connect click.
- **Stacked branch.** §0: branch from `task-24-shotgun` while it is unmerged, and say so in the review
  request's `Base:`.

---

## 13. Rows for `GAME_DESIGN.md` — ready to paste

Rule 3 requires the owners table to mirror this file. **No new row**: this system is the boar's. Amend
the existing **Boar AI** row's owner cell by appending (it will already carry Task 24's `takeHit`
sentence; this follows it):

> … Since Milestone 1.5 it also owns **hit zones and wound state**: `Boar.Body` builds the three welded,
> massless, non-colliding zone parts (`ZoneHead`, `ZoneChest`, `ZoneLegs`) that carry the `HitZone`
> attribute the weapon reads, and is the only writer of the hit flash, the collapse and the `Carcass`
> attribute; `Boar.Wound` is the pure damage model and holds no state; the Runtime is the only holder
> of a boar's `WoundState` and the only firer of `Runtime.Downed` (the kill event for Milestone 1.7)
> and of the extended `Runtime.Despawned` (which reports an escaped wounded boar). No damage number,
> health value or zone→reaction rule exists anywhere else in the repo
> ([hit-zones design](docs/design/hit-zones.md)).

Nothing else in that table changes. In particular **`Game state` stays `_unassigned_`**: the score
system that will consume `Downed` is Milestone 1.7 and gets its own design and its own owner. This
task must not claim that slot by putting a points number anywhere.

---

## 14. Open decisions — none of them blocks building

Every one has a default written into `CONFIG` or into this document, so the Builder can build, test and
report without an answer. They are the things to overrule on purpose rather than by accident.

### Karen (feel) — the "check this" list for the first shooting playtest (`ROADMAP.md` speed rule 8)

1. **Does a hit read as a hit?** The flash (0.25 s, red) plus the bolt (sprint for 3 s away from you).
   If not, the dials are `FLASH_SECONDS`, `FLASH_COLOR` and `BOLT_SECONDS` — and if it still does not,
   the answer is sound or a hit marker, which is §14 Director item C, not more red.
2. **Are the zones the right size?** Especially: is the head hittable at 60–80 studs with a slug, and
   is it *too* hittable with buckshot? `CONFIG.ZONES` sizes; `DAMAGE.head.Pellet` is the other dial.
3. **Is the hindquarters split right?** This design puts the rear *above* the legs band in `body` and
   the hams in `legs` (§4.2). One number (`legs.size.Y`) moves the line.
4. **Are the distances right?** Body ≈ 108 studs (~4 s), two leg hits ≈ 336 studs (usually an escape).
   Too short and every hit is a kill; too long and the drive never ends.
5. **Should a wounded boar be able to escape at all in v1?** Default **yes** (it is in the brief, and
   it is what makes the drive a drive). `FLIGHT.legs` is the dial if it happens too often.
6. **Is the zone tint on or off?** Default **on** for the grey box (`ZONE_TINT = true`). It is a
   teaching aid, not art, and it goes when the model arrives.
7. **Does a carcass in the way annoy you?** It is solid (`CanCollide = true`) and stays 120 s.

### Director (scope)

A. **A damage router / a health system of its own.** Default: **not now** (§3.1), same answer
   `docs/design/shotgun.md` §15 item B gave. Revisit when roe deer, fox and rabbit arrive (v1.1) — the
   expectation is that they reuse `Wound` with a different `DAMAGE` table, not a second model.
B. **How long a carcass lives, and who removes it.** Default: 120 s, removed by the boar runtime.
   1.7 may want carcasses to last the whole drive and be removed at the score screen; that is a config
   number plus one call, and it is 1.7's call, not this task's.
C. **A hit marker or a hit sound.** Default: **neither**, because both need an owner this task must not
   invent — anything drawn is `PlayerScripts.Hud` (`docs/design/shotgun.md` §3.4) and would need the
   server's `HitReported` replicated to the shooter, which is a weapon change. If Karen's answer to
   item 1 is "still not obvious", this is the next task, with the Hud as the owner and the weapon
   publishing a one-way remote.
D. **The harness cannot place a character or aim a camera** (§12.5). That blocks every end-to-end
   "shoot X" assertion, not only this one. Default: not built here (tooling freeze,
   `ROADMAP.md` speed rule 1); queued as the smallest useful harness step.
E. **Blood trail and tracking.** Out of v1 by the brief and `ROADMAP.md`. Named here only because the
   escaped-wounded event (§6.3) is the hook it will attach to, and nothing about it needs to change
   when that lands.
F. **Players are not damageable**, unchanged from `docs/design/shotgun.md` §15 item C. A pellet that
   hits a player is a miss; the drive-line rule, not damage, is the answer to shooting at people.
G. **Several boars at once.** Unchanged: the interface is plural, `maxBoars = 4`, production spawns
   one. Carcasses count against nothing yet.

---

## 15. What I could not verify (rule 8)

- **The Task 24 branch.** I could not read `task-24-shotgun`. Everything in §2.1 — the field names on
  `Hit` and on `HitReport`, that `Hits.targetOf` reads the **hit instance's** `HitZone` before the
  root's, that `report.zones` carries the per-pellet tally, and the shape of the `BoarBoot` wiring — is
  read from `docs/design/shotgun.md` and `reviews/task-27/BRIEF.md`, not from code. §2.3 makes
  checking it the Builder's first act; §8.1 makes every new field optional so a mismatch is a small
  adaptation rather than a redesign.
- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`). Every
  claim about how `WeldConstraint`, `Massless`, `CanQuery`, `ApplyAngularImpulse`, disabling an
  `AlignOrientation` or raycast ordering behave here is from documentation and from the code already in
  this repo, not observed. Specifically unverified: that a massless welded child leaves the assembly's
  mass and therefore `MAX_FORCE`/`ACCEL` untouched; that disabling `upright` plus
  `COLLAPSE_ANGULAR_IMPULSE = 1200` reliably topples a ~23-mass body rather than spinning it; and that
  a 0.06-stud protrusion is enough for the engine to prefer the zone part at a grazing angle.
  §12.3 item 4 and §12.6 shot 2 are the checks.
- **The external sources' URLs, licences and maintenance status.** No network. A, B (Roblox creator
  docs, CC BY 4.0, APIs ship with the engine) are near-certain; **C is cited from memory** — the paper
  exists in *Scientific Reports* 2018 on incapacitation time and flight distance, and I am confident of
  the finding but not of the exact title, author list or DOI; D is a category of source (hunting-
  association hit-sign guidance) rather than one fixed page; E's repository name and F are from my own
  knowledge. **The Builder confirms all of them in the research note before relying on any**, and if C
  cannot be confirmed, the model does not change — §5's numbers are Karen's feel values compressed to a
  400-stud arena, and C is cited for the *shape*, which D independently supports.
- **Every number in §11.2 is a first guess.** None has been played. They are arithmetic against
  `Boar.CONFIG.SPRINT_SPEED` and the arena span, not measurement, and §14's Karen list is where they
  get their real values.
- **The DEV place's `SignalBehavior`.** Not a repo file. The live specs poll, which is correct under
  both `Immediate` and `Deferred` — the same conclusion `docs/design/boar-ai.md` and
  `docs/design/shotgun.md` reached.
- **Whether `tests/client/input_scenarios.txt`'s `keyPress "One"` reaches the CoreGui backpack** to
  equip the Tool. `docs/design/camera.md` §9.3 flags the same unknown; §12.5 says what to report if it
  does not.
- **CI and harness status at this commit.** Lint and build are clean in the evidence
  (`.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`). No harness or CI output is
  in `.agent-evidence/`.

# Design: hit-zones — vital organs as volumes, and the path that crosses them

**v2, Task 277 (2026-10-26).** Written to `reviews/task-277/BRIEF.md`, which **overrides** anything
older in `docs/`, `TASKS.md` and v1 of this file. Direction **B** (real vital organs, hittable from
any angle) and the half of direction **C** this document is accountable for. Direction **A** is
`docs/design/ballistics.md` **v5**, written by run 1 of this same task; this document is run 2 and
does not re-open it.

**RULE 7. v1 of this file is not deleted — the Architect script replaces it in place.** The Builder
must recover it into `backups/design-hit-zones-v1.md` with a one-line note
(`git show 2ee60af3:docs/design/hit-zones.md`), in the same commit as the first code change of the
build task. I cannot write files.

Karen, the key of the game, verbatim:

> *"all shooting has to be like in real life"* · *"when boar is running we need to aim in empty space
> to get hit in head neck or heart like in real life smae with other animals"* · *"I need quality
> results"*

Architect, read-only session (Read, Grep, Glob; no Studio, no network), evidence precomputed in
`.agent-evidence/` for commit `2ee60af3ea147d1158372ae06f4121ee90fe512d`.

---

## 0. What v2 changes, in one page

**It is a change of KIND, not of numbers** (BRIEF item 7). Today a zone is *whichever protruding
surface box the ray met first*; after v2 a zone is *the most vital volume the shot's path crossed
inside the body*.

| # | What | Where |
|---|---|---|
| 1 | **Zones stop being raycast targets.** The four parts `Boar.Body.buildZones` welds on — each standing `PROTRUSION = 0.06` proud so the ray meets it first — are replaced by **interior volumes that are data**, plus a minimum **hull** of queryable parts (trunk + `HullHead`, and `HullNeck` on the deer) | 3.1, 3.4 |
| 2 | **Seven volumes per species, not four**: `head` (skull/brain), `neck`, `chest` (heart+lungs, the *Kammer*), `spine`, `rear` (hindquarters), `body` (paunch, and still the fallback), `legs`. The two new keys are `neck` and `spine` | 3.2, 3.3 |
| 3 | **Overlap becomes legal and load-bearing.** Two coincident surfaces at one ray distance was a coin toss (task 116 review round 2) and is why every box had to be proud of its neighbour. Volumes may interpenetrate; a `rank` row decides, not the engine | 3.6 |
| 4 | **The zone is decided by a ray/box slab test in the trunk's own frame at the shot's instant**, by a new pure module `Boar.Zones`, read by one function, `Runtime:zoneAt` | 4.1, 4.2, 5.1 |
| 5 | **The weapon asks the animal.** `Weapon.setZoneProvider` is an eighth injected provider in exactly the shape the seven have; the answer rides on the impact as `impact.zone`; `Hits.group` prefers it and `Hits.targetOf` is **unchanged** as the fallback | 4.3, 4.4 |
| 6 | **Penetration is modelled, per cartridge, in studs**: a slug reaches the chamber from the front and *just* from the tail of a boar; a buckshot pellet does not reach it from the front; the .416 reaches a stag's chamber from the tail and the slug does not | 3.7, 11.1 |
| 7 | **`CONFIG.ZONES.PROTRUSION` is DELETED**, with its name, because its whole job was to win a race that no longer happens | 3.1, 10.3 |
| 8 | **The damage model keeps its doctrine and its table shape** (BRIEF item 9): `LETHAL = 100`, `MORTAL = 50`, `DAMAGE[zone][ammo]`, `DAMAGE_BY_WEAPON[weapon][zone]`, `CLASS`, `FLIGHT`, `toughness`. Two new zone keys mean two new rows in each. **A path crossing two volumes takes the MAXIMUM, never the sum** | 4.6, 5.3 |
| 9 | **BRIEF item 14's `276a(d)` is answered: NO.** A head-on chest shot must not read `body`. After v2 it reads `chest`, `neck` or `head` depending on the height it entered at, and the design states the heights | 5.5 |

**Unchanged and not up for discussion here:** the wound model's arithmetic (`Wound.apply`,
`severityFor`, `flightStuds`, `speedScale`, `advance`, `killRecord`), the two thresholds, `toughness`
and the vitals' exemption from it, the Brain's `WOUNDED`/`DOWN`/cripple reactions, the carcass, the
`Downed`/`Despawned`/`Hit` signals, `Hits.group` as the one `HitReport` constructor, the claim
protocol's six payload fields, the six remotes, the `HIT_CLAIM` flag, and every number in
`Boar.CONFIG.WOUND` that already exists.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Model the anatomy as volumes inside the body**, not as surfaces on it: heart/lungs low and
   forward behind the shoulder, the neck, the brain in the skull, the spine along the back, the
   paunch behind the diaphragm, the hindquarters, the legs (direction B).
2. **The shot's path through the body decides which volumes it crosses**, and the damage is the most
   vital one crossed (direction B). A frontal shot reaches the heart and lungs; a quartering shot can
   pass the paunch into the vitals.
3. **Every vital is reachable from every aspect a drive produces**, not from the 40–115° window task
   276 measured on a live animal (MEASURED NOW 4). The aspect window per volume per cartridge is
   stated in degrees (11.1) and swept by a spec (12.1).
4. **Real proportions, cited.** Both species' volumes are derived from the bone positions already
   measured off the loaded rigs and recorded in `Boar.CONFIG.ZONES` and
   `Boar.CONFIG.SPECIES.reddeer.ZONES`, plus the hunting doctrine the research note already holds
   (`docs/research/2026-10-24-real-shooting.md` §7, sources D and E). **Nothing is re-guessed**
   (BRIEF item 8).
5. **Seven kinds, one table each per species.** `Boar.CONFIG.KINDS.ORDER` is
   `male, female, cub, legendary, stag, hind, calf`; the boar kinds use `Boar.CONFIG.ZONES` and the
   three deer kinds use `SPECIES.reddeer.ZONES`, each scaled by `KINDS[kind].scale` through the
   **existing** `Body.kindGeometry`. No new scaling mechanism.
6. **One owner for what a zone means**, and it is the animal: `ServerScriptService.Boar`. The weapon
   gains no zone table, no anatomy and no damage number.
7. **The answer must be cheap enough to compute per pellet** — nine pellets per shot, up to 6 shots
   a second (3.7, 11.2).
8. **Degrade, never crash.** No provider, no direction, no history sample, or no volume crossed each
   has a stated answer, and each is counted (5.4).

### 1.2 Must not

| Prohibition | Why | Whose job instead |
|---|---|---|
| The weapon must not gain a zone table, an anatomy, a damage number or a health concept | v1 §1.2 and `docs/design/shotgun.md` §1.2, unchanged since Milestone 1.5 | `ServerScriptService.Boar` (2) |
| Nothing outside `Boar.Body` may create, destroy, colour, weld or move an animal Instance — including the hull parts | `Boar.Body` is "the only writer of a boar's Instances" (`src/server/Boar/Body.luau` header) | `Boar.Body` |
| `Boar.Zones` must be **pure**: no service, no clock, no Instance, no `Random`, no state | it is what lets the aspect sweep run 7 kinds × 73 directions × 3 heights in a spec with no world | `Runtime:zoneAt` injects the frame and the geometry |
| No second rewind reader, and no second clock | task 266 made `Runtime:cframeAt` the ONE reader of the history ring, and ballistics v5 §5.3 made `t*` the one instant. `zoneAt` calls `cframeAt`; it must not sample the ring itself | `Runtime:cframeAt` |
| No `Workspace:Raycast` for the zone | the volume test is arithmetic on a box the server already holds. A second cast would be a second answer to "what did the bullet pass through" and a second raycast owner (ballistics v5 §1.2) | `Boar.Zones.rayBox`, pure |
| No per-pellet Instance, no zone Instance per volume, no `CollectionService` tag | 7 volumes × 8 animals is 56 parts that nothing can ever hit; and the harness compares attributes and does not compare tags | 3.4: the hull is 2 parts (boar) or 3 (deer) |
| **No new flag** | `Flags.MAX_FLAGS = 18` and `HIT_CLAIM` is the eighteenth (`src/shared/Flags/init.luau`). The rollback is a config row reachable by parameter (3.8) and the Director's alternative is named (16.2 B) | `CONFIG.ZONES.BY_PATH` |
| No new remote, no new payload field on the wire, **no zone on the wire** | the client must not name a zone: direction A's whole shape. `Shotgun.HitClaim`'s six fields are unchanged and carry no zone | ballistics v5 §4.2 |
| No change to the wound arithmetic, the thresholds, the flight formula or the Brain's states | this task adds volumes and two zone keys. Retuning the model as well would be the bundling rule 4 forbids | 4.6, and 16.1 is where Karen retunes |
| A path must not be charged twice | one projectile does one wound: the crossings are reduced to **one** zone before `Wound.apply` ever sees them | 5.3 |
| The drawn mesh must not become raycastable | `BOAR_MODEL`'s own contract: the visual is `CanQuery = false` and carries no `HitZone` (`src/shared/Flags/init.luau`, `BOAR_MODEL` row). v2 narrows the hull; it does not widen it onto the mesh | 3.4, and 16.2 C is the drawn-vs-hull width item |

**One predicate answers one question.** `Zones.crossed` says which volumes a path passed through.
It does not say what that does to the animal (`Wound`), whether the claim was honest (`Validator`),
where the animal was (`Runtime:cframeAt`) or what to draw (`Effects`, `Report`).

---

## 2. Owners — one writer each, named

| Thing | The one writer | On disk | v2? |
|---|---|---|---|
| **What a zone IS: the volume table, the ranks, the penetration depths** | `ServerScriptService.Boar` → `Boar.CONFIG.ZONES` and `SPECIES.reddeer.ZONES`, frozen data with no run-time writer | `src/server/Boar/init.luau` | **rewritten (3.2, 3.3, 3.7)** |
| **Which volumes a path crossed, and which of them is worst** — pure, no world | `ServerScriptService.Boar.Zones` **(NEW)** | `src/server/Boar/Zones.luau` | **new file** |
| **The one answer to "which zone did this shot hit on this animal"** | `ServerScriptService.Boar` → `Runtime:zoneAt` | `src/server/Boar/init.luau` | **new method** |
| Where an animal WAS (the ring, the sampling, the rewound part CFrame) | `ServerScriptService.Boar` → `Runtime:step` writes, `Runtime:cframeAt` reads | `src/server/Boar/init.luau` | **untouched; `zoneAt` is a caller** |
| **Every animal Instance**: the trunk, the hull parts, their welds, their attributes, the flash, the collapse | `ServerScriptService.Boar` → `Boar.Body` | `src/server/Boar/Body.luau` | **`buildZones` → `buildHull`; `kindGeometry` carries two more fields** |
| The damage model (pure, stateless) | `ServerScriptService.Boar.Wound` | `src/server/Boar/Wound.luau` | **untouched** (two new keys are DATA, not code) |
| A boar's wound state, and the one place a hit enters | `ServerScriptService.Boar` → `Runtime:takeHit` | `src/server/Boar/init.luau` | **untouched** |
| Whether a shot happened, what it hit, and the one `HitReport` | `ServerScriptService.Weapon` / `Weapon.Hits.group` | `src/server/Weapon/init.luau`, `Hits.luau` | **asks the provider; `group` prefers `impact.zone`** |
| The verdict on one claim — pure | `ServerScriptService.Weapon.Validator` | `src/server/Weapon/Validator.luau` | **`claimImpact` stamps `at`; ballistics v5 owns the rest** |
| The projectiles in the air | `ServerScriptService.Weapon.Flight` | `src/server/Weapon/Flight.luau` | **stamps `impact.at`: one line** |
| Where the server and client agree the muzzle is, and the shared types | `ReplicatedStorage.Shotgun`, deep-frozen | `src/shared/Shotgun/init.luau` | **`Impact` gains two optional fields; `ZoneQuery` is new** |
| The drive report's silhouette and its rectangles | `ReplicatedStorage.Report`, frozen data (`docs/design/drive-report.md`) | `src/shared/Report/init.luau` | **two new rects, and the draw order (10.2)** |
| What is drawn on screen for a hit | `PlayerScripts.Hud` / `PlayerScripts.Weapon.Effects` | `src/client/Hud/`, `src/client/Weapon/Effects.luau` | **untouched.** The mark drawn a body length behind (276a(c)) is `Effects.puff`'s and is ballistics v5 §16.6's item, not folded in here |

**Boar does not require Weapon and Weapon does not require Boar.** The zone provider is wired by the
composition roots that already wire the history provider — `MatchBoot.server.luau` and
`ForestTestBoot.server.luau`, both of which call `Weapon.setHistoryProvider(function(instance, at) …`
today (evidence: those two files, that call) — one line each.

### 2.1 Files on disk — v2's diff

```
src/server/Boar/init.luau      -> ServerScriptService.Boar       (CONFIG.ZONES rewritten; WOUND +2 rows
                                                                  per table; Runtime:zoneAt NEW;
                                                                  Boar.Zones exported)
src/server/Boar/Zones.luau     -> ...Boar.Zones                  NEW, pure
src/server/Boar/Body.luau      -> ...Boar.Body                   (buildZones -> buildHull;
                                                                  kindGeometry carries rank + hull)
src/shared/Shotgun/init.luau   -> ReplicatedStorage.Shotgun      (Impact: +zone?, +at?; ZoneQuery NEW)
src/server/Weapon/init.luau    -> ServerScriptService.Weapon     (setZoneProvider + askZone, the
                                                                  annotation of flight impacts and of
                                                                  the accepted claim's impact)
src/server/Weapon/Hits.luau    -> ...Weapon.Hits                 (group prefers impact.zone)
src/server/Weapon/Flight.luau  -> ...Weapon.Flight               (stamps impact.at)
src/server/Weapon/Validator.luau -> ...Weapon.Validator          (claimImpact stamps at = t*)
src/server/MatchBoot.server.luau, src/server/ForestTestBoot.server.luau   (one wiring line each)
src/shared/Report/init.luau    -> ReplicatedStorage.Report       (SILHOUETTE: +neck, +spine, draw order)
tests/server/boar_zones.spec.luau       (REWRITTEN: the pure sweep + the live hull)
tests/server/kill_zones.spec.luau       (+ neck and spine, over 7 kinds x 4 guns)
tests/server/boar_hit.spec.luau         (the seam, at the new zones)
tests/server/weapon_hits.spec.luau      (the provider: wired, unwired, throwing, no direction)
tests/server/weapon_shot.spec.luau      (LIVE: a scripted shot at a placed animal, per aspect)
tests/server/report_silhouette.spec.luau (the two new rects; disjointness -> draw order)
tests/server/boar_model.spec.luau, boar_kinds.spec.luau, boar_legendary.spec.luau,
tests/server/boar_behaviour_live.spec.luau  (part counts and names: 10.3)
```

**Nothing under `src/server/Match/`, `src/server/MatchBoot.server.luau`'s match code, `src/client/Match/`
or `src/shared/Drive/` is touched** — `MatchBoot.server.luau` **is** on `TWO_PLAYER_PATHS`
(`tools/agents.py`) and one wiring line in it therefore drags `test2` into the gate. **Put the wiring
in `ForestTestBoot` and `MatchBoot` in a separate, final commit and expect `test2` for the PR** (13.2
states the choice and the cheaper alternative).

---

## 3. The geometry

### 3.1 Two kinds of box, and why the old one could not work

Today (`Boar.CONFIG.ZONES`, built by `Boar.Body.buildZones`) every zone is a Part welded to the
trunk, `CanQuery = true`, `CanCollide = false`, `Massless`, standing `PROTRUSION = 0.06` studs proud
of the trunk on every face a pellet can arrive from, **because a raycast returns the first surface it
meets**. Three consequences, all measured:

- the chest is reachable only **40–115° off the nose**, is **1.54 studs long against a 6.03-stud
  trunk**, and clears the trunk by **0.05 studs a side** (MEASURED NOW 4). Head-on and tail-on chest
  shots read `body` and `rear`;
- a flank shot at the drawn head is charged to `body`, and the config says so in as many words:
  *"the drawn head is 1.1 studs wide and the trunk is 2.0, so a ray from the FLANK meets the trunk
  before it meets the head … the only fix is a narrower trunk at the front, which is a change to the
  animal's collision shape that nobody asked for"* (`Boar.CONFIG.ZONES.head`'s comment);
- every boundary between two zones had to be made proud or interior by hand, one face at a time, or
  it was *"a coin toss: two coincident surfaces at the same ray distance"* (the `rear` row's comment,
  task 116 review round 2).

After v2 there are two kinds of box and they answer two different questions:

| | **HULL** | **VOLUME** |
|---|---|---|
| Question | can a ray hit this animal here? | what is under the skin along this path? |
| Is | an Instance: the trunk, plus one part per volume row marked `hull = true` | **data only**: a row in `CONFIG.ZONES` |
| `CanQuery` | `true` | n/a — never an Instance |
| May overlap | no (and does not) | **yes, and that is the point** |
| Decided by | the engine's cast, as today | `Boar.Zones`, in the trunk's frame |
| Carries `HitZone` | yes — as the **fallback only** (5.4) | no |

`PROTRUSION` is deleted with its name. A reader who finds it next to the new rows will carry the old
meaning into them (the same reason ballistics v5 deletes `LINE_TOLERANCE_STUDS` rather than reusing
it).

### 3.2 The boar's seven volumes

Trunk: `Boar.CONFIG.BODY_SIZE = (2, 3, 5.5)` — x ±1.0, y ±1.5, z ±2.75, **−Z is the front**, origin
at the trunk's centre. Ground is y = −1.5 (`Body.visualOffset` stands the mesh's feet on it).

**The measurements these are built from** (already in the repo, read off the loaded rig in a Play
session on 2026-10-04 and recorded above `Boar.CONFIG.ZONES`): nose z −2.388 y 0.666 · head bone
z −1.279 y 0.912 · eye z −1.779 y 1.087 · ears z −1.208 y 1.570 · `Neck` z −0.866 y 0.872 · mesh
front face z −2.750 · front legs attach z −0.53 to −0.70 (`hip_1_f`, `thigh_f`). The drawn skull runs
z −2.75 to −1.10 and y 0.35 to 1.65.

| volume | `rank` | `CLASS` | `hull` | size (x, y, z) | offset | spans | why this box |
|---|---|---|---|---|---|---|---|
| `head` | 70 | vital | **yes** | (1.20, 1.30, 1.76) | (0, 1.00, −1.93) | x ±0.60 · y 0.35…1.65 · z −2.81…−1.05 | the drawn skull, nose to the back of the jaw. Width and height are today's accepted `ZoneHead`; only the back face moves, from −1.45 to −1.05, so the whole skull is in it |
| `neck` | 60 | vital | no | (1.00, 1.00, 0.85) | (0, 0.90, −0.625) | x ±0.50 · y 0.40…1.40 · z −1.05…−0.20 | `Neck` sits at z −0.866, y 0.872. A boar's neck is short and thick; it abuts the skull at −1.05 |
| `chest` | 50 | vital | no | (1.50, 1.60, 1.80) | (0, 0.25, −0.15) | x ±0.75 · y −0.55…1.05 · z −1.05…+0.75 | the *Kammer*: heart and lungs, low and forward, from the base of the neck back past the shoulder (the forelegs attach at −0.53/−0.70). Source E |
| `spine` | 40 | crippling | no | (0.70, 0.45, 3.35) | (0, 1.275, 0.775) | x ±0.35 · y 1.05…1.50 · z −0.90…+2.45 | the backbone strip under the back line. A high shot over the ribs breaks it and the animal cannot run — Karen's crippling reaction, now reachable along the whole back and not only at the rump |
| `rear` | 30 | crippling | no | (1.80, 1.80, 1.20) | (0, 0.60, 2.15) | x ±0.90 · y −0.30…1.50 · z +1.55…+2.75 | the hams and pelvis. Karen, 2026-10-03: *"can be hit to back part start to do circles with first legs on"* (task 116). Clipped to the trunk's rear face |
| `body` | 20 | nonVital | no | (1.80, 1.85, 0.80) | (0, 0.125, 1.15) | x ±0.90 · y −0.80…1.05 · z +0.75…+1.55 | the paunch, behind the diaphragm and in front of the pelvis — the *Waidwundschuss*. **It is also the fallback zone** (5.4), so the brisket and the flank that no volume claims are still `body`, exactly as the trunk's own comment has always said |
| `legs` | 10 | nonVital | no | (2.00, 1.00, 4.60) | (0, −1.00, 0.30) | x ±1.00 · y −1.50…−0.50 · z −2.00…+2.60 | the bottom third, the whole length — today's band, unchanged in extent |

Unclaimed, deliberately: **the brisket and lower neck**, z −2.00…−1.05 at y −0.50…+0.35 — the wedge
in front of the chest and under the head. A short projectile that stops there crosses nothing and is
charged `body`, which is what it is charged today.

### 3.3 The red deer's seven volumes

Trunk: `Boar.CONFIG.SPECIES.reddeer.BODY_SIZE = (1.8, 4.8, 7.05)` — x ±0.9, y −2.40…+2.40 (the box
bottom **is** the ground), z ±3.525. Every deer kind is this box × `KINDS[kind].scale`.

**The measurements** (already in the repo, measured in headless Blender on 2026-10-20 and
cross-checked against the loaded model in Studio, *"the two agree to 0.02 studs on every bone"*):
nose z −3.525 · skull bone (0, 2.72, −2.29) · mouth (0, 2.81, −2.42) · ear y 3.11 · `neck_01`
z −1.21 · `hip_1_f` z −0.53 · `thigh_f` z −0.63 · brisket y +0.05 · back y +2.45 · `Spine_base`
z +2.18 · `hip_b` z +2.79 · first tail bone z +3.15.

| volume | `rank` | `CLASS` | `hull` | size | offset | spans | why |
|---|---|---|---|---|---|---|---|
| `head` | 70 | vital | **yes** | (1.00, 1.10, 1.70) | (0, 2.72, −2.74) | y 2.17…3.27 · z −3.59…−1.89 | **unchanged, measured**: the skull between the mouth and `neck_01`. A red deer carries it a whole trunk-height above a boar's |
| `neck` | 60 | vital | **yes** | (0.75, 1.90, 1.50) | (0, 1.95, −1.60) | x ±0.375 · y 1.00…2.90 · z −2.35…−0.85 | the long neck from the withers up to the skull base. It stands above the trunk's top (2.40), so it is a hull row — on a stag it is one of the two things a shot can meet that the box does not cover |
| `chest` | 50 | vital | no | (1.40, 1.80, 2.20) | (0, 0.95, −0.80) | x ±0.70 · y 0.05…1.85 · z −1.90…+0.30 | the chamber from the brisket (y +0.05) up to below the back line, from the base of the neck back past the shoulder (`hip_1_f` −0.53) |
| `spine` | 40 | crippling | no | (0.60, 0.50, 3.40) | (0, 2.05, 0.50) | x ±0.30 · y 1.80…2.30 · z −1.20…+2.20 | the back line from the withers to `Spine_base` +2.18 |
| `rear` | 30 | crippling | no | (1.60, 2.50, 2.00) | (0, 1.05, 2.40) | x ±0.80 · y −0.20…2.30 · z +1.40…+3.40 | the hams and pelvis: `hip_b` +2.79, tail +3.15 |
| `body` | 20 | nonVital | no | (1.70, 2.00, 1.10) | (0, 0.90, 0.85) | x ±0.85 · y −0.10…1.90 · z +0.30…+1.40 | the paunch, and the fallback |
| `legs` | 10 | nonVital | no | (1.80, 2.50, 5.00) | (0, −1.15, 0.50) | x ±0.90 · y −2.40…+0.10 · z −2.00…+3.00 | *"a deer is mostly legs"*: the band from the ground to the brisket, 52 % of the animal's height against the boar's third |

### 3.4 The hull — two parts on a boar, three on a deer

`Boar.Body.buildHull` (today's `buildZones`, renamed and reduced) builds **one part per volume row
with `hull = true`**, and nothing else. Every other volume lies inside the trunk, so the trunk is its
hull.

| Property | Value | Reason — all four are today's `buildZones` values and the reasons are its own |
|---|---|---|
| `Parent` | the trunk Part | `Hits.targetOf` walks **ancestors** for `Damageable == true`, so a child resolves to the trunk as the target root; and `RaycastParams.FilterDescendantsInstances` is a descendant filter, so excluding the trunk excludes the hull (ballistics v5 §5.6 property 1 still holds, with fewer parts) |
| `Massless` | `true` | the assembly's mass, centre of mass and inertia stay what they were, so `MAX_FORCE`, `MAX_TORQUE` and `ACCEL` remain correct |
| `CanCollide` | `false` | the collision body stays the trunk box |
| `CanQuery` | `true` | being raycastable is its entire purpose |
| `CanTouch` | `false`, `Anchored` `false`, one `WeldConstraint` to the trunk | unchanged; an anchored welded child anchors the whole animal |
| `Color` | `ZONE_TINT and spec.tint or BODY_COLOR` | unchanged |
| attribute `HitZone` | the row's own name (`"head"`, `"neck"`) | **the fallback contract only** (5.4) |
| attribute `Damageable` | **not set** | it belongs on the target root alone |
| `Name` | `HullHead`, `HullNeck` | greppable, and **renamed on purpose**: a part called `ZoneChest` that no longer decides a zone would be the worst kind of stale name. The three that go are `ZoneChest`, `ZoneRear`, `ZoneLegs` |

**What the boar's hull keeps, face by face.** `HullHead` spans z −2.81 and y 1.65 against the trunk's
−2.75 and 1.50 — the same **0.06 proud at the front and 0.15 proud at the top** that today's
`ZoneHead` has, because it is the same measured skull. So the one thing a player can see about the
hull does not change: the boar still has a head sticking out in front and above, and a nose-on or
over-the-top shot still meets it. The deer's `HullHead` is unchanged outright and `HullNeck` is new
where there was nothing but air.

**What the hull loses:** the 0.06 of flank proudness on `ZoneChest`/`ZoneRear`/`ZoneLegs` and the
0.15 past the rear face on `ZoneRear`. Every one of those shots now lands on the trunk 0.06–0.15
studs further in and the path answers the same zone (5.1). **This is the one place a shot that hit
yesterday could miss today**: a ray that grazed the proud flank of `ZoneLegs` without touching the
trunk. It is 0.06 studs of silhouette on each side, it is in the honest direction (the hull is now
exactly the collision box plus the measured head), and the live spec sweeps the flank at ±0.05 studs
of the box edge to show what happens there (12.2 case 5).

### 3.5 Per kind: nothing new

`Body.kindGeometry(kind, config)` already builds `zones[name] = { part, size = spec.size * scale,
offset = spec.offset * scale, tint }` for every name in `ZONES.ORDER`, and `Body.create` stores the
result on the handle as `handle.geometry`. **v2 adds two fields to that copy — `rank` and `hull` —
and nothing else.** So:

- all seven kinds scale by `KINDS[kind].scale` through the existing path (male 1.0, female 0.85, cub
  0.45, legendary 1.35, stag 1.0, hind 0.8553, calf 0.495);
- `boar_kinds.spec` and `boar_legendary.spec`, which assert exactly that scaling over
  `ZONES.ORDER`, keep working against seven names instead of four;
- `Runtime:zoneAt` reads `entry.body.geometry.zones` and therefore needs **no species lookup, no
  kind lookup and no second table**. `Boar.speciesConfig` already decided which species' `ZONES` the
  animal was built from, at spawn.

### 3.6 Overlap is a feature, and `rank` is what replaces the race

Two volumes may interpenetrate. Where they do, **the crossing with the greatest `rank` wins** — one
number in one data row, decided by the design, never by the engine's choice between two coincident
surfaces.

`rank`, descending: `head` 70 · `neck` 60 · `chest` 50 · `spine` 40 · `rear` 30 · `body` 20 ·
`legs` 10.

**It is a data row rather than a derivation, and the spec pins it to the doctrine so it cannot
drift** (12.1 case 3): the order must agree with `CLASS` (`vital` above `crippling` above
`nonVital`) and, inside one class, with the `DAMAGE[zone].Slug` ordering. Today that reads:
head/neck/chest vital at 100 · spine/rear crippling at 55 · body 55 and legs 30 nonVital. A later
retune that makes `legs` hurt more than `body` without moving the ranks fails that assertion instead
of silently reporting the wrong zone.

Why not derive the rank from the damage directly: the damage depends on the cartridge, the weapon
and the animal's `toughness`, and the zone has to be decided **before** any of them is consulted
(`Wound.damageFor` takes the zone as its first argument). A rank that changed with the gun would mean
the hit card named a different organ for the same hole.

### 3.7 How deep a projectile goes — `PENETRATION`

The path is bounded. Without a bound a buckshot pellet into a ham would be charged to the chamber on
the far side of the animal.

`CONFIG.ZONES.PENETRATION`, keyed by the **ammo word** exactly as `WOUND.DAMAGE` is, with
`PENETRATION_BY_WEAPON` keyed by the **weapon id** exactly as `WOUND.DAMAGE_BY_WEAPON` is, consulted
first, falling through when a weapon has no row (so the shotgun, the semi-auto and every hit that
carries no weapon are unchanged in shape):

| row | studs | metres (at `Report.CONFIG.METRES_PER_STUD = 0.28`) | what it is |
|---|---|---|---|
| `PENETRATION.Slug` | **2.20** | 0.62 | a 1 oz rifled slug / Brenneke in tissue. **Derived to a purpose and the purpose is stated**: 0.20 studs more than the worst centre-line depth to a boar's chamber (2.00, tail-on), so the Texas heart shot *just* reaches it and nothing reaches it by accident |
| `PENETRATION.Pellet` | **0.90** | 0.25 | one 00 buckshot pellet at drive range. Enough to reach the chamber from the flank (0.25 studs of rib) and not from the front (1.70 studs of brisket) |
| `PENETRATION_BY_WEAPON.rifle` | **4.00** | 1.12 | .416 Rigby, 400 gr: through a stag end to end (its tail-to-chamber depth is 3.23) |
| `PENETRATION_BY_WEAPON.lever` | **3.00** | 0.84 | .45-70, 405 gr: through a boar end to end, not through a stag |

**These four numbers are not measured and they are Karen's dials** (15, 16.1 item 3). What is
measured is the geometry they are set against (3.2, 3.3) and the arithmetic in 11.1. The cartridges
themselves are source F of `docs/research/2026-10-24-real-shooting.md`.

**Penetration is NOT divided by `toughness`.** The legendary's `Schild` already divides its damage,
and dividing the depth as well would apply one armour twice — the same argument `Wound.damageFor`'s
header makes for refusing a second `LETHAL` scale. 16.1 item 7 is where Karen overrules it.

### 3.8 The switch, and why it is a config row and not a flag

`CONFIG.ZONES.BY_PATH`, default **`true`**.

- `true`: the zone is the most vital volume the path crossed (5.1).
- `false`: `Runtime:zoneAt` returns `nil` for every query, every impact falls through to
  `Hits.targetOf`'s attribute answer, and the game is the attribute game — on the **new hull**, so
  it is `head`/`neck` on those parts and `body` everywhere else. It is a rollback of the *decision*,
  not of the *geometry*.

**It is a config row because `Flags.MAX_FLAGS = 18` and `HIT_CLAIM` is the eighteenth**
(`src/shared/Flags/init.luau`). CLAUDE.md's rule for a feel-critical path — born OFF, merged dark,
Karen's OK flips the default — cannot be followed without retiring a row first, and that is the
Director's call, not mine: **16.2 B** states it, with the default that lets the build proceed either
way. Both states are reachable **by parameter** (`Boar.newRuntime` merges `world.config`), which is
the property CLAUDE.md actually requires of a flagged path, and 12.1 case 9 tests both.

---

## 4. Public interface

Types are Luau annotations. `luau-lsp analyze` is not in CI, so they are documentation plus editor
checking, not a gate.

### 4.1 `Boar.Zones` — pure, and the whole geometry

```luau
-- ServerScriptService.Boar.Zones
export type Volume = {
    name: string,
    size: Vector3,            -- the box, in the trunk's frame, already scaled by the kind
    offset: Vector3,          -- the box centre, in the trunk's frame
    rank: number,             -- 3.6
    hull: boolean?,           -- true: Boar.Body builds a queryable part for it
    part: string?,            -- the hull part's Name, when hull is true
    tint: Color3?,            -- read by Report.SILHOUETTE's mirror and by the hull part
}
export type Crossing = { zone: string, rank: number, enter: number, exit: number }  -- studs along the path

-- The slab test (source B, source F). Returns (tEnter, tExit) in studs along `direction`, or nil
-- when the ray misses. `direction` must be a unit vector; both returns may be negative, which is
-- "the box is behind the entry point".
Zones.rayBox(origin: Vector3, direction: Vector3, centre: Vector3, half: Vector3): (number?, number?)

-- Every volume the path crosses, in ascending `enter` order, clipped to [0, maxDepth].
Zones.crossed(geometry, order: { string }, origin: Vector3, direction: Vector3, maxDepth: number): { Crossing }

-- The most vital crossing: the greatest `rank`. nil for an empty list.
Zones.worst(crossings: { Crossing }): string?

-- How deep this projectile goes in THIS animal: PENETRATION_BY_WEAPON[weapon] or PENETRATION[ammo],
-- else `zones.PENETRATION_DEFAULT_STUDS`.
Zones.depthFor(zones, ammo: string?, weapon: string?): number

-- crossed + worst, in one call. THE function Runtime:zoneAt uses.
Zones.zoneFor(zones, geometry, origin: Vector3, direction: Vector3, ammo: string?, weapon: string?): (string?, { Crossing })

-- The rows Boar.Body must build a part for.
Zones.hullRows(geometry, order: { string }): { Volume }
```

`origin` and `direction` are in the **trunk's object space**. No `game:GetService`, no clock, no
`Instance`, no `Random`, no `CFrame` of the world. `geometry` and `zones` are parameters, not
lookups, so a spec passes its own tables — the discipline `Wound` and `Brain` are already held to.

**`rayBox` is arithmetic I can state in full, which is why it is in this document and not in a
library.** For each axis `i`, with `d = direction[i]` and `c = origin[i] − centre[i]`:

```
if |d| < 1e-9 then                      -- parallel to this slab
    if |c| > half[i] then return nil end
else
    t1 = (-half[i] - c) / d ;  t2 = (half[i] - c) / d
    tmin = max(tmin, min(t1, t2)) ;  tmax = min(tmax, max(t1, t2))
    if tmin > tmax then return nil end
end
```
starting at `tmin = -math.huge`, `tmax = math.huge`, and returning `(tmin, tmax)`. Eighteen
multiplications and no engine call. The degenerate cases — a ray exactly parallel to a face, a ray
starting inside the box (`tmin < 0 < tmax`, which is legal and means "the shot began inside this
volume"), and a zero-extent axis — are the three the spec drives first (12.1 case 1).

### 4.2 `ServerScriptService.Boar` — the owner

```luau
-- NEW. The one answer to "which zone did this shot hit on this animal".
Runtime:zoneAt(instance: Instance, query: Shotgun.ZoneQuery): string?
Boar.Zones                        -- the pure module, exported for specs, as Boar.Wound and Boar.Brain are
Boar.CONFIG.ZONES                 -- rewritten (3.2, 3.7, 3.8)
Runtime:stats()                   -- EXTENDED, three counters: zoneQueries, zoneMisses, zoneWhy
```

`zoneAt`, step by step — and it is deliberately the **same walk** `Runtime:cframeAt` makes:

1. refuse a non-Instance, a non-finite `at`, or `CONFIG.ZONES.BY_PATH ~= true` → `nil`;
2. find the entry whose `entry.body.part` **is** `instance` or is an ancestor of it (`cframeAt`'s own
   loop; `entry.body.part == part` is also `takeHit`'s key, so there is one index and no second id
   table);
3. a dead, `DOWN` or `GONE` animal → `nil` (`cframeAt`'s own rule: a carcass has no zones to hit);
4. `trunkThen = self:cframeAt(trunk, query.at)` — **the only rewind, through the only reader.** `nil`
   (outside the ring's span, no sample, no provider) → `nil`, counted in `zoneMisses` with
   `zoneWhy`;
5. `origin = trunkThen:PointToObjectSpace(query.point)`,
   `direction = trunkThen:VectorToObjectSpace(query.direction)` normalised (a zero or non-finite
   direction → `nil`, `zoneWhy = "no-direction"`);
6. `Zones.zoneFor(self._config.ZONES, entry.body.geometry.zones, origin, direction, query.ammo,
   query.weapon)`;
7. return the zone, or `nil` when the path crossed nothing — **`nil`, not `"body"`**: the fallback
   is one decision in one place and that place is 5.4.

```luau
-- ReplicatedStorage.Shotgun  (NEW type, beside Impact)
export type ZoneQuery = {
    point: Vector3,       -- where the projectile entered the animal, in WORLD space
    direction: Vector3,   -- the projectile's direction of travel there, world space, unit
    ammo: string?,        -- "Slug" | "Buck"'s pellet word; picks the penetration row
    weapon: string?,      -- the Weapons.WeaponId; picks the per-weapon penetration row
    at: number?,          -- GetServerTimeNow() of the impact. nil is "now"
}
-- Impact gains two OPTIONAL fields and loses none:
--   zone: string?   the answer, written by ServerScriptService.Weapon after it asks the provider
--   at: number?     when this impact happened, stamped by Flight (the cast) or by Validator (t*)
```

### 4.3 `ServerScriptService.Weapon` — the eighth provider

```luau
-- WHAT THE BULLET PASSED THROUGH, as the animal's own owner describes it. The weapon knows what
-- neither a zone nor an organ IS.
function Weapon.setZoneProvider(provider: ((Instance, Shotgun.ZoneQuery) -> string?)?)
```

- asked through `pcall`, like all seven before it (`askTarget`, `askStand`, `askDriveOpen`,
  `askWhereWas`, `askLineUnsafe`, …);
- **unwired means `nil` means today's game**: the attribute answers (5.4). That is this owner's
  standing default and the reason every `tests/server/weapon_*.spec.luau` and the bare DEV place
  keep working untouched;
- a provider that **throws** is not a provider that refused: the error's first 120 characters go to
  `stats.zoneProviderWhy`, exactly as `askWhereWas` records its own.

**Ballistics v5 §1.2 says "no eighth provider", and this is not a contradiction.** That sentence is
about the **LOS cast's exclude list**, where `shot.ignore` plus the `target` that `Hits.targetOf`
already returned answer the question completely. The zone has no other source: only the animal knows
where its heart is. The shape is the same, the `pcall` is the same, and the default is the same.

**Where it is asked — two sites, both in `Weapon`, each with its own instant:**

| path | site | `point` | `direction` | `at` |
|---|---|---|---|---|
| the server's own flight (flag off, or a refused claim) | `onShotLanded`, over `res.impacts`, before `Hits.group` | `impact.position` | `(impact.position − shot.muzzle).Unit` | `impact.at`, stamped by `Flight` when it cast |
| an accepted claim | `judgeClaimFor`, on the one impact `Validator.claimImpact` built | `claim.point` | `(claim.point − bore).Unit` | **`t*`** — the instant checks 5 and 6 already chose (ballistics v5 §5.3). One clock, named once, and this design adds no second one |

**The chord, not the tangent, and the error is bounded.** `(impact.position − muzzle).Unit` is the
straight line from bore to impact, while the projectile arrives along its own slightly-dropped
tangent. The drop is tiny by measurement: `sightOffsetAt(150)` is **+0.034 studs** with
`GRAVITY_SCALE = 0.12` and the whole miss decomposition is `up` 0.002–0.156 studs (MEASURED NOW,
supporting readings). Over a 150-stud path 0.16 studs of sag is 0.06° of angle, which across a
7-stud body is **0.008 studs** of lateral error inside the animal — three orders under the smallest
volume dimension (0.45). If that ever needs to be exact, the upgrade is one field: `Flight` already
knows the segment direction at the cast and can stamp it beside `at`. Named, not built.

### 4.4 `Weapon.Hits` — one preference, nothing else

```luau
-- UNCHANGED: (target root, zone) off the two attributes. It is the FALLBACK now, not the only answer.
Hits.targetOf(instance: Instance?): (Instance?, string)

-- UNCHANGED SIGNATURE. One line changes inside: the zone is `impact.zone` when the animal answered,
-- else `Hits.targetOf`'s attribute answer, exactly as today.
Hits.group(shooter, impacts, ammo, now, weapon): { HitReport }
```

That keeps `Hits.group` pure, keeps it the one constructor of a `HitReport`, keeps one report per
(shot, target) with `zones` as the per-pellet tally, and keeps all fifteen existing `Hits.group`
call sites in the specs compiling untouched (evidence: the fifteen `Hits.group(` lines under
`tests/server/`). **Each pellet keeps its own zone**, because each impact is annotated separately —
so buckshot still spreads across volumes and `report.zones` still means what it means.

### 4.5 `Boar.CONFIG.ZONES` after v2 — the data

```luau
ZONES = {
    ORDER = { "head", "neck", "chest", "spine", "rear", "body", "legs" },  -- the sweep order, and
                                                                           -- what every spec walks
    BY_PATH = true,                 -- 3.8
    ZONE_TINT = true,               -- unchanged: paints the HULL parts; the tints stay data for all
                                    -- seven, because Report.SILHOUETTE mirrors them
    PENETRATION = { Slug = 2.20, Pellet = 0.90 },          -- 3.7
    PENETRATION_BY_WEAPON = { rifle = 4.00, lever = 3.00 },
    PENETRATION_DEFAULT_STUDS = 2.20,  -- an ammo word with no row: the slug's reach, never 0 and
                                       -- never infinite
    -- then the seven rows of 3.2, each { part?, hull?, rank, size, offset, tint }
}
```

**`body` IS in `ORDER` now**, where it used to be the trunk's own fallback and therefore unnamed.
It needs a box because the paunch is a place, and it keeps being the fallback name (5.4). The
consequence for `Report.CONFIG.ZONES` — which lists five and comments that `body` *"is not in
`Boar.CONFIG.ZONES.ORDER`"* — is 10.2.

`PROTRUSION` is **gone** (3.1).

### 4.6 `Boar.CONFIG.WOUND` after v2 — two rows per table, and nothing else

The doctrine and the shape are kept (BRIEF item 9). `LETHAL = 100`, `MORTAL = 50`, `DAMAGE` keyed by
the ammo word, `DAMAGE_BY_WEAPON` keyed by the weapon, `CLASS`, `FLIGHT`, `toughness` dividing
non-vital points only — all unchanged. Added:

| table | `neck` | `spine` | basis |
|---|---|---|---|
| `DAMAGE` | `{ Slug = 100, Pellet = 30 }` | `{ Slug = 55, Pellet = 11 }` | the neck is an instant stop in source E's own first line (*"brain / neck (spine) — instant"*), so it is a vital and a slug kills. The spine is the `rear` row exactly: as much meat and bone, and the row exists so `CLASS` can call it crippling |
| `DAMAGE_BY_WEAPON.rifle` | `100` | `75` | head/chest's rule: *"one shot, any gun, and the vitals are never armoured"*. The spine takes `rear`'s 75 for `rear`'s reason — *"at 100 a rifle rump shot would be instant death and the reaction she asked for would never happen"* |
| `DAMAGE_BY_WEAPON.lever` | `100` | `65` | likewise |
| `FLIGHT` | `0` | `90` | a neck shot drops where it stands; a broken spine *"does not run, it turns on the spot"* — `rear`'s own number and its own reason |
| `CLASS` | `"vital"` | `"crippling"` | source E's order |

Pellet numbers: `neck` 30 (four pellets kill, against the head's three and the chest's four) and
`spine` 11 (the trunk's own). Both are Karen's dials and both are one line.

**What this does to the keys**: `Wound.chargedZone`, `row()` and `FALLBACK_ZONE = "body"` are
untouched — a zone with a `DAMAGE` row is charged under its own name, and `neck` and `spine` now have
rows. No rename anywhere: `head`, `chest`, `body`, `rear` and `legs` keep their names and their
numbers, so `kill_zones.spec`'s existing grid, `Report`, `HitLog`, `Match`, the hit card and the Hud
line all keep reading what they read. The Hud prints the zone with `%-6s` (`src/client/Hud/init.luau`
`hitLine`) and `"spine"` (5) and `"neck"` (4) both fit.

### 4.7 What the claim path gains and loses — the bound, in this design's terms

Ballistics v5 §5.9 owns the enumeration of what a modified client can do. **This design changes one
term in it and the change is in the server's favour:**

- **Lost (by the client):** naming a zone part. Today the claim names an Instance and *"the zone is
  that part's own `HitZone`"*, so `ZoneChest` on the wire **was** a chest claim — exactly the licence
  task 274's `claimLastPart` measured (`ZoneChest(chest)` on every claim of a trial). After v2 there
  are no chest, rear or leg parts to name. A cheat can name the trunk or the head hull and nothing
  else.
- **Still available:** choosing the entry point on the claimed part's box (bounded by check 3,
  `SKIN_STUDS = 0.15` of the part's own half-extents) and the claim's own direction (bounded by check
  4, `CLAIM_LINE_STUDS = 0.50` and `CLAIM_PATH_TOLERANCE_STUDS = 1.00`). Together those pick the
  volume.
- **So the bound is:** *a cheat gets the zone that a shot it genuinely could have taken, at an
  instant the server's own history agrees with, through a line the server's own cast agrees was
  clear, would have crossed.* That is aimbot-grade aim, which **no server-side check can refuse** —
  the server cannot know where a player meant to point — and it is the same bound an honest expert
  shot has. **Nothing in the claim decides anatomy:** the volumes, the ranks and the penetration are
  the server's own data, read in the server's own rewound frame.
- **And one check gets strictly tighter for free:** the claimed point must now be consistent with a
  path that crosses a volume. A claim whose offset is on the trunk's flank with a direction along the
  flank crosses nothing and is charged `body` — it cannot be turned into a chest by naming a part.

### 4.8 What does NOT change

`Runtime:takeHit`'s signature and behaviour · the `Hit` payload · `Runtime.Hit`/`Downed`/`Despawned`
· `KillRecord` · `WoundState` · `Wound`'s whole module · `Brain`'s states, the bolt, the cripple
circle and the carcass · `Boar.toughnessFor` · `Runtime:cframeAt` · `Boar.CONFIG.HISTORY` ·
`Hits.POINTS_MAX` and the per-pellet `points` list · the six remotes · `HitClaim`'s six fields ·
`Weapon.markHit` · `HitLog` · `Match.Score` (which has taken no zone since task 160) · the client,
entirely.

---

## 5. The rules

### 5.1 How a zone is decided, end to end

```
1. the projectile stops on a hull part of animal A, at world point P, travelling along world unit D
2. Weapon asks: zone = askZone(instance, { point = P, direction = D, ammo, weapon, at })
3. Boar finds A's trunk, refuses if A is dead/DOWN/GONE
4. F = Runtime:cframeAt(trunk, at)                 -- the one rewind, the one clock
5. o = F:PointToObjectSpace(P) ; d = F:VectorToObjectSpace(D).Unit
6. depth = Zones.depthFor(ZONES, ammo, weapon)     -- 3.7
7. for each name in ZONES.ORDER:
       tEnter, tExit = Zones.rayBox(o, d, geometry[name].offset, geometry[name].size / 2)
       keep it when tExit > 0 and tEnter < depth    -- it crossed, inside the projectile's reach
8. zone = the kept crossing with the greatest rank  -- Zones.worst
9. nil when nothing was kept -> the fallback chain, 5.4
```

Step 7's condition is written out because its two ends are both load-bearing: `tExit > 0` lets a path
that **begins inside** a volume count it (a contact shot, and every hull-head entry, which starts
inside the `head` box by construction), and `tEnter < depth` is the penetration bound.

### 5.2 Why the path and not the surface, in one paragraph

A surface box answers "what did the ray touch first", which is a question about the animal's outside.
The question Karen asks is about its inside: *"to get hit in head neck or heart like in real life"*.
Those are organs, they are at depth, and several of them are behind the same patch of skin — a boar's
chamber is under its shoulder, its spine is above its lungs, its paunch is in front of its pelvis.
A model made of outside patches has to choose one organ per patch and then make the patches not
overlap, which is how the chest ended up 1.54 studs long and unreachable from 65 % of the compass.
A model made of volumes does not choose: it reports what the hole went through.

### 5.3 "The damage by the most vital volume crossed" — the function, the owner, and MAX not SUM

- **The function** is `Zones.worst` (4.1), the owner is `Boar.Zones`, and it runs **before** any
  damage exists.
- **It takes the maximum, by `rank`, and never the sum** (BRIEF item 9). One projectile makes one
  wound channel; charging the paunch *and* the lungs for one bullet would double the points for a
  shot that did what one shot does, and it would make `DAMAGE`'s per-zone numbers unreadable (a
  quartering body-into-chest hit would cost 155 of a 100-point `LETHAL`). The existing model already
  encodes "the worst thing that happened to this animal decides": `Wound.flightStuds` takes
  `math.max` over the zones it has been hit in, for the same reason.
- **So `Wound.apply` is called with exactly one zone per projectile, and `Wound` is untouched.**
  Buckshot still charges each pellet in its own zone through `hit.zones`, because each pellet got its
  own answer (4.4).
- `Zones.crossed` still **returns** the whole list, and `Runtime:stats().zoneCrossings` keeps a count
  of multi-volume paths, because "how often does a shot pass through two organs" is a question the
  first playtest will raise and a counter answers it for free.

### 5.4 The fallback chain — four ways to not know, one answer each

| cause | answer | counted as |
|---|---|---|
| `BY_PATH = false` | the attribute (`Hits.targetOf`), i.e. `head`/`neck` on the hull parts, `body` on the trunk | nothing; it is the chosen state |
| no provider wired | the attribute | `stats.zoneProviderWhy = "unwired"` (Weapon) |
| the provider threw | the attribute | `stats.zoneProviderWhy = <the error, 120 chars>` |
| the animal is not this runtime's, is dead/DOWN/GONE, or the ring cannot place it at `at` | the attribute | `Runtime:stats().zoneMisses`, `zoneWhy` (the same vocabulary `cframeAt` already writes: `"no-entry"`, `"down:<state>"`, `"span live=…"`) |
| the path crossed **no** volume (the brisket wedge, a pellet that stopped in the skin) | **`body`** — through `Hits.targetOf`'s existing answer for the trunk, not through a second constant | `Runtime:stats().zoneCrossings.none` |

**The chain is "ask the animal, else read the attribute", and it is one `or`.** That is why
`Hits.targetOf` is unchanged and why the hull parts keep their `HitZone`: the degraded game is a
coarse game, never a crash and never an `unknown`. `Runtime:stats().unknownZoneHits` keeps meaning
what it means — an attribute typo — because no path in this design writes a zone name that
`WOUND.DAMAGE` does not have a row for.

### 5.5 BRIEF item 14's `276a(d)`, answered: **is a head-on chest shot supposed to read `body`? No.**

Today it does, and the reason is geometric: head-on, the first surface the ray meets is the trunk's
front face, which carries `HitZone = "body"`, because `ZoneChest` starts 1.30 studs further in. Nine
tasks of *"0 of 5 chest"* were partly this.

After v2, a head-on shot on a boar's centre line reads, by the height it entered at (trunk frame):

| entry height y | crosses | reads |
|---|---|---|
| 1.65 … 0.35 | the skull | `head` |
| 0.35 … −0.55 | the brisket wedge, then the chest at z −1.05 | **`chest`** (1.70 studs of path; a slug reaches it, a pellet does not — 3.7) |
| −0.55 … −1.50 | the leg band | `legs` |
| and at y 0.40…1.40 from a steeper down-angle, the neck before the chest | | `neck` |

So the answer Karen asked for — *"head neck or heart"* — is the answer a frontal shot gives, and the
only way to read `body` from the front is to stop in the brisket, which is what a pellet at range
does in life.

### 5.6 The aspect assertions, in degrees (BRIEF item 10)

**Aspect θ** is the angle, in the horizontal plane, between the animal's own forward (−Z) and the
direction **from the animal to the shooter**: 0° head-on, 90° broadside, 180° tail-on. The band task
276 measured for the old chest box, by ray at 5° steps on a live animal, was **40–115°**.

Centre-line depth from the hull to the chamber's near face, computed off 3.2 and 3.3:

| | boar (male) | red deer (stag) |
|---|---|---|
| θ = 0° (head-on, at the chest's own height) | 1.70 studs | 1.63 studs |
| θ = 90° (broadside) | 0.25 studs | 0.20 studs |
| θ = 180° (tail-on) | 2.00 studs | 3.23 studs |

Against 3.7's reaches, that gives the assertions the spec holds:

| # | Assertion | Holds because |
|---|---|---|
| **B1** | **A slug reaches `chest` at every aspect θ ∈ [0°, 135°], both flanks, aimed at the chamber's centre, on all seven kinds** | the aim point is inside a convex box, so any line through it crosses it; the only bound is the depth, and the worst depth in that band is the head-on 1.70 against 2.20 |
| **B2** | **A frontal (θ = 0° ± 10°) slug at the chamber's centre reads `chest`**, with the margin reported: 2.20 − 1.70 = **0.50 studs** on a boar, 0.57 on a stag | 5.5 |
| **B3** | **A rear-quartering (θ = 120°…150°) slug entering behind the last rib crosses `body` then `chest`, and reads `chest`** — direction B's *"a quartering shot can pass the paunch into the vitals"* | `Zones.crossed` returns both; `rank` 50 > 20 |
| **B4** | **A tail-on (θ = 180°) slug reads `chest` on a BOAR and `rear`/`body` on a STAG** | 2.00 < 2.20 < 3.23. The Texas heart shot works on the short animal and not on the long one, and the **.416 (4.00) reaches the stag's chamber where the slug cannot** — the rifle doing what a rifle does, out of the geometry rather than out of a special case |
| **B5** | **A buckshot pellet reaches `chest` at θ ∈ [60°, 120°] and NOT at θ = 0°** | 0.25 and 0.20 studs broadside against a 0.90 reach; 1.70 head-on against it |
| **B6** | **`head` is reachable from a pure FLANK** (θ = 90°, at skull height), which it is not today | the skull is a volume 1.20 wide inside a hull 2.00 wide: the path enters the trunk and crosses it. The config's own *"a pure flank is body"* limit is removed by the change of kind, not by widening anything |
| **B7** | **The rear band where a slug falls short is MEASURED AND REPORTED by the spec, not asserted** | B1 stops at 135° on purpose. Between 135° and 180° the path length through the paunch rises above 2.20 on the boar at some angle, and I will not write a number I have not computed per degree (15) |

### 5.7 What the player is told, and what he is not

The zone travels in `report.zone` exactly as it does today, so the hit card's label, the Hud's
one-line hit row, `HitLog`, the drive report's dot and `KillRecord.killingZone` all keep working, and
two new strings (`neck`, `spine`) appear in them. **No organ list, no damage number and no wound
channel is drawn** — that is a new picture with a new owner and it is not this task (16.2 A).

---

## 6. What it reads from and writes to other systems

### 6.1 Reads

| What | Owner of the other end | Status |
|---|---|---|
| `ZoneQuery` (point, direction, ammo, weapon, at), through `Runtime:zoneAt` | `ServerScriptService.Weapon` — it asks, the animal answers | **new seam, this design** |
| the animal's own rewound trunk CFrame | **this system** (`Runtime:cframeAt`) | unchanged |
| the animal's per-kind volume table | **this system** (`entry.body.geometry.zones`, written once at spawn by `Body.create`) | unchanged mechanism, two more fields |
| `Boar.toughnessFor(kind)` | **this system** | unchanged |

### 6.2 Writes

| What | Read by | Owner |
|---|---|---|
| a zone string, per impact | `Weapon` → `impact.zone` → `Hits.group` → `report.zone` → `HitLog`, `Match`, the hit card, the Hud, `Runtime:takeHit` | **this system** decides it; `Weapon` carries it |
| the hull parts, their welds, their `HitZone` and the trunk's `Damageable` | the weapon READS the two attributes and nothing else | **this system** (`Boar.Body`) |
| `Runtime:stats().zoneQueries / zoneMisses / zoneWhy / zoneCrossings` | the Builder's report, a probe, a spec | **this system** |
| nothing else, anywhere. No client, no remote, no UI, no camera, no character | | |

`Report.SILHOUETTE`'s rectangles **mirror** this system's boxes and are asserted against them by
`report_silhouette.spec` — a read of frozen data at build time, not a run-time dependency, and the
spec is what keeps the picture honest (10.2).

---

## 7. External sources

Rule 1 and rule 2: this is where the design borrows and where it says so. **I could fetch none of
them this session (no network).** Each licence and maintenance status is stated as I know it, and
15 records that the Builder confirms every URL in the research note before relying on it.

### A. Roblox creator documentation — raycasting, `RaycastParams`, `BasePart.CanQuery`, attributes
<https://create.roblox.com/docs/workspace/raycasting> ·
<https://create.roblox.com/docs/reference/engine/classes/RaycastParams> ·
<https://create.roblox.com/docs/reference/engine/classes/BasePart> ·
<https://create.roblox.com/docs/reference/engine/classes/Instance#GetAttribute> — first-party
(creator-docs is CC BY 4.0; the APIs ship with the engine) · **actively maintained**.
**Good:** it gives exactly the split this design needs — the collision body, the queryable body and
the *data* body are three different things; `FilterDescendantsInstances` is a descendant filter, so
one entry covers a trunk and all its children; attributes are the cross-system contract the harness
can compare.
**Bad:** a ray returns the **first** surface only — the whole reason the surface-box model failed —
and it says nothing about what is behind that surface, which is the half this design has to supply
itself.
**Adopted:** the hull is engine geometry (trunk + the measured head/neck), and everything under the
skin is arithmetic in this repo. The LOS exclude list keeps working through the descendant filter
with fewer parts (ballistics v5 §5.6 property 1).

### B. three.js — `Ray.intersectBox` / `Box3`, the slab method in a maintained codebase
<https://github.com/mrdoob/three.js/blob/dev/src/math/Ray.js> · **MIT** · ~100 k stars,
**actively maintained**, released monthly.
**Good:** the reference implementation of exactly `Zones.rayBox`: per-axis slab clipping with the
divide-by-zero case handled by the IEEE infinities, ~20 lines, no allocation, and a public test
suite. It is the shape to copy and it is MIT, so copying the *shape* is clean.
**Bad:** it is JavaScript and it relies on IEEE `±Infinity` arithmetic falling out of `0/0` and
`x/0`; Luau has the same semantics but **I have not verified Luau's NaN comparison behaviour for
the degenerate parallel case in this engine**, so this design writes the parallel case as an
explicit `|d| < 1e-9` branch instead of relying on it (15, and 12.1 case 1 is the test).
**Adopted:** the slab test, written out in 4.1, with the branch made explicit.

### C. Christer Ericson, *Real-Time Collision Detection* (Morgan Kaufmann, 2004), §5.3.3 — and Kay & Kajiya (1986), who first published the slab method
ISBN 978-1558607323 · **copyrighted book; the algorithm is standard and unpatented; no text or code
taken** · a 2004 book, **not maintained**.
**Good:** the canonical statement of ray/AABB and ray/OBB intersection, with the numerical
pitfalls — parallel rays, rays starting inside, the ordering of `tmin`/`tmax` — named and analysed.
It is why 4.1 states them as the first three test cases rather than discovering them.
**Bad:** it is a book: nothing is linkable, nothing is runnable, and it assumes a float pipeline this
engine does not expose.
**Adopted:** the correctness conditions. The axis-aligned form is enough here because every volume is
axis-aligned **in the trunk's own frame**, and the world rotation is removed once, by
`CFrame:PointToObjectSpace` / `VectorToObjectSpace`, instead of per box.

### D. Stokke, Arnemo, Brainerd, Söderberg, Kraabøl, Ytrehus (2018), *Defining animal welfare standards in hunting: body mass determines thresholds for incapacitation time and flight distance*, *Scientific Reports* 8
<https://doi.org/10.1038/s41598-018-32102-0> · **CC BY 4.0**, open access · published 2018, **not
maintained** (a paper). Already the source behind `Wound.FLIGHT` (`Wound.luau`'s header; `efd` and
`mfd` give 100 and 429 studs at 80 kg, against `FLIGHT.body = 120` and `FLIGHT.legs = 420`).
**Good:** real figures from thousands of hunted animals, and the one finding this design's shape
rests on — **placement, not energy, decides whether an animal drops or runs**, with thoracic hits
incapacitating on the spot far more often than abdominal or limb hits. It is why `chest`/`neck`/`head`
have `FLIGHT = 0` and the paunch does not.
**Bad:** it is about rifle hunting of moose, red deer and reindeer at welfare thresholds; it gives
**no organ geometry at all** and no penetration depths, which is the half this design needed most.
**Adopted:** the existing `FLIGHT` numbers, unchanged, and the ordering they encode.

### E. Deutscher Jagdverband — the *Jagdschein* material on the *Kammerschuss*, the *Blattschuss*, the *Waidwundschuss* and the *Drückjagd*
<https://www.jagdverband.de/> · **copyrighted web guidance; facts and technique taken, no text and no
code** · maintained as current national education material.
**Good:** it is the doctrine for exactly this kind of hunt, in the order a hunting education teaches
it, and it is the one source that states **where the organs are relative to the animal**: the
*Kammer* (heart and lungs) **behind the shoulder and low**, the brain and the neck as instant stops,
the *Blatt* as a stopper that wastes meat, the paunch as the shot that must never be taken because
the animal runs a long way. Karen will recognise or reject it immediately, which is the test that
matters.
**Bad:** qualitative and regional; not one number in studs; and written for tracking with a dog,
which v1 cuts. Also, as `docs/research/2026-10-24-real-shooting.md` §7 already noted against the old
model, *"the doctrine's zone is the Kammer, which is behind the shoulder and NOT the whole chest"* —
this design is where that note is acted on: the boar's `chest` goes from 1.70 studs of the front half
to a 1.80-stud block centred on the shoulder, with the back line given to `spine` and the belly to
`body`.
**Adopted:** the volume list, their relative placement and the order of lethality that `rank` encodes.

### F. Valve — Source/GoldSrc hitboxes and `hitgroup` damage scaling. **Named and deliberately NOT adopted**
<https://developer.valvesoftware.com/wiki/Hitboxes> · public developer wiki, **maintained**.
**Good:** the industry-standard cheap answer, and today's model in this repo: per-bone boxes, each
tagged with a damage group, the hit group taken from whichever box the trace struck first. One
lookup, no depth, no cost.
**Bad for this game:** a hitbox is a **surface**, and the first surface wins — so an organ behind
another organ's box is unreachable, which is precisely the 40–115° window and the head-on `body`
reading that were measured here. Valve's own games accept it because the targets are humanoid,
upright and shot from the front; a quadruped shot from every aspect of a drive is the case it fails.
**Decision:** not adopted, reason recorded so it is not re-researched. What is kept from it is the
*idea* of a per-group damage multiplier, which this repo already has in a better form
(`WOUND.DAMAGE` per zone per ammo, plus `DAMAGE_BY_WEAPON`).

### G. *theHunter: Call of the Wild* (Expansive Worlds / Avalanche) — behaviour precedent, not code
<https://www.thehunter.com/> · **proprietary, all rights reserved; nothing is copied** · actively
maintained commercial game.
**Good:** the best-known player-facing contract for exactly this mechanic — the bullet's **path
through the animal** decides what it hit, several organs can be struck by one shot, and the player is
told which. It is the expectation Karen's players arrive with, and it is evidence that a volume model
is playable at scale on consumer hardware.
**Bad:** proprietary, so nothing may be taken but the observation; its loop is tracking, which v1
cuts; and its organ list is far longer than this game simulates — the research note already records
*"drawing a liver this game never simulates is the mistake Way of the Hunter's own players
describe"* (`src/shared/Report/init.luau`, `ZONES`). This design stops at seven volumes for that
reason.
**Decision:** the path-crosses-organs model is adopted as the *shape*; the organ list is not.

### H. Borrowed from inside this repo (rule 2 applies to internal patterns too)
- **The provider seam** — `Weapon.setHistoryProvider` plus `askWhereWas` plus `Runtime:cframeAt`
  (task 266). The zone provider is the same shape, the same `pcall`, the same "unwired means today's
  game" default, wired by the same two composition roots. Seven precedents in one file.
- **The pure core beside the owner** — `Boar.Wound` and `Boar.Brain`: a module with no state, no
  service and no clock, exported for specs, driven with a hand-written config.
- **Per-kind geometry** — `Body.kindGeometry`'s scale-at-spawn, which makes seven kinds free.
- **Numbers as one frozen config table**, with Karen's feel values marked.
- **A counter for every failure case** — `unknownZoneHits`, `tallylessHits`, `historyMisses`,
  `historyWhy`: a silent degradation becomes a number in the harness report.
**Adopted whole.** The fourth change to this system either keeps its conventions or starts eroding
them.

**The pattern adopted overall:** a two-body model — an engine **hull** of as few queryable parts as
the animal's silhouette needs (A), and an arithmetic **volume** set inside it, tested with the slab
method (B, C) — with the organ list and their placement from hunting doctrine (E), their lethality
and flight distances from the wounding literature (D, unchanged), the path-crosses-organs contract
from the one commercial game that ships it (G), the surface-hitbox model it replaces named and
refused (F), and every seam, default and counter taken from this repo's own existing shapes (H).
**What is invented** is one bound — the four `PENETRATION` numbers — and 3.7 says so where they are
written.

---

## 8. Numeric targets

### 8.1 Direction C — the four acceptance criteria, and the half `hit-zones` is accountable for

Ballistics v5 §11.1 states the other half of each. (BRIEF item 12.)

| # | Criterion | **This document's half, as an assertion** | The instrument that reads it | Spec, or live only? |
|---|---|---|---|---|
| **C1** | honest claims accepted ≥ 95 % on running animals at 20–60 m | **`hit-zones` is accountable for exactly this: an accepted claim must be charged to a zone whose volume the claimed path actually crossed, and to no other.** Assertion: for every accepted claim in a trial, `report.zone` equals `Zones.worst(Zones.crossed(…))` recomputed from `claim.point`, the claim's own direction and the server's own `cframeAt(trunk, t*)` — with **zero** disagreements. The *rate* is ballistics' | `Runtime:stats().zoneQueries/zoneMisses/zoneCrossings` beside `Weapon.stats().claimsAccepted`; the recomputation in `weapon_hits.spec` | **SPEC** for the equality (it is pure arithmetic over hand-written claims); the rate is live and ballistics' |
| **C2** | a forged claim refused | **There is no zone on the wire to forge** (4.7). Assertion: `Shotgun.HitClaim` has exactly six fields and none of them is a zone, a volume, a rank or a damage number — a grep assertion in the spec, so a later field cannot be added quietly; plus: a claim whose offset is on the trunk's flank with a flank-parallel direction crosses no volume and is charged `body`, not `chest` | `weapon_hits.spec` over `judgeClaim` + `Hits.group`; the field count read off the type's own table | **SPEC** |
| **C3** | **the vitals hit from broadside, quartering and frontal aspects** | **This document owns the geometry half outright, and it is B1–B7 (5.6):** a slug reaches `chest` at every θ ∈ [0°, 135°] on both flanks on all seven kinds; frontal with a stated 0.50-stud margin; rear-quartering through the paunch into the chamber; the flank head shot that is impossible today | `Zones.zoneFor` swept at 5° steps × 3 heights × 7 kinds in the pure spec; and a **live** scripted shot through `Weapon`'s own path at a placed animal (12.2 case 6) | **SPEC, both pure and live.** Ballistics v5 §11.3 is right that *no MCP-driven trial can hold an aspect* (276a(a): 1–2 s to the click, 6 of 10 shots tail-on). **A live SERVER spec does not need to:** it places the animal's CFrame and fires through an injected cast in the same frame. What remains live-only is whether **Karen** hits the vitals when she aims at them — a playtest, 16.1 item 1 |
| **C4** | the lead equals the bullet's flight time only | **`hit-zones` is accountable for not asking for any further lead.** Assertion: the zone is resolved in the animal's own frame at the instant the claim or the flight already chose, so a shooter who leads by exactly `v × flight` and strikes the chamber gets `chest` at every speed in {18, 28.7, 38} and at 71/143/214 studs — the zone answer is **invariant under the animal's speed** for the same object-space entry point and direction. Two animals, one still and one at `SPRINT_SPEED`, same object-space shot, same zone | the pure spec (object space, so speed cannot enter) plus `weapon_shot.spec` live at two speeds | **SPEC** |

### 8.2 The rest

| Target | How it is measured |
|---|---|
| **`Zones.zoneFor` ≤ 10 µs**: 10 000 calls under 100 ms over seven volumes | the method `boar_wound.spec` and `boar_brain.spec` already use. Seven slab tests is ~130 multiplications and one small table |
| **Zero allocation per call beyond one crossings table**, and that table is bounded by 7 | read the code; `crossed` writes into a table it created and `ORDER` bounds its length |
| **Zero raycasts added, per shot and per frame** | the zone is arithmetic. `Workspace:Raycast` under `src/server/Weapon/` stays **one** caller (`Cast.luau`), and `Boar` adds none to its own probe |
| **≤ 1 extra `cframeAt` call per impact**, and `Runtime:stats().historyMisses` rises by at most 1 per impact that cannot be placed | `zoneAt` calls `cframeAt` once and returns on `nil` |
| **Parts per animal falls from 5 to 2** (boar) and **from 5 to 3** (deer); `BasePart` children of the runtime's folder stays **1** | `boar_zones.spec`, `boar_model.spec` |
| **The hull silhouette loses at most 0.06 studs a side and 0.15 at the rear**, and nothing at the front or the top | 3.4, and the live flank sweep at ±0.05 studs of the box edge (12.2 case 5) |
| **Every volume is inside the hull** (the trunk ∪ the hull parts), so no volume is unreachable | pure spec over all seven kinds (12.1 case 4) — the replacement for the deleted `PROTRUSION` clearance assertions |
| **No gap a shot can fall into between the belly, the chest and the legs**: the three bands abut or overlap on both species | pure spec (12.1 case 5). Where a gap is deliberate (the brisket wedge) the spec asserts it answers `body` |
| **`rank` agrees with `CLASS` and with the slug damage ordering** on both species | pure spec (12.1 case 3) |
| **Shots to drop is unchanged for `head`, `chest`, `body`, `rear` and `legs`, on all 7 kinds × 4 guns** | `kill_zones.spec`'s existing grid, untouched, plus two new rows |
| **The `BY_PATH = false` world is the attribute world** and nothing errors | pure + live spec (12.1 case 9) |
| Zero errors, zero skipped tests | `tests/TestKit.luau` fails the run otherwise |

---

## 9. How it is tested

`tests/server/` → `ServerStorage.Tests`. Specs write their own numbers rather than importing
`CONFIG` for the assertion where the number IS the claim (the idiom `test_arena.spec` set), and read
`CONFIG` where the claim is "the table and the world agree". Rule 6: these test the animal's path,
not the harness.

### 9.1 `tests/server/boar_zones.spec.luau` — REWRITTEN. The pure half first, and it is the valuable half

Requires `ServerScriptService.Boar` (side-effect-free on require) and drives `Boar.Zones` with
hand-written geometry and with `Body.kindGeometry` for each of the seven kinds. No Instances, no
physics, no waiting.

1. **`rayBox`, the three degenerate cases first:** a ray exactly parallel to a face and outside it
   → `nil`; parallel and inside → crosses; a ray **starting inside** the box → `tEnter < 0 < tExit`
   and it counts; a zero-extent axis; a ray that misses on one axis only. Then the ordinary case
   against hand-computed numbers.
2. **`depthFor`:** the weapon row wins; an ammo word with no weapon row falls through; an unknown
   ammo word gets `PENETRATION_DEFAULT_STUDS`; `nil` ammo and `nil` weapon both answer a number and
   never 0.
3. **`rank` agrees with the doctrine** (3.6): over both species' tables, `rank` is a strict total
   order, it is monotone in `CLASS` (vital > crippling > nonVital) and, within one class, monotone in
   `DAMAGE[zone].Slug`. **This is the assertion that stops a retune from silently renaming organs.**
4. **Containment:** every volume of every one of the seven kinds lies inside the trunk box ∪ the hull
   boxes of that kind. A volume outside is unreachable and is a design error, not a feature.
5. **No accidental gap:** on both species, for a dense grid of broadside and belly rays, every ray
   that enters the hull crosses at least one volume **or** lands in the stated brisket wedge; the
   wedge's own rays answer `nil` (→ `body`, 5.4).
6. **The aspect sweep — B1 to B7 (5.6).** For each of the seven kinds: θ from 0° to 180° at 5°
   steps, both flanks, at three heights (the chamber's centre, ±40 % of its height), aimed at the
   chamber's centre, for `Slug`, `Pellet`, `rifle` and `lever`. Asserts B1, B2, B3, B4, B5, B6, and
   **reports** B7's rear band rather than asserting a number nobody has computed.
7. **The most vital wins, and it is MAX not SUM:** a rear-quartering path returns `{body, chest}` and
   answers `chest`; a high broadside returns `{spine}` and answers `spine`; a path through a foreleg
   into the chamber returns `{legs, chest}` and answers `chest`; and in each case the damage
   `Wound.damageFor` would charge is the single zone's, never the pair's.
8. **Speed invariance (C4):** the same object-space origin and direction answer the same zone
   whatever the trunk's world CFrame is — four rotations and two translations.
9. **`BY_PATH = false`:** `Runtime:zoneAt` answers `nil` for every query and no error is raised.
10. **Performance:** 10 000 `zoneFor` calls under 100 ms.

### 9.2 `tests/server/boar_zones.spec.luau` — the live half, on real animals

One real animal per kind in the spec's own folder on its own plate at y = 500 (the pattern
`boar_body.spec` and today's `boar_zones.spec` already use, with teardown in `afterAll`):

1. the hull is **exactly** the trunk plus one part per `hull = true` row — 2 parts on a boar, 3 on a
   deer — each `Massless`, `CanCollide == false`, `CanQuery == true`, `Anchored == false`, welded by
   a `WeldConstraint` to the trunk; and the runtime's folder still holds **one** `BasePart` child;
2. `Damageable == true` on the trunk alone; `HitZone` on the trunk (`"body"`) and on each hull part
   (its own name); **no** `Damageable` on a hull part;
3. the ancestor walk: `Hits.targetOf(hullPart)` returns the trunk — the part `takeHit` is given —
   with the hull part's own zone;
4. **real rays, in the animal's own frame** (computed from `part.CFrame` so the test does not depend
   on which way the animal happens to face): nose-on, over-the-top and both flanks at skull height
   → the provider answers `head`; both flanks at the chamber → `chest`; low flank and rear-low →
   `legs`; high over the back → `spine`; rump from behind → `rear`; mid-flank behind the last rib →
   `body`. **Twelve directions minimum per species.** Each one is cast for real and then handed to
   `Runtime:zoneAt`, so the test proves the hull *and* the volume together;
5. **the flank edge**, which is the one thing 3.4 gives up: rays at the box's own x half-extent
   ±0.05 studs, at the leg band's height — asserting what hits and what misses, so the 0.06 studs
   lost is a measured fact and not a surprise;
6. `zoneAt` refuses a `DOWN` animal, a part of another runtime, and an `at` outside the ring's span,
   each with its own `zoneWhy`;
7. the animal still drives: after 1 s the assembly is moving, `CFrame.UpVector.Y > 0.9`, and
   `part:GetNetworkOwner() == nil` — the hull did not tip it, anchor it or slow it.

### 9.3 `tests/server/weapon_hits.spec.luau` — the seam, pure

1. with a zone provider injected, `impact.zone` is written and `Hits.group` reports it;
2. **unwired** → the attribute answer, byte-for-byte today's zone for the same impacts;
3. a provider that **throws** → the attribute answer, and `zoneProviderWhy` carries the message;
4. a provider that returns `nil` → the attribute answer;
5. a provider asked once per impact and no more (count the calls);
6. nine buckshot impacts across three volumes → `report.zones` is the three-way tally and
   `report.zone` is the dominant one, with the nearest-impact tie-break unchanged;
7. an accepted claim's impact carries `at == t*` and the zone the claim's own path crosses
   (C1's equality assertion);
8. **C2:** `HitClaim` has six fields and no zone; a flank-parallel claim is `body`.

### 9.4 `tests/server/weapon_shot.spec.luau` — LIVE, and this is C3's instrument

A placed animal (its CFrame written directly, so the aspect is exact), an injected cast that stops
nothing, and a shot resolved through `onFireRequest` — the path a player's trigger takes:

1. θ = 0°, 45°, 90°, 135° at the chamber's height with a slug → `report.zone == "chest"`, four
   times. **The live half of C3, with no human click and no MCP round trip**;
2. θ = 0° at skull height → `"head"`; θ = 90° high over the back → `"spine"`; θ = 180° at the
   chamber → `"chest"` on a boar and `"rear"`/`"body"` on a stag (B4);
3. the same four shots at `SPRINT_SPEED` with the claim path on → the same four zones (C4 live);
4. a boar and a stag of each kind, so the per-kind scaling is exercised on the player's path and not
   only in `kindGeometry`.

### 9.5 `tests/server/kill_zones.spec.luau`, `boar_hit.spec.luau`, `report_silhouette.spec.luau`

- **`kill_zones.spec`:** the existing grid of 7 kinds × 4 guns × zones, **unchanged for the five
  existing zones** (that invariance is the claim), plus `neck` (one shot, any gun, every kind) and
  `spine` (mortal on both species with both rifles, mortal with a slug on a boar, and the deer
  arithmetic read off the **divided** number — the mistake that file exists to prevent).
- **`boar_hit.spec`:** the seam end to end — a `neck` hit kills, a `spine` hit cripples and the
  animal circles (`CRIPPLE_SPEED`, `CRIPPLE_TURN_DEG`), a `legs` hit still does not kill, `Downed`
  still fires exactly once, a carcass still refuses hits.
- **`report_silhouette.spec`:** the two new rects, projected through `Shape.rectOf` from the new
  boxes; the disjointness assertion replaced by the draw-order assertion (10.2).

### 9.6 Client spec: none. Harness input: what it can and cannot do

**No client spec and no client change.** The client sends a claim naming a part and never a zone
(4.7); the hit card and the Hud read `report.zone` as they already do. `tests/client/` is unchanged
except that `hit_card.spec`'s fixtures may name `neck` or `spine` if the Builder wants coverage of
the new strings — optional, and not a gate.

**What harness-driven input still cannot do**, said plainly rather than wrapped in a test that looks
like proof (rule 6, and ballistics v5 §11.3 measured it): it cannot place the player's character, it
cannot aim under `MouseBehavior = LockCenter`, and **it cannot hold an animal's aspect at the
trigger** — 1–2 s pass between the gate reading and the real click, and 6 of 10 shots were tail-on
although all 10 passed a chest gate (276a(a)). **So there is no honest end-to-end "Karen shoots a
running boar in the heart" test today, and this design does not pretend otherwise.** 9.4 is the
instrument that answers the geometry question without a human; the feel question is a playtest.

### 9.7 Screenshots (rule 5) — three, inspected by the Builder

This task changes what the animal **is made of**, and with `BOAR_MODEL` lit (default `true`,
`src/shared/Flags/init.luau`) the drawn mesh covers the hull, so most of it is invisible by design.
What must still be looked at:

1. **The grey-box animal from the side and the front, `BOAR_MODEL` off** — it is now a plain trunk
   with a head (and a neck, on a deer) instead of a trunk with four tinted bands. Confirm it still
   reads as an animal and that nothing floats or protrudes wrongly. **Say plainly that the zone
   tints are gone from the body**; that is 16.1 item 4.
2. **The drive report panel** with hits in `neck` and `spine` — the two new rectangles, their rings
   readable against the fill (`Report.RING_MIN_LUMA`), and every dot inside the animal.
3. **A hit card** on a real shot, showing the new zone label where it lands.

Describe what is actually on screen, not what should be. A number is not a verification.

---

## 10. Deltas to other documents, each with its owner

### 10.1 `docs/design/ballistics.md` v5 — three sentences to amend, and who amends them

v5 was written by run 1 of this task and is right about everything it owns. Three of its sentences
describe the zone mechanism and become stale when this design is built. **The build task amends
them in v5 itself** (it is the Architect's file; the Builder may not rewrite a design — so the
honest route is: the build task records the three in its review request, and the Director calls the
next Architect run, or accepts them as a documentation note in `TASKS.md`). Named here so neither
document can quietly disagree with the other:

| v5 says | After this design |
|---|---|
| §1.2: *"The client never names a zone … the zone is that part's own `HitZone`, read on the server by `Hits.targetOf`"* | the client still never names a zone. The zone is the **animal's** answer for the path; `Hits.targetOf`'s attribute is the fallback (5.4) |
| §5.6 property 1: *"The four zone parts are `zonePart.Parent = trunk` … so one entry covers the trunk and all four zones"* | the **hull** parts are `Parent = trunk`, so one entry still covers everything. The property holds with two parts instead of four |
| §2 owners table: `Weapon.Flight` and `Validator.claimImpact` *"untouched"* | untouched **by v5**. This design adds one stamped field to each (`impact.at`) |

**No number in v5 moves.** `BODY_TOLERANCE_FACTOR`, `BODY_TOLERANCE_MIN_STUDS` and the per-kind table
in v5 §3.2 are read off `trunk.Size` — the **trunk**, which this design does not touch — so all seven
tolerances (2.00–3.71) are unchanged, including the hind's anchoring 6.030.

### 10.2 `ReplicatedStorage.Report` — two rects, and disjointness becomes draw order

`Report.CONFIG.SILHOUETTE` is *"`Boar.CONFIG.ZONES[zone]`'s own box projected through
`HitLog.Shape.dot`'s mapping"*, and `report_silhouette.spec` asserts exactly that (case
*"is Boar.CONFIG.ZONES projected, zone by zone"*) plus *"keeps the four named zones pairwise
disjoint"*. Volumes overlap, so **the second assertion cannot survive and must be replaced rather
than relaxed**:

- `SILHOUETTE` gains `neck` and `spine` and keeps the other five;
- the rects are drawn **in ascending `rank`**, so the most vital is on top and a dot in an overlap is
  labelled by the zone the model would have charged. That is the replacement assertion: *for every
  point in the unit square, the topmost rect containing it is the highest-ranked volume whose
  projection contains it* — the picture tells the truth about the model, which is what the old
  disjointness assertion was for;
- `Report.CONFIG.ZONES` becomes seven, and its comment that `body` *"is not in
  `Boar.CONFIG.ZONES.ORDER`"* is corrected (4.5).

The projections, for the **male boar** trunk (u = (z + 2.75)/5.5, v = 0.5 − y/3, clamped to the unit
square), as the arithmetic the Builder checks `Shape.rectOf` against:

| zone | u0 | u1 | v0 | v1 |
|---|---|---|---|---|
| `head` | 0.000 | 0.309 | 0.000 | 0.383 |
| `neck` | 0.309 | 0.464 | 0.033 | 0.367 |
| `chest` | 0.309 | 0.636 | 0.150 | 0.683 |
| `spine` | 0.336 | 0.945 | 0.000 | 0.150 |
| `rear` | 0.782 | 1.000 | 0.000 | 0.600 |
| `body` | 0.636 | 0.782 | 0.150 | 0.767 |
| `legs` | 0.136 | 0.973 | 0.667 | 1.000 |

`Shape.rectOf` is the authority and the spec recomputes all seven; the table above is the check, not
the source. (`SILHOUETTE` stays deliberately **not** species-aware, which `src/shared/Report`'s own
comment already explains and this design does not change.)

### 10.3 The grep the build task owes — CARRY FORWARD, NOT ABSORB (the BRIEF item 13 analogue)

Named here as a build-order step; **this design-only task does not do it.** Once the three interior
zone parts stop existing and `PROTRUSION` is deleted, every caller and spec of these names must be
visited **once**:

```
ZoneChest / ZoneRear / ZoneLegs   tests/server/boar_zones.spec.luau   (rewritten)
                                  tests/server/boar_hit.spec.luau
                                  tests/server/boar_behaviour_live.spec.luau  (reads chest.Size * scale)
                                  tests/server/weapon_shot.spec.luau
                                  src/server/Weapon/Validator.luau   (COMMENT only: the 7.275 waiver story)
                                  src/server/Weapon/init.luau        (COMMENT only: claimLastPart's story)
                                  reviews/task-266*/probes/*.luau    (probes, not code; leave, they are history)
CONFIG.ZONES.PROTRUSION           tests/server/boar_zones.spec.luau  (CLEARANCE_FLOOR and two assertions)
CONFIG.ZONES.ORDER                tests/server/boar_shot.spec.luau, boar_model.spec.luau (x3),
                                  boar_kinds.spec.luau (x3), boar_legendary.spec.luau,
                                  tests/server/report_silhouette.spec.luau
Report.CONFIG.ZONES               src/client/Hud/BoarArt.luau, tests/client/report_panel.spec.luau,
                                  tests/server/report_silhouette.spec.luau
geometry.zones                    src/server/Boar/Body.luau (kindGeometry, buildHull)
```

Every one of the `ORDER` readers is written as a loop over the list, so seven names instead of four
is arithmetic rather than a rewrite — but **that is a claim to verify, not to assume**: three of them
(`boar_model.spec`'s `expect(zones).to.equal(#CONFIG.ZONES.ORDER)`) count built **parts** against
`#ORDER`, and after 3.4 the built count is the number of `hull` rows, not the number of volumes.
Those three assertions change.

### 10.4 `GAME_DESIGN.md` — the owners table row, ready to paste

Rule 3. **No new row**: this is the boar's. In the **Boar AI** row, the sentence beginning *"Since
Milestone 1.5 it also owns hit zones and wound state: `Boar.Body` builds the three welded, massless,
non-colliding zone parts (`ZoneHead`, `ZoneChest`, `ZoneLegs`)…"* is **stale already** (there are
four since task 116) and is replaced by:

> Since Milestone 1.5 it also owns **hit zones and wound state**, and since Task 277 a hit zone is a
> **volume inside the body and not a box on it**: `Boar.CONFIG.ZONES` holds the seven volumes per
> species (`head`, `neck`, `chest`, `spine`, `rear`, `body`, `legs`) with their `rank` and the
> per-cartridge `PENETRATION`, measured off the loaded rigs; `Boar.Zones` is the pure slab-test
> module that says which volumes a shot's path crossed and which of them is worst; `Runtime:zoneAt`
> is the **one** answer to "which zone did this shot hit", rewinding through the one history reader
> `Runtime:cframeAt`; `Boar.Body` builds the **hull** — the trunk plus one queryable part per `hull`
> row (`HullHead`, and `HullNeck` on a deer) — and is the only writer of it, of the `HitZone`
> attribute it carries as the fallback, of the hit flash, the collapse and the `Carcass` attribute;
> `Boar.Wound` is the pure damage model and holds no state. `ServerScriptService.Weapon` **asks**
> through `Weapon.setZoneProvider`, exactly as it asks `setHistoryProvider`, and gains no zone table,
> no anatomy and no damage number. No damage number, health value or zone-to-reaction rule exists
> anywhere else in the repo ([hit-zones design](docs/design/hit-zones.md)).

**`Game state` stays `_unassigned_`.** Nothing here claims it.

---

## 11. The harness, the gate, and the build order

### 11.1 Scope and `test2`

- `tools/studio_mcp.py`'s `BLAST_RADIUS` already maps `src/server/Boar` → `boar`,
  `src/server/Weapon` → `weapon`, `src/shared/Shotgun` → `gun`. `src/shared/Report/init.luau` is
  **not** in the map and therefore resolves to `all` — which is correct and is the behaviour the
  table's own rule intends (*"an unmapped code path can only ever mean the whole suite"*).
- **No new spec FILE**, so `SCOPE_SPECS` needs no row and `selftest` cannot fail on this task.
- **`test2`**: `src/server/MatchBoot.server.luau` **is** in `TWO_PLAYER_PATHS`. The wiring line
  belongs there, so the PR that contains it needs the `[harness2]` line. **Put it in its own final
  commit** so the three commits before it need only the one-player run, and say so in the request.
  The cheaper alternative, if the Director prefers to avoid the human click: wire only
  `ForestTestBoot` in this task and carry `MatchBoot` into the drive's next task — at the cost of
  the production drive running on the attribute fallback until then. **16.2 D.**

### 11.2 Build order — four commits, each green on its own

1. **Data and arithmetic.** `Boar.Zones` (new, pure) · `CONFIG.ZONES` rewritten with the seven
   volumes, `rank`, `hull`, `PENETRATION`, `BY_PATH`; `PROTRUSION` deleted · `WOUND`'s two new rows
   in `DAMAGE`, `DAMAGE_BY_WEAPON`, `FLIGHT`, `CLASS` · `kindGeometry` carries `rank` and `hull` ·
   `Report.SILHOUETTE`'s two rects and the draw order · `boar_zones.spec`'s pure half,
   `kill_zones.spec`'s new rows, `report_silhouette.spec`'s rewrite, and the `ORDER`-reader specs.
   **The zone parts are still built and still queryable, so the game is unchanged and the suite is
   green.**
2. **The answer.** `Runtime:zoneAt` · `Shotgun.ZoneQuery`, `Impact.zone`, `Impact.at` ·
   `Weapon.setZoneProvider` + `askZone` + the two annotation sites · `Hits.group`'s one preference ·
   `Flight`'s and `claimImpact`'s stamps · `weapon_hits.spec`. **Unwired, so still unchanged.**
3. **The hull.** `buildZones` → `buildHull`: build only the `hull` rows, rename to
   `HullHead`/`HullNeck`, archive the three removed part names with a note (rule 7) ·
   `boar_zones.spec`'s live half · the part-count specs. **Wired in `ForestTestBoot` in this commit,
   so the volumes decide before the parts that used to decide are gone** — the order matters: 3
   before 2 would leave a window where only `head` and `body` were reachable.
4. **Production.** `MatchBoot`'s one wiring line · `weapon_shot.spec`'s live aspect cases ·
   `boar_hit.spec`. **This is the commit that needs `test2`.**

Each commit is a harness run on a clean tree and the request names the last one as `Code commit:`.

### 11.3 Process hazards

- **Rojo.** A new file (`Zones.luau`) in a watched folder and a branch switch to get it. `rojo serve`
  7.7.0 panics when watched files vanish and a large branch switch alone crashed it once. Stop
  `rojo serve` before switching; expect a **NEEDS KAREN** Connect click.
- **`HIT_CLAIM` expires 2026-11-15** and today is 2026-10-26. Nothing in this design moves it, but a
  build that lands after that date fails `flags.spec` and therefore the harness. One line, with a
  reason.
- **`python tools/flags.py clear` and `tools/pose.py clear`** before any harness run.

---

## 12. What I could not verify (rule 8)

- **Anything requiring Roblox Studio.** No Studio in this session (`.agent-evidence/INDEX.md`).
  Specifically unverified: that `CFrame:PointToObjectSpace` / `VectorToObjectSpace` behave as this
  design assumes for a welded child's frame (the repo relies on exactly that in
  `Runtime:cframeAt`'s `trunk.CFrame:Inverse() * instance.CFrame`, which is evidence but not a test I
  ran); that removing three welded `Massless` children leaves the assembly's mass, `MAX_FORCE` and
  `ACCEL` untouched (it should only make them *more* correct); that the hull head's 0.06 front
  proudness still wins a grazing-angle cast, which is unchanged from today but was never measured;
  and that `Luau`'s NaN/infinity behaviour in a divide-by-zero slab test matches three.js's — which
  is why 4.1 writes the parallel case as an explicit branch and 12.1 case 1 tests it.
- **The slab test is arithmetic I can state but not run.** Every number in 5.6's depth table is hand
  arithmetic off 3.2 and 3.3, not a computed sweep. **B7's rear band is deliberately left as
  "measured and reported by the spec"** for exactly that reason, and if the sweep contradicts any of
  B1–B6 the dial is one `PENETRATION` row and the finding is a finding, not a redesign.
- **The volume boxes are DERIVED from the repo's measurements, not re-measured.** The boar's bone
  positions (nose, eye, ear, `Neck`, the foreleg attachments) and the stag's (skull, `neck_01`,
  brisket, back, `Spine_base`, `hip_b`, tail) are read out of the comments above
  `Boar.CONFIG.ZONES` and `SPECIES.reddeer.ZONES`, where earlier tasks recorded them from a Play
  session and from headless Blender. **Where an organ sits *inside* that skeleton is doctrine (source
  E), not measurement** — there is no dissection in this repo and there will not be one. The chamber
  being "low and forward behind the shoulder" is as precise as the source gets, and the box is my
  reading of it against the measured bones.
- **The four `PENETRATION` numbers are not measured and have never been played** (3.7). They are
  reasoned from the cartridges (source F) at `METRES_PER_STUD = 0.28` and chosen so the boundary
  cases in 5.6 land where the doctrine says they should. They are Karen's dials.
- **The two new pellet damage numbers (`neck` 30, `spine` 11) have never been played.**
- **The external sources' URLs, licences and maintenance status.** No network. A (Roblox docs) and
  B (three.js, MIT) are near-certain; D's DOI is quoted from the repo's own research note, not
  fetched; C is cited from memory as to edition and section; E is a category of source rather than
  one fixed page; F is a public wiki I could not open; G is my own knowledge of the game. **The
  Builder confirms each in the research note before relying on it** (rule 1 — the note is the
  Builder's, not mine), and if C or E cannot be confirmed the geometry does not change: the boxes are
  built on the repo's own measurements and the doctrine is independently recorded in
  `docs/research/2026-10-24-real-shooting.md` §7 and `kill_zones.spec`'s own header.
- **The hull against the DRAWN silhouette.** `Boar.CONFIG.KINDS` records `drawnWidthStuds` = 3.47 for
  the stag against a 1.8-stud trunk and 2.01 for the hind, with the deliberate note that *"the
  collision box is NOT widened to match"*. So a shot at the outer ~0.8 studs of a drawn stag's flank
  misses the animal entirely, before and after this design. **I did not measure it and this design
  does not change it**; it is 16.2 C, and it may well matter more to Karen's hit rate than anything
  in this document.
- **`Flight`'s impact timing.** I assert that `onShotLanded` runs in the same frame as the cast that
  produced the impact (so `impact.at` is exact) from reading `Weapon.start`'s single Heartbeat and
  `flight:advance`; I did not observe it. If it is ever not true, the stamp is the thing that makes
  it not matter.
- **CI and harness status at this commit.** Lint and build are clean in the evidence
  (`.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`). No harness or CI output
  is in `.agent-evidence/`, so no claim about the suite's state is made here.

---

## 13. Open decisions — none of them blocks building

Every one has a default written into this document or into `CONFIG`, so the Builder can build, test
and report without an answer. They are the things to overrule on purpose rather than by accident.

### 13.1 Karen — feel. The "check this" list for the first playtest after it lands

1. **Can you now hit the heart when you aim at it, from the front and from behind?** That is the
   whole task. The dials, in order of bluntness: `chest`'s box (3.2), `PENETRATION.Slug`, and then
   the aspect sweep's own numbers.
2. **Is a snout or jaw hit supposed to kill?** Default **yes**: `head` is the whole measured skull
   and is `vital`, so a shot that clips the nose is lethal. In life it is a terrible wound and not a
   kill. Splitting the skull into `head` (brain) and a jaw volume is one more row and one more
   `DAMAGE` line — **your call, because it only ever makes the game harder.**
3. **Is the buckshot penetration right?** A pellet reaches the chamber from the flank and not from
   the front (B5). That is real, and it means frontal buckshot wounds instead of killing.
   `PENETRATION.Pellet` is the one number.
4. **The grey-box animal has no coloured zones any more.** With `BOAR_MODEL` on (the default) you
   never saw them anyway; with it off the boar is a plain trunk with a head. If you want the teaching
   aid back, it is a debug draw and it needs an owner — 13.2 A.
5. **Does a spine shot read as a spine shot?** It is `crippling`, so the animal goes down on its back
   end and circles at `CRIPPLE_SPEED` — your task-116 sentence, now reachable along the whole back
   instead of only at the rump. If a spine shot should simply kill, that is `CLASS.spine = "vital"`,
   one word.
6. **A neck shot is one shot, any gun** (`DAMAGE.neck.Slug = 100`). Too easy?
7. **Should a legendary's armour also stop the bullet going as deep?** Default **no** — `toughness`
   divides damage and nothing else, so one armour is applied once (3.7).

### 13.2 Director — scope. None blocks building

A. **A wound-channel picture or an organ read-out** (*"lung + liver"*, as theHunter does). Default:
   **not now.** Anything drawn is the Hud's and it needs the server to replicate the crossings list,
   which is a new payload field. `Runtime:stats().zoneCrossings` is the cheap version and it is in
   this task.
B. **Flag or config row?** Default: `CONFIG.ZONES.BY_PATH = true`, because `Flags.MAX_FLAGS = 18` is
   full and `HIT_CLAIM` is the eighteenth (3.8). The alternative is to retire one LIT, accepted flag
   row (`BOAR_MODEL`, `BOAR_BEHAVIOUR`, `HORN`, … each of which has shipped for weeks) and spend the
   slot on this. **Retiring a row is your decision and rule 7 work (archive with a note).**
C. **The hull against the drawn animal.** `drawnWidthStuds` says a stag is drawn 3.47 studs wide over
   a 1.8-stud box. Every shot at the outer flank of a drawn deer misses, today and after this task.
   Default: **not this task** (it is the collision shape, it changes how animals pack and route, and
   it needs its own measurement). It is a strong candidate for the next task, and it may be a bigger
   share of Karen's misses than anything here.
D. **Where the production wiring lands** (11.1): one line in `MatchBoot` and the PR needs `test2`,
   or `ForestTestBoot` only and the drive keeps the attribute fallback for one more task.
   Default: **wire both, pay the one `test2` click**, in its own final commit.
E. **Retuning the model.** This task adds volumes and two keys and changes **no** existing damage,
   flight or threshold number. The first playtest will want some of them moved. That is a content-ish
   task over `WOUND` and it should be one task, swept by `kill_zones.spec` over all 7 kinds and 4
   guns, as L-093 requires.
F. **Players and beaters are still not damageable**, unchanged. A pellet that hits a person is a
   miss; the drive-line rule, not damage, is the answer to shooting at people.

### 13.3 Carried from the 265–276 run — every item placed (BRIEF item 14)

| item | where it is |
|---|---|
| 269a(b) the instrument's `no-ammo` | **ballistics v5 §16.3.** Not this design's |
| 270a(a) the coarse gate at `SPRINT_SPEED` 38 | **ballistics v5 §16.** It is `Claim.simulate`'s first guess |
| 271 round-1 findings 5–7 | **ballistics v5 §16.3** |
| 272a(b) the window-0 case that accepts | **ballistics v5 §11.2** (the non-regression row) |
| 274a(b) the `claim-blocked` waiver at 7.275 against 3.40 | **ballistics v5 §0 item 4 and §5.6**: resolved by deleting the waiver. This design makes it smaller again — the part that stopped the server's own bullet was `ZoneChest`, which no longer exists |
| 276a(c) the mark drawn a body length behind the zone it names | **NOT absorbed here, by the BRIEF's own instruction.** Its owner is `PlayerScripts.Weapon.Effects` → `puff` (`src/client/Weapon/Effects.luau`); the cause is measured in `docs/research/2026-10-24-real-shooting.md` §8.1 (11.4 studs in one grain lifetime at `SPRINT_SPEED`) and the item is ballistics v5 §16.6's. **It is a client drawing defect, not a validation or a geometry one**, and after this task it will be the most visible thing left: the zone will be right and the dust will still be behind the animal |
| **276a(d) is a head-on chest shot supposed to read `body`?** | **ANSWERED HERE: no.** 5.5 |

---

## 14. The one-paragraph summary, for the Builder who reads nothing else

Stop building zone parts and start building two: the trunk, and one queryable part per volume row
marked `hull` (the measured skull, plus the deer's neck). Put the seven organs in `Boar.CONFIG.ZONES`
as boxes in the trunk's frame with a `rank`, scaled per kind by the `kindGeometry` that already
exists. Write `Boar.Zones`: a slab test, the list of volumes a path crossed, and the highest-ranked
one, bounded by a per-cartridge `PENETRATION`. Give the animal one method, `Runtime:zoneAt`, that
rewinds through the one reader `Runtime:cframeAt` and calls it. Give the weapon one more provider,
`setZoneProvider`, asked through `pcall` like the seven before it, with the answer riding on
`impact.zone` and `Hits.targetOf`'s attribute as the fallback. Change no damage arithmetic; add two
rows (`neck`, `spine`) to each of the four `WOUND` tables. Then a frontal shot reaches the heart, a
quartering shot passes the paunch into it, a flank shot can take the head, and a head-on chest shot
stops being charged to the belly.

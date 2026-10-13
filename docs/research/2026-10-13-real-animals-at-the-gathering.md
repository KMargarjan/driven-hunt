# The real animals at the gathering, not boxes (Task 173)

Builder's research note, 2026-10-13. Written before the code (CLAUDE.md rule 1).
Dispatched by the Director, 2026-10-13.

**KAREN, 2026-10-13 ~09:30, verbatim:**

> "and after hunt over we need to see boars shooted not boxes when we stand around"

The gathering itself is task 159 (the scene, the ring, the lamps) and task 168 (the rows, the
torches). Both shipped with the animals as GREY BOXES on purpose, and 159a(a) wrote down what the
next step was: *"the animals in the row are grey boxes. The seam for real models is one injected
template function ... read by `Match.Scene.build`; nothing else changes. Karen judges the look
first."* This is that step, and nothing else about the scene moves.

---

## 1. What the system must do

1. **One display animal per shot animal**, in the rows task 168 already lays out, of that animal's
   own KIND -- the male, the sow or the cub -- drawn from the SAME asset the live boar of that kind
   is drawn from, so a cub in the row is a cub and not a small male.
2. **Lying down dead, on its side**, like a day's bag and not like a herd standing in a field. The
   measurable form of that is the one task 150 already uses: the animal's spine 86-104 degrees off
   world up (a live standing boar measures 4-5).
3. **Facing the same way, all of them**, which is what makes a row read as a row.
4. **On the ground**, not sunk into it and not hovering -- the fault task 120 fixed on the live cub
   carcass (drawn 1.009 studs under the floor) and task 150 fixed on the standing one.
5. **The box stays the fallback.** No asset, no model, flag off, a template that is not one mesh:
   the grey box of today, in the same place, at the same size.
6. **Nothing else about the scene changes**: the torches, the ring, the rows, the spacing, the cap
   of twelve and the results table are task 168's and are untouched.
7. **Gone before the next drive**, with the folder, exactly as the boxes are.

### Numeric targets

| What | Target | Why that number |
|---|---|---|
| Display roll | **-90 degrees** about the animal's own forward axis | lays it on its **right** body side, which is what the tradition prescribes (section 3.1). The live carcass rolls **+45** and lets gravity finish it to the left (`WOUND.COLLAPSE_ROLL_DEG`), so this is the display's own number and is not that one |
| Lying check | spine 86-104 degrees off world up | task 150's own measured band for a carcass on its flank (`boar_model.spec`: seven of eight kills measured 86-102) |
| Height off the ground | half the mesh's X extent: male **0.70**, sow **0.60**, cub **0.31** studs | rolled a quarter turn, the mesh's WIDTH is its vertical extent. Its `CFrame` is its bounding-box centre, so half that extent is exactly "resting on the ground" for any kind and any future asset |
| Footprint in the row | male 3.26 across x 5.5 long (`Assets.ROWS`' own measured sizes) | against `SPACING_STUDS` 6 and `ROW_SPACING_STUDS` 8 that is a 2.7-stud gap sideways and 2.5 nose to tail: the row still reads as separate animals, so **no spacing number has to change** |
| Instances per scene | <= 12 models + 4 torch posts, one build and one clear per drive | unchanged from task 168: one display per animal, the cap of 12 still applies |
| Clips played on a display | **0** | section 4.2: the pose is one CFrame write at build time, not an animation. No Animator, no network, no per-frame writer |

## 2. What it must not do

| Must not | Why, with the evidence in this repo |
|---|---|
| Move, re-parent or keep a real carcass | `Boar.Body` owns a boar's Instances. The drive's own `clearBoars` effect is emitted **before** `scene` in `Phase.enterScoring`, so by the time the scene is built every carcass has been despawned; and in the Forest Test `ForestTest.readOnlyBoars` hands `Match` a view with no `spawn` and no `clear` at all. Taking one would be the drive writing a world it does not own -- "two systems wrote the creature's position", docs/PROJECT_CONTEXT.md |
| Let `Match.Scene` learn what a boar is | it has `ANIMAL_SIZE` and `ANIMAL_SCALES` as DATA for exactly this reason (its own comment). The model arrives through an injected function, the shape `Boar.setModelSource`, `Bots.setRigSource` and `world.placement` already have |
| Build a second asset lookup | `BoarAssetsBoot`'s `MODEL_KEYS` is the one mapping from a kind to an asset key, and `Assets.KEYS` the one home of the strings. The display asks the **boar runtime** for its own template, so there is exactly one route from "cub" to an asset id in the whole server |
| Play an animation on a display | section 4.2. Two things rotating one rig is the fault task 150 found from both sides ("a dead boar on its feet, made of two correct rotations") |
| Make a display shootable | `CanQuery = false` on every part, the rule the scene's boxes, the outfit's plates and the forest's markers already follow: what a shot hit is what the safety rule and the hit record read |
| Add a remote, a phase or a flag | this is one function behind an existing seam inside an existing phase. `SCENE.ENABLED` and `BOAR_MODEL` already gate it from both ends |
| Resize a kind's model | a skinned mesh cannot be resized after import (CLAUDE.md, `boar_prep.py`), which is why there are three baked assets. The display gets the kind's own asset and scales nothing |

## 3. External sources

### 3.1 The German hunting tradition: *Streckelegen* (ADOPTED, and it is the picture Karen described)

<https://www.jagdjuenger.de/blogbeitraege/strecke-legen/> -- Jagdjünger, editorial German hunting
site; no licence stated (quoted, not copied), current (the page is maintained and dated).
Corroborated by <https://wildeswissen.de/2016/04/04/legen-einer-strecke/> (2016, still online) and
<https://jagd.heintges-elearning.de/jagdliche-praxis/allgemeines-jagdliches-brauchtum/streckelegen/streckelegen-allgemeines/>
(Heintges, the German hunting-exam publisher's own e-learning course; current).

The bag of a driven hunt is laid out at the end of it and the hunt stands round it. Two sentences
from the Jagdjünger page, verbatim:

> "Jedes Stück Wild ist stets auf die rechte Körperseite zu legen."

> "Das Wild wird stets in Reihen gelegt. In jeder Reihe findet man ausschließlich eine Wildart vor."

**Good:** this is the real thing Karen is asking for, and it answers the one question the dispatch
left open -- **which side**. Every animal on its **right** side, and every animal the same way, which
is also exactly what makes a row read as a row rather than as a pile. It also confirms the ROWS task
168 already built.
**Bad for us, and not adopted:** one species per row (`"ausschließlich eine Wildart"`) and the head
dressed up for trophy animals (`"Bei Trophäenträgern wird das Haupt aufgestellt"`). Our rows are in
the order the animals were SHOT -- task 168's own property, which Karen has seen -- and one row per
kind would re-order the bag she looked at. **Queued as a note for her, not taken here.** The head
direction the tradition fixes (toward the hunt master) has no meaning in a ring: there is no hunt
master in this game, and the row faces the way the drive came.
**Borrowed:** the right-side-down roll, and the "all the same way" rule stated as one shared facing.

### 3.2 ioquake3 -- the intermission is not the match (ADOPTED, again)

<https://github.com/ioquake/ioq3> -- `code/game/g_main.c`, `code/game/g_cmds.c`. **GPL-2.0**;
maintained (the community fork of Quake III Arena, commits through the 2020s).

The scene already borrows `BeginIntermission` / `MoveClientToIntermission` (task 159's note, section
3.1). What matters HERE is the other half of that pattern: the intermission draws its own objects at
its own point and the round's entities are gone. The scoreboard view never reaches back into the
finished round for a body.

**Good:** it is the same answer the repo arrived at independently -- a DISPLAY copy, built by the
scene, owned by the scene, destroyed with the scene -- so the carcass's owner is never asked for a
favour at a moment when it has already cleaned up.
**Bad:** it has nothing skinned and nothing to pose; the pose is ours.
**Borrowed:** the display is the scene's own object, and the only thing it takes from the game world
is DATA (which kind was shot), never an Instance.

### 3.3 theHunter: Call of the Wild -- the harvest screen shows the ANIMAL

<https://store.steampowered.com/app/518790/theHunter_Call_of_the_Wild/> (proprietary; current, still
patched). Already cited by this repo in `docs/research/2026-10-05-drive-report.md`.

The genre's end-of-hunt moment is a 3-D render of the animal that was actually shot, with its own
species and sex, not an icon and not a silhouette.

**Good:** it is the evidence that "show the real animal" is the genre's own answer and not a
preference, and that the SEX/KIND being visibly right is part of it.
**Bad:** it is a modal screen with a lit studio and a turntable camera -- a driven hunt cannot stop
for that (the drive-report note's own conclusion), and Karen's version is the opposite: the animals
in the world, the people standing round them.
**Borrowed:** the kind is drawn from the real asset, and nothing about the display is a stand-in for
a species.

### 3.4 Roblox -- what a `Model` and a `Bone` actually guarantee

<https://create.roblox.com/docs/reference/engine/classes/Model> and
<https://create.roblox.com/docs/reference/engine/classes/Bone>. Engine documentation, current.
Both were FETCHED for this note, and the second one is a negative result worth writing down.

* `Model`: with no `PrimaryPart`, the pivot is *"the center of the bounding box containing"* the
  model's parts, and `PivotTo` moves the whole model by it. **So a display model sets its
  `PrimaryPart`** -- the mesh -- and is positioned by one explicit `CFrame` write on that part, which
  is the shape `Body.attachVisual` already uses and has no implicit bounding-box behaviour in it.
* `Bone`: `Transform` carries *"Capabilities: Basic, Animation"* and `TransformedWorldCFrame` is
  *"Read Only"* and *"Not Replicated"*. The page does **not** state whether a clone carries a posed
  rig, so **the decision in section 4.1 does not rest on it**: it rests on `clearBoars` being
  emitted before `scene`, which is a fact about this repo's own code.

### 3.5 Borrowed from inside this repo (rule 2)

* **the injected source** -- `Boar.setModelSource` (task 115), `Bots.setRigSource` (task 161),
  `world.placement` (task 157). A narrow function, handed in, nil means "not today".
* **the dressing** -- `Body.attachVisual`: unwrap the template, every `BasePart` made massless,
  `CanCollide`/`CanQuery`/`CanTouch` false, the asset's own `AnimationController` removed. The
  display needs the same list and one fewer step (no weld: there is no box to weld to).
* **the lying band** -- `boar_model.spec`'s "lets exactly ONE thing lay a carcass down": 86-102
  degrees measured over eight kills.
* **the fallback** -- `Runtime:_modelTemplate` answering nil and the boar staying a grey box. The
  scene's box is the same answer in the same shape.

## 4. The pattern adopted, and why

**One injected function, asked once per shot animal, answering a finished display model; and the
grey box when it answers nil.**

```
Match.applyScene -> Scene.build(spot, facing, kills, config, displayFor)
                      displayFor(kind, groundCFrame) -> Model?    -- Match passes it in
                        = world.boars:displayCarcass(kind, cframe)
                            -> Body.displayCarcass(template, cframe, config)
```

* `Match.Scene` keeps owning `Workspace.DriveScene` and the LAYOUT (where, and which way). It never
  learns what a boar is, and it writes no CFrame on a display.
* `Boar.Body` keeps owning what a boar looks like and how a dead one lies. The display is built by
  the same module that dresses a live one, out of the same template.
* `Boar`'s runtime keeps owning the kind-to-template lookup, so there is one route from `"cub"` to an
  asset id (`Runtime:_modelTemplate` -> `BoarAssetsBoot`'s `MODEL_KEYS` -> `Assets.KEYS`).
* Nothing requires anything new: `Match` already holds `world.boars`, and the Forest Test's
  read-only view gets one passthrough.

### 4.1 Why a display copy and not the drive's own carcasses

The dispatch asked for the real carcasses first, if they are still there. **They are not**, and two
independent facts in this repo say so:

1. `Phase.enterScoring` emits `{ kind = "clearBoars" }` and **then** `{ kind = "scene" }`, in that
   order, in one effect list. `applyClearBoars` is `Runtime:clear("driveOver")`, which despawns every
   carcass. The bodies are gone on the frame the scene is built. (Re-ordering the two was considered
   and rejected: the order is `Phase`'s, the scene would then have to hold a reference to another
   owner's live Instances for 25 seconds, and `Scene.clear` would be destroying them.)
2. In the Forest Test the drive cannot touch them anyway. `ForestTest.readOnlyBoars` exposes
   `boars`, `count` and `capacity` and nothing that writes -- deliberately, as task 159's note
   records.

So the display is built from the drive's own kill record (`Match.driveKills`, which already carries
the kind) plus the kind's template. That is also the answer that works for the cap: a drive that
shoots 20 animals lays out 12, and no carcass has to survive for it.

### 4.2 Why the pose is a roll and not the death clip's last frame

The dispatch allowed either. The roll is chosen, and the reason is task 150's own rule: **exactly one
thing may lay an animal down.**

* A display is built once, anchored, and never stepped. Posing it by CLIP would mean a second
  animation writer (`AnimationController` + `Animator` + `LoadAnimation` + `Play` + a wait for
  `AnimationTrack.Length` to stop being 0 + `AdjustSpeed(0)`), per animal, inside the one module that
  today creates four lamps and some boxes.
* `AnimationTrack.Length` *"is 0 until the asset has loaded from the network, and no spec in this
  repository can load one"* -- `Body.shouldFreeze`'s own comment. So a clip-posed display is a thing
  **no spec could check**: the lying-pose check the dispatch asks for would be untestable, which is
  the one property this task must have.
* The clip also brings task 120's bug with it: all three kinds play the male's clips, so a cub posed
  by the male's death clip ends up 1.009 studs under the floor and needs `deathLiftStuds` to be
  applied by hand. A roll needs no per-kind correction at all -- the height is read off the mesh.
* And the roll is what the live game already does in exactly this case: `Body.boxFalls` returns true
  when there is no death track, and then the BOX rolls and the welded mesh goes with it. A display
  with no live rig is that same case, decided once at build time instead of by gravity.

**The cost, stated honestly:** a rolled bind-pose animal has its legs straight rather than folded,
where a clip-posed carcass settles. It reads as a dead animal lying on its flank -- which is what
seven of task 150's eight measured kills also are -- and Karen judges it from the screenshot. If she
wants the softer pose, the next step is an authored "carcass" clip or a baked lying pose in the
asset, not a second rotation on top of this one.

### 4.3 What the fallback covers

`displayFor` answers nil, and the grey box of today is built instead, in the same place and at the
same size, for every one of:

* `BOAR_MODEL` off, or the asset not published / not loaded yet (`Loader.template` -> nil);
* a template that is not one mesh (`Body.displayCarcass` refuses it, the same refusal
  `Body.attachVisual` already makes);
* no boar runtime in the world at all (the DEV quick test, and every pure spec);
* `world.boars` without the method (an older or narrower view).

Per animal, not per scene: a drive that shot a male and a cub, with only the male published, lays out
one model and one box. That is the honest state and it is visible.

## 5. What is tested, and how

| Claim | How |
|---|---|
| one display per shot animal, with its kind | `match_scene.spec`: three kills of three kinds through an injected `displayFor` that records what it was asked; one child per kill, the `Kind` attribute on each |
| it is LYING, measured | `boar_model.spec`: `Body.displayCarcass` on this spec's own fake template (a `MeshPart` with a `Bone`, already built there), then the angle between the rig's own up vector and world up -- 86-104 degrees, the band task 150 measured |
| it is ON the ground | `boar_model.spec`: the mesh's lowest point against the target CFrame's own y, to 1e-3, for all three kinds' sizes |
| the row faces one way | `match_scene.spec`: every CFrame handed to `displayFor` has the same `LookVector`, and it is the scene's own facing |
| the box is still the fallback | `match_scene.spec`: `displayFor` nil, and nil per kind -- a mixed row of one model and one box |
| it cannot be shot | `boar_model.spec`: `CanQuery`, `CanCollide`, `CanTouch` false and `Anchored` true on every part of the display |
| cleanup | `match_scene.spec`: `Scene.clear` after a build with displays, and a rebuild that replaces them |
| the look | ONE screenshot of the gathering in the Forest Test (rule 5), which is what Karen judges |

## 6. Open for Karen

1. **The look of the lying animals** -- the screenshot. Legs straight (section 4.2) and on the right
   side (section 3.1).
2. **One species per row?** The tradition says yes; today's rows are in the order they were shot.
3. **Twelve is still the cap.** A bigger bag lays out the first twelve.

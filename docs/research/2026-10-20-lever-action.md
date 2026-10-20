# The lever-action rifle: the throw, the gate, and a .45-70

Task 224. Written before the code (rule 1). Design: `docs/design/lever-rifle.md`. Brief:
`reviews/task-224/BRIEF.md`.

**Karen, 2026-10-20 ~13:25, verbatim:** *"so you have things to do / deer / weapons / make it work
like we have now"*, and for the asset: *"Upload, sell in shop (Recommended)"*. Her standing bar:
shooting, weapon and reload **perfect**; a separate-part model; every frame checked against the
target.

---

## 1. What the system must do

A third weapon, joined to the shipped weapon system as a row and nothing more:

1. Fire one .45-70 bullet per trigger pull, through the shipped flight (`Ballistics.shotFor` +
   `Weapon.Flight`), with the same hit zones, damage table, hit card and drive report.
2. **Work its lever after every shot**, drawn as one hinged group swinging down and forward with the
   right hand carried on the loop.
3. **Top its tube up through the loading gate**, one cartridge at a time, leaving live rounds where
   they are.
4. Aim down its **own iron sights** — no scope, no reticle, no sight-picture overlay.
5. Be **bought in the shop**, so ownership is what decides whether a hunter may carry it.
6. Be drawn from uploaded MeshParts, with measured fallback boxes until they load.

Numeric targets are in the design, section 14. The three this note exists to justify are the
**cartridge's ballistics**, the **cycle time**, and the **two-step reading of one throw**.

---

## 2. Borrow before building: what already existed here

Rule 2 makes the repo the first place to look, and in this case almost everything was already built
and reviewed. **The only new mechanisms in this task are one pure refusal rule, one `CYCLE_KIND`
branch, one pure predicate and one sound key** — everything else is a row of data in a table that
already exists.

| What the lever needs | What already ships | Where |
|---|---|---|
| A second/third gun as a frozen row | `Weapons.ROWS`, built from each gun's own config, never copied out of it | task 140, `docs/research/2026-10-09-rifle-scope.md` |
| A cycle and a reload as **data** | `CYCLE` / `RELOAD` step lists walked by `runCycle`, charged per-sequence by `waitFor` | tasks 142 and 184 |
| "Opening the action throws the fired case only" | `CYCLE_EJECTS = "spent"` in `StateMachine.apply`'s `Break` | task 142 |
| "Push one round in by hand" | `StateMachine.apply`'s `Load` — it fills **exactly one** empty chamber from the pocket | task 24 (the shotgun) |
| An **open-sighted** gun with no glass | `SIGHT = "bead"`, `Geometry.sightKind`, the `onlyFor`/`skipFor` piece filter, `ShapeRifle`'s `skipFor` | task 143, kept on purpose when task 148 retired the row (`backups/2026-10-10-rifle-open-sights.md`) |
| A drag model fitted to published velocities | `Ballistics`, `v(s) = v0·exp(-k·s)`, one coefficient | task 185, `2026-10-14-ballistics-lead.md` |
| A flattened trajectory as a **dial** | `GRAVITY_SCALE`, read only by `Ballistics.dropAt` | task 189 |
| Per-weapon voices | `Lever.CONFIG.SOUND` read by `Sound.voiceFor(row, kind)` | task 142, `2026-10-10-rifle-bolt-magazine-sound.md` |
| Poses outside the code | `poses.json`, the content lane, `tools/pose.py` | task 98, `2026-10-01-poses-as-data.md` |
| Hand anchors measured off the model | the bolt-knob sphere fit and the wrist's four tolerances | task 188, `2026-10-15-rifle-right-hand.md` |
| Split one bought model into hinge groups in the game's frame | `tools/gltf_split.py`, with the anchor-triangle trick so every group imports at one size and origin | tasks 96 and 105 |
| A gun sold on a ladder | `Shop.ROWS` + `grants.weapon` + `Shop.ownsWeapon` | task 178; the rung this one re-occupies is `backups/2026-10-16_task-196_shop-rifle-open-row.md` |

**What is invented here, and the written reason rule 2 asks for:**

1. **`Weapon.cycleRefusal`** — a pure three-answer rule (`walk` / `finish` / `abort`) replacing one
   hard-coded boolean in `runCycle`. Not borrowed because the thing it generalises is this repo's own
   two-year-old expression; see section 5.
2. **`CYCLE_KIND = "lever"`** — a third value beside `"hinge"` and `"slide"`. Not borrowed because
   neither existing value is right, and using the wrong one is a measurable defect; see section 6.
3. **`Viewmodel.handFeedsShells`** — a declared fact about a gun, replacing a predicate that was
   answering a question it was not asked. See section 7.
4. **The `load` sound key** — because none of the three existing keys names "a cartridge going
   through a gate", and reusing `magazine` would put that word on a gun that has no magazine.

---

## 3. The cartridge: a .45-70, fitted and then predicting

**Sources.** All three are ordinary copyrighted web pages. No code and no asset is taken from any of
them; what is taken is published factory data, cited as fact.

**3.1 Hornady LEVERevolution .45-70 Govt 325 gr FTX — the published velocity table.**
- Midwest Gun Works' product page: <https://www.midwestgunworks.com/page/mgwi/prod/82747>
- Gunners Den's .45-70 comparison chart: <https://gunnersden.com/45-70government/>
- *Licence:* retail spec sheets, all rights reserved; the figures are Hornady's own published data.
- *Maintenance:* live retail pages, revised with the catalogue.
- *Good at:* four velocities for **the exact load a Marlin 1895 is sold for** — 2050 / 1729 / 1450 /
  1225 fps at 0 / 100 / 200 / 300 yd from a 24-inch barrel. Enough to fit one coefficient to the
  first interval and then **predict** the other two.
- *Bad at:* no drop table for a 100 m zero, no BC-driven trajectory, no game units. **Two
  independent pages were compared** so that a typo on one cannot become this gun's muzzle velocity.
- *Adopted:* the four velocities, and nothing else.

**What was computed from them, by task 185's own method and not by a second one:**

```
MUZZLE_STUDS_PER_S = 2232      2050 fps = 624.84 m/s, at 0.28 m/stud = 2231.6
DRAG_PER_STUD      = 5.21e-4   v(s) = v0·exp(-k·s), FITTED TO THE 100 yd POINT ONLY:
                               100 yd = 326.57 studs; ln(2050/1729)/326.57 = 5.214e-4
```

Then, with **nothing fitted to either point**:

| range | published | this model | error |
|---|---|---|---|
| 200 yd (653.1 studs) | 1450 fps | 1459 fps | **+0.6 %** |
| 300 yd (979.7 studs) | 1225 fps | 1231 fps | **+0.5 %** |

That is the whole argument for one coefficient instead of a G1 drag table, and it is the same
argument `Rifle.CONFIG.DRAG_PER_STUD` carries — it fits this cartridge **better** than it fits the
.416 (whose prediction was 0.9 % high).

**`GRAVITY_SCALE = 0.35`, and it is Karen's dial.** At 1.0 — real gravity, which is what
`Ballistics.CONFIG.GRAVITY_STUDS_PER_S2` is — a 100 m zero puts this bullet **+4.14 cm at 50 m, 0 at
100 m and −14.84 cm at 150 m**. That is real, and it is also exactly the complaint task 189 was
raised for (Karen, 2026-10-15: *"it has to be acurat 100% 100m 150m"*). Both terms of the deviation
are exactly proportional to g, so the scale moves the whole band and nothing else — and
`timeToRange` never reads gravity, so **every stud of lead on a running boar is untouched**. At 0.35
the band is **+1.45 / 0.00 / −5.19 cm** at 50 / 100 / 150 m: inside any zone on a boar, while the
bullet still visibly falls past 150 m where the scoped rifle's 0.12 does not. One line either way.

**No cone.** `SPREAD_FULL_DEG = 0`, for the reason `Rifle.CONFIG` already writes down: *"a number
nobody can predict is the wrong place to put character"*. This gun's character is its reach, its
drop and its cycle.

---

## 4. One throw: what it does, and how long it takes

**4.1 Hunter-Ed, "How Does a Lever Action Rifle Work?"**
<https://www.hunter-ed.com/national/studyGuide/How-Does-a-Lever-Action-Rifle-Work/201099_700056147/>
- *Licence:* course material, all rights reserved (Kalkomey). *Maintenance:* actively maintained
  state hunter-education courseware.
- *Good at:* the sequence of one throw — **eject, feed, cock**, in that order, from a tubular
  magazine.
- *Bad at:* a teaching diagram. Nothing about the gate, nothing about rate.
- *Adopted:* the two-step reading. Down-and-forward **ejects** (`Break`), back **feeds and
  chambers** (`Close`). This is why the lever **adds no primitive to the reducer**: the two steps it
  needs are the two the bolt rifle already uses, and `CYCLE_EJECTS = "spent"` is the direct
  consequence of "eject" meaning the fired case and not the whole magazine.

**4.2 Gun Digest, "Cowboy 101: How To Run A Lever-Action Rifle"**
<https://gundigest.com/rifles/cowboy-101-how-to-run-a-lever-action-rifle>
- *Licence:* editorial, all rights reserved. *Maintenance:* actively published magazine site.
- *Good at:* the throw as **one continuous motion of the hand that is already on the grip**, with
  the rifle staying mounted through it.
- *Bad at:* no timings at all, so it cannot settle a number.
- *Adopted:* the hand never leaves the gun — which is what `cycle.hand.reachShare` being small
  means, and why the right hand is carried **by the lever's own arc** rather than reaching for it.

**4.3 Ranger Point Precision, "Tips on How to Hold, Aim, and Shoot a Lever-Action Rifle"**
<https://rangerpointstore.com/news/tips-on-how-to-hold-aim-and-shoot-a-leveraction-rifle/>
- *Licence:* vendor blog, all rights reserved. *Maintenance:* active commercial site — and it
  **sells short-throw kits**, which is a declared interest.
- *Good at:* the only one of the three that connects the motion to a **rate**: a shorter lever throw
  raises the practical rate of aimed fire.
- *Bad at:* commercial, and it states no measured rate.
- *Adopted:* the **direction only** — a lever cycles faster than a bolt.

**So: 1.10 s, and it is bracketed by two numbers this repo has already measured on screen.**

- **Faster than 1.62 s**, which is the bolt's, and which is **Karen's own number**: task 184,
  *"I think it reloads to fast has to be 1 s slower"* and, asked which sequence she meant, *"Bolt
  after each shot"*.
- **Slower than 0.62 s**, which is what the bolt first shipped at and which read as too fast.

Split 0.46 / 0.64 on the bolt's own ratio (0.68 / 0.94 = 42 % / 58 %), so the out-stroke is the
shorter half and only the pace changed. **It is a dial and it is Karen's.**

**The reload is slower than the rifle's, and that is the trade.** `RELOAD` is
`Break 0.40, Load 0.42 × 5, Close 0.40` = **2.90 s** against the rifle's 1.97 s magazine change.
Filling a tube one cartridge at a time is slow; that is the price of carrying five instead of three.

---

## 5. `barrel-full` on a `Load`: the one refusal rule

`runCycle` walks past exactly one refusal today:

```luau
if reason and not (step.kind == "Load" and reason == "no-reserve") then  -- abort + recover
```

A **partial top-up** — three in the tube of five, press `R` — makes the fourth `Load` answer
`"barrel-full"`. Traced against the shipped code, that falls into the recovery branch whose own
comment says *"the world moved under it"*: it waits out the window, applies `Close` and
republishes. The gun does end up shut, so this is not a crash — but a **correct** event is routed
down an error path, and the `Close` it runs is never published as a step, so `snapshot.action` never
says `Close` for it.

**Neither shipped gun can reach it**, which is why nobody has: the shotgun's `Break` ejects `"all"`
so both its chambers are always `Empty` when its two `Load`s run, and the rifle's reload uses
`Magazine`, which fills every chamber at once.

The rule adopted is **three answers from one pure function**, which is this repo's own shape for
"a closed set of reasons the specs can name" (`StateMachine.apply`'s rejection reasons):

| step, reason | answer | why |
|---|---|---|
| `Load`, `no-reserve` | `walk` | closing a gun with fewer rounds is correct — bit-for-bit today |
| `Load`, `barrel-full` | `finish` | the tube is full: skip the remaining `Load`s and run the last step |
| anything else | `abort` | the world moved under it — today's recovery, unchanged |

`finish` rather than `walk` because `walk` gives a **fixed-length reload**: the unused `Load` steps
still burn 0.42 s each, so putting two rounds in would take the same 2.90 s as putting in five. With
`finish`, a two-round top-up is **0.40 + 2 × 0.42 + 0.40 = 1.64 s** and the `Close` is a real
published, timed, voiced step. One line either way (design 17 D-a).

---

## 6. Why the drawn cycle is a third kind and not `"hinge"`

Measured on the bought model, in the game's Handle frame (`driven-hunt-runs/t224/measure.py`, which
imports `tools/gltf_split.py` so there is **one** frame and not a second copy of the maths):

```
lever pivot      (0, -0.0660, +0.1944)     the boss where the loop pins into the receiver
loop apex        (0, -0.3592, +0.8204)     reach 0.6913 from the pivot; the bar is ~0.044 thick
```

Rotating the apex about the pivot, **positive about +X**:

| throw | apex moves |
|---|---|
| 30° | down 0.253, forward 0.225 |
| 45° | down 0.328, forward 0.379 |
| **60°** | **down 0.360, forward 0.546** |
| 70° | down 0.357, forward 0.660 — the loop has begun to come back up |

So the throw is **down and forward**, it is a positive rotation, and ~60° is where the loop stops
going down — which is a real Marlin's throw and is the seed for `cycle.openDeg`.

**Two named symbols say `"hinge"` is the wrong value:**

1. `Camera.Viewmodel.poseHands` places the LEFT hand with
   `(geometryNow().CYCLE_KIND or "hinge") == "hinge"`. On a break action the left hand holds the
   barrels and swings with them. On this gun it holds the **fore-end**, which is bolted to the
   barrel and does not move — so `"hinge"` would ride the fore-end glove through the loop's whole
   arc, a hand sliding off the gun once per shot.
2. `Viewmodel.hinge`'s break branch is `CFrame.Angles(-math.rad(angle), 0, 0)`. That **negative**
   rotation carries a loop hanging below and behind its pin **up and toward the butt** — the wrong
   way. Expressing the fix as a negative `openDeg` in `poses.json` would put a sign in the content
   lane and the arithmetic in the viewmodel, which is precisely the defect `Rifle.Geometry.boltLift`
   was created to fix in task 188 (*"the handle simply disappears into the gun for the whole
   cycle"*).

So the sign lives in `Lever.Geometry.leverThrow`, beside the pivot it turns about, and the spec
drives it: at full throw the loop's grip point must have **both** a smaller Y and a more negative Z
than at rest.

---

## 7. Loose shells: a borrowed predicate answering a question it was not asked

`Viewmodel.shells` and `Viewmodel.loadingAt` are both gated on `config.MAGAZINE_SWAP ~= nil`. That
field answers *"does this gun swap a box"*. It was standing in for *"does this gun put loose rounds
in the player's hands"*, and on the two shipped guns those happen to agree.

**The lever has no magazine**, so the predicate answers "yes, draw them" — and underneath it,
`chamberOffset` is `Gun.chamber(barrel, Shotgun.CONFIG)`: the **shotgun's** chamber mouths, at the
shotgun's 4.4-stud layout, with the shotgun's red 12-gauge hull. After every shot a shotgun shell
would flip out of a .45-70. That is the knife-held-backwards class of defect `PROJECT_CONTEXT.md`
opens with: two correct pieces of code disagreeing.

The fix is **a declared fact about the gun**, not a second borrowed predicate: each geometry module
carries `HAND_FED_SHELLS` (`Gun` true, `Rifle.Geometry` false, `Lever.Geometry` false), and
`Viewmodel.handFeedsShells(geometry)` is one pure exported expression the client spec can drive with
no Tool in a hand. `MAGAZINE_SWAP` keeps its other two readers untouched.

**The drawn gate feed is explicitly NOT built here** (design 16.6, queued as 224a). Drawing a
cartridge going into the gate needs `loadingAt`'s `for barrel = 1, 2` generalised to every chamber,
`chamberOffset`'s hard-wired `Shotgun.CONFIG` replaced by the gun's own geometry, and
`Camera.breakFrom`'s two-chamber `loaded` widened — four changes to shipped drawing code in three
owners. This task **suppresses** the wrong drawing rather than half-building the right one, and says
so out loud.

---

## 8. The asset: the Rigby's pipeline, step for step

Karen bought the model (Jeick, "Lever action rifle" on Fab — a Ruger-made Marlin 1895 SBL in
.45-70). **It is never committed and never redistributed**; everything below runs outside the repo.

```
FBX --(headless Blender, driven-hunt-runs/t224/fbx_to_gltf.py)--> glTF (separate form)
    --> tools/gltf_split.py probe/split  with the new LEVER_PLAN
    --> tools/asset_prep.py prep --preset model-b   per group
    --> tools/roblox_upload.py
```

**Why the conversion is a one-off script and not a tool.** `tools/gltf_split.py`'s docstring states
*"NO NETWORK, NO BLENDER, NO `bpy`"* as a design property — it is stdlib-only so its `selftest` runs
anywhere CI runs. Putting an FBX importer in it would break that promise. The **plan** does go in
that file, beside `MODEL_B_PLAN` and `RIGBY_PLAN`, because its docstring says why plans live there:
*"reviewed as a diff rather than carried in a loose JSON file nobody reads"*.

**The names lie about the action, exactly as the Rigby's did, and the geometry says so** (design
10.2, D-4). `Trigger frame` is the finger lever — on a Marlin the lever **is** the trigger guard,
which is why the file has no separate guard node; `Bolt action` is the breech bolt; `slide ` (with
the artist's trailing space) is the loading gate, the only node lying entirely on one side of the
centre line; `Magazine` is the tube and `Magazine release` its front cap. **Looked at** (rule 5):
the lever group's own preview is unmistakably a large-loop finger lever with its pivot plate.

**The rail stays, and that is a measurement.** The rear sight sits at y +0.1901..+0.2301 — on the
rail's top face — while the receiver's top is +0.1759. Dropping the rail leaves the rear sight
floating over a bare slot, which is the face-level surgery task 147 was cancelled for. This rifle is
sold with a rail and ghost-ring irons on it: **the rail is the sight base**, and the gun aims down
its own irons.

**A measurement worth writing down: the model's irons are set up level.** The rear notch floor is
y +0.1901 and the front blade tip is y +0.1903, over 2.2318 studs of separation — a sight line
**0.0055° from level**, sitting 0.0701 above the bore. Nothing had to be invented for the aim pose:
the gun's own sights define it.

**Textures:** the artist's four 4K maps resized to **1024** on disk before the glTF export (Blender's
exporter copies or composites from the file, so an in-memory `image.scale()` reached only the base
colour — measured: the normal and the packed metal/rough both came out 4096 on the first attempt).
`asset_prep` then split the packed metal/rough into the two single-channel maps Roblox reads and
wrote metalness 0.10 / roughness ~0.5 on the steel. **No base colour was recoloured.**

**Triangles:** 13,705 / 3,208 / 578 as bought. The action was decimated to **8,258** — the Rigby's
own worst group, which is the number this repo has already shipped and looked at — and the rail's
slots and the receiver's panel lines survive it (looked at, `render_side.png`). Roblox's ceiling is
20,000 per mesh. The whole gun is **12,044 triangles over three meshes**, against the shipped
Rigby's four at 18,672.

**One honest note about the prep.** The stock group classified as `steel` with **zero** `wood`
triangles, and that is the model rather than a fault: an 1895 SBL's stock is **grey laminate**, not
warm walnut, so its pixels are below the recipe's `satMin 0.18`. The only consequence is which shine
numbers were written (metalness 0.10 / roughness 0.544 instead of 0.00 / 0.22) — in the direction of
*less* shine, not more. Looked at: the stock reads as grey laminate with its grain.

---

## 9. Numeric targets

In the design, section 14 — not restated here.

## 10. What this note does not settle

Karen's, every one a dial and one line: `GRAVITY_SCALE` 0.35 (vs 1.0), the cycle at 1.10 s and the
reload at 2.90 s, the recoil block, the three voices and their pitches, and the shop price
(650 / 12 hunts). Nobody here has heard a sound or felt a kick.

# The semi-automatic shotgun (task 225)

**Written before any code (rule 1).** The design is `docs/design/semiauto-shotgun.md`; the brief that
fed it is `reviews/task-225/BRIEF.md`. This note holds the outside evidence, what each source is good
and bad at, what was adopted, and the numeric targets.

Karen, 2026-10-20: *"so you have things to do / deer / weapons / make it work like we have now"*.
Her standing bar is that shooting, weapon and reload must be **perfect**, on a separate-part model,
with every frame checked.

---

## 1. What the system must do

A fourth gun in the shipped weapon system, bought in the shop, that behaves like the three already
there and adds exactly one thing none of them has: **it works its own action**.

1. Each trigger pull fires one shell; the gun then ejects the hull, feeds the next and locks up, with
   nothing in the shooter's hands.
2. It holds **4 in the tube + 1 in the chamber**.
3. It reloads by single shells pushed through the loading port under the receiver, with the lifter
   tray rising for each one.
4. It carries a red-dot sight that is usable when aiming.
5. It fires the **same buckshot and slug** as the side-by-side.
6. It kicks **less** than the side-by-side.
7. It is sold in the shop and is carried only by a player who bought it.

---

## 2. The asset, and a correction to the dispatch

The model is Karen's own purchase: PStudio, "Semi-Automatic Shotgun" on Fab — an MP-153-pattern
12 gauge with a rail and a red-dot sight. **Fab Standard licence, Personal tier**, recorded as the
boar's and the lever's are. It is never committed and never redistributed; everything the pipeline
writes lives outside the repo.

**THE DISPATCH DESCRIBES IT AS A RIGGED SKELETAL MESH WITH BONES `Trigger`, `Zatvor`, `Lotok`,
`Otse` and `Gauge12`. IT IS NOT, AND THAT WAS MEASURED TWICE.** `SM_Shotgun.fbx` (FBX 7400) was read
by Blender and, independently, by a stdlib parser of the binary itself
(`driven-hunt-runs/t225/probe_fbx.py`, `fbx_nodes.py`). Both agree: **no armature, no bone, no
`Deformer`, no `Cluster`, no `LimbNode`, no skin weight**, and none of those five strings occurs
anywhere in the file. Its 12 nodes are named `shotgun.004`, `shotgun.012` … `shotgun.022` and
`sight.001`.

**This is better than a rig for this pipeline, not worse.** Every part the task needs to move is
already a SEPARATE OBJECT, which is what `gltf_split` wants; a skinned mesh would have had to be
decomposed first. What it does mean is that **the split is read off the geometry and not off the
names** — the lesson `tools/gltf_split.py`'s `RIGBY_PLAN` comment already writes down: *"THE NODE
NAMES ARE WRONG ABOUT THE BOLT, AND THE GEOMETRY SAYS SO"*.

**The frame, measured:** forward (the muzzle) is **−Y**, up is **+Z**, so right is **−X**. That
handedness is not assumed — it is **proved by the gun**. The charging handle (`shotgun.014`, reaching
to x −0.0375) and the bolt-release button (`shotgun.021`, lying entirely at x −0.0247 … −0.0203) are
the only two objects off the centre line; they are on the same side; and on an MP-153 both are on the
**right**.

**Each object was identified by measurement and then LOOKED AT** (rule 5). The 12 objects were
rendered in 12 flat colours from four sides and two zooms
(`driven-hunt-runs/t225/parts-{right,left,top,bottom}.png`, `zoom-right.png`, `zoom-bottom.png`,
`label_render.py`), and every identification below was read off those frames and confirmed by exact
pixel colour. The right-flank frame shows the bolt filling the ejection port with the release button
beside it; the underside frame shows the lifter tray in the loading port with the bolt visible above
it through the slot.

---

## 3. The scale, derived from the barrel and checked three ways

The model is 1.4208 file units long. Anchoring on the **barrel object** — the one dimension a
shotgun is actually specified by, and an unambiguous single mesh here — at the MP-153's listed
710 mm gives **1 file unit = 882.9 mm**. Nothing else was fitted, and then:

| quantity | at that scale | published | error |
|---|---|---|---|
| overall length | **1254 mm** | 1250 mm (4.2) | **0.3 %** |
| receiver width | **37.7 mm** | ~38 mm | 0.8 % |
| magazine tube, receiver face to cap | **313 mm** = 4.1 shells of 76 mm | **4 + 1** for 12/76 (4.2) | exact |

Three independent checks inside 1 %, none of them fitted. **The capacity is therefore measured off
the model AND confirmed by the manufacturer's own figure**, which is a stronger statement than either
alone — and it is the dispatch's "4+1 (say)" confirmed rather than adopted.

At the repo's own 3.87 studs/m (the shotgun is 4.4 studs for ~45 in, the lever 4.0 for 40.5 in) that
is 4.85 studs. The design ships **4.9**, inside the spread of the two anchors, and it makes this the
**longest gun in the game** — which is true of the real one.

---

## 4. The sources

Five external sources and the repo's own prior art. **No code and no asset is taken from any of
them**: what is borrowed is a fact, a mechanism's shape, or one pattern (rule 2).

### 4.1 Hunter-Ed (Kalkomey), "Semi-Automatic (or Autoloading) Action"

<https://www.hunter-ed.com/national/studyGuide/Semi-Automatic-or-Autoloading-Action/201099_92823/>
(resolved 2026-10-20; the deep link in the design's 13.1 404s and this is the live page).

*Licence:* state hunter-education courseware, all rights reserved (Kalkomey). *Maintenance:*
actively maintained — it is the material US states certify against.

*Good at:* the cycle in one sentence, which is exactly the behaviour this task has to draw: *"As each
shot is fired manually, the case of the cartridge or shotshell is ejected automatically and the
chamber is reloaded automatically"*, and *"the trigger must be pulled each time a shot is fired"*.
That is `AUTO_CYCLE = true` with a two-step `CYCLE` and **nothing in the shooter's hands**.

*Bad at:* it is a teaching page. It carries **no timings at all**, so it cannot settle the 0.30 s
cycle — that number is bracketed by this repo's own measured-on-screen numbers and is Karen's dial.

*Adopted:* the two-step reading of one stroke; `CYCLE_EJECTS = "spent"` as its consequence (the hull
leaves, the tube keeps its live rounds); and the fact that **the hands do not move**, which is what
`cycle.poseShare = 0` draws.

### 4.2 Wikipedia, "Baikal MP-153"

<https://en.wikipedia.org/wiki/Baikal_MP-153> (resolved 2026-10-20), cross-read against the retail
and editorial reviews it cites (American Hunter, GunMart) so that one typo cannot become this gun's
capacity.

*Licence:* CC BY-SA 4.0. *Maintenance:* actively maintained.

*Good at:* the four numbers section 3 checks the MODEL against — **4 + 1 for the 12/76 shell** (3 + 1
for 12/89), gas-operated, barrels of 610 / 650 / **710** / 750 mm, overall 1250 mm. These are what
turn our measurements from "self-consistent" into "right".

*Bad at:* an encyclopaedia entry. No drawing of the lifter, no cycle time, and its overall-length
figure is quoted beside a different barrel length than ours, which is why the barrel is the anchor
and the overall length is the check.

*Adopted:* the capacity and the barrel length, and nothing else.

### 4.3 Roblox Creator Documentation, `SurfaceAppearance`

<https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance>

*Licence:* Roblox creator documentation, content CC-BY-4.0 (`github.com/Roblox/creator-docs`).
*Maintenance:* actively maintained, public repository.

*Good at:* the **exhaustive** channel list — ColorMap, NormalMap, MetalnessMap, RoughnessMap. That
list is the whole evidence for two decisions: the artist's `M_Sight01_Emissive.png` **renders as
nothing at all**, so the red dot has to be drawn; and the packed `Mixed_AO` maps have nowhere to go
and are dropped.

*Bad at:* it documents the class, not the renderer, so what a bright material looks like beside it
comes from 4.4.

*Adopted:* the dot is a drawn piece, not a texture channel; the AO maps are not uploaded.

### 4.4 Roblox Creator Documentation, `Enum.Material`

<https://create.roblox.com/docs/reference/engine/enums/Material>

*Licence / maintenance:* as 4.3.

*Good at:* `Neon` is a **material that renders bright**, not a light source — Roblox emits light only
from `PointLight` / `SpotLight` / `SurfaceLight` instances. So an always-lit dot is not "a light the
player cannot switch off", which was the brief's reason for gating it on the aim blend, and the
design overrules that reason on this evidence.

*Bad at:* no photometry. **How bright the dot actually reads is a screenshot, not a document**, and
after that it is Karen's.

*Adopted:* the dot ships lit; turning it off on the hip is a one-line transparency write at one
owner if she wants it (225a).

### 4.5 NRA Women, "The Semi-Automatic Shotgun Dilemma: Inertia vs. Gas"

<https://www.nrawomen.com/content/the-semi-automatic-shotgun-dilemma-inertia-vs-gas>, read with
<https://www.nrawomen.com/content/understanding-and-mitigating-shotgun-recoil>.

*Licence:* editorial, all rights reserved. *Maintenance:* a live editorial site.

*Good at:* **the mechanism and its direction, stated quantitatively enough to argue from**: in a
gas gun roughly 30–40 % of the propellant gas is turned rearward to cycle the bolt while the rest
drives the shot, and *"the total recoil energy is spread out over a longer period of time than would
be the case with fixed-breech shotguns"*. A break-action is a fixed breech. That is the evidence for
shipping this gun's recoil **below** the side-by-side's, and it is better evidence than the design's
original "physics".

*Bad at:* it gives no figure for **how much** less, on any gun. The energy is the same; only its
spread changes, and felt recoil is a sensation.

*Adopted:* the **direction only**. The magnitude is not measured anywhere and is therefore **Karen's
dial, not a derivation** — said plainly, because the alternative is a number that looks measured and
is not.

### 4.6 Chuck Hawks, "Shotgun Recoil Table"

<https://www.chuckhawks.com/shotgun_recoil_table.htm>

*Licence:* editorial, all rights reserved. *Maintenance:* **dormant** — a static reference page.

*Good at:* free-recoil energy per 12-gauge load, which is the only published number behind "a slug
kicks harder than buckshot". That ratio is already in this repo as `fire.loads` (`Slug` 1.45).

*Bad at:* **fixed-breech free recoil**, so it says nothing about a gas gun, and it is the weaker half
of 4.5's argument rather than an independent one.

*Adopted:* the per-load ratio, which is the shotgun's own and does not change for this gun.

### 4.7 ioquake3, `code/cgame/cg_weapons.c`

<https://github.com/ioquake/ioq3> — `CG_AddPlayerWeapon`, `CG_MachinegunSpinAngle`.

*Licence:* GPL-2.0. *Maintenance:* actively maintained fork of the id Software release.

*Good at:* the established pattern for a weapon's **second, independently driven sub-part** — the
barrel is its own model, placed every frame from a value derived from game state plus a local clock,
beside the weapon's own animation rather than baked into it. That is this task's one new mechanism
with our names in it: `lifterSwing` from `liftProgress`, beside `boltTravel` from `cycleProgress`.

*Bad at:* a C renderer with its own entity system. **No code is copied**, and the clock seam here is
this repo's own (`Viewmodel.setMagazine` / `magazineProgress`, shipped in task 142).

*Adopted:* two sub-parts, two drivers, one per-frame placement site; the server state says WHICH step
and HOW LONG, the client owns HOW FAR THROUGH.

### 4.8 In-repo prior art, which rule 2 makes the first place to look

`docs/design/lever-rifle.md` (the fourth row's whole shape, `cycleRefusal`, `HAND_FED_SHELLS`, the
measurement list); `docs/design/rifle.md` (a second weapon as a row, the sight filter, `boltLift`'s
sign); `docs/design/shotgun.md` (the reducer and the remotes); `docs/design/shop.md` 7.1 (the nil
ownership set and its accepted cost); `docs/research/2026-10-20-lever-action.md`;
`2026-10-09-rifle-scope.md`; `2026-10-10-rifle-bolt-magazine-sound.md`; `2026-10-14-ballistics-lead.md`;
`2026-10-15-rifle-right-hand.md` (hand anchors as a line and a radius); `2026-10-01-poses-as-data.md`;
`backups/2026-10-10-rifle-open-sights.md` (the sight machinery this design deliberately does NOT
reuse, and why).

---

## 5. The pattern adopted, and what had to be invented

**Borrowed, not built (rule 2).** The whole weapon is a fourth row through machinery that ships:
`Weapons.ROWS`, `StateMachine`'s `Break`/`Load`/`Close` reducer, `runCycle`, `Shop`'s ownership gate,
`gltf_split` → `asset_prep` → `roblox_upload`, and the lever's `OWNED_ONLY`. Nothing in that list is
re-answered.

**Three things genuinely had to be added, and each has a written reason:**

1. **A fourth `CYCLE_KIND`, `"straight"`.** A gas bolt reciprocates and nothing rotates. Reusing
   `"slide"` with a zero lift angle would spend the first third of the stroke doing nothing and would
   need a `boltLift` that exists only to return identity — **a pose dial that moves nothing on
   screen, which is the silent-number defect task 188 was raised for**.
2. **A second moving group** (4.7's pattern). Every gun so far has one; this one has two, on two
   different sequences — the bolt on `CYCLE`, the lifter on each `Load` of `RELOAD`. It is
   **declared beside** the first (`LIFT_GROUP_NAME`) rather than overloaded onto it, and its sign and
   pivot live in the GEOMETRY, for task 188's reason.
3. **One pose number, `cycle.poseShare`.** The design's own finding, which the brief missed: the
   shipped break-action blend carries the gun and both hands to the cycle pose and back **whatever
   the aim is**, so a self-cycling gun lurches out of the sight picture 2.4 times a second and **no
   choice of pose data can fix it**. The number defaults to 1, so all three shipped guns are
   bit-for-bit what they are today.

---

## 6. The numeric targets

| target | value | why that number |
|---|---|---|
| overall length | 4.9 studs | section 3: 710 mm barrel → 1254 mm, three checks inside 1 % |
| capacity | 5 (4 + 1) | measured off the tube (313 mm / 76 mm) **and** published (4.2) |
| cycle | 0.12 + 0.18 = **0.30 s** | far under the lever's 1.10 and the bolt's 1.62 (a gas gun cycles while the shooter does nothing) and **not zero**, so the bolt is visibly back for a frame |
| rate | 0.42 s between shots | `BARREL_DELAY` + `CYCLE_TOTAL`; the gun's whole character, and Karen's |
| reload | 0.35 + 5 × 0.38 + 0.35 = **2.60 s** | the slowest in the game: the price of five rounds. A two-shell top-up is 1.46 s |
| bolt travel | ≥ 0.29 studs | 76 mm, one hull: less and the hull could not clear the port |
| lifter rise | ≥ 0.079 studs, upward | 20.5 mm, one hull diameter: less and the tray could not lift a shell to the chamber |
| recoil | **below** the side-by-side's | 4.5's direction. The magnitude is Karen's dial, not a derivation |
| ballistics | identical to the shotgun's, by reference | the same cartridge: a second copy would be a second answer |
| triangles | 8,724 over six groups, worst 2,802 | nothing decimated (the repo's shipped worst is 8,258) |
| price | 500 coins, 8 hunts | under the lever's 650: it buys **volume**, not reach |

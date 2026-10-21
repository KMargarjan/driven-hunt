# Task 225 BRIEF: the semi-automatic shotgun

**Written by the Builder, carrying the Director (dispatch 2026-10-20).** The input to
`tools/architect.sh design semiauto-shotgun --task 225`. Per `docs/ARCHITECT_PROMPT.md` this file is
read first and **overrides anything older** in `docs/`, `TASKS.md` or an earlier design.

**Karen, 2026-10-20 ~13:25, verbatim:** *"so you have things to do / deer / weapons / make it work
like we have now"*. Her standing bar: shooting, weapon and reload must be **perfect**; a
separate-part model; every frame checked against the target.

**UPLOAD OK and placement, her choice, verbatim:** *"Upload, sell in shop (Recommended)"*, answering
*"The two new guns (lever-action rifle + semi-auto shotgun): may I upload their models to Roblox
(your account, used only in this game), and how do players get them?"* So: the meshes are uploaded to
Karen's account, a row in `assets/uploads.json` carries those words, and the gun is **bought in the
shop**.

**THE MODEL IS BOUGHT AND STAYS OUTSIDE THE REPO.** PStudio, "Semi-Automatic Shotgun" on Fab (an
MP-153-pattern 12 ga), Fab Standard licence, Personal tier -- recorded exactly as the boar's and the
lever's are. Never committed, never redistributed.

---

## 0. THE DISPATCH'S DESCRIPTION OF THE ASSET IS WRONG, AND IT WAS MEASURED

The dispatch says the file is *"a rigged skeletal mesh with bones Trigger, Zatvor (the bolt), Lotok
(the shell lifter), Otse, Gauge12 (the shell) and the sight"*. **It is not.** `SM_Shotgun.fbx` (FBX
7400) was read two ways -- by Blender and by a stdlib parser of the binary itself
(`driven-hunt-runs/t225/probe_fbx.py`, `fbx_nodes.py`) -- and both say:

* **no armature, no bone, no `Deformer`, no `Cluster`, no `LimbNode`, no skin weight.** Every vertex
  in the file is unweighted.
* the strings `Trigger`, `Zatvor`, `Lotok`, `Otse` and `Gauge12` **do not occur anywhere in the
  file**.
* the 12 nodes are named `shotgun.004`, `shotgun.012` ... `shotgun.022` and `sight.001` -- generic
  and in no useful order.

**This is better than a rig, not worse, and it changes no decision below.** Every moving part the
dispatch asks for is already a SEPARATE OBJECT, which is precisely what this pipeline wants -- the
lever's was the same and the Rigby's was not. What it does mean is that **the split is read off the
geometry and not off the names**, which is the lesson `tools/gltf_split.py`'s `RIGBY_PLAN` comment
already writes down: *"THE NODE NAMES ARE WRONG ABOUT THE BOLT, AND THE GEOMETRY SAYS SO"*.

**THE FRAME, MEASURED:** forward (the muzzle) is **-Y**, up is **+Z**, and therefore right is
**-X** (forward cross up). That handedness is not asserted, it is **proved by the gun**: the charging
handle (`shotgun.014`, reaching to x -0.0375) and the bolt-release button (`shotgun.021`, lying
entirely at x -0.0247..-0.0203) are the only two objects off the centre line, they are on the SAME
side, and on an MP-153 both are on the **right**. The model is already axis-aligned, so there is no
Sketchfab tilt to measure out.

**THE SCALE, cross-checked twice against the real gun.** Forcing the overall length to a real
MP-153's 1270 mm gives **1 file unit = 0.894 m**. At that scale the barrel object measures **719 mm**
(the gun is sold with a 710 mm barrel) and the receiver **38 mm** wide (the real one is 38). Two
independent checks inside 1.5 %, neither fitted.

**WHAT EACH OBJECT IS.** Measured, then *looked at* -- the 12 objects were rendered in 12 flat
colours from four sides and from two zooms, and each identification below was read off those frames
and confirmed by the pixel colours (`driven-hunt-runs/t225/parts-*.png`, `zoom-right.png`,
`zoom-bottom.png`, `label_render.py`).

| object | what it is | material | tris | y (long) | z (up) |
|---|---|---|---|---|---|
| `shotgun.012` | **barrel**, with its vent rib | barrel | 1192 | -1.1334 .. -0.3293 | +0.0570 .. +0.1007 |
| `shotgun.022` | **fore-end** over the gas system and tube | barrel | 526 | -0.6937 .. -0.3308 | +0.0138 .. +0.0763 |
| `shotgun.004` | **magazine cap** at the tube's muzzle end | barrel | 1084 | -0.7200 .. -0.6851 | -0.0030 .. +0.0599 |
| `shotgun.013` | **receiver** | stock | 972 | -0.3305 .. -0.0839 | +0.0254 .. +0.0979 |
| `shotgun.014` | **BOLT + charging handle** -- fills the ejection port on the right flank, and is seen from below through the loading port | stock | 634 | -0.3210 .. -0.2083 | +0.0613 .. +0.0939 |
| `shotgun.018` | **SHELL LIFTER**, the tray in the loading port under the receiver | stock | 248 | -0.3100 .. -0.2114 | +0.0257 .. +0.0381 |
| `shotgun.016` | **trigger guard** | stock | 418 | -0.2152 .. -0.0822 | -0.0079 .. +0.0391 |
| `shotgun.017` | **trigger**, inside that guard | stock | 148 | -0.1365 .. -0.1110 | -0.0034 .. +0.0268 |
| `shotgun.020` | **Picatinny rail** on the receiver's top face | stock | 792 | -0.3230 .. -0.1468 | +0.0955 .. +0.1056 |
| `shotgun.021` | **bolt-release button**, right flank | stock | 70 | -0.2982 .. -0.2886 | +0.0401 .. +0.0498 |
| `shotgun.019` | **butt stock** | stock | 1062 | -0.0943 .. +0.2874 | -0.0851 .. +0.0828 |
| `sight.001` | **red-dot sight**, sitting on the rail | sight | 1578 | -0.3149 .. -0.2503 | +0.0981 .. +0.1421 |

`SM_Gauge12.fbx` is a second file holding **two** shells -- a full round (0.0914 long) and a SHORTER
spent hull (0.0797) -- which is exactly the pair an ejecting semi-auto needs. It is at its own scale
and must be scaled on its own evidence, not the gun's.

---

## 1. The decisions already taken. These are not open.

**D-1. It is a fourth row in the weapon system, joined exactly as the lever rifle was** (task 224).
Its own `Tool` and hotbar slot 4, its own viewmodel drawn with the same gloves, its poses as **data**
in `src/shared/Viewmodel/poses.json` written ONLY through `pose.py`'s serializer (standing rule J),
one row in `Weapons.ROWS` built from its own config module, and `OWNED_ONLY = true`. No new system,
no second owner: `ServerScriptService.Weapon` stays the owner of the action and `Weapons.ROWS` stays
the one table of guns.

**D-2. THE SPLIT IS FORCED BY THE MATERIALS, and `gltf_split` enforces it.** That tool refuses a
group spanning two materials -- *"one MeshPart is one material"* -- and this file has **three**
(`M_Shotgun_barrel`, `M_Shotgun_stock`, `M_Sight`), where the lever had one. So the barrel group and
the sight group are not a choice. **Six groups, and each line below is either a material boundary or
a part that has to move:**

| group | objects | material | tris | why it is its own group |
|---|---|---|---|---|
| `action` | 013, 016, 017, 020, 021 | stock | 2400 | the body. **Worn as `Model`** -- the piece that must be there for the gun to count as dressed (`Hardware.wearsMesh`) |
| `barrel` | 012, 022, 004 | barrel | 2802 | a different material; static |
| `stock` | 019 | stock | 1062 | the silhouette's other half |
| `bolt` | 014 | stock | 634 | **IT MOVES** -- the cycle |
| `lifter` | 018 | stock | 248 | **IT MOVES** -- the reload |
| `sight` | sight.001 | sight | 1578 | a different material, and the red dot |

8,724 triangles in total against the Rigby's 18,672 prepped, so **nothing is decimated**. Six uploads
is two more than any gun so far; the design should say so plainly rather than let it arrive as a
surprise at the upload step.

**D-3. THE ONE GENUINELY NEW MECHANISM IS A SECOND MOVING GROUP, and the design must own it.**
Every gun so far has exactly one (`Geometry.CYCLE_GROUP_NAME` + `CYCLE_KIND`: the shotgun's
`Barrels` hinge, the Rigby's `Bolt` slide, the lever's `Lever` arc). This gun has **two independent
ones on two different sequences**: the **bolt** slides on `CYCLE`, and the **lifter** rises on each
`Load` step of `RELOAD`. The Builder's proposal is that the second is DECLARED beside the first --
a `LIFT_GROUP_NAME` with its own geometry function (`lifterSwing(config, deg, progress)`, the hinge
maths `Lever.Geometry.leverThrow` already models) rather than a second meaning overloaded onto
`CYCLE_GROUP_NAME` -- and that its sign and pivot live in the GEOMETRY and not inline in the
viewmodel, which is precisely what task 188 bought and task 224 restated. **Confirm or overrule, and
name the owner and the file.** This is the task's one piece of real engineering; everything else is a
fourth row through machinery that ships.

**D-4. SEMI-AUTOMATIC: EACH PULL FIRES, AND THE GUN CYCLES ITSELF.** `AUTO_CYCLE = true` (the
lever's), `CYCLE = { Break, Close }`, `CYCLE_EJECTS = "spent"` -- the fired hull is thrown and the
live rounds stay in the tube, which is what a tube gun's ejection is. The Builder proposes
**`CYCLE_TOTAL = 0.30`** (`Break 0.12`, `Close 0.18`), bracketed by numbers this repo has measured on
screen: far faster than the lever's 1.10 and the bolt's 1.62, because a gas gun cycles while the
shooter does nothing, and not zero, because the bolt must be VISIBLY back for a frame or the
dispatch's "mid-cycle with the bolt back" frame does not exist. The practical rate it implies -- a
shot every ~0.42 s with `BARREL_DELAY` -- is the gun's whole character and is Karen's dial.

**D-5. FOUR IN THE TUBE AND ONE IN THE CHAMBER, AND IT IS MEASURED OFF THE MODEL.** `BARRELS = 5`,
`MAGAZINE = 5`, `READOUT = "magazine"`. The tube runs from the receiver face (y -0.3305) to the
magazine cap's rear (y -0.6851): **0.3546 units = 317 mm**. That is 4.5 rounds of 70 mm or 4.2 of
76 mm -- **four either way**, so the answer does not depend on which shell length is assumed, plus
one chambered. It is also what a real MP-153 holds, and it is the dispatch's "4+1 (say)" confirmed
rather than adopted.

**D-6. THE RELOAD IS SINGLE SHELLS THROUGH THE PORT UNDER THE RECEIVER, AND IT ADDS NO PRIMITIVE.**
`RELOAD = { Break, Load x 5, Close }`, the shape task 224 established, because `StateMachine.apply`'s
`Load` already fills **exactly one** empty chamber from the pocket per step -- which is precisely one
shell through one port. `Break` is the hand leaving the grip for the port and `Close` is it coming
back; neither opens anything on this gun, and the design should say that out loud so the words are
not read as a break action. The Builder proposes `Break 0.35`, `Load 0.38`, `Close 0.35`,
`RELOAD_TOTAL = 2.60` -- quicker per shell than the lever's 0.42 because a shotgun port is a bigger
hole than a rifle's gate, and still the slowest reload in the game, which is the price of five rounds.

**D-7. IT INHERITS TASK 224'S ONE SHARED-CODE CHANGE AND NEEDS NO SECOND ONE.** `runCycle`
(`src/server/Weapon/init.luau`) already walks past a `"barrel-full"` refusal for `Load`, which is what
makes a PARTIAL top-up work on a tube gun. This weapon reaches that path for the same reason the
lever does. **The design must confirm that nothing else in the reducer moves** -- and if the second
moving group (D-3) needs a wire field, say which, because that WOULD be a second change.

**D-8. THE AMMUNITION IS THE SIDE-BY-SIDE'S, AND THIS IS THE ONE PLACE SHARING IS CORRECT.** The
dispatch says *"the same buckshot/slug ammo as the side-by-side"*, and it is the same cartridge: a
12-gauge shell does not change because the gun that fires it has a gas piston.
`AMMO_KINDS = { "Slug", "Buck" }`, and the ballistics rows (`RANGE_STUDS`, `PELLETS`,
`SPREAD_FULL_DEG`, `MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD`, `ZERO_STUDS`, `GRAVITY_SCALE`) read
`Shotgun.CONFIG`'s, as the shotgun's own row does.

**This is the exact opposite of task 224's rule and the design must say why both are right.** The two
RIFLES share no number because they are different cartridges and `Rifle`'s header warns that the file
holding Karen's accepted numbers must not become the file everybody edits. The two SHOTGUNS fire the
identical shell, so a second copy of those numbers would be a second answer to *"how far does a slug
go"* -- the defect, not the protection. **Confirm or overrule**; if overruled, say which numbers
differ and on what evidence, because a 710 mm barrel against the double's is not a measurement this
repo has.

**D-9. THE RED DOT IS DRAWN, AND IT IS NOT A SCOPE.** `SIGHT = "reddot"`, **`scope = nil`** -- so
aiming takes the shotgun's path, with the gun and both gloves left in the view, and NOT the Rigby's
full-screen black mask (`docs/design/rifle.md`: the sight picture hides the gun behind it). That is
what a red dot is for, and it is Karen's own polish target: *"bead aiming with hands and no
crosshair"* (`reference-inspiration-game`).

**THE DOT IS A DRAWN EMISSIVE PIECE AND NOT THE MESH'S OWN EMISSIVE MAP, and that is a fact about
Roblox rather than a preference.** The artist ships `M_Sight01_Emissive.png`, but `SurfaceAppearance`
has **no emission channel** -- only Color, Normal, Metalness and Roughness -- so an uploaded emissive
map renders as nothing at all. The dot is therefore a small `Neon` piece placed at the sight's own
measured reticle plane, through task 143's `onlyFor` filter, which is the machinery task 148
deliberately KEPT for exactly this (`backups/2026-10-10-rifle-open-sights.md`). The design must
settle **when it is lit**: the Builder proposes only while aiming, read from the aim blend the
viewmodel already has, because a dot burning on the hip is a light source the player cannot switch
off.

**D-10. THE SOUND IS THE EXISTING SHOTGUN'S, RETUNED. No audio is uploaded.** Nobody here has heard
any of it -- the Builder cannot play audio -- so **every number in this block is one line and Karen's
ears decide**. The `shot` voice is the shotgun's own id; the `bolt` voice is the lever's clack,
shorter and higher, because a gas bolt slamming home is a lighter, faster piece of steel than a lever
throw; the `load` voice is the lever's gate click, which is already a shell-handling sample. A row
without a key is silent there (`Sound.voiceFor`), and the design should say which keys this gun
carries.

**D-11. RECOIL SOFTER THAN THE SIDE-BY-SIDE, AS DATA.** The dispatch's own call, and the physics
agrees: a gas gun spends part of the impulse cycling the action. It is the `fire` block of this
weapon's pose set (`camPitchDeg`, `gunBackStuds`, `gunPitchDeg` and their maxima), **content lane,
Karen's dial**, written only through `pose.py`'s serializer (rule J).

**D-12. THE SHOP SELLS IT AT 500, AND THE LADDER IS THE ARGUMENT.** One `Shop.ROWS` entry,
`category = "weapon"`, `grants.weapon`, `sale = true`, item id **`shotgun.semiauto`** -- so the two
shotguns sort together in any id-ordered listing, exactly as `rifle.lever` and `rifle.scoped` do.

**Proposed `price = 500`, `hunts = 8`**, placed in `Shop.ORDER` between the beater's licence (250)
and THE HIDE (575). `Shop.ORDER` is cheapest-first and `shop.spec` asserts the whole list ascends, so
that is a position and not a preference. **Why it is UNDER the lever's 650 rather than over it:** the
scarce thing in a driven hunt is REACH, and this gun does not add any -- it fires the free gun's
shell at the free gun's range. What it buys is VOLUME: five rounds instead of two and no cycle
between them. So the ladder reads free double -> 500 semi-auto (volume) -> 650 lever (reach) ->
1500 scoped rifle (precision at range), and each rung buys a different thing. Every number in the
blurb must be one this repo has measured (`Shop.Row.blurb`'s own rule): the five rounds and the
range are this weapon's config's own.

**D-13. THE LABEL MUST FIT SEVEN CHARACTERS.** `ReportPanel.DETAIL_COLUMNS`' `gun` cell is 88 px and
task 219 measured `SHOTGUN` at 46 px in that cell's own face, so the weapon row's `label` has a hard
ceiling -- "SEMI-AUTO SHOTGUN" is the SHOP row's label, not the gun's. The Builder proposes
**`label = "AUTO"`** with `"SEMI"` as the alternative. A taste call: **Karen's**, and the design
should carry both so she picks rather than discovers.

**D-14. THE HIT CARD AND THE DRIVE REPORT ARE THE SHOTGUN'S.** The pellets and the slug are the same
objects they already are. No new report path, no new decal, no new hit-zone table.

**D-15. THE ASSET PIPELINE IS THE LEVER'S, STEP FOR STEP** (rule 2), and it runs **outside the
repo**. FBX -> glTF (headless Blender, a one-off script in the runs directory, because
`tools/gltf_split.py`'s docstring promises it is stdlib-only and Blender-free) ->
`tools/gltf_split.py split` with a new named `semiauto` plan beside `MODEL_B_PLAN`, `RIGBY_PLAN` and
`LEVER_PLAN` -> `tools/asset_prep.py prep` per group -> `tools/roblox_upload.py`. The 4K and 2K maps
go down to **1024**, and the packed `Mixed_AO` is not an ORM -- the artist ships Metallic and
Roughness as separate files already, so the design should say which four maps each group actually
needs. Every group carries the WHOLE gun's bounding box through `gltf_split`'s anchor triangles, so
all six import at one size and one origin and assemble at ONE CFrame with no per-piece offset.

**D-16. SCALE: 4.9 STUDS, AND IT IS A FACT ABOUT THE GUN.** The shotgun and the Rigby are 4.4
because both are about 45 inches; this gun measures **1270 mm = 50 inches** (section 0's two
cross-checks), and at the repo's own 3.87 studs/m that is **4.91**. It is the LONGEST gun in the game
and that is true of the real one -- a 28-inch barrel on a semi-auto receiver is longer than a
45-inch double. Everything downstream is per-row data (`HANDLE_SIZE.Z`, `MUZZLE_OFFSET.Z`,
`MESH_SIZE_STUDS`) and the poses are authored fresh for this gun either way, so the length costs
nothing and buys its silhouette. **If the design judges 4.9 too long in the hand, say so and say what
it costs**, because shortening it makes the drawn gun disagree with the measurement.

---

## 2. What the design must contain

1. **The owner of every new thing**, against the *System owners* table in `GAME_DESIGN.md`: who owns
   this weapon's config, its drawn geometry, the world Tool, the shop row, the second moving group
   (D-3) and the drawn red dot (D-9). Name the file and the symbol.
2. **The module shape.** Whether the config is `src/shared/SemiAuto/` with its own `Geometry` sibling
   (the lever's and the Rigby's shape), and exactly what it may read out of `Shotgun.CONFIG` --
   D-8 says the ammunition rows and nothing else. Confirm or overrule, and write the boundary down.
3. **The second moving group, in full** (D-3): the field names, the geometry function, where the
   pivot is measured, which sequence drives it, how its progress is read, and which module may write
   it. The sign must be the geometry's, for task 188's reason.
4. **The cycle and the reload as step lists**, with the numbers and where each came from, and what
   each step does to the DRAWN gun -- the bolt's travel on `Break`/`Close`, the lifter's rise on
   `Load`, the hull that leaves and the shell that goes in. `HAND_FED_SHELLS` is a declared fact
   about the gun (task 224) and the design must state this gun's answer and why.
5. **The red dot** (D-9): the piece, its size, where its reticle plane is measured, what lights it,
   what turns it off, and whether `SIGHT = "reddot"` needs any filter beyond task 143's `onlyFor`.
6. **The hotbar order and the loadout.** Where slot 4 sits, what `Weapons.ORDER` becomes, and that
   `Weapons.PRIMARY` and a flag-off spawn stay bit-for-bit what they are.
7. **Whether this ships behind a feature flag.** The Builder's reading, and task 224's: **no new
   flag.** The gun is gated by OWNERSHIP (`OWNED_ONLY` + `Shop.ownsWeapon`), which is shipped and
   strictly stronger than a flag, and the `RIFLE` flag already decides whether any bought weapon is
   handed out. Confirm or overrule, and if a flag is wanted, say which boundary reads it.
8. **The invariants the specs must drive, one entering case per ARM** (the Learning Agent's [L-093],
   and task 224 round 2's mirrored-frame miss). The arms this weapon adds, each of which a case must
   actually ENTER rather than pass alongside: the semi-auto cycle; the bolt at full travel
   mid-cycle; the lifter at full rise during a `Load`; a PARTIAL top-up that ends early; the red dot
   lit while aiming and dark on the hip; the two-ammo readout on a magazine `READOUT`; the shop row
   and its grant; `OWNED_ONLY` keeping the gun out of an unrestricted loadout; and that no row
   carries the forbidden fields `Weapons`' header lists.
9. **The hand anchors, written so they CAN fail** (task 224's lesson, shown failing first): the
   design must publish the bounds the glove's grip point must satisfy on the wrist and on the
   fore-end, as a LINE and a radius rather than a point, so a pose that slides off the gun fails.
10. **Which `SCOPE_SPECS` scope every new or changed spec file belongs to**, and which `BLAST_RADIUS`
    entry maps this weapon's own shared folder -- standing rule G: a new spec in no scope turns CI red.
11. **What is explicitly out of scope**, so the Builder does not drift: a Robux product id, new
    audio, a new hit card, the drawn gate feed queued as 224a, and any change to
    `Match.CONFIG.SAFETY_RANGE_STUDS` (still 330, still queued as 183a(a), still a `TWO_PLAYER_PATH`).

## 3. Sources for the research note

* Baikal / Remington MP-153 owner's manual and published specification -- the 4+1 tube, the gas
  system and the barrel lengths. Cited for the gun's own numbers only.
* Hunter-Ed, "How Does a Semi-Automatic Shotgun Work?" -- the gas cycle: unlock, extract, eject,
  cock, feed, lock, as one stroke the shooter does not drive.
* Field & Stream / Shotgun Life on loading a tube-fed semi-auto -- shells pushed through the loading
  port past the lifter, one at a time, which is D-6's shape.
* Published work on gas-operated recoil reduction against a fixed-breech gun -- the evidence for
  D-11, which is otherwise only an assertion.
* In-repo prior art, which rule 2 makes the first place to look:
  `docs/design/lever-rifle.md` (the fourth row's whole shape), `docs/design/rifle.md`,
  `docs/design/shotgun.md`, `docs/research/2026-10-20-lever-action.md`,
  `docs/research/2026-10-09-rifle-scope.md`, `docs/research/2026-10-14-ballistics-lead.md`, and
  `backups/2026-10-10-rifle-open-sights.md` for the sight-filter machinery D-9 reuses.

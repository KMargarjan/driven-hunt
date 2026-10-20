# Task 224 BRIEF: the lever-action rifle

**Written by the Builder, carrying the Director (dispatch 2026-10-20 ~13:25).** The input to
`tools/architect.sh design lever-rifle --task 224`. Per `docs/ARCHITECT_PROMPT.md` this file is read
first and **overrides anything older** in `docs/`, `TASKS.md` or an earlier design.

**Karen, 2026-10-20 ~13:25, verbatim:** *"so you have things to do / deer / weapons / make it work
like we have now"*. Her standing bar: shooting, weapon and reload must be **perfect**; a
separate-part model; every frame checked against the target.

**UPLOAD OK and placement, her choice, verbatim:** *"Upload, sell in shop (Recommended)"*, answering
*"The two new guns (lever-action rifle + semi-auto shotgun): may I upload their models to Roblox
(your account, used only in this game), and how do players get them?"* So: the meshes are uploaded to
Karen's account, a row in `assets/uploads.json` carries those words, and the gun is **bought in the
shop**.

---

## 1. The decisions already taken. These are not open.

**D-1. It is a third row in the weapon system, joined exactly as the scoped rifle was** (tasks
140 / 183 / 185). Its own `Tool` and hotbar slot, its own viewmodel drawn with the same gloves, its
poses as **data** in `src/shared/Viewmodel/poses.json`, and one row in `Weapons.ROWS` built from its
own config module. No new system, no second owner: `ServerScriptService.Weapon` stays the owner of
the action and `Weapons.ROWS` stays the one table of guns.

**D-2. It is OPEN-SIGHTED. `SIGHT = "bead"`, `scope = nil`.** A lever gun on a driven hunt is an
iron-sight gun, and the machinery for this already ships and is already specced: task 143 built
`Geometry.sightKind`, `Geometry.beadOffset`, the drawn `Bead` piece's `onlyFor = "bead"` and
`ShapeRifle`'s `skipFor`, and task 148 archived the ROW while **deliberately keeping all of that**
(`backups/2026-10-10-rifle-open-sights.md`, "What was DELIBERATELY KEPT, and why"). This task is the
weapon that filter was kept for. No scope overlay, no `Rifle.Scope` table, no eyepiece, no reticle.

**D-3. THE PICATINNY RAIL STAYS ON THE GUN, and that is a measurement rather than a taste.** The
dispatch asks whether to drop it. Measured off the bought FBX (`driven-hunt-runs/t224/fbx-probe.json`,
file axes, +X the muzzle and +Z up):

| object | x (long) | z (up) | what it is |
|---|---|---|---|
| `Picatinny rail` | -0.554 .. +0.967 | +0.393 .. +0.467 | the rail over the receiver and the chamber end of the barrel |
| `Sights` | -0.403 .. -0.392 | **+0.447 .. +0.496** | the REAR sight, sitting ON the rail's top face |
| `Gun frame` | -1.189 .. +0.147 | -0.086 .. +0.429 | the receiver; its top is +0.429 |

The rear sight's base is at +0.447 and the receiver's top is +0.429, so **dropping the rail leaves
the rear sight floating 0.018 of the gun's length above the receiver** (about 4 mm at the shipped
scale) with a bare slot under it. Task 147 hit this exact trap on the Rigby and the Director
cancelled it: the scope rings were inside the uploaded action node and removing them needed
"face-level surgery and a cap in Blender rather than a different split"
(`backups/2026-10-10-rifle-open-sights.md`, "The cancelled upload"). This model is a
Ruger-made Marlin 1895 SBL, which **is sold with a rail and ghost-ring irons on it**, so the rail is
not a scope mount that wants removing -- it is the sight base, and the open sights are on it.
**It stays, and the gun still aims down its own irons** (D-2).

**D-4. Which object is the LEVER, and which is the loading gate, is settled by the geometry and not
by the names** -- the lesson `tools/gltf_split.py`'s `RIGBY_PLAN` comment writes down ("THE NODE
NAMES ARE WRONG ABOUT THE BOLT, AND THE GEOMETRY SAYS SO"). Measured:

* **`Trigger frame` IS THE FINGER LEVER.** x -1.032 .. -0.221, z **-0.270 .. +0.231**: a loop 0.81
  long hanging a quarter of the gun's depth *below* the receiver and sweeping back under the wrist.
  On a Marlin 1895 the finger lever **is** the trigger guard, so there is no separate guard object --
  and there is none in this file. The `Trigger` itself (x -0.662 .. -0.526, z +0.008 .. +0.165) sits
  inside that loop.
* **`Bolt action` is the BREECH BOLT, not the lever.** x -0.668 .. +0.048, z +0.310 .. +0.392 --
  inside the receiver at barrel height. A lever does not live up there.
* **`slide` IS THE LOADING GATE.** x -0.237 .. -0.018, z +0.207 .. +0.291, and y -0.051 .. -0.021
  -- the only object in the file that lies **entirely on one side of the centre line**. That is the
  spring cover plate on the right of a Marlin's receiver, which is what cartridges are pushed
  through.
* **`Magazine` is the TUBE under the barrel** (x +1.176 .. +2.323, z +0.201 .. +0.324), and
  `Magazine release` is its front cap and plug at x +1.594 .. +2.388 -- a Marlin has no magazine
  release, so that object is part of the tube and does not move.

**D-5. THE CYCLE IS A LEVER THROW, AND THE LEVER IS THE ONE GROUP THAT MOVES**, hinged. The drawn
weapon has exactly one moving group (`Geometry.CYCLE_GROUP_NAME` + `CYCLE_KIND`, which is "hinge" for
the shotgun's barrels and "slide" for the rifle's bolt). It is the **lever**: in first person the
signature of a lever gun is the loop swinging down and forward through a big arc, while the bolt is
hidden inside the receiver and the hammer is 458 triangles behind the rear sight. So
`CYCLE_GROUP_NAME = "Lever"`, `CYCLE_KIND = "hinge"`. The bolt and the hammer ship in the static
action group: **a bolt welded to the lever would swing in an arc below the receiver**, which is a
worse lie than a bolt that holds still.

**D-6. THE RELOAD IS SINGLE CARTRIDGES THROUGH THE GATE, AND IT ADDS NO PRIMITIVE.**
`StateMachine.apply` already has `Break` / `Load` / `Close`, and `Load` fills **one** empty chamber
from the pocket per step -- which is precisely one cartridge through one gate. With
`CYCLE_EJECTS = "spent"` the opening step throws the fired case and **leaves live rounds in the
tube**, which is what topping up a tube magazine is. So `RELOAD = { Break, Load x MAGAZINE, Close }`,
the shape the shotgun's reload already has, with the tube's count instead of two barrels.

**D-7. ONE CHANGE TO SHARED CODE, and it is forced by D-6:** `runCycle`
(`src/server/Weapon/init.luau`) walks past a refusal only for `step.kind == "Load"` with reason
`"no-reserve"`. A partial top-up -- three in the tube of five, press R -- makes the fourth `Load`
return **`"barrel-full"`**, which today aborts the sequence down its error-recovery path. A `Load`
that finds the magazine already full is **correct**, exactly as a `Load` that finds the pocket empty
is, so `barrel-full` joins that walk-past set for `Load` and nothing else. Neither shipped weapon can
reach it (the shotgun's `Break` ejects `"all"`, so both chambers are always Empty; the rifle's reload
uses `Magazine`, which fills every chamber at once), so this changes no existing behaviour -- and the
design must say that out loud, because it is the one line of this task that is not additive.

**D-8. A .45-70 BALLISTICS ROW, FITTED TO PUBLISHED FIGURES BY TASK 185'S OWN METHOD.** Hornady
LEVERevolution 325 gr FTX, the load a Marlin 1895 is sold for: 2050 fps muzzle, 1729 at 100 yd,
1450 at 200 yd, 1225 at 300 yd (24-inch barrel).

* `MUZZLE_STUDS_PER_S = { Slug = 2232 }` -- 2050 fps = 624.8 m/s at 0.28 m/stud.
* `DRAG_PER_STUD = { Slug = 5.21e-4 }` -- `v(s) = v0*exp(-k*s)` **fitted to the 100 yd point only**
  (326.6 studs), then PREDICTING 1458 fps at 200 yd against the published 1450 (**0.6 % high**) and
  1230 at 300 yd against 1225 (**0.4 % high**), with nothing fitted to either. That is the same
  one-coefficient justification `Rifle.CONFIG.DRAG_PER_STUD` carries, and it fits this cartridge
  better than it fits the .416.
* `RANGE_STUDS = { Slug = 600 }` -- 168 m, against the scoped rifle's 800 (224 m) and the slug's 330
  (92 m). The dispatch's "~150 m practical" with the margin an uphill shot needs.
* `ZERO_STUDS = { Slug = 357 }` -- 100 m, which is where an iron-sighted .45-70 is zeroed.
* `SPREAD_FULL_DEG = { Slug = 0 }`, like the scoped rifle's, and for the reason that file already
  writes down: *"a number nobody can predict is the wrong place to put character"*. The character of
  this gun is its **reach, its drop and its cycle**, not a cone.
* `GRAVITY_SCALE` -- **the one number the design must argue and Karen must settle.** The Builder
  proposes **0.35**. At full gravity this bullet is +4.1 cm at 50 m, dead on at 100 m and **-14.9 cm
  at 150 m**, which is real and is also exactly the complaint task 189 was raised for (Karen,
  2026-10-15: *"it has to be acurat 100% 100m 150m"*). 0.35 scales the whole band -- both terms are
  exactly proportional to g, which is `Ballistics.dropAt`'s own property -- to **+1.4 / 0.0 / -5.2
  cm** at 50 / 100 / 150 m, inside any zone on a boar, while the bullet still visibly falls past
  150 m where the scoped rifle's 0.12 does not. It is one line and it is hers (the same call as
  185a(h) and 189).
* `AMMO_KINDS = { "Slug" }` and the wire word stays **`Slug`**, because `Boar.Wound.damageFor`
  branches on that string; `AMMO_LABEL = { Slug = ".45-70" }` is what the Hud prints.

**D-9. FIVE ROUNDS, AND IT IS MEASURED OFF THE MODEL'S OWN TUBE.** `BARRELS = 5`, `MAGAZINE = 5`,
`READOUT = "magazine"` (the Hud prints rounds over capacity). The tube spans 1.147 of the gun's 4.905
units = 9.5 inches of a 40.5-inch rifle, which is 3.7 cartridges of 2.55 inches: **four in the tube
and one in the chamber**, which is what a 22-inch Marlin 1895 holds. Inside the dispatch's 4-6.

**D-10. THE SOUND IS THE EXISTING RIFLE'S, RETUNED. No audio is uploaded** (the dispatch's rule, and
Karen's ears decide every one of these numbers):
* `shot` -- the rifle's own `rbxassetid://9114725315` ("Gun Retort 1", ProSoundEffects, licensed
  Roblox library audio, already measured to load) at a **lower** pitch than the .416's 0.88, because a
  .45-70 is a bigger, slower, lower-pressure bore: a boom where the Rigby is a crack.
* `bolt` -- the rifle's `9117889191` at the rifle's own pitch or below rather than its 1.15: a lever
  throw is a heavier, duller clack than a bolt.
* No `magazine` voice: this gun has no magazine. The gate's cartridges are `Load` steps, so the key
  the design must settle is **which existing voice a `Load` plays on this weapon**, if any --
  `Sound.voiceFor(row, kind)` reads the row's block by key and answers nil when it has none.

**D-11. STRONG RECOIL, AS DATA.** Recoil is the `fire` block of this weapon's pose set in
`poses.json` (`camPitchDeg`, `gunBackStuds`, `gunPitchDeg` and their maxima), not code. It is
**above the scoped rifle's** (5.6 / 0.68 / 19.0), because a .45-70 in a light carbine kicks harder
than a .416 in a heavy stalking rifle. Content lane, Karen's dial.

**D-12. THE SHOP SELLS IT, through the row machinery that exists.** One `Shop.ROWS` entry,
`category = "weapon"`, a `grants.weapon` naming this weapon's id, `sale = true`, placed in
`Shop.ORDER` **between the beater's licence and the scoped rifle** -- which is the rung the archived
"RIFLE, OPEN" row occupied (`backups/2026-10-16_task-196_shop-rifle-open-row.md`: price 600, hunts
10). The dispatch asks for a price between the slug and the scoped rifle. **Proposed: `price = 650`,
`hunts = 12`** -- dearer than that archived row because this one actually ships a gun, and well under
the scoped rifle's 1500 so the ladder Karen accepted (slugs -> lever gun -> scoped rifle) still
climbs. Every number in the blurb must be one this repo already measured (`Shop.Row.blurb`'s own
rule): the 168 m reach and the five rounds are this weapon's config's own. Nothing new is invented:
`Economy.grant` and the eight readers of `grants` already answer off that field.

**D-13. THE HIT CARD AND THE DRIVE REPORT ARE THE RIFLE'S.** No new report path, no new decal, no new
hit-zone table. The bullet is one `Slug` and the existing card draws it.

**D-14. THE ASSET PIPELINE IS THE RIGBY'S, STEP FOR STEP** (rule 2), and it runs **outside the
repo**; the bought FBX is never committed and never redistributed.
FBX -> glTF (headless Blender) -> `tools/gltf_split.py split` (a new named `lever` plan) ->
`tools/asset_prep.py prep` per group -> `tools/roblox_upload.py`. The plan goes **in
`tools/gltf_split.py` beside `MODEL_B_PLAN` and `RIGBY_PLAN`**, because that file's docstring says why
plans live there ("reviewed as a diff rather than carried in a loose JSON file nobody reads").
`gltf_split` stays **stdlib-only and Blender-free**, which its docstring states as a design
property -- so the one-off FBX-to-glTF conversion is a script in the runs directory, not an import of
`bpy` into a tool that promises it has none.
* **Three groups, measured:** `action` (receiver, barrel, rail, both sights, tube, cap, fore-end,
  both swivels, trigger, hammer, bolt, gate -- worn as `Model`, the piece that must be there for the
  gun to count as dressed), `stock` (stock, butt plate, rear swivel) and `lever` (`Trigger frame`).
  Every group carries the WHOLE gun's bounding box through `gltf_split`'s anchor triangles, so all
  three import at one size and one origin and assemble at ONE CFrame with no measured per-piece
  offset -- task 96's trick, which both other guns use.
* **The frame:** forward is +X (the barrel runs to +2.446 and the butt plate to -2.459), up is +Z,
  and the model is already axis-aligned, so no Sketchfab tilt to measure out.
* **ONE MATERIAL.** All 18 objects are material `Marlin`, so the Rigby's material-1 lens refusal
  cannot arise and there is nothing to drop.
* **4K textures down to 1024** (`Marlin_Base_color`, `_Normal`, `_Roughness`, `_Metallic`), and the
  packed ORM split into the two single-channel maps Roblox reads -- `asset_prep` already does both.
* **17,485 triangles over three meshes** as bought, against the Rigby's four at 18,672 prepped. The
  design should say whether the 3,725-triangle rail is decimated; the Builder's proposal is to prep
  near-native and decimate only if a group exceeds the Rigby's own worst (8,258).

**D-15. SCALE: 4.0 STUDS, NOT 4.4, and it is a fact about the guns.** Both shipped guns are 4.4
because a Rigby stalking rifle and a 486 Parallelo are both about 45 inches. A Marlin 1895 is about
40.5 inches: 40.5 / 45 * 4.4 = 3.96. A lever carbine is **visibly shorter** and that is half of
what it looks like. Everything that follows is per-row data -- `HANDLE_SIZE.Z = 4.0`,
`MUZZLE_OFFSET.Z = -2.0`, `MESH_SIZE_STUDS` scaled by 4.0 / 4.905 -- and the poses are authored
fresh for this gun either way, so the shorter gun costs nothing and buys its silhouette.

---

## 2. What the design must contain

1. **The owner of every new thing**, against the *System owners* table in `GAME_DESIGN.md`: who owns
   the lever's config, the drawn gun, the world Tool, the shop row, and the one changed line in
   `runCycle` (D-7). Name the file and the symbol.
2. **The module shape.** Whether the config is `src/shared/Lever/` with its own `Geometry` sibling
   (the rifle's shape) or something smaller, and what -- if anything -- it may read out of
   `Rifle.CONFIG`. The Builder's reading of the repo's own rule is that it may read **nothing**:
   `Weapons`' header says the shotgun's row is built from `Shotgun.CONFIG` and `Rifle`'s header says
   it is a sibling rather than a second table inside that file precisely so "the file that holds
   [Karen's accepted numbers] must not become the file everybody edits". Confirm or overrule.
3. **The cycle and the reload as step lists**, with the numbers and where each came from. The
   Builder proposes `CYCLE = { Break 0.46, Close 0.64 }`, `CYCLE_TOTAL = 1.10` -- **faster than the
   bolt's 1.62**, which is Karen's own number from task 184, because a lever throw is one continuous
   motion of the hand already on the grip and the sources say a trained shooter cycles it while
   bringing the sights back; and **slower than the 0.62 the bolt first shipped at**, which read as
   too fast on screen. And `RELOAD = { Break 0.40, Load 0.42 x 5, Close 0.40 }`,
   `RELOAD_TOTAL = 2.90` -- slower than the rifle's 1.97 s magazine change, which **is** the trade a
   tube magazine makes. Both are dials.
4. **What `Load` does to the drawn gun on this weapon**, because the shotgun's `Load` draws a shell
   going into a broken-open breech and this one is a cartridge going into a gate on the right flank
   of a closed receiver. This is the pose set's `cycle.load` / `cycle.hand` / `cycle.shell` blocks,
   and the design must say which of them this gun needs and what moves.
5. **The hotbar order and the loadout.** Where slot 3 sits, what `Weapons.ORDER` becomes, and that
   `Weapons.PRIMARY` and a flag-off spawn stay bit-for-bit what they are.
6. **Whether this ships behind a feature flag.** The Builder's reading: **no new flag.** The gun is
   gated by OWNERSHIP (`Shop.ownsWeapon`), which is a shipped mechanism and strictly stronger than a
   flag -- nobody who has not bought it can hold it -- and the `RIFLE` flag already decides whether
   any bought weapon is handed out at all. A flag whose two states are "a shop row exists" and "a
   shop row does not" is the map-switch mistake (CLAUDE.md: a switch that cannot be switched off is
   not a feature flag). Confirm or overrule, and if a flag is wanted, say which boundary reads it.
7. **The invariants the specs must drive**, and for each one the case that **enters this weapon's own
   branch** rather than a case that would also pass on the scoped rifle (the Learning Agent's
   [L-093]): the cycle's two steps and their total, the magazine count and the tube's partial top-up
   (D-6/D-7), the ballistics row's required fields, `SIGHT = "bead"` drawing no scope, the shop row
   and its grant, and that no row carries the forbidden fields `Weapons`' header lists.
8. **Which `SCOPE_SPECS` scope every new or changed spec file belongs to**, and which `BLAST_RADIUS`
   entry maps this weapon's own shared folder -- standing rule G: a new spec in no scope turns CI
   red.
9. **What is explicitly out of scope**, so the Builder does not drift: the semi-auto shotgun (task
   225), a Robux product id, new audio, a new hit card, and any change to
   `Match.CONFIG.SAFETY_RANGE_STUDS` (still 330, still queued as 183a(a), still a
   `TWO_PLAYER_PATH`).

## 3. Sources for the research note

* Hornady LEVERevolution .45-70 325 gr FTX factory ballistics -- Midwest Gun Works' and Gunners Den's
  published tables (2050 / 1729 / 1450 / 1225 fps). Retail spec sheets, not a library: cited for the
  cartridge's numbers only.
* Gun Digest, "Cowboy 101: How To Run A Lever-Action Rifle" -- the lever's throw and how it is worked
  under the sights.
* Hunter-Ed, "How Does a Lever Action Rifle Work?" -- the eject/feed/cock sequence of one throw.
* Ranger Point Precision, "Tips on How to Hold, Aim, and Shoot a Lever-Action Rifle" -- that a
  shorter lever throw raises the practical rate, which is what D-5's 1.10 s is measured against.
* In-repo prior art, which rule 2 makes the first place to look:
  `docs/research/2026-10-09-rifle-scope.md`, `2026-10-10-rifle-bolt-magazine-sound.md`,
  `2026-10-14-ballistics-lead.md`, `2026-10-15-rifle-right-hand.md`, and
  `backups/2026-10-10-rifle-open-sights.md` for the open-sight machinery this task reuses.

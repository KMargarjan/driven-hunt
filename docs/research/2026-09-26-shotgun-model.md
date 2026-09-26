# Research: the shotgun's look, built from Parts

Task 71. Written before the code (rule 1). Network was available in this session and every source
below was fetched in it, on 2026-09-26; where a page would not render to a fetcher, that is said.

## What the system must do

Replace the shotgun's grey-box look -- one wooden box, `Shotgun.CONFIG.HANDLE_SIZE`
(0.4 x 0.5 x 4.4 studs) -- with something a player reads, at arm's length in third person and at
the eye in ADS, as **Karen's gun**: a side-by-side, walnut and blued steel, "not overly detailed"
(`docs/asset-briefs/shotgun.handle_v2.brief.json`).

Constraints that decide the answer before any source is read:

1. **`.rbxm` and `.rbxmx` are banned** (CLAUDE.md, Layout): binary, unreviewable in a PR, and CI and
   the harness both fail on one. So a downloaded model, free or paid, cannot enter this repo as a
   file.
2. **Typed property values in `.model.json` are refused by the harness** (`Vector3`, `Color3` --
   CLAUDE.md, "File types in Rojo-owned paths"; `docs/design/shotgun.md` section 3.1 makes the same
   point). So the gun cannot be a `.model.json` tree either.
3. **`Weapon.Hardware` is the only writer of `Tool` Instances** (GAME_DESIGN.md owners;
   `docs/design/shotgun.md` section 3.1), and **`Camera.Viewmodel` clones that Tool's `Handle` and
   never writes the original** (`docs/design/camera.md` section 3.2). Whatever the gun is made of has
   to arrive through Hardware and survive being cloned, or the first-person gun and the third-person
   gun are two different objects -- the "two correct pieces of code disagreeing" failure
   `docs/PROJECT_CONTEXT.md` exists to prevent.
4. **Two Meshy text-to-3D previews (40 credits) both came back wrong** -- runs
   `shotgun.handle_v1-20260926T1850Z` and `shotgun.handle_v2-20260926T1917Z`: an over-under with
   short barrels and a pistol grip, twice, from two different prompts (`TASKS.md` row 70). The
   Director looked at both and stopped spending credits on text for this model.

So: **the gun is built from Parts, in code, by `Hardware.build()`**, from numbers in a frozen config
-- which is the same conclusion `docs/design/shotgun.md` section 3.1 already reached for the grey
box, and the same one `src/server/TestArena.luau` and `src/server/Boar/Body.luau` reached for their
shapes. This note is about *how a firearm is shaped out of boxes*, and *what the real gun's
proportions are*.

## Sources

### 1. Roblox Weapons Kit (first-party reference implementation)

<https://github.com/Roblox/creator-docs/blob/main/content/en-us/resources/weapons-kit.md>

**Licence:** "The content of this project and documentation can be used under Roblox's
[Limited Use License]" (quoted from the page). **Maintenance:** part of `Roblox/creator-docs`, the
live documentation repository; actively maintained.

**Good:** it is the platform owner's own answer to this exact question, and its shape is the one this
repo already has. A weapon is a `Tool` whose visible gun is "a `Model` made up of one or more
`BaseParts` ... with one designated as the `PrimaryPart`", plus a **`HandleAttachment`** ("determines
where the tool's handle is welded") and a **`TipAttachment`** ("where projectiles originate"). Our
`Handle` plus `Muzzle` attachment is that pattern with the parts missing.

**Bad:** it ships as a Studio model, not as source, so nothing in it can be copied into this repo;
and it is built for "competitive combat-based games" with projectile weapons, not for a break-action
hunting gun -- there is no side-by-side in it.

**Adopted:** the structure -- one Tool, one Handle, the rest of the gun as welded `BasePart`s, and
the muzzle as an Attachment rather than a number re-derived per call site (which section 8 of the
design already says).

### 2. Roblox "Assemblies" (first-party engine documentation)

<https://create.roblox.com/docs/physics/assemblies>

**Licence:** the `Roblox/creator-docs` source is CC BY 4.0. **Maintenance:** actively maintained.

**Good:** says exactly what a welded multi-part gun *is* to the engine -- "An assembly is one or more
parts welded by a rigid WeldConstraint or connected through movable joints, like Motor6Ds", and such
an assembly behaves as one rigid body where "no force can push or pull the connected parts from each
other". It also gives the root-part rule -- anchored first, then "Parts with Massless set to false
(default) take precedence" -- which is why every decorative piece here is `Massless = true`: the
`Handle` must stay the root, or the Tool's grip weld moves to a barrel.

**Bad:** it is about physics, and says nothing about Tools, grips, or what happens to a joint created
before the parts are in the DataModel.

**Adopted:** every added part is `Massless = true`, `CanCollide = false`, and rigidly joined to the
`Handle`.

### 3. `JonathanKwak/gun-system` (open-source Roblox gun system)

<https://github.com/JonathanKwak/gun-system>

**Licence:** MIT (stated in the repository). **Maintenance:** 13 commits, the author describes the
code as written "1-2 years ago"; effectively unmaintained.

**Good:** confirms the community's shape is ours -- guns are Tools with a `Handle`, the gun's look is
"the tool's handle/looks", and the muzzle is "an attachment into one of the parts of the guns".

**Bad:** it is a *system* (firing, ammo, recoil), all of which this repo already owns and none of
which may be taken: its model is client-authoritative and `docs/design/shotgun.md` section 1.2 is
explicit that the server decides every hit. Nothing is borrowed from it but the confirmation.

### 4. "[Open-Source] Low Poly [Weapons & Terrain]" (community assets)

<https://devforum.roblox.com/t/open-source-low-poly-weapons-terrain/244201>

**Licence:** none stated. The author writes "This is for the use of anyone" and asks for credit
("I would appreciate it though"), which is **not** a licence grant this project can rely on.
**Maintenance:** posted 2019-02-23, last updated 2019-03-01; dead.

**Good:** it is the honest sample of what "open-source low-poly Roblox weapons" actually are -- a
pickaxe, a katana and a sabre, shipped as `.rbxm` and `.obj`.

**Bad:** both of those formats are unusable here (constraint 1 above), the licence is a forum
sentence, and there is no shotgun in it.

**Not adopted**, and it is the reason the *borrow* in "borrow before building" is the **pattern**
(sources 1-2) and not a model file: there is no part-built side-by-side under a usable licence to
take. That is the written reason rule 2 asks for.

### 5. Beretta 486 Parallelo -- the published dimensions

<https://www.gunmart.net/gun-reviews/shotguns/side-by-side-shotgun/beretta-a486-parallelo>

**Licence:** editorial review, quoted for **numbers only**. Nothing about the gun's engraving,
lettering, logo or trade dress is copied, and none is modelled -- the brief already forbids text and
maker marks, and at this scale a scroll pattern is invisible anyway.
**Maintenance:** a review of a current production model; the numbers are the manufacturer's.

**Good:** the only source found that publishes the **overall length**: barrel "28-inch", overall
"45.0-inches", length of pull "14.5-inches", weight "7.5lbs", "8mm concave rib with smooth surface",
"Single" trigger, "round bodied action design".

**Bad:** one editorial source for the overall length -- `beretta.com`'s own product page is
JavaScript-rendered and returned nothing to a fetcher, twice (both the
`/en/product/486-parallelo-P0024` and `/en-us/product/486-parallelo-FA0001` URLs), so the 45.0"
figure is corroborated only by the arithmetic below. A `projectupland.com` review of the same gun
answers HTTP 403 to every tool.

**Sanity check that it holds together:** 28" barrel + 14.5" length of pull = 42.5", leaving 2.5"
from the breech face to the trigger -- about right for a break action, so the three numbers are
consistent with each other and with a 45" gun.

## The pattern adopted, and why

**A pure piece list plus one builder** -- the division this repo already uses twice: `MapGen.Layout.furniture`
returns pieces as data and `MapGen.Props.furniture` builds what it is handed (Task 66); `Boar.Body`
builds welded, massless, non-colliding parts on an existing root part (Milestone 1.5).

- `src/server/Weapon/Shape.luau` -- **pure**, private to the weapon system, no Instance work: it
  returns every piece of the gun as `{name, size, offset (a CFrame relative to the Handle), color,
  material, shape}`. A spec asserts the **proportions** against the published numbers above with no
  Tool, no character and no physics.
- `Weapon.Hardware` -- unchanged in role: still the only writer of `Tool` Instances. It builds the
  `Handle` exactly as before, then builds the list and welds each piece to the `Handle`.
- `Camera.Viewmodel` -- unchanged in role: still clones the `Handle` and never writes the original.
  It has to stop destroying the Handle's `BasePart` children (it currently destroys every child that
  is not an `Attachment`), or the first-person gun would be the bare envelope box while the
  third-person gun is the real one. **One source, two views**, which is what the task asked for.

**Joints: legacy `Weld` with an explicit `C0`, not `WeldConstraint`.** `Boar.Body` uses
`WeldConstraint` and its own comment says why that works there: "The trunk must already be in the
DataModel: a WeldConstraint needs both parts parented." `Hardware.build()` returns a Tool that is
**not** in the DataModel -- `Hardware.give()` parents it later -- so a `WeldConstraint` created at
build time has nothing to bind. A `Weld` carries the offset as data (`Part0`, `Part1`, `C0`), so the
geometry is *derived from the number in the config* rather than *remembered from wherever the parts
happened to be*, which is also the more diffable of the two. Welds are parented to the `Handle`,
which is the documented convention (source 2's assembly, and the devforum consensus that a weld
parented outside the tool simulates separately).

**`CanQuery = false` on every decorative piece.** This task is appearance only, and the weapon's
raycast surface must not change: the `Handle` stays the one queryable part of the gun, exactly as
today. Without this, ten new boxes on *another* player's gun become ten new things a slug can stop
against -- the same class of defect as Task 68's furniture, from the opposite direction.

## The numeric targets

Everything is a proportion of the published gun, applied to the length this repo already has.
`Shotgun.CONFIG.HANDLE_SIZE.Z = 4.4` studs is the gun's total length and **does not change**: it is
what `MUZZLE_OFFSET = (0, 0, -2.2)` and `GRIP` are built on. At Roblox's documented 1 stud = 0.28 m
that is 1.23 m against the 486's 1.143 m, so **this gun is about 8 % oversize** -- an existing
choice, recorded here rather than silently corrected, because changing it moves the muzzle and the
grip and this task is appearance only.

| Quantity | Published | Fraction of 45" | Studs (x 4.4) |
|---|---|---|---|
| Overall length | 45.0 in | 1.0 | 4.40 |
| Barrels | 28 in | 0.6222 | **2.74** |
| Breech face to trigger | 2.5 in (45 - 28 - 14.5) | 0.0556 | **0.24** |
| Length of pull (trigger to butt) | 14.5 in | 0.3222 | **1.42** |

Laid out along the Handle's own axis, where **-Z is the muzzle** (`docs/design/shotgun.md`, the
`GRIP` row) and z = 0 is the Handle's centre: the barrels span z = -2.20 to +0.54, the trigger sits
at z = +0.78, the butt plate is at z = +2.20.

Shape targets that are **not** from the spec sheet, and are the Director's pick, changeable (Karen's
rule, 2026-09-26 -- styling never blocks):

- **Two barrels side by side**, cylinders so the muzzle end reads as two circles rather than two
  squares, ~0.17 studs across each, centres about 0.09 studs either side of the axis: roughly twice
  life size in diameter, because 12-gauge tubes at true scale are 0.08 studs and would not read at
  all.
- **Drop at heel**: the straight English stock is one box rotated a few degrees nose-up, putting the
  butt below the barrel line; the real gun's drop at heel is about 2.25 in over a 14.5 in pull,
  or 8.8 degrees.
- **A splinter forend**: slim and short, under the barrels, walnut -- as opposed to the "wide, semi
  beaver tail" the reviewed gun wore; Karen's brief asks for the splinter.
- **A flat top rib** between the barrels. The real gun's is an "8mm concave rib"; at 0.03 studs thick
  the concavity is below one pixel, so it is a flat strip with a bead at the muzzle end.
- **Part budget: 10 decorative parts** (two barrels, rib, bead, action, top lever, forend, stock,
  trigger guard, trigger) plus the `Handle`, which becomes invisible and stays the grip and the
  muzzle's anchor. Eleven parts per gun, one gun per shooter, at most 16 players.

## What this note does not answer

- Whether the proportions *read* as a side-by-side on screen is rule 5's question, not arithmetic's:
  screenshots in third person and in ADS, looked at, are part of the task.
- The colours are a first pick and Karen's to change; they are config rows, not literals.
- Nothing here brings back the Meshy route. If a mesh is ever wanted for this gun, the lesson from
  the two failed runs is that **text alone did not produce a side-by-side**, and the next attempt
  should be image-to-3D from a reference the Asset agent is given -- a Director decision with a
  credit cost, not this task's.

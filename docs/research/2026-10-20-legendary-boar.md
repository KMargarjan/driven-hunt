# Legendary animals: one rare, big, tough boar per drive

Task 219. Karen, 2026-10-10 ~22:30: *"Legendary animals: one or a few, e.g. a legendary boar"*.
Karen, 2026-10-11: *"money for each boar shot (small amounts), a first-place bonus, legendary animals
worth more"*. Task 160 already wrote the price -- `Match.CONFIG.POINTS.KIND.legendary = 25` -- as **a
data row with no animal behind it**, and its own comment promised *"the row is live the instant a
kind by that name dies"*. This is that day.

## What the system must do

1. **One animal, rarely.** At most ONE legendary per drive, and not every drive. A trophy you meet
   every ten minutes is not a trophy.
2. **Clearly bigger**, measured against the male rather than eyeballed, and bigger in the HIT BOXES
   as well as in the picture -- this game's own rule since task 119 (*"one scale, every box"*).
3. **Visibly special without being cartoonish.** Darker and grizzled, which is what an old boar
   actually is; no new asset, no upload -- the same bought model.
4. **Harder to kill**, reasoned from the hit zones that already exist and not from a second health
   pool bolted on beside `Boar.Wound`.
5. **Wary**: it notices further out and runs faster.
6. **Named everywhere a kill is shown**: the hit card and the TAB drive report (the start card
   turned out to be full -- see below).
7. **Worth more**: the existing `POINTS.KIND` row and the existing coins-per-point rule, with no
   second price.

## Sources

### A. Bundesjagdverband (DJV) on the boar's `Schild`

*Schwarzwild* literature is unanimous that a mature male grows a **`Schild`** ("shield"): a plate of
hardened connective tissue over the shoulders and flanks, centimetres thick on an old keiler, which
is exactly the part of the animal a flank shot has to pass through.
<https://www.jagdverband.de/wild-und-natur/wildtierportraits/wildschwein> (the DJV's own wild boar
portrait; maintained, the association's standing reference). The hunting rule that follows from it is
also unanimous and is the one this task needs: **the shot is taken at the chamber or the head**, and a
body shot on an old keiler is the shot that loses the animal. The same body is already the source of
`Boar.CONFIG.MODEL.DISPLAY_ROLL_DEG`'s *Streckelegen* number, so it is a source this project reads.

* **Does well:** it says the toughness is NOT uniform. The skull and the chamber of an old keiler are
  no harder than a young one's; the bulk around them is far thicker. That is a per-ZONE statement,
  which is the shape `Boar.CONFIG.WOUND.DAMAGE` and `CLASS` already have.
* **Does badly:** no numbers a game can use. Nothing says "twice".

### B. ioquake3, `g_combat.c` -- GPL-2.0, archived, the canonical id Software release

The repository this project already borrows from (the beater rule in
`docs/research/2026-10-12-scoring.md` is `g_team.h`'s). Quake 3's armour is the prior art for "the
same weapon, less damage" and it is a **fraction applied at the point of damage**, never a second
pool: `ARMOR_PROTECTION` takes a share of the damage and the rest goes through.
<https://github.com/ioquake/ioq3/blob/master/code/game/g_combat.c>

* **Does well:** it is a MULTIPLIER on incoming damage, not a bigger health pool. That matters here:
  `Boar.Wound` is two quantities (damage toward LETHAL, and flight studs) and a bigger pool would
  silently make every wounded legendary run FURTHER, because `Wound.flightStuds` tapers the run by
  how far past MORTAL the damage is. Scaling the damage instead leaves that taper's shape alone.
* **Does badly:** it is uniform over the whole body, which source A says is wrong for this animal.
* **Maintenance:** archived upstream; the file is stable, and it is quoted rather than depended on.

### C. theHunter: Call of the Wild / Monster Hunter -- rare-spawn rates

The genre's own answer to "how rare is a trophy". *theHunter: Call of the Wild*'s Great One spawns
are documented by its community as a per-population roll in the low percent; Monster Hunter's
"tempered" variants are a per-quest roll. Neither publishes a figure the developers wrote down.
<https://thehunter.fandom.com/wiki/Great_One> (community wiki; maintained, no licence stated)

* **Does well:** it confirms the SHAPE -- one roll per session, capped at one animal, rather than a
  chance per spawn that could produce two.
* **Does badly:** **this is a recorded NEGATIVE result for the NUMBER.** No figure from it is used:
  the percentages there are player-estimated and the page says so. The rate below is reasoned from
  this game's own drive length instead. (This is the same discipline
  `docs/research/2026-10-12-scoring.md` applied to the same game's rating page.)

### D. Roblox `Model:ScaleTo` and skinned meshes -- the engine's own documentation

<https://create.roblox.com/docs/reference/engine/classes/Model#ScaleTo> and
<https://create.roblox.com/docs/art/modeling/rigging>

* **Does well:** `ScaleTo` is documented to scale a model *and its descendants*, joints and
  attachments included.
* **Does badly:** it does not say what happens to a skinned rig's BONES, or to an animation's
  absolute translations, which is the whole question here -- so both were MEASURED (below).

## The pattern adopted, and why

**The legendary is a FOURTH ROW in `Boar.CONFIG.KINDS` and nothing else.** Task 119 built the kinds
mechanism as "a row plus an `ORDER` entry", and task 116 added the `rear` zone the same way
(*"IT IS ADDED THE WAY EVERY ZONE EXISTS AND IN NO OTHER WAY"*). Almost everything this task needs is
a field on that row:

| field | value | why |
|---|---|---|
| `scale` | 1.35 | every box: the trunk and all four hit zones, as task 119's "one scale, every box" |
| `clipScale` | 1.35 | **MEASURED** (below): the scaled rig's feet carry 1.35x the male's stride |
| `model` | `"male"` | the SAME bought asset. No upload, no new id |
| `meshScale` | 1.35 | how much the drawn rig is scaled at runtime -- the one new field |
| `deathLiftStuds` | 0 | **MEASURED** (below): the scaled rig's held death pose is on the ground |
| `tint` | RGB(70, 58, 48) | the `SurfaceAppearance.Color` the bought coat is multiplied by |
| `toughness` | 2.0 | source A + source B: see "Harder to kill" |
| `wary` | notice x1.4, run x1.12 | see "Wary" |

### Bigger: `Model:ScaleTo`, and `MeshPart.Size` is the trap

`Boar.Body`'s header has said since task 115 that *"the scale has to be baked into the upload:
`Size` and `Model:ScaleTo` move the mesh and not the bones, which tears the animal as soon as a clip
plays"*. **Half of that sentence is right and half of it is wrong**, and this task measured which
half, because the whole design rests on it. DEV place, 2026-10-20, on the real published male
(`boar.male` v3, modelId 120607820179994), reading `Bone.WorldPosition` in the mesh's own object
space:

| | mesh `Size.Y` | lowest bone, local Y | `hoof_f.L` local Z |
|---|---|---|---|
| as loaded | 3.2573 | -1.6264 | -0.7206 |
| after `mesh.Size = Size * 1.35` | 4.3974 | **-1.6264** | **-0.7206** |
| after `model:ScaleTo(1.35)` | 4.3974 | **-2.1957** | **-0.9728** |

`-2.1957 / -1.6264 = 1.3500` and `-0.9728 / -0.7206 = 1.3500`, exactly. So **`MeshPart.Size` scales
the drawn mesh and leaves the skeleton where it was** -- which is the tear the old comment describes
-- while **`Model:ScaleTo` scales the skeleton with it**. The old sentence is not corrected out of
spite: it was written when the animals in front of it were a sow and a cub, which had to be baked
anyway because they are *different animals* and not the male at another size. `ScaleTo` alone was
never measured. It is now, and the comment in `Body.luau` says so.

### ...and the clips scale with it, which is the half that decides `clipScale`

A KeyframeSequence's rotations are scale-free but its **translations are absolute studs** -- the fact
`tools/boar_prep.py` records, and the reason `deathLiftStuds` exists at all. So the question is
whether a scaled model's Animator scales them. MEASURED in a **Play** session -- the clips report
`Length = 0` in Edit, because the asset is never fetched there, so an Edit-mode measurement of a clip
is worth nothing and this task's first one was thrown away -- on the published walk clip
(78821328262922) and death clip (128792697872198), sweeping 41 samples across each clip and reading
every bone each frame:

| | walk, `hoof_f.L` Z travel | death held at `Length - HOLD_EPSILON`, lowest bone above the box's bottom plane |
|---|---|---|
| male, unscaled | 1.6409 | +0.0022 |
| the same rig at `ScaleTo(1.35)` | **2.2152** | **+0.0030** |

`2.2152 / 1.6409 = 1.3500`. **The feet carry exactly 1.35x the distance**, so `clipScale = 1.35` --
the same number as `scale`, which is what "the male at another size" ought to mean, and which is what
makes `Body.gaitBands` give this animal a longer stride and a higher gait-change speed. The held
death pose stays on the ground (+0.0030 against the male's own +0.0022), so `deathLiftStuds = 0`, the
male's own row: no fourth measurement of a per-bone fall is needed, because this rig IS the male's
rig.

### ...and ONE rail had to move, and it is arithmetic and not taste

`Body.gaitBands` gives every animal `maxRate = MODEL.MAX_RATE / clipScale`. Its own derivation
(task 119, review round 2) is *"the ceiling is above everything the game can ask for"*: a cub's
stride is 0.4372 of the male's, so the same cadence ceiling in a cub's units is 2.8 / 0.4372 = 6.40.
**Dividing is only safe below 1.** The worst rate the game can ask for is the TROT clip at the top of
its own band, and that ask is scale-INVARIANT, because the band edge scales with the stride:
`RUN_FROM * s / (10.244 * s) = 2.733` for every `s`. So at `s = 1.35` the ceiling would be
2.8 / 1.35 = **2.074** against an ask of **2.733** -- a third of the animal's feet sliding at the top
of the trot band, which `tests/server/boar_kinds.spec.luau`'s sweep would (correctly) fail.

The rail is therefore `MODEL.MAX_RATE / math.min(clipScale, 1)`: **unchanged for every kind that
exists** (male 2.8, female 3.27, cub 6.40 -- that spec asserts two of those three by number) and the
male's own 2.8 for anything bigger, which clears 2.733 with the margin he already has.

### Darker: the coat's own `SurfaceAppearance`

MEASURED on the loaded asset: the mesh is a single `MeshPart` (`BoarMale_NoAlpha`, 40 bones) carrying
**one `SurfaceAppearance`** (`ColorMap` rbxassetid://140199537340988) whose `Color` property exists
and reads `(1, 1, 1)`. So the tint is a multiply on the coat the artist drew -- not an overlay part,
not a second texture, and not a `MeshPart.Color` write, which a `SurfaceAppearance` ignores.
RGB(70, 58, 48) is a dark warm brown: it takes the bought coat to about a quarter of its brightness
and slightly off its red, which is what an old grizzled keiler reads as. **It is one number and it is
Karen's dial.**

**What could NOT be done, said plainly: the tusks.** The rig is one skinned mesh with no separate
tusk geometry, and the tusks are painted into the `ColorMap` -- so "pale tusks a bit longer" cannot
be reached by any colour or any scale. It needs either a second mesh welded at the jaw or a reworked
upload, which is an asset task and not this one. The animal is 35 % bigger, so its tusks are drawn
35 % bigger with it, and that is the whole of what this task delivers on that point.

### Harder to kill: the `Schild`, as a per-CLASS multiplier

Source A says the skull and the chamber of an old keiler are no harder and the bulk around them is
far thicker. `Boar.Wound` already knows which is which: `config.CLASS` names `head` and `chest`
`vital`, and `body`, `legs` and `rear` are not. So:

> **A legendary's VITAL zones take full damage. Every other zone takes damage divided by
> `toughness`.**

At `toughness = 2`, read off the table this game already has (`LETHAL` 100, `MORTAL` 50):

| shot | a male | a legendary |
|---|---|---|
| one head slug (100) | **lethal**, drops on the spot | **lethal**, drops on the spot |
| one chest slug (100) | **lethal** | **lethal** |
| three head pellets (3 x 34) | lethal | lethal |
| two chest pellets (2 x 25) | mortal, 0 studs of flight | mortal, 0 studs of flight |
| one body slug (55) | **mortal** -- 108 studs and down | **grazed**. It runs off well |
| two body slugs | lethal | mortal, 108 studs |
| one rump slug (55) | **mortal + crippled** -- the back end goes | **grazed**. It keeps its legs |
| one leg slug (30) | grazed | grazed |
| five body pellets (5 x 11) | mortal | grazed -- it takes ten |

That is exactly Karen's own second option -- *"only head/chest zones kill"* -- arrived at from the hit
zones rather than declared: **the vitals kill it the way they kill anything, and nothing else does on
one shot.** It is one number on one row, so Karen can turn it, and both states stay reachable by
parameter, because `toughness = nil` IS every animal in the game today.

Rejected: **a bigger `LETHAL` / `MORTAL` for this animal.** It scales the span `MORTAL..LETHAL` that
`Wound.flightStuds` tapers the run across, so a legendary would also run further for the same
*fraction* of a mortal wound -- a second behaviour change nobody asked for, hidden inside a number
that looks like it only means "tougher".

### Wary: two multipliers on the one function each answer already lives in

`Brain` has exactly one reader of each fact -- `Brain.noticeRadius` / `Brain.fleeRadius` for "how far
away does it react", and `Brain:_runSpeed()` for "how fast does it run", whose own comment says
*"One function, so the bolt, the hit and the pace clamp cannot disagree about what running is"*. So
the legendary does not get a second rule; it gets **its own `config`**, built once at the spawn by a
new pure `Boar.kindConfig(kind, config)` and handed to `Brain.new` the way `self._field` already is
(*"an already-spawned boar keeps the field it was born with"*).

`kindConfig` **returns the config table ITSELF** for every kind with no `wary` row -- not a copy --
so for the male, the sow, the cub and the whole flag-off world it is the identity function, and
nothing can drift.

* `noticeScale = 1.4`: 40 studs becomes 56, and the standing flush radius and the dog scale with it.
  An old boar is the animal that is never there when you arrive; 1.4 puts it off its feet while a
  hunter is still beyond the sow's own radius, without taking it outside the drive corridor.
* `runScale = 1.12`: 38 studs/s becomes 42.6. Big enough that a hunter who has watched the sounder
  run can tell this one is faster; small enough to stay inside the rate rail above (1.83 against the
  2.8 ceiling).

### Rare: one roll per drive, one animal per drive

* **`CHANCE_PER_DRIVE = 0.25`** -- one drive in four. Reasoned from THIS game, because source C is a
  negative result: a drive is 10 minutes and a session is a handful of drives, so at 1 in 4 a player
  meets one in about forty minutes of play and a full evening carries two or three. At 1 in 10 most
  sessions would have none and the animal would be folklore; at 1 in 2 it is just the big boar.
  **One number, Karen's to turn.**
* **`MAX_PER_DRIVE = 1`**, and it is structural rather than a count that could drift: the Runtime
  draws the roll **once**, on the first release of a drive, and clears the permission the instant one
  is promoted. `Runtime:clear("driveOver")` -- which `Match` already calls at the end of every drive
  -- is where both are reset.
* **It is always a MALE that is promoted.** A legendary is a mature lone boar (`SOUNDER.MAKEUP.LONE`
  is already `"male"`, and `COMPOSITIONS` row 6 is *"a lone big male, which is what a mature boar
  actually is"*). `Boar.promoteLegendary` promotes the FIRST male in a release and no one else; a
  release of sows and piglets promotes nobody and the drive's permission is still unspent, so the
  next release that carries a male carries the trophy.

## Numeric targets

| target | value | where |
|---|---|---|
| size against the male | 1.35x, every box and the drawn rig | `KINDS.legendary.scale`, `.meshScale` |
| stride | 1.35x, MEASURED | `KINDS.legendary.clipScale` |
| carcass lift | 0 studs, MEASURED | `KINDS.legendary.deathLiftStuds` |
| coat | RGB(70, 58, 48) on the existing `SurfaceAppearance` | `KINDS.legendary.tint` |
| non-vital damage | / 2.0 | `KINDS.legendary.toughness` |
| notice / flee radius | x1.4 (40 -> 56 studs) | `KINDS.legendary.wary.noticeScale` |
| run speed | x1.12 (38 -> 42.6 studs/s) | `KINDS.legendary.wary.runScale` |
| chance | 1 drive in 4 | `KINDS.LEGENDARY.CHANCE_PER_DRIVE` |
| cap | 1 per drive | `KINDS.LEGENDARY.MAX_PER_DRIVE` |
| points / coins | 25 points, 50 coins | `Match.CONFIG.POINTS.KIND.legendary` (task 160), `Economy.CONFIG.COINS_PER_POINT` |
| rate rail headroom at 1.35 | a 2.733 ask against a 2.8 ceiling | `Body.gaitBands` |

## What the screens say, and the two widths that decided it

`Report.kindWord` already returns an unknown kind **as it came** (*"a kind nobody has a word for is
still a fact about the animal that died"*), so `"legendary"` needs no mapping: the TAB report's ANIMAL
column prints `LEGENDARY` with no change to that function at all. What DID need measuring is whether
it FITS, because `Style.cell` truncates at the end and a clipped word is a defect no spec can see.
MEASURED with `TextService:GetTextBoundsAsync` in a Play client, in the two faces the two screens
actually use:

| string | face | measured | the box |
|---|---|---|---|
| `LEGENDARY` | Oswald Medium 17 (a report cell) | **55.0 px** | the ANIMAL column was **56** |
| `MALE` / `FEMALE` / `PIGLET` | the same | 24 / 34 / 31 | 56 |
| `SHOTGUN` / `RIFLE` | the same | 46 / 25 | the GUN column is 110 |
| `HIT - BUCKSHOT 4/9` spaced | BuilderSans Bold 10 (the hit card) | 117.0 px | the label is **164** |
| `LEGENDARY - BUCKSHOT 4/9` spaced | the same | **167.0 px** | 164 -- **it does not fit** |
| `LEGENDARY BOAR` spaced | the same | 104.0 px | the plate is 164 |

Two decisions fall out of those numbers:

1. **The ANIMAL column goes 56 -> 78 and the GUN column 110 -> 88.** `LEGENDARY` at 55.0 px in a
   56 px cell is a one-pixel margin, and this panel's own spec exists because eight columns *"tuned
   by eye"* ran POINTS 14 px past the well. 78 gives the longest animal word the proportional
   headroom `SHOTGUN` already has, and 88 still clears `SHOTGUN`'s 46 px twice over. The columns
   still add up to `WELL_INNER` and the spec still proves it.
2. **The hit card names the animal on the PLATE, not in the headline.** `HIT - <ammo> n/m` is the
   headline and it cannot carry six more characters -- 167 against 164 -- so a legendary gets one
   extra micro-label on the bone plate the animal is printed on, reading `LEGENDARY BOAR` at 104 px
   inside 164. It is drawn ONLY for a legendary, so every other shot's card is the card Karen has
   already seen, pixel for pixel.

### THE START CARD IS FULL, and that is the one thing this task could not deliver

The brief asked for the trophy to be named where a kill is shown, and the obvious fourth place is the
start card's quarry list. **It does not fit, and the reason is a Designer decision with its own
sentence on it:** `Drive.CONFIG.START_CARD_ROWS_MAX` is **4** -- *"ONE IDEA PER LINE, AND FOUR LINES
IS THE CEILING for a three-second read ... which is why there is no fifth row and no second layout"*
-- and the four are male, female, piglet and the **person** row the Designer added
(*"`SAFETY_PENALTY = -10` and a tie to a tree is a real rule the card never mentioned"*). The card's
height is a fixed number, and `Hud`'s own loop stops at the cap: a fourth quarry kind would have
**silently pushed the person row off the card**, with nothing erroring and no spec failing.

So `Match.CONFIG.QUARRY` keeps its three kinds, and the reason is written on that table. A fifth row
(or a merged one) is the Designer's call and is queued. `tests/server/boar_legendary.spec.luau`
asserts the absence -- `quarryKinds + 1 == START_CARD_ROWS_MAX` -- so the next person to add a kind
there is told why the card is full instead of discovering it in a frame.

**What is NOT changed either, and is a limit worth writing down:** the TAB list table's three count
columns stay MALE / FEM / CUB, and a legendary is counted in **MALE** -- it is a male boar. A fourth
count column does not fit the 584 px well without taking 44 px off the NAME column. The wire DOES
carry it as its own number (`byKind.legendary`, new in this task) rather than as an `unknown`, so the
column is the only thing that merges it and the report's "a typo shows up as a number" signal is
intact. Queued rather than smuggled in.

## Owners this task does not cross

`src/server/Boar` owns the animal, its geometry, its brain and its wound. `src/server/Match` owns the
price and the scene. `src/shared/Report` owns the word and the picture; `src/client/Hud` draws them.
The legendary adds no owner and moves no boundary: every change above is a row in a table its owner
already holds, except two -- `Body.attachVisual` learns to scale and tint the rig it already welds,
and `Runtime:_modelTemplate` asks for the kind's `model` key instead of for its name (for every kind
that exists those are the same string, so it is the identity it has always been).

**The Studio-only forcing switch** is an attribute `DrivenHunt.ForceLegendary` on `ServerStorage`,
read at the Runtime's boundary and only when `RunService:IsStudio()`. It is NOT a `DHFlag_*` override,
so the harness's flag guard cannot see it -- and a switch left on would silently change what every
drive spawns. So `tests/server/boar_legendary.spec.luau` **asserts it is unset**, which puts it inside
the gate that already exists rather than inside the harness: a run with the switch on FAILS, by name,
and prints how to clear it.

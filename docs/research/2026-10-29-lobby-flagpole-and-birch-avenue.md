# A clean lobby yard: a level truck bay, a flagpole, and a birch-lined approach road

Task 311. Written 2026-10-29, before any code.

Karen, 2026-10-28 ~10:15 UTC: *"so make nice lobby around and cars now some is on small mountain
some of them fix those, lobby has to be clean and nice / also you can add in middle somewhere flag
long stick and flag like in hunting lobbies / so it has to be realistic nice and forest road comming
to lobby around trees on the side or road bjorke tree from both sides with spaces / nice and clean /
outsource and make it real"*.

## 1. What the three systems must do

1. **The four truck bays stand at one height.** Every wheel on the ground, no truck on a mound.
2. **A flagpole** in the gathering yard: a real hunting-lodge pole with a flag hoisted near the top,
   standing on the ground, clear of the pads, the lodge door, the walking lines and the range.
3. **The approach road is lined with birches on both sides, with spaces**, stopping before the yard.

## 2. Why the bays are not level today -- measured, not read off the code

`<runs-dir>/evidence/p311-before.txt`, Forest Test, Play, 2026-10-29 11:35 UTC. A terrain-only
downward ray from 14 studs above each truck's own lowest corner (not from the sky -- a high ray
returns canopy, Learning Agent L-025), 49 samples over each truck's footprint:

| bay | truck's lowest corner | terrain lo | terrain hi | relief |
|---|---|---|---|---|
| Truck1 | 150.00 | 150.00 | 150.00 | 0.00 |
| Truck2 | 149.91 | 150.00 | 151.27 | **1.27** |
| Truck3 | 149.92 | 150.00 | 151.27 | **1.27** |
| Truck4 | **151.27** | 151.10 | 151.27 | 0.16 |

So Truck4 stands **1.27 studs (0.36 m) higher** than Truck1, and Trucks 2 and 3 have a 1.27-stud
bank beside their wheels. The pads are the same defect: `Pad1..3` top out at 150.2 against terrain
at 150.0 -- 0.2 showing -- and `Pad4` sits up at 150.4..151.2 (`p311-geom.txt`).

**The cause is the engine's voxel grid, and this project already wrote half of it down.**
`CONFIG.FIELD.PAD_SKIN_ABOVE_STUDS`' comment (task 244) records the measurement: the lobby's shelf
is 149.248, `Terrain:FillBlock` writes **4-stud voxels**, and 149.248 falls *inside* the voxel band
148..152. `Lobby.Field.fill` fills grass up to the shelf, then cuts the hill with an air block whose
**bottom is the shelf** -- inside that band -- so the band's own occupancy survives and the hill's
contour is still 1.27 studs high in it. Task 244 fixed that band's **material** with
`Terrain:ReplaceMaterial`, and that call "changes the material of a voxel and NOTHING ELSE". The
height was never cut. The grass went away; the mound did not. Measured spread over the whole yard
strip today: **1.27 studs**, the identical figure task 244 recorded for the grass band.

## 3. Sources

### 3.1 The terrain fill (the engine, and this repo's own measurements)

- [`Terrain:FillBlock`](https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock) --
  voxel resolution 4 studs. Roblox, current, maintained.
- [`Terrain:ReplaceMaterial`](https://create.roblox.com/docs/reference/engine/classes/Terrain#ReplaceMaterial)
  -- material only, no occupancy, no height. Roblox, current.
- This repo, `src/shared/Lobby/init.luau`, `FIELD.PAD_SKIN_ABOVE_STUDS` (task 244) and
  `src/server/Lobby/Field.luau` -- the two measurements above, taken in Karen's own place.
  **Good:** both record the voxel band and why filling *higher* is the wrong fix (it lifted the whole
  yard to 151.27 and would have buried the road slabs at 149.50). **Bad:** neither cut the band, and
  the material fix hid the mound by making it the same colour as the yard.

**Pattern adopted (borrowed, not invented): cut on a voxel boundary.** The air block's bottom moves
from the shelf down to the **4-stud boundary at or below it** (148 for a 149.248 shelf), so the band
is covered *whole* and comes out empty, and the grass/pad blocks are then filled back up to the
shelf over a flat, empty plane -- one uniform partial voxel, one uniform surface. The order inside
`Field.fill` becomes **air -> grass -> pad**, because an air block that now reaches *below* the shelf
would otherwise eat the grass it is meant to leave. This is `MapGen.Ground`'s own rule for the drive
map's terrain ("every terrain edge on a multiple of 4", `docs/design/shooting-range.md` section 4)
applied to the Y axis instead of X and Z. Nothing new is invented: it is one boundary function and a
re-ordering of three calls that already exist.

**Why not an edit-time fill saved into Karen's place** (the dispatch's first suggestion): it would
make a second writer of the lobby's ground. `Field.luau`'s header is explicit -- it is *"THE ONE
WRITER OF THE LOBBY'S TERRAIN"*, and `MapGen.Ground` is the edit-time writer for the drive map only,
kept apart by three stated facts. A hand-saved shelf in the place file would be a third, would
contradict `Field.fill` on the next boot, and would have to be re-done by hand after every anchor or
span change. The runtime fill is the owner that exists; it just had the wrong bottom. **No place save
is needed, and that is the better answer, not a shortcut.**

### 3.2 The flagpole

- [Bygghemma, *Flaggstangens hojd*](https://www.bygghemma.se/reportage-och-guider/flaggstang-hojd/)
  -- Swedish rule of thumb: no regulation; the pole should rise above the house's ridge; **8 m pole ->
  200x125 cm flag, 9-10 m -> 240x150 cm**; 10 m "perfect for most villa gardens". Retailer guide,
  current. **Good:** gives the pole->flag pairing, which is the one number a flag needs. **Bad:** a
  retailer, not a standard.
- [Testkollen, *Flaggstang*](https://www.testkollen.se/flaggstang) -- same height/flag pairing,
  independent of the first. **Good:** confirms the pairing. **Bad:** also commercial.
- [Liberty Flagpoles, *How tall should your home's flagpole be*](https://www.libertyflagpoles.com/blogs/libertyblog/how-tall-should-your-home-s-flagpole-be)
  -- US domestic practice: 20 ft (6.1 m) for a single-storey house, 25 ft (7.6 m) for two.
  **Good:** an independent second culture, and it brackets the Swedish numbers from below.
  **Bad:** a vendor blog, no standard cited.

Adopted: **10 m pole, 240x150 cm flag** -- the top of the Swedish domestic range, because the pole
stands beside a lodge whose ridge is already 33 studs (9.4 m) above the shelf, and the 8 m / 200x125
pairing would leave the flag below the roofline. At 1 stud = 0.28 m: **pole 35.7 studs, flag 8.6 x
5.4 studs**. Pole diameter: domestic 10 m poles run ~75-110 mm; **0.4 studs = 112 mm**, the top of
that range, because thinner than ~0.3 studs stops reading as a pole at 60 studs away.
The flag's own look is a free choice (feedback *"styling never blocks"*): a hunter-green field with
an off-white Nordic cross, the shape every Scandinavian estate flag has, so it is unmistakably a
flag from the road.

### 3.3 The birch avenue and the forest road

- [Naturvardsverket, *Alle* (biotopskydd guide, PDF)](https://naturvardsverket.se/4ac349/contentassets/996bb6b6620949b0bfbe7019b7d8109c/01-alle-2014-04-15.pdf)
  -- a legal Swedish alle is deciduous trees in **one or two rows along a road, at least 5 trees**,
  mostly adult. **Good:** it is the definition, from the agency. **Bad:** it sets **no spacing at
  all**, which is the number we actually wanted.
- [Haninge, *Bedomning av bjorkalleer* (PDF)](https://www.haninge.se/siteassets/bygga-bo-och-miljo/oversiktsplanering-och-detaljplaner/detaljplaner/vega-hermanstorp/hermanstorp/17-bedomning-av-bjorkalleer.pdf)
  and [Uppsala's alle inventory (PDF)](https://www.uppsala.se/contentassets/27e00f22b586468f8f8e543ba850a96b/biotopskydd-alleer-8-december-2021.pdf)
  -- real bjorkalleer assessed tree by tree; **gaps where individual trees died are normal and do not
  stop a row being an alle**. **Good:** says the gaps are real. **Bad:** no spacing figure either.
- [Clarington tree-planting standard (PDF)](https://www.clarington.net/media/adckthnl/trr-application-2026-aoda.pdf)
  -- rural road planting at **12 m per deciduous tree**. **Good:** an actual number from a road
  authority. **Bad:** Ontario, not Sweden.
- [Skogforsk / Bergqvist, *Geometrisk standard* (PDF)](https://www.skogforsk.se/contentassets/5e079c2a98bd4d549cdaf129072542c6/05-geometrisk-standard-mikael-bergqvist.pdf)
  -- Swedish forest-road guidance: **4 m road width**, 4.1-6.2 m usable in curves. **Good:** the road
  width this lobby's lane should be judged against. **Bad:** a presentation PDF, not the regulation.

Adopted: **7 m (25 studs) between trees in a row**, inside the 12 m road-authority figure and below
it because our birch template is 74 studs tall at scale 1 and is planted at 0.6-0.75, giving a ~10
stud crown radius -- at 25 studs the crowns nearly meet, which is what a bjorkalle looks like, and at
43 studs (12 m) it would read as scattered trees. **One deliberate gap**, on the Naturvardsverket /
Haninge finding that a dead individual is normal. **Two rows, >= 5 trees** -- the legal minimum is
met with 7.

The existing lane is **20 studs (5.6 m) wide plus two 3-stud verges**, which is already wider than
the 4 m Swedish forest-road figure, so nothing about the road itself needs changing.

## 4. Where the trees and the pole go -- from the measurement, not from taste

`<runs-dir>/evidence/p311-geom.txt`, Forest Test, Play:

```
LANE x 2860..2880 z -3054..-2894 topY=149.75   (verges to 2856.5 / 2883.5)
ROAD Yard x 2883..2929 z -2994..-2909
BOX Pads.Pad1..4 x 2891..2903 z -2982..-2921
BOX Trucks.Truck1..4 x 2906..2925 z -2981..-2922
BOX Lodge x 2828..2870 z -2930..-2888
BOX Range x 2570..2730 z -3356..-3212
world foliage inside the avenue corridor: 0
```

- **The avenue stands at x 2846 and x 2894**, 24 studs either side of the lane's centre (2870): 13
  studs clear of the lane's verge and 6 clear of the fence line at +-18.
- **It stops at z -2998**, four studs south of the yard's own southern edge (-2994) -- "stop the
  avenue before the yard", measured. South end z -3048, inside the lane's own length.
- The **east** row has room for three trees (the yard and the pads begin at z -2994); the **west**
  row has room for five, because the lodge's south face is at z -2930. Eight slots, one gap, seven
  trees -- both sides lined, with spaces.
- **The flagpole stands at (2906, -2915)**, the open gravel at the head of the yard: 6 studs north of
  Pad1's north edge, 7 south of Truck1, 36 east of the lodge's east wall, off the spawn->pad walking
  line (which runs at z ~ -2930), and **291 studs from the range's nearest edge**. The range anchor
  is `(2650, -3216)` (`src/shared/Range/init.luau`, `Range.ANCHORS`), **not** the (2600, -3030) an
  older draft quoted (Learning Agent L-151).

## 5. Numeric targets

| # | target | how it is measured |
|---|---|---|
| 1 | terrain relief under each truck footprint **<= 0.25 studs** (7 cm, under a tyre's own sag) | the same 49-sample terrain ray as section 2, before and after |
| 2 | the spread between the four trucks' lowest corners **<= 0.25 studs** | same probe |
| 3 | every pad's top **above** the terrain under it, by 0.1..0.6 studs | the same probe's census |
| 4 | pole height **35.7 studs +- 0.5**, flag **8.6 x 5.4 studs**, flag's top within 1.5 studs of the finial | `lobby.spec`, pure arithmetic over `CONFIG.FLAGPOLE` |
| 5 | pole and every avenue trunk **clear of the lane + verges** (x 2856.5..2883.5), of the yard rect, of every pad and truck box, and of the lodge box | `lobby.spec` over the config, plus the live census |
| 6 | **>= 5** avenue trees, **two rows**, row spacing 25 studs, **>= 1 gap** | `lobby.spec` over `CONFIG.AVENUE` |
| 7 | nothing floating: every ground-standing lobby item's lowest corner within **-0.75..+0.30** studs of the highest surface under its own footprint | the census probe, before and after |

Target 7's window is signed on purpose: a fence post or a log is *meant* to be bedded into the
ground (-0.75 is the fence post's own depth), and nothing may stand clear of it by more than 0.30.
Tree models are excluded from it and judged by their own claw junction, which `treePlan` and
`lobby.spec` already own; a lodge shingle 26 studs up is not a ground-standing item.

Design: `docs/design/lobby.md`. The owner is unchanged: `Lobby.Build` draws every part,
`Lobby.Field` writes the terrain, and nothing else touches either.

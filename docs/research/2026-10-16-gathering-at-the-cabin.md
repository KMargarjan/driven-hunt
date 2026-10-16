# The gathering happens on clean ground, next to the cabin (task 191)

2026-10-16. Builder.

KAREN, 2026-10-15 ~17:20, verbatim:

> *"next is when hunt over everyone is in clean ground no grass firstable / second it could be next
> to cabin"*

Two sentences, two facts. The end-of-drive gathering -- the shot boars laid in rows, everybody in a
ring, four torches, the results table (tasks 159 / 168 / 173) -- happens **in the forest**, on the
drive's own gathering spot, and in the forest there is **tall grass**: it hides the animals she asked
to see and it hides the players standing round them. And the place she wants it is the **lobby yard
beside the lodge**, which is already clean, flat, blade-free ground.

## 1. What the system must do

1. The gathering happens on ground with **no grass blades over it**, so every display animal, every
   player, every bot and all four torches are fully visible.
2. It happens **next to the cabin** -- a yard beside the lodge, inside the lobby, big enough to hold
   the whole scene at its worst case (12 animals, the ring round them, the four corner torches).
3. **Everyone goes there**: players and bots both, in one move, at the drive's end.
4. **The flow out of it is the one that already exists** (task 177's back-to-the-lodge). No teleport
   to the lobby and then another one back: the scene's ring IS the lobby, so when `enterWaiting`
   frees everybody they are already standing where they belong.
5. The lobby's own layout -- the road, the four trucks and their pads, the shopkeeper, the spawn --
   is **not** touched and nothing of the scene stands in it.
6. The player stands **ON** the ground, not under it (Karen's earlier *"when drive ends I am
   underground"*, fixed in task 192 and which must stay fixed at a new spot).
7. Where the gathering is must still work for **every drive layout** (task 179) and for a world with
   **no lobby at all** (the DEV place), which keeps today's behaviour.

## 2. Numeric targets

| What | Number | Where it comes from |
|---|---|---|
| worst-case scene square | 47 x 47 studs | `Scene.cornerReachFor(12, Match.CONFIG)` = 23.5, doubled |
| the yard's clean pad | 56 x 56 studs | the square plus 4.5 studs of margin on each side |
| clearance, gathering square to the chimney | 5.5 studs | the square's east edge at anchor-relative x -26.5, the chimney's west face at -21 |
| clearance, gathering square to the lodge wall | 8.5 studs | the wall's outer face at x -18 |
| clearance, the yard's dirt to the lodge footprint | 4 studs | the pad's east edge at x -22 |
| clearance, the yard's west edge to the nearest trunk | 8 studs | `Tree27` MEASURED at x -86 in the live place |
| distance from the porch spawn | ~50 studs | spawn at (0, 16), gather spot at (-50, 10) |
| ground spread over the footprint, before the lobby builds | 13.13 studs | raycast grid, section 5 |
| ground spread over the built yard | **0.00 studs** at y 150.00 | 625-sample grid, section 5 |
| non-terrain obstacles over the footprint | **0** | both grids |

## 3. Three external sources

### 3.1 ioquake3 -- `code/game/g_main.c`, `FindIntermissionPoint` / `BeginIntermission`

GPL-2.0. Actively maintained fork of Quake III Arena (`ioquake/ioq3`). **Fetched and quoted
verbatim 2026-10-16** (the raw file, not a summary of it).
<https://github.com/ioquake/ioq3/blob/main/code/game/g_main.c>

This repo already borrows the intermission's *shape* -- `Match.Scene`'s own header cites
`MoveClientToIntermission` for "every client is moved to one point and frozen while the scoreboard is
up". What matters for THIS task is the half that was not borrowed: **where that one point is.**

`FindIntermissionPoint` looks for an entity the **map author placed**:

```
ent = G_Find (NULL, FOFS(classname), "info_player_intermission");
if ( !ent ) {   // the map creator forgot to put in an intermission point...
    SelectSpawnPoint ( vec3_origin, level.intermission_origin, level.intermission_angle, qfalse );
}
```

So: the intermission point is **authored content with a fallback**, never a point derived from where
the fight happened. The comment in the engine's own source -- *"the map creator forgot to put in an
intermission point"* -- is the whole pattern: the content says where, the code says when, and a map
with no answer degrades to the spawn logic rather than failing.

- **Does well:** one authored place per map, so it can be a clean, framed, lit spot chosen by eye
  rather than a byproduct of geometry. The fallback means a map that never named one still works.
- **Does badly:** it is one global point per map, so a mode that wanted a different gathering per
  round could not have one.

### 3.2 `Streckelegen` -- what the thing the scene depicts actually is

CC BY-SA 4.0. German Wikipedia, maintained. **Fetched and quoted 2026-10-16.**
<https://de.wikipedia.org/wiki/Streckelegen>

The scene is a *Strecke* -- the day's bag laid out at the end of a drive -- and the article says what
that is, in two sentences that are both already in this repo's code:

> *"In Deutschland wird das Wild beim Streckelegen üblicherweise in einer bestimmten Anordnung auf
> seiner rechten Körperseite abgelegt."*
>
> *"In bestimmter Reihenfolge wird das Wild auf der Strecke angeordnet."*

A prescribed **arrangement**, in a prescribed **order**, each animal laid on its **right side**.
`Scene.rowLayout` is the arrangement (rows, the first animal shot first), and
`Boar.CONFIG.MODEL.DISPLAY_ROLL_DEG` is the side -- so the tradition is already the code's own answer
to "how do they lie".

- **Does well:** it settles what the scene needs from its ground, which is the thing this task is
  about. A bag that is *laid out* -- in rows, every animal visible, people walking round it -- needs
  a flat, open, prepared place. Tall grass is not one, and neither is the middle of a drive lane.
- **Does badly:** it describes the ritual and not a map. It names no place, no size and no lighting,
  so every number in section 2 is still ours.

**A fourth source was attempted and could not be read (rule 8):** the Valve Developer Community page
for `info_intermission` -- the same authored-point pattern in a second engine lineage -- answers
**HTTP 403** to this tool, as `en.help.roblox.com` already does (`docs/research/2026-09-26-asset-pipeline.md`).
Nothing in this note rests on it.

### 3.3 Roblox Creator Docs -- `Terrain:FillBlock` and `Enum.Material`

Roblox's own reference, maintained. Already the citation in `src/server/Lobby/Field.luau`'s header;
**not re-fetched here**, and nothing below rests on the page's prose -- the blade behaviour is
measured in this repository, with two photographs.
<https://create.roblox.com/docs/reference/engine/classes/Terrain#FillBlock> ·
<https://create.roblox.com/docs/reference/engine/enums/Material>

The *"clean ground no grass"* half is an engine fact this repo has already paid for twice.
`Lobby.CONFIG.FIELD.PADS` exists because of it, and its own comment records both measurements: the
lodge's first interior shot came back with **terrain grass growing through the floorboards**, and the
first road shot came back with **no road at all**, because Roblox draws a grass material's blades on
the terrain surface and a part laid over them does not hide them. `Enum.Material.Ground` has no
blades, so a block of it under a footprint is the whole fix.

- **Does well:** it is the answer already in the repository, measured in this place, with two
  photographs behind it. A third pad is a data row, not a code path (`Field.fill` loops the list).
- **Does badly:** the surface `FillBlock` produces is **voxelised** and is not exactly the nominal
  shelf -- measured at 150.000 against a shelf at 149.248 in task 186, which is why the trucks' tyres
  were 0.752 studs underground. So the gathering spot's Y must be **measured** with the world's own
  ground reader and never predicted from the shelf.

## 4. The pattern adopted, and why

**The world provides the gathering spot; the drive decides when to gather there.** One new injected
seam on `Match.start`, `world.gatherSpot`, exactly the shape `world.placement`, `world.markers`,
`world.standArea`, `world.boars`, `world.bots` and `world.depart` already have in this repository.

* `Match.gatherSpot()` asks `world.gatherSpot` first and falls back to `Match.gatherSpotFor(markerSet,
  config)` -- the drive's own "behind the middle stand" rule, untouched. That IS source 3.1's
  `if ( !ent )` branch: authored answer first, derived answer when there is none.
* The **lobby** answers it, because the lobby is the owner that knows where its own yard is. The
  rectangle is one row in `Lobby.CONFIG.FIELD.PADS`, named `Gather`, and it is the **only** place
  that rectangle is written: `Field.fill` lays the blade-free block from it, `Lobby.gatherSpotFor`
  reads its centre, `Build.treeLine` excludes it, and `lobby.spec` bounds the scene's own worst-case
  square inside it. A second copy of the rectangle would be two definitions of one fact, which is
  `docs/PROJECT_CONTEXT.md`'s named failure.
* The **Y is measured, never predicted** (source 3.3's second half): `Lobby.gatherSpotFor` asks
  `world.groundAt` at the yard's own centre and only falls back to the shelf when the reader answers
  nothing. `Scene.build` then asks the same reader again per animal and per torch (task 192), and
  `Body.stand` snaps every ring slot onto it -- so "the player stands ON the ground" is three
  readers of one answer and not a fourth opinion.
* **Nothing else moves.** `Scene`'s rows, ring, corners, spacing, cap and torches are untouched; so
  are `Phase`, the roster, the dismissal, the results table and task 177's flow out of the scene.
  What changes is the two Vector3s the scene is handed.

### Why not the alternatives

1. **Clear the grass at the forest spot instead.** It is not one spot: `ForestTest` has four drive
   layouts (task 179) and the spot is derived from the middle stand, so it moves with the layout and
   with the road's curve. Clearing grass would mean writing terrain inside a running session at a
   point that is different every drive -- and `MapGen.Ground`/`Lobby.Field` are the only terrain
   writers in this repo, neither of which runs in the drive. It also does not answer Karen's second
   sentence at all.
2. **A second, dedicated gathering area out in the fields.** More ground to build, more to keep clear
   of the drive, and it is not *"next to cabin"*.
3. **Teleport everybody to the lobby and then teleport them again to the lodge.** The dispatch rules
   it out and task 177 already makes it unnecessary: the lobby clears the roster when the scene goes
   up, so the men in the ring are men in the lobby, and `enterWaiting` frees them where they stand.
4. **A feature flag over the new spot.** `Flags` is at `MAX_FLAGS = 13`, and the switch is already
   stronger than a flag: it is an injected function, absent in the DEV place and absent whenever the
   lobby did not build (`lobbyOn`), so both states are reachable by parameter -- which is what
   CLAUDE.md's flag rule actually asks for.

## 5. Measured, in Karen's Forest Test place, 2026-10-16, before a line was written

Raycast grid, 11 x 11 samples, x 2740..2840 and z -2970..-2870 at 10-stud steps, from y = 500 down
1000 studs, water ignored (Edit mode, place 130094961655666):

```
lo=142.75  hi=155.88  spread=13.13  obstacles=0
```

* **Not one non-terrain hit and not one miss.** No tree, no rock, no foliage model and no hole over
  the whole footprint -- so the gathering yard is clean ground before the lobby flattens anything.
* 13.13 studs of fall is well inside `FIELD.DEPTH_STUDS` 48 and `FIELD.CLEAR_STUDS` 96, so
  `Field.fill`'s existing cut-and-fill makes this yard flat at the shelf exactly as it does the
  lodge's.
* The yard sits at anchor-relative x -78..-22, z -18..38, i.e. world x 2772..2828 and z
  -2968..-2912 -- inside the grid above on every side.

### Measured again with the yard actually built, same day, same place

One Play session of the Forest Test, the drive run to its end, then 625 raycasts at 2-stud steps over
the worst-case gathering square (48 x 48, centred on the spot the server itself printed):

```
[match] gathered 0 animal(s) in 0 row(s) at the world's own spot (2798, 150, -2940): 0 real model(s), 0 box(es)
samples=625 misses=0 materials[Ground=623 Grass=2] spread=0.00 (150.00..150.00) obstacles[] trees=27 onGatherYard=0
Alhamdulilah824 root=2798.0,153.5,-2926.0 ground=150.00 feetAbove=0.35 mat=Ground
```

Four facts out of that, and one defect:

1. **The gathering happened at the cabin**, at the spot this config names, 63 studs from the lodge
   floor -- and the Y is the MEASURED 150.00, not the predicted shelf of 149.2.
2. **The ground under it is dead flat and blade-free**: zero spread, zero obstacles, zero misses.
3. **The player stands ON it**, feet 0.35 studs above the surface -- not under it.
4. **The tree line is untouched**: 27 trees, the same 27 the road and yard rules already left, and
   none on the gathering yard.
5. **THE DEFECT: two of the 625 samples came back `Grass`**, four studs inside the nominal west edge.
   `Terrain:FillBlock` writes 4-STUD VOXELS, and x 2770 is 692.5 voxels -- an edge off the grid
   leaves a partly-filled voxel that keeps its grass, while the z edges, which happened to land on
   the grid, lost about a stud. Nothing in the scene stands at that point (the animals lie within 15
   studs of the centre and the nearest torch is at 23.5, 14 studs away in z), but *"clean ground no
   grass"* is the whole task. **Fixed by moving the yard two studs east, to (-50, 10)**: its edges
   are then x 2772 / 2828 and z -2968 / -2912, all four exactly on the voxel grid.

### Why the yard is at (-50, 10) and not further west

`TREELINE` stands 30 trees at radius 100 with +-9 studs of jitter, and where they actually landed was
MEASURED in the live place rather than predicted: the fifteen on the western half run from x -9 to
x -103, and the nearest one to the yard is **`Tree27` at x -86, z +34** -- eight studs clear of the
yard's west edge at -78 and four clear of `Build.treeLine`'s own exclusion. So the tree line frames
the gathering instead of standing in it, and the built count is **27, the same 27 as before this
task** (three of the thirty are skipped by the road and yard rules that already existed). A centre at
-62 with a 64-stud pad -- the first arithmetic -- reached x -94 and would have taken four or five
trees out of the arc for no gain.

The exclusion is still added to `Build.treeLine`, because jitter plus a future edit to `RADIUS_STUDS`
should not be able to put a spruce on the clean ground; it simply removes nothing today, and
`lobby.spec` asserts both halves -- that no arc position in the whole jitter band can reach the yard,
and that a tree line deliberately aimed at it is kept off.

### Which way the scene faces

`FACING` is `(1, 0, 0)` -- **east, at the lodge**. `Scene.sideAxis` crosses the facing with +Y, so a
look of +X gives a row axis of +Z: the animals lie in a line running north-south, and a player
walking out of the porch from the east sees the whole row **broadside** rather than end-on. The
second row stacks west, away from him, which is what `Scene.rowLayout` already means by "behind".

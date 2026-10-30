# Task 315 BRIEF -- move the shooting range straight out from the shop

Input to `tools/architect.sh design shooting-range-lobby --task 315`. Written by the Builder,
carrying the Director. It overrides anything older in `docs/`, `TASKS.md` and the existing designs
(`docs/design/shooting-range.md`, `docs/design/shooting-range-lobby.md`).

## 1. Karen, 2026-10-30 ~13:00 UTC, with a screenshot

> "those trees can be removed and shooting range can be moved there that I can directly from shop
> walk to shooting range same distance but straight / still shooting range changes is not there? /
> add and improve"

The frame is `<runs-dir>/playtest/range-move/karen-2026-10-30-trees.png`, opened and described: she
stands on the yard gravel south-west of the lodge, compass needle 15.6 deg past **S** (heading
~196 deg, measured off the label ticks at 3.18 px/deg); a row of leafy birches fills the view with
one tall narrow conifer behind them; the range's numbered station canopies are small at the far left
behind a grass bank. The same scene was reproduced live from (2850, -2960) at heading 245
(`<runs-dir>/playtest/range-move/315-C-yard245.png`, looked at): same pine, same stations, same bank.

## 2. MEASURED NOW (Forest Test, live, at main d4b10eda -- not read off the code)

Probes `m2..m10.luau` and `edit1/edit2.luau` (scratchpad), run through `<runs-dir>/ftplay.py`.

| Fact | Measured |
|---|---|
| Lobby anchor | (2850, -2950) |
| **Shop door** (`DoorThreshold`, the lodge's south front) | **(2850.0, 152.3, -2916.1), 9.6 wide, faces SOUTH (bearing 180)** |
| Shop counter / keeper | (2857, 153.4, -2899.2), inside the lodge |
| Range anchor today | (2600, -3030), `downrange = -1` (fires SOUTH) |
| Station mats today | x 2600/2624/2648/2672/2696/2720, all at z -3030 |
| Range parts bbox today | x 2544..2776 (232 wide), z -3222..-3011 (211 deep), y 149.5..164.9 |
| **Walk door -> nearest mat (station 6)** | **172.8 studs, bearing 228.8 deg** -- 48.8 deg off the door's own facing |
| Walk door -> station 1 (the anchor) | 274.7 studs, bearing 245.5 deg |
| Ground on the straight line south of the door (runtime) | flat 150.0 to z -3056, then a **step up to 160.3** at the field edge, 164.6 by z -3126 |
| Place terrain (EDIT) at the current range site | 134.9 at the anchor, 148.3 / 155.1 across the row -- so today's flat 150 terrace is **runtime fill, not in the place** |

**Every tree between the shop and the range is CODE-PLACED by `Workspace.Lobby`** (`Build.treeLine`,
`Build.avenue`, `Build.lodgeTrees`). A census of `Session`, `OurForest`, `Foliage` and `Lobby` over
x 2700..3000, z -3320..-2960 returns 18 lobby trees and **exactly one** place-content tree.

**The tall conifer Karen names is `Workspace.Session.Tree8` at (2844, -3188), 104.7 studs tall** --
place content, from the bought forest, standing **inside the proposed new footprint**, 6 studs off
the door's own line. Nothing else of the world's foliage is in that footprint (3 parts, all his).

Trees whose trunk is in the station row's span (x 2790..2910) between the lodge's south front and
the new range's north edge, measured:

| Tree | x | z | owner |
|---|---|---|---|
| Avenue05 | 2846.9 | -2948.0 | `Lobby.Avenue` (task 311) |
| Avenue03 | 2846.7 | -2997.3 | `Lobby.Avenue` |
| Avenue08 | 2893.8 | -2997.1 | `Lobby.Avenue` |
| Avenue07 | 2894.8 | -3015.3 | `Lobby.Avenue` |
| Avenue02 | 2846.4 | -3023.7 | `Lobby.Avenue` |
| Tree12 | 2901.7 | -3028.0 | `Lobby.TreeLine` |
| Tree18 | 2812.3 | -3032.0 | `Lobby.TreeLine` |
| Tree19 | 2792.8 | -3033.3 | `Lobby.TreeLine` |
| Tree17 | 2827.0 | -3040.4 | `Lobby.TreeLine` |
| Tree13 | 2892.1 | -3044.8 | `Lobby.TreeLine` |
| **Session.Tree8** | **2844.0** | **-3188.0** | **place content** |

Ten lobby trees plus the one pine -- which is Karen's own count ("a row of ~10 birches plus one tall
pine"). That the measured corridor reproduces her count is the evidence that this corridor is the
row she pointed at.

**Terrain at the proposed new site** (EDIT, the place's own ground, 9 x 11 grid over x 2734..2966,
z -3071..-3281): low 146.0 at (2734, -3281), high **183.8** at (2966, -3281), **spread 37.8**,
against the current site's 22.7. At a shelf of 150 the cut is **33.8 studs deep at the south-east
corner** and the fill 4.0. The hill rises to the south and to the east; the lane fires south, so the
natural rise is BEHIND the berm and the deep cut is that south-east corner.

**The asphalt at (2850..2860, -3070..-3090) is terrain, a 10 x 20 scrap, not a through road.** The
real asphalt road is at x 2600..2665, z -3240..-3260 -- behind today's berm, not at the new site.
The lobby's own built road (x 2860..2880) stops at z -3054, the field's south edge.

## 3. Director decisions this design must carry

(a) **The range is MOVED, not copied.** One range. Its origin goes on the straight line out of the
shop door, and the walking distance stays within +-15% of today's **172.8 studs** (door -> nearest
mat), i.e. **147..199**.

(b) **The birch row and the pine in front of the shop are removed.** Lobby trees are removed by the
owner that places them (`Workspace.Lobby`, in code); the pine is place content and is removed the
way `Lobby.CONFIG.CLEARING` already removes the world's foliage -- **at run time, by geometry, never
by a Studio click and never by an edit to the place**. Nothing else in the lobby moves unless the
footprint demands it, and the design says what and why.

(c) **Everything proven on the range stays exactly as it is relative to its own origin**: the hill
Karen called perfect, the 107/125/179 lanes, the T6 envelope, solo on the whole range (task 313),
the treestands and the climb, the isolation. A pure translation of the range frame, so **no tuned
number changes**. T6 is invariant under translation by construction -- every term
(`bermCrestFaceZ`, `backstopSpanFor`, `sightSpanFor`) is derived from the anchor -- so what the
design must re-answer is not T6's arithmetic but (d).

(d) **The berm still faces AWAY from the lodge, the shop and every walk path**, and no shot from any
station can end anywhere a player stands. Re-sweep against the NEW surroundings: the lobby field
(x 2740..2960, z -3060..-2840) is now directly NORTH of the range, i.e. BEHIND every shooter.

(e) **The old site is left clean** -- no orphan posts, fences, mats or prompts. Measured: every range
part lives under `Workspace.Range` and is rebuilt at the anchor, and the terrace is runtime fill that
is absent from the saved place (section 2), so the old site is clean by construction. The design
states this as a fact to be verified, not assumed.

## 4. The Builder's proposal, for the design to accept, change or refuse

**Anchor (2790, -3090)**, `downrange = -1` unchanged. Then:

* mats at x 2790/2814/2838/2862/2886/2910, **centred on 2850 = the door's own x**;
* walk door -> nearest mat (station 3 at 2838 or station 4 at 2862, both 12 studs off the line):
  **174.3 studs, bearing 183.9 / 176.1 deg** -- **+0.9 % of today's 172.8**, inside (a)'s +-15 %,
  and essentially straight out of the door;
* footprint x 2734..2966, z -3282..-3071: entirely south of the lobby field's south edge (-3060) and
  south of the lobby road's end (-3054), so neither is crossed.

**What the design must decide, where the Builder has a number but not the authority:**

1. **The shelf.** `shelfFrom` = the lobby anchor keeps the shelf at 150 and the walk from the door
   DEAD LEVEL for all 174 studs, which is what "directly from shop walk" asks for -- at the cost of a
   33.8-stud cut at the south-east corner (today's site cuts 21 and Karen called the result perfect).
   Taking the shelf from the new site instead (~163) halves the cut to ~21 but puts a 13-stud climb
   in the walk at the field edge. The Builder recommends the level walk, and asks the design to say
   how the cut face is finished (the berm's `slopeRun`/`slopeSteps` batter already exists).
2. **How wide the cleared corridor is, as a rule and not a list.** The Builder proposes the station
   row's own span (`anchor.x .. anchor.x + 120`), projected north from the range's north edge to the
   lodge's south front: it is the smallest rule under which the WHOLE range is visible from the door,
   and it reproduces Karen's count of ten.
3. **The avenue.** That corridor removes five of the six standing birches of task 311's birch avenue,
   because the range now stands at the south end of the road the avenue lines. The Builder does NOT
   propose to re-plant it in this task, and asks the design to say whether the avenue's rows should
   be re-sited along the new straight walk or left for a follow-up. Karen asked for the avenue on
   2026-10-28 and for these trees gone on 2026-10-30; the later word is taken as the current one, and
   the reversal is named here rather than hidden.
4. **The pine's remover.** `Lobby.CONFIG.CLEARING` sweeps `Session`/`OurForest`/`Foliage` inside the
   yard, the road corridor and the front of the house. The range's footprint is none of those. The
   design says which owner clears the range's own ground -- the range (its geometry owner) or the
   lobby (the existing sweep, given one more rectangle) -- and one owner only.

## 5. Which rule owns the ground at the NEW site (Learning Agent L-154)

Named here before any build, because this exact gap put a player back at the lodge in tasks 298/302.

* **`Join.homeAreas` / `Join.insideHome` / `Join.needsReturn`.** The range's rectangle is handed in by
  `ForestTestBoot`'s `rangeHomeAreas`, computed as
  `RangeData.footprintFor(anchor, LAYOUT, downrangeOf(row))` -- **derived from the anchor, so it
  follows the move with no code change.** `Join.homeAreas` then adds
  `Join.walkwayTo(lobby anchor, footprint centre)`, a corridor of half-width 24.
* **Checked by arithmetic for the proposed anchor:** footprint centre (2850, -3176.5); the corridor
  is x 2826..2874, z -3200.5..-2926; the footprint is x 2734..2966, z -3282..-3071; the field is
  x 2740..2960, z -3060..-2840. The straight walk at x = 2850 from z -2916 to the mats at -3090 is
  inside the field down to -3060 and inside the footprint from -3071, with the corridor covering
  x 2850 throughout, and **the 11 studs between -3060 and -3071 are inside the corridor's own z
  range**. The design states this and the build must VERIFY it live, not assume it.
* `Lobby.CONFIG.FIELD.PADS`, the spawn, the gather rectangle and the truck bays are all north of
  z -3060 and are not touched by the footprint.

## 6. Caveats carried forward, so they are not misreported as defects of this move

* **`TASKS.md` 313a(o) is open:** the boar does NOT hold RUN pace across the wide span -- the board
  read 9.13 s against the 4.18 s setpoint. The CLICK PROOF for this task asks for a RUN crossing;
  that discrepancy is **pre-existing and not caused by the move**, and the report says so.
* **`TASKS.md` 313a(a) is open:** nobody has looked at an invisible player (solo) in Karen's place.
  The move does not re-close it. If the translation changes who counts as "on the range", that is
  still open, not settled by this geometry.

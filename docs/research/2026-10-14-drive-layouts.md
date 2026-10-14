# Varied drives: more than one place to stand (Task 179)

2026-10-14. Builder. For `docs/design/drive-layouts.md`.

KAREN, 2026-10-13 ~13:55, verbatim:

> *"we will improve terrain that not all a time same place hunters standing and not the same terrain
> for beaters / we will make view for hunter from different places and diffretent tree lines road ect
> like in real life"*

## 1. What the system must do

Today the Forest Test has exactly ONE drive: the curved road at z = -2097, nine stands 150 studs
apart (`ForestTest.standPosition`), the beaters 580 studs north of it, the resting wood between, the
boars leaving at `ForestTest.EXIT_Z`. Every drive Karen plays is the same ground seen from the same
nine spots.

It must instead:

1. hold SEVERAL named drive layouts as DATA, each one a different place in the Forest Test world:
   its own stand line (where, how many, how far apart, straight or curved), its own beater start
   line, its own resting ground, its own exit;
2. pick one per drive, at random, never the same one twice running;
3. let the Director force one for a test (a Studio attribute, the `DHForestStartRole` idiom);
4. be read through the ONE world-geometry seam task 157 built, so no owner holds a second copy of
   where the road is -- the hunter's map, the compass, the markers, the bots' lanes, the animals'
   resting places and the drive all answer from the same table;
5. validate: every layout's stands stand on readable ground, its beater line is behind the animals
   and ahead of the stands, its exit is past the stands, and no layout's corridor runs through the
   lodge.

### Numeric targets

| What | Target | Why |
|---|---|---|
| Layouts shipped | >= 3 (today's + 2) | the dispatch's target; 1 acceptable if honest |
| Stands per layout | 5-9 | 9 is today's; a short line is a different kind of drive |
| Stand spacing | 130-150 studs | 150 = today = 42 m at `SPOOK.METRES_PER_STUD`, a real stand interval |
| Stands on readable ground | 100% of a shipped layout's stands | `Markers.groundFor` refuses a stand whose two ground readings differ by more than 1 stud |
| Stands clear of a trunk | 100% within 8 studs | today's road is 9/9 (measured, section 5); a new layout may not be worse |
| Drive length | ~120 s of bot walk, every layout | 580 studs at `Bots.CONFIG.WALK_SPEED` 5 -- task 162's measured pair, unchanged |
| Push corridor in trees | >= 75% of samples | the beaters must walk a wood, not a field |
| Repeat of the same layout | never twice running | section 4 |

## 2. Sources

### A. WILD UND HUND, *Drueckjagdstaende -- Sicher ist sicher?* (German hunting press)

<https://wildundhund.de/drueckjagdstaende-sicher-ist-sicher/>

Licence: all rights reserved, read for facts only, nothing copied. Maintained: a live trade title
(Paul Parey), articles dated and still published.

**Good:** it states where a driven-hunt stand belongs and, more usefully, where it does NOT. A stand
does not go on a path or a narrow clearing between two thickets, because panicked game runs down
those light bridges; it goes where the game passages converge AND the bullet catch (*Kugelfang*) is
safe, and the two places it names for that are **hillsides and natural terrain edges**. On level
ground a shooter has about ten metres before a bullet can ricochet off the forest floor, so a flat
stand only works where the ground rises in front of it.

**Bad:** it is about real safety, not about a game, and nothing in it is a number this project can
use directly.

**What this repo took:** the two new layouts are a **forest edge on a hillside** and a **straight
ride inside the wood**, in that order of preference, and the edge layout is deliberately the one
with 80 studs of rise across it (section 5). It also confirms today's road is the LEAST classical of
the three, which is exactly Karen's complaint.

### B. Deutsche Jagdzeitung, *Saubere Ansitz-Drueckjagden!*

<https://djz.de/saubere-ansitz-drueckjagden-858/>

Licence: all rights reserved, read for facts only. Maintained: a live title, dated articles.

**Good:** the preparation of a drive IS the clearing of the stands -- a BROAD shooting lane
(*Schiessschneise*) and a NARROW sight line (*Sichtschneise*) cut from every stand before the season.
So a stand's view is a property of the stand, made on purpose, and differs stand to stand.

**Bad:** no geometry, no distances for the lanes themselves.

**What this repo took:** the honest reading is that a real ride is CUT, and this place's wood was
bought and built in Studio, not generated. Cutting one means deleting Studio content, which rule 7
forbids and which is Karen's to decide. So the "ride" layout is placed on a strip the wood ALREADY
leaves clear, and measured to prove it (section 5); carving is written up as the next step
(section 6).

### C. DJV (Deutscher Jagdverband), *Drueckjagd*

<https://www.jagdverband.de/rund-um-die-jagd/was-draussen-passiert/bewegungsjagd/drueckjagd>

Licence: all rights reserved (the German hunting association's own site). Maintained: the national
body's standing reference pages.

**Good:** the plain definition of the method and its variants -- the beaters' line moves game to a
standing line of shooters, and a drive is one of several forms of *Bewegungsjagd*.

**Bad:** nothing about placement.

**What this repo took:** confirmation that the thing being varied is the PAIR (the stand line AND
the beaters' ground) and not the stand line alone. Every layout here therefore carries both halves
plus the ground between them.

### D. TetrisWiki, *Random Generator* (the 7-bag rule)

<https://tetris.wiki/Random_Generator>

Licence: community wiki, facts only. Maintained: actively edited; the rule it documents is in the
published Tetris Guideline.

**Good:** it names the exact failure this task must avoid and the exact cure. A memoryless
`math.random(n)` really does deal the same thing several times running, and players read that as
broken. The cure is a BAG: deal each item once, reshuffle when empty.

**Bad:** a 7-bag with 3 items is a 3-bag, and a 3-bag can still deal the same layout across a bag
boundary (`... C | C ...`).

**What this repo took:** the bag, PLUS the boundary guard the wiki's own description implies -- the
rule is "a shuffled bag of every layout, and if the first of a fresh bag is the one just played,
swap it with the second". That one extra line makes "never twice running" true rather than nearly
true, and it is pure arithmetic a spec can drive with a fixed roll.

### E. Roblox DevForum: *How to prevent math.random from picking the same map* and *An efficient way to randomize a list of maps or items*

<https://devforum.roblox.com/t/how-to-prevent-mathrandom-from-picking-the-same-map/1596809>
<https://devforum.roblox.com/t/an-efficient-way-to-randomize-a-list-of-maps-or-items/223583>

Licence: DevForum terms, read for approach. Maintained: live forum; the threads themselves are old
(2021 / 2018) and are quoted as what this platform's community does, not as a maintained library.

**Good:** the two shapes actually used on this platform -- "remember the previous and re-roll", and
"copy the list, remove as you deal, refill when empty" (the bag, independently reinvented). Both are
a handful of lines and neither needs a library.

**Bad:** the re-roll shape can loop; neither thread handles the bag boundary.

**What this repo took:** the bag, from the second thread, because re-rolling is unbounded AND a bag
guarantees every layout is SEEN -- which matters here, where Karen is judging the look of each one
and a layout she is never dealt is a layout she cannot judge.

## 3. The pattern adopted, and why

**THE WORLD IS A TABLE OF LAYOUTS AND THE GEOMETRY FUNCTIONS TAKE ONE** -- the same shape this module
already uses for `spook`, `beater` and `rest` (`ForestTest.sweepAheadStuds(spook, beater)`,
`ForestTest.encounterStage(..., spook, beater)`): a pure function reads a table handed in and
defaults to the live one when nothing is handed in. So `ForestTest.roadZ(x)` becomes
`ForestTest.roadZ(x, layout)`, and a spec can ask any layout anything with no world running.

**BORROWED, NOT INVENTED** (rule 2): this is Valve's and Unreal's rule, already cited in
`ForestTest.Markers`' header -- *the world places the entities the game mode queries*
(`info_player_terrorist`, `AGameModeBase::FindPlayerStart`) -- extended by one level: the world now
has SEVERAL sets of those entities and names which set is live. `Markers.build` is already the one
writer of `Workspace.ForestMarkers` and already destroys and rebuilds the folder per build, so a
layout change is a rebuild it can already do.

**ONE WRITER, ONE READER-OF-RECORD** (rule 3): the server's forest owner is the ONLY thing that
chooses a layout, and it publishes the name as an attribute on `ReplicatedStorage`. The client never
chooses; it reads. A second chooser on the client is exactly the "two systems that both decide"
failure `docs/PROJECT_CONTEXT.md` names three times -- and here it would put the hunter's map on a
different road from the one his feet are on.

**WHAT IS DELIBERATELY NOT DONE TODAY, and the reason is signs:** every layout pushes SOUTH, along
-Z, exactly as today's does. Rotating or reversing a drive would touch `Brain:_outcome`'s
`position.Z <= exitZ`, `Boar.CONFIG.field.exitZ`, `ForestTest.lineFrontAt`, `wavePoint`, `restPoint`,
`encounterStage`, the drive line's `normal = Vector3.zAxis`, `SafetyArc` and the compass -- a dozen
places where "north" is a sign rather than a parameter. Varying WHERE in the world and WHAT SHAPE
gives Karen three genuinely different views without touching one of them. The axis is the next task
(section 6).

## 4. The choice rule

Pure, so a spec drives it with fixed numbers and no randomness:

    nextLayout(previous, bag, roll) -> name, remainingBag

* the bag is a list of layout names;
* an empty bag is refilled with every name and shuffled using `roll`;
* take the first; if it equals `previous` and the bag holds another, swap it with the second
  (source D's boundary case);
* return the name and the rest of the bag.

The Director's override is a Studio attribute, `DHForestLayout` on `ServerStorage`, read the way
`ForestTest.START_ROLE_ATTRIBUTE` (`DHForestStartRole`) already is: set in Edit, survives into Play,
never in the git tree, not a `DHFlag_*` name so the harness's override guard neither sees it nor can
be defeated by it. A name the table does not know is ignored with a console line, never a crash.

## 5. The measurements -- what this world actually holds

All of it read in the Forest Test place (130094961655666) in **Edit** on 2026-10-14 through
StudioMCP, read-only: terrain height by a `Terrain`-only downward raycast (the rule
`ForestTest.terrainYAt` uses), the second reading by the `OurForest`/`Foliage`/`Boars`-excluding ray
(`ForestTest.groundAt`), and trunks by `GetPartBoundsInRadius` with `RespectCanCollide = true` (the
test `ForestTest.roomToStand` uses -- this wood is mostly non-colliding fern and leaf cards).

**THE WOOD IS A RECTANGLE.** Sampling x 1400..4700 and z -4100..-700 every 150 studs, a colliding
part within 25 studs appears only inside **x 2250..3900, z -2900..-1330** -- about 1650 x 1570
studs. Terrain carries on in every direction past that with no trees at all, so this world is one
block of wood with open field on all four sides of it. Today's road cuts it across the middle at
z = -2097.

**THERE IS NO CLEARING IN IT.** Sampling x 2300..3850, z -2850..-1400 every 50 studs, exactly **9 of
1,054 points** have no colliding part within 45 studs, and no two of them are adjacent. So the
fourth layout the dispatch asked about -- a clearing with a high seat -- **cannot be placed in this
world as it stands**, and is not shipped. Section 6.

**STRAIGHT LINES OF NINE, by z** (9 stands at x 2430..3630, 150 apart; "ground" = the two readers
agree within `Markers.GROUND_TOLERANCE_STUDS` = 1; "free" = no colliding part within 8 studs):

| z | ground | trunk-free | terrain y |
|---|---|---|---|
| -3050 | 9/9 | 9/9 | 134..200 |
| **-3000** | **9/9** | **9/9** | **132..203** |
| -2950 | 9/9 | 9/9 | 136..201 |
| -2900 | 9/9 | 6/9 | 134..200 |
| -2750 | 9/9 | 4/9 | 129..170 |
| -2600 | 8/9 | 6/9 | 123..172 |
| -2450 | 9/9 | 4/9 | 115..156 |
| -2300 | 9/9 | 9/9 | 109..148 |
| -2200 | 9/9 | 9/9 | 99..159 |
| -2050 | 9/9 | 4/9 | 101..193 |
| -1900 | 9/9 | 4/9 | 113..223 |
| -1700 | 9/9 | 5/9 | 100..266 |
| -1600 | 9/9 | 2/9 | 104..263 |
| -1450 | 9/9 | 7/9 | 108..245 |

**THE SOUTH TREE LINE IS AT z = -2900**, read by walking each of the nine stand columns north from
z = -3300 until a trunk appeared within 25 studs: -2900 at seven of nine columns, -2850 at x 2880,
-2925 at x 3480, and one outlier trunk at x 3030 z = -3175 standing alone in the open.

**TODAY'S ROAD IS 9/9 TRUNK-FREE**, measured the same way on the real sine. That is the bar a new
layout has to meet, and it is why a candidate line is rejected at 6/9 rather than nudged.

**THE LODGE IS IN THE WAY OF THE OBVIOUS EDGE LINE.** `Lobby.anchorFor("forest-test")` is
(x 2850, z -2950) -- 50 studs from the ideal 9-stand edge line at z = -3000. So the edge layout is
moved EAST and shortened: **6 stands, 150 apart, centred x 3480** -> x 3105..3855, the nearest stand
255 studs from the lodge. Measured per stand: ground delta 0.0 and trunk-free at all six, terrain y
148, 148, 172, 192, 223, 228 -- an **80-stud climb west to east**, which is source A's hillside, and
the hunters stand 100 studs out in the open with the tree line in front of them.

**THE RIDE.** Sweeping centres x 3250..3400 and z -2680..-2420 for a 5-stand line 130 apart, seven
candidate lines come out 5/5 trunk-free. Taken: **centre x 3350, z = -2600** -> x 3090..3610, terrain
y 141..163, every stand on ground the two readers agree about, 240 studs clear of the lodge in x.
The push corridor from there is 22 of 25 samples in trees.

**THE BEATERS WALK THE SAME 580 STUDS IN EVERY LAYOUT**, so a drive stays the ~120 s task 162
measured: edge beaters at z = -2420 (inside the wood, 480 studs north of the tree line), ride beaters
at z = -2020 (inside the wood, just north of the road, which they cross). Beater ground was readable
at every lane of both; trunk clearance at the exact lane point was 6/9 (edge) and 4/5 (ride), which
is what `ForestTest.beaterStartPosition`'s existing sideways search is for and is no worse than the
road's.

## 6. What is NOT shipped, and why

1. **A clearing with a high seat.** Measured impossible in this world (section 5): nine isolated
   points, no pocket. Making one means deleting Studio-built trees, which rule 7 forbids and which
   is Karen's call; `tools/mapgen.py` carves the GENERATED map in DEV, not this bought terrain.
2. **A drive on another axis** (an east-west push, or a north push out of the wood's north edge).
   The reason is the signs, section 3. It is the single biggest remaining win -- it would roughly
   double the layouts this one block of wood can hold -- and it is its own task.
3. **Terrain painting or carving.** Nothing here paints or carves; all three layouts sit on the
   ground as it was built.

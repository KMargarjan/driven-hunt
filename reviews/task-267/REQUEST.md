# Task 267 -- review request

Task: 267
Round: 1
Base: c243df86 (main, after PR #246)
Code commit: (filled in at the end of this round)

## PLAN (core quality protocol, step 0 -- committed before any `src/` edit)

### Item 1 (CORE): crossings within shotgun range

**(a) REAL LIFE.** On a German *Druckjagd* the stands are set so that the game's known passes run
past them inside shot range: WILD UND HUND's *"Druckjagdstande -- Sicher ist sicher?"* puts a stand
where the passages converge, and the shotgun/buckshot engagement it is set for is **25-35 m**. The
repo's own road layout already encodes the spacing half of that rule -- 9 stands over 1,200 studs =
150 studs = 42 m apart (`ForestTest.ROAD_LAYOUT`, which cites the same source).

**(b) MEASURED NOW, on Karen's path** -- `<runs-dir>/267-cross.luau` and `267-cross2.luau`, armed in
the Forest Test's Server during Play, sampling every animal under `Workspace.Boars` at 4 Hz and
recording the instant its `z - roadZ(x)` crosses zero. Two full drives, the player enrolled from the
lodge as the hunter (`DHForestStartRole=hunter`) and locked on stand 5:

| drive | crossings | nearest of the NINE stands | the HUNTER's own stand |
|---|---|---|---|
| 1 (`267-before-d1.txt`) | 80 | max **76.1**, 100% within 105, 100% within 175 | max **425.0**, **56.2%** within 105, 70.0% within 175 |
| 5 (`267-before-d5.txt`) | 77 | max **77.5**, 100% within 105, 100% within 175 | max **427.9**, **56.6%** within 105, 64.5% within 175 |

**THE DISPATCH'S OWN METRIC IS ALREADY MET AND IT IS THE WRONG INSTRUMENT, and this is said first
because it changes what the item is.** "Within 25-30 m of at least one hunter's stand" measured
against the nearest of the nine stands is **100% before any change** (worst 77.5 studs = 22 m): the
crossing point is pinned on the road at `hunterStandX() + crossOffset` with `crossOffsets` of only
-70..+95, and the stands are 150 studs apart ON THE SAME ROAD, so "near SOME stand" is true by
construction and cannot fail. It says nothing about whether anybody gets a shot.

**The instrument that answers Karen's sentence is the distance to an OCCUPIED stand** -- with one
player on the line, his own. On that instrument **44% of crossings are out of buckshot range (100
studs) and the worst is 428 studs**, which is the dispatch's measured "137-230 studs" and worse.
So the item is real; only the yardstick in the dispatch is not. Both are reported from here on.

**(c) TARGET.** >= 70% of crossings within **105 studs (30 m)** of the hunter's own stand, and
**none beyond 175 studs (50 m)** -- the dispatch's two numbers, read on the occupied stand. 105
studs is also just inside buckshot's 100-stud reach plus the sine's own z wobble, so "within target"
and "shootable" are the same statement.

**(d) LEVER: `offsetX` in `ForestTest.SCHEDULE.drive`, and the measurement names it.** Every one of
the 27 crossings beyond 175 studs in drive 5 belongs to a row whose `offsetX` is +-185 or more, or to
the stag's sideways sneak -- grouped by the release x the probe recorded (`firstX`):

| firstX | that is | crossings beyond 175 | where they crossed |
|---|---|---|---|
| 2780 = standX **-250** | slot 12, `BREAK-BACK` (no crossing pin at all) | 9 | 2632-2727, 305-398 studs from him |
| 3295 = standX **+265** | slot 15, `HOLD` (no crossing pin at all) | 6 | 3407-3458, 378-428 from him |
| 3265 = standX **+235** | slot 6 `LATERAL`, repeated as slot 16 | 7 | 3291-3354, 262-326 from him |
| 3228 = standX **+200** | slot 11 `SPLIT` | 3 | 3220-3245, 190-215 from him |
| 2935 = standX **-95** | slot 8, THE STAG, 120-stud treeline sneak | 1 | 2817, 213 from him |

The mechanism is visible in the same rows: a group released far out is reached by the beater line
before it reaches its pinned crossing, so **it crosses at its own release x, not at the pin** --
`drift` (crossing x minus release x) is -148..+163 for these, outward. Slot 12 and slot 15 carry no
`crossOffset` at all (`BREAK-BACK` and `HOLD` are written never to cross), so there is nothing to
pull them back when the line finally pushes them over, and they are also the two widest rows in the
table. The writer:

```
src/shared/ForestTest/init.luau:1101:	local x = standX + (spec.offsetX or 0)      -- ForestTest.wavePoint
src/shared/ForestTest/init.luau:1989:			crossOffset = -70,                   -- the SCHEDULE rows, offsetX beside it
src/server/ForestTest/init.luau:2983:	local nominal = Data.wavePoint(standX, row, chosen.layout)
```

So the change is DATA in `ForestTest.SCHEDULE.drive`: cap `|offsetX|`, keeping the left/right and
near/far rhythm (the dispatch's *"do NOT simply pull every animal onto a stand"*), and point the two
`LATERAL` rows' `crossOffset` at the END of their own 150-stud span so the pass no longer doubles
back. Nothing is removed: the fifteen slots, the three acts, the stag's `sneak`/`sneakStuds`/
`sneakDz` and edge check, the deer leap, `files`, the routes and the paces are untouched.

**(e) HOW IT WILL BE MEASURED AFTER.** The same probe file, the same place, the same enrolment, two
full drives, and `267-stats.py` over its output -- the before rows above were produced by that exact
script.

### Item 2: the spectator
See `## ITEM 2` at the end of this file.

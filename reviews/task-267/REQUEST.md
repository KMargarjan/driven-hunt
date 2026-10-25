# Task 267 -- review request

Task: 267
Round: 1
Base: c243df86 (main, after PR #246)
Code commit: 869ac755ebc7b31ac7b42e9c53b8e07eac54e28c

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


## THE HARNESS

```
[harness] PASS: 34/34 checks @ 869ac755ebc7b31ac7b42e9c53b8e07eac54e28c (clean tree) scope=all
```

**`test2` is N/A, and the rule says so rather than my judgement.** The only code file this round
changes is `src/shared/ForestTest/init.luau`, which is not in `TWO_PLAYER_PATHS` in
`tools/agents.py` (that list is `src/server/Match/`, `src/server/MatchBoot.server.luau`,
`src/client/Match/`, `src/client/MatchBoot.client.luau`, `src/shared/Drive/`,
`tests/client/Role.luau` and the specs that test them). The dispatch asked for `test2` because it
expected item 2 to touch `Match`; item 2 is not built this round (see `## ITEM 2` below), so nothing
in the change reaches the match, the drive, the tie or the teams. A second client would release the
same fifteen slots at the same offsets and answer nothing the one-player run did not.

`python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both PASS. No spec file
was added, so no `SCOPE_SPECS` row changed.

## ITERATION (core protocol step 2) -- three cycles, one instrument, Karen's place

Every row is one full Forest Test drive, the player enrolled from the lodge as the hunter and locked
on stand 5, measured by the same probe and summarised by the same script (`267-stats.py`).

| cycle | the change | crossings | within 105 of HIS stand | within 175 | worst |
|---|---|---|---|---|---|
| **before** | -- (`267-before-d1.txt`) | 80 | 56.2 % | 70.0 % | **425.0** |
| **before** | -- (`267-before-d5.txt`) | 77 | 56.6 % | 64.5 % | **427.9** |
| 1 | abs(offsetX) capped at 145 (`267-c1.txt`) | 80 | 59.5 % | 96.2 % | 230.4 |
| 2 | capped at 95 (`267-c2.txt`) | 76 | 78.9 % | 94.7 % | 189.0 |
| 3 | the WEST rows alone to -50..-75 (`267-c3.txt`) | 76 | **73.7 %** | 98.7 % | **180.4** |
| 3 | the same build, a second drive (`267-c3b.txt`) | 77 | **81.6 %** | 97.4 % | **200.1** |

**Cycle 1 taught the cap and cycle 2 taught the asymmetry, and neither was guessed.** Cycle 1 bounded
the tail (425 -> 230) and barely moved the body (56 -> 59 % within 105), because a group released at
+-140 that bolts south crosses at its own release x -- the measured `drift` for those was only -2 to
-35. Cycle 2's 95 put the bolt itself inside the gun's reach, and the four that still failed were
slot 7's nine having drifted 95-104 studs **west** of a release whose pin was **east** of it. Cycle 3
read the sign of the drift off the data -- east rows drift inward, west rows outward -- and tightened
only the west.

## CLAIMS

1. **The dispatch's own metric was already met before the change, and it is the wrong instrument.**
   Measured against the nearest of the nine stands, 100 % of 157 before-crossings were within 105
   studs (worst 77.5). Verify: `267-before-d1.txt` / `267-before-d5.txt` through `267-stats.py`, and
   read why in `ForestTest.wavePoint`'s new comment -- the crossing is pinned on the road at
   `hunterStandX() + crossOffset`, offsets only -70..+95, stands 150 studs apart on the same road.
2. **On the instrument that answers Karen's sentence -- the stand a hunter is actually on -- 44 % of
   crossings were out of buckshot range and the worst was 428 studs.** Verify: the same two files,
   `playerDist` column.
3. **Every before-crossing past 175 studs belonged to a row whose `offsetX` was +-185 or more** (or
   to the stag's sneak). Verify: `267-stats.py 267-before-d5.txt` prints all 27 with the release x
   the probe recorded; group them by `firstX` against the `offsetX` column of
   `ForestTest.SCHEDULE.drive`.
4. **The lever has a writer.** `ForestTest.wavePoint` is the one function that turns a row's
   `offsetX` into a world point, and `releaseLine` is its one caller:
   `src/shared/ForestTest/init.luau` `wavePoint` (`local x = standX + (spec.offsetX or 0)`) and
   `src/server/ForestTest/init.luau` `releaseLine` (`local nominal = Data.wavePoint(standX, row,
   chosen.layout)`).
5. **After, two full drives of the shipped build: 73.7 % and 81.6 % within 105 studs of his own
   stand** -- the dispatch's 70 % met on each drive separately. Verify: `267-c3.txt`, `267-c3b.txt`.
6. **"None beyond 50 m" is NOT met, and it is 3 crossings of 152.** 180.4, 200.1 and 188 studs
   against 50 m = 175. Verify: `267-stats.py` on the two after files. Before, the same bound was
   missed by 27 of 77 in one drive alone and the worst was 428.
7. **Nothing the dispatch asked to keep was touched.** The fifteen slots, three acts, `route` words,
   `files`, `pace`, the deer leap, and slot 8's `sneak`/`sneakStuds`/`sneakDz`/`offsetX` are
   unchanged. Verify: `git diff c243df86..869ac755 -- src/shared/ForestTest/init.luau` -- the only
   value lines are 14 `offsetX` and 2 `crossOffset`.
8. **No `offsetX` is 0, so nothing is pulled onto a stand** (the dispatch's condition): -65, +80,
   -70, +45, -75, +95, -50, -95, -70, +60, +90, -60, +75, +95, +80 -- both flanks, nine distinct
   magnitudes from 45 to 95. Verify: the `offsetX` lines of `ForestTest.SCHEDULE.drive`.
9. **The two `LATERAL` rows' `crossOffset` moved to the end of their own 150-stud span** (-70 -> +20
   on slot 5, +20 -> -35 on slot 6) so the pass finishes at the road instead of doubling back 75
   studs, and **all five of `LINE.crossOffsets` are still used by some row**, which
   `forest_line.spec.luau` asserts. Verify: that spec's "every crossing offset is used" case, green
   in the 34/34 run.
10. **An unintended edit was made and reverted inside the round, and is reported rather than left to
    be found**: a bulk replace also changed `ForestTest.REST`'s `offsetX = 140` to `90`. It is back
    at 140 and the final diff shows no REST line. Verify: claim 7's `git diff`.

## WHAT I COULD NOT VERIFY

- **"None beyond 50 m" (claim 6).** Three of 152 crossings are 5-25 studs past it. All three are a
  group drifting ~105-113 studs sideways while walking to the road; the cap bounds where a group
  STARTS, not how far trees and the beater line push it on the way. Closing the last 25 studs needs
  a lever on the drift itself (steering the final approach toward the pin), which is code and not
  data, and is not this item.
- **No frame of a crossing from the shooter's eye.** `ftplay.py capture` raised
  `FileNotFoundError: [WinError 3] ... ''` on the output path and the drive had ended before a
  retry would have found animals in front of the stand; the probe had already read the six-animal
  file at 74-111 studs that the frame was meant to show (`267-eye.luau` output, in the ledger).
  **NOT OBTAINABLE this round**, reported rather than silently dropped. The protocol's step 3 for a
  behaviour item is a counted drive before and after, which claims 1-6 are.

## ITEM 2 (the spectator): NOT BUILT THIS ROUND

Nothing was written for it -- no `src/` file, no spec, no commit. Item 1's core protocol (two
before-drives, three measured cycles, two after-drives, each one a ~6-minute live drive in Karen's
place) plus the gate consumed the dispatch's 2.5 h. Item 1 is CORE by the dispatch's own words and
was taken to completion rather than both being left half-measured.

**Two things found on the way that the next round needs, and the second one blocks the item as
written:**

1. **The client trigger already exists.** `drive.through == true` reaches the client and
   `Hud/Objective.luau` already renders `DriverThrough = "you are through - wait"` from it. The
   spectator's line replaces that row; no new feed field is needed.
2. **THE FOUNDATION THE DISPATCH CALLS SETTLED IS NOT.** `reviews/task-261/RESULT.md`'s own notes
   say `Match.CONFIG.BEATER_THROUGH.HOLD = false` does not release the beater at all -- `Body.stand`
   -> `Body.standCharacter` -> `Body.holdCharacter` already zeroes WalkSpeed and anchors the root,
   while `applyHold` only records `heldStill[userId]` and `applyFree` only restores a userId that is
   in it. So the man is frozen and anchored in **both** states of that row and nothing in this owner
   ever unties him. "This replaces the hold behind the stands" therefore cannot be done by flipping
   `HOLD`; `throughSweep` has to stop anchoring him. The same notes record that the freeze itself was
   task 261's own choice and not the Director's words, and that `throughSweep`'s "walked back and
   held" is asserted by no spec (`beatersWalkedBack` is named nowhere in `tests/`). A spectator built
   on it today would inherit an unverified and self-contradicting hold.

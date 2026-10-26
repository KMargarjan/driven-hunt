# Task 267 -- review request

Task: 267
Round: 2
Base: c243df86 (main, after PR #246)
Code commit: 5ba76627dd01c67bb4198c7a4f60300c4060b006

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
[harness] PASS: 34/34 checks @ 5ba76627dd01c67bb4198c7a4f60300c4060b006 (clean tree) scope=all
```

**`test2` is N/A, and the rule says so rather than my judgement.** The only code file this round
changes is `src/shared/ForestTest/init.luau`, which is not in `TWO_PLAYER_PATHS` in
`tools/agents.py` (that list is `src/server/Match/`, `src/server/MatchBoot.server.luau`,
`src/client/Match/`, `src/client/MatchBoot.client.luau`, `src/shared/Drive/`,
`tests/client/Role.luau` and the specs that test them). The dispatch asked for `test2` because it
expected item 2 to touch `Match`; item 2 is not built this round (see `## ITEM 2` below), so nothing
in the change reaches the match, the drive, the tie or the teams.

**Round 1 was right that the reason I first gave for it -- "a second client would answer nothing" --
does not hold, and it is withdrawn.** `ForestTest.hunterStandX` returns the first LOCKED pick, one
stand for the whole drive, and this change narrows the release corridor from +-250 to +-95 around
THAT stand, so a second hunter standing anywhere else now sees strictly less than he did before.
That is pre-existing single-stand aim made more pronounced, not something the change invents, and it
is queued in `TASKS.md` as 267a rather than argued away here. `test2` is N/A on the mechanical rule
alone.

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
| r2 | round 1's fix: the two `LATERAL` pins put back AHEAD of their pass (`267-r2.txt`) | 76 | **72.0 %** | 97.3 % | **195.9** |

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
   `offsetX` into a world point: `src/shared/ForestTest/init.luau` `wavePoint`
   (`local x = standX + (spec.offsetX or 0)`), reached from `src/server/ForestTest/init.luau`
   `releaseLine` (`local nominal = Data.wavePoint(standX, row, chosen.layout)`).
   **Round 1 corrected this claim and the correction stands**: `releaseLine` is NOT its only caller.
   `ForestTest.release` (the pre-task-127 wave path) and `ForestTest.roarPoint` call it too, and
   `ForestTest.waveAt`'s own comment says *"BOTH release paths read the same rows through this one
   function"*. No behaviour consequence -- `roarPoint` reads the stag row, whose `offsetX` this
   change leaves at -95, and `release` moves in the same direction as `releaseLine` -- but the blast
   radius is three callers, not one.
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
9. **The two `LATERAL` rows' pins are AHEAD of the end of their own pass, in its direction of
   travel -- and round 1 caught me shipping them BEHIND it.** `lateralSign` is +1 for `"RtoL"` and
   -1 for `"LtoR"`, and `WAVE.lateralSpan` is 150, so slot 5 (`offsetX` -75, `"RtoL"`) travels +X and
   its pass ends at +75, and slot 6 (`offsetX` +95, `"LtoR"`) travels -X and ends at -55. Round 1
   shipped pins of +20 and -35 -- 55 and 20 studs BACK the way the group had come, which is the
   doubling back the change claimed to remove and which the base data did not have. They are now
   **+95 and -70**, 20 and 15 studs onward. Verify: `ForestTest.lateralSign` and `releaseLine`'s
   `walkTo`/`acrossAt` against slots 5 and 6, and the live console of the re-measurement drive,
   which prints `offset +95, crossing -70 studs` for slot 6 (`267-r2-console.txt`).
   **All five of `LINE.crossOffsets` are still used by some row** (-70 by slots 1, 6, 9; -35 by 3, 7,
   8; 20 by 4; 55 by 2, 10; 95 by 5, 11, 14), which `forest_line.spec.luau` asserts -- green in the
   34/34 run. That case is a guardrail and not proof of this change: round 1's note is right that it
   passes byte-for-byte on the reverted tree, because the base rows use the same five values.
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


## ROUND 2 -- what changed, and why there is a round 2 at all

Round 1 returned **two blocking findings and both were right.** Neither was a wording quarrel: one
was a behaviour fault I introduced and claimed the opposite of.

1. **The `LATERAL` pins were moved the wrong way** -- claim 9 above, rewritten to the real
   arithmetic. The base data already satisfied the rule; my change broke it and the comment asserted
   the reverse. Fixed at `25d21b14` (slot 5 -> +95, slot 6 -> -70) and **re-measured on Karen's path**
   (`267-r2.txt`, the `r2` row of the iteration table): 72.0 % within 105 studs of his own stand,
   97.3 % within 175, worst 195.9 -- in line with the two cycle-3 drives and no regression.
2. **The comment's rhythm sentence listed cycle 2's `offsetX` values, not the shipped ones**, and
   contradicted the paragraph above it in the same comment. It now reads the fifteen shipped rows and
   nine distinct magnitudes.

Three of round 1's non-blocking notes are also taken, because each was a statement of mine that was
not true: claim 4's "one caller" (now three), the `test2` paragraph's over-reach (withdrawn, queued
as 267a), and the comment's *"inside 105 BY ARITHMETIC"* -- `amplitudeStuds` 30 with
`SHAPE.wavelengthDivisor` 70 lets `roadZ` move ~60 studs over 95 studs of x, so the worst case is
`sqrt(95^2 + 60^2)` = 112, not 102. The comment now states the typical figure AND the bound, and says
the after-drives are the measurement of which.

**Queued rather than done this round** (round 1's notes, and rule 4): a pure spec case over the
`LATERAL` rows -- pin ahead of `offsetX + lateralSign * lateralSpan`, in the direction of travel --
which is the case that would have caught finding 1 and which nothing in `tests/` relates today.

## HANDOVER (core protocol step 5)

- **Item 1 (CORE), "at least 70 % of crossings within 30 m of a stand": MET.** Measured on the stand
  the hunter is actually on, three full drives of the fixed build: 73.7 %, 81.6 %, 72.0 % within 105
  studs, against 56.2 % and 56.6 % before. On the dispatch's literal yardstick -- the nearest of the
  nine stands -- it was 100 % before the change and is 100 % after; that metric cannot fail and is
  not what Karen is feeling.
- **Item 1, "and none beyond 50 m": NOT MET.** Three crossings of 152 on the cycle-3 build and two
  of 76 on the fixed build land at 176-200 studs instead of 175. Before, 27 of 77 in a single drive
  were past that bound and the worst was 428. Nobody has yet seen a drive in which every animal
  crosses inside 50 m.
- **Item 1, the picture: NOT PROVEN.** The numbers are attested by four counted drives; **no frame of
  a crossing from the shooter's eye was obtained** (`ftplay.py capture` raised `FileNotFoundError` on
  its output path and the drive had ended). Nobody has looked at this change.
- **Item 2 (the spectator): NOT BUILT.** Not started, not stubbed, nothing in `src/`. See `## ITEM 2`
  -- and read point 2 there before dispatching it again: the hold it is written to replace is
  anchored in both states of its own config row, which task 261's review said and nothing has fixed.

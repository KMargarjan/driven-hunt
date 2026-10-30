# Task 315 -- the shooting range moves straight out of the shop door

Task: 315
Round: 2
Base: d4b10eda (origin/main)
Code commit: c9086a27cc3b39aec17b1300cc5f78afc382645c

```
[harness] PASS: 34/34 checks @ c9086a27cc3b39aec17b1300cc5f78afc382645c (clean tree) scope=all
```

`test2` is **N/A** and that is the tool's answer, not an opinion: `agents.needs_two_player` over this
branch's changed files returns `[]`.

**Karen, 2026-10-30, with a frame:** *"those trees can be removed and shooting range can be moved
there that I can directly from shop walk to shooting range same distance but straight"*.

Design: `docs/design/shooting-range-lobby.md` (task 315, ARCH_RESULT PASS).
Measurements taken at main before a line of code: `reviews/task-315/BRIEF.md`.

---

## The three round-1 findings

**F1 -- the redundancy assertion was a tautology.** Correct, and it is now the falsifiable form the
finding named. `own == 0` IS "all 25 points are inside the others", so re-asserting
`insideHome(at, others)` under `if own == 0` restated its own guard. `lobby.spec`
*"sends him back the moment he steps off ANY of the three rectangles"* now reads
`expect(own).to.equal(0, ...)` under the existing `if here == 0` guard -- which is
`here > 0 or own == 0` -- and it **would have reddened at d4b10eda**, where the walkway had
`here == 0` and `own > 0`. *Verify:* set the range anchor back to (2600, -3030) and that case fails.

**F2 -- no frame was described.** Fixed below: every frame is named, opened and described. The
request no longer claims a look it did not record.

**F3 -- the counters had no spec, and design items 11 and 13 were missing.** Both written, in
`lobby.spec`:
* *"plants nothing in the corridor, and BOTH counters carry the number through Lobby.stats"* drives
  the real `Build.build` with the two seams and a `Session` fixture where the pine stood; it asserts
  0 trees planted in either rectangle, `sightlineDropped > 0`, `sightlineCleared == 1`, the fixture
  destroyed, and the avenue empty. **Its bite is the same build with no rectangles handed in**:
  both counters 0 and the avenue planted. Deleting any `stats.sightlineDropped += 1`, or the two
  mirror lines in `Lobby.tryBuild`, now reddens it.
* *"leaves a man home at every single stud of the walk from the shop door to every mat"* is item 13:
  every one-stud sample of all six door-to-mat walks is `insideHome`, the z -3060..-3057 seam
  included, with the field-alone count (>100 samples off home) as its bite.

Three notes taken while cheap: the census prints the **first** foreign part, not the nearest, and now
says so; the fence case reads `fenceRuns` off the split row it built; the flagpole's *"291 studs from
the range"* comment was stale two tasks before this one and now records the measured 2-stud margin.
The remaining notes are for `TASKS.md`.

## Claims

**1. The move is TWO NUMBERS and a translation.** `Range.ANCHORS["forest-test"]` is `x = 2790,
z = -3090`; `plate`, `downrange`, `drawn`, `berm`, `fill`, `shelfFrom`, `keepOut` and **every row of
`Range.LAYOUT`** are untouched. *Verify:* `git diff d4b10eda..c9086a27 -- src/shared/Range/init.luau`.

**2. The walk is straight and +0.9% of today's.** Live, off the built `DoorThreshold`: nearest mat
**174.31 studs at 3.95 deg** off the door's facing, against **172.84 at 48.76 deg**. *Verify:*
`range.spec`'s anchor-row case, which asserts the station row's centre IS the lodge's centre line and
the distance and angle, derived rather than typed.

**3. The walk is DEAD LEVEL.** 151 samples at 1-stud steps on each of x 2838 / 2850 / 2862 from
z -2940 to -3090: **150.00 everywhere, spread 0.00, worst step 0.00**; the seam at z -3060 reads
150.00 both sides. *Verify:* `range.spec`'s keep-out case -- `cutRects` returns ONE rectangle whose
`maxZ` is the lobby field's south edge read from `Lobby.CONFIG`, overlap 0.

**4. The split-terrace arm did not go dark**: driven by a synthetic row 40 studs north of the
field's edge in both `range.spec` cases that relied on the live row.

**5. The trees go by a RULE with one owner.** `Range.sightlineFrom` is pure with no writer;
`Build.sightlineRect` closes the fourth edge with the LODGE's south face; `Build.keptClear` has
exactly four readers. **The range removes nothing it did not create.** The rectangles reach the lobby
as plain tables through OPTIONAL `keepClear` / `sightline` seams composed by `ForestTestBoot` beside
`rangeHomeAreas`. *Verify:* `grep -n keptClear src/server/Lobby/Build.luau`; `lobby.spec`
*"keptClear bites on every measured trunk and on nothing a player uses"*, where every one of the
eleven measured trunks answers **false** when no range is handed in.

**6. It removed what Karen pointed at, counted.** `[lobby] the walk to the range: 12 of our trees not
planted in the corridor, 1 of the world's taken off it` and `[RangeBoot] footprint census: 0 foreign
BaseParts`, both at this code commit. Live census: 0 trees in the corridor, 0 in the footprint. The
pine (`Workspace.Session.Tree8`, place content, 104.7 studs) is gone, **at run time, never by a
Studio click and never by an edit to the place**.

**7. Task 311's avenue stands no trees, named not hidden.** `AVENUE.SLOTS` is not edited (rule 7).
*Verify:* `Build.avenuePlan` plants 0 with the range handed in and **>= 5 without it**.

**8. The range still works where it stands** -- real keys and clicks, in HER place, at this commit.
Real `W` from the door: **174.8 studs in 10.9 s, X unchanged at 2850.0, no turn.** Real `E` at
station 2 opened the menu, lanes still 107 / 125 / 179. A real click chose RUN; the boar swept
**153.5 studs, 153% of that station's own 100.3-stud span**. A real click chose STAND; a real shot
landed -- board **SHOTS 2, HITS 1, MISS 1, CHEST 1 at 119 studs**. The treestand's F prompt and its
15.1-stud deck work.

## The frames (rule 5) -- each opened and described

In `<runs-dir>/playtest/range-move/`. Viewport 948 x 795 of the full-screen grab.

1. **`karen-2026-10-30-trees.png` (hers, BEFORE)** -- yard gravel, compass needle 15.6 deg past S; a
   row of leafy birches fills the frame with one tall narrow conifer behind; the range's numbered
   canopies are small at the far left behind a grass bank.
2. **`315-AFTER-karen-spot.png`** -- her spot and heading reproduced. The row of birches is gone, the
   conifer is gone, and **all six station huts stand in the open straight ahead** with the berm
   behind them. One birch survives at the far left, outside the corridor.
3. **`315-BEFORE-door-south.png`** -- from the shop door looking due S (compass S centred). A birch
   trunk stands squarely in the middle of the frame; **no part of the range is visible**.
4. **`315-AFTER-door-south.png`** -- same spot, same heading, after. The birch is gone and **all six
   numbered huts are visible across the frame** over level ground. This is the answer to her
   sentence.
5. **`315-walk-seam.png`** -- mid-walk at (2850, -3000), eye height, due S. Stations **1 2 3 4 5 6**
   in one unbroken row; the ground runs flat and continuous to them with **no step or bank at
   z -3060**; a lobby fence post in the foreground; no trunk between the viewer and any station.
6. **`315-walk-arrival.png`** -- where the real `W` walk ended, on the mown lane looking downrange:
   the berm across the far end with the natural hill rising above and behind it. The berm faces
   away from the lodge, which is behind the camera.
7. **`315-E-menu.png` / `315-E-run-selected.png` / `315-stand-selected.png`** -- the SHOOTING RANGE
   panel open from a real `E`; RUN, then STAND, highlighted green by a real click, with the cursor
   on the button.
8. **`315-board4.png`** -- the hit card: `SHOTS 2 HITS 1 MISS 1`, `CHEST 1`, `DISTANCE 119 studs`.
9. **`315-deck-top.png`** -- the treestand deck, 15.1 studs up, "TREESTAND / Climb down" prompt live,
   plank deck underfoot, the whole berm in view.
10. **`315-AFTER-old-site.png`** -- the old site from the yard on the same bearing as the before
    frame: open green hillside and distant hills. No mat, no post, no fence, no earth heap. The one
    hut at the right edge is the NEW range's station 1.

## What I could not verify

* **A real hit on a RUNNING target.** The click transport's aim-to-fire latency measured **~2.5 s**;
  at 24 studs/s that is 60 studs of lead and the target reverses at the span ends. The hit is on a
  **STAND** target -- the pace whose own purpose is to isolate aim from lead -- and the RUN crossing
  is proven as a measurement instead.
* **How the new cut faces LOOK.** The terrace cuts up to 35.8 studs at its south-east corner against
  ~21 at the old site. No frame was taken of the east face from close up; **nobody has looked at
  it**, and Karen's eye decides it. Queued, not claimed.
* **`TASKS.md` 313a(o)** is open and is NOT a defect of this move: the board read `crossing 9.07 s`
  against the 4.18 s setpoint, the same discrepancy 313 recorded at the OLD anchor (9.13 s).
* **`TASKS.md` 313a(a)** is open: nobody has looked at an invisible (solo) player in her place.
* **`weapon_client.spec:1211` and `:1263` are intermittent, and I am not calling them anything
  else.** At THIS code commit two consecutive full runs disagreed: the first reported 662 passed /
  2 failed (`Expected 12, got 14`; `Expected 2, got 0` -- replayed ammo counts), the second reported
  `664 passed, 0 failed` and 34/34, which is the line pasted above. Same sha, same tree, both runs
  mine. They are not the spec the dispatch names, and nothing in this branch touches the weapon path.
* **The board first read `SHOTS 0` on this branch.** A control at `d4b10eda` in the same place with
  the same sequence read `SHOTS 1`; re-running the control's exact sequence on this branch then read
  `SHOTS 1` too. The cause was my own no-cursor-move firing script, not the move.

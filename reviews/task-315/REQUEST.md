# Task 315 -- the shooting range moves straight out of the shop door

Task: 315
Round: 1
Base: d4b10eda (origin/main)
Code commit: adbbe3ce2918df2f773f0fa0b13a20cdf622805b

```
[harness] PASS: 34/34 checks @ adbbe3ce2918df2f773f0fa0b13a20cdf622805b (clean tree) scope=all
```

`test2` is **N/A** and that is the tool's answer, not an opinion: `agents.needs_two_player` over this
branch's 13 changed files returns `[]` -- none of `src/shared/Range/`, `src/server/Lobby/`,
`src/server/ForestTestBoot.server.luau`, `src/server/RangeBoot.server.luau` or the three server specs
is in `TWO_PLAYER_PATHS`.

**Karen, 2026-10-30, with a frame:** *"those trees can be removed and shooting range can be moved
there that I can directly from shop walk to shooting range same distance but straight"*.

Design: `docs/design/shooting-range-lobby.md` (task 315, ARCH_RESULT PASS). Brief, with every
measurement taken at main before a line of code: `reviews/task-315/BRIEF.md`.

---

## Claims

**1. The range moved by TWO NUMBERS and nothing else; it is a translation.**
`Range.ANCHORS["forest-test"]` is now `x = 2790, z = -3090`. `plate`, `downrange`, `drawn`, `berm`,
`fill`, `shelfFrom` and `keepOut` are untouched, and **no row of `Range.LAYOUT` changed**.
*Verify:* `git diff d4b10eda..adbbe3ce -- src/shared/Range/init.luau` -- the only value changes are
those two numbers plus the new pure `Range.sightlineFrom`. `range.spec`'s two shipped cases pinning
`shelfFrom` and `keepOut` against `Lobby`'s own config pass unedited.

**2. The walk is straight and within +-15% of today's.** Measured live in Karen's place at the code
commit, off the built `DoorThreshold` part: nearest mat **174.31 studs at 3.95 deg off the door's own
facing**, against **172.84 at 48.76 deg** before -- **+0.9%**. All six stations 174.31..183.97.
*Verify:* `range.spec` *"has a row for the DEV place and one for Karen's"*, which now asserts the
station row's centre IS the lodge's centre line and the walk's distance and angle, **derived instead
of two typed numbers**; and the live probe output quoted in the report.

**3. The walk is DEAD LEVEL, and the two terraces meet on one voxel plane.** 151 ground samples at
1-stud steps on each of x 2838 / 2850 / 2862 from z -2940 to -3090 read **150.00 everywhere: spread
0.00, worst step 0.00**. The seam at z -3060 reads 150.00 on both sides.
*Verify:* `range.spec`'s keep-out case now asserts `cutRects(...)` returns **one** rectangle whose
`maxZ` equals the lobby field's south edge read from `Lobby.CONFIG`, with terrace-field overlap 0.

**4. The two-rectangle terrace arm did not go dark.** The live row no longer splits, so the split arm
is driven **by parameter** -- a synthetic row 40 studs north of the field's south edge -- in both
`range.spec` cases that used to rely on the live row.
*Verify:* the `FOREST_ROW_SPLIT` / `northRow` locals in `range.spec`; deleting them must redden.

**5. The trees go by a RULE, with one owner and no new remover.** `Range.sightlineFrom` is pure and
has no writer; `Build.sightlineRect` closes the fourth edge with the LODGE's own south face;
`Build.keptClear` is the one predicate and has exactly four readers -- `treeLine`, `lodgeTrees`,
`avenuePlan` and `clearWorkingGround`. **The range removes nothing it did not create.** The two
rectangles reach the lobby as plain tables of numbers through new OPTIONAL `keepClear` / `sightline`
seams on `Lobby.start`, composed by `ForestTestBoot` in the same `do` block that already composes
`rangeHomeAreas`, so neither owner requires the other.
*Verify:* `grep -n "keptClear" src/server/Lobby/Build.luau` -- four call sites and the definition;
`lobby.spec` *"keptClear bites on every measured trunk and on nothing a player uses"*, which asserts
all eleven MEASURED trunks are cleared **and** that with `keepClear = nil, lane = nil` not one of
them is -- the no-range world, bit for bit.

**6. It removed what Karen pointed at, counted.** Boot line in her place at the code commit:
`[lobby] the walk to the range: 12 of our trees not planted in the corridor, 1 of the world's taken
off it`. Live census afterwards: **0 trees standing in the corridor, 0 in the footprint**;
`[RangeBoot] footprint census: 0 foreign BaseParts`. The pine -- `Workspace.Session.Tree8`, place
content, 104.7 studs, which stood inside the new footprint -- is gone, **removed at run time by the
lobby's existing sweep, never by a Studio click and never by an edit to the place**.
*Verify:* the boot lines, and `lobby.spec` *"sweeps a fixture in the range's footprint and in its
corridor, and spares one beside each"*, which builds its own `Session` folder and asserts the
`keepClear = nil` case removes **nothing**.

**7. The birch avenue of task 311 now stands no trees, and that is named rather than hidden.**
`AVENUE.SLOTS` is **not edited** (rule 7): all six standing birches are dropped by the corridor rule,
because the range now sits at the south end of the road the avenue lined. Karen asked for the avenue
on 2026-10-28 and for these trees gone on 2026-10-30; the later word is taken as the current one.
*Verify:* `lobby.spec` *"keeps the flagpole out of the range's corridor, and plants no avenue trunk
inside it"* -- `Build.avenuePlan` plants 0 with the range handed in and **>= 5 without it**, which is
the bite. The replaced case and its reason are in `backups/2026-10-30_task-315_range-anchor.txt`.

**8. Seven spec cases changed because the MOVE changed their arithmetic, not because of a defect**,
and each is re-expressed as the property it was really asserting. Named individually in the commit
message of `78fc4b94` and in `backups/2026-10-30_task-315_range-anchor.txt` section 3. The two that
matter most: task 302's *"leaves a man at the range... and returns him without the seam"* lost its
bite because the walk is now short enough to lie inside the lobby field -- it carries the six mats
instead; and the walkway rectangle is now genuinely redundant, so `lobby.spec` allows a redundant
rectangle but still reddens on one that is **neither redundant nor contributing**.
*Verify:* `git diff d4b10eda..adbbe3ce -- tests/`.

**9. Two instruments were found blind by the FIRST live run and fixed before this request.**
`[RangeBoot] footprint census` printed *"3 foreign BaseParts"* while the pine was in fact removed a
moment later -- the two boots run in no defined order -- so the census is taken once the server has
settled. And `Lobby.stats().sightlineDropped` lived only in `Build`'s table, so the boot's log line
raised `invalid argument #2 to 'format'` and **aborted `reportLobby`**, taking four other lobby lines
with it (measured, `ForestTestBoot:819`). Both are commits of their own, both re-measured after.
*Verify:* `c2ea81f1` and `adbbe3ce`; the boot lines quoted in claim 6 come from the fixed build.

**10. The whole range still works where it stands, proven with real keys and clicks in HER place at
the code commit.** Real `W` from the shop door: **174.8 studs in 10.9 s on a dead-straight line, X
unchanged at 2850.0, no turn**. Real `E` at station 2 opened the menu with the three lanes still
107 / 125 / 179. A real click selected RUN; the released boar swept **153.5 studs of X, 153% of that
station's own 100.3-stud sight span** (task 313's wide span, intact). A real click selected STAND;
a real shot landed -- board reads **SHOTS 2, HITS 1, MISS 1, CHEST 1 at 119 studs**. The treestand
climb prompt and its 15.1-stud deck still work.
*Verify:* the frames in `<runs-dir>/playtest/range-move/`, each opened and described in the report.

## What I could not verify

* **A real hit on a RUNNING target.** The click transport's aim-to-fire latency measured **~2.5 s**;
  at the boar's 24 studs/s that is 60 studs of lead, and the target reverses at the span ends. The
  hit was landed on a **STAND** target -- the pace whose own purpose is to isolate aim from lead --
  and the RUN crossing is proven as a measurement instead. Stated, not papered over.
* **`TASKS.md` 313a(o) is open and is NOT a defect of this move:** the boar does not hold RUN pace
  across the wide span. The board read `crossing 9.07 s` here against the 4.18 s setpoint, which is
  the same discrepancy 313 recorded at the OLD anchor (9.13 s). Pre-existing.
* **`TASKS.md` 313a(a) is open:** nobody has looked at an invisible (solo) player in her place. This
  move does not re-close it.
* **How the new cut faces LOOK.** The terrace cuts up to 35.8 studs at its south-east corner against
  ~21 at the old site. The design leaves the faces as the fill makes them and queues a batter as a
  LOOK task. I photographed the lane, the berm and the deck; **nobody has looked at the east face
  from close up**, and Karen's eye decides it.
* **A control run at main was needed once and is reported in full:** the board first read `SHOTS 0`
  on this branch. A control at `d4b10eda` in the same place, with the same sequence, read `SHOTS 1`.
  Re-running the control's exact sequence on this branch then read `SHOTS 1` as well. The cause was
  my own no-cursor-move firing script, not the move; both builds behave identically.

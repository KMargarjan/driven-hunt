# Task 352 — forest all round: A1, A2's gaps, and the outer edge

Task: 352
Round: 2
Base: origin/main (42a25d46, #369)
Code commit: 26426cb5c41215c9ad11edc7e78803b99da93ba4

```
[harness] PASS: 34/34 checks @ 26426cb5c41215c9ad11edc7e78803b99da93ba4 (clean tree) scope=all
```

```
[bake] selftest: PASS
```

`[harness2]` is **N/A**: nothing under `TWO_PLAYER_PATHS` changed. The diff is
`src/shared/Places/`, `src/shared/Grid/`, `src/shared/ForestTest/init.luau` (one line:
`LAYOUT_ORDER`), `src/server/ForestTestBoot.server.luau` (comments), `src/client/Hud/MapUi.luau`
(comments), `tools/terrainbake.py`, and five specs — no `Match/`, no `Drive/`, no `Role.luau`, no
match spec. No flake fired: 0 failed and 0 errors on both sides.

`26426cb5` is the commit that carries round 1's `RESULT.md`; the last `src/`, `tests/` or `tools/`
change is `b2c0d567`, which it sits directly on top of.

**Karen, 2026-11-12, on the painted map with three areas ringed in red** (`<runs-dir>/refs/
karen-2026-11-12-more-trees-marked.png`): *"marked where need more trees like edges has to be with
trees also feeling forest and those gaps also full of trees"*, then *"rest is ok"*.

## Round 1's two findings, closed

1. **`tools/terrainbake.py` refusal 10 — right, and worse than the finding said.** It greps for the
   literal `ForestTest.LAYOUT_ORDER = Grid.PLANTED_CELLS`, so the split disabled `trim` and
   `trim plan` outright and turned `terrainbake.py selftest` — a CI step — red. Fixed:
   `planted_cells(name)` reads either list, `rotation_cells()` names the one refusal 10 is about,
   and the refusal checks the ROTATION's cells (round 1's consequence (c)) as well as its line.
   *Verify:* `trim_rotation_problem`; the selftest case now passes the new line **and refuses the
   old one**; a case added asserting the two lists are read apart —
   `PASS the two Grid lists are read apart: ROTATION_CELLS is a subset of PLANTED_CELLS and A1 is
   the difference  planted=C1,C2,A2,B1,D1,B2,D2,A1 rotation=C1,C2,A2,B1,D1,B2,D2`.
   The claim *"a DATA change inside one owner"* was wrong and is withdrawn: a tool outside the
   owner parses that line, and the request now pastes the `[bake] selftest` line beside the harness.

2. **`352-after.txt` was truncated — my own pipeline, not the probe.** The run was written with
   `… | tee 352-after.txt | head -14`; `head` closed the pipe and `tee` stopped mid-token at 24
   stand rows. The file is re-run complete at the code commit: 38 lines, **26 stand rows**, the two
   A1 rows readable, the canary on line 3. `352-table.txt` is regenerated from it and asserts the
   26/26 count as it builds. Every number it quoted is unchanged.

## Claims

1. **A1 has a wood, and it is not in the drive rotation.** `Grid.PLANTED_CELLS` is all eight;
   `Grid.ROTATION_CELLS` is the seven baked ones and `ForestTest.LAYOUT_ORDER` **is** that table.
   A1's roads are not cut and its landform is not shaped, so a drive there would stand hunters on
   raw ground; a wood needs no bake. *Verify:* `Grid.init`'s two lists; `grid.spec` "deals ONLY the
   rotation cells…" asserts `order == Grid.ROTATION_CELLS`, that every dealt name is in
   `PLANTED_CELLS`, and that A1 is planted and not dealt. `forest_stand.spec` now compares
   `LAYOUT_ORDER[1]` with `ROTATION_CELLS[1]` (round 1 note).

2. **The identity that was deleted is replaced by a subset.** `grid.spec` "is a list of baked
   cells…" asserts `#PLANTED_CELLS == 8`, A1 last, A1 absent from `ROTATION_CELLS`, and every
   rotation cell present in `PLANTED_CELLS`. `terrainbake.py selftest` asserts the same relation
   from outside Studio.

3. **A1 is one kind of forest, like the other seven** (task 336's rule). `spruceSlope` drew four
   groups through `spruceThicket` / `mixedWood` / `spruceHigh`; it now draws `spruceLarchAll` /
   `spruceLarchUnder` — conifer and `young`, equal weights, a pair no other cell carries — and its
   frontage band is its own larch. *Verify:* `Places.CELL_MIXES`, the `spruceSlope` row, and
   `grid.spec` "gives each planted cell its own species…", whose `WANT` table carries
   `A1 = { "conifer", "young" }` and refuses a planted cell that is not in it.

4. **A1's clearing is closed, and no recipe has one left.** *Verify:* `grid.spec`'s recipe case
   asserts `clear == 0` for every cell; `grid_ground.spec` "declares no clearing in any recipe…"
   counts zero 0-spacing zones over all eight. **Declared, not hidden:** nothing in the suite can
   now reach `maskGrid`'s `CLEARING` arm. The arm and `REASON.CLEARING` are kept for a recipe that
   cuts a glade again, that case's header says so, and round 1's note asking for a parameterised
   plan or the arm's removal is queued rather than done — it is a change to `maskGrid`'s signature.

5. **A1 takes THE DENSITY RULE.** 26/60/12 → C1's 24/52/11, and every zone carries the 30-stud
   second storey. *Verify:* the `spruceSlope` row; `grid.spec`'s density case measures A1 inside the
   ±10 % band of C1's pinned 2,418 (A1's own wood **2,301**, 95 %), and A1's whole plan is **4,225**
   against `CELL_PART_CAP` **4,255** — 30 of headroom, the tightest cell in the world.

6. **A2's south band and west third are wood.** The two rectangles Karen ringed were already planted
   at 24 and 25 studs; what read as a gap was the SCALE — band `shrub` is 0.30–0.55 of an
   `aspenUnder` sapling. Band and mix only. **Two side effects, now in the comment as well as here**
   (round 1 notes): A2's plan moves 4,213 → 4,172 and its own wood 2,356 → 2,414, because
   `minGapStuds` 11 refuses full-size crowns the saplings fitted between; and `aspenAll` is in
   `FERN_MIXES` where `aspenUnder` is not, so those two rectangles gain the fern floor.

7. **The view from every stand, before and after, from ONE instrument.** `352-table.txt`,
   `MEASUREMENTS.md` §1, `352-before.txt`, `352-after.txt`. 36 rays at 10°, eye height, 150 studs,
   against **that cell's own plan** (one cell stands at a time), excluding directions that spend
   half their length in a road, a lane or a **cut ride**. 26 stands; 2 below the 90 % target before,
   2 after. Every run prints a canary naming the module that ran.

8. **The target the dispatch names was already met, and this change did not move it.** All
   seventeen C1 and D1 rows are identical before and after — nothing in their recipes moved. The net
   movement on stands a player can stand on is B1-11 86.7 → 90.3 and A2-8 93.3 → 100.0, against
   A2-4 96.7 → 93.3, B1-4 100.0 → 96.7 and A2-14 90.0 → 86.7. **NOT MET: A2-14 and A1-11 at 86.7 %.**
   `MEASUREMENTS.md` §4 has three cycles: the lever (`skirtFullStuds`) reaches 90.0 % at 110 but
   puts A2 **118 models over the cap**, and at 90 — which fits — A2-14 drops to **76.7 %**, because
   changing a band's width re-rolls its whole seeded grid. Not a dial, so 80 is kept.

9. **A1's 2,301 own trees cannot stand in the played world until A1 is baked and dealt** (round 1
   note, and it is right). One cell stands at a time, and A1 is out of the rotation. What a player
   gains today is the map patch, the neighbours' skirt species across A1's shared roads (B1's skirt
   1,607 → 1,665, A2's 1,857 → 1,758), and A1's quadrant of the outer ring, 0 on the ground →
   **1,031**. The three A1 stand rows are marked in `352-table.txt` as a view no hunter can occupy
   **in either column**.

10. **The outer ring: already planted; the PICTURE was what was bare.** Each boundary cell's skirt
    runs to `SKIRT_DEEPEST_STUDS` 420 past the footprint, cheap past 150 — 4,418 ring trees before
    this task. `MapUi.groundFromGrid` and `<runs-dir>/350/paint.py` draw one patch per CELL ZONE and
    no skirt, which is why the map Karen marked ends in grass. **Denser is out of budget and says
    so**: raising `PART_BUDGET_CELL` crosses 328g's measured frame ceiling, and that frame can only
    be read in Karen's place.

## Could not be verified

`<runs-dir>/352-devworld.txt`, measured in a DEV Play server: `OurForest: ABSENT`,
`Sources: ABSENT`, `Places.templates found 0 template folder(s)`, `Places.stats(GridPlaces):
folder=false total=0`. DEV draws **no tree**, so no frame of this wood exists there; the only place
with the templates is Karen's Forest Test, which the Director's 14:30 addendum forbids touching.

**Rule 5 is NOT met and round 1's note saying so stands.** NOT OBTAINABLE this session, each for
that one reason: the stand-11 and outer-edge frames; client frame p95 and memory; the cell-load
hitch (337c measured it at C1 661 ms / B2 573 ms against a 500 ms target and marked it NOT MET —
that is the starting point, not a clean baseline); 349's action numbers from stands 4 and 11; the
real-click stand pick. The scripts that would do each exist and were not run (`ftplay.py capture`,
`346-cam.luau`, `ft-open.sh`).

**Nobody has planted A1 yet.** The wood reaches the world through `python tools/terrainbake.py plant
--cells A1 --backup <f>.rbxl` in the Forest Test's Edit session, which rays every site and refuses
the ones over a cliff — the same route and the same answer-by-measurement task 336 used for B2 and
D2. A1 has never been in a bake, so its `cliff` count is unknown until that command runs. Director's
step.

**The only picture is a preview of the DATA.** `<runs-dir>/352/painted-icons.png` is
`<runs-dir>/350/paint.py` — the render Karen marked — with its copy of the repo tables brought up to
date, A1 added and the outer skirt drawn. Opened and read beside `350/painted-icons.png`: A1 goes
from olive grass labelled `empty` to a full cell of spruce-and-larch wood; A2's pale west crescent
and pale south band go to wood (the lighter patch left at A2's north edge is its `aspenUnder` shrub
band, unchanged and unmarked by Karen); the wide olive margin on all four sides goes to forest
running off every edge. Unchanged and checked: the roads are still pale open lanes, and the C1 box,
the stand dots and the orange `YOU` marker are where they were. 350's own note says it renders
canopy denser than the ground, so it is cited as "her picture on the new data", nothing more.

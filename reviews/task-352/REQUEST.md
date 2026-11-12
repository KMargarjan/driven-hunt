# Task 352 — forest all round: A1, A2's gaps, and the outer edge

Task: 352
Round: 1
Base: origin/main (42a25d46, #369)
Code commit: 7a283b2fbdfcd63186976b0679e0c07faf9efbc6

```
[harness] PASS: 34/34 checks @ 7a283b2fbdfcd63186976b0679e0c07faf9efbc6 (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing under `TWO_PLAYER_PATHS` changed. The diff is
`src/shared/Places/`, `src/shared/Grid/`, `src/shared/ForestTest/init.luau` (one line:
`LAYOUT_ORDER`), `src/server/ForestTestBoot.server.luau` (comments only), `src/client/Hud/MapUi.luau`
(comments only), and four specs — no `Match/`, no `Drive/`, no `Role.luau`, no match spec. No flake
fired in this run; the suite is 34/34 with 0 failed and 0 errors on both sides.

**Karen, 2026-11-12, on the painted map with three areas ringed in red** (`<runs-dir>/refs/
karen-2026-11-12-more-trees-marked.png`): *"marked where need more trees like edges has to be with
trees also feeling forest and those gaps also full of trees"*, then *"rest is ok"*.

This is a DATA change inside one owner. No new asset, no upload, no new system, no flag.

## Claims

1. **A1 has a wood, and it is not in the drive rotation.** `Grid.PLANTED_CELLS` is all eight cells;
   `Grid.ROTATION_CELLS` is the seven baked ones and `ForestTest.LAYOUT_ORDER` **is** that table.
   A1's roads are not cut and its landform is not shaped, so a drive there would stand hunters on
   raw ground; a wood needs no bake. *Verify:* `Grid.init`'s two lists and their header;
   `grid.spec` "deals ONLY the rotation cells…" asserts `order == Grid.ROTATION_CELLS`, that every
   dealt name is in `PLANTED_CELLS`, and that A1 is in the planted list and not in the rotation.

2. **The identity that was deleted is replaced by a subset, not dropped.** `grid.spec` "is a list of
   baked cells…" asserts `#PLANTED_CELLS == 8`, A1 last, A1 absent from `ROTATION_CELLS`, and every
   rotation cell present in `PLANTED_CELLS`. *Verify:* that case.

3. **A1 is one kind of forest, like the other seven** (task 336's rule). `spruceSlope` drew four
   groups through `spruceThicket` / `mixedWood` / `spruceHigh`; it now draws `spruceLarchAll` /
   `spruceLarchUnder` — conifer and `young`, equal weights, a pair no other cell carries — and its
   frontage band is its own larch instead of four groups the cell does not otherwise contain.
   *Verify:* `Places.CELL_MIXES`, the `spruceSlope` row, and `grid.spec` "gives each planted cell its
   own species…", whose `WANT` table now carries `A1 = { "conifer", "young" }` and refuses a planted
   cell that is not in the table.

4. **A1's clearing is closed, and no recipe has one left.** The `zone(0.20, 0.55, 0.80, 0.74, 0,
   "clearing", …)` rectangle was 60 % × 19 % of the cell. *Verify:* `grid.spec`'s recipe case now
   asserts `clear == 0` for every cell (it used to assert A1 as the one exception), and
   `grid_ground.spec` "declares no clearing in any recipe…" counts zero 0-spacing zones over all
   eight recipes. **Coverage note, declared not hidden:** with no 0-spacing zone anywhere, nothing in
   the suite can now reach `maskGrid`'s `CLEARING` arm. The arm and `REASON.CLEARING` are kept for a
   recipe that cuts a glade again, and that spec case says so in its header.

5. **A1 takes THE DENSITY RULE.** `spacingStuds` 26 → 24, `deepSpacingStuds` 60 → 52,
   `minGapStuds` 12 → 11 — C1's accepted numbers, the same three the other recipes took in 328i —
   and every zone carries the 30-stud second storey task 336 gave the other six. *Verify:* the
   `spruceSlope` row; `grid.spec`'s density case now measures A1 inside the ±10 % band of C1's
   pinned 2,418 (A1's own wood is **2,301**, 95 %), and A1's whole plan is **4,225** against
   `CELL_PART_CAP` **4,255** — 30 of headroom, the tightest cell in the world.

6. **A2's south band and west third are wood, at the same tree count.** The two rectangles Karen
   ringed were already planted at 24 and 25 studs; what read as a gap was the SCALE — band `shrub`
   is `shrubScale` 0.30–0.55 of an `aspenUnder` sapling. Band and mix only (`wood` / `aspenAll`);
   the pitch, the `rows = "NS"` plantation and the second storey are untouched. *Verify:* the
   `aspenRolling` row; A2's total moves 4,213 → 4,172 (the small drop is `minGapStuds` rejecting
   full-size crowns the saplings fitted between), and its own wood 2,356 → 2,414.

7. **The view from every stand, before and after, from ONE instrument.**
   `reviews/task-352/352-table.txt` and `MEASUREMENTS.md` §1. 36 rays per stand at 10°, eye height,
   150 studs, measured against **that cell's own plan** (`Places.Cells` stands one cell and stores
   the rest, so a hunter never sees another cell's wood), excluding directions that spend half their
   length in a road, a lane **or a cut ride**. 26 stands; 2 below the 90 % target before, 2 after.
   *Verify:* `<runs-dir>/352-measure.luau`, `352-before.txt`, `352-after.txt`; the before run is the
   same file against `origin/main` with `src/` stashed, and every run prints a canary naming the
   module that actually ran.

8. **NOT MET, declared: two stands are at 86.7 %.** A2-14 (90.0 → 86.7) and A1-11 (plan 93.3 →
   86.7). Three cycles are in `MEASUREMENTS.md` §4: the lever (`skirtFullStuds`) reaches 90.0 % at
   110 but puts A2 **118 models over `CELL_PART_CAP`**, and at 90 — which fits — A2-14 drops to
   **76.7 %**, because changing a band's width re-rolls its whole seeded grid. The knob is not a
   dial, so the shipped 80 is kept and the two stands are reported rather than tuned to a lucky
   number.

9. **The outer ring: already planted, and the PICTURE is what was bare.** Each boundary cell's
   skirt runs to `SKIRT_DEEPEST_STUDS` 420 past the footprint and is cheap past 150 — 4,418 trees
   before this task. `MapUi.groundFromGrid` and `<runs-dir>/350/paint.py` draw one patch per CELL
   ZONE and no skirt at all, which is why the map Karen marked ends in grass. A1's quadrant of the
   ring went 0 → **1,031**. *Verify:* `MEASUREMENTS.md` §3 and the ring column of the table.
   **Denser is out of budget and says so**: raising `PART_BUDGET_CELL` crosses 328g's measured frame
   ceiling, and that frame can only be read in Karen's place.

10. **What could not be verified, with the reading that says so.** `<runs-dir>/352-devworld.txt`:
    DEV holds `OurForest: ABSENT`, `Sources: ABSENT`, `Places.templates found 0 template folder(s)`,
    `Places.stats(GridPlaces): total=0` — DEV draws **no tree**, so no frame of this wood exists
    there. The only place with the templates is Karen's Forest Test and the Director's 14:30
    addendum forbids touching it. NOT OBTAINABLE for that one reason: the stand-11 and outer-edge
    frames; client frame p95 and memory; the cell-load hitch; 349's action numbers from stands 4 and
    11; the real-click stand pick. The scripts that would do each exist and were not run
    (`ftplay.py capture`, `346-cam.luau`, `ft-open.sh`). **What IS on screen:**
    `<runs-dir>/352/painted-icons.png`, the same render Karen marked, re-run on the new data — see
    below.

## The picture Karen marked, re-rendered

`<runs-dir>/350/paint.py` reads a COPY of the repo tables (`cells.json`, `zones.json`) and a
hard-coded `PLANTED` list, not the repo files. `<runs-dir>/352/` is that script with the copy
brought up to date, A1 added, **and the outer skirt drawn**. Opened and read side by side with
`350/painted-icons.png`:

* **A1**: olive grass with the word `empty` → a full cell of wood, dark spruce with larch through it.
* **A2**: the pale bare crescent on its west and the pale band along its south → wood. The lighter
  patch left at A2's north edge is its `aspenUnder` shrub band, which Karen did not mark and which
  is unchanged.
* **The outer border**: a wide olive margin on all four sides → forest running off every edge of
  the frame.
* Unchanged, checked: the roads are still pale open lanes between the cells, the C1 box, the stand
  dots and the orange `YOU` marker are where they were.

**It is a preview of the DATA, not a frame of the world**, and 350's own note says it renders canopy
denser than the ground. It is cited as "the picture she marked, on the new data", nothing more.

## Could not be verified

Everything in claim 10, plus: **nobody has planted A1 yet.** The wood reaches the world through
`python tools/terrainbake.py plant --cells A1 --backup <f>.rbxl` in the Forest Test's Edit session,
which rays every site and refuses the ones over a cliff — the same route and the same answer-by-
measurement task 336 used for B2 and D2, whose landform was held. A1 has never been in a bake at
all, so its `cliff` count is unknown until that command runs. It is the Director's step.

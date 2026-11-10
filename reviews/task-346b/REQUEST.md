# Task 346b — the deeper forest, proven cheap and made full

Task: 346b
Round: 1
Base: a36899b6 (origin/main, PR #360)
Code commit: b397aa4184942f0681fed7f5fa611d0d96bd7e20

Harness, clean tree, full scope, at the code commit:

```
[harness] PASS: 34/34 checks @ b397aa4184942f0681fed7f5fa611d0d96bd7e20 (clean tree) scope=all
```

The first gate run, before the five count/space fixes, for the two-commit control the flake rule
asks for:

```
[harness] FAIL: 31/34 checks @ 1d2bc385856d84a97ff2d9a04249af7582b16822 (clean tree) scope=all
```

`test2` is **N/A**: nothing here is in `TWO_PLAYER_PATHS` (`src/shared/Places/`,
`src/server/Places/`, two server specs). **No flake fired in the passing run.** `deer_hitbox.spec:682`
(on the dispatch's known list) fired once, only in the deliberate producer-deleted run of section 8
of `MEASUREMENTS.md`, which is a dirty-tree run and not evidence for anything else.

## What changed

The deepest skirt band — the one task 346 added, 230 to 420 studs past the shared road — is now
**scenery**: no shadow, no collision, no raycast. The saving is spent on planting it tighter, 34
studs instead of the plan's `deepSpacingStuds` 52. Karen, 2026-11-10: *"more tree needs behind, it
has to be feeling animals run away to another forest"*.

All numbers below are in `reviews/task-346b/MEASUREMENTS.md`, measured in Karen's Forest Test with
the cell replanted from this worktree through `terrainbake.plant_prelude()`.

## Claims

1. **A band is cheap by its own near edge.** `Places.SKIRT_CHEAP_FROM_STUDS` = 150; `skirtBands`
   sets `cheap = band.near >= that` and substitutes `Places.SKIRT_CHEAP_SPACING_STUDS` for the
   band's spacing. Today exactly one band qualifies, the deepest (near 230). *Verify:*
   `Places.skirtBands` in `src/shared/Places/init.luau`; `grid.spec` case 16b asserts
   `band.cheap == true` with `band.spacing == SKIRT_CHEAP_SPACING_STUDS` on the deepest band and
   `cheap == false` on the near ones, for all eight cells.
2. **Cheap reaches the planting and then the clone.** `ScatterOpts.cheap` → the `Planting.cheap`
   field → `Places.plantOne`, which clears `CastShadow`, `CanCollide`, `CanQuery` and `CanTouch` on
   every `BasePart` and publishes `DrivePlaceCheap` so a probe can count it. *Verify:*
   `Places.plantOne` in `src/server/Places/init.luau`; `grid_ground.spec`'s "a cheap far-band clone
   casts no shadow…" case plants the SAME template with and without the flag and asserts 0 shadows /
   0 collisions / 0 queries against a control that keeps both.
3. **The road end's horizon is full.** The dispatch's MEASURED NOW: the open fraction along the F3
   camera ray goes **81.0 % before 346 → 21.6 % at #360 → 0 %** (0 of 37 picture columns with no
   tree), 8 → 58 → **118 trees in frame**. *Verify:* `MEASUREMENTS.md` section 5;
   `<runs-dir>/346b-ray.luau` and its per-side JSON.
4. **That instrument has a control (L-141).** F1, standing inside the wood Karen accepted in task
   328s, reads 0 % open with 1,969–2,008 trees on every side, so a low count at F3 is a hole and not
   the instrument's floor. Two raycast sweeps were tried first and both read a frame that plainly
   shows conifers as 100 % open; they are described and discarded in section 2.
5. **The frame budget is met, and the band is cheaper than the one it replaces.** Client p95 at C1
   stand 8, median of three guarded samples: **23.35 (before 346) → 23.93 (#360) → 20.31 (after)**.
   A2: 20.12 → 21.48 → **21.83**, inside the +2 ms. Memory +82.3 / +89.8 MB against +300.
   *Verify:* `MEASUREMENTS.md` section 3.
6. **Two of the dispatch's budget lines are NOT MET, and were not met before this task.** The cell
   swap's worst SERVER frame is 655 / 746 / **783 ms** against a 100 ms ceiling, and the drive-start
   wait is 14.11 / 13.98 / **14.07 s** against 5 s. Both are now measured rather than inferred (346
   recorded them NOT PROVEN / NOT MEASURED), and both are standing defects of the swap and of the
   one-player lobby. *Verify:* `346b-swapframe.luau`, `346b-padwait.luau`, section 3.
7. **The delete-and-fail proof was RUN (L-093).** With `cheap` forced false, C1 falls back to
   3,507 models / 12,927 parts / 0 cheap and F3 to 21.6 % open with 58 trees — **exactly** the
   measured #360 column. The suite was run against the deletion: `grid.spec:2687` reddens. The
   `plantOne` half's bite is argued by reading, not run, and section 8 says so.
8. **The caps rise and say why.** `PART_BUDGET_CELL` 14,200 → 16,000 and `PART_BUDGET_DRIVE`
   29,000 → 32,000, with `CELL_PART_CAP`/`CELL_PLAN_CAP` computed from them as before. C1 goes
   3,507 → 3,969 models and 12,927 → 14,628 parts. The comment states that a part ceiling is a typo
   guard and the gate is the measured frame. `grid.spec`'s pinned counts move with it (3,558/3,574
   → 4,020/4,036) and the comments name the task.
9. **Four instrument faults were found and fixed before anything was claimed** (rule 6), section 1.
   One of them reaches task 346: its `346-after-F3.png`, labelled "the north road end", is the view
   the same instrument produces for the **NE corner**, because `346-cam.luau` parks the camera only
   after a 15 s raycast loop while the driver shoots at 16 s.
10. **Three frames, each opened and described** (section 10), and the attribute diff is empty but
    for the harness's own stage clock (L-101, section 9).

## What I could not verify

- **F2, C1's NE corner, is still 29.7 % open** (11 of 37 columns), down from 40.5 % but not closed.
  Measured as structural, not thin: the dead bearings are 1–25 degrees and the wedge is the strip
  0–230 studs north of the footprint east of C1's frontage, which no band reaches because the
  widening is confined to the deepest band on purpose (task 346's own recorded reason). Filling it
  means widening a near band across another cell's frontage — **a design decision for the Director,
  not a Builder call.** Section 5.
- The two NOT MET budget lines of claim 6 are left as they are: both are outside this task's files.
- No `src/shared/Places` or `src/server/Places` path is in `TWO_PLAYER_PATHS`, so no two-player run
  was made.

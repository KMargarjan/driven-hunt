# Task 347: the M map reads like real ground, with clear icons

Task: 347
Round: 2
Base: bec076ef (origin/main, #367)
Code commit: c5195de34c108b9784fdf27216cfd6ccc4aa951a

Karen, 2026-11-10: *"map is odd and hard to understand what and where it has to be clean and nice as
I showed you exmple / please improve map visuals and selection postion to be clear with icons and
actial map terrain as I send example"*.

Behind **`MAP_LOOK`, born OFF**. OFF is today's map, value for value.

```
[harness] PASS: 34/34 checks @ c5195de34c108b9784fdf27216cfd6ccc4aa951a (clean tree) scope=all
```

`test2`: **N/A**. Nothing in `TWO_PLAYER_PATHS` is touched -- the diff is `src/client/Hud/MapUi.luau`,
`src/client/Hud/init.luau`, `src/shared/Flags/init.luau`, `tests/client/map_ui.spec.luau` and docs.

## What changed

1. **The ground layer is the planter's own table.** `Places.CELL_PLANS[recipe].zones` over the seven
   cells `Grid.PLANTED_CELLS` names is **42 rectangles**, each with the lattice pitch the planter
   used (`spacingStuds`; **0 plants nothing**), a mix name and a wood/shrub band.
   `MapUi.groundFromGrid` turns each into a `GroundPatch` with a kind (`conifer` / `broadleaf` /
   `mixed` / `scrub` / `open`) and a density, drawn as **eight columns TRANSLATED by the world's
   bend**. Full-map only, under every existing mark, built once per cell set.
2. **A sparse deterministic tree stipple on the dealt cell only**, rolled in the producer off
   `Grid.seedFor`, so it is the same picture on every open and on every client.
3. **The LODGE icon**, pinned to the border, and **six more legend rows in the SAME well**, whose
   height is now derived (`MapUi.legendHeightPx`) instead of a constant that held exactly six.
4. **`MAX_FLAGS` 25 -> 26**, the sixth time, for the reason that block already writes out.

## Round 1's three findings, all of which were right

| # | What it was | What it is now |
|---|---|---|
| 1 | A1 carries `recipe = "spruceSlope"` and no wood, so the producer painted six patches of conifer under the words `A1 empty` | `groundFromGrid` reads `grid.PLANTED_CELLS`, as `geometryFromGrid` already did. **48 zones -> 42** |
| 2 | The projection case compared `Grid.standPosition` with its own definition -- 0.00 px by construction, and still 0.00 with the layer deleted | It asks whether any stand or any sample of the cell's four roads stands INSIDE a band `MapUi.groundColumns` drew. **It fired on its first run** and found a real defect (below) |
| 3 | The cost case passed with the producer returning nil (it timed the flag-off map twice) | It asserts the timed geometry HAS a layer and that the layer reached the canvas, and says in its own header that the rebuild counter guards the architecture rather than this task |

**And finding 2's new case found a real defect in the drawing, on its first run:** stand 12 at
(-3386, -4736) sat **15.2 studs inside a drawn wood band of its own cell**. A bend is a SHEAR, so
the bounding box of a column's four bent corners is strictly LARGER than the band it stands for, and
the surplus is wood over the carriageway. A column now keeps its own grid size and takes the CENTRE
of its bent corners, and there are eight instead of four. Worst now: **0.00 studs**.

## Claims, and how to verify each

1. **OFF IS TODAY'S MAP.** `geometryFor` without `places` returns a geometry whose `ground` and
   `lodge` are nil, and `Hud` hands those two in **only** while `MapUi.GROUND.ENABLED`
   (`Flags.isOn("MAP_LOOK")`, this module's one read, at its boundary). Case *"is one patch per
   planting zone, and NOTHING without the planting data"*.
2. **A CELL WITH NO WOOD GETS NO GROUND.** The same case counts the zones of the **planted** cells,
   asserts that list really differs from "the cells with a recipe" (`expect(withRecipe > wanted)`),
   and refuses a patch for any unplanted cell by name; the drawn case refuses a `GroundA1_*` child
   on the canvas. Harness line: `42 planting zones become 42 ground patches`.
3. **L-093, THE PRODUCER DELETED.** Make `MapUi.groundFromGrid` `return nil` and three lines fail:
   `expect(bands >= #model.ground)` in the drawn case, `expect(#bands > 0)` in the projection case,
   and `expect(#on.ground > 0)` in the cost case. None of them reads the producer's own table for
   its expectation.
4. **THE GROUND AND THE ICONS SHARE ONE PROJECTION** (the dispatch's spec). Three parts, each with
   `MapUi.groundColumns`' output on one side: no stand inside a band of its own cell, every zone's
   own middle inside the band drawn for it (with `Places.zoneIndexAt` asked the world question
   independently), and no sample of the cell's four roads inside a band. A dropped or mis-signed
   bend moves a band up to 45-60 studs, which is 24 studs past the road's 21-stud half-width; the
   floor is 6. Measured: `15 stands at worst 0.00 studs inside a wood band, 7 zone middles inside
   their own band, worst band reach over the four roads 0.0 studs`.
5. **THE BUDGET.** `open p50 0.20 / 0.16 ms, max 0.58 / 0.55 ms (off / on); build worst 14.9 /
   37.1 ms (336 bands drawn); 0 ground rebuild(s) over 6 ticks, map open`, and **1,317 UI instances**
   against the 1,500 ceiling. The case fails if an open passes 50 ms, if the timed build drew fewer
   bands than the geometry has patches, or if the ground is rebuilt once while the map sits open.
6. **IT IS ACTUALLY ON SCREEN, AND ROUND 1's FIRST DRAFT WAS NOT.** `Hud`'s ScreenGui is
   `ZIndexBehavior.Global` (probed live), so `Z_INDEX - 2` drew all the bands BEHIND the panel: the
   C1 pixels read `(28, 25, 21)` -- the panel's own colour -- in the flag-off and flag-on frames
   alike. At `Z_INDEX` the layer clears the panel and stays under the marks by tree order, and
   `map_ui.spec` fails on any `Ground*` or `Tree*` child below the panel's band.
7. **MEASURED IN KAREN'S FOREST TEST AT C1, flag ON vs OFF** (`347-map-probe.luau`, instance facts
   read out of `PlayerGui`, 06:30-06:51 UTC):

   | | OFF | ON |
   |---|---|---|
   | open-map UI instances | **297** | **1029** at that commit (**1,317** at the code commit, 8 columns) |
   | client frame time p95, map open | **32.62 ms** | **31.59 ms** |

   The probe's own `require` of `Hud` hands back a FRESH module (`sameModule=false`, printed), so the
   ms in claim 5 are DEV numbers on the real started module and the FT contributes instance facts
   only. The probe prints that limit rather than hiding it.
8. **FRAMES, opened and described -- AND THEY PREDATE THE CODE COMMIT, which is said out loud.**
   `<runs-dir>/347-BEFORE-map.png` (OFF) and `<runs-dir>/347-AFTER-final.png` (ON) are both from her
   Forest Test at C1, from two real `M` key presses, at commit `3dbdb5d2`. BEFORE: eight white cell
   outlines and eight curving roads on a FLAT BLACK panel, orange stands, a six-row legend. AFTER:
   B1 and A2 read as solid dark-green conifer, C1 and D1 as tan broadleaf with grey scrub bands, the
   roads curve over them, the stipple speckles C1, the LODGE pin sits at the top-right border, the
   legend is twelve rows in one well. **The AFTER frame therefore shows A1 painted and 4 boxed
   columns, both of which this round fixed** -- so it proves the layer renders and is NOT a picture
   of the code commit. Her FT was back on `:34873` before the 07:45 UTC cutoff, so a frame at this
   commit is `ESCALATE.md`'s *"Director: FT frame needed"*.
9. **NO WATER IS DRAWN, AND THAT IS A MEASUREMENT.** `TerrainBake` REFUSES any tile holding a water
   column, in its own words, so this world has none and a water layer would be a producer with an
   empty input. `ESCALATE.md` section 2.
10. **THE CLICK PROOF IS `NOT PROVEN`.** The stand-pick window never opened in ~9 minutes of live
    play (`pickable=0` from a probe polling all fifteen pads, four waits of 105-110 s).
    `ESCALATE.md` section 1 has the readings.

## What I could not verify

* **The real click on a pad** (claim 10). No `Assigning` window occurred; nothing was clickable.
* **A frame at the code commit** (claim 8). The frames are from `3dbdb5d2`; the FT was restored to
  `:34873`, Edit, before the cutoff and Karen wakes ~08:00.
* **End-to-end "key down to map visible" milliseconds in her place.** The probe gets a fresh `Hud`
  module, so those ms are DEV numbers.
* **Whether Karen likes it.** It reads as a quilt of hard-edged zone rectangles, not the painterly
  reference. `ESCALATE.md` section 3 states the two ways on, one of which needs her OK to upload.

## Flakes seen, named, and what was done

Three runs at or next to this branch each failed ONE different spec and never the same one twice:
`deer_hitbox.spec:659` + `gun_client.spec:393` @ `db9a0069` (06:52 UTC), `report_panel.spec:540` @
`db9a0069` (06:57), then the input-replay transport (`Target is not reachable`, not a spec) @
`9e1d3bed` (07:02). `deer_hitbox.spec:659` is in the dispatch's named flake list; the other two were
**mine** and are fixed, not excused -- the cost case cycled the ONE live Hud sixteen times and
`setGeometry(nil)` hands back the modal mouse, so it was cut to two builds and five opens. The three
runs since (`9e1d3bed` 07:07, `34319bdd` 07:36, `c5195de3` 07:41) are all **34/34, 0 failed**.

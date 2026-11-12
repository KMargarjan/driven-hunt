# Task 347: the M map reads like real ground, with clear icons

Task: 347
Round: 1
Base: bec076ef (origin/main, #367)
Code commit: 9e1d3bedccb96dbdeace268ffb93a23a8def95ff

Karen, 2026-11-10: *"map is odd and hard to understand what and where it has to be clean and nice as
I showed you exmple / please improve map visuals and selection postion to be clear with icons and
actial map terrain as I send example"*.

Behind **`MAP_LOOK`, born OFF**. OFF is today's map, value for value.

```
[harness] PASS: 34/34 checks @ 9e1d3bedccb96dbdeace268ffb93a23a8def95ff (clean tree) scope=all
```

`test2`: **N/A**. Nothing in `TWO_PLAYER_PATHS` is touched -- the diff is `src/client/Hud/MapUi.luau`,
`src/client/Hud/init.luau`, `src/shared/Flags/init.luau`, `tests/client/map_ui.spec.luau` and docs.

## What changed

1. **The ground layer is the planter's own table.** `Places.CELL_PLANS[recipe].zones` is 48
   rectangles over the eight cells, each with the lattice pitch the planter used (`spacingStuds`;
   **0 plants nothing**), a mix name and a wood/shrub band. `MapUi.groundFromGrid` turns each into a
   `GroundPatch` with a kind (`conifer` / `broadleaf` / `mixed` / `scrub` / `open`) and a density,
   pushed through `Grid.toWorld` as four bend-following column strips. Drawn full-map-only, under
   every existing mark, built once per cell set.
2. **A sparse deterministic tree stipple on the dealt cell only**, rolled in the producer off
   `Grid.seedFor` so it is the same picture on every open and on every client.
3. **The LODGE icon**, pinned to the border. **Six more legend rows in the SAME well**, whose height
   is now derived (`MapUi.legendHeightPx`) instead of a constant that held exactly six.
4. **`MAX_FLAGS` 25 -> 26**, the sixth time, for the reason that block already writes out.

## Claims, and how to verify each

1. **OFF IS TODAY'S MAP.** `MapUi.geometryFor` without `places` returns a geometry whose `ground`
   and `lodge` are nil, and `Hud` hands those two in **only** while `MapUi.GROUND.ENABLED`
   (`Flags.isOn("MAP_LOOK")`, read once at this module's boundary). Case *"is one patch per planting
   zone, and NOTHING without the planting data"*.
2. **L-093, THE PRODUCER DELETED.** Make `MapUi.groundFromGrid` `return nil` and the line that fails
   is `expect(bands >= #(model).ground)` in *"draws the ground, the tree marks and the lodge, and
   stays inside the budget"* -- it counts `Ground<cell>_*` frames on the DRAWN canvas, not on the
   table. Harness line: `map_ui 347 drawn: 192 ground bands over 7 planted cells, 166 tree marks,
   lodge pinned, 1029 instances`.
3. **THE GROUND AND THE ICONS SHARE ONE PROJECTION** (the dispatch's own spec). Case *"THE GROUND AND
   THE ICONS SHARE ONE PROJECTION"*: each stand's pixel by the icon path (`rawOffsetPx` of
   `Grid.standPosition`) against its pixel by the ground path (`standGridOf` -> `Grid.toWorld` ->
   `rawOffsetPx`), and each zone's own middle inside the band drawn for it, with `Places.zoneIndexAt`
   asked the world question independently. Measured: **15 stands agree to 0.00 px, 7 zone middles
   inside their own band, worst band reach over the main road 0.0 studs**.
4. **THE BUDGET.** `map_ui 347 cost (DEV): open p50 0.16 / 0.19 ms, max 0.81 / 0.48 ms (off / on);
   build worst 14.9 / 31.6 ms; 0 ground rebuild(s) over 6 ticks with the map open`, and **1029 UI
   instances** against the 1,500 ceiling. The case fails if an open passes 50 ms or the ground is
   rebuilt once while the map sits open.
5. **IT IS ACTUALLY ON SCREEN, AND ROUND 1 PROVED IT WAS NOT.** `Hud`'s ScreenGui is
   `ZIndexBehavior.Global` (probed live), so the first draft's `Z_INDEX - 2` drew all 192 bands
   BEHIND the panel: the C1 pixels read `(28, 25, 21)` -- the panel's own colour -- in the flag-off
   and the flag-on frame alike. Fixed to `Z_INDEX`, kept under the boxes and roads by tree order, and
   `map_ui.spec` now fails on any `Ground*` or `Tree*` child under the panel's band.
6. **MEASURED IN KAREN'S FOREST TEST AT C1, flag ON vs OFF** (`347-map-probe.luau`, instance facts
   read out of `PlayerGui`):

   | | OFF | ON |
   |---|---|---|
   | open-map UI instances | **297** | **1029** (192 ground bands, 166 tree marks) |
   | client frame time p95, map open | **32.62 ms** | **31.59 ms** |

   The probe's own `require` of `Hud` hands back a FRESH module (`sameModule=false`, printed), so the
   ms in claim 4 are DEV spec numbers on the real started module, and the FT numbers above are
   instance facts only. That limit is printed by the probe rather than hidden.
7. **FRAMES, opened and described.** `<runs-dir>/347-BEFORE-map.png` (OFF) and
   `<runs-dir>/347-AFTER-final.png` (ON), same cell C1, same panel, both from two real `M` key
   presses in her Forest Test. BEFORE: eight white cell outlines and eight curving roads on a FLAT
   BLACK panel, orange stands, a six-row legend. AFTER: B1 and A2 read as solid dark-green conifer,
   C1 and D1 as tan broadleaf with grey scrub bands, the roads curve over them, the stipple speckles
   C1, the LODGE pin sits at the top-right border, and the legend is twelve rows in one well.
8. **NO WATER IS DRAWN, AND THAT IS A MEASUREMENT.** `TerrainBake` REFUSES any tile holding a water
   column (its own refusal message), so this world has none and a water layer would be a producer
   with an empty input. `ESCALATE.md` section 2.
9. **THE CLICK PROOF IS `NOT PROVEN`.** The stand-pick window never opened in ~9 minutes of live
   play (`pickable=0` from a probe polling all fifteen pads, four waits of 105-110 s). `ESCALATE.md`
   section 1 has the readings.

## What I could not verify

* **The real click on a pad** (claim 9). No Assigning window occurred; nothing was clickable.
* **End-to-end "key down to map visible" milliseconds in her place.** The probe gets a fresh `Hud`
  module, so the ms are DEV spec numbers (claim 4) and the FT contributes instance facts only.
* **Whether Karen likes it.** It reads as a quilt of hard-edged zone rectangles, not the painterly
  reference. `ESCALATE.md` section 3 states the two ways on, one of which needs her OK to upload.

## Flakes seen, named, and what was done

Three runs at or next to this commit each failed ONE different spec and never the same one twice:
`deer_hitbox.spec:659` + `gun_client.spec:393` @ `db9a0069` (06:52 UTC), `report_panel.spec:540` @
`db9a0069` (06:57), then the input-replay transport (`Target is not reachable`, not a spec) @
`9e1d3bed` (07:02). `deer_hitbox.spec:659` is in the dispatch's named flake list. The other two were
**mine** and are fixed, not excused: the cost case cycled the ONE live Hud sixteen times and
`setGeometry(nil)` hands back the modal mouse, so it was cut to two builds and five opens -- after
which `9e1d3bed` ran **34/34 with 2955 server and 696 client cases, 0 failed**.

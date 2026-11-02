# Task 328d -- BAKE C1: the bake, its road, its tool, and the two hard stops

Task: 328d
Round: 2
Base: main (`6b520717`)
Code commit: `c7bdbd96786c0ea2e1ef9d7baa0ef156a9e88a5e`

```
[harness] PASS: 34/34 checks @ c7bdbd96786c0ea2e1ef9d7baa0ef156a9e88a5e (clean tree) scope=all
```

`test2` N/A: no path in `TWO_PLAYER_PATHS` is touched.

## What changed

`src/serverstorage/TerrainBake/init.luau` (new), `tools/terrainbake.py` (new) with its selftest as
a CI step, two `BLAST_RADIUS` rows, nineteen cases in `tests/server/grid_relief.spec.luau`, three
additive functions in `src/shared/Grid/Relief.luau`, a `.gitignore` line, `TASKS.md`, `ESCALATE.md`.

**THE BAKE DID NOT RUN AND NO `WriteVoxels` TOUCHED KAREN'S PLACE** (claim 1). Everything readable
read-only was read; everything else is `NOT OBTAINABLE` in claim 10 and is not claimed.

## PLAN (core protocol step 0), as it resolved

- **(a) THE DESIGN:** a forest road is level across and graded along -- 8 % E-W, 10 % N-S, crossfall
  under 0.5 st over 44, a 2-st ditch in two whole voxel columns (7.1; 15 item 2).
- **(b) MEASURED NOW** in her place, `<runs-dir>/328d-base.luau`: C1's base spans 61.73 st (min
  89.16, max 150.89, mean 113.20, 3,888 rays); its four road centrelines fall 21.99 / 52.25 / 63.61
  / 28.99 st with worst 20-st steps of **9.2 / 18.4 / 26.5 / 13.7 %**, every one over its clamp; and
  `Grid.standPosition`'s fixed Y 106.98 is up to **24.33 st** off the ground -- **stand 10 is buried
  24.33 st** today.
- **(c) TARGET:** those clamps, and the ditch at 2 st +- 1.0 (else the 4-st fallback).
- **(d) LEVER:** `TerrainBake.longProfile` and `TerrainBake.roadAt`, written this round; the write is
  `TerrainBake.bakeTile` -> `Terrain:WriteVoxels`.
- **(e) AFTER:** the same probe and the same three cameras.
- **(b) CONTRADICTED THE DISPATCH and the run stopped there**, 13:56 UTC, before any workaround was
  designed (V280). `ESCALATE.md` carries it.

## Claims

1. **Three hard stops, each with a control** -- `ESCALATE.md`, 2026-11-02 ~13:56 UTC. (i) the backup
   folder is empty; (ii) **Team Create reads ON** -- `FindService("NetworkClient")` answers
   `NetworkClient` and `Players:GetPlayers()` holds 1 (the owner) where **DEV answers `nil` and 0**,
   same Studio, same probe (`328d-tc.luau`); (iii) in her **Edit** session **297 of 297** scripts
   read `Source` length 0 and `require` fails on every one, where DEV reads 27,750 and requires
   fine (`328d-src.luau`, `328d-req2.luau`) -- which takes out both halves of design 3's ruling.
   **It is Edit-only:** the same place's PLAY server requires `Grid` and reads 27,750
   (`328d-playprobe.luau`). Play was started and stopped with the place in Edit (rule C), Edit
   confirmed after, and her eighteen `ServerStorage` attributes read identical before and after.
2. **DESIGN 7.1 IS BUILT** (round-1 finding 1). `TerrainBake.ROAD` is the cross-section as data;
   `longProfile` clamps the grade, limits grade CHANGE to 2 % per 50 st, caps cut-or-fill at 12 st
   and **relaxes the grade on that road and records it** rather than hiding a breach; `roadAt` cuts
   the crown, the ruts, the 2-st ditch, the verge and a bank never steeper than 1:2; `profilesFor`
   computes every profile ONCE from the base, before any write, so no profile is read off
   half-baked ground. Verify, cases **328d-14/15/16**, notes from the gate run:
   `road EW2: 225 samples, worst step 0.667 st per 20 (allowed 1.600 at 8 %), cut-or-fill 6.60, relaxed=false`
   -- against a sawtooth input of 12-st steps (30 %), which 328d-14 asserts is over the clamp first;
   `road EW2 at -5107: rut columns [-5104,-5100] d 3..7, ditch [-5088,-5080] d 19..27, ditch 2.00 st below the crown`
   -- realised by **`Relief.columnsFor`**, which now has a caller, so the BAND snaps and not the
   centre (F-2), and the inward shift is printed rather than assumed.
3. **The ditch is in the ground a tile writes, and FAIL FIRST proves it.** Case **328d-16** shapes a
   whole tile over a synthetic flat-100 snapshot: `tile (-4352,-5120) over a flat 100 base: crown
   99.990 (Ground), ditch 98.000 (Mud), 125 st away 100.000 (Ground)`. The same tile shaped with no
   profiles handed in comes back **100.000 at the ditch** -- no road, no cut. `TerrainBake.shapeTile`
   is split out of `bakeTile` precisely so the thing that decides the ground has a case
   (round-1 finding 7).
4. **The limiter crosses a tile seam** (round-1 finding 2). `shapeTile` shapes and limits the tile
   plus `LIMIT_MARGIN_STUDS` 128 and returns only the inner tile; `padFor` grew to cover it
   (`bake pad 204 st = limiter margin 128 + blur cutoff 72 + one voxel`). Case **328d-17** runs a
   0.6 gradient (~31 degrees) across two adjacent tiles and asserts every 16-stud window that
   straddles the seam: `seam at column 32 of 64: worst 16-st window 5.824 at 9, worst window ACROSS
   the seam 5.824, ceiling 5.824`. The case first asserts the input is over the ceiling.
5. **ONE fade, in the arithmetic that owns it** (round-1 finding 7). `Relief.heightAt` takes the
   weight as a parameter; the bake hands it `blendAt(union, ...)` instead of multiplying onto the
   cell-edge `k`. Case **328d-5** asserts linearity in that weight -- `one fade: full +24.000,
   quarter +6.000 over the base` -- which two fades in series cannot satisfy, and that weight 0
   returns the base exactly. Omitting the parameter leaves every caller before 328d unchanged.
6. **Refusal 4 asks the RESOLVED Studio** (round-1 finding 3). `compare_synced` issues unscoped
   queries, and an unscoped Edit call goes to the default, which `_choose_default_studio` pins to
   **DEV** -- so round 1 compared the wrong place and would have let a bake proceed. `pin_default`
   closes it, and the selftest asserts the id the comparison was asked of, and that the old default
   is put back. Cases added for refusals **3, 4 and 6**, the **run-log writer**, and the
   **canonical encoder** against the Luau's own output (captured from `Relief.epochInput` in DEV,
   `328d-epoch.luau`) -- design 6.4's two other mandated items. Verify:
   `python tools/terrainbake.py selftest` -> `[bake] selftest: PASS`, **55** cases, a CI step.
7. **`plan` asserts against a number it did not compute** (round-1 finding 4). Round 1 compared
   `ceil(a/b)` with `-(-a//b)` -- dead for every input. It now checks a committed `EXPECTED_TILES`
   and, when a Studio answers, `Relief.tiles`' own count, and says which checks ran. Verify:
   `python tools/terrainbake.py plan --cells C1` -> `ASSERTED: 208 tiles == the committed count for
   C1`, and against the Forest Test today it prints `(Relief.tiles was not asked: ...
   ServerStorage.TerrainBake is not in this place)` rather than passing quietly.
8. **The epoch is computed, stamped and printed** (round-1 finding 6). `epoch_for` digests
   `TerrainBake.epochInputFor`'s string, `tile_pass` stamps it through `TerrainBake.stamp` at the
   end of a wet run, and the OK line carries `epoch=`. Case **328d-11** now also asserts the
   **landform digest** is in the input (`landforms`, `C1`, `scarp`, length > 2000) -- round 1
   asserted the sha and the version only, so dropping `Relief.epochInput` left it green.
9. **The limiter's second axis and its exempt mask cannot be deleted** (round-1 finding 5). Case
   **328d-6** is steep in BOTH axes -- `the input holds 16.00 in x and 16.00 in z, both axes leave
   5.82 / 5.82` -- and pins a whole column through the mask, asserting it did not move.
   **And the 328c blur note is paid, because this task's own gate forced it:** with the per-point
   1,369-read kernel the server spec run passed the harness 300-s cap outright (`FAIL: 25/29 @
   7829a554`, `[server] runner reported within 300 s`). `Relief.blurredGrid` is the separable pass;
   case **328d-19** measures it against the per-point kernel -- `separable blur vs the per-point
   kernel: worst 0.000e+00 studs over 576 points` -- pins the kernel's normalisation on a constant
   base, and keeps the nil rule.
10. **What is NOT proven, said plainly.** NOT OBTAINABLE without a bake, and none of it claimed: the
    per-tile cost in seconds (the design's 8 s stays UNMEASURED), the achieved ditch depth **in her
    terrain** against +- 1.0 st (the 2.00 above is the shaped grid, not voxels on the ground, and
    section 15's fallback therefore stays undecided), the road crown in her world, the landform
    census, pad and stand heights after, and the post-bake tree census. Three BEFORE frames were
    taken and looked at (`328d-before-A|B|C.png`, eye 5 st over the measured ground, cameras in
    `328d-cam.luau` for reuse): **A** from stand 4, a flat featureless plain with **no ridge**; **B**
    standing on EW2's centreline, **no road at all** and the ground falling away west; **C** at stand
    10, the camera on a high shoulder in deep grass -- the 24.33-st burial in a picture. The BEFORE
    tree census (`328d-census-before.luau`, her Play server): `Session` trees=769 floating=195
    sunk=464 broken=250 worstHigh=65.23; `OurForest` trees=4819 floating=836 sunk=1673 broken=1277
    -- **SUSPECT as a certified figure** (rule E): `clawOf` was stubbed to 0, the survey does not
    filter its tree set by cell, and `Workspace.GridForest` does not exist yet. A baseline, not a
    census.

## Could not be verified

- Everything the bake would produce (claim 10). The blocked proof is an `ESCALATE.md` entry written
  at the stop, not worked around (V280).
- **The port switch to `:34874` was not performed and nothing was synced**, because without a bake
  there was nothing to sync; `driven-hunt-karen` was never checked out and its HEAD never moved.
  Her place stayed on `localhost:34873`, visible in the Rojo panel in all three frames.
- Whether Team Create CAUSES the Edit-side source fault. Labelled an inference in `ESCALATE.md`.
- `StreamingMinRadius` cannot be read from this context, let alone set. A NEEDS KAREN click.
- **Still open from the round-1 notes, queued in `TASKS.md` rather than claimed**: `plant` and
  `dims` are in design 6.1 and not in `choices=`; case 328d-13 still returns early (noting it
  proved nothing) on a run where `Script.Source` is unreadable, and the gate counts it.

## The gate

`c7bdbd96` passed 34/34 first time, no re-run. Earlier runs on this branch: `190a4930` failed once
on `deer_hitbox.spec:528` then passed 34/34; `f64106dd` failed on `weapon_shot.spec:1890` and on
`weapon_shot.spec:1490` (the one the dispatch names as not ours) before passing 34/34; `7829a554`
failed on the blur cost, which claim 9 fixes, and `c326e6c9` on one stale `padFor` assertion of my
own, fixed in `c7bdbd96`. Logs: `<runs-dir>/328d-gate1..8.txt`.

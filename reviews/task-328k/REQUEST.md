# Task 328k — the base snapshot: the bake reads the original ground from a file, never live terrain

Task: 328k
Round: 3
Base: `main` `2dd83cbb` (328e #317 and 328f #318 merged)
Code commit: `3f91156bf0245aa587b4086f2930b802a7f8ac89`

```
[harness] PASS: 34/34 checks @ 3f91156bf0245aa587b4086f2930b802a7f8ac89 (clean tree) scope=all
```

`[harness2]` N/A: no path here is in `TWO_PLAYER_PATHS`. **No terrain was written anywhere, in any
place, in any round**; the proof is a dry run. Design `docs/design/grid-terrain.md` 5.2 / 5.3 step 2 /
5.4 / 6.2.

Round 3 changed **one file for one reason** — the round-2 finding. `git diff 4760d89e..3f91156b`
touches `tools/terrainbake.py` only (+54/−13), and `tools/` is mapped nowhere in
`default.project.json`, so nothing in this round can reach a spec. The snapshot shas and the dry-run
figures of round 2 therefore stand unchanged and were not re-run.

## What changed, and why

`profilesFor` defaulted its sampler to a terrain raycast and `bakeTileAt` took its base slice from
`TerrainBake.snapshot` of LIVE ground. So a second bake read its own first bake: C1's `lineMeanY`
went 108.88 → 112.83 → 114.81 over three bakes (`ESCALATE.md`, 328e). `reshapeWanted` could stop the
LANDFORM going in twice; nothing could stop the ROAD climbing. B2's base snapshot is now built: a
file outside the repo, sha-checked, that both halves read.

## Claims

1. **THE ROUND-2 FINDING, fixed where it was wrong — in the test, by giving the rule a predicate.**
   The old case `main(["bake", …, "--allow-local-file", "--studio-name", "x"]) == 2` could not fail:
   with the guard deleted, `check_backup(None)` refuses with 2 as well. The rule is now a pure
   `local_file_refusal(command, allow_local, studio_name)` in `tools/terrainbake.py`, and `main`
   refuses on its answer (`why_not_local`). Six cases replace the two: **one per arm** — flag off
   (`bake`/`snapshot` both None), command ≠ snapshot (text holds ``only for `snapshot``` and names
   `archive`), no `--studio-name` (None *and* `""`, text holds `needs --studio-name`), and
   snapshot-with-a-name is None — plus two `main()` cases that **capture stdout and assert WHICH
   refusal fired**, not the exit code. Verify: `python tools/terrainbake.py selftest`, grep
   `local_file_refusal`. **FAIL FIRST, run three times just now** (each deletion applied to a copy of
   the file, selftest run, file restored — the restored file is the committed one):
   | deleted | cases that FAIL |
   |---|---|
   | arm 2 (`command != "snapshot"`) | `arm 2: … refused BY NAME` + `main refuses … on a mutating command` |
   | arm 3 (`not studio_name`) | `arm 3: … refused for the name` + `main refuses … with no --studio-name` |
   | `main`'s call to the predicate | both `main refuses …` cases |
   Each deletion fails exactly its own cases and nothing else. Selftest count **119 → 123**, 0 FAIL.
2. **A column with no single height is refused, never guessed — four arms, each entered.**
   `TerrainBake.columnFault` is pure; 328k-1 enters Water, overhang, empty and the Y-band ceiling and
   asserts a clean column is nil. The ceiling arm is measured: the whole-footprint read came back
   with `maxY` **exactly 400.00** (the band top); with the arm it reads **395.42** and 1,232 more
   columns are holes. A hole ANYWHERE in a tile's slice refuses that tile, the pad included (the blur
   reads 72 studs out, the limiter 128); 328k-6c/6d enter both arms and assert the two counts are
   reported apart. **A slice's range never counts a hole:** `decodeSlice` builds the hole set first
   and takes its range over the columns that have a height; `base_slice` sends `minY`/`maxY`;
   328k-2c asserts the hole's decoded height IS 0 and that `minY` is still 120.
3. **The base is a file, and both halves of the bake read it.** `profilesFor` asserts a sampler
   (328k-7 drives the throw); `bakeTileAt` refuses a tile with no slice (328k-6a); `selftest` asserts
   the `bakeTileAt` body calls no `TerrainBake.snapshot`. Verify:
   `tests/server/grid_relief.spec.luau` 328k-6/7 and the selftest.
4. **Snapshot twice, same sha — three times, across two commits.** Whole footprint + 430 + the tile
   pad: `010b6400abdd3e12f919e10a4f1a214d479145bda88b27931ad3deda39d878bf` every time, 4,203,957
   bytes, 1,532,160 columns, 172,320 holes, ground 44.80..395.42. C1's region alone, twice:
   `4f8bae6db80d…`, 395,718 bytes, 0 holes. The hashed header holds the lattice, the band and the
   frame and NOTHING an operator typed (selftest case). Verify: `<runs-dir>/328k-snap-all-{d,e,f}.txt`,
   `328k-snap-c1-{a,b}.txt`.
5. **THE DRIFT, measured without writing.** `terrainbake.py diff` computes both routes with one
   instrument. The LIVE route's long profile sits **+4.786 (EW2), +6.581 (EW3), +6.205 (NS3), +9.403
   (NS4) studs mean above the base**, max 16.649 st. A dry run of the live route would add **+2.713 st
   mean / +3.452 st max** to C1's road band *again*. The snapshot route's increment is 0 by
   construction. The carrying line is the profile one, not the FNV one (two dry runs write nothing).
   Verify: `<runs-dir>/328k-diff-r2.txt`, `328k-diff-on.txt`, `328k-diff-on-2.txt`.
6. **No second ridge.** Re-baking C1 from the base (`--reshape on`) lands within **0.05 st mean /
   2.50 st max** of her ground away from the road band (tiles 60, 149, 208); the LIVE route forced to
   reshape puts **+11.53 st** of second ridge into tile 60. Over 8 tiles the snapshot route is mean
   **−2.02 st** (road band −10.30 st) BELOW her ground — the accumulated drift a snapshot re-bake
   would undo, and it is negative; a doubled landform would be ≈ +24 st.
7. **The epoch hashes the snapshot sha, never the git sha** (design 5.4). `tile_pass` passes
   `args.base_sha`, which `check_base` has already compared against the file's own sha256. The case's
   regex captures the whole argument (`([^,)]+)`) over the runtime half of the file, with a fail-first
   case that feeds it the pre-fix `args.base_sha or sha` line and requires it to differ.
8. **Refusal 9, both halves.** `--base`/`--base-sha` are required for `bake`/`measure`/`diff`; the
   file must be outside the repo, exist, parse, carry that exact sha and cover the run's region (nine
   `ok(…)` lines over `check_base`/`base_load`, including a stale sha and a truncated file). Second
   half: a base that cannot answer a road sample point is refused with the reason — `profilesFor`
   computes EVERY east-west road over its WHOLE length, so a one-cell base left **639 of 975** points
   unanswerable (measured).
9. **Which window, measured (L-055).** A `.rbxl` re-opened with `-task EditFile -localPlaceFile`
   answers `game.PlaceId` **0** and `game.Name` `'FT-base-328k.rbxl'`; her live window answers
   `130094961655666` / `'Driven Hunt Forest Test'`. `resolve` walks every Studio, prints what each
   answered, and matches through one predicate `local_ok`. Of its cases, **two are the feature's own
   proof and die if `local_ok`'s place-0 arm goes** (the place-0 arm in both directions, and the live
   window accepted by id); **the DEV case is a standing invariant guard**, not proof of new code —
   DEV's id is neither `FOREST_PLACE_ID` nor `"0"`, so it holds with the feature deleted, and it is
   listed as a guard, answering the round-2 note.
10. **Nothing in her place changed.** Every operation there was a read; round 3 touched no place at
    all. Her attributes are byte-identical to 328f's AFTER dump (`<runs-dir>/328k-attrs-AFTER.json`
    vs `328f-attrs-AFTER.json`), and the backup `.rbxl` and its copy both still hash
    `e4cbb70f2a49…`, the value read before Studio opened it.

## What could not be verified

- **The first full run of this harness at the code commit FAILED one case: `deer_hitbox.spec:659`**
  (*"calf: the skull at (0.01, 1.50, −1.02) answered nil, wanted head"*), 32/34, and the **immediate
  re-run at the SAME commit `3f91156b` passed 34/34** — the PASS line above. Two runs, same bytes,
  two outcomes, so the case is non-deterministic; the dispatch names it as a known intermittent.
  **No control run at the merge-base was made** (L-136 asks for one): a branch switch with `rojo
  serve` live risks the 7.7.0 crash and Karen's Connect click, and the same-commit pair already
  answers whether this round's diff caused it — plus `tools/` is mapped nowhere in
  `default.project.json`, so a `tools/terrainbake.py` edit cannot reach a deer spec. Both run files
  are kept.
- **The snapshot route's zero increment is not demonstrated by a second WRITE.** The dispatch forbids
  writing terrain, so the claim rests on the input being a sha-verified file. 328h is the first run
  that can show it.
- **The dry run covers 8 of C1's 208 tiles.** None of the eight has a hole in its pad.
- **No `before` attribute dump of this session** — the comparison is against 328f's AFTER.
- **`diff` is an addition to design 6.1's command list**, and the base region is footprint + 430 **+
  `padFor()` 204** (measured: at +430 tile 208 could not be sliced), and `--allow-local-file` accepts
  a Studio reporting place id **0** matched by name — a deviation from design 6.2 refusal 2, now
  carried by `local_file_refusal` and gated to the read-only `snapshot`. All three are for the
  Architect to ratify or correct.
- **The twelve round-2 notes are queued, not fixed** (Director: this round is the finding only).

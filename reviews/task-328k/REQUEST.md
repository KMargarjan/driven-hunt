# Task 328k — the base snapshot: the bake reads the original ground from a file, never live terrain

Task: 328k
Round: 2
Base: `main` `2dd83cbb` (328e #317 and 328f #318 merged)
Code commit: `4760d89e64f113c1e8f74d7fc30539583ded8761`

```
[harness] PASS: 34/34 checks @ 4760d89e64f113c1e8f74d7fc30539583ded8761 (clean tree) scope=all
```

`[harness2]` N/A: no path here is in `TWO_PLAYER_PATHS`. **No terrain was written anywhere**; the
proof is a dry run. Design `docs/design/grid-terrain.md` 5.2 / 5.3 step 2 / 5.4 / 6.2.

## What changed, and why

`profilesFor` defaulted its sampler to a terrain raycast and `bakeTileAt` took its base slice from
`TerrainBake.snapshot` of LIVE ground. So a second bake read its own first bake: C1's `lineMeanY`
went 108.88 → 112.83 → 114.81 over three bakes (`ESCALATE.md`, 328e). `reshapeWanted` could stop the
LANDFORM going in twice; nothing could stop the ROAD climbing. B2's base snapshot is now built: a
file outside the repo, sha-checked, that both halves read.

## Claims

1. **The base is a file, and both halves of the bake read it.** `profilesFor` asserts a sampler
   (328k-7 drives the throw); `bakeTileAt` refuses a tile with no slice (328k-6a). `selftest`
   asserts the bakeTileAt body calls no `TerrainBake.snapshot` and that the only `epoch_for` call
   site passes `args.base_sha`. Verify: `tests/server/grid_relief.spec.luau` 328k-6/7, and
   `python tools/terrainbake.py selftest`.
2. **A column with no single height is refused, never guessed — four arms, each entered.**
   `TerrainBake.columnFault` is pure; 328k-1 enters Water, overhang, empty and the Y-band ceiling and
   asserts a clean column is nil. The ceiling arm is measured, not imagined: the whole-footprint read
   came back with `maxY` **exactly 400.00** (the band top), and with the arm it reads **395.42** and
   1,232 more columns are holes. **ROUND 2:** a hole ANYWHERE in a tile's slice refuses that tile,
   the pad included — the blur reads 72 studs out and the limiter 128, and before 328k the snapshot
   call refused the whole tile+pad read, so refusing on the tile alone was a loosening. 328k-6c/6d
   enter both arms and assert the two counts are reported apart.
3. **Snapshot twice, same sha — three times now, across two commits.** Whole footprint + 430 + the tile pad, read twice from the backup:
   `010b6400abdd3e12f919e10a4f1a214d479145bda88b27931ad3deda39d878bf` both times, 4,203,957 bytes,
   1,532,160 columns, 172,320 holes, ground 44.80..395.42, 24.6 s and 24.8 s. C1's region alone, also
   twice: `4f8bae6db80d…`, 395,718 bytes, 0 holes, 3.4 s / 3.3 s. Re-read at THIS code commit after
   the round-2 fixes: `010b6400abdd…` again, 25.8 s (`328k-snap-all-f.txt`). The hashed header holds the lattice,
   the band and the frame and NOTHING an operator typed, so the sha is a function of the ground
   (selftest case). Verify: `<runs-dir>/328k-snap-all-{d,e}.txt`, `328k-snap-c1-{a,b}.txt`.
4. **THE DRIFT, measured without writing.** `terrainbake.py diff` computes both routes with one
   instrument. The LIVE route's long profile sits **+4.786 (EW2), +6.581 (EW3), +6.205 (NS3), +9.403
   (NS4) studs mean above the base**, max 16.649 st. A dry run of the live route would add **+2.713 st
   mean / +3.452 st max** to C1's road band *again*. The snapshot route's increment is 0 by
   construction — the same sha-checked bytes in, the same bytes out. **The line that carries this
   claim is the profile one, not the FNV one:** two dry runs write nothing, so the LIVE route's FNV
   list repeats byte-identically too (round-1 note, and it is right). The live-minus-snapshot profile
   difference is what dies if `profile_sampler` or the `.bin` go away. Verify:
   `<runs-dir>/328k-diff-r2.txt` (at this code commit), `328k-diff-on.txt`, `328k-diff-on-2.txt`.
5. **No second ridge.** Re-baking C1 from the base (`--reshape on`) lands within **0.05 st mean /
   2.50 st max** of her ground away from the road band (tiles 60, 149, 208), while the LIVE route
   forced to reshape puts **+11.53 st** of second ridge into tile 60. Over 8 tiles the snapshot route
   is mean −2.02 st (road band −10.30 st) BELOW her ground: that is the accumulated drift a snapshot
   re-bake would undo, and it is negative — a doubled landform would be ≈ +24 st.
6. **The epoch hashes the snapshot sha, never the git sha** (design 5.4, 328e note c). `tile_pass`
   passes `args.base_sha`, which `check_base` has already compared against the file's own sha256.
   **ROUND 2:** the round-1 case's regex stopped at the first space, so the pre-fix `args.base_sha or
   sha` matched it too. It captures the whole argument now, over the runtime half of the file only,
   with a fail-first case that feeds it that exact pre-fix line and requires it to differ.

11. **ROUND 2 — a slice's range never counts a hole.** A hole's code on the wire is 0, and
   `shapeTile` writes `snapshot.minY` wherever the reader has no answer, so a decoded slice holding
   one hole put a 0-stud floor under 100–150-stud ground. `decodeSlice` builds the hole set first and
   takes its range over the columns that have a height (the sender's own numbers stand when none do);
   `base_slice` sends `minY`/`maxY`; the spec's `snapshotOf` no longer counts a hole either. 328k-2c
   asserts the hole's decoded height IS 0 and that `minY` is still 120.
7. **Refusal 9, both halves.** `--base` and `--base-sha` are required for `bake`/`measure`/`diff`; the
   file must be outside the repo, exist, parse, carry that exact sha, and cover the run's region
   (seven selftest cases, including a stale sha and a truncated file). Second half: a base that cannot
   answer a road sample point is refused with the reason — `profilesFor` computes EVERY east-west road
   over its WHOLE length, so a one-cell base left **639 of 975** points unanswerable (measured).
8. **Refusal 7b now has cases** (328e note h). The decision is a pure `reshape_blocked`; three cases
   cover one blocked cell, several named in order, and `same`/`virgin` passing.
9. **Which window, measured (L-055).** A `.rbxl` re-opened with `-task EditFile -localPlaceFile`
   answers `game.PlaceId` **0** and `game.Name` `'FT-base-328k.rbxl'`; her live window answers
   `130094961655666` / `'Driven Hunt Forest Test'`. `resolve` now walks every Studio, prints what each
   answered, and matches through one predicate `local_ok`; `--studio-name` requires the name too;
   `--allow-local-file` accepts place 0 only with a name and only for the read-only `snapshot`
   (main() refuses it elsewhere). Six selftest cases, DEV refused in both directions.
12. **Nothing in her place changed.** Every operation there was a read. Her attributes are
    byte-identical to 328f's AFTER dump (`<runs-dir>/328k-attrs-AFTER.json` vs `328f-attrs-AFTER.json`),
    and the backup `.rbxl` and its copy both still hash `e4cbb70f2a49…`, the value read before Studio
    opened it — checked again after the second open. No frames: nothing in the world changed.

13. **ROUND 2 — five notes fixed too:** the `X or True` tautology is gone; `base_at` reads the frame
    out of the file's own header; `tile_pass` refuses when Studio's tile plan and this tool's count
    disagree instead of an IndexError partway through a 70-minute bake; `check_place`'s name-mismatch
    branch is reachable again; `QUERY_PLACE_AND_NAME` is imported from `studio_mcp`, not copied.

## What could not be verified

- **The snapshot route's zero increment is not demonstrated by a second WRITE.** The dispatch forbids
  writing terrain, so the claim rests on the input being a sha-verified file and the dry run being
  byte-identical when repeated — not on baking C1 twice and measuring. 328h will be the first run
  that can show it.
- **The dry run covers 8 of C1's 208 tiles**, spread across the plan, not the whole cell. None of the
  eight has a hole in its pad, so the stricter round-2 refusal changed none of their numbers — which
  is why the round-1 and round-2 dry runs print identical figures.
- **No `before` attribute dump of this session** — the comparison is against 328f's AFTER, the last
  recorded state. Every operation in her place was read-only.
- **`diff` is an addition to design 6.1's command list**, not a command the design names. It exists
  because the dispatch asks for a dry-run proof and `measure` reports cost, not difference.
- **Deviation from design 6.2 refusal 2** (*"by place id and never by name"*): `--allow-local-file`
  accepts a Studio reporting place id **0**, matched by DataModel name. A `.rbxl` opened as a local
  file has no place id at all, so there is no other way to address the base snapshot's window; it is
  gated to the read-only `snapshot`, requires `--studio-name`, refuses a nameless Studio and refuses
  DEV. For the Architect to ratify or correct.
- **Deviation from design 5.2:** the base region is footprint + 430 **+ `padFor()` 204**. Measured:
  at exactly +430 the last tile of C1's plan (208) could not be sliced, because each tile shapes over
  itself plus that pad. For the Architect to ratify or correct.

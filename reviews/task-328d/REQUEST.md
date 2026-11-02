# Task 328d -- BAKE C1: review request

Task: 328d
Round: 3
Base: 6b5207176d26
Code commit: f30854ff774844e76eac018aa3514eab90764878

`[harness] PASS: 34/34 checks @ f30854ff774844e76eac018aa3514eab90764878 (clean tree) scope=all`
`[harness2]` N/A: no path in `TWO_PLAYER_PATHS` is touched (TerrainBake, Relief's caller, the spec
and the tool -- no match, drive, tie or team code).

**WHAT CHANGED.** The four round-2 findings, each with a case that fails before the fix; the load
route is INJECTION (Director decision 2, `ESCALATE.md` at `6cf9cf42`); and the measurements the
dispatch asks for, taken in Karen's Forest Test at this commit. **No `WriteVoxels` ran in her place:
the backup file still does not exist, so the bake stopped at its gate (`ESCALATE.md`, NEEDS KAREN).**

## Claims

1. **The ditch and the ruts are cut on BOTH sides of every road** (finding 1). `TerrainBake.bandFor`
   is the ONE band realiser and every road path goes through it (L-031): it answers bounds on `|d|`
   for the side the point is on, reflecting the centre through the origin for the minus side so each
   side gets whole voxel columns. *Verify:* `roadAt` no longer builds `centre - rutFar`; cases
   **328d-15** (both sides' widths, absolute column alignment, midpoints within VOXEL/2, Mud on each
   side, exact height symmetry where the bands agree, and the one place they cannot -- d 29) and
   **328d-16** (the minus rut in the tile, the minus ditch in the tile below).

2. **The realised cross-section is design 7.1's, measured on her ground.** Ditch **1.99 st deep and
   `Mud` on both sides of every road** (target 2.00, worst error **0.01 st**, so design 15 item 2's
   4-stud fallback is not triggered); cross-fall 0.160 st at the sampled column, inside the 0.5-st
   rule. *Verify:* `ESCALATE.md` 16:40 entry; six crossings over five tiles, EW2/EW3/NS3/NS4.

3. **The long profiles are computed ONCE, by the tool, before any write** (finding 2).
   `bakeTileAt` no longer falls back to `profilesFor` -- a tile with no profiles is REFUSED with the
   reason. *Verify:* `tools/terrainbake.py` `profiles_once` and `tile_pass`; selftest cases "EVERY
   tile call carries the profiles the tool computed once", "every tile of one run carries the SAME
   profile bytes", "the Luau refuses a tile that arrives with no profiles"; case **328d-16**'s south
   tile reads its ditch 2 st under the crown the NORTH tile wrote, at the same x.

4. **The eight tile counts are the arithmetic's** (finding 3): A1/B1/D1 224, C1 208, A2/B2/D2 238,
   C2 221, ALL 1333. *Verify:* `EXPECTED_TILES`; the selftest re-derives every one and asserts
   `plan --cells A1` now returns 0, which round 2 would have refused.

5. **The relaxation arm and the grade-change arm both have cases that bite** (finding 4).
   **328d-20**: a 20-st cliff forces `relaxed == true`, `gradePercent` above the axis clamp and a
   breach naming the road, with a flat-base control that does none of it. **328d-21**: a 0 -> 10 %
   kink. *Verify:* delete either arm and the case fails.

6. **One smoothing pass did NOT meet the grade-change rule** -- 3.80 % per 60 st against a 2.40 %
   allowance -- so the pass is iterated to convergence, the realised change is carried on the profile
   and a change that cannot be settled goes into `breaches`. The allowance is the design's RATE
   (2 % per 50 st) over the span the 20-st samples allow (60 st), re-derived in the code (L-167).
   *Verify:* `TerrainBake.GRADE_CHANGE_PASSES`, `worstGradeChangePercent`, case 328d-21.

7. **The injection route works in Karen's Edit session** -- what blocked rounds 1 and 2. The tool
   sends the text of `Relief`, `Grid` and `TerrainBake`, each require rewritten and asserted to match
   exactly once; `Shotgun` is stubbed with the one number `Grid` reads, off the Shotgun file.
   *Verify:* the tool's own output -- `injected Relief 381db97acf90, Grid 0977863b7ac2, TerrainBake
   af6f27bd182c, echoed back from Studio: tile=128 voxel=4 cells=8 roads=8 bakeVersion=1` -- then
   `survey C1` answering `minY 89.16 maxY 150.89 spread 61.73 ridge` from her place.

8. **Refusal 4 is the echo, and it says what it proves and what it does not.** Luau has no sha256 and
   `loadstring` is disabled, so Studio cannot digest its own injected text; the echo compares the
   constants the arrived code defines with the files' own, and the sha256s say which bytes were sent.
   *Verify:* `check_echo`, the docstring, and four selftest cases (a stale module, a wrong cell
   count, a TerrainBake pinned to another place, a wrong road count).

9. **Per-tile cost measured: 84-106 ms** on ten tiles of C1, against the design's UNMEASURED 8 s
   target (12.2). *Verify:* `measure --cells C1 --tiles 10` output; `.terrainbake/` run log.

10. **A snapshot refusal now says why.** `TerrainBake.snapshot` answers `(nil, why)` and JSONEncode
    of the first value sent `"null"`. Measured: C1's whole region is **24,611,375 voxels against
    ReadVoxels' 4,194,304 ceiling**, which is why the bake snapshots per tile.

## What I could not verify

* **Nothing in Karen's place changed.** No `WriteVoxels` ran: the backup gate is unmet. So the road
  crown and ditch IN WRITTEN GROUND, the landform census of C1's ridge, the pad and stand heights
  AFTER, and the post-bake tree census are **NOT OBTAINABLE** and are not claimed. The BEFORE halves
  are measured at this commit: the base (minY 83.89, maxY 160.00 over C1 + roads + 200), the 15
  stands (worst stand 10, **buried 24.33 st**), and three frames from eye height, looked at
  (`328d-r3-before-A|B|C.png`: **A** stand 4, a level horizon with **no ridge**; **B** on EW2's
  centreline, **no road at all**; **C** stand 10, the ground falling away east). Rule 5 is therefore
  **not met** for the bake's own result.
* **NS3 and NS4 end on a 20 % ceiling** with 14.1 st of cut-or-fill still over the 12-st cap, and
  realise 13-16 % grades. The arm is correct and printed all 16 breaches; the consequence for the
  truck ride is a Director/Karen decision, written up in `ESCALATE.md`.
* `deer_hitbox.spec:659` fired once in one of four runs (named INTERMITTENT in the dispatch);
  `semiauto_client.spec:93` fired once, is not on that list, and passed in the other three runs. The
  final run at `f30854ff` is 34/34 with neither.

# Task 302 — a player can walk to the range and stay there

Task: 302
Round: 2
Base: 671103cf (task-298b6-range-forest)
Code commit: 54093f57b14380d86ac6e79cca348fc4822f15f4

```
[harness] PASS: 34/34 checks @ 54093f57b14380d86ac6e79cca348fc4822f15f4 (clean tree) scope=all
```

`[harness2]`: **N/A.** `agents.needs_two_player` returns `[]` for all seven changed files —
none is in `TWO_PLAYER_PATHS`. The return rule is one man's position against rectangles.

## What changed

The lobby's return rule asked one question — "is he inside the 220 x 220 field?" — so a man on
the range mat (268 studs from the anchor) was respawned at the lodge every
`RETURN_COOLDOWN_SECONDS`. It now asks `Join.insideHome` over a list of rectangles: the field
plus each outlying area the composition root hands in plus the corridor that reaches it.

**Why a union and not the bounding rectangle of lodge+range.** The bounding box is
x 2558..2960, z -3368..-2840, and not one of its four edges is a fact about anything. Each
rectangle of the union has its own measured edge: the lodge's field, the range's own footprint
(`Range.footprintFor`, from the same `LAYOUT` `Build` lays its parts from, plus the mat prompt's
12-stud reach), and the bounding box of the straight line between the two anchors widened by
`FIELD.WALKWAY_HALF_STUDS` = 24 (16 studs/s walk, 1.5 s of drift). In Karen's numbers:
lodge x 2740..2960 z -3060..-2840 · range x 2558..2742 z -3368..-3200 · walkway x 2626..2874
z -3308..-2926; lodge∩walkway and walkway∩range are both non-empty, so the walk has no gap.

## Claims

1. **Round 1, finding 1 — the SHIPPED path is now what the proof drives.** Two new cases in
   `tests/server/lobby_live.spec.luau` go through `Lobby.start`'s `homeAreas` seam exactly as
   `ForestTestBoot` hands it in, and assert what the injected `place` recorded (`seen.placed`):
   *"leaves a man at the range and on the walk there alone -- and returns him without the seam"*
   — three men (mat, halfway along the walk, 400 studs past the range) in one `Lobby.step`:
   **with** the seam only the third is placed (`#placed == 1`), **without** it all three are
   (`#placed == 3`). `stepPlayer`'s call site, `Lobby.start`'s plumbing and `ForestTestBoot`'s
   `rangeHomeAreas` are all on that path.
2. **The mutation that finding 1 asked about was RUN, not argued.** With `stepPlayer` reverted
   to `Join.insideField(here, anchor, cfg)` and nothing else changed, the suite reads
   `FAIL: 32/34 ... (DIRTY TREE (4 paths) - NOT valid evidence) scope=all`, with exactly
   `failed [server] lobby_live.spec:1047 Expected value "nil" (nil), got "true" (boolean)` —
   *"the man on the mat was sent back to the lodge"* — 1 failed, 1 error, nothing else.
   A negative control, deliberately on a dirty tree; it is not gate evidence.
3. **FAIL FIRST at 671103cf.** Commit `3c7eca8d` is the five pure cases alone (no `src/`); the
   run at it reads `FAIL: 32/34 ... @ 3c7eca8d` with 5 errors, one per case:
   `lobby.spec:248` (the drive-clearance case, which calls `RangeData.footprintFor` itself) and
   `:954`, `:993`, `:1042`, `:1087` (each through `union()` at `:940`).
4. **The mat, the firing line and the walk are home** (`lobby.spec`, pure): mat, firing line and
   t = 0.25/0.50/0.75 on the lodge→mat line. Note: `4 of 5 range points were returned by the old
   field rule and are home now (mat, firing line, walk t=0.50, walk t=0.75)` — the old predicate
   runs beside the new one on the same points, so no constant reader can pass it (L-093).
5. **One case per sub-boundary, just outside each of the three rectangles**: the midpoint of
   each of the twelve edges pushed 1 stud out, interior seams skipped. Note:
   `7 outside-the-edge cases returned him (rect 1: 2, rect 2: 2, rect 3: 3)`; every rectangle
   contributing at least one is asserted.
6. **No range row = exactly the old 220 x 220.** `#homeAreas(anchor, cfg, nil) == 1`, its four
   edges equal `anchor ± SPAN_STUDS/2`, and a 41 x 41 grid agrees with `Join.insideField` on
   every point. Note: `no-range grid 1681 points, 0 disagreements; with the range, 738 points
   differ` — the second number proves the grid is a real instrument. The live half is in claim 1
   (`world.homeAreas = nil` → all three men returned, as before this task).
7. **`inDrive` and `held` behave as before, re-entered with the new areas** — pure
   (*"still never touches a man in the drive, a man held, or a man with no position"*) and live
   (*"still leaves a man at the range who is in the drive or held to the drive"*,
   `#seen.placed == 0`).
8. **Clear of the drive, measured (L-151).** The existing *"is clear of EVERY drive layout's
   ground"* case loops over all three home rectangles. Note: `12 pairs checked over 4 layouts;
   worst corridor gap 180 studs, worst boar-bounds gap 120 studs; road exitZ -2377, edge exitZ
   -3500, ride exitZ -4790, track exitZ -4150`. The 120 is the lodge's own existing gap; the new
   rectangles' worst is 206. Thresholds are the case's own (corridor ≥ 100, bounds ≥
   `BOUNDS_SLACK` + 40).
9. **No owner requires another, and the flag still rolls it back.**
   `grep -n Range src/server/Lobby/*.luau` → nothing; the rectangle is composed in
   `ForestTestBoot` and gated on `RangeOwner.ENABLED`, the one boundary that reads `RANGE`.
10. **Lint, build, selftests**: `selene src`, `selene --config tests/selene.toml tests`,
    `stylua --check src tests`, `rojo build`, `studio_mcp.py selftest`, `agents.py selftest` —
    all clean.

## Round 1 notes

Fixed here: note 2 (`inField` → `inHome`), note 1 (the `WALKWAY_HALF_STUDS` comment now says it
is a bounding box, 248 x 382 for Karen's diagonal, not a 48-stud strip), note 4 (claim 3 above
names `lobby.spec:248` correctly). The rest are queued in `TASKS.md` under 302a: the
`docs/design/lobby.md` 8.1/16.1 update, the `homeAreas` row shape check, the drive-clearance
case erroring if the forest-test range row is removed, and the row-vs-built note on
`rangeHomeAreas`.

## Not verified

**NOT PROVEN in Karen's place.** DEV has no lobby (`Lobby.ANCHORS` has no `map:v1` row), so
every claim is spec evidence in DEV. The live walk from the lodge to the mat and 30 s standing
there is the Director's, after this PASS. No screenshot: this task adds no visible thing.
Core quality protocol: N/A — nothing under `Boar/`, `Weapon/`, `Shotgun/`, `Ballistics/`,
`Flight`, `Effects` or a kill zone is touched.

# Task 302 — a player can walk to the range and stay there

Task: 302
Round: 1
Base: 671103cf (task-298b6-range-forest)
Code commit: b351da7009c73dd80a4a8de9d6089bbeb3fed8de

```
[harness] PASS: 34/34 checks @ b351da7009c73dd80a4a8de9d6089bbeb3fed8de (clean tree) scope=all
```

`[harness2]`: **N/A.** `agents.needs_two_player` returns `[]` for all six changed files —
none is in `TWO_PLAYER_PATHS`. The return rule is one man's position against rectangles.

## What changed

The lobby's return rule asked one question — "is he inside the 220 x 220 field?" — so a man on
the range mat (268 studs from the anchor) was respawned at the lodge every
`RETURN_COOLDOWN_SECONDS`. It now asks "is he inside ANY home rectangle?", and the list is the
field plus each outlying area the composition root hands in plus the corridor that reaches it.

**Why a union and not the bounding rectangle of lodge+range.** The bounding box is
x 2558..2960, z -3368..-2840 — 212,000 studs square, and not one of its four edges is a fact
about anything: it swallows the forest south-east of the lodge and north-west of the range,
where nobody walks, and it grows by the square if a third area is added. Each rectangle of the
union has its own defensible edge instead: the lodge's own field, the range's own footprint
(`Range.footprintFor`, from the same `LAYOUT` `Build` lays its parts from, plus the mat prompt's
own 12-stud reach), and the bounding box of the straight line between them widened by
`FIELD.WALKWAY_HALF_STUDS` = 24 (a player walks 16 studs/s, so 1.5 s of drift either side).

In Karen's numbers: lodge x 2740..2960 z -3060..-2840 · range x 2558..2742 z -3368..-3200 ·
walkway x 2626..2874 z -3308..-2926. Lodge∩walkway and walkway∩range are both non-empty, so the
walk cannot fall through a gap.

## Claims

1. **FAIL FIRST at 671103cf.** Commit `3c7eca8d` is the five cases alone; the harness run at it
   reads `FAIL: 32/34 ... @ 3c7eca8d` with 5 errors, one per case, at `lobby.spec:248`,
   `:954`, `:993`, `:1042`, `:1087` (each through `union()` at `:940`). Verify: that commit's
   tree touches no `src/`.
2. **The mat, the firing line and the walk are home.** `lobby.spec` →
   *"leaves a man on the mat, on the firing line, and all the way there"*: mat, firing line and
   t = 0.25/0.50/0.75 along the lodge→mat line. Note printed:
   `4 of 5 range points were returned by the old field rule and are home now (mat, firing line,
   walk t=0.50, walk t=0.75)` — the old predicate `Join.insideField` runs beside the new one on
   the same points, so the case cannot pass against a constant reader (L-093).
3. **One case per sub-boundary, just outside each of the three rectangles.**
   *"sends him back the moment he steps off ANY of the three rectangles"*: the midpoint of each
   of the twelve edges pushed 1 stud out, interior seams skipped. Note:
   `7 outside-the-edge cases returned him (rect 1: 2, rect 2: 2, rect 3: 3)` — every rectangle
   contributes at least one, asserted, so a skipped-everything run cannot read as a pass.
4. **No range row = exactly the old 220 x 220.** *"is EXACTLY the old 220 x 220 square in a
   world with no range row"*: `#homeAreas(anchor, cfg, nil) == 1`, its four edges equal
   `anchor ± SPAN_STUDS/2`, and a 41 x 41 grid agrees with `Join.insideField` on every point.
   Note: `no-range grid 1681 points, 0 disagreements; with the range, 738 points differ` — the
   second number proves the grid is a real instrument and not one that reports 0 regardless.
5. **`inDrive` and `held` behave as before, re-entered with the new areas.**
   *"still never touches a man in the drive, a man held, or a man with no position"*: both arms
   at the mat and at a point 400 studs outside the union, plus `nil` (absent is not outside).
   The eight-combination table above it is unchanged.
6. **Clear of the drive, measured not asserted (L-151).** The existing
   *"is clear of EVERY drive layout's ground"* case now loops over all three home rectangles.
   Note: `12 pairs checked over 4 layouts; worst corridor gap 180 studs, worst boar-bounds gap
   120 studs; road exitZ -2377, edge exitZ -3500, ride exitZ -4790, track exitZ -4150`. The 120
   is the lodge's own existing gap, unchanged; the new rectangles' worst is 206. Thresholds are
   the case's own (corridor ≥ 100, bounds ≥ `BOUNDS_SLACK` + 40).
7. **No owner requires another.** `src/server/Lobby/` requires nothing of `Range`; the rectangle
   is composed in `ForestTestBoot` from `RangeData.footprintFor` and handed to `Lobby.start` as
   the optional `homeAreas`. Verify: `grep -n Range src/server/Lobby/*.luau` → nothing.
8. **The flag still rolls it back.** `ForestTestBoot` gates the area on `RangeOwner.ENABLED` —
   the one boundary that reads `RANGE` — so with the flag off nothing is built and nothing is
   home. No second `Flags.isOn`.
9. **Lint, build, selftests.** `selene src`, `selene --config tests/selene.toml tests`,
   `stylua --check src tests`, `rojo build`, `tools/studio_mcp.py selftest`,
   `tools/agents.py selftest` — all clean.

## Not verified

**NOT PROVEN in Karen's place.** DEV has no lobby (`Lobby.ANCHORS` has no `map:v1` row), so
every claim above is spec evidence in DEV. The live proof — walk from the lodge to the mat with
real Humanoid movement, stand 30 s, not returned — is the Director's, in her place, after this
PASS. No screenshot: this task adds no visible thing.

Core quality protocol: **N/A** — nothing under `src/server/Boar/`, `src/server/Weapon/`,
`src/shared/Shotgun/`, `src/shared/Ballistics/`, `Flight`, `Effects` or a kill zone is touched.

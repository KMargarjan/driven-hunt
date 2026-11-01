PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: this task has no core item
(no animal behaviour, no shooting rule, no ballistics — `Range.spotAt` answers `bench` off
`MAT.size.X/Z` with no Y term, `distanceFor` has no `BENCH` term, and `bayHalfSlope` /
`sightlineFrom` still read the three surviving `HUT` keys, so the window, the mask and the shot's
door are untouched). What Karen will judge here is the LOOK of a station, and the request
describes four frames taken in her place at the code commit `0e30e865` (`322-a-approach`,
`322-a-zoom`, `322-b-station2`, `322-c-panel`) plus a live probe reading `PARTS Mat=6 Post=6
Turf=1`, `Mat2 top=150.120 ground=150.000 step=0.120`, `Post2 guis: StationNumber[Front]="2"
StationNumber[Back]="2"`, `tallest non-earth part: Post1 top=154.00`. I cannot open the frames;
every number in that probe is one this code produces (`MAT.liftStuds` 0.12, `POST.size.Y` 4,
`NUMBER_GUI_NAME` "StationNumber", `matName`/`postName`). Harness line names the request's
`Code commit:` with "(clean tree)", and `paperwork-after-code-commit.txt` says only
`reviews/task-322/REQUEST.md` followed it.

Delete-the-producer, by reading, for each case offered as proof:
- flush rectangle (claim 3): the no-plate case fails with the lay reverted — `matTop` would be
  138.5 against `137.5 + liftStuds`, and the second line `matTop - 137.5 < 0.5` fails at a full
  stud. Its producer is the handed-in `groundAt` returning 137.5, which is read.
- number on the post (claim 5): reads the `SurfaceGui`s out of `Post<n>` and asserts
  `faces == 2` with `seen[Front]` and `seen[Back]` separately — not one gui counted twice, and
  `label.Text == tostring(spot)` is independent of `stationNumberText`. Delete `makeNumberFace`
  and `faces` is 0.
- bare station (claim 1) and census (claim 8): the absence lines pass with the whole station loop
  deleted, but each case also asserts `Mat<n>` and `Post<n>` present (and the census
  `1 + 2*SPOT_COUNT + 3 + #turfSlabs` collapses to 5), so the pair fails on deletion and fails on
  main.
- T6 (claim 6): the pure case passes with the producer gone and says so; the built case reads
  `Post<n>` out of the folder against `bayHalfSlope * ahead`, margin 0.133 studs — not float noise.

## Notes (non-blocking)
- `src/server/Range/init.luau` `MAX_PARTS` comment, `tests/server/range.spec.luau` census comment,
  request claim 8 — the DEV count is **17**, not 28. `1 + 2 * SPOT_COUNT + 3 + #turfSlabs` with
  `#turfSlabs == 1` in DEV (main's 59 = 58 + 1 turf; 59 − 42 removed = 17). The assertion itself is
  the arithmetic and is right; only the three stated numbers are wrong. Fix: "= 17".
- `src/server/Range/Build.luau`, the mat lay — the flush slab no longer grows downward, so its
  bottom is pinned at `matHi - 0.88`; on ground whose spread under one 8×8 footprint exceeds 0.88
  studs the low edge floats (rule E). Nothing shipped hits it (the sloped spec arm spreads
  8·0.0625 + 8·0.03125 = 0.75; her place is a level terrace), and the sweep's `^Mat%d` arm
  `continue`s before the generic `bottom - lo` check, so no case would catch it. Add
  `expect(bottom <= lo + 1e-2)` inside that arm.
- `tests/server/range.spec.luau`, `"builds a bare station: the post inside the sight bound, and not
  one hut part"` — `gone += 1` counts loop iterations, not absences: `names` always holds 7 entries,
  so `expect(gone).to.equal(7 * LAYOUT.SPOT_COUNT)` cannot fail. The bite is the per-name
  `expect(folder:FindFirstChild(name)).to.equal(nil)`; drop the counter or increment it only on a
  confirmed `nil`.
- same file, the B10 sink case — `expect(deepest > HighSeats.DIMS.FOOT_EMBED_STUDS)` compares two
  constants (0.88 > 0.3) and cannot fail. The line that works is `worst >= -(deepest + 0.35)`.
- `docs/design/shooting-range-lobby.md` §7.1 — the task-322 NOTE is inserted **mid-sentence**: "The
  station row grown by half a hut roof is the" / NOTE / "**smallest rule under which every built
  part of every station is unobstructed**". Move the note after the bullet it comments on.
- same file, stale citations: §2.3's derived-reader list still names `hutPostPositions`; §7.1 still
  reads "the hut is the widest and tallest thing at a station (`HUT.roofSize` 13 × 0.6 × 15 at
  `roofRise` 9)" in the present tense, and `roofRise` no longer exists in `Range.LAYOUT`; §15.1
  item 7 still names `hutPostPositions`, `hutRoofPosition` and `benchPosition` as what the
  containment case walks, where the case now walks `matPosition`, `promptPosition` and
  `standPosition`.
- claim 10 overstates the sweep — `src/shared/Range/init.luau` still carries undated present-tense
  hut/bench prose: `bayHalfSlope`'s header ("The two downrange hut posts are the ONLY furniture of
  his own station in the bore's plane"), `sightSpanFor`'s "BOUND 2, HIS OWN BAY: what he can see out
  of his own firing hut", `sightlineFrom`'s "the STATION ROW grown by half a hut roof, because the
  hut is the widest and tallest", and `footprintFor`'s "mat, post and bench at six stations".
- claim 1 says "six names" and "the same six names" where it is seven per station (`Roof<n>`,
  `Board<n>`, `Bench<n>`, `HutPost<n>_1..4`); the 42 total is right.
- `backups/task-322/README.md` — every deleted symbol is archived verbatim, but the one deleted
  `Build.luau` line that is NOT archived verbatim is the old mat call
  (`onGround(RangeData.matName(spot), layout.MAT.size, at.X, at.Z, layout.MAT.color)`); the recipe
  describes it in prose instead. Paste the line.

---
REVIEWER verdict on commit `41ad654ff7e2337cd24dcf6434c409f42f3041d9` (round 1) · 2026-11-01 01:49 UTC · session cost $3.52, 42 turns · written by tools/agents.py

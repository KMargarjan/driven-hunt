# Task 311 — a clean lobby: a level truck bay, a flagpole, a birch-lined road

Task: 311
Round: 2
Base: fb890d68
Code commit: 41d4a48d054b047952cc2cf60a43fb5f2ec47f83

```
[harness] PASS: 34/34 checks @ 41d4a48d054b047952cc2cf60a43fb5f2ec47f83 (clean tree) scope=all
```

Two players: **N/A** — `agents.needs_two_player` returns `[]` for this diff (`src/server/Lobby/`,
`src/shared/Lobby/`, `tests/server/lobby.spec.luau`, `docs/`): none of it is in `TWO_PLAYER_PATHS`.

Karen, 2026-10-28: *"cars now some is on small mountain some of them fix those, lobby has to be clean
and nice / ... flag long stick and flag like in hunting lobbies / ... forest road comming to lobby
around ... bjorke tree from both sides with spaces"*.

Note: `docs/research/2026-10-29-lobby-flagpole-and-birch-avenue.md`. Evidence:
`<runs-dir>/evidence/p311-{before,after,after2,after3,pole,pole2,pole3,geom}.txt`; frames in
`<runs-dir>/f311/`.

## Round 1's three findings — all three were right

1. **`Field.shelfFor` rounded to the NEAREST voxel, and `tryBuild` can run twice.** The retry reads
   the surface the first fill produced — two studs above the cut — so `round(150/4)` cut the second
   build at 152, the third at 156, lifting the lobby a voxel each time. It now **floors**, through
   `Field.cutBottomY` itself, so the cut is a fixed point under that feedback.
   *Verify:* `Field.shelfFor`; `lobby.spec` *"snaps to the SAME cut on a second build, fed the
   surface the first one produced"*, which feeds `shelfFor` its own output + 0, 1, 2 and 3.9 for
   five starting grounds. **It fails on the old `math.round` body** (`round((148+2)/4)*4 = 152`).
2. **The avenue's shift-and-drop loop was only covered by a bookkeeping identity**, so the case
   passed with the whole loop deleted. The decision is now **`Build.avenuePlan` — pure and
   exported**, and the builder only draws its rows.
   *Verify:* `lobby.spec` *"walks a fouled slot north, drops one it cannot clear, and never onto the
   yard"*: a trunk 7 studs from a slot (inside the 14-stud keep-off) must move **exactly one**
   8-stud step — `shifted == 1`, `at.Y - first.at.Y == SHIFT_STUDS`, `at.X` unchanged; and a wall of
   trunks across the whole shift range must be **dropped**. Delete the `while` loop and the first
   assertion reads 0; delete the drop branch and the second has no `dropped` row.
3. **A shift could walk a trunk 24 studs north into the gravel yard and onto pad 4.** `fouled`
   refused the road and other trunks and nothing else. **`Build.plantable`** is now the one keep-out:
   the road corridor, `Build.yardRect`, all four `Pads.centreFor` decks, all four parked bays
   (`MODEL.LENGTH_STUDS` × `MODEL.WIDTH_STUDS`) and the lodge box — which is the research note's own
   target 5, and what `treeLine` next door already refused.
   *Verify:* `Build.plantable`; `lobby.spec` *"refuses a point in the road, and says so for the
   lane's own centre"* (the yard's centre, pad 4, the lodge's centre → `false`; a real avenue slot →
   `true`); the plan case above asserts `plantable` on every **shifted** position; and the live case
   now asserts it on the **planted pivots**, not on the nominal slot table.

**Found while fixing 3, and it is worth a line:** `Build.lodgeKeepOut` returns a **centre and
half-extents**, not a min and a max. Round 1 read it as min/max in three places — which answers
"outside" for almost any point, so two assertions passed for the wrong reason. `Build.insideLodgeBox`
is now the one reader, and its own case asserts the lodge's centre is **inside** it.

**Notes taken:** `Build.offRoad` has a negative control (the lane's centre and the verge edge both
`false`); the flagpole's kerb is turned like the mast, because a Roblox cylinder's length is its X
and an unturned `(3, 0.4, 3)` was a 3-stud tube lying on its side rather than a 0.4-stud ring.

## The standing claims (round 1, re-measured at this commit)

`<runs-dir>/evidence/p311-pole3.txt`, her place, Play, at `41d4a48d`:

4. **The mound is gone.** Relief **0.00** on all four 49-sample truck footprints, every truck's
   lowest corner **150.00**, gap **+0.00** ×4. Before (`p311-before.txt`): relief 1.27 / 1.27 and
   Truck4 1.27 studs above Truck1.
5. **Nothing floats and nothing new is buried.** Pads −0.62 ×4 (identical; before, Pad4 sat on the
   mound), lane / yard / logs / fence posts / spawn −0.75, flagpole kerb and mast **+0.00**. Worst
   float over every ground-standing item: **+0.00**.
6. **The pole is the size the sources give**: mast 35.70 studs (10 m at 0.28 m), finial on top,
   flag 8.57 × 5.36 (240 × 150 cm) hoisted 1 stud under the finial, hoist edge on the mast.
7. **The avenue is unchanged by round 2 — byte-for-byte**: the same six trunks at
   (2845,−3047) (2846,−3024) (2847,−2997) (2847,−2948) west and (2895,−3015) (2894,−2997) east,
   23.1–24.9 studs off the lane's centre. `p311-pole3.txt` against `p311-pole2.txt`.
8. **Four cycles of measurement are in the note and the round-1 request**: cut at the measured
   height → relief 1.27; cut on the boundary → 0.00 but surface 151.27 and the road buried; cut
   snapped → 0.00, surface 150.00, road still buried; cut snapped **plus the seat re-read after the
   fill** → 0.00 and the road on the ground.

## What I could not verify

- **No new frame for the kerb's new shape.** The round-2 visual change is 0.4 studs of stone at the
  pole's foot. The frames in `f311/` are round 1's: `311-road.png` (birches both sides with gaps,
  the fence, the lodge at the end, the flag with its cross above the trees — `311-flag-zoom.png`
  at 5×, where the cross reads and the green field reads near-black backlit), `311-pole.png` (the
  mast on the gravel beside Truck 1, all four wheels down, the pad flush), `311-yard.png`,
  `311-flag.png`. Every planted position in them is identical at this commit (claim 7), so they
  still show this build — **except the kerb, which I did not photograph.**
- **`Lobby.stats()` cannot be read live**: `execute_luau` has its own module cache, so a probe's
  `require` returns a fresh `Lobby` with zeroed counters. Every live number above is an **instance**
  fact; the counters are asserted in `lobby.spec`.
- **The ring is NOT dice, and round 1's wording was wrong** (reviewer's note): `treeLine` seeds
  `Random.new(1804)` so the wood is the same every boot. `avenuePlan`'s guard is still the right
  shape — it is a keep-out, not a lottery — but the comment claiming otherwise is still in
  `CONFIG.AVENUE` and `avenue()`'s header. **Not fixed in this round** (it is prose, and round 2 is
  the last round this task has); queued with the `docs/design/lobby.md` update below.
- **`docs/design/lobby.md` now contradicts the code in four places** (the file table, §9, acceptance
  items 5 and 6, all saying "grass first, then air" and "two FillBlock calls"), and the flagpole and
  the avenue have no design entry. Queued for the Architect / the next lobby task, as the round-1
  note asked.
- `stats.cutY`, `stats.flagpoleY` and `stats.avenueShifted` are still not printed by
  `reportLobby`'s boot line. Queued.
- **No terrain was saved into Karen's place and none needs to be**: the fill is a runtime write by
  the owner that already exists, and a hand-saved shelf would be a second writer of the same ground
  (note §3.1). **There is no `NEEDS-DIRECTOR`.**

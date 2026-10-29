PASS

Round 1's three blocking findings are closed, and each closure has a case that dies when the code
under test is removed:

- `Field.shelfFor` is now `Field.cutBottomY(measured)` -- `math.floor(shelfY / Field.RESOLUTION) *
  Field.RESOLUTION`. The fixed-point case *"snaps to the SAME cut on a second build, fed the surface
  the first one produced"* asserts `Field.shelfFor(produced) == first` for `produced` of `first + 0,
  1, 2, 3.9` over five starting grounds. On the old body it fails at the first row:
  `math.round(151.248 / 4) * 4 = 152` against `first = 148`. `tryBuild` is a fixed point with it:
  the retry's `centre = anchor` keeps x/z, `shelf = world.groundAt(...)` reads the produced surface
  and `Field.shelfFor` returns the cut it already made.
- `Build.avenuePlan` is pure and exported, and the builder's loop only draws its rows. Delete the
  `while fouled(at) and steps < spec.MAX_SHIFTS` loop and `expect((moved :: any).shifted).to.equal(1)`
  reads 0 (or `dropped`, which the line above refuses); delete the `{ index, slot, dropped = true }`
  branch and `expect((blocked :: any).dropped).to.equal(true)` reads nil.
- `Build.plantable` refuses the road, `Build.yardRect`, the four `Pads.centreFor` decks, the four
  parked bays and `Build.insideLodgeBox`. Checked against the live config (anchor 2850/-2950,
  `ROAD.CENTRE_X` 20, `TRUCK.OFFSET` (58,0,24)): yard x 2883..2929.2, z -2994..-2909, so the east
  slot `{ side = 1, z = -48 }` at z -2998 fouls on every one of its three 8-stud steps (-2990,
  -2982, -2974 are all inside the yard) and comes back `dropped` instead of standing on pad 4 --
  which is exactly what round 1 found nothing stopping. The negative control bites for three of the
  rectangles: `plantable(yard centre)`, `plantable(Pads.centreFor(anchor, 4, CFG))` and
  `plantable(lodge door)` all go `true` if the yard guard or the lodge guard is deleted, and
  `plantable(Build.avenueAt(anchor, SLOTS[1], CFG))` is the positive control.
- `Build.insideLodgeBox` reads `Build.lodgeKeepOut`'s centre-and-half-extents correctly, and
  `expect(Build.insideLodgeBox(Vector2.new(door.X, door.Z), anchor, CFG)).to.equal(true)` is the
  assertion the round-1 min/max misreading could not pass -- it is true for any porch depth, since
  `(south - north) / 2 < (south + north) / 2`.

Claim 7 (the avenue is unchanged by round 2) is consistent with the code: every nominal slot is
`plantable` with nothing standing, the one live shift (east z -3023 -> -3015) is still `plantable`,
and the one live drop is still dropped. Claim 1's live cut is unchanged too -- `round(149.248 / 4)`
and `floor(149.248 / 4)` are both 148 -- so re-measuring round 1's numbers at `41d4a48d` is what the
diff predicts. Harness line names the request's `Code commit:` with "(clean tree)" and `scope=all`;
`paperwork-after-code-commit.txt` says OK. `needs_two_player` N/A checked against
`changed-files.txt`, not against prose: no changed path is in `TWO_PLAYER_PATHS`. No file deleted,
no script outside Rojo-owned paths, no `.rbxm`, no secret or local path, `Field` is still the only
terrain writer and `Build` draws only into its own folder.

Rule 5, stated so this PASS is not read as rule 5 having been met: no item in this task is animal
behaviour or shooting, so no core item is at stake and the NOT PROVEN parenthesis does not apply.
The round-2 visual delta -- the kerb turned from a 3-stud tube on its side into a 0.4-stud ring --
has NO frame; the request says so itself (*"except the kerb, which I did not photograph"*). The
frames it names (`311-road.png`, `311-pole.png`, `311-yard.png`, `311-flag.png`,
`311-flag-zoom.png`) are round 1's, they are under `<runs-dir>` where I cannot open them, and the
claim that every planted position in them is identical at this commit is consistent with the diff.
The live numbers in claims 4-8 rest on `p311-*.txt` probe files I cannot read; the code could
produce each of them.

## Notes (non-blocking)
- `tests/server/lobby.spec.luau` *"scrubs every pad's own rectangle back to its own material (task
  244)"* — the ordering claim is no longer asserted anywhere. The comment says *"AFTER EVERY
  `FillBlock` AND NEVER BEFORE THEM ... so this is asserted on the fake's own two logs rather than on
  the last material"*, and what replaced `fake.calls[#fake.calls].material == Enum.Material.Air` is
  `expect(#fake.replacements > 0)` and `expect(#fake.calls > 0)` — neither can fail, and neither says
  "after". `fakeTerrain` keeps `calls` and `replacements` as two independent lists, so order is not
  expressible with it. Give the fake one shared sequence log (or record `#calls` at each
  `ReplaceMaterial`) and assert the scrub's recorded fill count equals the total.
- `src/server/Lobby/Build.luau` `Build.plantable` — the pad-box and truck-box branches have no case
  that fails without them. `plantable(Pads.centreFor(anchor, 4, CFG))` is already refused by the yard
  rectangle (pad 4 at x 2898.5, z -2977 is inside x 2883..2929.2, z -2994..-2909), and no assertion
  anywhere names a truck box, whose only ground outside the yard is the ~2 studs east of
  `yardRect`'s east edge. The guards are right; they are untested.
- `tests/server/lobby.spec.luau` — `expect(Build.plantable(row.at, anchor, CFG)).to.equal(true)` in
  *"walks a fouled slot north..."* and the same line over the planted pivots in *"plants the avenue
  when there are templates..."* are identities over the predicate `fouled` itself uses: they fail
  when the `Build.plantable` call is removed from `fouled` (I checked: with it gone, the `onEvery`
  plan puts east slot 8 at z -2982, inside the yard, and the assertion goes red), but they cannot
  fail when `plantable`'s own body is weakened. The one case that would bite both: drive
  `avenuePlan` with a trunk on the east slot at `z = -48` and assert the row comes back `dropped` —
  the known-bad input for finding 3, named as a number.
- `tests/server/lobby.spec.luau` *"snaps a measured shelf onto the voxel grid, by at most half a
  voxel"* — the title is the OLD `math.round` behaviour; the body asserts a floor
  (`expect(measured - snapped < Field.RESOLUTION).to.equal(true)`, up to a whole voxel below), which
  is the fix. The title contradicts the case's own assertion.
- `docs/research/2026-10-29-lobby-flagpole-and-birch-avenue.md` target 5 — *"pole and every avenue
  trunk clear of the lane + verges ..., of the yard rect, of every pad and truck box, and of the
  lodge box"* contradicts section 4 (*"The flagpole stands at (2906, -2915), the open gravel at the
  head of the yard"*) and the shipped code, where `lobby.spec` asserts the pole is INSIDE
  `Build.yardRect`. The yard/pad/bay clause is the avenue trunk's rule only.
- `src/server/Lobby/Build.luau` `avenue()` — it is the only planter that does not call
  `clearOfLodge`, so the lodge is tested against the PIVOT (`Build.insideLodgeBox`) and not against
  the planted model's real bounding box the way `treeLine` and `lodgeTrees` test it. Nothing is
  wrong today: the northernmost west slot (`z = 2`, abs -2948) sits 21 studs south of the keep-out's
  south edge and does not shift in her place. Two shifts would put a ~10-stud crown about 5 studs off
  the porch box. Worth a line if that slot table ever moves north.
- `src/server/Lobby/Build.luau` / `src/server/Lobby/init.luau` — `stats.avenueShifted`,
  `stats.cutY` and `stats.flagpoleY` are still write-only: set, never read, never asserted, and
  `reportLobby`'s boot line still prints `shelfY, parts, fillCalls, grassCalls`. The request queues
  this; `cutY` is the one of the three that would have shown round 1's defect on the console.
- `src/shared/Lobby/init.luau` `CONFIG.AVENUE` and `avenue()`'s header still justify the shift-and-
  drop with dice (*"a hand-tuned slot table would be right for one boot's dice and wrong for the
  next"*, *"a spruce that a different boot's dice put somewhere else"*) while `treeLine` seeds
  `Random.new(1804)` under *"ONE SEED, SO THE WOOD IS THE SAME WOOD EVERY BOOT"*. The guard's shape
  is right; the reason printed beside it is false, and the dropped `Avenue06` is a tunable fact
  rather than luck. The request acknowledges this and queues it.
- `tests/server/lobby.spec.luau` *"plants the avenue when there are templates..."* still passes with
  zero trees planted: `made.avenueTrees + made.avenueDropped == #SLOTS - made.avenueGaps` reads
  `0 + 7 == 7` and `#GetChildren() == made.avenueTrees` reads `0 == 0`. Assert the
  Naturvardsverket floor the sibling case already cites on the PLANTED count
  (`made.avenueTrees >= 5`), not only on the slot table.

---
REVIEWER verdict on commit `ca02877e1bcda7e1306d822316fb8fe332928233` (round 2) · 2026-10-29 13:21 UTC · session cost $4.45, 40 turns · written by tools/agents.py

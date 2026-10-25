# Task 261 -- Karen's Sunday-morning test: five fixes

Task: 261
Round: 2
Base: 03748f79 (main)
Code commit: e42da793596aee66147b5384e79c9233806f32b4

```
[harness] PASS: 34/34 checks @ e42da793596aee66147b5384e79c9233806f32b4 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ e42da793596aee66147b5384e79c9233806f32b4 (clean tree)
```

Both lines are mine this round and name one commit; `test2` now runs without a human, because the
Director's player-count click is saved and `<runs-dir>/press-f7.ps1` reaches *Server and Clients*
(`<runs-dir>/261-test2.py` drives both in one foreground command). The `NEEDS KAREN` entry that
blocked round 1 is closed in `ESCALATE.md`.

## Round 1's two blocking findings, and what they were

**Finding 1 was real, it was mine, and it was Karen's own defect caused by the code written to fix
it.** `stepCarcass` took the carcass's lowest point as `part.Position.Y - part.Size.Y / 2`, which is
the bottom only while the box STANDS UP -- and every carcass that reaches the anchor by the toppled
path is lying on its side. Reproduced as arithmetic off `SPECIES.reddeer.BODY_SIZE` (1.8 x 4.8 x
7.05) and the per-kind scales: **a stag resting exactly on the ground measured 1.500 studs below
it** (hind 1.283, calf 0.742), all past the 0.5 tolerance and inside the 20-stud bound -- so the
correction LIFTED a body that was already down and the anchor froze it there for 120 s.
`Body.verticalHalf(cframe, size)` is the fix: the box's own axes projected onto world up, used for
BOTH the bottom and the ray's origin. Two live cases roll the part a quarter turn first, and they
use a **stag** rather than this block's male on purpose -- a male's error is exactly 0.500, the
tolerance to the stud, so a male case would have passed against round 1's code too.

**Finding 2 was real.** The lift-payback case asserted `liftedBy == 0`, which `stepCarcass` writes
unconditionally, so reverting `Body.liftDrawn`'s `studs == 0` guard left the calf's mesh floating
1.325 studs with the suite green. It now asserts the MESH is back on the part it is welded to.

## What changed, by Karen's sentence

| # | Her words (2026-10-25) | Where |
|---|---|---|
| 1 | *"I been transfarred to same hunt ... with less than min remaining"* / *"I need to be same role and from begining"* | `Match.enrol`, `Phase.barredFromRejoin`, `Lobby`'s `occupancy` + SIT OUT |
| 2 | *"I reach out first and then can go around hunters and spook all animals"* | `Match`'s `throughSweep` + `throughSpotFor`, `Phase`'s grace |
| 3 | *"deer run on road the fall and was sidding on side"* / *"deer also hanging there hunted broken"* | `Boar.Body` `collapse` / `stepCarcass` |
| 4 | *"when animals too much we need show in another row"* | `SCENE.MAX_ANIMALS` 30, `PER_ROW` 6, the `Gather` pad |
| 5 | *"I have a license but can't shoot again"* | `Economy` `DHTestOwns` |

## Claims

1. **A man a live drive let go of cannot be put back into it.** `Phase.barredFromRejoin` is the
   pure rule (the drive number he was withdrawn from, AND `insideDrive`); `Match.enrol` is the one
   door that reads it, off `withdrawnFrom`, which `Match.withdraw` writes and `Match.forget` /
   `stop` / the drive-number move clear. *Verify:* `match_phase.spec` "bars him from the drive he
   left, and only from that one".
2. **And the lobby does not put him on a pad meanwhile.** `occupancy` leaves out a man whose
   `leftDrive` latch is up while `Data.liveDrive(phase)` -- the SAME two phase names the latch is
   armed in and `Phase`'s own `withdraw` branch refuses outside of, spelled once now (TASKS.md 249b).
   SIT OUT clears the latch, which that note asked for and this task makes load-bearing. *Verify:*
   `lobby_live.spec` "keeps a man a live drive let go of off the truck pads" and "clears the latch
   when he sits the next drive out".
3. **His role is the stored turn, and no second mechanism was added.** Round 1 of my own gate caught
   the obvious one: folding `other(team)` into `previousAssignment` moves `Roster.assign`'s swapped
   counts by two, so past a roster of two the balance check discards the whole swap and the men who
   FINISHED stop alternating. *Verify:* the two cases under `match_phase.spec` "a respawn takes one
   player out of the drive" -- one drives the shipping chain (`owed` -> `previousFrom` -> the swap)
   on Karen's own one-man roster, the other drives `Roster.assign` with the folded row on four and
   counts the finishers it breaks. The `withdraw` branch's comment carries the reasoning.
4. **A beater who crosses the hunters' line is walked behind them and held.** `throughSweep` runs
   after the tick (which is what fills the crossing measurement), moves him through `Body.stand` to
   `Match.throughSpotFor` -- 40 studs behind the middle stand, a centred row at 8 -- and holds him.
   *Verify:* `match_scene.spec` "puts a beater who is through BEHIND the hunters, in a centred row",
   which also asserts it is NOT `gatherSpot` (the Forest Test's world answer is the lobby yard).
5. **And the drive ends 15 s after the last of the line is through, instead of running the clock
   out.** `state.beatersThroughAt` is a level-triggered latch, cleared when the line stops being
   through and at both doors out of a drive; `Phase.throughGraceSeconds` answers 0 for a config
   without the row, which is task 159's game exactly. *Verify:* `match_phase.spec` "waits out the
   grace before it ends", "clears the grace if the line stops being through", "the game's own grace
   is the Director's 15 seconds".
6. **A dead animal keeps none of the speed it died at.** `Body.collapse` disables the constraint
   that was DRIVING the animal, which does not stop the BODY; `Body.collapseVelocity` is the pure
   rule and `WOUND.COLLAPSE_KEEP_SPEED` is the dial, at 0. The fall is kept whatever the dial says
   and an upward velocity is not a fall. *Verify:* `boar_model.spec` "takes the speed off a dead
   animal and leaves the fall alone" and "takes the running speed off the body at the moment of
   death".
7. **And it is put ON the ground at the one moment it is about to be frozen there.** The anchor is
   the only thing that can make a carcass hang, because it is the only thing that takes gravity
   away. The ground is read at the carcass's own x,z, from just above it (`ForestTest.groundAt`'s
   `fromY`, which also excludes `Boars`), bounded by a 0.5-stud tolerance and REFUSED past 20 -- and
   the body's bottom is measured with `Body.verticalHalf` at the angle it is LYING at, which is
   round 1's finding 1.
   *Verify:* `boar_model.spec` "puts a settled carcass on the ground before it anchors it" (which
   asserts the x,z and the ray's origin), "does not lift a carcass that is lying on its side", "still
   puts a ROLLED carcass down when it really is hanging", "leaves a carcass that is already down
   alone, and refuses a wild answer", and the two pure truth tables (`Boar.groundDrop`,
   `Boar.verticalHalf`).
8. **The two gaps task 249's review left in this code are closed.** (i) a case now collapses a body
   with a visual and a cached death track and asserts `deathTrack` is armed -- and nil on the
   `boxFalls` path; (ii) `Body.deathTrackOn` asks the clip actually on the rig, so a running PADDLE
   stops the box rolling on top of it (task 150's composed rotations). The death LIFT is paid back
   when the backstop fires -- a CALF's is 1.325 studs. *Verify:* the three `(task 261)` cases in
   `boar_model.spec`'s backstop block.
9. **The gathering holds thirty, and the move is arithmetic.** `Gather` pad -50 -> -62 and 56 -> 80;
   `cornerReachFor(30)` is 36.81, so the scene's east edge is -25.19 against the chimney's -21
   (clears by 4.19, where 16 cleared by 1.91), the pad's east edge is -22 against the lodge wall's
   -18, the margin inside the dirt is 3.19, and all four absolute edges are on the 4-stud voxel
   grid. *Verify:* `lobby.spec` "holds the WHOLE scene at its worst case" and "clears the lodge, the
   porch, the spawn, the road, the fences, the trucks and the four pads"; `match_scene.spec` "lays
   the whole cap out in five rows of six".
10. **It costs six trees, and that is measured in Karen's own place.** `Build.treeLine`'s third
    exclusion (written for exactly this edit) now removes six: **the live Forest Test planted 21 of
    30 where it planted 27, with 0 trunks on the gathering yard**, and nine raycasts across the new
    square came back **9 Ground, 0 grass, 0 misses, 0 non-terrain obstacles** -- so the dirt is
    blade-free and nothing of the world stands in it (`Build.onWorkingGround` gains the gathering as
    its fourth rectangle, which it needed: the `Yard` sweep reaches only x -54). *Verify:*
    `lobby.spec` "lets no tree stand on the gathering yard, and COUNTS the ones it takes out".

## The proof round (Director, 2026-10-25), and what it did and did not reach

Every number below was taken in **Driven Hunt Forest Test**, placeId 130094961655666, this working
copy. Its attributes were read before and after and are IDENTICAL
(`DHFlag_BOAR_BEHAVIOUR/BOAR_MODEL/COINS/DEER_ROAD_LEAP/DRIVE_BOTS/HORN/LICENCE_POPUP/LOBBY/SHOP=true`,
`DHForestStartRole=hunter`, `DHShopTestGrant=true`); `DHTestOwns="licence.reddeer"` was set for the
run and **cleared again**, which the second read confirms.

**ITEM 3 (CORE) -- NOT PROVEN. No kill was taken, and the reason is specific.** The instrument is
built and committed to the runs directory (`261-deerkill.luau`): it shoots a RUNNING animal through
`Shotgun.Remotes.FireRequest` -- the same event the Tool's trigger fires -- and reports, for one
carcass, the flat distance travelled after `Carcass` goes true **in body lengths of its own trunk**
and the lowest bone's gap to the ground under its own x,z at rest. Two faults in it cost the
session, and both are now fixed in the file: the origin was the CAMERA, which in this session sat
870 studs from the character, so `Validator.checkShot`'s 6-stud origin tolerance refused every shot
(`NOT KILLED shots=4` x5, with no console refusal line to show for it); and it sampled once instead
of waiting for a crossing. By the time both were corrected the drive had ended, and the next drive
seated the player as a **Driver with a Horn**. 13 shots were fired and 0 animals died.

**What that last sentence IS evidence of, and it is item 2(c):** the role alternated across a
completed drive on her own path -- `team=Shooters tool=Shotgun` in drive N, `team=Drivers tool=Horn`
in drive N+1, read off the server (`261-state.luau`). That is the rotation Karen asked for, observed
rather than reasoned.

**ITEM 1 (the respawn path) -- NOT PROVEN.** It needs the player in a drive with a gun to reset out
of; the drive cycle had already made him a beater. Nothing about it was reached.

**ITEM 2 (the beater at the line) -- NOT PROVEN on her path.** The probe is written
(`261-beater-through.luau`) and it does not run in this world: it finds the hunters' line through
`CollectionService:GetTagged("DrivenHunt.ShooterPost")` and the Forest Test has **0** of them
(`DrivenHunt.ShooterPost=0 DrivenHunt.DriveLine=0 DrivenHunt.DriverStart=0`) -- that world feeds
`Match` its markers through an injected `world.markers` view, not through tags, and its own layout
is `Workspace.DrivePlaces`. The probe has to read the stands the way the drive does. Stated here so
the next round starts from it rather than discovering it again.

**ITEM 4 -- the yard is measured, the LOOK is not.** Measured live last round and unchanged:
**21 of 30 trees planted** where it planted 27, **0 trunks on the gathering yard**, and nine
raycasts across the new square read **9 Ground, 0 grass, 0 misses, 0 non-terrain obstacles**.
`.screenshots/t261-gather-eye.png` (player eye height, 3 studs over the yard at its east edge,
looking west past the lodge) is opened and described: the new blade-free ground runs up to the
lodge's west end and the remaining birches stand beyond it. **There is no frame of thirty animals in
rows** -- that needs a drive with thirty kills in it -- and Karen has not seen the clearing.

**ITEM 5 -- the attribute was set and cleared on her place, cleanly.** What was NOT observed is the
`[economy] DHTestOwns is set: ...` console line, because the console was not re-read after the boot
that carried it; the grant itself is asserted by `economy.spec` and not by a reading.

## What I could not verify

* **Karen's four defects are still not reproduced on her own path (rule H).** Items 1, 2 and 3 above
  each say exactly what stopped them and what the next round needs.
* **`rifle_client.spec:747` ("Expected rifle, got shotgun") failed on two of six runs and passed on
  the other four, including both PASS lines above.** Nothing in this change touches a weapon, a
  viewmodel or the camera. It is the flake class task 252 was about, one spec along; it is not
  claimed as fixed and it is not claimed as mine.
* **No BEFORE numbers for item 3.** The pre-fix `src/server/Boar/` files were checked out and the
  session was run against them, which is why the session above is labelled "before" in
  `261-kills-before.txt`; it produced no kill either, so there is nothing to compare. The files were
  restored and the tree is clean at the code commit.

## Ledger

```
1. NOT PROVEN (no respawn run on her path: the drive cycle had seated the player as a beater) -- built, gated, and asserted by match_phase/lobby_live specs; the role half is the stored turn and no new mechanism
2. NOT PROVEN (the line probe reads CollectionService tags and the Forest Test has none) -- built and gated; 2(c)'s role alternation WAS observed live (Shooters+Shotgun -> Drivers+Horn)
3. CORE -- NOT PROVEN (13 shots, 0 kills: the probe's origin was the camera 870 studs from the character, so every shot was refused; fixed in the file, but the drive had ended) -- built and gated, and round 1's review then found the ground correction LIFTING a correctly-resting stag by 1.500 studs: fixed, and it is the sharpest argument there is for proving this one on her path
4. NOT PROVEN (no frame of thirty animals in rows; Karen has not seen the clearing) -- the yard IS measured live: 21 of 30 trees, 0 on the yard, 9/9 Ground, 0 obstacles
5. MET (attribute set and cleared on her place, attributes identical before and after; the grant itself is spec-asserted, not read off the console)
```

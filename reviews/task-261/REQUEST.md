# Task 261 -- Karen's Sunday-morning test: five fixes

Task: 261
Round: 1
Base: 03748f79 (main)
Code commit: dc1baceea84cccd33bbbc13eefa8a4694d59d87f

```
[harness] PASS: 34/34 checks @ dc1baceea84cccd33bbbc13eefa8a4694d59d87f (clean tree) scope=all
```

**`[harness2]` IS NOT PASTED AND THE REVIEW CANNOT START WITHOUT IT.** The change touches
`src/server/Match/`, which is on `TWO_PLAYER_PATHS`, so the two-player line is required. I could not
produce it: `press-f7.ps1` does start *Server and Clients* in this Studio, but it comes up with
**0 clients** (`1 new studio(s) beside the editor`), and the control the harness's own instructions
name -- *Test tab -> Clients and Servers -> Players: 2* -- **is not in this Studio's UI any more**.
Its ribbon tabs are Home / Avatar / UI / Script and the test commands live in the `Test` MENU
(`Start Test Session -> Server and Clients F7`, plus an `Add Clients` item that is greyed until a
session runs). `ESCALATE.md` carries it as `NEEDS KAREN`. Everything below is evidence for the
one-player run and for what was measured by hand.

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
   `fromY`, which also excludes `Boars`), bounded by a 0.5-stud tolerance and REFUSED past 20.
   *Verify:* `boar_model.spec` "puts a settled carcass on the ground before it anchors it" (which
   asserts the x,z and the ray's origin) and "leaves a carcass that is already down alone, and
   refuses a wild answer"; `Boar.groundDrop`'s own truth table.
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

## What I could not verify

* **`test2`.** See the top. The review gate asks for it and I could not produce it.
* **Karen's four defects were not reproduced on her own path.** Rule H asks for a before/after pair
  of HER defect and there is none: items 1 and 2 need a played session (respawn, walk to a pad,
  cross the line) and item 3 needs a deer shot at a crossing. What I did do in the Forest Test is
  item 4's measurement above, with a clean boot (`[lobby] built in 97 ms`, no `Stack Begin`, no
  `attempt to`, no error line), and its attributes read identical before and after
  (`DHFlag_* ... DHForestStartRole=hunter DHShopTestGrant=true`), changed none.
* **No frame of the gathering from inside it.** The camera has one owner and rewrites a scriptable
  camera within a frame, so `capture` in Play renders the player's view wherever he is; in Edit the
  lobby does not exist (it is built at run time). `.screenshots/t261-gather-eye.png` is what I have
  -- the new yard's blade-free ground beside the lodge, with the remaining tree line behind it --
  and I looked at it. **A frame of thirty animals in five rows, and whether six trees out of the
  western arc is a lobby Karen likes, are hers.**
* **`rifle_client.spec:747` ("Expected rifle, got shotgun") failed on two of four runs and passed on
  the other two, including the PASS above.** Nothing in this change touches a weapon, a viewmodel or
  the camera. It is the flake class task 252 was about, one spec along; it is not claimed as fixed
  and it is not claimed as mine.
* **Item 5's attribute is not set anywhere.** The dispatch's own route: the value to set on
  `ServerStorage` is `DHTestOwns = "licence.reddeer,role.alwayshunter,rifle.scoped"` (the dispatch's
  example `weapon.rifle` is not this build's id -- the rifle is `rifle.scoped`, and the tool names a
  refused id in a warning rather than staging nothing in silence).

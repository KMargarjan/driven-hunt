PASS

Round 1's two blocking findings are fixed and both fixes discriminate:
`Body.verticalHalf(part.CFrame, part.Size)` now feeds BOTH the bottom and the ray origin in
`stepCarcass`, and the two new rolled cases use a `stag` (`newBody("stag")`, box 1.8 x 4.8 x 7.05,
so `Size.Y/2 - half = 1.5`) — against round 1's code `"does not lift a carcass that is lying on its
side"` reads 1.500 studs high and `"still puts a ROLLED carcass down"` lands 2.4 studs off, so
neither can pass on the old arithmetic. The lift-payback case now asserts
`expect(drawn.Position.Y - handle.part.Position.Y).to.be.near(0, 1e-3)` after the backstop, which
reverting `liftDrawn`'s `studs == 0` guard fails by 1.325. Harness lines name the `Code commit:`
e42da793 with "(clean tree)" for both `test` and `test2`, and `paperwork-after-code-commit.txt` says
OK.

## Notes (non-blocking)
- `src/server/Match/init.luau` / `Match.CONFIG.BEATER_THROUGH.HOLD` — the `false` branch does not do
  what the row says. `Body.stand` → `Body.standCharacter` → `Body.holdCharacter` already zeroes
  WalkSpeed and sets `root.Anchored = true`; `applyHold` is what records `heldStill[userId]`, and
  `applyFree` only restores a userId that is in `heldStill`. So with `HOLD = false` the beater is
  still frozen and anchored and nothing in this owner ever unties him. Either drop the row or free
  him when it is false.
- `src/server/Match/init.luau` / `throughSweep` + the freeze — a human beater who reaches the line
  first is frozen 40 studs behind the stands for the remainder of the drive (the grace only starts
  when the LAST of the line is through), which can be minutes. The Director's sentence quoted in the
  config says *"moved to a safe gathering behind the hunters' line"* and does not say frozen; the
  freeze is this task's own choice and nothing pins it. Worth Karen's eyes before the next round.
- **Three production wires for this task's own claims are untested** — the same gap class TASKS.md
  row 249b queued rather than blocked, so queued here too:
  (a) `Body.collapse`'s `handle.liftedBy += lift` is asserted nowhere (`"gives the death lift back"`
  sets `handle.liftedBy = lift` by hand), so deleting that one line leaves the suite green and the
  calf's mesh floating 1.325 studs again — the exact defect claim 8 closes. Add a `newBody("calf")`
  + visual + seeded `tracks[fall]` case asserting `handle.liftedBy == CONFIG.KINDS.calf.deathLiftStuds`
  after `Body.collapse`.
  (b) `Match.enrol`'s `if Phase.barredFromRejoin(state, withdrawnFrom[userId])` block, and every
  write/clear of `withdrawnFrom`: nothing in `tests/` names `rejoinsRefused` or `withdrawnFrom`, so
  claim 1's owner half rests on the pure predicate alone.
  (c) `throughSweep` itself: nothing names `beatersWalkedBack`; `match_scene.spec` pins only
  `Match.throughSpotFor`'s arithmetic, so "walked back and held" is unobserved. `match_live.spec`
  is where all three belong.
- `src/server/Match/init.luau` / `placedCount` — still slot-collides after `Match.forget`
  (round 1): the count drops and the next man through is handed an occupied slot. A monotonic
  per-drive counter fixes it.
- `src/server/Match/Phase.luau` / `Phase.step`'s Running branch — `maybeRelease` now runs through
  the whole grace, where before the drive ended on the crossing instant, so sounders can be released
  after the line is through (round 1). If that is wanted, say so beside it.
- Still-false claims in shipped comments (all round 1, none fixed):
  `tests/server/match_scene.spec.luau`'s `BEATER_THROUGH` block says *"the case that reads them
  asserts the SHIPPED ones against `Match.CONFIG` separately"* — nothing in the repo names
  `Match.CONFIG.BEATER_THROUGH`; `src/shared/Lobby/init.luau`'s `Lobby.liveDrive` says
  *"`lobby_live.spec` asserts this answers exactly what `Phase.insideDrive` answers for all five
  names"* — no spec names `liveDrive`; `boar_model.spec`'s *"A CONFIG WITH NO ROW AT ALL KEEPS
  EVERYTHING"* overstates, since `math.min(velocity.Y, 0)` clamps a rise whatever the dial says;
  `COLLAPSE_KEEP_SPEED`'s and `Body.collapse`'s *"road slab (a smooth part, not terrain)"* — the
  Forest Test's road is painted terrain.
- `src/server/Boar/Body.luau` / `stepCarcass`'s backstop — when `Body.deathTrackOn` returns the
  PADDLE, `track:Stop(0)` stops the paddle and the fall track in `handle.deathTrack` is dropped
  unstopped, so *"the track is stopped here so a late download cannot apply one behind its back"*
  covers only whichever one was returned (round 1).
- `src/server/Economy/init.luau` / `Economy.TEST_OWNS_ATTRIBUTE` — `DHTestOwns` is not a `DHFlag_`,
  so the harness's override guard cannot see it; only `economy.spec`'s `started()` defaults
  `testOwns = false`. `licence_popup`, `shop_door`, `zz_drive_boundary`, `match_teams` and
  `match_live` pass nil and so read the live attribute under `IsStudio()` (round 1).
- `src/server/Lobby/init.luau` / `occupancy`'s `barred` — the `leftDrive` latch lives until a drive
  has him again, which is wider than `Phase.barredFromRejoin`'s one drive number: a man who left
  drive N and is then NOT taken by the party departing into drive N+1 is off the pads for the whole
  of N+1 too, with only SIT OUT to clear it.
- `tests/server/lobby.spec.luau` / the tree case — `expect(planted >= CFG.TREELINE.COUNT - 10)`
  admits 20..30 where the request names an exact 21 of 30 (round 1); and the new
  `onWorkingGround` case's *"ONE STUD BEYOND IT IS THE WOOD AGAIN"* actually tests a point one stud
  west AND 80 studs south of the yard, not one stud beyond the edge.
- `TASKS.md` row 261 still reads *"THE REVIEW IS BLOCKED ON `test2`"* and names code commit
  `dc1bacee`; `ESCALATE.md`'s closure names `[harness2] ... @ eaef41e0`, a different sha from the
  request's. Paperwork only. Round 1's notes are not queued as a 261a row anywhere.

---
REVIEWER verdict on commit `3558de017467effc830440fc064442d7a4ca539e` (round 2) · 2026-10-25 12:14 UTC · session cost $6.14, 48 turns · written by tools/agents.py

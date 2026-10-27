PASS (item 1 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this change was seen in
Karen's place. No core item (animal behaviour, shooting) is touched, but the deliverable IS a number
she named in seconds and will judge by playing -- the results scene standing up for 9 s and the
footer `NEXT DRIVE IN` counting 9 down. The request says so itself (*"Nothing was played"*), and the
Director's post-merge check (`ftplay.py server lobby-go.luau`, one drive) is the first time anyone
sees it. What HAS been seen: the harness line `PASS: 34/34 checks @ 6cbe6542... (clean tree)
scope=auto:economy,lobby,match`, which names the request's `Code commit:`, is clean, and whose scope
covers all three changed specs (`SCOPE_SPECS`: `match_phase`/`match_live` in `match` and `lobby`,
`lobby_next` in both); `paperwork-after-code-commit.txt` says only `reviews/task-295/REQUEST.md`
followed it.

Verified against the repo, not the request:
- Claim 1: `src/server/Match/init.luau` `SCORE_SECONDS = 9`, one row, one writer. `grep SCORE_SECONDS
  src/` finds exactly one reader -- `Phase.luau` `enterScoring`'s `state.phaseEndsAt = now +
  config.SCORE_SECONDS` -- unchanged, and no second constant. No world overrides it (it is on
  `WORLD_OVERRIDABLE` but nothing in `src/shared/ForestTest/` sets it), so the Forest Test place the
  Director plays runs 9 too.
- Claim 2, DELETE THE PRODUCER: the new `match_phase.spec` case does not survive it. It feeds
  `config({ SCORE_SECONDS = Match.CONFIG.SCORE_SECONDS })` and asserts LITERAL boundaries -- revert
  the row to 4 and `expect((Phase.step(state, ..., endOfDrive + 8.9, cfg)).phase).to.equal("Scoring")`
  reads `Assigning` (the line the quoted failure names, `match_phase.spec:320`); delete the row
  outright and `pairs({ SCORE_SECONDS = nil })` yields nothing, so `config`'s own `SCORE_SECONDS = 5`
  stands and the same line fails. The upper side is pinned too: `endOfDrive + 9` -> `Assigning` holds
  only because `Phase.step`'s `Scoring` arm is `if now >= next_.phaseEndsAt`, with
  `enoughPlayers`/`markersComplete` true from the `join` and `ready`. `Phase.step` begins
  `local next_ = copy(state)`, so reusing `state` for both of the last two steps is sound.
  `match_live.spec`'s `expect(Match.CONFIG.SCORE_SECONDS).to.equal(9)` and `lobby_next.spec`'s
  `expect(CFG.ARM_TIMEOUT_SECONDS > Match.CONFIG.SCORE_SECONDS)` also both fail with the row removed.
- Claim 4: no client copy. `Hud.renderScore` writes `tostring(left)` from the server's `secondsLeft`
  and `scoreCountdownFrom = math.max(scoreCountdownFrom, left)` is the bar's only denominator.
- Claims 5 and 7, the mechanism, checked in the code and not in the prose: `Next.step` step 3 arms on
  `home` (no member in `facts.held`) or on `lateBy >= 0`, and `stepNextDrive` builds `held` from
  `world.isHeld`, which is `enterScoring`'s hold -- so the card's 6 s begins on the `free` edge that
  ends the scene and the two windows cannot overlap. `12 > 9` still puts the hazard-1 rescue after the
  scene. Dropping `CFG.SECONDS > SCORE_SECONDS` therefore drops a share-of-budget statement, not a
  mechanism.
- Nothing else is length-dependent inside `Scoring`: no timed scene constant exists, and the two other
  specs that read the row (`zz_horn`'s `Horn.signalSeconds(...) < SCORE_SECONDS`,
  `zz_drive_boundary`'s `advanceForTests(SCORE_SECONDS + 1)`) read it rather than a literal and only
  get more slack at 9. No spec anywhere still pins the old 15-second total or `<= 8`.
- selene (src and tests), stylua and `rojo build` clean; the archive exists with the lineage.

## Notes (non-blocking)
- `src/shared/Lobby/init.luau` / `PADS.NEXT.SECONDS` comment — the change edited one sentence of this
  block and left it contradicting the paragraph it added. Still standing: *"the three phases now split
  one 15-second budget, and this card keeps the biggest share for the reason written below"* and the
  header *"**IT IS 15 SINCE TASK 249, AND THIS ROW IS THE BIGGEST OF THE THREE.**"* ... *"the
  Director's total is 15 and the split is 4 + 6 + 5"*. Four lines later the new text says *"TASK 295
  TOOK THE TOTAL TO 20 (9 + 6 + 5) ... it is no longer the biggest share"*. Both numbers are in one
  comment. Fix: 15 -> 20 and "biggest" -> "no longer the biggest" in the earlier sentences.
- `src/server/Match/init.luau` / `INTERMISSION_SECONDS` comment — same shape: *"**5 SINCE TASK 249,
  AND IT IS ONE THIRD OF A FIFTEEN-SECOND BUDGET.**"* and *"the Director's dispatch sets the new total
  at **15**. The three rows are 4 + 6 + 5"* sit two lines above the added *"THE TOTAL IS 20 SINCE TASK
  295 (9 + 6 + 5)"*. (*"IT IS THE SMALLEST OF THE THREE ANYWAY"* is still true at 5 < 6 < 9.)
- `tests/server/match_live.spec.luau` / *"the drive's own numbers"* — the `INTERMISSION_SECONDS`
  comment still says *"the Director set that gap at 15 seconds for all three phases"*, in the same
  case whose next assertion is now 9 and whose sibling case is titled 20.
- `src/shared/Lobby/init.luau` / `ARM_TIMEOUT_SECONDS` — the margin between the rescue and the scene
  fell from 8 s to 3 s (12 vs 4, now 12 vs 9) and the rewrite dropped the old justification's *"plus a
  respawn"* clause rather than re-measuring it. Nothing breaks -- the rescue arms the same card with
  the same 6 s and `since` is set at the `Scoring` edge, so 12 > 9 still holds -- but a member whose
  character is slow to come back is now 3 s from the timeout arm instead of 8, and the console line
  (`armed by the timeout`) is the only place that shows it. Worth a measured sentence or a queued row.
- `tests/server/match_live.spec.luau` / the 20-second case — `expect(results + card + walk).to.equal(20)`
  cannot fail: the three values are pinned to 9, 6 and 5 by the three lines above it. The case as a
  whole still fails on any cut (the pins do that work), so this is redundancy and not a hole, but the
  header's *"cut any one of the three and the total moves, and this is the assertion that notices"* is
  not what the sum line does. It predates this task.
- `tests/server/lobby_next.spec.luau` / *"waits the between-drive length the Director's brief names"* —
  with the cross-module relation gone, the case now asserts only `CFG.SECONDS == 6` and Valve's
  5..15 clamp, i.e. a literal and its own bounds. The title still says *"the between-drive length the
  Director's brief names"*, which is now the one thing it no longer compares against.
- `docs/design/drive.md` — the phase table (*"`SCORE_SECONDS` = 25 s"*) and the config table
  (*"`SCORE_SECONDS` | 25 | K | long enough to read a 16-row board"*) still carry 25. Stale since task
  209, not made worse here; Karen's live sentences are the authority, but the design doc for this
  system has now been wrong through three values.

---
REVIEWER verdict on commit `ef3d42e09f869375711a66acda590e99fc287022` (round 1) · 2026-10-27 16:46 UTC · session cost $2.25, 35 turns · written by tools/agents.py

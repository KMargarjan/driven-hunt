PASS

Checked against the repo, not the request: `Phase.step`'s `restart` branch calls
`enterAssigning` and nothing else (the round-1 `enterScoring` is gone); `Match.withdraw` now runs
`board = Score.leave(board, userId)` and `Coins.forDrive` skips `left == true` with
`skippedLeft += 1`; `dispatch`'s per-drive block is `if state.driveNumber ~= driveBefore then` and
`state.driveNumber += 1` in `enterAssigning` is the ONLY writer of that number (`Phase.initial`
seeds 0), so the new edge is the old `Assigning` edge plus the `Assigning`->`Assigning` restart and
nothing else; `measureMarkers` still dispatches nothing; `Score.leave` on a missing row returns the
board unchanged, and `watchPlayer` gives every player a row, so no crash path. `payDrive` has one
call site in `src/server/Match/init.luau` (the `Scoring` edge) and `Score.leave` two
(`Match.withdraw`, `Match.forget`) — claim 8 holds.

Delete the producer, by reading: the `lobby_live.spec` case fails with the restart arm removed
(phase stays `Running`) and failed with round 1's `enterScoring` (`:1953`, quoted), and its
`dismissals == 1` line fails if `Lobby.onPhase`/`Lobby.step` are not wired — so the case is
two-sided. In `zz_pad_restart.spec`, `expect(myRow.left).to.equal(true)` dies with the `Score.leave`
line deleted, and `expect(freshRow.left).to.equal(false)` + `drives == drivesBefore + 1` die with
the drive-number edge reverted to the phase edge (the board is not rebuilt, the row stays `left`).
One line does survive; it is note 6.

## Notes (non-blocking)
- Rule 5, stated so this PASS is not read as rule 5 having been met: task 299 has NO core (animal or
  shooting) item — it is a phase/economy change — so there is nothing of Karen's judgement to have
  seen; no Forest Test session and no frame were taken, and the one thing the change does put on her
  screen (note 3) was not photographed.
- `src/server/Match/init.luau` `Match.enrol` (restart branch) — the comment the change wrote says the
  opposite of what the code does: *"A restart out of `Running` now CROSSES that edge (`Phase`'s own
  restart branch), so the one pay-out in this file covers it"*, while `Phase.step`'s restart branch
  says *"IT MUST NOT CROSS `Scoring`"* and calls `enterAssigning`. The abandoned drive is never paid
  at all. Two comments about money contradicting each other is this project's named failure mode —
  rewrite it to say the abandoned drive reaches no `Scoring` edge and so pays nobody.
- `src/server/Economy/Coins.luau` `Coins.forDrive` header — *"`left == true` -> NOT PAID ... and the
  man is not on the server (`Economy.release` runs on `PlayerRemoving`)"* is no longer true of the
  rows it now skips: a withdrawn man IS on the server. One sentence, same place.
- `reviews/task-299/REQUEST.md` "What I could not verify" — *"nothing drawn"* is wrong. `left` is on
  the wire (`Match.snapshot`, `left = row.left`) and `src/client/Hud/init.luau` draws it:
  `scoreRowText` appends `"LEFT"` and `scorePanelLines` sets `left = (row).left == true`, which the
  panel turns into the faint tag / `gone` frame. So a man who merely respawned is now tagged `LEFT`
  on the results board. It is the drawing the HUD was written for (*"a leaver is not paid ... and the
  `LEFT` tag beside his row is what says why"*), so it is consistent — but it is a visual change and
  it has not been seen.
- Behaviour the change makes outside the faucet, deliberate per the request but undocumented: in a
  drive OTHERS finish, a man who respawned out of it now gets no coins and no completed hunt
  (`huntsCache`, which the shop gates read), and if he was the top hunter `Rank.firstPlaceUserId`
  still names him while `Coins.forDrive` skips him — so NOBODY is paid the first-place bonus for
  that ranking. `docs/design/drive.md` §4.4 still describes `left` as the **leaves** row only
  (*"Their row is kept for this drive's screen, marked `left`"*); queue the withdraw case there.
- `tests/server/lobby_live.spec.luau`, the new case — `expect(state.assignment[1]).to.equal(had)` is
  the line that survives deleting the producer: with a one-man roster `Roster.assign` forces
  `ODD_PLAYER_TEAM` ("Shooters") whatever `previous`/`owed` says (*"AT ONE PLAYER THERE IS NOTHING TO
  BALANCE"*), so the `owed = { [1] = had }` plumbing could be removed and that assertion would still
  pass. Claim 1's "his own team back" is therefore unproven; the drive number, `phaseEndsAt` and the
  two `dismissals` lines are what carries the case. (`match_phase.spec`'s pre-299 solo case has the
  same shape and is 287's, not this round's.) Queue a two-man restart that drives the role.
- `tests/server/lobby_live.spec.luau`, the same case — *"after five more scans"* is about three.
  `Lobby.step` returns early on `now - lastScan < 1 / cfg.SCAN_HZ` with `SCAN_HZ = 10`, and at 0.1 s
  spacing the subtraction of two neighbouring doubles comes out at 0.09999999999999964, so roughly
  every other step is dropped (the restart step at `at + 0.1` is itself dropped). Harmless — one
  scan after the transition is all the finding needs — but the count in the comment is wrong.
- `tests/server/zz_pad_restart.spec.luau` — *"(5 pad steps)"* in the note is one restart plus four
  calls that return at `Match.enrol`'s `if state.participants[userId] ~= nil then return true end`
  and dispatch nothing, so the repeat proves the idempotent door and not a second pay-out path
  (round 1 said the same).
- Claim 3's fail-first line carries the harness's own stamp `DIRTY TREE (3 paths) - NOT valid
  evidence`, which is unavoidable for old `src` plus new tests; what carries it is the four quoted
  TestEZ lines. Note also that `match_phase.spec` is unchanged against the base, so its two quoted
  failures show round 1 broke 287's cases rather than that round 2 added a case.

---
REVIEWER verdict on commit `005fb149613bc54f20c93e671ed7c6fc39a133fb` (round 2) · 2026-10-27 10:52 UTC · session cost $4.29, 50 turns · written by tools/agents.py

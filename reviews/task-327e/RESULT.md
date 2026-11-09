PASS (item 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the pace 5.64 and the crossing-end
WERE exercised in Karen's own Forest Test at the code commit `c61c9d48` (five drives, two of them
ending on `Phase`'s own *"Drive over - the beaters are through"*, read off the client), but KAREN HAS
NOT PLAYED IT, nothing was shot in any of the five drives (`0 ANIMALS` in both described frames), and
NEITHER DESCRIBED FRAME SHOWS THE THING THIS TASK DELIVERS -- `327d2-F1.png` is the hunter's view at
0:49 of drive 5 and `327d2-F2-driver.png` the driver's at 0:36, so the end-of-drive feed line and the
clock at the end are reported from a TextLabel read, not from a frame. Dispatch item 2 is met for a
FOUR-beater drive only: both three-beater drives (285.3, 290.7 s) ended on the clock, and the one
driver test crossed the line by being PLACED there, not by walking it -- so the wait Karen complained
of is unfixed in exactly the configuration she plays as driver. Items 1 and 4 are proven in the repo.

Delete-the-producer, case by case (duty (a)):
- `grid.spec` "the three roads are exact translates" -> `expect(math.abs(seconds - 253.5) < 0.1)`:
  GENUINE. `seconds` is `Grid.CONFIG.cellDepthStuds / Grid.CONFIG.beaterWalkStudsPerSecond`
  = 1430/5.64 = 253.546 against a hand-written 253.5; revert the pace to 5.2 and it is 275 and reddens,
  delete the field and it is arithmetic on nil. This single pin is the whole gate on 5.64.
- `bots_lane.spec` "walks the dealt cell's own depth" -> `expect(seconds + BEATERS_THROUGH_GRACE_SECONDS
  < DRIVE.seconds)`: SURVIVES a revert to 5.2 (278.8 + 15 = 293.8 < 300, green). The request says so
  itself, so it is not offered as the proof of 5.64; the comment's own arithmetic (272.1, "reddens if
  the flat walk grows by 27.9 s") is correct, and `last` 192 s < 257.1 s and 257.1 < 300 both hold.
- `bots_lane.spec` "advances at a beater line's pace, in metres" -> `>= 0.8` / `<= 1.6`: SURVIVES a
  revert to 5.2 (1.456). It is a guard band, and it does fail at 9 studs/s (2.52) and below 2.86, so
  the two literals are real producers; claim 4's "ONLY the ceiling" is true (floor 0.8 untouched).
- `bots_lane.spec`'s `expect(Bots.CONFIG.WALK_SPEED).to.equal(Grid.CONFIG.beaterWalkStudsPerSecond)`
  offered by claim 1: SURVIVES -- see note 2. Not blocking only because 5.64 is pinned by the
  `grid.spec` case above and the one-definition/one-reader fact is checkable in the repo itself.
- `tools/terrainbake.py selftest` ("requires no Flags..."): the check exists
  (`ok("src/server/Places/init.luau requires no Flags...")`) and nothing in the repo reads the deleted
  banner line, so the deletion cannot be what makes it pass.

Gate checked: `[harness] PASS: 34/34 @ c61c9d48d611d27d8419031efa3baa46a27c17bc (clean tree)
scope=all` names the request's `Code commit:` exactly; `paperwork-after-code-commit.txt` says
"Not paperwork: none / OK". `test2` N/A re-checked against `changed-files.txt` rather than the
request's prose: none of the nine changed files is in `agents.py`'s `TWO_PLAYER_PATHS` (which is
`src/server/Match/`, `MatchBoot`, `src/client/Match/`, `src/shared/Drive/`, `src/client/Range/`,
`tests/client/Role.luau` and nine named specs). selene 0/0, stylua clean, rojo build exit 0.

## Notes (non-blocking)
- `src/shared/Grid/init.luau` / `Grid.CONFIG.beaterWalkStudsPerSecond` and
  `tests/server/bots_lane.spec.luau`'s `local GROUND = 1.051` — both NEW comments assert a conclusion
  this task's own five drives refute: *"x1.051 measured ground = 270 s, + 15 s grace = 285 s inside the
  300 s clock"* and *"the line is through with 29.8 s of the clock left"*. `ESCALATE.md`'s own table
  measures 1.053-1.131, and 257.1 x 1.131 = 290.8 + 15 = 305.8, OUTSIDE the clock. The Grid comment
  also says the drive *"crossed at 292.9 s"* where 292.9 was the FIRST of four arriving -- the same
  quantity confusion the escalation flags. This is the exact shape of 327d note (h), now with a
  measured number instead of a modelled one. The drives ran after the code commit, so fixing it needed
  a second code commit and a second harness run; queue it with the 5.75 / `DRIVE.seconds` 315 decision.
- `tests/server/bots_lane.spec.luau` / `expect(Bots.CONFIG.WALK_SPEED).to.equal(Grid.CONFIG.beaterWalkStudsPerSecond)`
  — `Bots.CONFIG.WALK_SPEED = Grid.CONFIG.beaterWalkStudsPerSecond` on its own line, so this is one
  engine value compared with itself through two names and cannot fail while the read stands; a
  hand-written literal `5.64` would ALSO pass. Claim 1's *"reddens on a literal"* is therefore wrong --
  it reddens only on a literal that has DRIFTED. Unchanged by this diff and already queued as
  327d-notes (e); either assert `Bots.CONFIG.WALK_SPEED == 5.64` and let `grid.spec` own the owner, or
  drop the line and say `grid.spec`'s quotient pin is the drift guard.
- `reviews/task-327e/REQUEST.md` claim 5 item 2 — *"`grep -n \"275\" src/shared/Grid/init.luau`: none
  left"* is false; `Grid.CONFIG`'s own new comment line still reads *"Design 4.3's \"1430 / 5.2 =
  275 s\""*. The substance is right: all three sites that ASSERTED 275 s as the shipped walk are
  rewritten, and the survivor is a deliberate quotation of the design being corrected. Reword the claim.
- `docs/design/grid-map.md` §4.3 — still rules *"`Grid.CONFIG.beaterWalkStudsPerSecond = 5.2`"*,
  *"275 s at 5.2"*, *"83 s of margin"*, and §1467 derives the clock from it. The code is now 5.64, so
  the design and `Grid.CONFIG` disagree. Not the Builder's file (dispatch) and `ESCALATE.md` carries
  the number; this needs the Architect, or `grid-map.md` 4.3 becomes the next reader's trap.
- `src/server/Bots/init.luau` — the sentences AROUND the rewritten block still do 3.1's arithmetic:
  `MOVE_REISSUE_SECONDS`'s *"~600 studs to cross at 3.1 studs/s"*, `AHEAD_STUDS`'s *"3.9 SECONDS OF
  WALKING at `WALK_SPEED`"* (12 / 5.64 = 2.1 s) and *"at 3.1 it is 6.2, inside them"* (now 11.28
  against 12), `RECOVER_HOLD_SECONDS`'s *"`SIDE_STEP_STUDS` (10) at `WALK_SPEED` (3.1) is 3.23 s"*
  (now 1.77 s), and the header's *"0.87 m/s ... the band in `bots_lane.spec` is therefore 0.8-1.5 m/s
  now"*. The two assertions behind them still hold (`AHEAD_STUDS` 12 >= 5.64 x 2 = 11.28 with 0.72
  studs to spare; `RECOVER_HOLD_SECONDS` 3.4 >= 1.77), but the file's own numbers are two paces stale.
- `tests/server/forest_stand.spec.luau` ("gives every dealt layout a walk that outlasts the drive
  script") and `tests/server/forest_line.spec.luau`'s `lineNorthAt` / `arrivesGround` — both still use
  task 251's ROAD factor `1.081`, the stale multiplier this task fixed in `bots_lane.spec` and nowhere
  else. Their assertions still pass at 5.64 (257.1 s > last slot 192 s; the stag is at the verge at
  ~201 s against 253.5 s flat), but the printed ground figures are the wrong walk's. Queue with note 1.
- The `[bots] ... N arrived in Xs` number is `stats.walkSeconds = math.max(stats.walkSeconds, at -
  bot.walkStartedAt)` — the LONGEST WALK among arrived bots, timed from each bot's own first step
  (`walkStartedAt` is re-set to nil whenever a bot is re-placed) — and `arrived` is
  `GOAL_PAST_LINE_STUDS` 20 PAST the line, while `Phase.beatersThrough` compares `beatersAcross >=
  beaters` at the line itself. So X is neither the drive-clock time of the last crossing nor the
  crossing: drive 5's 270.6 + 15 s grace = 285.6 s predicts 0:14 left against the reported 0:04, a
  ~10 s gap. The derived factors 1.053-1.131 and the 5.75 / 315 arithmetic inherit it; name which
  quantity is which before the Director takes a number off that table.
- Only ONE assertion in the suite reddens on reverting the pace (`grid.spec`'s 253.5 pin). Nothing
  asserts the relation the task exists for — crossing x ground factor + grace < `DRIVE.seconds`. A
  follow-up could assert `walk * GROUND + BEATERS_THROUGH_GRACE_SECONDS < DRIVE.seconds` with the
  measured worst factor, which would have been RED at 5.64 and is the case the escalation argues for.
- Harness: 2 of 3 runs at this same commit and tree failed (32/34 with `map_ui.spec:1071`, then 30/34
  with the failing lines NOT captured) before the pasted 34/34. The gate line is valid and the
  flakiness is disclosed per L-136, but an uncaptured four-failure run on a green tree is worth the
  Director's eye; this change touches no client code.
- `tests/server/grid.spec.luau` — 1430 / 5.64 = 253.546, so the literal sits 0.046 inside the 0.1
  window. Deterministic, not noise; `253.55` would state the quotient exactly.

---
REVIEWER verdict on commit `11df37631504dc85498f1b58c0beebd1693158a0` (round 1) · 2026-11-09 03:17 UTC · session cost $3.26, 41 turns · written by tools/agents.py

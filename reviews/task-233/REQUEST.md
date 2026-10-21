# Task 233 -- v1 defaults: four of five flags lit, `SHOP` reverted and put to the Director

Task: 233
Round: 1
Base: `main` at `3558c177` (the merge of task 231)
Code commit: `2fc9b20385a69b52b4008915dc0b01ebe9183b9b`

```
[harness] PASS: 34/34 checks @ 2fc9b20385a69b52b4008915dc0b01ebe9183b9b (clean tree) scope=all
```
(1983 server + 517 client assertions, 65 server spec files, 25 client.)

`test2`: **NOT N/A, and NOT the Builder's to run.** `HORN` and `LOBBY` change the drive and
enrolment, so the Director runs it by decision rather than by `TWO_PLAYER_PATHS` -- the dispatch says
so, and says to stop before the review whatever `tools/agents.py` says. `ESCALATE.md` carries
`NEEDS DIRECTOR: test2 for task 233 at 2fc9b203`.

## What changed, and why

Karen's v1 decisions (2026-10-20: money in dollars, the shop and its v1 items, the roles with the
horn) are all merged, but `src/shared/Flags` still had those rows at `default = false`, so a server
WITHOUT her place attributes played the old game. She agreed to the plan on 2026-10-21 (*"good"*).

**Four rows are lit: `BOAR_BEHAVIOUR`, `HORN`, `COINS`, `LOBBY`.** Each is its own commit with the
full gate green after it, and each carries a dated one-line reason plus an `expires` moved to
2026-12-31 for the reason every accepted row carries that date. Every row STAYS, so every flip is one
line from being rolled back, and both branches of each stay reachable by parameter.

**`SHOP` is NOT lit.** It was flipped, measured over three full gate runs, and reverted
(`1a685ef1`). It is not a paperwork change -- it changes the default player's kit -- and the decision
it needs is not the Builder's. `ESCALATE.md` item 2 has the measurement and two options.

## Claims

1. **Four rows are flipped and nothing else in the table moved.** `default = true` on
   `BOAR_BEHAVIOUR`, `HORN`, `COINS` and `LOBBY`; `SHOP`, `QUICK_TEST` and `DRIVE_BOTS` are still
   `false`; `owner` and `born` are untouched on all fourteen rows, and `Flags.DEFAULTS` still holds
   fourteen. *Verify:* `src/shared/Flags/init.luau`;
   `git diff 3558c177..2fc9b203 -- src/shared/Flags/init.luau` shows only `default`, `expires`,
   comments and the lit/dark line.

2. **The four `expires` moves were required, not cosmetic.** `BOAR_BEHAVIOUR` sat at 2026-10-25 --
   four days out -- and `tests/server/flags.spec.luau`'s rot tripwire fails the harness on the day
   after, which blocks whatever gate runs that day. `HORN` (2026-10-31), `COINS` and `LOBBY`
   (2026-11-03) are the same bomb further out. 2026-12-31 is what every accepted row already carries
   and what task 230 moved `BOAR_MODEL` to. *Verify:* the four `expires` comments; `flags.spec`'s
   expiry case; `Flags.problems`.

3. **No assertion was weakened and nothing was skipped, in any of the eight spec files.** Every fix
   either names the world the case means BY PARAMETER, or asks the build and asserts BOTH halves.
   *Verify:* `git diff 3558c177..2fc9b203 -- tests/`; no `SKIP`, `FOCUS` or deleted `expect` in it
   (TestKit fails the run on a skip anyway).

4. **`BOAR_BEHAVIOUR`: 30 server cases went red and each now says it means the OFF flush.** The flip
   alone produced them (`[harness] FAIL: 30/34 ... 1953 passed, 30 failed`). `boar_brain.spec` and
   `boar_sounder.spec` build their brains from a `senseOff()` CONFIG clone -- both files are the
   decision tables of `Brain.step`'s `elseif sensing then` arm. `boar_body.spec` pins
   `SENSE = { ENABLED = false }` in both worlds: its threats stand 20 and 25 studs behind, inside
   `NOTICE_STANDING` (25) but outside `FLUSH_STUDS` (15), so the sense model reads them as AVOID and
   the bodies never sprint at all. `boar_shot.spec` pins it in the one config block every world is
   built from: its drivers exist to make animals MOVE so a footstep ration can be measured, and at
   18 and 38.5 studs the sense model leaves them grazing. *Verify:* `senseOff` in the two pure files;
   the two `config` tables in `boar_body.spec`; the `SENSE` entry in `boar_shot.spec`'s `buildWorld`;
   each comment names the measured failure it answers.

5. **...and the ON world keeps its own two files, so the flip did not take coverage away.**
   `boar_behaviour.spec` and `boar_behaviour_live.spec` turn `SENSE.ENABLED` on by parameter and are
   untouched: the notice radii, the AVOID turn, the panic spread, both formations and the live
   sprint are asserted there. *Verify:* `git diff 3558c177..2fc9b203 --stat -- tests/` lists neither
   file; `config = { SENSE = { ENABLED = true } }` in `boar_behaviour_live.spec`'s header.

6. **One real gap was closed, not papered over: `boar_shot.spec`'s threat fakes carried no `id`.**
   The seam is `world.threats()` giving `{ { id, position } }` and every production provider sets it
   (`Match.Body.boarStimuli`, `ForestTest.boarThreats`), but nothing read it while the flag was off.
   `Runtime:_measureMotion` indexes by it, so three cases died with
   **"ServerScriptService.Boar:3681: table index is nil"**. *Verify:* the three `threats` providers
   in `boar_shot.spec`; `Runtime:_measureMotion` in `src/server/Boar/init.luau`.

7. **`HORN` is a one-line game change in the DEV drive and nothing at all in the Forest Test.**
   `ForestTestBoot` has carried `local hornOn = true` unconditionally since task 152 -- Karen's own
   world already had it -- so this flip is `MatchBoot` and every other default server catching up.
   `zz_horn.spec`'s declaration case asserts the LIT row and now asserts `owner` and `born` unchanged
   beside it, so a row somebody rewrote cannot pass as one somebody lit. *Verify:*
   `ForestTestBoot.server.luau`'s `hornOn`; `MatchBoot.server.luau`'s `Flags.isOn(HornData.FLAG)`;
   `zz_horn.spec`'s *"was born OFF and since task 233 it is LIT"*.

8. **`COINS`: the only two cases that went red were claims about the REAL running drive, and both
   now ask the build.** `match_teams.spec` (*"Expected Shooters, got nil"*) and `match_client.spec`
   (`snapshot.coinsOn`: *"Expected nil, got true"*). Each asserts the ON shape and the OFF shape --
   the shape `zz_drive_boundary.spec` already used -- so flipping the row back is still measured
   rather than silently unasserted. **`match_teams.spec` deliberately does NOT assert that a row
   exists:** `Economy.noteNextTeams` skips a player whose profile session has not answered yet, and
   the drive-end edge is what reconciles it, so asserting a row here would be asserting that race
   away. The hazard the case exists for -- a record naming the OTHER team -- is asserted for every
   player with no condition at all, and the note carries the counts and the load stats so a run where
   nobody got a row is visible rather than silently green. *Verify:* both cases;
   `Economy.noteNextTeams`'s `sessions[userId] == nil` branch; `Match`'s write edges 1 and 2.

9. **`LOBBY` is a no-op in the DEV place, measured before it was flipped.** `MatchBoot` NEVER calls
   `Lobby.start` -- the only caller in `src/` is `ForestTestBoot` -- and even if it did,
   `Data.anchorFor("map:v1")` is nil and `start` returns `false` without building anything or writing
   a stud of terrain. So the harness's player path and enrolment are byte-identical either way, and
   no spec needed a change: `lobby_live.spec` names both `enabled` and `world` in its own fakes, and
   nothing in `tests/` reads `Lobby.ENABLED` or the flag by name. *Verify:*
   `grep -rn "Lobby.start" src/`; `Lobby.start`'s `row == nil` branch; `fakes` in `lobby_live.spec`.

10. **`SHOP` is reverted and the reason is written down, with the solved half archived.** The revert
    is `1a685ef1` and `Flags.DEFAULTS.SHOP.default` is `false` at the code commit. The measurement
    (5 stable server failures, 15 client failures in two runs of three and 1 in the other) and the
    two options are in `ESCALATE.md` item 2; the diff that takes the server side to 0 failures is
    `backups/2026-10-21_task-233_shop-on-spec-pins.txt` with its row in `backups/README.md` (rule 7).
    *Verify:* the `SHOP` row; the revert's commit message; `ESCALATE.md` 2026-10-21 item 2.

## What I could not verify

- **Frame (c), the horn in a beater's hand: not reachable in DEV.**
  `Match.requestTeam(player, "Drivers")` returns **false** with one player -- the roster will not
  leave a one-player drive without a hunter -- so no horn is carried there, and the dispatch's
  *"if a beater is reachable"* resolves to no. `HORN`'s evidence is `zz_horn.spec` by parameter plus
  the Forest Test, which has had it on since task 152.
- **Frame (a) is a measured TRACE and not a screenshot, and that is a harness limitation (rule 6).**
  One `capture` round trip is ~15 s; a reacting boar trots at 18 studs/s and sprints at 38, so it is
  270 to 570 studs away by the time the shutter falls. Four attempts, four empty fields. The two
  traces are in `TASKS.md` and the task report; frame (b), the `$0 MONEY` drive bar, is in all four
  frames and was inspected.
- **`test2` has not been run.** The Director runs it, by the dispatch's own decision.
- **Karen has not seen any of this.** Nothing here was judged by eye for feel.
- **Two flakes seen once each and not reproduced:** `camera_client.spec:376` failed in the session's
  very first run -- on `main`'s own tree, before any change -- and never again in nine later runs;
  `boar_body.spec:743` failed once on `pathFailures` under load. Neither recurred at the code commit.

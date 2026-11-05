# Task 329a -- the first Play after a sync: "gun not in hand"

Task: 329a
Round: 1
Base: dadc3540 (main, 328z #333 merged)
Code commit: `0086ab92`
(no `src/`, `tests/` or `tools/` file changed -- `git diff --name-only dadc3540..HEAD` is
`TASKS.md` and `reviews/task-329a/` only, so `harness_gate` reports *docs-only change: no
harness line required*. The sha above is the paperwork commit the claims were written at.)

## What changed

Nothing in `src/`, `tests/` or `tools/`. The fault is in the Director's smoke check, so the
deliverable is `<runs-dir>/smoke-329a.patch` (a placeholdered, readable copy is
`reviews/task-329a/smoke-329a-patch.md`; the absolute path in the diff's context would fail
`tools/privacy_scan.py` in a tracked file, so that copy is not apply-clean) plus `reviews/task-329a/EVIDENCE.md`. `<runs-dir>/smoke.sh` is untouched: the
patch was developed and run as `<runs-dir>/smoke-329a-test.sh`.

## Claims

1. **It is a HARNESS FAULT, not a player bug.** `smoke.sh:15` is
   `case "$lob" in lobby*) ... sleep 20;; esac`, and `lobby-go.luau:2` answers **`nolobby`** while
   `workspace.Lobby` does not exist. `nolobby` matches no branch of `lobby*`, so `lobbyfail` stays 0,
   there is no step-on, and the player is never put on a truck pad -- after which line 35's
   `FAIL: gun not in hand` and a `position ... y=153` are the only words the run has for it.
   *Verify:* read those two lines; then `<runs-dir>/t329a-ft1.txt` -- the step-on fired at server
   t=1.6, answered `nolobby`, and 100 s later the probe still read
   `pad1=empty team=nil tool=nil y=153.4`.
2. **The player's own path is correct**, so there is nothing to fix in `src/`. Control
   `<runs-dir>/t329a-ft2.txt`: the step-on held until after the lobby was up gives
   `pad1=empty` -> `sizing` (8 s) -> `countdown` (5 s) -> `team=Shooters tool=Shotgun y=110.5`,
   13.98 s after the step-on -- the 13.2 s that `src/shared/Lobby/init.luau`'s
   `PICK_TIMEOUT_SECONDS` (8) plus `COUNTDOWN_SECONDS` (5) plus a `SCAN_HZ` (10) scan predicts.
   *Verify:* the pad-state column of that file against `Pads.step`'s cases 2, 3b, 4 and 5.
3. **The margins are measured, in server-clock seconds.** The `Lobby` folder appears at
   **12.2-14.5 s** of the server's own boot over 6 Forest Test Plays; the step-on -> gun leg takes
   **13.9-18.0 s**. The two blind sleeps were 15 s (plus process cost) and 20 s.
   *Verify:* section 1 of `EVIDENCE.md` and the `t=` column of `t329a-rows-ft-p1.txt`,
   `t329a-ft1.txt`, `t329a-ft2.txt`, `t329a-mirror-m1.txt`.
4. **A second blind wait, found by fixing the first.** Polling only for the folder stepped the player
   on at +12 s, inside the 0.5-1.2 s window where the folder exists but the lobby has not taken him
   (`gunBefore=true`); the lobby then stood him back at the lodge, off the pad, and no gun arrived in
   51 s. So the poll now ends on `gunBefore=false` -- the fact the next line already asserts.
   *Verify:* `t329a-smoke-4.txt` (`lobby-go at +12s: [lobby gunBefore=true]`, `g1=0`, `y=153.4`), and
   the window itself in `t329a-ft2.txt` (`t=12.21 tool=Shotgun y=141.2`, then
   `t=12.73 tool=nil y=153.7`).
5. **A sync does not cause it through compile time.** `DEV ONLY`: with 15 scripts rewritten by rojo
   immediately before the Play, `set_play` returned 0.73 s after the server's clock started, against
   0.75 and 0.70 on two warm Plays -- so a slower compile moves smoke's sleep and the server's clock
   together. *Verify:* the three `BOOT dev-*` rows in section 1; the scratch edits were reverted and
   `git status` is clean.
6. **DEV cannot test this path at all**, which refutes that part of the dispatch.
   `Map.WORLD_BY_PLACE` gives DEV `map:v1` and `ForestTestBoot.server.luau:24` returns unless the
   world is `forest-test`: no lobby, no pad, no step-on. *Verify:* those two places in `src/`.
7. **The fix fails loudly where it used to pass silently.** With `SMOKE_LOBBY_WAIT=0` the patched
   script prints `FAIL: no lobby after 5s -- the boot had not finished, so the player was never
   stepped onto a truck pad (task 329a)` above the old `FAIL: gun not in hand` and the same
   `y=153.4`. *Verify:* `t329a-control-nolobby.txt`. Deleting the poll restores exactly the old
   silent skip, which is what the pre-fix runs did.
8. **5 consecutive patched runs PASS**, each printing its own measured waits (lobby +13..17 s, gun
   +17..18 s), `stacks=0 errorLines=0`, and `position @15s`/`@end` at `y=110.5`.
   *Verify:* `t329a-v2-1.txt` .. `t329a-v2-5.txt`, 17:20-17:33 UTC 2026-11-05.
9. **No harness gate is owed.** `git diff --name-only dadc3540..HEAD` is `TASKS.md` plus the three
   files of `reviews/task-329a/`, so this is a docs-only change. `python tools/studio_mcp.py selftest` and
   `python tools/agents.py selftest` were both run and both PASS (rule G).
10. **Karen's place was not altered.** All 18 `ServerStorage` attributes are byte-identical to the
    snapshot task 328z left (`328z-r3-attrs-AFTER.txt` vs `t329a-attrs-AFTER.txt`), no code was ever
    checked out in `driven-hunt-karen` (still detached at `dadc3540`), nothing was served to :34873,
    and the Forest Test is left in **Edit**.

## Could not be verified

* **Which of the two blind waits ran out on 2026-11-04.** Both print the same
  `FAIL: gun not in hand` with the player at y=153; they differ only in the summary line's
  `lobby=[...]` field and in the console, and `smoke.sh` overwrote both console files on the next run
  (L-043). `grep -rl nolobby` over `<runs-dir>`, `reviews/`, `TASKS.md` and `ESCALATE.md` finds only
  probe sources. The patch closes L-043 so the next occurrence keeps its own evidence.
* **Five first-Plays-after-a-sync in Karen's place: NOT OBTAINABLE.** Forcing "first" needs a sync
  that changes a script, and the dispatch forbids serving anything but merged main to :34873;
  `karen-build.sh` is already at `origin/main`, so re-running it pushes nothing. The five runs above
  are consecutive Plays at that commit, and neither wait depends on boot speed any more.

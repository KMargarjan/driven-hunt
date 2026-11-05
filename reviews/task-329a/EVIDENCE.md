# Task 329a -- "gun not in hand" on the first Play after a sync: the measurement

Every number below was read in **Karen's Forest Test** (placeId 130094961655666, rojo :34873 at
merged main `dadc3540`) unless the row says `DEV ONLY`. The instruments are
`<runs-dir>/t329a-probe.luau` (INSTANCE facts only: the pad part's `DHPadState`, `Player.Team`, the
`Tool`'s parent, the root's Y), driven by `t329a-table.py` / `t329a-time.py` / `t329a-load.py`, and
`t329a-mirror.sh`, which replays `smoke.sh` lines 10-16 with a timestamp on every step.

The console's own `%.2fs` figures (`places: ... 20.88s`) are `os.clock()` deltas --
`src/server/Places/init.luau:994,1088` -- which in Roblox is **process CPU time, not wall time**, so
they overstate. They are not used as timings here.

## 1. The timing table

Wall offsets are from the moment the Play was requested. `studio_gap` is how long Studio spends
before the server's own clock starts; `t_lobby` and the rest are in **server** seconds, which is the
clock every deadline in `Lobby` runs on.

| run | what it was | start returned | studio_gap | t_lobby | lobby TOOK him | step-on -> gun | verdict |
|---|---|---|---|---|---|---|---|
| ft1 | FT, 1st Play of the session, step-on at server t=1.6 | 18.59 | 17.52 | 12.59 | - | never (100 s) | **reproduces the fault** |
| ft2 | FT, step-on held until after the lobby was up | 16.51 | 16.92 | <=12.21 | 12.73 | **13.98** | pad takes + arms him |
| ft-p1 | FT | 17.22 | 16.07 | 13.22 | - | 16.14 | ok |
| ft-p2 | FT | 17.36 | 16.22 | 13.25 | - | 15.88 | ok |
| m1 | FT, `smoke.sh` lines 10-16 mirrored | 21.36 | 17.75 | <=19.00 | - | g1=1 | ok |
| load | FT booting while the DEV window also played | 18.98 | 17.92 | **14.47** | - | - | +1.3 s only |
| dev-warm1 | `DEV ONLY`, 1st Play of the session | 12.64 | 11.89 | n/a | n/a | n/a | start = server+0.75 |
| dev-FIRST-after-sync | `DEV ONLY`, 15 scripts rewritten by rojo first | 6.47 | 5.74 | n/a | n/a | n/a | start = server+0.73 |
| dev-warm2 | `DEV ONLY` | 6.58 | 5.88 | n/a | n/a | n/a | start = server+0.70 |

So: the `Lobby` folder appears **12.2-14.5 server-seconds** into the boot; the lobby finishes
**taking** the player (disarming him, standing him at the lodge) **0.5-1.2 s** after that
(`t329a-ft2.txt`: `t=12.21 ... tool=Shotgun y=141.2` then `t=12.73 ... tool=nil y=153.7`); and once
he is on a pad the drive arms him in **13.9-18.0 s** (8 s to pick + 5 s to leave + a scan --
`src/shared/Lobby/init.luau:1877,2422`, which predicts 13.2 s).

**DEV cannot answer the question the dispatch put to it.** `Map.WORLD_BY_PLACE`
(`src/shared/Map/init.luau:74-77`) gives DEV `map:v1`, and `ForestTestBoot.server.luau:24` returns
immediately unless the world is `forest-test` -- so DEV has no lobby, no truck pad and no step-on
path. What DEV *did* answer is the sync question: with 15 scripts rewritten by rojo immediately
before the Play, `set_play` still returned 0.73 s after the server's clock started, exactly as on the
two warm Plays (0.75, 0.70). **A sync does not slide `smoke.sh`'s sleep off the server clock.**

## 2. The cause, and the line that proves it

`smoke.sh:15`

    case "$lob" in lobby*) echo "$lob" | grep -q "gunBefore=false" || lobbyfail=1; sleep 20;; esac

`lobby-go.luau:2` answers `nolobby` when `workspace.Lobby` does not exist yet. **`nolobby` matches
no branch of `lobby*`** -- it starts with `n` -- so when the boot is still running:

* `lobbyfail` stays 0, so nothing complains;
* there is no `sleep 20`, and more importantly **no step-on**: the player is never put on a pad;
* he therefore sits on the lodge porch with no gun, and the run's only words for it are line 35's
  `FAIL: gun not in hand` and `position ... y=153`.

That is the Director's observation, both times, verbatim. Reproduced live in `t329a-ft1.txt`: the
step-on fired at server t=1.6, answered `nolobby`, and 100 s later the probe still read
`pad1=empty team=nil tool=nil y=153.4`.

It is a **HARNESS FAULT, not a player bug.** The control (`t329a-ft2.txt`) holds the step-on until
after the lobby is up and the player's path then works exactly as designed: `pad1=empty` ->
`sizing` (8 s) -> `countdown` (5 s) -> `team=Shooters tool=Shotgun y=110.5` at server t=41.55,
13.98 s after the step-on.

## 3. The second blind wait, found while proving the first

With the lobby step polled, round 1 of the patch stepped the player on as early as +12 s -- inside
the 0.5-1.2 s window where the folder exists but the lobby has **not** taken him
(`gunBefore=true`). The lobby then stood him back at the lodge, **off the pad**, so the pad never
took him either: `t329a-smoke-4.txt` reads `lobby-go at +12s: [lobby gunBefore=true]`, then
`g1=0` 51 s later, `y=153.4` throughout. Same output as fault 1, different cause.

So the wait now ends on `gunBefore=false` -- the fact the next line already asserts -- and nothing
else. A player walking there himself cannot hit this window (the lobby is ready ~13 s into the boot,
before anyone can cross the yard from spawn), so it is a harness-only exposure and no `src/` change
is proposed for it.

## 4. What the patch does

`<runs-dir>/smoke-329a.patch` (copy beside this file). `smoke.sh` itself is untouched: the patch was
developed and run as `smoke-329a-test.sh`.

1. the blind `sleep 15` becomes a **poll of `lobby-go` until `gunBefore=false`**, bounded by
   `SMOKE_LOBBY_WAIT` (default 70 s against a measured 12.2-14.5 s need), and the measured time is
   printed: `lobby-go at +13s: [lobby gunBefore=false]`;
2. the blind `sleep 20` becomes a **poll for the Tool in the character**, bounded by
   `SMOKE_GUN_WAIT` (default 50 s against a measured 13.9-18.0 s need), also printed;
3. **no lobby is now a FAIL, not a skip** (in the Forest Test only -- `SMOKE_PLACE` elsewhere keeps
   the old single call and the old semantics), with a message that names the cause;
4. the end-of-run check is held at `S` seconds after Play, computed from the elapsed time rather
   than from a sleep that no longer exists;
5. **L-043**, recurring since 2026-10-27: each run now keeps `smoke-console-<stamp>.txt` and
   `smoke-console-boot-<stamp>.txt`, so back-to-back runs stop destroying each other's stacks.

## 5. After the fix: 5 runs in a row, each quoted

    lobby=[lobby gunBefore=false] (+17s) gun in hand @+17s=1 @80s=1 | stacks=0 errorLines=0 | waves=9  | ... SMOKE PASS
    lobby=[lobby gunBefore=false] (+13s) gun in hand @+18s=1 @80s=1 | stacks=0 errorLines=0 | waves=10 | ... SMOKE PASS
    lobby=[lobby gunBefore=false] (+13s) gun in hand @+17s=1 @80s=1 | stacks=0 errorLines=0 | waves=10 | ... SMOKE PASS
    lobby=[lobby gunBefore=false] (+13s) gun in hand @+17s=1 @80s=1 | stacks=0 errorLines=0 | waves=10 | ... SMOKE PASS
    lobby=[lobby gunBefore=false] (+13s) gun in hand @+17s=1 @80s=1 | stacks=0 errorLines=0 | waves=9  | ... SMOKE PASS

`t329a-v2-1.txt` .. `t329a-v2-5.txt`, 17:20-17:33 UTC, each with `position @15s` and `@end` at
`y=110.5` (in the drive) and `stacks=0 errorLines=0`.

**The fault fires on the pre-fix path through the same trigger** (L-146), `t329a-control-nolobby.txt`,
`SMOKE_LOBBY_WAIT=0`:

    lobby-go at +5s: [nolobby]
    FAIL: no lobby after 5s -- the boot had not finished, so the player was never stepped onto a truck pad (task 329a)
    position @15s=[... y=141.2] @end=[... y=153.4] respawn+10s=[... y=153.4]
    FAIL: gun not in hand
    SMOKE FAIL

The last two lines are all the old script printed. The line above them is the whole point of the fix.

## 6. What is NOT proven

**Which of the two blind waits actually ran out on 2026-11-04 is not recoverable.** Both produce the
same `FAIL: gun not in hand` with the player at y=153, and they are told apart only by the summary
line's `lobby=[...]` field and the console -- and `smoke.sh` overwrote both console files on the next
run (L-043, which item 5 above now closes). `grep -rl nolobby` over `<runs-dir>`, `reviews/`,
`TASKS.md` and `ESCALATE.md` finds only probe sources, no saved summary line.

**Five first-Plays-after-a-sync in Karen's place: NOT OBTAINABLE.** Forcing "first" needs a sync that
changes a script, and the dispatch forbids serving anything but merged main to :34873;
`karen-build.sh` is already at `origin/main` (`dadc3540`), so re-running it changes no file and rojo
pushes nothing. The five runs above are consecutive Plays at that commit. What makes the fix hold
regardless is that neither wait depends on boot speed any more: both bounds are ~4x the measured
need, and a boot slower than that now names itself instead of reporting a missing gun.

## 7. After the round-1 PASS: two of the Reviewer's notes fixed in the patch, the rest queued

`reviews/task-329a/RESULT.md` line 1 is `PASS (items 2, 8 NOT PROVEN)`. Notes under a PASS are
queued and not fixed (CLAUDE.md, the loop, step 5) -- but two of them named defects in the
deliverable the Director has not applied yet, and shipping a patch with a known bug in it is worse
than the rule it would follow. Both are fixed in `<runs-dir>/smoke-329a.patch` and re-proven; the
other six are queued in `TASKS.md` as 329a-notes.

1. **The non-Forest-Test branch is restored bit for bit** (note 2). `nolobby` was only ever set
   inside the FT branch, so another `SMOKE_PLACE` fell through into the gun poll and sat there for
   `SMOKE_GUN_WAIT`, after which `rest` went negative and the end check was no longer at `S`. A
   `gunpoll` flag now carries it: the FT polls, anything else keeps its old `sleep 15`, its old
   single `lobby-go`, its old `sleep 20` and its old single `wq` read.
   *Proven:* `t329a-v3-dev.txt`, `SMOKE_PLACE=136410205938347`, `lobby-go at +18s: [nolobby]`, no
   new FAIL, `g1=1`, **SMOKE PASS** in 120 s.
2. **`position @15s=` is renamed `position @after-gun=`** (note 3). That probe is now read after both
   polls -- about +30 s -- and at a true +15 s the player is still at the lodge, so the old field
   name asserted a time the line never sampled.
3. Two sentences the Reviewer asked for are now **in the patch's own comment** rather than only
   here: that task 177's "no gun in the lobby" check is deliberately satisfied by any one sample in
   the window and must not be re-tightened to the first answer (note 8), and that the remainder
   between the config's predicted 13.2 s and the measured 13.98 s is the poll granularity plus the
   depart teleport and the equip, not something the config predicts (note 5). The `nolobby` message
   now also names the probe-failure cause (note 4).

**Re-proven after the amendment**, both at `<runs-dir>/smoke-329a-test.sh` as rebuilt:

    lobby-go at +17s: [lobby gunBefore=false]
    gun in hand at +17s after the step-on: g1=1
    position @after-gun=[... y=110.5] @end=[... y=110.5]        SMOKE PASS      (t329a-v3-1.txt)

    lobby-go at +4s: [nolobby]
    FAIL: no lobby after 4s -- the boot had not finished, or lobby-go did not answer, ...
    FAIL: gun not in hand                                       SMOKE FAIL      (t329a-v3-control.txt)

**And the Reviewer's first note is accepted as written:** the five PASS runs are a REGRESSION check
-- the old script passed on a warm Play too, which is the dispatch's own *"a second smoke straight
after PASSED"*. What proves the fix is the `SMOKE_LOBBY_WAIT=0` control, where the new script names
the cause that the old one reported only as a missing gun. Section 5's five runs should be read as
"the patch does not break the path that already worked", and nothing more.

# Task 356 -- the half-second stall when a wave releases

Task: 356
Round: 1
Base: fc2f99ba10de470ced7282dea1b44cc50f1a8ec8 (`main`)
Code commit: 72e3f25450202c6c124edb737fac3b7f5ec4d05e

```
[harness] PASS: 34/34 checks @ 72e3f25450202c6c124edb737fac3b7f5ec4d05e (clean tree) scope=all
```

`test2` is **N/A**: nothing in `TWO_PLAYER_PATHS` is touched (`src/server/ForestTest/`,
`src/server/ForestTestBoot.server.luau`, `tests/server/forest_placement.spec.luau`, `docs/`,
`backups/` -- no `Match/`, no `Drive/`, no client role spec).

## WHAT CHANGED, AND WHAT DID NOT

**No behaviour changed.** Not one line that decides what a drive does was touched: no animal, no
slot, no route, no position, no release time. The whole diff is an **instrument**, its **spec**, a
**research note** and the **measurements**.

**The fix the dispatch asked for was not written, because its premise is false.** `ESCALATE.md`
(2026-11-13 ~02:45) is the entry and says why in full. In short: `releaseLine` really does take
570-845 ms of WALL time per wave, 98.2 % of it `path:ComputeAsync` -- but `ComputeAsync` is a
**yielding** function, the call spans **27 / 24 / 43 Heartbeats**, and the worst frame that ever
happens while a release is in flight is **46.5 ms (mean 23.0 ms over 373 frames) against 23.3 ms
for the drive's other 14,507**. There is no half-second freeze to remove, and time-slicing,
precompute and cache all buy frame time that is not being spent.

## CLAIMS

1. **`path:ComputeAsync` is 732.0 of `releaseLine`'s worst 745.4 ms (98.2 %).**
   *Verify:* `reviews/task-356/MEASUREMENTS.md` section 1; the raw line is in
   `<runs-dir>/BEFORE-track.txt` (`RELEASE ... routes=733.0 (path=732.0 clear=0.7)`). The bill is
   `releaseProf` / `ForestTest.releaseBill` in `src/server/ForestTest/init.luau`.
2. **The call spans many frames, so the 570 ms is not a frame.** `FRAMES=27 / 24 / 43` over three
   drives. *Verify:* MEASUREMENTS section 2(a); `<runs-dir>/BEF2-track.txt`, `BEF3-track.txt`,
   `BEFORE-track.txt`. The counter is `stepTicks`, incremented at the top of `ForestTest.step`
   (one entry per Heartbeat) and read across the call in `ForestTest.releaseLine`.
3. **A frame during a release is not fatter than any other frame: mean 23.0 ms vs 23.3 ms.**
   *Verify:* MEASUREMENTS section 2(b); the `hb-in-release` / `hb-elsewhere` halves of
   `ServerStorage.DHReleaseBill`, written by `ForestTestBoot`'s Heartbeat off `ForestTest.releasing()`.
4. **That null result has a positive control: a 250 ms spin inside a release read back as
   `hb-in-release max=277.9 mean=188.7`.** *Verify:* `<runs-dir>/CTRL-track.txt` against
   `<runs-dir>/BEFORE-track.txt`; the control's code, why it was run and why it is not in the tree
   are in `backups/2026-11-13_task-356_release-burn-control.md` (rule 7).
5. **The drive's real worst frame is 1,421.7 ms, with NO release in flight, and it is the lobby's**
   (`Lobby.step` + `reportLobby`, 1,214.6 ms of it). *Verify:* MEASUREMENTS section 2(b) and
   section 5 item 1; `<runs-dir>/BEFORE-track.txt`'s `BOOTOWNERS ... lobby=1214.6/1857.0`.
6. **The spec fails if the instrument is broken, and it is not a tautology.**
   `tests/server/forest_placement.spec.luau`, `describe("the release bill (task 356)")`: the rollup
   keeps the WORST call and not the last (delete the `totalMs > releaseWorstMs` guard and the second
   `expect` fails -- **L-028**); the bill names all nine sections, `FRAMES=`, the pathfinder's counts
   and the legs; and a real release through the existing `stubRuntime` is charged to
   `ForestTest.releasing()` **while it runs** (read from inside the patched `computeRouteVia`, which
   is the stand-in for a Heartbeat firing during the yield) **and to nobody after it**.
   *Verify:* read the three cases; the harness line above ran them (83 server spec files).
7. **The research note meets rule 1 with four named, linked sources** -- Roblox's `Path:ComputeAsync`
   (it says "yields"), `RunService.Heartbeat` (`deltaTimeSec` is the frame), Brendan Gregg's
   off-CPU analysis (the pattern: split waiting from working), and the MicroProfiler, **refused with
   the written reason rule 2 requires** (no scripting API, unreadable from a headless session).
   *Verify:* `docs/research/2026-11-13-yielding-work-is-not-a-frame.md`; indexed in
   `docs/research/INDEX.md`.
8. **Her place was not written to and nothing was left behind.** The only attribute this task set
   (`DHReleaseBurn`) was set at RUNTIME inside the Play session, which is discarded at stop, never
   in Edit; `flags.py --place forest clear` was never run (rule K). *Verify:*
   `<runs-dir>/356-attrs-before.txt` vs `356-attrs-after.txt` -- **24 attributes, identical**, and
   neither `DHReleaseBurn` nor `DHFlag_BOAR_ATTACH_BUDGET` appears in the after file.
9. **The instrument's own cost is stated rather than left out, and is not claimed to be measured.**
   ~20 `os.clock()` calls per release (26 a drive) plus one `releasing()` call and two adds per
   frame; the boot's average step reads 1.21 ms with it in against 1.10 ms in an earlier drive,
   which is inside the spread of two drives that released different patterns. *Verify:*
   MEASUREMENTS section 4.
10. **`BOAR_ATTACH_BUDGET` was left alone, as instructed.** It is absent from her place in both the
    before and after attribute reads, so every number here is at her own setting (OFF), and the
    80-102 ms boar step peak in MEASUREMENTS section 3 is that arm. *Verify:* the two attribute
    files in claim 8.

## WHAT I COULD NOT VERIFY

- **That `ComputeAsync` costs the main thread nothing at all.** The bound this instrument can put on
  it is the one in claim 3 (in-release frames are not fatter than others). Only the MicroProfiler
  can answer it directly and it has no scripting API. Said in the research note's last section and
  in MEASUREMENTS section 2.
- **Whether the 0.2-0.7 s a released group spends standing still before its line starts walking is
  visible.** It is a consequence of spawning the bodies before the route is known. Nobody has looked
  at it; it is a question for Karen (MEASUREMENTS section 5 item 4, `ESCALATE.md`).
- **349's first sighting and median gap from stand 4.** N/A rather than measured: no behaviour code
  was touched, so re-running 349's drive pair would measure the same build twice.
- **A flake fired on the first harness attempt and I did not capture the server half by name.**
  `semiauto_client.spec:93` fired (it is on the dispatch's known-flake list) alongside one unnamed
  server failure; the very next run was `2975 passed, 0 failed` on the server and `704 passed,
  0 failed` on the client, and the evidence run above is 34/34 clean. The miss is mine: I re-ran
  before saving the first run's output.

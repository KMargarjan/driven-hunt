# Task 356 -- the half-second stall when a wave releases

Task: 356
Round: 2
Base: fc2f99ba10de470ced7282dea1b44cc50f1a8ec8 (`main`)
Code commit: 10584da8a2e0f011bd371da4e6d69ce3cc645315

```
[harness] PASS: 34/34 checks @ 10584da8a2e0f011bd371da4e6d69ce3cc645315 (clean tree) scope=all
```

`test2` is **N/A**: nothing in `TWO_PLAYER_PATHS` is touched (`src/server/ForestTest/`,
`src/server/ForestTestBoot.server.luau`, `tests/server/forest_placement.spec.luau`, `docs/`,
`backups/` -- no `Match/`, no `Drive/`, no client role spec).

## WHAT CHANGED SINCE ROUND 1

**Round 1's blocking finding was right and is fixed.** All three cases did pass with every
measurement producer deleted; they asserted format literals and the rollup's own argument.

**No behaviour changed, in either round.** Not one line that decides what a drive does was touched:
no animal, no slot, no route, no position, no release time. The diff is an instrument, its spec, a
research note, a control archived under `backups/`, and the measurements.

**The fix the dispatch asked for was still not written, because its premise is false.**
`ESCALATE.md` (2026-11-13) is the entry. `releaseLine` really does take 570-845 ms of WALL time per
wave, 97.9-98.2 % of it `path:ComputeAsync` -- but `ComputeAsync` **yields**, the call spans
**24-44 Heartbeats**, and a frame during a release is not fatter than any other frame.

## CLAIMS

1. **The spec now fails when the measurement producers are deleted, and it is checked, not argued.**
   Deleting `releaseCount.spawns += 1`, `stepTicks += 1` and all seven
   `releaseProf.<section> = (os.clock() - ...) * 1000` assignments fails
   `forest_placement.spec:1839`, `:1867` and `:1886` -- the exact cases that assert measurements.
   *Verify:* `<runs-dir>/356-delete-fail.txt` (a whole harness run with the producers deleted:
   `FAIL: 32/34`, 115 spec files, only those three cases down); the tree was restored and the run
   above is 34/34.
2. **Those cases assert the world, not the bill's own format.** `expect(field(bill, "spawns"))
   .to.equal(got.made)` compares the bill with the **stub runtime's own handle count**;
   `FRAMES >= 3` is driven by the patched `computeRouteVia` calling `Forest.step` itself -- the
   stand-in for the Heartbeat that fires while `ComputeAsync` is suspended; and the third sums the
   `releaseMax`/`releaseTotal` half and requires it non-zero. *Verify:* the four cases under
   `describe("the release bill (task 356)")`, and the harness's own notes from the run above:
   *"the bill counted 1 spawn(s) against the runtime's 1, and 3 frame(s) across the call"* and
   *"the sections billed 0.300 ms of real work"*.
3. **`path:ComputeAsync` is 748.2 of `releaseLine`'s worst 764.4 ms (97.9 %) AT THE REVIEWED
   COMMIT**, and 732.0 of 745.4 (98.2 %) at `f5f06f93`. *Verify:* MEASUREMENTS sections 1 and 3a;
   `<runs-dir>/R2B-track.txt` and `BEFORE-track.txt`.
4. **The call spans 24 / 27 / 43 / 44 Heartbeats over four drives, so the 570 ms is not a frame.**
   *Verify:* MEASUREMENTS 2(a) and 3a; the `FRAMES=` field of `ServerStorage.DHReleaseBill` in
   `BEF2-`, `BEF3-`, `BEFORE-` and `R2B-track.txt`.
5. **A frame during a release is not fatter than any other: mean 24.2 ms against 24.8 ms elsewhere
   at the reviewed commit** (23.0 / 23.3 at `f5f06f93`), with max 49.3 ms against 1,399.7 ms.
   *Verify:* MEASUREMENTS 2(b) and 3a. Round 2 made this **stricter** on round 1's note: the charge
   is read before AND after `ForestTest.step` and or-ed, so the frames a release starts and resumes
   on no longer fall in `hb-elsewhere`.
6. **That null result has a positive control: a 250 ms spin inside a release read back as
   `hb-in-release max=277.9`** against 46.5 with it off. *Verify:* `<runs-dir>/CTRL-track.txt` vs
   `BEFORE-track.txt`; archived with its code and its reason in
   `backups/2026-11-13_task-356_release-burn-control.md` (rule 7).
7. **The drive's real worst frame is 1,399.7-1,421.7 ms with NO release in flight, and it is the
   lobby's** (`Lobby.step` + `reportLobby`, 1,214.6 ms of it in Lua, at the join).
   *Verify:* MEASUREMENTS 2(b) and 5; `<runs-dir>/BEFORE-track.txt`'s
   `BOOTOWNERS ... lobby=1214.6/1857.0`.
8. **Round 2 found and fixed a bug of its own by re-measuring rather than carrying numbers
   forward.** Making the bill per-drive (`releaseReset` called from `newDrive`) meant a drive that
   ends before the probe reads it wiped its own bill: `calls=0 worst:` with 253 in-release frames.
   *Verify:* `<runs-dir>/R2-track.txt` (the broken run, commit `dbc7dbf0`) against `R2B-track.txt`
   (`88c324a8`); MEASUREMENTS 3a's last paragraph; the comment on `ForestTest.releaseReset`.
9. **Round 1's other notes are answered in code**, each with its reason on the line: `FRAMES` is
   worked out in the rollup so every early return publishes it; `stagedLine` is billed like a slot;
   `clearRoute` no longer counts a cast that `and` short-circuits away; `releaseDepth` is renamed
   `releaseInFlight` (`Data.releaseDepth` is studs); the comment on `releasing()` is its own; and
   `computeRouteVia`'s comment no longer calls `ComputeAsync` synchronous. *Verify:*
   `git diff 72e3f254..10584da8 -- src/`.
10. **Her place was not written to and nothing was left behind, across all six drives.** The one
    attribute this task set (`DHReleaseBurn`) was set at RUNTIME inside a Play session, never in
    Edit; `flags.py --place forest clear` was never run (rule K). Her Forest Test ends on :34873
    from `driven-hunt-karen` (`fc2f99ba`), Edit, connected (`<runs-dir>/356-connect-karen-final.png`,
    looked at). *Verify:* `<runs-dir>/356-attrs-before.txt` vs `356-attrs-final.txt` --
    **24 attributes, identical**, with neither `DHReleaseBurn` nor `DHFlag_BOAR_ATTACH_BUDGET` in
    either.

## WHAT I COULD NOT VERIFY

- **That `ComputeAsync` costs the main thread nothing at all.** The bound this instrument can put on
  it is claim 5. Only the MicroProfiler answers it directly and it has no scripting API (research
  note, last section).
- **Nothing here was seen as a picture or as play** (rule 5). Claims 4 and 5 are the stand-in for
  the dispatch's *"no hitch when a wave releases"*, and they were read off
  `ServerStorage.DHReleaseBill` in a headless Play session. Round 1's note asked for this to be
  said: **items 4 and 5 are NOT PROVEN on screen.** The one frame that was looked at is the Rojo
  panel, for the sync state, not the game.
- **Whether the 0.2-0.7 s a released group stands still before its line walks is visible.** Nobody
  has looked; it is Karen's question (MEASUREMENTS 5 item 4, `ESCALATE.md`).
- **349's first sighting and median gap from stand 4.** N/A rather than measured: no behaviour code
  was touched, so re-running 349's drive pair would measure the same build twice.
- **A cross-caller leak into `releaseProf.path` is bounded by arithmetic, not by a guard.** A repath
  or a woken group inside the ~44-frame window would be billed to the release. The worst call's four
  printed legs sum to `path` exactly and `path <= routes`, which a leak would break -- but nothing
  enforces it. MEASUREMENTS section 4a says so.
- **A flake fired on the first harness attempt of round 1 and I did not capture the server half by
  name** -- `semiauto_client.spec:93` (on the dispatch's known-flake list) plus one unnamed server
  failure; the next run was 0 failed on both sides. The miss is mine: I re-ran before saving the
  output. Round 2's three harness runs (the delete-the-producer run included) showed no flake.

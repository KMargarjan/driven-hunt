# Task 356 -- where `ForestTest.releaseLine`'s 570 ms goes, and whether it is a frame

All readings are from **Karen's own Forest Test**, cell **C1**, **her flags exactly as they are**
(`DHFlag_PLACEMENT_IN_PLACE=false`, `DHFlag_BOAR_ATTACH_BUDGET` absent = OFF, the rest as
`<runs-dir>/356-attrs-before.txt` records), served from `driven-hunt-rev` on :34873, one drive and
one window per row. **Every table below is also re-measured at the REVIEWED commit** -- see section
3a, run `R2B` at `88c324a8` -- so no number here is only true of an instrument that was later
changed. **Nothing was written to her place at all** -- the one attribute this task set
(`DHReleaseBurn`, the control) was set at RUNTIME in the Play session, which is discarded at stop,
never in Edit. `356-attrs-before.txt` vs `356-attrs-after.txt` is **EMPTY**.

---

## 1. THE ANSWER THE DISPATCH ASKED FOR: what spends the 570 ms

`ForestTest.releaseLine` is billed into nine named sections (`src/server/ForestTest/init.luau`,
`releaseProf` / `ForestTest.releaseBill`), published on `ServerStorage.DHReleaseBill`. The worst
call of a 340 s C1 drive, at `f5f06f93` (`<runs-dir>/BEFORE-track.txt`):

| section | symbol it covers | worst CALL | worst over the drive | total over the drive |
|---|---|---|---|---|
| **`routes`** | **`routeFilesFor` -> `ForestTest.computeRouteVia`** | **733.0 ms** | **733.0 ms** | **9,007.9 ms** |
| of which **`path`** | **`path:ComputeAsync`** (`PathfindingService`) | **732.0 ms** | **732.0 ms** | **8,987.8 ms** |
| of which `clear` | `ForestTest.clearRoute`, 127 `Blockcast`s | 0.7 ms | 1.0 ms | 13.5 ms |
| `spawn` | the spawn loop: `Data.groundAt` + `Runtime:spawn` | 11.5 ms | **23.2 ms** | 253.1 ms |
| `frame` | `wavePoint`, `lineNorthAt`, `releaseDepth`, `releaseFrame` | 0.7 ms | 0.7 ms | 5.3 ms |
| `prep` | `settleAim`, `waveAt`, `rosterSlot`, the schedule | 0.1 ms | 0.1 ms | 0.6 ms |
| `comp` | the composition, the live budget, the cap | 0.0 ms | 0.1 ms | 0.7 ms |
| `order` | `Line.order`, `Line.split`, `sounderKinds` | 0.0 ms | 0.0 ms | 0.7 ms |
| `files` | `seedTrail`, `formSounder`, the `state.lines` rows | 0.1 ms | 0.2 ms | 2.1 ms |
| | **call total** | **745.4 ms** | | 9,270.8 ms |

**`Path:ComputeAsync` is 732.0 of the 745.4 ms -- 98.2 %.** Everything this file's own Lua does,
all nine sections but `path`, comes to **13.4 ms**. The per-leg rows of that same worst call:

```
[399ms Success 146studs +23f]  [166ms Success 349studs +10f]  [68ms Success 146studs +4f]  [99ms Success 349studs +6f]
```

Four legs (a `SPLIT` row: two files x start->crossing, crossing->exit). Three other drives at the
same code: `legs=2 path=562.8` (`BEF356`), `legs=2 path=578.3` (`BEF2`), `legs=4 path=648.5`
(`BEF3`). **A single `ComputeAsync` costs 68-399 ms in this world, and a probe
(`<runs-dir>/356-path-A.txt`) put a floor under it: an immediately-unreachable search still costs
90.6 ms, and a 40-stud one 101.6 ms.** The cost is not the route's length; it is per call.

---

## 2. AND IT IS NOT A FRAME. The dispatch's premise is REFUTED.

> *"takes 569.3 / 567.5 / 845.7 ms in ONE frame each time a slot fires ... That is a half-second
> server freeze every wave."*

`Path:ComputeAsync` is documented as **a yielding function**
(<https://create.roblox.com/docs/reference/engine/classes/Path#ComputeAsync>). An `os.clock()` bite
across a yield measures **wall time**, which is working plus waiting -- the error class Brendan
Gregg's off-CPU analysis is about (research note,
`docs/research/2026-11-13-yielding-work-is-not-a-frame.md`). Two instruments settle it:

**(a) How many frames the call spanned.** `ForestTest.step` runs exactly once per Heartbeat, so its
entries between `releaseLine`'s entry and exit count the frames. A real stall reads `FRAMES=0`.

| drive | worst `releaseLine` | **FRAMES it spanned** |
|---|---|---|
| `BEF2` | 595.0 ms | **27** |
| `BEF3` | 666.7 ms | **24** |
| `BEFORE` | 745.4 ms | **43** |

745.4 ms over 43 frames is 17.3 ms a frame, which is the drive's ordinary frame.

**(b) The frame itself, charged to "a release is in flight" or not.** `Heartbeat`'s `deltaTimeSec`
is the only number in Lua's reach that includes the **engine's** work -- physics, replication,
pathfinding -- so no `os.clock()` bite could see it. `ForestTestBoot` charges every frame to one
side (`ForestTest.releasing()`, a depth, because the yield lets a later Heartbeat enter `step`
while an earlier release is still suspended):

| `BEFORE` run, C1, her flags | max | **mean** | frames |
|---|---|---|---|
| **while a wave release is in flight** | **46.5 ms** | **23.0 ms** | 373 |
| everywhere else in the same drive | **1,421.7 ms** | **23.3 ms** | 14,507 |

**WHAT THE IN-RELEASE COLUMN ACTUALLY HOLDS, said exactly (round 2's finding, option (b)).** The
charge reads the depth **once**, at the top of the Heartbeat, so `hb-in-release` is the frames a
release is **suspended through** -- the purely-yielding ones, where `ComputeAsync` has the handler
thread parked and the frame carries no release Lua at all. Two frames per release are **not** in it,
and both are in `hb-elsewhere`: (i) the frame the release **starts** on -- the depth was 0 when that
frame's charge was read -- and (ii) the frame whose `dt` covers the **resumed** `order` / `spawn` /
`files` Lua, because `Heartbeat`'s `dt` is *"the time elapsed since the previous frame"* and so the
frame that reports it is the one **after** the release finished, by when the depth is 0 again.
Round 2 tried to close that with a second, or-ed read and it was a **no-op**: the only writers of the
depth are inside `ForestTest.step`, so in the thread that carries the release both reads are false
(`reviews/task-356/RESULT.md` round 2, finding 1). Round 3 deleted the dead read rather than
pretending it worked. **So the leg this table carries is bounded:** no frame on which a release is
merely waiting is long. The resumed-Lua frame is bounded instead by section 1's arithmetic --
`order` + `spawn` + `files`, worst `spawn` 23.2 ms -- and by `heartbeat max`, and an in-release frame
is invisible in the `elsewhere` column's max because the 1,399.7 ms lobby join frame is in it.

**The two counters run for the whole Play SESSION, not only the 340 s drive** -- which is what lets
the join's own frame appear in the `elsewhere` column at all, and is why that column holds 14,507
frames. Both columns are over the same session, so the comparison between them is a fair one.

**A frame during a wave release is, on average, 0.3 ms FASTER than a frame that is not.** The worst
frame of the whole drive, 1,421.7 ms, happens with **no release in flight**: the same drive's boot
bill names it -- `lobby=1214.6` worst of a 1214.79 ms step, `Lobby.step` + `reportLobby` at the
join, which is task 355's spike #2 (it measured 378.4 ms; this drive saw 1,214.6).

**(c) The positive control, because (b) is a NULL result.** A channel that reports "nothing long
happened" is worthless unless it would have reported something long. A Studio-only spin of 250 ms
was injected into in-release frames (`<runs-dir>/CTRL-track.txt`; archived,
`backups/2026-11-13_task-356_release-burn-control.md`):

| same instrument, same place, same cell | burn OFF (`BEFORE`) | **burn = 250 ms (`CTRL`)** |
|---|---|---|
| `hb-in-release` max | 46.5 ms | **277.9 ms** |
| `hb-in-release` mean | 23.0 ms over 373 frames | **188.7 ms** over 37 frames |
| `hb-elsewhere` max | 1,421.7 ms | 1,497.1 ms |
| `hb-elsewhere` mean | 23.3 ms over 14,507 | 22.6 ms over 9,563 |

The channel reads a 250 ms stall back as 277.9 ms max / 188.7 ms mean. It is not blind. With the
burn off it reads 46.5 / 23.0. **There is no half-second freeze to remove.**

---

## 3. BEFORE | AFTER, against the dispatch's three targets

No fix was written, so there is no AFTER column: the BEFORE column already meets the two targets
that are this function's, and the one it misses is not its. This is said as a table rather than as
a paragraph because the dispatch asked for one.

| | measured (`BEFORE`, `f5f06f93`) | target | verdict |
|---|---|---|---|
| `releaseLine` **worst frame** | **DERIVED, not read: no instrument here produces a per-frame Lua figure.** `order` + `spawn` + `files` land together on the frame the call resumes on, so the implied worst in-release Lua frame is **>= 23.2 ms** (`spawn`'s own worst over the drive); every other section is <= 1.5 ms. The number actually READ for a frame is `hb-in-release max`, **46.5 / 49.3 ms**, which is the WHOLE frame and not this file's share | <= 16 ms | **MET for the eight sections that are this file's own arithmetic.** `spawn` is 23.2 ms worst -- and it is `Boar.Runtime:spawn`, 4.3-6.1 ms an animal (task 355), not this file's arithmetic. See *next owner* |
| **server step peak during a drive** | `StepMsMax` **88.2 / 101.9 / 80.97** ms over three drives | <= 40 ms with `BOAR_ATTACH_BUDGET` as in her place | **NOT MET, and not this task's.** That is the BOAR runtime's step and task 355 already measured it (104.2 ms), fixed it (26.1 ms) and shipped the fix behind `BOAR_ATTACH_BUDGET`, which is **OFF in her place by the Director's instruction** ("leave it"). Turning it on is the fix; nothing in `releaseLine` moves it |
| **heartbeat p95** | **29.10 ms** (`BEFORE`), 32.06 (`BEF2`), 33.02 (`BEF356`) | reported | **REPORTED.** Unchanged from task 355's 30.8-34.0 |
| peak live / peak parts | 33 / 561 (`BEFORE`), 59 / 1,003 (`BEF2`), 60 / 1,020 (`BEF356`) | -- | the three drives released different patterns (`DRIVE_VARIETY` is on in her place) |
| releases per drive | 26 calls, 24 of them putting animals down | -- | `<runs-dir>/BEFORE-console.txt` |

### 3a. THE SAME DRIVE AT THE REVIEWED COMMIT (`R2B`, `88c324a8`)

Round 2 changed the instrument (round 1's notes), so the claim was re-measured rather than carried
over. **One of those changes was a no-op and round 3 removed it:** the or-ed second read of the depth
cannot see a release's own frames (2(b) above, and `RESULT.md` round 2 finding 1), so this table's
`hb-in-release` row is the **purely-yielding** frames, exactly as the `BEFORE` column's is -- the
same instrument on both sides. The release's start frame and the frame whose `dt` covers its resumed
Lua are in the `hb-elsewhere` row of both columns. The row that was re-measured and the row it is
compared against are therefore like for like, which is all the comparison needs.

| | `BEFORE` (`f5f06f93`) | **`R2B` (`88c324a8`, reviewed)** |
|---|---|---|
| worst `releaseLine` | 745.4 ms | **764.4 ms** |
| of which `path:ComputeAsync` | 732.0 ms (98.2 %) | **748.2 ms (97.9 %)** |
| **FRAMES it spanned** | 43 | **44** |
| its four legs | 399+166+68+99 ms, +23/+10/+4/+6 frames | **356+214+78+100 (= 748.2) and 20+13+5+6 (= 44)** |
| `hb-in-release` max / mean / frames | 46.5 / 23.0 / 373 | **49.3 / 24.2 / 254** |
| `hb-elsewhere` max / mean / frames | 1,421.7 / 23.3 / 14,507 | **1,399.7 / 24.8 / 13,666** |
| heartbeat p95 / max | 29.10 / 116.04 ms | **31.79 / 386.68 ms** |
| peak live / parts | 33 / 561 | **60 / 1,020** |
| boar `StepMsMax` | 80.97 ms | **82.36 ms** |

**The in-release mean is still BELOW the elsewhere mean (24.2 against 24.8) under the stricter
charge, and the worst in-release frame is still 28x smaller than the worst frame elsewhere.** The
finding does not depend on which commit it was read at.

**One bug this re-measurement caught, and it was mine.** Round 2 first made the bill per-drive by
calling `releaseReset` from `ForestTest.newDrive`. A drive that ends before the probe reads it then
wiped its own bill: run `R2` at `dbc7dbf0` printed `calls=0 worst:` with 253 in-release frames on
the same run (`<runs-dir>/R2-track.txt`). The bill is per SESSION, like `DHBoot*`; `releaseReset`
stays as a window a caller opens deliberately, and `newDrive` does not call it. Had I carried round
1's numbers forward instead of re-running, that would have shipped silently.

**349's instrument, stand 4 (must not get worse): N/A, nothing changed.** No line of behaviour code
was touched -- the diff is an instrument and a comment -- so the first sighting and the median gap
from stand 4 cannot have moved. Re-running 349's drive pair would measure the same build twice.

---

## 4. What the instrument itself costs, said rather than left out

It is permanent and unflagged, so every number above carries it. Per **frame**: one
`ForestTest.releasing()` call before `ForestTest.step` and one after, plus two adds, in
`ForestTestBoot`'s Heartbeat. Per **release** (26 a drive): ~26 `os.clock()` calls for the worst
call -- 14 in `releaseLine`, 2 per pathfinder leg, 2 per `clearRoute` -- one `table.clear`, one `string.format` of nine numbers, and one
small string per pathfinder leg. `os.clock` is a C call of tens of nanoseconds. The boot's own
average step is **1.21 ms** with the instrument in (`BEFORE`), against 1.10 ms in `BEF2`, which is
inside the run-to-run spread of two drives that released different patterns -- so the charge is not
separately resolvable and this task does not claim it was measured.

---

## 4a. One bound this instrument does not enforce

`releaseProf.path`, `releaseProf.clear` and `releaseCount.legs` accumulate from **every** caller of
`computeRouteVia` / `clearRoute`, and because a release yields for ~44 frames, a stuck-leader repath
(`stepLines`) or a woken group (`orderGroup`) falling in that window would be billed to it. Nothing
in the code prevents it. What says it did not happen on these runs is arithmetic inside the
published line itself: the worst call's four printed legs sum to `path` exactly (356+214+78+100 =
748.2 against `path=748.2`), `legs=4` matches the four rows, and `path <= routes` (748.2 <= 749.0).
A leak would break all three at once. It is checked by reading, not by a guard, and that is said
rather than implied.

## 5. WHAT IS REAL, AND WHOSE IT IS NEXT

1. **The drive's worst frame is 1,421.7 ms, at the join, and it is the LOBBY's** --
   `Lobby.step` + `reportLobby` in one bucket, 1,214.6 ms of it in Lua
   (`src/server/Lobby/init.luau`). Task 355 named it spike #2 at 378.4 ms and left it because it
   is "at the join, before any drive". It is 3.2x bigger than 355 saw and it is the largest single
   stall the server actually takes. **It is the next owner, and it is a real one.**
2. **The boar runtime's step peak is 80-102 ms** and task 355's fix for it is written, reviewed,
   merged and **switched off in her place**. Nobody has looked at a drive with it on
   (355's own "Needs Karen"). Turning it on is cheaper than any new work.
3. **`Runtime:spawn` is 23.2 ms worst in one frame** (nine animals at once). Real, small, and the
   Boar owner's. It is the only thing inside `releaseLine` above the dispatch's 16 ms bar, and it
   would be sliced the way 355 sliced `attachVisual` -- at the price of a group appearing over
   several frames, which is a look question for Karen and not a performance one.
4. **`Path:ComputeAsync` costs 8,988 ms of wall time per drive and ~90 ms minimum per call.** It
   does not cost frames, so it is not a stall -- but it *is* why a released group stands still for
   ~0.2-0.7 s before its line starts walking, because the bodies are spawned before the route is
   known. **That is a question about how the drive LOOKS, and it is Karen's**, not a server-cost
   question. Nothing in this task measured whether it is visible.

## 6. ROUND 3: the depth cannot be poisoned, measured by removing the guard

`releaseInFlight -= 1` sits after `ForestTest.releaseLine` in the drive's own **un-pcalled**
Heartbeat, so a raise inside the release used to leave the depth at >= 1 -- and then every remaining
frame of the session is charged in-release and 2(b) means nothing. Round 3 wraps the call in a
`pcall` and re-raises the error unchanged (`ForestTest.step` and `ForestTest.stagedLine`).

**FAIL FIRST, measured, not argued.** With the `pcall` in `ForestTest.step` replaced by the plain
call and nothing else changed, the suite was run (`<runs-dir>/356r3-failfirst.txt`):

```
[tests:server] FAIL: 2976 passed, 1 failed, 0 skipped, 1 errors, 83 spec files
TestService: ... Expected value "false" (boolean), got "true" (boolean) instead
ServerStorage.Tests.forest_placement.spec:1931
[harness] FAIL: 32/34 checks @ e893d08a (DIRTY TREE (3 paths) - NOT valid evidence) scope=all
```

Line 1931 of that tree is `expect(Forest.releasing()).to.equal(false)` in
`it("brings the depth back down when the release RAISES")` -- the depth stuck at 1 after the raise.
Exactly one case failed, and no other spec moved -- so this is the case's own bite and not a
side-effect. With the guard restored the full clean run passes; its line is `REQUEST.md`'s.

## 7. ROUND 3: one case was reading the bill's FORMAT FLOOR, and that is fixed

`it("times the sections it really ran")` sums the bill's `max/total` pairs and asserts the sum is
> 0. The bill prints `%.1f`, and with `computeRouteVia` stubbed out every section of a spec release
is **under 0.05 ms**, so each pair can print `0.0` and the sum reads 0. Measured, both at the same
tree: `356r3-failfirst.txt` read **0.400 ms** and passed; `356r3-harness1.txt`, five minutes later at
`055cbaf7`, read 0 and **failed** (`forest_placement.spec:1872`, `Expected true, got false`). Nothing
about the release changed between them -- the case was reading rounding noise, which is a flaky
assertion and not a defect in the instrument it guards.

**The fix is REAL WORK, not a loosened assertion:** the spec's own `computeRouteVia` patch now burns
1 ms of `os.clock` before it returns, so `releaseProf.routes` is a measured millisecond and the
printed pair cannot round to 0.0. The timer that reads it is the one under test, so the case still
dies if the nine `releaseProf.<section> = (os.clock() - sectionAt) * 1000` assignments are deleted --
its FAIL FIRST claim is unchanged. The spin count is printed in the case's own harness note.

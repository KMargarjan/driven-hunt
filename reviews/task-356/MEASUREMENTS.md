# Task 356 -- where `ForestTest.releaseLine`'s 570 ms goes, and whether it is a frame

All readings are from **Karen's own Forest Test**, cell **C1**, **her flags exactly as they are**
(`DHFlag_PLACEMENT_IN_PLACE=false`, `DHFlag_BOAR_ATTACH_BUDGET` absent = OFF, the rest as
`<runs-dir>/356-attrs-before.txt` records), served from `driven-hunt-rev` on :34873, one drive and
one window per row. **Nothing was written to her place at all** -- the one attribute this task set
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

| `BEFORE` drive, 340 s, C1, her flags | max | **mean** | frames |
|---|---|---|---|
| **while a wave release is in flight** | **46.5 ms** | **23.0 ms** | 373 |
| everywhere else in the same drive | **1,421.7 ms** | **23.3 ms** | 14,507 |

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
| `releaseLine` **worst frame** | **1.5 ms** of Lua in the worst frame of the worst call, and `23.2 ms` worst over the drive for the one section that cannot yield (`spawn`) | <= 16 ms | **MET for eight of nine sections.** `spawn` is 23.2 ms worst -- and it is `Boar.Runtime:spawn`, 4.3-6.1 ms an animal (task 355), not this file's arithmetic. See *next owner* |
| **server step peak during a drive** | `StepMsMax` **88.2 / 101.9 / 80.97** ms over three drives | <= 40 ms with `BOAR_ATTACH_BUDGET` as in her place | **NOT MET, and not this task's.** That is the BOAR runtime's step and task 355 already measured it (104.2 ms), fixed it (26.1 ms) and shipped the fix behind `BOAR_ATTACH_BUDGET`, which is **OFF in her place by the Director's instruction** ("leave it"). Turning it on is the fix; nothing in `releaseLine` moves it |
| **heartbeat p95** | **29.10 ms** (`BEFORE`), 32.06 (`BEF2`), 33.02 (`BEF356`) | reported | **REPORTED.** Unchanged from task 355's 30.8-34.0 |
| peak live / peak parts | 33 / 561 (`BEFORE`), 59 / 1,003 (`BEF2`), 60 / 1,020 (`BEF356`) | -- | the three drives released different patterns (`DRIVE_VARIETY` is on in her place) |
| releases per drive | 26 calls, 24 of them putting animals down | -- | `<runs-dir>/BEFORE-console.txt` |

**349's instrument, stand 4 (must not get worse): N/A, nothing changed.** No line of behaviour code
was touched -- the diff is an instrument and a comment -- so the first sighting and the median gap
from stand 4 cannot have moved. Re-running 349's drive pair would measure the same build twice.

---

## 4. What the instrument itself costs, said rather than left out

It is permanent and unflagged, so every number above carries it. Per **frame**: one
`ForestTest.releasing()` call and two adds in `ForestTestBoot`'s Heartbeat. Per **release** (26 a
drive): ~20 `os.clock()` calls, one `table.clear`, one `string.format` of nine numbers, and one
small string per pathfinder leg. `os.clock` is a C call of tens of nanoseconds. The boot's own
average step is **1.21 ms** with the instrument in (`BEFORE`), against 1.10 ms in `BEF2`, which is
inside the run-to-run spread of two drives that released different patterns -- so the charge is not
separately resolvable and this task does not claim it was measured.

---

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

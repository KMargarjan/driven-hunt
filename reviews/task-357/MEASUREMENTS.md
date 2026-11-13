# Task 357 -- where the lobby's 1,214 ms at the join goes, and whether it is a frame

Every reading below is from **Karen's own Forest Test**, cell **C1**, **her flags exactly as they
are** (`<runs-dir>/357-attrs-before.txt`, 24 rows, `DHFlag_PLACEMENT_IN_PLACE=false`,
`DHFlag_BOAR_ATTACH_BUDGET` absent = OFF), served from `driven-hunt-rev` on :34873, one Play join per
row. **Nothing was written to her place**: the control's two attributes were set at RUNTIME inside a
Play session, which is discarded at stop, and `357-attrs-before.txt` vs `357-attrs-after.txt` is
**EMPTY** (24 identical rows; the only differing line is the harness's own "1 Studio connected" /
"2 Studios connected" banner).

---

## 1. THE ANSWER: THE DISPATCH'S PREMISE IS REFUTED. It is not one frame.

> *"task 356 ... found the drive's real worst server frame is 1,399.7-1,421.7 ms at the player's
> join ... the boot bill names it: lobby=1214.6 ms of a 1214.79 ms step, Lobby.step + reportLobby in
> one bucket."*

The bucket is `os.clock()` across `Lobby.step`, and `Lobby.step` calls `world.place`, which is
`Match.Body.place`, which calls **`player:LoadCharacter()` -- a yielding function**
(<https://create.roblox.com/docs/reference/engine/classes/Player#LoadCharacter>). The file's own
comment at that call site has said so since task 182: *"THROTTLED, because `Body.place` yields on
`LoadCharacter`"*. An `os.clock()` bite across a yield measures **wall** time (task 356's lesson,
`docs/research/2026-11-13-yielding-work-is-not-a-frame.md`).

`ServerStorage.DHLobbyBill`, run `R2` (`<runs-dir>/R2-bill.txt`), **pasted verbatim, nothing cut**:

```
step max=410.8 frames=14 report max=0.7 frames=0 | scan worst=410.8 frames=14 | ground=0.0/0f/1c build=82.6/0f/1c@step1 place=328.0/14f/1c@step1 rest=0.2 | hbmax=1666.5 at step=15 | prev frame's lobby step=0.0/0f report=0.0/0f | top3 1666.5@15(lua ?) 890.9@17(lua 0.1) 149.5@932(lua 0.9)
```

It was read at `84b213c3`, and the code commit is `4f3a0da2`: the two differ **only** by
`reviews/task-357/RESULT.md`, so no line of `src/` moved between the reading and the commit.

| bite | the symbol it covers | **ms** | **FRAMES it spanned** | calls |
|---|---|---|---|---|
| `ground` | `world.groundAt` (`ForestTest.Data.groundAt`), before `stats.buildMs` starts | **0.0** | **0** | 1 |
| **`build`** | **the whole of `Lobby.tryBuild` -- `Field.fill` plus `Build.build`** | **82.6** | **0** | 1 |
| **`place`** | **`world.place` -- `Match.Body.place` -- `player:LoadCharacter()`** | **328.0** | **14** | 1 |
| `rest` | `occupancy`, `stepPads`, `stepNextDrive`, the `stepPlayer` loop, the keeper | **0.2** | -- | -- |
| | **the whole scan** | **410.8** | **14** | |
| `reportLobby` | the six `print`s, billed apart (`report max`) | **0.7** | **0** | -- |

**The lobby's entire one-frame cost at the join is the 82.6 ms build.** The other 328.0 ms is
`LoadCharacter` waiting, spread over 14 frames (23.4 ms a frame, which is this server's ordinary
frame).

**What that 82.6 ms is and is not corroborated by** (review round 1, finding 1 -- the first draft of
this file claimed a cross-check that could not disagree). `stats.buildMs`, which the console prints
as `[lobby] built in 83 ms`, is **the same bracket off the same `began`**, two lines apart in
`tryBuild`: one reading printed twice, not two instruments. **The milliseconds have one source.**
What *is* corroborated, by a different mechanism rather than a second clock, is the part this task
turns on -- `frames=0` comes from `bootSteps`, an integer the Heartbeat increments, with no
`os.clock` in it at all. And `ForestTestBoot` brackets `Lobby.step` from outside (`step max=410.8`)
while `Lobby.step` brackets itself from inside (`scan worst=410.8`): nested spans off the same clock,
so a consistency check rather than an instrument, and it bounds the call-plus-throttle overhead at
under 0.1 ms.

**On the bill adding up:** `rest` is *computed* as `ms - ground - build - place`, so the sum is a
tautology and proves nothing. What says nothing is hiding in an unbitten gap is that **`rest` reads
0.2 ms** -- the occupancy pass, the pads, the next-drive party, the per-player loop and the keeper
together.

Five joins, same place, same flags:

| run | commit | scan worst | frames | `build` ms/frames | `place` ms/frames | console `built in` |
|---|---|---|---|---|---|---|
| `BEFORE` | `211cdc18` | 378.3 | **13** | (bill re-entered, section 4) | 303.1 / **13** | 75 ms |
| `BEF2` | `a22b726b` | 439.1 | **17** | (bill re-entered, section 4) | 356.7 / **17** | 82 ms |
| `BEF3` | `8276a2b7` | 429.2 | **11** | **67.9 / 0** | 361.1 / **11** | 68 ms |
| `CODEC` | `fdc04963` | 386.5 | **14** | **69.1 / 0** | 317.1 / **14** | 69 ms |
| **`R2`** | **`84b213c3`** | **410.8** | **14** | **82.6 / 0** | **328.0 / 14** | **83 ms** |

**There is no 1.2-1.4 s frame in `Lobby.step` + `reportLobby` to remove.** Per the dispatch's own
instruction -- *"If the 1.2-1.4 s is NOT in one frame, write that in MEASUREMENTS and ESCALATE.md and
stop: no fix for a stall that does not exist"* -- no fix was written.

---

## 2. THERE **IS** A REAL 1.6 s FRAME, AND IT IS NOT THIS GAME'S LUA

`Heartbeat`'s `dt` is the only number in Lua's reach that includes the engine's own work, and it
does report long frames at a join. The three worst of the 5,520-frame `R2` session, each with what
`ForestTestBoot`'s whole handler cost on the frame before it (`dt` looks **backward**, so that is
the handler whose work it covers):

| rank | frame `dt` | at step | the boot handler's own Lua on the frame before |
|---|---|---|---|
| 1 | **1,666.5 ms** | **15** | **`?` -- unknowable** |
| 2 | **890.9 ms** | **17** | **0.1 ms** |
| 3 | **149.5 ms** | **932** | **0.9 ms** |

**`?` is the honest answer and it is review round 1's finding 2.** The handler that calls
`world.place` is entered on step 1 and does not return until step 15, so for a frame whose
predecessor never completed there is no handler cost to report; the first draft published the
counter's initial `0` there as though it were a reading. `lastTookStep` now says which frame the
number belongs to, and anything else prints `?`.

What the table still carries is the finding: **ranks 2 and 3 are known, and they are 0.1 and
0.9 ms of Lua against 890.9 and 149.5 ms of frame.** The long frames at steps 15 and 17 are the
first fraction of a second of the server's life, while the place and the first character load; the
third-worst frame of a whole 150-second session is 149.5 ms. Across the five runs the opening pair
reads `1607.2@14 / 1591.4@18 / 1539.6@12 / 1545.7@15 / 1666.5@15`, and the third-worst reads
`162.2@16 / 99.7@2 / 104.0@2 / 149.5@932` -- **so outside the server's first ~20 frames, nothing in
a 150-second session comes near a second.**

**So what task 356 saw as "1,399.7-1,421.7 ms at the join" is real, and it is the place loading --
not `Lobby.step`, not `reportLobby`, and not anything a Lua fix in this repository can move.** The
two numbers were a similar size and they are not the same thing.

---

## 3. THE TARGETS THE DISPATCH SET

| | measured (`R2`) | target | verdict |
|---|---|---|---|
| the lobby's **one-frame** cost at the join | **82.6 ms** (`build`, 0 frames), with `rest` 0.2 and `report` 0.7 / 0 frames | <= 100 ms | **MET, with no change to the game** (67.9-82.6 ms over the four runs whose bill is sound) |
| **the join's worst server frame** | **1,666.5 ms at step 15**, boot Lua on the frame before it unknowable; rank 2 **890.9 ms at step 17 with 0.1 ms of Lua**; **third-worst of the whole session 149.5 ms** | <= 100 ms | **NOT MET, and NOT this owner's** -- it is the engine loading the place and the first avatar. See `ESCALATE.md` |
| **heartbeat max, reported** | **1,666.5 ms** (`hbmax`), and **under 149.5 ms for every frame outside the opening cluster** | reported | **REPORTED** |
| `smoke.sh` gun-in-hand time BEFORE / AFTER | **N/A -- no behaviour changed.** The diff is an instrument, a research note, three spec cases and an archived control; no line of the lobby's build, pads, shop, range or gun was touched, so there is no AFTER to compare | unchanged +-1 s | **N/A, by reason** |
| lobby bite table BEFORE / AFTER | **BEFORE only**, section 1 | both | **BEFORE only, because no fix shipped** |

---

## 4. THE INSTRUMENT'S OWN BUG, FOUND IN HER PLACE AND FIXED BEFORE ANY CLAIM WAS MADE

Runs `BEFORE` and `BEF2` reported `build=0.0/0f/0c` on the worst scan while the console said the
build took 75 / 82 ms. **The bill was being wiped by the scan re-entering itself**: `world.place`
yields for 11-17 frames and `lastScan` is only `1/SCAN_HZ` = 100 ms behind, so a Heartbeat seven
frames in enters `Lobby.step` again while the first call is suspended, and its reset cleared the
suspended call's bites. The arithmetic showed it before the fix did: `439.1 - 356.7 = 82.5` against
`[lobby] built in 82 ms` -- the build's milliseconds were in `rest`.

The bill is now taken for the **outermost** scan only, behind a depth with the shape and the `pcall`
that `ForestTest.releaseInFlight` was given in task 356 round 3 (a raise that left the depth
standing would silence the bill for the rest of the session). `BEF3`, `CODEC` and `R2` are the runs
after the fix, and they are the ones section 1 quotes.

**FAIL FIRST, measured.** With the depth guard deleted and nothing else changed:

```
[tests:server] FAIL: 2979 passed, 1 failed, 0 skipped, 1 errors, 83 spec files
ServerStorage.Tests.lobby_live.spec:415
[harness] FAIL: 31/34 checks @ 8276a2b7 (DIRTY TREE (4 paths) - NOT valid evidence) scope=all
```

Line 415 is the `build=...@step...` assertion in *"keeps the outer scan's bites when the yield lets
a second scan in"* -- the case that drives the re-entry by hand instead of by timing.
`<runs-dir>/357-failfirst.txt`.

**A second thing that run caught, and it was mine.** The first attempt at the fail-first run failed
*two* lobby cases, and one of them was the spec's own fault: the bill keeps the **worst** scan, the
build scan is 68 ms, and a fake `place` that spun a fixed 2 ms never outranked it -- so the case was
asserting against the build scan's bill. The fake now spins `buildMs + 20`. Had that been read as
"the producer is load-bearing in two places", it would have shipped a spec that proves nothing.

---

## 5. THE POSITIVE CONTROL, because this is a NULL result

A channel that reports *"nothing long happened"* is worthless unless it would have reported
something long (task 356's lesson, L-141). Two Studio-only knobs at `ForestTestBoot`'s `place` seam,
set at runtime, measured, then removed and archived
(`backups/2026-11-13_task-357_lobby-place-control.md`):

| input at the `place` seam | `place` ms | **`place` FRAMES** | the Heartbeat channel's top 3 |
|---|---|---|---|
| **none** (`BEF3`) | 361.1 | **11** | 1539.6@12 / 911.5@14 / **162.2@16** |
| **a SPIN of 800 ms** (`CTRLBURN`) | **1034.4** | **7** | 1483.3@12 / 931.2@14 / **811.4@502** |
| **a WAIT of 800 ms** (`CTRLWAIT`) | **1125.2** | **37** | 1414.0@12 / 900.7@14 / **99.7@2** |

**A spin raises the milliseconds and does not raise the frame count, and it puts a new long frame
into the Heartbeat channel. A wait raises both the milliseconds and the frame count, and puts no
long frame there at all.** 20,870,172 spins were counted in the burn arm and `DHLobbyBurnSpins` read
`nil` in the wait arm, so each arm ran only its own knob. Both channels are awake, and they
disagree in exactly the way that tells a stall from a wait. With both off, `place` reads
`317-361 ms over 11-14 frames` and no long frame appears outside the opening cluster -- which is the
finding.

---

## 6. WHAT THE INSTRUMENT COSTS, said rather than left out

It is permanent and unflagged, so every number above carries it. Per **frame**: one integer
increment and four assignments at the top of the boot's Heartbeat, one depth increment, one `pcall`,
three table reads and two comparisons in `Lobby.step` past the throttle -- and on a frame the lobby
is throttled out of (9 of every 10), nothing in the bill at all, because the guard is before it. Per
**scan**: three `os.clock()` pairs and three `world.frames()` calls. Per 120 frames: two
`string.format`s and one `SetAttribute`, the cadence `DHBootWorst` already uses. `DHBootStep avg`
read 1.03-1.54 ms across the five runs, against 1.19-1.22 in task 356's runs of the same place; the
spread between runs is larger than anything this could add, so **no claim is made that the
instrument's own cost was measured**.

---

## 7. ROUND 2: the four findings, all four right

1. **The "independent cross-check" was empty** -- `stats.buildMs` and `profMs.build` read the same
   `began`. Struck here, in `ESCALATE.md`, in the research note and in `docs/research/INDEX.md`, and
   replaced by what is actually corroborated and by what the consistency check actually bounds
   (section 1).
2. **`lua 0.0` was the counter's initial value, not a reading**, for a frame whose predecessor was
   still suspended -- which is exactly the step-2 row the first draft published. `lastTookStep` now
   says which frame the number belongs to and the bill prints `?` otherwise; the `R2` reading above
   shows `lua ?` on rank 1 (section 2).
3. **`hbWorst`'s "prev frame's lobby" fields were this frame's.** `lobbyStepMs` is reassigned
   earlier in the same handler, including on the throttled frames, so a long frame following the
   build frame would have printed `0.0/0f` and hidden it. The previous frame's four numbers are
   snapshotted at the top of the handler; `R2` prints `prev frame's lobby step=0.0/0f`, which is
   now true (step 14's scan was throttled out) instead of accidentally true.
4. **A segment of the bill was dropped from the paste, and the report's frame count was published
   nowhere.** The line is now pasted verbatim, and `report max=%.1f frames=%d` publishes it.

**The known flake, captured before re-running** (`<runs-dir>/357-flake.txt`). The first gate run at
the code commit `4f3a0da2` failed one assertion, `ServerStorage.Tests.weapon_shot.spec:1890`, which
is named in the dispatch's own flake list and is untouched by this diff (no weapon file is in it).
Re-run at the **same** commit: `[harness] PASS: 34/34 checks @ 4f3a0da2 (clean tree) scope=all`. The
same spec was green at `6106812d` and at `fdc04963` on this branch.

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

`ServerStorage.DHLobbyBill`, at the code commit `fdc04963`, run `CODEC`
(`<runs-dir>/357-CODEC.log`):

```
step max=386.5 frames=14 report max=0.7 | scan worst=386.5 frames=14 |
ground=0.0/0f/1c build=69.1/0f/1c@step1 place=317.1/14f/1c@step1 rest=0.2 |
hbmax=1545.7 at step=15 | top3 1545.7@15(lua 0.1) 827.8@17(lua 0.1) 104.0@2(lua 0.0)
```

| bite | the symbol it covers | **ms** | **FRAMES it spanned** | calls |
|---|---|---|---|---|
| `ground` | `world.groundAt` (`ForestTest.Data.groundAt`), before `stats.buildMs` starts | **0.0** | **0** | 1 |
| **`build`** | **the whole of `Lobby.tryBuild` -- `Field.fill` plus `Build.build`** | **69.1** | **0** | 1 |
| **`place`** | **`world.place` -- `Match.Body.place` -- `player:LoadCharacter()`** | **317.1** | **14** | 1 |
| `rest` | `occupancy`, `stepPads`, `stepNextDrive`, the `stepPlayer` loop, the keeper | **0.2** | -- | -- |
| | **the whole scan** | **386.5** | **14** | |
| `reportLobby` | the six `print`s, billed apart | **0.7** | **0** | 1 |

**The lobby's entire one-frame cost at the join is the 69.1 ms build, and it is already under the
dispatch's 100 ms target.** The other 317.1 ms is `LoadCharacter` waiting, spread over 14 frames
(22.6 ms a frame, which is this server's ordinary frame). The bill adds up exactly:
0.0 + 69.1 + 317.1 + 0.2 = 386.5, and `build` agrees with the console's own independent number,
`[lobby] built in 69 ms`.

Four joins, same place, same flags:

| run | commit | scan worst | frames | `build` ms/frames | `place` ms/frames | console `built in` |
|---|---|---|---|---|---|---|
| `BEFORE` | `211cdc18` | 378.3 | **13** | (bill re-entered, section 4) | 303.1 / **13** | 75 ms |
| `BEF2` | `a22b726b` | 439.1 | **17** | (bill re-entered, section 4) | 356.7 / **17** | 82 ms |
| `BEF3` | `8276a2b7` | 429.2 | **11** | **67.9 / 0** | 361.1 / **11** | 68 ms |
| **`CODEC`** | **`fdc04963`** | **386.5** | **14** | **69.1 / 0** | **317.1 / 14** | **69 ms** |

**There is no 1.2-1.4 s frame in `Lobby.step` + `reportLobby` to remove.** Per the dispatch's own
instruction -- *"If the 1.2-1.4 s is NOT in one frame, write that in MEASUREMENTS and ESCALATE.md and
stop: no fix for a stall that does not exist"* -- no fix was written.

---

## 2. THERE **IS** A REAL 1.5 s FRAME, AND IT IS NOT THIS GAME'S LUA

`Heartbeat`'s `dt` is the only number in Lua's reach that includes the engine's own work, and it
does report long frames at a join. The three worst of the 5,760-frame `CODEC` session, each with
what `ForestTestBoot`'s whole handler cost on the frame before it (`dt` looks **backward**, so that
is the handler whose work it covers):

| rank | frame `dt` | at step | the boot handler's own Lua on the frame before |
|---|---|---|---|
| 1 | **1,545.7 ms** | **15** | **0.1 ms** |
| 2 | **827.8 ms** | **17** | **0.1 ms** |
| 3 | **104.0 ms** | **2** | **0.0 ms** |

**Every frame from step 18 to step 5,760 -- the remaining 149 of the 150 seconds -- is under
104.0 ms.** The three long ones are steps 2, 15 and 17: the first fraction of a second of the
server's life, while the place and the first character load. On each of them this repository's Lua
costs **0.0-0.1 ms**, so 99.99 % of those frames is the engine. `Lobby.step`'s own worst scan starts
on **step 1** and is suspended through them, which is exactly why its wall time looked like their
size. The four runs agree: `1607.2@14`, `1591.4@18`, `1539.6@12`, `1545.7@15`.

**So what task 356 saw as "1,399.7-1,421.7 ms at the join" is real, and it is the place loading --
not `Lobby.step`, not `reportLobby`, and not anything a Lua fix in this repository can move.** The
two numbers were a similar size and they are not the same thing.

---

## 3. THE TARGETS THE DISPATCH SET

| | measured (`CODEC`, `fdc04963`) | target | verdict |
|---|---|---|---|
| the lobby's **one-frame** cost at the join | **69.1 ms** (`build`, 0 frames), with `rest` 0.2 and `report` 0.7 | <= 100 ms | **MET, with no change to the game** |
| **the join's worst server frame** | **1,545.7 ms at step 15**, boot Lua on the frame before it **0.1 ms**; next 827.8 at step 17; **third-worst of the whole session 104.0 ms** | <= 100 ms | **NOT MET, and NOT this owner's** -- it is the engine loading the place and the first avatar. See `ESCALATE.md` |
| **heartbeat max, reported** | **1,545.7 ms** (`hbmax`), and **under 104.0 ms for every frame after step 17** | reported | **REPORTED** |
| `smoke.sh` gun-in-hand time BEFORE / AFTER | **N/A -- no behaviour changed.** The diff is an instrument, a research note, a spec and an archived control; no line of the lobby's build, pads, shop, range or gun was touched, so there is no AFTER to compare | unchanged +-1 s | **N/A, by reason** |
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
standing would silence the bill for the rest of the session). `BEF3` and `CODEC` are the runs after
the fix, and they are the ones section 1 quotes.

**FAIL FIRST, measured.** With the depth guard deleted and nothing else changed:

```
[tests:server] FAIL: 2979 passed, 1 failed, 0 skipped, 1 errors, 83 spec files
ServerStorage.Tests.lobby_live.spec:415
[harness] FAIL: 31/34 checks @ 8276a2b7 (DIRTY TREE (4 paths) - NOT valid evidence) scope=all
```

Line 415 is the `build=...@step0` assertion in *"keeps the outer scan's bites when the yield lets a
second scan in"* -- the case that drives the re-entry by hand instead of by timing.
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
`317-361 ms over 11-14 frames` and no long frame appears after step 17 -- which is the finding.

---

## 6. WHAT THE INSTRUMENT COSTS, said rather than left out

It is permanent and unflagged, so every number above carries it. Per **frame**: one integer
increment at the top of the boot's Heartbeat (moved there from the middle of the same handler, so
it is not a new operation), one depth increment, one `pcall`, three table reads and two comparisons
in `Lobby.step` past the throttle -- and on a frame the lobby is throttled out of (9 of every 10),
nothing at all, because the guard is before the bill. Per **scan**: three `os.clock()` pairs and
three `world.frames()` calls. Per 120 frames: one `string.format` and one `SetAttribute`, the
cadence `DHBootWorst` already uses. `DHBootStep avg` read 1.03-1.54 ms across the four runs, against
1.19-1.22 in task 356's runs of the same place; the spread between runs is larger than anything this
could add, so **no claim is made that the instrument's own cost was measured**.

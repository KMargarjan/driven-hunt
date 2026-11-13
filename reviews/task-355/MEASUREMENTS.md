# Task 355 -- who spends the server's worst frame during a drive

All readings are from **Karen's own Forest Test**, cell **C1**, **her flags as they are**
(`DHFlag_PLACEMENT_IN_PLACE=false`, `DHFlag_DRIVE_VARIETY=true`, the rest as
`<runs-dir>/355-attrs-before.txt` records them), served from `driven-hunt-rev` on :34873, one drive
and one window per row. **Nothing was written to her place except `DHFlag_BOAR_ATTACH_BUDGET` for
the two arms below, and that attribute alone was removed afterwards** (never
`flags.py --place forest clear`, rule K): `355-attrs-before.txt` vs `355-attrs-after.txt` is
**EMPTY**.

## The instrument, and why there is code before the table

The dispatch says "MEASURE FIRST (no code) ... using os.clock bites or debug.profilebegin". `os.clock`
bites ARE code, so the honest statement is: **no FIX code was written until this file existed**. Three
instrument commits came first, and each one was written because the previous one could not answer
the question:

| commit | what it added | why |
|---|---|---|
| `83837a30` | nine named sections of `Boar.Runtime:step`, and six owners of `ForestTestBoot`'s Heartbeat; the bill of the WORST frame, published on `workspace.Boars.StepWorst` and `ServerStorage.DHBootWorst` | `StepMsMax` has said 73-94 ms since task 327h and could not say to whom |
| `f96d38a8` | `ForestTest.step` split into its seven calls; `Runtime:spawn` timed | "the drive clock" is not a symbol |
| `402aec2e` | **every owner's own max AND own total**, not only the worst frame (`StepOwners`, `DHBootOwners`) | one 1,274 ms lobby frame at the join hid every other owner's worst behind it (`355-BEF3-track.txt`) |

`StepMsMax` / `StepOwners` are per DRIVE; `DHBoot*` are per session. The server frame itself is the
Heartbeat `dt`, sampled by the probe (`<runs-dir>/355-arm.luau`).

## The top three spikes (BEFORE)

Run `BEFORE`, code `402aec2e`, one 340 s drive, flag absent (`<runs-dir>/BEFORE-track.txt`):

| # | owner | file and symbol | worst frame | total over the drive | what triggers it |
|---|---|---|---|---|---|
| 1 | the drive's wave release | `src/server/ForestTest/init.luau` `ForestTest.releaseLine`, called from `ForestTest.step` on `ForestTestBoot`'s Heartbeat | **569.3 ms** | 4,650 ms | a slot firing: one wave released in one frame |
| 2 | the lobby's presence scan | `src/server/Lobby/init.luau` `Lobby.step`, same Heartbeat | **378.4 ms** | 884 ms | a player joining / being rigged at the lodge -- once, at the join, not during the drive |
| 3 | putting the model on the animal | `src/server/Boar/Body.luau` `Body.attachVisual`, called from `Boar.Runtime:step` on the BOAR runtime's own Heartbeat | **92.1 ms** of a 104.2 ms step | 864 ms | the step after a group arrives: ten animals, ten skinned models, one frame |

Everything else is small: `probe` 4.4 ms worst, `brain` 2.7, `snap` 10.0, `draw` 5.3;
`drive.lines` 1.6 ms worst (but 5,035 ms total -- the biggest steady cost, not a spike);
`Runtime:spawn` itself is **4.3 ms at worst over 91 calls**, so release's 569 ms is NOT the making of
the animals.

**Which one this task fixes, and why it is #3 and not #1.** The dispatch's own headline number is
*"a server step peak of 73-94 ms against a 20 ms target"*, and that number is
`workspace.Boars.StepMsMax` -- the BOAR runtime's step, which is spike 3 and nothing else (92.1 of
104.2 ms, 88 %). Its target (`<= 40 ms`) is the one a fix can be measured against here. Spike 1 is
larger in absolute ms and is **named as the next owner** below, with its measurement, which is what
the dispatch asks for when a target is not reached. Spike 2 is at the join, before any drive.

## BEFORE | AFTER

Both arms at the **code commit**, one 340 s C1 drive each, the same probe, the same place
(`<runs-dir>/OFF-ARM-track.txt`, `ON-ARM-track.txt`). The OFF arm is the merge-base behaviour: the
boundary resolves `ATTACH_BUDGET_MS` to 0 and 0 is no budget at all.

| | BEFORE (`402aec2e`, no flag) | OFF arm (code commit) | **ON arm (code commit)** | target |
|---|---|---|---|---|
| boar step peak `StepMsMax` | 104.2 ms | 75.8 ms | **26.1 ms** | <= 40 ms **MET** |
| `attach` worst frame | 92.1 ms | 70.4 ms | **17.2 ms** | <= 20 ms **MET** |
| `attach` total over the drive | 864 ms | 864 ms | 1,441 ms | -- (176 spawns vs 104; see below) |
| heartbeat p95 | 33.14 ms | 33.71 ms | **34.04 ms** | <= 32 ms **NOT MET** |
| heartbeat max | 419.0 ms | 388.0 ms | 110.5 ms | -- |
| peak live | 60 | 59 | 56 | unchanged |
| peak parts | 1,020 | 1,003 | 950 | unchanged |
| `Runtime:spawn` | 91 calls, max 4.3 ms | 104 calls, max 6.1 ms | 176 calls, max 4.6 ms | unchanged |
| animals left with no model | 0 | 0 | **0** | 0 -- it defers, it never drops |

A second ON-arm drive, run earlier at the same code with the untrimmed probe
(`<runs-dir>/AFTER-ON-track.txt`): step peak **24.8 ms**, `attach` worst **16.6 ms**, heartbeat p95
**30.82 ms**, peak live 59, peak parts 978. So the step peak is 24.8 / 26.1 over two ON drives
against 75.8 / 104.2 over two without the budget.

**The three drives released different numbers of animals** (91 / 104 / 176 spawns) because
`DRIVE_VARIETY` is on in her place and every drive draws a different pattern. That is why the
per-drive TOTALS are not compared across arms and the WORST FRAME is: the worst frame is a property
of one release, and every one of these drives contains several.

## 349's own instrument, stand 4 (must not get worse)

`<runs-dir>/355-349run.py` (349-run.py with one change: the stand pick is a real click in Play, so
it uses `rawclick.ps1`), one 320 s drive per arm, `349-table.py`:

| arm | first sighting | median gap | max gap | released | peak live | groups that never came near |
|---|---|---|---|---|---|---|
| budget OFF | 1 s | 2 s | 2 s | 135 | 29 | 1 |
| budget ON | 0 s | 2 s | 2 s | 149 | 27 | 0 |

Not worse on any column.

## What is NOT reached, and whose it is next

**Heartbeat p95 is 30.8-34.0 ms against 32 ms, and this task does not move it.** It is not
attach-bound and it is not spike-bound at all: the two instrumented loops together cost
`stepMsAvg` 3.9 + boot `avg` 1.2 = **5.1 ms of a ~33 ms frame**, so 85 % of the server frame is
outside both of them -- physics, replication and the engine's own work for ~1,000 parts on 56-60
animals. The next owner for p95 is the **part count**, not a Lua loop; nothing in this task's
instrument can see it, and saying otherwise would be guessing.

**The next spike owner is `ForestTest.releaseLine`: 569.3 / 567.5 / 845.7 ms worst frame over the
three drives**, unchanged by this task and not caused by `Runtime:spawn` (4.3-6.1 ms per animal). It
is one frame per wave, and it is the biggest single stall the server takes during a drive.

# Task 366 -- where the frame cost after 360b's trees actually is

**No `src/`, `tests/` or `tools/` file changed.** This is a measurement and an escalation (the
dispatch's own step 3).

Place **Driven Hunt Forest Test** (130094961655666), served on `:34873` from `driven-hunt-karen` at
merged `main` **`c311f278`** (L-162: that is this branch's base, so every reading is at the code
commit's content). One Play session, started and stopped by this session; `ftplay.py mode` answered
`Edit` before it. Probes, frames and logs: `<runs-dir>/366-*`; the output the conclusions rest on is committed under
`reviews/task-366/evidence/`.

---

## 0. The headline

| question the dispatch asked | answer, measured |
|---|---|
| wood of cells **not dealt**? | **No.** They are not on the client at all, and not in `Workspace` on the server either (section 1) |
| wood **out of sight** of the player? | **No.** The one pair that varies residency alone puts it at **+0.85 ms p95** (section 3a) |
| the **dealt cell's own density**? | **Yes, all of it.** +10.92 ms p95 (+54 %) at the stand, in the frustum (section 4) |
| did the **lobby** get slower? | **It was never measured.** 360b's two rows are one station measured twice (section 5) |
| and the **memory**, +11.6 %? | **Not a client figure.** Studio's memory stats are process-wide -- server and client return byte-identical numbers (section 3b). The client's own share of the dealt cell's wood is **+11.1 MB of `GraphicsParts`** |

---

## 1. Per cell, where the wood is (dispatch step 1)

`evidence/366-census-EDIT.txt` (Edit), `evidence/366-srvcensus-S1.txt` (server, Play),
`evidence/366-client-census.txt` (client, Play). Instrument: `360b-census.luau`, unchanged, plus `366-cl.luau`.

| cell | Edit `Workspace.GridForest` | server in Play | client in Play |
|---|---|---|---|
| A1 | 4,087 models / 12,927 parts | `ServerStorage.GridWood` | **absent** |
| B1 | 4,052 / 14,040 | `ServerStorage.GridWood` | **absent** |
| **C1** | **4,431 / 16,344** | **`Workspace.GridForest`** | **`Workspace.GridForest`, 1,803-2,989 models / 6,663-11,254 parts** |
| D1 | 4,476 / 13,560 | `ServerStorage.GridWood` | **absent** |
| A2 | 4,245 / 12,534 | `ServerStorage.GridWood` | **absent** |
| B2 | 3,891 / 12,141 | `ServerStorage.GridWood` | **absent** |
| C2 | 4,172 / 15,022 | `ServerStorage.GridWood` | **absent** |
| D2 | 3,612 / 11,828 | `ServerStorage.GridWood` | **absent** |
| **total** | **32,966 / 108,396** | Workspace 4,431 / 16,344 plus GridWood **28,535 / 92,052** | **C1 only** |

`DHForestLayout=C1`. **Task 337's `Places.Cells` is already doing the job the dispatch suspected was
undone**: one cell stands, seven are stored, and the client is never sent the seven.

`StreamingEnabled=true`, `StreamingMinRadius=384`, `StreamingTargetRadius=512`,
`StreamOutBehavior=Default`, `StreamingIntegrityMode=Default`. The client's resident share of C1
grows as the player moves (6,663 -> 11,254 parts) and does not fall again: `Default` **does not stream
out except under memory pressure**, which is why nothing is released when the player walks away. It is
bounded by the one dealt cell, and it is not what costs (section 3a).

What the resident wood is (`evidence/366-client-census.txt`): 10,353 MeshParts plus 901 Parts; `RenderFidelity`
Automatic on all 10,353; `CollisionFidelity` Default 5,466 / Box 4,887; `Anchored` 11,254;
`CastShadow` 11,254; `CanCollide` 3,141; `CanQuery` 3,141; `ModelStreamingMode` Atomic on all 2,989
models.

## 2. The instrument 360b used does not park the camera -- measured

`360b-park.luau` sets `cam.CFrame` **once** and never binds to RenderStep.
`src/client/Camera/Rig.luau` owns the camera and binds at `Enum.RenderPriority.Camera`, so it
overwrites that write every frame. `360-holdA.luau`'s own comment says exactly this and binds at
`Camera.Value + 10` to beat it.

`366-camcheck.luau` (output: `evidence/366-camcheck.txt`), 28 samples over 14 s, asked for the lobby spawn (2850, 155, -2934):

```
[366cc] parked at 2850,155,-2934 | 0.5s:Scriptable/6791 1.0s:Scriptable/6791 ... 14.0s:Scriptable/6791
```

**6,791 studs from the station, constant, for the whole measurement window** -- and 7,082 studs on a
second run in a later session, equally constant (`evidence/366-camcheck.txt`), because the camera
simply stays on the character wherever the character happens to be. Confirmed by the
drawn-triangle counter tracking the CHARACTER and not the camera: with the character at C1 stand 4,
`RenderBreakdown/Opaque` read 8,637,533 / 8,624,695 / 8,507,583 tris for three different camera
literals, and 5,666,029 once the character was at the lobby (`366-st-A-*.txt`).

Every number below uses `366-hold.luau`, which binds at `RenderPriority.Camera.Value + 10` exactly
as `360-holdA.luau` does and **proves the park held** on its own output line (`HELD: offset 0.00
studs`, plus the count of frames the camera owner tried to drift it: 560-898 per sample).

## 3. The decomposition, three held stations, identical resident set (`366-hold-*`)

All six samples: `GridForest C1: 2,989 models / 11,254 parts`, `Workspace 14,350 parts`, forest
share **78.4 %**, boars 0, character fixed.

| camera station, held | p95 run 1 | p95 run 2 | mean | Opaque drawn | draws | CPU / GPU |
|---|---|---|---|---|---|---|
| C1 stand 4, **straight up** (residency floor) | **19.54** | **18.78** | 16.75 / 16.75 | 132,977 tris | 25 | 14.7 / 6.7 |
| **lobby** spawn, looking east | **22.76** | **22.76** | 19.32 / 19.23 | 2,452,223 tris | 344 | 19.4 / 8.8 |
| **C1 stand 4**, Karen's S/SW angle | **35.47** | **36.03** | 27.99 / 28.60 | 2,423,487 tris | 169 | 18.0 / 9.2 |

The same 11,254 tree parts are resident in all three, so **no row here varies residency** -- these
three rows bound the cost of what is DRAWN, nothing else. Pointing the camera away from the wood
costs **19.2 ms**; pointing it into it costs **35.7 ms**.

Both lobby rows read p95 22.76 because they are two separate 8 s windows whose p95 index landed on
the same millisecond. They are two samples, not one value printed twice: their means are 19.32 and
19.23 over 518 and 521 frames, in the `mean` column above.

## 3a. Residency on its own -- the 2x2 the round-1 review asked for (`evidence/366-grid2.txt`)

Round 1 compared *camera up, wood resident* against *camera into the wood, wood detached* and called
it "two ways of drawing no wood". It is not: those two differ in **both** variables. The missing
cell is **camera up with the wood detached**, and it was run, interleaved, two repeats:

| | p95 median | total memory median | `GraphicsParts` | Opaque drawn |
|---|---|---|---|---|
| camera **up**, forest **ON** | **19.84 ms** | 4,927.5 MB | **27.1 / 27.7 MB** | 126,887 tris |
| camera **up**, forest **OFF** | **18.99 ms** | 4,931.5 MB | **16.6 MB** | 1,778,814 tris |
| camera **stand**, forest **ON** | **29.31 ms** | 4,944.5 MB | **27.7 MB** | 2,418,401 tris |
| camera **stand**, forest **OFF** | **21.31 ms** | 4,941.4 MB | **16.6 MB** | 2,378,153 tris |

* **RESIDENCY = up/ON - up/OFF = +0.85 ms p95, -4.0 MB.**
* **DRAWING the near wood = stand/ON - up/ON = +9.47 ms p95.**
* wood present vs absent at the stand = **+8.00 ms p95** (n=2 here; n=4 in section 4 gives +10.92).

**The residency pair has a confound, and it runs AGAINST the claim, not for it.** With the forest
attached the camera looking up draws 126,887 triangles; detached, the far land comes into the lower
frustum and it draws 1,778,814. So the resident side is also the side with 1.65 M **fewer**
triangles to draw, and it is still the **dearer** of the two by 0.85 ms. Residency's own cost is
therefore **at most ~0.9 ms**, and the true figure is lower. Every condition in which the near wood
is not in front of the camera sits at 19-21 ms whether the wood is resident or not.

## 3b. Memory: what Studio's instrument actually reports (`evidence/366-mem-server.txt`, `evidence/366-mem-client-same-session.txt`)

The dispatch asked for memory because 360b charged the trees with **client memory +11.6 %**
(5,248.4 -> 5,856.5 MB). That figure is not a client figure.

**Measured:** the same probe run against the **server** DataModel and against the **client**
DataModel, seconds apart in one Play, returns **byte-identical** numbers --
`BaseParts = 565.4 MB`, `GraphicsParts = 14.9 MB`, `Instances = 336.6 MB` on both, and
`GetTotalMemoryUsageMb` 4,905.4 against 4,902.5. **`Stats` in Studio reports the PROCESS, not the
DataModel**, and in Studio the server and the client are one process. So 360b's "client memory" is
the whole Studio process -- including the server holding all eight cells' 108,396 parts, 92,052 of
them stored in `ServerStorage.GridWood` where no client ever sees them.

**What IS attributable to the wood the client draws:** `GraphicsParts`, the renderer's own memory,
which is the one tag the detach moves and it moves it identically every time --
**16.6 MB detached, 27.1-27.7 MB attached, in all four pairs: +11.1 MB.** `BaseParts` (565-582),
`Instances` (336-379), `GraphicsMeshParts` (8.1) and `GraphicsTexture` (121.8) do not move at all,
because the detach keeps every instance alive.

Total-memory deltas agree in sign and size: at the stand ON medians 5,004.5 MB against OFF 4,993.5
(+11), at the lobby 5,016.5 against 5,008 (+8.5) -- but total memory also drifts upward through a
run (4,927 -> 4,958 within section 3a's eight samples), so `GraphicsParts` is the figure to quote.

**NOT decomposed:** how much of 360b's +608 MB belongs to the seven stored cells. That would need
them out of the process, and they cannot leave it without destroying Karen's unsaved plant. So
**360b's +11.6 % stays unexplained as a client cost**, and section 7's option D is not sized by it.

## 4. The dealt cell's wood, ON vs OFF, interleaved (`evidence/366-forestoff-c1s4.txt`, `evidence/366-forestoff-lobby.txt`)

`GridForest` detached on the **client only**, reference kept, restored (`restored=true` on the last
line); the server and her place untouched. Four ON and four OFF alternating, so drift cannot pass
for the effect.

| station | forest ON, median p95 (range) | forest OFF, median p95 (range) | the wood costs | Opaque ON vs OFF |
|---|---|---|---|---|
| **C1 stand 4** | **31.13 ms** (21.39-35.94) | **20.22 ms** (18.11-21.15) | **+10.91 ms, +54.0 %** | 2,418,401 vs 2,378,153 |
| **lobby spawn** | **25.40 ms** (25.31-25.66) | **24.58 ms** (22.97-26.12) | **+0.82 ms, +3.4 %** | **2,452,223 vs 2,452,223 -- identical** |

At the lobby the wood draws **not one triangle** and costs +0.8 ms, inside the noise of section 6.
Note also that OFF is tight (18.1-21.2) where ON is wild (21.4-35.9): the wood is both the cost and
the variance.

Section 3a's independent 2x2, two repeats and a different Play session, puts the same quantity at
+8.00 ms. Both are quoted; neither is averaged into the other.

## 5. Why 360b read "+30 % at the lobby"

Its lobby row and its C1 row were **the same view**: the camera never left the character (section
2), and the character was at C1 stand 4 on both sides (the Forest Test opens a drive by itself
~10 s after boot -- `366-console-S1.txt`: *"Alhamdulilah824 took stand 4"*). So 360b measured one
quantity twice and both copies rose. There is no second, lobby-side regression to find, and nothing
in section 1 or 4 supports *"the client is carrying or drawing wood it cannot see"*.

## 6. What one frame-p95 sample of this place is worth (`evidence/366-noise-1.txt`)

Six consecutive 8 s samples, one held station, nothing changed between them -- same 11,254 forest
parts, same 528 boars, same character position, same 2,418,401 drawn triangles:

```
s1 p95 23.72 | s2 29.06 | s3 30.04 | s4 34.79 | s5 28.14 | s6 29.38
SPREAD over 6 identical samples: min 23.72 median 29.06 max 34.79 -> max/min = 1.47x (+46.7 %)
```

**The instrument's own spread (+46.7 %) is wider than the regression the trees were charged with
(+24 % / +30 %).** A single 8-10 s p95 window in this place does not separate a 30 % effect from nothing. The
section 4 effect survives this because it is interleaved and its two distributions do not overlap at
the stand (ON 21.4-35.9 against OFF 18.1-21.2, median gap 10.9 ms).

Per the task 357 perf lesson: every figure here counts **RenderStepped frames** over an 8-10 s
window (282-598 frames per sample, printed on every line). No `os.clock` spans a yielding call.

## 7. The levers that were tried, and what each is worth (all at C1 stand 4, interleaved)

| lever | p95 change | triangles | what Karen would see | ownable in `src/`? |
|---|---|---|---|---|
| the dealt cell's wood gone | **-10.91 ms (-35 % of the ON median 31.13)** | occlusion flips; -40 k net | the trees she asked for, gone | -- |
| `RenderFidelity = Performance` on the 10,353 tree MeshParts (`evidence/366-lod.txt`) | **-2.20 ms (-8.7 % of its own ON median 25.40)**, all 3 pairs improved (28.92->26.98, 25.40->23.20, 23.13->21.04) | **2,423,487 -> 1,914,595 (-21 %)** | coarser trunk and branch shape close in | **yes** -- `Places.plantOne` already writes part properties |
| forest `CastShadow = false` (`evidence/366-shadow-out.txt`) | -0.33 ms (-1.2 %), noise | 0 | trees stop casting shadows | yes, same place |
| `Lighting.GlobalShadows = false` | -3.01 ms (-11 %) | 0 | the whole scene loses shadows | Lighting is not Rojo-owned |
| residency / wood out of frustum | **-0.85 ms at most** (section 3a) | 0 | nothing | nothing to change |
| cells not dealt | **0** | 0 | nothing | already done (task 337) |

Every percentage in the table is off that lever's own ON median, so the column is comparable.
Nothing here reaches the dispatch's target of **28.40 ms at C1 stand 4** without changing what Karen
sees. The one measured lever that is both ownable and worth more than noise, `RenderFidelity`, buys
2.2 ms of the 10.9 and is a **look** change -- hers to judge, and `NOT YOURS` territory for this
task besides.

## 8. The trees behind the default stand are unchanged

`366-GA-NOW.png`, C1 stand 4, eye height (-3905, 112.4, -5063), Karen's S/SW angle, camera held by
`360-holdA.luau` verbatim, captured by `360-cap.py` -- the same route as 360b's GA pair.

**Opened and described (rule 5, rule F -- the camera is at eye height, not aerial):** a continuous
wall of spruce and birch trunks across the full width at ~15-40 studs, canopy closing the top of the
frame, two small blue slivers top-left and top-right; grass and a dirt track in the foreground; no
open horizon and no distant ridge. HUD reads `DRIVE 4`, `BEATER`.

Sky/haze in the eye-level band: **1.95 %**, against 360b-GA-AFTER's **2.29 %** on the same rule
(`366-sky.py`: the band is the middle 20 % of the frame, a pixel counts when max(r,g,b) >= 120 and
saturation <= 0.30). **That rule is mine, not 360b's**: run over 360b's own six frames it reads
GA 13.01 -> 2.29 %, GB 12.73 -> 2.34 %, GC 1.44 -> 1.39 %, where 360b reported 15.6 -> 0.9,
13.9 -> 0.7 and 0.4 -> 0.3. Same contrast, same ordering, different absolute values; the comparison
above is like-for-like because both sides are read with my rule.

## 9. BEFORE | AFTER, and what is NOT proven

1. **There is no AFTER.** No flag, no code, no world change -- the dispatch's step 3. Section 4's
   `ON | OFF` and section 3a's 2x2 are the before/after pairs this task can honestly produce: same
   instrument, same Play, same seconds, interleaved.
2. **Step 4 is N/A for the same reason** -- no flag to switch on, so no second set of readings and
   no drive to start by a click. The control path for when it is needed is recorded in the TASKS.md
   dispatch (L-095) and was not exercised here.
3. **Nobody has played this.** Every figure is a probe's. Whether 35 ms at the stand *feels* worse
   than 25 ms is Karen's call and nobody has asked her.
4. **360b's +11.6 % memory is still unexplained as a CLIENT cost, and this task does not explain
   it.** Section 3b shows the instrument that produced it reports the whole Studio process, and
   measures the client-attributable share at +11.1 MB of `GraphicsParts`. What the remaining ~600 MB
   is -- the seven stored cells on the server, Luau heap, drift between two Play sessions -- is NOT
   decomposed, because the stored cells cannot leave the process without destroying Karen's unsaved
   plant.
5. **The residency pair has a confound** (section 3a): the resident side draws 1.65 M fewer
   triangles. It bounds residency at <= ~0.9 ms rather than measuring it exactly, and the confound
   runs against the claim.
6. **The lobby rows were taken with the player at the stand.** Moving the character to the lobby
   mid-drive did not stick -- the server pulled it back (`366-st-A-plobby-*.txt`). The lobby rows in
   sections 3 and 4 are therefore *the lobby view with C1's wood resident*, which is the harder
   case, not the easier one.
7. **`StreamOutBehavior` was not changed or tested.** It is a `Workspace` property, and `Workspace`
   is not Rojo-owned (CLAUDE.md Layout), so no file under `src/` can own it. Listed in `ESCALATE.md`
   as the Director's to decide. Its frame-time ceiling is section 3a's <= 0.9 ms; its memory ceiling
   is +11.1 MB of `GraphicsParts`. Neither is sized by 360b's +608 MB (item 4).
8. **The flaky specs were named, not diagnosed** -- see `REQUEST.md` claim 9.

## 10. The place was left as it was found

* `python ftplay.py mode` -> **Edit**, on `:34873` from `driven-hunt-karen`;
* **attribute diff EMPTY** (L-101): `366-attrs-BEFORE.txt` vs `366-attrs-AFTER.txt` identical -- 23
  `DHFlag_*` plus `DHForestLayout`, `DHForestStartRole`, `DHShopTestGrant`, `DHTestOwns` unchanged.
  `DHFlag_PLACEMENT_IN_PLACE`, `DHFlag_MAP_PAINTED`, `DHFlag_CARCASS_POSE` all still `true`. No flag
  was set; `flags.py --place forest clear` was never run;
* **360b's unsaved plant survives**: final Edit census `Workspace.GridForest` **32,966 models /
  108,396 parts, 8 cells, PlantEpoch=58575af518ae6156** -- identical to the opening census
  (`366-census-END.txt`);
* `ft-open.sh` was **not** used (360b section 9: it can spawn a second Studio and kill the session
  holding the plant). The existing session was used throughout;
* **never Saved, Published or Drafts-Committed**; no code was checked out in `driven-hunt-karen`;
* game error lines in the console at the end: **0** (`366-console-END.txt`, searched for
  `Stack Begin`, `attempt to`, `invalid argument`). The two that appeared mid-session were this
  session's own first probe reading `Workspace.MeshPartHeadsAndAccessories`, which does not exist --
  `Script 'AssistantCommand'`, not a game script (`366-console-S1.txt` lines 121-124, 157-160).

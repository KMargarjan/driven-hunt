# Task 366 -- where the frame cost after 360b's trees actually is

**No `src/`, `tests/` or `tools/` file changed.** This is a measurement and an escalation (the
dispatch's own step 3).

Place **Driven Hunt Forest Test** (130094961655666), served on `:34873` from `driven-hunt-karen` at
merged `main` **`c311f278`** (L-162: that is this branch's base, so every reading is at the code
commit's content). `Edit` before each. Five Play sessions in all, each started and stopped by this session. Probes, frames and logs: `<runs-dir>/366-*`; the output the conclusions rest on is committed under
`reviews/task-366/evidence/`.

---

## 0. The headline

| question the dispatch asked | answer, measured |
|---|---|
| wood of cells **not dealt**? | **No.** They are not on the client at all, and not in `Workspace` on the server either (section 1) |
| wood **out of sight** of the player? | **No.** The one pair that holds DRAWING exactly constant -- the lobby, where the wood is out of frustum either way and `Opaque` is the identical 2,452,223 on both sides -- puts residency at **+0.82 ms p95 with the two ranges overlapping**, i.e. not distinguishable from zero (section 3a) |
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
`src/client/Camera/Rig.luau` is the only writer of `workspace.CurrentCamera` in `src/`, and the bind
is in `src/client/Camera/init.luau` --
`RunService:BindToRenderStep(Config.RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value, update)` --
so it overwrites that write every frame. `360-holdA.luau`'s own comment says exactly this and binds at
`Camera.Value + 10` to beat it.

`366-camcheck.luau` (output: `evidence/366-camcheck.txt`), 28 samples over 14 s, asked for the lobby spawn (2850, 155, -2934):

```
[366cc] parked at 2850,155,-2934 | 0.5s:Scriptable/7082 1.0s:Scriptable/7082 ... 14.0s:Scriptable/7082
```

**7,082 studs from the station, constant, for the whole measurement window** (`evidence/366-camcheck.txt`)
-- and 6,791 studs on an earlier run in another session, equally constant, because the camera simply
stays on the character wherever the character happens to be. Confirmed by the
drawn-triangle counter tracking the CHARACTER and not the camera: with the character at C1 stand 4,
`RenderBreakdown/Opaque` read 8,637,533 / 8,624,695 / 8,507,583 tris for three different camera
literals, and 5,666,029 once the character was at the lobby (`366-st-A-*.txt`).

Every number below uses `366-hold.luau`, which binds at `RenderPriority.Camera.Value + 10` exactly
as `360-holdA.luau` does and **proves the park held** on its own output line (`HELD: offset 0.00
studs`, plus the count of frames the camera owner tried to drift it: 560-898 per sample).

## 3. The decomposition, three held stations (`evidence/366-grid3-three.txt`)

Two repeats of each station, one Play, one probe call, the forest attached throughout, the park
proved held on every line (`held offset 0.00 studs`; the camera owner tried to drift it on 2,969
frames and lost every one).

| camera station, held | p95 median | range | mean | Opaque drawn | draws |
|---|---|---|---|---|---|
| C1 stand 4, **straight up** | **21.73 ms** | 21.31-22.15 | 17.25 / 17.20 | 125,523 tris | 22 |
| **lobby** spawn, looking east | **31.13 ms** | 29.55-32.71 | 22.20 / 22.94 | 2,452,223 tris | 342 |
| **C1 stand 4**, Karen's S/SW angle | **35.38 ms** | 34.04-36.72 | 25.75 / 27.80 | 2,418,401 tris | 176 |

**No row here varies residency** -- the forest is attached in all three -- so these bound the cost of
what is DRAWN and nothing else. The ordering is the finding: looking away from everything costs
21.7 ms, the lobby's own content costs 31.1, and the wood in front of the stand costs 35.4.

**Absolute p95 drifts a lot between sessions and must not be read across them.** An earlier run of
the same three stations read 19.5 / 22.8 / 35.5 at 4.9 GB of process memory; this one reads
21.7 / 31.1 / 35.4 at 5.16 GB. The ordering survives; the absolute numbers do not. That is section
6's point again, and it is why every claim in this document is a pair taken inside one probe call.

## 3a. Residency on its own

Round 1 compared *camera up, wood resident* against *camera into the wood, wood detached* and called
it "two ways of drawing no wood". It is not: those differ in **both** variables. Two attempts at the
isolate were made; **only one of them works**, and it is not the one round 2 ran.

### The pair that works: the lobby, drawing held EXACTLY constant (`evidence/366-forestoff-lobby.txt`)

At the lobby the wood is out of the frustum whether it is attached or not, and the counter proves it:
`Opaque` is the **identical 2,452,223 tris** on all four ON samples and all four OFF samples. So this
pair varies residency and nothing else.

| | p95 median | range | n |
|---|---|---|---|
| forest attached (resident) | **25.40 ms** | 25.31-25.66 | 4 |
| forest detached | **24.58 ms** | 22.97-26.12 | 4 |

**Residency = +0.82 ms, and the two ranges overlap**, so it is not distinguishable from zero by this
instrument. What it does establish is a ceiling: residency is about a millisecond, against the
~11-14 ms the drawn wood costs.

### The pair that does NOT work: camera up, forest ON vs OFF (`evidence/366-grid3-up.txt`)

Four interleaved repeats, a true median (round 2's probe used `s[ceil(n/2)]`, which at n=2 is the
MINIMUM, and picked p95 and memory column by column so a row could mix two samples -- both fixed):

| | p95 median | range | `GraphicsParts` | Opaque drawn | n |
|---|---|---|---|---|---|
| camera up, forest attached | **20.57 ms** | 19.15-31.67 | 27.2-27.7 MB | 126,887 tris | 4 |
| camera up, forest detached | **18.64 ms** | 18.05-18.77 | 16.6-16.7 MB | 1,778,814 tris | 4 |

The gap is **+1.93 ms** -- not round 2's +0.85, which was min-vs-min.

**This pair bounds residency in NEITHER direction, and the reason is in this task's own data.** Its
two sides draw different content: attached, the trees block the lower frustum and 126,887 triangles
are drawn; detached, the far land comes into it and 1,778,814 are. Whether that inflates or deflates
the gap depends on whether near-tree pixels cost more or less than distant-land pixels -- and
section 4 measures that **cost is not a function of triangle count**: at the stand, the OFF side
draws 40,248 **fewer** triangles and is **10.92 ms cheaper**, which no per-triangle model explains.
So the direction of the correction is unknown, and +1.93 ms is reported as what it is: a gap between
two conditions that differ in two ways. Nothing in sections 0, 7 or 9, and nothing in `ESCALATE.md`,
rests on it.

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
**16.6 MB detached, 27.1-27.7 MB attached, in all four pairs: +11.1 MB**, and again +11.0 MB at n=4 in `evidence/366-grid3-up.txt` (16.6-16.7 detached, 27.2-27.7 attached). `BaseParts` (565-582),
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
| **C1 stand 4** | **31.13 ms** (21.39-35.94) | **20.22 ms** (18.11-21.15) | **+10.92 ms, +54.0 %** | 2,418,401 vs 2,378,153 |
| **lobby spawn** | **25.40 ms** (25.31-25.66) | **24.58 ms** (22.97-26.12) | **+0.82 ms, +3.4 %** | **2,452,223 vs 2,452,223 -- identical** |

At the lobby the wood draws **not one triangle** and costs +0.8 ms, inside the noise of section 6.
Note also that OFF is tight (18.1-21.2) where ON is wild (21.4-35.9): the wood is both the cost and
the variance.

Section 3's independent three-station run, a different Play session, puts the stand's drawn-wood
cost at `stand 35.38 - up 21.73 = +13.65 ms` with residency held constant on both sides. The two
are not averaged into each other: +10.92 is wood present vs absent, +13.65 is wood drawn vs wood
resident-but-not-drawn, and they bracket the same thing from either side.

## 5. Why 360b read "+30 % at the lobby"

Its lobby row and its C1 row were **the same view**: the camera never left the character (section
2), and the character was at C1 stand 4 on both sides (the Forest Test opens a drive by itself
~10 s after boot -- `366-console-S1.txt`: *"Alhamdulilah824 took stand 4"*). So 360b measured one
quantity twice and both copies rose. There is no second, lobby-side regression to find, and nothing
in section 1 or 4 supports *"the client is carrying or drawing wood it cannot see"*.

## 6. What one frame-p95 sample of this place is worth (`evidence/366-noise-1.txt`)

Six consecutive 8 s samples, one held station, nothing changed between them -- same 11,254 forest
parts, same 528 boars, same character position, and the same 2,418,401 drawn triangles in four of the
six (s5 and s6 read 2,446,353; the minimum s1 and the maximum s4 are both in the 2,418,401 group,
so the spread below is not a triangle-count effect):

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

## 7. The levers that were tried, and what each is worth (all at C1 stand 4)

| lever | p95 change | triangles | what Karen would see | ownable in `src/`? |
|---|---|---|---|---|
| the dealt cell's wood gone | **-10.92 ms (-35 % of the ON median 31.13)** | occlusion flips; -40 k net | the trees she asked for, gone | -- |
| `RenderFidelity = Performance` on the 10,353 tree MeshParts (`evidence/366-lod.txt`) | **-2.20 ms (-8.7 % of its own ON median 25.40)**, all 3 pairs improved (28.92->26.98, 25.40->23.20, 23.13->21.04) | **2,423,487 -> 1,914,595 (-21 %)** | coarser trunk and branch shape close in | **yes** -- `Places.plantOne` already writes part properties |
| forest `CastShadow = false` (`evidence/366-shadow-out.txt`) | -0.33 ms (-1.2 %), noise | 0 | trees stop casting shadows | yes, same place |
| `Lighting.GlobalShadows = false` | -3.01 ms (-11 %) | 0 | the whole scene loses shadows | Lighting is not Rojo-owned |
| residency / wood out of frustum | **-0.82 ms** (section 3a's lobby pair, ranges overlapping) | 0 | nothing | nothing to change |
| cells not dealt | **0** | 0 | nothing | already done (task 337) |

Every percentage is off that lever's own ON median, so the column is comparable. **The LOD row is
interleaved** (`366-lod.txt` alternates Automatic/Performance three times) **and the two shadow rows
are not**: `366-shadow-out.txt` is one A->B->C->D sequence whose two controls, with nothing changed
between them, differ by 2.20 ms (A 27.24, D 29.44) -- larger than the -0.33 ms it calls noise and
comparable to the -3.01 ms it reports for `GlobalShadows`. **Both shadow figures are therefore soft**,
and neither is relied on.
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
5. **Residency rests on ONE pair, the lobby's**, and its two ranges overlap (25.31-25.66 against
   22.97-26.12), so +0.82 ms is a ceiling of about a millisecond rather than a measurement. The
   camera-up pair is reported but bounds nothing (section 3a).
6. **The lobby rows were taken with the player at the stand.** Moving the character to the lobby
   mid-drive did not stick -- the server pulled it back (`366-st-A-plobby-*.txt`). The lobby rows in
   sections 3 and 4 are therefore *the lobby view with C1's wood resident*, which is the harder
   case, not the easier one.
7. **`StreamOutBehavior` was not changed or tested.** It is a `Workspace` property, and `Workspace`
   is not Rojo-owned (CLAUDE.md Layout), so no file under `src/` can own it. Listed in `ESCALATE.md`
   as the Director's to decide. Its frame-time ceiling is the lobby pair's +0.82 ms; its memory
   ceiling is +11.1 MB of `GraphicsParts`. Neither is sized by 360b's +608 MB (item 4).
8. **The flaky specs were named, not diagnosed** -- see `REQUEST.md` claim 9.

## 10. The place was left as it was found

* `python ftplay.py mode` -> **Edit**, on `:34873` from `driven-hunt-karen`;
* **attribute diff EMPTY** (L-101): `evidence/366-attrs-BEFORE.txt` vs `evidence/366-attrs-END.txt` identical, and re-checked after every Play session -- 23
  `DHFlag_*` plus `DHForestLayout`, `DHForestStartRole`, `DHShopTestGrant`, `DHTestOwns` unchanged.
  `DHFlag_PLACEMENT_IN_PLACE`, `DHFlag_MAP_PAINTED`, `DHFlag_CARCASS_POSE` all still `true`. No flag
  was set; `flags.py --place forest clear` was never run;
* **360b's unsaved plant survives**: final Edit census `Workspace.GridForest` **32,966 models /
  108,396 parts, 8 cells, PlantEpoch=58575af518ae6156** -- identical to the opening census
  (`evidence/366-census-END.txt`);
* `ft-open.sh` was **not** used (360b section 9: it can spawn a second Studio and kill the session
  holding the plant). The existing session was used throughout;
* **never Saved, Published or Drafts-Committed**; no code was checked out in `driven-hunt-karen`;
* game error lines in the console at the end of each session: **0** (`366-console-END.txt`,
  `366-console-R2.txt`, `366-console-R3.txt`, searched for
  `Stack Begin`, `attempt to`, `invalid argument`). The two that appeared mid-session were this
  session's own first probe reading `Workspace.MeshPartHeadsAndAccessories`, which does not exist --
  `Script 'AssistantCommand'`, not a game script (`366-console-S1.txt` lines 121-124, 157-160).

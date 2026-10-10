# Escalations

## 2026-10-10 — Task 149b: the code is done and gated, and it cannot be reviewed. TWO BLOCKERS

**The work itself is finished and measured.** `[harness] PASS: 33/33 checks @ 8468e38 (clean tree)
scope=all`, smoke PASS, item 2 at 29% → 91% and item 3 at 60.7 s → 3.3 s dwell, both measured
either side of the change. `reviews/task-149b/REQUEST.md` is written. **Neither blocker below is
about the code**, and I have not worked around either of them.

### BLOCKER 1 — for the DIRECTOR: this review folder has a name the gate cannot accept

`tools/review.ps1 149b` answers `[agents] REFUSED: task number must be digits; got '149b'`, and
with no argument `resolve_task` matches only `task-(\d+)`, so it picks the **already-merged**
`reviews/task-149/REQUEST.md`. The review has therefore not run at all. The task number is the
Director's to set, so I have changed nothing.

**What I recommend, and will do in one paperwork commit on your word:** give this work the next free
number — **150** — `git mv reviews/task-149b reviews/task-150`, `Task: 150`, `Round: 1`, and a
line in the `149b` row of `TASKS.md` saying its review is filed as 150. That keeps
`reviews/task-149/RESULT.md` exactly as PR #132 was merged on (rule 7: nothing is overwritten), and
it starts this task's round count at 1, which is what it is.

**The alternative I did not take:** reusing `reviews/task-149/` would make this `Round: 2` of a
merged task and would overwrite the verdict that PR #132 was merged on.

### BLOCKER 2 — NEEDS KAREN: the two-player run, one click

The change touches `src/server/MatchBoot.server.luau` — **one line**, `runtime:hearShot(shot.muzzle,
shot.at)`, passing the impact point through to the boar runtime exactly as `ForestTestBoot` does —
and that file is in `TWO_PLAYER_PATHS` in `tools/agents.py`, so the gate refuses the review and the
merge without a `[harness2]` line for the code commit:

```
[agents] REFUSED: this change touches src/server/MatchBoot.server.luau, which a one-player run
cannot evidence. Paste the TWO-PLAYER line for the code commit as well.
```

I ran it. It posted F7 and **one Studio opened instead of three**, so nobody was playing:

```
[harness2] NEEDS KAREN: nobody pressed Start. Nothing was run and nothing is claimed.
FAIL: 10/12 checks @ c4cda6d (clean tree)
```

**I am not claiming that run, and `reviews/task-149b/REQUEST.md` now says so in place of the "N/A"
line it wrongly carried.**

**THE EXACT CLICKS, in order.** Studio is already in Edit with two windows open (Driven Hunt DEV and
Driven Hunt Forest Test) and nothing stray; the leftover `Server` window from my attempt is closed.

1. In a terminal at the repo: `python tools/studio_mcp.py test2` — then leave it running and do 2–4
   while it waits.
2. In **Driven Hunt DEV**, menu bar → **Test** → **Clients and Servers**.
3. Set **Players: 2**.
4. Press **Start**. Leave both player windows alone — do not click into them, do not move them.
5. When the harness prints its line, menu bar → **Test** → **End Session** (Alt+Shift+E) to close the
   extra windows.

Then paste the `[harness2] PASS: n/m checks @ 8468e38...` line into the request under the `[harness]`
line, and the review can run.

## 2026-10-09 — Task 139 (Karen's five boar complaints): BLOCKER, and the measurements

**ROUND 1 ONLY. Nothing was shipped in round 1: `src/` went back to `main` exactly and the only
change on the branch was Karen's words in `PLAYTEST.md`.** I stopped rather than merge a change set
that made two of her five complaints measurably worse. Rounds 2, 3 and 4 then shipped on the
Director's decisions; what this entry records is the stop and the measurements that caused it, not
the state of the branch.

### Why I stopped

I built a trace that measures all five from one 150 s Forest Test run (hunter at a stand, shots
through the real `FireRequest` route, reload after two). Three runs of the SAME build disagree by
more than the effects I was trying to measure:

| | main (before) | with fixes | fixes minus one |
|---|---|---|---|
| slide, median % gap between ground covered and feet | 56.2 | 56.2 | **44.8** |
| moving with no locomotion clip | 21.0 % | 20.4 % | **31.8 %** |
| shot animals that stood | 0 of 9 | 0 of 10 | 1 of 10 |
| ran NORTH after a shot | **5 of 9** | **1 of 10** | 3 of 10 |
| came back north over the road | 0 | **19** | **26** |
| worst sounds, one pack / world | 2 / 2 | 3 / 3 | 3 / 3 |

The slide figure moves by 11 points between runs of builds that differ in ways that cannot affect
it, so it is noise at this sample size and I cannot use it to show a fix works. "Came back north"
went from 0 to 19–26 and I could not attribute it: I reverted the change I suspected and it got
worse, not better. Shipping that would trade one of Karen's complaints for another.

### What IS established, and is worth keeping

1. **Item 3 has a located root cause and a real measurement.** `Brain:_latchFlight` reads, in its
   own comment: *"UNLESS THE WAY OUT IS PAST THE GUN … an animal in that position runs from the gun
   and finds its way out later"* — `self._flightHeading = if away:Dot(toExit) <= 0 then away else …`.
   **In a drive the shooter is ALWAYS in that position**: he stands on the road and the way out is
   past him. Measured on `main`: **5 of 9 shot animals ran north**, back into the view Karen had just
   shot into. Making the exit win took that to 1 of 10 — but that same change (or something it
   interacts with) is my first suspect for the "came back north" regression.
2. **Item 5 is already satisfied on `main` by this measure, and it fights item 4.** The worst moment
   in a 150 s run with nine shots was **2 sounds in one pack and 2 in the world**. Karen's *"max 2"*
   is met; what she is describing in *"I can't hear a sound walking"* is the other side of the same
   coin — the step rows are capped at `audibleStuds = 40` while a hunter watches animals from 120.
   Raising them to 75/85/95 made the approach audible AND took the worst count to 3. **These two
   cannot both be satisfied by range alone** — the cap has to become structural first.
3. **The line drive bypasses the voice cap entirely.** `ForestTest.releaseLine` spawns with
   `runtime:spawn` per animal, not `spawnSounder`, so line members have no `sounderId`; `Boar.hasVoice`
   answers "a herd with no list silences nobody" and **every animal in a line may voice**. That the
   count is 2 today is luck, not the cap. A `Runtime:formSounder(ids)` called once at release is the
   fix, and it is the prerequisite for item 4.
4. **Item 2 could not be reproduced in 29 shots across three runs** (0, 0 and 1 "stood"). The one
   mechanism I can see is real but unproven: a shot animal's flight ends, the line takes it back, the
   overrun rule orders `point = here, speed = 0`, and it stands. The one occurrence I did catch
   (`top speed 4.5, moved 12 studs in 12 s`) is consistent with it.
5. **Item 1's arithmetic does not explain the number.** The dwell path in `Body.clipFor` divides by
   `clips[held].groundStudsPerSecond` and omits `clipScale`, which every other rate in the file
   includes — a real defect. But fixing it did not move the measured gap at all, so either it is not
   the dominant path or my probe's `footed = groundStudsPerSecond × clipScale × track.Speed` is
   measuring the wrong thing. **I will not report a 56 % sliding figure as fact when I cannot
   reproduce it to better than ±11 points.**

### What I need from the Director

- **Item 4 vs item 5 is a decision, not a bug.** Audible from 60–80 studs and "max 2 sounds per pack"
  require the cap to become structural (point 3) before the range goes up. Confirm that ordering.
- **The trace needs to be longer or per-wave** before any of these can be shown fixed; 150 s of
  samples is not enough to see an 11-point effect.

Everything above is reproducible: the instrument is a temporary `Runtime:t139Publish` plus
`scratchpad/t139_trace.py`, and both are described in this entry rather than left in the tree.

For the Director and Karen. The Builder (or any agent) writes here and stops when:
- the same item has failed 3 review rounds
- it believes the Reviewer or Architect is factually wrong
- a design, feel or scope decision is needed
- **a human action is needed** (Rojo **Connect**, the Studio MCP toggle, Studio not in Edit mode,
  anything only Karen can click). Head that entry **`NEEDS KAREN`** and list the exact clicks.

Newest first. The Director or Karen answers under each entry, and the entry is closed with a date.

---
## 2026-10-06 · DIRECTOR DECISION · Tasks 122-130 merge as ONE pull request

**Raised by:** the Director, transcribed here by the Builder because the decision has to live where
the next reader of the merge gate will look for it.

**The decision:** the stack `122 -> 130` goes to `main` as a single PR (`task-130-spawn-view` ->
`main`), not as nine stacked PRs. Task 121 is NOT in it; PR #112 stays open and is to be closed as
superseded with Karen's OK.

**The reason, which is a fact about the gate and not a preference:** no branch below 128 can pass the
gate on its own.

* The gate's DEV place could not be rebuilt until task **128** existed. `tools/mapgen.py` had been
  dead since the MCP thread began refusing every `require`, so `Workspace.DrivenHuntMap` still held
  hand-made experiments with **0 tagged markers** against the 8 shooter posts, 4 boar spawns, drive
  line, driver start and 12 trees that `map_contract.spec` requires. Every run from task 122 onward
  failed on that, 18 of 23.
* Tasks **123-127** then shipped against a gate that could not run, and **129** found and fixed the
  20 spec failures that had accumulated -- three of them real bugs in shipped code. So 123-127 cannot
  be green before 129 exists, and 129 cannot be green before 128 is.

**What the evidence is, therefore:** the gate AT THE HEAD of the stack, both runs, clean tree, DEV:

```
[harness] PASS: 33/33 checks @ 831a06fbe759608129b15f1fbfdfb2f5abebfb16 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 831a06fbe759608129b15f1fbfdfb2f5abebfb16 (clean tree)
```

**What does NOT change:** every task still gets its own review. There is one
`reviews/task-<N>/REQUEST.md` for each N in {122, 123, 124, 125, 126, 127, 128, 129, 130}, each with
its own claims about that task's final state and its own list of what could not be verified, and the
Director runs the reviews one per task.

**One honest note about the gate at that head** (and it is queued in `TASKS.md` as a before-release
item rather than hidden here): the FIRST one-player run at this commit reported `FAIL 31/33` and the
immediate re-run on the same commit reported `PASS 33/33`. The failing check was not captured. A
gate that answers two different things about one commit is a gate with a flake in it, and the Builder
has seen one candidate on identical code -- `boar_body.spec`'s "the sounder scatters after its leader
dies", which failed 2 runs in 9 during task 129.

---
## 2026-10-03 · CLOSED 2026-10-03 · NEEDS DIRECTOR CLICKS · Task 115: the ten boar animations can only be published from inside Studio

**Raised by:** Builder, Task 115 (branch `task-115-boar-model`).

**What is blocked:** the boar's legs, and nothing else. The model itself is uploaded, approved,
measured and welded; with `BOAR_MODEL` on, a boar is RedDeer's textured male boar on the same physics
box. It does not move, because an `Animation.AnimationId` needs an animation ASSET and there is no
asset id for any of the ten clips yet.

**Why no tool can do it, measured rather than assumed:**

1. **Open Cloud will not take one from us.** The Assets API's own table gives `Animation` exactly two
   formats, `.rbxm` and `.rbxmx`, with the restriction *"`.rbxm` or `.rbxmx` files edited outside of
   Roblox Studio might not upload or function"*. Nothing outside Studio can write one, and `.rbxm` is
   banned in this repository anyway.
2. **`AssetService:CreateAssetAsync` is not available.** Tried through the harness's plugin-context
   `execute_luau`, in Edit mode, on 2026-10-03, with a hand-built `KeyframeSequence`, for both
   `Enum.AssetType.Animation` and `Enum.AssetType.Model`. Both answered:
   `"CreateAssetAsync and CreateAssetVersionAsync are not available yet"`.
3. The documented route is the Animation Editor's **Publish to Roblox**, which is a dialog.

**So: ten clips, two clicks each, and the Builder has made the files for it.**
`tools/boar_prep.py` writes one FBX per clip, each carrying the rig and that clip alone, at
`<assets-dir>/boar/prep-male-v4/clips/`:

```
Idle_1.fbx  Walk_F_IP.fbx  Trot_F_IP.fbx  Run_F_IP.fbx  Turn_L_IP.fbx
Turn_R_IP.fbx  Death_L.fbx  Death_R.fbx  Hit_F.fbx  Hit_B.fbx
```

**The exact clicks, in order.** Once, to get a rig to import onto:

1. In Studio, on the DEV place, in **Edit** mode, drag `<assets-dir>/boar/prep-male-v4/model.fbx`
   into the 3D Importer (**Avatar → 3D Importer**, or File → Import 3D). Accept it. One skinned
   MeshPart with 40 Bones appears.
2. Select the imported model. Open **Avatar → Animation Editor**. Give the rig a name when it asks.

Then, for each of the ten files above:

3. **⋯ → Import → From FBX Animation**, pick `<clip>.fbx`, accept.
4. ~~Click the **Curve Editor** button beside the timeline and press **Confirm**.~~ **NOT NEEDED.**
   This step came from Roblox's *emote* import page, where a `CurveAnimation` is required. The
   Director found the publish dialog takes the `KeyframeSequence` directly, and all ten published
   and load back fine without it.
5. **⋯ → Publish to Roblox**. Title it exactly the clip's own name — `Walk_F_IP`, `Death_L` and so on
   — and Save. **Copy the asset id** the Asset Configuration window then shows.

Afterwards, two things that matter:

6. **Delete `ServerStorage.RBX_ANIMSAVES` and the imported model before the next harness run.**
   ServerStorage is Rojo-owned with `$ignoreUnknownInstances: false`, so anything left there fails
   the harness's "no instance Rojo does not know about" check — and Workspace must contain no
   leftovers either.
7. Hand the Builder the ten `name = id` pairs, or add them yourself: ten rows in
   `src/serverstorage/Assets/init.luau` with `kind = "animation"`, `scope = "boar-animation"` and
   `key = Assets.KEYS.boar<Clip>`. **No code changes** — `BoarAssetsBoot` already reads them through
   `Assets.byKey`, `Boar` already knows the ten clip names, and `Body` already loads a track per clip
   from the id. Until they exist, `BoarAssetsBoot` warns `"0 of 10 boar clips have an animation asset
   id"` on every boot and `tests/server/boar_model.spec.luau` asserts that exact state.

**What the Builder did instead of waiting:** everything else. The model, the textures, the scale (two
uploads to find the rule, now a guard that fails the run), the flag, the weld, the clip decision, the
per-gait rates measured off the clips themselves, the specs, and a screenshot of the animal standing
on the box. The gaits cannot be looked at until step 5 is done, and the report says so.

### RESOLVED, 2026-10-03 — the Director published all ten

Creator: Karen. Studio → Animation Editor → **Publish to Roblox**, per clip. **No Curve-Editor
conversion was needed** (step 4 above is struck out and says why). Some clips were published twice by
a mis-click; the duplicates are unused and are deliberately **not** recorded — an id nothing reads is
an id nobody can account for.

```
Idle_1    82265692105692   Walk_F_IP  78821328262922   Trot_F_IP 131287194917750
Run_F_IP  80882224687243   Turn_L_IP  139483442990375  Turn_R_IP 88781568929523
Death_L   128792697872198  Death_R    88751192504828
Hit_F     91365202020290   Hit_B      80205641767239
```

**The Builder loaded every one of them back before writing it down** (`AnimationClipProvider:`
`GetAnimationClipAsync` in Edit, 2026-10-03), independently of the Director's own check. All ten
resolve, each clip's own name matches its row — and the read-back found **two things the ids alone
would not have**:

1. **Every clip's length was one frame too long in the config.** N frames at 24 fps span N−1
   intervals, so Idle is 4.167 s and not the 4.208 the frame count gave; all ten were out by exactly
   1/24 s. `Boar.CONFIG.MODEL.CLIPS` now carries the measured length, the manifest carries it as
   `clipSeconds`, `BoarAssetsBoot` warns if the two ever drift and `boar_model.spec` fails the build
   on it. The per-gait ground speeds were never affected — `tools/boar_prep.py` divides by the
   intervals it counted, not by the frame count.
2. **All ten were published `Loop = true`**, deaths and flinches included, because the publish dialog
   does not ask. `Boar.Body` now writes `AnimationTrack.Looped` from its own config **immediately
   before every `Play`**, not only where the track is built: a track takes `Looped` from the asset
   when the asset ARRIVES, which is after `LoadAnimation` returns, so a value written earlier can be
   overwritten by the load. A looping death would stand the carcass back up every 1.2 seconds in
   front of the player who just shot it.

Studio was left clean by the Director: the import rig, `RBX_MICROBONE_NODES` and
`ServerStorage.RBX_ANIMSAVES` all removed, no flag override set.

---
## 2026-10-02 · CLOSED 2026-10-02 · NEEDS DIRECTOR · Task 99: `test2` cannot stage `shoot-the-boar` -- a capability refusal in the harness, not in the game

**Raised by:** Builder, Task 99 round 2 (branch `task-99-new-gun`, code commit `1232022`).

**What is blocked:** the merge gate's `[harness2]` line, and therefore the review --
`tools/agents.py` refuses a review of an `src/` change without it. Nothing else: the one-player run
is green at the same commit.

```
[harness]  PASS: 34/34 checks @ 1232022 (clean tree)
[harness2] FAIL: 28/34 checks @ 1232022 (clean tree)
  FAIL [input] staged 1 scenario(s) (placed + aimed)  (shoot-the-boar: RuntimeError: execute_luau:
       ... The current thread cannot invoke 'LookAtRequest' since 'LookAtRequest' has additional
       values for the Capabilities property: LoadUnownedAsset (and 3 more))
```

**It is the harness's own step, and the four spec failures are its consequence.** The stage asks the
camera owner to aim by invoking the `BindableFunction` `PlayerScripts.Camera.LookAtRequest`
(`tools/studio_mcp.py`, "Staging a scenario"). Roblox refused the INVOKE on capability grounds, so
`shoot-the-boar` was never aimed -- and then `shoot_boar.spec` (2), `weapon_client.spec` (3) and
`zz_drive_boundary.spec` (1) failed waiting for a shot that never happened. The suites are otherwise
clean: 509 server and 101 shooter assertions passed.

**What is measured, and what is not.**
- REPRODUCIBLE: two consecutive `test2` runs at `1232022`, identical message, identical 28/34.
- ONE PLAYER IS GREEN at the same commit, and `test` stages the same scenario through the same
  function -- so it is not the camera, the request function or this task's diff. The difference is
  WHERE the call lands: in `test` the editor's own Play DataModel, in `test2` a separate Studio
  process that "Clients and Servers" started.
- `test2` was green at `f2b9667` earlier tonight, with the same staging code.
- NOT MEASURED: why the capability set differs. The most likely thing that changed in between is
  Studio's own session state -- this session used `execute_luau` to call
  `InsertService:LoadAsset` while reading the stock's colour map id, which is the first time this
  repo has asked the Assistant plugin for an asset capability. I did not verify that, and I am not
  going to guess further in a report.

**What I suggest, in order:**

1. Close Studio completely, reopen the DEV place (136410205938347) in **Edit**, press Rojo
   **Connect**, then `bash ../driven-hunt-runs/gate.sh task-99`. If that is green, the cause was
   Studio session state and this entry closes with that sentence.
2. If it fails the same way, it is a harness fault in the stage (rule 6) and wants its own task:
   the stage would have to reach the camera without invoking a BindableFunction, or the capability
   has to be granted to the plugin.

**DIAGNOSED, 2026-10-02 (Builder).** It is not the place and it is not this repo. It is the
Assistant plugin's own thread, and a `LoadAsset` call this session made through `execute_luau` is
what gave it capabilities.

Read-only measurements, all through `execute_luau` against the Edit DataModel:

| probe | result |
|---|---|
| `Capabilities` / `Sandboxed` on `game`, `ReplicatedStorage`, `ServerScriptService`, `StarterPlayerScripts`, and the modules `Gun`, `Shotgun`, `Viewmodel`, `Viewmodel.poses`, `Flags`, `Camera` | **every one empty**, `Sandboxed = false` |
| a brand-new `Instance.new("ModuleScript")`'s `Capabilities` | **empty** |
| plain property read | works |
| a plain Lua function the thread made, called | works |
| a `BindableFunction` the thread made, invoked | works |
| `require` of the synced `ReplicatedStorage.Shotgun` | **refused**: "The current thread cannot require 'Shotgun' since 'Shotgun' has additional values for the Capabilities property: LoadUnownedAsset (and 3 more)" |
| `require` of a ModuleScript **the thread had just created itself**, one line of source, parentless | **refused, identically** |

The last row is the one that settles it. A module the calling thread made a microsecond earlier, in
memory, cannot be required -- so nothing about OUR instances is the cause (and their `Capabilities`
are empty anyway). The THREAD carries `LoadUnownedAsset (and 3 more)`, and a capability-carrying
thread may not enter a container that grants none; the message names the target but the asymmetry
is the thread's. A full Studio close and reopen did not clear it, so it is attached to the plugin
context rather than to the place -- and Studio's own `LocalStorage/appStorage.json`
contains no `LoadUnownedAsset` entry, so wherever Studio keeps it, it is not there.

**What set it:** this session called `InsertService:LoadAsset(115346777423870)` through
`execute_luau`, to read the uploaded stock's `SurfaceAppearance.ColorMap` -- a property a game
script cannot read. That is the only new thing between `f2b9667` (both runs 34/34 tonight) and the
first refusal. **The prohibition is now in `tools/studio_mcp.py`'s Safety section with this
measurement**, and the id it was after lives in the manifest row (`Assets.textureId`) where it is
measured once and never asked for again.

**The clicks, in order. After each one, `python tools/flags.py` is the one-command test** -- it
goes through `FRESH_FLAGS`, which is a `require`, so it prints the flag table if the thread is
clean and the same capability message if it is not.

1. Studio -> **Assistant** settings -> turn the **MCP server OFF**, then **ON** again. That restarts
   the Assistant's plugin context, which is what carries the capability.
2. If still refused: **Plugins** tab -> **Manage Plugins** -> the Assistant / MCP plugin ->
   **Permissions** -> revoke its asset access. Restart Studio afterwards.
3. If still refused after both, it is not clearable by a click and wants its own task: every
   `require` the harness makes from `execute_luau` would have to stop crossing that boundary
   (`FRESH_FLAGS`, `QUERY_FLAG_TABLE`, `QUERY_REQUIRE_CACHE`, `QUERY_JSON_MODULES`) and so would the
   stage's `LookAtRequest:Invoke`. I did not start that here: it is a large change to the gate
   itself, and it would be the wrong fix if a click clears it.

**I did not save the place, and I have not called `LoadAsset` through `execute_luau` since.**

**Answer (Director, 2026-10-02).** Neither click cleared it: a full Studio close and reopen did
not, and the Assistant's MCP server toggle OFF and ON did not either, with no Studio update. So it
is the new normal for the MCP thread, and it was fixed in code instead -- **Task 101** (PR #90,
Reviewer PASS, merged into this branch at `b49ae77`) rewrote every harness, flags and pose path that
needed a module's VALUE so that none of them requires or invokes anything. The gate is green again:
`[harness2] PASS: 34/34` and `[harness] PASS: 32/32` at `b49ae77`.

**Closed** by Task 101, 2026-10-02.

---
## 2026-10-01 · CLOSED 2026-10-01 · NEEDS KAREN (or the Director's click) · Task 99: Studio is not connected to Rojo, so the gate cannot run

**Raised by:** Builder, Task 99 (branch `task-99-new-gun`, code commit `8db324e`).

**What is blocked:** every harness run, and the three screenshots the task asks for (`pose.py compare
carry`, `compare aim`, and the break-open with shells going in). Nothing else: the flag, the exact
geometry, the hinge, the chambers, the glove fix, the specs and the docs are all written, linted,
built and committed.

**Why it needs a click.** Moving between branches while `rojo serve` was live -- `task-98` to `main`
to `task-99`, which is what CLAUDE.md's git workflow step 6 warns about -- left the Studio plugin
disconnected. Measured, not guessed:

```
[harness] FAIL: 7/8 checks @ 8db324e (clean tree)
  FAIL Rojo synced the fresh token from disk  (Studio has '')
[harness] `rojo serve` answers, so the Rojo plugin is probably not connected: press Connect.
```

and, from a Play session started before the commit, Studio's own copy of the place is a build older
than Task 98:

```
Poses is not a valid member of ModuleScript "Players.<name>.PlayerScripts.Camera"
  Script 'Players.<name>.PlayerScripts.Camera', Line 32
```

So a Play session right now runs the pre-Task-98 camera. A screenshot taken from it would be a
picture of the wrong build, and I did not take one and call it evidence (rule 8).

**The clicks, in this order:**

1. In Studio, with the DEV place (136410205938347) open in **Edit** mode, open the **Rojo** plugin
   window and press **Connect**. Accept the sync dialog; the changes it lists are this branch's --
   `ReplicatedStorage.Gun` is new, and `Camera.Poses` arrives if it is still missing.
2. Then, in a terminal in the repo folder:

   ```
   python tools/flags.py clear
   python tools/pose.py clear
   bash ../driven-hunt-runs/gate.sh task-99
   ```

3. For the three pictures the task asks for, with the gate green and a Play session running:

   ```
   python tools/flags.py set NEW_GUN on     (Edit mode, BEFORE starting Play)
   [task 114, 2026-10-03: this flag is RETIRED -- the new gun is the only gun, so there is
    nothing to switch on and this line now fails. Kept as the record of what was asked for.]
   ... start Play ...
   python tools/pose.py compare carry --assets-dir <assets-dir>
   python tools/pose.py compare aim   --assets-dir <assets-dir>
   python tools/flags.py clear
   python tools/pose.py clear
   ```

**Answer (Director, 2026-10-01 23:33).** Connect pressed. Studio shows "Connected to session
'DrivenHunt' at localhost:34872". The gate and the captures are the Builder's to run from here.

**Closed** by the Director, 2026-10-01.

---
## 2026-10-01 · CLOSED 2026-10-01 · Director decision · Task 98: `FIRST_PERSON` ships ON, and the poses are seeded from Task 97 round 2

**Raised by:** Director, answering Reviewer finding 2 of Task 98 round 1 (and the background of finding 1).

**Authorisation.** On 2026-10-01 (~21:30 local) Karen approved the pose-data plan ("let's try") after the
Task 97 tuning loop. The plan she approved had three parts, and one of them was, as written: *FIRST_PERSON
default ON (Karen must see the current gun on every Play)*. The Director dispatched Task 98 with that as
item 4 and with item 1 saying: seed carry/aim from Task 97 round 2 (commit 9393d1e, closer to Karen's
target) if they read better, else main's. Both changes are therefore in scope and authorised.

**What it is not.** It is not a playtest OK of the poses. Those numbers are a starting point that the
Director now tunes live with `tools/pose.py` against `TARGET-*.jpg`, and Karen OKs the result from a
side-by-side (the content lane). The rollback for first person is the flag's `default = false` line.

**Closed** by the Director, 2026-10-01.

---
## 2026-09-27 · CLOSED 2026-09-27 · NEEDS KAREN · Task 75: the Rojo plugin is disconnected, so the harness and the in-game screenshots cannot run

**Raised by:** Builder, Task 75 (branch `task-75-barrel-shine`, code commit `58b3069`).

**What is blocked:** the 1-player harness, and the two in-game screenshots the task asks for (the gun
held in third person, and ADS). Nothing else: the tool fix, the re-prep, the upload, the manifest
change, the specs, the selftest and its two mutations are all done and committed.

**Why it needs a click.** I moved branches (`task-74` → `main` → `task-75`) while `rojo serve` was
live, which is exactly what CLAUDE.md's git workflow step 6 warns about. `rojo serve` still answers
on 34872, but the Studio plugin is no longer connected, and only a human (or the Director's click
tool) can press **Connect**. Measured, not guessed — Studio's own copy of the place still holds the
task-74 tree:

```
ServerStorage.Tests children = 24
TestSyncToken = ""
Assets.ROWS = 1 row(s); byKey modelId = 117134580332969   <- the OLD asset; this branch has 2 rows
```

Until it is connected, a Play session would load the old asset, so an in-game screenshot would be a
picture of the thing this task fixed. I did not take one and call it evidence.

**The clicks, in this order:**

1. In Studio, open the **Rojo** plugin window and press **Connect** (the DEV place, 136410205938347,
   must be open in **Edit** mode). Accept the sync dialog if it lists changes — they are this
   branch's: `ServerStorage.Assets` gains a second row.
2. Then, in a terminal in the repo folder:

   ```
   python tools/studio_mcp.py test
   ```

   and, because this touches `src/`, the Director's `test2` afterwards.

**What I would do next, unattended, once it is connected:** run the harness, take the two
screenshots, look at them, finish `reviews/task-75/REQUEST.md` with the PASS line and the honest
description, and report.

**RESOLVED 2026-09-27 by the DIRECTOR, not by Karen.** He pressed Connect himself ("Connected to
session 'DrivenHunt'"), and the harness then ran clean:
`[harness] PASS: 30/30 checks @ 6670402a382b40afea2d5ac1fe10f70307f5a4c0 (clean tree)`. Both in-game
screenshots were taken and are described in `reviews/task-75/REQUEST.md`. Nothing here needs Karen.

**Interim evidence that does not need the click** (Edit mode, daylight, both assets loaded side by
side at the exact size the manifest scales them to, then removed again):
`.screenshots/20260927T003817Z-task75-new-side.png`, `…-task75-old-side.png` and
`…-task75-new-side-b.png`. The old gun's barrels are bright mirror silver; the new gun's are
near-black with a thin highlight along the rib. Described in full in `reviews/task-75/REQUEST.md`.

---
## 2026-09-25 · CLOSED 2026-09-25 · NEEDS KAREN · Task 34: the 2-player harness mode needs one click to be exercised

**Raised by:** Builder, Task 34 (branch `task-34-harness-2p`). **Nothing is blocked**: the mode is
built, the one-player harness is green with it, and the 2-player spec runs in both modes. What is
missing is the only thing no tool here can do.

**Why it needs you.** StudioMCP's `start_stop_play` takes `is_start` and `studio_id` and **nothing
else** -- there is no player count anywhere in its tool schema -- so the harness cannot start a
Clients-and-Servers test. Everything after the click is the mode's own work.

**The clicks, and the one command, in this order:**

1. In a terminal in the repo folder, start the mode FIRST:

   ```
   python tools/studio_mcp.py test2
   ```

   It writes the gate token, prints these clicks, and then waits up to 180 s for the test windows.

2. In Studio, on **Driven Hunt DEV**: **Test** tab -> **Clients and Servers** -> **Players: 2** ->
   **Start**, within the **180 s** the mode waits. It no longer races a token: the disk token is
   cleared before the click and a fresh one is written into the running server afterwards, which is
   why there is no 120-second rule here any more.
3. Leave the three windows alone. The mode reads them: it finds which is the server and which are
   the clients, asks each client which team it is on, replays the input scenarios into the
   **shooter's** client, and collects all three reports.
4. When it says so, press **Cleanup** in the Test tab.
5. Paste the final `[harness2] ...` line under this entry, and the `[match_teams]` line from the
   server output just above it (it prints each player's name and team).

**CLOSED 2026-09-25.** The Director can now start and end the session himself
(`driven-hunt-runs/studio-key.ps1 F7` / `EndSession`), so this needs nobody's hands. Nine runs were
made; the last is the confirmation at `166bd33`:

```
[harness2] PASS: 28/28 checks @ 166bd334e576a84f324c5ca093e56af22ccb286b (clean tree)
[match_teams] 2 player(s): Player1=Shooters, Player2=Drivers | drivers=1 shooters=1 phase=Running
```

Server 234 passed / 0 failed, the shooter's client 58 / 0, the driver's report printed as an
observation. The runs also found the game bug Task 34 fixed: with two players the Shooter carried no
gun at all, for a whole drive.

**What the answer decides.** If it passes, ROADMAP 1.6 is closed and a two-player check is one
command away from then on. If a report is empty, the token window was missed -- just run it again.
If the studios are found but the classification is wrong, that is a real finding and the mode prints
what it saw.

---
## 2026-09-25 · CLOSED 2026-09-25 · Task 30: is a 2-player harness run possible at all?

**ANSWERED — yes, it is possible.** Karen ran Test -> Clients and Servers with 2 players and
`python tools/studio_mcp.py studios` listed **FOUR** studios: the DEV edit Studio
("Driven Hunt DEV (placeId: 136410205938347)") plus three unnamed ones - the local server and
the two clients. So the extra Studio processes DO register with StudioMCP and every tool takes a
`studio_id`, which is the route a 2-player harness would use. The Director has queued
**"harness runs specs with 2 players"** as its own task (`TASKS.md` row 33); it is not part of
Task 32. Reported by the Director, 2026-09-25.

**Raised by:** Builder, Task 30 (branch `task-30-harness-multiplayer`). **Nothing is blocked**: the
task is complete without this, and the answer only decides whether ROADMAP 1.6's automation is worth
a future task or should be closed.

**What is already known** (measured, `docs/research/2026-09-24-toolchain.md`, Task 30 addendum):
StudioMCP's `start_stop_play` takes no player count, and `execute_luau`'s `datamodel_type` is an enum
of `Edit` / `Client` / `Server` with no index — so one Studio cannot host a second addressable
client. **But every tool takes a `studio_id`**, and `list_roblox_studios` says "several instances are
commonly open at once". A local multi-client test starts extra Studio *processes*. If they register
with StudioMCP, a 2-player harness is possible; if they do not, 1.6's automation is closed for good.

**The exact clicks, once:**

1. In Studio, on **Driven Hunt DEV**, open the **Test** tab.
2. In the **Clients and Servers** group, set **Players** to **2**, leave the rest alone, and press
   **Start**. Two extra client windows open.
3. While they are running, in a terminal in the repository folder (`<repo>`), run exactly:

   ```
   python tools/studio_mcp.py studios
   ```

4. Paste the output under this entry. One line of JSON is the whole answer: if it lists **three or
   more** studios, a 2-player harness is feasible and deserves a task; if it lists **one**, it is not
   possible with this tool and `ROADMAP.md` 1.6 should say so.
5. Press **Cleanup** in the Test tab to close the extra windows.

**Note:** the harness's own tests do not run during that check, and nothing needs to be committed.
The MCP server must be on (Studio → Assistant settings), which it already is.

---
## 2026-09-25 · CLOSED 2026-09-25 · Task 22 cannot be reviewed: the round counter has no task boundary

**Raised by:** Builder, at loop step 5 of Task 22 (branch `task-22-playtest-ready`, code commit
`d265cab396b2a23b61c620fe9e6594f23b925211`, harness `PASS: 24/24 ... (clean tree)` on it).

**What happened.** `powershell -ExecutionPolicy Bypass -File tools/review.ps1` refused, verbatim:

```
[agents] REFUSED: `Round: 1` in REVIEW_REQUEST.md, but the committed REVIEW_RESULT.md is round 5
(FINDINGS), so this run must be `Round: 6`. The round is counted from the verdict file, not from the
request, so it cannot be raised or skipped here.
```

`Round: 6` would then hit the next check, `round 6 > 3: stop rule`.

**Why it is stuck.** `tools/agents.py` `cmd_review` computes
`expected = 1 if prev_rnd is None or prev_verdict == "PASS" else prev_rnd + 1`. The count restarts
only after a **PASS**. Tasks 17 and 18 ended on `FINDINGS` at round 5 and were merged anyway by
Director decision (the escalation above), so the verdict file on `main` says round 5 FINDINGS. Every
task branched from `main` from now on inherits that: round 1 is refused as too low and round 6 as too
high. This is not specific to Task 22 — **no task can be reviewed until it is resolved.**

CLAUDE.md counts rounds **per task** ("The loop, for every task ... increment `Round:`"); the script
counts them globally. That gap is the bug (rule 6: a harness fault is a bug and gets reported).

**What I did not do.** I did not touch `tools/agents.py`, and I did not set `DIRECTOR_MAX_ROUNDS`.
The Builder does not edit the gate that constrains it, and CLAUDE.md allows that variable only when
this file records the Director's authorisation for that task and that round. So Task 22 is built,
harness-green and pushed, and **unreviewed**.

**What the Director can choose.**
1. **One-off:** authorise here, for Task 22 round 6 only, and I re-run with
   `DIRECTOR_MAX_ROUNDS=6` and `Round: 6` in `REVIEW_REQUEST.md`. Unblocks this task; every later
   task hits the same wall one round higher.
2. **Fix the counter** (a Builder task of its own, reviewed like any other): restart the count at 1
   when the commit named in the committed `REVIEW_RESULT.md` trailer is an **ancestor of this
   request's `Base:`** — that is, when the verdict belongs to work already merged into the base this
   task branches from. It cannot be gamed by the Builder: resetting would require getting the
   failing commit merged first, and only the Director merges.
3. **Accept Task 22 unreviewed** on the harness evidence and the diff (one config constant plus
   comments and docs), and let the fix land with the next task.

My recommendation is 2, with 1 to unblock Task 22 in the same breath.

**Director's answer, 2026-09-25 (transcribed verbatim by the Builder from the dispatch):**

> DIRECTOR DECISION on the ESCALATE.md entry (review gate refuses round 1 after Tasks 17+18 merged on
> FINDINGS):
> - For Task 22 only: DIRECTOR_MAX_ROUNDS=6 and `Round: 6` are authorised (one review round). Record
>   this under the entry.
> - The real fix (per-task review files, round count per task) is Task 21, next. Do not change
>   tools/agents.py in Task 22.
> - Accepted: ServerStorage has a $path, so the Archive folder will go at the next Connect;
>   backups/2026-09-25_workspace-defaults.md is the rule-7 record. Good catch.
>
> Run the one review round now (policy: only real defects block; notes do not). If only notes: record
> PASS-with-notes as the Director's call in ESCALATE.md, close the entry, push. If a real defect: fix,
> harness, and with DIRECTOR_MAX_ROUNDS=7 one more round, then stop regardless.

**So:** this is the authorisation `tools/agents.py` requires, for **Task 22, round 6** (which is Task
22's first round). `DIRECTOR_MAX_ROUNDS` is set in the environment for that run only and is never
committed. `tools/agents.py` is untouched; the counter fix is Task 21. Entry **closed**; the outcome
of the round is recorded below.

**Outcome of the authorised round (round 6 = Task 22's round 1), 2026-09-25.** `REVIEW_RESULT.md`
line 1 is not `PASS`: the Reviewer returned **4 findings**, and **none of them is blocking under the
Director's policy for this round** (only a finding that makes the game, a test, an owner boundary or
security wrong blocks). All four are about documents:

| # | What | Disposition |
|---|---|---|
| 1 | `docs/research/2026-09-24-boar-ai.md` §4 still says, in the present tense, that the plate is coplanar with the default `Baseplate`; and claim 9 named 2 of the 3 stale mentions in `docs/design/boar-ai.md` | **Accurate. Not fixed here** — the research note is not on the merge gate's list of files that may change after the code commit (git workflow step 4), so fixing it now would put the harness PASS and this review out of date. Queued below |
| 2 | `TASKS.md` row 17 still poses "delete the Baseplate?" as Karen's open call and says two SpawnLocations exist | **Accurate, and not the Builder's row.** The Reviewer's own alternative applies: the Builder may write only its current task's status row, so row 17 is the Director's to close or strike through |
| 3 | `backups/2026-09-25_workspace-defaults.md` claims "every property ... recreated from it alone", but records the `Texture` and `Decal` children as counts only | **Accurate. Not fixed here** (same gate reason). The missing data is preserved verbatim below so it cannot be lost at Karen's next Connect, when Rojo removes `ServerStorage.Archive` |
| 4 | The request had no screenshot description a reviewer could read, for a change whose whole purpose is visual (rule 5) | **Fixed**: `REVIEW_REQUEST.md` now carries a `## Screenshots, inspected` section with all five views. `REVIEW_REQUEST.md` is on the gate's list, so this changes nothing about the evidence |

**The data finding 3 asks for, read from the place on 2026-09-25 before it can be lost** (both
children are still in `ServerStorage.Archive`; Rojo removes that folder at the next Connect):

- `Baseplate.Texture` — `Texture` `rbxassetid://6372755229`, `Face` `Top`, `StudsPerTileU` 8,
  `StudsPerTileV` 8, `OffsetStudsU` 0, `OffsetStudsV` 0, `Transparency` 0.8, `Color3` `0, 0, 0`,
  `ZIndex` 1.
- `SpawnLocation.Decal` — `Texture` `rbxasset://textures/SpawnLocation.png`, `Face` `Top`,
  `Transparency` 0, `Color3` `1, 1, 1`, `ZIndex` 1.

**Queued for the next task** (Task 21, or wherever the Director puts them): findings 1 and 3 — correct
the research note's §4 sentence, name all three stale mentions in the Architect design for its next
regeneration, and fold the two child-property lines above into
`backups/2026-09-25_workspace-defaults.md`, retitling that section to what it is. Finding 2 is the
Director's row 17.

There is **no round 7**: the Director authorised one more round only if a real defect appeared, and
none did.



---
## 2026-09-25 · CLOSED 2026-09-25 · Tasks 17+18: round 5 was the last authorised round, and it found 4 things

**Raised by:** Builder, at loop step 5 of the combined Tasks 17+18 (branch `task-18-boar-ai`, code
commit `b6cf3dec736347f65c42ad3d05129d302389349a`).

**Result.** `DIRECTOR_MAX_ROUNDS=5` authorised two rounds with real evidence. Both were used.
Round 4 returned **9** findings, round 5 returned **4**; all 13 are fixed, and **round 5's four are
unreviewed** because there is no round 6.

| Round | Commit | Findings | The one that mattered |
|---|---|---|---|
| 4 | `4432292` | 9 | **The "real arena" pathfinding test was testing the default Baseplate.** It never waited for `Workspace.TestArena`, so it ran before `ArenaBoot` had built anything — and its own output said so: 54 waypoints for a 210-stud route is a straight line with no detour, which I read past |
| 5 | `36b7c19` | 4 | **A whole failure class the diagnostic could not see.** `ComputeAsync` returning `Success` with no waypoint past where the boar already stands is counted as a failure by the Runtime, produces exactly the silent straight-line fallback the diagnostic exists to catch, and was recorded nowhere |

**What is unreviewed.** Round 5's four fixes:
1. `pathProblems` now counts `"success: no waypoints"` (about 10 lines in
   `Boar.defaultWorld().requestPath`), which is what makes the `world >= runtime` invariant rest on
   containment rather than coincidence.
2. A comment at the determinism test explaining why its `1e-9` is deliberately tighter than
   `EPSILON`.
3. `TASKS.md` row 18 and this file's Task-18 closure now name the reviewed code commit instead of
   `fbe1d60`, the first green run.
4. `REVIEW_REQUEST.md` rewritten fresh with one continuous claim numbering.

**Everything is green on the reviewed commit:**
`[harness] PASS: 24/24 checks @ b6cf3dec736347f65c42ad3d05129d302389349a (clean tree)` — 39 server
and 4 client assertions across five spec files. Lint, format and `rojo build` clean. Rule 5 met:
play-time screenshots captured and inspected.

**What these two rounds bought, plainly.** Rounds 1–3 reviewed this code with nothing ever executed
and passed over all of it: a test measuring the wrong world, a diagnostic with two blind spots, two
tests contradicting a feature they sat beside, and a tolerance tighter than float32. **Running it
once found three of those in ninety seconds.** The order the Director chose — harness first, then
review — is the reason this branch is worth merging.

**Options for the Director.**
1. **Accept on the record and merge.** The four unreviewed fixes are small, all of them make a
   diagnostic or a comment more honest rather than changing behaviour, and the full harness is green
   on the commit that contains them.
2. **One more authorised round** (`DIRECTOR_MAX_ROUNDS=6`), ~$2.80. On this branch's record it would
   probably find something — rounds 4 and 5 both did, and round 5 found a hole in a round-4 fix.
3. **Merge and queue the residue.** What is genuinely untested is listed in
   `REVIEW_REQUEST.md` "Could not verify" and in the research note's addendum §4: `Path.Blocked` has
   never fired, no real player has ever been a threat, `maxBoars` is never reached.

**Builder's recommendation: option 1, then option 3's residue as a queued task.** The remaining risk
is not in the code that was reviewed twice with evidence; it is in the paths nothing has exercised,
and a sixth reading will not reach those. A playtest with Karen and a second player will.

**Two things need Karen, both recorded in `TASKS.md` rows 17 and 18 and neither mine to change:**
the arena floor rendering as a triangle because it is coplanar with `Workspace.Baseplate`, and the
two `SpawnLocation`s during Play.

**Needs:** a Director decision. Karen's two calls are separate and not blocking this merge.

---

**Director decision 2026-09-25:** merged on the record. The Director read the only unreviewed code change after round 5 (`Boar.defaultWorld`: records "success: no waypoints" in the path-problem counter and returns nil, as before); it changes diagnostics, not behaviour. The harness PASS at `b6cf3de` stands.

## 2026-09-25 · CLOSED 2026-09-25 · FOR THE DIRECTOR · play-time `screen_capture` works; `TASKS.md` row 7 is wrong

**Raised by:** Builder, during the Tasks 17+18 harness run (branch `task-18-boar-ai`). This is not a
blocker — it **unblocks** something, and the queue is the Director's to edit, not mine (`CLAUDE.md`
Roles), so it comes here rather than into row 7.

**`TASKS.md` row 7 says:** "**BLOCKING before any visual client code (UI, HUD, cursor art):**
play-time screenshots | todo | StudioMCP's `screen_capture` is edit-time only, so rule 5 cannot be
met for play-time visuals by tools."

**That is wrong, and it has been wrong since Task 5.** `screen_capture` **does** work during Play. I
captured three play-time screenshots of the arena and the boar through MCP on 2026-09-25, inspected
them, and they are the rule-5 evidence for both tasks.

**The cause of the mistake was mine, in `tools/studio_mcp.py`.** `Studio._call` builds its return
value as

```python
text = "\n".join(c.get("text", "") for c in result.get("content", []))
```

— it joins **only the `text` content blocks**. `screen_capture` returns an **image** block
(`mimeType: image/jpeg`, base64), and no text at all, so `_call` returns an empty string. My first
attempt read that empty string as "capture is unavailable during Play". Calling `tools/call` directly
and keeping the image blocks returns the JPEG.

**What follows, for the Director to decide:**
1. **Row 7 is not blocking any more**, at least not for this reason. Whether it closes or becomes
   "wire capture into the harness" is a queue decision.
2. **A harness change would make this routine**, and it is small: one `capture` command that calls
   `screen_capture` and writes the image to a file. But `ROADMAP.md` speed rule 1 freezes tooling
   after Task 11, so I have not written it. Today's captures were taken by a throwaway script in the
   scratchpad, which means **rule 5 currently costs a hand-written script each time**.
3. **The `_call` text-only join is a latent trap for any future image-returning tool** (`store_image`,
   `generate_texture`, `generate_mesh` are all in the MCP tool list). Worth a one-line comment in
   `studio_mcp.py` at minimum, which is also a tooling change.

**Needs:** a Director decision on row 7 and on whether the harness gets a `capture` command. Nothing
here needs Karen.

---

**Director decision 2026-09-25:** agreed. TASKS.md row 7 is updated: play-time capture works; the remaining work is making `tools/studio_mcp.py` keep image blocks so the harness can save captures.

## 2026-09-24 · CLOSED 2026-09-25 · Task 18 reached round 3; the script refuses a fourth

**Raised by:** Builder, at loop step 5 of Task 18 (branch `task-18-boar-ai`, stacked on
`task-17-test-area`). Overnight, no-Studio mode.

**Result.** Three review rounds, 16 findings, all fixed. Round 3's four are fixed in the commit that
carries this entry. `tools/review.sh` refuses `Round: 4` (`MAX_ROUNDS = 3`) and the round count is
taken from the committed verdict, so I cannot get a `PASS` on the fixed commit.

| Round | Commit | Findings | Of which real defects in code or specs |
|---|---|---|---|
| 1 | `ad35852` | 6 | 3: `Path.Blocked` documented but not implemented (and a `Path` rebuilt per request); the anti-stuck turn was dead code; `boar_body.spec` would have failed on its first run because it measured the spawn drop as walking speed |
| 2 | `732c74a` | 6 | 4: the anti-stuck fix still did nothing (the slew undid it); the new stuck test was vacuous; the landing guard was vacuous; **and a real gameplay bug — an idle boar could despawn itself as "escaped" with no driver anywhere, because `spawnPoint` was 130 studs from the exit line while `HOME_RADIUS` is 120** |
| 3 | `e821aa4` | 4 | 2: the control case for the stuck test was vacuous (the control boar ran over the exit line and went `GONE` on tick 64, so the window measured nothing); the reaction assertion was 0.5 s where the design specifies 0.25 s, which would have hidden a doubling of `SENSE_INTERVAL` |

**What this says about the work, honestly.** The anti-stuck behaviour took three attempts and its
tests took three. Two of my three "fixes" for it did not work, and I asserted in writing that each
one did. The same claim about who constructs a `Brain` was wrong in all three rounds. None of this
would have been caught by lint, and **none of it can be caught by running anything, because nothing
in this task has ever executed** — `rojo serve` is down until Karen presses Connect. The Reviewer is
currently the only thing standing between this code and the game.

**What is now unreviewed.** Round 3's four fixes: the control-case rewrite (the boar now circles at
radius 30 instead of running off the map, and the test asserts it is still alive), the 0.25 s
reaction bound, the research-note addendum §3 rewritten to record all four departures from the
design rather than two, and claim 1 in `REVIEW_REQUEST.md`.

**State.** Code commit `4fa3db2bfc92c6521e13d44799e8e48ead9b888a`, clean tree. `selene src`, `selene --config tests/selene.toml tests`,
`stylua --check src tests` and `rojo build -o build/place.rbxl` all pass — the commands CI runs.
**No harness run, no screenshot, nothing executed.** Branch pushed; no PR opened (the Director does
that).

**Options for the Director.**
1. **One authorised round 4** (`DIRECTOR_MAX_ROUNDS=4`), as for Task 11. Round 3's findings were two
   vacuous tests and two documentation bounds — not the "documentation-only" case your standing rule
   names, since a vacuous test is a defect. Cost ~$2.50.
2. **Merge on the record**, accepting that the last four fixes are unreviewed. I would not recommend
   this here: unlike Task 11, the unreviewed changes are *test* changes, and the pattern of this task
   is that my test fixes have been wrong more often than my code.
3. **Hold Task 18 until Karen connects Studio (~09:00), then run the harness first and review after.**
   Everything blocking is the same blocker: nothing has run. A harness run would settle more than a
   fourth reading would — in particular the `LinearVelocity` plane setup, the `Path.Blocked` index
   arithmetic and whether either spec even loads.

**Builder's recommendation: option 3, then option 1 if the harness turns up nothing.** The cheapest
real information available is a single harness run at 09:00, and it costs nothing but Karen's click.
A fourth reading of code that has never executed has clearly diminishing returns — rounds 2 and 3
each found that my *previous* fix was wrong, which is exactly what running it would have told me in
seconds.

**Needs:** a Director decision. Karen's Connect click is already requested in the Task 17 entry
below; nothing further is needed from her for this.

### DIRECTOR's answer · 2026-09-25

**Option 3, then option 1: harness first, then review with real evidence.** Karen connected on the
morning of 2026-09-25, so the cheapest information became available and was taken first.
`DIRECTOR_MAX_ROUNDS=5` is authorised **for this run only** — up to two more rounds on the combined
Task 17 + Task 18 change, which is now one unit on `task-18-boar-ai`.

**The Director was right that a harness run would settle more than a fourth reading.** It did. The
first real run gave **35 passed, 3 failed, 3 errors**, and all three failures were things no amount
of re-reading had found:

| Failure | What it actually was |
|---|---|
| `boar_body` "used real pathfinding" — `pathFailures` 31, expected 0 | **The spec asserted the wrong thing.** `Enum.PathStatus.NoPath` on the spec's own plate floating at y = 500. An Edit-mode probe settled it: the same agent parameters at y = 0 return `Success` with 54 waypoints from `CONFIG.spawnPoint` to the exit line. Pathfinding works where the game plays |
| `boar_brain` "never accelerates faster than ACCEL" | **A tolerance tighter than float32 can be.** Measured overshoot 1.9e-6 against a 1e-6 tolerance |
| `boar_brain` "never turns faster than TURN_RATE" | **Two of my own tests contradicted each other.** Both held the boar at a fixed position for 300 steps; standing still for 2 × `STUCK_TIME` is by definition stuck, so the anti-stuck branch turned it 90° in one tick — the very behaviour the neighbouring test asserts |

**Closed** 2026-09-25 by the Director.

---

## 2026-09-24 · CLOSED 2026-09-25 · NEEDS KAREN · `rojo serve` crashed; Task 17 cannot be tested

**Raised by:** Builder, at loop step 3 of Task 17 (branch `task-17-test-area`, code commit
`48169db`). Overnight run, Karen asleep.

**What happened.** The Task 17 code is written and committed. The harness then failed at check 3:

```
  FAIL Rojo synced the fresh token from disk  (Studio has '')
[harness] `rojo serve` is NOT running (crashed?). Known Rojo 7.7.0 bug ...
[harness] FAIL: 3/4 checks @ 48169db32effaa1d4b8f0995dbf7df106f0d8f46 (clean tree)
```

Confirmed independently: `tasklist` shows no `rojo.exe`, nothing is listening on port 34872, and
`curl http://localhost:34872/api/rojo` returns nothing. Studio is still open on the DEV place in
**Edit** mode and the MCP server still answers, so only Rojo is down.

**Why.** Almost certainly the known Rojo 7.7.0 crash already in `CLAUDE.md` ("Known Rojo 7.7.0
crash": it panics when a watched file or folder disappears before it processes the event,
[#1309](https://github.com/rojo-rbx/rojo/issues/1309),
[#1321](https://github.com/rojo-rbx/rojo/issues/1321)). Rojo was alive at the start of this run — two
`rojo.exe` processes, and a read-only MCP probe worked. It died across
`git switch main && git pull` (59 commits) and `git switch -c task-17-test-area`, which deleted and
rewrote many watched files at once. **New data point for that note: a large branch switch is enough to
crash it**, not only a test deleting a folder. `CLAUDE.md` currently says to stop `rojo serve` before
switching branches; this run shows why, and the Task 17 dispatch forbade stopping it. Worth folding
into `CLAUDE.md` on the next task.

**Why I stopped rather than fixing it.** Two overnight rules, both explicit: never stop or restart
`rojo serve`, and if Rojo is down write a NEEDS KAREN entry and stop. Restarting it would not be
enough anyway — the Rojo plugin's **Connect** button cannot be clicked by any tool, so Karen has to
press it before the harness can run again.
## 2026-09-24 · CLOSED 2026-09-24 · Task 20 round 2 returned 5 findings; the Director's limit was two rounds

**Director decision (2026-09-24 ~23:50):** option 1, accepted on the record. The five unreviewed fixes are wording and source labelling; none changes a conclusion or a number. The Architect reads the note fresh when it designs the map generator. Merged by the Director with main (paperwork conflicts resolved by keeping both sides).

**Raised by:** Builder, at loop step 5 of Task 20 (branch `task-20-map-research`, code commit
`6cd9a84`). Documents only.

**Result.** Two review rounds, 11 findings, all fixed. Round 2's five are fixed in the commit that
carries this entry, and **they are unreviewed**: the dispatch said "max 2 rounds", and unlike
`MAX_ROUNDS` that is a Director instruction rather than something the script enforces, so I have
stopped rather than run a third.

| Round | Commit | Findings | What they were |
|---|---|---|---|
| 1 | `fba85c8` | 6 | the seed/determinism story did not work (`math.noise` has no seed, so seeding a `Random` answered nothing); the maths library was a source in everything but name; three broken section references; a false "one-to-one" claim; `ESCALATE.md` in the change but in no claim; the Director's dispatch paraphrased rather than transcribed |
| 2 | `41e9069` | 5 | **a new broken section reference inside my fix for the broken section references**; the source count corrected in one place and not two others; the "two table rows" summary corrected in one copy and not the other; the decisive finding resting on two unnamed sources (the MCP tool list, the community threads); the mesh limits presented as first-party when §9 itself calls them community/vendor figures |

**What this says about the work.** Round 1's finding 1 was the valuable one — it caught a real muddle
that would have been copied into a design, not a citation slip. But the pattern across Tasks 19 and
20 is now unmistakable: **I fix the instance I am shown rather than the class.** Round 2 found that
two of my round-1 fixes were themselves wrong in exactly the way the originals were. The one thing
that worked was mechanical: for round 2 I audited *every* section reference in the file against the
actual headings programmatically — 13 headings, zero unresolved — instead of hand-fixing the three I
was handed. That check should have existed in round 1.

**State.** Code commit `6cd9a84`, clean tree. The note has 13 sources, every section reference
resolves, the Director's dispatch is transcribed verbatim in `TASKS.md`, and the `NEEDS KAREN` entry
for `rojo serve` is on this branch. Lint, format and `rojo build` pass — unchanged by this task,
which touches no code. **No harness run** (nothing executes; Rojo is down), **no screenshot**
(nothing visual), **no Architect design** (the dispatch was research only).

**Options for the Director.**
1. **Accept on the record.** The five unreviewed fixes are: one section reference, one source count
   in two places, one summary sentence, two sources promoted from prose to numbered entries, and one
   "these figures are community, not first-party" label. None changes a conclusion or a number; the
   note's findings and targets are the same before and after.
2. **One authorised round 3.** ~$1.60. It would confirm the fixes, and on this task's record it
   would probably find something — rounds 1 and 2 both did.
3. **Regenerate nothing.** There is no design to regenerate here; the Architect was not run, by
   dispatch.

**Builder's recommendation: option 1, with one caveat.** The note is input to a future
`tools/architect.sh design map-generator`, not something built from directly, and the Architect will
read it with fresh eyes. The caveat is that I would not describe this note as *verified* — see the
long "Could not verify" list in `REVIEW_REQUEST.md`, of which the largest items are that
`math.noise`'s stability is undocumented and unmeasured, that `CollectionService` tag persistence is
unconfirmed, and that every number in the targets table is arithmetic rather than measurement.

**Needs:** a Director decision. Nothing here needs Karen beyond the Connect clicks already requested
in the `NEEDS KAREN` entry below.
## 2026-09-24 · CLOSED 2026-09-24 · Task 19 round 2: a Reviewer finding I believe is factually
wrong, and a contradiction I may not fix myself

**Raised by:** Builder, at loop step 5 of Task 19 (branch `task-19-shotgun-design`, code commit
`0f5627f`). Two separate things, both from review round 2 — the Director's limit for this task.

### 1. Round 2's finding 1 is factually wrong, and the evidence is reproducible

The finding says my addendum's `docs/PROJECT_CONTEXT.md` line numbers "are all wrong", and that of the
design's four citations only `:592` is "genuinely wrong".

Checked three independent ways at commit `009c20e`, on a clean tree — `awk` over the working tree,
`grep -n` over the working tree, and `grep -n` over `git show HEAD:docs/PROJECT_CONTEXT.md`. All three
agree:

| Quote | Actually at | Round 2 says | Design cites | Verdict on the design |
|---|---|---|---|---|
| "Two systems wrote the creature's position" | **34** | 36 | `:36` | wrong |
| "Three scripts set the mouse cursor" | **32** | 34 | `:33-34` | wrong |
| "one predicate answered two unrelated questions" | **32-33** | 34-35 | `:34-35` | wrong |
| "a visibility audit ignored parent visibility …" | **30-31** | 32-33 | `:30-31` | **correct** |

Round 2's numbers are uniformly **two lines later** than the file reads, which inverts its conclusion:
`:592` is the **only correct** design citation, not the only wrong one. My addendum's numbers
(`:34`, `:32`, `:32-34`, `:29-31`) were correct or contained the quote; they are now exact.

I cannot explain the offset. The Reviewer reads a `git worktree` of the same commit, which should be
byte-identical, and `docs/PROJECT_CONTEXT.md` is 48 lines of ASCII with no BOM and has not been
touched by this branch. **If the Reviewer's worktree really does differ from the commit, that is a
harness fault and far more important than this task** (rule 6). Someone with Studio down but git
working should run `git show 009c20e:docs/PROJECT_CONTEXT.md | grep -n` and compare.

Round 1's finding 10 was wrong the same way on two of its four replacements, and **I copied it into
the addendum instead of checking it** — which is how a wrong correction got two rounds of life. That
is my error, and it is the reason `CLAUDE.md` has the "you believe a finding is factually wrong" stop
rule at all.

### 2. The note and the design contradict each other on the slug cone, and I may not fix it

`docs/design/shotgun.md` §9: "Slug cone | 0.16° **half-angle**". The note: "**0.16° full cone**
(0.08° half-angle)", with the arithmetic. The buckshot row beside it in §9 is a **full** angle, and
§11.1 specs the pattern as "within the configured **half-angle** of the aim". So a `ShotgunConfig`
built from §9 as written produces a cone at 2× or 0.5×. Round 2's finding 4 is right that this ships
two documents disagreeing on a load-bearing number.

Rule 3 gives `docs/design/` and `ARCH_RESULT.md` to the Architect and the Builder never edits them, so
I have recorded all three design defects in `TASKS.md` row 19 and in the note's addendum rather than
touching the files. Round 2 asked for either a regeneration or this entry; this is the entry.

**Options for the Director.**
1. **Re-run `tools/architect.ps1 design shotgun`** on the corrected note. ~$2 and a few minutes. It
   would fix all three defects at once and re-derive its own citations — but it returns an
   **unreviewed** design, and this task has no rounds left to check it.
2. **Accept the documents as they are**, with the three defects recorded in `TASKS.md` row 19, and
   regenerate the design when the boar branches are merged — which it needs anyway, because
   `ARCH_RESULT.md` item 3 says the Architect could not see them and therefore cannot guarantee one
   writer for the damage entry point.
3. Waive the two-round limit for one more review round.

**Builder's recommendation: option 2.** The design has to be regenerated once the boar work is
visible regardless, and doing it twice costs two sessions to fix three citation-level defects that
are already written down where the next Builder will read them. Nothing is blocked in the meantime:
Task 1.4's code is blocked on Director decisions 13.1–13.3 anyway.

**Needs:** a Director decision on 2, and someone to sanity-check 1 — if the Reviewer's worktree
differs from the commit, that is a harness bug.

### DIRECTOR's answer · 2026-09-24

**1. The Builder is right about the line numbers.** The Director checked
`git show 009c20e:docs/PROJECT_CONTEXT.md`: the quotes are at **34, 32, 32-33 and 30-31**, exactly as
the Builder reported. **Round 2's finding 1 was wrong by two lines**, and not fixing it was correct.
Why the Reviewer's numbers were off — an evidence copy that differs from the commit, or a miscount —
is logged as a **before release** item in `TASKS.md`. The working rule already covers the practical
risk: `REVIEW_REQUEST.md` cites **files and symbols, not line numbers** (`CLAUDE.md` loop step 4).

**2. Task 19 is accepted on the record**, as documents only. **The shotgun design will be
REGENERATED by the Architect once Tasks 17 and 18 are merged**, and that regeneration fixes the
half-angle / full-cone unit defect and names the damage entry point owner. **Until then the design is
not built from.** So the Builder's recommendation (option 2) is taken, and the three design defects
recorded in `TASKS.md` row 19 are the handover list for that regeneration.

**3. The Architect's three blocking decisions are answered:**
- **(a) Task 6 lands BEFORE the shotgun build. No waiver.** The smallest version is the one the
  design proposes: one scenario, one key, one client spec.
- **(b) Accepted:** the shotgun first ships on the **default camera, with no ADS and no viewmodel**.
  Third-person-to-first-person aim comes as **its own camera task with its own design, right after**,
  because Karen wants it in v1. So the design's §3.3 cut stands, and it is a sequencing decision, not
  a scope cut.
- **(c) The damage entry point owner is decided in the regenerated design** (see 2).

**4. Karen's five feel questions keep their defaults** until her playtest.

**Closed** 2026-09-24 by the Director.

**Still open, and not part of this entry:** the `NEEDS KAREN · rojo serve is down` entry below.
Karen has not connected yet, so Tasks 17, 18 and 19 still have no harness run.

---

## 2026-09-24 · CLOSED 2026-09-25 · NEEDS KAREN · `rojo serve` is down; no task can be harness-tested

**Raised by:** Builder, during Task 20 (branch `task-20-map-research`).

`rojo serve` crashed on 2026-09-24 during Task 17 and has not run since: no `rojo.exe`, nothing
listening on port 34872. It is the known Rojo 7.7.0 watched-file panic, and on that occasion **a
large branch switch alone was enough** — `git switch main && git pull` across 59 commits, no test, no
**Raised by:** Builder, during Task 19 (branch `task-19-shotgun-design`).

`rojo serve` crashed on 2026-09-24 during Task 17 and has not run since: no `rojo.exe`, nothing
listening on port 34872. It is the known Rojo 7.7.0 watched-file panic, and on that occasion **a large
branch switch alone was enough** — `git switch main && git pull` across 59 commits, no test, no
deletion. Studio itself is still open on the DEV place in **Edit** mode and its MCP server still
answers; only Rojo is down.

Per the overnight rules I have not restarted it, and restarting alone would not be enough: the Rojo
plugin's **Connect** button cannot be clicked by any tool.

**Why this entry is repeated on this branch.** The same entry exists on `task-17-test-area`,
`task-18-boar-ai` and `task-19-shotgun-design`, but none of those is merged, so anything cut from
`main` — including this branch — has no record of why no task can produce a harness line. Task 19's
review round 1 caught me citing it from a branch where it did not exist. **The claim and the record
have to live in the same place**, so it is written here too. When the branches merge, these copies
collapse into one.

### Exact clicks for Karen, in order

1. Open a terminal (PowerShell or Git Bash) in the repository folder
   (`<repo>`).
**This entry exists on this branch because it was missing here.** Tasks 17 and 18 carry the same
entry, but they are on unmerged branches, so on `main` and on anything cut from it there was no record
of why no task has a harness line — which review round 1 of this task caught (finding 1). The harness
claim and the record must live in the same place.

### Exact clicks for Karen, in order

1. Open a terminal (PowerShell or Git Bash) in the repository folder (`<repo>`).
2. Run, and leave the window open:

   ```
   rojo serve default.project.json
   ```

   It should print that it is serving on `localhost:34872`. If `rojo` is not found, run
   `rokit install` first.
3. In Roblox Studio, with **Driven Hunt DEV** open in **Edit** mode: the **Plugins** tab → **Rojo** →
   **Connect**.
4. Rojo may show a confirmation dialog listing instances it will remove. It is expected to list
   nothing outside the Rojo-owned containers. **Do not accept anything that names
   `Workspace.Baseplate` or `Workspace.SpawnLocation`** — those are yours and must stay (rule 7).
5. Nothing else. The Builder takes it from there on the next run.

**State of the work.** Branch `task-17-test-area`, code commit `48169db`, pushed. Clean tree.
`selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests` and
`rojo build -o build/place.rbxl` all pass locally (the same commands CI runs). **Not run:** the
harness, the Reviewer, and the screenshot — all three need Rojo connected. Nothing in this task has
been executed in Studio, so nothing about it is verified beyond lint and build.

**Also found, read-only, before Rojo died** (useful whoever picks this up):
- `Workspace` already holds a default **Baseplate** (`Part`, 2048×16×2048 at y = -8, so its top face
  is at **y = 0**) and a default **SpawnLocation** (12×1×12 at (0, 0.5, 0)). Both anchored, both Studio
  content, both left alone (rule 7, and the dispatch says to report them).
- That means two things the Director should look at once the arena can actually be seen:
  1. **The arena's ground surface is also at y = 0, so it is coplanar with the Baseplate's top over
     the whole 400×400 footprint.** That usually z-fights. I have not seen it — no screenshot was
     possible — so I am not claiming it does or does not.
  2. **Two SpawnLocations** will exist during Play: the default one at the origin and the arena's
     `ArenaSpawn` near the south edge. Roblox picks between them, so spawning will be inconsistent.
- `screen_capture` **is** available over MCP (`capture_id` + `studio_id`, optional `camera_position` /
  `look_at_position`), so rule 5 is satisfiable in Edit mode. The arena is built at server start, so
  it only exists during Play; whether `screen_capture` returns the Play viewport is untested.

**Needs:** Karen's clicks above. Then the Builder reruns the harness, the review loop, and the
screenshot.

### RESOLVED · 2026-09-25

Karen connected on the morning of 2026-09-25: the Director started
`rojo serve default.project.json` and Karen pressed **Connect**. Two `rojo.exe` processes are up,
Studio is on the DEV place in **Edit** mode and answering over MCP, and the harness has run green on
this branch. The first green run was
`[harness] PASS: 24/24 checks @ fbe1d6049da35f75675d532ee77d0c4f6992a235 (clean tree)`;
review rounds 4 and 5 then changed code three more times, and the line that covers the
reviewed commit is
`[harness] PASS: 24/24 checks @ fe21a0df30dc60e4d873157b1bd4821173b36b80 (clean tree)`,
43 tests across five spec files.

**Tasks 17 and 18 have now been executed**, and rule 5 is met for both: three play-time screenshots
were captured through MCP and inspected (see `TASKS.md` rows 17 and 18 for what they showed).
Task 19's and Task 20's documents still cite no harness line, correctly — they contain no code.

**Closed** 2026-09-25.

---

**Closed by the Director 2026-09-25:** same outage as the Task 17 entry; Karen pressed Connect in the morning.

## 2026-09-24 · CLOSED 2026-09-24 · Task 11 round 4 (authorised) returned 5 findings
3. In Roblox Studio, with **Driven Hunt DEV** open in **Edit** mode: the **Plugins** tab → **Rojo**
   → **Connect**.
4. Rojo may show a confirmation dialog listing instances it will remove. It should name nothing
   outside the Rojo-owned containers. **Do not accept anything that names `Workspace.Baseplate` or
   `Workspace.SpawnLocation`** — those are yours and must stay (rule 7).
5. Nothing else.

**What is waiting on those clicks.** Task 17 (test arena) and Task 18 (boar AI) have never been
executed at all — no harness run, no screenshot. Tasks 19 and 20 are documents only and need nothing
from Studio, but they cannot cite a harness line either, which is why both say N/A and point here.
executed at all — no harness run, no screenshot. Task 19 is documents only and needs nothing from
Studio, but it cannot cite a harness line either, which is why it says N/A and points here.

**Needs:** Karen's clicks. Nothing here needs the Director.

---

## 2026-09-24 · CLOSED 2026-09-24 · Task 11 reached round 3; the script refuses a fourth

**Raised by:** Builder, at loop step 5 of Task 11 (branch `task-9-agent-workflow`, PR #4).

**Situation.** Three review rounds ran. Nothing failed three times; each round found different
things, and every finding was fixed.

| Round | Commit reviewed | Verdict | What it found |
|---|---|---|---|
| 1 | `0362ee0` | 6 findings | the merge gate was unsatisfiable; the 3-round rule was self-reported; Task 11's extra scope had no record in the repo; the agent prompt was read from the working tree; the KAREN row never said she does not merge; the Layout table was stale |
| 2 | `20334d5` | 2 findings | both on round 1's fix to the round count: it was called tamper-proof but restoring the `NONE` placeholder would reset it; and `parse_trailer` took the **first** trailer-shaped line, so a Reviewer quoting an older trailer would set the round (a real bug I introduced) |
| 3 | `c36b22e` | 2 findings | both stale sentences in `REVIEW_REQUEST.md` claim 19, which I failed to update when I updated claims 24–25: it still said "the committed `REVIEW_RESULT.md` is round 1" and "which only this script writes". **No finding against the code.** |

All ten findings are fixed and committed. The round-3 two are fixed in the commit that carries this
entry; claim 19 now matches `tools/agents.py:31-34` and `CLAUDE.md:90-91`.

**Why I stopped.** `tools/review.sh` refuses `Round: 4` (`MAX_ROUNDS = 3`, `tools/agents.py:52`), and
the round is now counted from the committed `REVIEW_RESULT.md` trailer, so I cannot reset it — that is
the hardening round 2 asked for, and going around it is exactly what `CLAUDE.md` "What is enforced and
what is policy" forbids. So there is no way for me to obtain a `PASS` on the fixed commit. Per the
stop rule I wrote `ESCALATE.md` and stopped: **no Architect audit was run** (loop step 6 needs a PASS),
and nothing was merged.

**What is and is not verified.**
- Verified: the harness passes 24/24 on a clean tree at every code commit
  (`6378a07`, `9fe442c`, `b32ac5f`, and the final `be9d045`:
  `[harness] PASS: 24/24 checks @ be9d0453ac84a48b5f8c759901e95d239c0c34b6 (clean tree)`); lint,
  format and `rojo build` are clean; the round-count logic was exercised by hand across six states
  (see `REVIEW_REQUEST.md` claim 25).
- `be9d045` is after round 3's review. It adds `ESCALATE.md` to the merge gate's paperwork list in
  `CLAUDE.md` git-workflow step 4, which had omitted it — so this PR would have failed the gate it
  introduces. One line, unreviewed, and listed here because it is.
- Not verified: **there is no Reviewer `PASS` for this branch.** The last verdict is round 3 with two
  findings, and the fix for them is unreviewed.

**Options for the Director.**
1. **Authorise one more round** for this task, and record it. That means either raising `MAX_ROUNDS`
   for this run or accepting a reset, both of which are Director decisions, not mine. Cost: one more
   paid Reviewer session (rounds 1–3 cost $1.63, $2.16, $1.91).
2. **Accept the branch without a round-4 PASS**, on the record above: round 3 found nothing against
   the code, and its two findings were documentation errors in `REVIEW_REQUEST.md` that are now fixed.
   This breaks rule 10, so it has to be a written Director decision.
3. **Split Task 11** as round-1 finding 3 suggested: the Task 9 review in one PR, the merge-policy
   and `NEEDS KAREN` edits in another. A smaller change would review faster, but it re-runs all three
   rounds on two branches.

**Builder's recommendation: option 1.** The change is small and the outstanding delta is two sentences
in a review request. A fourth round confirms them and gives the branch a real `PASS`, which options 2
and 3 do not (2 skips it; 3 pays for six rounds).

**Also needed:** a standing decision on `MAX_ROUNDS`. Round 3 spent a whole paid session on stale text
in the Builder's own document. If the rule is meant to stop *repeated failure on the same item*, the
script should count that, not total rounds — but changing it is a workflow change and belongs in a
task of its own, not here.

**Needs:** a Director decision. Nothing here needs Karen.

### DIRECTOR's answer · 2026-09-24

**Option 1: one more review round (round 4) is authorised, for Task 11 only.**

- **Mechanism, kept minimal.** `tools/agents.py` reads an optional environment variable
  `DIRECTOR_MAX_ROUNDS` (integer, default `MAX_ROUNDS` = 3). It may be set **only** when this file
  records a Director authorisation for that task and that round. Round 4 of Task 11 is that
  authorisation. The change itself goes into the round-4 review.
- **Standing decision.** `MAX_ROUNDS` stays 3. The Director may authorise **one** extra round when the
  last round's findings were documentation-only; otherwise escalate as now. The round counting is
  **not** to be reworked — tooling is frozen (`ROADMAP.md` speed rule 1). This closes the Builder's
  "Also needed" question at the end of the entry: no, the script keeps counting total rounds.
- **No Architect audit for Task 11.** New speed rule (`ROADMAP.md` on `main`, PR #7): audits run every
  ~5 tasks, not per task. Loop step 6 is skipped for this task by Director decision, and `TASKS.md`
  row 11 records that.
- **Accepted:** the merge gate naming the reviewed **code commit** and allowing only loop paperwork
  after it. Good call.
- If round 4 fails: fix it, write an `ESCALATE.md` entry and stop. Do **not** ask for round 5.

**Closed** 2026-09-24 by the Director.

---

## 2026-09-24 · CLOSED 2026-09-24 · Audit-002 must-fix items are outside Task 10's scope

**Raised by:** Builder, at loop step 6 of Task 10 (branch `task-10-lint-test-globals`, head
`24fd22a` + the audit commit).

**Situation.** Task 10 (audit-001 L5) passed review in 2 rounds (`REVIEW_RESULT.md`: PASS on round 2).
The one-per-task Architect audit (`docs/architecture/audit-002.md`) returned 5 must-fix items
(`ARCH_RESULT.md`). I checked the evidence for each and believe all 5 are **valid**, but **none is in
Task 10's change**:

| # | Must-fix (audit-002) | Where it belongs | Decision needed? |
|---|---|---|---|
| 1 | Typed property values (Vector3, CFrame, Color3…) fail as "cannot compare", so no positioned geometry can come from disk | harness (`tools/studio_mcp.py`), before the first grey-box geometry | **Yes, partly design.** Either support typed values in the harness, or decide that geometry lives elsewhere (Workspace built in Studio; templates as `.model.json` with typed values). The Architect owns the structure; this probably needs `tools/architect.sh design geometry-on-disk` first |
| 2 | The unmanaged scan checks only scripts, so a Studio-made non-script instance in a Rojo-owned container passes, then vanishes at the next Connect | harness | No: Builder work |
| 3 | `tools/agents.py` (the four-agent gate) has no research note (rules 1, 2, 9) | Task 9 | No: Builder work |
| 4 | The Architect audits blind: earlier audits are not on this branch (audit-001 is only on PR #2) and are not in its evidence | Task 9 (`tools/agents.py` evidence), and PR #2's merge order | No: Builder work, plus merge order |
| 5 | `ARCH_RESULT.md`/`REVIEW_RESULT.md` got a Builder-written `NONE` placeholder, although only the scripts may write them; nothing ties a verdict to the merged commit; a dirty-tree audit writes an unqualified verdict | Task 9 | No: Builder work |

**The conflict.** CLAUDE.md's loop says "must-fix → fix, back to 4". Rule 4 says "one task per round, nothing
extra", and PROJECT_CONTEXT.md warns that big multi-item rounds hid failures. Folding 5 unrelated fixes
into Task 10 would make it a multi-item round about the harness and the workflow, not about L5. Choosing
between those two rules is a scope decision, so it is the Director's.

**Builder's proposal.**
- Close Task 10 as done (its own change passed review).
- Queue audit-002 must-fix items as five separate small tasks, 11–15 in `TASKS.md`, each through the full
  loop, **all before any game code**. Suggested order: 5, 4, 3 (they fix the workflow itself), then
  2, then 1 (after an Architect design for geometry on disk).
- Merge order suggestion: PR #2 (audit-001) early, so every later branch has `docs/architecture/`.

**Needs:** a Director decision (and Karen, if item 1's geometry question touches how she wants to
build the map).

### DIRECTOR's answer · 2026-09-24

Accepted as proposed, with one task added in front. Task 10 is **closed as done**: its own change
passed review. The five must-fix items become their own tasks, each through the full loop, all before
any game code, in this order (see `TASKS.md`):

| # | Task |
|---|---|
| 11 | Review Task 9 itself through the loop, and fix the findings |
| 12 | audit-002 #5: only the scripts write the verdict files; each verdict is tied to a commit; a dirty-tree audit verdict is marked as such |
| 13 | audit-002 #4: the Architect sees earlier audits |
| 14 | audit-002 #3: research note for `tools/agents.py` |
| 15 | audit-002 #2: detect Studio-made **non-script** instances in Rojo-owned containers |
| 16 | audit-002 #1: typed property values. **BLOCKED** on Karen's map decision (build the map in Studio, or everything on disk). Architect design first |

**Standing decision for every future audit.** A must-fix item **outside** the current task's change is
queued as its own task in `TASKS.md` and listed in the Builder's report. It is not an escalation, and it
is not fixed in the current task. Must-fix items **inside** the change are fixed as the loop says.

**Closed** 2026-09-24 by the Director. No open escalations remain.

#### Task 11's dispatch, verbatim (transcribed by the Builder, 2026-09-24)

The Director dispatched Task 11 in the same message, outside the repo. Its scope is more than
"review Task 9", so it is recorded here rather than inferred from a Builder-written `TASKS.md` row
(review round 1, finding 3):

> TASK 11: Task 9 (the four-agent workflow, PR #4) never went through the loop itself. Do that now.
> 1. Work on branch task-9-agent-workflow (PR #4). First merge origin/main into it (a merge, not a
>    rebase; no force pushes) so it is current with main.
> 2. Also in this task, update CLAUDE.md to the new policy: the Director (agent) retargets and merges
>    PRs after Reviewer PASS on the PR head, green CI and a clean-tree harness PASS naming that
>    commit; Karen no longer merges; the Builder still never merges. Update the KAREN and DIRECTOR
>    rows and the git-workflow section to match. Also add the stop case "a human action is needed
>    (Rojo Connect, Studio MCP toggle, anything only Karen can click)": write it in ESCALATE.md headed
>    "NEEDS KAREN" with the exact clicks, then stop.
> 3. Run the loop on the whole Task 9 change (git diff origin/main...HEAD) plus the edits above:
>    REVIEW_REQUEST.md, tools/review.sh, fix, repeat until PASS. Then one Architect audit; handle its
>    items per the standing decision above.
> 4. Push task-9-agent-workflow. Then merge task-9-agent-workflow into task-10-lint-test-globals
>    (merge, no rebase) and push, so PR #5 stays current. Put the ESCALATE.md answer and TASKS.md rows
>    on whichever branch lands first (task-9), not only on task-10.
> 5. If Studio is not in Edit mode, Rojo is not connected, or the MCP server is off, and you cannot
>    fix it yourself: NEEDS KAREN entry, stop.

**Builder's note on item 2.** "Reviewer PASS on the PR head" as written cannot hold: loop steps 5 and
6 commit `REVIEW_RESULT.md`, `ARCH_RESULT.md` and the audit document *after* the reviewed commit, so
the head always moves past it (review round 1, finding 1). The gate in `CLAUDE.md` git-workflow step 4
therefore names the **code commit** and bounds what may follow it (paperwork only). Same intent,
satisfiable. Flagged to the Director in the Task 11 report.

---

## 2026-09-27 — Task 79 (M2.8e, the map switch): the flag and the PLACE contradict each other

**Builder → Director. A decision is needed; the code half is built, tested and merged-dark, and the
place half cannot be finished as specified.**

### What was asked

Task 79 dispatch, point 2: *"With the flag OFF the arena must still build and every existing spec
pass while the map sits in Workspace (prove the two worlds do not interfere: positions, spawns, boar
field)."*

### What happened, measured

The code half is done and green: `MAP_V1` is declared `default = false`, `Map` gained pure selectors
over a boolean, `ArenaBoot` and `Boar.CONFIG` read the flag at their own boundaries, and
`map_contract.spec` drives both worlds by parameter. With **no map in Workspace**:

```
[harness] PASS: 32/32 checks @ 0c29687e284422803b36dde57827b8e207e47c3f (clean tree)
[tests:server] PASS: 424 passed
note [server] task79: MAP_V1=false, world=arena, boar field x[-200,200] z[-200,200] exitZ=-190,
               arena=built, map=absent
```

Then the map was built into the place — `mapgen.py build --seed 1 --backup census`, **274/274 steps,
digest `e064d598…deae5`, 6,393 parts, 3,381,368 terrain cells**; `contract OK`; `reachability OK`
(every BoarSpawn and the DriverStart reach the line); all nine shots taken and inspected. With the
map in Workspace **and the flag still OFF**, the same commit:

```
[harness] FAIL: 22/27 checks @ 0c29687… (clean tree)
[tests:server] FAIL: 413 passed, 11 failed, 11 errors
  map_contract.spec:118  the arena is the world but Workspace holds DrivenHuntMap
  map_contract.spec:132  the world is the arena but Terrain holds 3381368 cell(s)
  map_contract.spec:163  the rough material is (126,122,78) but the arena world wants (111,126,62)
  map_contract.spec:197  Expected 8 shooter posts, got 16
  match_live.spec:137    Expected value "nil" to be non-nil
```

**The fourth one is not a spec being fussy — it is a gameplay collision.** Both worlds tag their
markers with the same `Map.TAGS` strings, so `CollectionService:GetTagged("DrivenHunt.ShooterPost")`
answers **16**, two drive lines, two driver starts and eight boar spawns. `Match.Markers` reads those
tags. A drive with the flag off would place shooters on map posts 700 studs away.

The place was restored afterwards (`mapgen.py clear` → `removed 9157, cellsAfter 0, paletteRestored
true`) and the harness is green again at the same commit.

### Why this is a decision and not a bug

`docs/design/map-generator.md` §17 never contemplated a place holding both worlds: step 4 saves the
map and step 6 commits `EXPECTED_WORLD = "map:v1"` **together**. The Director's one change — merge
dark behind a flag — separates them, and that is what creates the both-present state, because **the
flag lives in code and the map lives in the PLACE**. A flag cannot make 6,393 parts and three million
terrain cells absent.

Three ways out, none of which the Builder may choose alone:

1. **Filter by world root.** `Match.Markers` (and the spec's exclusivity checks) resolve tags only
   inside the named world's root — the `taggedInside` helper `map_contract.spec` already has. Fixes
   the collision and `match_live`. **Does not fix the palette**: the saved place keeps the autumn
   terrain colours, so with the flag OFF the grey-box arena sits on an autumn-coloured world for
   every playtest. Karen would see that, and §8.4/audit-004 called a leftover palette "a world nobody
   chose".
2. **Do not save the map until Karen accepts.** The place stays arena-only, everything above stays
   green — and the flag-on playtest has no map to walk, which is the point of the task.
3. **Switch by commit after all, as §17 wrote it** — EXPECTED_WORLD flips in the same commit that
   saves the place, and the feel gate is Karen's walk on a branch rather than a flag. This is the
   design's own shape and gives up "merge dark" for this one task.

**Recommendation: 1 plus an explicit decision about the palette** — it is the only option that both
merges dark and gives Karen a map to walk. It needs `Match.Markers` changed (its owner is the drive,
not this task's) and it needs somebody to say that an autumn-coloured arena is acceptable while the
flag is off. Option 3 is the cheapest if "merge dark" is worth less here than the design's simplicity.

### What is NOT blocked

The code half is committed and green and merges dark on its own: with no map saved, `MAP_V1` on or
off changes nothing a player can see, because the map does not exist in the place. Nothing here has
to be reverted whichever option is chosen.

### And one thing that was never reached

**`NEEDS SAVE`.** §17 step 4 (Karen's `File → Save to Roblox`, or the Director's Alt+Shift+S) and
step 5 (reopen, `contract` again = measurement B) were never requested, because the map had to be
cleared again to leave the place usable. When the decision above is made, the save is still a human
action and still the only way the map reaches the place.

### RESOLVED — Director decision, 2026-09-27

Verbatim:

> **DIRECTOR DECISION on your ESCALATE.md entry: OPTION 3 — switch by commit, exactly as
> docs/design/map-generator.md §17 wrote it. Reason: the world lives in the place, not in code, so a
> flag that cannot be turned off without failing 11 specs and misplacing shooters is not a feature
> flag; option 1 adds permanent marker-filtering code for a temporary state.**

Done in `0c29687`'s successor on `task-79-map-switch`: the `MAP_V1` row and both of its reads are
gone (archived nothing — it never merged, so there is nothing to archive under rule 7),
`Map.EXPECTED_WORLD` is `"map:v1"` with §17 step 6's data beside it, `Boar.CONFIG.field` carries the
same corridor as a literal by its own owner, and `ArenaBoot` and `MatchBoot` branch on the committed
string. `CLAUDE.md`'s "Feature flags" section now names the exception. `tests/server/test_arena.spec`
is **branched, not archived** — §17 step 9 archives it only after Karen accepts, and a spec that was
deleted cannot check a rollback.

## NEEDS KAREN — 2026-09-27, Task 79: the map save has never been read back

The generated map reached the place with **one human keystroke**, Alt+Shift+S (File → Save to
Roblox), posted by the Director with Studio in Edit mode and the built map in view. **Studio showed
no confirmation dialog**, so the save is **SENT, not verified**. Nothing a tool can run reads
Roblox's copy of a place, and `python tools/mapgen.py contract` answers `OK` for the Edit session
that was saved — the same DataModel, not proof it landed.

`docs/design/map-generator.md` §17 step 5 asks for exactly this readback (its "measurement B"), and
it needs a **reopen**, which the Director will not do tonight: reopening the place drops `rojo serve`
and the Studio MCP link, and recovering both needs Karen's **Connect** click.

**The clicks, in order, at Karen's 10:00 session:**

1. Open **Driven Hunt DEV** (PlaceId 136410205938347) in Studio, in **Edit** mode.
2. Press **Connect** in the Rojo plugin (Karen's click; `rojo serve` must be running).
3. Studio → Assistant settings → **MCP server enabled**.
4. Then the Director runs `python tools/mapgen.py contract` and compares the marker digest with
   **`e064d5982513a08616d2bf367f61c30c`**, and the counts with 8 shooterPost, 1 driveLine,
   1 driverStart, 4 boarSpawn, 12 tree.

If the digest matches, §17 step 5 is complete. If the place comes back empty, the map did not save
and `python tools/mapgen.py build --seed 1` rebuilds it byte-identically from the committed seed —
nothing is lost but the keystroke.

Recorded as `TASKS.md` 79a(j). The code half does not wait on this: `[harness] PASS: 32/32 @ 6ddb54e`
is a run against the map in that Edit session.

## 2026-10-02 — Task 112: `test2` fails twice on the same two cases, and it is the TIE

**Builder, task 112 round 2.** `bash ../driven-hunt-runs/gate.sh task-112` was run twice on
`ca572f7abab976547f27b391d0b8c7eac06d841b`. Both times:

```
[harness]  PASS: 33/33 checks @ ca572f7abab976547f27b391d0b8c7eac06d841b (clean tree)
[harness2] FAIL: 33/35 checks @ ca572f7abab976547f27b391d0b8c7eac06d841b (clean tree)
```

Both failures are in `tests/client/weapon_client.spec.luau`, a file this task does not touch:
`:585` ("equips on the cue and starts full") and `:914` (the readout). The run's own notes say why:

```
weapon_client: no quiet gun to test: equipped=false open=false busyFor=0.00 since input=114.7 s
weapon_client: this shooter is tied to a tree, so he has no gun to forge against
weapon_client: shots seen: ... 3 gun(s) handed over [+0.0s hand, +54.8s backpack, +54.8s backpack]
```

The shooter is TIED during the drive, which takes his gun to the backpack at +54.8 s, and the specs
run after that. **This is the third time it has appeared** — task 108's `test2` failed on exactly
these two cases with the same notes and passed on a re-run; task 111 was a one-player gate, so it was
never asked. It is not random now: it reproduced twice in a row.

**What I think is happening, and I am not certain:** it is a race between the client spec suite's
start and the tie at ~55 s. Tasks 108, 111 and 112 each added a client case to
`tests/client/gun_client.spec.luau`, which runs BEFORE `weapon_client.spec` alphabetically, and each
case costs a few tenths of a second; the suite has been creeping toward the tie. If that is right,
the next task pushes it further whatever it changes.

**Decision needed.** I am not fixing it inside task 112: it is not this task's code, the fix is in
the scenario or the suite's timing, and guessing at it would be a change nobody asked for in a file
no finding names. Either:
- it gets its own task (make the tie not take the gun before the specs run, or run
  `weapon_client.spec` before the tie); or
- the Director accepts the one-player line for task 112 and records why (the change is viewmodel,
  flash, and a sound the old gun cannot reach — none of it is a second client's business).

Task 112's work is committed and pushed; `reviews/task-112/REQUEST.md` says the same thing. The
review cannot run until this is decided, because `tools/agents.py` asks for the `[harness2]` line.

**DIRECTOR'S ANSWER, 2026-10-02 (transcribed by the Builder; CLOSED).** (1) The `test2` tie failure
is a HARNESS fault -- the suite outgrew the drive's tie timing -- and not a reason to accept a
one-player line; fix it in the test setup, smallest honest way, no gameplay change, and the gate must
be green on both lines. (2) The shot sound is Audioscape's "AS_shotgun_shot-01",
`rbxassetid://99008924129683` (Roblox-provided library audio, not an upload). (3) Keep the halved
smoke; Karen tunes it live.

**WHAT THE BUILDER DID, AND WHY IT IS IN `weapon_client.spec` AND NOT IN `Match`.** The shooter is
not tied by chance: the LAST scenario in `tests/client/input_scenarios.txt` is `tie-the-driver`,
which exists FOR `ClientTests.zz_tie_to_a_tree.spec` and ties him on purpose. So pardoning ties for
the run -- the test-only Match config the decision offers first -- would take the tie away from the
one spec whose whole subject it is. The two failing cases are the ones that assumed an equipped gun
AFTER that scenario had run:

* "equips on the cue and starts full" waited on `Weapon.get().equipped` and then said, one line
  down, that `Weapon.get()` is the wrong thing to ask because "the scenario has moved on". It now
  reads the equip off the LOG, like the "starts full" half beside it. The claim is about the
  BEGINNING of the session, and the log is where the beginning is kept.
* "reads out the barrels" now accepts an EMPTY readout when there is no gun in hand, which is what
  the case next to it already says in its own note ("no quiet gun to test ... tied to a tree").
  Anything that is not empty must still match the shape.

No gameplay file is touched, `Match` is untouched, and `zz_tie_to_a_tree.spec` still gets its tie.

## 2026-10-04 · OPEN · Task 117: round 3 failed — a 4th round needs Karen's authorisation

**Raised by:** the Director, during the overnight autonomous run (Karen, 2026-10-03: "you need to work
now atonomous and take decission until tomorrow morning").

**What failed.** Round 3's one blocking finding (`reviews/task-117/RESULT.md`): `tools/boar_prep.py`'s
offline selftest still asserts `check("ten clips", len(DEFAULT_CLIPS), 10)` while the task grew the
tuple to sixteen clips, so CI's `Build and lint` is red on PR #108 (verified by the Director: two
failing runs on the branch). Round 1 and 2 findings were real code/test defects and were fixed.

**Why the Director did not authorise round 4.** CLAUDE.md allows one extra round only when the last
round's findings were documentation-only. This one is a test assertion, so the rule does not allow it,
and the Director will not bend it. The fix itself is one line.

**Decision needed (Karen):** authorise one extra round for Task 117 (`DIRECTOR_MAX_ROUNDS=4`, this
task, round 4 only), or say how else to proceed.

**Meanwhile:** Task 118 (behaviour) is built as a stacked branch on `task-117-calm-boar`; it does not
touch `tools/boar_prep.py` and does not fix this line. It cannot merge before 117.

**KAREN'S ANSWER, 2026-10-04 (CLOSED by authorisation).** Asked "allow one extra round for Task 117?",
Karen answered, verbatim: "yes". So Task 117 may run **round 4, and round 4 only**, with
`DIRECTOR_MAX_ROUNDS=4` set for that one review and never committed. A failing round 4 is a new entry,
not a request for round 5.

## ~~NEEDS KAREN - the rifle's scope mount rings (task 146, 2026-10-10)~~ CLOSED, DROPPED BY KAREN (task 148, 2026-10-10)

**No upload is needed.** Karen retired the open-sighted rifle itself -- *"please remove rifle without scope so we don't implement now"* -- so the gun whose sight picture the rings were framing no longer exists. The scoped rifle wears them as it always has, which is correct. The whole entry is kept below for the day the open-sighted rifle comes back (`backups/2026-10-10-rifle-open-sights.md`), and task 147's measurement stands: it needs face-level surgery and a cap in Blender, not a different split.

Karen, playing: *"when aiming without scope remove righs (scope holding rings)"*. With the open
sights (key 3) the front mount ring sits DEAD CENTRE of the sight picture -- `.screenshots/
t146-open-aim.png` -- so it frames the view she is trying to aim through.

**IT CANNOT BE DONE IN CODE OR DATA.** The rings are inside the uploaded `rifle.action` mesh. The
split plan (`tools/gltf_split.py`, plan `rigby`) reads:

    stock  <- Wood_Low
    action <- Midden2_Low, Barrel_Low, Circle_Low, Vijsjes_Low, Trigger_Low, Safety_Low, TriggerHandle_Low
    bolt   <- Midden1_Low
    scope  <- Scope_Low, ScopeKnop_Low

`Vijsjes_Low` is 3196 triangles reaching `y +0.2916` -- scope height -- and it is in the **action**
group, which both rifles wear. Nothing in the viewmodel can hide part of a MeshPart.

**THE FIX IS ONE LINE AND TWO UPLOADS.** Move `Vijsjes_Low` from the `action` group to the `scope`
group and re-split: the SCOPED rifle wears action + scope and looks exactly as it does today, and the
open-sighted rifle wears the action alone and has no rings. It costs the screws elsewhere on the open
rifle (trigger-guard pins), which are a few pixels.

**THE CLICKS, IN ORDER:**

1. The Builder re-splits and produces the two new `.glb` files (no approval needed -- they are
   written outside the repo).
2. **Karen says OK to the upload** -- `assets/uploads.json` records her words, per CLAUDE.md.
3. `tools/roblox_upload.py` uploads the new `rifle.action` and `rifle.scope`, and the manifest rows
   in `src/serverstorage/Assets/init.luau` take the new ids.
4. A moderation wait, then a look at both rifles.

Everything else in task 146 shipped without it.


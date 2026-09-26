# Task 43 — Milestone 2.1: the first map slice

Task: 43
Round: 1
Base: `eb0b23e` (task-41-evidence-seams; stacked on 38, 36 and 35, none merged)
Code commit: `7d04836e500245efa285e0756b7275d6b2e74a23`

Harness, clean tree, one player:

    [harness] PASS: 27/27 checks @ 7d04836e500245efa285e0756b7275d6b2e74a23 (clean tree)

Harness, clean tree, two players (the Director's new gate, `src/` is touched):

    [harness2] PASS: 30/30 checks @ 7d04836e500245efa285e0756b7275d6b2e74a23 (clean tree)

Generator, clean tree, same seed twice:

    [mapgen] OK: 22/22 steps @ afb983a8208edbaff329625bd4f6f845f28ec16d seed=7 digest=87abf2678bfa13bdbe3e936fb34c1d0582b1109f8aef56492de14bff476add99 (clean tree)
    [mapgen] build 1: digest=87abf26…dd99 parts=153
    [mapgen] build 2: digest=87abf26…dd99 parts=153

`afb983a` is the commit the map was built from; `7d04836` adds the research note, the owner rows and
the task rows and changes no generator code (`git diff --name-only afb983a..7d04836`).

## What changed

The first map slice, built to `docs/design/map-generator.md` (v2). The slice is an **edit-time
artefact and not the world**: `Map.EXPECTED_WORLD` is still `"arena"`, the grey box is still what a
player stands in, and it is cleared out of Workspace before a harness run.

Also, carried from Task 41's notes in commit `67027ed` (before the map work): 41a(a), the retry the
new report loop lost, and the Director's decision that `test2` is part of the merge gate — written
into `CLAUDE.md`, the harness docstring and `tools/agents.py`'s `harness_gate`.

## Claims

1. **The contract has no run-time writer, and the tag strings live in one place.**
   `src/shared/Map/init.luau` is frozen data (`Shotgun.deepFreeze`). Nothing assigns to it: `grep -rn
   "Map\.[A-Z_]* *=" src` finds only the file's own definitions. `src/server/TestArena.luau` and
   `src/server/Match/Markers.luau` now read `Map.TAGS` instead of writing `"DrivenHunt.ShooterPost"`
   out again, and `MapGen.Markers` reads the same table.

2. **Nothing in the generator can run in a game session.** Every file under
   `src/serverstorage/MapGen/` is a ModuleScript that only defines and returns; `map_contract.spec`
   asserts `ServerStorage.MapGen` exists and that **every descendant is a `ModuleScript`**, and
   `MapGen.verifyContract` asserts it again from the tool's side.

3. **One writer per system inside the generator** (`GAME_DESIGN.md`'s new row). `Ground` is the only
   module in the repo that touches `Terrain` (`grep -rn "Terrain" src` — `Ground.luau` and comments),
   `Props` the only writer of `…Map.Props`, `Markers` the only caller of `CollectionService:AddTag`
   in the generated map (`grep -rn "AddTag" src`), `Settings` the only writer of
   `Workspace.StreamingEnabled`.

4. **The pure core is pure and deterministic, and the spec proves it without Studio.**
   `Height`, `Layout`, `Scatter`, `Digest` and `Assets` touch no Instance, no service and no Terrain
   (`Scatter` uses `Random.new(seed * 1000 + layer)`, one generator per layer; `Height` uses none at
   all). `tests/server/map_contract.spec.luau` drives them in the ordinary harness run: same seed →
   same heights and the same 50 tree positions, a different seed → a different field and a different
   wood, the digest stable under reordering and sensitive to a tenth of a stud.

5. **The live world still satisfies the contract it names.** The same spec asserts: exactly one of
   `TestArena` / `DrivenHuntMap` exists and it is the one `EXPECTED_WORLD` names; every tag resolves
   to exactly `Map.EXPECTED_COUNTS`, all inside that root and nowhere else; one drive line whose
   `LookVector:Dot(Vector3.zAxis) > 0.99`; every boar spawn inside `Map.FIELD.bounds` and within
   `SPAWN_PAD.tolerance` of `groundY`; a `PathfindingService` path from every spawn and from the
   driver start to the line **using `Boar.CONFIG.AGENT`**; no script under the root; and
   `Boar.CONFIG.field` equal to `Map.FIELD`. 296 server specs pass (274 before).

6. **The generator actually built the slice, and the same seed builds the same map.** 22/22 steps:
   16 terrain tiles at 24,576 voxels each, a hedgerow, the dirt track, 50 trees, the five tagged
   marker kinds plus 12 tie trees, the streaming step. 153 parts. Two full builds of seed 7 produced
   the same 64-hex digest over 153 instances **and 4,096 terrain samples** (`mapgen.py verify`).

7. **`tools/mapgen.py` refuses before it touches anything.** Edit mode and the DEV place; a dirty
   tree for every mutating command; Studio's copy of `MapGen` and `Map` differing from disk (it reuses
   `compare_synced` from the harness rather than copying it); no usable backup; no `--seed`. The M2.1
   `--backup census` prints Workspace's children and proceeds only if they are `Terrain`, `Camera` and
   the map root — otherwise it stops with a `NEEDS KAREN` Save-to-File block. Try:
   `python tools/mapgen.py build --seed 7` (refused: no backup), `… --backup census` on a dirty tree
   (refused), `python tools/mapgen.py plan` (read-only, writes nothing).

8. **Two measured facts changed the code, and both are written down** (research note, "Measurements,
   Milestone 2.1"). (a) Studio's require cache survives between `execute_luau` calls and a Rojo sync
   does not clear it — `build` twice reported a tree count from a `Config.luau` the file no longer
   held. Every call now requires a parentless **clone** of `ServerStorage.MapGen`, and `MapGen.Contract`
   does the same for `ReplicatedStorage.Map`, which is reached by absolute path. (b) Four of the five
   streaming properties are **not reachable from Luau** and `Workspace.StreamingEnabled` was **already
   `true`**: the contract now says `true` rather than turning streaming off, because flipping it would
   change client behaviour for every existing system and that is M2.6 with a playtest.

9. **Six screenshots, taken by `mapgen.py shots` in Edit and looked at** (`.screenshots/map-*.png`,
   rule 5). Honestly: the **ground** reads as farmland — `map-track` is a pale dirt track through tall
   grass with a tree line on the horizon, and `map-corridor` is an open lane toward a wood edge. The
   **props do not**: `map-stand` is two green boxes on brown stalks, which is what a proxy is, and the
   hedgerow reads as a low dark wall. And there are no fields yet — one material over everything
   outside the track — so the slice reads as one big meadow, not as European farmland. Queued as row
   43a(a) and (b); M2.2 and M2.3 are the tasks that answer them.

10. **Nothing was left in the place.** The slice is cleared before the harness (`mapgen.py clear`,
    then `census` shows `Camera` and `Terrain` only), which is what lets `map_contract.spec`'s "exactly
    one world" check mean anything. No `.rbxm`, no `.model.json`, no typed value: every number is plain
    Luau (design section 7, `TASKS.md` row 16 stays queued).

## What I could not verify

* **Measurement B — do tags survive a save and a reopen — is NOT made.** It needs File → Save to File
  and a reopen of the place: two clicks no tool in this repo can make. The fallback if they do not
  survive is already named (markers by folder and name; only `Match.Markers` changes). A `NEEDS SAVE`
  note is left for the Director with the slice rebuilt in the place, ready to be saved.
* **Reproducibility across engine versions.** Verified *within* one session only; that is what
  `verify` can see. The named fallback (seeded value noise inside `Height.luau`) is unchanged.
* **The memory half of measurement D.** Studio's own totals drifted upward across three samples
  regardless of content, so an Edit session cannot weigh 100 parts against its own noise. The part
  count is exact — two parts per tree, so 3,000 trees is 6,000 parts, inside `Map.BUDGET.parts` — and
  the memory question belongs to M2.3, with real meshes in a Play session.
* **`Props.template`** — the `InsertService:LoadAsset` route and the section 8.4 script refusal — is
  written but **never exercised**, because `Assets.ROWS` is empty. Queued as row 43a(d).
* **Whether the farmland reads as European farmland.** Only Karen can answer that; claim 9 is what I
  can see, not a verdict.

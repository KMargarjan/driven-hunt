# Task 43 — Milestone 2.1: the first map slice

Task: 43
Round: 3
Base: `eb0b23e` (task-41-evidence-seams; stacked on 38, 36 and 35, none merged)
Code commit: `87cdf86d63d010d2c5c48b6b03de5d1d766e8ae2`

Harness, clean tree, one player:

    [harness] PASS: 27/27 checks @ 87cdf86d63d010d2c5c48b6b03de5d1d766e8ae2 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me (standing rule since round 2: the
Builder never runs `test2` itself, because my own run dirtied the tree by editing this file while it
was live):

    [harness2] PASS: 30/30 checks @ 87cdf86d63d010d2c5c48b6b03de5d1d766e8ae2 (clean tree)

300 server specs, 70 shooter-client, 64 driver-client. 274 server specs before this task.

Generator, clean tree, same seed twice — three lines from one
`python tools/mapgen.py verify --seed 7 --backup census` run (not consecutive: 22 step lines and a
run-log line sit between them), each verbatim:

    [mapgen] build 1: digest=43dc6aeb77cde44d85221353fbd7a4c582b1109f8aef56492de14bff476add99 parts=146
    [mapgen] build 2: digest=43dc6aeb77cde44d85221353fbd7a4c582b1109f8aef56492de14bff476add99 parts=146
    [mapgen] OK: same seed twice, same digest @ 895300ea8e4969654eb52749efd5d906093e1a23 seed=7 digest=43dc6aeb77cde44d85221353fbd7a4c582b1109f8aef56492de14bff476add99 (clean tree)

`895300e` is the commit the map was built from. `87cdf86` differs from it only in `TASKS.md`
(`git diff --name-only 895300e..87cdf86`), which is why the harness lines name `87cdf86` and the
generator line names `895300e`. The digest's second half —
`82b1109f8aef56492de14bff476add99` — is byte-identical to the one round 2 produced: the terrain did
not move when the hedgerow gained its gate, only the marker half did.

## What this task is

The first map slice, built to `docs/design/map-generator.md` (v2). It is an **edit-time artefact and
not the world**: `Map.EXPECTED_WORLD` stays `"arena"`, the grey box is still what a player stands in
and still the rollback, and the slice is cleared out of Workspace before a harness run.

Also carried here from Task 41's notes, in commit `67027ed`, before the map work: 41a(a), the retry
the report loop lost, and the Director's decision that `test2` is part of the merge gate — written
into `CLAUDE.md`, the harness docstring and `tools/agents.py`'s `harness_gate`.

## Claims

1. **Every marker is metadata, not a gameplay object.** `Markers.place` builds each of the five kinds
   `Anchored`, `CanCollide = false`, **`CanQuery = false`**, `CanTouch = false`, `Transparency = 1`
   (design §4.3). `CanQuery` is the load-bearing one: `Weapon.Cast.world` builds `RaycastParams` with
   an Exclude filter and no `RespectCanCollide`, so a `CanCollide = false` part still stops a pellet —
   before this round the 340-stud `DriveLine` lay across the shooter line and would have eaten shots.

2. **The hedgerow has a gate, and the drive corridor is walkable.** `Scatter.hedgeGate(config, seed)`
   picks a centre inside `SLICE.corridor` from the `Scatter.LAYER.hedge` generator the design names
   (§5.3); `Layout.hedgerow(config, gate)` drops every segment whose *edge* would reach into it;
   `Layout.hedgeGap` measures the clear span that resulted. Three specs in
   `describe("the generator's hedgerow")` assert it **for twenty seeds**: the gate is inside the
   corridor and at least `gateStuds` wide, no segment reaches into it, and the same line without a
   gate has no gap at all. `map-corridor.png` shows it from the drivers' eye height.

3. **The contract has no run-time writer, and the tag strings live in one place.**
   `src/shared/Map/init.luau` is frozen (`Shotgun.deepFreeze`) and nothing assigns to it.
   `TestArena`, `Match.Markers` and `MapGen.Markers` all read `Map.TAGS`.
   (`tests/server/test_arena.spec.luau` still spells them literally, deliberately — an independent
   check — queued as 43a(h).)

4. **Nothing in the generator can run in a game session.** Every file under
   `src/serverstorage/MapGen/` only defines and returns; the spec asserts `ServerStorage.MapGen`
   exists and that every descendant is a `ModuleScript`, and `MapGen.verifyContract` asserts it from
   the tool's side. The one module that does work on require is `Contract.luau`, in Edit only, and the
   `init.luau` header says so.

5. **One writer per system inside the generator** (`GAME_DESIGN.md`'s new rows). `Ground` is the only
   module in the repo that touches `Terrain`, `Props` the only writer of `…Map.Props`, `Markers` the
   only caller of `CollectionService:AddTag` in the generated map, `Settings` the only writer of
   `Workspace.StreamingEnabled` (`grep -rn "AddTag\|Terrain\|StreamingEnabled" src`).

6. **The pure core is pure and deterministic, and the spec drives it with no Studio.** `Height`,
   `Layout`, `Scatter` and `Digest` touch no Instance and no service (`Scatter` takes
   `Random.new(seed * 1000 + layer)`, one generator per layer; `Height` uses none). The spec asserts:
   same seed → same heights and the same 50 tree positions; a different seed → a different field and a
   different wood; no tree in the corridor or on the track; every spawn pad flat at `GROUND_Y` and
   easing back to the terrain; the digest stable under reordering and sensitive to a tenth of a stud.

7. **The asset route is called on every placing step, and the proxy is its `nil` branch.**
   `Props.hedge` and `Props.trees` both call `Props.template(key, root)` first and proxy only on
   `nil`, through one `placed()` helper; `proxyUsed` lists the keys actually proxied; a `LoadAsset`
   failure or the §8.4 script refusal fails the step with its reason.

8. **The live world still satisfies the contract it names.** Exactly one of `TestArena` /
   `DrivenHuntMap` exists and it is the one `EXPECTED_WORLD` names; every tag resolves to exactly
   `Map.EXPECTED_COUNTS`, inside that root and nowhere else; one drive line with
   `LookVector:Dot(Vector3.zAxis) > 0.99`; every boar spawn inside `Map.FIELD.bounds` and within
   `SPAWN_PAD.tolerance` of `groundY`; a `PathfindingService` path from every spawn and the driver
   start to the line using `Boar.CONFIG.AGENT`; no script under the root; `Boar.CONFIG.field` equal to
   `Map.FIELD`.

9. **`tools/mapgen.py` refuses before it touches anything**: not Edit mode or not the DEV place; a
   dirty tree for every mutating command; Studio's copy of `MapGen` or `Map` differing from disk (it
   reuses the harness's `compare_synced`); no usable backup; no `--seed`. `--backup census` prints
   Workspace's children and proceeds only for `Terrain`, `Camera` and the map root — otherwise a
   `NEEDS KAREN` Save-to-File block. Try `python tools/mapgen.py build --seed 7` (refused: no backup)
   and `python tools/mapgen.py plan` (read-only, writes nothing).

10. **Six screenshots, retaken after this round's fixes and looked at** (`.screenshots/map-*.png`).
    `map-corridor` shows the hedgerow as two dark banks with a clear gate between them and the tree
    line beyond; `map-wide` shows the lane framed by woods with the markers correctly invisible;
    `map-track` reads as a farm track through tall grass. `map-stand` is two green boxes on brown
    stalks — proxies read as lollipops, not woods — and there are no fields yet, one material
    everywhere outside the track, so the slice reads as one big meadow rather than as European
    farmland. Queued as 43a(a) and (b) for M2.2 and M2.3.

## What I could not verify

* **Measurement B — do tags survive a save and a reopen — is NOT made.** It needs File → Save to File
  and a reopen: clicks no tool here can make. The Director and Karen do it in the morning. The
  fallback if tags do not survive is named (markers found by folder and name; only `Match.Markers`
  changes). The slice is **not** in the place right now — I cleared it so the harness could pass — so
  the save needs a `mapgen.py build --seed 7 --backup census` first, and a `clear` after it.
* **The generated slice has never been pathfound.** `map_contract.spec` check 5 runs against the world
  `EXPECTED_WORLD` names, which is the arena — that is how the hedgerow wall survived to round 2. The
  gate is asserted in the pure layer only until M2.5 points that check at the map. Row 43a(k).
* **Reproducibility across engine versions** — `verify` can only see one session. Fallback unchanged
  (seeded value noise inside `Height.luau`).
* **The memory half of measurement D.** Studio's own totals drifted upward across three samples
  regardless of content, so an Edit session cannot weigh 100 parts against its own noise. The part
  count is exact — two parts per tree, so 3,000 trees is 6,000 parts, inside `Map.BUDGET.parts`.
* **One 1-player run at `895300e` reported `FAIL: 25/27`**; the next two at that same commit, and the
  one at `87cdf86` above, reported `PASS: 27/27`. I did not capture which two checks failed, so the
  cause is unknown. A harness that fails once in three on an unchanged tree is a harness fault
  (rule 6) and it is queued as 43a(j) rather than explained away.
* **Whether the farmland reads as European farmland.** Only Karen can answer that; claim 10 is what I
  can see, not a verdict.

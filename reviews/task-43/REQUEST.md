# Task 43 — Milestone 2.1: the first map slice

Task: 43
Round: 2
Base: `eb0b23e` (task-41-evidence-seams; stacked on 38, 36 and 35, none merged)
Code commit: `1438665dbaf52d2817fae11ef3b6c3521b5f97d6`

Harness, clean tree, one player:

    [harness] PASS: 27/27 checks @ 1438665dbaf52d2817fae11ef3b6c3521b5f97d6 (clean tree)

Harness, clean tree, two players (the Director's new gate; `src/` and `tests/` are touched):

    [harness2] PASS: 30/30 checks @ 1438665dbaf52d2817fae11ef3b6c3521b5f97d6 (clean tree)

Both harness runs at this commit were made by the DIRECTOR, not by me: my own `test2` run
dirtied the tree by editing this file while it was live, and the Director's standing rule since
is that the Builder never runs `test2` itself. Server 297, shooter client 70, driver client 64.

Generator, clean tree, same seed twice — the last three lines of
`python tools/mapgen.py verify --seed 7 --backup census`, verbatim:

    [mapgen] build 1: digest=87abf2678bfa13bdbe3e936fb34c1d0582b1109f8aef56492de14bff476add99 parts=153
    [mapgen] build 2: digest=87abf2678bfa13bdbe3e936fb34c1d0582b1109f8aef56492de14bff476add99 parts=153
    [mapgen] OK: same seed twice, same digest @ 1438665dbaf52d2817fae11ef3b6c3521b5f97d6 seed=7 digest=87abf2678bfa13bdbe3e936fb34c1d0582b1109f8aef56492de14bff476add99 (clean tree)

That digest is the same one round 1 produced, before and after this round's `Props` rewrite: the
asset route changed and the map did not.

## What changed since round 1

**Finding 1 — the asset route was never called.** Right, and it made two of my own sentences false.
`Props.trees` and `Props.hedge` built boxes and then reported `proxyUsed` for a key they had never
looked up, so an id landing in `Assets.ROWS` would have been ignored while the step still claimed a
proxy. Both steps now call `Props.template(key, root)` **first** and proxy only on `nil`, through one
`placed()` helper that clones the asset when there is one; `proxyUsed` lists the keys actually
proxied; a `LoadAsset` failure or the section 8.4 script refusal fails the step with its reason.
`Props.trunks` returns a model's `PrimaryPart` (falling back to its first `BasePart`) instead of a
child literally named `Trunk`, so the tie trees keep working when the proxies become meshes.

**Finding 2 — a test asserting itself.** Right. The spec compared a count over `Layout.markers` with
`MapGen.expectedCounts()`, which is the same loop over the same data. It compares with the
**configuration** now (`SLICE.postCount`, `#SLICE.boarSpawnX`), and a second test asserts the map's
expectation is every planned marker plus the tie trees and nothing else.

Non-blocking notes fixed in the same commit: the contract header no longer says `ArenaBoot` reads
`EXPECTED_WORLD` today; `Settings.apply` reports a readable-but-not-boolean property as a third class
instead of skipping it; `Markers.tagTieTrees` counts the tie trees that **are** tagged, not only the
ones it newly tagged; the report loop's comment says what `process_call` actually retries, and the
client handshake beside it is wrapped like `run_test2`'s. The rest are queued as row 43a(f)–(i).

## Claims

1. **The asset route is called on every placing step, and the proxy is its `nil` branch.**
   `grep -n "Props.template" src/serverstorage/MapGen/Props.luau` shows the definition and two calls,
   one at the top of `Props.hedge` and one at the top of `Props.trees`. `proxyUsed` is
   `if proxied > 0 then { key } else {}`. The insertion branch itself is still dormant (`Assets.ROWS`
   is empty), which row 43a(d) now states as the honest reason.

2. **The spec no longer compares a function with itself.** `it("plans exactly the markers the
   configuration asks for")` asserts against `c.SLICE.postCount` and `#c.SLICE.boarSpawnX`; changing
   `postCount` alone fails it. `it("expects one tagged instance per planned marker…")` asserts
   `total == planned + tieTrees`, so a sixth marker kind without a tag breaks it.

3. **The contract has no run-time writer, and the tag strings live in one place.**
   `src/shared/Map/init.luau` is frozen (`Shotgun.deepFreeze`); nothing assigns to it. `TestArena`,
   `Match.Markers` and `MapGen.Markers` all read `Map.TAGS`. (`tests/server/test_arena.spec.luau`
   still spells them literally, deliberately — an independent check — and that is now queued as
   43a(h) rather than left unsaid.)

4. **Nothing in the generator can run in a game session.** Every file under
   `src/serverstorage/MapGen/` only defines and returns; the spec asserts `ServerStorage.MapGen`
   exists and that **every descendant is a `ModuleScript`**, and `MapGen.verifyContract` asserts it
   from the tool's side.

5. **One writer per system inside the generator.** `Ground` is the only module in the repo that
   touches `Terrain`, `Props` the only writer of `…Map.Props`, `Markers` the only caller of
   `CollectionService:AddTag` in the generated map, `Settings` the only writer of
   `Workspace.StreamingEnabled` (`grep -rn "AddTag\|Terrain\|StreamingEnabled" src`).

6. **The pure core is pure and deterministic, and the spec drives it with no Studio.** `Height`,
   `Layout`, `Scatter` and `Digest` touch no Instance and no service (`Scatter` takes
   `Random.new(seed * 1000 + layer)`, one per layer; `Height` uses none). The spec asserts: same seed
   → same heights and the same 50 tree positions; a different seed → a different field and a different
   wood; no tree in the corridor or on the track; the digest stable under reordering and sensitive to
   a tenth of a stud. `Assets` has no describe block of its own — claim 4 of round 1 overstated that,
   and this is the corrected list.

7. **The live world still satisfies the contract it names.** Exactly one of `TestArena` /
   `DrivenHuntMap` exists and it is the one `EXPECTED_WORLD` names; every tag resolves to exactly
   `Map.EXPECTED_COUNTS`, inside that root and nowhere else; one drive line with
   `LookVector:Dot(Vector3.zAxis) > 0.99`; every boar spawn inside `Map.FIELD.bounds` and within
   `SPAWN_PAD.tolerance` of `groundY`; a `PathfindingService` path from every spawn and the driver
   start to the line using `Boar.CONFIG.AGENT`; no script under the root; `Boar.CONFIG.field` equal to
   `Map.FIELD`. 297 server specs pass (274 before this task).

8. **The generator built the slice and the same seed rebuilds it.** 22/22 steps: 16 terrain tiles of
   24,576 voxels, a hedgerow, the dirt track, 50 trees, the five tagged marker kinds plus 12 tie
   trees, the streaming step. 153 parts. Two full builds, one digest, over 153 instances **and 4,096
   terrain samples**.

9. **`tools/mapgen.py` refuses before it touches anything**: not Edit mode or not the DEV place; a
   dirty tree for every mutating command; Studio's copy of `MapGen` or `Map` differing from disk (it
   reuses the harness's `compare_synced`); no usable backup; no `--seed`. `--backup census` prints
   Workspace's children and proceeds only for `Terrain`, `Camera` and the map root — otherwise a
   `NEEDS KAREN` Save-to-File block. Try `python tools/mapgen.py build --seed 7` (refused: no backup)
   and `python tools/mapgen.py plan` (read-only).

10. **Six screenshots, taken by `mapgen.py shots` in Edit and looked at** (`.screenshots/map-*.png`).
    Honestly: the **ground** reads as farmland — `map-track` is a pale dirt track through tall grass
    under a tree line, `map-corridor` an open lane toward a wood edge. The **props do not**:
    `map-stand` is two green boxes on brown stalks, and the hedgerow is a low dark wall. There are no
    fields yet — one material everywhere outside the track — so it reads as one big meadow, not as
    European farmland. Queued as 43a(a) and (b) for M2.2 and M2.3.

## What I could not verify

* **Measurement B — do tags survive a save and a reopen — is NOT made.** It needs File → Save to File
  and a reopen: two clicks no tool here can make. The fallback if they do not survive is named
  (markers by folder and name; only `Match.Markers` changes). A `NEEDS SAVE` note is left for the
  Director, and it says that the slice will be sitting in Workspace: **the next `python
  tools/studio_mcp.py test` fails `map_contract.spec` until `python tools/mapgen.py clear --backup
  census` runs.** The harness lines above were produced with the place cleared.
* **Reproducibility across engine versions** — `verify` can only see one session. Fallback unchanged
  (seeded value noise inside `Height.luau`).
* **The memory half of measurement D.** Studio's own totals drifted upward across three samples
  regardless of content, so an Edit session cannot weigh 100 parts against its own noise. The part
  count is exact — two parts per tree, so 3,000 trees is 6,000 parts, inside `Map.BUDGET.parts` — and
  the memory question belongs to M2.3 with real meshes in a Play session.
* **The insertion branch of `Props.template`** — `LoadAsset`, the run's asset cache and the section
  8.4 script refusal — has still never executed, because there is no asset id to make it. Row 43a(d).
* **Whether the farmland reads as European farmland.** Only Karen can answer that; claim 10 is what I
  can see, not a verdict.

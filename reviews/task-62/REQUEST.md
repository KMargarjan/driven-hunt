# Task 62 — `tools/meshy.py` step 2: refine, remesh, fetch, and the second stop point

Task: 62
Round: 2
Base: `51c2d57` (`main`)
Code commit: `ca5ac6af75861f4fe820ad35931d0a1e37710c9e` — the `[harness]` line below names it, and it
is the last commit that changed `src/`, `tests/` or `tools/`.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ ca5ac6af75861f4fe820ad35931d0a1e37710c9e (clean tree)

374 server and 84 client specs, unchanged: **no `src/` and no `tests/` file is touched.** The harness
ran because `tools/` changed; this tool puts nothing in the DataModel. **No `[harness2]`**:
`agents.py`'s `TWO_PLAYER_PATHS` is `src/`, `tests/client/` and `tools/studio_mcp.py`, none of them
here. **Nothing in this task called a generation endpoint and nothing spent a credit.**

## Scope

The design's **Task B up to the second stop point**: `refine`, `remesh`, `fetch`. **`promote` is not
here** — the sidecar and the drop dir depend on `tools/assets.py`, which does not exist yet (design
§0 item 6). Round 1's two findings were one class, and round 2 fixes it in **one guard** (claims 6
and 7). **The deadline this serves:** the approved boar preview
(`boar.body_v1-20260926T1501Z`) is deleted by Meshy on **2026-09-29 15:02 UTC**; after merge the
Asset agent's chain is `refine <run>` → `remesh <run>` → `fetch <run>`, inside that window.

## Claims

1. **Karen's OK is the door.** `refine` requires state `approved` and refuses any other **by name**
   (`run is preview-ready, not approved`). The case goes through `--dry-run`, so the gate is proven
   without anything being sendable. Verify: `cmd_refine`; selftest *"refine refuses a run Karen has
   not approved, by name"*.

2. **The refine body is frozen and asks for the BRIEF's texture resolution.**
   `{mode: "refine", preview_task_id, enable_pbr: true, texture_resolution: <brief.texturePx>}` and
   nothing else — a real parameter (research note D3), so the resolution is asked for rather than
   hoped for, and no deprecated field is sent. `TEXTURE_PX_ALLOWED` refuses anything but 1024/2048/
   4096 before the request is built; the frozen case pins the boar brief's 2048 (a 1024 case is
   queued as 62a(d)). Verify: `build_refine_request`, `cmd_refine`; the frozen-body case.

3. **The remesh cuts the REFINED task, in triangles, to the brief's target.**
   `{input_task_id: <the refine task>, target_polycount, topology: "triangle"}` — remeshing the
   preview would throw away the textures just paid for. `resolve_target` refuses a non-integer,
   anything outside Meshy's 100–300,000 and anything over `REMESH_CEILING = 18000`, **before** a
   request is sent. Verify: `build_remesh_request`, `resolve_target`.

4. **`fetch` downloads NOW, from fresh URLs, and asks for the maps where they are documented.** It
   re-polls the remesh task (a GET, no credits; no signed URL is ever persisted) for `model_urls`,
   and **when that response carries no `texture_urls` it re-polls the REFINE task** — the step that
   was paid for the maps, and the only one whose response the research note documents them on
   (source 3 gives remesh `model_urls` and no statistics). Both shapes of `texture_urls` are read
   (dict, and list-of-map-sets). Verify: `cmd_fetch`, `texture_set`; *"having re-polled the REFINE
   task for the map URLs"*, *"a remesh response with no texture_urls still lands the maps, from the
   refine"* (that case's fake answers `model_urls` on `/remesh` and the maps on `/text-to-3d`).

5. **What it validates locally, and what it refuses to pretend.** FBX present, non-empty, inside
   Roblox's 20 MB per-call cap; every PNG inside the brief's `texturePx`, read from the 8-byte
   signature plus the IHDR (24 bytes, no library); every file re-hashed off disk against what was
   downloaded; `trisDeclared` recorded. **The triangle count is NOT measured** — the remesh response
   carries no polycount (D5) and an FBX parser is one of the three named causes of death of the
   previous project. Verify: `validate_fetched`; the oversized-texture, oversized-FBX and truncated
   cases.

6. **ONE GUARD: no paid step is "done" until it delivered** (round 1 finding 1). `deliver` is the
   only place in the file that writes a ready state, so the next command cannot reopen the class:
   it checks what the step owed on disk (`DELIVERABLES`, where `texture_*.png` is a pattern and so
   means **at least one map**), that nothing offered failed to download, and every local check —
   then, and only then, prints the stop-point line. A fetch that lands no map exits 1, stays
   collectable and never says "OPEN IT AND LOOK AT IT". `finish_preview`, `finish_refine`,
   `finish_remesh` and `cmd_fetch` all go through it; `finish_preview`'s two hand-rolled stops and
   its hand-rolled dedup are gone (it uses `store()` like every other step). Verify: `deliver`,
   `DELIVERABLES`, `missing_deliverables`; *"a fetch that lands no PBR map at all exits 1"*,
   *"...and does NOT invite a human to look at it"*.

7. **Every paid-but-incomplete run has a route, and the line names a command that takes it** (round 1
   finding 2). Each `Problem` carries one: `refetch` (the bytes on disk are missing or wrong → the
   run is left `remesh-unresolved`, **never** `fetched`, and the line says `fetch`, which `cmd_fetch`
   now accepts as a door and `resume` accepts as well); `remesh` (the bytes are what Meshy sent and
   the geometry is too heavy → the line says `remesh <run> --target <lower>`, and `cmd_remesh` takes
   a `fetched` run whose validation failed — the replacement task `MAX_TASKS_PER_RUN` was sized for,
   still under `check_ceilings`); `brief` (everything paid for IS on disk and a written number is
   what it breaks → the line says no command can fix it, instead of offering one that does nothing).
   Verify: `Problem`, `validate_fetched`, `deliver`, `cmd_fetch`, `cmd_remesh`; *"a truncated
   download exits 1"* → *"is NOT left in fetched, which no command takes"* → *"the line names fetch"*,
   and *"a fetched run whose local checks failed can be re-cut"*.

8. **Task 59's class, extended rather than copied.** Every stop while a paid task may still be
   running is `<phase>-unresolved`; `RESUMABLE_STATES` is generated from `PHASES`; `resume` continues
   **whichever phase** the newest task belongs to; the poll path comes from the **task's** endpoint;
   and `fetch` no longer calls a task's absent URLs a failed download when the task has not
   SUCCEEDED — it says `IN_PROGRESS` and names `resume`. A refine thumbnail that was offered and
   failed now stops like the preview's GLB. Verify: the stalled-refine case, *"fetching a task that
   has not finished exits 1"*, *"a refine whose thumbnail download fails exits 1"* → *"resume
   collects that refine afterwards"*.

9. **Credits and ceilings.** Every task records `consumed_credits` from the API or `"unknown"`,
   totals are recomputed at each phase, and `check_ceilings` runs **before** every POST, so
   `MAX_TASKS_PER_RUN = 4` and `MAX_TASKS_PER_DAY = 12` bound this half exactly as they bound the
   preview. The 3-day expiry is counted from generation and refuses `refine`, `remesh` and `fetch`
   on an expired run with the reason.

10. **EIGHT NEW MUTATIONS, all caught by named cases** (2026-09-26; each applied, `selftest` run,
    then restored), on top of round 1's fourteen: the `texture_*.png` row in `DELIVERABLES` (the
    no-map fetch then prints "OPEN IT AND LOOK AT IT" with one file — round 1 finding 1, reproduced);
    `deliver`'s whole deliverables check (eight preview cases fail); the `refetch` route (the
    truncated run lands in `fetched`, which no command takes — finding 2, reproduced); the refine
    re-poll for maps; `fetch`'s `remesh-unresolved` door; `remesh`'s re-cut door; the SUCCEEDED gate;
    and the refine thumbnail's `undownloaded`.

## What I could not verify

- **Nothing ran against Meshy.** Every case swaps `request` and `download` for fakes: no key, no
  network, no credit. The refine and remesh **response shapes** come from the research note, not
  from a call this task made — including the claim in 4 that a real remesh response carries no
  `texture_urls`. If it does carry them, the refine re-poll simply never happens.
- **Only the first map set is fetched** if a real refine returns several materials (62a(a)).
- **The FBX is not opened.** "Is it a boar?" is the second stop point's question, and it is a human's.
- **`promote` does not exist**, so nothing writes a sidecar or the drop dir yet.
- **The `brief` route strands nothing but a judgement**: an oversized map means the files are all on
  disk and the brief's number is what they break, so no command is offered. That is a deliberate
  reading of "paid for but incomplete" — the credits bought bytes and the bytes arrived.

# Task 62 — `tools/meshy.py` step 2: refine, remesh, fetch, and the second stop point

Task: 62
Round: 1
Base: `51c2d57` (`main`)
Code commit: `5ce65df7eb68ef35d2a89d3c460597c790ed89c5` — the `[harness]` line below names it, and it
is the last commit that changed `src/`, `tests/` or `tools/`.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 5ce65df7eb68ef35d2a89d3c460597c790ed89c5 (clean tree)

374 server and 84 client specs, unchanged: **no `src/` and no `tests/` file is touched.** The harness
ran because `tools/` changed; this tool puts nothing in the DataModel. **No `[harness2]`**:
`agents.py`'s `TWO_PLAYER_PATHS` is `src/`, `tests/client/` and `tools/studio_mcp.py`, none of them
here. **Nothing in this task called a generation endpoint and nothing spent a credit.**

## Scope

The design's **Task B up to the second stop point**: `refine`, `remesh`, `fetch`. **`promote` is not
here** — the sidecar and the drop dir depend on `tools/assets.py`, which does not exist yet (design
§0 item 6). The module docstring, which used to say the whole of Task B was absent, says this.

**The deadline this serves:** the approved boar preview (`boar.body_v1-20260926T1501Z`) is deleted by
Meshy on **2026-09-29 15:02 UTC**. After merge, the Asset agent's chain is
`refine <run>` → `remesh <run>` → `fetch <run>`, and `fetch` must run inside that window.

## Claims

1. **Karen's OK is the door.** `refine` requires state `approved` and refuses any other **by name**
   (`run is preview-ready, not approved`). The case goes through `--dry-run`, so the gate is proven
   without anything being sendable. Verify: `cmd_refine`; selftest *"refine refuses a run Karen has
   not approved, by name"*.

2. **The refine body is frozen and asks for 2K PBR.** `{mode: "refine", preview_task_id, enable_pbr:
   true, texture_resolution: 2048}` and nothing else — `texture_resolution` is a real parameter
   (research note D3), so the resolution is asked for rather than hoped for, and no deprecated field
   is sent. Verify: `build_refine_request`; the frozen-body case.

3. **The remesh cuts the REFINED task, in triangles, to the brief's target.**
   `{input_task_id: <the refine task>, target_polycount, topology: "triangle"}` — remeshing the
   preview instead would throw away the textures just paid for. `resolve_target` refuses a
   non-integer, anything outside Meshy's 100–300,000, and anything over `REMESH_CEILING = 18000`,
   **before** a request is sent; the fallbacks are the brief, then `REMESH_TARGETS`, then the
   ceiling. Verify: `build_remesh_request`, `resolve_target`.

4. **`fetch` downloads NOW, and from fresh URLs.** It re-polls the remesh task (a GET, no credits)
   because no signed URL is ever persisted, then writes `model.fbx`, `model.glb`/`.obj` when offered,
   and `texture_<map>.png` for each PBR map, recording `bytes` and `sha256` for every one. Verify:
   `cmd_fetch`; the chain case, which asserts all four files on disk with hashes.

5. **What it validates locally, and what it refuses to pretend.** FBX present, non-empty, inside
   Roblox's 20 MB per-call cap; every PNG inside the brief's `texturePx`, read from the 8-byte
   signature plus the IHDR (24 bytes, no library); every file re-hashed off disk against what was
   downloaded; `trisDeclared` recorded. **The triangle count is NOT measured** — the remesh response
   carries no polycount (D5) and an FBX parser is one of the three named causes of death of the
   previous project. Verify: `validate_fetched`; the oversized-texture, oversized-FBX and
   truncated-file cases.

6. **A broken run never invites a human to look.** Validation problems are written onto the record
   (`validation.ok`, `validation.problems`), printed one per line, and the command exits 1 **without**
   the stop-point line. Verify: *"a fetch whose files break the local checks exits 1"*, *"...and does
   NOT invite a human to look at it"*.

7. **The second stop point.** On success `fetch` prints where the model is, tells the operator to
   open it and look (rule 5), and says plainly that **nothing is uploaded until Karen says yes** —
   which this tool could not do in any case: it contains no Roblox endpoint.

8. **Task 59's class, extended rather than copied.** Every stop while a paid task may still be
   running is `<phase>-unresolved` for the phase that stopped; `RESUMABLE_STATES` is generated from
   `PHASES`; `resume` continues **whichever phase** the newest task belongs to; and the poll path
   comes from the **task's** endpoint — a remesh task lives under `/openapi/v1/remesh/:id`, so
   polling the run's creation endpoint would ask the wrong service for the wrong id. Verify: the
   stalled-refine case (`refine-unresolved` → `resume` → `refine-ready`) and *"polls the remesh
   endpoint, not the run's creation endpoint"*.

9. **Credits and ceilings.** Every task records `consumed_credits` from the API or `"unknown"`,
   totals are recomputed at each phase, and `check_ceilings` runs **before** every POST, so
   `MAX_TASKS_PER_RUN = 4` and `MAX_TASKS_PER_DAY = 12` bound this half exactly as they bound the
   preview. The 3-day expiry is counted from generation and refuses `refine`, `remesh` and `fetch`
   on an expired run with the reason.

10. **FOURTEEN MUTATIONS, all caught** (2026-09-26; each applied, `selftest` run, then restored):
    the approval gate, `enable_pbr`, the remesh input task, triangle topology, the triangle ceiling,
    the poll path, the phase in a stop, the phase in a resume, the missing-FBX stop, the
    texture-size check, the file-size check, the sha256 check, the "do not invite a human" rule, and
    the PNG header reader. Every one makes the selftest fail **by name** — and a `Refused` inside a
    step-2 case is reported as a named failing case rather than ending the run (the Task 59 note).

## What I could not verify

- **Nothing ran against Meshy.** Every case swaps `request` and `download` for fakes: no key, no
  network, no credit. The refine and remesh **response shapes** come from the research note
  (items 1 and 3), not from a call this task made.
- **`texture_urls` shape.** Meshy's examples show a list of map sets; the code reads both a dict and
  a list-of-dicts and takes the first set. If a real refine returns several materials, only the first
  is fetched — queued as 62a.
- **The FBX is not opened.** "Is it a boar?" is the second stop point's question, and it is a human's.
- **`promote` does not exist**, so nothing writes a sidecar or the drop dir yet; the run folder is the
  handoff for now.
- **The deadline is arithmetic, not a measurement**: the expiry is computed from `created_at` + 72 h
  as the Terms say, and this task never polled the real run to confirm its stamp.

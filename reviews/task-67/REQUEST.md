# Task 67 — URGENT: `fetch` could not finish a remeshed run

Task: 67
Round: 1
Base: `4d559f3` (`main`, with Task 66 merged)
Code commit: `bb2066d4bea5bdb10cb18dd5512c8a6b24edf331` — the `[harness]` line below names it, and it
is the last commit that changed `src/`, `tests/` or `tools/`.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ bb2066d4bea5bdb10cb18dd5512c8a6b24edf331 (clean tree)

382 server and 84 client specs, unchanged: **no `src/` and no `tests/` file is touched.** The harness
ran because `tools/` changed. **No `[harness2]`**: `TWO_PLAYER_PATHS` is `src/`, `tests/client/` and
`tools/studio_mcp.py`, none of them here. **No credit was spent** — a `fetch` is a GET plus
downloads, and no generation endpoint was called.

## The run, finished

`boar.body_v1-20260926T1501Z` reached the **second stop point** (`fetch` exit 0, 35 credits
accounted, expiry 2026-09-29 18:17 UTC):

    [meshy] note: texture_metallic.png is 4096x4096, over the brief's texturePx 2048 (inside
            Roblox's 4096: a note, not a fault)
    [meshy] note: texture_roughness.png is 4096x4096, over the brief's texturePx 2048 (...)
    [meshy] the model is <runs-dir>/boar.body_v1-20260926T1501Z/model.glb with 5 file(s) beside it
            -- OPEN IT AND LOOK AT IT (rule 5), then ask Karen. Nothing is uploaded until she says
            yes. 2 note(s) above: nothing stops the run, and somebody should read them.
    [meshy] OK: fetch boar.body v1 run=boar.body_v1-20260926T1501Z tris=6000 files=5 credits=35

Nothing was approved, promoted or uploaded, and this tool still contains no Roblox endpoint.

## Claims

1. **It was not broken, it was unasked.** `target_formats` defaults to `["glb"]`
   (<https://docs.meshy.ai/en/api/remesh>, re-read today, quoted as note **D13** with the response's
   documented `model_urls` formats and its absence of `texture_urls` and any polycount). So the
   remesh answered with a GLB and no FBX, and `fetch` called that a missing deliverable twice.
   Verify: note D13; `build_remesh_request`, which now **sends** `target_formats: ["glb"]` so the
   deliverable is asked for rather than inherited.

2. **`DELIVERABLE_MODEL = "model.glb"` is the one name for it** — what `DELIVERABLES` requires, what
   `validate_fetched` judges, and what the second stop point points a human at. That line still said
   `model.fbx`, which would have sent the Asset agent to a path that does not exist. Verify:
   `DELIVERABLE_MODEL` and its three uses; the case *"a remesh that answers a GLB and no FBX
   finishes"* → *"the stop-point line names the GLB, not an FBX"*.

3. **The model is never taken from the refine.** The maps fall back to the refine (it was paid for
   them, D12); the model must not, because the refine's is the high-poly one the remesh exists to
   replace. Verify: the case *"a remesh with no model at all stops"* → *"takes NO model from the
   refine"* → *"while the MAPS still come from the refine"*, against a fake whose refine offers both
   `fbx` and `glb`.

4. **Both questions are answered every time.** "Did everything paid for land" and "is what landed
   usable" are different questions, and `deliver` returned on the first without asking the second —
   so two fetches said nothing about the four maps that HAD landed. Validation now runs over
   everything on disk whether or not a deliverable is missing, and the missing-deliverable line
   carries `; N local check(s) also failed on what DID land`. `validate_fetched` no longer asks
   whether the model is present: that is `DELIVERABLES`' question, and two checks for one fact drift
   apart. Verify: `deliver`; the case *"a fetch missing its model still reports the maps it DID
   land"*.

5. **A map bigger than the brief is a NOTE, not a dead run.** Roblox documents 4096 as supported
   (note **D14**, quoted), so a 4096 map overruns the brief and nothing else. `Problem` gains a
   fourth route, `note`: printed, kept under `validation.notes`, and it does not fail the run — the
   stop-point line says how many are above it, because that is when somebody is looking. **Over**
   Roblox's 4096 it stays a problem. **Nothing is resized**: resizing a map this tool did not make is
   how a budget stops meaning anything, and `promote` is where a resize belongs. Verify: the cases
   *"notes the oversized texture rather than failing on it"* and *"a map over Roblox's own 4096
   fails the fetch"*.

6. **A stored verdict can be re-made, free.** The real run had reached `fetched` carrying an older
   build's verdict, and no command took it — `fetch` refused the state and `remesh` would have spent
   credits re-cutting geometry that was never the problem. `fetch` now accepts a `fetched` run whose
   `validation.ok` is false (the door `remesh` already had), because re-fetching costs nothing and
   re-runs every check; one that PASSED is still refused by name. Verify: the case *"a fetched run
   whose verdict says something is wrong can be fetched again"*.

7. **D14 says what the documentation says, and what it does not.** Roblox's 3D Importer page reads
   *"You can import meshes in the .fbx, .obj, or .gltf format"* and **does not name `.glb`**; `.glb`
   is glTF's binary container and the Director's decision is that Studio takes it directly. The
   texture page documents 4K support and runtime quality ramping, **not** an upload-time downsample.
   Both are recorded as quotes with the gap named, because an assumption about the platform is how a
   budget stops meaning anything.

8. **D15 — what the first real delivery actually contained**, measured off the files: `model.glb`
   **20,891,952 bytes (19.92 MiB against Roblox's 20 MiB per-call cap — 0.4 % of headroom)**;
   base_color and normal at **2048**; metallic and roughness at **4096**, though the refine asked for
   `"2k"`. So `texture_resolution` governs some maps and not others, and the brief's `texturePx` is a
   budget to CHECK rather than a setting to rely on. The remesh response also carried `texture_urls`
   though its reference documents none, so the refine re-poll never fired. All three are queued as
   67a.

9. **NINE MUTATIONS, all caught by named cases** (2026-09-26; each applied, `selftest` run, then
   restored): the FBX deliverable back (6 cases fail); validation after the missing branch again;
   the remesh not asking for its format; the stop-point line naming a file that is not there; a real
   fallback to the refine's model; the platform limit ignored; a note failing the run again; the
   notes not printed; and the re-judge door removed.

10. **Nothing else moved.** No `src/`, no `tests/`, no design file. `TASKS.md` gains rows 67 and 67a;
    the module docstring gains the two rules.

## What I could not verify

- **Nobody has imported `model.glb` into Studio.** The Director's decision says the 3D Importer takes
  it; the documentation I read names `.gltf` and not `.glb` (claim 7). The first import is the
  measurement, and it has not happened.
- **Whether asking for `target_formats: ["glb", "fbx"]` works** — one word, one paid remesh, not
  spent (67a).
- **Whether the boar is a boar.** That is the second stop point's question and it is a human's; I
  have not opened the GLB.
- **The 19.92 MiB deliverable is 0.4 % under the upload cap** and nothing guarantees the next asset
  stays inside it.
- **`texture_resolution` was asked for as `"2k"` and two maps came back at 4096.** Measured, not
  explained; I did not ask Meshy why.

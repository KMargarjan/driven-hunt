# Task 59 — make `tools/meshy.py` safe before the first real credits are spent

Task: 59
Round: 3
Base: `29d2ba3` (`main`, with Task 55 merged)
Code commit: `310cb3fe76bceddfd7d3688de482747c4c6b5791` — the `[harness]` line below names it, and it is
the last commit that changed `src/`, `tests/` or `tools/`.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 310cb3fe76bceddfd7d3688de482747c4c6b5791 (clean tree)

335 server and 84 client specs, unchanged: **no `src/` and no `tests/` file is touched.** The harness
ran because `tools/` changed; this tool puts nothing in the DataModel. **No `[harness2]`**:
`agents.py`'s `TWO_PLAYER_PATHS` is `src/`, `tests/client/` and `tools/studio_mcp.py`, none of them
here. **Nothing in this task called a generation endpoint and nothing spent a credit.**

## What this task is

Five of Task 55's review notes, made blocking by the Director because the next run spends Karen's
money, plus the two findings of review round 1 — which were **one class**: the tool wrote `failed`
whenever **it** could not finish, and `cmd_resume` accepted only `preview-running`, so a task that
was **already paid for** could never be collected again and the only other route to the model was a
second `preview`, which pays twice (design §8).

`failed` is a terminal again and means what §7/§8 say: Meshy answered `FAILED` or `CANCELED`, a
ceiling stopped the run, or no task was created. Everything else that stops the tool while a paid
task may still be running, or while its output can still be re-fetched, is **`preview-unresolved`**,
which `resume` takes.

## Claims

1. **A give-up keeps the run collectable.** Three consecutive unanswered polls (~15 s of 5xx/429,
   each poll already retried inside `request`) and a 400/401/403/404 stop with exit 1 and
   `state = "preview-unresolved"`. Verify: `poll_and_finish`'s give-up branch; `stop_resumable`.

2. **A rejected key is recoverable, and the line says how.** The 401 line names the fix — rotate
   `MESHY_API_KEY`, check it with `key --check` — and then the exact command. Verify: selftest
   *"a 401 leaves the run resumable rather than failed"*, *"...and the 401 line says exactly what to
   run"*, *"resume collects the run after a 401 give-up"*.

3. **A failed download is recoverable.** A SUCCEEDED task whose signed `thumbnail_url` fails is the
   same class: the credits are spent and re-polling the same task id mints fresh URLs until the
   3-day expiry — which is what the old line **told** the operator to do while the tool refused it.
   Verify: `finish_preview`; selftest *"a failed preview download exits 1"* and the two cases after it.

4. **Every stop says exactly what to run.** `stop_resumable` is the one place that writes the state,
   and its line always ends `Run: python tools/meshy.py resume <run-id> (<expiry>)`. Three selftest
   cases assert the run id is in the printed text, not just the exit code.

5. **The last-line vocabulary gains `STOPPED`**, between `PENDING` (nothing wrong, still running,
   exit 0) and `FAILED` (terminal, nothing to collect). The docstring says which is which;
   `docs/ASSET_PROMPT.md` tells the ASSET agent to run the command the line names and to treat only
   a refusal from `resume` as the end.

6. **THE ROUND-2 FINDING, and it was right.** The case *"a re-download replaced its record rather
   than doubling it"* could not fail: it ran on the `broken` run, whose first pass fails **both**
   downloads, so the saved record held no artefact and the resume simply appended two fresh ones.
   The dedup is now asserted on **`partial`** — the run whose first pass lets `preview.png` through
   and fails only the GLB, so a prior entry really is on disk across the resume: `["preview.png"]`
   while stopped, `["preview.glb", "preview.png"]` after. The `broken` case keeps a weaker claim
   under an honest name (*"the resume recorded one entry per file"*) with a comment naming the case
   that owns the dedup.

7. **MUTATION-CHECKED, every claim above, and these are counts I ran rather than estimated**
   (2026-09-26, `python tools/meshy.py selftest` after each edit, restored between):

   | mutation | failing cases |
   |---|---|
   | `stop_resumable` writes `failed` again | **15** |
   | `cmd_resume` takes only `preview-running` | **11** |
   | a failed GLB download is ignored | **5** |
   | **the dedup filter in `finish_preview` is deleted** | **1** — and it prints the doubling it exists to catch: `['preview.png', 'preview.png', 'preview.glb']` |

   Round 2's request said 11 and 8 for the first two; those were counted by eye and were wrong. The
   table is measured.

8. **Same class, from the notes: a failed GLB download stops too.** The image on disk was the whole
   test, so a preview missing the artefact Task B needs was called `preview-ready` with a one-line
   note. A response carrying no GLB URL at all stays a note — there is nothing to re-fetch.

9. **The selftest restores the environment it borrowed**, and a `Refused` inside a resume case is
   reported as a **named** failing case rather than ending the selftest before the later cases run.

10. **`docs/design/meshy-tool.md` is out of date in four places** — `<assets-dir>/briefs`, PNG-only
    references, no `preview-unresolved`/`STOPPED` row, no `POLL_GIVE_UP_AFTER`. The Architect owns
    that file, so the delta is `reviews/task-59/DESIGN_DELTA.md` rather than an edit.

## What I could not verify

- **Nothing here was run against Meshy.** Every case swaps `request` and `download` for fakes: no
  key, no network, no credit. That Meshy re-mints a `thumbnail_url` on a second poll of a SUCCEEDED
  task is **documented and not measured**; the first real `preview` will show it.
- **A 2xx POST whose body carries no task id is still `failed`** (round 2's first note): Meshy
  probably created and charged a task, and there is no id to resume with. Queued as 59a(h), with the
  printed line to send the operator to the dashboard.
- **A `Failed` raised inside `cmd_resume`** would still end the selftest early — the same class as
  the `Refused` that claim 9 fixed. Queued as 59a(i).
- The selftest's blocks are still literally numbered `# 1.` … `# 11.`; only the cross-references were
  reworded. Queued, not fixed.
- **`docs/asset-briefs/` holds no reference image**, so an image-to-3d brief cannot name one:
  committing Karen's photographs to a public repo is her call. Queued as 59a(f).

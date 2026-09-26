# Task 59 — make `tools/meshy.py` safe before the first real credits are spent

Task: 59
Round: 2
Base: `29d2ba3` (`main`, with Task 55 merged)
Code commit: `45fcb11a65374a7a5ee14a58b021ccd6d6325aa2` — the `[harness]` line below names it. It is
at the last commit that changed `src/`, `tests/` or `tools/` plus one review file, and only this
request and `TASKS.md` change after it.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 45fcb11a65374a7a5ee14a58b021ccd6d6325aa2 (clean tree)

335 server and 84 client specs, unchanged: **no `src/` and no `tests/` file is touched.** The harness
ran because `tools/` changed; this tool puts nothing in the DataModel. **No `[harness2]`**:
`agents.py`'s `TWO_PLAYER_PATHS` is `src/`, `tests/client/` and `tools/studio_mcp.py`, none of them
here. **Nothing in this task called a generation endpoint and nothing spent a credit.**

## Round 1's two findings are one class, and that is what is fixed

The tool wrote `failed` whenever **it** could not finish, and `cmd_resume` accepted only
`preview-running` — so a task that was **already paid for** could never be collected by the tool
again, and the only other route to the model was a second `preview`, which pays twice (design §8).

`failed` is a terminal again and means what §7/§8 say: Meshy answered `FAILED` or `CANCELED`, a
ceiling stopped the run, or no task was ever created. Everything else that stops the tool while a
paid task may still be running, or while its output can still be re-fetched, is the new
**`preview-unresolved`**, which `resume` takes.

## Claims

1. **A give-up keeps the run collectable.** Three consecutive unanswered polls (~15 s of 5xx/429,
   each poll already retried inside `request`) and a 400/401/403/404 all stop the tool with exit 1
   and `state = "preview-unresolved"`. Verify: `poll_and_finish`'s give-up branch; `stop_resumable`.

2. **A rejected key is recoverable.** The 401 line names the fix — rotate `MESHY_API_KEY`, check it
   with `key --check` — and then the exact command. Verify: selftest *"a 401 leaves the run resumable
   rather than failed"*, *"and the 401 line says exactly what to run"*, *"resume collects the run
   after a 401 give-up"*.

3. **A failed download is recoverable.** A SUCCEEDED task whose signed `thumbnail_url` fails is the
   same class: the credits are spent and re-polling the same task id mints fresh URLs until the
   3-day expiry. That is what the old line **told** the operator to do while the tool refused it.
   Verify: `finish_preview`; selftest *"a failed preview download exits 1"*, *"...and leaves the run
   resumable rather than failed"*, *"resume collects a preview whose download failed"*.

4. **Every stop says exactly what to run.** `stop_resumable` is the one place that writes the state,
   and its line always ends `Run: python tools/meshy.py resume <run-id> (<expiry>)`. Three of the
   four selftest cases assert the run id is in the printed text, not just the exit code.

5. **The last-line vocabulary gains `STOPPED`**, between `PENDING` (nothing wrong, still running,
   exit 0) and `FAILED` (terminal, nothing to collect). The module docstring says which is which and
   why `STOPPED` is the one that costs money if it is ignored; `docs/ASSET_PROMPT.md` tells the ASSET
   agent to run the command the line names and to treat only a refusal from `resume` as the end.

6. **The four new cases bite — mutation-tested, not asserted.** Reverting `stop_resumable` to
   `failed` fails 11 cases; narrowing `cmd_resume` back to `preview-running` fails 8; ignoring a
   failed GLB download fails 4. A `Refused` raised inside a resume case is reported as a **named**
   failing case rather than ending the selftest before the cases after it run.

7. **Same class, from the notes: a failed GLB download stops too.** The image on disk was the whole
   test, so a preview missing the artefact Task B needs was called `preview-ready` with a one-line
   note. A response that carries no GLB URL at all stays a note — there is nothing to re-fetch.
   Verify: `finish_preview`'s `undownloaded` branch; selftest *"a failed GLB download stops instead
   of claiming preview-ready"*.

8. **A re-download replaces its record entry.** `resume` comes back through `finish_preview`, so
   appending would have made the record claim two artefacts for one file. Verify: selftest *"a
   re-download replaced its record rather than doubling it"*.

9. **The selftest restores the environment it borrowed.** `MESHY_API_KEY` is put back rather than
   dropped, the same `previous` dance `MESHY_RUN_DIR` already did, and both are read before the
   `try` so the `finally` cannot raise.

10. **`docs/design/meshy-tool.md` is out of date in four places** — `<assets-dir>/briefs`, PNG-only
    references, no `preview-unresolved`/`STOPPED` row, no `POLL_GIVE_UP_AFTER`. The Architect owns
    that file, so the delta is written to `reviews/task-59/DESIGN_DELTA.md` rather than edited in.

## What I could not verify

- **Nothing here was run against Meshy.** Every new case swaps `request` and `download` for fakes;
  no key, no network, no credit. Whether Meshy really re-mints a `thumbnail_url` on a second poll of
  a SUCCEEDED task is **documented** (the task keeps its artefacts until the 3-day expiry) and
  **not measured**: the first real `preview` run is what will show it.
- **Round 1's note on claim 6 stands**: the selftest's blocks are still literally numbered `# 1.`
  … `# 11.`, and one comment still cites a number. Only the cross-references were reworded. Queued,
  not fixed.
- **`docs/asset-briefs/` still holds no reference image**, so an image-to-3d brief cannot name one:
  committing Karen's photographs to a public repo is her call, not mine. Queued as 59a.
- **`TASKS.md`'s rows are renumbered 59 / 59a** to match the folder and the gate; the branch stays
  `task-55b-meshy-fixes`, as the Director said.

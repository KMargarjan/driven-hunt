# Task 55b — make `tools/meshy.py` safe before the first real credits are spent

Task: 55b
Round: 1
Base: `29d2ba3` (`main`, with Task 55 merged)
Code commit: `736afa07a298742f0995f19216caf6641c0ac910` — the `[harness]` line below names it, it is
the last commit that changed `src/`, `tests/` or `tools/`, and only this request changes after it.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 736afa07a298742f0995f19216caf6641c0ac910 (clean tree)

327 server and 84 client specs, unchanged: **no `src/` and no `tests/` file is touched.** The harness
ran because `tools/` changed; this tool puts nothing in the DataModel. **No `[harness2]`**:
`agents.py`'s `TWO_PLAYER_PATHS` is `src/`, `tests/client/` and `tools/studio_mcp.py`, none of them
here. **Nothing in this task called a generation endpoint and nothing spent a credit.**

## Claims

1. **A permanent poll error ends the run, instead of looking like a slow model.** `poll_and_finish`
   printed a non-200 and looped to the 600 s deadline, then fell out and reported `PENDING` with
   **exit 0** — so a revoked key (401) or a bad task id (404) was indistinguishable, to the operator
   and to the ASSET agent's report, from a model that was taking a while. Now 400/401/403/404 are
   terminal on the **first** poll and anything else gives up after `POLL_GIVE_UP_AFTER = 3`
   consecutive non-200s; both exit 1, set `state = "failed"`, and say the task may still be running
   at Meshy with `runs` holding the id. Verify: `poll_and_finish`; selftest "a 401 poll exits 1",
   "gives up on the FIRST permanent error", "a repeated 5xx also exits 1 after exactly
   POLL_GIVE_UP_AFTER".

2. **"preview-ready" is claimed only for a file that is on disk.** A missing `thumbnail_url` or a
   failed download printed a note and then told the ASSET agent to `Read` a path that does not
   exist — and that agent is instructed to *describe what it sees*, so the next step was a crash or
   an invention. It now checks `entry["artefacts"]` **and** `os.path.isfile`, fails with exit 1
   naming what did not download, and says plainly that the task **SUCCEEDED and its credits are
   spent**. Verify: `finish_preview`.

3. **A run directory that already exists is a refusal, not an overwrite.** Run ids are
   minute-resolution and `save_run` wrote unconditionally, so two `preview` runs of one key inside
   one minute replaced the first record and **orphaned a task that had already been paid for** — no
   id, no credits, no expiry left anywhere. `save_run(..., fresh=True)` refuses and says why; an
   ordinary state transition still saves. Verify: `save_run`, its `fresh=True` call site in
   `cmd_preview`; selftest "a second fresh run with the same id is refused".

4. **`texturePx` is type- and range-checked like every other field.** It was read straight out of the
   brief, so a string or a `16384` would have reached Task B's `texture_resolution` — and been
   refused by Meshy *after* the credits were spent, or accepted. Allowed: `1024`, `2048`, `4096`
   (`TEXTURE_PX_ALLOWED`). `targetTris` now rejects booleans too, which `isinstance(True, int)` let
   through. Verify: `validate_brief`; six new refusal cases and four acceptance cases.

5. **The selftest checks the 1-reference `image-to-3d` body.** The old loop was
   `for bodies in (body, got_body)` and `got_body` was whatever the last iteration left behind, so
   that body was never checked for a deprecated field at all. Every built body is collected now, and
   the count is asserted. **Proved by mutation:** putting `art_style` in the `image-to-3d` branch
   alone fails `no deprecated field art_style in body 1`. Verify: the `built` list in `selftest`.

6. **The stale case numbers are gone, and cannot come back.** Three comments cited three different
   numbers for the same two blocks (`case 3` twice for redaction, which was case 5; `case 2` for the
   frozen fixture, which was case 3). Blocks are **named**, not numbered — numbering a list that
   grows is a citation that rots. Verify: the module docstring, `redact`, `build_preview_request`.

7. **Director (a): PNG, JPEG and WebP references.** Meshy's docs list *".jpg, .jpeg, and .png"* and
   Karen's reference photographs are JPEG and WebP, so the PNG-only rule meant the gun and the trees
   could not use references at all. Each data URI now **announces its own media type from the file
   name** — a PNG announced as a JPEG is a decode error at the far end and a wasted task. An unknown
   suffix is refused before anything is sent. Verify: `REFERENCE_SUFFIXES`, `DATA_URI_TYPE`,
   `data_uri`; the four accepted-suffix cases and `model.fbx`'s refusal.

8. **Director (b): one source for briefs, and it is in the repo.** `briefs_dir()` returns
   `docs/asset-briefs/`; the drop-folder working copy is gone. Two copies of the file that decides
   what is generated and what is paid for — with the un-reviewable one being what the tool actually
   read — is the drift this project keeps paying for. **Note the asymmetry, and it is deliberate:
   briefs are READ from the repo; everything the tool WRITES still goes outside it**, into a folder
   it refuses if it resolves inside the repository. Verify: `briefs_dir`, `_load_brief_file`;
   `docs/asset-briefs/README.md`; `CLAUDE.md`'s layout row; run `python tools/meshy.py brief
   boar.body_v1` with no `ASSET_DROP_DIR` set.

9. **Director (c): the licence claim carries its evidence.** `LICENCE["evidence"]` is
   *"Karen's statement 2026-09-26, plus a working API key (no API call can prove a plan)"*, with the
   comment recording why nothing stronger is available: `usage/tasks` answers 403 below Studio
   (note D11) and the authentication docs never say a key requires a paid plan (D7). Verify:
   `LICENCE`.

10. **New coverage is on-disk and real, in a temp run directory** (no key, no network): the fresh-run
    refusal, a state transition still saving, `approve` refusing a wrong state **by name**, `approve`
    being idempotent (design §13.1 item 5, previously untested), `resume` refusing an expired run
    with *"cannot be regenerated ... no seed"*, and the two poll give-ups. **Checked by mutation:**
    removing the fresh guard fails 2 cases; removing the `texturePx` range fails 4; removing the poll
    give-up makes the selftest **hang to the 600 s deadline**, which is the defect itself.

## What I could not verify

- **Still no model has been generated, and nothing here was exercised against the real API.** Every
  new path is proved offline against fakes. The first real preview remains the Asset agent's, watched
  by a human.
- **Four Reviewer notes are queued, not fixed** (row 55b-a): `created_at`'s type is unconfirmed, so a
  non-ISO value would reset `createdAt` on every poll and push the expiry *later* than the truth —
  the opposite of D9's "earlier, therefore safe"; `expiresAt` is derived rather than stored, which
  deviates from design §4.2 as written; `_registry_key` discards the value kind and does no
  `expandvars`, which design §16 asked for; and the 429 give-up prints no run id.
- **WebP is accepted on the Director's decision, not on a measurement.** Meshy's docs list only
  `.jpg`, `.jpeg` and `.png`. If Meshy refuses a WebP data URI the task fails loudly with Meshy's own
  message — it does not fail silently — but I have not sent one.
- **The selftest prints two `[meshy] OK:` lines** from the `approve` cases. Harmless (CI reads the
  exit code) and honest, but it is output from a test, not from a run.
- **CI has not run yet**; `meshy.py selftest`, `privacy_scan.py selftest`/`scan` and the harness all
  pass locally.

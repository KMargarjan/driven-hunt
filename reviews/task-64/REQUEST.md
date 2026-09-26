# Task 64 — URGENT: the refine's texture type, and a rejected request that killed a paid run

Task: 64
Round: 1
Base: `aedf37b` (`main`, with Task 62 merged)
Code commit: `08e292da29b83a15251586edc8b61f3ea96f9bd4` — the `[harness]` line below names it, and it
is the last commit that changed `src/`, `tests/` or `tools/`.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 08e292da29b83a15251586edc8b61f3ea96f9bd4 (clean tree)

374 server and 84 client specs, unchanged: **no `src/` and no `tests/` file is touched.** The harness
ran because `tools/` changed. **No `[harness2]`**: `agents.py`'s `TWO_PLAYER_PATHS` is `src/`,
`tests/client/` and `tools/studio_mcp.py`, none of them here. **Nothing in this task called a
generation endpoint, spent a credit, or made any network call at all** — one documentation page was
re-read, by me, in a browser tool.

## Why this is urgent

Both defects come from the Asset agent's **first real refine**. Meshy deletes the approved preview
`boar.body_v1-20260926T1501Z` on **2026-09-29 15:02 UTC**; the 20 credits already spent go with it.
The run was stranded — `refine` refused it and `resume` refused it — and is now back at `approved`
(claim 8).

## Claims

1. **`texture_resolution` is a STRING, from the documentation.** Re-read 2026-09-26 at
   <https://docs.meshy.ai/en/api/text-to-3d>: *"texture_resolution (string): `"2k"`, `"4k"`, or
   `"8k"` (default `"2k"`)"*. Quoted in the research note as **D12**, with the three consequences.
   Verify: `docs/research/2026-09-26-meshy.md` item D12 and the answer-4 row; `REQUEST_FIELDS`.

2. **THERE IS NO 1k, and the tool says so rather than pretending.** `TEXTURE_RESOLUTION` maps
   2048/4096/8192 to `"2k"`/`"4k"`/`"8k"`; `resolve_texture` takes the smallest offered size not
   below the brief's budget, so `docs/asset-briefs/tree.oak_v1.brief.json` (`texturePx: 1024`,
   asset-pipeline §12.2's ordinary-key budget) is refined at `"2k"` — with a printed note, and
   recorded on the run as `textureResolution {asked, px, briefPx}`. `validate_fetched` judges the
   maps against **what was asked for**, because calling them oversized would strand a run that did
   exactly what it was told. Verify: `resolve_texture`, `cmd_refine`, `validate_fetched`'s `budget`;
   the `texturePx 1024 is asked for as 2k` case. Downscaling is queued as 64a(a).

3. **Every request field has its documented type, checked before anything is sent.**
   `REQUEST_FIELDS` is the one table; `check_request_types` refuses a wrong type, an undocumented
   value, and a field the docs do not list, naming the field, what it is and what is documented.
   It runs **twice**: in the builder that made the body, and inside `request`, the last place bytes
   leave the process — so a future builder that forgets cannot spend a credit on a 400. Verify:
   `check_request_types`, the three `build_*_request` functions, `request`'s first two lines;
   the cases *"a NUMERIC texture_resolution is refused, by name and by type"* and *"request()
   refuses a wrong-typed POST body before it sends anything"*.

4. **The fixture now comes from the documentation.** The frozen refine body asserted
   `"texture_resolution": 2048` — written from the code, so the one test that could have caught this
   agreed with the bug. It asserts `"2k"`, and a numeric size is its own named refusal case. Verify:
   *"refine asks for exactly the documented four fields, texture_resolution as a STRING"*.

5. **A request the API rejected is not a dead run.** `stop_unstarted` leaves the record **untouched**
   — no write, no save — prints the error, says *no task exists and no credit was spent*, names the
   state the run is still in and the exact command to retry. `start_task` uses it for every non-2xx
   POST. Verify: `stop_unstarted`, `start_task`; *"a refine the API rejects exits 1"* → *"the run is
   STILL approved, not failed"* → *"so refining again works"* → *"reaches refine-ready"*.

6. **`failed` has exactly one writer, and two reasons.** `fail_terminal` is the only place
   `record["state"] = "failed"` appears, and it records `failureKind`: **a Meshy task that RAN and
   came back FAILED or CANCELED**, or **a response that could not be read** — a 2xx with no task id,
   where a task may exist that this tool cannot name, so a retry would pay twice and the line sends
   the operator to the dashboard instead. A ceiling still refuses before any of this and writes
   nothing. Verify: `fail_terminal`, `poll_and_finish`'s `done and not ok` branch, `start_task`'s
   no-id branch. `grep -n 'state.*=.*"failed"' tools/meshy.py` gives five hits: one in
   `fail_terminal`, and four inside `selftest`, which builds failed records by hand as fixtures.

7. **One POST path for all three phases.** `cmd_preview` carried its own copy of `start_task`, which
   is why the defect existed in two places; it now calls `start_task` with its own retry command
   (`preview <key>_v<N>`, which mints a new run id, so nothing is overwritten). Verify: `cmd_preview`'s
   last line, `start_task`'s signature.

8. **`revive` — narrow, explicit, logged — and it was used on the real run.** It requires `failed`,
   and refuses: a record carrying a `failureKind` (this build's own terminal failures), any task that
   is not `SUCCEEDED`, and a task for the step that was rejected. It restores the state derived from
   the run's own tasks, appends a `revivals` entry, and names the next command. Run for real:

       [meshy] OK: revive boar.body_v1-20260926T1501Z failed -> approved (no refine task exists;
       logged on the run) -- next: python tools/meshy.py refine boar.body_v1-20260926T1501Z

   `status` then shows `approved, 1 task(s), credits=20 expires 2026-09-29T15:02:51Z`, and
   `refine --dry-run` prints the body with `"texture_resolution": "2k"`. **No real refine was run —
   that is the Asset agent's, after merge.** Verify: `cmd_revive`, `state_before_failure`,
   `next_phase`; the four revive cases.

9. **EIGHT MUTATIONS, all caught by named cases** (2026-09-26; each applied, `selftest` run, then
   restored): the type check's unknown-field branch; the whole type check (10 cases fail); the pixel
   count sent again (the dry run and the chain both fail, by the exact 400 message); a rejected POST
   called `failed` again (*"the run is STILL approved"* fails and the retry is refused); `revive`'s
   not-SUCCEEDED guard; an invented `"1k"`; the check inside `request`; and `failureKind`.

10. **Nothing else moved.** No `src/`, no `tests/`, no design file. The module docstring gained the
    two rules; `TASKS.md` gained rows 64 and 64a.

## What I could not verify

- **Nothing was sent to Meshy.** The corrected body is proven only in shape — by the dry run and by
  the type table. Only the Asset agent's real `refine` proves Meshy accepts it (64a(d)).
- **The documentation is the only source for the type.** I re-read one page; I did not test `"4k"`,
  `"8k"`, `texture_prompt` or `ai_model` against the API.
- **What the maps will actually look like** at 2k for a 1024 brief, and whether downscaling belongs
  in `promote`, is a Director/Architect call (64a(a)).
- **`revive` cannot be exercised on a record this build wrote**, by construction — it refuses them
  all. Its cases build the old shape by hand.
- **The stranded run's 20 credits are recoverable, not recovered**: the refine still has to run
  before 2026-09-29 15:02 UTC.

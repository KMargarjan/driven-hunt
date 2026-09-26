# Task 55 — the Meshy tool and the ASSET agent (design Task A: the boar, to the preview)

Task: 55
Round: 1
Base: `4ee25d2` (`main`, everything through Task 50 merged. Tasks 52 and 53 are unmerged and this
branch does not carry them)
Code commit: `e935a894ba05cf7b5904364b98bb3183c5b2efdb` — the `[harness]` line below names it, it is
the last commit that changed `src/`, `tests/` or `tools/`, and only this request changes after it.

Harness, clean tree, one player:

    [harness] PASS: 28/28 checks @ e935a894ba05cf7b5904364b98bb3183c5b2efdb (clean tree)

**No `[harness2]`, and none is needed.** Nothing under `src/`, `tests/` or `tools/studio_mcp.py` is
touched — `agents.py`'s `TWO_PLAYER_PATHS` is exactly those three. The harness ran at all only
because `tools/` changed; this tool puts nothing in the DataModel and must never be wired into the
harness (design §13.4).

## Scope

**Design §14 Task A only:** the preview half. `refine`, `remesh`, `fetch` and `promote` are Task B
and are deliberately **not here** — they import from `tools/assets.py`, which does not exist yet
(design §0 item 6).

## Rule 1 came first, and seven of its answers changed the build

The design was written by a session with **no network** (its own §0 item 1) and listed ten strings in
§10.1 that had to be fetched before any code. `docs/research/2026-09-26-meshy.md` answers all ten with
quotes, URLs and the date. Seven changed something:

| Fetched | What changed |
|---|---|
| `PENDING, IN_PROGRESS, SUCCEEDED, FAILED, CANCELED` | **`CANCELED` is a fifth value the brief never named.** Terminal, not success |
| `consumed_credits` is returned per task | credits are **recorded**, never estimated |
| remesh reports **no** polycount | the triangle count stays **declared**; §7.3's "assert reported ≤ target" can never run |
| refine takes `texture_resolution` | §15 Director D answered: 2048 is **asked for**, not hoped for |
| 429 carries `RateLimitExceeded` vs `NoMoreConcurrentTasks` | the message names which; `Retry-After` is undocumented and is honoured only if present |
| *"deleted three (3) days after it is **generated**"* | expiry runs from `created_at`, **not** the design's `finished_at` — earlier, therefore safe |
| `usage/tasks` is Studio/Enterprise-only | the free auth check answers **403** on Karen's plan, and that is success, not failure |

## Claims

1. **The key is read, and never printed.** Read once from `os.environ`, else from
   `HKCU\Environment` with `winreg`, read-only. **Measured: the key came from the registry**, because
   this shell started before the variable existed — the exact case design §6.1 predicted, exercised
   for the first time. `key` prints `fingerprint 48a80096, source=registry` and nothing else. Verify:
   `read_key`, `_registry_key`, `fingerprint`, `cmd_key`.

2. **Redaction is asserted over the full rendered output, not trusted.** Selftest case 5 builds every
   line the tool can emit — headers, both `describe_http_failure` branches, a `Failed` string, the
   `key` line — with a fake key, and asserts the fake key appears in **none** of them. Verify:
   `selftest`'s "Key redaction" block; `redact`.

3. **The one real call cost nothing and proved the key works.** `python tools/meshy.py key --check`:
   *"[meshy] OK: the key was accepted and REFUSED BY PLAN. usage/tasks is Studio/Enterprise-only
   (research note D11), so 403 here means the key reached Meshy and was read -- it does NOT mean the
   key is wrong. 0 credits spent"*, exit 0. **No generation endpoint was called and no credit was
   spent by this task.** Verify: `cmd_key`, and the note's D11.

4. **Which endpoint is data, not a flag**, and nothing deprecated is sent. 0 references → text-to-3D,
   1 → image-to-3D, 2–4 → multi-image, from the count alone. The text body is asserted against a
   **frozen fixture** (`EXPECTED_TEXT_BODY`), so a later edit to the builder shows up as a diff — the
   body is what costs money and what decides the model. `art_style`, `negative_prompt`, `symmetry`,
   `seed`, `rig` and `rigging` are asserted **absent** from every built body. Verify:
   `choose_endpoint`, `build_preview_request`; selftest case 3.

5. **Every refusal names its own reason, and each is asserted on the reason.** The name grammar
   (6 cases) and the brief validator (12 cases) are each checked for the *text* of the refusal, not
   just that something was raised — a test that only checks "it refused" passes when the wrong rule
   fires. Verify: `parse_brief_name`, `validate_brief`; selftest cases 1–2.

6. **An unknown status is not success, and a missing one fails loudly.** `SUCCEEDED` succeeds;
   `FAILED` and `CANCELED` are terminal with `task_error.message` extracted; `PENDING`/`IN_PROGRESS`
   are running; anything else is **not success** and says so; a response with no `status` raises
   rather than defaulting. This is the `MODERATION_STATE_` lesson made a test. Verify: `read_status`;
   selftest case 4.

7. **The money ceilings refuse before any request, from the records on disk.** `MAX_TASKS_PER_RUN`
   (4) and `MAX_TASKS_PER_DAY` (12), counted across every run record, so a crashed session does not
   reset them; both asserted at the boundary and one past it. A task 25 h old does not count.
   Verify: `check_ceilings`, `tasks_today`; selftest case 6.

8. **The 3-day trap is visible and the arithmetic is tested.** `expiresAt` = `created_at` + 72 h;
   `runs` prints `EXPIRES IN <n>h` under 24 h and `EXPIRED` past it; `resume` on an expired run
   refuses with *"it cannot be regenerated identically -- there is no seed"*. **No URL is ever
   persisted**: the run record keeps the task id, and a fresh URL is minted by re-polling. Verify:
   `expiry_of`, `expiry_line`, `cmd_resume`; selftest case 7.

9. **Nothing this tool prints could fail CI**, checked by importing CI's own rules. Selftest case 9
   runs `tools/privacy_scan.py`'s rules over the tool's rendered output, its docstring and its
   licence block, and asserts **no rule fires** — and then asserts the new `meshy-key` rule *does*
   catch a `msy_` token, so the guard is not vacuous. `privacy_scan.py` gains that rule assembled
   from pieces, so it still matches nothing in itself; **Meshy's own example key is deliberately not
   quoted in full in the research note**, because a scanner taught an exception for documentation
   will one day be taught one for a real key. Verify: `selftest` case 9; `RULES`'s `meshy-key`.

10. **The role is written down and honest about what it is not.** `docs/ASSET_PROMPT.md` gives the
    job, the two stop points, "look at the image" (rule 5), the never-list, the output markers, and a
    section separating what `tools/meshy.py` and CI **enforce** from what is only policy — ending
    **"You are not sandboxed"**, because `--allowedTools` is not enforced here (`tools/agents.py`,
    item 1). `CLAUDE.md` gains the role row, the `ASSET_RESULT.md` row, the layout rows and the
    Meshy key line; `GAME_DESIGN.md` gains the two owner rows; CI gains
    `python3 tools/meshy.py selftest`; `.gitignore` gains `/.meshy/`.

## What I could not verify

- **No model has been generated.** This task spends nothing by design, so `preview` against the real
  API, the polling loop, the download and `finish_preview` have **never run**. They are exercised
  only by `--dry-run` and the offline selftest. The first real preview is the Asset agent's, watched
  by a human, and it is the next task.
- **`licenceBasis = "meshy-paid-owned"` rests on Karen's statement, not on a measurement.** The Terms
  make ownership conditional on a paid plan, and no API call can prove the plan — `usage/tasks`
  answers 403 for everything below Studio. Recorded in the run record; queued as row 55a(c).
- **The Terms allow Meshy to train on non-Enterprise output** — *"unless otherwise agreed to in the
  Order"* — and paid is not Enterprise. The Director's recorded default is accept. It is in the note
  so the decision is on the record rather than assumed; it is **Karen's**, not mine.
- **Three deltas are queued, not decided** (row 55a): the reference images are JPEG/WebP while the
  validator accepts PNG only (Meshy accepts both, so all three positions are defensible); briefs now
  exist in two places (`docs/asset-briefs/` as the reviewed record, `<assets-dir>/briefs/` as what
  the tool reads); and the brief's "API keys need a paid plan" is **not** in the authentication docs.
- **`ASSET_DROP_DIR` is not set on this machine.** `brief` and `preview --dry-run` were exercised
  against a temporary drop folder outside the repo; the refusals for unset and for inside-the-repo
  were both confirmed (exit 2, with the reason). Karen still has to set the variable.

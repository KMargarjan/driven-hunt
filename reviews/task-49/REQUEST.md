# Task 49 — privacy: scrub the local absolute paths, and a CI check that keeps them out

Task: 49
Round: 1
Base: `fec5631` (`main`; everything through Task 48 plus audit-004 is merged)
Code commit: `a6815fcc41188206d33b306b14f2fba73ccbaa8e` — the harness line below names it, it is the
last commit that changed `src/`, `tests/` or `tools/`, and only this request changes after it
(CLAUDE.md git workflow step 4).

Harness, clean tree, one player:

    [harness] PASS: 28/28 checks @ a6815fcc41188206d33b306b14f2fba73ccbaa8e (clean tree)

307 server specs and 75 client specs, unchanged by this task: no `src/` and no `tests/` file is
touched. The harness ran because the change adds a file under `tools/`.

**No `[harness2]`, and it is not needed.** `tools/agents.py`'s `TWO_PLAYER_PATHS` is `src/`,
`tests/client/` and `tools/studio_mcp.py`; this task touches none of them. `tools/privacy_scan.py` is
a new file that never runs in Studio. The Director's dispatch says the same ("otherwise the CI run is
the evidence").

## What changed

Two halves of one job, plus the record.

1. **The scrub.** Nine local absolute Windows paths in four tracked files become placeholders. This
   closes `TASKS.md` row 39a(h), open since Task 39.
2. **The check.** `tools/privacy_scan.py`, a new step in `.github/workflows/ci.yml`, fails the build
   on a local user path, on an email that is not the GitHub noreply form, and on a secret shape.
3. **The record.** `CLAUDE.md`'s "Public repository" section gains the CI check and the Director's
   decision *not* to rewrite history, dated 2026-09-26.

Nothing under `src/`, `tests/` or `assets/` is touched. No design and no research note: this is CI
hygiene, not a game system (said so in the tool's docstring, so the next reader does not go looking
for a note in `docs/research/INDEX.md`).

## Claims

1. **The nine paths are gone, and only placeholders remain.** `git grep -I -n -F 'C:\Users'` returns
   three lines: `docs/architecture/audit-004.md` twice (`C:\Users\...` and `C:\Users\<user>\...`, both
   the audit quoting itself) and `docs/research/2026-09-24-map-generator.md` once
   (`C:\Users\<user>\AppData\Local\Roblox\RobloxStudio\AutoSaves`). All three are placeholders and are
   meant to stay — the autosave location is real documentation. The nine that went are in
   `ESCALATE.md` (3), `TASKS.md` (3), `reviews/task-37/BRIEF.md` (1) and `reviews/task-39/RESULT.md`
   (2); `git diff fec5631..a6815fc -- ESCALATE.md TASKS.md reviews/` shows each one.

2. **`docs/design/asset-pipeline.md` needed no edit, contrary to row 39a(h).** Its §7.2 already reads
   "this document calls it `<assets-dir>` and never writes it out, because the repo is public". The
   Architect had already fixed it; the row was written against the Task 37 design. Verify: read §7.2,
   and `git grep -I -n -F 'C:\Users' -- docs/design/` is empty.

3. **The scanner catches every shape it claims to, and allows the forms that must stay legal.**
   `python tools/privacy_scan.py selftest` prints
   `[privacy] selftest PASS: 22 shapes caught, 15 allowed forms clean, self-scan clean` and exits 0.
   The 22 are in `CAUGHT` and the 15 in `ALLOWED` in `tools/privacy_scan.py`. The allowed list is the
   interesting half: `<name>@users.noreply.github.com`, the `noreply@anthropic.com` commit trailer,
   `C:\Users\<user>\AppData\Local`, `%USERPROFILE%`, `$HOME/...`, `<repo>`/`<assets-dir>`/`<runs-dir>`,
   `setup-rokit@v0.2.1`, `actions/checkout@v7`, `testez@0.4.1`, `x-api-key: <key>`, and the words
   `.ROBLOSECURITY` and `*.pem` as prose — because `CLAUDE.md` and `.gitignore` must keep passing.

4. **The scanner passes its own scan, with no self-exclusion and no allowlist.** Every rule pattern
   and every selftest sample is assembled from pieces at run time (`_AT`, `_BEGIN`, `_BS`,
   `"AKIA" + "IOSFODNN7EXAMPLE"`, and so on), so the file on disk contains no string its own rules
   match. `selftest`'s last case reads `tools/privacy_scan.py` off disk and runs every rule over it;
   a rule that matched would be reported as a failure. Verify by reading `selftest` — the block after
   "The scanner must pass its own scan" — and `RULES` / `CAUGHT`.

5. **It bites: run against the pre-scrub tree it finds exactly the nine paths.**
   `findings_in()` over `git show main:ESCALATE.md`, `main:TASKS.md`,
   `main:reviews/task-37/BRIEF.md` and `main:reviews/task-39/RESULT.md` gives 9 `local-path` findings
   (ESCALATE 3, TASKS 3, BRIEF 1, RESULT 2 — two on one line each in `TASKS.md` row 39a and
   `RESULT.md`). Against the scrubbed tree: `[privacy] PASS: 0 findings in 223 tracked text files` at the code commit (224 once this
   request is committed).
   This is the evidence that the check is not vacuously green.

6. **Two rules exist because the first draft got them wrong, and the selftest is what caught it.**
   (a) The email rule's last label must be alphabetic, or `setup-rokit@v0.2.1` and `testez@0.4.1`
   read as addresses. (b) `assigned-secret` uses `(?<![A-Za-z0-9])`, not `\b`, before the name:
   in `ROBLOX_API_KEY` the underscore is a word character, so `\b` missed exactly the spelling a CI
   variable uses. Both are commented at the rule. This is claim 3's point made concrete: the
   selftest, not the scan, is what proves the rules work.

7. **False positives are bounded by look-behinds, not by luck.** `local-path` will not fire on
   `https://example.com/home/page` (the `/home` is preceded by a word character) and skips any
   segment starting `<`, `%`, `$`, `{` or `...`. `webhook-url` stops at a quote, backtick or angle
   bracket rather than at whitespace. `assigned-secret` needs 20+ credential-shaped characters after
   the name, so `x-api-key: <key>` and `--dry-run` prose do not match. Verify: `RULES`, plus the
   whole-tree scan in claim 5 over 223 files with 0 findings — 40 of which are `docs/` files full of
   URLs, keys named in prose, and quoted API headers.

8. **CI runs both, `selftest` first.** `.github/workflows/ci.yml`'s last step,
   "Privacy and secret scan (local paths, emails, secret shapes)", runs
   `python3 tools/privacy_scan.py selftest` then `... scan`, with `if: success() || failure()` like
   every other lint step so one run reports every problem. Ordering is deliberate and commented: a
   scan that passes because a pattern silently stopped matching is worse than no scan. Exit codes
   follow the harness's shape — 0 clean, 1 findings, 2 refused.

9. **History is not rewritten, and the reason is written down.** `CLAUDE.md`'s "Public repository"
   section now carries the Director's 2026-09-26 decision: the repo has been public since its first
   commit, so a rewrite un-publishes nothing, and it would break every PR, commit and review link
   recorded in `TASKS.md`, `ESCALATE.md` and `reviews/`. What the old commits leak is one Windows
   account name in a path. The existing rule for a real secret — revoke or rotate first — is
   unchanged and sits directly below.

10. **The paperwork is consistent.** `CLAUDE.md`'s Layout table names `privacy_scan.py` in the
    `tools/` row. `TASKS.md` row 49 records both halves, the placeholders, the 9-to-0 measurement and
    the history decision. The one edit made to a verbatim Director dispatch (`TASKS.md`, the Task 39
    section) is marked in a sentence above the quote, naming Task 49 and the reason, rather than made
    silently — `CLAUDE.md` gives the Builder the right to transcribe verbatim, so changing a quote is
    disclosed.

## What I could not verify

- **CI itself has not run yet** at the time of writing: the branch is pushed in the same round, and
  the GitHub Actions result is the Director's to read on the PR. What is verified locally is that
  both commands exit 0 on this tree, and that the runner image has `python3` (ubuntu-latest does).
  The step uses no action and no network.
- **`[harness2]` was not run**, by the rule above. I did not run it and am not claiming it.
- **No screenshot**: nothing visual changed. The task touches no `src/` file, so there is nothing on
  screen to photograph (rule 5 N/A).
- **The scanner is a shape check, not proof of absence.** A secret that looks like ordinary prose — a
  password that is a dictionary word, a bare token with no assignment near it — passes. It narrows
  the window; `git diff --cached` before every commit is still the rule, and that is said in
  `CLAUDE.md` in the line directly after the new one.
- **The three surviving `C:\Users\` placeholders are a judgement call**, not a measurement: I read
  all three and they carry no account name. If the Director would rather have no `C:\Users` string at
  all in the tree, that is a one-line change to each and a stricter rule, and it costs the autosave
  location its precision.

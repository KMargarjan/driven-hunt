"""Spawns the REVIEWER and ARCHITECT as fresh, headless, read-only Claude sessions.

Entry points (thin wrappers around this file):
  tools/review.sh    | tools/review.ps1 [N]                       -> python tools/agents.py review [N]
  tools/architect.sh | tools/architect.ps1 design <sys> --task N  -> agents.py architect design <sys> --task N
  tools/architect.sh | tools/architect.ps1 audit --task N         -> agents.py architect audit --task N

Every file of the loop lives in ONE FOLDER PER TASK (Task 21): `reviews/task-<N>/REQUEST.md`,
`RESULT.md` and `ARCH_RESULT.md`. Branches therefore stop conflicting on the same root files, and -
the point of the change - **the round count is per task**: a merged task whose last verdict was
FINDINGS can no longer block the next task's round 1 (the fault Task 22 hit, ESCALATE.md 2026-09-25).
The task number comes from the `Task: N` line in the request and must match its folder. With no
argument, `review` takes the most recently committed `reviews/task-*/REQUEST.md`.

Pattern: headless `claude -p` agents with a hard read-only sandbox, and the result written by this
script, never by the agent. Workflow: CLAUDE.md "Four-agent workflow".

How read-only is enforced (tested 2026-09-24, Claude Code 2.1.270). Each layer covers a gap in the others:
  1. `--restricted --tools Read,Grep,Glob`: the agent has exactly three tools, with no Bash,
     Write/Edit, messaging or network. A plain `--allowedTools` Bash allow-list was NOT enforced in
     this environment (a test session created a file through Bash anyway), and without `--restricted`
     a session could reach other live sessions via SendMessage. Hence the exact tool set.
  2. The agent runs in a throwaway `git worktree` of the commit under review, not the working tree.
  3. The agent's stdout is parsed for `=== BEGIN X === ... === END X ===` blocks, and this script
     writes REVIEW_RESULT.md / ARCH_RESULT.md / the document.
  4. The script refuses to write anything if HEAD or `git status` of the real repo changed during the run.
Because the agent cannot run commands, this script precomputes tool output (diff, log, lint, build,
sourcemap) into `.agent-evidence/` inside the worktree.

The 3-round stop rule is counted from the verdict, not from the request, and **within one task**:
`Round: N` in `reviews/task-<N>/REQUEST.md` must equal the round in that task's committed `RESULT.md`
trailer plus one (or 1 when the task has no verdict yet, which is every task's first round - no
DIRECTOR_MAX_ROUNDS needed). The trailer is written only by `trailer()` here, so the Builder cannot
raise or skip the round from the request, and deleting the trailer is caught by
`last_committed_review()`, which looks back over that one file's git history.
The cap is `MAX_ROUNDS` (3), or `DIRECTOR_MAX_ROUNDS` when the Director has authorised one more round
in ESCALATE.md for that task. It is an environment variable, so it cannot be committed by accident,
it may only raise the cap, and the run prints it.

**Harness before review** (Task 21): a change that touches `src/`, `tests/` or `tools/` is refused
unless the request pastes a harness line `[harness] PASS: n/m checks @ <code commit> (clean tree)`
naming that request's `Code commit:`. Task 18 was reviewed three times before its code had ever run;
that cannot happen again. Docs-only changes are exempt.
**And the TWO-PLAYER line** (`[harness2] PASS: ... (clean tree)`) for the same commit when the
change touches `src/`, `tests/client/` or `tools/studio_mcp.py` - Director decision 2026-09-26. A
driver, a tie, a team swap and half the client suite exist only with two clients, so a one-player
run is not evidence for gameplay or for the harness that drives them. Docs, and the tools that are
not the harness, stay exempt, because `test2` costs a human click.
**What is still policy, not enforcement:** nothing stops a Builder committing a hand-written trailer
(the Builder owns the repo and the commits), and `git rebase`/`--force` could drop the history the
look-back reads. audit-002 must-fix #5 (Task 12) is about exactly that: the verdict files must be
writable only by these scripts.

Exit codes: 0 PASS, 1 findings (numbered list), 2 refused or error (nothing written).
Each call is one paid Claude session: see CLAUDE.md "Costs".
"""

import datetime
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROKIT_BIN = os.path.expanduser(os.path.join("~", ".rokit", "bin"))
MAX_ROUNDS = 3
HISTORY_SCAN = 50  # commits of one task's RESULT.md history the round check looks back over
REVIEWS = "reviews"  # reviews/task-<N>/{REQUEST,RESULT,ARCH_RESULT}.md
# A change touching any of these must show a harness PASS before it may be reviewed.
CODE_PATHS = ("src/", "tests/", "tools/")
# ...and a change touching any of THESE must also show the TWO-PLAYER line. Director decision,
# 2026-09-26: gameplay (src/) and anything that can only be exercised with two clients (the client
# specs, the harness itself) are not evidenced by a one-player run. Everything else -- docs, and the
# tools that are not the harness -- is exempt, because test2 costs a human click and eight minutes.
TWO_PLAYER_PATHS = ("src/", "tests/client/", "tools/studio_mcp.py")
AGENT_TIMEOUT_S = 3600


class Refused(Exception):
    pass


def max_rounds():
    """MAX_ROUNDS, or the Director's one-off override in DIRECTOR_MAX_ROUNDS.

    Set only for a run the Director has authorised in ESCALATE.md for that task and round
    (CLAUDE.md "Stop rules"). It is an environment variable, not a file, so it cannot be committed
    by accident and does not survive the run."""
    raw = os.environ.get("DIRECTOR_MAX_ROUNDS")
    if raw is None or not raw.strip():
        return MAX_ROUNDS
    if not re.fullmatch(r"[0-9]{1,2}", raw.strip()):
        raise Refused(f"DIRECTOR_MAX_ROUNDS must be a small integer; got {raw!r}")
    n = int(raw.strip())
    if n < MAX_ROUNDS:
        raise Refused(f"DIRECTOR_MAX_ROUNDS={n} is below MAX_ROUNDS={MAX_ROUNDS}; it may only raise the cap")
    print(f"[agents] DIRECTOR_MAX_ROUNDS={n} (default {MAX_ROUNDS}); "
          "ESCALATE.md must record the Director's authorisation for this task and round", flush=True)
    return n


def run(cmd, cwd=REPO, check=True):
    env = dict(os.environ, PATH=ROKIT_BIN + os.pathsep + os.environ.get("PATH", ""))
    # Windows does not search env["PATH"] for the executable, so resolve it explicitly.
    exe = shutil.which(cmd[0], path=env["PATH"])
    if not exe:
        if check:
            raise Refused(f"`{cmd[0]}` not found on PATH (is Rokit installed? `rokit install`)")
        return subprocess.CompletedProcess(cmd, 127, "", f"`{cmd[0]}` not found on PATH\n")
    r = subprocess.run([exe, *cmd[1:]], cwd=cwd, capture_output=True, text=True, encoding="utf-8",
                       errors="replace", env=env)
    if check and r.returncode != 0:
        raise Refused(f"{' '.join(cmd)} failed ({r.returncode}): {r.stderr.strip()[:500]}")
    return r


def git(*args, cwd=REPO):
    return run(["git", *args], cwd=cwd).stdout


def repo_state():
    return git("rev-parse", "HEAD").strip(), git("status", "--porcelain")


# ------------------------------------------------------------------ evidence

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def tool_output(cmd, cwd):
    r = run(cmd, cwd=cwd, check=False)
    return f"$ {' '.join(cmd)}\n(exit {r.returncode})\n{r.stdout}{r.stderr}"


def build_evidence(wt, base=None, code_commit=None):
    """Precompute everything the agent would otherwise have to run. Keep the lint/build commands in step
    with .github/workflows/ci.yml."""
    ev = os.path.join(wt, ".agent-evidence")
    head = git("rev-parse", "HEAD", cwd=wt).strip()
    files = {
        "head.txt": f"commit under review: {head}\nbranch: {git('rev-parse', '--abbrev-ref', 'HEAD').strip()}\n",
        "ls-files.txt": git("ls-files", cwd=wt),
        "lint-selene.txt": tool_output(["selene", "src"], wt) + "\n"
                           + tool_output(["selene", "--config", "tests/selene.toml", "tests"], wt)
                           if os.path.exists(os.path.join(wt, "tests", "selene.toml"))
                           else tool_output(["selene", "src", "tests"], wt),
        "lint-stylua.txt": tool_output(["stylua", "--check", "src", "tests"], wt),
        "rojo-build.txt": tool_output(["rojo", "build", "default.project.json", "--output",
                                       os.path.join(tempfile.gettempdir(), f"dh-agent-{head[:8]}.rbxl")], wt),
        "sourcemap.json": run(["rojo", "sourcemap", "default.project.json", "--include-non-scripts"],
                              cwd=wt, check=False).stdout,
    }
    if code_commit:
        changed = git("diff", "--name-only", f"{code_commit}..HEAD", cwd=wt).split()
        extra = [f for f in changed if not is_paperwork(f)]
        lines = [f"Code commit (tested by the harness): {code_commit}",
                 f"Commit under review: {head}",
                 f"Files changed between them: {changed or 'none'}",
                 f"Not paperwork: {extra or 'none'}",
                 "OK: only the loop's own paperwork changed after the tested commit, so the harness line for the "
                 "code commit applies to HEAD (CLAUDE.md git workflow step 4 lists what may follow it)."
                 if not extra else
                 "NOT OK: a file that is not paperwork changed after the tested commit, so the harness line does "
                 "NOT cover HEAD. That is a finding."]
        files["paperwork-after-code-commit.txt"] = "\n".join(lines) + "\n"
    if base:
        files["log.txt"] = git("log", "--stat", f"{base}..HEAD", cwd=wt)
        files["changed-files.txt"] = git("diff", "--name-status", f"{base}...HEAD", cwd=wt)
        files["diff.patch"] = git("diff", f"{base}...HEAD", cwd=wt)
    index = ["# Evidence index", "", f"Precomputed by tools/agents.py for commit `{head}`.",
             "The agent cannot run commands; these are the outputs it would have needed.", ""]
    for name, text in files.items():
        write(os.path.join(ev, name), text)
        index.append(f"- `.agent-evidence/{name}` ({len(text.splitlines())} lines)")
    index += ["", "DevPackages/ (git-ignored TestEZ) is not in the worktree, so the sourcemap omits it (optional path).",
              "Roblox Studio is not available: harness claims can be checked only for consistency."]
    write(os.path.join(ev, "INDEX.md"), "\n".join(index) + "\n")


# ------------------------------------------------------------------ agent

def run_agent(role, prompt_file, task_text, wt):
    # From the worktree, not REPO: the prompt must come from the commit under review, so that an
    # uncommitted edit cannot drive the session (review round 1, finding 4).
    with open(os.path.join(wt, prompt_file), encoding="utf-8") as f:
        prompt = f.read().split("\n---\n", 1)[-1]  # drop the file's own header
    prompt += "\n\n## This run\n" + task_text + "\n"
    claude = shutil.which("claude")
    if not claude:
        raise Refused("`claude` CLI not found on PATH")
    cmd = [claude, "-p", prompt, "--restricted", "--tools", "Read,Grep,Glob", "--permission-mode", "dontAsk",
           "--strict-mcp-config", "--no-session-persistence", "--output-format", "json"]
    print(f"[agents] spawning {role} (headless, read-only) in {wt} ...", flush=True)
    r = subprocess.run(cmd, cwd=wt, capture_output=True, text=True, encoding="utf-8", errors="replace",
                       timeout=AGENT_TIMEOUT_S)
    logs = os.path.join(REPO, ".agent-logs")
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    write(os.path.join(logs, f"{stamp}-{role}.json"), r.stdout or r.stderr)
    try:
        data = json.loads(r.stdout)
    except json.JSONDecodeError:
        raise Refused(f"{role} session did not return JSON (exit {r.returncode}): {(r.stderr or r.stdout)[:500]}")
    if data.get("is_error"):
        raise Refused(f"{role} session reported an error: {str(data.get('result'))[:500]}")
    return data.get("result", ""), data.get("total_cost_usd"), data.get("num_turns")


def block(text, name):
    m = re.search(rf"=== BEGIN {name} ===\r?\n(.*?)\r?\n=== END {name} ===", text, re.S)
    if not m:
        raise Refused(f"agent output has no `=== BEGIN {name} ===` ... `=== END {name} ===` block")
    return m.group(1).strip("\n")


def verdict_of(result_text, name):
    first = next((l for l in result_text.splitlines() if l.strip()), "")
    if first.strip() == "PASS":
        return "PASS"
    if re.match(r"^\s*1\.\s", first):
        return "FINDINGS"
    raise Refused(f"{name} line 1 must be `PASS` or start with `1.`; got: {first[:120]!r}")


TRAILER_RE = re.compile(r"^REVIEWER verdict on commit `([0-9a-f]{40})` \(round (\d+)\)", re.M)


def parse_trailer(text):
    """(round, verdict) from a REVIEW_RESULT.md body, or (None, None) if it carries no trailer.

    The **last** match, not the first: `trailer()` appends it, and the Reviewer's own free text above
    it may quote an earlier trailer at the start of a line (review round 2, finding 2)."""
    matches = list(TRAILER_RE.finditer(text))
    if not matches:
        return None, None  # the placeholder, or a file this script never wrote
    m = matches[-1]
    first = next((l for l in text[:m.start()].splitlines() if l.strip()), "")
    return int(m.group(2)), ("PASS" if first.strip() == "PASS" else "FINDINGS")


def task_rel(task, name):
    """The repo-relative path of one of a task's loop files, in git's spelling (forward slashes)."""
    return f"{REVIEWS}/task-{task}/{name}"


def is_paperwork(path):
    """True for the loop's own files, the only ones that may change after the code commit
    (CLAUDE.md git workflow step 4): anything under `reviews/`, the escalation, queue and playtest
    files, and an Architect audit."""
    path = path.replace("\\", "/")
    return (path.startswith(REVIEWS + "/")
            or path in ("ESCALATE.md", "TASKS.md", "PLAYTEST.md")
            or re.fullmatch(r"docs/architecture/audit-\d{3}\.md", path) is not None)


def resolve_task(explicit=None):
    """(task number, request path) for this run.

    `explicit` (the optional CLI argument) wins. Otherwise the most recently **committed**
    `reviews/task-*/REQUEST.md`: `cmd_review` has already proved the tree clean, so the current
    task's request is committed. The filesystem is a fallback for a shallow clone."""
    if explicit is not None:
        if not re.fullmatch(r"[0-9]{1,4}", str(explicit)):
            raise Refused(f"task number must be digits; got {explicit!r}")
        task = int(explicit)
        if not os.path.exists(os.path.join(REPO, task_rel(task, "REQUEST.md"))):
            raise Refused(f"no {task_rel(task, 'REQUEST.md')}")
        return task, task_rel(task, "REQUEST.md")
    for path in git("log", "--format=", "--name-only", f"-{HISTORY_SCAN}", "--", REVIEWS).split():
        m = re.fullmatch(rf"{REVIEWS}/task-(\d+)/REQUEST\.md", path.replace("\\", "/"))
        if m and os.path.exists(os.path.join(REPO, path)):
            return int(m.group(1)), path
    found = [int(m.group(1))
             for d in glob.glob(os.path.join(REPO, REVIEWS, "task-*", "REQUEST.md"))
             if (m := re.search(r"task-(\d+)", d.replace("\\", "/")))]
    if not found:
        raise Refused(f"no {REVIEWS}/task-<N>/REQUEST.md found. Write the request first "
                      "(CLAUDE.md, the loop, step 4)")
    return max(found), task_rel(max(found), "REQUEST.md")


def previous_review(task):
    """(round, verdict) of the RESULT.md this script last wrote **for this task**, or (None, None).

    Read from the working tree, which `cmd_review` has already proved clean, so it is the committed
    file. The trailer is written only by `trailer()`, so the Builder cannot raise or skip the round
    by editing the request (review round 1, finding 2). Per task since Task 21: another task's
    verdict, merged or not, says nothing about this one."""
    path = os.path.join(REPO, task_rel(task, "RESULT.md"))
    if not os.path.exists(path):
        return None, None
    with open(path, encoding="utf-8") as f:
        return parse_trailer(f.read())


def last_committed_review(task):
    """(sha, round, verdict) of the newest commit whose RESULT.md **for this task** has a trailer.

    `previous_review()` alone cannot see that the file *lost* its trailer: deleting it or replacing
    it with a placeholder would silently reset the round to 1 (review round 2, finding 1). This
    looks back over that one file's history."""
    rel = task_rel(task, "RESULT.md")
    for sha in git("log", "--format=%H", f"-{HISTORY_SCAN}", "--", rel).split():
        text = run(["git", "show", f"{sha}:{rel}"], check=False).stdout
        rnd, verdict = parse_trailer(text)
        if rnd is not None:
            return sha, rnd, verdict
    return None, None, None


HARNESS_RE = re.compile(r"\[harness\]\s+PASS:\s*\d+/\d+\s+checks\s+@\s*([0-9a-f]{7,40})\s*\(clean tree\)")
# The two-player line has the same shape under a different tag. Both are written by
# tools/studio_mcp.py and nothing else; a request pastes them verbatim.
HARNESS2_RE = re.compile(r"\[harness2\]\s+PASS:\s*\d+/\d+\s+checks\s+@\s*([0-9a-f]{7,40})\s*\(clean tree\)")


def harness_gate(req, code_full, base, head):
    """Harness before review (Task 21).

    A change that touches src/, tests/ or tools/ may not be reviewed until it has RUN: the request
    must paste the harness's own PASS line for its `Code commit:`, on a clean tree. Task 18 was
    reviewed three times before any of its code had executed, and the first real run then failed
    three specs. Docs-only changes are exempt: the harness says nothing about them."""
    # TWO RANGES, UNIONED (TASKS.md 21a(b)). `base` comes from the request, so a `Base:` set to the
    # code commit made a tools/ change look docs-only and skipped this gate entirely. The second
    # range is one the request cannot choose: whatever the code commit itself introduced relative to
    # its own parent, plus anything after it. A Builder can still lie about the code commit, and that
    # is the policy half CLAUDE.md names -- but the free bypass is gone.
    ranges = [f"{base}...{head}", f"{code_full}~1..{head}"]
    seen = {}
    for spread in ranges:
        try:
            names = git("diff", "--name-only", spread).split()
        except Exception:
            continue  # a root commit has no parent, and a bad Base is the case above
        for f in names:
            if f.replace("\\", "/").startswith(CODE_PATHS):
                seen[f] = True
    changed = sorted(seen)
    if not changed:
        print("[agents] docs-only change: no harness line required", flush=True)
        return
    def pasted(pattern):
        return any(code_full.startswith(m.group(1)) for m in pattern.finditer(req))

    if not pasted(HARNESS_RE):
        roots = sorted({f.replace("\\", "/").split("/")[0] + "/" for f in changed})
        raise Refused(
            f"this change touches {', '.join(roots)} ({len(changed)} file(s)), so it must have RUN "
            f"before it is reviewed. Paste the harness's own line for the code commit:\n"
            f"  [harness] PASS: n/m checks @ {code_full} (clean tree)\n"
            "Run `python tools/studio_mcp.py test` on the clean tree first. Docs are exempt.")

    # THE TWO-PLAYER LINE, for the paths a one-player run cannot evidence (Director, 2026-09-26).
    # A driver, a tie, a team swap and half the client suite exist only with two clients, so a
    # change to gameplay or to the harness that drives them is not evidenced without one.
    two_player = [f for f in changed if f.replace("\\", "/").startswith(TWO_PLAYER_PATHS)]
    if two_player and not pasted(HARNESS2_RE):
        named = sorted({f.replace("\\", "/") for f in two_player})[:6]
        raise Refused(
            f"this change touches {', '.join(named)}"
            f"{' and more' if len(two_player) > len(named) else ''}, which a one-player run cannot "
            f"evidence. Paste the TWO-PLAYER line for the code commit as well:\n"
            f"  [harness2] PASS: n/m checks @ {code_full} (clean tree)\n"
            "Run `python tools/studio_mcp.py test2` on the clean tree (it needs one human click). "
            "Docs, and tools outside the harness, are exempt.")

    print(f"[agents] harness line(s) found for the code commit ({len(changed)} code file(s) changed, "
          f"{len(two_player)} needing two players)", flush=True)


# ------------------------------------------------------------------ worktree

class Worktree:
    def __enter__(self):
        self.dir = tempfile.mkdtemp(prefix="dh-agent-")
        self.path = os.path.join(self.dir, "wt")
        git("worktree", "add", "--detach", self.path, "HEAD")
        return self.path

    def __exit__(self, *exc):
        run(["git", "worktree", "remove", "--force", self.path], check=False)
        shutil.rmtree(self.dir, ignore_errors=True)
        run(["git", "worktree", "prune"], check=False)


def guarded(fn):
    """Run fn; refuse to write results if the real repo changed while the agent ran."""
    before = repo_state()
    result = fn()
    if repo_state() != before:
        raise Refused("the repo's HEAD or working tree changed during the agent run; nothing written")
    return result


def trailer(role, head, extra, cost, turns):
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    cost_s = f"${cost:.2f}" if isinstance(cost, (int, float)) else "unknown"
    return f"\n\n---\n{role} verdict on commit `{head}`{extra} · {now} · session cost {cost_s}, {turns} turns · " \
           f"written by tools/agents.py\n"


# ------------------------------------------------------------------ commands

def cmd_review(task_arg=None):
    head, dirty = repo_state()
    if dirty.strip():
        raise Refused("working tree is dirty: commit the change and the request first\n" + dirty)
    task, rel = resolve_task(task_arg)
    path = os.path.join(REPO, rel)
    with open(path, encoding="utf-8") as f:
        req = f.read()
    print(f"[agents] task {task}: reviewing against {rel}", flush=True)

    declared = re.search(r"^Task:\s*(\d+)", req, re.M)
    if not declared:
        raise Refused(f"{rel} needs a `Task: N` line (CLAUDE.md, the loop, step 4)")
    if int(declared.group(1)) != task:
        raise Refused(f"{rel} says `Task: {declared.group(1)}` but sits in task-{task}/. "
                      "The folder and the line must agree.")
    rnd = re.search(r"^Round:\s*(\d+)", req, re.M)
    base = re.search(r"^Base:\s*`?([^`\s]+)`?", req, re.M)
    code = re.search(r"^Code commit:\s*`?([0-9a-f]{7,40})`?", req, re.M)
    if not rnd or not base:
        raise Refused(f"{rel} needs `Task: N`, `Round: N`, `Base: <commit>` and `Code commit: <sha>` lines")
    if not code:
        raise Refused(f"{rel} needs a `Code commit: <sha>` line (the commit the harness tested)")
    code = git("rev-parse", "--verify", code.group(1) + "^{commit}").strip()
    rnd = int(rnd.group(1))
    prev_rnd, prev_verdict = previous_review(task)
    if prev_rnd is None:
        sha, h_rnd, h_verdict = last_committed_review(task)
        if sha:
            raise Refused(
                f"{task_rel(task, 'RESULT.md')} carries no verdict trailer, but commit {sha[:12]} "
                f"recorded round {h_rnd} ({h_verdict}) for this task. The round count cannot be reset "
                "by deleting or replacing that file. Restore it, or escalate.")
    expected = 1 if prev_rnd is None or prev_verdict == "PASS" else prev_rnd + 1
    if rnd != expected:
        raise Refused(
            f"`Round: {rnd}` in {rel}, but this task's committed RESULT.md is "
            + (f"round {prev_rnd} ({prev_verdict})" if prev_rnd else "not a verdict this script wrote")
            + f", so this run must be `Round: {expected}`. The round is counted from the verdict file of "
              "THIS task, not from the request, so it cannot be raised or skipped here.")
    cap = max_rounds()
    if rnd > cap:
        raise Refused(f"round {rnd} > {cap}: stop rule. Write ESCALATE.md instead of another review")
    base = git("rev-parse", "--verify", base.group(1) + "^{commit}").strip()
    harness_gate(req, code, base, head)

    def go():
        with Worktree() as wt:
            build_evidence(wt, base, code)
            # The effective cap, not MAX_ROUNDS: the agent must be told the cap in force, which the
            # Director's DIRECTOR_MAX_ROUNDS may have raised (review round 4, finding 3).
            raised = "" if cap == MAX_ROUNDS else f" (default {MAX_ROUNDS}, raised by the Director)"
            task_text = (f"Review commit `{head}` for **task {task}**, round {rnd} of max {cap}{raised}, "
                         f"against base `{base}`.\n"
                         f"Read `{rel}` (the Builder's request), then `.agent-evidence/INDEX.md`.\n"
                         f"Your verdict is written to `{task_rel(task, 'RESULT.md')}`.")
            return run_agent("reviewer", "docs/REVIEWER_PROMPT.md", task_text, wt)

    text, cost, turns = guarded(go)
    result = block(text, "REVIEW_RESULT")
    v = verdict_of(result, "REVIEW_RESULT")
    out = task_rel(task, "RESULT.md")
    write(os.path.join(REPO, out), result + trailer("REVIEWER", head, f" (round {rnd})", cost, turns))
    print(f"[agents] REVIEWER: {v} (task {task}, round {rnd}); wrote {out}")
    return 0 if v == "PASS" else 1


def next_audit_number():
    names = set(glob.glob(os.path.join(REPO, "docs", "architecture", "audit-*.md")))
    names |= set(git("log", "--all", "--name-only", "--format=", "--", "docs/architecture").split())
    nums = [int(m.group(1)) for n in names if (m := re.search(r"audit-(\d{3})\.md$", n.replace("\\", "/")))]
    return max(nums, default=0) + 1


def cmd_architect(mode, task, system=None):
    head, dirty = repo_state()
    if dirty.strip():
        print("[agents] note: working tree is dirty; the Architect sees committed HEAD only", flush=True)
    if not re.fullmatch(r"[0-9]{1,4}", str(task or "")):
        raise Refused("usage: architect design <system> --task N | architect audit --task N")
    task = int(task)
    if mode == "design":
        if not system or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", system):
            raise Refused("usage: architect design <system> --task N  (system: lower-case, digits, dashes)")
        target = os.path.join("docs", "design", f"{system}.md")
        task_text = (f"Mode: **design `{system}`** for task {task}. Write the design for `{target}`.\n"
                     f"Existing design (if any) is at `{target}` in the worktree.")
    elif mode == "audit":
        n = next_audit_number()
        target = os.path.join("docs", "architecture", f"audit-{n:03d}.md")
        task_text = (f"Mode: **audit** for task {task}. Your document is `{target}` (Architecture audit "
                     f"{n:03d}) of commit `{head}`.\n"
                     "Earlier audits live in `docs/architecture/` or git history; do not repeat items "
                     "already fixed.")
    else:
        raise Refused("usage: architect design <system> --task N | architect audit --task N")

    def go():
        with Worktree() as wt:
            build_evidence(wt)
            return run_agent("architect", "docs/ARCHITECT_PROMPT.md",
                             task_text + "\nRead `.agent-evidence/INDEX.md`.", wt)

    text, cost, turns = guarded(go)
    result, doc = block(text, "ARCH_RESULT"), block(text, "DOCUMENT")
    v = verdict_of(result, "ARCH_RESULT")
    out = task_rel(task, "ARCH_RESULT.md")
    write(os.path.join(REPO, target), doc + "\n")
    write(os.path.join(REPO, out),
          result + trailer("ARCHITECT", head, f" ({mode}{' ' + system if system else ''} -> {target})", cost, turns))
    print(f"[agents] ARCHITECT: {v}; wrote {target} and {out}")
    return 0 if v == "PASS" else 1


def take_task_flag(args):
    """Pull `--task N` (or `--task=N`) out of an argument list. Returns (N or None, rest)."""
    rest, task = [], None
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--task" and i + 1 < len(args):
            task, i = args[i + 1], i + 2
            continue
        if a.startswith("--task="):
            task, i = a.split("=", 1)[1], i + 1
            continue
        rest.append(a)
        i += 1
    return task, rest


def main(argv):
    try:
        args = argv[1:]
        if args[:1] == ["review"]:
            task, rest = take_task_flag(args[1:])
            # A STRAY ARGUMENT IS A REFUSAL, NOT A SHRUG (TASKS.md 21a(a)): `review --task 21 22`
            # used to review task 21 and drop the 22 without a word.
            if len(rest) > 1 or (task is not None and rest):
                raise Refused("usage: review [N]  (or review --task N)")
            return cmd_review(task if task is not None else (rest[0] if rest else None))
        if args[:1] == ["architect"] and len(args) >= 2:
            task, rest = take_task_flag(args[1:])
            # `architect --task 5`, with the mode left out, used to raise an uncaught IndexError on
            # rest[0] instead of printing this (TASKS.md 21a(a)).
            if not rest or len(rest) > 2:
                raise Refused(
                    "usage: architect design <system> [--task N] | architect audit [--task N]")
            return cmd_architect(rest[0], task, rest[1] if len(rest) > 1 else None)
        print(__doc__)
        return 2
    except Refused as e:
        print(f"[agents] REFUSED: {e}")
        return 2
    except subprocess.TimeoutExpired:
        print(f"[agents] REFUSED: agent session exceeded {AGENT_TIMEOUT_S} s")
        return 2


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv))

"""Spawns the REVIEWER and ARCHITECT as fresh, headless, read-only Claude sessions.

Entry points (thin wrappers around this file):
  tools/review.sh    | tools/review.ps1                  -> python tools/agents.py review
  tools/architect.sh | tools/architect.ps1 design <sys>  -> python tools/agents.py architect design <sys>
  tools/architect.sh | tools/architect.ps1 audit         -> python tools/agents.py architect audit

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

The 3-round stop rule is counted from the verdict, not from the request: `Round: N` in
REVIEW_REQUEST.md must equal the round in the committed REVIEW_RESULT.md trailer plus one (or 1 after
a PASS, or when there is no verdict yet). The trailer is written only by `trailer()` here, so the
Builder cannot raise or skip the round from REVIEW_REQUEST.md, and deleting the trailer is caught by
`last_committed_review()`, which looks back over the file's git history.
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
HISTORY_SCAN = 50  # commits of REVIEW_RESULT.md history the round check looks back over
AGENT_TIMEOUT_S = 3600


class Refused(Exception):
    pass


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
        ok = changed in ([], ["REVIEW_REQUEST.md"])
        lines = [f"Code commit (tested by the harness): {code_commit}",
                 f"Commit under review: {head}",
                 f"Files changed between them: {changed or 'none'}",
                 "OK: only REVIEW_REQUEST.md differs, so a harness line for the code commit applies to HEAD." if ok
                 else "NOT OK: more than REVIEW_REQUEST.md changed after the tested commit. The harness line does "
                      "NOT cover HEAD. That is a finding."]
        files["request-only-diff.txt"] = "\n".join(lines) + "\n"
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


def previous_review():
    """(round, verdict) of the REVIEW_RESULT.md this script last wrote, or (None, None).

    Read from the working tree, which `cmd_review` has already proved clean, so it is the committed
    file. The trailer is written only by `trailer()`, so the Builder cannot raise or skip the round
    by editing REVIEW_REQUEST.md (review round 1, finding 2)."""
    path = os.path.join(REPO, "REVIEW_RESULT.md")
    if not os.path.exists(path):
        return None, None
    with open(path, encoding="utf-8") as f:
        return parse_trailer(f.read())


def last_committed_review():
    """(sha, round, verdict) of the newest commit whose REVIEW_RESULT.md carries a trailer.

    `previous_review()` alone cannot see that the file *lost* its trailer: replacing it with the
    placeholder would silently reset the round to 1 (review round 2, finding 1). This looks back."""
    for sha in git("log", "--format=%H", f"-{HISTORY_SCAN}", "--", "REVIEW_RESULT.md").split():
        text = run(["git", "show", f"{sha}:REVIEW_RESULT.md"], check=False).stdout
        rnd, verdict = parse_trailer(text)
        if rnd is not None:
            return sha, rnd, verdict
    return None, None, None


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

def cmd_review():
    head, dirty = repo_state()
    if dirty.strip():
        raise Refused("working tree is dirty: commit the change and REVIEW_REQUEST.md first\n" + dirty)
    path = os.path.join(REPO, "REVIEW_REQUEST.md")
    if not os.path.exists(path):
        raise Refused("REVIEW_REQUEST.md missing")
    with open(path, encoding="utf-8") as f:
        req = f.read()
    rnd = re.search(r"^Round:\s*(\d+)", req, re.M)
    base = re.search(r"^Base:\s*`?([^`\s]+)`?", req, re.M)
    code = re.search(r"^Code commit:\s*`?([0-9a-f]{7,40})`?", req, re.M)
    if not rnd or not base:
        raise Refused("REVIEW_REQUEST.md needs `Round: N`, `Base: <commit>` and `Code commit: <sha>` lines")
    if not code:
        raise Refused("REVIEW_REQUEST.md needs a `Code commit: <sha>` line (the commit the harness tested)")
    code = code.group(1)
    git("rev-parse", "--verify", code + "^{commit}")
    rnd = int(rnd.group(1))
    prev_rnd, prev_verdict = previous_review()
    if prev_rnd is None:
        sha, h_rnd, h_verdict = last_committed_review()
        if sha:
            raise Refused(
                f"REVIEW_RESULT.md carries no verdict trailer, but commit {sha[:12]} recorded round "
                f"{h_rnd} ({h_verdict}). The round count cannot be reset by restoring the "
                "placeholder. Restore that verdict file, or escalate.")
    expected = 1 if prev_rnd is None or prev_verdict == "PASS" else prev_rnd + 1
    if rnd != expected:
        raise Refused(
            f"`Round: {rnd}` in REVIEW_REQUEST.md, but the committed REVIEW_RESULT.md is "
            + (f"round {prev_rnd} ({prev_verdict})" if prev_rnd else "not a verdict this script wrote")
            + f", so this run must be `Round: {expected}`. The round is counted from the verdict "
              "file, not from the request, so the 3-round stop rule cannot be reset by hand.")
    if rnd > MAX_ROUNDS:
        raise Refused(f"round {rnd} > {MAX_ROUNDS}: stop rule. Write ESCALATE.md instead of another review")
    base = base.group(1)
    git("rev-parse", "--verify", base + "^{commit}")

    def go():
        with Worktree() as wt:
            build_evidence(wt, base, code)
            task = (f"Review commit `{head}` (round {rnd} of max {MAX_ROUNDS}) against base `{base}`.\n"
                    "Read `REVIEW_REQUEST.md`, then `.agent-evidence/INDEX.md`.")
            return run_agent("reviewer", "docs/REVIEWER_PROMPT.md", task, wt)

    text, cost, turns = guarded(go)
    result = block(text, "REVIEW_RESULT")
    v = verdict_of(result, "REVIEW_RESULT")
    write(os.path.join(REPO, "REVIEW_RESULT.md"), result + trailer("REVIEWER", head, f" (round {rnd})", cost, turns))
    print(f"[agents] REVIEWER: {v} (round {rnd}); wrote REVIEW_RESULT.md")
    return 0 if v == "PASS" else 1


def next_audit_number():
    names = set(glob.glob(os.path.join(REPO, "docs", "architecture", "audit-*.md")))
    names |= set(git("log", "--all", "--name-only", "--format=", "--", "docs/architecture").split())
    nums = [int(m.group(1)) for n in names if (m := re.search(r"audit-(\d{3})\.md$", n.replace("\\", "/")))]
    return max(nums, default=0) + 1


def cmd_architect(mode, system=None):
    head, dirty = repo_state()
    if dirty.strip():
        print("[agents] note: working tree is dirty; the Architect sees committed HEAD only", flush=True)
    if mode == "design":
        if not system or not re.fullmatch(r"[a-z0-9][a-z0-9-]*", system):
            raise Refused("usage: architect design <system>  (lower-case, digits, dashes)")
        target = os.path.join("docs", "design", f"{system}.md")
        task = (f"Mode: **design `{system}`**. Write the design for `{target}`.\n"
                f"Existing design (if any) is at `{target}` in the worktree.")
    elif mode == "audit":
        n = next_audit_number()
        target = os.path.join("docs", "architecture", f"audit-{n:03d}.md")
        task = (f"Mode: **audit**. Your document is `{target}` (Architecture audit {n:03d}) of commit `{head}`.\n"
                "Earlier audits live in `docs/architecture/` or git history; do not repeat items already fixed.")
    else:
        raise Refused("usage: architect design <system> | architect audit")

    def go():
        with Worktree() as wt:
            build_evidence(wt)
            return run_agent("architect", "docs/ARCHITECT_PROMPT.md", task + "\nRead `.agent-evidence/INDEX.md`.", wt)

    text, cost, turns = guarded(go)
    result, doc = block(text, "ARCH_RESULT"), block(text, "DOCUMENT")
    v = verdict_of(result, "ARCH_RESULT")
    write(os.path.join(REPO, target), doc + "\n")
    write(os.path.join(REPO, "ARCH_RESULT.md"),
          result + trailer("ARCHITECT", head, f" ({mode}{' ' + system if system else ''} -> {target})", cost, turns))
    print(f"[agents] ARCHITECT: {v}; wrote {target} and ARCH_RESULT.md")
    return 0 if v == "PASS" else 1


def main(argv):
    try:
        if argv[1:2] == ["review"] and len(argv) == 2:
            return cmd_review()
        if argv[1:2] == ["architect"] and len(argv) >= 3:
            return cmd_architect(argv[2], argv[3] if len(argv) > 3 else None)
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

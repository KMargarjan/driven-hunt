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
change touches one of the paths in `TWO_PLAYER_PATHS`: the MATCH, the DRIVE, the TIE, the TEAMS and
the specs that test them. **That list is explicit and small since 2026-10-03** (Director decision,
after Karen the same day: "we dont need 2 player test now we just working on weapon and animal
next"). It was "any `src/`, any `tests/client/`, or this harness" from 2026-09-26, which asked for a
human click and eight minutes on every gameplay task. A second player answers one class of question
-- who the OTHER player is -- and the weapon, the viewmodel, the camera, the boar, the hud and the
tools are the same with one player as with two. They need only the one-player line, for a review
round AND for the PR to main.
`WEAPON_VIEWMODEL_PATHS` (Director decision 2026-10-02) is kept and is now SUBSUMED: no viewmodel
path is in the two-player list any more, so the exemption changes no answer. ALL OR NOTHING is still
its rule, and `selftest` proves it inert rather than assuming it.
**A SCOPED one-player line is enough for a REVIEW ROUND** (Task 113; Karen, 2026-10-02: "it has to
test only parts what has been changed and what blast radius could be"). `tools/studio_mcp.py test
--scope auto` resolves the scope from the branch's own changed paths and writes it into its line as
`scope=auto:<names>`; such a line can only have come from that resolution, so it is a review-round
run by construction and the `[harness2]` line is not asked for. `scope=all`, and every line committed
before this change, count as FULL evidence and nothing about them moves. A HAND-NAMED `scope=<names>`
is REFUSED as evidence: a scope typed by a person is a choice, not a measurement. The MERGE gate is
unchanged -- it wants the full `test` and, where the paths ask for it, `test2` (CLAUDE.md git
workflow step 4).
**The CONTENT LANE needs no round at all** (`CONTENT_PATHS`): `src/shared/Viewmodel/poses.json` is
data the Director tunes live and Karen OKs, so a change made only of it is treated here exactly like
a docs change. Its own one-player `test` is still required by CLAUDE.md -- what is dropped is the
review round, not the run.
**The REVIEWER'S EVIDENCE IS SCOPED TOO**: `.agent-evidence/blast-radius.md` holds the changed files
and, per symbol the diff defined, EVERY file in the repo's code that names it and how many times --
no file cut, only the quoted sample capped and counted against the true total
(`MAX_QUOTED_LINES_PER_SYMBOL`, review round 1 finding 1) -- and the prompt tells the Reviewer to
review only that and to read `docs/REVIEWER_RULES.md` (61 lines) instead of CLAUDE.md and
docs/PROJECT_CONTEXT.md.

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
# ...and a change touching any of THESE must also show the TWO-PLAYER line.
#
# IT IS AN EXPLICIT, SMALL LIST NOW (Director decision, 2026-10-03, after Karen the same day: "we
# dont need 2 player test now we just working on weapon and animal next"). It used to be "any
# `src/`, any `tests/client/`, or the harness", which asked for a human click and eight minutes on
# every gameplay task -- including the weapon and animal work that is all there is for the next
# while. A second player answers exactly one class of question: WHO THE OTHER PLAYER IS. The drive
# that assigns teams, the roster, the tie that freezes a driver at a tree, the score across two
# rosters, and the client specs that assert their own ROLE. Nothing else in the game has a second
# player in it: the weapon, the viewmodel, the camera, the boar, the hud and the tools behave the
# same whether one player is present or two, so a second client renders a second copy and answers
# nothing the first did not.
#
# PRECISION BEATS LENGTH HERE. The entries are owners and their specs, named one by one, because the
# rule has to be readable as a sentence: "the match, the drive, the tie, the teams, and the specs
# that test them". Add a path only when a SECOND PLAYER is what makes it true.
#
# DELIBERATELY NOT IN THE LIST, and both are judgement calls worth stating:
#   * `src/server/Weapon/SafetyArc.luau` -- the geometry that decides a shot is toward the drive
#     line. It is weapon-side maths, provable with one player and one angle; the PENALTY it triggers
#     is `src/server/Match/Penalty.luau`, which IS in the list.
#   * `tools/studio_mcp.py` -- the harness itself, which the Director's 2026-10-03 decision puts
#     with the tools. `run_test2` is then the one thing in the repo that only a two-player run can
#     evidence and nothing asks for that run: the Director decides that case by hand (TASKS.md
#     113a(d)).
TWO_PLAYER_PATHS = (
    # The match: phases, the roster and teams, the score, the markers, the outfit, and the TIE.
    "src/server/Match/",
    "src/server/MatchBoot.server.luau",
    "src/client/Match/",
    "src/client/MatchBoot.client.luau",
    "src/shared/Drive/",
    # Which team THIS client is on -- the module every client spec asks about its own role.
    "tests/client/Role.luau",
    # ...and the specs that test all of it. A spec is here when its claims need two rosters.
    "tests/server/match_live.spec.luau",
    "tests/server/match_outfit.spec.luau",
    "tests/server/match_phase.spec.luau",
    "tests/server/match_roster.spec.luau",
    "tests/server/match_safety.spec.luau",
    "tests/server/match_score.spec.luau",
    "tests/server/match_teams.spec.luau",
    "tests/server/zz_drive_boundary.spec.luau",
    "tests/client/match_client.spec.luau",
    "tests/client/outfit_client.spec.luau",
    "tests/client/zz_tie_to_a_tree.spec.luau",
)

# THE CONTENT LANE (CLAUDE.md "Content lane", Karen 2026-10-01: "too slow"; extended here in Task
# 113). These files are DATA the Director tunes live and Karen OKs, not code: the numbers behind a
# picture. A commit that changes only them needs no review round at all, so this gate treats them
# the way it treats docs -- it asks for no harness line and no two-player line. It does NOT excuse
# the data commit from `python tools/studio_mcp.py test`: `tests/server/viewmodel_poses.spec.luau`
# reads poses.json, so the content lane's own one-player gate still runs the specs that see it.
# What is removed is the ROUND, not the run.
CONTENT_PATHS = ("src/shared/Viewmodel/poses.json",)

# BLAST RADIUS: THE ONE SET OF FILES THE SECOND PLAYER CANNOT EVIDENCE (Director decision,
# 2026-10-02). Karen, that day: "not testing everything only changed part and only where could be
# blast radius / do not waist time on unnecassary things / ... we just focus to weapon features".
#
# THE REASON IS WHAT THE SECOND CLIENT IS FOR. `test2` exists because a driver, a tie, a team swap
# and half the client suite only exist with two players. The FIRST-PERSON VIEWMODEL is the opposite
# case: it is drawn under `workspace.CurrentCamera` for ONE player, every other player sees the
# Tool's own mesh, and nothing in it reads a team, a role or another character. A second client
# renders a second copy of the same thing and answers no question the first did not.
#
# SO A CHANGE WHOSE CODE FILES ARE ALL IN THIS LIST IS EXEMPT FROM THE TWO-PLAYER LINE. One file
# outside it -- any server code, Match, the shot or hit path, the driver, the tie -- and the whole
# change needs it again, because the exemption is about what the change CAN break, not about what it
# mostly is. The one-player line is still required for everything, always.
#
# THE SPECS ARE NAMED, NOT PREFIXED, and that is deliberate: only the files that test the viewmodel
# and nothing else may be in here. A spec that grows a driver or a team assertion must come out of
# this list in the same commit.
#
# SINCE 2026-10-03 THIS LIST IS SUBSUMED and kept anyway. `TWO_PLAYER_PATHS` is now the explicit
# match/drive/tie/team list above, and no viewmodel path is in it, so the exemption no longer has
# anything to exempt -- `needs_two_player` returns the same answer with it and without it. It stays
# because it is the written record of WHY the viewmodel never needed a second client, and because
# `selftest` proves it is inert rather than assuming it (the "subsumed" cases below).
WEAPON_VIEWMODEL_PATHS = (
    "src/shared/Gun/",
    "src/shared/Viewmodel/",
    "src/client/Camera/Viewmodel.luau",
    "src/client/Camera/Poses.luau",
    # The specs that drive only those, and only in the local player's own camera.
    "tests/server/gun.spec.luau",
    "tests/server/viewmodel_poses.spec.luau",
    "tests/client/gun_client.spec.luau",
)
AGENT_TIMEOUT_S = 3600


def needs_two_player(changed):
    """Which of `changed` a ONE-player run cannot evidence. Pure: a list of paths in, a list out.

    A path is in the answer only when it is in `TWO_PLAYER_PATHS` -- the match, the drive, the tie,
    the teams and the specs that test them (Director, 2026-10-03). Weapon, viewmodel, camera, boar,
    hud and tools paths are never in it, so they come back empty and need only the one-player line,
    for a review round AND for the PR to main.

    The `WEAPON_VIEWMODEL_PATHS` all-or-nothing exemption (Director, 2026-10-02) still applies and is
    now SUBSUMED: no viewmodel path is a two-player path any more, so it changes no answer. It is
    kept as the record of why, and `selftest` proves it inert. ALL OR NOTHING is still the rule it
    encodes: one file outside that list and every two-player path in the change is back, because the
    question is what the change CAN break, not what most of it is.
    """
    norm = [f.replace("\\", "/") for f in changed]
    two = [f for f in norm if f.startswith(TWO_PLAYER_PATHS)]
    if two and all(f.startswith(WEAPON_VIEWMODEL_PATHS) for f in norm):
        return []
    return two


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



# ------------------------------------------------------------------ blast radius (Task 113)
# KAREN, 2026-10-02: "not need start from zero I mentioned 100 times / it has to test only parts
# what has been changed and what blast radius could be". A review used to begin by reading CLAUDE.md
# (557 lines) and docs/PROJECT_CONTEXT.md (48) and then the whole diff with the whole repo behind it.
# Now the Reviewer gets docs/REVIEWER_RULES.md (61 lines, the rules digest) and this file: the
# changed files, the symbols whose definitions the diff touched, and every place in the repo that
# names one of them. That IS the blast radius, and the prompt tells it to review only that.
#
# GREP-BASED AND DELIBERATELY SO: a name match is a superset of the real callers, which is the safe
# direction. A missed caller would hide a defect; an extra one costs the Reviewer one look.
SYMBOL_RES = (
    re.compile(r"^\s*(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_.:]*)"),  # Luau function M.f / f
    re.compile(r"^\s*(?:local\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\b"),  # f = function()
    re.compile(r"^\s*def\s+([A-Za-z_][A-Za-z0-9_]*)"),  # Python def
    re.compile(r"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)"),
    re.compile(r"^([A-Z][A-Z0-9_]{2,})\s*="),  # a module-level constant, the other thing callers read
)
MAX_SYMBOLS = 40
# HOW MANY LINES ARE QUOTED PER SYMBOL -- and that is ALL it bounds (review round 1, finding 1).
# It used to bound the SEARCH: `references` stopped counting at 12 and the heading printed 12 as the
# total, so `studio_mcp`'s 55 references in 19 files came out as "12 reference(s)" and ten caller
# files -- `tools/pose.py` among them, with 19 of its own -- silently left the Reviewer's scope,
# which the prompt makes exhaustive by fiat. The count is now complete and EVERY file that names a
# symbol is named with how many times; only the quoted sample is capped, and the heading says so.
MAX_QUOTED_LINES_PER_SYMBOL = 12


def symbols_in_diff(diff_text):
    """The symbol names whose DEFINITION a diff adds or removes. Pure: text in, names out.

    Both directions matter: a definition the diff deleted is exactly the one whose callers now
    break, so a `-` line counts the same as a `+` line."""
    out = []
    for line in diff_text.splitlines():
        if not line or line[0] not in "+-" or line[:3] in ("+++", "---"):
            continue
        for rx in SYMBOL_RES:
            m = rx.match(line[1:])
            if m:
                name = m.group(1).split(".")[-1].split(":")[-1]
                if len(name) > 2 and name not in out:
                    out.append(name)
                break
    return out[:MAX_SYMBOLS]


def module_names(changed):
    """The names other files would use to reach the changed files: `Foo` for `Foo.luau`, and the
    FOLDER's name for an `init.luau`, which is what `require` actually names. Pure."""
    names = []
    for raw in changed:
        path = raw.replace("\\", "/")
        base = path.rsplit("/", 1)[-1]
        stem = base.split(".")[0]
        if stem in ("init", "index") and "/" in path:
            stem = path.rsplit("/", 2)[-2]
        if len(stem) > 2 and stem not in names:
            names.append(stem)
    return names


def reference_hits(names, documents):
    """{name: {"total": n, "files": {path: count}, "lines": [(path, number, text)]}}.

    Pure: the names and `{path: [line, ...]}` go in, the counts come out -- no git and no
    filesystem, which is what lets `selftest` drive it (CI runs that step with neither).

    NOTHING IS CUT SILENTLY (review round 1, finding 1). `total` counts every matching line and
    `files` names EVERY file that names the symbol, with how many times; the cap applies only to
    `lines`, the quoted sample, and the report prints `len(lines)` against `total`. The old version
    stopped searching at the cap and printed the cap as the total, so a caller file could leave the
    Reviewer's scope with no sign of it -- and the Reviewer prompt makes that scope exhaustive.
    """
    patterns = {name: re.compile(r"\b" + re.escape(name) + r"\b") for name in names}
    hits = {name: {"total": 0, "files": {}, "lines": []} for name in names}
    for path in sorted(documents):
        for number, text in enumerate(documents[path], 1):
            for name, rx in patterns.items():
                if not rx.search(text):
                    continue
                info = hits[name]
                info["total"] += 1
                info["files"][path] = info["files"].get(path, 0) + 1
                if len(info["lines"]) < MAX_QUOTED_LINES_PER_SYMBOL:
                    info["lines"].append((path, number, text.strip()[:140]))
    return hits


def references(wt, names, changed):
    """`reference_hits` over the worktree's tracked code: who else names one of `names`.

    The changed files themselves are left out: the diff already shows them, and what the Reviewer
    cannot see from the diff is who else depends on them."""
    skip = {f.replace("\\", "/") for f in changed}
    documents = {}
    for rel in git("ls-files", cwd=wt).split():
        rel = rel.replace("\\", "/")
        if rel in skip or rel.startswith((".agent-evidence/", "reviews/", "backups/")):
            continue
        # CODE AND CONFIG ONLY. A `.md` scan was tried first and was almost all noise: a symbol
        # called `references` or `Body` matches English prose, and ESCALATE.md and TASKS.md are
        # full of it. A caller is in code; the docs are the Architect's business, not a caller.
        if not rel.endswith((".luau", ".lua", ".py", ".json", ".yml", ".toml", ".ps1", ".sh")):
            continue
        try:
            with open(os.path.join(wt, rel), encoding="utf-8", errors="replace") as f:
                documents[rel] = f.read().splitlines()
        except OSError:
            continue
    return reference_hits(names, documents)


def blast_radius_report(changed, names, hits):
    """The `.agent-evidence/blast-radius.md` body. Pure: the lists and the counts in, markdown out.

    Split from `blast_radius_text` so `selftest` can render a symbol with more hits than the quoted
    cap and read what the Reviewer would read (review round 1, finding 1: the heading was the only
    place the truncation could have been visible, and it was not)."""
    out = ["# Blast radius", "",
           "**This is your whole review scope.** The files below, and the callers and callees of the",
           "symbols below. Nothing else in the repository is yours this round (docs/REVIEWER_RULES.md,",
           "\"What you review\").", "",
           "Grep-based, so the lists are a SUPERSET: an entry that turns out not to call the symbol",
           "costs you one look, which is the safe direction. **Every file that names a symbol is",
           "named below, with how many of its lines name it** -- no file is cut. Only the QUOTED",
           f"LINES are capped, at {MAX_QUOTED_LINES_PER_SYMBOL} per symbol; each heading says how",
           "many of the total they are, and the rest are in the files named beside them.", "",
           f"## Changed files ({len(changed)})", ""]
    out += [f"- `{f}`" for f in changed] or ["- none"]
    out += ["", "## Symbols the diff defines, removed or renamed, and who names them", ""]
    if not names:
        out.append("No function, class or constant definition changed: the diff is data, docs or "
                   "paperwork only.")
    for name in names[:MAX_SYMBOLS]:
        info = hits.get(name) or {"total": 0, "files": {}, "lines": []}
        total, files, lines = info["total"], info["files"], info["lines"]
        if not total:
            out += [f"### `{name}` -- no reference outside the changed files (nothing else in the "
                    "repo's code names it)", ""]
            continue
        out += [f"### `{name}` -- named on {total} line(s) in {len(files)} file(s) outside the "
                "changed files", "",
                "Every file that names it, and on how many of its lines: "
                + " · ".join(f"`{f}` ({n})" for f, n in sorted(files.items())), "",
                f"{len(lines)} of {total} line(s) quoted"
                + ("" if len(lines) == total else
                   f"; the other {total - len(lines)} are in the files above")]
        out += [f"- `{rel}`:{number} `{text}`" for rel, number, text in lines]
        out.append("")
    return "\n".join(out) + "\n"


def blast_radius_text(wt, changed, diff_text):
    """`blast_radius_report` over a worktree: work out the symbols, count the references, render."""
    code = [f for f in changed if f.replace("\\", "/").endswith((".luau", ".lua", ".py"))]
    defined = symbols_in_diff(diff_text)
    names = (defined + [n for n in module_names(code) if n not in defined])[:MAX_SYMBOLS]
    return blast_radius_report(changed, names, references(wt, names, changed) if names else {})

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
        # THE REVIEW SCOPE ITSELF (Task 113): the changed files plus the direct callers and callees
        # of the symbols the diff defined. The prompt sends the Reviewer here first and tells it to
        # review nothing else, so this file is what stops a round from starting at zero.
        changed_now = git("diff", "--name-only", f"{base}...HEAD", cwd=wt).split()
        files["blast-radius.md"] = blast_radius_text(wt, changed_now, files["diff.patch"])
    index = ["# Evidence index", "", f"Precomputed by tools/agents.py for commit `{head}`.",
             "The agent cannot run commands; these are the outputs it would have needed.", "",
             "**Start with `blast-radius.md`** (when it is listed): the changed files and the callers",
             "and callees of what they define. That is the whole review scope. The rules are in",
             "`docs/REVIEWER_RULES.md` -- do NOT read CLAUDE.md or docs/PROJECT_CONTEXT.md, they are",
             "605 lines together and the digest replaces them (Task 113).", ""]
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


HARNESS_RE = re.compile(r"\[harness\]\s+PASS:\s*\d+/\d+\s+checks\s+@\s*([0-9a-f]{7,40})\s*\(clean tree\)"
                        r"(?:\s+scope=([A-Za-z0-9_,:.-]+))?")
# The two-player line has the same shape under a different tag. Both are written by
# tools/studio_mcp.py and nothing else; a request pastes them verbatim.
HARNESS2_RE = re.compile(r"\[harness2\]\s+PASS:\s*\d+/\d+\s+checks\s+@\s*([0-9a-f]{7,40})\s*\(clean tree\)"
                         r"(?:\s+scope=([A-Za-z0-9_,:.-]+))?")


def scope_verdict(scope):
    """What a pasted line's `scope=` means here. Pure: the tag (or None) in, a word out.

    "full"   -- `scope=all`, or no scope at all, which is every harness line committed before
                Task 113. Evidence for a review round AND for the merge gate.
    "auto"   -- `scope=auto:<names>`: tools/studio_mcp.py resolved the scope from the branch's own
                changed paths. Good enough for a REVIEW ROUND -- the game was still played whenever
                any spec was in the blast radius -- and not evidence for the merge.
    "hand"   -- `scope=<names>` typed by a person. REFUSED as evidence: a chosen scope is a choice,
                not a measurement, and the one thing the gate must not accept is a Builder naming
                the scope that happens to pass."""
    if not scope or scope == "all":
        return "full"
    return "auto" if scope.startswith("auto:") else "hand"


def harness_gate(req, code_full, base, head):
    """Harness before review (Task 21).

    A change that touches src/, tests/ or tools/ may not be reviewed until it has RUN: the request
    must paste the harness's own PASS line for its `Code commit:`, on a clean tree. Task 18 was
    reviewed three times before any of its code had executed, and the first real run then failed
    three specs. Docs-only changes are exempt: the harness says nothing about them.

    WHAT `Code commit:` MEANS, and this is the definition (CLAUDE.md git workflow step 4 now says the
    same): the commit the harness lines name. It must be at or after the last commit that changed
    src/, tests/ or tools/, and only paperwork may follow it. A LATER paperwork commit is fine -- the
    two-player run happens at the branch head, which by then carries the request itself -- and only
    narrows what the evidence has to cover. An EARLIER one is not, and this gate is what refuses it:
    the sha in the pasted line must match, so a request cannot claim a commit nothing ran over."""
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
    # THE CONTENT LANE IS NOT A CODE CHANGE for this gate (Task 113). `CONTENT_PATHS` is data the
    # Director tunes live and Karen OKs; CLAUDE.md gives it no review round at all, so a request
    # made only of it is treated exactly like a docs one. The data commit still runs `test`.
    content = sorted(f for f in seen if f.replace("\\", "/").startswith(CONTENT_PATHS))
    changed = sorted(f for f in seen if f not in content)
    if content:
        print(f"[agents] content lane: {len(content)} data file(s) "
              f"({', '.join(content[:3])}) need no review round (CLAUDE.md \"Content lane\"); "
              "the data commit still needs `python tools/studio_mcp.py test`", flush=True)
    if not changed:
        print("[agents] docs-only change: no harness line required", flush=True)
        return

    def pasted(pattern):
        """The pasted lines of this shape that name the code commit, in the order they appear."""
        return [m for m in pattern.finditer(req) if code_full.startswith(m.group(1))]

    one = pasted(HARNESS_RE)
    if not one:
        roots = sorted({f.replace("\\", "/").split("/")[0] + "/" for f in changed})
        raise Refused(
            f"this change touches {', '.join(roots)} ({len(changed)} file(s)), so it must have RUN "
            f"before it is reviewed. Paste the harness's own line for the code commit:\n"
            f"  [harness] PASS: n/m checks @ {code_full} (clean tree)\n"
            "Run `python tools/studio_mcp.py test` on the clean tree first. Docs are exempt.")

    # THE TWO-PLAYER LINE, for the paths a one-player run cannot evidence (Director, 2026-09-26).
    # A driver, a tie, a team swap and half the client suite exist only with two clients, so a
    # change to gameplay or to the harness that drives them is not evidenced without one.
    #
    # ...UNLESS EVERY CODE FILE IS FIRST-PERSON VIEWMODEL (Director, 2026-10-02). See
    # `WEAPON_VIEWMODEL_PATHS`: a second client draws a second copy of a thing only its own player
    # can see, so it answers nothing. ALL or NOTHING -- one file outside the list and the whole
    # change needs the line again.
    # ...AND UNLESS THE ONE-PLAYER LINE IS A SCOPED ONE (Task 113; Director, 2026-10-02: "agents.py
    # accepts a scoped line for review rounds; the FULL suite (and test2 where required) is required
    # only for the PR to main"). A `scope=auto:...` line can only have come from `test --scope auto`
    # on this branch, so it is a REVIEW-ROUND run by construction, and `test2` costs a human click
    # and eight minutes per round. The MERGE gate is unchanged: it wants the full pair, and
    # CLAUDE.md git workflow step 4 plus the Director check it. A HAND-NAMED scope is refused
    # outright above -- that is the one shape a Builder could choose to make a gate pass.
    kinds = {scope_verdict(m.group(2)) for m in one}
    hand = sorted({m.group(2) for m in one if scope_verdict(m.group(2)) == "hand"})
    if hand and "full" not in kinds and "auto" not in kinds:
        raise Refused(
            f"the pasted harness line carries a hand-named scope (scope={hand[0]}). A scope typed by "
            "a person is a choice, not a measurement, so it is not review evidence. Re-run either "
            "`python tools/studio_mcp.py test` (the whole suite) or `test --scope auto` (resolved "
            "from this branch's own changed paths) and paste that line.")
    scoped = "full" not in kinds
    two_player = needs_two_player(changed)
    if not two_player and any(f.replace("\\", "/").startswith(TWO_PLAYER_PATHS) for f in changed):
        print(f"[agents] every changed file is first-person viewmodel ({len(changed)} file(s)), so "
              f"the two-player line is not required (Director, 2026-10-02)", flush=True)
    if two_player and scoped:
        print(f"[agents] the one-player line is scoped ({sorted(m.group(2) for m in one)}), so this "
              "is a review round and the two-player line is not required (Task 113). THE MERGE "
              "STILL NEEDS the full `test` and `test2` pair for the code commit.", flush=True)
        two_player = []
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
            # WHAT TO READ, AND IN WHICH ORDER (Task 113). The scope comes first and the rules come
            # from the 61-line digest: a round used to start by reading CLAUDE.md (557 lines) and
            # docs/PROJECT_CONTEXT.md (48) before it had seen the diff. Karen, 2026-10-02: "not need
            # start from zero I mentioned 100 times".
            task_text = (f"Review commit `{head}` for **task {task}**, round {rnd} of max {cap}{raised}, "
                         f"against base `{base}`.\n"
                         f"Read, in this order: `docs/REVIEWER_RULES.md` (the rules digest -- do NOT "
                         f"read CLAUDE.md or docs/PROJECT_CONTEXT.md), "
                         f"`.agent-evidence/blast-radius.md` (your whole review scope), `{rel}` "
                         f"(the Builder's request), then `.agent-evidence/INDEX.md` for the rest of "
                         f"the precomputed evidence.\n"
                         f"Review ONLY the changed files and the callers and callees named in "
                         f"blast-radius.md. Anything outside that is not even a note.\n"
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


def selftest():
    """Offline, no git and no Claude: the two rules the two-player gate rests on, both directions.

    It drives `needs_two_player` with FILE LISTS rather than with a repository, which is the whole
    point -- the decision is a pure function of the paths, so it can be proved without a branch, a
    commit or a Studio.
    """
    failures = []

    def check(name, ok, detail=""):
        print("[selftest] %-62s %s %s" % (name, "ok" if ok else "FAILED", detail))
        if not ok:
            failures.append(name)

    viewmodel = ["src/shared/Gun/init.luau", "src/client/Camera/Viewmodel.luau",
                 "tests/client/gun_client.spec.luau", "tests/server/gun.spec.luau"]
    check("a viewmodel-only change needs no two-player line",
          needs_two_player(viewmodel) == [], "%s" % (needs_two_player(viewmodel),))
    # ...AND THE OTHER DIRECTION, which is the one that matters: one MATCH, DRIVE, TIE or TEAM file
    # brings the two-player line back for the whole change. These are the paths a second player is
    # the only way to test (Director, 2026-10-03).
    for stranger in ("src/server/Match/init.luau", "src/server/Match/Penalty.luau",
                     "src/server/Match/Roster.luau", "src/client/Match/init.luau",
                     "src/shared/Drive/init.luau", "src/server/MatchBoot.server.luau",
                     "tests/client/Role.luau", "tests/client/match_client.spec.luau",
                     "tests/client/zz_tie_to_a_tree.spec.luau",
                     "tests/server/match_teams.spec.luau",
                     "tests/server/zz_drive_boundary.spec.luau"):
        got = needs_two_player(viewmodel + [stranger])
        check("one %s brings the two-player line back" % stranger, len(got) > 0,
              "%d path(s) need it" % len(got))
    # ...AND THE OTHER HALF OF KAREN'S RULE, 2026-10-03: "we dont need 2 player test now we just
    # working on weapon and animal next". These are the paths that used to demand a human click and
    # eight minutes and must NOT any more -- the weapon, the shot path, the hud, the boar, the
    # camera, the client specs that are not about a role, and the tools.
    for alone in ("src/server/Weapon/Shot.luau", "src/server/Weapon/Hits.luau",
                  "src/client/Weapon/Input.luau", "src/client/Hud/init.luau",
                  "src/server/Boar/Brain.luau", "src/client/Camera/Rig.luau",
                  "src/shared/Gun/init.luau", "tests/client/weapon_client.spec.luau",
                  "tests/client/camera_client.spec.luau", "tests/client/hit_marker.spec.luau",
                  "tests/server/weapon_shot.spec.luau", "tests/server/boar_hit.spec.luau",
                  "tools/studio_mcp.py", "tools/agents.py"):
        got = needs_two_player([alone])
        check("%s needs only the one-player line" % alone, got == [], "%s" % (got,))
    check("a docs-only change asks for nothing", needs_two_player([]) == [])
    check("a non-code change asks for nothing", needs_two_player(["README.md"]) == [])
    # NORMALISATION, DRIVEN BY THE CASE THAT CAN FAIL (round 1, finding 2). This used to assert that
    # a backslashed VIEWMODEL path comes back exempt -- which it does with the normalisation deleted
    # too, because an un-normalised path matches no prefix at all and the function then returns the
    # same empty list. The dangerous direction is the other one: a GAMEPLAY path that the gate reads
    # as asking for nothing. With `norm` removed this returns [] and the check fails.
    check("a Windows path is normalised, so a gameplay path still asks for two players",
          needs_two_player([r"src\server\Match\init.luau"]) != [],
          "%s" % (needs_two_player([r"src\server\Match\init.luau"]),))
    # EVERY EXEMPT PATH IS A CODE PATH, so nothing in this list can ever skip the ONE-player line --
    # which is the half of the gate the Director did not relax.
    for path in WEAPON_VIEWMODEL_PATHS:
        check("exempt path %s still needs the one-player line" % path,
              path.startswith(CODE_PATHS))
    # ...AND THE EXEMPTION IS NOW INERT, which is a thing to PROVE rather than assume (Director,
    # 2026-10-03): `TWO_PLAYER_PATHS` is the match/drive/tie/team list, and no viewmodel path is in
    # it, so `needs_two_player` gives the same answer with the exemption and without it. If a
    # viewmodel path is ever added back to the two-player list, this fails and whoever added it has
    # to decide which rule wins.
    check("no viewmodel path is a two-player path any more (the exemption is subsumed)",
          not any(p.startswith(TWO_PLAYER_PATHS) for p in WEAPON_VIEWMODEL_PATHS),
          "%s" % ([p for p in WEAPON_VIEWMODEL_PATHS if p.startswith(TWO_PLAYER_PATHS)],))
    check("a viewmodel change plus its SERVER spec is still exempt",
          needs_two_player(["src/shared/Gun/init.luau", "tests/server/gun.spec.luau"]) == [])
    # ...and `tests/client/` as a whole is NOT a two-player path any more: only the named match, tie
    # and role files in `TWO_PLAYER_PATHS` are. That is the change Karen asked for, stated as a test.
    check("tests/client/ as a whole is no longer a two-player path",
          needs_two_player(["tests/client/weapon_client.spec.luau"]) == [])
    check("but the named client role, match and tie specs still are",
          needs_two_player(["tests/client/Role.luau"]) != []
          and needs_two_player(["tests/client/match_client.spec.luau"]) != []
          and needs_two_player(["tests/client/zz_tie_to_a_tree.spec.luau"]) != [])
    # EVERY TWO-PLAYER PATH IS A CODE PATH, so it can never skip the one-player line either.
    check("every two-player path is a code path", all(p.startswith(CODE_PATHS) for p in TWO_PLAYER_PATHS))
    # THE LIST IS SMALL ON PURPOSE. A rule that has to be readable as a sentence cannot grow to
    # "any src/" again without somebody noticing, which is what this bound is for.
    check("the two-player list is still small and explicit", len(TWO_PLAYER_PATHS) <= 20,
          "%d entries" % len(TWO_PLAYER_PATHS))
    check("no two-player entry is a whole root", not any(p in ("src/", "tests/", "tools/")
                                                         for p in TWO_PLAYER_PATHS))
    # The one-player gate is untouched by any of this: every code path still needs `[harness]`.
    check("the exempt paths are still CODE paths, so the one-player line is still required",
          all(p.startswith(CODE_PATHS) for p in WEAPON_VIEWMODEL_PATHS))
    # ---------------------------------------------------------- Task 113: scope, content lane,
    # blast radius. All three are pure functions of text, so all three are proved here.
    #
    # THE SCOPED-LINE RULE, and the direction that matters is "hand": that is the one shape a
    # Builder could choose to make a gate pass, so it must never read as evidence.
    check("no scope at all is full evidence", scope_verdict(None) == "full")
    check("scope=all is full evidence", scope_verdict("all") == "full")
    check("scope=auto:... is a review-round run", scope_verdict("auto:gun,viewmodel") == "auto")
    for hand in ("gun", "gun,viewmodel", "none", "match"):
        check("a hand-named scope=%s is not evidence" % hand, scope_verdict(hand) == "hand")
    # ...and the regex still reads the lines both with and without a scope, which is what keeps
    # every harness line committed before Task 113 valid.
    sha = "a" * 40
    for line, want in ((f"[harness] PASS: 32/32 checks @ {sha} (clean tree)", None),
                       (f"[harness] PASS: 32/32 checks @ {sha} (clean tree) scope=all", "all"),
                       (f"[harness] PASS: 12/12 checks @ {sha} (clean tree) scope=auto:gun", "auto:gun"),
                       (f"[harness] PASS: 12/12 checks @ {sha} (clean tree) scope=none", "none")):
        m = HARNESS_RE.search(line)
        check("the harness line parses (%s)" % (want or "no scope"),
              m is not None and m.group(1) == sha and m.group(2) == want,
              repr(m.groups() if m else None))
    check("the two-player line parses a scope too",
          HARNESS2_RE.search(f"[harness2] PASS: 9/9 checks @ {sha} (clean tree) scope=all") is not None)
    # A DIRTY-TREE line is still not evidence, scoped or not: the scope group may only follow
    # "(clean tree)".
    check("a DIRTY TREE line is still refused",
          HARNESS_RE.search(f"[harness] PASS: 12/12 checks @ {sha} (DIRTY TREE (1 paths)) scope=all")
          is None)

    # THE CONTENT LANE. `CONTENT_PATHS` is data, so a change made only of it is a docs change here;
    # a change that also touches code is NOT, and that is the direction that would be wrong quietly.
    check("poses.json is a content path", "src/shared/Viewmodel/poses.json".startswith(CONTENT_PATHS))
    check("the module that READS poses.json is not content",
          not "src/shared/Viewmodel/init.luau".startswith(CONTENT_PATHS))
    check("a content path is still a code path, so nothing else about it changes",
          all(p.startswith(CODE_PATHS) for p in CONTENT_PATHS))

    # THE BLAST RADIUS. The symbols come out of the diff text, in both directions: a definition the
    # diff DELETED is exactly the one whose callers now break.
    diff = "\n".join([
        "--- a/src/shared/Gun/init.luau", "+++ b/src/shared/Gun/init.luau",
        "+function Gun.reload(self)", "-local function oldHelper(x)", "+MAX_SHELLS = 2",
        "+\tlocal unchanged = callSomethingElse()", " context line with function notAdded()",
        "--- a/tools/agents.py", "+++ b/tools/agents.py", "+def scope_verdict(scope):",
    ])
    got = symbols_in_diff(diff)
    check("an added Luau function is a symbol", "reload" in got, repr(got))
    check("a REMOVED function is a symbol too", "oldHelper" in got, repr(got))
    check("a module-level constant is a symbol", "MAX_SHELLS" in got, repr(got))
    check("a Python def is a symbol", "scope_verdict" in got, repr(got))
    check("a context line is not a symbol", "notAdded" not in got, repr(got))
    check("a local assignment that is not a definition is not a symbol",
          "unchanged" not in got, repr(got))
    # And the module names other files would `require`: a folder's `init.luau` is reached by the
    # FOLDER's name, which is the name a caller actually writes.
    mods = module_names(["src/shared/Gun/init.luau", "src/client/Camera/Viewmodel.luau", "docs/x.md"])
    check("an init.luau is named by its folder", "Gun" in mods, repr(mods))
    check("a plain module is named by its file", "Viewmodel" in mods, repr(mods))

    # ...AND THE CAP MUST NOT HIDE A CALLER (review round 1, finding 1). The cap used to stop the
    # SEARCH and the heading printed it as the total: `studio_mcp`'s 55 references in 19 files were
    # reported as "12 reference(s)", and ten caller files -- `tools/pose.py` with 19 of its own
    # among them -- left the Reviewer's scope without a word, in a scope the prompt makes
    # exhaustive. These cases drive the two pure halves with MORE hits and MORE files than the cap.
    many = {"caller_%02d.luau" % i: ["local x = useThing()", "-- useThing again", "nothing here"]
            for i in range(MAX_QUOTED_LINES_PER_SYMBOL + 8)}
    total = 2 * len(many)
    got = reference_hits(["useThing"], many)["useThing"]
    check("the TOTAL counts every reference, not the cap", got["total"] == total,
          "%d vs %d" % (got["total"], total))
    check("EVERY file that names the symbol is counted, however many there are",
          set(got["files"]) == set(many), "%d of %d file(s)" % (len(got["files"]), len(many)))
    check("each file carries its own count", set(got["files"].values()) == {2}, repr(got["files"]))
    check("only the QUOTED lines are capped",
          len(got["lines"]) == MAX_QUOTED_LINES_PER_SYMBOL, "%d quoted" % len(got["lines"]))
    check("a file that does not name the symbol is not counted",
          reference_hits(["useThing"], {"quiet.luau": ["nothing here"]})["useThing"]["total"] == 0)
    # ...and THE DOCUMENT THE REVIEWER READS says all of it: the true total, the file count, every
    # file name, and how many lines it quoted. This is the check that would have caught it.
    report = blast_radius_report(["caller_00.luau"], ["useThing"], {"useThing": got})
    check("the report heading carries the full total, not the cap",
          "named on %d line(s) in %d file(s)" % (total, len(many)) in report,
          [l for l in report.splitlines() if l.startswith("### ")][:1])
    check("the report names every file, including the ones it could not quote",
          all(("`%s`" % f) in report for f in many),
          "%d of %d named" % (sum(1 for f in many if ("`%s`" % f) in report), len(many)))
    check("the report says how many lines it quoted and how many it did not",
          "%d of %d line(s) quoted" % (MAX_QUOTED_LINES_PER_SYMBOL, total) in report
          and "the other %d are in the files above" % (total - MAX_QUOTED_LINES_PER_SYMBOL) in report)
    check("a symbol nothing names says so plainly",
          "no reference outside the changed files"
          in blast_radius_report([], ["lonely"], {"lonely": {"total": 0, "files": {}, "lines": []}}))

    print("[selftest] %s" % ("all ok" if not failures else "FAILED: " + ", ".join(failures)))
    return 0 if not failures else 1


def main(argv):
    try:
        args = argv[1:]
        if args[:1] == ["selftest"]:
            if len(args) > 1:
                raise Refused("usage: selftest")
            return selftest()
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

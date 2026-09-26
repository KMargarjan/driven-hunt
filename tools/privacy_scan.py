#!/usr/bin/env python3
"""Privacy and secret scan for the public Driven Hunt repository.

The repo is public (CLAUDE.md, "Public repository: never commit secrets"). Three things must
never reach it, and until Task 49 nothing checked for them on the way in:

1. **Local absolute user paths** - `C:\\Users\\<name>\\...`, `/c/Users/<name>/...`, `/home/<name>/...`.
   They leak the Windows or Linux account name and the machine's layout, and they are useless to
   anyone else reading the repo. Placeholders are the fix, and are allowed: a path segment that
   starts with `<`, `%`, `$`, `{` or `...` is a placeholder, so `C:\\Users\\<user>\\AppData\\...`
   passes and `docs/research/2026-09-24-map-generator.md` keeps saying where Studio autosaves.
2. **Email addresses**, except two: any address on a domain ending `.noreply.github.com` -- which is
   the GitHub noreply form (`<name>@users.noreply.github.com`, and the enterprise variants that end
   the same way) -- and `noreply` at `anthropic.com`, the commit-trailer address. `ALLOWED_EMAIL_SUFFIX`
   and `ALLOWED_EMAILS` are the whole rule; nothing else is allowed. Every commit in this repo
   already uses the noreply identity, and this keeps it that way in file contents too.
3. **Secret shapes** - private key headers, `.ROBLOSECURITY` cookie values, AWS / GitHub / Slack /
   `sk-` style API keys, webhook URLs, and any `api_key = "<20+ characters>"` style assignment.
   Naming a secret is fine: CLAUDE.md and `.gitignore` both talk about `.ROBLOSECURITY` and
   `*.pem` and must keep passing. Only a value that looks like the real thing fails.

**The scanner scans itself.** Every pattern below, and every selftest sample, is assembled from
pieces at run time, so this file on disk contains no string that its own rules match. There is no
self-exclusion and no allowlist to quietly grow: `scan` covers `tools/privacy_scan.py` like any
other tracked file.

What it does NOT do: rewrite history. The repo has been public from the start, and rewriting it
would break every PR and review link already recorded in `TASKS.md` and `reviews/`. See CLAUDE.md,
"Public repository", 2026-09-26.

Usage
    python tools/privacy_scan.py scan [path ...]   every tracked text file, or just the paths given
    python tools/privacy_scan.py selftest          prove each rule catches its shape and allows the
                                                   forms that must stay legal

Exit codes, the harness's shape (`tools/studio_mcp.py`):
    0  clean (or selftest passed)
    1  findings (or a selftest case came out wrong)
    2  refused - not a git repository, or a bad argument

Pattern: deny-by-shape secret scanning, the same idea as gitleaks' rules
(https://github.com/gitleaks/gitleaks, MIT, actively maintained), reduced to the handful of shapes
this repo can actually produce. gitleaks 8.30.1 was run over every ref on 2026-09-24 and found
nothing; this is the standing check that keeps that true without a second binary in CI.
Note: docs/research/INDEX.md has no entry - this is a CI hygiene tool, not a game system.
"""

import os
import re
import subprocess
import sys

# ---------------------------------------------------------------------------
# Pieces. Kept apart so this file never contains a literal its own rules match.
# ---------------------------------------------------------------------------

_AT = "@"
_DASH5 = "-" * 5
_BEGIN = _DASH5 + "BEGIN "
_UNDERSCORE_PIPE = "_" + "|"

# A path segment that is a placeholder, not a real account name.
_PLACEHOLDER = r"(?:[<%${]|\.\.\.)"

RULES = [
    (
        "local-path",
        # Windows drive + Users, the Git-Bash /c/Users form, POSIX /home and /Users. The
        # look-behind stops `https://example.com/home/page` from looking like a home directory.
        re.compile(
            r"(?<![A-Za-z0-9._-])"
            r"(?:[A-Za-z]:[\\/]{1,2}Users|/[A-Za-z]/Users|/home|/Users)"
            r"[\\/]{1,2}(?!" + _PLACEHOLDER + r")[A-Za-z0-9._-]{2,}",
            re.IGNORECASE,
        ),
        "local absolute user path - use a placeholder such as <repo>, <assets-dir> or <runs-dir>",
    ),
    (
        "email",
        re.compile(
            r"(?<![A-Za-z0-9._%+-])[A-Za-z0-9._%+-]+" + _AT
            + r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}"
        ),
        "email address - use the GitHub noreply form <name>" + _AT + "users.noreply.github.com",
    ),
    (
        "private-key",
        re.compile(_BEGIN + r"[A-Z ]*PRIVATE KEY" + _DASH5),
        "private key block - keys never live in the repo (see .gitignore)",
    ),
    (
        "roblox-cookie",
        re.compile(re.escape(_UNDERSCORE_PIPE + "WARNING:-DO-") + r"NOT-SHARE-THIS"),
        ".ROBLOSECURITY cookie value - revoke it now, then remove it (CLAUDE.md)",
    ),
    (
        "aws-key",
        re.compile(r"(?<![A-Z0-9])(?:AKIA|ASIA)[0-9A-Z]{16}(?![0-9A-Z])"),
        "AWS access key id",
    ),
    (
        "github-token",
        re.compile(r"(?<![A-Za-z0-9])(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{22,})"),
        "GitHub token",
    ),
    (
        "sk-key",
        # OpenAI / Anthropic style, including the sk-ant- prefix.
        re.compile(r"(?<![A-Za-z0-9-])sk-(?:ant-)?[A-Za-z0-9_-]{20,}"),
        "API key (sk- prefix)",
    ),
    (
        "slack-token",
        re.compile(r"(?<![A-Za-z0-9])xox[abprs]-[A-Za-z0-9-]{10,}"),
        "Slack token",
    ),
    (
        "webhook-url",
        re.compile(
            r"https://(?:hooks\.slack\.com/services|(?:discord|discordapp)\.com/api/webhooks)"
            r"/[^\s\"'`<>]+"
        ),
        "webhook URL - it is a credential; keep it in the Secrets Store",
    ),
    (
        "assigned-secret",
        # api_key = "....", token: '....', X-Api-Key: <20+ characters>. A quoted or bare literal of
        # 20+ credential-shaped characters after a credential-shaped name. `x-api-key: <key>` in
        # docs/design/asset-pipeline.md is a placeholder and does not match.
        re.compile(
            # No \b before the name: in ROBLOX_API_KEY the underscore is a word character, so a
            # word boundary would miss exactly the spelling a CI variable uses.
            r"(?i)(?<![A-Za-z0-9])(?:api[_-]?key|apikey|secret|access[_-]?token|auth[_-]?token"
            r"|password|passwd)\b\s*[:=]\s*[\"']?[A-Za-z0-9_\-/+=]{20,}[\"']?"
        ),
        "credential assigned in a tracked file - use the Secrets Store / GitHub Actions secrets",
    ),
]

# The only addresses allowed to appear as literal text. Everything else the `email` rule catches.
ALLOWED_EMAIL_SUFFIX = ".noreply.github.com"
ALLOWED_EMAILS = ("noreply" + _AT + "anthropic.com",)


def _email_allowed(match_text):
    """True for the GitHub noreply form and for the commit-trailer address."""
    lowered = match_text.lower()
    return lowered.endswith(ALLOWED_EMAIL_SUFFIX) or lowered in ALLOWED_EMAILS


def findings_in(text):
    """Every rule violation in `text`, as (rule name, line number, message, matched text)."""
    out = []
    for name, pattern, message in RULES:
        for match in pattern.finditer(text):
            if name == "email" and _email_allowed(match.group(0)):
                continue
            line = text.count("\n", 0, match.start()) + 1
            out.append((name, line, message, match.group(0)))
    out.sort(key=lambda f: (f[1], f[0]))
    return out


def _tracked_files(repo_root):
    result = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        return None
    return [p for p in result.stdout.decode("utf-8", "replace").split("\0") if p]


def _read_text(path):
    """File contents, or None when it is binary or unreadable."""
    try:
        with open(path, "rb") as handle:
            raw = handle.read()
    except OSError:
        return None
    if b"\0" in raw:
        return None
    return raw.decode("utf-8", "replace")


def scan(repo_root, paths):
    if not paths:
        paths = _tracked_files(repo_root)
        if paths is None:
            print("[privacy] REFUSED: not a git repository (or git is not on PATH)")
            return 2
    total = 0
    scanned = 0
    for rel in paths:
        text = _read_text(os.path.join(repo_root, rel))
        if text is None:
            continue
        scanned += 1
        for name, line, message, matched in findings_in(text):
            shown = matched if len(matched) <= 60 else matched[:57] + "..."
            print("%s:%d: [%s] %s -- %s" % (rel, line, name, message, shown))
            total += 1
    if total:
        print("[privacy] FAIL: %d finding(s) in %d tracked text files" % (total, scanned))
        return 1
    print("[privacy] PASS: 0 findings in %d tracked text files" % scanned)
    return 0


# ---------------------------------------------------------------------------
# Selftest. Every sample is built from pieces, so this file passes its own scan.
# ---------------------------------------------------------------------------

_BS = "\\"
_WIN_USERS = "C:" + _BS + "Users" + _BS

CAUGHT = [
    ("local-path", "in a terminal in `" + _WIN_USERS + "someone" + _BS + "Desktop" + _BS + "x`"),
    ("local-path", "C:" + "/Users/" + "someone" + "/Desktop"),
    ("local-path", "run it from /c" + "/Users/" + "someone" + "/proj"),
    ("local-path", "the log is in /home" + "/someone" + "/.cache"),
    ("local-path", "/Users/" + "someone" + "/Library/Logs"),
    ("email", "write to " + "person" + _AT + "example.com"),
    ("email", "person" + _AT + "gmail.com is the owner"),
    ("email", "someone" + _AT + "noreply.github.com"),  # not the users. form
    ("private-key", _BEGIN + "RSA PRIVATE KEY" + _DASH5),
    ("private-key", _BEGIN + "PRIVATE KEY" + _DASH5),
    ("roblox-cookie", _UNDERSCORE_PIPE + "WARNING:-DO-" + "NOT-SHARE-THIS.--abcdef"),
    ("aws-key", "AKIA" + "IOSFODNN7EXAMPLE"),
    ("github-token", "ghp_" + "a" * 36),
    ("github-token", "github_pat_" + "b" * 30),
    ("sk-key", "sk-" + "ant-" + "api03-" + "c" * 30),
    ("sk-key", "sk-" + "d" * 32),
    ("slack-token", "xox" + "b-1234567890-abcdefghij"),
    ("webhook-url", "https://hooks.slack.com" + "/services/T000/B000/" + "e" * 24),
    ("webhook-url", "https://discord.com" + "/api/webhooks/123456/" + "f" * 24),
    ("assigned-secret", "api_key" + " = " + '"' + "g" * 32 + '"'),
    ("assigned-secret", "ROBLOX_API_KEY" + ": " + "h" * 40),
    ("assigned-secret", "password" + "=" + "i" * 24),
]

ALLOWED = [
    "KMargarjan" + _AT + "users.noreply.github.com",
    "12345+name" + _AT + "users.noreply.github.com",
    "Co-Authored-By: Claude <" + "noreply" + _AT + "anthropic.com>",
    _WIN_USERS + "<user>" + _BS + "AppData" + _BS + "Local",
    _WIN_USERS + "...",
    "%USERPROFILE%" + _BS + "Desktop",
    "$HOME/projects/driven-hunt",
    "the drop folder is <assets-dir>, the runs folder <runs-dir>, the repo <repo>",
    "never commit a .ROBLOSECURITY cookie or a *.pem private key",
    "header `x-api-key: <key>`, with the key replaced by ***",
    "see https://create.roblox.com/docs/reference/engine/classes/AssetService",
    "uses: CompeyDev/setup-rokit" + _AT + "v0.2.1",
    "uses: actions/checkout" + _AT + "v7",
    'testez = "roblox/testez' + _AT + '0.4.1"',
    "https://github.com/rojo-rbx/rojo/issues/1309",
]


def selftest(repo_root):
    failures = []
    for expected, sample in CAUGHT:
        names = {f[0] for f in findings_in(sample)}
        if expected not in names:
            failures.append("NOT CAUGHT by %s: %r (rules that fired: %s)" % (
                expected, sample, sorted(names) or "none"))
    for sample in ALLOWED:
        found = findings_in(sample)
        if found:
            failures.append("FALSE POSITIVE on %r: %s" % (sample, [(f[0], f[3]) for f in found]))

    # The scanner must pass its own scan: no rule may match this file's source.
    own = os.path.join(repo_root, "tools", "privacy_scan.py")
    text = _read_text(own)
    if text is None:
        failures.append("cannot read tools/privacy_scan.py to scan it against itself")
    else:
        for name, line, _message, matched in findings_in(text):
            failures.append("tools/privacy_scan.py:%d matches its own rule %s: %r"
                            % (line, name, matched))

    for line in failures:
        print("[privacy] selftest: " + line)
    if failures:
        print("[privacy] selftest FAIL: %d of %d cases wrong"
              % (len(failures), len(CAUGHT) + len(ALLOWED) + 1))
        return 1
    print("[privacy] selftest PASS: %d shapes caught, %d allowed forms clean, self-scan clean"
          % (len(CAUGHT), len(ALLOWED)))
    return 0


def main(argv):
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if len(argv) < 2 or argv[1] not in ("scan", "selftest"):
        print(__doc__.split("Usage")[1].split("Exit codes")[0].strip())
        return 2
    if argv[1] == "selftest":
        return selftest(repo_root)
    return scan(repo_root, argv[2:])


if __name__ == "__main__":
    sys.exit(main(sys.argv))

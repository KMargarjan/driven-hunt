#!/usr/bin/env python3
"""The Director's playtest switch: turn a feature on for Karen WITHOUT a commit.

    python tools/flags.py                       what is declared, and what is overridden
    python tools/flags.py set <NAME> on|off     override one flag (Edit mode only)
    python tools/flags.py clear                 remove every override
    python tools/flags.py live [role]           what a RUNNING session resolved
                                                (role: server, client, client:<PlayerName>)

Why it exists: feel-critical work used to wait for Karen's playtest before merging, so ten PRs
stacked on one unmerged PR. A flagged path merges dark; the Director switches it on here; Karen
plays; her OK flips the default in a later three-line commit. The override is an attribute on
ServerStorage, never a file, so THE GIT TREE STAYS CLEAN and the harness stays runnable.

`set` and `clear` are Edit-only. The server resolves flags once, at boot, so a write into a running
session would never be read -- and an invisible write is a lie about what was tested. Start the
session after setting, then use `live` to confirm it before telling Karen to go.

CLEAR BEFORE THE NEXT HARNESS RUN. `test` and `test2` both refuse to start while any override is
set, and print this tool's `clear` line: a run against an overridden build is not evidence for the
reviewed one.

This is a THIN WRAPPER, the same shape as tools/review.sh over tools/agents.py. All of the logic,
the Edit-mode gate and the MCP transport live in `tools/studio_mcp.py` (`run_flags`), which is the
one owner of the DHFlag_* attributes (docs/design/feature-flags.md sections 2 and 7.2).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import studio_mcp  # noqa: E402


def main(argv):
    if argv[1:2] in (["-h"], ["--help"], ["help"]):
        print(__doc__)
        return 0
    return studio_mcp.main([argv[0], "flags", *argv[1:]])


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main(sys.argv))

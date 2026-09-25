#!/usr/bin/env bash
# REVIEWER: fresh headless read-only Claude -> reviews/task-<N>/RESULT.md.
# Usage: tools/review.sh [N]   (N defaults to the most recently committed reviews/task-*/REQUEST.md)
# Logic: tools/agents.py (see its docstring).
set -euo pipefail
cd "$(dirname "$0")/.."
exec python tools/agents.py review "$@"

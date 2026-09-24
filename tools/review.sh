#!/usr/bin/env bash
# REVIEWER: fresh headless read-only Claude -> REVIEW_RESULT.md. Logic: tools/agents.py (see its docstring).
set -euo pipefail
cd "$(dirname "$0")/.."
exec python tools/agents.py review "$@"

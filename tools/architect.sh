#!/usr/bin/env bash
# ARCHITECT: fresh headless read-only Claude -> docs/design/<system>.md or docs/architecture/audit-NNN.md,
# plus reviews/task-<N>/ARCH_RESULT.md.
# Usage: tools/architect.sh design <system> --task <N> | tools/architect.sh audit --task <N>
# Logic: tools/agents.py (see its docstring).
set -euo pipefail
cd "$(dirname "$0")/.."
exec python tools/agents.py architect "$@"

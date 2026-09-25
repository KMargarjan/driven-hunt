# ARCHITECT: fresh headless read-only Claude -> docs/design/<system>.md or docs/architecture/audit-NNN.md,
# plus reviews/task-<N>/ARCH_RESULT.md.
# Usage: powershell -ExecutionPolicy Bypass -File tools/architect.ps1 design <system> --task <N>
#        powershell -ExecutionPolicy Bypass -File tools/architect.ps1 audit --task <N>
# Logic: tools/agents.py (see its docstring).
Set-Location (Join-Path $PSScriptRoot "..")
python tools/agents.py architect @args
exit $LASTEXITCODE

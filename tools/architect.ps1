# ARCHITECT: fresh headless read-only Claude -> docs/design/<system>.md or docs/architecture/audit-NNN.md,
# plus ARCH_RESULT.md. Usage: tools/architect.ps1 design <system> | tools/architect.ps1 audit
# Logic: tools/agents.py (see its docstring).
Set-Location (Join-Path $PSScriptRoot "..")
python tools/agents.py architect @args
exit $LASTEXITCODE

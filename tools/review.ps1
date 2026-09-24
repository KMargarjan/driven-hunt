# REVIEWER: fresh headless read-only Claude -> REVIEW_RESULT.md. Logic: tools/agents.py (see its docstring).
Set-Location (Join-Path $PSScriptRoot "..")
python tools/agents.py review @args
exit $LASTEXITCODE

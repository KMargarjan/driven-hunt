# REVIEWER: fresh headless read-only Claude -> reviews/task-<N>/RESULT.md.
# Usage: powershell -ExecutionPolicy Bypass -File tools/review.ps1 [N]
#   (N defaults to the most recently committed reviews/task-*/REQUEST.md). Logic: tools/agents.py.
Set-Location (Join-Path $PSScriptRoot "..")
python tools/agents.py review @args
exit $LASTEXITCODE

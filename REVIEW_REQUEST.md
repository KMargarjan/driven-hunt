# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 0
Base: `<commit before the change>`
Code commit: `<commit the harness tested>`

## Task
<TASKS.md number and one line>

## What changed
<files and why>

## Claims
1. <claim> — How to verify: <file:line, evidence file, or reasoning>

## Harness
<the final `[harness] ... @ <code commit> (clean tree)` line, or N/A with a reason>

## Could not verify
<what the Builder could not verify, and why>

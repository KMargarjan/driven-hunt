# Escalations

For the Director and Karen. The Builder (or any agent) writes here and stops when:
- the same item has failed 3 review rounds
- it believes the Reviewer or Architect is factually wrong
- a design, feel or scope decision is needed

Newest first. The Director or Karen answers under each entry, and the entry is closed with a date.

---

## 2026-09-24 · OPEN · Audit-002 must-fix items are outside Task 10's scope

**Raised by:** Builder, at loop step 6 of Task 10 (branch `task-10-lint-test-globals`, head
`24fd22a` + the audit commit).

**Situation.** Task 10 (audit-001 L5) passed review in 2 rounds (`REVIEW_RESULT.md`: PASS on round 2).
The one-per-task Architect audit (`docs/architecture/audit-002.md`) returned 5 must-fix items
(`ARCH_RESULT.md`). I checked the evidence for each and believe all 5 are **valid**, but **none is in
Task 10's change**:

| # | Must-fix (audit-002) | Where it belongs | Decision needed? |
|---|---|---|---|
| 1 | Typed property values (Vector3, CFrame, Color3…) fail as "cannot compare", so no positioned geometry can come from disk | harness (`tools/studio_mcp.py`), before the first grey-box geometry | **Yes, partly design.** Either support typed values in the harness, or decide that geometry lives elsewhere (Workspace built in Studio; templates as `.model.json` with typed values). The Architect owns the structure; this probably needs `tools/architect.sh design geometry-on-disk` first |
| 2 | The unmanaged scan checks only scripts, so a Studio-made non-script instance in a Rojo-owned container passes, then vanishes at the next Connect | harness | No: Builder work |
| 3 | `tools/agents.py` (the four-agent gate) has no research note (rules 1, 2, 9) | Task 9 | No: Builder work |
| 4 | The Architect audits blind: earlier audits are not on this branch (audit-001 is only on PR #2) and are not in its evidence | Task 9 (`tools/agents.py` evidence), and PR #2's merge order | No: Builder work, plus merge order |
| 5 | `ARCH_RESULT.md`/`REVIEW_RESULT.md` got a Builder-written `NONE` placeholder, although only the scripts may write them; nothing ties a verdict to the merged commit; a dirty-tree audit writes an unqualified verdict | Task 9 | No: Builder work |

**The conflict.** CLAUDE.md's loop says "must-fix → fix, back to 4". Rule 4 says "one task per round, nothing
extra", and PROJECT_CONTEXT.md warns that big multi-item rounds hid failures. Folding 5 unrelated fixes
into Task 10 would make it a multi-item round about the harness and the workflow, not about L5. Choosing
between those two rules is a scope decision, so it is the Director's.

**Builder's proposal.**
- Close Task 10 as done (its own change passed review).
- Queue audit-002 must-fix items as five separate small tasks, 11–15 in `TASKS.md`, each through the full
  loop, **all before any game code**. Suggested order: 5, 4, 3 (they fix the workflow itself), then
  2, then 1 (after an Architect design for geometry on disk).
- Merge order suggestion: PR #2 (audit-001) early, so every later branch has `docs/architecture/`.

**Needs:** a Director decision (and Karen, if item 1's geometry question touches how she wants to
build the map).

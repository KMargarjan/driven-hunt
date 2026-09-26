# Task 51 — design brief for the ARCHITECT: `docs/design/feature-flags.md`

Written by the Director; Karen green-lit it on 2026-09-26. Problem: feel-critical work (shooting, camera,
penalty, map switch) waited for Karen's playtest before merging, so ten PRs stacked on one unmerged PR.
Goal: feel-critical work MERGES as soon as it is reviewed and green, switched OFF; the Director turns it
ON for Karen's playtest; Karen's OK flips the default in a later small commit.

Constraints:
- One owner for flag values (rule 3). Defaults live in one config module on disk (reviewed in git).
- A playtest override must not dirty the git tree (the harness refuses dirty trees) and must not exist
  in a live server: e.g. an override read only when `RunService:IsStudio()`, set by the Director through
  Studio MCP (`execute_luau` in Edit mode) as attributes on a service — and the harness must refuse to run
  (or reset them) while any override is set, so tests never run against overridden flags.
- Both sides (server and client) must agree on a flag's value (replication path named).
- Specs must be able to test both states of a flag without leaking one test's state into another
  (the TestKit gate pattern; the arming-policy leak in audit-004 F1 is the failure to avoid).
- Old code paths behind a flag are archived (rule 7) once the flag defaults ON and Karen accepts.
Give: owner, API, the Studio override mechanism and its guard, the harness interaction, how a flag is
retired, and a worked example using an existing feature (e.g. the tie penalty's TIE_UNTIL_DRIVE_END).
No local absolute Windows paths.

## Director decisions on the design's §14 (2026-09-26)
- 2: agreed — an expired flag FAILS the harness.
- 3: agreed — MAX_FLAGS = 12.
- 4: agreed — existing pseudo-flags stay; exactly one migration (§10).
- 5: agreed — TASKS row 2's strip list gains clearing every ServerStorage `DHFlag_*` attribute.
- §15 items 1-2 are the Builder's FIRST measurements (attribute replication; Edit-mode attribute
  reaching a Play / two-client server). If they fail, use the named fallback and report it.

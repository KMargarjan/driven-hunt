# Task 23 — regenerate the shotgun design

Task: 23
Round: 1
Base: `cf184f1`
Code commit: `795876c698d5166131c620390b247d95f7e715aa`

**Docs only — no `src/`, `tests/` or `tools/` file changed**, so there is no harness line and the
harness gate exempts this change (`tools/agents.py`, `harness_gate`). Per `CLAUDE.md` (the loop,
step 5) a docs-only task gets **one round**, and notes never block.

## Task

Director, 2026-09-25 (verbatim in `TASKS.md`): regenerate `docs/design/shotgun.md`, which the
Director ruled on 2026-09-24 must not be built from until the boar was merged. Nothing was ever built
from the Task 19 version; there is still no weapon code.

## What changed

| File | What |
|---|---|
| `docs/design/shotgun.md` | rewritten by the Architect (`tools/architect.ps1 design shotgun --task 23`), 690 → 1112 lines |
| `reviews/task-23/ARCH_RESULT.md` | the Architect's verdict: `PASS` |
| `reviews/task-23/BRIEF.md` | **new.** The Director's and Karen's input, written by me before the run |
| `docs/ARCHITECT_PROMPT.md` | three lines: read `reviews/task-<N>/BRIEF.md` first when it exists |
| `TASKS.md` | row 23 and the dispatch, verbatim |

## Claims

1. **The design is the Architect's, not mine.** I wrote only the brief. `docs/design/` is
   Architect-owned (rule 3) and the script writes it; I did not edit it after the run.

2. **A brief could reach the agent at all.** `cmd_architect` in `tools/agents.py` builds the run's
   task text itself and tooling may not change in a docs-only task, so the channel is a document:
   `docs/ARCHITECT_PROMPT.md`'s "Mode: design" now tells the Architect to read
   `reviews/task-<N>/BRIEF.md` first, and the run's task text already names the task number. **Verify:**
   the design cites the brief by name and answers its numbered items in order.

3. **The four scope calls are settled in the design, not deferred.** §15 is headed "Open decisions —
   none of them blocks building", and `ARCH_RESULT.md` line 1 is `PASS`. The Task 19 version's three
   blocking items (Task 6, ADS/viewmodel, the damage entry point) are answered: default camera first
   with no ADS and no viewmodel; ADS as the next task with its own design and a named seam (§9);
   Task 6 first, no waiver (§13.3).

4. **Both cones are in one unit, and the config's unit is in the field name.** §4: every stored angle
   is degrees, the field name carries `FULL` or `HALF`, and each is converted to radians at exactly one
   named call site — `SPREAD_FULL_DEG.Slug = 0.16`, `SPREAD_FULL_DEG.Buck = 1.6`, both full cones,
   matching the research note; `SAFETY_ARC_HALF_DEG` is a different quantity and says so. The spec in
   §13.1 asserts against the full angle so a 2× error in either direction fails. This is the Task 19
   defect (a half-angle row beside a full-angle row, consumed as a half-angle) made unrepeatable.

5. **The damage entry point has one owner, and the boar keeps its own state.** §6.2:
   `ServerScriptService.Boar` gains `Runtime:takeHit(part, hit)` and `Runtime.Hit`; the weapon
   publishes `Weapon.HitReported` and never writes boar state. §6.3 puts the wiring in
   `BoarBoot.server.luau`, so neither owner requires the other — the same composition-root idiom
   `BoarBoot` already uses for `TestArena`. §6.2 also says why a damage router is *not* built yet.

6. **The seam matches the brief's shape and stops where 1.5 starts.** `Hit = { zone, ammo, pellets, at }`
   with `HitZone` a string that is `"body"` in v1; §6.5 says what `takeHit` must **not** do yet
   (no health, no wounded running — ROADMAP 1.5).

7. **The `GAME_DESIGN.md` owner rows are written out ready to paste** (§14): five new rows — server
   weapon, weapon client, effects, **UI/HunterHud**, and the frozen `Shotgun.CONFIG` — plus an
   amendment to the existing Boar row rather than a second boar row, and a deliberate note that Input
   stays unassigned with a per-system `ContextActionService` prefix instead.

8. **Karen's five feel defaults are config fields** (§12), each with the alternative if she says
   otherwise: `SPREAD_FULL_DEG.Buck`, the 0.5 + 2×0.45 + 0.6 = 2.0 s uninterruptible reload,
   `CROSSHAIR_*` with `PlayerScripts.Hud` named as its owner (the crosshair Karen wants is no longer
   deferred for want of a UI owner), automatic barrel select, and load-only-while-open enforced in the
   reducer.

9. **Task 6 now has a target written by its consumer** (§13.3): three inputs — a key, a mouse button,
   and two inputs in sequence with an observable gap — then the weapon assertions they unlock,
   including that `workspace.CurrentCamera.CFrame` is unchanged when aiming, which is the mechanical
   proof the weapon never becomes the camera's writer.

10. **The Task 19 documents' three known defects are addressed in §2** ("Defects in the Task 19
    documents, corrected here"), which is where the cone-unit fix, the mis-pointed `ARCH_RESULT`
    reference and the off-by-two `docs/PROJECT_CONTEXT.md` citations are accounted for.

## What I could not verify

- **Nothing was executed.** No code exists for this design; the harness was not run (docs-only, and
  Karen is playtesting — I did not touch Studio, Play or the harness this task).
- **The design's own claims about the boar code and the harness** are the Architect's reading of the
  repo. I spot-checked the ones the build will lean on hardest — the `takeHit` owner, the angle rule,
  the owner rows — but I did not re-verify every citation in 1112 lines.
- **Karen has not seen any of it.** Every feel number in §12 is a default awaiting her playtest.

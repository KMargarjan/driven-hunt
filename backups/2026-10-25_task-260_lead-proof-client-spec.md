# Archived: `tests/client/lead_proof.spec.luau`, task 260 item 3 (rule 7, NEVER DELETE)

**Written, linted, and taken back out of the branch in the same session — because it cannot work
with today's harness, and the reason is worth more than the file.**

## What it was

The real-click lead proof the Director asked for (task 259a, re-dispatched as task 260 item 3): two
replayed mouse clicks at a real running boar, the first aimed AT its chest and the second aimed ahead
by `velocity * Ballistics.timeToRange`, with the error measured as the signed projection of
`impact - aimPoint` onto the animal's own direction of travel — so it reads the same whether the boar
crosses or runs away. Shot A must miss or land behind; shot B must land where it was aimed. The
bounds are fractions of the lead the run itself produced.

Everything in it is written and linted, and the arithmetic half of the same claim is already asserted
with no world in `tests/server/weapon_hits.spec.luau`'s *"the shot in the air"* block.

## Why it cannot run yet — MEASURED, in the harness, not predicted

**Two stage-driven scenarios cannot coexist, because the harness has ONE stage marker for all of
them.** `tools/studio_mcp.py`'s stage sets the LocalPlayer attribute **`StagedTarget`** to the
target's full name, and every stage-driven spec waits on that one attribute. `shoot_boar.spec` and
this file would both latch on whichever scenario staged first, and would then both drive
`Camera.lookAt` at the same boar with different aim points — one leading it and one not. The file's
own assertions would read the other spec's clicks as its own shots.

**And the load itself fails first:** `tests/client/InputReady.luau`'s `EXPECTED` list is the one place
every input-driven spec is named, and `InputReady.ready` asserts the name is in it. A new spec is a
new entry — which is correct and was the first thing the harness said (*"failed to load
ReplicatedStorage.ClientTests.lead_proof.spec"*), and it also aborted the whole client suite, so
`lever_client.spec` and everything after it did not run.

## What it needs, exactly

A **per-scenario** stage marker: the stage should set the scenario's own name (say
`StagedScenario = "lead-the-boar"`) beside `StagedTarget`, so each spec latches on its own scenario
and no two ever track the camera at once. That is a change to `tools/studio_mcp.py` plus its
`selftest`'s scenario-shape checks, plus the `InputReady.EXPECTED` entry — a small, self-contained
task, and it is queued as TASKS.md 260a.

Restoring the file is then: copy it back to `tests/client/lead_proof.spec.luau`, add `"lead_proof"`
to `InputReady.EXPECTED`, re-add the `lead-the-boar` scenario to `tests/client/input_scenarios.txt`
(it was placed after `shoot-the-boar`, with `stage: { targetFolder = "Boars", offsetStuds = [0, 1.5,
22] }` and steps: moveTo, wait 4200, click, wait 1800, click, wait 1600), register it in
`SCOPE_SPECS` under `weapon` and `gun`, and make it wait on the new per-scenario marker.

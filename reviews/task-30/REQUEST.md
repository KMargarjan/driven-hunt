# Task 30 — two players, staging a shot, and a detector that sees rotation

Task: 30
Round: 1
Base: `437cde1`
Code commit: `99afc5be142d48299363142ce14e7dccafcc0c4d`

```
[harness] PASS: 27/27 checks @ 99afc5be142d48299363142ce14e7dccafcc0c4d (clean tree)
```

162 server and 51 client `it` blocks across 17 spec files (`main` had 156 and 44). 27 checks, not 26:
staging a scenario is a check of its own.

## Task

ROADMAP 1.6 plus two queued items, all three the Director's: `docs/design/drive.md` §12.6 (can the
harness run 2+ players?), `docs/design/hit-zones.md` §14 D (place the character and aim the camera,
**through the camera owner's API**), and `docs/architecture/audit-003.md` must-fix 2 (the foreign-write
detector cannot see a rotation-only write).

## Claims

1. **The 2-player question is answered from the server's own schemas, not from reading our client.**
   I asked StudioMCP `tools/list`. `start_stop_play` takes `{is_start, studio_id}` — **no player
   count**. `execute_luau`, `user_mouse_input`, `user_keyboard_input` and `search_game_tree` all take
   `datamodel_type` as an enum of exactly `Edit | Client | Server` — **no index**, so a second client
   in one Studio is not addressable. So: **not possible today**, as `drive.md` §12.6 predicted. What
   the design did not have: **every** tool takes a `studio_id` and `list_roblox_studios` returns one
   `{id, name}` per connected Studio ("several instances are commonly open at once"). A local
   multi-client test starts extra Studio *processes*, so that is the one open route — and it cannot
   be evaluated without a human, because `start_stop_play` cannot start such a test.

2. **So the deliverable for 1.6 is one read-only command and one exact set of clicks.**
   `python tools/studio_mcp.py studios` prints the listing (with one Studio open: one entry).
   `ESCALATE.md` carries a `NEEDS KAREN` entry: start a 2-client test, run that one command, paste
   the output — three or more studios means a 2-player harness is feasible and deserves a task, one
   means 1.6's automation is closed and `ROADMAP.md` should say so. Nothing in the repo depends on
   the answer. The evidence and the reasoning are in the toolchain note's Task 30 addendum.

3. **A scenario can now be staged, and the stage is load-bearing.** `input_scenarios.txt` grew an
   optional `stage` block (`targetFolder`, `offsetStuds`), validated before Play like every step.
   During the replay, immediately before that scenario's steps, the harness finds the first `BasePart`
   in `Workspace.<targetFolder>`, moves the character to `target.Position + offsetStuds`, asks the
   camera owner to aim, and sets the `StagedTarget` attribute. It is **its own check line** —
   `[input] staged 1 scenario(s) (placed + aimed)` — because a scenario staged into thin air would
   otherwise send every click and still be reported as replayed. Delete the stage and
   `shoot_boar.spec` goes red twice over.

4. **It goes through the camera owner, and it has to be an Instance.** MEASURED, twice (Task 26 and
   again here): a `require()` of `PlayerScripts.Camera` through `execute_luau` reports
   `mode=Loading frames=0` while the live camera is `Scriptable` at FOV 70 — `execute_luau` has its
   own module cache, so the harness **cannot call a live module's functions at all**. So the owner
   exposes `LookAtRequest`, a `BindableFunction`, in the same spirit as `Cursor.requestFree`: the
   caller asks, the owner writes. `workspace.CurrentCamera` still has exactly one writer in the repo,
   and `shoot_boar.spec` asserts the foreign-write counter does not move across a staged aim.

5. **`Mode.anglesToward` is pure, and it earns its iteration.** The camera sits 12 studs behind the
   pivot and 2.2 to the right, so aiming the *pivot* at a target 20 studs away leaves the camera
   **3.97°** off — wide enough to miss a 2-stud boar. Taking the camera position the current angles
   give and re-aiming from there converges: six passes land under **0.02°** (both numbers printed by
   `camera_mode.spec`, which drives it on the server with no client). A target *inside* the boom
   cannot be centred at all — turning toward it moves the camera away — so that case is a test of its
   own that asserts what it must never do: NaN or an unclamped angle.

6. **The end-to-end assertion exists now, and it is real.** `tests/client/shoot_boar.spec.luau`: a
   replayed click → `ContextActionService` → the client weapon → `FireRequest` → the server's
   validator, cast and pellets → a real boar's zone part → `HitReported` → the boar's runtime → the
   shooter's hit marker. The run logs `[shoot_boar] staged on Workspace.Boars.Boar1, 22 studs away`
   and `[shoot_boar] marker: kind=hit zone=body`. The spec counts **only markers that arrive after
   the stage**, which matters: see claim 9.

7. **Audit-003 must-fix 2 is fixed and the fix is tested.** `Rig.apply` compares position, **both
   `LookVector` and `RightVector`** (so a roll is caught too) and the field of view. `camera_client.spec`
   performs a deliberate rotation-only write — same position, same FOV, opposite look — and asserts
   the counter rises (`0 -> 1` in the run), then asserts it does not move over the next 60 frames of
   the camera's own writes. `CameraType` and `CameraSubject` are deliberately **not** compared, for
   the reason the audit gives: the engine restores both on respawn.

8. **Two specs' session-wide claims became window claims, because the session now has another
   shooter.** `weapon_client.spec` asserted "exactly two shots" and "it ends here" over the whole
   session; `shoot-the-boar` fires the same gun afterwards, so those became claims about its own
   scenario, bounded by the `StagedTarget` attribute — the one event that says another scenario has
   taken the gun. Its foreign-write assertion is likewise a delta over its own describe, since the
   detector test above deliberately raises the total.

9. **Two harness bugs, found by running it, fixed, and the second one matters more than it looks**
   (rule 6). (i) A batch of eight big files truncated Studio's reply and failed the whole run as a
   `JSONDecodeError`; the comparison now splits a batch that will not parse and retries, down to one
   instance, which then fails loudly by name. (ii) A `string.format` inside `QUERY_STAGE` collided
   with Python's `%` templating, so **every stage raised before Studio saw it — and the run went
   green anyway, twice**, because a stray click from an earlier scenario hit the wandering boar and
   produced the marker the new spec was waiting for. The stage's own check caught it; the spec did
   not. Hence the gate in claim 6.

10. **The frame-budget assertion now measures the frame, not the worst hitch.** `Camera.stats()`
    gained `avgUpdateMs`; the spec asserts the **average** against the design's 0.3 ms
    (`0.050 ms average, 0.180 ms worst, over 122 frames`) and keeps a loose bound on the max. Task 26
    measured maxima between 0.22 and 0.34 ms for identical code, so the old assertion was one hitch
    away from red — and it went red in this task's first runs.

## Screenshot, inspected (rule 5)

`task30-staged-on-the-boar`: the staged view, one frame after the stage ran. The player stands 22
studs from the production boar with the gun out, and **the crosshair is on the animal** — the tan
body with its pink head block sits under the reticle. That is the whole capability in one picture:
the harness put the player there and the camera owner pointed the view at the target. Nothing else on
screen changed in this task.

## What I could not verify

- **Whether a 2-client local test registers extra Studios with StudioMCP.** It needs a human click
  and it is the entire remaining unknown for 1.6 (claim 1, `ESCALATE.md`).
- **The staged shot depends on a live production boar.** It is staged 22 studs out and the boar bolts
  as soon as the player appears, so the spec tracks it every frame; two clicks are sent for two
  chances. It has now hit on three consecutive runs (`zone=chest`, `zone=body`, `zone=body`), but it
  is the one assertion in the repo that depends on an animal's behaviour, and a boar that runs behind
  cover would fail it.
- **The client report timeout was raised from 60 s to 90 s.** The client suite cannot finish before
  the replay does, now that a spec waits to be staged; the replay measures about 50 s.
- **`LookAtRequest` exists in production too**, not only under test. That is deliberate — production
  behaving differently under test is the failure the harness exists to avoid — but it is a new public
  surface on the camera, and it is a request rather than a write.
- **I did not run a 2-player test myself**, and nothing here claims the `studio_id` route works: it
  is named as the open route and left open.

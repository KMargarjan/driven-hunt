# Task 88 — design brief for the ARCHITECT: first person, the viewmodel, and the bead

Written by the Builder, carrying the Director (2026-09-27). This brief is the input to
`tools/architect.sh design camera --task 88` and **overrides anything older** in `docs/`, `TASKS.md`
and the existing design where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-09-27-first-person-viewmodel.md`** (this task's note — sources,
licences, the measurements of Karen's reference, and the numeric targets). The design is a **delta**
to `docs/design/camera.md`, plus whatever `docs/design/shotgun.md` sections the viewmodel touches.

## 1. The decisions, already taken — do not re-open them

1. **KAREN, 2026-09-27: FIRST PERSON ALL THE TIME.** This **replaces** the 2026-09-25 decision
   (over-the-shoulder third person, "option A") in `docs/design/camera.md` §1/§12. The polish phase
   starts with the shotgun and goes **step by step "until I say it looks and feels right"**.
2. **No crosshair at any time** — not in the carry, not in ADS, not ever. Today the Hud draws one and
   only hides it while aiming (`camera.md` §6.2).
3. **Walking: the gun is held LOW in the lower-LEFT of the screen** (today's hip pose is low-right).
   It may be half off-screen; in the reference it often is, entirely.
4. **Aiming (hold right mouse): the gun comes up to the eye and the player looks down the rib at the
   front BEAD.** The bead is the sight. Our gun is Karen's side-by-side (Tasks 72–76, through the
   `Assets.Loader` seam), with the parts gun as the fallback.
5. **Hands and arms are visible on the gun.**
6. **Minimal HUD** — no new HUD element comes out of this work.
7. **It merges dark.** A new flag **`FIRST_PERSON`**, `default = false`, owner
   `StarterPlayerScripts.Camera`, so the Director switches it on for one playtest and Karen compares
   both cameras in the same session. The shoulder camera stays as the OFF branch until she says
   otherwise (`docs/design/feature-flags.md`; the ON and OFF branches must both be reachable **by
   parameter**, §13.3).
8. **Karen's accepted feel numbers stay** unless she changes them: `FOV_AIM_DEG = 50` and
   `AIM_BLEND_SECONDS = 0.20` (2026-09-25). The note's measurements of her reference (≈57° and
   ≈0.29 s) are recorded **beside** them as dials, not substituted for them.
9. **Docs-only task.** No code is written in Task 88. Every step below is a later task.

## 2. What the design must contain

1. **Owners, unchanged in number (rule 3).** Exactly one camera owner (`Camera`, the only writer of
   `workspace.CurrentCamera`) and exactly one owner of the drawn viewmodel (`Camera.Viewmodel`). Say
   explicitly who owns: the first-person eye pose, the carry/ADS blend, sway, bob, recoil on the drawn
   gun, recoil on the camera, the arms, and the reload motion. If any of those wants a new module, say
   which owner it belongs to and why it is not a second writer.
2. **The flag**, as §1.7, with the row's `owner`/`born`/`expires`/`why` and the one boundary read named
   (`Flags.isOn("FIRST_PERSON")` read once, passed inward — the only permitted shape).
3. **ADS must be GEOMETRIC, not a hand-tuned offset** (note §4.3). The gun carries a **`Sight`
   attachment** whose look direction runs along the rib through the bead; aiming blends the viewmodel
   until that attachment coincides with the camera, less eye relief. **`Weapon.Hardware` creates it,
   beside the `Muzzle` attachment it already creates** for exactly this reason. Decide and write down:
   who owns the per-variant `Sight` value, given that the parts gun has a real `Bead` part
   (`Weapon.Shape`) and **Karen's uploaded gun is exactly one MeshPart** (`Assets`: "the template is
   EXACTLY ONE MeshPart"), so the mesh's value is a measured constant.
4. **The one testable number: bead alignment.** In ADS steady state the bead must project within
   **8 px of screen centre at 1920×1080** (`Camera:WorldToViewportPoint`; 0.37° at the 50° ADS FOV).
   Say which spec asserts it, on which Instance, and what it does when the viewmodel is not parented.
   This is the check that stops "measured correct, looks wrong" (`docs/PROJECT_CONTEXT.md`).
5. **The shot must not move.** The shot ray stays `workspace.CurrentCamera.CFrame`
   (`docs/design/shotgun.md` §5.5). Sway, bob and recoil are **cosmetic** and may never change the
   ray; say where that boundary is enforced. Note the simplification worth recording: at the eye the
   origin and the muzzle are within a stud, so `CAMERA_ORIGIN_TOLERANCE`'s 30 studs and the camera-ray
   ignore list stop mattering in this branch (they stay for the OFF branch).
6. **What happens to the numbers that stop meaning anything** in first person —
   `THIRD_DISTANCE_STUDS`, `SHOULDER_STUDS`, `MAX_DISTANCE_STUDS`, the occlusion cast,
   `BODY_HIDE_BLEND`, `VIEWMODEL_SHOW_BLEND`. Each: kept for the OFF branch, or deleted, said once.
7. **The numeric table** (note §6), as the one config table, with every new number marked as the
   Director's first pick and Karen's to change.
8. **The step plan**, exactly these five, each small, each behind the flag, each with the screenshot
   that proves it. **Say what each screenshot must show** (the note's §7 table is the starting point;
   sharpen it):
   - **S1** — first-person camera + no crosshair + gun carried low-left.
   - **S2** — ADS raise to the bead + FOV change, with the pixel measurement of §2.4.
   - **S3** — hands/arms on the gun, in both poses.
   - **S4** — recoil kick and return, plus the break-open reload motion. **Constraint from the note
     §5.4: a single MeshPart has no barrel to hinge**, so specify the whole-gun tilt and name the
     asset split (a later asset task) as the upgrade.
   - **S5** — sound, later, judged in a playtest and not by a screenshot.
   For each step say what a spec can assert and what only Karen can judge.
9. **What must keep working**: the existing client specs that assert the third-person framing
   (`tests/client/camera_client.spec.luau`) belong to the OFF branch and must not be deleted; the
   aim-source seam, the foreign-write detector and `Camera.lookAt` (used by the harness's staging and
   by `shoot_boar.spec`) must survive in both branches.
10. **Open decisions**, if any, listed as questions with a recommendation each — the Builder does not
    guess a design decision, and a blocking open decision is a `FAIL` line in `ARCH_RESULT.md`.

## 3. Constraints and non-goals

- No new system owner unless the design argues for one. No new HUD element. No Rojo container changes.
- No `.rbxm`, no binary. Nothing from the reference clips is committed, embedded or copied — they are
  third-party footage that was looked at, and the note records what was measured from them.
- No local absolute Windows paths, emails or keys anywhere in the design (CI fails on them).
- Do **not** design the animation system for the whole game here: S4 is the break-open motion of one
  gun, not a general animation owner.
- Karen is the judge of every feel number. Where the design picks one, it says so in one line and
  names it as hers to change.

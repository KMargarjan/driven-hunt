# Task 89 — S1: first person behind a flag, no crosshair, the gun carried low-left

Task: 89
Round: 1
Base: `main` (`0a6e5e0`)
Code commit: `1fa975600e8329def048a45ec21b655ef46ae433`

```
[harness2] PASS: 32/32 checks @ 1fa975600e8329def048a45ec21b655ef46ae433 (clean tree)
[harness]  PASS: 32/32 checks @ 1fa975600e8329def048a45ec21b655ef46ae433 (clean tree)
```

My own `gate.sh` at this head, on the map world, **with `FIRST_PERSON` OFF and no override set**
(`flags.py` printed `override none` before the run and again after the screenshots).

**What changed.** `src/shared/Flags/init.luau` (the row), `src/client/Camera/Config.luau` (the one
boundary read plus the carry numbers), `src/client/Camera/Mode.luau` (`carryOffset`, the
`cameraCFrame` branch, the new `viewmodelOffset`, the ten cosmetic state fields at rest),
`src/client/Camera/init.luau` (no occlusion cast in ON, the body-hide branch, `isFirstPerson`),
`src/client/Camera/Viewmodel.luau` (takes the state; stays parented in ON),
`src/client/Hud/init.luau` (`crosshairVisible`), `tests/server/camera_mode.spec.luau` (7 new cases),
`tests/client/camera_client.spec.luau` (the branch guard, the two live branch blocks, the crosshair,
the new signature), `GAME_DESIGN.md` (three owner rows), `TASKS.md` rows 89/89a and the Director's
A–H ruling transcribed into row 88a.

## Claims

1. **IT IS BORN OFF AND NOTHING A PLAYER SEES CHANGES.** `Flags.DEFAULTS.FIRST_PERSON.default` is
   `false`, `expires = 2026-10-18`, owner `StarterPlayerScripts.Camera` — the design's row verbatim
   (§6.6). Both harness lines above are the OFF branch, and the client spec printed
   `[camera_client] FIRST_PERSON = false (Config false, flag false)` at the code commit. Verify: the
   row, and `Camera.Config.FIRST_PERSON = Flags.isOn("FIRST_PERSON")` — **the one boundary read**, the
   first in `src/client/` (grep `Flags` there).

2. **EVERY FUNCTION THAT NEEDS THE SWITCH TAKES IT AS `config`, so the server spec drives BOTH
   cameras in every run at one flag value** (`feature-flags.md` §13.3). `tests/server/camera_mode.spec`
   builds `firstPerson = table.clone(Config)` with `FIRST_PERSON = true` and runs the geometry cases
   against both tables. Verify: the `first person, by parameter` describe.

3. **THE CAMERA IS AT THE EYE AT EVERY BLEND, and inside every tolerance that binds.**
   `Mode.cameraCFrame` with the ON table, at blends 0, 0.25, 0.5 and 1: the position is within
   `AIM_PIVOT_FORWARD_STUDS + 1e-4` of the pivot, under 2 studs from the root, under
   `MAX_DISTANCE_STUDS` and under the shotgun validator's 30 (`CAMERA_ORIGIN_TOLERANCE`, which the
   fire origin is measured against). There is no boom to ease along, so the blend moves the field of
   view and the gun and not the camera.

4. **A CASE THAT WOULD PASS WITH THE BRANCH DELETED IS WORTH NOTHING**, so one asserts the two
   branches *disagree*: at blend 0 the ON and OFF cameras are more than 10 studs apart, and they still
   agree about where the player is looking (`LookVector` dot > 0.999). Verify: `disagrees with the
   third-person branch, which is the whole point of the flag`.

5. **THE CARRY POSE IS LOW AND LEFT, WITH THE THREE DEGREES CONVERTED AT ONE SITE.**
   `VIEWMODEL_CARRY_POS_STUDS = (-0.95, -1.45, -2.6)` and `CARRY_PITCH/YAW/ROLL_DEG = -12 / -14 / 8`;
   `Mode.carryOffset` is the only `math.rad` of them. The spec rebuilds the rotation from the same
   three numbers and compares all twelve CFrame components to 1e-6 — a second conversion or a missing
   `math.rad` moves the muzzle by more than a stud (the Task 19 cone-unit defect made mechanical).

6. **THE NEAR PLANE IS AN ASSERTION, NOT A HOPE.** All eight corners of the gun's own box
   (`Shotgun.CONFIG.HANDLE_SIZE`, 4.4 studs long about its centre) are measured in **both** poses
   against `NEAR_PLANE_MARGIN_STUDS = 0.25`. Measured at this commit and printed by the run:
   `task89: nearest gun corner to the camera -0.411 studs (blend 0 corner 0.2, -0.25, 2.2),
   margin 0.25`.

7. **THE COMPOSITION ORDER IS WRITTEN ONCE, AND IT IS EXACTLY IDENTITY TODAY.**
   `Mode.viewmodelOffset(state, sightLocal, config)` takes the whole state and multiplies sway and bob
   **before** the pose (camera space: they move the gun across the frame) and recoil and the
   break-open tilt **after** it (gun space: the gun turns about its grip). The ten cosmetic fields
   exist at their exact rests and **nothing in this build moves them** — so the spec asserts the
   result is the pose **bitwise** (`to.equal`, not a tolerance), in both branches at blends 0, 0.5 and
   1, which is what S2's bead measurement will rest on. `Mode.step` and `Mode.anglesToward` both clone
   rather than rebuild, and a case asserts every field survives both.

8. **NO CROSSHAIR IN THIS BRANCH, EVER, AND THE DRAWING IS CHECKED AS WELL AS THE PREDICATE.**
   `Hud.crosshairVisible(state, aiming, firstPerson)` is pure and public; the spec drives all eight
   combinations (false whenever `firstPerson`, **including not aiming**) plus the third-person
   combinations, so "always false" cannot pass it. The second case asserts the **live** GUI equals the
   predicate for this build's own three inputs — the half that stops a predicate being right while the
   drawing is wrong. Run output: `crosshair drawn=true, predicate=true (firstPerson=false,
   aiming=false)` and `drawn=false, predicate=false` while aiming. The Hud asks
   `Camera.isFirstPerson()`, never `Flags`.

9. **THE LIVE BRANCH IS COUNTED, NOT ASSUMED.** Exactly one of `third person — the live OFF branch`
   and `first person — the live ON branch` is *built*, and the last `it` in the client file asserts the
   counter is 1: `[camera_client] live branch: third person (1 built)`. A guard that silently skipped
   would report a pass for a branch that never ran; this fails instead.

10. **FOUR MUTATIONS, APPLIED IN ONE RUN, EACH FAILING ITS OWN NAMED CASE, THEN RESTORED**
    (`[harness] FAIL: 28/32 @ 1fa9756 (DIRTY)`): the `FIRST_PERSON` branch in `cameraCFrame` disabled
    → `camera_mode.spec:279` (the eye) **and** `:296` (the branches disagree); the carry Z pulled from
    −2.6 to −1.0 → `:349` (the near plane); the crosshair predicate's `firstPerson` term dropped →
    `camera_client.spec:880`; no live branch block built → `camera_client.spec:953` (the counter).
    The tree was restored and `selene`, `stylua --check` and the gate are green at the code commit.

## What is not in this task, and what I could not verify

- **The ON branch's live wiring is untested by the harness**, and that is the flag's stated cost
  (design §9.4): `test`/`test2` refuse to start while an override is set, and a playtest with the
  override on runs no specs. Its maths is covered by parameter, its pose by the viewmodel cases, its
  live wiring by the screenshots below.
- **Sway, bob, recoil and the tilt have no maths anywhere** — fields and composition only (TASKS 89a).
- **One deliberate deviation:** the design writes the body-hide step as one expression which, read
  literally, drops the OFF branch's `mode ~= "Dead"` guard (round 2 finding 2). The branches are
  written out so the OFF branch is untouched. TASKS 89a(a), for the Architect.
- **The screenshots, described as they are** (override on, then cleared; `flags live` confirmed
  `Source=override FIRST_PERSON=true`). *Shooter, standing:* first person at eye height, **no reticle
  anywhere**, the shotgun's barrel crossing the **lower-left** corner with the muzzle reaching about
  45 % across and three-quarters down — the stock and receiver are off the bottom-left, so roughly
  half the gun is in frame — **no body part and no second gun visible**, and no orange hat brim over
  the view, so the local body (the hat with it) is hidden. Two bright orange wedges sit in the top
  corners: **I first took them for the player's own hat and they are not** — the third-person capture
  from Task 82 at the same post shows two orange marker cubes on poles flanking the player, and from
  between them at eye height they clip both top corners. The scene is **dark**: the shooter's post is
  under a tree canopy, so "daylight" it is not, while the *driver's* capture at the same moment is
  bright daylight. *Driver, standing:* first person, no reticle, **no gun** (drivers carry none), no
  body, ground close under a pitched-down view with no floating parts and no hole where the character
  should be.
- **Not taken:** the design's second S1 shot, looking straight down at the feet, and a walking shot.
  Both need input the harness can only replay inside a gated run, and a gated run refuses to start
  with the override set. The carry pose is speed-independent in S1 (no bob), so a walking capture
  would be the same image. Clipping against a tree at close range is therefore **not tested** either.

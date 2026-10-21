# Task 227 — aiming the lever rifle and the semi-auto, fixed to what Karen sees

Task: 227
Round: 1
Base: `main` @ `12ffd2ed` (branch `task-227-aim-lever-reddot`, created by the Director)
Code commit: `a8c10b2a9f1eece57e80b6fa3c3865027dbdfe77`

```
[harness] PASS: 33/33 checks @ a8c10b2a9f1eece57e80b6fa3c3865027dbdfe77 (clean tree) scope=all
```

`[harness2]` **N/A**: nothing in the change is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The eight
changed paths are `src/client/Camera/Viewmodel.luau`, `src/shared/Gun/init.luau`,
`src/shared/Lever/Geometry.luau`, `src/shared/SemiAuto/Geometry.luau`,
`src/shared/Viewmodel/poses.json`, `tests/server/lever.spec.luau`, `tests/server/semiauto.spec.luau`
and `TASKS.md`. This is weapon and viewmodel work: it behaves the same with one player as with two,
which is the Director's 2026-10-03 decision verbatim.

## What changed, and why

Karen, 2026-10-21, after buying and shooting both guns: *"Aiming with lever i terrible and broken you
need to fix / Semi auto aiming cant see true that red it has to be visible and dot in the middle"*.

**Both defects were reproduced before anything was changed** (rule H), in DEV, from eye height,
through the seam the client specs use — a Handle in a Tool carrying `DrivenHunt.Weapon` through
`Camera.Viewmodel.setSource`, driven by the production `Viewmodel.update` at a fully blended
`Aiming` state. The DEV place has no lodge, so `Shop.atCounter` is false there by construction and a
purchase is refused `TOO_FAR`; that seam is the one the Director's dispatch names as the alternative.
Before: `.screenshots/227-before-lever-aim.png`, `.screenshots/227-before-semiauto-aim.png`.
After: `.screenshots/227-after-lever-aim.png`, `.screenshots/227-after-semiauto-aim.png`.

## Claims

1. **The lever's rear sight was measured wrong in task 224, and that is the whole defect.**
   `Lever.Geometry`'s header carried *"the rear notch floor y +0.1901"* and *"0.0055 degrees from
   level"*. `driven-hunt-runs/t224/measure.py` computes that number as `min(p[1] for p in rs)` over
   the whole `Sights` node — the LOWEST point of the rear sight, i.e. where it sits on the rail, not
   the notch. It agreed with the front blade's tip at +0.1903 by coincidence.
   *Verify:* read `measure.py`'s `base = min(...)` line and the string it prints beside it, then
   `src/shared/Lever/Geometry.luau`'s header block, which now states both numbers and the error.

2. **Re-measured on the source geometry, through the same one frame.**
   `driven-hunt-runs/227-sights.py` imports `tools/gltf_split.py` and uses `measure_frame`, exactly
   as task 224 did, and slices the `Sights` node's top surface across x. Measured: ears +0.2301,
   notch floor +0.2226 (the slot is 0.0075 deep), blade tip +0.1903 at z −1.9135. Shoulders to tip
   is −0.03983 over 2.2309 = **−1.0229 degrees**, not level.
   *Verify:* run `python driven-hunt-runs/227-sights.py` and read the per-slice table — the central
   band tops out 0.0075 below the outer ones, which is the slot.

3. **`Lever.Geometry.sight` now answers a ROTATED frame, and that removes the free parameter.**
   `Mode.aimOffset` composes `sightLocal:Inverse()`, so a frame whose −Z is the gun's own sight line
   turns the gun until that line runs down the screen's centre: both sights land on the centre by
   construction, with `cheekDeg` left at 0. A cheek angle hand-tuned to the same effect would have
   been a number tuned by eye, which is what this file's own header forbids.
   *Verify:* `Geometry.sight` in `src/shared/Lever/Geometry.luau`; `Mode.aimOffset` in
   `src/client/Camera/Mode.luau` is unchanged.

4. **The aim is right, measured through the production maths on the live build.**
   Rear notch depth **0.6187** studs in front of the eye, **0.0000 deg** off centre; front blade
   depth **2.8500**, **0.0000 deg** off centre.
   *Verify:* `tests/server/lever.spec.luau`, case *"THE SIGHT PICTURE: both sights land on the
   screen's centre at aim"*, which drives `Mode.aimOffset` with this weapon's own `Geometry.sight`
   and its own `poses.json` numbers and prints both through `TestKit.note`.

5. **That case cannot pass by accident: two negative arms, both from the build that shipped.**
   With an unrotated sight frame the notch misses the centre by **3.68 deg**; with the shipped-before
   `eyeReliefStuds` of 0.9 the notch is **1.33 studs BEHIND the eye** — the eye sat 0.98 studs behind
   the MUZZLE with the receiver, the stock and the lever all behind the player's head, which is the
   `227-before-lever-aim.png` frame.
   *Verify:* the same case's last two blocks.

6. **The eye relief is content, and it was written through `pose.py`'s own serializer (rule J).**
   `weapons.lever.aim.eyeReliefStuds` 0.9 → 2.85, nothing else in `poses.json` touched. 2.2313 of
   that is blade-to-notch, so the eye sits 0.619 studs behind the notch. 3.15 was tried and
   photographed: it brings the right glove (posed at z +1.203) to 0.03 studs IN FRONT of the lens.
   *Verify:* `git diff 12ffd2ed..HEAD -- src/shared/Viewmodel/poses.json` is one line;
   `python tools/pose.py selftest` passes.

7. **The semi-auto's aim axis was already exact — the glass is what is wrong.**
   The dot projects **0.000000 deg** off centre at depth 0.9. The `semiauto.sight` upload is ONE
   MeshPart whose glass is a solid amber face: photographed against the sky, the window reads a flat
   **(96, 36, 0)** with no sky through it and the screen centre reads **(0, 1, 0)**, pure black,
   because the drawn `Dot` sits inside the housing.
   *Verify:* `.screenshots/227-before-semiauto-aim.png`; `tests/server/semiauto.spec.luau`, case
   *"THE SIGHT PICTURE: the dot is on the screen's centre and the housing clears it"*.

8. **`Gun.Piece.clearFromBlend` is the new field, and `Camera.Viewmodel` is its only writer.**
   The housing fades out of the sight line over the last of the raise (`Viewmodel.clearAtAim`, pure
   and public), applied once per frame beside the pose through `applyClear`. The list is collected
   per build from the pieces themselves and cleared in both `Viewmodel.clear` and the rebuild, like
   `builtMeshes`. The gun's own `Dot` is kept and no second reticle owner is created.
   *Verify:* `clearFromBlend` in `src/shared/Gun/init.luau`; `Viewmodel.clearAtAim`, `applyClear`,
   `clearParts` in `src/client/Camera/Viewmodel.luau`; the `Optic` piece in
   `src/shared/SemiAuto/Geometry.luau`.

9. **Nothing else fades, and the sight is still solid everywhere Karen can see it.**
   `clearAtAim` answers 0 for `from = nil` (every piece of every other gun), 0 in `Third`, 0 at the
   threshold blend, 0.5 half way past it and 1 at full aim; exactly one piece in the semi-auto's
   list carries the field and it is the `Optic`; the shotgun, the Rigby and the lever carry none.
   So carry, mid-raise, third person and `Hud.ShopDisplay`'s card are untouched.
   *Verify:* the same `semiauto.spec` case drives all five values and walks the other three guns.

10. **Smoke, in a 108 s Play in DEV** (rule A). (1) the Tool is in the CHARACTER at 15 s and at
    108 s — `toolInCHARACTER=[Shotgun] inBackpack=[Rifle]` both times, read off the INSTANCES because
    StudioMCP's `require` has its own module cache. (2) the whole console, read in full rather than
    its last 6000 characters: 125 lines, **0** "Stack Begin", **0** "attempt to", **0** "invalid
    argument"; the only three `failed` lines are Roblox's own
    `rbxassetid://203785492 … Asset type does not match requested type`, which appears nowhere in
    `src/`, `tests/` or `tools/` and follows a CorePackages Scheduler trace. (3) the change ran, on
    instances in that session: the lever's `Sight` attachment read `(0, 0.1903, -1.9135)` — the
    re-measured blade tip — and the semi-auto's drawn gun reported `cleared=[Optic@1.00]` at full
    aim. Screen centre: lever `(37, 41, 42)` (the blade in the notch), semi-auto `(253, 0, 2)`.
    *Verify:* `.screenshots/227-smoke-lever-aim.png`, `.screenshots/227-smoke-semiauto-aim.png`,
    `driven-hunt-runs/227-smoke-console-full.txt`.

## What I could not verify

- **Not in the Forest Test, and not on a BOUGHT gun.** Karen buys both guns at the lodge counter;
  the DEV place has no lodge, so the purchase path itself is unexercised here. What the purchase
  changes is which Tool reaches the hand — the drawn gun, its geometry and `Mode.aimOffset` do not
  know which world they are in — but it is stated rather than claimed.
- **Karen has not looked.** She said *"I tested no testing from my side work on it"* on 2026-10-21
  and the Director looked at both frames instead (approved merging looks unseen, 2026-10-17).
- **Two Studios were connected during the gate.** Karen's Forest Test was still open and closing it
  is a click I cannot make. The harness resolves by a live `game.PlaceId` read since task 226, and
  the run proves where it went: `[server] report comes from the DEV place (136410205938347)` and the
  same line for the client.
- **Two known defects are NOT fixed and are queued as `TASKS.md` 227a**: the lever's receiver renders
  near-white at the lens (pre-existing — it is in task 224's own accepted
  `.screenshots/t224r3-carry-solved.png`), and the aim HAND poses are still the ones tasks 224 and
  225 flagged unseen. This task moved only `aim.eyeReliefStuds` and touched no `left`/`right` block.

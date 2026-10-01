# Task 97 — the carry, the aim and the raise, from the new side-by-side video

Task: 97
Round: 2
Base: main (ee8fed5) — PR #87
Code commit: 19368ba6129249c192eccb7bcfd63a775d3b3193

```
[harness2] PASS: 32/32 checks @ 19368ba6129249c192eccb7bcfd63a775d3b3193 (clean tree)
[harness] PASS: 32/32 checks @ 19368ba6129249c192eccb7bcfd63a775d3b3193 (clean tree)
```

## Claims

1. **Finding 1, the number: one source, and no comment restates it.** `EYE_RELIEF_STUDS = 3.90`.
   The block above it derives that value and nothing else names a relief: `Assets/init.luau`'s hand
   comment now points at the constant instead of repeating it, and the bead-marker comment states its
   size as a ratio. Verify: `grep -rn "3\.65\|3\.80\|4\.40" src/` finds only the sentence recording
   what round 1 shipped.
2. **Finding 1, the defect: the glove is mechanically clear of the lens.**
   `tests/server/camera_mode.spec.luau`, "keeps both gloves clear of the near plane, even at the
   recoil's ceiling", drives `Mode.viewmodelOffset` in BOTH poses with
   `recoilGunBackStuds = RECOIL_MAX_GUN_BACK_STUDS` and `recoilGunPitchDeg = RECOIL_MAX_GUN_PITCH_DEG`,
   hangs each hand at `Mode.rightHandOffset`/`leftHandOffset` as `Viewmodel.addHand` does, and
   measures all eight corners of each against `NEAR_PLANE_MARGIN_STUDS` — 32 corners, asserted to
   have run. Measured in the run: **nearest corner −0.351 studs, 0.10 of surplus**.
   **MUTATION-CHECKED**: put `3.65` back and that assertion, and only it, fails
   (`camera_mode.spec:910`); restored.
3. **The value is bounded on three sides, and the CARRY is what binds it.** The carry holds the gun
   closest to the eye and does not move with the relief at all, so the only lever there is where the
   right hand sits; the first configuration that cleared the aim left the carry with 0.005 studs of
   surplus. The hand moves forward to the gun's Z = +0.54 — and no further, because
   `camera_mode.spec`'s own task-93 guard (`right.Z > breechZ`, 0.528) is what makes it the body's
   hand and the other the barrels'. That guard caught the move at +0.52. The two bounds meet within
   a fiftieth of a stud; the comment says so and names a shorter glove as the only real headroom.
4. **The stock case asserts both halves again.** At this relief the butt is behind the camera plane,
   so `rearmost > 0` is back beside `buttFromAxisDeg > 40` — the angle is kept because it is the one
   that still means "out of the picture" if a later relief puts the butt just in front, which is what
   round 1's did.
5. **Six of the Reviewer's notes are fixed in place**: the 1.28-stud comment in `assets_seam.spec`,
   the recoil case's title, the driver arm's missing positive assertion, the session-wide
   `handsDrawn` counter, the muzzle provider compared against itself (now against
   `Viewmodel.muzzle`), and the carry-angle derivation, which now says the pose was re-solved.
   `PLAYTEST.md` gains Karen's 2026-10-01 words and `TASKS.md` a row 97, which two `licence`
   fields already cite.

## Evidence

* `.screenshots/task97-compare-aim.png`, rebuilt from the SHIPPED numbers — the wrist and the dark
  action fill the bottom centre, two rounded barrel tops flank the rib, the bead sits at the top dead
  centre on the shot line, and the pale glove is gone from the frame. Ours is smaller than the
  video's and shows more action and less wood than it does.
* `task97-compare-carry.png` and `task97-compare-raise-mid.png` are round 1's: neither pose changed.

## What I could not verify

* **The right hand still renders untextured white** (round 1's finding, unchanged): same prep run as
  the left, which is brown, and re-uploading identical bytes to a new id did not change it. Its
  `SurfaceAppearance` needs looking at in Studio.
* **The aim is smaller than `TARGET-aim`** — the barrel pair reads about 18 % of the screen width
  against the 30–35 % the Director asked for. The glove's clearance is what stops it coming closer.

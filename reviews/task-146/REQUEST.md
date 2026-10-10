# Task 146 - Karen's sight picture, and the left hand back the way it was

Task: 146
Round: 2
Base: main (`3bfc86c`)
Code commit: `7d9ad5950837645463c0134d30491bec4c5586c9`

```
[harness] PASS: 33/33 checks @ 7d9ad5950837645463c0134d30491bec4c5586c9 (clean tree) scope=all
```

`test2` is N/A: the diff is the Hud, the rifle's data, `poses.json` and two specs — nothing in
`TWO_PLAYER_PATHS`.

Karen, 2026-10-10, with a reference image: *"left arm is oposit, put in a position like it was /
right hand also oposit / each time shootion has to reload with right hand, once 3 shots made with
left hand taking out magazine and ution back and then right hand reload like with rifles / scope
aiming has to be different cross look at the exaple I attached / when aiming without scope remove
righs (scope holding rings) / fix those"*. Transcribed in `PLAYTEST.md`.
**No Architect run:** no new owner and no new system.

**TWO OF HER FIVE ARE FIXED, ONE WAS ALREADY RIGHT AND IS NOW MEASURED, ONE I COULD NOT REPRODUCE,
AND ONE NEEDS AN UPLOAD.** Claims 8–10 are the three that did not ship.

## The ten claims

1. **THE LEFT HAND WAS A 60-DEGREE TWIST, AND "LIKE IT WAS" IS LITERAL.** Task 143 moved the rifle's
   left glove from the shotgun's own `twist = -150` to `-90` after a live sweep I ran and judged.
   Karen has overruled that. **Verify:** `git show 54c7759:src/shared/Viewmodel/poses.json` has
   `-150`; `poses.json` has it again, in `carry`, `aim` and `cycle`, on both rifles. Six numbers,
   nothing else in the content-lane diff.

2. **IT IS VERIFIED AGAINST THE GUN SHE APPROVED, NOT BY EYE ALONE.** `tools/pose.py inspect carry`
   photographs the viewmodel from a fixed outside angle, so the shotgun and the rifle can be compared
   in the same pose from the same place:
   * `20261010T082113Z-inspect-carry-left-front.png` (shotgun, approved): the pale khaki cuff sits
     ABOVE and BEHIND, the brown glove cups the barrels from BELOW.
   * `20261010T082045Z-inspect-carry-left-front.png` (rifle at `-90`, what Karen played): the two are
     **swapped** — brown glove above, cuff behind-right. That is "opposite", in a frame.
   * `20261010T082309Z-inspect-carry-left-front.png` (rifle at `-150`): the shotgun's arrangement.

3. **THE SIGHT PICTURE IS HER REFERENCE — AND ROUND 1 PUT THE MEASUREMENT IN THE WRONG FIELD.**
   `eyepiece.diameterDeg` is the OUTER circle and `Hud.layoutScope` draws the tube INWARD from it, so
   the clear lens is `diameterDeg - 2 * rimThickDeg`. At task 141's hairline `rimThickDeg = 0.45`
   those were nearly the same number; at the 1.69 this task measured they are not. **Round 1 shipped
   14.22 degrees of glass — 0.716 of the screen height — while claiming 0.886, which is SMALLER than
   the 0.810 task 141 drew.** The Reviewer's finding 1, and it was right.

   Her jpg is 1920x1080: the clear glass is 960 px (0.889 of the height) and the tube around it is
   92 px. So the glass wants `0.889 * 19.87 = 17.66` degrees and the whole circle wants that plus
   both walls — `17.66 + 2 * 1.69 = 21.04`.

   ```
   diameterDeg 21.0 - 2 * 1.69 = 17.62 deg = 0.887 of the height   (hers 0.889)
   at 1080: outer 1141 px, tube 92 px (hers 92), glass 958 px (hers 960)
   ```

   **THE TUBE THEREFORE RUNS OFF THE TOP AND BOTTOM**, which is exactly what her frame shows — the
   body is cut by the picture edge rather than floating inside it. So `layoutScope`'s clamp is on the
   GLASS now and not on the whole circle: what may never leave the screen is the part you look
   through, because the reticle's degrees are measured against it. **Verify:** `rifle.spec`'s "keeps
   the world outside the tube, and the tube is a scope body" asserts
   `(diameterDeg - 2 * rimThickDeg) / aimFovDeg` against 0.889 — the assertion that would have caught
   round 1 — and `rifle_client.spec` reads the DRAWN `Rim` frame off the live viewport and asserts
   the same share, so the config and the pixels have to agree. The gate printed it:
   `rifle: clear glass 0.887 of the viewport (Karen's frame: 0.889)`.

4. **THE CROSS RUNS EDGE TO EDGE, WITH NO RING AND NO POSTS.** They are not hidden by a zero: they
   are **not in the data**, and `Hud.layoutReticle` draws what it finds — the rule the dot has
   followed since task 142, now applied to the rest of the furniture. **Verify:** `rifle_client.spec`,
   "lays out as a cross that spans the glass, with no ring and no posts" asserts `Ring.Visible` and
   `PostTop.Visible` are both false and that the arm is the lens's radius less the tube.

5. **AND THE CROSS IS CUT TO THE GLASS, not to a number of its own.** `spanLens` makes the arms a
   function of the EYEPIECE, so changing the glass moves the hairs with it and the two cannot
   disagree. That is why `Hud.layoutReticle` now takes the whole `optics` block rather than
   `optics.reticle`.

6. **THE WORLD OUTSIDE THE TUBE IS NO LONGER PAINTED OUT.** `maskTransparency = 0.45` on the mask's
   stroke. **ROBLOX UI CANNOT BLUR**, so "softened" is darkened and nothing else — the one half of
   her note this cannot do, said out loud rather than quietly dropped. **Verify:** `t146-final-scope
   -aim.png` against her jpg: grass, trunks and the far treeline are all there, dark.

7. **THE RED DOT IS A DATA TOGGLE, DEFAULT ON AND SMALL.** She asked for it on 2026-10-09; her
   example has none. `dot.enabled` is one line either way, and `rifle_client.spec` asserts the
   default. On screen it is a 4-5 px red point sitting on the cross.

8. **THE RELOAD ALREADY PLAYS EXACTLY AS SHE DESCRIBES — TRACED, NOT ASSUMED.** Three real shots
   through the live remote (`driven-hunt-runs/t146-reload.luau`), reading the wire and the drawn
   model:

   ```
   +0.28 Break -> +0.56 Close            the bolt, after the shot
   +6.24 Break -> Close    live=0        the third shot: the magazine is empty
   +6.91 Magazine busy=1.35 live=3       the magazine comes out and goes back
   +8.25 Break -> Close                  ...and THEN the bolt chambers
   RIGHT hand travelled 0.825 studs (worst at +6.28, on a bolt)
   MAGAZINE travelled 0.420 studs (worst at +7.45, inside the magazine window)
   ```

   **Nothing was changed for this item**, because nothing was found to change.

9. **I COULD NOT REPRODUCE "RIGHT HAND ALSO OPPOSITE", AND I AM NOT GUESSING AT IT.** The rifle's
   right hand is **bit-for-bit the shotgun's** in every pose — carry `(-24.4176, -35.5376, -103.1991)`
   and aim `(-12, 60, 115)` — which is the orientation the dispatch names as the target, so copying
   the shotgun's changes nothing. Its POSITION is on the rifle's own measured pistol grip: the stock
   drops to `y -0.2958` at `z +1.05..+1.15` (`driven-hunt-runs/t146-grip.py`) and the aim hand is at
   `(0, -0.22, 1.1)`. **This one needs Karen to point at a frame** — hip, aimed or mid-cycle — or
   the next change to it would be me moving a number by taste.

10. **THE MOUNT RINGS CANNOT COME OFF WITHOUT A NEW UPLOAD, and here is the measurement.** They are
    inside the uploaded `rifle.action` mesh: the split plan puts `Vijsjes_Low` — 3196 triangles
    reaching `y +0.2916`, which is scope height — in the **action** group, while the `scope` group is
    only `Scope_Low` and `ScopeKnop_Low`. Moving that node to the scope group is a one-line plan
    change, but it makes two new meshes and both need Karen's OK and a moderation wait
    (`assets/uploads.json`). **`ESCALATE.md` carries it as `NEEDS KAREN` with the exact steps.**

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t146-final-scope-aim.png` (re-shot on the round-2 build) | **The tube is one flat grey where hers is shaded**, and the glass is not brighter than the surround as it is in her frame — UI primitives give a flat colour and no exposure. Everything the note asked for is there: a **thin black cross running the full width and height of the lens**, **no ring and no posts**, a **thick grey scope body cut off at the top and bottom** as hers is, the **forest outside it visible and dark** rather than black, and the small red dot on the centre. Round 1's version of this frame had a visibly smaller lens — that is finding 1 on screen |
| `t146-final-carry.png` | The left glove is **small and half behind the barrel** at this angle, so it reads as a cuff more than a hand — but the arrangement is the shotgun's: pale cuff above, brown glove below the wood |
| `20261010T082045Z` / `082309Z` / `082113Z-inspect-carry-left-front.png` | The three-way comparison of claim 2: rifle before, rifle after, shotgun. The gun fills the frame diagonally in all three (that is what `pose.py inspect` does) and the hands are small; the cuff/glove order is still unmistakable |
| `t146-open-aim.png` (before this task) | **The mount ring sits dead centre of the open-sight picture**, which is claim 10 and the reason Karen asked for it |

## Standing rule A, Forest Test, 85 s, with RIFLE ON

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 24 boars alive

## What I could not verify, and what went wrong on the way

* **ROUND 1'S CENTRAL NUMBER WAS WRONG AND THE SPEC I WROTE COULD NOT CATCH IT.** I measured Karen's
  frame correctly and then asserted the OUTER circle against it, so the case passed on a lens a fifth
  too small. Both specs now assert the glass, and the client one reads it off the screen.
* **THE FIRST GATE RUN ON THE ROUND-1 COMMIT READ 31/33**, immediately after the Rojo sync; the two runs
  after it read `PASS: 33/33 ... (clean tree) scope=all` with 829 server and 180 client assertions
  and no failures. The same thing happened in task 144 and I still have not captured WHICH two checks
  fail — it is worth a task of its own, and row 130a is where it belongs. Round 2's gate was green on
  the first run.
* **Nobody has seen the aim pose's left hand from outside.** `pose.py inspect aim` answered "no
  viewmodel is drawn" twice: an interrupted inspect leaves the live model hidden, and separately the
  OS-key script toggles a hotbar slot, so pressing `2` on a held rifle puts it away. The carry frame
  is the one I have, and carry, aim and cycle carry the SAME rotation by construction.
* **I kept one rotation across carry, aim and cycle** rather than restoring the shotgun's own aim
  rotation `(85, 110, -165)`. The shotgun's left hand MOVES between those poses and the rifle's does
  not — it is on the forend in all three — so a different rotation in aim would spin the glove for no
  reason. If Karen meant the aim pose specifically, it is three numbers.
* **The dot's size, the tube's grey and the 0.45 darkening are dials**, not measurements: her
  reference has no dot to measure, and a jpg's grey is not a colour value.

## Round 2, in one line

The Reviewer's two blocking findings were the same defect: `diameterDeg` is the outer circle, the
glass is what is left inside the tube, and round 1 asserted the first against a measurement of the
second. Both are fixed, both specs now assert the glass, the gate is green and the frame is re-shot.

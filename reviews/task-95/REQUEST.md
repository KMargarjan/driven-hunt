# Task 95 — the walk pose, the raise and the aim, from Karen's reference

Task: 95
Round: 1
Base: `main` (`1443cde`)
Code commit: `a4b727aa6d54db4dcf1fdd9259b7db00682eed65`

```
[harness2] PASS: 32/32 checks @ a4b727aa6d54db4dcf1fdd9259b7db00682eed65 (clean tree)
[harness]  PASS: 32/32 checks @ a4b727aa6d54db4dcf1fdd9259b7db00682eed65 (clean tree)
```

Behind `FIRST_PERSON`, still **default OFF**. Screenshots are throwaway sessions with it on, cleared
after. The reference is `REF-SHEET-carry-aim.jpg`, panels A and C.

## Claims

1. **THE CARRY IS PANEL A'S DIAGONAL.** The gun lies across the lower left: the muzzle meets the LEFT
   EDGE two thirds of the way down, the action sits at the bottom edge about a third across, the
   stock is out of the picture, and the line runs up-left at about **28 degrees** -- the Director's
   20-25 asked for a flatter carry than round 1's 37. Solved from those two points and then moved
   twice by looking, because the arithmetic lands within ten degrees of where a viewmodel renders;
   both the solving and the two moves are written where the numbers live.
2. **THE SPEC ASSERTS WHAT THE PICTURE CLAIMS.** The muzzle is left of -1.5 studs and further away
   than the action; it is **higher in the FRAME** than the action by more than 5 degrees (an angle in
   the view, not the gun's pitch -- the bore is 2 degrees below level and still rises across the
   screen); both ends stay below the horizon; the action is low, left and clear of the near plane;
   and the butt is past the CORNER of the field of view, so it cannot be in frame.
   `task95 carry: muzzle 41.6 deg left, 23.3 deg above the action in view, action 1.62 studs`.
3. **THE FOREND BELONGS TO THE GUN AGAIN.** Karen's wood was carved for the generated barrels --
   fatter, and running into the action -- so against the built tubes it read as a separate dark flap
   with daylight above it and a gap behind it. `rebuildBarrels` MOVES her wood rather than replacing
   it: stretched back along the gun's own axis until its rear meets the cut (x1.22) and lifted if it
   hangs below the tubes, and only the vertices that belong to the forend alone, because one shared
   with the action would tear the mesh at the seam. Asset **126484176321060**, Approved, manifest
   **v8**; v7 kept and superseded, and the seam spec's chain check follows.
4. **THE RAISE AND THE AIM ARE UNCHANGED FROM THE ROUND THE DIRECTOR ACCEPTED.** One eased swing,
   0.25 s up and 0.20 s down (`Mode.blendSeconds`), the muzzle peaking at 6.9 degrees above the
   horizon -- the carry itself -- and no step backwards on the way; the aimed picture still leaves the
   bottom edge a quarter of the screen wide with the action out of frame.
5. **TASK 92 STILL HOLDS.** No crosshair; `task90 bead: worst 0.00 px from the shot line and the
   screen centre`; the ADS rotation is about the bead, so the aim point does not move; recoil and the
   muzzle flash are untouched code and their cases pass.

## Not verified

- Karen has not played it; the Director compares the frames.
- The carry reads at 28 degrees against the 20-25 asked for -- closer than round 1, not exact.
- Sway and bob are still exactly identity; nothing moves them yet.

# Task 95 — the walk pose, the raise and the aim, from Karen's reference

Task: 95
Round: 2
Base: `main` (`1443cde`)
Code commit: `3c564ad0d79bc5cd655235c1417719748ab826c6`

```
[harness2] PASS: 32/32 checks @ 3c564ad0d79bc5cd655235c1417719748ab826c6 (clean tree)
[harness]  PASS: 32/32 checks @ 3c564ad0d79bc5cd655235c1417719748ab826c6 (clean tree)
```

The `[harness]` line is a SECOND one-player run at the same commit: the first failed `hit_marker.spec`
waiting for its tick to clear while a real marker from the staged shot arrived at +42.8 s inside that
wait. `test2` passed the same spec at the same commit, and nothing in this round touches the Hud.

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
3. **THE FOREND, AND WHAT IT NOW LOOKS LIKE IN THE GAME.** In `t95r3-carry` the wood is one piece
   with the gun at the action end and runs forward UNDER the barrels as a dark walnut wedge; toward
   its front it narrows away from the tubes and a thin dark gap opens between its top edge and the
   barrel's underside. The flap that hung off the gun with daylight above it and a gap behind it is
   gone; that front wedge is not. `rebuildBarrels` MOVES Karen's wood rather than replacing it --
   stretched back along the gun's axis until its rear meets the cut (x1.22), lifted only if it hangs
   below the tubes, and only the vertices that belong to the forend alone, because one shared with
   the action would tear the mesh at the seam. Asset **126484176321060**, Approved, manifest **v8**;
   v7 kept and superseded, and the seam spec's chain check follows.
4. **THE RAISE RISES, AND THE GUARD SAYS SO.** This commit's own numbers: the muzzle sits about
   **1.2 degrees** above the horizon in the carry and **5.4** in the aim -- the cheek angle tips the
   gun nose-up about the bead -- so it climbs across the swing and the AIMED pose is the highest it
   gets (`task95 raise: muzzle peaks at 5.4 deg up at blend 1.00; aimed is 5.4 deg`). Round 1 said the carry was the
   highest, which was true of an earlier pose and not of this one. The case now asserts that the
   swing never climbs above where it ENDS, which is what "never points at the sky" means for a move
   whose end is not the sky, and still checks the pose sweeps there without a step backwards. One
   eased swing, 0.25 s up and 0.20 s down.
5. **TASK 92 STILL HOLDS.** No crosshair; `task90 bead: worst 0.00 px from the shot line and the
   screen centre`; the ADS rotation is about the bead, so the aim point does not move; recoil and the
   muzzle flash are untouched code and their cases pass.

## Not verified

- Karen has not played it; the Director compares the frames.
- The carry reads at 28 degrees against the 20-25 asked for -- closer than round 1, not exact.
- Sway and bob are still exactly identity; nothing moves them yet.

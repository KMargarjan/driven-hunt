# Task 96 — the break-open reload

Task: 96
Round: 1
Base: `main` (`d4de4c7`)
Code commit: `ea047aa1f5686e6c357295c3d7315a57f7c2196d`

```
[harness2] PASS: 32/32 checks @ ea047aa1f5686e6c357295c3d7315a57f7c2196d (clean tree)
[harness]  PASS: 32/32 checks @ ea047aa1f5686e6c357295c3d7315a57f7c2196d (clean tree)
```

Karen, 2026-09-27: a BREAK ACTION like the real Beretta 486 Parallelo, not the reference game's
pump-style reload. Behind `FIRST_PERSON`, still default OFF.

## Claims

1. **THE GUN IS TWO PIECES, AND THEY ASSEMBLE AT ONE CFRAME.** `asset_prep` writes the model out
   split at the same plane it cut the generated barrels off at -- barrels with Karen's forend (2,073
   tris), body with her action and stock (9,701) -- and bakes the WHOLE gun's bounding box into each
   half as two anchor triangles a ten-thousandth of a unit across, so Roblox imports both at the same
   size and origin. Uploaded under her OK: body **121405298612730** (`shotgun.handle` v9), barrels
   **85998258056906** (`shotgun.barrels` v1), both Approved; v8 kept and superseded. The seam spec
   asserts both keys preload, one row each, and that the two rows share size, rotation and offset.
2. **NOTHING ABOUT THE RELOAD'S RULES OR CLOCK MOVED.** The server still owns break, load, load,
   close and their timings; the client replica carries `open`; `CameraBoot` hands it to the camera as
   a source exactly like the aim flag. The drawn swing is 0.22 s open and 0.16 s shut, both inside
   the server's own 0.5 and 0.6 -- asserted, so the motion always finishes inside the state that
   started it -- and `openTilt` reaches exactly 1 and exactly 0 at 240, 60 and 20 fps.
3. **THE BARRELS HINGE, THE BEAD RIDES THEM, THE SHELLS COME AND GO.** `Camera.Viewmodel` rotates
   the `Barrels` piece 35 degrees about the knuckle: the client case measures 0.000 deg off the body
   when shut, 35.00 when open, the muzzle DOWN, one spent shell per barrel that FIRED (two for two,
   one for one), none when shut, and nothing at all in the third-person branch. The BEAD is parented
   to the barrel group and placed from the same transform, so it swings down to the muzzle instead of
   floating where the muzzle was -- asserted twice over: it moves more than 0.2 studs, and its offset
   in the barrels' own frame does not change by a ten-thousandth. Shut, that transform is identity:
   `task90 bead: worst 0.00 px from the shot line and the screen centre`.
4. **THREE DEFECTS THE SCREEN AND THE SPECS FOUND, each fixed at its cause.** The boot preloaded one
   key by name and `wearsMesh` said yes to a gun wearing the body alone, so every gun handed out
   before the barrels landed stayed body-only for ever -- the boot preloads the manifest's own key
   list now, `wearsMesh` means both, and `addBarrels` is its own idempotent step. `addBarrels` was
   called at the end of the Model branch alone, so a MeshPart body never got barrels (the spec's note
   read `body=true barrels=false` while the game looked right). And the break pose is its own pose:
   added to the carry it put the whole gun outside the picture.
5. **OTHERS SEE THE SAME GUN.** The two pieces are welded to the same Handle at the same pose, with
   `CanQuery = false` and `Massless` as before; the Handle is still the only part a ray can hit, the
   Muzzle and Sight attachments have not moved, and no crosshair appeared. The bead measurement is
   unchanged: `task90 bead: worst 0.01 px from the shot line and the screen centre`.

## Not verified

- Karen has not played it. The "chambers" a player sees are the barrels' own open ends rather than
  modelled chambers.
- The five frames were taken with the reload slowed in a throwaway tree (a capture takes ~4 s against
  a 2 s reload); the POSES are the shipped ones, the speed is not what they show.
- The mesh bead sits on the body, not the barrels, so during the swing the drawn bead does not travel
  with them.

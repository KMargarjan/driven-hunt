# Task 169 -- the beater's horn gets a real model

Task: 169
Round: 2
Base: main @ 4be5455 (PR #152 merged)
Code commit: daed44a319b9218c14185691cfc713bd6e3b51f4

KAREN, 2026-10-12 ~21:45: *"We need better horn"* -- the LOOK. Task 152 built the horn out of nine
welded cylinders and its own header says why (the two plausible free Creator Store horns answer
`LoadAsset` with "User is not authorized to access Asset"). She found one herself and gave the upload
OK the same evening: *"Yes, upload it"*. It is now asset **105611404389014**, approved.

Harness, FULL, twice, both on the clean tree at the code commit:

```
[harness] PASS: 33/33 checks @ daed44a319b9218c14185691cfc713bd6e3b51f4 (clean tree) scope=all
[harness] PASS: 33/33 checks @ daed44a319b9218c14185691cfc713bd6e3b51f4 (clean tree) scope=all
```

**Round 1's one blocking finding is fixed, and it was right.** The uniformity guard compared an
absolute 1e-3 against a scale of 1.25 / 1164.78 = 0.00107, so it was no guard at all -- the
Reviewer's own counter-example, a Y/Z swap (the horn squashed to 55 % in one axis and stretched 81 %
in the other), passed both lines. It compares RELATIVELY now, at 1e-4, which the committed numbers
clear by four orders of magnitude (7e-9 and 8.9e-8). Claim 5 below is that case. One sentence of
`GRIP_BLOW`'s comment that disagreed with itself went with it (round 1's last note); the shipped
value is unchanged and is still the photographed one. The other four notes are queued as **169a**.

`test2` is **N/A**: no path in `TWO_PLAYER_PATHS` is touched (the change is `src/server/Weapon/`,
`src/serverstorage/Assets/`, `src/shared/Horn/`, two server specs and two prep tools -- no `Match`,
no `Drive`, no `tests/client/Role.luau`, no two-player spec).

## Claims

1. **The horn is one uploaded MeshPart with ONE `SurfaceAppearance`, and the download's two material
   slots are why that needed work.** `scene.gltf` carries materials `horn` and `metal` over ONE set
   of three images; `collapse_materials` in `tools/asset_prep_blender.py` merges slots that link the
   same image datablocks and leaves slots over different images alone. *Verify:* read
   `collapse_materials` and `import_model`; the prep report records
   `collapsedMaterials: {collapsed: true, slots: [horn, metal], kept: horn}` and `materials: [horn]`.
   Measured in the live Forest Test: the worn part has exactly one `SurfaceAppearance` child.
2. **`Weapon.Horn.build` wears the mesh and falls back to the parts horn, and nothing was deleted.**
   `Horn.addMesh` borrows `Hardware.addPieceMesh` -- the one path the shotgun's barrels and the
   rifle's four groups already take -- and `Horn.addParts` / `Horn.removeParts` are the pure list's
   two directions. `Horn.pieces` is untouched and is still what a beater carries if the asset will
   not load. *Verify:* `Horn.build` in `src/server/Weapon/Horn.luau`;
   `tests/server/zz_horn.spec.luau` -> "builds a horn from parts when there is no uploaded horn to
   wear" and "wears the uploaded horn when the template is there, and no parts under it".
3. **A horn handed out before the preload lands is upgraded in the hand it is already in.**
   `WeaponBoot` starts the systems BEFORE it preloads, on purpose, so that window is real -- the gun
   needed `Weapon.upgradeLook` for exactly this (task 123 round 9). `Horn.upgradeLook` runs on the
   existing carry sweep, touches only the Handle's children, and is idempotent. *Verify:*
   `Horn.upgradeLook` and `Horn.start`'s sweep; the spec "upgrades a parts horn into the mesh when
   the template lands later", which also asserts the `Blast` sound survives `removeParts`.
4. **The geometry is stated once.** `Horn.MESH` holds the four numbers and the manifest row
   `horn.body` reads them; `Weapon.Horn` reads them back off the row through the template provider,
   never out of its own file. *Verify:* the row in `src/serverstorage/Assets/init.luau`; the spec
   "has a manifest row, approved, under the key the horn names" compares all four.
5. **The scale is uniform and it is a real horn.** `NATURAL_SIZE_STUDS` (1164.78, 404.13, 223.34) was
   MEASURED off the live template in the Forest Test (`ServerStorage.AssetCache.Object_4` size
   = 1164.7756, 404.1294, 223.3446), not guessed; `SIZE_STUDS` is 1.25 studs over all, which is 0.35 m
   at `METRES_PER_STUD`. *Verify:* the spec "is scaled UNIFORMLY, so the horn in the hand is the horn
   that was looked at" -- it holds all three axes to one ratio and the length to 0.2-0.4 m.
6. **The rotation is -90 BECAUSE A SCREENSHOT SAID SO, not because the file's axes said so.** The
   mouthpiece is at the model's own -X (its cross-section grows 0.72 -> 2.23 units toward +X), so +90
   should have put the bell forward; photographed in the raise it hung BELL DOWN AT THE CHEST with
   the tip past the head (`.screenshots/20261012T224700Z-t169-horn-raised-close.png`). That is task
   107's reversal again, the same one `Gun.MESH_ROTATION_DEG` carries. Flipped and re-photographed:
   `...224741Z-t169-horn-raised-flipped.png`. *Verify:* `Horn.MESH.ROTATION_DEG` and its comment.
7. **The raise still puts the mouthpiece at the face with the new geometry.** The horn is 1.25 studs
   long against the coil's 0.76, so the old `GRIP_BLOW` held it two thirds of a stud lower down its
   own length. Y 0.05 -> -0.22 and Z 0.4 -> 0.3, which is the pose that was photographed.
   *Verify:* `.screenshots/20261012T225535Z-t169-raised-server.png` -- the grip in that frame came
   from the SERVER (`-0.42, -0.22, 0.30`), not from a client override; and
   `...225339Z-t169-carry-final2.png` for the carry.
8. **The licence is honoured in three places and asserted in one.** CC-BY-4.0 asks for a credit:
   `CREDITS.md` has the entry with the licence's own credit line, the `HORN_LICENCE` row carries the
   same attribution, and `assets/uploads.json` records the upload with Karen's OK verbatim. *Verify:*
   the spec "credits its author, which is the whole of what its licence asks". Nothing was painted
   out of this atlas -- the "R4VL" mark on a band is the artist's signature on his own work.
9. **The runtime preload count moved by one, and the spec says why rather than being loosened.**
   `assets_seam.spec` walked `Weapons.ROWS` to decide what `keysFor("runtime")` must hold; a horn is
   not a gun and has no row there, so the horn's key is now counted beside the guns'. *Verify:* the
   diff in `tests/server/assets_seam.spec.luau` -- the count is still derived, never typed.
10. **The one gun-side change is a default argument.** `Hardware.addPieceMesh` gains an optional
    `missingWarning`; every call written before this one gets the sentence it always printed.
    *Verify:* `Hardware.addPieceMesh` and its one new caller.

## What I could not verify

- **Whether Karen likes it.** The look is hers. Two third-person screenshots are inspected and named
  above; the first-person framing is NOT re-tuned, and the horn is now 1.65x longer than the coil
  that `GRIP` was photographed for, so it takes more of the bottom-right corner than it did. That is
  task **168b**'s open item, and it is one `GRIP` line.
- **The sound.** Nothing here touched the voice, and no spec in this repo can load audio.
- **The two-player picture.** Not run: no `TWO_PLAYER_PATHS` path is touched.
- **The wave count in the smoke console.** `ftplay.py console` returns the last 6000 characters only,
  so the wave lines had scrolled off. What IS measured in that session: the Tool is in the CHARACTER
  at 15 s and at 86 s, wearing the mesh with one `SurfaceAppearance` and no parts under it; zero
  "Stack Begin" and zero error lines; and three horn blasts published, the last pushing 3 boars.

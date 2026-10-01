# Task 97 — the carry, the aim and the raise, from the new side-by-side video

Task: 97
Round: 1
Base: main (ee8fed5) — PR #87, retargeted from `task-93-fp-hands` now that it is merged
Code commit: da926feb1bcdc38af9ca0798a90036c8f6b9feef

```
[harness2] PASS: 32/32 checks @ da926feb1bcdc38af9ca0798a90036c8f6b9feef (clean tree)
[harness] PASS: 32/32 checks @ da926feb1bcdc38af9ca0798a90036c8f6b9feef (clean tree)
```

## Claims

1. **`FIRST_PERSON` is ON by default and the row is still the rollback.** `src/shared/Flags/init.luau`:
   `default = true`, every other field kept. Both camera specs build BOTH configs themselves, so no
   case anywhere tests "whatever booted" — verify: no `, Config)` call remains in `camera_mode.spec`
   or `camera_client.spec`; `Config` is read for numbers only.
2. **The two poses are solved from the target frames, then measured on screen.** The carry comes from
   three readings of `TARGET-carry.jpg`; the aim's eye relief comes from the barrel pair's share of
   the screen width in `TARGET-aim.jpg`. Both record the correction the screenshot forced. Verify:
   `camera_mode.spec`, "carries the gun ACROSS THE BODY" (the muzzle is ABOVE the view axis and more
   than 25 degrees above the action) and "puts the stock behind the eye when aiming" (the butt is
   more than 40 degrees off the axis — an angle, because at this relief it is in front of the camera
   and still far out of the picture).
3. **The hands are where Karen put them.** 2026-10-01: *"left arm has to be on pipes and right on
   stock holding and aiming"*, *"left hand has to be further, right hand closer"*. The left hand is
   at the gun's Z = −0.85 (under the forend, toward the muzzle) and the right at +0.80 (the grip,
   just behind the trigger at +0.78). Verify: `camera_mode.spec`, "where the hands sit on the gun" —
   the right is behind the breech, the left in front of it, both below the bore, neither past the
   muzzle. The hand model is shortened to 0.95 studs because at the new relief the 1.28-stud one
   reached the lens and a Roblox MeshPart the camera is inside shows its own back surface.
4. **The action is dark steel, not chrome.** `tools/asset_prep.py`'s `action` region goes from
   RGB(172,172,172) at metalness 0.70 / roughness 0.35 to RGB(88,90,95) at 0.20 / 0.62. Re-prepped,
   re-uploaded as the BODY half only (the barrels' maps are untouched), `shotgun.handle` v10, id
   75977232140256, Approved. Verify: the manifest row, `assets/uploads.json`, and
   `assets_seam.spec`'s own count guard — which caught this row on the first gate run and now asserts
   ten rows with v10 live.
5. **Three gate failures, three real findings, none of them re-run blindly.** (a) the manifest count
   guard above; (b) a shooter tied to a tree reaches the forged-remote case disarmed, and
   `TIE_UNTIL_DRIVE_END` keeps him there — for a tied player that case now asserts the tie's own
   claim; (c) the barrels' at-rest bound was 0.01 degrees, tighter than a float32 CFrame round trip,
   and the driver measured 0.020 where the shooter measured 0.000. It is 0.1 now, still 350 times
   smaller than the 35-degree swing it exists to catch.

## Evidence, described as it is

* `task97-compare-carry.png` — both run the gun from the bottom centre to the left edge with a gloved
  hand on the barrels at the lower left; the muzzle leaves the left edge at the same height. Ours is
  steeper (our viewport is 1.24:1, the reference 16:9, and Roblox's field of view is vertical).
* `task97-compare-aim.png` — same picture now: wrist filling the bottom centre at 27 % of the width
  (asked 25), dark action and top lever, two rounded barrel tops at 25 % (asked 30–35), bead at the
  top dead centre on the shot line. Ours is still a little smaller than the video's.
* `task97-compare-raise-mid.png` — both catch the gun part way up, barrels from the lower right to
  the upper left. Ours is further through the swing than the video's frame.

## What I could not verify, and one defect I could not fix

* **The right hand renders WHITE, untextured.** Same prep run and same preset as the left hand, which
  renders brown; the file embeds its three PNGs; re-uploading the identical bytes to a new id
  (`hand.right` v2, 114416997151977) did not change it, and Studio logs nothing. It is an asset-side
  fault, not the drawn code — one function draws both hands. The next step is to look at that asset's
  `SurfaceAppearance` in Studio, which I have no way to do from here.
* **The bead's offset from the shot line in pixels.** Geometric and asserted to 1e-4; it reads as the
  screen centre in the capture, but I did not measure the pixel. The Director's "55–60 % from the
  top" cannot hold at the same time as "on the shot line": the shot goes through the screen centre.
* **Recoil and smoke**, which Karen also named. Not in this task.

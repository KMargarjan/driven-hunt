# Task 106 — Karen's new gloves on model B, and the two-player run's blast radius

Task: 106
Round: 1
Base: `main` (`fb0bd00`)
Code commit: `6b2649e489cafe2dfca1c341dbcf6600b53d7221`

```
[harness] PASS: 32/32 checks @ 6b2649e489cafe2dfca1c341dbcf6600b53d7221 (clean tree)
[harness2] PASS: 34/34 checks @ 6b2649e489cafe2dfca1c341dbcf6600b53d7221 (clean tree)
```

Karen made both gloves in her own paid Meshy account on 2026-10-02 and gave the upload OK the same
day: "upload ok". Behind `NEW_GUN`, still born OFF. Uploaded and Approved: right `97259644277702`,
left `74971853808718`; the v1 rows carry `supersededBy = 2` and keep their own frozen sizes.

## Claims

1. **The size is pinned to the GRIP, not to a hand's length, and the old number is why.** At 1.27
   studs the right glove measured **0.665 across the fingers — 173 mm, nearly twice an adult palm**.
   Model B's stock wrist is **0.320 studs (83 mm)** long, so the dial is `HAND_ACROSS_STUDS` = 0.35
   (91 mm) and the longest axis follows at 0.669. Verify: `gun.spec` "is sized to the grip it closes
   on", `assets_seam.spec` "keeps the viewmodel's rows out of the server's preload".
2. **`uniformTo` pins the LONGEST axis, not X.** The left glove's longest axis is Z — a palm-up C
   puts the forearm at an angle to the fingers, so its box is a diagonal. Both gloves are scaled to
   one number and come out the same size, which `gun.spec` asserts.
3. **The rotations were measured, not guessed.** One capture with every angle at zero and the hands
   held clear of the gun (`.screenshots/20261002T111038Z-pose-aim.png`) showed the right glove's
   fingers at its mesh +X with the cuff at −X, and the left glove's cuff at +X with the C opening up.
   Hence left yaw −90, right yaw +90, and the old left `twist` of 180 (a palm-DOWN model) is now 0.
4. **The gloves arrived WHITE and the rows say why.** With `textureId` nil the first live frame
   showed both as white blobs (`...110256Z-pose-aim.png`) — task 99's white glove exactly. The two
   `ColorMap` ids were read through the harness (a plugin context; a game script cannot) and written
   into the rows with fallback colours measured off each prepped `texture_baseColor.png`.
5. **The two-player line is not required when EVERY changed code file is first-person viewmodel**
   (`tools/agents.py`'s `WEAPON_VIEWMODEL_PATHS`). All or nothing; the one-player line is still
   required for everything. Verify: `python tools/agents.py selftest` (both directions, now in CI),
   CLAUDE.md "Run / test". **This task is not exempt and ran both**, because it changes `tools/`.

## What I could not verify

- **The drawn sleeve was removed and put back in the same session.** With the new gloves' own turned
  cuff it looked redundant; the broken-open frame proved it is not. It is now 2.6 studs long (was
  1.6) and seated 0.30 inside the cuff (was 0.12). I did not re-measure every pose for a visible
  cuff end — three were looked at and none shows one.
- **The reload still draws the action and the barrels far apart** (`...112224Z-pose-reload.png`),
  which is task 103/104's open problem and not the gloves'.
- **The carry pose still sits mostly off the left edge**, unchanged from task 105.

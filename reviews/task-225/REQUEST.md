# Task 225 review request — the semi-automatic shotgun

Task: 225
Round: 2
Base: `2eb78b4e` (main, after task 224 merged)
Code commit: `5211678e06476a3c88d62a18ef47dd339e7dae13`

```
[harness] PASS: 33/33 checks @ 5211678e06476a3c88d62a18ef47dd339e7dae13 (clean tree) scope=all
```

`test2` is **N/A**: nothing here is in `TWO_PLAYER_PATHS`, and `tools/agents.py` agreed in round 1
("24 code file(s) changed, 0 needing two players"). It touches no `Match/`, no `Drive/`, no
`MatchBoot`, no `Role.luau` and none of the named match specs.

CI: green at the code commit (run 39514243802, `Build and lint`).

---

## What changed

A fourth weapon row — an MP-153-pattern gas-operated 12 gauge, bought in the shop at 500 and carried
only by a player who owns it. Design `docs/design/semiauto-shotgun.md` (ARCHITECT PASS); note
`docs/research/2026-10-20-semiauto-shotgun.md`. Most of it is the lever rifle's shape again; three
things are new, and one shipped behaviour improved.

## Round 1's three findings, and what each cost

**Finding 1 was a real defect and the Reviewer was right.** The drawn sight piece was named `Sight`,
which is `Camera.Viewmodel.SIGHT_NAME` — the *Attachment* the eye is laid on — and
`Hardware.SIGHT_NAME` on the world Tool as well. `Viewmodel.sight()` resolves it with
`FindFirstChild` then `IsA("Attachment")`, so the **part** was found first, failed the class test,
and the whole aimed pose fell back to `VIEWMODEL_AIM_OFFSET`: `eyeReliefStuds` and `cheekDeg` were
dead and the red dot was never on the camera axis. **Claim 7 of round 1 was wrong in practice.** The
fix took two goes, and the second was found by the case the Reviewer asked for: the first rename
called the sight *mesh* `RedDot`, so the new case went looking for the dot, found the housing
instead, and measured them **0.56 studs apart**. Two things now have two names — `Optic` is the
uploaded housing, `Dot` is the drawn Neon ball — and the case measures **0.000000 studs**.

**Findings 2 and 3 are written and both enter their arm.** The aim is reached by parameter at blend
1 and measures **0.9421 studs from the hip**, which is what proves the aimed pose is solved rather
than falling through to a default; and `X` on a full tube reports
`ammo=Slug but chamber=Buck, 5 live`, with the Hud printing `5/5 BUCK 10` and the chip `buck`.

Six of the notes are also fixed: both missing `SCOPE_SPECS` scopes, the duplicated `Gun.Group`
comment, the `poseShare` helper that had been inserted into the middle of another function's doc
comment, the 12 anchor triangles that explain 8,736 against 8,724, and a client booting mid-reload
reading its first snapshot as a fed shell.

## Claims

**1. The sight name no longer shadows the aim attachment, and the case proves it.**
*Verify:* `SemiAuto.Geometry.MESH_KEYS.Optic`, the piece named `Optic`, and the row's
`MESH_NAMES` — the three must say one word, because `meshFor(piece.name)` looks the mesh up by piece
name and `publishGunPiece` walks the keys. `semiauto_client.spec`'s dot case asserts the drawn `Dot`
is within 1e-3 of `Viewmodel.sight()`'s attachment **and** that no part at all is named `Sight`; it
names the edit that makes it fail.

**2. The bought file has no rig, so the split was read off the geometry — and looked at.** Measured
two ways (Blender, and a stdlib parser of the FBX binary): no armature, no deformer, no skin weight,
and none of the five bone names the dispatch lists. *Verify:* `SEMIAUTO_PLAN`'s comment in
`tools/gltf_split.py`; `driven-hunt-runs/t225/parts-*.png` and `zoom-{right,bottom}.png` are the
twelve-colour frames each identification was read off. The handedness is proved by the gun — the
charging handle and the bolt release are the only two nodes off the centre line and lie on the same
side.

**3. The scale is anchored on the barrel and checked three ways, none of them fitted.** 710 mm puts
1 file unit at 882.9 mm, and then the overall length measures 1254 mm against a published 1250, the
receiver 37.7 mm against 38, and the tube 4.1 shells of 76 mm against a published **4+1**.
*Verify:* `SemiAuto.CONFIG`'s `HANDLE_SIZE` and `BARRELS` comments; research note section 3.

**4. `CYCLE_KIND = "straight"` is a fourth branch, not a reuse.** Reusing the Rigby's `"slide"` would
hold the bolt still for its first `BOLT_LIFT_FRACTION` and need a `boltLift` returning identity — the
silent-number defect task 188 was raised for. *Verify:* `Viewmodel.hinge`'s branch;
`Geometry.boltTravel`, which owns the sign and clamps to the measured maximum. The client spec
measures **+0.3600 studs in Z and 0.0000 in X/Y** on the real instance.

**5. A SECOND moving group, which no gun here has had.** The bolt moves on `CYCLE`; the lifter moves
on each `Load` of `RELOAD`. Its envelope is parented to the **Handle and not the bolt**, it has its
own clock, and its ramp goes **up and back down** because a tray takes the next shell. *Verify:*
`Gun.Group`'s `"lift"`; `buildNewGun`'s envelope and parent branch; `Viewmodel.lift`;
`Geometry.lifterSwing` / `lifterTipOffset`, whose sign is falsifiable. The client spec measures the
tray **+0.0553 in Y, turned 0.3420, with the bolt moving 0.0000**, and back to 0.0000 of rest.

**6. The gun must NOT move when it cycles itself.** `cycle.poseShare`, read at the two sites that
already blend on `openTilt`. **Absent means 1**, so the three shipped guns are bit-for-bit what they
were — `semiauto.spec` asserts each of them still moves (1.7133 / 2.0481 / 2.1436 studs) while this
one moves **0.000000**.

**7. The ammunition is the side-by-side's BY REFERENCE** — the opposite of the lever's rule, for the
opposite reason: the two shotguns fire one cartridge. `AMMO_KINDS` / `AMMO_LABEL` / `AMMO_GLYPH` moved
into `Shotgun.CONFIG`; no value changed. *Verify:* `semiauto.spec` asserts **table identity**, not
equality, against both `Shotgun.CONFIG` and the shotgun's row.

**8. The red dot is drawn, not textured.** `SurfaceAppearance` has four channels and no emission, so
the artist's emissive map would render as nothing. A 3 mm `Neon` ball at the sight's own measured
optical centre, through task 143's `onlyFor` filter, at `x = 0` because the shot leaves at `x = 0`.
*Verify:* `Geometry.pieces`' `Dot`; the server spec checks it is Neon, has no `meshKey`, is on the
centre line, comes from the **same expression** `Geometry.sight` aims with, and is dropped when the
same geometry is asked for a `bead`.

**9. The model is shifted +0.0235 studs once, so the BORE lands on the centre line.** `gltf_split`
centres the bounding BOX and the charging handle pulls that off the bore. *Verify:* `BORE_X`, applied
once; **after** it the fore-end's own centre measures x +0.0020 and the sight's glass x −0.0032 —
two independent parts, both inside a millimetre.

**10. Both hand anchors are bounded as LINES, and the poses were SOLVED onto them**
(`pos = P − R·GRIP_STUDS`, not typed by eye). *Verify:* `semiauto.spec`'s two cases compute through
`Mode.handOffsetAt` and report **0.0000 off both axes** at hip, aimed and cycle, against bounds
0.0601 and 0.0768. The same solver reproduces the lever's shipped pose to 0.0000.

**Also:** `Camera.fedShell` reads the live-chamber count, already on the wire, so the gate voice
fires **once per shell** instead of once per run — closing 224a(e) without the protocol change it was
queued against. **This changes the LEVER's audible behaviour** (five clicks for five cartridges);
design D-c, the Director's to refuse.

---

## What I could NOT verify, and why

* **Three of the four look frames, and a live shot over the shop counter.** I have **one**
  first-person frame in the Forest Test (`.screenshots/225-fp-carry.png`), looked at: barrel, vent
  rib, rail, receiver and magazine cap all read correctly, in a dusk scene. The aimed / mid-cycle /
  shell-into-port frames and a real shot need the gun **bought**, and `Economy.grant` cannot be
  reached from a live probe — a probe gets a fresh `Economy` whose `enabled` is false, so it answers
  `shop-closed` whatever the flag says. Handing the character a fabricated Tool *draws* the gun
  (which is how the carry frame exists) but binds no aim or fire, because it carries no server weapon
  state. **The behaviour those frames would show is measured instead**, on real instances — the
  numbers are in claims 1, 4, 5 and 6, and the round-1 defect proves the measurement was worth more
  than the picture would have been.
* **Karen's eye.** Nobody here has heard the three voices or felt the recoil, and **the carry pose is
  unconfirmed — as the lever's still is** (task 224 shipped with its carry pose unseen). Both guns
  now sit on the same pose system, so if she rejects the lever's hold, both weapons' pose data moves
  together. Flagged rather than left to surface later.
* **Smoke (rule A) was not run as a clean PASS**; the session was deliberately non-standard. From it:
  the whole server + client console had **0 "Stack Begin" and 0 error lines**, and all six uploads
  loaded — `[ViewmodelAssets] published 6 of 6 semiauto piece(s)` plus a `[WeaponBoot] semiauto.*
  loaded` line per asset id. The Forest Test's `DHFlag_SHOP` attribute was captured (absent), set, and
  **restored and read back absent**; `DHForestStartRole` and `DHShopTestGrant` were untouched.

## What the design got wrong, and this task corrected

* Design 6.2 calls this "the slowest reload in the game". It is not: the lever's five cartridges
  through a gate cost 2.90 s and these five shells through a bigger port cost 2.60. The spec measures
  both comparisons rather than repeating the claim.
* Design 14 says `Geometry.partCount` is 9; its own row writes the drawn total as 12 including two
  gloves, and 12 − 2 is 10. The function answers 10 and the spec asserts it against the pieces
  actually built.
* Design 5.4 names a `SemiAutoTube` cylinder on the world gun; this ships `SemiAutoForeEnd` (a block)
  plus `SemiAutoSight`, reasoned in that file's header. The design row is stale — the Reviewer's note,
  and I agree it should be said rather than left.

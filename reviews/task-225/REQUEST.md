# Task 225 review request — the semi-automatic shotgun

Task: 225
Round: 3
Base: `2eb78b4e` (main, after task 224 merged)
Code commit: `8168e2036e24f293737e78ec8a6c3670395946b4`

```
[harness] PASS: 33/33 checks @ 8168e2036e24f293737e78ec8a6c3670395946b4 (clean tree) scope=all
```

`test2` is **N/A**: nothing here is in `TWO_PLAYER_PATHS`, and `tools/agents.py` agreed in round 1
("24 code file(s) changed, 0 needing two players"). It touches no `Match/`, no `Drive/`, no
`MatchBoot`, no `Role.luau` and none of the named match specs.

CI: green at the code commit (run 39516246755, `Build and lint`).

---

## What changed

A fourth weapon row — an MP-153-pattern gas-operated 12 gauge, bought in the shop at 500 and carried
only by a player who owns it. Design `docs/design/semiauto-shotgun.md` (ARCHITECT PASS); note
`docs/research/2026-10-20-semiauto-shotgun.md`. Most of it is the lever rifle's shape again; three
things are new, and one shipped behaviour improved.

## Rounds 1 and 2, and what each found

**Round 1, finding 1 was a real defect.** The drawn sight piece was named `Sight`, which is
`Camera.Viewmodel.SIGHT_NAME` — the *Attachment* the eye is laid on — and `Hardware.SIGHT_NAME` on
the world Tool as well. `Viewmodel.sight()` resolves it with `FindFirstChild` then
`IsA("Attachment")`, so the **part** was found first, failed the class test, and the aimed pose fell
back to `VIEWMODEL_AIM_OFFSET`: `eyeReliefStuds` and `cheekDeg` were dead and the red dot was never
on the camera axis. The fix took two goes — the first rename called the sight *mesh* `RedDot`, so the
new case went looking for the dot, found the housing, and measured them **0.56 studs apart**. Two
things, two names now: `Optic` is the uploaded housing, `Dot` is the drawn ball. The case measures
**0.000000**.

**Round 2, finding 1 is the sharpest catch of the task, and it was mine to make.** The
`CYCLE_POSE_SHARE` assertions **could not fail**. This gun's `carry.gun` and `cycle.gun` are
bit-identical in `poses.json`, so at blend 0 that `Lerp` is identity for every value of the share;
the hands were worse still, because all three hand poses are identical and the hand frame is
therefore constant across every state and every share. "The gloves held still" was asserting
nothing. Both are driven at **blend 1** now, where the sight-solved aim is not `cycle.gun`, and each
carries its **negative arm**: the same two frames with the share forced to 1 must MOVE the gun. They
do — **0.000000 studs at share 0 and 1.5233 at share 1** on the server, **0.0000 and 0.9421** on the
real instance. The hands get their own case saying plainly that the pose data holds them still and
the share does not, which is the truth about a gas gun.

**Round 2's other two.** `partCount` was *claimed* to be asserted and was not, by either number — it
is pinned on the real build now (`10 gun part(s) plus 2 worn`). And `ammoChipFor` always returns a
table, so the nil guard and the `to.be.ok()` could not fail; the case asserts the content
(`5 pip(s), glyph=buck`).

Ten of the twelve non-blocking notes are also fixed, including two overstated claims in my own spec
comments that round 2 was right to call out.

## Claims

**1. The sight name no longer shadows the aim attachment, and the case proves it.**
*Verify:* `SemiAuto.Geometry.MESH_KEYS.Optic`, the piece named `Optic`, and the row's
`MESH_NAMES` — the three must say one word, because `meshFor(piece.name)` looks the mesh up by piece
name and `publishGunPiece` walks the keys. `semiauto_client.spec`'s dot case asserts the drawn `Dot`
is within 1e-3 of `Viewmodel.sight()`'s attachment **and** that no DIRECT CHILD of the Handle is
named `Sight` — which is exactly the lookup `Viewmodel.sight()` does, and round 2 was right that the
wider wording overstated it. The case names the edit that makes it fail.

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

**6. The gun must NOT move when it cycles itself, and the proof has a negative arm.**
`cycle.poseShare`, read at the two sites that already blend on `openTilt`. **Absent means 1**, so the
three shipped guns are bit-for-bit what they were — `semiauto.spec` asserts each still moves
(1.7133 / 2.0481 / 2.1436 studs) while this one moves **0.000000**, *and* that forcing the share to 1
moves it **1.5233**. Without that second half the case would pass against a `poseShare` nothing read,
which is exactly what round 2 found.

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
`Mode.handOffsetAt` and report **0.0000 off both axes**, against bounds 0.0601 and 0.0768. The same
solver reproduces the lever's shipped pose to 0.0000. **Said accurately this time:** hip, aimed and
cycle are the same computation on this gun, because its three hand poses are identical — one pose
checked three times, which is the Reviewer's round-2 note and is now written into the case itself.

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
  numbers are in claims 1, 4, 5 and 6 — and round 1's defect and round 2's vacuous assertions both
  prove the measurement was worth more than the picture would have been.
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

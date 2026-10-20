# Task 225 review request — the semi-automatic shotgun

Task: 225
Round: 1
Base: `2eb78b4e` (main, after task 224 merged)
Code commit: `83b355f9fc420287ad0775e612f9febceb5edf34`

```
[harness] PASS: 33/33 checks @ 83b355f9fc420287ad0775e612f9febceb5edf34 (clean tree) scope=all
```

`test2` is **N/A**: nothing in this change is in `TWO_PLAYER_PATHS`. It touches no `src/server/Match/`,
no `src/client/Match/`, no `src/shared/Drive/`, no `MatchBoot`, no `tests/client/Role.luau` and none
of the named match specs — it is a weapon, its geometry, its pose data, its shop row and the camera
that draws it, all of which behave the same with one player as with two.

CI: green on this branch at the code commit (run 39509671559, `Build and lint`).

---

## What changed

A fourth weapon row — an MP-153-pattern gas-operated 12 gauge, bought in the shop at 500 and carried
only by a player who owns it. Design `docs/design/semiauto-shotgun.md` (ARCHITECT PASS, committed);
note `docs/research/2026-10-20-semiauto-shotgun.md`.

Most of it is the lever rifle's shape again. **Three things are new**, and one shipped behaviour
improved.

## Claims

**1. The bought file has no rig, so the split was read off the geometry — and looked at.**
The dispatch describes bones `Trigger` / `Zatvor` / `Lotok` / `Otse` / `Gauge12`. Measured two ways
(Blender, and a stdlib parser of the FBX binary in `driven-hunt-runs/t225/fbx_nodes.py`) the file has
**no armature, no deformer, no skin weight and none of those strings**; its twelve nodes are
`shotgun.0NN` and `sight.001`. *Verify:* `SEMIAUTO_PLAN`'s comment in `tools/gltf_split.py` lists what
each node is and why; `driven-hunt-runs/t225/parts-*.png` and `zoom-{right,bottom}.png` are the
twelve-colour frames each identification was read off. The handedness is proved by the gun: the
charging handle and the bolt release are the only two nodes off the centre line and both lie on the
same side.

**2. The scale is anchored on the barrel and checked three ways, none of them fitted.**
710 mm (a listed barrel length) puts 1 file unit at 882.9 mm, and then the overall length measures
1254 mm against a published 1250, the receiver 37.7 mm against 38, and the magazine tube 4.1 shells of
76 mm against a published **4+1**. *Verify:* `SemiAuto.CONFIG`'s `HANDLE_SIZE` and `BARRELS` comments;
research note section 3; `driven-hunt-runs/t225/measure-summary.txt`.

**3. `CYCLE_KIND = "straight"` is a fourth branch and not a reuse.** A gas bolt reciprocates and
nothing rotates. Reusing the Rigby's `"slide"` would hold the bolt still for its first
`BOLT_LIFT_FRACTION` and need a `boltLift` on this geometry whose only job is to return identity — the
silent-number defect task 188 was raised for. *Verify:* `Viewmodel.hinge`'s new branch;
`SemiAuto.Geometry.boltTravel`, which owns the sign (`-Z` is the muzzle, so back is `+Z`) and clamps
to the measured `BOLT_TRAVEL_MAX`. `semiauto.spec` drives both ends and the over-ask; the client spec
measures **+0.3600 studs in Z and 0.0000 in X/Y** on the real instance.

**4. A SECOND moving group, which no gun here has had.** The bolt moves on `CYCLE`; the shell lifter
moves on each `Load` of `RELOAD`. Declared beside the first (`LIFT_GROUP_NAME`), with its own
envelope parented to the **Handle and not to the bolt**, its own clock (`setLift` / `liftProgress`,
the exact shape `setMagazine` already has) and a ramp that goes **up and back down**, because a tray
takes the next shell. *Verify:* `Gun.Group`'s new `"lift"`; `buildNewGun`'s envelope block and parent
branch; `Viewmodel.lift`; `Geometry.lifterSwing` / `lifterTipOffset`, whose sign is falsifiable —
`semiauto.spec` asserts the free end is **higher** at full throw and by at least one hull diameter.
The client spec measures the tray **+0.0553 in Y, turned 0.3420, with the bolt moving 0.0000**, and
back to 0.0000 of rest afterwards.

**5. The gun must NOT move when it cycles itself, and that needed one number.** The shipped
break-action blend carries the gun and both hands to the action pose and back whatever the aim is —
right for a hand working an action, wrong for a gas piston, and at 0.42 s a shot it is a lurch out of
the sight picture 2.4 times a second. `cycle.poseShare` (published as `CYCLE_POSE_SHARE`) is read at
the two sites that already blend on `openTilt`. *Verify:* `Camera.Mode`'s `poseShare` helper.
**Absent means 1**, so the three shipped guns are bit-for-bit what they were — `semiauto.spec` asserts
that each of them still moves (1.7133 / 2.0481 / 2.1436 studs) while this one moves **0.000000**.

**6. The ammunition is the side-by-side's BY REFERENCE, which is the opposite of the lever's rule.**
The two rifles share no number because they fire different cartridges; the two shotguns fire the same
shell, so a second copy would be a second answer to how far a slug goes. `AMMO_KINDS` / `AMMO_LABEL` /
`AMMO_GLYPH` moved out of `Weapons.ROWS.shotgun` into `Shotgun.CONFIG` beside that cartridge's
ballistics (design 9.2, D-a). *Verify:* `semiauto.spec` asserts **table identity**, not equality,
against both `Shotgun.CONFIG` and the shotgun's row; no value moved.

**7. The red dot is drawn, not textured, and that is a fact about Roblox.** `SurfaceAppearance` has
four channels and no emission, so the artist's `M_Sight01_Emissive.png` would render as nothing. It is
a 3 mm `Neon` ball at the sight's own measured optical centre, through task 143's `onlyFor` filter, at
`x = 0` because the shot leaves at `x = 0`. *Verify:* `Geometry.pieces`' `Dot`; `semiauto.spec` checks
it is Neon, has no `meshKey`, sits on the centre line and comes from the **same expression**
`Geometry.sight` aims with — and that asking the same geometry for a `bead` drops it.

**8. The whole model is shifted +0.0235 studs once, so the BORE lands on the centre line.**
`gltf_split` centres the bounding BOX, and the charging handle pulls that off the bore — measured, the
barrel's muzzle ring centred at x −0.0235 while the bullet leaves at 0. *Verify:* `BORE_X` in
`SemiAuto.Geometry`, applied once. The two independent checks that it is right: **after** it the
fore-end's own centre measures x +0.0020 and the sight's glass x −0.0032.

**9. Both hand anchors are bounded as LINES, and the poses were SOLVED onto them.** The right hand on
the stock's pistol grip, the left on the fore-end, each with a point, an axis, a radius and a half
length. The pose `pos` is solved from the target grip point and the rotation
(`pos = P − R·GRIP_STUDS`), not typed by eye. *Verify:* `semiauto.spec`'s two cases compute through
`Mode.handOffsetAt` — the one conversion site the viewmodel draws with — and report **0.0000 off both
axes** at hip, aimed and cycle, against bounds 0.0601 and 0.0768. The same solver reproduces the
lever's shipped pose to 0.0000, which is how the arithmetic was checked against the game's.

**10. It is bought or not carried, and the shop is now full.** `OWNED_ONLY`, `grants.weapon`, 500
coins at `Shop.ORDER[3]`, buckshot free with the gun and the slug still the ladder's first rung.
*Verify:* `semiauto.spec` enters both arms — an unrestricted loadout answers `shotgun, rifle` and an
owner's includes it. `#Shop.ORDER` is now **12, which IS `MAX_ITEMS`**, asserted as such in
`shop.spec` so the next catalogue row is a decision and not a red harness. The catalogue total went
13395, so `Economy.CONFIG.TEST_GRANT.coins` moved 13000 → 13500 — `economy.spec` caught that as a real
consequence, not a stale number.

**Also, one shipped behaviour improved (design D-c).** `Camera.fedShell` reads the live-chamber count,
which was already on the wire, so the gate voice fires **once per shell** instead of once per run —
closing 224a(e) without the protocol change it was queued against. The LEVER's audible behaviour
changes with it (five clicks for five cartridges). `semiauto_client.spec` drives the edge and the two
cases that defeated the earlier round-counting attempts (a re-grant, a magazine change).

---

## What I could NOT verify, and why

* **Three of the four look frames the dispatch asks for, and the live shot over the shop counter.**
  I have **one** first-person frame in the Forest Test (`.screenshots/225-fp-carry.png`) showing the
  gun drawn in the player's hands, and I looked at it: barrel, vent rib, rail, receiver and magazine
  cap all read correctly, in a dusk scene. The aimed / mid-cycle / shell-into-port frames and a real
  shot need the gun **bought**, and `Economy.grant` cannot be reached from a live probe — a probe gets
  a fresh `Economy` whose `enabled` is false, so it answers `shop-closed` whatever the flag says (my
  own note, `studio-mcp-execute-luau-single-line`). Handing the character a fabricated Tool *draws*
  the gun (which is how the carry frame exists) but binds no aim or fire, because it carries no server
  weapon state. **The drawn behaviour those frames would show is measured instead**, on real instances,
  by `semiauto_client.spec` — the numbers are quoted in claims 3, 4 and 5.
* **Karen's eye on any of it.** Nobody here has heard the three voices or felt the recoil, and the
  carry pose is unconfirmed — as the **lever's still is** (task 224 shipped with its carry pose
  unseen). Both guns now sit on the same pose system, so if she rejects the lever's hold, both
  weapons' pose data moves together. Flagged rather than left to surface later.
* **Smoke (rule A) was not run as a clean PASS.** The session above was a deliberately non-standard
  one (an attribute changed, a fabricated Tool). What I can report from it: the whole
  server + client console had **0 "Stack Begin" and 0 error lines**, and all six uploads loaded —
  `[ViewmodelAssets] published 6 of 6 semiauto piece(s)` plus a `[WeaponBoot] semiauto.* loaded` line
  per asset id. The Forest Test's `DHFlag_SHOP` attribute was captured (absent), set, and **restored
  and read back absent**; `DHForestStartRole` and `DHShopTestGrant` were untouched.

## What the design got wrong, and this task corrected

* Design 6.2 calls this "the slowest reload in the game". It is not: the lever's five cartridges
  through a gate cost 2.90 s and these five shells through a bigger port cost 2.60. `semiauto.spec`
  measures both comparisons rather than repeating the claim.
* Design 14 says `Geometry.partCount` is 9. Its own row writes the drawn total as "Handle + 2
  envelopes + 7 pieces + 2 gloves = 12", and 12 − 2 is 10. The function answers 10 and the spec
  asserts it against the pieces actually built, not against either number.

# Task 204 — a slug is not buckshot

Task: 204
Round: 1
Base: f3597f2 (main, the Director's branch point)
Code commit: 50505abac43cbf95991ddac8238793aef634de52

Karen, 2026-10-18 ~14:20, verbatim: *"please diferenciate slug from shells / also we need to change
shooting sound and power to shotgun when slugs and shells is used slugs are harder"*. Her frame of
the chip: `<runs-dir>/karen-2026-10-18/shot-3.png`.

```
[harness] PASS: 33/33 checks @ 50505abac43cbf95991ddac8238793aef634de52 (clean tree) scope=all
```

`test2` is **N/A**: nothing this branch touches is in `TWO_PLAYER_PATHS`, and `agents.py`'s own
answer for this diff is `needs_two_player([...]) == []`. The change is the HUD chip, the camera's
kick and the weapon's voice — weapon / viewmodel / camera / hud paths, which the 2026-10-03
Director decision gives the one-player line.

SMOKE PASS (rule A), Forest Test, 100 s: `gun in hand @15s=1 @100s=1 | stacks=0 errorLines=0 |
waves=10`, player on the ground at 15 s, at the end and after a respawn.

## What changed

Nine files. The LOAD becomes an axis the shot path reads, in three places that already existed —
the chip's glyph, the shot's voice and the kick's amplitude — and in no new system.

* `src/shared/Viewmodel/poses.json` — `weapons.shotgun.fire.loads`, three multipliers per load.
* `src/shared/Viewmodel/init.luau` — `Viewmodel.loadFor` (the one reader), `NEUTRAL_LOAD`,
  `LOAD_SCALES`, and the optional block's validation.
* `src/client/Camera/Poses.luau` — `Poses.forLoad`, the six recoil amplitudes scaled.
* `src/client/Camera/init.luau` — `Camera.kick(ammo)`.
* `src/client/Weapon/Sound.luau` — `Sound.shot(config, row, ammo)`, and `Sound.lastShot()`.
* `src/client/CameraBoot.client.luau` — hands both owners `shot.ammo`.
* `src/shared/Weapons/init.luau` — `AMMO_GLYPH` on the shotgun's row.
* `src/client/Hud/Style.luau` — the `slug` and `buck` glyphs, and `Style.SHELL`.
* `src/client/Hud/init.luau` — the shell in the chip, `Hud.AMMO_ACCENT`, `ammoChipFor().glyph`.

## Claims

**1. The defect was reproduced on Karen's own path first (rule H), before a line was changed.**
A one-player DEV Play, the chip at the bottom right, the real HUD, eye height:
`.screenshots/204-before-slug-desktop-crop.png` and `204-before-buck-desktop-crop.png` are the same
picture with one word swapped — two pips, the same colours, the same shape.
*Verify:* look at the two crops (and the full frames beside them). Compare with Karen's
`shot-3.png`.

**2. The same shot, before, measured through the game's own request path.** With each load actually
chambered, `FireRequest:FireServer` fired and the REAL camera and the REAL `Sound` were read:

```
BEFORE  Buck: peakCamPitchDeg=+1.941  volume=0.950  speed=1.000
BEFORE  Slug: peakCamPitchDeg=+2.040  volume=0.950  speed=1.000     (run 1: 2.015 / 1.999)
```

*Verify:* `<runs-dir>/t204-before-fire.txt` and the probe that produced it,
`<runs-dir>/t204-fire.luau` — it selects the ammo, reloads so the CHAMBER holds it, samples
`workspace.CurrentCamera`'s own pitch per frame and records the `Sound` the client's owner created.
Nothing in it reads a config.

**3. The chip now reads as two things at a glance, in §3.10's glyph language.**
`.screenshots/204-after-slug-desktop-crop.png`: a GREEN hull with ONE SOLID PALE NOSE, brass rim,
and `SLUG` in the hull's green. `204-after-buck-desktop-crop.png`: a RED hull with a 2x2 CLUSTER OF
FOUR PELLETS, brass rim, and `BUCK` in the hull's red. Same session, same camera, same eye height,
same crop box as the before pair.
*Verify:* the four crops side by side. `Style.glyph`'s `slug` / `buck` arms in
`src/client/Hud/Style.luau`.

**4. Both steps are one implementation, and both were rendered.** §3.10's rule is that every number
is a fraction of one `px`, so the phone shell is the desktop shell at 14.
`.screenshots/204-after-glyphs-both-steps-crop.png` is both shells at BOTH steps, built by
`Style.glyph` in the live client's own `PlayerGui` (magnified 4x so the shape is legible).
*Verify:* that frame, plus the `hud_style.spec` case that builds one of each at 16 and 14 and
asserts the box and the hull shrink together. **Named limit:** the full phone CHIP was not
photographed at a 400-px viewport — `Style.viewportX()` is the one reader of the width and the chip
is built once at boot, so a running 969-px client cannot be made to re-lay it. TASKS.md 204a(e).

**5. The glyph is the WEAPON'S, not the wire word's.** The wire says `Slug` for both guns (because
`Boar.Wound.damageFor` branches on that string), so the mapping is `row.AMMO_GLYPH`, beside
`AMMO_LABEL` and for the same reason. The rifle's row carries none and its chip is unchanged.
*Verify:* `Hud.ammoChipFor` in `src/client/Hud/init.luau`; `Weapons.ROWS.shotgun.AMMO_GLYPH`; the
`hud_style.spec` case "names a different shell for each load, and none for a gun that has one",
which asserts `glyph == nil` for a rifle state.

**6. Both shells are built once and at most one is shown.** The discipline the start card's row
glyphs and the chamber pips already use — a chip that destroyed and rebuilt a Frame on every X press
would flicker, and `Hud.renderCorner` runs once a frame. `LayoutOrder = 0`, so the shell reads
before the chambers.
*Verify:* the `hud_style.spec` case "builds both shells into the chip as Frames, and shows at most
one" (it also asserts the slug has a `Nose` and the buck has four `Pellet*` and no `Nose`).

**7. A slug is louder and deeper, out of the SAME sample — nothing was uploaded.**
`fire.loads.Slug` is `volumeScale 1.25`, `pitchScale 0.82`; buckshot is 1 and 1. Lowering
`PlaybackSpeed` drops the whole spectrum AND lengthens the report (the shotgun's voice has no
`cut`).
*Verify:* measured through the request path, twice —

```
AFTER   Buck: volume=0.950  speed=1.000   (unchanged from the before)
AFTER   Slug: volume=1.188  speed=0.820
```

`<runs-dir>/t204-after-fire.txt`; the id is `rbxassetid://99008924129683` in both. And the harness's
own note: `task204 voice: buck volume=0.950 pitch=1.000 | slug volume=1.188 pitch=0.820`.
**No low-frequency layer was added** and the dispatch's condition is why: it allows one *"if the
game already has a suitable sound"*, and the only other voices in the repo are Studio's `switch`,
`switch3` and `clickfast` wavs — mechanism clicks, not a boom. A real slug recording would be an
upload and needs Karen's OK (TASKS.md 204a(d)).

**8. A slug kicks harder, measured on the real camera.** `recoilScale 1.45` multiplies the three
amplitudes and their three ceilings, so a doublet of slugs is worse than a doublet of buckshot —
which is the point.

```
AFTER   Buck: peakCamPitchDeg=+1.924   (before: +1.941)
AFTER   Slug: peakCamPitchDeg=+2.824   (before: +2.040)   — run 2: +1.886 / +2.848
```

*Verify:* `<runs-dir>/t204-after-fire.txt`, the same probe as claim 2. The harness's notes agree
from the other side: `task204 kick (live config): camPitch buck=2.100 slug=3.045 deg, gunPitch
buck=8.00 slug=11.60 deg`, and `one shot, pure: camPitch buck=2.100 slug=3.045`. The settle is
`+0.0000` in every trace — the bead still comes back to exactly the aim point.

**9. BUCKSHOT IS BIT-FOR-BIT THE GUN KAREN ACCEPTED, and the spring's shape is untouched.**
`Poses.forLoad(config, "Buck")` returns `config` ITSELF — the same frozen table — because its scale
is 1, as does a caller that passes no load at all. `frequencyHz`, `dampingRatio`, `REST_EPSILON` and
`MAX_SUBSTEP_SECONDS` are never scaled, so `camera_mode.spec`'s settle at 240, 60 and 20 fps is the
same assertion about the same spring.
*Verify:* `viewmodel_poses.spec`'s "scales the six recoil amplitudes for the load and nothing else
about the spring" (it asserts identity, not equality) and "answers NEUTRAL for a weapon, an ammo or
a row it does not know". The before/after Buck traces above are the live half of the same claim.

**10. One reader, one table per load, and a half-written row is refused.** `Viewmodel.loadFor` is
the only answer to "what does this load do to the shot" — the camera and the sound both call it, so
they cannot disagree. The block is OPTIONAL (the rifle has none); present, `Viewmodel.validate`
requires three positive numbers per load, so a bad file fails the harness and therefore the merge
gate.
*Verify:* `viewmodel_poses.spec`'s "refuses a loads block that is not three positive numbers per
load", and `Viewmodel.loadFor`'s guard returning `NEUTRAL_LOAD` for a row missing a scale.

## What I could not verify, and what I got wrong

* **The full phone CHIP was not photographed** (claim 4). Only the glyphs at the phone step were,
  plus the spec's arithmetic. TASKS.md 204a(e).
* **Nobody has HEARD it.** I cannot play audio. That a slug at `PlaybackSpeed 0.820` and
  `Volume 1.188` actually sounds heavier than buckshot is Karen's call, and the numbers are one
  `tools/pose.py set` away without a round (TASKS.md 204a(b)).
* **How much harder is a first pick.** 1.45 / 1.25 / 0.82 are not derived from anything; real free
  recoil puts a 1 oz slug roughly 10–25 % over 00 buck, and that is invisible on screen, so these
  are chosen to READ. They are content-lane data.
* **My first live spec broke the run.** It fired two real shots through `FireRequest` inside
  `weapon_client.spec`; its own shots came back refused and the gun it reloaded broke
  `zz_tie_to_a_tree`, three cases (`[harness] FAIL: 29/33 @ f1119fd`). The end-to-end measurement
  moved out of band (claims 2, 7, 8) and the spec now drives the owners instead (`dc53f03`).
* **The design docs do not know about the load.** `docs/design/shotgun.md` 3.4 and
  `docs/design/camera.md` still describe one chip and one kick per weapon. The Builder may not write
  `docs/design/` — TASKS.md 204a(a).
* **The ballistics were NOT changed, because they are already different** (tasks 183/185): slug 1
  projectile / 330 studs / 1752 studs/s / 0.16 deg; buck 9 pellets / 100 studs / 1442 studs/s /
  1.6 deg. The dispatch asked for a change only if they were equal today.
* **No research note.** No new system and no invention: §3.10's glyph language, the pose-data
  content lane and the critically-damped recoil spring are all this repo's own adopted patterns, and
  the change is an axis on each.

# Task 120: animal bugs first

Task: 120
Round: 2
Base: 25e84c031b4dd1c1e4a3967ce51fba51eaf92ebe
Code commit: 576f94f950583baad83cddabe3865cf03bf1df45

[harness2] PASS: 35/35 checks @ 576f94f950583baad83cddabe3865cf03bf1df45 (clean tree)
[harness] PASS: 33/33 checks @ 576f94f950583baad83cddabe3865cf03bf1df45 (clean tree) scope=all

Both run by the Director at the branch head. `match_live.spec` is in `TWO_PLAYER_PATHS`, so this
round needed its own two-player line; `576f94f` is the paperwork commit after `44a7c5e`, which is
the last commit that changed `src/`, `tests/` or `tools/`.

## Claims

1. **The shot cub was the DRAWING, not the carcass.** It was drawn 1.01 studs under the floor on an
   animal 1.44 studs tall while the box stayed anchored with `Carcass = true`. Every kind plays the
   male's clips, a KeyframeSequence's bone translations are absolute studs, and the fall is built of
   child-bone translations -- so a rig baked smaller is driven too far down (the root bone never
   moves, measured). Fixed in one write at death: `Body.collapse` -> `Body.liftDrawn`, a weld offset
   that touches nothing a shot reads, and only where there is a death clip to fall with
   (`Body.hasClip`, so the no-id world task 116 supports is not left with a floating carcass).
   Verify: `Boar.CONFIG.KINDS`' `deathLiftStuds`; `boar_kinds.spec` "carries the studs each kind's
   carcass has to be given back" (male +0.002, sow -0.205, cub -1.009, measured at the frozen death
   frame; `(1 - scale)` shown not to predict the sow's; 0 with `KINDS` off); `boar_model.spec` "a
   cub's carcass is given back what the male's death clip takes off it" and "lifts NOTHING when
   there is no death clip to fall with".
2. **A kill carries which animal died**: `Wound.killRecord` takes a trailing `kind`, and `Downed`
   and `Despawned` both carry it -- where a later cub penalty reads it. No penalty built.
3. **Both impact cues are OFF, by data** (Karen: "I think we can remove hit sound for now"):
   `enabled = false` on `HIT`, `FALL` and `LAST_BREATH` is the only line `playOneShot` reads, and
   every row keeps its id, volume and filter. Verify: `boar_shot.spec` "has both impact cues OFF, by
   data and not by deletion", "a REAL shot plays the CRY and NOT the bullet hit", and "is still one
   play after a rump wound finishes the animal later".
4. **A death is one short squeal**: the squeal samples, cut at 0.6 s with a 0.15 s fade
   (`Body.stepCuts`/`Body.cutVolume`), nothing after it. Verify: "makes a death ONE SHORT squeal
   rather than a scream" and the live "a dead boar has no footsteps and ONE SHORT squeal".
5. **A voice per kind**: male 0.80, sow 1.00, cub 1.40 as the pitch centre of the three cues that
   come out of the animal (cry, death, grunts), the male keeping the one rough scream in the
   verified set; hooves, breath and the sniff untouched. No new asset ids. Verify: "gives each kind
   a voice of its own".
6. **A herd is not six animals**: one grunt per sounder per 2.5 s, two squeals world-wide at once
   (skipped, never queued), one set of hooves per sounder (the pure `Boar.isStepEmitter`), voices
   fading to 0.75 beyond 90 studs. Verify: "rations a CALM sounder's grunts" -- a six-boar sounder
   with no threat over 20 s, **1 grunt at the 2.5 s gap against 19 with the gap at zero** -- "lets
   two squeals be heard and SKIPS the third" (three animals shot in one instant: 2 heard, 1
   skipped), and "plays ONE set of hooves for a whole sounder, whoever is running".
7. **A waiting hunter hears the approach** (Karen: "when its verry fal I cant hear them"). The
   roll-off is `InverseTapered`, so the level goes as `NEAR_STUDS / distance` and `audibleStuds` is a
   hard cut: a running sounder at 100 studs arrived at 0.084 of full scale and was silent past 90.
   Now `NEAR_STUDS` 12 -> 24 and, as volume/reach: run 0.70/90 -> 0.85/130 (0.204 at 100 studs),
   trot 0.50/70 -> 0.65/110, walk 0.35/45 -> 0.45/80, grunts 0.45/70 -> 0.50/85, running breath
   0.50/60 -> 0.55/95. The far-voice fade was moved out of the way (90 studs, floor 0.75) and never
   touched the footstep loops. A loop something else stopped now comes back on the next step, so the
   pre-roll can no longer silence the one animal a sounder's hooves depend on. Verify: "lets a
   waiting hunter HEAR the approach long before he sees it" and "brings a footstep loop back when
   something else has stopped it".
8. **What a person is, to a boar**: `match_live.spec` "tells the boar what KIND each person is"
   gives its fake players real Characters -- a `Shooters` row is tagged `"shooter"`, a `Drivers` row
   `"driver"`, a spectator and a bodiless player are not stimuli at all -- and the quick test's
   phantom is found in the published list as a driver with a non-numeric id at
   `Match.quickTestPhantom`'s own position, or asserted absent when it is not pushing. Also:
   `camera_client.spec`'s "the shot's kick" waits for `Camera.Mode.recoiling` to go false before
   asserting the rest state is exactly zero, which is the flake fixed at its cause.
9. **The screenshots** (rule 5), all taken on this code commit in one live session:
   - `.screenshots/120r2-dead-cub.png` -- a shot cub on its left flank ON the surface 12 s after the
     kill: striped juvenile coat, pale legs out to the side, snout flat on the ground, its own
     shadow under it, the stand's post behind. Nothing is under the floor.
   - `.screenshots/120r2-dead-sow.png` -- the sow in the foreground, dark grey-brown, on her left
     flank, all four legs out, tusks against the ground; the dead cub small in the distance behind
     her. Both are on the surface.
   - `.screenshots/120r2-cub-fall-0.png` and `-1.png` -- the kill at 18 studs, hit marker on screen,
     kill feed "BOAR chest". By the first frame a capture can reach (~0.2-0.3 s after `Carcass`
     flips) the cub is ALREADY on its side on the ground, and 0.35 s later it is still there. The
     "a cub starts its fall a body-height high" worry does not show: the lowest bone measured
     -0.000, +0.058 and +0.007 studs against the ground at those three instants.

## Could not verify

- **NOBODY HAS HEARD ANY OF IT.** Nothing in this toolchain can hear a sample, and Karen skipped the
  listen ("skip me for testing", 2026-10-04), so every sound claim -- the cues off, the short squeal,
  the voices, the caps, the distances -- is a dial or an instance property and not a judgement that
  it SOUNDS right.
- `Boar.heardAt` is a MODEL, not a measurement: nothing here can read back the level a client
  renders, and Roblox does not publish the exact InverseTapered blend. It has the two properties the
  numbers were chosen on -- the plateau sets the far tail, the max is a hard cut -- and the teeth in
  that case are the `audibleStuds`/`volume` data beside it.
- The one-emitter cap's live half is a regression guard, not an A/B: measured, a sounder's followers
  hold their slot, so only the leader's setpoint reaches `STEPS.MIN_SPEED` even with all six in
  FLEE. The A/B is the pure `Boar.isStepEmitter`.
- I re-read every case this task added, asking "would it pass with the code it tests deleted?".
  Eight are mutation-checked by hand (the `enabled` gate, the cut, the squeal cap, the grunt cap, the
  kind ternary, the death-clip gate, the loop re-play, the death lift); the rest fail on reverted
  data.
- Two flakes seen today and queued in `TASKS.md` under 120, each green on a re-run with identical
  code: `weapon_client.spec`'s reserve check (Slug 23 against a baseline of 25) and
  `zz_drive_boundary.spec`'s "a client never reported".

# Task 119 — the sow and the cub, and the head zone on the real snout

Task: 119
Round: 2
Base: f21260b0f8540a801882b97444248162955bb855
Code commit: 51fa8b5a9243669884c59f3595bc102061aebd1a

The base is the head of `task-118-boar-behaviour`, the branch this PR targets: 119 is stacked on 118.

```
[harness] PASS: 33/33 checks @ 51fa8b5a9243669884c59f3595bc102061aebd1a (clean tree) scope=all
```
`[harness2]`: **N/A.** Nothing in this task touches `src/server/Match/`, `src/server/MatchBoot...`,
`src/client/Match/`, `src/shared/Drive/` or their specs; the branch's own diff against its base is
`src/server/Boar/`, `src/server/BoarAssetsBoot...`, `src/serverstorage/Assets/`, three specs and the
harness's scope table. (118's own Match change is below the base and was gated at `f21260b`.)
CI is red for ONE reason that is **task 117's and must not be fixed here**: `tools/boar_prep.py`'s
selftest still says "ten clips" with sixteen in the tuple.

## What changed in round 2

**Both blocking findings are right.**

**1. `clipScale` was clamped away.** The ceiling it was clamped against was derived for the male
alone, so a cub asking 4.02 at `TROT_SPEED` and 5.05 at `SPRINT_SPEED` got 2.8 and its feet carried
12.5 and 21.1 studs/s against a body doing 18 and 38. *Fixed with one pure function,*
`Body.gaitBands(clipScale, config)`: the gait EDGES and the CEILING are the male's numbers expressed
in this animal's stride — the ceiling because its own derivation is "above everything the game can
ask for" (2.8 / 0.4372 = 6.40), the edges because a piglet is running where its mother trots, so a
cub now plays `run` at the sounder's 18 studs/s instead of trotting at a 4× blur. **The FLOOR does
not scale**: `MIN_RATE` says a clip may not be played as slow motion, which is a fact about the clip
— scaling it clamped a cub at the BOTTOM of its own trot band, where every animal asks 0.501.
Measured, by trying it.

**2. The snout case could not fail.** Both probes came from the front and `zoneAt` answers with the
first box along the axis, so the old floating box satisfied them. Added the probe only the new
geometry can satisfy — straight down onto the snout's own z, where the pre-task head top was +1.1,
under the trunk and under the old chest — and an assertion that the head's front face stands exactly
one `PROTRUSION` proud of the trunk's rather than 1.15 studs. The comment no longer claims what the
old probes could not show.

**Mutation-checked, both.** The male's ceiling for every kind → `boar_kinds.spec`'s sweep fails; the
pre-119 head and chest rows → both new zone probes fail with `chest`.

**Notes fixed here** (the rest is queued as **119a**): the `Random` stream is untouched with the flag
off again (the kind rolls are gated like the formation draw); `_askedModelAt` is per kind, so the
sow's coat no longer waits a second behind the male's; `kindRow`'s fallback carries a `name`; the
unread `protrusion` is gone and that case asserts the one thing that can fail; `Flags`' and
`GAME_DESIGN`'s "the physics box is byte-identical in both flag states" is corrected — it is not,
since this task, and both now say so; the bone count is **40** `Bone` instances, counted off all
three loaded templates; and the live spec pins the spawn height a cub depends on.

## Claims

1. **Two animals prepped and uploaded, one run each.** `tools/boar_prep.py` with nothing changed but
   `--animal` and `--length-studs`; female `73776255349661` (13,644 tris, 4.675 studs), cub
   `78344628955312` (12,234 tris, 2.475 studs), both Approved, both recorded in `assets/uploads.json`
   with Karen's 2026-10-03 OK verbatim. *Verify:* the two rows in `src/serverstorage/Assets/init.luau`
   — their `sizeStuds` are the LOADER'S OWN measurements, printed by `BoarAssetsBoot` off the live
   assets (female 1.2019/2.6473/4.6750, cub 0.6177/1.4389/2.4749).
2. **A sounder is a sow with young; a lone animal is a male; every box scales with the animal.**
   *Verify:* `boar_kinds.spec` (five cases: the lengths, every zone at 0.45, the protrusion still
   proud at every size, the makeup by roll, and "with the FLAG off, every animal is the male-sized
   box this game has always spawned"); `boar_behaviour_live.spec`, "spawns a sow and cubs, each on its
   own box, and every one of them lives" — four real bodies, the sow first, a cub's `ZoneChest` at
   0.45 of the male's, all four alive 1.5 s later.
3. **The male's published clip ids play on all three, measured, so nothing was republished — and a
   cub's legs now match its ground speed at every speed it travels at.** Live: every hoof lands at
   **0.86** (sow) and **0.41–0.43** (cub) of the male's height, no stretching. Each animal's own
   ground speed is **0.8553** and **0.4372** of the male's, identically on all four locomotion clips.
   *Verify:* `boar_kinds.spec`, "never clamps a cub at any speed a cub actually travels at" — all
   three animals swept from the rooting 1.901 studs/s to `SPRINT_SPEED`, every ask strictly inside
   its own rails; the tightest over the whole sweep is the MALE's trot at 27.2 studs/s, 0.15 under
   his ceiling.
4. **A shot at the drawn snout is a head shot.** The head box hung 1.15 studs in FRONT of the snout
   (grey-box geometry); it is now the skull, sited off the rig's own bones measured in a Play session,
   and the chest moved back one stud onto the shoulder because the head cannot sit where it belongs
   while another zone part is there. *Verify:* `boar_zones.spec`, "is a HEAD shot at the drawn snout"
   — a real ray at the `nose` bone's own measured point — plus the moved front/above/flank cases.
   The flank limit is asserted too, as `body`, rather than left unsaid.
5. **Every cub the drive released used to vanish inside a second, and that is fixed.** A boar is
   spawned at `field.groundY`; the map's real surface is ~2 studs above it (measured: a released sow
   settles with her box bottom there), so every boar spawns embedded — a male's 3-stud box has its
   top above the surface and is pushed out, a cub's 1.35-stud box is entirely below it and is
   ejected. Every kind is now dropped from the MALE's height, so the flag-OFF world spawns exactly
   where it always did. *Verify:* `Runtime:spawn`'s comment carries the measurement; confirmed live —
   a sow, a male and a cub running together (`119-file.png`).

## Screenshots (rule 5), flag-ON Play session, 2026-10-04, `.screenshots/` (git-ignored)

- `119-file.png` — a striped tan cub nearest the camera, the dark sow behind it and the bigger male
  behind her, strung out one behind the other across open ground.
- `119-size.png` — the male facing the camera at ~20 studs with the cub beside him: about half his
  length and a third of his height, tan and striped against his black.
- `119-headshot.png` — the hit marker drawn on the boar's snout and the readout bottom-left:
  **"Alhamdulilah824 BOAR head"**. Before this task that same shot was charged `body`.

Round 2 adds two, for the drawn half of finding 1:

- `119-running.png` — the sow and the male at a full gallop, both measured at 38.0 studs/s,
  mid-stride with the legs gathered and extended rather than stiff.
- `119-running-cub.png` — a cub at 38.0 studs/s, side on and large in frame, in the same gallop pose.
  **A still cannot show cadence**: what the still shows is the gait and the posture, and the cadence
  is the spec's sweep above.

## What I could not verify

- **Nobody has judged the feel**: 0.85 and 0.45, the sow-and-young makeup and the 1-in-4 young male
  are all Karen's dials, and nobody has seen a drive of them.
- **The cub's own clips are never played** — all three animals play the male's ids. The package ships
  a cub set; whether the cub's own gait reads better is unasked and unmeasured. Queued as 119a.
- **Nobody has watched a cub for long enough to judge the new cadence.** At 38 studs/s an animal
  crosses the frame in under a second, so the two round-2 frames are single strides; the claim that
  it does not skate rests on the swept arithmetic, not on the eye.
- **The flank head shot is `body`** and always was: the drawn head is 1.1 studs wide inside a 2.0-wide
  trunk. Front and above are `head`. The only fix is a narrower trunk at the front.
- **The moved CHEST is a gameplay change nobody asked for.** It was on the drawn animal's neck; it is
  now on the shoulder. The damage numbers are untouched, but where the vital zone IS has moved by one
  stud and the Director can reverse it.

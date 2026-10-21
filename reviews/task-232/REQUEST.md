# Task 232 -- the red deer MOVES: the eleven published clips, wired and measured

Task: 232
Round: 1
Base: `801065b0` (`main`)
Code commit: `bf13e32aa11d4fbf0cfba9993b0a63a42dc90306`

```
[harness] PASS: 33/33 checks @ bf13e32aa11d4fbf0cfba9993b0a63a42dc90306 (clean tree) scope=all
```

`test2` is **N/A**: nothing in `TWO_PLAYER_PATHS`. The four code files are
`src/serverstorage/Assets/init.luau`, `src/server/Boar/init.luau`,
`src/server/BoarAssetsBoot.server.luau` and `tests/server/deer.spec.luau` -- the boar/deer lane,
which the Director's 2026-10-03 decision puts on the one-player gate.

## What changed

Task 223 shipped the stag, the hind and the calf with **no animation ids**, which was the honest,
tested state the boar was in between tasks 115 and 116: `Assets.byKey` answered nil, `Body.hasClip`
was false, and the animal stood and slid. The Director published all eleven clips in DEV's Animation
Editor on 2026-10-21. This task writes them into the manifest, measures the three numbers the clips
made knowable, and fixes one enumeration that had been counting a single species.

**Almost nothing had to be joined up**: `DEER_CLIP_KEYS`, `CLIPS_BY_SPECIES`, the species-first
`animationIdFor` and the deer's own `ANIMATION_IDS` table were all built in task 223. The diff is
eleven data rows, three measured numbers, one `looped` value, and one loop that was walking the
wrong table.

## Claims

**1. The eleven rows exist, under their own scope, and every id was read back off Roblox before it
was written down.** `Assets.ROWS` gains eleven `kind = "animation"` rows keyed by the eleven
`Assets.KEYS.deer*` names, `scope = "deer-animation"`, geometry fields `NO_GEOMETRY`/`NO_FIDELITY`,
`fileName`/`sourceSha256` from the stag's own prep export. *Verify:* read the block headed *"the red
deer's eleven clips (task 232, published 2026-10-21)"* in `src/serverstorage/Assets/init.luau`;
`deer.spec`'s *"has a published animation row for every one of the deer's eleven clips"* fails,
naming the clip, if any one is missing -- and the same case fails if a deer row ever carries the
boar's `modelId`.

**2. `clipSeconds` is the published asset's own last-keyframe `Time`, and it agrees with the number
the deer already played by.** Measured in Edit on 2026-10-21 with
`AnimationClipProvider:GetAnimationClipAsync` over all eleven ids: 4.166667 / 1.000000 / 0.666667 /
0.583333 / 0.666667 / 0.666667 / 1.166667 / 1.166667 / 0.833333 / 0.833333 / 4.166667. Every one
agrees with `DEER_CLIPS` to the last decimal the config states. *Verify:* `deer.spec`'s *"agrees
with the manifest about how long each deer clip is"* (half a frame at 24 fps, the boar's own
tolerance) and its `TestKit.note`, which printed the worst drift in the gate run.

**3. The published `Loop` flag is the boar's case INVERTED, and this is why `Body`'s property write
exists.** Read back off the assets: only `Walk_F_IP` carries `Loop = true`; the other ten read
`Loop = false`, where the boar's ten were all `true`. So on this rig the hazard runs the other way
-- an un-looped walk plays once and freezes a walking deer mid-stride. Nothing reads the row's flag;
`Boar.Body` writes `AnimationTrack.Looped` from `MODEL.CLIPS` immediately before every `Play`.
*Verify:* each row's `notes` records what its asset says; `deer.spec`'s *"loops the deer's gaits and
plays its deaths and flinches ONCE"* names both arms on both sides, so a clip moving between them
fails. Measured live: every deer track observed in a real drive reported `looped=true`.

**4. `deathLiftStuds` is MEASURED per kind, in a Play session, at the frame the game freezes the
death at.** `AnimationTrack.Length` is 0 in Edit, so this can only be read in Play. On the real
published `Death_L` (90698126097935) and `Death_R` (137231010993280), held at
`length - HOLD_EPSILON` exactly as `Body.stepVisual` holds them, reading every `Bone.WorldPosition`
in the mesh's object space against `-meshSize.Y / 2` -- the plane `Body.visualOffset` puts on the
trunk's bottom:

| | at rest | Death_L | Death_R | lowest bone when dead |
|---|---|---|---|---|
| stag | -0.0110 | -0.0110 | -0.0110 | `root_bone` |
| hind | -0.0029 | -0.1847 | -0.1847 | `hoof_b.L` / `hoof_b.R` |
| calf | -0.0038 | -1.3246 | -1.3247 | `hoof_b.L` / `hoof_b.R` |

Shipped: **stag 0.011, hind 0.185, calf 1.325**. The two death clips agree to 0.0001 studs on every
kind, which is what makes one number per kind honest rather than a side-dependent pair. **The stag's
0.011 is the RIG, not the fall** -- `root_bone` sits 0.011 under the plane in the rest pose too and
never moves, so the death clip costs a stag 0.0000; the number is kept because the field's rule is
"write what was measured", and 3 mm on a 7-stud animal is below anything a player can see. *Verify:*
the table and its derivation are in `Boar.CONFIG.KINDS`; `deer.spec`'s *"carries a MEASURED death
lift for each of the three deer kinds"* reads each through `Boar.kindGeometry` -- the seam the live
carcass reads -- one branch per kind, plus the flag-OFF arm at 0.

**5. And it was LOOKED AT (rule E), not only counted.** All three staged dead on flat DEV ground
with these lifts applied, photographed from a standing player's eye height:
`.screenshots/232-three-lift.png` (all three lying on the grass) and `232-calf-lift.png` (the calf
close up, the extreme case). With the lifts the lowest bone of each sits within **0.0004 studs** of
the ground. `.screenshots/232-dead-nolift.png` is the same staging with no lift.

**6. THE DEFECT WAS REPRODUCED ON THE REAL PATH FIRST (rule H).** DEV, `BOAR_MODEL` + `QUICK_TEST` +
`BOAR_BEHAVIOUR` on: the first release drew a hind and a calf -- real meshes, real Animators -- with
`tracks=[]`, and over a 10 s sample the calf reached **18.20 studs/s with ZERO animation tracks
playing**. In the same server, at the same instant, the boars were playing `digWalk`, `grazeLoop`,
`smell` and `turnRight`. Before-frame `.screenshots/232-BEFORE-bindpose.png`: stag, hind and calf
standing at eye height with their legs locked in the bind pose.

**7. AFTER, on the real path: deer in a real drive play their clips, at the rate their OWN stride
asks for.** Same world, after the change -- a live hind and calf over 85 s:

```
calf/idle      len=4.167 looped=true  rate 1.000..1.000  body 0.00..4.00
calf/smell     len=4.167 looped=true  rate 1.000..1.000  body 0.00..2.92
calf/turnLeft  len=0.667 looped=true    calf/turnRight len=0.667 looped=true
calf/walk      len=1.000 looped=true  rate 0.400..1.422  body 0.00..4.00
hind/idle      len=4.167 looped=true  rate 1.000..1.000  body 0.00..4.00
hind/walk      len=1.000 looped=true  rate 0.400..1.064  body 0.00..4.00
hind/trot      len=0.667 looped=true  rate 1.600..1.624  body 17.85..18.13
```

**That is the feet-not-sliding arithmetic, per kind, measured live.** The calf's walk rate
**1.422** is `4 / (4.178 x 0.6735)`; the hind's **1.064** is `4 / (4.178 x 0.9)`; her trot **1.624**
is `18 / (12.312 x 0.9)`. Each animal is rated by its own `clipScale` and not by the stag's -- the
recurring defect class the Learning Agent's L-024 names. A later sample caught the calf trotting at
**2.169** against `18 / (12.312 x 0.6735) = 2.171`.

**8. The clips play on all three rigs and the legs move.** Measured on the real templates with the
real ids, sweeping 25 samples across each clip and reading `hoof_f.L` in the mesh's own frame
(`driven-hunt-runs/232-gait.luau`): the stag's walk gives a 2.546-stud hoof stride with a 0.397-stud
lift, his trot 2.520 / 0.783, his run 3.297 / 1.726, his turn 0.597 / 0.375 -- and the hind and the
calf scale with them. Every rate the game asks for sits inside that kind's own rails (stag run
2.217 against a 2.80 ceiling, hind 2.464 against 3.11, calf 3.292 against 4.16), which is the sweep
`Boar.CONFIG.KINDS`' own comment predicted. Frame: `.screenshots/232-AFTER-walk.png`, all three
mid-walk at eye height, against the locked-leg before-frame.

**9. ONE REAL BUG FOUND AND FIXED: `BoarAssetsBoot` was counting one species.** Task 223 made the
two *assert* loops above it per-species and left the *count* loop walking `Boar.CONFIG.MODEL.CLIPS`
and `CLIP_KEYS` alone -- so for two tasks it printed *"all 19 boar clips have an animation asset
id"* on a server where every deer clip was missing, which is exactly the silent 0 that block exists
to prevent, and the same hand-written enumeration this file paid for three times in task 219. It
walks `CLIPS_BY_SPECIES` now, and the manifest-vs-config length warning is per species too.
*Verify:* the live DEV server now prints both lines:

```
[BoarAssetsBoot] all 19 boar clips have an animation asset id.
[BoarAssetsBoot] all 11 reddeer clips have an animation asset id.
```

The second line **did not exist before this change**, in any form.

**10. The deer's `smell` loops where the boar's does not, deliberately, and the boar is untouched.**
The Director's dispatch asked for `looped = true` on `smell`; the boar's row is `false` and its
reason is written on `ALERT_CLIP`. Both are kept, because the case that separates them is the CALM
activity, which runs `smell` for `minSeconds = maxSeconds = 4.167` -- the clip's own length to the
last decimal. A frame of jitter past the end stops a one-shot track, and a stopped track drops the
animal into its BIND POSE in front of whoever is watching. Looping cannot do that, and for an ALERT
(`ALERT_SECONDS` 2.5) the two values are indistinguishable. The boar's row is left as task 117
shipped it -- that is an animal Karen has already accepted -- and the same change there is queued as
232a(a), not taken. *Verify:* the paragraph above `DEER_CLIPS`; `deer.spec` asserts both species'
values in one case, so neither can drift alone; `boar_calm.spec`'s existing assertion on the boar's
`false` still passes.

## What I could not verify

- **A deer dying in a live drive.** Not observed, and not for want of trying: a kill has to come
  from the live server, and a synthetic `FireRequest:FireServer` from a client probe killed
  **nothing** -- not a deer and not a boar, run as a control through the identical path at 7.6
  studs. That is task 224's wall again (*"the gun was armed from an MCP-side module instance, so the
  LIVE server holds no state for it"*). What stands instead: the death pose measured on the real
  rigs with the real ids at the exact frame `stepVisual` freezes, both clips, all three kinds, with
  three eye-height frames looked at (claims 4 and 5); `deer.spec` asserting the three numbers at
  `Boar.kindGeometry`, the seam the live carcass reads; and `boar_model.spec`'s existing live case,
  which proves the lift MECHANISM on a real runtime -- the weld cycle, straight up in the trunk's
  frame, box untouched -- in kind-agnostic code this task did not touch.
- **A deer running or turning in a live drive.** The live samples caught idle, walk, trot, both
  turns and smell. `run` needs a sprint, which needs a shot, which is the same wall. Measured on the
  real rig instead (claim 8).
- **A live frame of a deer inside a drive.** Three attempts; the animals cross hundreds of studs
  between the probe that places the player and the capture that follows it, and the deer draw is
  `CHANCE_PER_RELEASE = 0.2`, so the drive I could follow had none. The eye-height frames are of the
  real rigs playing the real clips (claim 8) and of the real death pose (claim 5).
- **No research note.** No new system: `docs/design/red-deer.md` section 7.5 already specifies this
  work, including the measurement method, and this follows it exactly.
- **Karen has not seen any of it.**

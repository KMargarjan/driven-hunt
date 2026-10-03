# Task 115 -- the wild boar arrives: a bought, rigged, animated animal, behind `BOAR_MODEL`

Task: 115
Round: 1
Base: `main` (`82a3f36`)
Code commit: 74fe65b9a54cf6c8cb9e4330320700137489f815

```
[harness] PASS: 33/33 checks @ 74fe65b9a54cf6c8cb9e4330320700137489f815 (clean tree) scope=all
```

**ONE LINE IS THE WHOLE GATE for this change** -- no `[harness2]`. `needs_two_player` over
`git diff --name-only origin/main...HEAD` returns **`[]`**: not one of the 19 changed files is in
`TWO_PLAYER_PATHS`. It is boar, assets, flags and tools; no `src/server/Match/`, no `MatchBoot`, no
`src/client/Match/`, no `src/shared/Drive/`, no `tests/client/Role.luau`, none of the match / tie /
outfit specs. `test --scope auto` resolves to `all` anyway, so the full `test` the merge gate wants
is the same run.

## What changed

Karen bought RedDeer's "Boar Family" on Fab and said *"we start with one bord and when this works we
do with rest"*, then *"1. go 2. upload"*. The male boar is now welded to the physics box that already
exists, as a **visual passenger**, and the clip it plays is a pure function of what the animal is
doing. The flag is **born OFF**, so `main` is unchanged until the Director flips it.

She has played it three times and accepted it: *"walking, running is good / colour is good"*, then
*"now looks good"* after the carcass and the head shake were fixed, then **"looks good now"** after
the carcass was anchored (`PLAYTEST.md`, three rows).

## Claims

1. **With the flag OFF a boar is what it was, and a boar is never two things at once.**
   `Flags.DEFAULTS.BOAR_MODEL.default` is `false`, read once at `Boar.CONFIG.MODEL.ENABLED` and
   passed inward as `config` -- the only permitted shape. *Verify:* `boar_model.spec`, "flag OFF
   draws exactly the grey box" (no `Model` child, no `AnimationController`, box and zone parts still
   `Transparency` 0, `Damageable`/`HitZone`/`CanQuery`/`CanCollide` unchanged). Every pre-115 boar
   spec still passes untouched.

2. **The model cannot change a hit.** `Body.attachVisual` sets the clone `Massless`,
   `CanCollide = false`, **`CanQuery = false`**, `CanTouch = false`, and gives it neither
   `Damageable` nor `HitZone`; the grey box is made invisible rather than deleted, and only after the
   model is really there. *Verify:* `boar_model.spec`, "is a passenger: massless, no collision, NO
   RAY CAN SEE IT" and "a ray from outside still meets a zone part, never the model" -- a real
   `Workspace:Raycast` through the animal, which lands on the box (harness note: *a ray through the
   boar met Boar1*).

3. **The feet do not slide, and the number is measured off the clip.** Every clip is in place, so a
   planted hoof's speed IS the clip's ground speed; `tools/boar_prep.py` measures it (walk 2.852,
   trot 10.244, run 17.210 studs/s at this scale) and `Body.clipFor` plays `speed / that`.
   *Verify:* `boar_model.spec`, "plays each gait at the rate that stops the feet sliding" (harness
   note: *rates walk 1.403 trot 1.757 run 2.208*) and "never clamps at a speed a boar can actually
   reach", which sweeps `WALK_FROM`..`SPRINT_SPEED` (*swept 0.5..38 studs/s, 0 clamped*). The band
   edge is `MODEL.TROT_FROM = CLIPS.walk.groundStudsPerSecond * WALK_MAX_RATE`, derived, not a
   literal -- a wounded boar sits between Karen's dials (measured live at 8.99 and 9.84 studs/s) and
   used to walk with clamped feet.

4. **One rig, one `AnimationController`, and it is asserted rather than hoped.** `LoadAsset` returns
   `Model > Model > { MeshPart, InitialPoses, AnimationController }` -- the importer writes that
   controller -- and with two on one rig **neither steps**: every track loaded with the right
   `Length`, `WeightTarget` reached 1, and `WeightCurrent`, `TimePosition` and every `Bone.Transform`
   stayed at zero for ever on both server and client, with no error. `Body.attachVisual` strips what
   the template brings and asserts one of each. *Verify:* `boar_model.spec`, "ends up with exactly
   ONE AnimationController and ONE Animator", and `makeTemplate`, whose fake now carries the asset's
   own controller and the extra `Model` nesting -- a fake without them let the first version of this
   spec pass while every boar in the game stood still.

5. **A dead boar lies ON the ground and stays where it fell.** `Body.collapse` rolls the box only
   when nothing is drawn on it (the death clip does the falling itself, and doing both buried the
   animal: head 1.20 studs below ground, ear 1.93 below, hooves 0.86 above); `Body.stepCarcass`
   anchors the box once it has come to rest, in **both** flag states, because the grey carcass was
   shoveable too -- measured at **1.826 studs** from one walking-speed impulse with the flag OFF.
   *Verify:* `boar_model.spec`, "the carcass lies ON the ground, not in it" and "a dead boar stays
   where it fell" (harness notes: *flag OFF carcass up.y = 0.707*, *flag ON carcass up.y = 1.000*,
   *carcass box bottom 620.081, ground 620*, *flag OFF ... shove moved 0.0000 studs*, *flag ON ...
   shove moved 0.0000 studs*). The pure rules are `Boar.carcassIsStill` and
   `Boar.shouldAnchorCarcass`; removing the single `Anchored = true` fails three cases
   (mutation-checked). Anchoring touches no property a shot reads -- asserted by "the carcass still
   answers a ray exactly as it did" -- and "a LIVE boar is still unanchored, and still moves".

6. **The clip decision cannot chatter.** Karen's *"head shaking sometimes vierd"* was measured, not
   guessed: up to **24 clip changes in 7 s** on a standing boar, several lasting 0.03 s against a
   0.15 s fade, **three tracks at once** all writing the same bones, and raw yaw swinging
   −120..+173 deg/s at body speed 0.0. Three causes, each fixed at the cause -- the yaw is smoothed
   (`YAW_SMOOTH_SECONDS`), the turn band has hysteresis (`TURN_FROM_DEG` 60 in, `TURN_EXIT_DEG` 35
   out), and no gait may replace another before its own crossfade has finished
   (`MIN_CLIP_SECONDS` 0.18 > `FADE_SECONDS` 0.15). A death and a flinch bypass the dwell; the RATE
   still follows the speed every frame. *Verify:* `boar_model.spec`, "the clip does not chatter" --
   five cases, including the measured yaw storm replayed through the fixed decision (harness note:
   *the measured yaw storm now makes 2 clip change(s)*). After, live: 5--8 changes per 7 s, never
   more than two tracks.

7. **Every asset id was loaded back before it was written down, and that found two faults.** The ten
   animation ids can only be made inside Studio (Open Cloud takes an `Animation` only as a
   Studio-written `.rbxm`; `AssetService:CreateAssetAsync` answered *"not available yet"* for both
   `Animation` and `Model`), so the Director published them -- `ESCALATE.md`, closed. The Builder
   then read each back with `AnimationClipProvider:GetAnimationClipAsync`: **every clip length was
   one frame too long** (N frames at 24 fps span N−1 intervals), and **all ten were published
   `Loop = true`**, deaths included. *Verify:* `Assets.AssetRow.clipSeconds` carries the measured
   length, `BoarAssetsBoot` warns on drift between it and `Boar.CONFIG.MODEL.CLIPS`, and
   `boar_model.spec`'s "every clip the boar can play has a published asset id" fails the build past
   half a frame (*worst clip-length drift 0.0000 s*). `Body`'s `play` writes `track.Looped`
   immediately before every `Play`, because a track takes `Looped` from the asset *when the asset
   arrives*.

8. **A harness fault, found by this task and reported as one (rule 6).**
   `src/serverstorage/Assets/init.luau` passed StudioMCP's ~100 KB result limit when the ten
   animation rows landed, and the whole run died as *"one instance is too big for a single StudioMCP
   result"* with nothing wrong in the repository -- a size cap on every file in the repo, set by a
   transport. Splitting the BATCH is finished at one instance, so the SOURCE is split:
   `read_source_in_slices` re-fetches the record with `skipSource` and reads the Source in
   `SOURCE_SLICE_CHARS` pieces, length-checking every one. *Verify:* `tools/studio_mcp.py selftest`
   (six new cases, in CI) and the run's own line *`ServerStorage.Assets`: Source read in 2 slice(s),
   95328 chars*. Removing the per-slice guard makes the selftest fail (mutation-checked).

## Screenshots (rule 5) -- what they actually show, looked at by me

- `.screenshots/20261003T120402Z-task115f-move3.png` -- two boars trotting away at ~7 studs. Their
  legs are in **different phases of the stride**, not a shared rest pose; feet on the ground, no
  tearing at the shoulders or the neck.
- `.screenshots/20261003T131632Z-task115fix-dead2.png` -- the carcass after the burial fix: lying on
  its flank **on** the surface, head and snout on the ground with a tusk visible, legs folded out in
  front, the whole body above the ground.
- `.screenshots/20261003T133938Z-task115walk-before.png` and `...133941Z-task115walk-after.png` --
  the same carcass at the player's feet, then after 2.5 s of really holding W into it. The body has
  not moved; the measurement beside it reads 0.0000 studs.
- `.screenshots/20261003T120313Z-task115e-carcass1.png` is kept deliberately: it is the **buried**
  boar Karen reported, only its legs above the surface. My own earlier report described it as "lying
  on its flank", which was wrong.

## What I could not verify

- **No spec can load a real animation.** `AnimationTrack.Length` is 0 without the network, which is
  why `Boar.shouldFreeze`, `Boar.clipFor`, `Boar.carcassIsStill` and `Boar.shouldAnchorCarcass` are
  pure functions with their own cases. That every clip really plays, at the right rate, and that a
  death freezes on its last frame, is a LIVE measurement recorded in
  `docs/research/2026-10-03-boar-skinned-model.md`, not a spec.
- **The Fab Standard License grant was read through a web search**, not from `fab.com/eula`, which
  answers 403 to this machine. Recorded in `CREDITS.md` and in the `licence` field of the rows.
- **A boar killed on a steep slope** could in principle slide past the 0.25 s stillness window before
  anchoring; the 4 s backstop bounds it. Not reproduced -- the map is flat where boars run.

# Task 293 -- a shot deer stands after it dies

Task: 293
Round: 1
Base: 1c1408fc (main)
Code commit: 3a44e0bf8af41a7ee631ec2add13eb2cac9cd048

Gate (full one-player run, clean tree, at the code commit):
`[harness] PASS: 34/34 checks @ 3a44e0bf8af41a7ee631ec2add13eb2cac9cd048 (clean tree) scope=all`
`[harness2]`: N/A -- no `TWO_PLAYER_PATHS` path is touched (`src/server/Boar/`, `tests/server/`).

## PLAN (core quality protocol)
Honest about order: the plan below was MEASURED first and written into this file after the fix was
coded, in one session against a 13:17 deadline. Every number in it is a reading, not a recollection.

(a) REAL LIFE: a deer shot through the chest collapses and stays down; `docs/design/boar-ai.md`
    section 6 and task 150's rule -- exactly one thing lays an animal down.
(b) MEASURED NOW (`<runs-dir>/293-lab.luau`, `293-lab3.luau`, `293-tail.luau`, DEV Play, the real
    published rigs, read as live Instance properties): the DEER DEATH CLIP IS RIGHT. Played and held
    while still playing, `Death_L` lays every kind flat -- drawn height (lowest to highest
    `Bone.TransformedWorldCFrame`) hind **4.94 -> 1.03**, stag **5.66 -> 1.30**, calf **3.30 -> 1.32**.
    The instant that non-looped track runs PAST its end it STOPS and the same hind draws
    **4.94 studs again -- its standing bind pose** (`293-lab3.luau`: `SERVER hind ... playing=false
    w=0.00 drawnSpan now=4.94 then=1.02`, beside `SERVER boar ... playing=true w=1.00 drawnSpan 1.24`).
(c) TARGET: a dead deer's drawn height stays at the lying band measured in (b) -- hind/stag/calf
    1.03-1.55 studs over the whole tail of the clip (`293-tail.luau`) -- and never the 3.30-5.66
    standing band, for the whole carcass time. Threshold: <= 2.0 studs is lying, >= 3.3 is standing.
(d) LEVER: `Body.stepVisual`'s hold. `grep -n "shouldFreeze" src/server/Boar/Body.luau` ->
    `1588: if Body.shouldFreeze(track.TimePosition, track.Length, track.Speed, reach) then` and
    `Body.freezeReach(speed, dt, epsilon)` at 1616. The writer exists; it predicts the next step from
    the LAST frame's `dt`, so one longer frame steps past the end before it is asked.
(e) HOW MEASURED AFTER: the same probes. See claim 6 for what is NOT proven live.

## What changed
`Body.shouldRehold` (pure) plus one call in `Body.stepVisual`: a collapsed animal whose held death
track has stopped, or sits at weight 0, is put back on `handle.heldAt` -- `Play(0,1,0)`,
`TimePosition = at`, `AdjustSpeed(0)` -- and `handle.reholds` counts it. `Runtime:animationOf`
publishes `reholds`. One spec case in `boar_model.spec.luau`. 81 lines added, nothing removed.

## Claims
1. **The clip and the asset are not the fault.** Verify: the numbers in (b); `Death_L`
   (90698126097935) held while playing lays all three deer kinds flat.
2. **The fault is the hold losing the pose.** A non-looped track that ends STOPS, and a stopped
   track draws the bind pose. Verify: `293-lab3.luau`'s two lines above -- same instrument, same
   session, hind stopped (bind, 4.94) and boar held (1.24).
3. **Why the deer and not the boar.** `DEER_CLIPS` in `src/server/Boar/init.luau` publishes no
   `deathPaddleLeft/Right`, so `Body.clipFor` holds the FALL itself; the boar holds the 4 s paddle.
   Verify: that table, and `Body.collapse`'s `deathClipNames`.
4. **One rule for every species, on a tick.** Verify: `Body.shouldRehold`'s only inputs are
   collapsed / heldClip / playing / weight -- no kind, no species. It is asked each `stepVisual`,
   not at the death event, because the overrun is a race with one long frame (`freezeReach`).
5. **It writes only when the invariant is broken.** Verify: the call site -- two property reads per
   carcass per step, and `Play/TimePosition/AdjustSpeed` only inside `shouldRehold`. A held track
   that is playing at weight 1 is left alone (`shouldRehold(true,"deathLeft",true,1) == false`), so
   the per-frame-write fault of task 150 round 1 cannot come back.
6. **The pose it restores is the pose the lift was measured against.** `handle.heldAt` is the frame
   `shouldFreeze` chose (`length - HOLD_EPSILON`), so `KINDS.deathLiftStuds` still holds. Verify:
   `handle.heldAt` is written only in the freeze branch and read only here.
7. **FAIL FIRST, pasted.** With the two `src/` files stashed and the spec in place:
   `failed [server] boar_model.spec:1188 ServerStorage.Tests.boar_model.spec:1188: attempt to call a
   nil value` / `[tests:server] FAIL: 2410 passed, 1 failed, 0 skipped, 1 errors, 75 spec files`
   (`[harness] FAIL: 32/34 checks @ 1c1408fc25fb (DIRTY TREE (1 paths) - NOT valid evidence) scope=all`,
   main's tree). With the fix: 34/34 clean, above.
8. **Nothing else changed.** `git diff --name-only 1c1408fc..3a44e0bf` is the three files.

## What I could NOT verify
- **The live after-measurement on a real carcass: NOT PROVEN.** No animal could be killed in the DEV
  session: `FireRequest:FireServer` at a staged 18-22 studs, 6 rounds with reloads, left
  `Carcass=nil` on every target and the server console shows no hit (`<runs-dir>/293-hunt.luau`).
  The cause of THAT is not diagnosed -- see `ESCALATE.md`. So the fix is proven as the rule and the
  measured cause, not yet as a carcass in a frame. The dispatch assigns the Forest Test proof (a
  real rifle kill on a hind, the frame after 3 s) to the Director.
- Whether a client whose own track also ran past the end gets the pose back from the replicated
  `Play`: task 150 measured that mechanism fixing "one in ten stands on the CLIENT", and this reuses
  it, but I did not re-measure a client carcass.

## Answered flags
- ANSWERED: L-133 -- every pose reading is taken while the real `Death_L` track is live and playing,
  several points per kind (`293-tail.luau` samples seven frames of the tail for hind, stag, calf and
  boar; `293-lab3.luau` reads the held and the overrun state). No instrument anchored a live animal
  or destroyed its Animator: the lab builds its OWN rig from the published template.
- ANSWERED: ROUTE -- kills were attempted only through `FireRequest:FireServer`
  (`<runs-dir>/293-hunt.luau`, `293-shoot.luau`), never by aiming at a screen point. None landed; see
  "What I could NOT verify" and `ESCALATE.md`.
- ANSWERED: L-104 -- the carcass/death-pose code is ONE path for both places: `Body.collapse` and
  `Body.stepVisual` in `src/server/Boar/Body.luau`, reached through `Boar.newRuntime` from
  `MatchBoot.server.luau` (DEV) and `ForestTestBoot.server.luau` (Karen's Forest Test). Checked by
  grep: those are the only two `Boar.newRuntime` callers, and neither replaces `Body`.
- ANSWERED: L-026 -- every pose and track reading is a live Instance property
  (`Bone.TransformedWorldCFrame`, `AnimationTrack.TimePosition/WeightCurrent/IsPlaying`) in place. No
  probe required a game module for state; `Assets` is required only for asset ids.
- ANSWERED: L-010/L-031 -- the fix is ONE shared invariant in `Body`, with no species or kind in its
  inputs, not a deer patch. The boar's carcass is unchanged: its hold already holds, and
  `shouldRehold` leaves a playing, full-weight track alone.
- ANSWERED: L-029 -- it reconciles on a TICK, not on the death event, which is why it covers the
  intermittent case; the overrun race is named in the code comment.
- ANSWERED: L-033 -- one Forest Test kill is NOT treated as proof here: the live after-measurement is
  marked NOT PROVEN, and the Director's proof should be several kills.
- ANSWERED: L-020 -- no bone or Motor6D CFrame is written by this fix. It writes only
  `AnimationTrack` properties, so no rig's axis convention is assumed.

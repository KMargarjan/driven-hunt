# Task 293 -- a shot deer stands after it dies

Task: 293
Round: 2
Base: 1c1408fc (main)
Code commit: 5be6ae878cdc6462c2f29413329eaef829627f23

Gate (full one-player run, clean tree):
`[harness] PASS: 34/34 checks @ 5be6ae878cdc6462c2f29413329eaef829627f23 (clean tree) scope=all`
`[harness2]`: N/A -- no `TWO_PLAYER_PATHS` path is touched (`src/server/Boar/`, `tests/server/`).
The last commit that changed `src/` or `tests/` is `c44c64b8`; only `reviews/task-293/RESULT.md`
changed after it, and the harness line above covers both.

## PLAN (core quality protocol)
Honest about order: everything below was MEASURED first; the plan was written into this file after
the code, in one session against a 13:17 deadline. Every number is a reading, not a recollection.

(a) REAL LIFE: a deer shot through the chest collapses and stays down. Task 150's rule: exactly one
    thing lays an animal down (`docs/design/boar-ai.md` section 6).
(b) MEASURED NOW (DEV Play, the real published rigs, live Instance properties only --
    `<runs-dir>/293-lab.luau`, `293-lab3.luau`, `293-tail.luau`): THE DEER DEATH CLIP IS RIGHT.
    Held while still playing, `Death_L` lays every kind flat -- drawn height, lowest to highest
    `Bone.TransformedWorldCFrame`: hind **4.94 -> 1.03**, stag **5.66 -> 1.30**, calf **3.30 -> 1.32**.
    The instant that non-looped track runs PAST its end it STOPS and the same hind draws **4.94
    again -- its standing bind pose**: `SERVER hind len=1.167 t=1.167 sp=0.00 w=0.00 playing=false
    drawnSpan now=4.94 then=1.02`, beside `SERVER boar ... playing=true w=1.00 drawnSpan 1.24`.
(c) TARGET: a dead deer's drawn height stays in the lying band measured in (b) -- 1.03-1.55 studs
    across the whole tail of the clip (`293-tail.luau`, seven frames per kind) -- and never the
    3.30-5.66 standing band. Threshold: <= 2.0 lying, >= 3.3 standing.
(d) LEVER: the hold in `Body.stepVisual`. `grep -n "shouldFreeze" src/server/Boar/Body.luau` ->
    `Body.shouldFreeze(track.TimePosition, track.Length, track.Speed, reach)` with
    `Body.freezeReach(speed, dt, epsilon)`. The writer exists and predicts the next step from the
    LAST frame's `dt`, so one longer frame steps past the end before it is asked.
(e) HOW MEASURED AFTER: the same probes. See "What I could NOT verify".

## What changed (final state)
`src/server/Boar/Body.luau`: two pure rules and one block in `stepVisual`.
- `Body.shouldRehold(collapsed, deathClip, playing, weight, reholds, config)` -- a dead animal's
  death clip must still be PLAYING at weight; bounded by `MODEL.REHOLD_LIMIT`.
- `Body.holdFrame(heldAt, length, config)` -- the frame it goes back on, clamped to
  `length - HOLD_EPSILON`.
- the block names the animal's own death clip through `Body.deathClips` (`handle.heldClip` or
  `handle.clip`), and on a broken invariant does `Play(0,1,0)` / `TimePosition = frame` /
  `AdjustSpeed(0)`, then writes `heldAt`, `heldClip` and `reholds += 1`.

`src/server/Boar/init.luau`: `MODEL.REHOLD_LIMIT = 3`, `reholds` in `Runtime:animationOf`, three
exports. `tests/server/boar_model.spec.luau`: two cases. 168 insertions, nothing removed.

## Claims
1. **The clip and the asset are not the fault**, and the deer feel it where the boar does not
   because `DEER_CLIPS` publishes no `deathPaddleLeft/Right` -- the fall itself is the clip that is
   held. Verify: (b) numbers above; `DEER_CLIPS` in `src/server/Boar/init.luau`; `Body.clipFor`
   `info.collapsed` branch.
2. **Round 1 finding 1 is fixed: it no longer keys off `heldClip`.** The block asks
   `Body.deathClips(config)` and accepts `handle.heldClip or handle.clip`, so the overrun state --
   where the freeze never ran and `heldClip` is nil -- is seen. Verify: the call site; `handle.clip`
   is set by `play` on the frame the death starts, long before any overrun.
3. **Round 1 finding 2 is fixed: the frame is clamped and the repair is bounded.**
   `Body.holdFrame` returns `math.max(math.min(heldAt or target, target), 0)` with
   `target = length - HOLD_EPSILON`, so a frame at or past the end can never be restored; and
   `shouldRehold` refuses once `reholds >= MODEL.REHOLD_LIMIT` (3). Verify: both functions, and the
   spec rows that assert each.
4. **It is one repair per stop in the ordinary case.** After the put-back the track is playing at
   weight 1, which `shouldRehold` refuses, and `heldClip` is set so `play` leaves it alone
   (`shouldAdjustRate`). Verify: the spec case drives three consecutive `stepVisual` ticks and
   asserts `plays == 1`, `reholds == 1`.
5. **Round 1 finding 3 is fixed: a case drives the real code.** The `boar_model.spec` case "drives
   stepVisual on a carcass whose death track stopped" builds a collapsed handle and a stub track
   reporting `IsPlaying = false` at `TimePosition = Length`, calls `Boar.stepVisual`, and asserts
   one `Play`, `TimePosition == Length - HOLD_EPSILON`, `Speed == 0`, `heldClip == fall`,
   `reholds == 1`. Verify: delete the `stepVisual` block alone and `plays` stays 0 -- `heldClip`
   stays nil and the freeze branch cannot fire on a stopped track, so three expectations fail.
6. **A live animal and a box-toppled carcass are untouched.** Verify: the block guard
   `handle.collapsed and not handle.toppled`, the `collapsed` and `deathClip` rows of
   `shouldRehold`, and the live-animal tick in the spec (`plays` unchanged, `reholds == 0`).
7. **One rule for every species** (Learning Agent L-010/L-031: the boar standing carcass was patched
   three times, one kind at a time). Verify: no kind or species appears in `shouldRehold`,
   `holdFrame` or the block; the clip names come from `Body.deathClips(config)`, which the deer own
   `MODEL` clone feeds.
8. **The pose restored is the pose the lift was measured against.** `length - HOLD_EPSILON` is the
   frame `shouldFreeze` aims at and the frame `KINDS.deathLiftStuds` was measured at. Verify: those
   comments in `init.luau` and `Body.holdFrame`.
9. **Nothing else changed.** `git diff --name-only 1c1408fc..c44c64b8` is the three files.
10. **Fail-first, pasted** (round 1, the pure rules only, on the main tree):
    `failed [server] boar_model.spec:1188 ... attempt to call a nil value` /
    `[tests:server] FAIL: 2410 passed, 1 failed, 0 skipped, 1 errors, 75 spec files` /
    `[harness] FAIL: 32/34 checks @ 1c1408fc25fb (DIRTY TREE (1 paths) - NOT valid evidence) scope=all`.

## What I could NOT verify
- **The live after-measurement on a real carcass: NOT PROVEN.** No animal could be killed in the DEV
  session -- `FireRequest:FireServer` at a staged 18-22 studs, six rounds with reloads, left
  `Carcass = nil` on every target and no hit in the server console (`<runs-dir>/293-hunt.luau`).
  Written up in `ESCALATE.md` at the hard stop. So this ships with the cause measured against the
  drawn pose and the rule driven by a spec, NOT with an after-frame of a carcass the game produced.
  The dispatch assigns that proof to the Director (a real rifle kill on a hind in the Forest Test,
  the frame after 3 s) and it should be several kills, not one (L-033).
- Whether a client whose own track also overran gets the pose back from the replicated `Play`: task
  150 measured that mechanism fixing "one in ten stands on the CLIENT" and this reuses it; I did not
  re-measure a client carcass.

## Answered flags
- ANSWERED: L-133 -- every pose reading was taken while the real `Death_L` track was live, several
  frames per kind (`293-tail.luau`: seven frames of the tail for hind, stag, calf and boar). No
  instrument anchored a live animal or destroyed its Animator: the lab builds its OWN rig from the
  published template.
- ANSWERED: ROUTE -- kills were attempted only through `FireRequest:FireServer`, never by aiming at
  a screen point. None landed; see above and `ESCALATE.md`.
- ANSWERED: L-104 -- one code path for both places: `Body.collapse` and `Body.stepVisual`, reached
  through `Boar.newRuntime` from `MatchBoot.server.luau` (DEV) and `ForestTestBoot.server.luau`
  (the Forest Test Karen plays). Checked by grep: those are the only two `Boar.newRuntime` callers
  and neither replaces `Body`.
- ANSWERED: L-026 -- live Instance properties only (`Bone.TransformedWorldCFrame`,
  `AnimationTrack.TimePosition/WeightCurrent/IsPlaying`). No probe took game state from a `require`;
  `Assets` was required for asset ids alone.
- ANSWERED: L-010/L-031 -- one shared invariant, no species in its inputs (claim 7).
- ANSWERED: L-029 -- reconciled on a TICK, not on the death event, which is what covers the
  intermittent case; the race is named in the code comment.
- ANSWERED: L-033 -- one kill is not treated as proof: the live proof is marked NOT PROVEN and the
  Director proof should be several kills.
- ANSWERED: L-020 -- no bone or Motor6D CFrame is written; only `AnimationTrack` properties, so no
  rig axis convention is assumed.

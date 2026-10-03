# Task 115 -- the wild boar arrives: a bought, rigged, animated animal, behind `BOAR_MODEL`

Task: 115
Round: 3
Base: `main` (`82a3f36`)
Code commit: 37ff2f45f14757dabdca0fe6043dbc391f7ebbc3

```
[harness] PASS: 33/33 checks @ 37ff2f45f14757dabdca0fe6043dbc391f7ebbc3 (clean tree) scope=all
```

**ONE LINE IS THE WHOLE GATE for this change** -- no `[harness2]`. `needs_two_player` over
`git diff --name-only origin/main...HEAD` returns **`[]`**: not one changed file is in
`TWO_PLAYER_PATHS`. It is boar, assets, flags and tools; no `src/server/Match/`, no `MatchBoot`, no
`src/client/Match/`, no `src/shared/Drive/`, no `tests/client/Role.luau`, none of the match / tie /
outfit specs. `test --scope auto` resolves to `all` anyway, so the full `test` the merge gate wants
is the same run.

## What changed since round 2, and what I got wrong

**Round 2's claim 2 was a false measurement, and the fault was mine.** It said round 1's code left
the rig in the rest pose. The build I measured it on was **not round 1's**: I removed the new
`heldClip` guard from `play` but left `heldClip` gating the *freeze*, which produces a third
behaviour that never shipped -- re-rate every frame with nothing re-freezing it, so the track really
did run away and stop. Round 1 had no `heldClip` anywhere; its freeze ran unconditionally, wrote 1
then 0 before the engine stepped the animation, and the pose held.

The Reviewer was right that the request asserted two things that could not both be true, and the
Director was right that a change to how a carcass is **held** is a drawn change that needed a look.
Both are now answered by measurement: three new frames on this commit, and a faithful replica of
round 1's three hunks measured beside it.

## Claims

1. **A held clip is never re-rated.** `play` asks the new pure `Body.shouldAdjustRate`, which
   refuses to re-rate the clip the boar is holding: a held clip's speed is deliberately not the
   clip's rate, so "they disagree" is not a reason to write anything. `handle.heldClip` is set once,
   by the freeze, and cleared when a new clip starts. *Verify:* `boar_model.spec`,
   "never re-rates the clip it is holding" -- `Boar.shouldAdjustRate(DEATH, DEATH, 0, 1,
   RATE_EPSILON)` is `false` **and** the same call with nothing held is `true`, so the `false` is the
   hold and not an accident of the numbers; plus "a clip that is NOT held is still re-rated when the
   speed really changes". Round 2's 600-iteration case is **dropped**: it stepped nothing and its
   note read as a stepped carcass (round 2, note).

2. **WHAT ROUND 1 ACTUALLY DID, measured on a faithful replica of its three hunks.** It held the
   pose. `deathLeft` at weight 1.00, `t=1.18/1.21`, **speed 0.00** at t+1 s, t+10 s *and* t+60 s;
   head +0.42, hoof +0.13, lowest −0.006 of the ground, unchanged across the minute -- the same
   numbers this commit gives (+0.45 / +0.12 / −0.008), and the frames look the same. **So Karen's
   *"looks good now"* and the 13:16 / 13:39 frames were of code that drew the carcass correctly**,
   and they were never evidence for something that had changed underneath them. What the fix is worth
   is the cost the Reviewer named, not a visual fault: **two property writes per frame per carcass,
   replicated** -- up to 1,920 a second with eight carcasses down. Whether a client ever *rendered*
   the `speed = 1` it was sent stays the Reviewer's inference: I did not observe a client-side
   artefact in either build and I am not claiming one. *Verify:*
   `docs/research/2026-10-03-boar-skinned-model.md` section 7(d), which carries the correction and
   both runs' numbers, and the two 60 s frames below.

3. **With the flag OFF a boar is what it was, with one deliberate exception.** `BOAR_MODEL.default`
   is `false`, read once at `Boar.CONFIG.MODEL.ENABLED` and passed inward as `config`. The exception
   is `Body.stepCarcass`, which anchors a settled carcass in **both** states on purpose (claim 6) --
   round 1's claim 1 said "what it was" without that caveat, which the Reviewer was right to flag.
   *Verify:* `boar_model.spec`, "flag OFF draws exactly the grey box".

4. **The model cannot change a hit.** `Body.attachVisual` now applies `Massless`, `CanCollide`,
   `CanQuery`, `CanTouch` and `Anchored` to **every `BasePart`** the template brings, not only the
   mesh (round 1 note), and gives none of them `Damageable` or `HitZone`. *Verify:* `boar_model.spec`,
   "is a passenger: massless, no collision, NO RAY CAN SEE IT" and "a ray from outside still meets a
   zone part, never the model" -- a real `Workspace:Raycast` (harness note: *a ray through the boar
   met Boar1*).

5. **The feet do not slide, and the number is measured off the clip.** `tools/boar_prep.py` measures
   each clip's ground speed from its planted hoof (walk 2.852, trot 10.244, run 17.210 studs/s) and
   `Body.clipFor` plays `speed / that`. *Verify:* "plays each gait at the rate that stops the feet
   sliding" and "never clamps at a speed a boar can actually reach", which now prints the band it
   counts (harness note: *swept 1.2..38 studs/s, 0 clamped*; below ~1.1 the floor bites and the case
   says so). `MODEL.TROT_FROM` is derived from the hoisted `WALK_MAX_RATE`, not a repeated literal.

6. **A dead boar lies ON the ground and stays where it fell.** `Body.collapse` rolls the box only
   when nothing is drawn on it; `Body.stepCarcass` anchors it once it has come to rest, in both flag
   states, because the grey carcass was shoveable too -- **1.826 studs** from one walking-speed
   impulse with the flag OFF. *Verify:* "the carcass lies ON the ground, not in it" and "a dead boar
   stays where it fell" (harness notes: *flag OFF carcass up.y = 0.707*, *flag ON ... = 1.000*,
   *carcass box bottom 620.081, ground 620*, *shove moved 0.0000 studs* in both). Anchoring touches
   no property a shot reads -- "the carcass still answers a ray exactly as it did" -- and "a LIVE
   boar is still unanchored, and still moves".

7. **The clip decision cannot chatter, and a death cannot be stepped past its end.** Karen's
   *"head shaking sometimes vierd"* was measured: 24 clip changes in 7 s, three tracks at once, raw
   yaw −120..+173 deg/s at body speed 0.0. Fixed at three causes -- the yaw is smoothed, the turn band
   has hysteresis, and no gait may replace another before its own crossfade finishes. Round 1's note
   about `HOLD_EPSILON` is fixed with it: the freeze window is now `max(HOLD_EPSILON, |speed| * dt)`,
   because `stepVisual` gets the raw Heartbeat `dt` and one long frame could step a non-looped death
   clean past its end -- it is `Body.freezeReach` now, exported so the spec drives the production
   formula instead of recomputing `math.max` itself (round 2, note). *Verify:* "the clip does not
   chatter" (note: *the measured yaw storm now makes 2 clip change(s)*) and "the freeze window is
   this repository's formula, not math.max in the spec". Its overshoot on a hitch -- freezing a death
   a fraction short of its end rather than past it -- is written down in `freezeReach`'s own comment
   as the trade it is (round 2, note).

8. **Every asset id was loaded back before it was written down.** The ten animation ids can only be
   made inside Studio; the Director published them (`ESCALATE.md`, closed), and reading each back
   found **every clip length one frame too long** and **all ten published `Loop = true`**.
   *Verify:* `Assets.AssetRow.clipSeconds`, `BoarAssetsBoot`'s drift warning, and
   "every clip the boar can play has a published asset id" (note: *worst clip-length drift 0.0000 s*).
   `play` writes `track.Looped` immediately before every `Play`.

## Screenshots (rule 5) -- three new ones, on this commit, looked at by me

A dead boar, killed in a live session with `BOAR_MODEL` and `QUICK_TEST` on, photographed from ~7
studs to its side at **1 s, 10 s and 60 s** after death. Flags cleared afterwards.

- `.screenshots/r3b-carcass-1s.png` -- lying on its right flank **on** the ground, head and snout
  flat on the surface with the lower tusk showing, the near ear up, forelegs and hind legs folded out
  toward the camera, tail along the ground. Not standing, not sunk, not the rest pose.
- `.screenshots/r3b-carcass-10s.png` -- the same animal in the **same pose**, in the same place.
- `.screenshots/r3b-carcass-60s.png` -- again identical a full minute after death, which is half of
  `CARCASS_SECONDS`. Measured alongside each frame: `deathLeft` w=1.00, t=1.18/1.21, speed 0.00, and
  head/hoof/lowest unchanged to three decimals across all three.
- `.screenshots/r1replica-carcass-60s.png` -- the **same shot on a faithful replica of round 1's
  code**, for the comparison claim 2 rests on. Visually the same boar in the same pose.

Carried over from earlier rounds, still accurate for what they show:

- `.screenshots/20261003T120402Z-task115f-move3.png` -- two boars trotting away, legs in different
  phases of the stride, feet on the ground, no tearing.
- `.screenshots/20261003T133938Z-task115walk-before.png` / `...133941Z-...-after.png` -- a carcass at
  the player's feet, then after 2.5 s of holding W into it: unmoved.
- `.screenshots/20261003T120313Z-task115e-carcass1.png` is kept deliberately: the **buried** boar
  Karen reported, only its legs above the surface, which my own report once misdescribed as "lying on
  its flank".

## What I could not verify

- **`play`'s call site and the `heldClip` write have no spec.** `Body.shouldAdjustRate` and
  `Body.freezeReach` are tested as functions, but the wiring that passes `handle.heldClip` into the
  first and sets it in `stepVisual` is not: making the freeze fire needs a loaded animation, and
  `shouldFreeze` refuses a `Length` of 0, which is every track a spec can build. A regression that
  stopped passing `heldClip` would leave every case green (round 2, note). It is covered by the live
  1 s / 10 s / 60 s measurement above and by nothing else, and that is the honest state.
- **No spec can load a real animation**, which is why `shouldFreeze`, `freezeReach`, `clipFor`,
  `shouldAdjustRate`, `carcassIsStill` and `shouldAnchorCarcass` are pure functions with their own
  cases.
- **Whether a client rendered the `speed = 1` round 1 sent it.** Not observed, not claimed.
- **The Fab Standard License grant was read through a web search**, not from `fab.com/eula` (403).
- **A boar killed on a steep slope** could slide past the 0.25 s stillness window before anchoring;
  the 4 s backstop bounds it. Not reproduced.
- **A multi-byte character split across a source slice** (`tools/studio_mcp.py`): both length checks
  compare bytes now, so the message is right, but the split itself is not handled. The one oversized
  file is ASCII; queued as 115a(a).

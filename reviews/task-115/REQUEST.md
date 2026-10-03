# Task 115 -- the wild boar arrives: a bought, rigged, animated animal, behind `BOAR_MODEL`

Task: 115
Round: 2
Base: `main` (`82a3f36`)
Code commit: 79b6894c1d6fcaa2bb135b937b9d741c123ac6bc

```
[harness] PASS: 33/33 checks @ 79b6894c1d6fcaa2bb135b937b9d741c123ac6bc (clean tree) scope=all
```

**ONE LINE IS THE WHOLE GATE for this change** -- no `[harness2]`. `needs_two_player` over
`git diff --name-only origin/main...HEAD` returns **`[]`**: not one changed file is in
`TWO_PLAYER_PATHS`. It is boar, assets, flags and tools; no `src/server/Match/`, no `MatchBoot`, no
`src/client/Match/`, no `src/shared/Drive/`, no `tests/client/Role.luau`, none of the match / tie /
outfit specs. `test --scope auto` resolves to `all` anyway, so the full `test` the merge gate wants
is the same run.

## What changed since round 1

**The one blocking finding, fixed at the cause.** A frozen death was re-rated and re-frozen on every
frame. `Body.clipFor` answers "the death clip, rate 1" for a dead boar while the frozen track sits at
speed 0 on purpose, so `play`'s re-rate branch wrote `AdjustSpeed(1)` and the freeze wrote
`AdjustSpeed(0)` back -- for `CARCASS_SECONDS` and up to `maxBoars` carcasses, on a server `Animator`
whose every write replicates.

`play` now asks the new pure **`Body.shouldAdjustRate`**, which refuses to re-rate the clip the boar
is **holding**: a held clip's speed is deliberately not the clip's rate, so "they disagree" is not a
reason to write anything. `handle.heldClip` is set once, by the freeze, and cleared when a new clip
starts, so the death's speed is written exactly once per kill. `Body.shouldFreeze`'s own
"a speed already 0" guard stays as the second line of defence it was always written to be.

Six of the seven notes are fixed in the same lines; the seventh is queued as `TASKS.md` 115a(a).

## Claims

1. **A held clip is never re-rated, and the count proves it.** *Verify:* `boar_model.spec`,
   "a frozen death costs nothing after it has frozen" -- `Boar.shouldAdjustRate(DEATH, DEATH, 0, 1,
   RATE_EPSILON)` is `false` **and** the same call with nothing held is `true`, so the zero is the
   hold and not an accident of the numbers. Over 600 frames the counts are **0 and 600** (harness
   note: *600 frames of a frozen death -> 0 rate write(s); unheld -> 600*). A live carcass cannot
   show this -- a spec has no loaded animation, so `shouldFreeze` refuses a `Length` of 0 -- which is
   why the seam is the decision. `Runtime:animationOf` carries the live counter, read-only, the same
   shape `Runtime:woundOf` has.

2. **Measured live, with round 1's code put back.** The carcass's Animator had **no playing track at
   all**: 0 samples above weight 0.01 over 4 seconds, on the server *and* on the client. The
   non-looped death had been driven past its end and **stopped** -- the rest pose, which is the fault
   the freeze exists to prevent, and worse than the replication cost the finding names. With the fix:
   `deathLeft` at full weight and **Speed 0.000** across 241 samples in 4 seconds, both sides.
   *Verify:* `docs/research/2026-10-03-boar-skinned-model.md` section 7(d) records both runs.

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
   clean past its end. *Verify:* "the clip does not chatter" (note: *the measured yaw storm now makes
   2 clip change(s)*) and "the freeze window is at least one frame of the clip wide".

8. **Every asset id was loaded back before it was written down.** The ten animation ids can only be
   made inside Studio; the Director published them (`ESCALATE.md`, closed), and reading each back
   found **every clip length one frame too long** and **all ten published `Loop = true`**.
   *Verify:* `Assets.AssetRow.clipSeconds`, `BoarAssetsBoot`'s drift warning, and
   "every clip the boar can play has a published asset id" (note: *worst clip-length drift 0.0000 s*).
   `play` writes `track.Looped` immediately before every `Play`.

## Screenshots (rule 5) -- what they actually show, looked at by me

Unchanged from round 1; this round's fix is invisible, and the Director confirmed no new look is
needed. Karen has signed off: *"looks good now"* (`PLAYTEST.md`).

- `.screenshots/20261003T120402Z-task115f-move3.png` -- two boars trotting away at ~7 studs, legs in
  **different phases of the stride**, feet on the ground, no tearing.
- `.screenshots/20261003T131632Z-task115fix-dead2.png` -- the carcass lying on its flank **on** the
  surface, head and snout on the ground with a tusk visible, the whole body above the ground.
- `.screenshots/20261003T133938Z-task115walk-before.png` and `...133941Z-task115walk-after.png` --
  the same carcass at the player's feet, then after 2.5 s of holding W into it: unmoved.
- `.screenshots/20261003T120313Z-task115e-carcass1.png` is kept deliberately: the **buried** boar
  Karen reported, only its legs above the surface, which my own earlier report misdescribed as "lying
  on its flank".

## What I could not verify

- **No spec can load a real animation.** `AnimationTrack.Length` is 0 without the network, which is
  why `shouldFreeze`, `clipFor`, `shouldAdjustRate`, `carcassIsStill` and `shouldAnchorCarcass` are
  pure functions with their own cases. That the clips really play, at the right rate, that a death
  freezes and holds, and that `rateWrites` stops growing, are LIVE measurements recorded in the
  research note.
- **The Fab Standard License grant was read through a web search**, not from `fab.com/eula`, which
  answers 403 to this machine.
- **A boar killed on a steep slope** could slide past the 0.25 s stillness window before anchoring;
  the 4 s backstop bounds it. Not reproduced -- the map is flat where boars run.
- **A multi-byte character split across a source slice** (`tools/studio_mcp.py`): the length
  comparison is fixed to bytes, so the message is no longer misleading, but the split itself is not
  handled. The one oversized file is ASCII; queued as 115a(a).

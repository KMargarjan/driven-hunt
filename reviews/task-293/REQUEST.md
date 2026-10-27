# Task 293 -- a shot deer stands after it dies

Task: 293
Round: 3
Base: 1c1408fc (main)
Code commit: 4c4fd70ae027ac91d39faca1a662c4e62d73cf55

Gate (full one-player run, clean tree, at the code commit):
`[harness] PASS: 34/34 checks @ 4c4fd70ae027ac91d39faca1a662c4e62d73cf55 (clean tree) scope=all`
`[harness2]`: N/A -- no `TWO_PLAYER_PATHS` path is touched (`src/server/Boar/`, `tests/server/`).
Round 3 authorised by the Director (inside MAX_ROUNDS 3); the round-2 finding was real.

## PLAN (core quality protocol)
(a) REAL LIFE: a deer shot through the chest collapses and stays down. The repo rule it rests on is
    task 150: exactly one thing lays an animal down.
(b) MEASURED (DEV Play, the real published rigs, live Instance properties only --
    `<runs-dir>/293-lab.luau`, `293-lab3.luau`, `293-tail.luau`): held while playing, `Death_L` lays
    every deer kind flat -- drawn height (lowest to highest `Bone.TransformedWorldCFrame`) hind
    **4.94 -> 1.03**, stag **5.66 -> 1.30**, calf **3.30 -> 1.32**. The instant that non-looped track
    runs PAST its end it STOPS and the hind draws **4.94 again, its standing bind pose**.
(c) TARGET: after an overrun frame a dead deer still draws inside the lying band of (b) --
    1.03-1.55 studs, every frame from `length - 0.20` to `length - 0.02` (`293-tail.luau`) -- and
    never the 3.30-5.66 standing band. Threshold: <= 2.0 lying, >= 3.3 standing.
(d) LEVER: `Body.stepVisual`'s hold. The round-2 code is at `f53dc9bd`; its rule
    `return not playing or weight < 0.5` is the line this round changes, with
    `handle.heldAt = nil` added where `play` clears `handle.heldClip`.
(e) HOW MEASURED AFTER: the same instrument -- `<runs-dir>/293-after.luau`, below.

## STEP 2/3 -- the after, same instrument (DEV ONLY, the Forest Test kills are the Director's)
`<runs-dir>/293-after.luau`, one run, 13:04 UTC: the real rig, the real clip, an overrun frame
forced, then the SHIPPED pure rules asked what to do about exactly that state:
```
hind len=1.167 | OVERRUN playing=false w=0.03 drawnSpan=4.84 (bind 4.94) | rule says rehold=true at=1.137 | AFTER drawnSpan=1.05 playing=true w=1.00
stag len=1.167 | OVERRUN playing=false w=0.00 drawnSpan=5.66 (bind 5.66) | rule says rehold=true at=1.137 | AFTER drawnSpan=1.36 playing=true w=1.00
```
Standing 4.84 / 5.66 before, lying **1.05 / 1.36** after -- inside (c). The decision is
`Boar.shouldRehold` and `Boar.holdFrame` themselves, not a copy of their rules.

## What changed this round (the four points of the escalation)
1. **The END as well as the weight.** `Body.shouldRehold` now takes `timePosition` and `length`: a
   STOPPED track is put back; a track that is merely at low weight must ALSO be at its end
   (`timePosition >= length - HOLD_EPSILON`). `play` starts every clip with `FADE_SECONDS` 0.15, so
   the boar paddle is at `WeightCurrent` ~0.11 one Heartbeat in -- round 2's pinned paddle.
2. **`heldAt` never crosses a clip change.** `play` clears it beside `heldClip`, so the fall's
   1.178 s can never be applied to the 4.0 s paddle. Greps checked (L-030): its only other readers
   are the freeze (which writes it) and the twitch scrub, and both run only while `heldClip` is set.
3. **`length <= 0` refused** -- "not loaded yet", never "already over"; frame 0 of the fall is the
   animal standing.
4. **Three cases drive the real `Body.stepVisual` THROUGH `play`**, on a stub track: the deer
   fall-only overrun, the boar fall -> paddle fade-in plus the paddle's own later overrun, and the
   live / box-toppled animals that must be left alone.

## Claims
1. **Round 2's finding is fixed and tested where it lives.** Verify: the boar case drives the
   handover, then three mid-fade ticks, and asserts `plays[paddle] == 1`, `reholds == 0`,
   `paddleTrack.Speed == 1` (it ADVANCES), `handle.heldAt == nil`.
2. **The paddle, when IT overruns, goes back on its OWN end frame**, never the fall's. Verify: the
   same case ends with `TimePosition` near `paddleLen - HOLD_EPSILON` and `> fallLen`.
3. **The deer overrun is put back on a frame that draws a LYING deer.** Verify: the deer case
   asserts `TimePosition` near `len - HOLD_EPSILON` and `>= len - 0.20`, the window `293-tail.luau`
   measured at 1.03-1.20 studs; and the live `293-after.luau` numbers above.
4. **FAIL FIRST at `f53dc9bd` (the boar case)**, round-2 src with this round's specs:
   `TestService: ... Expected value "nil" (nil), got "1.178" (number) instead` /
   `ServerStorage.Tests.boar_model.spec:1354` (that line is `expect(handle.heldAt).to.equal(nil)`) /
   `[tests:server] FAIL: 2412 passed, 2 failed, 0 skipped, 2 errors, 75 spec files` /
   `[harness] FAIL: 32/34 checks @ 4c4fd70a... (DIRTY TREE (1 paths) - NOT valid evidence) scope=all`.
   (The pure case also errors there, at `boar_model.spec:1208`: round 2's rule has six parameters.)
5. **FAIL FIRST at main (the deer case)**, main src with this round's specs:
   `TestService: ServerStorage.Tests.boar_model.spec:1274: attempt to call a nil value` -- line 1274
   is the deer case's `Boar.stepVisual(handle, 1 / 60, { speed = 0 }, deer)` -- plus 1208, 1350 and
   1403 / `[tests:server] FAIL: 2410 passed, 4 failed, 0 skipped, 4 errors, 75 spec files` /
   `[harness] FAIL: 32/34 checks @ 4c4fd70a... (DIRTY TREE (2 paths) - NOT valid evidence) scope=all`.
6. **It writes only when the invariant is broken, and is bounded.** Verify: two property reads per
   carcass per step; `MODEL.REHOLD_LIMIT = 3`; the spec asserts three consecutive deer ticks write
   once. The counter is CUMULATIVE per carcass (round 2, note 3) and the comments now say so.
7. **One rule for every species** (L-010/L-031). Verify: no kind or species in `shouldRehold`,
   `holdFrame` or the block; the clip names come from `Body.deathClips(config)`, and the deer case
   gets its config from `Boar.speciesConfig("reddeer", CONFIG)`.
8. **The boar case models the live world rather than the manifest.** Verify: it clones
   `MODEL.ANIMATION_IDS` and publishes the two death ids (the `boar_calm.spec` idiom), because
   `Boar.CONFIG` alone answers `hasClip(deathPaddleLeft) == false` -- the real ids are wired by
   `BoarAssetsBoot`.
9. **Nothing else changed.** `git diff --name-only 1c1408fc..4c4fd70a` is
   `src/server/Boar/Body.luau`, `src/server/Boar/init.luau`, `tests/server/boar_model.spec.luau`.
10. **No red line is called a flake.** The gate run is 34/34 with no FAIL line at all.

## What I could NOT verify
- **A carcass in a frame on Karen's path: NOT PROVEN by me.** No animal could be killed in DEV at
  all (`<runs-dir>/293-hunt.luau`: six rounds at a staged 18-22 studs left `Carcass = nil` and no
  hit in the console) -- its own `ESCALATE.md` entry, written at the hard stop in round 2. The
  dispatch assigns the Forest Test kills to the Director; they must include a BOAR as well as deer,
  because round 2's regression was boar-only. **Route for that session (rule I):** start Play, then
  `python ftplay.py server lobby-go.luau` from `<runs-dir>` to enrol, and
  `python ftplay.py server 264-stage-deer.luau` to bring the drive's deer onto the road in front of
  the stand; `<runs-dir>/293-pose.luau` reads every carcass's DRAWN span (lying <= 2.0, standing
  >= 3.3 for a deer) and `293-bones.luau` the same with per-bone detail.
- The `293-after.luau` numbers are DEV ONLY and come from a rig the probe built; the shipped rules
  made the decision, but no player saw it.
- CI on the pushed branch: not readable from this session (no `gh` auth here). Local equivalents
  pass: `stylua --check src tests`, `selene src`, `selene --config tests/selene.toml tests`,
  `rojo build`, `privacy_scan scan`, `studio_mcp selftest`, `agents selftest`.

## Answered flags
- ANSWERED: L-133 -- every pose reading was taken on a live, playing track, several frames per kind
  (`293-tail.luau`: seven tail frames for hind, stag, calf, boar; `293-after.luau`: two kinds,
  before and after). No instrument anchored a live animal or destroyed its Animator: the lab builds
  its own rig from the published template.
- ANSWERED: ROUTE -- kills were attempted only through `FireRequest:FireServer`, never a screen
  point; none landed, and the route for the Director's proof is named above.
- ANSWERED: L-104 -- one code path for both places: `Body.collapse` / `Body.stepVisual`, reached
  through `Boar.newRuntime`, whose only callers are `MatchBoot.server.luau` (DEV) and
  `ForestTestBoot.server.luau` (the Forest Test). Checked by grep; neither replaces `Body`.
- ANSWERED: L-026 -- live Instance properties only. `293-after.luau` requires `Boar` for PURE
  functions (`shouldRehold`, `holdFrame`, `speciesConfig`), which a fresh module copy answers
  identically; no module state is read.
- ANSWERED: L-030 -- grepped every read of `heldAt` and `heldClip` in `src/` and `tests/` before
  committing (point 2 above): the freeze writes both, the twitch scrub reads both and only runs
  while `heldClip` is set, and `Runtime:animationOf` publishes `heldClip`.
- ANSWERED: L-136 -- nothing is called a flake: the gate run has no FAIL line.
- ANSWERED: L-010/L-031 -- one shared invariant, no species in its inputs (claim 7).
- ANSWERED: L-029 -- reconciled on a tick, not on the death event.
- ANSWERED: L-033 -- one kill is not proof; the Director's proof should be several, deer and boar.
- ANSWERED: L-020 -- no bone or Motor6D CFrame is written; only `AnimationTrack` properties.

# Task 313: solo on the whole range

Task: 313
Round: 1
Base: c818d374ce4a4be40a2997889b8c305ce1a6d30c (main)
Code commit: 4118900997bfb0c02b97c5c78af1f8b9c35811b3

```
[harness] PASS: 34/34 checks @ 4118900997bfb0c02b97c5c78af1f8b9c35811b3 (clean tree) scope=all
```

**The `[harness2]` line is MISSING and that is an open NEEDS KAREN, not an omission.** This change
puts `src/client/Range/` into `TWO_PLAYER_PATHS` on purpose (L-158: a per-player PICTURE is exactly
what one client cannot evidence), so `needs_two_player` answers
`['src/client/Range/Solo.luau', 'tests/client/range_solo.spec.luau']`. `test2` was run twice and
produced nothing both times: it needs a Studio click StudioMCP cannot make, and it also fails
*"One Studio instance before the test starts"* while Karen's `Driven Hunt Forest Test` Studio is
open, which is hers and was not closed. See `ESCALATE.md`, 2026-10-30. A `--scope auto` run does not
get round it either: this change edits `tools/studio_mcp.py`, which resolves to `all`, so the run is
tagged `scope=all` and the two-player line is asked for again (measured, not assumed).

Karen, 2026-10-30: *"when I click E it will make that I am alone in all shooting range and then we
can test all way running waling ect animal, now is to short for one specific stand"*.
Design: `docs/design/shooting-range-lobby.md` (Architect PASS, `reviews/task-313/ARCH_RESULT.md`),
to `reviews/task-313/BRIEF.md`.

## What changed

The animal's crossing was his station's own 36-stud window -- 1.5 s at run. It becomes a SPAN
derived per station and per lane, 71.07 to 156 studs (2.96 to 6.50 s at run), and while a man is at
a station every other player's body is hidden for him. All of it behind `RANGE_SOLO`, born OFF.

## Claims

1. **The span is the intersection of three bounds, each off `LAYOUT`, none typed.**
   `RangeData.sightSpanFor` intersects the backstop (`backstopSpanFor` = the berm's span less its
   two tapered shoulders, projected back along the lane), the shooter's own bay (`bayHalfSlope`, the
   hut's downrange posts) and the apron (`corridorSpan` less one `APRON_STUDS` each end), then pulls
   each edge in by `LAYOUT.SIGHT.silhouetteStuds`.
   *Verify:* `range.spec`, *"derives the span from the built earth, his own bay and the apron"* --
   it recomputes the answer from the same dials for 6 stations x 3 lanes and then checks the design's
   own six numbers (71.07 / 80.67 / 109.47 and 98.11 / 115.96 / 156) to 0.01 studs.

2. **`wide = false` is bit-for-bit the shipped game**, so the flag-off branch is the one Karen has
   already played. `sightSpanFor(..., false)` IS `windowSpanFor`'s answer and `laneEnds` now
   delegates to `laneEndsFor(..., false)`, so there is one arithmetic and not two.
   *Verify:* `range.spec`, *"is bit-for-bit the shipped window with the flag off"* -- asserted
   against the SHIPPED functions for every station, lane and leg, and for `nil` as well as `false`.

3. **ONE predicate still answers "where may his animal be".** `Range.maskFor` (the picture),
   `Range.ignoredFor` (the shot's door) and `timeWindow` (the crossing the board prints) all read
   `RangeData.sightSpanFor` and derive no copy. `timeWindow` previously compared against
   `laneCentre.X +- WINDOW_STUDS/2`; it now reads the span through `RangeData.inWindow`.
   *Verify:* `src/server/Range/init.luau` -- the three call sites; there is no other reader.

4. **The ISSF paces did not move, and that regression is the reason the constant was split.**
   `WINDOW_STUDS` = 36 is now read for pace purposes ONLY through `RangeData.paceWindowStuds`, whose
   only caller is `paceSpeedFor`. Had the masking window fed it, `slow` would have become 39.2
   studs/s -- faster than `Boar.CONFIG.PACE.SPRINT_SPEED` 38.
   *Verify:* `range.spec`, *"keeps the ISSF paces on the ISSF window while the span is wide"*:
   7.20 and 14.40 exactly, the 5.0 / 2.5 s identity, and the three run crossings 2.96 / 6.50 / 1.50.

5. **T6 re-swept, 36 combinations, and the realised worst angle is 28.07 degrees.**
   Every aim point on the silhouette at the span's edge, from both firing positions, at all six
   stations and all three lanes, crosses `bermCrestFaceZ` inside `backstopSpanFor`.
   **A CORRECTION TO THE DESIGN, raised in the round that writes the fix:** section 3.3 tabulates
   **39.81** degrees for station 1 at 107 studs, taking the aim point as +89.17. It is not reachable
   -- the bay bound cuts that span at +-53.07, so the widest aim point is +57.07 and the angle is
   28.07. 39.81 is the BOUND (`atan(backstopSlope)`) and 28.07 is the FACT (`atan(bayHalfSlope)`);
   the design is conservative in the safe direction. Both are asserted.
   *Verify:* `range.spec`, *"lands every widest shot inside the backstop, from both firing
   positions"* -- `swept == 36`, and the `TestKit.note` line `range 313: T6 swept 36 combinations`.

6. **The backstop bound is load-bearing and the case proves it by deletion.** With
   `BERM.shoulderStuds` set to 0 the span at station 3 / 107 studs widens on the LOW side and its
   worst ray lands on the shoulder, outside the full-height earth; the shipped span's does not.
   (At station 1 the bay binds at every lane, which is why a case there would prove nothing -- that
   is stated in the case.)
   *Verify:* `range.spec`, *"fails the sweep when the backstop is not trimmed by the shoulders"*.

7. **A NEW OWNER for the second picture, disjoint by code and not by comment.**
   `src/client/Range/Solo.luau` is the one writer of `LocalTransparencyModifier` on parts under
   ANOTHER player's Character. It refuses the local character (`Camera.Rig`'s set) and refuses
   anything `RangeData.isTarget` answers true for (`Range.Mask`'s set -- the FOLDER wins over the
   character), counting both as `refused`. `Mask.luau` is not modified at all.
   *Verify:* `range_solo.spec`, the `the two pictures partition the one property` group: a character
   model parented INTO the targets folder is refused by `Solo` and written by `Mask`.

8. **The client judges no isolation and reads no flag.** The server resolves `RANGE_SOLO` once
   (`Range.SOLO_VIEW`), passes it inward as `seams.solo` -> `state.solo` -> the `wide` argument, and
   publishes `record.alone`. `RangeRequest` gains nothing.
   *Verify:* `src/server/Range/init.luau` (`Range.SOLO_VIEW`, `maskFor`'s third return) and
   `src/client/RangeBoot.client.luau` (`Solo.setAlone(record.alone == true)`).

9. **`ignoredFor` still gives a shot exactly one animal, and the cap cannot bite.** The five that
   are not his are excluded unconditionally, so a wider span can only make HIS OWN hittable more of
   the time. No new provider, no new cast, no new ray.
   *Verify:* `src/server/Range/init.luau` `Range.ignoredFor` -- the `spot ~= mine` branch is
   untouched; only the span's source changed.

10. **A staleness defect closed, because the feature needs it closed.** Nothing published when a man
    walked from one mat to another, so he kept the old station's `mine` and window. `occupancy` now
    compares each watcher's measured station with the previous tick's (`state.spotOf`) and marks the
    mask dirty, counted as `stats().spanPushes`. The table drops a player who left.
    *Verify:* `src/server/Range/init.luau` `occupancy`.

## What I could NOT verify

- **NOTHING HAS BEEN SEEN ON A SCREEN.** No frame exists of the wide crossing, of two clients each
  seeing only his own animal, or of another player being hidden. The CLICK PROOF and the FOREST TEST
  PROOF the dispatch asked for were **not taken**: Karen's Forest Test was in a Play session when
  this session reached them and the dispatch's own rule is to stop rather than disturb her. Every
  claim above is arithmetic or a spec. `docs/design/shooting-range-lobby.md` section 15 items 3-9
  stay UNVERIFIED, and item 3 in particular -- that the property hides another player's whole
  character, accessories and held Tool -- has a shipped fallback but no picture.
- **`[harness2]`**: see the header.
- **One defect in this area was NOT fixed and is not mine** (`playtest/range-v3/report.md`, "Seen by
  accident"): stepping off a mat strips all four guns and rearms the wrong one. The design's section
  14.5 walks the six symbols of that path and this change touches none of them -- but a man tracking
  an animal across 156 studs is MORE likely to meet it, so it should land before this flag is lit.

ANSWERED: L-136 the named flake `weapon_shot.spec.luau:1490` did not fire in any of the four runs on
this branch; no FAIL line is claimed as known or flaky anywhere in this request.
ANSWERED: L-127 every item above is MET as arithmetic or a spec and NOT PROVEN ON SCREEN, said once
per item in "What I could NOT verify" rather than implied.
ANSWERED: L-162 there is no live proof in this request, so none is mis-dated; the one harness line is
at the code commit named in the header.
ANSWERED: Rule 5 no visual claim is made, because no frame was taken. The only frames looked at this
session were of Studio's own windows, and they are evidence for `ESCALATE.md`, not for the game.
ANSWERED: L-158 `src/client/Range/` and both range client specs were added to `TWO_PLAYER_PATHS` in
the same commit as the code, which is why this request has to ask for a run nobody could make.
ANSWERED: L-154 the design names a concrete owner module, `src/client/Range/Solo.luau`, not "the
Mask", and the partition is asserted in `range_solo.spec` rather than described.
ANSWERED: L-033/L-034 no two-client run exists at all, so no single run is being offered as proof of
a per-player claim.

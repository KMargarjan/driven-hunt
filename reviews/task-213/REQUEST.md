# Task 213 -- the truck pads come back to their trucks

Task: 213
Round: 1
Base: 10444c8 (main)
Code commit: c4808aa93a04642b124252d9ae3a062d8d622b70

```
[harness] PASS: 33/33 checks @ c4808aa93a04642b124252d9ae3a062d8d622b70 (clean tree) scope=all
```

`test2` is **N/A**: no path this task touches is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The four
files are `src/shared/Lobby/init.luau`, `src/server/Lobby/Build.luau`, `tests/server/lobby.spec.luau`
and `tests/server/lobby_live.spec.luau` -- the lobby, which one player can evidence end to end, and
the smoke run in claim 10 does.

Only paperwork has landed since the code commit: `git diff --name-only c4808aa..HEAD` is `TASKS.md`
and this file.

## What changed

KAREN, 2026-10-19 ~09:00, verbatim: *"truck is good, now can make pods closer to truck"*.

Task 209 moved the truck 8 studs south and the pad 8 studs north, which left a truck's whole length
of gravel between the rectangle she stands on and the truck she is getting into. Her truck's row
does not move here (she says it is good); the pad's does, and it is **one config row**. The move put
pad 4's corner in the yard's old east hill, so a second, measured defect is fixed with it.

Frames and probe scripts: `<runs-dir>/t213/` (git-ignored, outside the repo).

## Claims

1. **Her defect was reproduced and MEASURED on her own path before a line was written (rule H).**
   In the live Forest Test, over every world-axis corner of every `BasePart` of each built truck,
   counted only over the parts standing in that pad's own x band (L-024, L-086: the pair's own drawn
   footprint, never a pivot and never an object-space box), the clear gap from each pad's near edge
   to its truck was **18.74 / 18.77 / 18.77 / 18.41**.
   *Verify:* `t213/before-approach.png`, `before-karen.png`, `before-row.png`, `before-padcam.png`
   (task 209's own four cameras, unchanged, at eye height) and `t213/p1_measure.py`.

2. **One row moves, and it is the pad's.** `TRUCK.PAD_BEHIND_STUDS` 20 -> 5 in
   `Lobby.CONFIG.TRUCK`. `TRUCK.BACK_STUDS` is untouched at 8, so the trucks, the bays, the yard's x
   and the billboards' x are exactly where task 209 left them.
   *Verify:* the `CONFIG.TRUCK` rows and their comment; `Pads.centreFor` is unchanged.

3. **The gap is now 3.74 / 3.77 / 3.77 / 3.41, measured the same way, at every bay (L-093).** Bay 4
   is the one the hill tilts (its drawn box is 18.71 long against the nominal 18.46) and it is the
   worst of the four, which is why the band has room under it.
   *Verify:* `t213/p1_measure.py` run at `after`; `t213/final-padcam.png`, `final-approach.png`,
   `final-row.png`, `final-karen.png` -- the same four cameras as claim 1.

4. **The band is DATA, because the gap is emergent and nothing owned it.**
   `TRUCK.PAD_GAP_STUDS = { MIN = 2, MAX = 4 }`: three rows make the gap (`PAD_BEHIND_STUDS`,
   `BACK_STUDS`, `MODEL.LENGTH_STUDS`), so a retune of any one of them could walk it out of
   *"closer"* with nothing to catch it. `MIN > 0` is what says the pad and the truck never share a
   stud. The new case replaces task 209's *"at least two truck-widths"*, which was the same sentence
   with her older number in it.
   *Verify:* `tests/server/lobby.spec.luau`, *"leaves one short step -- not a walk -- between every
   pad and its own truck (task 213)"*, which asserts the band itself before measuring against it.

5. **Nothing overlaps, and that was measured over the whole of `Workspace`, not reasoned.** Every
   `BasePart` in the place was boxed in world space and tested against each pad's rectangle: the
   only things rising above a pad's top inside its own rectangle are that pad's own four rim bars.
   No truck, no lodge, no porch, no tree, no fence. The lateral gaps between pads are still
   **8.00 / 8.00 / 8.00** (x did not move).
   *Verify:* the "things standing in a pad rectangle" probe in `t213/p1_measure.py`, before and
   after; `tests/server/lobby.spec.luau`, *"puts one pad behind each bay..."*, which now also holds
   pad 1's west face clear of the lodge's gable overhang and of the porch -- a NEW bound, because
   the pads sit in the porch's z band for the first time, asserted from the same `CONFIG` rows
   `Build`'s roof and porch are drawn from.

6. **The move would have shipped a buried pad, and it was found by measuring and then looked at
   (rule E).** `Build.pad` asked `world.groundAt` at the pad's CENTRE only. 81 rays per pad say the
   yard is dead flat under pads 1-3 (spread 0.000) and that the last of the old east hill rises
   **0.936 studs** across pad 4's new south-east corner, so **8 of its 81 samples came out ABOVE the
   deck's top**: a corner underground and a broken rim.
   *Verify:* `t213/p5_slope.py` and `p4_oldvsnew.py` (the same rectangle sampled where it used to
   be: the old position reads -0.080 everywhere, so the hill is what the move walked into);
   `t213/buried-pad4corner.png` and `buried-pad4east.png`, both from a player's eye at the measured
   worst spot.

7. **So the ground is asked at nine places and the highest wins** -- task 196's own finding
   (*"WHY ONE SAMPLE IS NOT ENOUGH"*) on a third surface, after task 182's and task 186's. The cost
   is stated on the code rather than hidden: a flat slab on sloping ground cannot be flush at both
   ends, and pad 4's low edge now stands **0.351 studs** proud. Measured after the fix: the worst
   ground under pad 4 is 0.144 studs BELOW its top, and pads 1-3 are unmoved.
   *Verify:* `Build.pad`'s `groundAt` block; `t213/p3_ground.py` run at `final`;
   `t213/final-pad4corner.png` and `final-pad4east.png`, the same two cameras as claim 6.

8. **Both halves of that are specified.** `tests/server/lobby_live.spec.luau`, *"lays a pad on the
   HIGHEST ground under it, not the ground at its middle (task 213)"*, builds a world whose ground is
   flat except one corner of the last pad and asserts that pad's top is the bump plus the lift AND
   that the other three are not dragged up with it. `tests/server/lobby.spec.luau`'s *"sits each pad
   on the ground that is REALLY there"* pinned ONE probe per pad and FAILED at the first harness run
   (`expected 26, got 77`); it now asserts the nine probes' COVERAGE -- all nine on that pad's own
   rectangle, its four corners among them, its centre one of them -- rather than a count.

9. **The billboards got more readable, not less, and that is a measurement.** A ray from her
   approach eye and from the porch to each board's own anchor, taken twice -- to where the boards are
   now and to where task 209 had them (+15z, the trucks having not moved): from both eyes all four
   are **CLEAR** now, where pads 1 and 2 were **BLOCKED BY THE LODGE** at the 209 positions. From the
   south camera that stands beside truck 1, pads 2-4 are blocked by truck 1's body both before and
   after -- unchanged, and it is the 17-stud bay pitch task 209 already recorded as a field question.
   *Verify:* `t213/p8_bbcompare.py`; `t213/final-approach.png` against `before-approach.png`.

10. **The face-the-truck turn still aims right, and the lobby still works end to end.** The truck is
    still south of its pad (the new case asserts the tail is south of the near edge), so `Hud`'s one
    `faceTowards` call on `lobbyData.truckPosition` -- untouched -- still turns a man on the pad
    toward a truck 19 studs away. The smoke run walked a player onto `TruckSpot`, through the pick
    and into the drive:

    ```
    lobby=[lobby gunBefore=false] gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 | waves=9
    position @15s=[ground ...:ok hp=100 y=143.2] @end=[ground ...:ok hp=100 y=143.2]
    SMOKE PASS
    ```

## What I could not verify

- **No spec holds the BUILT trucks to the band**, because the free truck model is not in the harness
  place: `lobby.spec` holds the arithmetic and the four built pairs are held by the live measurement
  in claims 1 and 3. Task 209's `CONFIG` comment claimed `lobby_live.spec` did hold them; that
  sentence is corrected in this task's comment rather than repeated.
- **Karen has not seen it.** She approved merging looks unseen (2026-10-17); the frames are hers to
  judge afterwards.
- **`docs/design/truck-pads.md` is now one task staler (L-071).** Sections 4, 4.1 and 5 still print
  `PAD_BEHIND_STUDS` 12, *"12 studs behind the tailgate"* and *"clear by >= 2.75"*, and section 4's
  `Pads.centreFor` listing knows nothing about the nine ground samples. It has been stale since task
  209 (escalated 2026-10-18) and the Builder does not write designs; the delta is in `TASKS.md` row
  213 for the next Architect run.
- **0.351 studs of air under pad 4's low edge is a real cost**, not a rounding: it is the half of
  the trade the frames in claim 7 show, and the alternative (tilting the deck onto the plane through
  its corners, as `settleOnGround` does for the truck) is a rotation this system owns nothing else
  for.

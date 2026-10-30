# Task 313: solo on the whole range

Task: 313
Round: 1
Base: c818d374ce4a4be40a2997889b8c305ce1a6d30c (main)
Code commit: 02b9dfc402f334e3b2f9d774279e2da8c52bedeb

```
[harness] PASS: 34/34 checks @ 02b9dfc402f334e3b2f9d774279e2da8c52bedeb (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 02b9dfc402f334e3b2f9d774279e2da8c52bedeb (clean tree)
```

**Director, 2026-10-30 ~14:00 UTC:** both lines above were run by the Director at `02b9dfc4`, which
differs from the Builder's tested commit `4118900` only in paperwork (`ESCALATE.md`, `TASKS.md`,
this file). The Forest Test Studio was closed for the run (Karen away; preflight #81), so the
`[harness2]` blocker in `ESCALATE.md` is cleared. The Builder's own line was
`[harness] PASS: 34/34 checks @ 4118900997bfb0c02b97c5c78af1f8b9c35811b3 (clean tree) scope=all`.
**Honest note: the first one-player run at `02b9dfc4` FAILED 32/34**, with one case:
`deer_hitbox.spec:682 calf: legs box 1 is unreachable by a flank ray`. The rerun right after
passed 34/34 (the line above). The Builder reported this same case failing 3/3 because of
`range_solo.spec` staging parts in Workspace, fixed at `fd60936d`; one failure in two runs at the
fixed head is therefore either a leftover of that interaction or a new intermittent. It is NOT
called the known flake. Reviewer: please judge whether `range_solo.spec` (or anything in this change)
can still put geometry in the deer hitbox spec's ray path.

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

11. **MEASURED LIVE, BOTH STATES, ON THE BOARD KAREN READS. `DEV ONLY`.**
    One Play session per state in the DEV place, same station (2), same lane (125 studs), same pace
    (trot), the flag switched by override with no commit, and a real `E` keypress through
    `298key.ps1` after a focusing click -- so the menu and the board are the shipped path and not a
    probe. The board's own line, read off the two frames:

    | `RANGE_SOLO` | the board's line | predicted |
    |---|---|---|
    | **off** | `PACE TROT pace 11.0 studs/s issued 11.0 studs/s crossing 3.25 s` | 36 / 11 = 3.27 s |
    | **on** | `PACE TROT pace 11.0 studs/s issued 11.0 studs/s crossing 9.10 s` | 100.34 / 11 = 9.12 s |

    **2.80x longer, and both within 0.6 % of the span arithmetic.** 100.34 studs is this design's
    own number for station 2 at the 125 lane.

    And the LEG, sampled independently as an instance fact (`313-sample.py` reads the trunk's X off
    `Workspace.RangeTargets` ~15 times a second; the same instrument for both states):

    | `RANGE_SOLO` | measured leg | predicted leg |
    |---|---|---|
    | **off** | 1188.30 .. 1259.37 = **71.07 studs** | 76 studs, less `LINE.ARRIVE_STUDS` at each end |
    | **on** (run) | 1166.63 .. 1308.10 = **141.47 studs** | 140.33 studs |

    **1.99x.** The shortfall at each end in the OFF row is the brain stopping inside
    `Boar.CONFIG.LINE.ARRIVE_STUDS`, which `range.spec`'s own header records as the reason a lane
    case measures the ordered lane and not the spec's idea of walking.

    *Verify:* the frames `313-board-off.png` and `313-board-run.png` under `<runs-dir>`, and the two
    sampler runs printed in the task report. **I opened and read all four frames.**
    One further board reading, from the two-player session at the same station and pace, said
    `crossing 10.60 s` where this one said 9.10 -- both far above the 3.25 of the OFF state, but
    10.60 is 16 % above the 9.12 the span predicts, outside `CROSSING_TOLERANCE` 10 %. Reported
    because it was read, not averaged away: see the third bullet below.

12. **TWO CLIENTS, TWO STATIONS, WITH THE KNOWN-BAD CONTROL. `DEV ONLY`.**
    A real 2-player local test (Studio's own Server-and-Clients, player count 2, started by a real
    `F7`), Player1 staged on station 2 and Player2 on station 4, a real `E` on each client window
    (`313-clientkey.ps1`: focus that process, click its viewport, send `E` with its scan code), and
    then the same probe run on EACH client. The probe reads `LocalTransparencyModifier` straight off
    the parts -- an INSTANCE fact -- because this channel hands a probe a FRESH copy of
    `Range.Mask`/`Range.Solo` and not the one `RangeBoot` steps, so a live `stats()` read would mean
    nothing (`range_mask.spec`'s own live/starter distinction).

    | with `RANGE_SOLO` | on Player1's client | on Player2's client |
    |---|---|---|
    | **ON** | his Boar1 **0.00 shown**; Boar2 1.00 hidden; **Player2: 21 parts, 21 at modifier 1, mean 1.00** | Boar1 1.00 hidden; his Boar2 1.00 (it was at x=1341, outside his span 1209.3..1325.3); **Player1: 20 parts, 20 at modifier 1, mean 1.00** |
    | **OFF** (control) | his Boar1 **0.00 shown**; Boar2 1.00 hidden; **Player2: 21 parts, 0 at modifier 1, mean 0.00** | Boar1 1.00 hidden; his Boar2 **0.00 shown**; **Player1: 20 parts, 0 at modifier 1, mean 0.00** |

    **The control is what makes this a proof rather than an observation.** The ONLY line that moves
    between the two states is the OTHER player's: 1.00 -> 0.00. Each man's OWN body reads
    `mean 1.00` in BOTH states, because `Camera.Rig` hides it in first person either way -- so the
    control separates `Solo`'s set from `Rig`'s set live, which is exactly the partition claim 7
    makes, and it fails if `Solo` is not the thing doing the hiding.

    The per-animal mask is unchanged by the flag in both rows (each man sees his own and not the
    other's), which is task 306's behaviour and is what should happen.

    The server also printed Player1's span live as `1186.3..1286.7` -- the design's
    [1186.33, 1286.67] for station 2 at the 125 lane, to 0.04 studs.

## What I could NOT verify

- **NOTHING WAS PROVED IN KAREN'S PLACE.** Both live proofs above are DEV. Her Forest Test was in a
  Play session when this session reached that step and the dispatch's own rule is to stop rather
  than disturb her, so the CLICK PROOF and the FOREST TEST PROOF as the dispatch specified them --
  in HER place, with her terrain and her anchor -- **were not taken**.
- **NO FRAME OF THE TWO-CLIENT PICTURE.** Claim 12 is numbers, not a picture: the frame I aimed for
  was spoiled because DEV's own drive re-roled Player1 to BEATER and moved him off the mat
  mid-capture, and I did not get a clean one before the session was cleaned up. The modifier
  readings were taken while both men were measured at their stations; the frame was not.
  `docs/design/shooting-range-lobby.md` section 15 item 3 -- that the property hides a character's
  ACCESSORIES and his held Tool specifically -- is covered by claim 12's part counts (21 and 20
  parts, all of them) but nobody has LOOKED at an invisible player, and item 4, the name tag over
  one, is untouched and unseen.
- **`Solo` was exercised only at `alone` true/false via the flag**, never at a man walking off the
  mat mid-session, which is `setAlone(false)`'s own path. `range_solo.spec` covers it; live, nobody
  has.
- **ONE READING I CANNOT EXPLAIN, AND IT IS NOT BEING EXPLAINED AWAY.** With the flag ON at pace
  **RUN**, the board read `crossing 9.13 s` where the span arithmetic says 100.34 / 24 = **4.18 s**.
  The TROT pair above matches to 0.2 %, and the sampler measured a full RUN leg in 6.21 s, so the
  animal was moving at the issued speed -- but the board's RUN crossing is roughly the TROT number.
  The likeliest reading is that `trial.lastCrossingSeconds` was still the previous pace's when the
  frame was taken, since the pace was changed and the target re-released moments before. **That is a
  guess and I did not confirm it.** The Reviewer should treat `crossing` after a pace change as
  unproven, and it belongs in `TASKS.md` either way.
- **`[harness2]`**: see the header.
- **One defect in this area was NOT fixed and is not mine** (`playtest/range-v3/report.md`, "Seen by
  accident"): stepping off a mat strips all four guns and rearms the wrong one. The design's section
  14.5 walks the six symbols of that path and this change touches none of them -- but a man tracking
  an animal across 156 studs is MORE likely to meet it, so it should land before this flag is lit.

ANSWERED: L-136 the named flake `weapon_shot.spec.luau:1490` did not fire in any of the four runs on
this branch; no FAIL line is claimed as known or flaky anywhere in this request.
ANSWERED: L-127 each item is marked MET on screen (claim 11, DEV), MET as arithmetic or a spec, or
NOT PROVEN, item by item, in "What I could NOT verify" rather than implied.
ANSWERED: L-162 every live reading above was taken on this branch at the code commit's tree -- the
working tree was clean and unchanged throughout (`git status` empty before and after), the flag was
an override and never a commit, and DEV was returned to no overrides at all.
ANSWERED: Rule 5 every visual claim cites a frame I opened and described: `313-board-off.png` and
`313-board-run.png` (the board's crossing line in both states), `313-span-east.png` (the shooter's
own bay, from his eye, with the span's far ground in view) and `313-E-span.png` (the menu a real `E`
opened). No claim is made about anything I did not look at.
ANSWERED: L-158 `src/client/Range/` and both range client specs were added to `TWO_PLAYER_PATHS` in
the same commit as the code, which is why this request has to ask for a run nobody could make.
ANSWERED: L-154 the design names a concrete owner module, `src/client/Range/Solo.luau`, not "the
Mask", and the partition is asserted in `range_solo.spec` rather than described.
ANSWERED: L-033/L-034 the two-client reading in claim 12 is ONE run per state, not two consecutive
clean ones, so it is offered as a measurement with a control and NOT as proof that the picture is
free of races; the standing bar is not met and is not claimed to be.

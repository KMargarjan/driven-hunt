# ESCALATE -- task 298-B6: round 2 returned FINDINGS, so I stop (the dispatch's rule). For the Director.

**Builder, 2026-10-28 01:50 UTC.** Branch `task-298b6-range-forest`, stacked on
`task-301-stand-provider` at `7905ca17`. Code commit `b8e83b32931afb1b99543e3f577a76bbfa50afd5`
(`[harness] PASS: 34/34 checks @ b8e83b32931afb1b99543e3f577a76bbfa50afd5 (clean tree) scope=all`).
The dispatch gave max 2 rounds and said FINDINGS on round 2 -> escalate and stop. Round 2 returned
two findings. **DO NOT MERGE AS IT STANDS: finding 1 is real, it is mine, and it makes the range in
Karen's place permanently empty.** Reviewer verdict: `reviews/task-298f/RESULT.md` (round 2).

## What is built and proven (DEV, 34/34, scope=all)
The measured forest row (`x 2650, z -3216, plate = false, downrange = -1, drawn = true`), the lane
direction as a DATA field threaded through one arithmetic (both arms entered by parameter), every
part standing on the ground under its OWN footprint against a SLOPED reader, the whole range inside
the measured rectangle, clear of the seven lobby rectangles, and `Match.lineUnsafeFor` refusing
nothing down the lane while still refusing a shot at the man. One root (`RangeBoot`), no
`ForestTestBoot` change, no second caller of `Range.installOver`.

## Finding 1, and it is correct
`Range.fieldFor` now writes `exitZ = anchor.Z - dir * FIELD_EXIT_BEHIND_STUDS`. **`Brain:_outcome`'s
despawn test is one-sided and not a parameter**: `position.Z <= field.exitZ` means "escaped". For the
forest row that gives `exitZ = -2816`, which is NORTH of the whole field, so the first ordered target
(the range orders on its first scan tick, and `LINE.ENABLED` is wired) is despawned as `escaped`
immediately, for ever. I broke the module's own invariant two lines above the change I made.

**The fix the Reviewer names, and I agree with it:** `exitZ = math.min(nearZ, farZ) -
Range.FIELD_EXIT_BEHIND_STUDS` -- bit-for-bit `-400` for DEV and `-3741` for the forest row, so the
exit is south of the whole field for BOTH rows because the predicate's direction is not a parameter.
It must be stated what that does to `Brain:_flee`'s heading (`Vector3.new(targetX, groundY, exitZ)`),
which in Karen's place then points a wounded target downrange into the berm rather than back over the
shooter -- that may be wanted at a range, but it is a decision, not a side effect to slip in.

## Finding 2, also correct
No case drives `RangeData.fieldFor` with a `downrange` argument, so the whole `dir` arm of `fieldFor`
could be deleted and the suite stays 34/34 -- which is exactly why the harness is green over a range
that cannot hold a target. The fix: drive the existing exit case with BOTH rows, and put an ORDERED
animal on the forest field through the real `Boar.newRuntime` (`range.spec` already builds one) and
assert it is still alive after a step, so the field and the predicate are asserted together.

## RESOLVED -- Director authorised round 3 (2026-10-28 01:50 UTC)

**Director authorised round 3** ("MAX_ROUNDS is 3; my brief's cap of 2 is lifted for this one
round"), and it PASSED: `reviews/task-298f/RESULT.md` line 1 is
`PASS (items 1, 2, 3, 4, 5, 6, 7, 8, 9 NOT PROVEN)` at code commit `73037ba1`
(`[harness] PASS: 34/34 checks @ 73037ba1 (clean tree) scope=all`). Both findings are fixed:
`exitZ = math.min(nearZ, farZ) - FIELD_EXIT_BEHIND_STUDS` (-400 DEV bit-for-bit, -3741 forest), and
the exit case now drives BOTH rows with an ORDERED target held alive on Karen's field through the
real `Boar.newRuntime`. Red first at `14d1bf98` (`range.spec:274`, `range.spec:2028`).
**Director's decision recorded in the code and in design 5:** a wounded target at a range flees
DOWNRANGE into the berm, which is wanted -- nothing runs back over the firing line.
**Still NOT PROVEN: nothing in Karen's place has been seen.** The live proof that the range HOLDS a
target there is the Director's, after this PASS.

## What was asked of the Director (now answered)
One authorised round 3 (`DIRECTOR_MAX_ROUNDS=3` is the cap; a round 3 needs this entry plus the
Director's word), or a new task. Both findings are small and the second is the one that matters:
without it the first can come back.

**And the Forest Test proof is still unrun and is yours** (the dispatch reserves it): the mat is at
**x 2650, z -3216**, facing **south (-z)**; the lane's middle is z -3341 and the berm z -3353. It is
worth doing only after finding 1 is fixed -- today the lane would be empty.

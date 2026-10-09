# Task 137 - a readable dot ring, and the rank guard proved by a test

Task: 137
Round: 1
Base: main (`6348728`)
Code commit: `db68e67a745e038539c2e224a377f496392e4ddd`

```
[harness] PASS: 33/33 checks @ db68e67a745e038539c2e224a377f496392e4ddd (clean tree) scope=all
```

`test2` is N/A: no path in `TWO_PLAYER_PATHS` is touched.

## Item 1 - the `body` dot ring was invisible

**MEASURED by the task-135 Reviewer and confirmed here:** `SILHOUETTE.body.tint` is (96, 84, 76) and
`BOAR_FILL` is (112, 99, 88) — about 16 of 255 per channel, which at one pixel is no ring at all. Of
the five zones task 135 called readable "at a glance", the one you could not read was `body`: the
fallback zone, the flank and the belly, which is most of an animal.

1. **The record is untouched and the pixel moved instead.** `Report.ringColor(tint, fill)` lifts a
   zone's tint until its **relative luminance** is at least `RING_MIN_LUMA` (0.22) from the fill it is
   drawn on, pushing toward whichever of white or black has the room. The tints stay mirrored from
   `Boar.CONFIG.ZONES` and the spec that fails when they drift is untouched — this is the same
   record/drawing split `SILHOUETTE` and `BOAR` already have. Rec. 709 coefficients, because what
   makes one pixel readable on a flat field is lightness, not hue distance.
2. **A tint already far enough away is returned untouched**, so chest and rear keep exactly the
   colours task 135 shipped. Measured: head 0.146 from the fill before, chest 0.232 (unchanged).
3. **The ring is 1.5 px rather than 1**, which is the other half of "clearly readable" at a 7-px dot.
4. **Load-bearing, measured.** With the lift disabled the suite reports
   `report_silhouette.spec:178: the head ring is 0.146 from the fill, under 0.22` and
   `784 passed, 0 failed` becomes `782 passed, 2 failed`. Restored; tree clean at the code commit.
5. **The three wrong comments 135a lists are fixed.** `buildSilhouette`'s header described "the four
   zone rectangles over it … Five `Frame`s" two lines above the loop that replaced it; "eleven parts"
   appeared twice for thirteen; and the `BOAR` block sat between `SILHOUETTE`'s doc comment and the
   `SILHOUETTE` table, so that paragraph read as documentation for `BOAR`. `SILHOUETTE` has its own
   header back and `BOAR` now follows the table it refers to.

## Item 2 - the rank guard is proved by a test, not by reading

6. **`Line.rejoinOrder` is the rule, pure, and the drive calls it.** Task 136's round-1 **blocking**
   finding — the rejoin must never demote a bolting sow — lived in `stepLines` with no test, so it
   could have been deleted green. It is now one function with both rules and the whole of why in its
   comment: a follower whose flight has just ended goes to the tail; **never the leader**.
7. **Six assertions in `forest_line.spec`**, including the two that are the finding: the leader
   coming back moves nothing at all, and the leader is *still* not moved when a follower is — so the
   guard cannot be satisfied by the "nothing moved" shortcut. Also: two returning followers keep
   their relative order, an animal still flying is not rejoining, and one that never flew never moves.
8. **Load-bearing, measured.** With `place > 1` removed the case fails
   `forest_line.spec:155 Expected "sow,b,c,d", got "b,c,d,sow"` — the sow demoted, which is exactly
   the shape that sent the file up her dead flight path. Restored; tree clean.

## The frame, and it shows one thing working and one thing wrong

`.screenshots/t137-dots.png` — three real animals from real shots in the Forest Test through the
`FireRequest` route, reloading after two, with a 4× copy of the first row beside it.

**The ring fix works, and you can see it.** In the 4× view the fatal diamond carries a clear pale
ring against the fill, and the small `body` dot near the snout is plainly readable — both were the
cases that could not be read before.

**AND THE FRAME SHOWS A DEFECT THIS TASK DID NOT CAUSE AND DID NOT FIX.** Two of the three `body`
dots are drawn **off the front of the animal**. The probe read them off the live panel:

```
rear u=0.759 v=0.532 fatal=true on=[Trunk,Haunch]      <- correct
body u=0.000 v=0.441 fatal=false on=[Snout]
body u=0.000 v=0.890 fatal=true  on=[]                 <- off the animal
body u=0.000 v=0.567 fatal=true  on=[]                 <- off the animal
```

**Every `body` dot in this run came back at u = exactly 0.000**, which is `Shape.dot`'s clamp
(`u = clamp(fz + 0.5, 0, 1)`) saturating at the nose end — for flank shots taken at 70 m, which
cannot be right. `rear` in the same run reports a sensible 0.759. So the suspicion is that the
impact position or the frame handed to `Shape.dot` is wrong for body hits specifically. It is
Karen-visible (a flank hit drawn in front of the animal's nose), it is outside this task's two
queued items and its 45-minute box, and it is queued as its own TASKS row with these numbers.

## What could not be verified

- **The spec does NOT go through `ForestTest.start(runtime, now)` with an injected runtime**, which
  is what the dispatch asked for, and here is why. Driving `stepLines` needs a line in `state.lines`,
  and the only way to make one is `ForestTest.releaseLine`, which **returns nil when
  `PathfindingService` cannot route** — it computes a path at the Forest Test's own coordinates, and
  the gate runs in **DEV**, where that geometry does not exist. A spec built that way would most
  likely be a spec that silently does nothing in the place it actually runs, which is worse than no
  spec. So I took the alternative the same Reviewer note offered — "extract the reorder as pure
  arithmetic the way `aimFor` was" — and the drive and the spec now share one implementation, so the
  rule cannot be proved in one place and different in the other. The REST of `stepLines` (the free
  window, the trail, the stations) still has no test; that part of 136a stands.
- **I did not re-measure the line traces.** `rejoinOrder` is the same rule the drive already ran,
  moved; no behaviour changed, and task 136's nine traces stand.
- **Standing rule A, Forest Test, 85 s:** the Tool in the CHARACTER at 15 s and at the end
  (`tool=true backpack=false` both), **0 fault lines in 22**, and four wave lines released at a walk
  and a trot, 1 and 2 lines per wave. The report panel is not opened by a plain Play, so the evidence
  that item 1 ran is the framed run above plus `report_silhouette.spec` in the gate.

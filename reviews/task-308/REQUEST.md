# Task 308 -- four range bugs the Playtester hit in Karen's place

Task: 308
Round: 1
Base: 46cbd787
Code commit: 9a6d8a35db918ea9e86e4500422795708727aead

```
[harness] PASS: 34/34 checks @ 9a6d8a35db918ea9e86e4500422795708727aead (clean tree) scope=all
```

`test2` is N/A: nothing here touches `TWO_PLAYER_PATHS` (no `src/*/Match/`, no `src/shared/Drive/`,
no `MatchBoot`, no `tests/client/Role.luau` and none of their specs). The range, the hit card, the
weapon's hit report and the boar runtime are all one-player evidence.

## What changed, and what was MEASURED first

Every bug below was reproduced in **Karen's Forest Test on `46cbd787`** (her build, served by the
karen worktree on :34873) before a line was written, and re-measured on this build in the same
place (the 294 worktree on :34874, Rojo panel photographed connected both times:
`<runs-dir>/playtest/check308/00-rojo-crop.png`).

1. **The empty menu.** BEFORE, standing on the mat with no request sent: the six option strips had
   **0, 0, 0, 0, 0, 0** children (client probe `b1.luau`). Only a request, a shot or a hit ever
   published. AFTER, walking onto the mat with a **real W** and sending nothing: **2, 4, 4, 4, 2, 1**
   = 17 chips, panel still shut; the first **real E** then drew the full menu
   (`01-first-E-full-menu.png` / `01-menu-crop.png`).
2. **E at the post.** BEFORE, 1.90 studs from the prompt, `Enabled=true`, `MaxActivationDistance=12`:
   turning the camera off the post fired `ProximityPromptService.PromptHidden` and **four real E
   presses gave `trig=0`** -- `InputBegan` counted all four with `gameProcessed=false`, and the
   engine answered none, because a hidden prompt does not answer its key. AFTER, same spot, same
   hidden prompt: **six real E presses, six toggles, `trig=0` throughout** (`02-E-crop.png`).
3. **The card's dot.** `Weapon.Rewind` reports a rewound impact where the SHOOTER DREW the animal;
   `HitLog` divided it down by the trunk's CFrame read flight-time-plus-replication later. The
   report now carries `targetCFrame` and `HitLog` projects in it. **This is NOT proven on screen and
   the bug is NOT fixed for the case Karen saw** -- see "What I could not verify".
4. **The miss gap.** `endPoint` is where the bullet came to REST, so a slug that passed in front of
   the nose reported the berm. BEFORE: the same **19.3 m** at two paces in two directions
   (check305c, check305d). AFTER, controlled misses aimed one body length into empty air:
   RUN **2.0 m ahead**, **--**, **2.0 m ahead**; WALK **0.2 m behind**, **2.0 m ahead**. Different
   shots, different numbers.

## Claims

1. `Range.look(player)` publishes the record and the lists to a man on the mat who has asked for
   nothing, and refuses one off it. `tests/server/range.spec.luau`, "sends the lists to a man
   standing on the mat who has asked for nothing": it asserts all five lists non-empty through a
   fake `RangeBoard.FireClient`, and that a man 400 studs away gets nothing.
2. `RangeBoot` calls it on the mat-entry EDGE (`matEdges`, in the Heartbeat it already runs), so the
   menu is full before the first E. Verify: the live reading above (0,0,0,0,0,0 -> 2,4,4,4,2,1 after
   a real W, with no request sent).
3. `RangePanel` binds `E` through `ContextActionService` while `near`, and unbinds off the spot, on
   `setEnabled(false)` and on `start`. `tests/client/range_panel.spec.luau`, "holds its own E while
   he is at the spot, and one press toggles once".
4. One press can never toggle twice: while the engine is showing its prompt the prompt has right of
   way and `onKeyPressed` stands down (`stats.swallowed`); while it is hidden the key is the door.
   Same spec case, both directions. `ProximityPromptService.PromptShown/Hidden` drive
   `setPromptShown`, which is also a parameter.
5. `Rewind.impact` stamps `frame = candidate.past` on the impact it returns, `Hits.group` carries
   the nearest impact's frame onto the report as `targetCFrame`, and `HitLog` projects both the
   card's dots and the trace line's local offset through it. `tests/server/hit_card.spec.luau`,
   "puts a nose hit at the nose even though the animal has travelled since": with the frame, u < 0.1;
   the same point with NO frame carried reads u > 0.9, which is the known-bad side of the case.
6. `Range.gapStuds` is the shot SEGMENT's closest approach to the animal, not `endPoint`'s X.
   `tests/server/range.spec.luau`: a shot whose line passes 1 stud ahead and ends 1.48 studs past
   reads 1.0, not 1.48; a shot that stopped in the animal reads 0; no muzzle, no gap. The two
   direction cases and the STAND case are unchanged.
7. The gap is measured against the animal where the shooter DREW it: `Range.onShotResolved` asks
   `boars.cframeAt(id, resolvedAtServerTime - viewWindowFor(player))`, wired in `RangeBoot` to the
   new `Runtime:cframeAtId`, which is `Runtime:cframeAt` looked up by id -- the same ring
   `Weapon.castWithRewind` judges against. It falls back to the present position when the ring
   cannot answer, which is what the read was before.
8. Nothing here touches the match, the drive, the tie or the teams.
9. `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both pass (rule G);
   no new spec file, so no `SCOPE_SPECS` entry is needed.
10. Money did not change across the whole live session: `$13500` on the mat before the first shot
    and `$13500` on the shot frames (`01-menu-crop.png`, `02-E-crop.png`).

## What I could not verify

- **BUG 3 IS NOT FIXED ON SCREEN, and I am not claiming it is.** On this build, in Karen's place, a
  real shot that the board scored as **HEAD 1** drew its dot at **u = 0.794** of the drawn
  silhouette -- on the hindquarter (`03-card-zoom.png`, measured off the picture's own pixels by
  `cardwatch.luau`, against that art's own `Silhouette` rectangle). It is better than check305d,
  where the dot was in the white space OFF the animal, but it is still the wrong end.
  **The measured reason:** the range's hits come through the ACCEPTED CLIENT CLAIM, and
  `Weapon.Validator.claimImpact` builds that impact as `partCFrame * claim.offset` -- the LIVE part
  CFrame, deliberately, "not where it was". Such an impact carries no `frame`, so the change above
  never reaches it. The change is still right for the rewound server impact and is not a regression
  (a nil `frame` is exactly the old behaviour), but the claim path needs its own answer.
  `ESCALATE.md` carries it.
- **No two-player run.** N/A by the path list, as above.
- The `MISS GAP --` the dispatch also names reproduced once in five controlled misses. It is
  `targetPositionOf` answering nil while the lane has no target (between a carcass and the next
  release), not the arithmetic. Not fixed in this task.

# Task 306 step B4 -- THE PACES: `slow` 5.0 s, `fast` 2.5 s and `mixed`, as TIMES

Task: 306d
Round: 1
Base: task-306b3-treestand @ 7664ce41
Code commit: 5b7bcf43d5ca80d02455117ae80a0fa11425352e

`[harness] PASS: 34/34 checks @ 5b7bcf43d5ca80d02455117ae80a0fa11425352e (clean tree) scope=all`

`test2`: **N/A.** No `TWO_PLAYER_PATHS` path is touched -- `src/shared/Range/`, `src/server/Range/`,
`src/client/Hud/RangePanel.luau` and their two specs are none of the match, the drive, the tie or the
teams (Director, 2026-10-03), and `src/client/Range/` is out of that list by the 2026-10-28 ratified
decision.

## PLAN (core-quality protocol step 0)

- **(a) REAL LIFE.** ISSF 50 m running target specifies a TIME across a 10 m window, not a speed:
  **5.0 s slow, 2.5 s fast**, and a `mixed` event that draws one of the two per run and does not
  announce it (`docs/research/2026-10-28-the-range-in-the-lobby.md`, sources A and B).
- **(b) MEASURED NOW.** Before this step the range offered four paces and the harness's own note
  read `range: predicted crossing of 36 studs -- walk 8.00 s, trot 3.27 s, run 1.50 s`. Nothing
  between 8.00 and 3.27, and nothing between 3.27 and 1.50.
- **(c) TARGET.** 5.00 s and 2.50 s across `WINDOW_STUDS` 36 -> **7.20 and 14.40 studs/s** (306a
  must-fix (b): NOT 7.14 / 14.29, which came from an unrounded 35.714-stud window).
- **(d) LEVER.** `src/shared/Range/init.luau` `Range.paceSpeedFor`, read by
  `src/server/Range/init.luau`'s `paceSpeed`, which is the only writer of
  `trial.speedStudsPerSecond` (`grep -n "speedStudsPerSecond =" src/server/Range/init.luau` ->
  `newTrial`, `setPace`, and the `mixed` redraw in `order`).
- **(e) HOW MEASURED AFTER.** The same instrument as (b): `Range.step`'s own window timer, read
  through `range.spec`'s crossing case and through the live board in DEV.

## What changed

`Range.WORD` gains `SLOW`/`FAST`/`MIXED`; `Range.CROSSING_SECONDS = { slow = 5.0, fast = 2.5 }` is
the only pair of numbers typed; `Range.crossingTargetSeconds`, `Range.mixedWord` and
`Range.paceSpeedFor` are new; `PACE_ORDER` is seven words with Karen's four first and unmoved. The
server routes every pace through `paceSpeedFor`, redraws `mixed` per LEG in `order`, and gains
`Range.setDistance` as the one writer of a live trial's lane. `RangePanel.buttonLayout` derives the
button pitch from the value count. The design's wrong gait sentence is corrected in the same commit.

## Claims, and how to verify each

1. **The two new paces are TIMES, and the crossing is exact by construction.**
   `range.spec` "derives ISSF's two paces from the WINDOW and its TIME": `paceSpeedFor("slow")`
   equals `WINDOW_STUDS / 5.0` equals 7.2, `fast` equals 14.4, and
   `crossingSeconds(WINDOW, paceSpeedFor(w))` equals 5.0 and 2.5 exactly. A 72-stud layout doubles
   both speeds and keeps both times -- the case that reddens a hard-coded 7.2 / 14.4.
2. **Karen's four still delegate to the animal owner.** Same case: `paceSpeedFor(w, LAYOUT, speedOf)`
   equals `speedOf(w)` for stand/walk/trot/run, and with no injected function Karen's four are 0
   while ISSF's two still answer (the window and the clock are the range's own).
3. **306a must-fix (a) is closed as a MEASUREMENT, not a sentence.** `range.spec` "lands both new
   paces inside ONE trot band" reads `Boar.CONFIG.MODEL.TROT_FROM` / `RUN_FROM` and asserts both
   7.20 and 14.40 fall between them. Harness note: `gait bands TROT_FROM 5.13 RUN_FROM 28.00 --
   slow 7.20 and fast 14.40 are BOTH trot (one clip, two rates)`. **The repo's `RUN_FROM` is 28.00,
   not the 21 the 306a note states**; the finding stands either way and is stronger at 28. Design
   section 6 now says this and section 14 item 11 carries the honest question for Karen.
4. **T5, measured for all six paces at a 36-stud window.** Harness note:
   `walk 7.93 s (predicted 8.00, 0.8 %) · slow 5.02 s (5.00, 0.3 %) · trot 3.27 s (3.27, 0.2 %) ·
   fast 2.57 s (2.50, 2.7 %) · run 1.40 s (1.50, 6.7 %)`. All inside TARGET 3's 10 %; slow, trot and
   walk are also inside T5's 5 %. `run`'s 6.7 % is the shipped 0.1 s scan quantum against a 1.50 s
   crossing and is unchanged by this step.
5. **`mixed` is not a sixth speed.** `range.spec` "crosses at slow OR fast under `mixed`": every
   order the owner issued is one of exactly two speeds, and the measured crossing is within 10 % of
   5.00 OR of 2.50. The pure case takes 400 draws: `400 mixed draws -- 211 slow, 189 fast, 0 other`,
   and `mixedWord(0)` / `mixedWord(0.5)` enter both arms by parameter.
6. **The menu offers seven and every button is ON the panel.** `range_panel.spec` reads the REAL
   buttons: seven values, `SLOW` fifth and `MIXED` seventh, and the widest right edge is inside
   `STRIP_WIDTH` -- `range menu: 7 pace buttons span 409 px of a 416 px strip`. A second case drives
   `buttonLayout` itself: 94/90 at four values (so every shipped row is bit-for-bit today's), the
   strip divided by the count at seven, and the turnover count in between.
7. **306b queued note (ii) is closed.** `range.spec` "does not time the transit when the LANE is
   changed under a target inside the window": the case walks the target until the owner's own
   `windowEnteredAt` is set, calls `Range.setDistance(1, 179)`, and asserts the timer is cleared and
   DISARMED; the next real crossing then measures 3.27 s against 3.27 predicted.
8. **LIVE IN DEV, by a real mouse click (`slow`).** Station 1's bench prompt (L-012: `Hud` resolves
   `promptFor(1)` only). Real `E` opened the menu; a real click moved the lit row from `TROT` to
   `SLOW` (`pace5` background 42,46,40 -> 96,124,72, read off the live buttons); a real click on
   `CONFIRM` sent it; the board then printed `PACE SLOW  pace 7.2 studs/s  issued 7.2 studs/s
   crossing 5.05 s` -- **1.0 %** from 5.00. The live animal measured `v=7.20` in
   `Workspace.RangeTargets`. Frames `<runs-dir>/306b4-pacerow.png` (all seven buttons, none clipped,
   `TROT` lit) and `306b4-check.png` (`SLOW` lit after the click), both opened and described.
9. **LIVE IN DEV, through the menu's own remote (`fast`, `mixed`).** `RangeRequest:FireServer` with
   the same payload the menu sends: the board read `PACE FAST  pace 14.4 studs/s  issued 14.4
   studs/s  crossing 2.52 s` (0.8 %) and `PACE MIXED  pace 14.4 studs/s  issued 14.4 studs/s
   crossing 2.52 s` (0.8 % -- that leg drew FAST, and the board prints the issued SPEED, never a
   second word). **This is the same door but NOT a real click**, which is the next line.
10. **NOT PROVEN, and escalated at the hard stop (V280).** `fast` and `mixed` have never been picked
    by a real click. After the first Play session a synthetic press stops being processed where the
    cursor is and lands on the viewport centre -- which is the `Confirm` bar by design (11.3) --
    even though `GetGuiObjectsAtPosition` says the right button is under the pointer. Five input
    routes were tried and refuted; a 58-px viewport-origin shift between sessions was found and is
    now guarded. `ESCALATE.md`, "Task 306 step B4".

## What could not be verified

- Claim 10 above. Nobody has seen `fast` or `mixed` picked by hand.
- No shot has been fired at a target running at either new pace: that is B5/B9's T4, not this step.
- The board is published on a REQUEST, not per crossing, so every live number above is read after a
  second confirm of the same pick. That is the shipped behaviour, unchanged here.

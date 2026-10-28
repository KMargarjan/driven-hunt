# Task 306 step B4 -- THE PACES: `slow` 5.0 s, `fast` 2.5 s and `mixed`, as TIMES

Task: 306d
Round: 2
Base: task-306b3-treestand @ 7664ce41
Code commit: 391d2ca8d743c806f99a6d1bc23243cc2e64e4f3

`[harness] PASS: 34/34 checks @ 391d2ca8d743c806f99a6d1bc23243cc2e64e4f3 (clean tree) scope=all`

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
  `src/server/Range/init.luau`'s `paceSpeed`, the only writer of `trial.speedStudsPerSecond`
  (`grep -n "speedStudsPerSecond =" src/server/Range/init.luau` -> `newTrial`, `setPace`, and the
  `mixed` redraw in `order`).
- **(e) HOW MEASURED AFTER.** The same instrument as (b): `Range.step`'s own window timer, read
  through `range.spec`'s crossing cases and through the live board in DEV.

## What changed

`Range.WORD` gains `SLOW`/`FAST`/`MIXED`; `Range.CROSSING_SECONDS = { slow = 5.0, fast = 2.5 }` is
the only pair of numbers typed; `Range.crossingTargetSeconds`, `Range.mixedWord` and
`Range.paceSpeedFor` are new; `PACE_ORDER` is seven words with Karen's four first and unmoved. The
server routes every pace through `paceSpeedFor`, redraws `mixed` **per LEG** in `order` through an
injected `roll` seam, records `legDrawn`/`drewWord`, and gains `Range.setDistance` as the one writer
of a live trial's lane -- called by `Range.onRequest`. `RangePanel.buttonLayout` derives the button
pitch from the value count. The design's wrong gait sentence is corrected in the same commit.

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
   slow 7.20 and fast 14.40 are BOTH trot (one clip, two rates)`. **The repo's module `RUN_FROM` is
   28.00, not the 21 the 306a note states** (21 is the band a world lowers it to); both numbers band
   7.20 and 14.40 as trot, so the finding stands either way. Design section 6 now says this and
   section 14 item 11 carries the honest question for Karen.
4. **T5, measured for the five single-speed moving paces at a 36-stud window.** Harness note:
   `walk 7.93 s (predicted 8.00, 0.8 %) · slow 5.02 s (5.00, 0.3 %) · trot 3.27 s (3.27, 0.2 %) ·
   fast 2.57 s (2.50, 2.7 %) · run 1.40 s (1.50, 6.7 %)`. All inside TARGET 3's 10 %, which is what
   the spec asserts; walk, slow, trot and fast are also inside T5's 5 %, and **`run` is not** -- the
   0.1 s scan quantum is 6.7 % of a 1.50 s crossing, which is the shipped sampling rate and not this
   step's. `stand` never crosses (its own case) and `mixed` has two answers (claim 5).
5. **`mixed` is REDRAWN PER LEG, and that is now what the case asserts.** Round 1 finding 1 was
   right: the old case survived deleting the redraw. `Range.start` takes a `roll` seam, `order`
   records `legDrawn` and `drewWord`, and `range.spec` "redraws `mixed` on every leg" drives rolls
   `{0.1, 0.9}` -- slow, fast, slow, fast -- then asserts `trial.legDrawn == trial.leg`, that no
   order carried a third speed (membership, not a count: a count of 0 is truthy in Lua, which is how
   the old case passed), and that **both** speeds appear. Note:
   `mixed -- 343 slow orders, 198 fast orders over 10 legs, 9 crossings, last 2.45 s`.
   **FAIL FIRST, for this case:** deleting the five-line redraw block in `order` and running
   `test --scope auto` gives
   `failed [server] range.spec:1279 Expected value "7" (number), got "nil" (nil) instead` --
   `expect(trial.legDrawn).to.equal(trial.leg)`, the new assertion, at the commit that contains it
   (`[harness] FAIL: 32/34 checks @ 391d2ca8 (DIRTY TREE (1 paths)) scope=auto:match,places,range`).
   The pure draw is proved separately: `mixedWord(0)`/`mixedWord(0.5)` enter both arms by parameter,
   and 400 draws through `paceSpeedFor` give `198 slow, 202 fast, 0 other`.
6. **The menu offers seven and every button is ON the panel.** `range_panel.spec` reads the REAL
   buttons: seven values, `SLOW` fifth and `MIXED` seventh, and the widest right edge is inside
   `STRIP_WIDTH` -- `range menu: 7 pace buttons span 409 px of a 416 px strip`. A second case drives
   `buttonLayout` itself: 94/90 at four values (so every shipped row is bit-for-bit today's), the
   strip divided by the count at seven, and the turnover count in between.
7. **306b queued note (ii) is closed IN THE DOOR.** Round 1 finding 2 was right: the case called the
   owner. It now drives `Range.onRequest(man, { spot = 1, distanceStuds = 179 })` -- where a menu
   CONFIRM arrives -- with the target inside the window, and asserts `windowEnteredAt == nil`,
   `windowArmed == false`, `distanceStuds == 179`, and that the next real crossing measures 3.27 s
   against 3.27 predicted. **FAIL FIRST:** restoring the door's old straight assignment gives
   `failed [server] range.spec:1963 Expected value "nil" (nil), got "2.0999999999999974" (number)` --
   the window timer still running through the lane change.
8. **LIVE IN DEV, by a real mouse click (`slow`).** Station 1's bench prompt (L-012: `Hud` resolves
   `promptFor(1)` only). Real `E` opened the menu; a real click moved the lit row from `TROT` to
   `SLOW` (`pace5` background 42,46,40 -> 96,124,72, read off the live buttons); a real click on
   `CONFIRM` sent it; the board then printed `PACE SLOW  pace 7.2 studs/s  issued 7.2 studs/s
   crossing 5.05 s` -- **1.0 %** from 5.00. The live animal measured `v=7.20` in
   `Workspace.RangeTargets`. Frames `<runs-dir>/306b4-pacerow.png` (all seven buttons on one row,
   none clipped, `TROT` lit, every label legible at 55 px) and `306b4-check.png` (the whole menu
   with `SLOW` lit after the click), both opened and described.
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

- Claim 10. Nobody has seen `fast` or `mixed` picked by hand, and the GAIT at 7.20 and 14.40 -- the
  one thing section 14 item 11 asks Karen to judge -- has not been looked at by anyone.
- No shot has been fired at a target running at either new pace: that is B5/B9's T4, not this step.
- The board is published on a REQUEST, not per crossing, so every live number above is read after a
  second confirm of the same pick. Shipped behaviour, unchanged here. Round 1's note that a `mixed`
  record can pair this leg's speed with the previous leg's crossing time is **queued, not fixed**:
  it needs the crossing's own speed stored when `timeWindow` closes it, which is a payload change.

# Task 303 -- the range on Karen's path: four defects from the Director's real-key proof

Task: 303
Round: 1
Base: 0d65e55c (task-302-range-walkway)
Code commit: TBD

## PLAN (core quality protocol, step 0) -- item 4, the WALK crossing

(a) REAL LIFE. A wild boar walks ~4.5 studs/s at 1 stud = 0.28 m (`Boar.CONFIG.PACE.WALK_SPEED`,
    research note docs/research/*boar*). 40 studs of open window is then 8.89 s.
(b) MEASURED NOW. Karen's place, 0d65e55c, frame
    `<runs-dir>/evidence/p298/14-walk-crop.png`, read by me: the board says
    `PACE WALK  pace 4.5 studs/s  issued 4.5 studs/s  crossing 4.75 s`.
    THE DISPATCH'S PREMISE IS REFUTED: the issued speed IS 4.5 and the board itself prints 4.5.
    4.75 s x 4.5 studs/s = 21.4 studs -- a PARTIAL crossing of a 40-stud window, not a 40-stud
    crossing at 8.42 studs/s. The body cannot exceed the setpoint: `Body.drive` writes
    `mover.PlaneVelocity` (a LinearVelocity velocity setpoint, `src/server/Boar/Body.luau`), which
    under-shoots under load and never over-shoots.
    CAUSE, from source: `Range.setPace` clears `trial.windowEnteredAt`/`windowLeg`
    (`src/server/Range/init.luau`). Pick a new pace while the target is INSIDE the window and the
    next scan re-starts the clock mid-window (`timeWindow`'s `if trial.windowEnteredAt == nil`), so
    the first crossing after any pace change is timed over the remaining studs only. The Director
    picked WALK while the target was crossing at a trot, so WALK read short; TROT (3.60) and RUN
    (1.73) matched because their frames were taken after a later, whole crossing. NOT the drawn
    model, NOT a shared movement row -- the fix is in the range's own owner (dispatch L-147/L-150).
(c) TARGET. The recorded WALK crossing within `Range.CONFIG.CROSSING_TOLERANCE` (10 %) of
    `WINDOW_STUDS / Boar.paceSpeed("walk")` = 8.89 s, after a mid-window pace change -- design
    TARGET 3, the number the board exists to teach.
(d) LEVER. `src/server/Range/init.luau`, `timeWindow` -- the one writer of
    `trial.windowEnteredAt`, `lastCrossingSeconds` and `crossingSecondsByPace`:
      536:		if trial.windowEnteredAt == nil then
      537:			trial.windowEnteredAt = now
      544:			local seconds = now - (trial.windowEnteredAt :: number)
    plus its two clearers, `setPace` (407-408) and `release` (525-526).
(e) HOW MEASURED AFTER. The same instrument as (b) -- the trial's own
    `crossingSecondsByPace["walk"]`, read through `Range.trialOf` -- in a new `range.spec` case that
    drives the Director's exact sequence (trot, enter the window, pick WALK mid-window) against the
    forest row's downrange. FAIL FIRST: without the arming field that case records ~21/4.5 s.

## What changed

1. `src/shared/Range/init.luau` + `src/server/Range/Build.luau`: the prompt moves off the floor
   onto `LAYOUT.POST` -- a named post at the mat's front edge, laid by `onGround` like every other
   part, with the prompt on an attachment at its top. `Range.promptPosition` is the one arithmetic;
   `Range.viewportPointOf` is the pure projection the client case uses.
2. `src/client/Hud/RangePanel.luau`: `confirm()` closes the menu on a successful send -- both doors
   (cursor, input hold) given back on that edge.
3. `src/client/Hud/RangeBoard.luau`: the last line prints the trial's own cartridge LABEL.
4. `src/server/Range/init.luau`: the window timer is ARMED only by a real entry from outside.

## Claims
1. The prompt is on a post, not the mat -- `range.spec` "the way in stands at chest height".
2. From the firing position looking down the lane at Karen's 969x792 viewport the prompt is inside
   the viewport and above the hotbar band -- `range_panel.spec` (client).
3. `RangePanel.confirm()` closes the menu and releases both doors -- `range_panel.spec`.
4. The board's last line prints `.416 Rigby`, not `Slug` -- `range_panel.spec`.
5. A WALK crossing picked mid-window is 8.89 s +-10 % -- `range.spec`.

## Not verified

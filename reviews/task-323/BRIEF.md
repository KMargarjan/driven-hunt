# BRIEF -- Task 323: STAND PICK (the hunter chooses his stand on the map before the drive)

Written by the Director, 2026-10-31. **This file overrides anything older in `docs/`, `TASKS.md` or
an earlier design** (`docs/ARCHITECT_PROMPT.md`).

The Architect is asked for **one design**: `docs/design/stand-pick.md`, plus the **deltas** it needs
in the designs it touches (`map-ui.md`, `drive.md`/`drive-places.md`, `high-seats.md`, `bots.md` as
needed). Nothing else.

## 1. Karen's words

> **2026-10-31 ~21:00:** *"so you now can use sworms and finish things like shooting range, hunter
> positions, terrains, general map in hunting, choose shooting place on map before hunt"*
> Karen said "go ahead" to the Director's plan: range, then map check, then **pick your stand on the
> map before the hunt** with hunter positions, then terrain.

Her design doc (Driven Hunt v1, roles: hunter / beater) has hunters standing on a line of stands
while beaters drive the animals towards them. Today the server places hunter N on stand N
(`Body.placementFor(markers, team, index, ...)` in `src/server/Match/`); the hunter has no say.

## 2. Decisions already taken (the Architect designs to these, it does not re-open them)

- **D1 Who picks.** Hunters only. Beaters/drivers are placed exactly as today.
- **D2 When.** In a PICK WINDOW at the start of each drive, before hunters are placed -- inside the
  existing `Assigning` phase or as a step in front of placement; the Architect rules on which, and
  on the phase/timing arithmetic. Window length is one CONFIG number, first value **15 s**.
- **D3 Where.** On the **existing map** (`docs/design/map-ui.md` owns it -- no second map). For a
  hunter the map opens by itself when the window opens, showing that drive place's stands as
  numbered markers: free, taken (by whom), his own. High-seat stands (`high-seats.md`) show as a
  distinct marker. Tap/click a free stand to take it. Works with mouse and touch (`mobile-controls.md`).
- **D4 Conflicts.** The SERVER decides: first request wins; a taken stand cannot be taken; a hunter
  may change his pick to another free stand until the window closes; a stand freed by a change or a
  leave is free again at once.
- **D5 No pick.** A hunter who has not picked when the window closes is placed on a free stand by
  today's rule (lowest free index), so a drive never waits on a player.
- **D6 Bots** (`DRIVE_BOTS`): bots never take a stand a human could still pick; they fill what is
  left when the window closes.
- **D7 Safety.** Picking changes WHO stands on a stand, never WHERE stands are: the line, the safety
  arcs (`SafetyArc`) and the penalty are unchanged.
- **D8 Flag.** A new flag `STAND_PICK`, born **OFF** (`docs/design/feature-flags.md`). Flag off: today's
  placement bit for bit.
- **D9 Two players.** This touches the match and the teams: `test2` is part of the gate (two hunters
  racing for one stand is the case that matters). Add whatever new paths to `TWO_PLAYER_PATHS` the
  design creates -- or say how to stay within its 20-entry ceiling.
- **D10 No new art.** Markers are UI built in code; no uploads.

## 3. What the design must contain

1. The ONE owner of "which hunter has which stand" and the ONE writer of the pick (rule 3), and how
   `Body.placementFor` / the world's `placement` reads it.
2. The wire: request/answer remotes, what the server validates (role, phase, window open, stand
   exists and free, rate), and what the client is told (the whole pick table, as one snapshot).
3. The phase timing: where the window sits, what the HUD shows (time left), how a late joiner sees it.
4. The map-ui deltas: marker states, the hit area for a tap, what hides what, redraw budget.
5. Edge cases: two requests in the same frame; a hunter leaves mid-window; a role switch mid-window;
   fewer stands than hunters; the drive place rotates (`drive-places.md`) so stands differ per drive.
6. The tests: server specs (owner, conflict, fallback, flag off) and the two-player case, with
   numeric targets.
7. The task split: at most three Builder tasks, each small and testable, in order.

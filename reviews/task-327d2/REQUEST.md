# Task 327d2 — the beaters cross the cell before the clock

Task: 327d2
Round: 1
Base: main `0a2a2ffc`
Code commit: TBD

## PLAN (core quality step 0)

**(a) REAL LIFE.** A driven-hunt beater line advances rather than walks: it stops in cover, beats it
and waits for the flanks. The man-walking band is 0.8–1.5 m/s (`tests/server/bots_lane.spec.luau`,
task 251 part 2). **This target leaves that band**: 1.58 m/s is a brisk walk, and it is accepted for
one reason only — a 1,430-stud cell has to be crossed inside a 300 s clock that did not grow with it
(Director decision, 2026-11-09; `ESCALATE.md` 2026-11-09 ~00:40 UTC).

**(b) MEASURED NOW.** One live drive in Karen's Forest Test at 327d's code commit `52716ba4`, cell
C1, four bot beaters, probe `<runs-dir>/327d-bots.luau`:
`[bots] drive 3 hunters, 4/4 beaters (0 failed, 0 stale) | 4 walking, 1 arrived in 292.9s | 0 stuck,
worst pin 0.0s, 1135 side-steps, 0 no-ground | 74 detours (1 boxed in), 0 recoveries`. The last
beater was dz 58 against the line when the clock ended the drive, so all four would have been
through at ~300–305 s. `END_ON_BEATERS_CROSS` did not fire; the 300 s clock ended the drive.
Ground factor: 292.9 / 278.8 = **1.051**.

**(c) TARGET.** `Grid.CONFIG.beaterWalkStudsPerSecond` **5.64**, `DRIVE.seconds` unchanged at 300.
`(1430 + GOAL_PAST_LINE_STUDS 20) / 5.64 = 257.1 s` flat, `x1.051 = 270.2 s` on the ground, plus
`BEATERS_THROUGH_GRACE_SECONDS` 15 = 285.2 s inside 300. Not 5.35 (through at 285 s, zero margin);
not `DRIVE.seconds` 330 (a longer drive is more waiting, which is the complaint). Director's call.

**(d) LEVER.** `src/shared/Grid/init.luau`, `Grid.CONFIG.beaterWalkStudsPerSecond` — the one owner.
Its one reader writes the bots' `WalkSpeed`:

```
$ grep -rn "WALK_SPEED" src/server/Bots/init.luau
136:	WALK_SPEED = Grid.CONFIG.beaterWalkStudsPerSecond, -- K, via the grid's own cell depth
$ grep -rn "CONFIG.WALK_SPEED" src/server/Bots/
src/server/Bots/Lane.luau:208:		humanoid.WalkSpeed = Bots.CONFIG.WALK_SPEED
```

Proven live at 327d: every bot sampled at `sp=5.20` / `ws=5.2`, so the dial is the right one.

**(e) HOW IT WILL BE MEASURED AFTER.** The same probe (`327d-bots.luau`) in the same place, reading
the same `[bots]` server line for "arrived in Ns", plus the drive's end reason off `Live`.

## Claims

TBD

# Task 124 - the hit indicator, the kill log and the drive report

Task: 124
Round: 3
Base: main
Code commit: `cced90502fddfbeda8efd3ba74e27779834fe879`

```
[harness] PASS: 33/33 checks @ cced90502fddfbeda8efd3ba74e27779834fe879 (clean tree) scope=all
[harness2] <the Director runs this at the code commit and pastes it here>
```

The `[harness2]` line is the Director's: it needs one Studio open, and this round's live proof
needed the Forest Test open beside DEV.

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director
decision, recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own -- DEV's
map could only be rebuilt once 128's bundler existed, and 129 fixed the specs 123-127 broke --
so the evidence for every task in the stack is the gate AT THE HEAD, and every task still gets
its own review.


## What changed

Karen: *"we need to indicate a hit / we need to show when is killed logg / and we need to show on the
end what has been killed where was the hit"*. Three parts, one record.

## What round 2 found, and what round 3 did

**The client half of the kill log had no assertion anywhere, and the suite passed with it deleted** --
which would have taken Karen's first-named ask (*"we need to show when is killed logg"*) out of both
worlds in silence. Two seams were named rather than invented: `Hud.onKilled(event)` is the handler
the replica's `Killed` signal connects to (the same shape as `Hud.onHitMarker`), and `Hud.feedTextFor`
is exported beside `Hud.killLineText`. `tests/client/report_panel.spec.luau` now asserts:

* **one kill draws exactly ONE line** -- `Hud.feedText()` grows by one and the line is
  `killLineText`'s -- and the Match feed's own `kill` entry draws none, which is the two halves of
  that rule;
* **a kill with no `animalKind` says BOAR and never NIL BOAR**, and an empty event draws a line
  rather than raising;
* **the tick counts once per marker** (`Sound.stats()` moved by 2 over a hit and a kill: `hit=1
  kill=1 silent=0`), and an empty id answers `""` and plays nothing.

**Also fixed, the note that would crash a client:** a NaN `page` (a client sending `0/0`) passed
`page < 1` and every clamp and reached the panel's `string.format("PAGE %d/%d")`, which raises.
`Shape.resolveRequest` now stops it with `page ~= page`.

## What round 1 found, and what round 2 did

**ROUND 2.** #1 the fatal dot now joins the KILLING shot: `recordHit` takes the dot's clock from `report.at` (the shot's own, set in `Weapon.Hits.group`) instead of a fresh `os.clock()` on the other side of the signal, and `recordDown` joins on `record.at`/`record.killingZone` -- the MORTAL wound `Wound` latches -- rather than on `wounds[#wounds]`, which on a carcass shot twice is the wrong one. `unmatchedFatal` now rises when the JOIN fails, which is what design section 12 reads. #2 `tests/server/hitlog.spec.luau` is new and covers the server half: the join, the fallback and its counter, a death with no record, a refused hit, `Shape.hunterRows` (kills, lost, hits, no points field), and open/close.

## Claims

1. **One writer of the record.** `ServerScriptService.HitLog` joins the two signals that already
   existed -- `Weapon.HitReported` and `Runtime.Downed` -- on the animal's id string. It adds no
   second score: Match still owns points and penalties. Verify: `src/server/HitLog/init.luau`.
2. **The impact is stored in the ANIMAL's own frame**, computed once at the hit (`HitLog.Shape.dot`
   -> u nose-to-tail, v back-to-belly, side), divided by the part's own `Size` -- so a cub's shoulder
   and a male's land at the same (u, v) and `HitLog` needs neither `Boar` nor its config. A world
   position stops meaning anything the moment the carcass is shoved. Verify: `src/server/HitLog/Shape.luau`.
3. **"Wounded" is where a record starts and only a Downed leaves it**, which IS Karen's wounded-lost,
   with no third signal.
4. **The panel is drawn by ONE writer inside its own frame.** `src/client/Hud/ReportPanel.luau` is
   the only thing that writes anything inside the `ReportPanel` frame; the Hud hands it the frame and
   its collaborators, each of which may be nil. Verify: that file and `src/client/Hud/init.luau`.
5. **Every child of the panel carries an explicit `ZIndex` above the panel's own.** A child at the
   default 1 under a panel at 10 renders BEHIND it -- which is why the first build looked blank and
   then looked see-through. Verify: `CONFIG.PANEL_Z_INDEX` in `src/shared/Report/init.luau` and its
   use in `ReportPanel`.
6. **The silhouette's zones are derived, not drawn twice.** `Report.SILHOUETTE` is built from
   `Boar.CONFIG.ZONES` through `Shape.rectOf`, so a zone that moves in the boar moves on the picture.
7. **The hold is tagged, so two owners cannot fight over the keyboard.** `Input.requestHold` /
   `releaseHold` / `isHeld` / `holdTags` in `src/client/Weapon/Input.luau`, and all four weapon
   handlers are gated on `not Input.isHeld()`.
8. **The hit tick is two engine sounds** (`Shotgun.HIT_MARK_SOUND_ID`, `HIT_MARK_KILL_SOUND_ID`),
   both measured to load, both quiet; an empty id plays nothing and is not an error.
9. **The zone question was measured and there was no zone bug**: firing at ZoneHead / ZoneChest /
   ZoneRear at 30-90 studs, three shots each, the server recorded the part aimed at. The differences
   were muzzle parallax plus replication lag, not a mis-mapped zone.

## What could not be verified

- **The panel in Karen's hands.** Its layout was inspected in frames I took myself; whether the
  numbers are the ones she wants after a drive is a playtest.

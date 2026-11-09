# Task 338 -- "an animal got away xN": the premise, measured

Task: 338
Round: 1
Base: 5cc51f81
Code commit: ccd7689c (docs only -- no file under src/, tests/ or tools/ changed on this branch)

## PLAN (core-quality step 0)

(a) **REAL LIFE / the brief.** The hunter's feed must say "an animal got away" once per animal that
really left the drive.
(b) **MEASURED NOW.** In Karen's Forest Test on main `5cc51f81`, cell C1 (exit line z = -5402), no
shot fired, two probes in one Play session: `<runs-dir>/338-watch.luau` (server, every spawn and
removal of `Workspace.Boars` with the animal's last position) and `<runs-dir>/338-wire.luau`
(client, every `escape` entry on `ReplicatedStorage.Drive.Remotes.MatchEvent` -- exactly what the
toast stacks). Readings in the table below.
(c) **TARGET.** One toast per animal that crosses the cell's exit line, none for anything else.
(d) **LEVER.** `src/server/Match/init.luau` `onDespawned` -> `dispatch({ kind = "gone" })`, guarded
by `record.reason ~= "escaped"` and `Phase.isLive(state)`; `src/server/Match/Phase.luau` turns that
into the `escape` feed entry; `src/server/Boar/Brain.luau` `Brain:_outcome` is what calls it
escaped, at `position.Z <= field.exitZ`.
(e) **AFTER** would be the same two probes.

**(b) CONTRADICTS THE DISPATCH, so per step 0 this item stops here and no `src/` file is touched.**
The full evidence is in `ESCALATE.md`, 2026-11-09.

## Claims

1. **The count is zero in the first minute, not "climbing from the first seconds".** Drive 1:
   escape entries = 0 at 15 s, 0 at 60 s, 19 at 150 s, 108 at 300 s; first entry at +72.8 s. Drive 2
   at 145 s: 78 released, 0 crossings, 0 new entries. *Verify:* the run output quoted in
   `ESCALATE.md` and `<runs-dir>/338-run.sh`, which is the script that took it.
2. **The HUD `TIME` field is a COUNTDOWN, so "0:11" is 289 s into a 300 s drive.** *Verify:*
   `Match.secondsLeft` in `src/client/Match/init.luau` returns `phaseEndsAt - GetServerTimeNow()`,
   and `clockText` in `src/client/Hud/init.luau` formats it.
3. **Both frames say so.** `327d-F1-stand-beaters.png` (the evidence frame) reads `DRIVE 1 · 0:11
   TIME` with "an animal got away x80"; `338-F1.png` (mine, this session, drive 2 at 87 s) reads
   `DRIVE 2 · 3:33 TIME` with **no got-away line on screen**. *Verify:* open both.
4. **Every toast was a real animal at the real line.** Drive 1: 130 spawned, 114 removed, 108
   escape entries; each of those removals had the animal at z = -5397…-5402 against C1's exit line
   -5402. *Verify:* the per-animal `DEL` log in `ESCALATE.md`.
5. **The 6 removals that fired no toast are correct.** They are the pre-drive animals wiped by
   `runtime:clear("layoutChanged")` in `promote` (`src/server/ForestTest/init.luau`), reason
   `cleared`, which `onDespawned` returns on. *Verify:* read `promote` and `onDespawned`.
6. **Which animal each toast was.** The two probe clocks are a fixed 4.0 s apart; entries map
   one-to-one in order -- toast 1 = Boar1 (z=-5401), 2 = Boar7 (-5401), 3 = Boar3 (-5402).
   *Verify:* the two logs in `ESCALATE.md`, same run.
7. **The drive releases 130 / 80 animals, not ~60**, because `ForestTest.slotAt`
   (`src/shared/ForestTest/init.luau`) repeats the 15-row script past slot 15 by design and the
   metronome fires every 13 s for 300 s. Drive 2 ended at x55, the same figure the evidence frame
   photographed for drive 5. *Verify:* read `slotAt`'s `repeatFrom`/`repeatTo` branch.

## What I could not verify

* Whether ~130 released and ~110 escaped per drive is the drive Karen wants. That is drive density,
  which the dispatch's NOT YOURS list puts outside this task; it is in `ESCALATE.md` for the
  Director.
* Drive 2's own 15 s / 60 s row is from its first 145 s only (the session was stopped after drive 2
  closed, at x55); its end figure is the 55 entries it added.

## Gate

Docs-only round: no file under `src/`, `tests/` or `tools/` changed, so the harness gate does not
apply (CLAUDE.md, the loop step 3). `test2` N/A for the same reason.

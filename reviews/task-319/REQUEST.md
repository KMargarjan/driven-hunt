# Task 319 — the range keeps going, and a leave ends it

Task: 319
Round: 1
Base: a659b5f9 (main, 313-318 merged)
Code commit: fbd0145bf8e4f0f6c8f3523c47e922015e15fb40

Karen, 2026-10-31: *"i don't need each time click e to have new animal, I killed , then new comes
after few seconds I can click e and change settings I also can leave then end"*.

Harness, clean tree, at the code commit:

```
[harness] PASS: 34/34 checks @ fbd0145bf8e4f0f6c8f3523c47e922015e15fb40 (clean tree) scope=all
```

`test2`: N/A. `python -c "agents.needs_two_player([...the four changed paths])"` answers `[]` —
`src/server/Range/`, `src/client/Hud/` and their specs are in no `TWO_PLAYER_PATHS` entry.

## What changed

`src/server/Range/init.luau`, `src/client/Hud/RangePanel.luau`, and their two specs. Nothing else.

## Claims

1. **THE AUTO-NEXT WAS ALREADY THERE, AND IS NOW GUARDED.** Measured first, at main (a659b5f9) in
   Karen's Forest Test with no E pressed at all (`319-flow.luau`): first animal on the lane 0.5 s
   after standing on station 2's mat, carcass gone 2.40 s after the kill, a NEW LIVE animal 4.37 s
   after the kill. So no release timing is touched. `range.spec`'s new "brings the next animal by
   itself after a kill" case asserts it with the species, kind, pace, lane and station he picked,
   and no second request. Verify: `scan`'s carcass branch in `Range` (`CARCASS_SECONDS` then
   `releaseAt = now + RELEASE_SECONDS`) is unchanged in the diff.
2. **`leave` IS A WORD THE ONE DOOR READS**, beside `reset` and before the two-pass option check:
   his own animal through `clearOne`, his record and pending slot dropped, `stats.leaves`,
   `trial.ended = true`. Verify: `Range.onRequest` in the diff; no second remote was added.
3. **AN ENDED STATION RELEASES NOTHING WHILE HE STANDS THERE.** `scan`'s release edge now reads
   `occupied and not trial.ended`. Verify: that line, and the spec's 10 s with no spawn.
4. **TWO RE-ARMS, SO HE NEVER PRESSES E JUST TO GET AN ANIMAL.** Any `go` or pick clears `ended`
   (`onRequest`, before the options are applied); so does the station going empty (`scan`'s
   occupancy branch), so the next man finds a live station. Verify: both writes in the diff, and
   the spec's "RE-ARM 1 / RE-ARM 2" blocks.
5. **FAIL FIRST.** With `src/server/Range/init.luau` alone reverted to a659b5f9, the leave case
   fails at its first assertion — `range.spec:2006`, `onRequest{leave=true}` answers false, because
   `leave` is not a word that door knows (`319-failfirst.txt`,
   `[harness] FAIL: 32/34 checks @ cba7237c (DIRTY TREE (1 paths))`). The 11 further `range.spec`
   failures in that run are the cascade of an aborted case leaving the range started; they are not
   present with the fix (gate run: 2597 passed, 0 failed).
6. **THE PANEL HAS ONE NEW SENDER AND ONE NEW BUTTON.** `RangePanel.leave()` sends
   `{spot, leave=true}` and closes the menu on that edge, both doors back by tag. Verify:
   `range_panel.spec`'s new case.
7. **THE BUTTON IS WHERE IT CAN BE SEEN AND CLICKED.** First position (56 px under the confirm bar)
   was MEASURED on screen in her place and came out grey under the range BOARD
   (`319-b-panel.png`); it is now the panel's top-right corner, which is neither the board's strip
   nor the viewport centre the input replay clicks. Frame: `319-c-panel.png` (LEAVE THE RANGE
   legible, top right).
8. **LIVE, IN HER PLACE, AT THE CODE COMMIT** (Forest Test on rojo :34874 from `driven-hunt-294` at
   fbd0145b; flags read live in that session: `RANGE=true RANGE_SOLO=true`):
   real E opened the menu (`319-c-panel.png`); a real click on RUN picked it (`319-i-pick-zoom.png`)
   and after a real click on RELEASE the BOARD printed `PACE RUN pace 24.0 studs/s issued 24.0
   studs/s` (`319-l-board2-zoom.png`) — the pick and the word on the board agree; a kill with no E
   pressed gave carcass gone +2.40 s, new live animal +4.37 s (`319-killwatch.luau` output); a real
   click on LEAVE THE RANGE left `RangeTargets` with 0 children, still 0 twelve seconds later while
   he stood on the mat; one E + RELEASE later a new animal (Boar4) was on the lane.
9. **NOT PROVEN ON SCREEN: the arriving animal itself.** No frame shows it. With the camera pointed
   at it (`WorldToViewportPoint` 485,396 of 969x792) and a camera raycast hitting it at 123 of 124
   studs, its drawn mesh reads `LocalTransparencyModifier = 1.00` on this client — `Range.Mask`'s
   HIDDEN value — so it is not drawn in any frame, through either capture route (window grab and
   StudioMCP capture). Reported, not fixed: this task is CORE-NA and the crossing, pace and death
   stay as they are.
10. **NOTHING ELSE ON THE PANEL OR BOARD CHANGED**, and no release timing moved. Verify: the diff is
    four files; `CARCASS_SECONDS`, `RELEASE_SECONDS` and `IDLE_CLEAR_SECONDS` are untouched.

## What I could not verify

- The frame of claim 9, above.
- Walking off the station still ends the session the EXISTING way: `IDLE_CLEAR_SECONDS` = 30 s, kept
  deliberately (design 7.4, *"stepping off the mat is not losing your target"*). The explicit
  LEAVE button is the immediate end.
- Two gate runs at the code commit failed on named intermittents before the PASS above:
  `deer_hitbox.spec:682` twice (315a(q)), and, while Karen's Forest Test was in PLAY on the same
  machine, `weapon_shot.spec:1890`/`:1490` (L-136) and `semiauto_client.spec:93`. The client ones
  did not recur once that Play session was stopped.

ANSWERED: L-136 the flake fired as `weapon_shot.spec:1490` in one run and is named above with its run.
ANSWERED: L-127 every dispatch item is MET or NOT PROVEN ON SCREEN by name in claims 1-9.
ANSWERED: L-162 every live proof above was taken at fbd0145b, the code commit, on :34874.
ANSWERED: L-159 the one-event `298key.ps1` is what pressed E, and one press opened the menu once.
ANSWERED: L-164 `RANGE` and `RANGE_SOLO` were read live inside the proof session, after the flag writes.
ANSWERED: L-158 the fix is per-station: `trial.ended` is one trial's field, the spec drives station 2
with a one-man crowd and the other five stations keep their own animals.
ANSWERED: ROUTE the 3 s window was captured with the 130 ms burst named before the attempt
(`319-burst.ps1`), and the arrival was measured by instance log; the frame is claim 9's NOT PROVEN.
ANSWERED: Rule 5 every frame cited above was opened and described.

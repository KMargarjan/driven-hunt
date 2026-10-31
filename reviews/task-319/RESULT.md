PASS (item 1, 9 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the LEAVE THE RANGE button itself
was seen in Karen's place (`319-c-panel.png`, described: legible, top right), and so were the pick and
the board's agreeing PACE line (`319-i-pick-zoom.png`, `319-l-board2-zoom.png`). The ARRIVING ANIMAL
of item 1 -- the thing she judges when she says *"I killed, then new comes after few seconds"* -- was
NOT seen: claim 9 reports its drawn mesh at `LocalTransparencyModifier = 1.00` on that client with the
camera on it, so the +2.40 s / +4.37 s timings of claim 8 are an instance log and no frame. The
no-animal-after-a-leave half has nothing to see and is proven as far as a picture can go
(`RangeTargets` 0 children, still 0 twelve seconds later).

## Notes (non-blocking)
- `src/client/Hud/RangePanel.luau` / `RangePanel.rowRect` -- the new `option == "leave"` arm has no
  reader anywhere: the only caller in the repo is `range_panel.spec`'s `rowRect("pace", index)`, and
  the `"confirm"` arm it was copied from is itself uncalled. Either the live scenario of design 11.3
  asserts the clicked point lies inside this rectangle (which is what the function's own comment says
  it exists for), or the arm is dead code; queue the assertion rather than the deletion.
- `src/client/Hud/RangePanel.luau` / `build` -- `Title`'s rectangle is `Position (16, 10)`,
  `Size (1, -32, 0, 24)`, i.e. x 16..544, y 10..34, and the new button is x 364..544, y 8..36 at
  `Z_INDEX + 2` against the title's `+ 1`. Nothing is hidden today because the title is left-aligned
  and transparent-backed, but a longer title string would be drawn under the button. Shortening the
  title's width to `(1, -212)` would make the two disjoint.
- `tests/client/range_panel.spec.luau` / the new case -- `expect(sent[1].spot).to.be.ok()` cannot
  distinguish his station from the default: `station` initialises to `{ spot = 1 }` and the case never
  calls `RangePanel.setStation`, so the assertion holds with the station plumbing removed. The case's
  own claim ("one leave word, and the menu closes") is proven by the other assertions; a
  `setStation(3)` before the send would make the `spot` half mean something too.
- `src/server/Range/init.luau` / `scan`'s re-arm -- the two clocks are asymmetric: `trial.ended` is
  spent on the FIRST scan tick he is off the mat, while his animal survives `IDLE_CLEAR_SECONDS`
  (30 s). So after a LEAVE, one step off the mat and back releases a new animal at once -- the "end"
  undone by an accidental step. Claim 4 declares the behaviour and gives its reason (the next man
  finds a live station), so this is Karen's call, not a defect; queue a grace period keyed on
  `idleSince` if she reports it.
- `src/server/Range/init.luau` / the `leave` arm -- the end is per STATION, not per player, and the
  design makes two men on one mat one occupied station (`stats.idleClears`' own comment). So where a
  `reset` clears only the sender's record, a LEAVE clears the animal the other man on that mat is
  shooting at and blanks the station until somebody asks. Six stations make this rare; worth one line
  in design 7.4 so the next change does not have to re-derive it.
- `src/client/Range/Mask.luau` -- outside this change and not made worse by it, so a note only: claim
  9's measurement is what `wantedFor` returns for a trunk that is not `state.mine`, and `setMine` is
  TOLD off the server's published record. A freshly released target is therefore `Mask.HIDDEN` until
  that publish names it, which is a range animal the man at the station cannot see. Queue it as its
  own task -- it is worth more to the game than anything in this diff.

---
REVIEWER verdict on commit `646267497efe6deabb313ccc4fd7ee9df2794b82` (round 1) · 2026-10-31 19:04 UTC · session cost $2.69, 42 turns · written by tools/agents.py

# Task 306k -- three fixes from the Playtester (plus the defects they uncovered)

Task: 306k
Round: 2
Base: 884cff14 (merged #290)
Code commit: 94a050a83f03fb177834206a1af5abb2dfaac568

Harness, clean tree, at the code commit:

```
[harness] PASS: 34/34 checks @ 94a050a83f03fb177834206a1af5abb2dfaac568 (clean tree) scope=all
```

`python tools/agents.py needs_two_player` on this branch's diff answers `[]` -- no match, drive, tie
or teams path is touched -- so `[harness2]` is N/A.

## What changed

Four dispatch items. Three more defects turned up while proving them, two of them caused by this
task's own fixes; all three are fixed here.

1. **The way down is drawn.** `Range.downPromptRiseFor` replaces the typed `CLIMB.deckRise`.
2. **The berm is a real backstop.** `BERM.height` 10 -> 21, `BERM.slopeSteps` 4 -> 6,
   `BANK.size.Y` 8 -> 18, `SURFACE.BERM` Grass -> Ground (both the terrain arm and the part arm,
   berm and banks).
3. **The climb keeps his gun.** `moveBody` anchors first; `Range.settleStep` / `holdForSettle`
   release it; `Range.standReach` reaches the way down.
4. **The deck's DISTANCE chip lights and reads the board's number.** `Range.distancePickOf`,
   `RangePanel.valuesFor`, `Range.look`, `RangeBoot.matEdges`.
5. (uncovered) `RangePanel.climbTakesKey` -- the panel stands down only for a climb prompt on E.

## Claims

1. **Round 1, finding 1 -- two climbs inside the window.** `Range.holdForSettle` now keeps ONE row
   per root: a second hold refreshes `left` and keeps the FIRST `was`, so the release can never put
   back the `true` it wrote itself. Verify `src/server/Range/init.luau` and the new arm of
   `range.spec` "releases a climbed body's anchor after the settle" -- it holds the SAME part twice
   0.1 s apart, asserts the window was refreshed, and asserts it ends **false**; and it does the
   same for a root that was already anchored, which must end **true**.
2. **Round 1, finding 2 -- the in-transit band wiped the board.** Two changes: `matEdges` makes an
   edge only out of a REAL firing position (`word ~= nil`), and `Range.look` keeps the word the
   record already had when the measurement is nil. Verify `src/server/RangeBoot.server.luau`,
   `Range.look`, and the new `range.spec` case "keeps the tally when a man walks between the bench
   and his own ladder" -- it shoots from the bench, walks 8 studs uprange (asserting `spotAt` there
   is spot 1 with a **nil** word), and asserts `shots` is still 1 and the position still `bench`;
   then it stands him ON the deck and asserts the position DOES change and the tally DOES reset, so
   this is not "never change the position".
3. **The down prompt sat below the view cone, and that is arithmetic.** At `deckRise` 1.6 the point
   was 3.4 studs under the eye and 2.9 in front -- 49 degrees below a level look, where a 70-degree
   FOV reaches 35. Verify `Range.downPromptPosition` / `downPromptRiseFor`, and
   `range_panel.spec` "puts the Climb down prompt inside Karen's viewport from the deck": it
   projects the point into 969x792 over an eye band and asserts the OLD 1.6 point falls under the
   hotbar (fail-first).
4. **The down prompt's point is now pinned, which it never was** (306j RESULT.md note). Verify
   `range.spec` "hangs a Climb on E at the ladder foot and a Climb down on F": identity against
   `downPromptPosition`, reach from `climbTargetFor(...).Position`, height tied to `eyeOverRootStuds`.
5. **The gun was not "swapped", it was LOST, and the station box was why.** Measured at the
   climb-down point (2624, 153.15, -3009): `held=nil backpack=[]`, because the box ended at -3010.9
   -- `standReach` 19.10 against the 21 the way down needs. Verify `Range.standReach` and the
   `spotAt(down) == 2` line in "keeps a man walking from the bench to the ladder AT his own
   station"; delete the `wayDown` arm and it fails.
6. **Real keys in HER place, on THIS commit** (`<runs-dir>/306k-tools.luau`, same probe each time):
   ground `held=Rifle` -> real `E` -> deck Y 165.65 `held=Rifle` -> real `F` -> ground Y 153.15
   `held=Rifle`; backpack `[Lever,SemiAuto,Shotgun]` at every reading. Two real `E` back to back
   (inside 0.4 s) left `anchored=false` -- the live side of claim 1, weakly, because the second press
   had no prompt left to trigger; the spec case is the real proof.
7. **The berm: 21 studs is sourced, the face is earth, and T6 is kept.** 10 studs subtended 3.0
   degrees at 190; 21 studs (5.9 m at 0.28 m/stud) is the top of the 4-6 m band real impact berms use
   (NRA Range Source Book; US Army TC 25-8) and subtends 6.3. Re-swept with the same instrument as
   `306b8-proof.luau`'s T6 (`<runs-dir>/306k-t6.luau`): **`T6: 180 shots, 180 stopped at or before
   the berm, 0 not`**, and the crest raycast at three z all read `171.02` -- **21.02 studs over the
   shelf**, measured not assumed.
8. **The deck's DISTANCE row.** Deck menu reads `121 / 139 / 193` with **139 lit** -- the number the
   board prints from the deck (`306k-PROOF-deckmenu2-crop.png`); on the previous commit, same deck,
   same instrument, it read `107 / 125 / 179` with 125 lit (`306k-PROOF-deckmenu-crop.png`). Verify
   `range_panel.spec` "lights the DISTANCE chip on the deck": it asserts the bench arm too, that the
   lit chip is still the PICK the server's whitelist accepts, and that 139 is NOT accepted.
9. **Item 1's fix closed the menu on the deck, and that is fixed here.** With the F prompt drawn,
   `climbShown` went true up there and `onKeyPressed` swallowed E -- a real E opened nothing
   (`306k-deckmenu.png`). `RangePanel.climbTakesKey` narrows the stand-down to a prompt on the
   panel's OWN key; a real E then opened the full menu (`306k-PROOF-deckmenu2-crop.png`).
10. **Frames, all looked at** (`<runs-dir>/`, BEFORE on 884cff14, AFTER on this branch, same camera
    points): `306k-BEFORE-bench2-crop.png` / `306k-AFTER-bench2b-crop.png` (bench 2, camera
    2624.1,155.7,-3030.4) · `306k-BEFORE-deck2-crop.png` / `306k-PROOF-deck-crop.png` (deck 2,
    camera 2624.1,167.2,-3016.4; the AFTER one also shows the drawn "F TREESTAND Climb down") ·
    `306k-PROOF-ground-crop.png` (Rifle in hand after the real F) · `306k-AFTER-boar-zoom.png` (3x
    on the berm's face).

## What I could NOT verify

- **That the berm reads as a "mountain".** It reads as a BACKSTOP: brown worked earth across the
  whole lane, above the horizon, hiding the hills behind the animal. Its crest is a dead-straight
  horizontal line and from the bench the 12-stud batter is foreshortened to nothing, so it reads as
  an earth WALL rather than a natural hill (`306k-AFTER-boar-zoom.png`). Whether that is "earth
  formed mountain" enough is Karen's eye; a varied ridge and planting is NOT in this task.
- **The 179-stud lane stands on the batter's toe** (round 1 note, corrected here): the toe is at
  176, three studs UPRANGE of that lane, and has been since B8's `slopeRun = 12`. This raise DEEPENS
  the earth there (about 2 studs to 3) rather than creating it. Queued, not claimed fixed.
- **b306b10's NOT MET item 5** (the floating side-fence post at (2775,-3061)) is untouched: the
  dispatch's "Nothing else" leaves it out and the fence is still deliberately not built.
- **Two players.** `needs_two_player` answers `[]`.

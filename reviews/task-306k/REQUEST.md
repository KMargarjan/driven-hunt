# Task 306k -- three fixes from the Playtester (plus the two defects they uncovered)

Task: 306k
Round: 1
Base: 884cff14 (merged #290)
Code commit: 7178049713b6c81ca7c5cd13d2ec13bcd9f4eb1e

Harness, clean tree, at the code commit:

```
[harness] PASS: 34/34 checks @ 7178049713b6c81ca7c5cd13d2ec13bcd9f4eb1e (clean tree) scope=all
```

`python tools/agents.py needs_two_player` on this branch's diff answers `[]` -- no match, drive, tie
or teams path is touched -- so `[harness2]` is N/A.

## What changed

Four dispatch items. Two more defects turned up while proving them live and are fixed here, because
one of them was caused by item 1's own fix.

1. **The way down is drawn.** `Range.downPromptRiseFor` replaces the typed `CLIMB.deckRise`.
2. **The berm is a real backstop.** `BERM.height` 10 -> 21, `BANK.size.Y` 8 -> 18,
   `SURFACE.BERM` Grass -> Ground.
3. **The climb keeps his gun.** `moveBody` anchors first; `Range.standReach` reaches the way down.
4. **The deck's DISTANCE chip lights and reads the board's number.** `Range.distancePickOf`,
   `RangePanel.valuesFor`, `Range.look` and `RangeBoot.matEdges`.
5. (uncovered) `RangePanel.climbTakesKey` -- the panel stands down only for a climb prompt on E.

## Claims

1. **The down prompt sat below the view cone, and that is arithmetic.** At `deckRise` 1.6 the point
   was 3.4 studs under the eye and 2.9 in front of it -- 49 degrees below a level look, where a
   70-degree FOV reaches 35. Verify: `Range.downPromptPosition` / `downPromptRiseFor` in
   `src/shared/Range/init.luau`, and `tests/client/range_panel.spec.luau` "puts the Climb down prompt
   inside Karen's viewport from the deck" -- it projects the point into 969x792 over an eye band and
   asserts the OLD 1.6 point falls under the hotbar (fail-first).
2. **The down prompt's point is now pinned, which it never was** (306j RESULT.md note). Verify:
   `tests/server/range.spec.luau` "hangs a Climb on E at the ladder foot and a Climb down on F" --
   identity against `downPromptPosition`, reach measured from `climbTargetFor(...).Position` (the
   point the climb actually puts him at), and the height tied to `eyeOverRootStuds`.
3. **Real keys in HER place, final commit** (frames below): on the deck with the Rifle, a real `F`
   put him at Y 153.15 holding the **Rifle**; a real `E` put him back at Y 165.65 holding the
   **Rifle**; backpack `[Lever,SemiAuto,Shotgun]` unchanged at every reading. Probe:
   `<runs-dir>/306k-tools.luau`.
4. **The gun was not "swapped", it was LOST, and the cause was the station box.** Measured: staged at
   the climb-down point (2624, 153.15, -3009), `held=nil backpack=[]`; the box ended at -3010.9
   because `standReach` was 19.10 against the 21 the way down needs. Verify: `Range.standReach` and
   the new `spotAt(down) == 2` line in `range.spec` "keeps a man walking from the bench to the ladder
   AT his own station" -- delete the `wayDown` arm and it fails.
5. **The pivot anchors first.** `moveBody` holds the root, `Range.settleStep` releases it after
   0.4 s **to the value it replaced**. Verify: `range.spec` "releases a climbed body's anchor after
   the settle, to the value it replaced" -- a free part and an already-anchored one, half-way and
   past, plus a destroyed root.
6. **The berm: 21 studs is sourced and the face is earth.** 10 studs subtended 3.0 degrees at 190;
   21 studs (5.9 m at 0.28 m/stud) is the top of the 4-6 m band real impact berms use (NRA Range
   Source Book; US Army TC 25-8), and subtends 6.3. `depth` and `behindStuds` do NOT move -- the
   batter's toe stays 3 studs clear of the 179-stud target and the far face stays off the road the
   playtest measured at 200-275 studs. Verify: the `BERM`/`BANK`/`SURFACE` comments and the pinned
   literals in `range.spec` "leaves every measured point and distance exactly where B2-B9 put it".
7. **T6 is kept, re-swept on the taller berm**, `<runs-dir>/306k-t6.luau` (the same instrument as
   `306b8-proof.luau`'s T6): `T6: 180 shots, 180 stopped at or before the berm, 0 not`. The crest was
   measured by raycast at three z, all `171.02` -- **21.02 studs over the shelf**, not assumed.
8. **The deck's DISTANCE row.** Two causes, both fixed: `Range.look` made a record with no firing
   position, and `matEdges` watched "on the range" rather than WHICH position -- so a man who climbed
   kept the bench's record. With both, the deck menu reads `121 / 139 / 193` with **139 lit**, which
   is the number the board prints from the deck. Verify: `range_panel.spec` "lights the DISTANCE chip
   on the deck and labels it the distance from there" -- it asserts the bench arm too (fail-first),
   that the lit chip is still the PICK the server's whitelist accepts, and that 139 is NOT accepted.
9. **Item 1's fix closed the menu on the deck, and that is fixed here.** Once the F prompt was drawn,
   `climbShown` went true up there and `onKeyPressed` swallowed E -- measured on screen, a real E
   opened nothing (`306k-deckmenu.png`). `RangePanel.climbTakesKey` narrows the stand-down to a climb
   prompt on the panel's OWN key. Verify: `range_panel.spec`, the `climbTakesKey` block.
10. **Frames, all looked at** (in `<runs-dir>/`, BEFORE on 884cff14 and AFTER on this branch, same
    camera points, same instrument): `306k-BEFORE-bench2-crop.png` / `306k-AFTER-bench2b-crop.png`
    (bench 2, camera 2624.1,155.7,-3030.4) · `306k-BEFORE-deck2-crop.png` /
    `306k-PROOF-deck-crop.png` (deck 2, camera 2624.1,167.2,-3016.4) ·
    `306k-PROOF-ground-crop.png` (after the real F) · `306k-PROOF-deckmenu2-crop.png` (the 139 chip).

## What I could NOT verify

- **That the berm reads as a "mountain".** It reads as a BACKSTOP: brown worked earth across the
  whole lane, standing above the horizon and hiding the hills behind the animal. Its crest is a
  dead-straight horizontal line and from the bench the 12-stud batter is foreshortened to nothing,
  so it reads as an earth WALL rather than a natural hill (`306k-AFTER-boar-zoom.png`, 3x). Whether
  that is "earth formed mountain" enough is Karen's eye. A varied ridge line and planting on the
  crest is the next step and is NOT in this task.
- **b306b10's NOT MET item 5** (the floating side-fence post at (2775,-3061)) is untouched: the
  dispatch's "Nothing else" leaves it out, and the fence is still deliberately not built.
- **Two players.** `needs_two_player` answers `[]`.

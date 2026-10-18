# Task 201 part 2 — the two tables, and one row component for both

Task: 203
Round: 2
Base: main @ `19c5604`
Code commit: `449e0120500d6d8ef5c0d190ebab646f9a41b838`

```
[harness] PASS: 33/33 checks @ 449e0120500d6d8ef5c0d190ebab646f9a41b838 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 449e0120500d6d8ef5c0d190ebab646f9a41b838 (clean tree)
```

Both lines are the Director's runs at the same commit. His note with them: `test2`'s first attempt hit
two known flakes in files this branch does not touch — `weapon_client`'s reload case and
`boar_body`'s `memberIds` — queued as task 210; the retry passed.

**THE FOLDER IS `task-203` AND THE ROADMAP CALLS THIS "201 PART 2".** `tools/agents.py` resolves a
task of DIGITS only (`resolve_task`, and the `task-(\d+)/REQUEST\.md` regex), and writing into
`reviews/task-201/` would overwrite part 1's own PASS verdict for a PR already merged to `main`
(rule 7). `TASKS.md`'s row still reads 201-2 and points here.

## What this round is

Round 1 returned **three blocking findings**. All three were real; each is fixed at its owner, with
the two non-blocking notes the Director named and one defect of my own that the gate caught. Nothing
was reframed: the round-1 verdict stands as written (`reviews/task-203/RESULT.md`).

Note: `docs/research/2026-10-17-one-design-system.md`, the "Part 2" section.

## The three findings, each with the case that fails at `e1c6966`

**Every line below was produced by checking out the PRE-FIX source and running the suite against the
NEW specs** — `git checkout e1c6966 -- src/client/Hud/`, then `test --scope auto` on a deliberately
dirty tree (the harness flags it `DIRTY TREE (3 paths) - NOT valid evidence`, which is right: it is
evidence about the CASES, not about the build).

**1. The report's well clips rows the server sends — fixed by making it scroll.**
`ReportPanel.build` puts a `ScrollingFrame` ("Body") inside the well, with the system's own 3 px
brass bar at half transparency — the treatment the results board's body already uses, so there is
one scrollbar in the game. The column head is pinned in the well ABOVE it and does not scroll away.
`ReportPanel.canvasHeight` is the pure measure, `applyCanvas` writes it from what was drawn, and
`ReportPanel.windowHeight` reads the drawn frame.

*Not a shorter page:* the page size is the SERVER's (`HitLog` reports `pages` from
`ANIMALS_PER_PAGE`), so a client showing fewer would be disagreeing with its own payload — the
failure this panel's header exists to prevent.

Case: `report_panel.spec`, "reaches EVERY row the server can send, which the clipped well did not".
It asks the two constants the server pages by (16 and 8), not a convenient number, and asserts the
canvas holds them, that the detail canvas is BIGGER than the window (so the rest scrolls into view
rather than being clipped), and that the last row is inside the canvas and a descendant of the
scrolling body.
```
failed [client] report_panel.spec:242 Expected value "nil" to be non-nil
```

**2. `Hud.boardHeight` omitted the card's padding — fixed by one source for the inset.**
`Style.cardInset` is now that source and `Style.card` reads the same function; `Hud.boardHeight`
adds `2 × inset` and `Hud.boardContentHeight` is the box the three bands are laid out in. Measured
on screen: the board was `520x134` for an empty roster and is `520x158` — the 24 px that were being
drawn over the table.

Case: `match_client.spec`, "leaves the footer clear of the table, which the card's own padding ate".
It asserts the inset arithmetic AND then reads the DRAWN frames: the footer's `AbsolutePosition.Y`
is at or below the body's bottom.
```
failed [client] match_client.spec:473 ReplicatedStorage.ClientTests.match_client.spec:473: attempt to call a nil value
```
(`Style.cardInset` and `Hud.boardContentHeight` do not exist at `e1c6966`.)

**3. The tied banner's slate was raised after its text — fixed by passing the band in.**
`Style.toast` takes a `zIndex` argument used BEFORE its children are built. The old guard
(`if parent:IsA("GuiObject")`) could never fire for this toast: it is parented to the `ScreenGui`.
The feed's toasts pass `feed.ZIndex` through the same argument rather than leaning on the guard.

Case: `hud_style.spec`, in "draws the two tables from ONE row component, and the tied toast over the
band" — `text.ZIndex > tied.ZIndex` and the same for the dot, plus the rule over every feed toast.
```
failed [client] hud_style.spec:692 Expected value "true" (boolean), got "false" (boolean) instead
```

## The two spec holes

**4. `Hud.scoreFooterText` substituted the constant for the drawn word.**
It now returns the word it read. Case: `match_client.spec`, "answers the footer's DRAWN word, not
the constant it was supposed to match" — it writes a different word onto the live label and asserts
the accessor follows, then puts it back.
```
failed [client] match_client.spec:510 Expected value "SOMETHING ELSE 12" (string), got "NEXT DRIVE IN 12" (string) instead
```

**5. The scrim case asserted `false == false`.**
**This one is different and I am saying so rather than claiming a failing line I do not have:** the
CODE was correct at `e1c6966` — `setOpen` already wrote the scrim — so the strengthened case passes
there too. What round 1 found was a case with no teeth. I proved the teeth instead, by deleting the
`setOpen` scrim write and running the suite: the new case, which OPENS the panel and asserts both
frames visible, fails.
```
failed [client] hud_style.spec:713 Expected value "true" (boolean), got "false" (boolean) instead
```

## One more defect, mine, caught by the gate rather than by a review

**6. `Style.unspaced`.** `Style.spaced` puts a space after EVERY character — the original spaces
included — so a sentence is drawn with two spaces where it had one, and the `string.gsub(text, " ",
"")` I used to read a drawn label back collapsed `NEXT DRIVE IN` to `NEXTDRIVEIN`. `Style.unspaced`
reads back the odd positions, which is the exact inverse, and every reader of a drawn spaced label
in `init.luau` and `ReportPanel.luau` now uses it.

Its own case (`hud_style.spec`, `unspaced(spaced(x)) == x`) was written AFTER the demonstration run,
so I have no `e1c6966` line for it — the function does not exist there. The failing line I do have
is better evidence anyway, because a gate found it rather than a constructed mutation:
```
(at 67a85a4, the first round-2 commit)
failed [client] match_client.spec:435 Expected value "NEXT DRIVE IN 12" (string), got "NEXTDRIVEIN 12" (string) instead
failed [client] match_client.spec:504 Expected value "NEXT DRIVE IN 12" (string), got "NEXTDRIVEIN 12" (string) instead
```

**7. `Hud.BOARD.PADDING` 16 → 12** (round 1 note): the board IS a card, the card's own `UIPadding`
is what indents it, and a second larger number pushed the table 8 px left of centre. Asserted in the
same case as finding 2 (`expect(Hud.BOARD.PADDING).to.equal(inset)`).

## Also in this commit: the Director's board-frame lever

`ForestTest.DRIVE_SECONDS_ATTRIBUTE` (`DHForestDriveSeconds`), read at the composition root through
`Match.WORLD_OVERRIDABLE`'s own `DRIVE_SECONDS` key — the same shape as the two playtest attributes
that file already has (`DHForestLayout`, `DHForestStartRole`). `ForestTest.driveSeconds` is the one
place a value is judged and it REFUSES rather than clamps: under `DRIVE_SECONDS_MIN` (20) a drive
would end before its own first release, and over the world's own length it would make a playtest
longer. Case: `forest_stand.spec`, "takes the Director's short-drive switch, and refuses a value
that would lie".

## Ready-check (standing rule A) — one Play of ≥ 86 s in DEV

1. **The Tool is in the CHARACTER**: at 15 s `character=[Shotgun] backpack=[Rifle]`; at 86 s the
   same.
2. **The console**: 10 831 chars, **0** lines matching `Stack Begin` / `attempt to` /
   `invalid argument` / `is not a valid member` / `Unable to cast`.
3. **The feature ran**: the report opened and closed on real `Tab` keypresses, drawing through the
   new scrolling body; the board measured `520x158`, which is finding 2's 24 px.

Frame: `.screenshots/20261018T150250Z-t201b-report-open-2.png`, against mockup board 4.

## What is NOT proven

* **No frame of the results board, and the blocker is the LOBBY — not the drive's length.** Two
  full Play sessions in the Forest Test: the player starts unenrolled (`team=nil`,
  `WAITING players`) and the drive never starts, so neither the new `DHForestDriveSeconds` nor the
  existing `DHForestStartRole` gets him into one. Walking onto a truck pad is the missing step and
  the pads only exist at runtime. The Director has since named the route for next time
  (`<runs-dir>/lobby-go.luau`). The board is asserted on the LIVE screen instead — its card, cells,
  team bar, section colours, height and now its footer clearance.
* **No frame of the report with ROWS in it.** A solo session hits nothing, and the Forest Test runs
  `BOARS_PER_DRIVE = 0`, so there is nothing to hit there at all. The rows, the tags, the selected
  row and the scrolling are `report_panel.spec`'s.
* **I set and restored two attributes on the Forest Test place, and got one of them wrong first.**
  `DHForestStartRole` was ALREADY `"hunter"` and my cleanup set it to nil; it is back at `"hunter"`,
  verified by reading it after. `DHForestDriveSeconds` did not exist before and does not now. Her
  four `DHFlag_*` overrides on that place were seen by the harness and left alone. The lesson
  (L-056) is to capture the prior value before WRITING, not before the run.
* **Karen has not seen any of it.** It is all look; she approved merging look work before she sees
  it (2026-10-17: *"it's ok to keep doing it"*).

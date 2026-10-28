# Task 304 -- the board off the shooting view, the hit card on

Task: 304
Round: 1
Base: `aed230ef`
Code commit: `d48ab19d7ff3295d43e944a48c360ec50f9ccd2f`

```
[harness] PASS: 34/34 checks @ d48ab19d7ff3295d43e944a48c360ec50f9ccd2f (clean tree) scope=all
```
`test2` N/A: `agents.needs_two_player` returns `[]` for all nine changed files (no `TWO_PLAYER_PATHS` path).

Karen, 2026-10-28, playing the range with the board over the left third of her view: *"if you remove
this shit will be good I will see where I hit / and hit card will be usefull"*.

## PLAN (core-quality step 0; this task touches none of the protocol's named paths -- no `Boar/`, `Weapon/`, `Shotgun`, `Ballistics`, `Flight`, `Effects`, no kill zone)

* **MEASURED NOW** -- the Director's own instrument, `<runs-dir>/p298` panel probe, on `main`: `RangeBoard`
  380 x 300 at abs (16, 188) of her 969 x 792 viewport, `Visible` the whole time she stands on the mat.
* **TARGET** -- `RangeBoard.Visible == false` whenever the E panel is shut, and its rectangle wholly
  inside the menu's when it is open. Not "smaller" and not "moved": nothing of it on screen while she shoots.
* **LEVER** -- `src/client/Hud/RangeBoard.luau` `render` (`root.Visible = menuOpen`, the file's only
  writer of that property) and `src/client/Hud/init.luau`'s frame `Position`/`ZIndex`.
* **MEASURED AFTER** -- the same probe, `<runs-dir>/304-panel.luau`, in DEV Play at the mat.

## What changed

1. **The board is a page of the menu.** `RangeBoard` stays the ONE writer of its frame; `Hud.step`
   tells it `RangePanel.isOpen()` (`setMenuOpen`, the `setNear` idiom) and `render` writes
   `Visible = menuOpen`. `Hud` draws the frame inside the menu's own footprint, off the same screen
   centre, at `RangePanel.LOOK.Z_INDEX + 3`. Numbers, columns, leads, miss gap and RESET: unchanged text.
2. **Every range hit sends the hunt's card.** `HitLog.sendCard` = `recordHit`'s own `buildCard`
   (extracted; one builder, one projection) + `toShooter`. `Range` holds the sender as an injected
   seam (`setCardSender`); `RangeBoot` wires `HitLog.sendCard`.
3. **A lane hit is not a row, in any world.** `HitLog.rowWorthy` (`not RangeData.isTarget(part)`)
   refuses one at the top of `recordHit` and counts `stats.rangeHits`.

## Claims

1. **Nothing of the board is on screen while she shoots.** DEV Play, on the mat, her viewport:
   `304-panel.luau` reads `RangeBoard ... Visible=false ... size=(536,192) Z=17`, and the frame
   `.screenshots/304-menu-shut.png` shows the left third clear. Verify: that probe, that frame.
2. **The numbers are in the menu when she presses E.** The live `RangePrompt` fired in DEV Play:
   `RangePanel Visible=true | RangeBoard Visible=true | Title: THE BOARD | Line1: no shots yet |
   Reset: RESET`, and `.screenshots/304-menu-open.png` shows the board inside the menu under its hint.
   Verify: `304-open.luau`, that frame, and `range_panel.spec` "puts NOTHING of the board on screen...".
3. **It is INSIDE the menu's rectangle, at every viewport.** Live abs: menu (204,18) 560x640, board
   (216,462) 536x192 -- contained. Verify: `range_panel.spec` "sits INSIDE the menu's own rectangle"
   (arithmetic on the shared 0.5 anchor, so it answers for a phone too).
4. **One owner.** `RangeBoard` is the only writer of that frame's `Visible` and children; `RangePanel`
   gains nothing. Verify: `grep -n "Visible" src/client/Hud/RangeBoard.luau src/client/Hud/RangePanel.luau`
   and `grep -n "rangeBoard" src/client/Hud/init.luau` (creation + `setMenuOpen` + the accessor only).
5. **A range hit sends ONE card, boar AND red deer, built by the hunt's own builder.**
   `hit_card.spec` "sends ONE card for a boar and for a red deer": `HitLog.lastCard()` -- the payload
   that WENT OUT -- carries `animalKind` male/hind, 2 dots, and a dot computed here off `Shape.dot`
   is found among them. Verify: that case.
6. **To the shooter only.** `toShooter` (`FireClient`) is the only send in `sendCard`; the broadcast
   path is a different function. Verify: `grep -n "FireAllClients\|FireClient" src/server/HitLog/init.luau`.
7. **It scores nothing.** Same case, real stores read before and after: `stats.hits`, `stats.downs`,
   `stats.traced`, `currentDrive().animalCount`, `HitLog.lastHits()` and `Economy.balanceOf` all
   unchanged, with a drive OPEN. Verify: that case.
8. **A miss shows no card -- the same stores read on the miss side.** `hit_card.spec` "sends NOTHING
   for a miss...": `lastCard()` nil, `cards` 0, `cardlessHits` 2, and the same five store reads.
   And `range.spec` "sends the hit card once per counted hit...": a `ShotResolved` with no
   `HitReported` sends nothing; the hit sends exactly one, carrying the report itself (identity);
   a second report of the same shot sends none.
9. **A lane hit writes no drive row, and the drive's own animal still does.** `hit_card.spec`
   "refuses a ROW for a lane target while writing one for the drive's own animal" -- both halves in
   one case, so it is a difference and not a tautology.
10. **FAIL FIRST (dirty-tree mutation run at `d48ab19d`, 30/34).** (A) `sendCard` returning false at
    its first line -> `hit_card.spec:527`, `:583`. (B) the `rowWorthy` guard deleted -> `hit_card.spec:605`.
    (C) `render` back to `root.Visible = record ~= nil` -> `range_panel.spec:437`, `:463`. Nothing else failed.

## What I could NOT verify

* **Karen's place, on screen: NOT PROVEN.** Her Forest Test syncs from the merged-main copy, not this
  branch, so every live reading above is **DEV ONLY**. The dispatch assigns the real-click re-run to
  the Director.
* **The card on screen after a real shot: NOT PROVEN ON SCREEN.** Firing a real shot at a lane target
  needs a real click in the Play window; the card is proved by claims 5-8 and dies with mutation (A).
* **Carried bug, NOT fixed and NOT mine (303a note (c)):** the board prints the PREVIOUS pace's
  crossing time for up to ~22 s after a pick (`blankRecord` seeds `crossingSeconds` from
  `trial.lastCrossingSeconds`). This task moves the display and touches neither that field nor its
  writer, so the menu inherits it verbatim. Queued as 303a(c).

ANSWERED: L-136 -- no spec failed on the PASS run (34/34, 0 failed both sides), so nothing is called a flake and no control run was needed.
ANSWERED: L-127 -- every visibility claim says MET / NOT PROVEN ON SCREEN; claims 1-3 are DEV frames and the live probe, Karen's place is the Director's.
ANSWERED: Verdict-298 rule -- mutation (A) stubs the range's card sender to send nothing and `hit_card.spec:527` and `:583` fail; the card case cannot pass without a real send.

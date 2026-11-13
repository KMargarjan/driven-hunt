PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: this task has NO core item -- it is
the map panel, not animal behaviour and not shooting. The thing Karen will judge (the X, the chip
markers, the ringed pick, the card rows) HAS been seen in her place: `361-R2-AFTER-open.png`,
`361-FT-AFTER-mark5.png`, `361-AFTER-zoom-stands.png`, `361-R2-AFTER-hover8.png`,
`361-FT-AFTER-row8.png`, `361-R2-ROWX-row2.png` and `361-R2-ROWX-close.png` are her own Forest Test,
C1, her flags, at code commit `11faec07`, each opened and described, against a BEFORE pair at
`3533e137`. I cannot open an image; I checked those descriptions against the code and the numbers
agree. NOT seen by anyone: a real touch tap (`TouchEnabled` false on that PC, so "44 px is enough for
a thumb" is a measured pixel size plus the HIG number), and this map on a real phone.

## Notes (non-blocking)
- `MapUi.applyStandAccent` / `applyPick` -- `standHover` survives the window closing. `applyPick`
  sets `node.hit.Visible = on` and `list.Visible = on`, and Roblox fires no `MouseLeave` for a widget
  hidden under the cursor, so the hover ring stays drawn on the stand the mouse was last over and is
  still there at the next open until the mouse moves. One `MapUi.setHoverStand(nil)` in `applyPick`'s
  not-pickable arm (or in `setOpen(false)`) closes it.
- `map_ui.spec` case 34b, the 1366 arm -- `expect(list.Position.X.Offset >= full.Size.X.Offset)` is a
  tautology: `layoutFor`'s beside branch writes `math.round(panelWidth + gapPx / shown)` and
  `full.Size.X.Offset` IS `panelWidth`, so with `gapPx > 0` it cannot fail. The case's teeth are
  entirely in the 400x800 arm. Worth saying in the case's comment, since the note it prints
  (`1366 beside | 400 over`) reads like two measurements that both bite.
- `map_ui.spec` case 35 -- `expect(pickRing.Size.X.Offset).to.equal(CONFIG.FULL_STAND_PX +
  CONFIG.STAND_PICK_PAD_PX)` still assumes stand 5 is a GROUND stand: `place` sizes each ring from
  `node.tower`, so the day `Grid.towerStands("C1")` gains 5 this reddens on correct code. It is round
  1's note moved one stand over. Size it against `if towers[5] then FULL_STAND_TOWER_PX else
  FULL_STAND_PX`, the way case 36 already does for the marker.
- `layoutFor`, the pushed list -- the fix costs the over-the-panel list `(topPx - (FULL_TITLE_HEIGHT +
  FULL_PADDING)) * shown` of visible height, which at the 400x800 the case measures (list top 60 real
  px, panel scale under 0.5) is 35-46 real px, about one 44 px row of the four it had. It is a
  `ScrollingFrame` with `CanvasSize` at `rows * 44`, so no row is unreachable; it is a row more
  scrolling on a phone, and nothing in the request says so.
- rule 4 -- the commit carries another task's deliverable: `reviews/task-360b/MEASUREMENTS.md`, the
  360b `ESCALATE.md` entry and the 360b `TASKS.md` row. `REQUEST.md`'s "What changed" says
  "`src/client/Hud/MapUi.luau` only" and never mentions them. Docs-only, breaks nothing, and 360b was
  dispatched with "no review round: the Director checks the file" -- but the Director should know
  360b's file rides in on this PR.
- `MapUi.standRowText` -- after this change nothing in `src/` calls it; `map_ui.spec` is its only
  reader. Kept deliberately (its own comment says why), but it is now test-only surface.
- round 1's notes 5 and 11 are still open and are correctly left for a queue, not for a round: the
  `high` state has lost its own word in the list (`standRowParts` falls through to `Free` when
  `HighSeats.standsFor` and `Grid.towerStands` disagree), and `docs/design/stand-pick.md` section 9.5
  now describes a row that no longer exists.
- `REQUEST.md` claim 4, "the picked ring is the brighter, thicker, larger one" -- larger only on one
  and the same stand: a tower's hover ring is `20 + 8 = 28` against a ground pick ring's `16 + 10 =
  26`. The case asserts the two pads, which is the right statement; the prose overstates it.

---
REVIEWER verdict on commit `9db5ff7a96bb365391c9bb0ff56a10901ca7b49a` (round 2) · 2026-11-13 22:26 UTC · session cost $4.33, 41 turns · written by tools/agents.py

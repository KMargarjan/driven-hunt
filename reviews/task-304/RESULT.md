PASS (item 1, 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: **nothing in this change has been
seen in Karen's place.** What was seen: a DEV Play window — `304-panel.luau` reading `RangeBoard
Visible=false size=(536,192) Z=17` with the menu shut, `RangePanel Visible=true | RangeBoard
Visible=true | Title: THE BOARD | Line1: no shots yet | Reset: RESET` with it open, and two frames
described in prose (`304-menu-shut.png`, `304-menu-open.png`). What was NOT seen, by the request's
own admission: **item 1** (the left third of *her* view clear while she shoots — her Forest Test
syncs from merged main, so every reading above is DEV only), and **item 2** (the hit card on screen
after a real shot at a lane target — no real click was fired; the card is proved only by
`hit_card.spec`/`range.spec`, server-side). The card's own drawing path checks out by reading —
`ReportClient` dispatches `kind == "hit"` with no drive filter and `HitCard.start` wires
`ReportSystem.Hit:Connect(HitCard.show)` unconditionally, and `show`/`textFor` read neither `drive`
nor `at` — so `drive = 0, at = 0` cannot suppress it; but that is a code reading, not a screen.

Delete-the-producer, case by case (duty (a)):
- `hit_card.spec` "sends ONE card for a boar and for a red deer" — `expect(HitLog.sendCard(fired)).to.equal(true)`
  and `after.rangeCards == 1` die with `sendCard`/`buildCard` removed. The dot assertion is a real
  cross-check: `Shape.dot(part.CFrame, part.Size, points[1].position)` is computed in the spec and
  looked for among `HitLog.lastCard().dots` — the payload that went out, not one rebuilt.
- `hit_card.spec` "refuses a ROW ... while writing one for the drive's own animal" — both halves in
  one case; with `rowWorthy` deleted `recordHit(lane)` answers true and `stats().rangeHits` is nil.
  Bites, and it is a difference, not a tautology.
- `range.spec` "sends the hit card once per counted hit" — with the `state.card` block deleted
  `#sent == 1` fails. `expect(sent[1]).to.equal(fired)` is identity on purpose and CAN fail (a
  rebuilt table would not be the same object), so it is not a same-identity comparison.
- `range_panel.spec` "puts NOTHING of the board on screen..." and "sits INSIDE the menu's own
  rectangle" — both read the RUNNING Hud's frames (`player.PlayerScripts`, `LiveHud.rangeBoard()`),
  not frames the spec made. Revert `render` to `root.Visible = record ~= nil` and the first fails at
  `expect((board).Visible).to.equal(false)` after `setRecord` (`setMenuOpen(false)` early-returns, so
  no render repairs it); revert the frame to `AnchorPoint (0,0.5) / Position (0,16,0.5,0)` and the
  second fails at `Position.X.Scale == 0.5`. The containment is arithmetic on two frames both
  asserted at scale 0.5 with their anchors asserted, so it answers for any viewport, and
  `top > CONFIRM_HEIGHT/2 + 48` is the hint's own bottom (8 + 40), not a magic number.

Checked and true: harness line names `Code commit: d48ab19d` with "(clean tree) scope=all", 34/34 —
the same count as task 303, so no spec went missing; `paperwork-after-code-commit.txt` says only
`reviews/task-304/REQUEST.md` followed it. `test2` N/A is correct: none of the nine code files is
under `TWO_PLAYER_PATHS`. Z arithmetic: `RangePanel.LOOK.Z_INDEX` 14, children 15/16, board 17 — the
claimed `Z=17`. Geometry: board top-left = centre + (-268, +124), i.e. panel-local (12, 444), bottom
636 inside 640, and the hint ends at 438 — no overlap, as the comment says. The `buildCard`
extraction is faithful (`hits = report.pellets or 1` = old `dot.pellets`, `distance = report.nearest
or 0` = old `dot.distance`, same `zone`, same `sinceOpen(at)`, same `Shape.cardDots` arguments).
`isTarget` holds: `Body.create` parents the trunk into the runtime's folder and `buildZones` parents
every zone part under the trunk, and the drive's folder is `"Boars"`, so one `FindFirstAncestor`
separates them. No require cycle (`RangeBoard` → `RangePanel`, which requires only `RangeData`). A
lane KILL writes nothing either: `RangeBoot` never connects its runtime's `Downed`, and `recordDown`
returns early on an animal with no row. `sendCard` sends only through `toShooter` (`FireClient`);
`broadcast` is a different function.

## Notes (non-blocking)
- `src/server/HitLog/init.luau` `sendCard` — no guard that the target IS a range target, which is the
  missing mirror of `rowWorthy`. Both `ForestTestBoot` and `RangeBoot` listen to `Weapon.HitReported`,
  so a hit on a DRIVE animal taken while standing on the mat inside the pending window sends TWO
  cards for one shot: `recordHit`'s (real `drive`/`at`) and then `Range.onHitReported` →
  `sendCard` (`drive = 0, at = 0`). The second replaces the first, and since `HitCard.markFatal`
  joins on `|event.at - showing.at| > 1e-3`, the kill X is then lost for that shot. Unreachable in
  practice today (drive animals are not in the lobby), which is why this is a note. Fix is one line:
  send only when the part is a range target — `if HitLog.rowWorthy(part) then return false end` in
  `sendCard`, or the same test in `onHitReported`.
- `src/server/RangeBoot.server.luau` — the comment above the `HitReported` listener still says *"The
  range writes no score and no money: `HitLog.recordHit` is `MatchBoot`'s line and it records nothing
  while no drive is open (`HitLog.openDrive` is never called here)"*. That is the belief task 304
  exists to correct (design 9.4: *"in Karen's place a drive is open while she stands at the lobby
  range"*). The file was changed in this commit and the sentence was left; it should name `rowWorthy`
  as the actual reason.
- `tests/server/range.spec.luau` — two world builders still write `world.folderName = "RangeTargets"`
  as a literal where `RangeBoot` now writes `RangeData.TARGETS_FOLDER`. Same value today; the point of
  the new constant was "named once", so a rename would split the spec from the runtime silently.
- `tests/server/hit_card.spec.luau` — the `Economy.balanceOf(...)` reads in both new cases cannot
  fail: no code on the `recordHit`/`sendCard` path touches `Economy` (money is `Match`'s `onDowned`
  listener, and `RangeBoot` connects none). They are harmless, but claim 7's "no money" is actually
  guaranteed by that missing wiring, not by this assertion — worth saying so where it is asserted, so
  nobody later treats the line as the money gate.
- `src/server/HitLog/init.luau` `stats` — `cards` now totals hunt cards AND range cards, with
  `rangeCards` as a subset rather than a separate total. Any live reading that compares `cards` with
  drive hits (design section 12's checklist style) will drift once she uses the range; it needs
  `cards - rangeCards`.
- `reviews/task-304/REQUEST.md` claim 3 — "Live abs: menu (204,18) 560x640" is not consistent with the
  969 x 792 viewport the PLAN names: at 0.5 scale the menu's top would be 396 - 320 = 76, not 18 (the
  x reading, 204 + 280 = 484, does match 969/2). Presumably a shorter DEV Play window; as pasted, the
  two readings cannot both come from the viewport the PLAN measured. Prose only — containment is
  proved by the spec's arithmetic, not by these absolutes.

---
REVIEWER verdict on commit `b441ae6673b144255e7fe309ef1b9b3bd7f69617` (round 1) · 2026-10-28 09:02 UTC · session cost $4.47, 43 turns · written by tools/agents.py

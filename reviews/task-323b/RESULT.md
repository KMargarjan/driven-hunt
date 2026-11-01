PASS (item 6, 7, 8 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: **nobody has seen the thing this
task draws.** What WAS seen in a place, and described in words, is `.screenshots/t323-pick.png` /
`t323-pick-after.png` -- the full map auto-opening in `ASSIGNING` with `0:10 LEFT`, the footer
reading `click a stand`, the task-158 start card over the panel and then gone. What was NOT seen, in
Karen's place or any other, is **the nine numbered stand marks themselves**: the orange diamond on
his own, a dimmed square with a holder's name, the brass ring on a seat, the dimmer barred square --
and **no real mouse has ever clicked a pad**. Items 6, 7 and 8 rest entirely on engine numbers read
by `map_ui.spec` cases 28, 24 and 27 inside the REAL client (`AbsolutePosition`/`AbsoluteSize` off
the drawn nodes, `Active`/`Visible`, the UIStroke's `Enabled`, the holder label's `Text`) plus
`MapUi.tapStand` driven by parameter. That is wiring and geometry, not a picture and not a gesture,
which is exactly what design 13.3's own "what no spec can prove" paragraph says. The reason is a
world fact and it is reported honestly: `MapUi.geometryFromMap` returns `stands = {}` and the
client's forest-geometry door sits inside `if Map.EXPECTED_WORLD == "forest-test"`, so DEV's map has
nothing to photograph and nothing to click; `ESCALATE.md` carries the request for one Forest Test
pass. Verified consistent: `[harness] PASS: 34/34 @ cf3beb0c (clean tree) scope=all` and
`[harness2] PASS: 36/36 @ cf3beb0c (clean tree)` both name the request's `Code commit:`, and
`paperwork-after-code-commit.txt` says only `reviews/task-323b/REQUEST.md` changed after it.

No blocking finding. Claims 1-3 verified by reading `applyStandSettle` and `Match.standSettlePlan`
(`standMoved` does handle the two nil cases, so the "a deal the world cannot answer" case is real);
the road-swap case derives `firstStand` from `HighSeats.dealLine` rather than hardcoding it and
fails both if `standSettlePlan` is gutted and if sweep A is removed, so the note-(b) seam is closed.
Claim 2's own admission is accurate and I checked it by reading: the carry loop iterates exactly
`plan` and holds no second rule. Claims 4, 5, 9, 10 verified against the source; `fullMapVisible` is
`open and not suppressed and not reportOpen`, so case 25's `want` is a real re-derivation and not the
function under test; case 26's `grab()` asserts both tags present before each exit, so it cannot pass
with `applyPick` deleted; case 31's `never.to.equal(words31.Shooters.Assigning)` fails if the
`Objective.text` pick branch is deleted. Flag-off identity holds: `Phase.pickWindow` is false,
`applyStandSettle` returns at `anyClaim()`, `Hud.pickingStand` is false, `standStateFor` is never
called with a non-empty count, and `Cursor.release`/`Input.releaseHold` are both idempotent on a tag
that was never held.

## Notes (non-blocking)

- `src/client/Hud/MapUi.luau`, `setPickWindow` / `pickOpenedByWindow` — **design 9.6's "unless the
  player opened it himself with M since" is not implemented, and this one should be fixed before the
  flag flips.** The boolean records only who opened the map, never that the player took it over
  since: the window opens it (`pickOpenedByWindow = true`), he presses M to close it, he presses M
  again to open it himself -- and `elseif was and not now_ then if pickOpenedByWindow and open then
  MapUi.setOpen(false)` still takes it off him at the horn. Nothing in `setOpen` or `toggle` clears
  the flag. Fix: clear `pickOpenedByWindow` in `MapUi.setOpen` whenever the auto-open is not the
  caller. Case 30 tests the map he opened when the window never opened one, which is the other
  sequence. Reachable only with `STAND_PICK` on, which is why this is a note and not a block.
- `src/client/Hud/MapUi.luau`, `applyPick` — design 9.7's *"Zero added per-tick cost. `MapUi.render`'s
  20 Hz tick is untouched"* is no longer true. `applyPick` is called from `MapUi.applyVisibility`,
  which `render` calls every tick, and its body is unconditional: `for _, node in ipairs(standNodes)
  do node.hit.Active = on; node.hit.Visible = on end`, plus `Cursor.release(PICK_TAG)` /
  `WeaponInput.releaseHold(PICK_TAG)` and the footer's `node.Visible = text ~= ""`. In a nine-stand
  world that is 18 no-op property writes 20 times a second, forever, flag off included (DEV escapes
  it only because `standNodes` is empty there). Edge-trigger the body on a change of `on`, the way
  `setStandStates` edge-triggers the marks.
- `src/client/Hud/MapUi.luau`, `setStandStates` — the header's reason for having both checks is
  false: *"a version that forgot to move would otherwise freeze the picture"*. `if version ~= nil and
  version == standVersion then return end` runs FIRST and returns before the element-by-element
  compare is reached, so a version that forgot to move freezes the picture exactly as it would
  without the compare. The compare's real job is to spare the writes when a version DID move over
  unchanged states, which is what case 24's `setStandStates(states, 2)` measures.
- `reviews/task-323b/REQUEST.md` claim 7 / `tests/client/map_ui.spec.luau` case 24 — "Case 24 reads
  the colour, transparency, stroke and name off the drawn nodes" overstates by one property: there is
  no `BackgroundColor3` assertion anywhere in the file (`grep BackgroundColor3
  tests/client/map_ui.spec.luau` -> no matches). Design 13.3's own case 24 also asks for *"and
  **nothing else**"*, which nothing covers. Little is lost -- `node.frame.BackgroundColor3 =
  MapUi.COLORS.stand` is unconditional and restores the value `drawGeometry` already built, so
  asserting it proves close to nothing -- but the claim should say three of four.
- `src/client/Hud/Objective.luau`, `CONFIG.TEXT.ShooterPick` — the comment says *"31 CHARACTERS AT A
  TWO-DIGIT COUNT"*; `"pick your stand on map - "` is 25 characters, so a two-digit count gives 27.
  The 33-character bound and `hud_clarity.spec`'s `TextFits` sweep are unaffected; only the number in
  the comment is wrong.
- `src/client/Hud/MapUi.luau`, `CONFIG.STAND_TAKEN_TRANSPARENCY` — the comment names
  `PINNED_TRANSPARENCY` as the reason (*"so 'not available to you' reads the same everywhere on this
  map"*) but the line is a second copy of its number, `0.45` written twice. Design 9.4's source
  column names `MapUi.CONFIG.PINNED_TRANSPARENCY`. `STAND_TAKEN_TRANSPARENCY = 0.45` and
  `PINNED_TRANSPARENCY = 0.45` drift apart the moment either is retuned, which is the one thing the
  comment promises cannot happen; `STAND_TAKEN_TRANSPARENCY = MapUi.CONFIG.PINNED_TRANSPARENCY` (or
  reading it at the write site) says it once.
- `tests/server/match_stand_pick.spec.luau` case 1 — one assertion was lost in the move and cannot be
  recovered where the words now live. The old case asserted
  `StandPick.REASON[string.upper(reason)] == reason` for every drawn word, i.e. that each key of the
  word table IS a wire reason. The replacement at the screen can only manage
  `expect(string.lower(reason)).to.equal(reason)`, because a client cannot require
  `ServerScriptService.Match.StandPick` -- so a mistyped key in `MapUi.CONFIG.PICK_WORDS`
  (`takn = "taken"`) would silently draw nothing and no case in the repo would notice. Worth queueing:
  the eight reason strings beside `Drive.StandVerdict` in `src/shared/Drive/init.luau`, which already
  describes them in prose (*"one of `StandPick.REASON` otherwise"*), would give both sides one table
  to assert against.
- `tests/server/match_stand_pick.spec.luau`, "names NOBODY with an empty claim table" —
  `expect(Match.stats().standSettlePlanned).to.equal(0)` is guaranteed by `applyStandSettle`'s own
  `if markerSet == nil or not StandPick.anyClaim() then return end` and so cannot tell a correct plan
  from a missing one; the 4-layout x 8-count parameter sweep in the same case is what carries it. Same
  shape as the existing case 17, so not introduced here -- but the claim-2 sentence "`stats.standSettlePlanned`
  is the same count off production and is 0" is worth reading as "the guard held", not "the plan did".
- `src/client/Hud/MapUi.luau`, `renderDrawer` — `standMine` moves the `Target` diamond on BOTH
  drawers, and the minimap's squares are not in `standNodes` (`drawGeometry` `continue`s before
  building a node for them), so `node.frame.Visible = word ~= "mine"` never reaches them: on the
  minimap the 6 px square stays drawn under the diamond. Design 9.4's *"the square and its index step
  aside"* holds on the full map only. Cosmetic, and the minimap deliberately has no pads and no
  states -- but the sentence is wider than the code.
- `src/client/Hud/MapUi.luau`, `teardown` — it zeroes `pickWindow`, `pickIsHunter` and
  `pickOpenedByWindow`, so a geometry rebuild mid-window (a layout change during `Assigning`) loses
  the auto-open's record: the next `renderObjective` frame re-enters the window with `open` already
  true, takes the `if enoughLeft ~= false and not open` guard, and leaves `pickOpenedByWindow` false
  -- after which the window will not close the map it opened. The opposite direction from the first
  note and far narrower; naming it so both are fixed at the same site.
- For the ARCHITECT, `docs/design/stand-pick.md` — 13.3's case 26 (*"`Cursor.isFree() == false` and
  `Input.isHeld() == false`"*) is now wrong and the spec is right: `ReportPanel` correctly holds the
  cursor free under its own `"report"` tag while the report is up, so `isFree()` is TRUE at that exit
  and only the TAG can answer. `map_ui.spec` case 26 reads `Camera.Cursor.stats().tags` and
  `Weapon.Input.holdTags()` instead and says why on the line. 5.2's *"Only claimants are moved"* and
  12's `standsSettled` row are still the stale pair the round-2 note (h) queued, now contradicted in
  the code's own header as well.

---
REVIEWER verdict on commit `35a5d53fcea46984c2f47baad61e9e6d2ddf2c02` (round 1) · 2026-11-01 05:00 UTC · session cost $4.05, 33 turns · written by tools/agents.py

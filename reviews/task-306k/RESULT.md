PASS (item 1, 2 NOT PROVEN)

Round 1's two blocking findings are closed in the shipped code, and both offered cases die when the
producer is removed:

- `src/server/Range/init.luau` / `Range.holdForSettle` now coalesces by root -- `for _, row in
  ipairs(state.settling) do if row.root == part then row.left = SETTLE_SECONDS; part.Anchored = true;
  return true end end` before the `table.insert`, so the first `was` is the one `settleStep` restores.
  Delete that loop and `range.spec` "releases a climbed body's anchor after the settle" fails at
  `expect(Range.settling()).to.equal(1)` after the second `Range.holdForSettle(twice)` (it would read
  2), and then at `expect(twice.Anchored).to.equal(false)`.
- `Range.look` now keeps the word the record had (`if word == nil then ... existing.position end`),
  and `matEdges` makes an edge only from `spot ~= nil and word ~= nil`. Delete the fallback and
  `range.spec` "keeps the tally when a man walks between the bench and his own ladder" fails at
  `expect((Range.recordOf(man) :: any).shots).to.equal(1)` after the PivotTo to `between`:
  `recordFor`'s `existing.position ~= position` sees `"bench" ~= nil` and hands back `blankRecord`.
  I traced the walk through `Range.spotAt` myself -- `ahead = -8`, `halfZ = 4`, `reach = 21`, deck
  rect missed by 6 -- so `spot 1, nil` is the real answer there, and the deck arm reaches
  `HighSeats.minYFor` at `anchor.Y + 16`, so the counter-assertion (`shots` 0, `treestand`) is real
  and this is not "never change the position".
- `Range.standReach`'s `wayDown` = `backStuds + |LADDER_OFFSET_STUDS| + footClearStuds` = 21 matches
  `climbDownTargetFor`'s own Z exactly (`foot.Z - dir * footClearStuds`, foot 18 uprange of the mat).
  Remove the `wayDown` arm and `reach` falls to 19.10, `ahead >= -reach` fails at -21, and
  `expect(RangeData.spotAt(DEV_AT, down, LAYOUT, dir, tops)).to.equal(2)` fails.
- `Range.downPromptRiseFor` = `riseStuds + eyeOverRootStuds` = 5.0 puts the point exactly at
  `climbTargetFor`'s eye. Revert to `deckRise` 1.6 and the viewport case's `expect(at.Y > 0 and at.Y
  < KAREN_VIEWPORT.Y - HOTBAR_BAND)` fails (y ~1059 at FOV 70, against the 735 bound), and the
  prompt case's `expect(math.abs((downPoint :: Vector3).Y - eyeY) < 1e-3)` fails by 3.4.
- `Range.distancePickOf` / `valuesFor`: delete either and "lights the DISTANCE chip on the deck"
  fails -- `expect(RangePanel.selected("distanceStuds")).to.equal(base)` would read 139, and the lit
  chip's `expect(entry.label).to.equal(RangeData.distanceText(base + back))` would read 125.
  `RangeBoard` reads `record.distanceStuds` directly, so the board's 139 and the chip's value 125
  are consistent, and `optionAllowed` still refuses 139.
- `RangePanel.climbTakesKey` gates on `KeyboardKeyCode == RangePanel.KEY` (E); `Build.luau` sets
  `prompt.KeyboardKeyCode = key` from `CLIMB.UP_KEY`/`DOWN_KEY`, so the gate reads a value that is
  really written. Revert to `isClimbPrompt` semantics and
  `expect(RangePanel.climbTakesKey(climbDown)).to.equal(false)` fails.
- Both material arms now read `layout.SURFACE.BERM` (`writeTerrain`'s berm and bank fills,
  `Build.build`'s `onGround` for "Berm" and `bankName(leg)`), so round 1's split is closed.
- Harness: `[harness] PASS: 34/34 @ 94a050a8 (clean tree)` names the request's `Code commit:`;
  `paperwork-after-code-commit.txt` says only `reviews/task-306k/REQUEST.md` followed it. selene,
  stylua and rojo build all exit 0.

Rule 5, stated so this PASS is not read as rule 5 having been met: the request describes live
evidence from Karen's place for the task's core items -- `306k-tools.luau` reading `held=Rifle`
through a real `E` and a real `F` with the backpack unchanged at every reading (item 3, the gun
loan), the re-swept `T6: 180 shots, 180 stopped at or before the berm, 0 not` with the crest raycast
reading 171.02 at three z (item 2, the shot path), and BEFORE/AFTER frames at the same camera points
plus the deck menu with 139 lit -- and I cannot see any image, so none of that is verified here
beyond the code being able to produce it. The two things named on line 1 are ROUND 2's own fixes:
claim 1 (one settle row per root) was exercised only by the spec -- the request's own live double-`E`
is admitted "weakly, because the second press had no prompt left to trigger" -- and claim 2 (the
in-transit band keeping the tally) has no live frame at all. The Builder also states he could NOT
verify that the raised berm reads as a "mountain" rather than an earth wall; that one is Karen's eye.

## Notes (non-blocking)
- `src/shared/Range/init.luau` / `BERM.slopeSteps`, `src/server/Range/Build.luau` / `Build.bermBoxes`
  — the 179-stud lane is still inside the batter and the raise deepens it. With `steps = 6`,
  `extra = 12 * (7 - k) / 6` puts band faces at 176 (height 3) and 178 (height 6), and
  `Range.laneCentre` returns `anchor.Y` for the target's Y — so at z 179 the earth is now 6 studs
  where it was 4 at `height 10 / slopeSteps 4`. Pre-existing from B8's `slopeRun = 12` and correctly
  queued rather than claimed fixed, but the request's "about 2 studs to 3" understates it; the
  numbers are 4 to 6. Queue: `slopeRun` <= 9, or more `behindStuds`.
- `src/server/Range/init.luau` / `Range.holdForSettle` — still a second writer of a PLAYER's root
  `Anchored` (round 1 note, unaddressed). `src/server/Match/Body.luau`'s header: "THIS module owns a
  PLAYER's character: its team, its position, its freeze", and `Body.holdCharacter` writes
  `root.Anchored = true`. A tie or freeze landing inside the 0.4 s window is undone by `settleStep`'s
  restore of `was`. One holder shared with `Match.Body`, or routing the climb's move through it,
  would close it.
- `src/shared/Range/init.luau` / `Range.standReach` — zero margin, unaddressed. `wayDown` 21 is
  exactly `-ahead` at `climbDownTargetFor`'s point, so `spotAt`'s `ahead >= -reach` passes only by
  equality; any fractional row Z or a retune of `footClearStuds` flips it straight back to the
  empty-backpack symptom this task exists to fix. A stud of slack, or a case asserting the margin.
- `src/server/Range/init.luau` / `moveBody`; `src/client/Hud/RangePanel.luau` / `watchClimbPrompts` —
  the two wirings are still uncovered. Delete `Range.holdForSettle(model.PrimaryPart or ...)` from
  `moveBody` and the spec passes (it drives the queue directly); revert the two `PromptShown` /
  `PromptHidden` connections from `climbTakesKey` to `isClimbPrompt` and `range_panel.spec` passes
  (it calls `climbTakesKey` directly). Both rest on the live frames alone.
- `tests/client/range_panel.spec.luau` — the viewport case still reads `camera.FieldOfView` off the
  live camera while the claim's arithmetic is "a 70-degree FOV reaches 35". At a wide FOV the
  fail-first line `expect(floor.Y > KAREN_VIEWPORT.Y - HOTBAR_BAND)` stops holding (at 120 the old
  1.6 point projects to ~664, under the 735 bound). Pinning 70 would make the case say what it means.
- `tests/server/range.spec.luau` — two assertions are transcriptions of the functions under test
  (verdict 278): `expect(RangeData.standReach(LAYOUT)).to.equal(math.max(feet, wayDown))`, and
  `eyeY = stood.Y + LAYOUT.CLIMB.eyeOverRootStuds` against `downPoint.Y`, which is the same sum by
  construction. Both bite only through the lines beside them (`spotAt(down) == 2`, `standReach >
  feet`, and the `> 45` degree line), which is enough; the transcriptions are noise.
- `tests/server/range.spec.luau` — the new `deckTopOf` helper was inserted between the comment "THE
  PROMPTS THEMSELVES: two per station, with the two KEYS..." and the `it` that comment describes, so
  the comment now reads as the helper's.
- `src/server/Range/init.luau` / `Range.settling` — "for the spec and for `Range.stats`" still
  overstates; `Range.stats()` clones `state.stats` and adds `started`, `built`, `targets`, and never
  reads it.
- `docs/design/shooting-range-lobby.md` — stale after the berm raise: §4.1's table still reads
  "`height` 10 ... inside the refused 6 m upper bound", §5.x's part list "crest +10", and §8.2's
  decided fallback "four `FillBlock`s, 2 studs per step" against six 3-stud bands. The change did not
  set out to fix the doc.
- `src/server/RangeBoot.server.luau` / `matEdges` — `onMat` keeps an entry for a player who
  disconnects while on a firing position (nothing clears it on `PlayerRemoving`). Same shape as the
  boolean it replaced, so not made worse, but one line in a leave handler would close it.
- `reviews/task-306k/REQUEST.md` — "What changed" item 2 names `BERM.height`, `BANK.size.Y` and
  `SURFACE.BERM`; the diff also moves `BERM.slopeSteps` 4 -> 6. Claim 1 says the second hold
  "refreshes `left` and keeps the FIRST `was`" — correct — but claim 3's "replaces the typed
  `CLIMB.deckRise`" is listed under item 1 in "What changed" and under claim 3, two numbers for one
  fix.

---
REVIEWER verdict on commit `5514ea3a2d9b2f8eb3d845392a02a8e8008c164f` (round 2) · 2026-10-30 00:31 UTC · session cost $3.08, 36 turns · written by tools/agents.py

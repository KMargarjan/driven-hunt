PASS (item 1, 2, 3, 4 NOT PROVEN)

Round 1's two blocking findings are fixed. `Hud.renderObjective` now reads
`RangeData.promptPointOf(rangeMat)` and asks `RangeData.atSpot` about that point, and
`promptPointOf` answers both shapes (`parent:IsA("Attachment")` -> `WorldPosition`,
`:IsA("BasePart")` -> `Position`), so the attachment no longer kills the signal; `me` is
`Hud.localPosition()` = `PrimaryPart.Position`, which is the point the engine measures
`MaxActivationDistance` from, so the client's closer and the engine's offer are now one
measurement. `.agent-evidence/lint-stylua.txt`: `$ stylua --check src tests` `(exit 0)`.
Harness line names the `Code commit:` 59e0b2c9 "(clean tree)";
`paperwork-after-code-commit.txt` says OK (only `reviews/task-303/REQUEST.md` followed it).

## Notes (non-blocking)

- Rule 5, stated so this PASS is not read as rule 5 having been met: NOTHING in this change has
  been seen in Karen's place. The request says so itself — *"ON SCREEN IN KAREN'S PLACE: nothing
  here."* Item 4 (the WALK crossing) is the core item — animal behaviour — and is proved only by
  `range.spec` against the fake rail animal in DEV. Item 1 (a new 1.2 x 4 x 1.2 `Post` with the
  prompt on it), item 2 (the menu closing) and item 3 (the board's `.416`) are proved by cases
  plus arithmetic about a 969 x 792 viewport, not by a frame. The BEFORE string was read off
  `p298/14-walk-crop.png`; the AFTER string has not been read off anything.

- Delete the producer, by reading, all five cases: each bites.
  `range.spec` "hangs the prompt on a POST" dies at `expect(post).to.be.ok()` with `Build`'s post
  block gone, and errors at the `RangeData.promptPosition` / `promptPointOf` calls with the shared
  code gone. `range_panel.spec` "closes on RELEASE THE TARGET" dies at
  `expect(RangePanel.isOpen()).to.equal(false)` with `RangePanel.setOpen(false)` removed from
  `confirm`. "prints the gun's OWN cartridge label" dies at `string.find(text, wanted, 1, true)`
  with `ammoText` reverted to `tostring(record.ammo)` — every row's label differs from the wire
  word (`SLUG`/`Slug`, `BUCK`/`Buck`, `.416`, `.45-70`) and none of those strings occurs anywhere
  else in `rowText`. "puts the prompt inside Karen's viewport" errors at `promptPosition`; its
  engine cross-check is the engine against this arithmetic and not a value against itself, and
  the `matTop` line is the known-bad input. "times a WALK picked MID-WINDOW" dies at
  `expect(err <= Range.CONFIG.CROSSING_TOLERANCE)` — traced by hand: 3 s of TROT (~11 studs/s)
  carries the target ~33 of the 40 studs from the west end, leaving it ~7 studs short of centre,
  so the old `timeWindow` would time ~27 studs at 4.5 = ~5.9 s against 8.89, a 33 % error.

- `src/client/Hud/init.luau` `renderObjective` — the caller itself is still asserted by nothing.
  Revert `local promptAt = RangeData.promptPointOf(rangeMat)` to `rangeMat.Parent` and the whole
  suite stays green: `range.spec`'s POST case calls `RangeData.promptPointOf` directly and
  `range_panel.spec`'s *"gives both doors back when he walks off the spot"* calls
  `RangePanel.setNear` itself. That is the gap `reviews/task-298/RESULT.md` already filed and the
  second half of round 1's "Required". No spec in the repo drives `Hud.renderObjective`, so it is
  not a one-line fix; the cheap shape is a pure `Range.atSpotOf(prompt, playerPosition, layout)`
  that wraps both calls, leaving the Hud one call that a case can drive on the real built folder.

- `src/shared/Range/init.luau` `LAYOUT.POST` comment — the request claims *"the `LAYOUT.POST`
  sight-line arithmetic is rewritten with the right numbers (1.22 studs at the window's far end,
  2.43 at the lane's...)"*. It is not: the file at HEAD still reads *"a target at the window's far
  end subtends 1.9 studs of X at this post's Z, and the post stands at 3."* The right numbers are
  the ones the request names — ±20 studs at Z = 7 is 1.12, and the lane's ±40 at the post's far
  face (Z = 7.6) is 2.43, inside the post's own X span of 2.4..3.6. The shot clears vertically
  (a ~5.5-stud eye to a chest 125 studs out passes ~1.3 studs over a 4-stud post at Z = 7), so the
  geometry is fine and only the sentence is wrong.

- `tests/client/range_panel.spec.luau` "puts the prompt inside Karen's 969 x 792 viewport" — the
  request claims *"the client note now prints the FOV it used"*. It does not: the note prints the
  five eye rows and the mat's y, and `camera.FieldOfView` is still taken off whatever the harness
  machine's live camera is at that instant. The case fails below ~33° vertical FOV, and
  `camera_client.spec` drives that same camera to `Config.FOV_AIM_DEG` and back. Pass
  `Config.FOV_THIRD_DEG`, or print the FOV in the note.

- `src/server/Range/init.luau` `blankRecord` — item 4 is fixed in the measurement but not on the
  board. A pace pick starts a fresh record with `crossingSeconds = trial.lastCrossingSeconds`,
  which is the PREVIOUS pace's crossing, so picking WALK off a TROT now prints
  "PACE WALK  pace 4.5 studs/s  issued 4.5 studs/s  crossing 3.60 s" — a 60 % error — until the
  first whole WALK crossing lands, up to ~22 s later (out of the window, to the end, turn, back
  across). It is strictly better than the 4.75 s partial it used to print and the code is
  untouched by this change, so it is not blocking; but it is the same sentence on the screen that
  produced the dispatch. Clearing `lastCrossingSeconds` on a pick, or printing
  `crossingSecondsByPace[trial.pace]`, finishes item 4 where Karen reads it. Queue it.

- `src/shared/Range/init.luau` `atSpot` measured from the post — the "at the spot" region is now
  centred 8.60 studs downrange-and-east of the mat, so one corner of the mat is outside it: the
  post point is `(mat.X + 3, shelf + 4, mat.Z + dir*7)` and the mat corner at `(-4, -dir*4)` is
  13.0 studs from it against `MaxActivationDistance` 12. In roughly a 1.5-square-stud wedge at
  that corner (of 64), `atSpot` is false, so `RangeBoard.setNear(false)` wipes the record while
  `Range.mayShoot`'s `spotAt` still lets her shoot there. The engine offers no E there either, so
  this is the consistency the change set out to get rather than a defect — but the board's
  visibility is now keyed to the prompt's reach instead of the mat's box.

- `src/server/Range/init.luau` `timeWindow` — one-scan race: `setPace` sets `windowArmed = false`
  even when the target is OUTSIDE the window and relies on the next 10 Hz scan to re-arm. If the
  target crosses the window edge inside that 0.1 s (2.3 studs at RUN) the entry is skipped and
  that crossing records nothing. Losing a measurement rather than printing a wrong one is the safe
  direction; one sentence in the comment would say so.

- `docs/design/shooting-range.md` §4.1 — the part table still has no `POST` row while §7.2 now
  describes the post in full. The design is what blocking kind 1 is judged against; one row.

- `src/client/Hud/init.luau` — the local is still called `rangeMat` and now holds the PROMPT.
  That name is what made round 1's defect invisible. Rename it `rangePrompt`.

- `reviews/task-303/REQUEST.md` claim 1 — *"`Range.promptFor` still finds it by name, so nothing
  downstream changed"* is carried over unedited from round 1, where it was false; it is still the
  wrong sentence for a change whose downstream reader had to be rewritten this round.

---
REVIEWER verdict on commit `835889edabddaa007caa0a324ddb42d72868719f` (round 2) · 2026-10-28 04:40 UTC · session cost $4.99, 50 turns · written by tools/agents.py

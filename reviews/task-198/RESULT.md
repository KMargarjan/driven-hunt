PASS

Verified, not taken on trust:
- Harness: `[harness] PASS: 33/33 checks @ 2820229...` names the request's `Code commit:`, says
  "(clean tree)", `scope=all`; `.agent-evidence/paperwork-after-code-commit.txt` says only
  `reviews/task-198/REQUEST.md` followed it. selene 0/0, stylua exit 0, rojo build exit 0.
- `test2` N/A is true: none of the 18 changed paths starts with any `TWO_PLAYER_PATHS` prefix in
  `tools/agents.py`.
- Claim 1: `BLAST_RADIUS` has `src/shared/Report/` and `src/server/HitLog/` but no
  `src/client/Report/`, so `scope_for` falls through `FAIL_SAFE_PATHS` to `all` — the claim is read
  off the resolver correctly. Both selftest cases the change must satisfy ("every spec file on disk
  belongs to a scope", "no scope names a spec file that does not exist") hold, and no selftest case
  asserts an exact `report`/`hud`/`weapon` spec tuple that the added entries would break.
- Claim 2: `recordHit`'s card sends `at = sinceOpen(at)` where `at = report.at or now or os.clock()`,
  and `recordDown`'s `hitFatal` sends `sinceOpen(animal.dots[index].at)` — the same raw quantity
  through the same function against one `current.openedAt`, so `HitCard.markFatal`'s 1e-3 join holds.
  No raw clock on the wire.
- Claim 4: `grep PointToObjectSpace src/` -> `HitLog/Shape.luau:33` and `Hud/Objective.luau:537`
  only; `BoarArt` projects nothing.
- Claim 5: `Shape.cardDots`'s lead loop indexes `points` in the same order `out` was built and breaks
  at `#out`, so `out[bestIndex]` is the nearest *carried* point. Exactly one `lead`.
- Claim 7: `src/server/HitLog/init.luau` has `ReportEvent:FireAllClients` (broadcast),
  `ReportEvent:FireClient` (`toShooter`) and `ReportData:FireClient` — nothing else.
- Claim 10 arithmetic: `FEED_BOTTOM_OFFSET` 16 + `FEED_LINES` 5 * 20 + `FEED_GAP` 8 = 124 puts the
  card's bottom exactly 8 px above the feed's top (both anchored (0,1)); `Readout` spans the bottom
  40 px, so the x overlap at phone widths is separated on y. All seven names the overlap case looks
  up (`Feed`, `Readout`, `Compass`, `DriveBar`, `ObjectiveLine`, `MiniMap`, `Rail`) really are direct
  children of `screen`, so no element is silently skipped.
- The move is a move: `BoarArt.build`/`drawDots` reproduce `ReportPanel`'s old ZIndex ladder
  (art Z+2, parts Z+3, pips Z+5), white dot, zone ring, half-dot inset, `ontoBoar` nudge and
  `fadeFarSide` for the report, and `Shotgun` is no longer named anywhere in `ReportPanel`.
  `HitCard` -> `ShopPanel` -> `ShopDisplay` is not a require cycle.
- `show` calls `setFade(0)` after `art.Visible = true`, so a replacement card cannot inherit the
  previous card's mid-fade transparency on either the pips or the fourteen body parts.
- No secret, no absolute user path, no non-noreply address in the diff.

## Notes (non-blocking)
- `docs/research/INDEX.md` — the 2026-10-17 hit-card row this commit ADDS says "the card gets a
  164 x 70 BLACK one", but `Report.CONFIG.CARD` ships `ART_WIDTH` 148 / `ART_HEIGHT` 80 on a
  164 x 96 plate, and the note's own section 5 says 164 x 70 was the rejected first frame
  ("the legs came out stubby"). The index row is wrong at birth. Already queued as 198a(b); fix it
  in the row, not only in the note.
- `src/client/Hud/HitCard.luau` / `HitCard.stop` — claim 9's third item ("holds and disconnects its
  two wire connections so a stop/start pair cannot draw every hit twice") is true in the code
  (`wires` is populated in `start` and cleared in `stop`), but no case anywhere drives a
  stop/start pair. A regression to the double-connect the note found would pass the suite. Queue a
  case that calls `HitCard.stop()` then `HitCard.start(frame, ...)` and asserts `stats().shows`
  rises by one per `ReportSystem.Hit` fire.
- `tests/client/hit_card.spec.luau` / "the kill" — `markFatal` paints
  `Shotgun.CONFIG.HIT_MARK_KILL_COLOR`, which is the fix claim 9 names, and nothing asserts it: the
  case reads the `Fatal` attribute and the `u`. Read `BackgroundColor3` off the lead pip, the way
  the buckshot case already reads `CONFIG.DOT_COLOR`. The request states this gap itself, which is
  why it is a note.
- `src/client/Hud/HitCard.luau` / `HitCard.step` — during the 3 s hold `setFade(0)` runs on every
  `RenderStepped` frame and rewrites `BackgroundTransparency` on the card, the plate, the label, the
  fourteen body parts and every pip, plus each `UIStroke`, with a value that has not changed. A
  remembered last fade would make the hold cost nothing.
- `src/client/Hud/BoarArt.luau` / `BoarArt.dotsOf` — `drawDots` writes a `Lead` attribute but
  `dotsOf` does not return it, so `markFatal` walks `shown:GetChildren()` for `Lead` itself rather
  than using the reader the header calls "the seam a spec reads instead of guessing". Returning
  `lead` (and `side`) from `dotsOf` would let a spec name the lead dot without a second traversal.
- `tests/server/hit_card.spec.luau` header — cites "Design: docs/design/drive-report.md (sections
  6.2, 6.3)". 6.2 is the impact projection and is apt; 6.3 is "Shape of the stored record", which
  the card is explicitly not. 6.5 (wire types) is the section the payload belongs to.

---
REVIEWER verdict on commit `079a78ec3c52003a23c2b49dd478576203664659` (round 1) · 2026-10-17 05:40 UTC · session cost $5.07, 55 turns · written by tools/agents.py

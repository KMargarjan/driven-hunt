PASS (items 3, 7 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: what HAS been seen in Karen's
place (130094961655666, live clicks, frames measured and the zoomed crops described) is the STAG
chest hit, the STAG rump hit and the MALE boar rear hit, with the shotgun slug -- "the red diamond
floats in bare plate in front of the stag's brisket; after, it sits behind the stag's shoulder". What
has NOT been seen there: any HEAD hit on any animal (13 clicks, none landed) -- which is the single
largest correction the change makes (stag head 0.00 -> 0.99) and now rests only on a script I cannot
run and overlays I cannot see; the HIND, FEMALE, CUB and CALF pictures (no live frame of any of
them, item 3); the scoped rifle (the gun Karen was holding when she found the defect); and
`recordDown`'s own log line (item 7) -- all three live lines are `fatal=no`, and no spec drives that
branch.

Verification I did do, so the PASS is not on trust:
- `Report.imageFit`'s two branches are correct for `ScaleType.Fit`, and the request's own numbers
  fall out of them: male 946/474 = 1.996 > 1.85 -> `tall = 0.927`, `v0 = 0.0365` (the "3.7 %");
  female 757/440 = 1.721 < 1.85 -> `wide = 0.930`, `u0 = 0.035` (the "3.5 %"); stag 750/758 ->
  `u0 = 0.2326`, which is the 0.230 measured off her screenshot, and `v0..v1 = 0..1`, which is the
  "ink v 0.037..1.000" she measured. The engine's aspect preservation is confirmed by that match and
  not assumed.
- `imageBox`'s composition matches what `BoarArt.setKind` actually draws: `picture.Size =
  UDim2.fromScale(chosen.scale, chosen.scale)` and `Position = fromScale(inset, inset)`, so the
  label keeps the FRAME's aspect at any `scale` and `onto(a, lo, hi) = inset + scale * (lo + a *
  (hi - lo))` is the right order of the three rectangles.
- Step 3's "drawn" column reproduces from the code to +/-0.003 for all six numbers, through
  `drawDots`' half-dot inset (`DOT_PIXELS` 7 in 148x80) and the composed box -- e.g. stag chest
  `uv=(0.425,0.209)` -> u 0.4425 / v 0.5253 against the reported 0.443 / 0.525; male rear
  `uv=(0.705,0.262)` -> 0.6562 / 0.3808 against 0.659 / 0.381. The live frames came from this code.
- Delete the producer: with `Report.imageFit` returning the identity rectangle, server
  `hit_card.spec:350` (`stag.u0` vs the file's own `drawn()`) and `:354` (the independent literal
  0.232582) fail, `:393` (`box.u0 >= lo.u`) fails on the stag, and client `:454` (`x >= lo`) fails --
  the three lines claim 8 names, and they are the right three. Delete `Shape.traceLine` and the
  format case errors; delete `writeTrace`'s body and "keeps the last ten hits" fails on
  `#kept == 10`. No offered case survives its producer.
- One writer: `BoxU0..BoxV1` are written only in `BoarArt.setKind` and read only in
  `BoarArt.drawDots`; `DHLastHits` is written only in `HitLog.writeTrace`, is not `DHFlag_*` (so
  `tools/studio_mcp.py`'s override guard and `flags clear` do not see it) and is JSON-encoded in
  `QUERY_ATTR_DUMP`, so its newlines break nothing. Harness line names the `Code commit:`, is
  "(clean tree)", and `paperwork-after-code-commit.txt` says OK.

## Notes (non-blocking)
- `reviews/task-278/REQUEST.md` claim 9 -- "the drawn `(u, v)` ... is the `uv=` in the same row's log
  line, to three decimals" is false as written, and its own table shows it (0.443 against 0.425,
  0.564 against 0.681). The drawn column is the log's `uv` mapped through the half-dot inset and the
  composed box -- which is the thing the task changed, and it reproduces exactly (above). Say that
  instead; the sentence as it stands invites a reader to think a check was made that was not.
- `HitLog.recordDown` -- the DOWN line passes `index = stats.traced` without incrementing, so it
  repeats the previous HIT's `#n`, and if another animal was hit in between it repeats a number that
  belongs to a different animal. That contradicts `stats.traced`'s own comment, which is the reason
  the number is there: *"the ring can be read for a gap: three clicks and two numbers means a shot
  that never reached the server"*. A duplicate reads as a gap's opposite. Increment it, or print the
  down line with a mark instead of a number.
- `HitLog.recordDown` -- `offset = Vector3.zero` prints `local=(0.00,0.00,0.00)`, which in a log
  whose header says *"IT ADDS NO SOURCE OF TRUTH ... every field is a value `recordHit` already
  holds"* reads as a hit through the centre of the trunk rather than as "not applicable". The dot it
  marks has a real `(u, v)` beside it, so a dash or the hit's own offset would both be honest.
- `HitLog.recordDown` -- no spec drives this branch and no live line shows it (every line in step 3
  is `fatal=no`), so the whole second half of claim 7 rests on reading. Queue one case: `openDrive`,
  one `recordHit`, one `recordDown` with the matching `killingZone`/`at`, then `lastHits()` has two
  lines and the second ends `fatal=YES`. I checked it cannot raise -- `animal.kind`,
  `dots[index].weapon` and `record.killingDistance` all fall back -- which is why this is a note.
- `src/server/HitLog/init.luau` `stats.traced` -- the comment says *"HOW MANY LINES THE HIT LOG HAS
  WRITTEN THIS DRIVE"*, but `stats` is zeroed only in `HitLog.clear()` and not in `openDrive`, so it
  is per-session like `hits` and `downs` beside it. Also `stats.traced += 1` runs outside Studio
  while `writeTrace` returns early, so on a published server the counter counts lines that were
  never written. Drop the words "this drive", or move the increment inside `writeTrace`.
- `src/server/HitLog/Shape.luau` `Shape.traceLine` -- `pellets` is guarded with `math.floor` but
  `index` is not, and Luau's `string.format("%d", 3.5)` raises. Not reachable: both callers pass
  `stats.traced`, an integer. One `math.floor` would make the function's own promise -- *"A ROW WITH
  NOTHING IN IT STILL MAKES A LINE rather than raising on the server at the instant of a shot"* --
  true for every row rather than for the rows that happen to be passed today.
- `tests/server/hit_card.spec.luau` -- the local `drawn()` helper is a verbatim transcription of
  `Report.imageFit`'s body, so "puts every kind's unit square inside the rectangle its picture is
  drawn in" cannot detect a WRONG fit formula: both sides of the comparison would move together. It
  does fail when the producer is deleted (which is what the duty asks), and the formula itself is
  pinned by the independent `0.232582` literal measured off Karen's frame in the case above. Worth
  one sentence in that comment, because the current comment claims more than the case delivers.
- `src/shared/Report/init.luau` `CONFIG.BOAR_IMAGE` -- the deer's `v1` is still `1.000`, the image's
  BOTTOM, which task 223's own comment says was measured as the HOOVES; `HitLog.Shape.dot` says
  `v = 1` is the BELLY. That is the same shape of fault as the `u1` this task corrected from the
  trailing hoof to the rump, and it is now the asymmetry in the pair: `u1` measured to the trunk,
  `v1` left at the picture's edge. It may well be deliberate (a clamped `legs` hit then draws on the
  legs) but nothing says so for `v1` specifically, and the zone-coverage instrument cannot see it --
  leg ink counts as ink. Queue it with the hind's head-centre question the request already raises;
  this task did not touch deer `v` (both deer pillarbox, so their `v` fit is 0..1) and nothing got
  worse.
- `src/client/Hud/ReportPanel.luau` -- `buildSilhouette` passes no `kind`, so the TAB report's rows
  still draw the fourteen-part BOAR frames with no `BoxU0..BoxV1` at all, for a stag as for a male.
  The fix is therefore the hit CARD's only, by construction, and nothing there regressed. Named so
  nobody reads claim 2's "one composition in one place" as covering both screens.

---
REVIEWER verdict on commit `4e62104e11b9794304dc22bb68cba0a63edc5908` (round 1) · 2026-10-26 17:51 UTC · session cost $3.00, 30 turns · written by tools/agents.py

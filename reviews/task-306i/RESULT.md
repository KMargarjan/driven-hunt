PASS (item 3 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: shooting in Karen's place WAS
seen — 360 real clicks through `Input.fire` at the new six-station range, with the SERVER's own
`zone=`, `ring[local=]` and `back` per shot, from both firing positions, and the deck half is
independently corroborated by `Range.distanceFor`'s `base + STAND.backStuds` giving exactly the
request's 179 -> 193. NOT seen: §11.1 item 3, the client's mark PER CASE (one hit-card frame for
all eighteen cells; the request itself declares `card=(None,None)` on every row); §11.5 item 4, the
two-client isolation frame (§11.4/§11.6 assign it to the Director as T3); and the real ladder climb
(the deck was reached by the teleport §11.4's own last row names as T4's route). The frames f1–f5
and the hit-card frame are described, not viewable here.

## Notes (non-blocking)
- `selftest`, the `STAGE` block — the case now dies when the selection dies (verified: the three new
  strings are absent from the downrange-sign lines `local mat = folder:FindFirstChild("Mat4", true)`
  and `seatDeck = seatDeck and seatDeck:FindFirstChild("Deck", true)`), but it does not die when the
  two arms are SWAPPED: `for text in (bench_text, stand_text): assert 'target = folder:...Mat4...'
  and 'target = seat and...Deck...'` asserts both strings in both texts, so bench→Deck /
  treestand→Mat passes. Not blocking because the live gate catches it — `run_cell`'s
  `for want in (... "position=%s" % bench.position)` fires `MISMATCH` against the server's own
  measured `position=`, and the server measures it (`Range.onRequest`: `local spot =
  (Range.positionOf(player))`). What would close it in the selftest:
  `stand_text.index('target = seat and') < stand_text.index('else target = folder:')`.
- `with_self_checks` vs design §11.1 — the design says *"Beside each, rule L's known-bad control: a
  click at the air beside the animal, AT THE SAME PACE"*. The known-bad is appended per RUN, not per
  cell, so it exists only at `run` (0/20 in all three sessions). STAND 100 % — the one chest target
  reported MET — therefore has no same-pace falsifier, and its gate's speed arm is vacuous
  (`PACE_FLOOR["stand"] = 0.0`). The varying zone splits per cell (stand chest 20 · trot body 8
  chest 8 · run rear 9 body 8) carry the aim→hit causality instead. One `rifle/stand/ahead` cell
  would close it.
- `cmd_run` / `Bench.where` — unchanged from round 1 and still the basis of claim 1's
  `[aim_bench] the server's own answer:` line: `bench.where(...)` is logged BEFORE
  `bench.install()`, and the only writer of `DHBenchBoard` is the resident's `RangeBoard` listener.
  The line is fresh only because a PREVIOUS run's resident is still connected and its
  `mine()` (`(DHBenchGen) == gen`) is still true at that instant; in a fresh Play session it reads
  `nil`, and if the `{reset=true}` push is refused (`not Range.mayShoot(player)` → `offMat`, no
  `publish`) it prints the previous run's board as if it were this one's. `RESIDENT` clears
  `DHBenchRows` (`me:SetAttribute("DHBenchRows", "")`) but never `DHBenchBoard`. Install first and
  clear both.
- `cmd_run` — `--station` and `--position` are validated against `STATIONS`/`POSITIONS`;
  `--distance` is validated against nothing. `Range.LAYOUT.DISTANCES_STUDS` is `{107, 125, 179}`,
  so an off-list value makes `optionAllowed("distanceStuds", …)` refuse the WHOLE two-pass pick —
  pace included — and the only thing that notices is the `pace=` arm of the `MISMATCH` loop, which
  does not check `dist=`. Validate it beside the other two, and add `dist=` to the loop.
- `selftest` / `PACE_FLOOR` — `assert PACE_FLOOR["slow"] < 7.2 and PACE_FLOOR["fast"] < 14.4` types
  the two speeds in Python; they are `WINDOW_STUDS / Range.CROSSING_SECONDS` (36/5.0, 36/2.5 —
  checked, they agree today) and nothing ties the two files, so a later window or crossing time
  leaves the floors silently wrong (verdict 278's shape). The companion
  `PACE_FLOOR["slow"] > PACE_FLOOR["trot"] * 0.8` passes on a 0.1 margin (5.7 > 5.6) and is an
  arbitrary bound, not a derivation.
- `REQUEST.md` claim 4 says *"Control and known-bad, in BOTH sessions"* and then names only the
  bench pair (17/20, 0/20); the deck pair (90 %, 0 %) is in the prose below and the guns pair
  (80 %, 0 %) in its own table. Name all three in the claim.
- To queue (rule 4, not this task; raised in round 1 and still open): `docs/design/
  shooting-range-lobby.md` §11.4 opens *"The shipped stage block needs no harness change: it finds
  `Workspace.Range:FindFirstChildWhichIsA("BasePart")` … which is why `Build` still parents mat 1
  first"*. `STAGE` is a second staging route that reads `Mat<n>` / `Stand<n>.Deck` by name, so
  "where does the harness put him" now has two answers in one document.

---
REVIEWER verdict on commit `283cc482832ab57381b819c06249f900dec90ab6` (round 2) · 2026-10-29 20:02 UTC · session cost $2.24, 27 turns · written by tools/agents.py

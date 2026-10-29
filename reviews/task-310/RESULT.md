PASS (items 1, 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing Karen judges by playing
changed. The deliverable is a host-side text column (`tools/aim_bench.py` `render`) plus one field
(`aimz`) in the injected resident's row string. THE ONE OUTCOME the request itself states -- "a rifle
chest-centre shot at a running boar must land in the chest or the body, not the rear" -- is NOT met
and the request says so (`rear 11 of 65`, queued as 310b). Claims 1 and 2 ARE claims about shooting:
they rest on 65 scripted bench shots in placeId 130094961655666, not on a human firing in her place,
and the run files live outside the repo (`<runs-dir>/310/`) so I could check only that the code can
produce them and that they are internally consistent. No frame of the card or the report silhouette
was taken, and none is owed -- no drawn thing changed. Harness line
`[harness] PASS: 34/34 checks @ 9a81fc8b40f1933323b2dfcfb2fd083c092ddd31 (clean tree) scope=all`
names the request's `Code commit:`; `paperwork-after-code-commit.txt` says OK (only `REQUEST.md`
followed it).

Round-1 finding 1 is fixed and I checked the arithmetic rather than taking the claim: the fixtures
are now `ringlocal` z `0.49` and `1.39` against `aimz=-0.41`, so `_back` gives 0.90 and 1.80 and
`summarise`'s mean is 1.35, which is exact at two decimals -- no `.xx5` boundary. In doubles the
accumulated mean is `double(1.35)` minus 1 ulp (1.3499999999999999778), so `"%+.2f"` yields `"+1.35"`
and `abs(table[0]["back"] - 1.35) < 1e-9` holds, neither one decided by noise.

Delete the producer, by reading, for every case claim 4 offers:
- delete `_back` / `offset_disagreement` -> the asserts at `_back(agree)`, `offset_disagreement(agree)`
  raise NameError. Delete `summarise`'s `"back"` / `"backs"` / `"backdisagree"` -> the `table[0]`
  asserts raise KeyError.
- delete the `render` column (`"--" if r.get("back") is None else "%+.2f" % r["back"]`) -> `"+1.35"
  in text` fails: in that table `along` renders `-0.84`, `ringz` `+0.94`, `pastgap` `--`, and no
  footer line or note carries `1.35`. The weak `"back" in text` clause from round 1 is gone, so the
  surviving clause is the value, which the footer prose cannot supply.
- delete the `OFFSET DISAGREEMENT` block in `render` -> `"OFFSET DISAGREEMENT on 1 of 2 row(s)"`
  fails.
- delete the resident's `aimz` write -> `assert "aimz=%s" in RESIDENT and
  "PointToObjectSpace(aim).Z" in RESIDENT` fails, and the live rule can never fire.
- the two sides are not one engine identity: `back` comes from `HitLog`'s `DHLastHits` ring
  (`frameOf(part, report)` = `report.targetCFrame`), `along` from the client's `(impact - aim):Dot(dir)`.
- claim 1's CONTROL cell does discriminate: deleting `Ballistics.leadStuds` would make the `+lead`
  cell aim at the bare chest centre and read like the no-lead cell.

Claim 3 is true in the repo, not only in the run file: `along` is `(impact - aim):Dot(dir)` from the
AIM POINT along `aimDir`, while `_ring_z` reads `offset = frame:PointToObjectSpace(position)` from
`HitLog`'s `writeTrace`, where `frame = frameOf(bp, report)` and `report.targetCFrame` traces back to
`Rewind.impact`'s `frame = CFrame.new(candidate.past.Position) * (candidate.present -
candidate.present.Position)` -- the TRUNK's rewound CFrame. `report.target` is the Damageable trunk
part (`HitLog.recordHit`: `local part = report and report.target`), so ring-z is trunk-relative in
both the carried and the `part.CFrame` fallback case, and `back` is a subtraction of two trunk-axis
coordinates. Signs are consistent: behind the aim is `along < 0` and `back > 0`, which is what
`abs(back - (-along))` assumes and what the fixtures and the live means (-0.48 .. -0.93, rear-heavy
splits) show.

## Notes (non-blocking)
- `tools/aim_bench.py` / `offset_disagreement` — the defect round 1 raised for `aimz` is fixed in
  `_back` (`isinstance(aimz, (int, float))`, `bool` excluded) but left in place one function below:
  `if back is None or not isinstance(along, float)` still rejects an integer `along`, so a row
  reading `along=0` would silently never report a disagreement. Unreachable from the live rig for the
  same reason the Builder gives for `aimz` -- the resident's `f()` always writes `%.3f` -- but it is
  the same class, half-fixed. `isinstance(along, (int, float))` with `bool` excluded closes it.
- `tools/aim_bench.py` / `run_cell`'s per-shot log — the line prints `along=%s ... pastgap=%s
  ring[zone=%s local=%s ...]` and does NOT print `aimz` or `back`. The new number reaches the cell
  mean and the `--out` JSON (`"cells": [{"cell": ..., "rows": ...}]`) but not the human-readable run
  text that gets pasted into a request, so a reader cannot check `mean back` against its own rows --
  which is exactly what `310/summ.py` had to be written to do. Add `aimz`/`back` to that line.
- `tools/aim_bench.py` / `render` footer — the new line "+back is toward the rump, so back and -along
  are the same quantity measured two ways" contradicts the pre-existing line four lines above it,
  "+along is down its heading (behind the aim point)". Both cannot hold: if +along were behind the
  aim, `back` and `along` would share a sign and `offset_disagreement`'s `abs(back - (-along))` would
  be wrong. The new line is the correct one; the old parenthetical should read "(ahead of the aim
  point, toward the snout)". The change did not touch that line but it now sits beside a direct
  contradiction.
- `reviews/task-310/REQUEST.md` / "What the new column shows, in one line" — round 1's note 7 is
  answered with the spread but the arithmetic still substitutes the frozen-frame value: "Taking the
  mean aim at -0.41 that is ring-z +0.31". The same paragraph measures mean `aimz` at **+0.10**, and
  +0.10 + 0.72 = **+0.82** -- past the chest back edge (+0.36), in the body, 0.32 studs short of the
  rear boundary (+1.14), not straddling the seam. The direction of the conclusion (the strike leaves
  the chest rearward) survives either way and the zone splits confirm it, but THE ANSWER FOR KAREN in
  `TASKS.md` repeats the -0.41 substitution verbatim. Use the measured mean, or say the two probes
  disagree by 0.51 studs and why.
- `tools/aim_bench.py` / `render` — `out.append("-" * (widths[0] + 99))`. The row is
  `widths[0] + 98` wide (5+6+8+16 + five `%8s` at 9 + 7 + 11), so the rule is still one character
  long. `+90` over an 89-wide row had the same off-by-one, so the `+9` is faithful to the previous
  behaviour; `+98` would be exact.
- `tools/aim_bench.py` / `selftest` — the `livepair` fixture writes `hit=True answered=True`
  capitalised, which `parse_row` leaves as the strings `"True"` (only `"true"`/`"false"` become
  bools); the resident writes `tostring(hit)`, i.e. lowercase. The assert only reads `aimz`, so
  nothing fails, but the line is offered as the live row format and is not it.
- `tools/aim_bench.py` / `selftest` — the comment heading the new block still cites "a ring at z=+1.42
  ... 1.83 studs back" while the fixture it introduces is 1.39 / 1.80. The comment immediately below
  explains the swap, so a reader gets there, but the first one is now stale.
- `tools/aim_bench.py` / `Bench._find_play_client` — the `studio_list` retry is still in this commit
  and is still outside task 310's statement (rule 4); it is now declared in `TASKS.md` as 310a(a)
  rather than removed, which is the Builder's call to make. Two things for that task: the loop
  re-reads only the NAME listing (`self.place in (e.get("name") or "")`) and not the `game.PlaceId`
  confirmation below it, which is the step L-055 says is the one that matters; and the failure path
  now takes up to 27 s before printing "no Studio for place %s is connected".

---
REVIEWER verdict on commit `dd6bf407894ba521a8db664c285a67e1160042e6` (round 2) · 2026-10-29 10:00 UTC · session cost $2.63, 32 turns · written by tools/agents.py

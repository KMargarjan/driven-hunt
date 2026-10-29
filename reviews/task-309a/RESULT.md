PASS (item 3, 5 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the core item is shooting. What
has been seen is **scripted bench shots** (`tools/aim_bench.py`, placeId 130094961655666 synced from
the test build `driven-hunt-294`), counted by the server's own remotes and read out of `HitLog`'s
ring. What has **NOT** been seen is any human firing at an animal on this build, and **no frame of
the hit card or the report silhouette** — the fix's whole visible effect is that `buildCard` ->
`Shape.cardDots(frameOf(part, report), ...)` now divides the dots down by the rewound frame instead
of `part.CFrame`, moving the red dot off the clamped `u=1.000` tail into the body. The request says
so itself (*"No frame of the card was taken ... NOT PROVEN, not claimed"*). Claim 5's shipped value
(0.250) is likewise unjudged: the request's own *"needs Karen's eye, not another number"*. Also:
`src/shared/Flags/init.luau` `AIM_REWIND` is still `default = false`, so as merged the constant
reaches nobody who has not lit the flag.

Producer deletion, duty (a) — every case offered as proof bites, and none of the three compares a
value with itself:
- `tests/server/weapon_rewind.spec.luau` "carries the rewound frame out of the flight": delete
  `frame = impact.frame` from `Flight.advance` and `expect(resolved[1].impacts[1].frame).to.equal(
  withFrame)` goes red; `flown(nil)` kills a hard-coded field. `withFrame` is a `CFrame.new(10, 2,
  -30)` the spec's own stub cast hands in, and the production step is in the path between.
- `tests/server/hit_card.spec.luau` (the range's ring): delete the new block in `HitLog.sendCard` and
  `expect(after.traced).to.equal(before.traced + 1)` and `expect(#ring).to.equal(1)` both go red;
  replace `frameOf(bp, report)` with `bp.CFrame` and the SECOND pass goes red, because
  `drawnFrame = part.CFrame * CFrame.new(0, 0, 6)` makes `wantTense` and `wrongTense` differ by
  exactly 6 on Z whatever the part's rotation. Round 1's "the tense is not covered" note is closed.
  The known-bad half (`traced` 0 and the ring empty for a refused card) goes red if `cardWorthy` is
  removed.
- `tools/aim_bench.py selftest`: delete `parse_trace`'s `if m is None` return and the four non-ring
  inputs raise on `m.group`; delete the `ringn` key and `assert good["ringn"] == 7` goes red; make
  `ring_credit` credit unconditionally and `assert ring_credit(ring(5), seen) is None` goes red;
  delete the seeding in `run_cell` and the known-bad cell goes back to the `ring 1/30` claim 7 names.
- The live chain is real, not asserted: `Rewind.impact` sets `frame` -> `Flight.advance` now carries
  it -> `Hits.luau` `entry.frame` / `targetCFrame = entry.frame` -> `HitLog.frameOf`. With the flag
  off `Cast.cast` and `Cast.only` set no `frame`, so the new line is a no-op and the off state is
  bit-for-bit the old game. Claim 1 checks out against the code: at base, `recordHit` returns at
  `if not HitLog.rowWorthy(part)` BEFORE `writeTrace`, so a range shot wrote no ring line at all.
  Claim 4's zone edges are the repo's: `Boar.CONFIG.ZONES` chest spans z -1.29..+0.23, body's loin
  +0.67..+1.11, rear's hips from +1.11.
- Harness paperwork: the line names `Code commit: 7f0a45a8...` with "(clean tree)",
  `paperwork-after-code-commit.txt` reads OK (only `reviews/task-309a/REQUEST.md` follows it), and
  `log.txt` confirms claim 10 — `7f0a45a8` touches `reviews/task-309a/RESULT.md` alone, so no `src/`,
  `tests/` or `tools/` line differs from the measured `83569069`. selene, stylua and the Rojo build
  are exit 0.

## Notes (non-blocking)

- `src/shared/Shotgun/init.luau`, the 309a block + `docs/research/2026-10-28-lag-compensation.md`
  (the rewind row) — the row that carries the shipped constant states numbers the request itself
  contradicts, and cites the baseline run as the shipped one. Evidence: the row says *"at 0.250 it
  reads +0.23, +0.13 and +0.00, and a boar aimed at with no lead at all went 15/30 to 25/30"* and
  *"Runs: <runs-dir>/309a/after-A.txt (0.205) against after-B.txt (0.250)"*; the request's claim 5
  says *"+0.17 / +0.09 / +0.05 at 0.250 ... after-A.txt (0.205) against after-C.txt (0.250)"*, claim
  6 lists the cycles as *"diag1 -> after-A -> cycle3 -> after-C"* with `pastgap` *"+1.47 -> +1.00 ->
  +0.10 -> +0.17"*, claim 9 says RUN chest is *"30/30 = 100%"*, and claim 7 names after-B as the
  **190b145d** run. So neither the numbers nor the file is the shipped build's. Round 1 asked for
  this row to print the numbers of the build that ships it and it now prints a third set. What would
  fix it: put after-C's `+0.17 / +0.09 / +0.05` and 15/30 -> 30/30 in the row and in the note, and
  cite after-C. Same row: the bracket *"near 0.254..0.271"* does not follow from its own stated
  residual (*"about +0.4..+0.6 studs AHEAD"* at 24 studs/s is 0.267..0.276); the low end is a
  leftover. The DIRECTION is now right, which was round 1's finding, and I verified it against the
  bench: `drawn` is read after `repeat ... until me:GetAttribute("DHClaimWhy") ~= nil`, so it has
  moved further along `+dir` and `pastgap = (past - drawn):Dot(dir)` under-reports.
- `src/server/Weapon/Flight.luau` `Flight.advance` — the impact rebuild the task just added `frame`
  to still drops `material`, the identical defect class. Evidence: the row is `{ instance, position,
  normal, distance, frame }` while `Shotgun.Impact` carries `material: Enum.Material?`, `Cast.cast`
  and `Cast.only` both set `material = hit.material`, and `src/server/Weapon/init.luau` reads
  `table.insert(materials, if impact.material ~= nil then impact.material.Name else "")` for
  `ShotLanded`. So every pellet's dust on every client is drawn with `materials[i] = ""`.
  Pre-existing and not made worse by this change, so a note — queue it as its own task.
- `src/server/Weapon/init.luau` `castWithRewind` — `DH305Past` / `DH305Pres` are written only on the
  rewound path and **never cleared**, and the bench reads them after the answer with no freshness
  check. Evidence: the writes sit inside `if STUDIO then ... if rewound ~= nil`-adjacent block after
  `rewindTrail.cast += 1`, while the five early exits (`rewind-zero`, `no-provider`, `no-roots`,
  `no-history`) `return castFn(...)` without touching the attributes; the resident reads
  `past, pres = vec3(troot:GetAttribute("DH305Past")), vec3(troot:GetAttribute("DH305Pres"))` and
  computes `pastgap` from whatever is there. So a shot that did not rewind — a clear-air click, a
  known-bad cell row — prints a `pastgap` belonging to an earlier shot, which is exactly round 1's
  finding 3 in the other half of the instrument. The ring half was fixed by `#n`; this half already
  publishes `DH305At` and `ServerStorage.DHLastHits`'s `DH305Rewind` counts the exits, and the bench
  reads neither against the shot. What would fix it: stamp the two positions with the shot's own
  instant (or clear them on every early exit) and have `run_cell` drop a row whose `pastat` did not
  advance. Claims 5 and 6 are the ones read off `pastgap`.
- `tools/aim_bench.py` `render` — the footer legend says *"pastgap is DH305Past minus the drawn
  trunk, along travel ... (+ = ahead of it)"* and says nothing about the late read. The bias that was
  round 1's blocking finding now lives in the `Shotgun.CONFIG` row and the research note but not in
  the output the next person reads, so a printed `+0.00` still reads as "perfect". One line in the
  legend ("a perfect rewind prints about -0.4 at a run; the trunk is read up to one frame late").
- `src/shared/Flags/init.luau` `AIM_REWIND.why` — the first half was refreshed to 0.250 but the OFF
  clause still reads *"the shooter must add 0.18 s x the animal's speed of his own"*.
- `src/server/HitLog/init.luau` — `stats.traced` is now incremented by the range path too, so the
  ring's `#n` sequence interleaves range and drive lines and the counter's own comment (*"three
  clicks and two numbers means a shot that never reached the server"*) no longer holds for a drive
  read while someone shoots the lane. Range lines' `t` is also a different base (`at - rangeEpoch`)
  from drive lines' (`sinceOpen(at)`) with nothing in the line saying which — a lane target carries
  `Kind`, so `kind=male` prints either way. Round 1's note, unchanged.
- `tools/aim_bench.py` `ringdisagree` and `_TRACE` — round 1's two notes stand unaddressed. Both
  sides of `ringdisagree` may be the same server quantity (`r["ringzone"]` is `report.zone` through
  the ring; `r["zone"]` is the `HitMarker` payload's `zone`), so only the selftest's synthetic rows
  exercise it; and `_TRACE` is a hand-transcription of `Shape.traceLine`'s format string with no
  repo-side tie, so a change to that Luau format turns every cell into `ring 0/N` while `selftest`
  stays green on its hand-written `good` input.
- `tests/server/weapon_rewind.spec.luau`, the new case's header — *"MEASURED in Karen's place
  (<runs-dir>/309a/diag1.txt)"* is the phrase round 1 objected to, left unqualified here while the
  `Flight` comment and the `Shotgun` row both now name the build.

---
REVIEWER verdict on commit `67ed8d4848c1c43c063e1201873115e9e13d113f` (round 2) · 2026-10-29 06:52 UTC · session cost $4.98, 48 turns · written by tools/agents.py

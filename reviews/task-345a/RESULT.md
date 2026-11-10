PASS (item 3, 4, 5, 6, 7, 8, 9, 10 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing in this change has been
seen in Karen's place, and nothing can be — `PLACEMENT_IN_PLACE` is born `default = false` and no
file under `src/server/` or `src/client/` names `Placement` or the flag (grepped: the only hits in
`src/` are the module itself and two prose lines in `src/shared/Flags/init.luau`). What was seen is
arithmetic only: the harness line `[harness] PASS: 34/34 checks @ 62ed274a... (clean tree) scope=all`
names the request's `Code commit:`, and `paperwork-after-code-commit.txt` says OK (only
`reviews/task-345a/REQUEST.md` followed it). No screenshot is owed, because flag-off draws nothing
new. Items 1 and 2 (purity, nothing reads it) are static facts and ARE proven here by grep; items
3-10 are where animals stand and when they wake, which is core, and Karen has judged none of it.

Checked by re-deriving it independently, not by trusting the request: the dial keeps 9 / 13 / 15 rows
(`keepAt` 9 on nine rows, 13 on four, 15 on two) and 53 / 73 / 83 nominal animals from
`SOUNDER.COMPOSITIONS` / the deer parties; `neverStuds` 145 = `NOTICE_STUDS` 125 + 40/2 and
`bandNear` 150; `bandFar` 450 = 580 − 100 − 30. I simulated `clearX` over the real fifteen rows:
`normal` lays 13 beds with a closest pair of 71.42 and `busy` lays 12 and skips 3, closest pair
71.30 — both exactly the request's measured figures, so claims 6, 7 and 9 hold. The four `clearX`
unit expectations (40, 71, nil, 38) are right, and `harem` is `{stag = 1, hind = 2}` and
`LONE_PARTY_EXTRA_GROUPS` is 1, so claim 10's cases bite for the stated reason.
Delete-the-producer, by reading: gutting `plan` fails "keeps exactly the rows Data.slotAt keeps" on
`#rows == SCHEDULE.DENSITIES[density]`; ignoring the density word fails that same line at quiet and
busy; `clearX` returning `wantedX` fails "clears every pair of beds" at `normal` (slots 4 and 6 are
55.9 studs apart as written); `clearX` never returning nil fails `skipped > 0`; `clearOfEyes` as
`return true, math.huge` fails both halves of case 6; dropping `bandNear`'s `math.max` leaves
`near` 40 and fails `expect(near >= never)`.

## Notes (non-blocking)
- `Placement.clearX` / `plan`, AND THE ONE FOR THE DIRECTOR: the three `busy` skips are not anonymous.
  Re-deriving the sweep, the rows with no bed are ordinals 4, 8 and 12 — slots 4, 8 and 12 — and all
  three are `reddeer`: the `herd` of 7, **the lone stag**, and the second `herd` of 7. So at the
  shipped muster a busy drive silently loses 15 of its 83 animals and three of its seven deer groups,
  including the one row the repo bends its own cap for (`LONE_PARTY_EXTRA_GROUPS`, "the stag is the
  last deer"). `ESCALATE.md` and TASKS.md say "3 of 15" without saying which three, and K-1 (580 vs
  700) is being decided on that number. Nothing live reads it, so it is not blocking — but the
  escalation should name them before T2.
- `Placement.clearX` — the sweep routinely crosses the stand, and the comment undersells it: at
  `normal` slot 4 goes from a written `offsetX` +45 to −81 and slot 14 from +95 to −81, i.e. 126 and
  176 studs, to the other side of the drive's aim point, while `crossOffset` (where the group breaks
  out) is untouched. The header says the answer is "the nearest legal bed to the one the script asked
  for", and the spec's unit cases only ever sweep 31–71 studs, so a reader will not expect it. State
  the measured sweep distances, or let a pair give up the nearest-x preference.
- `Placement.laneOf` — no case drives it. The only assertion that reads its output is
  `expect(row.laneOffset % Data.laneSpacing(nil)).to.equal(0)` in "counts the whole roster in one
  line", which is true of `round(x/s)*s` for any x AND of a constant, so `laneOf` could be
  `return 0` and the whole spec stays green. Add `laneOf(95, 150) == 150` and `laneOf(74, 150) == 0`.
- `forest_placement.spec` / "takes the far edge off the muster" — the expected value
  (`beaterNorth - notice - SPOOK.SWEEP.MIN_AHEAD_STUDS`) is a transcription of `bandFar`'s one-line
  body (verdict 278). It does discriminate a wrong sign, but unlike `bandNear` — which is anchored by
  `expect(near).to.equal(CONFIG.bandNearStuds)` — nothing ties `bandFar` to the published 450 at the
  shipped muster. One anchored row would close it.
- `forest_placement.spec` / "derives neverStuds ... and orders the four radii" —
  `expect(CONFIG.neverStuds <= CONFIG.bandNearStuds)` is weaker than design 13.1 case 4, which asks
  for `never < bandNear`. With `SPOOK.NOTICE_STUDS` at 130 the rounding makes both 150 and the
  design's strict order would be broken with this case still green.
- `forest_placement.spec` / "lets a party of one through over the cap" — the `harem` half asserts only
  `expect(#rows3).to.equal(1)`, and a party name that matches nothing takes `plan`'s "names no deer
  party" branch to that same count. It is sound today (`harem` = `{stag = 1, hind = 2}`), but it would
  pass for the wrong reason if that row ever left `COMPOSITIONS`. Count the "the deer cap refused"
  line, as the case above it does.
- `tools/studio_mcp.py` selftest — the loop "a %s change plays the forest's own specs" still names
  only `forest_stand`, `forest_line` and `forest_markers`. A `src/shared/ForestTest/` change must now
  also play `forest_placement.spec`; that is the case round 2's own finding 1 was about.
- `reviews/task-345a/REQUEST.md` claim 7 — "it is in `ESCALATE.md` 2026-11-10 ~13:50 as the Director's
  decision" overstates it. That entry is headed "FOR THE DIRECTOR" and its item 2 says "THIS ONE IS
  THE DIRECTOR'S", i.e. it asks for a decision and none is recorded. What actually tolerates the
  skips is design must-not 3 ("skipped for that drive, counted and printed"), which the claim also
  cites and which does hold.
- `TASKS.md` row 345a — still round 1: status "AWAITING REVIEW (round 1)", `code commit 9df17202` and
  that commit's harness line, while the request's code commit is `62ed274a`.
- The two L-028 delete-and-fail proofs were run at `9df17202`, not at the code commit. I checked the
  claim "neither guard changed in round 2" for consistency rather than taking it: the quoted failures
  at `:220`, `:322` and `:344` land on `expect(near >= never)` (now :252), `expect(inside)...false`
  (now :357) and `expect(still)...false` (now :379), offsets +32 / +35 / +35, and the three extra
  lines between the first and the second are exactly the re-commented `bedNorth(2, 2, 450, 150)` case
  this round added. Consistent, so not a finding — recorded so the next round does not re-litigate it.

---
REVIEWER verdict on commit `b1acc133a3a9c52ec2730bbcccd72a2d1d885005` (round 2) · 2026-11-10 14:20 UTC · session cost $5.12, 48 turns · written by tools/agents.py

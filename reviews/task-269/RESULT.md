PASS (items 2 and 3 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: Karen has seen NOTHING of this
task. Item 2's target -- 4 of 5 led shots named `chest` with `DHClaimStats`' accepted counter
moving -- was NOT met (1 of 5, and that one shot's claim was refused, so even it is the server's own
late resolution); item 3 (the 3 no-lead shots) was NOT RUN at all. The single frame
(`<runs-dir>/269-led4-led4.5.1.png`) is described, not seen by me and not seen by her, and the
request itself says it "is not evidence that the claim works". Nothing in `src/`, `tests/` or
`tools/` changed, so there is no new behaviour for her to judge -- the deliverable is a measurement
that refutes the PLAN's hypothesis, and that is what it is reported as.

Delete the producer (RULE 3(a)), case by case:
- The discriminating case is `DHClaimStats` =
  `enabled=true claims=10 accepted=2 refused=8 ignored=0 ... why=ok [claim-blocked=4 claim-line=4]`.
  It SURVIVES the test: delete the claim path and `judgeClaimFor` returns at `if claim == nil then
  return res.impacts`, so `stats.claims` never increments and the line reads `claims=0`; set
  `HIT_CLAIM` off and `enabled=false` with `claimsIgnored=10, refused=0` instead
  (`out.claimsEnabled = if claimPolicy ~= nil then claimPolicy else CLAIMS_ON`, `CLAIMS_ON =
  Flags.isOn("HIT_CLAIM")`). `enabled=true` is the LIVE server's own load-time read, which is what
  makes claim 1 stand on more than the `DHFlag_` attribute. The string also matches
  `Weapon.claimLine`'s format field for field, the counters close (2+8=10, 4+4=8, `claimAges`=10),
  and `why=ok` agrees with there being no `claim-history` refusal.
- The chest count (1 of 5) does NOT discriminate -- it would read the same with the whole feature
  deleted, because every claim in the table was refused. That is not a blocking finding here only
  because the request does not offer it as proof the feature works: claim 6 says "its claim was
  refused, so it is not evidence that the claim works", claim 7 says "the difference between them is
  not significant at these counts -- which is said here rather than presented as progress", and
  claim 8 calls the hypothesis refuted. Offered as the refutation it is, it is honest.
- The zone names are the shape the code produces: `Hits.targetOf` reads the hit instance's `HitZone`
  else the root's, and `Boar/Body.luau` keeps the trunk at `HitZone = "body"` -- so `Boar408(body)`
  (server resolution on the trunk) versus `ZoneChest(chest)` (a welded zone part) is the real
  distinction, not a typo.
- Cross-check that the screenshot belongs to the row it is filed under: led4.5.1's range is 146.2
  studs, and `Report.CONFIG.METRES_PER_STUD = 0.28` with `math.round` gives 41 m, which is the
  `41 m` on the described hit card.

## Notes (non-blocking)
- `reviews/task-269/REQUEST.md` header — the harness line names
  `38176f068385904b23ecb69a34dee5a142f11b12` but the declared field is `Code commit: 27735477`, so
  the two do not agree. NOT blocking, and I checked rather than assumed: `.agent-evidence/log.txt`
  shows every commit on this branch (`27735477`, `38176f06`, `f9bd3bda`) with a diffstat of
  `reviews/task-269/REQUEST.md` and nothing else, `changed-files.txt` is the single added file, and
  `paperwork-after-code-commit.txt` says OK — so the tree the harness ran over has `src/`, `tests/`
  and `tools/` identical to HEAD's and the "everything the harness ran over is covered" sentence is
  true. Fix by setting `Code commit:` to `38176f06` so the field and the line name the same sha.
- PLAN (a) — "the flight to 140 studs is **0.057 s**" is 145 studs' answer, not 140's.
  `Ballistics.timeToRange` is `(exp(k*s) - 1) / (k*v0)` with `Rifle.MUZZLE_STUDS_PER_S.Slug = 2612`
  and `DRAG_PER_STUD.Slug = 4.29e-4`: 140 studs is 0.0552 s, and the lead at 32.05 studs/s is 1.77
  studs, not 1.84. The t3.11.1 row itself is self-consistent (32.05 x 0.0573 = 1.837), so only the
  prose figure is off and the argument -- a third of a body length, far smaller than the 3.8-5.4
  studs measured -- is unaffected.
- "WHAT COULD NOT BE VERIFIED", first bullet — the reason is sharper than the request gives, and
  here it is for the next session. `judgeClaimFor` updates `claimWorstStuds`,
  `claimWorstLineStuds` and `claimWorstEndStuds` only AFTER `stats.claimsAccepted += 1`, so a
  REFUSED claim leaves no number behind at all. That is why `worst=2.590/1.840/2.008` sits under
  `LINE_TOLERANCE_STUDS = 2.0` and `POSITION_TOLERANCE_STUDS = 6.0` while four claims were refused
  `claim-line` — it is the worst over the two ACCEPTED claims, not a contradiction. The "one-field
  addition" should therefore be the worst REFUSED value per rule, recorded inside `refuse`.
- Claim 3 — "eight of ten were refused" is true of the attribute but aggregates the three trials the
  request itself calls silently corrupted (loops fighting over `DHTestLook`, five shots into
  Terrain) with the clean one, and both `accepted` claims come from those earlier trials. The clean
  final trial's own number is in the table and is stronger: 4 claims sent, 4 refused, 0 accepted.
  Carry that one forward.
- Instrument fault 3 — the gate is as described, confirmed: `Claim.forCamera` reads
  `snapshot.loaded[snapshot.selected]` and returns `nil` unless it is a string. Reported-not-fixed is
  right under rule 4, but queue it with the consequence stated, because it is a player-facing one and
  not only an instrument one: a hunter who fires a second shot without cycling sends no claim and
  gets the server's own resolution with no sign that the feature stood down.
- `TASKS.md` / dispatch follow-up (prose only) — claim 10 checks out as written: a
  `DHFlag_HIT_CLAIM=false` row resolves exactly as its absence does (`Flags.resolve` applies the
  override value, which equals the row's `default = false`). Worth knowing that the extra row does
  change `Flags`' published `Source` to `override`, but the Forest Test already carries eleven
  overrides, so nothing moved.

---
REVIEWER verdict on commit `f9bd3bda147429b65bad10089cd1358fe45c979c` (round 1) · 2026-10-26 02:55 UTC · session cost $1.52, 27 turns · written by tools/agents.py

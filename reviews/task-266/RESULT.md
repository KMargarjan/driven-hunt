PASS (item 8, 9, 10 NOT PROVEN)

**Rule 5, stated so this PASS is not read as rule 5 having been met:** nothing Karen will judge has
been seen in her place. Acceptance (1) (claim 8) is one STILL animal, instrument output only, and the
request itself says it "would have landed in the same place with the feature off"; acceptance (2)'s
led chest hit (claim 9) was not obtained — "nobody has yet seen the pair complete"; acceptance (3)
(claim 10) ran in the gate as the policy-parameter case only. `266-acc1-still.png` and
`266-acc-claim.png` are explicitly NOT offered as evidence. **No shot anywhere — live or in a spec —
has had its hit decided by an accepted claim.** The only live reading of the feature is a probe
string (claim 7), seen by the Builder, not a frame.

Round 2's blocking finding is answered on the terms round 2 set: §12.1's 28 (`reachedStuds`, three
ways), 29 (`Flight` carries and never reads the claim) and 26 (the truncation through
`Validator.claimImpact` into `Hits.group`) are written in `tests/server/weapon_hits.spec.luau` and
each one FAILS when its producer is removed — pin `Flight.advance`'s `live.reached` at 0 and all
three `reachedStuds` cases fail; delete `Validator.claimImpact` and case 26 errors. Case 27 is
dropped, named as dropped, and the reason given, which is the alternative round 2 allowed. Harness
`5a634c48` names the request's `Code commit:` with "(clean tree)",
`paperwork-after-code-commit.txt` says OK (only `REQUEST.md` followed), selene/stylua/rojo green.

## Notes (non-blocking)
- `src/server/Weapon/init.luau` → `judgeClaimFor`'s accept branch comment — *"pure and exported
  precisely so this branch can be deleted and FAIL something"* is not true, and REQUEST claim 11's
  *"so the branch can no longer be deleted silently"* says the same thing. Replace
  `return { Validator.claimImpact(claim, part.CFrame, bore, part.Material) }` with
  `return res.impacts` and the whole suite stays green: case 26 calls `claimImpact` directly, and the
  only assertion on `claimsAccepted` anywhere is `weapon_shot.spec`'s
  `expect(after.claimsAccepted).to.equal(before.claimsAccepted)` — that it did NOT move. What is now
  covered is the truncation ARITHMETIC and `reachedStuds`, not the one line of wiring. Say that in
  both places. (`claimImpact` takes four arguments, not "three facts".)
- **The accepted path has never executed, anywhere.** Nothing in the suite reaches past
  `Validator.judgeClaim`'s `return true` into `stats.claimsAccepted`, the `claimImpact` call, or the
  report and dust built from the truncated list; the live case degraded to the honest note in both
  harness runs (claim 10). The flag ships OFF so this costs nothing at merge, but the first time the
  Director lights `HIT_CLAIM` for Karen is the first execution of that branch in the project's
  history. Queue a live case that accepts one claim (the policy seam and `setHistoryProvider` already
  make it reachable — `weapon_shot.spec`'s forgery case is the shape, with an honest point) before
  the flag is turned on in front of her.
- `tests/server/weapon_shot.spec.luau` → `it("counts a claim it was given, and refuses the forged one
  through the real handler")` — when no player is holding a firable gun it notes and asserts
  `expect(CLAIM.POSITION_TOLERANCE_STUDS > 0)`, a line that passes with the entire feature deleted.
  Pre-existing shape (task 185) and disclosed by claim 10, but while it is the only live wiring case
  the gate reports 34/34 with the wiring untested. Arming a bot or a scripted held gun would make it
  fail honestly.
- `src/client/Weapon/Claim.luau` → `Claim.simulate` — `blockAt` is the static hit's distance from
  `pellet.position`, but `hit.distance` is measured from `pellet.position - shift`, so the two sides
  of `hit.distance < blockAt` are on different rulers by up to `|shift|` (~1.27 studs at the step cap
  for an animal running along the bore); `distanceStuds = pellet.travelled + hit.distance` carries
  the same error into checks 4 and 6. The direction is safe — a refusal, never a free hit — and it is
  the same `elapsed`-granularity term round 2 noted; `stats.claimWorstLineStuds` is the instrument.
- `tests/server/ballistics.spec.luau` → `it("is bit for bit the advance-plus-delta it replaced")` —
  `Ballistics.segment` delegates to `Ballistics.advance`, so `expect((position - wantPosition)
  .Magnitude).to.equal(0)` and the velocity line compare `advance`'s output with `advance`'s output
  and can only fail if `segment` stops delegating. The content of the case is `segment`, `length` and
  `capped`, which do fail on a wrong derivation; claim 3's "bit for bit on all three vectors" rests
  on the third.
- `src/server/Weapon/Validator.luau` → `judgeClaim` — its inline check numbers (1 offset, 2 position,
  3 line, 4 blocked, 5 clock, 6 flight) still disagree with `docs/design/ballistics.md` §5.2, which
  `Shotgun.CONFIG.CLAIM`'s comments and `zz_claim_window.spec` follow ("design 5.2 check 4" for the
  line). Carried unfixed from round 2. Renumber to the design's.
- `tests/client/weapon_client.spec.luau` → `it("the row ships OFF, so this client sends no claim
  until the Director turns it on")` — still only `Flags.isOn("HIT_CLAIM") == false` and
  `type(Input.setClaimSource) == "function"`; nothing about `Input.fire`'s payload, which design
  §12.6 asks for. Carried unfixed from round 2.
- 259b ships with no regression guard (queued 266a(a)) and `src/server/Match/` was not exercised by a
  live two-player case for it. Unchanged since round 1; repeated so it is not lost at merge.

---
REVIEWER verdict on commit `0235f715442dcdd4d9525f247cebcdb7604812d9` (round 3) · 2026-10-25 20:48 UTC · session cost $3.78, 43 turns · written by tools/agents.py

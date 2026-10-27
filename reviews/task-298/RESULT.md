PASS (items 1, 2, 4, 5, 6, 7, 8, 9 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: **nothing in this change has been
seen in Karen's place.** `Range.ANCHORS` holds one row, `["map:v1"]`, and `range.spec` still asserts
`RangeData.anchorFor("forest-test") == nil` -- her place has no range, no mat, and no gun on loan, so
every item above was evidenced in the DEV harness or by reading only. What WAS exercised by real
shipped code in the harness: item 1 (`mayShoot` true on the mat, false one mat-width off, false with
the range stopped), item 4 (the loan's whole set, row by row, against `Shop.grantsDriveGun` /
`grantsAlwaysHunter` / `grantsHighSeat`), item 5 (30 pulls through the real `StateMachine` cycle with
the no-loan control), item 6's mayShoot half, and items 7/8 through `Weapon.onFireRequest` and a real
flight -- the 106.3-studs measurement in commit `65dcf612`'s own message is the proof that the shot
path was entered, in run 4. What was NOT: anything in Karen's place; item 2's install order
(`compose()` in `RangeBoot` has never executed in a run that produced evidence here -- the Builder
says so: *"argued from how Roblox loads server Scripts, not measured"*); item 9's live half (*"nobody
has seen a range target die"*). Items 3, 10 and 11 are structural and verified against the repo. No
visual change, so no screenshot was owed.

Round 1's finding is FIXED and the fix bites. `loanSet` now walks `Shop.GRANT_FIELDS` and admits a row
only when every field but `weapon`/`ammo` is nil, so `Range.LOAN` is `ammo.slug`, `rifle.scoped`,
`rifle.lever`, `shotgun.semiauto` and the explicitly added `ammo.unlimited` -- the three `bundle.*`
rows, whose `grants` are the merged set carrying `driveGun`/`alwaysHunter`/`highSeat`, are now
rejected. Revert the inner walk and the case reds twice over: the row-by-row loop finds
`grants.driveGun ~= nil`, and `Shop.grantsDriveGun(owned)` answers true against
`expect(...).to.equal(false)`.

Verified against the repo, no action. `Ballistics.segment` returns `segment = segment.Unit * remaining`
and `length = remaining` when it caps, so `pellet.position + segment` lands exactly `rangeStuds` along
the path and `|endPoint - muzzle| <= reachedStuds` holds by chord-vs-arc -- claim 8's fix is correct and
`nextPosition` was the real defect; a shot the global cap refused has `endPoint = nil` (`Flight.launch`)
and `onShotLanded` falls back to `shot.muzzle`, which matches the claim. `resolvedSignal:Fire` sits on
the one path `flight:advance`'s resolutions take (`Weapon.start`'s Heartbeat -> `onShotLanded`), so once
per resolved shot is right. Claim 6 holds and not for the reason the request gives: `refreshArming`'s
closing loop over `Weapons.ids()` revokes any weapon no longer in the narrowed `wanted`, so the three
loaned guns go on the next 2 s sweep -- without that loop the loan would have survived in the Backpack
for ever. `Weapon.setDriveOpenProvider`/`setEntitlementProvider` returning the previous provider cannot
break a caller: `MatchBoot:196/218/351` and `ForestTestBoot:319/355/877` ignore the return and are
untouched by the diff, and `Match.driveOpen()` takes no parameter so the new `player` argument is
discarded. `Range.armingOver`'s short-circuit is the design's `or` with the operands swapped, which is
the same answer with no side effect skipped. `RANGE` is still `default = false`, so `RangeBoot` returns
before `compose()` in every harness run and the 2441-case suite is untouched by the new wiring.
`Weapon` stays the only writer of the arming decision, the Tool and the shot; `Runtime:takeHit` loops
its own `_boars` and returns false for a part it does not own, so the two listeners cannot answer for
each other. Harness line names the request's `Code commit:` 9a79896c with "(clean tree)",
`paperwork-after-code-commit.txt` says OK, FAIL FIRST's 2435 + 6 = the 2441 of the final run;
selene/stylua/rojo clean. No secret, no absolute user path, no non-noreply email, no `.rbxm`, no script
outside a Rojo-managed path.

## Notes (non-blocking)
- `src/server/RangeBoot.server.luau` / `compose` -- **the ordering risk has no instrument, and its
  failure is silent.** If any root's require chain yields past the first Heartbeat, `MatchBoot`'s
  `Weapon.setArmingPolicy(Match.mayCarryWeapon)` lands *after* the composition and overwrites it, the
  range arms nobody, and the print still reads `"the range's two relaxations and the four guns on loan
  are composed"`. The Builder discloses that the order is argued and not measured; what is missing is a
  way to notice the argument being wrong. Keep the composed function's identity in a local and re-check
  it on a later Heartbeat -- `warn` and re-compose if something replaced it. One line each way, and it
  turns an unverifiable claim into a self-reporting one.
- `src/server/Weapon/init.luau` / `Weapon.ShotResolved` header -- *"Its one listener is `Range`, wired
  at a composition root"* is false today: grep finds no `ShotResolved:Connect` anywhere in `src/`, only
  the declaration and `range.spec`. B4's board is the first listener. Say "no listener yet (B4)".
- `tests/server/range.spec.luau` / "fires exactly ONCE per resolved shot" -- the producer-deletion bite
  is CONDITIONAL, unchanged from round 1. Delete the whole producer (the `resolvedSignal` declaration
  and `Weapon.ShotResolved = resolvedSignal.Event` with the `Fire` block) and the case reds in both
  branches, which is why this is a note. Delete only the `Fire` block and keep the signal, and in any
  run where `readyShooter()` returns nil the single surviving assertion is
  `expect(Weapon.ShotResolved).to.be.ok()` -- a line about the signal object, not about a publish. The
  request does not paste this case's `TestKit.note` for the quoted run, so the pasted evidence does not
  say which branch 9a79896c took; the only thing in the repo that shows the shot path was entered is
  commit `65dcf612`'s message. Paste the note (it is also claim 8's own *"Verify: the note now reads
  `end 100.0`"* -- the one number the request asks the reader to check and does not supply).
- same case -- `putBack()` is still not reached if any assertion after `expect(#seen).to.equal(1)`
  fails, so one red leaves `Weapon.setCast(function() return nil end)` installed and every later spec's
  shot hits nothing, misattributing the real failure. Round 1's note (m), queued in `TASKS.md` and not
  fixed; a pcall-and-restore around the body closes it.
- `tests/server/range.spec.luau` / the claim-4 case -- its inner `for _, field in ipairs(Shop.GRANT_FIELDS)`
  loop is a transcription of `loanSet`'s own walk over the same list, so a ninth grant field invisible
  to `GRANT_FIELDS` would be invisible to both. What makes that safe is outside this case --
  `shop.spec` asserts the list covers every key appearing in any row's `grants` -- and what carries the
  case is the three `Shop.grants*` readers, which are independent of `loanSet`. Name the `shop.spec`
  dependency in the comment so the transcription is not read as the assertion.
- `src/shared/Range/init.luau` / `spotAt` -- it compares X and Z and ignores Y entirely, so
  `Range.mayShoot` is true for a man at any height directly above or below a mat. Harmless on a flat
  lobby plate; a `MAT.size.Y`-sized band in Y would make the predicate say what its comment says.
- `src/server/Range/init.luau` / `Range.CONFIG.FREE` -- still read by nothing in `src/`, while B2's
  comment beside it says *"STEP B3 READS EXACTLY THESE TWO"*. Round 1's note (p), queued, unchanged.
  FREE is implemented by absence; delete the field or mark it declarative.
- `tests/server/range.spec.luau` / `manAt` -- still builds a `Model` + `HumanoidRootPart` per call and
  never destroys them. Unparented, so nothing in `Workspace` is touched.
- `tests/server/range.spec.luau` / "is false with the range not started..." -- all four of its
  assertions are `false`, so on its own it cannot tell `mayShoot` from `return false`. The sibling case
  carries the true branch, and claim 1 names both, so the pair is the proof -- which is the right shape,
  recorded only so the pair is never split.
- `src/server/RangeBoot.server.luau` / the `HitReported` listener -- with `RANGE` on in the DEV place,
  `MatchBoot`'s own `HitReported` listener still runs `HitLog.recordHit(report)` for a range hit and
  will file it under whatever drive `HitLog` has open, so range shots appear in the drive's report.
  Design section 12 asks for exactly that (*"`HitLog.recordHit` keeps receiving it, unchanged"*), so it
  is not a defect -- named so B4's board and the drive report are not later read as disagreeing.
- `reviews/task-298/REQUEST.md`, claim 2 -- *"the two relaxations"* in the case name covers three
  composed providers (arming, drive-open, entitlement); the design's own heading counts two gates plus
  the loan. Wording only.

---
REVIEWER verdict on commit `ad1185ce2641e74d3dbb2f80f7bfaff9382eea89` (round 2) · 2026-10-27 22:02 UTC · session cost $5.91, 63 turns · written by tools/agents.py

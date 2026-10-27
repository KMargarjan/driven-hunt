# Task 298 step B3 — the one gate, the guns on loan, endless ammo, `Weapon.ShotResolved`

Task: 298
Round: 1
Base: 98a8f587 (task-298b2-range-lane, step B2's PASS)
Code commit: 65dcf6123d22c2214ed75b52eae86a743477cb1b

```
[harness] PASS: 34/34 checks @ 65dcf6123d22c2214ed75b52eae86a743477cb1b (clean tree) scope=all
```

`[harness2]`: **N/A.** `python -c "import agents; agents.needs_two_player([...the five changed files...])"`
returned `[]` — no changed path is in `TWO_PLAYER_PATHS`. `Match/init.luau` and `MatchBoot` are
**not** touched: `Match.driveOpen` ignores the new argument, which is the design's own reason.

## PLAN (core-quality protocol step 0)

This step moves no feel number; it builds a gate. The protocol's five lines, answered for the one
thing that IS measurable — whether a man in the lobby can shoot and what it costs him:

- **(a) REAL LIFE / the brief.** Karen, 2026-10-27: *"range is free and amunition is endless"*, all
  four guns at a spot, owned or not.
- **(b) MEASURED NOW** (source at 98a8f587, read off the shipped wiring, not played): a player in
  the lobby carries **no gun** (`Weapon.setArmingPolicy(Match.mayCarryWeapon)`) and his trigger is
  **dead** between drives (`Weapon.setDriveOpenProvider(Match.driveOpen)` →`Rules.driveClosed`).
- **(c) TARGET.** On a mat: armed, trigger live, 4/4 guns, **0 shells spent in 30 pulls**. Off it:
  unchanged, within the 2 s arming sweep.
- **(d) LEVER.** `Weapon.setArmingPolicy` / `setDriveOpenProvider` / `setEntitlementProvider`
  (`src/server/Weapon/init.luau`), composed at `src/server/RangeBoot.server.luau`. The shells:
  `Shop.startFor` → `unlimited` → `StateMachine`'s `boundless` branch in `Load`, which is the one
  place a pocket goes down.
- **(e) HOW MEASURED AFTER.** The same reducer, 30 pulls, with and without the loan — claim 5.

## Claims (each with how to verify it)

1. **`Range.mayShoot` is the one predicate, server-measured.** `src/server/Range/init.luau`. False
   when the range is not started, for `nil`, for a man with no character, and one mat-width off the
   mat; true on it. *Verify:* `range.spec` → *"Range.mayShoot"*, two cases.
2. **The two relaxations and the loan are built in `Range` and installed at the root.**
   `Range.armingOver` / `driveOpenOver` / `entitlementOver` are pure functions of a base provider;
   `RangeBoot` installs them **on the first Heartbeat** (boot Scripts run in no defined order, so
   composing at require time would capture a base `MatchBoot` had not installed yet) and keeps the
   base each setter hands back. *Verify:* `range.spec` → *"the two relaxations, composed"*; the spec
   drives the real functions, so deleting a branch fails here.
3. **`setDriveOpenProvider` is `((Player?) -> boolean?)` and every shipped caller is unchanged.**
   `askDriveOpen(player)` passes the player it already had. *Verify:* `grep -rn setDriveOpenProvider
   src/` — `MatchBoot.server.luau`, `ForestTestBoot.server.luau` both still pass `Match.driveOpen`
   unedited; every `weapon_*.spec` is unchanged and green in the run above.
4. **All four guns on loan at a spot, through the shipped composition, and NOTHING off it.** Off the
   mat the base's answer is handed back identically (`nil` stays `nil`); on it, every row that grants
   a gun or a cartridge plus `ammo.unlimited`. *Verify:* claim-4 case asserts
   `Shop.loadoutFrom(Weapons.ids(), …)` has all four and that a licence the player did NOT buy is
   absent.
5. **Endless ammo is the shipped `ammo.unlimited` entitlement, MEASURED, with a control.**
   `[server] range endless ammo: 30 pulls on the loan fired 30, pocket 24 -> 24; without it 14
   fired, pocket 12`. Same reducer, same 30 pulls, the only difference being the loan. *Verify:* the
   note in the run above; `src/server/Weapon/StateMachine.luau` `Load` → `boundless`.
6. **The loan never follows him into a drive, and it ends on a tick, not an edge.** `mayShoot` is
   false the moment he steps off the mat, and `Weapon.refreshArming`'s existing 2 s sweep
   (`ARMING_SWEEP_SECONDS`) re-asks and revokes. Nothing listens for a step-off event. *Verify:*
   case *"is TRUE on the mat and FALSE one stride off it"*, plus the unchanged sweep.
7. **`Weapon.ShotResolved` fires exactly once per resolved shot, hit AND miss.** Published in
   `onShotLanded` with `endPoint`, `reachedStuds`, `resolvedAtServerTime` and `hitParts`. *Verify:*
   `range.spec` → *"Weapon.ShotResolved"*: a real shot through `Weapon.onFireRequest` and the real
   flight, counted — `#seen == 1` after the miss and `== 2` after the hit.
8. **The resolved end point is on the bullet's path.** The first run of claim 7 measured
   `end 106.3 studs from the muzzle for a 100.0-stud cap`: `Ballistics.segment` clamps the SEGMENT
   to the range cap and hands back the unclamped advance beside it. Fixed in
   `src/server/Weapon/Flight.luau` (`pellet.position + segment`), and the spec now asserts
   `reach <= reachedStuds`. *Verify:* the note now reads `end 100.0`; revert that line and the case
   fails.
9. **A range hit is the hunt's hit, and it costs nothing.** `RangeBoot` wires `Weapon.HitReported`
   to the range runtime's `Runtime:takeHit` — the same signal and the same method the drive uses.
   `takeHit` matches the part against its own animals, so the two listeners never answer for each
   other. The range calls no `Economy`, no `Match.Penalty`, no `Match.Score` and never
   `HitLog.openDrive`. *Verify:* `grep -rn "Economy\|Penalty\|Score\|openDrive" src/server/Range/
   src/server/RangeBoot.server.luau` → nothing. **NOT PROVEN:** a real shot at a live range target
   killing it was not driven in this round (see below).
10. **FAIL FIRST.** With these specs committed and the code still at the base, the same full run read
    `[harness] FAIL: 32/34 checks @ a89f5843cb29c57e770e5ce15ad2ee14b3064cbb (clean tree) scope=all`
    — `2435 passed, 6 failed, 6 errors`, six failures for the six new cases.

## What I could not verify

- **Claim 9's live half.** No case fires a real shot at a real range target and watches it die; the
  case that would need a player standing on the DEV mat with a target crossing the lane. The wiring
  is one line and is asserted only by reading. **NOT PROVEN — nobody has seen a range target die.**
- **The first-Heartbeat composition order** is argued from how Roblox loads server Scripts, not
  measured. A probe reading `[RangeBoot] … are composed` from a live DEV console would settle it.
- Run 3 of the harness (b1b795b5, a server-spec fixture away from the code commit) reported **2
  client failures**; run 4 at 65dcf612 is 623/623 green and I changed no client code between them.
  I am not calling that a flake: it is unexplained, and it is listed here rather than left out.

## ANSWERED (the dispatch's CHECKED flags)

- **ANSWERED: L-093** — one case per arm, each with its own fixture and each shown red first in the
  FAIL FIRST run: on-mat armed / off-mat refused / trigger live between drives / the loan / the
  endless shells / ShotResolved on a HIT and on a MISS in one counted case.
- **ANSWERED: L-136** — no failure was excused. The three server failures of run 2 and the one of
  run 3 were all mine (fixtures) and are fixed, not explained away; the two client failures of run 3
  are reported above as unexplained rather than called the flake. `weapon_shot.spec:1490` did not
  fire in any run.
- **ANSWERED: L-140/L-143** — FREE is measured where it can be and declared where it cannot: the
  30-shot case quotes both pocket numbers whole (24 → 24, control 24 → 12). The Economy-balance and
  HitLog-row reading needs the live shot of claim 9, which is NOT PROVEN.
- **ANSWERED: L-041** — `agents.needs_two_player()` was run against the real changed-file list and
  returned `[]`; `Match/init.luau` is not edited.
- **ANSWERED: L-030** — every call site of `setDriveOpenProvider` was grepped: `MatchBoot:218`,
  `ForestTestBoot:355` and the new `RangeBoot`. All three compile and the suite is green.
- **ANSWERED: L-029** — the loan ends on `refreshArming`'s existing 2 s level-triggered sweep. No
  leave/step-off event is listened to anywhere in this change.

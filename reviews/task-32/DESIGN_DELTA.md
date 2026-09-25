# Task 32 — where the build differs from `docs/design/drive.md`

`docs/design/` is the Architect's (rule 3), so this file is the Builder's record of every place the
1.7a build departs from it, and why. The Director asked for it explicitly for item 1.

## 1. `MIN_PLAYERS = 1`, and the odd player is a **Shooter** — the Director's decision F

**Design:** §11.1 `MIN_PLAYERS = 2`, `ODD_PLAYER_TEAM = "Drivers"`.
**Built:** `MIN_PLAYERS = 1`, `ODD_PLAYER_TEAM = "Shooters"`.

The Director's decision F (and audit-003 must-fix 1) is that one player is a drive during Milestone
1, so Karen can practise alone and the harness's single Play player is armed. **The second half of
that follows from the first and the design does not say it:** with `ODD_PLAYER_TEAM = "Drivers"` a
lone player is the odd player, lands in Drivers, and `DRIVERS_MAY_SHOOT = false` takes their gun —
which is exactly the state decision F exists to avoid, and it would take `weapon_client.spec` and
`camera_client.spec` down with it. So the odd player is a Shooter.

**What that changes for Karen, and it is hers to overrule:** with 3, 5 or 7 players the extra one now
shoots rather than drives (3 players: 2 shooters, 1 driver). With 2 — Karen and her daughter — it is
1 and 1 either way. Both are one word in `Match.CONFIG`.

**Before release** (`ROADMAP.md` Milestone 3): `MIN_PLAYERS = 2`, and `ODD_PLAYER_TEAM` is then a
pure feel choice again.

## 2. The first boar release is exact; only the rhythm after it is jittered

**Design:** §12.1 item 5, "the first at `FIRST_RELEASE_SECONDS ± RELEASE_JITTER_SECONDS`".
**Built:** the first release is at exactly `FIRST_RELEASE_SECONDS`; every later one is jittered.

Measured, twice: with the first release jittered by up to 15 s either way, the only boar in a harness
session could arrive **after the input replay had finished**, so the end-to-end staged shot
(`shoot_boar.spec`, Task 30) had nothing to aim at and the run went red for a reason that had nothing
to do with the code under test. It is also arguably better: the drive starts when the drive starts.

## 3. `Boar.Runtime:clear()` is new — a second change inside the boar's own owner

**Design:** §3.6 says the only change to `src/server/Boar/init.luau` is `maxBoars = 4 → 8`, while §4.3
requires a `clearBoars` effect.
**Built:** both. The Match may not touch a boar Instance (§1.2), and the boar had no public way to
remove one, so the request goes to the owner: `Runtime:clear(reason)` despawns every live boar
through the existing `_despawn` path (`Body.destroy`, `releasePath`, the `Despawned` signal). Asserted
in `match_live.spec`.

## 4. The markers are re-read while `Waiting`, not only on `Assigning` entry

**Design:** §6.2, "re-run on `Assigning` entry".
**Built:** that, **and** once a second while `Waiting`.

`ArenaBoot` and `MatchBoot` are two `Script`s in `ServerScriptService` with no defined order, so
`Match.start` can read the tags before the arena exists. It did, on one harness run in three: the
drive sat in `Waiting` for the whole session, nobody was armed, and five specs went red for a reason
none of them owned. Five `GetTagged` calls a second while waiting closes the race for good.

## 5. `Match.stop()` does not destroy the three signals

**Design:** §9.2, "`Match.stop()` … disconnects everything, destroys the signals".
**Built:** it disconnects everything it connected and leaves the `BindableEvent`s alive.

`Match` is a singleton `ModuleScript` that production and every spec share. A destroyed
`BindableEvent` stays destroyed for the rest of the session, so the next spec to require `Match`
would get a dead module — the teardown would break the thing it is supposed to protect.

## 6. `placePlayers` carries an optional list of userIds

**Design:** §4.3, `{ kind = "placePlayers" }` with no argument.
**Built:** `{ kind = "placePlayers", userIds: { number }? }`; `nil` still means everybody.

§4.4 requires a mid-drive joiner to be placed **without moving anyone already playing**, which the
no-argument effect cannot express.

## 6b. A joiner during `Assigning` is put on the smaller team immediately

**Design:** §4.4, a joiner in `Assigning` is "assigned with everybody else".
**Built:** a joiner in `Assigning` **or** `Running` takes the smaller team on arrival.

`Assigning` assigns once, on entry (§4.1), so "with everybody else" has already happened by the time
a joiner arrives one second later; the alternative is a player standing teamless and unarmed for the
rest of the intermission. The sizes balance either way, because the smaller team is exactly where a
balanced split wants one more. Raised by the round-1 review, which was right that it was undeclared.

## 7. What 1.7a does not build at all (the Director's split, design §14 item A)

`Penalty.luau`, the tie/rope/`Workspace.DriveMarkers` half of `Match.Body`, the `SafetyViolated`
listener and `stopAt`, and `Hud/Scoreboard.luau` are **1.7b**. `SAFETY_ENABLED` and
`SCOREBOARD_ENABLED` exist and are `false`; `Score.violation` and the `tied` list are built and
tested, because points have one home and the wire should not change when 1.7b lands.

## 8. `match_live.spec` asserts the PRODUCTION match, not a stub world

**Design:** §12.4, "one `Match` started with a spec-built world".
**Built:** the spec asserts the drive that is actually running in the Play session.

`Match` is a singleton that `MatchBoot` has already started; a spec calling `Match.start` again would
assert, and one that stopped production to run a stub would leave the client specs reading a Hud fed
by nothing. Asserting production is also the only version of this test that tests the player's path
(rule 6). Everything the design wanted a stub world for — joins, leaves, deferred releases, a hitch,
determinism — is driven exhaustively in `match_phase.spec`, where it is pure.

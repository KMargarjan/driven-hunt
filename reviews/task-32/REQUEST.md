# Task 32 — the drive runs

Task: 32
Round: 1
Base: `339933a`
Code commit: `63edba1f3311358713ce5ab3e9603c470dabf14b`

```
[harness] PASS: 27/27 checks @ 63edba1f3311358713ce5ab3e9603c470dabf14b (clean tree)
```

224 server and 58 client `it` blocks across 22 spec files (`main` had 162 and 51).

## Task

ROADMAP 1.7a, built to `docs/design/drive.md` with the Director's decisions in
`reviews/task-29/BRIEF.md`. Scope: the phase machine, teams, the 10-minute timer, six boars per
drive, points, and the posts and drive line as tagged markers. `SAFETY_ENABLED` and
`SCOREBOARD_ENABLED` exist and are **false** — the penalty and the score screen are 1.7b.
**Every deviation from the design is in `reviews/task-32/DESIGN_DELTA.md`**, eight of them, and
claims 2, 7 and 9 below are the three that change behaviour rather than shape.

## Claims

1. **The `Game state` slot is filled, and nothing else moved into it.** `ServerScriptService.Match`
   owns the phase, the teams, the per-drive score and which boars exist. It writes no boar state (it
   calls `runtime:spawn`/`clear` and reads handles), no weapon state (it injects a policy), nothing
   drawn and no camera. `Phase`, `Roster` and `Score` are pure — no service, no Instance, no clock,
   no `Player`, no `Random` — and `Markers` only reads. `GAME_DESIGN.md` has the filled row, three
   new rows and three amended ones.

2. **A reducer that returns EFFECTS, not a state machine that does things.** `Phase.step` returns a
   new frozen state plus a list like `assignTeams`, `placePlayers`, `spawnBoar`, `clearBoars`,
   `broadcast`. That is why `match_phase.spec` drives a whole 600-second drive — with joins, leaves,
   a kill, a hitch and a full release schedule — in milliseconds with no players and no world, and
   asserts on plain tables. 10 000 steps at 16 participants run in well under the 200 ms budget
   (printed). The pattern is Redux's with the side effects made values; the package (Rodux) is named
   and not adopted, and the research note corrects the design: **Rodux is not archived**.

3. **Teams are Roblox's own `Player.Team`, and the split is equal for every size.**
   `match_roster.spec` checks 2..16: `|#Drivers − #Shooters| ≤ 1`, everybody exactly once,
   deterministic (sorted by userId, no `Random`), the odd player on `ODD_PLAYER_TEAM`, and the swap
   between drives putting everybody on the other side while still balancing — including the case the
   design does not mention, where the previous split was lopsided because somebody left and a straight
   swap would carry the imbalance forward.

4. **One player is a drive, and that is the Director's decision F.** `MIN_PLAYERS = 1`, and the lone
   player is a **Shooter**, so the harness's single Play player is armed and `weapon_client.spec` and
   `camera_client.spec` stay green. The second half does not follow from the design's own numbers —
   with `ODD_PLAYER_TEAM = "Drivers"` a lone player would be an unarmed driver — so it is called out
   in the delta as Karen's to overrule for odd player counts.

5. **The weapon still decides and still writes.** `Weapon.setArmingPolicy` and
   `Weapon.refreshArming` are the third injected provider on that owner, beside `setCast` and
   `setDriveLineProvider`; `nil` restores `Shotgun.CONFIG.shouldArm`, which is what a server with no
   Match uses, so **every `tests/server/weapon_*.spec.luau` is untouched**. A policy that errors falls
   back to the default rather than leaving a player permanently unarmed.

6. **The markers are tags, and the arena places them.** `TestArena` builds and tags 8 posts, one
   drive line, a driver start and 4 boar spawns, and re-uses the four corner pillars as trees.
   `test_arena.spec` asserts the counts, the 40-stud spacing, that every post is inside the plate and
   between the boar's exit line and the driver start, that a second `build()` adds no second set of
   tags — and, in one assertion, **that the drive line's `LookVector` points at the drivers**, which
   is the difference between the 1.7b safety rule firing on the right shots and on exactly the wrong
   ones.

7. **Two harness runs found a race that would have cost a day later** (rule 6). `ArenaBoot` and
   `MatchBoot` are two `Script`s in `ServerScriptService` with no defined order, so `Match.start`
   could read the tags **before the arena existed** — and did, on one run in three: the drive sat in
   `Waiting` for the whole session, nobody was armed, and five specs went red for a reason none of
   them owned. The markers are now re-read while `Waiting`. The same runs found that a jittered
   **first** boar release could land after the input replay had finished, leaving Task 30's staged
   shot with nothing to aim at; the first release is now exact.

8. **The drive decides when a boar exists, and still never touches one.** `BoarBoot.server.luau` is
   archived (rule 7, `backups/` with a note) and its three jobs are in `MatchBoot`, the one
   composition root. The Match releases six boars on a schedule, holds a release back instead of
   dropping it when the runtime is full, and clears the drive's boars at the end — through
   `Runtime:clear()`, which is new on the boar's own owner because the Match may not destroy a boar
   Instance. `Boar.CONFIG.maxBoars` is 8, because a carcass occupies a slot for two minutes.

9. **`match_live.spec` asserts the drive that is actually running**, not a stub world: `Match` is a
   singleton that `MatchBoot` has started, and a spec that stopped production to run a stub would
   leave the client specs reading a Hud fed by nothing. It checks that the drive left `Waiting`, that
   both `Team`s exist with `AutoAssignable = false` (the page does not state its default, so it is set
   explicitly and asserted), that the player is a Shooter and may carry a weapon, that the drive line
   points at the drivers, that the snapshot is frozen to its rows, and that `killSignalMissing == 0`.

10. **The client is a replica with no setter and nothing inbound.** `PlayerScripts.Match` subscribes
    to the two server→client remotes and freezes what arrives; `match_client.spec` asserts there are
    **exactly two** remotes in `Drive.Remotes` and both are `RemoteEvent`s, that the snapshot and its
    rows throw on a write, that `secondsLeft()` matches `phaseEndsAt - GetServerTimeNow()` and is
    never negative, and that the drive bar is really on screen — every ancestor present and visible,
    the `ScreenGui` enabled — with a text that never renders a `nil`.

## Screenshots, inspected (rule 5)

- **`task32-drive-line-from-the-drive`** — the best one. The drive bar reads
  `DRIVE 1   9:58   BOARS 6   SHOOTER`, the event feed at the bottom left reads `Drive on`, and across
  the middle distance the **drive line** runs the width of the arena as a thin pale strip with the
  brown posts standing on it. That is the drive, in one frame.
- **`task32-boar-in-the-drive`** — `DRIVE 1   9:36   BOARS 6   SHOOTER`, with a released boar (tan
  body, pink head) 26 studs away on its spawn pad and the post line behind it.
- **`task32-shooter-line`** — from beside post 5, looking along the line: the posts recede into the
  distance, the player is holding the shotgun (a Shooter is armed), and the bar reads
  `DRIVE 1   ASSIGNING   0:00`.

**The `0:00` in that third shot is real and is reported rather than cropped out:** for the first
seconds of a session the client's `Workspace:GetServerTimeNow()` has not caught up with the server's,
so `phaseEndsAt - now` clamps to zero. It is right by the time the drive runs (9:58, 9:36 above). It
is a startup transient in the clock, not in the phase, and it is the one thing on screen I would look
at again in 1.7b.

## What I could not verify

- **Nobody has played a drive.** Every number is the design's default, and the ten-minute length,
  the points and the push rule are exactly what Karen's two-player playtest is for.
- **Two players.** Karen's probe proved the harness *could* drive two clients (Task 30, four studios);
  it does not yet, so everything about a real second player — the team split on screen, a driver
  pushing a boar into a shooter — is `NEEDS KAREN` in the design's §12.8 and untested here.
- **The score screen and the safety penalty are dark**, so `Score.violation`, the `tied` list and the
  `release` effect are exercised only in the pure specs.
- **`execute_luau` cannot see the live Match** (the same module-cache limit Task 30 measured), so the
  screenshot script's `Match.phase()` read `Waiting` while the real drive was `Running`. Everything I
  claim from the screenshots comes from the Hud and from real Instances.
- **The 600-second drive has never run to `Scoring` in a live session** — a harness Play session is
  about two minutes. `Running → Scoring → Assigning`, the swap and the second drive are proved in
  simulated time only.

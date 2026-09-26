# Review request — Task 35: the safety penalty and the score screen (ROADMAP 1.7b)

Task: 35
Round: 1
Base: `main` @ `ba86a42` (Task 34 merged)
Code commit: `ad567bdd1c74de00071ff22acb6c85a905ec41a7`
Branch: `task-35-safety-score`

Harness, on the clean tree, naming the code commit:

```
[harness] PASS: 27/27 checks @ ad567bdd1c74de00071ff22acb6c85a905ec41a7 (clean tree)
```

271 server and 68 client `it` blocks (main had 263 and 67). Built to `docs/design/drive.md` §8 and
§9.3 with Karen's values from `reviews/task-29/BRIEF.md`. **Five deviations, in
`reviews/task-35/DESIGN_DELTA.md`; two of them are corrections without which the rule never fires on
the case it exists for** — claims 2 and 3 below.

---

## Claims

1. **The 45° arc is the filter; "you fired at a driver" is the verdict.** The weapon still publishes
   `SafetyViolated` from `SafetyArc.isForbidden` and does nothing else about it; the Match decides with
   the new pure `Match.Penalty.judge`, and the owner asks the other three questions around it (phase is
   `Running`, this shooter is not already tied, the grace is over) in `onSafetyViolation`.
   *Verify:* `src/server/Match/Penalty.luau`; `onSafetyViolation` in `src/server/Match/init.luau`;
   `tests/server/match_safety.spec.luau`, describe "Penalty.judge". A cone as the verdict would tie
   everybody in the first minute, which is what claim 8's one-player assertion proves it does not.

2. **Correction 1 — `stopAt` is the distance to the aim point, not `report.nearest`.** The design's
   number does not exist for a shot that hits nothing damageable, and with buckshot the nearest impact
   of a nine-pellet pattern is whichever pellet clipped the ground first, which would mask every
   violation. *Verify:* the `driveLineProvider` block in `src/server/Weapon/init.luau`;
   `DESIGN_DELTA.md` §1.

3. **Correction 2 — `SAFETY_BODY_STUDS = 4`.** `t` is measured to the driver's root and `stopAt` is
   where the pellets stopped, so a shot that **hits** a driver stops a stud in front of his root and
   the design's bare `t <= stopAt` judged a point-blank shot at a person harmless. *Verify:*
   `Penalty.judge`'s `reach`; `tests/server/match_safety.spec.luau`, "ties a shot that HIT a driver…"
   and "does NOT tie a shot that stopped in the boar in front of him" — the design's own cases still
   pass, by 10 and 50 studs.

4. **Being tied is one module's work and it is reversible.** `Match.Body` freezes the humanoid, anchors
   the root (**before** the pivot — a character's physics belongs to its own client), stands the player
   outside the trunk on the ground facing it, draws one non-colliding, non-queryable rope in the new
   run-time folder `Workspace.DriveMarkers`, and gives back exactly the numbers it took.
   *Verify:* `Body.tie` / `tieCharacter` / `tiePointFor` / `untieCharacter` / `driveMarkers` /
   `anchorFor` in `src/server/Match/Body.luau`; `tests/server/match_safety.spec.luau`, describes
   "Body.tiePointFor", "Body.tie" and "Body.anchorFor". The live half runs against a **rig this spec
   builds at y = 700**, never the real player, because half the client suite is standing in that player.

5. **One writer of "who is tied".** The owner's `tied` table is the only copy: `Match.mayCarryWeapon`
   reads it, `Match.snapshot` reports it, `Match.isTied` exposes it, the `release` effect empties it.
   `Phase` emits `freeze` **before** the feed and the broadcast, so the snapshot that announces a
   violation already shows the tie. *Verify:* `src/server/Match/init.luau` (`tied`, `applyFreeze`,
   `untie`, `applyRelease`); the `violation` branch of `Phase.step`;
   `tests/server/match_phase.spec.luau`, describe "the safety rule's effects".

6. **A tie takes the gun, and a respawn does not give it back.** `mayCarryWeapon` is false while tied
   and `refreshArming` is asked to re-evaluate; `watchCharacter` re-ties a tied player who presses
   Reset. The weapon still decides and still writes. *Verify:* `Match.mayCarryWeapon`, `applyFreeze`,
   `watchCharacter`, `Match.forget` in `src/server/Match/init.luau`;
   `tests/server/match_live.spec.luau`, "connected the weapon's safety signal…".

7. **End to end, with two real players.** In `test2` the shooter's client walks 25 studs behind the
   driver, holds the camera on him through the camera owner, and the harness replays a click: click →
   `ContextActionService` → client weapon → `FireRequest` → validator → cast → `SafetyArc` →
   `Penalty.judge` → `Body.tie` → the snapshot's `tied` list → this client's banner. Nothing stubbed.
   *Verify:* `tests/client/zz_tie_to_a_tree.spec.luau`; the `tie-the-driver` scenario in
   `tests/client/input_scenarios.txt`; the run below.

8. **The same shot into an empty drive ties nobody.** With one player there is no driver, so the spec
   fires straight down +Z — inside the 45° cone — and asserts the player is **not** tied and still has
   the gun. That is the design's rejected rule, proved rejected. *Verify:* the `driver() == nil` branch
   of `tests/client/zz_tie_to_a_tree.spec.luau`; it runs in every `test`.

9. **The score screen is really on screen, and the next drive swaps the teams.** A drive is 600 s, so
   **no harness run reaches the `Scoring` phase**; the two halves are proved where they can be — the
   transition (`Running → Scoring → Assigning` with every team flipped) in
   `tests/server/match_phase.spec.luau` ("frees everybody when the drive ends…", "swaps the roles on
   the next drive"), and the panel — visible, every ancestor visible, two rows, this player's row
   highlighted, `NEXT DRIVE IN n`, cleared again when the drive restarts — in
   `tests/client/match_client.spec.luau`, describe "the score screen", which hands `Hud.renderScore`
   the snapshot the server would have sent. `Hud.renderScore` / `renderTied` are public for that
   reason and say so in the file header, exactly as `Hud.onHitMarker` already is.

10. **No rule number reached the client.** `Drive.CONFIG` gained layout and colours only; the safety
    numbers and the points table stay in `Match.CONFIG` on the server. *Verify:* `src/shared/Drive/init.luau`;
    `tests/client/match_client.spec.luau`, "carries no rule number…".

---

## Evidence

- **1 player:** `[harness] PASS: 27/27 checks @ ad567bdd1c74de00071ff22acb6c85a905ec41a7 (clean tree)`
- **2 players:** `[harness2] PASS: 28/28 checks @ ad567bdd1c74de00071ff22acb6c85a905ec41a7` — one
  server and two clients, `Player1=Shooters` / `Player2=Drivers`, the SERVER green (263 passed, 0
  failed) and the SHOOTER green (67 passed, 0 failed, including `zz_tie_to_a_tree`: `staged=25
  cued=true`). The driver's report is the mode's observation, never a check: `44 passed, 23 failed`
  (no gun, no replay) — and it arrives again, which the first run of this task broke and the last
  commit fixed. That line says `DIRTY TREE (1 paths)` because this file was being written while it
  ran; the code commit is identical and its clean-tree evidence is the `[harness]` line above. A
  `[harness2]` line is never the merge gate's evidence anyway (`tools/studio_mcp.py` docstring).
- **Screenshots, inspected (rule 5),** in `.screenshots/` (git-ignored):
  `task35-tied-to-a-tree.png` — the player standing against a corner pillar, facing it, a warm-brown
  rope from his torso into the trunk, no gun in his hands, the red banner
  "TIED TO A TREE - you fired toward the drive" under the drive bar, and
  "Alhamdulilah824 tied to a tree" in the feed;
  `task35-score-screen.png` — the panel centred, "DRIVE 1   SCORE", a header row, two rows
  (`1 Alhamdulilah824 SHOOTER 1 50`, `2 8167651842 - 0 10`) and "NEXT DRIVE IN 120", with the bar
  above reading "DRIVE 1   SCORING   2:00   SHOOTER".

## What could not be verified, and what is wrong

- **Both screenshots were taken on deliberately modified, dirty trees**, and that is stated rather than
  hidden. No harness run can reach either state at the shipped numbers: the tied shot needs a driver
  (there is none with one player) and the score screen needs a 600-second drive to end. For the tie,
  `Penalty.judge` was forced to return true for one run; for the score screen, `DRIVE_SECONDS` was 30
  and `SCORE_SECONDS` 150 for one run. Both were reverted, and the committed tree is what the harness
  PASS above tested.
- **The harness cannot take a screenshot during a two-player run.** `screen_capture` is refused with
  "This call is missing the required `studio_id` argument" whenever more than one Studio is connected,
  and `capture` sends none (`tools/studio_mcp.py`, `Studio.capture`). So the *real* two-player tie is
  proved by assertions and not by a picture. One argument, queued rather than built (tooling freeze).
- **The ammo readout stays on screen after the gun is revoked.** `Weapon.revoke`
  (`src/server/Weapon/init.luau`) resets the player's state but never `publish`es it, so the client's
  replica keeps the last snapshot and the Hud keeps drawing "x[*] BUCK 18 R" for a tied player with
  empty hands — visible in `task35-tied-to-a-tree.png`. It is the weapon's own contract and it
  pre-dates this task; nothing revoked a gun in production until now. Not fixed here (one task,
  nothing extra); reported so it is a decision and not an oversight.
- **That `Anchored` holds against the owning client** is measured, not documented: no Roblox page
  states it. The two-player run is the evidence.
- The second row in the score screenshot (`8167651842`) is a spec-injected contributor that reached the
  live board through the production boar runtime, not a player. It is what a synthetic hit looks like
  on a real scoreboard; harmless, and named so it is not read as a bug in `Score`.

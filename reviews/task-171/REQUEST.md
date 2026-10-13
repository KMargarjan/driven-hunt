# Task 171 review request: the rules -- a shot refused before it is taken

Task: 171
Round: 1
Base: main (`a52f4d2`, #154 merged)
Code commit: `3c768c87af2b6d0f9ab43f0d427fc7b8d446c9e9`

Branch `task-171-rules`. Karen's three new rules (a beater cannot be shot at, a hunter outside his
stand circle cannot fire, a species you have no licence for cannot be shot) plus the drive's limited
shells, all refused BEFORE the shot exists and with **no punishment**. Note:
`docs/research/2026-10-13-the-rules.md`.

## Harness

```
[harness] PASS: 33/33 checks @ 3c768c87af2b6d0f9ab43f0d427fc7b8d446c9e9 (clean tree) scope=all
```

Run twice at that commit, both PASS 33/33 (server **1214** passed / 0 failed, client **302** / 0).

```
[harness2] NEEDS KAREN -- placeholder. `test2` costs one human click;
           the Director runs it at the branch head and pastes the line here.
```

**TWO OF THE DIRECTOR'S `test2` RUNS FAILED ON `zz_tie_to_a_tree.spec`, and both failures were this
task's rules working on a spec that staged the wrong thing.** The one-player run was green at both
commits, which is exactly what a two-player-only defect looks like.

* **At `5e0ee90`, 33/35, at the tie.** That spec staged its driver 25 studs out and **dead on the
  shot line** (its own note: `miss 0.0 of 12`), so the aim ray hit a beater, the shot was refused and
  there was nothing for the safety rule to judge -- `violations=0`, nobody tied.
* **At `8b2bb40`, 33/35, at the refusal AND the tie.** The probe reached the gate but came back
  `off-stand`, not `beater-in-line`: to reach the driver the spec had walked its shooter **525
  studs** from his post (the DEV arena's posts are at z = -150, the driver pad at z = +170), and off
  his own stand he may not fire at all. Its note also shows **seven earlier `off-stand` refusals** in
  the same session -- the replay walks the player about for five scenarios, so by the tie scenario he
  was nowhere near his post. Both answers were true, and nothing in the repo said which should win.

* **At `cd30764`, 33/35, at the refusal case's own staging claim -- and the TIE half came out
  GREEN** (`TIED by a shot aimed 5 studs beside the driver at 25 studs`). Three facts, and what the
  log does NOT say mattered as much as what it does: the DRIVER's pivot provably took (he read
  `z = -675`, the stand centre `-700` plus exactly `STAND_BEHIND`); the SHOOTER read **41 studs** off
  the centre, but that reading was taken ~25 s after the probe, at the end of the case, with the
  replay still holding his movement keys -- so WHEN he left his stand is not in the data at all; and
  the probe answered `refused=nil` with the barrels **unchanged** and `busy=0.60`, because the
  scenario presses **R** 1.2 s after the cue and a `busy` rejection is the REDUCER's: it commits no
  state, carries no `refused`, and reads exactly like "no rule spoke".

* **At `bac93d6`, 33/35 -- and everything but one assertion came out green.** The staging worked and
  the rule worked: `me 0.5 from the centre; driver 25.0 away; ray hit Workspace.Player2.UpperTorso`,
  `refused=beater-in-line after 2 attempt(s)`, the gun print **identical** before and after, and the
  tie case passed on the beside-aim click. The one failure was the refusal case reading
  `Match.isTied()` at the END of itself: the probe can only fire in the gap after the scenario's own
  reload (R lands 1.2 s after the cue, the reload runs 2.0 s, the first click lands at 3.8 s), so
  "after the probe" and "after the tie shot" were the same moment -- and he was, correctly, tied.

Claim 2 is the fix for all four, and **the production rules did not change for any of them**: the
game's rules got a declared ORDER, the spec got the drive's own geometry to stage from, the staging
is held and measured before each shot, and the two shots are now ORDERED and measured at their own
instant.

**This change touches `TWO_PLAYER_PATHS`** (`src/server/Match/init.luau`,
`src/server/MatchBoot.server.luau`), so the two-player line is required and is the Director's.
`tools/agents.py` will refuse this review until it is pasted -- that is expected, not a mistake.

## What changed, and how to verify each claim

1. **A shot whose aim ray would hit a beater does not fire, and costs nothing.** `Weapon.Rules` is
   pure (`beaterInLine`); `Weapon.onFireRequest` now takes the muzzle and the aim ray from the
   PRE-fire state, asks the rules, and only then calls `setState` -- so a refusal keeps the state
   the player already had. Verify: read `onFireRequest` in `src/server/Weapon/init.luau` (the block
   headed "THE RULES (task 171)") and `tests/server/weapon_rules.spec.luau`, case *"refuses a shot
   at a beater and spends no shell, then fires the same shot once the rule is gone"*. Its live note
   from the gate run: `Alhamdulilah824 refused=beater-in-line fired=nil; shots +0/+1, refused
   +1/+1; barrels Live/Live -> Live/Live -> Spent/Live`.
2. **THE ORDER IS DECLARED (`Rules.ORDER`), AND THE BOUNDARY BETWEEN THE TWO BEATER RULES IS HIS
   BODY -- there is no double handling.**
   **The order: off-stand, then the beater in the ray, then the licence.** Off-stand is a fact about
   the SHOOTER, true of every shot he takes from where he is standing, so it is the one thing he must
   fix before any other answer helps him; the beater question is about his AIM and must come before
   the licence, because a man is not quarry and `Licences` has no row for him; the licence is the
   narrowest and needs a target that published a species. `Rules.refuse` is a **pure sequencer** over
   the three predicates -- it adds no condition of its own, each question still lives in its own
   function -- and `onFireRequest` calls it once, so the order is a rule a spec can trip rather than
   an `if` chain's habit. Verify: `Rules.ORDER` and `Rules.refuse` in
   `src/server/Weapon/Rules.luau`, and `tests/server/weapon_rules.spec.luau`, case *"asks the three
   rules in one declared order, and names the winner"* -- it trips all three at once and asserts
   `off-stand`, then clears them one at a time down to a legal shot.
   **The stand circle is on the wire** (`snapshot.stands`, keyed by `tostring(userId)`, built from
   the same `Match.standAreaOf` the fire gate reads). Before this the client had no way to know
   where a hunter's stand was in the DEV world at all -- `Hud.Objective`'s own note says *"doing
   better needs the drive to publish the assigned stand index"* -- which is why the spec could only
   guess, and guessed 525 studs wrong. ONE answer, two readers; absent means no circle and therefore
   no rule, which is byte-identical to every build before this task. Verify: `Match.standAreaOf` and
   the `stands` block in `Match.snapshot`, the `stands` field in `src/shared/Drive/init.luau`, and
   the wire assertion at the end of the *"gives a stand circle to a shooter"* case (it compares the
   published circle with `Match.standAreaOf`'s own answer for every player in the session).
   **THE BOUNDARY BETWEEN THE TWO RULES IS HIS BODY** -- the answer
   to the dispatch's *"say how the two rules relate"*, which round 1 answered in prose and the
   two-player run then tested. The game's rule: the aim ray **would hit him** -> refused (no fire, no
   shell, no tie, no punishment); the ray **misses him** but the shot passes within
   `SAFETY_MISS_STUDS` (12) of him inside the arc -> **fired, and he is tied**, which is what the arc
   is for. No shot can be both: a refused shot returns before `safetySignal:Fire`. The sharp edge is
   deliberate and the reason is written down -- softening it means either punishing the refused shot
   (which Karen asked not to happen) or retiring the safety rule. `Match/Penalty.luau` is untouched
   (`git diff main -- src/server/Match/Penalty.luau` is empty).
   **No production code changed for this** -- both halves were already true; what changed is the
   STAGING, so the spec proves both instead of asserting one and staging the other:
   * **the shooter is put back ON HIS OWN STAND**, at the centre of the circle the drive published
     for him, and the case asserts he is inside it (from that same published geometry) BEFORE it
     asserts anything about his aim -- so "the beater rule is broken" can never again be confused
     with "the spec put him in the wrong place";
   * **the DRIVER's client walks itself** 25 studs in front of that stand, up +Z, at the stand's own
     height. A client may move only its own character, and the shot has to be able to reach him:
     `Buck` carries 100 studs of the 320 between the posts and the pad. The driver's client still
     never touches its camera, which was the reason `onCue` ignored it;
   * **both characters are HELD at their staged points every frame** -- the `root.CFrame` plus zeroed
     `AssemblyLinearVelocity` pair `ForestTest.boundary` uses -- because the replay holds movement
     keys and a position written once is undone by the next step of one;
   * **every pre-condition the rule needs is measured before each attempt**, and the one that fails
     is the word the note carries: inside his own circle by the published radius, the driver within
     `PROBE_REACH` (40 studs), the gun equipped, loaded and **not busy**, and a client-side raycast
     that really lands on the driver's body -- it names what is in the way otherwise, which is the
     one thing `cd30764` could not say. The numbers are recorded **at the shot** the gate judged,
     never read back afterwards;
   * **and the probe retries** at 4 a second (the limiter is 6) inside a 10-second window, because a
     mechanical rejection commits no state and costs no shell, so trying again is free -- and it is
     the only way to be sure the shot did not land in a gun whose hands were full;
   * the real replayed click aims `BESIDE_STUDS` = **5 studs** off the driver's body (11.3
     degrees at 25 studs, deep inside the 45-degree half-arc, miss 5 of 12) -> fires and ties. **The
     tie proof is not deleted and not weakened** -- same chain, same click, same assertions, pointed
     at the shot the arc exists to punish;
   * **the tie state is measured AROUND THE PROBE'S OWN SHOT** -- untied before it, untied after it,
     no new violation announced in between -- which is the claim *"a refused shot ties nobody"*
     exactly, and is **stricter** than the old `Match.isTied()` line it replaces: that one could
     also be satisfied by a probe that never fired. `probeTiedBefore` doubles as the case's starting
     condition, so a session that arrives here already tied fails on it rather than being worked
     around (`TASKS.md` 166a(b) records the same race biting `weapon_client` and `rifle_client`);
   * **and the two shots are ordered**: the aim stays ON the driver until the probe has answered, so
     a replayed click that lands early is REFUSED by the very rule being measured instead of tying
     him. The scenario clicks twice (3.8 s and 5.0 s after the cue), so the tie shot is whichever
     click follows the probe -- the tie can no longer precede it. Every attempt is logged with the
     tie state at it, so "what was the first attempt" is answered by the note and not by a counter;
   * a **probe at the cue**, before the tie shot and while the gun still exists, fires one
     `FireRequest` dead at him -> refused. The client reads the server's own word for it off the
     snapshot's new `refused` field (`beater-in-line`), with the gun print before and after proving
     **no shell was spent**. This is the only place the `refused`
     wire field is proved reaching a client (claim 8 can only assert the wire carries it).
   Verify: the header of `src/server/Weapon/Rules.luau` ("HOW THIS RELATES TO `Match.Penalty`"), and
   `tests/client/zz_tie_to_a_tree.spec.luau` -- its header, `onCue`'s probe, the aim loop's
   `BESIDE_STUDS`, the new case *"refuses a shot aimed straight at a beater, and spends nothing doing
   it"*, and the unchanged tie case after it. **Needs `test2`:** in the one-player run both cases
   take their no-driver branch (note: `one player, so no beater to refuse a shot at; probe not
   fired`).
3. **A beater is a player on the push team OR a bot.** `Match.classifyTarget` walks the hit
   instance's ancestors, asks `Players:GetPlayerFromCharacter` and reads `state.assignment` (never
   `Player.Team`), then falls back to `world.bots.isBeaterPart` -- which answers with the same
   `bot.to ~= nil` definition `Bots.beaters` uses. Verify: `Match.classifyTarget` in
   `src/server/Match/init.luau`, `Bots.isBeaterPart` plus `Bots.view` in `src/server/Bots/init.luau`.
4. **A hunter outside his stand circle cannot fire; the edge counts as inside; a beater is
   unaffected.** `Rules.outsideStand` is flat and uses `<=`, the same comparison
   `ForestTest.withinStand` makes, so task 166's soft wall cannot park a man where he may not
   shoot. The circle is `Match.standAreaFor`: the world's own answer when it has one
   (`ForestTest.standArea`, the LOCKED PICK and `PICK.standRadiusStuds`), else the post the drive
   placed him on plus `Match.CONFIG.STAND_RADIUS_STUDS` (12). nil = no circle = no rule. Verify:
   `tests/server/weapon_rules.spec.luau`, cases *"refuses a hunter outside his circle and allows him
   on its edge"* (36 bearings) and *"gives a stand circle to a shooter in this drive and none to
   anybody else"* (live note: `[Alhamdulilah824=Shooters/true] (1 shooter(s), 0 other(s))`).
5. **The licence rule is data plus a stub, and no deer exists.** `src/shared/Licences` is frozen
   (boar free, red deer licensed, `required`/`allows` pure); the licence PROVIDER is deliberately
   unwired, so the rule is reachable and inert. The boar's own trunk publishes
   `Species = "boar"` (`Boar.Body.create`), the `Damageable`/`HitZone` idiom. Verify: the two
   licence cases and *"names the species of anything that publishes one, and nobody else"* in
   `tests/server/weapon_rules.spec.luau`. **Measured live in the Forest Test** (Play, 2026-10-13):
   13 of 13 damageable boar trunks carried `Species=boar` with their kinds.
6. **12 shells per drive per kind, refilled once per drive.** One source
   (`local DRIVE_SHELLS` in `src/shared/Shotgun/init.luau` feeds `DRIVE_SHELLS` and both pockets of
   `START_RESERVE`). A new SERVER-SIDE reducer primitive `Refill` puts the pocket back without
   touching what is in the gun and is exempt from the busy window;
   `Weapon.refillForDrive(player, driveNumber)` is level-triggered on the drive number and is called
   from `Match`'s own `refreshArmingFor`, so a transition, a join, a tie and a respawn all refill
   once -- **dying mid-drive is not a resupply**. `Validator.checkRequest` is unchanged, so `Refill`
   is unreachable from the wire. Verify: the three cases under *"the drive's shells"* in
   `tests/server/weapon_rules.spec.luau` (live note: `refilled 2 weapon(s) ... pocket Slug=12`), and
   `Validator.checkRequest` in `src/server/Weapon/Validator.luau` (untouched).
7. **The Hud shows the drive's remaining reserve already.** `Hud.readoutFor`'s `pocket` is
   `state.reserve[state.ammo]`, so no Hud change was needed for item 3 of the dispatch. Verify:
   `textFor` in `src/client/Hud/init.luau` (untouched) and the gate's client note
   `weapon_client: readout: x[*] SLUG 12 R`.
8. **The client mirrors the refusal and decides nothing.** It already predicts no flash, smoke or
   bang (all come with the server's `ShotFired`). Added: `refused` on the snapshot
   (`Shotgun.snapshot`), one dry click played by `CameraBoot` on `Weapon.Changed`
   (`Weapon.Sound.dry`, `Camera.Config.SOUND_DRY_ID` = `rbxasset://sounds/clickfast.wav`, an ENGINE
   asset measured loading in this place in task 124 at 0.29 s), and the Hud's existing `notice`.
   Verify: `src/client/CameraBoot.client.luau` (the block after `Weapon.Fired`), `Sound.dry`, and
   the wire assertion in the handler case. **Not verified:** that the click is audible and sounds
   right -- nobody has heard it (the Builder cannot play audio); it is Karen's to judge.
9. **A world that wires nothing behaves exactly as before.** All three providers default to "no
   restriction" through `askTarget`/`askStand`/`askLicences`, each `pcall`ed, the rule `mayArm`
   already states. Verify: those three helpers in `src/server/Weapon/init.luau`, and that every
   `tests/server/weapon_*.spec.luau` still passes untouched (50 server spec files, 1213 assertions).
10. **Item 4 was a check and it passes.** The start card already reads `WILD BOAR, POINTS: male 10,
    female 6, cub -10` plus *"a piglet COSTS you - leave them"*. Nothing was built for it; the
    `match_config.spec` case that promised to FAIL the day a weapon-side refusal arrived was
    corrected instead of left lying, because a cub is deliberately NOT in the gate (Karen settled it
    the other way: a penalty). Verify: `Match.CONFIG.QUARRY_NOTE`/`POINTS.KIND.cub` and
    `tests/server/match_config.spec.luau`, case *"SAYS WHAT THE RULE REALLY IS"*.

## What could not be verified

* **The two-player line.** `test2` needs one human click; the Director runs it. **Everything in
  claim 2's staging is proved only there:** in a one-player run there is no driver, so neither the
  probe nor the stand pivot happens at all (note: `one player, so no beater to refuse a shot at;
  probe not fired`). What the one-player run does prove is the order (pure case), the published
  circle against `Match.standAreaOf` (live case), and the whole refusal path through
  `Weapon.onFireRequest` (handler case).
* **The refusal in a live Forest Test session**, because proving it needs somebody to pull a trigger
  at a bot. What WAS measured there (Play, ~95 s + a second ~60 s session): the Director's smoke
  check PASS -- gun in the character at 15 s and at 95 s, **0 "Stack Begin", 0 error lines**, 6 waves
  released, worst 2 boar sounds at once -- plus the species probe in claim 5 and 7 bot rigs in
  `Workspace.DriveBots`, 4 carrying a horn. The end-to-end refusal is proved in the DEV gate run
  (claim 1), through the very function `Weapon.start` connects to `FireRequest`.
* **The dry click's sound** (claim 8).
* **Whether Karen wants a POOLED 12 shells across both kinds** rather than 12 per kind. The reducer
  carries one pocket per type, so a pool would change what `state.reserve` means to the Hud's
  readout, the rifle's row and three reserve sites; it was not built, and the note records why.

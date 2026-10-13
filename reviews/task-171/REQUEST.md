# Task 171 review request: the rules -- a shot refused before it is taken

Task: 171
Round: 1
Base: main (`a52f4d2`, #154 merged)
Code commit: `e001111b7a70c28d0e1bbff26c7b3c1961771abd`

Branch `task-171-rules`. Karen's three new rules (a beater cannot be shot at, a hunter outside his
stand circle cannot fire, a species you have no licence for cannot be shot) plus the drive's limited
shells, all refused BEFORE the shot exists and with **no punishment**. Note:
`docs/research/2026-10-13-the-rules.md`.

## Harness

```
[harness] PASS: 33/33 checks @ e001111b7a70c28d0e1bbff26c7b3c1961771abd (clean tree) scope=all
```

Run twice at that commit, both PASS 33/33 (server 1213 passed / 0 failed, client **302** / 0 -- one
more than the previous code commit, which is the new refusal case).

```
[harness2] NEEDS KAREN -- placeholder. `test2` costs one human click;
           the Director runs it at the branch head and pastes the line here.
```

**The Director's `test2` at `5e0ee90` FAILED 33/35** on `[shooter] zz_tie_to_a_tree.spec:316`, and
it was this task's rule working: that spec staged its driver 25 studs out and **dead on the shot
line** (its own note, `miss 0.0 of 12`), so the aim ray hit a beater, the new rule refused the shot,
and there was nothing for the safety rule to judge -- `violations=0`, nobody tied. Claim 11 below is
the fix. The one-player run was green at that same commit, which is exactly what a two-player-only
defect looks like.

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
2. **It is not double handling with `Match.Penalty`, and nothing there changed.** The refusal
   returns before `safetySignal:Fire`, so the tie can only ever be reached by a shot that was not
   aimed at anybody. Verify: the header of `src/server/Weapon/Rules.luau` ("HOW THIS RELATES TO
   `Match.Penalty`"), and `git diff main -- src/server/Match/Penalty.luau` (empty).
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

11. **THE TWO RULES NOW HAVE A DECIDED BOUNDARY, AND IT IS HIS BODY** -- the answer to the
    dispatch's *"say how the two rules relate (no double handling)"*, which round 1 answered in
    prose and the two-player run then tested. The game's rule: the aim ray **would hit him** ->
    refused (no fire, no shell, no tie, no punishment); the ray **misses him** but the shot passes
    within `SAFETY_MISS_STUDS` (12) of him inside the arc -> **fired, and he is tied**, which is what
    the arc is for. No shot can be both: a refused shot returns before `Weapon.SafetyViolated`. The
    sharp edge is deliberate and the reason is written down (softening it means either punishing the
    refused shot, which Karen asked not to happen, or retiring the safety rule).
    **No production code changed for this** -- both halves were already true; what changed is the
    staging, so that the spec proves both instead of asserting one and staging the other:
    * the real replayed click now aims `BESIDE_STUDS` = **5 studs** off the driver's body (11.3
      degrees at 25 studs, deep inside the 45-degree half-arc, miss 5 of 12) -> fires and ties. **The
      tie proof is not deleted and not weakened** -- same chain, same click, same assertions, pointed
      at the shot the arc exists to punish;
    * a **probe at the cue**, before the click and while the gun still exists, fires one
      `FireRequest` dead at him -> refused. The client reads the server's own word for it off the
      snapshot's new `refused` field (`beater-in-line`), with the gun print before and after proving
      **no shell was spent**, and asserts that nobody was tied by it.
    Verify: `tests/client/zz_tie_to_a_tree.spec.luau` -- its header, `onCue`'s probe, the aim loop's
    `BESIDE_STUDS`, the new case *"refuses a shot aimed straight at a beater, and spends nothing
    doing it"*, and the unchanged tie case after it. The `refused` field reaching a client is proved
    here and only here (the server spec can only assert that the wire carries it, which is what
    claim 8 says). **Needs `test2`:** in the one-player run both cases take their no-driver branch
    (note: `one player, so no beater to refuse a shot at; probe not fired`).

## What could not be verified

* **The two-player line.** `test2` needs one human click; Karen is asleep. The Director runs it.
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

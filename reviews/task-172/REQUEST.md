# Task 172 review request: the horn in the hand, one horn for all, and a beater who sees the animals

Task: 172
Round: 2
Base: main (`db6bfe2`, #155 merged)
Code commit: `d1bb54cc92c0535bf30f6be7049270a6e73ce5be`

Branch `task-172-horn-hand-see-animals`. Karen, 2026-10-13 ~09:20: *"horn is hanging somehwere it has
to be in hand / all beaters has to have same horn / beaters has to see more animals when walking I
want to see how they stand and then start to run or run but I want to see them more"*, and ~09:25:
*"and again no boar behing comming after beater walk"*. Both transcribed in `PLAYTEST.md`.

## Harness

Run TWICE at the code commit, both PASS, with the same counts: server **1225 passed / 0 failed** (50
spec files), client **302 / 0** (17).

```
[harness] PASS: 33/33 checks @ d1bb54cc92c0535bf30f6be7049270a6e73ce5be (clean tree) scope=all
[harness] PASS: 33/33 checks @ d1bb54cc92c0535bf30f6be7049270a6e73ce5be (clean tree) scope=all
```

**`test2` is N/A, and the list is why**: nothing this task touches is in `TWO_PLAYER_PATHS`
(`tools/agents.py`). The changed `src/` files are `src/server/Boar/Brain.luau`,
`src/server/Boar/init.luau`, `src/server/ForestTest/init.luau`, `src/server/Weapon/Horn.luau`,
`src/shared/ForestTest/init.luau`, `src/shared/Horn/init.luau` -- no `Match/`, no `Drive/`, no
`MatchBoot` -- and the three changed specs are `boar_behaviour`, `forest_stand` and `zz_horn`.

## What changed, as claims

1. **THE GRIP POINT IS A POINT ON THE HORN, and the old one was not.** `Tool.Grip.Position` is the
   point of the Handle the hand holds (the weld is `Part0.CFrame * C0 == Part1.CFrame * C1`, C1 =
   `Grip`); `Shotgun.CONFIG.GRIP` is `(0, 0, 1.4)` on a 4.4-stud Handle, which is the wrist of the
   stock. The horn's was `(-0.8, 0.7, 0.45)` -- 1.17 studs from the centre of a Handle 0.5 x 1.1 x
   1.1, so the fist closed on air outside the object it was holding. It is `(0, 0, 0.25)` now:
   inside the horn's own body, a quarter stud from the middle toward the mouthpiece end.
   *Verify:* `Horn.CONFIG.GRIP` in `src/shared/Horn/init.luau` and its header; the case
   `closes the hand on the horn's own body, carried and raised (task 172)` in
   `tests/server/zz_horn.spec.luau`, which derives the half-extents from `Horn.MESH.SIZE_STUDS` and
   `MESH.ROTATION_DEG` rather than restating them. Note: `grip (0.00, 0.00, 0.25) inside the horn's
   half-extents (0.12, 0.22, 0.62); it was 1.15 studs out`.

2. **MEASURED LIVE, BEFORE AND AFTER, ON A PLAYER AND ON EVERY BOT.** In the Forest Test, before any
   number moved: the Handle's centre sat **1.224 studs** from the RightHand on a player beater and on
   all four bot beaters. After: **0.407** on all of them, with `Tool.Grip` reading `0.00, 0.00, 0.25`
   on every horn in the world. The horn's distance from the head in the carry went 3.41 -> 2.80.
   *Verify:* the numbers are in the `GRIP` header and in `TASKS.md` row 172; the screenshot is
   `.screenshots/20261013T094638Z-t172-grip-front.png` (a bot beater, third person, front and right;
   `.screenshots/` is git-ignored, so it is on this machine and described here).

3. **THE RAISE IS TASK 169'S, UNCHANGED, AND THAT IS A MEASUREMENT RATHER THAN AN OMISSION.**
   Re-basing `GRIP_BLOW` onto the carry point was tried FIRST and measured: the Handle stopped **2.66
   studs** from the head instead of task 169's recorded **1.77** -- the horn at the chest, not at the
   mouth. The raise clip only lifts the hand to about chest height, so what puts the mouthpiece at
   the mouth is that pose's own lateral offset. Left alone, with the cost disclosed in the file and
   queued: between carry and blast the horn slides about half a stud through the hand.
   *Verify:* the `GRIP_BLOW` header; the last third of the zz_horn case above, which asserts only
   that the blow is a different pose, pitched up and not yawed.

4. **ONE HORN FOR EVERY BEATER: the builder was already shared, the LOOK SWEEP was not.**
   `Horn.giveTo` has always called `Horn.build`, which is what a player's grant calls -- measured in
   a live session, all four bots' Handles carried `MeshPart:Model`, task 169's upload. What was not
   shared is the upgrade: `Horn.upgradeLook` walked `Players:GetPlayers()`, and a bot is not a
   player, so a bot handed its horn in the window `WeaponBoot` leaves open on purpose would carry the
   parts horn for the whole session with nothing able to notice. The horns given to a character that
   is not a player's are a registry now (`bodyTools`), pruned on read, swept on the same beat.
   *Verify:* `Horn.upgradeLook`, `Horn.bodyTools` and the `table.insert(bodyTools, tool)` in
   `Horn.giveTo` (`src/server/Weapon/Horn.luau`); the case `gives a bot beater the SAME horn, and the
   look sweep reaches it (task 172)` in `zz_horn.spec`, which grants with no provider, upgrades with
   one, and asserts the registry drops a destroyed rig.

5. **THE ENCOUNTER IS STAGED, AND THE MACHINE IS ONE PURE FUNCTION.** `ForestTest.encounterStage`
   answers `none` / `notice` / `flush` from three numbers: how far in front of the line's interpolated
   front the animal is (task 168's band, gapless across x), how far the nearest beater's body is
   (task 154's circle, a man's own reach), and how long it has been holding a look. The band and the
   circle are a **union** -- either alone is weaker than both -- and the clock ends the stand whether
   or not he has closed further. Numbers, all data: NOTICE 35 m / 125 studs, ALERT 2 s, FLUSH 20 m /
   71 studs; the horn is untouched at 100 m and skips the stand.
   *Verify:* `ForestTest.SPOOK`, `noticeStuds`, `alertSeconds`, `noticeAheadStuds` and
   `encounterStage` in `src/shared/ForestTest/init.luau`; the describe block `she sees them stand
   before they run (task 172)` in `tests/server/forest_stand.spec.luau`. Notes: `notice 35 m (125
   studs) -> stand 2.0 s -> flush 20 m (71 studs); the horn 100 m` and `notice 100 studs deep (reach
   125), flush 30 studs deep (reach 71), lanes 150 apart`.

6. **THE STAND IS THE BRAIN'S OWN ALERT STATE, ASKED FOR FROM OUTSIDE -- no new state, timer or
   number.** `Brain:notice(from, seconds)` is `_enterAlert` with the cause handed in, exactly as
   `Brain:spook` is `_flush` with the cause handed in; `Runtime:notice` is `Runtime:spook`'s shape one
   door down. Only an `IDLE` animal is accepted (`Brain.CLASS` is not the test, because ALERT is also
   "calm"), so an approach cannot re-point a herd every tick; the refractory is deliberately ignored
   and the header says why. `seconds` is the WORLD's.
   *Verify:* `Brain:notice` and `Runtime:notice`; the two cases `can be ASKED to look up...` and
   `refuses to be re-pointed once it is looking, running or gone` in `boar_behaviour.spec`. Note:
   `task 172: asked for a 1.5 s stand, held 1.50 s`.

7. **THE WOOD IS LAID BESIDE THE LANES, AND PREFERRED WHERE THE LANE CAN SEE IT.** Ten groups of 36
   animals (was six of 28), each row naming the lane it belongs to (`laneOffset`, one of the offsets
   `beaterLaneOffset` really deals out), none more than 24 studs off it against a 40-stud ceiling,
   four of them on the real beater's own lane 110 studs apart down the whole 355-stud depth.
   `ForestTest.restSeenFromLane` casts ONE ray from `laneLookPoint` -- the lane, 45 studs short of the
   group, at a walking man's eye height -- to the animal's shoulder, with `RespectCanCollide` so a
   fern is not a screen. It is the FIRST of two passes and never a rule.
   *Verify:* `ForestTest.REST`, `laneLookPoint` and `offLaneStuds` in `src/shared/`;
   `restSeenFromLane` and the two passes of `ForestTest.restSpot` in `src/server/`; the cases `lays
   every resting group beside the lane...` and `takes the look from inside the notice band...`. Notes:
   `10 groups, 4 of them on her own lane; the furthest is 24 studs off its lane (ceiling 40)` and
   `the resting band is 40-425 studs of a 580-stud walk (66% of it); keep-away 155`.

8. **NOTHING BEHIND THE LINE: the re-stock is gone, and the "place it anyway" fallback with it.**
   Task 168 measured its own remaining source -- 7 animals of 25 appearing up to 31 studs behind the
   front -- and the reason is geometric: the band is measured from the ROAD and the line is deep
   inside it fifteen seconds later. The wood is stocked ONCE (`state.restStocked`, set whether or not
   a group went down, so a failed search is not retried every heartbeat) and never again; both passes
   of `restSpot` enforce the sweep rule and neither places anyway. `REST.restockSeconds` and the
   branch it timed are archived in `backups/2026-10-13_task-172_rest-restock.md` (rule 7), logged in
   `backups/README.md`, with how to put them back.
   *Verify:* `ForestTest.stepRest` and `ForestTest.restSpot`; the end of `ForestTest.REST`; the case
   `never re-stocks the wood, which is the last way an animal could appear behind the line`.

9. **MEASURED LIVE, TWICE, OVER A WHOLE DRIVE EACH TIME, AND THE COUNT IS 0.** Beater drives in the
   Forest Test with the bot line (`DHForestStartRole=beater` for the measurement, restored to
   `hunter` afterwards), sampling every boar's position against the nearest beater (players + bot
   rigs) and the interpolated front: run 1, 14 samples, **`northOfNearest = 0` at every one** while
   the wood went 37 -> 36 -> 19 -> 8 -> 1 -> 0; run 2, 12 samples, **0 at every one**, 36 -> 5. The
   simulation half is in the spec: `task 168 sweep: 10 resting groups, front depth 30.0 studs --
   missed 0, ticks behind the line uncaught 0`.

10. **BOTH WORLDS REACHABLE BY PARAMETER.** `noticeStuds` falls back to the flush reach and
    `alertSeconds` to 0 for a world that names neither, so `encounterStage` is task 154's one-reach
    encounter exactly -- its own case, not an argument. No flag was added: this is a correction to
    numbers plus one new stage inside the beater path, and (round 1's note, which was right) that
    path is behind NO flag -- `spookNearBeaters`, `Brain:spook` and `Brain:notice` read none.

## Round 1's two findings, both fixed

1. **The keep-away was still the FLUSH reach.** `restSpot` computed `beaterSpookStuds + 30` (101)
   while `REST.farRoadStuds`'s derivation, the header above it and all three spec sites had moved to
   the NOTICE reach (155) -- and it was the only live enforcement, so a ring of the search could
   legally answer 101 studs and hand back a group that notices her before she takes a step. It reads
   `Data.noticeStuds` now. (The shipped rows were never that close: the nearest is 173.6 studs from
   her start. The guard was wrong, not the data.)
2. **A rule-7 archive that did not exist.** The comment claimed the re-stock was archived under
   `backups/` and nothing was. `backups/2026-10-13_task-172_rest-restock.md` is there now, cited by
   filename, with the deleted row, the whole deleted branch, the deleted fallback pass, why, and how
   to put it back; `backups/README.md` has its log row.

Six of the eight notes are fixed in the same round: the task-162 `farRoadStuds` paragraph is marked
as history; the four stale `SPOOK.BEATER_STUDS` citations say which reach they mean; the stand is
reported on a tick where something else also bolted; the grip case's `pitch` local held the YAW and
is renamed; the `GRIP` header cites the screenshot the request cites; and the re-stock spec case is
renamed to what its body does, with the gap stated inside it. The other two are below.

## What I could not verify (rule 8)

* **THE STAGED STAND DID NOT FIRE AT ALL IN EITHER LIVE DRIVE, AND THE REASON IS THE BOTS' HORNS.**
  Measured: no animal was ever in `ALERT` in the `[rest]` report, and the console is full of
  `horn blown at (...): 9 boar(s) pushed within 357 studs (100 m)`. Three bot beaters blowing on
  their own rhythm reach 100 m with the latch, and a horn skips the stand **by instruction** (the
  dispatch: *"the horn still flushes at 100 m (no alert)"*). So in a bots-on drive the wood is
  flushed by horns before anybody's walk-up can stage anything, and what Karen will SEE is close to
  what she saw before. The machine is proved by the specs and by `Brain:notice`; what is NOT proved
  is that she will meet it. **This is a decision, not something to fix here:** either the bot horn
  rhythm thins out, or a horn stages too, or its reach comes down. Flagged for the Director.
* **The Reviewer's own note on the same subject stands:** with a line walking at 5 studs/s the 20 m
  flush reach is effectively unreachable -- every group bolts on the 2 s clock at ~90-115 studs
  (25-32 m). `ALERT_SECONDS` is the one number to raise if she still cannot see them.
* **THE THIRD-PERSON SCREENSHOT IS OF A BOT, NOT OF KAREN'S OWN CHARACTER.** The Forest Test puts a
  beater in FIRST person (measured: the camera is `Scriptable`, 0.42 studs from the head), so a
  player's own body cannot be photographed from a solo Play session. The bot carries the identical
  Tool at the identical Grip, which is claim 4.
* **THE CARRY POSE OVERLAPS THE HIP.** In the photograph the horn's mouthpiece half is inside the
  torso, because the fist is at the hip and the horn is held at its middle. Whether the fist should
  take the narrow end instead (`GRIP.Z` 0.4-0.5, which hangs the whole horn below the hand) is
  Karen's eye and one number. Queued.
* **NOBODY HAS PLAYED IT AS A HUMAN BEATER.** Both measured drives had no human input -- the player
  beater stood where she spawned while the bots walked -- so what is measured is the rule, the count
  and the console, not the feel.
* **`restSeenFromLane`, `restSpot`'s two passes and `stepRest`'s latch have no spec of their own**
  (round 1's note, which was right): the first two raycast and the third needs a runtime. The
  evidence for them is the code and the live drives.

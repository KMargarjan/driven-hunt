# Task 172 review request: the horn in the hand, one horn for all, and a beater who sees the animals

Task: 172
Round: 1
Base: main (`db6bfe2`, #155 merged)
Code commit: `f2fcdeaec8ec111a0a87e375140cf0e1def0aeeb`

Branch `task-172-horn-hand-see-animals`. Karen, 2026-10-13 ~09:20: *"horn is hanging somehwere it has
to be in hand / all beaters has to have same horn / beaters has to see more animals when walking I
want to see how they stand and then start to run or run but I want to see them more"*, and ~09:25:
*"and again no boar behing comming after beater walk"*. Both transcribed in `PLAYTEST.md`.

## Harness

```
[harness] PASS: 33/33 checks @ f2fcdeaec8ec111a0a87e375140cf0e1def0aeeb (clean tree) scope=all
```

Server **1225 passed / 0 failed** (50 spec files), client 302 / 0 (17).

**RUN TWICE, AND THE SECOND RUN IS REPORTED HONESTLY (rule 8): it FAILED, on the input-replay
intermittent this repo has had on the record since task 71.** Same commit, no edit between them, and
the server side was identical (`1225 passed, 0 failed`); the CLIENT side read `300 passed, 2 failed`
at `weapon_client.spec:874` (`reserve.Slug` 14 against 12) and `:925` (`rises` 0 against 2) -- the
two assertions that count how many of the replayed clicks became shots. That is `TASKS.md` row
71a(a) exactly: *"the replayed third click lands after the reload has finished when the session runs
fast, so the gun is loaded when the spec expects it empty"*, a wall-clock claim about the machine.
**This task changes no client file at all** -- the six changed `src/` files are all server or shared
-- so it cannot reach that suite.

**A THIRD RUN, clean, at the paperwork commit this request sits on, is the second PASS:**

```
[harness] PASS: 33/33 checks @ 48002417f9e9f42c28448227ee28762108e39745 (clean tree) scope=all
```

Server 1225 / 0 and client 302 / 0 again. Nothing but `reviews/task-172/REQUEST.md` separates it
from the code commit.

**`test2` is N/A, and the list is why**: nothing this task touches is in `TWO_PLAYER_PATHS`
(`tools/agents.py`). The changed `src/` files are `src/server/Boar/Brain.luau`,
`src/server/Boar/init.luau`, `src/server/ForestTest/init.luau`, `src/server/Weapon/Horn.luau`,
`src/shared/ForestTest/init.luau`, `src/shared/Horn/init.luau` -- no `Match/`, no `Drive/`, no
`MatchBoot`, and the three changed specs are `boar_behaviour`, `forest_stand` and `zz_horn`.

## What changed, as claims

1. **THE GRIP POINT IS A POINT ON THE HORN, and the old one was not.** `Tool.Grip.Position` is the
   point of the Handle the hand holds (the weld is `Part0.CFrame * C0 == Part1.CFrame * C1`, C1 =
   `Grip`); `Shotgun.CONFIG.GRIP` is `(0, 0, 1.4)` on a 4.4-stud Handle, which is the wrist of the
   stock. The horn's was `(-0.8, 0.7, 0.45)` -- 1.17 studs from the centre of a Handle 0.5 x 1.1 x
   1.1, so the fist closed on air outside the object. It is `(0, 0, 0.25)` now: inside the horn's own
   body, a quarter stud toward the mouthpiece end.
   *Verify:* `Horn.CONFIG.GRIP` in `src/shared/Horn/init.luau` and its header; the case
   `closes the hand on the horn's own body, carried and raised (task 172)` in
   `tests/server/zz_horn.spec.luau`, which derives the half-extents from `Horn.MESH.SIZE_STUDS` and
   `MESH.ROTATION_DEG` rather than restating them. Its note: `grip (0.00, 0.00, 0.25) inside the
   horn's half-extents (0.12, 0.22, 0.62); it was 1.15 studs out`.

2. **MEASURED LIVE, BEFORE AND AFTER, ON A PLAYER AND ON EVERY BOT.** In the Forest Test, before any
   number moved: the Handle's centre sat **1.224 studs** from the RightHand on Karen's own player
   beater and on all four bot beaters. After: **0.407** on all of them, and `Tool.Grip` read
   `0.00, 0.00, 0.25` on every horn in the world. The horn's distance from the head in the carry
   went from 3.41 studs to 2.80.
   *Verify:* the numbers are in the `GRIP` header and in `TASKS.md` row 172; the screenshot is
   `.screenshots/20261013T094638Z-t172-grip-front.png` (a bot beater, third person, front-right).

3. **THE RAISE IS TASK 169'S, UNCHANGED, AND THAT IS A MEASUREMENT RATHER THAN AN OMISSION.**
   Re-basing `GRIP_BLOW` onto the carry point was tried first and photographed-by-measurement: the
   Handle stopped **2.66 studs** from the head instead of task 169's recorded **1.77** -- the horn at
   the chest, not at the mouth. The raise clip only lifts the hand to about chest height, so what
   actually puts the mouthpiece at the mouth is that pose's own lateral offset. It is left alone, and
   the cost is disclosed in the file and queued: between carry and blast the horn slides about half a
   stud through the hand.
   *Verify:* the `GRIP_BLOW` header in `src/shared/Horn/init.luau`; the last third of the zz_horn
   case above asserts only that the blow is a different pose and is pitched up.

4. **ONE HORN FOR EVERY BEATER: the builder was already shared, the LOOK SWEEP was not.**
   `Horn.giveTo` has always called `Horn.build`, which is what a player's grant calls -- measured in
   Karen's live session, all four bots' Handles carried `MeshPart:Model`, task 169's upload. What was
   not shared is the upgrade: `Horn.upgradeLook` walked `Players:GetPlayers()`, and a bot is not a
   player, so a bot handed its horn in the window `WeaponBoot` leaves open on purpose would carry the
   parts horn for the whole session with nothing able to notice. The horns given to a character that
   is not a player's are a registry now (`bodyTools`), pruned on read, swept on the same beat.
   *Verify:* `Horn.upgradeLook`, `Horn.bodyTools` and the `table.insert(bodyTools, tool)` in
   `Horn.giveTo` (`src/server/Weapon/Horn.luau`); the case
   `gives a bot beater the SAME horn, and the look sweep reaches it (task 172)` in `zz_horn.spec`,
   which grants with no provider, upgrades with one, and asserts the registry drops a destroyed rig.

5. **THE ENCOUNTER IS STAGED, AND THE MACHINE IS ONE PURE FUNCTION.** `ForestTest.encounterStage`
   answers `none` / `notice` / `flush` from three numbers: how far in front of the line's interpolated
   front the animal is (task 168's band, gapless across x), how far the nearest beater's body is
   (task 154's circle, a man's own reach), and how long it has been holding a look. The band and the
   circle are a **union** -- either alone is weaker than both, and the header says why. The clock ends
   the stand whether or not he has closed further. Numbers: NOTICE 35 m / 125 studs, ALERT 2 s, FLUSH
   20 m / 71 studs; the horn is untouched at 100 m and skips the stand entirely.
   *Verify:* `ForestTest.SPOOK`, `noticeStuds`, `alertSeconds`, `noticeAheadStuds` and
   `encounterStage` in `src/shared/ForestTest/init.luau`; the describe block
   `she sees them stand before they run (task 172)` in `tests/server/forest_stand.spec.luau`. Notes:
   `notice 35 m (125 studs) -> stand 2.0 s -> flush 20 m (71 studs); the horn 100 m` and
   `notice 100 studs deep (reach 125), flush 30 studs deep (reach 71), lanes 150 apart`.

6. **THE STAND IS THE BRAIN'S OWN ALERT STATE, ASKED FOR FROM OUTSIDE -- no new state, timer or
   number.** `Brain:notice(from, seconds)` is `_enterAlert` with the cause handed in, exactly as
   `Brain:spook` is `_flush` with the cause handed in; `Runtime:notice(id, from, seconds)` is
   `Runtime:spook`'s shape one door down. Only an `IDLE` animal is accepted (`Brain.CLASS` is not the
   test, because ALERT is also "calm"), so an approach cannot re-point a herd every tick; the
   refractory is deliberately ignored and the header says why. `seconds` is the WORLD's, because how
   long a group stares before it breaks is a property of the drive.
   *Verify:* `Brain:notice` in `src/server/Boar/Brain.luau`, `Runtime:notice` in
   `src/server/Boar/init.luau`; the two cases `can be ASKED to look up...` and `refuses to be
   re-pointed once it is looking, running or gone` in `tests/server/boar_behaviour.spec.luau`. Note:
   `task 172: asked for a 1.5 s stand, held 1.50 s`.

7. **THE WOOD IS LAID BESIDE THE LANES, AND PREFERRED WHERE THE LANE CAN SEE IT.** Ten groups of 36
   animals (was six of 28), each row naming the lane it belongs to (`laneOffset`, one of the offsets
   `beaterLaneOffset` really deals out), none more than 24 studs off it against a 40-stud ceiling, and
   four of them on the real beater's own lane 110 studs apart down the whole 355-stud depth.
   `ForestTest.restSeenFromLane` casts ONE ray from `laneLookPoint` -- the lane, 45 studs short of the
   group, at a walking man's eye height -- to the animal's shoulder, with `RespectCanCollide` so a
   fern is not a screen; it is the FIRST of two passes, never a rule, because a wood where every legal
   spot is screened is a wood with no animals in it.
   *Verify:* `ForestTest.REST` and `laneLookPoint` / `offLaneStuds` in `src/shared/ForestTest/`;
   `restSeenFromLane` and the two passes in `ForestTest.restSpot`
   (`src/server/ForestTest/init.luau`); the cases `lays every resting group beside the lane...` and
   `takes the look from inside the notice band...`. Notes: `10 groups, 4 of them on her own lane; the
   furthest is 24 studs off its lane (ceiling 40)` and `the resting band is 40-425 studs of a
   580-stud walk (66% of it); keep-away 155`.

8. **NOTHING BEHIND THE LINE: the re-stock is gone, and the "place it anyway" fallback with it.**
   Task 168 measured its own remaining source -- 7 animals of 25 appearing up to 31 studs behind the
   front -- and the reason is geometric: the band is measured from the ROAD and the line is deep
   inside it fifteen seconds later, so the deep rows have nowhere left that is in front of anybody.
   The wood is stocked ONCE (`state.restStocked`, set whether or not a group went down, so a failed
   search is not retried every heartbeat) and never again; `restSpot` has two passes now and both
   enforce the sweep rule. `REST.restockSeconds` is deleted with the behaviour it timed.
   *Verify:* `ForestTest.stepRest` and `ForestTest.restSpot` in `src/server/ForestTest/init.luau`;
   the end of `ForestTest.REST` in `src/shared/`; the case `never re-stocks the wood, which is the
   last way an animal could appear behind the line`.

9. **MEASURED LIVE OVER A WHOLE DRIVE, AND THE COUNT IS 0.** A beater drive in the Forest Test with
   the bot line (`DHForestStartRole=beater` for the measurement, restored to `hunter` afterwards),
   sampled 14 times across the drive: for every boar, the nearest beater (players + bot rigs) and
   whether it was north of him. **`northOfNearest = 0` at every sample**, while the wood went 37 ->
   36 -> 19 -> 8 -> 1 -> 0 as the line swept it. The simulation half is in the spec: `task 168 sweep:
   10 resting groups, front depth 30.0 studs -- missed 0, ticks behind the line uncaught 0`.
   *Verify:* the note above in the gate log, and `TASKS.md` row 172.

10. **BOTH WORLDS REACHABLE BY PARAMETER.** `noticeStuds` falls back to the flush reach and
    `alertSeconds` to 0 for a world that names neither, so `encounterStage` is task 154's one-reach
    encounter exactly -- asserted as its own case rather than argued. The sweep's own OFF case is
    unchanged. No flag was added: this is a correction to numbers and a stage inside a path that is
    already behind `HORN` and `BOAR_BEHAVIOUR`.

## What I could not verify (rule 8)

* **THE THIRD-PERSON SCREENSHOT IS OF A BOT, NOT OF KAREN'S OWN CHARACTER.** The Forest Test puts a
  beater in FIRST person (measured: the camera is `Scriptable` and 0.42 studs from the head), so a
  player's own body cannot be photographed from a solo Play session; a second player is `test2`,
  which this change does not otherwise need. The bot carries the identical Tool at the identical
  Grip, which is exactly claim 4.
* **THE CARRY POSE OVERLAPS THE HIP.** In the photograph the horn's mouthpiece half is inside the
  character's torso, because the fist is at the hip and the horn is held at its middle. Whether the
  fist should instead take the narrow end (`GRIP.Z` 0.4-0.5, which hangs the whole horn below the
  hand) is Karen's eye and one number. Queued.
* **THE HORN SLIDES THROUGH THE HAND DURING A BLAST** (claim 3). Queued.
* **NOBODY HAS PLAYED THE STAGED ENCOUNTER AS A HUMAN BEATER.** The live drive that measured the
  count had no human input -- the player beater stood where she spawned while the bots walked -- so
  what is measured is the rule, the count and the console, not the feel. Whether 35 m / 2 s / 20 m is
  what she wants to SEE is Karen's judgement and all three are data.
* **THE BOTS EMPTY THE WOOD FAST.** In the measured drive the line swept 37 animals out in about 80
  seconds, because a bot walks faster than the stocked depth is long. That is not new and not this
  task's, but it is what a human beater walks into.

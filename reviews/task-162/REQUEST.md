# Task 162 — a longer drive: the beaters' walk takes ~2 minutes

Task: 162
Round: 1
Base: `b8ed152` (main)
Code commit: `9f7c82e022bd5f1c9f64d288fe52d9c76083c210`

```
[harness] PASS: 33/33 checks @ 9f7c82e022bd5f1c9f64d288fe52d9c76083c210 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 9f7c82e022bd5f1c9f64d288fe52d9c76083c210 (clean tree) scope=all
```

Two full one-player runs, both at the code commit on a clean tree. `test2` is **N/A**: no file in
this change is in `TWO_PLAYER_PATHS` (`src/shared/ForestTest/`, `src/server/ForestTest/`,
`src/server/Bots/`, `src/client/Hud/`, `tests/server/forest_stand.spec.luau`,
`tests/server/bots_lane.spec.luau` — none of the match, drive, tie or teams paths).

## What changed

Karen, 2026-10-12: *"can we make drive longer, it's to fast / good for testing but now need longer
walk for beaters let's say 2 min"*. A bot line is what ENDS a drive in the Forest Test
(`Match.beaterCrossing` counts bot beaters into the line), so the pair **(where the line starts, how
fast a bot walks)** IS the length of a drive. It was 240 + 20 studs at 9 studs/s = 29 s. It is now
**580 + 20 studs at 5 studs/s = 120.0 s**, and everything derived from the start follows as data.

Four files of code, two of specs. No new module, no new state, no behaviour: every change is a
number, a comment, or an assertion.

## Claims

1. **`Bots.CONFIG.WALK_SPEED` 9 → 5 and `ForestTest.BEATER.behindLineStuds` 60 → 400 make a
   two-minute walk.** Verify: `(ForestTest.LINE.spawnNorthStuds 180 + behindLineStuds 400 +
   Match.CONFIG.BOTS.GOAL_PAST_LINE_STUDS 20) / 5 = 120.0`. Asserted, not commented, in
   `tests/server/bots_lane.spec.luau` → *"the length of the walk"* → *"takes about two minutes at
   the bot pace"* (105–135 s). Harness note: `a bot beater walks 600 studs at 5.0 studs/s = 120.0 s`.

2. **MEASURED IN THE PLACE, AND IT IS WHY THE PACE CAME DOWN RATHER THAN THE START GOING OUT.**
   Forest Test, Edit, 2026-10-12, nine stand columns x 2430–3630 sampled every 25 studs to 1,000:
   terrain carries past 1,000 studs north at every one with no gap, but the **trees** (a colliding
   part within 25 studs) run out at **775–850** and past that it is bare hillside. 120 s at 9
   studs/s needs 1,060 studs of wood; the wood is ~775 deep, so 9 cannot make two minutes. 5 studs/s
   is **1.40 m/s** at `ForestTest.SPOOK.METRES_PER_STUD`, a real walking pace; 9 was 2.52 m/s.
   Verify: the measurement is written into `ForestTest.BEATER`'s header and
   `Bots.CONFIG.WALK_SPEED`'s; the pace band is asserted in `bots_lane.spec` → *"walks at a real
   walking pace, in metres"*.

3. **The pad at 580 is ground the drive can actually start from.** `Markers.read` refuses
   `forest:beater-start` when terrain and `groundAt` disagree by more than `GROUND_TOLERANCE_STUDS`,
   and a refusal leaves the Forest Test in `Waiting` for ever (task 158). Measured at the default
   stand's column: terrain 234.1, `groundAt` 234.1, **delta 0.00**, `roomToStand` true, nearest
   trunk 12.4 studs. Verify in the live run: `[ForestTest] Alhamdulilah824 is a beater at
   (3030, 237, -1517), 580 studs from the road`.

4. **`REST.farRoadStuds` 160 → 460 is DERIVED, not chosen**: `580 − (SPOOK.BEATER_STUDS 89 +
   REST.clearOfStartStuds 30) = 461`, taken to 460. Without it the six groups would sit in the last
   quarter of the walk and the first 420 studs would be empty wood — task 154's own defect in a new
   form. Verify: `tests/server/forest_stand.spec.luau` → *"takes the band as deep as the keep-away
   allows"*, which asserts BOTH directions (`farRoadStuds + keepAway <= start` **and** within 2 studs
   of it, so the band cannot be left short). Harness note: `the resting band is 40-460 studs of a
   580-stud walk (72% of it); keep-away 119`.

5. **The six `REST.groups` are respread deepest-first over 55–440 studs, and no two are inside one
   spook reach.** The fright latches, so two groups within `BEATER_STUDS` (89) bolt on one approach
   and six groups give her three events. Verify: `forest_stand.spec` → *"never puts two resting
   groups inside one spook reach of each other"*, measured over all fifteen pairs **in the world
   frame** (not the depth difference: `restPoint` adds `roadZ(x)` and the road is a sine). The first
   layout of the table was 94.7 studs apart against a reach of 89 — 5.7 studs of margin, which the
   ring search (up to 64 studs) could have closed — so two offsets were widened and the measured
   closest pair is **121.7**. The assertion demands reach + 25. Harness note: `6 groups over 385
   studs of depth (55 to 440); closest pair 122 studs, reach 89`.

6. **Every one of the six is a group the wood can hold.** Each nominal point was driven through the
   real `restSpotOk` rules against the live place: all six find a legal spot within search ring 0 or
   1 of four, 9.6–18.7 studs from the nearest trunk (`clearStuds` 8 to `nearTrunkStuds` 22), on the
   terrain and off a canopy. Verify in the live run: `[ForestTest] the wood is stocked: 28 animal(s)
   in 6 group(s) — ... 1 at -9/+439 (trunk 13); 2 at +95/+354 (trunk 10); 9 at -110/+279 (trunk 10);
   9 at +76/+199 (trunk 19); 6 at -70/+119 (trunk 18); 1 at +98/+54 (trunk 15)`.

7. **`AHEAD_STUDS >= WALK_SPEED * MOVE_REISSUE_SECONDS` is now true and is asserted.**
   `AHEAD_STUDS`'s own comment claims the aim point is "always still ahead of the bot when the next
   re-issue comes round"; at `WALK_SPEED` 9 the product was 18 against 12, so the comment was false.
   At 5 it is 10. Verify: `bots_lane.spec` → *"keeps the aim point ahead of the bot between
   re-issues"*. **What is NOT claimed** is that the old pace was actually clamped by that cadence:
   task 161 printed `walkSeconds 30.0` for a 260-stud walk, which is 8.7 studs/s and not the 6 a hard
   clamp would give. The comment in `Bots.CONFIG` says exactly that rather than inventing a cause.

8. **A real player is not slowed.** Nothing in `Bots` writes a player's `WalkSpeed`; `Match.Body` is
   the only writer and still hands out `Body.defaultWalkSpeed()` (16). Verify: grep `WalkSpeed` under
   `src/server/Bots/` — the only write is `Rig.apply`'s, onto the BOT's own humanoid. The CONSEQUENCE
   is stated rather than hidden: `bots_lane.spec` → *"does not slow a real beater down, and says what
   that costs"* notes `a real beater walks it in 38 s at 16 studs/s and then waits 82 s for the bot
   line` — because *"all beaters cross"* is the line and not the first of it. **That wait is a feel
   call and it is Karen's.**

9. **Everything else that derives from the start already derived.** The bot LANES are perpendicular
   to the push (`Bots.Lane.offsetFor` along the base's `RightVector`), so depth does not touch them.
   The map's bounds and beater marker come from `LINE.spawnNorthStuds + BEATER.behindLineStuds` in
   `MapUi.geometryFromForestTest`, and `DRIVERS.startNorthStuds` (700) is still the larger, so the
   picture is unchanged — verify `tests/client/map_ui.spec.luau` → *"holds everything that world
   states inside its bounds"*, which checks `beaterStart` against those bounds. The restock keep-away
   reads LIVE beater positions (`restSpot` → `realBeaters`, which has included bots since task 161),
   so it followed with no change. Six comments that stated the old 240 were corrected
   (`src/server/ForestTest/init.luau` ×3, `src/client/Hud/MapUi.luau`, `forest_stand.spec` ×2).

10. **SMOKE IN THE FOREST TEST, 196 s of Play with Karen's own settings (`DHFlag_DRIVE_BOTS=true`,
    `DHForestStartRole=hunter`), and it is the claim that matters.** `[bots] drive 3 hunters, 4/4
    beaters (0 failed, 0 stale) | 4 walking, 3 arrived in **132.5s** | **0 stuck**, 698 side-steps, 0
    no-ground | 17 blasts (0 refused) | step 0.27 ms avg, 24.49 ms max`. Sampled bot depth north of
    the road: t+15 s 519–555, t+45 s 383–434, t+90 s 189–240, t+130 s 5.6–62.6, t+165 s all four
    NEGATIVE (−9.9 to −38.2, i.e. through the line). Drive 1 released **eight** waves instead of the
    one and a half a 29-second drive allowed. **Whole console: no "Stack Begin", no "attempt to", no
    "invalid argument", no error line, no warning.** Tool in the CHARACTER at t+15/45/90/130/165 s
    (`hand=Shotgun bag=Rifle`); at t+195 s the teams had swapped and she was a beater
    (`hand=Horn bag=`), which is the beater loadout and not a regression.

## Screenshots (rule 5), both inspected

`.screenshots/20261012T090523Z-task162-beater-pad-looking-south.png` — the new beater pad, looking
down the push. Standing birch wood, trunks at arm's length, grass and dappled light, the ground
cresting ahead and falling away. The road is NOT visible: she cannot see the line she is pushing at,
which is what a 580-stud start is for. `...-task162-pad-from-above.png` — continuous canopy over the
pad and on into the distance: the wood at 580 studs out is real wood, not the bare hillside the
measurement says begins past ~775.

## What I could NOT verify

* **Whether two minutes is the right two minutes.** It is a feel number and it is Karen's. The three
  dials are `BEATER.behindLineStuds`, `Bots.CONFIG.WALK_SPEED` and `END_ON_BEATERS_CROSS`.
* **The real beater's 82-second wait** (claim 8). Measured arithmetic, not played: nobody has walked
  it as a player at 16 studs/s since the change.
* **698 side-steps.** 0 stuck, so the nudge is doing its job, but the walk is 4.4× longer than the
  one that number was last seen on and there is no baseline for a walk this deep. It is a number for
  the Director, not a defect I can name.
* **`docs/design/bots.md` sections 5.2 and 15.1 still state the 29-second arithmetic**, and the
  Builder does not write designs (the same shape as 161a(k)). Flagged for the Director.

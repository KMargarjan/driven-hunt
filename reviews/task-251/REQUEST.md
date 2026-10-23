# Task 251 part 1: the drive pattern as a fifteen-slot script, and the opening horn's own reach

Task: 251
Round: 2
Base: 4b6e1638 (main, the task-250 merge)
Code commit: fdd7aff11b1c7d5261a24b38fd72027963a82cd8

```
[harness] PASS: 34/34 checks @ fdd7aff11b1c7d5261a24b38fd72027963a82cd8 (clean tree) scope=all
```

(That sha is the paperwork commit at the branch head; the last commit that changed `src/` or `tests/`
is `840db687`, and only `reviews/task-251/RESULT.md` and `ESCALATE.md` changed after it -- which is
git workflow step 4's own case, and it only makes the bound stricter.)

`[harness2]` is **N/A**: no file in `TWO_PLAYER_PATHS` is touched (the drive's data and release path,
the boar's deer compositions, the horn's data, the Forest Test boot). Who the OTHER player is answers
nothing about which group comes out of which zone.

## What changed, and what it is NOT

KAREN, 2026-10-23: *"we need better saound and behaviour for red stag / and them patter with animals
how many where they come how they come how many groups jumping over road red stags ect"*, then `"ok"`
to the Designer's plan (`<runs-dir>/design/driveflow-spec.md`, with `driveflow-plan.png`).

**This is PART 1 of a dispatch the Director allowed to be split: items 1 (the drive pattern) and 4
(the opening horn's radius). Items 2 and 3 -- the stag's own behaviour and his voice, including the
Freesound CC0 roar upload -- are the next session and nothing here claims them.** The stag's
behaviour fields (`check`, `sneak`) are DATA declared by the script and honoured only as far as the
EXISTING edge stop goes; a spec case pins exactly that boundary so the day part 2 reads them, the
assertion is what changes.

**The one thing the Director must read before anything else: `ESCALATE.md`, 2026-10-23, task 251.**
A Forest Test drive ends when the beater line arrives, at a MEASURED 125-133 s, not at
`DRIVE.seconds` 300 -- so at the 20-second interval only slots 1-5 of the fifteen ever happen, and
the stag, both refusals and the hold do not. That is a feel decision (one number) and it is Karen's.
It is not a defect in the code below, and it is not hidden: the escalation carries the console
measurement, five options and a recommendation.

## The claims

1. **The drive is fifteen rows of DATA, in three acts, and the six-row repeating `cycle` is gone.**
   `ForestTest.SCHEDULE.drive` in `src/shared/ForestTest/init.luau`: one row per slot, carrying who
   (`species`/`party`/`composition`), where (`zone`/`northStuds`/`offsetX`), when (`slot`/`atSeconds`/
   `act`), how (`route`/`files`/`pace`/`crossOffset`) and the dial (`keepAt`).
   *Verify:* read the table and its header; `tests/server/forest_line.spec.luau`, `describe("the drive
   script (task 251)")`, case *"is fifteen slots of one drive..."* -- every row's `atSeconds` is
   asserted to be `Data.slotSeconds`'s own arithmetic rather than a second clock, and the acts are
   asserted to be five slots each. The old table is archived verbatim with its reason in
   `backups/2026-10-23_task-251_schedule-cycle.md` (rule 7).

2. **Karen's counts come out of the rows, not out of a comment.** 13 groups, 59 animals, 10
   crossings, 2 refusals, 1 that never comes, 2 deer groups, 2 silences.
   *Verify:* `ForestTest.driveTally` (pure, `src/shared/ForestTest`) counts them off the rows and
   counts NO animals -- how much a composition weighs is the boar system's fact. The spec case
   *"answers Karen's counts at the dial she OK'd"* adds the animals through `Boar.compositionSize`
   and `Boar.deerComposition`, so the number 59 cannot drift from the table.

3. **59 and not the spec's 57, and the difference is written down rather than fudged.** Three rows
   are written in the spec as `{females = 1, cubs = 4}` / `{females = 2, cubs = 3, males = 1}`, which
   are not among the six `SOUNDER.COMPOSITIONS` rows -- while the spec's own sentence is *"not one new
   composition is invented"*. Each takes composition 5, the nearest real row, which weighs 6 and not 5.
   *Verify:* the `59 AND NOT THE SPEC'S 57` paragraph in the table's header; the spec case *"names
   only crossings, compositions and parties that exist"* asserts every row's composition index and
   every deer row's party name resolve through the animal's owner.

4. **The quiet/normal/busy dial is ONE number and ONE rule.** `SCHEDULE.density` (default `normal`,
   which is what Karen OK'd) and `row.keepAt <= groups`. The four rows at `keepAt = 13` ARE the stag,
   the two refusals and the hold, so one number moves all five columns of the dial's table -- there is
   no `refusalsPerDrive` to keep in step with it.
   *Verify:* case *"moves all five of the dial's columns with ONE number"*: quiet 9 groups / 37
   animals / 0 refusals / 0 holds / 1 deer group, normal 13 / 59 / 2 / 1 / 2, busy 15 / 69 / 2 / 1 / 2.
   An unknown word is `normal` and not silence (`groupsWanted`), because a typo in a dial must not
   empty the wood.

5. **ROUND 1'S BLOCKING FINDING IS FIXED, AND IT WAS RIGHT.** `stepLines`' stuck-leader repath
   read `line.crossing.X`, and this task made `line.crossing` nil for exactly the two route words
   that never reach the road -- so the first stuck leader of a `BREAK-BACK` or `HOLD` file would have
   raised "attempt to index nil" inside the drive's own un-pcalled Heartbeat connection, losing the
   rest of that tick, every stuck check, for the life of the line. A `HOLD` file stands still BY
   DESIGN, which is the case the stuck rule exists to catch.
   The fix is the thing the review named: the per-file PINS the release computes (the turn and the
   way home, the hold point, or the crossing and the exit) are now kept on the line, and
   `ForestTest.repathVia` -- **pure**, so the case can be driven with no live runtime, no wedged
   animal and no three seconds of not moving -- turns a position plus those pins into the
   `computeRouteVia` argument, or **nil when there is nothing to pin through**, in which case the
   leader is left to the Brain (which is what the `leaderFreeSeconds` window beside it is for).
   *Verify:* `ForestTest.repathVia` and its header; the repath block in `ForestTest.stepLines`;
   `tests/server/forest_line.spec.luau`, case *"RE-PINS A STUCK LEADER THROUGH ITS OWN PINS, and
   never through a crossing that is nil"*, which builds a `BREAK-BACK` row's pins the way
   `releaseLine` builds them and asserts the via list, and asserts nil for no pins at all.

6. **Five route types, all of them the same machinery.** `ForestTest.computeRoute` is now the
   two-leg call of `ForestTest.computeRouteVia`, a chain of pathfinder legs pinned through points the
   DRIVE chose -- the agent, the clearance and the `clearRoute` body sweep are untouched. STRAIGHT is
   what every wave did; LATERAL walks `WAVE.lateralSpan` across her front at `WAVE.lateralDz` first;
   **BREAK-BACK is new and is Karen's *"several go back"*, which has never been drawn** -- it comes to
   `turnAtDz` of the road and goes home north to `SCHEDULE.breakBackToDz`, crossing nothing; SPLIT
   gives the second file its own crossing `splitStuds` away; HOLD is a route that ends 300 studs
   short of the verge, after which `CALM.ENABLED` takes the group over.
   *Verify:* the `THE ROUTES, ONE PER ROUTE WORD` block in `ForestTest.releaseLine`; the spec cases
   *"gives every route word a shape, and the one that never crosses no crossing"* and *"refuses a
   route that is not pinned through at least two points"*. Measured live (claim 11): the LATERAL and
   the two-file STRAIGHT rows both released and walked.

7. **`releaseLine` reads the row instead of drawing the drive.** The count (was 4-9 at random), the
   crossing (was one of five at random), the pace (was `paceMix`) and the depth (was
   `LINE.spawnNorthStuds`, one number for every wave) all now come from the slot.
   *Verify:* `ForestTest.releaseLine`'s `THE SLOT (task 251)` block. **Both release paths read the
   rows through ONE FUNCTION** -- `ForestTest.waveAt` -- so there is one reader of the table and not
   two. Round 1's note is right that this is NOT "both paths agree about the drive": `release` asks
   `waveAt(state.waveIndex + 1)` (session-wide) while `releaseLine` asks `waveAt(state.driveWave)`
   (per drive), so they index the same rows at different slots, and a `reddeer` row on the wave path
   has no `spec.composition` and would release one `"male"`. That path is unreachable while
   `LINE.enabled = true` and this task does not fix it; the claim here is the reader, not the
   agreement. A silence returns nil from both and **still costs its slot**, because the
   shape is the fifteen rows in order and a skipped gap would pull act III forward by 40 s.

8. **A deer row names its PARTY, and the animal's owner still owns the vocabulary.**
   `SPECIES.reddeer.RELEASE.COMPOSITIONS` rows gained a `name`, and `Boar.deerComposition`'s `wanted`
   may be a string. A name that matches nothing is nil -- not a draw and not the first row. The
   chance clause is skipped by a named ask too, so a `CHANCE_PER_RELEASE` of 0 cannot silently refuse
   the drive's own scripted stag.
   *Verify:* `tests/server/deer.spec.luau`, case *"GIVES THE PARTY THE DRIVE NAMED..."*; `name` is
   stripped from the returned group exactly as `weight` is (asserted), and `compositionFormation`'s
   own `type(count) == "number"` guard already skips it.

9. **ITEM 4: the opening signal alerts, and the beater's hand horn is untouched.**
   `Horn.SIGNAL.SPOOK_STUDS = 120` (33.6 m) for `SPOOK_SECONDS = 3`, read by the new
   `Horn.signalSpookStuds` / `Horn.signalSpookSeconds`; `Horn.SPOOK_STUDS` stays 357 with its own
   reader, so neither radius can be got out of the other by accident. It goes through
   `Runtime:notice` (head up, faces the line) and **not** `Runtime:spook` (runs, and with `untilExit`
   never stops). Wired at the composition root on the `Running` edge -- the instant `Match.Phase`
   emits the `start` signal -- so `src/server/Match/` is untouched.
   *Verify:* `tests/server/zz_horn.spec.luau`, cases *"gives the OPENING SIGNAL its own, much shorter
   reach"* and *"falls back to the hand horn's reach for a config written before task 251"*;
   `ForestTest.signalPoint` / `ForestTest.signalHeard` and the `Running` branch of
   `ForestTestBoot.server.luau`.

10. **ITEM 4, THE CORRECTION THE SPEC NEEDED (rule 8).** The spec says *"today any horn blast spooks
   every animal within 357 studs ... so the opening signal currently empties most of the wood before
   the drive starts"*. **It does not, and it never has.** The only thing that reached
   `Runtime:hearHorn` was `Weapon.Horn.Blown`, the HAND horn; the opening signal is a `Match.Phase`
   feed entry consumed by `Hud` on the CLIENT as a 2-D fanfare, and nothing on the server ever heard
   it. So item 4 is a reach of **0 becoming 120**, not 357 becoming 120 -- and what the 120 protects
   is the drive script, since a 357-stud signal would reach the far wood (dz 360) and move slot 15
   before slot 1 was released.
   *Verify:* grep `hearHorn` across `src/` -- two callers, both `Weapon.Horn.Blown` handlers (this
   boot and `MatchBoot`); grep `"signal"` -- `Match/Phase.luau` emits it, `client/Hud` consumes it,
   nothing else. The `WHAT WAS ACTUALLY THERE BEFORE THIS TASK` paragraph above
   `ForestTest.signalPoint` says it in the code.

11. **THE FOREST TEST PROOF, on Karen's path, and what it could NOT produce.** One Play session in
    **Driven Hunt Forest Test** (130094961655666), enrolled at the truck pad (rule I), four drives.
    Every slot released exactly as its row wrote it -- kinds, files, zone depth, offset, crossing,
    route and the silence:

    ```
    line 1:  SLOT 1 act 1 STRAIGHT -- 1 of 1 animal(s) [male] in 1 of 1 file(s) at a trot, from dz 95 offset -150, crossing -70 studs from the stand
    line 2:  SLOT 2 act 1 STRAIGHT -- 2 of 2 animal(s) [hind+calf] in 1 of 1 file(s) at a walk, from dz 125 offset +170, crossing +55 studs from the stand
    line 5:  SLOT 3 act 1 STRAIGHT -- 6 of 6 animal(s) [female+cub+cub+cub+cub+male] in 2 of 2 file(s) at a trot, from dz 110 offset -215, crossing -35 studs
    line 6:  SLOT 4 act 1 STRAIGHT -- 2 of 2 animal(s) [male+male] in 1 of 1 file(s) at a trot, from dz 85 offset +60, crossing +20 studs from the stand
    line 7:  slot 5 of the drive is SILENT -- nothing released
    line 8:  SLOT 6 act 2 LATERAL -- 8 of 8 animal(s) [female+female+female+male+male+male+male+male] in 1 of 1 file(s) at a trot, from dz 150 offset +235, crossing +20 studs
    line 9:  SLOT 7 act 2 STRAIGHT -- 9 of 9 animal(s) [female+female+cub+cub+cub+cub+male+male+male] in 2 of 2 file(s) at a trot, from dz 170 offset -120, crossing -35 studs
    ```

    **The horn's two radii, measured there and not here** -- the opening signal on a drive whose wood
    was stocked, beside the hand horn's own unchanged line from the same session:

    ```
    [ForestTest] opening signal: 9 of 9 animal(s) within 120 studs put their heads up (the beater's hand horn still reaches 357)
    [ForestTest] horn blown at (3826, 222, -2905): 0 boar(s) pushed within 357 studs (100 m), 0 credited
    ```

    **WHAT IT COULD NOT PRODUCE, and why (rule 8):** the two frames the dispatch asks for -- the stag
    stopping and looking back at the verge, and the hinds in file -- **were not taken.** The stag is
    slot 13 and **no drive ever reached slot 6 or beyond** (`ESCALATE.md`: a drive ends at 125-133 s
    when the beater line arrives; the slots above past 5 are from drive 1, which opened late and
    ran longer). The hind party of slot 2 released and crossed in two of the four drives, but by the
    time the session could be pointed at it the wood held 18 animals and none was a deer (measured,
    `Boars` folder read). **No frame of either is claimed, and no frame was taken.** Part 2 owns the
    stag; the frames belong with the decision in `ESCALATE.md`.

    The place's attributes were read before anything (`placeId=130094961655666`,
    `DHFlag_BOAR_BEHAVIOUR/BOAR_MODEL/COINS/DEER_ROAD_LEAP/DRIVE_BOTS/HORN/LICENCE_POPUP/LOBBY/SHOP=true`,
    `DHForestStartRole=hunter`, `DHShopTestGrant=true`), **none was changed**, and the re-read at the
    end is identical. Play was stopped, the place left in Edit and its window closed
    (CloseMainWindow, Don't Save) before the harness ran; the harness log says DEV.

## What could not be verified

- **The second half of the pattern has never run.** Slots 8-15 -- both refusals, the split, the
  stag, the last pair and the one that holds -- are proved only as DATA and as pure arithmetic. Their
  ROUTES (`BREAK-BACK`, `SPLIT`, `HOLD`) have never been walked by an animal, because no drive got
  that far. `ESCALATE.md` is the decision that unblocks them, and part 2's own Forest Test run is
  where they would first be seen.
- **The deer-party hold-over has not been seen working.** The run MEASURED the defect
  (`slot 2 wanted the hinds and the deer cap refused -- nothing released`) and the fix is written and
  gated, but a drive in which a refused party is then released at slot 5 has not been observed.
- **Nothing about how any of it LOOKS.** No frame was taken in this session at all (see claim 11).
- One client spec (`camera_client.spec:1618`, a `handsMissing` counter in a case this task touches no
  part of) failed in the FIRST harness run of this task and passed in the two since, with no change
  to any camera or viewmodel file between them. Reported as a flake rather than explained; it is not
  in this task's blast radius and nothing was changed for it.
- **Round 2 changed no behaviour that the live run covered**, so the Forest Test run above was NOT
  repeated. What round 2 changed is the stuck-leader repath (a path the live run never reached, by
  claim 11's own admission), the `deerDone` latch's condition, one `Horn` fallback that the shipped
  config does not use, and comments. The gate ran again in full on the clean tree at the code commit.

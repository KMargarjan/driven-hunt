# Task 160 — scoring by the animal, a beater's push, and a first place

Task: 160
Round: 1
Base: `94fc315` (main, #142 merged)
Code commit: `58a4ca3dc50f70d8ee8628bd3c5ee5892d61253d`

Harness, one player, the FULL run, twice on the clean tree at the code commit:

```
[harness] PASS: 33/33 checks @ 58a4ca3dc50f70d8ee8628bd3c5ee5892d61253d (clean tree) scope=all
[harness] PASS: 33/33 checks @ 58a4ca3dc50f70d8ee8628bd3c5ee5892d61253d (clean tree) scope=all
```

```
[harness2] <placeholder — NEEDS TEST2 160 58a4ca3dc50f70d8ee8628bd3c5ee5892d61253d>
```

**`test2` IS REQUIRED AND THE BUILDER DID NOT RUN IT.** This change touches `TWO_PLAYER_PATHS`
(`src/server/Match/`, `src/server/MatchBoot.server.luau`, `tests/server/match_*.spec.luau`,
`tests/client/match_client.spec.luau`). The Director runs it, per his own dispatch: *"stop 'NEEDS
TEST2 160 <sha>' with a [harness2] placeholder; I run test2 + the review."* **The Forest Test Studio
was left OPEN but its Play session was STOPPED and it is back in Edit mode** (verified: `forest mode:
Edit`), so `test2` is free to use it.

## What changed

A kill is scored by the **animal** instead of by the hit zone; a **beater** earns for an animal he
pushed that somebody then shot, and the horn is now a door into that credit; the results table marks
a **first place**. Points only — no money (step 3b). One score owner, no second score, no new remote.

Note: `docs/research/2026-10-12-scoring.md`. Archive: `backups/2026-10-12_task-160_points-by-hit-zone.txt`.

## Claims, and how to verify each

1. **A kill is priced by `record.kind` and by nothing else.** `Match.Score.pointsForKind` reads
   `config.POINTS.KIND`; `Score.kill` no longer reads `killingZone` at all. Verify: `match_score.spec`,
   describe "the kill" — "pays what the ANIMAL is worth, exactly" (male 10, female 6, cub 2,
   legendary 25), "pays a male more than a female and a female more than a cub (Karen's rule)", "pays
   an unknown kind as a female -- never free", and **"pays the same for a head shot and a leg shot on
   the same animal"**, which is the retired rule asserted as retired: without it, putting the zone
   table back would pass. The award's reason is now `kill-<kind>` / `kill-unknown`.

2. **The hit zone is retired from scoring and from nowhere else.** Grep `POINTS.KILL` in `src/`:
   the only hits are comments naming it as retired. The zone still decides whether the animal dies
   (`Boar.Wound`), is still on the kill record (`Match`'s `driveKills` keeps `zone`), still drawn on
   the report's silhouette (`ReportPanel`'s `RING`/`drawDots`) and still printed in its ZONE column
   (`ReportPanel.detailRowText`). Rule 7: the whole old table, `pointsForZone`, its call sites and the
   old diagnostic are in `backups/2026-10-12_task-160_points-by-hit-zone.txt` with a rollback
   paragraph, and a row is in `backups/README.md`.

3. **The owner's unknown-kill diagnostic followed the rule it guards.** `stats.unknownZoneKills`
   became `stats.unknownKindKills` and `Match`'s `onDowned` tests `config.POINTS.KIND[record.kind]`.
   Verify: grep `unknownZoneKills` — no hits in `src/` or `tests/` outside the archive and two
   history comments. A zone typo can no longer misprice a kill; a KIND typo can, and that is what is
   counted.

4. **A beater is paid for the animal's LAST credit before it died, and a tie pays everybody tied.**
   `Match.Score.latestPushers` takes the max timestamp in `pushCredit` and returns every userId at it,
   sorted. Verify: `match_score.spec`, describe "the beater's push" — "pays the beater whose credit is
   the LAST one before the kill" (3 at t=9 earns nothing, 5 at t=18 earns 3), "pays everybody tied on
   the latest credit, because 2 Hz sampling ties them", "never pays the shooter who killed it a push
   as well", "pays nobody at all when nothing pushed it", "is worth less than the animal, and switches
   off at 0" (with `BEATER_PUSH = 0` the row still counts the push and the points are 0).
   The tie rule is a **judgement call against the dispatch's "the beater who caused it", stated**:
   `PUSH_SAMPLE_HZ` is 2, so two beaters walking one animal up are written in the same tick with
   identical timestamps, and "the last one" would then be `pairs` order or `userId` — a coin flip the
   loser watches.

5. **The horn is a second door into push credit, and the BOAR's owner decides which animals it
   reached.** `Runtime:hearHorn` returns `(count, ids)` — the ids of the animals that actually RAN,
   so a carcass, a terminal boar and a crippled one (all refused by `Brain:spook`) are not in it. The
   first return is unchanged, which is why every older caller is untouched. Verify: `zz_horn.spec`,
   "pushes every live boar inside the radius and nothing outside it" (the two inside are in `ids`, the
   far one is not) and "ignores a nonsense blast rather than erroring on it" (the second return is an
   empty table, never `nil`, because `Match.creditPush` iterates it).

6. **Only a beater of a live drive is credited, and a phantom beater earns nothing by
   construction.** `Match.pushCreditable(userId, team, live)` is pure: a number userId, a live drive,
   `team == "Drivers"`. A phantom (the quick test's `"quick-test"`, the forest's wave beaters) has no
   userId and cannot reach it. Verify: `match_live.spec`, in the task-83 phantom case — six
   `pushCreditable` assertions covering every branch, then the real owner refusing all three
   (`creditPush(nil, …) == 0`, `creditPush("quick-test", …) == 0`, `creditPush(<stranger>, …) == 0`
   with `stats().hornCredits` unchanged).

7. **Both worlds' composition roots wire it, and neither learns the other's rule.**
   `MatchBoot.server.luau` and `ForestTestBoot.server.luau` each take `blast.blowerUserId` (which
   `Weapon/Horn.luau` has always published) and the ids from `hearHorn`, and hand both to
   `Match.creditPush`. The horn publishes a fact, the boar owner answers which animals it reached, the
   drive decides what it is worth. Verify: read the two `Weapon.Horn.Blown:Connect` blocks. The forest's
   console line now ends `…, %d credited`.

8. **The results table marks a first place, and marks nobody when it would be a lie.**
   `Hud.firstPlaceRank(rows)` returns 1 only when the top row has scored something AND is strictly
   ahead of the second. Verify: `match_client.spec`, "marks the leader 1st, and marks nobody when the
   top two are level" — clear leader → 1; alone having scored → 1; **tie at the top → nil**;
   all-noughts board (two rows and one) → nil; empty and nil → nil; all-negative board with a
   least-negative leader → 1. And "puts the badge on the drawn row, on the leader's row only": the
   badge is in row 1 and not in row 2, and it sits AFTER the points. The sort and the rank themselves
   are not new — `Score.leaderboard` → `Match.snapshot` already ordered the board by points, and
   `match_score.spec` "sorts by points, then kills, then the earliest first kill, then userId" is
   rewritten for the new scale (three players tied on 12, separated by kill count then first-kill
   time). Hunters and beaters are in ONE table, as dispatched; the split is `TASKS.md` 160a(c).

9. **The start card reads the same points table, with no second copy.** `Match.quarryLines` prices
   each kind from `cfg.POINTS.KIND`, prints a kind with no row with no number rather than a wrong one,
   and leaves the word POINTS off a line where nothing is priced. Verify: `match_config.spec`,
   describe "the quarry lines" — three new cases plus the pre-existing cub-rule case, whose evidence
   is now `KIND` (`cub > 0`, `cub < female < male`). The live note from the harness run:
   `match-config: the start card's quarry lines -> WILD BOAR, POINTS: male 10, female 6, cub 2 | every
   one of them counts - no cub rule yet`.

10. **The rest of `POINTS` was rescaled for scale, not taste, and the scale is asserted.**
    `ASSIST` 10 → 3, `SAFETY_PENALTY` −50 → −10. Against a 10-point male the old numbers were one
    animal and five, so one safety violation would have ended a board irrecoverably. Verify:
    `match_score.spec`'s last describe — "are the numbers production ships" now asserts **both
    directions** of `POINTS.KIND` (no production kind without an asserted price) and that
    `POINTS.KILL` and `POINTS.PUSH` are **gone**, not merely unread; and "costs one animal and not a
    whole drive" (`-SAFETY_PENALTY == KIND.male`, and less than a whole drive's six animals).
    `match_safety.spec` asserts the live −10 and that it equals one male; its second case now reads
    the number off the config instead of typing it a second time (that duplication is what the first
    gate run caught).

## What I could not verify

* **The horn → credit → points chain end to end.** Every link has a spec (claims 5, 6, 4), but no
  spec reaches a beater blowing a horn at a sounder that a hunter then shoots: that needs a live
  drive with two roles and a kill. `TASKS.md` 160a(d).
* **A BADGED row on a screen.** The screenshot (rule 5, inspected:
  `.screenshots/20261012T005515Z-task160-results-table-forest.png`) is the results table at the end of
  a real 300-second Forest Test drive — `DRIVE 1 RESULTS`, the header, `1  Alhamdulilah824  DRIVER
  0  0`, `NEXT DRIVE IN 24`. Nobody fired a shot in that solo session, so the board is all noughts
  and there is correctly **no badge**. The badge's own text and position are asserted by
  `match_client.spec` (`1  Alhamdulilah824  SHOOTER      2      16  1st`), not seen on a screen.
* **Every number in `POINTS` is Karen's and she has seen none of them.** `TASKS.md` 160a(a).
* **`docs/design/drive.md` section 7.1 is now stale** (it documents the zone table, `PUSH = 25` and
  `unknownZoneKills`). The Architect owns that file; flagged in the code, the note and 160a(b), not
  edited by the Builder.
* **`test2`**, above.

# Task 160 — scoring by the animal, a beater's push, and a first place

Task: 160
Round: 2
Base: `94fc315` (main, #142 merged)
Code commit: `f4ec27f66a1f4b98267259294f133b696433c1cf`

Harness, one player, the FULL run, twice on the clean tree at the code commit (DEV alone — the
Forest Test Studio is closed):

```
[harness] PASS: 33/33 checks @ 38b88536e81d3295aef5d3fae09b904fa6da2975 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 38b88536e81d3295aef5d3fae09b904fa6da2975 (clean tree) scope=all
```

```
[harness] PASS: 33/33 checks @ f4ec27f66a1f4b98267259294f133b696433c1cf (clean tree) scope=all
[harness2] PASS: 35/35 checks @ f4ec27f66a1f4b98267259294f133b696433c1cf (clean tree)
```

**`test2` IS REQUIRED AND THE BUILDER DID NOT RUN IT.** This change touches `TWO_PLAYER_PATHS`
(`src/server/Match/`, `src/server/MatchBoot.server.luau`, `tests/server/match_*.spec.luau`,
`zz_drive_boundary.spec.luau`, `tests/client/match_client.spec.luau`). The Director runs it, per his
own dispatch: *"Stop 'NEEDS TEST2 160 <sha>'."* Round 1's `[harness2] PASS: 35/35 @ b35e9d1` does
**not** carry over — that was a different commit, and this round changes `src/`.

## What changed

A kill is scored by the **animal** instead of by the hit zone; a **beater** earns for an animal he
pushed that somebody then shot, and the horn is a second door into that credit; the results table
marks a **first place**. Points only — no money (step 3b). One score owner, no second score, no new
remote.

**Round 1 was FINDINGS (1 blocking) and it was right:** every assertion about `Match.creditPush` was
a refusal, so `function Match.creditPush() return 0 end` passed the whole gate. Claims 5–7 below are
what changed; claims 1–4 and 8–10 are unchanged from round 1 and are restated so this page is the
final state, not a history.

Note: `docs/research/2026-10-12-scoring.md`. Archive: `backups/2026-10-12_task-160_points-by-hit-zone.txt`.

## Claims, and how to verify each

1. **A kill is priced by `record.kind` and by nothing else.** `Match.Score.pointsForKind` reads
   `config.POINTS.KIND`; `Score.kill` no longer reads `killingZone` at all. Verify: `match_score.spec`,
   describe "the kill" — "pays what the ANIMAL is worth, exactly" (male 10, female 6, cub 2,
   legendary 25), "pays a male more than a female and a female more than a cub (Karen's rule)", "pays
   an unknown kind as a female -- never free", and **"pays the same for a head shot and a leg shot on
   the same animal"**, which is the retired rule asserted as retired: without it, putting the zone
   table back would pass. The award's reason is now `kill-<kind>` / `kill-unknown`.

2. **The hit zone is retired from scoring and from nowhere else.** Grep `POINTS.KILL` in `src/`: the
   only hits are comments naming it as retired. The zone still decides whether the animal dies
   (`Boar.Wound`), is still on the kill record (`Match`'s `driveKills` keeps `zone`), still drawn on
   the report's silhouette (`ReportPanel`'s `RING`/`drawDots`) and still printed in its ZONE column
   (`ReportPanel.detailRowText`). Rule 7: the old table, `pointsForZone`, its call sites and the old
   diagnostic are in `backups/2026-10-12_task-160_points-by-hit-zone.txt` with a rollback paragraph,
   and a row is in `backups/README.md`.

3. **The owner's unknown-kill diagnostic followed the rule it guards.** `stats.unknownZoneKills`
   became `stats.unknownKindKills` and `Match`'s `onDowned` tests `config.POINTS.KIND[record.kind]`.
   Verify: grep `unknownZoneKills` — no hits in `src/` or `tests/` outside the archive and two history
   comments.

4. **A beater is paid for the animal's LAST credit before it died, and a tie pays everybody tied.**
   `Match.Score.latestPushers` takes the max timestamp in `pushCredit` and returns every userId at it,
   sorted. Verify: `match_score.spec`, describe "the beater's push" — "pays the beater whose credit is
   the LAST one before the kill", "pays everybody tied on the latest credit, because 2 Hz sampling
   ties them", "never pays the shooter who killed it a push as well", "pays nobody at all when nothing
   pushed it", and **(new, round 1 note 3)** "reads BEATER_PUSH and not ASSIST, which production
   happens to set to the same number": both are 3 in production, so every other case passed with the
   two config keys swapped inside `Score.kill`; this one drives a config where they differ (5 and 9)
   and reads each award off its own key.

5. **THE FIX FOR ROUND 1's BLOCKING FINDING: the write and the read are pure, exported, and used by
   the owner itself.** `Match.writePushCredit(credits, userId, boarIds, at)` is the loop `creditPush`
   runs once it has decided to pay; `Match.pushCreditWithin(credits, boarId, at, window)` is what the
   local `creditFor` — the function `onDowned` hands straight to `Score.kill` — now *is*, not a copy
   of. `Match.pushCreditFor(boarId)` reads the owner's own table as a copy with no setter, the
   discipline `Runtime:perceptionOf` and `Runtime:woundOf` already follow. Verify: read
   `Match.creditPush`, `Match.writePushCredit`, `Match.pushCreditWithin`, `creditFor`, `onDowned` in
   `src/server/Match/init.luau` — `creditFor` is three lines and delegates.

6. **The write is now proved POSITIVELY, twice, and both cases fail if it is deleted.**
   * **Pure, no drive** — `match_live.spec`, continuing the task-83 phantom case:
     `writePushCredit(credits, 42, {"A", "B", 7, false}, 100) == 2`, `credits.A[42] == 100`,
     `credits[7] == nil` (a non-string id is skipped, never `credits[nil]` — task 83's "table index
     is nil"), a second blast at the same animal returns 0 and *refreshes* the timestamp to 140, a
     second BEATER on it returns 1, a nil list returns 0; then `pushCreditWithin` including at
     `seen + window` and excluding at `seen + window + 1`, and answering an empty table for an
     unknown or nil boar id.
   * **Live, through the real owner** — `zz_drive_boundary.spec`, "pays a beater through the live
     owner, and the credit is where Score.kill will read it": in a real `Running` drive, a HUNTER is
     refused (`creditPush(userId, {"zzBoarA"}) == 0` — the `state.assignment` read nothing reached
     before); the same player is made a beater with `Match.requestTeam`; `creditPush(userId,
     {"zzBoarA", "zzBoarB", 7}) == 2`; `stats().hornCredits` rises by exactly 2; the credit reads back
     through `Match.pushCreditFor`; `Score.kill` then pays him `BEATER_PUSH` for an animal a
     **different** userId shot; a second blast at the same animal returns 0 and leaves `hornCredits`
     alone. His side is put back at the end. The harness note from the run:
     `zz_drive_boundary: horn credit -> 2 animal(s), hornCredits +2, beater paid 3 point(s)`.
   * **Still only negative:** `creditPush` with `nil`, with `"quick-test"` and with a stranger's
     userId, plus the six pure `pushCreditable` branches (`match_live.spec`).

7. **The horn is that door's one caller, and the BOAR's owner decides which animals it reached.**
   `Runtime:hearHorn` returns `(count, ids)` — the ids of the animals that actually RAN, so a carcass,
   a terminal boar and a crippled one (all refused by `Brain:spook`) are not in it; the first return
   is unchanged, which is why every older caller is untouched. Both composition roots take
   `blast.blowerUserId` (which `Weapon/Horn.luau` has always published) plus those ids and hand them
   to `Match.creditPush`. Verify: `zz_horn.spec` ("pushes every live boar inside the radius and
   nothing outside it" asserts the two inside are in `ids` and the far one is not; "ignores a nonsense
   blast" asserts the second return is an empty table, never `nil`), and read the two
   `Weapon.Horn.Blown:Connect` blocks — **round 1 note 1 is fixed: `MatchBoot`'s binding is `ids`,
   not `pushed`**, which is what `ForestTestBoot`'s `pushed` already means beside it.

8. **The results table marks a first place, and marks nobody when it would be a lie.**
   `Hud.firstPlaceRank(rows)` returns 1 when the top row is strictly ahead of the second; with only
   one row it also requires that the row has scored something. **Round 1 note 2 is fixed:** the zero
   test used to be asked of the leader's own points, so a leader on 0 ahead of −10 got no badge while
   a leader on −10 ahead of −20 got one — the function disagreed with itself about the same shape of
   board. Verify: `match_client.spec`, "marks the leader 1st, and marks nobody when the top two are
   level" — clear leader → 1; alone having scored → 1; tie at the top → nil; all-noughts board (two
   rows, and one) → nil; empty and nil → nil; (−10, −20) → 1; **(0, −10) → 1**. And "puts the badge on
   the drawn row, on the leader's row only": the badge is in row 1, not in row 2, and sits AFTER the
   points. The sort and the rank are not new — `Score.leaderboard` → `Match.snapshot` already ordered
   by points — and `match_score.spec`'s order case is rewritten for the new scale (three players tied
   on 12, separated by kill count then first-kill time). Hunters and beaters are in ONE table, as
   dispatched; the split is `TASKS.md` 160a(c).

9. **The start card reads the same points table, with no second copy.** `Match.quarryLines` prices
   each kind from `cfg.POINTS.KIND`, prints a kind with no row with no number rather than a wrong one,
   and leaves the word POINTS off a line where nothing is priced. Verify: `match_config.spec`,
   describe "the quarry lines" — three new cases plus the pre-existing cub-rule case, whose evidence
   is now `KIND` (`cub > 0`, `cub < female < male`). The live note from the run:
   `match-config: the start card's quarry lines -> WILD BOAR, POINTS: male 10, female 6, cub 2 | every
   one of them counts - no cub rule yet`.

10. **The rest of `POINTS` was rescaled for scale, not taste, and both the scale and the retirement
    are asserted.** `ASSIST` 10 → 3, `SAFETY_PENALTY` −50 → −10: against a 10-point male the old
    numbers were one animal and five, so one violation would have ended a board irrecoverably. Verify:
    `match_score.spec`'s last describe asserts **both directions** of `POINTS.KIND` (no production
    kind without an asserted price) and that `POINTS.KILL` and `POINTS.PUSH` are **gone**, not merely
    unread; "costs one animal and not a whole drive"; and `match_safety.spec` asserts the live −10,
    that it equals one male, and reads the number off the config in its second case rather than typing
    it twice. **Round 1 note 4 is also fixed here:** `stats().hornCredits` counted every id, so a
    beater blasting one animal twice inside the window read as two credits though `credit[userId] =
    at` is idempotent; `writePushCredit` counts NEW credits and its comment is true again.

## What I could not verify

* **A beater actually blowing a horn.** Every link of horn → credit → points now has a spec (claims
  6 and 7), including the live owner paying a beater, but no spec reaches `Weapon.Horn.Blown` firing
  from a horn in a hand: that needs a live drive with a horn. `TASKS.md` 160a(d), corrected this round
  (the round-1 wording claimed `creditPush` was called with a hunter's userId; it was not then, and it
  is now).
* **A BADGED row on a screen.** The screenshot (rule 5, inspected,
  `.screenshots/20261012T005515Z-task160-results-table-forest.png`) is the results table at the end of
  a real 300-second Forest Test drive, all noughts and correctly **no** badge. The badge's text and
  position are asserted by `match_client.spec` (`1  Alhamdulilah824  SHOOTER      2      16  1st`).
* **The new start-card line on a screen** (round 1's last note): 43 characters in a 408 px label at
  size 18, against a 41-character line that already rendered in task 158's frame. The Forest Test
  Studio is closed and this dispatch forbids reopening it, so no frame was taken. `TASKS.md` 160a(h).
* **Every number in `POINTS` is Karen's and she has seen none of them.** `TASKS.md` 160a(a).
* **Three design places are stale** — `drive.md` §7.1, `drive.md`'s `stats` comment, and
  `forest-drive.md`'s `samplePush` row. The Architect owns them; `TASKS.md` 160a(b), widened this
  round with the two the Reviewer found.
* **`test2`**, above.

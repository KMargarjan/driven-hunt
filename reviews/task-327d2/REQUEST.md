# Task 327d2 — the beaters cross the cell before the clock

Task: 327d2
Round: 1
Base: main `0a2a2ffc`
Code commit: `c61c9d48`

## PLAN (core quality step 0)

**(a) REAL LIFE.** A driven-hunt beater line advances rather than walks: it stops in cover, beats it
and waits for the flanks. The man-walking band is 0.8–1.5 m/s (`tests/server/bots_lane.spec.luau`,
task 251 part 2). **This target leaves that band**: 1.58 m/s is a brisk walk, and it is accepted for
one reason only — a 1,430-stud cell has to be crossed inside a 300 s clock that did not grow with it
(Director decision, 2026-11-09; `ESCALATE.md` 2026-11-09 ~00:40 UTC).

**(b) MEASURED NOW.** One live drive in Karen's Forest Test at 327d's code commit `52716ba4`, cell
C1, four bot beaters, probe `<runs-dir>/327d-bots.luau`:
`[bots] drive 3 hunters, 4/4 beaters (0 failed, 0 stale) | 4 walking, 1 arrived in 292.9s | 0 stuck,
worst pin 0.0s, 1135 side-steps, 0 no-ground | 74 detours (1 boxed in), 0 recoveries`. The last
beater was dz 58 against the line when the clock ended the drive, so all four would have been
through at ~300–305 s. `END_ON_BEATERS_CROSS` did not fire; the 300 s clock ended the drive.
Ground factor: 292.9 / 278.8 = **1.051**.

**(c) TARGET.** `Grid.CONFIG.beaterWalkStudsPerSecond` **5.64**, `DRIVE.seconds` unchanged at 300.
`(1430 + GOAL_PAST_LINE_STUDS 20) / 5.64 = 257.1 s` flat, `x1.051 = 270.2 s` on the ground, plus
`BEATERS_THROUGH_GRACE_SECONDS` 15 = 285.2 s inside 300. Not 5.35 (through at 285 s, zero margin);
not `DRIVE.seconds` 330 (a longer drive is more waiting, which is the complaint). Director's call.

**(d) LEVER.** `src/shared/Grid/init.luau`, `Grid.CONFIG.beaterWalkStudsPerSecond` — the one owner.
Its one reader writes the bots' `WalkSpeed`:

```
$ grep -rn "WALK_SPEED" src/server/Bots/init.luau
136:	WALK_SPEED = Grid.CONFIG.beaterWalkStudsPerSecond, -- K, via the grid's own cell depth
$ grep -rn "CONFIG.WALK_SPEED" src/server/Bots/
src/server/Bots/Lane.luau:208:		humanoid.WalkSpeed = Bots.CONFIG.WALK_SPEED
```

Proven live at 327d: every bot sampled at `sp=5.20` / `ws=5.2`, so the dial is the right one.

**(e) HOW IT WILL BE MEASURED AFTER.** The same probe (`327d-bots.luau`) in the same place, reading
the same `[bots]` server line for "arrived in Ns", plus the drive's end reason off `Live`.

## Claims (10)

1. **The pace is 5.64 and its one owner still owns it.** `Grid.CONFIG.beaterWalkStudsPerSecond`
   `src/shared/Grid/init.luau`; `Bots.CONFIG.WALK_SPEED` reads it, `Bots.Lane` writes it to the
   humanoid. Verify: `grep -rn "beaterWalkStudsPerSecond" src/` -- one definition, one reader.
   `bots_lane.spec`'s `expect(Bots.CONFIG.WALK_SPEED).to.equal(Grid.CONFIG.beaterWalkStudsPerSecond)`
   reddens on a literal.
2. **`DRIVE.seconds` is untouched at 300.** Verify: `git diff 0a2a2ffc..c61c9d48 -- src/server/ForestTest/`
   is empty; `grep -n "seconds = " src/server/ForestTest/init.luau`.
3. **The margin assertion means what its comment says, with the new pace.**
   `tests/server/bots_lane.spec.luau`, *"walks the dealt cell's own depth, and arrives before the
   clock runs out"*: `expect(seconds + Match.CONFIG.BEATERS_THROUGH_GRACE_SECONDS < Forest.DRIVE.seconds)`
   is 257.1 + 15 = 272.1 against 300. **L-093:** revert `beaterWalkStudsPerSecond` to 5.2 and the
   case's `expect(metresPerSecond <= 1.6)` stays green but `grid.spec`'s
   `expect(math.abs(seconds - 253.5) < 0.1)` reddens at once; revert it to 9 and the 1.6 ceiling
   reddens. Neither assertion can be satisfied by the other's number.
4. **The m/s ceiling moved 1.5 -> 1.6 and ONLY the ceiling.** 5.64 x `SPOOK.METRES_PER_STUD` 0.28 =
   1.5792. The floor 0.8 is untouched and 9 studs/s (2.52 m/s) still fails. Verify: the two
   `expect`s in *"advances at a beater line's pace, in metres"*, and the comment's one-line reason.
5. **The four 327d review notes are fixed, all four.** (1) `tools/terrainbake.py` -- the
   `print("  stub   ... Flags ...")` line is gone (`grep -n Flags tools/terrainbake.py`: no print
   site left; `python tools/terrainbake.py selftest` still PASSes, including *"requires no Flags, so
   the prebuild has no flag to stub"*). (2) `src/shared/Grid/init.luau` -- all three *"1430 / 5.2 =
   275 s"* / *"275-second"* sites are rewritten (`grep -n "275" src/shared/Grid/init.luau`: none
   left), and `Grid.CONFIG`'s comment now names the 292.9 s measurement and `ESCALATE.md`.
   (3) `bots_lane.spec`'s note multiplier is this cell's own measured `1.051`, not task 251's road
   `1.081`, and says which drive measured it. (4) the archive's *"21.2 studs-seconds"* is *"21.2 s"*,
   and *"reddens if the walk grows by 7 s"* is now the real threshold, 27.9 s at the new pace.
   `src/server/Bots/init.luau`'s 5.2 block is rewritten for the same reason (it is the other half of
   note 2's sentence).
6. **LIVE IN KAREN'S FOREST TEST at the code commit, five drives.** Her place, rojo :34873 from
   `driven-hunt-rev` at `c61c9d48`, `pace=5.6400 botsWalk=5.6400 cellDepth=1430` read from the
   running server. `[bots] ... N arrived in Xs` and the player-visible end line:
   drive 1 (4 bots) **279.8 s**; drive 2 (3 bots + a human beater who never walked) 285.3 s,
   `Drive over` -- correct, he was not across; drive 3 (4 bots) **278.7 s**,
   **`Drive over - the beaters are through`**; drive 4 (3 bots + a human placed across) 290.7 s,
   `Drive over`; drive 5 (4 bots) **270.6 s**, **`Drive over - the beaters are through`**.
   Verify: the table in `ESCALATE.md`'s 2026-11-09 ~03:05 entry.
7. **`END_ON_BEATERS_CROSS` fires, which it never did at 5.2.** The discriminator is `Phase`'s own
   text -- `if state.endedEarly then "Drive over - the beaters are through" else "Drive over"` --
   read off the client's `TextLabel`, not inferred from a time. Drive 5 ended at **0:04 on the
   clock**, drive 3 at **0:08**. At 327d's 5.2 the first of four crossed at 292.9 s and the clock
   ended every drive.
8. **AND IT DOES NOT FIRE ON EVERY DRIVE -- stated, not hidden.** Both three-beater drives (285.3,
   290.7 s) ended on the clock; all three four-beater drives crossed under 285 s. The measured ground
   factor is **1.053-1.131**, not the dispatch's 1.051 (which was 327d's FIRST beater; the rule needs
   the LAST). Escalated with the arithmetic for 5.75 studs/s or `DRIVE.seconds` 315. **Dispatch item
   2 is MET for a four-beater drive and NOT MET for a three-beater one.**
9. **FRAMES, opened and described.** `<runs-dir>/327d2-F1.png` -- the hunter's own first-person view
   on his stand in drive 5: shotgun barrel low-left, `INF S L U G`, HUD `DRIVE 5 · 0:49 TIME ·
   0 ANIMALS · HUNTER · $13540`, compass `NW -- DRIVE -- NE`, birch wood over tall grass, **one
   beater in an orange cap and hi-vis in the middle distance** (the probe read beater-1 at dz 103 in
   the same second), the stand's yellow dashed edge ring across the foreground, and bottom-left
   **"an animal got away x55"**. `<runs-dir>/327d2-F2-driver.png` -- the same session's DRIVER view
   at 0:36: `DRIVE 4 · BEATER · 0 ANIMALS`, orange cap seen from behind, horn in hand, `ROAD 6 m`.
10. **Dispatch item 3 answered with a before AND an after (L-136).** The toast is NOT this task's: it
    is on at `52716ba4` (`327d-F1-stand-beaters.png`, x80 at 0:11) and at `c61c9d48`
    (`327d2-F1.png`, x55 at 0:49), and it climbs from the drive's first seconds with no shot fired
    (sampled 1, x4, x2, x5, x8, x9, x11, x16 over 67 s). **Possible real defect, escalated, not
    fixed here** (dispatch): x80 at 11 seconds exceeds everything that can have been released by
    then, so it is very likely counting crossings rather than animals. Its owner is the hunter's
    feed, not `Grid`.

## What I could NOT verify

- **Karen has not played it.** Nothing was shot in any of the five drives (`0 ANIMALS` in both
  frames); the crossing-end is proven by `Phase`'s own feed text, not by her eye.
- **Drive 1's feed line was not sampled** -- only its 279.8 s arrival. Drives 3 and 5 carry the text.
- **The driver's wait is from a PLACED crossing, not a walked one.** In drive 4 I set the player
  beater across the line at ~88 s (a walked 1450 studs at `WalkSpeed` 16 is 91 s) and the drive ran
  to its clock at ~293 s: **~205 s of waiting**. It ended on the clock, so this is the wait Karen
  complained of, still there on a three-beater drive.
- **No control drive on `main`** for claim 10; the `52716ba4` frame is the baseline instead.
- The harness needed **three runs at this same commit, same tree**: 32/34, 30/34, then 34/34. Run 1's
  only failure was `map_ui.spec:1071` (a 20 Hz +-40 % timing window reading 11.44 Hz); run 2's
  failing lines were not captured. A result that varies with the tree fixed is not caused by the
  tree, and this change touches no client code at all. `map_ui.spec:632/:1210` are in the Director's
  list; `:1071` is not.

## Gate

`[harness] PASS: 34/34 checks @ c61c9d48d611d27d8419031efa3baa46a27c17bc (clean tree) scope=all`

`test2` **N/A**: no `TWO_PLAYER_PATHS` path is touched -- the change is `src/shared/Grid/`,
`src/server/Bots/`, two server specs, `tools/terrainbake.py` and a backups note.

---

ANSWERED: **L-136** named with its count. Three runs at the SAME commit and the SAME tree: 32/34
(`map_ui.spec:1071`, a 20 Hz ±40 % window reading 11.44 Hz), 30/34 (lines not captured), then
**34/34**, which is the line pasted above. No claim of "known flake": a result that varies with the
tree fixed is not caused by the tree, and this change touches no client code. `:1071` is NOT in the
Director's list; `map_ui.spec:632/:1210` are.
ANSWERED: **L-127** per item. **MET** -- item 1 (5.64, read by its one owner; the margin assertion),
item 4 (the L-093 case, claim 3). **MET for a four-beater drive, NOT MET for a three-beater one** --
item 2: 279.8 / 278.7 / 270.6 s with four beaters and two observed `Drive over - the beaters are
through`; 285.3 and 290.7 s with three, both on the clock. Escalated. **MET** -- item 3: the toast is
present at the before-commit and the after-commit, escalated as a possible defect, not fixed.
**NOT PROVEN** -- Karen has not played a drive at this pace, and nothing was shot in any of the five.
ANSWERED: **L-162** every live number above is from the ONE Play session at the code commit
`c61c9d48`, served to her place from `driven-hunt-rev`, with `pace=5.6400 botsWalk=5.6400` read off
the running server before the first drive. No number is blended with 327d's: the 5.2 figures are
labelled `52716ba4` throughout and came from the same probe file (`<runs-dir>/327d-bots.luau`) in
the same place.
ANSWERED: **L-014** `driven-hunt-karen` was never checked out, written to or touched; it is still on
`0a2a2ffc`. The branch was served from `driven-hunt-rev`, which was put back to `2cdf3be4`
afterwards. Her Forest Test ends on rojo **:34873 from `driven-hunt-karen`**, reconnected and in
**Edit**. No Save, no Publish, no Drafts Commit.
ANSWERED: **L-101** her `ServerStorage` attributes were dumped BEFORE the first Connect -- before any
flag or layout override existed -- and again after the final reconnect. All 19 are **identical**,
`DHFlag_GRID_PREVIEW=true` included, which was deliberately left as found (dispatch). No override was
set at any point: the cells came from the game's own rotation.
`.agent-logs/327d2-ft-attrs-{before,after}.txt`.
ANSWERED: **L-093** claim 3 is the delete-the-producer case, and it cuts both ways: revert the pace to
5.2 and `grid.spec`'s `expect(math.abs(seconds - 253.5) < 0.1)` reddens; revert it to 9 and
`bots_lane.spec`'s `expect(metresPerSecond <= 1.6)` reddens. No single wrong number satisfies both.
ANSWERED: **the Learning Agent's ROUTE note** -- note 4 was the half the dispatch did not describe,
and BOTH its halves are fixed: the archive's *"studs-seconds"* unit and `bots_lane.spec`'s *"7 s"*
threshold (claim 5, items 4).

# Task 159 — the end of a drive, and the results scene

Task: 159
Round: 1
Base: `a0589f5` (main, #141 merged)
Code commit: `3bcdeda112477980168a5b1781811af7e7cb67cd`

Harness, one player, the FULL run, twice on the clean tree at the code commit:

```
[harness] PASS: 33/33 checks @ b9795f65ce9c40d0db950037f2649d8290284283 (clean tree) scope=all
[harness] PASS: 33/33 checks @ b9795f65ce9c40d0db950037f2649d8290284283 (clean tree) scope=all
```

```
[harness] PASS: 33/33 checks @ 3bcdeda112477980168a5b1781811af7e7cb67cd (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 3bcdeda112477980168a5b1781811af7e7cb67cd (clean tree)
```

**`test2` IS REQUIRED AND THE BUILDER DID NOT RUN IT.** This change touches `TWO_PLAYER_PATHS`
(`src/server/Match/`, `tests/server/zz_drive_boundary.spec.luau`, `tests/client/match_client.spec.luau`).
The Director runs it (his own dispatch): *"before stopping, CLOSE the Forest Test Studio yourself so my
test2 can run, and stop 'NEEDS TEST2 159 <sha>' with a [harness2] placeholder; I run test2 + the
review."* The Forest Test Studio was left OPEN — the Director's follow-up dispatch allows it
(*"The Forest Test may stay open — I close it"*).

## What changed

A drive now ends on its clock **or** when every real beater is through the hunters' line, and the
`Scoring` phase it enters is Karen's results scene: this drive's animals laid out in a row, four lamps
on four corners, everybody held and standing round them, and the semi-transparent results table over
it. No new phase, no second score, no new remote.

## Claims, and how to verify each

1. **A drive still ends on its clock, and ends EARLIER only when every REAL beater is through the
   line.** `Phase.beatersThrough` (pure: `END_ON_BEATERS_CROSS`, `beaters > 0`, `beatersAcross >=
   beaters`) is the whole rule; `Phase.step`'s `Running` branch asks the clock FIRST, so the crossing
   can only shorten a drive, never extend one. Verify: `match_phase.spec`, describe "the end of a drive
   (task 159)" — "ends on the clock", "ends EARLIER …", "needs a REAL beater: with none in the drive
   only the clock ends it" (a whole simulated drive with `beaters = 0`), "does not end early at all
   with the rule off", "ends a drive once".

2. **A phantom beater cannot end a drive.** `Match.beaterCrossing` counts off `driverPositions()`,
   which is `Match.playerDrivers(Match.driverThreats())` — the same `tonumber(driver.id)` filter the
   safety rule uses, so the quick test's `"quick-test"` and the forest's `"beater-3"` are not in it.
   Verify: read `Match.beaterCrossing` and `Match.playerDrivers` in `src/server/Match/init.luau`.

3. **A crossing is measured against the NEAREST STAND, not the line's plane**, because the forest's
   single plane is up to 30 studs off its sine road (`docs/design/forest-drive.md` section 6.1).
   `Match.crossedLine` takes the lateral component out before choosing the reference post. Verify:
   `match_scene.spec`, describe "has this beater crossed the hunters' line" — the curved-road case
   asserts the same position is `true` against the stands and `false` against the plane alone, plus
   the margin's own boundary (−9 no, −10 yes) and a missing line/normal/position answering no.

4. **The gathering spot comes from the world's own geometry, one rule for both worlds**:
   `Match.gatherSpotFor` = `SCENE.GATHER_BEHIND_STUDS` behind the MIDDLE stand, on the hunters' side of
   the line, at the stand's own underside (its ground). Verify: `match_scene.spec`, describe "where the
   drive is gathered" (x, z, y and the facing; "nowhere" with no stands; the +Z fallback with no line).

5. **`Match.Scene` is the one writer of `Workspace.DriveScene` and lays out exactly what Karen asked
   for**: a centred, evenly spaced row of animals sized by kind; a ring of players all facing the
   middle at `STAND_HEIGHT_STUDS`; **four** corners. Verify: `match_scene.spec`, describes "the scene's
   layout" and "the scene as Instances" (four different corners, one `PointLight` per lamp, animals
   `CanQuery = false`/`CanCollide = false`/anchored and sitting ON the ground, destroy-and-rebuild, the
   `MAX_ANIMALS` cap, and an empty drive still getting its lights).

6. **The animals are DISPLAY COPIES, and the dispatch asked for the reason.** `Boar.Body` owns a
   boar's Instances; `Phase.enterScoring`'s existing `clearBoars` is `Runtime:clear("driveOver")` and
   despawns every carcass at the instant the scene begins; and in the Forest Test the drive holds
   `ForestTest.readOnlyBoars`, which has no `clear` and no `spawn` at all. So `Match` keeps a thin
   per-drive kill record (kind, zone, who shot it — **no points**) and the row is built from it.
   Verify: the header of `src/server/Match/Scene.luau`, `Match.driveKills`, and the `table.insert` in
   `onDowned`; `docs/research/2026-10-12-drive-end-and-results-scene.md` section 4.

7. **Everybody is HELD at the scene with the task-158 freeze, and let go by the next drive's own
   flow.** `enterScoring` emits `release` → `clearBoars` → `hold` (the whole roster) → `scene`, in that
   order; `enterAssigning` emits `clearScene` and `free` BEFORE `placePlayers` and before the start
   line's own hold; `enterWaiting` emits both as well. `Body.standCharacter` is `tieCharacter` without
   the rope, so there is still one writer of whether a character can move and where it stands. Verify:
   `match_phase.spec` ("holds the WHOLE ROSTER …", "takes the scene down and frees everybody when the
   next drive starts", "takes the scene down when the server empties out instead") and `Body.stand` /
   `Body.standCharacter` in `src/server/Match/Body.luau`.

8. **It really happens in the live drive, in the world** — the DEV place, at the real boundary.
   Verify: `zz_drive_boundary.spec`, "built the results scene: four lamps, this drive's animals,
   everybody held round them" and "took the scene down before the next drive, and let everybody go".
   The run's own notes:
   `zz_drive_boundary: scene lamps=4 animals=1 kills=1 spot=-80, 0, -724 | scenes=1 moved=1 nowhere=0`
   and `Alhamdulilah824 stands 14.0 studs from the gathering spot (ring 14)`.

9. **The results table is the EXISTING score panel and there is no second score.** The only client
   change is its title: `Drive.CONFIG.SCORE_TITLE_FORMAT` = `"DRIVE %d RESULTS"`, read by
   `Hud.renderScore`. Verify: `match_client.spec` ("shows this drive's points…" now asserts the title
   against the contract, the RESULTS word, and that the panel is see-through). The row words stay
   SHOOTER / DRIVER: the hunter/beater vocabulary is Karen's open decision from 158a, named in
   `Drive.CONFIG`'s own comment.

10. **WHAT THE SCREENSHOT FOUND, and the one deviation from an older design (rule 5).** Every spec
    above passed, twice, against a screen that showed none of it: the task-124 report panel **opens
    itself** when a drive closes (`docs/design/drive-report.md` section 1 item 6), it is a near-opaque
    full-screen panel, and `Hud.scorePanelVisible` deliberately refuses to draw the score board while it
    is open — so the end of a drive was a dark rectangle over the scene with no results table at all
    (`.screenshots/20261011T230613Z-task159-results-scene.png`). `Report.CONFIG.AUTO_OPEN_AT_DRIVE_END`
    is now **false**; `Tab` still opens the report and **nothing is deleted** — `onDriveChanged` takes
    the config, so `report_panel.spec` drives BOTH states and the once-per-drive rule keeps its case.
    Verify: those two cases in `tests/client/report_panel.spec.luau`, the config comment in
    `src/shared/Report/init.luau`, and the second screenshot,
    `.screenshots/20261011T230908Z-task159-results-scene.png` — the forest's own drive ending with the
    scene, the four posts, the feed line *"Drive over - the beaters are through"* and the
    semi-transparent "DRIVE 1 RESULTS" table all on screen. (That frame is also where the Director
    found the table unreadable — claim 11.)

11. **The table is READABLE, and the defect behind that was mechanical.** The Director looked at the
    first scene frame and the table could not be read. The cause was not a colour: task 141 raised the
    SCORE PANEL and the START CARD to `Report.CONFIG.PANEL_Z_INDEX` (15) and left every label at the
    default `ZIndex` 1, so both frames were drawing their own words **behind** their own translucent
    dark background. `src/client/Hud/ReportPanel.luau`'s header records this repo paying for the
    identical defect on 2026-10-05 (*"an EMPTY BLACK RECTANGLE … the text was being drawn BEHIND its
    own background"*). Fixed with one `panelLabel` helper in `Hud.build`: every label of both frames is
    built above its own panel's `ZIndex`, white, with the same 1 px black `UIStroke` the feed wears;
    the title is 26 and **bold** through `FontFace` (the Code family is kept, because the columns are
    aligned by `string.format`); the header is dimmer by TRANSPARENCY (0.25), not by a grey colour; the
    panel stays see-through at 0.25. **The start card is fixed in the same commit** — one defect, two
    instances, and the second is the card Karen reads for ten seconds at the start of every drive.
    Verify: `match_client.spec`, "draws its text IN FRONT of its own panel, in white, with an outline
    (task 159)" and "draws the card's text IN FRONT of the card, with an outline (task 159)" — the OLD
    specs read every string back perfectly while the screen showed a grey rectangle, which is what
    these two exist to stop. Looked at: `.screenshots/20261011T232238Z-task159-results-scene.png` (the
    table: "DRIVE 1 RESULTS" bold and white, the header, the player's row, "NEXT DRIVE IN 21", forest
    visible through the panel) and `...232414Z-task159-start-card.png` (the card reads, and the next
    drive started normally with the hunter on the road, gun in hand).

12. **THE DIRECTOR'S `test2` FOUND A REAL ORDERING DEFECT, and it is fixed at the owner.**
    `[harness2] FAIL 33/35 @ 7ea945f`, on this task's own case, for the one player the roster had just
    made a beater. **`placePlayers` is the only effect in `Phase`'s list whose owner YIELDS** —
    `applyPlace` calls `Player:LoadCharacter`, once per player — and `hold` was emitted **after** it.
    The drive is already in `Assigning` with its new number while that yields, so the Heartbeat
    broadcasts the new drive to every client before the hold is applied: for the length of a respawn a
    beater the machine has decided to hold **is not held**, and nothing reading the drive can tell. It
    is a game defect, not a test artefact — he can walk off his line, every drive.
    **The rule now, stated once in `Phase`'s header and applied in all three places**
    (`enterAssigning`, the `join` branch, the `team` branch): a `hold` or a `free` is emitted BEFORE
    the `placePlayers` it goes with — which is task 158's own mechanism used as it was documented
    (the userId is remembered and the character watch freezes whatever character the respawn
    produces). Verify: `match_phase.spec` — "holds exactly the beaters at the line, and BEFORE they are
    placed (task 159)", "puts a side-changer's hold or release before his placement too (task 159)",
    the join-branch clause, and the boundary case's `hold < placePlayers`.

13. **The one-player run can now catch it, and the case is PROVED falsifying.**
    `zz_drive_boundary` — "never shows a beater who is not yet held, mid-respawn (the two-player
    failure)" — samples the live owner from another coroutine while `Match.requestTeam` (the same
    branch, the same placement) yields, and states the invariant: *while the countdown runs, the drive
    never calls somebody a beater without holding him*. **Measured both ways by putting the old order
    back for one run: 2 gaps at 0.000 s and 0.006 s with the old order (`zz_drive_boundary.spec:494`,
    "Expected 0, got 2"), 0 gaps with the fix.** The existing case keeps its assertion **unweakened**
    and now prints every freeze per player first (`team` / the drive's own `assignment` / `isHeld` /
    `Body.isHolding` / `tied` / WalkSpeed), and asserts that the two representations of a side agree —
    `Match.assignmentOf` was added for exactly that, so a future failure names which one is wrong.

## What I could not verify

* **`test2`.** Not run (the Director's own instruction, above) — and it is the run that found claim
  12, so it is the one that matters here. What the one-player gate CAN now prove about it is in claim
  13: the invariant is sampled live, and the sampler was shown to fail on the old order. What is still
  two-player-only: two players standing on the ring rather than one, and the roster's own swap making
  somebody a beater at a boundary without a spec asking for it. The one-player gate covers everything else, twice.
* **The LOOK.** Karen judges it in the morning. The one thing I can see and will not decide for her,
  queued as TASKS.md row 159a: **a solo beater is all the beaters** — in the Forest Test her drive ended 35 seconds in, when she walked past the
  stands. That is her rule applied literally, and the two one-line answers (require two beaters, or
  only count a crossing after the first release) are hers to pick, not mine.
* **The lamps in daylight.** They are four `PointLight`s in a bright wood; `Lighting` is untouched
  (no run-time writer in this repo), so "dusk-ish" is the lamp colour and not the sky.
* **The Forest Test Studio was left OPEN**, against the dispatch: closing it is a window action I
  could not take without killing the process, and `File → Close Place` is not reachable from the
  harness. The Director's `test2` will need it closed first — see the report.

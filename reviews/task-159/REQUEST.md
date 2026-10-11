# Task 159 — the end of a drive, and the results scene

Task: 159
Round: 1
Base: `a0589f5` (main, #141 merged)
Code commit: `3f4858c2d529f47583300b497dd17e7198d6219f`

Harness, one player, the FULL run, twice on the clean tree at the code commit:

```
[harness] PASS: 33/33 checks @ 3f4858c2d529f47583300b497dd17e7198d6219f (clean tree) scope=all
[harness] PASS: 33/33 checks @ 3f4858c2d529f47583300b497dd17e7198d6219f (clean tree) scope=all
```

```
[harness2] NEEDS TEST2 159 3f4858c2d529f47583300b497dd17e7198d6219f
```

**`test2` IS REQUIRED AND THE BUILDER DID NOT RUN IT.** This change touches `TWO_PLAYER_PATHS`
(`src/server/Match/`, `tests/server/zz_drive_boundary.spec.luau`, `tests/client/match_client.spec.luau`).
The Director runs it (his own dispatch): *"before stopping, CLOSE the Forest Test Studio yourself so my
test2 can run, and stop 'NEEDS TEST2 159 <sha>' with a [harness2] placeholder; I run test2 + the
review."* The Forest Test Studio was left OPEN — see claim 10.

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
    semi-transparent "DRIVE 1 RESULTS" table all on screen.

## What I could not verify

* **`test2`.** Not run (the Director's own instruction, above). The two-player claims this change
  touches are: two players standing on the ring rather than one, and the scene's hold over both
  rosters. The one-player gate covers everything else, twice.
* **The LOOK.** Karen judges it in the morning. Two things I can see in the screenshot and will not
  decide for her, both queued as TASKS.md row 159a: the results table reads faint over bright grass
  (the panel is the 1.7b one at transparency 0.25, and its rows have no stroke), and **a solo beater is
  all the beaters** — in the Forest Test her drive ended 35 seconds in, when she walked past the
  stands. That is her rule applied literally, and the two one-line answers (require two beaters, or
  only count a crossing after the first release) are hers to pick, not mine.
* **The lamps in daylight.** They are four `PointLight`s in a bright wood; `Lighting` is untouched
  (no run-time writer in this repo), so "dusk-ish" is the lamp colour and not the sky.
* **The Forest Test Studio was left OPEN**, against the dispatch: closing it is a window action I
  could not take without killing the process, and `File → Close Place` is not reachable from the
  harness. The Director's `test2` will need it closed first — see the report.

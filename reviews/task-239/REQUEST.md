# Task 239 — red deer in the Forest Test's drives

Task: 239
Round: 1
Base: `6116f3e7` (merge of PR #218, task 236)
Code commit: `7c1d5aff5f3590611309b505ddd132eb8166deef`

```
[harness] PASS: 34/34 checks @ 7c1d5aff5f3590611309b505ddd132eb8166deef (clean tree) scope=all
```

`[harness2]` is **N/A**: not one changed path is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The
change is `src/server/Boar/`, `src/server/ForestTest/` and their two specs — the animal and the
playtest world, the explicit one-player list (Director, 2026-10-03). `src/server/Match/` is NOT
touched; claim 8 says why that was a decision and not an oversight.

## What changed

Karen, 2026-10-21: *"we need all a time in drive deer"* and *"I want to see a deer"*. Task 234 gave
the DEV drive that guarantee and proved it there. **The place she plays never got it**, and this
task is that.

Five files: `src/server/Boar/init.luau`, `src/server/ForestTest/init.luau`,
`src/server/ForestTest/Line.luau`, `tests/server/deer.spec.luau`,
`tests/server/forest_line.spec.luau`. No new design document and no new research note — no new
system: every rule about the deer is the one task 223 and task 234 already wrote, read from a second
caller.

## Claims

**1. The defect was reproduced on Karen's own path, in her own place, before a line was changed.**
240 s of the Forest Test (placeId 130094961655666) on `main` `6116f3e7`, one enrolled hunter, a
server probe reading the `Kind` attribute of every BasePart under `Workspace.Boars` every 12 s and
unioning by instance name: **13 line waves, 80 distinct animals — cub 50, female 13, male 17, deer
0.** That is the Director's 2026-10-22 measurement, independently reproduced.
*Verify:* `<runs-dir>/239-before.json` (the union and the tally) and `<runs-dir>/239-watch.py`
(the probe that produced it). The console file `<runs-dir>/239-before-console.txt` holds the 13
`[ForestTest] line N:` lines of that run.

**2. The cause is NOT the one the dispatch named, and the two calls it cites are not on a hunter's
path at all.** `ForestTest.LINE.enabled` is `true` (`src/shared/ForestTest/init.luau`), so
`ForestTest.step` takes its line branch and every wave of this world is released by
`ForestTest.releaseLine`: the animals are placed **one at a time** with `Runtime:spawn` and their
kinds come from `Boar.sounderKinds(count, rolls, boar, nil)`, which draws from `SOUNDER.MAKEUP` and
holds no deer at any roll; `Runtime:formSounder` makes the file a sounder afterwards.
`Runtime:spawnSounder` — where task 223's deer door lives — **is not called on this path at all**,
so that door's `composition == nil` test never comes into it. The dispatch's first call is in
`ForestTest.release` (the non-LINE wave path) and its second is in `ForestTest.stockWood` (beater
mode). Neither was changed, and neither is reached by the drive a hunter plays.
*Verify:* read `ForestTest.step`'s `if Data.LINE ~= nil and Data.LINE.enabled == true then` branch —
it `return`s before `ForestTest.release` is reached — and `ForestTest.LINE.enabled` in
`src/shared/ForestTest/init.luau`. Then grep either run's console: every wave logs `line N:`, the
format string in `releaseLine`; not one logs `wave N:`, the format string in `release`.

**3. The cap is published rather than copied: one question, one answer, two callers.**
`Runtime:deerAllowed` (new, `src/server/Boar/init.luau`) is exactly
`Boar.deerGroupsAllowed(self:_liveKinds(), self._config)` — the line `Runtime:spawnSounder`'s own
deer door had inline — and `spawnSounder` now calls the method instead. The Forest Test asks the
same method, so `MAX_GROUPS_ALIVE` has one implementation and the forest counts no deer itself.
*Verify:* `grep -n "deerGroupsAllowed" src/` finds the definition, the method, and nothing else in
`src/`. `tests/server/deer.spec.luau`, *"answers the live cap through one door, for a caller that
never spawns a sounder"*: a real runtime, two boars (allowed), one hind (refused), and the pure rule
asserted to agree over the same three animals.

**4. Who the deer are, and whether there are any, is still only `Boar.deerComposition`'s answer.**
`releaseLine` asks it with the two rolls and a `wanted` flag and hands whatever comes back to
`Boar.sounderKinds`, which already turns a composition into kinds. `CHANCE_PER_RELEASE`, the
weighted `COMPOSITIONS` draw and the `KINDS.ENABLED` gate are untouched and unread by this file —
it never writes the word `stag`.
*Verify:* `grep -nE "stag|hind|calf|reddeer" src/server/ForestTest/` returns only comments. The two
calls are `Boar.deerComposition(...)` and `Boar.sounderKinds(count, rolls, boar, composition)` in
`releaseLine`.

**5. The guarantee is the drive's, it is drawn rather than fixed, and it cannot be missed.**
`ForestTest.wavesPerDrive` is `DRIVE.seconds / SCHEDULE.intervalSeconds` = 15;
`ForestTest.deerWaveOf` draws the ordinal uniformly from the **first third** of those (1..5), so a
300-second drive always reaches it; `ForestTest.deerWanted` is `>=` and not `==`, so a wave that
could not carry the group hands it to the next one; `state.deerDone` latches only after a group is
actually on the ground, and `ForestTest.newDrive` — which the boot already calls on the `Assigning`
edge — hands all three back.
*Verify:* the four new cases in `tests/server/forest_line.spec.luau` under *"the drive's red deer
(task 239)"*. The guarantee case walks 50 drives with `deerComposition`'s chance roll pinned at
`1.0` — **the value that draws nothing** — and asserts a group every time, at the drawn ordinal,
inside the window. To see it fail: change `deerWanted`'s `>=` to `==` and the latch stops being
recoverable; change `deerWaveOf`'s `/ 3` to `/ 1` and the ordinal can land past the drive.

**6. The file marches by the animal owner's rank, and the boars do not move.** `Line.order` carried
its own `{ female = 1, cub = 2, male = 3 }` — the boar half of `Boar.MARCH_RANK` written twice — so
all three deer fell through to the unknown rank of 2 and a harem (`{ stag = 1, hind = 2 }`, dealt
stag-first by `KINDS.ORDER`) would have put the **stag at the head of his hinds**. `Boar.MARCH_RANK`
is now published frozen and `releaseLine` passes it; `Line.order`'s parameter is optional so the
pure spec keeps driving it with no `Boar`.
*Verify:* `tests/server/forest_line.spec.luau`, *"marches a deer file by the animal owner's rank,
not by spawn order"* — it asserts the default's stag-first answer, the owner's hind-first answer,
and that the three boar kinds order **identically** under both, which is what makes this a
de-duplication and not a retune.

**7. A deer group is one file, never two.** `releaseLine` draws `lines` 1-or-2 at
`LINE.twoLineChance`; a deer release forces `lines = 1`, because
`SPECIES.reddeer.RELEASE.FORMATION` is `"column"` and two parallel files of a two-animal group is
not a column.
*Verify:* the `if composition ~= nil then ... lines = 1` block in `releaseLine`, and every
`RED DEER` console line of both after-runs reads `in 1 of 1 line(s)`.

**8. `Match.Phase.deerRelease` is deliberately not shared, and `src/server/Match/` is untouched.**
Its three clauses are entirely over a RELEASE BUDGET — `BOARS_PER_DRIVE`, `expectedReleases` from
the sounder size, and *"this is the last release because `boarsReleased + size >= BOARS_PER_DRIVE`"*
— and this world has none: its drive is a 20-second metronome that runs until the clock ends the
drive, and `Match` releases **nothing** in the forest. Sharing that rule would mean inventing values
to feed it. The deer rules that ARE transferable all live in `Boar` and all three are reused
(claims 3, 4, 6).
*Verify:* `tests/server/match_phase.spec.luau`'s forest case —
`expect(countKind(collected, "spawnSounder")).to.equal(0)` and its note *"match_phase forest: … 0
spawnSounder"*. And `git show --stat 7c1d5aff`: no file under `src/server/Match/`.

**9. It works in the place she plays, measured the same way as the before.** 330 s, one enrolled
hunter, same probe: **102 distinct animals, 5 deer in 2 groups** — a guaranteed `hind+calf` on wave
1 and a chance `stag+hind+hind` on wave 10 — and **0 console lines matching `Stack Begin`,
`attempt to` or `invalid argument`**. The console now names which is which:
`[ForestTest] line 2: 2 of 2 animal(s) in 1 of 1 line(s) at a trot, crossing +95 studs from the
stand -- RED DEER (hind+calf), the drive's own, due on wave 1, on this drive's wave 1`.
*Verify:* `<runs-dir>/239-after.json`, `<runs-dir>/239-after-console.txt`.

**10. Looked at, from where a hunter stands (rule 5, rule F).** Three frames,
`<runs-dir>/239-deer-eyes1.png`, `2`, `3`, taken in Play with the client camera pinned at **5.0
studs above the deer's own body centre** — a standing player's eye height on that ground — **23
studs** from the group. Frame 2 shows the hind and her calf crossing the road nose-to-tail with a
boar beside them for scale; frame 3 shows both standing on the grass, feet down, nothing floating or
sunk; frame 1 caught the `ASSIGNING` card and is reported as such rather than counted.
*Verify:* the three files, and the printed line of `<runs-dir>/239-frame3.py`, which carries the
camera height above the deer for every frame it takes.

## What could not be verified, and one thing to know

- **`ForestTest.release` and `ForestTest.stockWood` still cannot make a deer.** They are the
  non-LINE path and beater mode; a hunter's drive reaches neither, so they were left alone rather
  than changed blind (rule 4). If `LINE.enabled` is ever turned back off, that world has this defect
  again. Queued, not smuggled in.
- **One run is one run.** The paper expectation for this world is ~3.8 deer groups a drive (15 waves
  × 0.2 plus the guaranteed one); the measured answer was 2, because `MAX_GROUPS_ALIVE = 1` refuses
  every roll made while a group is still on its feet. Both numbers are reported; neither is a
  distribution. **`ESCALATE.md` carries task 234's own unanswered question about that density
  forward verbatim** (L-095) rather than this task re-baking the dial silently.
- **Nothing was changed in the Forest Test place.** Its `ServerStorage` attributes were read before
  the first run and again after the last and are identical, character for character.
- **No two-player run.** `test2` is N/A by `TWO_PLAYER_PATHS`; a deer answers the same question with
  one player as with two.

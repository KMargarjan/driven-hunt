PASS (item 2, 3 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: what WAS seen in Karen's place
(placeId 130094961655666) is item 1 -- the staged release itself, 14 times, in `releaseLine`'s own
console format with `SLOT 0` and `STAGED by DHTestRelease`, a string only the new code can produce
-- and four carcass readings taken there. What was NOT seen is the thing both core items are about:
no deer killed while running ON the road (the one carcass on the road read `v 0.00` at the trigger,
and the one shot at `v 32.05` died 186 studs north of it), no frame showing any carcass at all
(`268-t3-t3.9.2.png` is described and shows the hit card, not the body), and item 2 was never run
under its own condition -- `HIT_CLAIM` off, no shot named `chest`. Item 2 is NOT MET and item 3 is
MET per carcass and NOT MET on its count; the request says so itself (claim 9) and does not dress it
up, which is why this is a pass and not a finding.

Producer-deletion check (duty (a)), case by case: all seven spec cases call `Data.stagedRow`, which
the diff defines -- delete it and every case errors. The live-server case (`stagedRow(false, spec)`)
fails if the `not isStudio` gate goes; the default case fails if the `offsetX`/`crossOffset`/`pace`
fallbacks go; the NaN spec reaches the `north ~= north` guard, because Luau's `tonumber` is `strtod`
and returns NaN for `"nan"` (Lua 5.3's 'n' rejection is not in Luau), so without that guard the row
would pass both bounds; `boar6@200` reads `Boar.CONFIG.SOUNDER.COMPOSITIONS[6]` off the owner's own
table (6 rows, so it exists); the party case reads `SPECIES.reddeer.RELEASE.COMPOSITIONS` names
(stag/hinds/harem) in both directions. Item 1's live proof cannot survive the deletion either: `slot`
is `state.driveWave or 1` on every other path, so `SLOT 0` has one producer. Item 3's producers
(`Body.shouldAnchorCarcass`/`stepCarcass`) are untouched and the probe waits on `Anchored` becoming
true, which never happens without them.

Harness: `[harness] PASS: 34/34 @ 77908afc... (clean tree) scope=all` names the request's
`Code commit:`, and `paperwork-after-code-commit.txt` says only `reviews/task-268/REQUEST.md`
followed it. selene 0/0, stylua clean, rojo build exit 0. `test2` N/A is TRUE: `TWO_PLAYER_PATHS`
in `tools/agents.py` holds `src/shared/Drive/` and the match paths, none of the four changed files.

## Notes (non-blocking)

- `ForestTest.stagedRow` / `releaseLine` boar branch — `boar<N>` has a lower bound and no upper one.
  `"boar7@250"` parses (`composition = 7`), then `composition = boar.SOUNDER.COMPOSITIONS[7]` is nil,
  `count = if composition ~= nil then ... else 1`, and `Boar.sounderKinds(1, rolls, boar, nil)` deals
  one drawn sow -- so the instrument gets a success line for a group it did not ask for. That is the
  one place the module breaks its own written rule, *"A number outside the band is REFUSED rather
  than clamped: an instrument that silently moved the release would make its own measurement a
  guess"*. The spec's boar case checks `COMPOSITIONS[row.composition]` for index 6 only, so nothing
  covers it. Fix: refuse an index with no row (carry the count in the limits table, or refuse in
  `releaseLine` the way the unknown-party branch already does).
- `ForestTest.step`, beater mode — `return ForestTest.stepRest(now, spooked) or flush` drops the
  staged line whenever `stepRest` answers, while the release has already happened. The new comment's
  *"including beater mode below"* is true of the release and false of its console line, which is the
  only proof the release has.
- CLAIM 5 — *"Everything after the row ... is byte-for-byte what a slot gets"* is contradicted by the
  change itself two lines above it: `if capOk or staged ~= nil` and
  `if row.species == "reddeer" and staged == nil` are both after the row. The cap bypass is disclosed
  honestly in "WHAT COULD NOT BE VERIFIED" and argued in the code; it is the sentence that overstates.
- `releaseLine` — a staged deer group counts toward `Boar.deerGroupsAllowed` (it counts live deer, so
  there is no counter to corrupt), which means a staged release can make the drive's own slot 2 or 8
  be refused and set `state.owedRow`. The instrument can therefore change what the drive does while a
  measurement is running. Worth a line in the ledger next session.
- `state.released += placed` counts staged animals into `stats().released`. The module's own comment
  calls `released` the SESSION's counter, so claim 5 ("the drive's counters") is literally true, but
  a reader of `stats()` after a staged session is reading staged animals too.
- PLAN item 1(c) asks for *"crossing the road in front of the stand (`crossOffset = 0`)"*; the shipped
  `STAGED.crossOffset` is 60 and the spec asserts `row.crossOffset > 0`. The reason is written in
  `STAGED`'s own comment (lateral speed is what a lead has to take out) and 0 is reachable by
  parameter -- it is the plan text that is now stale.
- `ForestTest.STAGED` comment — *"600 is just inside the beaters' own start (`beaterNorthStuds` 580)"*:
  600 is 20 studs north of 580, i.e. behind them. No behaviour follows from it, because
  `Data.releaseDepth` pulls a clamped row to `lineNorth - leadStuds` (130) anyway.
- No spec case drives `ForestTest.stagedLine`, `setStagedReader` or any of the four `staged ~= nil`
  branches in `releaseLine`; claim 5 is explicitly a reading claim and the live console line is the
  only evidence. Also `stagedRow`'s third parameter (`staged`, the limits table) is passed by no
  caller and no case. Queue a case that injects a reader and a stub runtime.
- With `BOAR_MODEL` off, `Boar.deerComposition` returns nil before it ever looks at the party, so a
  staged deer spec in such a world prints *"the animal owner has no deer party named"* -- a refusal
  that names the wrong cause. Karen's place has the flag on, so it did not bite.
- `state.lines` ids: a staged release is built with the current `state.waveIndex` (the metronome
  increments it after `stagedLine` runs), so a staged line can carry the same `line-<n>-<which>` id as
  the previous slot's. Inert today -- `line.id` is written and read nowhere.
- "WHAT CHANGED" says *"`src/`, four files"*; three are in `src/` and the fourth is the spec. Claim 3
  says the readers are called "in its own order" -- `releaseLine` calls `wavePoint` before
  `clampedToLine`/`routeFloor`, the case calls it after.

---
REVIEWER verdict on commit `093610fae080f56dbbc905a0fe14af24c39f8264` (round 1) · 2026-10-26 02:09 UTC · session cost $3.22, 38 turns · written by tools/agents.py

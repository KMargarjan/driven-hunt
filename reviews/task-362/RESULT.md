PASS (item 9 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: what Karen judges here is her
screen at the start of a drive, and NO AFTER FRAME OF IT EXISTS. What was seen in her place is the
probe's counts (claim 6: four boundaries carrying 1-3 bodies, 0 standing at +1/+5/+12 s, fourteen
further boundaries at 0) and the owner's own console line `[ForestTest] drive 3: 1 body(ies) of the
previous drive removed`. What was NOT seen is a picture: claim 9 says both AFTER captures
(`362-AFTER-spot.png`, `362-AFTER-spot2.png`) came back as sky and fog because the spots were in an
unloaded cell, so the only opened frame of the defect is Karen's own BEFORE. The verified reading
that supports the claim: `Phase.enterScoring` and `enterAssigning` are the two `clearBoars` emitters
(`Match/Phase.luau`, lines 884 and 783), `Match.step` fires `phaseSignal:Fire` AFTER `applyEffects`,
and `Match/Scene.luau`'s header is explicit that the results scene is built from display copies and
not from the carcasses -- so clearing at `Scoring` cannot empty the *Strecke*. `Runtime:clearCarcasses`
is `liveCount`'s predicate inverted exactly (`entry.dead or state == "DOWN" or state == "GONE"`),
goes through `_despawn` with reason `"driveOver"`, and `Match`'s `onDespawned` acts only on
`"escaped"`, so no score, escape penalty or report moves. `ForestTest.readOnlyBoars` is byte-identical,
`TWO_PLAYER_PATHS` in `tools/agents.py` contains none of the seven changed paths (so `test2` N/A is
right, not lucky), the harness line names `887f3ceb` "(clean tree) scope=all", and
`paperwork-after-code-commit.txt` says OK.

## Notes (non-blocking)
- `src/server/ForestTestBoot.server.luau` / `forest_carcass_clear.spec` — the WIRING has no case. All
  five cases call `ForestTest.clearPreviousDriveCarcasses` directly, so deleting the
  `local cleared = ForestTest.clearPreviousDriveCarcasses(runtime, phase)` line leaves the whole spec
  green while Karen's bug returns verbatim. Each case does fail when its own producer goes
  (`clearCarcasses` nil -> the function returns 0 -> `:118` fails; the guard disabled -> the third
  case's loop fails), and a `.server.luau` in a place the DEV harness never boots cannot be required
  by a spec, so this is a note -- but claim 6's live table is the ONLY evidence that line runs. Queue
  a live probe case that drives the real `Match.PhaseChanged` edge.
- `ForestTest.CARCASS_CLEAR_PHASES` / the spec — `"Scoring"` and `"Assigning"` are string literals in
  the owner and again in the spec; nothing ties them to `Match.Phase`'s own phase names. Rename a
  phase in `Match` and the spec stays green while the clear goes dead. Assert against a name `Match`
  exports, or drive `Phase.step` to the edge.
- `REQUEST.md` claim 3 — "With the `_despawn` call inside `Runtime:clearCarcasses` disabled" cannot by
  itself produce `Expected value "1" (number), got "0" (number)`: `taken += 1` sits after that call and
  would still run, so the whole `if` body must have gone. The direction of the evidence is right; the
  sentence describes a smaller edit than the output implies.
- `REQUEST.md` claim 4 — no `[harness]` line at all for its dirty run (claim 3 names
  `6dc9332e...`), so the commit that FAIL-FIRST sat on is unnamed.
- `REQUEST.md` claim 6 — the table does not state the drive length. With `CARCASS_SECONDS = 120`
  (`Boar.CONFIG.WOUND`) a body killed more than two minutes before a boundary expires on its own, so
  "0" only proves the fix on a SHORT drive. Claim 8's `DHForestDriveSeconds=60` and the 18 boundaries
  in ~18 minutes make it consistent — put the 60 in claim 6 beside the counts.
- `src/server/ForestTestBoot.server.luau`, the new `print` — at the `Scoring` edge `driveNumber` is the
  drive those bodies were shot in, so the line reads "drive 3: 1 body(ies) of the **previous** drive
  removed" about drive 3's own body. Say "of drive %d" or fire the wording off the phase.
- `REQUEST.md` citations — (d) quotes `src/server/Match/init.luau:1862` for
  `if world and world.boars and world.boars.clear`, which is at 1863 in HEAD; claim 3's `:117` and
  claim 4's `:130` are line numbers of the pre-`887f3ceb` spec (the assertion is `:118` now), which
  reads as a mismatch until the log is checked.
- `docs/design/forest-drive.md` 9.4 — the table's `applyClearBoars` row still ends "**The forest's
  wood is never cleared at a drive boundary**" and the design has no row for the owner clearing its
  own bodies at a phase edge. No owner moved, so this task was right not to touch the design; queue
  the section update.
- `Runtime:clearCarcasses` — `CRIPPLED` is not in the predicate (it is live to `liveCount` too), so a
  crippled survivor of the previous drive keeps circling into the next one. Correct under "only the
  bodies go", but it is the shape of the next report if Karen reads a circling wounded animal as a
  leftover. Separately, `entry.dead` in the predicate is unreachable for a listed entry (`_despawn`
  sets it and `table.remove`s in the same breath); it is there to mirror `liveCount`, which the
  comment says.

---
REVIEWER verdict on commit `71ac31b52cb06f0b6f5d3ea6a4f58ffef17c9e94` (round 1) · 2026-11-13 15:32 UTC · session cost $3.75, 48 turns · written by tools/agents.py

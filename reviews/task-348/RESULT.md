PASS (item 6 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the thing Karen reported —
a body standing beside her on her stand during the countdown, and its ABSENCE after the fix —
was MEASURED in her place and never SEEN there. The two frames offered (claim 8) are of the MAP
PANEL (`DRIVE 5 · ASSIGNING · 0:10 LEFT`, row `2 MAIN YOURS`, diamond and YOU circle), and the
request says so itself: *"The map draws no bot markers in either, so the bot is the probe's number
and not the picture's"*. So what is proven in her place is `within10=0/141 minDist=401.6
nearMe12=0` and `within10=0/146 minDist=150.7 nearMe12=0` from a Heartbeat distance sampler over
`Workspace.DriveBots` roots — numbers, not a frame of the wood with an empty neighbouring post.
No animal-behaviour or shooting item is in this task.

What I verified in the repo (not blocking, recorded so the PASS is readable):
- `Match.botFillDuringPick` exists as claimed, returns its ARGUMENT TABLE (identity, `== want`) for
  `pickOpen` false and nil, and `{ hunters = 0, beaters = want.beaters or 0 }` for true.
  `syncBots` at `local want = Match.botFillDuringPick(bots.fillCounts(real, config, standsFree), pickOpen)`
  is its only caller (grep for `fillCounts|bots.fill(` finds no second writer of how many bots a
  drive places).
- The fix does not move the collision to the `Running` edge: `applyStandSettle` calls
  `StandPick.close()`, which only sets `open = false` — `byUser` survives until `StandPick.reset`
  at the next `enterAssigning` — so `placementLine`'s `StandPick.picksFor(ids)` still carries the
  human claims when `syncBots` runs at the end of the same dispatch (`applyEffects(effects)` then
  `syncBots()`), and the bot line is dealt the leftovers.
- No new pop-in: with `STAND_PICK` on, `Match.botsNeedRebuild` already deferred the clear-and-
  rebuild to the first `Running` tick (`if pickOpen == true then return false end`), so the rigs
  were already destroyed and rebuilt at `Running` before this change.
- Nothing outside the bots reads a bot HUNTER during `Assigning`: `ForestTest.eyes` (the "never in
  view" bed check) iterates `Players:GetPlayers()` only, and `ForestTest.realBeaters` takes bot
  DRIVERS, which this rule leaves untouched. `stats.botsWanted`/`botsFilled` have no reader in
  `tests/` or `tools/`.
- Case 15 has a bite on the rule: delete `Match.botFillDuringPick` and the first line of the case,
  `Match.botFillDuringPick({ hunters = 4, beaters = 4 }, false)`, is a call of a nil value. The
  hazard half is real arithmetic and not a transcription: with `walkOf("road")` = 1..n,
  `picks = {5}` gives bots {1,2,3,4} and `picks = {2}` gives bots {1,3,4,5}, so
  `holds(botStands(after, unguarded), 5)` is genuinely true.
- Harness line names the `Code commit:` (`66de5029955d6560ffaa62606b9be6f1198770b4`), is
  "(clean tree)", and `paperwork-after-code-commit.txt` says OK (only `reviews/task-348/REQUEST.md`
  followed it). `scope=auto:match` does include `tests/server/match_stand_pick.spec.luau`
  (`tools/studio_mcp.py`, the `"match"` tuple), so case 15 was in the 34. selene, stylua and rojo
  build clean. No secret, absolute user path or non-noreply address in the diff.

## Notes (non-blocking)
- `tests/server/match_stand_pick.spec.luau` / case 15 — the case proves the PURE rule, not the
  WIRING. Revert `syncBots` to `local want = bots.fillCounts(real, config, standsFree)` and leave
  `Match.botFillDuringPick` in the file, and every line of case 15 still passes; the only thing
  that catches that revert is the live probe (claims 5/6), which no one can re-run from the repo.
  What would fix it: one assertion that reads production across the window — e.g.
  `Match.stats().botsWanted` with the window open against the same drive with it shut — or state
  in the spec header that the call site is asserted only live, the way the header already states
  it for `placementLine` and `applyStandSettle`.
- `docs/design/stand-pick.md` §8 "Bots (D6)" — now describes only half of D6. It still says the one
  change is `botsNeedRebuild`'s `pickOpen` and that *"`Fill.standsFree(postCount, realHunters)` and
  `Fill.counts` are **unchanged**"*, with no mention that the FILL is also held to zero hunters
  while the window is open. Its own headline — *"Bots never take a stand a human could still pick"*
  — and its timeline line *"Match: StandPick.close(); bots filled (D6, §8)"* are what this change
  finally makes true, so the body of §8 is what is stale. Queue a one-paragraph §8 amendment naming
  `Match.botFillDuringPick`.
- `docs/design/bots.md` §8, the phase table — the `Assigning` row still reads
  *"`fillCounts` → `botSlotsFor` → `fill`"* with no qualifier; with `STAND_PICK` on, that row now
  places zero hunters for the whole countdown. Same queue as the note above.
- `reviews/task-348/REQUEST.md`, "What is NOT verified" — the `test2` failure can be settled from
  the repo rather than left open: `tests/server/forest_placement.spec.luau`'s `stubRuntime` returns
  `boars()` handles as `table.insert(out, { id = id })`, with no `position` field at all, while
  `ForestTest.spookNearBeaters` does `local at = handle.position()`. That path is gated on
  `#ForestTest.realBeaters() > 0`, and `realBeaters` is real beater players plus bot DRIVERS —
  neither of which this change touches (`beaters = want.beaters`). The stub and the call are both
  in the base, and this diff changes three files, none of them `ForestTest`. So it predates the
  branch; the Director can treat it as a separate task rather than as this change's.
- `Match.botFillDuringPick(want, pickOpen: boolean?)` — `want` is the only unannotated parameter
  among its neighbours (`botsNeedRebuild(phase: string, driveNumber: number, lastRebuilt: number?,
  pickOpen: boolean?)`); `Bots.Fill` already exports `Counts`. Style only.

---
REVIEWER verdict on commit `a357e0282230e1fe105db3e5862e94cdfd513a8c` (round 1) · 2026-11-11 11:54 UTC · session cost $3.36, 48 turns · written by tools/agents.py

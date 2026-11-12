# Task 354, Round 4 -- the INDEX row says what the repo measured

Task: 354
Round: 4
Base: 8cc53d35
Code commit: 41be43704a4e7373ab3d68d0e17b802994e9faf9

Round 3's single blocking finding, fixed. **One line, one file, no code.** The Director
authorised this one extra round at 22:40 UTC (`ESCALATE.md`, under the 22:35 entry) because the
finding is documentation-only; `DIRECTOR_MAX_ROUNDS=4` was set in the environment for this one
`review.ps1` call and is not committed anywhere.

Nothing else in the branch moved. `MAP_PAINTED` is still OFF, no upload was attempted, no Forest
Test session was started, and the whole of round 3's code (`PaintedMap.imageId`, `MapUi`'s numeric
`imageId` guard, `map_paint.py`'s refusals, the `report_panel.spec` repair) is byte-identical to the
commit round 3's verdict already read.

## Harness

```
[harness] PASS: 34/34 checks @ 41be43704a4e7373ab3d68d0e17b802994e9faf9 (clean tree) scope=all
```

Full run, `scope=all`, clean tree, at the code commit. 2966 server + 704 client assertions, 0 failed,
0 errors. `test2` is N/A: the change is one documentation line and touches no path in
`TWO_PLAYER_PATHS`. **No known flake fired** -- every spec the dispatch named passed.

## Claims

1. **`docs/research/INDEX.md`'s task-354 row no longer asserts the fabricated measurement.** Its last
   clause now reads *"an `ImageLabel` **cannot** draw the Decal id the Assets API returns
   (`src/shared/Report/init.luau` 2026-10-18, `src/client/Hud/ShopDisplay.luau` 2026-10-22); the image
   id is resolved on the server with `InsertService:LoadAsset(decalId).Texture`, and that is what
   `PaintedMap.imageId` carries"*. Verify: `sed -n '7p' docs/research/INDEX.md | tail -c 420`.
2. **The row now agrees with the code and the note.** The same statement is made by
   `PaintedMap.luau`'s header, `MapUi.PAINTED.NO_ASSET`'s comment, `MapUi.paintedFromGrid`'s
   `-- THE RESOLVED IMAGE ID ... a Decal id here draws nothing`, `map_paint.py`'s `read_ids` refusal
   text, and the note's "Measured, not assumed" section. Verify: grep `LoadAsset` /
   `cannot draw` in those files; nothing in the repo now claims the opposite.
3. **No other copy of the sentence survives as an assertion.**
   `grep -rn "DOES render"` over the tree (excluding `.git/` and the git-ignored `.agent-logs/`)
   finds three files, all QUOTING it as the error: `ESCALATE.md:10` (a blockquote inside my own
   22:35 entry), `reviews/task-354/RESULT.md:1` (round 3's verdict), `TASKS.md:7` (the status row
   repeating the verdict). I also grepped the looser shapes
   `(does|can) (render|draw) .*decal` and `decal id .*(renders|draws|works)`: the only other hit is
   `ESCALATE.md:95`, round 2's blockquote of the note's older wording, again as the error.
4. **The Director's authorisation is recorded in `ESCALATE.md` before the review ran.** It is the
   blockquote `Director 2026-11-12 22:40 UTC: one extra round authorised for task 354, Round 4 ...`,
   appended under the 22:35 entry and committed in the code commit `41be4370` -- i.e. before this
   request and before `review.ps1` was called. Verify: `git show 41be4370 -- ESCALATE.md`.
5. **Only paperwork follows the code commit.** `41be4370` changed `docs/research/INDEX.md` and
   `ESCALATE.md` and nothing else; after it only this `REQUEST.md`. Verify:
   `git diff --name-only 41be4370..HEAD` and `.agent-evidence/paperwork-after-code-commit.txt`.
6. **Rule G, green.** `tools/studio_mcp.py selftest`, `tools/agents.py selftest` and
   `tools/map_paint.py selftest` (40 checks) all exit 0 at this commit.
7. **Round 3's six non-blocking notes are queued, not lost**, as `354-notes2` in `TASKS.md` --
   the `{}`-ids selftest expectation, `--ids`' help text, `paintedRectPx`'s identity caveat, the
   Euclidean drawn bound, `local _ = index`, and rule 4 on the `report_panel.spec` repair.

## Not verified

- **Nobody has seen the painted map, in any place.** The nine uploads still answer
  `401 Invalid API Key` (`ESCALATE.md` NEEDS KAREN, 20:14 UTC), every `imageId` is 0, so the flag-ON
  frame remains **NOT OBTAINABLE** and `MAP_PAINTED` is left OFF. Unchanged by this round.
- No core item (animal behaviour, shooting) is touched, so no Step 3 proof is owed.

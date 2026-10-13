PASS

## Notes (non-blocking)
- `tests/server/boar_model.spec.luau` `kindTemplate` — the round-2 fix for the extra-parts hazard has no test. No template in this spec carries a `BasePart` other than the mesh, so `Body.displayCarcass`'s `offsets` table is empty in every case and the `drawn.CFrame = cloneMesh.CFrame * offset` loop is never executed. One extra `Part` parented into `kindTemplate` at a known offset, asserted after the roll, would pin it.
- `reviews/task-173/REQUEST.md` claim 7 — it cites `boar_model.spec`, "cannot be shot, shoved or stepped: it is scenery" for *"every part that is not the mesh keeps its offset to the mesh"*; that case asserts the query/collide/touch/anchored/massless flags and the absence of an `AnimationController`, and nothing about offsets. The behaviour is in the code; the citation overstates the coverage.
- `src/server/Boar/init.luau` `Runtime:displayCarcass` — on a MISS it does not merely fill the cache: `_modelTemplate` writes `self._askedModelAt[kind] = os.clock()` before returning nil, so a gathering-time miss can push the live draw path's next ask out by `MODEL.ASK_EVERY_SECONDS`. Harmless (it happens at a drive boundary, after `clearBoars`), but the `ForestTest.readOnlyBoars` comment lists only the cache fill, not the ask timestamp's effect on timing.
- `src/server/Match/Scene.luau` `Scene.stats` — `models`/`boxes` are not cleared by `Scene.clear()`, so between a teardown and the next build `stats()` reports the last scene's pair next to `animals`/`built`/`cleared`, which are session totals. `applyScene` is the only reader and it reads immediately after a build, so nothing is wrong today; `rowsBuilt` already had the same property. Worth a word in the comment for the next live probe.
- `TASKS.md` row 173 — stale gate prose: it still says *"AWAITING `test2` ... NEEDS TEST2 173 `4a93fb7`"* while the request carries a real `[harness2] PASS: 35/35 ... @ d69555a... (clean tree)` at the `Code commit:`.

---
REVIEWER verdict on commit `3ed21245e0f6b3649f791c97afd5e06be4476b4e` (round 2) · 2026-10-13 14:26 UTC · session cost $3.27, 36 turns · written by tools/agents.py

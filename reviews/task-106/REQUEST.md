# Task 106 — Karen's new gloves on model B, and the two-player run's blast radius

Task: 106
Round: 2
Base: `main` (`fb0bd00`)
Code commit: `c18f9c42083abd822f72d8215691b1314c98a56c`

```
[harness] PASS: 32/32 checks @ c18f9c42083abd822f72d8215691b1314c98a56c (clean tree)
[harness2] PASS: 34/34 checks @ c18f9c42083abd822f72d8215691b1314c98a56c (clean tree)
```

Both round-1 findings were right. Round 1's notes are queued as `TASKS.md` row 106a.

`test2` is required here because `src/client/Camera/Config.luau` and
`src/serverstorage/Assets/init.luau` are `src/` files outside `WEAPON_VIEWMODEL_PATHS` — round 1's
claim 5 gave `tools/` as the reason, which is wrong: `tools/agents.py` is not a two-player path.

## Claims

1. **Finding 1: a different gun's hands are a different KEY.** The new gloves shipped as `hand.right`
   version 2, and a version supersedes — so the flag-OFF default build was handed a pair its
   top-level poses were never measured for. Model B's are `gun.hand.right`/`gun.hand.left`; the old
   gun's keep `hand.right`/`hand.left`, un-superseded, at their own 1.27-stud dial. Verify:
   `gun.spec` "gives each gun its OWN pair", "keeps the old gun's own poses"; `assets_seam.spec`
   (seven viewmodel keys).
2. **The flag-OFF build draws exactly what `main` drew.** The v1 sizes are recomputed by the same
   `uniformTo(natural, 1.27)` that produced them; `poses.json`'s top-level block is untouched
   (`git diff origin/main -- src/shared/Viewmodel/poses.json` changes only `newGun.*`); the sleeve's
   two numbers are per gun (`Viewmodel.sleeveLength`/`sleeveOverlap`), so 1.6/0.12 still apply with
   the flag off. Verify: `gun_client.spec` "draws the OLD gun's gloves with the flag off and model
   B's with it on" — it measured 1.270 against 0.670 on the drawn parts.
3. **One place decides which pair.** Both are published under the SAME names into two folders, so
   `Camera.Viewmodel.handTemplate` is the whole of the difference and `poseHands`, `clearHands` and
   every spec still look for `HandRight`/`HandLeft`. Verify: `HandAssets`, `ViewmodelAssetsBoot`.
4. **Finding 2: the normalisation check can fail now, and was mutation-checked.** It drives a
   GAMEPLAY path (`src\server\Match\init.luau`), which is the dangerous direction — an un-normalised
   viewmodel path returns the same empty list with the feature deleted. With the `norm` line removed
   the check FAILED; restored, it passes. Verify: `python tools/agents.py selftest`.
5. **Two cases that could only ever skip were made to run.** `InsertService:LoadAsset` has not landed
   when the client specs execute — the task 99 gloves case has skipped in every harness run — so the
   flag-OFF guard stands in its own templates when a pair is absent (and destroys them), and the
   sleeve-overlap bound moved to the server where the manifest is readable. Both printed real numbers
   this run (`task106 the old gun's glove is 1.270 studs, model B's 0.670`; `task106 model B: overlap
   0.300 against half a hand 0.335`).
6. **Round 1's "one pair" note.** The spec now asserts the two models' SCALE FACTOR (0.003525 against
   0.003517), not their longest axes, which `uniformTo` equalises for any two models.

## What I could not verify

- **No new captures this round**: no `newGun` pose number changed, so the three frames round 1
  described still stand. The flag-OFF build is asserted by spec, not by a screenshot.
- The notes in 106a (c) and (d) — the longer sleeve rod across the carry frame, and a described
  capture of the shipped pose — are queued, not done.

# Task 341 — no tree hangs over the void

Task: 341
Round: 1
Base: 45c548d7 (main, PR #352)
Code commit: 4abd199584cb20779144c1e31ece15aa034e7a14

`[harness] PASS: 34/34 checks @ 4abd199584cb20779144c1e31ece15aa034e7a14 (clean tree) scope=all`

`test2` N/A: `tools/agents.py`'s `TWO_PLAYER_PATHS` names none of the changed files (no `Match/`,
no `Drive/`, no `tests/client/Role.luau`). CI green at `4abd1995`.

## What changed

After the world trim (task 340) the land outside the keep boxes is Air, and 1,862 parts of the
bought forest — `Workspace.Session` (**two** folders) and `Workspace.LobbyAssets` — stood over
nothing. `docs/design/cell-loading.md` 10.3 keeps them on purpose, so they are not deleted and not
thinned: they are **moved, at run time, to where nothing is drawn**.

- **`src/server/Places/Store.luau`** (new) — the one writer of `ServerStorage.Sources`. It moves
  every child of a source folder with **no terrain under its lowest visible part**, stamps it
  `SourceHome`, and refuses at Edit time.
- **`Places.templates`** looks for each `TEMPLATE_SOURCES` path in the world **and** in the store,
  the world's copy first.
- **`Build.clone`** takes a store as a second place to look (the lobby's truck); the composition
  root in `src/server/Lobby/init.luau` resolves the mirror. `Places.SOURCE_STORE` is spelled once,
  in the shared plan.

## Claims

1. **Floating parts in `Workspace`: 1,618 → 0, and parts outside the keep boxes 1,862 → 0.**
   Task 340's own probe, unchanged, run in Karen's Forest Test on both sides:
   `<runs-dir>/t341/341-floaters-before.txt` / `-after.txt`.
2. **Nothing was deleted and nothing was thinned.** `ServerStorage.Sources` holds **1,862 parts /
   3,864 descendants**; `Workspace` lost **exactly 1,862 parts** (24,890 → 23,028) and 3,861
   descendants — the 3 missing descendants are the three mirror folders the move created.
   `341-worldcensus-before.txt` / `-after.txt`.
3. **Nothing standing on kept ground moved.** Of the 810 stowed children, **0 have a part inside
   K1 ∪ K2** (`341-stowed-inkeep.txt`). `Workspace.OurForest` (4,819 children / 9,901 parts) and
   `Workspace.LobbyAssets.Trees` (18 parts, on terrain) are untouched — they are in the census on
   both sides, unchanged. What moved, by folder: `Session 746 child(ren)/1250 part(s)`,
   `Session 60/105`, `LobbyAssets 4/370` (`Truck`, `Lodge`, `BoarHead`, `DeerHead`) — the boot's own
   `[Places.Store]` line, `341-console-after.txt`.
4. **The plant counts did not change.** `[ForestTestBoot] prebuilt forest: STANDS, folder=true,
   20599 model(s) in 7 cell folder(s), live=58575af518ae6156 planted=58575af518ae6156` — identical
   before and after, and identical to task 337c's. `GridForest` 25,589/11,645 and
   `ServerStorage.GridWood` 125,491/56,281 are identical in the two censuses. The one-leaf sweep is
   identical too: `1172 leaf part(s) unblocked` on both sides.
5. **No template changed.** `341-templates-before.txt` / `-after.txt` resolve all **44** names
   (35 `TEMPLATE_DIMS` + the 9 `Session` names) through the real `Places.templates` +
   `pickTemplate`; **every chosen scale is identical** (`diff` of the two, pasted in the task
   report). All 35 names `Places.SPECIES` can plant come from `Workspace.OurForest`, which does not
   move — so the plan's vocabulary never touches the store. `Tree10` now resolves out of
   `ServerStorage.Sources.Session`, which is the fallback actually biting.
6. **The lobby's truck is still the free model, out of the store.**
   `[lobby] trucks: 4/4 settled on the measured ground, worst wheel +0.000 studs, 96 part(s) in
   camouflage` at the code commit, with `Workspace.LobbyAssets` holding only `Trees` by then.
   Before the change the same line reads the same.
7. **It refuses at Edit time** (lesson L-057, design 4.3): `Store.editTime()` is
   `MapGen.Contract`'s predicate, both arms reachable by parameter. Karen's Edit place is therefore
   unchanged — `341-attrs-BEFORE.txt` vs `-AFTER.txt` vs `-RESTORED.txt` is an **empty diff** (all
   16 `DHFlag_*`, `DHForestStartRole`, `DHShopTestGrant`, `DHTestOwns`), and the place file still
   holds every tree where it was.
8. **Two cases die if the fix is deleted** (L-093). `places.spec` *"finds a stowed source as a
   template, and still prefers the one still standing"* — delete the store arm of
   `Places.templates` and the stowed `Session` is no longer a source. `lobby.spec` *"clones the
   truck out of the store once it is no longer in the world"* — it builds the SAME lobby twice, with
   and without the store, and asserts the fallback difference is exactly `TRUCK.COUNT`; delete the
   store arm of `Build.clone` and every bay is a parts truck.
9. **The rule is a measurement, not a box.** A child moves when there is no terrain under it — ray
   from y 1200 down, `Include` filter holding only `Workspace.Terrain`. Claim 3 is what shows the
   terrain rule and the trim's keep boxes agree, so the second copy of the keep set is not needed.
   The ray starts above everything because a ray begun *inside* terrain returns nil: that mistake
   read 4,809 of `OurForest`'s 4,819 models as groundless (`341-census2` vs `341-census3`).
10. **`SMOKE PASS`** at the code commit in her place: gun in hand at +16 s and at 80 s,
    `stacks=0 errorLines=0`, `waves=11`, respawn ok (`smoke-console-1109-230944.txt`); boot
    `STANDS`; **0 console error lines** in both the before and the after Play.

## What I could not verify, and one refuted premise

- **THE DISPATCH'S PREMISE IS HALF REFUTED, AND IT IS MEASURED.** *"Karen sees them from a tower or
  the air"* — she does not, at today's streaming settings. `workspace.StreamingMinRadius` 384 /
  `StreamingTargetRadius` 512, and the nearest floating part is **849 studs** from the lobby spawn
  and **1,231–2,492 studs** from C1 stands 1/8/15; **0** within 600 studs of any of them
  (`341-visible-before.txt`). The frames prove it: `341-c1tower-before.png` and
  `341-lobby-before.png` contain no floating tree. The fix is still right — 1,862 parts leave the
  replicated world — but it was never visible from where she stands.
- **The before/after frames come from two different Play sessions**, so their pixel diff carries the
  sessions' own sun and grass, not the move: the lobby pair reads 5.48 % while a **same-session
  control of the same camera reads 0.06 %**. The pair that shows the defect is
  `341-floaters-before/after.png` (the camera parked over the densest cluster, 1.45 %), and both
  were opened and described in the task report.
- **341-G as the dispatch asked (top-down over the whole kept land) is NOT OBTAINABLE in Play**:
  streaming is centred on the CHARACTER, so a camera 1,500 studs up photographs blue haze
  (`341-g-before.png`, the first attempt). Task 340 took its G frame in Edit, where this task's
  change does not exist. The substitute is the floaters pair above.
- No two-player run, no drive played, no animal shot: nothing here touches them.

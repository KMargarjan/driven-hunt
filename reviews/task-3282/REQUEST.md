# Task 328g2 — the prebuilt forest PLANTED into Karen's Forest Test, for real (PART 2)

**THE FOLDER IS `reviews/task-3282/`, NOT `reviews/task-328g2/`, AND THAT IS A DEVIATION FROM THE
DISPATCH.** `tools/agents.py`'s `TASK_PATTERN` is `[0-9]{1,4}[a-z]?`, so it REFUSES `328g2`
outright, and `328a`..`328z` are all taken in `TASKS.md`, so no conformant id in that series is
free. `3282` is conformant, free, and far from the queue's head (329), so it cannot collide with
the Director's next dispatch. `ESCALATE.md`'s entry of today ~20:40 UTC records the hard stop,
the refusal verbatim, and the three ways out; renaming this folder to whatever the Director
prefers is one `git mv` plus this `Task:` line. Everything below is unchanged.

Task: 3282
Round: 1
Base: `main` @ `8f91a477`
Code commit: `8f91a47749f8286ff2cf98e61de4016969863e8e`

That sha is `main` itself, and it is named because **this task is docs-only**: nothing under `src/`,
`tests/` or `tools/` changed on this branch, so the LAST commit that changed code is the branch's
own base, and the definition in CLAUDE.md git workflow step 4 — "at or after the last commit that
changed src/, tests/ or tools/, and only paperwork after it" — is satisfied exactly by it.
`git diff --name-only 8f91a477..HEAD` is `ESCALATE.md`, `TASKS.md` and `reviews/task-3282/`, all
paperwork. **No harness line is pasted and none is required** (docs-only is exempt). Rule G ran
anyway: `tools/studio_mcp.py selftest` PASS, `tools/agents.py selftest` "all ok". **No flake fired**
— no spec ran at all, because no spec file and no code file changed.

## What happened

`Workspace.GridForest` now STANDS in Karen's Forest Test (place `130094961655666`), planted from
EDIT by `tools/terrainbake.py plant` run out of a worktree of **merged main `8f91a477`** — the
commit her `:34873` build serves. 10,839 models / 36,007 parts in 5 cell folders, stamped
`PlantEpoch=58575af518ae6156`, which is the ground's own live `TerrainEpoch`. Her place was left in
**Edit, Rojo connected on `:34873`**, and `smoke.sh` passes on it.

## Claims, and how to verify each

1. **Backup first, by hand, before any write.** File > Download a Copy to
   `<backups-dir>/FT-before-328g2.rbxl`, **28,944,173 bytes** (27.60 MiB, over 20 MB), 20:53 local,
   taken before the first plant call. Frames: `328g2-filemenu-crop.png` (the File menu),
   `328g2-dlg2-name2.png` (the typed path, zoomed 6x, reading `...\FT-before-328g2.rbxl`),
   `328g2-after-save-crop.png` (dialog gone). Only Roblox Studio windows were clicked; no Save, no
   Publish, no Drafts Commit.

2. **The plant ran against HER place, in Edit, from merged main.** `328g2-plant.txt`:
   `[bake] Studio: 0769bd76 name='Driven Hunt Forest Test' place 130094961655666`,
   `[bake] commit 8f91a47749f8286ff2cf98e61de4016969863e8e`, the eight injected sha256s, and
   `[bake] plant OK: 5 cell(s) @ 8f91a477... PlantEpoch=58575af518ae6156 10839 models / 36007 parts
   in Workspace.GridForest (clean tree)`. `git diff --stat 8c43aeac 8f91a477 -- src/ tools/` is
   EMPTY, so the code that planted is byte-identical to part 1's.

3. **THE PLANT IS DETERMINISTIC, and that is new.** Two full plants, same Studio session, minutes
   apart (`328g2-plant.txt`, `328g2-plant2.txt`): all five cells identical in models, parts AND row
   hash — C1 1942/`09b41eb8`, C2 2241/`588a28e0`, A2 2314/`522221c0`, B1 2168/`c78cba48`,
   D1 2174/`c3ff43f0`. So the wood in her place is frozen and will not re-roll.

4. **THE DISPATCH'S EXPECTED HASHES ARE NOT MET, and I report that rather than round to them.** It
   asked for part 1's prebuild numbers (C1 `f8d6b718`, C2 `ededd638`, A2 `0f1c5e60`, B1 `67a0e513`,
   D1 `a2e69fc0`). What I measured is the OTHER set part 1 also published: **exactly part 1's boot
   dress #2**, all five cells, models and hash (`328g-rows-BOOT2.txt` vs `328g2-plant.txt`). The
   split correlates with a Studio restart, not with a code change: everything part 1 read BEFORE it
   closed Studio at 20:02 (`328g-rows-BOOT.txt` 19:37; its Edit prebuild ~19:45) is the `f8d6b718`
   set, and everything read AFTER the reopen (`328g-rows-BOOT2.txt` 20:08, and both of my plants)
   is the `09b41eb8` set. Per cell the two sets differ by **+1, 0, +3, +1, +5 models** — inside the
   plus/minus 1..5 drift part 1's own claim 4 bounds. So part 1's sentence *"the boot dress is not
   reproducible run to run, and the prebuild is"* is better stated as: **both are reproducible
   within a Studio session, and both shift by at most 5 models a cell across a Studio restart.** I
   did not edit `docs/design/` (not mine); this is for the Director.

5. **The boot certifies it, live, in her place.** `328g2-console-STANDS.txt`:
   `[ForestTestBoot] prebuilt forest: STANDS, folder=true, 10839 model(s) in 5 cell folder(s),
   live=58575af518ae6156 planted=58575af518ae6156, dress=false`. **`GridPlaces` holds no cell
   folder**: `328g-rows.py GridPlaces C1 C2 A2 B1 D1` answers *"GridPlaces has no (cell) folder"*
   five times, and the fill probe reads `GridPlaces[nil]{C1=-1 C2=-1 A2=-1 B1=-1 D1=-1}`.

6. **The wood the SERVER sees is the wood that was planted.** Same instrument both sides
   (`FOREST_ROWS_SEAM`, imported by `328g-rows.py`, never retyped): `328g2-rows-PLAY.txt`, read in
   the Play server, gives the five hashes of claim 3 and `PlantEpoch=58575af518ae6156` per cell.

7. **The trees are there at the first frame, and the boot reaches the lobby 10x sooner.**
   `328g2-fill-AFTER.txt`: the EARLIEST sample the server would answer, `up=1.1 s`, already reads
   C1=1942 C2=2241 A2=2314 B1=2168 D1=2174 — all five complete (part 1's earliest was `up=3.2 s`).
   `[ForestTestBoot] places: ... 1.90s`, against 20.55 s with no prebuild and 2.01 s for part 1's
   own prebuilt run.

8. **The frame, hunter eye height, opened and described.** `328g2-F1.png`, cropped from
   `328g2-F1-early-screen.png`, taken at server `up` about **3.8 s** (`328g2-earlyframe.py` prints
   the pin at `up=1.2 s` and the shot 3.0 s after it). Camera measured on the client:
   `cam=(-3905.0,111.1,-5062.4) look=(0.000,-0.001,-1.000)`, head 110.94 over ground 106.00 — a C1
   stand, eye height, due -Z into C2, the same spot and heading as part 1's `328g-F1.png`.
   **Route (L-095):** `ftplay.py capture`'s camera argument is the known D-1 frame fault and came
   back with the lodge (`328g2-F1-raw.png` shows the shop porch); the player is pinned DIRECTLY
   instead — `PivotTo` + anchor + `DHTestLook`, **from the CLIENT**, because the server's pivot moved
   only the server's copy (server read `(-3905,110.9,-5062)` while the client still read the lodge
   `(2850,153.4,-2934)`; both are pasted in `328g2-stand-client.luau`'s header).
   **What is IN it:** a pale gravel stand pad across the bottom with tall grass blades over it; a
   green clearing strip; then an unbroken band of wood filling the full width — dark spruce/fir
   spires, lighter oak/beech crowns, several white-barked birch trunks right of centre and far
   right; two dark bushes at mid-frame; blue sky only in small gaps between the crowns. HUD: *step
   on a truck pad to hunt*, DRIVE 0 / WAITING players / 0 ANIMALS / $13500 MONEY, the compass band,
   MAP and REPORT, `TRUCK 1992 m`. One sky rule over all four frames (blue-dominant pixels below the
   top 18 %): **328g2-F1 3.48 %**, part 1's prebuilt `328g-F1` 4.23 %, part 1's boot-finished
   `328g-F1-before-done` 2.39 %, part 1's mid-fill `328g-F1-before-late` **19.05 %**. At 3.8 s it is
   already in the finished family.

9. **Persistence, re-measured for THIS plant on the live tree (L-026).** Studio was closed with
   `WM_CLOSE` — **no save prompt** (`328g2-closing-crop.png` shows the DEV window behind it) — and
   reopened from the place URL by `ft-open.sh`. The Studio id changed `0769bd76` to `2f691373`, so
   it is a different process; `terrainbake.py rows` then read all five cells back **identical**
   (models, parts, hash, `PlantEpoch`), and the attribute capture is byte-identical to the
   pre-close one (`328g2-attrs-AFTER.txt` vs `328g2-attrs-REOPEN.txt`, `diff` exit 0). Rojo was
   re-connected and a third capture after Connect is identical again (`328g2-attrs-CONNECTED.txt`)
   — `Workspace` is not a Rojo-owned container, so the reconcile cannot take it.

10. **Her place, and the re-plant runbook.** The attribute diff against the baseline taken before
    any write is **exactly two lines, both this task's own write**:
    `GridForest.PlantEpoch=58575af518ae6156`, and `GridForest-exists` false to true. Her **15 flag
    overrides are byte-identical** and were never cleared (rule K; the 13 that are not built into
    `KARENS_FLAGS` were DECLARED with `--keep-flags` and are echoed in the run log).
    `<runs-dir>/replant-forest.sh` is the one-command runbook: Edit check, backup check, worktree of
    `origin/main`, the plant, then a Play that prints the boot verdict. Its header answers the
    Director's question off the code: **BOTH cases are true** — (1) a bake moves `TerrainEpoch`, so
    `ForestTest.prebuildVerdict` returns REFUSED with `dress = false` and `ForestTestBoot` hands
    `Places.build` an empty cell list, dressing nothing; AND nothing under `src/` destroys
    `Places.FOREST_FOLDER` (`Places.build` destroys `Places.GRID_FOLDER` only), so the stale wood
    stays standing on the new ground; (2) a planting change never reaches the stamp, so
    `planted == live` gives STANDS, the same empty list, and the new trees never show. One command
    fixes both. `smoke.sh` on `:34873` afterwards: **SMOKE PASS**, gun in hand at +17 s and at 80 s,
    0 stacks, 0 error lines, 10 waves (`328g2-smoke.txt`).

## What I could not verify, and what is carried forward

- **`grid-terrain.md` 12.2's three unresolved rows are NOT re-measured here**, and the plant cannot
  move two of them: client frame **43.12 / 44.30 ms against 16.7 ms — NOT MET** (part 1 measured the
  same camera with and without the prebuild, 1.2 ms apart, inside the instrument's own spread);
  server heartbeat **NOT PROVEN** (two same-branch readings 4.7 ms apart against a 1.0 ms budget);
  live `StreamingMinRadius` **NOT OBTAINABLE** (NOT A MEMBER in both the Play server and the Edit
  plugin context, Studio 0.740.x). They are the Director's to schedule; nothing in 328g2 moves them.
- **Census (L-170), every counter named, re-read on the wood that is now in her place**
  (`328g2-census-GRIDFOREST.txt`, `GridCensus.survey` per cell in the Play server):
  floating 0, tilted 0, broken 0, noGround 0, inRoad 0, inStand 0, onCliff 0, crownOverRoad 0,
  crownUnmeasured 0 in all five; **`sunk` 101/154/123/194/200 and `foliageInGround` 45/33/41/40/176
  are NOT 0**; worstSink 4.35–4.41; `inLane(other-world)` 144/0/0/195/239;
  `inBeaterPath, inDitch, inRide, inTower, inVerge, mudPct, rockPct` print UNMEASURED by the
  census's own design. Both this reading and part 1's hand in `clawOf = 0`, not 328b's real
  per-template claw, so they are **not** comparable with 328i's reported 0 and I do not claim a
  clean census. Every counter matches part 1's to the unit except the tree and part totals, which
  follow claim 4's drift.
- **Karen has not seen this.** The frames are mine. Nothing here is a feel judgement.
- The `[ForestTestBoot] places:` line counts the lobby and arena places, not the grid cells; the
  grid's count is the arbiter line's `10839 model(s)`.

ANSWERED: L-127 — every item is MET / NOT MET / NOT PROVEN off a named file.
ANSWERED: L-014 — nothing was checked out in `driven-hunt-karen` (still detached at `8f91a477`); the
tool ran from a fresh worktree `driven-hunt-328g2`, and her FT ends Connected on `:34873`.
ANSWERED: L-086 — the frame is at the character's own eye height, measured on the client, and opened.
ANSWERED: L-101 — baseline before any write; the diff is the two lines in claim 10 and nothing else.
ANSWERED: L-026 — persistence judged by closing Studio, reopening it as a new process and probing
the LIVE tree, never by a `Source` or `require` read.
ANSWERED: L-095 — the route to the stand is written out in claim 8, with the failed route named.
ANSWERED: L-170 — the census counters are quoted by name above, with the `clawOf = 0` caveat.

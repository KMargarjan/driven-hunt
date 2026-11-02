# Task 328a — terrain v2: the research note, the BRIEF and the Architect's design run

Task: 328
Round: 1
Base: `main` (`1656ca36`)
Code commit: `a881b4fa` — **docs-only. No `src/`, `tests/` or `tools/` file is touched**, so the
harness is exempt (`CLAUDE.md`, the loop step 3; `tools/agents.py` prints *"docs-only change: no
harness line required"*). `test2` N/A: no `TWO_PLAYER_PATHS` path, and nothing in this task can be
run in Studio at all.

**What changed.** Four files, all documentation:
`docs/research/2026-11-02-terrain-v2.md` (new), `docs/research/INDEX.md` (one row),
`reviews/task-328/BRIEF.md` (new), `docs/design/grid-terrain.md` +
`reviews/task-328/ARCH_RESULT.md` (both written by `tools/architect.ps1`, committed by the Builder),
plus the `TASKS.md` rows and the `ESCALATE.md` entry.

Karen, 2026-11-02 ~08:05 UTC: *"… (we kee same trees we have do not make same as on image colours
ect) I need perfect terrai … not broken trees hanging or to inside"*, then *"we wait results then
start to implement if it make sense"*.

## Claims

1. **The research note meets rule 1.** `docs/research/2026-11-02-terrain-v2.md` covers the four
   subjects the dispatch names — the ground contact rule (§3), Edit-time sculpting with
   ReadVoxels/WriteVoxels and its limits (§4), the forest layout of real driven-hunt rides (§5), and
   prebuild versus runtime planting (§6) — with the pattern adopted and why (§7) and numeric targets
   (§8). *Verify:* read those sections.
2. **Seven external sources, each fetched today, with licence and maintenance status**, and the one
   that failed is recorded as failed. §2's table names: the Roblox `Terrain` reference and the
   streaming-techniques page (first-party, `Roblox/creator-docs`, **CC BY 4.0**, maintained), two
   DevForum threads (2018, never resolved; 2025-04-30, closed as intentional), BASC ×2 (2024-01-31;
   current 2026), Fieldsports Journal (2020-06-28, not maintained), and the Scottish Wild Deer Best
   Practice Guidance — **checked and yielded nothing**, because its woodland-design page now 301s to
   the site root. *Verify:* §2, and the last row of §9.
3. **The note refutes SWARM_DESIGN §3.5 against code that is already in the repo**, rather than on
   preference. `TreeGround.sinkFor` is `min(0.6, 0.1h)`, `CLIFF_STUDS` is 4.0 with its measurement in
   the comment (*"0.23 studs at the median and 2.10 at the ninetieth percentile"*),
   `TOLERANCE_STUDS` is 0.2, and `Places.clawFor`/`TreeGround.junctionY` already seat at the
   trunk/root junction — against the design's `clamp(0.03h, 0.5, 2.0)`, flat 3.0, 0.25 and *"trunk
   bottom = low − sink"*. *Verify:* `src/shared/TreeGround/init.luau` (those four symbols) and
   `src/server/Places/init.luau` (`clawFor`, `trunkBox`, `groundsUnder`, and the
   `max(TreeGround.CLIFF_STUDS, 0.10 * heightStuds)` line) against the note's §3 table.
4. **`TEMPLATE_DIMS` does not exist and `CLAW_FRACTION` covers 5 of 61 models**, so `clawFor` returns
   0 — and therefore the junction rule silently degrades to the lowest-point rule for 56 of them.
   *Verify:* `grep -rn TEMPLATE_DIMS src/ tools/` is empty; count the entries of
   `Places.CLAW_FRACTION` (5, all `SilverBirch_*`) and the names in `Places.SPECIES`
   (`src/shared/Places/init.luau`); read `Places.clawFor`'s `or 0`.
5. **The crown arithmetic in SWARM_DESIGN §3.1 fails §1.4's own rule, and §3.2 has no crown term at
   all.** With `crown` defined by B10 as the half-width, `22 + ½·crown·scale + 2` puts the trunk at
   `24 + 0.5·hw` and the crown's edge at `24 − 0.5·hw` from the centreline, so it clears the ±10-stud
   carriageway only while `hw ≤ 28`. Rides are 36 st trunk-free — trunks 18 st out — against a
   measured spruce height of **56–156 studs**. *Verify:* the arithmetic in note §5 and BRIEF §6.2;
   SWARM_DESIGN §1.4, §3.1, §3.2 and B10; the height range in `Places.SPECIES`' `young` comment.
6. **The BRIEF carries what the dispatch told it to carry.** §2 = SWARM_DESIGN §1–4 and B1–B11 as
   decided; §3 = §7's four open points, one numbered item each (the epoch's inputs, the 2-column
   ditch and the 34-stud minimum, the unmeasured budgets as targets, B2's bot climb); §4 = Karen's
   Q1–Q5 with their defaults, Q1 marked **UNANSWERED** and 328d blocked on it. *Verify:*
   `reviews/task-328/BRIEF.md` §2, §3, §4 against `SWARM_DESIGN.md` §2.3, §2.4, §6 and §7.
7. **The Architect ran against the committed BRIEF and returned PASS.**
   `reviews/task-328/ARCH_RESULT.md` line 1 is `PASS`; its trailer names commit `d1ca8e19`, which is
   the commit that added the BRIEF, and the run cost $9.19 over 62 turns. *Verify:* that file, and
   `git show --stat d1ca8e19`.
8. **The design settles all four open points and all three refuted numbers**, each with its reason:
   §15 (the epoch is `BAKE_VERSION` enforced by a golden file; the ditch confirmed with a **±1.0 st**
   tolerance and a 4-st fallback named now; the budgets tabled in §12.2 against the task that
   measures each; B2 at 24° with **three** ramps, because the corridors at x 460 and 610 had no ramp
   within ~225 st and `Bots.Lane`'s jitter is ±20), §9.1 (`TreeGround` is not forked), §7.2 (the
   crown term goes linear, with a frontage rule), §7.3 (the ride is 54 st). *Verify:*
   `docs/design/grid-terrain.md` §7.2, §7.3, §9.1, §15.
9. **The design found five defects in code that every later task would have inherited**, each with a
   file and a symbol: `Places.build` destroys `GridPlaces` at boot, so a prebuilt forest is gone at
   the next Play (F-1); the `4k+2` snap moves every road one stud, because all eight centres are
   ≡ 1 (mod 4) (F-2); ruts at `d ±4` merge, already measured once (F-3); a 34-stud `roadClearStuds`
   would break `laneHalfWidth`'s asserted identity, `grid.spec` case 15 (F-4); `Places.fernBands`
   runs from d 24 to 54 and so plants through the ditch and the verge (F-5). *Verify:*
   `grid-terrain.md` §14, then each cited symbol in `src/server/Places/init.luau`,
   `src/shared/Places/init.luau` and `tests/server/grid.spec.luau`.
10. **No design was written by the Builder, and no code was touched.** The Architect script wrote
    `docs/design/grid-terrain.md` and `ARCH_RESULT.md`; the Builder committed them unmodified. The
    exact text the design leaves for `grid-map.md`, `drive-places.md`, `map-generator.md` and
    `tools/forest_ground.py` (§16) was **deliberately not pasted** — `docs/design/` is the
    Architect's to write (rule 3) — and is queued in `TASKS.md` row `328a-queued` (a) and raised in
    `ESCALATE.md` as the first Director decision. *Verify:*
    `git diff --name-only 1656ca36..a881b4fa` lists only `docs/`, `reviews/`, `TASKS.md` and
    `ESCALATE.md`; `git log --format=%an d1ca8e19..bb3a8e0c -- docs/design/grid-terrain.md`.

## What could not be verified

- **Nothing in this task was run in Studio.** No harness run (docs-only, exempt), no Forest Test
  probe, no frame, no screenshot. Rule 5 is N/A: no visual change was made.
- **Every number in §5 of the note about crown half-widths is arithmetic over a plausible
  0.15–0.25-of-height ratio, not a measurement.** `TEMPLATE_DIMS` does not exist yet. That is
  precisely why the note and the BRIEF make measuring all 61 models work inside 328b, and why §8
  target 6 is marked as failing today rather than as fixed.
- **The unmeasured budgets are still unmeasured**: 8 s a tile, 6 GB, 150 MB, a 90 s save, ~70 min for
  1,053 tiles, +25–40 MB. The design's §12.2 is the list and names the task that measures each.
- **The Architect could not fetch its own links** (Read, Grep, Glob only; its §18 says so). Their
  licences and maintenance statuses in `grid-terrain.md` §11 rest on this note's fetch of
  2026-11-02, which is claim 2.
- **Q1 is unanswered**, so the design's §4 and §5 (the sculpt) are not yet authorised work.

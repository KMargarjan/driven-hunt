PASS (item 3, 9 NOT PROVEN)

## Delete the producer (RULE 3(a))
No spec, probe, counted run or frame is offered this round; nothing under `src/`, `tests/` or `tools/`
changed (`changed-files.txt` is nine `.md` paths). The proof is the note's section 4 table, one row per
number, "Derived here" against "Design section 5" as written, plus the repo values quoted beside them.
Those are two independent sources, not one identity through two names, and the table does fail -- three
rows read `NO`. Producer deleted: with `src/shared/Grid/init.luau`'s `CONFIG` gone no "Derived here"
cell answers (every row's input list is `originX -6700` / `cellWidthStuds 1070` / `cellDepthStuds 1430`
/ `roadClearStuds 42` / `mainSpacingStuds 150` / `flankSpacingStuds 220` / `flankMarginStuds 27`, all
confirmed at HEAD, with `rows = 2`, `columns = 4`); with the design's section 5 gone the "Agrees?"
column cannot be filled. I re-ran every row of section 4 and all of section 8 by hand and all reproduce.
**Two rows survive the deletion.** (i) `| cell depth along any column | the E-W roads are exact
translates | **exactly 1430** | 1430 | yes |` -- it restates `cellDepthStuds`, an input; round 1 named it
note (c) and `TASKS.md`'s 328q row item (iii) queues the exact-translate property as the assertable
thing, so it is not re-raised. (ii) `| offset at a junction | A*sin(pi*k) | **0, exactly** | 0 | yes |`
and its section 5 target `| offset at every junction | **0**, asserted to 1e-12 | grid.spec, by
construction |` -- `A*sin(pi*k)` is 0 at `A = 0`, so that assertion holds with the bend deleted and at
the born `bend = {0, 0, 1}`; it is the same assertion as the inert gate. That is a hole in 328q's gate,
not in this round's proof, and it is note 3 below.

## Rule 5, stated so this PASS is not read as rule 5 having been met
Claims 3 and 9 are **shooting** numbers: the 330-stud cross-side separation
(`Shotgun.CONFIG.RANGE_STUDS.Slug = 330`), its eaten margin (333.1/3.1 -> 332.44/2.44) and
`flankFirstStuds` 340 -> 366 with the realised worst pair 357.45 / 27.45. **Nothing in this round was
seen in Karen's place**: docs-only, no harness run, no Studio, no frame, no voxel, no bake, and no code
exists yet to run. The separation is arithmetic on paper; today's `grid.spec` case 5 still measures the
straight world (worst 356.14 at 340), which `TASKS.md`'s 328q row item (iv) owns. Karen has judged
neither the bend nor the moved flank stands -- that is 328r. One thing in the arithmetic's favour,
checked rather than assumed: the note's `bendX` term uses the linear bound `0.12805 * 340 = 43.54`
where the true maximum swing over a 340-stud window is `120*sin(170*pi/1472)` = **42.589**, so `dx` is
under-stated, the required `dz` over-stated, and 366 errs toward more separation, not less.

## Notes (non-blocking)
- `docs/research/2026-11-03-curved-grid-roads.md`, section 4 finding 1 — *"**What it changes in the
  design: only that row.**"* is not true of the repo, and it under-scopes what 328q must paste. Two
  places more carry the refuted figures. (i) Inside section 5.3 it is **two** rows, not one, as the
  note's own table marks with two `NO -- finding 1` cells: `grid-roads.md` has `| published minimum for
  this class of road (source B) | 15–30 m | 15–30 m |` immediately above `| so ours is | **26 to 52×
  looser than the real limit** | same |`. `TASKS.md`'s 328q row gets this right (*"section 5.3's
  published-minimum and ratio rows"*); the note's sentence is the loose one. (ii) Section 10 B states
  the ratio a second time -- *"our 780 m minimum radius is **26 to 52 times looser** than its limit"* --
  and asserts the class the note's own width table refutes: *"a single-lane forest road with a 3.5–4.5 m
  running surface ... Our §7.1 cross-section is this shape"*. This also makes `REQUEST.md` claim 2's
  *"no other section consumes the ratio"* inexact: no section consumes it arithmetically (section 5.2's
  amplitudes do come from the equal-swing rule `A*pi*m/P`, verified), but section 10 B restates it.
  Fix: say "section 5.3's two rows and section 10 B's prose", and add section 10 B to 328q's row.
- `TASKS.md` — none of item 1's five source corrections is queued to any task. The 328q row names
  sections 5.3, 5.4, 5.5, the section 14 delta text and the four spec items, and nothing names
  `grid-roads.md` **section 10**, so the design keeps *"**Licence:** © FAO; the document repository
  permits non-commercial reproduction with attribution"* for a document the note found to be ALL RIGHTS
  RESERVED, *"**Maintenance:** 1989"* for a 1998 document, *"public domain"* and *"still distributed by
  the Forest Service's Technology & Development programme"* for source B, *"avoid long tangents"* which
  the note found is not in it, and OpenDRIVE at 1.8/2024/CC BY-ND. The note records the truth; nothing
  carries it into the design. One clause in 328q's row (or a `328o-notes` row) fixes it.
- `docs/research/2026-11-03-curved-grid-roads.md`, section 5 target table — `| offset at every junction
  | **0**, asserted to 1e-12 | grid.spec, by construction (sin(pi*k)) |` cannot fail at the amplitude
  the bend is born with, and 328q's row already requires *"the whole suite answers what it answers
  today"* at `{0, 0, 1}`, so the junction assertion and the inert gate are one assertion. The pair that
  can fail is the junction zeros **plus** the mid-span offset equalling 45 / 60 at the half-pitch with
  the amplitude passed in by parameter. Queue beside 328q's items (ii)-(iv).
- `docs/research/2026-11-03-curved-grid-roads.md`, section 5 — *"at 1.5 three of the five junctions stop
  being zeros"* is **two** of five. `columns = 4` gives an E-W road five junctions at `k = 0..4`, and
  `A*sin(1.5*pi*k)` is non-zero only at `k = 1` and `k = 3` (-45, +45). The guard it justifies
  (`harmonic % 1 == 0`) is right.
- `docs/research/2026-11-03-curved-grid-roads.md`, section 2 B — *"the level formation is **2 to 3
  times** either class"*: 11.2/5.5 = 2.04 but 11.2/3.5 = **3.2**, so the top of the range is over 3.
  The leg the conclusion actually rests on is sound and is the one to keep: 20 studs painted = 5.6 m is
  past the Collector column's 5.5 m top.
- `reviews/task-328o/REQUEST.md` — *"Diff against `main`"* omits `docs/design/grid-roads.md` (added,
  1,005 lines), `reviews/task-328o/ARCH_RESULT.md` and `reviews/task-328o/BRIEF.md`, all three of which
  `changed-files.txt` shows as `A` against `97b2cfbc`. They are the Architect's `c30a4512` and the
  Director's `6e6e2051`, not this round's work, but the sentence reads as the whole branch diff.
- **Not verifiable here, and recorded as such rather than as wrong**: the five fetches and their HTTP
  codes, the licence texts, Table 4.1's transcription, the 403 on `fs.usda.gov`, the re-host's fidelity,
  the `grep -i radius` four-line count, and claim 10's three selftests. No network, no shell. What I
  could check is consistent: `changed-files.txt` touches nothing under `src/`, `tests/` or `tools/`, so
  the docs-only harness exemption is correct and `test2` N/A holds; `paperwork-after-code-commit.txt`
  says OK (only `reviews/task-328o/REQUEST.md` followed `05f770e9`); `selene` is 0/0/0 on `src` and
  `tests`; `rojo build` exits 0; `ls-files.txt` is 1,338 lines, matching claim 10's *"1338 tracked text
  files"*; and the changed files hold no local absolute user path and no non-noreply address.
- **Verified and correct, so not relitigated.** Claim 1: `TerrainBake.ROAD` reads `carriagewayStuds =
  20, -- 0 to +-20, level` and is used as a distance from the centreline (`if d <=
  spec.carriagewayStuds`, `crownY - spec.crownFallStuds * (d / spec.carriagewayStuds)`), and
  `Places.ROAD_TRUNK_FLOOR_STUDS = 34` carries *"road 0-21, ditch 22-30, verge 30-34"* verbatim, so
  20/40/68 studs -> 5.6 / 11.2 / 19.0 m all hold. Claim 2: the row is as quoted, 779.6/25 = 31.18 and
  1024.5/25 = 40.98, and `<=` is the safe direction (a higher true floor only shrinks the multiple).
  Claim 3: `sqrt(62.5^2 + 326.5^2)` = **332.428** -> 332.43, and `hypot(62.4616, 326.5239)` =
  **332.4445** -> 332.444, margin 2.44; the table's 332.44 stands. Claim 4: both attributions now read
  *"`grid-roads.md`'s own section 5.3 row"* / *"section 5.4 numbers"*, and section 6 item 8's "section
  14" is correct there. Claim 5: both lists are the same four URLs. Claim 7: `"52x and 68x"` occurs once
  in `TASKS.md`, inside the corrective clause, and both rows carry `<= 31x` / `<= 41x`. Claim 8: the
  328o row now attributes 332.43 to the parentheses and 332.44 to the realised pair. Claim 9: 1112 /
  1472, -6679 / -6579, 0.12713 / 0.12805, 7.2448 / 7.2965 (the design's 7.244 / 7.295 are the rounding
  slips), 2784.2 st / 779.6 m and 3659.0 st / 1024.5 m, 435.1 / 498.8 and 2.90 / 2.27, `dx0` 106,
  312.512 -> 340, 356.14 / 26.14, 324.04, 13.476, the fixed point 340 -> 365 -> 366, 357.45 / 27.45,
  586 / 806, 1026 / 404, the Jacobian 0.0163 and the five `toWorld` steps to 6.9e-8, 151.21, +0.82 %,
  0.16 / 0.33, 0.208, 31.46 / 31.24, and all of section 8 (3.0255 -> 3.03, 7260, 2640, 953, 20.1 % vs
  2.6 %, 3416 / 184, 7999, ~64,000, 25,200 vs 22,000) all re-run and reproduce; item 8's 42.59 is
  42.589.

---
REVIEWER verdict on commit `1afd7b74d8f8977d1552483032c0e3f6d676e484` (round 2) · 2026-11-03 15:25 UTC · session cost $2.33, 31 turns · written by tools/agents.py

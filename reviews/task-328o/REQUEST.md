# REQUEST -- Task 328o: curved grid roads, the research note and the docs round

Task: 328o
Round: 2
Base: `97b2cfbc` (main)
Code commit: `05f770e9`

**Docs only.** Nothing under `src/`, `tests/` or `tools/` is touched, so the harness is N/A
(CLAUDE.md loop step 3's docs-only exemption) and `test2` is N/A. Nothing in the world changed:
no frame, no click proof. Diff against `main`: `docs/research/2026-11-03-curved-grid-roads.md`
(new), `docs/research/INDEX.md` (one row), `TASKS.md` (nine rows), `ESCALATE.md` (two entries),
`reviews/task-328o/` (this file, `RESULT.md`).

Round 1 returned **one blocking finding and six notes**. The finding was right; it is fixed in
`f46e5c9f`, the Director authorised round 2 at the top of `ESCALATE.md`, and this round is the
notes. Every claim below names the commit the text lives in.

## Claims

1. **The blocking finding is fixed: the repo's road width is stated as the repo states it, and the
   class pick is gone.** `f46e5c9f`. Section 2 B's cross-section is now three half-widths read from
   the centreline -- painted +-10 = **5.6 m**, level formation `TerrainBake.ROAD.carriagewayStuds = 20`
   (*"0 to +-20"*) = +-20 = **11.2 m**, trunk-free `Places.ROAD_TRUNK_FLOOR_STUDS = 34` = **19.0 m** --
   and section 4 finding 1 concludes *"our road is wider than both of source B's classes ... so no
   published floor applies directly"*. *Verify:* section 2 B's table and section 4 finding 1 against
   `TerrainBake.ROAD` and `Places.ROAD_TRUNK_FLOOR_STUDS`.
2. **The ratio row is the defensible one, `<=` and against the 25 m floor.** `f46e5c9f`. Section 4's
   table row reads *"so ours is looser by, against the widest class B publishes | 779.6/25, 1024.5/25 |
   **<= 31x (E-W), <= 41x (N-S)** | "26 to 52x", N-S "same" | **NO -- finding 1**"*. 779.6/25 = 31.2,
   1024.5/25 = 41.0; `<=` because source B's own floor rises with the class. *Verify:* the row, and
   that no other section consumes the ratio (`grep` the design).
3. **Note (a), fixed and read back out of the commit.** `git show f46e5c9f:docs/research/2026-11-03-curved-grid-roads.md`
   finding 2 now reads *"The design's own parenthesised arithmetic, `sqrt(62.5^2 + (340 - 13.5)^2)`,
   evaluates to **332.43**, and at full precision (dx 62.462, dz 326.524) to **332.444** -- margin
   **2.44**, not 3.1."* sqrt(3906.25 + 106602.25) = 332.428. The table row's **332.44** is unchanged
   and still right (it uses dx 62.46 / bendZ 13.48). *Verify:* that sentence; recompute both.
4. **Note (d), fixed and read back.** The two attributions now name `grid-roads.md`'s own sections, not
   its section 14: `f46e5c9f` lines read *"Not blocking; `grid-roads.md`'s own section 5.3 row is
   corrected by 328q."* and *"... `grid-roads.md`'s own section 5.4 numbers are corrected by 328q."*
   Section 6 item 8 still says section 14, correctly -- that item IS about the section 14 delta text.
   *Verify:* `grep -n "corrected by 328q"` at `f46e5c9f`.
5. **Note (e), fixed and read back: the two URL lists are now equal, four each.** `f46e5c9f` section
   2 E lists terrain · `Terrain#WriteVoxels` · `datatypes/Region3` · `creator-docs/blob/main/LICENSE`
   -- *"**all four fetched, 200.**"* -- and section 7's Roblox bullet lists the same four. *Verify:*
   diff the two lists at `f46e5c9f`.
6. **Notes (b) and (c) are queued in `TASKS.md`'s 328q row, not fixed here.** Items (ii) and (iii) of
   that row: (ii) the section 14 delta's *"39.9 studs off its `dx` term"* matches nothing -- section
   5.4's linear bound is `0.12805 * 340 = 43.54` and the true max swing over a 340-stud window is
   **42.59** -- so neither 39.9 nor its *"3.1 studs of margin"* may be pasted as it stands; (iii) the
   *"cell depth ... exactly 1430"* row restates `cellDepthStuds` and cannot fail, so the
   **exact-translate property** is the assertable thing and 328q's spec is where it belongs.
   *Verify:* the 328q row.
7. **A fourth correction this round found: `TASKS.md`'s 328q row still carried round 1's ratio.**
   `05f770e9`. It said *"corrected to source B's real figures (15 m / 25 m; 52x and 68x)"* -- figures
   computed against a floor the blocking finding showed does not apply to our width, in the row that
   328q PASTES into the design. It now reads *"corrected to source B's real figures (15 m min. Rural
   Access, 25 m min. Collector) and to the fact that **our road is wider than both of those classes**,
   so the ratio row becomes **<= 31x (E-W, 780 m) and <= 41x (N-S, 1,024 m)** against the 25 m floor of
   the widest class B publishes, not 52x and 68x"*. *Verify:* `grep -c "52x and 68x" TASKS.md` is 1,
   inside that corrective clause, and the 328o row carries the same pair.
8. **Note (a) was repeated in `TASKS.md` and is fixed there too.** `05f770e9`. The 328o row now reads
   *"(the design's own parenthesised arithmetic, `sqrt(62.5^2 + (340 - 13.5)^2)`, evaluates to
   **332.43**; 332.44 is the realised pair at full precision, dx 62.462 / bendZ 13.48)"*. *Verify:*
   `grep "parenthesised arithmetic" TASKS.md` -- no 332.44 attribution survives.
9. **Everything round 1 verified is untouched.** `f46e5c9f` and `05f770e9` change no number in the
   verdict's note (g) list: the junction pitches, the first junctions, the slopes 0.12713 / 0.12805,
   the angles 7.245 / 7.297, the radii, the sight figures, the fixed point 340 -> 365 -> 366, 357.45 /
   27.45, and all of section 8. The `0.16 st` row the finding named is now two figures with their
   inputs -- **0.16** painted (20 * 0.00817), **0.33** level (40 * 0.00817) -- and carries finding 3,
   the repo's two meanings of *"carriageway"*. *Verify:* `git diff 41b33361..05f770e9` over the note.
10. **Rule G ran, even docs-only.** `python tools/agents.py selftest` -> **all ok**;
    `python tools/studio_mcp.py selftest` -> **selftest PASS**; `python tools/privacy_scan.py scan` ->
    **PASS: 0 findings in 1338 tracked text files**. *Verify:* re-run all three.

## What could not be verified

- **Nothing was measured in Karen's place, and nothing could be.** Docs-only: no harness run, no
  Studio, no frame, no voxel, no bake. Every repo number is read from the file named beside it; every
  derived number is arithmetic over those. The note's section 6 lists this and eight more items.
- **The five fetches cannot be re-made from the review worktree** (no network): source B's own
  `fs.usda.gov` URL is HTTP 403 here and the text came from a complete re-host, named in section 2 B,
  so *"still distributed by the Forest Service"* stays **unconfirmed**; the content is confirmed.
- **The sight figures 435 / 499 are still a tangent approximation** (`0.5*k*d^2` against a 34-stud
  corridor), not a cast ray. 328r's frame is the measurement.
- **Karen has judged neither the bend nor the moved flank stands**, as round 1's rule-5 paragraph says.

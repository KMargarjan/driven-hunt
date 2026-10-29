# Task 306 phase A — the range moves to the lodge: the research note and the design

Task: 306
Round: 1
Base: 2b77716e (`task-305-aim-what-you-see`; this branch is stacked on it, not on `main`)
Code commit: 4324c817

**DOCS ONLY. No file under `src/`, `tests/` or `tools/` is touched** — so no harness line is pasted
and none is required (CLAUDE.md, the loop step 3: *"Docs-only tasks are exempt"*).
Verify: `git diff --name-only 2b77716e..4324c817` lists exactly four paths —
`TASKS.md`, `docs/design/shooting-range-lobby.md`, `docs/research/2026-10-28-the-range-in-the-lobby.md`,
`docs/research/INDEX.md`, plus `reviews/task-306/{BRIEF,ARCH_RESULT}.md`.

Phase A's gate is the **Architect design PASS**, which is in hand:
`reviews/task-306/ARCH_RESULT.md` line 1 is `PASS` at commit `8d0b0b11` (54 turns, $9.56). The
Director dispatches B1 only after this review.

Karen, 2026-10-28 ~10:15 UTC, is quoted verbatim in §1 of the research note. She is away until
2026-10-30 and said: *spend two days on it, make it perfect, all tests.*

---

## Claims

1. **Rule 1 is satisfied: the note names what the system must do, 3+ external sources with licence
   and maintenance status, what each does well and badly, the pattern adopted and why, and the
   numeric targets.** `docs/research/2026-10-28-the-range-in-the-lobby.md`, §1 (seven requirements,
   each with a measurable), §2 (five sources A–E in a table with licence/status/good/bad columns),
   §3 (four Roblox doc pages plus three DevForum threads), §5 (the pattern and the numbers), §7
   (T1–T8). Verify: open the note; count the sources in §2 and §3; check each row has a licence and
   a status.
2. **Rule 2 is satisfied: the one invention is written down as one.** §2's heading *"The one thing no
   source has"* states that **no real running-boar range in the sweep has an elevated firing point**
   — every one shoots from a ground hut — so the treestand station is Karen's and this project's
   invention, and what it borrows is the *hunt's* structure (platform 3.0 m, rail 1.2 m above it)
   with the sourced reason hunters sit high at all. Verify: that subsection, and §13 of the design,
   which repeats it.
3. **The two new paces are TIMES, not speeds, and are genuinely new rows.** Note §5.2: ISSF
   specifies the time across the window, so `slow` = 5.0 s and `fast` = 2.5 s, and the stud speed
   falls out of `WINDOW_STUDS` 36 — 7.14 and 14.29 studs/s, which sit between `PACE.WALK_SPEED` 4.5,
   `TROT_SPEED` 11 and `RUN_SPEED` 24 (`src/shared/Boar`'s `CONFIG.PACE`, via the design's §6).
   Verify: the arithmetic in that table, and that neither number equals any shipped pace.
4. **L-154 is answered as arithmetic and not as a name-check, in both documents.** The note's §4
   tabulates every rule that owns the space (`Join.insideField`/`homeAreas` with `FIELD.SPAN_STUDS`
   220 → **x 2740..2960, z −3060..−2840**; `Join.walkwayTo` with `WALKWAY_HALF_STUDS` 24;
   `Range.footprintFor` → `ForestTestBoot`'s `rangeHomeAreas`; `ForestTest.boundsOf(ROAD_LAYOUT)`
   → x 2230..3830, z −2477..−1197, `exitZ −2377`; the truck pads; the stand rule) **and derives that
   a 6-station footprint is about 304 × 222 studs, which the 220 × 220 field cannot hold on either
   axis** — so an extra home area is required whatever site is chosen. The design then does it for
   the chosen anchor: §2.2 works `footprintFor` through to **x 2536..2784, z −3237..−2998.9**, §2.3
   gives the union and a nine-row membership table including a point that is correctly **outside**
   home, §2.4 the drive margin, §2.5 the obstacle clearances with crown width, §2.7 the stand rule
   by four named symbols. Verify: §4 of the note, §2.1–§2.7 of the design; re-do any row.
5. **T1 is derived from her own measurement, not the nominal walk speed.** Note §4: 268 studs in
   25.7 s = 10.4 studs/s effective, so 20 s = **208 studs or less**; `Body.defaultWalkSpeed` 16 is
   explicitly not used. Design §2.6: lodge door (2850, −2916) to the nearest mat (2720, −3030) is
   166.5 studs straight and **186.7 studs / 17.9 s** walked round the gathering yard's corner.
   Verify: both arithmetics.
6. **The design states its one deviation from a Director decision rather than slipping it in.**
   Brief decision 3 says *a client-drawn animal*; design §4.2 keeps pattern 3's three load-bearing
   parts (server-owned per-station run DATA, the shot reported as NUMBERS, the server the judge) and
   replaces the fourth with **client-MASKED**, with three pieces of evidence: the templates are
   `ServerStorage`-only and never replicated (CLAUDE.md's Layout table), a client copy would be a
   second renderer and a second writer of where an animal is drawn, and `MODEL.HIDE_BOX` already
   ships the invisible body. It is **open decision 1 for the Director** (§15) and **B1–B4 do not
   depend on it** (§16). Verify: §4.2, §15 item 1, §16's dependency sentence.
7. **The design names the moving-target hit as THE proof of the feature (verdict 298's tests rule).**
   §11.1: `{stand, walk, trot, run, slow, fast} × {bench, treestand}` = **12 cases**, each with task
   305's three numbers plus the shooter's-eye frame, and **rule L's known-bad control beside each** —
   a click at the air beside the animal must produce no hit and no `HitLog` line — with the sentence
   *"A design that proves only the 12 hits has proved half"*. It is T4 in §12 and the whole of step
   **B9** in §16. Verify: §11.1, §12's T4 row, §16's B9 row.
8. **L-151: every spatial and compositional fact is marked unverified-until-built in the documents
   themselves.** Note §7's closing paragraph names the 6-station spacing, the berm's height and
   slope, the 10.7-stud platform, the site's clearances and T6, and says an Architect PASS proves the
   document is coherent and not that it fits the engine, citing task 298 step B2's two placement
   errors. The design has a whole section for it, **§14 UNVERIFIED UNTIL BUILT (L-151)**. Verify:
   both.
9. **L-108: no engine API is named from memory where ownership depends on it.** Note §3 and §5.4
   carry the Roblox doc links for instance streaming, remote events, the client-server boundary,
   security tactics, the `Terrain` API and the 20 000-triangle mesh limit; design §4.1 cites
   `GetPartBoundsInRadius` to its reference page **and** to `Cast.luau`'s own header. Verify: follow
   two of the links; check §4.1's citation against `src/server/Weapon/Cast.luau`.
10. **L-125: this design will not be re-derived from scratch.** `TASKS.md` has a **row 306** naming
    the branch, the base commit `2b77716e`, what the note decided and what phase A's gate is; the
    design and the brief are committed on `task-306-range-lobby` and pushed, so B1's ROUTE line can
    name branch + commit. Verify: `grep -n "^| 306 " TASKS.md`; `git log --oneline origin/task-306-range-lobby -2`.

## What I could NOT verify (rule 8)

- **Nothing in either document is an engine fact.** Phase A built nothing and measured nothing in a
  running place: every geometric number is arithmetic over readings taken by earlier tasks
  (`evidence/p306-lobby.txt`, `evidence/p298/walk-after.txt`) or over shipped constants. The site's
  ground spread, the clearances against a real part census, and T1 walked are **B1's job** and are
  written as B1's job.
- **No screenshot** (rule 5): phase A changes nothing visible. N/A.
- **No harness run**, so no claim is made about the suite. L-136 is therefore not applicable; if a
  later phase cites the suite, the known flake to name is `weapon_shot.spec.luau:1490`.
- The berm's height is **not settled by any source** — the NRA's 6 m reaches us through two forum
  quotes that disagree and the German *Schiessstandrichtlinien* text was not retrievable — so 21.4
  studs is an upper bound and Karen's "not high" decides inside it (note §2, design §15 item 8).
- The lane surfaces (mown grass, gravel) are a stated **GUESS**: no source was found.

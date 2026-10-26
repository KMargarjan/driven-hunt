# Review request — Task 277: an honest hit accepted by construction, and real vital organs

Task: 277
Round: 1
Base: `be4de11f` (`main`, after PR #255)
Code commit: `6293136c` — **DOCS ONLY. Nothing under `src/`, `tests/` or `tools/` changed**, so no
harness line is required (`tools/agents.py`, "docs-only change: no harness line required").
`git diff --name-only main...HEAD` is exactly: `TASKS.md`, `docs/design/ballistics.md`,
`docs/design/hit-zones.md`, `reviews/task-277/ARCH_RESULT.md`, `reviews/task-277/BRIEF.md`.

## What changed

The Director dispatched a **design, not a trial**: tasks 269b–276 iterated on the claim validator
piece by piece without converging, so this task writes the design and the next one builds it.

Three commits: the BRIEF (`a3b6663e`), Architect run 1 → `docs/design/ballistics.md` v5
(`2ee60af3`), Architect run 2 → `docs/design/hit-zones.md` v2 (`6293136c`). **No gameplay code.**

**CORE QUALITY PROTOCOL: `CORE-NA`,** as the dispatch states. There is no `## PLAN`/measure→change→
re-measure block because this task writes no `src/` edit and takes no reading; MEASURED NOW
(tasks 265–276) is transcribed into the BRIEF instead, as §"MEASURED NOW", and the designs' numeric
targets are accountable to it.

## Claims

1. **`reviews/task-277/BRIEF.md` carries the Director's direction verbatim.** Directions A, B and C
   are under `## THE DIRECTOR'S DIRECTION (verbatim)` word for word, and Karen's three sentences are
   quoted above them. *Verify:* read that heading against the dispatch text.
2. **MEASURED NOW is in the BRIEF with its provenance.** Five numbered findings (the ~5-stud
   `v × 0.19 s` lag in both arms; `claim-line` 4.09/2.00 and 2 of 2 while the sweep reaches
   19/19 over 0.301 s with `took == best`; an accepted claim does decide the hit, photographed; the
   chest reachable only 40–115° off the nose, 1.54 against a 6.03 trunk; 269b–276 did not converge),
   each attributed to its task. *Verify:* `## MEASURED NOW` against `TASKS.md` rows 265–276a.
3. **Two Architect runs, two documents, and run 1's verdict survived.** `tools/agents.py` writes one
   `reviews/task-277/ARCH_RESULT.md` per task and run 2 overwrote it (Learning Agent L-111). Run 1's
   `PASS` is committed in `2ee60af3`; run 2's is the file at HEAD. *Verify:*
   `git show 2ee60af3:reviews/task-277/ARCH_RESULT.md` reads `PASS … (design ballistics …) … $7.91,
   53 turns`, and the file at HEAD reads `PASS … (design hit-zones …) … $7.51, 50 turns`.
4. **Run 2 did not truncate run 1's document.** A baseline copy of `docs/design/ballistics.md` was
   taken after run 1 and before run 2 started, and `diff` against HEAD is empty. *Verify:*
   `git diff 2ee60af3 6293136c -- docs/design/ballistics.md` is empty (run 2's commit touches only
   `hit-zones.md` and `ARCH_RESULT.md`).
5. **The zones' system was named `hit-zones`, not `boar-zones`.** The dispatch said *"`design
   boar-zones` or the right system name"*; the doc on disk is `docs/design/hit-zones.md`, and
   `docs/design/boar-zones.md` was not created. *Verify:* `ls docs/design/ | grep -i zones`.
6. **Direction A is answered and `claim-line` is resolved by name.** `ballistics.md` §5.4 **deletes**
   the old check 4, on the stated ground that both its operands (`trajectoryPoint`, `serverPoint`)
   are server-side reconstructions in which the claim appears in neither — so an honest client could
   satisfy it only by luck — names which remaining checks (3, 5, 6) stop the cheat it was credited
   with, and deletes `LINE_TOLERANCE_STUDS` rather than renaming it so no stale reader carries the
   old budget forward. §5.2 states the seven checks each with its cheat and its honest worst case;
   §5.3 holds one clock; §5.9 re-enumerates the modified-client bound. *Verify:* §§5.2–5.4, 5.9.
7. **Direction B is answered as a change of kind.** `hit-zones.md` §§3.1–3.7 replace the four
   surface boxes (`PROTRUSION = 0.06`, first box the ray meets wins) with **seven volumes inside a
   two- or three-part hull**, decided by a slab test along the shot's path, with `rank` replacing the
   race on overlap, damage as the **MAX** over volumes crossed (§5.3, not the sum), and
   `PENETRATION` deciding depth. §5.5 answers 276a(d): **a head-on chest shot is not supposed to read
   `body`.** §5.6 states the broadside / quartering / frontal assertions in degrees. *Verify:*
   §§3.1–3.7, 5.3, 5.5, 5.6, and the per-kind volume tables §3.2 (boar) and §3.3 (red deer).
8. **Direction C is in both documents' numeric targets, split by accountability.**
   `ballistics.md` §11.1 and `hit-zones.md` §8.1 each take the half they own, and `ballistics.md`
   §11.3 states that criterion C3's instrument **does not exist** — task 276a(a) measured 1–2 s
   between the gate reading and the real click, with 6 of 10 shots tail-on at the trigger although
   all 10 passed a chest gate. *Verify:* those three sections.
9. **Both designs keep the engine-API discipline (L-108).** Neither asserts an unverified API as
   fact: `hit-zones.md` §12 puts `CFrame:PointToObjectSpace`/`VectorToObjectSpace` on a welded
   child's frame, the slab test's NaN behaviour, the `PENETRATION` numbers, the two new pellet
   damage numbers and every source URL/licence into **"What I could not verify"**, with the probe or
   the spec case that settles each. `ballistics.md` has the same section (§15). *Verify:*
   `hit-zones.md` §12 and `ballistics.md` §15.
10. **The grep is carried forward, not absorbed (L-030).** `ballistics.md` §13.3 and
    `hit-zones.md` §10.3 both name the re-grep of every `claim-line` caller and spec as a **build-task
    step**, listing `Validator.luau`, `Weapon/init.luau`, `Shotgun.CONFIG.CLAIM`,
    `weapon_hits.spec`, `zz_claim_window.spec`, `weapon_shot.spec`. This task did not do it, by
    design. *Verify:* those two sections.

## What could not be verified

- **Nothing in either design was played.** Both are documents; no `src/` change exists to test, and
  no live reading was taken in this task. Every number in them is either transcribed from tasks
  265–276 or derived by the Architect from the repo's own measurements, and each document's
  "What I could not verify" says which.
- **The harness was not run and is not required** (docs-only; `tools/agents.py` asks for no harness
  line). Rule G's two selftests were run and pass: `python tools/studio_mcp.py selftest` →
  `selftest PASS`, `python tools/agents.py selftest` → `all ok`.
- **The two designs leave one cross-document item open, and it is the Director's call, not mine.**
  `hit-zones.md` §10.1 names **three sentences in `ballistics.md` v5** that go stale when v2 is built
  (§1.2's *"the zone is that part's own `HitZone`"*, §5.6 property 1's *"four zone parts"*, and the
  §2 owners row calling `Flight`/`claimImpact` untouched). `docs/design/` is the Architect's file and
  the Builder may not rewrite a design, so the fix is either a third Architect run or a documented
  note — recorded in `TASKS.md` row 277a, not applied here. **No number in v5 moves**: v5's per-kind
  tolerances are read off `trunk.Size`, which v2 does not touch.
- **Karen has seen none of this.** It is a design; nothing is playable from it yet.

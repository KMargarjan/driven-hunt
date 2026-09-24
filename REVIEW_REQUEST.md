# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 2
Base: `7399585`
Code commit: `0f5627fa8d819169c32f22a1049e2ba4ffbd7faa`

## Task

TASKS.md #19, ROADMAP step 1.4: **shotgun research and design only. No game code.** The Director's
dispatch says so explicitly.

The change is three documents and two index/queue rows. There is no `src/`, no `tests/`, no
`tools/`. **What is worth your time is whether the note and the design are *true* and *usable***, not
whether any code works — there is none.

**No harness run, and none is possible.** `rojo serve` crashed during Task 17 and only Karen can
press Connect (~09:00). The Director dispatched this in no-Studio mode. Nothing in this task needs
Studio anyway, since nothing executes.

## What changed

| File | What it is |
|---|---|
| `docs/research/2026-09-24-shotgun.md` | the research note (rule 1): 9 sources with licence and maintenance, the numbers and their derivation, the pattern adopted, the written reasons for two rejections |
| `docs/research/INDEX.md` | its row |
| `docs/design/shotgun.md` | written by `tools/architect.ps1 design shotgun`, not by me |
| `ARCH_RESULT.md` | written by `tools/agents.py`, not by me. A numbered list of 3 blocking open decisions, not `PASS` |
| `TASKS.md` | row 19 |

## Claims

Files and symbols, not line numbers (CLAUDE.md loop step 4).

1. **The note was written before the design, and the design before any code.** Verify:
   `.agent-evidence/log.txt` — commit `003dc0a` adds the note and its INDEX row; `9cf9d7d` adds
   `docs/design/shotgun.md` and `ARCH_RESULT.md`, whose trailer names `003dc0a` as the commit it was
   written against. No file under `src/`, `tests/` or `tools/` is touched at all:
   `.agent-evidence/changed-files.txt`.
2. **Rule 1 is met in substance: 9 sources, each with a licence and a maintenance status, and each
   with what it does well *and badly for this system*.** Verify: the note's "Sources" section,
   headings 1–9. The licences are: first-party Roblox docs (creator-docs CC BY 4.0) for 1, 2, 5, 6;
   dual MIT/ART for FastCast2; MIT for `rbx-fractality-spring`; a forum post for the viewmodel
   write-up; two copyrighted articles cited for figures only; and **"could not confirm"** for ACS.
3. **Rule 2 is met: two rejections, each with a written reason.** FastCast2 is rejected because it
   solves travel time and drop, which do not exist at these ranges, and because its provenance is
   split across four forks over a dead upstream — the same shape as the SimplePath rejection. ACS is
   rejected because its licence could not be confirmed and it replaces every owner in the game.
   Verify: the note's "Pattern adopted, and why", points 4 and 5, and sources 3 and 9.
4. **The one invention is named as an invention.** The safety rule (shooting toward the drive line)
   has no external pattern because it is this game's own mechanic; the note says so and reduces it to
   a dot product and one number. Verify: the note, "What is invented, and why it has to be".
5. **Every number in the table now says which it is: derived, a feel number, or unattributed.**
   Round 1's finding 6 was right that the old claim was false — the 0.2 s ADS transition and the
   9-pellet count were presented as derived and are not. Both rows now say so in the table itself:
   the ADS row says "**The 0.2 s is a feel number** — it appears in no source and is not derived",
   and the pellet row says "**Not from sources 1–9** … I did not verify it against a primary source".
   Verify: the note's "Numeric targets" table, rows "Pellets" and "ADS transition"; the derived rows
   (slug range, buckshot range, both cones, boar scale) each carry their arithmetic; reload,
   barrel delay and the validation tolerances are labelled feel/guess.
6. **The two ballistics sources are used against each other rather than taken on trust.** Source 8
   kills the "1 inch per yard" rule (measured 0.5 in/yd on stock barrels, 0.96 in/yd back-bored) and
   source 7's own figures bracket it (45 in at 30 yd = 1.5 in/yd open; 15 in at 30 yd = 0.5 in/yd
   full choke), so the note states a **band** of 0.5–1.5 in/yd and picks the middle. Verify: sources
   7 and 8, and the buckshot spread row.
7. **The client/server split is derived from a checkable engine fact, not from a preference.**
   `Camera` is "Not Replicated" and the viewmodel lives under it, so the server cannot see the aim
   ray and *cannot reproduce* a shot — only validate it within tolerances. Verify: the note's
   source 5, and the design's §7.3 ("The client never names a target").
8. **The note is honest about the limit of that validation.** It states plainly that a client lying
   about direction only (an aimbot) passes every listed check, because direction is unknowable to the
   server, and that this is accepted for v1. Verify: source 5, "Bad".
9. **The note argues for one camera writer and one viewmodel writer; the design defers both, and
   that disagreement is an open Director decision.** Round 1's finding 2 was right that the old
   claim ("the design's §3 assigns exactly one owner each") was flatly false: design §3.1 assigns
   `WeaponServer`, §3.2 assigns `WeaponInput` / `WeaponReplica` / `ShotEffects`, and **neither the
   camera nor the viewmodel has an owner anywhere** — §3.3 ships the gun on the default camera with
   no ADS and no viewmodel, and §13.2 makes that cut the Director's call. The note's reasoning for
   why the owners matter still stands and is why the design refuses to let the *weapon* become the
   camera's second writer. Verify: the note, "Why this note is longer on the camera than on the
   gun"; design §3.1–3.3 and §13.2; `docs/research/INDEX.md`, which now records the deviation.
10. **The design names what is blocked on Task 6 and Task 7 and proposes the smallest unblock for
    each, as the Director asked.** Verify: design §11.3. Task 6's smallest unblock is one
    `tests/input-scenarios.json` entry, one harness step replaying it through the existing
    `user_keyboard_input`, and one client spec asserting the key arrived — reusing the report
    channel, gate and token unchanged. Task 7's is that **there is no tool path**: rule-5 evidence
    stays Karen's screenshot, recorded in `PLAYTEST.md`, plus a client spec that makes the specific
    lie the old project's visibility audit told (ignoring parent visibility) impossible to repeat.
11. **`ARCH_RESULT.md` is a numbered list, not `PASS`, and all three items are Director scope calls.**
    I did not escalate, because they block the **code** (Task 1.4), not this docs task, and the
    dispatch was docs-only. They are in the report and in `TASKS.md` row 19. Verify: `ARCH_RESULT.md`,
    design §13.1–13.3, `TASKS.md` row 19.
12. **The design's third blocking item is a real process defect, not a design gap.** The Architect
    could not see `docs/research/2026-09-24-boar-ai.md` or `docs/design/boar-ai.md` because this
    branch is cut from `main` and the boar work is on unmerged branches — so it cannot guarantee one
    writer for the damage entry point. That is audit-002 must-fix 4 (the Architect audits blind)
    biting a second time. Verify: design §13.3; `TASKS.md` row 13.
13. **No owner rows were added to `GAME_DESIGN.md`.** The design drafts them in §12, and they land
    with the code. A system that does not exist has no owner, and claiming one now would make the
    table lie. Verify: `.agent-evidence/changed-files.txt` — `GAME_DESIGN.md` is not listed.
14. **Nothing in `src/`, `tests/` or `tools/` changed, so lint and build are unaffected.** They were
    run anyway and pass: `.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`.

## Round 2: the ten round-1 findings

All ten were right. Seven were mine and are fixed in the code commit; three are in files rule 3
gives to the Architect, and the Builder does not edit those.

15. **Finding 1 — I cited an `ESCALATE.md` entry that is not on this branch.** The worst of the ten,
    because it is the whole justification for having no harness line. Fixed: the `NEEDS KAREN` entry
    with the exact clicks is now in `ESCALATE.md` on this branch. See the Harness section.
16. **Finding 2 — claim 9 was false.** Fixed above, and the INDEX row too (finding 8).
17. **Findings 3 and 4 — the two cones.** The slug cone was labelled "0.16° half-angle" while its own
    derivation gives 0.16° **full**, and the buckshot value cell said "~1.0° full cone" against its
    own derivation of 1.6°. Both rows now state the **full** angle with the half-angle in brackets
    and show the arithmetic. This matters beyond the note: design §6 takes a `halfAngleDeg`, so one
    config field would have held two units.
18. **Finding 5 — two different bands two clauses apart.** The source-8 paragraph said "the range
    0.5–1.0 in/yd" and then "our band is 0.5–1.5 in/yd". It now states **0.5–1.5 once**, and says so.
19. **Finding 6 — claim 5 was false.** Fixed in claim 5 and in the table itself.
20. **Finding 7 — three numbers rested on files not in this repo.** Fixed: the stud scale now comes
    from source 6 directly; the boar's 5.5 × 3 × 2 is **re-derived here** from 1.5 × 0.9 × 0.5 m at
    0.28 m/stud; and the SimplePath comparison is marked as context whose source is off-branch, with
    the FastCast2 rejection standing on its own. The note's new addendum says which files are
    invisible from here and why.
21. **Finding 8 — the INDEX row claimed as settled what the design defers.** Fixed.
22. **Finding 10 — four wrong `PROJECT_CONTEXT.md` citations and a wrong cause count.** The note said
    "three of the five causes"; the file lists **six**, and my three quotes come from **two** of
    them. Fixed in the note and in claim 9 here. The four wrong line numbers are in the design, not
    the note — see below.
23. **Findings 3, 9 and 10 (design side) are the Architect's to fix, and I have not touched them.**
    `docs/design/` and `ARCH_RESULT.md` belong to the Architect (CLAUDE.md rule 3 and the Roles
    table); the Builder never edits them. The three are recorded in the note's addendum so they
    travel with the document: the design copies my "0.16° half-angle" error into §9 beside a
    full-angle buckshot row while §6 takes `halfAngleDeg`; `ARCH_RESULT.md` item 1 points at §11.1
    where it means §11.3; and the design mis-cites four `PROJECT_CONTEXT.md` line numbers. **I chose
    not to re-run `tools/architect.sh design shotgun`** — it is a paid session, the Director allowed
    two review rounds, and a regenerated design would arrive unreviewed with no round left to check
    it. It should be regenerated when the boar branches are merged and the Architect can finally see
    them (its own blocking item 3), and these three go in then.

## Harness

**N/A — no code, and Studio is unreachable.** Nothing in this change executes: it is three markdown
documents and two table rows.

Round 1's finding 1 was right and it was the most important of the ten: I cited an `ESCALATE.md`
entry that **did not exist on this branch**. The Task 17 and Task 18 entries are on unmerged
branches, so `main` and everything cut from it had no record of why no task can produce a harness
line. `CLAUDE.md`'s stop rule requires the entry with the exact clicks, so **it is now written here**:
`ESCALATE.md`, "NEEDS KAREN · `rojo serve` is down; no task can be harness-tested". It lists the
clicks in order, and it says plainly that Tasks 17 and 18 have never been executed at all.

Lint, format and `rojo build` are clean, unchanged by this task.

## Could not verify

- **The ACS licence.** I could not find a licence file or an explicit grant; the note says
  "could not confirm" rather than guessing, and ACS is rejected partly *for* that. If you can find
  one, that is a finding.
- **FastCast2's canonical home.** Four near-identical forks exist and the Wally package is published
  under one of them (`weenachuangkud/fastcast2`). I did not establish which is authoritative — and
  the note treats that ambiguity as the reason to stay away, so nothing depends on resolving it.
- **The viewmodel write-up is a 2021 forum post** using `SetPrimaryPartCFrame`, superseded by
  `PivotTo`. I took the technique, not the code, and said so — but I have not seen the pattern run.
- **Every number in the note is arithmetic, not measurement.** The stud conversions are exact; what
  they *feel* like at 100 studs in a real playtest is unknown, and the hit-validation tolerances are
  admitted guesses that "must be measured with two real players".
- **Whether the design's `.model.json` / `init.meta.json` shapes are accepted by Rojo.** The design
  flags this itself (§5.4): it would be the repo's first `init.meta.json`, and audit-002 F2 is
  untested. Nothing here proves it.
- **The design document is the Architect's work, not mine.** I read it and agree with it, including
  its §3.3 cut of ADS and the viewmodel. If you think that cut is wrong, say so — it is the one
  judgement in this task I would most like a second opinion on, and §13.2 makes it the Director's
  call rather than mine.
- **The Director's dispatch for this task is not transcribed in `TASKS.md`.** Task 18's review found
  that gap and it was fixed there, but Task 18 is on an unmerged branch, so this branch has no
  "Director dispatches" section to add to. Row 19 records the scope in its own words instead. If you
  want the section recreated here, say so.
- **Round 1 found ten things and seven were mine**, including a citation to a file that does not
  exist on this branch. Four of the ten are the same failure: I stated a number or a claim and did
  not check it against the thing it cited. In a task whose entire output is citations, that is the
  defect that matters, and I do not think a second round proves it is gone.

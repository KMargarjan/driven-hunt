# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 2
Base: `7399585`
Code commit: `00df9666e6af9e36872d7f6bc696546696071c36`

## Task

TASKS.md #20, ROADMAP Milestone 2: **map generator research note only. No code, no Architect
design** — the Director dispatched research only this time.

The change is one new document plus edits to three existing ones. There is no `src/`, no `tests/`,
no `tools/`.
**What is worth your time is whether the note is true and usable**, and in particular whether its
central negative finding is right, because the whole adopted pattern turns on it.

**No harness run, and none is possible.** `rojo serve` has been down since Task 17 and only Karen can
press Connect. The record with the exact clicks is `ESCALATE.md`, "NEEDS KAREN · `rojo serve` is
down; no task can be harness-tested" — **on this branch**, because a previous round of Task 19 caught
me citing that entry when it existed only on unmerged branches. Nothing in this task executes
anyway.

## What changed

| File | What it is |
|---|---|
| `docs/research/2026-09-24-map-generator.md` | the note: **13** sources with licence and maintenance, the numbers and their derivation, the pattern adopted, the smallest first generator task, what needs Karen |
| `docs/research/INDEX.md` | its row |
| `TASKS.md` | row 20, and the Director's Task 20 dispatch transcribed verbatim |
| `ESCALATE.md` | the `NEEDS KAREN · rojo serve is down` entry, written on this branch — see claim 15 |

## Claims

Files and symbols, not line numbers (CLAUDE.md loop step 4).

1. **The central finding is that Studio's heightmap/colormap import cannot be driven from code or
   MCP, and the note states it plainly as the Director asked.** Verify: the note's source 3. The
   Terrain Editor page describes Import and Generate as Studio UI tools and documents **no scripting
   API** for either; the Studio MCP server's tool list (`execute_luau`, `insert_asset`,
   `search_asset`, `screen_capture`, `generate_*`, `start_stop_play`, `user_*_input`,
   `get_console_output`, …) contains nothing that drives the Terrain Editor. The note draws the
   consequence rather than hedging: the generator computes its own heightfield.
2. **Rule 1 is met in substance: 13 sources, each with a licence and a maintenance status, and each
   with what it does well *and badly for this system*.** Verify: the note's "Sources",
   headings **1–13**, in that order. First-party Roblox docs (CC BY 4.0) for 1, 2, 3, 4, 5, 9 (the
   API half), 10 and 11; MIT for RTerrainGenerator (7); DevForum posts cited as figures or
   corroboration only for 6, 13 and the mesh limits in 9; **an explicit "could not confirm"** for
   the Creator Store Terms (8), which returned HTTP 403; and **§12, which is not a published source
   at all** — a first-hand `tools/list` call against the Studio MCP server, labelled as such, with
   "licence / maintenance: not applicable" and the caveat that StudioMCP is unpinned.
3. **Rule 2 is met: three rejections, each with a written reason.** The Terrain Editor's Import and
   Generate tools (unreachable from code, and their state is UI state, not a file);
   RTerrainGenerator's *code* (MIT and worth reading for domain warping, but it does not use Roblox
   Terrain and shows no recent activity); and heightmap PNGs as the source of truth (not reviewable
   as a diff, which is the point of map option C). Verify: the note's "Pattern adopted, and why",
   final paragraph, and sources 3 and 7.
4. **Nothing is invented, and the note says what the only project-specific part is.** Noise
   heightfields with domain warping, voxel writes, tag markers, id-referenced assets and seeded
   generation are all standard; only the layer order and the tag vocabulary are ours, and those are
   naming decisions. Verify: "Pattern adopted", the "Nothing here is invented" paragraph.
5. **The map carries no scripts, and the note gives the mechanism.** `CollectionService` tags
   (`AddTag`, `GetTagged`, `GetInstanceAddedSignal`) with an agreed vocabulary — `BoarSpawn`,
   `DriveStart`, `ShooterPost`, `DriveLine`. Verify: source 4 and pattern point 4. The note also
   names why this is the seam that makes the grey-box arena and the real map interchangeable to the
   boar and the shotgun.
6. **The note does not assert that tags survive a save, and makes confirming it the first task's
   job.** This is the one that would silently sink the whole marker scheme. Verify: source 4's "Bad"
   — the reference page does not say whether tags are serialised, so the note refuses to assert it
   from memory — and "The smallest first generator task", which lists it as the question to answer
   cheapest.
7. **Streaming numbers come from the docs where they exist and from the community where they do
   not, and the note says which is which.** `StreamingMinRadius` 64 and `StreamingTargetRadius` 1024
   with Roblox's own recommendation to keep them, `StreamingIntegrityMode.PauseOutsideLoadedArea`,
   `ModelStreamingBehavior.Improved`, and the four per-model `StreamingMode` values — all first-party
   (source 5). The ~50,000 desktop / ~20,000 mobile visible-part figures are DevForum rules of thumb
   and are labelled as such (source 6).
8. **The public-repo licence hazard is identified and turned into two rules.** The Creator Store
   licence is **use-on-Roblox**, not a redistribution grant, so: never commit a Creator Store asset
   (the repo stores the **asset id**), and keep a provenance manifest so a later licence or
   moderation question is answerable. Verify: source 8. The note also says plainly that a free model
   whose uploader did not own the work is a live hazard and that ids get moderated away.
9. **The Open Cloud key discipline is stated because the docs do not state it.** The Assets API page
   gives the `x-api-key` header and the assets read/write scope but says nothing about secrecy; the
   note makes the key an **environment variable**, never a file, never a commit, and requires the
   upload tool to fail loudly when it is unset. Verify: source 9's "Bad". It also catches that meshes
   are "not available for updating", so a changed mesh is a **new id** and the manifest must be
   versioned.
10. **The backup step is specified as a `NEEDS KAREN` click, with the reason.** `File → Save to File`
    to a dated `.rbxl` **outside** the repository, before every rebuild, because Workspace is not
    Rojo-mapped and so has no git history behind it, and because `.rbxm`/`.rbxmx` are already banned
    here as unreviewable binaries. Verify: source 10 and pattern point 6.
11. **Every number is derived at a stated scale or labelled a target, and the note says outright
    that none of them is measured.** Verify: the note's "Numeric targets" table and the sentence
    immediately after it — "**Every one of these is unverified.** Nothing in this project has yet run
    on a phone, and the map does not exist." 2048 studs = 573 m at 1 stud = 0.28 m; the part budgets
    trace to source 6; the mesh limits (21,000 triangles, 1024 × 1024 textures) are Roblox's hard
    import limits; the drive length, post spacing, memory and load-time rows are marked feel/target.
12. **The note ends with the smallest first generator task, and each of its five bullets names
    where the question comes from.** Round 1's finding 4 was right that "one-to-one onto sources 2, 4
    and 10" was false. Verify: "The smallest first generator task" — a 512 × 512 stud slice, two
    materials, one hedgerow, 50 trees from one asset id, four tagged markers, then
    save-reopen-confirm. The five bullets trace to: **§2** (`WriteVoxels` region size and whether
    `resolution` 4 is the only value); **§11 and pattern point 2** (what `math.noise` returns and
    whether it is stable — the assumption the seed story rests on); **§4** (do tags survive a save);
    **`TASKS.md` row 7**, not a source (whether Edit-mode `screen_capture` is rule-5 evidence — Task 7
    is unsolved for *play-time* screenshots, and this generator runs in Edit mode); and **§6** (what
    50 trees cost, so the 3,000-tree budget can be multiplied out).
12a. **The seed mechanism is stated properly, and the assumption under it is named.** Round 1's
    finding 1 was right: `math.noise` takes **no seed**, so the old text ("it seeds its own
    `Random`") answered nothing about the heightfield. Verify: pattern point 2 — the seed becomes a
    **coordinate offset** into the fixed noise field, `Random.new(seed)` drives everything discrete,
    and the note says outright that reproducibility rests on `math.noise` being stable across
    sessions and engine versions, **which the documentation does not promise**, with the fallback
    named (a small seeded noise implementation on disk).
12b. **The maths library is now a numbered source.** Round 1's finding 2 was right that the whole
    heightfield rested on a page the note never named. Verify: source 11 — URL, licence (first-party,
    CC BY 4.0), maintenance, the confirmed signature `math.noise(x, y, z): number`, and the "Bad"
    that the page gives the signature **and nothing else**.
13. **It notices that Milestone 2 may be the first visual work in this project that can meet rule 5
    without Karen.** The generator runs in **Edit** mode, and `screen_capture` over MCP is Edit-mode
    only — which is exactly why it is useless for Task 7's play-time problem and potentially useful
    here. Verify: "The smallest first generator task", fourth bullet.
15. **`ESCALATE.md` gains the `NEEDS KAREN` entry for `rojo serve`, on this branch, and it asserts
    only what I checked.** Round 1's finding 5 was right that it was in the change but in no claim.
    It states: `rojo serve` has been down since Task 17 (no `rojo.exe`, nothing on port 34872);
    Studio is still in Edit mode and its MCP server answers, so only Rojo is down; the exact clicks
    for Karen in order; that Tasks 17 and 18 have **never been executed at all**; and **why the entry
    is repeated here** — the copies on `task-17`, `task-18` and `task-19` are unmerged, so `main` had
    no record, and Task 19's round 1 caught me citing it from a branch where it did not exist.
    Verify: `ESCALATE.md`, the first entry. The process claims (rojo down, Studio up) are ones I
    re-checked in this session; you cannot verify those from the repo, and they are listed under
    "Could not verify".
16. **Nothing in `src/`, `tests/` or `tools/` changed.** Lint, format and `rojo build` were run
    anyway and pass: `.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`.
    `GAME_DESIGN.md` is untouched — there is no system yet, so there is no owner to record.

## Round 2: the six round-1 findings

All six were right. Four were in the note or `TASKS.md` and are fixed in the code commit; two were in
this request and are fixed above.

17. **Finding 1 — the determinism story did not work.** The sharpest finding of the six, and it
    caught a real muddle rather than a typo: `math.noise` has no seed parameter, so seeding a
    `Random` said nothing about the heightfield, while pattern point 2 promised "one `seed` number
    reproduces the map exactly". Fixed as claim 12a.
18. **Finding 2 — the maths library was a source in everything but name.** Fixed as claim 12b.
19. **Finding 3 — three sets of broken section references.** All three were wrong in the same way:
    pointing at a source number when meaning a section, or at the wrong source. The backup step is
    §10 (it was §6, twice), the part budgets are in "Numeric targets" (they were §9, twice), and the
    `math.noise` bullet now points at §11 and pattern point 2. In a note whose only value is being
    usable by the next Builder, these matter more than their size suggests.
20. **Finding 4 — claim 12's "one-to-one" was false.** Fixed above; each bullet now names its source,
    including the one that traces to `TASKS.md` row 7 rather than to any source.
21. **Finding 5 — `ESCALATE.md` was in the change but in no claim, and the summary said "two table
    rows".** Both fixed: it is in the table, the summary is corrected, and claim 15 states what the
    entry asserts. The irony is not lost: this task's whole point was to avoid Task 19's mistake of
    citing that entry without it existing, and I wrote the entry but then left it out of the change
    list.
22. **Finding 6 — the Director's dispatch was paraphrased, not transcribed.** Fixed: `TASKS.md` now
    has a "Director dispatches, transcribed by the Builder" section with the Task 20 dispatch
    verbatim, and row 20 cites it instead of asserting the scope in my own voice. That is also where
    "no Architect design was run" is on the record, with the note that whoever builds the generator
    needs `tools/architect.sh design map-generator` first.

## Round 2's five findings

All five were right. Three were in the note and are fixed in the code commit; two were in this
request and are fixed above. **Round 2 is the Director's limit for this task, so there is no round 3
and these fixes are unreviewed** — `ESCALATE.md` has the entry.

23. **Finding 1 — my fix for round 1's broken references introduced a new broken reference.** I
    pointed source 11 at a "§12" that did not exist. Fixed, and this time **I audited every section
    reference in the file programmatically** against the actual headings rather than fixing only the
    ones I was handed: 13 headings, zero unresolved references. The sections are also back in
    numeric order, which they were not after the insert.
24. **Finding 4 — the decisive finding rested on two unnamed sources.** The strongest of the five.
    The claim that Studio's heightmap import is unreachable leaned on an MCP tool list and some
    community threads, neither of them a numbered source, and the request then made an exhaustiveness
    claim off a list I had printed with an ellipsis. Both are now sources: **§12** records the tool
    list as what it is — a first-hand `tools/list` call made during Task 17, fully enumerated, with
    "not a published source", "StudioMCP is unpinned and can change under us" and "the in-repo record
    is partial" said out loud — and **§13** links the three community threads as corroboration while
    stating that absence of a forum answer proves nothing. The load-bearing evidence is §3.
25. **Finding 5 — the mesh limits were dressed up as first-party.** The numbers table said "Roblox's
    hard import limits" while §9 itself said the figures come from a DevForum thread and a vendor
    page. Fixed where they are used, the same way §6's part counts are.
26. **Finding 2 — the source count was wrong in two more places than the one I fixed.** Fixed above;
    it is 13 now, and claim 2's verification pointer says 1–13 rather than excluding the sources
    added to answer earlier findings.
27. **Finding 3 — the "two table rows" summary survived in the Harness section.** I corrected one
    copy and missed the other, which is the same class of miss as finding 1. Fixed above.

## Harness

**N/A — no code, and Studio is unreachable.** Nothing in this change executes: it is four markdown
files — one new note, plus `ESCALATE.md` (a 47-line entry), `TASKS.md` (row 20 and a ~45-line
transcribed-dispatch section) and one `INDEX.md` row. `rojo serve` has been down since Task 17; the record with the exact clicks is
`ESCALATE.md`, "NEEDS KAREN · `rojo serve` is down; no task can be harness-tested". **I wrote that
entry on this branch as part of this task**, because this branch is cut from `main` and the copies on
`task-17`, `task-18` and `task-19` are all unmerged — so `main` had no record of it. Task 19's review
round 1 caught me citing that entry from a branch where it did not exist, and I checked this time
before writing the claim. Lint, format and `rojo build` are clean and unchanged by this task.

## Could not verify

- **The Creator Store Terms.** <https://en.help.roblox.com/hc/en-us/articles/21308223046932> returned
  **HTTP 403** to me, so I have **not read the primary licence text**. Source 8 rests on the
  `create.roblox.com` docs page's summary of it. The two rules the note draws (never commit an
  asset; keep a manifest) are conservative and hold under any reading, but **if you can reach the
  Terms and they say something different, that is a finding**.
- **`math.noise`'s range and determinism.** The maths-library reference gives the signature
  `math.noise(x, y, z): number` and **nothing else** — no algorithm, no range, no determinism
  guarantee. The note says so and makes it a question for the first task rather than assuming the
  usual −1..1.
- **Whether `resolution` may be anything but 4, and any `ReadVoxels`/`WriteVoxels` region cap.** The
  `Terrain` page uses 4 in examples and states neither. Flagged in source 2 and in the first task.
- **Whether `CollectionService` tags are serialised into the place file.** Not stated on the
  reference page. See claim 6 — this is the highest-consequence unknown in the note.
- **RTerrainGenerator's maintenance status.** MIT, ~45 commits, no archive notice, but I could not
  establish a last-commit date, so the note treats it as unmaintained until proven otherwise rather
  than claiming either way.
- **Every number in the "Numeric targets" table.** They are arithmetic and budgets, not measurements.
  Nothing in this project has run on a phone; the map does not exist; the 3,000-tree and 20,000-part
  figures are budgets to be checked by multiplying what 50 trees actually cost.
- **The part-count figures are DevForum rules of thumb**, not Roblox specifications, and not
  measurements of this map on these devices.
- **No Architect design exists for this system.** The dispatch was research only. Whoever builds the
  generator needs `tools/architect.sh design map-generator` first — the note is input to that, not a
  substitute for it, and it does not assign owners.
- **The `ESCALATE.md` entry's process claims are not checkable from the repo.** That `rojo serve` is
  down and Studio is still in Edit mode are things I verified in this session (no `rojo.exe`, nothing
  on port 34872) and wrote down; the repo cannot confirm them.
- **Four of round 1's six findings were mine to have caught.** The broken section references and the
  unnamed source are exactly the "stated it and did not check it against the thing it cites" failure
  that Task 19 spent two rounds on. The determinism muddle (round 1, finding 1) is worse than a
  citation slip, because it would have been copied into a design.
- **Round 2 then found that two of my round-1 fixes were themselves wrong** — a new broken section
  reference inside the fix for broken section references, and a count corrected in one place but not
  two others. Across Tasks 19 and 20 that is now a consistent pattern: **I fix the instance I am
  shown rather than the class.** The audit in item 23 is the first time I checked the class
  mechanically, and it is what I should have done in round 1.
- **These round-2 fixes are unreviewed.** Two rounds was the Director's limit; see `ESCALATE.md`.

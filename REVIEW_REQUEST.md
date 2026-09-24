# Review request

Written by the Builder for `tools/review.sh`. The format is below; the script parses the first three lines.

Round: 1
Base: `7399585`
Code commit: `fba85c8c091e8143c5bd865367d32aac2fb03d4a`

## Task

TASKS.md #20, ROADMAP Milestone 2: **map generator research note only. No code, no Architect
design** — the Director dispatched research only this time.

The change is one new document plus two table rows. There is no `src/`, no `tests/`, no `tools/`.
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
| `docs/research/2026-09-24-map-generator.md` | the note: 10 sources with licence and maintenance, the numbers and their derivation, the pattern adopted, the smallest first generator task, what needs Karen |
| `docs/research/INDEX.md` | its row |
| `TASKS.md` | row 20 |

## Claims

Files and symbols, not line numbers (CLAUDE.md loop step 4).

1. **The central finding is that Studio's heightmap/colormap import cannot be driven from code or
   MCP, and the note states it plainly as the Director asked.** Verify: the note's source 3. The
   Terrain Editor page describes Import and Generate as Studio UI tools and documents **no scripting
   API** for either; the Studio MCP server's tool list (`execute_luau`, `insert_asset`,
   `search_asset`, `screen_capture`, `generate_*`, `start_stop_play`, `user_*_input`,
   `get_console_output`, …) contains nothing that drives the Terrain Editor. The note draws the
   consequence rather than hedging: the generator computes its own heightfield.
2. **Rule 1 is met in substance: 10 sources, each with a licence and a maintenance status, and each
   with what it does well *and badly for this system*.** Verify: the note's "Sources", headings 1–10.
   First-party Roblox docs (CC BY 4.0) for 1, 2, 3, 4, 5, 9 (the API half) and 10; MIT for
   RTerrainGenerator; DevForum posts cited as figures only for 6 and the mesh limits; and **an
   explicit "could not confirm"** for the Creator Store Terms, which returned HTTP 403.
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
12. **The note ends with the smallest first generator task, as the Director asked, and that task is
    chosen to answer the note's own open questions.** Verify: "The smallest first generator task" — a
    512 × 512 stud slice, two materials, one hedgerow, 50 trees from one asset id, four tagged
    markers, then save-reopen-confirm. The bullets under it map one-to-one onto the things sources 2,
    4 and 10 could not settle.
13. **It notices that Milestone 2 may be the first visual work in this project that can meet rule 5
    without Karen.** The generator runs in **Edit** mode, and `screen_capture` over MCP is Edit-mode
    only — which is exactly why it is useless for Task 7's play-time problem and potentially useful
    here. Verify: "The smallest first generator task", fourth bullet.
14. **Nothing in `src/`, `tests/` or `tools/` changed.** Lint, format and `rojo build` were run
    anyway and pass: `.agent-evidence/lint-selene.txt`, `lint-stylua.txt`, `rojo-build.txt`.
    `GAME_DESIGN.md` is untouched — there is no system yet, so there is no owner to record.

## Harness

**N/A — no code, and Studio is unreachable.** Nothing in this change executes: one markdown document
and two table rows. `rojo serve` has been down since Task 17; the record with the exact clicks is
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

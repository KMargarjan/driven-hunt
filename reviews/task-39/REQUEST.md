# Task 39 — the asset-pipeline research note

Task: 39
Round: 1
Base: `5d93e87`
Code commit: `6f3d617c6769e92da8cfaa3bce42dde7a1a65a03`

**Docs-only task, so exempt from harness-before-review** (`CLAUDE.md`, the loop step 3; the exemption
is implemented in `harness_gate` in `tools/agents.py`). No harness line is pasted because none exists:
nothing under `src/`, `tests/` or `tools/` changed. The commit above is the docs commit — the only
non-paperwork commit in this branch — and `git diff --name-only 5d93e87..6f3d617` is exactly:

```
TASKS.md
docs/research/2026-09-26-asset-pipeline.md
docs/research/INDEX.md
```

## What this task was

Rule 1's research note for the `asset-pipeline` system, which the design's §16 E asks for by name and
flags as unusually load-bearing: the Architect wrote `docs/design/asset-pipeline.md` with **no
network**, so every URL in its §11 was named from memory and never fetched, and the document says so
at the top. The note's job is to **read the pages** and report, source by source, whether the design's
use of each one is right.

**The design was not edited.** It is the Architect's. Everything wrong with it is a numbered item in
the note's `## DESIGN DELTA` section, for the Director.

## What could not be verified, stated first (rule 8)

- **Nothing in the note is measured in the engine.** This was a docs-only session in the
  `driven-hunt-review` worktree: no Studio, no `rojo`, no `tools/studio_mcp.py`, no harness. Every
  engine claim in the note is a **documentation** claim and is labelled as one. The design's
  measurements M1, M2 (reframed by delta D5), M3's second half and M4 all still need the first build
  task, and the note says so in `## What could not be verified`.
- Three facts the note explicitly leaves open rather than guessing: whether free Creator Store models
  are flagged *shared by the asset owner* (the fact delta D9 turns on); whether the 3D Importer
  produces a `SurfaceAppearance` from an FBX's PBR maps; and what the API-key dashboard actually shows
  for an `assets` key on a personal account (delta D11 — a Karen report-back).
- The Meshy/Roblox licence tension (delta D15) is **quoted, not resolved**. The note says plainly that
  it is not legal advice.

## Claims

Nine. Every source citation in the note names a URL and quotes the sentence it rests on, so each claim
is checkable against the note's own text; the pages themselves were fetched live on 2026-09-26 and a
read-only reviewer cannot re-fetch them.

1. **The note exists, covers rule 1's five required parts, and is indexed.**
   `docs/research/2026-09-26-asset-pipeline.md` has: what the system must do; sources with link,
   licence, maintenance, good, bad and a verdict on the design's use of each; the pattern adopted and
   why; numeric targets; and it is one row in `docs/research/INDEX.md`, newest first.
   *Verify:* read the note's headings and the top data row of `INDEX.md`.

2. **Fifteen sources, over rule 1's minimum of three, and every one of the design's §11 sources is
   covered.** The design cites six numbered sources plus Meshy; the note covers all seven and adds
   eight (rate limits, mesh specifications, texture specifications, `MeshPart`/`TriangleMeshPart`, the
   3D Importer, `Content`, CC BY 4.0 + Roblox Creator Terms, Creator Store Terms).
   *Verify:* the note's `## Sources` subheadings against the design's §11 list.

3. **Every source carries a licence line and a maintenance line, and the "first-party vs community"
   marking the dispatch asked for is explicit.** Roblox docs are marked CC BY 4.0 at source
   (`github.com/Roblox/creator-docs`, confirmed via the GitHub API); the two community figures —
   `CreateMeshPartAsync`'s ~22 ms + ~0.27 ms/1k tris and `InsertService:LoadAsset`'s
   error-rather-than-nil behaviour — are labelled **community** in both the source entry and the
   numeric table.
   *Verify:* grep the note for `Licence:` and `Maintenance:`; read the two rows of
   `## Numeric targets` whose basis says "community".

4. **Every delta is a defect in the design, not a disagreement about taste, and each names the design
   section it corrects.** Seventeen, numbered D1–D17, each citing the design §§ it lands on.
   *Verify:* read `## DESIGN DELTA`; spot-check any Dn against the design section it names.

5. **The three deltas marked as changing what gets built are correctly characterised as such.**
   **D5**: the Assets API table says `Mesh` is *"Roblox only … Only Asset delivery API content
   accepted"* and `Model` *"Imports as Model container with MeshPart objects"*, while
   `CreateMeshPartAsync` takes a mesh `Content` — so the design's §5/§11-source-3 "two routes chosen by
   measurement M2" cannot be a coin flip. **D6**: `MeshPart.RenderFidelity` is Access ReadOnly with
   write security `PluginSecurity` and `CollisionFidelity` *"cannot be read or manipulated by scripts
   during runtime"* — so the manifest's `renderFidelity` is not an instruction the Loader can execute.
   **D9**: `AllowInsertFreeAssets` is Access ReadOnly with `RobloxScriptSecurity` on read **and**
   write — so no game script can enable it, which walls off free Creator Store models and contradicts
   `docs/design/map-generator.md` §8.2.
   *Verify:* read D5, D6, D9 and the source entries they point at (sources 1, 6, 7, 8); check that the
   design §5.1/§12.2/§16-Karen-3 and `docs/design/map-generator.md` §8.2 say what the deltas claim
   they say.

6. **Where the design was right, the note says so rather than only listing faults.** Named as correct:
   the endpoint, the `x-api-key` header, the multipart part names `request` and `fileContent`, the
   `type=model/fbx` content type, the request JSON with `creationContext.creator.userId`, operation
   polling, the 20 MB cap, the `Highlight` toggle-a-property-don't-add-remove pattern (now *confirmed*
   by a first-party sentence the design did not have), the `TextureID`-not-`SurfaceAppearance` decision
   (also confirmed, and for a better reason than the design gives), the whole of §8's key discipline,
   and the entire PNG source, which is the only one of the design's §11 entries described without
   error.
   *Verify:* the "Is the design's use right?" line of each source entry, and D7 and D8, which correct
   *towards* the design.

7. **Two of the design's own `[UNVERIFIED]` markers are resolved from documentation, one each way.**
   `MeshPart.TextureID` is Access **ReadWrite** with read and write security **None**, so §6.6
   decision 1 and the first half of measurement M3 are answered **yes**. `SurfaceAppearance` is
   documented as **not** script-modifiable during a game, so §6.6's later-`SurfaceAppearance` plan must
   have it arrive with the asset.
   *Verify:* source 7 and source 10, and delta D7.

8. **Both licences that previous sessions could not read have been read, with the route recorded.**
   Creator Store Terms §License, verbatim: *"By purchasing assets on the Creator Store, User is granted
   a license to use the asset in Roblox Studio and in Experiences on the Services consistent with the
   Roblox User and Creator Terms."* That closes
   `docs/research/2026-09-24-map-generator.md` §8's *"I have not read the primary licence text"*, and
   both rules that note derived (never commit a Creator Store asset; record provenance per row) now
   stand on primary evidence. The `en.help.roblox.com` HTML page is **HTTP 403** to the fetch tool and
   to `curl` with a browser user-agent — confirmed twice this session — and the note records the
   working route (`.../api/v2/help_center/en-us/articles/<id>.json`) so the next session does not lose
   another licence page to it. The note also finds the gap: the grant is written for **purchased**
   assets, so a *free* one is licensed only via the Creator Terms share sentence — **the same flag D9
   turns on**.
   *Verify:* source 15, source 14's last quote, delta D16, and the map note's §8 paragraph that D16
   says can be closed.

9. **The Meshy licence question is answered as far as a document can answer it, and the remainder is
   put to Karen with a recommendation.** Meshy Terms of Use (last updated 19 September 2026; the
   design's `meshy.ai/terms` URL is 404, the live one is `meshy.ai/terms-of-use`) §3.2: on a free plan
   *"Meshy owns all right, title, and interest … in and to the Customer Output"*, granted under CC BY
   4.0; on a paid plan *"customers on a paid Meshy plan own their Customer Output."* CC BY 4.0 §2(a)(1)
   is **non-sublicensable**, while Roblox's Creator Terms require a licence *"with the right to
   sublicense to any person or entity"* and require the Creator be *"the owner of or … fully authorized
   to grant rights in all parts of that UGC"*. The note's recommendation is a paid Meshy plan for
   anything that ships, never posting a Driven Hunt model to Meshy's community page (§3.3 puts those
   under CC0), and it states it is not legal advice.
   *Verify:* source 13, source 14, delta D15, and `## What needs Karen` item 1.

## Not in scope

No code, no design edit, no harness run, no screenshot (nothing visual changed — rule 5 N/A). The note
recommends one small docs task for the four corrections that belong to `docs/research/2026-09-24-map-generator.md`
and `docs/design/map-generator.md`; it does not make them, because they are not this task.

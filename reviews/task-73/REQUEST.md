# Task 73 — upload a prepared asset to Roblox through Open Cloud

Task: 73
Round: 2
Base: `main` (`87a28b6`)
Code commit: `eb73b6d02e52b05b18a794006a09fce91b49dc7b`

```
[harness] PASS: 30/30 checks @ eb73b6d02e52b05b18a794006a09fce91b49dc7b (clean tree)
```

**`test2`: N/A.** Nothing under `src/`, `tests/client/` or `tools/studio_mcp.py` changed — this is
`tools/`, `assets/uploads.json`, `GAME_DESIGN.md`, `CLAUDE.md`, two research files and one CI step.

**Round 1's blocking finding was right and is fixed.** The check named `it refuses an extension
Roblox does not list` asked `find_model` for a `model.obj` that did not exist, so the run stopped at
the missing-file branch and the check passed on the wrong message — deleting the guard it names left
the selftest green. `read_key`'s refusal had no check at all. Both are now exercised and both are
mutation-proved (claim 5). **Nothing was re-uploaded.**

**The upload happened.** Asset **`117134580332969`**, moderation **`Approved`**, creator 8167651842
(Karen), from Task 72's `shotgun_sxs_r2-20260926T213701Z/model.fbx` (13.0 MiB), operation
`operations/b243c2cd-6dab-4e29-bc1d-67ef49288a63`, 9 polls over 20 s. **It is not swapped into the
game** — that is the next task.

## Claims

1. **Research before implementation (rule 1).** `docs/research/2026-09-26-roblox-upload.md`, four
   external sources with licence and maintenance (the Assets guide, the API-keys page, `InsertService`,
   `AssetService` — all CC BY 4.0 docs, all active), standing on the repo's own asset-pipeline note
   rather than re-deriving it. Indexed in `docs/research/INDEX.md`.

2. **The documented moderation string is wrong, and this was measured, not assumed.** The guide
   prints `"moderationState": "MODERATION_STATE_APPROVED"`; the live API returned **`"Approved"`**,
   nested under `moderationResult`. The repo's asset-pipeline note (delta D13) told this project to
   *match on the `MODERATION_STATE_` prefix* — **that would have called an approved asset unknown.**
   `moderation_of` reads both nestings, branches on neither spelling, records what it was handed and
   says which shape it found. Verify: `assets/uploads.json`'s `moderationStateFrom`.

3. **The key is never printed, logged or committed.** Read from the environment then
   `HKCU\Environment` (the two places `tools/meshy.py` reads `MESHY_API_KEY`); `--dry-run` prints
   `x-api-key: <redacted>`; no error path includes it. Verify: the selftest plants a fake key, runs a
   whole mocked upload, and asserts the key is absent from the row **and** from the written manifest —
   and mutating the tool to put it in the row fails both checks.

4. **Karen's OK is an argument, not a flag, and it is recorded verbatim.**
   `--karen-ok "<date + what>"` is required, must carry a date and at least three real words, and is
   stored in the row — so what she approved is answerable from git. The row for this upload reads
   `2026-09-26 Karen approved uploading her shotgun as prepared by Task 72`. A second asset needs its
   own OK. Verify: `check_karen_ok`, and the three refusal checks in the selftest.

5. **Six refusals, each proved by a check that fires on the guard it names, and each
   mutation-proved.** No key (`read_key` run with **both** places it looks stubbed out — an empty
   environ and a registry read returning nothing — and again with the variable present, so the happy
   path is covered too); no or empty `--karen-ok`; an **asset type this tool does not implement**;
   an **extension Roblox does not list** (the fixture writes a real `model.obj`, and the assertion is
   on `"does not list"`, so the missing-file branch cannot satisfy it); a file over 20 MB; and the
   same bytes twice. **Mutations:** removing the extension guard, the key refusal or the asset-type
   guard each fails exactly the check named after it — `it did not refuse`, one check each.

6. **The request is the guide's, part for part, and the content type is now keyed by asset type.**
   `POST https://apis.roblox.com/assets/v1/assets`, multipart with exactly `request` and
   `fileContent`, `creationContext.creator.userId`, content type from the guide's own table. Round 1
   had one flat `Model`-only table that nothing compared against `--type`, so `--type Decal --file
   model.fbx` was accepted and sent as `model/fbx`; `CONTENT_TYPES` is per type now and an
   unimplemented type is a refusal with a reason. **A dry run also reads no key** — it sends nothing,
   so it has no business demanding a password, and the selftest proves it by replacing `read_key`
   with something that raises and running the dry run anyway. Verify: the multipart assertions, `it
   refuses an asset type it does not implement`, and `a dry run needs no key`.

7. **`privacy_scan.py` now fails CI on an Open Cloud key**, which has no prefix to grep for: the rule
   is its **shape** — an unbroken run of 120+ base64url characters. 120 is chosen to clear what is
   legal here: a sha256 digest is 64, a git sha 40, an asset id a dozen. **No real key appears in any
   fixture**: the caught samples are built from expressions (`"A1_b" * 40`), and the ALLOWED list now
   holds the variable name, a digest, a git sha, an asset id and a long URL so none of them can
   regress into a false positive.

8. **Five owner rows are in `GAME_DESIGN.md`, and audit-005 must-fix 1 is only PARTLY closed —
   said plainly.** Added: asset prep, asset upload, the upload record, the **asset manifest** and the
   **id → Instance seam** (the last two marked *designed, not yet built (M2.7a)*, so nothing claims
   to exist that does not), plus the gun's visible model. Must-fix 1 names **three** rows and the
   third — **the boar's visible model** — is **not** written, so it still blocks the boar model swap.
   `TASKS.md` row 73a(a0) says so. `docs/design/map-generator.md` §12.2 still stands: `MapGen.Assets`
   is the only id table and this task adds no second one.

9. **The id is written down where ids belong.** `assets/uploads.json`, one appended row per upload:
   asset id, type, display name, creator, file, sha256, content type, operation, moderation state and
   where it was read from, poll count, and Karen's OK. It is provenance, not an id table: Rojo does
   not sync `assets/`, nothing in `src/` reads it, and it holds no secret. `CLAUDE.md`'s layout table
   and its secrets list both name it.

10. **Selftest 32 checks, offline, mocked HTTP, no key needed — and it runs in CI.** Six mutations
    across the two rounds, each applied, the selftest run, then restored: dropping the Karen-OK
    requirement, recording the key in the manifest (both key checks fail), removing the privacy rule
    (`NOT CAUGHT by roblox-open-cloud-key`, two cases), and this round's three — the extension guard,
    the key refusal and the asset-type guard.

## Not verified

- **Nobody has loaded the asset in Studio.** `InsertService:LoadAsset` requires the `LoadOwnedAsset`
  capability and Karen is both creator and place owner, so it should work — that is an argument, not
  a measurement, and row 67a(b) (nobody has imported a `.glb`) sits beside it. The next task measures
  it.
- **Only one moderation string has ever been seen.** `"Approved"` is measured; `"Rejected"` /
  `"Reviewing"` or the long form are guesses and nothing branches on them.
- **The 120-character privacy rule is a shape, not a signature.** A base64 data URI or a minified
  bundle would trip it. Neither exists in this repo today.
- **The sha256 guard catches the same bytes, not the same model.** A re-exported FBX of the same gun
  would upload again without complaint.
- **The key expires 2026-10-26**; uploads stop that day.
- **There is no `resume <operationPath>`.** The manifest row is written only after a successful poll,
  so an upload whose poll is interrupted leaves a live asset with no row and the sha256 guard will
  not catch the re-run. `docs/design/asset-pipeline.md` §7.7 anticipates it; queued as 73a(h).
- **Two older selftest checks assert less than their names claim** (round 1 notes, queued as 73a(i)):
  the multipart boundary check cannot fail while `multipart` returns its literal format string, and
  `a review state is reported, not retried` holds because the mock returns `done` on the first GET.

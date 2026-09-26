# Task 73 — upload a prepared asset to Roblox through Open Cloud

Task: 73
Round: 1
Base: `main` (`87a28b6`)
Code commit: `b6beafd979c822db7bebb6a14ab6a73278ec0e2e`

```
[harness] PASS: 30/30 checks @ b6beafd979c822db7bebb6a14ab6a73278ec0e2e (clean tree)
```

**`test2`: N/A.** Nothing under `src/`, `tests/client/` or `tools/studio_mcp.py` changed — this is
`tools/`, `assets/uploads.json`, `GAME_DESIGN.md`, `CLAUDE.md`, two research files and one CI step.

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

5. **Five refusals, each proved before anything is sent:** no key; no or empty `--karen-ok`; no model
   file, or an extension Roblox does not list for `Model`; a file over 20 MB (the guide's own limit);
   and **the same bytes twice** — the sha256 is checked against the manifest and `--again` is how a
   deliberate repeat says so.

6. **The request is the guide's, part for part.** `POST https://apis.roblox.com/assets/v1/assets`,
   multipart with exactly `request` and `fileContent`, `creationContext.creator.userId`, content type
   from the guide's own table (`model/fbx`). Verify: the three multipart assertions in the selftest,
   and the `--dry-run` output quoted in `TASKS.md` row 73.

7. **`privacy_scan.py` now fails CI on an Open Cloud key**, which has no prefix to grep for: the rule
   is its **shape** — an unbroken run of 120+ base64url characters. 120 is chosen to clear what is
   legal here: a sha256 digest is 64, a git sha 40, an asset id a dozen. **No real key appears in any
   fixture**: the caught samples are built from expressions (`"A1_b" * 40`), and the ALLOWED list now
   holds the variable name, a digest, a git sha, an asset id and a long URL so none of them can
   regress into a false positive.

8. **The owner rows audit-005 must-fix 1 asked for are in `GAME_DESIGN.md`**: asset prep, asset
   upload, the upload record, the **asset manifest** and the **id → Instance seam**. The last two are
   marked **designed, not yet built (M2.7a)**, so nothing claims to exist that does not, and
   `docs/design/map-generator.md` §12.2 still stands — `MapGen.Assets` is the only id table and this
   task adds no second one.

9. **The id is written down where ids belong.** `assets/uploads.json`, one appended row per upload:
   asset id, type, display name, creator, file, sha256, content type, operation, moderation state and
   where it was read from, poll count, and Karen's OK. It is provenance, not an id table: Rojo does
   not sync `assets/`, nothing in `src/` reads it, and it holds no secret. `CLAUDE.md`'s layout table
   and its secrets list both name it.

10. **Selftest 28 checks, offline, mocked HTTP, no key needed — and it runs in CI.** Three mutations,
    each applied, the selftest run, then restored: dropping the Karen-OK requirement (`it refuses with
    no Karen OK at all` fails), recording the key in the manifest (both key checks fail), and removing
    the privacy rule (`NOT CAUGHT by roblox-open-cloud-key`, two cases).

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

# Design: meshy-tool (`tools/meshy.py`) and the ASSET agent

System: **`meshy-tool`** — the one program that talks to Meshy, and the fifth role that operates it.
It turns a written brief (text, and optionally 1–4 reference images) into a downloaded FBX plus PNG
maps in Karen's drop folder, with a licence basis and a provenance record, and hands off to
`tools/assets.py` (`docs/design/asset-pipeline.md` §7). It is the **supply** end of the pipeline whose
**delivery** end is already designed.

Architect, 2026-09-26, read-only session: Read, Grep, Glob only. No Studio, no network, no engine, no
shell. Evidence precomputed in `.agent-evidence/` (`INDEX.md`), commit
`9c4ca8c7c0ee84b20b496cc18821ef55e2da583d`.

Inputs, in precedence order: **`reviews/task-53/BRIEF.md`** (the Director's, green-lit by Karen
2026-09-26; it overrides anything older), `docs/design/asset-pipeline.md` (which already owns the
manifest, the sidecar, the drop dir and the upload), `docs/research/2026-09-26-asset-pipeline.md` (the
citation of record for both licence documents), `CLAUDE.md`, `docs/PROJECT_CONTEXT.md`, `ROADMAP.md`
speed rules, `GAME_DESIGN.md` owners, and the code at this commit.

**Test of this document:** a Builder can build the first task from it without asking a question, and
no sentence in it invents a Meshy API string. Every API shape below is labelled with where it came
from, and §10.1 lists exactly what the research note must confirm before code is written.

---

## 0. Six facts this design is built on

1. **I could not fetch anything.** This session has Read, Grep and Glob (`tools/agents.py`,
   `run_agent`: `--restricted --tools Read,Grep,Glob`). Every Meshy API fact here comes from
   `reviews/task-53/BRIEF.md`, which says the Director checked it against the official docs on
   2026-09-26 and that **the research note must re-fetch and quote them**. Rule 1 therefore still
   applies in full: `docs/research/<date>-meshy.md` is written and indexed **before** any code
   (`CLAUDE.md` rule 1). §10.1 is the list of strings that note must nail down.
2. **Nothing in this repo ever parses geometry.** `docs/PROJECT_CONTEXT.md`, "Invented foundations":
   *"Cutting a mesh into pieces, a hand-written FBX reader … Each produced a run of bugs."*
   `docs/design/asset-pipeline.md` §0 item 1 already binds this pipeline to it. So the brief's "local
   validation (triangle count …)" is **not** implemented by reading the FBX: see §7.3 and §15 Director C.
3. **A Meshy result is not reproducible.** The brief: *"no seed (not reproducible)"*. There is no
   rerun that returns the same boar. The downloaded bytes are therefore the artefact of record, they
   are never deleted (rule 7), and provenance (prompt text, task ids, sha256) replaces reproducibility.
4. **Meshy deletes the API output after 3 days.** The brief. So download is not a later step that can
   be batched: `fetch` runs in the same session as the task that produced the URLs, the run record
   carries an `expiresAt`, and `runs` prints an expired run in capitals (§8).
5. **A `--allowedTools` Bash allow-list is not enforced in this environment.** `tools/agents.py`
   module docstring, "How read-only is enforced", item 1: *"A plain `--allowedTools` Bash allow-list
   was NOT enforced in this environment (a test session created a file through Bash anyway)"*. So the
   ASSET agent **cannot be sandboxed by a tool list**. Its limits are: what `tools/meshy.py` refuses
   to do (real), the credit/task ceilings inside it (real), the fact that the Roblox key is a
   different variable it never reads (real), and its prompt (policy). §9.4 says which is which, in the
   shape of `CLAUDE.md`'s "What is enforced and what is policy".
6. **The delivery half does not exist yet.** `.agent-evidence/ls-files.txt` has no `tools/assets.py`
   and no `src/serverstorage/Assets/`; the only manifest on disk is
   `src/serverstorage/MapGen/Assets.luau`, whose own header says *"THE ASSET MANIFEST. Pure data,
   frozen, and EMPTY on purpose"*, and which `docs/design/asset-pipeline.md` §15 D1 deletes. So the
   handoff target is unbuilt, and that decides the build order in §14: the **preview half** of this
   system has no dependency on it and is the smallest first task; the **promote half** imports from
   `tools/assets.py` and lands after M2.7a.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. **Turn one written brief into one preview, and stop.** Text and/or 1–4 reference images in, a
   preview task out, a preview image on disk that Karen can look at, and the session ends (§3, §6).
2. **Take Karen's OK as a separate, recorded step**, and never refine without it (§6.3).
3. **Refine, remesh and download in one unbroken command chain**, because the output dies in 3 days
   (§0 item 4).
4. **Record provenance per asset**: the brief text verbatim, every Meshy task id, the credits each
   task cost, the sha256 of every downloaded byte-stream, and the licence basis with its quote (§4.2).
5. **Write the sidecar `tools/assets.py` already expects**, with `licenceBasis = "meshy-paid-owned"`,
   so the handoff is a file the next tool validates rather than a conversation (§4.3).
6. **Keep `MESHY_API_KEY` out of the repo, the run records, the logs, the terminal and the report**
   (§6.1, §7).
7. **Be loud on every failure**: 429, task `FAILED`, an expired signed URL, a 3-day deletion, a
   ceiling hit (§8).
8. **Be reviewable and testable with no key and no network**: `selftest` plus `--dry-run` on every
   network command (§12).
9. **Spend nothing by accident.** A per-run task ceiling and a per-day task ceiling, enforced in the
   tool, not in a habit (§11).

### 1.2 Must not

| Prohibition | Why | Whose job instead |
|---|---|---|
| Never read or write geometry (FBX, OBJ, GLB) | `docs/PROJECT_CONTEXT.md` "Invented foundations"; `docs/design/asset-pipeline.md` §0 item 1 | Meshy's `remesh` sets the triangle target; Roblox's importer enforces *"Individual meshes can not exceed 20,000 triangles"* |
| Never write anything under `src/`, `tests/`, `tools/` or `docs/design/` | `CLAUDE.md` role table: the **Builder** is *"the only writer of code in `src/`, `tests/`, `tools/`"*; the Architect owns `docs/design/` | the Builder, from the row this tool printed (§9.2) |
| Never call the Roblox Open Cloud API, and never read `DRIVEN_HUNT_ROBLOX_API_KEY` | one key per tool: a compromise of one must not be a compromise of both. `docs/design/asset-pipeline.md` §2.1 makes `tools/assets.py` *"the only holder of an Open Cloud key and the only authenticated caller of `apis.roblox.com` in the repo"* | `tools/assets.py` |
| Never touch `tools/studio_mcp.py`, Studio, Rojo, the harness or the sync token | `docs/design/asset-pipeline.md` §0 item 2: the file that decides whether a PR may be reviewed must not also hold a key. This one holds a *second* key | the harness, unchanged |
| Never post, publish or share a model on Meshy's community page, and never call any endpoint that does | Meshy Terms §3.3: anything posted to the community page goes out as **CC0 1.0** (`docs/research/2026-09-26-asset-pipeline.md` source 13) | nobody. The endpoint is on the forbidden list in the prompt (§9.3) |
| Never claim `licenceBasis = "own-work"` for a Meshy model | `own-work` in `docs/design/asset-pipeline.md` §4.5 means *"Karen modelled it herself, no generator involved"*. The brief's phrase *"own work, paid Meshy plan"* is the **enum value `meshy-paid-owned`** plus its quote, not the `own-work` enum | `meshy-paid-owned`, quote from Terms §3.2 |
| Never write a file inside the repository that holds an asset id, a licence or a key | one home for ids and licences: `docs/design/asset-pipeline.md` §4.2, and §15 D5 there deletes the second home `assets/ready/README.md` invited | the manifest, via the Builder |
| Never download into the repository, and never accept a drop dir inside it | `docs/design/asset-pipeline.md` §7.2: *"A source tree that can be uploaded from is a source tree someone commits"* | `ASSET_DROP_DIR`, refused if it resolves inside the repo |
| Never retry a failed generation automatically | a retry costs credits and cannot reproduce the same model (§0 item 3). A silent retry loop is a bill | the operator, with one explicit command |
| Never delete a run directory, a download or a superseded preview | rule 7 | `runs --prune` does not exist; archiving is Karen's, outside the repo |
| Never use Meshy's rigging | the brief: *"rigging is humanoid-only (not for the boar)"* | out of scope; boar animation is `docs/design/asset-pipeline.md` §14 M2.7e |
| Never send `art_style`, `negative_prompt` or `symmetry` | the brief: deprecated | the prompt text and the reference images carry the intent |

**One predicate answers one question.** `meshy.py status` answers "what is the state of this run at
Meshy and on disk", and nothing else. It does not answer "is this model good" (Karen), "is this file
uploadable" (`tools/assets.py validate`), "is this key current in the game" (`Assets.byKey`), or "does
the boar look right in the place" (a screenshot, `docs/design/asset-pipeline.md` §13.4). The previous
project's worst bug was one predicate answering two questions (`docs/PROJECT_CONTEXT.md`: *"mounting
hid both the crosshair and the weapon"*).

---

## 2. Ownership

Rule 3: one writer per system, named. Two rows of this table are new owners; the rest are named so it
is visible that they are **not** taken over.

### 2.1 Owner table (paste into `GAME_DESIGN.md` when the first task lands)

| System | Owner (the only writer) | Location on disk |
|---|---|---|
| **Meshy generation**: the only holder of `MESHY_API_KEY` and the only caller of `api.meshy.ai` in the repo. The only writer of the run directory, the preview image, the downloads and the Meshy-sourced sidecar | **`tools/meshy.py`** | `tools/meshy.py` (Builder-written, per `CLAUDE.md`) |
| **Asset production runs**: which brief is in flight, what Karen said about a preview, which run produced which file, what it cost | **the ASSET agent**, operating `tools/meshy.py`, writing **one file in the repo**: `reviews/task-<N>/ASSET_RESULT.md` | `docs/ASSET_PROMPT.md` (its brief), `reviews/task-<N>/ASSET_RESULT.md` (its report) |
| Upload and validation, the Open Cloud key, the printed manifest row | **unchanged: `tools/assets.py`** (`docs/design/asset-pipeline.md` §2.1). `meshy.py` calls no Roblox API and holds no Roblox key | `tools/assets.py` |
| The asset manifest and the licence quarantine | **unchanged: `ServerStorage.Assets`, edited by the Builder** (`docs/design/asset-pipeline.md` §2.1: *"the Builder edits the file from what `tools/assets.py` printed, and git records it"*) | `src/serverstorage/Assets/` |
| The test gate and the harness | **unchanged: `tools/studio_mcp.py`** (`GAME_DESIGN.md`, test-gate row). Nothing here touches it | `tools/studio_mcp.py` |
| The drop folder's contents for non-Meshy assets (`own-work`, Creator Store) | **unchanged: Karen** | `<assets-dir>` |

### 2.2 The one file the ASSET agent writes in the repo, and why it is not the manifest

The brief lists *"the asset manifest rows"* among what the ASSET agent may write, and asks for that to
be reconciled with `docs/design/asset-pipeline.md`, which already owns the manifest. **The
reconciliation: the ASSET agent authors the row *text*; the Builder authors the *file*.**

- `src/serverstorage/Assets/init.luau` is linted Luau under `src/`. `CLAUDE.md`'s role table makes the
  Builder the only writer there, CI runs `selene src` and `stylua --check src tests`, and
  `docs/design/asset-pipeline.md` §7.5 already decided that *"`tools/assets.py` never writes a file
  under `src/`"* for exactly this reason.
- A second writer of the manifest is failure #3 in `docs/PROJECT_CONTEXT.md` ("Overlapping owners"),
  and the manifest is the file the whole game's art provenance rests on.
- So `reviews/task-<N>/ASSET_RESULT.md` carries the row, verbatim, in a fenced block, exactly as
  `tools/assets.py record|upload` printed it. The Builder pastes it, commits it, and the diff is
  reviewable as a diff. **Nothing is lost:** the facts come from the ASSET agent's run, and the report
  is paperwork the merge gate already allows (`CLAUDE.md` git workflow step 4: *"anything under
  `reviews/`"*).

This is a narrowing of one brief line, with a named reason, not a refusal of it. If the Director wants
the ASSET agent writing `src/` directly, that is §15 Director B — one decision, and it does not block
the first task, which never reaches the manifest.

### 2.3 The fifth role, for `CLAUDE.md`

Paste this row into the **Roles** table in `CLAUDE.md` (Builder's edit; `CLAUDE.md` is the Builder's
file per the role table):

| Role | Owns | Writes | Never |
|---|---|---|---|
| **ASSET** (`docs/ASSET_PROMPT.md`) | asset production: one brief → preview → Karen's OK → refine → remesh → download → validated files in `<assets-dir>` | `reviews/task-<N>/ASSET_RESULT.md`; files under `<assets-dir>` and `<runs-dir>` through `tools/meshy.py` | touches `src/`, `tests/`, `tools/`, `docs/design/`, `docs/architecture/`, any verdict file, `TASKS.md`, Studio, Rojo, the harness or git. Never commits, never merges, never uploads to Roblox, never refines without Karen's recorded OK |

And one line in `CLAUDE.md`'s "Public repository" / toolchain area: `tools/meshy.py` is the second and
last credential path in the repo; its variable is `MESHY_API_KEY`; it is never in CI; it is never the
same variable as `DRIVEN_HUNT_ROBLOX_API_KEY`.

---

## 3. The flow, with both stop points drawn

```
 Karen                     the ASSET agent + tools/meshy.py                 Meshy            Roblox
 ─────                     ────────────────────────────────                ─────            ──────
 writes a brief ─┐
 drops 0-4 refs  │
                 ▼
   <assets-dir>/briefs/boar.body_v1.brief.json  (+ ref .png)
                 │  meshy.py brief   validate only, no network
                 │  meshy.py preview ─── POST /openapi/v2/text-to-3d  mode=preview ──────►
                 │                   ─── GET  /openapi/v2/text-to-3d/:id  (poll)    ──────►
                 │                   ◄── thumbnail + preview model (signed URLs)
                 ▼
   <runs-dir>/boar.body_v1-<utc>/preview.png     the ASSET agent READS this image and says
                 │                               what it sees; report written; SESSION ENDS
   ═══════════ STOP 1: KAREN LOOKS AT preview.png AND SAYS YES OR NO ═══════════
                 │  meshy.py approve <run-id>            (the operator's command; §6.3)
                 │  meshy.py refine  <run-id>  ── POST … mode=refine (2K, PBR) ─────────►
                 │  meshy.py remesh  <run-id>  ── POST /openapi/v1/remesh
                 │                                  topology=triangle, target_polycount ─►
                 │  meshy.py fetch   <run-id>  ── GET the signed URLs NOW (3-day window)
                 │  meshy.py promote <run-id>  ── local validation, then write:
                 ▼
   <assets-dir>/boar.body_v1.fbx
   <assets-dir>/boar.body_v1_albedo.png
   <assets-dir>/boar.body_v1.json      ← the sidecar tools/assets.py §7.3 validates
                 │
   ═══════════ STOP 2: THE OPERATOR RUNS THE UPLOAD (not the ASSET agent; §15 Director A) ══
                 │  python tools/assets.py validate     (the ASSET agent may run this: no key)
                 │  python tools/assets.py upload       (Karen or the Director) ────────────►
                 ▼
   reviews/task-<N>/ASSET_RESULT.md  ← the printed manifest row, verbatim
                 │
                 ▼  the BUILDER pastes it
   src/serverstorage/Assets/init.luau   (docs/design/asset-pipeline.md §4)
```

Nothing crosses that diagram sideways. Meshy never sees a Roblox key; Roblox never sees a Meshy key;
the repo never sees either; the manifest is written by one role.

---

## 4. The three file contracts

All three are JSON, all three live outside the repo, all three are validated before anything is sent.
Types are written as TypeScript-ish records because these are JSON, not Luau.

### 4.1 The brief — Karen's (or the Director's) input

`<assets-dir>/briefs/<key>_v<N>.brief.json`. The name reuses
`docs/design/asset-pipeline.md` §4.3's grammar unchanged (`key ::= segment ("." segment)*`,
`segment ::= [a-z][a-z0-9]*`), so the key and version are **derived from the file name and never
prompted** — the same rule, and the same reason: *"a typo there becomes a manifest row and an asset on
Roblox that cannot be renamed."*

```jsonc
{
  "key": "boar.body",          // must equal the name's derived key; a mismatch is refused
  "version": 1,                // must equal the name's derived version
  "kind": "meshpart",          // asset-pipeline §4.1 Kind; "meshpart" means ONE mesh (Merge Meshes)
  "prompt": "A European wild boar, adult male, ...",   // verbatim, recorded forever (§0 item 3)
  "references": ["boar_ref_side.png", "boar_ref_head.png"],  // 0-4 file NAMES in briefs/, never paths
  "sizeMetres": [0.56, 0.84, 1.54],   // real-world size; the sidecar converts at 1 stud = 0.28 m
  "targetTris": 6000,          // optional; default = REMESH_TARGETS[key] (§11, §15 Director C)
  "texturePx": 2048,           // optional; what refine is expected to deliver (§15 Director D)
  "notes": "sides must read light: TASKS.md row 18 and row 24 both lost a round to a dark albedo"
}
```

Refusals, before any request: name off-grammar; `key`/`version` disagreeing with the name; `prompt`
empty; more than 4 references; a reference missing from `briefs/`; a reference that is not a PNG (one
format per job, as `docs/design/asset-pipeline.md` §7.3 item 3); `sizeMetres` absent; `targetTris`
above `REMESH_CEILING`; `kind` not in the manifest's enum.

**Which endpoint is chosen is data, not a flag**: 0 references → text-to-3D
(`POST /openapi/v2/text-to-3d`); exactly 1 → image-to-3D (`POST /openapi/v1/image-to-3d`); 2–4 →
multi-image (`POST /openapi/v1/multi-image-to-3d`). All three endpoints are from the brief, to be
re-quoted by the research note (§10.1).

### 4.2 The run record — `tools/meshy.py`'s own state, and the provenance of record

`<runs-dir>/<run-id>/run.json`, where `run-id = "<key>_v<N>-<utcYYYYMMDDTHHMMZ>"`. Written only by
`tools/meshy.py`; append-only in spirit (a new phase adds a `tasks[]` entry, nothing is rewritten
except `state`).

```jsonc
{
  "runId": "boar.body_v1-20260926T1412Z",
  "key": "boar.body", "version": 1,
  "brief": { /* the whole brief object, copied verbatim */ },
  "briefSha256": "…64 hex…",           // the brief file's bytes: which brief made this model
  "endpoint": "text-to-3d",            // which of the three §4.1 chose
  "state": "preview-ready",            // §4.4
  "tasks": [
    { "phase": "preview", "taskId": "0195…", "status": "SUCCEEDED",
      "createdAt": "2026-09-26T14:12:04Z", "finishedAt": "2026-09-26T14:18:31Z",
      "credits": 5, "creditsSource": "api",      // "api" | "unknown"; never a guess (§11)
      "expiresAt": "2026-09-29T14:18:31Z",       // finishedAt + 3 days (the brief's fact)
      "artefacts": [ { "name": "preview.png", "sha256": "…", "bytes": 148236 },
                     { "name": "preview.glb", "sha256": "…", "bytes": 2214096 } ] }
  ],
  "approval": null,                    // §6.3 fills it
  "licence": { "basis": "meshy-paid-owned",
               "quote": "customers on a paid Meshy plan own their Customer Output.",
               "quotedFrom": "https://www.meshy.ai/terms-of-use",
               "readOn": "2026-09-26" },
  "totals": { "tasks": 1, "credits": 5 }
}
```

**No URL is ever stored as a reference.** A signed URL expires; the run record keeps the **task id**,
and a fresh URL is minted by re-polling `GET …/:id` (§8). This is the difference between a pipeline
that works on day 2 and one that 404s.

### 4.3 The sidecar — the handoff, and a file `tools/assets.py` already validates

`meshy.py promote` writes `<assets-dir>/<key>_v<N>.json` with exactly the fields
`docs/design/asset-pipeline.md` §7.3 item 2 lists: `source`, `creator`, `licenceBasis`, `licenceQuote`,
`licenceQuotedFrom`, `licenceReadOn`, `trisDeclared`, `sizeMetres`, optional `offsetStuds`,
`rotationDeg`, `notes`. Filled as:

| Field | Value | Basis |
|---|---|---|
| `source` | `"meshy"` | `asset-pipeline` §4.1 `Source` |
| `creator` | `MESHY_CREATOR` env, else `"Karen (Meshy)"` | a name, never an email — `tools/privacy_scan.py` rule `email` would fail the commit if it ever reached the repo, and this file never does |
| `licenceBasis` | `"meshy-paid-owned"`, and **never anything else from this tool** | the brief: Karen is on a PAID plan and owns the output |
| `licenceQuote` | *"customers on a paid Meshy plan own their Customer Output."* | Terms §3.2, quoted in `docs/research/2026-09-26-asset-pipeline.md` source 13 |
| `licenceQuotedFrom` / `licenceReadOn` | `https://www.meshy.ai/terms-of-use` / the date the research note read it | same source; the note records *"last updated 19 September 2026"*, so the date matters |
| `trisDeclared` | the `target_polycount` the remesh task was **sent** | declared, not measured (§0 item 2, §7.3) |
| `sizeMetres` | the brief's | `asset-pipeline` §6.1 converts at 1 stud = 0.28 m |
| `notes` | run id, task ids, prompt sha256 | §0 item 3: provenance replaces reproducibility |

**One writer per sidecar:** for a key produced by `meshy.py`, `meshy.py` is the only writer of that
sidecar and `tools/assets.py` only reads it (`docs/design/asset-pipeline.md` §7.3). For an `own-work`
or Creator Store key, `tools/assets.py init` writes the stub and Karen fills it, exactly as today.
`meshy.py promote` **refuses to overwrite an existing sidecar** and tells the operator to bump the
version, because the manifest is append-only (`asset-pipeline` §4.4).

### 4.4 Run states (the whole state machine; one owner writes it)

`brief-ok → preview-running → preview-ready → approved → refine-running → refine-ready →
remesh-running → remesh-ready → fetched → promoted`, plus two terminals: `failed` (a Meshy task came
back `FAILED`, or a ceiling stopped the run) and `expired` (now > the newest task's `expiresAt` and
`fetched` was never reached). Every command states the transition it requires and refuses any other
transition by name — `refine` on a `preview-running` run prints
`[meshy] REFUSED: run is preview-running, not approved`, not a stack trace.

---

## 5. Public interface — `tools/meshy.py`

Plain Python 3, **stdlib only** (`urllib.request`, `json`, `hashlib`, `os`, `time`, `winreg`), matching
`tools/studio_mcp.py`, `tools/assets.py` (designed) and `tools/privacy_scan.py`. No `requests`, no
SDK, no `meshy-cli`: a third-party dependency in the one program holding a secret is a supply-chain
surface for no gain (`docs/design/asset-pipeline.md` §7 makes the same call for the same reason; and
see §10 source 2 for what is borrowed from the official CLI instead — its request shapes, not its code).

```
python tools/meshy.py key                                  # set / not set + fingerprint. Never the key
python tools/meshy.py brief <key>_v<N>                     # validate the brief; print what would be sent
python tools/meshy.py preview <key>_v<N> [--dry-run]       # create + poll + download preview.png/.glb
python tools/meshy.py status [<run-id>]                    # local records, and one GET per live task
python tools/meshy.py approve <run-id> --by karen [--note] # record Karen's OK (§6.3)
python tools/meshy.py refine <run-id> [--dry-run]          # REFUSED without an approval; 2K PBR
python tools/meshy.py remesh <run-id> [--target <n>]       # topology=triangle, target_polycount
python tools/meshy.py fetch <run-id>                       # download NOW; verify bytes; record sha256
python tools/meshy.py promote <run-id>                     # validate, then write the drop-dir files
python tools/meshy.py runs                                 # every run: state, age, expiry, credits
python tools/meshy.py resume <run-id>                      # continue a poll that was interrupted
python tools/meshy.py selftest                             # offline: validators, builders, parsers
```

- **`--dry-run`** on `preview`, `refine` and `remesh` does everything except the HTTP call and prints
  the exact request it would send, with `Authorization: Bearer ***`. So the whole tool is reviewable
  with no key and no network (`docs/design/asset-pipeline.md` §7.1 sets this precedent).
- **Exit codes**, the harness's shape (`tools/studio_mcp.py`, `tools/privacy_scan.py`): **0** done ·
  **1** failed · **2** refused (key unset, dirs unset or inside the repo, validation refused before
  any request, a wrong run state, a ceiling).
- **The last line is always machine-readable**, prefix `[meshy]`, one of:
  `[meshy] OK: preview boar.body v1 run=<run-id> credits=5 (expires 2026-09-29T14:18Z)` ·
  `[meshy] PENDING: <run-id> preview IN_PROGRESS 42% (re-run: meshy.py resume <run-id>)` ·
  `[meshy] FAILED: <run-id> refine FAILED — <task_error.message>` ·
  `[meshy] REFUSED: <reason>`. This is the line the ASSET agent pastes into its report and the line a
  Reviewer checks, exactly as `[harness]` and `[assets]` lines are used today.

**There is no `generate` that does everything.** One command per phase, because the stop point between
preview and refine is the whole point of the design (§6.3), and because a single command that spends
three tasks' credits before anyone looks is the *"big multi-item rounds hid failures"* failure in
`docs/PROJECT_CONTEXT.md`.

---

## 6. The key, the environment, and Karen's OK

### 6.1 `MESHY_API_KEY`

- Read **once**, into a local, from `os.environ`. Never logged, never printed, never in an exception
  message, never in `run.json`, never in the report. Every request's headers are redacted before any
  print (`docs/design/asset-pipeline.md` §8.4, same rule, same tool shape).
- **Registry fallback, per the brief:** when the variable is absent from the process environment,
  read `HKEY_CURRENT_USER\Environment` with the stdlib `winreg` (`OpenKey` + `QueryValueEx`), because
  a shell started before Karen created the variable does not have it. Read-only; the tool never writes
  the registry. Not Windows → the fallback is skipped and the printed reason says so. The value read
  from the registry is treated exactly like the environment one: never printed.
- `python tools/meshy.py key` prints one of
  `[meshy] MESHY_API_KEY: not set (see docs/design/meshy-tool.md section 6)` or
  `[meshy] MESHY_API_KEY: set, fingerprint 7ab31c04, source=environment|registry` — the first 8 hex of
  its SHA-256. Enough to tell "did the variable change", not invertible.
- Auth header: `Authorization: Bearer msy_…` (the brief). **`tools/privacy_scan.py` gains one rule**
  for that shape (§13 D3), so a pasted key in a report or a research note fails CI instead of being
  published. That tool's existing rules do not cover it: `RULES` names `local-path`, an email rule,
  private keys, `.ROBLOSECURITY`, AWS/GitHub/Slack/`sk-` and `api_key = "…"`, and a bearer token
  called `msy_…` matches none of them.
- If it leaks: revoke it in the Meshy dashboard first, then tell Karen (`CLAUDE.md`: *"revoke or
  rotate it first"*). Removing it from history does not un-publish it, and history is not rewritten
  (Director, 2026-09-26).

### 6.2 The other variables

| Variable | Meaning | Default |
|---|---|---|
| `MESHY_API_KEY` | the key | none; unset ⇒ exit 2 |
| `ASSET_DROP_DIR` | Karen's drop folder, **outside the repo** | none; unset or inside the repo ⇒ exit 2 (`asset-pipeline` §7.2, unchanged) |
| `MESHY_RUN_DIR` | where run records and downloads live | `<ASSET_DROP_DIR>/meshy-runs` |
| `MESHY_CREATOR` | the name written into the sidecar's `creator` | `"Karen (Meshy)"` |

`briefs/` is `<ASSET_DROP_DIR>/briefs`. **No absolute local path appears in this document, in the
tool's output, or in any run record**: paths print as `<assets-dir>`, `<runs-dir>`, `<brief>`, and file
**names** only — `tools/privacy_scan.py`'s `local-path` rule is CI, and Task 49 exists because nine of
them got in.

### 6.3 Karen's OK: the stop that the money and the taste both need

The preview is the cheap artefact and the only one anybody can judge. `docs/PROJECT_CONTEXT.md`: *"The
agent verified its own work with numbers and never looked… purple untextured legs."*

1. `meshy.py preview` downloads **`preview.png`** (the task's thumbnail) and `preview.glb`, and prints
   the path as `<runs-dir>/<run-id>/preview.png`.
2. **The ASSET agent opens `preview.png` with Read and writes what it sees** in its report — shape,
   proportions, whether it is a boar and not a pig, whether the sides read light (`TASKS.md` rows 18
   and 24 both lost time to a dark albedo). An agent looking at the image is not a substitute for
   Karen; it is the cheapest way to catch the obviously-wrong one before she is asked.
3. **The session ends there.** The report's last section is `## Needs Karen`, with the one question and
   the file to open.
4. Karen says yes or no. `meshy.py approve <run-id> --by karen [--note "…"]` writes
   `approval.json` = `{ "by": "karen", "at": "<utc>", "previewSha256": "…", "note": "…" }` and moves
   the run to `approved`. `refine` refuses any run without it, naming the state.

**Honest about what this enforces** (§0 item 5): the *state gate* is enforced in the tool; *who typed
`approve`* is not, because the agent has a shell. What is enforced against the real risk — money — is
§11's ceilings, and what makes a fake approval visible is that `approval.json` and the report both go
into the record. This is the same honesty `CLAUDE.md` applies to the round counter: *"It is not
tamper-proof… See 'What is enforced and what is policy'."*

---

## 7. What each phase sends, and what it must not assume

Every endpoint, parameter name and value below is **from `reviews/task-53/BRIEF.md`** and must be
re-quoted by the research note before code is written (§10.1). Where the brief does not give a name,
this design does **not** invent one: it says "the field the research note names".

### 7.1 Preview

`POST /openapi/v2/text-to-3d` with `mode: "preview"` (text), or `POST /openapi/v1/image-to-3d`, or
`POST /openapi/v1/multi-image-to-3d` (1–4 images). Body carries the brief's `prompt` and/or the
reference images as the endpoint requires. **Not sent:** `art_style`, `negative_prompt`, `symmetry`
(deprecated, per the brief), any rigging option (humanoid-only, per the brief), any seed (there is
none). Poll `GET …/:id` every `POLL_INTERVAL_S` until the status is the documented success value.

**The status parser matches on the success value and treats every other value as not-success**, the
same pattern `docs/design/asset-pipeline.md` §7.4 step 5 adopted for `MODERATION_STATE_*` after Task
37 keyed on two invented spellings: *"hard-coding two strings is how a rejected asset quietly reads as
fine."*

### 7.2 Refine and remesh

- Refine: the same v2 text-to-3D endpoint with `mode: "refine"` and the preview task's id, producing
  2K PBR maps (the brief). Whether the resolution is a parameter at all is §10.1 item 4.
- Remesh: `POST /openapi/v1/remesh` with `topology: "triangle"` and
  `target_polycount: <REMESH_TARGETS[key]>` (the brief). Triangles, because Roblox counts triangles
  (*"Individual meshes can not exceed 20,000 triangles"*, `docs/design/asset-pipeline.md` §11 source 4).

### 7.3 Fetch and local validation — what it can and cannot check

`fetch` runs in the same command chain as the task that produced the URLs, re-polls `GET …/:id` to
mint fresh ones, downloads **FBX** plus the PNG maps, and records `bytes` and `sha256` for each. GLB
and OBJ are downloaded to the run dir when the response offers them (rule 7: keep what was produced),
but **only the FBX is promoted**, because `docs/design/asset-pipeline.md` §7.3 item 3 accepts `.fbx`
and `.png` and refuses the rest — *"one format per job, so there is no 'which of five paths did this
take' later."*

`promote` then validates, reusing the delivery half's implementations rather than copying them
(`tools/meshy.py` imports them from `tools/assets.py`; two copies of a validator is
*"two correct pieces of code disagreeing"*):

| Check | How | Verdict if it fails |
|---|---|---|
| File name and key grammar | `asset-pipeline` §4.3, imported | refuse |
| PNG dimensions ≤ the key's `texturePx` budget | the 8-byte signature plus the IHDR width/height at fixed offsets — **24 bytes, no library** (`asset-pipeline` §7.3 item 5) | refuse, print both numbers |
| FBX size ≤ 20 MB | Roblox's documented per-call cap (`asset-pipeline` §12.2) | refuse |
| Bytes are non-empty and the sha256 matches what was downloaded | `hashlib` | refuse; a truncated download is the 3-day trap's cruellest form |
| **Triangle count** | **NOT measured.** `trisDeclared` is the `target_polycount` that was sent. If the research note finds a polycount/statistics field in the remesh response (§10.1 item 5), assert `reported ≤ target` and record both | refuse only on the *reported* number; never on a parsed one |
| Sidecar does not already exist | append-only manifest (`asset-pipeline` §4.4) | refuse, ask for `_v<N+1>` |

**Stated plainly, because the brief asked for a triangle-count validation:** there is no honest local
triangle count without an FBX parser, and an FBX parser is one of the three named causes of death of
the previous project (`docs/PROJECT_CONTEXT.md`). The number is declared, Meshy is the one that
remeshes to it, and Roblox's importer is the enforcer. See §15 Director C.

---

## 8. Failure modes, and how each is loud

| Failure | What the tool does |
|---|---|
| `MESHY_API_KEY` unset (and absent from `HKCU\Environment`) | **exit 2**, names the variable and §6. Never prompts, never reads stdin: a typed key lands in the shell's scrollback (`asset-pipeline` §7.7, same rule) |
| 401 / 403 | prints status, endpoint and body **with every header redacted**; names the causes in order: key revoked, key expired, **plan no longer paid** (the brief: API keys need a paid plan) |
| **429** | honours `Retry-After`; else backs off 2 / 4 / 8 s; after `RETRIES = 3` **stops the whole run** and prints the run id to resume. The brief gives 20 req/s and per-plan concurrent-task caps, so a 429 here usually means *concurrency*, not rate: the message says both, and `MIN_REQUEST_GAP_S = 1.0` means we never approach 20/s |
| Task status `FAILED` | **exit 1**, prints the error message the response carries, records the task in `run.json` with its credits, sets `state = "failed"`, and **does not retry** (§1.2). A retry is `meshy.py preview` again, by a human, with the credits understood |
| Poll deadline passed, task still running | **not a failure**: `[meshy] PENDING`, the run id, and `meshy.py resume <run-id>`. The task keeps running at Meshy; a second POST would pay twice for the same model (`asset-pipeline` §7.7 made the same call for a pending operation) |
| A signed URL is expired or 403 | re-poll `GET …/:id` for fresh URLs, once, then fail loudly. **No URL is ever persisted as a reference** (§4.2) |
| **The 3-day deletion** | every task entry carries `expiresAt`. `runs` prints `EXPIRED` in capitals for any unfetched run past it and `EXPIRES IN <n>h` under `EXPIRY_WARN_H`. `fetch` on an expired run refuses with *"Meshy deleted the output; the model cannot be recovered, and it cannot be regenerated identically (no seed) — write a new brief version"* |
| A ceiling hit (`MAX_TASKS_PER_RUN`, `MAX_TASKS_PER_DAY`) | **exit 2** before any request, naming the ceiling and the count. Counted from the run records on disk, so it survives a crashed session |
| Interrupted after a POST but before the id is stored | the id is written to `run.json` **before the first poll** (`asset-pipeline` §7.4 step 3, same ordering, same reason): nothing is orphaned, `resume` finds it |
| `promote` refusal | the files stay in the run dir; nothing is half-written into the drop dir (write to a temp name in the drop dir, then rename) |
| Non-Windows, no registry | printed, once, as a reason — not an exception |

---

## 9. The ASSET agent

### 9.1 Its brief: `docs/ASSET_PROMPT.md`

Same shape as `docs/REVIEWER_PROMPT.md` and `docs/ARCHITECT_PROMPT.md`: a title, "read
`docs/PROJECT_CONTEXT.md` and `CLAUDE.md` first", the job, the rules, the output markers. Contents,
which the Builder writes verbatim into that file:

1. **Job.** Produce one asset from one brief, up to the next stop point. One key per session
   (rule 4: one task per round).
2. **Tools.** Read, Grep, Glob, Write (only `reviews/task-<N>/ASSET_RESULT.md`), and Bash **only** for
   `python tools/meshy.py …` and the two keyless `tools/assets.py` read commands (`validate`,
   `licences`). Nothing else. No git, no `rojo`, no `studio_mcp.py`, no `pip install`, no editor.
3. **The two stop points.** Stop at the preview, always, with `## Needs Karen`. Stop before the Roblox
   upload, always (§15 Director A gives the Director the option to move this one).
4. **Look at the image** (rule 5). Read `preview.png` and say what it shows — not that it exists.
   *"a number is not a verification."*
5. **Never print, paste or echo a key**, and never `cat` a run record without checking it first. The
   report is committed to a public repo by the Builder.
6. **Report honestly** (rule 8): what failed, what it cost, what it could not check.
7. **Output format**: `=== BEGIN ASSET_RESULT === … === END ASSET_RESULT ===`, so the same
   marker-parsing pattern that `tools/agents.py` already uses can capture it when §14's later task
   gives this role a spawn script.

### 9.2 `reviews/task-<N>/ASSET_RESULT.md` — the report

Fixed sections, one page: `Task:` / `Round:` / `Key:` / `Run:` · **What was produced** (the
`[meshy] …` line verbatim, every task id, the credits and the totals) · **What the preview shows**
(the agent's own description of `preview.png`) · **Files written** (names only, never paths) · **The
manifest row**, verbatim from `tools/assets.py`, in a fenced block, for the Builder to paste ·
**Licence basis** and its quote · **What I could not verify** · `## Needs Karen`.

### 9.3 What it may never touch

`src/`, `tests/`, `tools/` (it *runs* `tools/meshy.py`; it never edits it), `docs/design/`,
`docs/architecture/`, `docs/research/` (the research note is the Builder's, rule 1), any `RESULT.md`
or `ARCH_RESULT.md`, `TASKS.md`, `CLAUDE.md`, `ROADMAP.md`, `PLAYTEST.md`, `ESCALATE.md`, git (no
add, commit, branch, push, merge, stash), Studio / Rojo / the harness / the sync token, the Roblox
Open Cloud API and `DRIVEN_HUNT_ROBLOX_API_KEY`, any Meshy community/publish/share endpoint, and any
asset that is not this session's key.

### 9.4 What is enforced and what is policy

**Enforced, by construction:**
- `tools/meshy.py` refuses `refine` without an approval record, refuses a wrong run state, refuses a
  drop dir inside the repo, refuses more than `MAX_TASKS_PER_RUN` / `MAX_TASKS_PER_DAY`, and never
  prints the key.
- `tools/meshy.py` contains no Roblox endpoint and reads no Roblox variable, so an ASSET session
  cannot publish UGC through it.
- `tools/privacy_scan.py` (CI) fails the build on a leaked key shape, a local path or an email in any
  tracked file — including the ASSET report (§13 D3).
- The Builder stages **explicit paths** and reads `git status` and `git diff --cached` before every
  commit (`CLAUDE.md` git workflow step 2), so a stray write by any agent does not silently land.
- The Reviewer and CI see every committed diff.

**Policy, and named as such** (the `--allowedTools` allow-list is not enforced here — `tools/agents.py`
docstring, item 1): that the ASSET agent only runs the two allowed programs, that it does not edit
`src/`, that `approve` was typed by Karen, and that it stops at both stop points. The mitigation for
the expensive half is the ceilings; the mitigation for the repo half is the Builder's staging plus
review. **Do not describe the ASSET agent as sandboxed.**

---

## 10. What it reads from and writes to other systems

| Direction | What | The other side's owner | Evidence |
|---|---|---|---|
| **writes** | `<runs-dir>/**` — run records, previews, downloads | `tools/meshy.py`, sole writer | this design §4.2 |
| **writes** | `<assets-dir>/<key>_v<N>.fbx`, `_albedo.png`, `.json` for Meshy-sourced keys | `tools/meshy.py`; for other sources, Karen and `tools/assets.py init` | `docs/design/asset-pipeline.md` §7.2–7.3 |
| **writes** | `reviews/task-<N>/ASSET_RESULT.md` | the ASSET agent, sole writer; the Builder commits it as paperwork | `CLAUDE.md` git workflow step 4 |
| **reads** | `<assets-dir>/briefs/*.brief.json` and reference PNGs | Karen (or the Director) | §4.1 |
| **reads (imports)** | the file-name grammar, the PNG header reader, the 20 MB cap | `tools/assets.py` (`docs/design/asset-pipeline.md` §7) | one implementation, not two |
| **hands off to** | `tools/assets.py validate` / `upload` | `tools/assets.py` — the only Open Cloud caller | `asset-pipeline` §2.1 |
| **hands off to** | the printed manifest row → `src/serverstorage/Assets/init.luau` | the **Builder** edits it; `ServerStorage.Assets` has no runtime writer | `asset-pipeline` §2.1, §7.5; §2.2 above |
| **writes nothing to** | `src/`, `tests/`, `tools/`, the DataModel, Studio, Workspace, `Boar.CONFIG`, `Shotgun.CONFIG`, `MapGen`, the harness | their existing owners: `Boar.Body`, `Weapon.Hardware`, `MapGen.Props`, `Assets.Loader`, `tools/studio_mcp.py` (`GAME_DESIGN.md` owner rows) | §1.2 |
| **constrains** | the per-key `targetTris` and `texturePx` it asks Meshy for | `docs/design/asset-pipeline.md` §12.1 owns the budgets; this tool **reads** them and must not exceed them | §11, §15 Director C and D |

No change to `default.project.json`, no Rojo restart, no Karen Connect click, no `src/` file, no
harness change.

---

## 11. External sources

Five, plus the two in-house patterns. **None was fetched in this session** (§0 item 1): the two Meshy
Terms/pricing sources were fetched and quoted by Task 39 and are cited from that note; the API sources
are cited as the Director's brief until the research note re-fetches them. Anything I could not verify
is marked.

1. **Meshy API documentation** — base `https://api.meshy.ai`; `POST /openapi/v2/text-to-3d`
   (preview then refine), `POST /openapi/v1/image-to-3d`, `POST /openapi/v1/multi-image-to-3d`,
   `POST /openapi/v1/remesh`, `GET …/:id`; `Authorization: Bearer msy_…`; 20 req/s; per-plan
   concurrency; GLB/FBX/OBJ plus separate PBR maps by signed URL; output deleted after 3 days.
   Licence: **vendor documentation, proprietary, no reuse grant** — quote it, never copy it into the
   repo beyond short quotations. Maintenance: **active vendor docs** (Terms last updated
   2026-09-19 per Task 39, so the site is live and changing).
   **Good:** it is the only authority on the endpoints, it publishes a rate limit and a retention
   window, and it exposes remesh with an explicit triangle target — which is what lets this repo keep
   its no-geometry-parsing rule. **Bad:** no seed, so nothing is reproducible; per-plan concurrency is
   not a number this design can pin; the 3-day deletion turns every interruption into potential data
   loss; `art_style`/`negative_prompt`/`symmetry` were deprecated, which is evidence the surface moves
   under us. **Adopted:** the endpoints, the Bearer header, poll-until-terminal, download-immediately,
   and one command per phase. **Unverified by me:** every string in this entry; §10.1 lists them.
2. **Official `meshy-cli` and `meshy-mcp-server` (MIT, TypeScript)** — named in
   `reviews/task-53/BRIEF.md`. Licence: **MIT** per the brief. Maintenance: **unverified**.
   **Good:** they are first-party, MIT, and therefore the cheapest possible check that our request
   bodies and status handling match what the vendor's own client does — rule 2's "borrow before
   building" applied to the *shape*, which is the part that goes stale. **Bad:** TypeScript and npm;
   adopting either would put a Node toolchain and a dependency tree into the one program that holds a
   secret, in a repo whose three existing tools are stdlib-only Python
   (`tools/studio_mcp.py`, `tools/privacy_scan.py`, and `tools/assets.py` as designed), and an MCP
   server would add a second network surface next to StudioMCP. **Adopted:** read them, copy the
   request/response shapes and the status handling into the research note, cite the file and commit —
   and write ~400 lines of stdlib Python instead of taking the dependency. **This is the "inventing
   needs a written reason" case (rule 2), and that is the reason.** The research note must confirm the
   repository URLs, the `LICENSE` file and the last-commit date before anything is borrowed; I will not
   put a URL I could not fetch into this design (Task 26a: a fabricated devforum URL in a header was
   fixed rather than queued, in a public repo).
3. **Meshy Terms of Use** — <https://www.meshy.ai/terms-of-use>, plus the two help-centre articles and
   the pricing page, all quoted in `docs/research/2026-09-26-asset-pipeline.md` source 13. Licence of
   the *output* on a paid plan: **Karen owns it** — §3.2 *"customers on a paid Meshy plan own their
   Customer Output."* Maintenance: **Terms last updated 19 September 2026**.
   **Good:** the position is published and plain, so the sidecar can carry a quote rather than a
   label. **Bad:** §3.3 puts anything posted to the community page under **CC0 1.0**, and §2.9 lets
   Meshy *"use Customer Inputs and Customer Outputs from non-Enterprise Customers to train, validate,
   test, or improve Services"* — so a paid plan protects ownership, not privacy. **Adopted:**
   `licenceBasis = "meshy-paid-owned"` with that quote, the date and the URL in every sidecar (§4.3);
   a hard prohibition on the community page (§1.2); and §15 Karen 2 on the training clause.
4. **Roblox mesh and texture specifications** —
   <https://create.roblox.com/docs/art/modeling/specifications> and
   <https://create.roblox.com/docs/art/modeling/texture-specifications>. Licence: **CC BY 4.0**
   (`github.com/Roblox/creator-docs`, SPDX `CC-BY-4.0`). Maintenance: **active** (the docs repo was
   pushed to 2026-09-25, per `docs/design/asset-pipeline.md` §11).
   **Good:** one unambiguous first-party sentence — *"Individual meshes can not exceed 20,000
   triangles"* — which is what the remesh target must stay under, plus albedo as plain 24-bit RGB PNG,
   which is what Meshy exports. **Bad:** the triangle limit is the only number on the page, so the
   per-key budgets in `asset-pipeline` §12.1 cannot be validated from it; and 1024 appears there as a
   *recommendation* that Task 37 misread as a limit. **Adopted:** `REMESH_CEILING = 18,000` as our
   never-exceed under the 20,000 hard limit, and the PNG budget read per key from the manifest.
5. **Python `urllib.request` and `winreg`** — <https://docs.python.org/3/library/urllib.request.html>,
   <https://docs.python.org/3/library/winreg.html>. Licence: **PSF**, stdlib. Maintenance: **active**.
   **Good:** multipart-free JSON POSTs, a timeout per request, no dependency; `winreg` gives the
   brief's `HKCU\Environment` fallback with no PowerShell subprocess and no command line to leak into
   `ConsoleHost_history.txt`. **Bad:** `urllib` has no retry, no backoff and no connection pooling, so
   §8's behaviour is hand-written and must be unit-tested; `winreg` is Windows-only, so the fallback
   needs a platform branch. **Adopted:** both, for the same reason the other three tools are stdlib.

**In-house patterns borrowed, named per rule 2:** the subcommand-plus-`selftest`-plus-`--dry-run`
shape, the `[tool] VERB: …` last line and the 0/1/2 exit codes from `tools/studio_mcp.py` and
`tools/privacy_scan.py`; the key fingerprint, the drop-dir refusal and the sidecar contract from
`docs/design/asset-pipeline.md` §7–§8; the `=== BEGIN … ===` marker report from `tools/agents.py`.

**Rejected, so they are not re-proposed:** an FBX/OBJ parser to count triangles (§0 item 2); Pillow or
any image library to downscale a 2K map (a dependency in the key-holding program, for a resize Karen
can do in an editor); a single `generate` command (§5); automatic retry of a failed task (§1.2); a
`meshy` subcommand inside `tools/studio_mcp.py` (`asset-pipeline` §0 item 2); storing signed URLs
(§4.2); Meshy's rigging (humanoid-only).

### 10.1 What the research note must confirm before any code (rule 1)

Each of these is a **string or a shape this design deliberately does not fix**, because I could not
fetch it. The note quotes each one with the URL and the date read.

1. The four endpoint paths and HTTP verbs, and the exact request field names for text, image and
   multi-image (including how a reference image is sent: URL, base64 or multipart).
2. The **status enum spellings** and which single value means success. The parser treats everything
   else as not-success (§7.1), so the note must also name the failure value and where the error
   message lives.
3. The **poll response field names** for the thumbnail, the model URLs and the texture URLs.
4. Whether refine takes a **texture resolution** parameter at all, or whether 2K is simply what it
   returns (this decides §15 Director D).
5. Whether the remesh response **reports** a polycount or statistics field (this decides whether
   §7.3's triangle check is a real assertion or a declaration).
6. Whether a **credits** figure is returned per task, and under what name (this decides whether
   `creditsSource` is ever `"api"`; §11).
7. The **concurrency cap** per plan, and whether 429 distinguishes rate from concurrency.
8. The 3-day retention sentence, verbatim, and whether it is measured from creation or completion.
9. `meshy-cli` / `meshy-mcp-server`: repository URL, `LICENSE` contents, last commit date.
10. Whether any endpoint publishes to the community page, so §1.2's prohibition names it.

---

## 12. Numeric targets

**K** = Karen's taste value; **M** = Meshy's documented value (to be re-quoted, §10.1); **R** =
Roblox's documented value; unlabelled = ours, and a guess unless a basis is given.

| Quantity | Value | Basis |
|---|---|---|
| Meshy rate limit | **20 req/s** | **M**. We never approach it |
| `MIN_REQUEST_GAP_S` | 1.0 | ours, same as `asset-pipeline` §12.2. One request per second against a 20/s limit is not the constraint; concurrency is |
| `POLL_INTERVAL_S` | 5 | ours. Generation takes minutes, not seconds |
| `POLL_DEADLINE_S` preview / refine / remesh | 600 / 900 / 300 | ours. Past it is `PENDING`, never a failure (§8) |
| `HTTP_TIMEOUT_S` | 60 per request; 300 per download | ours |
| `RETRIES` / backoff | 3 / 2, 4, 8 s, `Retry-After` wins | the pattern `asset-pipeline` §12.2 adopted from Roblox's own rate-limit instruction; applied here to Meshy |
| **Output retention** | **72 h**, then deleted | **M**. Drives `expiresAt`, `EXPIRED`, and download-in-the-same-chain |
| `EXPIRY_WARN_H` | 24 | ours |
| `MAX_TASKS_PER_RUN` | **4** (preview, refine, remesh, one replacement) | ours. The real spend ceiling; a fifth task needs a new run and a human |
| `MAX_TASKS_PER_DAY` | **12**, counted from the run records | ours. A runaway session cannot empty the plan |
| `REMESH_TARGETS` | `boar.body` **6,000**; `shotgun.handle` 4,000; `prop.highseat` 1,500; trees 900–1,200 | **read from `docs/design/asset-pipeline.md` §12.1**, one table, not restated here. §15 Director C |
| `REMESH_CEILING` | **18,000** | the Director's brief ("~18k, under Roblox's 20k"), used as the **never-exceed** for a key with no budget |
| Roblox mesh hard limit | **20,000 triangles** | **R**, first-party, one sentence |
| `texturePx` requested | **2048** for hero keys (boar, gun) | the brief ("refine (2K, PBR)"). Collides with `asset-pipeline`'s `TEXTURE_MAX_PX = 1024`: §15 Director D |
| Roblox texture platform limit | 4096 × 4096 | **R**. 2048 is inside it |
| `MAX_FILE_BYTES` | 20 MB | **R**, per Open Cloud call; imported from `tools/assets.py` |
| Maps promoted in v1 | **1** (albedo) | `asset-pipeline` §12.2: a `SurfaceAppearance` cannot be assembled at run time, so the other maps stay in the run dir |
| Reference images per brief | **1–4** | **M** (multi-image endpoint) |
| Preview→OK→delivered, wall clock | **target ≤ 2 h** including Karen's look; generation itself minutes | ours, and the number that says whether this role is worth its cost |
| Credits per task | **logged, never estimated** | `creditsSource: "api" \| "unknown"`. §10.1 item 6 |
| Sizes the boar and gun must match | `2, 3, 5.5` and `0.4, 0.5, 4.4` studs | measured from the code: `src/server/Boar/init.luau` `CONFIG.BODY_SIZE`, `src/shared/Shotgun/init.luau` `CONFIG.HANDLE_SIZE`. `asset-pipeline` §6.1 requires the mesh to be the grey box's size, so no physics, hit-zone or grip number moves when art lands |

---

## 13. How it is tested

`tools/meshy.py` puts **nothing** in the DataModel, so there is no server spec and no client spec to
write, and the harness has no part in it. That is a real answer, not a gap — and it is why the test
burden falls entirely on an offline selftest plus two human looks.

### 13.1 `python tools/meshy.py selftest` — offline, no key, no network, runs in CI

1. **Brief validator**: each refusal in §4.1 fires on a crafted brief, and a good brief passes. Every
   case asserts the *reason*, not just the exit code.
2. **Request builders**: for 0, 1 and 3 references, the endpoint chosen is text / image / multi-image,
   and the body contains the prompt and no deprecated field (`art_style`, `negative_prompt`,
   `symmetry`) and no rigging option. Asserted against a frozen expected-JSON fixture, so a later
   edit to the builder shows up as a diff.
3. **Key redaction, asserted rather than trusted**: build a request with a fake key, render every log,
   `--dry-run` and error string the tool can emit, and assert the fake key appears in **none** of
   them. This is the test that keeps §6.1 true after a future edit.
4. **Status parser**: the success value succeeds; the failure value fails with the message extracted;
   **an unknown value is treated as not-success** (the `MODERATION_STATE_` lesson); a missing status
   field fails loudly rather than defaulting.
5. **State machine**: every command refuses every wrong state by name; `refine` without
   `approval.json` refuses; `approve` twice is idempotent.
6. **Ceilings**: `MAX_TASKS_PER_RUN` and `MAX_TASKS_PER_DAY` computed from fixture run dirs, at the
   boundary and one past it.
7. **Expiry arithmetic**: a run 71 h old warns, 73 h old is `EXPIRED`, and `fetch` on it refuses.
8. **Validation on fixtures**: a 24-byte PNG header at 512, 1024 and 2048; an over-budget PNG
   refused; a 21 MB file refused; a sha256 mismatch refused; an existing sidecar refused.
9. **Sidecar writer**: the produced JSON has exactly the fields `tools/assets.py` §7.3 item 2 requires,
   `licenceBasis == "meshy-paid-owned"`, a non-empty quote, and **no absolute path and no email**
   anywhere in it.
10. **No local path in any output**: every printed line from every command, run over fixtures, is
    checked against `tools/privacy_scan.py`'s rules by importing them — so the tool's own stdout is
    held to the CI standard before it can be pasted into a report.

Each case asserts something that can fail, and the two that could most easily become tautological (3
and 10) assert absence over the full rendered output, not over a single string.

### 13.2 `--dry-run`, and the one real run a human watches

`--dry-run` prints the exact request with the key masked. The first real preview is watched by a
human, and its `[meshy] OK:` line, task id and credit figure go into
`reviews/task-<N>/ASSET_RESULT.md` verbatim — the same evidence discipline as the `[harness]` line.

### 13.3 Images (rule 5)

The only image this system produces is `preview.png`, and **it is looked at twice**: by the ASSET agent
(Read, described in the report) and by Karen (the OK). Studio screenshots belong to the delivery half
and are already specified: `boar-front`, `boar-side`, `boar-rear`, `boar-above`, `boar-flash`,
`gun-third`, `gun-ads`, `prop-edit` (`docs/design/asset-pipeline.md` §13.4). **Nothing in this design
claims a Studio screenshot**, because nothing here reaches Studio.

### 13.4 What the harness cannot do here, stated rather than discovered

- **It cannot run this tool.** `tools/studio_mcp.py test` needs Studio in Edit mode with Rojo
  connected; `tools/meshy.py` needs neither and must never be wired into it (`asset-pipeline` §0
  item 2). A change to `tools/meshy.py` is still a `tools/` change, so the harness gate in
  `tools/agents.py` requires a 1-player `[harness] PASS` line for the code commit; `test2` is
  **exempt**, because the change touches neither `src/`, `tests/client/` nor `tools/studio_mcp.py`
  (`CLAUDE.md`, definition of done, box 2).
- **It cannot generate, and it must not.** No Meshy key in the harness, ever.
- **It cannot count triangles** (§7.3), and neither can this tool.
- **It cannot judge a model.** Karen.
- **No input scenario is added.** An asset takes no input; a scenario here would test the harness,
  which rule 6 forbids (`asset-pipeline` §13.5 made the same call).
- **The `Read`-the-image check is not a substitute for Karen**, and the report must not read as one.

---

## 14. Build order — and the smallest first task

The brief asks for *"the smallest first task: one model (the boar) end to end up to Karen's preview
OK"*. §0 item 6 makes that clean: the preview half needs nothing that does not exist.

**Task A — "the boar, to the preview" (the first task).**
- `docs/research/<date>-meshy.md` + its `INDEX.md` row, answering §10.1's ten items (rule 1, and no
  code before it).
- `tools/meshy.py`: `key`, `brief`, `preview`, `status`, `runs`, `resume`, `approve`, `selftest`,
  `--dry-run`. **Not** `refine`, `remesh`, `fetch`, `promote`.
- `docs/ASSET_PROMPT.md` (§9.1); the `CLAUDE.md` role row and key line (§2.3); the
  `tools/privacy_scan.py` `msy_` rule and its two selftest samples (§13 D3); the CI step
  `python tools/meshy.py selftest`; `.gitignore` `/.meshy/` if any local scratch is used.
- **NEEDS KAREN:** the `MESHY_API_KEY` user variable (and `ASSET_DROP_DIR`, if M2.7a has not already
  created it); the brief text for the boar; **and the look at `preview.png`**.
- **Buildable and reviewable before any of Karen's clicks**: `selftest` and `--dry-run` need no key.
- Deliverable: `reviews/task-<N>/ASSET_RESULT.md` with a real `[meshy] OK: preview …` line, the
  credits, and the agent's description of the image. Karen's yes or no is the gate to Task B.

**Task B — "the boar, delivered".** `refine`, `remesh`, `fetch`, `promote`, the sidecar writer, and the
import of `tools/assets.py`'s grammar and PNG reader. **Depends on M2.7a** (`tools/assets.py` +
`src/serverstorage/Assets/`, `asset-pipeline` §14), because the sidecar contract and the promote
validation are that tool's. Ends with `tools/assets.py validate` green on the promoted files.

**Task C — the upload and the row.** The operator runs `tools/assets.py upload`; the ASSET agent
reports the printed row; the Builder pastes it into the manifest. Then
`docs/design/asset-pipeline.md` §14 M2.7b ("the boar wears it") is unblocked and unchanged.

**Later, one task each, none of them in the way:** a spawn script for the ASSET role
(`tools/asset.ps1` / `tools/agents.py asset --task N`, marker-parsed like the Reviewer and Architect)
— **tooling, so `ROADMAP.md` speed rule 1 puts it at "before release" unless the Director allows it**;
multi-asset runs (the gun, the high seat, the trees); Meshy's other endpoints if a need appears.

---

## 15. Deltas this design imposes on documents that already exist

Named so they are not discovered in review. D1–D2 are **Architect-owned** and need a regeneration or a
Director note; D3–D6 are the Builder's, in the first task.

- **D1. `docs/design/asset-pipeline.md` §12.2 `TEXTURE_MAX_PX = 1024` becomes per-key**, default 1024,
  with `boar.body` and `shotgun.handle` at **2048**, because the brief specifies a 2K refine and
  `tools/assets.py` §7.3 item 5 would otherwise **refuse the file this pipeline produces**. 2048 is
  inside Roblox's 4096 platform limit. See §15 Director D; the default in this design is: ask Meshy for
  what the key's budget says where the API allows it (§10.1 item 4), promote what arrives, and record
  the number.
- **D2. `docs/design/asset-pipeline.md` §12.1's `boar.body` triangle budget (6,000) and the brief's
  "~18k" must be reconciled**, and this design uses 6,000 as the target with 18,000 as the ceiling.
  See §15 Director C. Nothing else in either design changes either way — it is one number in one table.
- **D3. `tools/privacy_scan.py` gains one rule**, `meshy-key`, matching a `msy_`-prefixed token of 20+
  characters, plus one `CAUGHT` sample and one `ALLOWED` sample (the bare word `MESHY_API_KEY` and the
  string `Bearer msy_…` as prose must stay legal). Assembled from pieces at run time like every
  existing rule, so the file still contains no string its own rules match. And its docstring's list of
  secret shapes gains the row.
- **D4. `CLAUDE.md`**: the ASSET role row (§2.3), the `tools/meshy.py` line in the toolchain/secrets
  area, the `docs/ASSET_PROMPT.md` entry in the "Files the roles talk through" table with
  `reviews/task-<N>/ASSET_RESULT.md`, and the Layout table's `tools/` row gaining `meshy.py`. The
  workflow prose says "Four-agent workflow" and "Five roles" — with the ASSET agent it is five agents;
  the Builder decides whether to rename the heading or add a sentence, and a stale heading is a note,
  not a defect.
- **D5. `.github/workflows/ci.yml`**: one step, `python tools/meshy.py selftest`, in the shape of the
  existing steps, `if: success() || failure()` so one run reports every problem. Offline, no key, and
  CI never gets one. Allowed past `ROADMAP.md` speed rule 1 by the same green light the brief gives
  `tools/meshy.py`.
- **D6. `GAME_DESIGN.md`**: the two new owner rows from §2.1 when the first task lands (rule 3: the
  table mirrors the designs).

---

## 16. Open decisions

**None of these blocks Task A.** Each has a working default, in this document or in one constant.

### For Karen (taste, and the two she alone can answer)

1. **The boar's brief text.** Nobody else can write what a European wild boar should look like for her
   game. Default: a first draft in the brief file, which she edits before Task A runs. The reference
   images are optional and 1–4 of them usually beat a longer prompt.
2. **The plan tier, for one reason only.** Ownership is settled by the paid plan (Terms §3.2), and the
   working API key is itself evidence of it (API access is a paid feature, per the brief). What is
   **not** settled: §2.9 lets Meshy *"use Customer Inputs and Customer Outputs from non-Enterprise
   Customers to train, validate, test, or improve Services"*. If a bespoke Driven Hunt asset being
   training data is not acceptable, Enterprise is the only answer Meshy's terms offer. Default: accept
   it and record it in the run log. **Not legal advice.**
3. **Never post a Driven Hunt model to the Meshy community page** (Terms §3.3 puts it under CC0). This
   is a habit, not a setting, and the tool cannot prevent it.
4. **Does the preview look right** — the one gate this whole design is built around. Default: nothing
   is refined until she says yes.
5. **Texture size, if she notices**: 2K delivered, 1024 recommended by Roblox for a 20-stud object. If
   the boar's texture memory ever matters, the map's trees come down before the boar does.

### For the Director (scope)

A. **Does the ASSET agent run `tools/assets.py upload`?** Default here: **no** — it runs `validate`
   and `licences` (keyless) and stops, because an upload mints a permanent, unrenameable public asset
   on Karen's account under Roblox's Creator Terms and cannot be undone. Recommendation: keep it with
   a human until the pipeline has produced a few assets without surprises.

B. **Does the ASSET agent write `src/serverstorage/Assets/init.luau` directly?** Default here: **no**
   — it prints the row into its report and the Builder commits it (§2.2), because that file is linted
   Luau under `src/` and `CLAUDE.md` gives the Builder that file. Recommendation: keep it. The cost is
   one paste per model; the benefit is one writer on the art provenance of the whole game.

C. **The boar's triangle target: 6,000 (the manifest budget) or ~18,000 (the brief)?** Default here:
   **6,000**, because `tools/assets.py` §7.3 item 6 refuses a `trisDeclared` above the key's budget, so
   18,000 would be refused by the next tool in the chain; 18,000 becomes `REMESH_CEILING`.
   Recommendation: 6,000 for eight on-screen boars at ≤100 studs, raised later by one number if Karen
   says the silhouette reads badly — `asset-pipeline` §12.1 already says *"If they must come down, the
   tree budget comes down before the boar's."*

D. **`TEXTURE_MAX_PX`: per-key 2048 for hero assets, or 1024 everywhere with a manual downscale?**
   Default here: **per-key, 2048 for the boar and the gun** (D1), because the brief specifies a 2K
   refine and neither an image library nor a Karen resize is worth adding to the chain. Recommendation:
   accept D1.

E. **Does the ASSET role get a spawn script now or later?** Default here: **later** — Task A's role is
   operated as a session against `docs/ASSET_PROMPT.md`, exactly as the Builder is, so the first task
   adds no agent-harness code. `ROADMAP.md` speed rule 1 freezes tooling, and §0 item 5 says a spawn
   script would not sandbox it anyway. Recommendation: revisit once the flow has run end to end, and
   size it then.

F. **Task B waits for M2.7a.** It imports `tools/assets.py`'s grammar, PNG reader and sidecar
   contract, and writes files for a manifest that does not exist yet (§0 item 6). Recommendation:
   dispatch M2.7a between Task A and Task B; if the order must be reversed, `tools/meshy.py` would own
   those helpers and `tools/assets.py` would import them — one direction or the other, never both.

### What I could not verify (rule 8)

- **Every Meshy API string in this document.** No network in this session (§0 item 1). §10.1 is the
  list the research note must close, and nothing in §5, §7 or §8 depends on a string I invented: the
  parsers are written to treat unknown values as failures, and the field names are named as "the field
  the research note names" wherever the brief did not give one.
- **The `meshy-cli` / `meshy-mcp-server` URLs, licences and maintenance status.** Named in the brief as
  MIT; deliberately not written here as links (§10 source 2).
- **Meshy credit prices per task type.** Not in the brief; the design logs what the API reports and
  `"unknown"` otherwise, and enforces ceilings in **tasks**, which are countable.
- **Whether `winreg` returns `REG_EXPAND_SZ` for these variables on Karen's machine.** The tool must
  handle both `REG_SZ` and `REG_EXPAND_SZ` and expand the latter with `os.path.expandvars`; that
  branch is covered by the selftest with a fixture, not by a live registry read.
- **Anything in Studio or the engine.** Nothing in this system touches either.

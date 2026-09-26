# Task 59 — what `docs/design/meshy-tool.md` no longer matches

The Architect owns that file; this is the delta the Builder is asking for, not an edit. Everything
below is a Director decision already taken, or a review finding already fixed in `tools/meshy.py`.

## 1. Briefs live in the repo, and are not PNG-only (§4.1, §16)

- §4.1 and §16's table say briefs and their reference images live in `<assets-dir>/briefs/`. They
  live in **`docs/asset-briefs/` in the repo** — one source, reviewed in git — and `tools/meshy.py`
  reads that folder directly. Everything the tool *writes* still goes outside the repo
  (`<runs-dir>`). Director decision, row 55a(b), 2026-09-26.
- §4.1 refuses *"a reference that is not a PNG"*. The accepted set is **`.png`, `.jpg`, `.jpeg`,
  `.webp`** — Karen's photographs are JPEG and WebP. Director decision, row 55a(a).

## 2. A new terminal that is not terminal: `preview-unresolved` (§7, §8)

Round 1 of this review found the class: a give-up or a failed download wrote `failed`, and `resume`
refuses anything but `preview-running`, so **credits already spent could never be collected**. The
tool now has a sixth state:

| state | meaning | `resume` takes it |
|---|---|---|
| `preview-unresolved` | a PAID task may still be running, or its output can still be re-fetched: three unanswered polls, a rejected key, a SUCCEEDED task whose signed download URL failed | **yes** |
| `failed` | Meshy said `FAILED` or `CANCELED`, a ceiling stopped the run, or no task was ever created | no |

§7's state table and §8's failure table both need the row. §8 currently reserves `failed` for *"a
Meshy task came back FAILED, or a ceiling stopped the run"*, which is exactly the line the code now
keeps — the design was right and the code was wrong.

## 3. A fifth word in the machine-readable vocabulary (§13.1)

The last line is `OK / PENDING / **STOPPED** / FAILED / REFUSED`. `STOPPED` exits 1 and always ends
with the exact `resume` command, because a stopped run is money waiting to be collected. Whatever
§13.1 says about the vocabulary needs the fifth word.

## 4. Constants §16 does not list

- `POLL_GIVE_UP_AFTER = 3` — consecutive non-200 polls before the tool stops. Each poll is already
  retried by `request`, so this is ~15 s of 5xx or 429, not one blip.
- A failure-table row for **"a poll that cannot reach Meshy"**, distinct from "the task failed".

## 5. Still open, for the Director rather than the Architect

`docs/asset-briefs/` holds the three briefs and no reference image, so an image-to-3d brief cannot
name one yet: `validate_brief` requires every reference to be a file in that folder. Committing
Karen's photographs to a **public** repo is her decision, not mine. Queued in `TASKS.md` as 59a.

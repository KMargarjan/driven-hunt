# Task 70 — the shotgun brief, v2: a side-by-side, said so first

Task: 70
Round: 1
Base: `7cf52d1` (`main`, with Task 67 merged)
Code commit: `<this request's commit>` — **docs-only**. Nothing under `src/`, `tests/` or `tools/` is
touched, so no harness run applies (CLAUDE.md, the loop's step 3: "Docs-only tasks are exempt").
The only files are `docs/asset-briefs/shotgun.handle_v2.brief.json`,
`docs/research/2026-09-26-meshy.md` (item D16, claim 8), `TASKS.md` and this request.

**No credit was spent and no network call was made.** `meshy.py brief` validates and prints; it
sends nothing.

## Why there is a v2

The Asset agent's first preview (`shotgun.handle_v1-20260926T1850Z`, 20 credits, **not approved**)
came back an **over-under** with short barrels, a ventilated rib and a bulky pistol grip. The
Director looked at `preview.png` and agrees. Karen's decision has not changed — side-by-side,
Beretta 486 Parallelo style, no logo or text, not overly detailed — so what changes is the wording,
not the decision. **v1 is kept exactly as it is** (rule 7): a brief is the provenance of the run that
was paid for, and the next version is a new file.

## Claims

1. **The configuration is the first thing the prompt says, positively and negatively.** It opens:
   *"A side-by-side double-barrelled shotgun. The two barrels lie horizontally next to each other at
   the same height, forming a wide flat barrel pair, seen from the front as two circles side by side
   -- not stacked, not an over-under."* Verify: the `prompt` field's first two sentences.

2. **"Classic Italian style" is gone.** It is the phrase that pulls a generator toward an
   over-under; the brief says **"A classic European game gun"**. Verify: the prompt contains no
   "Italian"; `git diff` against v1's prompt.

3. **The three shapes v1 got wrong are now stated.** *"A solid concave top rib, not ventilated"*, *"A
   shallow, wide action body"*, and *"Long barrels, about two thirds of the total length; not short
   or sawn-off."* Each names what it is AND what it is not, which is the only part of v1's wording
   that demonstrably worked (the no-text rule held).

4. **The Director's pick is marked as a pick.** The straight English stock with no pistol grip, the
   single trigger and the slim splinter forend are in the prompt, and `notes` says in capitals that
   they are the **Director's choice of a sensible first answer, changeable** — Karen's rule of
   2026-09-26, styling never blocks. Verify: the `notes` field.

5. **Everything Karen already decided is carried through unchanged**: warm walnut with fine
   chequering, a silver-grey action with light scroll engraving, blued barrels, a bead front sight,
   restrained rather than ornate, and **no text, lettering, logo, maker mark or serial number**. No
   brand name appears in the prompt, deliberately: a generated maker mark would be somebody's trade
   dress. Verify: the prompt's last three sentences.

6. **No number moved.** `sizeMetres` `[0.112, 0.14, 1.232]`, `targetTris` 4000, `texturePx` 2048 are
   v1's, so nothing in `Shotgun.CONFIG.HANDLE_SIZE` or any hit-zone number moves when the art lands.
   Verify: `diff` of the two briefs' numeric fields.

7. **It validates, offline:**

       [meshy] brief shotgun.handle_v2.brief.json: key=shotgun.handle v2 kind=meshpart
               briefSha256=125ab5d3b39eeec4
       [meshy] endpoint: text-to-3d (chosen by 0 reference(s), not by a flag)  POST /openapi/v2/text-to-3d
       [meshy] target_polycount=4000 texture_resolution='2k' (refine, Task B; the brief's 2048px)
       [meshy] OK: brief shotgun.handle v2 is usable

   Verify: run `python tools/meshy.py brief shotgun.handle_v2`.

8. **The prompt is 790 characters against Meshy's documented 800-character maximum**, which is why
   the wording is compressed rather than longer. The first draft was 912 and would have been refused
   by the API after the operator had typed `preview`. `meshy.py` does **not** check that limit — it
   is the one field with a documented length and no local check — so it is queued as **70a(a)**.
   The limit is quoted from the Text to 3D reference and recorded in the research note as **D16**,
   which this task adds: it was not in the note before.

## What I could not verify

- **Nothing has been generated from this brief.** Whether the wording actually produces a
  side-by-side is Meshy's answer to give, and it costs 20 credits to ask.
- **Karen has not seen v2.** The Director's three style picks are marked changeable in the file, but
  she has not been asked.
- **The 800-character limit was not in the research note until this task added it (D16).** It is
  quoted from the Text to 3D reference as read on 2026-09-26; I did not re-read the page today, I
  recorded what an earlier fetch of it in this session said.
- **v1's preview image**: the Director looked at it, not me. This task quotes that report.

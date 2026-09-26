# Asset briefs — the reviewed record

These are the inputs to `tools/meshy.py`: one JSON file per asset, carrying Karen's decisions about
what the model must be. They are **data, not code**, and they contain no path, no key and no email.

**Why they are in the repo, when `docs/design/meshy-tool.md` §4.1 puts briefs in
`<assets-dir>/briefs/`.** A brief decides what is generated and what is paid for, and it is quoted
verbatim into every run record as the provenance of record (design §0 item 3). A file that decides
that, and that nobody can review in a pull request, is the shape of decision this project has been
burned by before. So the repo holds **the reviewed record** and the drop folder holds **the working
copy the tool reads** — `tools/meshy.py` still reads only `<assets-dir>/briefs/`, exactly as the
design says, and reads nothing from here.

Copy a brief into place before running the tool:

    cp docs/asset-briefs/<key>_v<N>.brief.json "$ASSET_DROP_DIR/briefs/"

**This duplication is a delta from the design** and is listed for the Architect in
`TASKS.md` row 55a. If the Architect would rather the repo copy were the only one, the change is one
line in `briefs_dir()`.

`references` names files that must sit in `<assets-dir>/briefs/`, and the validator accepts **PNG
only** (design §4.1, `docs/design/asset-pipeline.md` §7.3 item 3: one format per job). The reference
images the Director supplied are JPEG and WebP, in `<assets-dir>/references/` — see row 55a again;
nothing in Task A is blocked by it, because the boar is text-to-3D with no references.

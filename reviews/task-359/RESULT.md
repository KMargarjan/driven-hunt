PASS (item 8 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: nobody has seen the painted
forest on the M map, in Karen's place or anywhere else. What was seen are two DEV frames the
request describes -- nine `ImageLabel`s carrying the nine resolved ids on a probe's own ScreenGui
(`20261113T114511Z-359-dev-nine-image-ids.png`), and the DEV M map opened by a real keystroke
(`20261113T114632Z-359-dev-map-OPEN-after-M.png`), which by `MapUi.geometryFor`'s
`world == "forest-test"` branch and `Map.WORLD_BY_PLACE`'s `map:v1` for DEV *cannot* contain a
painted tile. The request says exactly that (claim 8) and names neither frame for a state it does
not show. `Flags.DEFAULTS.MAP_PAINTED` is `default = false` (expires 2026-12-03), and
`src/client/Hud/init.luau` does not even `require` `PaintedMap` with the row off, so this merge
lights nothing; the tiles-on-the-map frame is the Director's to take in her Forest Test after she
says so. Not a core item (no animal behaviour, no shooting) -- item 8 is named so the merge gate
reads what is still unseen.

Delete the producer, by reading, case by case:
- `tools/map_paint.py` `cmd_selftest`, "src/shared/Map/PaintedMap.luau is this generator's own
  output": the new `on_disk == manifest_luau(plan, geo, read_ids(None), sizes)` bites both ways.
  Revert the one changed argument to `{}` and it FAILs on the committed file (`manifest_luau`
  writes `decalId = 0,`/`imageId = 0,` via `ids.get(tile["id"], (0, 0))`); delete the code that
  FEEDS it, `assets/ready/map/asset-ids.json`, and `read_ids` returns `{}` by its own
  "Absent is all zeros" branch, so it FAILs again. Not circular: the ids file is the generator's
  INPUT, read from `OUT_DIR`, never derived from the shipped manifest.
- `tests/client/map_ui.spec.luau` "draws the IMAGE id, and a tile with only a Decal id paints
  nothing and keeps its ground" (claim 9) builds its tiles from `uploaded()`, whose ids are
  `800000 + index` / `900000 + index`, so EVERY line of it passes unchanged with the nine ids
  reverted to 0. That is not a finding -- the request offers it as proof of the guard
  (`paintedFromGrid`'s `type(imageId) == "number" and imageId ~= MapUi.PAINTED.NO_ASSET`), not of
  the ids, and says so. It does mean no committed automated case stands behind the nine ids: only
  the selftest comparison above, plus the DEV probes I cannot re-run.
- claim 5's probe is sensitive: with the ids at 0, `MapUi.paintedFromGrid` hits `if #out == 0 then
  return nil`, so "9 rows, background first" could not print. Claim 6's is sensitive: `imageId` 0
  in front of an `ImageLabel` is the blank red ground it says no label shows.
- claim 7 (the M key) passes with this whole change deleted, by design -- it is an invariant case
  for an unchanged control, and it is not offered as evidence that any tile draws.

Consistency of what I cannot run: `[harness] PASS: 34/34 checks @
e4b50d48c288339ac0e1478aaef5b2d6edeef77a (clean tree) scope=all` names the request's
`Code commit:` exactly; `.agent-evidence/paperwork-after-code-commit.txt` says only `TASKS.md` and
`reviews/task-359/REQUEST.md` changed after it ("Not paperwork: none"). selene 0/0/0, stylua
clean, `rojo build` exit 0. The nine `uploads.json` rows match `roblox_upload.py`'s `row` dict
field for field and in order, every one `"assetType": "Decal"` / `"moderationState": "Approved"`;
`creatorUserId` is that tool's own public `CREATOR_USER_ID` constant, not a new datum. All nine
`file` values (`a1`..`d2`, `wood.png`) are tracked under `assets/ready/map/`, and
`asset-ids.json` is outside every Rojo path, so no `.json` becomes a ModuleScript. I cannot hash,
so claim 2's sha256 equality is unchecked; the nine `decal` ids in `asset-ids.json` equal the nine
`assetId`s of the new rows and the dispatch's nine, the nine `image` ids are distinct, and none
equals any decal id -- checked by hand, nine for nine.

## Notes (non-blocking)
- `tests/client/map_ui.spec.luau`, `uploaded()`'s comment -- "The nine rows ship with `decalId`
  and `imageId` 0 until the pictures are uploaded" is now false: they ship resolved. The case
  bodies are unaffected (arm 1 sets its own `imageId = nil`, the `one` literal its own 0). Fix:
  say the rows now ship resolved and that the stand-in ids keep the arithmetic cases independent
  of whatever the manifest carries.
- `tools/map_paint.py` `cmd_selftest` -- nothing ties `asset-ids.json`'s `decal` ids to the
  `assets/uploads.json` rows. One wrong digit in the ids file renders cleanly, passes the selftest
  (which only re-renders its own input) and ships a tile whose `imageId` loads nothing while
  `PAINTED.REPLACES_GROUND` takes task 347's tint away under that cell. Queue: an assertion that
  every `decal` in the ids file is the `assetId` of an `assets/uploads.json` row with
  `sourceFolder == "map"` and the matching `file`.
- `tools/map_paint.py` -- the "fails on a hand edit" half of claim 10 was measured by hand, twice,
  and no case in the file asserts it (e.g. render with one mutated id and assert inequality). With
  no workflow step running `map_paint.py` at all (already queued as TASKS.md 354-notes (ci)), the
  manifest-fidelity check is a hand check only; the CI note is the one that matters.

---
REVIEWER verdict on commit `7165715bf3f0a06d5c7b50fea96039e1a9a62432` (round 1) · 2026-11-13 11:59 UTC · session cost $1.83, 32 turns · written by tools/agents.py

# Task 231 -- four small fixes before Karen's next test

Task: 231
Round: 1
Base: `main` at `2cb69057` (the merge of task 229's role switch)
Code commit: `6e2b575f6e4ff8c97ae3db2fb13c5f9930fda0c7`

```
[harness] PASS: 34/34 checks @ 6e2b575f6e4ff8c97ae3db2fb13c5f9930fda0c7 (clean tree) scope=all
```
(1983 server + 517 client assertions, 65 server spec files, 25 client. The check count is 34 and was
33: claim 9 adds one.)

`test2`: **N/A.** `TWO_PLAYER_PATHS` in `tools/agents.py` is the match, the drive, the tie and the
teams. This change is `src/client/Hud/` (init, Objective, ReportPanel, Touch, Rail, MapUi),
`src/shared/Report/`, `src/serverstorage/Assets/`, `src/server/ViewmodelAssetsBoot.server.luau`,
`tools/studio_mcp.py`, four `tests/client/` specs and one `tests/server/` spec -- none of them in that
list, and `src/shared/Drive/` and `tests/client/match_client.spec.luau` are deliberately NOT touched
(claim 2). CI green on the pushed branch (run 39648738327).
`python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both pass (rule G).

## What changed, and why

Four dispatched fixes, measured first in a live DEV session in every case. Two of them contradict
what the queue said was wrong, and both contradictions are evidenced below (rule 8).

## Claims

1. **Every player-facing string that names the quarry in general says ANIMALS, and the counter was
   already right.** MEASURED before anything changed: `Phase.step` adds one to `boarsAccounted` on
   any `kill` or `gone` event, and `Match.onDowned` / `onDespawned` raise those off the record
   without ever reading the species -- so `Match.snapshot`'s `boarsLeft` has counted red deer since
   task 230 and only the WORD was wrong. Nothing about the count is touched. The strings changed,
   all six: the status chip's caption (`Hud.renderDrive`), `Objective.CONFIG.TEXT.Shooters.Running`
   and `.Drivers.Running`, `Hud.feedTextFor`'s escape line, `Hud.killLineText`'s noun, and
   `ReportPanel.detailCellsFor`'s no-kind fallback.
   *Verify:* `tests/client/hud_style.spec.luau` (the live bar says ANIMALS and never BOARS),
   `tests/client/report_panel.spec.luau` (the kill line and the ANIMAL column), and
   `tests/client/hud_clarity.spec.luau`'s existing sweep, which measures every objective sentence
   with the engine's own `TextFits` at 400 px and a 33-character bound -- `stay on your stand,
   animals coming` is 34, which is why the two sentences lost a word instead of the bound being
   raised a third time.

2. **The ONE quarry string left alone, and why.** The beater start card says *"Push the boars to the
   hunters"* (`Drive.CONFIG.START_CARD_BEATER_ROWS`), asserted by
   `tests/client/match_client.spec.luau`. Both files are in `TWO_PLAYER_PATHS`, so one word there
   costs a human `test2` click per review round -- the cost that table's own comment predicts. Queued
   as **231a** with the frame that shows it. Boar-SPECIFIC strings are unchanged as dispatched:
   `START_CARD_QUARRY_WORDS`, `Match.CONFIG.QUARRY`'s `WILD BOAR`, `Licences`' labels and
   `Report.trophyWord`'s `LEGENDARY BOAR`.
   *Verify:* `git diff main..HEAD --name-only` contains neither file.

3. **A stag is no longer reported as "STAG BOAR".** `Hud.killLineText` built its noun as
   `string.upper(kind) .. " BOAR"`, so every red deer kill since task 230 printed one species over
   another, and a kill whose `animalKind` never arrived printed `BOAR` about an animal nobody had
   identified. `Report.animalWord` is the one place that decision lives now, beside `Report.kindWord`
   for the same reason.
   *Verify:* `tests/client/report_panel.spec.luau`, case *"names the animal when it knows its kind,
   and never says NIL BOAR or STAG BOAR"* -- it walks all seven kinds and both fallbacks.

4. **227a(a)'s cause for the pale receiver is WRONG, and here is the measurement.** The queue says it
   is task 99's white glove (`AlphaMode.Overlay` over a map with no alpha, which draws the part's
   `Color`). Four probes in a live DEV session say otherwise:
   (a) every gun mesh in the manifest arrives identically -- one `SurfaceAppearance`,
   `AlphaMode.Overlay`, `Color` (163, 162, 165) -- and the Rigby and model B look right;
   (b) painting the drawn clone **pure red** changed not one pixel: the receiver's flank reads
   (102, 139, 158) in both frames, so the part's `Color` is IGNORED and the ColorMap IS drawing;
   (c) `Material` changes nothing (Fabric and SmoothPlastic both read (102, 139, 158)), because the
   appearance's maps own the response;
   (d) forcing `AlphaMode.Transparency` made it WORSE -- the whole gun washed to
   (141..170, 176..193, 195..203) and lost its panel lines.
   What is pale is the ALBEDO: a stainless 1895 SBL whose prep recoloured no base colour (the row's
   own notes), where model B's barrels were re-prepped to a blued (34, 36, 42) for exactly this
   reason (task 105).
   *Verify:* `.screenshots/231-before-lever-aim.png`, `231-probe-lever-red-overlay.png`,
   `231-probe-lever-aim-transparency.png`, `231-probe-matFabric.png` -- and the `tint` field's own
   comment in `src/serverstorage/Assets/init.luau`, which carries all four.

5. **So the fix is the map's own tint, in ONE pass keyed on the manifest.** A new `tint` field on the
   asset `Row`, applied by `ViewmodelAssetsBoot`'s `publishGunPiece` to every gun piece that has one
   -- not a patch on the one mesh that was complained about (L-031), so the next pale upload is one
   field and no code. It goes on the `SurfaceAppearance` because a `MeshPart.Color` write is ignored
   while one is present, which is the fact `src/server/Boar/Body.luau` already writes the coat
   through. Only the lever's three groups carry it, and a spec asserts that no other row does: a
   blanket tint would break two guns to mend one.
   *Verify:* `tests/server/assets_seam.spec.luau`, the two task-231 cases, and the live read-back
   below.

6. **0.60 was picked by sweeping it on screen, and the result was looked at.** At the aimed eye the
   receiver's flank reads (102, 139, 158) untinted, (76, 111, 131) at 0.85, (58, 90, 111) at 0.75,
   (32, 59, 78) at 0.60 and (10, 29, 43) at 0.45 -- pale ice-blue, then steel, then nearly black.
   SAME-SESSION before/after, one camera, the tint flipped live so no respawn can move the gun: the
   pale fraction of the gun region (luminance > 110) falls from **12.1 % to 1.0 %**, and the receiver
   patch from (95, 126, 146) to (31, 53, 69). Read back off the live instances in a fresh Play:
   `saColor=(153,153,153)` on all three lever groups, `(255,255,255)` on the Rigby's four.
   *Verify:* `.screenshots/231-tint-strip.png` (five frames), `231-zoom-pair.png` (the receiver at
   5x, where the difference is plain), `231-carry-before-after.png`, `231-tint-same-session.png`.
   **At 1x the change is less obvious to my eye than the numbers are -- Karen should judge it, and it
   is one field.**

7. **The phone keep-out is measured at last, and the overlap is worse than 32 px.** Studio's Device
   Simulator, iPhone 17 Pro landscape, viewport 750 x 381, `TouchEnabled` TRUE, read off the engine's
   own `TouchGui`: `JumpButton` is **70 x 70** at screen (655, 291) -- half our 140 x 140 -- and the
   folded rail at (634..738, 244..348) covers the top 57 px of it, leaving **13 px**. Our rectangle
   CONTAINS the real one (conservative in the safe direction) and `Touch.CONFIG.MEASURED` records
   what was read, so a future shrink below the real control fails the suite.
   *Verify:* `tests/client/touch_controls.spec.luau`, case *"contains the jump button that was
   actually measured"*; `.screenshots/231-before-rail-jump-750x381.png`, where the four rail buttons
   sit exactly where the jump button is and it cannot be seen at all.

8. **NO LAYOUT CHANGE, and the reason is arithmetic rather than reluctance.** A single row of four
   clears the real button at 750 x 381 but at 800 x 400 lands on the AIM button at (576..640,
   224..288); bounding the fold by the free width caps it at two columns at both. The right column is
   already triple-booked -- the cluster overlaps the minimap at (642..738, 140..236) today. Both ways
   out belong to other owners (`MapUi`'s minimap, or separating *how far down* from *how far left* in
   the rail's blockers), and `docs/design/mobile-controls.md` 14.4 puts the landscape layout out of
   scope. Written up with the three viewports in `ESCALATE.md`, queued as **231b**. What IS fixed:
   220a(c) `MapUi.setRailColumn` no longer clears a pinned viewport, and 220a(d) `Rail.applyLayout`
   records the columns it settled on when there is no frame.
   *Verify:* `tests/client/map_ui.spec.luau`, case *"keeps a pinned viewport when it is told the
   rail's column"*; `Rail.applyLayout`'s no-frame branch.

9. **`capture` is pinned to a place, and the harness now sees the Device Simulator.** Both faults are
   220a(b)'s. `capture` resolved by ROLE alone, so with two editors connected it shot whichever the
   listing named first -- tasks 220 and 230 both quoted a DEV frame taken in the Forest Test. It
   takes `--place dev|forest|<id>`, defaults to DEV, resolves by a live `game.PlaceId` read and
   prints the id it shot beside the id it was asked for; `studio_for_role` checks the place in its
   MULTI-entry branch too (only the one-entry shortcut did, which is exactly the case that broke) and
   reads it in whichever DataModel the process has, so a capture DURING Play still works. And `test`
   and `test2` REFUSE to start while a device profile is active -- MEASURED in Edit: simulator OFF is
   touch=false/keyboard=true, ON is touch=true/keyboard=false; the viewport is not used (it is also
   whatever the window is) and touch alone is not either (a touchscreen laptop has a keyboard).
   *Verify:* `python tools/studio_mcp.py selftest` cases 9e and 9f; every `[capture]` line in this
   task's own frames reads `place 136410205938347 Driven Hunt DEV, asked for 136410205938347`.

10. **The gate found one real fault in my own spec and it is fixed, not worked around.** Run 1 came
    back 32/34: `assets_seam.spec`'s live case demanded that the lever's pieces be published, and in
    a Studio session whose `InsertService:LoadAsset` does not reach the network the folder is
    published EMPTY -- `ViewmodelAssetsBoot`'s own documented behaviour. It reads that as the
    documented path now and notes the count either way, so the request can say whether it ran.
    *Verify:* the gate's `note [server] assets_seam: lever pieces tinted ...` line.

## What I could not verify

- **KAREN HAS SEEN NONE OF IT.** Two of the four fixes are look items (the receiver's tint, the phone
  layout) and L-008 says she looks first. The Director approved merging looks unseen (2026-10-17);
  the tint is one field and the phone layout is unchanged, so neither is hard to reverse.
- **The AFTER frame for fix 1 has no deer alive in it.** The BEFORE pair does -- the server probe
  read `Boar8=reddeer/hind Boar9=reddeer/calf` alive in the same second the HUD said *"push the
  boars"* and *"6 BOARS"* -- but by the time the fix was in, the drive was at its six-animal cap with
  six boars and released nothing else for two minutes. The after frame shows the words
  (`stay on stand, animals coming`, `6 ANIMALS`) in the same world; the deer pairing is the before
  frame's.
- **Fix 3 has no after frame, because nothing about the layout changed.** The before frame plus the
  measured rectangles are the evidence.
- **Portrait is still unmeasured** (task 220's own open item): the simulator's rotate control was
  driven successfully, but only landscape was read.
- **The touch cluster's placement at 750 x 381 looks wrong to me** -- `above-jump` puts it over the
  minimap -- and it is not in this task's scope. Noted in `ESCALATE.md` as part of 231b.
- **The 1x look at the tint.** See claim 6.

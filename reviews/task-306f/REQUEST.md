# Task 306 step B6 -- ISOLATION, THE PICTURE

Task: 306f
Round: 2
Base: task-306b5-isolation-shot @ 7683369c
Code commit: e3fd345f0387ad3fe36975654fb29f1abc8c1153

`[harness] PASS: 34/34 checks @ e3fd345f0387ad3fe36975654fb29f1abc8c1153 (clean tree) scope=all`

`test2` N/A: no `TWO_PLAYER_PATHS` path is touched. The Director ratified `src/client/Range/` OUT of
that list on 2026-10-28, and `tools/studio_mcp.py` has been with the tools since 2026-10-03.

## PLAN (core quality protocol -- the Director's own line: CORE-NA)

B6 changes no animal behaviour, no ballistics, no kill zone and no shot rule (B5 owns the shot). It
changes the PICTURE and the board payload, so steps 0(a)-(e) are stated as owner and instrument.

- **(b) MEASURED BEFORE.** `src/client/Range/` did not exist; `grep -rln LocalTransparencyModifier
  src/client` named only the three `Camera` files; `publish` sent `{ record, lists }` with no `mine`
  and no `window`. Six men at six stations saw all six animals.
- **(c) TARGET.** Exactly 1 animal drawn per occupied station; writes flat while nothing changes.
- **(d) LEVER.** `BasePart.LocalTransparencyModifier`, written in `Mask.apply` and nowhere else; the
  window predicate is the SHIPPED `RangeData.inWindow`, the same one `Range.ignoredFor` reads.
- **(e) INSTRUMENT.** `tests/client/range_mask.spec.luau`, and in DEV Play a client probe that reads
  the property off every part under `Workspace.RangeTargets`.

## What changed

1. **`src/client/Range/Mask.luau` (new)** -- the one writer of `LocalTransparencyModifier` under
   `Workspace.RangeTargets`. `start/setMine/setWindow/step/stats/stop`, design 4.4's API.
2. **`src/client/RangeBoot.client.luau` (new)** -- starts it, hands it the board payload's `mine`
   and `window`, steps it once a Heartbeat.
3. **`Range.maskFor`** (server) measures those two fields from `boars.rootOf` and
   `RangeData.windowSpanFor`; `Range.recordOf` puts them on every record it hands out, so the
   reader and the wire see one record. **`flushMasks`** pushes to every man at the range whenever a
   trial's `targetId` changes, once per scan tick.
4. **MUST-FIX, 306b note (i) / 306c NOT PROVEN item 1** -- `Range.nearestPrompt` (shared) answers
   which of the TWELVE prompts he is standing at in one walk; `Hud.renderObjective` asks it every second
   instead of only while no prompt is bound; `RangePanel` is TOLD the station and both senders carry
   it; `Range.onRequest` takes the trial from the station it MEASURES.

## Claims, and how to verify each

1. **The mask writes that property and nothing else.** `grep -n "LocalTransparencyModifier\|
   \.Transparency\s*=" src/client/Range/Mask.luau` -- FOUR write sites: two in `apply` and two in
   `stop`, and both `Transparency` ones are under `state.alsoTransparency` (design 4.4's stated
   fallback, off by default, no production caller sets it). Round 1's "two" was a miscount.
2. **Exactly one animal is drawn and five are hidden, every part of them.** `range_mask.spec`
   "shows exactly one and writes 1 on the other five" asserts the trunk AND the welded zone part.
   MEASURED IN DEV PLAY after a real click on RELEASE at station 3's bench: `Boar3 x=1235.4
   ltm=0.00 zones=0/16 hidden`, the other five `ltm=1.00 zones=16/16 hidden`.
3. **His own is hidden outside his own station's window and drawn inside it, on the SHIPPED
   predicate.** `range_mask.spec` "hides his own outside his own window and shows it inside".
   MEASURED at station 5 (window 1278..1314 from `windowSpanFor`), four samples: x=1279.8 -> 0.00,
   x=1322.2 -> 1.00, x=1302.0 -> 0.00, x=1261.3 -> 1.00, with the other five hidden in all four.
4. **T12: the mask is free when nothing changes.** `range_mask.spec` "writes nothing across 60 idle
   steps": `writes` settles at `2 * SPOT_COUNT` = 12 and is the same number after 60 further steps;
   `sweeps` is 61, so the steps did run; `Cursor.stats().reasserts` is unchanged.
5. **The owner boundary with `Camera.Rig` is enforced, not just stated.** `Mask.apply` refuses any
   part under `seams.player.Character` and counts it. `range_mask.spec` "never writes a part under
   the local character" puts a character part INSIDE the folder and asserts it keeps its 0.5, and
   "never touches a part outside its own folder" asserts the other direction.
6. **`stop` restores every value it wrote, including a non-zero one.** `range_mask.spec` "stop
   restores every value it wrote": a trunk that shipped `0.25` is hidden, then restored to `0.25`.
7. **The board payload carries his OWN trunk and his OWN window.** `range.spec` "maskFor names HIS
   trunk and HIS window, and never another station's": at station 4 it returns `fake.at(4).root` and
   `windowSpanFor(ANCHOR, 4)`, asserted `never.to.equal` station 1's edge, and the trunk is the one
   `ignoredFor` leaves out. Off-station -> nil, nil. No animal released -> the window, no trunk.
8. **MUST-FIX: all twelve prompts resolve, each to ITS OWN station.** `range.spec` "nearestPrompt
   finds all TWELVE": from each mat it returns that station's BENCH prompt, from each deck that
   station's TREESTAND prompt, and the set reached is counted `== 2 * SPOT_COUNT`.
   MEASURED IN DEV PLAY: on station 3's mat `nearestPrompt=RangePrompt3 spot=3 position=bench`; on
   station 5's deck `nearestPrompt=RangeStandPrompt5 spot=5 position=treestand`. It is CAPPED at
   `layout.PROMPT.MaxActivationDistance` (round 1 note), the same number `atSpot` measures with, so
   the panel is never told a station he is nowhere near; the twelve cases bound the cap from below.
9. **MUST-FIX: the station is MEASURED, never claimed; the menu's senders carry what they were
   told.** `range_panel.spec` "carries the station it was TOLD, in both senders, and defaults to 1";
   `range.spec` "onRequest lands on the station he is STANDING on, whatever the payload claims":
   a man on station 5 sending `spot = 1` moves station 5's trial and NOT station 1's, and his
   record reads `spot = 5`; `{ spot = 0, go = true }` still returns false and counts a badRequest.
10. **ROUND 1, FINDING 1 -- the picture does not go blank after a re-release.** `record.mine` is
    an INSTANCE; `release` makes a new trunk and `boars.clear` destroys all six at once, so without
    a push on that edge a man held a destroyed trunk and his own new animal stayed hidden until his
    next shot. `Range` now remembers the men its own seams handed it (`state.watchers`, filled in
    `recordFor`), marks `maskDirty` wherever a `targetId` changes, and `flushMasks` pushes ONCE per
    scan tick. `range.spec` "pushes the new trunk on every re-release, to every man at the range"
    asserts it **on the wire** through a fake `RangeBoard` injected with the shipped
    `Range.setRemotes` seam: a payload after the pick naming his trunk, a NEW payload after a clear
    and re-release naming a DIFFERENT instance **with no shot fired**, `#sent - before <=
    SPOT_COUNT` for the batching, and the `targetId == nil` arm reached through a real species pick.
    Reading `Range.recordOf` instead would measure `maskFor` again and pass with the push deleted.
    **FAIL FIRST, run:** with `flushMasks()` commented out of `scan` at `e3fd345f`, the harness
    reported `2536 passed, 1 failed, 1 errors` with the failure at `range.spec:3310`
    (`expect(#sent > 1)` got false) -- that case and no other. Restored, then the clean 34/34 above.

## CLICK PROOF, in DEV Play (frames looked at and described)

- `<runs-dir>/306b6-menu-station3.png` -- a real `E` at station 3's bench. The SHOOTING RANGE menu
  is on screen with its six rows and RELEASE THE TARGET; THE BOARD below it reads `DISTANCE 125
  studs (35 m)`, `BOAR male at shotgun / SLUG`. The lane behind it is EMPTY -- no animal is drawn,
  which is the mask with nothing yet told (`mine = nil`, all six hidden, measured `ltm=1.00 16/16`).
- `<runs-dir>/306b6-menu-station5-stand.png` -- a real `E` on station 5's treestand deck. The same
  menu, from 15.6 studs up, and THE BOARD reads **`no shots yet`** -- a different record from
  station 3's, which is what a per-station menu looks like.
- **T3 is the Director's two-client step. The exact steps:** `python tools/flags.py set RANGE on`;
  `python <runs-dir>/devplay.py start`; `python tools/studio_mcp.py test2`-style second client, or
  two Play clients; put client A on station 3's mat (`Workspace.Range.Mat3`) and client B on station
  5's deck; press `E` and RELEASE on each; then on EACH client run `<runs-dir>/306b6-ltm.luau`
  (reads `LocalTransparencyModifier` on every part under `Workspace.RangeTargets`) and take one
  screenshot per client. PASS is: A reads `Boar3 ltm=0.00` with five at `1.00`, B reads
  `Boar5 ltm=0.00` with five at `1.00`, at the same instant. Finally `python tools/flags.py clear`.

## What could NOT be verified

1. **No single-client frame shows the drawn animal down the lane.** The client `Camera` owner
   re-asserts within 0.3 s, so `devcap.py` returns the player's eye whatever camera is passed, and
   from both firing positions a DEV surface fills the lower half of that view; a 4x crop of the
   horizon band (`306b6-crop-horizon.png`) could not be read as an animal. This is the SAME gap
   `b306b5-result.json` recorded. The property reading above is the instrument that did answer, and
   T3's two client screenshots are the Director's step.
2. **A tool artefact, reported not worked around (rule 6).** At station 5's deck real `E` presses
   alternated: press 1 no menu, press 2 menu, press 3 no menu, press 4 menu, with the character
   measured at a constant 4.1 studs from the prompt (reach 12) throughout. The most likely cause is
   `<runs-dir>/key.ps1`'s own Alt tap (the foreground-lock trick) toggling Studio's menu bar and
   swallowing every other `E`, not the game: at station 3 the first press opened it, and the panel's
   own toggle behaved as a clean toggle from press 2 on. Not reproduced through a second route.
3. **Three round-1 notes are QUEUED, not fixed, and are named here so the verdict is not read as
   their having been done:** (a) `Mask.step` has no throttle -- it walks every trunk's descendants
   each Heartbeat, so "free when nothing changes" is about WRITES, not allocation; (b) design T14
   and section 4.4 say `src/client/Range/` never writes `Transparency`, while 4.4's own fallback
   bullet is exactly that write -- the design contradicts itself and needs restating as "none on
   the shipped path"; (c) the alternating-`E` item below deserves its own task.
4. **The skinned-mesh fallback is UNTAKEN.** `alsoTransparency` is off; design section 14 item 8 is
   still unverified. Both arms have their own case, and the DEV animals hid on the modifier alone.

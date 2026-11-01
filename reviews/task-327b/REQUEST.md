# Task 327b: THE STANDS AND THE TOWERS

Task: 327b
Round: 3
Base: e7131a94 (main, with 327a merged as #310)
Code commit: 2b2a55d16a23065cb4efc1e0f532f737e56cde4f

```
[harness] PASS: 34/34 checks @ 2b2a55d16a23065cb4efc1e0f532f737e56cde4f (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 2b2a55d16a23065cb4efc1e0f532f737e56cde4f (clean tree)
```

Both ran ONCE and passed; no known flake and no known intermittent fired. `test2` is required because
the BRANCH touches `src/server/Match/` (round 1); round 3's own files do not.

This round is the Director's decision **C** on round 2's single finding (`ESCALATE.md`, top entry,
commit e3dbf0f1): keep the preview cell as the live layout and close ONLY the deal, plus the flag's
`why` sentence and `Markers.build`'s missing entry. Everything else in round 2's notes is queued as
**327b-notes**: the beater walk is 327d, `MapUi` is 327f, the flank facing is 327g.

## Claims

1. **On a layout with `sides`, the walk IS `Grid.standWalk`** -- `ForestTest.standWalk`
   (`src/server/ForestTest/init.luau`) returns `Grid.standWalk(chosen.layout.name)` when
   `chosen.layout.sides ~= nil`, and that is the list `ForestTestBoot`'s `placement` hands
   `HighSeats.dealLine`. Verify: `grid.spec` / "the stand walk" / "deals the first hunter of a cell
   the MAIN stand hunterStandX aims at" promotes `Grid.PREVIEW_CELL` and asserts
   `ForestTest.standWalk()` equals `Grid.standWalk(id)` entry for entry.
2. **`standIndexFor` reads that same walk, so there is still ONE walk per layout** --
   `ForestTest.standIndexFor` indexes `ForestTest.standWalk()` modulo `#walk` on a cell. That is what
   keeps `ForestTestBoot`'s fallback (`deal[index] or ForestTest.standIndexFor(index)`) and
   `Match`'s bot order from disagreeing with the deal. Verify: the same case asserts
   `deal[1] == ForestTest.standIndexFor(1)`.
3. **The first hunter of a cell is dealt a MAIN stand** -- `Grid.sideOf(id, deal[1])` is `"main"`,
   asserted for BOTH entitlement shapes: `entitled = nil` (today's world) and `entitled = {false}`
   (the hunter barred from every seated stand), because C1's three seats are flank posts. Round 2's
   finding named stand 8 (west flank) and stand 7 respectively.
4. **...and it is the stand `hunterStandX()` aims at** -- `ForestTest.defaultPickIndex` is the walk's
   first stand, and `ForestTest.hunterStandX` and `ForestTest.openPick` both read it. Verify: the
   same case asserts `ForestTest.hunterStandX()` is `Data.standX(deal[1], layout)` within 1e-6.
5. **FAIL FIRST, for claims 1-4.** With `ForestTest.standWalk`'s `sides` arm removed, the cell's walk
   is the derived centre-out over 15 and `deal[1]` is **8**, so claim 1's entry-for-entry comparison,
   claim 3's `"main"` and claim 2's equality all fail; with `defaultPickIndex`'s `sides` arm removed,
   `hunterStandX()` is `standX(5)` = `centre.X + 150` and claim 4's `near` fails by 150 studs.
   Argued by READING, not by a reverted run: the case was written against the round-2 verdict's own
   arithmetic, and its live counterpart (claim 7) is the measurement.
6. **The ROAD's branch is unmoved (L-093)** -- neither function's `else` arm changed, and
   `defaultPickIndex` on a layout without `sides` is `math.min(Data.PICK.defaultIndex,
   standCount)`, which is what every caller got before. Verify: `forest_stand.spec` still pins
   `standIndexFor(1) == Data.PICK.defaultIndex == 5`, 2 -> 4, 3 -> 6 and the wrap; and the new case
   re-asserts `standIndexFor(1)` and `defaultPickIndex()` are both 5 after it restores the default
   layout. The full suite is green (34/34).
7. **LIVE PROOF, in Karen's Forest Test at this code commit** (driven-hunt-294 on rojo :34874,
   `DHFlag_GRID_PREVIEW` set as a place attribute for the proof and removed after; her other 14
   `DHFlag_*` read identical before and after). One Play session, one human hunter:
   - boot: `grid preview cell C1: 15 of 15 post(s) (7 line), 3 tower(s) at {8,13,15}, line=true,
     complete=true` and `layout=C1 (override)`;
   - the server's own lines: *"is walking to stand 4 this intermission"* and *"has the pick window
     open on stand 4"*;
   - the hunter's real `HumanoidRootPart` at **(-3899.0, 111.7, -5107.0)**, which is the live
     `ForestMarkers.Stand4` part at **(-3899.0, -5107.0)** -- cell C1's main-road centre;
   - the three DriveBots at **-4049 / -3749 / -4199**, all at z = -5107, i.e. main stands **3, 5, 2**
     -- `Grid.standWalk("C1")` = 4,3,5,2,... exactly;
   - a probe of the synced code in her place: `dealt=4 side=main default=4 hunterStandX=-3899.0
     standPos=(-3899.0,-5107.0) Stand4Marker=(-3899.0,-5107.0) deal4=4,3,5,2`.
   The dealt stand and `hunterStandX()` are the same main stand. Whole console: 0 "Stack Begin",
   0 "attempt to", 0 "invalid argument".
8. **`GRID_PREVIEW.why` now says what the flag does** (`src/shared/Flags/init.luau`): one cell built
   and made the LIVE layout with its fifteen Stand markers and three high seats, it is for WALKING
   the cell, and a drive in it is not judged until 327d because the beaters still walk
   `Bots.CONFIG.WALK_SPEED` 3.1 rather than the 5.2 a 1430-stud cell needs. Verify: read the row.
9. **`Markers.build` refuses a set with no main-line post** (`src/server/ForestTest/Markers.luau`):
   `#linePosts == 0` adds a `forest:line-posts (0 of %d)` entry to `missing` AND is a term of
   `complete`. The second half is not decoration -- `Phase.waitingFor` reads `missing` only while
   `markersComplete` is false, so the entry alone would be a string nobody acts on. Round 2's note
   asked for the entry; this is the entry plus the thing that makes it bite. Verify: read
   `Markers.build`'s tail; the live C1 set has 7 line posts and is `complete=true` (claim 7).
10. **Two comments the change made false were rewritten, not left** -- `ForestTestBoot`'s `middleX`
    comment (*"It is NOT what `hunterStandX` answers"*) and `placement`'s header (*"a solo hunter
    gets stand 5"*). Verify: read both in `src/server/ForestTestBoot.server.luau`.

## What I could not verify

- **Rule 5 is MINE, not Karen's.** She has not walked the cell. The frame I took is the hunter's own
  eye at stand 4 (`<runs-dir>/327b-r3-aerial.png`, the client view, camera at the character's eye
  height): he stands on the bare dirt of the main road with the yellow pick-edge ring round him and
  open grass running north into the cell, HUD `DRIVE 1 / 2:20 / HUNTER`, no error banner.
  `ftplay.py capture` returns the PLAYER's view and ignores its camera arguments in Play, so there is
  **no aerial of the ring of 15** this round either.
- **`hunterStandX()` could not be read off the LIVE module instance.** The StudioMCP probe thread
  gets a FRESH `ForestTest` (it answered `layout=road` on the first attempt), so claim 7's
  `hunterStandX=-3899.0` is the synced code in her place computing it with C1 promoted in the
  probe's own copy and no picks -- not a read of the running server's own variable. The instance
  facts beside it (the hunter's root part, the Stand4 marker, the three bots) are the running
  world's, and they agree with it.
- The `#linePosts == 0` path was not reached live: every C1 stand built (15 of 15, 7 line).

## Answers to the dispatch's learning flags

- ANSWERED: L-136 -- no flake fired. `weapon_shot.spec.luau:1490` passed; `test` and `test2` each
  ran once and passed at the code commit, so there is no FAIL line to call known.
- ANSWERED: L-127 -- MET / NOT PROVEN is per item in the report's handover block; the two NOT PROVEN
  items are named under "What I could not verify" above.
- ANSWERED: L-162 -- every live reading in claim 7 is at `2b2a55d1`, checked out in
  `driven-hunt-294` and served on :34874 before the Play session started.
- ANSWERED: L-014 -- `driven-hunt-karen` was never checked out, touched or served; the port switch
  was in the Studio panel only.
- ANSWERED: L-139 -- the switch back to :34873 is verified two ways: the Rojo panel reads
  `localhost:34873`, connected; and `Get-NetTCPConnection` on the Forest Test Studio process shows
  two ESTABLISHED connections to 127.0.0.1:34873 and none to :34874.
- ANSWERED: L-095 -- round 1's prompt was re-read in full and its route followed, including the
  port-script fallback and `shot.ps1`. `rojo-port.sh`'s baked click points are STALE (Disconnect is
  at y=862, not 900); the blind run missed every button and only changed the Explorer selection, so
  every click after it was computed off a fresh frame.
- ANSWERED: L-093 -- claim 6: the road branch keeps `forest_stand.spec`'s cases and the new case
  re-asserts it after restoring the default layout, so the `if sides` fork has both arms tested.
- ANSWERED: L-028 -- the FAIL-FIRST argument is claim 5, and it says on its own line that it is
  argued by reading rather than by a reverted run.

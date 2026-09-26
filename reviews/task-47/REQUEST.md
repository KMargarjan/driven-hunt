# Task 47 — audit-004's two must-fix items, and the ADS defect Karen would have seen

Task: 47
Round: 1
Base: `1478854` (task-45-hygiene; stacked on 44, 43, 41, 38, 36 and 35, none merged)
Code commit: `61841d29a34f9faa38ccdee6bdf2cc9752594b44` — this request's own commit, which is what
both harness lines name (CLAUDE.md git workflow step 4, as Task 45 rewrote it). The last commit that
changed `src/`, `tests/` or `tools/` is `3531708`, and only this fill-in changed after it.

Harness, clean tree, one player:

    [harness] PASS: 27/27 checks @ 61841d29a34f9faa38ccdee6bdf2cc9752594b44 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: 30/30 checks @ 61841d29a34f9faa38ccdee6bdf2cc9752594b44 (clean tree)

303 server specs (302 before this task), 73 shooter-client and 67 driver-client (70 and 64 before).
The Director recorded `CountCells() = 0` before the two-player run, which is claim 10's check made
by a second pair of hands.

## What changed

`docs/architecture/audit-004.md`'s two must-fix items, and audit-003's F1 — the one item in either
audit that Karen would have seen with her own eyes.

## Claims

1. **The terrain is read, not assumed, and the false-PASS path is closed** — audit-004 must-fix 1.
   `Workspace.Terrain` is a global singleton with no container, so destroying `Workspace.DrivenHuntMap`
   in the Explorer left the whole heightfield in the place while every check still passed.
   `Ground.cells()` wraps `Terrain:CountCells`; `MapGen.clear` returns `cellsAfter` **measured** where
   `terrainCleared = true` used to be a literal; **the clear step fails** when cells remain instead of
   letting 267 steps write over them; `mapgen.py`'s census prints the count and refuses a mutating
   command when terrain is orphaned; `map_contract.spec` asserts the terrain the named world requires.

2. **All four were proved against the real thing, not argued.** I built the map, deleted
   `Workspace.DrivenHuntMap` through `execute_luau` — the Explorer right-click the audit describes —
   and then:

       (census)   Terrain: 3105004 cell(s)
       (build)    [mapgen] REFUSED: Workspace holds 3105004 terrain cell(s) and no DrivenHuntMap …
       (harness)  failed [server] map_contract.spec:103 the world is the arena but Workspace.Terrain
                  holds 3105004 cell(s): a generated map was left behind. Run `python tools/mapgen.py
                  clear --backup census`.
                  [harness] FAIL: 23/27 checks @ 09b8f06 (clean tree)
       (clear)    "cellsBefore": 3105004, "cellsAfter": 0, "terrainCleared": true

   Before this task that state was a clean `[harness] PASS`.

3. **`clear` is exempt from its own refusal.** The orphan refusal names `mapgen.py clear` as the cure,
   so refusing `clear` would hand the operator a message pointing at the command just refused. The
   exemption is one condition and is commented as such; every other mutating command is refused.

4. **In ADS the real gun is no longer drawn beside the viewmodel** — audit-003 F1, never queued until
   this task. `Rig.setLocalBodyHidden` cached the character's parts once per life and wrote them only
   when the flag changed, so the shotgun's `Handle` — granted on `CharacterAdded` and reaching the
   client after the camera's first render step — was in no list and was never hidden. The walk stays
   off the frame path (the budget is 0.3 ms); `DescendantAdded` now keeps the list true and hides a
   part **as it arrives** while the body is hidden, and `DescendantRemoving` keeps the list from
   growing across a life of accessory churn.

5. **A client spec that fails before the fix.** `describe("the hidden local body")` in
   `tests/client/camera_client.spec.luau`: one test parents a part to the character **after** the body
   is hidden — the same arrival the `Handle` makes — and the run at `09b8f06` shows it failing in
   exactly the shape the audit predicted:

       failed [client] camera_client.spec:376 a part parented to the character while the body was
       hidden kept LocalTransparencyModifier = 0.0: in ADS that is the real gun drawn beside the
       viewmodel (audit-003 F1)

   The other two assert that every `BasePart` of the character is at 1 while hidden, and back at 0
   when the flag clears.

6. **That failure was mine, not the fix's, and the measurement says so.** `DescendantAdded` is
   **deferred**, not synchronous: a probe that parented a part and read the value in the same breath
   saw `synchronous=false ; afterOneWait=true`. The test waits up to 3 s now and re-asserts the flag on
   each pass, because `Camera.step` lowers it from the real aim blend while the test waits.
   Re-asserting cannot make it pass by itself — `setLocalBodyHidden` writes only the parts in its own
   list, and the defect is that the late arrival was never in that list.

7. **The fix is confirmed in a live Play session, not only in a spec.** With right mouse held, the
   client reported: `parts=18 visible=0 Handle ltm=1.0 tool=Shotgun`. Eighteen character parts, the
   Tool's `Handle` among them, all at `LocalTransparencyModifier = 1`.

8. **Twenty-five findings that existed only inside an audit file are now rows** — audit-004 must-fix 2.
   audit-003's F1–F12 and L1–L13 are `TASKS.md` row 47b, and audit-004's own F1–F11 are row 47c, each
   classified with Task 38's G / T / D / L letters, in the shape rows 12–16 already have. F1 is marked
   done in this task; the rest carry what they block.

9. **Nothing else changed.** `git diff --stat 1478854..3531708`: `TASKS.md`, `Rig.luau`, two `MapGen`
   files, two specs and `tools/mapgen.py`. No new step, no new feature, and the generator still builds
   268 steps to the same digest `c9b8a30…`.

10. **The place is clean.** `python tools/mapgen.py census` prints `Camera`, `Terrain` and
    `Terrain: 0 cell(s)`, so the harness lines above are about the arena and nothing else.

## What I could not verify

* **The ADS screenshot shows no second gun, and that is all it shows.** `.screenshots/ads-body-hidden.png`
  is the viewmodel filling the lower centre of the frame with the HUD around it: one gun, no body, no
  second shotgun. It is also a very large wooden block — how the ADS framing FEELS is Karen's, and the
  viewmodel offsets are already queued (audit-003 L6).
* **The 22-second wait before the capture is a sleep, not a handshake.** It worked; a slower load would
  photograph a character that has not spawned. The harness's own ready handshake is the right tool and
  this script is not part of the harness.
* **Neither audit's remaining F and L items were fixed** — only queued, which is what must-fix 2 asked
  for. Several are sharp (47c F1 can leave the live server arming everybody; 47c F3 puts a wrong seed
  in the record M2.5 will be built from).
* **Measurement B (tags across save + reopen)** is still open from Task 43.
* **The terrain check is `CountCells() == 0` for the arena**, which is exact, and `> 0` for the map
  branch, which is weak: it cannot tell the committed seed's terrain from any other. That is what
  `MapGen.markerDigest` and row 43a(g) are for, at M2.5.

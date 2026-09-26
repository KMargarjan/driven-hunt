# Task 47 — audit-004's two must-fix items, and the ADS defect Karen would have seen

Task: 47
Round: 2
Base: `1478854` (task-45-hygiene; stacked on 44, 43, 41, 38, 36 and 35, none merged)
Code commit: `PENDING` — this request's own commit, which is what both harness lines name (CLAUDE.md
git workflow step 4). The last commit that changed `src/`, `tests/` or `tools/` is `9bed8e3`.

Harness, clean tree, one player:

    HARNESS1_LINE

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    HARNESS2_LINE

303 server specs (302 before this task), 74 client (70 before).

## What changed

`docs/architecture/audit-004.md`'s two must-fix items, and audit-003's F1 — the one item in either
audit a player would have seen. Round 1 found two real defects, one of them introduced by this task's
own fix; both are below as claims 5 and 8.

## Claims

1. **The terrain is read, not assumed** — audit-004 must-fix 1. `Workspace.Terrain` is a global
   singleton with no container, so destroying `Workspace.DrivenHuntMap` left the whole heightfield in
   the place while every check passed. `Ground.cells()` wraps `Terrain:CountCells`; `MapGen.clear`
   returns `cellsAfter` **measured** where `terrainCleared = true` used to be a literal; the clear
   **step** fails when cells remain rather than letting 267 steps write over them; `mapgen.py clear`
   branches on the same measurement and exits non-zero; the census prints the count and refuses a
   fresh build over orphaned terrain; and `map_contract.spec` asserts the terrain the named world
   requires — `CountCells() == 0` for the arena, `> 0` for the map.

2. **Proved against the real thing.** I built the map, deleted `Workspace.DrivenHuntMap` through
   `execute_luau` — the Explorer right-click the audit describes — and then:

       (census)   Terrain: 3105004 cell(s)
       (build)    [mapgen] REFUSED: Workspace holds 3105004 terrain cell(s) and no DrivenHuntMap …
       (harness)  failed [server] map_contract.spec:103 the world is the arena but Workspace.Terrain
                  holds 3105004 cell(s): a generated map was left behind. Run `python tools/mapgen.py
                  clear --backup census`.
                  [harness] FAIL: 23/27 checks @ 09b8f06 (clean tree)
       (clear)    "cellsBefore": 3105004, "cellsAfter": 0, "terrainCleared": true

   Before this task that state was a clean `[harness] PASS`.

3. **The refusal knows which states are legitimate** (round 1, finding 2 — right, and it would have
   cost the retry). A build calls `ensureRoot()` for the first time in the **hedgerow** step, so
   through all 256 terrain steps Workspace holds terrain and no map root: exactly what the first guard
   called orphaned. It would have refused `mapgen.py step`, the documented way to resume a build, and
   told the operator to `clear` the partial build they were resuming. Only `build` and `verify` are
   refused now; `step` and `clear` are exempt, and the comment says why for each.

4. **In ADS the real gun is no longer drawn beside the viewmodel** — audit-003 F1, never queued until
   this task. `Rig.setLocalBodyHidden` cached the character's parts once per life and wrote them only
   when the flag changed, so the shotgun's `Handle` — granted on `CharacterAdded` and reaching the
   client after the camera's first render step — was in no list and was never hidden. The walk stays
   off the frame path (the budget is 0.3 ms); `DescendantAdded` keeps the list true and hides a part
   **as it arrives** while the body is hidden.

5. **A part that LEAVES the character is restored before it is dropped** (round 1, finding 1 — right,
   and the defect was mine, introduced by the fix above). `forgetHiddenPart` removed a part from the
   list still at `LocalTransparencyModifier = 1`, and `Rig` is the only writer of that property on the
   local character, so nothing put it back. The player's path: aim, then unequip with `1` while the
   right button is down — the Tool reparents to the Backpack, its `Handle` leaves at 1, the blend
   decays, and **the player's own gun is invisible in third person for the rest of that life**. It is
   restored before being dropped now.

6. **Four client specs, and each one failed before its fix.**
   `describe("the hidden local body")`: a part that arrives after the body is hidden is hidden; every
   part the character has is at 1 while hidden; a part that leaves while hidden comes back to 0; the
   body returns to 0 when the flag clears. The arrival test failed at `09b8f06` in exactly the shape
   the audit predicted — `kept LocalTransparencyModifier = 0.0: in ADS that is the real gun drawn
   beside the viewmodel` — and the departure test fails without claim 5's restore.

7. **Two measurements, both of which corrected me rather than the code.** `DescendantAdded` is
   **deferred**, not synchronous (`synchronous=false ; afterOneWait=true`), so a test that parents a
   part and reads in the same breath sees the old value; and reading *after* a `task.wait()` is always
   reading just after a `Camera.step` that set the flag from the real aim blend and wrote every listed
   part back to 0. Both loops now set and read in the same resumption, with a deadline.

8. **The probes are inert and off the world origin** (found by the harness, not by me arguing). Both
   were 1-stud anchored parts with no `CFrame`, so they sat at the **world origin inside the arena**
   for the length of a 3 s wait — while `weapon_client.spec` fired live rounds — and its ammo counts
   moved by one. They are on the character now, `Transparency = 1`, `CanCollide`/`CanQuery`/`CanTouch`
   false, and the departing one goes to the Backpack, where the Tool actually goes.

9. **The fix is confirmed in a live Play session, not only in a spec.** With right mouse held, the
   client reported `parts=18 visible=0 Handle ltm=1.0 tool=Shotgun`: eighteen character parts, the
   Tool's `Handle` among them, all hidden.

10. **Twenty-five findings that existed only inside an audit file are now rows** — audit-004 must-fix
    2. audit-003's F1–F12 and L1–L13 are `TASKS.md` row 47b and audit-004's own F1–F11 are row 47c,
    classified with Task 38's letters, in the shape rows 12–16 already have.

## What I could not verify

* **The ADS screenshot shows no second gun, and that is all it shows.**
  `.screenshots/ads-body-hidden.png` is the viewmodel filling the lower centre with the HUD around it:
  one gun, no body. It is also a very large wooden block — how the ADS framing FEELS is Karen's, and
  the viewmodel offsets are already queued (audit-003 L6, row 47b).
* **The capture script waits 22 s for the character rather than using the harness's ready handshake.**
  It worked; a slower load would photograph an empty world.
* **Neither audit's remaining F and L items were fixed** — only queued, which is what must-fix 2 asked
  for. Two are sharp: 47c F1 can leave a live server arming everybody after one genuine failure, and
  47c F3 puts a wrong seed in the record M2.5 will be built from.
* **The map-branch terrain check is only `> 0` cells.** It cannot tell the committed seed's terrain
  from any other; that is `markerDigest`'s job at M2.5 (row 43a(g)).
* **Round 1's other notes are queued, not fixed**: `verifyContract`'s early return omits three fields
  against its declared type (45a(c)), `Camera.stop()` leaves the two connections attached, the design
  still declares the old `MapGen.clear` signature, and row 47b's L items carry one collective letter
  rather than one each.

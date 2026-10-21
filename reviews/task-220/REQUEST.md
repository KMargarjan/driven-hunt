# Task 220 — review request: the game plays on a phone (touch controls)

Task: 220
Round: 1
Base: `4e0f4f7d` (origin/main)
Code commit: `ca3394cb5d05543a42fa54ad50e7a65b9ea3bc03`

```
[harness] PASS: 33/33 checks @ ca3394cb5d05543a42fa54ad50e7a65b9ea3bc03 (clean tree) scope=all
```

`test2` is **N/A**: nothing changed under `TWO_PLAYER_PATHS`. The changed code paths are
`src/client/Hud/`, `src/client/Weapon/Input.luau`, `tests/client/`,
`tests/server/lobby.spec.luau` and `tools/studio_mcp.py` — the harness itself is explicitly with
the tools (Director, 2026-10-03). The line above is `scope=all`, so it is full evidence for the PR
to `main` as well as for this round.

## What changed

A touch player could move, look and jump, and could reload and change shell from `Hud.Rail` — and
had **no way to fire, aim, change weapon or blow a horn**. A new sibling `Hud.Touch` owns a
168 × 160 cluster of four buttons beside the engine's jump button. `Weapon.Input.fire` and
`Input.setAim` / `toggleAim` became public and the `ContextActionService` handlers became two-line
callers of them, so the mouse and the thumb run one implementation. The rail now **folds** so it
fits on a landscape phone. **Zero new remotes, flags or ScreenGuis.**

## Claims, and how to verify each

1. **Three engine facts were MEASURED, not remembered.** The research note (§3) forbids the design
   resting on an unmeasured one. `reviews/task-220/BRIEF.md` §0 records all three with their
   probes: `tool:Activate()` from a LocalScript fires the **server's** `Tool.Activated`
   (`SERVER activated=2` for two client calls); `Humanoid:EquipTool()` from a LocalScript lands the
   Tool in the character on the server; `ProximityPrompt.ClickablePrompt` defaults to **true**.
   *Verify:* read `BRIEF.md` §0 and the probe files it names in `<runs-dir>`.

2. **One path to the server, asserted by IDENTITY.** `Touch.actionFor("FIRE") == Weapon.Input.fire`,
   and the same for AIM / SWAP / BLOW. `Weapon.Input` is still the only firer of `FireRequest` and
   the only keeper of the aim flag; `onFire` / `onAim` call `Input.fire` / `Input.setAim`.
   *Verify:* `grep -n "FireRequest" src/` finds one firer; the case *"calls Weapon.Input's own
   functions, proved by identity"* in `tests/client/touch_controls.spec.luau`.

3. **No new remote and no new flag anywhere in the task.**
   *Verify:* `git diff 4e0f4f7d..ca3394cb -- src/` contains no `RemoteEvent`, no `FireServer` that
   is not already `Shotgun.remotes()`, and `src/shared/Flags/init.luau` is untouched.

4. **The lobby interact gained NO button**, because M3 says the prompt is already tappable. The only
   change is one assertion on the prompt the real `Build` makes.
   *Verify:* `tests/server/lobby.spec.luau` now asserts `p.ClickablePrompt == true`; no source file
   under `src/server/Lobby/` changed.

5. **The geometry is pure and is asserted at five viewports.** `Touch.rect`, `Touch.buttonRect`,
   `Touch.reserved`, `Touch.placement`, `Hud.cornerRect`, `Hud.leftStackRight`, `Rail.layoutFor`,
   `Rail.floorFor`, `Rail.columnsFor` and `Rail.slotFor` read nothing. The intersection set is
   **empty** at 400 × 800, 800 × 400, 800 × 600, 969 × 784 and 1920 × 1080, with **one** named
   exclusion (claim 8) and three members excluded with reasons written into the test.
   *Verify:* the cases *"overlaps NOTHING, at five viewports"* and the two
   *"...exactly where the design says..."* cases in `touch_controls.spec`.

6. **The rail fits on a phone now, and nothing on a desktop moved.** Before: `Rail.topFor(96, 140)`
   + `Rail.heightFor(4)` = **510 on a 400 px tall screen**, so RELOAD and AMMO were off the bottom.
   After: it folds to 2 × 2 at both phone viewports and stays **one column, pixel-identical** at
   800 × 600, 969 × 784 and 1920 × 1080.
   *Verify:* the cases *"folds into two columns on a phone and into one on every desktop"* and
   *"is pixel-identical to before the fold at every desktop viewport"*; and claim 9's live reading.

7. **`MapUi` lost a writer rather than gaining one.** `MapUi.applyLayout` no longer writes the rail
   frame's `Position`; `Rail.applyLayout` does, and `MapUi` is told the column width
   (`MapUi.setRailColumn`). The removed lines are archived with their reasoning.
   *Verify:* `grep -n "railFrame" src/client/Hud/MapUi.luau` finds nothing;
   `backups/2026-10-21_mapui-rail-position.md` (rule 7); `Rail.columnPx(1) ==
   MapUi.CONFIG.RAIL_COLUMN_PX` is asserted.

8. **A REAL HOLE, REPORTED RATHER THAN ASSERTED AWAY: at 800 × 400 the rail cannot clear the
   engine's jump button.** The minimap's bottom is y 236 and the JUMP keep-out's top is y 260 —
   **24 px** of free right-edge column, and the smallest button in this design system is 48. No
   fold helps: more columns move the rail's *left* edge left and leave its right edge at the
   margin, inside the jump button's x-range whatever happens. It is the single entry in
   `ALLOWED_TO_TOUCH` with that measurement beside it, it is **visible in the landscape frame**,
   and a real landscape layout for the top band and the right column is the Designer's — named as
   out of scope in the design (§14.4) and queued as 220a.

9. **MEASURED LIVE IN STUDIO'S DEVICE SIMULATOR (iPhone XR, landscape), which answers the design's
   own open question.** The design (§13.5) says *"whether the emulator sets `TouchEnabled` is
   unverified"*. **It does.** At viewport **801 × 413**, `touchEnabled=true`:
   `clusterVisible=true` with `FIRE`, `AIM`, `SWAP` drawn and `BLOW` hidden (a hunter carries no
   horn); cluster at **x 473..641, y 237..397**, which is `Touch.rect`'s answer exactly; the rail
   **folded to 104 × 104** at y 244..348 — all four buttons on screen; and the chip moved by
   exactly `Touch.reserved` = **(144, 168)**. Frame: `<runs-dir>/t220-touch-landscape.png`,
   **inspected** (rule 5).

10. **The gate found three real faults and they are fixed, not worked around.** Commit `9f7f8902`:
    the spec left the player holding the wrong Tool (`blowHorn` equips the horn, and
    `weapon_client.spec` asserts four bound actions that exist only with a gun in hand — it failed
    with 0); the spec modelled a different rail floor from the renderer; and the 800 × 400
    rail/jump collision is claim 8. Commit `ca3394cb`: the exclusion key was order-sensitive.
    *Verify:* those two commit messages, and `493 passed, 0 failed` on the client.

## What I could not verify (rules 6 and 8)

- **PORTRAIT HAS NO FRAME.** The emulator's rotation control exited the simulator instead of
  rotating, and I did not get a usable portrait frame. Portrait geometry is asserted
  arithmetically at 400 × 800 only. Landscape is the first-class layout by the design's own
  decision, and it IS frame-verified.
- **A TAP.** No spec can fire `GuiButton.Activated` and the harness cannot synthesise a touch, so
  `Touch.press` is the seam every case drives and what it proves is the **action**, not the touch.
  `Hud.Rail`'s own limitation, queued as 165a.
- **THE KEEP-OUT RECTANGLES ARE STILL OURS.** 140 × 140 and 180 × 180 are our constants; Roblox
  publishes no size. The spec case that reads the real `TouchGui` runs only when `TouchEnabled` is
  true, and on the desktop gate it did **not** run and says so through `TestKit.note`. The
  landscape frame shows our JUMP estimate is about right, but that is an eye, not a measurement.
- **A BEATER'S BLOW END TO END.** The one-player gate is a hunter
  (`Match.CONFIG.ODD_PLAYER_TEAM = "Shooters"`), so no horn is granted. The spec proves the client
  half with its own Tool; the server half is `zz_horn.spec`'s, unchanged.
- **A HARNESS FAULT, REPORTED (rule 6):** `python tools/studio_mcp.py capture` wrote its frame to
  the **Forest Test** Studio (`place 130094961655666`) while every other call in the same session
  went to DEV — the class of defect task 226 fixed for `flags.py`. The frame above was taken with a
  place-pinned driver instead. Queued as 220b.
- **`Touch` captures `touchEnabled` at `start`**, as `Rail` does, so toggling the Device Simulator
  **mid-session** leaves the cluster drawn on a desktop. A real device does not change mid-session;
  noted because I saw it.
- **Whether the picture is right.** Karen's eye.

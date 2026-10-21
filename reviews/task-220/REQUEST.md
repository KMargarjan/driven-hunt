# Task 220 — review request: the game plays on a phone (touch controls)

Task: 220
Round: 2
Base: `4e0f4f7d` (origin/main)
Code commit: `fc05663474161f5e6d07356acf3c93a8e546ce02`

```
[harness] PASS: 33/33 checks @ fc05663474161f5e6d07356acf3c93a8e546ce02 (clean tree) scope=all
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
   *Verify:* `git diff 4e0f4f7d..fc056634 -- src/` contains no `RemoteEvent`, no `FireServer` that
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
   + `Rail.heightFor(4)` = **460 on a 400 px tall screen** (510 at the desktop step's 150 px
   minimap, which is what a landscape phone renders at today), so RELOAD and AMMO were off the
   bottom either way.
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

10. **ROUND 1's BLOCKING FINDING IS FIXED, AND IT WAS RIGHT.** `Touch.setCarried` / `setHorn` were
    driven from `render`, which runs on `Weapon.Changed` — a signal fired from the server's
    `publish`, **which never runs for a player who has no gun**. That player is a BEATER, and BLOW
    is his button: his horn arriving after `Hud.start` told `Touch` nothing. The two tells moved
    into `Hud.renderObjective`, the one pass that runs every frame and already calls
    `Touch.setCovered` / `Touch.applyLayout`; it takes the Weapon module as an optional second
    argument. **A case that would have caught it** adds a Tool named `Horn.TOOL_NAME` to the
    **Backpack** — never equipping it, so `Weapon.Changed` does not fire and only a per-frame
    reader can see it — and asserts `Touch.state().hasHorn` goes true and then false.
    *Verify:* commit `cfd7df72`; the case *"sees a horn arrive and leave, without any weapon state
    changing"*; `Touch.state` exists because the drawing cannot show this on a desktop, where the
    whole cluster is hidden.

11. **Four of round 1's notes are fixed in the same commit, because each was a comment telling a
    lie rather than a preference:** the rail's pre-fold bottom was **460**, not 510 (510 is the
    same arithmetic at the desktop step's 150 px minimap — both are off a 400 px screen, and the
    comment now says which is which, in `Rail.luau` and in the backups note);
    `MapUi.fullMapRect` defaulted to the **told** column, which would have made a pure exported
    rectangle answer differently in a folded session than in an unfolded one for the same
    arguments — it defaults to the constant now, as the design said; `Hud.build`'s rail comment
    still named `MapUi.applyLayout` as the writer of its `Position`; and `MapUi.railColumn` /
    `setRailColumn` had been inserted between `MapUi.setTarget`'s doc comment and `setTarget`
    itself. The remaining notes are queued as **220a**.

12. **The earlier gate rounds found three real faults, fixed not worked around.** Commit
    `9f7f8902`: the spec left the player holding the wrong Tool (`blowHorn` equips the horn, and
    `weapon_client.spec` asserts four bound actions that exist only with a gun in hand — it failed
    with 0); the spec modelled a different rail floor from the renderer; and the 800 × 400
    rail/jump collision is claim 8. Commit `ca3394cb`: the exclusion key was order-sensitive.

## Three gate runs I wasted, reported because they look exactly like a code defect (rule 8)

Between rounds, **I left Studio's Device Simulator on**. The click I believed exited it in fact
switched the profile to **Meta Quest 3**, and the next three gate runs played the client in a
VR-emulated viewport where the client runner never reported at all — consuming its whole 300 s
budget and then failing `zz_drive_boundary` on the **server** with its own note, *"a client never
reported"*. One stall, two red lines, and neither was the code: a bisect that removed the new case
failed identically, and a screenshot of the DEV window showed the device bar reading *Meta Quest
3*. **The Device Simulator is Studio state that outlives the session that set it and the harness
cannot see it.** With it off the gate is 33/33 in 204 s again. Worth a harness check, queued as
**220b** beside the `capture` fault below.

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

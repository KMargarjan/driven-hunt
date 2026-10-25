# Task 265 -- a reliable shot instrument, and the 38 m scope miss

Task: 265
Round: 1
Base: 670416e6 (main, which includes 264)
Code commit: 670416e60614695a9fcf9a6fb1237d8dd66a29a4

`[harness] PASS: 34/34 checks @ 670416e60614695a9fcf9a6fb1237d8dd66a29a4 (clean tree) scope=all`
`[harness2]` N/A: **nothing under `src/`, `tests/` or `tools/` changed at all** this round, so no
path can be in `TWO_PLAYER_PATHS`. The harness was run anyway, on the clean tree, because the
dispatch asked for the full `test`.

## PLAN (core quality protocol step 0), for item 3

- **(a) REAL LIFE.** A scoped rifle zeroed at a known distance puts the bullet on the sight line to
  within a small fraction of the target at ordinary ranges; `docs/research/2026-10-24-real-shooting.md`
  section 6 and `Ballistics.boreOrigin`'s own header give the residual as **1.6 cm inside 60 m**.
- **(b) MEASURED NOW.** Task 264's single datum was *"the first real click, at a stag 136 studs out
  with the sight on its chest, hit Terrain"*. This task measured the thing itself, with
  `aimshot.py` and the server's own `ShotLanded` payload: the perpendicular deviation from the
  sight line is **0.023 / 0.031 / 0.038 studs** at 25.2 / 38.1 / 50.1 m.
- **(c) TARGET.** The dispatch's 0.3 studs. It is ~8 cm, well inside a deer's chest at any of these
  ranges, and ten times the residual the research note predicts.
- **(d) LEVER.** `Ballistics.launchDirection` / `Ballistics.boreOrigin` /
  `Shotgun.CONFIG.BORE_ON_SIGHT_LINE`, written at `src/server/Weapon/init.luau` in
  `onFireRequest` -- `local origin = Ballistics.boreOrigin(req.origin, req.direction, muzzle,
  CONFIG.BORE_ON_SIGHT_LINE)` and `local bore = Ballistics.launchDirection(aim, ballistic)`.
  **The lever was not moved**: the measurement is inside the target, so there is nothing to change.
- **(e) HOW IT IS MEASURED AFTER.** The same instrument, `aimshot.py`, which is also what measured
  (b). Before and after are one tool.

**(b) CONTRADICTS THE DISPATCH, AND THE PROTOCOL SAYS TO SAY SO AND STOP.** Item 3's premise -- that
the 136-stud Terrain hit is a sighting or drop defect -- is **refuted**. The cause is measured
below and it is the instrument's, not the game's.

## STEP 1 -- her path

The Forest Test (placeId 130094961655666), a hunter enrolled at a truck pad (rule I), on his own
stand, the scoped rifle in his hands, real focused mouse clicks. Nothing was measured in DEV.

## Claims

1. **Item 1 is MET and self-proving.** `aimshot.py --selftest` prints
   `SELFTEST: 5 click(s) -> 5 ShotLanded` / `SELFTEST PASS`. *Verify:* run it in a Play session with
   a gun in hand; the count comes from a listener on `Shotgun.Remotes.ShotLanded`, which is an
   Instance and not a re-`require`d module (the task 258 trap).
2. **The four task-264 faults are each closed by a named line of the instrument.** Studio resolved
   by `game.PlaceId` (`ftsid.resolve`); the click through `click.ps1`, which focuses; the click
   point computed from `winrect.ps1` every run; the reload the player's own `R` through
   `263key.ps1`; and **no probe `FireRequest` path left at all**. *Verify:* read `aimshot.py`'s
   docstring and `shoot()`.
3. **Item 3 (CORE): the rifle puts the bullet on the sight line, measured at three ranges.**
   Perpendicular deviation **0.023 / 0.031 / 0.038 studs** at 89.9 / 136.0 / 178.8 studs
   (25.2 / 38.1 / 50.1 m), against a 0.3-stud target. *Verify:* the table in
   `<runs-dir>/ledgers/265.md`; each row is one `ShotLanded` payload read back by the probe, and the
   sight line is rebuilt in-game from the eye and the aim point the hold was set to.
4. **The 136-stud Terrain hit is REPRODUCED and its cause measured.**
   `SERVER Terrain @ ... MISS 29.812 studs (dY -0.401) | OFF-SIGHT 0.029 studs` -- the shot was
   0.029 studs off the sight line while landing 29.8 studs from the aim point, because the aim had
   been taken before a 2.4 s reload and the stag walked 20 studs. *Verify:* the ledger's item 3;
   the fix is `shoot(..., rearm=...)` in `aimshot.py`, whose comment carries the measurement.
5. **Step 3's three numbers, together, on her path, after the fix.** AIMED: `Boar90/hind` chest,
   `offTarget=0.000 deg`, 131.2 studs. SERVER: `ZoneRear(rear) @ 3287.44,158.02,-3126.11 local
   -0.820,-0.406,0.785`, `OFF-SIGHT 0.031 studs`. CLIENT: `Attachment @ 3287.44,158.02,-3126.11
   (under ZoneRear)`. *Verify:* the ledger; the two sides are not one identity -- the server side is
   the replicated payload, the client side the Instance its own effects code built from it.
6. **The frame was opened and described.** `<runs-dir>/265-deer38b.png`: the shooter's eye, scoped
   .416 (1 loaded, 9 reserve), the hind broadside in mid-field with a boar to its left, and the hit
   card bottom-left reading `HIT - .416` with the red dot on the silhouette's **rear** -- the zone
   the server named in claim 5. *Verify:* open it.
7. **`BORE_ON_SIGHT_LINE` was not flipped, and that is a decision and not an omission.** Nothing
   measured asks for it: its own case is a shot led into EMPTY SPACE (task 259), which is not what
   the dispatch described. *Verify:* `git diff --name-only 670416e6..HEAD` shows no `src/` file.
8. **Item 2 is NOT MET and item 4 is NOT PROVEN, in those words.** *Verify:* the ledger and the
   report's handover block. Item 4 is CORE and reads *"nobody has yet seen a deer killed on the
   road, running, lie still in her place."*
9. **Nothing in the game changed.** No file under `src/`, `tests/` or `tools/` was touched; the only
   repository changes are this folder and `TASKS.md`. *Verify:* `git diff --name-only 670416e6..HEAD`.
10. **The Forest Test's attributes are identical before and after.** Read with
    `<runs-dir>/attrs-id.luau` before anything and again after the restore:
    `DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true DHFlag_COINS=true DHFlag_DEER_ROAD_LEAP=true
    DHFlag_DRIVE_BOTS=true DHFlag_HORN=true DHFlag_LICENCE_POPUP=true DHFlag_LOBBY=true
    DHFlag_SHOP=true DHForestStartRole=hunter DHShopTestGrant=true`. `DHTestOwns` was set for the
    proof only and is cleared. *Verify:* the two strings are the same string.

## What could not be verified

- **Item 2** (the `DHTestRelease` hook): not built. It is a `src/` change needing both branches
  asserted and a `SCOPE_SPECS` entry, and the session's time went on items 1 and 3.
- **Item 4** (eight running deer, four on the road): not attempted, because item 2 is its lever.
- **Item 5**: not attempted.
- **The empty-space case** (task 259's own, `BORE_ON_SIGHT_LINE`): one shot was fired at a point in
  the air and the reading is not clean enough to quote -- a stale listener generation was writing
  the row. The generation gate that fixes it is in the instrument now; the measurement is not made.

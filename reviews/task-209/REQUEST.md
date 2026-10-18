# Task 209 — the lobby flow: the trucks back, the banner on the click, 8 s between drives

Task: 209
Round: 1
Base: 9465e12 (main)
Code commit: 9c203cb

Harness (paste, clean tree):

```
[harness] PASS: 33/33 checks @ 9c203cb1060974cf9009a8f25c76556f43451c08 (clean tree) scope=all
```

Two players: see claim 10 — `src/server/Match/init.luau` and
`tests/server/match_live.spec.luau` are both in `TWO_PLAYER_PATHS`, so this change needs the
`[harness2]` line and the Director has it on the stop word.

## What changed

Karen, 2026-10-18 ~14:20, with a screenshot of the trucks
(`driven-hunt-runs/karen-2026-10-18/shot-1.png`, outside the repo):

- *"car has to be moved back meaning left same size twice as car now is (screenshoot) so I can
  easy access enter to game"*
- *"also once I click I need imeadiatly show loading (Leaving dfor hunting)"*
- *"time for next rount is to long make 8s max"*

All three were reproduced on her own path in the live Forest Test **before** any code changed
(rule H), and every before/after number below was measured there rather than reasoned about.
The frames are in `driven-hunt-runs/t209/` (git-ignored, outside the repo).

Files: `src/shared/Lobby/init.luau`, `src/server/Lobby/Build.luau`, `src/client/Hud/PadPanel.luau`,
`src/client/Hud/init.luau`, `src/server/Match/init.luau`, plus `tests/server/lobby.spec.luau`,
`tests/client/pad_panel.spec.luau`, `tests/server/match_live.spec.luau`.

## Claims

1. **Step 0: `QUICK_TEST` no longer fails the harness at midnight.** Its `expires` was
   `2026-10-18`, and `tests/server/flags.spec.luau` fails any row whose date is in the past — so
   from 2026-10-19 it would have failed every gate. It is `2026-11-08` (21 days, the ceiling in
   `docs/design/feature-flags.md` section 12) with a comment naming the use that justifies it
   (the Director's live playtest switch; task 205's lobby frames were shot with it on 2026-10-17).
   *Verify:* `src/shared/Flags/init.luau`, the `QUICK_TEST` row; commit `94b61cb`.
   **Every other row was checked**: the next two are `BOAR_MODEL` 2026-10-24 and `BOAR_BEHAVIOUR`
   2026-10-25 — both outside three days — and nothing else is before 2026-10-31.

2. **Her defect was reproduced and measured first (rule H, L-010).** Standing on pad 1 at eye
   height, her own truck's tailgate was **2.77 studs** from the pad's near edge and 8.77 from its
   centre — her objective chevron reads *"TRUCK 8 m"* in her screenshot, and it read the same in
   the reproduction. From the south, which is where her shot was taken (her compass reads NW/N/NE
   and `TRUCK 1` is on the right, both of which the reproduction matches), the four trucks hid
   their own pads: one corner of pad 1's green deck was the only pad visible and the three
   `TRUCK n` billboards were chopped into each other by the truck bodies in front of them.
   *Verify:* `t209/before-karen.png` (camera 2866,155,−2948 → 2882,153.5,−2928, eye height),
   `t209/before-approach.png`, `t209/before-pad1-asis.png` (the live third-person camera on pad 1).

3. **Which world axis "back" is was MEASURED, not assumed (L-019).** `Camera.RightVector` read
   `(−1,0,0)` with `LookVector` `(0,0,1)`: facing +z, +x is on the LEFT — which is why her frame
   has `TRUCK 1` (the smallest x) on the right and the lodge beyond it, and it is how the
   reproduction above was confirmed to be her viewpoint. The pads are at +z from the bays
   (`Pads.centreFor`), so **away from the pad is −z**, and that is the direction `BACK_STUDS` moves
   the truck. *Verify:* `Build.trucks` (`-cfg.TRUCK.BACK_STUDS` on the z component only).

4. **The clear gap between every pad and its own truck is at least two truck-widths.** Measured in
   the live Forest Test after the change, over the WORLD-axis corners of every `BasePart` of each
   built truck (L-020: the drawn footprint, not a pivot and not an import frame):

   | bay | truck width (drawn) | gap, before | gap, after | after / width |
   |---|---|---|---|---|
   | 1 | 8.70 | 2.77 | **18.74** | 2.10 x |
   | 2 | 8.70 | 2.77 | **18.77** | 2.16 x |
   | 3 | 8.70 | 2.77 | **18.77** | 2.16 x |
   | 4 | 9.09 / 9.01 (tilted to the hill) | 2.61 | **18.41** | 2.04 x |

   Two rows do it, 8 studs each: `TRUCK.BACK_STUDS = 8` parks the truck south of its bay (nothing
   else reads it — the bay, the pad, the yard's x and the billboards are still the bay centre's)
   and `PAD_BEHIND_STUDS` 12 → 20 brings the pad north toward the lodge she walks from. Why not one
   row of 16, with the measurements that bound each, is written on the rows.
   *Verify:* `Lobby.CONFIG.TRUCK`; `tests/server/lobby.spec.luau`, *"parks every truck at least two
   truck-widths back from its own pad (task 209)"*; frames `t209/after-oldpadcam.png` (the
   **same camera** as `before-pad1-asis.png`, measured off that frame: 2876,154.71,−2914.40 looking
   due south) and `t209/after-karen.png` / `t209/after-approach.png` (her two viewpoints, same
   cameras as the before pair).

5. **The truck's footprint is data now, and it was measured off the built trucks.**
   `TRUCK.MODEL.WIDTH_STUDS = 8.7` and `LENGTH_STUDS = 18.46` are the world-axis extents after the
   quarter turn, taken from every corner of every part of `Workspace.Lobby.Trucks.Truck1..3` in the
   live place. The Creator Store's "18.5 x 7.0 x 8.7" was already in the comment; a spec cannot read
   a comment, and the clearance rule in claim 4 is written against these.
   *Verify:* the `MODEL` row and its comment; the spec in claim 4 uses both.

6. **The yard is one rectangle with two readers instead of two copies of the same literals.**
   `Build.road`'s slab and `Build.trees`' exclusion each rebuilt it from the same config rows with
   their own `+ 34` / `44` / `26`. They call `Build.yardRect` now, whose z span is derived from what
   the yard has to carry — the trucks' south end and the pads' north edge, plus `YARD_LIP_STUDS`.
   This is load-bearing rather than tidying: the old exclusion ended at z +44 from the anchor and
   the moved pads reach +50, so without it a spruce could stand on a queue pad.
   *Verify:* `Build.yardRect` and its two callers; `tests/server/lobby.spec.luau`, *"keeps every
   truck and every pad on the yard rectangle (task 209)"*; the live slab measured
   x[2853.0..2944.0] z[−2953.2..−2896.0] against trucks z[−2949.2..−2930.4] and pads z[−2912..−2900].

7. **Nothing floats or sinks after the move (rule E).** Independently of the owner's own settle
   number, for each truck I took the LOWEST corner of every one of its parts and raycast the ground
   directly under that point, worst case per truck: Truck1 −0.041, Truck2 +0.000, Truck3 +0.000,
   Truck4 −0.077 studs. The metric is NOT 0.00 for every item, so it is a measurement rather than a
   stub. The owner's own line agrees: `[lobby] trucks: 4/4 settled on the measured ground, worst
   wheel +0.497 studs` (it was +0.456 before the move). The pads' decks stand +0.080 above the
   ground at all four corners of all four pads with 0.700 of slab below it — sunk, as task 177's
   round-1 finding requires. *Verify:* `t209/p14_wheels.py`, `t209/p13_ground.py`, and the
   `[lobby]` line in `t209/console-after.txt`.

8. **The banner is up on the click: 3.65 s → 0.1032 s.** Measured through the REAL UI path both
   times (L-027) — a real left mouse click driven into the `1 / 1` button at its own measured
   screen rectangle, with the timestamps taken INSIDE the client on
   `UserInputService.InputBegan` and on `PadLeaving:GetPropertyChangedSignal("Visible")`, not by
   firing the remote from a script. `PadPanel.press` now raises the banner in its own call stack
   (`renderLeaving()` before it returns), saying `LEAVING.SENT` — *"GETTING THE TRUCK READY"* — and
   the server's three words replace it the moment one arrives. The residual 0.1032 s is the
   injected click's own down-to-up gap plus a frame: `GuiButton.Activated` fires on RELEASE.
   *Verify:* `PadPanel.press`, `PadPanel.bannerLineFor`, `pendingPick`;
   `tests/client/pad_panel.spec.luau`, the three task-209 cases — the banner is visible in the same
   expectation as the press with nothing from the server, it survives the pad no longer asking
   (which is what an ACCEPTED pick looks like one scan later), the server's word replaces the line,
   and `PENDING_SECONDS` takes it down when no word ever comes.

9. **The optimistic banner cannot contradict the world.** `LEAVING.SENT` is deliberately not a
   `PAD_STATE` and `Lobby.padLoading` is unchanged, so "the server says this party is leaving"
   still has one answer; `bannerLineFor` returns `leavingLineFor`'s line whenever the server has
   sent one, whatever the pending flag says. The Hud TELLS `setLeaving` the clock
   (`os.clock()` from the one evaluation it already runs) rather than this renderer starting one.
   *Verify:* the third task-209 case, *"never lets the click's banner contradict the server"*.

10. **"NEXT DRIVE IN" is 8 s: `Match.CONFIG.SCORE_SECONDS` 25 → 8.** That is the number she was
    reading — the results panel's footer literally says `NEXT DRIVE IN n` and counts this down
    (`Hud.ScorePanel.Footer`, `Drive.CONFIG.SCORE_FOOTER_WORD`). Measured on the real player path
    (L-017) by watching `ScorePanel.Visible` from the client through a whole drive end in the live
    Forest Test: **25.22 s before, 8.03 s after**. `INTERMISSION_SECONDS` 15 is the other wait
    between two drives and is **deliberately untouched**: it is Karen's own number (task 163, after
    playing it — *"for hunter a bit more time like 15s to find a place"*), the start card counts it,
    and she is respawned and walking to her stand through it rather than frozen. Flagged to the
    Director rather than decided here. *Verify:* `Match.CONFIG.SCORE_SECONDS` and its comment;
    `tests/server/match_live.spec.luau`, the `<= 8` and the `== 8`.

## What I could not verify

- **The two-player run.** `src/server/Match/init.luau` and `tests/server/match_live.spec.luau` are
  in `TWO_PLAYER_PATHS`, so this needs `[harness2]`, which needs a second client. Two Studios are
  open on this machine (DEV and the Forest Test), and `run-test2.sh` refuses unless exactly one is.
  Handed to the Director with the stop word.
- **The label overlap at a glancing angle is NOT fixed, and I say so rather than claim it.** The
  pads themselves are now plainly visible from her approach (compare `before-approach.png`, where
  one sliver of one pad shows, with `after-approach.png`, where all four decks do), but the four
  `TRUCK n` billboards still crowd each other when the row is viewed nearly end-on, because they
  are 17 studs apart in x and that is the bay pitch. **Widening the bay gap to the Director's 2x a
  truck's width is not possible inside the lobby field, and that is arithmetic rather than an
  opinion:** the yard slab's east edge is `anchor + 43 + 3g` (`Build.yardRect`), the field's own
  half-span is `FIELD.SPAN_STUDS / 2` = 110, so `g <= 22.3`; `g = 26` would be needed for a gap of
  2x the 8.70 width, and even `g = 22` only buys 1.53x and already pushes the slab 13 studs past
  the flattened `FIELD.PADS` "Yard" rectangle (x −44..96), which would have to be widened too —
  terrain, with trees standing in it. Left for the Director: it is a field change, not a bay change.
- **The 0.1032 s was not split** into the injected click's down-to-up gap and the frame after
  `Activated`. The attempt needed the dialog open again and the player was by then enrolled in a
  drive, so pads stop asking him. What IS proved is that no server round trip is in it: the spec
  asserts `Visible == true` in the same expectation as the `press` call.
- **Karen has not seen any of it.** She approved merging looks before she sees them.

## Standing rule A, on the lobby path

A fresh Play of the Forest Test, twice.

1. **The Tool is in the CHARACTER.** The first run spent its 88 s in the lodge and read
   `team=nil character=[] backpack=[]` — which is the lobby's designed state and not a fault: you
   are given nothing until you take a truck. So a second run took one: teleport to pad 1, a real
   left click on `1 / 1`, then `team=Shooters character=[Shotgun] backpack=[]` at +20 s, +45 s and
   +70 s. In the character, never in the backpack.
2. **The console.** Run 1: 12,951 characters, **0** suspicious lines. Run 2: 15,352 characters,
   **0**. (For contrast, the BEFORE run in the same place carried four `Stack Begin` traces from
   `Boar runtime is at maxBoars` in `ForestTest.releaseLine` — pre-existing, nothing to do with this
   task, and absent from both runs above.)
3. **The thing I changed ran.** The lobby built with the new geometry (`[lobby] built ... pad 1
   2876, 149.73, -2906`), the dialog opened, the banner came up on the click and the truck took him
   into drive 1 as a Shooter.

## Karen's place was left exactly as found

`ServerStorage` attributes on the Forest Test, read before the first Play and again after the last:
`DHFlag_COINS=true, DHFlag_DRIVE_BOTS=true, DHFlag_LOBBY=true, DHFlag_SHOP=true,
DHForestStartRole=hunter, DHShopTestGrant=true` — identical, and nothing was set or cleared (L-056).
One thing WAS clicked: the Rojo plugin's **Accept** on a sync dialog that had been sitting unanswered
in that Studio, without which the place could not show this task's code at all. The attributes above
were re-read immediately afterwards and are unchanged.

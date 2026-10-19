# Task 201 part 4 (task 216) — the map, the scope and the marks in the one palette

Task: 216
Round: 1
Base: main @ `18f53d6`
Code commit: `4e35c0c90b4665e6da4b5fd1501b1fa085cd7968`

```
[harness] PASS: 33/33 checks @ 4e35c0c90b4665e6da4b5fd1501b1fa085cd7968 (clean tree) scope=all
```

`[harness2]` **N/A.** No file this branch touches is in `TWO_PLAYER_PATHS` (`tools/agents.py`):
the change is `src/client/Hud/`, `src/shared/Rifle/`, `src/shared/Shotgun/`, three files under
`tests/client/` that are NOT in that list (`hud_style`, `hit_marker`, `map_ui`) and two
`backups/` notes. `src/shared/Drive/` is deliberately NOT touched — see claim 6.

**The folder is `task-216` and not `task-201-4`** because `tools/agents.py` resolves
`reviews/task-(\d+)/`, which `task-201-4` does not match; parts 2 and 3 did the same (203, 205).
The Director named the work "201 part 4"; 216 is the next free number.

**This is design system E.** The spec is the Designer's design system, 2026-10-17 §6 E, at
`<runs-dir>/design/design-system.md`, with `hud-mockups.png` beside it. **It is outside the repo,
so every "to §5 surface N" citation below is unverifiable from the tree** — that hole was raised by
the Reviewer on part 3 and recorded as 205a's decision for the Director, and nothing has changed, so
it is restated here rather than left to be discovered. What CAN be checked is the code and the
frames; the quotations are pasted in the comments at every site so the Reviewer reads the same words
the Builder did.

**A further limit of the mockup:** `hud-mockups.png` has five boards and NONE of them is the full
map, the scope, the hit mark or the way-mark. Boards 1 and 2 carry the minimap, the crosshair and
the toast feed, and those are the only three surfaces of this part that have a picture to be
compared against. The other four are prose in §5 only.

---

## Claims

**1. Every colour, face and radius on the map is a `Style` token, and the greps are zero.**
`src/client/Hud/MapUi.luau` — `MapUi.CONFIG`'s six hand-picked colours (`BACKGROUND`,
`MINIMAP_TRANSPARENCY`, `PANEL_TRANSPARENCY`, `RIM_COLOR`, `TEXT_COLOR`, `ROAD_COLOR`) and
`MapUi.COLORS`' three reads of `Drive.CONFIG` all read `Style` now; the `Drive` require is gone
from the file. *Verify:* read `MapUi.CONFIG`'s "what things look like" block and `MapUi.COLORS`;
`grep -rn "Drive" src/client/Hud/MapUi.luau` finds only comments.

**2. The acceptance greps return zero code hits in `src/client/`.** Table, run at the code commit:

| grep | code hits | hits that are comments | where |
|---|---|---|---|
| `Enum.Font.Code` | **0** | 16 | all 16 are prose naming what left; `grep -rn` and read each |
| `Color3.fromRGB(255, 255, 255)` | **0** | 0 | — |
| `101214` | **0** | 4 | `Compass`, `Rail` comments quoting §5 |
| `EB5A37` | **0** | 5 | `Compass`, `Objective` comments |
| `5A96FF` | **0** | 1 | `Compass` comment |
| `FFA03C` | **0** | 2 | `Compass` comment |
| `FFE896` | **0** | 2 | `Compass` comment |
| black `UIStroke` on a `TextLabel` | **0** | — | the three `Color3.new(0, 0, 0)` left are named below |

The three remaining `Color3.new(0, 0, 0)` in `src/client/`, each named with its reason:
`Style.SCOPE_MASK` (§5 surface 20: *"Mask stays `#000000`"* — the paint outside the eyepiece, not
an outline); `ShopPanel`'s drop shadow (a `BackgroundColor3`, not a stroke, and not a surface of
this part); `BoarArt`'s `or Color3.new(0, 0, 0)` fallback after `RING.body`, which is unreachable
while `RING.body` exists. *Verify:* run the seven greps and
`grep -rn "Color3.new(0, 0, 0)" src/client/`.

**3. The grep is not the test — the live screen is.** `tests/client/hud_style.spec.luau`, *"is clear
of Code, white and black strokes over the WHOLE Hud"* walks every descendant of the real
`ScreenGui` and fails on `Enum.Font.Code`, `TextScaled`, any of the six banned colours as a text
colour OR as a visible `Frame` fill, and any black `UIStroke` except the scope mask (excluded by
name AND parent). **It caught three things the greps could not**, all fixed in `12d8107`: the
scope's mask, rim and ring strokes were coloured only inside `layoutScope`, so until a scope was
first raised all three were a `UIStroke`'s default black; and the TAB report's silhouette dots were
pure white from `BoarArt`'s own `or Color3.new(1, 1, 1)` fallback, because `ReportPanel.drawDots`
passed no `dot`. *Verify:* read the case; `git show 12d8107`.

**4. The minimap is a quiet slate with a brass rim and the full map is a modal panel with a scrim.**
`src/client/Hud/init.luau` `build` (`miniRim`, `mapScrim`, `fullMap`), `MapUi.applyVisibility`.
The scrim is written from `full.Visible` itself, so the two cannot part company. **It dims the world
and not the top band, deliberately:** it sits at `MapUi.CONFIG.Z_INDEX - 1` = 5 because the panel is
6 (it must stay under the scope mask at 11–13 and the report at 15), and the status slate, objective,
compass and feed are all at 6. The comment at `mapScrim` says so. *Verify:* `hud_style.spec`,
*"draws the map in the palette, with a brass rim and a scrim that follows it"*, which toggles
`MapUi.setOpen` and re-reads both; frame `t201e-fullmap.png`.

**5. The hit mark is coloured by kind and both marks wear a drop line, not an outline.**
`Style.hitMarkColor` (hit `PAPER`, kill `PINE_TEXT`, wound `CLAY`), `Style.dropLine`, and `arm` in
`src/client/Hud/init.luau`. The drop line is a **sibling** and not a child: a `ScreenGui`'s
`ZIndexBehavior` is `Sibling`, under which a child always draws over its parent whatever its
`ZIndex`, so a shadow parented to the mark would sit on top of it. It carries a `DropLine` attribute
because `Hud.showHitMark` recolours every `Frame` under the marker. **`"wound"` has no sender:**
`Weapon.markHit` is called with `"hit"` and `"kill"` only (`src/server/Weapon/init.luau`,
`MatchBoot`, `ForestTestBoot`), so the third arm is reachable by parameter and by spec and not yet
by the wire. That is stated in the code at both `Style.hitMarkColor` and `Hud.showHitMark`.
*Verify:* `hit_marker.spec`'s new case asserts all three colours are distinct, the drop line's
attribute, its colour, its +1/+1 offset, its lower `ZIndex`, its rotation matching the arm's, and
that **no `UIStroke` survives anywhere under either mark**.

**6. The feed collapses repeats and caps at 3, and `src/shared/Drive/` was not touched to do it.**
`Hud.pushFeed` is the one writer of the list (both call sites go through it), `Hud.feedLineText`
renders the count, `renderFeed` trims at `Style.FEED_LINES` = 3. **`Drive.CONFIG.FEED_LINES` (5) is
now read by nothing and was left in place on purpose:** `src/shared/Drive/` is in
`TWO_PLAYER_PATHS`, so deleting one dead number would have cost a two-player run on a one-player
look task. `Style.FEED_LINES`' own comment says this and queues it. *Verify:* `hud_style.spec`,
*"collapses a repeated feed line into one line with a count"*, which drives **four arms** — a new
line, a repeat, an **interleaved** repeat (the arm a consecutive-only collapse gets wrong), and the
over-cap drop — plus that a repeat carrying no meaning keeps the first line's, and that only three
toast slots exist at all. Frame: `t201e-drive-fp.png` shows one line reading **`a boar got away
x17`** in a live drive.

**7. The scope's tube is the system's and its geometry is still the rifle's.** `rimColor` and
`maskColor` are removed from `Rifle.CONFIG.scope.eyepiece` and from the exported `Eyepiece` type;
`Hud.layoutScope` reads `Style.LOOK.SCRIM` and `Style.SCOPE_MASK`, and a new `Bezel` frame carries
a 1 px `BRASS` ring at `Style.SCOPE_RING_T` on the **glass's** edge (the rim's inner size, not the
tube's outer one). Archived with the way back in
`backups/2026-10-19_rifle-eyepiece-colours.txt` (rule 7). **MEASURED on the frame**, not asserted:
sampling `t201e-scope.png` across the glass edge at y 392 gives tube `(9,9,7)` → **`(67,56,38)`,
`(95,78,58)`** → glass `(26,7,0)`. `BRASS` is `(200,162,88)`; 30 % of it (T 0.70) over `(9,9,7)` is
`(66,55,31)`. The ring is there and it is as faint as a 1 px hairline at 0.70 should be.
*Verify:* `hud_style.spec`, *"rims the scope in the system's darkest surface"*.

**8. The way-mark's word sits on its own slate and all three parts dim together when pinned.**
`src/client/Hud/Objective.luau` `render` + `start` (`markSlate`), the `WaypointSlate` built in
`Hud.build`. The word is a CHILD of the slate (`AutomaticSize.XY`), so the pair travels as one; the
chevron's own black `UIStroke` is gone. `BackgroundTransparency` and a `UIStroke`'s transparency do
not inherit in Roblox UI, so each of the three is faded from the one `PINNED_TRANSPARENCY`.
*Verify:* `hud_style.spec`, *"gives the way-mark's word its own slate, and dims all of it when
pinned"*. **Measured live** (`t201e-waymark.png`, and the probes beside it): pinned off the left
edge the slate read T 0.49 (= 0.08 + 0.92 × 0.45) at x 16.5 with the chevron at 48.5; walking 110
studs east moved the pair to 851 / 880.5 and the word from `TRUCK  28 m` to `TRUCK  7 m`; facing
it, the slate read T 0.08 at x 381.5. The word travels with the mark, which is task 153 round 2's
blocking finding and the reason this pair is one module.

**9. A regression this task caused, found by looking at a frame and fixed (rule 5).** Before the
palette the map's target mark was `#EB5A37` and a stand `#FFA03C` — two oranges told apart by
colour, and the legend drew both as squares. The system has ONE go-here orange and the hunters ARE
that orange (`HUNTER` and `BLAZE_HI` are both `#E8832F`), so after the recolour
`t201e-fullmap.png` showed **three identical orange squares reading STAND, GO HERE and HUNTER**.
The MAP never had the problem — it has always drawn the target turned 45° — so the key now draws
what the map draws. *Verify:* `map_ui.spec`, *"keys every mark by a shape as well as by a colour"*,
which asserts the colour-**and**-shape pair is unique across all six rows — the property a
colour-only case could not have caught.

**10. Two dead colours left `Shotgun.CONFIG`, and `HIT_MARK_KILL_COLOR` did not.**
`CROSSHAIR_COLOR` and `HIT_MARK_COLOR` had exactly one reader each (`Hud.build`), which now reads
`Style`; they are removed and archived in `backups/2026-10-19_hit-mark-colours.txt`.
`HIT_MARK_KILL_COLOR` stays because `Hud.BoarArt` and `Hud.HitCard` still read it as the **fatal
dot** on the boar plate — a wound position on a bone silhouette, where red reads as blood and the
marker's new green would not. **Its name is now wrong for what it does**, and renaming it would
touch `docs/design/drive-report.md` and `docs/research/2026-10-17-hit-card.md`, which are the
Architect's files; it is queued instead, in the archive note and in the config comment.
*Verify:* `grep -rn "CROSSHAIR_COLOR\|HIT_MARK_COLOR" src/ tests/`.

---

## What I could not verify

- **The spec itself.** `design-system.md` and `hud-mockups.png` are outside the repo. Every §5 / §6
  citation rests on the Director's own look. Parts 1–3 shipped on the same basis (205a's last item).
- **No mockup board exists** for the full map, the scope, the hit mark or the way-mark. Only the
  minimap, the crosshair and the toast feed can be put beside a picture; the rest are prose.
- **Karen has not seen any of it.** It is all look.
- **The hit mark on screen.** Its three colours and its drop line are asserted by
  `hit_marker.spec` through `Hud.onHitMarker` — the function the wire is bound to — but I have no
  live frame of one: it needs a boar hit inside a Play session, and the crosshair is deliberately
  never drawn in first person (Karen, 2026-09-27), so neither mark appears in any frame I took.
- **`"wound"` draws nothing today** because nothing sends it (claim 5).
- **The way-mark was not verified against a real mouse turn.** `send_input`'s `moveTo` into a Play
  client with a locked cursor did not rotate the camera, so the pair was moved by moving the
  CHARACTER instead (three positions, numbers in claim 8). The claim that it tracks the WORLD is
  measured; the claim that it tracks a mouse turn is not.
- **Two stale design-doc lines I may not fix** (the Builder does not write `docs/design/`):
  `docs/design/shotgun.md` lines 629 and 1066 describe the crosshair as `CONFIG.CROSSHAIR_COLOR`
  "with a 1-px black `UIStroke`", and `docs/architecture/audit-003.md` line 213 lists
  `CROSSHAIR_COLOR` among the crosshair's numbers. Both named in the archive note.
- **The truck-pad billboards in `t201e-waymark.png`** (`TRUCK 4`, `TRUCK 3`, …) are still bright
  purple/orange/blue world labels with outlines. They are `BillboardGui`s in the lobby, not the
  `HunterHud`, so they are outside this part's surfaces and outside the §6 grep — reported, not
  touched.
- **The full map panel is much taller than the road it draws** (`t201e-fullmap.png`): the panel is
  cut to the geometry's own bounds, and the forest-test bounds are far deeper in Z than the road.
  Pre-existing (task 155's `fullView`), not introduced here, and not in part E's scope.

## Frames (all player's-eye, Forest Test unless said)

| frame | what it shows | against its board |
|---|---|---|
| `<runs-dir>/t201e-drive-fp.png` | mid-drive, hunter on his stand: minimap (slate disc, brass rim, `BODY` road, brass own-mark, orange stands, blaze DRIVE), status band, rail, **one toast reading `a boar got away x17`** | board 1 of `hud-mockups.png`. Differs: the mockup's feed shows three distinct lines where this is one collapsed line (the collapse working); the mockup has a hit card up and this has none |
| `<runs-dir>/t201e-fullmap.png` | the full map open on M: opaque panel, corner 16, brass edge, eyebrow `MAP` + `forest-test`, legend well, brass scale bar, world dimmed by the scrim | **no board exists.** Differs from §5 surface 14 in nothing I can see except the legend regression of claim 9, fixed after this frame was taken |
| `<runs-dir>/t201e-waymark.png` | the chevron and `TRUCK 19 m` on its slate, un-pinned, at the lobby | **no board exists.** §5 surface 21 as written |
| `<runs-dir>/t201e-waymark-pinned.png` | the same pair pinned to the left edge, dimmer | as above |
| `<runs-dir>/t201e-scope.png` | the scoped rifle (DEV, `RIFLE` on, cleared after): `SCRIM` tube, brass ring on the glass, Karen's black cross and red dot | **no board exists.** §5 surface 20, measured in claim 7 |

**The scope frame cost a mistake, recorded because it touched Karen's place.** `tools/flags.py`
addresses *the first Studio in Edit mode*. With DEV in Play, `flags clear` therefore cleared the
**Forest Test's** four flags (`COINS`, `LOBBY`, `DRIVE_BOTS`, `SHOP`) instead of DEV's `RIFLE`.
Both Studios were read back and restored before anything else: the Forest Test now holds exactly
the six attributes it started with (`DHFlag_COINS`, `DHFlag_LOBBY`, `DHFlag_DRIVE_BOTS`,
`DHShopTestGrant`, `DHFlag_SHOP`, `DHForestStartRole=hunter`) and DEV holds none. Nothing in the
repo changed. It is worth a line in `flags.py`'s docstring that it resolves by mode and not by
place — a tools change, so not made here.

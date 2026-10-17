# Task 201 part 1 — one design system, and the in-drive HUD drawn from it

Task: 201
Round: 1
Base: main @ `c52a332`
Code commit: `944d11540c7cd08467f6f7809750416294c732bc`

```
[harness] PASS: 33/33 checks @ 944d11540c7cd08467f6f7809750416294c732bc (clean tree) scope=all
```

`[harness2]` **N/A.** No file this branch touches is in `TWO_PLAYER_PATHS` (`tools/agents.py`): the
change is `src/client/Hud/`, three files under `tests/client/` that are NOT in that list
(`compass.spec`, `hud_clarity.spec`, and the new `hud_style.spec`), `tools/studio_mcp.py`'s scope
table, and a research note. `Role.luau`, `match_client.spec`, `outfit_client.spec`,
`zz_tie_to_a_tree.spec` and `src/shared/Drive/` are untouched — **deliberately**, see claim 9.

## What changed

The Designer's design system, 2026-10-17 (`<runs-dir>/design/design-system.md`, with
`hud-mockups.png` and `hud-mockups-phone.png`) is the spec. This is its §6 **build tasks A and B**.

**A.** `src/client/Hud/Style.luau` — the one source: §1 in full (every token, including the new
`SLATE`, `FIELD_MUTED`, `HUNTER`, `BEATER`), the two faces, `spaced`, `sizeFor`, the radius ladder,
the four over-the-world opacities, `MOTION`, and the constructors `panel` / `card` / `slate` /
`header` / `statChip` / `toast` / `pill` / `bar`. `ShopPanel.LOOK` / `.FONT` / `.spaced` become
**thin aliases**.

**B.** Surfaces **1, 2, 3, 5, 6, 7, 8** — the status bar, the objective line, the compass, the rail,
the ammo chip, the **new** horn chip, the toast feed.

Note: `docs/research/2026-10-17-one-design-system.md`.

## Claims, one per surface, each with how to verify it

**1. There is ONE palette, and the shop's look is unchanged.**
`ShopPanel.LOOK`, `.FONT` and `.spaced` are assignments of `Style.LOOK` / `.FONT` / `.spaced`, not
copies. Verify: `src/client/Hud/ShopPanel.luau`, the three lines under "THEY LIVE IN `Hud.Style`
SINCE TASK 201"; and `tests/client/hud_style.spec.luau`, "is the SHOP'S palette and not a second
copy of it", which compares the **tables** (`expect(ShopPanel.LOOK).to.equal(Style.LOOK)`) and not
their values. `tests/client/shop_panel.spec.luau` is untouched and passes, which is task A's own
check — it asserts `Panel.LOOK.BLAZE`, `Panel.LOOK.MESSAGE_SECONDS`, `Panel.spaced("AMMO")` and the
four BUY-button fills by name.

**2. The status bar is a slate of stat chips with a role pill and a coin disc.**
`Hud.build`'s "the status bar (surface 1)" block and `renderDrive` with its `chip()` helper. The
frame is still named `DriveBar` (claim 9). Verify on screen:
`.screenshots/20261017T135300Z-t201e-hunter-ammo-2.png` reads `DRIVE 1 | 9:52 TIME | 6 BOARS |
SHOOTER` on one slate with 1 px dividers; `...T134639Z-t201c-beater-cooldown.png` has the same bar
with a **pewter** `DRIVER` pill. The lobby frame `...T133516Z-t201-hunter-assigning.png` has the
fifth chip — `● 2000 COINS` with the coin disc — and an **amber** `WAITING players` chip.
`Hud.driveBarText()` answers the chips' plain words, which is what `match_client.spec` asserts.

**3. The objective line sits on a slate, in Oswald Medium, and the GO turns blaze.**
`Objective.render` writes the label AND the slate's `Visible` (one owner, one answer), and
`Objective.isGo` is the pure predicate for the one line that takes `GO_COLOR`. Verify:
`...T134639Z-t201c-beater-cooldown.png` — `GO - push to the road` in `BLAZE_HI` on its slate —
against `...T135300Z-t201e-hunter-ammo-2.png`, where `stay on your stand, boars coming` is `PAPER`.
`hud_style.spec` "has ONE go-here colour, and it is the blaze".

**4. The compass is a quiet slate, 420 wide, with no white and no outline.**
`Compass.CONFIG` reads `Style.LOOK.SLATE` / `.PAPER` / `.BLAZE_HI` / `.BRASS_HI`; `Compass.widthFor`
is the pure width. Verify: the live probe in the capture log reads `compass=true 420x30`, and the
strip in any frame above shows `N W` / `N` / `N E` letter-spaced in cream with ticks, on a rounded
slate with a brass hairline. `hud_style.spec` "backs every word of the top band with a slate".

**5. The rail is a column of ghost buttons with hover and press states.**
`Rail.CONFIG` reads `Style.LOOK.SLATE` / `.LINE` / `.FIELD_MUTED` / `.BRASS`; the words are child
labels so a press can nudge them, and `AutoButtonColor` is off. Verify: any frame — `MAP / M`,
`REPORT / TAB`, `RELOAD / R`, `AMMO / X`, each a rounded quiet slate with the key hint in spaced
brass; and `...T134639Z` where a beater's rail is **two** buttons, which is `Rail.buttonVisible`
unchanged. `hud_style.spec` "draws the rail as a ghost over the world".

**6. The ammo readout is chamber pips, a count and a reload bar.**
`Hud.ammoChipFor` is the pure data (pips, selected, pocket, label, busy); `Hud.renderCorner` draws
it. Verify: `...T135300Z-t201e-hunter-ammo-2.png`, bottom right — two pips, `12`, `SLUG` on a slate,
measured `104x46`. `hud_style.spec` "reads the chambers as pips, and the magazine rifle as rounds
held" drives both readouts with states it owns. `Hud.readoutText()` still answers `""` with no gun,
which is what `weapon_client.spec` and `zz_tie_to_a_tree.spec` assert (both untouched).

**7. The horn chip is new, and it is the first answer to "why did my horn stop working".**
`Hud.renderCorner` reads `Horn.BLOW_ATTRIBUTE` — the attribute the SERVER stamps in
`Weapon.Horn.blowTool` — and fills the bar over `Horn.CONFIG.COOLDOWN`, **starting empty** (§7's own
instruction). Verify: `.screenshots/20261017T135207Z-t201d-horn-1.png` — horn icon (two Frames),
`HORN`, `WAIT`, and a brass bar part-filled, measured `126x46`. **Staged, and said so:** a lone
player is a Shooter, so the frame was made by setting `Player.Team` to `Drivers` and equipping a
`Horn` Tool from the server. The chip's own branches (`READY` / `WAIT` / `THROUGH`) are code and the
`THROUGH` branch has no frame.

**8. Every feed line is its own toast with a meaning dot, and the dot and the words agree.**
`Hud.feedMeaningFor` is the one pure mapping and **both** writers of `feedEntries` carry it. Verify:
`...T135300Z` bottom left — `● Drive on` on its own slate. `hud_style.spec` "maps a feed entry to
one meaning" pushes a real kill through `Hud.onKilled` and asserts the drawn toast's dot and text
are the SAME colour and are `PINE_TEXT` — the check that caught this missing on the first run.

**9. Two things the system asks for are NOT done, and the reason is the gate, not a disagreement.**
(a) the role pill says `SHOOTER` / `DRIVER` where §5 surface 1 asks for `HUNTER` / `BEATER`;
(b) the top band is 8 / 40 / 108 with a **34 px** status slate where §4.1 asks for 12 / 50 / 98 and
40. Both are blocked by `TWO_PLAYER_PATHS`: the word by `tests/client/Role.luau` +
`match_client.spec`, the band by `Drive.CONFIG.TIED_TOP_OFFSET` (74) in `src/shared/Drive/`. Verify:
`Hud.roleBadge`'s header and `Hud.STATUS`'s header say exactly this; queued as TASKS.md 201a.
(c) the ammo chip keeps the server's `NO BUCK` notice (§5 surface 6 wants a clay toast) — that is
behaviour, not look. Research note §4 lists all three.

**10. Nothing overlaps, at 400 × 800 as well as here.**
`hud_clarity.spec`'s band test now reads `Hud.statusRect` (pure, and the MAXIMUM width, so the test
is conservative) and `Compass.widthFor`. Band: objective 8..38, status 40..74, tied banner 74..104,
compass 108..138, minimap 140. Verify: that case at three viewports, plus `hud_style.spec` "keeps
the top band's rectangles stacked".

## The grep table (code lines only, comments excluded)

| Pattern | My seven surfaces | Elsewhere in `src/client/` (tasks C–E) |
|---|---|---|
| `Enum.Font.Code` | **0** | 7: `init.luau` 1040/1087 (score panel + start card → C/D), 1159 (tied banner → C), 1435 (way-mark word → E); `MapUi` 865 (→ E); `ReportPanel` 175/218 (→ C) |
| black `UIStroke` (`Color3.new(0, 0, 0)`) | **0** | 7: `init.luau` 636 (`arm()`, the crosshair and hit mark → E), 1047, 1169, 1426, 1446; `MapUi` 856; `ReportPanel` 172. Plus `ShopPanel` 1207, which is the display case's **contact shadow** (a Frame fill, named in §1.3) and not a text outline |
| `Color3.fromRGB(255, 255, 255)` | **0** | 1: `MapUi.CONFIG.TEXT_COLOR` (→ E) |
| `101214` `EB5A37` `5A96FF` `FFA03C` `FFE896` | **0** | **0** — all five are gone from code everywhere; the only hits left are inside comments quoting the system |

## Ready-check (standing rule A) — one Play of ≥ 80 s in DEV

1. **The Tool is in the CHARACTER**: at 15 s `character=[Shotgun] backpack=[Rifle]`; at 86 s
   `character=[Shotgun] backpack=[Rifle]`. Both from the server, printed in the capture log.
2. **The console**: 10 756 chars, **0** lines matching `Stack Begin` / `attempt to` /
   `invalid argument` / `is not a valid member` / `Unable to cast`
   (`<runs-dir>/t201-console-dev.txt`).
3. **The feature ran**: the drive reached `Running` (`DRIVE 1  9:36 TIME  6 BOARS`), the ammo chip
   drew `104x46`, the horn chip `126x46`, the compass `420x30`, the status slate `303x34`, and a
   `Drive on` toast appeared and faded.

## What I could not verify

* **A real phone frame.** No tool here can resize a Studio viewport (`hud_clarity.spec` says so in
  its own comment), so 400 × 800 is proven by the pure rectangles — `Hud.statusRect`,
  `Objective.lineRect`, `Compass.widthFor`, `Rail.rect`, `MapUi.minimapRect` — and by
  `hud_style.spec`, **not by a picture**. Studio's Device Emulation would give one and needs a click.
* **The frames are the DEV place, not Karen's Forest Test.** The Forest Test Studio dropped off
  StudioMCP mid-session and its drive never leaves the lobby with one player; DEV is where a lone
  player reaches `Running`. Same HUD, greyer ground. The first pass's lobby frames
  (`...T133516Z`, `...T133631Z`) ARE the Forest Test and show the coins chip and the pewter pill.
* **`THROUGH` on the horn chip** (a beater past the line) and **the reload bar filling** have specs
  and code but no frame.
* **Karen has not seen any of it.** It is all look; she approved merging look work before she sees
  it (2026-10-17: *"it's ok to keep doing it"*).

## Four defects the SPECS could not catch, and a frame did

Recorded because they are the task's own lesson and all four are in the history: the whole HUD built
at the **phone step** (`Camera.ViewportSize` is (1, 1) before the first frame, so the compass was
120 px wide); the horn's bar running the **whole screen**; then **430 px**; then a rename leaving a
layout and an icon parented to `nil`, so the chip measured **57 px** with the word hanging off the
end. Commits `5eff363`, `5cbe5c2`, `cb6c39c`, `944d115`.

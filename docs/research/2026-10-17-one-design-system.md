# One design system, and the in-drive HUD drawn from it (Task 201, parts A and B)

**Karen, 2026-10-17 ~12:30, verbatim:** *"all menus all information (timer  what to shoot who you
are ect. ) has to be same design as menu colors loading ect again ask designer to fallow on this /
we need one unified design system and colours and style across all game"*.

**The spec is not this note.** The Designer's design system, 2026-10-17 is, and it lives outside the
repo at `<runs-dir>/design/design-system.md` beside `hud-mockups.png` and `hud-mockups-phone.png`.
This note records what the system must do, what was read before building to it, what was adopted,
what was refused, and the numbers the result is measured against — rule 1's five headings, with the
system itself as the decision.

---

## 1. What the system must do

1. **One answer per look question.** "What colour is blaze orange", "which font is a number",
   "how round is a chip" must each have exactly one place to read. `docs/PROJECT_CONTEXT.md` names
   the failure this prevents: *"Most of the worst bugs were two correct pieces of code
   disagreeing"*, and this repo has already paid for it once in the look — the pad dialog shipped as
   `Enum.Font.Code` on a blue-grey panel while the shop beside it was Oswald on charcoal, which is
   what task 197 fixed by exporting `ShopPanel.LOOK`.
2. **Every word over the 3-D world must be readable over the worst ground the game makes**, without
   the black `UIStroke` every HUD label has worn since task 124.
3. **The in-drive HUD must say who you are, how long is left, what to shoot and what to do** in
   components a player who has used the shop already recognises.
4. **It must hold at 400 × 800 as well as at 1280 × 720.** Karen wants mobile in v1.
5. **Nothing may overlap anything**, at either size, and that must be asserted rather than promised.

## 2. What was read

| # | Source | Licence / status | Does well | Does badly |
|---|---|---|---|---|
| A | **The Designer's design system, 2026-10-17** (`<runs-dir>/design/design-system.md`), with `hud-mockups.png` and `hud-mockups-phone.png` | ours, current | It is an EXACT build, not a mood board: every component is spelled as Roblox instances and properties (§3), the layout is given as rectangles with a no-overlap contract (§4.3), and §2's contrast table is a measurement and not an opinion. It also says what it could not decide (§7) | It puts the tied banner at y 96, inside the compass's own band (§5 row 13 against §4.1) — an internal collision it does not resolve. Taken as task C's, see §6 below |
| B | **WCAG 2.2 contrast minimum (SC 1.4.3), W3C Recommendation** — https://www.w3.org/TR/WCAG22/#contrast-minimum | W3C Document Licence, current (Rec. 2023, errata 2024) | Gives the 4.5 : 1 floor the system's §2 table is computed against, and the 3 : 1 large-text exception that keeps `FAINT` legal as a caption on an opaque panel | Says nothing about text composited over live 3-D at an arbitrary transparency, which is the actual problem; the system solves that by making the backing panel opaque enough that the ground stops mattering |
| C | **Roblox — "UI Design Best Practices" / "Typography"** — https://create.roblox.com/docs/ui/ui-design-best-practices and https://create.roblox.com/docs/ui/typography | Roblox docs, current | Where the 44 px touch-target floor comes from (`Rail.CONFIG.BUTTON_PX` 48 clears it), and the grouping rule this repo already quotes in `Rail.luau`'s header: *"group UI elements from the same category together"*. Confirms BuilderSans as the engine's own UI face | Prescriptive about Roblox's own kit and silent on a first-person HUD over terrain |
| D | **theHunter: Call of the Wild — HUD** (observed, plus its players' own complaints quoted in `docs/research/2026-10-12-hud-clarity.md`) | commercial, not reusable; read for shape only | The closest commercial analogue: a compass strip, a small way-mark, a quiet corner readout. Its players' *"massive and orange"* is why our chevron is 14 px | Proprietary; nothing can be copied, only the proportions learned |
| E | **Our own `shop-design-spec.md` section 8 ("UI style"), 2026-10-16** | ours, shipped in tasks 196/197 | Already proved the Oswald + BuilderSans pair, the charcoal/brass/blaze palette and the 0.12 s hover tween at a real screen size. The new system is this, widened | Covers an OPAQUE panel only; it has no answer for text over the world, which is the whole of §2 |

## 3. What was adopted, and why

**The system, whole** (borrow before building, rule 2). It is the work product Karen asked for by
name — *"ask designer to fallow on this"* — and it arrived as an exact build. Nothing here was
invented; what follows is only where this task's code had to choose.

* **`src/client/Hud/Style.luau` is the one source** (§6 task A): §1 in full, plus six constructors.
  `ShopPanel.LOOK` / `.FONT` / `.spaced` become **thin aliases** of it rather than being renamed
  across `PadPanel`, `HitCard`, `init.luau` and `shop_panel.spec`. A field rename across a shared
  table is this repo's named recurrence (task 196's `Body.SLOTS`); the alias costs three lines and
  removes the second copy, which is the whole point.
* **The slate replaces the stroke** (§2). Measured, not chosen: `SLATE #14110E` at transparency 0.18
  composited over the six worst grounds this game produces leaves every type colour above 4.5 : 1,
  the tightest being `BLAZE_HI` at 4.66 over a bright sky — which is why blaze over the world is
  used at 14 px and up. The two colours that fail (`MUTED` 4.11, `FAINT` 2.20) are banned over the
  world and `FIELD_MUTED #B3AA98` (5.51) exists for exactly that slot.
* **Two reds became one.** `#EB5A37` — the compass's drive mark, the way-mark chevron and the map's
  target — is deleted and the mark is `BLAZE_HI`. Clay is then the only red-ish thing on screen and
  it always means something went wrong.
* **Numbers are chips, sentences are lines.** The status bar stops being one `string.format` line
  and becomes stat chips on one slate, so the clock can be the biggest number on screen without the
  rest of the bar growing with it.
* **The horn chip is the answer to a question the game never answered**: *"why did my horn stop
  working"*. A beater's bottom-right corner was empty.

## 4. What was refused, and why (rule 2: inventing needs a written reason)

1. **The role pill still says `SHOOTER` / `DRIVER`, and the system asks for `HUNTER` / `BEATER`.**
   Not a disagreement — a gate. The word is asserted by `tests/client/match_client.spec.luau`
   through `tests/client/Role.luau`, and **both files are in `TWO_PLAYER_PATHS`** (CLAUDE.md,
   Director 2026-10-03), so changing the string costs a `test2` run and a human click. The pill's
   shape, its team colour and its place on the bar land now; the vocabulary flip is three lines and
   is queued as TASKS.md 201a.
2. **The top band is 8 / 40 / 108 and not the system's 12 / 50 / 98.** `Drive.CONFIG.TIED_TOP_OFFSET`
   is 74 and lives in `src/shared/Drive/`, which is in `TWO_PLAYER_PATHS` as well — so the tied
   banner cannot move in a task whose gate is the one-player run, and the status slate is **34 px
   rather than 40**. The band that results is objective 8..38, status 40..74, tied banner 74..104,
   compass 108..138, minimap 140: stacked, nothing overlapping, asserted at three viewports in
   `hud_clarity.spec`. The system's own §5 row 13 moves the tied banner anyway (it becomes a clay
   toast in build task C), and the band's final geometry goes with it.
3. **The ammo chip keeps the server's refusal for now.** §5 surface 6 wants `NO BUCK` to leave the
   chip and become a clay toast. It is a behaviour change on the weapon's own notice path, not a
   look change, so it is queued rather than smuggled into a styling task.
4. **No `ImageLabel`, no upload, no new glyph.** The system's own rule, and this task holds it: the
   horn icon is two Frames, the coin is a Frame with a gradient, the chamber pips are Frames.
   `Style.spaced` is still the only letter-spacing available, because Roblox `TextLabel` has no
   tracking property.
5. **`Enum.Font.Code` and the black stroke survive on the surfaces this task did not touch** — the
   results board, the TAB report, the tied banner, the start card, the hit card's header, the map,
   the scope and the way-mark. They are build tasks C, D and E. The acceptance grep in §6 of the
   system is for AFTER E; `hud_style.spec` asserts the zero over **this task's seven surfaces only**
   and says so, rather than claiming a clean screen.

## 5. The numeric targets

| What | Target | Where it is checked |
|---|---|---|
| Contrast, any type colour on a slate over the worst ground | ≥ 4.5 : 1 | the system's §2 table; the tokens it was computed from are asserted in `hud_style.spec` ("the four over-the-world opacities") |
| Slate transparency | 0.18 (12 px type and up), 0.08 (9–11 px) | `hud_style.spec` |
| Break points in the game | exactly **1**, at 700 px | `hud_style.spec`: `Style.PHONE_BELOW_PX == Objective.CONFIG.SMALL_BELOW_PX` |
| Top-band rectangles overlapping, at 400×800, 800×600, 1920×1080 | **0** | `hud_clarity.spec` "keeps every band of the top of the screen clear of every other" |
| `Enum.Font.Code`, `TextScaled` and black `UIStroke` on this task's seven surfaces | **0**, read off the live screen | `hud_style.spec` "has no `Enum.Font.Code` and no black stroke left…" |
| Copies of the palette | **1** | `hud_style.spec`: `ShopPanel.LOOK == Style.LOOK` (the table, not its values) |
| Chips drawn in the bottom-right corner at once | ≤ **1** | `hud_style.spec` "draws ONE of the ammo chip and the horn chip" |
| Objective sentence at 400 px | fits, by the engine's `TextFits` | `hud_clarity.spec` |
| Motion on the HUD | one 0.12 s colour tween on hover/press; **no tween on any bar** | `Style.MOTION`; the bars are written as fractions with no `TweenService` call |

## 6. What this note cannot answer

* **A real phone frame.** No tool here can resize a Studio viewport (`hud_clarity.spec` says so in
  its own comment), so 400 × 800 is proven by the pure rectangle functions — `Hud.statusRect`,
  `Objective.lineRect`, `Compass.widthFor`, `Rail.rect`, `MapUi.minimapRect` — and not by a
  screenshot. Studio's Device Emulation would give a real one and needs a human click.
* **Whether Karen likes it.** Feel and taste are hers (CLAUDE.md), and she looks after the merge
  (2026-10-17: *"it's ok to keep doing it"*).

---

# Part 2 (build task C): the two tables

**Surfaces 11, 12 and 13** — the results board, the TAB report and the tied banner — plus the row
component §3.12 asks for, which is the thing that makes them one system rather than two tables that
happen to agree today.

## What was adopted

* **`Style.tableRow` / `Style.cell` / `Style.rowState` / `Style.columnHead` / `Style.sectionHead`
  / `Style.tag` / `Style.closeButton` / `Style.keyChip`** — ONE row, two panels. The monospace
  alignment both tables used is gone with `Enum.Font.Code`: *"the numbers line up because they are
  PLACED, not because every glyph is one width"* (§1.2). A column is an x and a width.
* **The board's HEIGHT FOLLOWS THE ROW COUNT** (§3.12's one named defect). It was 20 fixed slots
  drawing a 480 × 574 box to hold three of them; it is `header + rows + footer` now, measured by
  the pure `Hud.boardHeight`, and the body is a `ScrollingFrame` past 14 rows. Measured live at
  **520 × 134** with no rows.
* **The report is a MODAL** (§3.1): a 640 × 576 lodge panel over a full-screen `SCRIM` at 0.42,
  with an eyebrow + title pair, a well, and the footer's key hints as **ghost chips** instead of
  `[TAB] CLOSE` inside a sentence.
* **`DOWN` / `WOUNDED` are tags** (§3.7) and the word is always there: a state is never colour
  alone. `WOUNDED` is the screen's word for the record's `wounded` — Karen's own "wounded-lost" —
  and `detailCellsFor` is the one place it is decided, so the tag and the line cannot disagree.
* **The tied banner is one centred clay toast at `TITLE`** (§5 surface 13).

## What was refused or decided against the letter of the spec

1. **The tied banner moved to y 96 and LEFT the no-overlap band.** A toast at the `TITLE` step is
   40 px tall, not the 30 the old 74..104 slot held, so it no longer fits between the status slate
   and the compass. 96 is the designer's own number and it puts the toast **over** the compass
   (108..138) — which §4.3 permits, because that contract names exactly three members of the TOP
   BAND and the tied banner is not one of them. It is a notice, it is up for seconds, and a player
   roped to a tree is not walking anywhere the compass would help with. `hud_clarity.spec` drops it
   from `bands()` with that reason written in; `hud_style.spec` asserts instead that it is drawn
   ABOVE the strip it covers, which is the real claim.
2. **The report keeps its two VIEWS.** Mockup board 4 draws the per-player table and one player's
   animals on one panel; §5 surface 12 asks only for the row rebuild, the ghost chips, the selected
   row and the tags. Merging the two views is a behaviour change on a panel Karen already uses, so
   it was not smuggled into a styling task.
3. **An unknown number is not drawn at all**, rather than `--` (§3.12). A leaver is not paid, and
   the `LEFT` tag beside his row is what says why — `--` in the coins column was the same fact said
   twice and badly.

## What this part could not answer

* **No frame of the results board.** A drive is 600 s and nothing reachable from here shortens it:
  `Match.advanceForTests` is the server's and the StudioMCP thread may not `require` (the harness's
  own docstring records why). The board is asserted on the LIVE screen instead — its card, its
  cells, its team bar, its section colours and its height — by `match_client.spec` and
  `hud_style.spec`, and its geometry was measured live at 520 × 134. The Director can shoot it by
  overriding `DRIVE_SECONDS` through a world's `world.config` (`Match.WORLD_OVERRIDABLE`).

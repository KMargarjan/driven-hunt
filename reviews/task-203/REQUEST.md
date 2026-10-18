# Task 201 part 2 — the two tables, and one row component for both

Task: 203
Round: 1
Base: main @ `19c5604`
Code commit: `e1c69665dc4ff6fe4486d41fe7fc9c020bd2accb`

```
[harness] PASS: 33/33 checks @ e1c69665dc4ff6fe4486d41fe7fc9c020bd2accb (clean tree) scope=all
[harness2] PASS: 35/35 checks @ e1c69665dc4ff6fe4486d41fe7fc9c020bd2accb (clean tree)
```

**WHY THIS FOLDER IS `task-203` AND NOT `task-201-2`.** The roadmap and `TASKS.md` call this task
**201 part 2**; `tools/agents.py` cannot. `resolve_task` accepts a task of DIGITS only
(`[0-9]{1,4}`) and finds a request with `reviews/task-(\d+)/REQUEST\.md`, so a `task-201-2/` folder
is invisible to it and a `Task: 201-2` line fails its `^Task:\s*(\d+)` parse. The obvious
alternative — writing into `reviews/task-201/` — would OVERWRITE part 1's own request and its
**PASS verdict at round 3**, which is the evidence for a PR already merged to `main` (rule 7: never
delete). So this part takes the next free task number for its loop folder, the file was `git mv`d
rather than copied, and `TASKS.md`'s row still reads 201-2 and points here.

**`[harness2]` IS THE DIRECTOR'S RUN**, at the same code commit as the one-player line above
(standing lesson L-034: both lines name `e1c6966`). His note with it: the first two-player attempt
failed one known-flaky `weapon_client` reload case in the SHOOTER client — not this branch's code,
and queued separately — and the retry passed.

`e1c6966` IS NAMED AND NOT THE EARLIER `94bb34b`, AND THE REASON IS THE GATE'S OWN RULE: the
research note and its INDEX row are under `docs/research/`, which is NOT on the merge gate's
paperwork list (`reviews/`, `ESCALATE.md`, `PLAYTEST.md`, `docs/architecture/audit-NNN.md` and the
task's `TASKS.md` row). They landed in the same commit as the request, so the harness was re-run at
the head and that head is the code commit -- at or after the last commit that changed `src/`,
`tests/` or `tools/`, with nothing after it. `94bb34b` also passed the full run (33/33, clean tree,
`scope=all`); it simply did not cover the note.

**WHY `test2` WAS NEEDED AT ALL:** this branch changes two files in `TWO_PLAYER_PATHS` —
`src/shared/Drive/init.luau` and `tests/client/match_client.spec.luau` — confirmed against
`tools/agents.py`'s own list. That spec asserted the OLD board structurally (every direct-child
`TextLabel` white, black-stroked, 23 of them, the panel at `SCORE_PANEL_TRANSPARENCY`), which is
exactly what §3.12 replaces, so it could not be left alone.

The scoped run, for the record: `scope=auto:hud,match,report,shop,weapon (auto, from 9 changed
path(s)): 54 spec file(s) in the blast radius` — it names the Hud paths rather than falling through
to `all`.

## What changed

The Designer's design system, 2026-10-17 is the spec; this is its §6 **build task C**: surfaces
**11** (the results board), **12** (the TAB report) and **13** (the tied banner), and the §3.12 ROW
both tables are built from.

Note: `docs/research/2026-10-17-one-design-system.md`, the "Part 2" section.

## Claims — one per surface, each with how to verify it on its own

**1. There is ONE row component and both tables are built from it (§3.12).**
`Style.tableRow` (the row, its 1 px `Rule` and its 3 px team `Bar`), `Style.rowState` (mine /
hovered / bare — one writer of all three properties), `Style.cell` (one `TextLabel` per cell, at an
x and a width, numbers right-aligned), plus `Style.columnHead`, `Style.sectionHead`, `Style.tag`,
`Style.closeButton`, `Style.keyChip`. Verify: `hud_style.spec`, "builds a §3.12 table row" and
"builds a §3.7 tag … and a §3.5 close button of two Frames"; and "draws the two tables from ONE row
component", which reads a row off the LIVE board and a row off the LIVE report and asserts both
have the same three parts at the same height.

**2. The results board's HEIGHT FOLLOWS ITS ROW COUNT — §3.12's one named defect.**
It was 20 fixed slots drawing `64 + 20×22 + 30 = 534` px to hold three of them. `Hud.boardHeight`
is the pure measure and `Hud.renderScore` is the one writer of the board's `Size`; the body is a
`ScrollingFrame` past 14 rows. Verify: `match_client.spec`, "makes its HEIGHT follow the row count,
which 20 fixed slots never did" — two rows and two headings differ from twelve by exactly ten row
heights, the growth stops at 14 rows, and the drawn board matches the pure measure. **Measured
live:** `board=false 520x134` in the capture log (54 header + 28 column head + 0 rows + 52 footer).

**3. The board is a CARD of cells, with section heads in the team's colour and a countdown bar.**
Eyebrow `DRIVE 1` + title `RESULTS` (§3.4), a column head with its brass hairline, `HUNTERS` in
blaze and `BEATERS` in pewter, your own row in `ROW_SELECTED` with a 3 px bar in your team's colour
and your name in `PAPER`, a brass `1st` pill, a faint `LEFT` tag, coins in `COIN_TEXT`, and a blaze
bar draining over the next-drive countdown. Verify: `match_client.spec`, "draws every CELL in front
of its own card…" and "shows this drive's points, one row per player, mine with a team bar".

**4. The TAB report is a real MODAL over a 0.42 scrim.**
`Hud.build` creates `ReportScrim`; `ReportPanel.setOpen` is the one writer of both its `Visible` and
the panel's. The panel is the shop's own size rule (`ReportPanel.panelSize`), with a well, a close
button of two rotated Frames, and the footer's key hints as **ghost chips**. Verify:
`.screenshots/20261017T150735Z-t201b-report-open-2.png` — opened with a real `Tab` keypress during
Play — against mockup board 4; and `hud_style.spec`'s scrim assertions. **Live:**
`report=true 640x576 scrim=true` in the capture log.

**5. Every column of both report tables fits inside the well, and no column overlaps the next.**
This is in the request because the FIRST frame of the panel got it wrong: `POINTS` ran 14 px past
the well's right edge (`20261017T150447Z-t201b-report-open-2.png`). The tables are arithmetic now
and are added up in a case. Verify: `report_panel.spec`, "keeps EVERY column inside the well, which
the first frame did not"; and the re-shot frame above, where `POINTS` sits inside the rule.

**6. `DOWN` / `WOUNDED` are tags, and the word is always there (§3.7).**
`ReportPanel.detailCellsFor` decides the word ONCE — the record says `wounded`, the screen says
`WOUNDED` (Karen's "wounded-lost"), and the tag and the line therefore cannot disagree. Pine for
down, clay for wounded. Verify: `report_panel.spec`, "draws one row per animal with its result,
zone and range in metres".

**7. The tied banner is one centred clay toast at `TITLE`, and it leaves the no-overlap band.**
A `TITLE` toast is 40 px tall, not the 30 the old 74..104 slot held, so it takes the designer's own
y 96 and is drawn OVER the compass (108..138). §4.3's TOP BAND contract names exactly three members
— objective, status, compass — and this is not one of them; it is a notice, up for seconds, and a
player roped to a tree is not walking anywhere the compass would help with. Verify:
`Drive.CONFIG.TIED_TOP_OFFSET`'s own header, `hud_clarity.spec`'s `bands()` comment (it drops the
banner and says why), and `hud_style.spec`'s "the tied toast over the band", which asserts it is
drawn ABOVE the strip it covers — the real claim.

**8. The pure row-text functions kept their data and lost their padding (§1.2).**
`ReportPanel.listCellsFor` / `detailCellsFor` and `Hud.scorePanelLines`'s `cells` are the data;
`listRowText` / `detailRowText` / `ScoreLine.text` are the same rows as one line, built from those
cells by ONE function so the two cannot drift. `ReportPanel.rowText()` and `Hud.scoreRowText()` read
the DRAWN labels. Verify: `report_panel.spec`, "formats a row as CELLS…"; `rifle_client.spec`'s gun
case, which was a character-offset assertion and is a CELL assertion now — it cannot be broken by a
longer weapon label, which is what it was really trying to catch (task 143's own note).

## The grep table — the three surfaces I touched

| Pattern | Surfaces 11, 12, 13 | Elsewhere in `src/client/Hud/` |
|---|---|---|
| `Enum.Font.Code` | **0** (`ReportPanel.luau` is now 0 for all three patterns) | 3: `init.luau` 1176 (`panelLabel`, the start card → task D), 1660 (the way-mark word → E); `MapUi` 865 (→ E) |
| black `UIStroke` | **0** | 5: `init.luau` 772 (`arm()`, crosshair + hit mark → E), 1183 (`panelLabel` → D), 1651, 1671 (the way-mark → E); `MapUi` 856 (→ E). Plus `ShopPanel` 1207, the display case's **contact shadow** (a Frame fill, named in §1.3), and `BoarArt` 190, which is a line continuation and not a stroke |
| `Color3.fromRGB(255, 255, 255)` | **0** | 1: `MapUi.CONFIG.TEXT_COLOR` (→ E) |
| old hexes (`101214 EB5A37 5A96FF FFA03C FFE896`) | **0** | **0** in code anywhere |

## Ready-check (standing rule A) — one Play of ≥ 86 s in DEV

1. **The Tool is in the CHARACTER**: at 15 s `character=[Shotgun] backpack=[Rifle]`; at 86 s
   `character=[Shotgun] backpack=[Rifle]`.
2. **The console**: 10 829 chars, **0** lines matching `Stack Begin` / `attempt to` /
   `invalid argument` / `is not a valid member` / `Unable to cast`
   (`<runs-dir>/t201b-console.txt`).
3. **The feature ran**: the report opened on a real `Tab` keypress (`report=true 640x576
   scrim=true`), closed again on a second one, and the board measured `520x134` — its height for a
   roster of none, which is the whole of claim 2.

## What I could not verify

* **No frame of the results board.** A drive is 600 s and nothing reachable from here shortens it:
  `Match.advanceForTests` is the server's and the StudioMCP thread may not `require` (the harness's
  own docstring records why, and `Match.WORLD_OVERRIDABLE` is set at a world's composition root).
  The board is asserted on the LIVE screen instead — the card, the cells, the team bar, the section
  colours, the height — and its geometry was measured live. **A full roster and a roster of one are
  therefore spec claims, not pictures,** and the Director can shoot both by overriding
  `DRIVE_SECONDS` through a world's `world.config`.
* **No frame of the report with ROWS in it.** A solo 90 s session hits nothing, so the frame shows
  the chrome and `Nobody has hit anything yet`. The rows, the tags and the selected row are
  `report_panel.spec`'s.
* **The new specs were not run against `main`.** `Style.tableRow`, `Hud.boardHeight`,
  `ReportPanel.listCellsFor` and `WELL_INNER` do not exist there, so the cases cannot execute at
  all rather than fail with a number. What CAN be checked against `main` is the one claim that is
  arithmetic: `git show main:src/client/Hud/init.luau` builds the board
  `UDim2.fromOffset(SCORE_PANEL_WIDTH, 64 + SCORE_ROWS_MAX * SCORE_ROW_HEIGHT + 30)` = **480 × 534**
  for every roster, against the case's `expect(two < 400)` and the measured 134.
* **One flaky full run.** The first `test` at `94bb34b` failed
  `weapon_client.spec:1019` with `rises` 0 against 2 — the input replay saw no shot. The re-run at
  the SAME sha passed with `shots seen: 2`, the scoped run before it passed, and the run at
  `e1c6966` above passed. Three green against one red at the same code. Reported
  rather than hidden: nothing in this branch touches the weapon, and I did not chase it.
* **Karen has not seen any of it.** It is all look; she approved merging look work before she sees
  it (2026-10-17: *"it's ok to keep doing it"*).

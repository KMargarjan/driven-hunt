# BRIEF -- Task 327: THE GRID MAP (one big world, forest roads cut it into 8 drive cells; one cell per round)

Written by the Director, 2026-11-01. **This file overrides anything older in `docs/`, `TASKS.md` or
an earlier design** (`docs/ARCHITECT_PROMPT.md`).

The Architect is asked for **one design**: `docs/design/grid-map.md`, plus the **deltas** it needs in
the designs it touches (`drive-places.md`, `drive-layouts.md`, `map-generator.md`, `stand-pick.md`,
`map-ui.md`, `drive.md`, `high-seats.md`, `bots.md`, the shop, the animal designs, as needed).

## 1. Karen's words

> **2026-11-01 ~18:45 UTC:** *"we will need fix those terrains and trees from hunter standing view and
> beater it has to be terrain with different reljef and trees in different places where hunter will
> have different experience on each round or selected place imagine one big terrain where is different
> trees growing in different section, mixed then there are in the middle on straing road vertical and
> horizintal in the middle so there we have rectangle with 4 smaller rectangles. Then we can devide
> into 2 more vertical lines and then 8 rectangles. So each line is road forest road where hunter can
> stand and there will be a several stands in on line . Imagine hunting started you can choose from
> map view clicking on icon standing position or tower where you can select yuor place, each place is
> a bit different for the hunter to get real life experience and then if you have license select your
> place you select on m,ap where you want to stand as example top right corner rectangle will be ad
> active drive place you can select all around rectangle where to stand as a hunter then there will be
> show where drive will happen (or aat the begining will show what direction hunt will move beaters)
> you choose your position hunt starts and on each round you can select if you have this license, if
> no then randomly trowen there but who has license can select first then what remains is yours. so
> next round will be next rectangle and so on we don't need several different maps terrains we have
> one devided in sections and there is plenty animals we will make patter how they run where run how
> manny to have fun and fallow to not be laggy or look odd. So this is my vision how it will look"*

> **~19:20 UTC, answers to the Director's three questions:** *"1. based on time how much time ?
> 2.Stand choise same license we have instead tower license there will be choose stand 3. maybe they
> can vote to choose what to take ? it will be even better"*

## 2. Decisions already taken (the Architect designs to these, it does not re-open them)

- **D1 One world.** ONE big map replaces the "four separate drive places" (`drive-places.md`). It is
  cut by straight forest roads: one horizontal road through the middle and three vertical roads ->
  **2 rows x 4 columns = 8 drive cells**. A border road around the whole is the Architect's call.
- **D2 Size from time.** A cell is sized so the beaters walk through it within the drive time
  (Karen's place runs ~5 min drives): first values **~300 m wide x ~400 m deep** per cell, so the
  world is ~1.2 km x 0.8 km. Cell size is ONE number set (CONFIG), tuned after Karen plays. Give the
  stud conversion this project uses and the beater walk-time arithmetic.
- **D3 Each cell different.** Its own relief (hills, hollows, a slope, a dip -- different per cell)
  and mixed tree sections (species/density zones, clearings, thickets) so each round feels different
  from a hunter's AND a beater's eye. Generated from code and data (the map-generator path), not
  hand-placed Studio content. Every tree and stand on the ground (task 326's census is the check).
- **D4 Stands on the roads.** Along every road edge, several stands per side of a cell: ground spots
  AND towers (high seats), each a bit different (height, cover, field of view, distance to the
  forest edge). For the active cell, its four bordering road sides are the hunter line.
- **D5 One cell per round.** Each drive happens in one cell. The map shows that cell, its stands,
  and the **beaters' drive direction** (an arrow) before the pick.
- **D6 Vote.** At the end of a drive (results screen), every player votes for the next cell on the
  map, from cells not yet driven this cycle. Most votes wins; a tie or no votes = random among the
  candidates. After all 8, the cycle resets.
- **D7 Stand pick = licence.** The shop's `access.highseat` (HIGH SEAT ACCESS, 600, 5 hunts) becomes
  **STAND CHOICE**: holders pick their stand first (task 323's map pick); when their window closes,
  everyone else is placed at RANDOM on what remains. Builds on `stand-pick.md` (323a/b, merged,
  flag `STAND_PICK` OFF); 323c (touch) folds into this work.
- **D8 Animals.** Per-cell spawn and run patterns (how many, where they start, where they break
  out), designed for fun and within a performance budget: give the numeric budget (live animals,
  parts, server ms/frame) and how it is measured. No lag, nothing that looks odd.
- **D9 Flags.** New paths born OFF behind flags. The world switch follows CLAUDE.md's MAP SWITCH
  exception (by commit, `Map.EXPECTED_WORLD`), not a flag -- rule on whether that applies here.
- **D10 Safety** (`SafetyArc`, penalty) holds on every stand of every cell; say how it is checked.
- **D11 Mobile.** Every new control works on touch (`mobile-controls.md`).

## 3. What the design must contain

1. The world layout as data: grid, road widths, cell ids, stand slots per road side, relief and
   tree-section recipes per cell; the ONE owner of each (rule 3).
2. How it is generated and placed (reuse `MapGen` / `Places` / `TreeGround`), its size/part budget,
   and how the Forest Test gets it (switch, rollback).
3. Round flow: vote -> cell -> pick window (licence first, then random) -> drive -> results/vote;
   phase timing arithmetic against `drive.md`.
4. Map-UI deltas: whole-world view, cell highlight, drive arrow, vote UI, stand icons (ground vs tower).
5. Animal patterns per cell and the performance budget.
6. Tests: specs with numeric targets, which need `test2`, and the live census/frames that prove it.
7. **The task split**: Builder tasks in order, each small and testable, with a day estimate each;
   the first one must give Karen something she can SEE (the empty world with its roads and relief).

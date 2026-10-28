# Task 306 — design brief for the ARCHITECT: the range moves to the lodge

Written by the Builder, carrying the Director (2026-10-28). This brief is the input to
`tools/architect.sh design shooting-range-lobby --task 306` and **overrides anything older** in
`docs/`, `TASKS.md` and the existing designs where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-28-the-range-in-the-lobby.md`** (this task's note — the
sources, their licences, the lobby's own rules as arithmetic, and the numeric targets T1–T8). The
design is a **delta to `docs/design/shooting-range.md`** (task 298), which stays the base document;
say in each section whether you are replacing, extending or leaving a numbered section of it alone.
It also touches `docs/design/lobby.md` (the home field and the yard) and
`docs/design/high-seats.md` (the stand's structure).

Karen's own sentence is quoted in full in section 1 of the research note. She is away until Friday
2026-10-30 and said: *spend two days on it, make it perfect, all tests.*

---

## 1. The decisions, already taken — do not re-open them

Taken by the Director for Karen, who said decide.

1. **SIX STATIONS side by side on ONE firing line in front of the lodge.** `SPOT_COUNT` 1 → **6**.
2. **Each station has its own E prompt at chest height on a post** — task 303's rule, already
   shipped as `Range.LAYOUT.POST` (`aheadStuds` 7, `sideStuds` 3) for the reason recorded there: a
   `ProximityPrompt` is drawn only while its own position is on screen, so one hung on the mat is
   invisible down the lane and E does nothing.
3. **Every player at a station sees ONLY his own animal, his own menu and his own board.** Many
   shoot at once. The research note's pattern 3 is adopted: **server-owned per-station run DATA, a
   client-drawn animal, the shot reported as NUMBERS, the server the judge.**
4. **Distance per station: 30 m (107 studs) or 50 m (179 studs), chosen in the menu.** Today's 35 m
   (125) **stays available** as a third row.
5. **Window 10 m (36 studs) between two low cover banks**, with the apron behind each end for the
   turn-around.
6. **The paces `stand`, `walk`, `trot`, `run` are kept** (Karen's own four words, 2026-10-27) **and
   the real `slow` (5.0 s) and `fast` (2.5 s) runs are added** — as TIMES across the window, so the
   stud speed is derived and not typed (note section 5.2).
7. **Firing position: GROUND (bench, covered-hut look) or TREESTAND (ladder stand, platform 3 m,
   rail), chosen at the station.**
8. **A low natural earth berm behind the target line — terrain, grassy, not high — with side
   berms.**
9. **A mown grass lane and a gravel firing line.**
10. **The old forest range retires**: its site, its walkway and its home-area row go. Archive with a
    note under `backups/` (rule 7) — never delete. `Join.insideHome`'s range rect for the forest site
    is removed with it.
11. **The range stays free: endless ammo, nothing scored, no money, no `HitLog` row** (task 304's
    rule, `HitLog.rowWorthy`). **The hit card DOES show on a hit** (task 304) — that is what she
    asked for.
12. **No second shooting path.** Task 305's rule is binding: *the shot hits what the shooter saw.*
    Reuse `Weapon.Rewind`, `Cast.candidates`/`Cast.only`, `Flight`'s carried `rewindSeconds`,
    `Weapon.setRewindWorld` and `RangeBoot`'s already-registered per-runtime history provider.

---

## 2. What the DESIGN must decide

### 2.1 The exact site — and it must be ARITHMETIC, not a name-check (L-154)

This is the item that cost tasks 298 and 302 a session: a lobby-placed range respawned the player
every 3 s, because `Join.insideField`'s half-span is 110 and the mat was 268 studs from the anchor.
**Name-checking `Join.insideHome` is not enough. Put the numbers in the document.**

Choose the firing line's anchor so that it is clear of the lodge, the road, the trucks, the pads, the
spawn and the tree line; **shoots AWAY from every one of them**; and is within the walk budget. Then
show, as numbers in the design:

- the chosen anchor, and the footprint `Range.footprintFor(anchor, LAYOUT, downrange)` computes from
  it with `SPOT_COUNT = 6` — `minX/maxX/minZ/maxZ`, worked through;
- that footprint against the **lodge home field x 2740..2960, z -3060..-2840** (anchor
  `(2850, -2950)`, `FIELD.SPAN_STUDS` 220, half-span 110). The note's section 4 already measures
  that a 6-station footprint is about **304 × 222 studs** and therefore **cannot fit** — so name the
  extra home area, computed by `Range.footprintFor`, and the `Join.walkwayTo` corridor
  (`WALKWAY_HALF_STUDS` 24) that reaches it, and state that **every one of the 6 mats and the
  treestand is inside the union**;
- the **drive's field** `x 2230..3830, z -2477..-1197`, `exitZ -2377` — show the whole range stays
  outside it, with the margin in studs;
- the **truck pads** (x 2916, z -2926..-2977) — show no mat, no post, no lane and no walk crosses a
  pad, so nobody is enrolled in a hunt by standing at the range;
- the **stand rule** (`docs/design/high-seats.md`, `Join.withinRect`/`withinStand`) — show the
  range's treestand cannot be mistaken for a hunt stand;
- the clearance in studs from each obstacle in the note's section 4 inventory (lodge plinth,
  LodgeSpawn, Road lane and verges, Yard, Trucks, Fences, Logs, TreeLine ×21, LodgeTrees ×12),
  **crown width included** — a trunk centre is not a tree;
- **T1**: the lodge door (z = -2916, x 2846..2854) to the nearest mat, **208 studs or less** — her
  own measured 10.4 studs/s × 20 s, not the nominal 16.

Say which trees, if any, must be removed, and that they are archived (rule 7).

### 2.2 The owner of the per-station run data, and the owner of the client-drawn animal

One writer each (rule 3), named, with the file. State how a station's trial is replicated to **one**
player and to nobody else, and what happens to the other five stations' data.

### 2.3 How the server judges a shot against a client-local animal at the client's time

**The hardest decision, and the note hands it to you with the obstacle named:** `Cast.candidates`
finds candidates with `GetPartBoundsInRadius` — it wants a Part, and a client-drawn animal has none.
Either the server keeps an invisible, non-collidable proxy per station (and "isolated" then describes
*rendering*, not instances), or `Cast.only`'s seam takes an analytic zone test. **Decide, and reuse
task 305's seams — do not invent a second resolution.** Say what happens to `Boar.Body`'s welded zone
parts, on which every `weapon_*.spec` and the hit card's `zone=` depend, and how rule L's geometric
proof (the ray crossed the DRAWN mesh; a click at the air beside it produces no hitlog line) is still
possible when the mesh is the client's.

### 2.4 The treestand as DATA

Not a second structure and not a branch on a name: a row, read by `Build`, that invents no number.
Platform 3 m (10.7 studs), rail 1.2 m above it (4.3). Say how a man gets up and down, and what the
menu's `spot` option becomes when a station has two firing positions.

### 2.5 What is TERRAIN and what is code-built Parts

Karen's OK, 2026-10-28: **her Forest Test place (terrain) may be edited and saved.** So the berm may
be terrain saved in her place — say so explicitly, say who writes it (the lobby already does terrain
cut-and-fill for its shelf, `Lobby.CONFIG.FIELD.DEPTH_STUDS` 48), and say what happens in **DEV**,
where the harness runs and the `map:v1` row has `plate = true` and no terrain at all. A design that
only works in one of the two worlds is not finished.

### 2.6 The build steps B1..Bn

Each small and testable, in the order they can be built and proved, and each saying what evidence
closes it. **The Director dispatches B1 only after this design PASSes.**

---

## 3. Rules of the document itself

- **L-151 — mark every spatial and compositional fact as UNVERIFIED UNTIL BUILT, in the document
  itself**: the 6-station spacing, the berm's height and slope, the treestand platform at 3 m, the
  site's clearance from road, trucks, spawn and tree line, and T6. An Architect PASS proves the
  document is coherent, **not** that it fits the engine — task 298 step B2 found two placement
  errors (the screens stopping the target 7.8 studs short, the prompt invisible down the lane) only
  at the first build.
- **L-108 — every engine API or property you name when assigning ownership must be read back from
  the running engine or cited to a source.** A design once listed `SoundService.Volume` from memory
  and it does not exist, costing a harness round. That applies here to `GetPartBoundsInRadius`,
  `Terrain:FillBlock`/`FillWedge`, `RunService.Heartbeat`, `ProximityPrompt.MaxActivationDistance`,
  `StreamingMinRadius` and anything else load-bearing. The note's section 3 carries the Roblox doc
  links for streaming, remotes and the client-server boundary; cite them rather than recalling them.
- **THE TESTS RULE (verdict 298):** the design must name **the moving-target hit as THE proof of the
  feature** — a **registered hit per pace from both firing positions, on the client-drawn animal**
  (T4: `stand`, `walk`, `trot`, `run`, `slow`, `fast` × {ground, treestand} = 12 cases, each with
  the shooter's aim, the server's hit part and local offset, the client's mark, and the shooter's-eye
  frame), with rule L's known-bad control beside it. A spec may support that proof; a spec may not
  replace it.
- Cite **files and symbols, never line numbers.**
- Where you deviate from `docs/design/shooting-range.md`, `lobby.md` or `high-seats.md`, say so in
  that section and say why.

---

## 4. Not in scope

The old forest range's **retirement is in scope**; the forest's own high seats, the drive, the
economy, the shop and the lobby's look (flagpole, birch road) are **not**. Phase A writes no code:
this brief, the research note and the design are the whole of it.

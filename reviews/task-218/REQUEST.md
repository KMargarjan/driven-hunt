# Review request — Task 218: a wooden high seat at some stands of each drive place

Task: 218
Round: 1
Base: `d297ebb` (main, the merge of #199)
Code commit: `c21429f67fe3dd11f7a6b20fef669b2a774f1a45`

```
[harness] PASS: 33/33 checks @ c21429f67fe3dd11f7a6b20fef669b2a774f1a45 (clean tree) scope=all
```

`[harness2]`: **N/A.** Not one file this change touches is in `TWO_PLAYER_PATHS`
(`tools/agents.py`): `src/shared/HighSeats/`, `src/server/ForestTest/`,
`src/server/ForestTestBoot.server.luau` are the forest; `src/server/Weapon/Rules.luau` is the
weapon; `tools/studio_mcp.py` is the tools. `src/server/Match/`, `src/client/Match/` and
`src/shared/Drive/` are **not touched at all** — the design's §7.3 ruling is that the hunter reaches
the deck with no new arithmetic in `Match`.

Design: `docs/design/high-seats.md` (Architect, PASS, `reviews/task-218/ARCH_RESULT.md`).
Brief: `reviews/task-218/BRIEF.md`. Note: `docs/research/2026-10-20-high-seats.md`.

---

## What changed

Karen, 2026-10-10: *"we just will improve standing places, maybe will add towers where they can
stand"*; 2026-10-12: a tree stand *"count[s] as part of the stand"*. Six wooden high seats now stand
at chosen stands of the four drive places, the hunter is placed **on** the platform, and at those
stands he may shoot only from it.

* **`src/shared/HighSeats/init.luau`** (new, pure): which stands carry a seat (keyed by layout
  **name**, so the `Layout` record is untouched), every dimension, and the arithmetic —
  `deckTopFor`, `spreadOf`, `minYFor`, `clearsRail`, `blockedBand`, `footprint`, `plan`.
* **`src/server/ForestTest/Seats.luau`** (new): the one writer of `Workspace.HighSeats`. Reads five
  footprint samples, refuses what it cannot measure, and is level-triggered on the layout's name.
* **`src/server/ForestTest/Markers.luau`**: one new injected seam (`setSeatSource`), one branch in
  the stand loop, and `lineGroundFor`.
* **`src/server/ForestTest/init.luau`**: requires `Seats`, injects its two readers and
  `Markers.setSeatSource`, and `standArea` carries `minY`.
* **`src/server/ForestTestBoot.server.luau`**: `Seats.ensure(layout)` before `Markers.build`, and
  the `[seats]` line beside the existing `markers:` line.
* **`src/server/Weapon/Rules.luau`**: `StandArea.minY`, `Rules.belowPlatform`, the
  `off-platform` reason and its notice, and its declared place in `Rules.ORDER`.
* **`tools/studio_mcp.py`**: one `BLAST_RADIUS` row and two `SCOPE_SPECS` memberships.
* Specs: `tests/server/high_seats.spec.luau` (new) plus cases in `forest_markers.spec` and
  `weapon_rules.spec`. Docs: the design, the research note, and the five deltas §14 of the design
  asked for.

---

## Claims, and how to verify each

**1. The platform is the stand, and `outsideStand` is untouched.** `Rules.belowPlatform` is its own
predicate over `StandArea.minY`; `Rules.outsideStand` is byte-for-byte what it was (flat, Y
ignored). `nil` `minY` is "no height rule", so every ground stand, the DEV arena fallback and every
world without seats behave exactly as before.
*Verify:* read `Rules.belowPlatform` and `Rules.outsideStand`; `weapon_rules.spec`'s *"refuses a
hunter who is in his circle but not up on his platform"* and *"leaves every ground stand exactly as
it was"*.

**2. `minY` is the deck's own top face, with no margin, and the brief's margin was wrong.** The
brief (D3) asked for `deckTop − 2` on the reasoning that a jump reaches 4–5 studs.
`StarterPlayer.CharacterJumpHeight` **measured 7.2** in Karen's Forest Test on 2026-10-20
(`CharacterUseJumpPower = false`), so that line is reachable. At the deck's face there are 1.8 studs
of air under it and 3.5 above it.
*Verify:* `HighSeats.minYFor`; `high_seats.spec`'s *"keeps the platform's line out of reach of a
jump from the ground"*, which asserts `DECK_RISE − STAND_HEIGHT >= MAX_JUMP` and that the slack
equals `JUMP_RELIEF_STUDS`.

**3. Nothing in `Match` changes, and the placement needs no new arithmetic.** `Markers.build` puts a
seated stand's `Stand<i>` marker at the deck top; `Body.placementFor` reads `post.Position` and
`post.Size.Y` as it always has, and `Body.onGround`'s near probe then lands on the deck.
*Verify:* `git diff d297ebb..c21429f --name-only` names no file under `src/server/Match/`,
`src/client/Match/` or `src/shared/Drive/`. **Measured live** (Forest Test, `edge`):
`[place] spawn … at (3400, 196.8, -3250) ground=193.3 askedY=197.3 dY=-0.5` — the ground the snap
measured **is** the deck (193.26), and the root settled at deck + 3.50.

**4. A seated stand is not measured by the two ground readers, and that is the whole call order.**
From the sky the canopy reader sees the deck 12.5 studs over the terrain against a tolerance of 1,
so every seated stand would be refused. `Seats.ensure` runs **before** `Markers.build` and the build
asks the seat where its deck is.
*Verify:* `Markers.build`'s seat branch; `forest_markers.spec`'s *"puts a seated stand's post ON its
deck, and does not read that column at all"* (it counts reader calls: zero at the seated column) and
*"never refuses a seated stand, whatever the ground readers say about it"*.

**5. The drive LINE's own point can be under a seat, and that was found live, not reasoned about.**
The line is read at `layout.centre.X`, which for an odd stand count **is** the middle stand's x. On
`edge` that is stand 3, which carries a seat, and the first live run came back
`WAITING forest:line`. `Markers.lineGroundFor` takes the terrain reading alone inside a seat's
footprint and `groundFor` everywhere else.
*Verify:* commit `6b6999a`; `forest_markers.spec`'s *"reads the drive line's ground through the
terrain when a seat stands over it"*, *"still refuses a drive line the two readers disagree about
away from a seat"* and *"covers the whole of a seat's own footprint"*. **Measured after the fix:**
`markers: layout=edge 5/5 stands (0 refused), max ground delta 0.00`.

**6. Rule E: it stands on the ground, and each leg is cut to its own.** Five footprint samples, each
read `terrainYAt` first and then `groundAt(x, z, terrain + 2)` — the `fromY` rule, so a seat cannot
measure itself through its own deck. The deck references the **worst** corner; all four leg tops are
one number.
*Verify:* `Seats.footGroundAt` and `HighSeats.plan`; `high_seats.spec`'s *"cuts each leg to its own
ground and still leaves the deck level"*. **Measured off the real drawn parts** in the live place,
on a 3×3 grid across each leg's and the ladder's own footprint (45 samples a seat — stricter than
the five the design claims against): **worst float +0.06 studs (1.7 cm), worst sink 0.69 studs**,
against the design's bound of 0.8. The server's own line says
`[seats] edge: 1 built, 0 refused, worst foot gap -0.30 studs, worst spread 1.74 studs`.

**7. A seat can never stop a playtest.** A sample that cannot be read, a 1-stud disagreement, or a
footprint spread over 4 studs refuses **that seat**; its stand stays a working ground stand and the
set is byte-for-byte today's.
*Verify:* `HighSeats.plan`'s two refusals and `Seats.ensure`'s counter; `forest_markers.spec`'s
*"is byte-for-byte today's set in a world with no seats"*; `high_seats.spec`'s *"refuses rather than
building a partial seat"*.

**8. A hole in the readings is refused, and `ipairs` could not see one.** `{140, 142, nil, 141, 143}`
— four of five samples read — answered a deck top from the first two, and `plan` went on to build a
leg whose ground it never had. `deckTopFor` and `spreadOf` now walk by index.
*Verify:* commit `a21794a`; `high_seats.spec`'s *"answers nil when any reading is missing"*. This
was caught by this task's own spec in the full run at `6b6999a`.

**9. Which stands was measured, not chosen.** All 25 stands of the four layouts, in a **Play**
session so the three dressed places exist (`DrivePlaces=3`; the Edit reading had them absent and
gave different gains). Ranked by sight gain, then the caps, non-adjacency, `gain >= 60`,
`spread <= 4.0` and `relief <= 1.8`. Six seats: road 1/4/7, edge 3, ride 2, track 1.
*Verify:* the table and its per-row gains in `HighSeats.STANDS`; `high_seats.spec` asserts the
**shape** only. `edge` is the declared exception (design §6.2 rule 4) and `Seats.takeLine` prints it
every build rather than leaving it in a comment.

**10. The seats are ground, deliberately, and a spec says so.** `Workspace.HighSeats` is **not** in
`ForestTest.GROUND_IGNORE` — the inverse of `places.spec`'s assertion about `Places.FOLDER` — because
a deck is a thing a body stands on. The design's §7.4 closes the consequence caller by caller.
*Verify:* `high_seats.spec`'s *"is NOT in the world's ground-ignore list"*.

---

## What I could not verify

1. **No hit card.** The dispatch asks for a full drive from a high seat **with a shot boar**. Two
   shots were fired from the platform (the pocket went 12 → 10) and both missed at 145–158 studs;
   a later run with a 55-stud cut-off saw no boar come that close inside its window. **So the
   refusal half is proven and the kill half is not.**
2. **Frames for `road`, `ride` and `track`.** Only `edge` was shot. The three others build from the
   same `plan` on different ground.
3. **The notice text on screen.** The refusal is proven by the **shell count** (10 → 10 from the
   ground, against 12 → 10 from the deck — a refused shot spends nothing), not by reading
   `"CLIMB TO YOUR STAND"` off the Hud: my label probe did not find the readout label, and the
   notice had faded by the time the frame was taken.
4. **`TrussPart`'s size clamp was not read back** (design §12 item 2). The ladder is built at
   `2 × L × 2` and looks right in the frame, but the engine's returned `Size` was not compared.
5. **The aim origin's rise is 4.69 studs, not the design's assumed 5.0** — measured from a live shot
   (`origin.Y 197.95`, deck top 193.26). The rail's blocked annulus is therefore **12.5 – 15.8
   studs** rather than 11.3 – 13.9, still 3.3 studs wide and far under the 10-stud limit at which
   the design says to drop the rail. `HighSeats.AIM_RISE_STUDS` still says 5.0 and is **stale by
   0.31 studs**; nothing reads it but the spec and the report.
6. **`PathfindingService` against a seat** (design §12 item 4) — not measured.
7. **The harness picked the wrong Studio** when both DEV and the Forest Test were connected: the
   run at `0931819` reported `Studio has the DEV place open (130094961655666 vs 136410205938347)`
   with no `[harness] N Studios connected` line, and read the Forest Test's own place attributes as
   flag overrides. Closing the Forest Test Studio fixed it. **A harness fault, reported under rule
   6**, not worked around in code.

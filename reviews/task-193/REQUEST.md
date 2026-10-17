# Review request — Task 193: four real driven-hunt places, a new one each drive

Task: 193
Round: 1
Base: `c02f65e` (main, PR #181 merged)
Code commit: `8b1a1644196045edd8ad24c93b73f48f0cc27f26`

Harness, clean tree, run twice at the code commit:

```
[harness] PASS: 33/33 checks @ 8b1a1644196045edd8ad24c93b73f48f0cc27f26 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 8b1a1644196045edd8ad24c93b73f48f0cc27f26 (clean tree) scope=all
```

The second is `test --scope auto`, which **resolved to the whole suite** and so is tagged `scope=all`:
`tools/studio_mcp.py` is in the change and that file maps to `all` by its own rule. `test2` is **N/A** —
nothing in `TWO_PLAYER_PATHS` is touched (checked against `origin/main`: no `src/server/Match/`,
`src/client/Match/`, `src/shared/Drive/` or any of the named specs).

## What changed

Karen, 2026-10-15: *"make 4 hunting places where each time person will be in new place when is hunter
then loop it again"*, and *"be sure you do it properly not fake it or broken"*.

A **fourth layout** (`track`, the forest road) and a **fixed rotation 1 → 2 → 3 → 4**, replacing task
179's shuffled bag — her own sentence reversed that decision. Plus **one new system**: a pure planner
(`ReplicatedStorage.Places`) and a thin planter (`ServerScriptService.Places`, the one writer of
`Workspace.DrivePlaces`), with `Places.Ground` the only caller of `Terrain`.

Step 0 ran: `reviews/task-193/BRIEF.md`, `docs/design/drive-places.md` (Architect **PASS**, 51 turns)
and `docs/research/2026-10-17-four-driven-hunt-places.md`. **All five of the design's section-10
corrections are built**, and section 16's two behind-the-code design updates were applied to
`lobby.md` and `drive.md` rather than promised (lesson L-071).

---

## Claims

**1. Four places, and the rotation visits them in Karen's order and then loops — observed live, not
only asserted.**
`ForestTest.LAYOUT_ORDER` is `{ road, edge, ride, track }` and `ForestTest.nextLayout(previous)`
returns the next in it. **Verify:** `tests/server/forest_stand.spec.luau`, *"the rotation that deals
the places"* (three cases: the order over two full cycles, never twice running, and that nil or an
unknown name answers place 1 rather than nil). **Live:** one session in Karen's Forest Test, sampling
the published `Layout` attribute every 20 s across five drives, gave
**`road → edge → ride → track → road`** (`<runs-dir>/193-rotation2.log`).

**2. A forced drive never advances the cycle, and the first drive of a session is place 1.**
`ForestTest.layoutForDrive` keys the step on `chosen.rotated`, which the override branch never sets.
Without that, drive 1 of every session would be place 2, because `chosen.name` starts at the default
and `nextLayout` answers the one after. **Verify:** `forest_stand.spec`, *"deals a layout once per
drive"* (an override is reported as `source = "override"`, a bad override deals normally and reports
`"rotation"`), and the live log above, whose first sample is `road`.

**3. Every stand can see its own drive — and three of the four lines MOVED because a frame said they
could not.** This is the dispatch's gate rule (*"every stand: the hunter stands ON the ground, can see
the drive area"*) and the design could not check it (its §18: *"I measured nothing myself"*).
Measured in the place, first build: a ray north from eye height (+5) died on terrain at **60 studs**
at `edge` stand 4, at **62 and 65** at two `track` stands, at **89** at `ride` stand 1. Candidate lines
were then scored by walking the terrain along each stand's sight ray; the **whole west ground has no
line at all** where every stand sees 180 studs. The three lines moved to `edge` (3400, 190, −3250)
5 × 130, `ride` (4900, 166, −4500) 5 × 130, `track` (4700, 159, −3900) 6 × 130 — **worst intrusion
0.0 studs and a sight line past 400 studs at every stand of all three**. **Verify:** the numbers and
the reasons are in `ForestTest.LAYOUTS`' own comments per row; the frames are
`<runs-dir>/193-p2-north.png`, `193-p3-north.png`, `193-p4-north.png` (first-person, at a stand, in a
real drive).

**4. Every planted tree stands ON the ground, measured at the lowest point under every footprint
sample — and the metric is not a tautology.** `Places.plantOne` measures the terrain on
`TreeGround.samples`' 5 × 5 grid over the **trunk's** footprint (never the crown's, never the pivot)
and hands it to `TreeGround.decide`. **Verify, live:** over all **3,012** planted models in the three
places, the worst trunk-junction gap above the lowest ground under its footprint is **−0.177 studs**
(i.e. every one is sunk), and the worst lowest-visible-geometry gap is **−0.18**; `0 above tolerance`
in all three places. The number **varies by species as the arithmetic predicts** (the least-sunk item
is a fern, whose `sinkFor` is capped at a tenth of its 2.8-stud height), so it is a measurement and
not the setter echoed back — standing rule E's *"a metric that reads 0.00 for every item is reported
as SUSPECT"*.

**5. No tree is in a shooting lane and none is inside a stand circle, over every planting of every
place.** Nothing is planted within `halfStripStuds + LANE_STUDS` of the line — the strip is a
subtraction, so no later tweak can walk a tree into a lane. **Verify:**
`tests/server/places.spec.luau`, *"has no tree in any lane, in any place, by arithmetic the spec does
itself"* — it computes the gap from `Forest.roadZ` **and** asks `Plan.inLane`, because asking the
predicate alone proves only that the planner called its own predicate (design 10.4 item 3). The
companion case asserts `Plan.LANE_STUDS == Forest.PICK.standRadiusStuds` rather than describing it.

**6. The forest is at least as dense as the wood Karen already has, and the bar was measured off that
wood rather than invented.** Firing 21 rays over a 120° fan from every stand at eye height: the first
build's belts stopped **24 of 105** (ride) and **25 of 126** (track) within 300 studs — and the frame
showed open hillside through the trees. `Workspace.OurForest`, measured at five points inside it,
stops **8–14 of 36** (mean sight 242–272 studs). After bringing the young growth to the strip's lip
(herb band 30 → 6 and 14 → 4) and tightening the close cell (30 → 20, 28 → 18), the belts stop
**48 of 105** and **40 of 126**, mean 252 and 244. **Verify:** the probe is
`<runs-dir>`-side and read-only; the numbers are in the note's section 4.2 and in the plan rows' own
comments.

**7. Boars cross the hunters' line in every place, counted — and the counter can read zero.**
One forced drive per place, sampling every boar trunk's side of the line every 25 s:
**cut line 12, forest road 14, field edge 7** crossings, and **0 at t = 20 s and t = 45 s in all
three** — before any wave was released. 7 bots walking in every drive, **0 stuck**; 4, 4 and 9 waves;
0 `Stack Begin` and 0 error lines in all three consoles
(`<runs-dir>/193-drive-ride.txt`, `-track.txt`, `-edge.txt`).

**8. The Architect's five corrections are built.** (a) The planter no longer measures the ground with
a reader that can see its own trees: the boot hands it `ForestTest.terrainYAt`, there is **no default
reader**, and `ForestTest.GROUND_IGNORE` — now data — carries `DrivePlaces`, which `places.spec`
asserts against `Places.FOLDER` so the list cannot drift from the folder. (b) The north belt reaches
**640 studs**, past `beaterNorthStuds()` 580, through a coarse `deep` band at 60 studs, so the beaters
muster in trees instead of 306 studs of bare grass. (c) The neighbour test exists
(`minGapStuds` 10–14, a nine-cell check). (d) The three spec bugs are fixed. (e) `Places.plotOf`
clamps planting to the ground the BRIEF surveyed. **Verify:** `places.spec` has a case for each —
*"carries the north belt all the way to where the beaters muster"* (and that a tree really is planted
out there), *"never puts two trees in one stump, and the spec measures that itself"*, *"plants only on
the ground the BRIEF surveyed"*, *"is in the ground reader's ignore list"*, *"plants nothing when
nobody hands it a ground reader"*.

**9. The build is bounded and printed, not assumed.** The boot's own line, live:
`places: 3 dressed, 3012 planted (6895 parts), 0 skipped, 879 on a step, 0 missing, 10 paint call(s),
2.56s`. Against the design's §11 targets: plantings ≈ 3,000 ✓ (hard bound 4,500, and `places.spec`
asserts `#list ≤ capacity` per place), parts **6,895** against *< 25,000* ✓ (the ~7-descendants
estimate was pessimistic; it is 2.3), paint calls **10** against *≤ 12* ✓, build **2.56 s** against
*< 2.5 s* — **0.06 s over, reported as measured**.

**10. Smoke PASS on the player's path, in the place Karen plays.** 90 s, Forest Test, the lobby loop:
`gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=10 | worst playing sounds over 10 s: 1`,
`position @15s=ok @end=ok respawn+10s=ok`, **SMOKE PASS**. CI is green on the pushed head
(run 39016628025, success). `tools/studio_mcp.py selftest` and `tools/agents.py selftest` both PASS,
and the two new specs are in a `SCOPE_SPECS` scope (`places`, plus `match`).

---

## What I could not verify, and what I got wrong

* **The "along the ride / along the track" view, which is what two of Karen's frames actually show.**
  A capture during Play returns the **client's own camera**, and the client owns the look direction —
  a server-side `PivotTo` on the character is overridden within a frame. Every frame here is therefore
  the hunter looking **north, at his drive**, which is his working view but not ref-5's or ref-1's
  framing. Turning the camera needs the harness's real mouse input and was not done.
* **`193-p4b-north.png` is from the WEST RUN-OUT of the forest road (x 4365, outside the stand span),
  not from a stand**, and the belt is visibly thinner there — the plot clamp ends it at x 4290. It is
  kept because it is the worst spot, not the best; `193-p4-north.png` is the mid-line frame from
  stand 3.
* **Karen has seen none of this.** Every look decision is hers, and the design's K-list is open: the
  forest floor is green where her frames are brown leaf litter; there is **no crop model**, so place 2
  is a mown field and not her golden maize; all 61 models are in summer leaf and all seven frames are
  late autumn. None of that is faked, and none of it is fixed here.
* **A single-player session does not start a second drive by itself.** After a drive the lobby sends
  the player back to the lodge and unenrols him, so the rotation only steps when he takes a truck
  again — which is why claim 1's run steps him on every 20 s. My first rotation run did not, sat on
  `road` for 14 minutes, and I read that as a broken rotation before the HUD frame
  (`193-rot-hud.png`: `DRIVE 1 · WAITING players`, at the lodge, coins paid) showed what it was.
  Nothing in `src/server/Match/` was touched; **the Director may want to decide whether Karen can see
  the rotation at all without taking a truck between drives.**
* **The harness found two defects I had claimed were right**, and both are now fixed in `8b1a164`:
  my grid kept one point per cell where Bridson's invariant needs `r/√2`, so a point could be
  forgotten and a third tree land inside it (`places.spec:311` caught it — the module could not,
  because it was agreeing with itself); and `forest_stand.spec` still expected `layoutSource == "bag"`.
* **`879 of 3,891 candidates are refused "on a step"** (23%). The allowance is
  `max(TreeGround.CLIFF_STUDS, 0.10 × height)` rather than a flat 4, which recovered most of a 29%
  refusal rate; the junction still goes to the lowest ground either way, so nothing floats. Whether
  23% leaves visible holes is a look judgement nobody has made.
* **That a Play-session terrain write is discarded on stop** is `Lobby.Field`'s standing property in
  this same place, and the design (§18) flagged it as unverified. I did not verify it either: the
  paint runs only inside Play (the boot), so no Edit-time write exists to inspect, and Karen's place
  file was never written by this task.

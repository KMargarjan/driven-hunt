# Review request — Task 193: four real driven-hunt places, a new one each drive

Task: 193
Round: 3
Base: `c02f65e` (main, PR #181 merged)
Code commit: `87079508403516035a5f90476287d80adff10468`

Harness, clean tree, at the code commit:

```
[harness] PASS: 33/33 checks @ 87079508403516035a5f90476287d80adff10468 (clean tree) scope=all
```

`87079508` is the paperwork commit that carries round 2's `RESULT.md`; the last commit that changed
`src/` or `tests/` is its parent `1a08a2e`, so this line covers all of the code and is the stricter
bound (git workflow step 4). `test2` is **N/A** — nothing in `TWO_PLAYER_PATHS` is touched (checked
against `origin/main`). CI green on the pushed head (run 39020141324).

## What changed

Karen, 2026-10-15: *"make 4 hunting places where each time person will be in new place when is hunter
then loop it again"*, and *"be sure you do it properly not fake it or broken"*.

A **fourth layout** (`track`, the forest road) and a **fixed rotation 1 → 2 → 3 → 4**, replacing task
179's shuffled bag. Plus **one new system**: a pure planner (`ReplicatedStorage.Places`) and a thin
planter (`ServerScriptService.Places`, the one writer of `Workspace.DrivePlaces`), with `Places.Ground`
the only caller of `Terrain`. Step 0 ran (BRIEF, design **PASS**, research note); all five of the
design's §10 corrections are built, and §16's two behind-the-code updates were applied to `lobby.md`
and `drive.md` (lesson L-071).

---

## Round 2's blocking finding

**The cut line's north belt was planted through the forest road's track and across five of its six
stands, and neither spec case could see it.** `Places.layer` asked `inLane` about its **own** layout
only. Task 179 had the places 3,300 studs apart in x so that was harmless; round 1 re-sited them for
sight lines and put the cut line 600 studs south of the forest road — and the cut line's north belt
reaches 684 studs. My own comment called the shared wood a feature and never checked it against the
other place's lane. **Round 2's claim 4 was false.**

**FIXED, by making the rule global rather than by opening a gap.** `Places.clearOfEveryLane(x, z)`
refuses a candidate inside **any** place's lane — `road` included, whose half-width is `LANE_STUDS`
alone because its stands are still circles on its line. The Reviewer put the conflict exactly: at
these two centres *"the belt reaches the beaters' muster"* and *"no tree in the track's lane"* cannot
both hold **if the belt must be unbroken**. It need not — **a cleared corridor through the wood is
what a forest road is.** The cut line's north belt now reaches its full 640 studs with a 42-stud gap
where the forest road crosses it, which keeps both properties and is the more honest landscape. Moving
a line would throw away the sight-line measurement that put it there, and no scored candidate pair is
far enough apart to avoid the overlap.

**Verify:**
* `src/shared/Places/init.luau`, `Places.clearOfEveryLane` and `Places.laneHalfWidth`, called from
  `layer` at the **jittered** point.
* `tests/server/places.spec.luau`, *"has no tree in ANY place's lane — every planting against every
  layout"* and *"keeps every tree clear of EVERY place's stand circles"*. Both now loop
  **planting × layout**, do the arithmetic themselves from `Forest.roadZ` / `Forest.standPosition`
  **and** ask the predicate, and report the tightest margin they saw. The old pair compared each
  place's trees against its own line, so the cross-place claim in their names could not fail.
* **Live, in the world, over the instances actually made** (not the plan): `3020 planted | in a lane:
  0 (tightest margin 0.1 studs, track tree vs track) | in a stand circle: 0 (tightest 10.4, ride tree
  vs track stand 2)`. The 0.1 is a track tree against its own strip edge, which is the rule touching
  its own boundary by construction.

Round 2's notes 1–3 are fixed too: `chosen.rotated` is gone (both branches had the same answer once
`chosen.cycle` existed), `stats().layoutNext` reads the cycle rather than the forced name, and the
forced-cycle case no longer claims a "place 1" half it does not assert — the name says what it tests,
and the rule it rests on (`nextLayout(nil) == LAYOUT_ORDER[1]`) is asserted in `Data`'s own cases.
Note 4 (`Places.plotOf`) stands and is queued as 193a.

---

## Claims

**1. Four places, and the rotation visits them in Karen's order and then loops — observed live.**
**Verify:** `forest_stand.spec`, *"the rotation that deals the places"* (the order over two full
cycles; never twice running; nil or an unknown name answers place 1) and *"does not let a forced drive
move the cycle"*. **Live:** sampling the published `Layout` attribute every 20 s across five drives
gave **`road → edge → ride → track → road`** (`<runs-dir>/193-rotation2.log`).

**2. A forced drive does not move the cycle** — `chosen.cycle`, not `chosen.name`, is what the
rotation steps from, because `promote` writes `name` for a forced drive too. **Verify:** the case
above deals a rotated drive, forces a place chosen to be **neither** the current one nor the next, and
asserts the following rotated drive is the place after the last **rotated** one. It fails on round
2's code.

**3. Every stand can see its own drive — and three of the four lines MOVED because a frame said they
could not.** The dispatch's gate rule, which the design could not check (§18: *"I measured nothing
myself"*). First build: a ray north from eye height (+5) died on terrain at **60 studs** at `edge`
stand 4, **62 and 65** at two `track` stands, **89** at `ride` stand 1. Candidates were scored by
walking the terrain along each stand's sight ray; the **whole west ground has no line** where every
stand sees 180 studs. Shipped: `edge` (3400, 190, −3250) 5 × 130, `ride` (4900, 166, −4500) 5 × 130,
`track` (4700, 159, −3900) 6 × 130 — **worst intrusion 0.0 studs, sight line past 400 studs, at every
stand of all three**. **Verify:** each `LAYOUTS` row's comment; frames `<runs-dir>/193-p2-north.png`,
`193-p3-north.png`, `193-p4-north.png` (first person, on a stand, in a real drive).

**4. Every planted tree stands ON the ground, measured at the lowest point under every footprint
sample — and the metric is not a tautology.** **Live:** over all planted models the worst
trunk-junction gap above the lowest ground under its own footprint is **−0.177 studs** (every one
sunk), worst lowest-visible-geometry gap **−0.18**, `0 above tolerance` in all three places. The
number **varies by species as the arithmetic predicts** — the least-sunk item is a fern, whose
`sinkFor` is capped at a tenth of its 2.8-stud height — so it is a measurement and not the setter
echoed back (standing rule E). **With no world:** `places.spec`, *"never plants a tree above the
ground, on a hillside it has never seen"* re-measures the junction off the settled model, and
*"allows a bigger step for a bigger tree"* drives both branches of `stepAllowance`.

**5. The forest is at least as dense as the wood Karen already has, and that bar was measured off
that wood.** 21 rays over a 120° fan from every stand at eye height: the first build stopped **24 of
105** (ride) and **25 of 126** (track) within 300 studs, and the frame showed open hillside through the
trees. `Workspace.OurForest` at five points inside it stops **8–14 of 36** (mean sight 242–272).
Shipped: **48 of 105** and **40 of 126**, mean 252 and 244.

**6. Boars cross the hunters' line in every place, counted — and the counter can read zero.** One
forced drive per place: **cut line 12, forest road 14, field edge 7** crossings, and **0 at t = 20 s
and t = 45 s in all three**, before any wave. 7 bots walking, **0 stuck**, in every drive; 4, 4 and 9
waves; 0 `Stack Begin` and 0 error lines (`<runs-dir>/193-drive-*.txt`).

**7. The Architect's five corrections are built**, each with its own spec case: the terrain-only
reader handed in by the boot (no default), `GROUND_IGNORE` as data carrying `DrivePlaces` and asserted
against `Places.FOLDER`, the 640-stud north belt through a coarse `deep` band, the neighbour test, the
three spec bugs, and `Places.plotOf`.

**8. The build is bounded and printed, not assumed.** Live:
`places: 3 dressed, 3020 planted (6916 parts), 0 skipped, 871 on a step, 0 missing, 10 paint call(s),
2.73s`. Against design §11: plantings ≈ 3,000 ✓ (`places.spec` asserts `#list ≤ capacity` per place),
parts **6,916** against *< 25,000* ✓, paint calls **10** against *≤ 12* ✓, build **2.73 s** against
*< 2.5 s* — **0.23 s over and reported as measured**; the global lane rule costs a loop over four
layouts per candidate and that is where it went.

**9. Smoke PASS on the player's path, in the place Karen plays.** 90 s, Forest Test, lobby loop:
`gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=10`, `position @15s=ok @end=ok
respawn+10s=ok`, **SMOKE PASS**. Both selftests PASS; the new spec file is in a `SCOPE_SPECS` scope.

**10. `road` is untouched, number for number** (BRIEF decision 3). **Verify:** `forest_stand.spec`'s
`fieldFor(ROAD_LAYOUT)` identity case, and `Plan.planFor("road") == nil` in `places.spec`.

---

## What I could not verify, and what I got wrong

* **The cross-place defect was mine and the Reviewer found it, not me** — and my own comment presented
  the overlap as a feature. Round 2's claim 4 was false. It is fixed in `1a08a2e` and re-measured in
  the world.
* **The "along the ride / along the track" view, which two of Karen's frames show.** A capture during
  Play returns the **client's own camera** and the client owns the look direction, so a server-side
  `PivotTo` is overridden within a frame. Every frame here is the hunter looking **north at his
  drive** — his working view, but not ref-5's or ref-1's framing. Turning the camera needs the
  harness's real mouse input and was not done.
* **`193-p4b-north.png` is from the WEST RUN-OUT of the forest road (x 4365, outside the stand span)**,
  where the belt is visibly thinner — the plot clamp ends it at x 4290. Kept because it is the worst
  spot; `193-p4-north.png` is the mid-line frame.
* **Karen has seen none of this.** The design's K-list is open and nothing in it is faked: the floor is
  green where her frames are brown leaf litter; there is **no crop model**, so place 2 is a mown field
  and not her golden maize; all 61 models are in summer leaf and all seven frames are late autumn.
* **A single-player session does not start a second drive by itself** — the lobby sends the player back
  to the lodge and unenrols him, so the rotation steps only when he takes a truck again. My first
  rotation run did not, sat on `road` for 14 minutes, and I read that as a broken rotation until the
  HUD frame showed `DRIVE 1 · WAITING players`. Nothing in `src/server/Match/` was touched; **the
  Director may want to decide whether Karen should have to take a truck between drives to see the
  rotation at all.**
* **Four defects of mine were caught by the harness or the Reviewer, not by me:** the grid kept one
  point per cell where Bridson's invariant needs `r/√2`; `forest_stand.spec` still expected
  `layoutSource == "bag"`; a forced drive moved the cycle; and the cross-place lane. The first two are
  in `8b1a164`, the third in `c3367c3`, the fourth in `1a08a2e`.
* **871 of ~3,900 candidates are refused "on a step"** (22%). Whether that leaves visible holes is a
  look judgement nobody has made.
* **`Places.plotOf`'s case still asserts against the planner's own declared plot** and so cannot catch
  the plot drifting off surveyed ground; for `edge` the declared plot (x 2990…3810) is wider on the
  west than BRIEF M6's survey (x 3100…3860). Nothing collides today (nearest lobby ring tree x ≤ 2959).
  Queued as 193a.
* **That a Play-session terrain write is discarded on stop is carried from `Lobby.Field`, not
  verified** — stated as an assumption in `Ground.luau`'s header, with design §18's consequence if it
  is false.

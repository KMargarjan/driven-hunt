# Review request — Task 193: four real driven-hunt places, a new one each drive

Task: 193
Round: 2
Base: `c02f65e` (main, PR #181 merged)
Code commit: `064872c1c5fcfa2a1b8057544b8560854b55bc5f`

Harness, clean tree, at the code commit:

```
[harness] PASS: 33/33 checks @ 064872c1c5fcfa2a1b8057544b8560854b55bc5f (clean tree) scope=all
```

`test2` is **N/A** — nothing in `TWO_PLAYER_PATHS` is touched (no `src/server/Match/`,
`src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau` or any named spec; checked against
`origin/main`). CI green on the pushed head (run 39018854827).

## What changed

Karen, 2026-10-15: *"make 4 hunting places where each time person will be in new place when is hunter
then loop it again"*, and *"be sure you do it properly not fake it or broken"*.

A **fourth layout** (`track`, the forest road) and a **fixed rotation 1 → 2 → 3 → 4**, replacing task
179's shuffled bag — her own sentence reversed that decision. Plus **one new system**: a pure planner
(`ReplicatedStorage.Places`) and a thin planter (`ServerScriptService.Places`, the one writer of
`Workspace.DrivePlaces`), with `Places.Ground` the only caller of `Terrain`.

Step 0 ran: `reviews/task-193/BRIEF.md`, `docs/design/drive-places.md` (Architect **PASS**) and
`docs/research/2026-10-17-four-driven-hunt-places.md`. All five of the design's §10 corrections are
built, and §16's two behind-the-code updates were applied to `lobby.md` and `drive.md` rather than
promised (lesson L-071).

---

## Round 1's two blocking findings, and the note that was really a third

**F1. `Places.Ground`'s header claimed task 193 verified that a Play-session terrain write is
discarded on stop — the request said the opposite, and the request was right.** FIXED: the header now
states it as **carried from `Lobby.Field`'s precedent and never re-tested**, names design §18's
consequence if it is false (the paint would be a change to Karen's place file, rule 7 territory), and
says why no Edit-time write exists to inspect — the paint runs only from the boot, i.e. only inside
Play. **Verify:** `src/server/Places/Ground.luau`, the paragraph beginning *"THE ROLLBACK IS THAT
THERE IS NOTHING TO ROLL BACK"*.

**F2. `plantOne` and `stepAllowance` had no spec case at all** — the function that actually puts a
tree on the ground, and a step rule this task invented. FIXED, as design §12.1 case 22 and §12.2 ask.
**Verify:** `tests/server/places.spec.luau`:
* *"never plants a tree above the ground, on a hillside it has never seen"* — drives the real
  `plantOne` with a fake tree and a fake slope, **re-measures the junction off the settled model**
  (not from the planter) and asserts it is below the lowest sample under the footprint; a footprint
  across a step answers `"cliff"` **and leaves no instance behind**; unanswerable ground likewise.
* *"allows a bigger step for a bigger tree, with the tool's number as the floor"* — both branches of
  `stepAllowance`, including where the floor and the fraction cross.
* *"keeps the resting wood inside the belt"* — design §12.2:
  `REST.farRoadStuds ≤ northBeltStuds − LANE_STUDS` for every dressed layout with a north belt
  (425 ≤ 628). `edge` has no north belt by design, and its beaters muster inside the existing wood.

**F3 (round 1's note 6, which was a defect and not a note). A forced drive DID move the cycle.**
`promote` writes `chosen.name` for every source, so advancing from it resumed the rotation at the
**forced** place: force `road` at drive 3 while the cycle sat at `edge`, and drive 4 deals `edge`
again. Claim 2 of round 1 overstated this and design §5 item 3 was only nearly true. FIXED:
`chosen.cycle` holds where the cycle itself is, and the rotation advances from that. **Verify:**
`tests/server/forest_stand.spec.luau`, *"starts a session at place 1, and a forced drive does not move
the cycle"* — it deals a rotated drive, forces a place chosen to be **neither** the current one nor
the next, and asserts the following rotated drive is the place after the last **rotated** one. That
case fails on the old code.

Round 1's other notes are fixed where they were stale numbers (the field is 350 studs / 98 m, not
504; the beaters form up **230** studs inside the wood, not 80; `band` includes `"deep"`; the spec
header says ~3,000 trees; `forest_stand`'s "bag" wording). The remaining notes are queued in
`TASKS.md` as 193a, not fixed here.

---

## Claims

**1. Four places, and the rotation visits them in Karen's order and then loops — observed live.**
**Verify:** `forest_stand.spec`, *"the rotation that deals the places"* (the order over two full
cycles; never twice running; nil or an unknown name answers place 1 rather than nil) and the new F3
case. **Live:** sampling the published `Layout` attribute every 20 s across five drives in Karen's
Forest Test gave **`road → edge → ride → track → road`** (`<runs-dir>/193-rotation2.log`).

**2. Every stand can see its own drive — and three of the four lines MOVED because a frame said they
could not.** The dispatch's gate rule, which the design could not check (its §18: *"I measured nothing
myself"*). First build, measured: a ray north from eye height (+5) died on terrain at **60 studs** at
`edge` stand 4, **62 and 65** at two `track` stands, **89** at `ride` stand 1. Candidates were then
scored by walking the terrain along each stand's sight ray; the **whole west ground has no line** where
every stand sees 180 studs. Shipped: `edge` (3400, 190, −3250) 5 × 130, `ride` (4900, 166, −4500)
5 × 130, `track` (4700, 159, −3900) 6 × 130 — **worst intrusion 0.0 studs, sight line past 400 studs,
at every stand of all three**. **Verify:** each `ForestTest.LAYOUTS` row's own comment carries the
numbers and the reason; the frames are `<runs-dir>/193-p2-north.png`, `193-p3-north.png`,
`193-p4-north.png` (first person, on a stand, in a real drive).

**3. Every planted tree stands ON the ground, measured at the lowest point under every footprint
sample — and the metric is not a tautology.** **Verify, live:** over all **3,012** planted models the
worst trunk-junction gap above the lowest ground under its own footprint is **−0.177 studs** (every
one sunk), worst lowest-visible-geometry gap **−0.18**, `0 above tolerance` in all three places. The
number **varies by species as the arithmetic predicts** — the least-sunk item is a fern, whose
`sinkFor` is capped at a tenth of its 2.8-stud height — so it is a measurement and not the setter
echoed back (standing rule E). **With no world:** the new case 22 above.

**4. No tree is in a shooting lane and none is inside a stand circle, over every planting of every
place.** Nothing is planted within `halfStripStuds + LANE_STUDS` of the line: the strip is a
subtraction, so no later tweak can walk a tree into a lane. **Verify:** `places.spec`, *"has no tree in
any lane, in any place, by arithmetic the spec does itself"* — it computes the gap from `Forest.roadZ`
**and** asks `Plan.inLane`, because asking the predicate alone proves only that the planner called its
own predicate. The companion case asserts `Plan.LANE_STUDS == Forest.PICK.standRadiusStuds`.

**5. The forest is at least as dense as the wood Karen already has, and that bar was measured off
that wood rather than invented.** 21 rays over a 120° fan from every stand at eye height: the first
build stopped **24 of 105** (ride) and **25 of 126** (track) within 300 studs, and the frame showed
open hillside through the trees. `Workspace.OurForest` at five points inside it stops **8–14 of 36**
(mean sight 242–272). Shipped: **48 of 105** and **40 of 126**, mean 252 and 244. **Verify:** the
note's §4.2 and the plan rows' own comments carry the numbers.

**6. Boars cross the hunters' line in every place, counted — and the counter can read zero.** One
forced drive per place: **cut line 12, forest road 14, field edge 7** crossings, and **0 at t = 20 s
and t = 45 s in all three**, before any wave. 7 bots walking, **0 stuck**, in every drive; 4, 4 and 9
waves; 0 `Stack Begin` and 0 error lines (`<runs-dir>/193-drive-ride.txt`, `-track.txt`, `-edge.txt`).

**7. The Architect's five corrections are built.** (a) The planter takes a terrain-only reader handed
in by the boot, has **no default reader**, and `ForestTest.GROUND_IGNORE` — now data — carries
`DrivePlaces`, asserted against `Places.FOLDER` so the list cannot drift. (b) The north belt reaches
**640 studs**, past `beaterNorthStuds()` 580, through a coarse `deep` band. (c) The neighbour test
exists. (d) The three spec bugs are fixed. (e) `Places.plotOf` clamps planting to the surveyed ground.
**Verify:** `places.spec` has a case for each.

**8. The build is bounded and printed, not assumed.** The boot's own line, live:
`places: 3 dressed, 3012 planted (6895 parts), 0 skipped, 879 on a step, 0 missing, 10 paint call(s),
2.56s`. Against design §11: plantings ≈ 3,000 ✓ (`places.spec` asserts `#list ≤ capacity` per place),
parts **6,895** against *< 25,000* ✓, paint calls **10** against *≤ 12* ✓, build **2.56 s** against
*< 2.5 s* — **0.06 s over, reported as measured**.

**9. Smoke PASS on the player's path, in the place Karen plays.** 90 s, Forest Test, lobby loop:
`gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=10`, `position @15s=ok @end=ok
respawn+10s=ok`, **SMOKE PASS**. `tools/studio_mcp.py selftest` and `tools/agents.py selftest` both
PASS; the new spec file is in a `SCOPE_SPECS` scope (`places`, and also `match`).

**10. `road` is untouched, number for number.** BRIEF decision 3. **Verify:** `forest_stand.spec`'s
existing case asserting `fieldFor(ROAD_LAYOUT)` is bit-for-bit the table the boot used to build, and
`Plan.planFor("road")` is `nil` — `places.spec`, *"dresses every layout that is not the road"*.

---

## What I could not verify, and what I got wrong

* **The "along the ride / along the track" view, which is what two of Karen's frames show.** A capture
  during Play returns the **client's own camera** and the client owns the look direction, so a
  server-side `PivotTo` is overridden within a frame. Every frame here is the hunter looking **north
  at his drive** — his working view, but not ref-5's or ref-1's framing. Turning the camera needs the
  harness's real mouse input and was not done.
* **`193-p4b-north.png` is from the WEST RUN-OUT of the forest road (x 4365, outside the stand span)**,
  where the belt is visibly thinner — the plot clamp ends it at x 4290. Kept because it is the worst
  spot, not the best; `193-p4-north.png` is the mid-line frame from stand 3.
* **Karen has seen none of this.** The design's K-list is open and none of it is faked: the forest
  floor is green where her frames are brown leaf litter; there is **no crop model**, so place 2 is a
  mown field and not her golden maize; all 61 models are in summer leaf and all seven frames are late
  autumn.
* **A single-player session does not start a second drive by itself.** After a drive the lobby sends
  the player back to the lodge and unenrols him, so the rotation only steps when he takes a truck
  again — which is why claim 1's run steps him on every 20 s. My first rotation run did not, sat on
  `road` for 14 minutes, and I read that as a broken rotation until the HUD frame
  (`193-rot-hud.png`: `DRIVE 1 · WAITING players`, at the lodge, coins paid) showed what it was.
  Nothing in `src/server/Match/` was touched; **the Director may want to decide whether Karen should
  have to take a truck between drives to see the rotation at all.**
* **Three defects of mine were caught by the harness and the Reviewer, not by me:** the grid kept one
  point per cell where Bridson's invariant needs `r/√2`, so a point could be forgotten and a third
  tree land inside it (`places.spec:311`); `forest_stand.spec` still expected `layoutSource == "bag"`;
  and a forced drive moved the cycle (F3 above). The first two are in `8b1a164`, the third in
  `c3367c3`.
* **`879 of 3,891 candidates are refused "on a step"** (23%). Whether that leaves visible holes is a
  look judgement nobody has made.
* **Round 1's note on `Places.plotOf`** is right and is **not** fixed: the case asserts `item.x`
  against the planner's own declared plot, so it cannot catch the plot drifting off surveyed ground,
  and for `edge` the declared plot (x 2990…3810) is wider on the west than BRIEF M6's survey
  (x 3100…3860). Nothing collides today (the nearest lobby ring tree is x ≤ 2959). Queued as 193a.
* **That a Play-session terrain write is discarded on stop is still carried, not verified** (F1).

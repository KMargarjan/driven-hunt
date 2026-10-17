PASS

Round 2's blocking finding is genuinely fixed, not papered over.
`src/shared/Places/clearOfEveryLane` loops `Forest.LAYOUT_ORDER`, resolves each layout and refuses
any candidate with `math.abs(z - Forest.roadZ(x, layout)) <= Places.laneHalfWidth(Places.planFor(name))`
— `road` included, at half-width 12 with no plan — and `Places.layer` asks it at the jittered point
(`if jx >= minX and jx <= maxX and Places.clearOfEveryLane(jx, z)`). Checked by hand: `ride`'s north
belt reaches z −3818, `track`'s lane is z −3921…−3879, and that band is now refused; `track`'s north
belt reaches −3241 and `edge`'s lane (−3292…−3208) refuses its top; `edge`'s own field is untouched
(`northBeltStuds = 0`, and no other place's accepted tree lands north of −3292). `LANE_STUDS` ==
`PICK.standRadiusStuds` and every stand sits at `roadZ(standX)`, so clearing every lane clears every
stand circle by construction.
Both spec cases can now fail: *"has no tree in ANY place's lane"* loops planting × layout and asserts
`gap > clear` from its own `Forest.roadZ` arithmetic before also asking the predicate; *"keeps every
tree clear of EVERY place's stand circles"* loops planting × layout × `other.standCount` off
`Forest.standPosition`. On round 2's code the first would fail on the ride/track pair.
Round 2's notes 1–3 are fixed: `chosen.rotated` is gone, `stats().layoutNext = Data.nextLayout(chosen.cycle)`,
and the forced-cycle case's name no longer claims the place-1 half it does not assert.
Harness line names `Code commit: 87079508…` with "(clean tree)";
`paperwork-after-code-commit.txt` says only `REQUEST.md` followed it. selene 0/0, stylua clean,
rojo build exit 0.

## Notes (non-blocking)
- `docs/design/drive-layouts.md` — §4.4 (`state.bag`, `layoutSource = "default" | "bag" | "override"`), §5.1's owner row (*"Which layout is live (the choice, the bag, the override) … `state.bag`"*), §5.2's pseudocode (`name, state.bag := Data.nextLayout(state.layoutName, state.bag, roll)`, `source := "bag"`) and the whole of §5.4 *"The bag, written out"* still document the shuffled bag and a three-argument `nextLayout` that no longer exists (`ForestTest.nextLayout(previous)` only). `drive-places.md` §15.1 asked for exactly these to be replaced; the diff to this file touches only its first ~210 lines. Replace them with the rotation, keeping the Tetris/DevForum sources as superseded history as §15.1 says.
- `docs/design/forest-drive.md`, `docs/design/map-ui.md` — the deltas the design requires (§15.2: the `GROUND_IGNORE`/`DrivePlaces` sentence in §4.1.5 and the untagged-wood sentence in §6.3; §15.3: the four-row bounds table and the lodge sentence in §5.5) are not applied — neither file is in the change. Queue or apply.
- `docs/design/drive-places.md` §9 — still states the rule as per-layout and cites *"`Places.layer`'s `if not Places.inLane(jx, z, layout, plan)` already does exactly this"*. Since round 3 the call is `Places.clearOfEveryLane(jx, z)` over every layout; §9 is the section blocking kind 1 is judged against, so it should say so, with the 42-stud corridor named.
- `docs/design/drive-places.md` §11 — four stale rows: *"A forced drive advances the rotation | never | by construction (`chosen.rotated`)"* (`chosen.rotated` was deleted; the fact now rests on `chosen.cycle`); *"Minimum distance between two planted trees ≥ `minGapStuds` (16–19)"* against the shipped 14 / 11 / 10; *"Field, place 2: guns to the far tree line 500 studs = 140 m"* against the shipped 350 studs = 98 m; *"Build cost < 2.5 s"* against the measured 2.73 s. The build numbers are the honest ones and the request reports all of them — it is the table that moved.
- `src/shared/Places/init.luau`, `clearOfEveryLane` — a layout's lane is treated as an **infinite** line in x, so a candidate is refused against a lane whose stand span is nowhere near it. Measured consequence: the top ~51 studs of `track`'s north belt (z −3292…−3241) is cut by `edge`'s lane, although the two places share no x at all (`widthOf(edge)` 2990…3810 against `widthOf(track)` 4290…5110). Nothing visible today — it is 560+ studs out behind 230 studs of dense wood — and it is the safe direction, but bounding the test by the other layout's `standSpan` ± its run-out would stop it and would also take back part of the loop that cost the 0.23 s.
- `src/shared/ForestTest/init.luau`, `LAYOUTS.ride`'s comment — still reads *"`track`'s line is 600 studs north of this one, so this place's north belt and that place's south belt are one continuous wood"*. Since round 3 it is one wood with a 42-stud cleared corridor through it. `Places.clearOfEveryLane`'s header says this correctly; this comment is the one the round-2 finding quoted and it still presents the overlap as unbroken.
- `src/shared/ForestTest/init.luau` / `src/shared/Places/init.luau` — a consequence of the corridor worth Karen's eye rather than a rule break: `beaterStart(x, 0, LAYOUTS.ride).Z` is −4500 + 580 = **−3920**, which is inside `track`'s lane (−3921…−3879), so the cut line's beaters muster on the forest road's painted track instead of in cover. Design §10.2 raised the belt to 640 precisely so they would not form up in the open; 42 studs of open is left, and it is a road crossing, which is defensible — but nobody has looked at it.
- `tests/server/places.spec.luau`, *"carries the north belt all the way to where the beaters muster"* — design 12.1 case 9 has three clauses and the case asserts two: *"and the far edge is inside `boundsOf(layout).maxZ`"* is not asserted. The property holds by arithmetic (`ride` far edge −3818 against `boundsOf.maxZ` −3620; `track` −3241 against −3020), so this is a missing assertion rather than a defect.
- `Places.plotOf` / *"plants only on the ground the BRIEF surveyed"* — rounds 1 and 2's note still stands and the request agrees (queued 193a): design §10.5's fix says `edge`'s surveyed range is x 3080…3880, the shipped plot is 2990…3810, and the case asserts `item.x` against the planner's own declaration, so it cannot catch the plot drifting off surveyed ground. Nothing collides (nearest lobby ring tree x ≤ 2959 against a west edge of 2990), but the 110 unsurveyed studs are real.
- `reviews/task-193/REQUEST.md`, claim 2 — *"It fails on round 2's code"* is wrong by one round: round 2 already stepped from `chosen.cycle` (round 2's `RESULT.md` note 2 quotes `if chosen.rotated then Data.nextLayout(chosen.cycle) else Data.LAYOUT_ORDER[1]`), so the case would have passed on it. It fails on round 1's. The case itself drives the invariant correctly.
- `src/server/Places/init.luau` — 871 of ~3,900 candidates refused `"cliff"` (22%), and the request says plainly that whether that leaves visible holes is a look judgement nobody has made. Worth putting in front of Karen with a frame rather than leaving in prose.

---
REVIEWER verdict on commit `24b4fec6c570eda859f64063473f5c26892a1545` (round 3) · 2026-10-17 09:21 UTC · session cost $5.14, 44 turns · written by tools/agents.py

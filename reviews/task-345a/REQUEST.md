# Task 345a (T1): the pure rules of animal placement, dark

Task: 345a
Round: 2
Base: 0ded8b8f (the design, on top of `main` 459f89ed / #357)
Round 1's code commit: 9df17202 — the two L-028 delete-and-fail proofs in claims 4 and 5 were run at
it, and neither guard changed in round 2.
Code commit: 62ed274aab75bdb43b160eb63dac2d1a000b13f9

`[harness] PASS: 34/34 checks @ 62ed274aab75bdb43b160eb63dac2d1a000b13f9 (clean tree) scope=all`

`test2`: **N/A**. No path here is in `TWO_PLAYER_PATHS` (`src/shared/ForestTest/`, `src/shared/Flags/`,
`tests/server/`, `tools/studio_mcp.py`, `docs/`), and `docs/design/animal-placement.md` section 17
says so for all six of T1..T6. Nothing in this change can behave differently with a second player:
no code in the live path reads any of it.

## What changed

T1 of the design's section 17, and nothing else.

* **`src/shared/ForestTest/Placement.luau`** (new). The pure rules: the roster, the band
  (`bandFar` / `bandNear` / `bedNorth`, deepest bed first), the bed gap and the sideways sweep that
  keeps it (`clearX`, `gapOk`), the distance half of never-in-view (`clearOfEyes`), the budget door
  (`roomFor`), the due rule (`dueNow`), the wake rule (`wakeReason`), the lane classification
  (`laneOf`) and the console line (`tally`, `line`).
* **`tests/server/forest_placement.spec.luau`** (new, in the `match` scope).
* **`src/shared/Flags/init.luau`**: `PLACEMENT_IN_PLACE` born OFF, and `MAX_FLAGS` 23 → 24.
* **`docs/research/2026-11-10-animal-placement.md`** + its `INDEX.md` row (rule 1).
* **`tools/studio_mcp.py`**: one `SCOPE_SPECS` entry for the new spec (rule G).

**Nothing in the live path reads the module or the flag.** No existing `src/` file changed except the
flag table. Flag OFF is byte-for-byte today's drive.

## Claims

1. **The module is pure and can never be a second writer.** `Placement.luau` has no `require`, no
   `game:GetService`, no `Instance.new`, no `workspace`, no `RunService`, no `os.clock` and no
   `task.*` on any CODE line. Verify (the leading `^[^-]*` skips comment lines, where three of these
   words do appear, in the header that promises they are absent):
   `grep -nE '^[^-]*(require\(|game:GetService|Instance\.new|workspace|RunService|os\.clock|task\.)' src/shared/ForestTest/Placement.luau`
   → no output. Every fact it uses is a parameter, including the owners' own functions (`Deps`).
2. **Nothing live reads it.** Verify:
   `grep -rnE 'WaitForChild\("Placement"\)|ForestTest\.Placement|script\.Placement' src/ tests/`
   → two hits, and neither is a reader: a prose line in the `Flags` comment, and the spec's own
   `require`. `grep -rn "PLACEMENT_IN_PLACE" src/` → only the `Flags` row and its `MAX_FLAGS`
   comment. And **no file under `src/server/` or `src/client/` changed at all**:
   `git diff --name-only 0ded8b8f..62ed274a` lists ten paths — three of them `reviews/` /
   `TASKS.md` / `ESCALATE.md` paperwork — of which the only `src/` ones are
   `src/shared/Flags/init.luau` and the new `src/shared/ForestTest/Placement.luau`.
3. **The roster is the dial, and the dial is `Data.slotAt`'s.** `plan` asks `deps.slotAt` once per
   slot and copies none of its rules. MEASURED by the spec's own notes:
   quiet **9 groups / 53 animals**, normal **13 / 73**, busy **15 / 83**, matching design 5.2.
   Verify: the case "keeps exactly the rows Data.slotAt keeps, at every density" compares the
   roster's slot list and animal total against a list rebuilt from `Data.slotAt` and
   `Boar.compositionSize` / `Boar.deerComposition` in the spec.
   **ROUND 1's BLOCKING FINDING, FIXED, and it was right.** The second case drove
   `DENSITIES.normal = 1`; every one of the fifteen rows carries `keepAt` 9, 13 or 15, so that dial
   keeps NOTHING and the case asserted `0 == 0` — it survived gutting `plan`. It now drives
   `DENSITIES.normal = DENSITIES.quiet` (**9**), which keeps a NON-EMPTY subset that is not the
   shipped one, and asserts four things: `#wanted > 0`, the moved roster's slot list equals
   `Data.slotAt`'s at that dial, `#moved < #unmoved` (9 against 13), and
   `#unmoved − #moved == DENSITIES.normal − DENSITIES.quiet`. Verify it bites: `return {}, {}` from
   `plan` now fails it on `#moved == #wanted`, and ignoring the dial fails it on `#moved < #unmoved`.
4. **The band is derived, not written, and it cannot start inside a hunter's reach.**
   `bandFar == beaterNorth − Data.noticeAheadStuds − SPOOK.SWEEP.MIN_AHEAD_STUDS`, asserted at the
   shipped muster **and at 700**, so moving `BEATER.behindLineStuds` moves the band.
   `bandNear == max(neverStuds, REST.nearRoadStuds)` rounded up, and `neverStuds ==
   SPOOK.NOTICE_STUDS + bedSpreadStuds/2`. The published `CONFIG` rows are asserted equal to the
   derivations, and the four radii are asserted in order
   (`bedSpread < bedGap < never <= bandNear`). **L-028 FAIL FIRST, RUN at `9df17202`:** replacing
   `bandNear`'s `math.max(never, road)` with `road` fails
   `forest_placement.spec:220` — `Expected value "true" (boolean), got "false" (boolean) instead`
   (`[tests:server] FAIL: 2917 passed, 1 failed`). :220 is `expect(near >= never)`, the line whose
   own comment names that deletion.
5. **`clearOfEyes` refuses inside the reach, says how far, and is 3-D.** **L-028 FAIL FIRST, RUN at
   `9df17202`:** replacing its body with `return true, math.huge` fails
   `forest_placement.spec:322` and `:344` — both `Expected value "false" (boolean), got "true"
   (boolean) instead` (`[tests:server] FAIL: 2916 passed, 2 failed`). The two lines are the plain
   refusal at 144 studs and the high-seat refusal at 144 studs flat + 12.5 up.
   **One correction to design 13.1:** it predicts that deletion fails "cases 6 and 9". It does not
   fail case 9: `dueNow` never consults `clearOfEyes`, so a skip-is-a-skip case cannot see that
   deletion. What it fails is both halves of case 6, which is what the run shows. Case 9 has its own
   guard and its own case (claim 8).
   The spec also carries the case that proves the **third dimension is used at all** — 144 flat and
   20 up is 145.38 studs, which a flat test would refuse and the 3-D rule allows.
6. **No two groups lie up inside one flush circle, and the design's claim about how is wrong.**
   Design 4.2 says the 71-stud gap *"is carried by the lateral offsets, and `Placement.plan` asserts
   it"*. MEASURED: it is not — at `normal` slots 4 and 6 are **55.9 studs** apart and at `busy` slots
   5 and 8 are **67.3**, both inside 71, so an `assert` would have failed every drive. So the bed is
   **placed**: `clearX` keeps the row's depth and sweeps the lateral offset outward from the written
   x, one stud at a time, inside `crossCapStuds`, to the first x that clears every bed laid.
   MEASURED closest pair: **71.60 / 71.42 / 71.30** studs at quiet / normal / busy against a gap of
   71 (the spec's own notes). `clearX` has four unit cases including the two refusals (no room inside
   the cap → `nil`; the 3-D case where 60 studs of depth buys back 33 studs of width).
7. **A group that cannot be bedded is skipped, counted and printed — never bedded on top of
   another.** A case drives `crossCapStuds = 1`, where 13 beds 25 studs apart cannot hold a 71-stud
   gap: the roster still has 13 rows, `skipped > 0`, the number of `SKIPPED` console lines equals the
   skip count, and no skipped row is a walker or is ever due again.
   **MEASURED on the real data: `busy` skips 3 of 15 at the shipped muster of 580 and 0 of 15 at
   700.** That is the design's own tolerated failure mode (`nobed` skips "tolerated and counted"),
   and it is in `ESCALATE.md` 2026-11-10 ~13:50 as the Director's decision, with the arithmetic.
8. **A skip is a skip, a body is not re-bedded, and the budget door is read at the instant.**
   `dueNow` is false for a row with `skipped` set however late it is (task 172's rule), false for a
   row that is not a `record`, and true exactly `leadSeconds` before the line reaches its bed.
   `roomFor` refuses on `bodies + size > cap` ("live") and on `bedded + size > bedCap` ("bedded")
   **independently**, and is never latched (L-029): a refusal followed by room answers room.
9. **The two wake triggers cannot reach each other's arm.** A walker has a finite `wakeAtSeconds`
   (`firstSlotSeconds + k × intervalSeconds`, the shallowest bed taking the first clock) and a group
   the line must find has `math.huge`, so one row of data decides which rule applies. Cases: a walker
   wakes on its clock and not 0.01 s earlier and needs no line at all; a non-walker is nil for ever
   with no line, nil one stud outside the notice band, `"beaters"` on the band's edge; a `record`
   never wakes. MEASURED: **2 walkers** at every density, and they are the two shallowest beds.
10. **The deer cap is spent once per drive, at plan time, by weight and not by name.** Two non-lone
    `reddeer` rows at `MAX_GROUPS_ALIVE` 1 give one deer group in the roster and exactly one printed
    refusal; adding a lone stag row admits him over the cap on the animal owner's own
    `LONE_PARTY_EXTRA_GROUPS`, and he is the last deer; making that third row a party of three
    (`harem`) has the same cap refuse it, with nothing else edited. The cap is built in the spec
    rather than read off `Boar.CONFIG`, because `ForestTestBoot` mutates that table at boot and a
    spec must not pass or fail by load order.

## Deviations from design 8.1, all stated, none a number

* **`Placement.plan` takes a `deps` table instead of `layout`**, and `bandFar` / `wakeReason` take
  the notice band as a **number**. The reason is rule 3: `noticeAheadStuds` is a derivation
  (`sqrt(reach² − (laneSpacing/2)²)`, floored) owned by `src/shared/ForestTest/init.luau`, and
  `slotAt`, `compositionSize` and `deerComposition` are their owners' functions. Re-implementing any
  of them inside a pure module would have been a second answer. That is this repo's own precedent, in
  the same file: *"it is a plain number, which is what makes 'how far apart is a lane' ONE answer"*
  (`bandDepth`'s header).
* **`RosterRow` gains `reachAtSeconds`** (when the line is expected to reach this bed), because
  `dueNow` needs it and `wakeAtSeconds` is the walker clock. **`Placement.tally`** is added because
  `line` and the caller's stats must not count twice.
* **`clearX` is new** (design 4.2 expected an `assert`; claim 6 says why it could not be one).
* **`bedOffsetX` is the row's RAW `offsetX`, not an `offsetX` biased by `routeBias`** — design 4.2
  says *"the row's `offsetX` biased by `routeBias`"*, and round 1's note is right that nothing
  applies that bias: `Data.cellSchedule` biases **`crossOffset` only**
  (`copy.crossOffset = ForestTest.crossBias(...)`), so a cell's `routeBias` moves where its animals
  BREAK OUT and not where they lie up. Listed here rather than changed, because the fix belongs to
  `cellSchedule` (not this task's file) and would move the live cell schedule every drive reads,
  which T1 must not do. Queued as TASKS.md **345a-notes (a)** for T2. The shipped comment on
  `RosterRow.bedOffsetX` now says "after the gap sweep", which is what the code does.

## Round 1's notes

Fixed in this round, because each was a one-line risk and this round was already open:
the vacuous dial case (claim 3, blocking); the **silent drop** of a boar row whose `composition`
indexes nothing, which now prints *"names no sounder composition"* like the deer path;
the `expect(row.wakeAtSeconds).to.equal(math.huge)` self-assertion of a literal the case itself
wrote, deleted; the mis-commented `bedNorth(2, 2, 150, 450)` case, which now drives the band the
wrong way round as its comment claims; and the research note's tempo row, which listed the refuted
3.1 studs/s figure its own section 5 corrects.

Queued in TASKS.md as **345a-notes**, not fixed here: the `routeBias` gap (above, (a)); one walker
instead of two when a shallowest bed is skipped (b); `tally.animals` counting skipped rows (c); and
`clearX`'s local `clears` vs `gapOk` being two spellings of one question (d). The `BOAR_MODEL`
dependency is now stated in the spec's header, as the note offered.

## Not verified

1. **No drive was run and nothing was measured in the running game**, because nothing in the running
   game reads this code. Every figure above is the spec's arithmetic at `9df17202`.
2. **No screenshot** (rule 5): there is no visible change. The flag is OFF and nothing reads it.
3. **Whether a bed at dz 450 is actually hidden from a stand** is T3's measurement (`inView == 0`,
   `rays > 0`); `clearOfEyes` is only the distance half, and the ray half is not in this task.
4. **The tempo.** Design 4.2's intervals are computed at 3.1 studs/s; the live
   `Bots.CONFIG.WALK_SPEED` is **5.64** (task 327d2), so the spec measures *"the line finds a group
   every 4.43 s"* at `normal` against the design's 8.1 s and the 13 s Karen accepted. The module is
   indifferent (`walkSpeed` is a parameter); the decision is in `ESCALATE.md`.
5. **`Boar.deerComposition`'s `CHANCE_PER_RELEASE`** can grow a deer party, so 53 / 73 / 83 are
   nominal — which is what `plan` computes and what the spec asserts.

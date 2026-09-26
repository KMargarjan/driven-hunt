# Task 58 — M2.8a: the forest road, the corridor and the autumn palette

Task: 58
Round: 1
Base: `c46c699` (`main`, with Task 54's revised design merged)
Code commit: `32538b0cd6189b7a0e2f39768f783ae20573ec6e` — **both** harness lines below name it. It is
a PAPERWORK commit: the last commit that changed `src/`, `tests/` or `tools/` is `4bdf434`, and
`git diff --name-only 4bdf434..32538b0` is `TASKS.md` and this file. Naming the later commit is what
CLAUDE.md git workflow step 4 allows and prefers, and it only narrows what the evidence covers.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ 32538b0cd6189b7a0e2f39768f783ae20573ec6e (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: 32/32 checks @ 32538b0cd6189b7a0e2f39768f783ae20573ec6e (clean tree)

330 server specs (327 before: **3 new**), 84 shooter and 78 driver client specs; the two-player run
took 120 s and ended its session automatically. **The map is CLEARED from the place**: `cells: 0`, no
`DrivenHuntMap`, and the palette read back at
`LeafyGrass=106,134,64 Grass=111,126,62 Ground=140,130,104 Mud=121,112,98` — the measured default.
The Director confirms the same: one Studio, Edit mode, no map in the place.

## Scope

Design §18's **M2.8a row only** — the road and the corridor. **No new props**: the wood, its species
and the density inside the drive are M2.8b, which is why the corridor is still bare in the shots.

## The measurements (design §16.6)

**N1 — the palette. Every part of it is a yes, so the §8.3 fallback is NOT taken and no code for it
exists.** `Terrain:SetMaterialColor` / `GetMaterialColor` are callable through `execute_luau` in Edit;
the values read back exactly; **they survive `Terrain:Clear()`** — which is precisely why `clear` has
to restore them; and **they replicate to a client**, so `map_client.spec`'s colour check stands rather
than being dropped. `Map.PALETTE_DEFAULT` is the **measured** default of a place nobody has
recoloured (the design said *"Do not guess it"*): litter `106,134,64`, rough `111,126,62`, road
`140,130,104`, bog `121,112,98`.

**N4 — the worst corridor slope over three seeds** at `BENCH_RELIEF = 6`, verge 24: **11.60 / 12.36 /
10.31 degrees** against the 15° ceiling. The verge itself is **7.45°**; the worst point is at a spawn
pad, not at the road. The road is flat to **0.0000 studs** over 89 samples. No fallback needed.

**And N4 found a defect.** The road is painted x ∈ [−900, 900] while the map runs to ±1024, and with
the end distance in the edge-floor suppression the last 124 studs of the ride rose to **34.8 studs** —
exactly the *"ridge across the end of the ride"* §6.2 says the suppression exists to avoid, and
exactly what `map-edge` asks about. The suppression is `across` only now: **0.000 studs** where the
road leaves the map, while the rim still rises to 44.

## Claims

1. **Everything the game stands a player or a boar on is at exactly `GROUND_Y`.** The road bench, the
   assembly bench and the four spawn pads. A new spec walks both bench centrelines at 10-stud steps
   and fails on any offset over 1e-6; N4 measured 0.0000 over 89 samples. This is what lets
   `Boar.CONFIG.field.groundY` stay unchanged at the M2.5 switch. Verify: `Height.benchHeight`;
   "keeps the road and the assembly track flat".

2. **The easing cannot hide a bug.** A second spec asserts that one stud outside the verge the
   flattened height **equals the raw height**, over 31 samples. Without it, a `benchHeight` that
   flattened the whole map would pass every other check here — the road would be flat, the pads would
   be flat, and the slope would be zero. Verify: "leaves the ground unflattened a verge away".

3. **The rim rises and the road's band does not.** A third spec asserts the ground at the rim on the
   road's centreline is within 0.5 studs of `GROUND_Y`, that away from the road the rim is over
   `GROUND_Y + 20`, and that it never exceeds `BAND_Y.max` — so the edge floor is doing something,
   and the tile size measurement A proved is unchanged. Verify: "raises the map's rim but leaves the
   road's band flat".

4. **The palette is written, read back, and restored.** `Ground.applyPalette` / `readPalette` /
   `resetPalette` — the module that is already the only writer of `Terrain` takes the palette too, so
   there is no second writer. The palette **step** runs second, before a voxel is written, and
   **reads every colour back**; `clear` restores the default and returns `paletteRestored`, measured
   rather than claimed. Verified live: the clear above put all four back exactly.

5. **A hand-edited colour changes the digest.** `Digest.paletteText` joins the canonical text, so a
   recolour cannot silently become the map while the voxels and markers hash identically. Verify:
   `Digest.of`, `Digest.paletteText`; `MapGen.digest` passes `Ground.readPalette()`.

6. **The corridor, the road and the posts are the design's numbers.** Corridor x ± 620, z ∈
   [−880, 800]; `exitZ = −820`, 120 studs past the road; `postSpacing = 160` (45 m, inside Karen's
   40–80); drive line `1240 × 1 × 1`; driver start `1120 × 1 × 20`. **The contract spec caught this
   change on the first harness run** — it still pinned x ± 340 — which is the assertion doing its job;
   it now pins the new numbers with the reason beside them.

7. **Three long-open defects are closed by construction.** The post marker is `6 × 1 × 6` at
   `GROUND_Y + 0.5`, so `Body.placementFor` stands a character at ground + 4.5 instead of dropping
   9.5 studs onto a non-colliding part (row 43a(l), audit-004 F9). `Layout.pads` returns the **four
   boar spawns only**, so the merged post-pad strip (row 45a(d)) cannot exist. `MapGen.VERSION` is
   `Map.GENERATOR` — one home (row 44a(f)). `verifyContract`'s early return now fills every field its
   own annotation makes mandatory (row 45a(c)).

8. **Reachability paths five froms to five targets, not to one midpoint.** 25 `ComputeAsync` calls,
   every one reported, one failure fails the check. Run live: **25/25 Success**, 340–415 waypoints.
   Closes row 44a(e): pathing only to the line's centre proved one corridor down the middle of the
   map and said nothing about a boar pushed toward x = +500. Verify: `MapGen.reachability`; and
   `python tools/mapgen.py reach`.

9. **A step can be inserted without silently moving three others.** Three handlers derived their
   tile / hedge-line / track index by subtracting a hard-coded count of preceding steps; adding the
   palette step at position 2 would have shifted all three, and a terrain tile written into the wrong
   region is a defect no spec here would catch. The ordinal is derived from the plan now. Verify:
   `ordinal()` in `MapGen.runStep` and its three call sites.

10. **The build is real and deterministic in shape.** 267 steps, **1,086 parts**, 4,096 terrain
    samples, 3,383,582 terrain cells, `contract OK`, `reachability OK`, digest
    `392f7f48…467deae5` at seed 1. Then cleared, and the place verified empty.

## What the shots actually show (rule 5 — I looked at all eight)

**And the first set found a defect the numbers did not.** `Config.MATERIAL.field` was `Grass` and
`.rough` was `LeafyGrass`, so the autumn palette painted the **whole forest floor olive** and put the
orange leaf litter on the **steep rim**. The map generated correctly, digested correctly, reached
correctly — and read as a dry summer meadow. `map-wide` and `map-autumn` showed it at once. The roles
are named for what `Map.PALETTE` calls them now, and the default return is `litter`.

After the fix, honestly:

- **`map-road`** — the shot this revision exists for. The road **is** there and **is** gravel: a pale
  strip running dead straight and flat to the horizon. ✔
- **`map-autumn`** — the floor is **orange-brown leaf litter** with a fine speckle. ✔ The trees are
  still green cube crowns on thin trunks: **it does not yet read as an autumn forest**, and it cannot,
  because M2.8a places no new props.
- **`map-wide`** — autumn interior, **olive-green farmland flanks**, both benches visible as pale
  lines, the hedge lines visible. It reads as wood-floor-with-fields. The **corridor is bare of
  trees**, which is M2.8b.
- **`map-edge`** — **no void**: the road runs out flat and the rim closes the horizon with ground and
  trees. This is the N4 fix, visible.
- **`map-post` / `map-drive` / `map-crossing` / `map-stand`** — open ground with scattered proxy
  trees at the flanks; the tie trees read as a row of lollipops. All four are M2.8b's to answer.

## What I could not verify

- **`map-road` cannot answer its own question.** It asks whether the posts read at 160-stud spacing —
  but every marker is `Transparency = 1` by design (§4.3), so **the posts are invisible in every
  shot**. Nothing is visibly wrong; the shot simply cannot show it until M2.8c puts stakes beside each
  post. Queued as row 58a.
- **Whether it reads as an autumn European forest: the floor does, the trees do not**, and that is
  M2.8b. I am not claiming M2.8a delivers the look.
- **Two players says nothing about the map itself**, and I am not claiming otherwise: the map is not
  the world yet, so `test2`'s value here is that the 330/84/78 suites still pass with the new contract
  numbers and the palette in the digest — not that anybody walked the road.
- **The map is not the world.** `Map.EXPECTED_WORLD` is still `"arena"`; nothing here changes what a
  player stands in, and the switch is M2.8e.
- **Measurement B is still open** (tags and terrain surviving a save and reopen) — it needs clicks no
  tool here can make. N2, N3 and N5 belong to M2.8b/M2.8c and are not attempted.

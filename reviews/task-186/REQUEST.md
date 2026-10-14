# Task 186 — review request: the tyres were inside the earth, and the trucks were white

Task: 186
Round: 1
Base: `68dc88f` (`main`, #169 merged)
Code commit: `a771099ac30927e541bbbf75e926c6af2dbb1f8a`

Branch `task-186-camo-trucks`. Note `docs/research/2026-10-14-trucks-on-the-ground.md`. No design
run and no Architect run: this changes no owner and adds no system — `Lobby.Build` is still *"the
one writer of every part in `Workspace.Lobby`"*, and what it gained is the rule `Build.pad` already
applies to a pad deck, applied to a truck.

Karen, 2026-10-14 ~17:00: *"car tyers are inside earth / trucks has to be comoflash"*; ~21:15:
*"make cars comoflash like military like hunting cars"*.

## The harness

```
[harness] PASS: 33/33 checks @ a771099ac30927e541bbbf75e926c6af2dbb1f8a (clean tree) scope=all
```

Run **twice**, both PASS, both at the code commit on a clean tree (1468 server assertions, 343
client, 55 server specs, 19 client specs, both runs).

**`test2` is N/A.** Not one file this task touches is in `TWO_PLAYER_PATHS`: the files are
`src/server/Lobby/Build.luau`, `src/server/Lobby/init.luau`, `src/shared/Lobby/init.luau`,
`src/server/ForestTestBoot.server.luau` and `tests/server/lobby.spec.luau`. A second player renders a
second copy of a parked truck and answers nothing the first did not.

## What changed

**One: the wheels.** `Build.trucks` stood each truck's bounding box on `anchor.Y` — the *nominal*
shelf. Measured live in the Forest Test, one ray under each of the sixteen wheels, **before** a line
was written: every tyre of all four trucks **0.752 studs UNDER the terrain**, and the east bay's
worst wheel **2.017 under**, with a **1.266-stud spread across that one truck's own four wheels**.
Roblox terrain is voxelised: `Field.fill` asks for a block whose top is `shelfY` and the engine
rounds the surface it produces to its own grid (150.000 against a shelf at 149.248). That is task
182's pad defect against the same surface; the trucks were the half of it nobody fixed.

So `settleOnGround` measures the ground under each **wheel** through the world's own `groundAt`,
fits a least-squares plane through the four contacts (`Build.groundFit`), tilts onto it with
`Build.tiltFrom` (clamped 0.25°–6°) and lifts by the **worst** contact — measured twice, because the
tilt moves the wheels and the ground under them is a new question afterwards.

**Two: the camouflage.** `camo` repaints the panels the free model ships untextured, plus the rims
and tyres, in one of four olive palettes per bay. Windows and lamps untouched. No upload.

## Claims

1. **The defect was real and is measured, not asserted.** `docs/research/2026-10-14-trucks-on-the-ground.md`
   §2 holds the sixteen before-numbers and §6 the after-numbers, both taken with the same probe in
   the live place. *Verify:* read §2 and §6; the "after" numbers are reproduced by the console line
   in claim 7.
2. **No wheel can end under its ground, under any reader.** `settleOnGround` takes `lift` as the
   **max** over contacts of `ground - bottom`, so the worst contact is the one that decides.
   *Verify:* `tests/server/lobby.spec.luau` → *"never sinks a truck, even where the ground is steeper
   than it may tilt"* drives a 26° slope (four times the clamp), so the tilt is **refused**, and
   still asserts every wheel at or above its ground.
3. **On ground that is a plane, every wheel lands on it.** *Verify:* the same file → *"settles every
   wheel onto the ground a world can measure"*: a 0.03/stud plane, all sixteen wheels within
   `[0, 0.2]` studs of it, and `Build.stats().truckGroundStuds <= 0.2`.
4. **A world that cannot measure the ground is the OLD behaviour, exactly.** `settleOnGround` returns
   `false, 0, 0` when `groundAt` is nil, when the `pcall` throws, or when any one contact answers a
   non-number — half a measurement is refused rather than used. *Verify:* *"leaves a truck exactly on
   the shelf when the world cannot measure the ground"* (a reader that `error`s), plus the untouched
   older case *"stands every free model ON the shelf, not in it and not over it"*, which still
   passes with no reader at all.
5. **A measurement can never bury a truck in a slab this system laid itself.** The sampled ground is
   `math.max(measured, floorY)` with `floorY = anchor.Y + cfg.ROAD.THICK_STUDS`, the top of the
   `Yard` slab `road` lays across all four bays — `pad`'s own bound, out of the same row. *Verify:*
   read `trucks`' `floorY` against `road`'s `Yard` part and `pad`'s `math.max`.
6. **The repaint touches the paint and nothing else.** `Build.truckSkinOf` answers glass → lamp →
   wheel → rim → paint → **keep**, in that order, and `keep` is the default. *Verify:* *"knows which
   part of a truck is paint, glass, a lamp or a wheel"* — `WindowFrame` carries both words and must
   answer `glass`, or a frame round a window gets painted olive; `Bumper`, `Grill1` and `Steering1`
   must answer `keep`. And *"paints every truck in the bay's own camouflage, and leaves the glass
   alone"* asserts every painted panel is one of **that bay's** tones, that more than one tone lands
   on one truck, and that the windscreen is still `Glass`.
7. **The live result is a number on the console, not a belief.** `[lobby] trucks: 4/4 settled on the
   measured ground, worst wheel +0.456 studs, 68 part(s) in camouflage` — printed by
   `ForestTestBoot.reportLobby`, read off two separate Play sessions today (the last one
   `driven-hunt-runs/smoke-console.txt`). *Verify:* read `reportLobby` and `Build.stats`.
8. **`truckGroundStuds` is measured off the parts, never computed from the lift.** It is
   `|(bottom + lift) - ground|` over the **second** sample, the one taken after the tilt. *Verify:*
   read the last loop of `settleOnGround`.
9. **The pads did not move.** `pads` still runs after `trucks`, from `Pads.centreFor`, with its own
   reader; nothing in this task writes a pad. The one spec that counted probes
   (*"sits each pad on the ground that is REALLY there"*) now takes the **last** `TRUCK.COUNT` of
   them and still asserts each is at its own pad's centre — the trucks probe first because
   `Build.build` parks them first. *Verify:* that case, and the screenshot in claim 10 (four pads,
   four colours, still behind their own trucks).
10. **Looked at, not inferred (rule 5).** `driven-hunt-runs/186-before-3.png` (white trucks, tyres
    cut off at the dirt) and `186-final.png` (olive, matte, full tyres with ground shadow, four pads
    behind them), same camera, same place, same lighting. `186-final-side.png` is truck 1 broadside
    in sunlight.

## What I could NOT verify

* **Truck 4 ends with one wheel 0.456 studs in the air, over the Director's 0.2 target**, and tuning
  will not close it: its four ground answers are 150.000 / 150.217 / 150.477 / 151.266 — not a
  plane, and no rigid body has four wheels on a surface that is not one. The guarantee that IS kept
  is Karen's (nothing inside the earth, from −2.017). Reaching 0.2 there means moving the east bay
  or cutting `Field.fill`'s air block below the shelf; both move something this task was not asked
  to move. Written up in the note §6 and queued for the Director.
* **Whether Karen likes the colour.** The tones were photographed rather than reasoned — a correct
  olive drab on `Fabric` came back as four BLACK trucks — but *which* olive is hers to say.
* **There is no camo PATTERN**, only a scheme of tones per panel. A library texture cannot be proved
  to load without an asset call, which `tools/studio_mcp.py` forbids in capitals after one cost a
  night's gate on 2026-10-02; blotches need an upload and Karen's OK.
* **The free-model branch of the settle is proved live, not in the gate.** The DEV place has no
  lobby (`Lobby.anchorFor` has no `map:v1` row), so every spec here drives the **parts** build
  (named `Wheel1..4`) or the spec's stand-in model (the footprint fallback). The live `Tire`
  MeshParts are covered by the measurement in claim 7 and the pictures in claim 10.

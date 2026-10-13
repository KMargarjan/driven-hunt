# Task 173 — the gathering shows the REAL boars, not boxes

Task: 173
Round: 1
Base: db6bfe2 (main; task 172 is NOT merged, by Karen's decision, and this does not build on it)
Code commit: 2c52e246833ee826a98a398fb0a8f89687f00e92

```
[harness] PASS: 33/33 checks @ 2c52e246833ee826a98a398fb0a8f89687f00e92 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 2c52e246833ee826a98a398fb0a8f89687f00e92 (clean tree) scope=all
[harness2] <<< NEEDS TEST2 173 2c52e246833ee826a98a398fb0a8f89687f00e92 — the Director's click >>>
```

**`src/server/Match/` is a `TWO_PLAYER_PATH`,** so this review cannot start until the `[harness2]`
line for `2c52e24` is pasted over the placeholder above (`tools/agents.py` refuses it, by design).
The one-player line is there twice, full, clean-tree, `scope=all`, as the dispatch asked.

## What changed

KAREN, 2026-10-13 ~09:30, verbatim: *"and after hunt over we need to see boars shooted not boxes when
we stand around"*.

The results scene's grey boxes become the REAL animal of each shot animal's kind, lying dead on its
side. It is the one injected template function `TASKS.md` row 159a(a) said the next step would be;
the torches, the ring, the rows, the spacing and the cap of twelve are untouched.

* `Match.Scene.build` takes a fifth argument, `displayFor(kind, groundCFrame) -> Instance?`, and asks
  it once per animal it lays out. A model comes back and is parented into `Workspace.DriveScene` as
  it is; nil means that animal is the grey box of task 159. Per animal.
* `Boar.Body.displayCarcass` builds the display from the same per-kind template a live boar is
  dressed from. `Runtime:displayCarcass` is the one route from a kind to a template.
* `Match.displayAnimal` is the wire between the two owners; `ForestTest.readOnlyBoars` gets a
  passthrough (it writes nothing).
* `Boar.lyingHalfHeight` / `Boar.lyingCFrame` are the pure pose arithmetic. `DISPLAY_ROLL_DEG` is
  **-90** — the right side down, which is the tradition's own rule (the note quotes it).
* `Scene.stats()` counts `models` and `boxes`; `Match` prints both per drive.

Note: `docs/research/2026-10-13-real-animals-at-the-gathering.md` (new, in `INDEX.md`).
No design run: this is an existing system behind an existing seam, and no new owner appears.

## Claims, and how to verify each

1. **One display per shot animal, with its kind, where the row put it.** `Scene.build` asks
   `displayFor` once per laid-out animal with that kill's `kind` and `row[index]`, and names what
   comes back `Animal<i>` with `Kind` and `Model` attributes. `tests/server/match_scene.spec.luau`,
   "lays one real animal per shot animal, with its kind, where the row put it" — the asks are
   recorded and compared against `Scene.rowLayout`'s own output.
2. **It is LYING, measured the way task 150 measures a carcass.** `Body.displayCarcass` rolls the
   mesh by `MODEL.DISPLAY_ROLL_DEG`. `tests/server/boar_model.spec.luau`, "rolls the real model onto
   its RIGHT side, on the ground, facing the way it was told": the angle off world up is measured on
   the mesh **and on the rig's own `Bone`**, and must land in 86-104 degrees — task 150's own
   measured band. Live evidence from the Forest Test: `meshUp=90.0 boneUp=90.0` on every animal.
3. **On its RIGHT side, and all of them the same way round.** Same case: the mesh's up vector dotted
   with the row frame's `RightVector` is > 0.99, and its `LookVector` equals the row's. The row's own
   one facing is `match_scene.spec`, "faces every animal in the row the same way".
4. **On the ground, for every kind, with no per-kind number written down.** `Body.lyingHalfHeight` is
   half the rolled mesh's vertical extent, read off the mesh. `boar_model.spec`, "draws each kind
   from its OWN asset, at its own size" and "works out the lying height as arithmetic, for any angle
   and any asset" — the three measured asset sizes against 0.70 / 0.60 / 0.31 studs, written out in
   the spec as independent literals.
5. **The box is still the fallback, per animal.** `Scene.build`'s `if display ~= nil` branch;
   `Runtime:displayCarcass` answers nil with no model source, with a template that is not one mesh,
   and with no mesh at all. `match_scene.spec`, "keeps the grey box for an animal it cannot draw, one
   animal at a time" (a mixed row, and the no-source row) plus `boar_model.spec`, "answers nil for
   every world that cannot draw one".
6. **A display cannot be shot, shoved or animated.** Every `BasePart` is `Anchored`, `CanQuery`,
   `CanCollide` and `CanTouch` false and massless, and the asset's own `AnimationController` is
   destroyed. `boar_model.spec`, "cannot be shot, shoved or stepped: it is scenery".
7. **No carcass is taken, moved or kept.** `applyScene` reads `driveKills` only, and
   `Phase.enterScoring` still emits `clearBoars` before `scene`. Read `Match.displayAnimal` and
   `Runtime:displayCarcass`: nothing is registered with the runtime, nothing existing is read, and
   the model comes back unparented. `ForestTest.readOnlyBoars` still exposes no `spawn` and no
   `clear`.
8. **It is taken down with the scene.** `Scene.clear` destroys the folder, displays included.
   `match_scene.spec`, "takes the real animals down with the scene, and rebuilds rather than adds".
9. **Nothing else about the scene moved.** No number in `Match.CONFIG.SCENE` changed; the four
   torches, the ring radius, the rows and `MAX_ANIMALS` are byte-for-byte task 168's. Every case in
   `match_scene.spec` written before this task passes unchanged (the no-`displayFor` path is exactly
   today's). `git diff db6bfe2..2c52e24 -- src/server/Match/init.luau` shows only the wire, the two
   stats and the console line.
10. **It was looked at (rule 5).** `driven-hunt-runs/173-gathering.png`, taken in the Forest Test
    with Karen's settings: a sow and a cub lying on their sides in the row, the same way round, four
    torches burning, three bot beaters standing round. Console: `[match] gathered 2 animal(s) in 1
    row(s): 2 real model(s), 0 box(es)`.

## What I could not verify

* **`test2`.** `src/server/Match/` is a `TWO_PLAYER_PATH` and the second player needs a human click.
  Nothing in this task is about who the other player is — the scene is built from one drive's kill
  record and the ring already took the roster's count — but the path rule is the path rule, and the
  line above is a placeholder until the Director runs it.
* **The animals rest on the gathering spot's own plane, not on the terrain under each one.** Measured
  in the forest: 0.51, 0.88 and 1.28 studs above the terrain directly below them, on a slope. That is
  task 159's behaviour (the boxes did the same, from the same single `spot.Y`), it does not read as
  floating in the screenshot, and it is queued as 173a(c) rather than changed here.
* **The results panel sits in front of the bag** from where the scene puts the player. Seen in a
  capture during the run; queued as 173a(b). Karen's call, not a defect.
* **How a clip-posed display would look.** The pose is a roll, deliberately (note section 4.2); the
  comparison with a death-clip pose has not been built, so "straight legs rather than settled" is a
  statement about what the screenshot shows, not a measurement against an alternative.

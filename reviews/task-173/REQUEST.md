# Task 173 — the gathering shows the REAL boars, not boxes

Task: 173
Round: 2
Base: db6bfe2 (main; task 172 is NOT merged, by Karen's decision, and this does not build on it)
Code commit: d69555a2701a1a9717f97d0c96113c521651fe84

```
[harness] PASS: 33/33 checks @ 4a93fb7680dd9205913db3296ae8136df87b7ea1 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 4a93fb7680dd9205913db3296ae8136df87b7ea1 (clean tree) scope=all
[harness] PASS: 33/33 checks @ d69555a2701a1a9717f97d0c96113c521651fe84 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ d69555a2701a1a9717f97d0c96113c521651fe84 (clean tree)
```

Both one-player lines are the FULL run on a clean tree, DEV alone (the Forest Test Studio was
closed). `src/server/Match/` is a `TWO_PLAYER_PATH`, so the `[harness2]` line for **this** code
commit replaces the placeholder before the round can start; `tools/agents.py` refuses it until then,
by design.

## What changed

KAREN, 2026-10-13 ~09:30, verbatim: *"and after hunt over we need to see boars shooted not boxes when
we stand around"*.

The results scene's grey boxes become the REAL animal of each shot animal's kind, lying dead on its
side. It is the injected template function `TASKS.md` row 159a(a) named; the torches, the ring, the
rows, the spacing and the cap of twelve are untouched, and no `SCENE` number moved.

* `Match.Scene.build` takes a fifth argument, `displayFor(kind, groundCFrame) -> Instance?`, and asks
  it once per animal it lays out. A model comes back and is parented as it is; nil means that animal
  is the grey box of task 159. Per animal.
* `Boar.Body.displayCarcass` builds it from the same per-kind template a live boar is dressed from,
  rolled `MODEL.DISPLAY_ROLL_DEG` = **-90** onto its RIGHT side (the tradition's rule, quoted in the
  note) and lifted by half the rolled mesh's own vertical extent.
* `Match.displayAnimal` is the one wire; `ForestTest.readOnlyBoars` gets a passthrough that creates
  no boar and moves none.
* `Scene.stats()` reports `models` and `boxes` **for the scene it just built**; `Match` sums them
  into its own session totals and prints the per-drive pair.

**Round 2 fixed finding 1 and all six notes** (details in the commit message of `4a93fb7`): the
breakdown is per build, `Match.displayAnimal` moved out of `applyScene`'s header comment, the fake
spine bone is tilted so the bone measurement is its own, `Runtime:displayCarcass` asks
`MODEL.ENABLED`, the Forest Test comment no longer says "writes nothing", a template's extra parts
travel with the mesh, and `DISPLAY_NAME` is asserted. Nothing was queued.

Note: `docs/research/2026-10-13-real-animals-at-the-gathering.md` (new, in `INDEX.md`).
No design run: an existing system behind an existing seam, and no new owner appears.

## Claims, and how to verify each

1. **The breakdown is this scene's, and the owner's sentence adds up** (round 1, finding 1).
   `Scene.build` assigns `models` and `boxes` where it assigns `rowsBuilt`; `applyScene` prints them
   beside `laid` and adds them into `stats` with `+=`. `tests/server/match_scene.spec.luau`, "counts
   the models and the boxes of THIS scene, not of every scene since the server started" — four builds
   in a row (2 models; 1 model + 1 box; a build that can draw nothing; an empty drive), with
   `models + boxes == laid` each time. **The second block fails on the round-1 code** (it reported 3).
   `built` and `cleared` are still session counters and the case says so.
2. **One display per shot animal, with its kind, where the row put it.** Same spec, "lays one real
   animal per shot animal, with its kind, where the row put it": one ask per laid-out animal, the
   kill's own `kind`, the CFrame compared against `Scene.rowLayout`'s own output, and `Kind` plus
   `Model` attributes on each child.
3. **It is LYING, and the band is measured on the rig's own bone.** `tests/server/boar_model.spec.luau`,
   "rolls the real model onto its RIGHT side, on the ground, facing the way it was told": the mesh
   and the `Bone` are each measured against world up and must land in 86-104 degrees — task 150's own
   measured band. The fake bone is tilted `BONE_TILT_DEG` = -8 against the mesh, so the two are
   different numbers and the spec asserts the gap as well as the band. Harness note, both runs:
   `display mesh 90.0 deg off up, bone 98.0 deg, bottom 0.0000 of the ground`.
4. **On its RIGHT side, and all of them the same way round.** Same case: the mesh's up vector dotted
   with the row frame's `RightVector` > 0.99 and its `LookVector` equal to the row's; the row's single
   facing is `match_scene.spec`, "faces every animal in the row the same way".
5. **On the ground, for every kind, with no per-kind number in the code.** `Body.lyingHalfHeight`
   reads the half-extent off the mesh. `boar_model.spec`, "draws each kind from its OWN asset, at its
   own size" and "works out the lying height as arithmetic, for any angle and any asset" — the three
   measured asset sizes against 0.70 / 0.60 / 0.31 studs, written in the spec as independent literals.
6. **The box is the fallback, per animal, and `BOAR_MODEL` off is one of its cases.**
   `Runtime:displayCarcass` returns nil with the flag off, with no model source, with a template that
   is not one mesh and with no mesh at all; `Scene.build`'s `if display ~= nil` does the rest.
   `boar_model.spec`, "answers nil for every world that cannot draw one" (four cases) and
   `match_scene.spec`, "keeps the grey box for an animal it cannot draw, one animal at a time".
7. **A display cannot be shot, shoved or animated, and nothing it carries is left behind.** Every
   `BasePart` is anchored, massless and `CanQuery`/`CanCollide`/`CanTouch` false; the asset's own
   `AnimationController` is destroyed; every part that is not the mesh keeps its offset to the mesh
   (round 1, note). `boar_model.spec`, "cannot be shot, shoved or stepped: it is scenery".
8. **No carcass is taken, moved or kept.** `applyScene` reads `driveKills` only;
   `Phase.enterScoring` still emits `clearBoars` before `scene`; `Runtime:displayCarcass` registers
   nothing and returns an unparented model; `ForestTest.readOnlyBoars` still exposes no `spawn` and no
   `clear`. Read those four.
9. **It is taken down with the scene, and nothing else about the scene moved.** `Scene.clear`
   destroys the folder, displays included (`match_scene.spec`, "takes the real animals down with the
   scene, and rebuilds rather than adds"). Every case written before this task still passes with the
   no-`displayFor` path, which is byte-for-byte today's.
10. **It was looked at (rule 5).** `driven-hunt-runs/173-gathering.png`, taken in the Forest Test with
    Karen's settings in round 1: a sow and a cub lying on their sides in the row, the same way round,
    four torches burning, three bot beaters standing round. Console: `[match] gathered 2 animal(s) in
    1 row(s): 2 real model(s), 0 box(es)`. **Round 2's code was not re-photographed** — the Forest
    Test Studio was closed for the gate, and nothing in round 2 changes what is drawn (see below).

## What I could not verify

* **`test2`.** `src/server/Match/` is a `TWO_PLAYER_PATH` and the second player needs a human click.
  Nothing here is about who the other player is, but the path rule is the path rule.
* **Round 2 in the world.** The six fixes are a counter reset, a moved comment, a flag check, two
  comment corrections, a spec fixture and an offset loop for parts no shipped asset carries — none of
  them changes a pixel of the screenshot above, and the gate ran twice over all of it. But it was not
  re-played in the Forest Test, so that is an argument, not a photograph.
* **The animals rest on the gathering spot's own plane, not on the terrain under each one.** Measured
  in the forest: 0.51, 0.88 and 1.28 studs above the terrain directly below them, on a slope. Task
  159's behaviour (the boxes did the same, from the same single `spot.Y`); queued as 173a(c).
* **The results panel sits in front of the bag** from where the scene puts the player. Seen in a
  capture during the round-1 run; queued as 173a(b). Karen's call, not a defect.
* **How a clip-posed display would look.** The pose is a roll, deliberately (note section 4.2); no
  comparison against a death-clip pose has been built.

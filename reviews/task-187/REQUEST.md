# Task 187 — a Central-European hunting lodge, built by us

Task: 187
Round: 4
Base: f28fcd9 (main, #170 merged — task 186)
Code commit: `35afd5779abb6797cb6f3cad252f07e744a90d15`

Harness, FULL run, TWICE, clean tree:

```
[harness] PASS: 33/33 checks @ 618d22f51b66b2688f7de5c66303091572771405 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 35afd5779abb6797cb6f3cad252f07e744a90d15 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 35afd5779abb6797cb6f3cad252f07e744a90d15 (clean tree)
[harness] PASS: 33/33 checks @ 618d22f51b66b2688f7de5c66303091572771405 (clean tree) scope=all
```

(`.agent-logs/task187-r3-test1.log`, `.agent-logs/task187-r3-test2.log`.)

`[harness2]` is **N/A**: no file this branch touches is in `TWO_PLAYER_PATHS` — `src/server/Lobby/`,
`src/shared/Lobby/`, `tests/server/lobby.spec.luau` and docs only.


DIRECTOR NOTE (round 4): Karen authorised using this lodge on 2026-10-15 ~17:40 ("Use the 187 lodge"); round 3's finding (the door antlers through the roof) was fixed in `681001e`; the Director merged `main` (tasks 188-192) into the branch at `35afd57` (doc conflicts only, both sides kept) and ran both gates there.

## What this round changed (round 2's two blocking items)

1. **One outward face per window, on all four walls.** `windowUnit`'s header claimed one outward
   normal and neither half of it was true. A CFrame's LookVector is its own −Z, so
   `R_y(t) · (0,0,−1) = (−sin t, 0, −cos t)`: **0 looks south, π north, π/2 west, −π/2 east**. The
   caller had south = π and north = 0 — inward — so on the front elevation the 1.7-stud sill sat
   **inside the room** and no shadow line existed on the wall Karen walks out of. And the shutter's
   hinge turned the opposite way from the rest of its own window: `R_y(t) · (a,0,0) = (a cos t, 0,
   −a sin t)`, so with `−side * OPEN` the leaf's own offset came back **+0.94 in local Z**, behind
   the face — on the east gable each leaf hung 0.64 studs inside the trophy wall. The four yaws now
   share the outward normal and the hinge sign is flipped, so **−Z is outdoors** for every offset in
   that function. *Verify:* the four-way `if` in `lodge`'s window loop against `trophies`' stated
   convention (which is the same rule read inward), and `hinge` in `windowUnit`. Photographed from
   the porch: frame, sill and shutters all stand proud of the logs on the front elevation.

2. **The opening case can no longer leak a lobby into `Workspace`.** `expect(lowest).to.be.ok()` and
   `expect(fills).to.be.ok()` both threw before the `Destroy` — and `lowest == nil` is exactly the
   *"the wall was never cut at all"* failure the case exists to catch, so the first time it did its
   job it would have poisoned the run again (an enabled `SpawnLocation` at x 2850; three
   `zz_drive_boundary` cases respawned 3,000 studs away the last time). **Every** failure in it is a
   string now and nothing is asserted until the folder is gone. *Verify:* the `problem` variable and
   the two `error` calls after `other:Destroy()`.

Also from round 2's notes: the north window moves from −13 to −11 (at −13 the 0.7-stud remainder
between the opening and the wall's end was dropped as a sliver and the corner stub does not cross it
on even courses — a 0.2 × 1.8 slit); the two north trophies move with it; the doorway case samples
the **volume** instead of comparing centres; and the gable stag reads the snapped `doorTop` rather
than `DOOR.HEIGHT`.

## Claims (the whole task, final state)

1. **An opening is a whole number of log courses, and the frame is built to the hole.** `snapOpening`
   rounds each opening to the course grid once, in `lodge()`; the same two numbers cut the wall and
   size the frame (`windowUnit` and `doorway` take the hole's real height), with a `1e-4` fuzz
   because both sides are the same float arrived at two ways. *Verify:* `lobby.spec` *"really CUTS
   the door and every window out of the log wall, away from the origin too"* — it builds at Karen's
   own (2850, 100, −2950), walks a 0.15-stud line up the wall plane at each opening, and fails unless
   the open band **is** the part that fills it.

2. **Every window reads the same on all four walls, and its dressing is outside.** See above.

3. **There is no second lodge and no clone of one.** `Lobby.TEMPLATE` has two rows (`TRUCK`,
   `TREES`), `CONFIG.LODGE.MODEL` is gone, `Build.roomFor` has one branch. *Verify:* `lobby.spec`
   *"builds OUR lodge and the four trucks out of the templates"*, which asserts those config rows and
   not only the absence of `House`.

4. **Nothing stands in the doorway, and the walk from it to the counter is clear.** *Verify:*
   `lobby.spec` *"leaves the doorway a GAP"* (now a sampled volume, 5 × 9 × 3 points) and *"is
   WALKABLE from the doorway to the counter"*, which found a bench centred on the room.

5. **The room is a room:** 32.4 × 22.4 × 12.6 studs against the 14 × 10 asked for.

6. **The fire is present and so are the lanterns:** one `Fire` + `ParticleEmitter` + `PointLight` on
   the hearth part, a mantel and a hearth stone; 6 `PointLight`s in the lobby, each written once.

7. **Twelve trophy mounts, each measured and fitted.** Each is built into its own Folder, its true
   vertical span read off the parts (the Y extent of a rotated box) and the folder shifted if it does
   not fit. *Verify:* `lobby.spec` *"hangs every trophy INSIDE the room…"* — the vertical bound is the
   part's own extent, which is the axis `trophies` clamps; x and z are still centre tests, which is
   what round 2's note says and all that is claimed — and *"hangs nothing on a wall in front of a
   window or the shop counter"*.

8. **Nothing floats:** every part of the lodge is inside the envelope it may occupy and overlaps
   another part of it on all three axes (0.75 studs of slack). *Verify:* `lobby.spec` *"leaves no
   part of the lodge floating"*.

9. **The part count.** `MAX_PARTS` is 1200 → 1500 with its arithmetic rewritten to the two numbers
   measured live: lodge **418**, whole lobby **885**. The spec case bounds `count <= MAX_PARTS` only
   — the two live figures are a measurement in this request and in the research note, not a repo
   assertion (round 2's note; the claim is corrected rather than defended).

10. **"Person inside broken" is fixed, without touching the outfit owner.** `src/server/Match/` is
    untouched; `Build.shopkeeper` writes `HeadColor3` on every `BodyColors` (creating one if the rig
    arrived without any, which is `Body.paint`'s own rule), colours the head and adds a Decal with
    `rbxasset://textures/face.png`. *Verify:* `lobby.spec` *"has a face, and a head that is not solid
    black"*.

11. **The lobby still works end to end.** Forest Test smoke PASS at this commit:
    `lobby=[lobby gunBefore=false] gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 | waves=6`.

## What I could not verify

* **Whether Karen likes it.** This is a look task and the eye that matters is hers. Nine screenshots
  were taken and inspected over three rounds; each one changed the build.
* **The two-player run.** Not run: no path this branch touches is in `TWO_PLAYER_PATHS`.
* **A flake, reported and not absorbed:** at the round 2 commit a run failed twice in
  `weapon_client.spec` (ammo reserve 12 vs 14, 2 vs 0) and passed on either side of it. Nothing here
  touches the weapon, the viewmodel or the input replay. Queued for the Director rather than claimed
  as this task's.
* **A harness flake worth the Director knowing:** with two Studios open, `list_roblox_studios`
  alternates between answering with only the DEV place and only the Forest Test, and the harness
  takes the first non-empty answer — three runs this round refused with *"Studio has the DEV place
  open (130094961655666 …)"* before attaching correctly. Both PASS lines above are from runs that
  attached to DEV and passed every check.
* **The three unused free models** are still parked in `Workspace.LobbyAssets`. Removing Studio
  content is Karen's click.
* **`docs/design/lobby.md` is not edited** — the Architect's file. The owner is unchanged; section
  9's "two builds, free model first" is now one build, which is a design delta for the Architect.

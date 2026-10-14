# Task 187 — a Central-European hunting lodge, built by us

Task: 187
Round: 2
Base: f28fcd9 (main, #170 merged — task 186)
Code commit: 028d9d852dee7ebd3869d936af00f3e9dbb30e87

Harness, FULL run, TWICE, clean tree:

```
[harness] PASS: 33/33 checks @ 028d9d852dee7ebd3869d936af00f3e9dbb30e87 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 028d9d852dee7ebd3869d936af00f3e9dbb30e87 (clean tree) scope=all
```

(`.agent-logs/task187-r2-test1.log`, `.agent-logs/task187-r2-test2.log`.)

`[harness2]` is **N/A**: not one file this branch touches is in `TWO_PLAYER_PATHS`
(`tools/agents.py`) — `src/server/Lobby/`, `src/shared/Lobby/`, `tests/server/lobby.spec.luau` and
docs only.

**Reported honestly:** a third run at this same commit failed TWICE in `weapon_client.spec` (ammo
reserve 12 against 14, and 2 against 0) and passed on either side of it. Nothing on this branch
touches the weapon, the viewmodel or the input replay; it is the replay's own flake. Both lines above
are from runs that passed every check.

## What changed

Karen, 2026-10-14 ~21:30, on the free Creator Store cabins: *"all of then garbadge"*, and so *"you
build then one proper europen standart"* — *"I need hunting house where will be fireplace table on
walls animal antlers ect like hunting cabin"*; and ~17:00, *"house is broken person inside broken"*.

There is **one lodge** now and it is ours, built from parts and Roblox materials. Task 180's clone of
"Log Cabin" and the two free trophy heads are gone (archived with their measurements in
`backups/2026-10-14_task-187_free-lodge.txt`, rule 7); the truck and the trees are still free models.
The road, fields, forest, trucks and pads are untouched.

Research note: `docs/research/2026-10-14-european-hunting-lodge.md`.

## Claims

1. **An opening is a whole number of log courses, and the frame is built to the hole and not to the
   config.** Round 1's blocking finding. `snapOpening` rounds each opening to the course grid once,
   in `lodge()`; the same two numbers cut the wall and size the frame (`windowUnit` and `doorway`
   take the hole's real height). The comparison in `logWall` carries a `1e-4` fuzz, because both
   sides are the same float arrived at two ways and the course under every sill was dropped by 4e-16.
   *Verify:* `lobby.spec` *"really CUTS the door and every window out of the log wall, away from the
   origin too"* — it now walks a 0.15-stud line up the wall plane at each opening and **fails unless
   the open band is the part that fills it** (the pane for a window; floor to lintel for the door).
   That measurement is what round 1's case was missing. It fails on round 1's code with
   *"the wall is open from 104.65 to 109.90 but WindowGlass1 covers 106.40 to 110.00"*, which is how
   the fuzz was found.

2. **There is no second lodge and no clone of one.** `Lobby.TEMPLATE` has two rows (`TRUCK`,
   `TREES`), `CONFIG.LODGE.MODEL` is gone and `Build.roomFor` has one branch and two arguments.
   *Verify:* `lobby.spec` *"builds OUR lodge and the four trucks out of the templates"*, which now
   asserts the **config rows** (`LODGE.MODEL`, `TEMPLATE.LODGE`, `TEMPLATE.DEER` all nil) as well as
   the absence of `House` — the round 1 note was right that the `House` line alone could not fail.

3. **Nothing stands in the doorway, and the walk from it to the counter is clear.** *Verify:*
   `lobby.spec` *"leaves the doorway a GAP"* and *"is WALKABLE from the doorway to the counter"* —
   the second walks 25 points and fails on any solid part within half a body's width of the line. It
   found a bench centred on the room; the table is west of the middle because of it.

4. **The room is a room**: 32.4 × 22.4 × 12.6 studs against the 14 × 10 the task asked for.
   *Verify:* same case, read off `Build.roomFor`.

5. **The fire is present and so are the lanterns**: one `Fire` + one `ParticleEmitter` + one
   `PointLight` on the hearth part, a mantel and a hearth stone, and 6 `PointLight`s in the lobby
   (fire + 3 inside + 2 on the porch), each written once at build. *Verify:* `lobby.spec` *"has a
   warm inside…"*.

6. **Twelve trophy mounts, every PART of them inside the room and under the ceiling**, and none in
   front of a window or the counter. Each mount is built into its own Folder, its true vertical span
   measured off the parts (the Y extent of a rotated box) and the folder shifted if it does not fit.
   *Verify:* `lobby.spec` *"hangs every trophy INSIDE the room…"* — which now bounds the part's own
   **extent** and not its centre, so the measure-and-shift is what is being tested (round 1 note) —
   and *"hangs nothing on a wall in front of a window or the shop counter"* (renamed: it never
   checked the fireplace, and the one west mount is deliberately ON the chimney breast).

7. **Nothing floats.** Every part of the lodge is inside the envelope it may occupy and **overlaps
   another part of it on all three axes** (0.75 studs of slack) — a box test, not the bounding
   spheres of round 1, which a 36-stud plinth passed against almost anything. *Verify:* `lobby.spec`
   *"leaves no part of the lodge floating"*.

8. **The part count is what the budget says**: lodge **418**, whole lobby **885**, counted live,
   against `MAX_PARTS` raised 1200 → 1500 with its arithmetic rewritten to those two measured
   numbers. *Verify:* `lobby.spec` *"stays inside the part budget"*.

9. **"Person inside broken" is fixed, the fix does not touch the outfit owner, and it has a case.**
   `src/server/Match/` is untouched. `Build.shopkeeper` writes `HeadColor3` on every `BodyColors` the
   character carries — **creating one if the rig arrived without any**, which is `Body.paint`'s own
   find-or-create rule — colours the head part and adds a Decal with `rbxasset://textures/face.png`,
   an engine asset. *Verify:* `lobby.spec` *"has a face, and a head that is not solid black"*;
   `git diff f28fcd9..028d9d8 -- src/server/Match/` is empty.

10. **The lobby still works end to end.** Forest Test smoke PASS at this commit:
    `lobby=[lobby gunBefore=false] gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 | waves=6`.
    The keeper's `ProximityPrompt` is present and `Enabled` (probed live); `Lobby.spawnCFrame`'s
    slots are bounded by the porch (`SPREAD_STUDS` 6 → 4.5, since the lodge's half-width went 20 → 18
    and 3 × 6 is 18).

## Round 1's other notes

Fixed in this round: the stale `Build.luau` header ("two builds"), the stale `CONFIG.PADS` wall
measurement (+21 → +18), the `MAX_PARTS` arithmetic (now the two counted numbers), the vacuous
`House` assertion (claim 2), the mis-named fireplace case (claim 6), the centre-only trophy bound
(claim 6), the bounding-sphere float test (claim 7), the missing keeper case (claim 9), the
`skull.Name = skull.Name` no-op, and the "fifteen rows" comment.

## What I could not verify

* **Whether Karen likes it.** This is a look task and the eye that matters is hers. Seven screenshots
  were taken and inspected, and each round changed the build: the porch roof (it was *inside* the
  main roof), the fire (a white blob), the antler colour, the shutter angle, the log colour, the
  brackets, the gable mount's size, and — found by the camera, not by arithmetic — the fact that the
  house had **no door and no windows at all**.
* **The two-player run.** Not run: no path this branch touches is in `TWO_PLAYER_PATHS`.
* **The three unused free models** are still parked in `Workspace.LobbyAssets` in the Forest Test
  place. Removing Studio content is Karen's click, not a Builder's.
* **`docs/design/lobby.md` is not edited** — it is the Architect's file. The owner is unchanged
  (`Lobby.Build` is still the one writer of every part in `Workspace.Lobby`); section 9's "two
  builds, free model first" is now one build, which is a design delta for the Architect.

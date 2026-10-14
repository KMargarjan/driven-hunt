# Task 187 — a Central-European hunting lodge, built by us

Task: 187
Round: 1
Base: f28fcd9 (main, #170 merged — task 186)
Code commit: b74fbc777b6f9f87d6898cd4da2a82a4940dad67

Harness, FULL run, TWICE, clean tree:

```
[harness] PASS: 33/33 checks @ b74fbc777b6f9f87d6898cd4da2a82a4940dad67 (clean tree) scope=all
[harness] PASS: 33/33 checks @ b74fbc777b6f9f87d6898cd4da2a82a4940dad67 (clean tree) scope=all
```

(`.agent-logs/task187-r1-test1.log`, `.agent-logs/task187-r1-test2.log`.)

`[harness2]` is **N/A**: not one file this branch touches is in `TWO_PLAYER_PATHS`
(`tools/agents.py`). The branch changes `src/server/Lobby/Build.luau`, `src/shared/Lobby/init.luau`,
`tests/server/lobby.spec.luau` and docs — no `src/server/Match/`, no `src/client/Match/`, no
`src/shared/Drive/`, no `match_*`/`zz_drive_boundary`/`zz_tie`/`outfit_client` spec.

## What changed

Karen, 2026-10-14 ~21:30, on the free Creator Store cabins: *"all of then garbadge"*, and so *"you
build then one proper europen standart"* — *"I need hunting house where will be fireplace table on
walls animal antlers ect like hunting cabin"*; and ~17:00, *"house is broken person inside broken"*.

There is **one lodge** now and it is ours, built from parts and Roblox materials. Task 180's clone of
"Log Cabin" and the two free trophy heads are gone (archived with their measurements in
`backups/2026-10-14_task-187_free-lodge.txt`, rule 7); the truck and the trees are still free models.
The road, fields, forest, trucks and pads are untouched.

Research note: `docs/research/2026-10-14-european-hunting-lodge.md` (three architecture sources plus
a measured trophy shield plus the Roblox fire pages; one negative fetch result recorded).

## Claims

1. **There is no second lodge and no clone of one.** `Lobby.TEMPLATE` has two rows left (`TRUCK`,
   `TREES`); nothing names a lodge or a head template, and `Build.roomFor` has one branch and two
   arguments. *Verify:* `grep -rn "TEMPLATE" src/shared/Lobby/init.luau src/server/Lobby/Build.luau`;
   `lobby.spec` cases *"builds OUR lodge and the four trucks out of the templates"* (asserts `House`
   is **never** found even with templates) and *"builds the SAME lodge when the template folder is
   not there at all"*.

2. **The door and every window are really cut out of the log wall — and the case proves it away from
   the origin.** An `Opening` carries its `along` **in world coordinates**, converted once in
   `lodge()` from the row's wall. *Verify:* `lobby.spec` *"really CUTS the door and every window out
   of the log wall, away from the origin too"*, which builds at **(2850, 100, −2950)** and asserts no
   `^Wall%u` part contains the middle of any opening, then that the sill, a shutter and the glass
   exist. **This case fails on the code as first written** (the whole suite anchors at x = 0, where
   lodge-relative and world studs are the same number, which is why nothing caught it; the
   photograph did). Live, in Karen's place: a ray from the porch through the doorway hits nothing.

3. **Nothing stands in the doorway, and the walk from it to the counter is clear.** *Verify:*
   `lobby.spec` *"leaves the doorway a GAP"* and *"is WALKABLE from the doorway to the counter"* —
   the second walks 25 points from a stud inside the door to the counter's face and fails on any
   solid part within half a body's width of the line. It found a bench centred on the room; the table
   is west of the middle because of it (`LODGE.TABLE.OFFSET`).

4. **The room is a room**: 32.4 × 22.4 × 12.6 studs against the 14 × 10 the task asked for.
   *Verify:* same case, first two assertions, read off `Build.roomFor`.

5. **The fire is present and so are the lanterns.** One `Fire` + one `ParticleEmitter` + one
   `PointLight` on the hearth part, a mantel and a hearth stone; 6 `PointLight`s in the whole lobby
   (fire + 3 inside + 2 on the porch), every one written once at build and never again. *Verify:*
   `lobby.spec` *"has a warm inside: a real fire, the lanterns, and the shop counter task 178 fills"*.

6. **Twelve trophy mounts, each inside the room and under the ceiling, and none of them in front of a
   window, the counter or the fireplace.** Each mount is built into its own Folder, its true vertical
   span is measured off the parts (the Y extent of a rotated box, which `Position.Y ± Size.Y / 2` is
   not for a cylinder) and the folder is shifted if it does not fit. *Verify:* `lobby.spec` *"hangs
   every trophy INSIDE the room…"* and *"hangs nothing on a wall in front of a window, the counter or
   the fireplace"*.

7. **Nothing floats.** Every part of the lodge is inside the envelope the lodge may occupy
   (footprint + roof overhang + chimney + porch + steps) and touches another part of it. *Verify:*
   `lobby.spec` *"leaves no part of the lodge floating: every one of them touches another"* — the
   keeper's body is excluded by `FindFirstAncestorOfClass("Model")`, because his limbs hang off his
   own joints.

8. **The part count is what the budget says.** Lodge 418, whole lobby 885 (measured live), against
   `MAX_PARTS` raised 1200 → **1500** with its arithmetic rewritten. *Verify:* `lobby.spec` *"stays
   inside the part budget"*; the live figures are in the report.

9. **"Person inside broken" is fixed and the fix does not touch the outfit owner.** `Match.Body` is
   unchanged. `Build.shopkeeper` writes `HeadColor3` on every `BodyColors` the character carries and
   adds a Decal with `rbxasset://textures/face.png` — an engine asset, no upload, no asset call.
   *Verify:* `git diff f28fcd9..b74fbc7 -- src/server/Match/` is empty; the keeper close-up screenshot;
   the probe quoted in the note (head was RGB 0,0,0).

10. **The lobby still works end to end.** Forest Test smoke PASS at this commit:
    `lobby=[lobby gunBefore=false] gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 | waves=6`.
    The shopkeeper's `ProximityPrompt` is present and `Enabled` (probed live), the counter is found by
    `Lobby.counterPart`'s name, and `Lobby.spawnCFrame`'s slots are now bounded by the **porch**
    (`SPREAD_STUDS` 6 → 4.5, because the lodge's half-width went from 20 to 18 and 3 × 6 is 18).

## What I could not verify

* **Whether Karen likes it.** This is a look task; the eye is the test and the eye that matters is
  hers. Five screenshots were taken and inspected (front from the road, three-quarter from the truck
  pads, inside toward the fireplace, inside toward the counter, and the keeper's face) and each round
  of them changed the build — the porch roof, the fire, the antler colour, the shutter angle, the log
  colour, the brackets and the gable mount's size are all answers to a photograph.
* **The two-player run.** Not run: no path this branch touches is in `TWO_PLAYER_PATHS`.
* **The free models are still parked in `Workspace.LobbyAssets`** in the Forest Test place and
  nothing reads three of them. Removing Studio content is Karen's click, not a Builder's.
* **`docs/design/lobby.md` is not edited** — it is the Architect's file. The owner is unchanged
  (`Lobby.Build` is still the one writer of every part in `Workspace.Lobby`); what changed is the
  geometry it writes. Section 9's "two builds, free model first" is now one build, and that is a
  design delta for the Architect rather than a Builder edit.

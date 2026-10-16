# Task 195 — the lodge inside: nothing hanging, a seller you can reach, a counter you cannot climb

Task: 195
Round: 1
Base: 0c4ddd2 (main, #175 merged — task 187)
Code commit: `748cf294b75c6a2c7f8e3ccd55079aaaa389b1c7`

Harness, clean tree, at the code commit:

```
[harness] PASS: 33/33 checks @ 748cf294b75c6a2c7f8e3ccd55079aaaa389b1c7 (clean tree) scope=auto:lobby,match
[harness] PASS: 33/33 checks @ 748cf294b75c6a2c7f8e3ccd55079aaaa389b1c7 (clean tree) scope=all
```

(`.agent-logs/task195-r1-test1b.log`, `.agent-logs/task195-r1-test1-full.log`. The Director's gate
rule for this task is the scoped run; the FULL run is here as well so the PR to `main` needs nothing
more. An earlier scoped run at `c276baa` FAILED one case and is at `.agent-logs/task195-r1-test1.log`
— see claim 10.)

`[harness2]` is **N/A**: no file this branch touches is in `TWO_PLAYER_PATHS` — `src/server/Lobby/`,
`src/shared/Lobby/`, `tests/server/lobby*.spec.luau`, docs, `backups/` and `TASKS.md` only.

Karen, 2026-10-15 ~17:40, verbatim: *"then you need to fix inside the cabin / it's broken there / you
need to make nice inside and person not hanging and all things not hanging clean perfect doors can
be open no doors, inside one bot as a seller access with e and you can't go over the table"*.

**Every defect below was measured in her own place before a line was changed** (220 interior part
boxes dumped live). Research note: `docs/research/2026-10-16-lodge-inside-clean.md`, section 2.

## Claims

1. **The door hanging in mid-air is gone, and it is deleted rather than corrected.** `DoorLeaf` was
   measured at z −2913.856 against an inner south wall of −2915.2 — **1.34 studs inside the room** —
   with its bottom 0.2 studs over the floorboards, and `CanCollide = false`, so players walked
   through it. The cause is one sign (`R_y(t)·(a,0,0) = (a cos t, 0, −a sin t)`: a positive
   half-width about the east jamb swings the free edge north). Corrected it stands at 100° across
   the porch; laid flat it covers a front window at either jamb — so Karen's *"doors can be open no
   doors"* is taken, the leaf and its two bands go, and the jambs, lintel and threshold frame a 7 × 9
   opening. *Verify:* `doorway` in `src/server/Lobby/Build.luau` and `CONFIG.LODGE.DOOR` in
   `src/shared/Lobby/init.luau` (no `LEAF_OPEN_RADIANS`); `lobby.spec` *"leaves the doorway open: no
   leaf, and no door part inside the room"*; archive `backups/2026-10-16_task-195_door-leaf.txt`
   with the rollback (rule 7), logged in `backups/README.md`.

2. **The seller's feet are on the floorboards, by the engine's own number.** `KEEPER.ROOT_HEIGHT = 3`
   put his `LeftFoot` at 151.860 on a floor whose top is 152.048. `Build.shopkeeper` now seats him at
   `floorY + Humanoid.HipHeight + rootHalfHeight` (HipHeight measured 2.192 — it is the distance from
   the root part's **bottom**), with `ROOT_HEIGHT` as the fallback for a body that has none. **A
   first attempt measured his lowest part instead and was wrong in a way worth recording:** seated
   that way he stood exactly on the boards at build and sank **0.174 studs** the moment the idle clip
   started, so the measured bottom is kept only as a guard that may **lift** and never lower.
   *Verify:* `shopkeeper` in `Build.luau` (`local lift = if man.HipHeight > 0 …`, and the
   `lowest < floorY` guard after the dressing); `lobby.spec` *"stands the seller's feet ON the
   floorboards, measured and not assumed"* — which **fails on the old code**, because `fakeRig` now
   has a real R15's proportions (root 3.188 over its soles, `HipHeight` 2.192).
   *Live, after:* `LeftFoot` 152.060 against a floor top of 152.048 **with the idle running**.

3. **The seller is out of the till, and the bound is his own radius and not his depth.** The live
   scan caught his `RightLowerArm` **1.182 studs** inside `Counter`; his measured horizontal radius
   about his root is **2.42 studs** and `Build.faceKeeper` turns him on the spot, so arms that are at
   his sides swing forward when he turns. `COUNTER_BACK` 4.6 → **6.4** (a 5.5-stud bay) and
   `BEHIND_STUDS` 1.6 → **3.5** stand him in the middle of it: 2.6 studs in front, 2.9 behind.
   *Verify:* `CONFIG.LODGE` in `src/shared/Lobby/init.luau`; `lobby.spec` *"gives the seller more
   room than he can reach, whichever way he is turned"*, which computes the radius off the body that
   was actually built.

4. **He reads as a man and not as a head on a shelf.** `COUNTER.Y` 3.2 → **2.8** (top 3.15): only 1.4
   studs of a 5.5-stud man cleared the old 3.55-stud top. *Verify:* the config row, and
   `<runs-dir>/t195/195-a-counter2.png` — head, hat, shoulders and arms over the till, inspected.

5. **You cannot get behind the counter.** A visible **`CounterWing`** closes the 3.2-stud gap to the
   east wall and a visible **`CounterReturn`** the west side to the north wall, both at counter
   height and in the counter's own timber; two invisible **clips** (`CounterGuard`,
   `CounterGuardWest`, `Transparency = 1`, `CanTouch = false`, `CastShadow = false`) run from the
   **solid** counter's top to the ceiling, flush with the two faces a body could cross. They start at
   the solid top and not at the cosmetic slab's, because nothing cosmetic in this lodge collides.
   *Verify:* the shop block in `Build.interior` and the `clip` helper in `Build.luau`;
   `lobby.spec` *"closes the service side: a body can neither walk in nor jump in"*, which samples
   both planes on a half-stud grid from the floorboards to the ceiling. *Live:* four scripted
   run-and-jump attempts — head-on at the till, at the east wing, east along the back wall, and over
   the return from the side — **all kept out, deepest 0.00 studs in**.

6. **`CanQuery = false` is IGNORED while `CanCollide` is true, and that moved the prompt.** Measured,
   four parts, one per combination, each shot at with a ray: collide+query HIT, **collide+noquery
   HIT**, nocollide+query HIT, nocollide+noquery passed through. So a no-climb barrier cannot be made
   ray-invisible, and a ray from a customer's head to the keeper's head came back *"blocked by
   CounterGuard"* at 1.5, 3 and 5 studs back from the till. The prompt therefore hangs on the
   **counter**, `PROMPT_OVER_STUDS` (1.2) above its top and `PROMPT_OUT_STUDS` (0.45) in front of its
   face — south of the clip — with the keeper behind it, `RequiresLineOfSight` still `true`,
   `MAX_DISTANCE` still the Director's 8 (now 8 studs of customer floor instead of 5.5), and built
   **only when a keeper was built**. `Lobby.shopPrompt` finds it by name, so no reader changed.
   *Verify:* `shopPrompt` in `Build.luau` and the call in `interior`; `lobby.spec` *"carries the
   prompt, with Karen's key, 8 studs and line of sight"*; `lobby_live.spec` *"stands a dressed
   shopkeeper at the counter…"*. *Live:* walk up, ask the camera to look at it, press the key →
   prompt drawn, `Triggered` fired, `ShopPanel` visible, **with the barrier in place**.

7. **Nothing in the room hangs, and that is now a measurement.** `lobby.spec` *"rests every part of
   the inside on the floor, a wall, the ceiling or another part"* walks all 253 interior parts and
   fails unless each one is within 0.05 studs of the floorboards, a wall plane, the ceiling, or
   another interior part. It found and this task fixed the shop sign (0.15 studs off the logs →
   flush, half its own thickness) and two gun-rack pegs (0.05 off their board → `-0.9` becomes
   `-0.8`). A companion case, *"lets no two pieces of furniture into each other"*, bounds the table,
   both benches, the counter group, the gun rack, the rug and the seller at 0.05 studs — and
   deliberately does **not** bound the chimney through the ceiling boards, the fire logs in the
   firebox or a lantern's rod into the planks, which were measured and are correct.
   *Live, after:* **0 unsupported, 0 furniture overlaps**, with the idle clip running.

8. **Clean and nice:** a `Rug` lying ON the boards in front of the hearth (its bottom **is** the floor
   top), clear of the hearth stone by 0.5 and of the bench legs by 0.15; the trophies at exactly
   **two** heights with the east wall a 2 × 4 grid and the north wall's boar level with the roe
   beside it. *Verify:* `CONFIG.LODGE.RUG`, `TROPHIES.UPPER_STUDS` and `TROPHIES.MOUNTS`;
   `lobby.spec` *"lays the rug ON the floorboards"* and *"hangs the trophies in rows: two heights,
   and a wall's two rows in the same places"*; `<runs-dir>/t195/195-a-rug.png`,
   `195-a-door.png`, `195-a-room.png`, inspected.

9. **The lobby still works end to end.** Forest Test smoke **PASS**:
   `lobby=[lobby gunBefore=false] gun in hand @15s=1 @80s=1 | stacks=0 errorLines=0 | waves=6 |
   worst playing sounds over 10 s: 1 (boars=17)`.

10. **The first gate run FAILED and the failure was mine.** `.agent-logs/task195-r1-test1.log`:
    `lobby_live.spec` asserted the prompt was a descendant of the keeper's BODY, which claim 6 made
    false. Fixed in `748cf29` by asserting what matters — a keeper, a prompt, and the prompt on the
    counter. Reported rather than absorbed.

## What I could not verify

* **Whether Karen likes it.** This is a look task and the eye that matters is hers; she judges in the
  morning. Eight screenshots were taken and inspected, in `<runs-dir>/t195/` (`195-b-*` before,
  `195-a-*` after).
* **The two-player run.** Not run: no `TWO_PLAYER_PATHS` file is touched.
* **A pre-existing fact, measured and NOT fixed here:** the keeper's `UpperTorso` and `LowerTorso`
  read `CanCollide = true` in the live place although `Build.shopkeeper` sets every part false twice
  — the engine re-enables them on a rig it re-dresses. It no longer matters (nobody can reach him),
  and `lobby.spec`'s *"cannot be pushed…"* case cannot see it because the spec's fake rig is not
  re-dressed by the engine. Queued for the Director rather than claimed as fixed.
* **A harness lesson that cost an hour** (research note 3.2): a `ProximityPrompt` is not drawn behind
  the camera, and this game's camera keeps its own yaw through `Character:PivotTo` — so every probe
  that teleported the player to the till and asked "is the prompt shown" answered no, through a
  parent change, a stand-off sweep and `RequiresLineOfSight = false`, for reasons that had nothing to
  do with the lodge. `PromptShown` is a poor detector too (it fires on the edge); count the
  descendants of `PlayerGui.ProximityPrompts`.
* **`docs/design/lobby.md` is not edited** — the Architect's file. No owner changed; the counter's
  geometry, the service bay and the prompt's new home are a design delta for the Architect.

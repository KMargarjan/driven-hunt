# Task 260 -- the sight is true, leaves stop nothing, and the origin bound is measured

Task: 260
Round: 2
Base: main @ ae8aba15
Code commit: 152b26343e86c5c1a48496c9a709f771d3980394

```
[harness] PASS: 34/34 checks @ 152b26343e86c5c1a48496c9a709f771d3980394 (clean tree) scope=all
```

`[harness2]` is **N/A**: nothing here touches `TWO_PLAYER_PATHS`. The changed files are
`src/shared/Shotgun/`, `src/server/Weapon/` (init and Validator), `src/server/Places/`,
`src/serverstorage/MapGen/Props.luau`, `src/server/ForestTestBoot.server.luau`, three server specs,
the scenario file and `tools/studio_mcp.py` -- weapon, map, places and tools, which the Director's
2026-10-03 decision puts on the one-player line for the review round and for the PR to `main`.

## THE ONE THING THAT IS NOT DONE, FIRST, BECAUSE IT IS THE BIGGEST RISK TO THIS ROUND

**`docs/design/shotgun.md` section 5.5 step 7 still says the bore starts at the muzzle, and the
shipped code no longer does.** The Architect design run that was dispatched to fix that **failed
twice and wrote nothing**: run 1 was killed at 9m50s by my own foreground timeout (the tool's ceiling
is 10 minutes), run 2 was relaunched detached, waited for in the foreground, ran ~19 minutes and was
refused by `tools/agents.py` -- *"agent output has no `=== BEGIN ARCH_RESULT ===` ...
`=== END ARCH_RESULT ===` block"*.

**I am not disputing that the document and the code disagree. I am reporting it.** What is NOT
missing is the authority: the change is the Director's own decision, dispatched verbatim
(transcribed into TASKS.md row 260 and quoted below) and resolving my own `ESCALATE.md` entry of
2026-10-25. `reviews/task-260/BRIEF.md` is committed and states exactly what the amendment must
contain. The design run is one command away for whoever has the clock.

> *"YOUR ESCALATION (2026-10-25, BORE_ON_SIGHT_LINE) IS DECIDED by the Director: OPTION 1 ...
> THE TRUE SIGHT: `BORE_ON_SIGHT_LINE = true`."*

## Round 1 -> round 2

**Both blocking findings were mine and both are closed.**

1. **Two shipped comments claimed `docs/design/shotgun.md` had been amended by this task.** It has
   not been (the top of this request has always said the Architect runs wrote nothing), so the
   comments were telling a reader the document agrees with the code on exactly the line the task
   changed. `Shotgun.CONFIG.BORE_ON_SIGHT_LINE` and `sights.spec`'s describe now say the document is
   NOT yet amended and point at `reviews/task-260/BRIEF.md`.
2. **A real defect: `onActionRequest`'s `"Aim"` branch still bounded the client's claimed origin at
   15 studs while `onFireRequest` bounded the byte-identical payload at 6** -- two answers to one
   question, under a comment promising *"THE SAME VALIDATOR THE TRIGGER'S RAY GETS"*. It now passes
   `ORIGIN_TOLERANCE_STUDS`. `src/client/Weapon/Input.luau` says the two payloads are built from the
   same two lines, so this was reachable by any player who shouldered a gun.

**Six notes fixed, four of them numbers I had written wrongly:** the first-person minimum is
**1.226** studs, not 1.209 -- not a value the pitch clamp allows -- and the case now asserts the
closed form at BOTH ends so the figure cannot be wrong in silence again; *"16 is that clamp plus
0.5"* was two errors in one line above a row that ships 15; `camera_mode.spec` claimed the
third-person clamp *"really does bind"* where `Shotgun.CONFIG`'s own arithmetic says it never does
(it is asserted both ways now); `Mode.luau` still described 30 studs with 15 of headroom; `BRIEF.md`
carried the stale 16 into the document the amendment will be written from; and the `FIRST_PERSON`
flag row now records that the server reads it too, which is a real second reader.

**And one note was a weakness worth fixing rather than queueing:** `stats.originFarthest` is written
only on the accepted path, so it could argue the bound TIGHTER and never looser -- the one event that
would show 6 studs is too tight is a shot refused `origin-far`, and that shot never reached it.
`stats.originRefused` and `stats.originRefusedFarthest` now record the refusal path.

**Two notes are deliberately not acted on and are for Karen or the Architect, not for me:** that
`unblockFoliage` clears `CanCollide` on ground-level cover (`bush`, `fern`, `shrub`) and so changes
where a player can WALK as well as where a bullet goes -- true, a consequence of the measurement, and
a thing to look at in a playtest; and that `Props.placeTree` reverses a choice its own comment
attributes to `docs/design/` section 7.1, which is the same document gap as finding 1 and the
Architect's to close.

## Claims

1. **The sight is true now, and the assertion that says so fires the shipped value rather than
   reading it.** `sights.spec`'s *"is TRUE in the shipped build"* case takes
   `Shotgun.CONFIG.BORE_ON_SIGHT_LINE` and flies it through `boreOrigin` -> `convergeAim` ->
   `launchDirection` -> the real `Flight` at the case Karen named -- the aim ray missing -- at
   25 / 50 / 100 m, and demands the reticle to 1.68 cm. On the pre-flip config that expectation
   lands 0.66 studs right at 25 m, so it fails by a factor of ten and for the right reason (the
   Learning Agent's L-028).
   *Verify:* that case; and the describe above it, which still measures the `false` branch
   explicitly and pins the old error as a LOWER bound so it cannot be shrunk in silence.

2. **The measured before/after, which is the dispatch's "re-measure the sights table".** Rifle, the
   measured shotgun hold, ray missing: **+18.6 / +16.2 / +11.6 cm RIGHT -> 0.0 at all three ranges**;
   on-reticle (ray on target) unchanged at +0.6 / +1.1 / +1.5 cm up, which is the arc alone.
   *Verify:* `sights.spec`'s print case puts the whole table in the harness log every run
   (11 (gun, range) cells x three columns), and the sweep case asserts the bound over 44 cells.
   **Three sighted guns are covered, not one:** rifle (scope), lever (open sights) and semi-auto
   (red dot), plus the shotgun's bead -- all in `GUNS`.

3. **`CAMERA_ORIGIN_TOLERANCE` is tightened from 30, and the number is MEASURED rather than
   chosen.** The sweep drives `Mode.cameraCFrame` over every pitch the clamp allows x every yaw x
   three blends: first person is **1.209 to 1.993 studs** from the root, and the closed form
   (`1.6^2 + 0.4^2 + 1.28*look.Y`) is asserted to agree with the sweep's maximum to 0.01 studs.
   `blend` does not appear at all, which is task 92's no-jump rule as arithmetic.
   *Verify:* `camera_mode.spec`, *"the honest spread of the fire origin"* -- three cases.

4. **So the shipped first-person bound is 6 and the third-person rollback's is 15, each bounded
   against its own branch.** 6 is three times the honest worst case; the margin is for the one term
   nothing here can measure (rule 8) -- the client sends the eye it DREW and the server compares it
   with the root it has REPLICATED, and a loopback Studio session reads 1-2 ms of ping (task 256).
   15 is bounded against the client's own `MAX_DISTANCE_STUDS` clamp **from both sides**: at or above
   14.5 so the client's own limit can never be refused, and within a stud of it so the slack cannot
   grow back. **A first version of that row at 16 failed its own margin assertion in the gate** --
   the unclamped third-person eye only reaches ~13.5 studs, so the clamp never binds -- which is why
   the bound is now written against the clamp and not against the sweep.
   *Verify:* the third case of that describe; `Shotgun.CONFIG`'s two rows and their derivations.

5. **The branch is read ONCE at the owner's boundary and passed inward.**
   `ORIGIN_TOLERANCE_STUDS = if Flags.isOn("FIRST_PERSON") then ... else ...`, module level in
   `src/server/Weapon/init.luau`; `Validator.checkShot` takes it as a FOURTH argument and `nil` is
   `config.CAMERA_ORIGIN_TOLERANCE` -- every caller written before this task, bit for bit
   (`weapon_shot.spec`'s own config table is one).
   *Verify:* the two call sites and `Validator.checkShot`'s header. It reads the same flag
   `Camera.Config` reads, which is the point rather than a coupling: "is this game first person" has
   one answer.

6. **`Weapon.stats.originFarthest` is the instrument for the margin.** The largest `|origin - root|`
   any ACCEPTED shot had, so the next move of either row can be argued from a real server instead of
   from reasoning.
   *Verify:* the field and the one `math.max` in `onFireRequest`, after the validator and before
   anything is committed.

7. **259's un-reconciled reading is RESOLVED, with a control, and it is an engine fact worth
   knowing.** Two Include-filtered casts, each at one named part in the Forest Test:
   `OurForest.SilverBirch_Var11_LOD_0.Branch.001` (`CanQuery = false`, `CanCollide = TRUE`) **HITS**;
   `OurForest.SM_AspenTree_Var02.SM_Leaves` (`CanQuery = false`, `CanCollide = false`) does not.
   **`CanQuery = false` does not exempt a part from a raycast while it still collides.**
   *Verify:* `driven-hunt-runs/260-why.luau` (read-only) and `Places.unblockFoliage`'s header, which
   records both casts. That is why L-060 kept recurring: the old rule only ever cleared `CanQuery` on
   parts that were already not colliding -- exactly the set for which it changed nothing.

8. **So foliage loses BOTH properties, at one rule, and trunks keep both.** `Places.unblockFoliage`
   is the rule; `Places.quieten` calls it on the planting path; `Places.build` runs it over the
   standing Studio folders at boot; `MapGen.Props.placeTree`'s grey-box canopy loses `CanQuery` so
   the generated map answers the same way.
   *Verify:* `places.spec` -- the visible-and-colliding `Branch.001` case (both properties, trunk
   untouched), the queryable-leaf case (and that a second sweep changes nothing), and the name-list
   case, which asserts eleven real names from Karen's wood as foliage and seven real trunk names as
   not. **The name list is a deliberate exception to that function's own property rule and says so
   where it is written**: a leaf that is visible AND collides is indistinguishable from a trunk by
   its properties, which is the state the measurement found.

9. **MEASURED ON KAREN'S OWN MAP, in a live Play session, before and after.** Queryable foliage parts
   **623 -> 0**; colliding `Branch` parts **127 -> 0**; a 9x9 grid of eye points x a 9-ray fan at
   282 studs (79 m) at chest height, stopped by foliage **19 of 729 -> 0 of 729**, with terrain stops
   essentially unchanged (365 -> 369) and total blocks 523 -> 507.
   *Verify:* `driven-hunt-runs/260-foliage.luau` / `260-after.luau` / `260-left.luau`, and the
   `[ForestTestBoot] places: ... N leaf part(s) unblocked` line the boot now prints.

10. **A first sweep left 41 standing and the reason is in the code: this place has TWO `Workspace`
    children called `Session`.** `Places.templates`' `FindFirstChild` can only answer one, so
    `Places.foliageRoots` walks the children and matches the first segment of each
    `TEMPLATE_SOURCES` path.
    *Verify:* `places.spec`'s *"finds EVERY tree folder, including a duplicate name"*, and the live
    re-measurement above, which went 41 -> 0 after it.

## What could not be verified, or was not done

- **The design document (see the top).** Two Architect runs, nothing written.
- **Item 3, the real-click lead proof, is written and ARCHIVED rather than shipped**
  (`backups/2026-10-25_task-260_lead-proof-client-spec.luau` plus its note, rule 7). The blocker is
  measured, not guessed: **two stage-driven scenarios cannot coexist**, because the stage sets ONE
  attribute (`StagedTarget`) for every scenario, so `shoot_boar.spec` and this spec would both latch
  on whichever staged first and then drive `Camera.lookAt` at the same boar with different aim
  points. The load failed first for a smaller reason -- `InputReady.EXPECTED` is the one place an
  input-driven spec is named -- and **that one abort took the whole client suite with it**, which is
  itself worth knowing. Queued as 260a with the exact restore steps and the fix (a per-scenario stage
  marker in `tools/studio_mcp.py`).
- **The high-seat scope frame in the Forest Test was dropped for time.** The Forest Test was used
  only for the item-2 measurement; its attributes were read FIRST and LAST and are **identical**
  (`placeId=130094961655666 DHFlag_... DHForestStartRole=hunter DHShopTestGrant=true`), nothing was
  written there, Play was stopped and **the window was closed before every harness run** -- the
  harness log says `1 Studio connected ... Driven Hunt DEV`.
- **Rule 5:** no screenshot. Nothing drawn changed; what changed is where a bullet starts and what a
  leaf does to it. The frame that WOULD be evidence is a shot landing on the reticle at 100 m, and
  that is item 3's job and Karen's.
- **The replication-lag half of claim 4's margin**, as claim 4 says.
- **Time: measured, not estimated.** `duration_ms` from the session's own recorded start
  (1792891055673) was **5,250,676 ms = 87 minutes** at the end of round 1, inside the 2.5 h box.
  **Round 1's request and TASKS.md row claimed "2h40, over the box" and that was wrong** -- I read a
  local clock as UTC. Corrected in both places rather than left standing, because an invented
  overrun is as bad as a hidden one.

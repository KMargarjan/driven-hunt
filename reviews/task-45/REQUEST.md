# Task 45 — hygiene from the queued notes

Task: 45
Round: 1
Base: `56b2768` (task-44-map-full; stacked on 43, 41, 38, 36 and 35, none merged)
Code commit: `12e49a4ed2c655b12e6a741a7466e43ea93c2204` — this request's own commit, which is what
both harness lines name. It is after the last commit that changed `src/`, `tests/` or `tools/`
(`5be36cf`), and only this fill-in changed after it. That sequence is exactly what claim 1 writes down,
and this is the first request written to it.

Harness, clean tree, one player:

    [harness] PASS: 27/27 checks @ 12e49a4ed2c655b12e6a741a7466e43ea93c2204 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: 30/30 checks @ 12e49a4ed2c655b12e6a741a7466e43ea93c2204 (clean tree)

302 server specs (301 before this task), 70 shooter-client, 64 driver-client.

Generator, clean tree, same seed twice, and walkable, at `5be36cf` (the terrain change below):

    [mapgen] build 1: digest=c9b8a30dfbabf867aabcdf7df26658d7cdd6b69e47a9b5f4177a7ce208b9de98 parts=1238
    [mapgen] build 2: digest=c9b8a30dfbabf867aabcdf7df26658d7cdd6b69e47a9b5f4177a7ce208b9de98 parts=1238
      BoarSpawn1..4, DriverStart: Enum.PathStatus.Success (339-370 waypoints)
    [mapgen] reachability OK
    [mapgen] OK: same seed twice, same digest @ 5be36cf51fa529a16899a5cc3382bbae772b425d seed=7 digest=c9b8a30dfbabf867aabcdf7df26658d7cdd6b69e47a9b5f4177a7ce208b9de98 (clean tree)

The digest differs from Task 44's because the terrain changed (claim 2). The map was cleared out of
Workspace again afterwards, so the place is empty for the harness.

## What changed

Hygiene, from the notes queued on Tasks 43 and 44. One behaviour change came out of it, and it is the
largest thing here: writing the slope check that a constant had promised since M2.2 found the drive
corridor at 22.5°, against the design's 15.

## Claims

1. **`Code commit:` now means one thing, and it is the thing the gate enforces** — row 44a(k), noted
   in three reviews running. The definition: *the commit the harness lines name; at or after the last
   commit that changed `src/`, `tests/` or `tools/`; only paperwork after it.* A **later** paperwork
   commit is allowed (the Director runs `test2` at the branch head, which by then carries the request
   itself) and only narrows what the evidence must cover; an **earlier** one is refused, because then
   nothing ran over the code. Written in `CLAUDE.md` git workflow step 4, its definition-of-done box
   and its "what is enforced" paragraph; in the `tools/studio_mcp.py` docstring, beside what the sha
   in the final line is; and in `harness_gate`'s own docstring in `tools/agents.py`, which is the code
   that refuses it. `docs/REVIEWER_PROMPT.md` already said it and is untouched. **This request is
   itself the first one written to that rule** — see the `Code commit:` note above.

2. **The corridor was too steep, and now it is not** — row 44a, `CORRIDOR_MAX_SLOPE_DEG`. The comment
   claimed "the spec measures it" and no spec did. Writing it found the drive corridor reaching
   **22.53°** against the design's 15. The cause is not the noise: it is the **spawn-pad easing** — a
   pad is flat at `GROUND_Y` while the ground around it is up to `CORRIDOR_RELIEF` studs away, so a
   short blend rings every shooter post and every boar spawn with a ramp. Measured over three seeds on
   a 20-stud lattice: `blend 24 → 22.53°`, `blend 40 → 12.94°` at the same relief; `relief 12,
   blend 24 → 17.28°`. `Map.SPAWN_PAD.blend` is 40 now and the relief is untouched, because the relief
   is Karen's taste value for how rolling the corridor is and the blend is not. **This is a deviation
   from design §7.3's 24**, and it is queued as 45a(a) for the Architect.

3. **The slope spec measures the ground a boar walks.** `it("keeps the drive corridor under the
   design's slope ceiling")` samples the whole corridor on a 20-stud lattice for two seeds, through
   `Height.atFlattened` **with the pads and the bog applied**, across an 8-stud step — one voxel wider
   than the terrain's own resolution, so the number is about ground the engine builds. It fails loudly
   with the worst slope and where it is, and it asserts the ground is not trivially flat either.

4. **The relief-band test now samples the map.** It ran over ±250, which at 2,048 studs is entirely
   inside the drive corridor: `worst` and `worstCorridor` were the same number, so the whole-map bound
   could not fail and ~94% of the map was sampled by nothing (round 1 of Task 44). It samples ±1000.

5. **Eight comments that no longer matched their code** (row 44a(i)) — the hedge part count, the
   `mapgen.py` docstring's step count and capture count, `verifyContract`'s declared return type and
   its `Map.FIELD`/`Config.FIELD` wording, `Map.SIZE_STUDS`'s pointer to a constant this branch had
   removed, the spawn-pad test's post spacing, `SCATTER_CLEARANCE`'s claim to cover tracks and the
   bog, and measurement H's addition. Each now says what the code does.

6. **`Layout.Marker.facing` is gone** (row 44a(j)): set to 0 on every marker, read by nothing, and a
   second unread way of saying what `Markers.place`'s explicit `CFrame.lookAt` already says — the
   duplicate rule 3 exists to stop. The drive line's facing is still asserted by the contract spec.

7. **Nothing else changed.** `git diff --stat 56b2768..5be36cf` is `CLAUDE.md`, the research note,
   four `MapGen` files, `Map`, the contract spec and three tools. No new feature, no new step, no
   change to the generator's plan: 268 steps and 1,238 parts, exactly as Task 44.

## What I could not verify

* **Whether 40 is the right blend** is Karen's, not mine: it makes the ground around every post and
  spawn gentler, which is what the number is for, but how it *feels* to stand there is a walk.
* **The two screenshots I retook** (`map-line`, `map-corridor`) look the same as Task 44's at those
  camera distances — the change is a sub-metre difference in a ring around each pad, 700 studs from
  the camera. I am reporting that they show no visible difference, not that they show the fix.
* **The other five shots were not retaken**, because nothing in this task moves a tree, a hedge, a
  track or the bog.
* **Measurement B (tags across save + reopen)** is still open from Task 43.
* **`docs/REVIEWER_PROMPT.md` was not edited.** It already matches the definition, and it is not a
  file `CLAUDE.md` lists the Builder as writing.

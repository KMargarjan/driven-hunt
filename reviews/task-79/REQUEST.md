# Task 79 — M2.8e: the generated map IS the world

Task: 79
Round: 2
Base: `main` (`4650b97`)
Code commit: `cc5045ceb5fc8a397e55627f2fd04814e2efc248`

```
[harness]  PASS: 32/32 checks @ cc5045ceb5fc8a397e55627f2fd04814e2efc248 (clean tree)
[harness2] pending — the Director's run at this branch's head
```

My own clean-tree run, **on the map world**, with `[tests:server] PASS: 414 passed, 0 failed, 0
errors, 25 spec files`. `src/` and `tools/studio_mcp.py` both changed, so `test2` is part of the gate
and the Director runs it at the head; the head is a paperwork commit, which only makes the bound
stricter. Round 1's two lines were `PASS: 32/32` and `PASS: 32/32` at `a21efef`, and this round
changed nothing a second client would see — `tests/client/` is untouched by the whole branch, which
round 1's request got wrong (Reviewer note, fixed here).

**Round 1's finding was right, and then right a second time about my fix for it** — claims 8 and 9.
An assertion that passes for the wrong reason is what this whole task has been about.

**What changed this round.** `tools/studio_mcp.py` (9c's fixture and its per-case branch assertions,
the `UNREADABLE` guard, the docstring's `selftest` paragraph, case (b)'s wording),
`tests/server/test_arena.spec.luau` (the dormant note's count), `src/server/Boar/init.luau`
(`CONFIG.spawnPoint`'s comment), `TASKS.md` rows 79/79a.

**What the branch changes in all.** `src/shared/Map/init.luau` (`EXPECTED_WORLD`, `SEED`, `DIGEST`, `FIELD`,
`EXPECTED_COUNTS`), `src/server/ArenaBoot.server.luau`, `src/server/Boar/init.luau`
(`CONFIG.field`), `src/server/MatchBoot.server.luau`, `src/server/Match/init.luau`
(`stats.firstReleaseAfterSeconds`), `tests/server/map_contract.spec.luau`,
`tests/server/test_arena.spec.luau`, `tests/server/boar_body.spec.luau`,
`tests/server/zz_drive_boundary.spec.luau`, `tools/studio_mcp.py` (`QUERY_STAGE_TARGET`,
`stage_seed`, `QUERY_STAGE`, `json_answer`, selftest 9c), `CLAUDE.md`, `GAME_DESIGN.md`,
`ESCALATE.md`, `TASKS.md`.

## Claims

1. **The switch is one committed string, and that is a Director decision with a measurement behind
   it.** `Map.EXPECTED_WORLD = "map:v1"`, `SEED = 1`, `DIGEST` the full sha256. It was built behind a
   flag first; with the map in Workspace and the flag off, the same commit went from 32/32 to 22/27
   with eleven specs failing and `GetTagged("DrivenHunt.ShooterPost")` answering **16**, because both
   worlds tag with the same strings. `ESCALATE.md` carries the decision verbatim under `### RESOLVED`
   and CLAUDE.md's "Feature flags" section now names the exception. **Nothing of the `MAP_V1` flag
   survives**: `grep -rn MAP_V1 src tests tools` is empty, and nothing is archived because it never
   merged. **And `GAME_DESIGN.md`'s owners table no longer says the opposite of what ships** — a
   documentation defect, not a preference: the generated map's row read *"it is still NOT the world:
   `Map.EXPECTED_WORLD` is still `"arena"`"*, and the arena's row read *"the arena is the only thing
   this repo puts in Workspace at all"* while `ArenaBoot` now builds nothing. Three rows fixed,
   including why `TestArena` keeps its file (it is the rollback until section 17 step 9).
2. **`ArenaBoot` builds nothing, and it cannot be half-on.** It returns early on
   `Map.EXPECTED_WORLD ~= "arena"` before requiring `TestArena` — not hidden, not moved, not built —
   and it never sniffs Workspace for a folder, because a predicate like that lies the moment a run
   half-finishes. Verify: `test_arena: world=map:v1, the arena is not built; this file's other cases
   are dormant until the switch goes back to "arena"`, and `task79: ... arena=absent, map=in
   Workspace`.
3. **The corridor is the design's, and the boar and the contract agree about it.**
   `Map.FIELD` is x ±620, z −880…+800, `exitZ = -820`, which is 120 studs PAST the road at z = −700 —
   Karen's decision that the boars cross it. `map_contract.spec`'s "the map switch" describe asserts
   every number, that `exitZ < Map.ROAD.z` and that `Map.ROAD.z - FIELD.exitZ == 120`; the
   `Boar.CONFIG.field` deep-equal lives in "agrees with the boar about the field rectangle, in
   whichever world this is" (round 1's request cited the wrong describe for it). Verify: `boar field x[-620,620] z[-880,800]
   exitZ=-820`.
4. **Twelve tie trees, not the arena's four corner pillars**, and the other four counts are the same
   because it is the same drive. `Map.EXPECTED_COUNTS.tree = 12`; `mapgen.py contract` answers 8
   shooterPost, 1 driveLine, 1 driverStart, 4 boarSpawn, 12 tree, marker digest
   `e064d5982513a08616d2bf367f61c30c`.
5. **The arena-shaped specs are BRANCHED, not archived** (`test_arena.spec`, `boar_body.spec`).
   Section 17 step 9 archives them only after Karen accepts, and a deleted spec cannot check the
   rollback. Both print what they did rather than passing silently: `the arena is not built; this
   file's other cases are dormant`, `the arena's cover case is dormant`. Neither note names a COUNT any
   more: the dormant one said twelve and there were ten (Reviewer note, round 1).
6. **79a(i), fixed at the harness, at its class, the way the Director chose (fix (1)).**
   `QUERY_STAGE_TARGET` asks the **SERVER** where its own boar is — read-only, constant, one JSON
   argument, no arbitrary Luau — and `stage_seed` hands the position to the client stage, which pivots
   the character there **before** it waits, so streaming brings the boar in. The wait splits by what
   each half waits for: the server holds the drive's clock (`STAGE_TARGET_WAIT_SECONDS` 60) and the
   client holds only replication (`STAGE_STREAM_WAIT_SECONDS` 30). Verify: `[input] shoot-the-boar:
   the server's Workspace.Boars.Boar1 is at (-449, 3, 600); the client is placed there first,
   Map.STREAMING.targetRadius 1024` → `staged on Workspace.Boars.Boar1, 22 studs away`.
7. **The diagnosis was measured before anything was widened, and the answer was neither candidate.**
   `Match.stats().firstReleaseAfterSeconds` and a permanent `zz_drive_boundary` note print the drive
   every run: `phase=Running releases=1 deferred=0 boars=1 alive=1 firstReleaseAfter=40.5s`. 40.5 s is
   `INTERMISSION_SECONDS` 20 + `FIRST_RELEASE_SECONDS` 20, nothing deferred — **the map costs the
   drive nothing**, so there was nothing to fix at its owner, and a bigger scenario budget could not
   have helped either: the boar is released 1,300 studs from the lone shooter against a streaming
   radius of 1,024 and was never going to be replicated to that client.
8. **The arena path is unchanged, and that is enforced rather than asserted.** A server that cannot
   be asked, or answers no usable position, falls back to exactly the old query — no seed, the
   client's own 60 s wait against the same folder. Selftest 9c drives the **real** `replay_input`
   against a scripted Studio: four kinds of unusable answer (a raising transport, a bare string, JSON
   with no position, the `{error}` object) each give `"seedPosition": null` and `"waitSeconds": 60`
   with the stage still passing, and the seeded case gives the position, 30 s and the target's name.
   **Each case now pins itself to ONE branch**: it names the words the log must carry *and* the
   branches it must not take. `json_answer` and `stage_seed` have three ways to refuse and two of them
   repeat the server's answer back into the message, so "the error text is in the log" is satisfied by
   the wrong branch as easily as the right one — which is precisely how round 1's malformed fixture
   went unnoticed. The `{error}` fixture is built with `json.dumps`: valid by construction, not by
   proofreading.
9. **Five mutations, applied, run and restored.** Break `json_answer`'s `data.get("error")` branch →
   three cases fail, naming `also took ['carries no usable position']`; **this is the one that showed
   my first fix was still passing for the wrong reason**, because the `{error}` object then arrived as
   data with no position and that message repeated every word the case looked for. Restore round 1's
   stray seam → two cases fail, printing the malformed `""` verbatim. Drop the seed → case (a) fails,
   printing the JSON the client was handed, `"seedPosition": null`. Drop the transport guard → three
   cases report `raised RuntimeError: place is not open`, Task 78's shape of defect avoided here. Read
   the radius off Workspace again → the CI guard fails, naming `.StreamingTargetRadius`.
10. **It cost an extra round, and the reason is worth reading.** The first `QUERY_STAGE_TARGET` read
    `Workspace.StreamingTargetRadius`, and a live run answered *"not a valid member of Workspace"* for
    **every** stage — which `src/shared/Map/init.luau` had already recorded in a comment: that
    property and its three neighbours are reachable only from the Studio property pane. The fallback
    carried the run instead of crashing it and printed the reason on its own line, which is why one
    run was enough to find it. `Map.STREAMING.targetRadius` is the one source for it now, read by the
    server query only, and the guard in claim 9 refuses any staging query that names one of the
    five — scanned as `.<Name>` since this round, so `local w = Workspace; w.StreamingTargetRadius`
    no longer slips past (Reviewer note). That second fix is why `6ddb54e` exists; claim 1's
    owners-table rows are why `05df7bb` does; this round is `cc5045c`.
    **Four more round-1 notes fixed here rather than queued**, each because it was a documentation
    defect and not a preference: `test_arena.spec`'s dormant note claimed *"its 12 cases are dormant"*
    and there were **ten**, so it names the file instead of a count and cannot go stale; the
    `studio_mcp.py` docstring still said `selftest` *"exercises the pure helpers only"*, untrue since
    Task 78, and CLAUDE.md makes that docstring the source of truth for the test system;
    `Boar.CONFIG.spawnPoint`'s comment described the Task 17 arena (*"210 studs from exitZ … clear of
    PillarMid and WallWest"*) when with `exitZ = -820` it is 840 studs and neither part is built; and
    case (b)'s label claimed it proved `QUERY_STAGE`'s Luau format string when it proves the
    propagation, the live run being that message's only evidence.

## What I could not verify

- **THE SAVE IS SENT, NOT VERIFIED, and this is the one thing still open** (`TASKS.md` 79a(j), and an
  `ESCALATE.md` **NEEDS KAREN** entry with the exact clicks). The Director posted Alt+Shift+S with
  Studio in Edit mode and the built map in view, and **Studio showed no confirmation dialog**. Nothing
  a tool can run reads Roblox's copy of a place: `mapgen.py contract` answers `OK` for the Edit
  session that was saved — the same DataModel, not proof it landed. Section 17 step 5's measurement B
  needs a **reopen**, which drops Rojo and the MCP link, so it waits for Karen's 10:00 session. Every
  harness result here is a run against the map in that Edit session, which is what a player would
  stand in; what is unproven is only whether Roblox kept it.
- **`test2` is the Director's run, not mine**, and a second player exercises paths one does not: the
  driver's half of the client suite, a team swap and the tie. I have not watched that session.
- **Three round-1 notes are queued, not fixed**, because none is a one-liner, and each is written out
  in `TASKS.md`: **79a(l)** no `SpawnLocation` exists in the map world and nothing asserts one (a
  joining player gets Roblox's origin fallback until the drive places them — not broken, the live run
  placed, shot and scored, but §17 never named it and it is a decision with an owner); **79a(m)**
  `stats.firstReleaseAfterSeconds` is first-writer-wins per server process, so a future spec could
  silently claim the number claim 7 rests on (it did not: 40.3 s and 40.5 s over two runs); **79a(n)**
  no Play-mode capture of the switched state exists — the nine images are Edit-mode stills, and a Play
  capture needs a session outside the harness's own.
- **No new screenshot this round**, and none was warranted: nothing was rebuilt. The nine from
  `d133bba` stand at the same seed and marker digest.
- **Whether the map plays well is Karen's eye**, not a measurement: the eighty-metre sightlines, the
  120 studs past the road, how long 40 s feels waiting for the first boar. Five more items sit in 79a,
  none of which changes what this branch does.

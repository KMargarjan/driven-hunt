# Task 79 — M2.8e: the generated map IS the world

Task: 79
Round: 1
Base: `main` (`4650b97`)
Code commit: `05df7bbf0e69ddc329a0e17e82291be42dd10ff3`

```
[harness]  PASS: 32/32 checks @ 05df7bbf0e69ddc329a0e17e82291be42dd10ff3 (clean tree)
[harness2] pending — the Director's run at this branch's head
```

My own clean-tree run, against the **generated map**, with `[tests:server] PASS: 414 passed, 0
failed, 0 errors, 25 spec files` and the client reporting after 18 s, 93 s total. `src/`,
`tests/client/` and `tools/studio_mcp.py` all changed, so `test2` is part of the gate and the
Director runs it at the head; the head is a paperwork commit, which only makes the bound stricter.

**What changed.** `src/shared/Map/init.luau` (`EXPECTED_WORLD`, `SEED`, `DIGEST`, `FIELD`,
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
   merged.
2. **`ArenaBoot` builds nothing, and it cannot be half-on.** It returns early on
   `Map.EXPECTED_WORLD ~= "arena"` before requiring `TestArena` — not hidden, not moved, not built —
   and it never sniffs Workspace for a folder, because a predicate like that lies the moment a run
   half-finishes. Verify: `test_arena: world=map:v1, the arena is not built and its 12 cases are
   dormant`, and `task79: ... arena=absent, map=in Workspace`.
3. **The corridor is the design's, and the boar and the contract agree about it.**
   `Map.FIELD` is x ±620, z −880…+800, `exitZ = -820`, which is 120 studs PAST the road at z = −700 —
   Karen's decision that the boars cross it. `map_contract.spec`'s "the map switch" describe asserts
   every number, that `exitZ < Map.ROAD.z`, that `Map.ROAD.z - FIELD.exitZ == 120`, and that
   `Boar.CONFIG.field` deep-equals `Map.FIELD`. Verify: `boar field x[-620,620] z[-880,800]
   exitZ=-820`.
4. **Twelve tie trees, not the arena's four corner pillars**, and the other four counts are the same
   because it is the same drive. `Map.EXPECTED_COUNTS.tree = 12`; `mapgen.py contract` answers 8
   shooterPost, 1 driveLine, 1 driverStart, 4 boarSpawn, 12 tree, marker digest
   `e064d5982513a08616d2bf367f61c30c`.
5. **The arena-shaped specs are BRANCHED, not archived** (`test_arena.spec`, `boar_body.spec`).
   Section 17 step 9 archives them only after Karen accepts, and a deleted spec cannot check the
   rollback. Both print what they did rather than passing silently: `the arena is not built and its 12
   cases are dormant`, `the arena's cover case is dormant`.
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
8. **The arena path is unchanged, and that is enforced rather than asserted.** A server that cannot be
   asked, or answers no usable position, falls back to exactly the old query — no seed, the client's
   own 60 s wait against the same folder. Selftest 9c drives the **real** `replay_input` against a
   scripted Studio: four kinds of unusable answer (a raising transport, a bare string, JSON with no
   position, the `{error}` object) each give `"seedPosition": null` and `"waitSeconds": 60` with the
   stage still passing; the seeded case gives the position, 30 s and the target's name; a target that
   never replicates fails the check with `1300 studs` and `targetRadius is 1024` in the message.
9. **Three mutations, applied, run and restored.** Drop the seed → case (a) fails, printing the JSON
   the client was actually handed, `"seedPosition": null`. Drop the transport guard → three cases
   report `raised RuntimeError: place is not open`, which is Task 78's shape of defect avoided here.
   Read the radius off Workspace again → the new CI guard fails, naming
   `Workspace.StreamingTargetRadius`.
10. **It cost an extra round, and the reason is worth reading.** The first `QUERY_STAGE_TARGET` read
    `Workspace.StreamingTargetRadius`, and a live run answered *"not a valid member of Workspace"* for
    **every** stage — which `src/shared/Map/init.luau` had already recorded in a comment: that
    property and its three neighbours are reachable only from the Studio property pane. The fallback
    carried the run instead of crashing it and printed the reason on its own line, which is why one
    run was enough to find it. `Map.STREAMING.targetRadius` is the one source for it now, read by the
    server query only, and the guard in claim 9 refuses any staging query that names one of the five.

## What I could not verify

- **THE SAVE IS SENT, NOT VERIFIED, and this is the one thing still open** (`TASKS.md` 79a(j), and an
  `ESCALATE.md` **NEEDS KAREN** entry with the exact clicks). The Director posted Alt+Shift+S with
  Studio in Edit mode and the built map in view, and **Studio showed no confirmation dialog**. Nothing
  a tool can run reads Roblox's copy of a place: `mapgen.py contract` answers `OK` for the Edit
  session that was saved — the same DataModel, not proof it landed. Section 17 step 5's measurement B
  needs a **reopen**, which drops Rojo and the MCP link, so it waits for Karen's 10:00 session. Every
  harness result here is a run against the map in that Edit session, which is what a player would
  stand in; what is unproven is only whether Roblox kept it.
- **`test2` is the Director's run.** Two players exercise the driver's half of the client suite and
  the tie, neither of which one player reaches.
- **No new screenshot this round.** The nine from `d133bba` stand — same seed, same marker digest,
  nothing rebuilt. Rule 5 is satisfied by those, not by a fresh look.
- **Whether the map plays well is Karen's eye**, not a measurement: the eighty-metre sightlines, the
  120 studs past the road, how long 40 s feels while waiting for the first boar.
- **`mapgen.py shots` still takes nine screenshots where section 17 step 3 says eight** (79a(a)), and
  four other items sit in 79a. None of them changes what this branch does.

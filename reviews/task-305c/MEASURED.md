# Task 305c -- the live measurements, all in KAREN'S place (Forest Test, Play)

Her overrides were READ FIRST and nothing of hers was touched (rule K): `AIM_REWIND=on`,
`RANGE=on`, `BOAR_BEHAVIOUR`, `BOAR_MODEL`, `COINS`, `DEER_ROAD_LEAP`, `DRIVE_BOTS`, `HIT_CLAIM=off`,
`HORN`, `LICENCE_POPUP`, `LOBBY`, `SHOP` -- eleven overrides before this session, all eleven still
set. **ONE was added by me and is still ON, deliberately, so the Playtester can re-run the proof:
`DHFlag_ZONES_FOLLOW_GAIT=true`.** `flags.py --place forest clear` was never run.

The Forest Test worktree (`driven-hunt-karen`, rojo :34873) is left with `src/` and `tests/` at the
code commit `d375ba70`, checked out path-wise so no branch switch could kill `rojo serve`.

Instruments, all in `<runs-dir>/305c/`:

| probe | what it reads |
|---|---|
| `deform.luau` / `srvdeform.luau` | each bone's `TransformedWorldCFrame` minus its rest chain `mesh.CFrame * prod(bone.CFrame)`, in the trunk's axes. Client and server copies of the same question |
| `nosegap.luau` / `srv-nosegap.luau` | is the DRAWN nose bone inside any zone part, frame by frame |
| `prof.luau` | the static collision silhouette per z slice, against the zone boxes |
| `sil.luau` | mesh-vs-zone coverage over a grid, 6 frames apart |
| `srv-window.luau` | which zone part lies at each dz behind the drawn nose, along the animal's heading |
| `t-rifle-nose.luau` etc. (`trial.tpl`) | a real `FireRequest` from the client VM aimed at the drawn nose, zero lead |
| `z-run-rifle-nose.luau` | 305b's OWN rig, changed only in the aim point |

## 1. The cause, ruled in with numbers

| candidate (the dispatch's list) | measurement | verdict |
|---|---|---|
| (a) the zones do not cover the drawn head at a running gait | `nosegap`: the drawn nose is inside a zone part on **0 of 83** frames at RUN, 0/88 at trot. `deform`: nose dY -0.284..-0.640 in one run clip and **-1.648..-1.822** in the head-down one, against `ZoneHead1`'s 0.36-stud height | **THE CAUSE** |
| the 284 fit itself is wrong | `prof`: at z -2.40 the static mesh spans y +0.30..+0.90 and `ZoneHead1` +0.42..+0.76 -- strictly inside, as task 284 intended | RULED OUT |
| a skinned MeshPart raycasts its drawn pose | `sil`: 747 head rays hit the mesh on every one of 6 frames, identical -- the query geometry never deforms | RULED OUT (and it is why (a) could hide) |
| the server sees a different pose from the client | `srvdeform` vs `deform`: nose dY -0.281..-0.641 against -0.284..-0.640; head, Neck, Spine_01, Spine_03, Spine_05 and root_bone all agree to 0.003 | RULED OUT for the ENVELOPE. The PHASE is **not measured** |
| (b) the rewind over/under-shoots at 24 studs/s | `testedAt-firedAt` read **-0.078..-0.095** here where `reviews/task-305b/MEASURED.md` reads -0.126 on the same shipped constants. **Unexplained**, and it is part of the escalation | **NOT RULED OUT** |
| (c) the slug's flight time differs from the rewind's assumption | not run | NOT MEASURED |
| (d) the deer's zones | not run | NOT MEASURED |

## 2. Before and after, same probe, same place, same pace

| reading | flag OFF (same build) | flag ON |
|---|---|---|
| drawn nose inside a zone part, RUN, client | 0/98 | 96/105 |
| drawn nose inside a zone part, RUN, **server** (the tense the bullet is tested in) | -- | **86/94** |
| the window behind the drawn nose, at its own height | `Head1` for 0.4 studs, then AIR; `Legs` at +1.2..+1.6 | `Head1 Head2 [0.2-stud gap] Chest1 Chest2 Body3`, continuous to +3.0 |
| dz -0.2 and -0.4, i.e. AHEAD of the drawn nose | miss | miss, 8 of 8 frames |
| `ZoneHead1` size | 0.320 x 0.360 x 0.560 | 0.320 x 0.360 x 0.560 |

## 3. NOT PROVEN

- **The click proof.** rifle RUN nose 6/10 against the 8/10 asked. The control that must sit beside
  it -- chest + `Ballistics.leadStuds`, which 305b measured at 9/10 -- reads **4/10** on this rig in
  this session, so the instrument disagrees with its own earlier self and no click count here is
  evidence of the game's hit rate. `ESCALATE.md`.
- Slug, semi-auto, lever and red deer at the nose: **not fired**.
- The per-shot crossing offset against the drawn animal at the crossing instant: **not measured**
  (the rig reads the drawn nose ~0.2 s late, which is ~4.8 studs at 24 studs/s).
- The client/server animation PHASE.
- Rule 5 / Karen: nobody has played it, no frame was taken.
- A harness fault, reported per rule 6: with a SECOND Studio in Play, `test`'s input replay fails
  `shoot-the-boar` with `UserMouseInputTool.SendUserInput ... Target is not reachable
  (DMN_ID_PLAYCLIENT) ... Sender: DMN_ID_STANDALONE` -- four runs in a row, at three different
  commits. Stopping the other Studio's Play made the same commit read 34/34. The harness does not
  say this; it reads as a code defect.

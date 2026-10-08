# Task 133 - no weapon when it loads

Task: 133
Round: 1
Base: main (`e20bf37`)
Code commit: `d07a9cb56d847646e240ddab038c3e8699fc2d99`

```
[harness] PASS: 33/33 checks @ d07a9cb56d847646e240ddab038c3e8699fc2d99 (clean tree) scope=all
```

`test2` is N/A: this change touches no path in `TWO_PLAYER_PATHS` -- two client files under
`src/client/Camera*` and one `tests/client/` spec, all camera and viewmodel.

## What changed

Karen, 2026-10-09: *"no weapon when it loads"*. The Director played three fresh sessions in the
Forest Test and could not reproduce it: the Tool was in the character and the viewmodel existed from
his first sample at 0.8 s. So the task was to find the window.

**There are two, and the first one is not a window at all -- it is for ever.** Both were found with
a temporary client script that traced, per frame from t = 0, where the Tool is, whether the viewmodel
exists, how many of its parts are drawable, and each mesh's `ContentProvider` fetch status. That
script is removed; the tree at the code commit has no instrumentation in it.

## Claims

1. **`CameraBoot` LOOKED FOR THE WEAPON INSTEAD OF WAITING FOR IT, and that is the whole complaint.**
   `src/client/CameraBoot.client.luau` read `PlayerScripts.Weapon` with `FindFirstChild` on the line
   after it read `PlayerScripts.Camera` with `WaitForChild`. `PlayerScripts` is replicated, so on a
   boot where `Weapon` had not arrived yet the entire wiring block was skipped **for the session**:
   no aim source, no muzzle provider, no break source, and no `Viewmodel.setSource` -- which draws
   **no gun at all, for ever**, while the Tool sits correctly in the character. Verify:
   `src/client/CameraBoot.client.luau`, `WEAPON_WAIT_SECONDS`.
2. **MEASURED, 4 FAILURES IN 10 FRESH PLAYS.** A failing trace line reads
   `frames=465 parented=false fp=true/true src=false rebuilds=0 tool=HAND(Shotgun,handle=true,Part)`
   -- the camera running at 465 frames, first person on, the gun in the character with its Handle,
   and `Viewmodel.getSource()` nil. **After the fix: 8 of 8 clean**, every one reading
   `parented=true src=true`. That is why nobody could reproduce it on demand: it is a replication
   race, not a code path.
3. **The wait is BOUNDED and it SAYS SO.** `WaitForChild("Weapon", 10)`, and a `warn` naming the
   consequence if it times out -- so the case the file's own header describes, a place with no weapon
   in it, still boots a working camera and is never silently gunless.
4. **THE SECOND WINDOW: the gun was rebuilt with meshes this client had not downloaded.**
   `Camera.Viewmodel.buildNewGun` took model B's published `MeshPart` the moment the server published
   it and dropped the measured box beside it -- and a `MeshPart` whose mesh has not been fetched
   renders as nothing. **Measured:** the gun was built from boxes at 2.050 s with 3 of its 5 parts on
   screen; the server published at 2.7 s; the rebuild swapped both hinge groups at 2.942 s and from
   there to 3.332 s the whole gun on screen was the **bead** -- `VISIBLE=1`. 390 ms on this machine,
   whose content cache was warm.
5. **The rule that closed it reads the engine, it does not guess.** `Viewmodel.meshReady` asks
   `ContentProvider:GetAssetFetchStatus`; `Success` is the only ready answer, a status it cannot read
   answers ready (a guard that failed closed would ship boxes to everyone), and a `None` -- nobody has
   asked -- makes it ask, once per id, with a spawned `PreloadAsync`. That request is **required**, not
   an optimisation: a template parked in `ReplicatedStorage` is never rendered, so without it the
   status would read `None` for ever and the gun would wear boxes all session.
6. **The mesh replaces its box IN PLACE, through the path that already existed.** `builtReady` sits
   beside `builtMeshes` and the staleness check compares both, so a download landing marks the gun
   stale exactly as the folder appearing already did. **Measured under a slow condition** (a temporary
   8 s hold on `meshReady`, reverted): the gun wore its boxes from 2.396 s to 8.673 s with
   `VISIBLE` 3 then 5, and swapped to the meshes at 8.673 s with no frame below 3. Before the fix the
   same moment read `VISIBLE=1`.
7. **Readiness is sticky once a mesh has arrived, and the reason is measured.** The frame after the
   rebuild, both groups read `Loading` again for ~250 ms and then `Success`: a fresh clone re-asks for
   content the client already has, so the status describes a REQUEST, not the cache. Without `arrived`
   the gun went mesh -> box -> mesh in a quarter of a second. Verify: `arrived` in
   `src/client/Camera/Viewmodel.luau`.
8. **A measured 208 ms of empty hands per spawn, removed.** The viewmodel's source lookup was
   throttled to 0.25 s even with nothing in hand, so the Tool reached the character up to a quarter of
   a second before the viewmodel noticed. It is now per frame **only while there is no handle** -- one
   `FindFirstChildOfClass` on the local character -- and unchanged at 0.25 s once there is. The
   staleness check stays on the quarter second, because it walks a folder and asks for a status per
   piece.
9. **One assertion per window, in `tests/client/camera_client.spec.luau`.** "has its sources wired by
   the composition root" fails in the exact state claim 1 describes -- and it had to be added because
   **the bug PASSED every case in that file**: the aim-path case reads the source to decide whether
   this client has a gun, so a source that was never installed reads as "no handle, no viewmodel",
   which the spec accepts. "never wears a mesh this client has not downloaded" drives both answers of
   `meshReady`, asserts every mesh piece in `Gun.pieces` carries a fallback box to draw instead, and
   asserts the gun on screen holds no mesh it cannot draw.
10. **Two frames inspected (rule 5).** `.screenshots/t133-spawn-2p2.png`: 2.2 s after Play in the
    Forest Test, the shotgun in frame with both gloves, the compass and `SLUG 24`.
    `.screenshots/t133-fallback-4p0.png`: the same spawn under the slow condition -- the measured
    boxes, a plain dark gun with its wooden frame block and both gloves. **A gun, not a hole**, which
    is the Director's fourth question answered: the fallback parts really are visible.

## What could not be verified

- **The second window's LENGTH on a cold client is not measured, only its existence and mechanism.**
  I could not make the real content fetch slow: `MeshPart.MeshId` cannot be written from a script, and
  I would not clear Studio's HTTP cache with two of Karen's Studios open. What is measured is the
  warm-cache window (390 ms, `VISIBLE=1`) and that the fixed build is independent of how long the
  download takes (the 8 s hold above). The claim that an unfetched `MeshPart` draws nothing is the
  Director's own brief and is consistent with every trace here; I did not photograph that frame,
  because it is 390 ms wide and the capture cannot be timed into it.
- **Standing rule A was run in the Forest Test**, 85 s: Tool in the CHARACTER at 15 s and at the end
  (`tool=true backpack=false` both times), the viewmodel in `CurrentCamera` with 5 drawn parts and 4
  meshes at both samples, **0 fault lines in 24**, and four wave lines released. The same sample's
  `source=`/`parented=` fields read false and are **not** evidence of anything: a `require` from the
  StudioMCP thread returns its own instance of the module with empty state, which is why they
  contradict `viewmodel=true` in the same line.
- **Only the FIRST-PERSON gun is fixed for the mesh window.** The world Tool that other players see
  still loses its parts the instant the server welds the mesh on (`Hardware.upgrade`), and the server
  cannot know what a given client has downloaded. Queued as a TASKS row rather than guessed at here.

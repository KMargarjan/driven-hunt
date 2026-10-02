# Task 107 — model B was assembled backwards: the stock sat at the muzzle end

Task: 107
Round: 1
Base: `main` (`65d1c14`)
Code commit: `5455d0a5c73c504915f82b890d5ad10192409a90`

```
[harness] PASS: 32/32 checks @ 5455d0a5c73c504915f82b890d5ad10192409a90 (clean tree)
[harness2] PASS: 34/34 checks @ 5455d0a5c73c504915f82b890d5ad10192409a90 (clean tree)
```

`test2` was run because `src/serverstorage/Assets/init.luau` is outside `WEAPON_VIEWMODEL_PATHS`:
the diff is otherwise all viewmodel, and that one file is a two-line comment that contradicted the
value it describes. My call, and the cost of it is this run.

## Claims

1. **It is neither the splitter nor the welds.** `tools/gltf_split.py` writes every group with the
   muzzle at the FILE's +X (`to_file`, selftested), and `CFrame.Angles(0, +90°, 0)` takes +X to this
   gun's −Z. Both halves are true. The model comes back from Blender's glTF import, its FBX export
   and Roblox's FBX import **reversed along its own long axis**, so the quarter turn pointed the BUTT
   down the gun. Task 105 inherited the assumption from Karen's gun's rows and never looked at which
   end was which. Verify: `Gun`'s `MESH_FILE_TURN_DEG` / `MESH_IMPORT_TURN_DEG` block.
2. **One measured constant, used twice.** `Gun.MESH_IMPORT_TURN_DEG = 180` composes into
   `MESH_ROTATION_DEG` (270) and `SHELL_ROTATION_DEG`. The SHELL was equally backwards — a seated
   shell pointed its brass head up the barrel — so `Camera.Viewmodel.makeShell` turns the mesh it
   clones by the same constant, and the quarter turn stays at the one site that places every shell,
   drawn or uploaded.
3. **The spec is the ROUND TRIP, which is the case task 105 did not have.** `Gun.MESH_MUZZLE_AXIS` is
   where the muzzle points in the MeshPart's own axes after the import; composed with
   `MESH_ROTATION_DEG` it must give the gun's muzzle direction. Flip either sign and it fails. Ran:
   `task107 the mesh's muzzle axis -1, 0, 0 turns by 270 to (-0.000, 0.000, -1.000)`.
4. **The Director's invariant, stated as geometry.** `gun.spec` "puts the stock and the action BEHIND
   the breech": the barrel group reaches the muzzle and the frame group does not, the frame group's
   centre is behind the breech, the butt is at the Handle's +Z half, and the hinge is ahead of the
   breech, inside the frame group and below the bore line. Ran: `task107 muzzle -2.200, barrel group
   front -2.200, frame front 0.292, frame centre 1.246, breech 0.517`.
5. **The flag-OFF build is untouched.** Nothing outside `Gun`, `Viewmodel.makeShell`'s mesh branch and
   the manifest comment changed, and all three are reached only with `NEW_GUN` on. Task 106's
   flag-OFF guard still passes.

## What I could not verify

- **Whether the import HALF-TURNS the model or MIRRORS it** cannot be told apart on a gun this close
  to symmetric. A half turn is what the correction applies; that is written down in `Gun`.
- **The mesh shell's new turn was not seen seated**: shells are drawn only during a reload, and the
  uploads do not land before the harness's client specs run. The gun's own turn was looked at.

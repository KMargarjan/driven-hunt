# Task 107 — model B was assembled backwards: the stock sat at the muzzle end

Task: 107
Round: 2
Base: `main` (`65d1c14`)
Code commit: `5455d0a5c73c504915f82b890d5ad10192409a90`

```
[harness] PASS: 32/32 checks @ 5455d0a5c73c504915f82b890d5ad10192409a90 (clean tree)
[harness2] PASS: 34/34 checks @ 5455d0a5c73c504915f82b890d5ad10192409a90 (clean tree)
```

Round 1's finding was right and nothing in `src/`, `tests/` or `tools/` changed to answer it: the one
claim that makes this change right is visual, and no after-frame was described. Both are below.
Round 1's notes are queued as `TASKS.md` row 107a.

`test2` was required because `src/serverstorage/Assets/init.luau` is under `TWO_PLAYER_PATHS` and
outside `WEAPON_VIEWMODEL_PATHS` — `tools/agents.py` would have refused the review without the line.
Round 1 called it "my call", which is wrong.

## Claims

1. **THE PROOF OF DIRECTION IS ON SCREEN, AND THE SPEC IS SELF-CONSISTENT ONLY.** `gun.spec`'s new
   case composes `Gun.MESH_MUZZLE_AXIS` with `Gun.MESH_ROTATION_DEG` and requires the gun's muzzle
   direction — so `(-1, 0, 0)` with 270 and `(+1, 0, 0)` with 90 pass equally. It catches a LATER
   drift in either number; it cannot tell you which pair is right. Only the frames can, and
   `tools/gltf_split.py` cannot help: its `backTowardNode` disambiguates the file's own sign, so the
   file really is muzzle-at-+X and the pre-fix 90 was arithmetically right. The 180 rests entirely on
   what follows.
2. **CARRY, BEFORE → AFTER.** `.screenshots/20261002T121400Z-pose-carry.png`: the walnut stock and
   the silver action are unmistakable at the FAR upper-left end of the barrels, where `compare` puts
   the Muzzle landmark, and the near end by the gloves is bare.
   `.screenshots/20261002T121752Z-pose-carry.png` (after): the two blued barrels run diagonally from
   the bottom-centre up to the upper-left edge and END THERE AS A BARE TUBE TIP — no stock, no action,
   no walnut at the far end. The gloves are at the lower left with the olive sleeve, and a sliver of
   walnut shows below the left glove at the bottom edge. The wood is at the hands; the muzzle is away.
3. **AIM, BEFORE → AFTER.** `.screenshots/20261002T121329Z-pose-aim.png` (eye relief pushed to 5.2 so
   there is room to see): the eye looks straight into TWO OPEN MUZZLES a foot away, with the gun
   running off behind them. `.screenshots/20261002T121808Z-pose-aim.png` (after, shipped 3.65), from
   the bottom up the centre: a brown glove at the bottom edge, then the WALNUT STOCK with its
   chequered grip filling the lower centre, then the dark action with the trigger-guard loop and the
   top strap, then the two round breech ends, then the barrels foreshortened away to a dark
   knuckle/bead at about 50 % across and 50 % down. **No open bore faces the camera anywhere in the
   frame.**
4. **One measured constant, used twice.** `Gun.MESH_IMPORT_TURN_DEG = 180` composes with the file's
   own quarter turn into `MESH_ROTATION_DEG` (270) and `SHELL_ROTATION_DEG`. The SHELL comes through
   the same import and was equally backwards — its brass head pointed up the barrel — so
   `Camera.Viewmodel.makeShell` turns the mesh it clones by the same constant.
5. **The flag-OFF build is untouched.** The diff is `Gun`, `Viewmodel.makeShell`'s mesh branch,
   `tests/server/gun.spec.luau` and a two-line comment in the manifest; the first two are reached
   only with `NEW_GUN` on. Task 106's flag-OFF guard still passes.

## What I could not verify

- **Whether the import HALF-TURNS the model or MIRRORS it** — indistinguishable on a gun this close
  to symmetric. A half turn is what the correction applies, and `Gun` says so.
- **The shell's new turn was not seen seated.** Shells draw only during a reload and the uploads do
  not land before the client specs run; `gun_client.spec` asserts the bore line and the back-off,
  neither of which moves with the turn. Queued as 107a.
- **The two round shapes above the action in the aimed frame** are read as the barrel pair's breech
  ends seen from behind. What is certain is that the walnut and the action are NEARER the eye than
  they are, which only happens on a gun the right way round.

# Task 76 — the early joiner gets her own shotgun

Task: 76
Round: 1
Base: `main` (`25da32d`)
Code commit: `9100aae464a19c23cc1ea79c126d927cee17fc3e`

```
[harness]  PASS: 30/30 checks @ 9100aae464a19c23cc1ea79c126d927cee17fc3e (clean tree)
[harness2] PASS: 32/32 checks @ 9100aae464a19c23cc1ea79c126d927cee17fc3e (clean tree)
```

Both are the Director's runs at this branch's head. `src/` and `tests/client/` both changed, so
`test2` is part of the gate. The head is a paperwork commit — at or after the last commit that
touched `src/` or `tests/` (`80380a7`), with only `TASKS.md` and this file between them — which only
makes the bound stricter. My own clean-tree `[harness] PASS: 30/30 @ 80380a7` covers the same code
and reported `[tests:server] PASS: 408 passed` (404 before: four new), client 86 (85 before: one
new).

**The defect (row 75a(h)).** `WeaponBoot` starts the weapon system BEFORE the preload — Task 74
review round 1 asked for exactly that, because a stalled `LoadAsset` must not mean a gunless player —
and the preload measured 1227 ms. Nothing rebuilt a Tool granted before it, so a player who spawned
in the server's first second kept Task 71's parts gun for as long as they held it. In Studio Play a
join takes well under a second, so Karen has never held her own uploaded shotgun.

**A second defect, found by the fix.** Commit `069e430` passed one harness run and failed the next.
`WeaponBoot` wired the template provider AFTER `preload`, and `preload` waits for a load running in
another thread — so the template is cached a frame or more before `preload` returns, and through that
frame `Loader.template` answered with a mesh while `Hardware` had no way to ask for one. The harness
plans its specs inside that window about half the time, and `assets_seam.spec` captured its "live"
provider at plan time and put that value back after every case: `nil`. A server with no provider
builds the parts gun for every grant and cannot upgrade one either — silently, for the session.

**What changed.** `src/server/Weapon/Hardware.luau` (`upgrade`, `upgradeAll`, `wearsMesh`,
`addParts`, `removeParts`, `MODEL_NAME`), `src/server/Weapon/init.luau` (the arming sweep also
upgrades; `meshUpgrades`, `meshUpgradeFails`), `src/server/WeaponBoot.server.luau` (the seam is wired
before the network; one `upgradeAll` when the preload returns),
`src/client/Camera/Viewmodel.luau` (the clone rebuilds when the source Handle's children change),
`tests/server/assets_seam.spec.luau`, `tests/client/camera_client.spec.luau`, `TASKS.md` rows 76/76a.

## Claims

1. **A gun built before the template arrives gets the mesh, exactly once.** `assets_seam.spec`,
   "upgrades a tool built before the template arrived, exactly once": a provider that answers `nil`
   then a template. Asserts the `Model` child, its size from the manifest row, the `ModelWeld`, that
   `BarrelLeft`/`Stock`/`Trigger` and their welds are gone, and that a second and third `upgrade`
   return `false` with one `Model` child and the SAME Instance.
2. **Nothing the rest of the system stands on moves.** Same case: `Handle.Size` is `HANDLE_SIZE`,
   `Tool.Grip` is `GRIP`, `Handle.CanQuery` is still true, the `Muzzle` is the SAME Attachment
   object, and `Hardware.muzzlePosition` still answers. No weapon state is read or written by
   `Hardware.upgrade` — read it: it touches the Handle's children and nothing else.
3. **A template that never arrives changes nothing.** "leaves the fallback alone when the template
   never arrives": `upgrade` returns `false` twice and the whole parts gun is still there. The mesh
   goes on BEFORE the parts come off (`Hardware.upgrade`), so a failed upgrade cannot leave a player
   holding an empty Handle.
4. **It is safe on a Tool it does not understand.** "refuses a Tool that has no Handle, rather than
   erroring in a sweep" — the sweep calls this every 2 s for every carried Tool.
5. **The player's path, live.** "leaves no carried gun wearing the fallback once the mesh has
   loaded" runs with the LIVE provider and no fake. Its note in the `80380a7` run reads
   `1 carried gun(s), 0 wearing the mesh, live template=yes, provider answers=yes` — the defect,
   reproduced on the harness's own player — and the case passes because `upgradeAll` fixes it. The
   count varies per run (a player who joins after the preload is handed the mesh outright), which is
   why the note prints what it saw rather than the case asserting a number.
6. **The ADS viewmodel follows from its one source.** `Camera.Viewmodel` rebuilt only when the
   source part changed IDENTITY, which an in-place upgrade never does. It now watches the source's
   `ChildAdded`/`ChildRemoved`; `camera_client.spec`, "rebuilds the clone when the source Handle's
   children change", drives the same mutation the server makes and asserts a new clone carrying
   `Model` and not `BarrelLeft`. `Viewmodel.clear` disconnects the watchers.
7. **Two callers, and the second is the net.** `WeaponBoot` upgrades once when `preload` returns;
   `Weapon`'s existing 2 s arming sweep repeats it, because a load that timed out is late rather
   than lost (`Loader` adopts it) and there is no signal for that arrival. `Hardware.upgradeAll`
   never yields, so it cannot interleave a grant.
8. **The seam is wired before anything touches the network** (`WeaponBoot`), and
   `assets_seam.spec` now borrows the provider at the moment of the borrow, not at plan time, and
   asserts `Hardware.getTemplateProvider()` is still ok after every case has run. Both halves of the
   race above.
9. **Four mutations applied, run and restored.** (a) `Hardware.upgrade` returns `false` at once →
   two cases fail, and the live note read `0 wearing the mesh` with the provider wired: the defect
   itself. (b) the idempotence guard removed → the "exactly once" assertion fails. (c) `removeParts`
   skipped → "Expected nil, got BarrelLeft". (d) the Viewmodel `stale` check removed →
   `camera_client.spec` fails on the same clone coming back.
10. **`withLoader` unwires the provider too.** The sweep now asks for a template every 2 s and the
    slow-load case yields 11 s, so without this the spec's fake could be welded onto a live player's
    gun for the session. This is also why `sweep upgrades` is often 0 in the note — said in the spec,
    beside `sweep failures`, which is what would mean the sweep is broken.

## What I could not verify

- **`test2` is the Director's run, not mine**, and it is pasted above. A second player exercises no
  path this task adds that one does not; the gate wants it because `src/` and `tests/client/`
  changed.
- **The screenshots are of a gun that had already been upgraded**, not of one changing under the
  camera: I cannot make a Play session join at a chosen millisecond. The three Play captures of the
  `80380a7` run show the MESH gun in ADS and in hand; the same run's spec note is what says the gun
  reached that state by being upgraded.
- **Whether a player notices the swap mid-reload or mid-aim.** Argued from what the code touches and
  asserted on the Instances (claim 2); nobody has held a gun while it changed.
- **The gun reads very dark in this place's daylight** — near-black with a blue cast, and a mottled
  light blue-grey muzzle face (`.screenshots/20260927T015658Z-task76-early-join-1.png`). That is Task
  75's new maps, not this task's doing, and it is Karen's eye (row 75a(a), 74a(b)). Queued as 76a(a).

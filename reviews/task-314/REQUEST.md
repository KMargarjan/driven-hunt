# Task 314 -- `main` was red in DEV: the viewmodel's handle cache froze on a backwards clock

Task: 314
Round: 1
Base: cc058bf49f6072553df07d7e33b282ca1ec72336 (main)
Code commit: 4f2755986293e3a63d803c6c7065079f4f5654ea

`[harness] PASS: 34/34 checks @ 4f2755986293e3a63d803c6c7065079f4f5654ea (clean tree) scope=all`

Two files: `src/client/Camera/Viewmodel.luau` and `tests/client/camera_client.spec.luau`.
No DEV place edit was made, and none is needed.

## What was wrong

`rifle_client.spec` equips the Rifle and waits for `Camera.Viewmodel.weaponId()`; it kept
answering `"shotgun"`. Not a code regression: `git diff d33c318e..cc058bf4 -- src tests` is
EMPTY, and `d33c318e` is where task 306m recorded `PASS: 34/34`.

`Viewmodel.update` refreshes `cachedHandle` on a 0.25 s throttle, `now - lastSourceCheck > 0.25`.
`gun_client.spec`'s `withSeatedShells` drives `update` on a fake clock of `4000.0`, which writes
`lastSourceCheck = 4000`. `os.clock()` is seconds since the STUDIO PROCESS started: measured in
DEV at `rifle_client` time it read **3512**, so the elapsed time was **-488 s**, the throttle
could never expire again, and the cached handle stayed the shotgun's for the rest of the session.
On every green run Studio had been open past 4000 s; Karen restarted it this morning.

## The fix (root, in the owner)

1. `Viewmodel.update`: `sourceDue = sinceCheck > 0.25 or sinceCheck < 0` -- a negative elapsed
   time is a DUE throttle, not a frozen one. Used for the handle refresh and for `lastSourceCheck`'s
   own write, so neither can be frozen by a timestamp from another clock.
2. `Viewmodel.setClock`: drops `lastSourceCheck`, exactly as `setSource` already drops
   `cachedHandle` ("a cache that outlives the source it came from is a stale answer whoever asks").

## Claims

1. **The cause is measured, not inferred.** A diagnostic run at `cc058bf4` printed, inside
   `rifle_client`'s wait: `src=set srcHandle=Workspace.Alhamdulilah824.Rifle.Handle clock=3512.460
   os=3512.460 rebuilds=51 cur=DrivenHuntViewmodel`, at i=1, 10 and 60, with
   `weaponId()` = `shotgun` throughout. So the Rifle WAS in the character, the live source returned
   its Handle, the clock was live and advanced 2 s, and the cache still never moved.
   Verify: the numbers are quoted here; the diagnostic was not committed (it was a dirty-tree run).
2. **`4000.0` is the poisoning value and it is in the tree.** `tests/client/gun_client.spec.luau`,
   `withSeatedShells`: `local fake = 4000.0` then `Camera.Viewmodel.setClock(...)` and
   `Camera.Viewmodel.update(...)`. Verify: read that function.
3. **FAIL FIRST, with the live defect's own message.** With `or sinceCheck < 0` removed from
   `sourceDue` (nothing else changed), the new case failed
   `camera_client.spec:2858 Expected value "rifle" (string), got "shotgun" (string) instead`
   and `rifle_client.spec:747` failed with it -- `FAIL: 30/34 ... (DIRTY TREE (2 paths))`.
   Verify: delete `or sinceCheck < 0` and run; the comment in the case names that exact edit.
4. **The new case bites the throttle, not the seam.** `setClock` is NOT called between the two
   `update`s; the clock VALUE drops. So claim 3's failure cannot be credited to the `setClock`
   reset. Verify: read the case in `camera_client.spec` ("the source throttle against a clock that
   went backwards").
5. **The case cannot be answered by the live camera loop.** There is no yield between the clock
   drop and the read. Verify: read the case.
6. **The case restores everything it borrowed** -- `setClock(nil)`, `setSource(liveSource)`,
   `clear()`, both Tools destroyed -- inside the `pcall` discipline this file already uses, so a
   red case cannot change what later frames of the session draw. Verify: read the case's tail.
7. **The full suite is green at the code commit**, one player, whole suite:
   `[harness] PASS: 34/34 checks @ 4f2755986293e3a63d803c6c7065079f4f5654ea (clean tree) scope=all`,
   and that run's note reads `rifle kick: drawn=rifle applied view 8.40 deg / gun 28.50 deg /
   back 1.020 studs` -- the equip is seen again. Verify: the line above.
8. **No DEV place state was touched and the spec no longer depends on any.** The fix is two edits
   in git; nothing was published, no Workspace/Terrain/attribute edit was made. Verify:
   `git diff cc058bf4..4f275598 --name-only` is exactly those two files.
9. **Two players: N/A.** Neither file is in `TWO_PLAYER_PATHS` (`src/client/Camera/` is not listed;
   the listed client specs are `match_client`, `outfit_client`, `zz_tie_to_a_tree`, `Role.luau`).
   Verify: read `TWO_PLAYER_PATHS` in `tools/agents.py`.
10. **Lint, format and both selftests pass**: `selene src`, `selene --config tests/selene.toml
    tests`, `stylua --check src tests`, `python tools/studio_mcp.py selftest`,
    `python tools/agents.py selftest` -- all clean (rule G). No new spec FILE, so `SCOPE_SPECS`
    is unchanged.

## What I could not verify

- **Studio's version before this morning's update.** Not recorded anywhere on this PC, so the
  update is not ruled out as a CONTRIBUTING cause of the timing shift. It does not matter to the
  fix: the measured mechanism is arithmetic on two numbers, and the new case reproduces it with no
  reference to Studio's uptime or version.
- **That 4000.0 is the only future-clock constant that could ever poison it.** The guard makes any
  such value harmless rather than auditing them, which is why the fix is in the reader.

# Task 294: the guns are never grey rectangles

Task: 294
Round: 2
Base: bb2ae06e (main, #266 merged)
Code commit: eb706cb1d54bd1c0c73b36a85715b5c9eb5dd598

Karen, 2026-10-27, playing her build: *"weapons loaded at first in game is rectangles"*.

```
[harness] PASS: 34/34 checks @ eb706cb1d54bd1c0c73b36a85715b5c9eb5dd598 (clean tree) scope=all
```

That run's own notes are this task's measurement:

```
  note   [client] task294 hold case: 2 mesh piece(s), 2 fabricated
  note   [client] task294 held: 0 visible; past the bound: 3 visible
  note   [client] task294 warm asked for 16 avatar mesh id(s), once each
  note   [client] task294 the lobby sweep handed over 4 weapon folder(s)
```

`test2` N/A: no `TWO_PLAYER_PATHS` path is touched (the viewmodel, the hud and the client weapon
owner; the Director's 2026-10-03 list).

## PLAN

- **(a) REAL LIFE / the engine.** A `MeshPart` whose mesh has not been downloaded is drawn as its
  plain box; `ContentProvider:GetAssetFetchStatus` is the only signal that says it has
  ([docs](https://create.roblox.com/docs/reference/engine/classes/ContentProvider#GetAssetFetchStatus)),
  and `PreloadAsync` is what turns "published" into "downloaded" for a template parked in
  `ReplicatedStorage`, which is never rendered and so never fetches itself.
- **(b) MEASURED NOW.** The Director's probe `<runs-dir>/gun-load.luau` in Karen's Forest Test with a
  WARM Studio cache: at the first shotgun in hand (t=60.7 s) every gun MeshPart reads
  `fetch=Success`, queue 0; the rifle's first draw (t=88.8 s) too. So with a warm cache there are no
  rectangles, and the defect is a COLD client. **I could not read a cold cache myself** — clearing it
  needs a Studio restart, which is Karen's click — so the cold case is reproduced through the SEAM the
  dispatch offered, and bounded by the fail-first below.
- **(c) TARGET.** Zero frames of a gun drawn as boxes on a cold start, bounded: after
  `Viewmodel.HOLD_SECONDS = 4` the fallback is shown anyway (an endless hold is a gunless player, and
  `WeaponBoot.server`'s ordering rule exists precisely to prevent that).
- **(d) LEVER.** `src/client/Camera/Viewmodel.luau`, `buildNewGun`'s piece loop — the one writer of
  what the first-person gun is made of: `made_.Transparency = if held then 1 else piece.transparency or 0`,
  and `mesh ~= nil and not Viewmodel.meshReady(mesh)` is what decides a piece is waiting.
- **(e) HOW MEASURED AFTER.** `tests/client/asset_fetch.spec.luau` in a real client, plus the
  fail-first below (the same case, with the producing line neutered).

## FAIL FIRST — the quantity that moved

With `Viewmodel.holdPieces` neutered to `return false` (main's behaviour: draw the boxes), the same
spec in the same Studio:

```
  failed [client] asset_fetch.spec:146 Expected value "true" (boolean), got "false" (boolean) instead
[harness] FAIL: 32/34 checks @ d85a8a1c55583d4231e4b5d6a5ebf9e95bf2d5fa (DIRTY TREE (1 paths) - NOT valid evidence) scope=all
```

## WHAT CHANGED

1. **`src/shared/AssetFetch/init.luau` (new): ONE owner** of "has this id landed on this client, and
   may we ask again" — the rule, the per-id cool-down and the counters task 244 built for the shop
   case. `Hud.ShopDisplay` and `Camera.Viewmodel` both go through it now; the gun's own copy had
   **no cool-down** (`requested[id]` was set once for ever, so a FAILED fetch left the fallback up
   for the session — and nothing throttled a re-ask either).
2. **`Camera.Viewmodel`: the first-show hold.** A build missing any mesh builds its fallback boxes at
   `Transparency = 1` for up to `HOLD_SECONDS`; the bound running out marks the gun stale, so the
   honest fallback still arrives.
3. **`Weapon` (client): asks early.** `Weapon.warmWeapons` warms **every** row of `Weapons.ROWS` from
   the lobby on its own thread, bounded by `WARM_TRIES`.

## CLAIMS

1. **The gate asks once and not four times a second.** `asset_fetch.spec`, "asks once for a mesh in
   flight": 20 reads, one ask. (L-031: task 244's own self-caught regression is kept, not re-shipped.)
2. **A FAILED fetch is re-asked exactly once the cool-down runs out** — `AssetFetch.RETRY_SECONDS -
   0.01` asks nothing, `+0.01` asks: "asks again for a fetch the engine CALLED failed".
3. **Success is sticky**: a fresh clone reading `Loading` again does not take the gun off the screen.
4. **A status that cannot be read answers READY** — a guard that failed closed would ship boxes to
   everybody for ever.
5. **One rule, two doors**: `ShopDisplay.RETRY_SECONDS == AssetFetch.RETRY_SECONDS` and
   `ShopDisplay.nextAsk` is `AssetFetch.nextAsk`. Verify: `grep -n AssetFetch src/client/Hud/ShopDisplay.luau`.
6. **The hold withholds ON THE DRAWN GUN** (round 1, finding 2). "DRAWS NOTHING A PLAYER CAN SEE":
   the shotgun's mesh templates are FABRICATED (`semiauto_client.spec`'s own reason -- DEV has no
   upload; a `MeshPart` with no mesh id IS the not-ready state), a real `buildNewGun` runs through
   `Viewmodel.update`, and the case reads the INSTANCES: the gun is built (descendants > 2),
   `holding() == true`, `stats().meshesHeld > 0`, and **0 of its pieces are visible**; then with the
   viewmodel clock stepped past `HOLD_SECONDS`, the same build draws **3**. Delete the `if held then 1`
   and the first number becomes 3. The pure rule is still driven beside it, production-reachable form
   first (round 1 note).
7. **A held piece is still BUILT.** Three gate runs proved the alternative wrong: dropping the pieces
   left `semiauto_client.spec:93` with no drawn bolt to read (it failed in both runs with the hold
   active and PASSED in the neutered run, so it was **mine**, not the known flake of TASKS 285). The
   final run is 34/34 with that spec green.
8. **The ask-early half really asks** (round 1, finding 1), in two halves that each go red alone:
   "ASKS THE ENGINE for every mesh it is handed" drives `AssetFetch.warm` against REAL mesh ids that
   exist in any client (the R15 avatar: 16 of them), asserting each was asked for **exactly once**
   across two sweeps; and "hands AssetFetch EVERY weapon folder that has replicated" spies on
   `AssetFetch.warm` to assert WHICH holders the lobby sweep passes -- all 4 weapon folders, one call,
   and nothing that is not a weapon's folder. It cannot pass on an empty sweep: with no folder present
   one is fabricated, so `folders > 0` always.
9. **`tests/client/asset_fetch.spec.luau` is in a scope** (`viewmodel`), and `src/shared/AssetFetch/`
   maps to it: `python tools/studio_mcp.py selftest` and `python tools/agents.py selftest` both pass.
10. **Owners unchanged**: no new writer of `LocalTransparencyModifier` (that is `Camera.Rig`'s; this
    writes the viewmodel clone's own `Transparency`, which `buildNewGun` already owned), and no
    server change at all.

## THE ROUND-1 NOTES

Taken: the status seam now DELEGATES for ids the case does not own (it was answering nil for the live
gun four times a second, and consuming its hold); `Viewmodel.forgetHold` makes the once-per-session
spend explicit; `HOLD_SECONDS = 0` is stated as the kill switch; the header states the window the hold
does NOT cover (before the server publishes -- task 133's 2.050-2.7 s -- `waiting` is 0 and the boxes
are drawn, so PLAN (c) is "zero frames once the templates exist", not "zero frames"); the fail-first
names the production-reachable line. Queued, not done: `docs/design/camera.md` does not yet describe
the "built, not shown" state (rule 4). The `32/34` of the fail-first is 2 checks because the client
report fails twice over -- `status PASS` and the pass/fail count -- which is how every client failure
in this repo reads; there was one failing case.

## WHAT I COULD NOT VERIFY

- **A real COLD start.** Clearing the content cache needs a Studio restart (Karen's click), and
  Karen's Forest Test syncs from a separate copy at `:34873`, so my branch is not in her place. The
  cold case is reproduced through the seam only. **The first gun of a fresh Forest Test session is
  the Director's check** (as the dispatch assigns it) and is the only proof that Karen's sentence is
  now false on screen.
- **No frame of the held state.** With a warm DEV cache every mesh reads `Success`, so the hold does
  not fire there and there is nothing to photograph. `NOT OBTAINABLE` in DEV; the Director's cold
  session is where it can be seen.
- A gun whose meshes land one at a time shows the ready pieces and hides the waiting ones for
  ≤4 s — real metal and a gap, never a box. Not photographed, for the reason above.

## ANSWERED (the dispatch's CHECKED flags)

- **ANSWERED: L-031/L-105** one shared preload + fetch gate (`src/shared/AssetFetch`) used by the shop
  case and the gun, and task 244's per-id COOL-DOWN came with it rather than being re-invented — it
  is what claim 2 drives, and the gun had none before.
- **ANSWERED: L-095** the dispatch's literal route is what the Director will run; I used the DEV gate
  and the seam because Karen's place syncs from another copy (see "what I could not verify").
- **ANSWERED: L-136** the failing line I hit (`semiauto_client.spec:93`) was NOT called the flake: the
  three runs beside each other show it following MY hold, and the final run has it green (claim 7).
- **ANSWERED: L-028** the fail-first is above, with the quantity bounded: the hold case goes red with
  the producing line neutered, at a named commit, in the same Studio.

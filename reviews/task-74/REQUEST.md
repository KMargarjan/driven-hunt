# Task 74 — M2.7a: the id → Instance seam, and Karen's shotgun is the gun

Task: 74
Round: 3
Base: `main` (`f3f6a49`)
Code commit: `f73493fe2111dccf1a746a7d5f2592d45aef074e`

```
[harness]  PASS: 30/30 checks @ f73493fe2111dccf1a746a7d5f2592d45aef074e (clean tree)
[harness2] PASS: 32/32 checks @ f73493fe2111dccf1a746a7d5f2592d45aef074e (clean tree)
```

Both are the Director's runs at this branch's head, and **`test2` is evidence rather than a formality
here**: this touches `src/` and `tests/client/`, and the viewmodel work only has a second client to be
seen on. The head is a paperwork commit — at or after the last commit that touched `src/` or `tests/`
(`ae7d0f2`), with only this file and `TASKS.md` row 74 between them. My own clean-tree
`[harness] PASS: 30/30 @ ae7d0f2` covers the same code, and reported
`[tests:server] PASS: 402 passed, 0 failed, 0 skipped, 0 errors, 24 spec files` with client 85 passed.

**Round 2's single finding was right, and it was right for the second time.** The spec was still
destroying the running server's preloaded template, and the check I had added to catch that could not
fail. Both halves are fixed below, and the fix is structural rather than another ordering rule.

**What changed since round 2.** `src/serverstorage/Assets/Loader.luau` (all mutable state in one
injectable value; `PRELOAD_BUDGET_S` 20 → the design's 15) and `tests/server/assets_seam.spec.luau`
(a scratch state per case, two new cases, the timeout fake no longer spins); `GAME_DESIGN.md`'s two
owner rows say **BUILT**. **402 server specs** (390 before Task 74: twelve new), 85 client (one new).

## Claims

1. **THE FIX IS THAT THE LOADER'S STATE IS INJECTABLE, so the spec cannot name the live template.**
   Round 1 cleared the loader while it held the live mesh. Round 2 nominated a throwaway cache
   *folder* first and believed that was enough — it was not: `clear()` walked one **module-level
   `templates` table** and destroyed every Instance in it, the live one included, whatever folder the
   spec had nominated. The guard was on the container and the defect was in the table. There is no
   module-level table any more: `Loader.newState` / `getState` / `setState` hold `templates`,
   `reports`, `lastReasons`, `counters`, the cache parent, the injected insert and the preload
   deadline, and `withLoader` runs `Loader.setState(Loader.newState())` first. `clear()` walks *this*
   state's templates and destroys the cache folder only when **this state created it**
   (`state.createdCache`), so "destroys only what it created" is now a fact about the data rather
   than a comment.

2. **The check that catches it can fail, and it is network-independent.** `assets_seam.spec` records
   the live **Instance** — not a boolean, and it repairs nothing — in the file's first case
   (`describe("the live server before any of this")`), and the last case asserts
   `Loader.template(key) == hadTemplate` plus `hadTemplate.Parent ~= nil`, and that the Tool a player
   would be handed **is wearing the mesh**. Round 2's version re-fetched the template over the
   network and reported the damage in a `TestKit.note`, then asserted `wearing or partsGun`, which
   `Hardware.build` satisfies by construction. Run notes: `boot loaded the live template:
   ServerStorage.AssetCache.output_unwrapped` and `the live template survived the specs:
   ServerStorage.AssetCache.output_unwrapped (proxies=2)`.

3. **MUTATION-CHECKED, both ways.** Put round 2's shared state back — `local live =
   Loader.getState()` in `withLoader` — and the run is
   `[tests:server] FAIL: 400 passed, 2 failed, 2 errors`, failing at `assets_seam.spec:321` (the
   isolation case's inner `multi-meshpart` assertion, because the keeper's template was still cached)
   and at `assets_seam.spec:345` (`expect(now).to.equal(hadTemplate)` — *"Expected value
   "output_unwrapped" (userdata), got "nil" (nil)"*, the live template destroyed). Restored, and the
   run above is the restored one.

4. **One case proves the rule with no network and no dependence on boot.**
   `it("cannot reach a template another state holds, with no network in sight")` builds a **keeper**
   state, preloads a fake into its own folder, then runs a whole `withLoader` cycle — a failing load
   and a `clear()` — in a second state, and asserts the keeper still holds **the same Instance**, still
   parented where it was put. It then clears the keeper itself, which is allowed. This is the case
   that would have failed in round 2 whatever the Studio's network was doing, and it is the one I
   should have written instead of an ordering comment.

5. **The first attempt at claim 2 was vacuous, and the run said so.** Recording `hadTemplate` at
   TestEZ **collection** time gave nil on a healthy server: `WeaponBoot` preloads over the network at
   server start and the suite begins a second or two later. The measured evidence is in the mutation
   run I kept — the note read *"no live template existed before these cases"* while the same run's
   later cases proved a template had arrived. The anchor case now waits for boot to **decide**
   (`LOAD_TIMEOUT_S + 2`, the bound boot itself works to) before recording, and asserts nothing about
   whether it loaded — a Studio with no network has nothing to protect, and that is not this file's
   failure.

6. **Boot cannot wait on the network.** `WeaponBoot` calls `Weapon.start()` **before** anything
   touches the network, and `preload` is bounded: `LOAD_TIMEOUT_S = 10` per key, `PRELOAD_BUDGET_S =
   15` for the call — **the design's own numbers** (§12), where round 2 had 20 (review note).
   `LoadAsset` cannot be cancelled, so the load runs in its own thread and the caller stops *waiting*
   at the deadline, reason `timeout`; a late arrival is **adopted** if the key is still empty, into
   **the state the load started in** (round 2's note on `adopt`: a slow fake can no longer park itself
   into the live cache). Verify: `it("gives up on a slow load, says timeout, and adopts it when it
   lands")` — the fake now **returns** after the bound instead of spinning forever, which proves both
   halves and leaves no coroutine running for the rest of the Studio session (round 2 note). Note:
   `loader timeout: gave up after 10.0 s (bound 10 s), adopted the late arrival at 11.1 s`.

7. **Nothing about the Handle changed, so nothing downstream did.** Still `HANDLE_SIZE`, still
   `Tool.Grip`, still the `Muzzle` attachment the server reads for every shot, still the **only part
   of the gun a ray can hit**; the mesh is welded scenery (`CanQuery`/`CanCollide` false, `Massless`
   true). The size is **uniform** — scaled so the length is `HANDLE_SIZE.Z`, not squashed into the
   0.4 × 0.5 envelope (design §6.1's squashed boar) — and `it("keeps the gun's LENGTH and does not
   squash it")` asserts the three axes share one factor. Note: `shotgun mesh: natural 200.0 x 31.3 x
   11.3 -> 4.400 x 0.689 x 0.249 studs (x0.02200)`.

8. **Every failure still ends in a gun**, driven by injection: `insert-failed`, `contains-script`,
   `no-meshpart`, `multi-meshpart`, `aspect`, `no-row` and `timeout`, each with `Loader.template` nil
   and `Hardware.build` drawing Task 71's parts gun. `Hardware.addMesh` returns **false** for a
   template class it cannot scale (destroying its clone and warning once) rather than falling through
   with `return true`, so an unhandled class is the parts gun and not an invisible gun.

9. **The viewmodel keeps the gun's appearance, asserted and photographed.** `camera_client.spec`,
   `it("keeps the appearance of the gun it clones, and still strips everything else")` injects a
   `MeshPart` handle with `SurfaceAppearance`/`Texture`/`Decal`/`Attachment` plus `Weld`/`Sound`/
   `Folder` and asserts the first four survive the clone and the last three do not, on a welded piece
   as well as on the root; it borrows the live source through `Viewmodel.getSource` and puts it back,
   because `setSource(nil)` ends the source rather than restoring it. The ADS screenshot is described
   below.

10. **The owner table now says what is true.** `GAME_DESIGN.md`'s **asset manifest** and **id →
    Instance seam** rows read **BUILT (Task 74, M2.7a)** with the built paths, and say plainly what is
    still outstanding: `MapGen.Props` is its own `LoadAsset` caller until 74a(a), `MapGen.Assets.ROWS`
    is empty so there is exactly one id table (`assets_seam.spec` asserts that), and
    `AssetService:CreateMeshPartAsync` has no caller at all yet (74a(h)). Round 2's claim that those
    rows already described built things was false; they said the opposite.

## The ADS screenshot, taken in Play and looked at (rule 5)

`.screenshots/20260926T231103Z-task74-ads2-44.png`, first person, aiming: the gun seen from behind
the stock — **walnut with its grain clearly textured** filling the lower frame, the silver/blue action
with its top lever and hinge, the pale standing breech above it, and the barrels foreshortening away
to a small pale shape at the top, because the camera is looking straight down them. **No untextured or
purple surface anywhere.** Honest caveats: the action and the stock's edges carry a **blue cast** — the
SurfaceAppearance's metalness reflecting the sky — and the gun is centred pointing away, so it reads as
a sight picture rather than a flank view (the same geometry as Task 71's ADS, queued as 71a(b)).
Nothing clips into the camera. It was taken in round 2, after the cache defect was found, so it is a
picture of the mesh and not of the fallback gun; the round-3 change is invisible to the camera.

## Not verified

- **The barrels read light silver in Roblox's daylight**, not the near-black of Task 72's Blender
  renders, and in ADS the metal takes a blue cast from the sky. The albedo is what Karen asked for;
  the in-engine result is not, and the dial is the prep recipe's (74a(b)).
- **`LoadAsset` has only ever been exercised for real in this Studio, on this account.** A server
  where it fails takes the fallback, which is asserted — but the real failure has not been seen, and
  no real load has ever hung: the `timeout` bound is proved by an injected slow fake.
- **The anchor depends on boot having decided within 12 s.** On a machine where the network is slower
  than that, `hadTemplate` is nil, the last case asserts the fallback instead, and the note says so
  rather than pretending it proved something.
- **`MapGen.Props` is still its own `LoadAsset` caller** (74a(a)), so "one caller in the repo" is
  true of `src/` outside the map generator and not yet of the whole repo.
- **`test2` was run by the Director, not by me** — the `[harness2]` line above is his, at this head. Two clients ran the whole client suite, the viewmodel appearance check included.

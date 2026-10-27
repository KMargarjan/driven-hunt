# Task 294a -- the two asset_fetch.spec defects that turned main's two-player run red

Task: 294a
Round: 2
Base: 625dfab2 (main)
Code commit: 4a788bae1e47d31157869c26ae4fe2ebc11c6e31

`git diff --stat 625dfab2..4a788bae`: `tests/client/asset_fetch.spec.luau` +84/-0 and
`src/client/Weapon/init.luau` +5/-0. CORE-NA: the five `src/` lines are a monotonic diagnostic
counter and its comment -- no branch, no timing, no behaviour change. It is there because the
Reviewer's round-1 blocking finding named it as the fix, and because the seam really was missing:
`Weapon.start`'s `started` guard makes it un-re-enterable, so nothing but the module itself can say
the sweep ran.

## HARNESS

```
[harness] PASS: 34/34 checks @ 4a788bae1e47d31157869c26ae4fe2ebc11c6e31 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 4a788bae1e47d31157869c26ae4fe2ebc11c6e31 (clean tree)
```

## FAIL FIRST, run by me on this branch, same scope (test2), at its FIRST commit

`70b2a718` is main's tree plus one `TestKit.note` of the hold case's counters:

```
[harness2] FAIL: 32/36 checks @ 70b2a7186f86ff3dab88b61d2515bff9e0b64d3c (clean tree)
  failed [shooter] asset_fetch.spec:324 ... asset_fetch.spec:184: Expected value "true" (boolean), got "false" (boolean) instead
  failed [driver]  asset_fetch.spec:324 ... asset_fetch.spec:184: Expected value "true" (boolean), got "false" (boolean) instead
```

It covers claim 1's case, "DRAWS NOTHING A PLAYER CAN SEE": `:184` is `body(handle)` inside
`withGunDrawn`'s pcall and the expectation it carries is `expect(Viewmodel.holding()).to.equal(true)`.
Claim 5's case did not exist at that commit, so its bite is argued by reading, not run (below).
`semiauto_client.spec:93` passed in that run and in both runs of the fix.

## CONFIRM -- the cause, every counter, both runs

| counter | 1P DEV, fix | 2P, BEFORE (`70b2a718`) | 2P, fix |
|---|---|---|---|
| mesh piece(s) | 2 | 2 | 2 |
| fabricated | **2** | **0** | **0** |
| waiting | 2 | **0** | 2 |
| held | 2 | **0** | 2 |
| holding | true | **false** | true |
| visible (held) | 0 | **3** | 0 |
| visible (past the bound) | 3 | not reached (red first) | 3 |
| warm calls (this case / live sweep) | 1 / 0 | -- | 1 / 0 |
| sweeps run by `Weapon.start` | 8 | -- | 6 (shooter), 19 (driver) |

`0 fabricated` in the two-player run means the server HAD published `BarrelGroup`/`FrameGroup`: they
read `Success`, `waiting` was 0, the hold never fired and 3 pieces were visible. The one-player DEV
run reached the held state only because it fabricated both pieces. After the fix the two columns are
identical with 2 fabricated and with 0.

## CLAIMS

1. **The hold case is place-independent.** The ids are held back through `AssetFetch.setStatus`
   instead of relying on an absent upload. Verify: the table -- `waiting=2 held=2 holding=true
   visible=0` with `2 fabricated` (1P) and with `0 fabricated` (2P).
2. **The stub holds back only THIS gun's own ids** (round-1 note). `heldBack` is keyed by the mesh
   ids of `ReplicatedStorage[Gun.FOLDER_NAME]`'s own MeshParts and every other id is delegated to
   `ContentProvider:GetAssetFetchStatus`, so no other gun can be pushed into a hold from inside a
   test. `reset()` is still needed ahead of it because `arrived` short-circuits `readyId`, and
   `arrived` is refilled for that folder afterwards through `AssetFetch.ready`.
3. **The hold still FAILS OPEN past the bound.** `past the bound: 3 visible` in both runs.
4. **The warm-call race is closed by identity, not a window** (one line): `warmWeapons` calls
   `AssetFetch.warm` synchronously, so this case's call always runs on the spec's own coroutine
   while `Weapon.start`'s sweep always runs on the `task.spawn` thread it created -- so
   `coroutine.running() ~= mine` excludes every sweep call whatever the timing. Verify:
   `warm calls: 1 from this case, 0 from the live sweep`, and a foreign-thread call is delegated to
   `realWarm` so the live sweep is not neutered.
5. **NO CLOCK decides whether the sweep case passes** -- the round-1 blocking finding, fixed as the
   Reviewer's second option. `Weapon.WARM_SWEEPS` is incremented inside `Weapon.start`'s `task.spawn`
   block; the case reads it and asserts `> 0`. `expect(time() < window)` is deleted, and the bounded
   wait is only for a spec that beats the FIRST sweep -- the counter is monotonic, so arriving late
   can no longer make it red. Verify: `sweeps run by Weapon.start: 8, 5.6s into the session` (1P),
   `6, 4.0s` (shooter), `19, 17.6s` (driver); the driver at 17.6 s would have been inside round 1's
   losing band. TO SEE IT FAIL: delete the `task.spawn` block in `Weapon.start` -- the counter stays
   0 and nothing else writes it (`grep -rn WARM_SWEEPS src tests`).
6. **No behaviour change.** `Weapon.WARM_SWEEPS` is read by nothing in `src/`; the only reader is the
   spec. Verify: that same grep.
7. **Rule G.** `tools/studio_mcp.py selftest`, `tools/agents.py selftest`, `stylua --check src tests`,
   `selene src`, `selene --config tests/selene.toml tests`, `rojo build` all pass. No new spec file,
   so `SCOPE_SPECS` is unchanged.

## WHAT I COULD NOT VERIFY

- Claim 5's case has no EXECUTED fail-first: it did not exist at `70b2a718`, and its bite is argued
  by reading (`WARM_SWEEPS` has exactly one writer, that block). The counter it reads removed the
  clock dependency but the negative was not run.
- Nothing of the held gun has been seen in Karen's place. This task is test code plus a counter; the
  cold-start look is the Director's to put to her and is unchanged by it.

ANSWERED: L-136 `semiauto_client.spec:93` was NOT pre-cleared. It passed at `70b2a718` (control:
main's tree + one note) and at `4a788bae`, both clients, so no carve-out was needed and none written.
ANSWERED: ROUTE the cold-start look task is the Director's, not this one. This task's three items are
the spec defects only; the other nine notes of `reviews/task-294/RESULT.md` stay queued.
ANSWERED: L-143 every counter, both runs, in the CONFIRM table -- including the ones that do not fit
the story (`visible=3` before the fix).
ANSWERED: L-028 fail-first was RE-RUN by me on this branch at its own first commit, in the same scope
(test2) the fix passes at. No wording was reused.

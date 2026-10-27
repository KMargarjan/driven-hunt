# Task 294a -- the two asset_fetch.spec defects that turned main's two-player run red

Task: 294a
Round: 1
Base: 625dfab2 (main)
Code commit: ef75d19f220bb23ff4b27079e7a6afe4aa96620a

TEST CODE ONLY. `git diff --stat 625dfab2..ef75d19f` is one file,
`tests/client/asset_fetch.spec.luau`, +89/-0. No `src/` change, so the game's behaviour is
untouched; no spec seam was missing (`AssetFetch.setStatus`, `setAsk`, `reset` already exist).

## HARNESS

```
[harness] PASS: 34/34 checks @ ef75d19f220bb23ff4b27079e7a6afe4aa96620a (clean tree) scope=all
[harness2] PASS: 36/36 checks @ ef75d19f220bb23ff4b27079e7a6afe4aa96620a (clean tree)
```

## FAIL FIRST, run by me on this branch, same scope (test2), at this branch's FIRST commit

`70b2a718` contains the hold case unchanged plus one `TestKit.note` of its counters:

```
[harness2] FAIL: 32/36 checks @ 70b2a7186f86ff3dab88b61d2515bff9e0b64d3c (clean tree)
  failed [shooter] asset_fetch.spec:324 ... asset_fetch.spec:184: Expected value "true" (boolean), got "false" (boolean) instead
  failed [driver]  asset_fetch.spec:324 ... asset_fetch.spec:184: Expected value "true" (boolean), got "false" (boolean) instead
```

It covers claim 1's case, "DRAWS NOTHING A PLAYER CAN SEE": `:184` is `body(handle)` inside
`withGunDrawn`'s pcall, and the expectation it carries is `expect(Viewmodel.holding()).to.equal(true)`.
Nothing else was red; `semiauto_client.spec:93` passed in that run and in both runs of the fix.

## CONFIRM -- the cause, every counter, both runs

| counter | 1P DEV, fix (`ef75d19f`) | 2P, BEFORE (`70b2a718`) | 2P, fix (`ef75d19f`) |
|---|---|---|---|
| mesh piece(s) | 2 | 2 | 2 |
| fabricated | **2** | **0** | **0** |
| waiting | 2 | **0** | 2 |
| held | 2 | **0** | 2 |
| holding | true | **false** | true |
| visible (held) | 0 | **3** | 0 |
| visible (past the bound) | 3 | not reached (red first) | 3 |

The Reviewer of 294 was right: `0 fabricated` in the two-player run means the server HAD published
`BarrelGroup`/`FrameGroup`, they read `Success`, `waiting` was 0, the hold never fired and 3 pieces
were visible. The one-player DEV run reached the held state only because it fabricated both pieces.
After the fix the two columns are identical with 2 fabricated and with 0.

## CLAIMS

1. **The hold case is place-independent.** `asset_fetch.spec` "DRAWS NOTHING A PLAYER CAN SEE" now
   holds the ids back through `AssetFetch.setStatus` (returning `Loading`) instead of relying on an
   absent upload. Verify: the table above -- `waiting=2 held=2 holding=true visible=0` with
   `2 fabricated` (1P) and with `0 fabricated` (2P).
2. **`reset()` is why it works and it is restored.** `AssetFetch.readyId` checks `arrived[id]` before
   the status, so `setStatus` alone cannot hold a downloaded id back. Verify: `arrived` is refilled
   after the case through the gate's own reader -- the `for ... AssetFetch.ready(part)` loop over the
   published folder, after `setStatus(nil)`/`setAsk(nil)`. Nothing else in the suite went red:
   623/617 passed on the two clients, up from 621/615.
3. **The hold still FAILS OPEN past the bound.** `past the bound: 3 visible` in both runs: the gun
   comes back as boxes rather than staying an empty hand.
4. **The warm-call race is closed by identity, not by a window** (one line, as asked): `warmWeapons`
   calls `AssetFetch.warm` synchronously, so this case's call always runs on the spec's own
   coroutine, while `Weapon.start`'s sweep always runs on the `task.spawn` thread it created -- so
   `coroutine.running() ~= mine` excludes every sweep call whatever the timing, and no window is
   relied on. Verify: `task294 warm calls: 1 from this case, 0 from the live sweep`, and the spy
   delegates a foreign-thread call to `realWarm` so the live sweep is not neutered.
5. **The sweep is now asserted to be STARTED** (new case, "IS REALLY STARTED by Weapon.start"). The
   `started` guard makes `Weapon.start` un-re-enterable, so the bite is the live thread: a `warm`
   call from a coroutine that is not the spec's can only come from that `task.spawn` block. Verify:
   `the sweep's own thread called warm 1 time(s) in 1.1s, 6.5s into a 30s window` (1P),
   `1 time(s) in 0.6s, 5.1s` (shooter), `1 time(s) in 0.9s, 20.7s` (driver). TO SEE IT FAIL: delete
   the `task.spawn` block in `src/client/Weapon/init.luau` `Weapon.start`.
6. **No `src/` change, no behaviour change.** Verify: `git diff --name-only 625dfab2..ef75d19f`.
7. **Rule G.** `python tools/studio_mcp.py selftest`, `python tools/agents.py selftest`,
   `stylua --check src tests`, `selene --config tests/selene.toml tests` all pass. No new spec file,
   so `SCOPE_SPECS` is unchanged.

## WHAT I COULD NOT VERIFY

- Claim 5's observation needs the session to still be inside the sweep's 30 s window. The margin
  measured is 9.3 s at worst (the driver, 20.7 s in). It is stated as an assertion
  (`expect(time() < window)`), so a session that starts the client specs after 30 s reads as that
  line and not as a deleted sweep -- but it is a timing dependency, and three clean runs is weaker
  evidence than Karen's two-consecutive-clean-runs bar for a race claim.
- Nothing of the held gun has been seen in Karen's place. This task changed test code only; the
  cold-start look (the Director's to put to Karen) is unchanged by it.

ANSWERED: L-136 `semiauto_client.spec:93` was NOT pre-cleared. It passed at `70b2a718` (control, main's
tree + one note) and at `ef75d19f`, on both clients, so no carve-out was needed and none was written.
ANSWERED: ROUTE the cold-start look task is the Director's, not this task. This task's three items are
the spec defects only; the other nine notes of `reviews/task-294/RESULT.md` stay queued.
ANSWERED: L-143 every counter, both runs, in the CONFIRM table -- including the ones that do not fit
the story (`visible=3` before the fix).
ANSWERED: L-028 fail-first was RE-RUN by me on this branch at its own first commit, in the same scope
(test2) the fix passes at. No wording was reused.

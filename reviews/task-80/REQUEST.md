# Task 80 — weapon_client's intermittent failure is a test fault, and the measurement says so

Task: 80
Round: 1
Base: `task-79-map-switch` (`5d31119`) — stacked, because Task 79 is not merged
Code commit: `40390b37d5932e4561b63f568bb71ebfa85e6449`

```
[harness]  PASS: 32/32 checks @ 40390b37d5932e4561b63f568bb71ebfa85e6449 (clean tree)
[harness2] pending — the Director's run at this branch's head
```

Nine of my own clean-tree runs at that commit, all green, on the **map world**; `src/` and
`tests/client/` both changed, so `test2` is part of the gate and the Director runs it twice.

**What changed.** `src/server/Weapon/init.luau` (`Weapon.onActionRequest`, `Weapon.onFireRequest`
exported), `tests/server/weapon_shot.spec.luau` (the handler case), `tests/client/weapon_client.spec.luau`
(the parking invariant, the window's near end, the reserve delta, the gun-count guard, prints → notes),
`tests/client/zz_outfit_client.spec.luau` → `tests/client/outfit_client.spec.luau`, `TASKS.md` rows 80/80a.

## Claims

1. **IT IS A TEST FAULT, NOT A GAME BUG, and that was measured before anything was changed.** Six runs
   of `test` on the map world at `e9911c2`: PASS, FAIL, PASS, PASS, PASS, FAIL. The failing run's own
   note: `shots seen: 3 ... cue at +4.5s; 3 gun(s) handed over [+2.2s backpack, +41.7s backpack, +41.8s
   backpack]; rises [#1 at +4.1s None/Slug res=24/24 BEFORE THE CUE, #2 at +7.3s None/Slug res=23/24,
   #3 at +8.3s None/None res=23/24]`. A slug fired **four tenths of a second before the spec's own
   cue**, from a full gun.
2. **No forged request was ever accepted.** In every one of those runs the exploit window came back
   identical before and after — ten snapshots each, all `busyFor=0.00`, `before open=false
   b=Spent/Spent res=23/20 -> after open=false b=Spent/Spent res=23/20`. Verify: the
   `weapon_client: exploit window:` note, which prints every snapshot inside the window.
3. **One cause, and the game is behaving correctly.** `Weapon.grant` ends with `Hardware.equip`
   because `Shotgun.CONFIG.AUTO_EQUIP` is true (Karen: a playtest should not start by hunting for the
   hotbar), and `refreshArming`'s sweep calls grant again whenever it finds a player who should be
   holding one — three guns per one-player session. `parkTool` returned true the moment it found the
   gun in the Backpack, *"already parked"*, **without unequipping anything**, and the owner
   auto-equipped it a moment later; then the replay's first click fired it.
4. **Parking is an invariant now, not a one-off act.** A watcher unequips the gun every time the owner
   hands one over, until the cue — so the owner may re-grant as often as it likes and the replay's
   early clicks still reach nothing.
5. **This spec's window has a near end.** `ownLog()` starts at the cue, so a shot before the spec took
   the gun is not counted as one of its own. That is the fix for the symptom **and** for 77a(a), whose
   diagnosis was wrong: inserting a file changed *which* shot leaked into the count, it did not cause
   the leak. Verify: Task 80 reproduced the identical failure — 23 slugs, three shots — with no new
   file at all.
6. **The reserve assertions are a delta from the cue.** They read `== 24` and `== 22`, which is
   `Shotgun.CONFIG`'s starting pocket and therefore a claim about the whole session; `Weapon.grant`
   resets the reserve to full, so the absolute was right only when nothing had touched the gun first.
7. **The exploit window is thrown away if the owner handed over a gun inside it.** Causal, not timed:
   a grant resets the state and auto-equips, which is exactly what an accepted `Break` would look
   like, and the two failing two-player runs had `weapon granted=9 revoked=4`.
8. **The property itself moved to the server, where it is deterministic.**
   `Weapon.onActionRequest` and `Weapon.onFireRequest` are the **same** functions `Weapon.start`
   connects to the remotes, now reachable by parameter — no second implementation, one owner.
   `weapon_shot.spec`'s "consults the whitelist before acting, at the handler the remote calls" drives
   twelve forged payloads through them and requires `stats.badRequests` to rise by exactly twelve with
   `rateDropped` and `shots` unmoved. A legitimate grant or reload cannot raise that counter, so there
   is no window and no waiting. Verify: `weapon_shot: 12 forged request(s) at the handler ->
   badRequests +12, rateDropped +0, shots +0`. The client case stays as the half only a client can
   prove — that the remotes reach that handler at all.
9. **One mutation, applied, run and restored, and it caught both halves.** `onActionRequest` stops
   consulting the whitelist → the server case fails with `badRequests +3` of twelve
   (`weapon_shot.spec:158`) **and** the client case fails at
   `expect(after.open).to.equal(before.open)`. So the forged `Break` really does open the gun when the
   guard is gone, and neither half is dead weight.
10. **The evidence arrives with the failure now.** Every print in `weapon_client` that explains
    something is a `TestKit.note`. The first diagnostic run was wasted on exactly this: the map
    world's console came back `[TRUNCATED DUE TO LENGTH LIMIT]` and took every print with it, while
    the notes arrived intact. The notes also name *which* shot was extra and every Tool the owner
    handed over, which is what made claim 1 a measurement rather than a theory.

## What I could not verify

- **The two-player failures were not reproduced under two players.** I cannot run `test2`, so
  `weapon_client.spec:766/770` in `<runs-dir>/test2-task-79b.log` and `-79c.log` are **explained** by
  this mechanism, not measured under it: that session handed over nine guns and revoked four, and
  claim 7 is aimed exactly at it. If a two-player run still fails there, the new note says how many
  guns were handed over and when. Queued as 80a(b).
- **Nine green runs is evidence, not proof.** The failure was about one run in three, so nine clean
  runs put the chance of having been lucky near 2.6%. The cause is a race with a sweep that runs every
  few seconds, so a slower machine could still find a window this does not cover (80a(f)).
- **The `QUIET` wait is still partly time-based** (80a(a)): a click's effect arrives after the click,
  and no client-visible signal says "the server has finished reacting to what I did". The property no
  longer rests on it — that is claim 8 — so the worst this costs is a retry.
- **`docs/design/shotgun.md` does not mention the handler seam** (80a(e)). The two handlers are part
  of `Weapon`'s public surface now and §5.5 describes them as private to the remote wiring. The
  Architect's file, queued like 74a(g), 75a(i) and 79a.
- **N/A: no screenshot.** Nothing visual changed — one `src/` export, two specs and a rename.

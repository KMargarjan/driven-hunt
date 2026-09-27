# Task 80 — weapon_client's intermittent failure is a test fault, and the measurement says so

Task: 80
Round: 1
Base: `task-79-map-switch` (`5d31119`) — stacked, because Task 79 is not merged
Code commit: `fd362867395246a8f3aea431a38f45ae83cb98b1`

```
[harness]  PASS: 32/32 checks @ fd362867395246a8f3aea431a38f45ae83cb98b1 (clean tree)
[harness2] pending — the Director's run at this branch's head
```

Three of my own clean-tree runs at that commit, all green, on the **map world**, plus nine at
`40390b3` for the client half, which this commit does not touch. `src/` and `tests/client/` both
changed, so `test2` is part of the gate and the Director runs it twice.

**The Director's `test2` at `99a2f5a` found a second fault, and it was mine.** `[harness2] FAIL: 30/32`
at `weapon_shot.spec:161`, `Expected 0, got 1` — the `shots` delta. The client half passed under two
players, which is claims 1–7. Claim 8's first version asserted a **server-wide counter across a
wall-clock window**, which is the same mistake this whole task is about, committed inside the fix for
it. Claim 8 reads per call now and carries that correction itself.

**What changed.** `src/server/Weapon/init.luau` (`Weapon.onActionRequest` and `Weapon.onFireRequest`
exported, and both now return their own decision at every exit),
`tests/server/weapon_shot.spec.luau` (the handler case),
`tests/client/weapon_client.spec.luau` (the parking invariant, the window's near end, the reserve
delta, the gun-count guard, prints → notes),
`tests/client/zz_outfit_client.spec.luau` → `tests/client/outfit_client.spec.luau`, `TASKS.md` rows
80/80a.

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
8. **The property itself moved to the server, and the seam reports its own decision so nothing is
   raced.** `Weapon.onActionRequest` and `Weapon.onFireRequest` are the **same** functions
   `Weapon.start` connects to the remotes, now reachable by parameter — no second implementation, one
   owner — and each returns `nil` when the request was acted on, otherwise the reason it was not, at
   every exit. `OnServerEvent:Connect` discards the return, so the game is unchanged; a return value
   belongs to one call and one player and nobody can race it. The spec drives twelve forged payloads
   and asserts **(i)** none came back `nil`, so none was acted on, and **(ii)** none came back
   `rate-limited` or `untracked`, the two exits *before* the validator — which is what would make this
   case green with the whitelist deleted. The rate limiter is no longer dodged by counting to ten and
   guessing: a call that says `rate-limited` is simply made again in the next window. Verify:
   `weapon_shot: 12 forged request(s) at the handler, subject <name> of roster [<name>(tracked)];
   reasons [action Break=bad-request, … fire #1=bad-type, …]`. The client case stays as the half only a
   client can prove — that the remotes reach that handler at all.
   **AND ITS FIRST VERSION WAS WRONG IN EXACTLY THE WAY CLAIMS 1-7 ARE ABOUT.** It asserted
   `stats.shots` had not moved across its own window. `stats` is one module-level table for the whole
   server, so `after.shots - before.shots` counted **every** player's shots — and under two players the
   shooter's replayed click landed in my numbers and read as a forged request being accepted. One
   player never overlapped; two did. Verify in `<runs-dir>/test2-task-80.log`: `badRequests +12,
   rateDropped +0, shots +1` — twelve refusals *and* one real shot, in the same line. The counters
   survive only as labelled context in the note now, beside the subject's name, the full roster with
   who is tracked, and every payload's reason, so the next `test2` answers this either way without
   another round.
9. **The mutation, re-run against the new shape, still catches both halves — and now it names the
   exploit instead of a number.** `onActionRequest` stops consulting the whitelist → the note reads
   `action Break=nil` (the forged `Break` **accepted**) with every later payload `not-ready`, because
   that Break left the gun broken open; `weapon_shot.spec:202` fails; **and** the client case fails at
   `expect(after.open).to.equal(before.open)`. Neither half is dead weight.
10. **The evidence arrives with the failure now.** Every print in `weapon_client` that explains
    something is a `TestKit.note`. The first diagnostic run was wasted on exactly this: the map
    world's console came back `[TRUNCATED DUE TO LENGTH LIMIT]` and took every print with it, while
    the notes arrived intact. The notes also name *which* shot was extra and every Tool the owner
    handed over, which is what made claim 1 a measurement rather than a theory.

## What I could not verify

- **The client half is confirmed under two players; the server half is not yet.** The Director's
  `test2` at `99a2f5a` reported `[shooter] weapon_client: shots seen: 2 … cue at +16.8s; 3 gun(s)
  handed over [+0.0s hand, +37.0s backpack, +37.0s backpack]` and it passed — which is claims 1–7
  measured under the conditions that used to break them, including a gun in the hand at +0.0 s. Claim
  8's new shape has only run under one player; I cannot run `test2`. If it still fails, the note names
  the subject, the roster and every payload's reason. 80a(b).
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

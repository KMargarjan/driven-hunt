# Review request — Task 41: evidence seams

Task: 41
Round: 1
Base: `task-38-note-fixes` @ `b1620ac` (**stacked three deep**: 38 on 36 on 35, none merged. The
Director merges 35, then 36, then 38, then this)
Code commit: `eb0b23e3c4a0697bd4b1cb1ad62471f54245506c`
Branch: `task-41-evidence-seams`

```
[harness]  PASS: 27/27 checks @ eb0b23e3c4a0697bd4b1cb1ad62471f54245506c (clean tree)
[harness2] PASS: 30/30 checks @ eb0b23e3c4a0697bd4b1cb1ad62471f54245506c (clean tree)
```

Server 274 passed (265 before), shooter 70, driver 64; 0 failed / errors / skipped in each.

---

## Claims

1. **The drive's clock has a seam, and it cannot open outside a harness run.**
   `Match.advanceForTests(seconds)` adds to this owner's own `now()`. No number changes and no phase
   is skipped: the machine takes exactly the transitions it would have taken ten minutes later. The
   gate is **Studio AND `TestKit.activeToken()`** — "a gated test run is in progress", which only
   `TestKit.run` sets — reached through `FindFirstChild` + `pcall`, so stripping TestKit at publish
   (`TASKS.md` row 2) cannot break the owner and a published place has no seam at all. Karen's
   playtests are never given a token, so `TestKit.run` never starts and `activeToken()` stays nil.
   *Verify:* `testGateOpen` / `advanceForTests` / `now` in `src/server/Match/init.luau`;
   `TestKit.activeToken` in `tests/TestKit.luau`; the first `it` of
   `tests/server/zz_drive_boundary.spec.luau`.

2. **`TestKit.openToken()` was the wrong question to gate on, and the run proved it.** It answers
   "may a runner START now" and is time-limited by design (120 s); a suite outlives it, and the seam
   was refused 200 s into a run. `activeToken()` answers "is a gated run in progress". Same gate, one
   implementation, right question. *Verify:* the header above `activeToken` in `tests/TestKit.luau`.

3. **32a(c) is closed, and the spec fails on the pre-fix behaviour in both modes.** The drive-start
   push is asserted on `Match.lastSent()` — what the clients were *actually* sent, which is not the
   same question as what `snapshot()` says a quarter of a second later. Measured this run: the old
   drive carried **61 point-units (1 player) / 12 (2 players)** and the drive-start payload carried
   **0**. Pre-fix it carried the old rows. *Verify:* `lastSent` in `src/server/Match/init.luau`;
   "starts the next drive, and TELLS the clients the new drive's rows" in `zz_drive_boundary.spec`;
   the `zz_drive_boundary` notes in either run's output.

4. **The tie lasts exactly until the drive ends.** In the two-player run the shooter really is tied by
   a real shot; the boundary spec records **1 tied, 1 rope** before it ends the drive, then asserts the
   tied set is empty, `Workspace.DriveMarkers` holds nothing, and the gun comes back at the next
   Assigning. *Verify:* "ends the drive…" and "gives the guns back…" in `zz_drive_boundary.spec`.

5. **35b(b) is closed: the penalty is published as an award.** `Match.Scored` carries the −50 like
   every kill and escape, and the spec asserts the count of `safety` awards equals
   `Match.stats().violations` — **3 awards, 1 of them safety**, measured in the two-player run.
   *Verify:* the last-but-one `it` of `zz_drive_boundary.spec`.

6. **32a(d) is closed: the arming policy's pcall fallback.** A policy that throws must not disarm
   everybody or arm everybody — it falls back to the weapon's own rule. The spec installs a throwing
   policy, asserts `refreshArming` does not raise (it would without the pcall), asserts the fallback
   answer, and puts the drive's policy back. It runs after every client has finished, because it hands
   a driver a gun for the two seconds before the restore. *Verify:* `Weapon.mayArmForTests` in
   `src/server/Weapon/init.luau`; "falls back to the weapon's own rule…" in `zz_drive_boundary.spec`.

7. **A real defect the seam found (rule 6): a phase-change broadcast could be swallowed by the
   throttle.** `STATE_MIN_INTERVAL` is the floor between pushes for a busy drive; a *phase change*
   behind it is a client showing the wrong drive until the 5-second heartbeat. Crossing two boundaries
   inside one throttle window made the drive-start push vanish outright. Every phase entry now marks
   its broadcast `force`, and an ordinary event does not. *Verify:* `enterAssigning` / `enterRunning` /
   `enterScoring` / `enterWaiting` in `src/server/Match/Phase.luau`; `applyEffects` in
   `src/server/Match/init.luau`; "forces the push on every phase entry, and only there" in
   `tests/server/match_phase.spec.luau`.

8. **A client cannot tell the server it has finished, so the harness does.** Measured: a `LocalPlayer`
   attribute written on the client does **not** replicate to the server (the first version of the spec
   waited 240 s for a `TestReport` that had been set 200 s earlier), and this game has no inbound
   remote by design. The harness sets `ServerStorage.ClientsFinished` to the run's own token once every
   client has reported; the boundary spec waits for it before it disturbs anything — ending a drive
   clears every boar, frees every tie and respawns everybody. *Verify:* `QUERY_SET_CLIENTS_DONE` and
   both report loops in `tools/studio_mcp.py`; `clientsFinished` in `zz_drive_boundary.spec`.

9. **The one-player report loop read its two sides one after the other**, so a server that
   legitimately reports *after* the client was given up on at 120 s — which is now the normal order.
   Both are polled against one deadline (`REPORT_WINDOW`), the fix `test2` already had. *Verify:* the
   polling loop in `run_test`.

10. **`capture` names its Studio, so a two-player screenshot is possible at all.** StudioMCP refuses
    every call that names no `studio_id` as soon as a local test adds processes, and `capture` sent
    none. It now takes a role — `edit` (default), `server`, `client`, `client:<PlayerName>` — resolved
    by asking each process what it is (`probe_role`, the same classifier `test2` uses), never by name.
    *Verify:* `studio_for_role` and the `capture` branch of `main` in `tools/studio_mcp.py`; the
    screenshots below, taken from `client:Player1`'s own window during a live `test2`.

---

## Screenshots, inspected (rule 5)

`.screenshots/task41-boundary-from-client-window.png` (git-ignored), taken from **`client:Player1`'s
own window during a live two-player run** -- which is the thing that was impossible before claim 10.
One frame carries the whole boundary: the event feed reads **"Player1 tied to a tree" / "Drive over" /
"Drive 2"**, the drive bar reads **"DRIVE 2   ASSIGNING   0:18   DRIVER"** -- Player1 was the SHOOTER
in drive 1 and is the DRIVER in drive 2, so the teams swapped -- and the character is respawning on
the driver pad.

**The rope itself is not in it, and that is the seam working.** The window between the tie and the
boundary is about ten seconds (the boundary waits only until both clients have reported), and a
capture round-trip is several. The rope in close-up is `.screenshots/task35-tied-to-a-tree.png` from
Task 35; that the rope EXISTED in this run is the boundary spec's own note, `1 tied, 1 rope(s)`,
asserted gone immediately after.

## What could not be verified, and what is not closed

- **Three of the six notes 38a(i) named are still open, and each needs its own thing:** 32a(b) (the
  release hand-back needs a boar runtime that refuses a spawn), 32a(e) (`Match.forget` / `Match.stop`
  would remove the live player mid-session) and 35b(c) (the no-anchor branch needs a map with no
  `DrivenHunt.Tree` at all). None is a clock problem, so this seam does not reach them. Row 38a(i)
  says so.
- **The seam moves the drive's clock and nothing else's.** The boar runtime, the weapon and
  `Body.place`'s timeout keep real time, so a boundary crossed in a test is not a ten-minute drive in
  every respect — it is the same transitions with the same numbers, which is what the notes needed.
- **The gate is asserted, not proven against a playtest.** `activeToken()` is nil unless `TestKit.run`
  started, and nothing writes a token during a playtest — but I did not sit in a playtest and try it.
- **I did not photograph the rope in a two-player run**, for the reason above. Three `test2` runs
  were spent trying; the third is the one the screenshot comes from.
- **`Match.lastSent()` is a new public reader.** It holds one frozen snapshot, which is a reference to
  a table the owner built anyway; a spec is its only caller.

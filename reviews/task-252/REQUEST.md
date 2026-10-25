# Task 252 -- the `camera_client` flake that fails half the gate runs

Task: 252
Round: 1
Base: 6e5926b2 (`main`, after PR #240)
Code commit: 6de2403f076634e6933a49a90305a7c8de62cb7b

One file changed: `tests/client/camera_client.spec.luau`, the `describe("the hands")` case. No `src/`
file, no bound widened, no spec re-baselined.

```
[harness] PASS: 34/34 checks @ 6de2403f076634e6933a49a90305a7c8de62cb7b (clean tree) scope=all
```

`test2` is N/A: `tests/client/camera_client.spec.luau` is not in `TWO_PLAYER_PATHS`
(`tools/agents.py`), and the change touches no match, drive, tie or team path.

## What changed, and why

The flake is a **second writer getting inside the case's own `task.wait`**. `Camera.step` calls
`Viewmodel.setReload(breaking)` every frame off the weapon replica; the case set `setReload(nil)`
*before* a `task.wait(0.3)` and then measured, so the next live render frame replaced that state with
the real gun's. With the replayed input holding the real gun open and a shell going in, the "carry"
frame drew the **left hand at the shell-feed pose** instead of on the forend, and the pair
"its place on the barrels did not change" was then measured across two different hand mechanisms.

The fix sets the reload state **after the last yield**, asserts the fact the measurement needs on both
measured frames rather than assuming it, drops a second `task.wait` that was making a different
assertion pass for the wrong reason, and makes the re-raise name the step it failed on.

## Claims

1. **The flake's recorded line names no assertion, and three tasks therefore named the wrong one.**
   `camera_client.spec:1618` at `e2d41773`, `bba4763d`, `f7716249` and `2b47d3a7` is `error(err, 0)`
   -- the `pcall` re-raise at the bottom of the `describe("the hands")` case.
   *Verify:* `git show <sha>:tests/client/camera_client.spec.luau | sed -n '1615,1620p'`.
2. **`handsMissing > missingBefore` cannot read false on a live camera**, so 235's, 242a(c)'s and
   249a(d)'s identification was an inference. `stats.handsMissing` only ever rises
   (`Viewmodel.hands`, `updateHorn`; nothing resets it), and `Viewmodel.clear()` -- the line
   immediately above the read -- sets `handsMissingCounted = false`, so the next `Viewmodel.hands`
   with a nil template increments.
   *Verify:* read `Viewmodel.hands`, `Viewmodel.clear` and `stats` in
   `src/client/Camera/Viewmodel.luau`; grep the file for every write to `stats.handsMissing` and to
   `handsMissingCounted`.
3. **The real failing assertion is the left hand's place on the barrels, and the failing run is on
   disk.** `<runs-dir>/test-t229-r2b.log` at `c1084110`: *"left hand moved 0.182 studs on the body and
   0.2695 on the barrels; right hand 0.1194"*, `failed [client] camera_client.spec:1573`,
   `FAIL: 31/33`. `<runs-dir>/test-t229-r2c.log` at the **same sha**: 0.219 / **0.0000**,
   `PASS 33/33`. The right hand reads 0.1194 in both, so the gun and the barrels were in the same
   place and only the left hand was somewhere else.
   *Verify:* `grep -aE "task93 break|failed .client.|^.harness." <runs-dir>/test-t229-r2b.log <runs-dir>/test-t229-r2c.log`.
4. **The mechanism is `Camera.step`'s own per-frame write.** `src/client/Camera/init.luau` resolves
   `breaking` from the break source and calls `Viewmodel.setReload(breaking)` once a frame, so any
   live render frame inside the case's `task.wait(0.3)` overwrites what the case set before it.
   *Verify:* read the `Viewmodel.setReload(breaking)` call in `Camera.step`; then
   `Viewmodel.loadingAt` -- a non-zero weight needs `reload.open` and `loadedAt[barrel]`, both of
   which that call fills -- and `Viewmodel.poseHands`, where a non-zero weight lerps the left hand
   off `Mode.handOffsetAt("left", ...)` toward the feed pose.
5. **It reproduces on demand, at weight 0.800.** A throwaway probe injected one
   `setReload({ open = true, spent = 0, loaded = { true, false } })` -- exactly what a live frame
   leaves -- with the clock wound 0.12 s on through `Viewmodel.setClock`.
   *Verify:* `<runs-dir>/test-252-repro.log`:
   `note [client] task252 repro: feed weight after a live setReload is 0.800`. The probe was reverted
   and is in no commit (`git diff main..HEAD` is the whole change).
6. **The new guard CAN fail, and it names its own step** (L-028). The same probe run:
   `failed [client] camera_client.spec:1714 [hands: the break: which hand rides the barrels] Expected
   value "0" (number), got "0.8036179995785158" (number) instead`. That is both halves of the fix
   proving themselves: the wait-on-fact assertion fired, and the `stage` prefix reached the report.
   *Verify:* `grep -a "failed .client." <runs-dir>/test-252-repro.log`.
7. **The reload state is now set after the last yield, and nothing yields during the measurement.**
   *Verify:* in the `describe("the hands")` case, read from `stage = "the first build"` to the final
   `Camera.Viewmodel.clear()`: the only `task.wait` left is the one before `setReload(nil)`, and no
   other call in that range yields (`expect`, `TestKit.note` -> `print`, `string.format`,
   `Viewmodel.update`, `Viewmodel.loading`, `Mode.*`, `CFrame` arithmetic).
8. **No bound moved and no assertion was deleted.** The claims are the same claims: `> 0.05` on the
   body, `< 1e-3` on the barrels, `< 1e-3` against `Mode.handOffsetAt("right", open, ...)`, the two
   parents, the ancestry, the four part properties, the flag-off removal and the counter.
   *Verify:* `git diff main..HEAD -- tests/client/camera_client.spec.luau` -- every removed line is a
   `task.wait(0.3)`, a moved `setReload(nil)`, or the old `error(err, 0)`.
9. **The no-templates sub-case now measures the call under test.** Before the fix its own note read
   `handsMissing 11 -> 12 (12 after the wait, drawn=true)` -- the counter had already moved inside the
   sleep, so the live render step was what passed it and the `update` below contributed nothing.
   *Verify:* `grep -a "no templates" <runs-dir>/test-252-probe-1.log` (the instrumented pre-fix run)
   against `<runs-dir>/test-252-proof-1.log`.
10. **Ten consecutive full runs green at the code commit.** `<runs-dir>/test-252-proof-1.log` ...
    `-10.log`, each `[harness] PASS: 34/34 checks @ 6de2403f076634e6933a49a90305a7c8de62cb7b (clean
    tree) scope=all`, all ten at that one sha (L-034).
    *Verify:* `grep -ahE "^.harness. (PASS|FAIL)" <runs-dir>/test-252-proof-*.log`.

## What could not be verified

- **The flake did not reproduce at HEAD before the fix.** Four pre-fix full runs were green with
  byte-identical notes, including one with 8 CPU hogs pinned on 12 logical cores -- which did not
  reach the client: its longest frame stayed 0.025 s (`<runs-dir>/test-252-stress-1.log`). So there is
  no fresh red run of my own. The "before" is the two saved task-229 logs at one sha (claim 3) plus
  the on-demand reproduction (claims 5 and 6). I could not make the replayed input put the real gun
  open with a shell in flight at the exact moment this case runs; that interleaving is what decides
  the flake, and it is the harness's cue timing, not something this case can ask for.
- **Whether this was the only cause of every one of the 7-of-12 failures task 249 counted.** Those
  logs were not kept (L-043), and the surviving signature (`:1618`) names no assertion. What is
  proved is one cause, with one measured failing run and an on-demand reproduction. Any remaining
  occurrence will now arrive with its step in the message.
- **A screenshot.** N/A: nothing drawn changed. No `src/` file is touched.
- **One cosmetic item, queued as 252a rather than fixed:** the `THE TEMPLATES, INJECTED` paragraph now
  sits 17 lines above the `setHandTemplates` call it describes, because the probe block and `stage`
  went in between. Comment-only; a new code commit would re-open the ten-run proof this task exists
  to produce.

# Task 293c -- the carcass says how often it was repaired

Task: 293c
Round: 1
Base: afd31918 (main)
Code commit: f482308f793dab3fa32ed88f96f9aefbb4d0cdcf

## PLAN (core quality protocol; the dispatch declares this CORE-NA -- a diagnostic, the pose must not change)

- (a) REAL LIFE: n/a. This is an instrument, not a behaviour. Nothing a player sees changes.
- (b) MEASURED NOW: at main, a live DEV probe over three boars read
  `Boar1 kind=female carcass=nil Reholds=nil / Boar2 cub / Boar3 male` -- the attribute does not
  exist (probe `scratchpad/293c-read.luau` through `<runs-dir>/devplay.py server`). `handle.reholds`
  exists but lives in module state, which a live probe cannot read.
- (c) TARGET: the real repair count, on the carcass instance, written once per change and never on a
  step that changed nothing. Not a rate, not a cap -- 293b deliberately has no bound, and an
  instrument with a bound could not show the storm it is there to rule out.
- (d) LEVER: `handle.reholds`, incremented by the one repair site.
  `src/server/Boar/Body.luau:1466: handle.reholds += 1` (grep `reholds` -- the only `+=` in `src/`).
  The instance is `handle.part`, the trunk, which is already the one carrying `Carcass`
  (`src/server/Boar/Body.luau`, `Body.collapse`: `part:SetAttribute("Carcass", true)`) and the one
  `src/server/Boar/init.luau` itself reads `GetAttribute("Carcass")` off -- so every existing probe
  that finds carcasses finds this with no new lookup.
- (e) MEASURED AFTER by the same probe: `scratchpad/293c-read.luau` reads `Reholds` off each boar part.

## What changed

1. `Body.stepVisual` (`src/server/Boar/Body.luau`) publishes `handle.reholds` onto `handle.part` as
   the `Reholds` attribute: **read-compare-write**, guarded by `handle.collapsed`. nil = alive,
   0 = a carcass that never lost its pose, N = N repairs.
2. Two cases in `tests/server/boar_model.spec.luau`, and `carcass293` now builds its handle with a
   real `part`, so the cases drive the real writer.

Nothing else: the pose, the freeze window, the paddle and the repair rule are untouched.

## Claims

1. **The attribute is the real count, on every change.** `boar_model.spec.luau`, *"publishes the
   repair count on the carcass instance, on every change (task 293c)"*: 17 real overruns through
   `Body.stepVisual`, and the attribute is asserted **after every single one** (`expect(...).to.equal(i)`
   inside the loop). A throttle, an every-Nth write or a cap anywhere fails it on the step it skipped.
   *(L-145.)*
2. **0 across a whole carcass life with no overrun.** Same file, *"reads 0 across a whole carcass life
   with no overrun (task 293c)"*: `math.ceil(CARCASS_SECONDS / dt)` = 7200 back-to-back real
   `Body.stepVisual` calls on a held track. It asserts the step count beside the 0, `track.plays == 0`,
   and that the pose is still held at the end -- so it cannot pass by doing nothing. *(L-142, L-093.)*
3. **FAIL FIRST, at a commit that contains the cases.** `83273e4dc9bd8881190076c8fa836ae9d3c334ff`
   is the two cases against **main's** `Body.luau` (the src change stashed out of that commit):
   `[harness] FAIL: 30/34 checks @ 83273e4dc9bd8881190076c8fa836ae9d3c334ff (clean tree) scope=all`
   -- `boar_model.spec:1417`, `Expected value "0" (number), got "nil" (nil)`, which is claim 1's
   SECOND assertion (the first, `...to.equal(nil)`, passes at main). *(L-034.)*
4. **AFTER:** `[harness] PASS: 34/34 checks @ f482308f793dab3fa32ed88f96f9aefbb4d0cdcf (clean tree) scope=all`
   -- server 2419 passed / 0 failed (2417 before these two cases), client 623 / 0.
5. **Not a per-frame writer.** The write is behind `part:GetAttribute("Reholds") ~= handle.reholds`.
   `reholds` changes only at the one `+=` inside the repair branch, and that branch is already
   once-per-stop (the repair restores the state `shouldRehold` then refuses -- the first assertion of
   the existing *"puts the held death pose back"* case). Claim 2's 7200 steps are the measurement:
   `plays == 0` and the attribute never moves off 0.
6. **Only a carcass carries it.** The publish is inside `if handle.collapsed`, so a live animal has
   no `Reholds` attribute at all. Claim 1's first two lines assert nil before the first step and 0 after it.
7. **A probe can find it.** It is on the trunk part in `workspace.Boars`, the instance carrying
   `Carcass` -- `src/server/Boar/init.luau` reads `GetAttribute("Carcass")` off exactly that part in
   two places. Verified live at main by `scratchpad/293c-read.luau`, which walked
   `workspace.Boars:GetChildren()` and printed three rows.
8. **The pose behaviour is unchanged.** `git diff afd31918..f482308f -- src/` is one added block and
   one comment; no rule, window, frame or clip name is touched. Every pre-existing 293/293b case
   still passes (claim 4).
9. **Gates.** `selene src`, `selene --config tests/selene.toml tests`, `stylua --check src tests`,
   `rojo build`, `python tools/studio_mcp.py selftest`, `python tools/agents.py selftest`: all clean.
   No new spec file, so `SCOPE_SPECS` is unchanged.

## Not verified

- **A live kill in DEV: NOT OBTAINABLE this session.** `<runs-dir>/293-shoot-any.luau` returned
  `0 kills attempted` three times (its LOS test is `r.Instance:IsDescendantOf(m)`, which is false when
  the ray hits the trunk `m` itself), and a direct probe (`scratchpad/293c-shoot.luau`) fired 6
  `FireRequest:FireServer` shots at a boar 30 studs away with the Shotgun in the character and
  `team=Shooters` -- `carcass=nil` afterwards and no hitlog line in the console. So the AFTER half of
  (b)/(e) was read only at main (nil on three live boars), not on a real carcass.
  `<runs-dir>/onray.py` is Forest-Test-only. **The live proof is the Director's dispatched item**
  (a drive-native kill in the Forest Test, attribute + bones at +3/+60/+115 s).
- `test2`: N/A. `src/server/Boar/` and `tests/server/boar_model.spec.luau` are not in
  `TWO_PLAYER_PATHS`; a second player answers nothing here.

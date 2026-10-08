# Task 131 - a permanent spec that the gun stays in the hand

Task: 131
Round: 2
Base: main
Code commit: `6dc8ac4d4acef5b68a13e3dbc0cdda0248c59940`

```
[harness] PASS: 33/33 checks @ 6dc8ac4d4acef5b68a13e3dbc0cdda0248c59940 (clean tree) scope=all
```

`test2` is N/A: this change touches no path in `TWO_PLAYER_PATHS` (one new file under `tests/server/`
and one line in `tools/studio_mcp.py`'s scope table), and no `src/` at all.

## What changed

Karen hit *"There is no weapon something is broken"* twice and then said *"be sure that those mistakes
never be repeated / it's basics"*. It was fixed twice -- task 123 round 9 (`Hardware.upgradeAll`'s
`after` callback re-equips a gun whose mesh landed late) and task 129 (`Hardware.equip` verifies the
outcome and retries) -- and neither fix had a spec that would fail if it were deleted.
`tests/server/weapon_equip.spec.luau` is that spec.

## What round 1 found, and what round 2 did

**The finding was real, and it was this file's own fault committed in this file.**
`Humanoid:EquipTool` unequips whatever is held before it equips the new Tool, so equipping a probe
onto the live player left his real Shotgun in the **Backpack** -- the exact state Karen complained
about -- and nothing put it back: `holdsTool` is record-based, so a gun in the Backpack still reads
as "holding", `armingAction(true, true)` is nil and the sweep does nothing. `Weapon.armingAction`'s
own comment records the same trap from Task 34.

Every case that equips anything now **remembers the player's own gun first, runs its body inside a
`pcall`, and ends by re-equipping that gun and ASSERTING it landed** -- so a FAILING assertion cannot
leave the session gunless either. The live evidence is in the same run: `match_live`'s note reads
`may carry=true holds=true | weapon granted=3 ... equip now=3 late=3 gaveUp=0`, and the gun is in
the character at the end of the harness's Play.

The notes are done too: the probe Tool has a handle and is named for what it is (`probeTool`), the
second `Shotgun`-named Tool is destroyed pass or fail, the design citation points at
`docs/design/shotgun.md`, which exists, and the comment no longer claims a frame that does not pass.

## Claims

1. **The equip reports an OUTCOME, not a call.** The case puts a Tool in the player's Backpack, calls
   `Hardware.equip`, and asserts the Tool **ends in the CHARACTER** and that `Weapon.stats().equipLate`
   moved. Verify: `tests/server/weapon_equip.spec.luau`, "reports the OUTCOME of an equip".
2. **That assertion is load-bearing for task 129.** `equipLate` is incremented in ONE place -- the
   loop in `Hardware.equip` that re-checks on a later frame. **Measured:** with that loop deleted the
   case fails (`weapon_equip.spec:121`, "Expected true, got false"), and the suite reports
   `773 passed, 3 failed` instead of `776 passed, 0 failed`.
3. **Task 123 round 9's re-equip is pinned.** A gun wearing the parts fallback, in the Backpack, is
   upgraded by `Weapon.upgradeLook()` and must end **in the character**; nothing else in that path
   parents it there. **Measured:** with the `after` callback's body deleted the case fails
   (`weapon_equip.spec:182`).
4. **`after` fires once per upgraded gun, not every sweep.** A second `upgradeLook()` returns 0, and a
   gun deliberately put back in the Backpack is left there -- which is what lets a player holster one.
5. **The arming policy is asserted** (`Weapon.armingAction`): grant when allowed and not holding,
   revoke when holding and not allowed, and **nothing** when the world already matches.
6. **No `src/` was touched, and the session is left as it was found.** The spec DOES equip onto the
   live player -- there is no other humanoid to equip onto -- so each case remembers his gun, destroys
   its own Tool pass or fail, and re-equips his, asserting it landed. Verify: `realGunOf`, `restore`,
   and the `pcall` in both equipping cases.
7. **Registered in the weapon scope** (`SCOPE_SPECS` in `tools/studio_mcp.py`), so
   `test --scope auto` runs it for a weapon change; `selftest` passes.

## What could not be verified

- **The retry loop itself cannot be driven from a spec**, and the spec's header records why, with the
  three measurements it cost: `Humanoid:EquipTool` on a LIVE humanoid takes the Tool every time -- a
  handleless Tool is equipped anyway and then bounces out, putting the Tool back after the call is
  too late (`task.spawn` runs the loop's first iteration synchronously), and a Tool parented to
  `ServerStorage` is moved into the character from there. The window the retry exists for is the
  placement respawn, and only a respawn makes it. What claim 2 pins is the loop's own counter, which
  is the next best thing and which the counterfactual run proves is load-bearing.
- **Standing rule A was run in DEV, not in the Forest Test.** This change is test-only and the Forest
  Test place is closed; the gate's own Play in DEV is the ≥ 80 s session, and it reports the gun in
  the character through `weapon_equip.spec` itself (`now 3->4, late 3->4`) and `match_live`'s note.

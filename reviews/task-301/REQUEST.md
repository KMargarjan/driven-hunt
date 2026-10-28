# Task 301 -- `Weapon.setStandProvider` hands back the provider it replaces

Task: 301
Round: 1
Base: task-298b4-range-menu @ 89e7068b
Code commit: ec81b7681392addbc68d2faa9d720e285bc8399f

```
[harness]  PASS: 34/34 checks @ ec81b7681392addbc68d2faa9d720e285bc8399f (clean tree) scope=all
```

`test2` is N/A: `agents.needs_two_player` returns `[]` for this change's four files (no
`TWO_PLAYER_PATHS` entry is touched -- `Weapon`, `Range`, `RangeBoot` and `range.spec` are none of
them).

## What changed

1. `Weapon.setStandProvider` now returns the provider it replaced -- the exact shape
   `setArmingPolicy` / `setDriveOpenProvider` / `setEntitlementProvider` already have. It was the one
   setter of four that returned nothing, so `RangeBoot`'s composition captured a nil base and the
   composed provider answered "no stand" for every player everywhere (task-298 RESULT finding 1).
2. `RangeBoot.compose`'s body moved into `Range.installOver(armFallback)`, which returns an
   uninstall. The boot calls it; so does the spec. Nothing else changed in what is installed.
3. `tests/server/range.spec.luau`: the weak hand-built case is RETIRED and replaced by one that
   installs a real base through `Weapon.setStandProvider` and composes through `Range.installOver`,
   plus a new case for the setter's return value.
4. `RangeBoot`'s prose claim corrected to name all four setters. `Range.standOver`'s claim
   (*"off the mat the base provider's answer is untouched"*) is now TRUE, so it is unchanged.

## FAIL FIRST, at `e7ef6d64` (the composition moved out, the setter still returning nothing)

```
[harness] FAIL: 32/34 checks @ e7ef6d64e49fa38aa5d6745a08845a83461d5553 (clean tree) scope=all
  2456 passed, 2 failed, 2 errors   <- exactly these two cases, nothing else
ServerStorage.Tests.range.spec:1238  Expected value "function: 0x..." (function), got "nil" (nil)
ServerStorage.Tests.range.spec:1269  Expected value "function" (string), got "nil" (string)
```

`range.spec:1238` is the return-value case (`expect(Weapon.setStandProvider(second)).to.equal(first)`).
`range.spec:1269` is the composed-base case (`expect(type(composedStand)).to.equal("function")` --
the composed provider cannot even be read back out of the owner while the setter returns nothing).
Both pass at `ec81b768`.

## Claims

1. `Weapon.setStandProvider` returns `previous`. Verify: `src/server/Weapon/init.luau`, that function
   -- `local previous`, assign, `return previous`, and the annotated return type.
2. Every shipped caller is unchanged and ignores the return value. Verify by grep for
   `setStandProvider`: `src/server/MatchBoot.server.luau` and `src/server/ForestTestBoot.server.luau`
   both still read `Weapon.setStandProvider(Match.standAreaFor)` in statement position (diff shows
   neither file touched); `src/server/RangeBoot.server.luau` no longer calls it directly;
   `tests/server/weapon_rules.spec.luau`, `weapon_shot.spec.luau` and `range.spec.luau` call it in
   statement position.
3. `Range.installOver` installs exactly what `compose` installed: the same four setters, the same
   four `Range.*Over` wrappers, the same self-referential base capture. Verify: `src/server/Range/init.luau`
   `Range.installOver` against `89e7068b`'s `RangeBoot.compose`. The one difference is that the arming
   fallback is a PARAMETER (`Shotgun.CONFIG.shouldArm`, passed by the boot) so `Range` gains no
   dependency on a gun's config.
4. `Range.installOver` returns the uninstall, which puts all four bases back. Verify: the returned
   closure in that function, and `range.spec`'s `expect(Weapon.setStandProvider(base)).to.equal(base)`
   after `uninstall()`.
5. The spec drives the SHIPPED composition, not a copy: it calls the same `Range.installOver` the
   boot calls. Verify: `range.spec`'s *"keeps the drive's stand off the mat..."* case and
   `RangeBoot.compose`, which is now four lines.
6. The composed provider keeps the drive's area off the mat and drops it on the mat. Verify the same
   case: `composedStand(away) == driveArea`, `Rules.outsideStand(mat, composedStand(away)) == true`,
   `composedStand(onMat) == nil`, `Rules.outsideStand(mat, composedStand(onMat)) == false`.
7. The old weak case is gone, not left beside the new one (L-028). Verify: `grep -c "hands back NO
   STAND AREA" tests/server/range.spec.luau` is 0, and the surviving pure-function assertion
   (`Range.standOver(nil)(away) == nil`) lives inside the new case.
8. LIVE in DEV, `RANGE` on, read off the gun's `StateChanged` wire
   (`<runs-dir>/301-live.out`, probe `<runs-dir>/301-live.luau`, built from B4's saved
   `298b4-zoneshot.luau`):
   ```
   ON THE MAT at -560, 5.149998664855957, -700
   OFF THE MAT at -520, 5.149998664855957, -660 (moved 56.6 studs)
      tool in the character: Shotgun
      OFF-MAT SHOT: server said refused=off-stand notice=NOT IN YOUR STAND
      BACK ON THE MAT: server said nothing (allowed)
   ```
   The off-stand refusal is the gate finding 1 proved was DEAD server-wide: with the base lost it
   could never fire for anybody. It fires now, from the composed provider, in a world with `RANGE` on.
9. `tools/studio_mcp.py selftest` and `tools/agents.py selftest` both pass (rule G); no new spec file
   was added, so `SCOPE_SPECS` is unchanged.
10. Lint and format clean: `selene src`, `selene --config tests/selene.toml tests`,
    `stylua --check src tests` -- 0 errors each.

## What I could not verify

**The mat half of the live proof is NOT OBTAINABLE in DEV this session, measured.** With `RANGE` on
and Play running, `Workspace.Range` and `Workspace.RangeTargets` both had **0 children**
(`<runs-dir>/301-mat.luau`), so no mat and no target existed: the probe's first half reported
`trunk nil  chest part nil` and the board stayed `no shots yet`. So SHOTS/HITS could not be moved and
the "one shot from the mat still lands" reading is not in this round. What IS in it is the half this
task is about -- the off-stand refusal above, which is the rule finding 1 killed -- plus the on-mat
`composedStand(onMat) == nil` path in the spec. Nothing in this step has been seen in Karen's place:
`RANGE` is born OFF and nothing is merged.

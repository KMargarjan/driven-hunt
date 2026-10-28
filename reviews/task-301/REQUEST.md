# Task 301 -- `Weapon.setStandProvider` hands back the provider it replaces

Task: 301
Round: 2
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
8. LIVE in DEV, `RANGE` on, ON THE REAL MAT -- round 1's reading was taken at the spawn point, where
   `Range.spotAt` answers nil for both positions, so the Reviewer was right that it survived the
   change's deletion. Retaken at `x = 1200, z = 0` (`map:v1`'s own anchor row), probe
   `<runs-dir>/301-live2.luau`, output `<runs-dir>/301-live2.out`, in a session whose log carries
   both boot lines:
   ```
   [range] built in 0 ms (5 parts)
   [RangeBoot] the range's three relaxations and the four guns on loan are composed
   ```
   ```
   world anchor 1200, 0, 0  mat 1200, 0, 0
   teleported to 1200, 4.149999141693115, 0
   trunk Boar2  chest part ZoneChest1
   attempt 1: aimed at 1200.03, 2.14, 125.00 (ZoneChest1) | my ray crossed Boar2 | server said nothing
      SHOTS 1   HITS 1   MISS 0  //  HEAD 0  CHEST 1  BODY 0  REAR 0  LEGS 0  MISS 0
   ON THE MAT at 1200, 4.149999141693115, 0 onMat=true
      ON-MAT SHOT: server said nothing (allowed)
   OFF THE MAT at 1240, 3.149998903274536, 40 onMat=false
      OFF-MAT SHOT: server said refused=off-stand notice=NOT IN YOUR STAND
   ```
   `onMat` is `RangeData.spotAt(anchor, position, LAYOUT) ~= nil` read at each position, so the two
   sides are the mat and off it by the owner's own measurement. THE ASYMMETRY IS THE PROOF AND IT
   DIES WITH THE CHANGE: with the base lost (the state at `89e7068b`) the composed provider answers
   nil for every player everywhere, `Rules.outsideStand` answers false by its own first line, and the
   OFF-MAT shot would be ALLOWED like the on-mat one. It is refused. The mat shot also LANDS --
   SHOTS 1, HITS 1, CHEST 1 off the board -- so the on-mat relaxation is intact.
9. `tools/studio_mcp.py selftest` and `tools/agents.py selftest` both pass (rule G); no new spec file
   was added, so `SCOPE_SPECS` is unchanged.
10. Lint and format clean: `selene src`, `selene --config tests/selene.toml tests`,
    `stylua --check src tests` -- 0 errors each.

## What I could not verify

Nothing in this change has been seen in Karen's place: `RANGE` is born OFF, `Range.ANCHORS` has no
`forest-test` row, and nothing is merged. Both live readings above are DEV ONLY.

Round 1's non-blocking notes, answered: claim 3's wording is corrected here -- there is a SECOND
difference from `89e7068b`'s `compose`, `armFallback(player) == true` where it had
`Shotgun.CONFIG.shouldArm(player)` raw (behaviour-identical today, since that function is
`return true`). The two notes about the spec case (the `uninstall` assertion leaning on the
return-value case, and the span between `installOver` and `uninstall`) are queued in `TASKS.md`
rather than fixed: the round cap is 2 and the code commit is already evidenced.

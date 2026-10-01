# Task 99 -- the new shotgun, round 2: the breech is open and the rise is counted once

Task: 99
Round: 2
Base: main (`2026eee`)
Code commit: 123202206eeb90dfc76e9879ab46d0cecf46a447

```
[harness]  PASS: 34/34 checks @ 123202206eeb90dfc76e9879ab46d0cecf46a447 (clean tree)
[harness2] FAIL: 28/34 checks @ 123202206eeb90dfc76e9879ab46d0cecf46a447 (clean tree)
```

**THE TWO-PLAYER LINE IS NOT A PASS, AND THIS REQUEST IS NOT READY TO REVIEW UNTIL IT IS.** It is a
capability refusal in the harness's OWN staging step -- `execute_luau` could not invoke
`PlayerScripts.Camera.LookAtRequest` -- so `shoot-the-boar` was never aimed and four specs failed
waiting for a shot that never happened. Reproducible twice at this commit; one player is green at
the same commit and stages the same scenario through the same function. `ESCALATE.md` (top entry)
has the evidence and the two things to try.

## Claims (round 2 only; round 1's five stand)

1. **The breech shows two open bores.** The `BreechFace` plate that buried both discs -- and that
   the fed shells slid through -- is gone; a Cylinder's rear end is already the flat face, and the
   breech disc now sits DEEPER than `Gun.chamber` seats a shell, so an empty chamber reads dark and
   a fed one shows the shell in front of the dark. Verify: `gun.spec`, "lets you SEE both openings"
   -- nothing in the BARREL GROUP may stand in front of a bore (the group is the right scope: the
   break-open is what separates the barrels from the standing breech).
2. **The old case could not have caught it, and the new one can.** A disc sealed inside an opaque
   plate still satisfies "inside its tube". Verify: the new case found a second defect on its first
   run -- its own box arithmetic treated a Z-lying cylinder's `size.X` as a width, so it reported
   the left muzzle bore as hidden by the right barrel. The test was wrong, the gun was not; commit
   `1232022` fixes the test.
3. **The muzzle flash is on the bore line, for both guns.** `Gun.muzzle` is back on the Handle's
   axis (`= MUZZLE_OFFSET` exactly), and `Gun.barrelOffset` is the one definition of this gun's bore
   line -- sign from `Shotgun`, magnitude this gun's own 0.076. `Viewmodel.muzzle` picks the offset
   from an attribute the BUILDER wrote on the model, so no caller can hand it the wrong gun.
   Verify: `gun.spec` (pure: the flash lands exactly on the tube's axis) and `gun_client.spec`
   (live: inside the drawn tube, and the OLD gun's flash exactly where it has always been).
4. **MUTATION CHECKED.** Putting `Gun.muzzle` back on the bore line failed four assertions across
   both files -- `gun.spec` (the attachment, the exact bore line, the occlusion count) and
   `gun_client.spec` -- then restored.
5. **One definition fixed a note for free.** `Gun.chamber` took the whole of
   `Shotgun.barrelMuzzleOffset` (the MESH gun's 0.09), so the shell sat 0.014 studs off this gun's
   bore line while both tests bounded it only by the tube radius. It is exact now, bound 1e-6.

Not verified: the two-player run (above). The rest of the Reviewer's round-1 notes are queued as
`TASKS.md` row 99a(f), unfixed.

# Task 99 -- the new shotgun: exact metal, Karen's walnut, a real hinge, and the white glove

Task: 99
Round: 3
Base: main (`2026eee`)
Code commit: 62385a20c01702ac5b29dd52e8ac6f8800b4b38c

```
[harness2] PASS: 34/34 checks @ 62385a20c01702ac5b29dd52e8ac6f8800b4b38c (clean tree)
[harness] PASS: 32/32 checks @ 62385a20c01702ac5b29dd52e8ac6f8800b4b38c (clean tree)
```

Task 101 (PR #90, PASS) is merged into this branch and is out of this review's scope. Behind
`NEW_GUN`, born OFF, **first person only**; both guns are driven by parameter, so every spec drives
both while the flag sits off.

**The break-open capture** (`.screenshots/20261002T012118Z-pose-reload.png`, `NEW_GUN` on, the
shooter's client): the two blued tubes hang down to the left on the pin and **each chamber mouth
carries a brass ring** -- the two seated shells' rims, where round 2 showed nothing at all. The
action and the stock behind it render as one near-white wedge across the right half of the gun, with
the brown walnut forend and the dark gloves on the left.

## Claims

1. **The bore discs are OUTSIDE the tube now, which is the whole of round 2, finding 1.** A Part is
   an opaque closed solid, so the inset discs drew nothing. All four stand `BORE_PROUD` = 0.002 out
   of their own end face and bite 0.001 back in so no two drawn faces are coplanar. Verify:
   `gun.spec` "show two dark openings ... PROUD of its own tube's end face" asserts the direction BY
   SIGN (a magnitude cannot: 0.002 in and 0.002 out are the same distance), and the occlusion case
   **no longer excludes a disc's own tube** -- the one part that was burying it.
2. **A seated shell's brass RIM sits at the chamber mouth.** `Gun.chamber` is now that mouth --
   `Gun.SHELL_RIM_PROUD` = 0.005 outside the breech face and in front of the 0.002 dark disc it
   covers, so brass at the mouth is loaded and the dark disc is empty. The body stays in the tube,
   unseen, as on a real gun. Verify: `gun.spec` "seats a shell's RIM ... OUTSIDE the breech face"
   and "backs the shell off its rim by its own length"; the run's notes read "rim seats 0.0050 studs
   out of the breech face (disc 0.0020 out)".
3. **One owner for the shell's length.** `Gun.shellLayout` is the only place that says where a
   shell's body, base and rim are and how far behind its pivot the rim's face is; `makeShell` draws
   from it and `chamberOffset` seats from it, so the two cannot disagree. It also APPLIES the
   offsets `makeShell` computed and dropped (round 2 note), which is why a shell had no brass head
   at all. Verify: `gun_client.spec`'s shell case measures the DRAWN rim against `shellLayout().back`
   and the seat against the DRAWN tube's own half length.
4. **MUTATION CHECKED, once.** Putting the old inset positions back (`+0.012` / `-0.17`, chamber at
   `breechZ - 0.10`) failed four server cases -- the proud discs, the occlusion, the rim's seat, the
   shell's back-off -- and one client case, then restored. The first gate run at `73fa4fd` FAILED on
   two of the new bounds: a `CFrame`/`Vector3` holds float32, so 1e-9 against double arithmetic is
   not a bound any correct number passes. `62385a2` is that diagnosis, at 1e-6, with the reason
   written where it bites.
5. **Two cases that passed for the wrong reason are gone (round 2 notes).** The flash's "at the
   MUZZLE end" was `never.to.equal(0)`, which the breech end satisfies too; it is now the sign and
   the distance. The fed shell's bore line was bounded by the tube's own radius, 0.0725 -- five
   times the 0.014 the OLD `chamberOffset` is out by, so it passed with the new gun's branch
   deleted; it is 1e-3 now. Neither new rim assertion is "the drawn rim is outside the tube right
   now", because a shell still travelling in satisfies that whatever the seat is: that one is a
   note, not an assertion.
6. **`pose.py compare` takes `--client <name>`.** The capture above could not be taken without it:
   with two players `compare` photographed whichever client answered first, and that was the DRIVER,
   who carries no gun. Verify: `tools/pose.py` `run_compare`, and `python tools/pose.py selftest`
   (CI).

Not verified: whether the gun LOOKS right. It does not yet -- the capture says how, and the action
and stock reading near-white is the biggest part of it. Those are `poses.json`'s `newGun` set,
`Gun.LOOK`, and whether the stock mesh's texture is drawing at all; queued in `TASKS.md` row 99a
with the rest of the round-2 notes, which are unfixed by the Director's instruction.

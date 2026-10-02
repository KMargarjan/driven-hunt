# Task 107 — model B was assembled backwards: the stock sat at the muzzle end

Task: 107
Round: 3
Base: `main` (`65d1c14`)
Code commit: `6715643bf0e885a6d54ddac89392db2dbeac8089`

```
[harness] PASS: 32/32 checks @ 6715643bf0e885a6d54ddac89392db2dbeac8089 (clean tree)
[harness2] N/A: every changed code file is first-person viewmodel
          (src/shared/Gun/init.luau, src/client/Camera/Viewmodel.luau,
           tests/client/gun_client.spec.luau) -- WEAPON_VIEWMODEL_PATHS, Director 2026-10-02.
          `python -c "import agents; agents.needs_two_player(...)"` answers `[]`.
```

Round 2's finding was right and the engine fact behind it is right: `Model:PivotTo` lands the PIVOT,
and with `PrimaryPart` set the pivot IS that part — so the half turn written onto the cloned part was
overwritten on the frame it was made. Rounds 1 and 2's notes are queued as `TASKS.md` row 107a.

## Claims

1. **The turn now lives where every shell is PLACED**, composed with the quarter turn rather than
   fighting it, chosen by the same `shellIsMesh` condition `shellBack` uses — one question, asked
   once. `Gun.MESH_FILE_TURN_DEG` is exported so the drawn shell's quarter turn stops being a literal
   at that site (round 2's note). Verify: `Viewmodel.shellTurnDeg`, `Viewmodel.shells`, `makeShell`.
2. **The spec measures the DRAWN INSTANCE, and it was mutation-checked.** In the barrels' own frame
   the cartridge's brass axis must point at +Z — toward the breech face and the shooter. Ran:
   `task107 fresh shell 1: its brass axis points (0.000, -0.000, 1.000) in the barrels' frame`. With
   the import turn removed the same note read `(0.000, 0.000, -1.000)` and the case FAILED at
   `gun_client.spec:357`; restored, it passes. It stands in a template for the reason task 106's
   flag-OFF guard does, and destroys it again.
3. **The gate's first run of that case caught me, not the code.** It asserted the shell's CENTRE sits
   forward of the chamber mouth and failed at 0.853 against a mouth at 0.522 — because
   `Viewmodel.shells` slides a fresh shell in from `feedFromStuds` behind the seat, so the centre is
   only forward of it once seated. The claim with no clock in it is that the brass end is at or
   behind the mouth the whole way in: `brass end 0.9211, chamber mouth 0.5215`.
4. **LOOKED AT (rule 5): `.screenshots/20261002T124816Z-reload-seated-fresh.png`.** The gun is broken
   open, barrels tilted down-left, stock and action at the lower right; TWO red shells are at the
   breech end of the tubes, each with its **brass head toward the upper right — out of the chamber,
   toward the shooter — and its red hull running down-left into the tube.** One is nearly home, one
   still travelling. `...124757Z-reload-seated.png`, half a second earlier, shows the SPENT shell in
   mid-air the same way round.
5. **The flag-OFF build is untouched.** The drawn shell still takes the quarter turn alone, which is
   `Gun.MESH_FILE_TURN_DEG` = 90 — the literal that was at that site before. Nothing else outside
   `Gun` and the `NEW_GUN` branches changed.

## What I could not verify

- **Whether the import HALF-TURNS the model or MIRRORS it** — indistinguishable on a gun this close
  to symmetric. A half turn is what the correction applies, and `Gun` says so.
- **The capture is of the FEED, not of a shell at rest**: both frames catch shells in motion, which is
  what a reload is. The brass-head-out orientation is the same in both.
- Row 107a's remaining notes (the `gun.shell` row comment, the fallback-box case's wording, the
  `assets_seam` comment) are queued, not done.

# Task 328j -- the bake's two fixes, then C1's bake

Task: 328j
Round: 1
Base: 6b520717 (origin/main)
Code commit: 89d9c5b10064a28e1922c7edfa1c586dbd2f4ead

```
[harness] PASS: 34/34 checks @ 89d9c5b10064a28e1922c7edfa1c586dbd2f4ead (clean tree) scope=all
```

`test2` is N/A: nothing here is in `TWO_PLAYER_PATHS` (the bake is the map and the tools).

**What this covers.** The whole branch against `main`: task 328d (the bake tool, the Luau, the
cases) plus 328j, which is exactly the two blocking findings of `reviews/task-328d/RESULT.md` round
3, plus Director decision 3 of `ESCALATE.md`'s 17:05 UTC entry. 328d's own request is
`reviews/task-328d/REQUEST.md` and its claims still stand; the claims below are 328j's.

## Claims

1. **The CI selftest no longer touches a Studio, proved with CI's own condition.**
   `tools/terrainbake.py` `selftest` calls `command_plan(argparse.Namespace(cells=["A1"]), facts,
   None, None)` -- the transport is two arguments and both are `None`. Verify:
   `LOCALAPPDATA=/nonexistent python tools/terrainbake.py selftest` exits **0** and prints **78
   PASS** lines. Before the fix the same command exits **1** after **19** lines (`StudioMCP.exe not
   found under %LOCALAPPDATA%\Roblox\Versions`), because `main`'s `plan` branch builds `Studio()` and
   `SystemExit` is not an `Exception`. No other `main([...])` case in the selftest reaches a Studio:
   `bake`/`archive` with no `--cells` is refusal 6 and an unknown cell is refused, both before
   `facts` is read.
2. **That case now asserts the count instead of printing it.** A second case sets
   `EXPECTED_TILES["A1"]` to a wrong number and requires `command_plan` to answer **2**, restoring it
   in a `finally`. Verify: delete the `elif count != expected: return refuse(...)` arm and the new
   case fails while the old one still passes.
3. **Design 7.1's junctions are pinned, in closed form, and the pin is exact.**
   `TerrainBake.junctionPins` gives a north-south road one pin per crossing at the **east-west
   crown**; `pinnedSamples` holds every sample within `pinWindowStuds()` = carriageway + one sample
   step = 40 st of it; `longProfile`'s pin stage builds `upper`/`lower` cones of `rise` a sample from
   the held samples and clamps the profile into that band. Verify: case **328j-1** reads `pinStuds`
   **0.0000** at all four of C1's crossings, and in Karen's place the tool printed the same (claim
   7). The band is why it is exact: the median of three functions Lipschitz in `rise` is Lipschitz in
   `rise`, and the band is zero-width at a held sample.
4. **The first attempt at this was wrong and the comment says what it measured.** The existing
   min-cone sweep can only LOWER, so a crossing above the ground each side is never met: iterating
   (restore the pins, sweep) left the pin **2.75 st** out on NS3 and **7.55 st** on NS4 in Karen's
   place. Verify: `ESCALATE.md`'s 328j entry quotes that run; the `longProfile` pin-stage comment
   carries both numbers and the reason.
5. **A pin the ground cannot carry is dropped and SAID, never forced.** `pinCost` is set when the
   band is empty, or on the last attempt when pinning costs more cut-or-fill than the axis cap AND
   more than not pinning; a breach line then names the road. Verify: case **328j-3** on the
   Reviewer's own base (east-west lines 60 st down) reads `NS3: pinning its junctions needs 60.0 st
   of cut or fill, over the 20-st cap, so this road is NOT pinned`, and `worstCutFill` is back inside
   the cap. Forcing it instead is what sent a flank's bank 165 st into a tile it has no business in:
   **328d-17** failed at `worst 16-st window 454.687` against a `5.824` ceiling while that was in,
   and reads **5.824** now.
6. **The E-W profile wins inside the junction square, and only there.** `roadAt` keeps the nearest
   centreline **per axis** and prefers the `x` one when both are within `carriagewayStuds`. Verify:
   case **328j-1** reads a point at (+4,+12) from the crossing -- where the nearest centreline is the
   north-south one -- as **147.8800**, the east-west section's own value to 1e-9; the square's
   diagonal (+5,+10) against (+10,+5) differs by 0.05 st, inside the crown fall; and 500 st up the
   same road the north-south crown wins again at **160.00**. Delete `inSquare or` from the condition
   and the first of those fails.
7. **Measured at C1's four crossings in Karen's Forest Test, at the code commit.**
   `TerrainBake.junctionSteps` prints the pin, the worst height difference between voxel-adjacent
   columns on the junction square (plus one voxel past it, minus the corner on neither carriageway
   and anything past either road's end), and what the east-west crown's own rise across the square
   explains. From the `measure --cells C1 --tiles 1` run at this commit, injection route:

   | crossing | pin | worst voxel step | E-W rise over the square | explained |
   |---|---|---|---|---|
   | EW2 x NS3 | 0.0000 | 0.6801 | 0.6801 | 0.8801 |
   | EW2 x NS4 | 0.0000 | 0.4132 | 0.4132 | 0.6132 |
   | EW3 x NS3 | 0.0000 | 0.8466 | 0.8466 | 1.0466 |
   | EW3 x NS4 | 0.0000 | 0.2007 | 0.2007 | 0.4007 |

   Every step **equals that crossing's east-west rise to four decimals**, which is the derivation:
   the north-south crown is pinned flat across the square while the east-west one keeps climbing, so
   the residual is the east-west road's own grade and not a discontinuity. Round 3 measured **60.00
   st** there.
8. **`cutFillStuds` is per axis, and 20 was walked rather than chosen** (Director decision 3).
   `x = 12` is design 7.1's and the east-west roads keep it. The realised **grade in per cent** each
   north-south cap buys, each from its own `measure` run in Karen's place: **12 st -> NS3 20.00, NS4
   20.00 · 16 -> 16.00, 12.00 · 18 -> 12.00, 10.00 · 20 -> 10.00, 10.00**. 20 is the smallest under
   the 12 % the decision asks for and is its own hard ceiling. The **cut in studs** it realises:
   **NS3 19.75, NS4 17.21**, both inside 20, and neither road relaxes any more. Verify: case
   **328j-2** walks a cliff height until the cut is over the east-west cap and inside the north-south
   one, then requires `relaxed == false` and no breach; the same cut on a hunter line relaxes. With
   one scalar cap the first of those fails.
9. **What this does NOT fix, measured and printed, not hidden.** Pinning a junction flat over 80 st
   on a 10 % hillside kinks the grade: NS3 and NS4 now print `grade change 10.00 % over 60 st, over
   the 2.40 % allowance` as breach lines. Before the pins they printed `20.00 %` at a 12-st cap and
   the grade itself was 15.73 / 13.47 %. EW3's 2.41 % against 2.40 is unchanged from 328d. Verify:
   the breach list of the final `measure` run, quoted in `ESCALATE.md`'s 328j entry.
10. **The gate and the lint.** `tools/agents.py selftest`, `tools/studio_mcp.py selftest` and
    `tools/terrainbake.py selftest` all pass; `selene src`, `selene --config tests/selene.toml tests`
    and `stylua --check src tests` are clean. No new spec FILE, so no `SCOPE_SPECS` row is needed.

## What I could not verify

* **`deer_hitbox.spec:682` failed on the first run of this commit and passed on the second**, both
  clean-tree at `89d9c5b1`: `FAIL: 32/34 ... (clean tree) scope=all`, then
  `PASS: 34/34 ... (clean tree) scope=all`. The dispatch names `deer_hitbox.spec:659/:682` as a known
  intermittent. One of two runs, and nothing in this change touches a deer or a hitbox.
* **Design 7.1 still says "cut-or-fill <= 12 st" for both axes.** The per-axis cap is the Director's
  decision 3, not the design's; `docs/design/grid-terrain.md` is the Architect's file and is not
  touched here. Queued in `TASKS.md` under 328j.
* **The bake itself.** At the time this request is written no `WriteVoxels` has run in Karen's place
  in this task. The bake and its before/after measurement follow this review, as `ESCALATE.md`'s
  17:05 UTC decision 4 orders; everything measured above is read-only.

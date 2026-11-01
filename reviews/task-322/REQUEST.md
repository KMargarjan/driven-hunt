# Task 322 — a station is the E and a rectangle on the ground

Task: 322
Round: 1
Base: 2615879a (main, 313–321 merged)
Code commit: 0e30e865933ec4250f07571f40fbf9d6695f48be

Karen, 2026-10-31, after playing 320: *"also remove this roof in shooting range we dont need that
eather keep just this e and one line or row where it can go or recatange not need thos 4 columns
and roof and platform"*. CORE-NA: range props only — ballistics, the animal, the pass loop (321)
and the board are untouched, so the Core Quality Protocol's Steps 0–3 are N/A for this task.

```
[harness] PASS: 34/34 checks @ 0e30e865933ec4250f07571f40fbf9d6695f48be (clean tree) scope=all
```

`test2` is **N/A**: `needs_two_player` on this branch's changed paths returns `[]` — no path is in
`TWO_PLAYER_PATHS`. Karen's Forest Test was open (Edit, never Play) in a second Studio during the
run; the harness pinned the DEV place (`report comes from the DEV place (136410205938347)`).
CI green on the code commit: run 41261639177.

## Claims

1. **The hut is gone: four columns, roof, fascia board — and the bench rest with them.**
   `src/server/Range/Build.luau`, the station loop: the whole `layout.HUT` block and the
   `RangeData.benchName` call are removed. Verify by name in `tests/server/range.spec.luau`,
   `"builds a bare station: the post inside the sight bound, and not one hut part"` — it asks the
   folder for `Roof<n>`, `Board<n>`, `Bench<n>` and `HutPost<n>_1..4` and requires `nil` for all
   42. The same six names are asserted absent in `"lays NOTHING at a station but its mat and its
   post"`. **Each fails on main**, where every one of those parts exists.

2. **The bench was a prop, and that is a reader, not an opinion.** `grep` for `benchPosition` /
   `benchName` across `src/` at the base: the only callers are `Range.Build` itself.
   `Range.distanceFor` adds nothing for `POSITION.BENCH` (only `TREESTAND` adds `backStuds`), and
   `Range.spotAt` returns `POSITION.BENCH` off the **MAT's** box (`layout.MAT.size.X/Z`), never off
   the bench part. So removing the part changes no shooting rule. The word `bench` survives as
   `Range.POSITION.BENCH`, untouched.

3. **The rectangle is flush — no step up.** `src/server/Range/Build.luau` lays the mat through
   `groundUnder` + `makePart` at `matHi + layout.MAT.liftStuds - size.Y/2` (the `TURF` slab's own
   trick) instead of through `onGround`, which grew the slab downward from its own top and left a
   full stud of kerb. Verify: `range.spec`, the no-plate case (`matTop` vs `137.5 +
   LAYOUT.MAT.liftStuds`) and the ground sweep's `^Mat%d` arm, which samples a 9×9 grid of the
   ground under the footprint on **flat and sloped** ground and asserts `top - hi < 0.5`. That line
   reads 1.0 on main. **Measured live in Karen's place at the code commit: `Mat2 top=150.120
   ground=150.000 step=0.120`.**

4. **`MAT.size` did not move, because it IS the station box.** `Range.spotAt` measures
   `MAT.size.X/2` and `MAT.size.Z/2`; only `liftStuds`, `color` and `material` were added.
   `range.spec`'s layout roll-call still asserts `Vector3.new(8, 1, 8)`.

5. **The station's number is on the post, on both faces.** `Range.boardText` → **`Range.
   stationNumberText`** (one answer, as before); `makeBoardFace` → `makeNumberFace`, now parented to
   `postPart` with `RangeData.NUMBER_GUI_NAME`. Verify: `"prints each station's own number on its
   post, on both faces, and no board at all"` — three stations, `Front` **and** `Back` present as
   two different faces, text equal to `stationNumberText(spot)`, and `Board<n>` `nil`. **Chosen over
   painting it on the ground**: a digit on the 8×8 pad is foreshortened to nothing from the walk-up,
   a vertical face he walks toward is not. Frame `322-a-zoom.png` shows **1 2 3** readable.

6. **`LAYOUT.HUT` is kept as UNBUILT DATA, clearly marked — and that is required, not laziness.**
   Two live readers measure the safety geometry off it: `Range.bayHalfSlope` (his bay's opening,
   which `sightSpanFor` reads, and through it the mask, the shot's door and the crossing window) and
   `Range.sightlineFrom` (the X span a tree may not stand in, task 315). Deleting the table would
   move the animal's window, which this task does not touch. Same precedent as `LAYOUT.STAND` (task
   320). Only `boardSize` and the four colours were removed from it. **T6 re-asserted:**
   `"keeps the prompt post inside its own station's bay"` asserts `bayHalfSlope == 5.6/10.5`,
   `sightHalfWidthAt(0) == 0` and the crest identity against `backstopSpanFor` — all unchanged.

7. **A REFUTED claim, reported in the round that wrote it (V293).** Round 1's first draft asserted
   *"the prompt post is out of every line of fire"*. The gate refused it, and it is **false on main
   too**: at the post's Z (7 ahead) the bay's fan reaches 3.73 studs off axis and the post spans
   2.4…3.6. The true property — and the one task 322 may not move — is that the post is inside
   **his own** bay (outer face 3.6 ≤ `bayHalfSlope × 7` = 3.733, margin 0.13 studs), hence never in
   a neighbour's line of fire. That is what both the pure case and the built case now assert, with
   the refutation written into the case. See the commit message of `a6db4631`.

8. **Part census, as arithmetic.** `range.spec` now expects `1 + 2 * SPOT_COUNT + 3 + #turfSlabs`
   = **28** in DEV, where main builds 59; `src/server/Range/init.luau`'s `MAX_PARTS` comment carries
   the same arithmetic. Two further counts moved with it and are named so they are not mistaken for
   drift: the gravel strip covers `SPOT_COUNT * 2` parts (was 3 — the bench), and the ground-read
   floor is `5 * 2 * SPOT_COUNT` (five samples per part, two parts per station).

9. **Rule 7: archived, and the archive was checked, not assumed.** `backups/task-322/` holds the
   removed `Build.luau` block and every removed shared symbol, plus a `README.md` restore recipe.
   All 13 removed symbols are present; `function`/`end` balance verified (9 defs, 11 ends, 2 `for`
   loops; the Build fragment ends on its own `table.insert(mats, mat)`). This was checked **because**
   `backups/task-320/Build-treestands-removed.luau` is reported broken (320a(a)); the recipe here
   names the one rename (`boardText` → `stationNumberText`) and says no `require` changes either way.

10. **Docs and comments swept, not just specs (L-071).** `docs/design/shooting-range-lobby.md`: five
    places that described the hut as built are corrected (§7.1's corridor decision, the orphan-parts
    table, the §13 source note, §15.1's span case, §15.4's "station 3's bench"). In code,
    `Build.luau`'s treestand paragraph and its fence paragraph, and `Range.LAYOUT`'s "THE LOOK"
    header, no longer describe a hut that is built. `grep -riE "hut|roofed|fascia|bench"` over
    `docs/design/shooting-range*.md` and `src/server/Range/`, `src/shared/Range/` returns only
    history that is explicitly dated to 320/322.

## Rule 5 — frames in Karen's place, at the code commit, looked at

The Forest Test worktree `driven-hunt-294` was checked out to `0e30e865` and served on rojo :34874;
her Studio was switched to :34874, played, and **switched back to :34873 and reconnected** (frame
`322-restore-crop.png` reads `DrivenHunt localhost:34873`, Disconnect showing). No ServerStorage
attribute was read or written.

* `322-a-approach.png` / `322-a-zoom.png` — the shop-door approach, eye ~3.5 studs over the pad.
  Three pale rectangles lying flat on the mown grass, three slim dark posts carrying **1**, **2**,
  **3** in white, the earth berm behind. No roof, no columns, no fascia board, no bench, nothing
  above post height anywhere on the line.
* `322-b-station2.png` — the shooter's eye standing ON station 2's rectangle. The pale pad is flush
  under his feet; the post carries the **2** and the `E · SHOOTING RANGE / RANGE` prompt; the sky
  and the lane above it are completely open.
* `322-c-panel.png` — a **real E keystroke** (`298key.ps1 E`, after one focusing click) at station 2
  opens the SHOOTING RANGE panel, with THE BOARD under it. The board reads `SHOTS 1` because the
  focusing click fired one round; the range is free and ammo endless, so nothing else moved.
* Live probe at the code commit, her place: `PARTS Mat=6 Post=6 Turf=1` (no `Roof`, `HutPost`,
  `Board` or `Bench` anywhere in `Workspace.Range`), `Mat2 colour=214,210,198
  material=Enum.Material.Concrete`, `Post2 guis: StationNumber[Front]="2" StationNumber[Back]="2"`,
  `Post2 prompt=RangePrompt2 action=RANGE key=E`, `tallest non-earth part: Post1 top=154.00`
  (the roof stood at ~159.6 on main).

## Could not be verified

* **The banks and the berm are terrain in Karen's place**, so the live part census cannot show them
  — they appear only in the DEV build, where `range.spec` asserts them unchanged (`1 + … + 3`).
* **No two-player evidence**, and none is asked for (`needs_two_player` → `[]`).

ANSWERED: L-136 — the named flake `weapon_shot.spec.luau:1490` did not fire in any of the three runs;
the final run is a clean 34/34 with no FAIL line at all, so no flake wording appears in this request.
ANSWERED: L-127 — every claim above is MET and carries its instrument; the two items nobody can see
on screen are listed under "Could not be verified" rather than asserted. The one refuted claim is
claim 7, stated as refuted in the round that wrote it.
ANSWERED: L-162 — every live proof (the probe, all three frames) was taken in Karen's place against
the `driven-hunt-294` worktree checked out to the code commit `0e30e865`, on rojo :34874, after the
harness PASS at that same commit.
ANSWERED: Rule 5 — I opened and described each of the four frames above; claims 3, 5 and the
approach/station views are each tied to the frame that shows them.

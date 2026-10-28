# Task 298-B6 — the range in Karen's place: the forest row, the boot wiring, a range beside her lodge

Task: 298b6
Round: 1
Base: task-301-stand-provider @ 7905ca17
Code commit: 4b851d423917eb0c37d34e07d584ad731e81edd1

`[harness] PASS: 34/34 checks @ 4b851d423917eb0c37d34e07d584ad731e81edd1 (clean tree) scope=all`

Two players: N/A. `agents.needs_two_player` returns `[]` for every file in the diff — no
`TWO_PLAYER_PATHS` file is touched (Director 2026-10-03; the range is one player's).

FAIL FIRST, at `3f26cdf3ba9c9eb1b08eeec48f7ba1f510f4bbda` (the spec alone on top of 7905ca17):
`[harness] FAIL: 32/34 checks @ 3f26cdf3ba9c9eb1b08eeec48f7ba1f510f4bbda (clean tree) scope=all`,
server `2457 passed, 5 failed, 5 errors` — all five are this task's new cases, each erroring in its
own branch (`range.spec` lines 195, 1773, 1817, 1878, 1908: the row, the two-world build, the
measured rectangle, the lobby clearance, the gathering yard).

## What changed

1. `src/shared/Range/init.luau` — the `forest-test` row, from the Director's measurement; the
   `downrange` and `drawn` data fields; `Range.downrangeOf`; the sign threaded through
   `laneCentre`, `laneEnds`, `screenPosition` and `fieldFor` (default `+1`, so no existing caller
   moves).
2. `src/server/Range/Build.luau` — the lane, the plate, the screens and the berm take the sign off
   the row; the result carries `downrange`.
3. `src/server/Range/init.luau` — `state.downrange`, read ONCE at `start` and passed inward to the
   five arithmetic calls; `Range.shelfFor(row, groundAt)`, so a root can learn the shelf through
   the owner instead of keeping a second copy of the `plate` rule.
4. `src/server/RangeBoot.server.luau` — ONE root for both worlds: the world's own ground reader for
   a row with no plate, the shelf before the field, `groundAt` into the runtime's world and into
   `Range.start`, and the drawn-animal config for a row that asks for it.
5. `docs/design/shooting-range.md` — §3 "who starts it" (one root), the `downrange`/`drawn` fields,
   §7.4 rewritten to what ships (the THIRD relaxation, `Range.installOver` as the installer, the
   four providers) and the `Range.mayShoke` typo fixed.

## Claims, and how to verify each

1. **Karen's place has a row, and it is the one that was measured.** `range.spec`, "has a row for
   the DEV place": `x = 2650`, `z = -3216`, `plate = false`, **no `y`**, `downrange = -1`.
   The measurement is `<runs-dir>/evidence/b6-anchor/SUMMARY.md` (504 raycast samples, Edit and
   Play): best centre (2650, -3300), 0 non-terrain hits, spread 11.6.
2. **The direction is DATA, and both arms are entered.** `range.spec`, "lays every part on the
   ground it is handed, both worlds": the DEV row (+z, plate) and the forest row (−z, injected
   `groundAt`) go through the SAME `Build.build` call with the row as the only difference; each
   asserts `laneCentre(...).Z - anchor.Z == dir * DISTANCE_STUDS` and that the berm is downrange of
   the mat by more than the lane length. Red first at 3f26cdf3.
3. **Nothing is laid under the ground or floating.** Same case: every part's LOWEST face is on the
   injected shelf to 1e-3, except the plate, whose TOP is the shelf. Parts are named
   (`Mat`, `ScreenEast`, `ScreenWest`, `Berm`, and `Plate` in DEV) so the Director can enumerate
   them under `Workspace.Range` (L-086).
4. **The ground is read once, at the anchor, and only where there is no plate.** Same case: the
   fake reader records its calls; `#asked == 1`, at `(2650, -3216)`.
5. **The whole range is inside the rectangle that was measured.** `range.spec`, "keeps the whole
   range inside the rectangle that was measured". Harness note:
   `range forest footprint: x 2570.0..2730.0 z -3356.0..-3212.0 (measured x 2570..2730 z -3392..-3208)`.
6. **It stands clear of all seven lobby rectangles.** `range.spec`, "stands clear of all seven
   lobby rectangles": the three `Lobby.CONFIG.FIELD.PADS` rows and the four truck pads from
   `Lobby.Pads.centreFor` — read, never retyped — each a positive gap. Note:
   `nearest lobby rectangle is Road, 158.0 studs away`.
7. **`Match.lineIsUnsafe` refuses nothing from the Gather yard toward the lane.** `range.spec`,
   "refuses nothing a man in the gathering yard is doing": `Match.lineUnsafeFor` is false down the
   lane with a man standing in the Gather pad's centre, and TRUE when the same shooter turns and
   aims at him — so the rule is live, not switched off. Note: `309 studs from the mat, 276 of it
   downrange`.
8. **One root, and it learns its world the way `Lobby` does.** `src/server/RangeBoot.server.luau`
   still reads `Map.EXPECTED_WORLD` through `RangeData.anchorFor`; `ForestTestBoot` is untouched
   (`git diff --stat`), so there is no second caller of `Range.installOver` and no idempotency
   guard was needed.
9. **The prompt path is unchanged.** `Range.promptFor` / `setPrompt` are not touched: `Build` makes
   the same `RangePrompt` on the same `Mat`, at the forest anchor. The B2–B4 prompt and panel
   cases still pass (34/34).
10. **The design says what ships.** §7.4 now names the three relaxations and the loan,
    `Range.installOver` as the installer, and `Range.mayShoot` (the `mayShoke` typo is gone).

## What I could not verify

- **Nothing in Karen's place was played.** No FT session was mine (the dispatch reserves it). Every
  number above is DEV or arithmetic over her measured ground. The mat is at **x 2650, z −3216**,
  facing **south (−z)**; the lane's middle is at z −3341 and the berm at z −3353.
- The drawn target in her place (`drawn = true`) is reasoned from `ForestTestBoot`'s own rule for
  MODEL/CALM/PACE/MOVE, not seen on screen.

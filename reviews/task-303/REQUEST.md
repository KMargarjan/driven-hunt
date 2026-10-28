# Task 303 -- the range on Karen's path: four defects from the Director's real-key proof

Task: 303
Round: 2
Base: 0d65e55c (task-302-range-walkway)
Code commit: 59e0b2c9b08d7556cf1456d97803d2d5037e8902

[harness] PASS: 34/34 checks @ 59e0b2c9b08d7556cf1456d97803d2d5037e8902 (clean tree) scope=all

`tools/agents.py` `needs_two_player` returns `[]` for this branch's eight changed files (asked with
`git diff --name-only 0d65e55c..HEAD`): no match path, no drive, no tie, no team. The two-player
run is N/A, for the review round and for the PR to main.

## PLAN (core quality protocol, step 0) -- item 4, the WALK crossing

(a) REAL LIFE. A wild boar walks 4.5 studs/s at 1 stud = 0.28 m (`Boar.CONFIG.PACE.WALK_SPEED`);
    40 studs of open window is 8.89 s.
(b) MEASURED NOW. Karen's place, 0d65e55c, frame `<runs-dir>/evidence/p298/14-walk-crop.png`,
    opened and read by me: `PACE WALK  pace 4.5 studs/s  issued 4.5 studs/s  crossing 4.75 s`.
    **THE DISPATCH'S PREMISE IS REFUTED.** The issued speed IS 4.5 and the board prints 4.5 beside
    the crossing. 4.75 s x 4.5 studs/s = 21.4 studs -- a PARTIAL crossing of a 40-stud window, not
    a whole one at 8.42 studs/s. The body cannot outrun its setpoint: `Body.drive` writes
    `mover.PlaneVelocity`, a `LinearVelocity` velocity setpoint, which under-shoots under load and
    never over-shoots. The walk is NOT fast in her place; the CLOCK was started late.
    CAUSE, from source: `Range.setPace` cleared `trial.windowEnteredAt`, and `timeWindow` starts a
    crossing on any scan that finds the target inside with no entry time. Pick a pace while the
    target is inside the window -- which is what the Director did, picking WALK off a TROT -- and
    the next scan times the studs that were left. TROT (3.60) and RUN (1.73) matched because those
    frames were taken after a later, whole crossing had overwritten the short one.
    NOT the drawn model, NOT a shared movement row: the fix is in the range's own owner, which is
    what L-147/L-150 require.
(c) TARGET. The FIRST crossing recorded after a mid-window pick, within
    `Range.CONFIG.CROSSING_TOLERANCE` (10 %) of 8.89 s -- design TARGET 3.
(d) LEVER. `src/server/Range/init.luau`, `timeWindow` -- the one writer of `windowEnteredAt`,
    `lastCrossingSeconds` and `crossingSecondsByPace` -- plus its clearers `setPace` and `release`.
(e) HOW MEASURED AFTER. The same instrument: the trial's own `crossingSecondsByPace["walk"]`
    through `Range.trialOf`, in `range.spec` "times a WALK picked MID-WINDOW over the whole window".

## ITERATION (step 2) -- the instrument is the suite; three runs, all pasted

| cycle | change | measured | distance to target |
|---|---|---|---|
| 1 | the case asserts the LAST crossing after the pick | PASS against the OLD src: `FAIL: 30/34 @ 7154289e`, `range.spec:473` the only server line | the case does not bite -- a later whole crossing overwrites the short one |
| 2 | the case asserts the FIRST crossing after the pick, still old src | `FAIL: 30/34 @ fafe465a`, `range.spec:624` = `err <= CROSSING_TOLERANCE` false | the defect, reproduced |
| 3 | the arming field, new src | `PASS: 34/34 @ 2b8eab73`, 2471 server + 637 client cases green | target met |

## FAIL FIRST (all five claims; two runs, each at a commit that contains the cases)

- `[harness] FAIL: 30/34 checks @ fafe465a09014efdc9fc95ec023b0d877f341b8c (clean tree) scope=all`
  -- the five new cases against the UNCHANGED `src/` of the base. The failing lines, from the
  console: `range.spec:473` (no `Post`), `range.spec:624` (the mid-window crossing),
  `range_panel.spec:140` (the menu stayed open on confirm), `range_panel.spec:166`
  (`promptPosition` is nil), `range_panel.spec:362` (the board printed the wire word).
  `range.spec:639/686/728/767/809` are the cascade of the one case that threw before its own
  `Range.stop()` -- this file's existing shape, and all green in the passing run.
- The probe is in the branch's history on purpose: 7154289e reverts `src/` to the base and
  66a25d43 puts it back. `git diff 0c8773cd..HEAD -- src/` is empty.

## Round 1's two blocking findings, both right

1. **The "is he at the spot" signal.** `Hud.step` read `rangeMat.Parent` and expected the mat, so
   the prompt's move onto an attachment silently killed it -- the board wiped itself every frame
   and the door-closer never fired. `Range.promptPointOf` is now the ONE reader of a found prompt's
   point (attachment or part), the Hud asks it, and `Range.atSpot` is asked about THAT point rather
   than the mat's -- which also settles the reach: the engine offers E within 12 studs of the
   prompt and the client now closes at the same 12 studs of the same point, so the shell where one
   said yes and the other no is gone. `range.spec` "hangs the prompt on a POST" drives the real
   built folder through it: `promptPointOf(promptFor(1, folder))`, `atSpot` true at the mat, true
   one stud inside the reach, false one stud outside, plus the nil and part-parent shapes.
2. **`stylua --check`.** The round-1 comment was glued onto the `elseif` line. `stylua --check src
   tests` is clean at this commit.

The notes I also took: the `LAYOUT.POST` sight-line arithmetic is rewritten with the right numbers
(1.22 studs at the window's far end, 2.43 at the lane's, over a 4-stud post under a 5-stud eye),
`promptPosition`'s sign is corrected, the client note now prints the FOV it used, and
`docs/design/shooting-range.md` 7.2 says the prompt is on a post. The two notes I did not take are
listed under "What I could not verify".

## What changed

1. **The prompt is off the floor.** `src/shared/Range/init.luau` gains `LAYOUT.POST` and
   `Range.promptPosition`; `src/server/Range/Build.luau` lays a named `Post` through the same
   `onGround` every other part uses, at the mat's front edge and out of the lane of fire, with the
   prompt on a `RangePromptAt` attachment at its top -- `Lobby.Build.shopPrompt`'s shape.
   `Range.promptFor` still finds it by name, so nothing downstream changed.
   `Range.viewportPointOf` is the pure projection (the arithmetic `Camera:WorldToViewportPoint`
   performs) that the client case asks about Karen's viewport.
2. **The menu closes on confirm.** `RangePanel.confirm` calls `setOpen(false)` after a successful
   send, which is the one door-closer: the cursor and the input hold both come back under the
   "range" key.
3. **The board prints the cartridge.** `RangeBoard.ammoText` reads the gun row's own `AMMO_LABEL`,
   the ammo chip's own source. `record.ammo` is the WIRE word -- "Slug" on all three rifled guns,
   because `Boar.Wound.damageFor` branches on it.
4. **The crossing is timed from a real entry.** `trial.windowArmed`: armed by being outside the
   window, spent on the way in, cleared by `setPace`.

## Claims (each with how to verify it)

1. The prompt hangs on a `Post`, not on the mat, at the point the shared arithmetic names, in
   reach of a man on the mat and inside the range's own footprint -- `tests/server/range.spec.luau`,
   "hangs the prompt on a POST at the mat's front edge". Take the post out of `Build` and it fails
   (it did: `range.spec:473`).
2. From the firing position looking at the lane centre, at Karen's 969 x 792 viewport, the prompt
   projects inside the viewport and above the hotbar band, over five eye heights 4.0..6.0 --
   `tests/client/range_panel.spec.luau`, "puts the prompt inside Karen's 969 x 792 viewport". The
   same case shows the MAT's own point falling below the hotbar band, which is the defect, and
   cross-checks `viewportPointOf` against the engine's `Camera:WorldToViewportPoint` on three
   points in the live camera's own frame -- with no write to the camera, which has one owner.
3. `RangePanel.confirm()` sends the pick AND closes the menu, giving both doors back by tag, and
   the prompt still re-opens it -- `range_panel.spec`, "closes on RELEASE THE TARGET".
4. The board's last line prints each gun's own label for each of its loads and never the wire word,
   and Karen's own case (`rifle` + `Slug`) reads `.416` -- `range_panel.spec`, "prints the gun's
   OWN cartridge label".
5. A WALK picked while the target is inside the window records 8.89 s +-10 % on the FIRST crossing
   after the pick -- `range.spec`, "times a WALK picked MID-WINDOW".
6. Walking off the spot still closes the menu and drops the board, now measured from the prompt's
   own point -- `range.spec`, the `atSpot` assertions in the POST case, and `range_panel.spec`
   "gives both doors back when he walks off the spot" (unchanged, still green).
7. Nothing else on the range moved: 34/34 checks, 2471 server and 637 client cases green, and the
   known flake `weapon_shot.spec.luau:1490` did not fire in any of the three runs.

## What I could not verify

- **ON SCREEN IN KAREN'S PLACE: nothing here.** All four are proved by cases in DEV plus the
  arithmetic of her viewport. The Director's real-key, real-click re-run in her place is the
  screen's own answer and it has not happened yet. In particular the board's AFTER string
  (`BOAR male at rifle / .416`) is asserted by a case and not read off a frame; the BEFORE string,
  `BOAR male at rifle / Slug`, I read off `<runs-dir>/evidence/p298/14-walk-crop.png` myself.
- The post's Y over her terrain is the shelf plus the post's height, less the ground spread under
  its own 1.2 x 1.2 footprint. The sloped-ground case bounds that; no measurement in her place
  confirms it.
- Round 1's note that the POST case's position assertion compares `Build` against the same
  `promptPosition` it built from: still true. The independent anchors are the reach, the footprint
  box, and now the `atSpot` pair, which are bounds rather than a second derivation of the point.
- Whether the lodge -> mat walkway segment was WALKED rather than spawned at the mat during the
  Director's 03:05-03:33 pass (task 302 item 1's open gap, L-095). `PROOF.md` records a walk from
  the lodge to the mat in 25.7 s with the same character, which reads as the walk, but the
  Director's own re-run is what closes it.

# Task 234 - a red-dot sight the player looks THROUGH, a deer in every drive, the deer on the card

Task: 234
Round: 1
Base: main @ `00ef51495464` (merge of #214, task 233)
Code commit: `d99686b26a1e780a96c3877af55ec59069151adc`

```
[harness] PASS: 34/34 checks @ d99686b26a1e780a96c3877af55ec59069151adc (clean tree) scope=auto:assets,boar,camera,gun,hud,lobby,match,report,shop,viewmodel,weapon
```

1995 server + 519 client cases, on a clean tree, at the code commit.

**THE FULL `test` IS ALSO GREEN AT THIS COMMIT and its line is deliberately NOT pasted here.**
`tools/agents.py` reads a full line beside a scoped one as *"you have the whole suite"* and then
asks for `[harness2]` -- which needs a human click nobody can automate. This task touches
`TWO_PLAYER_PATHS`, so Task 113's scoped lane is what makes a review round possible at all today.
The full line, the `test2` refusal and the exact clicks are all in `ESCALATE.md`, and **the MERGE
gate is unchanged**: the PR to `main` needs the full `test` AND `test2` for this same commit, and
the Director checks both. Nothing is claimed here that the scoped run did not play -- it resolved to
eleven scopes and 83 spec files out of the 90 in the tree.

CI green on the branch: `Build and lint`, run 39688300450.

## What changed

Karen, 2026-10-21, playing: *"this aiming is not coirrect for semiauto / you know this type of
aiming you look from that galss and there is a dot inside right ?"*, *"I didnt see deer red tag
why ?"* / *"I want to see a deer"*, *"we need all a time in drive deer and could be also lines and
how they behav"*.

Three parts: a DRAWN red-dot sight replacing task 227's fade; a GUARANTEED red deer group in every
drive, marching in file; and the deer on the drive's start card with their points and their licence.

**Every case below was shown FAILING on the broken behaviour before it was offered as proof**
(L-028). Six deliberate breaks, one harness run, and each failed in the case named for it:
`deer.spec` (formation nil), `match_phase.spec` (no last-release clause), `semiauto.spec` (the hood
chord on the middle radius), `semiauto.spec` (`clearAtAim` without the first-person gate),
`match_client.spec` (a head per row), `semiauto_client.spec` (the `Optic` back on the instance).

## Claims

1. **The aimed sight picture is a hood, a lens and a dot -- and it matches Karen's own references.**
   `.screenshots/234-sidebyside-refs.png` is her `reddot-ref-1`, `reddot-ref-2` and our aimed frame
   (`234-a4-aim.png`) side by side; `234-before-semiauto-aim.png` is the defect reproduced first
   (rule H). **Verify:** `<runs-dir>/234-ring.py` reads a capture and prints the window and the rim
   as a percentage of frame width -- ours is 28.7 % / 39.2 % against ref-1's 31 % / 38 %. The
   geometry is `SemiAuto.Geometry`'s `HOOD_INNER_RADIUS`, `HOOD_WALL`, `HOOD_SEGMENTS`,
   `GLASS_*`, `MOUNT_*` and the hood loop in `Geometry.pieces`; `semiauto.spec`'s *"THE SIGHT
   PICTURE"* bounds the window and the rim **in degrees at the shipped eye relief** (20.0 and 23.8),
   not in studs.

2. **The dot is on the camera axis and stays there as the gun moves.** `Geometry.beadOffset` is the
   one expression `Geometry.sight` aims with and `Geometry.pieces` draws the `Dot` at. **Verify:**
   `semiauto.spec` measures the dot through `Mode.aimOffset` at `0.000000 deg` off centre; live,
   `<runs-dir>/234-measure.luau` read the camera at `(0, 0, -0.35)` from the dot in the gun's frame,
   and `234-a4-aim.png` (yaw 0, pitch -8) and `234-a6-aim-yaw90.png` (yaw 90, pitch -20) measure the
   dot at the same pixel and the same 1.0-1.1 deg in both.

3. **The viewmodel stops wearing the bought optic, and the world gun still does.** Its glass is one
   opaque amber face on a mesh that cannot be split here, so it is a wall at any transparency --
   which is what task 227's fade was working around. `Optic` carries `skipFor = "reddot"`;
   `Geometry.ASSET_KEYS` still carries `semiauto.sight`. **Verify:** `semiauto.spec` asserts no
   piece named `Optic` in the shipped row AND that the asset key survives; `semiauto_client.spec`
   asserts it on the real INSTANCE, with the hood, the mount and the lens present instead.

4. **The eye went to the glass, and the near-plane risk was measured rather than assumed.**
   `aim.eyeReliefStuds` 0.9 -> 0.35 in `poses.json`, written through `pose.py`'s own reader, merge
   and serializer (rule J; `pose.py selftest` green). At 0.35 the eye sits inside the receiver's z
   span. **Verify:** `semiauto.spec`'s case 6 -- the sight line is 0.0850 studs above the rail, so at
   the frame's bottom edge (25 deg at FOV 50) the receiver is 0.1823 studs away against Roblox's 0.1
   clip; `234-a4-aim.png` shows no hole in the gun. The old numbers and the rollback are in
   `backups/2026-10-21_task-234_semiauto-optic-fade.md` (rule 7).

5. **The dot reads and does not hide a deer at 50 m.** `DOT_DIAMETER` 0.012 -> 0.006. **Verify:**
   `semiauto.spec` prints `0.98 deg against a stag's 2.41 deg at 50 m` and bounds it at both ends
   (bigger than a real 2 MOA, under half the animal, under a sixth of its own window).

6. **EVERY drive asks for a red deer group, exactly once, and not always on the first release.**
   `Phase.deerRelease` is pure; `State.deerReleased` latches and `Phase.releaseFailed` hands it
   back; `enterAssigning` resets it with the rest of the drive. **Verify:** `match_phase.spec` runs
   **200 whole drives** and reports `0 with no deer ask, 0 with more than one`, plus the ordinal
   case (`the deer rode release 1 in 20 of 60 drives`), the last-release fallback, the hand-back and
   the per-drive reset. Live: the DEV drive released a stag and two hinds
   (`<runs-dir>/234-realdeer.luau`), photographed at eye height in `234-deer-in-drive.png`.

7. **The schedule says WHEN and the animal's own table says WHO.** `Boar.deerComposition` gained
   `wanted`, which skips the CHANCE and nothing else -- `pick` still draws the group. **Verify:**
   `deer.spec` drives the asked arm at a roll that refuses (1.0) and gets each of the three
   compositions back by `pick`; it also asserts an ask is refused with `BOAR_MODEL` off, so the
   schedule's half of the feature carries no flag.

8. **A deer group marches in single file, declared rather than drawn, with no second movement
   writer.** `SPECIES.reddeer.RELEASE.FORMATION = "column"`, read by `Boar.compositionFormation`
   and applied in `Runtime:spawnSounder`. **Verify:** `deer.spec` asserts every shipped deer
   composition answers `"column"`, that a boar composition answers nil (so a boar sounder still
   draws), that a mixed group answers nil, and that 9-stud column slots are wider than the longest
   deer (`9.00 stud slots, longest deer stag at 7.05`). **The draw is still MADE and then
   overridden** -- skipping it would move `self._rng`'s stream, which is the defect task 223's
   round 1 shipped.

9. **The start card names the deer, with their real points, off their one home -- and says they
   need the licence, off Licences.** `Match.CONFIG.QUARRY` names the species KEY;
   `Match.quarryRows` resolves the label and `licence` through `Licences.ROWS`; `Hud.startCardRows`
   draws a head row for a licensed species only, once per species. **Verify:**
   `.screenshots/234-card-live.png` is the LIVE card in a DEV drive -- `Male boar +10`, `Female boar
   +6`, `Piglet - leave them -10`, `RED DEER [NEEDS LICENCE]`, `Stag +20`, `Hind +6`, `Calf - leave
   them -10`, `A person -10`, with the countdown intact. `match_config.spec` proves the prices come
   from `POINTS.KIND` and the licence from `Licences.required`; `match_client.spec` proves ONE head
   and eight rows, and that an unlicensed species gets none.

10. **The card grew and the beater's did not.** `START_CARD_ROWS_MAX` 4 -> 8;
    `Hud.START_CARD[n].height` became `chrome`, and `Hud.startCardHeight(viewX, rows)` is the one
    answer. **Verify:** `hud_style.spec` asserts `startCardHeight(viewX, 4)` equals the Designer's
    own measured `Drive.CONFIG.START_CARD_HEIGHT` (274 desktop, 239 phone) at BOTH steps, that a row
    is worth exactly one `rowH`, and that the ceiling is a clamp; `match_client.spec` asserts a
    beater still draws four rows at exactly that height.

## What I could NOT verify

- **`test2`.** It cannot be started by a tool. `ESCALATE.md` carries the exact clicks. The merge
  gate needs it; the review round does not (Task 113's scoped lane, above).
- **Deer walking nose-to-tail in a real drive, in a frame.** The formation is DECLARED and
  unit-proved, and `.screenshots/234-deer-file-eye.png` is three deer frozen at their best file
  (8.1 studs of sideways spread, measured by `<runs-dir>/234-fileshot.luau`) -- but in a ONE-PLAYER
  DEV drive nothing pushes them, so they either idle on the spawn ring or sprint for the exit and
  break past `BREAK_STUDS = 60`. Measured, not guessed: three separate runs are in the report. The
  walking file needs a drive with beaters -- Karen's playtest or `test2`. **The deer in that frame
  are grey-box bodies**, because a probe's own runtime never loads the published meshes; the MESHED
  deer is `234-deer-in-drive.png`.
- **Karen has not seen any of it.** Every look decision here -- the hood's size, the tint, the dot's
  1 degree, eight rows on a card the Designer capped at four -- is hers to judge.
- **`docs/design/semiauto-shotgun.md` section 5.3 and `startcard-spec.md` section 1.4 now describe
  the gun and the card as they were.** The Builder does not write designs (rule 3); this is for the
  Architect and is flagged, not edited.

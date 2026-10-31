# Task 320: no towers on the shooting range -- he shoots from the bench

Task: 320
Round: 1
Base: main (a768a070)
Code commit: fba3fcca3abdcbe7d3473350043499bf9daff25c

Karen, 2026-10-31, after playing her range: *"and remove towers we dont need them in shooting
range"*. The six TREESTANDs of the lobby range are no longer built. The bench works exactly as
before. CORE-NA: no ballistics, no animal, no 316-319 loop code is touched.

```
[harness] PASS: 34/34 checks @ fba3fcca3abdcbe7d3473350043499bf9daff25c (clean tree) scope=all
```
`test2`: N/A. No changed path is in `TWO_PLAYER_PATHS` (`agents.needs_two_player` over this
branch's diff returns `[]`) -- the range is a one-player lobby feature.

## Claims

1. **`Range.Build` builds no treestand.** The stand loop, `makePiece`, `makeClimbPrompt` and the
   `HighSeats` require are gone from `src/server/Range/Build.luau`; `deckTops` stays an empty
   table so the return shape does not change. Verify: read the file; no `Stand`, no `Deck`, no
   `HighSeats`.
2. **Nothing downstream branches on the removal.** `Range.onClimb` already refused a station with
   no `deckTops` entry and `Range.spotAt` already answered `bench` without one (a station whose
   seat `HighSeats.plan` refused). Verify: `src/server/Range/init.luau` `onClimb`, and
   `Range.spotAt` in `src/shared/Range/init.luau`.
3. **The panel can never be told `treestand`.** `Range.nearestPrompt` -- the one evaluation that
   tells `Hud.step` the position -- now scans the BENCH word only. Verify: `nearestPrompt` in
   `src/shared/Range/init.luau`. There is no TREESTAND *chip* in the panel and there never was:
   the position was where he stood, not a pick (frame `320-c-panel-view.png`, below).
4. **The arithmetic stays as data no reader builds, marked at each site, and that is deliberate**
   (dispatch (c)): the T6 safety envelope, the station box (`standReach`) and the banks are
   measured off `LAYOUT.STAND.backStuds`, so deleting it would MOVE them. Verify: the headers on
   `Range.POSITION` and `LAYOUT.STAND`; `backups/task-320/README.md` (rule 7 archive of the
   removed code, verbatim).
5. **FAIL FIRST, covering exactly this change.** With main's `Build.luau` and `Range/init.luau`
   checked back into the tree and the new specs in place, the suite reports
   `FAIL ... 9 failed, 9 errors` -- `range.spec:1185` (stands 6, wanted 0), `:1255` (a built
   treestand prompt), `:1295` (`RangeStandPrompt1` where nil was wanted), `:535` (24 prompts,
   wanted 6), `:934` (143 parts, wanted 59). Run `<runs-dir>/320-failfirst.txt`. The same specs
   are 0/0 at the code commit (the harness line above).
6. **The specs that asserted treestands are UPDATED, named one by one.**
   `tests/server/range.spec.luau`: *"Build: the bench and the treestand"* -> *"Build: the bench,
   and NO treestand (task 320)"* (its four cases rewritten to the new truth: no seat part by name
   or class, no deck top, one prompt a station, `nearestPrompt` answers nothing where the deck
   stood, and the ground that used to REFUSE a seat now costs nothing); the two climb cases
   (*"climbs a man onto the deck..."*, *"hangs a Climb on E..."*) replaced by one, *"has no climb
   at all: no prompt, nothing wired, and every station refused"*; *"is TRUE on the deck, measures
   TREESTAND there"* -> *"has NO deck top at all, answers BENCH on the mat and nothing where the
   deck stood"*; the deck arm of *"keeps the tally when a man walks between the bench and his own
   ladder"*; the prompt count (4 per station -> 1) and the part count (the
   `SPOT_COUNT * HighSeats.PARTS_PER_SEAT` term dropped). `tests/client/range_panel.spec.luau`:
   no case changed -- the two that name `TREESTAND` exercise `distanceFor`'s data branch
   directly, and each now says so.
7. **`tools/` was grepped too, not just `src/` and `tests/`.** `tools/aim_bench.py` hard-coded
   `POSITIONS = ("bench", "treestand")` and staged the character on `Stand<n>.Deck`; it is now
   bench-only and reads downrange off `Post<n>` (which `POST.aheadStuds` puts downrange of the
   mat) instead of the deck. `python tools/aim_bench.py selftest` -> OK, and it runs in CI.
8. **HER PLACE, AT THE CODE COMMIT** (`driven-hunt-294` checked out to fba3fcca, rojo :34874,
   panel shot `evidence/port-34874-20261031-195050.png`; back on :34873 afterwards,
   `evidence/port-34873-20261031-195437.png`). Census probe `<runs-dir>/320-census.luau`:
   at main `stands=6`, 24 prompts (`RangeStandPrompt1..6`, `RangeClimbPrompt1..6`,
   `RangeDownPrompt1..6`, `RangePrompt1..6`), 102 tall range parts; at the code commit
   `stands=0`, 6 prompts (`RangePrompt1..6`), 36 tall range parts, tallest +9.6 (the hut roof).
   Files `320-census-main.txt` and `320-census-320.txt`.
9. **FRAMES, LOOKED AT, PLAYER EYE HEIGHT, SAME TWO CAMERA POINTS BEFORE AND AFTER** (rule 5,
   rule F; dispatch (a)). `320-a-main-approach-left.png` (from the lodge approach at main: four
   wooden towers with ladders in front of the huts) vs `320-a-after-view.png` (same point, code
   commit: only the roofed huts 1/2/3). `320-b-main-bench-view.png` (from the bench at main: a
   tower fills the right of the frame) vs `320-b-after-view.png` (same point: huts and the lane).
   **Dispatch (a), every tall structure on or beside the range at main:** the six range
   TREESTANDs (legs/rails +14.9, ladder +13.5, deck +12.5 over the shelf) and the six range HUTS
   (roof +9.6, posts +9.3) -- nothing else is a structure; everything else within 220 studs is a
   `Lobby`/`OurForest` TREE or the lodge, 140-220 studs away. Only the treestands were touched.
10. **REAL E AT STATION 2, in her place, at the code commit** (`320-c-panel-view.png`, taken after
    `<runs-dir>/298key.ps1 E` with the view focused by a click): the menu opens with ANIMAL, KIND,
    PACE, WEAPON, CARTRIDGE, DISTANCE (107/125/179, 125 lit), RELEASE THE TARGET and THE BOARD --
    no position row and no TREESTAND anywhere. Probe `320-mat2.luau` read the one prompt in reach
    from the mat: `RangePrompt2 7.6 studs (reach 12)`. Console over that session:
    0 "Stack Begin", 0 "attempt to", 0 "invalid argument"; `[range] built in 18 ms (55 parts,
    0 stands, 0 refused, 0 climb prompts)`; the one `rbxassetid://203785492` content warning is
    pre-existing (tasks 227 and 254 recorded it).

## What I could not verify

* I did not fire a shot: 319a(a) (the released range target stays invisible until the server's
  `Mask` publish reaches the client) is still open and is not this task's. Nothing in this change
  touches ballistics, the target or the release.
* `Range.onClimb` / `onClimbDown` / `wireClimbs` are kept in `src/server/Range/init.luau` as
  handlers no prompt can reach (asserted unreachable by the new spec). Deleting them is a bigger
  cut than Karen asked for; queued rather than taken.

CHECKED: L-136 · CHECKED: L-127 · CHECKED: L-162
ANSWERED: L-136 -- the named flake (`weapon_shot.spec.luau:1490`) did not fire in either clean
run. The first clean run showed `deer_hitbox.spec:682` (the known intermittent of 315a(q)/313)
plus two real failures of my own; both were fixed and the next clean run was 34/34 with
`deer_hitbox` green, so no FAIL line is being called known.
ANSWERED: L-127 -- MET / NOT PROVEN is given per item in the report's handover block.
ANSWERED: L-162 -- every live proof above was taken in her place on the worktree checked out to
fba3fcca, the code commit, with the rojo panel photographed at :34874 before and :34873 after.

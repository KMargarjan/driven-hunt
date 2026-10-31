# Task 321 -- one pass, one animal

Task: 321
Round: 1
Base: d7ae1929 (main)
Code commit: e407f6af0ecda552d8a39860c47a50f84133ce20

`[harness] PASS: 34/34 checks @ e407f6af0ecda552d8a39860c47a50f84133ce20 (clean tree) scope=all`

`test2`: **REQUIRED AND NOT OBTAINED -- see `ESCALATE.md`, 2026-10-31.** `tools/agents.py` refuses the
round without it, because `src/client/Range/Mask.luau` and `tests/client/range_mask.spec.luau` are in
`TWO_PLAYER_PATHS` (task 313 put the range's per-player picture there). I ran it rather than assume:
`[harness2] FAIL: 33/36 checks @ ab5265c7 (clean tree)` -- it fails `One Studio instance before the
test starts` because Karen's Forest Test editor is open, which the Builder may not close, and
`[driver] camera_client.spec:376` (`expect(stats.maxUpdateMs < 5)`, the camera's worst frame) on a
machine running five Studio processes. **I am not calling that one a flake: there is no control run
at the merge base.** The Director closes the Forest Test, re-runs `test2` (`<runs-dir>/press-f7.ps1`
makes the Start click), pastes the line here, and runs the review. Round 1 is unused.

## PLAN (core-quality step 0)

- **(a) REAL LIFE.** An ISSF running-target lane shows ONE run per target: the animal appears at one
  end, crosses the 10 m window, is gone, and the next run follows. Nothing turns round in view.
  <https://en.wikipedia.org/wiki/50_meter_running_target>
- **(b) MEASURED NOW**, on main `d7ae1929`, in Karen's Forest Test, station 2, RUN, solo
  (`<runs-dir>/321-pass.luau`): **ONE animal (Boar1), FOUR crossings, 7.12 s mean / 7.13 s worst out
  of sight between them**, and `LocalTransparencyModifier` **1.00 on two of the four entries** -- the
  man could not see it. (317's figure was 7.10 s; 319's kill figures were +2.40 s to the carcass
  going and +4.37 s to a new live animal.)
- **(c) TARGET.** A new animal per crossing; the next entering the span <= 1.0 s after the last one
  left it; the next released <= 1.0 s after a kill; every animal visible from the moment it enters.
- **(d) LEVER.** `src/server/Range/init.luau`: `release`/`order`/`scan` (the one writer of
  `trial.targetId` and of `boars.spawn`/`clearOne`), `Range.CONFIG.NEXT_PASS_SECONDS`, and
  `RangeData.passEntryFor` for the release point. The mask: `Range.mineIdsFor` ->
  `record.mineIds` -> `Mask.setMine`.
- **(e) MEASURED AFTER** with the same probe, same place, same station.

## What changed

1. **A pass is one animal (a).** It is released into the apron run-up, crosses the span once, and is
   cleared at the far edge; the leg -- and so the direction -- changes with the next release.
   `timeWindow`'s own span-exit edge is what ends it (`trial.passOver`), and `PASS_MAX_SECONDS`
   ends one that never arrives. **Verify:** `range.spec` "runs ONE animal per pass".
2. **Nothing is removed in his sight (f).** The span is also the predicate `Range.Mask` shows him by
   (`wantedFor` -> `RangeData.inWindow`), so an animal outside it is already invisible. Release and
   removal both happen outside it. **Verify:** `RangeData.passEntryFor` clamps into the apron;
   the live log below shows every spawn at `span edge -+ 8.4` studs.
3. **The next pass starts at once (b).** One number: `NEXT_PASS_SECONDS` = 0.35, as a run-up of
   `pace speed * NEXT_PASS_SECONDS` studs, so the gap is the same at every pace. **Verify:**
   `range.spec` "starts the next pass within NEXT_PASS_SECONDS" (walk, trot, run; worst <= 1.0 s).
4. **A kill does not make him wait (c).** The carcass moves to `trial.carcassId` and keeps its own
   `CARCASS_SECONDS` clock; the next animal is released on the same tick. `MAX_TARGETS` doubled
   (`Runtime:count()` counts carcasses, so the old cap refused that spawn). **Verify:** `range.spec`
   "releases the next animal within a tick of a kill".
5. **The mask names ids, not only an Instance (e, 319a(a)).** A trunk created this tick may not have
   replicated when the payload arrives, and `mine` then reads nil -- which hid the man's own fresh
   animal for the whole pass. `Body.create` names the trunk after the animal's id, so
   `record.mineIds` resolves on the client's own sweep. His carcass is in the list too.
   **Verify:** `range_mask.spec` "shows the animal the server named by ID even when the Instance
   never arrived" -- red with the id arm deleted.
6. **A man at a station is published to without asking (e).** `occupancy` makes him a watcher and
   `publish` makes his record, so his FIRST animal is named. Before this, nothing was published
   until he pressed E or fired. **Verify:** `range.spec` "tells every man at the range" cases;
   `#sent >= 1` before any request.
7. **The 317 apron reversal is ARCHIVED, not left unreached** (rule 7):
   `backups/2026-10-31-range-apron-reversal.md` carries the six `TURN_*` numbers, `turnDone`,
   `inSpan`, the leg flip, and the spec case that asserted the walk, verbatim. `TURN_AIM_STUDS` ->
   `AIM_MIN_STUDS` survives as the pure-pursuit floor. **Verify:** `grep -r TURN_ src tests` is empty
   but for one comment naming the archive.
8. **Spec cases the loop moved.** Counts that are the whole firing line's are now scoped to the
   station under test; `leadsAt(spot)` answers for the animal the station holds NOW, so order history
   is keyed by the ids that station held; the idle clock is asserted on a STANDING animal, which is
   the one with no pass to end. **Verify:** the diff of `tests/server/range.spec.luau`.

## Measured after, in Karen's place (every live proof named with its commit)

| | main d7ae1929 | cycle 1, 0.5 s | cycle 2, 0.35 s (shipped) |
|---|---|---|---|
| animals in 41 s | **1** | 8 | **8** |
| crossings each | **4** | 1 | **1** |
| gap, out of sight | **7.12 s mean** | 0.97-5.01 s | **0.83-2.12 s, mean 1.12, median 0.93** |
| crossing at RUN | 4.15 s | 4.2 s | **4.02-4.27 s** (predicted 4.18, 2 %) |

- Probe `<runs-dir>/321-pass.luau`, Forest Test, station 2, RUN, solo, same instrument throughout.
- Cycle 1 at `2c5466f6`, cycle 2 and the frames at `160c25ae`. `e407f6af` (the code commit) differs
  from `160c25ae` in `tests/server/range.spec.luau` ONLY -- `git diff --name-only 160c25ae..e407f6af`.
- **The kill, twice** (`<runs-dir>/321-kill.luau`, `160c25ae`): `KILL Boar29 at x=2780.3` ->
  `NEXT ANIMAL Boar30 released +0.00 s after the kill (carcass still there=true)`; the carcass stays
  at x=2780 (no `CARCASS MOVED` line) and goes at +2.40 s while Boar30 keeps walking.
- **The mask, in the same log:** Boar30 reads `ltm=1.00` at x=2878 and x=2877 (outside the span) and
  `ltm=0.00` at x=2876 -- it is drawn for him the frame it enters the span, with no second publish.
  The carcass reads `ltm=0.00` throughout: he sees what he shot.
- **Frame (rule 5):** `<runs-dir>/321-b2.png` (crop `321-b2-z.png`), shooter's eye at station 2 in her
  place: a boar, fully drawn, broadside on the grass lane in front of the berm. I opened it.
  `321-b4.png` is the gap between two passes: the same view, empty lane.

## What I could not verify

- **The <= 1.0 s gap is met at the median (0.93 s) and not at the worst case (2.12 s).** The residue
  is the animal's own standing start: it is spawned AT REST and turns onto the lane, and
  `Boar.Body.create(config, folder, id, position, kind)` takes no heading and no speed -- there is no
  writer for it, so the target is refuted at that lever rather than dialled. Shortening the run-up
  further would put it in the span below pace and break the crossing the board teaches.
  Cycle 1 -> cycle 2 is the measurement that shows the distance is not the dominant term.
- **Flag-off (L-083).** Two halves, and one of them IS evidenced. `RANGE` gates the whole module at
  `Range.start` (`Range.ENABLED = Flags.isOn("RANGE")`), and the DEV place the harness runs in has
  **no override set and the default `false`** -- the run refuses to start if any override is set, and
  it did start -- so the `34/34 scope=all` line IS the flag-off world: nothing in this diff runs
  there, and the place builds and boots unchanged. `RANGE_SOLO` (the span this loop measures against)
  is exercised in BOTH states by parameter: every `range.spec` case passes `solo` explicitly, and
  `RangeData.sightSpanFor`'s `wide ~= true` arm is `windowSpanFor`'s body. **What has no frame is the
  range drawn with `RANGE_SOLO` off**, which is the narrow window: not photographed this round.
- 319a's other open items (leave is per station; step off and back) are untouched and unproven here.

ANSWERED: L-136 the named flake `weapon_shot.spec.luau:1490` did not fire in any of the seven runs;
the final run is 34/34 with 0 failures, so no FAIL line is argued away in this request.
ANSWERED: L-127 every claim above is MET or carries its own NOT PROVEN line; the gap claim says
median met / worst not met rather than "met".
ANSWERED: L-162 every live proof names the commit it was taken at, and the only difference between
them and the code commit is one test file, shown by `git diff --name-only`.
ANSWERED: L-033 the kill proof was run TWICE and both runs are quoted; the pass loop was measured on
three separate Play sessions (cycle 1 twice, cycle 2 once).
ANSWERED: L-083 the flag-off state is listed above as NOT PROVEN ON SCREEN, with the reason.
ANSWERED: L-156 319a(b)-(f) are untouched; the loop rewrite did not move `ended` or the station-end
logic, which still reads exactly as 319 left it (`trial.ended` in `scan` and `onRequest`).

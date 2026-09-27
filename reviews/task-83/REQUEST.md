# Task 83 — a quick test mode for playtests, Studio only

Task: 83
Round: 1
Base: `main` (`bf9323c`)
Code commit: `4e7d34c398103c934c5ba5d7a03dee807b5355ad`

```
[harness2] PASS: 32/32 checks @ 4e7d34c398103c934c5ba5d7a03dee807b5355ad (clean tree)
[harness]  PASS: 32/32 checks @ 4e7d34c398103c934c5ba5d7a03dee807b5355ad (clean tree)
```

My own `gate.sh`, `QUICK_TEST` **off**, no override (`flags.py` printed `override none` before the run
and again after the Play sessions).

**Three gates failed on the way, each diagnosed before anything was re-run.** (1) `30/32 @ 9a268c2`:
this file's own `MAX_ALIVE_BOARS` is 2 and `maybeRelease` holds the **whole** sounder back when it
does not fit, so a three-boar release was deferred for ever — a fixture fault, and the real invariant
it exposed (`MAX_ALIVE_BOARS >= QUICK_TEST_SOUNDER`) is asserted of the live numbers now. (2)
`30/32 @ 17012e4`: the "is it faster" case compared the quick first release against the **fixture's**
`FIRST_RELEASE_SECONDS`, which is also 5 — 5 < 5 is false, and the claim belongs to the shipped table.
(3) `30/32 @ 4e7d34c`, the same commit that had just passed twice: `hit_marker` and `weapon_client`,
the client shot path. `git diff 46638ae 4e7d34c -- src` is **empty**, and the run's own input note
shows the staging race — the client was placed at `Boars.Boar1` and then staged on `Boar2, 22 studs
away`, with the first marker arriving at +37.0 s. That is Task 80's family, not this change; the next
run of both was green with nothing changed.

**What changed.** `src/shared/Flags/init.luau` (the row), `src/server/Match/init.luau`
(`quickTestEnabled`, `quickSpawnFor`, `quickTestPhantom`, `playerDrivers`, the numbers, the effect's
spread), `src/server/Match/Phase.luau` (`intermissionSeconds`, `firstReleaseSeconds`, the first
sounder's size and spawn, `releaseGap`, `quickSpawn` in the state and the event),
`tests/server/match_phase.spec.luau`, `tests/server/match_live.spec.luau`, `PLAYTEST.md` (the
how-to), `GAME_DESIGN.md` (the drive's owner row), `TASKS.md` rows 83/83a.

## Claims

1. **IT CANNOT RUN OUTSIDE STUDIO, AND THAT IS THE ONE ASSERTION A STUDIO SPEC COULD NEVER MAKE ANY
   OTHER WAY.** `Match.CONFIG.QUICK_TEST = quickTestEnabled(Flags.isOn("QUICK_TEST"),
   RunService:IsStudio())` — the only flag in this repo whose value is ANDed with anything. The guard
   is pure and exported, so the spec drives all four combinations: `(true, false)`, `(false, true)`,
   `(false, false)` are false and `(true, true)` is true — the last one so the case cannot pass on a
   function that always answers false.

2. **THE FLAG IS OFF IN EVERY HARNESS RUN AND THE DEFAULT IS `false`**, asserted live beside the
   value: `Match.CONFIG.QUICK_TEST == false` and `Flags.DEFAULTS.QUICK_TEST.default == false`.

3. **40 SECONDS OF WAITING BECOMES 8**, and the claim is made of the **shipped** table rather than a
   fixture: `QUICK_TEST_INTERMISSION_SECONDS < INTERMISSION_SECONDS`,
   `QUICK_TEST_FIRST_RELEASE_SECONDS < FIRST_RELEASE_SECONDS`, `QUICK_TEST_INTERVAL_SECONDS <
   RELEASE_INTERVAL_SECONDS`, and the total wait is at most a quarter. The run prints it:
   `task83: 40 s of waiting becomes 8 s with the quick test`.

4. **THE FIRST RELEASE IS KAREN'S SMALL GROUP, ON THE ROAD, AND ONLY THE FIRST.** `Phase.sounderSize`
   returns `QUICK_TEST_SOUNDER` when `soundersReleased == 0`; `maybeRelease` uses `state.quickSpawn`
   and sends its own `spread`. The spec asserts the first effect is size 3 at the measured position
   with the road's spread, and that the **second** release is an ordinary one — a marker position,
   no spread — on the quick rhythm.

5. **BOTH BRANCHES ARE DRIVEN BY PARAMETER**, so neither the flag nor Studio is consulted anywhere in
   `match_phase.spec`: with the quick table the drive is Running and has released inside 12 s; with
   the ordinary one the same 9 s release nothing at all, because the intermission alone is ten.

6. **A MISSING DRIVE LINE IS NOT A DROPPED RELEASE**: with no line there is no `quickSpawn`, and the
   release still happens from the ordinary marker with no spread.

7. **THE CONSOLE FOUND A REAL BUG THAT NO HARNESS RUN COULD.** Push credit is keyed **by userId**, and
   the phantom is not a player: `credit[tonumber("quick-test")] = at` is `credit[nil] = at`, which
   threw `table index is nil` on **every step** of every quick-test session and took the rest of the
   drive's step with it — which is why the first Play sessions showed no boars at all.
   `Match.playerDrivers` is now the one filter both the safety rule and push credit go through, and
   the spec drives it with a mixed list: the phantom is dropped, the player is kept with its numeric
   userId. `studio_mcp.py console` is what found it, in the first session with the flag on.

8. **THE PHANTOM IS INVISIBLE TO EVERYTHING THAT MEANS A PERSON.** `Match.quickTestPhantom` is nil
   with the flag off (asserted live), its id is not a number, and the live case walks
   `Match.driverThreats()` asserting every entry has a numeric id.

9. **THE NUMBERS WERE MOVED BY LOOKING, AND THE REJECTED ONES ARE WRITTEN DOWN.** The first release
   waits 5 s into the drive rather than 0 (at 0 the sounder was released and gone before a player —
   or a screenshot — arrived, six bursts in a row); the spawn is 12 studs ahead because that keeps the
   ring on the road, the one strip the map guarantees flat at `groundY`, and `Runtime:spawn`
   overwrites the caller's Y; the sideways offset is 0 because at 12 studs the visible half-width of a
   70° view is 8.4 studs and the 25 and 60 I tried put the sounder outside the frame. 90 studs ahead
   was tried and showed an empty road three times, and I could not tell from a picture whether that
   was terrain or capture latency — so it is not what shipped (`TASKS.md` 83a(c)).

10. **SIX MUTATIONS, IN TWO RUNS, EACH FAILING ITS OWN NAMED CASE, ALL RESTORED.** `quickTestEnabled`
    ignoring `isStudio` → `match_live.spec:299`; the quick spawn not used → `match_phase.spec:636`
    (position) and `:666` (spread); `playerDrivers` not filtering → `match_live.spec:345`;
    `firstReleaseSeconds` ignoring the quick test → `match_phase.spec:600`. **That last mutation ran
    GREEN at first** and is the reason the fixture's own numbers are no longer equal: with both set to
    5, a branch that ignored the quick test entirely passed every case in the file.

## The screenshots, described as they are

`.screenshots/20260927T1313*-task83k-*`, a one-player Play session with the override on, cleared
afterwards. The shooter is on a post under the canopy, facing up the drive.

- **The clock, measured from the Hud**: at t+7 s after pressing Play the Hud reads `DRIVE 1 9:55`, so
  the drive has been running 5 s and started at **t+2 s** — against roughly 22 s without the mode.
- **The boars**: at t+7 the ground ahead is empty; at **t+11 s** three tan-and-grey bodies stand among
  the trunks ahead of the shooter (`task83-boars-sequence.png` puts t+11, +15, +18 and +22 side by
  side). So the small group is **in front of a player about eleven seconds after Play**, which is the
  thing Karen asked for.
- **What the pictures do NOT show, and I am not claiming it**: them crossing the line. Frame by frame
  they get *smaller* and drift away rather than coming past the camera, which is what wandering looks
  like and not what bolting for the exit looks like. The phantom is in the code, nothing errors, and
  `quickTestPhantom` is asserted nil with the flag off — but whether it reaches `Boar.Brain` as a
  threat is **unverified**, and the honest next step is a counter on the boar's side rather than
  another screenshot. `TASKS.md` row 83a(a2).

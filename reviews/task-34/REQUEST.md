# Task 34 — running the specs with two players

Task: 34
Round: 1
Base: `2545891`
Code commit: `7f4f1e373dac869a7e023d1df7b8bc50c05769fc`

```
[harness] PASS: 27/27 checks @ 7f4f1e373dac869a7e023d1df7b8bc50c05769fc (clean tree)
```

230 server and 58 client `it` blocks across 23 spec files (`main` had 226 and 58). The one-player
`test` is the line above and is unchanged; the two-player `test2` is the new mode, and **its own run
needs a click only Karen can make** — `ESCALATE.md`, `NEEDS KAREN`, 2026-09-25.

## Task

ROADMAP 1.6. Karen's probe (Task 30) proved a local Clients-and-Servers test registers its
processes with StudioMCP — four studios: the edit one plus a server and two clients. This task turns
that into a harness mode: start the test if possible, find which studio is which, run the gated
specs on each, read all the reports, end the session. Plus one spec that needs two players.

## Claims

1. **`test` is untouched and stays the default.** The new mode is a separate command (`test2`) and a
   separate function (`run_test2`); `run_test` has **no** new branch, no flag and no mode argument.
   Nothing in the place, and no spec, knows which mode it is running under: the same `TestKit` gate,
   the same two runners, the same reports. The one-player harness is green at the commit above with
   the new spec in it (230 server `it` blocks, was 226).

2. **StudioMCP cannot start the test, and that is measured, not assumed.** Its `start_stop_play`
   takes `is_start` and `studio_id` and nothing else — there is no player count anywhere in its tool
   schema (`tools/list`, Task 30's addendum). So the mode prints the exact clicks, waits up to 180 s
   for the windows, and **if nobody presses Start it says so and claims nothing**: the check fails,
   the token is cleared, and the run exits 1. I ran exactly that path: the five checks before the
   click pass, the sixth fails with `1 studio(s): Driven Hunt DEV (placeId: …)`, and the output
   reads `NEEDS KAREN: nobody pressed Start. Nothing was run and nothing is claimed.`

3. **The token goes first, and that ordering is the whole trick.** A local test copies the place as
   it stands when Start is pressed, so a token written afterwards never reaches those processes and
   every runner refuses (`TestKit`'s gate, 120 s). `run_test2` writes the token, proves Rojo synced
   it, and only then asks for the click — and says in its own output how long the window is.

4. **The test's instances are identified by identity, not by name.** `list_roblox_studios` is read
   **before** the click; anything new afterwards belongs to the test. That way the edit Studio — and
   anything else Karen has open — is excluded without parsing a name, and the three unnamed entries
   Karen's probe saw are exactly what is classified.

5. **Server and clients are told apart by what they offer, not by order.** `get_studio_state` per
   instance lists its DataModels: the one offering `Server` is the server, the ones offering
   `Client` are the clients. Anything else is reported as unclassified rather than guessed at. Two
   checks: one server found, exactly two clients found.

6. **Every call that must land somewhere names its `studio_id`.** `Studio._call` gained an optional
   `studio_id`; `query`, `console`, `state_of`, `set_play` and `send_input` all pass it through, and
   `replay_input` takes one. With one Studio connected the argument may be left out, which is why
   the existing single-player path is unchanged.

7. **The input replay drives client 1 only, and client 2's report is an observation.** The scenarios
   are written for one player — a cue key, one gun, one staged shot — so client 2 has nothing to
   react to and its input-driven specs cannot pass. The mode prints client 2's status as a `note`
   line and never as a check. Saying so is cheaper than pretending otherwise, and it is in the
   docstring.

8. **What the 2-player run actually checks:** one server and two clients found; each of the three
   runners reported within 120 s; each report carries this run's token and the DEV PlaceId; the
   server and client 1 are `PASS` with 0 failed, 0 errors, 0 skipped; the server ran
   `ServerStorage.Tests.match_teams.spec`; and it ran every server spec file in the repo. Then it
   stops each test instance and, if any survive, says to press Cleanup.

9. **The 2-player spec is true for whatever number of players is there**, so it runs in both modes
   rather than being dead code in the default one. `tests/server/match_teams.spec.luau`: everybody
   has a team; the counts differ by at most one; with **one** player the lone player is a `Shooter`
   and may carry a weapon (Director decision F); with **two**, the split is 1 driver and 1 shooter
   and `mayCarryWeapon` is true for exactly the shooter. It prints each player's name and team.

10. **The docstring is the single source of truth again.** `test2` has its own section — what
    StudioMCP cannot do, the ordering, the identification, the replay's one client, every check and
    the final line — and the two sentences Task 32a note (a) said were missing are now there: the
    stage's 60 s wait for its target, and the 120 s report window.

## What I could not verify

- **The half after the click has never run.** Nobody pressed Start, so the classification, the
  three-report read, the per-instance stop and the Cleanup notice are code I have exercised only up
  to the point where the windows should appear. That is the `NEEDS KAREN` entry, and it is one
  command plus four clicks.
- **The two-player assertion has only ever run with one player.** `match_teams.spec` passes its
  one-player branch in the harness above; its two-player branch is untested for the same reason.
- **Whether the two clients' `ClientTestRunner`s both report at all** is an assumption about
  Studio's local test, not an observation — the mode checks it, nobody has watched it.
- **Whether `set_play(False)` ends a multi-process test** or whether Cleanup is always needed. The
  mode tries, re-lists, and says what is left.
- **Nothing about a real second player's experience** — teams on screen, a driver pushing a boar —
  is covered here. That is still the drive design's §12.8 `NEEDS KAREN`.

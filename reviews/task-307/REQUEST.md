# Task 307 -- the aim bench: one repeatable instrument for "does aiming at what she sees hit"

Task: 307
Round: 2
Base: 8b7ffb71
Code commit: 81ca71d91b1efcedc2db17df5851942b24ee41a6

```
[harness] PASS: 34/34 checks @ 81ca71d91b1efcedc2db17df5851942b24ee41a6 (clean tree) scope=all
```

`test2` is **N/A**: `python tools/agents.py` reads `needs_two_player([tools/aim_bench.py,
.github/workflows/ci.yml, docs/research/*])` as `[]` -- nothing here is in `TWO_PLAYER_PATHS`. A
Director tool, CI and two docs files.

## PLAN (core-quality protocol step 0)

* **(a) REAL LIFE / the ask.** Karen, 2026-10-24/25: *"we need to aim in empty space to get hit in
  head neck or heart like in real life"*. The question is whether aiming at the animal the client
  DRAWS, plus the real lead, hits.
* **(b) MEASURED NOW.** Five rigs, one build, three answers for rifle/RUN/nose: **9/10**
  (`<runs-dir>/playtest/check305c/report.md` item 1), **5/9** (`<runs-dir>/305d/U2`), **4/10**
  (`reviews/task-305b/MEASURED.md`, chest+lead, where its own nose read 9/10).
* **(c) TARGET.** N = 30 per cell: +-17 pp at a true 70 %, against +-29 pp at N = 10 -- the smallest
  N at which a 70 % cell and a 40 % cell stop overlapping. Plus a CONTROL cell >= 50 % and a
  KNOWN-BAD cell <= 20 %, with **non-overlapping** 95 % intervals.
* **(d) LEVER.** There is no `src/` change in this task: the deliverable IS the instrument. The
  three things it drives already exist and each has one writer --
  `src/client/Camera/TestLook.luau:51` (`TestLook.ATTRIBUTE = "DHTestLook"`),
  `src/client/Weapon/Input.luau:207` (`"DHClaimWhy"`, the only hit in `grep -rn DHClaimWhy src/
  tests/ tools/`), and `Range.onRequest` in `src/server/Range/init.luau`.
* **(e) HOW IT IS MEASURED after.** The same tool: `aim_bench.py run <same cells>`.

## What changed

Three files plus an index row. **No `src/`, no `tests/`.**

1. **`tools/aim_bench.py`** (new, docstring = its documentation). Task 298's design planned this as
   phase **B5, "shot.py"** and never built it, so the four earlier rigs are harvested and each part
   cites its source file.
2. **`.github/workflows/ci.yml`** -- one step, `python3 tools/aim_bench.py selftest`.
3. **`docs/research/2026-10-29-aim-bench.md`** + the `INDEX.md` row (rule 1).
4. **`reviews/task-307/bench-A..D.txt`** -- the four runs' own output, verbatim, with every
   per-shot row.

## Round 2: the five round-1 findings

| # | what it was | what changed | verify |
|---|---|---|---|
| 1 | `bench-B.txt` carried `@reddeer.stag`, which matches `privacy_scan`'s email rule and fails CI | the four tables rewritten to `~` (cell NAME only, header note in each), and the scan **re-run at HEAD** | `python tools/privacy_scan.py scan` -> `PASS: 0 findings in 1177 tracked text files` |
| 2 | the ray and aim were sampled on the frame the HOST bumped, two StudioMCP round trips before the click | the resident clears `DHClaimWhy` and waits for `Input.fire`'s own write -- that IS the fire frame -- and the row carries the gap | `frames=8..27` in `bench-E.txt`; the `repeat ... until me:GetAttribute("DHClaimWhy") ~= nil` block in `RESIDENT` |
| 3 | `cmd_ray` part 3 asserted nothing under a criterion the shipped ballistic cannot meet | the offset is printed as a reading, labelled `NOT A CRITERION` with `boreOrigin` / `launchDirection` named, and the verdict and exit code rest on part 2 | read `cmd_ray`; the verdict line now reads `VERDICT (parts 1 and 2 only)` |
| 4 | a click the server never answered counted as a miss; `semiauto` 0/30 was clear air by construction | rows carry `answered`; unanswered rows are excluded from N; `run_cell` prints `notice`; `summarise` flags `NOT A MEASUREMENT` and `NO SHOT IN ... REACHED THE SERVER AT ALL` | `selftest` drives both (a 30/30-unanswered cell and a 7-answered/3-not cell) |
| 5 | the comment-strip selftest could not fail (it read `GATE`, which has no comment, and only up to its first quote) | it now asserts `RESIDENT` **carries** a comment line and that **none survives** the join | delete the `startswith("--")` line from `oneline` -> `selftest` fails |

Non-blocking notes also taken: every control/known-bad cell is checked rather than the last named
one; `ahead` spans the drawn MODEL, not the trunk part; the dead `note0` arm removed; the `--`
legend; `wilson(0, 30)`'s float equality; the shot count (805, not 780); the `N` column for
`bench-D`; and the `DHClaimWhy` second-writer sentence. **Not taken:** asserting the ray offset
against `Ballistics.sightOffsetAt` (finding 3's suggested stronger form) -- a wrong threshold would
be worse than none, so the number is printed and the criterion removed. Queued.

## Claims, and how to verify each

1. **The shot goes through the REAL client input path.** `Bench.click` sends a
   `mouseButtonClick` through `Studio.send_input` (`tools/studio_mcp.py`), the same
   VirtualInputManager route the Task-6 scenario replay uses; the tool never builds a `FireRequest`
   payload. *Verify:* `grep -n "FireRequest" tools/aim_bench.py` -> no hit. Compare with
   `<runs-dir>/305d/trial2.tpl` and `<runs-dir>/305-shoot.luau`, which both do `fire:FireServer`.
2. **CLICK PROOF, by negative control, run live in Karen's place.** `src/client/Weapon/Input.luau`
   is the ONE writer of a **VALUE** to `DHClaimWhy`, inside `Input.fire`. Cleared, with no click
   sent, it stayed `nil` for 2 s; one real click set it to `off`. **The bench is a second writer and
   only ever writes nil**, which the tool's own printed line now says (round 1, note). *Verify:*
   `grep -rn DHClaimWhy src/` -> two hits (the comment at `Input.luau`:23, the write in
   `Input.fire`); then read the proof below.
3. **The ray is read on the frame `Input.fire` RAN, not the frame the host asked for it** (round 1,
   finding 2 -- `bump` and `click` are two separate StudioMCP round trips). The resident clears
   `DHClaimWhy`, waits for `Input.fire`'s own write, and reads `camera.CFrame.Position` /
   `.LookVector.Unit` and the aim point on THAT frame. The gap is printed on every row and in the
   proof: `frames=8..27` Heartbeats, so it was never one frame. The impact's distance from that ray
   is printed and **asserts nothing** -- the server flies from `Ballistics.boreOrigin` along
   `Ballistics.launchDirection` (elevated for the gun's zero), not the camera ray (round 1,
   finding 3). *Verify:* the `DHClaimWhy` wait in `RESIDENT`'s shot watcher, then the `frames=`
   column in `reviews/task-307/bench-E.txt`.
4. **The camera is steered only through the owner's hook.** `RESIDENT` writes `DHTestLook` and
   never `workspace.CurrentCamera.CFrame`; `selftest` asserts that (`"CurrentCamera.CFrame =" not in
   resident`). *Verify:* read the assertion, then `grep -n "CurrentCamera" tools/aim_bench.py`.
5. **The result is read from what the live game WROTE, never from a module.** The resident connects
   `HitMarker` / `ShotLanded` / `StateChanged` / `RangeBoard` once and publishes rows into a
   LocalPlayer attribute; the host only reads attributes. *Verify:* `grep -n "require(" ` in
   `RESIDENT` -> only `Ballistics` and `Weapons`, both pure arithmetic tables, used for the lead.
6. **The two self-check cells are not optional and they BITE.** `with_self_checks` appends them
   whenever the caller has not named them, and `summarise` prints `INSTRUMENT SUSPECT` when the
   known-bad reads > 20 %, the control < 50 %, or their 95 % intervals overlap. *Verify:*
   `python tools/aim_bench.py selftest` -- it drives all four branches, including the overlap case
   (16/30 vs 9/30), plus the "no control cell ran" and "0 shots" cases.
7. **The self-check caught four of the bench's OWN defects before any table was believed**, each
   fixed and re-measured. Listed in the research note's "Measured while building it" table: rows
   bleeding between cells (known-bad read 2/6 on 2 shots), the hotbar digit un-equipping the gun
   (`held=nil` on the second cell), a one-frame velocity reading 49.7 studs/s on a target carried at
   24, and the lead legend read as the hit dot. *Verify:* read the table, then the four comments in
   the code that each cite the measurement.
8. **805 shots in Karen's own place, on `main` 8b7ffb71 served from the 294 worktree on :34874.**
   Rojo panel photographed connected: `<runs-dir>/evidence/port-34874-20261028-233313.png`.
   Her thirteen flag rows were **read first and never written** (rule K) -- the bench has no
   `DHFlag_` writer at all: `grep -n "DHFlag" tools/aim_bench.py` shows one read-only query.
9. **Every table self-checked clean.** A/B/C/D: CONTROL 60 / 70 / 67 / 83 %, KNOWN-BAD 13 / 7 / 17 /
   0 %, intervals never overlapping, so all four printed
   `Self-check: CONTROL and KNOWN-BAD both read as they must.` *Verify:* `tail -8
   reviews/task-307/bench-*.txt`.
10. **CI covers the pure half** and the three gate selftests pass:
    `python tools/aim_bench.py selftest`, `tools/studio_mcp.py selftest`, `tools/agents.py selftest`,
    `tools/privacy_scan.py scan` -> `PASS: 0 findings in 1171 tracked text files`.

## The click proof, as the FIXED build printed it (Karen's Forest Test, in Play, on the mat)

```
1. NEGATIVE CONTROL -- DHClaimWhy cleared, NO click sent:
   after clear:    nil
   2 s later:      nil   (must be nil -- only Input.fire sets a VALUE here; the bench
                   itself only ever writes nil)

2. ONE REAL CLICK (StudioMCP user_mouse_input mouseButtonClick, left):
   DHClaimWhy:     off
   src/client/Weapon/Input.luau is the ONE writer of a VALUE to DHClaimWhy, inside
   Input.fire -- the client's ONE firer of FireRequest. So the click ran Input.fire.

3. THE RAY Input.fire SENT, its own two expressions read on the frame it RAN
   (the frame DHClaimWhy changed, 8 Heartbeat(s) after the host asked):
   origin|direction: 2650.0806,146.7846,-3216.3916|0.20141,0.02306,-0.97923
   server impact:    2678.47|149.97|-3350.00   (hit=False zone=-)
   the impact lies 0.891 studs off that ray, over 136.6 studs of flight (0.37 deg)
   NOT A CRITERION: the server flies from Ballistics.boreOrigin along
   Ballistics.launchDirection (elevated for the gun's zero), not from the camera
   along the camera ray, so a non-zero offset here is the shipped ballistic.

VERDICT (parts 1 and 2 only): the bench's click ran the live Input.fire
```

**`reviews/task-307/bench-E.txt`** is the fixed build's own run in the same place, on disk, and it
carries the three new fields and the measured gap:

```
#1 hit=True  answered=True fired=True frames=27 zone=head spd=11.36 dist=128.0 along=-0.178 notice=- src=nose
#2 hit=True  answered=True fired=True frames=10 zone=head spd=11.80 dist=130.9 along=-0.100 notice=- src=nose
#3 hit=False answered=True fired=True frames=8  zone=-    spd=10.78 dist=135.7 along=+0.628 notice=- src=nose
#4 hit=False answered=True fired=True frames=9  zone=-    spd=10.02 dist=128.3 along=-0.423 notice=- src=nose

rifle/trot/nose~boar        4  2   50%  15% - 85%   -0.02  +0.08
rifle/run/chest+lead~boar   4  4  100%  51% - 100%  -0.40  +0.03  CONTROL
rifle/run/ahead~boar        4  0    0%   0% - 49%   -0.73  +0.18  KNOWN-BAD
Self-check: CONTROL and KNOWN-BAD both read as they must.
```

## The table, from Karen's place (805 shots, N = 30 per cell)

| cell | N | hits | rate | 95 % | along | up |
|---|---|---|---|---|---|---|
| rifle/run/nose | 30 | 21 | 70 % | 52-83 | -0.27 | +0.06 |
| rifle/run/eye | 30 | 12 | 40 % | 25-58 | -2.39 | +0.20 |
| rifle/run/chestfront | 30 | 9 | 30 % | 17-48 | -0.45 | +0.19 |
| rifle/run/chest | 30 | 8 | 27 % | 14-44 | -2.99 | +0.09 |
| rifle/trot/chest | 30 | 28 | 93 % | 79-98 | +1.18 | +0.12 |
| rifle/trot/chestfront | 30 | 26 | 87 % | 70-95 | -0.34 | +0.14 |
| rifle/trot/eye | 30 | 24 | 80 % | 63-90 | +0.02 | +0.10 |
| rifle/trot/nose | 30 | 22 | 73 % | 56-86 | +0.94 | +0.09 |
| rifle/walk/chest | 30 | 29 | 97 % | 83-99 | +0.58 | +0.03 |
| rifle/walk/chestfront | 30 | 27 | 90 % | 74-97 | -0.26 | -0.06 |
| rifle/walk/nose | 30 | 25 | 83 % | 66-93 | -0.42 | +0.02 |
| rifle/walk/eye | 30 | 25 | 83 % | 66-93 | -0.78 | +0.05 |
| rifle/stand/nose | 30 | 27 | 90 % | 74-97 | +0.42 | -0.19 |
| rifle/stand/chest | 30 | 28 | 93 % | 79-98 | +0.40 | -0.09 |
| rifle/stand/chestfront | 30 | 26 | 87 % | 70-95 | +0.43 | -0.01 |
| rifle/stand/eye | 30 | 23 | 77 % | 59-88 | +0.35 | -0.04 |
| lever/run/nose | 30 | 16 | 53 % | 36-70 | -0.37 | -0.03 |
| **semiauto/run/nose** | 30 | **0** | **0 %** | **0-11** | -- | -- |
| shotgun:Slug/run/nose | **7** | 4 | 57 % | 25-84 | +0.95 | +0.25 |
| rifle/run/chestfront ~reddeer.stag | 30 | 21 | 70 % | 52-83 | +0.76 | -0.01 |
| **rifle/run/eye ~reddeer.stag** | 30 | **1** | **3 %** | **1-17** | +1.54 | +0.45 |
| CONTROL rifle/run/chest+lead (A/B/C) | 30 | 18/21/20 | 60/70/67 % | | | |
| CONTROL rifle/run/chest+lead (D, E) | **6, 4** | 5, 4 | 83, 100 % | | | |
| KNOWN-BAD rifle/run/ahead (A/B/C) | 30 | 4/2/5 | 13/7/17 % | | | |
| KNOWN-BAD rifle/run/ahead (D, E) | **6, 4** | 0, 0 | 0, 0 % | | | |

**`semiauto/run/nose` 0/30 IS NOT A MEASUREMENT ABOUT THE AIM** (round 1, finding 4). All 30 rows
carry no `HitMarker`, no `ShotLanded` and no impact: the server never answered the click. The fixed
tool records `answered` per row, **excludes** such rows from N, prints `notice`, and flags the cell
`NOT A MEASUREMENT` / `NO SHOT IN ... REACHED THE SERVER AT ALL`. A/B/C were taken before that field
existed and so cannot be re-rated without re-running. **That row must not be carried forward as a
fact about the game** -- it is a reading about the trigger. Queued for the Director.

Cells that got **fewer than 30**: `shotgun:Slug/run/nose` got **7** -- the gate closed three times
in a row at 15 studs/s and the tool gave up on the cell, as it is written to. `bench-D` is the
confirmation run at **N = 6**, not a measurement.

## What could not be verified

* **The hit card's dot read `nil` on every row.** The resident polls the live `HitCard` frame for
  1.2 s after each hit for a `Frame` named `Dot` that is not the lead legend, and found none; a
  separate 6 s poll after one shot (`<runs-dir>/307/card2.luau`) saw the frame never become
  `Visible`. The earlier non-`nil` readings were the lead legend, which is why the filter is there.
  Zone and impact come from the remotes instead and are unaffected. **Unresolved -- queued.**
* **`ServerStorage.DHLastHits` is empty for range shots** (printed `nil` in all four runs): the
  range's card goes through `Range.setCardSender` -> `HitLog.sendCard`, which does not write
  `HitLog`'s trace ring (`HitLog.recordHit` does). Recorded in the note.
* **A/B/C were measured before the five round-1 fixes and before the `@` -> `~` rename.** Their cell
  NAMES were rewritten in place (a header note in each file says so; no number changed) so CI's
  privacy scan passes on HEAD -- `PASS: 0 findings in 1177 tracked text files`, run at HEAD, not at
  the first code commit. They carry no `answered` / `frames` column, which is why the `semiauto` row
  is called out above rather than quietly re-rated. `bench-D` is the tool after the rename and
  `bench-E` is the tool after all five fixes, both in the same place, both self-checked clean.
* **No screenshot (rule 5).** Nothing drawn changed; the evidence is the four tables and the click
  proof. The Rojo panel frame is cited in claim 8.

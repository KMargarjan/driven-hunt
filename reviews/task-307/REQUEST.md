# Task 307 -- the aim bench: one repeatable instrument for "does aiming at what she sees hit"

Task: 307
Round: 1
Base: 8b7ffb71
Code commit: b4904c49483342843ff5df0f8c362a27b3db9eea

```
[harness] PASS: 34/34 checks @ b4904c49483342843ff5df0f8c362a27b3db9eea (clean tree) scope=all
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

## Claims, and how to verify each

1. **The shot goes through the REAL client input path.** `Bench.click` sends a
   `mouseButtonClick` through `Studio.send_input` (`tools/studio_mcp.py`), the same
   VirtualInputManager route the Task-6 scenario replay uses; the tool never builds a `FireRequest`
   payload. *Verify:* `grep -n "FireRequest" tools/aim_bench.py` -> no hit. Compare with
   `<runs-dir>/305d/trial2.tpl` and `<runs-dir>/305-shoot.luau`, which both do `fire:FireServer`.
2. **CLICK PROOF, by negative control, run live in Karen's place (section "The click proof" below).**
   `src/client/Weapon/Input.luau` is the ONE writer of `DHClaimWhy` in the repo, inside `Input.fire`.
   Cleared, and with no click sent, it stayed `nil` for 2 s; one real click set it to `off`.
   *Verify:* `grep -rn DHClaimWhy src/ tests/ tools/` -> two hits, both the comment and the write in
   `Input.fire`; then read the pasted output.
3. **The ray the click sent is `Input.fire`'s own two expressions.** The resident records
   `camera.CFrame.Position` and `camera.CFrame.LookVector.Unit` on the click frame -- the literal
   pair `Input.fire` passes -- and the server's own impact lies **1.758 studs** off that ray over
   **129.9 studs** of flight (0.78 deg) with the rifle. *Verify:* read `Input.fire` in
   `src/client/Weapon/Input.luau` against the `DHBenchRay` block in `RESIDENT`.
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
8. **780 shots in Karen's own place, on `main` 8b7ffb71 served from the 294 worktree on :34874.**
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

## The click proof, as it printed (Karen's Forest Test, in Play, on the mat)

```
[aim_bench] bench up gen=2
[aim_bench] held=Rifle
[aim_bench] gate: READY px=1.0,0.0 spd=10.91 dist=136 held=Rifle centre=484,396

1. NEGATIVE CONTROL -- DHClaimWhy cleared, NO click sent:
   after clear:    nil
   2 s later:      nil   (must be nil -- nothing else writes it)

2. ONE REAL CLICK (StudioMCP user_mouse_input mouseButtonClick, left):
   DHClaimWhy:     off

3. THE RAY Input.fire SENT, its own two expressions read on the click frame:
   origin|direction: 2649.9668,146.7852,-3216.3984|-0.08300,0.02461,-0.99625
   server impact:    2640.94|150.03|-3345.91   (hit=True zone=body)
   the impact lies 1.758 studs off that ray, over 129.9 studs of flight (0.78 deg)

VERDICT: the bench's click ran the live Input.fire
```

## The table, from Karen's place (780 shots, N = 30 per cell)

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
| CONTROL rifle/run/chest+lead (A/B/C/D) | 30 | 18/21/20/5 | 60/70/67/83 % | | | |
| KNOWN-BAD rifle/run/ahead (A/B/C/D) | 30 | 4/2/5/0 | 13/7/17/0 % | | | |

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
* **A/B/C were measured before the species separator was renamed `@` -> `~`** (the `@` form tripped
  `privacy_scan.py`'s email rule). The rename touches the cell NAME only; `bench-D` is the same tool
  after the rename, run in the same place, and it self-checked clean.
* **No screenshot (rule 5).** Nothing drawn changed; the evidence is the four tables and the click
  proof. The Rojo panel frame is cited in claim 8.

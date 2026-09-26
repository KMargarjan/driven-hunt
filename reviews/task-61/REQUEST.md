# Task 61 — the drive releases sounders

Task: 61
Round: 1
Base: `51c2d57` (`main`, with Task 60 merged)
Code commit: `d10817a03e5b0d53834bcfc276225904428ce599` — the `[harness]` line below names it, and it is
the last commit that changed `src/`, `tests/` or `tools/`.

Harness, clean tree, one player:

    [harness] PASS: 30/30 checks @ d10817a03e5b0d53834bcfc276225904428ce599 (clean tree)

Harness, clean tree, two players — run by the DIRECTOR, not by me:

    [harness2] PASS: n/n checks @ d10817a03e5b0d53834bcfc276225904428ce599 (clean tree)

374 server specs (350 before: **24 new**) and 84 client specs. `python tools/flags.py clear` before
the run, and the harness's own check confirms no override was set.

## Scope

The design's **57b half**: the release stops being "one boar" and becomes "a sounder of `size`
animals". `Boar` is untouched — Task 60 built the sounder itself. Nothing else changed: no client
file, no wire field (Director decision L), no new owner.

## Claims

1. **With the flag OFF the drive is byte-for-byte today's drive.** Every size is 1, so
   `soundersReleased == boarsReleased`, the marker round-robin index and the jitter index are the
   same indices, and `releaseGap` returns `RELEASE_INTERVAL_SECONDS`. The proof is written against
   **literals**, not `CONFIG`: six singles, the first at exactly 20 s, the rest 90 ± 15 s,
   round-robin over the markers in order. Verify: *"with the flag OFF releases six singles on exactly
   the old schedule"*.

2. **With it ON a drive spends exactly its budget.** `Phase.sounderSize` draws from `SIZE_WEIGHTS`
   and clamps to `MAX_SIZE` and to what is left, so over **200 seeded drives** every drive's sizes
   sum to exactly `BOARS_PER_DRIVE`, never five and never seven. Verify: *"spends exactly the drive's
   budget, in sizes 1..MAX_SIZE"*.

3. **The mix is the weights — and the budget bends it, which is measured, not hidden.** The draw is
   within 20 % of `SIZE_WEIGHTS` over 2,000 draws with a budget big enough that the clamp never
   bites. The **released** mix over 200 drives is 41/23/25/8/3 % against weights of 40/20/18/12/10,
   because a six-animal budget cannot pay for a five after a three. The spec asserts the draw and
   **prints** the released histogram; the design's §12.1 item 2 asks for ±20 % of the released mix,
   which is not true of any implementation that also guarantees claim 2.

4. **One hash, not two.** `Phase.unitHash` is the module's only source of drawn numbers and
   `Phase.jitter` is refactored onto it, so "is this drive reproducible" has one answer. Same seed
   and drive number → the same sizes; a different drive number → different ones. Verify: *"is the
   same drive twice, and a different drive next time"*.

5. **The committed seed opens with a group, so there is no seed to change** (design §12.10): with the
   flag ON, `SEED = 1` drive 1 is **3, 3**. The spec prints it and asserts the first size is ≥ 2.

6. **The whole sounder fits or none of it is released.** `maybeRelease` checks the live count **and**
   the runtime's entries against its capacity — a carcass holds a slot for `CARCASS_SECONDS` and
   `aliveBoars` does not count it — holds the sounder back rather than dropping it, and the retry is
   the **same** sounder (the hash index did not move), so the same size arrives. Verify: *"holds a
   whole sounder back rather than releasing part of it"*, *"holds back on the CARCASS count too"*.

7. **A refused release comes back whole.** `Phase.releaseFailed(state, now, size)` gives back one
   sounder and `size` boars and makes the next release due now; from nothing released it is a no-op.
   The owner calls it with the size it tried. Verify: *"gives a refused sounder back whole"*.

8. **A stall is visible instead of folkloric.** `state.holdbacks` counts consecutive hold-backs, the
   owner accumulates them into `stats().sounderHoldbacks` and warns **once** when they reach
   `HOLDBACK_WARN = 20`. `match_live.spec` asserts it is 0 on a clean run.

9. **The numbers that must agree, agree, and a spec says so.** `BOARS_PER_DRIVE <= maxBoars`,
   `MAX_ALIVE_BOARS >= SOUNDER.MAX_SIZE`, `MAX_ALIVE_BOARS <= maxBoars`, and
   `SPAWN_RING_STUDS + PAD_MARGIN_STUDS <= Map.SPAWN_PAD.radius`. **`MAX_ALIVE_BOARS` is 4 → 6**
   (Director decision H), outside the flag and declared in the code: a ceiling of 4 would make a
   5-boar release permanently impossible. Verify: `match_live.spec`, *"keeps the budget, the ceiling
   and the runtime's capacity in order"*.

10. **The flag is read once, at the owner's boundary**, and both states are driven by parameter:
    `Match.CONFIG.SOUNDER.ENABLED == Flags.isOn("BOAR_SOUNDERS")`, **false** on a clean run, and
    `flags.spec` exercises `sounderSize` with `ENABLED` false and true. `Match.Markers` publishes
    `spawnRadius` from `Map.SPAWN_PAD` (Director decision I), so the ring is spread only where the
    map guarantees flat ground.

## What the screenshots show (rule 5 — I looked at them)

Taken in a Play session with `python tools/flags.py set BOAR_SOUNDERS on`, then `clear` before the
harness run above.

- **`sounder-drive-6`** — the HUD reads `DRIVE 1 · 6:04 · BOARS 6 · SHOOTER`: the drive is running
  with the flag on and has released its whole budget. The shooter faces the arena wall, so no boar
  is in frame.
- **`sounder-field-2`** — four boars on the arena floor, well apart, grazing, with the HUD reading
  `DRIVE 1 · 2:58 · BOARS 6 · DRIVER`. **They are not in formation**, and that is the honest
  reading: nothing is pushing them.
- **The server side of the same session**, which is the part that shows the release worked: five
  boars alive with **three of them clustered inside 20 studs** (a sounder) and two lone boars
  elsewhere — the designed mix, from the drive, with the flag on.

## What I could not verify

- **A sounder CROSSING toward the posts cannot be produced with one player.** `Match.driverThreats`
  reads the Match's own assignment, and with `ODD_PLAYER_TEAM = "Shooters"` a solo player is a
  shooter, so a 1-player session has no driver and nothing ever pushes a boar. I moved the player's
  `Team` and their character and the boars still grazed — correctly. **That shot needs two players**:
  it is the Director's `test2` or Karen's playtest, not something this task can stage.
- **The formation is only visible while they flee.** Idle members drift apart (`IDLE_SPREAD_STUDS`
  is 18, `BREAK_STUDS` 60 for 4 s), so a released sounder with no driver dissolves within a minute.
  Expected from Task 60's design, and worth Karen's eye.
- **The design's §12.1 item 5 is not true of this code**: MEASURED over 200 drives, the worst last
  release is at **521 s** and **25 of 200 drives** place their last release after
  `DRIVE_SECONDS − TAIL_SECONDS = 510`, because `GAP_MIN_SECONDS = 45` wins over the pacing once the
  budget is nearly spent. The spec asserts what the code guarantees (every gap inside the clamp,
  every release before the drive ends, worst ≤ 560, ≥ 80 % of drives done by the tail) and prints the
  measurement. Queued as 61a.
- **Nothing here was played.** Whether ~3 encounters a drive feels empty is Karen item 9, and the
  flag exists for exactly that question.

## For the Director — the playtest tonight

    python tools/flags.py set BOAR_SOUNDERS on      # Edit mode; the git tree stays clean
    python tools/flags.py                           # see it
    # Studio -> Test -> Clients and Servers -> Players: 2 -> Start, then:
    python tools/flags.py live                      # what the running server resolved
    python tools/flags.py clear                     # BEFORE any harness run

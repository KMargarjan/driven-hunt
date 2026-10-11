# Task 158: the start of a drive

Task: 158
Round: 1
Base: `d6399f8` (main, #140 merged)
Code commit: `08bf455491f31ba0ca5c062fb3227c737d24cf55`

```
[harness] PASS: 33/33 checks @ 08bf455491f31ba0ca5c062fb3227c737d24cf55 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 08bf455491f31ba0ca5c062fb3227c737d24cf55 (clean tree) scope=all
[harness2] <NEEDS TEST2 -- the Director runs it; this touches TWO_PLAYER_PATHS>
```

Two FULL one-player runs at the code commit, both PASS on a clean tree (the Director's dispatch
asked for two). `test2` is the Director's: `src/server/Match/`, `src/shared/Drive/`,
`src/client/Match`'s wire and `tests/client/match_client.spec.luau` are all in `TWO_PLAYER_PATHS`.

## What changed

A START CARD at the beginning of every drive (what may be shot, plus your role), a 10 s timer on it,
and the BEATERS held at their start line until GO.

**No phase was added, so no Architect design run** — the dispatch's own condition. The countdown IS
the `Assigning` intermission the machine has had since task 32, now 10 seconds (Karen named the
number), and the card's life, the hunter's stand timer and the beaters' hold are all that one
`phaseEndsAt`. `Phase` still has four phases and still has one clock.

| | |
|---|---|
| `Match.Phase` | two effects (`hold`, `free`) and `Phase.heldUserIds` |
| `Match` (owner) | `heldAtLine`, `applyHold`/`applyFree`, the re-apply in `watchCharacter`, `Match.quarryLines`, `INTERMISSION_SECONDS` 20 -> 10, `START_HOLD_TEAM`, `QUARRY` |
| `Match.Body` | `holdCharacter` — the tie's own freeze factored out, no rope and no move |
| `Drive` | `quarry: { string }` on the wire; the card's layout and wording |
| `Hud` | the card: `startCardVisible`, `startCardLines`, `startCardTimerFor`, `roleWord`, `renderStartCard` |

## Claims

1. **The countdown is the existing phase, not a new one.** `Phase.PhaseName` is still the four names
   and `phaseEndsAt` is still the only clock. Verify: `src/server/Match/Phase.luau` — no new phase
   name, no `task.delay`, no second deadline field in `State`; `match_phase.spec`, "the start of a
   drive" → "is the intermission itself: ONE deadline".
2. **The beaters are held at the line and nobody else is.** `Phase.heldUserIds` reads
   `config.START_HOLD_TEAM`, sorted; `enterAssigning` emits `hold` AFTER `placePlayers`, because the
   hold is on the character the placement respawns. Verify: `match_phase.spec` → "holds exactly the
   beaters at the line, and AFTER they have been placed" and "holds no hunter".
3. **Everybody is let go at GO, exactly once.** `enterRunning` emits `free` with `userIds = nil`
   (everybody held), so a beater who joined mid-countdown goes with the rest. Verify:
   `match_phase.spec` → "lets everybody go at GO, with one effect that names nobody"; and the live
   measurement in claim 8.
4. **A join or a side change inside the countdown is handled, and inside the DRIVE is not.** Verify:
   `match_phase.spec` → "holds a beater who arrives inside the countdown, and not a hunter", "holds
   nobody who joins INSIDE the drive", "moves the hold with a player who changes sides".
5. **A hold is the tie's freeze, not a second one.** `Body.holdCharacter` is what `Body.tieCharacter`
   now calls — the same three humanoid numbers in the same `held` table, the same anchored root, the
   same refusals — and `Body.untie` restores either. A hold draws nothing and MOVES NOBODY. Verify:
   `src/server/Match/Body.luau`; `match_safety.spec` → "Body.hold -- held where she stands" (five
   cases, including "saves what she had ONCE", which is what stops a re-applied hold recording
   WalkSpeed 0), and the existing "Body.tie" cases still pass unchanged.
6. **The hold survives the respawn the drive itself causes.** `placePlayers` calls `LoadCharacter`,
   so `applyHold` remembers the userId and `watchCharacter` puts the hold on the character that
   arrives — the same shape the tie uses for the Reset button. Verify:
   `src/server/Match/init.luau`, `watchCharacter` and `applyHold`; `stats.holds` /
   `stats.holdsReapplied`; and claim 8, where a live beater was measured frozen after being placed.
7. **What may be shot is the SERVER's words, and they say what the code really does.**
   `Match.quarryLines(config)` → `snapshot.quarry`, beside `waitingFor`; the client holds no second
   copy. The card reads *"WILD BOAR: male, female, cub"* and *"every one of them counts - no cub rule
   yet"*, because `Boar.CONFIG.KINDS` distinguishes the three but `POINTS.KILL` scores by hit zone
   alone — nothing refuses a cub. Verify: `match_config.spec` → "the quarry lines" (four cases, the
   last one fails the day a cub rule arrives); `match_live.spec` → "puts what may be shot on the
   wire"; `match_client.spec` → "carries what the SERVER said may be shot".
8. **It was measured live in DEV, and it is in the report.** Drive 2, 2026-10-11 21:30, one player,
   teams swapped so he became the beater:
   `ASSIGNING 0:09 team=Drivers ws=0 anch=true` → `ASSIGNING 0:04 card=true "DRIVE 2 YOU MAY SHOOT"
   timer="DRIVE STARTS IN 5" lines=[YOU ARE A BEATER | WILD BOAR: male, female, cub | every one of
   them counts - no cub rule yet]` → at GO `DRIVE 2 9:45 ws=16 anch=false card=false`. Held, told,
   freed. Verify: the report, and `match_live.spec` → "holds nobody once the drive is live".
9. **The card is on screen, and I looked at it.** `.screenshots/20261011T213141Z-task158-card-try2.png`
   (DEV, Play, drive 1, hunter): the panel upper-middle reading `DRIVE 1   YOU MAY SHOOT` /
   `YOU ARE A HUNTER` / `WILD BOAR: male, female, cub` / `every one of them counts - no cub rule yet`
   / `GET TO YOUR STAND  2`, with the bar above it at `DRIVE 1  ASSIGNING  0:01  SHOOTER`. The card
   reads `2` where the bar reads `0:01` because the countdown rounds UP: a player must not read 0
   while he still has time (`match_client.spec` → "rounds the countdown UP").
10. **Nothing else about the drive moved.** The card is hidden in every other phase and behind the
    drive report, like the score panel; `Drive.CONFIG` still carries no rule number; `QUARRY` and
    `START_HOLD_TEAM` are NOT on `Match.WORLD_OVERRIDABLE`. Verify: `match_client.spec` → "is only
    ever the start of a drive"; `match_live.spec` → "names the beaters as the side held at the line,
    and does not let a world change it".

## What I could not verify, and what I found

* **`test2` has not been run.** The Director runs it.
* **Karen has not seen it.** The wording, the colours and where the card sits are hers to judge.
* **The drive report eats the first half of the card on drives 2 and later.** Measured (claim 8): at
  `0:09` the card was hidden because the report had auto-opened, at `0:04` it was up. Both centred
  panels hide behind the report — the score board has done so since 1.7b and the card follows it.
  About five of the ten seconds. `TASKS.md` 158a(e); it is a Karen/Director choice, not a defect to
  fix inside this task.
* **The Forest Test cannot start a SECOND drive, and it is not this change's doing.**
  `ForestTest.Markers.build` refuses the beater pad because `ForestTest.groundAt` is an Exclude
  raycast that does not ignore characters and lands on the beater's own head: measured at
  (3030, -1857), terrain 155.81 against a 161.09 hit on `Workspace.<player>.Head`, a 5.3-stud delta
  against a 1-stud tolerance. Drive 1 runs; then the world sits in `Waiting forest:beater-start`.
  Nothing in this task touches a marker, a raycast or `standX`. Full diagnosis and the one-line fix
  in `TASKS.md` 158a(f), for the Director.
* **A hunter off his stand at 0 is not punished, and no cub is protected.** Neither rule exists in the
  code and the dispatch forbids inventing one. `TASKS.md` 158a(a) and (b).
* **The forest smoke covered the console and the Tool, not the card.** ~160 s of Play as a beater:
  0 "Stack Begin", 0 error lines, the Horn in the CHARACTER at +6 s and at the end. The card itself
  could not be caught there — `ftplay start` returns about 25 s into the drive, long after the
  10 s countdown — which is why claim 8 and claim 9 are DEV measurements.
* **`match_phase.spec`'s quick-test ratio moved from 4x to 3x** in its own commit (`08bf455`): with
  the intermission at 10 the real wait is 30 s against the quick test's 8, so `quickWait * 4 <=
  realWait` is false and 3 is what was measured.

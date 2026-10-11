# Task 158: the start of a drive

Task: 158
Round: 1
Base: `d6399f8` (main, #140 merged)
Code commit: `8592ddfa586ae3e89adfe0d7be476879052efce8`

```
[harness] PASS: 33/33 checks @ 8592ddfa586ae3e89adfe0d7be476879052efce8 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 8592ddfa586ae3e89adfe0d7be476879052efce8 (clean tree) scope=all
[harness2] <NEEDS TEST2 -- the Director runs it; this touches TWO_PLAYER_PATHS>
```

Two FULL one-player runs at the code commit, both PASS on a clean tree. `test2` is the Director's:
`src/server/Match/`, `src/shared/Drive/` and `tests/client/match_client.spec.luau` are in
`TWO_PLAYER_PATHS`. The review has not run yet, so this is still Round 1.

## What changed

A START CARD at the beginning of every drive (what may be shot, plus your role), a 10 s timer on it,
and the BEATERS held at their start line until GO — plus, on the Director's decision of 2026-10-11,
the 158a(f) defect that stopped the Forest Test ever reaching a second drive.

**No phase was added, so no Architect design run** — the dispatch's own condition. The countdown IS
the `Assigning` intermission the machine has had since task 32, now 10 seconds (Karen named the
number), and the card's life, the hunter's stand timer and the beaters' hold are all that one
`phaseEndsAt`. `Phase` still has four phases and one clock.

| | |
|---|---|
| `Match.Phase` | two effects (`hold`, `free`) and `Phase.heldUserIds` |
| `Match` (owner) | `heldAtLine`, `applyHold`/`applyFree`, the re-apply in `watchCharacter`, `Match.quarryLines`, `INTERMISSION_SECONDS` 20 -> 10, `START_HOLD_TEAM`, `QUARRY` |
| `Match.Body` | `holdCharacter` — the tie's own freeze factored out, no rope and no move |
| `Drive` | `quarry: { string }` on the wire; the card's layout and wording |
| `Hud` | the card: `startCardVisible`, `startCardLines`, `startCardTimerFor`, `roleWord`, `renderStartCard` |
| `ForestTest` (158a(f)) | `Data.characterOf` — one rule for "is this a person", three callers |

## Claims

1. **The countdown is the existing phase, not a new one.** `Phase.PhaseName` is still the four names
   and `phaseEndsAt` is still the only clock. Verify: `src/server/Match/Phase.luau` — no new phase
   name, no `task.delay`, no second deadline in `State`; `match_phase.spec`, "the start of a drive"
   → "is the intermission itself: ONE deadline".
2. **The beaters are held at the line and nobody else is.** `Phase.heldUserIds` reads
   `config.START_HOLD_TEAM`, sorted; `enterAssigning` emits `hold` AFTER `placePlayers`, because the
   hold is on the character the placement respawns. Verify: `match_phase.spec` → "holds exactly the
   beaters at the line, and AFTER they have been placed", "holds no hunter".
3. **Everybody is let go at GO, exactly once.** `enterRunning` emits `free` with `userIds = nil`
   (everybody held), so a beater who joined mid-countdown goes with the rest. Verify:
   `match_phase.spec` → "lets everybody go at GO, with one effect that names nobody"; claim 8.
4. **A join or a side change inside the countdown is handled; inside the DRIVE it is not.** Verify:
   `match_phase.spec` → "holds a beater who arrives inside the countdown, and not a hunter", "holds
   nobody who joins INSIDE the drive", "moves the hold with a player who changes sides".
5. **A hold is the tie's freeze, not a second one.** `Body.holdCharacter` is what `Body.tieCharacter`
   now calls — the same three humanoid numbers in the same `held` table, the same anchored root, the
   same refusals — and `Body.untie` restores either. A hold draws nothing and MOVES NOBODY. Verify:
   `src/server/Match/Body.luau`; `match_safety.spec` → "Body.hold -- held where she stands" (five
   cases, including "saves what she had ONCE", which is what stops a re-applied hold recording
   WalkSpeed 0); the existing "Body.tie" cases pass unchanged.
6. **The hold survives the respawn the drive itself causes.** `placePlayers` calls `LoadCharacter`,
   so `applyHold` remembers the userId and `watchCharacter` puts the hold on the character that
   arrives — the shape the tie already uses for the Reset button. Verify:
   `src/server/Match/init.luau` (`watchCharacter`, `applyHold`), `stats.holds` /
   `stats.holdsReapplied`, and claim 8.
7. **What may be shot is the SERVER's words, and they say what the code really does.**
   `Match.quarryLines(config)` → `snapshot.quarry`, beside `waitingFor`; the client holds no second
   copy. The card reads *"WILD BOAR: male, female, cub"* and *"every one of them counts - no cub rule
   yet"*, because `Boar.CONFIG.KINDS` distinguishes the three but `POINTS.KILL` scores by hit zone
   alone — nothing refuses a cub. Verify: `match_config.spec` → "the quarry lines" (four cases, the
   last fails the day a cub rule arrives); `match_live.spec` → "puts what may be shot on the wire";
   `match_client.spec` → "carries what the SERVER said may be shot".
8. **It was measured live, in both places.** DEV drive 2, teams swapped so the player became the
   beater: `ASSIGNING 0:09 team=Drivers ws=0 anch=true` → `0:04 card=true "DRIVE 2 YOU MAY SHOOT"
   timer="DRIVE STARTS IN 5" lines=[YOU ARE A BEATER | …]` → at GO `9:45 ws=16 anch=false
   card=false`. Forest Test drive 2: `card=true "DRIVE 2 YOU MAY SHOOT" timer="GET TO YOUR STAND 10"
   lines=[YOU ARE A HUNTER | …]`, `ws=16 anch=false` — a hunter is never held. Verify: the report;
   `match_live.spec` → "holds nobody once the drive is live".
9. **The card is on screen, and I looked at it.** `.screenshots/20261011T213141Z-task158-card-try2.png`
   (DEV, Play, drive 1, hunter): the panel upper-middle reading `DRIVE 1   YOU MAY SHOOT` /
   `YOU ARE A HUNTER` / `WILD BOAR: male, female, cub` / `every one of them counts - no cub rule yet`
   / `GET TO YOUR STAND  2`, the bar above it at `DRIVE 1  ASSIGNING  0:01  SHOOTER`. The card reads
   `2` where the bar reads `0:01` because the countdown rounds UP: a player must not read 0 while he
   still has time (`match_client.spec` → "rounds the countdown UP"). Second shot,
   `20261011T215111Z-task158-forest-card.png`, is the forest two seconds into drive 2 — the card had
   just gone, and it shows the drive that could not previously exist.
10. **158a(f): a person standing on a marker's spot is not the ground.** `Data.characterOf` answers
    *"is this a person"* in one place and WALKS UP (a hat's `Handle` hangs off an `Accessory`);
    `Data.groundAt` skips a character hit and carries the ray on, bounded; `roomToStand` and the
    nearest-obstacle measurement beside it now ask the same function. Verify:
    `forest_markers.spec` → "the ground, with somebody standing on it" — the body case and the hat
    case fail on the old code — and the live before/after: the Forest Test printed
    `[report] drive 2 opened (300s windows)` and `markers: 9/9 stands (0 refused), max ground delta
    0.00, reads=3`, where the third read is the one at drive 2's start with the beater standing on
    the pad that used to be refused at 5.3 studs.

## What I could not verify, and what I found

* **`test2` has not been run.** The Director runs it.
* **Karen has not seen it.** The wording, the colours and where the card sits are hers to judge.
* **The drive report eats the first half of the card on drives 2+ in DEV.** Measured: hidden at
  `ASSIGNING 0:09` because the report had auto-opened, up at `0:04`. Both centred panels hide behind
  the report — the score board has since 1.7b and the card follows it. It did NOT happen in the
  forest run (the card was up at 0:09 there). `TASKS.md` 158a(e); a Karen/Director choice.
* **157a's other half is still queued, and that is a measurement.** The Director asked for it only if
  it were the same one-line exclude: it is not. The forest Workspace holds TWO folders both named
  `Session` (771 and 60 children, read in Edit), so `FindFirstChild("Session")` covers one of them.
  The 8/9 stand refusal did not reproduce in this run (`0 refused`, delta 0.00), so there is no new
  evidence either way, and raising `GROUND_TOLERANCE_STUDS` is still the Director's open alternative.
* **A hunter off his stand at 0 is not punished, and no cub is protected.** Neither rule exists in the
  code and the dispatch forbids inventing one. `TASKS.md` 158a(a), (b).
* **The forest smoke, long enough for two drives (~6 minutes):** 0 "Stack Begin", 0 error lines; the
  Tool in the CHARACTER at +15 s (`Horn`, as the beater) and at the end (`Shotgun`, as the hunter
  after the swap, with the rifle in the backpack); `[report] drive 2 opened`.
* **`match_phase.spec`'s quick-test ratio moved from 4x to 3x** in its own commit (`08bf455`): with
  the intermission at 10 the real wait is 30 s against the quick test's 8, so `quickWait * 4 <=
  realWait` is false and 3 is what was measured.

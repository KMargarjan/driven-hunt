# Task 157 — design brief for the ARCHITECT: the real drive, in the forest

Written by the Builder, carrying the Director (2026-10-11). This brief is the input to
`tools/architect.sh design forest-drive --task 157` and **overrides anything older** in `docs/`,
`TASKS.md` and any existing design where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-11-forest-drive.md`** — this task's note. Its §2 is twelve facts
read out of the code **by symbol**: what seam already exists, what does not, and what is already a
no-op for a world that supplies nothing. Its §3 names the three external sources, their licences and
maintenance status, and the one rejected package. **The pattern is already chosen and is not open**
(§4 of the note, restated as decision 6 below); what is open is where each half of it lives.

The design is a **new system document**, `docs/design/forest-drive.md`. It is also a **delta** to
`docs/design/drive.md` (§3.5 "one composition root", §6.1 "the markers are tags, and the world of
the day places them", §5.3 "what Assigning does", §9.2 the owner's interface) and to
`docs/design/map-generator.md` §17 wherever the two disagree about which world the drive is about.

---

## 1. The decisions already taken — do not re-open them

1. **KAREN, 2026-10-11, verbatim**, approving the next two pieces of the drive:
   *"start of a drive ... good / end of a drive ... yes"*.
   And on 2026-10-11 about the role rotation she wants to feel:
   *"you start as a hunter then next round you are beater ... and yes beater are behind animals and
   moving towards hunter line (road) like in real life"*.
2. **THE REAL `Match` RUNS IN THE FOREST TEST PLACE.** Teams (Shooters/Drivers), the four phases,
   the drive clock, the tie and the penalty, the score, the report. Not a second drive inside
   `ForestTest` — Karen's next two tasks (a 10-second stand timer at the start, a results scene at
   the end) belong to the real drive and must be built once.
3. **IT USES THE FOREST'S GEOMETRY, which is the forest's to state.** The nine stands on the curved
   road (`ForestTest.standPosition`, `STAND_COUNT` 9, `STAND_SPACING` 150), the beater start 240
   studs behind the animals (`ForestTest.beaterStartPosition`, task 153's start, already
   ground-measured and trunk-cleared), the road curve (`ForestTest.roadZ` — *"the one definition;
   every other reader calls this"*), `EXIT_Z`, `groundAt`. The map's numbers (`Map.FIELD`,
   `Map.ROAD`, posts at z = −700) describe a world that does not exist in that place.
4. **THE PLACE ID STAYS THE SWITCH. NO FLAG FOR THE WORLD.** `Map.WORLD_BY_PLACE` →
   `Map.EXPECTED_WORLD`. Task 79 measured the alternative: the same commit went from 32/32 checks to
   22/27, eleven specs failing, because the world lives in the PLACE. A behaviour flag for a *piece*
   of this task is allowed (decision 12); the world is not one.
5. **THE ANIMALS STAY `ForestTest`'s, AND `Match` RELEASES NONE IN THE FOREST.** Karen has accepted
   the resting wood, the one-way flush, the lines and the horn by playing them (tasks 150, 153,
   154). One owner of "when an animal exists", per world. The note's §2.5 shows the drive's own
   schedule switches off with data (`BOARS_PER_DRIVE = 0` → `Phase.maybeRelease` returns on its
   first predicate) and §2.6 that `clearBoars`/`spawnSounder` are already no-ops for a runtime that
   offers neither — use that, do not add a branch to `Phase`.
6. **THE PATTERN IS "THE WORLD PROVIDES; THE OWNER DECIDES"** (note §4): `Match` keeps every
   decision it has today, and everything it READS about a world arrives at the composition root.
   It is the repo's **third** instance of an owner with an injected world (`Boar.newRuntime(world)`,
   `Weapon.setArmingPolicy`/`setDriveLineProvider`), not a new foundation. A DI container is
   rejected (Knit, archived 2024-07-31).
7. **ONE PLAYER ALONE MUST BE ABLE TO PLAY IT.** A solo player is a **hunter**, armed, from the
   first drive (`MIN_PLAYERS` 1, `ODD_PLAYER_TEAM = "Shooters"` — already the config). The
   `DHForestStartRole` attribute still flips her to a beater (task 153). The phantom beaters still
   push (`ForestTest.boarThreats`).
8. **DEV'S WORLD AND THE GATE MUST NOT CHANGE BEHAVIOUR.** The harness runs in DEV. With no
   overrides, every `Match.CONFIG` value and every effect sequence is what the suite passes on
   today. Say how the design makes that provable rather than hoped — the note's §5 names the
   assertion.
9. **TWO COMPOSITION ROOTS, STILL ONE PER WORLD.** `MatchBoot` does not grow a forest branch and
   `ForestTestBoot` does not grow a DEV one. `ForestTestBoot` **shrinks** to the forest-only parts
   and starts `Match` with this world's providers.
10. **THE HORN, THE OUTFIT, THE MAP AND THE REPORT KEEP WORKING IN THE FOREST** (tasks 151, 152,
    155, 124). Each is wired in `ForestTestBoot` today; say what moves and what does not.
11. **NO FRAMES AND NO LONG TRACES ARE PART OF THIS TASK'S EVIDENCE.** Karen judges look and feel
    herself (her standing rule). The design asks for numbers a spec or a console line can produce.
12. **A FLAG IS ALLOWED FOR THE SWITCH-OVER ITSELF, and the design decides whether to use one.**
    `docs/design/feature-flags.md`: a feel-critical path is born OFF, reachable **by parameter as
    well as by flag**. If the design wants one, give the row (`owner`, `born`, `expires` within 21
    days, one-line `why`) and name the single boundary read. Note that `expires` in the past fails
    `tests/server/flags.spec.luau`, which fails the harness.
13. **OUT OF THIS TASK** (each named so it is not forgotten, and each is Karen's next): the
    10-second stand timer as a drive PHASE, the end-of-drive results scene, money, the weapon
    licence, dogs. The design must say **where each would attach** and must not build them.

---

## 2. The open decisions this design has to take

### 2.1 The seam, named, with its owner

The note's §4 lists three pieces. Decide **each**, say where it lives, and say in one sentence why it
is not a second writer (rule 3):

1. **The marker set.** `Match.start(injected)` already prefers `world.markers`
   (`readMarkers` = `if world.markers then world.markers else Markers.read(world.collection)`). State
   the shape the forest supplies, field by field, against `Markers.MarkerSet`:
   `posts`, `line`, `lineParts`, `driverStart`, `boarSpawns`, `spawnRadius`, `trees`, `complete`,
   `missing`. For each: what the forest puts there, and what reads it.
   - **`posts` and `driverStart` are consumed as `BasePart`s**, not positions: `Body.placementFor`
     reads `post.Position` and `post.Size.Y`, and for a driver `start.Size.X` / `start.Position`;
     `Body.anchorFor` and `Body.tiePointFor` read a part's `Position` and `Size`. So decide: does
     the forest **build invisible anchored marker parts** (the Valve/UE pattern — the world places
     entities the mode queries, note §3.1, §3.2), or does `MarkerSet` gain a position-based shape?
     If parts: name their container, their properties (`Anchored`, `CanCollide`, `Transparency`,
     `CanQuery`), who destroys them, and why a run-time part in `Workspace` cannot dirty the harness
     (the `Workspace.DriveMarkers` and `WeaponEffects` precedent). If tagged: say whether they carry
     `Map.TAGS` strings, and note that the forest has **no** `DrivenHunt.*` tags today — the
     opposite of the Task 79 hazard where both worlds tagged alike.
   - **`complete`/`missing` must still be able to say no.** An injected set that is `complete` by
     construction is the audit that *"certified a blank screen twice"*. Say what makes it false in
     the forest and what the Hud then shows.
2. **The per-world config.** `Match.CONFIG` is one module table, frozen by `Drive.deepFreeze` at
   require time, and the owner reads it directly (`applyPlace`, `onSafetyViolation`, `samplePush`,
   `Match:step`); every pure module already takes `config` as a parameter. Decide whether
   `Match.start({ config = … })` merges overrides over the defaults (the `Boar.newRuntime` shape),
   and if so: **shallow or key-by-key**, what happens to the frozen table and to the exported
   `Match.CONFIG` name that specs read, which keys a world may override, and which it may **never**
   (the safety numbers are not replicated for a reason — `drive.md` §3.4). Name the forest's
   override list and the start value of each (§3 below).
3. **The placement.** The forest's road is a sine curve (`ROAD.amplitudeStuds` 30 over a 440-stud
   wavelength) over ground that climbs **56 studs in 400** (`ForestTest.groundAt`'s own
   measurement), so a flat `driverStart` part spanning 1,920 studs of x is one y for a hillside.
   Decide how a player of each team is placed:
   - `Body.placementFor(markers, team, index, config)` unchanged, fed marker parts the forest builds
     at measured ground; or
   - an optional provider (`world.placement` / `markers.placementFor`) that the forest fills from
     `standPosition` + `groundAt` and `beaterStartPosition`.
   Either way **`Body` stays the one writer** (`Body.place` respawns and pivots). Say which, and say
   which way each role faces (`placementFor` faces a shooter **+Z** and a driver **−Z**; north is +Z
   in the forest and the road is south of the beaters, so state whether that is already right).
   Also: `Body.place` calls `LoadCharacter`, so **every drive start respawns everybody** — say what
   that does to the stand pick, the leash, the horn Tool and the outfit in the forest, and who
   re-opens each.

### 2.2 WHO DECIDES WHICH ROLE A PLAYER IS — and it is two deciders today

This is the sharpest ownership question in the task. **`Player.Team` has one writer
(`Match.Body.setTeam`) and, in the forest, two deciders:**

- `Match`'s roster: `Phase.enterAssigning` → `Roster.assign` → the `assignTeams` effect →
  `Body.setTeam`;
- the forest's own role request: `ForestTest.roles` (written by `/beater`, `/hunter` and the
  `DHForestStartRole` attribute) → `ForestTestBoot.applyRole` → `Body.setTeam`.

And `ForestTest.roleOf` is read by **five** things that change behaviour: `boarThreats`
(`threatKind`: a beater is a `driver` stimulus and pushes, a hunter is a `shooter` and does not),
`realBeaters`, `beaterMode` (whether the wood is stocked at all), `leash` (a beater is not held to a
stand) and the stand pick (`startAt`, `lockPick`). So two answers to "which role is she" is not a
cosmetic clash: it decides whether the wood fills and whether she can walk.

Decide, and name the one source of truth:

- does the forest's role request become an **input to the roster** (a per-world roster override that
  `Match` honours, so `Player.Team` is still the drive's answer), or
- does `ForestTest.roleOf` **derive** from `Body.teamOf(player)` (the drive assigns; `/beater`
  becomes a request that re-enters through the drive), or
- is `/beater` **retired** in this world in favour of `SWAP_TEAMS_EACH_DRIVE` and
  `DHForestStartRole`?

Whichever: say what a solo player gets on drive 1 and on drive 2 (decision 7 plus
`SWAP_TEAMS_EACH_DRIVE = true` means a lone hunter becomes a lone beater next drive — Karen asked
for exactly that rotation on 2026-10-11, so say whether this task takes it or defers it), and say
what reads what, once.

### 2.3 The drive line on a curved road, and the safety rule

`Markers.DriveLine` is `{ position, normal }` — **one plane**. The forest road is a sine curve, and
`Weapon.SafetyArc.isForbidden` compares the shot direction against that one normal.

- Decide what the forest supplies as its line, and **state the approximation and its consequence in
  studs**: a hunter at stand 1 or stand 9 is up to 600 studs from the centre and the curve deviates
  by up to ±30 studs, so say what that does to the arc's verdict.
- Note from the research (§2.10): **the arc only publishes, it never refuses a shot** —
  `Weapon` fires `SafetyViolated` and `Penalty.judge` then requires a **real driver** within
  `SAFETY_MISS_STUDS` (12) of the shot's own path. So a line in the forest cannot cost Karen a shot
  while she plays alone; it decides which shots are judged. `ForestTestBoot` registers `noDriveLine`
  today **with a comment that stops being true** when real beaters exist there — say so explicitly
  (the task-151-round-1 rule: do not leave the older sentence standing).
- Decide where a tied player is tied in the forest (`Body.anchorFor` falls back to `posts` when
  `trees` is empty — is that the answer, or does the forest tag trunks near the road?) and whether
  `TIE_UNTIL_DRIVE_END` stays true there.

### 2.4 The record and the report

`HitLog`'s window is `Match.PhaseChanged` in DEV (`MatchBoot`) and `ForestTest.drive`'s own index in
the forest (`ForestTestBoot`'s Heartbeat latch). With a real drive in the forest there are two window
owners. Decide which one survives, and say what `ForestTest.DRIVE` means afterwards (today it *"moves
no animal and resets no schedule"* — the safe default is that it keeps moving nothing).

### 2.5 What `ForestTestBoot` keeps, and what it hands over

Give the file-by-file table (`drive.md` §3.6's shape). For each of `ForestTestBoot`'s current jobs
say KEEP / MOVE / DELETE with one line of why: the boar runtime and its world config; `ShotFired`,
`HitReported`, `Downed`, `Horn.Blown`; `setArmingPolicy` (today `HornData.gunFor(Body.teamOf)`) and
`setDriveLineProvider`; `Body.ensureTeams`; `applyRole`; `placeFor`/`startAt`; the pick window and
its `task.delay`; `PlayerAdded`/`CharacterAdded`/`PlayerRemoving` (including `Match.forget`, which
*"never runs in this world"* today and will now); the Heartbeat's four jobs (the drive latch,
`step`, the wave and rest reports, `leash`); `HitLog.start`; `ForestTest.start`.

Flag every place where `Match.start` and the existing code would now both act, and say which one
wins: **arming** (`Match.mayCarryWeapon` vs `HornData.gunFor`), **the respawn** (`Body.place` vs
`startAt`), **the outfit** (`Match`'s `watchCharacter` → `dressWhenLoaded` vs `applyRole`), **the
horn carry sweep**, and **`Weapon.refreshArming`**.

### 2.6 Numbers, and the one-player reachability rule

Every path this design adds must be reachable **by parameter as well as by flag** and assertable with
**one player** wherever that is possible: the gate's two-player run costs a human click per round.
Say for each new seam which spec proves it, and name the file:
`tests/server/match_*.spec.luau`, `tests/server/forest_stand.spec.luau`,
`tests/server/forest_line.spec.luau`, `tests/client/match_client.spec.luau`. State plainly which
assertions genuinely need two players.

### 2.7 The deviations, named

If this design contradicts `docs/design/drive.md`, `map-generator.md` §17, `beater-kit.md` or
`boar-behaviour.md`, say so in its own section rather than leaving the older sentence standing.

---

## 3. Numeric starting values (the Director's, and Karen's to change)

| Thing | Start value | Source |
|---|---|---|
| Forest drive length | **300 s** | the forest's own `ForestTest.DRIVE.seconds`; DEV stays 600 |
| Intermission / scoring | **20 s / 25 s** (unchanged) | `Match.CONFIG` |
| Animals released by `Match` in the forest | **0** (`BOARS_PER_DRIVE = 0`) | decision 5 |
| Hunter stands | **9**, 150 studs apart, on the curve | `ForestTest.STAND_COUNT`, `STAND_SPACING` |
| Max hunters placed | **9**; say what a 10th hunter gets (`placementFor` wraps with `% #posts`) | `Body.placementFor` |
| Beater start | **240 studs** north of the road, trunk-clear by 6 | `LINE.spawnNorthStuds` + `BEATER.behindLineStuds` |
| Marker ground tolerance | within **1 stud** of `ForestTest.groundAt(x, z)` | note §5 |
| Tie anchor search | nearest tagged trunk, else the nearest post | `Body.anchorFor` |
| Safety numbers | unchanged (`SAFETY_MISS_STUDS` 12, `SAFETY_RANGE_STUDS` 330, grace 0) | `Match.CONFIG` |
| Solo player | hunter, armed, drive 1 | decision 7 |

---

## 4. Out of scope for this design

- The start-of-drive stand timer and the end-of-drive results scene (decision 13) — say where they
  attach, build nothing.
- Any change to the boar's own behaviour, the weapon, the camera or the Hud's existing elements.
- The generated map and the DEV world's own geometry.
- Money, licences, dogs, rotation beyond `SWAP_TEAMS_EACH_DRIVE`.
- Rewriting `ForestTest`'s wave/rest schedule. If the design wants the drive's phase to reset it, say
  so as a **named, separate** decision with Karen's accepted rhythm as the thing at risk.

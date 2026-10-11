# The end of a drive, and the results scene (Task 159)

Builder's research note, 2026-10-12. Written before the code (CLAUDE.md rule 1).
Dispatched by the Director, 2026-10-11/12. Karen's words, verbatim (her doc answers, 2026-10-10):

> "Timer or when all beaters cross line of hunters.And yes could be that all they standing around the
> animals there is light on 4 corners and then showing image transperent with results table. So who
> has purchased who they want to be they can choose but by default who was shooter become beater next
> round"

Approved 2026-10-11: *"end of a drive ... yes"*. **Role rotation and persistence are NOT in this
task** (Karen: *"not now"*): today's `SWAP_TEAMS_EACH_DRIVE` rotation is untouched.

---

## 1. What the system must do

1. **End a drive on the clock, as today** — `DRIVE_SECONDS`, `Phase`'s own `phaseEndsAt`.
2. **End it EARLIER when every real beater is through the hunters' line.** Phantom beaters (the quick
   test's, and the Forest Test's waves) do not count; with no real beater in the drive, only the
   clock ends it.
3. **Gather the drive's shot animals in a row at a gathering spot** — the forest: by the road near the
   stands; DEV: open ground behind the stands. Data per world.
4. **Move every player to stand around them**, and **hold** them there so nobody wanders off.
5. **Four lights on the four corners**, warm, dusk-ish.
6. **Show a semi-transparent results table**: per player, name, role, kills, points — the score the
   drive already computes, with a "drive results" title.
7. **Last the intermission**, then the next drive starts as today, with the scene taken down first.

### Numeric targets

| What | Target | Why that number |
|---|---|---|
| Scene length | `SCORE_SECONDS` = 25 s, unchanged | it IS the intermission Karen asked the scene to last |
| "Crossed the line" | 10 studs past the nearest stand | just past a hunter's own post; standing ON the line is not crossing it |
| Gathering spot | 24 studs behind the middle stand | off the road corridor the drive comes down, still within sight of the stands |
| The row | 6 studs apart, at most 12 animals | a boar's width plus room to walk between them; the cap stops a long drive's row running into the wood |
| The ring | radius 14 studs | close enough to see the animals, far enough not to stand on them |
| The lamps | 4, at 16 studs, range 60, brightness 4, shadows off | Karen's number; just outside the ring; four shadow maps for a 25-second scene is cost for nothing |
| Cost per scene | ≤ 16 Instances (12 animals + 4 lamps), 1 build and 1 clear per drive | the folder is destroyed and rebuilt, never added to |
| Cost per step | `#beaters × #posts` dot products at 4 Hz, in `Running` only | 16 × 9 = 144 at the roster's ceiling |

## 2. What it must not do

| Must not | Why, with the evidence in this repo |
|---|---|
| Keep a second score | `Match.Score` owns points. The results table is the EXISTING score panel reading `MatchSnapshot.rows`; the scene's own kill record carries kind and zone and **no points at all**. The same rule `docs/design/drive-report.md` section 2 already sets |
| Add a phase | every transition in this system is time-driven from `phaseEndsAt`, which is the only clock (`Phase`'s header). The scene is the `Scoring` phase that already existed, exactly as task 158's countdown is the `Assigning` phase that already existed |
| Move a carcass | `Boar.Body` is the only writer of a boar's Instances, and in the Forest Test the drive is handed a **read-only** boar view (`ForestTest.readOnlyBoars`) — moving one would be the drive writing a world it does not own. See §4 |
| Move a character itself | `Match.Body` is the one writer of where a character stands. The scene computes a `CFrame`; `Body.standCharacter` writes it |
| Add a second screen owner | `src/client/Hud` stays the one writer of `HunterHud`. The only client change in this task is one title string, taken from `Drive.CONFIG` |
| Add a remote | this system has no inbound remote at all and keeps none (`docs/design/drive.md` section 9.1) |
| Write `Lighting` | Karen asked for *"light on 4 corners"*, which is four lamps in the world. Time of day is Studio-edited content and has no run-time writer in this repo |
| Respawn anybody for the scene | `Body.place` calls `LoadCharacter`: a new character, a dropped Tool and a reset camera, seconds after a drive she was holding a gun in |
| Let a phantom end a drive | `Match.playerDrivers` filters by `tonumber(driver.id)` — the quick test's `"quick-test"` and the forest's `"beater-3"` have no userId. The same filter the safety rule uses, for the same reason |

## 3. External sources

### 3.1 ioquake3 — `BeginIntermission` / `MoveClientToIntermission` (ADOPTED)

<https://github.com/ioquake/ioq3> — `code/game/g_main.c`, `code/game/g_cmds.c`.
Licence **GPL-2.0**; maintained (the community fork of Quake III Arena, commits through the 2020s).

At the end of a round the game finds one intermission point, moves **every** client to it, and puts
each one in `PM_INTERMISSION` — a movement type that accepts no input — while the scoreboard is
shown; the next round begins by taking them out of it. That is this task's shape exactly: one spot,
everybody moved, everybody frozen, a table on screen, a fixed duration.

**Good:** the freeze and the move are the *same* decision in the *same* place, so a player can never
be moved and still walking. The intermission point is **map data**, not code — which is why a sine
road and a flat arena can share one rule here.
**Bad for us:** it teleports to a camera point and takes the player's body out of the world; Karen
wants to *see* everybody standing round the animals, so the ring is ours and the point is not a
camera.
**Borrowed:** move + freeze as one step (`Body.standCharacter` = the task-158 hold plus a `PivotTo`),
and the spot as world data (`Match.gatherSpotFor` over the marker set).

### 3.2 Valve — Counter-Strike's round end and `mp_freezetime`

<https://developer.valvesoftware.com/wiki/Counter-Strike:_Global_Offensive> (Valve Developer
Community wiki, CC BY-SA; community-maintained, still edited).

CS splits a round into play, a short end-of-round delay with the result on screen, and a *freezetime*
at the **start** of the next round during which players cannot move. Two separate timers, each with
its own cvar, and the scoreboard is a panel over the live view rather than a separate screen.

**Good:** the result is read **in the world**, with the bodies still there — which is what Karen is
describing. The two timers are independent, so tuning one cannot shorten the other.
**Bad:** the freeze is at the round's START, not its end; nothing is gathered or laid out.
**Borrowed:** the panel is semi-transparent and over the world, never a full screen (which is what
`SCORE_PANEL_TRANSPARENCY` = 0.25 already is), and the end-of-drive delay stays its own number
(`SCORE_SECONDS`), independent of the start countdown (`INTERMISSION_SECONDS`, task 158).

### 3.3 Unreal Engine — `AGameMode` match state (`EndMatch`, `WaitingPostMatch`)

<https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/GameFramework/AGameMode>
Epic's own documentation (proprietary engine, public docs; current).

A match ends by moving the mode's **state machine** into `WaitingPostMatch`; the mode then tells the
world, and spectating/freezing is a consequence of the state rather than a thing the ending code does
itself. `ReadyToEndMatch` is the overridable predicate that answers "is it over".

**Good:** the *predicate* and the *consequences* are separate — exactly `Phase.beatersThrough`
(pure, two numbers) against the effects the owner applies.
**Bad:** a mode subclass per rule; here one pure function and a config boolean is the whole of it.
**Borrowed:** the ending is a predicate the state machine asks, never a side effect the thing that
noticed performs. This repo's `docs/design/forest-drive.md` §11.1 already cites Unreal for the
same split over spawn points.

### 3.4 Roblox — `PointLight`

<https://create.roblox.com/docs/reference/engine/classes/PointLight>. Engine documentation, current.

`Color`, `Brightness`, `Range` and `Shadows` are the four properties a lamp has. The page documents
no falloff curve and no cost model, so **what four of them look like together is a screenshot and not
an estimate** (rule 5) — which is why this task's one screenshot is of the lit scene.

### 3.5 Borrowed from inside this repo (rule 2)

* **the hold** — `Body.holdCharacter` (task 158): the same three humanoid numbers and the same
  `Anchored` root, saved in the same `held` table, so there is still exactly one writer of whether a
  character can move. `Body.standCharacter` is `tieCharacter` without the rope.
* **the run-time folder** — `Workspace.DriveMarkers` and `Workspace.Boars`: a Play-time folder in
  Workspace cannot dirty a harness run, which compares the **Edit-mode** DataModel.
* **destroy-and-rebuild** — `Body.OUTFIT_NAME`'s discipline, so two drives can never leave eight
  lamps standing.
* **the results table** — the Milestone 1.7b score panel, already semi-transparent, already one row
  per player with name, role, kills and points, already up for the whole of `Scoring`. This task
  changes its **title**.

## 4. The pattern adopted, and the one deviation from Karen's words

**Adopted:** ioquake3's intermission, with the spot taken from the world's own geometry (Valve /
Unreal) and the ending expressed as a pure predicate the state machine asks (Unreal).

**The deviation, named rather than buried: the animals in the row are DISPLAY COPIES, not the
carcasses.** Karen said *"all they standing around the animals"*. Three facts make the carcass itself
the wrong object:

1. `Boar.Body` owns a boar's Instances (`docs/PROJECT_CONTEXT.md`: *"two systems wrote the creature's
   position"* is one of the failures these rules exist for);
2. the drive ends by **clearing** its animals — `Phase.enterScoring` emits `clearBoars`, which is
   `Runtime:clear("driveOver")`, and every carcass is despawned at the instant the scene begins;
3. in the Forest Test the drive does not own the animals at all (`ForestTest.readOnlyBoars` has no
   `clear` and no `spawn`), so moving one would be the drive writing another owner's world.

So `Match` keeps a thin per-drive record of what was shot (kind, zone, who shot it — **no points**),
and `Match.Scene` lays out one anchored, non-colliding, `CanQuery = false` box per kill, sized by the
kind's own scale. It is a **grey box**, like every other first cut here, and the next step is one
injected template function rather than a rewrite (queued as TASKS.md row 159a). What Karen judges in
the morning is the gathering, the lights and the table; whether the animals need to be the real
models is her call, and the seam for it is one function.

**The second deviation: the results table says SHOOTER / DRIVER on its rows**, which are the team
names, while Karen says hunter / beater. That vocabulary question is already open from task 158
(TASKS.md row 158a) and renaming half the Hud to settle it quietly is exactly what that row exists to
prevent.

## 5. The ownership, one writer each

| Thing | Owner (the only writer) | Where |
|---|---|---|
| Which of the two endings ended the drive, and when the scene exists | `Match.Phase` (pure) | `src/server/Match/Phase.luau` |
| How many beaters there are and how many are through the line | `Match` (the measurement) + `Match.crossedLine` (the pure rule) | `src/server/Match/init.luau` |
| Where the animals are gathered and which way the scene faces | `Match.gatherSpotFor` (pure, over the marker set) | `src/server/Match/init.luau` |
| `Workspace.DriveScene` — the animals and the four lamps | **`Match.Scene`**, new | `src/server/Match/Scene.luau` |
| Where a character stands, and whether it can move | `Match.Body` — unchanged owner, one new function | `src/server/Match/Body.luau` |
| The results table on screen | `src/client/Hud` — unchanged owner; the wording is `Drive.CONFIG`'s | `src/client/Hud/init.luau`, `src/shared/Drive/init.luau` |
| The score in it | `Match.Score` — unchanged, and there is no second one | `src/server/Match/Score.luau` |

## 6. How it is tested

* `tests/server/match_scene.spec.luau` (new, pure): the crossing predicate on both sides of the line
  and against a **curved** road (the case the plane alone gets wrong), the gathering spot, the row's
  spacing and centring, the ring's radius and facing, **four** corners, and the folder built and torn
  down.
* `tests/server/match_phase.spec.luau`: **both endings**, the zero-beater clause, the rule off, the
  whole roster held at the scene, the effect ORDER, and the scene taken down on the way into both
  `Assigning` and `Waiting`.
* `tests/server/zz_drive_boundary.spec.luau`: the REAL drive's boundary in the DEV place — four lamps
  in the world, one animal per recorded kill, every player held and standing on the ring, and the
  scene gone before the next drive.
* `tests/client/match_client.spec.luau`: the title says RESULTS, and the panel is see-through.
* One screenshot of the scene in the Forest Test (rule 5), looked at once.

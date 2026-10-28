# BRIEF: task 298 -- the lobby shooting range (phase A, design only)

This file is the Architect's first input and **overrides anything older** in `docs/`, `TASKS.md` or an
earlier design (CLAUDE.md, "Files the roles talk through"). Phase A ends with
`docs/design/shooting-range.md`; the build is phase B.

Note: `docs/research/2026-10-27-shooting-range.md` (read it: every number below comes from it).

## KAREN, VERBATIM

> "I think we can build in lobby shooting range where anyone can shoot moving target like in real
> life head and boddy of animal and then we can tune shooting and will see what to improve ...
> because now I feel it's broken shooting"

> "lets build a range / there will be a several spots where you go and click e or similar button then
> can choose from menu options like animal speed weapon cartigae ect / start building / then after we
> will try shooting and when we like how it go in shooting range we implement same in game"

## DECISIONS ALREADY TAKEN (Director; Karen said go). The design may not reopen these.

1. **WHERE: the LOBBY** (the Forest Test is the place Karen plays). Several shooting **SPOTS**. At a
   spot a real `E` press opens a **MENU**: animal (boar first; deer when its rig allows), pace
   (walk / trot / run -- **the speeds our animals really use, read from their own config, never new
   numbers**), weapon (the four guns), cartridge (the loads that weapon really has), distance (start
   at ~35 m; 25 / 50 later). Then the target runs.
2. **TARGET: the REAL animal model** with its real hit zones and real gait animation, moving along a
   fixed lane, crossing left-right and back -- the European running-boar range. **Not a flat picture.**
3. **ONE SHOOTING PATH.** The same `Weapon` owner, the same `Ballistics`/`Flight`, the same claim
   checks, the same `HitLog` zones as the hunt. The range adds a target and a menu and **never a
   second way to shoot or score**. A shot landing differently on the range than in the hunt is a RANGE
   bug.
4. **FEEDBACK:** the existing hit card and toast, plus a **range board**: shots, hits,
   head / neck / chest / body / miss, distance, and **the LEAD the shot actually had**. No money, no
   penalties, no licence check, no animal counts in the drive.
5. **"WHEN WE LIKE IT IN THE RANGE WE IMPLEMENT THE SAME IN GAME":** the design must make tuning in
   the range **be** tuning of the game. The shooting numbers the range lets us change live live in
   **ONE data file both read**, tuned live by the Director's override -- `poses.json` is the model
   (`docs/research/2026-10-01-poses-as-data.md`, CLAUDE.md "Content lane") -- and "implement in game"
   is **one commit of that data file**.
6. **FIRST PLAYABLE CUT (phase B):** ONE spot, the boar, three paces, the four weapons and their
   cartridges, ~35 m, the board. More spots, deer and distances come after.

## THE TWO KNOWN SHOOTING DEFECTS: STATE AT `afd31918` (dispatch item e)

Task 256 (`docs/research/2026-10-24-real-shooting.md`) found the two that match Karen's "broken
shooting". **Both are FIXED. The range is not to be designed on top of either, and must not re-solve
them.**

| Defect | State | File plus symbol |
|---|---|---|
| (a) the lead carried the network round trip | **FIXED, bounded** | `Weapon.catchUpFor`, `Weapon.viewWindowFor` in `src/server/Weapon/init.luau`: `Player:GetNetworkPing()` inside a `pcall`, zero on a negative/NaN/missing ping, clamped at `FLIGHT_CATCHUP_MAX_SECONDS` 0.15 and `CLAIM.VIEW_LAG_MAX_SECONDS` 0.45. `Flight.launch` spends the catch-up once |
| (b) the impact puff was world-anchored and drifted off a running animal | **FIXED** | `Effects.ridesWith` and `puff(..., attachTo)` in `src/client/Weapon/Effects.luau`: the `Attachment` goes onto the struck unanchored `BasePart` via `attachTo.CFrame:ToObjectSpace(frame)`; the anchored host survives for static surfaces only |

**What is STILL OPEN is what the range exists to close, and the design must say how it exposes each:**

- **`Shotgun.CONFIG.FLIGHT_CATCHUP_PING_FACTOR = 1.0`** -- open **item H** of
  `docs/design/shotgun.md` section 15. 1.0 (treat the engine's ping as the round trip) against 2.0
  (one way); a loopback Studio session reads 1.7 ms, so no measurement here can tell them apart.
  **It IS in the first-cut tunable set below, deliberately: this range is the venue item H was
  waiting for.** The design must state that closing it needs a published session on two machines
  (Karen's call), and that the range's job is to make the dial reachable and the error visible.
- **`Shotgun.CONFIG.CLAIM.VIEW_LAG_BASE_SECONDS = 0.30`** -- its own comment calls it *"the one
  invented number here"*. Also first-cut tunable.

## THE ARITHMETIC THE DESIGN MUST BE BUILT AROUND

At 35 m = **125 studs**, with the animal at `PACE.RUN_SPEED` 24 studs/s:

| Weapon / load | flight to 125 studs | true ballistic lead | of a 5.5-stud body |
|---|---|---|---|
| .416 Rigby | 0.049 s | 1.18 studs = 33 cm | 0.21 |
| .45-70 lever | 0.058 s | 1.39 studs = 39 cm | 0.25 |
| 12 ga slug | 0.076 s | 1.83 studs = 51 cm | 0.33 |
| 12 ga 00 buck | 0.103 s | 2.46 studs = 69 cm | 0.45 |

**`VIEW_LAG_BASE_SECONDS` 0.30 s at that pace is 7.2 studs of animal travel: three to six times the
whole ballistic lead, and 1.3 body lengths.** So at this distance the range measures the LAG and CLAIM
path, not the ballistics, and **the board must report the lead as two numbers, never one**: the
ballistic lead (flight time times animal speed) and the view offset (where this client drew the animal
against the instant the server resolved). A single "lead" number would blame ballistics for a clock.

**The paces are the animal's own** (`src/server/Boar/init.luau` `PACE`, the table `ForestTestBoot`
runs the forest on): `WALK_SPEED` 4.5, `TROT_SPEED` 11, `RUN_SPEED` 24 studs/s. Invent none.
**The lane**: 125 studs out, a 40-stud (11.2 m) visible window, so a crossing takes 8.9 / 3.6 / 1.7 s
-- the trot brackets ISSF's 5 s and 2.5 s. **Direction alternates** (ISSF makes the change mandatory:
a lane that runs one way trains one lead).

## KNOWN CONSTRAINTS (measured before; the design must honour them)

1. **The DEV place has NO lobby surfaces.** The pads and the shop panel exist only in the Forest Test.
   So the range must be **BUILT FROM CODE/DATA** -- no Studio-made parts, per CLAUDE.md's layout rules
   (a Studio-made instance inside a Rojo container is DELETED at the next Connect) -- so the harness in
   DEV can construct one and test it. State explicitly in which worlds the range is built and what
   decides that.
2. **`src/server/TestArena.luau` plus `src/server/ArenaBoot.server.luau` exist** -- read them and say
   **whether the range reuses them**. Note for the decision: `ArenaBoot` returns early unless
   `Map.EXPECTED_WORLD == "arena"`, and `TestArena` is *"the only writer of Workspace.TestArena"* and
   is the map's rollback, so reusing the module itself is probably wrong while reusing its PATTERN
   (world geometry built from code into one `Workspace` folder, every dimension in one `LAYOUT` table)
   is probably right. Say which, with the reason.
3. **The boar's movement owner today is `src/server/Boar` (`Brain` decides, `Body` writes).**
   `Boar.Body` is *"the only writer of a boar's Instances"* and drives an **unanchored** body through
   `LinearVelocity` plus `AlignOrientation`, never by per-frame CFrame writes, because *"two systems
   writing a creature's position killed the previous project"*. **The range must NOT add a second
   writer of a boar's CFrame or animation.** The Architect must NAME the owner of the range target's
   motion and say by which existing seam the range commands a pace and a lane (the `Runtime:urge`
   shape, a new `Brain` state, an injected route -- the Architect decides, and rule 3 decides that it
   is exactly one).
4. **A live probe gets a fresh module cache** -- measure INSTANCE facts, not module state.
5. **The cursor and the trigger are already solved, in shipped code with a shipped caller** (lesson
   L-108: do not state an engine property from memory). The Architect is read-only and cannot reach
   Studio, so this BRIEF supplies the evidence and the design must cite **the shipped caller**, not
   the Roblox docs:
   - `src/client/Camera/Cursor.luau` is *"THE ONLY WRITER of UserInputService.MouseBehavior,
     .MouseIconEnabled, .MouseDeltaSensitivity and Mouse.Icon"*. API: `Cursor.requestFree(tag)` /
     `Cursor.release(tag)`; `Cursor.apply()` (once per frame, by the owner) writes
     `Enum.MouseBehavior.Default` and `MouseIconEnabled = true` while any tag is out and
     `Enum.MouseBehavior.LockCenter` otherwise, and counts writes it did not cause (`reasserts`).
   - `src/client/Weapon/Input.luau`: `Input.requestHold(tag)` / `Input.releaseHold(tag)`. The four
     `ContextActionService` bindings (`FIRE` on `MouseButton1`, `RELOAD` on `R`, `SELECT_AMMO` on `X`,
     `AIM` on `MouseButton2`) stay bound and still return `Pass`, but act on nothing while a hold is
     out; entering the hold drops the aim.
   - `src/client/Hud/ShopPanel.luau` holds **both at once** (`Cursor.requestFree("shop")` plus
     `WeaponInput.requestHold("shop")`) and releases exactly its own tags on close. **The range menu is
     that path with the tag `"range"`.** Do not design a new mechanism, and do not rely on
     `GuiButton.Modal` -- `Input.luau`'s own header refuses it as a second writer of `MouseBehavior`.
6. **The existing feedback is owned.** `HitLog` is *"THE ONE WRITER of who hit what, where, and did it
   die"*, fed by `Weapon.HitReported` and `Boar.Runtime.Downed`, and *"adds no source of truth"*. The
   range board must READ that path, not start a second record. `Hud.HitCard` and the toast stay as they
   are.
7. **Flags.** A new feel-critical path is born OFF as a row in `src/shared/Flags/init.luau` with
   `default = false`, an owner, `born`, `expires` within 21 days and a one-line `why`, read ONCE at its
   owner's boundary and passed inward. Say which flag(s) the range needs.

## FIRST-CUT TUNABLE SET (decision 5), AND WHAT IS REFUSED

Today **no** shooting number is in a data file: they are Luau `CONFIG` tables in
`src/shared/{Shotgun,Rifle,Lever,SemiAuto}/init.luau`, assembled at one boundary by
`src/shared/Weapons/init.luau` (`Weapons.for(id)`). **That single assembly point is the one place the
data file is read**, exactly as `poses.json` is read at the viewmodel's boundary.

**IN** (per weapon, per load where the shipped row is per load): `MUZZLE_STUDS_PER_S`,
`DRAG_PER_STUD`, `GRAVITY_SCALE`, `SPREAD_FULL_DEG`, **`FLIGHT_CATCHUP_PING_FACTOR`**,
`FLIGHT_CATCHUP_MAX_SECONDS`, `CLAIM.VIEW_LAG_BASE_SECONDS`.

**OUT, with the reason** (and what moving each would take):

| Refused | Reason | What it would take |
|---|---|---|
| the kill zones (`Boar.CONFIG.ZONES`) | geometry, not a scalar: welded parts built at spawn by `Boar.Body.zones`, with server specs asserting their extents | zones read from the file at `Body.create`, the specs reading the same file, and a rebuild path for live animals. Its own task |
| the wound model (`Boar.Wound`) | it decides whether an animal dies, so it moves the match, the money and the report | its own lane and its own proof |
| rate of fire, magazine size, reload timings | mechanism, not ballistics; specs assert the state transitions | the engineering lane, as today |
| recoil and the viewmodel's poses | **already a content lane** (`poses.json`); a second one would break rule 3 | nothing: use `tools/pose.py` |
| `CLAIM.LINE_TOLERANCE_STUDS`, `CLAIM.POSITION_TOLERANCE_STUDS` | the server's licence to believe a client. **A live dial on a security bound is a live dial on an exploit** | stays a reviewed commit, deliberately |

## WHAT THE DESIGN MUST CONTAIN

1. **The owners table** (rule 3): one writer for the range geometry, one for the target's motion, one
   for the menu, one for the board, and the statement that the shooting path gains no new writer.
2. **In which worlds the range is built** and what decides it, with constraint 1 honoured.
3. **Whether `TestArena`/`ArenaBoot` are reused** (constraint 2), with the reason either way.
4. **The seam by which the range commands the target's pace and lane** without a second CFrame writer
   (constraint 3).
5. **The menu**: the prompt, the panel, the cursor and trigger doors by their shipped names
   (constraint 5), the option lists and where each list's values come from (the gun's own loads, the
   animal's own `PACE`).
6. **The board**: its columns, and the **two-number lead** of the arithmetic section, naming where each
   number is measured and by whom.
7. **The data file**: its path, its shape, the ONE boundary that reads it, the live-override route
   (`tools/pose.py`'s shape), and the sentence that makes "implement in game" one commit.
8. **The flag row(s)** (constraint 7).
9. **The phase-B proof route**: a real `E` (`263key.ps1`), real mouse clicks on every menu option, real
   shots -- and what each step's instrument is.
10. **Open decisions for Karen**, listed separately, so the Director can put them to her.

## WHAT THE DESIGN MAY NOT DO

- Reopen decisions 1-6.
- Add a second shooting path, a second score, a second position writer for an animal, or a second
  cursor/mouse writer.
- Put a Studio-made part anywhere.
- State an engine property from memory where constraint 5 already gives the shipped answer.

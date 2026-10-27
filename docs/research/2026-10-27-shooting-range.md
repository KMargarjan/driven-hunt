# The lobby shooting range: a running boar on a lane, a menu, and a board that shows the lead

Task 298, phase A (design only). Karen, 2026-10-27, verbatim:

> "I think we can build in lobby shooting range where anyone can shoot moving target like in real
> life head and boddy of animal and then we can tune shooting and will see what to improve ...
> because now I feel it's broken shooting"

> "lets build a range / there will be a several spots where you go and click e or similar button then
> can choose from menu options like animal speed weapon cartigae ect / start building / then after we
> will try shooting and when we like how it go in shooting range we implement same in game"

## 0. WHAT THE SYSTEM MUST DO

1. **Several SPOTS in the lobby.** Standing at one, a real `E` press opens a menu.
2. **The menu picks the trial**: animal (boar first), pace (walk / trot / run), weapon (the four guns),
   cartridge (the loads that weapon really has), distance (~35 m first; 25 / 50 later).
3. **The target is the real animal** -- the real model, the real welded hit zones, the real gait clip --
   crossing a fixed lane left-right and back. Not a flat picture.
4. **ONE shooting path.** The same `Weapon` owner, the same `Ballistics`/`Flight`, the same claim
   checks, the same `HitLog` zones as the hunt. A shot that lands differently on the range than in the
   hunt is a RANGE bug, by definition.
5. **A board**: shots, hits, head / neck / chest / body / miss, distance, and **the lead the shot
   actually had** -- where the animal was when the bullet arrived versus where the bullet went. No
   money, no penalty, no licence, no drive counts.
6. **Tuning the range IS tuning the game**: the shooting numbers live in ONE data file both read, the
   Director turns them live, and "implement in game" is one commit of that file.

## 1. SOURCES

### A. ISSF, Official Statutes, Rules and Regulations -- 10 m Running Target (section 8)
- https://www.issf-sports.org/theissf/rules.ashx
- https://www.issf-sports.org/sports/discipline.ashx?discipline=RT

Copyright ISSF, freely published, **current** (the rulebook is reissued every Olympic cycle; Running
Target is still a World Championship discipline). The oldest continuously-run moving-target discipline
and the one with exact numbers: the target is **a boar silhouette carrying scoring rings**, it crosses
a **2 m opening** at **10 m**, and the only variable is the crossing TIME -- **5 s (slow run) and
2.5 s (fast run)** -- and the athlete shoots 30 slow plus 30 fast, with a mandatory direction change
so neither shoulder is favoured.

**Does well:** it proves the shape we want -- one target, one lane, one variable at a time, and the
crossing time (not the speed) as the dial a shooter actually feels. The mandatory left-right AND
right-left is a real finding: a lane that only ever runs one way trains one lead.
**Does badly for us:** 10 m and an air rifle. Its speeds are apparent speeds for a tiny target;
nothing in its table transfers as a number.

### B. Deutscher Jagdverband -- the laufender Keiler (running boar)
- https://www.jagdverband.de/
- https://www.jagdverband.de/wild-wissen/jagdliches-schiessen

The national hunting association's own competition and education material, **current**, and the
doctrine this game's hunt is already modelled on (`Boar.Wound`, the Kammerschuss zones and the safety
arc all cite the DJV). The hunter's discipline, not the athlete's: a boar target **crosses a lane at
50 m**, the shooter fires a hunting rifle standing and unsupported, and the scoring is **anatomical**
-- the Kammer (heart/lung) counts and a paunch hit is a fault, not a lower ring. It is the discipline
a Drueckjagd hunter is expected to be able to pass.

**Does well:** this is exactly our game, at exactly our kind of distance, scored the way our
`Boar.CONFIG.ZONES` already scores. It settles decision 4: the board's columns are ZONES, not rings.
**Does badly:** the association publishes the discipline, not a measured target speed. The figures
quoted for these ranges (a boar crossing at roughly 20-25 km/h, 5.5-7 m/s) come from range operators
rather than from one authoritative table, so **the speed is taken from our own animal's config
instead** (section 3) -- which is what decision 1 asks for anyway.

### C. Svenska Jaegareförbundet -- the loepande aelg (moving-moose) range
- https://jagareforbundet.se/
- https://jagareforbundet.se/skytte/

The Swedish hunters' association, **current**, and the mandatory moose-shooting test in Sweden, Norway
and Finland: a **moose-sized target moving across a lane at 80 m**, a fixed number of shots inside a
time limit into a scoring area the size of the animal's vitals, repeated until passed. The target runs
at roughly a moose's own trot, which is the point -- it is calibrated against the animal, not against
a sport's stopwatch.

**Does well:** the clearest precedent for *"the target moves at the speed the animal really moves"*,
which is decision 1's rule, and for a pass/fail read off the vitals rather than a score.
**Does badly:** 80 m, a centre-fire rifle, a 500 kg animal; the lane and the zones are an order of
magnitude off ours.

### D. theHunter: Call of the Wild (Expansive Worlds, 2017) -- the harvest screen
- https://store.steampowered.com/app/518790/
- https://thehunter.fandom.com/wiki/Harvest_Screen

Commercial, closed source; **actively maintained** (still shipping content in 2026). The reference for
what a shot's RESULT should look like: after a kill it shows the animal, **which organs the bullet
passed through**, the shot distance, and whether the hit was lethal -- so the player learns *where* he
hit, not merely *that* he hit.

**Does well:** the anatomical readout is what Karen is asking for with *"head and boddy of animal"*.
Borrowed as the board's zone columns beside the existing hit card's dot.
**Does badly for us:** it is a POST-MORTEM screen -- one animal, after it dies. It shows nothing about
a MISS, and a range is mostly misses. It also says nothing about lead.

### E. Aim Lab (State Space Labs) and KovaaK's -- per-shot moving-target telemetry
- https://store.steampowered.com/app/714010/Aim_Lab/
- https://store.steampowered.com/app/824270/KovaaKs/

Commercial, closed source, **actively maintained**. The only widely used prior art that reports a
moving-target miss as a VECTOR rather than a score: tracking tasks report accuracy over time, and the
breakdown separates **how far off** from **in which direction** -- the "behind the target" signature
that is under-leading.

**Does well:** precisely the missing half of source D. A range whose feedback is "miss" teaches
nothing; "0.9 studs BEHIND" teaches the lead in one shot. Adopted as the board's LEAD row.
**Does badly:** no anatomy, no ballistics, no distance -- these are mouse-skill trainers. The per-shot
vector is read off their UI, not from a published format, so what is borrowed is the IDEA (a signed
lead, not an absolute error).

### F. Our own prior art, which outranks all of the above for the mechanism
- `docs/research/2026-10-24-real-shooting.md` (task 256): the ballistics, the lead, the two defects.
- `docs/research/2026-10-01-poses-as-data.md` plus CLAUDE.md "Content lane": numbers in a data file,
  tuned live, saved in one commit. **This is the pattern decision 6 asks for, already shipped once**
  for `src/shared/Viewmodel/poses.json`.
- `docs/research/2026-10-17-the-pad-menu-and-the-truck.md` and `src/client/Hud/ShopPanel.luau`: a
  `ProximityPrompt` opening a full-screen panel that is clickable in first person. **The menu of
  decision 2 is that panel again**, and section 4 names the two shipped doors it uses.

## 2. THE TWO KNOWN SHOOTING DEFECTS: ARE THEY STILL LIVE? (dispatch item e)

Task 256's note named two, and both of Karen's sentences pointed at them. Read against the code at
`afd31918`:

| Task 256 defect | State today | Evidence (file plus symbol) |
|---|---|---|
| (a) the lead carried the network round trip; `ping`/`latency` appeared nowhere in `src/` | **FIXED, and bounded** | `Weapon.catchUpFor` and `Weapon.viewWindowFor` (`src/server/Weapon/init.luau`) read `Player:GetNetworkPing()` inside a `pcall`, contribute ZERO on a negative, NaN or missing ping, and clamp at `Shotgun.CONFIG.FLIGHT_CATCHUP_MAX_SECONDS` (0.15) and `CONFIG.CLAIM.VIEW_LAG_MAX_SECONDS` (0.45). `Flight.launch` spends the catch-up once, on the first `advance`. |
| (b) the impact puff was `Anchored` in the world and the animal ran out from under it | **FIXED** | `Effects.ridesWith` (`src/client/Weapon/Effects.luau`) returns the struck part when it is an unanchored `BasePart`, and `puff(..., attachTo)` then parents its `Attachment` straight onto that part with `attachTo.CFrame:ToObjectSpace(frame)` -- no host part, no weld, no per-frame write. The anchored host survives only for static surfaces. |

**So the range is NOT being built on top of either defect.** What task 256 left OPEN is what the range
exists to close, and it is two numbers:

- **`Shotgun.CONFIG.FLIGHT_CATCHUP_PING_FACTOR = 1.0`** (`src/shared/Shotgun/init.luau`) -- open item H
  of `docs/design/shotgun.md` section 15. The engine's docs do not say whether `GetNetworkPing` is the
  round trip or one way, and **a loopback Studio session reads 1.7 ms**, which is 0.065 studs on a
  sprinting boar: the measurement cannot tell 1.0 from 2.0. It is in the first-cut tunable set
  (section 5) for exactly that reason.
- **`CONFIG.CLAIM.VIEW_LAG_BASE_SECONDS = 0.30`** -- its own comment calls it *"the one invented number
  here"*, derived from a single measured 0.178 s with 1.7x margin. Also first-cut tunable.

Section 3's arithmetic then says something the range must be designed around: **at 35 m these two
numbers move the picture far more than the ballistic lead does.**

## 3. NUMERIC TARGETS

**The animal's own speeds** (decision 1: read from its config, invent nothing).
`src/server/Boar/init.luau` `PACE` -- the table `ForestTestBoot` runs the forest on:

| Pace | studs/s | m/s (1 stud = 0.28 m) | km/h | the real animal |
|---|---|---|---|---|
| walk | `WALK_SPEED` 4.5 | 1.26 | 4.5 | a boar's working walk |
| trot | `TROT_SPEED` 11 | 3.08 | 11.1 | its travelling trot |
| run | `RUN_SPEED` 24 | 6.72 | 24.2 | a hard canter. `MOVE.SPRINT_SPEED` 38 (40 km/h) is the real flat-out sprint; Karen cut the forest to 24 because *"when they fleet make speed slover it's to fast"* (task 123 r4) |

**The lane.** 35 m = **125 studs** from the firing line. A visible crossing window of **40 studs
(11.2 m)** gives a crossing time of **8.9 s at a walk, 3.6 s at a trot, 1.7 s at a run** -- which
brackets ISSF's 5 s / 2.5 s (source A) with the trot, and makes the run harder than the sport's fast
run. The direction alternates (source A's mandatory change).

**The true ballistic lead at 125 studs**, from the shipped rows (`MUZZLE_STUDS_PER_S`,
`DRAG_PER_STUD`; exponential drag, so `t = (exp(k*d) - 1) / (k*v0)`):

| Weapon / load | v0 studs/s | k per stud | flight to 125 studs | lead at run (24 studs/s) | as a boar body (5.5 studs) |
|---|---|---|---|---|---|
| .416 Rigby (`Rifle`) | 2612 | 4.29e-4 | 0.049 s | 1.18 studs = 33 cm | 0.21 |
| .45-70 (`Lever`) | 2232 | 5.21e-4 | 0.058 s | 1.39 studs = 39 cm | 0.25 |
| 12 ga slug (`Shotgun`, `SemiAuto`) | 1752 | 1.06e-3 | 0.076 s | 1.83 studs = 51 cm | 0.33 |
| 12 ga 00 buck | 1442 | 2.63e-3 | 0.103 s | 2.46 studs = 69 cm | 0.45 |

**And the number that matters most**: `VIEW_LAG_BASE_SECONDS` 0.30 s at a run is **7.2 studs** of
animal travel -- **three to six times the whole ballistic lead at this distance**, and 1.3 body
lengths. So:

- **TARGET 1.** At 35 m the range measures the LAG and CLAIM path, not the ballistic lead. The board
  must report the lead as **two numbers, never one**: the ballistic lead (flight time times animal
  speed) and the view offset (where this client drew the animal versus the instant the server
  resolved against). A single "lead" number would blame ballistics for a clock.
- **TARGET 2.** A shot the player sees as centred on the chest must log `zone = chest`. Acceptance:
  over 20 run-pace shots with the correct lead, **zero** shots where the client drew a hit mark on the
  animal and the server logged no hit, and zero where the server logged a zone whose DRAWN part the aim
  point was not on (standing rule L: geometric against the drawn model).
- **TARGET 3.** Lane crossing times within **plus or minus 10 %** of the table above, measured off the
  animal's own position samples -- otherwise the pace labels lie and every lead number computed from
  them is wrong.
- **TARGET 4.** 50 m (179 studs) later: slug flight 0.113 s, lead at run **2.70 studs = 76 cm**. That
  is the distance at which the ballistic lead first exceeds half a body length.

## 4. THE PATTERN ADOPTED, AND WHY (rule 2: borrowed, not invented)

| Piece | Borrowed from | Why not something else |
|---|---|---|
| the lane, one variable at a time, alternating direction | source A (ISSF 10 m RT) | a discipline refined over 50 years; the alternation is a finding we would not have guessed |
| anatomical scoring at a hunter's distance | source B (DJV laufender Keiler) | our `Boar.CONFIG.ZONES` already is this; rings would be a second scoring model |
| target speed = the animal's own speed | source C (loepande aelg) plus decision 1 | a new speed table would be a second answer to "how fast is a boar" |
| the result as anatomy | source D (theHunter harvest screen) | shows where, not just whether |
| the miss as a SIGNED lead, not an error magnitude | source E (Aim Lab, KovaaK's) | "behind by 0.9 studs" teaches the lead; "miss" teaches nothing |
| the menu: `ProximityPrompt` into a full-screen panel, clickable in first person | **our own** `Hud.ShopPanel` | shipped, reviewed, and proven with real clicks (task 181) |
| the numbers as DATA, tuned live, saved in one commit | **our own** content lane (`poses.json`, tasks 98/113) | the only route that makes decision 6 true by construction |
| geometry built from code into one `Workspace` folder | **our own** `TestArena` and `Lobby.Build` | CLAUDE.md layout: a Studio-made part in a Rojo container is deleted at the next Connect, and the DEV place has no lobby surfaces at all |

**Nothing is invented here.** The one piece with no external precedent is the two-number lead readout
of TARGET 1, and its reason is written above: our own measurement says the view window dominates the
ballistics at this distance, so a one-number readout would be the wrong instrument.

**The cursor and the trigger are SHIPPED mechanisms, read off the code rather than from the engine
docs** (lesson L-108):

- `Camera.Cursor` (`src/client/Camera/Cursor.luau`) is *"THE ONLY WRITER of
  UserInputService.MouseBehavior, .MouseIconEnabled, .MouseDeltaSensitivity and Mouse.Icon"*. It takes
  **tagged requests**: `Cursor.requestFree("range")` and `Cursor.release("range")`, resolved once per
  frame in `Cursor.apply`, which writes `Enum.MouseBehavior.Default` plus `MouseIconEnabled = true`
  while any tag is out and `LockCenter` otherwise, and counts every write it did not cause
  (`reasserts`, a number a spec asserts is zero).
- `Weapon.Input.requestHold("range")` and `releaseHold` are the other door: the four
  `ContextActionService` bindings (`FIRE` on `MouseButton1`, `RELOAD` on R, `SELECT_AMMO` on X, `AIM`
  on `MouseButton2`) stay bound and still return `Pass`, but act on nothing while a hold tag is out --
  *"without this, clicking a row in the report would also fire the gun"*. Entering the hold drops the
  aim as well.
- `Hud.ShopPanel` uses **both together** (`Cursor.requestFree("shop")` plus
  `WeaponInput.requestHold("shop")`) and releases exactly its own tags on close. The range menu is that
  path with the tag `"range"`.

So phase B's click-proof route is: `263key.ps1` sends a real `E` at the spot, the prompt fires, the
panel opens, the cursor frees and the trigger holds, real mouse clicks pick each menu option, the panel
closes and releases both tags, then real `MouseButton1` shots. Every step uses a mechanism that already
has a shipped caller.

## 5. WHICH NUMBERS BECOME DATA IN THE FIRST CUT (decision 6)

Today **none** of the shooting numbers is in a data file: they are Luau `CONFIG` tables in
`src/shared/Shotgun/init.luau`, `src/shared/Rifle/init.luau`, `src/shared/Lever/init.luau` and
`src/shared/SemiAuto/init.luau`, assembled at one boundary by `src/shared/Weapons/init.luau`
(`Weapons.for(id)` copies `SPREAD_FULL_DEG`, `MUZZLE_STUDS_PER_S`, `DRAG_PER_STUD` and `GRAVITY_SCALE`
into one table). That single assembly point is what makes this cheap: **one file read at one
boundary**, exactly as `poses.json` is read at the viewmodel's boundary.

**IN the first cut** (per weapon, and per load where the shipped row is per load):

| Number | Where it lives today | Why it is in |
|---|---|---|
| `MUZZLE_STUDS_PER_S` | each gun's CONFIG | sets the flight time, so it sets the lead |
| `DRAG_PER_STUD` | each gun's CONFIG | the lead's curve with distance |
| `GRAVITY_SCALE` | each gun's CONFIG | the drop and zero Karen says is "not needed"; proving that live needs the dial |
| `SPREAD_FULL_DEG` | each gun's CONFIG | buckshot's cone, the one thing a range makes visible |
| `FLIGHT_CATCHUP_PING_FACTOR` | `Shotgun.CONFIG` | **task 256's open item H**: 1.0 against 2.0, undecidable on a loopback. The range IS the venue that decides it |
| `FLIGHT_CATCHUP_MAX_SECONDS` | `Shotgun.CONFIG` | the bound on the above; a factor without its bound is half a dial |
| `CLAIM.VIEW_LAG_BASE_SECONDS` | `Shotgun.CONFIG.CLAIM` | *"the one invented number here"*, and section 3 says it dominates at 35 m |

**NOT data in the first cut**, and what moving each would take:

| Number | Why not yet | What it would take |
|---|---|---|
| the kill zones (`Boar.CONFIG.ZONES`) | geometry, not a scalar: welded parts built at spawn by `Boar.Body.zones`, and the server specs assert their extents. A live change would have to rebuild every spawned animal's zone parts | zones read from the file at `Body.create` time, the zone specs reading the same file, and a rebuild path. Its own task |
| the wound model (`Boar.Wound` damage and flight thresholds) | changes whether an animal dies, so it changes the match, the money and the report -- not a picture | its own lane and its own proof; it is not a shooting-feel dial |
| rate of fire, magazine size, reload timings | mechanism, not ballistics; each has specs asserting state transitions | the engineering lane, as today |
| recoil and the viewmodel's poses | **already a content lane** (`poses.json`) and must not get a second one | nothing: use `tools/pose.py` |
| `CLAIM.LINE_TOLERANCE_STUDS`, `CLAIM.POSITION_TOLERANCE_STUDS` | these are the server's LICENCE to believe a client. A live dial on a security bound is a live dial on an exploit | it stays a reviewed commit, deliberately |

The live route copies `tools/pose.py` exactly: an override attribute in Edit or Play, `show` / `set` /
`compare`, `save` writing the data file through the tool's own serializer, and the harness REFUSING to
run while an override is set (CLAUDE.md "Content lane"; standing rule J for the selftest). "Implement
in game" is then literally one commit of that file, because the hunt reads the same file through the
same boundary.

## 6. WHAT THIS NOTE COULD NOT ESTABLISH (rule 8)

- **The real ranges' target speeds** are from range-operator figures, not one authoritative table
  (source B). Mitigated: decision 1 takes the speed from our own animal instead.
- **Sources D and E are read as documentation, not measured.** Neither publishes a format; what is
  borrowed is the idea (an anatomical readout; a signed lead).
- **`FLIGHT_CATCHUP_PING_FACTOR` still cannot be calibrated on this PC.** A loopback reads 1.7 ms. The
  range makes the dial reachable and the error visible; it does not supply the real server. Closing
  item H needs a published session on two machines, which is Karen's call and not a build step.
- **Nothing here is measured in the running game.** Phase A is design only; every number above is
  either read off a cited config row or arithmetic from those rows, shown. Phase B's `## PLAN` owes a
  MEASURED NOW for each one.

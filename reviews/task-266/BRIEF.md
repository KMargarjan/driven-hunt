# BRIEF for the Architect: A SHOT HITS WHAT THE SHOOTER SAW. The client claims the hit; the server validates it by rewinding.

Task 266. Written by the Builder, carrying the Director (2026-10-25). **This brief overrides anything
older in `docs/`, `TASKS.md` or an earlier design** (`docs/ARCHITECT_PROMPT.md`), and it overrides
`docs/design/ballistics.md` §1.2's "No lag compensation / rewinding hitboxes" rule and §9.B's refusal
of "per-target position history, a trusted client timestamp and a rewind window" **by name**.

**It is the input to TWO design runs, not one**, and they must be run and committed separately:

```
powershell -ExecutionPolicy Bypass -File tools/architect.ps1 design ballistics --task 266
powershell -ExecutionPolicy Bypass -File tools/architect.ps1 design shotgun    --task 266
```

`tools/agents.py`'s `cmd_architect` writes exactly ONE `docs/design/<system>.md` per invocation and
both runs write the SAME `reviews/task-266/ARCH_RESULT.md`, so the first verdict is committed before
the second run starts or it is silently overwritten (task 256 hit this; Learning Agent L-111).

**If the ballistics design can state the shotgun delta inside itself** — as `ballistics.md` already
does for `shotgun.md` §§3.1, 5.3, 5.5, 11, 13 — **say so in `ARCH_RESULT.md` and the second run is
not made.** The Director prefers one design that owns the flight and names its deltas to two designs
that can disagree.

---

## 1. KAREN, VERBATIM

2026-10-24 and 2026-10-25:

> *"it seems there is a bit off"*
> *"we need to aim in empty space to get hit in head neck or heart like in real life"*
> *"this signe where we shot ... shows we hit empty space and died"*
> *"all shooting has to be like in real life / this is a key of this game"*

Asked which of several fixes to take, she answered: *"the best way"*.

## 2. THE DIRECTOR'S DECISION (2026-10-25). ALREADY TAKEN; NOT OPEN TO THE ARCHITECT

Verbatim from the dispatch:

> **STOP MEASURING THE LAG; MAKE THE SHOT CORRECT BY CONSTRUCTION.**
>
> - **THE CLIENT is authoritative for WHAT IT SAW:** on fire, the client simulates the projectile
>   against ITS OWN view of the world at the real flight time (Ballistics), and sends the hit claim:
>   the target id, the part and its local offset, the view timestamp, the muzzle and direction.
> - **THE SERVER VALIDATES:** the shooter can fire (state, ammo, rate, safety lock), the muzzle is
>   within the existing origin tolerance, and the claimed target was, in the server's recent position
>   HISTORY (keep ~0.5 s per animal), within a tolerance of the claimed hit at the claim's time
>   (rewind), with line of sight from the muzzle. If plausible, it is accepted, with damage by the
>   claimed zone. If not, it is rejected and logged (anti-cheat).
> - The **HIT MARK** is drawn on the client from its own claim, on the animal it saw.
> - The **SAFETY LOCK** and the **PENALTY** use one line (fix 259b's parallel offset in passing).

**The question the Architect is asked is HOW the design should now read, not WHETHER a rewind is
allowed.** It is allowed, for this task, by the Director, against the two passages quoted above.

### 2.1 Why this does NOT delete the lead Karen asked for — the reason the old rule existed

`ballistics.md` §9.B refused the rewind because *"lag-compensated hitscan removes lead"*. That is
true of **hitscan**. It is not true here, and the difference must be written into the design:

- The projectile still **takes its real flight time** (`Ballistics.timeToRange`, unchanged).
- The simulation is now run on the **client against the animal the player can see**, stepping that
  animal forward over the flight the same way the server stepped it. **Aiming at a running animal
  still misses; aiming ahead by `v * t` still hits.** The lead is preserved *exactly*, because the
  lead is the flight time and the flight time has not changed.
- What is removed is only the **view error** — the difference between where the player's screen draws
  the animal and where the server holds it. That is not lead. It is a disagreement about the present
  moment, and it is the thing Karen calls *"a bit off"*.

Source-engine lag compensation rewinds so that **hitscan** hits what was drawn. We rewind so that a
**projectile fired at what was drawn** can be checked for plausibility. The design must say this in
its own words, because the two look identical in a one-line summary and are opposite in effect.

## 3. WHAT IS MEASURED, AND WHAT IS NOT (the Architect must not re-assert either way)

From task 265 (three rounds, all findings; `ESCALATE.md` 2026-10-25 and
`<runs-dir>/ledgers/265.md`):

1. **The ballistics themselves are true.** Task 256 §§3-4 and task 265 round 2: the perpendicular
   deviation of a shot from the sight line on a still target is **0.008-0.028 studs (under 1 cm)**.
   Nothing in this task touches the drag, the drop, the zero or the pattern.
2. **A chest-aimed shot on a moving hind landed in the rump, trunk z +2.915 against a chest spanning
   -1.625..-0.086 — about 3 studs behind.** UNEXPLAINED. Not the animal's travel (0.052 s of flight
   needs 58 studs/s; a hind's ceiling is 28.3), not distance along the ray, and not excluded as an
   instrument mispairing.
3. **A ~0.17 s client/server position offset was measured and is NOT ESTABLISHED.** Five animals,
   0 of 1049 samples the other way, one time shift collapsing a 4.0-stud gap to 0.098 studs — but
   the only control was a motionless part, which reads 0.000 under any clock skew, so a skew between
   the two VMs' `GetServerTimeNow()` is not excluded. **The design must not depend on that number's
   size or sign.** This is the whole reason the Director stopped measuring it: the construction
   below is correct whatever the offset turns out to be, because the client's own view is the
   authority for what was aimed at.
4. **259b is live and real:** `askLineUnsafe(player, origin, aim, stopAt)` tests the line from
   `origin` (on the sight line, `BORE_ON_SIGHT_LINE` ships `true`), while
   `safetySignal:Fire(player, aim, muzzle, stopAt)` publishes the line from `muzzle`. Same `aim`
   unit vector, different start point, so the two rays are **PARALLEL** and
   `Match.Penalty.judge`'s perpendicular distance differs by up to **0.73 studs at every range** —
   a range-independent flip band around `SAFETY_MISS_STUDS = 12`.
5. **`BORE_ON_SIGHT_LINE` ships `true`** (`src/shared/Shotgun/init.luau`, since task 260).

## 4. THE SHAPE THE DIRECTOR HAS IN MIND — and the primitives, each CHECKED to exist (L-108)

The Architect may change any of this; it is offered so that nothing in the design is a requirement
nobody has confirmed is buildable. Every line below was read out of the tree today.

| Primitive the design will need | Does it exist | Where |
|---|---|---|
| A shared, pure flight simulator the client can run | **YES** | `ReplicatedStorage.Ballistics` (`advance`, `timeToRange`, `launchDirection`, `boreOrigin`, `convergeAim`) — already `src/shared/` |
| The weapon's ballistic row on the client | **YES** | `ReplicatedStorage.Weapons`, `Rifle`, `Shotgun`, `Lever`, `SemiAuto` are all `src/shared/` |
| A client raycast against its own view | **YES** | nothing stops a `LocalScript` casting; `src/client/Weapon/Effects.luau` and `src/client/Camera` already cast |
| An Instance crossing a RemoteEvent | **YES** | Roblox replicates Instance references on remotes; the server re-derives the animal from the part, so **no new id table is needed** (`docs/design/map-generator.md` §12.2's rule against a second id table) |
| A server-side per-animal position history | **NO — must be built.** It is buildable: `Boar.Runtime:step(dt)` already runs every Heartbeat (`RunService.Heartbeat:Connect` in `Runtime:connect`, `src/server/Boar/init.luau`) and already walks every live animal, so a ring buffer per animal is a few fields on a record it already owns | new |
| A seam for the Weapon to ASK the Boar where an animal was | **YES, the idiom is already there** | `Weapon.setTargetProvider`, `setStandProvider`, `setSafetyLineProvider`, `setDriveOpenProvider` — the Boar/Match already install providers and the Weapon only ever asks |
| A line-of-sight raycast from the muzzle | **YES** | `Weapon.Cast` is the one caller of `Workspace:Raycast` under `src/server/Weapon/` and `Weapon.setCast` is the injected seam the specs already drive |
| A shared clock for the view timestamp | **PARTLY.** `workspace:GetServerTimeNow()` exists on both sides; whether it is tight is **unestablished** (item 3.3). The design must therefore use it only **inside a tolerance and a window**, never as a precision input | — |

### 4.1 The owner question, which is the Architect's to settle (rule 3)

**The Director's view, for the Architect to accept or replace with a better one:**

- **`Boar` stays the ONE owner of where an animal is and was.** The history buffer lives on the
  animal's own record in `Boar.Runtime`, sampled in the step it already runs, and is exposed
  **read-only** through a provider the Boar installs into the Weapon
  (`Weapon.setHistoryProvider(fn)` or similar). A `Rewind.luau` under `src/server/Weapon/` that
  sampled Workspace itself would be a **second reader of the animal's position** and is the exact
  failure `docs/PROJECT_CONTEXT.md` is named after.
- **`Weapon` stays the ONE owner of whether a shot happened and what it hit.** The client's claim is
  an *input to* `onFireRequest`, never a second path into `Hits.group`. There must still be exactly
  one constructor of a `HitReport`.
- **The client's simulation is NOT a second answer to "where did the bullet go"** only if it runs the
  same `Ballistics` functions. The design must forbid a client-side copy of the arithmetic.

### 4.2 What the server must check before it accepts a claim, in the Director's order

Everything the trigger already gates, unchanged and first (rate limit, `Validator.checkShot`,
`StateMachine.apply`, muzzle present, `Rules.refuse` including the safety lock, `Ballistics.shotFor`),
**then** the claim:

1. the claim's **view time** is not in the future and not older than the history window;
2. the claimed **part** is a `Damageable`/`HitZone` part of a live animal the server knows;
3. the claimed **hit point**, rebuilt from the part's rewound CFrame and the claim's local offset, is
   within a tolerance of where the server's history says that part was at the view time;
4. the **muzzle-to-hit line** is clear in the server's own world (line of sight), from the same
   `origin` the shot is fired from;
5. the **flight time** the claim implies is consistent with `Ballistics.timeToRange` for that
   (weapon, ammo) at that range, within a tolerance.

Accepted → damage by the **claimed zone**. Rejected → **logged and counted** (`Weapon.stats`), and
the shot still happens; **the design must say exactly what a rejected claim's shot does** (flies as
an ordinary server-side flight, or is a plain miss) **and why**.

### 4.3 What a rejected claim must NOT do

It must not silently become a hit somewhere else, and it must not let a client turn a miss into a
kill at a different animal. The design must state the **worst thing a modified client can do** with
this payload, in one paragraph, with the bound that stops it — the way `shotgun.md` §11 stated the
lag before it happened.

## 5. WHAT THE DESIGN MUST CONTAIN (the Architect's checklist for this run)

1. **The decision in §2, restated as the design's own rule**, replacing `ballistics.md` §1.2's "No
   lag compensation" and §9.B's refusal, with the §2.1 distinction (projectile claim + validation,
   not hitscan rewind) written out so no later reader re-applies the old rule.
2. **The owners**, named, one writer each (§4.1), and what each may NOT touch.
3. **The claim payload**, field by field, with its type, and what the server does when each field is
   absent, wrong-typed, or hostile. `Validator` is pure and must stay the one place a payload is
   judged.
4. **The numbers**, with units and where each lives: the history window (~0.5 s), the sample rate,
   the position tolerance, the flight-time tolerance, the view-time window. The SYSTEM's numbers go
   in `Shotgun.CONFIG` (that is where the origin tolerance, the rate limits and the arc already
   live); a GUN's numbers go in its own row.
5. **Where the hit mark is drawn now** — the client's own claim, on the animal it saw — and what
   `ShotLanded` still carries, since task 256's dust rides a `parts` array that exists for exactly
   this reason.
6. **259b, fixed in passing:** one line for the safety lock and the penalty. Name the line.
7. **What happens to `Flight`** — does the server still step projectiles for the claimed shot, for
   an unclaimed shot, for a pellet pattern? **Buckshot is nine pellets and one claim is one point:**
   say what a shotgun claim is. This is the single most likely place the design can be incoherent.
8. **How it is tested with no world** (the injected cast and injected `dt` the specs already use),
   and which existing specs change.
9. **Rule 1's sources:** 3+ external, named, linked, with licence and maintenance status. Valve's
   lag compensation and the published descriptions of client-authoritative hit claims with server
   validation are the obvious ones; `ballistics.md` §9.B already cites Valve and must now cite it
   for the opposite conclusion, with the reason.
10. **What you could not verify** (rule 8), explicitly including anything about the shared clock.

## 6. WHAT MUST NOT CHANGE

- The drag, the drop, the zero, `GRAVITY_SCALE`, the pattern, the flight time. Task 265 measured
  them true to under a centimetre.
- `Hits.group` as the one constructor of a `HitReport`; one report per (shot, target).
- Everything at the trigger stays at the trigger (`ballistics.md` §1.1 item 6).
- `Weapon.Cast` as the only caller of `Workspace:Raycast` under `src/server/Weapon/`.
- No `.rbxm`. No second id table. No vendored FastCast.

## 7. THE ACCEPTANCE THIS DESIGN WILL BE JUDGED BY (the Director's, on Karen's path)

The design must be buildable such that each of these can be shown, and must say which of its
numbers each one reads:

1. a **STILL** animal, 3 chest shots: chest hits, mark on the chest;
2. a **RUNNING** animal: aim AT the chest → **miss behind**, by about `velocity x flight time`; aim
   AHEAD by that lead → **chest hit**, mark on the chest. 3 each;
3. a **FORGED** claim (a probe sends a hit on an animal 30 studs from where it was) → **REJECTED**;
4. each of the above must be shown **failing on the pre-266 code** as well as passing after
   (Learning Agent L-028).

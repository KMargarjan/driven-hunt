# Real-life shooting: the lead, the drop, the scope, and the mark where the bullet landed

Task 256. Karen, 2026-10-24, verbatim:

> "we need to work on rifle acuracy when aiming with scope, it seems there is a bit off / it has to
> be like in real life we need to aim ahead to hit animal when running"
> "all shooting has to be like in real life / this is a key of this game have real life shooting
> feeling"
> "when boar is running we need to aim in empty space to get hit in head neck or heart like in real
> life smae with other animals / drop not needed more need leed hit / and this signe where we shot
> where we hit sometimes shows we hit empty space and died needs corection"
> "also slug and shells has to have different sound and different recoil"

And on how to work: *"do real iteration understand and fix it"*.

## 0. WHAT THIS NOTE FOUND BEFORE IT PROPOSED ANYTHING

The headline is that **four of the six things the dispatch asks for are already built and shipped**,
and this note's job turned out to be to MEASURE them rather than to design them. The two that are
genuinely missing are named in section 1, and they are the two that explain Karen's two complaints.

| # | What the dispatch asks | What the repo already does | Verdict |
|---|---|---|---|
| 1 | time of flight, the shot is not instant | `Weapon.Flight` + `ReplicatedStorage.Ballistics`, task 185 | **BUILT.** Measured in section 3 |
| 1b | lag compensation for the shooter | **nothing. `latency`, `ping`, `GetNetworkPing` appear nowhere in `src/`** | **MISSING -> section 5** |
| 2 | no bullet drop | `GRAVITY_SCALE` per weapon per load, tasks 189/224 | **BUILT.** Measured in section 4: the worst case in the band anyone shoots in is **1.6 cm** |
| 3 | the scope is true | muzzle convergence onto the aim point, task 183 | **BUILT.** Measured in section 6: the ballistic part of it is **1.5 cm** and cannot be what she feels |
| 4 | real kill zones | `Boar.CONFIG.ZONES` + `Wound`, tasks 116/118/119/219/240 | **BUILT.** Audited against the literature in section 7 |
| 5 | the hit mark is true | `Effects.playLanded`, tasks 185/249 | **WRONG, and section 8 says why in one sentence: the puff is `Anchored` in the world and the animal runs out from under it** |
| 6 | slug and buckshot differ | `fire.loads` per load, chosen by the chambered round, task 204 | **BUILT.** Measured against the real cartridges in section 9 |

So this task is **not** "build real ballistics". It is: remove the ping from the lead, put the mark
on the animal, and prove the other four with numbers.

## 1. THE TWO REAL DEFECTS

**(a) The lead a player must take is the true lead PLUS the round trip to the server.** The shot is
launched on the server at the moment the request arrives, and resolved against positions that are
live at that moment. The player aimed at an animal he saw one trip earlier. Section 5 derives the
error as `round-trip x speed` and section 5.3 measures it: at 60 ms one way and a boar at
`SPRINT_SPEED`, the player must over-lead by **64 cm** on top of a true lead of 91 cm at 60 m. The
ping is not a correction to the lead, it is **70 % of it again**.

**(b) The impact puff is a world-anchored part and the animal is moving.** `Effects.puff` sets
`host.Anchored = true` and parents it to `Workspace.WeaponEffects`. The grains live 0.22-0.38 s
(`IMPACT.LIFETIME`) and the host 0.75 s (`HOST_LIFETIME`). A boar at `SPRINT_SPEED` 38 studs/s
covers **11.4 studs in 0.3 s** -- its own body is 5.5 studs long (`BODY_SIZE`) -- so by the time the
dust has faded the animal is **two body lengths past the mark**, and the mark is hanging in the air
where the animal *was*. That is Karen's sentence exactly: *"sometimes shows we hit empty space and
died"*. It is "sometimes" because it only happens on a RUNNING animal, and it says "died" because
the hit was real -- the server hit the animal, the client drew the dust where the animal no longer
is.

Neither is a ballistics bug. The ballistics are right; the first is a missing clock correction and
the second is a missing parent.

## 2. SOURCES

**A. Roblox, *Network ownership* and *Player:GetNetworkPing*** (official docs, maintained).
  - https://create.roblox.com/docs/physics/network-ownership
  - https://create.roblox.com/docs/reference/engine/classes/Player#GetNetworkPing

  `Player:GetNetworkPing()` is the engine's own measurement and the only latency number a server can
  read without a protocol of our own. **Does well:** free, no wire format, no clock to synchronise,
  and unspoofable by the client (the client never sends it). **Does badly:** the docs say only
  *"the network ping in seconds"* and do not state whether it is the round trip or one way, and it
  is a smoothed average, so a single shot's own trip is not knowable from it. That ambiguity is why
  section 5.4 makes the conversion a DATA ROW instead of a constant in code.

**B. Valve, *Source Multiplayer Networking* -- lag compensation** (the canonical description of the
problem; public developer wiki, maintained).
  - https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking

  *"the server moves the player hitboxes back in time to where they were when the player fired"*,
  with the correction derived as the command's own latency plus the client's interpolation delay.
  **Does well:** it is the right analysis, and it names the term everybody else forgets --
  interpolation, not just ping. **Does badly for us:** it rewinds a history buffer of every hitbox,
  which is a second position store for every animal in the drive and a second answer to "where is
  this boar", exactly the overlapping-owner failure `docs/PROJECT_CONTEXT.md` is a document about.
  **Adopted as the ANALYSIS and refused as the MECHANISM** -- see section 5.2.

**C. Unreal Engine, *Networking Overview* / forward-predicted projectiles** (Epic, maintained).
  - https://dev.epicgames.com/documentation/en-us/unreal-engine/networking-overview-for-unreal-engine

  The forward-prediction half of the same idea: rather than rewinding the world, a projectile is
  **advanced by the owner's latency at spawn** so it arrives where the firing client predicted.
  **Does well:** it needs no history, no second position store and no new clock -- the correction is
  one number multiplied into a simulation the system already runs. **Does badly:** against a
  crossing target the catch-up stretch is resolved against one world state rather than a rewound
  one, so it is an approximation, and an unbounded one would let a high-ping client reach forward
  arbitrarily far. **ADOPTED, bounded** -- section 5.2. This is the mechanism `Weapon.Flight`
  already has the shape for: it steps a projectile over an injected `dt`, so "catch up by L" is the
  step it already takes, taken once more.

**D. Stokke, Arnemo, Brainerd, Soderberg, Kraabol, Ytrehus (2018), *Defining animal welfare
standards in hunting: body mass determines thresholds for incapacitation time and flight distance*,
Scientific Reports 8, CC BY 4.0** (peer-reviewed, open access).
  - https://doi.org/10.1038/s41598-018-32102-0

  Already the source behind `Wound.FLIGHT` (see `src/server/Boar/Wound.luau`'s header). Re-read here
  for section 7, for the thing this task needs that the existing note did not take from it: the
  split between a thoracic hit and an abdominal one. **Does well:** real figures from thousands of
  hunted animals, with flight distance as a function of body mass and hit placement. **Does badly:**
  it is about welfare thresholds, not about where the heart is, and gives no zone geometry.

**E. Deutscher Jagdverband, the German *Jagdschein* material on the *Kammerschuss* and the
*Drueckjagd*** -- the national hunting association's own current education material.
  - https://www.jagdverband.de/

  The vital triangle: the *Kammer* (heart/lung, behind the shoulder, the shot every hunting
  education in the German-speaking world teaches), the *Blatt* (the shoulder itself), the neck and
  the brain as instant stops, and the *Waidwundschuss* (paunch) as the shot that must never be
  taken -- the animal runs on for a long way. **Does well:** it is the actual doctrine for the
  actual kind of hunt this game is, and it states the ORDER of preference and the sizes of the
  zones relative to the animal. **Does badly:** no numbers in studs, and no energy model.

**F. Published ballistic tables for the four cartridges** (manufacturer data, cross-checked):
  Remington *Slugger* 1 oz rifled slug, Brenneke *Classic Magnum*, Federal 00 buckshot 9-pellet,
  Hornady/Norma .416 Rigby 400 gr, Remington .45-70 405 gr. These are the numbers already fitted
  into `MUZZLE_STUDS_PER_S` and `DRAG_PER_STUD` by tasks 185/189/224; section 3 re-derives the
  flight times from them and section 9 derives the recoil. **Does well:** they are the real world.
  **Does badly:** every one is quoted from a 24-26 inch test barrel and a stated gun weight, so the
  recoil figures move with the gun, which is why section 9 states the gun weight it used.

**Borrowed, not invented (rule 2):** the analysis is B, the mechanism is C, the latency number is A,
the zones are D+E, the cartridges are F. What is invented is one bound
(`FLIGHT_CATCHUP_MAX_SECONDS`) and one parenting decision (section 8), and both say so where they
are written.

## 3. TIME OF FLIGHT AND THE TRUE LEAD (item 1, the half that is built)

Computed from the shipped rows, through `Ballistics.timeToRange`'s own closed form
`t = (exp(k*s) - 1) / (k*v0)`, at `METRES_PER_STUD = 0.28`. A boar at `SPRINT_SPEED` 38 studs/s is
10.6 m/s; a red deer bolting is taken at 15 m/s (section 7).

| Weapon (load) | 20 m | 40 m | 60 m | 80 m |
|---|---|---|---|---|
| shotgun **Buck** (1442 st/s) | 54.5 ms | *past its 28 m range* | -- | -- |
| shotgun **Slug** (1752 st/s) | 42.4 ms | 88.0 ms | 137.3 ms | 190.4 ms |
| lever **.45-70** (2232 st/s) | 32.6 ms | 66.4 ms | 101.6 ms | 138.0 ms |
| rifle **.416** (2612 st/s) | 27.8 ms | 56.4 ms | 85.9 ms | 116.4 ms |

The lead that buys, on a crossing animal:

| Weapon | 20 m | 40 m | 60 m | 80 m |
|---|---|---|---|---|
| slug, boar 10.6 m/s | 45 cm | 94 cm | 146 cm | 203 cm |
| rifle, boar 10.6 m/s | 30 cm | 60 cm | 91 cm | 124 cm |
| rifle, deer 15 m/s | 42 cm | 85 cm | 129 cm | 175 cm |

**A boar is 5.5 studs = 1.54 m long.** So at 60 m with the rifle the true lead is **most of a body
length** and at 80 m with the slug it is **more than a body length** -- Karen's *"aim in empty
space"* is exactly the right description of it, and the game already demands it. **This half needs
no code.**

**The buckshot line is the one to carry forward** (the Learning Agent's route note, from
`b240-result.json`): buckshot's `RANGE_STUDS` is 100 studs = **28 m**. Every lead figure for
buckshot beyond 28 m is unreachable -- the pellets retire before they arrive. So the dispatch's
"20-80 m" band is a SLUG and RIFLE band, and buckshot is a 0-28 m proposition with one lead number
worth knowing: **58 cm at 20 m on a boar**.

## 4. BULLET DROP: KAREN SAYS "NOT NEEDED", AND IT ALREADY IS NOT (item 2)

`Ballistics.sightOffsetAt` is how far above (+) or below (-) the sight line the projectile is. It is
exactly 0 at the zero. Computed over every shipped row, with each weapon's own `GRAVITY_SCALE`:

| Weapon (gravityScale, zero) | 10 m | 20 m | 30 m | 40 m | 60 m | 80 m | 100 m | worst over its whole range |
|---|---|---|---|---|---|---|---|---|
| shotgun **Buck** (1.0, 70 st) | +0.3 cm | -0.0 cm | *past range* | -- | -- | -- | -- | **1.0 cm** (at 28 m) |
| shotgun **Slug** (1.0, 180 st) | +1.0 | +1.5 | +1.5 | +1.1 | -1.6 | -6.8 | *past range* | 11.4 cm (at 92 m, its last stud) |
| lever **.45-70** (0.35, 357 st) | +0.5 | +0.8 | +1.1 | +1.3 | +1.3 | +0.9 | -0.0 | 7.1 cm (at 168 m) |
| rifle **.416** (0.12, 714 st) | +0.3 | +0.5 | +0.7 | +0.9 | +1.2 | +1.4 | +1.5 | **1.5 cm** (at 105 m) |

**THE ANSWER TO ITEM 2 IS "FLAT ENOUGH, MEASURED, AND NO CODE CHANGES".** Inside 60 m -- which is
where this game's drives happen -- **every weapon and every load is within 1.6 cm of the reticle**.
A boar's chest zone is 1.6 studs = 45 cm tall. 1.6 cm is **3.5 % of the smallest thing anyone aims
at**, and no player can feel it.

Two honest caveats, both stated rather than fixed:
- **the shotgun slug past 60 m** falls away to -6.8 cm at 80 m and -11.4 cm at its 92 m limit. Real,
  and the one place in the game where drop exists at all. It is left alone deliberately: it is a
  rifled-slug shotgun at 80 m, the shot is already a bad idea, and `GRAVITY_SCALE.Slug` is one line
  if Karen ever disagrees.
- **the lever at 168 m** reaches 7.1 cm, again at the far end of a range nobody shoots.

So Karen's *"drop not needed"* is already true as a matter of measurement, and the reason is
`GRAVITY_SCALE` -- a dial tasks 189 and 224 already turned. **Nothing in item 2 is a defect.**

## 5. LAG COMPENSATION (item 1, the half that is missing)

### 5.1 The derivation

Let `L` be the one-way trip. The client draws the animal at `P(t - L)` (what the last snapshot
said). The player leads by the flight time and clicks at `P(t - L) + tof*v`. The request reaches the
server at `t`. The server launches, and the bullet arrives at the aim point at `t + tof`, when the
animal is at `P(t + tof)`.

The aim point was `P(t - L) + tof*v ~ P(t - L + tof)`. The animal is at `P(t + tof)`. The miss is

    P(t + tof) - P(t - L + tof)  =  L*v    ... behind the animal, once for each of the two trips

and the player feels **`2L*v`** -- the full round trip -- because his own click took `L` to arrive
and the picture he aimed at was already `L` old. So the shot lands **behind** a crossing animal and
the player learns to over-lead. Karen's *"it seems there is a bit off"*.

### 5.2 The mechanism: forward-predict, do not rewind

Source B's rewind is the textbook answer and is **refused**: it needs a per-animal position history,
which is a second store of a fact `Boar.Body` owns, and `docs/PROJECT_CONTEXT.md` names "two systems
wrote the creature's position" as one of the things that killed the previous project.

Source C's forward prediction is **adopted**, because `Weapon.Flight` is already exactly the right
shape for it: `Flight.advance(dt, cast)` steps every live projectile by an INJECTED `dt` over an
INJECTED cast, sub-stepped at `FLIGHT_STEP_MAX_SECONDS` with a segment raycast per sub-step. So
"catch the shot up by `L`" is not a new mechanism at all -- it is **the step this module already
takes, taken once more at launch**, through the same cast, under the same sub-step cap, so it cannot
tunnel through a wall and cannot skip a target.

### 5.3 What it is worth

| one-way L | boar 10.6 m/s | deer 15 m/s | against the rifle's true lead at 60 m (91 cm) |
|---|---|---|---|
| 30 ms | 32 cm | 45 cm | +35 % |
| 60 ms | 64 cm | 90 cm | **+70 %** |
| 100 ms | 106 cm | 150 cm | +116 % |

At 60 ms the correction is **most of a boar's body length again**. This is the single biggest error
in the shooting model and it is the one Karen is feeling.

### 5.4 The two numbers, and why each is a data row and not a constant

- **`FLIGHT_CATCHUP_MAX_SECONDS`** -- the bound. Unbounded forward prediction lets a 400 ms client
  reach a third of a second into the future, which is an animal's whole body length of free lead and
  a thing other players would see as a shot that hit nothing. Source C's own objection. **0.15 s**
  is proposed: it covers a 150 ms one-way trip, which is a bad connection, and caps the reach at
  5.7 studs on a sprinting boar -- about one body length, the most a mistake here may ever be worth.
- **`FLIGHT_CATCHUP_PING_FACTOR`** -- the conversion from `GetNetworkPing()` to the correction.
  Source A does not state whether the engine's number is the round trip or one way, and
  **section 5.1 shows the correction wanted is the ROUND TRIP `2L`**. So the factor is exactly the
  thing that is uncertain, and it is a row rather than a literal for the reason this repo already
  applies to `GRAVITY_SCALE`: *a constant that can only be read at one value cannot be tested at
  another*, and this one has to be confirmed against a real server, which Studio cannot provide (a
  local Play session's ping is ~0). Shipped at **1.0** -- treating the engine's number as the round
  trip, which is the conservative reading, since over-correcting hands out free lead while
  under-correcting only leaves some of today's error in place.

### 5.5 THE LIMIT, FOUND BY MEASUREMENT AND NOT BY REASONING

**Forward prediction can only give back time the bullet actually spends in the air.** This was not
anticipated when section 5.2 was written -- the first version of the spec asserted a hit at every
range and FAILED at the shortest one, which is how it was found.

If the round trip exceeds the flight time, the bullet reaches the animal's distance before the world
has caught up with the picture the player aimed at, and there is no flight left to spend. Simulated
against the real stepper, rifle, boar at `SPRINT_SPEED`, 100 ms round trip:

| range | flight time | ping error | miss, uncompensated | miss, compensated |
|---|---|---|---|---|
| 179 studs (50 m) | **71 ms** *(< 100 ms)* | 3.80 studs | 4.26 studs | **1.73 studs -- still a miss** |
| 357 studs (100 m) | 148 ms | 3.80 | 3.89 | **0.10 -- a hit** |
| 536 studs (150 m) | 231 ms | 3.80 | 3.90 | **0.11 -- a hit** |
| 714 studs (200 m) | 320 ms | 3.80 | 4.31 | **0.51 -- a hit** |

So the correction is **exact beyond 100 m and partial inside it**, and at 50 m it still cuts the
miss by 59 %. Two things follow, and both are stated rather than fixed:

- **It is the right way round.** The shortfall is largest where the lead is smallest, so what is
  left over is a fraction of a small number: 1.73 studs is 48 cm, which at 50 m on a boar whose
  chest zone is 45 cm tall is about one zone -- noticeable, and far better than the 4.26 studs
  (1.19 m) it replaces.
- **Nothing can be done about it inside this mechanism.** Giving back more time than the bullet
  flies would mean resolving the shot against a REWOUND world, which is source B -- refused in 5.2
  for a reason that has not changed. If Karen ever reports that close shots on fast animals still
  feel behind, that is the trade to reopen, and this table is its starting point.

`weapon_hits.spec`'s "CANNOT GIVE BACK MORE PING THAN THE BULLET SPENDS IN THE AIR" case is this
row of the table, asserted, so the degradation is a number in the harness rather than a sentence
here.

**What cannot be measured here, said plainly (rule 8):** a Studio Play session has no network, so
the live magnitude of this correction is **not measurable on this PC**. What IS measurable and is
proved by spec: the catch-up advances the projectile by exactly the time asked for, it is clamped at
the cap, it casts the same segments the normal step casts, 0 reproduces today's behaviour bit for
bit, a projectile cannot be leaked or tunnelled by it, and the 5.5 limit above holds where it is
predicted to.

## 6. THE SCOPE (item 3): WHAT THE "BIT OFF" IS NOT

`Weapon.onFireRequest` does muzzle convergence: cast from the camera along the camera's look to find
`aimPoint`, then aim the bore from the MUZZLE at that point (`aim = (aimPoint - muzzle).Unit`), then
elevate once for the zero (`Ballistics.launchDirection`). Three candidate causes were measured or
read out:

1. **The ballistic arc.** Measured in section 4: **+1.5 cm at 100 m**, the rifle's worst anywhere.
   **Not it.**
2. **The sway.** `Mode.step` applies `scopeSwayDeg` to the CAMERA (`Mode.cameraCFrame` adds it into
   `viewPitch` and `yawDeg`), and `Input.fire` sends `camera.CFrame.LookVector`. So the ray wanders
   with the picture and the reticle still marks where the bullet goes. **Consistent; not it.**
3. **Convergence when the ray hits NOTHING.** `aimPoint` falls back to `origin + direction * range`
   -- 800 studs for the rifle -- so the bore converges at 800 studs instead of on the target, and
   the eye-to-muzzle offset is divided down by `(1 - d/range)` instead of cancelling. At a target
   the ray DOES hit, this cannot happen. **A real hole, but not reachable when aiming at an animal.**

**So the scope's ballistics are not what Karen is feeling, and the honest conclusion of this section
is that item 3 needs a MEASUREMENT IN THE PLACE, not a code change guessed from here** -- the
dispatch's own instruction ("Measure the offset today ... at 25, 50 and 100 m"). It is carried to
part 2 with sections 4 and 6 as the two things already ruled out, so part 2 starts from the
eye-relief / parallax / reticle-geometry end rather than from the arithmetic.

## 7. THE KILL ZONES (item 4), AUDITED

Doctrine, from E, in the order a hunting education teaches it:
- **brain / neck (spine)** -- instant. Small targets, and on a moving animal an unethical aim.
- **Kammer (heart + lungs), behind the shoulder** -- *the* shot. Death in seconds; the animal may
  still run 20-80 m (D's `efd` for an 80 kg animal is ~100 studs, which is what `FLIGHT.body = 120`
  already encodes).
- **Blatt (shoulder)** -- stops the animal but wastes meat and may not be lethal alone.
- **Waidwund (paunch/abdomen)** -- wounds; the animal runs a long way. D's `mfd` at 80 kg is
  ~429 studs, against `FLIGHT.legs = 420`.
- **legs** -- cripples, never kills.

The repo's zones are `head`, `chest`, `rear`, `legs` with `CLASS` marking `head` and `chest` as
`vital` (`Wound.hitClass`), `FLIGHT` giving `body` 120 and `legs` 420 studs, and the deer's four
boxes *"MEASURED on the same probe and cross-checked against the LOADED model ... the two agree to
0.02 studs on every bone"*.

**The audit's finding is that the SHAPE is right and matches the doctrine** -- two vital zones that
kill, a rear/body zone that wounds and runs, a leg zone that cripples, with flight distances taken
from D and already within 7 % of its own formula. **What this note does NOT do is re-tune them**:
item 4 is explicitly part 2 of the split, the numbers are per-animal per-load tables that the
Learning Agent's L-030/L-093 note requires be swept together (`DAMAGE`, `DAMAGE_BY_WEAPON`,
`toughness`, `CLASS`, `FLIGHT`, and the HUD labels that read them), and doing that in the same
session as sections 5 and 8 would be the bundling L-012 warns about. **Carried to part 2, with the
doctrine above as its bar.**

One thing IS worth recording now, because part 2 will need it: **the doctrine's zone is the
*Kammer*, which is behind the shoulder and NOT the whole chest**, and the repo's `chest` box is the
whole front half. Whether that matters is a question about what Karen feels when she hits a
shoulder, and it is hers.

## 8. THE MARK WHERE THE BULLET LANDED (item 5)

### 8.1 The cause, measured

`Effects.puff` builds its host part with `host.Anchored = true` and parents it to
`Workspace.WeaponEffects`. The animal is an unanchored physics assembly driven by constraints
(`Boar.Body`). So the dust is pinned to the WORLD at the point the server's ray struck, and the
animal keeps going:

| boar speed | in one grain lifetime (0.3 s) | in the host's life (0.75 s) | body lengths (5.5 studs) |
|---|---|---|---|
| `WALK_SPEED` 4.5 st/s | 1.4 studs | 3.4 studs | 0.6 |
| `RUN_SPEED` 24 st/s | 7.2 studs | 18.0 studs | **3.3** |
| `SPRINT_SPEED` 38 st/s | 11.4 studs | 28.5 studs | **5.2** |

So on a sprinting animal the mark is **two body lengths behind it before the dust has even faded**,
and the client's own view of the animal is additionally one trip old on top of that. *"sometimes
shows we hit empty space and died"* -- "sometimes" is "whenever the animal was running", and the
rest of the sentence is the server correctly killing the animal it correctly hit.

### 8.2 The fix, and why it is a parent and not a per-frame write

A moving cosmetic that must stay on a moving body is what Roblox's `Attachment` is for: an
`Attachment` is a point in its parent part's own frame, and a `ParticleEmitter` inside one emits from
wherever that part now is, with **no welds, no constraints, no per-frame CFrame write, and no second
writer of anything** (`Boar.Body` stays the only writer of a boar's Instances -- this adds a child to
a part it owns and destroys it again, which is what `Debris` is for).
  - https://create.roblox.com/docs/reference/engine/classes/Attachment
  - https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter

`Effects.puff` **already** builds exactly this -- an invisible host part, an `Attachment` on it, the
emitter in the attachment. The host part exists only to be a place to put the attachment. So the
change is: **when the pellet struck a part that moves, put the attachment on THAT part at the local
offset instead of on a new anchored host.** Everything else -- the colour rule, the normal rule, the
grain counts, the `Debris` lifetime, the `EFFECT_MAX_PER_SHOT` budget -- is untouched, and a pellet
that struck the ground still gets today's anchored host, because the ground does not move.

**AND THAT IS NOT SUFFICIENT, WHICH ROUND 1 GOT WRONG AND THE REVIEWER CAUGHT.** Moving the
`Attachment` moves only where the NEXT particle would be BORN. `Effects.puff` emits all seven grains
in ONE burst at the instant of the hit (`emitter.Enabled = false`, then `emitter:Emit(COUNT)`), and
**a `ParticleEmitter` simulates its emitted particles in WORLD space unless `LockedToPart` is
true** -- and `LockedToPart` defaults to false.
  - https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter#LockedToPart
    *"whether the particles are locked in place relative to the emitter's parent"*

So round 1 shipped an attachment that rode the boar and dust that hung in the air at exactly the
point the anchored host had used: the measured target in section 10 was **not met**, and the two
spec assertions that were supposed to prove it (`attachment.WorldPosition` after the body moves, and
its `UpVector` after the body turns) are properties of `Attachment` ITSELF -- `WorldCFrame` is
*defined* as `parent.CFrame * attachment.CFrame` -- so they held for any attachment on any part and
could not fail. **That is this repo's own founding failure mode** (`docs/PROJECT_CONTEXT.md`: *"The
agent verified its own work with numbers and never looked. Things measured correct and looked
wrong"*), reproduced exactly, in the task whose whole subject is a thing the player SEES.

**`LockedToPart = true` on the riding path is the line that moves the picture**, and the assertion
that can fail is `emitter.LockedToPart`, asserted `true` on the riding path and `false` on the static
one. Its one side effect is that `Acceleration` is then read in the part's frame rather than the
world's, so the grains fall along the animal's own -Y; `Boar.Body` holds the trunk upright with an
`AlignOrientation`, so for a live animal those are the same direction, and for 0.3 s of dust on a
rolled carcass the difference is not worth a second acceleration number to keep in step.

**What the server has to send for that:** the Instance that was hit. The server already has it
(`Impact.instance`, which `Cast.world` returns today). `ShotLanded` already carries three parallel
arrays and the pattern for adding one (task 249's own note: *"THREE ARRAYS AND NOT ONE ARRAY OF
TABLES ... so an older client draws what it always drew rather than nothing"*). A fourth array of
Instances follows it exactly, and a nil entry is "the world", which is every point sent before this
task.

**The local offset is computed on the CLIENT, not sent**: the client has the part, the part has a
CFrame, and `part.CFrame:PointToObjectSpace(worldPoint)` is the offset. Sending it would be a second
representation of a thing derivable from the two facts already on the wire, and it would be wrong by
exactly the trip time -- the part has moved since the server measured it, and **the client's own copy
of where it is now is the right frame to pin the dust in**, because that is the animal the player
can see.

### 8.3 The honest limit

This puts the mark **on the body that was hit**, which is the zone BOX. The zone boxes protrude by
`ZONES.PROTRUSION = 0.06` studs by construction (task 116: a flush box is a coin toss), and the
drawn mesh is a `CanQuery = false` passenger inside them. So a ray that clips a box CORNER still
marks a point up to the box-to-mesh gap away from the drawn coat. That is a **separate, smaller and
static** error from the one this section fixes, it is bounded by the box geometry rather than by the
animal's speed, and it is named here so that part 2 can measure it rather than discovering it.

## 9. SLUG AND BUCKSHOT (item 6), MEASURED AGAINST THE REAL CARTRIDGES

Free recoil energy, the standard formula
`V = (m_proj*v_proj + m_powder*v_powder_eff) / m_gun`, `E = m_gun*V^2 / 2g`, at a 7.5 lb 12-gauge
and an effective powder gas velocity of 4000 fps:

| Load (source F) | recoil velocity | recoil energy | ratio to buckshot |
|---|---|---|---|
| 00 buck, 9 pellet, 1-1/8 oz (492 gr) @ 1325 fps | 14.9 fps | **25.7 ft-lbf** | 1.00x |
| Foster slug, 1 oz (437.5 gr) @ 1680 fps | 16.9 fps | **33.3 ft-lbf** | **1.29x** |
| Brenneke slug, 1 oz @ 1476 fps | 14.9 fps | 25.8 ft-lbf | 1.00x |
| *(.45-70 405 gr @ 1600, 8 lb, for scale)* | 15.5 fps | 29.9 ft-lbf | 1.16x |
| *(.416 Rigby 400 gr @ 2400, 10 lb, for scale)* | 19.1 fps | 56.9 ft-lbf | 2.21x |

**So a real 1 oz Foster slug kicks 1.29x a 9-pellet 00 buck load**, and the dispatch's premise -- *"a
real 1 oz Foster slug kicks noticeably more than 32 g of buckshot"* -- is confirmed, at 1.29x rather
than at something dramatic. (The Brenneke row is the honest footnote: at its lower velocity it kicks
the same as buckshot. The game's slug is the fast Foster.)

**What the game ships, in `poses.json` `fire.loads` on both shotguns:**

| | pitchScale | volumeScale | recoilScale |
|---|---|---|---|
| Buck | 1.00 | 1.00 | 1.00 |
| Slug | **0.82** | **1.25** | **1.45** |

- **The recoil is already per-load and already harder for the slug**, at 1.45x against a real 1.29x.
  **It is left at 1.45 deliberately:** it is 12 % above the real ratio, Karen asked for the two to
  FEEL different, and a recoil scale is a thing a player feels rather than measures. The real figure
  is recorded here so the dial has a known reference, and 1.29 is one line if she wants it true.
- **The sound is per-load in LEVEL and PITCH but is ONE SAMPLE.** The shotgun's row carries no
  `SOUND` block at all, so `Sound.shot` falls through to `Camera.Config.SOUND_SHOT_ID` -- a single id
  -- and the slug is that id played at 0.82 speed and 1.25 volume. Dropping `PlaybackSpeed` lowers
  the whole spectrum and stretches the report, which is what a heavier charge sounds like, and is
  what task 204 chose on purpose. **But it is not a different RECORDING, and Karen asked for a
  "different sound".** Whether 0.82/1.25 reads as "different" is her ear's call and nobody here can
  answer it; if it does not, the fix is a second uploaded sample and a `SOUND` block, which is an
  upload and therefore the Director's.
- **It is chosen by the CHAMBERED round, and this was verified by reading the path end to end**:
  `onFireRequest` takes `local ammo = state.loaded[state.selected]` -- the round in the chamber about
  to go off, not `state.ammo`, which is the HUD's selection for the NEXT load -- puts it on
  `ShotFired`, and `CameraBoot` hands that one string to both `Camera.kick` and `Weapon.Sound.shot`.
  So a player who presses X between the trigger and the shot cannot get the other load's kick, and
  the ear and the eye cannot disagree. **This is tasks 204 and 244 already correct; item 6 needs no
  code.**

## 10. NUMERIC TARGETS

| What | Target | Where it is checked |
|---|---|---|
| true lead, rifle, boar at 60 m | 91 cm (0.6 body lengths) | section 3, from `Ballistics.timeToRange` |
| sight offset, every weapon, 0-60 m | **<= 1.6 cm** | section 4 -- already met, no change |
| ping contribution to the lead, 60 ms | 64 cm **-> 0** | section 5, the catch-up |
| catch-up bound | <= 0.15 s, <= 5.7 studs on a sprinting boar | `FLIGHT_CATCHUP_MAX_SECONDS` |
| catch-up at L = 0 | **bit-for-bit today's flight** | spec |
| catch-up where flight < round trip | **partial, and said so**: 59 % of the miss at 50 m | section 5.5, spec |
| hit mark separation, sprinting boar, 0.3 s | 11.4 studs **-> 0** | section 8 |
| hit mark on a static surface | unchanged | spec |
| slug/buck recoil ratio | real 1.29x; shipped 1.45x (Karen's dial) | section 9 |
| buckshot spread | real ~1.59 deg full; shipped `SPREAD_FULL_DEG.Buck = 1.6` | section 9 / already met |
| buckshot's reach | 100 studs = **28 m**: no buckshot lead figure beyond it is real | section 3 |

## 11. WHAT THIS NOTE DECIDES

1. **Item 2, item 6 and the arithmetic half of item 3 are MEASURED AS ALREADY CORRECT** and get no
   code. Sections 4, 9, 6.
2. **Item 1 gains lag compensation** by Source C's forward prediction, bounded, through the step
   `Weapon.Flight` already takes. Section 5.
3. **Item 5 is a parent, not a position**: the dust goes on the part that was hit. Section 8.
4. **Items 3 (the live measurement) and 4 (the zone re-tune) are part 2**, with sections 6 and 7
   naming what has already been ruled out so part 2 does not re-derive it.

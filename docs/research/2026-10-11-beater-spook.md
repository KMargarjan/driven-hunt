# The beater's drive: what she walks into, and what happens when she gets there (Task 154)

Karen, 2026-10-11 ~14:00-14:20, after the first playtest where she *was* a beater:

> horn sound: - should be short one like beeep / didn;t see any animals probably need to wait 10s ?

> so we need to improve animal behaviuor and yes map is to short but for now we can keep like that
> for testing / so animals already there somewhere in bushes close to trees ect / once I get a bit
> closer they just run away without stop it's not like they cool down they spooked and run away / so
> from me direction they looking they run away / horn reach is further once they hear also run
> without stop

## 1. What the system must do

In the Forest Test world only, and only while the player is a **beater**:

1. **The wood is already full when she starts.** Several resting sounders between her and the road,
   close to trees, on the ground, spread across her front. No timed waves.
2. **Walking up on them flushes them, and the flush does not wear off.** Inside a reach measured in
   metres, the animal *and its sounder* run away from her, toward the road, and keep running until
   they leave the field.
3. **The horn does the same at a longer reach**, and sounds as one short note rather than a phrase.
4. **A beater carries the horn and no guns.**

What it must **not** do: change the hunter's world, add a second rule for "when does an animal calm
down", or invent a panic system beside the one that exists.

## 2. Sources

| # | Source | What it is | Licence / status |
|---|---|---|---|
| 1 | Wielgus, E. et al. (2024), *Frequent flight responses, but low escape distance of wild boar to nonlethal human disturbance*, **Ecological Solutions and Evidence** 5:e12331, [doi:10.1002/2688-8319.12331](https://besjournals.onlinelibrary.wiley.com/doi/full/10.1002/2688-8319.12331) | GPS-collared wild boar in the Bohemian Forest, approached on foot by a person on purpose, 2024 | British Ecological Society, open access, current |
| 2 | Olejarz, A., Augustsson, E., Kjellander, P., Ježek, M., Podgórski, T. (2024), *Experience shapes wild boar spatial response to drive hunts*, **Scientific Reports** 14, [doi:10.1038/s41598-024-71098-8](https://pmc.ncbi.nlm.nih.gov/articles/PMC11358132/) | GPS-collared wild boar measured through real **drive hunts** (Drückjagden) | CC BY-NC-ND 4.0, open access, current |
| 3 | Deutscher Jagdverband, [*Drückjagd*](https://www.jagdverband.de/rund-um-die-jagd/was-draussen-passiert/bewegungsjagd/drueckjagd) | The German hunting association's own description of how a driven hunt is run | The national body's standing reference page, maintained |
| 4 | Lee, Yu. S. et al. (2025), *Initial Escape Distances of Wild Boars (Sus scrofa ussuricus)…*, **Biology Bulletin**, [link.springer.com](https://link.springer.com/article/10.1134/S1062359025700773) | 98 measured initial escape distances, a second population | Paywalled abstract; used only as a second opinion on one number |

### What each does well and badly

**(1) Wielgus 2024** is the only source that measures the exact thing this task models — *a person
walking at a wild boar* — and it gives two numbers: **flight initiation distance 93 m** and **escape
distance 256 m**, with a flight response in **69 %** of approaches. Badly: it is non-lethal
disturbance by one walker in a forest where the boar are used to people on paths, not a beater line,
and the flight initiation distance was *shorter* in the non-hunting zone — so the number is
population- and context-dependent, not a constant. (4) agrees independently at **84 m** over 98
measurements, which is the main reason to trust (1)'s 93 m as the right order of magnitude rather
than an artefact.

**(2) Olejarz 2024** is the one that settles Karen's *"it's not like they cool down"*. Measured
through actual drive hunts: average flight **1.80 km** (95 % CI 1.40–2.20), maximum **2.2 km**, and
**25.8 hours** before the animal returned to the area it had been using. On a hunt day the daily
distance went from 5.02 km to 7.99 km and the daily range from 0.99 km² to 2.4 km². Badly: it says
nothing about the first few seconds — its resolution is GPS fixes, not gaits — so it cannot tell us
how fast they go, only that they go and do not come back.

**(3) DJV** is the practice, in the body's own words: *"Das Wild wird durch die Treiber vorsichtig,
langsam und durch stilles Durchgehen in Bewegung gebracht"* and *"das so in Bewegung gebrachte Wild
kommt den angestellten Schützen möglichst ruhig in Anblick"*. It is the reason the **approach** in
this game is a walk or a trot and only the **flush** is a run — the drive is supposed to be calm, and
a hunting association is an authority on that. Badly: it is prose for hunters, with no distances in
it at all.

## 3. The pattern adopted, and why

**Borrowed, not invented (rule 2): the one-way flight latch already in this repo.** Task 150 built
`Brain:spook(from, seconds, untilExit)` + `SENSE.SHOT_FLIGHT_UNTIL_EXIT` for *"once they hear shoot
they run and don't stop"*: the animal takes one heading at the moment of the fright
(`Brain:_latchFlight`), never settles (`Brain:_settle` returns early), is re-flushed above every
other mood (`_senseAware` row 6b), and is only over when `field.exitZ` despawns it. Source (2) says
that is not a shot-specific behaviour at all — a drive hunt produces the same 1.8 km one-way
departure — so the beater and the horn **go through the same door** and the third argument is
renamed from `shot` to `untilExit` to say so. Two systems deciding when an animal calms down is the
failure this project is named after (CLAUDE.md rule 3).

**The resting wood is `Runtime:spawnSounder` plus nothing.** An unordered sounder is an IDLE sounder
and `CALM.ENABLED` (task 117) is already the graze/stand/lie repertoire. The only new code is *where*
to put one: a search for a spot that is in the trees but not inside one, on terrain rather than on a
canopy, between her and the road, and outside her own flush reach at the start.

### One number is deliberately NOT the literature's, and this is the reason

| | measured in the wild | in the game | why |
|---|---|---|---|
| flush at a walker | 93 m (1), 84 m (4) | **25 m** (`ForestTest.SPOOK.BEATER_M`, 89 studs) | At 93 m in this wood she would never see it happen. Sight down a 40-stud forest ride is tens of studs; a flush she cannot witness is, to the player, a wood that empties itself — which is the exact bug this task fixes. Karen asked for *"once I get a bit closer"*, and 25 m is close enough to be hers. |
| horn | — | **100 m** (`Horn.CONFIG.SPOOK_M`, 357 studs) | Karen: *"horn reach is further"*. It lands on the real flight-initiation distance by coincidence rather than by design, and it is the same radius a gunshot already carries (`SENSE.SHOT_HEARD_FROM_SHOOTER_M`) and the same as the sound's own `ROLLOFF_MAX_STUDS`, so what runs is what could hear it. |
| flight | 1.8 km, 25.8 h | until `EXIT_Z` (~430 studs = 120 m south of the road) | The map is 168 m deep. "Does not come back" is the whole of the finding that survives the scale change, and the latch is exactly that. |

That is the written reason rule 2 asks for: the *mechanism* is borrowed whole, one *distance* is
scaled to a map that is 1/20 the size of the study area, and the scaling is recorded here.

## 4. The numeric targets

| What | Value | Where it lives |
|---|---|---|
| beater flush reach | 25 m / 89 studs | `ForestTest.SPOOK.BEATER_M` / `BEATER_STUDS` |
| horn reach | 100 m / 357 studs | `Horn.CONFIG.SPOOK_M` / `SPOOK_STUDS` |
| horn blast | one note, 1.00 s (clip 3.40–4.40 s of asset 9038902877) | `Horn.CONFIG.SOUND_START` / `SOUND_CUT` |
| horn cooldown | 1.5 s | `Horn.CONFIG.COOLDOWN` |
| resting groups | 5 groups, 27 animals, 55–150 studs north of the road, ±125 of her line | `ForestTest.REST.groups` |
| a group is "in the trees" | nearest solid thing 8–22 studs | `REST.clearStuds` / `nearTrunkStuds` |
| a group is not already flushed at spawn | ≥ 89 + 30 studs from her start | `REST.clearOfStartStuds` |
| the wood refills | 15 s after it is empty | `REST.restockSeconds` |
| flushed speed | `PACE.RUN_SPEED` 24 studs/s, never below, never settling | measured in §5 |

## 5. What this note measured, because no source could

All in "Driven Hunt Forest Test", 2026-10-11, one player, console trace in
`<runs-dir>/t154/t154-walk.txt`.

**The horn clip.** `Sound.PlaybackLoudness` sampled at render rate in a Play session, peak per
bucket: 0.05 s over the first 5.2 s, then 0.02 s over two candidate windows. Asset 9038902877 is
**60.63 s** of a horn blown over and over. Its first call is **eight** separate notes between 0.20 s
and 3.36 s, each 0.39–0.50 s with a valley between; the loudest (peak 453 at 2.40 s) is 0.40 s nose
to tail. The phrase's **last** note runs 3.42–4.38 s with a long natural decay into the clip's own
silence at 4.40–5.08 s, and the second call begins at 5.10 s. So **3.40 → 4.40 is the only single
note in the clip that reaches 0.5–1 s, and the only one whose end is real silence** rather than the
next note's attack. A 0.5–1 s single note does not otherwise exist in this asset; that is why the
cut is the one it is and not a shorter, louder one.

**The bug the first build hit, and it was not in this task's code.** Five resting sounders were put
down 112–181 studs from a *motionless* beater and all 27 members were `FLEE` in the first report,
marching south at `WALK_SPEED` for the whole session. The cause is `PACE.LEAVE_AFTER_CROSSING` (task
149b): "a stimulus on the far side from the exit is one the animal has gone past". **A beater is
always on that side — that is what a beater is** — so every animal in the wood read as "past the
guns" on its first sense tick. The rule now only counts a stimulus that is *not* a driver, which is
what "past the GUNS" always meant. It had no spec coverage at all; it has one now
(`boar_behaviour.spec`, "what counts as a threat the animal has gone past").

**The walk.** After the fix, the five groups hold station grazing (`IDLE`, 0.0–4.0 studs/s, dz
unchanged over 40 s). Walking at the nearest one:

| group | spooked at | speed over the next 10 s | heading vs away-from-her | outcome |
|---|---|---|---|---|
| rest-3 (9) | 89 studs (25 m) | 24.0 · 21.3 · 24.0 · 24.0 · 21.3 · 24.0 | +0.61 → +0.97 → +0.99 → +0.99 → +0.98 | dz 90 → −89, crossed the road |
| rest-2 (6) | 89 studs (25 m) | 20.4 · 24.0 · 24.0 · 24.0 · 24.0 | +0.62 → +0.96 → +0.95 → +0.98 → +0.99 | dz 104 → −43, crossed |
| rest-4 (2) | 89 studs (25 m) | 24.0 · 24.0 · 23.1 · 24.0 | +0.74 → +0.86 → +0.93 → +0.96 | dz 97 → 3, crossing |
| rest-1 (9) | never (she passed at 139 studs) | 0.4–2.4 | — | still grazing, dz 139–141 |
| rest-5 (1) | never (119 studs) | 0.0–3.4 | — | still grazing, dz 43–45 |

`PACE.RUN_SPEED` is 24, so **no flushed animal was ever below a run**, none settled, and the two
groups she never reached never moved. The whole sounder goes with the member she reached: the
console reads `a beater spooked Boar22 at 89 studs (25 m) took 9 with it`, and likewise 6 and 2.

**The horn.** Blown with 11 animals alive — 9 at 111 studs, 1 at 113, 1 at 669 — the console reads
`horn blown at (3073, 148, -1953): 10 boar(s) pushed within 357 studs (100 m)`. The ten inside went
to 24.0 studs/s with `away` +0.44 → +0.92 → +0.96 → +0.97 and ran dz 116 → −198 without settling;
the one at 669 studs was outside and was not counted. `Sound.TimeLength` 60.63, `IsPlaying` true at
`TimePosition` 3.68 on the click (0.28 s into the cut) and false after it.

**The kit.** Before: `tools=[HAND:Shotgun,BAG:Rifle,BAG:Horn]`. After: `tools=[HAND:Horn]`.

## 6. What is NOT verified

- **Whether 25 m feels right.** It is the Director's start value against a literature figure of 84–93
  m, it is data, and only Karen can say.
- **27 animals in five groups on Karen's machine.** A measured session has carried 32 here, but she
  has not played this build.
- **The horn at 100 m with a hunter in the world.** There is no second player in the Forest Test.
- **The Match world.** `MatchBoot` deliberately does not pass the latch and keeps its own arming
  policy, so the drive is unchanged; whether a beater there should carry no gun is the rotation
  task's.

# Task 139 - Karen's five boar complaints

Task: 139
Round: 2 (round 1 shipped nothing and is an `ESCALATE.md` entry)
Base: main (`0c7f736`)
Code commit: `d796c4898af323a2ed0d17ec6d19bbb0b050e117`

```
[harness] PASS: 33/33 checks @ d796c4898af323a2ed0d17ec6d19bbb0b050e117 (clean tree) scope=all
```

`test2` is N/A: no path in `TWO_PLAYER_PATHS` is touched.

## The table

Three 150 s Forest Test runs per build, hunter at a stand, shots through the real `FireRequest`
route, reload after two. Round 1's lesson was that one run cannot tell an effect from noise.

| | main (3 runs) | round 2 (3 runs) | target |
|---|---|---|---|
| ran NORTH after a shot | 8 / 6 / 4 — **mean 6.0** | 0 / 0 / 0 — **mean 0.0** | 0 ✓ |
| came back north over the road | 0 / 0 / 0 | 0 / 0 / 0 | 0 ✓ |
| stood after a shot | 1 / 0 / 1 — mean 0.7 | 0 / 0 / 1 — **mean 0.3** | 0 ✗ |
| moving with NO locomotion clip | 22.2 / 26.0 / 27.0 % — **mean 25.1 %** | 1.0 / 1.3 / 1.3 % — **mean 1.2 %** | — ✓ |
| slide, median gap feet vs ground | 56.2 / 56.2 / 56.1 % | 56.2 / 56.2 / 56.2 % | — ✗ |
| worst sounds, one pack | 2 / 2 / 2 | 2 / 3 / 2 | ≤ 2 ~ |
| worst sounds, world | 2 / 2 / 2 | 2 / 3 / 3 | ≤ 3 ✓ |
| shots fired | 10 / 7 / 8 | 10 / 10 / 9 | — |

**What the no-clip figure was**, by the clip that was playing instead of a walk cycle — main:
`idle` 2,151 samples, **`grazeLoop` 2,052**, `smell` 377, `grazeStart` 181. Round 2: `grazeStart` 78,
`idle` 76, `smell` 35, `grazeLoop` 4.

## A — fled or crossed leaves the drive, and the exit wins

1. **The rejoin rule was round 1's regression, and the Director named it.** Task 136 sent an animal
   whose flight had ended back to the TAIL of its line — and the tail is NORTH of the road, so with
   flights pointed south every fled animal was ordered straight back into the view Karen had just
   shot into (19–26 came back north in round 1, against 0 on main). It is deleted, archived under
   `backups/2026-10-09-line-rejoin-at-tail.md` with its spec case (rule 7).
2. **One permanent rule replaces it:** `line.gone` in `ForestTest.stepLines`. Flying, hurt, or south
   of the road means out of the file **for good** — never ordered again, never rejoined. What the
   animal does next is `Brain`'s business.
3. **`Brain:_latchFlight` lets the exit win even past the gun.** That line used to take `away` when
   the shooter stood between the animal and `exitZ` — and **in a drive he always does**. The
   away-vector is kept as a sideways swerve (`MOVE.FLIGHT_SWERVE`), so the animal still breaks left
   or right of the gun; it just never breaks backwards. **6.0 → 0.0.**

## B — a line is a pack, then the approach is audible

4. **`Runtime:formSounder(ids)`, called once by `releaseLine`.** This is the structural half the
   Director asked for first, and it was missing entirely: `releaseLine` spawns with `Runtime:spawn`
   per animal (not `spawnSounder`, which places a ring), so **no line member had a `sounderId`** and
   `Boar.hasVoice`'s "a herd with no list silences nobody" let every one of them speak. The voice
   ration never applied to the one formation the game actually uses.
5. **Then the step reach went 40 → 70 studs**, one number for all three gaits, volumes untouched.
   70 and not more because `boar_shot.spec` holds the other half of task 123 round 4 — the grunt
   carries more than **twice** as far as the hooves (160 against 70) — so the far cue is still the
   voice and the near cue is still the feet.

## C — the feet keep up

6. **The calm activity clip sat ahead of the gait selection** and answered for ANY calm animal, so a
   boar the drive was walking along at 4 studs/s with its head down played the grazing LOOP and
   skated. It is now for an animal that is standing still — **except** a calm clip that carries its
   own ground (`digWalk`, a boar rooting as it walks) and **except** an exit clip already in progress
   (`grazeEnd`, the head coming out of the grass). Both exceptions were taught to me by existing
   specs that failed, and both are tested by the clip's own `groundStudsPerSecond` rather than by a
   list of names.
7. **Anything moving above `MODEL.STILL_SPEED` (0.6) now walks**, so a follower easing onto its
   station has a walk cycle under it instead of `idle`.
8. **The dwell path divided by the clip's ground speed without `clipScale`**, where every other rate
   in the file includes it — a real defect, fixed. It did **not** move the slide median (below).

## What could not be verified

- **The slide median did not move: 56.2 % on both builds, across six runs, to ±0.1.** That stability
  is itself the finding: it is not noise, and it is not plausibly a property of six different
  animals in two different builds. I believe my probe's `footed = groundStudsPerSecond × clipScale ×
  track.Speed` is measuring the wrong thing — `1 − 0.4372` (the cub's `clipScale`) is 0.5628, which
  is the number to within a rounding — but I could not prove where in the remaining time. **The
  figure I DO trust is the no-clip one**, 25.1 % → 1.2 %, which is the one that corresponds to what
  Karen can see: an animal translating with no walk cycle at all. I am not claiming the sliding is
  fixed; I am claiming the largest measured cause of it is.
- **"Stood after a shot" is 0.3, not 0.** One case in three runs survives (`top speed 4.5, moved 11
  studs in 12 s`). `line.gone` removes the animal from the file the moment it is hurt, so the drive
  is no longer ordering it to stand — what is left is something in `Brain`, and I have not found it.
- **THE TABLE WAS MEASURED ON AN INTERMEDIATE BUILD.** The three round-2 runs were taken before the
  last two commits, which differ in exactly two ways: the step reach is 70 for all three gaits rather
  than 75/85/95 (sound only — cannot affect any movement number), and `digWalk` and an in-progress
  graze exit now pass the activity gate. The second would, if anything, raise the no-clip figure
  slightly from 1.2 %. I could not re-measure because the probe is temporary instrumentation and the
  tree has to be clean at the code commit.
- **Standing rule A, Forest Test, 85 s:** the Tool in the CHARACTER at 15 s and at the end
  (`tool=true backpack=false` both), **0 fault lines in 22**, four wave lines released at a trot, 1
  and 2 lines per wave.
- **Studio:** I opened DEV from the Forest Test window for the gate, read the Rojo sync dialog in
  full (four edits — `Boar/Body`, `Boar/Brain`, `ForestTest/Line`, `Tests` — **no removals**),
  accepted, ran the gate, then closed the place with Save and closed the empty window. Karen has one
  Studio, the Forest Test, in Edit.

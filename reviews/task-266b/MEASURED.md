# Task 266b — what was measured, pasted

Every line below is copied from the run that produced it. The live ones are from the **Driven Hunt
Forest Test** (placeId 130094961655666), with `DHFlag_HIT_CLAIM=true` and `DHTestOwns=rifle.scoped`
set in **Edit before Play** (`Economy` resolves `DHTestOwns` once at boot) and both removed
afterwards. The probes are in `reviews/task-266b/probes/`.

---

## 0. CLICK PROOF, first, as the dispatch required

```
SELFTEST: 5 click(s) -> 5 ShotLanded
SELFTEST PASS
```

Setup each time: `PRE OK team=Shooters held=[Rifle] gun=Rifle`, and the flag resolved live on BOTH
sides — `isOn(HIT_CLAIM)=true source=override`.

## 1. ITEM 1 — the counters, where a probe can read them

The counters are module state and a probe gets a **fresh module cache**, so "did the server accept
it?" could not be asked at all. `ServerStorage.DHClaimStats` is the answer, Studio only:

```
enabled=true claims=1 accepted=1 refused=0 ignored=0 worst=0.000/1.526 age=0.031..0.031/1 why=ok []
```

(That is a round-1 reading; `claimLine` prints **three** worst fields since round 2 added
`claimWorstEndStuds`.)

## 2. THE FEATURE WAS INERT, AND THREE READINGS NAMED THE CAUSE

Every claim came back `claim-history`. Each instrument below was built because the previous one
could not answer, and each answered in one line:

| # | instrument | reading | what it ruled out |
|---|---|---|---|
| 1 | `claimHistoryWhy` | `why=no-sample` | the provider was wired and did not throw — it answered nil |
| 2 | `claimAgeMin/Max` | `age=0.007..0.031` | the clock: the arrival is 7–31 ms in the server's **past**, well inside `AGE_MAX_SECONDS` |
| 3 | `DHBoarHistory` | `animals=12 samples=13514 misses=0` | the ring is written; 13,514 samples, newest = server now |
| 4 | `historyWhy` | **`span live=64 at-oldest=1.877 at-newest=0.027`** | **the answer**: the claimed arrival is **27 ms NEWER than the newest sample** |

**It always would be.** The ring is stamped once per `Runtime:step`; the claim is judged in the
Weapon's own Heartbeat handler; the claimed arrival is only ~10–30 ms old when it is judged. So the
instant asked about falls in the gap between the last sample and the present, every single time.

**THE FIX IS AN INTERPOLATION.** The server knows exactly where the animal is NOW, so an instant
between the newest sample and the present is bracketed on both sides. Past the present it is still
a refusal.

| cycle | change | reading, same probe |
|---|---|---|
| 1 | as shipped in task 266 | `claims=1 accepted=0 refused=1 why=no-sample [claim-history=1]` |
| 2 | `Boar.sampleAt` takes `now` and the live CFrame | **`claims=1 accepted=1 refused=0 why=ok []`** |

That `accepted=1` is the first accepted claim in this project's history.

## 3. ACCEPTANCE 2(1) — a STILL animal, three chest shots

One staged boar at 91 studs, locked by name (`--target Boar19`), rifle, chest aimed
(`offTarget` 0.000–0.020°). All three:

```
ROWS [1] ZoneChest zone=chest world 3017.54,138.59,-2008.06 local 1.060,0.095,0.139
mark=[hit/chest kill/chest]
```

**THE FRAME, `266b-acc1-still.png`, opened and described:** the shooter's eye, first person on the
stand (camera at player eye height), scoped rifle low-right, autumn wood ahead. Bottom-left the hit
card reads **`HIT - .416`** with a red diamond on the boar silhouette's **chest**, behind the
shoulder. The bottom line reads **`Alhamdulilah824 MALE BOAR  chest  25 m  RIFLE`** — 25 m is
91 studs at 0.28 m/stud. It is a **STILL** animal and is not offered as anything else.

**`accepted` moved by 1 across those three, not 3**, and the cause is a staging artefact: the
anchored animal's CLIENT replica still reported `v = 11.17` while the server had it still, so the
client's own simulation shifted its segment by `velocity * elapsed` and claimed nothing on two of
them. The ZONE outcome — what Karen sees — was 3 of 3.

## 4. ACCEPTANCE 2(3) — a forged claim, live, before and after

A probe sent a claim naming a real animal and a real zone with an honest flight time and a point
**30 studs** from where the server's own history put it. Everything else true.

```
before   claim=nil
after    claims=1 accepted=0 refused=1 ignored=0 worst=0.000/0.000 age=0.050..0.050/1 why=ok [claim-moved=1]
```

**`why=ok` is the part that matters:** the rewind ANSWERED, so the refusal is the check doing its
job and not a missing history — a distinction that did not exist before item 1.

## 5. ACCEPTANCE 2(2) — a RUNNING animal: NOT PROVEN

No shot was landed on an animal that was still moving at the trigger. Two claims on moving animals
were refused `claim-line`; in the window that remained the drive presented nothing above 4 studs/s
inside 150 studs. **Nobody has seen this.**

What round 2 then found is that the explanation offered for those refusals was measured with the
wrong meter: `claimWorstLineStuds` was written from the trajectory's END point, not the closest
approach check 4 uses. With the meter corrected, the in-gate accept case reports

```
accepted 0 -> 1, worst 0.000/0.027, refusedClaimBy []
```

— an across-track distance of **0.027 studs** against a 2.0-stud tolerance. So the budget is barely
touched and the `claim-line` refusals are **not** explained by a large across-track error. What does
explain them has not been measured.

## 6. THE PLACE IS AS IT WAS

`flags.py --place forest clear` removes **every** override, not one — the incident its own docstring
records from 2026-10-21 — so the nine flags that were not mine were put back from the before-dump
(`reviews/task-266b/probes/266b-restore.luau`). The attribute set now reads character for character
what it read at the start: 11 rows, `DHForestStartRole=hunter`, no `HIT_CLAIM`, no `DHTestOwns`, and
the two diagnostic attributes removed. Every staged animal was un-anchored.

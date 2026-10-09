# Task 138 - a body hit is drawn at the nose

Task: 138
Round: 1
Base: main (`e1877dd`)
Code commit: `3871b0c33cb0bc3a5a80b5451341d95b881823b5`

```
[harness] PASS: 33/33 checks @ 3871b0c33cb0bc3a5a80b5451341d95b881823b5 (clean tree) scope=all
```

`test2` is N/A: no path in `TWO_PLAYER_PATHS` is touched.

## THE ROOT CAUSE, AND MY OWN 137a DIAGNOSIS WAS WRONG

137a guessed at "the impact position or the CFrame handed to `Shape.dot` for a body hit". **It is
neither. The record is correct and always was.** I logged every input to the dot, per hit, and shot
real animals in the Forest Test through the `FireRequest` route:

```
[T138] zone=body part=Boar16 size=(0.90,1.35,2.47) impact=(2969.9,135.0,-2007.5)
       local=(0.19,-0.07,-1.24) fz=-0.500 -> u=0.000
[T138] zone=body part=Boar25 size=(1.70,2.55,4.68) impact=(2963.3,135.2,-2015.8)
       local=(0.63,-0.27,-2.34) fz=-0.500 -> u=0.000
[T138] zone=body part=Boar4  size=(2.00,3.00,5.50) local=(1.00,-0.18,-1.68) fz=-0.306 -> u=0.194
```

`local.Z` is **exactly −size.Z/2** in four of seven hits — the pellet struck the **front face of the
trunk box**. `u = clamp(fz + 0.5, 0, 1)` then answers 0, which is the correct projection of a hit on
the nose end. Across seven real shots **every `body` hit landed in the front quarter**: u = 0.000,
0.005, 0.170, 0.194, 0.210, 0.236. The reason is the game, not the code: **the drive walks the
animals straight at the hunter**, so the first surface a pellet meets is the front of the body. Their
own look vectors in the log are (0.09, 0, −1.00), (−0.39, 0, −0.92), (0.59, 0, −0.81) — all facing
south, at the stand. I added a broadside filter and still could not find a true flank shot in 150 s.

**So there is no bug in `Shape.dot`, `HitLog` or the impact position, and this task changes none of
them.** What was wrong is the PICTURE: the drawn boar had nothing below the snout, so the commonest
hit in the game was drawn under its chin.

## What changed

1. **The drawn boar gets a `Brisket`** — the deep front of the chest, under the jaw and in front of
   the forelegs (`Report.CONFIG.BOAR`, u 0.02–0.36, v 0.42–0.68). It is anatomy, and it is where the
   hits are.
2. **`Report.ontoBoar(u, v)`** puts a dot that still falls in the air onto the nearest point of the
   drawn animal, measured in PIXELS (the art is 104 × 56, so "nearest" is not in the unit square). It
   is a **drawing decision and the record is untouched** — the pip's attributes still carry the true
   `(u, v)` the server measured — which is the same line `drawDots`' half-dot inset already draws.
   The box has corners; an animal does not.

## The table: the same 13 measured hits, before and after

The `(u, v)` values are **identical** before and after — that is the point. What moved is where they
are drawn.

| measured (u, v) | drawn at | BEFORE | AFTER |
|---|---|---|---|
| (0.000, 0.441) | (0.034, 0.448) | Snout | Snout |
| (0.000, 0.549) | (0.034, 0.543) | **NOTHING** | Brisket |
| (0.000, 0.556) | (0.034, 0.549) | **NOTHING** | Brisket |
| (0.000, 0.564) | (0.034, 0.556) | **NOTHING** | Brisket |
| (0.000, 0.567) | (0.034, 0.559) | **NOTHING** | Brisket |
| (0.000, 0.606) | (0.034, 0.593) | **NOTHING** | Brisket |
| (0.000, 0.890) | (0.034, 0.841) | **NOTHING** | nudged onto the animal |
| (0.005, 0.600) | (0.038, 0.588) | **NOTHING** | Brisket |
| (0.048, 0.525) | (0.078, 0.522) | **NOTHING** | Brisket |
| (0.170, 0.564) | (0.192, 0.556) | **NOTHING** | Brisket |
| (0.194, 0.561) | (0.215, 0.553) | **NOTHING** | Brisket |
| (0.210, 0.500) | (0.230, 0.500) | Head | Head |
| (0.236, 0.576) | (0.254, 0.567) | **NOTHING** | Brisket |

**Off the animal: 11 of 13 before, 0 of 13 after** (12 land on drawn parts, the thirteenth is nudged).

## Claims

1. **`Shape.dot`'s two ends are now asserted**, which is what stops this being called a bug again: a
   **broadside** hit on the trunk's side face at mid-length maps to **u = 0.5** and reports the flank
   it came in on; a **front-face** hit maps to u = 0 and a back-face hit to u = 1. Verify:
   `report_silhouette.spec`, "maps a BROADSIDE hit to the middle of the body".
2. **The ten real measured hits are the spec.** "has animal under a FRONT-ON hit" walks the measured
   `(u, v)` list through the panel's own half-dot inset and fails if any of them is drawn off the
   animal.
3. **The nudge is asserted both ways**: the bottom-front corner a real session produced
   (u = 0.000, v = 0.890) ends up on the animal, and a dot already on the animal is **not moved at
   all** — which is what keeps this from quietly repositioning every hit in the report.
4. **Load-bearing, measured.** With the `Brisket` and the nudge both deleted the suite reports
   `report_silhouette.spec:224: a measured body hit (0.034, 0.543) is drawn off the animal` and
   `report_silhouette.spec:237 Expected true, got false`, and `787 passed, 0 failed` becomes
   `785 passed, 2 failed`. Restored with `git checkout`; tree clean at the code commit.

## The frame (rule 5)

`.screenshots/t138-after.png` — two real animals from real shots, with a 4× copy of the first row.

**The fatal diamond is on the animal now.** In the 4× view it sits on the brisket, just behind and
below the jaw, clearly inside the outline; before this change the same dot (u = 0.000, v ≈ 0.556)
hung in the air in front of the nose. At row size both rows show it against the chest.

**Honestly: it is at the very FRONT of the animal, not mid-flank**, and it should be — those were
head-on shots into the front of the trunk. It no longer floats, and it no longer says "nose"; it says
"front of the chest", which is where the pellets went.

## What could not be verified

- **I could not produce a true broadside hit in the live world.** The drive is built to walk the
  animals at the hunter, so over 150 s with a broadside filter the best angle available was ~0.5 of
  the shot line. The flank case is therefore proved by `Shape.dot`'s arithmetic (claim 1) rather than
  by a live shot. That the LIVE hits are all front-quarter is itself the finding.
- **The report still does not say a shot was head-on.** A side-view silhouette cannot show the
  difference between "front of the chest" and "straight up the nose", and `side` only answers which
  flank. That is a design question for the Director, not something to invent here.
- **Standing rule A, Forest Test, 85 s:** the Tool in the CHARACTER at 15 s and at the end
  (`tool=true backpack=false` both), **0 fault lines in 22**, four wave lines released at a trot and
  a run, 1 and 2 lines per wave. The report panel is not opened by a plain Play, so the evidence that
  this change ran is the framed run above plus `report_silhouette.spec` in the gate.

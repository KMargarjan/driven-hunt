# Task 276 -- is the instrument leading BACKWARDS? Then the rate.

Task: 276
Round: 1
Base: `144b1b0a` (`main`, after #254, which carries 275)
Code commit: `d9464ecb3c342a10e7d9e998271eb6483e19689f` (the PLAN). **NOTHING UNDER `src/`,
`tests/` OR `tools/` CHANGED IN THIS TASK** -- the Director's hypothesis was refuted by measurement
and every change this task made is in the INSTRUMENT, which lives outside the repo.
`git diff --name-only main..HEAD` is `reviews/task-276/REQUEST.md` only.

```
[harness] PASS: 34/34 checks @ d9464ecb3c342a10e7d9e998271eb6483e19689f (clean tree) scope=all
```

`test2` is **N/A**: nothing under `src/` changed, so no path can be in `TWO_PLAYER_PATHS`.

## PLAN

Written before any edit to `src/` or to the instrument, as the core quality protocol's step 0
requires. **The Director's hypothesis is a claim about a SIGN, and a sign is cheap to measure**, so
item 1 is one printed line and nothing else changes until it has been read.

### (a) REAL LIFE

A crossing animal is led AHEAD of itself by the bullet's own flight time. At the scoped .416's
2612 studs/s the flight to 140 studs is **0.057 s**, and a red deer at the **32 studs/s** this
world measures (9.0 m/s; a red deer's gallop is 10-13 m/s, `docs/research/2026-10-24-ballistics.md`)
covers **1.84 studs** in that time -- a third of the 6.03-stud trunk measured on a live hind in task
268. **The sign is not a matter of taste: the aim point is `chest + v * t`, never `chest - v * t`,
and the two differ by 3.7 studs, which is more than half a body length.**

### (b) MEASURED NOW -- task 275, both arms on one build in one session

`<runs-dir>/275-a.log` and `275-b.log`, `DHClaimStats` read as a live `ServerStorage` attribute
(L-026), five shots each at staged running deer in Karen's Forest Test with `HIT_CLAIM` ON:

| trial | chest | the accepted claims named | refusals |
|---|---|---|---|
| A, 5 shots LED by `v x flight` | **0 of 5** | `ZoneRear(rear)` | `claim-line` 4.403/2.000 |
| B, 5 shots NOT led | **2 of 5** | `ZoneChest(chest)` | `claim-line` 4.668/2.000 |

**That is the reading the Director's hypothesis is built on and it is confirmed, not contradicted:
leading made it worse.** What has never been measured is the SIGN of the lead the instrument
actually applies -- every log of tasks 268-275 carries `lead 1.837` as a MAGNITUDE
(`DHTrackLeadStuds` is `.Magnitude`), so a lead applied backwards and a lead applied forwards have
printed the same number for nine tasks. **That is the gap this task closes.**

The Forest Test's attributes, read before anything was touched this session
(`<runs-dir>/attrs-id.luau` through `ftq.py`, by placeId): twelve rows, `DHFlag_HIT_CLAIM=false`.

### (c) TARGET

* **Item 1:** one line per shot that answers the sign **as a signed number**, in the animal's frame:
  `(aim - chest) . vhat`, its word (AHEAD / BEHIND), its magnitude against `v * flight`, the
  velocity SOURCE by name, and the angle between that velocity and the animal's motion sampled over
  the last 0.2 s. Three shots. **A signed dot product and not a distance** because a distance is
  exactly what nine tasks already printed and it cannot answer the question.
* **Item 2 (CORE):** **at least 8 of 10 led shots are accepted claims naming the chest with the mark
  on the chest.** The dispatch's number; it is the rate at which Karen could use the feature.
* **Item 3:** 5 unled shots land BEHIND the chest by about `v * flight` -- the real lead existing.
  Measured along the animal's own velocity, with a sign, by the same line as item 1.

### (d) LEVER

```
<runs-dir>/proof268.py:377:        local aim = chest + vel * (flight * LEAD)
<runs-dir>/proof268.py:370:            local fresh = (chest - lastAt) / (now - lastT)
<runs-dir>/proof268.py:371:            vel = vel * 0.5 + fresh * 0.5
<runs-dir>/proof268.py:376:        local flight = Ballistics.timeToRange(shot, (chest - at).Magnitude)
src/shared/Ballistics/init.luau:119:function Ballistics.timeToRange(shot: Shot, studs: number): number
```

**The lever is in the instrument, not in the game** -- `proof268.py`'s tracker is the one writer of
the aim point (`DHTestLook`), and `aim = chest + vel * (flight * LEAD)` is the one line that decides
the sign. It is outside the repo (Director ops), which is why this task may well change no `src/`
file at all. The repo's own `Ballistics.timeToRange` supplies `flight` and is not in question.

**AND THE FRAME OF EVERY QUANTITY, STATED BEFORE ANYTHING IS COMPARED (L-021):** `chest`, `aim`,
`vel` and the 0.2 s motion trace are all read from the **CLIENT's** replicated copies, in **world**
coordinates, inside one `RenderStepped` iteration -- `chest` is `ZoneChest.Position` on the client,
`vel` is differenced from two of those positions, and the comparison `(aim - chest) . vhat` is
therefore two client-frame quantities against a third. Nothing in item 1's line is read from the
server. The server's own `AssemblyLinearVelocity` is printed BESIDE it as a separate field, named
as the server's, and never mixed into the dot product.

### (e) HOW IT IS MEASURED AFTER

The same instrument, with item 1's line added to it and nothing else changed:
`<runs-dir>/proof268.py` + `268kill.py` -- `DHTestRelease` stages a hind party, the hold is led by
`v x flight` through `Ballistics.timeToRange`, the settle gate checks the live generation AND the
angle, the trigger is a real focused click through `click.ps1`, and `DHClaimStats` is read as a live
attribute before and after every shot (L-026). The lead line is latched on **`ShotFired`**, the
server's own announcement of the trigger, exactly as task 273 fixed the sight basis -- a line read
when the payload arrives would describe the hold AFTER the shot.

### On L-022 -- the two sides must not be the same read

The 0.2 s motion is a **separate ring of sampled (time, position) pairs** kept by the tracker, and
the lead uses the EWMA `vel`. They are two instruments over the same animal, which is the point: if
`vel` ever pointed backwards, the ring would not. Task 275's round 1 fed one untestable zero into
both sides of a check and the Reviewer was right to refuse it.

### On the Learning Agent's route note -- `static-blocked`

269a(b) is unfixed and task 275 measured that **every** no-claim shot in ten was `static-blocked`
(the client's own static pass closing on ground clutter in front of a crossing deer). So this task
reports `DHClaimWhy` per shot and **counts the three outcomes apart**: a chest hit, a `claim-line`
refusal, and a shot that never built a claim at all. A rate under 8/10 that is all foliage noise is
not evidence about the lead and will not be reported as if it were.


## WHAT CHANGED

**No `src/`, no `tests/`, no `tools/`.** Three instrument changes outside the repo
(`<runs-dir>/proof268.py`, `268kill.py`) and twenty live shots in Karen's Forest Test.

## ITEM 1 -- **MET. THE LEAD IS APPLIED AHEAD. THE DIRECTOR'S HYPOTHESIS IS REFUTED.**

Three shots, the printed line, `<runs-dir>/276-l1.log`. **Every quantity is the CLIENT's, in world
coordinates, read inside one `RenderStepped` iteration** (L-021); nothing here is the server's.

| shot | aim minus chest | **ALONG the velocity** | word | `v * flight` | across | v, src | motion over ~0.2 s | **ang(v, m)** | `vPart` | ang(vPart, m) |
|---|---|---|---|---|---|---|---|---|---|---|
| l1.1.1 | 0.235 | **+0.235** | **AHEAD** | 0.235 | 0.000 | 22.53 diff-client-ZoneChest | 22.26 over 0.223 s | **1.2 deg** | 21.12 | 7.2 deg |
| l1.2.1 | 0.895 | **+0.895** | **AHEAD** | 0.895 | 0.000 | 24.48 diff-client-ZoneChest | 27.91 over 0.237 s | **2.1 deg** | 28.48 | 4.0 deg |
| l1.5.1 | 2.208 | **+2.208** | **AHEAD** | 2.208 | 0.000 | 29.21 diff-client-ZoneChest | 29.73 over 0.209 s | **0.9 deg** | 28.32 | 4.5 deg |

* **SIGN: AHEAD on all three, and on 16 of the 16 moving-target shots taken since** (the other two
  were animals standing still, printed `NEITHER` at `+0.000`). **Not one shot in twenty read
  `BEHIND`.**
* **MAGNITUDE: exactly `v * flight`**, to the three decimals printed, with `across` 0.000 -- the
  lead is parallel to the velocity by construction and the arithmetic is the repo's own
  `Ballistics.timeToRange`.
* **SOURCE: `diff-client-ZoneChest`** -- two of the client's own `ZoneChest.Position` reads one
  frame apart, smoothed 50/50. It is **not** the server root and **not** the drawn model. Its
  direction agrees with the animal's sampled motion to **0.9-2.1 degrees**; the obvious
  alternative, the client part's own `AssemblyLinearVelocity`, is **4.0-7.2 degrees** off the same
  sample, so the instrument is using the better of the two.
* **The 0.2 s motion is a SEPARATE ring of (time, position) samples** (L-022), not the EWMA the
  lead uses: the two sides of the direction check are two instruments.

## WHAT THE NUMBERS SHOW INSTEAD -- three causes, each a measurement

### (i) THE IMPACT LANDS BEHIND THE CHEST BY 5 STUDS, LED OR NOT, AND THE LEAD IS 1

The offset from the chest is now **signed along the animal's own velocity** (it was a magnitude for
nine tasks, and a magnitude cannot tell a shot that led too far from one that did not lead at all).
Two trials, same session, same build, same instrument, the trigger gated on the chest being
presented (`<runs-dir>/276-ul.log`, `276-ld.log`):

| | shots | **impact, ALONG v, from the chest** | mean | the lead applied | chest-named |
|---|---|---|---|---|---|
| **UNLED** | 5 | -3.830, -7.127, -6.184, -3.619 (+ one -79.2 into a tree) | **-5.19** | 0.000 | **1 of 5** |
| **LED by `v x flight`** | 5 | -4.612, -6.689, -4.654, -6.009 (+ one at v near 0) | **-5.49** | 0.27-1.65, mean 0.97 | **1 of 5** |

**Every clean shot in both arms landed BEHIND the chest, by 3.6 to 7.1 studs.** At the measured
21-32 studs/s that is **0.19 s of animal** -- the view lag tasks 271-273 measured at 0.167-0.178 s.
**The lead the dispatch is arguing about is 1 stud against an error of 5.**

### (ii) THE CHEST ZONE IS ONLY REACHABLE FROM A NARROW ASPECT BAND

Swept with a ray around one live animal at 5-degree steps, from the player's own eye height
(`<runs-dir>/276-band.luau`): the first of the animal's own parts on the line to its chest centre is
`Boar121` (the trunk, whose `HitZone` is `body`) from **0-35 deg** off its nose, **`ZoneChest` from
40-115 deg**, the trunk again to 135, and **`ZoneRear` from 140-180**. The chest zone measures
1.64 wide against the trunk's 1.54 (task 273's geometry probe), so it clears its own trunk by
**0.05 studs a side** and is 1.54 long against a 6.03 trunk. **A shot at the chest of an animal
running at you reads `body`; at one running away it reads `rear`; and the band moves per animal**
(one live animal answered `ZoneChest` at aspect 48 while another answered the trunk at 88). That is
why nine tasks of "0 of 5 chest" were mostly reporting the animal's aspect, not the gun.

### (iii) `static-blocked` -- 3 of the 10, unchanged from task 275

The client's own static pass closing on ground clutter in front of a crossing deer. 269a(b) stays
unfixed and is separated out below rather than counted as a lead failure.

## ITEM 2 (CORE) -- **NOT MET. 0 of 10.** This is still unproven; nobody has seen it at a rate

Ten led shots, `HIT_CLAIM` ON, the trigger gated on the chest being presented
(`<runs-dir>/276-led.log`). **The server named the chest on NONE of them.**

| | count |
|---|---|
| shots | 10 |
| **server named `ZoneChest`** | **0** |
| a claim was built | 7 (3 `static-blocked`) |
| claims accepted / refused | 3 / 4 |
| **the CLIENT claimed `ZoneChest` and the server REFUSED it** | **2** |
| the chest was still presented when the trigger fell | 4 |

**On the honest denominator it is 0 of 4**, and the reason the other six do not count is itself
measured: **1 to 2 seconds pass between the gate read and the real focused click** (the round trips
plus `park`/`click`), and a deer at 28 studs/s covers 30-60 studs and turns in that time -- six of
the ten were tail-on at the trigger although every one of them passed a chest gate to get there.
**That is an instrument limit and I am naming it as one.**

## ITEM 3 -- **MET IN SIGN, AND ITS OWN MAGNITUDE IS REFUTED**

The dispatch asks that unled shots "land BEHIND the chest by about `v x t`". **They land behind, all
five** -- but by **3.6 to 7.1 studs** while `v x flight` for those same shots was **0.45 to 0.92**.
They land behind by `v x 0.19 s`, which is the view lag, not the bullet's flight.

**And the paired arms retire task 275a(a)'s signal.** 275 measured 0 of 5 chest led against 2 of 5
unled and called it the strongest remaining signal; **re-run as a pair on one build it is 1 of 5
against 1 of 5**, and the arms' means differ by 0.30 studs against a within-arm spread of 3.5.
**The double lead cannot be discriminated by this measurement** -- the quantity in dispute is 1 stud
and the noise is 3.5 -- so I am not asserting it either way, and 275's reading is withdrawn as
sampling.

## THE ONE ACCEPTED CHEST CLAIM, AND WHAT IS WRONG WITH IT

`ul.15.1`, an **unled** shot at 47 studs: server `ZoneChest(chest)`, client mark
`Attachment @ 4808.02,139.88,-3881.41 (under ZoneChest)` -- the same point, under the chest.

**THE FRAME, `<runs-dir>/276-ul-ul.15.1.png`, opened and described**: the shooter's eye from the
stand, the scoped .416 diagonally across the lower half with the yellow stand ring under it, a green
hillside of spruce and bare birch, a dirt track climbing the rise with a single figure at the top,
and **a deer lying dead on the grass at mid-left**. HUD: `stay on stand, animals coming`, `DRIVE 8 /
3:21 TIME / 0 ANIMALS / HUNTER / $12268 MONEY`, the compass on NE-E, the drive radar top right, ammo
`9 .416`. Bottom left the hit card **`HIT - .416`** with the deer silhouette carrying a **red diamond
on the CHEST, behind the foreleg**, and under it **`Alhamdulilah824 HIND  chest  13 m  RIFLE`**.

**And the defect the same shot carries:** its impact point is **5.033 studs from the chest zone's own
centre in that zone's local frame**, and 6.184 studs behind the client's chest along the animal's
velocity. An accepted claim's mark is drawn at the CLAIM's point while being parented to the part it
names -- so the card says chest and the mark sits a body length behind the chest. **The aspect at
the trigger was 12 degrees, tail-on: this is an accepted chest claim on an animal whose chest the
shooter could not see.**

## CLAIMS

1. **The lead is applied AHEAD**, as a signed dot product in the animal's frame, on 3 shots in the
   table and on 16 of 16 moving-target shots in three trials. **Nothing read BEHIND.** The
   Director's hypothesis is refuted by the instrument it asked for.
2. **Its magnitude is exactly `v * flight`** with `across` 0.000, and **its direction agrees with an
   independently sampled 0.2 s position trace to 0.9-2.1 degrees** -- two instruments, not one read
   used twice (L-022).
3. **The velocity source is the differenced client `ZoneChest` position**, and it is the better of
   the two available: the client part's `AssemblyLinearVelocity` is 4.0-7.2 degrees off the same
   sample.
4. **Impacts land BEHIND the chest by 3.6-7.1 studs in BOTH arms**, signed along the animal's
   velocity -- `v x 0.19 s`, the view lag -- while the lead in dispute is 0.27-1.65 studs.
5. **The chest zone is first on the line only from 40-115 degrees off the animal's nose**, swept at
   5-degree steps on a live animal; outside it a chest shot reads `body` or `rear`.
6. **Item 2 is NOT MET: 0 of 10** (0 of 4 on the shots where the chest was still presented at the
   trigger), with the claim counters and `DHClaimWhy` per shot.
7. **The CLIENT claimed `ZoneChest` twice and the server refused both** -- `claim-line`, task
   275a(b) unchanged. That, not the lead, is the game-side defect in the way.
8. **Item 3's sign is MET and its magnitude is refuted**: behind by 3.6-7.1, not by `v x flight`
   (0.45-0.92).
9. **Task 275a(a)'s 0/5-vs-2/5 did not reproduce**: 1 of 5 against 1 of 5 on one build in one
   session, means 0.30 studs apart against a 3.5-stud spread. Withdrawn as sampling.
10. **The Forest Test is as it was found.** Twelve attributes before, twelve after, byte-identical;
    `HIT_CLAIM` ON for the trials and **OFF again** (rule K); `flags.py --place forest clear` never
    run; `DHTestOwns` added and removed by name. Play stopped, the window closed, and the harness
    log says DEV.

## WHAT COULD NOT BE VERIFIED

* **Whether the chest can be hit at the rate the dispatch asks, at all.** The instrument cannot
  hold a 1-2 s trigger latency against a 28 studs/s animal, so the denominator it offers is not the
  denominator a player has. **The next trial wants a trigger that fires from inside the game loop,
  not through a round trip** -- or a slower animal.
* **The double lead.** Refuted as a reading of 275's numbers, not settled: this measurement's noise
  is 3.5 times the quantity.
* **`claim-line` at 4.1 of 2.0 with `took=1 best=1`** -- untouched here, as in 275.

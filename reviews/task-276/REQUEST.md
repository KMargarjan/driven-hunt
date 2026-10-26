# Task 276 -- is the instrument leading BACKWARDS? Then the rate.

Task: 276
Round: 1
Base: `144b1b0a` (`main`, after #254, which carries 275)
Code commit: (filled in with the harness line)

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

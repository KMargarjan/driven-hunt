# How a driven sounder moves: file, edge, crossing, flight

**Task 126.** Research note, written before any code (CLAUDE.md rule 1).

Karen, 2026-10-05, watching the Forest Test while task 124 was being built:

> *"after shoot animals usually run straight when they spook ofc avoiding opsticals"*
> *"they shouldn do circles like I see now"*
> *"wildboar has to cross then when I shoot it runs awai a lot until I can;t see them like in
> real life not run a bit and stop"*
> *"it could be lines of boars like in real life check how they run how they cross road and
> apears in front of shooter we need very similar to this"*
> *"and not hitting the trees and hang"*
> *"so they comming we can hear them as now is / then they can stop before entering the road or
> walk or trot if there are spook or shoot they run and run straigh like in real life / you know
> what I mean"*
> *"and walking sound sounds like horse we need animal not horse"*

The last sentence is the whole specification: **approach → edge → cross → flight**, and the note is
organised around it.

---

## 1. What the system must do

| # | Requirement | Karen's words | Observable |
|---|---|---|---|
| R1 | A sounder travels in SINGLE FILE behind its lead animal | *"lines of boars like in real life"* | per sounder: members lie along one path, spacing bounded, order stable |
| R2 | The leader MAY stop short of the road and check; the file stacks up behind her | *"they can stop before entering the road"* | a measurable halt of 1-4 s with followers closing up |
| R3 | The crossing is a WALK, or a TROT if the herd is a bit spooked | *"walk or trot if there are spook"* | speed in the walk or trot band through the road band |
| R4 | A shot or a spook starts a RUN in a STRAIGHT line away from it | *"run straigh"*, *"avoiding opsticals"* | heading fixed once, deviation bounded except around trunks |
| R5 | The run is LONG -- out of sight, not a dash | *"runs awai a lot until I can;t see them ... not run a bit and stop"* | >= 250-300 studs covered, or gone |
| R6 | NOTHING CIRCLES | *"they shouldn do circles like I see now"* | no animal turns >= 300 deg in any 10 s window while walking or standing |
| R7 | NOTHING HANGS ON A TREE | *"not hitting the trees and hang"* | zero trunk contacts; zero animals under 1 stud of travel in 5 s while meant to move |
| R8 | Footsteps sound like an animal on a forest floor, not a horse on a road | *"walking sound sounds like horse we need animal not horse"* | the two ids change; Karen's ears decide |

R8 is a sound row and is dealt with in section 6. R1-R7 are movement.

---

## 2. External sources

Five named sources, three of them peer-reviewed, plus two hunting-practice sources. Each is listed
with what it is good for **and what it does not answer**, because two of Karen's seven requirements
are not in the literature at all and the note says so rather than inventing a citation.

### S1. Sodeikat & Pohlmeyer (2003), *Escape movements of family groups of wild boar Sus scrofa influenced by drive hunts in Lower Saxony, Germany*

* **Where:** *Wildlife Biology* 9(s1): 43-49.
  <https://bioone.org/journals/wildlife-biology/volume-9/issue-4/wlb.2003.063/Escape-movements-of-family-groups-of-wild-boar-Sus-scrofa/10.2981/wlb.2003.063.full>
* **Status / licence:** published 2003, still hosted and citable on BioOne; **subscription full
  text**, abstract and figures open. Not maintained -- it is a paper, not a project.
* **Good for R5 and for group cohesion.** It is the closest thing to our exact scenario: GPS/VHF
  family groups, actual German driven hunts. Its numbers: nightly movements **1.1-9.4 km** (mean
  3.7 km) before the hunt; in **6 of 10** hunt situations the group **stayed inside its home range**
  and in the other 4 it moved **up to 6 km** away and came back after 4-6 weeks; groups moved
  roughly **1-3 km** from the disturbance before settling; a group fled **as a unit** along **"a
  well-known trail"**.
* **Bad for us:** the sampling interval is far coarser than a game frame. It says nothing about the
  first 20 seconds, which is the only part a player sees, and nothing about formation or gait.

### S2. Thurfjell, Spong & Ericsson (2013), *Effects of hunting on wild boar Sus scrofa behaviour*

* **Where:** *Wildlife Biology* 19(1): 87-93.
  <https://nsojournals.onlinelibrary.wiley.com/doi/10.2981/12-027>
* **Status / licence:** 2013, hosted by Wiley/Nordic Society Oikos; full PDF on BioOne. Subscription.
* **Good for R4:** it separates hunting METHODS and finds that the method decides whether a boar
  **flees or hides**, and that under **drive hunting movement increased (P < 0.001)**; after fleeing
  they move less and pick cover. That is exactly our two-state picture: a drive produces a flight,
  and the flight ends somewhere else, not in a circle back to the start.
* **Bad for us:** it is a statistical result about movement RATE, not a trajectory. It gives no
  heading, no straightness and no speed we can put in a config.

### S3. Scientific Reports (2024), *Experience shapes wild boar spatial response to drive hunts*

* **Where:** *Scientific Reports* 14, article s41598-024-71098-8.
  <https://www.nature.com/articles/s41598-024-71098-8>
* **Status / licence:** 2024, open access (Scientific Reports publishes under **CC BY 4.0**), active
  journal. **HONESTLY: I could not open the full text** -- nature.com answered a 303 to an identity
  provider and the PMC mirror answered a reCAPTCHA. The figures below are from the indexed abstract
  and are cited as such.
* **Good for R5:** GPS data from **55 wild boars** over drive hunts across **three seasons
  (2019-2022)** in the Czech Republic and Sweden; **mean post-hunt flight distance 1.80 km**, and
  the elevated state lasted **25.8 h** before they returned to their former range. Boar showed two
  responses, **"remain" or "leave"**, and tended to "leave" more with experience.
* **Bad for us:** same scale problem as S1, plus I am citing an abstract.

### S4. Wielgus et al. (2024), *Frequent flight responses, but low escape distance of wild boar to nonlethal human disturbance*

* **Where:** *Ecological Solutions and Evidence* 5(2), e12331.
  <https://besjournals.onlinelibrary.wiley.com/doi/10.1002/2688-8319.12331>
* **Status / licence:** 2024, British Ecological Society, **open access (CC BY)**, active journal.
* **Good as the COUNTER-CASE, and that is why it is here.** It measures response to **non-lethal**
  disturbance -- a walker, not a drive -- and finds boar flee **often but not far**. So "a short
  flight" is a real behaviour; it is simply the behaviour for the wrong stimulus. It is the evidence
  that our two stimuli must produce two different distances, and that Karen's *"not run a bit and
  stop"* applies to the SHOT, not to a driver walking past.
* **Bad for us:** nothing about formation or about a driven hunt.

### S5. Wildtier Schweiz, *Wild boar* species account, and PIRSCH, *Schwarzwildeinstände zur Drückjagd*

* **Where:** <https://wls.ch/wild-boar/?lang=en> and
  <https://www.pirsch.de/jagdpraxis/jagdarten/schwarzwildeinstaende-zur-drueckjagd-wo-steckt-die-rotte-39779>
  (PIRSCH, published 2024-09-16, updated 2025-09-14).
* **Status / licence:** both are living, maintained web publications; all rights reserved, cited not
  copied.
* **Good for R1:** the sounder is led by **an old, experienced lead sow** who "defines where and
  when foraging and resting takes place", the hierarchy is **graded by age and body size**, and when
  travelling **adults lead and bring up the rear with the young in the middle**. That is a sharper
  statement of the march order Task 123 already built from its own sources, and it is where R1's
  ORDER comes from.
* **Bad for us:** PIRSCH's Drückjagd piece turns out to be about **where boar lie up**, not how they
  move when pushed -- I fetched it and it says nothing about file, gait or lanes. It is cited for
  the Jagdschneise context only, and the sentence I wanted is not in it.

### What NO source gave, and what we do about it

* **R2, the pause at the forest edge before crossing a ride, is not quantified anywhere I could
  find.** It is well-known hunting practice and it is what Karen asked for, but I have no measured
  chance and no measured duration. So it is **data with the Director's own numbers in it**
  (`EDGE.CHANCE`, `EDGE.SECONDS = 1..4`), written as a dial and labelled in the config as
  unmeasured. If it reads wrong, it is one number.
* **R6 (no circles) and R7 (no hanging on trees) are not behaviours at all** -- they are defects in
  our own simulation. No source can help; a measurement of our own game can, and section 5 is that.

---

## 3. What the sources do NOT let us copy, and the one honest scale conversion

Every distance above is in kilometres over hours. Our stand sees about **200 studs** of road and the
whole Forest Test field is roughly **800 x 600 studs**. At `Report.CONFIG.METRES_PER_STUD = 0.28`,
S3's **1.80 km mean flight is 6,400 studs** -- eight times the width of the world.

**So the literature settles the SHAPE and not the SIZE.** What we take from it:

* flight is **one direction, sustained** (S1's "fled as a unit using a well-known trail", S2's
  increased movement under drive hunting), not a dash and a stop;
* the distance is **far beyond what the player can watch** (S1, S3), which in our world means **"out
  of sight and then gone"** rather than a number copied from a paper;
* a **short** flight is the response to the **wrong** stimulus (S4), so the driver and the shot must
  not produce the same thing;
* the group **stays together** while it does it (S1).

The number we adopt, **`FLIGHT.MIN_STUDS = 300`**, is therefore the Director's playable figure, not a
converted one: it is longer than the hunter's sightline down the road and about half the field, so an
animal that runs it has left the picture -- which is Karen's own test, *"until I can't see them"*.
The note records the conversion so nobody later mistakes 300 for a biological fact.

---

## 4. The pattern adopted (borrow before building, rule 2)

**Single file is a FOLLOW-THE-LEADER queue, not a flocking rule.** The obvious borrow would be
Reynolds' boids (separation / alignment / cohesion), which this repo has not used and should not
start with here: cohesion pulls every member toward the group's CENTROID, and a centroid is a point
you orbit. **Boids are how you get R6's circles.** Reynolds says so himself -- the steering-behaviours
paper's own `leader following` and `queueing` behaviours are separate from flocking for exactly this
reason.

* Craig Reynolds, *Steering Behaviors For Autonomous Characters* (GDC 1999),
  <https://www.red3d.com/cwr/steer/gdc99/> -- the canonical description of `leader following`
  ("stay behind the leader, out of its path") and `queueing`. Status: a 1999 paper, still the
  reference everyone cites; free to read, text is the author's.

So the pattern is: **each animal has exactly one animal ahead of it, and steers to a point behind
that animal, never to the group.** The leader steers to the goal. That is a chain, and a chain
cannot orbit, because no member has a centre to orbit.

This also matches what our own code already has: Task 123 built `Boar.marchOrder` (sow, then
females, then cubs, males last or alone) and `Runtime:_assignMarchSlots`. **The order exists; what
does not exist is a FILE.** The slots are currently positions in a formation spread across the front.
Task 126 turns the same order into a queue.

**Straight flight is a HEADING LATCH, not a steering behaviour.** The second borrow is from our own
file: `Brain.steerAroundTrunk(direction, whisker, config, prefer)` already exists and already avoids
trunks by whisker. Flight therefore is: fix a heading once at the moment of the spook, and every
frame ask `steerAroundTrunk` to perturb THAT heading rather than recompute a new one. Avoidance is a
local deflection off a fixed line, which is exactly Karen's *"run straight ... ofc avoiding
opsticals"*.

---

## 5. Numeric targets (what the proof must show)

| Quantity | Target | Why |
|---|---|---|
| file spacing, nose to tail | 1.5-3.0 studs between consecutive members | the Director's figure; a 5.5-stud body at 2 studs' gap reads as a line, not a crowd |
| file order | lead sow, then sows, then cubs, males last or alone | S5; and Task 123's `Boar.marchOrder`, unchanged |
| file lateral spread | each follower within ~2 studs of the leader's own path | "a line", measured as RMS distance from the leader's traced path |
| edge stop | chance per sounder per crossing (dial), 1-4 s, followers close up | R2; **not measured in any source** -- a dial |
| crossing speed | walk 4.5, or trot 11 when pushed | Task 123's accepted values, unchanged |
| flight heading deviation | <= 20 deg from the heading latched at the spook, excluding trunk deflections | R4 |
| flight distance | >= 300 studs, or gone | R5, section 3 |
| turning at walk/stand | < 300 deg total in any 10 s window | R6 |
| trunk contacts | 0 | R7 |
| stuck (< 1 stud in 5 s while meant to move) | 0 | R7 |

---

## 6. The footsteps (R8)

The two ids in `Boar.CONFIG.SOUND.STEPS` today are **"Goat Footsteps Only 1" (9114623726)** and
**"Donkey Footsteps 1" (9114127078)**. Both are hooves on a hard surface -- Karen's *"sounds like
horse"* is a correct description of what they are. A wild boar on a forest floor is leaf litter,
undergrowth and the odd twig, not a clop.

**The constraint nothing in this toolchain can get round: no agent here can listen to a sample.**
Every sound round since task 116 has ended with "Karen's ears decide", and this one does too. What
CAN be checked is that an id exists and loads, which task 124 established as the method
(`ContentProvider:PreloadAsync`, read `IsLoaded` and `TimeLength` off the real `Sound`). So:

* the replacement ids are **measured to load** before they are committed;
* **the old ids stay in the config**, named, so one word brings the clop back;
* the row keeps every other number (volume, roll-off, the per-sounder ration) exactly as task 123
  left it, because those are Karen's and she accepted them.

---

## 7. What this note does not cover

* **The right-to-left pass** (Task 123 round 8 left it one-directional) is a `ForestTest` scheduling
  bug, not an animal behaviour. It is in the task because it is in the way of proving R1-R5 from the
  stand in both directions, and it needs no research.
* **Dogs**, which are what actually push a real sounder, are not in this game yet
  (`karen-game-vision`: dogs are a later milestone).
* **Leaving the map.** S1 and S3 both say a disturbed group leaves its range for weeks. Our boars
  despawn at `field.exitZ`. That is already the right shape and this task does not change it.

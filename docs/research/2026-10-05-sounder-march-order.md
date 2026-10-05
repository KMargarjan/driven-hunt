# The order a sounder marches in, and what "natural movement" is worth measuring

2026-10-05, Task 123 round 3. Written because Karen, after playing the Forest Test, asked for
something this code had no rule for at all:

> "always first go famale and then kids behind / male can walk together or on the end or alone /
> they feels like walkin strange like with mouse turning here there has to be more natural and they
> has to avoid trees to not stuck"

## What the system must do

1. **Put a sounder in a believable travelling order.** A group walking or trotting across a drive
   must read as a family, not as five animals that happen to be near each other: a lead female in
   front, the young behind her, the males at the back or not in the group at all.
2. **Keep a lone big male lone.** He is the animal a hunter is waiting for and he does not arrive in
   a line of piglets.
3. **Turn like an animal.** No frame-to-frame heading chatter -- Karen's "like with mouse turning".
4. **Not get stuck on a trunk**, and steer around one before it is stuck rather than after.

The order must survive members dying and leaving, because a drive kills animals mid-march.

## Sources

| Source | What it supports | Status |
|---|---|---|
| [Animal Diversity Web, *Sus scrofa*](https://animaldiversity.org/accounts/Sus_scrofa/) (University of Michigan Museum of Zoology) | **The travelling order**, verbatim: *"When traveling, mothers keep their young in the middle, with adults in the lead and rear."* Also *"sounders ... made up of 6 to 20 closely-related females"* and *"Males stay with their mothers until they are 1 to 2 years old and then leave the herd."* | Live, maintained by UMMZ; cited for behaviour, not reused as code or art |
| [Wildtier Schweiz / wls.ch, *Wild boar*](https://wls.ch/wild-boar/?lang=en) | **The lead sow is the leader**: *"Wild boars live together in maternal families, harems or groups of yearling animals. Particularly male animals live as loners. In a sounder with a lead sow, 6-30 animals live together."* Fetched and confirmed | Live |
| [Podgórski et al., *Long-Lasting, Kin-Directed Female Interactions in a Spatially Structured Wild Boar Social Network*, PLOS ONE 2014 (PMC4053407)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4053407/) | The group is **matrilineal and persistent** -- female kin stay together over years -- which is why the leader of a sounder is a female and why "the sow leads" is a stable fact and not a per-encounter coin flip | Peer-reviewed, open access |
| [wildbeimwild.com, *The Wild Boar*](https://wildbeimwild.com/en/animal-portraits/the-wild-boar/) | Fetched to confirm the marching claim and **did not support it** -- it carries the lead-sow and lone-male statements only. Recorded because a source that did not say what a search extract suggested is worth writing down | Live |

The first three were read as extracts through WebSearch; ADW and wls.ch were then **fetched and
quoted directly** (the quotes above are from those fetches). Nothing here is code or art, so no
licence applies -- these are behaviour claims, cited.

## What each source does well and badly

* **ADW** is the only one of the four that states a *travelling arrangement*, which is the thing the
  code needs. It is a species account rather than a field study, so it gives no distances, no
  spacing, and no measure of how often the order holds. It is enough to decide a rule and not enough
  to tune one.
* **wls.ch** is clear on leadership and on lone males and says nothing about order.
* **Podgórski et al.** is the rigorous one and is about social *networks* over seasons, not about
  the shape of a line of pigs. It is cited for why the leader is female, not for the march.
* **wildbeimwild.com** is a popular portrait and turned out not to support the claim a search extract
  attributed to it. Left in the table as a negative result.

## Karen's rule against the sources

| | Karen | ADW |
|---|---|---|
| Front | "first go famale" | "adults in the lead" |
| Middle | "then kids behind" | "mothers keep their young in the middle" |
| Rear | "male can walk together or on the end or alone" | "adults ... and rear" |

They agree, and ADW is the stricter of the two: it puts an **adult at the rear as well**, with the
young between the two adults. Karen's sentence is that same shape for the group this game actually
builds, because `Boar.CONFIG.SOUNDER.MAKEUP` makes a sounder **one sow plus her young** (with a
`YOUNG_MALE_CHANCE` of a yearling among them) -- with only one adult female there is nobody to bring
up the rear, so the rearmost animals are the young males. Nothing has to be chosen between them.

## The pattern adopted, and why

**A rank per kind, then position within the rank, assigned once.**

```
rank 1  adult females   (the lead sow at the very front)
rank 2  cubs            (the young, in the middle)
rank 3  males           (yearlings and adults, at the rear)
```

and, taking ADW's stricter claim: **when a sounder holds two or more adult females, the hindmost
female is moved behind the cubs** -- an adult in the lead *and* an adult at the rear, the young
between them. Today's makeup never produces two females, so that branch is unreachable in the game
and reachable by parameter in a spec; it is written now because Karen's roadmap already asks for
"3 males 3 females 3 cubs" and a rule that has to be rediscovered then is a rule written twice.

**Within a rank, the animal nearest the exit line is further forward.** That is the rule
`Runtime:_chooseLeader` already used for picking a leader, so there is ONE answer to "where is the
front of this herd" rather than two that can disagree -- this project's named killer
(`docs/PROJECT_CONTEXT.md`).

**Assigned once, not per step.** The rank is stable but the distance-to-exit is not: two animals
abreast swap order several times a second, and re-sorting every step would hand each one a different
formation slot every frame. That is a cause of exactly the twitching Karen complained about, so the
order is drawn when the sounder forms and redrawn only when the leader changes or a member leaves.

**Rejected: steering by kind.** An alternative was to give cubs a "stay behind mother" steering term
of their own. It was rejected because the sounder already has a formation-slot mechanism
(`SOUNDER.FORMATION` plus `COLUMN_SPACING_STUDS`) that decides where a member stands relative to its
leader -- adding a second mechanism that also decides that is two owners for one fact. The march
order therefore changes **which slot a member holds**, and nothing about how slots work.

## Natural movement: what was measured first

Karen's "like with mouse turning" was measured before anything was changed, in her own place, over
106 s of real crossings (the recorder is in the task's scratchpad; the numbers are in `TASKS.md`):

| | before |
|---|---|
| heading change, walking | **max 688 deg/s**, mean 50-85 |
| heading change, trotting | max 247 deg/s, mean ~47 |
| animals stuck (moved < 1 stud in 5 s while their own speed setpoint asked for movement) | **0** |
| forward probe blocked by something SOLID | 2.2 % of 6328 casts |
| forward probe blocked by ANYTHING, leaves included | 4.3 % of the same |

Three things follow, and two of them contradicted what I expected:

* **The turn rate is the fault.** `Boar.CONFIG.TURN_RATE` is 4 rad/s = **229 deg/s** for every gait,
  and the measured body turns twice that in a sample because an `AlignOrientation` chases a target
  that itself moves every frame. A walking animal turning 688 deg/s is the complaint, exactly.
* **Leaves are not the problem.** I expected the forward probe to be blocked constantly by
  non-colliding foliage in a 1,549-tree wood and for that to be the twitch. It is 4.3 % against
  2.2 %, so leaves roughly double the block rate on a rate that is small either way. The probe is
  still corrected to respect `CanCollide` -- "is something solid in front of me" is the question it
  is asked -- but it is a correctness fix, not the cause.
* **Nothing was stuck for five seconds in 106 s.** Karen saw animals stuck; this measure did not.
  Either it is rarer than one run, or it is shorter than five seconds and the existing stuck
  sidestep recovers it after the player has already seen it. The trunk whiskers are therefore built
  to prevent the *approach* rather than to recover from the wedge, and the before/after number for
  "stuck" is 0 against 0 -- which is honest and is not evidence.

## Numeric targets

| | target | why |
|---|---|---|
| heading change, walking | <= 90 deg/s | the Director's number; a walking pig does not pivot |
| heading change, trotting | <= 140 deg/s | between the walk and the run |
| heading change, running | <= 220 deg/s | close to today's 229, because a bolting animal does swerve |
| heading deadband | 4 deg | below it the animal does not turn at all, which is what kills the wobble on a straight line |
| heading smoothing | 0.35 s | one exponential on the TARGET direction, the same trick `SPEED_SMOOTH_SECONDS` and `YAW_SMOOTH_SECONDS` already use for the same reason: one frame's blend is noise, not an intention |
| whiskers | 35 deg apart, 9 studs long, 55 deg of swerve | 9 studs is ~1.6 body lengths, which is far enough ahead to turn at a walk and not so far that every trunk in a wood is "ahead" |
| stuck | 0 animals | it was already 0; the target is that it stays 0 |
| boar sounds playing at once | <= 3 | Karen: "still to noisy" |
| spook memory | 5 s | the Director's `SPOOK_MEMORY_SECONDS`: a wave released within 5 s of a shot starts running, otherwise it walks in |

## What this note does not decide

* How many females a sounder has. That is `SOUNDER.MAKEUP`, and Karen's "3 males 3 females 3 cubs"
  is a later task.
* Pathfinding on a trunk layer. The whiskers are local steering; `ComputeAsync` already routes the
  leader and the path budget is one route per sounder, which this task does not change.

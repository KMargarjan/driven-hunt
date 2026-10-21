# A deer in every drive, and the deer walk in file

**Task 234, parts 2 and 3.** Karen, 2026-10-21, after playing:

> *"I didnt see deer red tag why ?"* ... *"I want to see a deer"*

> *"we need all a time in drive deer and could be also lines and how they behav"*

and, asked whether she meant deer walking one after another in a row: **"yes"**.

---

## 1. What the system must do

1. **Every drive carries at least one red deer group.** Not "usually". Today the only door is
   `SPECIES.reddeer.RELEASE.CHANCE_PER_RELEASE = 0.2`, rolled per release: about six releases a
   drive, so `0.8^6 = 26 %` of drives carry **no deer at all**, and hers carried none. A
   probability is not a guarantee however high it is set, so the fix cannot be a bigger number.
2. **A deer group moves in SINGLE FILE** -- a leader, and each follower on the leader's trail at a
   measured spacing.
3. **The start card names the deer**, with their real points, and says they need the licence.

---

## 2. Sources

| # | Source | Licence | Maintained | What it gave |
|---|---|---|---|---|
| 1 | [Red Deer Behaviour & Social Structure](https://www.wildlifeonline.me.uk/animals/article/red-deer-behaviour-social-structure), Wildlife Online (Marc Baldwin), reporting the Red Deer Research Group's Isle of Rum study (Clutton-Brock, Guinness & Albon 1982) | editorial, quoted for figures | yes, a live reference site | group sizes and the stag's own company |
| 2 | [Animal Diversity Web, *Cervus elaphus*](https://animaldiversity.org/accounts/Cervus_elaphus/), University of Michigan | ADW terms, cited not copied | yes | matriarchal hind parties, stags solitary outside the rut -- **already the source behind `RELEASE.COMPOSITIONS`** (task 223) |
| 3 | [Reynolds, *Steering Behaviors For Autonomous Characters*](https://www.red3d.com/cwr/steer/gdc99/) and [Boids](https://www.red3d.com/cwr/boids/) | technique, no code taken | the canonical pages, static | leader following -- **already the pattern behind `Boar.CONFIG.SOUNDER`** (task 118) |
| 4 | [*Deer traveling in line?*](https://www.thehuntingbeast.com/viewtopic.php?t=37425), The Hunting Beast forum | a forum thread, weighted as practice and not as science | a live forum | why a file forms: *"the alpha doe takes the lead while others follow"*, *"the followers feel safe behind the leader"*, and *"making defined trails ... makes for easier walking"* |

### What each does well and badly

**Source 1** gives the one number worth having: *"the median hind party size on Rum was seven
individuals in summer and five during the winter"*, and *"only 10% to 20% of mature stags
associated with hinds outside the rut"*. It is a careful account of a long study. It says
**nothing about how a party moves on the ground**, which is the half this task needs.

**Source 2** is the account `RELEASE.COMPOSITIONS` was already built from, and nothing here
changes it: a stag alone (40), a hind with her calf (40), a stag holding hinds (20). Re-reading it
for this task changed no weight, which is the honest outcome to report.

**Source 4** is a hunters' forum, and it is cited AS a forum: it is the only source found that
says plainly why deer string out, and all three reasons it gives are about the same thing -- a
leader who chooses the route and followers on her trail. That is exactly the `"column"` formation
this repo already has. **It is not evidence of a spacing**, so the spacing is not taken from it.

**Nothing new is invented here, and that is the finding.** Both halves of part 2 are already
built: the drive has a release schedule with a per-drive budget (`Match.Phase`), and the sounder
has a `"column"` formation with a leader, march order and a slot spacing (`Boar`, task 118/123).
What is missing is that nothing ever ASKS for either on behalf of the deer.

---

## 3. The pattern adopted

**(a) The guarantee belongs to the SCHEDULE, not to the dice.** `Match.Phase` is the one thing
that knows a drive is a drive: it holds `boarsReleased`, `soundersReleased` and
`BOARS_PER_DRIVE`, it is reset at the drive's start, and it already emits the `spawnSounder`
effect. The Boar runtime cannot own this -- `MatchBoot` builds **one runtime for the whole
server** and it outlives every drive, so it has no drive boundary to latch against.

So `Phase` marks **exactly one release of each drive** as the drive's deer release
(`Phase.deerRelease`, pure), the effect carries `deer = true`, and the runtime's chance roll is
skipped for that one. Which release it is comes from the drive's own seed, so it is not always
the first; and if the drawn ordinal is never reached, **the drive's LAST release carries it**,
which is what makes it a guarantee rather than a better chance. The latch
(`State.deerReleased`) is handed back with the release by `Phase.releaseFailed`, exactly as the
sounder and the boar budget already are.

`CHANCE_PER_RELEASE` is left at Karen's 0.2 and still decides the EXTRA, unscheduled deer: one
guaranteed group plus about 1.2 more by chance, so a drive now averages about 2.2 deer groups
(~4 animals) against 6 boars. If that is too many for an animal she called rare, it is one
number.

**(b) The file is the formation this game already has.** `SOUNDER.FORMATION`'s wedge and
`"column"` are drawn per sounder at `COLUMN_CHANCE = 0.5`; `_assignMarchSlots` puts members in
`Boar.marchOrder` (which already ranks `hind = 1, calf = 2, stag = 3`, task 223) and the column
slots are `(0, 0, (i-1) * COLUMN_SPACING_STUDS)` in the leader's frame. A deer group simply
**declares its formation** (`SPECIES.reddeer.RELEASE.FORMATION = "column"`) instead of drawing
one, and `Boar.compositionFormation` is the one pure function that answers it. **No second
movement writer**: the steering, the slots and the leader stay exactly where they were.

The draw is still MADE and then overridden rather than skipped, because skipping it would move
`self._rng`'s stream and change every formation and `phase` drawn after it -- the exact defect
task 223's round 1 shipped and its review caught.

**The spacing is the sounder's own `COLUMN_SPACING_STUDS = 9`, and that is a measurement, not a
reuse by laziness:** the three deer were measured at `stag 7.05, hind 6.03, calf 3.49` studs long
(`Boar.CONFIG.KINDS`, prepped 2026-10-20), so 9 studs leaves the longest of them about two studs
of daylight to the animal in front. A smaller gap would have a stag's nose inside the hind ahead
of him.

**(c) The start card names the deer from ONE home.** The points are already
`Match.CONFIG.POINTS.KIND` (`stag 20, hind 6, calf -10`, task 223) and the licence rule is already
`Licences.ROWS.reddeer` (`licence = true`, label `RED DEER`). Neither is copied: `Match.QUARRY`
gains a row naming the SPECIES KEY, `Match.quarryRows` resolves the label and the licence through
`Licences`, and the client draws what the wire sent -- the division task 158 set and
`startcard-spec.md` restates.

**The Designer's four-row ceiling is raised to eight, and it is a real cost.** `startcard-spec.md`
section 1.4 says *"ONE IDEA PER LINE, AND FOUR LINES IS THE CEILING for a three-second read"*.
Seven quarry rows plus the person row cannot be a three-second read, and the alternative -- leaving
the deer off the card -- is the defect Karen reported. The card's height stops being a measured
constant and becomes `chrome + rows * rowH`, so a beater's four-row card is EXACTLY the card he
has today and only the hunter's grows. **A licensed species gets a head row** (`RED DEER`, with
the amber `NEEDS LICENCE` tag the beater's first row already uses) and an unlicensed one does not
-- because `Male boar` / `Female boar` / `Piglet` name their animal in the words and `Stag` /
`Hind` / `Calf` cannot. That is the rule, it is generic over any future licensed species, and
whether eight rows is still a card is the Designer's call: it is reported, not smuggled.

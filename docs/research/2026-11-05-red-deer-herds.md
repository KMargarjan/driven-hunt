# Red deer herds of five to eight, in one row (task 328z)

**Karen, 2026-11-03 ~11:20 UTC**, after playing C1 in her Forest Test: *"rest is ok and could be
more red stags they also run in bundle like 5 8 one row ect like in life"*. And her earlier,
simpler model (task 127): *"imagine they come from one side in one line and crossing road thats
it"*.

This note stands on `2026-10-21-deer-in-every-drive.md` (how often a deer comes) and
`2026-10-05-sounder-march-order.md` (the order a group marches in). Neither asked what a red deer
group is made of or how big it is, because until now it was one to three animals.

## 1. What the system must do

1. A red deer release is a **group of five to eight animals**, with a stag in most of them, built
   only from the three kinds this game already has (`stag`, `hind`, `calf`) -- no new asset.
2. They cross the road in **one row**: every follower on the leader's own trail, a natural
   centre-to-centre spacing, lateral offset small enough that a hunter reads one file and not a
   blob.
3. **More red deer per drive than before** -- the frequency, not just the group size.
4. A shot runs the file **on forward**, never back (task 127's rule), and nothing stands still for
   three seconds (task 328n's sampler).
5. Inside the existing animal ceiling and the existing frame budget.

## 2. Sources

| Source | What it is | Licence | Maintained |
|---|---|---|---|
| **Wildlife Online -- "Red Deer Behaviour & Social Structure"** <https://www.wildlifeonline.me.uk/animals/article/red-deer-behaviour-social-structure> | A referenced popular-science account of the Isle of Rum long-term study (Clutton-Brock et al.) | All rights reserved; **quoted, not copied** | Live site, dated articles |
| **Animal Diversity Web -- *Cervus elaphus*** <https://animaldiversity.org/accounts/Cervus_elaphus/> | University of Michigan Museum of Zoology species account | CC BY-NC-SA 3.0 | Live, curated |
| **Jarnemo & Wikenros 2014, "Movement pattern of red deer during drive hunts in Sweden"**, *Eur J Wildl Res* 60:S77-S84 <https://link.springer.com/article/10.1007/s10344-013-0753-4> | GPS-collared red deer measured **during drive hunts** -- this game's exact situation | Paywalled; abstract quoted | Published, cited since |
| **"Energy saving mechanisms, collective behavior and the variation range hypothesis"** <https://arxiv.org/pdf/1606.08969> | Review that collects the single-file / drafting evidence for ungulates (caribou) | arXiv, CC BY | 2016, not updated |
| **Reynolds, "Leader Following"** <https://www.red3d.com/cwr/steer/LeaderFollow.html> | The steering pattern this game already implements | Author's reference page, quoted | 1999, stable reference |

### What each does well and badly

* **Wildlife Online** is the only source that gives a **group-size number with a study behind it**:
  *"the median hind party size on Rum was seven individuals in summer and five during the winter"*,
  and for bachelor groups *"the median group size of stags in the summer months was seven
  individuals, declining to groups of four during the winter"*, with the overall range *"anywhere
  from four animals to in excess of one hundred"*. Badly: it is a secondary account, so the figures
  are quoted at one remove, and it says **nothing about travelling formation**.
* **ADW** is the authority this repo already uses for *Cervus elaphus* social structure -- hinds and
  calves in matriarchal groups, stags solitary or in bachelor groups outside the rut. Badly: no
  numbers for spacing.
* **Jarnemo & Wikenros** is the right *situation* (a drive hunt, dogs, GPS): median flight distance
  2.5 km for hinds over 46 flights, 5.1 km for stags over 8. Badly: it measures kilometres of
  flight, not metres between animals -- it tells us the animals **leave**, which is what this
  game's crossing already does, and nothing about the file.
* **The energy-saving review** is the only source that explains *why* a file forms at all:
  caribou travel single file and followers place their feet where the animals ahead already broke
  the snow, so the leader pays the cost and the followers draft. Badly: caribou, not red deer, and
  the mechanism is snow -- which this map has none of.
* **Reynolds** is the pattern, not the animal, and it is already the adopted one (task 127).

### The negative result, stated rather than hidden

**No source found gives a measured inter-animal distance for a travelling red deer file.** The two
behavioural-synchrony papers that come closest -- Rands, Muir & Terry 2014 (*PeerJ* 2:e344, CC BY
3.0) for red deer and Hoyle, Miller & Rands 2021 (*BMC Ecol Evol*, CC BY 4.0) for fallow deer --
were both fetched, and both are **topological, not metric**: they rank the *"first, second and third
closest individual"* and estimate proximity by *"observable body lengths ... visually compared by
observers"*. So the field's own unit for deer spacing is the **body length**, and there is no
published metre figure to borrow.

## 3. The pattern adopted, and why

**Group size: the Rum medians, as declared compositions.** Five to eight is not a guess -- it is
exactly the band Wildlife Online reports (hind parties 5 in winter, 7 in summer; stag groups 4 to
7). So the three red deer `COMPOSITIONS` rows become four, every one of them a shape ADW names:

| Row | Animals | Real-life shape |
|---|---|---|
| `hinds` | hind x3, calf x2 = **5** | the matriarchal party, Rum's winter median |
| `harem` | stag x1, hind x4, calf x2 = **7** | a stag with hinds, Rum's summer median |
| `stags` | stag x6 = **6** | a bachelor group, inside Rum's 4-7 |
| `stag` | stag x1 = **1** | the solitary mature stag (ADW), kept because it is the drive's one scripted trophy and the row the lone-party rule is written against |

**Spacing: nothing is retuned, and the measurement is why.** The field's unit is the body length,
and this game already set its file spacing that way and measured it: `Data.LINE.spacingStuds = 8.5`
centre to centre for a 5.5-stud body -- a three-stud nose-to-tail gap -- with the alternative (6.5)
tried in task 136 and measured no better. `SOUNDER.COLUMN_SPACING_STUDS = 9` is the sounder path's
twin. **Borrowing beats inventing (rule 2), and the thing to borrow here is this repo's own
measurement.** What changes is the number of animals standing on that spacing, so what this task
measures is whether the file still holds at seven.

**Frequency: raise the dial, let the live cap throttle.** `CHANCE_PER_RELEASE` 0.2 -> 0.5 (a group
in at least every second release on the drive path) and the Forest Test script carries deer in six
of its fifteen slots instead of two. `MAX_GROUPS_ALIVE` 1 -> 3, because one group at a time cannot
deliver a group every second wave at any chance, and a refused deer slot releases **nothing** --
a hole in the drive rather than fewer deer.

**Formation: unchanged, by design.** `RELEASE.FORMATION = "column"` and `Boar.MARCH_RANK`
(hind 1, calf 2, stag 3) already declare one file with a hind in front. A hind leading is the
matriarchal fact ADW gives, so "a stag-led group" is read as *a group with a stag in it*, not as a
stag at the head. Changing the march order is a design row, not this task's.

## 4. The numeric targets

| What | Before (measured) | Target |
|---|---|---|
| red deer group sizes available | 1, 2, 3 | **5, 6, 7** and 1 (the lone stag) |
| red deer per Forest Test drive | 3 | **>= 20** |
| deer slots in the Forest Test script | 2 of 15 (13 %) | **6 of 15 (40 %)** |
| deer releases on the drive path | 1 guaranteed + 0.2/release | 1 guaranteed + **0.5/release** |
| centre-to-centre gap in the file, at the road | no reading possible (never 2 deer at once) | **8.5 studs** +- 3, median |
| lateral offset from the leader's trail | same | **<= 2.5 studs** median (a body width) |
| animals stuck >= 3 s | 0 | **0** |

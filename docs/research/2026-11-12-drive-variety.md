# Every drive a different pattern (Task 351)

2026-11-12. Builder. For `src/shared/ForestTest` (the drive's own owner). No design file is mine on
this task (the dispatch: *"NOT YOURS: docs/design/"*), so the Director's decisions in the dispatch
are the design this note is written against.

KAREN, 2026-11-12 ~08:20 UTC, verbatim:

> *"patterns needs to be diffret for each drive could be singles groups different count of groups
> and mixes (do not mix different animals)"*

## 1. What the system must do

Today `ForestTest.SCHEDULE.drive` is ONE fixed script of fifteen slots. Slot 1 is always *"the first
mover: one big lone male"*, slot 9 always *"the big herd"*, slot 15 always *"THE ONE THAT STAYS"*.
`ForestTest.slotAt` reads that table by index, so every drive of every session plays the same story
in the same order. The density dial (`quiet` / `normal` / `busy`) changes HOW MANY of those fifteen
rows fire; it cannot change WHICH animals they are, how big the groups are, or what order they come
in.

It must instead, behind a flag:

1. generate the slot list PER DRIVE from a seed (drive number + cell + server seed), so two drives
   in a row are recognisably different: a different mix of singles and groups, different group
   sizes, a different number of groups, from different sides;
2. keep every group ONE SPECIES -- a boar sounder is boars, a red deer party is stag/hind/calf --
   with singles of either species allowed. Karen's own parenthesis: *"(do not mix different
   animals)"*;
3. keep the SHAPE of a drive: early movers, a build-up, the last runners, and the special acts
   (break-back, split, hold, the red stag) appearing SOMETIMES rather than every drive;
4. invent nothing: the parties, the routes, the depths, the crossings and the paces are the ones the
   shipped script already uses (rule 2);
5. be PURE: same seed -> same drive, different seeds -> different drives, both asserted by spec;
6. keep the action task 349 measured (first sighting, gap, released, peak live) within the
   dispatch's band, so a varied drive is not a worse drive;
7. be OFF by default, and OFF must be today's drive BYTE FOR BYTE.

### Numeric targets

| What | Target | Why |
|---|---|---|
| Groups at `normal` | 9-13, and not the same count two drives running | base is 13; the count must VARY and must not rise (`MAX_DEER_GROUPS`, `MAX_BOARS` 60) |
| Singles per drive | 0-3 | the dispatch's own number |
| Species per group | exactly 1 | Karen: *"do not mix different animals"* |
| Specials per drive | each at most 1, and 0-4 of the four | the dispatch: *"sometimes, not every drive"* |
| Deer groups per drive | 1 to the base's own count (7 at `normal`), never above it | `MAX_DEER_GROUPS` 40 is *"past every deer this script can have on its feet at once (39)"* and that 39 is the script's own seven deer rows at `normal`; more deer parties would risk the cap refusing a slot, which releases NOTHING |
| Animals released | within +-10% of the fixed script at the same density. **MEASURED, not quoted: the base at `normal` is 13 groups, 73 animals, 7 deer parties** (`<runs-dir>/351-gen-probe.luau`, through `Boar.compositionSize`), so the band is 65..81. The 59 / 2 deer in the `SCHEDULE` header is stale -- that header's own note says the counts above its `leaps` line are task 251's | the dispatch allows 15%; 10% is the generator's own band, so the measured figure has headroom |
| First sighting | <= 30 s | task 349's action, kept |
| Median gap between sightings | <= 20 s | task 349's action, kept |
| Peak live | within 15% of the fixed script | the dispatch; measured fresh, because `TASKS.md` row 349 recorded -21% and deferred it |
| Same seed twice | identical row list, field for field | spec |
| Two consecutive drives | a different row list | spec, over the seeds `driveSeed` actually produces |

## 2. Sources

### 2.1 Dungeon Crawl Stone Soup, `mon-pick.cc` -- a weighted pool filtered by a band

<https://github.com/crawl/crawl/blob/master/crawl-ref/source/mon-pick.cc>
GPL-2.0-or-later (the `crawl/crawl` repository's own licence). **Actively maintained** -- the file is
on `master` of a repository with continuous release activity since 2006.

`pick_monster_all_branches()` walks a population table, skips every entry whose band does not hold
the depth (`if (depth < pop.minr || depth > pop.maxr) continue;`), accumulates each survivor's
rarity, and then draws:

> `totalrar = random2(totalrar); for (int i = 0; i < nvalid; i++) if ((totalrar -= rarities[valid[i]]) < 0) return valid[i];`

**Does well:** the shape of the answer. A pool plus a band plus one weighted draw is all that
"this level's monsters are not last level's" needs, and it is ~20 lines. The band is what stops a
deep monster appearing shallow -- which is exactly this drive's act I / act II / act III problem.
**Does badly:** no pacing and no budget. Nothing in it says "the level builds up"; the draw is
per-monster, so a *group* and its size are not expressible at all; and nothing bounds the total.

### 2.2 Cataclysm: Dark Days Ahead, monster groups -- a group IS a species with a pack size

<https://docs.cataclysmdda.org/JSON/JSON_INFO.html> (Monster Groups), data in
<https://github.com/CleverRaven/Cataclysm-DDA/blob/master/data/json/monstergroups/>
Docs **CC BY-SA 3.0** (stated at the foot of the page); the code is GPL-3.0. **Actively maintained.**

A `monstergroup` entry carries, documented by those names: `weight` (*"Chance of an item spawning is
x/T, where X is the value linked to the specific item and T is the total of all item values in a
group"*), `pack_size` (how many are spawned -- a single number or a range), `cost_multiplier`
(*"How many monsters each monster in this definition should count as, if spawning a limited number
of monsters"*), and the conditions `time` and `season`.

**Does well:** it is this task's data model almost exactly. One entry = one species + a pack-size
range + a draw weight, and `cost_multiplier` is a BUDGET: the game asks for 50 zombies and four
brutes at multiplier 15 spend it. That is the answer to "the number of groups varies but the drive
must still release about as many animals". **Does badly:** no arc. A CDDA spawn is a place, not a
performance, so nothing in it orders the groups or holds one back for the end.

### 2.3 Valve, the Left 4 Dead AI Director -- the four-beat arc

Michael Booth, GDC 2009: *The AI Systems of Left 4 Dead*
<https://steamcdn-a.akamaihd.net/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf> and *Replayable
Cooperative Game Design: Left 4 Dead*
<https://cdn.fastly.steamstatic.com/apps/valve/2009/GDC2009_ReplayableCooperativeGameDesign_Left4Dead.pdf>.
Proprietary (published conference slides, no licence to reuse code -- only the idea is borrowed).
Maintenance: not applicable, 2009 slides; the game itself is still shipped.

**MEASURED, not assumed: both PDFs are image-only.** Each renders to a fetcher as JP2 image data
with no extractable text, so the four state names below are taken from secondary descriptions of
the same system (an L4D2 director-research repository and published analyses) rather than quoted
from Valve's own page. The arc is: **Build Up** (spawn until the survivors' intensity crosses its
peak) -> **Sustain Peak** (hold it a few seconds) -> **Peak Fade** (spawn less while intensity
decays) -> **Relax** (a minimum threat for 30-45 s) -> Build Up again.

**Does well:** it names the thing the fifteen-slot script already has by hand -- act I, act II,
act III -- and says why a generated population must keep it: a random population with no arc reads
as noise. It is also the source of "the same level plays differently twice", which is Karen's
request. **Does badly:** it is a continuous controller reading live player state, which this drive
is not and must not become -- a drive here is a fixed metronome of fifteen slots whose timing
`forest_line.spec` asserts. Adopting the controller would mean rewriting the release path; adopting
the ARC costs nothing, because the arc is already in the table.

### 2.4 Real life -- a Drueckjagd is singles AND groups, several species

<https://purewild.de/Glossar/Drueckjagd/> (editorial glossary, read 2026-11-12). Not a licence
matter; cited as a statement of fact.

> *"Wildschweine leben in Rotten, stehen tagsueber in dichten Einstaenden und lassen sich einzeln
> kaum planbar bejagen"* -- boar live in sounders and lie up by day in thick cover; and
> *"Auch Rotwild, Damwild und Rehwild werden regelmaessig bejagt"* -- red, fallow and roe deer are
> taken on the same drives.

A second German glossary of the same kind puts the mix plainly: at a Drueckjagd boar come out of the
thicket *"meist in kleinen Gruppen oder Rotten, oft aber auch als Einzeltiere"* -- mostly in small
groups or sounders, but often as single animals
(<https://jagdwelten.de/jagden/drueckjagden/>). That is Karen's sentence from the other side: a
drive is a MIX of singles and groups, and which it is this time is not scripted.

The repository's existing real-life sources stay in force and are not re-derived here: the PLOS ONE
driven-hunt study's *32 % that stay put* (the row that HOLDS) and the Livingactive *Tipps und Tricks
fuer die Drueckjagd* observation that the noise of arrival moves the experienced animals first
(act I starting before the beaters), both already quoted in `src/shared/ForestTest/init.luau` above
`SCHEDULE`.

## 3. The pattern adopted, and why

**A seeded weighted draw from the shipped script as a POOL, inside the script's own arc, closed by
an animal budget.** In one sentence: 2.1's band-filtered draw, over 2.2's one-species-plus-pack-size
entries, arranged by 2.3's arc, with 2.2's `cost_multiplier` idea as the budget.

Concretely (`ForestTest.generateDrive`, pure):

1. **The pool is the fifteen shipped rows**, partitioned by what they are: ORDINARY rows by act
   (2.1's band -- an act I slot may only take act I geometry, so a far-wood group can never be
   released 85 studs from the road), and SPECIAL rows by their act name (BREAK-BACK, SPLIT, HOLD,
   SNEAK). Nothing is invented: a generated row's depth, side, crossing, files, pace and route are a
   shipped row's, and its party is a shipped party.
2. **The vocabulary is read off the pool**, not written down twice: the boar composition indices the
   script uses and the deer party names it uses, each split into SINGLES (weighing one animal) and
   GROUPS (more). The weigher is INJECTED (`weigh(species, key)`), because how many animals a
   composition is belongs to the animal's owner (`Boar.compositionSize`) and not to the drive --
   rule 3, and the same seam `Placement.luau` already uses for `slotAt`.
3. **The draw, per drive, from one `Random.new(seed)`**: which specials appear (each about half the
   time, so *"sometimes, not every drive"*), how many slots fall silent, how many singles, and then
   per carrying slot a species and a party. Roblox's own seeded `Random` is the generator -- nothing
   home-grown, and `Random.new(seed)` is deterministic, which is what makes the function pure.
4. **The arc is kept by construction.** Fifteen slots, the same metronome, the same acts; slot 1
   always carries (the early mover) and two silences are never adjacent, so the drive still opens
   early, builds, and ends with the last runners.
5. **The budget closes it** (2.2's `cost_multiplier`): after the draw, the animals that will
   actually fire are weighed and compositions are walked up or down the size ladder until the total
   is inside +-10 % of what the fixed script releases at the same density. A varied drive is a
   different drive, not a smaller one.
6. **The dial keeps its exact meaning.** `keepAt` is assigned by rank -- the first nine carrying
   slots 9, the next four 13, the rest 15 -- so `quiet` still fires nine groups and `normal` at most
   thirteen, and `ForestTest.slotAt` is not touched at all.

### What was NOT adopted, with the reason

- **A live intensity controller** (2.3's own mechanism): it would replace the fifteen-slot metronome
  that `forest_line.spec` and `bots_lane.spec` both assert, and Karen asked for different PATTERNS,
  not adaptive difficulty.
- **A new composition table.** Rule 2, and the shipped script's own sentence: *"not one new
  composition is invented"*. Sizes vary by drawing the script's existing compositions, never by
  writing a new one.
- **Per-row weights in the table** (2.1's `rarity`, 2.2's `weight`). A sixteenth field on fifteen
  rows, tuned by nobody, to express a preference nobody has stated. The draw is uniform over the
  pool until Karen says a shape is too rare.
- **Varying the slot count or the slot clock.** 10 s + 13 s x 14 is measured against the beater
  line's own walk (`bots_lane.spec`); a generated drive that also moved its clock could not be
  compared with the fixed one at all.

## 4. What this note does not answer

- Whether a varied drive FEELS more varied is Karen's to judge; this note's targets are countable
  ones.
- The flag's default stays OFF. Flipping it is a later three-line commit after she plays it.

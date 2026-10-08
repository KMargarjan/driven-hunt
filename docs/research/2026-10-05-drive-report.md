# The drive report: showing a hunter where his shots landed, and how he did against the others

2026-10-05, Task 124. Karen, after playing the Forest Test:

> "we need to show when is killed logg or something similar / we need to indicate a hit / and we need
> to show on the end what has been killed where was the hit / so after drive we can see how much I
> killed compairing others and I can click on details or similar and see boars where was the hit /
> something simple but cool"

## What the system must do

1. **Say "that hit"**, instantly, to the shooter only — and say it differently when the animal died.
2. **Say "X killed a Y"** to everybody, briefly, while the drive runs.
3. **At the end of a drive, show every hunter side by side**, sorted, so Karen can see how she did
   against the others; and let her open ONE hunter and see each animal with **where every shot
   landed on it**, how far away it was, and whether it died or was lost wounded.
4. **The server is the only author.** A client that can write its own kills is a client that can
   invent them, and this data is also the score.

## Sources

| Source | What it supports | Status |
|---|---|---|
| [theHunter: Call of the Wild wiki — Harvest Screen](https://thehuntercotw.fandom.com/wiki/Harvest_Screen) (Fandom, CC BY-SA 3.0) | The **genre's standard post-kill screen**: *"The player can cycle through all the shots that impacted the animal to see more details such as the percentage of total damage done by the shot or organs and bones that were hit. Also, the used weapon, ammunition, shot distance and the obtained weapon score will be displayed."* One animal, a list of shots, each shot carrying where it landed and how far away it was | Live. **Read through search extracts: the page itself answered HTTP 402 to a fetch**, so this is quoted from the extract and not from the page |
| [Way of the Hunter — damage model and bullet-cam thread](https://steamcommunity.com/app/1288320/discussions/0/4691153988129135177/) (Steam, fetched and quoted) | The **richest version of the same idea, and why we are not building it**: a 3D model with the bullet's path, organ-by-organ energy bars, penetration split from cavitation, thresholds in joules (*"a Red Deer lung requires approximately 600 joules ... the heart needs around 75"*), and *"only organs where the bullet actually penetrated the organ are indicated on the energy graph"* | Live, fetched |
| [Hunting Simulator 2 — "No multiplayer?"](https://steamcommunity.com/app/1135910/discussions/0/2567564692475501394/) and [thexboxhub review](https://www.thexboxhub.com/hunting-simulator-2-review/) | **A NEGATIVE RESULT, and the most useful one.** It is single-player: there is no kill summary and no scoreboard, and the series' own co-op was dropped. So the thing Karen actually asked for -- *"how much I killed compairing others"* -- is **not** a solved pattern in hunting games; the hunting sims show YOUR animal, not a table of hunters | Live |

Nothing here is code or art; these are design claims, cited. No licence attaches to a citation. The
Fandom wiki's text is CC BY-SA 3.0 and **none of it is copied into the game** -- the quote above
lives in this note only.

## What each source does well and badly

* **theHunter's harvest screen** is the right shape for the "details" half of Karen's ask: one
  animal, every shot that hit it, each with a place and a distance. It is also **modal and slow** --
  it interrupts the hunt for one animal at a time, which is wrong for a driven hunt where six
  animals cross in a minute and the shooting does not stop. We take the SHAPE and not the moment.
* **Way of the Hunter** is the most informative and the least buildable here. A 3D model, a bullet
  path and per-organ energy bars need a ballistics model we do not have (`Boar.CONFIG.WOUND` is
  damage points per zone, not joules) and a rig we would have to author. Its real lesson is the one
  the thread states plainly: **show only what the model actually knows.** Its own players complain
  about organs that are drawn but not simulated, and a silhouette that promises a liver we never
  simulate would earn the same complaint.
* **Hunting Simulator 2** tells us the comparison table has to be designed rather than borrowed from
  this genre. The nearest honest reference is the ordinary competitive **scoreboard**: name, a count,
  a score, sorted, one row each, with a detail view behind a click.

## The pattern adopted, and why

**A record of hits owned by the server, drawn two ways.**

1. **`HitLog`, a server module with one writer.** It already has a feed: `Weapon.HitReported` fires
   per (shot, target) and `Boar.Runtime.Downed` fires per death. `HitLog` subscribes to both and
   keeps, per animal: its kind, and one row per hit -- shooter, zone, **the impact point expressed in
   the ANIMAL's own frame**, distance, time, and whether that hit was the fatal one. Nothing else in
   the game may write it, and the client is never asked what it hit.

   *The animal's own frame* is the decision that makes the silhouette possible at all. A world
   position is useless once the carcass has been despawned; `CFrame:PointToObjectSpace(impact)` at the
   moment of the hit is a number that still means "high on the shoulder" an hour later.

2. **Two client views over one replica.** A short-lived `HitMarker` (which already exists) and a feed
   line for the kill log; and a panel that reads the same table at the end of the drive. No second
   score: `Match` already owns points and penalties, and the report shows what `Match` says plus the
   placement `HitLog` adds.

**Rejected: a 3D model with a bullet path.** Way of the Hunter's screen is the best in the genre and
is out of scope for "something simple but cool": it needs a ballistics model we do not have. A flat
**side-view silhouette with a dot per hit** carries the one fact we do model -- which zone, and
roughly where on the animal -- and carries it honestly.

**Rejected: a modal harvest screen per animal.** theHunter stops the hunt to show you one animal.
A driven hunt cannot stop; the hit marker and the kill-log line carry the moment, and the detail
goes to the end.

**Rejected: drawing organs we do not simulate.** The zones this game models are exactly
`head`, `chest`, `body`, `legs`, `rear` (`Boar.CONFIG.WOUND.DAMAGE`). The silhouette is divided into
those five and no more, and the report's words come from the same table, so the picture cannot
promise a liver the damage model has never heard of.

## Numeric targets

| | target | why |
|---|---|---|
| hit marker on screen | ~0.35 s hit, ~0.8 s kill | long enough to read in peripheral vision, short enough not to sit over the next animal |
| kill-log lines | max 4, each ~6 s | Karen's "something simple"; four is one glance |
| report opens | end of drive, and on **Tab** any time | the Forest Test has no drive end, so it gets a drive length in data AND a key |
| Forest Test drive length | 5 minutes | the Director's number: ~15 waves at a 20 s interval |
| hits kept per animal | all of them | a shotgun's nine pellets are one hit record per (shot, target), not nine: `Hits.group` has already grouped them |
| silhouette zones drawn | 5 | exactly the zones `WOUND.DAMAGE` has rows for |
| report render | one screen, no scrolling at 1920x1080 for 8 hunters | Karen: "Clean, readable, one screen" |

## What this note does not decide

* The penalty rules (shooting a cub, shooting toward a driver). `Match` owns those and the report
  only displays what it already records.
* Trophy scoring, meat weight, or anything else the genre's sims show: this game has no such model,
  and inventing one to fill a panel is the mistake Way of the Hunter's own players describe.

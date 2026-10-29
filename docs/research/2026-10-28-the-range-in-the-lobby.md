# The range moves to the lobby: six isolated stations, two distances, ground or treestand

Task 306, phase A. Written 2026-10-28. Companion to
[2026-10-27-shooting-range.md](2026-10-27-shooting-range.md), which researched the range task 298
built; this note researches **moving it, multiplying it, and making each man's target his own.**

The raw source sweep, with every link and every "GUESS" marked, is
`<runs-dir>/research-306-references.md` (outside the repo, the Director's, 2026-10-28). This note is
the decision: what was taken from it, what was refused, and the numbers.

---

## 1. What the system must do

Karen, 2026-10-28 ~10:15 UTC, verbatim:

> "then I want that you move shooting range in lobby / people don't have to walk far / and there has
> to be accessable for many people so they can shoot anytime / so I think there will be several
> places where they can click E and then become isolated view (not many animals and everyone
> shooting what they see) but one person sees animal and menu and settings but can many play you
> understand probably / and when I say close to lobby that means front of shop house there could be
> clean space and then shooting range and make nice shooting range clean proper like in real life
> and behind animal could be a mountain not high but like in real life they have eather mountain or
> some earth formed mountain / so outsource how it looks / also we can make an option shoot from
> treestand so they can shoot from ground or treestand"

Seven requirements, each with its own measurable:

1. **Near the lodge.** Today the mat is at `(2650, 141.5, -3216)` in her place, **268 studs** from
   the lobby anchor and a **25.7 s** walk (`evidence/p298/walk-after.txt`). Target: 20 s or less.
2. **Many men at once.** Today `Range.LAYOUT.SPOT_COUNT = 1` and `CONFIG.MAX_TARGETS = SPOT_COUNT`,
   so one lane, one target, one shooter. Target: **6 stations**, all usable simultaneously.
3. **Isolated view.** Today the target is a server-owned `Boar` runtime instance in
   `Workspace.RangeTargets` -- replicated, so every player in the lobby sees every other man's
   animal. Target: a man at station *n* sees **his** animal, **his** menu, **his** board, and no
   other station's animal.
4. **A real-looking range.** Distances, window, speeds, bench, firing hut, berm -- sections 2, 5.
5. **An earth berm behind the animal**, "not high", "like in real life".
6. **Ground or treestand**, chosen at the station.
7. **The old forest range retires** (the Director's decision; `reviews/task-306/BRIEF.md`).

### What it must NOT do

- It must not score, pay, count a hunt, or write a `HitLog` row -- task 304's rule. It **does** send
  the hit card (task 304), because that is what she asked for.
- It must not become a second shooting path. Task 305's rule is binding: **the shot hits what the
  shooter saw**, resolved through `Weapon.Rewind` / `Cast` / `Flight`'s carried `rewindSeconds` and
  the per-runtime history provider `RangeBoot` already registers. No second resolution.
- It must not put an animal, a shot or a prompt inside the lobby's own rules (section 4).

---

## 2. Sources: real running-target ranges

Nine sources were read. Five carry numbers this design uses.

| # | Source | What it is | Licence / status | Good | Bad |
|---|---|---|---|---|---|
| A | [BSRC Time Limit Range](https://bsrc.co.uk/time-limit-range/) + [50 m Running Boar normal runs (PDF)](https://bsrc.co.uk/wp-content/uploads/2023/01/50m-Running-Boar-Normal-Runs.pdf) | Bisley's own running-boar range, quoting the ISSF spec | club web page, text (c) BSRC -- **reference only, nothing copied**; live and maintained (2023 PDF) | Every number this design needs in one place: 50 m, 10.00 m window, 5.0 s / 2.5 s, target centre 1.4 m, bench 0.7-0.8 m. Describes the **mechanism**: trolley on a rail, a **parapet** hiding the rail, the motor in the butt, a **firing hut** with two bays and a red light per bay | Second-hand for the ISSF rulebook -- the rulebook itself could not be retrieved. Sport, not hunting: no berm height |
| B | [Wikipedia 50 m running target](https://en.wikipedia.org/wiki/50_meter_running_target) + [mixed](https://en.wikipedia.org/wiki/50_meter_running_target_mixed) | the ISSF event | **CC BY-SA 4.0**; current | Confirms A's distance, window and both times independently. Gives **"mixed"**: slow/fast randomised and *not announced* | No construction detail |
| C | [Wald und Holz NRW Uebungsnachweis (PDF)](https://www.wald-und-holz.nrw.de/fileadmin/Publikationen/Broschueren/Broschuere_Jagd_Uebungsnachweis_Bedingungen.pdf), [recht.nrw.de Anlage 2 (PDF)](https://recht.nrw.de/system/files/BHA/22168-31425-sgv_792_20100331_2_anlage2.pdf) | the legal yearly proof a German driven-hunt shooter must pass | German state law / official brochure; current | **Hunters', not sport**: running boar from the right at **48-62 m**, standing freehand, 5 shots, pass = 5 of 9 hits. This is the band a *hunting* range should sit in | No geometry of the installation |
| D | [Jaegareforbundet Vildsvinspasset (PDF)](https://gava.jagareforbundet.se/globalassets/documents/jaktskytte/vildsvinspassetny5juli_2016.pdf), [seminar (PDF)](https://jagareforbundet.se/contentassets/be71799f06f141eeabf2abf0ed9af2e7/skytteseminarie_bjornpass_vildsvin_algtavla_om_17.pdf) | the Swedish boar proficiency test | Swedish hunters' association, official; 2016-2017, still the published test | A **second, shorter** hunting distance: running boar at **30 m**, using *half* the moose-range opening, with a hunting-style rest. This is where the 30 m station comes from | 2016; no berm or hut dimensions |
| E | [BSRC Running Deer](https://bsrc.co.uk/running-deer/), [Aland moose protocol (PDF)](https://regeringen.ax/sites/default/files/attachments/protocol/nr2-2023-enskild-n4a.pdf), [SvSF viltmal 80 m (PDF)](https://www.skyttesport.se/media/muaf0ucu/bilaga_1_viltmal_80m-2.pdf) | the long running-game ranges | club / government / federation; current | The rule all of them share, and the one this design borrows hardest: **the animal is hidden behind cover at both ends and is already at full speed before it enters the gap** (BSRC: at full speed 0.5 s before it appears; SvSF: horns visible 1-2 s first). A window is a *gap between two banks*, not a lane with open ends | 23 m windows at 80-102 m -- too long for us |

**Refused.** The NRA *Range Source Book*'s 6 m impact berm and 8-12 ft side berms reach us only
through two forum quotes ([one](https://www.migunowners.org/forum/archive/index.php/t-259873.html),
[two](https://www.migunowners.org/forum/archive/index.php/t-89086.html)) and the sources disagree
with each other; the German *Schiessstandrichtlinien* has a section on baffles and bullet traps
([umwelt-online index](https://umwelt-online.de/recht/anlasi/spreng/schiessstrl_in.htm)) but its
text with heights was not retrievable. So **6 m is used as an upper bound and a shape, never as a
requirement**, and Karen's own word ("not high") decides inside it. No source was found for mown
grass versus gravel on a running-boar lane: that is a GUESS, and is stated as one below.

### The one thing no source has

**No real range anywhere in the sweep has an elevated firing point.** Every running-boar range
shoots from a ground-level hut (A, and Bisley's
[running-boar regulations 2026 (PDF)](https://www.nationalshootingcentre.co.uk/media/jdvpxl1v/20260413-running-boar-range-regulations-2026-v10.pdf)).
**The treestand station is Karen's invention and this project's, and rule 2 is satisfied by saying so
here.** What it borrows is the *hunting* structure, not a range's:

| Thing | Value | Source |
|---|---|---|
| Driven-hunt stand (*Drueckjagdbock*), DIY | platform **1.80 m**, 1.20 x 0.80 m, rail **1.20 m above the platform**, slat ring 0.40 m | [topagrar build guide](https://www.topagrar.com/jagd-und-wald/news/bauanleitung-drueckjagdbock-guenstig-bauen-70191.html) (trade press, live) |
| Ladder stand (*Ansitzleiter*), sold | total 4.00 m, **seat 3.00 m**, standing 2.50 m, footprint 1.70 x 2.50 m | [landwirt.com listing](https://www.landwirt.com/bg/detail/sonstige-ansitzleiter-drueckjagdleiter-7062639) (commercial listing, live) |
| Rifle rest in an enclosed seat | **1.05 m** ("Standardhoehe") | [Wild und Hund (PDF)](https://wildundhund.de/wp-content/uploads/sites/2/old_docs/100_101_otb_1411_2_neuerwaechterimfeld.pdf) |
| *Why* hunters sit high | the bullet goes **downward into the ground** -- safer near walkers | [ShootingUK](https://www.shootinguk.co.uk/?p=37680), [Geograph 86740](https://www.geograph.org.uk/photo/86740) (CC BY-SA 2.0) |

That last row is the reason the treestand belongs on *this* range and not on a sport range: the
game's own hunt is a driven hunt with beaters walking in front of the guns, and the stand is how that
is shot safely. The range should teach the position the hunt uses. `docs/design/high-seats.md`
already owns the hunt's stands, so the range's stand must be **the same structure or a stated
deviation from it.**

---

## 3. Sources: each player sees only his own animal

| Source | Fact | Licence / status |
|---|---|---|
| [Roblox -- Instance streaming](https://create.roblox.com/docs/workspace/streaming) | *"Instances which are created or cloned by client-side scripts are exempted from streaming out"* -- unless parented under a server-created instance. Default `StreamingMinRadius` 64 | official docs, current |
| [Roblox -- Remote events](https://create.roblox.com/docs/scripting/events/remote) | a client-created instance sent through a remote arrives on the server as **nil** | official docs, current |
| [Roblox -- Client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary) | the recommended shooting contract: the client sends **origin + the point it believes it hit**; the server checks the origin against the character with latency tolerance, the hit point against the target, and uses static geometry for occlusion | official docs, current |
| [Roblox -- Security tactics](https://create.roblox.com/docs/scripting/security/security-tactics) | an exploiter can fire any remote at any rate with any arguments | official docs, current |
| DevForum: [local parts](https://devforum.roblox.com/t/are-local-parts-possible/951032), [hitbox: server or client](https://devforum.roblox.com/t/hitboxs-dilema-server-or-client/4012087), [client-sided hitbox security](https://devforum.roblox.com/t/client-sided-hitbox-security/4540739/1) | community consensus: detect on the client, validate on the server, lenient enough not to punish ping | forum, active threads |

Three patterns were weighed.

1. **Client-authoritative.** The client decides the hit; the server only shows it. Cheapest. A
   cheater fakes a perfect card. *Acceptable only because the range pays nothing* -- but it throws
   away task 305's whole mechanism and gives the range a second shooting path, which section 1
   forbids. **Refused.**
2. **Six server-owned lanes, each hidden from everyone but its owner.** Roblox has no per-player
   visibility for a server-created part. The only approximation is six lanes far enough apart to sit
   outside each other's streaming radius -- six times the geometry, and still not isolation: a man
   who walks over sees the lot. **Refused.**
3. **Server-owned run DATA, client-drawn animal, server-judged shot.** The server owns each
   station's trial as *numbers* -- direction, pace, the leg's start time, the leg's ends -- and
   replicates **that**, to the one player. The client draws its own animal from those numbers, under
   a **client-created** folder (exempt from streaming out). The shot reports numbers, never an
   instance -- the remote-events doc makes that mandatory, not a preference. The server recomputes
   where that station's animal was at the shooter's time (a pure function of the run data) and
   resolves the ray against it. **Adopted.**

**Why 3 and not 1, in one sentence:** pattern 3 *is* task 305's rule -- *"the server tests an animal
where the SHOOTER DREW it"* -- and the seams for it already ship (`Weapon.Rewind`,
`Cast.candidates` / `Cast.only`, `Flight`'s carried `rewindSeconds`, `Weapon.setRewindWorld`, and
`RangeBoot`'s own registered history provider in `src/server/RangeBoot.server.luau`). The range stops
being a special case of shooting and becomes the *first* consumer of the rewind seam with no server
part at all. **That is a real risk and it is named in section 6 as the Architect's hardest
decision**, because `Cast.candidates` finds candidates with `GetPartBoundsInRadius` -- it wants a
Part.

---

## 4. The lobby's own rules, numerically (L-154)

The 298/302 incident: a character standing on the range mat was respawned at the lodge **0.6 s**
later, because `Join.insideField`'s half-span is 110 and the mat was 268 studs away. She could not
use the range at all. Task 302 fixed it with a **union of rectangles**, handed in as data. Any site
chosen for task 306 must be checked against the same arithmetic **before** a part is placed.

| Rule | Owner | The numbers, today |
|---|---|---|
| The lodge's home field | `Join.insideField` / `Join.homeAreas`; `Lobby.CONFIG.FIELD.SPAN_STUDS` = 220 | anchor `(2850, -2950)`, half-span 110, so **x 2740..2960, z -3060..-2840**. Outside it, `Join.needsReturn` is true and the man is respawned |
| The walkway to an outlying area | `Join.walkwayTo`; `FIELD.WALKWAY_HALF_STUDS` = 24 | the bounding box of anchor -> area centre, widened 24 on both axes |
| The range's own home area | `Range.footprintFor` -> `ForestTestBoot`'s `rangeHomeAreas` -> `Lobby.start` | already data. A new anchor is a new footprint and the union follows it |
| The drive's field | `ForestTest.boundsOf(ROAD_LAYOUT)` | **x 2230..3830, z -2477..-1197**, `exitZ -2377`. The whole lobby (z about -2950) is **473 studs south of `minZ`**, so a lobby range stays outside the drive -- which is what section 5 of the 10-27 note requires of any range site |
| The truck pads | `Lobby.Pads`, `CONFIG.PADS` | 4 pads under the trucks at **x 2916, z -2926..-2977**; standing on one enrols a man in a hunt |
| The stand rule | `docs/design/high-seats.md`; `Join.withinRect` / `withinStand` | a treestand on the range must not be mistakable for a hunt stand |

**Measured obstacles in the lobby** (`evidence/p306-lobby.txt`, Play, her place, 2026-10-28) -- the
inventory a site must be clear of, so the Architect need not re-measure:

| Thing | X extent | Z extent | Note |
|---|---|---|---|
| Lodge (plinth) | 2831..2870 | -2919..-2889 | the door is on the **SOUTH** wall at z = -2916 (`DoorPostW`/`DoorPostE`), porch z -2921, steps to -2929. The shop counter is **inside** the lodge (`Lodge.Inside.Shop`), so "front of shop house" is the front of this building |
| LodgeSpawn | 2844..2856 | -2937..-2931 | |
| Road `Lane` + verges | 2857..2884 | -3054..-2894 | runs north-south, south of the lodge |
| `Yard` | 2883..2929 | -2994..-2910 | the gathering yard |
| Trucks 1-4 | 2906..2925 | -2982..-2921 | on terrain with **1.3 studs of relief** |
| Fences | 2852..2888 | -3048..-3012 | 14 parts |
| Logs | 2816..2823 | -2917..-2912 | |
| `TreeLine`, 21 trees | 2765..2956 | -3045..-2875 | trunk centres; crowns 18-33 wide |
| `LodgeTrees`, 12 trees | 2806..2896 | -2906..-2863 | birch and alder; crowns 18-26 wide |

**Walk budget.** `Body.defaultWalkSpeed` is 16 studs/s, but her measured walk was 268 studs in
25.7 s = **10.4 studs/s effective** (terrain, trees, turns). 20 s x 10.4 = **the lodge door to the
nearest mat must be 208 studs or less** -- a bound derived from her own measurement rather than from
the nominal speed.

**And the footprint does not fit the field, which is a number and not an opinion.** With
`SPOT_COUNT = 6` at `SPOT_SPACING_STUDS` 24 and the long station at 179, `Range.footprintFor`'s own
arithmetic gives `halfX = max(BERM.X/2, screenOut, MAT.X/2)` plus `margin` 12 and
`spots = 5 x 24 = 120` on the +X side: about **304 studs across x and 222 along z** at today's
`BERM.size.X` of 160. The 220 x 220 field cannot hold it on either axis. So an **extra home area is
required whatever site is chosen** -- the task-302 mechanism, used as designed, not a new one.

---

## 5. The pattern adopted, and the numbers

### 5.1 Geometry. `Report.CONFIG.METRES_PER_STUD` = 0.28, so 1 m = 3.5714 studs

| Thing | Real | Studs | From |
|---|---|---|---|
| Station distance, long | 50 m | **179** | A, B (ISSF); inside C's 48-62 m hunting band |
| Station distance, short | 30 m | **107** | D (Swedish boar pass) |
| Station distance, today's | 35 m | **125** | the shipped `LAYOUT.DISTANCE_STUDS`; kept available (the Director's decision) |
| Window -- the gap between the two banks | 10.0 m | **36** | A, B. Today's is 40 (11.2 m) |
| Target centre above the firing ground | 1.4 m | **5.0** | A |
| Bench top | 0.7-0.8 m | **2.5-2.9** | A |
| Parapet in front of the track | about 1 m (GUESS) | about 3.6 | A's parapet; its height is not sourced |
| Berm behind the target line | 6 m is the upper bound, "not high" is the instruction | **upper bound 21.4**; shipped today is 10 (2.8 m) | NRA via forum, refused as a requirement; Karen's word decides inside it |
| Side berms | 2.5-3.5 m | 8.9-12.5 | same source, same caveat |
| Treestand platform | 3.0 m | **10.7** | the ladder stand's seat height; the Director's decision |
| Treestand rail above the platform | 1.2 m | **4.3** | topagrar |
| Station spacing | -- | **24 or more** | derived, not borrowed: `PROMPT.MaxActivationDistance` is 12, so 2 x 12 = 24 is the smallest spacing at which a man standing on mat *n* is out of reach of mat *n plus or minus 1*'s prompt. `SPOT_SPACING_STUDS` already **is** 24 |

### 5.2 Paces: the two new rows are TIMES, not speeds

ISSF specifies the **time across the window**, not a speed (A, B). So do we -- and the stud speed
falls out of `WINDOW_STUDS`, which means a later change to the window keeps the real timing instead
of silently changing it.

| Row | Rule | Studs/s at a 36-stud window | Crossing |
|---|---|---|---|
| `stand` | broadside, still (Karen, 2026-10-27) | 0 | -- |
| `walk` | `Boar.CONFIG.PACE.WALK_SPEED` | 4.5 | 8.00 s |
| `trot` | `TROT_SPEED` | 11 | 3.27 s |
| `run` | `RUN_SPEED` | 24 | 1.50 s |
| **`slow`** | **5.0 s across the window** (ISSF) | 7.14 | **5.04 s** |
| **`fast`** | **2.5 s across the window** (ISSF) | 14.29 | **2.52 s** |

`slow` and `fast` are genuinely new rows and not renamings: 7.14 falls between walk and trot, 14.29
between trot and run. The **"mixed"** rule from B -- slow or fast chosen at random and *not
announced* -- is the cheapest realism in this note and costs one boolean.

Crossing times are independent of the station's distance, which is correct: ISSF's window is 10 m at
50 m, and D's 30 m test uses the same kind of gap.

### 5.3 Shape

From E, stated once because the rest follows from it: **the animal is hidden behind cover at both
ends of the window and is already at its pace before it appears.** Two low cover banks, 36 studs
apart, with an apron behind each for the turn-around -- the shipped `APRON_STUDS` = 20 and
`SCREEN.beyondStuds` = 6, which task 298 step B2 *measured* rather than guessed: screens built *on*
the lane's ends stopped the target 7.8 studs short of an end it could never reach, so no leg ever
finished and nothing ever crossed.

From A: a covered firing hut over the line, a bench per bay, open front, and a red light per bay.
**Six bays side by side on one firing line** -- which is only possible because of section 3's
pattern 3: with each man's animal local to him, six bays can face **one** lane.

Surfaces: **mown grass in the lane, gravel at the firing line.** A GUESS, no source, recorded as one.

### 5.4 Free assets that could dress it (Karen's OK: free Creator Store / CC0 / our own Meshy only)

| Need | Asset | Licence | Polys | Risk |
|---|---|---|---|---|
| Bench / rest | Poly Haven [painted_wooden_bench](https://polyhaven.com/a/painted_wooden_bench) 630, [WoodenTable_01](https://polyhaven.com/a/WoodenTable_01) 952 | **CC0** | far under Roblox's [20 000-triangle mesh limit](https://create.roblox.com/docs/art/modeling/specifications) | Poly Haven's `polycount` may count polys, not triangles -- check after import |
| Ladder for the stand | Poly Haven [wooden_ladder](https://polyhaven.com/a/wooden_ladder) 8 492, [wooden_ladder_02](https://polyhaven.com/a/wooden_ladder_02) 6 126 | **CC0** | under the limit | platform and rail are Parts |
| Range props | [ammo_box](https://polyhaven.com/a/ammo_box) 4 382, [wooden_crate_01](https://polyhaven.com/a/wooden_crate_01) 6 576, [barrel_03](https://polyhaven.com/a/barrel_03) 1 473 | **CC0** | under | dressing only |
| Berm | Roblox [Terrain](https://create.roblox.com/docs/reference/engine/classes/Terrain): `FillBlock` plus two `FillWedge`s back to back | engine | -- | **the lobby already uses terrain cut-and-fill for its own shelf** (`Lobby.CONFIG.FIELD.DEPTH_STUDS` 48), so this is an existing pattern, not a new one |
| Treestand | none free found; the Creator Store must be searched inside Studio | Roblox terms | ? | **every free model must be checked for scripts** -- CLAUDE.md forbids a script outside a Rojo path |

No asset is on the critical path: every dimension above is buildable from Parts and Terrain, which is
how task 298 built the range that exists.

---

## 6. What this note does NOT settle, and hands to the Architect

1. **Does the cast need a Part?** `Cast.candidates` uses `GetPartBoundsInRadius`. A client-drawn
   animal has no server part, so either the server keeps an invisible, non-collidable proxy per
   station -- and then "isolated" is a statement about *rendering*, not about instances -- or
   `Cast.only`'s seam is given an analytic zone test. **This is the design's hardest decision, and
   whichever way it goes it must not invent a second resolution** (section 1).
2. **The site.** Every candidate must be checked numerically against section 4's two tables, and the
   extra home area computed from `Range.footprintFor` for the chosen anchor.
3. The owner of the per-station run data; the owner of the client-drawn animal; what is Terrain
   (saved in her place) and what is code-built Parts; the treestand as data; the build steps.

---

## 7. Numeric targets (what a build is measured against)

| # | Target | Instrument |
|---|---|---|
| T1 | Lodge door to nearest mat **208 studs or less**, walked in **20 s or less** | the 298 walk probe (`evidence/p298/walk-after.txt`'s instrument), re-run |
| T2 | **6** stations, all six prompts firable with a real key, each 24 studs or more from its neighbour | a real-key E at each post |
| T3 | A man at station *n* has **1** animal drawn for him, whatever the other five stations are doing | a client-side census of the local folder, two players |
| T4 | **A registered hit per pace from both firing positions** -- `stand`, `walk`, `trot`, `run`, `slow`, `fast` x {ground, treestand} = 12 cases, on the **client-drawn** animal, each with the shooter's aim, the server's hit part and local offset, and the client's mark, plus the shooter's-eye frame. **This is THE proof of the feature** | task 305's three-number instrument, plus rule L's known-bad control: a click at the air beside the spot must produce **no** hit |
| T5 | Measured crossing times within **5 %** of section 5.2 | the board's own measured crossing seconds (shipped; TARGET 3 of the 10-27 note) |
| T6 | No shot leaves the range: every miss ends in the berm or a side berm | a ray sweep from each station across the full window, both firing positions |
| T7 | `Join.needsReturn` is **false** at all 6 mats, on the treestand, and along the walk sampled every 8 studs | the task-302 instrument |
| T8 | 0 console errors; the forest range's folder, its walkway and its home-area row are gone and nothing references them | `ft-open.sh` plus grep |

**Unverified until built (L-151).** Every spatial number in section 5 -- the 6-station spacing, the
berm's height and slope, the 10.7-stud platform, the site's clearance from road, trucks, spawn and
tree line, and T6 -- is a document fact, not an engine fact. An Architect PASS proves the document is
coherent, not that it fits the engine: task 298 step B2 found two placement errors (the screens
stopping the target 7.8 studs short, and the prompt being invisible down the lane) only at the first
build.

---

## 8. THE LOOK (step B10). Karen, 2026-10-28: *"make nice shooting range clean proper like in real life ... outsource and make it real"*

The B8 range WORKS and reads PLAIN. The Director's own frames of her place
(`<runs-dir>/evidence/306b8/f1b-line-view.png`, `f2b-lane1-view.png`, `f3b-deck4-view.png`,
`f6b-berm-view.png`) show a bare brown dirt lane, a bare dirt berm, a brown box per bench, six bare
ladder stands and dark slabs at the firing line. Nothing in the picture says "range".

### 8.1 Photo-reference pages read for this step (text read; images to be checked by eye)

| # | Page | What it shows, and what we take from it |
|---|---|---|
| 1 | [BSRC Time Limit Range](https://bsrc.co.uk/time-limit-range/) | The 50 m running-boar range at Bisley: a **firing hut** with two bays, a **red safety light over each bay**, a Line Officer's station, a **parapet** hiding the trolley rail, and the motor room in the right-hand **butt**. We take the ROOFED FIRING POINT and the per-bay identity (our number board). |
| 2 | [BSRC Running Deer](https://bsrc.co.uk/running-deer/) | The 100 m running-deer range: firing point 4.0 m off the track centre line, target centre 1.66 m, and the **gap between two banks** the animal crosses. We take the two-bank window (already built, B2) and the GRASSED banks. |
| 3 | [Rheinpfalz: Hubertus Kaiserslautern, Aschbacherhof "Laufender Keiler"](https://www.rheinpfalz.de/lokal/kaiserslautern_artikel,-sch%C3%BCtzengesellschaft-hubertus-weiht-neue-anlage-auf-aschbacherhof-ein-_arid,5040637.html) | A German hunters' club running-boar installation: cardboard boar at 50 m, runs either way, slow or fast, behind a **sand backstop with a protective mat**. We take: the backstop is an EARTH heap, not a wall, and it is the only thing behind the animal. |
| 4 | [tips.at: Jagdschiesszentrum Desselbrunn](https://www.tips.at/nachrichten/voecklabruck/land-leute/725491-neues-jagdschiesszentrum-in-desselbrunn) | An Austrian hunting-range centre with a planned *Laufender Keiler* plus a 200 m stand: the lodge-plus-range layout we are copying (range in front of the house, not a walk away). |
| 5 | [Thurgau: Jagdschiessstand Heckemos, Objektkredit documentation (PDF)](https://finanzverwaltung.tg.ch/public/upload/assets/149334/Jagdschiessstand_Heckemos%2C_Dokumentation_zum_Objektkredit_def._.pdf?fp=1) | A new Swiss hunting range's own plan set: a roofed firing line, **mown turf** between the line and the backstop, **grassed side banks**, and a low fence round the lot. The strongest single reference for the LOOK. |
| 6 | [Geograph: "Hide or High Seat" (CC BY-SA 2.0)](https://www.geograph.org.uk/photo/86740) | A Scottish high seat: four weathered timber legs, a ladder, a platform rail you can see straight through. This is the look `HighSeats.COLORS` was already tuned to on 2026-10-20 (`<runs-dir>/218-edge-seat2.png`). |
| 7 | [Target World Landscheid](https://target-world.de/en/shooting) | A commercial running-boar stand: numbered bays under one roof. Our 1-6 number boards. |

### 8.2 What is adopted, and the deviations

**BORROW BEFORE BUILDING (rule 2).** No asset is uploaded for this step, and that is a decision, not
an omission:

1. Every shape wanted here (post, roof, bench, board, rail fence, turf) is an axis-aligned box. A
   downloaded mesh buys nothing a `Part` does not already give and costs a moderation wait, an
   `uploads.json` row, and a **per-asset rendered-loaded proof** (L-094: a `Decal`-vs-`ImageLabel`
   defect passed every automated check because no frame was taken of the asset itself).
2. The dispatch allows it: *"they may be a free/CC0 model scaled to the measured deck, **or better
   Parts**"*.
3. The seat is NOT rebuilt. `HighSeats.plan` is already ref-6's shape -- four weathered timber legs,
   a girt, two braces, a plank deck, a rail with a gap, and a `TrussPart` ladder at
   `Style = NoSupports` -- and it is **shared with the hunt's own stands**, so a change here changes
   the drive's look. Item 4 of the dispatch is therefore answered with a FRAME and no code.

**THE LANE: a PART of `Enum.Material.Grass`, not terrain grass.** The measured fact from B8 stands:
*terrain* `Grass` draws blades and from the bench they fill the frame. But a **BasePart**'s `Grass`
material is a flat texture with NO blades -- the blade geometry is a terrain-renderer feature, not a
material one. So the lane keeps its blade-free `Ground` terrain and a single anchored turf slab is
laid on it, `CanCollide = false`, `CanQuery = false`: nothing a ray or a body can meet, so no shot,
no boar route and no walk changes. `Terrain:SetMaterialColor` was REFUSED as the alternative: it is
global per material, and `Ground` is also the lodge yard and the road (`Lobby.CONFIG.FIELD.PADS`),
`Mud` the forest ruts and the bog (`Places.ruts`, `MapGen.Config.bog`) -- recolouring either would
repaint half her world.

**THE BERM AND THE BANKS: terrain `Grass`.** Blades 190 studs downrange are what ref-3 and ref-5
show ("earth formed mountain", grassed). They are nowhere near the shooter's eye, so B8's measured
objection does not apply at that distance. The two repaints therefore move AHEAD of the berm and
bank fills in `Build.writeTerrain`: a repaint of `AROUND -> LANE` in a band at the shelf would
otherwise eat the bottom 4 studs of a grassed heap and leave a brown skirt.

**THE FIRING POINT: a roofed hut per station** (ref-1, ref-5, ref-7): four corner posts, a flat
roof, a wooden bench in place of the brown box (same size, same position -- only colour and material
move), and a number board 1-6 on the uprange fascia where a man walking from the lodge reads it. A
`SurfaceGui` + `TextLabel` draws the digit: no upload, no decal id, and the text is read back off the
instance in the spec.

**THE WAY UP (dispatch item 6, the one input change).** B9 measured TWICE that a real `W` against the
`TrussPart` never climbs (`ESCALATE.md`, B9 entry). The common Roblox treestand pattern is a
`ProximityPrompt` that moves the character, and that is what is adopted:
`Climb` on **E** at the ladder foot, `Climb down` on **F** on the deck. Both keys are stated, and
**F and not E for the down prompt is a measurement, not a taste**: a man on the deck is inside
`MaxActivationDistance` (12) of BOTH the down prompt and the station's existing `RANGE` menu prompt
(the two points are 2.4 and 1.5 studs above the same deck), and `ProximityPrompt.Exclusivity`
defaults to `OnePerButton` -- one prompt per key is shown, the closest -- so two E prompts on one
deck is a coin toss about which door the key opens.
  * ProximityPrompt https://create.roblox.com/docs/reference/engine/classes/ProximityPrompt
  * Exclusivity https://create.roblox.com/docs/reference/engine/enums/ProximityPromptExclusivity

`Triggered` is connected on the **SERVER**, where it carries the player who pressed it, so there is
no new remote and no new client owner. The character is moved with `Model:PivotTo`, which is
`Match.Body.standCharacter`'s own call -- but NOT through `Body`: `Body.standCharacter` snaps its
target onto the measured GROUND, which is exactly wrong for a deck 12.5 studs up. The range writes
its own two points and says so.

**THE EDGES: a low rail fence** down both long sides of the lane corridor (ref-5), outside the
corridor and outside the window, so nothing stands in a line of fire.

> **REFUTED ON THE GROUND, 2026-10-29, and NOT SHIPPED.** Those two lines stand 18 studs outside the
> corridor, which in Karen's place is OFF the cut terrace and on the hill. Measured there (the
> census plus `<runs-dir>/306b10-post.luau`): along the east line the BUILD's own ground reader
> answers 159.1 where a plain terrain raycast answers 150.0, at (2775, -3061) -- so a post laid on
> the reader's answer stands 7.5 studs in the air in the picture. A rail was refuted first (one
> 155-stud board cannot follow a hillside that falls 150 -> 158 -> 154), then the posts. Refusing a
> post by footprint SPREAD did not catch it either: the two readers disagree about the SURFACE, not
> about its slope. `Range.fenceRuns` / `fencePosts` survive as the arithmetic a later task needs and
> `range.spec` asserts the build writes none of them. **Dispatch item 5 is NOT MET.**

### 8.3 Numeric targets for this step

| # | Target | Why that number |
|---|---|---|
| L1 | **ZERO gameplay numbers move**: the six mat, post, bench, deck and prompt points, the window, the three distances, the berm's and banks' size and position, the firing line's strip | `range.spec` asserts each against `Range` own position arithmetic, which B2-B9 measured; the step is a look step |
| L2 | Roof bottom at least 8.5 studs above the shelf, and no hut part inside the sight cone from either firing position to either end of any window | a level shot at a 5-stud-high target 107-179 studs away rises 0 studs; the worst off-axis ray is atan(18/107) = 9.6 deg, which is 1.3 studs of X at the roof's own downrange edge |
| L3 | The turf slab covers the lane from the firing line's downrange edge to the berm's near face, and is `CanCollide = false`, `CanQuery = false` | a decorative part that a ray or a body can meet is a gameplay change |
| L4 | The boar is **fully visible** from the bench: 0 % of its silhouette covered by anything this step adds | Karen's B8 complaint was a lane you cannot see over |
| L5 | A real `E` at the ladder foot puts the player on the deck (server position = treestand), and a real `F` on the deck puts him on the ground | dispatch item 6; B9's two failed `W` climbs |
| L6 | `Range.CONFIG.MAX_PARTS` raised to the new measured count plus headroom | the bound is a claim about cost, and it has to move when the build does |

# High seats — a wooden Hochsitz at some stands of each drive place (Task 218)

**Karen, 2026-10-10, verbatim:** *"hunter part is good for now, we just will improve standing
places, maybe will add towers where they can stand"*. On 2026-10-12 she decided the stand is the
circle and *"tree stands later count as part of the stand"*; the v1 plan of 2026-10-19 lists
towers / high seats.

**Her reference is ref-7** (`<runs-dir>/193-refs/karen-ref-7.png`, outside the repo). Looked at by
the Builder, 2026-10-20: a hunter on an **open raised wooden stand at the side of a forest road**,
looking down the road — a plain weathered-timber rail of rough boards at about chest height on a
seated man, an open deck with **no roof**, and the ground a long way below.

The design is `docs/design/high-seats.md` (Architect, PASS, 2026-10-20). This note is rule 1's five
headings: what the system must do, what was read, what each source does well and badly, the pattern
adopted and why, and the numeric targets — plus, under rule 8, what could not be verified.

---

## 1. What the system must do

1. **Put a raised wooden stand at SOME stands of each of the four drive places**, chosen by a
   measurement rather than by taste, and frozen as data so the world is a pure function of the
   commit.
2. **Make the platform the stand.** At a stand that carries one, a hunter may shoot only from the
   deck — Karen's *"tree stands count as part of the stand"*, which means the circle's rule moves
   up onto it rather than a second rule appearing beside it.
3. **Add no controls.** Climbing must be walking into the ladder, so a thumbstick and a phone work
   and no input owner changes.
4. **Stand on the ground** — every leg and the ladder's foot, on rolling terrain, with no daylight
   under a foot and none sunk out of sight (standing rule E).
5. **Break nothing that already works**: the drive's placement, the floor net, the soft wall, the
   stand ring, the tree planting of tasks 193/196, the markers' own refusal, and every ground stand
   in the game.
6. **Build from parts, in our design language.** No upload, no free model, no `.rbxm`.

## 2. What was read

| # | Source | Licence / status | Does well | Does badly |
|---|---|---|---|---|
| A | **Roblox Creator Docs — `TrussPart`** and `Enum.HumanoidStateType` — https://create.roblox.com/docs/reference/engine/classes/TrussPart | Roblox docs, current | It **is** the ladder: a default Humanoid climbs a `TrussPart` with no script, no key and no new input owner, which is requirement 3 answered by the engine. Its climb is driven by collision and class, so it needs no `Touched` and no state machine of ours | The page is a property index with **no prose on the climb and no stated size clamp**. The 2 × 2 × *n* constraint is the community's measured answer (devforum, "How to make truss parts 0.5 by 0.5"), not a documented one — so the Builder sets the size, reads it back and reports (section 6) |
| B | **Luanti (Minetest) — the `climbable` node property** — https://api.luanti.org/node-definition/ | LGPL-2.1+, maintained | The same decision in another engine, in one word: **climbing is a property of the WORLD, not a control the player learns.** It is the API this repo already borrows `core.is_protected` from in `Weapon.Rules` | Voxel-world semantics; nothing about a free-standing structure or about collision shape |
| C | **Valve Source SDK 2013 — `UTIL_DropToFloor`** (`game/server/util.cpp`) — https://github.com/ValveSoftware/source-sdk-2013 | source-available, non-commercial, archived | The rule this repo already lives by (`Match.Body`'s own header quotes it): **an entity's Y is never authored, it is a trace straight down from the authored point.** Applied per footprint corner it is also the fix for lessons L-024 / L-025 | One trace from one origin. A four-legged structure on a hill needs five, and Valve's version has nothing to say about which of the five the deck should reference |
| D | **Wikipedia — *Hochsitz*** — https://de.wikipedia.org/wiki/Hochsitz | CC BY-SA 4.0, current | The **typology**, which is what settles what ref-7 actually shows: an open *Drückjagdbock* / *Drückjagdkanzel* without a roof, as against a closed *Kanzel* and against a ladder stand strapped to a tree. It is why this seat has no walls, no roof and no bench | Encyclopaedic: no dimensions worth building to |
| E | **German hunting practice literature on the Drückjagdbock** — jagdpraxis.de's *"Bauanleitung: Drückjagdbock günstig bauen"*, Jäger's *"Hochsitz bauen"*, and the *Outlander* larch Drückjagdbock's own material list | commercial / trade press, current | **The dimensions, as built things.** Seat heights are sold at 2.40 / 3.00 / 3.50 / 4.00 m, with 2.50–3.50 m called optimal (2.50 enough in forest, higher for open ground). The platform is *"at least 1 × 1 m"*, typically 1.20 × 1.20 or 1.40 × 1.20. Corner posts 7.2 × 7.2 cm, platform beams 4.2 × 7.2, deck boards 3.8 × 11.0. Designed to **UVV**, which wants a railing and step protection | Written for timber and a human body, not for a 2-stud-wide Roblox character; and the UVV rail is a guard rail, which is the one number this design deliberately refuses (section 3) |
| F | **WILD UND HUND — *"Drückjagdstände — Sicher ist sicher?"*** — https://wildundhund.de/ | trade press, current | Already quoted in `src/shared/ForestTest/init.luau` for where a stand belongs on a drive. Confirms the *safety* reason height is wanted at all: a raised shooter has a **downward** backstop | Nothing about construction |
| G | **This repository** (rule 2 — borrow from inside first) | ours | `ForestTest.Markers.ring`'s tilted-chord `CFrame.fromMatrix` idiom, `Lobby.Build`'s `part`/`log` timber language and its `solid = false` split, `TreeGround`'s claw/embed idiom, `Markers.setReaders`' injection shape, `Body.onGround`'s drop-to-floor and its `fromY` rule, and `Weapon.Rules`' one-predicate-per-question discipline. **Nothing in this task is a new mechanism** | — |

## 3. What was adopted, and why

**The whole shape is borrowed; one number is deliberately not.**

* **The ladder is a `TrussPart`** (source A, with B as the principle). It is the only part of this
  task that could have become a control, and the engine already owns it. **2 studs square is the
  engine's constraint, not our choice.**
* **The ground fit is drop-to-floor per footprint corner** (source C), five samples — four leg feet
  and the ladder's foot — each read with `ForestTest.terrainYAt` **first** and then
  `ForestTest.groundAt(x, z, terrain + 2)`. The `fromY` origin is the whole point: a downward ray
  can only hit what is below it, so a seat **cannot** measure itself through its own deck. That is
  lesson L-025 turned into a rule instead of care.
* **The deck references the WORST (highest) corner**, which is the one place this design departs
  from `TreeGround`'s own rule and the reason is stated in code: a tree is seated at the **lowest**
  ground because daylight under it is the defect, while a seat's deck is also the **platform rule's
  own line**, so referencing the highest foot makes *"nobody standing under this seat is above the
  line"* arithmetic rather than hope.
* **The dimensions come from source E, converted at 0.28 m/stud** and widened only where a Roblox
  body demands it: 12.5 studs = **3.50 m** of rise (the top of the real band, because these stands
  look over a drive); a **6 × 6** deck = 1.68 m square against the real 1.20, because 6 × 6 is
  already `Markers.POST_SIZE`'s footprint and leaves 2 studs clear all round a 2-stud character;
  0.5-stud posts = 0.14 m against the real 0.072, because 0.072 m is 0.26 studs and would not read
  at all.
* **The rail is REFUSED as a guard rail and adopted as a shooting rest.** Source E's UVV / ASR A2.1
  height is 1.00 m; this seat's board top is **0.67 m (2.4 studs)**. The reason is arithmetic, not
  preference: with the aim origin 5.0 studs above the deck and the board plane 2.9 studs out, a
  board at 2.4 blocks only a **2.6-stud annulus** (11.3–13.9 studs, 3.2–3.9 m) directly beneath the
  seat, which a real Hochsitz has too; at 3.6 studs the blind band widens into the range a side
  shot is actually taken at. The deviation is written in `HighSeats.DIMS` beside the number.
* **The stand rule gains a FLOOR and `outsideStand` is untouched.** `StandArea.minY`,
  `Rules.belowPlatform`, one new reason (`off-platform`, "CLIMB TO YOUR STAND"), and a declared
  place in `Rules.ORDER` immediately inside `OFF_STAND`. One question per function — `Rules.luau`'s
  own rule, and `Match.Penalty`'s warning about a predicate that answers two unrelated questions.
* **`minY` IS the deck's top face, with no margin.** `reviews/task-218/BRIEF.md` D3 proposed
  `deckTop − 2` on the reasoning that *"a jump reaches about 4-5 studs"*. **That is wrong and was
  measured:** `StarterPlayer.CharacterJumpHeight` in Karen's Forest Test is **7.2**
  (`CharacterUseJumpPower = false`), so a man standing in the seat's own footprint reaches
  `ground + 3.5 + 7.2` at his apex and a line at `ground + 10.5` is reached. At the deck's own face
  there are **1.8 studs** of air under the line and **3.5** above it.

**What was NOT adopted, and why.** No bench (ref-7's hunter is seated; Roblox has no sit here and a
bench takes a third of a 6-stud deck), no roof (it is a *Bock*, not a *Kanzel*), no walls, no gun
hook, and no weathering or per-layout variation.

## 4. The borrowings this task did NOT make, written down (rule 2)

Nothing here is invented, so there is no "why we built our own" to justify. The two places where it
would have been tempting to invent are both recorded as refusals:

* **A second ground reader for the markers.** It would have been easy to give `Markers.groundFor`'s
  canopy call a `fromY` so the deck became invisible to it. That reader's refusal is the rule all
  four layouts were selected by, `forest_markers.spec` asserts it, and changing it would move the
  answer at every stand of every layout for a reason belonging to one stand in three. Instead
  `Markers.build` **asks the seat where its deck is** and does not ask the readers for that stand.
* **A remembered table of deck heights.** The brief proposed one. The folder **is** the state:
  `Seats.deckTopY` reads the `Deck` part's own top face, so there is no second copy to go stale —
  `Weapon.heldId`'s discipline, *"derived, never stored by anybody else"*.

## 5. The numeric targets

| What | Target | Where it is asserted |
|---|---|---|
| Deck top above the seat's **worst** footprint ground | 12.5 studs = 3.50 m | `high_seats.spec`, "the deck is referenced to the worst corner" |
| Deck | 6 × 0.5 × 6 studs (1.68 m square) | same |
| Rail board top above the deck | 2.4 studs = 0.67 m | same, "every rail board's top at one height" |
| Parts per seat | 17 | `high_seats.spec`, "exactly seventeen pieces" |
| Seats per layout | ≤ `ceil(standCount/3)`, never two adjacent, at least one | `high_seats.spec`, "takes at least one stand…" |
| Minimum sight gain for a seat | 60 studs = 17 m ≈ 3.3 s at a boar's trot | the selection rule (section 6.2 of the design) |
| Footprint spread a seat accepts | ≤ 4.0 studs | `high_seats.spec`, "refuses rather than building a partial seat" |
| **Rule E:** leg/ladder bottom **above** its own ground | **0.00 studs**, worst case over 5 samples × all seats | the `[seats]` console line, live |
| **Rule E:** leg/ladder bottom **below** its own ground | ≤ 0.8 studs (embed 0.3 + voxel 0.5) | same |
| Deck level: spread of the four leg tops | ≤ 1e-6 studs | `high_seats.spec`, "cuts each leg to its own ground" |
| Jump margin under `minY` | 12.5 − 3.5 − 7.2 = **1.8 studs** | `high_seats.spec`, "keeps the platform's line out of reach of a jump" |
| Floor-net margin for a man under a seat | 12.0 − (3.5 + 6) = **2.5 studs** | `high_seats.spec`, "keeps the deck's underside above the floor net's near probe" |
| Rail-blocked annulus at a 5.0-stud aim rise | 11.3 – 13.9 studs, 2.6 wide | `high_seats.spec`, "names the blocked annulus as a number" |
| Seat footprint inside the stand circle and the cleared lane | 5.1 < 12 | `high_seats.spec`, "keeps the whole footprint inside…" |

## 6. What could not be verified from disk (rule 8)

1. **`TrussPart`'s exact `Size` clamp.** The docs page (source A) carries no prose on it. The size
   is set, read back and reported from the live place; if the engine clamps the long axis too, the
   ladder becomes a stack of trusses and the part count rises.
2. **The aim origin's rise above the deck.** 5.0 studs is derived (root 3.5 + 1.5 to the eye). The
   blocked band is sensitive to it, so it is measured from a live shot and the band reported.
3. **Whether `PathfindingService` routes a boar round a seat rather than through it.** The legs
   collide, so the navmesh should treat them as obstacles; nothing in this repo has measured a
   `TrussPart` or a 0.5-stud post against `ComputeAsync`.
4. **The sight measurement is of Karen's world on 2026-10-20**, taken in a **Play** session so the
   three dressed places exist (`DrivePlaces=3`; the Edit run read `ABSENT` and gave different gains
   for `ride` and `track`). Re-dressing or re-terraforming a place invalidates the table, and the
   probe is in the run directory to be re-run.
5. **The one accepted hole, in writing.** Where no stand on a line satisfies the relief test, its
   best stand is taken anyway (design section 6.2 rule 4) and the platform rule is defeatable at the
   top of a jump from the high side of that circle. **It applies to `edge` today**, it is printed by
   `Seats.takeLine` every time the world is built, and it is accepted because the rule's purpose is
   *a high-seat hunter shoots from his platform*, not anti-cheat.

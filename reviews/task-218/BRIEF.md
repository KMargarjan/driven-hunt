# BRIEF — Task 218: HIGH SEATS (a wooden Hochsitz at some stands)

Written by the Builder, carrying the Director's dispatch of 2026-10-20. **This file overrides
anything older in `docs/`, `TASKS.md` or an earlier design** (`docs/ARCHITECT_PROMPT.md`).

The Architect is asked for **one design**: `docs/design/high-seats.md`, plus the **deltas** section 9
lists for the designs this touches. Nothing else.

---

## 1. Karen's words, and what this task is

> **2026-10-10:** *"hunter part is good for now, we just will improve standing places, maybe will add
> towers where they can stand"*
>
> **2026-10-12:** the stand is the circle, and *"tree stands later count as part of the stand"*
>
> **2026-10-19 ("continue"):** the v1 plan lists towers / high seats.

Her reference is **ref-7** (`<runs-dir>/193-refs/karen-ref-7.png`, outside the repo). Looked at by
the Builder, 2026-10-20: a hunter sits on an **open raised wooden stand at the side of a forest
road**, looking down the road. Visible: a **plain weathered-timber rail** of rough boards at about
chest height on a seated man, an **open deck** with no roof, and the ground a long way below. It is
a Central-European **Drueckjagdbock / Hochsitz**, not a closed box *Kanzel* and not a ladder stand
strapped to a tree.

**This task builds that, at SOME stands of each of the four drive places, and moves the stand rule
up onto its platform.**

---

## 2. The decisions already taken (the Architect designs to these, it does not re-open them)

### D1 — What a high seat is

A **Central-European wooden high seat**: four legs, cross-bracing, an **open deck** about **3.5 m**
(about **12.5 studs** at `Report.CONFIG.METRES_PER_STUD` 0.28) above the ground, a **plank rail**
round the deck, and a **ladder** up one side. **No roof.** Built from **Parts in code**, in the
lodge's timber language (`Lobby.Build`'s `log` / `part` idiom, `Enum.Material.Wood` /
`WoodPlanks`). **No uploads, no free models, no `.rbxm`.**

### D2 — SOME stands, and which ones, is a MEASUREMENT frozen as data

Not every stand. A seat goes where **height buys sight the ground does not have**: the hunter's
whole job here is to see the drive coming.

* The Builder **measures** it in Karen's Forest Test before writing the table: at **every one of the
  25 stands of the four layouts**, how far a ray north at eye height reaches **from the ground**
  against **from the deck** (12.5 studs up). The gain is the number.
* The result is **frozen as a table keyed by layout name** (`road` 9, `edge` 5, `ride` 5, `track` 6),
  so the world is a pure function of the commit — the rule `Places` already follows.
* **Caps, so "some" is a rule and not a taste:** at most `ceil(standCount / 3)` seats per layout
  (road 3, edge 2, ride 2, track 2 — **9 seats in all**), and **never two adjacent stands**, so a
  hunter always has a ground neighbour and the line never reads as a row of towers.
* A spec asserts the SHAPE (count within the cap, no two adjacent, every index inside
  `1..standCount`) — not the measured values, which are Karen's to move.

### D3 — The platform IS the stand, and the circle's rule moves up onto it

* The deck is **centred on the stand point** (`ForestTest.standPosition`), so the flat circle
  (`PICK.standRadiusStuds` 12) is already centred under it and nothing about the ring, the soft wall
  (`ForestTest.boundary`) or `Places.LANE_STUDS` moves. `Places.LANE_STUDS == standRadiusStuds`
  already keeps every tree out of the circle, so **nothing is planted through a seat** (193/196
  respected, with no new rule).
* **At a high-seat stand the hunter may shoot only from the platform.** `Weapon.Rules.StandArea`
  gains an optional **`minY`**; `Rules.outsideStand` stays exactly what it is (flat, Y ignored — it
  is the flat question, and the ground stands must not change). A **new, separate predicate**
  answers the height question, with its own reason and its own notice line — one question per
  function, `Rules.luau`'s own rule.
* **`minY` is nil everywhere else**, which is "no height rule": every ground stand, the DEV arena
  (`Match.standAreaOf`'s fallback) and every existing spec behave exactly as they do today.
* **The margin is arithmetic, not a guess.** A root sits about 3 studs above the feet, and a jump
  reaches about 4-5 more. `minY = deckTopY - MARGIN` with a margin of about 2 studs leaves a man on
  the ground (root about ground+3) nine studs under the line and a man on the deck (root about
  deck+3) five above it, and **no jump from the ground can reach it**. The Architect states the
  arithmetic.

### D4 — Climbing is walking into the ladder. No new controls.

The ladder is a **`TrussPart`**: the Roblox Humanoid's own climb state, so it works with WASD, with
a thumbstick and on **mobile**, and this task adds **no input owner and no key**
(`docs/design/camera.md` owns input; it is not touched).

### D5 — Collisions, and what a pellet may pass through

* **The deck, the legs, the rail and the truss COLLIDE.** Nobody falls through the deck and nobody
  walks off it sideways.
* **They are `CanQuery = true`** — this is **real structure, not a marker**. A shot must not pass
  through a deck or a leg. This is the **deliberate opposite** of `ForestTest.Markers`'s
  `CanQuery = false` rule, and the Architect must write down why the two differ.
* The rail's top is **below the muzzle of a standing shooter**, so a hunter on the deck can shoot
  out over it — the thing ref-7 shows. The Architect gives the number and the arithmetic against
  `Body`'s root height.

### D6 — Rule E: it stands on the ground, and the ladder meets the ground

Lesson **L-025 / L-024** (Task 207's ring, Task 196's trees) names the exact bug to avoid:

* the ground is read **per footprint corner** — **each leg's own foot and the ladder's foot** — not
  once at the pivot and not off a bounding box;
* every read uses a **`fromY` origin just above the terrain at that corner**, never a cast from the
  sky over the deck;
* **each leg is cut to its own ground**, so the deck is level and no leg hangs or sinks;
* the claim is the **worst case over all samples of all seats**, plus frames.

### D7 — Placement puts the hunter ON the platform, through the seam that already exists

`Body.placementFor` reads `post.Position + post.Size.Y/2 + STAND_HEIGHT_STUDS`. So **the stand's
marker part (`ForestMarkers.Stand<i>`) sits at the DECK at a high-seat stand**, and `placementFor`,
`Match.standAreaOf`'s fallback and the Forest Test's own `placement` closure need **no new
arithmetic**.

**The snap is the hard part, and the Architect must rule on it.** `Body.onGround` replaces a
caller's Y with the ground measured under it (task 192, *"a caller's Y is advisory"*), through the
world's **one** injected reader `ForestTest.groundAt` (`ForestTestBoot`: *"not onto a fourth opinion
of it"*). Two facts collide:

1. If the seats are **visible** to `groundAt`, the hunter snaps onto the deck correctly and the
   floor net, the boundary lift and `underGroundBy` all stay right — **but** `Markers.groundFor`
   reads the stand column from the sky, would see the deck 12.5 studs over the terrain, and
   `GROUND_TOLERANCE_STUDS` is 1 — so **every seat stand would be REFUSED** and the drive would sit
   in `WAITING forest:stands`.
2. If the seats are **in `ForestTest.GROUND_IGNORE`**, the markers are right and **the hunter is
   snapped down off his own seat**, which kills the feature.

**The Builder's proposal, for the Architect to accept, amend or replace:** the seats are **visible**
to the world's one reader (a deck is a thing a body stands on), and the stand column stays honest by
**ORDER and MEMORY** instead of by a second reader —

* the seats live in **one new folder with one writer** (`Workspace.HighSeats`, a new
  `src/server/ForestTest/Seats.luau`; the pure "which stands, how big" half in a new shared module,
  because `drive-places.md` section 1.2.1 forbids adding a field to the `Layout` record);
* **a seat REMEMBERS the terrain it was built on.** `Markers.build` asks the seat first: where a
  seat stands, its remembered ground IS the stand's ground and the two readers are not asked at all;
  where there is none, the two readers run exactly as they do today and, if they agree, the seat for
  that stand is built on that reading and the post is raised to its deck;
* so the ground under a stand is measured **once, on clean ground**, and `Markers.build`'s
  once-a-second `Waiting` call neither churns 135 parts nor re-reads through a deck;
* the seats are cleared with the picks and the rings at the `Assigning` edge when the **layout**
  changes, so a rotation never leaves the road's seats standing in the ride.

**The named residual risk, which the Architect must either close or accept in writing:** with the
seats visible to `groundAt`, the three other callers that ask it **from the sky with no `fromY`**
(`Boar` spawn and path points, `Bots` placement, `Places` planting) could in principle put a boar or
a beater bot **on a deck**. `Places` is already closed by the lane rule (nothing is planted within
`LANE_STUDS` of the line). For the other two the Builder's position is: it is a **rare, visible and
self-correcting** oddity (the animal walks off and falls), against a **certain, every-drive**
failure the other way — and the live drive proof measures it rather than assuming it. If the
Architect wants it closed, it must be closed **without a second answer to "where is the ground"**.

### D8 — What this task does NOT do

No new phase, no new input, no new animal behaviour, no terrain write, no upload, no change to the
drive's length, the score, the safety arc or the tie. **Place 1 (`road`) keeps its numbers to the
stud** — a seat adds a structure, it moves no stand. The DEV place (`TestArena`) gets **nothing**:
the harness runs there, and `ForestTestBoot` already returns early anywhere else.

---

## 3. The owners this touches, and the one new one

| System | Owner | What changes |
|---|---|---|
| `Workspace.HighSeats` | **NEW: `src/server/ForestTest/Seats.luau`** | the one writer. Nothing else creates, moves or destroys a seat |
| which stands have one, and the seat's dimensions | **NEW: a shared, pure module** | pure data and arithmetic; no Instance, no service, no raycast |
| `Workspace.ForestMarkers` | `ForestTest.Markers` (unchanged owner) | asks the seat where the stand's ground is, and raises `Stand<i>` to the deck |
| where a character stands | `Match.Body` (unchanged owner) | **ideally nothing.** If the Architect needs a change here, it is `TWO_PLAYER_PATHS` |
| may this shot be taken | `Weapon.Rules` (unchanged owner) | one new predicate, one new reason, one new notice, `StandArea.minY` |
| this hunter's circle | `ForestTest.standArea` (unchanged owner) | carries `minY` when his stand has a seat |

---

## 4. What the design must contain

1. **The seat, as geometry**: every part, its size, its material, its colour, its `CanCollide` /
   `CanQuery` / `CastShadow`, and the part count per seat and for the worst layout. Measured against
   ref-7 in words a frame can be judged by.
2. **The ground fit** (D6): the exact footprint samples, the `fromY` rule, how a leg is cut, and
   what is refused when a corner cannot be read.
3. **Which stands** (D2): the measurement, the caps, the frozen table, and what a spec may assert.
4. **The stand rule** (D3): `minY`, the new predicate, where it sits in `Rules.ORDER` and why, the
   reason string, the notice line, and the arithmetic of the margin.
5. **Placement and the snap** (D7): the ruling, in full, including the residual risk.
6. **The ownership and the call order** across `ForestTestBoot`, `Markers.build`, `Seats` and the
   layout rotation — as a numbered sequence.
7. **The specs**: what is asserted with hand-written numbers and no Studio, including the two the
   dispatch names — *can shoot on the platform, cannot from the ground below*, and *placement puts
   him on it*.
8. **The scope**: which `BLAST_RADIUS` / `SCOPE_SPECS` entry in `tools/studio_mcp.py` each new file
   belongs to (standing rule G: a new spec in no scope turns CI red).
9. **The deltas** (section 9 below), as **exact text for the Builder to paste**, because the
   Architect script writes only its own file.

---

## 5. What the design must NOT do

1. Must not add a field to the `Layout` record (`drive-places.md` section 1.2.1).
2. Must not write a second answer to "where is the ground".
3. Must not touch, move or re-colour anything in `Workspace.OurForest`, `Session`, `LobbyAssets` or
   `DrivePlaces`.
4. Must not carve or raise terrain.
5. Must not change `Rules.outsideStand`'s flat rule, or the behaviour of any ground stand.
6. Must not require an upload, a free model or an `.rbxm`.
7. Must not invent a y (`TreeGround`'s rule).
8. Must not put a seat in the DEV place.

---

## 6. The gate and the proof this task owes (the Director's dispatch, for the Architect's information)

* **Rule E frames**: an eye-height frame from the platform in each place that has a seat, and one
  from the ground looking at a seat, beside ref-7.
* **Specs**: the stand rule on the platform (can shoot up there, cannot from the ground below), and
  that placement puts him on it.
* **Live**: a full drive from a high seat with a shot boar (the hit card).
* **Smoke PASS** (standing rule A), **scoped gate logged**, and — because the Architect's ruling on
  D7 may reach `src/server/Match/`, and because `Match`'s own stand rule is in play —
  **`TWO_PLAYER_PATHS`: the Builder STOPS with `NEEDS TEST2 218 <sha>` before the review.**
  Karen's look at the silhouette happens at that same stop (lesson **L-008**), before the review is
  spent.

## 7. Time box

3 h, foreground only.

---

## 8. Lessons the Director's dispatch attached, and what this brief does with them

| Lesson | What this brief does |
|---|---|
| **L-095** — the prompt never pastes the command that reaches a drive | `python ftplay.py server lobby-go.luau` from `<runs-dir>`, after Play starts (standing rule I). Written here so the live proof has a route |
| **L-023** — no route named for landing the shot | the Builder uses the Forest Test's own shoot route (`<runs-dir>`'s shoot probe / `FireRequest:FireServer`) and reloads between shots, rather than aiming at a screen point (Task 149: 0/62) |
| **L-025 / L-024** — a ground reader cast from above the platform, or one pivot instead of the footprint | **D6**, written as a decision rather than as advice |
| **L-071** — design decisions landing in a BRIEF and never in `docs/design/` | **section 9**: the Architect writes `docs/design/high-seats.md` AND gives the exact delta text for the designs it changes, and the Builder commits those edits in the same commit as the design |
| **L-008** — a new visible model judged by eye, with no stop for her look before the gate is spent | **section 6**: Karen's look at the silhouette is folded into the `NEEDS TEST2` stop, before the review round |

## 9. The deltas the Architect must write out (as exact paste text)

1. `docs/design/forest-drive.md` — section 4.1 (`Markers`) gains the seat seam and the call order;
   the stand is no longer always on the terrain.
2. `docs/design/drive-layouts.md` — a layout's stands may carry a high seat; where that table lives,
   and that the `Layout` record is unchanged.
3. `docs/design/drive-places.md` — section 1.2's "must not" list: `Workspace.HighSeats` is a second
   folder this world owns, and the lane rule already clears it.
4. `GAME_DESIGN.md` — the *System owners* table: one row for the high seat's owner.
5. `docs/research/INDEX.md` — the research note this task writes (rule 1), if the Architect judges
   the system non-trivial enough to need one. **The Builder's position: it does** — a Hochsitz's
   real dimensions, the Roblox truss-climb pattern and the drop-to-floor collision are all
   borrowed, and rule 2 wants the borrowing written down.

# Task 179 — design brief for the ARCHITECT: drive layouts (varied drives)

Written by the Builder, carrying the Director (2026-10-14). This brief is the input to
`tools/architect.sh design drive-layouts --task 179` and **overrides anything older** in `docs/`,
`TASKS.md` and the existing designs where they disagree (`docs/ARCHITECT_PROMPT.md`).

Read first: **`docs/research/2026-10-14-drive-layouts.md`** — this task's note. It carries the
sources, the pattern, and **every measurement of the Forest Test world this design must respect**.
The design is a NEW system design, `docs/design/drive-layouts.md`, plus the deltas it forces on
`docs/design/forest-drive.md` (the Forest Test's own drive) and `docs/design/map-ui.md` (the
hunter's map draws the road and the stands).

KAREN, 2026-10-13 ~13:55, verbatim:

> *"we will improve terrain that not all a time same place hunters standing and not the same terrain
> for beaters / we will make view for hunter from different places and diffretent tree lines road ect
> like in real life"*

## 1. The decisions, already taken — do not re-open them

1. **A DRIVE LAYOUT IS DATA, IN THE SHARED WORLD MODULE.** `src/shared/ForestTest/init.luau` is the
   one world-geometry seam (task 157) and stays the one home. A layout is a frozen table there, not
   a new module, not a Studio folder, not a second file.
2. **THREE LAYOUTS SHIP**, and their numbers are MEASURED (note §5), not chosen:
   * **`road`** — today's, unchanged in every number: centre (3030, 138, -2097), the sine
     (amplitude 30, wavelength divisor 70, half-width 20), 9 stands 150 apart.
   * **`edge`** — the south forest edge: centre x 3480, z −3000, **straight** (amplitude 0),
     **6 stands 150 apart** (x 3105..3855), hunters out in the open with the tree line ~100 studs in
     front of them, on an 80-stud west-to-east slope. 6 and not 9, and 3480 and not 3030, because
     `Lobby.anchorFor("forest-test")` is (2850, −2950) and a 9-stand line would run through the
     lodge.
   * **`ride`** — a straight ride inside the east wood: centre x 3350, z −2600, **straight**,
     **5 stands 130 apart** (x 3090..3610). Measured 5/5 trunk-free; the bar is today's road, which
     is 9/9.
3. **THE FOURTH LAYOUT THE DISPATCH ASKED FOR — A CLEARING WITH A HIGH SEAT — IS NOT SHIPPED**, and
   the reason is measured, not an opinion: of 1,054 points sampled inside the wood, **nine** have
   nothing colliding within 45 studs and no two are adjacent. There is no clearing. Making one means
   deleting Studio-built trees (rule 7, and Karen's call). The design says this in one paragraph and
   moves on.
4. **EVERY LAYOUT PUSHES SOUTH, ALONG −Z**, exactly as today's does, and **the beaters' walk stays
   580 studs in every layout** so a drive stays the ~120 s task 162 measured. Rotating or reversing
   a drive is explicitly the NEXT task: north is a sign rather than a parameter in `Brain:_outcome`
   (`position.Z <= exitZ`), `Boar.CONFIG.field.exitZ`, `ForestTest.lineFrontAt`, `wavePoint`,
   `restPoint`, `encounterStage`, the drive line's `normal = Vector3.zAxis`, `SafetyArc` and the
   compass. The design must NOT try to parameterise the axis today, and must say where the seam for
   it would go.
5. **THE CHOICE IS A BAG, NOT A RE-ROLL** (note §2 source D, §4): a shuffled bag of every layout
   name, dealt one per drive, refilled when empty, with the one boundary swap that stops `C | C`
   across a refill. It is PURE — `(previous, bag, roll) -> name, bag'` — so a spec drives it with
   fixed numbers.
6. **THE DIRECTOR CAN FORCE ONE**: an attribute `DHForestLayout` on `ServerStorage`, read exactly as
   `ForestTest.START_ROLE_ATTRIBUTE` (`DHForestStartRole`) is — Edit mode, survives into Play, never
   in the git tree, not a `DHFlag_*` name. An unknown name is ignored with a console line.
7. **NO FEATURE FLAG.** The layout table with one entry IS today's behaviour, so the change is dark
   by construction; a flag here would be a second switch over the same fact. (If the Architect
   disagrees, say so and say why — this is the one decision in §1 open to a counter-argument.)
8. **NOTHING IS CARVED OR PAINTED.** All three layouts sit on the ground as Studio built it.

## 2. What the design must contain

1. **THE LAYOUT RECORD.** The exact field list, with the type of each and which existing number it
   replaces: name, a short label a HUD may print, centre (Vector3), the line's shape (amplitude,
   wavelength divisor, half-width — amplitude 0 IS a straight line, so there is one shape and not
   two), stand count, stand spacing, how far north the beaters start, how far south of the line the
   boars leave, and anything else the three shipped layouts actually differ in. **A field no shipped
   layout varies must not exist**: a knob nobody turns is a second copy of a constant.
2. **HOW A PURE FUNCTION GETS ITS LAYOUT.** The adopted shape is the one this module already uses
   for `spook`, `beater` and `rest`: a trailing optional parameter, defaulting to the live layout.
   Write out the resulting signature of every geometry function that must change — at least
   `roadZ`, `standX`, `standPosition`, `driverStart`, `beaterStart`, `roadPointAt`, `wavePoint`,
   `restPoint`, `laneLookPoint`, `offLaneStuds`, `beaterLaneOffset` — and say what happens to the
   bare module constants `CENTRE`, `ROAD`, `STAND_COUNT`, `STAND_SPACING`, `HALF_SPAN` and
   `EXIT_Z`. **Decide explicitly whether they are removed or kept**, and if kept, say how a reader
   is stopped from meaning "the road layout" when it means "the live one". `EXIT_Z` in particular is
   a CONSTANT today and is −2377, which is NORTH of the `ride` line at −2600 — so a boar on the ride
   would vanish before reaching the hunters. It cannot stay a constant.
3. **THE ONE WRITER, AND HOW THE CLIENT LEARNS THE ANSWER** (rule 3). The server's forest owner
   chooses; the client reads. Name the owner, the moment it chooses (which phase), the transport
   (the note proposes an attribute on `ReplicatedStorage`, the mechanism `Flags` already proves
   replicates), and what a client does before the first publish and if the attribute is missing.
   Say explicitly that the client never chooses and never derives.
4. **WHAT REBUILDS WHEN THE LAYOUT CHANGES**, in order: `ForestTest.Markers.build` (the one writer
   of `Workspace.ForestMarkers`), the stand rings, the hunter's locked pick, the bots' lanes, the
   resting wood, the hunter's map and the compass. Say which of those are already rebuilt per drive
   and which are new, and say what happens to a player standing on a stand that the next layout does
   not have (the `ride` has 5 stands, the `road` has 9 — stand 7 exists in one and not the other).
   **This is the most likely source of a real bug and the design must answer it.**
5. **THE VALIDATION, AS SPECS.** What must be true of EVERY layout in the table, asserted by a spec
   that would fail if someone added a bad one:
   * every stand's x is inside the layout's own span and the stands come out sorted ascending;
   * the beaters' start line is strictly NORTH of the stand line, and north of where the animals are
     released, so a beater is behind them;
   * the exit is strictly SOUTH of every point of the stand line, by a stated margin;
   * the beaters' walk is the same ~120 s in every layout;
   * the lane spacing equals the layout's stand spacing (the task-167 reason, which must survive);
   * **no layout's corridor contains the lodge.** `tests/server/lobby.spec.luau` asserts
     `forest.z < ForestTest.EXIT_Z` and `CENTRE.Z - forest.z > 500` today; with the `edge` layout's
     exit at −3250 the first is false. Say what the honest replacement assertion is (the note says:
     a distance from every layout's corridor, not a z comparison) and which owner states it.
6. **THE BAG, WRITTEN OUT** as pseudocode with the boundary case, plus where its state lives (it
   must survive a drive boundary and must NOT survive a server restart in a way that hides a bug),
   and what `DHForestLayout` does to it.
7. **WHAT IS MEASURED AND WHAT IS ASSUMED.** The design must mark every number it carries as either
   measured (note §5 has it) or assumed, and nothing may be assumed that §5 could have measured.

## 3. Out of scope for the design

* The real map (`Map` + `MapGen`) in the DEV place. This is the Forest Test's geometry only. Say in
  one sentence how the same record would be fed by `MapGen` later, and stop.
* Any new model, mesh or upload. A "high seat" needs none of them and is not shipped anyway.
* Any change to the boar's behaviour, the horn, the weapon, the shop or the lobby, beyond the lodge
  assertion in §2.5.
* Tuning the drive's length, the stand radius, the spook reaches or the wave rhythm.

## 4. The time box

4 hours for design plus a first working version. If the design wants something that cannot be built
and reviewed in that, say which part is the minimum that gives Karen **two new places to stand** and
mark the rest as a later task.

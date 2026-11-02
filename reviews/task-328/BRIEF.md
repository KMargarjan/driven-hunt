# Task 328 — design brief for the ARCHITECT: the grid's terrain and its forest

Written by the Builder, carrying the Director (2026-11-02). Input to
`tools/architect.ps1 design grid-terrain --task 328`. It **overrides anything older** in `docs/`,
`TASKS.md` and the existing designs where they disagree (`docs/ARCHITECT_PROMPT.md`).

**Read first, in this order:**
1. `reviews/task-328/SWARM_DESIGN.md` — five designers, a merge, a Builder code read. **Sections 1–4
   and the B1–B11 table are decided. Do not re-open them.**
2. `docs/research/2026-11-02-terrain-v2.md` — this task's research note (rule 1): the external
   sources with licences, and **three of the swarm design's numbers refuted by measurements this
   repository already holds**. §6 below is those three, and they are the only parts of sections 1–4
   that are open.
3. `docs/design/grid-map.md` §4.4, §4.5, §8.1–8.4 — what this supersedes.

Karen, 2026-11-02 ~08:05 UTC: _"Terrain what I explained previuosly how it has to be … (we kee same
trees we have do not make same as on image colours ect) I need perfect terrai … not broken trees
hanging or to inside"_. Then: _"we wait results then start to implement if it make sense"_.

## 1. Scope, and what this document is

`docs/design/grid-terrain.md` is **new**, and it is the design for one layer: **the ground of the
eight cells, and the forest standing on that ground.** It is not a rewrite of `grid-map.md`, which
keeps the cells, the roads, the stands, the vote and the round flow.

**It must open with a supersession table** — one row per `grid-map.md` section it displaces, with
what replaces it — because two documents describing the same ground is the second-writer failure
rule 3 exists to stop. At least these:

| `grid-map.md` | Was | Becomes |
|---|---|---|
| §4.4 | _"for `grid:v1` the relief is Karen's existing bought terrain … **No terrain height is written anywhere**"_; **open decision D-5** | **D-5 is closed, sculpt.** Relief = the measured base + one baked landform a cell. The four measured `relief` fields keep their shape and are re-filled by the post-bake survey |
| §4.5 | the tree recipes | `CELL_PLANS` v2: landform, rides, cuts, per-zone jitter / relief bias / floor, field, standTypes, crown clearance, scale floor 0.35 |
| §8.1–8.3 | per-drive `Slice` planting and its budget | Edit-time prebuild + border wood + the v2 budgets; `Slice` **kept** as the measured fallback (rule 7) |
| §8.4 | the ground rule by reference | unchanged in substance — `TreeGround` stays the one owner (§6.1) |
| §3.1 owners | `Ground.paintRoads` owns the roads' material at run time | the Edit-time paint pass owns shape **and** material together; `paintRoads` is archived (rule 7) |
| K-6 | open | closed |

## 2. Decided — do not re-open

**SWARM_DESIGN sections 1, 2, 3 and 4 in full**, except the three items in §6 below. In particular:

1. **Sculpt, once, at Edit time, on the measured base, after a backup** (§2.3 conflict 1). The eight
   landforms and their per-cell recipes (§2.1, §2.2) are decided, including D1's field in a 10-st
   dish with no rim and B2's plateau-and-edge.
2. **Our trees only** — the 7 groups of `Places.SPECIES`, 61 models. No new pack, no recolour.
3. **One tile pass writes shape and material together.** Runtime `paintRoads` is archived (conflict
   12).
4. **Prebuild and save, with per-drive planting as the fallback** behind the 328g performance gate
   (conflict 13).
5. **Stand types** keyed by (cell, index), neighbours never equal, ≥ 5 types a cell; the lane rule;
   the pads and the front cone (§3.3).
6. **B1–B11 in full**, as written in §2.4: the FT place guard checked **before every mutating call**;
   the base snapshot (B2); the `Workspace.Archive_SavedTrees_2026-11` archive by re-parenting only
   (B3); `StreamingMinRadius` as a NEEDS KAREN click (B4); `refused` printed not gated in 328b (B5);
   the map-switch exception and the pre-328d part survey (B6); no run without `--backup` (B7); the
   2-column ditch (B8, but see §6.3); the 400-fern hard cap (B9); the template audit's definitions
   (B10); and the blast-radius scopes `lobby` / `places` / `map` / `match`, **one-player gate, no
   path in `TWO_PLAYER_PATHS`** (B11).
7. **The task split** of §5.3 (328a…328i) is the Director's. The design may re-cut **what is in**
   each task, and must say so plainly if it does, but 328a is docs-only and 328d is blocked on Q1.

## 3. The four open points of SWARM_DESIGN §7 — settle each

1. **The epoch's inputs.** The design hashes `base-snapshot sha ‖ Relief data JSON ‖ BAKE_VERSION`;
   the Builder had put the **code commit** in. **Rule:** a commit-based epoch fails the census after
   every paperwork commit, which would make the census a liar on every review round. Settle it, and
   say what bumps `BAKE_VERSION` and who is obliged to bump it.
2. **The ditch and the trunk minimum.** B8's 2 whole voxel columns at d 22–30 (8 st wide, 2 st deep)
   move the trunk minimum from 33 to **34 st**. Confirm or replace. The 4-stud voxel is the floor on
   any vertical detail (note §4.1), so a 2-st-deep ditch cannot be narrower than this.
3. **The unmeasured budgets stay targets**: 8 s a tile, 6 GB of Studio memory, a 150 MB place file, a
   90 s save, ~70 min for 1,053 tiles, +25–40 MB. Say in the design **which task measures each**, and
   that no gate may cite one of them as evidence before it is measured.
4. **B2's bot climb of the 24° scarp is unmeasured.** The default fix if the bot cannot climb it is a
   third ramp at u .50. Decide whether the scarp ships at 24° at all before 328h measures it.

## 4. Karen's questions (SWARM_DESIGN §6), with their defaults

| # | Question | Default | Status |
|---|---|---|---|
| **Q1** | **May we permanently reshape the ground in your Forest Test?** A full copy is saved first | *yes* | **UNANSWERED. 328d does not start until Karen answers. The default is not assumed** (B6) |
| Q2 | Build the whole forest once and save it (no pop-in), rather than planting per round (~7 s of trees growing in)? | *build once* | default taken; the per-round path is kept as the fallback |
| Q3 | D1's field is a green meadow with tractor stripes and a hedge — we have no crop model. Acceptable? | *yes* | default taken (styling never blocks) |
| Q4 | Flank hunters: keep today's rule, no shots into the drive within ±45°? | *keep* | default taken; **out of scope in this split** (conflict 15) |
| Q5 | Row 1 low looking uphill, row 2 high looking down. Keep it? | *keep* | default taken |

Q2–Q5 are proceeding on their defaults, so the design is written to them. **Only Q1 blocks a task.**
The design must name, in one place, what Q1 changes if Karen says no — the honest answer is that a
no ends the sculpt and the design falls back to `grid-map.md` §4.4's measured relief, with §2–§4's
landforms deleted and the forest layout kept.

## 5. What the design must contain (beyond `ARCHITECT_PROMPT.md`'s list)

1. **Owners, one writer each, named** (rule 3), extending `grid-map.md` §3.1 rather than restating
   it. Say explicitly who owns: **terrain height**, **terrain material**, **the trees** (both the
   Edit-time prebuild and the runtime fallback — if those are two writers, say why that is not a
   second writer of the same state), **the ground-contact arithmetic**, **the census**, **the epoch
   attribute**, and **the saved-tree archive**.
2. **`Relief.luau` is pure** and its data is separable from its arithmetic, because every landform
   has to be assertable in a spec with no terrain in the world.
3. **The seam the tool crosses.** `tools/terrainbake.py` runs in Karen's FT, where Rojo serves
   nothing: say how the Luau it sends and the modules in `src/` stay **one copy of the arithmetic**
   (`tools/forest_ground.py` reads `TreeGround`'s own source and injects it — the precedent to
   follow or to better).
4. **How each claim is tested**: which server spec, which `SCOPE_SPECS` scope each new spec file
   joins (standing rule G: a spec in no scope turns CI red), and — for anything only Karen's place
   can show — which FT probe line and which frame, at what camera height.
5. **The refusal shape** for `terrainbake.py`: Edit mode, the right `PlaceId` before every mutating
   call, a clean tree, a usable `--backup`, exit codes 0/1/2, one pasteable report line
   (`tools/mapgen.py` is the precedent).
6. **Open decisions**, split into those needing Karen (feel) and those needing the Director (scope).

## 6. Three numbers in the swarm design are refuted by measurement — settle them

These are **not** re-openings of taste. Each is a case where SWARM_DESIGN contradicts a figure
already measured in this repository, and the research note carries the arithmetic.

### 6.1 The contact rule is `TreeGround`'s, and §3.5 regressed it

`src/shared/TreeGround/init.luau` and `src/server/Places/init.luau` already seat every tree, and
their constants were measured on **this** forest after Karen's _"look at the trees wtf"_:

| Quantity | Measured, shipped | SWARM_DESIGN §3.5 |
|---|---|---|
| contact point | the **trunk/root junction**, `junctionY = minY + (maxY − minY) × clawFraction` | _"Trunk bottom = low − sink"_ — **the pre-fix rule Karen photographed** |
| sink | `min(0.6, 0.1h)` → 0.6 st | `clamp(0.03h, 0.5, 2.0)` → 1.8 st at 60 st, 2.0 at 156 st |
| spread accepted | `max(4.0, 0.10h)` | flat **3.0** — tighter than the measured 90th percentile (2.10) **and** than the shipped rule, so it inflates the refusal rate §3.5 then caps at 8 % |
| samples | **25** (`samples(box, 4)`, 5 × 5) | 29, undefined |
| floating | `TOLERANCE_STUDS` **0.2** | census `> 0.25` |

**The Builder's position, for the Architect to rule on:** `TreeGround` stays the one owner of the
contact arithmetic and keeps its measured constants; §3.5 is read as *what the census must check*,
not as new arithmetic. The genuinely new parts of §3.5 — the **template audit** and **quarantine**
(B10) — are kept whole, because nothing in the repo stops a broken template at the source.

**The prerequisite nobody has:** `Places.TEMPLATE_DIMS` **does not exist** (no hit in `src/` or
`tools/`), and `Places.CLAW_FRACTION` holds **5 entries, all silver birch**, against the **61**
models of `Places.SPECIES`. `Places.clawFor` returns **0** for a model it has no number for — so
today, for 56 of 61 models, the junction rule silently degrades to the lowest-point rule Karen
rejected. **Measuring claw fractions, reference extents and crown half-widths for all 61 is work
inside 328b**, and the design must say so rather than assume the data.

### 6.2 The crown arithmetic fails its own rule — this is Karen's defect

SWARM_DESIGN §1.4: _"no crown hangs over a road or a stand"_. Two places break it.

- **Roads (§3.1).** `trunkMin = max(34 + r, 22 + ½·crown·scale + 2)` with `crown` defined (B10) as
  the **half-width**. So the trunk sits at `24 + 0.5·hw` and the crown's edge lands at `24 − 0.5·hw`
  from the centreline. The carriageway is ±10 st, so the crown clears it only while **hw ≤ 28 st**;
  at hw = 39 the crown edge is **4.5 st from the road centre**, over the road. **The term grows at
  half the rate the crown does**, so it fails for exactly the biggest trees.
- **Rides (§3.2)** carry **no crown term at all**: trunk-free 36 st, trunks **18 st** from the
  centre. A conifer's crown half-width is ~0.15–0.25 of its height, and our spruces are a measured
  **56–156 studs** tall (`Places.SPECIES`), so hw ≈ 23–39 st for a mature one: **5–21 studs of crown
  across the centreline.** That is _"broken trees hanging"_, guaranteed by the geometry.

**Two candidate fixes; the Architect picks, and says which trees pay for it.** (a) Make the term
linear in the crown — `trunkMin = max(34 + r, halfCrown·scale + clearance)`, `clearance` 10 st to
clear the carriageway or 34 st to clear the verge, and **the same term for rides**
(`halfCrown·scale + 18`). At hw = 39 that is 73 st from a road centre and 57 st from a ride centre,
which thins the roadside wood considerably — a real cost, not a free fix. (b) **Species by
frontage**: only birch and larch within one crown of a road or ride, spruce set back — which costs
no density and which the design already half does (A1's _"spruce on the west side and broadleaf on
the east"_, §3.1's shrub belt). Either way, **no planting task may claim the crown rule before the
half-widths are measured** (§6.1).

### 6.3 The ride is a third of a real ride

Outside practice (note §2, §5): a ride should be **≥ 1.0 ×** tree height (BASC, against shading) or
**≥ 1.5 ×** (Fieldsports Journal), and **15 m is the only published minimum width for an open space
to count at all** (BASC). The design's ride is **36 st = 10.1 m**, i.e. **0.36 ×** a 100-st tree.
Counting the design's own geometry, C1 (12.0 ha) holds **≈ 11.6 %** qualifying open space — scraping
into BASC's 10–25 % band **on its roads alone**, because not one ride is wide enough to count.

**Decide:** widen the trunk-free ride to **≥ 54 st (15.1 m)** — which puts C1 at ≈ 17 %, mid-band —
or record in the design why a narrower ride is right for a game sightline and accept that the
published minimum is not met. It is separate from §6.2 and does not by itself fix the crowns.

## 7. Verdict

`ARCH_RESULT.md` = `PASS` if `docs/design/grid-terrain.md` is complete and buildable as written.
Otherwise a numbered list of the **blocking open decisions** only. §6's three items are expected to
be *settled in the design*, not listed as blockers: the evidence for each is in the research note.

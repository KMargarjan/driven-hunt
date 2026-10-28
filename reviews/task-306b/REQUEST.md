# Task 306 step B2 — six stations, in DEV

Task: 306b
Round: 2
Base: 952b5649 (`task-306-range-lobby`)
Code commit: 037c7e19f959f95870713a6cfa9fe833f18c8f37

```
[harness] PASS: 34/34 checks @ 037c7e19f959f95870713a6cfa9fe833f18c8f37 (clean tree) scope=all
```

`test2`: **N/A.** No path here is in `TWO_PLAYER_PATHS` (`src/shared/Range/`, `src/server/Range/`,
`tests/server/range.spec.luau`, `docs/`), and the Director's dispatch keeps `src/client/Range/` out
of it too. Nothing in this change can tell one player from two.

**CORE-NA**, in the Director's words: this step lays out stations and terrain arithmetic in DEV; it
changes no shot, no animal motion and no hit rule. The moving-target proof is B9 (T4).

## What changed

`SPOT_COUNT` 1 → **6**, `WINDOW_STUDS` 40 → **36**, `DISTANCES_STUDS` **{107, 125, 179}**, `SCREEN`
→ **`BANK`** (12 × 8 × 14), the berm's width **derived** instead of typed, the `PLATE` span and
centre sized to six stations, `footprintFor`'s new X, and the lane arithmetic taken **per station
and per distance**. The design document's two incompatible bank placements are reduced to one, in
the same commit (L-151). Karen's place is untouched: the forest row is unchanged and `RANGE` is dark.

## Round 1's two findings

1. **`bermWidthFor`'s grid snap was a no-op at the shipped numbers**, so claim 3 survived deleting
   it, and the two face lines asserted the DEV anchor rather than the rounding. **Fixed:** the case
   now drives `layoutWith({ WINDOW_STUDS = 34 })` — raw width **230**, `% grid == 2` — and asserts
   `bermWidthFor` answers **232**, i.e. `raw + 2`, rounded **UP**, and that the snapped berm still
   spans both banks. The face lines are now **anchor-relative** (`(bermMin - anchorX) % grid`), with
   a sentence saying face alignment in world space is a property of the ANCHOR, not of this
   arithmetic. Delete `math.ceil(raw / grid) * grid` and the new arm goes red.
2. **The berm's Z faces were off the grid (offsets 187/195)** under a caption claiming every edge is
   on it. **Fixed:** `BERM.behindStuds` 12 → **13**, so the centre is `distanceMax + 13` = 192 and
   the faces are **188 / 196**, both multiples of `FILL.GRID_STUDS`, asserted for both signs of
   `downrange`. §5.4's caption now says exactly which edges the grid binds: the berm and the fills
   by construction; **the two cover banks' Z cannot be, and that is arithmetic** — centred on the
   179 lane with `size.Z` 14, and no two multiples of 4 differ by 14; and **B8 must put the final
   anchor on the grid in world space** (§2.1's −3030 is not), or snap each rectangle as it fills it.
   §2.2, §5.1, §5.2, §5.4 and B1's census window all moved with the 13.

## Claims

1. **`laneCentre`/`laneEnds` are per station and per distance, and station 1's answer is what
   shipped.** `range.spec` → *"six stations: the geometry"*: station 1, station 3 and station 6 each
   have their own case, each walking all three distances and both signs of `downrange`.
2. **306a(c) is closed as arithmetic.** `bankReach` is the bank's **outer** face
   (`beyondStuds + BANK.size.X`) and `bermWidthFor` is derived from it, so the berm's faces **are**
   the banks' outer faces. The case asserts `bermMin == bankWestMin` / `bermMax == bankEastMax`, and
   computes the old centre-based width to show it failing that identity by `BANK.size.X / 2` at each
   end. Run note: `range berm: 232 studs wide, x 1144..1376 -- banks x 1144..1156 and 1364..1376`.
3. **The grid, with an arm that fails without the producer** — finding 1 above.
4. **`footprintFor` holds both banks, the berm, all six mats and all six prompts, both ways, and
   reaches the berm at the LONGEST lane** (179, not the 125 the menu opens on); so does `fieldFor`,
   or an ordered target on the 179 lane is out of bounds the moment it is led.
5. **Every part the DEV build lays except the plate stands over the plate and inside the
   footprint** (the plate cannot stand over itself; the case excludes it, and claim 5 of round 1
   overstated that — corrected here). It bites: a plate centred on the anchor spans 1062..1338 and
   stops **38** studs short of station 6's own bank.
6. **Six of everything, each prompt out of reach of its neighbour's:** `atSpot` true for his own and
   false for all five others, every pair ≥ `2 × MaxActivationDistance` apart, `spotAt` answers his
   own number, `optionAllowed("spot", n)` true for 1..6 and false for 7.
7. **The menu offers the three lanes that are built** and nothing else; `distanceMax` is 179;
   `DISTANCES_STUDS` is the layout's own list, not a second copy.
8. **The old site is refuted, and measured:** a layout with `SPOT_COUNT = 1` and one distance still
   fits the sampled rectangle; six do not — by **96 studs east and 19 south**. Design §2.3's own
   finding; **B8** moves the row and re-samples.
9. **Two screenshots, looked at** (rule 5), camera = the player's own eye on the mat, ~5.6 studs over
   the plate. `<runs-dir>/306b2-lane1.png`: from mat 1 — the green mat underfoot, the olive post
   with its prompt at the mat's front edge, the berm as a dark wall across the whole far end with
   boars crossing in front of it, the east bank's block at the right. `<runs-dir>/306b2-lane6.png`:
   from mat 6 — the berm's **west** end and the west bank away to the left, the berm running east
   past the frame's edge; lane 6 is backed by earth across its whole window. **Caveat:** `capture`
   in Play ignores its camera arguments and shoots the player's own camera, so each frame was taken
   by standing the character on that mat facing +Z. **These are DEV, not her place** — see below.
10. **The live DEV build matches the arithmetic.** Server probe in Play (`<runs-dir>/306b2-probe.luau`,
    taken at `8bcd9b16`, before `behindStuds` moved the berm 1 stud downrange):
    `parts=16 prompts=6 animals=6 box x 1122..1398 z -40..219`, `BankWest 1150`, `BankEast 1370`,
    `Berm 1260 size 232`, `Mat1..Mat6` at 1200..1320 on 24s. 0 console lines matching "Stack Begin",
    "attempt to" or "invalid argument".

## What this leaves open, and what is NOT proven

- **NOTHING HERE HAS BEEN SEEN IN KAREN'S PLACE, and rule 5 is met for DEV only.** `RANGE` is
  `default = false`, `RangeBoot` returns before building, and the `forest-test` row is untouched, so
  the six stations exist only in DEV (`map:v1`, x 1200). **NOT PROVEN in her place: claims 9 and 10.**
  Step **B8** is what puts them there.
- **`boars.clear` is range-WIDE** (`Boar.Runtime:clear` is the only clear there is; no per-id despawn
  exists), so with six trials one man's carcass takes the other five stations' animals and all six
  re-release. **Not fixed here** — a per-id despawn is another owner's module and is not in §16's B2
  list; **B7** is where it closes. It is written into the spec as a number (`2 × SPOT_COUNT` spawns,
  `SPOT_COUNT - 1` `lostTargets`) so B7 breaks that case the moment it fixes the behaviour, and the
  case says in words that this is the defect. The owner likewise runs six trials with nobody there.
- **`Hud` resolves `promptFor(1)` only**, so the five new prompts open no menu — station 1 behaves
  exactly as it shipped and `RANGE` is dark. No §16 row owns it (it falls between B5 and B6); queued
  in `TASKS.md` 306b.
- **`onRequest` writes a new `distanceStuds` straight onto a live trial** with no clear and no window
  reset, so an animal mid-window when its man switches 125 → 179 is led diagonally and that crossing
  spans the transit. Queued for **B4**, which is where the crossing times are measured.
- `footprintFor`'s uprange Z keeps its shipped edge (§2.2's `STAND`/`HighSeats` term is **B3**'s);
  §5.4's terrain, fills and side banks are **B8**'s; §2.2's four literal numbers are for the **new**
  anchor, which B8 sets — no case retypes them (306a note (k)).
- Round 1's remaining notes (the `box.minX == bermMin - margin` pair reading stronger than it is, and
  the `reach > DISTANCE_STUDS` tautology) are left as written and queued; the Z identity against
  `distanceMax` and the mat / prompt / `fieldFor` loops are what carry that case.

ANSWERED: L-151 — the design carried two bank placements; I picked ONE, in the same commit as the
code. `beyondStuds` is the clearance to the bank's NEAR face (task 298's measurement, and what the
shipped `screenPosition` did), so the outer face is `beyondStuds + BANK.X` past the corridor's end
and the berm is derived to reach it: §2.2, §5.1, §5.2, §5.3, §5.4, §2.5 and B1's census window all
corrected — banks x 2544..2556 / 2764..2776, berm 2544..2776 (232), footprint x 2532..2788,
z −3238. Round 2 added the grid rule's exact scope to the same section.
ANSWERED: L-095 — every assertion derives from `Range.footprintFor` / `LAYOUT` / `bermSpanFor` /
`bankSpanFor`; not one of §2.2's four numbers is typed in the spec.
ANSWERED: L-136 — no FAIL line is claimed in this evidence; the gate is a clean 34/34 at the code
commit, so nothing is called a flake and no control run was needed. (For the record: two client
cases, `gun_client.spec:81` and `:833`, went red in two earlier runs at earlier commits and green at
the code commit, with no client file touched in this branch. No claim rests on them.)
ANSWERED: L-127 — every claim above is MET and evidenced; the items under "what this leaves open"
are stated as NOT PROVEN or NOT DONE, with the step that closes each, never as passes.
ANSWERED: L-093 — station 1, a middle station (3) and station 6 each have their own `it(...)`, each
walking all three distances. FAIL FIRST, split honestly: the single-animal assumptions were **seen
red** at `ae709bcd` and `ceed6f57` (`<runs-dir>/306b2-t1.log`, 5 red; `306b2-t2.log`, 4 red) and are
green at the code commit; the grid-snap arm added in round 2 is **argued to bite by construction**
(delete the `math.ceil` and `bermWidthFor(offGrid)` answers 230, not 232) and I did not run a build
with the snap removed; the plate shortfall (1062..1338 against an east bank outer face at 1376 = 38
studs) is computed from the built plate rather than watched going red.

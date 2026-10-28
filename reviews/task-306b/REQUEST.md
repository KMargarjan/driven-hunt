# Task 306 step B2 — six stations, in DEV

Task: 306b
Round: 1
Base: 952b5649 (`task-306-range-lobby`)
Code commit: 8bcd9b168e720e4d404bea82f9b654342eab6ab5

```
[harness] PASS: 34/34 checks @ 8bcd9b168e720e4d404bea82f9b654342eab6ab5 (clean tree) scope=all
```

`test2`: **N/A.** No path in this change is in `TWO_PLAYER_PATHS` (`src/shared/Range/`,
`src/server/Range/`, `tests/server/range.spec.luau`), and the Director's dispatch says
`src/client/Range/` does not join it either. Nothing here can tell one player from two.

**CORE-NA**, in the Director's own words: this step lays out stations and terrain arithmetic in DEV;
it changes no shot, no animal motion and no hit rule. The moving-target proof is B9 (T4).

## What changed

`SPOT_COUNT` 1 → **6**, `WINDOW_STUDS` 40 → **36** (10.00 m), `DISTANCES_STUDS` **{107, 125, 179}**,
`SCREEN` → **`BANK`** (12 × 8 × 14), the berm's width **derived** instead of typed, the `PLATE` span
and centre sized to six stations, `footprintFor`'s new X, and the lane arithmetic taken **per
station**. The design document's two incompatible bank placements are reduced to one in the same
commit (L-151). Nothing in Karen's place changes: the forest row is untouched and `RANGE` is dark.

## Claims

1. **`laneCentre`/`laneEnds` are per station and per distance, and station 1's answer is bit-for-bit
   what shipped.** `range.spec` → *"six stations: the geometry"*, three cases: station 1, station 3,
   station 6, each walking all three distances and both signs of `downrange`.
2. **306a(c) is closed as arithmetic.** `Range.bankReach` is the bank's **outer** face
   (`beyondStuds + BANK.size.X`), and `bermWidthFor` is derived from it, so the berm's two faces
   **are** the two banks' outer faces. Case *"derives a berm that spans every station's lane AND both
   banks, to the stud"* asserts `bermMin == bankWestMin` and `bermMax == bankEastMax`, and in the
   same case computes the old centre-based width and shows it **failing** that identity by
   `BANK.size.X / 2` at each end. Live note from the run:
   `range berm: 232 studs wide, x 1144..1376 -- banks x 1144..1156 and 1364..1376 (the centre-based 220 left 6 out at each end)`.
3. **The berm is on the terrain grid.** Same case: the width and both faces are multiples of
   `FILL.GRID_STUDS`.
4. **`footprintFor` holds both banks, the berm, all six mats and all six prompts, both ways, and its
   Z reaches the berm at the LONGEST lane** (179, not the 125 the menu opens on). So does `fieldFor`,
   or an ordered target on the 179 lane is out of bounds the moment it is led. Case *"holds both
   banks, the berm and all six stations inside footprintFor, both ways"*.
5. **Every part the DEV build lays stands over the plate and inside the footprint.** Case *"stands
   every part it builds over the DEV plate"* — it bites: a plate centred on the anchor (as it was)
   stops 38 studs short of station 6's own bank. Note: `range DEV: 16 parts (plate 276 x 259) all
   inside the footprint x 1132..1388 z -16..207`.
6. **Six of everything, each station's prompt out of reach of its neighbour's.** Case *"gives each of
   the six its own prompt"*: `atSpot` is true for his own and false for all five others, every pair
   ≥ `2 × MaxActivationDistance` apart, `spotAt` answers his own number, and `optionAllowed("spot", n)`
   is true for 1..6 and false for 7.
7. **The menu offers the three lanes that are built** and nothing else; `distanceMax` is 179;
   `DISTANCES_STUDS` is the layout's own list, not a second copy.
8. **The old site is refuted, and that is measured rather than asserted.** `range.spec` →
   *"OVERFLOWS the clearing that was measured for ONE station"*: a layout with `SPOT_COUNT = 1` and
   one distance still fits the sampled rectangle, and six do not — by **96 studs east and 19 south**.
   That is design §2.3's own finding; **step B8** moves the row and re-samples. Nothing is built in
   her place meanwhile, because `Range.ENABLED` is dark.
9. **Two screenshots, looked at** (rule 5; camera height = the player's own eye at the mat, ~5.6
   studs over the plate). `<runs-dir>/306b2-lane1.png`: from mat 1, the green mat underfoot, the
   olive post with its prompt at the mat's front edge, the berm as a dark wall across the whole far
   end with boars crossing in front of it, and the east bank's block at the right of the frame.
   `<runs-dir>/306b2-lane6.png`: from mat 6, the berm's **west** end and the west bank are away to
   the left and the berm runs east past the edge of the frame — lane 6 is backed by earth across its
   whole window. **Honest caveat:** `capture` in Play ignores its camera arguments and shoots the
   player's own camera, so each frame was taken by standing the character on that mat facing +Z.
10. **The live DEV build matches the arithmetic.** Server probe during Play
    (`<runs-dir>/306b2-probe.luau`): `parts=16 prompts=6 animals=6 box x 1122..1398 z -40..219`,
    `BankWest 1150`, `BankEast 1370`, `Berm 1260 size 232`, `Mat1..Mat6` at 1200..1320 on 24s.
    0 console lines matching "Stack Begin" / "attempt to" / "invalid argument".

## What this leaves open, and what I could not verify

- **`boars.clear` is range-WIDE** (`Boar.Runtime:clear` is the only clear there is; no per-id despawn
  exists), so with six trials one man's carcass takes the other five stations' animals and all six
  re-release. **Not fixed here** — a per-id despawn is another owner's module and is not in §16's B2
  list; design **B7** ("one animal per occupied station") is where it closes. It is **written into
  the spec as a number** (`2 × SPOT_COUNT` spawns and `SPOT_COUNT - 1` `lostTargets`), so B7 breaks
  that case the moment it fixes the behaviour. The `RANGE` flag is dark, so no shipped game changes.
- The owner also runs six trials with nobody at the range. Same step, same reason.
- `footprintFor`'s **Z** keeps its shipped uprange edge; design §2.2's `STAND`/`HighSeats` term is
  **B3**'s, as is the treestand, and §5.4's terrain, fills and side banks are **B8**'s.
- §2.2's four literal footprint numbers are for the **new** anchor (2600, −3030), which B8 sets. No
  case retypes them; every assertion is derived from `LAYOUT` (306a note (k)).
- Two client cases (`gun_client.spec:81`, `:833`) failed in two earlier runs at earlier commits and
  passed at the code commit, with no client file touched in this branch. No FAIL line is claimed as
  known or flaked; the evidence above is a clean 34/34.

ANSWERED: L-151 — the design doc carried two bank placements; I picked ONE in the same commit as the
code. `beyondStuds` is the clearance to the bank's NEAR face (task 298's measurement, and what the
shipped `screenPosition` did), so the outer face is `beyondStuds + BANK.X` past the corridor's end
and the berm is derived to reach it: §2.2, §5.2, §5.3, §5.4, §2.5 and B1's census window all
corrected to banks x 2544..2556 / 2764..2776, berm 2544..2776 (232), footprint x 2532..2788.
ANSWERED: L-095 — group 1's cases derive from `Range.footprintFor` / `LAYOUT` / `bermSpanFor` /
`bankSpanFor`; not one of §2.2's four numbers is typed in the spec.
ANSWERED: L-136 — no FAIL line is in this evidence; the gate is a clean 34/34 at the code commit, so
nothing is called a flake and no control run was needed.
ANSWERED: L-127 — every claim above is MET and evidenced; the two items under "what this leaves
open" are stated as NOT DONE with the step that closes them, not as passes.
ANSWERED: L-093 — station 1, a middle station (3) and station 6 each have their **own** `it(...)`,
and each walks all three distances, as does each new arm of the bank/berm/footprint arithmetic.
FAIL FIRST, honestly split: the single-animal assumptions (`fake.only()` returning an arbitrary one
of six, and the carcass count) were **seen red** at `ae709bcd` and `ceed6f57` — logs
`<runs-dir>/306b2-t1.log` (5 red) and `306b2-t2.log` (4 red) — and are green at the code commit.
The berm identity and the plate span are argued **by arithmetic inside the case rather than by a
run**: the berm case computes the old centre-based width and asserts it fails the identity by 6 at
each end, and the plate case's shortfall (1062..1338 against an east bank outer face at 1376 = 38
studs) is computed from the built plate; I did not build a deliberately wrong plate to watch it go
red.

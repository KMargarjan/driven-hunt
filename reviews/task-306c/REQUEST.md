# Task 306 step B3: the treestand as data — ground OR treestand at every station

Task: 306c
Round: 1
Base: ccb6e3e9 (`task-306b2-six-stations`)
Code commit: 49bef9395f01a9be669e4e2502add7a3f74a0cf2

```
[harness] PASS: 34/34 checks @ 49bef9395f01a9be669e4e2502add7a3f74a0cf2 (clean tree) scope=all
```

`test2`: **N/A** — no changed path is in `TWO_PLAYER_PATHS` (`tools/agents.py`'s `needs_two_player`
answers `[]` for this diff). The range is the weapon/boar/hud family; one player answers every claim
below.

Built to `docs/design/shooting-range-lobby.md` §16 row B3 (§7.1–7.3, §9.1–9.2). Changed:
`src/shared/HighSeats/init.luau`, `src/shared/Range/init.luau`, `src/server/Range/Build.luau`,
`src/server/Range/init.luau`, the two specs, the design and `TASKS.md` row 306c.

## Claims

1. **`HighSeats.plan`/`footprint` take a `facing` sign that mirrors the ladder, the rail's gap and
   the ladder's ground sample — AND NOTHING ELSE.** Verify: `high_seats.spec`, the two new cases.
   The mirror case walks all 14 pieces, collects every piece whose Z moved and asserts the set is
   exactly `Ladder,RailN,RailSE,RailSW`, each mirrored about `stand.Z`; `facing` nil and `+1` are the
   same 14 pieces, piece for piece. Girt, braces, legs and deck do not move.
2. **The sign is turned WITH the row, not typed.** `Range.standFacing(layout, downrange)`: a constant
   `−1` puts the ladder DOWNRANGE in DEV (L-019). Verify: `range.spec` "lays a bench and a 14-piece
   seat at every station, with the ladder and the gap UPRANGE" builds for `downrange` **+1 and −1**
   and reads the mirror off the BUILT parts. Live DEV (`<runs-dir>/306b3-stand.luau`, in Play):
   `Mat1 z 0.0 | Deck centre 1200.0,12.2,-14.0 top 12.50 | Ladder z -18.0 | RailN z -11.1 |
   RailSE z -16.9` → ladder and gap uprange, solid board downrange, all true.
3. **`Range.spotAt` answers (station, firing position), measured, over the UNION box of the two
   positions.** `bench` on the mat; `treestand` on the deck rect at or above `HighSeats.minYFor` with
   no margin; the station with NO position under the deck or beside it; nil one stud outside any
   face; nil half way between two stations. Verify: `range.spec` "the two firing positions", five
   cases, both signs of the lane, every station.
4. **A refused seat is a bench, as DATA.** `deckTops[spot]` simply absent → `spotAt` can never answer
   `treestand` there, and nothing branches. Verify: the pure case (`tops[3] = nil`) and the Build case
   that feeds a ground reader a 5-stud step under station 3's ladder foot: `stands` 5, `refusedStands`
   1, no `Stand3`, no `RangeStandPrompt3`, and its mat, bench and bench prompt untouched.
5. **A second prompt per station, found by name.** `RangeStandPrompt<n>` on the deck at the rail's
   top (`deckTop + STAND.promptRise`). Verify: `range.spec` "gives every station TWO prompts…" —
   the built prompt equals `promptPosition(…, "treestand")`, the deck is within reach of its own
   stand prompt and NOT of its bench prompt, a man on the mat cannot reach the stand's, and no two
   stand prompts are within `2 × MaxActivationDistance`. Live DEV: 12 prompts, 6 of them stand
   prompts; `RangeStandPrompt1 at 1200.0,14.90,-16.9 — 26.4 studs from RangePrompt1, reach 12`.
6. **`Range.distanceFor` adds the 14 studs the deck stands back**, at all three lanes, and the board
   record carries the SERVER's measured position. Verify: the `distanceFor` case, and
   `range.spec` "Range.positionOf and the board's distance" — a man on the deck tallies
   `DISTANCE_STUDS + 14`, the same man on the mat tallies `DISTANCE_STUDS` in a FRESH record, and a
   man under the deck gets `position = nil` and the bench's distance.
7. **`Build` measures each seat's own five footprint points through the injected `groundAt`** (the
   plate arm takes no ray at all) and records `deckTops`. Verify: the Build cases; `deckTops[spot]`
   equals the built Deck part's own top face and `shelf + DECK_RISE_STUDS`; on the SLOPING arm each
   leg and the ladder sit embedded at THEIR OWN ground (`range.spec` "lays every part on the ground
   it is handed"). Live DEV: `[range] built in 2 ms (106 parts, 6 stands, 0 refused)` — T9's ≤ 160
   parts and ≤ 300 ms, against the designed 106.
8. **`footprintFor` now reaches the seat's feet uprange and its edges are whole studs, rounded
   OUTWARD.** The seat's 5.1-stud radius made the uprange edge fractional, and `lobby.spec`'s
   round-trip case read the rectangle's own corner a ten-thousandth outside itself (a `Vector3` is
   float32). Verify: `range.spec` "holds every deck, ladder foot and stand prompt inside
   footprintFor, both ways"; `lobby.spec` is green at this commit.
9. **FAIL FIRST (L-093).** Five mutations at once, one harness run at `ccb6e3e9`+dirty, each new arm
   entered by its own case: `standFacing` sign flipped → the refusal case (`range.spec:1138`) and the
   forest-overflow case (`:2813`) red; `distanceFor` ignoring the deck → `:957` and the server case
   `:2223` red; `spotAt` dropping the deck-face height test → `:884` red; `plan` ignoring `facing`
   for the rail → `high_seats.spec:361` red; `Build` recording no deck tops → `:1041`, `:1104` red.
   8 failed / 8 errors against 34/34 green with them reverted.
10. **Measured, and NEW: the treestand is a THIRD overflow of the old forest clearing** — 11.1 studs
    BEHIND the firing line, so even ONE station no longer fits the rectangle sampled in task 298.
    Written into the design's §16 for B8's census. Verify: `range.spec` "OVERFLOWS the clearing…".

## What could NOT be verified

- **The real `E` on a stand prompt opening the station menu: NOT PROVEN.** `Hud` resolves
  `RangeData.promptFor(1)` only (306b's queued note (i), which no section-16 row owns), so the eleven
  other prompts — the five bench ones and all six stand ones — open no menu yet. This step lays the
  prompt and its name; the Hud wiring needs a row.
- **Climbing the ladder: NOT ESTABLISHED** (design §11.4's own row). The player on the deck in the
  live frames was PLACED there (`PivotTo`), which proves the geometry the server's rule reads, not
  that a climb lands a man in that zone. L-147: this is not offered as climb evidence.
- The board does not PRINT `position` — design §11.3's `range_panel.spec` extension belongs to B6's
  payload work with `mine`/`window`.

## Screenshots (rule 5), looked at

- `<runs-dir>/306b3-deck-lane.png` — station 1's deck, first person, looking downrange: the rail
  board and deck planks under the gun, the lane plate running away, the berm as a dark wall across
  the far end with a cover bank at its right.
- `<runs-dir>/306b3-bench-lane.png` — the SAME lane from the mat (root Y 4.15 against 15.65 on the
  deck): the post is now a tall block beside the gun and the berm's crest sits higher in frame. The
  two frames are the two firing positions.

ANSWERED: L-136 — no spec failed at the code commit; the one `gun_client.spec:81` red in an early
iteration run did not recur and the clean run is 34/34, so nothing is called a flake here.
ANSWERED: L-127 — every claim above is MET or carries its own NOT PROVEN line in the section above.
ANSWERED: L-093 — claim 9: every new arm is entered by its own case and each was shown red first.
ANSWERED: L-147 — the deck was reached by `PivotTo`, and that is stated as a geometry/picture proof,
never as a climb; the climb stays NOT ESTABLISHED.
ANSWERED: L-019 — the `facing` mirror is read off the BUILT parts in both lane directions (spec) and
off the live DEV build (claim 2), not from the sign in the code.

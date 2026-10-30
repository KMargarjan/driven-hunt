PASS (item 1 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the hill's SHAPE was seen in her
place — claim 9's three BEFORE/AFTER pairs at fixed camera points (bench 2, deck 2, lodge yard),
described, Karen's verdict still outstanding under L-117 — and the backstop's stopping was COUNTED
in her place (T6 180/180, a scripted sweep, not a frame). **Item 1's core subject was not seen**: the
request's own "What I could NOT verify" says no frame of a GAME-RELEASED boar standing at 179 exists
(`NO TARGET DRAWN` from `RangeRequest:FireServer` part-way through the session), so claim 2's frames
are a staged 5.5 x 3 x 2 trunk box and the released boar at d 178.5 / 1.49 over the shelf is a
reading. Whether Karen can SEE and SHOOT a released boar at 179 is still unproven by picture.

Round 1's two findings are fixed, and I checked both by re-deriving the numbers rather than reading
the claim:

- Finding 1. `Range.bermColumns` with the shipped dials (`height` 21, `crestDropStuds` 3,
  `shoulderDropStuds` 5, `shoulderStuds` 16, `crestStepStuds` 12) gives 19 columns of width
  232/19 = 12.2105. Only columns 1 and 19 have `taper < 1` (edge 6.105 / 16 = 0.3816), so their tops
  are 16.25 and 17.00; columns 2..18 are at `taper == 1` and run 19.00 / 19.50 / 18.25 / 20.50 /
  19.00 / 20.50 / 19.75 / 19.25 / 19.75 / **18.00** / 20.25 / 18.75 / 20.50 / 19.75 / 19.50 / 19.75
  / 18.25. `fan = sightHalfWidthAt(LAYOUT, 192)` = 192 * 18 / 107 = 32.299, `fanMin/fanMax` =
  anchor.X - 32.299 .. anchor.X + 152.299, and the columns whose span meets it are exactly 2..18 —
  17 of them, min 18.00, all `>= deckEye` 17.5. `inFan >= #columns - 4` is 17 >= 15 and
  `deckEye >= 17.5` is 17.5. The request's "18.00 .. 20.50 over 17 columns" is right to the stud.
  Deleting the producer kills it: `sightHalfWidthAt -> 0` leaves inFan 11 and fails `>= 15`;
  `crestDropStuds` back to 4 puts column 11 on 17.25 and fails the floor.
- Finding 2. `expect(distinct >= #RangeData.bermColumns(anchorOf(b), LAYOUT, -1))` with
  `Build.bermBoxes` returning `{}` is 0 >= 19 and fails. Round 1's vacuous pass is closed.

Rule 3(a) on the rest of the proof set: `#boxes == #columns * (1 + slopeSteps) + #scrub` = 19*5+7 =
102 fails at 0 if `bermBoxes` is emptied, so claim 7's bottom-at-the-shelf loop is no longer
vacuous; `expect(hill).to.equal(#columns)` fails at 0 if the cores are given `SURFACE.BERM`
(claim 6); deleting the `wave` term leaves 2 distinct tops against `distinct >= 4` (claim 4).
Claim 1's `|dir*(toe - at.Z) - (distanceMax + clear)| < 1e-6` IS a tautology — `bermToeZ` and
`bermToeClearance` are the same arithmetic through two names — but it is not what the case rests on:
`clear >= toeClearStuds` (5 >= 5, typed), `clear > 2.75` (the measured trunk) and the
no-box-past-`laneCentre` loop all fail with `slopeRun` back at 12.

Independently re-derived and consistent with the claims: `bermToeClearance` = 17 - 4 - 8 = 5;
crest face 192, far face 200, toe 184, terrace edge 202 (`CUT.downrangeStuds` 2) inside
`footprintFor`'s own 200 and `MEASURED.minZ` -3238; the BERM bands' far face is exactly the crest
face and the k=4 band's height is `column.top`; the scrub sits at `face - 2 .. face - 6` against a
rear face at `face - 8`. Claim 3's live profile checks out against the code: lane 2 falls on column
7, whose top is 20.50 and whose run is 6.00, which is the 20.52 crest at d 196 and the clear ground
at d 184 the probe reported, and column 7 carries no scrub (clumps land on columns 4, 6, 8, 10, 12,
14, 16), which is why d 196 reads Grass and not LeafyGrass.

## Notes (non-blocking)
- `src/shared/Range/init.luau` / `LAYOUT.BERM` comment — a THIRD pre-306l paragraph still contradicts
  the code: *"Four 2-stud bands (10 * k / 5) over a 12-stud run is a 1:1.2 batter"*, eight lines
  above `slopeSteps = 4`'s own *"over an 8-stud run six bands are 1.3 studs deep ... Four gives a
  2-stud step"*. The two the request named (the 188/196 faces, the "176 is three studs clear of 179")
  are fixed; fold this one in too.
- `src/shared/Range/init.luau` / `crestDropStuds` comment — *"the crest wanders 18..21"*. On the
  shipped dials it wanders 16.25..20.50 (18.00..20.50 inside the fan); 21 is never reached, because
  `wave`'s ceiling is 0.5 + 0.32 + 0.18 = 1.0 only where both sines peak together and they never do.
- `src/server/Range/Build.luau` / `writeTerrain` — *"The berm and the two banks are BARE EARTH
  (`SURFACE.BERM`)"* is now false: the cores and both banks are `SURFACE.HILL` (Grass) and the scrub
  is LeafyGrass. The ordering reason the paragraph gives (a grassed heap filled before the
  `AROUND -> LANE` repaint loses the bottom 4 studs of its skin) is now MORE load-bearing, not less;
  only the sentence is wrong. The request's "both `SURFACE.BERM` paragraphs in `Build.build`" did not
  cover this one, which is in `writeTerrain`.
- `tests/server/range.spec.luau` / "cuts one level terrace" — *"The berm and the banks are filled
  with the SAME material as the lane"* is stale for the second time (noted at 306j): the heap now
  writes three materials and only the impact bands share the lane's `Ground`. `isTerrace` keys off
  the bottom face, so the case is still correct.
- `reviews/task-306l/REQUEST.md` claim 1 — *"set `shoulderStuds` back to 24 and column 2 lands on
  16.75 and it fails"*. Column 2 lands on 17.75 at `shoulderStuds` 24 and still passes; it is
  **column 18** that lands on 17.00 and fails (same edge, lower `wave`). The case does die; the
  column and the number do not match. The `crestDropStuds` half (column 11 on 17.25) is exact.
- `reviews/task-306l/REQUEST.md` claim 4 — *"delete the `wave` term and the shoulder taper alone
  leaves three distinct tops"*. With `shoulderStuds` now 16 only columns 1 and 19 taper, so it leaves
  **two** (18.00 and 14.75). Round 1's "three" was computed on round 1's dials.
- `docs/research/.../9.4` — *"232 studs is 19 fills, not 58"* counts columns, not fills: the row now
  writes 19 cores + 76 bands + 7 clumps = 102 `FillBlock` calls (the old shape was ~28 after
  chunking). Nothing in the repo bounds `terrainFills`, so no case is wrong and it is a one-time
  build cost; the number in the note is what is off.
- `Range.bermScrubPoints` with `Build.bermBoxes` — `scrubSize.Z` 6 -> 4 does keep the clump's far
  face at `face - 6` clear of the rear face at `face - 8`, as claimed. But the clump box still runs
  the FULL height from the shelf (`clump.top + clump.size.Y`), so each of the seven is a LeafyGrass
  slab driven through the hill rather than a bush sitting on it. `scrubCount = 7`'s comment *"only
  its top shows, on the crest, BEHIND the bare lip"* holds from the firing line, which is the side
  that matters; round 1's note is reduced, not closed. Moving the box's bottom to `column.top`
  would close it, at the cost of the rule-E identity the case asserts.
- `tests/server/range.spec.luau` / the terrace case's new anchor — `distinct >= #bermColumns` is
  exactly what round 1 required and it does kill `bermBoxes -> {}`. It does not kill `bermBoxes` and
  `bermColumns` emptied TOGETHER (0 >= 0); what catches that is `expect(#columns > 8)` in the hill
  case, a different `it`. Worth knowing before the next hand moves these two.
- `docs/design/shooting-range.md` — the `BERM` row still reads *"160 x 10 x 6, 12 studs behind the
  lane"*; every one of those four numbers is now wrong (derived 232, 21, 8, 17 behind). Outside this
  change's job, and flagged in round 1; queue it with whichever task next opens the design doc.

---
REVIEWER verdict on commit `d190079132859d6ed6f5bb96cb7c4a20b0eb473a` (round 2) · 2026-10-30 03:40 UTC · session cost $3.28, 31 turns · written by tools/agents.py

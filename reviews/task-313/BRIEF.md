# Task 313 BRIEF: solo on the WHOLE range

Input to `tools/architect.sh design shooting-range-lobby --task 313`. **This overrides anything
older in `docs/`, `TASKS.md` and `docs/design/shooting-range-lobby.md`** where they disagree.
The base documents are `docs/design/shooting-range.md` (task 298) and
`docs/design/shooting-range-lobby.md` (task 306); this is a DELTA to the latter's sections 4.3,
4.4, 5.3, 6, 9 and 12 (T3, T6).

## Karen's words

2026-10-30 ~09:30 UTC, after playing her place:

> "hill is perfect, we will need to improve isolated view where when I click E it will make that I
> am alone in all shooting range and then we can test all way running waling ect animal, now is to
> short for one specific stand"

2026-10-28:

> "several places where they can click E and then become isolated view ... one person sees animal
> and menu and settings but can many play"

## MEASURED NOW (the defect, as numbers, read off the shipped code)

`src/shared/Range/init.luau`:

| dial | value |
|---|---|
| `LAYOUT.WINDOW_STUDS` | 36 |
| `LAYOUT.APRON_STUDS` | 20 |
| `LAYOUT.SPOT_COUNT` | 6 |
| `LAYOUT.SPOT_SPACING_STUDS` | 24 |
| `Range.laneLength` | 36 + 2x20 = **76** |
| `Range.spotSpan` | 5 x 24 = **120** |
| `Range.corridorSpan` (anchor-relative X) | **-38 .. +158 = 196 studs** |
| `Range.bankReach` | 6 + 12 = 18, so the two bank NEAR faces sit at -38 and +158 |

`Range.windowSpanFor(anchor, spot)` returns `mat.X +- 18`: a **36-stud** window centred on that
station's own mat. `Range.laneEnds` turns the animal around at `mat.X +- 38`. So the animal is in
view for 36 studs and walks a 76-stud leg.

Crossing time over 36 studs, at `Boar.CONFIG.PACE` (`RUN_SPEED` 24, `TROT_SPEED` 11,
`WALK_SPEED` 4.5) through `Range.paceSpeedFor`:

| pace | studs/s | seconds across the 36-stud window TODAY |
|---|---|---|
| walk | 4.5 | 8.0 |
| trot | 11 | 3.3 |
| run | 24 | **1.5** |
| slow (ISSF) | 7.20 | 5.0 |
| fast (ISSF) | 14.40 | 2.5 |

**1.5 s at run is Karen's "to short".** The Playtester's `playtest/range-v3/report.md` item 2
records the second half of the same defect: two players at stations 2 and 4 each saw only his own
boar, which is correct and is NOT what is being changed.

## Decisions ALREADY TAKEN by the Director - the design implements these, it does not re-open them

**(a) E at any station starts that player's SOLO view, and his animal crosses the WHOLE range.**
The crossing spans the full corridor in front of all six stations - `Range.corridorSpan`, 196 studs
- from one side bank to the other, not his station's 36-stud window. He may turn to track it.

The design must state the re-expressed crossing times over the chosen span and show the arithmetic.
Over 196 studs they are: walk 43.6 s, trot 17.8 s, run **8.2 s**, slow 27.2 s, fast 13.6 s.

**The two ISSF paces keep the ISSF definition.** `slow` is 10 m in 5.0 s and `fast` 10 m in 2.5 s;
`Range.paceSpeedFor` divides `WINDOW_STUDS` by `CROSSING_SECONDS`. If the masking window becomes
196 studs and that divisor moves with it, `slow` becomes 39.2 studs/s and `fast` 78.4 - faster than
a sprinting boar (`SPRINT_SPEED` 38) and no longer ISSF. **So the design must separate the two uses
of the one constant by name**: the number that defines an ISSF pace stays 36 and is read only by
`paceSpeedFor`; the number that defines what a man SEES and what his shot may HIT becomes the
corridor. Name both, say which function reads which, and say which `LAYOUT` rows change (ideally
none: the corridor is already derived).

**The banks already stand where the new turn-around needs them.** `bankReach` puts the two cover
banks' near faces at exactly the corridor's two ends, so a full-width leg turns around behind the
built cover with no new geometry. The design must confirm this against `Range.bankPosition` /
`Range.bankFaces` rather than assume it, and say whether `laneEnds` becomes the corridor ends for
every station or only for the solo occupant.

**(b) While solo, his client draws only HIS animal, on the whole range, and no other player.**
The existing `src/client/Range/Mask.luau` rule is kept - it is the one writer of
`LocalTransparencyModifier` under `Workspace.RangeTargets` - now with the whole-range window.
In addition, **other players' CHARACTERS standing on the range are hidden for him**, so "I am
alone" is literal.

**The Architect must NAME the owner module of that second picture** - a concrete file, not "the
Mask" - and show it is **disjoint from `src/client/Camera/Rig.luau`'s writes on the LOCAL
character** and from `Mask.luau`'s writes under the targets folder. Three sets, three owners, no
instance in two of them, and a spec that asserts the disjointness rather than describing it.
Say which instances are in scope (every other player's character model, and only while he is
solo at a station), what happens when he leaves the mat, and what happens to a character that
arrives late (the same sweep rule `Mask` uses, not a signal).

**(c) Many players still play at once, and each may HIT only his own animal.**
`Range.ignoredFor` already does this and is not re-opened. The design must show it still holds
when the window is 196 studs wide and all six animals are inside every window at once - in
particular whether `CLAIM.MAX_TARGETS` (8) can now cut a body before the ignore list excludes it,
and that `Weapon.setIgnoreProvider`'s list is applied before the candidate cap, not after.

**(d) The safety envelope (T6) is re-swept at the widest angle a station can now shoot to.**
Today's T6 sweeps each station across its own 36-stud window. A man at station 1 may now track his
animal to the far end of the corridor, so the widest off-axis angle grows. Compute it: from mat 1
the far corridor end is 158 + 18 = 176 studs off axis at a lane distance of 107 / 125 / 179, which
is 58.7 / 54.6 / 44.6 degrees - far outside anything the berm and the two short side banks cover.
**So the design must decide the limit and write the arithmetic**: either the side banks grow, or
the crossing is capped at the widest span whose whole solid angle still ends in earth, at both
firing positions and all three distances. State the chosen span in studs and the angle it implies,
and re-express the crossing times for THAT span if it is not 196. The envelope rule is unchanged:
every shot whose aim point is on the animal's silhouette ends in the berm or a bank.

**(e) Ground and treestand both keep working; the three distances stay 107 / 125 / 179.**

## What the design must contain

1. Which of 4.3, 4.4, 5.3, 6, 9, 12 it replaces, in the delta-map shape section 0 already uses.
2. The window as ONE predicate still - the shot's door and the client's picture reading one
   function, as 4.3 and 4.4 require today.
3. The owner of the hidden characters, by file, with the disjointness argument.
4. The feature flag: this is a feel-critical path, so CLAUDE.md's rule applies - a row in
   `src/shared/Flags/init.luau`, `default = false`, `expires` within 21 days, read ONCE at its
   owner's boundary and passed inward, and the new span reachable by PARAMETER as well as by flag
   so both states are testable. Name the flag and name the boundary that reads it.
5. The numeric targets, as T-rows in section 12's shape: the re-expressed crossing times (T3), the
   re-swept envelope (T6), and the mask's per-frame write budget at six animals in one wide
   window (today's `Mask.stats().writes` must-not-climb rule).
6. What is **UNVERIFIED UNTIL BUILT**, marked as section 14 does.

## What this task does NOT do

No new cast, no new ray, no second renderer of an animal, no client-authored hit, no scoring or
money, no change to `CLAIM.*`, `Rules.unsafeLine` or the safety-arc penalty, no change to the
three distances, no new asset.

## Known defect in this area, NOT to be fixed here

`playtest/range-v3/report.md`, "Seen by accident": stepping off a mat or walking the firing line
between stations strips all four guns and rearms the wrong one, with nothing on screen. A solo view
spanning the whole width makes a player MORE likely to step off the mat while tracking. The design
should say whether anything it adds touches that path; the fix is a separate task.

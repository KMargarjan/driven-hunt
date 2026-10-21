# Archived: the semi-automatic's faded bought optic, and the numbers it was aimed with

**Task 234, 2026-10-21.** Rule 7: nothing is deleted, it is archived with a note.

Task 227 made the bought `semiauto.sight` mesh fade out of the sight line as the eye arrived,
because that upload is ONE MeshPart whose glass is a solid opaque amber face and a mesh cannot be
split in this repo. The result is `.screenshots/234-before-semiauto-aim.png`: aimed, the player
sees a bare red ball floating over the receiver and nothing to look through. Karen, 2026-10-21:

> *"this aiming is not coirrect for semiauto / you know this type of aiming you look from that
> galss and there is a dot inside right ?"*

227b queued the real fix and task 234 is it: the viewmodel no longer wears that mesh on the red-dot
row (`skipFor = "reddot"`) and draws a hood, a lens and the dot instead. **The mesh is NOT retired**
-- it still dresses the WORLD gun through `Geometry.ASSET_KEYS`, so another player at thirty studs
sees the artist's sight exactly as before, and the fade itself (`Gun.Piece.clearFromBlend`,
`Viewmodel.clearAtAim`) is still in the code and still on that piece for any row that is not the red
dot.

What is archived here is the three NUMBERS that moved, so a rollback is arithmetic rather than
archaeology.

## `src/shared/SemiAuto/Geometry.luau`

```lua
-- THE RED DOT'S OWN PLANE, measured on the sight's optical path: its rear glass centres at
-- (x -0.0032, y +0.2318, z +0.5894) and its front glass at (x -0.0033, y +0.2400, z +0.3776), so
-- the dot sits at the MIDDLE of the tube, which is where a reflex sight's dot appears to a shooter
-- looking through it. 0.1159 studs above the bore line.
local DOT_Y = 0.2359
local DOT_Z = 0.4835
-- 3 mm. A real red dot's is 2-4 MOA, which at any range a hunter shoots is a dot and not a disc;
-- what this number has to be is "small enough to aim with and big enough to find".
local DOT_DIAMETER = 0.012
```

`DOT_Y` became `SIGHT_Y = 0.298` -- the bought mesh's measured glass centre became the DRAWN sight's
line, lifted so it clears the receiver's top face (y +0.2130) by 0.085 studs. That clearance is what
keeps Roblox's 0.1-stud near plane from cutting a hole in the gun once the eye comes to the glass;
the arithmetic is section 6 of `docs/research/2026-10-21-red-dot-sight.md`.

`DOT_DIAMETER` became `0.006`. 0.012 subtends 2 degrees at the new eye relief, and a stag at 50 m
subtends 2.4 -- so the old dot would have covered most of the animal it was being aimed at. 0.006 is
about one degree.

`DOT_Z` did not move.

## `src/shared/Viewmodel/poses.json`

```json
"weapons": { "semiauto": { "aim": { "eyeReliefStuds": 0.9 } } }
```

Now `0.35`. 0.9 studs is 252 mm -- a rifle scope's eye relief, inherited when this weapon was built
and never re-solved for a red dot. At 0.9 no believable hood fills a third of the frame: it would
have to be 0.33 studs (92 mm) across, two thirds of the gun's height. Written through `pose.py`'s
own reader, merge and serializer (CLAUDE.md rule J).

## How to roll it back

Put the three numbers above back, delete the `SightMount` / `SightGlass` / `SightHood*` blocks and
the hood loop from `Geometry.pieces`, and take `skipFor = "reddot"` off the `Optic` piece. The gun
is then exactly task 227's, including its defect.

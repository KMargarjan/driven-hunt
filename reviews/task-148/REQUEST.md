# Task 148 - the open-sighted rifle retired, and the left hand half a palm back

Task: 148
Round: 1
Base: main (`7a43686`, task 147 merged as PR #130)
Code commit: `c507ee38c621c588ec5dc1475d638b0125e56514`

```
[harness] PASS: 33/33 checks @ c507ee38c621c588ec5dc1475d638b0125e56514 (clean tree) scope=all
```

`test2` is N/A: the diff is the weapon table, two maps, `poses.json`, three specs and the archive —
nothing in `TWO_PLAYER_PATHS`.

Karen, 2026-10-10 ~14:45: *"please remove rifle without scope so we don't implement now / for rifle
left arm to far it has to be half palm closer towards hunter / rest is good"*. Transcribed in
`PLAYTEST.md`. **"Rest is good" accepts task 147's per-shot bolt and dark scope tube.**
**No Architect run:** nothing new; one row leaves a table it was added to five tasks ago.

## The ten claims

1. **THE HOTBAR IS TWO AGAIN, AND IT WAS MEASURED IN HER OWN PLACE.** With the `RIFLE` override on,
   a fresh Play reports `tools: Rifle, Shotgun(hand)` — 1 shotgun, 2 rifle, the shotgun in the hand.
   With the flag off the loadout is the shotgun alone, unchanged. **Verify:** `Weapons.ORDER`, and
   `rifle.spec`'s "holds exactly the two weapons".

2. **ARCHIVED, NOT DELETED (rule 7).** `backups/2026-10-10-rifle-open-sights.md` carries why it went,
   **the commit that had it (`7a43686`)**, a table of what lived where, and five numbered steps to
   put it back. The three artefacts sit beside it: the row
   (`…-row.luau`), the pose set (`…-poses.json`) and the spec case (`…-cases.luau`).

3. **WHAT CAME OUT:** `Weapons.ROWS.rifle_open`, its place in `Weapons.ORDER` and `GEOMETRY`,
   `Shapes.BY_ID.rifle_open`, `Viewmodel.validate`'s must-exist entry, and `weapons.rifle_open` in
   `poses.json`. **Grepped before committing (rule B):** the only remaining mentions in `src/` are
   two comments that describe task 144's and task 143's history, both marked as history.

4. **WHAT DELIBERATELY STAYED, AND WHY IT IS NOT DEAD WEIGHT.** `Geometry.sightKind`,
   `Geometry.beadOffset`, the drawn `Bead` piece's `onlyFor`, `Geometry.pieces`'s `skipFor`/`onlyFor`
   filter and `ShapeRifle`'s `skipFor` are what let ONE geometry draw a gun with or without glass.
   The scoped rifle carries `SIGHT = "scope"` through all of it, and **Karen also asked for an
   Aimpoint** (cut from task 140), which is the next thing that filter is for.

5. **BOTH BRANCHES KEEP CASES, DRIVEN BY PARAMETER** — the rule CLAUDE.md states for anything behind
   a flag, applied to a sight with no row of its own. `rifle.spec` calls
   `sightKind({ SIGHT = "bead" })` and `table.clone`s the rifle's row with a bead on it to prove the
   fallback world gun drops its scope tube. **Verify:** "reads any row written before this task as
   the SCOPED rifle".

6. **ONE CASE WAS ARCHIVED RATHER THAN REWRITTEN.** "is the SAME rifle with the glass off, and three
   things differ" compared two rows field by field; with one row it has nothing to compare. It is in
   `backups/2026-10-10-rifle-open-sights-cases.luau` and step 4 of the restore puts it back.

7. **HALF A PALM IS 0.33 STUDS, MEASURED OFF THE DRAWN GLOVE** rather than chosen: a live probe
   reports `HandLeft size (0.629, 0.534, 0.669)`, so half its longest extent is 0.33. The hand moves
   **`z -0.55 → -0.22`** along the rifle's axis (`+z` is toward the shooter in the Handle's frame) in
   carry, aim and cycle. **The grip rotation Karen approved in task 146 is untouched.**

8. **IT IS STILL ON THE WOOD THERE, and that was checked before moving it.** `t148-forend.py` slices
   `Wood_Low`: at `z -0.25..-0.15` the stock spans `y -0.0194..+0.1209`, `x -0.0856..+0.0596`. So
   `y` went `0.057 → 0.051` — the centre of that slice — and `x` stayed at `-0.013`.

9. **THE RINGS RE-SPLIT IS CANCELLED WITH THE ROW.** Task 147 stopped short of a
   `rifle.action_open` mesh because the mount rings are inside the uploaded `rifle.action`. With the
   open-sighted rifle gone there is nothing to upload: `ESCALATE.md`'s `NEEDS KAREN` entry is closed
   as dropped by Karen, and the archive note says so.

10. **ONE SPEC ASSERTED A LITERAL AND THE GATE CAUGHT IT.** `weapon_equip.spec`'s respawn case —
    task 144's — read `expect(#Weapons.loadoutFor(true)).to.equal(3)`. It compares against
    `#Weapons.ORDER` now plus "more than one Tool", which is the property the case is actually
    about, so the next weapon lands in it without an edit. **That failure was real and mine**; the
    other four in the same run were not (below).

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t148-before-carry.png` / `t148-after-carry.png` | **The glove is a pale khaki lump in both** — this pose change cannot make it read as fingers. What it does show is the move: before, the cuff sits out at the forend tip (x≈200 of 969); after, it is back along the wood toward the shooter (x≈260) and lower in frame, which is the half palm |
| `t148-shipped-aim.png` | **The hand is not in it at all, and cannot be.** Aiming the scoped rifle hides the gun and both gloves behind the sight picture (`Viewmodel.hiddenByScope`, task 141), so "aimed" can only show the scope view. The hand in the aim POSE is visible during the bolt cycle, where the scope drops out |
| `t148-shipped-carry.png` | The shipped build at hip: the hand in its new place, the scope rifle otherwise as task 147 left it |

## Standing rule A, Forest Test, 85 s, with RIFLE ON

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 29 boars alive
* ...and the loadout the change is about: `tools: Rifle, Shotgun(hand)`

## What went wrong on the way, and what I could not verify

* **THE FIRST GATE RUN FAILED 24/28, AND FOUR OF THE FIVE FAILURES WERE MY STUDIO WINDOW.** Every
  input scenario reported `VirtualInput::SendMousePosition: position (250, 308) hits CoreGUI` — a
  title-bar click of mine in an earlier task had left the DEV window un-maximised, so the scenarios'
  fixed pixel coordinates landed on CoreGui instead of the 3D view. Maximising it fixed all four.
  **The fifth, `weapon_equip.spec:486`, was a real miss of mine** (claim 10). I am reporting the
  whole run rather than only the green one.
* **Nobody has seen the new hand pose from outside.** `pose.py inspect` hid the live viewmodel and
  left it hidden on the `aim` run — the same fault task 146 hit — so the evidence is the
  first-person pair, which is what Karen sees anyway.
* **Whether 0.33 studs is HER half palm is her call.** The measurement is of the drawn glove, which
  is the only palm this game has; if she meant more or less, it is one number in the content lane.

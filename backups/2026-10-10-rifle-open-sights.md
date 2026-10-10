# The open-sighted rifle, retired (task 148, 2026-10-10)

**Karen, 2026-10-10 ~14:45:** *"please remove rifle without scope so we don't implement now / for
rifle left arm to far it has to be half palm closer towards hunter / rest is good"*.

Not a defect: she decided it is not wanted **now**. Everything here is kept so a later task can put
it back in one commit rather than rebuild it.

## Where it lived

| what | where it was | archived as |
|---|---|---|
| the weapon row | `src/shared/Weapons/init.luau`, `Weapons.ROWS.rifle_open` | `2026-10-10-rifle-open-sights-row.luau` |
| the pose set | `src/shared/Viewmodel/poses.json`, `weapons.rifle_open` | `2026-10-10-rifle-open-sights-poses.json` |
| the two-row spec case | `tests/server/rifle.spec.luau`, "is the SAME rifle with the glass off, and three things differ" | `2026-10-10-rifle-open-sights-cases.luau` |

**The last commit that had all of it is `7a43686`** (main, task 147 merged as PR #130). Everything
below is reachable with `git show 7a43686:<path>`.

## What was taken out

* `Weapons.ROWS.rifle_open` — the row itself, every field of which was `Rifle.CONFIG.*` except the
  id, the label `RIFLE (OPEN)`, the Tool name `RifleOpen`, slot 3, three `ASSET_KEYS` instead of
  four, and `SIGHT = "bead"`.
* `Weapons.ORDER` — back to `{ "shotgun", "rifle" }`, so the hotbar is 1 shotgun, 2 rifle with the
  `RIFLE` flag on, and the shotgun alone with it off.
* `GEOMETRY.rifle_open` in `Weapons`, and `Shapes.BY_ID.rifle_open` on the server.
* `Viewmodel.validate`'s must-exist list — back to `{ "shotgun", "rifle" }`.
* `weapons.rifle_open` in `poses.json` (the whole set: carry, aim, cycle, and the cycle's own
  magazine, load, hand and shell blocks).
* The spec case that compared the two rows field by field, which has nothing to compare any more.

## What was DELIBERATELY KEPT, and why

None of this is dead weight for the scoped rifle, and all of it is what a second sight needs:

* **`Geometry.sightKind(config)`** — `config.SIGHT or "scope"`. The scoped row carries
  `SIGHT = "scope"` and the default is what every row written before task 143 gets.
* **`Geometry.beadOffset(config)`** and the drawn **`Bead`** piece with `onlyFor = "bead"`.
* **`Geometry.pieces`'s `skipFor`/`onlyFor` filter**, and `ShapeRifle`'s `skipFor = "bead"` on the
  fallback scope tube.
* **`Gun.Piece`'s `skipFor` / `onlyFor` fields.**

Both branches stay reachable **by parameter**: `rifle.spec` drives `sightKind({ SIGHT = "bead" })`
and builds a beaded row with `table.clone` to prove the fallback gun drops its tube. So the machinery
has cases even with no beaded row shipping — which is the same rule CLAUDE.md states for a flag.

Karen also asked for an Aimpoint (cut from task 140); that is the next thing this filter is for.

## The cancelled upload

Task 147 stopped short of a `rifle.action_open` mesh — the mount rings are inside the uploaded
`rifle.action` (`Vijsjes_Low` holds the rings, `Midden2_Low` the scope base, 1299 of its 2420
vertices above `y +0.20`), so removing them needs face-level surgery and a cap in Blender rather than
a different split. **That work is cancelled with this row**: `ESCALATE.md`'s `NEEDS KAREN` entry for
it is closed as dropped by Karen, and no upload is needed.

## How to restore it

1. `git show 7a43686:src/shared/Weapons/init.luau` — put the row back and add `rifle_open` to
   `Weapons.ORDER` and to `GEOMETRY`.
2. `git show 7a43686:src/server/Weapon/Shapes.luau` — one line in `Shapes.BY_ID`.
3. Merge `2026-10-10-rifle-open-sights-poses.json` back into `poses.json` under `weapons`, and add
   the id to `Viewmodel.validate`'s list.
4. Put `2026-10-10-rifle-open-sights-cases.luau` back in `tests/server/rifle.spec.luau`, and restore
   the three-weapon counts in "holds exactly the two weapons" and "carries the rifle only when the
   flag says so".
5. The rings are still on it, and still need the Blender job above.

# The shotgun's METAL as exact geometry (task 99)

2026-10-01. Short note (rule 1) for one decision: how the barrels, the action and the furniture-metal
of the first-person shotgun are MADE.

## 1. What the system must do

Karen, 2026-10-01: *"shooting, weapon, reload, all has to be perfect"*. The gun on screen today is one
AI-generated mesh cut in two, and the break-open frame shows what that costs: a torn breech, a shell
loose in the gap, a left hand on nothing. Meshy is weak on machined metal -- its barrels came back
faceted and wavy along the top, which is the one surface the player looks ALONG when aiming. So:

1. The barrels are **perfectly round and smooth down their whole length**, as a side-by-side pair,
   with a slim rib and a bead at the muzzle.
2. The muzzle and the breech each show **two dark round openings** that read as bores at
   first-person distance, and the breech face is flat.
3. A silver-grey **action**, a round **hinge pin** at its lower front, and the barrel group rotates
   about exactly that axis -- so the break-open is a real hinge and not a mesh tearing.
4. Trigger, round trigger guard, top lever, safety. Blued steel against a silver action.
5. Proportions from the Beretta side reference, inside the existing `HANDLE_SIZE.Z` of 4.4 studs.
   **No shot, hit or physics number moves** -- the Handle stays the envelope it has been since Task 71.
6. A sane budget, stated.

## 2. Sources

| # | Source | Licence / status | Good | Bad |
|---|---|---|---|---|
| 1 | Roblox [`BasePart.Shape`](https://create.roblox.com/docs/reference/engine/enums/PartType) / [`Part`](https://create.roblox.com/docs/reference/engine/classes/Part) -- Cylinder, Ball, Block, Wedge | First-party, maintained, no asset pipeline at all | A `Part` with `Shape = Cylinder` is **analytically round**: the engine tessellates it per-frame for the view, so there is no facet count to get wrong and no wavy top -- exactly requirement 1. Free to change (a number, not an upload), reviewable as a diff, needs no moderation, and this repo already builds its gun this way (`Weapon.Shape` + `Weapon.Hardware`, Task 71). Smooth-shaded by the engine | No bore HOLE: a cylinder is solid, so an opening has to be faked with a dark inset disc. No chamfers, no fillets, no engraved rib. Part count grows with detail, and each part is a draw call |
| 2 | Roblox [`EditableMesh`](https://create.roblox.com/docs/reference/engine/classes/EditableMesh) + [`AssetService:CreateMeshPartAsync`](https://create.roblox.com/docs/reference/engine/classes/AssetService#CreateMeshPartAsync) | First-party, out of beta, maintained | Real geometry built in code: a true tube with a HOLE at each end, exact normals, one MeshPart for the whole barrel group. Nothing uploaded, so no moderation and no asset id | Every vertex is OURS to get right, which is precisely the invention rule 2 warns about -- a hand-written tube generator is a new foundation with its own run of bugs (`docs/PROJECT_CONTEXT.md`: "a home-grown viewmodel system ... each produced a run of bugs"). It is also **client-creatable but not free**: the mesh is rebuilt per session, and `CreateMeshPartAsync` yields. And a generated mesh is not reviewable as a diff: a PR would show arithmetic, not a gun |
| 3 | A generated mesh FILE (Blender via `tools/asset_prep.py`, then `tools/roblox_upload.py`) -- the pipeline Task 74/93 already use | Blender GPL-2.0-or-later; the repo's own tools | The best-looking option: true bores, chamfers, a concave rib. The pipeline exists and is proven on four assets | Every change is a Blender run, an upload, a moderation wait and a manifest row -- hours per tweak, which is exactly the loop Karen stopped in Task 97. It also puts the metal back into the asset lane, where the Director cannot tune it live. `.rbxm` is banned (CLAUDE.md) so it must be an uploaded asset, not a file in the PR |

## 3. The pattern adopted, and why

**Source 1: Roblox Parts, built from a pure piece list** -- `src/shared/Gun/init.luau`, the same
"pure list plus one builder" division `Weapon.Shape` + `Weapon.Hardware` and `MapGen.Layout` +
`MapGen.Props` already use in this repo (rule 2: borrow the pattern that is here).

The deciding requirement is **1**: the barrel must be perfectly round and smooth down its whole
length, because that is the surface the player looks along. A Roblox Cylinder is round by
construction -- there is no triangle budget at which it stops being round -- while both mesh routes
make roundness a number somebody chose. Source 2 and 3 buy real bore holes, and source 1 cannot have
them; that is answered with a dark inset disc at each end (requirement 2 asks that it READ as a bore
at first-person distance, and at 3.65 studs an unlit near-black disc inside a blued tube does).

The other half is the loop: a part gun is **numbers in a file the Director can change and the
Reviewer can read**, which is the same reason Task 98 moved the poses into data. A mesh gun is an
upload.

**The wood is still Meshy** (`forend` and `stock`), because wood is what Meshy is good at and what
these two models actually are -- the split Karen OK'd on 2026-10-01.

## 4. The numeric targets

| Target | Value | How it is held |
|---|---|---|
| Barrels round and smooth | `Enum.PartType.Cylinder`, analytic | `gun.spec`: every barrel piece is a Cylinder, and its two cross-axis sizes are equal (a cylinder scaled unevenly is an ellipse) |
| Side-by-side pair | two tubes, centres `BARREL_GAP` apart, same Y | `gun.spec` |
| Bores read as holes | a near-black `SmoothPlastic` disc inset at each end of each tube, 4 in all | `gun.spec` counts them and asserts each sits inside its tube's radius |
| Hinge is real | the barrel group rotates about `hinge.pinStuds`, and the PIN part is centred on that axis | `gun.spec` (the pin's centre is the axis) + `camera_mode.spec`'s break case |
| Shells seat in the chambers | a fresh shell at feed 1 is INSIDE the barrel's bore line, within the tube's radius | `viewmodel_poses.spec` / client spec |
| Nothing a shot depends on moves | `HANDLE_SIZE`, `MUZZLE_OFFSET`, `GRIP`, the hitbox | the flag's OFF branch is byte-identical, and no `Shotgun.CONFIG` number changes |
| Budget | **23 parts** for the whole first-person gun: 19 metal (2 barrels, 4 bore discs, rib, bead, breech face, hinge hook, action, standing breech, flat bars, hinge pin, top lever, safety, trigger, guard bow, guard strap), 2 wood, and the 2 invisible envelopes (the Handle and the barrel group). The old mesh gun is 1 MeshPart plus a drawn bead | `gun.spec` asserts the count exactly, so growth is a decision and not a drift |

## 5. What this does NOT change

The **third-person / world** gun. `Weapon.Hardware` still wears the uploaded mesh, and every other
player sees exactly what they saw before. The new gun exists only under
`workspace.CurrentCamera`, only for the local player, and only while `NEW_GUN` is on.

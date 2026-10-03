--!strict
-- HandAssets: the THREE NAMES the first-person hands are published under, and nothing else.
--
-- It exists because the two ends of that publication cannot see each other's tables. The server
-- loads the hands -- `InsertService:LoadAsset` is server-only, and `ServerStorage.Assets.Loader` is
-- the one place in this repo an asset id becomes an Instance (docs/design/asset-pipeline.md section
-- 5) -- and parks the templates in `ReplicatedStorage`, where `Camera.Viewmodel` clones them under
-- `workspace.CurrentCamera` for the local player. `ServerStorage.Assets` is not replicated, so the
-- client cannot read the manifest at all.
--
-- Without this module the folder name and the two child names would be string literals in two files
-- that never meet, and a typo in one of them is a silent nil and a gun with no hands that nobody can
-- explain -- the reason `Assets.KEYS` and `Map.TAGS` exist, one layer over.
--
-- PURE DATA. No service, no Instance, no state: it is a table of names, frozen.
local HandAssets = {}

-- Created at RUN TIME by `ServerScriptService.ViewmodelAssetsBoot`, never on disk. ReplicatedStorage
-- is Rojo-owned with `$ignoreUnknownInstances: false`, so a folder parked here in Edit would be
-- deleted at the next Connect (CLAUDE.md); a folder a running server makes for itself lives and dies
-- with that server, exactly as `Assets.Loader`'s own cache folder does.
HandAssets.FOLDER_NAME = "ViewmodelHands"
-- ONE FOLDER AGAIN SINCE TASK 114. Task 106 added a second one, `ViewmodelHandsNewGun`, because two
-- guns wanted two pairs of gloves; Karen's gun is the only gun now and her pair is the only pair, so
-- there is one folder and the names in it are the names everything downstream has always used.

HandAssets.RIGHT = "HandRight"
HandAssets.LEFT = "HandLeft"

-- Which manifest key each published name comes from. The SERVER reads this; the client only ever
-- needs the names, because by the time it looks the Instance is already there or it is not.
--
-- `gun.hand.*` AND NOT `hand.*`, AND THE KEYS ARE WHY (task 106, round 2, kept through task 114).
-- Karen's gloves were first shipped as `hand.right` version 2 -- and a new version SUPERSEDES, so
-- `Assets.byKey` handed the OLD gun a pair it was never posed for: upside down (its `twist` of 180 is
-- for a palm-DOWN model) and at 53 % of the size its poses assumed. The fix was a different KEY, and
-- these are those keys. The v1 pair and the gun they were posed for are gone, and their ROWS STAY
-- WHERE THEY ARE: `src/serverstorage/Assets/init.luau` keeps them at `scope = "retired"`, which is
-- rule 7 satisfied in place -- an id that has been in a place is provenance, and nothing loads a
-- scope no boot line asks for.
HandAssets.KEY_OF = table.freeze({
	[HandAssets.RIGHT] = "gun.hand.right",
	[HandAssets.LEFT] = "gun.hand.left",
})

-- WHICH WAY EACH GLOVE'S OWN MESH POINTS, MEASURED (task 108), and this is the whole of Karen's
-- "left hand is oposit180deg need to turn or not sure but broken".
--
-- THE TWO MODELS DO NOT SHARE AN AXIS. Measured off each prepped mesh by classifying every vertex by
-- the colour its own UV samples in the base-colour map -- the cuff is olive, the glove is brown -- so
-- the centroid of one to the centroid of the other IS the wrist-to-fingers direction, exactly:
--
--   RIGHT glove: wrist -> fingers (-0.963, 0.265, 0.048), i.e. its own -X, and the palm faces +Z
--   LEFT  glove: wrist -> fingers ( 0.317, 0.874, -0.369), i.e. its own +Y, and the palm faces
--                roughly (0.458, 0.488, 0.743)
--
-- ONE CONVENTION IS WHAT THIS IS FOR, AND `Camera.Viewmodel.align` IS WHAT READS IT. Because the two
-- models differ, no single yaw/pitch/twist can mean the same thing on both: the Director's live try
-- of `left.rot.twist 180` moved the glove to the far side of the barrels instead of rolling the
-- palm, which is what a shared number does when the two meshes disagree about which axis it turns.
-- So `poseHands` applies a per-glove rotation that takes each mesh into ONE frame -- FINGERS ALONG
-- +X, PALM TOWARD +Y -- on the right of the pose offset, and the pose's three angles are read in
-- THAT frame on both. All three poses in `poses.json` are seeded in it.
--
-- The palm normal is the hand cloud's flattest axis signed toward the fingertips (a curled hand's
-- tips lie over its palm). On the right glove that is a clean slab; on the LEFT, which is a cupped C,
-- it is an estimate -- `align` squares it against the fingers, which were measured exactly, so a few
-- degrees of error there turns into a few degrees of roll and the pose's `twist` is the dial that
-- finishes it.
--
-- `python tools/pose.py inspect <pose>` photographs the drawn viewmodel FROM OUTSIDE, which is how
-- these were judged: three rounds of guessing at two dark lumps beside a barrel could not.
HandAssets.AXES = table.freeze({
	[HandAssets.RIGHT] = table.freeze({
		fingers = Vector3.new(-0.9632, 0.2645, 0.0484),
		palm = Vector3.new(-0.0660, 0.1061, 0.9922),
	}),
	[HandAssets.LEFT] = table.freeze({
		fingers = Vector3.new(0.3172, 0.8738, -0.3686),
		palm = Vector3.new(0.4579, 0.4884, 0.7428),
	}),
})

return table.freeze(HandAssets)

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
-- ...AND A SECOND FOLDER, FOR A SECOND PAIR (task 106). Karen made gloves that HOLD something, for
-- model B; the old gun keeps the pair its poses were measured against. Two folders rather than two
-- NAMES, so everything downstream -- `poseHands`, `clearHands`, every spec -- still looks for
-- `HandRight` and `HandLeft` and only ONE place decides which pair that is
-- (`Camera.Viewmodel.handTemplate`).
HandAssets.NEW_GUN_FOLDER_NAME = "ViewmodelHandsNewGun"

HandAssets.RIGHT = "HandRight"
HandAssets.LEFT = "HandLeft"

-- Which manifest key each published name comes from. The SERVER reads this; the client only ever
-- needs the names, because by the time it looks the Instance is already there or it is not.
--
-- TWO TABLES, TWO KEYS PER HAND, AND THAT IS THE POINT (task 106, round 2). The new gloves were
-- first shipped as `hand.right` version 2 -- and a new version SUPERSEDES, so `Assets.byKey` handed
-- the old gun a pair it was never posed for: upside down (its `twist` of 180 is for a palm-DOWN
-- model) and at 53 % of the size its poses assume. A different gun's hands are a different key.
HandAssets.KEY_OF = table.freeze({
	[HandAssets.RIGHT] = "hand.right",
	[HandAssets.LEFT] = "hand.left",
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
-- THAT frame on both. All three newGun poses in `poses.json` are seeded in it.
--
-- IT REACHES THE NEW GUN ONLY. `align` returns identity unless `config.NEW_GUN`, because the old
-- gun's pair is a different model whose poses were measured against it with no alignment at all.
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

HandAssets.NEW_GUN_KEY_OF = table.freeze({
	[HandAssets.RIGHT] = "gun.hand.right",
	[HandAssets.LEFT] = "gun.hand.left",
})

return table.freeze(HandAssets)

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

HandAssets.NEW_GUN_KEY_OF = table.freeze({
	[HandAssets.RIGHT] = "gun.hand.right",
	[HandAssets.LEFT] = "gun.hand.left",
})

return table.freeze(HandAssets)

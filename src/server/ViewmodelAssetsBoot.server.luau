-- ViewmodelAssetsBoot: the two first-person hands, loaded on the server and PUBLISHED for the
-- client (ROADMAP.md step 1.4b, the camera's S3). Boot line only.
--
-- WHY A SERVER SCRIPT AT ALL, for something only the local player's camera ever draws:
-- `InsertService:LoadAsset` cannot be called from a client, and `ServerStorage.Assets.Loader` is the
-- one place in this repo an asset id becomes an Instance (docs/design/asset-pipeline.md section 5).
-- So the server loads the two hands and parks the templates in `ReplicatedStorage`, where they
-- replicate like any other Instance and `Camera.Viewmodel` can clone them. The names both sides use
-- are `ReplicatedStorage.HandAssets`, so neither side carries a literal the other could disagree
-- with.
--
-- IT IS NOT THE WEAPON'S BOOT, AND THAT IS THE POINT. A hand is never worn by a Tool, never welded
-- to one and never part of a character: a player who is not holding this gun sees exactly what they
-- saw before (their own avatar's arms). `WeaponBoot` preloads `Assets.keysFor("runtime")` -- what the
-- SERVER needs before it can hand a gun over -- and this preloads `keysFor("viewmodel")`, which is
-- the manifest's own answer to "what does the local camera draw". The two key sets are disjoint by
-- construction, so the two boot lines never ask the Loader for the same key.
--
-- They do share `Loader.CONFIG.PRELOAD_BUDGET_S`, which is one deadline on one state, so two
-- preloads in flight can each extend the other's budget by a few seconds. That is a bound on how
-- long a boot waits and nothing else -- neither call can take the other's template, because the keys
-- differ -- and it is written down here rather than worked around.
--
-- A FAILURE IS NOT AN ERROR (design 5.3). No row, a refused insert, a moderated-away asset: the
-- folder is published EMPTY, `Camera.Viewmodel` finds no template and draws the gun with no hands,
-- which is the gun Karen has been playing since task 95. The folder is created BEFORE the load, so
-- the client's lookup resolves to "nothing published" rather than to "not there yet, forever".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))
local HandAssets = require(ReplicatedStorage:WaitForChild("HandAssets"))

local folder = Instance.new("Folder")
folder.Name = HandAssets.FOLDER_NAME
folder.Parent = ReplicatedStorage

local reports = Loader.preload(Assets.keysFor("viewmodel"))
for _, loaded in ipairs(reports) do
	if not loaded.ok then
		warn(
			string.format(
				"[ViewmodelAssets] %s not loaded (%s); the first-person gun is drawn without it",
				loaded.key,
				loaded.reason or "unknown"
			)
		)
	end
end

local published = 0
for name, key in pairs(HandAssets.KEY_OF) do
	local template = Loader.template(key)
	local row = Assets.byKey(key)
	if template and template:IsA("BasePart") and row then
		local worn = (template :: BasePart):Clone()
		worn.Name = name
		-- THE CONSUMER SETS THE SIZE, ALWAYS (design 6.1), and this script is the consumer: the
		-- Loader never writes it. Uniform, from the row, for the reason the row spells out.
		worn.Size = row.sizeStuds
		-- Everything that says "scenery" -- the same set `Weapon.Hardware` puts on the worn gun.
		-- `CanQuery = false` is not decoration: the clone ends up under `workspace.CurrentCamera`,
		-- which is a child of Workspace, so a client raycast can hit a part parented there.
		worn.Anchored = true
		worn.CanCollide = false
		worn.CanQuery = false
		worn.CanTouch = false
		worn.Massless = true
		worn.CastShadow = false
		worn.Parent = folder
		published += 1
	end
end
print(string.format("[ViewmodelAssets] published %d of 2 hand template(s)", published))

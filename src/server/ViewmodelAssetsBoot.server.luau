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
local Gun = require(ReplicatedStorage:WaitForChild("Gun"))

-- THE ONE PLACE A PUBLISHED TEMPLATE IS MADE TO SHOW ITS OWN COLOUR (task 99), for the hands and
-- for the gun's WOOD alike -- they come from the same generator, through the same prep, with the
-- same fault, so the fix is one function and not two copies of it. Every prepped
-- `texture_baseColor.png` was checked on disk: the two gloves AND the stock are mode RGB.
-- THE WHITE GLOVE, AND ITS CAUSE (task 99). Karen, 2026-10-01: the right glove is WHITE.
--
-- IT IS `AlphaMode.Overlay` OVER A MAP WITH NO ALPHA CHANNEL, measured in three steps on
-- 2026-10-01:
--   1. both hands arrive with a `SurfaceAppearance` whose `ColorMap` id is present, and both
--      `AlphaMode`s are `Overlay` (probed on this server in a live session);
--   2. both prepped `texture_baseColor.png` files are mode RGB -- NO ALPHA CHANNEL -- with a
--      median of about (55, 44, 35), i.e. dark brown leather;
--   3. `Overlay` blends the colour map over the part's `Color` THROUGH THAT ALPHA. With no
--      alpha to blend through, nothing is drawn and the part shows its `Color`, which was
--      Roblox's default medium stone grey -- the pixels of the aimed screenshot read
--      (115, 120, 131) and (132, 138, 151), beside the gun mesh's own texture at (39, 16, 13)
--      in the same frame.
-- PROVED BY ISOLATION: with the `SurfaceAppearance` destroyed, the same image on `TextureID`
-- and `Color` set to pure WHITE, the glove rendered dark brown leather on screen.
--
-- SO THE MAP GOES DOWN THE PATH THAT DRAWS IT. `TextureID` is the classic MeshPart route and
-- does not read an alpha channel at all; a `SurfaceAppearance` always wins over it, so the
-- one that could not draw is destroyed rather than left to shadow the one that can. The
-- metalness and roughness maps go with it -- a worn leather glove loses little, and a glove
-- nobody can see the colour of loses everything.
local function showItsOwnColour(worn: BasePart, row, material: Enum.Material)
	worn.Material = material
	-- THE ID COMES FROM THE ROW, NEVER OFF THE MODEL. Measured the hard way, 2026-10-01: reading
	-- `SurfaceAppearance.ColorMap` from a game script raises "The current thread cannot read
	-- 'ColorMap' (lacking capability Plugin)" -- which took this whole boot down and published
	-- nothing at all, hands included. DESTROYING it needs no such capability, and the id is a
	-- measured fact about the upload that belongs in the manifest beside the size and the sha.
	local appearance = worn:FindFirstChildOfClass("SurfaceAppearance")
	if appearance then
		appearance:Destroy()
	end
	if row.textureId ~= nil and row.textureId ~= "" then
		worn.TextureID = row.textureId
		-- A MeshPart's `Color` TINTS its `TextureID`, so a textured part is left white and the
		-- texture is shown as it is.
		worn.Color = Color3.new(1, 1, 1)
	elseif row.fallbackColor ~= nil then
		-- NO MAP AT ALL: the row's own measured colour, so a part that lost its texture is the
		-- thing it is meant to be rather than a white blob. Belt beside the braces above.
		worn.Color = row.fallbackColor
	end
end

local folder = Instance.new("Folder")
folder.Name = HandAssets.FOLDER_NAME
folder.Parent = ReplicatedStorage

-- MODEL B'S GUN PIECES (task 105; task 99's wood before it), parked in their own folder for the same
-- reason the hands have one: `InsertService:LoadAsset` is server-only, so the server loads and
-- publishes and `Camera.Viewmodel` clones. A SEPARATE folder because they are a different thing with
-- a different owner -- `Gun` names these, `HandAssets` names those.
local gunFolder = Instance.new("Folder")
gunFolder.Name = Gun.FOLDER_NAME
gunFolder.Parent = ReplicatedStorage

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

-- ONE PAIR, ONE FOLDER (task 114). Task 106 published two pairs into two folders because there were
-- two guns; Karen's gun is the only gun and her gloves are the only gloves, so this publishes one
-- pair under the names everything downstream looks for -- `HandRight` and `HandLeft`.
local published = 0
local function publishHands(into: Folder, keys: { [string]: string }): number
	local count = 0
	for name, key in pairs(keys) do
		local template = Loader.template(key)
		local row = Assets.byKey(key)
		if template and template:IsA("BasePart") and row then
			local worn = (template :: BasePart):Clone()
			worn.Name = name
			-- THE CONSUMER SETS THE SIZE, ALWAYS (design 6.1), and this script is the consumer: the
			-- Loader never writes it. Uniform, from the row, for the reason the row spells out.
			worn.Size = row.sizeStuds
			-- Leather: the material decides how a glove catches the viewmodel's own fill light, and
			-- one that reads as shiny plastic is the next complaint.
			showItsOwnColour(worn, row, Enum.Material.Fabric)
			-- Everything that says "scenery" -- the same set `Weapon.Hardware` puts on the worn gun.
			-- `CanQuery = false` is not decoration: the clone ends up under
			-- `workspace.CurrentCamera`, which is a child of Workspace, so a client raycast can hit
			-- a part parented there.
			worn.Anchored = true
			worn.CanCollide = false
			worn.CanQuery = false
			worn.CanTouch = false
			worn.Massless = true
			worn.CastShadow = false
			worn.Parent = into
			count += 1
		end
	end
	return count
end

published = publishHands(folder, HandAssets.KEY_OF)
print(string.format("[ViewmodelAssets] published %d of 2 hand template(s)", published))

-- MODEL B, by the same three rules as the hands: the CONSUMER sets the size (from the row),
-- everything says scenery, and a piece that did not load is simply absent -- `Camera.Viewmodel`
-- then draws the measured box `Gun.pieces` carries as that group's fallback, so the gun has a
-- silhouette either way and does not depend on an upload.
--
-- TWO HINGE GROUPS AND A SHELL, under one folder, named by `Gun.MESH_KEYS` and `Gun.SHELL_KEY` so
-- the server and the camera cannot disagree about which half swings.
local gunParts = 0
local function publishGunPiece(name: string, key: string)
	local template = Loader.template(key)
	local row = Assets.byKey(key)
	if not (template and template:IsA("BasePart") and row) then
		return
	end
	local worn = (template :: BasePart):Clone()
	worn.Name = name
	worn.Size = row.sizeStuds
	-- THE ARTIST'S OWN MATERIAL AND MAPS ARE LEFT ALONE, which is the one way this differs from the
	-- hands. Model B arrives with a base colour, a normal and the two shine maps its author painted,
	-- and the whole reason Karen chose it is that they are better than anything this repo would pick
	-- for it. `showItsOwnColour` -- the white-glove fix -- is the fallback for a part whose colour
	-- map does NOT draw, and it needs a `textureId` that only a plugin context can read off a loaded
	-- asset. These rows have none yet, so this calls it only if one is ever written in.
	if row.textureId ~= nil or row.fallbackColor ~= nil then
		showItsOwnColour(worn, row, worn.Material)
	end
	worn.Anchored = true
	worn.CanCollide = false
	worn.CanQuery = false
	worn.CanTouch = false
	worn.Massless = true
	worn.CastShadow = false
	worn.Parent = gunFolder
	gunParts += 1
end

for name, key in pairs(Gun.MESH_KEYS) do
	publishGunPiece(name, key)
end
-- The shell is not a hinge group, so it is not in `Gun.MESH_KEYS`; it is published here because it
-- comes from the same model, through the same loader, into the same folder.
publishGunPiece(Gun.SHELL_TEMPLATE_NAME, Gun.SHELL_KEY)
print(string.format("[ViewmodelAssets] published %d of 3 model B gun piece(s)", gunParts))

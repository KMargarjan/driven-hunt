-- WeaponBoot: starts the weapon system at server start (ROADMAP.md step 1.4).
-- Boot line only. All weapon state, hit resolution and Tool Instances belong to
-- ServerScriptService.Weapon (rule 3), mirroring ArenaBoot and BoarBoot.
--
-- Design: docs/design/shotgun.md (sections 3.1, 5.4)
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))

-- THE WEAPON SYSTEM STARTS FIRST, BEFORE ANYTHING TOUCHES THE NETWORK.
--
-- Round 1 read the asset and then started the weapons, and its own comment claimed a failed load
-- "means the parts gun, not a gunless player" -- which was only true if `preload` RETURNED. A
-- stalled `LoadAsset` meant no weapon system at all (review finding 1). Starting here costs
-- nothing: `Hardware.build` asks for a template through a provider that is not wired yet, gets nil,
-- and draws Task 71's parts gun. When the mesh arrives a moment later, every gun granted after that
-- wears it.
Weapon.start()

-- THE WIRING LIVES IN THE BOOT SCRIPT, so neither owner requires the other
-- (docs/design/shotgun.md section 6; the same idiom `MatchBoot` uses for the boar and the weapon).
-- The provider hands back the template AND the manifest row, because the row is where the size, the
-- rotation and the pivot correction live -- the Loader never writes any of them (design 6.1-6.3).
--
-- AND IT IS WIRED BEFORE ANYTHING TOUCHES THE NETWORK, for the same reason `Weapon.start()` is.
-- Wired AFTER `preload`, as it was until Task 76, it left a window nothing could reach the asset
-- through: `preload` waits for a load that runs in another thread, so by the time it RETURNS the
-- template has been cached for a frame or more, and through that frame `Loader.template` answered
-- with a mesh while `Hardware` had no way to ask for one. Wiring it here costs nothing, because
-- `Loader.template` NEVER YIELDS (design 5.2) and answers nil until the load lands -- which is
-- exactly the "wear the parts gun" answer the grant path already handles.
--
-- Task 76 measured what that window was worth. The harness plans its specs inside it about half the
-- time, and a spec that borrows this seam and puts back what it found then puts back NIL: a server
-- with no provider builds the parts gun for every grant and cannot upgrade one either, silently, for
-- the rest of the session. The same commit passed one run and failed the next on it.
Weapon.Hardware.setTemplateProvider(function(key: string)
	local template, loadReport = Loader.template(key)
	local row = Assets.byKey(key)
	return template, { reason = if loadReport then loadReport.reason else nil, row = row }
end)

-- `preload` YIELDS and hits the network, which is exactly why it happens here, once, at server
-- start -- and never on the path that hands a player a gun (docs/design/asset-pipeline.md 5.2).
-- It is bounded by `Loader.CONFIG.PRELOAD_BUDGET_S`, so this line cannot hang the boot either.
--
-- EVERY LIVE KEY, NOT A LITERAL (task 96). The gun ships as two meshes since the break-action
-- reload -- a body and a barrel group that hinges -- and a list written out by hand here would have
-- preloaded one of them and left the gun with no barrels, which is exactly what the first run of
-- that task did. `Assets.keysFor("runtime")` is the manifest's own answer to "what does a server
-- need before a player can hold it", one key each and never a superseded row.
local reports = Loader.preload(Assets.keysFor("runtime"))
for _, loaded in ipairs(reports) do
	if loaded.ok then
		print(
			string.format(
				"[WeaponBoot] %s loaded: model %d, %d mesh part(s), %d ms",
				loaded.key,
				loaded.modelId or 0,
				loaded.meshParts or 0,
				loaded.elapsedMs
			)
		)
	else
		warn(
			string.format(
				"[WeaponBoot] %s not loaded (%s); that piece of the gun is missing",
				loaded.key,
				loaded.reason or "unknown"
			)
		)
	end
end
-- AND THE GUN ITSELF IS THE ONE FAILURE WORTH ITS OWN WORDS: without the body there is no mesh gun
-- at all, only task 71's parts gun, which is a different sentence from "a piece is missing".
local report = nil
for _, loaded in ipairs(reports) do
	if loaded.key == Weapon.Hardware.ASSET_KEY then
		report = loaded
	end
end
if not (report and report.ok) then
	-- NOT FATAL. A failure here means the parts gun, not a gunless player: `Hardware.addMesh`
	-- returns false and `Hardware.build` draws Task 71's shape instead.
	warn(
		string.format(
			"[WeaponBoot] %s not loaded (%s); the gun wears its grey box",
			Weapon.Hardware.ASSET_KEY,
			if report then report.reason or "unknown" else "no report"
		)
	)
end

-- AND EVERY GUN THAT WAS ALREADY HANDED OUT GETS THE MESH (TASKS.md row 75a(h)).
--
-- `Weapon.start()` is above `preload` on purpose and stays there, so between those two lines a player
-- can join, spawn and be handed a gun -- which is not a corner case: the preload measured 1227 ms and
-- a Studio Play join takes well under a second, so in a playtest it is what ALWAYS happens. Nothing
-- rebuilt those Tools, so Karen never saw her own shotgun; she saw Task 71's parts gun and kept it.
--
-- This is the moment the template exists, so it is the moment to look. `Hardware.upgrade` is
-- idempotent and touches nothing but the visible model, and `Weapon`'s arming sweep repeats the call
-- every 2 s for the other case -- a load that arrived later than the budget.
local upgraded = Weapon.Hardware.upgradeAll()
if upgraded > 0 then
	print(string.format("[WeaponBoot] upgraded %d gun(s) that were handed out before the mesh landed", upgraded))
end

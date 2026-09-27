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
-- `preload` YIELDS and hits the network, which is exactly why it happens here, once, at server
-- start -- and never on the path that hands a player a gun (docs/design/asset-pipeline.md 5.2).
-- It is bounded by `Loader.CONFIG.PRELOAD_BUDGET_S`, so this line cannot hang the boot either.
local report = Loader.preload({ Weapon.Hardware.ASSET_KEY })[1]
if report and report.ok then
	print(
		string.format(
			"[WeaponBoot] %s loaded: model %d, %d mesh part(s), %d ms",
			report.key,
			report.modelId or 0,
			report.meshParts or 0,
			report.elapsedMs
		)
	)
else
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

-- The provider hands back the template AND the manifest row, because the row is where the size, the
-- rotation and the pivot correction live -- the Loader never writes any of them (design 6.1-6.3).
Weapon.Hardware.setTemplateProvider(function(key: string)
	local template, loadReport = Loader.template(key)
	local row = Assets.byKey(key)
	return template, { reason = if loadReport then loadReport.reason else nil, row = row }
end)

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

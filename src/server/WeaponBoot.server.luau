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

-- THE WIRING LIVES IN THE BOOT SCRIPT, so neither owner requires the other
-- (docs/design/shotgun.md section 6; the same idiom `MatchBoot` uses for the boar and the weapon).
-- `preload` YIELDS and hits the network, which is exactly why it happens here, once, at server
-- start -- and never on the path that hands a player a gun (docs/design/asset-pipeline.md 5.2).
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

Weapon.start()

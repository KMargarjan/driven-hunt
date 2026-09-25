-- WeaponBoot: starts the weapon system at server start (ROADMAP.md step 1.4).
-- Boot line only. All weapon state, hit resolution and Tool Instances belong to
-- ServerScriptService.Weapon (rule 3), mirroring ArenaBoot and BoarBoot.
--
-- Design: docs/design/shotgun.md (sections 3.1, 5.4)
local ServerScriptService = game:GetService("ServerScriptService")

local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

Weapon.start()

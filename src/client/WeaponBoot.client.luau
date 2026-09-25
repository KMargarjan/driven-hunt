-- WeaponBoot: starts the client weapon replica, its input bindings and the Hud (ROADMAP.md 1.4).
-- Boot lines only: PlayerScripts.Weapon owns the replica and the bindings, PlayerScripts.Hud owns
-- everything drawn (rule 3). The Hud reads the weapon and the weapon never calls the Hud.
--
-- Design: docs/design/shotgun.md (sections 3.2, 3.4)
local Players = game:GetService("Players")

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Weapon = require(scripts:WaitForChild("Weapon"))
local Hud = require(scripts:WaitForChild("Hud"))

Weapon.start()
Hud.start()

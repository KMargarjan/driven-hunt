-- CameraBoot: the composition root for the camera (ROADMAP.md 1.4b). Boot lines only.
--
-- It is the ONLY place that knows both the camera and the weapon, which is how the two owners are
-- wired together without either requiring the other -- the idiom src/server/BoarBoot.server.luau
-- already uses for the boar and the weapon (docs/design/boar-ai.md section 9).
--
-- The aim SOURCE is "the player is holding the aim button AND the server says the gun is equipped".
-- That second half closes the one hole the state machine would otherwise need a state for: a tool
-- taken away during a held aim (docs/design/camera.md section 4.2).
--
-- With no weapon in the place this simply installs no source, and the camera is a working
-- third-person camera that never aims.
--
-- Design: docs/design/camera.md (section 4.4)
local Players = game:GetService("Players")

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))

local weaponModule = scripts:FindFirstChild("Weapon")
if weaponModule then
	local Weapon = require(weaponModule)
	Camera.setAimSource({
		isAiming = function()
			local state = Weapon.get()
			return Weapon.Input.isAiming() and state ~= nil and state.equipped
		end,
	})
	-- The viewmodel clones the Handle of the Tool the character is holding. A READ of the weapon's
	-- Instance; Weapon.Hardware stays its only writer.
	Camera.Viewmodel.setSource(function(): BasePart?
		local character = Players.LocalPlayer.Character
		local tool = character and character:FindFirstChildOfClass("Tool")
		local handle = tool and tool:FindFirstChild("Handle")
		return if handle and handle:IsA("BasePart") then handle else nil
	end)
end

Camera.start()

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
	-- TASK 92, AND BOTH DIRECTIONS OF THE SAME WIRE. The weapon says "a shot of mine landed" and the
	-- camera kicks; the weapon's cosmetics ask the camera where the DRAWN gun's muzzle is, so the flash
	-- comes out of the pipe on screen instead of the hidden gun at the character's shoulder. Neither
	-- owner requires the other -- this file is the only place that knows both, exactly as the aim
	-- source above.
	Weapon.Fired:Connect(function()
		Camera.kick()
	end)
	Weapon.Effects.setMuzzleProvider(function(barrel: number?): CFrame?
		return Camera.viewmodelMuzzle(barrel)
	end)
	-- TASK 96: the break-open reload. The weapon's own replica says whether the gun is open and how
	-- many barrels were spent when it opened; the camera draws the swing and the shells. The RULES
	-- and the clock stay the server's -- this is a read, like the aim source above.
	--
	-- IT REMEMBERS THE LAST SHUT SNAPSHOT, because that is the only place the answer lives: the
	-- server's `Break` opens the gun and empties both barrels in ONE reduction, so a replica that
	-- says "open" has already forgotten what was spent. `Camera.breakFrom` does the deciding and is
	-- pure; this closure only keeps the memory.
	local lastClosed = Weapon.get()
	Camera.setBreakSource({
		state = function()
			local snapshot = Weapon.get()
			if snapshot ~= nil and snapshot.open ~= true then
				lastClosed = snapshot
			end
			return Camera.breakFrom(lastClosed, snapshot)
		end,
	})
end

Camera.start()

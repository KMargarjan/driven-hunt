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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camera = require(scripts:WaitForChild("Camera"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- HOW LONG THE CAMERA WAITS FOR THE WEAPON TO REPLICATE, and it is a wait rather than a look
-- (task 133). Karen: *"no weapon when it loads"*.
--
-- `FindFirstChild` WAS THE WHOLE BUG. `PlayerScripts` is replicated to this client, and nothing
-- promises that `Weapon` has arrived by the time this script runs -- line 18 above already waits for
-- `Camera` for exactly that reason. When it had not arrived, this block was SKIPPED FOR THE WHOLE
-- SESSION: no aim source, no muzzle provider, no break source and -- the one the player sees -- no
-- viewmodel source, which means NO GUN ON SCREEN AT ALL, for ever, with the Tool sitting correctly
-- in his hand the entire time.
--
-- MEASURED in the Forest Test, 10 fresh Plays with a per-frame trace from t = 0: it happened in 4 of
-- them. The trace of a bad one reads `frames=465 parented=false fp=true/true src=false rebuilds=0
-- tool=HAND(Shotgun,handle=true,Part)` -- the camera running, first person on, the gun in the
-- character, and the viewmodel source never installed. That is why it could not be reproduced on
-- demand: it is a replication race, not a code path.
--
-- A TIMEOUT, NOT AN ETERNAL WAIT, so the case the comment above describes -- a place with no weapon
-- in it -- still boots a working camera, and says so instead of being silently gunless. Ten seconds
-- is the same bound this repo uses for a `WaitForChild` on something that should already be there
-- (`ForestTestBoot`'s HumanoidRootPart, `Camera.faceCharacter`).
local WEAPON_WAIT_SECONDS = 10

local weaponModule = scripts:WaitForChild("Weapon", WEAPON_WAIT_SECONDS)
if weaponModule == nil then
	warn(
		string.format(
			"[CameraBoot] no PlayerScripts.Weapon after %d s: the camera starts with no aim source and "
				.. "NO VIEWMODEL -- there will be no gun on screen (task 133)",
			WEAPON_WAIT_SECONDS
		)
	)
end
if weaponModule then
	local Weapon = require(weaponModule)
	Camera.setAimSource({
		isAiming = function()
			local state = Weapon.get()
			return Weapon.Input.isAiming() and state ~= nil and state.equipped
		end,
	})
	-- THE OPTICS OF THE WEAPON ON SCREEN (task 140), which is the third injected source on this
	-- camera and the same idiom as the two around it: the camera is told a field of view, a reticle
	-- and a sway, and still requires no weapon. The id comes off the drawn gun -- the Tool's own
	-- attribute -- so what the camera zooms for is the gun the player is looking at.
	Camera.setOpticsSource({
		optics = function()
			local row = Weapons.row(Camera.Viewmodel.weaponId())
			local scope = row and row.scope
			if scope == nil then
				return nil -- a bead: `config.FOV_AIM_DEG`, no reticle, no sway
			end
			return {
				aimFovDeg = scope.aimFovDeg,
				reticle = scope.reticle,
				sway = scope.sway,
			}
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
		-- THE SHOT'S NOISE (task 112). `Weapon.Sound` owns it; this file is still the only place that
		-- knows both owners, exactly as the kick and the muzzle provider are.
		Weapon.Sound.shot(Camera.poseConfig())
	end)
	-- THE SHOT'S LIGHT, AND WHO DRAWS IT (task 112, round 2). `Weapon.Effects` asks BEFORE drawing
	-- its own flash and smoke, so the two cannot land on top of each other -- which is what round 1
	-- shipped and Karen saw ("remove those smokes (white from previous)"). `Camera.fire` answers
	-- false unless it really drew one, so the flag-OFF build and everybody else's shot are untouched.
	Weapon.Effects.setViewmodelFlash(function(barrel: number?): boolean
		return Camera.fire(barrel)
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
	-- ...AND THE TWO CLICKS (task 112). The break and the close are the only other things the gun
	-- does that make a noise, and this closure is already the one place that sees the state flip --
	-- so the EDGE is detected here rather than by a second reader of the replica.
	local wasOpen = lastClosed ~= nil and lastClosed.open == true
	Camera.setBreakSource({
		state = function()
			local snapshot = Weapon.get()
			if snapshot ~= nil and snapshot.open ~= true then
				lastClosed = snapshot
			end
			local isOpen = snapshot ~= nil and snapshot.open == true
			local noise = Camera.breakSound(wasOpen, isOpen)
			wasOpen = isOpen
			if noise == "open" then
				Weapon.Sound.open(Camera.poseConfig())
			elseif noise == "close" then
				Weapon.Sound.close(Camera.poseConfig())
			end
			return Camera.breakFrom(lastClosed, snapshot)
		end,
	})
end

Camera.start()

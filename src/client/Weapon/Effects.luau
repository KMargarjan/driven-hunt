--!strict
-- PlayerScripts.Weapon.Effects: the shot's cosmetics, and nothing else. It writes no state, decides
-- no hit, and touches nothing outside Workspace.WeaponEffects, which it creates on first use.
--
-- Everything it makes is handed to Debris, so nothing it does can accumulate: EFFECT_MAX_PER_SHOT
-- is a hard cap on top of that, so a bug upstream cannot flood Workspace (design section 11).
--   Debris  https://create.roblox.com/docs/reference/engine/classes/Debris
--
-- Design: docs/design/shotgun.md (sections 3.2, 5.6)
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Effects = {}

local folder: Folder? = nil

function Effects.folder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local existing = Workspace:FindFirstChild("WeaponEffects")
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local made = Instance.new("Folder")
	made.Name = "WeaponEffects"
	made.Parent = Workspace
	folder = made
	return made
end

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, lifetime: number)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = Effects.folder()
	Debris:AddItem(p, lifetime)
	return p
end

function Effects.play(payload: any)
	if type(payload) ~= "table" or typeof(payload.muzzle) ~= "Vector3" then
		return
	end
	local config = Shotgun.CONFIG
	local budget = config.EFFECT_MAX_PER_SHOT

	part(
		"Flash",
		Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(payload.muzzle),
		Color3.fromRGB(255, 220, 140),
		config.FLASH_LIFETIME
	)
	budget -= 1

	for _, position in ipairs(payload.impacts or {}) do
		if budget <= 1 then
			break
		end
		local gap = position - payload.muzzle
		if gap.Magnitude > 0.1 then
			part(
				"Tracer",
				Vector3.new(0.08, 0.08, gap.Magnitude),
				CFrame.lookAt(payload.muzzle + gap * 0.5, position),
				Color3.fromRGB(255, 240, 200),
				config.TRACER_LIFETIME
			)
			budget -= 1
		end
		part(
			"Impact",
			Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(position),
			Color3.fromRGB(255, 170, 90),
			config.IMPACT_LIFETIME
		)
		budget -= 1
	end
end

return Effects

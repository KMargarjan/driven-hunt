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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Effects = {}

local folder: Folder? = nil

-- WHERE THE GUN ON SCREEN IS, when the gun on screen is not the gun in the world (task 92). Karen,
-- after playing S2: "when firing this animation where flies light has to be from pipes not from
-- shoulder."
--
-- In first person the Tool is in the character's hand, hidden, and what the player SEES is the camera's
-- viewmodel clone -- so a flash at the server's muzzle position appears off at the character's
-- shoulder. `CameraBoot` installs the camera's `viewmodelMuzzle` here, the same way it installs the
-- camera's aim source: injected rather than required, so this module needs no camera and a spec can
-- drive both answers. Nil, or no provider at all, means "draw it in the world", which is what every
-- other player's shot wants.
local muzzleProvider: ((number?) -> CFrame?)? = nil

-- WHO DRAWS THE SHOOTER'S OWN FLASH (task 112, round 2). Round 1 added a particle flash to the
-- viewmodel and left this one running, and the two landed on top of each other: `muzzleFrame` below
-- has asked the viewmodel for the shooter's OWN muzzle since task 92, so the neon box and the grey
-- ball were already at the drawn gun, two studs from the eye -- not "in the world, nowhere near it"
-- as round 1's comments claimed. Karen saw both: "remove those smokes (white from previous)".
--
-- SO THE VIEWMODEL GETS FIRST REFUSAL. This answers true when it drew its own; then the box and the
-- ball are skipped for that shot and nothing else changes -- the tracers and the impacts are still
-- drawn here, every other player's shot is still drawn here whole, and the flag-OFF build has no
-- provider that answers true at all.
local viewmodelFlash: ((number?) -> boolean)? = nil

function Effects.setViewmodelFlash(fn: ((number?) -> boolean)?)
	viewmodelFlash = fn
end

function Effects.getViewmodelFlash(): ((number?) -> boolean)?
	return viewmodelFlash
end

function Effects.setMuzzleProvider(fn: ((number?) -> CFrame?)?)
	muzzleProvider = fn
end

function Effects.getMuzzleProvider(): ((number?) -> CFrame?)?
	return muzzleProvider
end

-- The frame the flash, the smoke and the tracers are drawn in: the fired barrel's muzzle, pointing
-- down the bore. In order of preference -- the drawn gun, then the payload's own barrel frame, then
-- the bare position the payload has always carried (an older server, or a gun with no attachment).
--
-- PURE, AND EXPORTED, so a spec can ask it what it chose without firing a shot.
function Effects.muzzleFrame(payload: any): CFrame
	-- MY OWN GUN IS ONLY EVER MY OWN SHOT (round 1, finding 1). `Effects.play` runs for EVERY
	-- payload -- the server fires `ShotFired` at all clients -- so asking the provider without
	-- checking who fired put a teammate's flash, smoke and tracers at the local barrel, and stretched
	-- a tracer from my own muzzle to somebody else's impacts. The drawn gun is one player's picture of
	-- their own weapon; everyone else's shot is a thing in the world and is drawn where the world
	-- says. The provider itself answers nil in third person, so this asks only about the shooter.
	local mine = payload.shooterUserId ~= nil and payload.shooterUserId == Players.LocalPlayer.UserId
	local fromViewmodel = if mine and muzzleProvider then muzzleProvider(payload.barrel) else nil
	if fromViewmodel then
		return fromViewmodel
	end
	if typeof(payload.muzzleCFrame) == "CFrame" then
		return payload.muzzleCFrame
	end
	return CFrame.new(payload.muzzle)
end

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

local function part(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	lifetime: number,
	material: Enum.Material?,
	transparency: number?,
	shape: Enum.PartType?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
	end
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transparency or 0
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

	-- OUT OF THE PIPE THAT FIRED, AND ALONG IT (task 92): a short bloom on the bore line rather than a
	-- cube at a point, and a puff of smoke behind it that outlives it. `-Z` is the muzzle direction in
	-- the barrel's own frame (the `GRIP` convention), so both sit forward of the muzzle rather than
	-- inside the barrel.
	local at = Effects.muzzleFrame(payload)
	local origin = at.Position
	-- THE FIRST-PERSON GUN DRAWS ITS OWN (round 2). Only for the shot that is MINE, because that is
	-- the only one the viewmodel knows about, and only when it really drew: with the flag off, with
	-- no clone on screen, or in third person it answers false and this draws the pair as it always
	-- has.
	local mine = payload.shooterUserId ~= nil and payload.shooterUserId == Players.LocalPlayer.UserId
	local drawnOnScreen = mine and viewmodelFlash ~= nil and (viewmodelFlash :: any)(payload.barrel) == true
	if not drawnOnScreen then
		part(
			"Flash",
			Vector3.new(0.34, 0.34, 0.75),
			at * CFrame.new(0, 0, -0.30),
			Color3.fromRGB(255, 220, 140),
			config.FLASH_LIFETIME,
			Enum.Material.Neon
		)
		budget -= 1
		-- A BALL, AND THAT IS WHAT THE FIRST SCREENSHOT OF IT CHANGED: as a block it read as a grey BOX
		-- hanging off the barrels (`.screenshots/...t92-smoke-1.png`, the first frame that ever caught it).
		-- A sphere at this size reads as a puff of smoke, which is what it is.
		part(
			"Smoke",
			Vector3.new(0.55, 0.55, 0.55),
			at * CFrame.new(0, 0.06, -0.45),
			Color3.fromRGB(196, 196, 196),
			config.SMOKE_LIFETIME,
			Enum.Material.SmoothPlastic,
			0.62,
			Enum.PartType.Ball
		)
		budget -= 1
	end

	for _, position in ipairs(payload.impacts or {}) do
		if budget <= 1 then
			break
		end
		local gap = position - origin
		if gap.Magnitude > 0.1 then
			part(
				"Tracer",
				Vector3.new(0.08, 0.08, gap.Magnitude),
				CFrame.lookAt(origin + gap * 0.5, position),
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

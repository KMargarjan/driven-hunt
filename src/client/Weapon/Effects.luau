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

-- ONE PUFF OF DUST, defined with the landing below and FORWARD-DECLARED here so `Effects.play`'s
-- own impact branch draws the same thing. There is exactly one impact picture in this file.
local puff: (Vector3, Vector3?, string?) -> BasePart

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
		-- THE SAME PUFF THE LANDING DRAWS (task 249), and never the `Neon` cube again. This branch
		-- is dead in production -- the server has sent `impacts = {}` on `ShotFired` since task 185
		-- -- but a dead branch that can still draw a yellow box is one edit away from being alive.
		puff(position, nil, nil)
		budget -= 1
	end
end

-- ---------------------------------------------------------------- the landing (tasks 185, 249)

-- WHICH PUFF A SURFACE GETS. PURE and exported, so `weapon_client.spec` can ask it about every
-- material name without firing a shot. The argument is the plain STRING the server sends (see
-- `Weapon.onShotLanded`); anything it does not recognise -- including nil, including "" from an
-- older server -- is dust, which is the safe way round on a map that is grass, soil and rock.
function Effects.impactColor(materialName: string?): Color3
	local cfg = Shotgun.CONFIG.IMPACT
	if type(materialName) == "string" and cfg.WOOD[materialName] then
		return cfg.WOOD_COLOR
	end
	return cfg.DUST_COLOR
end

-- WHICH WAY A PUFF COMES OFF. PURE and exported for the same reason. The emitter fires along its
-- host part's TOP face (`EmissionDirection`), so the host is built with its top ALONG the surface
-- normal -- grains come off a trunk sideways and off the floor upwards, from one rule.
--
-- A ZERO OR ABSENT NORMAL IS WORLD UP, which is what every landing point sent before task 249
-- carries: the puff still happens, it just always goes up.
function Effects.impactFrame(position: Vector3, normal: Vector3?): CFrame
	local up = if typeof(normal) == "Vector3" and normal.Magnitude > 1e-4 then normal.Unit else Vector3.yAxis
	-- ANY right-hand vector that is not parallel to `up`: the emitter is radially symmetric about
	-- its top face, so the roll about the normal changes nothing a player can see.
	local reference = if math.abs(up.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local right = reference:Cross(up)
	if right.Magnitude < 1e-4 then
		right = Vector3.new(0, 0, 1):Cross(up)
	end
	return CFrame.fromMatrix(position, right.Unit, up)
end

-- ONE PUFF, AS AN INSTANCE. Named "Impact" exactly as the cube was, because that name is what the
-- `EFFECT_MAX_PER_SHOT` cap and the suite both count -- what changed is the picture, not the
-- bookkeeping.
--
-- THE PART IS INVISIBLE AND THE PARTICLES ARE THE PICTURE. It is still handed to Debris like every
-- other effect in this file, so nothing here can accumulate.
function puff(position: Vector3, normal: Vector3?, materialName: string?): BasePart
	local cfg = Shotgun.CONFIG.IMPACT
	local host = Instance.new("Part")
	host.Name = "Impact"
	host.Size = Vector3.new(0.05, 0.05, 0.05)
	host.CFrame = Effects.impactFrame(position, normal)
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.CastShadow = false
	host.Massless = true

	local attachment = Instance.new("Attachment")
	attachment.Parent = host

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Puff"
	emitter.Texture = cfg.TEXTURE
	emitter.Color = ColorSequence.new(Effects.impactColor(materialName))
	emitter.LightEmission = cfg.LIGHT_EMISSION
	emitter.Lifetime = NumberRange.new(cfg.LIFETIME[1], cfg.LIFETIME[2])
	emitter.Speed = NumberRange.new(cfg.SPEED[1], cfg.SPEED[2])
	emitter.SpreadAngle = Vector2.new(cfg.SPREAD_DEG, cfg.SPREAD_DEG)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.SIZE[1]),
		NumberSequenceKeypoint.new(1, cfg.SIZE[2]),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, cfg.TRANSPARENCY[1]),
		NumberSequenceKeypoint.new(1, cfg.TRANSPARENCY[2]),
	})
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-60, 60)
	-- GRAVITY PULLS THE GRAINS BACK DOWN, which is what makes it read as dirt rather than smoke.
	emitter.Acceleration = Vector3.new(0, -24, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	-- NEVER A STREAM. `Emit` below puts exactly `COUNT` grains in the air, once.
	emitter.Enabled = false
	emitter.Parent = attachment

	host.Parent = Effects.folder()
	emitter:Emit(cfg.COUNT)
	Debris:AddItem(host, cfg.HOST_LIFETIME)
	return host
end

-- WHERE THE DUST GOES, WHEN THE BULLET ARRIVES (tasks 185, 249). `ShotLanded`'s payload, and
-- nothing else: one "Impact" per position, through `puff` above, under the same
-- `EFFECT_MAX_PER_SHOT` budget `play` has always used.
--
-- NOTHING IS DRAWN IN THE AIR, AND THAT HAS ALWAYS BEEN TRUE HERE RATHER THAN BEING ADDED NOW: a
-- pellet that hits nothing produces no `Weapon.Cast` result, so it reaches no `res.impacts` entry,
-- so `Weapon.onShotLanded` sends no point for it -- *"A shot that hit nothing sends nothing"*, in
-- that function's own words. Every position here is a surface a pellet really struck.
--
-- NO FLASH, NO SMOKE, NO TRACER, EVER. The bang was at the trigger and `Effects.play` drew it
-- there; this is the bullet landing, up to 0.365 s later, and it is the one thing on screen that
-- tells a player a shot takes time -- with no tracer and no number (design section 7). A tracer
-- would be a bar drawn between two points the bullet never occupied at the same moment; if Karen
-- ever asks for one, its honest home is a drawn path from the same `Ballistics` arithmetic, and
-- that is a separate task.
--
-- IT MUST NOT FIRE `Weapon.Fired`: that signal is the recoil and the sound, and the kick belongs to
-- the trigger. Nothing here touches it -- the connection in `PlayerScripts.Weapon` keeps
-- `firedSignal:Fire` inside its `ShotFired` handler alone.
function Effects.playLanded(payload: any)
	if type(payload) ~= "table" or type(payload.impacts) ~= "table" then
		return
	end
	-- THE TWO NEW ARRAYS ARE OPTIONAL AT EVERY INDEX (task 249), which is what lets every caller
	-- written before this task -- the suite's own `playLanded({ impacts = { ... } })` included --
	-- keep working: a missing normal is world up and a missing material is dust.
	local normals = if type(payload.normals) == "table" then payload.normals else nil
	local materials = if type(payload.materials) == "table" then payload.materials else nil
	local budget = Shotgun.CONFIG.EFFECT_MAX_PER_SHOT
	for index, position in ipairs(payload.impacts) do
		if budget <= 0 then
			break
		end
		if typeof(position) == "Vector3" then
			local normal = if normals ~= nil then normals[index] else nil
			local material = if materials ~= nil then materials[index] else nil
			puff(
				position,
				if typeof(normal) == "Vector3" then normal else nil,
				if type(material) == "string" then material else nil
			)
			budget -= 1
		end
	end
end

return Effects

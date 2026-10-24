--!strict
-- PlayerScripts.Weapon.Effects: the shot's cosmetics, and nothing else. It writes no state and
-- decides no hit. Everything it creates lives in Workspace.WeaponEffects, which it makes on first
-- use -- WITH ONE EXCEPTION since task 256: a landing on a body that MOVES parents its `Attachment`
-- to the struck part itself, because an Attachment's frame is its parent's and the folder would pin
-- the dust to the world again. It adds a child and Debris takes it away; it reads and writes nothing
-- else about that part, so `Boar.Body` is still the only writer of a boar.
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
local puff: (Vector3, Vector3?, string?, BasePart?) -> Instance

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

-- WHETHER THE DUST HAS TO RIDE WHAT IT LANDED ON (task 256). PURE and exported, so
-- `weapon_client.spec` can ask it about an anchored tree, a boar's zone part, a nil and a
-- non-BasePart without firing a shot.
--
-- KAREN, 2026-10-24: *"this signe where we shot where we hit sometimes shows we hit empty space and
-- died needs corection"*. MEASURED (research note section 8.1): the puff below is `Anchored` in the
-- WORLD, and a boar at `Boar.CONFIG.MOVE.SPRINT_SPEED` (38 studs/s) covers **11.4 studs in the
-- 0.3 s its own grains live** -- two of its own 5.5-stud body lengths -- so the mark hangs in the
-- air where the animal WAS while the animal it really hit runs on and dies. "Sometimes" is
-- "whenever the animal was running".
--
-- `not Anchored` IS THE WHOLE TEST, and it is a fact the client can read off its own copy rather
-- than a second answer sent over the wire. A boar's trunk and all four of its zone parts are
-- `Anchored = false` (`Boar.Body.create`, `Boar.Body.zones`); the map's ground, trees and stands are
-- anchored. So the discriminator is the engine's own word for "this moves", and nothing has to
-- maintain a list of what is an animal.
--
-- IT IS WIDER THAN THE ANIMALS, DELIBERATELY AND SAID OUT LOUD (the Reviewer's note, round 1): any
-- unanchored BasePart rides, which includes another player's limbs and any physics prop. That is the
-- RIGHT answer for all of them -- dust belongs on the thing it landed on, whatever that thing is --
-- and it is why this asks "does it move" rather than "is it an animal", which would need a list
-- somebody has to keep.
function Effects.ridesWith(instance: Instance?): BasePart?
	if instance == nil or not instance:IsA("BasePart") then
		return nil
	end
	-- ANCHORED IS THE WORLD AND THE WORLD DOES NOT MOVE, so it keeps today's anchored host: cheaper,
	-- and bit-for-bit the picture every landing drew before this task.
	if instance.Anchored then
		return nil
	end
	return instance
end

-- ONE PUFF, AS AN INSTANCE. Named "Impact" exactly as the cube was, because that name is what the
-- `EFFECT_MAX_PER_SHOT` cap and the suite both count -- what changed is the picture, not the
-- bookkeeping.
--
-- THE PART IS INVISIBLE AND THE PARTICLES ARE THE PICTURE. It is still handed to Debris like every
-- other effect in this file, so nothing here can accumulate.
--
-- `attachTo` IS THE BODY THE DUST RIDES (task 256), and it is nil for every static surface and for
-- every caller written before this task. When it is given there is NO HOST PART AT ALL: the
-- `Attachment` -- which this function has always built -- goes straight onto that part, and an
-- Attachment IS a point in its parent's own frame, so the emitter follows the body with no weld, no
-- constraint, no per-frame CFrame write and no second writer of anything `Boar.Body` owns.
--   https://create.roblox.com/docs/reference/engine/classes/Attachment
-- The frame is converted into the part's space with the CLIENT's own current CFrame
-- (`ToObjectSpace`), deliberately: the part has moved since the server measured the hit, and where
-- this client draws the animal NOW is the frame the player can actually see the dust against
-- (research note section 8.2).
--
-- IT RETURNS THE INSTANCE IT MADE, which is a Part on the static path and an Attachment on the
-- riding one. The one thing both have in common is that `Debris` takes them away, which is what the
-- "nothing here can accumulate" promise above rests on.
function puff(position: Vector3, normal: Vector3?, materialName: string?, attachTo: BasePart?): Instance
	local cfg = Shotgun.CONFIG.IMPACT
	local frame = Effects.impactFrame(position, normal)

	local attachment = Instance.new("Attachment")
	local made: Instance = attachment
	local host: Part? = nil
	if attachTo ~= nil then
		attachment.Name = "Impact"
		attachment.CFrame = attachTo.CFrame:ToObjectSpace(frame)
	else
		-- NOT the `part` helper above: that one is `Neon`, visible and sized for a flash. This is
		-- the invisible carrier the grains hang on, and it is named `anchoredHost` so a reader is
		-- never asked which `part` is meant.
		local anchoredHost = Instance.new("Part")
		anchoredHost.Name = "Impact"
		anchoredHost.Size = Vector3.new(0.05, 0.05, 0.05)
		anchoredHost.CFrame = frame
		anchoredHost.Transparency = 1
		anchoredHost.Anchored = true
		anchoredHost.CanCollide = false
		anchoredHost.CanQuery = false
		anchoredHost.CanTouch = false
		anchoredHost.CastShadow = false
		anchoredHost.Massless = true
		host = anchoredHost
		made = anchoredHost
	end

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
	-- THE GRAINS THEMSELVES RIDE THE BODY, AND THIS LINE IS THE WHOLE OF IT (task 256, round 2).
	--
	-- ROUND 1 SHIPPED A FIX THAT MOVED NOTHING THE PLAYER CAN SEE, and the Reviewer was right: an
	-- `Attachment` on the boar moves where the NEXT particle would be born, but `Emit` below puts all
	-- seven grains in the air in ONE burst at the instant of the hit -- and with `LockedToPart` at
	-- its default of FALSE a particle is simulated in WORLD space once emitted. So the attachment
	-- rode the animal and the dust hung in the air at exactly the point the anchored host used, which
	-- is the defect verbatim.
	--   https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter#LockedToPart
	--     "whether the particles are locked in place relative to the emitter's parent"
	--
	-- ONLY ON THE RIDING PATH. A static surface keeps `false`, which is world space and is
	-- bit-for-bit the picture every landing has drawn since task 249 -- the ground does not move, so
	-- the two are identical there and `false` is the one that is already proven.
	--
	-- `Acceleration` IS THEN IN THE PART'S FRAME, which is the one thing this line changes besides
	-- the position: the grains fall along the animal's own -Y instead of the world's. `Boar.Body`
	-- holds the trunk upright with an `AlignOrientation`, so while the animal is alive those are the
	-- same direction; on a carcass that has rolled, 0.3 s of dust falls along the body's axis
	-- instead of straight down. Stated rather than corrected: it is a third of a second of seven
	-- grains, and the alternative is a second acceleration number that would have to be kept in step
	-- with this one.
	if attachTo ~= nil then
		emitter.LockedToPart = true
	end
	-- NEVER A STREAM. `Emit` below puts exactly `COUNT` grains in the air, once.
	emitter.Enabled = false
	emitter.Parent = attachment

	-- PARENTED LAST, AND THE EMIT IS AFTER IT, exactly as this function has always done: an
	-- `Emit` on an emitter that is not yet in the world draws nothing.
	if host ~= nil then
		attachment.Parent = host
		host.Parent = Effects.folder()
	else
		-- ONTO THE BODY ITSELF. Not into `Effects.folder()`: an Attachment's frame is its PARENT's,
		-- so the folder would pin it to the world again and undo the whole of task 256.
		attachment.Parent = attachTo
	end
	emitter:Emit(cfg.COUNT)
	-- THE SAME LIFETIME EITHER WAY, and `Debris` destroys an Attachment as readily as a Part -- so
	-- the riding path cannot accumulate children on an animal that survives the drive, and a puff
	-- on a boar that is destroyed first goes with it.
	Debris:AddItem(made, cfg.HOST_LIFETIME)
	return made
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
	-- THE THREE EXTRA ARRAYS ARE OPTIONAL AT EVERY INDEX (tasks 249, 256), which is what lets every
	-- caller written before each of them -- the suite's own `playLanded({ impacts = { ... } })`
	-- included -- keep working: a missing normal is world up, a missing material is dust, and a
	-- missing part is the world, which is what every landing drew before task 256.
	local normals = if type(payload.normals) == "table" then payload.normals else nil
	local materials = if type(payload.materials) == "table" then payload.materials else nil
	-- WHAT EACH PELLET STRUCK (task 256). `Weapon.onShotLanded` sends `false` where it struck
	-- something that is not a BasePart, for the reason the normals array sends `Vector3.zero`: these
	-- are read BY INDEX, so a hole would shift every later entry and stand one pellet's dust on
	-- another pellet's surface.
	local parts = if type(payload.parts) == "table" then payload.parts else nil
	local budget = Shotgun.CONFIG.EFFECT_MAX_PER_SHOT
	for index, position in ipairs(payload.impacts) do
		if budget <= 0 then
			break
		end
		if typeof(position) == "Vector3" then
			local normal = if normals ~= nil then normals[index] else nil
			local material = if materials ~= nil then materials[index] else nil
			local struck = if parts ~= nil then parts[index] else nil
			puff(
				position,
				if typeof(normal) == "Vector3" then normal else nil,
				if type(material) == "string" then material else nil,
				-- `Effects.ridesWith` IS THE ONE DECISION, so the spec drives it directly and this
				-- loop cannot hold a second copy of "does this move".
				Effects.ridesWith(if typeof(struck) == "Instance" then struck :: Instance else nil)
			)
			budget -= 1
		end
	end
end

return Effects

--!strict
-- Weapon.Claim: THE SHOOTER'S OWN SHOT, SIMULATED AGAINST THE WORLD HE CAN ACTUALLY SEE (task 266).
--
-- KAREN, 2026-10-24 and 2026-10-25: *"it seems there is a bit off"* / *"we need to aim in empty
-- space to get hit in head neck or heart like in real life"* / *"this signe where we shot ... shows
-- we hit empty space and died"* / *"all shooting has to be like in real life / this is a key of this
-- game"*. Asked which of several fixes to take, she answered *"the best way"*.
--
-- WHAT THIS IS FOR, in one paragraph. The server holds every animal where IT thinks the animal is;
-- the player's screen draws it somewhere else, by whatever the connection and the engine's
-- interpolation make of it (task 265 measured ~0.17 s of it and could NOT establish the number,
-- which is precisely why nothing here depends on its size or its sign). So a shot judged only on the
-- server can miss an animal the player's sights were on. This module simulates the shot the player
-- actually took, against the animal he was actually looking at, and produces a CLAIM. The server
-- then rewinds its own history and decides whether to believe it
-- (`Weapon.Validator.judgeClaim`, six checks).
--
-- **THE LEAD KAREN ASKED FOR IS UNTOUCHED, and that is the whole reason this is not the "lag
-- compensation" both designs forbade.** The projectile still takes its real flight time
-- (`Ballistics.timeToRange`), and the animal is still stepped forward over that flight here --
-- against the animal AS DRAWN rather than as the server holds it. Aiming AT a running animal still
-- misses; aiming ahead by `v * t` still hits. What goes away is only the disagreement about the
-- present moment. `docs/design/ballistics.md` section 1.4 is the argument in full.
--
-- IT IS NOT A SECOND ANSWER TO "WHERE DID THE BULLET GO", and that is a property of the code rather
-- than an intention: every step is `Ballistics.segment` and `Ballistics.advance` -- the SAME
-- functions `ServerScriptService.Weapon.Flight` steps with -- and the bore and the aim are
-- `Ballistics.boreOrigin` and `Ballistics.convergeAim`, the same two `Weapon.onFireRequest` uses.
-- There is no copy of the arithmetic here to drift.
--
-- PURE OVER ITS INJECTED CASTS. No state, no clock of its own, no camera, no remote, no Instance
-- created, nothing drawn, and no `Workspace:Raycast` except in `Claim.world` and `Claim.only` below
-- -- which makes `Claim.simulate` driveable from a client spec with a scripted world and no boar
-- (`tests/client/weapon_client.spec.luau`).
--
-- Design: docs/design/ballistics.md (sections 2.1, 4.7, 5.5)
-- Note:   docs/research/2026-10-24-real-shooting.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local Claim = {}

-- THE ONLY CALLER OF `Workspace:Raycast` UNDER `src/client/Weapon/`, and the exact shape of
-- `ServerScriptService.Weapon.Cast.world`: `RaycastParams` with `FilterType = Exclude`, rebuilt per
-- call because the list differs per shot and a shared mutable params object is a second writer
-- waiting to happen.
--
-- (`src/client/Camera/Rig.luau` casts too, for camera occlusion. That is a different question with
-- a different owner, and it is named here so the grep claim in the review request is honest.)
function Claim.world(origin: Vector3, direction: Vector3, ignore: { Instance }): Shotgun.Impact?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	local result = Workspace:Raycast(origin, direction, params)
	if not result then
		return nil
	end
	return {
		instance = result.Instance,
		position = result.Position,
		normal = result.Normal,
		distance = result.Distance,
		material = result.Material,
	}
end

-- THE SAME CAST, INCLUDE-FILTERED TO ONE INSTANCE: *"did this segment meet THIS animal"*. One
-- builder per target rather than one params object reused, for the reason above.
function Claim.only(instance: Instance): Shotgun.CastFn
	return function(origin: Vector3, direction: Vector3, _ignore: { Instance }): Shotgun.Impact?
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { instance }
		params.IgnoreWater = true
		local result = Workspace:Raycast(origin, direction, params)
		if not result then
			return nil
		end
		return {
			instance = result.Instance,
			position = result.Position,
			normal = result.Normal,
			distance = result.Distance,
			material = result.Material,
		}
	end
end

export type Target = { root: Instance, velocity: Vector3 }

-- ONE PELLET, THE REAL FLIGHT TIME, THE CLIENT'S OWN VIEW. Returns the claim, or `nil`.
--
-- **`nil` IS THE COMMON CASE AND IS NOT A FAILURE**: a miss, a shot into the wood, and EVERY shot
-- aimed AT a running animal instead of ahead of it. The server then resolves the shot from its own
-- flight, which is the game exactly as it is today.
--
-- PER SUB-STEP (`Ballistics.segment`, the same function the server steps with):
--   1. THE STATIC PASS. `cast(position, segment, ignore)` with every target excluded as well: a
--      tree, the ground or a stand post stops the simulation and there is NO CLAIM. The client
--      refuses to claim a hit it could not have made -- which is the same line of sight the server's
--      own check 5 tests, from the other side.
--   2. THE TARGET PASS, for each of at most `CLAIM.MAX_TARGETS`. The segment is TRANSLATED by
--      `-velocity * elapsed` and cast against that animal alone; the impact point is translated
--      back by `+velocity * elapsed`. **Translating the segment IS the animal's own frame**: the
--      bullet's position, velocity, drag and drop stay exactly the server's arithmetic, because
--      they are `Ballistics.segment`'s, and only the question "where was this animal then" moves.
--      Stepping the ANIMAL instead would need a second copy of every animal's pose.
--
-- WHAT THIS GETS WRONG, NAMED RATHER THAN DISCOVERED (design 5.5): the animal is stepped in a
-- STRAIGHT LINE at the velocity it is drawn moving at, so an animal that TURNS during the flight is
-- mispredicted -- tenths of a stud over buckshot's 0.079 s, of the order of 2 studs over the rifle's
-- longest. The server's check 4 (`LINE_TOLERANCE_STUDS`) is what stops that becoming a free hit, and
-- the direction of the failure is the right one: a mispredicted claim is REFUSED and the shot falls
-- back to the server's own flight, so the player gets a miss -- which is what a real shot at an
-- animal that jinked does.
function Claim.simulate(opts: {
	origin: Vector3,
	aim: Vector3,
	shot: Ballistics.Shot,
	rangeStuds: number,
	targets: { Target },
	ignore: { Instance },
	cast: Shotgun.CastFn?,
	castOnly: ((Instance) -> Shotgun.CastFn)?,
	firedAtView: number,
	limits: any,
}): Shotgun.HitClaim?
	local limits = opts.limits or Shotgun.CONFIG.CLAIM
	local stepCap = Shotgun.CONFIG.FLIGHT_STEP_MAX_SECONDS
	local cast = opts.cast or Claim.world
	local castOnly = opts.castOnly or Claim.only

	-- THE SAME ELEVATED BORE THE SERVER WILL LAUNCH ALONG, from the same function. If this used the
	-- raw aim the claim's own flight time and drop would disagree with the server's by the zero's
	-- whole elevation, and check 4 would refuse every honest claim at range.
	local direction = Ballistics.launchDirection(opts.aim, opts.shot)
	local pellet = {
		position = opts.origin,
		velocity = direction.Unit * opts.shot.v0,
		travelled = 0,
		elapsed = 0,
	}

	-- THE STATIC PASS'S IGNORE LIST: the caller's, plus every target -- so a target cannot stop the
	-- static cast and be mistaken for a tree. Built once; `table.clone` so the caller's list is not
	-- appended to (it is the same table the fire path holds).
	local staticIgnore = table.clone(opts.ignore)
	local targets = {}
	for index, target in ipairs(opts.targets) do
		if index > limits.MAX_TARGETS then
			break
		end
		table.insert(targets, target)
		table.insert(staticIgnore, target.root)
	end

	for _ = 1, limits.MAX_SUBSTEPS do
		local nextPosition, nextVelocity, segment, length, capped =
			Ballistics.segment(pellet, stepCap, opts.shot, opts.rangeStuds)
		if length <= 1e-6 then
			return nil
		end

		-- (1) THE STATIC WORLD STOPS THE SIMULATION, and there is no claim.
		if cast(pellet.position, segment, staticIgnore) ~= nil then
			return nil
		end

		-- (2) EACH ANIMAL, IN ITS OWN FRAME. The FIRST impact wins; nothing here sorts, because the
		-- sub-step is short enough that two animals inside one segment is a tie nobody can see.
		for _, target in ipairs(targets) do
			local shift = target.velocity * pellet.elapsed
			local hit = castOnly(target.root)(pellet.position - shift, segment, staticIgnore)
			if hit ~= nil and hit.instance ~= nil and hit.instance:IsA("BasePart") then
				local part = hit.instance :: BasePart
				return {
					part = part,
					-- OBJECT SPACE, FROM THE UNTRANSLATED IMPACT, and the two frames here are the
					-- whole of this function's arithmetic -- getting them the wrong way round is a
					-- defect this spec caught before the gate did.
					--
					-- The cast ran in the animal's TRIGGER-TIME frame (the segment was moved back by
					-- `-v * elapsed`), so `hit.position` is a point on the part AS IT IS DRAWN NOW --
					-- which is exactly the frame `part.CFrame` is in while this runs. The offset is
					-- therefore a constant of the animal's own body, independent of time, which is
					-- what lets the server test it against the part's own `Size` (check 1).
					offset = part.CFrame:PointToObjectSpace(hit.position),
					-- ...AND THE WORLD POINT IS THE SAME HIT AT THE ARRIVAL INSTANT, which is where
					-- the client's own picture says the animal will be when the bullet gets there.
					-- The server rebuilds this from its OWN rewind of the same offset and compares
					-- (check 2) -- so this is the one field that exists to be disagreed with.
					point = hit.position + shift,
					firedAtView = opts.firedAtView,
					flightSeconds = pellet.elapsed + (hit.distance / math.max(1e-6, pellet.velocity.Magnitude)),
					distanceStuds = pellet.travelled + hit.distance,
				}
			end
		end

		if capped then
			return nil
		end
		pellet.travelled += length
		pellet.elapsed += stepCap
		pellet.position = nextPosition
		pellet.velocity = nextVelocity
	end
	return nil
end

-- THE GATHERER: everything `simulate` needs, read off the live client, and nothing else.
--
-- It is thin on purpose -- every decision is in `simulate` or in `Ballistics` -- and it does not
-- touch the camera beyond the CFrame it is handed, so the one owner of the camera is still the
-- camera (`src/client/Camera`).
--
-- WHY THE CLIENT'S BORE AND THE SERVER'S AGREE BY CONSTRUCTION AND NOT BY LUCK:
-- `Shotgun.CONFIG.BORE_ON_SIGHT_LINE` ships `true` (since task 260), so `Ballistics.boreOrigin`
-- projects the muzzle onto the camera ray and `Ballistics.convergeAim` returns the camera's own
-- direction *whatever the ray hit* -- which is the whole of tasks 259 and 260. Both sides therefore
-- compute one trajectory from the same two numbers. **At `false` they could diverge by the 0.73
-- studs across the sight line**, which is a stated dependency of this design (section 4.7).
--
-- `nil` WHENEVER ANYTHING IS MISSING -- no character, no Tool, no muzzle, no row, no ballistics, no
-- visible animal -- and nil simply means no claim is sent. There is no fallback, because a fallback
-- would be a guess about what the player saw.
function Claim.forCamera(cframe: CFrame, snapshot: any?, firedAtView: number?): Shotgun.HitClaim?
	local player = Players.LocalPlayer
	local character = player and player.Character
	if character == nil then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	if tool == nil then
		return nil
	end
	local muzzle = Shotgun.muzzleOf(tool)
	if muzzle == nil then
		return nil
	end
	local id = Weapons.idForToolName(tool.Name)
	local row = id and Weapons.ROWS[id]
	if row == nil then
		return nil
	end
	-- WHICH LOAD IS IN THE CHAMBER, off the snapshot the server published -- never guessed. With no
	-- snapshot there is no claim: the ammo decides the flight time, the range AND whether a claim is
	-- allowed at all.
	local ammo = if type(snapshot) == "table" and type(snapshot.loaded) == "table"
		then snapshot.loaded[snapshot.selected]
		else nil
	if type(ammo) ~= "string" then
		return nil
	end
	-- A PATTERN LOAD CLAIMS NOTHING, decided off the row on BOTH sides (the server re-checks it;
	-- design section 6). Buckshot's cone at its own 100-stud reach is wider than the error a claim
	-- would remove.
	if (row.PELLETS and row.PELLETS[ammo]) ~= 1 then
		return nil
	end
	local shot = Ballistics.shotFor(row, ammo)
	if shot == nil then
		return nil
	end

	local origin = Ballistics.boreOrigin(cframe.Position, cframe.LookVector, muzzle, Shotgun.CONFIG.BORE_ON_SIGHT_LINE)
	local rangeStuds = row.RANGE_STUDS[ammo]
	-- THE SAME AIM THE SERVER WILL COMPUTE: the camera ray's own impact when it has one, else the
	-- far end of the ammo's range. `convergeAim` then answers the camera's own direction either way,
	-- because the bore is on the sight line.
	local ignore = { character }
	local aimImpact = Claim.world(cframe.Position, cframe.LookVector * rangeStuds, ignore)
	local aimPoint = if aimImpact then aimImpact.position else cframe.Position + cframe.LookVector * rangeStuds
	local aim = Ballistics.convergeAim(origin, aimPoint, cframe.LookVector, Shotgun.CONFIG.MIN_AIM_DISTANCE)

	return Claim.simulate({
		origin = origin,
		aim = aim,
		shot = shot,
		rangeStuds = rangeStuds,
		targets = Claim.visibleTargets(origin, rangeStuds),
		ignore = ignore,
		firedAtView = firedAtView or Workspace:GetServerTimeNow(),
		limits = Shotgun.CONFIG.CLAIM,
	})
end

-- THE ANIMALS THIS CLIENT CAN SEE, nearest first, bounded by `CLAIM.MAX_TARGETS`.
--
-- `Damageable == true` IS THE ONE TEST, and it is the same attribute `Hits.targetOf` reads on the
-- server -- published by the animal's own owner (`Boar.Body`), so this module knows nothing about
-- what a boar is. A carcass is excluded by its own attribute, exactly as every other reader excludes
-- one.
--
-- NO VISIBILITY TEST HERE: whether the segment can actually reach the animal is the simulation's
-- own static pass, which is a better question asked per sub-step than once from the muzzle.
function Claim.visibleTargets(origin: Vector3, rangeStuds: number): { Target }
	local folder = Workspace:FindFirstChild("Boars")
	if folder == nil then
		return {}
	end
	local rows = {}
	for _, part in ipairs(folder:GetChildren()) do
		if
			part:IsA("BasePart")
			and part:GetAttribute("Damageable") == true
			and part:GetAttribute("Carcass") ~= true
		then
			local distance = (part.Position - origin).Magnitude
			if distance <= rangeStuds then
				table.insert(rows, { root = part, velocity = part.AssemblyLinearVelocity, distance = distance })
			end
		end
	end
	table.sort(rows, function(a, b)
		return a.distance < b.distance
	end)
	local out: { Target } = {}
	for index, row in ipairs(rows) do
		if index > Shotgun.CONFIG.CLAIM.MAX_TARGETS then
			break
		end
		table.insert(out, { root = row.root, velocity = row.velocity })
	end
	return out
end

return Claim

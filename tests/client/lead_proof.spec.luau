-- lead_proof.spec: AIM AT A RUNNING ANIMAL AND THE SHOT LANDS BEHIND IT; AIM AHEAD AND IT LANDS
-- WHERE YOU AIMED. Two REAL replayed clicks, through the real input stack (task 260, item 3; queued
-- as TASKS.md 259a).
--
-- KAREN, 2026-10-24, verbatim: *"when boar is running we need to aim in empty space to get hit in
-- head neck or heart like in real life smae with other animals"*, *"all shooting has to be like in
-- real life / this is a key of this game"*.
--
-- WHY A CLIENT SPEC AND NOT A SERVER ONE. `weapon_hits.spec`'s *"the shot in the air"* block already
-- asserts this claim PURELY -- a scripted cast, a stub target, no world -- and it is the right place
-- for the arithmetic. What it cannot say is that the claim survives the REAL path: a replayed mouse
-- click, `ContextActionService`, `Input.fire` reading `workspace.CurrentCamera.CFrame`, `FireRequest`
-- over the wire, `Validator.checkShot`'s origin bound, `Ballistics.boreOrigin`, the pattern, the
-- sub-stepped flight, and `ShotFired`/`ShotLanded` home again. That is what this file is for, and it
-- is the Director's "CLICK PROOF" for this task.
--
-- THE TARGET IS A REAL BOAR AND ITS SPEED IS MEASURED, NOT ASSUMED. `shoot_boar.spec` established
-- that route in task 30 and this file reuses it exactly: the harness `stage` places the character
-- beside the animal and takes the first aim, and this spec keeps the camera on it through
-- `Camera.lookAt` -- the OWNER's API, never `workspace.CurrentCamera`. The velocity is a finite
-- difference across `RenderStepped`, so nothing reads a replicated boar field.
--
-- THE TWO SHOTS DIFFER IN ONE TERM AND NOTHING ELSE:
--   SHOT A, aimed AT the chest                       -> must land BEHIND, or miss
--   SHOT B, aimed at chest + velocity * timeToRange  -> must land WHERE IT WAS AIMED
-- and "behind" is measured as the signed projection of `impact - aimPoint` onto the animal's own
-- direction of travel. That metric is why this works for an animal running AWAY as well as across:
-- the error is always along the velocity, whatever the geometry, and its SIGN is the whole claim.
--
-- THE BOUNDS ARE RELATIVE TO THE LEAD THE RUN ITSELF PRODUCED, deliberately. A boar bolts when a
-- player appears inside `DETECT_RADIUS` and then runs where it likes, so the distance and the speed
-- at the instant of each click are the drive's business and not this file's -- but the ratio is not:
-- shot A must be at least `BEHIND_FRACTION` of its own computed lead behind the aim, and shot B
-- within `ON_FRACTION` of its own. An absolute bound in studs would be a bound on how fast the boar
-- happened to be going.
--
-- WHAT IS LATCHED AT THE TRIGGER AND WHY. `ShotFired` arrives on every client the moment the server
-- accepts the trigger, so the spec pairs each shot with the aim point IT asked for and the velocity
-- it had measured at that instant -- not with whatever the camera is doing 130 ms later when
-- `ShotLanded` comes back. `ShotFired.at` is NOT used for shot B on purpose: it is the server's own
-- aim point, and a shot led into empty space has no aim point on the animal at all -- the ray hits
-- nothing and the server reports `origin + direction * range`. That is the very case task 260's
-- `BORE_ON_SIGHT_LINE` exists for, so this file would be reading the symptom as its own instrument.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/ballistics.md (section 11.4), docs/design/camera.md (section 9.3)
-- Note:   docs/research/2026-10-24-real-shooting.md (sections 3 and 12)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Ballistics = require(ReplicatedStorage:WaitForChild("Ballistics"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))
local Role = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("Role"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Camera = require(scripts:WaitForChild("Camera"))
local Weapon = require(scripts:WaitForChild("Weapon"))

-- Set by the harness's stage step and by nothing else, exactly as in `shoot_boar.spec`: tracking
-- starts when it appears, so this spec never fights another for the camera.
local STAGE_ATTRIBUTE = "StagedTarget"
local STAGE_TIMEOUT = 240
local TRACK_SECONDS = 20
local AIM_HEIGHT = 0.4 -- studs above the trunk centre: the chest band, not the legs

-- Shot A must land at least this much of its own computed lead behind the aim point, and shot B
-- within this much of its own. 0.5 and 0.6 leave a wide corridor between them and still fail the
-- thing they are for: a shot that does not care whether you led it would sit near 0 for both.
local BEHIND_FRACTION = 0.5
local ON_FRACTION = 0.6
-- Below this the measurement is not worth making: a lead smaller than a pellet's own spread at that
-- range cannot be told from noise. It is reported rather than asserted away.
local MIN_LEAD_STUDS = 1.0

local latchedAt: number? = nil
local shots = {} -- one entry per ShotFired, in order
local landed = {} -- one entry per ShotLanded, in order
local phase = "at" -- "at" until the first trigger is seen, then "ahead"
local lastAim: Vector3? = nil
local lastVelocity = Vector3.zero
-- The previous frame's reading, for the finite difference. One table rather than two locals, so a
-- half-updated pair cannot be read.
local lastSample: { at: Vector3, clock: number }? = nil
local lastDistance = 0
local lastLead = 0

local function boarPart(): BasePart?
	local folder = Workspace:FindFirstChild("Boars")
	return folder and folder:FindFirstChildWhichIsA("BasePart")
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- WHAT THE PLAYER IS HOLDING AND HOW ITS SHOT FLIES, read live. A one-player DEV run holds the
-- SHOTGUN, whose slug is two thirds of the rifle's speed, so the lead is this gun's lead and never
-- an assumption. nil anywhere is "no lead this frame", which is the old behaviour and not an error.
local function flightFor(): any?
	local snapshot = Weapon.get()
	local id = snapshot and snapshot.weapon
	local row = if type(id) == "string" then Weapons.row(id) else nil
	if row == nil or snapshot == nil then
		return nil
	end
	local ammo = (snapshot :: any).loaded and (snapshot :: any).loaded[(snapshot :: any).selected]
	if type(ammo) ~= "string" then
		ammo = row.INITIAL_AMMO
	end
	return Ballistics.shotFor(row, ammo)
end

-- THE TRIGGER. `ShotFired` reaches every client the instant the server accepts it, which is the only
-- moment at which "what did he aim at" and "how fast was it going" are both still true.
Shotgun.remotes().ShotFired.OnClientEvent:Connect(function(payload)
	if not latchedAt or type(payload) ~= "table" or payload.shooterUserId ~= player.UserId then
		return
	end
	table.insert(shots, {
		phase = phase,
		aim = lastAim,
		velocity = lastVelocity,
		distance = lastDistance,
		lead = lastLead,
	})
	-- THE SECOND CLICK IS THE LED ONE. One latch, so the order of the two shots is the scenario's
	-- and not a clock's.
	phase = "ahead"
end)

Shotgun.remotes().ShotLanded.OnClientEvent:Connect(function(payload)
	if not latchedAt or type(payload) ~= "table" or payload.shooterUserId ~= player.UserId then
		return
	end
	table.insert(landed, payload)
end)

local tracking = RunService.RenderStepped:Connect(function()
	if not latchedAt then
		local staged = player:GetAttribute(STAGE_ATTRIBUTE)
		if type(staged) == "string" and staged ~= "" then
			latchedAt = os.clock()
		end
		return
	end
	if os.clock() - latchedAt > TRACK_SECONDS then
		return -- the window closed: give the camera back
	end
	local boar = boarPart()
	local root = rootPart()
	if not boar or not root then
		return
	end

	local now = os.clock()
	if lastSample and now > lastSample.clock then
		local measured = (boar.Position - lastSample.at) / (now - lastSample.clock)
		if measured.Magnitude < 80 then -- above a sprint is a respawn or a teleport, not a boar
			lastVelocity = lastVelocity * 0.6 + measured * 0.4
		end
	end
	lastSample = { at = boar.Position, clock = now }

	local chest = boar.Position + Vector3.new(0, AIM_HEIGHT, 0)
	lastDistance = (chest - root.Position).Magnitude
	local shot = flightFor()
	local lead = Vector3.zero
	if shot then
		lead = lastVelocity * Ballistics.timeToRange(shot, lastDistance)
	end
	lastLead = lead.Magnitude
	-- THE ONE TERM THAT DIFFERS BETWEEN THE TWO SHOTS.
	local aim = if phase == "ahead" then chest + lead else chest
	lastAim = aim
	Camera.lookAt(aim)
end)

InputReady.ready("lead_proof")

local function waitUntil(seconds: number, predicate: () -> boolean): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return predicate()
end

-- THE IMPACT NEAREST THE AIM POINT, and whether it struck a boar at all. `ShotLanded` carries four
-- parallel arrays and `parts` is task 256's fourth: a nil entry is "the world".
local function nearestImpact(payload, aim: Vector3)
	local best, bestPart, bestGap = nil, nil, math.huge
	for index, position in ipairs(payload.impacts or {}) do
		if typeof(position) == "Vector3" then
			local gap = (position - aim).Magnitude
			if gap < bestGap then
				best, bestGap = position, gap
				bestPart = (payload.parts or {})[index]
			end
		end
	end
	return best, bestPart
end

local function onABoar(part: Instance?): boolean
	if part == nil then
		return false
	end
	local folder = Workspace:FindFirstChild("Boars")
	return folder ~= nil and part:IsDescendantOf(folder)
end

return function()
	describe("a real replayed click at a running boar", function()
		it("is this client's to take -- a driver has no gun to fire", function()
			if Role.isShooter() then
				expect(player.Team).to.be.ok()
				expect(player.Team.Name).to.equal("Shooters")
				return
			end
			task.wait(5)
			expect(player:GetAttribute(STAGE_ATTRIBUTE)).to.equal(nil)
			expect(#shots).to.equal(0)
		end)

		it("was staged, and both clicks reached the server", function()
			if Role.isDriver() then
				expect(latchedAt).to.equal(nil)
				return
			end
			expect(waitUntil(STAGE_TIMEOUT, function()
				return latchedAt ~= nil
			end)).to.equal(true)
			-- TWO TRIGGERS, which is the proof that the REPLAYED INPUT arrived: nothing in this spec
			-- can fire a shot, and `ShotFired` only exists because the server accepted a request that
			-- `Input.fire` sent from a real `ContextActionService` action.
			expect(waitUntil(20, function()
				return #shots >= 2
			end)).to.equal(true)
			expect(shots[1].phase).to.equal("at")
			expect(shots[2].phase).to.equal("ahead")
			print(
				string.format(
					"[lead] shot A aimed AT: %.0f studs, lead would have been %.2f | shot B aimed AHEAD: %.0f studs, lead %.2f",
					shots[1].distance,
					shots[1].lead,
					shots[2].distance,
					shots[2].lead
				)
			)
		end)

		it("lands shot A BEHIND the animal and shot B where it was aimed", function()
			if Role.isDriver() then
				expect(#landed).to.equal(0)
				return
			end
			expect(waitUntil(25, function()
				return #shots >= 2 and #landed >= 2
			end)).to.equal(true)

			local results = {}
			for index = 1, 2 do
				local fired = shots[index]
				local payload = landed[index]
				local aim = fired.aim
				expect(typeof(aim)).to.equal("Vector3")
				local impact, part = nearestImpact(payload, aim)
				local along = 0
				if impact and fired.velocity.Magnitude > 1e-3 then
					-- THE SIGNED PROJECTION ONTO THE ANIMAL'S OWN DIRECTION OF TRAVEL. Negative is
					-- BEHIND, which is where an unled shot has to land.
					along = (impact - aim):Dot(fired.velocity.Unit)
				end
				results[index] = { impact = impact, part = part, along = along, lead = fired.lead }
				print(
					string.format(
						"[lead] shot %s (%s): %s, %+.2f studs along the boar's travel, against a lead of %.2f",
						if index == 1 then "A" else "B",
						fired.phase,
						if impact then (if onABoar(part) then "hit the boar" else "hit the world") else "no impact",
						along,
						fired.lead
					)
				)
			end

			-- THE LEAD HAS TO BE BIG ENOUGH TO MEASURE, and if it is not this says so instead of
			-- passing on a number it cannot see. A boar that was walking at the instant of the click
			-- is a drive that did not cooperate, not a broken ballistic model.
			if results[2].lead < MIN_LEAD_STUDS then
				error(
					string.format(
						"[lead] the boar's lead at the second click was only %.2f studs (< %.1f): nothing to measure",
						results[2].lead,
						MIN_LEAD_STUDS
					)
				)
			end

			-- SHOT A: a miss, or a hit BEHIND. Both are the dispatch's own words, and both are the
			-- same fact -- the bullet went where the animal was.
			local a = results[1]
			local aMissed = a.impact == nil or not onABoar(a.part)
			if not aMissed then
				expect(a.along <= -BEHIND_FRACTION * a.lead).to.equal(true)
			end

			-- SHOT B: ON the animal, where it was aimed. This is the half that cannot be satisfied by
			-- a broken model: a shot that ignored the lead would land `lead` studs behind the point
			-- this one is asked to arrive at.
			local b = results[2]
			expect(b.impact).to.be.ok()
			expect(onABoar(b.part)).to.equal(true)
			expect(math.abs(b.along) <= ON_FRACTION * b.lead).to.equal(true)
		end)

		afterAll(function()
			if tracking.Connected then
				tracking:Disconnect()
			end
		end)
	end)
end

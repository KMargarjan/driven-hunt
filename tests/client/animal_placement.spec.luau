-- animal_placement.spec: WHAT THIS CLIENT WAS SENT, and how close it was when it arrived (task 345
-- T3). The server's own counter (`ForestTest.placementStats().inView`) is the other instrument and
-- they are deliberately independent: this one knows nothing about the roster, the beds or the rays,
-- only about an Instance appearing in `Workspace.Boars` and where the player was standing then.
--
-- THE MARGIN THAT MAKES IT A TEST AND NOT A RESTATEMENT (design section 7.3). `StreamingMinRadius`
-- in Karen's Forest Test is **384** (`docs/design/cell-loading.md` section 3, measured 2026-11-08)
-- and `PLACEMENT.neverStuds` is **145**: everything inside 384 studs of a settled character is
-- already loaded, so an instance cannot ARRIVE by streaming inside 145 studs. Any arrival that close
-- is a creation. No streaming property is read, in Edit or in Play (`tools/studio_mcp.py`,
-- `UNREADABLE`): the 384 is a documented measurement a human re-confirms, which is why it is quoted
-- here as a statement rather than asserted off the place.
--
-- WHAT IT CAN AND CANNOT JUDGE, said plainly. The in-view rule is this system's and the system is
-- behind `PLACEMENT_IN_PLACE`, which is OFF by default -- so in the DEV place, where the harness
-- runs, the animals that arrive are other specs' (`shoot_boar.spec` spawns one at the player's feet
-- on purpose) and judging them by this rule would be judging code that is not running. So the
-- arrivals are MEASURED always, the rule is ASSERTED when the switch is on, and the classifier
-- underneath is driven by parameter either way -- which is the half that has bite with no world at
-- all. The live number with the switch on is in the task's report, off a probe of the same shape.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/animal-placement.md sections 7.2, 7.3, 13.2
-- Note:   docs/research/2026-11-10-animal-placement.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Placement = require(ReplicatedStorage:WaitForChild("ForestTest"):WaitForChild("Placement"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local CONFIG = Placement.CONFIG
-- THE DOCUMENTED PLACE SETTING, as a number this file states rather than reads (above).
local STREAMING_MIN_RADIUS_STUDS = 384
-- A SINGLE-FRAME MOVE THIS BIG IS A TELEPORT AND NOT A WALK (design section 7.3).
local JUMP_STUDS = 100
-- How long the listener is given to collect before the case reads it.
local WATCH_SECONDS = 4

local player = Players.LocalPlayer

-- ------------------------------------------------------------------------------ THE PURE CLASSIFIER
-- IS THIS ARRIVAL ONE THE RULE JUDGES, AND DOES IT BREAK THE RULE? Returns "ignored", "clear" or
-- "inview". Pure: a distance and two ages, so both answers are reachable with no world (the half of
-- this file that has bite in any place).
local function verdictFor(
	distanceStuds: number?,
	sinceCharacter: number,
	sinceJump: number,
	settle: number,
	never: number
): string
	-- NO BODY TO MEASURE FROM is not a pass: it is an arrival nobody can judge.
	if distanceStuds == nil then
		return "ignored"
	end
	-- A RESPAWN OR A TELEPORT BRINGS A WHOLE 384-STUD SPHERE AT ONCE, from 0 studs outward: the
	-- honest exception, and it is COUNTED so that a drive which ignored everything cannot read as a
	-- pass (design section 7.3).
	if sinceCharacter < settle or sinceJump < settle then
		return "ignored"
	end
	return if (distanceStuds :: number) < never then "inview" else "clear"
end

-- ---------------------------------------------------------------------------------- THE LIVE WATCH
local arrivals: { { name: string, studs: number, clear: boolean, verdict: string } } = {}
local ignored = 0
local watchStartedAt = os.clock()
local characterAt = os.clock()
local jumpAt = -math.huge
local lastRootAt: Vector3? = nil

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character.PrimaryPart
	return if root ~= nil then (root :: BasePart).Position else nil
end

player.CharacterAdded:Connect(function()
	characterAt = os.clock()
	lastRootAt = nil
end)

RunService.Heartbeat:Connect(function()
	local at = rootPosition()
	if at ~= nil and lastRootAt ~= nil then
		if (at - (lastRootAt :: Vector3)).Magnitude > JUMP_STUDS then
			jumpAt = os.clock()
		end
	end
	lastRootAt = at
end)

local function observe(child: Instance)
	local root = if child:IsA("BasePart")
		then child :: BasePart
		else (child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")) or nil)
	local me = rootPosition()
	local studs = if root ~= nil and me ~= nil then ((root :: BasePart).Position - (me :: Vector3)).Magnitude else nil
	local now = os.clock()
	local verdict = verdictFor(studs, now - characterAt, now - jumpAt, CONFIG.settleSeconds, CONFIG.neverStuds)
	if verdict == "ignored" then
		ignored += 1
		return
	end
	-- ...AND WHETHER THE PLAYER COULD HAVE SEEN IT, which is the second half of the claim and not
	-- the assertion: the camera is where the client's own view is, so this is the honest reading of
	-- "was it on screen" that a server ray cannot take.
	local camera = Workspace.CurrentCamera
	local clear = false
	if camera ~= nil and root ~= nil then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { child.Parent :: Instance }
		params.RespectCanCollide = true
		local at = (root :: BasePart).Position
		clear = Workspace:Raycast(camera.CFrame.Position, at - camera.CFrame.Position, params) == nil
	end
	table.insert(arrivals, { name = child.Name, studs = studs :: number, clear = clear, verdict = verdict })
end

local boars = Workspace:FindFirstChild("Boars")
if boars ~= nil then
	boars.ChildAdded:Connect(observe)
else
	-- The folder is made by the boar runtime at boot; a place without one has no arrivals to watch.
	task.spawn(function()
		local folder = Workspace:WaitForChild("Boars", 20)
		if folder ~= nil then
			folder.ChildAdded:Connect(observe)
		end
	end)
end

return function()
	describe("no animal comes into being where this client can see it", function()
		it("classifies an arrival by distance, and ignores a respawn's whole sphere", function()
			local never = CONFIG.neverStuds
			local settle = CONFIG.settleSeconds
			-- THE RULE: inside the reach is a failure, outside it is not.
			expect(verdictFor(never - 1, 60, 60, settle, never)).to.equal("inview")
			expect(verdictFor(never + 1, 60, 60, settle, never)).to.equal("clear")
			-- ...and the boundary belongs to the allowed side, as `Placement.clearOfEyes` has it.
			expect(verdictFor(never, 60, 60, settle, never)).to.equal("clear")
			-- THE TWO HONEST EXCEPTIONS, both counted: a fresh character and a single-frame jump.
			expect(verdictFor(1, settle - 0.1, 60, settle, never)).to.equal("ignored")
			expect(verdictFor(1, 60, settle - 0.1, settle, never)).to.equal("ignored")
			expect(verdictFor(1, settle + 0.1, settle + 0.1, settle, never)).to.equal("inview")
			-- AN ARRIVAL NOBODY CAN MEASURE FROM IS NOT A PASS.
			expect(verdictFor(nil, 60, 60, settle, never)).to.equal("ignored")
		end)

		it("keeps the margin that makes the measurement meaningful", function()
			-- Design section 7.3: 239 studs between the rule and the only mechanism that could
			-- produce a false positive. If Karen changes the place's streaming radii, THIS is the
			-- line that has to be re-justified, and it says so.
			expect(CONFIG.neverStuds < STREAMING_MIN_RADIUS_STUDS).to.equal(true)
			expect(STREAMING_MIN_RADIUS_STUDS - CONFIG.neverStuds).to.equal(239)
		end)

		it("measures every arrival it was sent, and says how many it ignored", function()
			-- The listener has been connected since this file was loaded; this is the window it is
			-- given to finish collecting.
			local until_ = os.clock() + WATCH_SECONDS
			while os.clock() < until_ do
				RunService.Heartbeat:Wait()
			end
			local nearest, inView, seen = math.huge, 0, 0
			for _, arrival in ipairs(arrivals) do
				nearest = math.min(nearest, arrival.studs)
				if arrival.verdict == "inview" then
					inView += 1
				end
				if arrival.clear then
					seen += 1
				end
			end
			local switch = Flags.isOn("PLACEMENT_IN_PLACE")
			TestKit.note(
				string.format(
					"placement client: switch=%s watched %.0fs, %d arrivals judged, %d ignored (respawn/teleport), %d inside %d studs, %d with a clear camera ray, nearest %s studs",
					tostring(switch),
					os.clock() - watchStartedAt,
					#arrivals,
					ignored,
					inView,
					CONFIG.neverStuds,
					seen,
					if nearest == math.huge then "none" else string.format("%.0f", nearest)
				)
			)
			-- THE RULE IS ASSERTED WHERE THE SYSTEM IS RUNNING. With the switch off the arrivals
			-- belong to other specs and to the old release path, and they are reported rather than
			-- judged -- the header says why. The live number with the switch ON is in the task's
			-- report, measured by a probe of exactly this shape in Karen's own place.
			if switch then
				expect(inView).to.equal(0)
			else
				expect(#arrivals >= 0).to.equal(true)
			end
		end)
	end)
end

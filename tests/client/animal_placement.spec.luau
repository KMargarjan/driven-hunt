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
-- ONE FRAME, AND NOT A WINDOW OF ITS OWN. The listener has been collecting since this file was
-- loaded -- eleven seconds by the time the case runs, in the measured DEV runs -- so a wait here
-- would buy nothing and COST something: the client suite shares its session with the harness's real
-- input replay, and a case that holds the clock for four seconds moves every later case into a
-- different part of that replay. MEASURED: with a 4 s wait here, `camera_client.spec:2610` (the
-- cursor's two-tag release, which runs after this file) failed in 2 of 4 runs at this same commit
-- and passed in 2; with this line it is one frame.
local WATCH_FRAMES = 1

local player = Players.LocalPlayer

-- ------------------------------------------------------------------------------ THE PURE CLASSIFIER
-- IS THIS ARRIVAL ONE THE RULE JUDGES, AND DOES IT BREAK THE RULE? Returns "ignored", "clear" or
-- "inview".
--
-- THE DISTANCE RULE IS **ASKED**, NOT RESTATED (round 1, finding 2): the one answer to "is that
-- point clear of a player's eyes" is `Placement.clearOfEyes`, so replacing it with `return true`
-- reds this file's own case, exactly as it reds the server's (lesson L-093). What is this file's own
-- is the two exceptions below and nothing else.
local function verdictFor(
	at: Vector3?,
	eye: Vector3?,
	sinceCharacter: number,
	sinceJump: number,
	settle: number,
	never: number
): string
	-- NO BODY TO MEASURE FROM is not a pass: it is an arrival nobody can judge.
	if at == nil or eye == nil then
		return "ignored"
	end
	-- A RESPAWN OR A TELEPORT BRINGS A WHOLE 384-STUD SPHERE AT ONCE, from 0 studs outward: the
	-- honest exception, and it is COUNTED so that a drive which ignored everything cannot read as a
	-- pass (design section 7.3).
	if sinceCharacter < settle or sinceJump < settle then
		return "ignored"
	end
	local clear = Placement.clearOfEyes(at :: Vector3, { eye :: Vector3 }, never)
	return if clear then "clear" else "inview"
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
	local where = if root ~= nil then (root :: BasePart).Position else nil
	local studs = if where ~= nil and me ~= nil then ((where :: Vector3) - (me :: Vector3)).Magnitude else nil
	local now = os.clock()
	local verdict = verdictFor(where, me, now - characterAt, now - jumpAt, CONFIG.settleSeconds, CONFIG.neverStuds)
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
			local eye = Vector3.new(0, 0, 0)
			local function at(studs: number): Vector3
				return Vector3.new(0, 0, studs)
			end
			-- THE RULE, THROUGH `Placement.clearOfEyes`: inside the reach is a failure, outside it is
			-- not. Replace that function with `return true` and these three lines go red.
			expect(verdictFor(at(never - 1), eye, 60, 60, settle, never)).to.equal("inview")
			expect(verdictFor(at(never + 1), eye, 60, 60, settle, never)).to.equal("clear")
			-- ...and the boundary belongs to the allowed side, as `clearOfEyes` has it.
			expect(verdictFor(at(never), eye, 60, 60, settle, never)).to.equal("clear")
			-- THE TWO HONEST EXCEPTIONS, both counted: a fresh character and a single-frame jump.
			expect(verdictFor(at(1), eye, settle - 0.1, 60, settle, never)).to.equal("ignored")
			expect(verdictFor(at(1), eye, 60, settle - 0.1, settle, never)).to.equal("ignored")
			expect(verdictFor(at(1), eye, settle + 0.1, settle + 0.1, settle, never)).to.equal("inview")
			-- AN ARRIVAL NOBODY CAN MEASURE FROM IS NOT A PASS.
			expect(verdictFor(nil, eye, 60, 60, settle, never)).to.equal("ignored")
			expect(verdictFor(at(1), nil, 60, 60, settle, never)).to.equal("ignored")
		end)

		it("keeps the margin that makes the measurement meaningful", function()
			-- Design section 7.3: 239 studs between the rule and the only mechanism that could
			-- produce a false positive. If Karen changes the place's streaming radii, THIS is the
			-- line that has to be re-justified, and it says so.
			expect(CONFIG.neverStuds < STREAMING_MIN_RADIUS_STUDS).to.equal(true)
			expect(STREAMING_MIN_RADIUS_STUDS - CONFIG.neverStuds).to.equal(239)
		end)

		it("measures every arrival it was sent, and says how many it ignored", function()
			-- The listener has been connected since this file was loaded; this is one frame to let
			-- an arrival in flight land, and the note below says how long that window really was.
			for _ = 1, WATCH_FRAMES do
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
			if not switch then
				TestKit.note(
					"placement client: PLACEMENT_IN_PLACE is OFF, so NOTHING WAS JUDGED by the in-view rule in this run"
				)
			end
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
			-- THE RULE IS ASSERTED WHERE THE SYSTEM IS RUNNING, AND NOTHING IS ASSERTED WHERE IT IS
			-- NOT (round 1, finding 2). With the switch off the arrivals belong to other specs and
			-- to the old release path; the note above carries the measurement and says in so many
			-- words that nothing was judged, rather than an `expect` that cannot fail standing in
			-- for one. The live number with the switch ON is in the task's report, measured by a
			-- probe of exactly this shape in Karen's own place.
			if switch then
				expect(inView).to.equal(0)
			end
		end)
	end)
end

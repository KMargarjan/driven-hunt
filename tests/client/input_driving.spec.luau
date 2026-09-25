-- input_driving.spec: proves the harness can drive REAL player input, and that it arrives through the
-- path a player's input takes -- ContextActionService and UserInputService events delivered by the
-- engine to client code -- not by calling a handler directly. This is TASKS.md Task 6, and its shape
-- is what the regenerated shotgun design asks for: a key down and up, a mouse button down and up, and
-- two inputs in sequence with an observable gap between them. That is section 13.3 ("Task 6 - exactly
-- what the smallest version must prove") of the Task 23 regeneration, on branch
-- task-23-shotgun-design-v2; in the Task 19 design still on main the same unblock is section 11.3.
--
-- Pattern: record-then-assert. The module body (which TestKit requires before TestEZ runs) binds the
-- listeners and publishes a "ready" attribute; the harness waits for that attribute, replays
-- tests/client/input_scenarios.txt through StudioMCP's user_keyboard_input / user_mouse_input, and
-- the `it` blocks below wait for the recorded events and assert over them.
--   ContextActionService  https://create.roblox.com/docs/reference/engine/classes/ContextActionService
--     BindAction(name, handler, createTouchButton, ...) -- the handler gets (name, state, inputObject)
--   UserInputService      https://create.roblox.com/docs/reference/engine/classes/UserInputService
--     InputBegan/InputEnded/InputChanged -- the only way to see mouse movement, which CAS cannot bind
--   TestEZ describe/it/expect  https://roblox.github.io/testez/api-reference/
--
-- The scenario is one file on disk, read by BOTH sides: the harness replays it, and this spec derives
-- what it expects from it. It is a .txt holding JSON because Rojo turns a .txt into a StringValue the
-- harness already compares byte-for-byte, so the scenario the client sees is provably the file on
-- disk, and adding a new mapping would need default.project.json (a Rojo restart, which needs Karen).
--
-- Note: docs/research/2026-09-24-toolchain.md (addendum: driving real input)
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ACTION_NAME = "DrivenHunt.Test.InputProbe"
-- Seconds to wait for the harness's replay; it starts within ~2 s of the ready handshake. Raised
-- from 25 in Task 36: `test2` sends every step to both clients, so each one costs two calls.
local ARRIVE_TIMEOUT = 45
-- The harness sleeps the scenario's gap in Python, so the gap the client sees can only be LONGER than
-- asked. The tolerance is for clock skew between that sleep and os.clock() here, nothing more.
local GAP_TOLERANCE = 0.6

local InputReady = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("InputReady"))

-- Every event the engine delivered, in arrival order. `source` says which real path carried it.
local log = {}

local function record(source: string, phase: string, name: string)
	table.insert(log, { source = source, phase = phase, name = name, at = os.clock() })
end

-- The name an InputObject is known by: the key for a keyboard event, the input type otherwise.
local function inputName(input: InputObject): string
	if input.KeyCode ~= Enum.KeyCode.None then
		return input.KeyCode.Name
	end
	return input.UserInputType.Name
end

local scenarios = nil
local scenarioError = nil
do
	local value = ReplicatedStorage:WaitForChild("ClientTests", 10)
	value = value and value:FindFirstChild("input_scenarios")
	if not value or not value:IsA("StringValue") then
		scenarioError = "ReplicatedStorage.ClientTests.input_scenarios is missing (Rojo did not sync it)"
	else
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value.Value)
		if ok then
			scenarios = decoded
		else
			scenarioError = "input_scenarios is not valid JSON: " .. tostring(decoded)
		end
	end
end

-- Bind at require time, before TestEZ runs anything: the harness must not be able to replay into a
-- client that is not listening yet. `Pass` so nothing a player does is swallowed by the test.
local function onAction(_name: string, state: Enum.UserInputState, input: InputObject)
	record("cas", state.Name, inputName(input))
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction(
	ACTION_NAME,
	onAction,
	false,
	Enum.KeyCode.F,
	Enum.KeyCode.R,
	Enum.UserInputType.MouseButton1,
	Enum.UserInputType.MouseButton2
)

local connections = {
	UserInputService.InputBegan:Connect(function(input: InputObject)
		record("uis", "Begin", inputName(input))
	end),
	UserInputService.InputEnded:Connect(function(input: InputObject)
		record("uis", "End", inputName(input))
	end),
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			record("uis", "Change", "MouseMovement")
		end
	end),
}

-- The handshake. The harness replays only once the attribute carries THIS run's token, so the replay
-- can never race the bindings above. Since Task 24 there is more than one client spec binding input,
-- so the attribute is written by ONE rendezvous module when EVERY expected spec is ready, never by a
-- spec itself (docs/design/shotgun.md section 13.3).
if scenarios then
	InputReady.ready("input_driving")
end

-- What the scenario's steps must produce, in order: {source, phase, name} plus, for a `wait` step,
-- the gap that must be visible between the events on either side of it. A step this does not
-- understand is an ERROR, never a skip: the harness would still send it, and a silently skipped step
-- means the spec proves less than the file says it does (review round 1).
local function expectedFrom(steps)
	local expected, errors = {}, {}
	local pendingGap = nil
	local function push(source, phase, name)
		table.insert(expected, { source = source, phase = phase, name = name, gapBefore = pendingGap })
		pendingGap = nil
	end
	for index, step in ipairs(steps) do
		local button = if step.button == "right" then "MouseButton2" else "MouseButton1"
		if step.device == "keyboard" and step.action == "keyDown" then
			push("cas", "Begin", step.key)
		elseif step.device == "keyboard" and step.action == "keyUp" then
			push("cas", "End", step.key)
		elseif step.device == "keyboard" and step.action == "keyPress" then
			push("cas", "Begin", step.key)
			push("cas", "End", step.key)
		elseif step.device == "mouse" and step.action == "moveTo" then
			push("uis", "Change", "MouseMovement")
		elseif step.device == "mouse" and step.action == "mouseButtonDown" then
			push("cas", "Begin", button)
		elseif step.device == "mouse" and step.action == "mouseButtonUp" then
			push("cas", "End", button)
		elseif step.device == "mouse" and step.action == "mouseButtonClick" then
			push("cas", "Begin", button)
			push("cas", "End", button)
		elseif step.device == "wait" then
			pendingGap = (step.ms or 0) / 1000
		else
			table.insert(errors, string.format("step %d: %s/%s", index, tostring(step.device), tostring(step.action)))
		end
	end
	return expected, errors
end

-- The recorded events that match `expected`, in order, ignoring anything else the engine delivered
-- (the player's own mouse, a stray key). Returns the matched entries, shortest prefix first.
-- A real mouse move by whoever is at the machine satisfies a `MouseMovement` expectation as well as
-- the replayed one does (review round 1). The two CAS button events still pin the run to the replay,
-- and the scenario puts its `wait` AFTER the move precisely so that an early stray move can only make
-- the waited gap longer, never shorter.
local function matchInOrder(expected)
	local matched, at = {}, 1
	for _, entry in ipairs(log) do
		local want = expected[at]
		if want and entry.source == want.source and entry.phase == want.phase and entry.name == want.name then
			table.insert(matched, entry)
			at += 1
		end
	end
	return matched
end

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

return function()
	describe("harness-driven input", function()
		local scenario = scenarios and scenarios.scenarios and scenarios.scenarios[1]
		local expected, stepErrors = {}, {}
		if scenario then
			expected, stepErrors = expectedFrom(scenario.steps)
		end
		local matched = {}

		it("has a scenario on disk, synced to the client, and understands every step in it", function()
			expect(scenarioError).to.equal(nil)
			expect(scenario).to.be.ok()
			expect(#expected > 0).to.equal(true)
			if #stepErrors > 0 then
				print("[input_driving] steps this spec does not understand: " .. table.concat(stepErrors, ", "))
			end
			expect(#stepErrors).to.equal(0)
		end)

		it("sees every step of the scenario arrive", function()
			local arrived = waitUntil(ARRIVE_TIMEOUT, function()
				matched = matchInOrder(expected)
				return #matched == #expected
			end)
			if not arrived then
				local seen = {}
				for _, entry in ipairs(log) do
					table.insert(seen, string.format("%s/%s/%s", entry.source, entry.phase, entry.name))
				end
				print(
					string.format(
						"[input_driving] matched %d of %d; log: %s",
						#matched,
						#expected,
						table.concat(seen, ", ")
					)
				)
			end
			expect(arrived).to.equal(true)
		end)

		it("saw the key press and release as separate events", function()
			local downs, ups = 0, 0
			for _, entry in ipairs(matched) do
				if entry.name == "F" and entry.phase == "Begin" then
					downs += 1
				elseif entry.name == "F" and entry.phase == "End" then
					ups += 1
				end
			end
			expect(downs).to.equal(1)
			expect(ups).to.equal(1)
		end)

		it("saw the mouse button through ContextActionService, and the move through UserInputService", function()
			local casButton, uisMove = 0, 0
			for _, entry in ipairs(matched) do
				if entry.source == "cas" and entry.name == "MouseButton1" then
					casButton += 1
				elseif entry.source == "uis" and entry.name == "MouseMovement" then
					uisMove += 1
				end
			end
			expect(casButton).to.equal(2) -- down and up
			expect(uisMove >= 1).to.equal(true)
		end)

		it("carried the scenario's gap: a waited step arrives later than an unwaited one", function()
			local waited, gaps = nil, {}
			for index = 2, #matched do
				local gap = matched[index].at - matched[index - 1].at
				if expected[index].gapBefore then
					waited = { want = expected[index].gapBefore, got = gap }
				else
					table.insert(gaps, gap)
				end
			end
			expect(waited).to.be.ok()
			-- The harness sleeps this gap, so it can only ever be longer, never shorter, than asked.
			expect(waited.got >= waited.want * GAP_TOLERANCE).to.equal(true)
			-- AGAINST THE TYPICAL UNWAITED GAP, not the largest one (Task 34). In a two-player local
			-- test this client is a background window rendering at about 15 fps, and one scheduling
			-- hitch between two unwaited steps is enough to beat a deliberate 0.3 s gap -- which
			-- would fail a claim that is still true of the replay. The median says what the claim
			-- means: a gap the scenario asked for stands out from ordinary step-to-step spacing.
			-- A scenario with no unwaited step has nothing to compare against, and 0 would make the
			-- comparison below trivially true. That is a broken scenario, not a passing test.
			expect(#gaps > 0).to.equal(true)
			table.sort(gaps)
			local typical = gaps[math.ceil(#gaps / 2)]
			print(string.format("[input_driving] waited %.3f s vs typical %.3f s", waited.got, typical))
			expect(waited.got > typical).to.equal(true)
		end)

		it("recorded the events in the scenario's order", function()
			expect(#matched).to.equal(#expected)
			for index, entry in ipairs(matched) do
				expect(entry.source).to.equal(expected[index].source)
				expect(entry.phase).to.equal(expected[index].phase)
				expect(entry.name).to.equal(expected[index].name)
			end
		end)

		it("leaves nothing bound behind", function()
			ContextActionService:UnbindAction(ACTION_NAME)
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			expect(ContextActionService:GetAllBoundActionInfo()[ACTION_NAME]).to.equal(nil)
		end)
	end)
end

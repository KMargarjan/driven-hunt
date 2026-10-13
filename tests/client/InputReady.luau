-- InputReady: the ONE writer of the harness's ready attribute (tools/studio_mcp.py, replay_input).
--
-- The harness waits for a single attribute carrying the run's token and then replays EVERY scenario
-- in the file. With more than one client spec binding input, whoever set that attribute first would
-- start the replay and could race the other spec's bindings. So no spec sets it: each one says it is
-- ready here, and the attribute is set only when every expected spec has.
--
-- If a listed spec never becomes ready the attribute is never set, the harness's
-- "[input] the client bound its listeners and published this run's token" check fails after 60 s
-- (per client, since Task 36 waits for every one of them), and the run is red. There is no path where the replay proceeds against an unprepared client, and
-- none where a missing spec passes quietly.
--
-- Design: docs/design/shotgun.md (section 13.3)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local InputReady = {}

InputReady.ATTRIBUTE = "InputProbeReady" -- must equal the scenario file's `readyAttribute`
-- ORDER MATTERS AND IT IS NOT PINNED BY ANYTHING ELSE (Task 30 review note (e)). TestEZ runs the
-- spec modules in the order the specs folder lists them, and two of them depend on it:
--   * camera_client's zero-write assertions must land before weapon_client's baseline;
--   * zz_tie_to_a_tree must run LAST, because a tie takes the gun away and every armed assertion
--     before it would then fail. Its `zz_` prefix is what puts it there, and its scenario is the
--     last one in input_scenarios.txt for the same reason.
-- This list is not the runner's order -- it is only who must be ready -- but it is the one place
-- every input-driven spec is named, so the rule is written down here.
InputReady.EXPECTED = { "input_driving", "weapon_client", "camera_client", "shoot_boar", "zz_tie_to_a_tree" }

-- THE REPLAY MAY NOT START BEFORE THE DRIVE IS OPEN (task 174), AND THIS IS THE ONE PLACE THAT CAN
-- SAY SO. Since task 174 a shot is refused unless the drive is between its two signals
-- (`Weapon.Rules.DRIVE_OVER`, off `Match.driveOpen`), so a replayed click that lands in the
-- countdown, the start fanfare or the results scene spends no shell and fires nothing -- and three of
-- the five specs below replay CLICKS whose whole claim is what the shot did.
--
-- IT IS A RACE AND IT WAS MEASURED, in two runs of the same commit (`b355b37`): the cue landed at
-- **+49.3 s** in one and at **+4.1 s** in the other, because how fast a Play client comes up is not
-- this suite's to decide. The DEV drive reaches `Running` ~15 s after the player joins and GO 2.18 s
-- later, so the early run fired both clicks inside `Assigning` -- `weapon_client`'s "fired exactly
-- twice" saw **0** shots and its pocket read 14 instead of 12 (the two slugs went back in because
-- they were never spent). Nothing was wrong with the game: the gate did exactly what Karen asked for.
--
-- SO THE FIX IS HERE AND NOT IN FIVE SPECS. The harness replays only after this attribute appears, so
-- holding it until the drive is open puts EVERY replayed click of EVERY spec inside an open drive,
-- deterministically, in one place -- rather than each firing spec stating the drive for itself, which
-- a client cannot do anyway: the gate is the SERVER's and no client may move it.
--
-- THIS IS NOT A SECOND ANSWER TO "IS THE DRIVE OPEN". It is this client's own snapshot -- the two
-- fields the server publishes and the Hud already reads (`Match.phase`, `Match.holdSecondsLeft`) --
-- and it decides exactly one thing: WHEN THE TEST FIRES. It allows nothing and refuses nothing.
InputReady.OPEN_DRIVE_TIMEOUT = 45

-- The client's own drive module, resolved lazily and tolerantly -- the shape `weapon_client`'s
-- `cameraView` already uses, and for the same reason: a place with no drive in it must still replay.
local function driveModule(): any?
	local player = Players.LocalPlayer
	local scripts = if player then player:FindFirstChild("PlayerScripts") else nil
	local module = if scripts then scripts:FindFirstChild("Match") else nil
	if module == nil or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, match = pcall(require, module)
	return if ok and type(match) == "table" then match else nil
end

-- IS THE DRIVE OPEN, as this client's snapshot says? `Running`, and the start fanfare finished --
-- which is `Match.holdSecondsLeft() <= 0`, the same number the Hud's own objective line uses.
-- TRUE when there is no drive at all, because then nothing refuses a shot either.
function InputReady.driveOpen(): boolean
	local match = driveModule()
	if match == nil then
		return true
	end
	local ok, open = pcall(function()
		return match.phase() == "Running" and match.holdSecondsLeft() <= 0
	end)
	return not ok or open == true
end

-- WHAT THE DRIVE WAS, FOR A NOTE. One short string, so a spec can print the drive its shot stood in
-- instead of leaving the next reader to guess (the Director's own instruction, 2026-10-13).
function InputReady.drivePrint(): string
	local match = driveModule()
	if match == nil then
		return "no drive"
	end
	local ok, text = pcall(function()
		return string.format(
			"phase=%s hold=%.1f open=%s",
			tostring(match.phase()),
			match.holdSecondsLeft(),
			tostring(InputReady.driveOpen())
		)
	end)
	return if ok then text else "drive unreadable"
end

-- Waits for the drive to open, up to `seconds`. Returns whether it is open and one line about it.
-- IT GIVES UP RATHER THAN HANGING: a drive that never opens would otherwise hold the ready attribute
-- for ever, and the harness's own "the client bound its listeners" check would fail after 60 s with
-- nothing in the log about why. Replaying into a shut drive fails the firing specs instead, loudly,
-- with this line beside them -- which is the honest failure of the two.
function InputReady.waitForOpenDrive(seconds: number?): (boolean, string)
	local began = os.clock()
	local deadline = began + (seconds or InputReady.OPEN_DRIVE_TIMEOUT)
	repeat
		if InputReady.driveOpen() then
			return true,
				string.format("the drive was open after %.1f s (%s)", os.clock() - began, InputReady.drivePrint())
		end
		task.wait(0.1)
	until os.clock() > deadline
	return false, string.format("the drive did not open in %.1f s (%s)", os.clock() - began, InputReady.drivePrint())
end

local done = {}

function InputReady.ready(name: string)
	local known = false
	for _, expected in ipairs(InputReady.EXPECTED) do
		if expected == name then
			known = true
			break
		end
	end
	-- A typo must fail loudly here, not silently never signal.
	assert(known, "InputReady.ready: unknown spec name " .. tostring(name))
	done[name] = true

	for _, expected in ipairs(InputReady.EXPECTED) do
		if not done[expected] then
			return
		end
	end

	local token = TestKit.openToken()
	if token then
		-- ...AND THE LAST THING BEFORE THE REPLAY IS THE DRIVE (task 174, above). Printed either way:
		-- the one line in the console says which drive every replayed click of this run stood in.
		local open, why = InputReady.waitForOpenDrive()
		if open then
			print("[input] " .. why .. "; replaying")
		else
			warn("[input] " .. why .. "; replaying anyway, so the firing specs say so themselves")
		end
		Players.LocalPlayer:SetAttribute(InputReady.ATTRIBUTE, token)
	end
end

return InputReady

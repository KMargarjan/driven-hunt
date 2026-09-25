-- InputReady: the ONE writer of the harness's ready attribute (tools/studio_mcp.py, replay_input).
--
-- The harness waits for a single attribute carrying the run's token and then replays EVERY scenario
-- in the file. With more than one client spec binding input, whoever set that attribute first would
-- start the replay and could race the other spec's bindings. So no spec sets it: each one says it is
-- ready here, and the attribute is set only when every expected spec has.
--
-- If a listed spec never becomes ready the attribute is never set, the harness's
-- "[input] the client bound its listeners and published this run's token" check fails after 20 s,
-- and the run is red. There is no path where the replay proceeds against an unprepared client, and
-- none where a missing spec passes quietly.
--
-- Design: docs/design/shotgun.md (section 13.3)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local InputReady = {}

InputReady.ATTRIBUTE = "InputProbeReady" -- must equal the scenario file's `readyAttribute`
InputReady.EXPECTED = { "input_driving", "weapon_client", "camera_client" }

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
		Players.LocalPlayer:SetAttribute(InputReady.ATTRIBUTE, token)
	end
end

return InputReady

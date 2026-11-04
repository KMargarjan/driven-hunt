-- TestRunner: runs the server specs (ServerStorage.Tests) through TestKit when the harness opens the gate.
-- Pattern: thin runner over TestKit (tests/TestKit.luau). Full description: tools/studio_mcp.py docstring.
-- Note: docs/research/2026-09-24-toolchain.md
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

-- WHERE THIS RUN GOT TO, published as it goes (task 328t). Every stop between boot and the report
-- used to be silent, so a missing TestReport named nothing -- four hours of 328s went on guessing.
-- Read by tools/studio_mcp.py when the report does not arrive.
local lastStage, startedAt = "boot", os.clock()
-- A TRAIL AND NOT ONE WORD: Studio's console comes back truncated from a run this long (the whole
-- head of it is gone -- the same reason TestKit.note exists), so the last stages travel on the
-- attribute WITH their timestamps. Thirty is enough to tell a crawl from a stop and name the test.
local TRAIL = 30
local trail: { string } = {}

local function mark(name: string)
	lastStage = name
	table.insert(trail, string.format("%.0fs %s", os.clock() - startedAt, name))
	if #trail > TRAIL then
		table.remove(trail, 1)
	end
	pcall(function()
		ServerStorage:SetAttribute("TestStage", name)
		ServerStorage:SetAttribute("TestStageTrail", table.concat(trail, " >> "))
	end)
end

mark("boot")

-- THE ERROR NOBODY SAW. Studio's console comes back truncated and this place's log is flooded by
-- the fake asset ids a spec fixture uses on purpose, so an unhandled error in the suite was
-- invisible: the run just stopped (task 328t). The engine's own errors are kept here instead, with
-- the asset noise filtered out, and travel on an attribute like everything else.
local ASSET_NOISE = {
	"Asset is not trusted",
	"not authorized to access Asset",
	"access permission to use asset",
	"failed to load",
	"Failed to load",
}
local errors: { string } = {}

LogService.MessageOut:Connect(function(message: string, messageType: Enum.MessageType)
	if messageType ~= Enum.MessageType.MessageError then
		return
	end
	for _, noise in ASSET_NOISE do
		if string.find(message, noise, 1, true) then
			return
		end
	end
	table.insert(errors, string.sub(message, 1, 240))
	if #errors > 6 then
		table.remove(errors, 1)
	end
	pcall(function()
		ServerStorage:SetAttribute("TestStageErrors", table.concat(errors, " ## "))
	end)
end)

-- IS IT HUNG OR IS IT DEAD? A stage that stops moving says nothing on its own; a clock beside it
-- that also stops says the thread is gone, and one that keeps ticking says it is waiting.
task.spawn(function()
	while true do
		task.wait(5)
		pcall(function()
			ServerStorage:SetAttribute(
				"TestStageAge",
				string.format("%.0f s since boot, last stage %s", os.clock() - startedAt, lastStage)
			)
		end)
	end
end)

-- awaitToken, not openToken: a two-player run cannot put the token in the place these processes
-- start from, so it arrives after they are up (tools/studio_mcp.py docstring, `test2`). The gate is
-- the same one -- Studio, and a token under 120 s old -- so a playtest still runs no tests.
local token = TestKit.awaitToken()
if not token then
	mark("no-token")
	return
end
mark("token-ok")
TestKit.onStage = mark

-- xpcall AND NOT A BARE CALL: `TestKit.run` pcalls the TestEZ run, but nothing covered the
-- pre-pass's own caller or this line, so a throw here ended the run with no report and no word.
local ran, report = xpcall(TestKit.run, debug.traceback, "server", token, ServerStorage:FindFirstChild("Tests"))
if not ran then
	mark("run-threw: " .. string.sub(tostring(report), 1, 240))
	return
end
mark("run-returned")
-- THE DRIVE-CLOCK SEAM, observed from OUTSIDE TestKit after the run returned (audit-004 F5). Asked
-- here rather than inside `TestKit.finish`, where the answer would sit one line below the assignment
-- that makes it true and could only ever be `true` in a committed state. `activeToken` is what
-- `Match.advanceForTests` asks "is a gated test run in progress"; left set, the seam stays open for
-- the rest of a Studio session a human is about to play in.
--
-- It travels in the report because nothing outside the module can see the upvalue: MEASURED, a query
-- that requires ReplicatedStorage.TestKit through `execute_luau` gets a DIFFERENT instance, out of its
-- own require cache, and answers about a token nothing ever set.
report.seamClosed = TestKit.activeToken() == nil
-- Read by tools/studio_mcp.py from the Server DataModel. MEASURED not to be the fault (task 328t):
-- the thread never reached this line -- the engine had killed it mid-suite.
local encoded = HttpService:JSONEncode(report)
mark("encoded")
ServerStorage:SetAttribute("TestReport", encoded)
mark("report-set")

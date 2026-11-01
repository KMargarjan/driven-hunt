-- RangeBoot: the client root of the range's PICTURE (design 9.5). It is the only thing that knows
-- both the board remote and the mask, so neither owner requires the other -- the mask never reads
-- a remote and the board's drawer never reads a part.
--
-- Three jobs and nothing else: start the two pictures when the targets folder exists, hand them the
-- board payload's `mine`, `window` and `alone` (the SERVER's measurement, design 9.4, 10.3), and
-- step them once a Heartbeat. The shape of src/client/AmbienceBoot.client.luau.
--
-- TWO PICTURES, TWO OWNERS (task 313, design 7.4): `Mask` hides other men's ANIMALS, `Solo` hides
-- other men. Two owners so a defect in the character sweep cannot hide an animal.
--
-- Design: docs/design/shooting-range-lobby.md sections 4.4, 7, 9.4, 9.5
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RangeData = require(ReplicatedStorage:WaitForChild("Range"))

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local rangeScripts = scripts:WaitForChild("Range")
local Mask = require(rangeScripts:WaitForChild("Mask"))
local Solo = require(rangeScripts:WaitForChild("Solo"))

-- THE FOLDER MAY NOT BE THERE YET, AND IN A PLACE WITH NO RANGE IT NEVER IS. So this is a start
-- that can be asked more than once and does nothing until the folder replicates: `Mask.start`
-- returns false before touching any state when the folder is missing.
local started = false
local function tryStart(): boolean
	if started then
		return true
	end
	local folder = Workspace:FindFirstChild(RangeData.TARGETS_FOLDER)
	if folder == nil then
		return false
	end
	started = Mask.start({ root = folder, player = Players.LocalPlayer, now = os.clock })
	if started then
		-- IT WRITES NOTHING UNTIL THE SERVER SAYS `alone`, and in a place with no range it never
		-- starts at all, so nobody is ever hidden outside the range.
		Solo.start({ me = Players.LocalPlayer })
	end
	return started
end

tryStart()
Workspace.ChildAdded:Connect(function(child)
	if child.Name == RangeData.TARGETS_FOLDER then
		tryStart()
	end
end)

-- WHAT THE SERVER TOLD HIM. A second connection on `RangeBoard` beside the Hud's is deliberate:
-- the Hud draws the board, this one aims the mask, and neither reaches into the other's state.
local remotes = RangeData.remotes()
remotes.RangeBoard.OnClientEvent:Connect(function(payload)
	local record = if type(payload) == "table" then (payload :: any).record else nil
	if type(record) ~= "table" then
		return
	end
	-- The payload can beat the folder's replication, so ask again here rather than on every frame.
	tryStart()
	-- THE IDS AS WELL AS THE INSTANCE (task 321 (e)): the Instance can beat its own replication and
	-- arrive nil, and then only the names tell the mask which animal is his.
	Mask.setMine((record :: any).mine, (record :: any).mineIds)
	Solo.setAlone((record :: any).alone == true)
	local window = (record :: any).window
	if type(window) == "table" then
		Mask.setWindow(window.minX, window.maxX)
	else
		Mask.setWindow(nil, nil)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	Mask.step(dt)
	Solo.step(dt)
end)

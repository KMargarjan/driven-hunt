-- CarcassPoseBoot: the client root of task 358. THE ONE READ OF THE FLAG, at this boundary, passed
-- inward as a parameter -- the only permitted shape (CLAUDE.md, feature flags), and what keeps both
-- states reachable while the row sits at one of them.
--
-- Three jobs and nothing else: start the owner when the animals' folder exists, ask again if the
-- folder arrives later, and step it once a Heartbeat. The shape of src/client/RangeBoot.client.luau.
--
-- Design: docs/design/carcass-pose.md sections 2, 6.3
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local CarcassPose = require(scripts:WaitForChild("CarcassPose"))

local on = Flags.isOn("CARCASS_POSE")

-- THE FOLDER MAY NOT BE THERE YET, and in a place with no animals it never is. So this is a start
-- that can be asked more than once and does nothing until the folder replicates.
local started = false
local function tryStart(): boolean
	if started or not on then
		return started
	end
	started = CarcassPose.start({ enabled = on })
	return started
end

tryStart()
Workspace.ChildAdded:Connect(function(child)
	if child.Name == CarcassPose.FOLDER_NAME then
		tryStart()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	-- With the flag off `start` was never called, so this returns on its first line: no sweep, no
	-- read, no instance.
	CarcassPose.step(dt)
end)

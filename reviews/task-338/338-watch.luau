-- Task 338: the got-away instrument. Installs ONE watcher on the live Boars folder and one on the
-- escape wire's producer side, and keeps its tally in a StringValue a later probe reads.
local SS = game:GetService("ServerStorage")
local ws = game:GetService("Workspace")
local existing = SS:FindFirstChild("DH338")
if existing then return "already installed: " .. existing.Value end
local box = Instance.new("StringValue")
box.Name = "DH338"
box.Value = ""
box.Parent = SS
local log = {}
local tally = { added = 0, removed = 0, pastExit = 0 }
local Data = require(game:GetService("ReplicatedStorage").ForestTest)
local live = game.ReplicatedStorage.ForestTest:FindFirstChild("Live")
local layoutName = live and live:GetAttribute("layout") or "?"
local layout = Data.layoutOf(layoutName)
local exitZ = Data.exitZOf(layout)
local t0 = os.clock()
local pos = {}
local folder = ws:FindFirstChild("Boars")
local function watch(f)
	f.ChildAdded:Connect(function(c)
		tally.added += 1
		table.insert(log, string.format("+%.1f ADD %s", os.clock() - t0, c.Name))
	end)
	f.ChildRemoved:Connect(function(c)
		tally.removed += 1
		local p = pos[c.Name]
		local past = p ~= nil and p.Z <= exitZ
		if past then
			tally.pastExit += 1
		end
		table.insert(
			log,
			string.format(
				"+%.1f DEL %s z=%s exit=%d past=%s",
				os.clock() - t0,
				c.Name,
				if p then string.format("%d", p.Z) else "?",
				exitZ,
				tostring(past)
			)
		)
	end)
end
if folder then
	watch(folder)
else
	ws.ChildAdded:Connect(function(c)
		if c.Name == "Boars" then
			watch(c)
		end
	end)
end
task.spawn(function()
	while box.Parent ~= nil do
		local f = ws:FindFirstChild("Boars")
		if f then
			for _, m in ipairs(f:GetChildren()) do
				local part = if m:IsA("Model") then (m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")) else nil
				if m:IsA("BasePart") then
					part = m
				end
				if part then
					pos[m.Name] = part.Position
				end
			end
		end
		box.Value = string.format(
			"added=%d removed=%d pastExit=%d exitZ=%d layout=%s | %s",
			tally.added,
			tally.removed,
			tally.pastExit,
			exitZ,
			layoutName,
			table.concat(log, " ; ")
		)
		task.wait(0.2)
	end
end)
return string.format("installed layout=%s exitZ=%d folder=%s", layoutName, exitZ, tostring(folder ~= nil))

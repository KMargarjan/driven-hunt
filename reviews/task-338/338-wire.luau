-- Task 338: counts the escape entries THIS CLIENT is sent, which is exactly what the toast stacks.
local RS = game:GetService("ReplicatedStorage")
local existing = RS:FindFirstChild("DH338Wire")
if existing then return "already installed: " .. existing.Value end
local box = Instance.new("StringValue")
box.Name = "DH338Wire"
box.Value = ""
box.Parent = RS
local drive = RS:FindFirstChild("Drive")
local folder = drive and drive:FindFirstChild("Remotes")
local ev = folder and folder:FindFirstChild("MatchEvent")
if ev == nil then
	box.Value = "no MatchEvent"
	return "no MatchEvent found"
end
local n, kinds, t0, log = 0, {}, os.clock(), {}
ev.OnClientEvent:Connect(function(entry)
	local k = tostring(entry and entry.kind)
	kinds[k] = (kinds[k] or 0) + 1
	if k == "escape" then
		n += 1
		if #log < 200 then
			table.insert(log, string.format("+%.1f %s", os.clock() - t0, tostring(entry.name or entry.userId or "-")))
		end
	end
	local parts = {}
	for key, v in pairs(kinds) do
		table.insert(parts, key .. "=" .. v)
	end
	table.sort(parts)
	box.Value = string.format("escape=%d | %s | %s", n, table.concat(parts, " "), table.concat(log, " ; "))
end)
return "installed on " .. ev:GetFullName()

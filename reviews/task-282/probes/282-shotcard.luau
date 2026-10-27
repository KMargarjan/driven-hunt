local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
local head = me.Character and me.Character:FindFirstChild("Head")
local aim = me:GetAttribute("DH282_aim")
if not head or typeof(aim) ~= "Vector3" then return "no head/aim" end
local r = RS:WaitForChild("Shotgun"):WaitForChild("Remotes")
local out = {}
r.ActionRequest:FireServer("SelectAmmo", "Buck")
task.wait(3.5)
local origin = head.Position
local dir = (aim - origin).Unit
r.FireRequest:FireServer({ origin = origin, direction = dir })
task.wait(1.2)
table.insert(out, string.format("fired %.1f studs", (aim - origin).Magnitude))
local gui = me:FindFirstChild("PlayerGui")
local cardFrame
for _, d in ipairs(gui:GetDescendants()) do if d.Name == "HitCard" then cardFrame = d end end
if not cardFrame then return "no HitCard" end
table.insert(out, "HitCard visible=" .. tostring(cardFrame.Visible))
for _, lbl in ipairs(cardFrame:GetDescendants()) do
	if lbl:IsA("TextLabel") and lbl.Text ~= "" then table.insert(out, "  text: " .. lbl.Text) end
end
for _, art in ipairs(cardFrame:GetDescendants()) do
	if art:IsA("Frame") and art:GetAttribute("BoxU0") ~= nil then
		local dots = {}
		for _, d in ipairs(art:GetChildren()) do if d.Name == "Dot" then table.insert(dots, d) end end
		if #dots > 0 then
			table.insert(out, string.format("art %s vis=%s abs=%dx%d box u %.3f..%.3f v %.3f..%.3f dots=%d",
				art.Name, tostring(art.Visible), art.AbsoluteSize.X, art.AbsoluteSize.Y,
				art:GetAttribute("BoxU0"), art:GetAttribute("BoxU1"), art:GetAttribute("BoxV0"), art:GetAttribute("BoxV1"), #dots))
			for _, d in ipairs(dots) do
				table.insert(out, string.format("  dot true=(%.3f,%.3f) zone=%s drawn=(%.3f,%.3f)",
					d:GetAttribute("U") or -1, d:GetAttribute("V") or -1, tostring(d:GetAttribute("Zone")),
					d.Position.X.Scale, d.Position.Y.Scale))
			end
		end
	end
end
return table.concat(out, string.char(10))

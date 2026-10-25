local Players = game:GetService("Players")
local p = Players:GetPlayers()[1]
local ch = p.Character
local tools, bp = {}, {}
if ch then for _, t in ipairs(ch:GetChildren()) do if t:IsA("Tool") then table.insert(tools, t.Name) end end end
if p.Backpack then for _, t in ipairs(p.Backpack:GetChildren()) do if t:IsA("Tool") then table.insert(bp, t.Name) end end end
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
local root = ch and ch.PrimaryPart
return string.format("name=%s team=%s role=%s health=%s held=[%s] backpack=[%s] at %s",
  p.Name, tostring(p.Team and p.Team.Name), tostring(p:GetAttribute("DrivenHunt.Role") or p:GetAttribute("Role")),
  tostring(hum and hum.Health), table.concat(tools, ","), table.concat(bp, ","),
  root and string.format("%.0f,%.0f,%.0f", root.Position.X, root.Position.Y, root.Position.Z) or "?")

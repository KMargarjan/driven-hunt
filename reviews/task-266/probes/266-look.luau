local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local me = Players.LocalPlayer
local char = me.Character
local head = char and (char:FindFirstChild("Head") or char.PrimaryPart)
if head == nil then return "no char" end
local eye = (head :: BasePart).Position
local folder = Workspace:FindFirstChild("Boars")
if folder == nil then return "no Boars" end
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local ignore = { char }
for _, n in ipairs({ "Boars", "Foliage", "WeaponEffects" }) do
  local f = Workspace:FindFirstChild(n); if f then table.insert(ignore, f) end
end
params.FilterDescendantsInstances = ignore
local rows = {}
for _, part in ipairs(folder:GetChildren()) do
  if part:IsA("BasePart") and part:GetAttribute("Damageable") == true and part:GetAttribute("Carcass") ~= true then
    local d = (part.Position - eye).Magnitude
    local clear = Workspace:Raycast(eye, (part.Position + Vector3.new(0, part.Size.Y * 0.25, 0)) - eye, params) == nil
    table.insert(rows, string.format("%s(%s) d=%.0f v=%.1f %s", part.Name, tostring(part:GetAttribute("Kind")), d, part.AssemblyLinearVelocity.Magnitude, clear and "CLEAR" or "blocked"))
  end
end
table.sort(rows)
return table.concat(rows, " | ")

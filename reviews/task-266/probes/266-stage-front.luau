local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local p = Players:GetPlayers()[1]
local char = p.Character
local root = char and char.PrimaryPart
local head = char and (char:FindFirstChild("Head") or root)
if root == nil then return "no char" end
local folder = Workspace:FindFirstChild("Boars")
if folder == nil then return "no Boars" end
-- the nearest live animal, whatever it is doing: it is about to be moved anyway
local pick, bestD = nil, math.huge
for _, part in ipairs(folder:GetChildren()) do
  if part:IsA("BasePart") and part:GetAttribute("Damageable") == true and part:GetAttribute("Carcass") ~= true then
    local d = (part.Position - root.Position).Magnitude
    if d < bestD then pick, bestD = part, d end
  end
end
if pick == nil then return "NO ANIMAL at all" end
local DIST = tonumber("%DIST%") or 100
local look = root.CFrame.LookVector
local flat = Vector3.new(look.X, 0, look.Z).Unit
local spot = root.Position + flat * DIST
-- ground under the spot, from well above it
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { char, folder }
local down = Workspace:Raycast(spot + Vector3.new(0, 150, 0), Vector3.new(0, -400, 0), params)
local y = if down then down.Position.Y + pick.Size.Y / 2 else root.Position.Y
-- BROADSIDE to the shooter, so the chest zone faces him
pick.CFrame = CFrame.lookAt(Vector3.new(spot.X, y, spot.Z), Vector3.new(spot.X, y, spot.Z) + flat:Cross(Vector3.yAxis))
pick.AssemblyLinearVelocity = Vector3.zero
pick.Anchored = true
local eye = (head :: BasePart).Position
local chest = pick:FindFirstChild("ZoneChest")
local aimAt = if chest then (chest :: BasePart).Position else pick.Position
local blockedBy = Workspace:Raycast(eye, aimAt - eye, params)
return string.format("STAGED %s(%s) at %.0f studs, chest %s, ground=%s", pick.Name, tostring(pick:GetAttribute("Kind")),
  (pick.Position - eye).Magnitude, blockedBy and ("BLOCKED by " .. blockedBy.Instance.Name) or "CLEAR", tostring(down ~= nil))

-- TASK 266b: put ONE boar in a CLEAR lane in front of the shooter, broadside, on the ground.
-- It SEARCHES: several distances and several lateral offsets, and it reports the one it took and how
-- many it refused -- because a staged animal behind a trunk produced three shots into the trunk in
-- task 266 and read as a gun fault.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local p = Players:GetPlayers()[1]
local char = p.Character
local root = char and char.PrimaryPart
local head = char and (char:FindFirstChild("Head") or root)
if root == nil then return "no char" end
local folder = Workspace:FindFirstChild("Boars")
if folder == nil then return "no Boars" end
local pick, bestD = nil, math.huge
for _, part in ipairs(folder:GetChildren()) do
  if part:IsA("BasePart") and part:GetAttribute("Damageable") == true and part:GetAttribute("Carcass") ~= true
     and tostring(part:GetAttribute("Species")) == "boar" then
    local d = (part.Position - root.Position).Magnitude
    if d < bestD then pick, bestD = part, d end
  end
end
if pick == nil then return "NO BOAR at all (only deer?)" end
local eye = (head :: BasePart).Position
local look = root.CFrame.LookVector
local flat = Vector3.new(look.X, 0, look.Z).Unit
local side = flat:Cross(Vector3.yAxis)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { char, folder }
local tried = 0
for _, dist in ipairs({ 90, 110, 70, 130, 60, 150 }) do
  for _, lateral in ipairs({ 0, 12, -12, 24, -24 }) do
    tried = tried + 1
    local spot = root.Position + flat * dist + side * lateral
    local down = Workspace:Raycast(spot + Vector3.new(0, 150, 0), Vector3.new(0, -400, 0), params)
    if down then
      local y = down.Position.Y + pick.Size.Y / 2
      local at = Vector3.new(spot.X, y, spot.Z)
      pick.CFrame = CFrame.lookAt(at, at + side)
      pick.AssemblyLinearVelocity = Vector3.zero
      pick.Anchored = true
      local chest = pick:FindFirstChild("ZoneChest")
      local aimAt = if chest then (chest :: BasePart).Position else pick.Position
      if Workspace:Raycast(eye, aimAt - eye, params) == nil then
        return string.format("STAGED %s(%s) at %.0f studs (dist=%d lateral=%d), chest CLEAR, tried %d",
          pick.Name, tostring(pick:GetAttribute("Kind")), (pick.Position - eye).Magnitude, dist, lateral, tried)
      end
    end
  end
end
pick.Anchored = false
return string.format("NO CLEAR LANE in %d placements -- the wood is thick here", tried)

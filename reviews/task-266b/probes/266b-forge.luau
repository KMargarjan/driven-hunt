-- TASK 266b item 2(3): a FORGED claim, sent by a probe, must be REJECTED BY NAME.
-- It names a real animal and a real zone part, with an honest flight time -- and a point 30 studs
-- from where the server's own history says that offset was. Everything else is true, so the only
-- thing the server can refuse it for is the lie.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local me = Players.LocalPlayer
local char = me.Character
local cam = Workspace.CurrentCamera.CFrame
local folder = Workspace:FindFirstChild("Boars")
if folder == nil then return "no Boars" end
local best, bestD = nil, math.huge
for _, part in ipairs(folder:GetChildren()) do
  if part:IsA("BasePart") and part:GetAttribute("Damageable") == true and part:GetAttribute("Carcass") ~= true
     and tostring(part:GetAttribute("Species")) == "boar" then
    local d = (part.Position - cam.Position).Magnitude
    if d < bestD then best, bestD = part, d end
  end
end
if best == nil then return "no boar" end
local zone = best:FindFirstChild("ZoneChest") or best
local Ballistics = require(RS:WaitForChild("Ballistics"))
local Weapons = require(RS:WaitForChild("Weapons"))
local tool = char and char:FindFirstChildOfClass("Tool")
local id = tool and Weapons.idForToolName(tool.Name)
local row = id and Weapons.ROWS[id]
if row == nil then return "no gun row (tool=" .. tostring(tool and tool.Name) .. ")" end
local shot = Ballistics.shotFor(row, "Slug")
if shot == nil then return "no ballistics" end
local offset = Vector3.new(0, 0, 0)
local honest = (zone :: BasePart).CFrame * offset
local claim = {
  part = zone,
  offset = offset,
  -- THE LIE, AND THE ONLY ONE: 30 studs sideways from where the animal actually is.
  point = honest + Vector3.new(30, 0, 0),
  firedAtView = Workspace:GetServerTimeNow(),
  flightSeconds = Ballistics.timeToRange(shot, bestD),
  distanceStuds = bestD,
}
RS:WaitForChild("Shotgun"):WaitForChild("Remotes"):WaitForChild("FireRequest")
  :FireServer({ origin = cam.Position, direction = cam.LookVector.Unit, claim = claim })
return string.format("FORGED claim sent: part=%s at %.0f studs, point 30 studs off, flight=%.4f",
  zone.Name, bestD, claim.flightSeconds)

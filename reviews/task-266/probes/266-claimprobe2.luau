local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local me = Players.LocalPlayer
local scripts = me:WaitForChild("PlayerScripts")
local Claim = require(scripts:WaitForChild("Weapon"):WaitForChild("Claim"))
local cam = Workspace.CurrentCamera.CFrame
local targets = Claim.visibleTargets(cam.Position, 800)
if #targets == 0 then return "no targets" end
local best, bestD = nil, math.huge
for _, t in ipairs(targets) do
  local d = ((t.root :: BasePart).Position - cam.Position).Magnitude
  if d < bestD then best, bestD = t, d end
end
local part = best.root :: BasePart
local chest = part:FindFirstChild("ZoneChest")
local aimAt = if chest then (chest :: BasePart).Position else part.Position
local look = CFrame.lookAt(cam.Position, aimAt)
local snap = { loaded = { "Slug", "Slug", "Slug" }, selected = 1 }
local c = Claim.forCamera(look, snap, Workspace:GetServerTimeNow())
local tool = me.Character and me.Character:FindFirstChildOfClass("Tool")
if c == nil then
  return string.format("NO CLAIM aiming at %s chest at %.0f studs (tool=%s)", part.Name, bestD, tostring(tool and tool.Name))
end
return string.format("CLAIM part=%s zone=%s offset=%.2f,%.2f,%.2f dist=%.1f flight=%.4f (target %s at %.0f)",
  c.part.Name, tostring(c.part:GetAttribute("HitZone")), c.offset.X, c.offset.Y, c.offset.Z, c.distanceStuds, c.flightSeconds, part.Name, bestD)

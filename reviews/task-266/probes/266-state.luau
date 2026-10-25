local Players = game:GetService("Players")
local p = Players:GetPlayers()[1]
local tool = p and p.Character and p.Character:FindFirstChildOfClass("Tool")
local bp = p and p.Backpack and p.Backpack:FindFirstChildOfClass("Tool")
local boars = workspace:FindFirstChild("Boars", true)
local n, rows = 0, {}
if boars then
  for _, c in ipairs(boars:GetChildren()) do
    if c:IsA("BasePart") and c:GetAttribute("Damageable") then
      n = n + 1
      if n <= 6 then
        table.insert(rows, string.format("%s kind=%s v=%.1f at %.0f,%.0f,%.0f", c.Name, tostring(c:GetAttribute("Kind")), c.AssemblyLinearVelocity.Magnitude, c.Position.X, c.Position.Y, c.Position.Z))
      end
    end
  end
end
return string.format("team=%s tool=%s backpack=%s animals=%d | %s", tostring(p and p.Team and p.Team.Name), tostring(tool and tool.Name), tostring(bp and bp.Name), n, table.concat(rows, " ; "))

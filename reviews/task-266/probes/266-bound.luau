local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local ok, info = pcall(function() return CAS:GetAllBoundActionInfo() end)
local names = {}
if ok and type(info) == "table" then
  for name, d in pairs(info) do
    local keys = {}
    if type(d) == "table" and type(d.inputTypes) == "table" then
      for _, it in ipairs(d.inputTypes) do table.insert(keys, tostring(it)) end
    end
    table.insert(names, name .. "{" .. table.concat(keys, ",") .. "}")
  end
end
table.sort(names)
local me = game:GetService("Players").LocalPlayer
local pg = me:FindFirstChild("PlayerGui")
local guis = {}
if pg then for _, c in ipairs(pg:GetChildren()) do table.insert(guis, c.Name .. "=" .. tostring(c:IsA("ScreenGui") and c.Enabled)) end end
return string.format("mouseBehavior=%s bound=%d | %s || GUIs: %s", tostring(UIS.MouseBehavior), #names, table.concat(names, " "), table.concat(guis, " "))

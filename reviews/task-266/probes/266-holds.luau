local Players = game:GetService("Players")
local me = Players.LocalPlayer
local scripts = me:FindFirstChild("PlayerScripts")
local mod = scripts and scripts:FindFirstChild("Weapon") and scripts.Weapon:FindFirstChild("Input")
if mod == nil then return "no Input module found" end
local ok, Input = pcall(require, mod)
if not ok then return "require failed: " .. tostring(Input) end
local tags = Input.holdTags and Input.holdTags() or {}
return string.format("held=%s tags=[%s] watchedTools=%s isAiming=%s (watchedTools>0 means this IS the live module instance)",
  tostring(Input.isHeld and Input.isHeld()), table.concat(tags, ","), tostring(Input.watchedTools and Input.watchedTools()), tostring(Input.isAiming and Input.isAiming()))

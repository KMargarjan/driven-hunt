-- Restore the Forest Test's ServerStorage attributes to EXACTLY what they were before task 266b.
-- `flags.py clear` removes EVERY override, not one -- the incident its own docstring records from
-- 2026-10-21 -- so the nine that were not mine are put back here, and the two that WERE mine
-- (DHFlag_HIT_CLAIM, DHTestOwns) are left off.
local SS = game:GetService("ServerStorage")
for _, name in ipairs({
  "DHFlag_BOAR_BEHAVIOUR", "DHFlag_BOAR_MODEL", "DHFlag_COINS", "DHFlag_DEER_ROAD_LEAP",
  "DHFlag_DRIVE_BOTS", "DHFlag_HORN", "DHFlag_LICENCE_POPUP", "DHFlag_LOBBY", "DHFlag_SHOP",
}) do
  SS:SetAttribute(name, true)
end
SS:SetAttribute("DHForestStartRole", "hunter")
SS:SetAttribute("DHShopTestGrant", true)
SS:SetAttribute("DHFlag_HIT_CLAIM", nil)
SS:SetAttribute("DHTestOwns", nil)
SS:SetAttribute("DHClaimStats", nil)
SS:SetAttribute("DHBoarHistory", nil)
local t = {}
for k, v in SS:GetAttributes() do table.insert(t, k .. "=" .. tostring(v)) end
table.sort(t)
return "placeId=" .. game.PlaceId .. " " .. table.concat(t, " ")

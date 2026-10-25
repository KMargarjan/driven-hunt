local SS = game:GetService("ServerStorage")
return string.format("boarHistory=%s | claim=%s", tostring(SS:GetAttribute("DHBoarHistory")), tostring(SS:GetAttribute("DHClaimStats")))

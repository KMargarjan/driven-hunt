-- MatchBoot: starts the client's match replica (ROADMAP.md 1.7a). Boot line only.
--
-- PlayerScripts.Match owns the replica and subscribes to the two server -> client remotes;
-- PlayerScripts.Hud owns everything drawn and READS the replica. Neither knows the other exists,
-- and the order these two boot scripts run in does not matter: the Hud subscribes to signals that
-- exist on require, so a snapshot that arrives before or after Hud.start() is drawn either way.
--
-- Design: docs/design/drive.md (section 9.3)
local Players = game:GetService("Players")

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Match = require(scripts:WaitForChild("Match"))

Match.start()

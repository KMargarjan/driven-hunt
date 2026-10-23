-- AmbienceBoot: starts the client's ambience bed (task 250). Boot line only.
--
-- PlayerScripts.Ambience owns the beds and is the one writer of their `Volume`; it reads
-- `Players.LocalPlayer.Team` at one boundary and nothing else about the world. Nothing else in the
-- game knows it exists, and the order these boot scripts run in does not matter: the voices are made
-- at MODULE LOAD, so a `Team` that is already set when this line runs is read by `start`'s own
-- `refresh`, and one that arrives later comes through `GetPropertyChangedSignal`.
--
-- Verbatim the shape of src/client/MatchBoot.client.luau.
--
-- Design: docs/design/ambience.md (section 3)
local Players = game:GetService("Players")

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Ambience = require(scripts:WaitForChild("Ambience"))

Ambience.start()

-- ReportBoot: starts the client's report replica (task 124). Boot line only -- it owns nothing,
-- decides nothing and holds no state.
--
-- IT RUNS IN EVERY WORLD, and that is the point: the Forest Test has no `Match`, and the kill log has
-- to work there too. The replica has no `Match` dependency at all, so there is nothing to gate on.
--
-- Design: docs/design/drive-report.md (section 3, owner table)
local Players = game:GetService("Players")

local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Report = require(scripts:WaitForChild("Report"))

Report.start()

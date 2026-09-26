-- FlagsBoot: the ONE caller of Flags.publish, once per server lifetime. It owns nothing, decides
-- nothing and holds no state -- it is a boot line, the shape MatchBoot already has.
--
-- It runs before any player exists, so by the time a client asks for the mirror it is already
-- there: the client's Flags.WAIT_SECONDS budget is a safety net for a restart, not a normal cost.
--
-- Nothing else in the repo may call Flags.publish. That is rule 3 for the published mirror: one
-- writer, named here and in GAME_DESIGN.md.
--
-- Design: docs/design/feature-flags.md (sections 2, 5)
-- Note:   docs/research/2026-09-26-feature-flags.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))

-- Resolution happens inside all(): defaults, plus DHFlag_* attributes on ServerStorage when
-- RunService:IsStudio(). The boot line (and, under an override, the OVERRIDE ACTIVE warn) is printed
-- by the same call, so the server's console always says what this run was resolved with.
local resolved = Flags.all()
print(Flags.line())

Flags.publish(resolved, Flags.source())

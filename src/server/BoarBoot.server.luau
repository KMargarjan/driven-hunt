-- BoarBoot: spawns the production boar at server start (ROADMAP.md step 1.2).
-- Boot line only. All state, movement and lifetime belong to ServerScriptService.Boar (rule 3),
-- mirroring ArenaBoot.server.luau.
--
-- It asserts the arena still matches Boar.CONFIG.field before spawning. Boar itself never requires
-- TestArena: the arena rectangle is carried as data, so when the Milestone 2 map generator replaces
-- the arena this fails loudly here instead of routing the boar to an edge that no longer exists.
--
-- Design: docs/design/boar-ai.md (section 9)
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestArena = require(ServerScriptService:WaitForChild("TestArena"))

local field = Boar.CONFIG.field
local ground = TestArena.LAYOUT.ground
local span = field.bounds.maxX - field.bounds.minX

assert(
	ground.span == span and ground.top == field.groundY,
	string.format(
		"boar-ai: the arena changed (span %d, top %d) but Boar.CONFIG.field still says span %d, groundY %d."
			.. " Update CONFIG.field in src/server/Boar/init.luau (see docs/design/boar-ai.md section 9).",
		ground.span,
		ground.top,
		span,
		field.groundY
	)
)

local runtime = Boar.newRuntime(Boar.defaultWorld())
runtime:spawn()
runtime:run()

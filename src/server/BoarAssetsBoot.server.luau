-- BoarAssetsBoot: the boar's skinned model, loaded on the server and wired into the boar's own
-- owner. Boot line only: it owns nothing, decides nothing, holds no state, and creates no Instance.
--
-- WHY IT IS ITS OWN SCRIPT AND NOT A LINE IN `MatchBoot`. `MatchBoot` is the composition root of the
-- DRIVE -- the boar runtime, the weapon and the match -- and it is on `TWO_PLAYER_PATHS`
-- (tools/agents.py), so a line added to it would put a two-player run and a human click in the gate
-- of every boar task from now on. The boar needs neither (Karen, 2026-10-03: "we dont need 2 player
-- test now we just working on weapon and animal next"). This wiring also has nothing to do with the
-- drive: it answers one question -- what does a boar look like -- and `Boar` is the only thing that
-- asks it.
--
-- THE ORDER OF TWO SCRIPTS IN ServerScriptService IS UNDEFINED, and this one does not need an order.
-- `MatchBoot` creates the runtime and `Boar.setModelSource` is wired here, so either can run first:
-- a boar born before the asset lands is a grey box that puts its coat on as soon as it arrives
-- (`Runtime:_modelTemplate`, asked once a second), and a boar born after it is already wearing it.
-- That is the same "a late arrival is late, not lost" rule `Assets.Loader` itself follows -- and it
-- is why nothing here shares a Luau value with `MatchBoot`, which it could not do anyway.
--
-- WIRED BEFORE `preload`, FOR THE REASON `WeaponBoot` LEARNED IT (task 76): `preload` returns a frame
-- or more after the template is actually cached, so wiring afterwards leaves a window in which the
-- asset exists and nothing can ask for it. `Loader.template` never yields and answers nil until the
-- load lands, which is exactly the "wear the grey box" answer the boar already handles.
--
-- Design: docs/design/asset-pipeline.md (sections 5, 6), docs/design/boar-ai.md (section 6)
-- Note:   docs/research/2026-10-03-boar-skinned-model.md
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))

-- WITH THE FLAG OFF, NOTHING HAPPENS AT ALL: no network call, no wiring, no warning. The flag is read
-- at the boar's own boundary (`Boar.CONFIG.MODEL.ENABLED`) and this script only reads it back, so
-- there is still one source for it.
if not Boar.CONFIG.MODEL.ENABLED then
	print("[BoarAssetsBoot] BOAR_MODEL is off: the boar is the grey box, and nothing was loaded.")
	return
end

-- THE ONE MAPPING FROM A CLIP'S NAME TO ITS ASSET KEY, in the composition root because that is where
-- a mapping between two owners belongs: `Boar` knows the ten clips by the names its own config uses
-- and must not hold a copy of an asset key, and `Assets.KEYS` stays the one home of the strings.
local CLIP_KEYS = {
	idle = Assets.KEYS.boarIdle,
	walk = Assets.KEYS.boarWalk,
	trot = Assets.KEYS.boarTrot,
	run = Assets.KEYS.boarRun,
	turnLeft = Assets.KEYS.boarTurnLeft,
	turnRight = Assets.KEYS.boarTurnRight,
	deathLeft = Assets.KEYS.boarDeathLeft,
	deathRight = Assets.KEYS.boarDeathRight,
	hitFront = Assets.KEYS.boarHitFront,
	hitBack = Assets.KEYS.boarHitBack,
}

-- A CLIP NAME WITH NO KEY IS A TYPO, AND IT FAILS HERE RATHER THAN BY NOT ANIMATING. Both tables are
-- frozen data edited in git, so a mismatch between them is a mistake somebody just made and not a
-- state the game can reach.
for name in pairs(Boar.CONFIG.MODEL.CLIPS) do
	assert(
		CLIP_KEYS[name] ~= nil,
		string.format(
			"BoarAssetsBoot: Boar.CONFIG.MODEL.CLIPS has a clip %q that CLIP_KEYS does not name."
				.. " Add it to both, or to neither (src/server/BoarAssetsBoot.server.luau).",
			name
		)
	)
end
for name, key in pairs(CLIP_KEYS) do
	assert(
		Boar.CONFIG.MODEL.CLIPS[name] ~= nil and type(key) == "string",
		string.format("BoarAssetsBoot: CLIP_KEYS names a clip %q that Boar.CONFIG.MODEL.CLIPS has not.", name)
	)
end

Boar.setModelSource(function(): Instance?
	-- NEVER YIELDS, which is the condition for calling it from inside the boar's step loop
	-- (docs/design/asset-pipeline.md 5.2). nil means "stay a grey box", not "fail".
	local template = Loader.template(Assets.KEYS.boarMale)
	return template
end, function(name: string): number?
	local row = Assets.byKey(CLIP_KEYS[name])
	if row == nil or row.kind ~= "animation" then
		return nil
	end
	return row.modelId
end)

-- `preload` YIELDS and hits the network, which is why it is here, once, at server start, and never
-- on the path that builds a boar. It is bounded by `Loader.CONFIG.PRELOAD_BUDGET_S`, so this line
-- cannot hang the boot either.
--
-- `keysFor("boar")` AND NOT A LITERAL: the manifest's own answer to "what does a boar need", never a
-- superseded row, and -- since task 115 -- never a row of a kind the loader cannot insert, so the ten
-- animation rows are not asked of `InsertService` (`Assets.INSERTABLE`).
local reports = Loader.preload(Assets.keysFor("boar"))
for _, loaded in ipairs(reports) do
	if loaded.ok then
		print(
			string.format(
				"[BoarAssetsBoot] %s loaded: model %d, %d mesh part(s), %s, %d ms",
				loaded.key,
				loaded.modelId or 0,
				loaded.meshParts or 0,
				tostring(loaded.naturalSizeStuds),
				loaded.elapsedMs
			)
		)
	else
		warn(
			string.format(
				"[BoarAssetsBoot] %s not loaded (%s); boars stay grey boxes this session",
				loaded.key,
				loaded.reason or "unknown"
			)
		)
	end
end

-- HOW MANY CLIPS THIS SERVER ACTUALLY HAS, said once at boot. Until the ten animations have been
-- published out of Studio's Animation Editor (the only way to make an animation asset id -- see
-- `Assets.KEYS`, the boar block, and `ESCALATE.md`) this prints 0 of 10, and that is the honest
-- state: the boar is welded, textured and standing still. A silent 0 is how a missing asset becomes
-- a bug report about animation code.
local have, want = 0, 0
for name in pairs(Boar.CONFIG.MODEL.CLIPS) do
	want += 1
	local row = Assets.byKey(CLIP_KEYS[name])
	if row and row.kind == "animation" and row.modelId > 0 then
		have += 1
	end
end
if have < want then
	warn(
		string.format(
			"[BoarAssetsBoot] %d of %d boar clips have an animation asset id. The rest are NOT"
				.. " published yet (Studio -> Animation Editor -> Publish to Roblox; see ESCALATE.md)."
				.. " The boar is drawn and welded; it does not move its legs.",
			have,
			want
		)
	)
else
	print(string.format("[BoarAssetsBoot] all %d boar clips have an animation asset id.", want))
end

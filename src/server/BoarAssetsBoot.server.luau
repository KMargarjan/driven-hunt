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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Map = require(ReplicatedStorage:WaitForChild("Map"))

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))

-- WITH THE FLAG OFF, NOTHING HAPPENS AT ALL: no network call, no wiring, no warning. The flag is read
-- at the boar's own boundary (`Boar.CONFIG.MODEL.ENABLED`) and this script only reads it back, so
-- there is still one source for it.
--
-- ...OR THE WORLD ASKS FOR IT ANYWAY (task 122). The playtest world turns the model on through the
-- boar runtime's own `config`, which is the right seam for what a boar LOOKS like -- but that is
-- the runtime's clone, and this script reads the MODULE's flag, so the animals were drawn from
-- assets nobody had loaded. Measured in the Forest Test place: "BOAR_MODEL is off: the boar is the
-- grey box, and nothing was loaded."
--
-- The world says so at this boundary, which is where a composition decision belongs, and it is
-- still ONE question with one answer rather than a second flag.
local wanted = Boar.CONFIG.MODEL.ENABLED or Map.PLAYTEST_WORLD
if not wanted then
	print("[BoarAssetsBoot] BOAR_MODEL is off: the boar is the grey box, and nothing was loaded.")
	return
end
if not Boar.CONFIG.MODEL.ENABLED then
	print("[BoarAssetsBoot] BOAR_MODEL is off but the world is " .. Map.EXPECTED_WORLD .. ": loading anyway.")
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
	-- The three this project authored, published 2026-10-03, so the boot's own "n of m clips" line
	-- below says 13 of 13. Before a publish `Assets.byKey` answers nil for them and that line says
	-- so out loud, which is the same honest state the ten above were in on the day they were
	-- declared.
	deathPaddleLeft = Assets.KEYS.boarDeathPaddleLeft,
	deathPaddleRight = Assets.KEYS.boarDeathPaddleRight,
	crippleDrag = Assets.KEYS.boarCrippleDrag,
	-- The calm repertoire (task 117), published 2026-10-03, so the boot's own "n of m clips" line
	-- below says 19 of 19.
	smell = Assets.KEYS.boarSmell,
	grazeLoop = Assets.KEYS.boarGrazeLoop,
	grazeChew = Assets.KEYS.boarGrazeChew,
	grazeStart = Assets.KEYS.boarGrazeStart,
	grazeEnd = Assets.KEYS.boarGrazeEnd,
	digWalk = Assets.KEYS.boarDigWalk,
}

-- ...AND THE DEER'S ELEVEN (task 223). A SECOND TABLE AND NOT A MERGED ONE, because `idle`, `walk`,
-- `trot`, `run`, `turnLeft`, `turnRight`, `deathLeft`, `deathRight`, `hitFront`, `hitBack` and
-- `smell` are clip names in BOTH species: one flat table would have one of them win, and the loser's
-- animals would play the other animal's published ids on their own rig. `CLIPS_BY_SPECIES` below is
-- what the lookup is keyed by.
local DEER_CLIP_KEYS = {
	idle = Assets.KEYS.deerIdle,
	walk = Assets.KEYS.deerWalk,
	trot = Assets.KEYS.deerTrot,
	run = Assets.KEYS.deerRun,
	turnLeft = Assets.KEYS.deerTurnLeft,
	turnRight = Assets.KEYS.deerTurnRight,
	deathLeft = Assets.KEYS.deerDeathLeft,
	deathRight = Assets.KEYS.deerDeathRight,
	hitFront = Assets.KEYS.deerHitFront,
	hitBack = Assets.KEYS.deerHitBack,
	smell = Assets.KEYS.deerSmell,
}

-- WHICH CLIP TABLE A SPECIES READS, and which `MODEL` its clip NAMES come out of. `"boar"` is the
-- key `Boar.Body.create` falls back to for every kind with no `species` field, so the four boar
-- rows reach exactly the table they always reached.
local CLIPS_BY_SPECIES = {
	boar = { keys = CLIP_KEYS, model = Boar.CONFIG.MODEL },
	reddeer = { keys = DEER_CLIP_KEYS, model = Boar.CONFIG.SPECIES.reddeer.MODEL },
}

-- A CLIP NAME WITH NO KEY IS A TYPO, AND IT FAILS HERE RATHER THAN BY NOT ANIMATING. Both tables are
-- frozen data edited in git, so a mismatch between them is a mistake somebody just made and not a
-- state the game can reach.
--
-- BOTH LOOPS RUN PER SPECIES (task 223), so the deer's eleven are held to exactly the same standard
-- as the boar's nineteen. This script's own history is why that matters: task 219 added a field to
-- `KINDS` and the loop below it asserted on it, so **this script died at its own assert,
-- `setModelSource` was never called, and not one boar in the game was ever dressed** -- which no
-- spec saw, because no spec runs a boot script. `tests/server/assets_seam.spec.luau` asserts the
-- same data where a spec CAN see it.
for species, entry in pairs(CLIPS_BY_SPECIES) do
	for name in pairs(entry.model.CLIPS) do
		assert(
			entry.keys[name] ~= nil,
			string.format(
				"BoarAssetsBoot: the %s MODEL.CLIPS has a clip %q that its key table does not name."
					.. " Add it to both, or to neither (src/server/BoarAssetsBoot.server.luau).",
				species,
				name
			)
		)
	end
	for name, key in pairs(entry.keys) do
		assert(
			entry.model.CLIPS[name] ~= nil and type(key) == "string",
			string.format(
				"BoarAssetsBoot: the %s key table names a clip %q that its MODEL.CLIPS has not.",
				species,
				name
			)
		)
	end
end

-- ...AND THE ONE MAPPING FROM A MODEL NAME TO ITS ASSET KEY (task 119), here for the same reason:
-- `Boar` knows its animals by the names its own config uses and must not hold a copy of an asset
-- key. An unknown name answers the male, which is the state every boar was in before task 119.
--
-- IT IS KEYED BY A KIND'S `model` FIELD AND NOT BY THE KIND (task 219), and that is ONE answer
-- rather than two: `KINDS.legendary.model` is already `"male"` -- the trophy is the male's own
-- bought asset, scaled -- so a `legendary` row here would be a second place saying the same thing,
-- and the two could disagree. There are three MODELS and four kinds, and this table is the models.
local MODEL_KEYS = {
	male = Assets.KEYS.boarMale,
	female = Assets.KEYS.boarFemale,
	cub = Assets.KEYS.boarCub,
	-- THE DEER (task 223). Three kinds, three models, and no row is shared the way the legendary
	-- shares the male's: a stag, a hind and a calf are three different uploads off one bought
	-- package.
	stag = Assets.KEYS.deerStag,
	hind = Assets.KEYS.deerHind,
	calf = Assets.KEYS.deerCalf,
}

-- A KIND WHOSE MODEL HAS NO ASSET KEY IS A TYPO, AND IT FAILS HERE rather than by standing in the
-- field as a grey box nobody can explain. Both tables are frozen data edited in git, so a mismatch
-- is a mistake somebody just made and not a state the game can reach.
--
-- IT WALKS `ORDER` AND NOT `pairs(KINDS)` (task 219), and the gate did not catch why: `KINDS` is a
-- table of ROWS **and** of settings, so the old loop skipped three names by hand (`ENABLED`,
-- `DEFAULT`, `ORDER`) and asserted on everything else -- which meant the next field anyone added to
-- that table would fail the boot. Task 219 added two (`legendary` and the `LEGENDARY` rarity block)
-- and it did exactly that: **this script died at its own assert, so `setModelSource` was never
-- called and NOT ONE BOAR IN THE GAME WAS EVER DRESSED.** No spec saw it, because no spec runs a
-- boot script; it was found by looking at a live server. `ORDER` is the list of animals by
-- definition, so there is nothing to skip and nothing to forget.
for _, kind in ipairs(Boar.CONFIG.KINDS.ORDER) do
	local row = Boar.CONFIG.KINDS[kind]
	local model = (type(row) == "table" and row.model) or kind
	assert(
		MODEL_KEYS[model] ~= nil,
		string.format(
			"BoarAssetsBoot: Boar.CONFIG.KINDS[%q] wears the model %q, which MODEL_KEYS does not name."
				.. " Add it to both, or to neither (src/server/BoarAssetsBoot.server.luau).",
			kind,
			model
		)
	)
end

Boar.setModelSource(function(kind: string): Instance?
	-- NEVER YIELDS, which is the condition for calling it from inside the boar's step loop
	-- (docs/design/asset-pipeline.md 5.2). nil means "stay a grey box", not "fail".
	local template = Loader.template(MODEL_KEYS[kind] or Assets.KEYS.boarMale)
	return template
end, function(species: string, name: string): number?
	-- THE SPECIES COMES FIRST (task 223, design section 6.4) and it is a GUARD, not an ordering
	-- preference: a stale one-argument caller then hands the species where the name was expected,
	-- `entry.keys[species]` is nil, and the answer is nil -- "no clip", which is "the animal stands
	-- still", which is the safe and tested state. With the species second, that same stale caller
	-- would get the BOAR's id for a deer clip and a deer would walk with a boar's legs.
	local entry = CLIPS_BY_SPECIES[species]
	local row = if entry ~= nil then Assets.byKey(entry.keys[name]) else nil
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
-- A SECOND CALL FOR THE DEER (task 223), and the separate scope is the point: `preload` is bounded
-- by `Loader.CONFIG.PRELOAD_BUDGET_S`, so one call for six skinned meshes would let a slow deer cost
-- a boar its coat. Two calls, two budgets. A deer born before its template lands is a grey box that
-- puts its coat on within a second (`_modelTemplate`'s `ASK_EVERY_SECONDS`) -- late is not lost.
for _, loaded in ipairs(Loader.preload(Assets.keysFor("deer"))) do
	table.insert(reports, loaded)
end
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
for name, clip in pairs(Boar.CONFIG.MODEL.CLIPS) do
	want += 1
	local row = Assets.byKey(CLIP_KEYS[name])
	if row and row.kind == "animation" and row.modelId > 0 then
		have += 1
		-- THE TWO COPIES OF ONE MEASUREMENT, COMPARED IN THE ONE PLACE THAT SEES BOTH. The clip's
		-- length is a fact about the published asset (`row.clipSeconds`, read back out of Roblox)
		-- and also a number the boar plays by (`clip.seconds`, which sets how long a flinch lasts).
		-- Neither owner may require the other, so nothing but this composition root can notice them
		-- drifting apart -- and they already did once, by exactly one frame on all ten clips, when
		-- the lengths were frame counts rather than measurements. Half a frame at 24 fps is the
		-- tolerance: anything smaller is rounding, anything larger is a different clip.
		local published = row.clipSeconds
		if published ~= nil and math.abs(published - clip.seconds) > 1 / 48 then
			warn(
				string.format(
					"[BoarAssetsBoot] %s: the manifest says the clip is %.3f s and Boar plays it as"
						.. " %.3f s. One of the two was not measured off the published asset.",
					name,
					published,
					clip.seconds
				)
			)
		end
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

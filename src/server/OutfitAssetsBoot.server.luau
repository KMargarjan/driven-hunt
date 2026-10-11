-- OutfitAssetsBoot: the two WORN catalog accessories, loaded on the server and wired into the one
-- module that writes what a character wears. Boot line only: it owns nothing, decides nothing,
-- holds no state, and creates no Instance of its own.
--
-- WHY IT IS ITS OWN SCRIPT AND NOT A LINE IN `MatchBoot`, which is the same argument
-- `BoarAssetsBoot` makes: `MatchBoot` is on `TWO_PLAYER_PATHS` (tools/agents.py), so a line added
-- there would put a two-player run and a human click into the gate of every outfit task from now
-- on. What a beater WEARS needs no second player. (`Match.Body` itself is on that list, so task 151
-- pays the click once; this script is what stops the next one paying it.)
--
-- THE ORDER OF TWO SCRIPTS IN ServerScriptService IS UNDEFINED, and this one does not need an
-- order. `Body.setAccessorySource` is wired BEFORE `preload` returns -- the rule `WeaponBoot`
-- learned in task 76, because `preload` returns a frame or more after the template is really
-- cached, so wiring afterwards leaves a window in which the asset exists and nothing can ask for
-- it. Until the load lands `Loader.template` answers nil and `Match.Body` builds its plates, which
-- is the same "a late arrival is late, not lost" rule every other asset in this repo follows.
-- A player dressed in that window wears the grey box until their next dress.
--
-- THE MAPPING FROM A SLOT TO AN ASSET KEY LIVES HERE, and nowhere else. `Match.Body` knows the
-- slots it dresses ("hat", "vest") and must never learn what `ServerStorage.Assets` calls them;
-- `Assets.KEYS` stays the one home of the key strings. A composition root is exactly where a
-- mapping between two owners belongs -- `BoarAssetsBoot.CLIP_KEYS` is the same shape.
--
-- Design: docs/design/beater-kit.md (sections 2, 3), docs/design/asset-pipeline.md (sections 5, 6)
-- Note:   docs/research/2026-10-11-beater-kit.md section 4.2
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Match = require(ServerScriptService:WaitForChild("Match"))
local Assets = require(ServerStorage:WaitForChild("Assets"))
local Loader = require(ServerStorage.Assets:WaitForChild("Loader"))

local Body = Match.Body

local SLOT_KEYS = {
	[Body.SLOTS.hat] = Assets.KEYS.outfitCap,
	[Body.SLOTS.vest] = Assets.KEYS.outfitVest,
}

-- A SLOT WITH NO KEY IS A TYPO, and it fails here rather than by a player quietly wearing plates
-- for ever. Both tables are frozen data edited in git, so a mismatch is a mistake somebody just
-- made and not a state the game can reach.
for name, slot in pairs(Body.SLOTS) do
	assert(
		SLOT_KEYS[slot] ~= nil,
		string.format("OutfitAssetsBoot: Body.SLOTS.%s is %q and SLOT_KEYS does not name it.", name, slot)
	)
end

-- WIRED FIRST, THEN LOADED. `Loader.template` never yields and answers nil until the load lands,
-- which is the answer `Match.Body` already handles by building its plates.
Body.setAccessorySource(function(slot: string): Instance?
	local key = SLOT_KEYS[slot]
	if key == nil then
		return nil
	end
	local template = Loader.template(key)
	return template
end)

-- WITH THE OUTFITS OFF, NOTHING IS FETCHED AT ALL: no network call and no warning. The flag is read
-- once at its owner's boundary (`Match.CONFIG.OUTFITS_ENABLED`) and this script only reads that
-- back, so there is still one source for it.
if not Match.CONFIG.OUTFITS_ENABLED then
	print("[OutfitAssetsBoot] ORANGE_OUTFITS is off: nobody is dressed, and nothing was loaded.")
	return
end

local keys = Assets.keysFor("outfit")
local reports = Loader.preload(keys)
local ok = 0
local lines = {}
for _, report in ipairs(reports) do
	if report.ok then
		ok += 1
	end
	-- THE ELAPSED MILLISECONDS ARE PART OF THE EVIDENCE, not decoration: `Loader` gives this call
	-- 15 seconds for all keys and 10 for any one of them, and a boot that shares the network with
	-- the gun, the rifle and the boar can run out of either. A run that falls back to plates and a
	-- run that loads in 400 ms look identical without this number.
	table.insert(
		lines,
		string.format(
			"%s=%s(%dms)",
			report.key,
			if report.ok then "ok" else "FAILED:" .. tostring(report.reason),
			math.floor(report.elapsedMs or -1)
		)
	)
end

-- ONE LINE, AND IT IS THE EVIDENCE. A failed load is not an error -- the plates are worn instead and
-- the game is playable -- but it is the difference between a beater in a real hi-vis vest and a
-- beater in four orange boxes, and nobody can tell those apart from a screenshot of the console
-- unless this says which happened.
print(
	string.format(
		"[OutfitAssetsBoot] %d of %d catalog accessory(ies) loaded: %s%s",
		ok,
		#keys,
		table.concat(lines, " "),
		if ok < #keys then " -- the rest wear the grey-box plates" else ""
	)
)

-- AND RE-DRESS WHOEVER WAS ALREADY DRESSED, which is the line that makes the whole thing visible.
--
-- MEASURED, 2026-10-11, and without this the feature did not reach the screen at all: the boot wires
-- the source in its first millisecond and `preload` hits the network, while `CharacterAdded` fires
-- a second or two into the session -- so the FIRST dress always wins the race and
-- `Loader.template` still answers nil at that moment. The console said
-- "2 of 2 catalog accessory(ies) loaded" and the player stood there in grey-box plates.
-- "A late arrival is late, not lost" is only true if something asks again.
--
-- It is one loop in the composition root and no new owner: `Match.Body` still does every write, and
-- `dressWhenLoaded` is idempotent by construction -- it destroys the folder and this module's own
-- tagged accessories before it builds anything, so a re-dress cannot leave a player in two hats.
-- A player with no team yet is a no-op here and is dressed when the drive gives them one.
--
-- IT IS A BOUNDED POLL AND NOT A SINGLE SHOT, for the case `Loader` itself documents: `preload`
-- gives up WAITING at its deadline, but the abandoned load keeps running and `adopt` takes the
-- template if it ever lands -- "a slow load is late rather than lost". A one-shot re-dress here
-- would miss exactly that, and the symptom is a player in plates with the console claiming success.
-- The poll runs in its own thread, so the boot never blocks on it.
local REDRESS_WINDOW_S = 20
local REDRESS_INTERVAL_S = 1

local function everyTemplateIsHere(): boolean
	for _, key in ipairs(keys) do
		if Loader.template(key) == nil then
			return false
		end
	end
	return #keys > 0
end

local function redressEverybody(why: string)
	local redressed = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and player.Team then
			Body.dressWhenLoaded(player, character, Match.CONFIG)
			redressed += 1
		end
	end
	print(
		string.format(
			"[OutfitAssetsBoot] re-dressed %d player(s) already on a team (%s); %d accessory(ies) worn, %d slot(s) on plates",
			redressed,
			why,
			Body.accessoriesWorn(),
			Body.slotsFellBack()
		)
	)
end

if ok > 0 then
	redressEverybody("the preload returned")
end

task.spawn(function()
	local deadline = os.clock() + REDRESS_WINDOW_S
	while os.clock() < deadline do
		if everyTemplateIsHere() then
			if ok < #keys then
				-- A load that `preload` had given up on has landed since. Nothing else would ever
				-- ask again, so this is the only thing standing between a late template and a
				-- player who wears plates for the rest of the session.
				redressEverybody("a late template landed")
			end
			return
		end
		task.wait(REDRESS_INTERVAL_S)
	end
	if not everyTemplateIsHere() then
		print(
			string.format(
				"[OutfitAssetsBoot] after %ds some accessory never arrived: those slots wear the grey-box plates.",
				REDRESS_WINDOW_S
			)
		)
	end
end)

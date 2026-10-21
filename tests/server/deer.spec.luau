-- deer.spec: THE RED DEER (task 223) -- stag, hind and calf in the drive, behind a licence.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- Karen, 2026-10-20: *"I will buy red tag deer"*, and then the rule, verbatim: *"deer also will be
-- possible to shoot if you have purchased deer license"*.
--
-- **EVERY CASE HERE ENTERS AN ARM THAT DID NOT EXIST BEFORE THIS TASK**, which is the thing the
-- Learning Agent's L-093 asks for and the thing a licence spec is easiest to get wrong at: a
-- `has licence` assertion is trivially satisfiable with the branch never inverted, so each of the
-- two licence cases below is written as a PAIR -- the same real animal, the same real gate, one
-- player holding the card and one not -- and the calf's penalty is a case of its own rather than a
-- corollary of the stag's.
--
-- MOSTLY PURE, for `boar_legendary.spec`'s stated reason: `BOAR_MODEL` sits at its DEFAULT in every
-- harness run (`test` refuses to start with an override set) -- `true` since task 230 -- so the only
-- way both states are reachable is to drive the config by parameter. The two cases that are not pure are the two that
-- cannot be: a REAL trunk built by `Body.create` reaching the REAL fire gate, and the per-drive cap,
-- which is runtime state across two releases.
--
-- Design: docs/design/red-deer.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Assets = require(game:GetService("ServerStorage"):WaitForChild("Assets"))
local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Licences = require(ReplicatedStorage:WaitForChild("Licences"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local Rules = Weapon.Rules
local Score = Match.Score
local CONFIG = Boar.CONFIG

local EPSILON = 1e-4
local DEER_KINDS = { "stag", "hind", "calf" }
local BOAR_KINDS = { "male", "female", "cub", "legendary" }
local ALL_KINDS = { "male", "female", "cub", "legendary", "stag", "hind", "calf" }
local FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
}

-- THE CLIP NAME -> ASSET KEY MAPS, ONE PER SPECIES, written out as LITERAL key strings for the
-- reason `boar_model.spec`'s own `KEY_OF` is: reading them out of `Assets.KEYS` would assert that
-- the manifest agrees with itself. The ELEVEN names are the deer's own; the boar's table is here
-- only so the case below can prove the two species' ids are different numbers.
local DEER_CLIP_KEY = {
	idle = "deer.anim.idle",
	walk = "deer.anim.walk",
	trot = "deer.anim.trot",
	run = "deer.anim.run",
	turnLeft = "deer.anim.turn.left",
	turnRight = "deer.anim.turn.right",
	deathLeft = "deer.anim.death.left",
	deathRight = "deer.anim.death.right",
	hitFront = "deer.anim.hit.front",
	hitBack = "deer.anim.hit.back",
	smell = "deer.anim.calm.smell",
}
local BOAR_CLIP_KEY = {
	idle = "boar.anim.idle",
	walk = "boar.anim.walk",
	trot = "boar.anim.trot",
	run = "boar.anim.run",
	turnLeft = "boar.anim.turn.left",
	turnRight = "boar.anim.turn.right",
	deathLeft = "boar.anim.death.left",
	deathRight = "boar.anim.death.right",
	hitFront = "boar.anim.hit.front",
	hitBack = "boar.anim.hit.back",
	smell = "boar.anim.calm.smell",
}

-- THE FLAG AS A PARAMETER, the one permitted shape (`boar_kinds.spec`'s own helper). A deep-enough
-- clone that `KINDS.ENABLED` can be true without the module's own frozen table being touched.
local function configWith(on: boolean)
	local config = table.clone(Boar.CONFIG)
	config.KINDS = table.clone(Boar.CONFIG.KINDS)
	config.KINDS.ENABLED = on
	config.MODEL = table.clone(Boar.CONFIG.MODEL)
	config.MODEL.ENABLED = on
	return config
end

return function()
	describe("the red deer", function()
		-- 1 + 2. THE LICENCE RULE, AS A PAIR, ON A REAL ANIMAL -----------------------------------
		--
		-- Not the hand-made stub `weapon_rules.spec` drives (that one proves the GATE with no world
		-- and must stay green); this one builds a REAL trunk with `Body.create`, reads it back the
		-- way the weapon does -- through `Match.classifyTarget`, which walks the instance for the
		-- species attribute -- and puts the answer through the real `Rules.refuse`.
		describe("the fire gate, reached from a trunk the boar owner built", function()
			local holder, runtime
			local trunks: { [string]: Instance } = {}

			beforeAll(function()
				holder = Instance.new("Folder")
				holder.Name = "DeerSpecAnimals"
				holder.Parent = Workspace
				-- THE PUBLIC DOOR AND NOT `Body.create`: `Body` is private on purpose ("the only
				-- writer of a boar's Instances" is a claim an export would weaken), so the animal
				-- is made the way the drive makes one. `KINDS.ENABLED` is merged key by key by
				-- `newRuntime`, which is why it arrives like this.
				runtime = Boar.newRuntime({
					field = FIELD,
					parent = holder,
					folderName = "DeerGate",
					rng = Random.new(223),
					config = { KINDS = { ENABLED = true }, maxBoars = 12 },
					threats = function()
						return {}
					end,
					probe = function()
						return false
					end,
					requestPath = function(_id, _from, _to, done)
						done(nil)
					end,
					releasePath = function() end,
				})
				for index, kind in ipairs(ALL_KINDS) do
					local handle = runtime:spawn(Vector3.new(index * 12, 10, 0), kind)
					trunks[kind] = handle.part
				end
			end)

			afterAll(function()
				runtime:destroy()
				holder:Destroy()
			end)

			it("publishes reddeer on every deer kind and boar on every boar kind", function()
				-- BOTH ARMS of `Body.create`'s `row.species or Licences.ROWS.boar.species`. The
				-- second half is what proves the four boar rows did not change meaning when the
				-- field was added to three new ones.
				for _, kind in ipairs(DEER_KINDS) do
					expect(trunks[kind]:GetAttribute(Licences.SPECIES_ATTRIBUTE)).to.equal("reddeer")
				end
				for _, kind in ipairs(BOAR_KINDS) do
					expect(trunks[kind]:GetAttribute(Licences.SPECIES_ATTRIBUTE)).to.equal("boar")
				end
			end)

			it("REFUSES a shot at any red deer from a player with no card", function()
				for _, kind in ipairs(DEER_KINDS) do
					local target = Match.classifyTarget(trunks[kind])
					expect(target).to.be.ok()
					expect(target.species).to.equal("reddeer")
					-- The arm: `Rules.unlicensed` TRUE, reached through the real sequencer.
					expect(Rules.unlicensed(target, nil)).to.equal(true)
					expect(Rules.refuse({ target = target, licences = nil })).to.equal(Rules.REASON.LICENCE)
					expect(Rules.noticeFor(Rules.REASON.LICENCE)).to.equal("NO LICENCE")
				end
			end)

			it("ALLOWS the same shot from a player holding the deer card", function()
				-- THE SAME ANIMAL AND THE SAME GATE, inverted only by what he holds -- which is the
				-- half that makes the case above mean something.
				local held = ShopData.licencesFor({ [ShopData.ITEM.RED_STAG] = true })
				expect(held).to.be.ok()
				expect(held.reddeer).to.equal(true)
				for _, kind in ipairs(DEER_KINDS) do
					local target = Match.classifyTarget(trunks[kind])
					expect(Rules.unlicensed(target, held)).to.equal(false)
					expect(Rules.refuse({ target = target, licences = held })).to.equal(nil)
				end
			end)

			it("never asks a card of a boar, with or without one", function()
				for _, kind in ipairs(BOAR_KINDS) do
					local target = Match.classifyTarget(trunks[kind])
					expect(Rules.unlicensed(target, nil)).to.equal(false)
					expect(Rules.refuse({ target = target, licences = nil })).to.equal(nil)
				end
			end)

			it("sizes a deer off the DEER's trunk and not off a scaled boar", function()
				-- The seam reaching the world: a stag's physics box is the species' own measured
				-- box times his `scale`, and it is longer and NARROWER than a boar's.
				local stag = trunks.stag.Size
				local male = trunks.male.Size
				expect(stag.Z > male.Z).to.equal(true)
				expect(stag.X < male.X).to.equal(true)
				expect(stag.Z).to.be.near(CONFIG.SPECIES.reddeer.BODY_SIZE.Z, 0.01)
			end)
		end)

		-- 3. THE CATALOGUE -----------------------------------------------------------------------
		describe("the deer licence in the shop", function()
			it("is on sale, named for the species and still held to its own invariant", function()
				local row = ShopData.ROWS[ShopData.ITEM.RED_STAG]
				expect(row).to.be.ok()
				expect(row.sale).to.equal(true)
				expect(row.grants.licence).to.equal("reddeer")
				-- THE RENAME: it covers three animals, so it may not be named for one of them.
				expect(row.label).to.equal("DEER LICENCE")
				expect(string.find(row.label, "STAG")).to.equal(nil)
				expect(Licences.ROWS.reddeer.shipped).to.equal(true)
				expect(#ShopData.rowsOk(Weapons.ROWS, Weapons.ROWS.shotgun.AMMO_KINDS, Licences.ROWS)).to.equal(0)
			end)

			it("would STILL be refused for a species no build ships", function()
				-- THE INVARIANT IS NOT WEAKENED BY BEING SATISFIED (L-093: the other arm). A
				-- hand-made licence table with `shipped = false` must still close the door.
				local rows = { reddeer = table.clone(Licences.ROWS.reddeer) }
				rows.reddeer.shipped = false
				local problems = ShopData.rowsOk(Weapons.ROWS, Weapons.ROWS.shotgun.AMMO_KINDS, rows)
				expect(#problems > 0).to.equal(true)
			end)
		end)

		-- 4 + 5. THE SPECIES SEAM ----------------------------------------------------------------
		describe("speciesConfig and kindConfig", function()
			it("is the IDENTITY for nil, for boar and for a species nobody ships", function()
				-- BY REFERENCE, which is the whole property that makes this seam safe: a boar, and
				-- the whole flag-off world, get the table they always got and nothing can drift.
				local config = configWith(true)
				expect(Boar.speciesConfig(nil, config)).to.equal(config)
				expect(Boar.speciesConfig("boar", config)).to.equal(config)
				expect(Boar.speciesConfig("wolf", config)).to.equal(config)
			end)

			it("hands a deer its own trunk, zones and clips", function()
				local config = configWith(true)
				local deer = Boar.speciesConfig("reddeer", config)
				expect(deer).never.to.equal(config)
				expect(deer.BODY_SIZE).to.equal(CONFIG.SPECIES.reddeer.BODY_SIZE)
				expect(deer.ZONES).to.equal(CONFIG.SPECIES.reddeer.ZONES)
				expect(deer.MODEL).to.equal(CONFIG.SPECIES.reddeer.MODEL)
				-- The deer is longer than the boar and NOT a multiple of its box.
				expect(deer.BODY_SIZE.Z > config.BODY_SIZE.Z).to.equal(true)
				expect(deer.BODY_SIZE.X < config.BODY_SIZE.X).to.equal(true)
			end)

			it("composes the species tables with the kind's wary scaling", function()
				local config = configWith(true)
				local stag = Boar.kindConfig("stag", config)
				expect(stag.BODY_SIZE).to.equal(CONFIG.SPECIES.reddeer.BODY_SIZE)
				expect(stag.DETECT_RADIUS).to.be.near(config.DETECT_RADIUS * 1.5, EPSILON)
				expect(stag.SPRINT_SPEED).to.be.near(config.SPRINT_SPEED * 1.18, EPSILON)
				local hind = Boar.kindConfig("hind", config)
				expect(hind.DETECT_RADIUS).to.be.near(config.DETECT_RADIUS * 1.8, EPSILON)
				-- ONE SPECIES, ONE RUN SPEED: a hind who outran her own calf would dissolve the
				-- group at `SOUNDER.BREAK_STUDS`, which is a correctness constraint and not taste.
				expect(Boar.kindConfig("calf", config).SPRINT_SPEED).to.be.near(hind.SPRINT_SPEED, EPSILON)
				-- ...and a boar with no `wary` row is still the config itself, by reference.
				expect(Boar.kindConfig("male", config)).to.equal(config)
			end)
		end)

		-- 6. THE CLIP TABLES ARE NOT SHARED ------------------------------------------------------
		it("gives the deer its own animation id table", function()
			-- THE BUG THIS SEAM EXISTS TO PREVENT, asserted where a spec can see it: sharing one
			-- table would play the BOAR's published ids on `Arm_Deer`, and nothing in the suite
			-- could tell, because an `AnimationId` is a number and it would be set correctly.
			local deerModel = CONFIG.SPECIES.reddeer.MODEL
			expect(deerModel.ANIMATION_IDS).never.to.equal(CONFIG.MODEL.ANIMATION_IDS)
			expect(deerModel.CLIPS).never.to.equal(CONFIG.MODEL.CLIPS)
			-- The deer asks for its OWN package's clip names, not the boar's.
			expect(deerModel.CLIPS.hitFront.clip).to.equal("Hit_Front")
			expect(CONFIG.MODEL.CLIPS.hitFront.clip).to.equal("Hit_F")
			-- Eleven, and none of the boar's grazing four.
			local count = 0
			for _ in pairs(deerModel.CLIPS) do
				count += 1
			end
			expect(count).to.equal(11)
			expect(deerModel.CLIPS.grazeLoop).to.equal(nil)
			expect(deerModel.CLIPS.crippleDrag).to.equal(nil)
			-- ALL THREE MODELS HAVE ROWS, which is what makes a deer visible at all.
			for _, key in ipairs({ Assets.KEYS.deerStag, Assets.KEYS.deerHind, Assets.KEYS.deerCalf }) do
				local row = Assets.byKey(key)
				expect(row).to.be.ok()
				expect(row.kind).to.equal("model")
				expect(row.scope).to.equal("deer")
			end
		end)

		-- 6b. THE ELEVEN PUBLISHED CLIPS (task 232) ----------------------------------------------
		--
		-- IT IS THE MANIFEST THAT IS ASSERTED AND NOT THE LIVE `ANIMATION_IDS` TABLE, which is a
		-- real lesson from the first run of this spec: `_modelTemplate` FILLS that table from
		-- whatever source is wired, so another spec's fake id function had already written `20009`
		-- into it by the time this case ran. The manifest is the fact; the live table is session
		-- state.
		it("has a published animation row for every one of the deer's eleven clips", function()
			local model = CONFIG.SPECIES.reddeer.MODEL
			-- NAMED, NOT COUNTED: "3 missing" sends the next reader looking for which three.
			local missing, sharedWithBoar = {}, {}
			for name in pairs(model.CLIPS) do
				local key = DEER_CLIP_KEY[name]
				expect(key).to.be.ok()
				local row = Assets.byKey(key)
				if row == nil or row.kind ~= "animation" or row.modelId <= 0 then
					table.insert(missing, name)
				else
					-- ...AND IT IS NOT THE BOAR'S ID. The seam exists to stop a deer playing boar
					-- clips on `Arm_Deer`, and an `AnimationId` is a number, so nothing downstream
					-- could tell. This is where it is caught.
					local boarRow = Assets.byKey(BOAR_CLIP_KEY[name])
					if boarRow ~= nil and boarRow.modelId == row.modelId then
						table.insert(sharedWithBoar, name)
					end
				end
			end
			table.sort(missing)
			table.sort(sharedWithBoar)
			expect(table.concat(missing, ", ")).to.equal("")
			expect(table.concat(sharedWithBoar, ", ")).to.equal("")
		end)

		it("agrees with the manifest about how long each deer clip is", function()
			-- The two copies of one measurement: `clipSeconds` was read back off the published
			-- asset with `AnimationClipProvider:GetAnimationClipAsync`, `clip.seconds` is what the
			-- deer plays by. `BoarAssetsBoot` warns at boot; this fails the build, which is the
			-- half that stops it being merged. Half a frame at 24 fps is the tolerance.
			local model = CONFIG.SPECIES.reddeer.MODEL
			local worst, worstName = 0, "none"
			for name, clip in pairs(model.CLIPS) do
				local row = Assets.byKey(DEER_CLIP_KEY[name])
				expect(row.clipSeconds).to.be.ok()
				local drift = math.abs(row.clipSeconds - clip.seconds)
				if drift > worst then
					worst, worstName = drift, name
				end
			end
			TestKit.note(string.format("deer: worst clip-length drift %.4f s (%s)", worst, worstName))
			expect(worst <= 1 / 48).to.equal(true)
		end)

		it("never asks InsertService to load a deer animation", function()
			-- An animation is a number on an `Animation.AnimationId`, not an Instance you insert.
			-- A boot script handed one would spend a network load that can only fail, and delay the
			-- model that does need it -- which for the deer is its own `preload` budget.
			for _, key in ipairs(Assets.keysFor("deer")) do
				expect(Assets.byKey(key).kind).never.to.equal("animation")
			end
			expect(#Assets.keysFor("deer-animation")).to.equal(0)
		end)

		-- BOTH LOOPED STATES, ENTERED, AND NOT ONE CASE THAT HAPPENS TO BE IN FRONT OF THE WRITER
		-- (L-093). The deer's assets are the boar's case INVERTED -- only `Walk_F_IP` was published
		-- `Loop = true` -- so `looped` cannot be taken off the asset, and both arms are stated.
		it("loops the deer's gaits and plays its deaths and flinches ONCE", function()
			local clips = CONFIG.SPECIES.reddeer.MODEL.CLIPS
			local looping, once = {}, {}
			for name, clip in pairs(clips) do
				table.insert(if clip.looped then looping else once, name)
			end
			table.sort(looping)
			table.sort(once)
			-- Named on both sides, so a clip that moves from one arm to the other fails here.
			expect(table.concat(looping, ", ")).to.equal("idle, run, smell, trot, turnLeft, turnRight, walk")
			expect(table.concat(once, ", ")).to.equal("deathLeft, deathRight, hitBack, hitFront")
			-- A LOOPING DEATH WOULD STAND THE CARCASS BACK UP, in front of the player who just
			-- shot it; a one-shot GAIT would freeze a running deer mid-stride.
			expect(clips.deathLeft.looped).to.equal(false)
			expect(clips.deathRight.looped).to.equal(false)
			expect(clips.walk.looped).to.equal(true)
			expect(clips.run.looped).to.equal(true)
			-- `smell` LOOPS ON THE DEER AND NOT ON THE BOAR, deliberately: the calm activity runs
			-- it for exactly its own length, and a frame past the end drops a one-shot track --
			-- and the animal -- into the bind pose. The boar's row is untouched, which is the
			-- other half of this assertion.
			expect(clips.smell.looped).to.equal(true)
			expect(CONFIG.MODEL.CLIPS.smell.looped).to.equal(false)
		end)

		-- EACH KIND ENTERS ITS OWN BRANCH (L-093), because `deathLiftStuds` is per kind and a
		-- single case would prove one of three.
		it("carries a MEASURED death lift for each of the three deer kinds", function()
			local config = configWith(true)
			local measured = { stag = 0.011, hind = 0.185, calf = 1.325 }
			for kind, expected in pairs(measured) do
				-- Through `Boar.kindGeometry`, which is what the live carcass reads, so the number
				-- is asserted where it is USED and not only where it is written.
				local geometry = Boar.kindGeometry(kind, config)
				expect(geometry.kind).to.equal(kind)
				expect(geometry.deathLift).to.be.near(expected, EPSILON)
			end
			-- THE CALF'S IS THE BIG ONE and it is the whole point of the field: the three kinds
			-- play the STAG's published clips on geometry baked smaller, so the smaller the animal
			-- the further its fall overshoots. A calf with no lift is 1.32 studs under the floor.
			local stag = Boar.kindGeometry("stag", config).deathLift
			local hind = Boar.kindGeometry("hind", config).deathLift
			local calf = Boar.kindGeometry("calf", config).deathLift
			expect(calf > hind).to.equal(true)
			expect(hind > stag).to.equal(true)
			-- ...AND WITH `KINDS` OFF EVERY ANIMAL IS THE MALE-SIZED GREY BOX, lift 0, so the
			-- flag-OFF world is arithmetically untouched.
			expect(Boar.kindGeometry("calf", configWith(false)).deathLift).to.equal(0)
		end)

		-- 7 + 8. THE SPAWN MIX -------------------------------------------------------------------
		describe("the deer draw", function()
			it("draws nothing at roll 1 and always at roll 0", function()
				local config = configWith(true)
				expect(Boar.deerComposition(1.0, 0, config)).to.equal(nil)
				expect(Boar.deerComposition(0.9999, 0, config)).to.equal(nil)
				expect(Boar.deerComposition(0.0, 0, config)).to.be.ok()
				-- The dial itself: 0.2 is one release in five.
				expect(CONFIG.SPECIES.reddeer.RELEASE.CHANCE_PER_RELEASE).to.be.near(0.2, EPSILON)
				expect(Boar.deerComposition(0.1999, 0, config)).to.be.ok()
				expect(Boar.deerComposition(0.2, 0, config)).to.equal(nil)
			end)

			it("draws each of the three compositions at its own weight boundary", function()
				local config = configWith(true)
				local alone = Boar.deerComposition(0, 0.0, config)
				expect(alone.stag).to.equal(1)
				expect(Boar.compositionSize(alone, config)).to.equal(1)
				local nursery = Boar.deerComposition(0, 0.5, config)
				expect(nursery.hind).to.equal(1)
				expect(nursery.calf).to.equal(1)
				expect(Boar.compositionSize(nursery, config)).to.equal(2)
				local harem = Boar.deerComposition(0, 0.9, config)
				expect(harem.stag).to.equal(1)
				expect(harem.hind).to.equal(2)
				expect(Boar.compositionSize(harem, config)).to.equal(3)
				-- `weight` IS NOT AN ANIMAL and must never be counted as one.
				expect(harem.weight).to.equal(nil)
			end)

			it("turns a named composition into that composition's own kinds", function()
				local config = configWith(true)
				local kinds = Boar.sounderKinds(3, {}, config, { stag = 1, hind = 2 })
				expect(#kinds).to.equal(3)
				table.sort(kinds)
				expect(kinds[1]).to.equal("hind")
				expect(kinds[2]).to.equal("hind")
				expect(kinds[3]).to.equal("stag")
				-- The boar's own three words are untouched and still mean what they meant.
				local sounder = Boar.sounderKinds(3, {}, config, { females = 1, cubs = 2 })
				expect(sounder[1]).to.equal(config.SOUNDER.MAKEUP.SOW)
				expect(sounder[2]).to.equal(config.SOUNDER.MAKEUP.YOUNG)
			end)

			it("draws NOTHING, and no number, with BOAR_MODEL off", function()
				-- The gate is in FRONT of the roll, so the runtime's `Random` stream is bit-for-bit
				-- the one every existing spec was written against in the flag-off world.
				expect(Boar.deerComposition(0, 0, configWith(false))).to.equal(nil)
			end)

			-- ------------------------------------------------ THE DRIVE ASKS FOR ONE (task 234)
			it("GIVES A GROUP WHATEVER THE ROLL when the drive asks, and still picks WHICH", function()
				-- Karen, 2026-10-21: *"we need all a time in drive deer"*. `CHANCE_PER_RELEASE` is
				-- 0.2 and 0.8^6 = 26 % of drives carried none; the schedule now names one release.
				--
				-- THE ASK SKIPS THE CHANCE AND NOTHING ELSE: `pick` still chooses the group by the
				-- same weighted walk, so WHICH deer come is still this function's own decision and
				-- `Match.Phase` never learns the vocabulary.
				local config = configWith(true)
				expect(Boar.deerComposition(1.0, 0, config)).to.equal(nil) -- the roll that refuses
				local asked = Boar.deerComposition(1.0, 0, config, true)
				expect(asked).to.be.ok()
				expect(asked.stag).to.equal(1)
				expect(Boar.deerComposition(1.0, 0.5, config, true).hind).to.equal(1)
				expect(Boar.deerComposition(1.0, 0.9, config, true).hind).to.equal(2)
				-- ...AND IT CANNOT CONJURE AN ANIMAL THAT DOES NOT EXIST. With `BOAR_MODEL` off
				-- there are no deer kinds, and an ask is refused exactly as a roll is -- which is
				-- what keeps the schedule's half of this feature free of the flag.
				expect(Boar.deerComposition(0, 0, configWith(false), true)).to.equal(nil)
				-- ...and `false` is the behaviour every caller before task 234 had.
				expect(Boar.deerComposition(1.0, 0, config, false)).to.equal(nil)
			end)

			-- ------------------------------------------------ THEY WALK IN FILE (task 234)
			it("MARCHES A DEER GROUP IN SINGLE FILE, declared rather than drawn", function()
				-- Karen, 2026-10-21: *"we need all a time in drive deer and could be also lines and
				-- how they behav"*, and "yes" to deer walking one after another in a row.
				--
				-- `"column"` IS THE FORMATION THIS GAME ALREADY HAD (task 118): a leader,
				-- `Boar.marchOrder` behind him, slots at `(0, 0, (i-1) * COLUMN_SPACING_STUDS)`.
				-- Nothing here is a second movement writer -- the group simply declares what a
				-- boar sounder draws.
				local config = configWith(true)
				expect(config.SPECIES.reddeer.RELEASE.FORMATION).to.equal("column")
				for _, shape in ipairs(config.SPECIES.reddeer.RELEASE.COMPOSITIONS) do
					expect(Boar.compositionFormation(shape, config)).to.equal("column")
				end
				-- A BOAR COMPOSITION HAS NO OPINION, so a boar sounder still draws between the
				-- wedge and the column at `COLUMN_CHANCE` -- unchanged, which is the whole of
				-- "no boar behaviour moved".
				expect(Boar.compositionFormation({ females = 2, cubs = 3 }, config)).to.equal(nil)
				expect(Boar.compositionFormation({ males = 1 }, config)).to.equal(nil)
				-- ...AND A MIXED GROUP HAS NO ONE ANSWER, so it gets none rather than one of them.
				expect(Boar.compositionFormation({ stag = 1, male = 1 }, config)).to.equal(nil)
				-- `weight` IS NOT AN ANIMAL: a `COMPOSITIONS` row carries its draw weight beside
				-- its counts, and reading it as a kind would answer nil for every real row.
				expect(Boar.compositionFormation({ weight = 40, stag = 1 }, config)).to.equal("column")
				-- With `BOAR_MODEL` off there are no kinds, so nothing declares anything.
				expect(Boar.compositionFormation({ stag = 1 }, configWith(false))).to.equal(nil)
				expect(Boar.compositionFormation(nil, config)).to.equal(nil)
			end)

			it("SPACES THE FILE wider than the longest deer in it", function()
				-- The Director asked for "each follower on the leader's trail at a MEASURED
				-- spacing". The three deer were measured at the prep (`KINDS`), and this is the
				-- check that says 9 studs is the right gap for them rather than a number reused
				-- from the boar because it was there. TO SEE IT FAIL: drop
				-- `SOUNDER.COLUMN_SPACING_STUDS` to 6 -- a stag is 7.05 studs long and the file
				-- becomes a stag standing inside the hind in front of him.
				local config = configWith(true)
				local gap = config.SOUNDER.COLUMN_SPACING_STUDS
				local longest, which = 0, ""
				for _, kind in ipairs({ "stag", "hind", "calf" }) do
					local length = Boar.kindGeometry(kind, Boar.kindConfig(kind, config)).bodySize.Z
					if length > longest then
						longest, which = length, kind
					end
				end
				TestKit.note(
					string.format("task234 deer file: %.2f stud slots, longest deer %s at %.2f", gap, which, longest)
				)
				expect(longest > 0).to.equal(true)
				expect(gap > longest).to.equal(true)
			end)

			it("refuses a second deer group while one is alive, and counts GROUPS", function()
				local config = configWith(true)
				expect(Boar.deerGroupsAllowed({}, config)).to.equal(true)
				expect(Boar.deerGroupsAllowed({ "male", "female", "cub" }, config)).to.equal(true)
				expect(Boar.deerGroupsAllowed({ "male", "hind" }, config)).to.equal(false)
				expect(Boar.deerGroupsAllowed({ "stag" }, config)).to.equal(false)
				-- ROUND 1 DID NOT COUNT ANYTHING (Reviewer's note): it answered
				-- `MAX_GROUPS_ALIVE > 1` on the FIRST live deer, so the dial worked only at 1 and at
				-- 2 it capped nothing at all. Three members of ONE release share a sounder id and
				-- are ONE group, so at a cap of 2 they still leave room for a second.
				local two = configWith(true)
				two.SPECIES = table.clone(Boar.CONFIG.SPECIES)
				two.SPECIES.reddeer = table.clone(Boar.CONFIG.SPECIES.reddeer)
				two.SPECIES.reddeer.RELEASE = table.clone(Boar.CONFIG.SPECIES.reddeer.RELEASE)
				two.SPECIES.reddeer.RELEASE.MAX_GROUPS_ALIVE = 2
				local oneHerd = {
					{ kind = "stag", sounder = "S1" },
					{ kind = "hind", sounder = "S1" },
					{ kind = "hind", sounder = "S1" },
				}
				expect(Boar.deerGroupsAllowed(oneHerd, two)).to.equal(true)
				local twoHerds = {
					{ kind = "stag", sounder = "S1" },
					{ kind = "hind", sounder = "S2" },
				}
				expect(Boar.deerGroupsAllowed(twoHerds, two)).to.equal(false)
				-- ...and at the shipped cap of 1 that same single herd already fills it.
				expect(Boar.deerGroupsAllowed(oneHerd, config)).to.equal(false)
			end)

			-- FINDING 1. THE FLAG-OFF STREAM, COUNTED AGAINST A BASELINE ------------------------
			--
			-- ROUND 1 SHIPPED THE BUG THIS CASE EXISTS FOR. The two rolls were the ARGUMENTS to
			-- `Boar.deerComposition`, and Lua evaluates arguments before it enters a function, so
			-- the gate INSIDE it could not stop them being drawn: the default build, where
			-- `BOAR_MODEL` is off, consumed two extra numbers on every composition-less release and
			-- every later draw -- the formation's `phase`, its `COLUMN_CHANCE` -- came out
			-- different from the values every spec written before task 223 was written against.
			--
			-- IT IS COUNTED, NOT INSPECTED. The runtime's `Random` is handed in, so a counting
			-- wrapper records exactly how many numbers one release asks for. The BASELINE is a
			-- release that cannot possibly want a deer -- a NAMED composition, which
			-- `spawnSounder` never offers the deer draw -- and the flag-off release must ask for
			-- the same count. Nothing here asserts a magic number: it asserts two runs agree.
			it("draws NOT ONE extra number with BOAR_MODEL off", function()
				local function releaseDraws(flagOn: boolean, composition): number
					local holder = Instance.new("Folder")
					holder.Name = "DeerStreamSpec"
					holder.Parent = Workspace
					local drawn = 0
					local real = Random.new(2231)
					local counting = {
						NextNumber = function(_self, ...)
							drawn += 1
							return real:NextNumber(...)
						end,
						NextInteger = function(_self, ...)
							drawn += 1
							return real:NextInteger(...)
						end,
					}
					local runtime = Boar.newRuntime({
						field = FIELD,
						parent = holder,
						folderName = "Stream",
						rng = counting :: any,
						config = { KINDS = { ENABLED = flagOn }, maxBoars = 12 },
						threats = function()
							return {}
						end,
						probe = function()
							return false
						end,
						requestPath = function(_id, _from, _to, done)
							done(nil)
						end,
						releasePath = function() end,
					})
					runtime:spawnSounder(Vector3.new(0, 10, 0), 3, 20, composition)
					runtime:destroy()
					holder:Destroy()
					return drawn
				end

				-- The baseline: a NAMED composition of three boars. `spawnSounder` never consults
				-- the deer draw when the caller named one, with the flag on or off, so this is the
				-- release that cannot want a deer in either world.
				local named = releaseDraws(false, { females = 1, cubs = 2 })
				-- The one that round 1 broke: no composition, flag OFF. Same release, same size.
				local blind = releaseDraws(false, nil)
				expect(blind).to.equal(named)
			end)
		end)

		-- 9. THE PRICES, THROUGH THE REAL SCORER -------------------------------------------------
		describe("what a red deer is worth", function()
			local function pointsFor(kind: string): number
				local board = Score.new()
				local after = Score.kill(board, { killedByUserId = 7, kind = kind, at = 0 }, nil, Match.CONFIG)
				return after.rows[7].points
			end

			it("prices the stag above a male boar and below the trophy", function()
				expect(pointsFor("stag")).to.equal(20)
				expect(pointsFor("stag") > pointsFor("male")).to.equal(true)
				expect(pointsFor("stag") < pointsFor("legendary")).to.equal(true)
			end)

			it("prices the hind exactly as the sow", function()
				expect(pointsFor("hind")).to.equal(6)
				expect(pointsFor("hind")).to.equal(pointsFor("female"))
			end)

			it("makes the CALF a penalty, through the price and through nothing else", function()
				-- THE ARM: a negative row IS the penalty (there is no second mechanism), and the
				-- kill must be a KNOWN kind -- a calf landing in `unknown` would score +6 and the
				-- rule would silently be inverted.
				expect(pointsFor("calf")).to.equal(-10)
				expect(pointsFor("calf")).to.equal(pointsFor("cub"))
				expect(pointsFor("calf") < 0).to.equal(true)
				local board = Score.new()
				local after, awards =
					Score.kill(board, { killedByUserId = 7, kind = "calf", at = 0 }, nil, Match.CONFIG)
				expect(after.rows[7].kills).to.equal(1)
				expect(awards[1].reason).to.equal("kill-calf")
			end)
		end)

		-- 12. THE SCENE'S SCALES ARE THE BAKED LENGTHS -------------------------------------------
		it("lays every kind out at its own baked length", function()
			-- The trap this catches: a deer's `KINDS.scale` is against the STAG and the scene's is
			-- against the BOAR MALE, so the two numbers for one animal are different on purpose.
			local scales = Match.CONFIG.SCENE.ANIMAL_SCALES
			local male = CONFIG.BODY_SIZE.Z
			local deerLength = CONFIG.SPECIES.reddeer.BODY_SIZE.Z
			for _, kind in ipairs(CONFIG.KINDS.ORDER) do
				local row = CONFIG.KINDS[kind]
				local baked = if row.species == "reddeer" then deerLength * row.scale else male * row.scale
				expect(scales[kind]).to.be.ok()
				expect(scales[kind] * male).to.be.near(baked, 0.01)
			end
		end)

		-- 13. THE SCREENS ------------------------------------------------------------------------
		describe("what the screens draw", function()
			it("gives each deer kind its own picture", function()
				local art = Report.CONFIG.BOAR_IMAGE
				expect(Report.boarImage("stag").id).to.equal(art.stag.id)
				expect(Report.boarImage("hind").id).to.equal(art.hind.id)
				-- The calf is the HIND's drawing, smaller -- said out loud, not hidden.
				expect(Report.boarImage("calf").id).to.equal(art.hind.id)
				expect(Report.boarImage("calf").scale).to.be.near(Report.CONFIG.CALF_SCALE, EPSILON)
				-- ...and its own row, not the piglet's, although both are 0.70 today.
				expect(Report.boarImage("cub").id).to.equal(art.female.id)
				-- An id a label can actually draw: an Open Cloud PNG upload makes a DECAL, and an
				-- ImageLabel cannot draw a decal id (task 205 lost a round to exactly that). These
				-- are the IMAGE ids those decals carry.
				for _, kind in ipairs({ "stag", "hind" }) do
					expect(string.match(art[kind].id, "^rbxassetid://%d+$")).to.be.ok()
					expect(art[kind].id).never.to.equal(art.male.id)
				end
			end)

			it("names the stag on the hit card and nothing else", function()
				expect(Report.trophyWord("stag")).to.equal("RED STAG")
				expect(Report.trophyWord("hind")).to.equal(nil)
				expect(Report.trophyWord("calf")).to.equal(nil)
				expect(Report.trophyWord("legendary")).to.equal("LEGENDARY BOAR")
			end)

			it("prints each deer kind's own word in the report's ANIMAL column", function()
				expect(Report.kindWord("stag")).to.equal("stag")
				expect(Report.kindWord("hind")).to.equal("hind")
				expect(Report.kindWord("calf")).to.equal("calf")
				-- The piglet's rename is untouched.
				expect(Report.kindWord("cub")).to.equal("piglet")
			end)
		end)
	end)
end

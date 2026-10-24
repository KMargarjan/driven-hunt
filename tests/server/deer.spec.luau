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
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local ForestTest = require(ReplicatedStorage:WaitForChild("ForestTest"))
local Licences = require(ReplicatedStorage:WaitForChild("Licences"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local Brain = Boar.Brain

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
	leap = "deer.anim.leap", -- the twelfth, task 245b
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
				-- THE `MODEL` IS AN OVERLAY SINCE TASK 240 and so is NOT the module's table by
				-- reference any more -- it is the WORLD's `MODEL` with `MODEL_OVERRIDES` laid over
				-- it. Asserted as the property rather than as an identity: every override wins, and
				-- `ANIMATION_IDS` is still the SAME TABLE the boot script fills, because a copy
				-- would leave every deer with an empty id table and no clips at all.
				expect(deer.MODEL).never.to.equal(CONFIG.SPECIES.reddeer.MODEL)
				for key, value in pairs(CONFIG.SPECIES.reddeer.MODEL_OVERRIDES) do
					expect(deer.MODEL[key]).to.equal(value)
				end
				expect(deer.MODEL.ANIMATION_IDS).to.equal(CONFIG.SPECIES.reddeer.MODEL.ANIMATION_IDS)
				expect(deer.MODEL.CLIPS).to.equal(CONFIG.SPECIES.reddeer.MODEL.CLIPS)
				-- The deer is longer than the boar and NOT a multiple of its box.
				expect(deer.BODY_SIZE.Z > config.BODY_SIZE.Z).to.equal(true)
				expect(deer.BODY_SIZE.X < config.BODY_SIZE.X).to.equal(true)
			end)

			-- 5b. THE WORLD'S OWN `MODEL` NUMBERS REACH THE DEER (task 240) ----------------------
			--
			-- KAREN, 2026-10-22: *"deer running is a bit odd"*. `ForestTestBoot` lowers
			-- `MODEL.RUN_FROM` from 28 to `(TROT_SPEED + PACE.RUN_SPEED) / 2` = 21 so an animal
			-- bolting at 24 is DRAWN running rather than trotting -- and until this task the deer
			-- kept the module's 28 while bolting at `24 x runScale 1.18` = 28.3, three tenths of a
			-- stud a second over its own band edge. MEASURED in two 70 s windows of real drives:
			-- 8 of 13 and 8 of 68 of the stag's samples at 20 studs/s or more were drawn TROTTING
			-- or WALKING, against 2-3 % for every boar kind and for the hind and the calf.
			--
			-- IT IS DRIVEN BY PARAMETER, as the whole file is: a world table with RUN_FROM moved,
			-- exactly the shape `ForestTestBoot` builds, and then the deer's own band read back
			-- through `Body.gaitBands` -- the function `Body.clipFor` picks a gait with.
			it("takes the WORLD's gait band, not the module's, so a bolting stag is drawn running", function()
				local config = configWith(true)
				local world = table.clone(config)
				world.MODEL = table.clone(config.MODEL)
				world.MODEL.RUN_FROM = 21 -- the Forest Test's own number
				world.MODEL.ENABLED = true

				local stag = Boar.kindConfig("stag", world)
				expect(stag.MODEL.RUN_FROM).to.equal(21)
				expect(stag.MODEL.ENABLED).to.equal(true)
				-- ...and the four overrides still win over the world's values.
				expect(stag.MODEL.CLIPS).to.equal(CONFIG.SPECIES.reddeer.MODEL.CLIPS)
				expect(stag.MODEL.TROT_FROM).to.be.near(
					CONFIG.SPECIES.reddeer.MODEL.CLIPS.walk.groundStudsPerSecond * config.MODEL.WALK_MAX_RATE,
					EPSILON
				)

				-- THE BAND, PER KIND, AGAINST THE SPEED EACH ONE ACTUALLY BOLTS AT. One case per
				-- arm (L-093): the stag was the only kind on its rail, and a case that only
				-- entered his would not notice if the hind's or the calf's regressed.
				for _, kind in ipairs(DEER_KINDS) do
					local animal = Boar.kindConfig(kind, world)
					local bands = Boar.gaitBands(CONFIG.KINDS[kind].clipScale, animal)
					local bolt = animal.PACE.RUN_SPEED
					expect(bolt > bands.runFrom).to.equal(true)
					-- A FIFTH OF MARGIN, not three tenths of a stud: below this the clip flickers
					-- between the trot and the run at every wobble in the animal's speed.
					expect((bolt - bands.runFrom) / bolt > 0.2).to.equal(true)
					TestKit.note(
						string.format(
							"deer-240: %s bolts at %.2f studs/s, run band from %.2f (margin %.0f%%)",
							kind,
							bolt,
							bands.runFrom,
							100 * (bolt - bands.runFrom) / bolt
						)
					)
				end

				-- AND WITHOUT THE WORLD'S NUMBER THE STAG IS BACK ON THE RAIL, which is the state
				-- Karen played: the two states have to be reachable by parameter or neither is
				-- tested. 28.32 against 28.0 is 1.1 % of margin.
				local onTheRail = Boar.kindConfig("stag", config)
				local railBands = Boar.gaitBands(1.0, onTheRail)
				expect(railBands.runFrom).to.equal(config.MODEL.RUN_FROM)
				expect((onTheRail.PACE.RUN_SPEED - railBands.runFrom) / railBands.runFrom < 0.05).to.equal(true)
			end)

			it("composes the species tables with the kind's wary scaling", function()
				local config = configWith(true)
				local stag = Boar.kindConfig("stag", config)
				expect(stag.BODY_SIZE).to.equal(CONFIG.SPECIES.reddeer.BODY_SIZE)
				-- 1.5 -> 1.8 IN TASK 251 PART 2 (spec section 3.1, Karen OK'd): *"a lone stag has no jumpy
				-- companion to trigger him, so he must be his own alarm"*, so he carries the hind's own
				-- scale. The radius this case is about is unchanged in MEANING -- it is still the kind's
				-- `wary` multiplier reaching `DETECT_RADIUS` through `scaledByWary` -- and what the stag
				-- NOTICES at is the case in "the red stag's own behaviour" below.
				expect(stag.DETECT_RADIUS).to.be.near(config.DETECT_RADIUS * 1.8, EPSILON)
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

		-- 5c. THE DEER'S VOICE IS NOT A PIG'S (task 240) -----------------------------------------
		--
		-- KAREN, 2026-10-22, after playing the Forest Test: *"deer sound has to bee when hit now it
		-- seems it's pig sound when I hit deer"*. Task 223 shipped the three deer rows holding the
		-- BOAR's pig squeals, pitched, and wrote that down as a known compromise. A pig squeal is
		-- the most recognisable noise in the whole set and pitching it does not stop it being one.
		--
		-- ONE CASE PER KIND AND PER CUE (L-093): the fix is a three-armed branch -- stag, hind,
		-- calf -- and a single generic "the deer does not sound like a pig" assertion would pass
		-- with two of the three arms still holding pig ids. That exact defect class cost task 219
		-- three review rounds.
		--
		-- IT IS ASSERTED AS A DISJOINTNESS and not as a list of expected ids: "the stag's death is
		-- 9113626273" would have to be edited by anybody who swaps a sample, which is the one thing
		-- this table is meant to make cheap. What may never happen is a deer and a boar sharing a
		-- sample, or a deer borrowing the module-level generic set (which IS the pig squeals).
		describe("the deer's voice", function()
			it("shares no sample with any boar cue, kind by kind and cue by cue", function()
				local on = configWith(true)
				local voice = CONFIG.SOUND.VOICE
				local sound = CONFIG.SOUND

				-- EVERY ID A BOAR CAN MAKE, including the module-level generic rows a kind with no
				-- voice falls back to -- because falling back IS how the deer got pig squeals.
				local boarIds: { [number]: string } = {}
				local function collect(ids, where: string)
					if type(ids) ~= "table" then
						return
					end
					for _, id in ipairs(ids) do
						boarIds[id] = where
					end
				end
				collect(sound.CRY.ids, "SOUND.CRY")
				collect(sound.DEATH.ids, "SOUND.DEATH")
				collect(sound.GRUNTS.ids, "SOUND.GRUNTS")
				for _, kind in ipairs(BOAR_KINDS) do
					local row = voice[kind]
					expect(row).to.be.ok()
					for _, cue in ipairs({ "cry", "death", "grunt" }) do
						collect(row[cue], kind .. "." .. cue)
					end
				end

				local clashes = {}
				for _, kind in ipairs(DEER_KINDS) do
					for _, cue in ipairs({ "cry", "death", "grunt" }) do
						-- THROUGH THE REAL RESOLVER, not by reading the table: `Body.voiceIds` is
						-- what `playOneShot` calls, and its fallback to `spec.ids` is the path that
						-- produced the pig sound in the first place.
						local spec = if cue == "cry"
							then sound.CRY
							elseif cue == "death" then sound.DEATH
							else sound.GRUNTS
						local ids = Boar.voiceIds(cue, kind, spec, on)
						expect(ids).to.equal(voice[kind][cue]) -- its OWN list, never the generic one
						expect(#ids > 0).to.equal(true)
						for _, id in ipairs(ids) do
							if boarIds[id] ~= nil then
								table.insert(
									clashes,
									string.format("%s.%s id %d is also %s", kind, cue, id, boarIds[id])
								)
							end
						end
					end
				end
				table.sort(clashes)
				expect(table.concat(clashes, " | ")).to.equal("")
			end)

			it("gives each deer kind a pitch of its own, measured against ITS OWN sample", function()
				-- THE THREE NUMBERS ARE NOT IN SIZE ORDER AND MUST NOT BE READ AS IF THEY WERE
				-- (round 1's note). The boar's three are one sample set, so their ratio IS which
				-- animal sounds deeper; the deer's are not -- the stag's 1.15 multiplies a BULL
				-- bellow (pitched UP, a stag being about a third of a bull) and the hind's 0.80 a
				-- LAMB bleat (pitched DOWN, a hind being about three lambs). Comparing 1.15 with
				-- 0.80 says nothing about either animal.
				--
				-- SO WHAT IS ASSERTED IS WHAT IS TRUE: three distinct pitches, none of them task
				-- 223's pig-era numbers, and the hind not sharing the sow's samples.
				local voice = CONFIG.SOUND.VOICE
				local seen = {}
				for _, kind in ipairs(DEER_KINDS) do
					expect(type(voice[kind].pitch)).to.equal("number")
					expect(voice[kind].pitch > 0).to.equal(true)
					expect(seen[voice[kind].pitch]).to.equal(nil)
					seen[voice[kind].pitch] = kind
				end
				-- THE CALF IS THE THIN ONE AND THE HIND IS NOT, within the one sample set they share.
				expect(voice.calf.pitch > voice.hind.pitch).to.equal(true)
				-- ...AND THE TWO FEMALES ARE NOT THE SAME ANIMAL: a hind bleats and a sow squeals,
				-- so if the two rows ever converge on one sample set the deer is a pig again.
				expect(voice.hind.death).never.to.equal(voice.female.death)
			end)

			-- ROUND 1, FINDING 2'S REPLACEMENT. The case that stood here named no deer and would have
			-- passed with every line of this task reverted: it asserted `DEATH.cut`, `SQUEAL_SECONDS`
			-- and `CRY.cut == nil`, all three of which predate the task. It also failed to catch
			-- round 1's finding 1 -- that the hind's and the calf's bleats are LONGER than the budget
			-- the world books for them.
			--
			-- THIS ONE ASSERTS THE RELATION ON THE DEER'S OWN ROWS, off MEASURED lengths
			-- (`VOICE.LENGTHS`, read back from `Sound.TimeLength` in a live session), so an id added
			-- without a measurement fails the suite and an id that is too long fails it too.
			it("cannot hold a voice slot it has already given back, on any deer kind or cue", function()
				local on = configWith(true)
				local sound = CONFIG.SOUND
				local voice = sound.VOICE
				local crowd = sound.CROWD
				local specOf = { cry = sound.CRY, death = sound.DEATH, grunt = sound.GRUNTS }

				-- EVERY ID IN THE TABLE HAS A MEASURED LENGTH, boar ids included, because the bound
				-- below is a comparison and an unmeasured id would silently skip it.
				local unmeasured = {}
				local function check(ids, where: string)
					for _, id in ipairs(ids) do
						local length = voice.LENGTHS[id]
						if type(length) ~= "number" or length <= 0 then
							table.insert(unmeasured, string.format("%s id %d", where, id))
						end
					end
				end
				for _, cue in ipairs({ "cry", "death", "grunt" }) do
					check(specOf[cue].ids, "SOUND." .. cue)
					for _, kind in ipairs(CONFIG.KINDS.ORDER) do
						check(voice[kind][cue], kind .. "." .. cue)
					end
				end
				table.sort(unmeasured)
				expect(table.concat(unmeasured, ", ")).to.equal("")

				-- ...AND NO DEER CUE SOUNDS FOR LONGER THAN THE WORLD BOOKS IT FOR. A sample plays
				-- for `length / pitch` seconds and `Body.voiceCut` bounds that; the booking is
				-- `SQUEAL_SECONDS` for a cry or a death (`Runtime:_claimSqueal`) and
				-- `GRUNT_GAP_SECONDS` for a grunt (the gap before another may START).
				local tooLong, lines = {}, {}
				for _, kind in ipairs(DEER_KINDS) do
					local pitch = voice[kind].pitch
					for _, cue in ipairs({ "cry", "death", "grunt" }) do
						local spec = specOf[cue]
						local cut = Boar.voiceCut(cue, kind, spec, on)
						local budget = if cue == "grunt" then crowd.GRUNT_GAP_SECONDS else crowd.SQUEAL_SECONDS
						for _, id in ipairs(Boar.voiceIds(cue, kind, spec, on)) do
							local whole = voice.LENGTHS[id] / pitch
							local sounds = if cut ~= nil then math.min(whole, cut) else whole
							if sounds >= budget then
								table.insert(
									tooLong,
									string.format(
										"%s.%s id %d sounds %.2f s against %.2f",
										kind,
										cue,
										id,
										sounds,
										budget
									)
								)
							end
							table.insert(lines, string.format("%s.%s %.2fs", kind, cue, sounds))
						end
					end
				end
				table.sort(tooLong)
				expect(table.concat(tooLong, " | ")).to.equal("")
				TestKit.note("deer-240 cue lengths: " .. table.concat(lines, " "))
			end)

			-- ...AND THE OTHER HALF OF THE SAME FIX: the cut is on the DEER's rows and nowhere else,
			-- so the boar makes exactly the noise Karen signed off (*"animal react sound is good"*).
			it("cuts only the deer, and never lengthens a death", function()
				local on = configWith(true)
				local sound = CONFIG.SOUND
				local specOf = { cry = sound.CRY, death = sound.DEATH, grunt = sound.GRUNTS }
				-- ONE ARM PER BOAR KIND (L-093): a case that only entered the male's would not see a
				-- `cut` smuggled onto the legendary.
				for _, kind in ipairs(BOAR_KINDS) do
					expect(CONFIG.SOUND.VOICE[kind].cut).to.equal(nil)
					for _, cue in ipairs({ "cry", "death", "grunt" }) do
						expect(Boar.voiceCut(cue, kind, specOf[cue], on)).to.equal(specOf[cue].cut)
					end
				end
				-- ...AND ONE PER DEER KIND: the cry and the grunt take the row's, the DEATH keeps the
				-- 0.6 s Karen asked for, because `voiceCut` takes the SMALLER of the two.
				for _, kind in ipairs(DEER_KINDS) do
					local own = CONFIG.SOUND.VOICE[kind].cut
					expect(own).to.be.ok()
					expect(own).to.be.near(CONFIG.SOUND.VOICE.CUE_CUT_SECONDS, EPSILON)
					expect(Boar.voiceCut("cry", kind, sound.CRY, on)).to.be.near(own, EPSILON)
					expect(Boar.voiceCut("grunt", kind, sound.GRUNTS, on)).to.be.near(own, EPSILON)
					expect(Boar.voiceCut("death", kind, sound.DEATH, on)).to.be.near(sound.DEATH.cut, EPSILON)
					expect(sound.DEATH.cut < own).to.equal(true)
				end
				-- A CUT CUE MUST BE ABLE TO END RATHER THAN BE CHOPPED, which is what `fade` is for
				-- and what `Body.cutVolume` reads. The two cues the deer newly cuts had none.
				expect(sound.CRY.fade).to.be.ok()
				expect(sound.GRUNTS.fade).to.be.ok()
				expect(sound.CRY.fade < CONFIG.SOUND.VOICE.CUE_CUT_SECONDS).to.equal(true)
				-- ...and with the voice OFF nothing is cut that was not cut before.
				local off = table.clone(on)
				local offSound = table.clone(CONFIG.SOUND)
				offSound.VOICE = table.clone(CONFIG.SOUND.VOICE)
				offSound.VOICE.ENABLED = false
				off.SOUND = offSound
				expect(Boar.voiceCut("cry", "stag", sound.CRY, off)).to.equal(sound.CRY.cut)
			end)
		end)

		-- 5d. TWENTY PER CENT MORE HITS (task 240) ------------------------------------------------
		--
		-- KAREN, 2026-10-22: *"deer need more hits before die a bit more like 20% more"*.
		-- `toughness` is the mechanism task 219 built for the legendary and 1.2 is her sentence
		-- arithmetically: `Wound.damageFor` divides a NON-VITAL hit by it, so each point is worth
		-- 83.3 % and it takes 20 % more of them. One case per kind (L-093), because three rows were
		-- edited and a case that only entered the stag's would not see a missing one.
		describe("how much a deer takes", function()
			local Wound = Boar.Wound
			local WOUND = CONFIG.WOUND

			it("is a fifth tougher than it was, on every one of the three kinds", function()
				local on = configWith(true)
				for _, kind in ipairs(DEER_KINDS) do
					expect(Boar.toughnessFor(kind, on)).to.be.near(1.2, EPSILON)
				end
				-- ...and the boars are untouched: only the legendary has ever had armour.
				expect(Boar.toughnessFor("male", on)).to.equal(nil)
				expect(Boar.toughnessFor("female", on)).to.equal(nil)
				expect(Boar.toughnessFor("cub", on)).to.equal(nil)
				expect(Boar.toughnessFor("legendary", on)).to.be.near(2.0, EPSILON)
				-- WITH THE KINDS OFF NOTHING IS ARMOURED, which is the flag-off world unchanged.
				for _, kind in ipairs(DEER_KINDS) do
					expect(Boar.toughnessFor(kind, configWith(false))).to.equal(nil)
				end
			end)

			it("leaves the head and the chest unarmoured and charges the rump and legs a fifth more", function()
				local tough = Boar.toughnessFor("stag", configWith(true))
				-- THE VITALS ARE NEVER ARMOURED -- `Wound.damageFor`'s own rule and the hunting rule
				-- behind it: take the chamber or the head. A chest slug still drops a stag.
				for _, zone in ipairs({ "head", "chest" }) do
					expect(Wound.damageFor(zone, "Slug", 1, WOUND, tough)).to.equal(
						Wound.damageFor(zone, "Slug", 1, WOUND, nil)
					)
					expect(Wound.damageFor(zone, "Slug", 1, WOUND, tough) >= WOUND.LETHAL).to.equal(true)
				end
				-- ...AND EVERYTHING ELSE IS WORTH FIVE SIXTHS.
				for _, zone in ipairs({ "rear", "legs" }) do
					for _, ammo in ipairs({ "Slug", "Pellet" }) do
						local before = Wound.damageFor(zone, ammo, 1, WOUND, nil)
						local after = Wound.damageFor(zone, ammo, 1, WOUND, tough)
						expect(after).to.be.near(before / 1.2, EPSILON)
					end
				end
			end)

			it("names the hits to kill, before and after", function()
				-- THE NUMBERS IN THE REPORT, COMPUTED RATHER THAN TYPED. `Wound.damageFor` has no
				-- range term, so these are the same at 20 m and at 40 m; what range changes is how
				-- many pellets land, and buckshot's own `RANGE_STUDS` is 100 studs (28 m), so at
				-- 40 m none of them do.
				local function hitsTo(zone: string, ammo: string, target: number, tough: number?): number
					local each = Wound.damageFor(zone, ammo, 1, WOUND, tough)
					expect(each > 0).to.equal(true)
					return math.ceil(target / each)
				end
				local tough = Boar.toughnessFor("stag", configWith(true))
				local lines = {}
				for _, zone in ipairs({ "rear", "legs" }) do
					for _, ammo in ipairs({ "Slug", "Pellet" }) do
						local wasMortal = hitsTo(zone, ammo, WOUND.MORTAL, nil)
						local wasLethal = hitsTo(zone, ammo, WOUND.LETHAL, nil)
						local isMortal = hitsTo(zone, ammo, WOUND.MORTAL, tough)
						local isLethal = hitsTo(zone, ammo, WOUND.LETHAL, tough)
						-- IT MAY NEVER GET EASIER, which is the only direction this can be wrong in.
						expect(isMortal >= wasMortal).to.equal(true)
						expect(isLethal >= wasLethal).to.equal(true)
						table.insert(
							lines,
							string.format(
								"%s/%s mortal %d to %d, lethal %d to %d",
								zone,
								ammo,
								wasMortal,
								isMortal,
								wasLethal,
								isLethal
							)
						)
					end
				end
				-- ...AND IT REALLY IS HARDER SOMEWHERE, so a `toughness` of 1.0 could not pass this.
				local softLethal = hitsTo("rear", "Pellet", WOUND.LETHAL, nil)
				local hardLethal = hitsTo("rear", "Pellet", WOUND.LETHAL, tough)
				expect(hardLethal > softLethal).to.equal(true)
				TestKit.note("deer-240 hits to kill: " .. table.concat(lines, " | "))
			end)
		end)

		-- 5e. THE SWEEP IS AS WIDE AS THE ANTLERS (task 240) --------------------------------------
		--
		-- KAREN, 2026-10-22: *"deer running is a bit odd and seems it hitting trees"*. MEASURED in
		-- her own place off each kind's loaded mesh: a stag is DRAWN 3.47 studs wide and COLLIDES as
		-- a 1.80-wide box, so his box clears a trunk by 0.70 studs while his antlers are 0.84 studs
		-- inside it -- and the swept avoidance cast that is supposed to keep him off trunks was
		-- 1.60, narrower than his own drawn half-width of 1.735. Every BOAR is drawn NARROWER than
		-- its box (male 1.40 against 2.00), which is why no boar number may move.
		it("sweeps for trunks as wide as the animal a player SEES, and leaves every boar at 1.6", function()
			local on = configWith(true)
			local move = CONFIG.MOVE
			expect(move.AVOID_CLEARANCE_STUDS).to.be.ok()

			-- EVERY BOAR KIND IS THE NUMBER TASK 167 MEASURED, to the last decimal.
			for _, kind in ipairs(BOAR_KINDS) do
				expect(Boar.avoidRadius(kind, on)).to.be.near(move.AVOID_RADIUS_STUDS, EPSILON)
			end
			expect(Boar.avoidRadius(nil, on)).to.be.near(move.AVOID_RADIUS_STUDS, EPSILON)
			expect(Boar.avoidRadius("wildebeest", on)).to.be.near(move.AVOID_RADIUS_STUDS, EPSILON)

			-- ...AND EACH DEER KIND ENTERS ITS OWN ARM (L-093), through the config it really lives
			-- by, because `_avoidTurnFor` is handed `entry.config` and that is the SPECIES box.
			local widths = {}
			for _, kind in ipairs(DEER_KINDS) do
				local animal = Boar.kindConfig(kind, on)
				local row = CONFIG.KINDS[kind]
				expect(row.drawnWidthStuds).to.be.ok()
				local radius = Boar.avoidRadius(kind, animal)
				local widest = math.max(row.drawnWidthStuds, animal.BODY_SIZE.X)
				expect(radius).to.be.near(
					math.max(move.AVOID_RADIUS_STUDS, widest / 2 + move.AVOID_CLEARANCE_STUDS),
					EPSILON
				)
				-- THE PROPERTY THAT MATTERS: the cast is never narrower than the thing a player
				-- watches go past a trunk.
				expect(radius >= row.drawnWidthStuds / 2).to.equal(true)
				table.insert(widths, string.format("%s drawn %.2f, radius %.3f", kind, row.drawnWidthStuds, radius))
			end

			-- THE STAG IS THE ONE THAT MOVES, and it moves UP: a case that only asserted the
			-- formula would pass with every number unchanged.
			local stag = Boar.avoidRadius("stag", Boar.kindConfig("stag", on))
			expect(stag > move.AVOID_RADIUS_STUDS).to.equal(true)
			expect(stag).to.be.near(3.47 / 2 + move.AVOID_CLEARANCE_STUDS, EPSILON)
			-- EVERY KIND HAS THE MEASUREMENT, so a new animal cannot arrive without one -- and it
			-- walks `KINDS.ORDER` and not this file's own literal (round 1's note), because `ORDER`
			-- is what `BoarAssetsBoot` walks and what a new kind is really added to.
			expect(#CONFIG.KINDS.ORDER).to.equal(#ALL_KINDS)
			for _, kind in ipairs(CONFIG.KINDS.ORDER) do
				expect(type(CONFIG.KINDS[kind].drawnWidthStuds)).to.equal("number")
				expect(CONFIG.KINDS[kind].drawnWidthStuds > 0).to.equal(true)
			end
			TestKit.note("deer-240 avoid radius: " .. table.concat(widths, " | "))
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
			-- Twelve since task 245b added the leap, and none of the boar's grazing four.
			local count = 0
			for _ in pairs(deerModel.CLIPS) do
				count += 1
			end
			expect(count).to.equal(12)
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

		-- 6b. THE TWELVE PUBLISHED CLIPS (task 232, and the leap in 245b) ----------------------------------------------
		--
		-- IT IS THE MANIFEST THAT IS ASSERTED AND NOT THE LIVE `ANIMATION_IDS` TABLE, which is a
		-- real lesson from the first run of this spec: `_modelTemplate` FILLS that table from
		-- whatever source is wired, so another spec's fake id function had already written `20009`
		-- into it by the time this case ran. The manifest is the fact; the live table is session
		-- state.
		it("has a published animation row for every one of the deer's twelve clips", function()
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
					-- A CLIP THE BOAR DOES NOT HAVE HAS NO BOAR KEY TO COLLIDE WITH, which is the
					-- leap (task 245b): `BOAR_CLIP_KEY.leap` is nil on purpose and there is nothing
					-- to compare it against.
					local boarKey = BOAR_CLIP_KEY[name]
					local boarRow = if boarKey ~= nil then Assets.byKey(boarKey) else nil
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
			-- `leap` joined the once-only arm in task 245b: a looping bound would have a deer
			-- jumping on the spot all the way across the lane.
			expect(table.concat(once, ", ")).to.equal("deathLeft, deathRight, hitBack, hitFront, leap")
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

			-- ------------------------------------- ...AND MAY ASK FOR ONE BY NAME (task 251)
			it("GIVES THE PARTY THE DRIVE NAMED, and refuses a word this table does not have", function()
				-- KAREN, 2026-10-23, through the plan she OK'd: the HIND PARTY comes early in the
				-- drive and THE STAG comes last, alone. That is a fact about the drive's SHAPE, so
				-- `ForestTest.SCHEDULE.drive` has to be able to name which party it wants -- and it
				-- names the WORD, while this function stays the only thing that knows which row that
				-- is.
				local config = configWith(true)
				local stag = Boar.deerComposition(0, 0, config, "stag")
				expect(stag).to.be.ok()
				expect(stag.stag).to.equal(1)
				expect(stag.hind).to.equal(nil)
				local hinds = Boar.deerComposition(0, 0, config, "hinds")
				expect(hinds).to.be.ok()
				expect(hinds.hind).to.equal(1)
				expect(hinds.calf).to.equal(1)
				expect(hinds.stag).to.equal(nil)
				expect(Boar.deerComposition(0, 0, config, "harem").hind).to.equal(2)
				-- THE NAME BEATS THE PICK, which is the whole point: at `pick` 0.9 the weighted walk
				-- would answer the harem, and the ask answers what it asked for.
				expect(Boar.deerComposition(0, 0.9, config, "hinds").calf).to.equal(1)
				-- ...AND A NAME IT DOES NOT HAVE IS nil, not a draw and not the first row. A slot
				-- that asked for a party this table has not got is a mistake in the drive script, and
				-- "no deer, and the console says which word" is the honest answer to it.
				expect(Boar.deerComposition(0, 0, config, "roedeer")).to.equal(nil)
				expect(Boar.deerComposition(0, 0, config, "")).to.equal(nil)
				-- THE CHANCE IS SKIPPED BY A NAMED ASK TOO, even at the roll that refuses -- and even
				-- if `CHANCE_PER_RELEASE` were 0, which a drive's own scripted stag must survive.
				expect(Boar.deerComposition(1.0, 0, config, "stag")).to.be.ok()
				local noChance = configWith(true)
				noChance.SPECIES = table.clone(noChance.SPECIES)
				noChance.SPECIES.reddeer = table.clone(noChance.SPECIES.reddeer)
				noChance.SPECIES.reddeer.RELEASE = table.clone(noChance.SPECIES.reddeer.RELEASE)
				noChance.SPECIES.reddeer.RELEASE.CHANCE_PER_RELEASE = 0
				expect(Boar.deerComposition(0, 0, noChance, "stag")).to.be.ok()
				expect(Boar.deerComposition(0, 0, noChance)).to.equal(nil)
				-- ...and it still cannot conjure a kind that does not exist.
				expect(Boar.deerComposition(0, 0, configWith(false), "stag")).to.equal(nil)
				-- EVERY ROW IS NAMED, so a drive can reach all three and no row is unreachable.
				local names = {}
				for _, row in ipairs(config.SPECIES.reddeer.RELEASE.COMPOSITIONS) do
					expect(type(row.name)).to.equal("string")
					expect(names[row.name]).to.equal(nil) -- and the names are unique
					names[row.name] = true
					expect(Boar.deerComposition(0, 0, config, row.name)).to.be.ok()
				end
				-- `name` IS NOT A MEMBER OF THE GROUP, which is the one way this could have gone
				-- wrong: it is stripped exactly as `weight` is, so nothing tries to spawn a "name".
				expect(stag.name).to.equal(nil)
				expect(stag.weight).to.equal(nil)
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

			-- --------------------------------- THE SAME CAP, ASKED FROM OUTSIDE (task 239)
			--
			-- THE FOREST TEST NEVER REACHES `spawnSounder`. Its drive releases a wave as a FILE:
			-- `Runtime:spawn` one animal at a time, then `Runtime:formSounder` -- so the deer door
			-- inside `spawnSounder`, and the cap it consults, are not on that path at all. The
			-- forest therefore asks `Runtime:deerAllowed`, and this case is what says that is the
			-- SAME answer and not a second one: a live runtime with a real deer group out, checked
			-- against the pure rule over the same animals.
			it("answers the live cap through one door, for a caller that never spawns a sounder", function()
				local holder = Instance.new("Folder")
				holder.Name = "DeerAllowedSpec"
				holder.Parent = Workspace
				local runtime = Boar.newRuntime({
					field = FIELD,
					parent = holder,
					folderName = "Allowed",
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
				-- An empty world allows one.
				expect(runtime:deerAllowed()).to.equal(true)
				-- A BOAR IS NOT A DEER: the cap is the deer's and nothing else fills it.
				runtime:spawn(Vector3.new(0, FIELD.groundY, 0), "male")
				runtime:spawn(Vector3.new(6, FIELD.groundY, 0), "female")
				expect(runtime:deerAllowed()).to.equal(true)
				-- ...and one hind does, at `MAX_GROUPS_ALIVE` of 1.
				local hind = runtime:spawn(Vector3.new(12, FIELD.groundY, 0), "hind")
				expect(hind).to.be.ok()
				expect(runtime:deerAllowed()).to.equal(false)
				-- IT DRAWS NO NUMBER, which is what lets the forest ask it before deciding
				-- anything: the same question twice is the same answer twice.
				expect(runtime:deerAllowed()).to.equal(false)
				-- ...AND IT IS THE PURE RULE, not a second count. `Boar.deerGroupsAllowed` over
				-- the same three animals must agree, which is the whole claim.
				local live = {
					{ kind = "male", sounder = nil },
					{ kind = "female", sounder = nil },
					{ kind = "hind", sounder = nil },
				}
				expect(Boar.deerGroupsAllowed(live, configWith(true))).to.equal(false)
				-- ...AND THE STAG COMES ANYWAY, BECAUSE HE MOVES ALONE (task 253). **THE DIRECTOR'S
				-- DECISION, 2026-10-24**: *"if MAX_GROUPS_ALIVE slips him, let the stag (only) be
				-- released even if one other group is alive"*. MEASURED the night before -- the hind
				-- party was still on its feet at his slot, so the drive held him over to its next
				-- silence and he came out 26 s late, against an arithmetic written for his slot.
				expect(runtime:deerAllowed("stag")).to.equal(true)
				expect(Boar.deerGroupsAllowed(live, configWith(true), "stag")).to.equal(true)
				-- IT IS "A PARTY OF ONE" AND NOT "THE STAG": the hind party weighs two, so it is
				-- still refused while a group is out, and a drive cannot have two herds.
				expect(runtime:deerAllowed("hinds")).to.equal(false)
				expect(Boar.deerGroupsAllowed(live, configWith(true), "hinds")).to.equal(false)
				-- AND THE EXEMPTION IS ONE GROUP DEEP, not a bypass: with the stag out as well, the
				-- next stag is refused too.
				local stagOut = {
					{ kind = "hind", sounder = nil },
					{ kind = "stag", sounder = nil },
				}
				expect(Boar.deerGroupsAllowed(stagOut, configWith(true), "stag")).to.equal(false)
				-- A PARTY NOBODY NAMED is the answer every caller got before this task.
				expect(Boar.deerGroupsAllowed(live, configWith(true), nil)).to.equal(false)
				runtime:destroy()
				holder:Destroy()
			end)

			-- WHICH KINDS ARE DEER, ASKED ONCE (task 253) ---------------------------------------
			--
			-- The drive asks it on every tick of the beater line, to decide whether an animal the
			-- line has reached bolts or slips away, and three callers were about to inline
			-- `KINDS[kind].species == "reddeer"`.
			it("knows a deer kind from a boar kind, and knows none at all with the flag off", function()
				local config = configWith(true)
				expect(Boar.isDeerKind("stag", config)).to.equal(true)
				expect(Boar.isDeerKind("hind", config)).to.equal(true)
				expect(Boar.isDeerKind("calf", config)).to.equal(true)
				expect(Boar.isDeerKind("male", config)).to.equal(false)
				expect(Boar.isDeerKind("female", config)).to.equal(false)
				expect(Boar.isDeerKind("cub", config)).to.equal(false)
				-- AN UNKNOWN WORD AND NO WORD ARE BOTH "not a deer", which is the safe answer: the
				-- caller's fallback is the behaviour every animal had before this task.
				expect(Boar.isDeerKind("elephant", config)).to.equal(false)
				expect(Boar.isDeerKind(nil, config)).to.equal(false)
				-- WITH `KINDS` OFF THERE ARE NO KINDS, so there is no deer -- the same first line
				-- `deerGroupsAllowed` takes, and the default build has one animal and it is a boar.
				expect(Boar.isDeerKind("stag", configWith(false))).to.equal(false)
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

		-- 12. THE LEAP OVER THE ROAD (task 245b) -------------------------------------------------
		--
		-- KAREN, 2026-10-22: *"they usually jump when is cross road so can we do that ?"*.
		--
		-- EVERY CASE DRIVES THE FEATURE **ON BY PARAMETER** while `Flags.DEFAULTS.DEER_ROAD_LEAP`
		-- sits at false, which is what `docs/design/feature-flags.md` section 11 asks of a flagged
		-- path: *"a flagged path must be reachable by parameter as well as by flag, or its two
		-- states cannot be tested while the flag sits at one of them"*.
		describe("the leap over the road", function()
			local ROAD = {
				halfWidthStuds = 20,
				zAt = function(_: number)
					return 0
				end,
			}
			local SINE = {
				halfWidthStuds = 20,
				zAt = function(x: number)
					return 30 * math.sin(x / 70)
				end,
			}
			local ON = { ENABLED = true, SECONDS = 0.75 }
			local OFF = { ENABLED = false, SECONDS = 0.75 }

			it("is BORN OFF, with an owner, a birthday and an expiry inside 21 days", function()
				local row = Flags.DEFAULTS.DEER_ROAD_LEAP
				expect(row).to.be.ok()
				expect(row.default).to.equal(false)
				expect(row.owner).to.equal("ServerScriptService.Boar")
				expect(row.born).to.equal("2026-10-23 task 245b")
				expect(row.expires).to.equal("2026-11-13")
				expect(#row.why > 0).to.equal(true)
			end)

			it("reads the flag at ONE boundary and passes it inward", function()
				-- `Boar.CONFIG.MODEL.LEAP.ENABLED` is the only place in the game that asks, and with
				-- the row at its default it is false -- so the shipped game draws no leap.
				expect(CONFIG.MODEL.LEAP.ENABLED).to.equal(Flags.isOn("DEER_ROAD_LEAP"))
				expect(CONFIG.MODEL.LEAP.ENABLED).to.equal(false)
			end)

			it("knows the road band, and a world without one has none", function()
				expect(Brain.onRoad(Vector3.new(0, 0, 0), ROAD)).to.equal(true)
				expect(Brain.onRoad(Vector3.new(500, 0, 19.9), ROAD)).to.equal(true)
				expect(Brain.onRoad(Vector3.new(500, 0, -19.9), ROAD)).to.equal(true)
				expect(Brain.onRoad(Vector3.new(0, 0, 20.1), ROAD)).to.equal(false)
				expect(Brain.onRoad(Vector3.new(0, 0, -20.1), ROAD)).to.equal(false)
				-- THE WHOLE FEATURE IS INERT IN A WORLD WITH NO ROAD, which is the DEV map: nil in,
				-- false out, and `leapStarts` can then never be true.
				expect(Brain.onRoad(Vector3.new(0, 0, 0), nil)).to.equal(false)
				expect(Brain.onRoad(Vector3.new(0, 0, 0), {})).to.equal(false)
				expect(Brain.onRoad(Vector3.new(0, 0, 0), { zAt = ROAD.zAt, halfWidthStuds = 0 })).to.equal(false)
			end)

			it("FOLLOWS THE SINE, which is why the road is a function and not a number", function()
				-- At x = 70 * pi / 2 the ride is at its crest, z = +30. A constant-z band would have
				-- this animal 30 studs off the lane, and would catch one that is 30 studs off it.
				local crestX = 70 * math.pi / 2
				expect(Brain.onRoad(Vector3.new(crestX, 0, 30), SINE)).to.equal(true)
				expect(Brain.onRoad(Vector3.new(crestX, 0, 0), SINE)).to.equal(false)
				expect(Brain.onRoad(Vector3.new(0, 0, 0), SINE)).to.equal(true)
			end)

			it("leaps only when it is ON the road, ARMED, RUNNING and switched ON", function()
				local runFrom = 21
				expect(Brain.leapStarts(true, true, 28, runFrom, ON)).to.equal(true)
				-- ...and each condition removed on its own.
				expect(Brain.leapStarts(false, true, 28, runFrom, ON)).to.equal(false)
				expect(Brain.leapStarts(true, false, 28, runFrom, ON)).to.equal(false)
				expect(Brain.leapStarts(true, true, 20.9, runFrom, ON)).to.equal(false)
				expect(Brain.leapStarts(true, true, 28, runFrom, OFF)).to.equal(false)
				expect(Brain.leapStarts(true, true, 28, runFrom, nil)).to.equal(false)
				-- The edge is inclusive: an animal exactly at the band edge is running.
				expect(Brain.leapStarts(true, true, 21, runFrom, ON)).to.equal(true)
			end)

			it("draws the leap above every gait and below every reaction", function()
				local config = table.clone(CONFIG)
				config.MODEL = table.clone(CONFIG.SPECIES.reddeer.MODEL)
				config.MODEL.ANIMATION_IDS = table.clone(config.MODEL.ANIMATION_IDS)
				for name in pairs(config.MODEL.CLIPS) do
					config.MODEL.ANIMATION_IDS[name] = 20000
				end
				-- `Body.clipFor` reads `hitFor` and `deadFor` without guarding them -- every call
				-- site in the game is `stepVisual`, which always has both -- so the helper fills
				-- in the resting values rather than each case repeating them.
				local function clip(info)
					info.speed = info.speed or 28
					info.clipScale = 1
					info.hitFor = info.hitFor or 0
					info.deadFor = info.deadFor or 0
					return (Boar.clipFor(info, config))
				end
				-- A running deer on the road bounds instead of galloping, at rate 1.
				expect(clip({ leaping = true })).to.equal("leap")
				local name, rate =
					Boar.clipFor({ leaping = true, speed = 28, clipScale = 1, hitFor = 0, deadFor = 0 }, config)
				expect(name).to.equal("leap")
				expect(rate).to.equal(1)
				-- ...and without the Brain's fact it gallops, which is the game as it shipped.
				expect(clip({ leaping = false })).to.equal("run")
				-- A DEATH AND A FLINCH BOTH BEAT IT: a deer shot mid-bound flinches, and one that
				-- dies mid-bound falls.
				expect(clip({ leaping = true, collapsed = true, deadFor = 0 })).to.equal("deathLeft")
				expect(clip({ leaping = true, hitFor = config.MODEL.HIT_SECONDS, speed = 0 })).to.equal("hitFront")
			end)

			it("draws NOTHING with no published leap, which is every boar", function()
				-- `Body.hasClip` is the one owner of "is there anything to play", so a world where
				-- the id is missing draws the gait it always drew -- and a BOAR has no `leap` entry
				-- in its CLIPS at all, so the branch is unreachable for one.
				expect(CONFIG.MODEL.CLIPS.leap).to.equal(nil)
				expect(Boar.hasClip("leap", CONFIG)).to.equal(false)
				local config = table.clone(CONFIG)
				config.MODEL = table.clone(CONFIG.SPECIES.reddeer.MODEL)
				config.MODEL.ANIMATION_IDS = {}
				expect(Boar.hasClip("leap", config)).to.equal(false)
				expect((Boar.clipFor({ leaping = true, speed = 28, clipScale = 1, hitFor = 0, deadFor = 0 }, config))).to.equal(
					"run"
				)
			end)

			it("has a leap clip whose length is the asset's and whose rate is never divided", function()
				local clip = CONFIG.SPECIES.reddeer.MODEL.CLIPS.leap
				expect(clip).to.be.ok()
				expect(clip.clip).to.equal("Jump_Run_IP")
				expect(clip.looped).to.equal(false)
				-- A bound is played at rate 1, so the field every gait divides by is 0 here and
				-- nothing can quietly start rating it.
				expect(clip.groundStudsPerSecond).to.equal(0)
				-- 2.0000 s, measured two ways in Play and recorded on the manifest row; only
				-- `LEAP.SECONDS` of it is played.
				expect(math.abs(clip.seconds - 2.0) < EPSILON).to.equal(true)
				expect(CONFIG.MODEL.LEAP.SECONDS < clip.seconds).to.equal(true)
			end)

			it("carries the measured sink for all three kinds, inside the clip", function()
				-- The numbers nothing reads yet (see `MODEL.LEAP.LIFT_STUDS`), pinned so the
				-- follow-up cannot start from a different measurement.
				local leap = CONFIG.MODEL.LEAP
				for _, kind in ipairs(DEER_KINDS) do
					expect(leap.LIFT_STUDS[kind] > 1).to.equal(true)
					expect(leap.LIFT_STUDS[kind] < 1.5).to.equal(true)
				end
				-- It grows as the animal gets smaller, which is the `deathLiftStuds` shape: all
				-- three play the STAG's clip and bone translations are absolute studs.
				expect(leap.LIFT_STUDS.stag < leap.LIFT_STUDS.hind).to.equal(true)
				expect(leap.LIFT_STUDS.hind < leap.LIFT_STUDS.calf).to.equal(true)
				-- The bound is inside the window that is played.
				expect(leap.LIFT_FROM_SECONDS < leap.LIFT_TO_SECONDS).to.equal(true)
				expect(leap.LIFT_TO_SECONDS <= leap.SECONDS).to.equal(true)
			end)

			it("gives the Forest Test's field a road that IS ForestTest.roadZ", function()
				local field = ForestTest.fieldFor()
				expect(field.road).to.be.ok()
				expect(field.road.halfWidthStuds).to.equal(ForestTest.SHAPE.halfWidthStuds)
				-- Not "a road exists" -- the SAME curve the map is built on, at four points across
				-- it, so a second answer to where the lane runs cannot appear.
				for _, x in ipairs({ -400, 0, 137, 2800 }) do
					expect(math.abs(field.road.zAt(x) - ForestTest.roadZ(x)) < EPSILON).to.equal(true)
				end
				-- ...and the animal's owner agrees that a point on it is on it.
				local onIt = Vector3.new(137, 0, ForestTest.roadZ(137))
				expect(Brain.onRoad(onIt, field.road)).to.equal(true)
				expect(Brain.onRoad(onIt + Vector3.new(0, 0, 25), field.road)).to.equal(false)
			end)
		end)
	end)

	-- ------------------------------------------- THE RED STAG'S OWN BEHAVIOUR (task 251 part 2)
	--
	-- KAREN, 2026-10-23, verbatim: *"we need better saound and behaviour for red stag"*, and her "ok"
	-- to the plan (`<runs-dir>/design/driveflow-spec.md` sections 3 and 4). Four things, and every one
	-- of them is a NUMBER ON A KIND ROW composed through `Boar.kindConfig`: he notices at 1.8, he
	-- checks the open at 0.90 for 2-6 s, he looks 150 degrees back at the man while he does it, and he
	-- barks once when he takes the check. The fifth -- the bound -- is dark by instruction.
	--
	-- EVERY CASE IS PURE AND EVERY ONE OF THEM ENTERS AN ARM THAT DID NOT EXIST BEFORE THIS TASK
	-- (L-093), which here means something specific: `Brain:check` reads ONE table, `self._config.MOVE`,
	-- so the per-kind difference has to arrive THERE -- and a case that only asserted the KINDS rows
	-- would pass with `edgeByKind` never called. So the composed config is what is asked.
	describe("the red stag's own behaviour (task 251 part 2)", function()
		it("notices a walking man at 108 studs, which is the hind's own radius and not a boar's", function()
			-- SPEC SECTION 3.1: 1.5 -> 1.8, *"a lone stag has no jumpy companion to trigger him, so he
			-- must be his own alarm"*. Asserted as the RADIUS and not only as the multiplier, because
			-- the multiplier is not the thing Karen sees.
			expect(CONFIG.KINDS.stag.wary.noticeScale).to.equal(1.8)
			expect(CONFIG.KINDS.stag.wary.noticeScale).to.equal(CONFIG.KINDS.hind.wary.noticeScale)
			-- SENSE IS TURNED ON BY PARAMETER rather than read off the live flag, which is this
			-- file's own discipline: `Brain.noticeRadius` answers `DETECT_RADIUS` for everything with
			-- `SENSE` off, so a case that happened to run in a flag-off world would assert the wrong
			-- number and pass.
			local on = configWith(true)
			on.SENSE = table.clone(on.SENSE)
			on.SENSE.ENABLED = true
			local stag = Boar.kindConfig("stag", on)
			local male = Boar.kindConfig("male", on)
			local walking = { id = "p", position = Vector3.new(0, 0, 0), kind = "driver", speed = 5 }
			expect(math.abs(Brain.noticeRadius(walking, stag) - 108) < 1e-6).to.equal(true)
			expect(math.abs(Brain.noticeRadius(walking, male) - 60) < 1e-6).to.equal(true)
			TestKit.note(
				string.format(
					"a walking man is noticed at %.0f studs by a stag, %.0f by a hind and %.0f by a boar",
					Brain.noticeRadius(walking, stag),
					Brain.noticeRadius(walking, Boar.kindConfig("hind", on)),
					Brain.noticeRadius(walking, male)
				)
			)
		end)

		it("checks the open likelier and longer than his hinds, and they both longer than a boar", function()
			-- SPEC SECTION 3.1, the two rows: *"a red deer reconnoitres the open; a boar marches
			-- through"* for the chance, and *"long enough that a hunter can mount the rifle"* for the
			-- length. THE COMPOSED CONFIG IS WHAT IS ASKED, because that is what `Brain:check` reads.
			local on = configWith(true)
			local stag = Boar.kindConfig("stag", on).MOVE
			local hind = Boar.kindConfig("hind", on).MOVE
			local calf = Boar.kindConfig("calf", on).MOVE
			local male = Boar.kindConfig("male", on).MOVE
			expect(stag.EDGE_CHANCE).to.equal(0.90)
			expect(hind.EDGE_CHANCE).to.equal(0.75)
			expect(stag.EDGE_MIN_SECONDS).to.equal(2.0)
			expect(stag.EDGE_MAX_SECONDS).to.equal(6.0)
			expect(hind.EDGE_MIN_SECONDS).to.equal(1.5)
			expect(hind.EDGE_MAX_SECONDS).to.equal(4.0)
			-- THE ORDER IS THE CLAIM, so a retune that crosses two of them fails here.
			expect(stag.EDGE_CHANCE > hind.EDGE_CHANCE).to.equal(true)
			expect(hind.EDGE_CHANCE > male.EDGE_CHANCE).to.equal(true)
			expect(stag.EDGE_MAX_SECONDS > hind.EDGE_MAX_SECONDS).to.equal(true)
			-- A BOAR IS UNTOUCHED, byte for byte: no boar kind carries an `edge` row, so
			-- `edgeByKind` hands back the config it was given BY REFERENCE.
			for _, kind in ipairs(BOAR_KINDS) do
				local composed = Boar.kindConfig(kind, on)
				expect(composed.MOVE.EDGE_CHANCE).to.equal(on.MOVE.EDGE_CHANCE)
				expect(composed.MOVE.EDGE_MIN_SECONDS).to.equal(on.MOVE.EDGE_MIN_SECONDS)
				expect(composed.MOVE.EDGE_MAX_SECONDS).to.equal(on.MOVE.EDGE_MAX_SECONDS)
				expect(composed.MOVE.EDGE_LOOK_BACK_DEG).to.equal(0)
				expect(composed.MOVE.EDGE_BARKS).to.equal(false)
			end
			-- THE CALF HAS NO ROW AT ALL and takes the defaults, which is the spec's *"follows her
			-- mother"*: she walks behind the hind and a follower is never offered the check.
			expect(CONFIG.KINDS.calf.edge).to.equal(nil)
			expect(calf.EDGE_CHANCE).to.equal(male.EDGE_CHANCE)
		end)

		it("lays a kind's edge row over MOVE as a DELTA and never as a replacement", function()
			-- THE LESSON `speciesConfig` PAID FOR IN TASK 240, asserted rather than commented: a world
			-- that tunes a key the row does not name must keep its own number.
			local world = configWith(true)
			world.MOVE = table.clone(world.MOVE)
			world.MOVE.EDGE_CHANCE = 0.11
			world.MOVE.WEDGE_SECONDS = 9.75
			local stag = Boar.edgeByKind(world, CONFIG.KINDS.stag.edge, CONFIG.KINDS.stag.spook).MOVE
			expect(stag.EDGE_CHANCE).to.equal(0.90) -- the row names it: the row wins
			expect(stag.WEDGE_SECONDS).to.equal(9.75) -- the row does not: the world keeps it
			-- NEITHER ROW -> THE SAME TABLE, by reference, which is what makes this free for a boar.
			expect(Boar.edgeByKind(world, nil, nil)).to.equal(world)
			-- ...AND IT NEVER WRITES THROUGH to the config it was handed.
			expect(world.MOVE.EDGE_CHANCE).to.equal(0.11)
		end)

		it("looks back at the nearest man, 150 degrees and never further", function()
			-- SPEC SECTION 3.1: *"stand looking back"*, *"150 degrees to the nearest threat"* -- *"150
			-- and not 180: a stag looks over his shoulder, he does not reverse"*.
			local travel = Vector3.new(0, 0, -1) -- walking south, toward the road
			-- THE MAN BEHIND HIM: dead astern is 180 degrees away, so the look is CLAMPED to 150 and
			-- the last 30 are what he cannot turn. That is the whole of the number.
			local behind = Brain.lookBack(travel, Vector3.new(0, 0, 1), 150)
			expect(math.abs(math.deg(math.acos(math.clamp(behind:Dot(travel), -1, 1))) - 150) < 1e-3).to.equal(true)
			-- A MAN OFF TO ONE SIDE is inside the limit, so he faces him exactly.
			local side = Brain.lookBack(travel, Vector3.new(1, 0, 0), 150)
			expect(math.abs(side:Dot(Vector3.new(1, 0, 0)) - 1) < 1e-6).to.equal(true)
			-- THE Y IS IGNORED: a man up a high seat is a man in the same direction.
			local high = Brain.lookBack(travel, Vector3.new(1, 40, 0), 150)
			expect(math.abs(high:Dot(side) - 1) < 1e-6).to.equal(true)
			-- EVERY WAY OUT ANSWERS "THE WAY YOU ARE GOING", which is what every boar in the game
			-- gets and is the behaviour task 126 shipped: no man, no angle, a zero angle, a
			-- degenerate direction.
			expect(Brain.lookBack(travel, nil, 150)).to.equal(travel)
			expect(Brain.lookBack(travel, Vector3.new(0, 0, 1), 0)).to.equal(travel)
			expect(Brain.lookBack(travel, Vector3.new(0, 0, 1), nil)).to.equal(travel)
			expect(Brain.lookBack(travel, Vector3.zero, 150)).to.equal(travel)
		end)

		it("barks when he takes the check, and a calf never does", function()
			-- SPEC SECTION 4.2: the alarm bark plays *"once, at the edge-check"* -- *"the sound that
			-- tells the player he has been seen"*. `Runtime:check` is the one caller and
			-- `MOVE.EDGE_BARKS` the one switch; what is asserted here is the SWITCH and the SAMPLE,
			-- because nobody in this toolchain can hear a Sound.
			local on = configWith(true)
			expect(Boar.kindConfig("stag", on).MOVE.EDGE_BARKS).to.equal(true)
			expect(Boar.kindConfig("hind", on).MOVE.EDGE_BARKS).to.equal(true)
			expect(Boar.kindConfig("calf", on).MOVE.EDGE_BARKS).to.equal(false)
			-- IT IS THE ANIMAL'S OWN `cry` ROW AND NOT A NEW CUE, which is why no id is added: task
			-- 240 chose the stag's `cry` samples expressly AS the warning bark. So the bark a player
			-- hears is the voice row, and `deer.spec`'s own "no deer cue shares an id with a boar
			-- cue" case already covers what it is.
			local voice = CONFIG.SOUND.VOICE
			expect(#voice.stag.cry >= 1).to.equal(true)
			expect(#voice.hind.cry >= 1).to.equal(true)
			-- ...AND IT IS BOUNDED BY THE WORLD'S VOICE RATION, so two barking deer cannot be three
			-- voices: `CROWD.MAX_SQUEALS` is what `Runtime:check` claims against.
			expect(CONFIG.SOUND.CROWD.MAX_SQUEALS >= 1).to.equal(true)
		end)

		it("bounds when spooked from a stand-still, and it is DARK by instruction", function()
			-- THE DIRECTOR'S DISPATCH, 2026-10-24: *"HOLD the bound when spooked until 245c (the hoof
			-- sink) is fixed, behind a flag born off"*. So the row is off and every case below drives
			-- the feature ON BY PARAMETER, which is what section 11 of the flag design asks.
			local row = Flags.DEFAULTS.STAG_BOUND_ON_SPOOK
			expect(row).to.be.ok()
			expect(row.default).to.equal(false)
			expect(row.owner).to.equal("ServerScriptService.Boar")
			expect(row.born).to.equal("2026-10-24 task 251 part 2")
			expect(row.expires).to.equal("2026-11-14")
			expect(#row.why > 0).to.equal(true)
			-- ONE BOUNDARY, AND IT IS THE STAG'S OWN KIND ROW. With the row at its default this is
			-- false, so no animal in the shipped game bounds -- and `MOVE`'s own default is false
			-- too, so a world that forgot the kind row would not bound either.
			expect(CONFIG.KINDS.stag.spook.bound).to.equal(Flags.isOn("STAG_BOUND_ON_SPOOK"))
			expect(CONFIG.KINDS.stag.spook.bound).to.equal(false)
			expect(CONFIG.MOVE.BOUND_ON_SPOOK).to.equal(false)
			local on = configWith(true)
			for _, kind in ipairs({ "male", "female", "cub", "legendary", "hind", "calf" }) do
				expect(Boar.kindConfig(kind, on).MOVE.BOUND_ON_SPOOK).to.equal(false)
			end
			-- THE RULE, each condition on its own. `ON`/`OFF` are the leap tables this block already
			-- defines for the road leap, because the bound IS that clip.
			local LEAP_ON = { ENABLED = true, SECONDS = 0.75 }
			local LEAP_OFF = { ENABLED = false, SECONDS = 0.75 }
			local from = CONFIG.MOVE.BOUND_FROM_SPEED
			expect(from).to.equal(6)
			expect(Brain.boundStarts(true, 0, from, LEAP_ON)).to.equal(true)
			expect(Brain.boundStarts(true, 4.5, from, LEAP_ON)).to.equal(true) -- a walk
			expect(Brain.boundStarts(true, 6, from, LEAP_ON)).to.equal(true) -- the edge is inclusive
			-- ...AND EVERY WAY IT DOES NOT HAPPEN.
			expect(Brain.boundStarts(true, 6.1, from, LEAP_ON)).to.equal(false) -- already trotting on
			expect(Brain.boundStarts(true, 28, from, LEAP_ON)).to.equal(false) -- *"a running stag just runs"*
			expect(Brain.boundStarts(false, 0, from, LEAP_ON)).to.equal(false) -- the kind does not bound
			expect(Brain.boundStarts(nil, 0, from, LEAP_ON)).to.equal(false)
			expect(Brain.boundStarts(true, 0, from, LEAP_OFF)).to.equal(false) -- no road leap, no bound
			expect(Brain.boundStarts(true, 0, from, nil)).to.equal(false)
			expect(Brain.boundStarts(true, 0, 0, LEAP_ON)).to.equal(false) -- no threshold, no bound
			expect(Brain.boundStarts(true, 0, from, { ENABLED = true, SECONDS = 0 })).to.equal(false)
		end)
	end)

	-- ------------------------------------------- THE STAG GETS THROUGH THE WOOD (task 249)
	--
	-- KAREN, 2026-10-23: *"I can see redtag is stucking when walking in mountain,tree ect check
	-- that"*. MEASURED in her own place first, 150 s of a real drive sampled four times a second,
	-- "stuck" being *its `Mover` is asking for movement and the body is under 0.8 studs/s*:
	-- **stag 73 of 337 samples (21.7 %)** against cub 4.2 %, female 4.2 %, calf 3.1 %, hind 2.2 %,
	-- male 0.0 %. One animal, five to ten times the rest.
	--
	-- AND THE STAG IS THE ONE ANIMAL WHOSE AVOIDANCE IS PLANNED AT A WIDTH IT HAS NOT GOT:
	-- `Boar.avoidRadius` reads `drawnWidthStuds`, and only the stag's (3.47, his ANTLERS) is wider
	-- than his collision box.
	describe("the stag in close wood (task 249)", function()
		it("plans at the antlers but is allowed through at the body", function()
			local deer = Boar.speciesConfig("stag", Boar.CONFIG)
			local wide = Boar.avoidRadius("stag", deer)
			local body = Boar.bodyAvoidRadius(deer)
			-- THE WIDE ONE IS TASK 240'S AND IS UNCHANGED: the antler span, halved, plus the
			-- clearance every animal keeps.
			expect(wide > body).to.equal(true)
			expect(
				math.abs(wide - (Boar.CONFIG.KINDS.stag.drawnWidthStuds / 2 + deer.MOVE.AVOID_CLEARANCE_STUDS)) < 1e-6
			).to.equal(true)
			-- ...AND THE NARROW ONE IS THE BOX HE ACTUALLY COLLIDES AT, under the same floor.
			expect(body >= deer.MOVE.AVOID_RADIUS_STUDS).to.equal(true)
			expect(body >= deer.BODY_SIZE.X / 2 + deer.MOVE.AVOID_CLEARANCE_STUDS).to.equal(true)
		end)

		it("changes nothing measurable for any animal but the stag", function()
			-- THE WHOLE BLAST RADIUS OF THE FIX, AS AN ASSERTION. The fallback can only ever run
			-- when `bodyAvoidRadius` is SMALLER than `avoidRadius`, and the gap is what it buys.
			--
			-- FOR EVERY BOAR KIND THE TWO ARE THE SAME NUMBER -- none of them is drawn wider than
			-- its 2.0-stud box -- so each reaches exactly the code it reached before task 249.
			for _, kind in ipairs({ "male", "female", "cub", "legendary" }) do
				local cfg = Boar.speciesConfig(kind, Boar.CONFIG)
				expect(Boar.avoidRadius(kind, cfg)).to.equal(Boar.bodyAvoidRadius(cfg))
			end
			-- THE HIND AND THE CALF ARE NOT EXACTLY EQUAL AND THAT WAS MEASURED RATHER THAN
			-- ASSUMED: the hind's drawn width is 2.01 against the deer box's 2.00, so her wide
			-- radius is 1.605 and her narrow one 1.600 -- **five thousandths of a stud**. The
			-- fallback is reachable for her in principle and can buy her nothing in practice: no
			-- corridor in any wood is 0.01 studs wide. The stag's gap is 0.735, a hundred and
			-- forty times hers, which is the whole point.
			local deer = Boar.speciesConfig("hind", Boar.CONFIG)
			local narrow = Boar.bodyAvoidRadius(deer)
			expect(Boar.avoidRadius("hind", deer) - narrow < 0.01).to.equal(true)
			expect(Boar.avoidRadius("calf", deer) <= narrow).to.equal(true)
			local stagCfg = Boar.speciesConfig("stag", Boar.CONFIG)
			expect(Boar.avoidRadius("stag", stagCfg) - Boar.bodyAvoidRadius(stagCfg) > 0.7).to.equal(true)
		end)
	end)
end

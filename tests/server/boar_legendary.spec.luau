-- boar_legendary.spec: THE LEGENDARY BOAR (task 219) -- one rare, bigger, tougher, warier animal per
-- drive. Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- Karen, 2026-10-10: *"Legendary animals: one or a few, e.g. a legendary boar"*, and 2026-10-11:
-- *"legendary animals worth more"*. Task 160 wrote the price with no animal behind it; this is the
-- animal.
--
-- MOSTLY PURE, deliberately. Everything about WHO the animal is, HOW tough it is and WHETHER a drive
-- has one is a pure function driven with its own config -- which is the only way both flag states are
-- reachable while `BOAR_MODEL` sits at one of them, and the only way "one in four drives" is a case
-- rather than a probability somebody has to play for an hour to see. The two cases that are not pure
-- are the two that cannot be: the per-drive CAP (which is runtime state across several releases) and
-- the forcing switch's own guard.
--
-- Note: docs/research/2026-10-20-legendary-boar.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Match = require(ServerScriptService:WaitForChild("Match"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Wound = Boar.Wound
local CONFIG = Boar.CONFIG
local WOUND = CONFIG.WOUND

local EPSILON = 1e-4
local FIELD = {
	bounds = { minX = -200, maxX = 200, minZ = -200, maxZ = 200 },
	exitZ = -190,
	groundY = 0,
}

-- THE FLAG AS A PARAMETER, which is the one permitted shape (`boar_kinds.spec`'s own helper): a
-- harness run only ever sees `BOAR_MODEL`'s OFF default, because `test` refuses to start with an
-- override set. `chance` is the drive roll, and 0 and 1 are EXACT -- `NextNumber` returns [0, 1) --
-- so a case never depends on a draw.
local function configWith(on: boolean, chance: number?)
	local rare = table.clone(CONFIG.KINDS.LEGENDARY)
	if chance ~= nil then
		rare.CHANCE_PER_DRIVE = chance
	end
	local kinds = table.clone(CONFIG.KINDS)
	kinds.ENABLED = on
	kinds.LEGENDARY = rare
	local config = table.clone(CONFIG)
	config.KINDS = kinds
	return config
end

return function()
	describe("the legendary boar: who it is", function()
		local on = configWith(true)
		local off = configWith(false)

		it("is the male's own asset at 1.35, every box and the drawn rig", function()
			-- KAREN ASKED FOR *"clearly bigger"* AND THE BRIEF SAID ~1.3-1.4x THE MALE, measured off
			-- his bounds. 1.35 is the middle of that, and this game's rule since task 119 is "one
			-- scale, EVERY box" -- so the trunk and all four hit zones are his times 1.35 and the
			-- animal is a big target in exactly the way it looks big.
			local legend = Boar.kindGeometry("legendary", on)
			local male = Boar.kindGeometry("male", on)
			expect(math.abs(legend.scale - 1.35) < EPSILON).to.equal(true)
			expect((legend.bodySize - male.bodySize * 1.35).Magnitude < EPSILON).to.equal(true)
			for _, zone in ipairs(CONFIG.ZONES.ORDER) do
				expect((legend.zones[zone].size - male.zones[zone].size * 1.35).Magnitude < EPSILON).to.equal(true)
				expect((legend.zones[zone].offset - male.zones[zone].offset * 1.35).Magnitude < EPSILON).to.equal(true)
			end

			-- NO UPLOAD AND NO NEW ASSET ID: it asks for the MALE's template. That is what the row's
			-- `model` field is for, and `Runtime:_modelTemplate` is what reads it.
			expect(legend.model).to.equal("male")
			expect(legend.model).to.equal(male.model)

			-- AND THE DRAWN RIG IS SCALED AT RUNTIME, which is `meshScale` -- 1 for every kind whose
			-- scale is BAKED into its own upload by `tools/boar_prep.py`. MEASURED in the DEV place
			-- (`Model:ScaleTo(1.35)` moved the lowest bone -1.6264 -> -2.1957, exactly 1.3500, where
			-- `MeshPart.Size` left it at -1.6264); the derivation is in `Boar.CONFIG.KINDS`.
			expect(math.abs(legend.meshScale - 1.35) < EPSILON).to.equal(true)
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.kindGeometry(kind, on).meshScale).to.equal(1)
			end
			TestKit.note(
				string.format(
					"boar-legendary: the trophy is %.2f studs long against the male's %.2f, on his own asset",
					legend.bodySize.Z,
					male.bodySize.Z
				)
			)
		end)

		it("carries a coat tint, and no other animal does", function()
			-- THE COAT IS MULTIPLIED on the `SurfaceAppearance` the bought asset already carries --
			-- measured: it has exactly one, and its `Color` reads (1, 1, 1). A `MeshPart.Color` write
			-- would have been ignored, which is a no-op nobody could explain, so the tint travels
			-- with the geometry and `Body.attachVisual` writes it on that property.
			expect(Boar.kindGeometry("legendary", on).tint).to.be.ok()
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.kindGeometry(kind, on).tint).to.equal(nil)
			end
			-- IT IS DARKER THAN THE GREY BOX'S OWN COLOUR, which is the whole ask (*"darker,
			-- grizzled"*): a tint that was not darker would be a number nobody could see.
			local tint = Boar.kindGeometry("legendary", on).tint :: Color3
			local box = CONFIG.BODY_COLOR
			expect(tint.R < box.R and tint.G < box.G and tint.B < box.B).to.equal(true)
		end)

		it("plays the male's clips at the male's stride times 1.35, inside its own rate rails", function()
			-- MEASURED IN A PLAY SESSION, on the published walk clip, with 41 samples across it: the
			-- scaled rig's `hoof_f.L` travels 2.2152 studs against the male's 1.6409 -- 1.3500, the
			-- same ratio as the bones. So a scaled model's Animator DOES scale the clip's absolute
			-- translations, `clipScale` is 1.35, and the gait bands scale with the stride.
			local bands = Boar.gaitBands(Boar.kindRow("legendary", on).clipScale, on)
			expect(math.abs(bands.scale - 1.35) < EPSILON).to.equal(true)
			expect(math.abs(bands.runFrom - CONFIG.MODEL.RUN_FROM * 1.35) < EPSILON).to.equal(true)

			-- ...AND THE CEILING DID NOT GO DOWN WITH IT. `MAX_RATE / clipScale` is only safe below
			-- 1: the worst ask is the TROT clip at the top of its own band, which is
			-- `RUN_FROM * s / (10.244 * s)` = 2.733 for EVERY s -- so at 1.35 the old formula gave
			-- 2.074 against an ask of 2.733, a third of the animal's feet sliding. This is the case
			-- that pins `math.min(scale, 1)`.
			local worstAsk = CONFIG.MODEL.RUN_FROM / CONFIG.MODEL.CLIPS.trot.groundStudsPerSecond
			expect(math.abs(bands.maxRate - CONFIG.MODEL.MAX_RATE) < 1e-9).to.equal(true)
			expect(bands.maxRate > worstAsk).to.equal(true)
			expect(CONFIG.MODEL.MAX_RATE / 1.35 < worstAsk).to.equal(true) -- what it WOULD have been

			-- EVERY SMALLER KIND IS EXACTLY AS IT WAS, which is what makes this a widening and not a
			-- change: the cub's rail is still the male's cadence in the cub's own units.
			expect(math.abs(Boar.gaitBands(1, on).maxRate - CONFIG.MODEL.MAX_RATE) < 1e-9).to.equal(true)
			expect(
				math.abs(Boar.gaitBands(CONFIG.KINDS.cub.clipScale, on).maxRate - CONFIG.MODEL.MAX_RATE / 0.4372) < 1e-3
			).to.equal(true)

			-- ...AND ITS CARCASS NEEDS NO LIFT, measured on the same rig: the death clip held at
			-- `length - HOLD_EPSILON` leaves the lowest bone +0.0030 above the box's bottom plane,
			-- against the male's own +0.0022. It IS the male's rig, so it is the male's row.
			expect(Boar.kindGeometry("legendary", on).deathLift).to.equal(0)
		end)

		it("with the FLAG off there is no fourth animal at all", function()
			-- The flag gates the whole block, so the grey-box world Milestone 1.2 shipped is
			-- untouched -- kinds, the trophy, the tint and the armour alike.
			local geometry = Boar.kindGeometry("legendary", off)
			expect((geometry.bodySize - CONFIG.BODY_SIZE).Magnitude < EPSILON).to.equal(true)
			expect(geometry.scale).to.equal(1)
			expect(geometry.meshScale).to.equal(1)
			expect(geometry.tint).to.equal(nil)
			expect(Boar.toughnessFor("legendary", off)).to.equal(nil)
			expect(Boar.wantsLegendary(0, off)).to.equal(false)
			expect(Boar.kindConfig("legendary", off)).to.equal(off) -- the identity, table and all
		end)
	end)

	describe("the legendary boar: how rare it is", function()
		local always = configWith(true, 1)
		local never = configWith(true, 0)

		it("rolls once per drive, and 0 and 1 are exact", function()
			-- `NextNumber` returns [0, 1), so `roll < 0` is never and `roll < 1` is always -- which is
			-- what lets every other case in this file be driven with no randomness.
			expect(Boar.wantsLegendary(0, always)).to.equal(true)
			expect(Boar.wantsLegendary(0.999999, always)).to.equal(true)
			expect(Boar.wantsLegendary(0, never)).to.equal(false)
			-- ...and the shipped number is the one the note argues for: one drive in four.
			expect(CONFIG.KINDS.LEGENDARY.CHANCE_PER_DRIVE).to.equal(0.25)
			expect(Boar.wantsLegendary(0.24, configWith(true))).to.equal(true)
			expect(Boar.wantsLegendary(0.26, configWith(true))).to.equal(false)
		end)

		it("promotes exactly ONE male, and nobody in a nursery", function()
			-- A LEGENDARY IS A MATURE LONE BOAR: `SOUNDER.MAKEUP.LONE` is already "male" and
			-- `COMPOSITIONS` row 6 is *"a lone big male"*. So the promotion takes the FIRST male and
			-- no one else -- never a sow, never a piglet.
			local herd = { "female", "cub", "male", "male", "cub" }
			local promoted, index = Boar.promoteLegendary(herd, true, always)
			expect(index).to.equal(3)
			expect(promoted[3]).to.equal("legendary")
			-- EXACTLY ONE: the second male is still a male. "At most one per drive" starts here, in
			-- the shape of the function, rather than in a counter two code paths could disagree on.
			local count = 0
			for _, kind in ipairs(promoted) do
				if kind == "legendary" then
					count += 1
				end
			end
			expect(count).to.equal(1)
			expect(promoted[4]).to.equal("male")
			-- ...AND IT NEVER MUTATES ITS INPUT, so a caller can compare before with after.
			expect(herd[3]).to.equal("male")

			-- A RELEASE OF SOWS AND PIGLETS PROMOTES NOBODY, and the permission is therefore NOT
			-- spent -- which is what lets the next release of the same drive carry the trophy.
			local nursery, none = Boar.promoteLegendary({ "female", "cub", "cub" }, true, always)
			expect(none).to.equal(nil)
			expect(table.concat(nursery, ",")).to.equal("female,cub,cub")

			-- AND WITHOUT THE PERMISSION NOTHING HAPPENS AT ALL.
			local untouched, refused = Boar.promoteLegendary(herd, false, always)
			expect(refused).to.equal(nil)
			expect(table.concat(untouched, ",")).to.equal(table.concat(herd, ","))
		end)

		it("puts AT MOST ONE in a drive however many releases it has, and a new drive gets a new one", function()
			-- THE CAP, LIVE, because it is the one thing in this task that is runtime state rather
			-- than a pure function: four releases of a drive whose chance is 1, and exactly one
			-- animal in the world is the trophy. `clear` is the drive boundary -- `Match` calls it at
			-- every drive's end -- so the next drive rolls again and may have its own.
			local holder = Instance.new("Folder")
			holder.Name = "BoarLegendarySpec"
			holder.Parent = ServerStorage
			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "Trophy",
				rng = Random.new(219),
				-- `KINDS` is merged KEY BY KEY by `newRuntime`, so `LEGENDARY` has to arrive whole or
				-- its other two fields would be lost.
				config = { KINDS = { ENABLED = true, LEGENDARY = always.KINDS.LEGENDARY }, maxBoars = 8 },
				threats = function()
					return {}
				end,
			})

			local function trophies(): number
				local found = 0
				for _, handle in ipairs(runtime:boars()) do
					if handle.kind == "legendary" then
						found += 1
					end
				end
				return found
			end

			-- FOUR LONE MALES, which is the release most likely to be the trophy AND the path that
			-- returns early -- the one this task got wrong first.
			for _ = 1, 4 do
				runtime:spawnSounder(Vector3.new(0, FIELD.groundY, 0), 1, nil, { males = 1 })
			end
			expect(#runtime:boars()).to.equal(4)
			expect(trophies()).to.equal(1)
			expect(runtime:stats().legendariesSpawned).to.equal(1)

			-- ...AND A SOUNDER RELEASE AFTERWARDS ADDS NO SECOND ONE.
			runtime:spawnSounder(Vector3.new(30, FIELD.groundY, 30), 3, nil, { males = 3 })
			expect(trophies()).to.equal(1)

			-- THE DRIVE ENDS. Everything is despawned and the permission comes back, so the next
			-- drive can have its own -- and with the chance at 1 it does.
			runtime:clear("driveOver")
			expect(#runtime:boars()).to.equal(0)
			runtime:spawnSounder(Vector3.new(0, FIELD.groundY, 0), 1, nil, { males = 1 })
			expect(trophies()).to.equal(1)
			expect(runtime:stats().legendariesSpawned).to.equal(2)
			TestKit.note(
				"boar-legendary: 4 lone releases in one drive produced exactly 1 trophy; the next drive got its own"
			)

			runtime:destroy()
			holder:Destroy()
		end)

		it("puts NONE in a drive whose roll said no", function()
			local holder = Instance.new("Folder")
			holder.Name = "BoarLegendaryNoneSpec"
			holder.Parent = ServerStorage
			local runtime = Boar.newRuntime({
				field = FIELD,
				parent = holder,
				folderName = "NoTrophy",
				rng = Random.new(219),
				config = { KINDS = { ENABLED = true, LEGENDARY = never.KINDS.LEGENDARY }, maxBoars = 8 },
				threats = function()
					return {}
				end,
			})
			for _ = 1, 4 do
				runtime:spawnSounder(Vector3.new(0, FIELD.groundY, 0), 1, nil, { males = 1 })
			end
			for _, handle in ipairs(runtime:boars()) do
				expect(handle.kind).to.equal("male")
			end
			expect(runtime:stats().legendariesSpawned).to.equal(0)
			runtime:destroy()
			holder:Destroy()
		end)

		it("leaves the Director's forcing switch OFF, and fails the harness if it is not", function()
			-- THE GUARD THE HARNESS CANNOT GIVE US. `tools/studio_mcp.py` refuses to start while a
			-- `DHFlag_*` override is set; this switch is deliberately not one of those, so a run with
			-- it left on would silently change what every drive spawns. This case is that guard: it
			-- is inside the gate that already exists, and it says how to clear it.
			local name = CONFIG.KINDS.LEGENDARY.FORCE_ATTRIBUTE
			expect(type(name)).to.equal("string")
			local set = ServerStorage:GetAttribute(name)
			if set ~= nil then
				TestKit.note(
					string.format(
						'boar-legendary: the forcing switch is STILL SET. Clear it: ServerStorage:SetAttribute("%s", nil)',
						name
					)
				)
			end
			expect(set).to.equal(nil)
		end)
	end)

	describe("the legendary boar: harder to kill, and where", function()
		local on = configWith(true)

		it("is armoured everywhere but the vitals", function()
			-- THE DJV'S `Schild`: an old keiler carries centimetres of hardened tissue over the
			-- shoulders and flanks, and his skull and his chamber are no harder than a young boar's.
			-- So the armour is per-CLASS, and `WOUND.CLASS` is what already says which is which.
			local toughness = Boar.toughnessFor("legendary", on)
			expect(toughness).to.equal(2)
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.toughnessFor(kind, on)).to.equal(nil)
			end

			-- A VITAL ZONE TAKES FULL DAMAGE, which is the half that makes the rule Karen's
			-- *"only head/chest zones kill"* rather than "it takes four slugs anywhere".
			for _, zone in ipairs({ "head", "chest" }) do
				expect(Wound.hitClass(zone, WOUND)).to.equal("vital")
				expect(Wound.damageFor(zone, "Slug", 1, WOUND, toughness)).to.equal(
					Wound.damageFor(zone, "Slug", 1, WOUND)
				)
			end
			-- EVERYTHING ELSE IS HALVED.
			for _, zone in ipairs({ "body", "legs", "rear" }) do
				expect(Wound.hitClass(zone, WOUND) ~= "vital").to.equal(true)
				expect(Wound.damageFor(zone, "Slug", 1, WOUND, toughness)).to.equal(
					Wound.damageFor(zone, "Slug", 1, WOUND) / 2
				)
			end
			-- AND `nil` IS EVERY ANIMAL BEFORE THIS TASK: the arithmetic is untouched.
			expect(Wound.damageFor("body", "Slug", 1, WOUND, nil)).to.equal(WOUND.DAMAGE.body.Slug)
			expect(Wound.damageFor("body", "Pellet", 5, WOUND, 1)).to.equal(WOUND.DAMAGE.body.Pellet * 5)
		end)

		it("dies to the chamber or the head and shrugs off a body shot, which a male does not", function()
			-- THE WHOLE TABLE FROM THE RESEARCH NOTE, driven through `Wound.apply` rather than
			-- through `damageFor`, so it is the severity a player would actually see.
			local toughness = Boar.toughnessFor("legendary", on)
			local function shoot(zone: string, ammo: string, pellets: number, armour: number?)
				local state = Wound.new()
				local severity
				for _ = 1, pellets do
					state, severity = Wound.apply(state, { zone = zone, ammo = ammo, pellets = 1 }, WOUND, armour)
				end
				return severity, state
			end

			-- ONE SLUG IN THE VITALS STILL KILLS IT OUTRIGHT -- the same word a male gets.
			expect((shoot("head", "Slug", 1, toughness))).to.equal("lethal")
			expect((shoot("chest", "Slug", 1, toughness))).to.equal("lethal")
			expect((shoot("head", "Pellet", 3, toughness))).to.equal("lethal")

			-- A BODY SLUG DROPS A MALE AND ONLY GRAZES THE TROPHY. This is the pair the rule is
			-- about, and it is asserted as a PAIR so the change cannot be read as "it got tougher
			-- everywhere".
			expect((shoot("body", "Slug", 1, nil))).to.equal("mortal")
			expect((shoot("body", "Slug", 1, toughness))).to.equal("grazed")
			expect((shoot("body", "Slug", 2, toughness))).to.equal("mortal")

			-- A RUMP SLUG CRIPPLES A MALE (*"the back end goes"*) and does not cripple this one.
			expect((shoot("rear", "Slug", 1, nil))).to.equal("mortal")
			expect((shoot("rear", "Slug", 1, toughness))).to.equal("grazed")

			-- FIVE BUCKSHOT PELLETS IN THE BODY are mortal on a male and it takes ten here.
			expect((shoot("body", "Pellet", 5, nil))).to.equal("mortal")
			expect((shoot("body", "Pellet", 5, toughness))).to.equal("grazed")
			expect((shoot("body", "Pellet", 10, toughness))).to.equal("mortal")

			-- ...AND THE FLIGHT IS NOT CHANGED, which is why the thresholds were NOT scaled instead:
			-- two body slugs put it exactly where one puts a male, so the taper
			-- `Wound.flightStuds` applies across `MORTAL..LETHAL` reads the same.
			local _, trophy = shoot("body", "Slug", 2, toughness)
			local _, male = shoot("body", "Slug", 1, nil)
			expect(math.abs(trophy.flightStuds - male.flightStuds) < EPSILON).to.equal(true)
			TestKit.note(
				string.format(
					"boar-legendary: a body slug is mortal on a male and a graze on the trophy; two of them run it %.0f studs, same as one on a male",
					trophy.flightStuds
				)
			)
		end)
	end)

	describe("the legendary boar: wary", function()
		local on = configWith(true)

		it("notices further out and runs faster, and no other animal moved", function()
			local config = Boar.kindConfig("legendary", on)
			local wary = CONFIG.KINDS.legendary.wary

			-- EVERY RADIUS AT WHICH A PERSON MATTERS MOVES TOGETHER. Scaling one and not the others
			-- would put the calm radius inside the flee radius, which is a state that flickers.
			expect(math.abs(config.DETECT_RADIUS - CONFIG.DETECT_RADIUS * wary.noticeScale) < EPSILON).to.equal(true)
			expect(math.abs(config.CALM_RADIUS - CONFIG.CALM_RADIUS * wary.noticeScale) < EPSILON).to.equal(true)
			expect(config.CALM_RADIUS > config.DETECT_RADIUS).to.equal(true)
			for _, key in ipairs({ "NOTICE_MOVING", "NOTICE_STANDING", "FLUSH_STUDS", "CALM_MARGIN" }) do
				expect(math.abs(config.SENSE[key] - CONFIG.SENSE[key] * wary.noticeScale) < EPSILON).to.equal(true)
			end
			expect(math.abs(config.SPRINT_SPEED - CONFIG.SPRINT_SPEED * wary.runScale) < EPSILON).to.equal(true)

			-- THE BRAIN'S OWN TWO READERS ANSWER THE BIGGER NUMBERS, which is the point of doing this
			-- as a config rather than as a branch: `Brain.noticeRadius` and `Brain.fleeRadius` are
			-- unchanged code reading changed numbers.
			local walker = { position = Vector3.zero, speed = CONFIG.SENSE.MOVING_SPEED + 1 }
			expect(Boar.Brain.noticeRadius(walker, config) > Boar.Brain.noticeRadius(walker, on)).to.equal(true)
			expect(Boar.Brain.fleeRadius(walker, config) > Boar.Brain.fleeRadius(walker, on)).to.equal(true)
			TestKit.note(
				string.format(
					"boar-legendary: it notices a walking man at %.0f studs against %.0f, and runs at %.1f against %.1f",
					Boar.Brain.noticeRadius(walker, config),
					Boar.Brain.noticeRadius(walker, on),
					config.SPRINT_SPEED,
					on.SPRINT_SPEED
				)
			)

			-- ...AND FOR EVERY OTHER ANIMAL `kindConfig` IS THE IDENTITY FUNCTION -- the config TABLE
			-- itself, not a copy. That is what makes "nothing else moved" structural: there is no
			-- second table that could drift.
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.kindConfig(kind, on)).to.equal(on)
			end
			expect(Boar.kindConfig(nil, on)).to.equal(on)
			expect(Boar.kindConfig("wildebeest", on)).to.equal(on)

			-- IT IS STILL INSIDE ITS OWN RATE RAIL at the speed it can now reach, which is the other
			-- half of `runScale` being 1.12 and not 2: the run clip at 42.6 studs/s asks 1.83 of a
			-- ceiling of 2.8.
			local bands = Boar.gaitBands(CONFIG.KINDS.legendary.clipScale, on)
			local asked = config.SPRINT_SPEED / (CONFIG.MODEL.CLIPS.run.groundStudsPerSecond * bands.scale)
			expect(asked < bands.maxRate).to.equal(true)
			expect(asked > bands.minRate).to.equal(true)
		end)
	end)

	describe("the legendary boar: what it is worth, and what the screens are told", function()
		it("carries kind = legendary on the kill record", function()
			-- THE ONE FIELD EVERY SCREEN AND THE WHOLE PRICE DEPEND ON. `Wound.killRecord` has
			-- carried `kind` since task 120 (*"WHICH ANIMAL DIED"*), and this is the case that says a
			-- legendary arrives on it -- the hit card, the TAB report and `Score.kill` all read it.
			local state = Wound.apply(Wound.new(), {
				zone = "chest",
				ammo = "Slug",
				pellets = 1,
				shooterUserId = 4219,
				shooterName = "Karen",
			}, WOUND, Boar.toughnessFor("legendary", configWith(true)))
			local record = Wound.killRecord(state, "Boar1", Vector3.zero, 12, WOUND, "legendary")
			expect(record.kind).to.equal("legendary")
			expect(record.killedByUserId).to.equal(4219)
			expect(record.instant).to.equal(true) -- a chest slug is still a chest slug
		end)

		it("is worth 25 points and 2.5 males, through the table task 160 already wrote", function()
			-- **THE NUMBER DID NOT MOVE.** It was Karen's (*"first place ofc more legendary more
			-- ect"*) and it has been in `Match.CONFIG.POINTS.KIND` since task 160 with nothing behind
			-- it. What this task added is an animal that can claim it, so this case reads the price
			-- through `Match.Score.kill` -- the function the drive actually scores with -- rather
			-- than reading the constant twice.
			local points = Match.CONFIG.POINTS
			expect(points.KIND.legendary).to.equal(25)
			expect(points.KIND.legendary).to.equal(points.KIND.male * 2.5)

			local board = Match.Score.new()
			board = Match.Score.join(board, 4219, "Karen", "Shooters")
			local awards
			board, awards = Match.Score.kill(board, {
				kind = "legendary",
				killedByUserId = 4219,
				killingZone = "chest",
			}, nil, Match.CONFIG)
			expect(board.rows[4219].points).to.equal(25)
			expect(board.rows[4219].kills).to.equal(1)
			-- THE AWARD SAYS WHICH ANIMAL IT WAS PAID FOR, which is how a kind typo is told from a
			-- real kind: a legendary is `kill-legendary` and never `kill-unknown`.
			expect(#awards).to.equal(1)
			expect(awards[1].reason).to.equal("kill-legendary")
			-- ...and a male beside it, so the LADDER is asserted and not just the number.
			board = Match.Score.kill(board, { kind = "male", killedByUserId = 4219 }, nil, Match.CONFIG)
			expect(board.rows[4219].points).to.equal(35)
			TestKit.note("boar-legendary: one trophy and one male score 25 + 10 = 35 points, as kill-legendary")
		end)

		it("is named on every screen that names an animal, and is one of the species' kinds", function()
			-- L-093's lesson, applied: every place a `kind` is READ gets a case that actually enters
			-- the legendary arm, not just the data table.
			local Report = require(ReplicatedStorage:WaitForChild("Report"))
			local Drive = require(ReplicatedStorage:WaitForChild("Drive"))

			-- 1. THE TAB REPORT'S ANIMAL COLUMN. `Report.kindWord` returns an unknown kind as it
			--    came, so this needed no mapping -- but it needs a case, because "no change was
			--    needed" is a claim about behaviour and not about a diff.
			expect(Report.kindWord("legendary")).to.equal("legendary")
			expect(string.upper(Report.kindWord("legendary"))).to.equal("LEGENDARY")

			-- 2. THE HIT CARD'S PLATE TAG, and nothing else gets one.
			expect(Report.trophyWord("legendary")).to.equal("LEGENDARY BOAR")
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Report.trophyWord(kind)).to.equal(nil)
			end
			expect(Report.trophyWord(nil)).to.equal(nil)

			-- 3. THE PICTURE. It is the male's silhouette at full size, which is honest about being
			--    the same drawing -- the same answer the sow gives a piglet.
			expect(Report.boarImage("legendary").id).to.equal(Report.boarImage("male").id)
			expect(Report.boarImage("legendary").scale).to.equal(1)

			-- 4. THE START CARD DOES **NOT** NAME IT, and that is asserted rather than left to
			--    chance -- because the failure would be invisible: the card's row cap is 4 and its
			--    height is a fixed number, so a fourth quarry kind would push the PERSON row (the
			--    Designer's own addition) off the card and nothing would error. The reason lives on
			--    `Match.CONFIG.QUARRY`; this is the case that holds it in place.
			expect(Drive.CONFIG.START_CARD_QUARRY_WORDS.legendary).to.equal(nil)
			expect(Drive.CONFIG.START_CARD_ROWS_MAX).to.equal(4)
			local quarryKinds = 0
			for _, row in ipairs(Match.CONFIG.QUARRY) do
				for _, kind in ipairs(row.kinds) do
					quarryKinds += 1
					expect(kind ~= "legendary").to.equal(true)
				end
			end
			expect(quarryKinds + 1).to.equal(Drive.CONFIG.START_CARD_ROWS_MAX)

			-- 5. ...AND IT IS STILL A WILD BOAR TO THE RULES. Nothing but the card reads `QUARRY`;
			--    the licence and `Match.classifyTarget` learn the species from the ANIMAL, so the
			--    trophy needs no licence of its own and cannot be shot by somebody who may not shoot
			--    a boar.
			expect(Match.CONFIG.QUARRY[1].species).to.equal("WILD BOAR")

			-- 6. THE GATHERING lays it out 35 % longer than the males beside it, and the scene's own
			--    scales are the same four numbers the boar config holds.
			for kind, scale in pairs(Match.CONFIG.SCENE.ANIMAL_SCALES) do
				expect(math.abs(scale - CONFIG.KINDS[kind].scale) < EPSILON).to.equal(true)
			end
			expect(Match.CONFIG.SCENE.ANIMAL_SCALES.legendary).to.equal(1.35)

			-- 7. THE DRIVE REPORT'S WIRE carries it as its OWN count and not as an `unknown`, which
			--    is what keeps `unknown` meaning "a kind typo". The TAB list's three columns are the
			--    client's business (`report_panel.spec`); what this pins is that the key exists.
			local HitLog = require(ServerScriptService:WaitForChild("HitLog"))
			local rows = HitLog.Shape.hunterRows({
				order = { "Boar1" },
				animals = {
					Boar1 = {
						kind = "legendary",
						result = "down",
						killedByUserId = 4219,
						dots = { { userId = 4219, name = "Karen", u = 0.5, v = 0.5, zone = "chest" } },
					},
				},
			}, 8)
			expect(#rows).to.equal(1)
			expect(rows[1].byKind.legendary).to.equal(1)
			expect(rows[1].byKind.unknown).to.equal(0)
			expect(rows[1].kills).to.equal(1)
		end)
	end)
end

-- boar_kinds.spec: THE SOW AND THE CUB (task 119) -- three animals, one skeleton, one set of numbers.
-- Pure: no physics, no Workspace, no waiting. Every case drives the exported pure functions with its
-- own config, which is the only way both flag states are reachable while `BOAR_MODEL` sits at one.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- Karen, 2026-10-03: "we need also biger smaller kids ect". The agreed makeup (Director, 2026-10-04)
-- is that a SOUNDER is a sow with young and a LONE animal is a male.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local CONFIG = Boar.CONFIG

local EPSILON = 1e-4

-- The flag as a parameter, which is the one permitted shape: `test` refuses to start with an
-- override set, so a harness run only ever sees `BOAR_MODEL`'s OFF default.
local function configWith(on: boolean)
	local kinds = table.clone(CONFIG.KINDS)
	kinds.ENABLED = on
	local config = table.clone(CONFIG)
	config.KINDS = kinds
	return config
end

return function()
	describe("boar kinds: three animals, one set of numbers", function()
		local on = configWith(true)
		local off = configWith(false)

		it("scales every box with the animal, so a cub is a small target", function()
			local male = Boar.kindGeometry("male", on)
			local female = Boar.kindGeometry("female", on)
			local cub = Boar.kindGeometry("cub", on)

			-- THE LENGTHS ARE THE DIRECTOR'S (2026-10-04) and are what `tools/boar_prep.py` baked
			-- into the uploaded geometry: 0.85 and 0.45 of the male's 5.5 studs.
			expect(math.abs(male.bodySize.Z - CONFIG.BODY_SIZE.Z) < EPSILON).to.equal(true)
			expect(math.abs(female.bodySize.Z - 4.675) < EPSILON).to.equal(true)
			expect(math.abs(cub.bodySize.Z - 2.475) < EPSILON).to.equal(true)

			-- EVERY HIT ZONE GOES WITH IT, which is what makes a cub a small target rather than a
			-- small picture: its chest box is 0.45 of the male's chest box, in all three axes, and
			-- it sits 0.45 as far forward.
			for _, name in ipairs(CONFIG.ZONES.ORDER) do
				local big, small = male.zones[name], cub.zones[name]
				expect((small.size - big.size * 0.45).Magnitude < EPSILON).to.equal(true)
				expect((small.offset - big.offset * 0.45).Magnitude < EPSILON).to.equal(true)
			end
			TestKit.note(
				string.format(
					"boar-kinds: trunks %.2f / %.2f / %.2f studs long; a cub's chest is %.2f x %.2f x %.2f",
					male.bodySize.Z,
					female.bodySize.Z,
					cub.bodySize.Z,
					cub.zones.chest.size.X,
					cub.zones.chest.size.Y,
					cub.zones.chest.size.Z
				)
			)
		end)

		it("keeps every zone PROUD of its own trunk, at every size", function()
			-- The clearance that stops a zone part being FLUSH with the trunk is what task 116's
			-- review round 2 was about: two coincident faces at one ray distance is a coin toss. It
			-- scales with the animal, so it is smaller on a cub and it is never zero.
			for _, kind in ipairs(CONFIG.KINDS.ORDER) do
				local geometry = Boar.kindGeometry(kind, on)
				expect(geometry.protrusion > 0).to.equal(true)
				-- The chest and the rump are the two that stand proud SIDEWAYS, and they must still
				-- be wider than the trunk they hang on after everything has been scaled.
				for _, name in ipairs({ "chest", "rear", "legs" }) do
					expect(geometry.zones[name].size.X > geometry.bodySize.X).to.equal(true)
				end
			end
		end)

		it("rates a smaller animal's clips off its OWN measured stride", function()
			-- `clipScale` is not the box scale and is not a guess: `tools/boar_prep.py` measured each
			-- animal's own ground speed for every locomotion clip, and the ratio to the male came out
			-- the same on all four -- walk 2.440/1.247 against 2.852, trot 8.762/4.480 against
			-- 10.244, run 14.720/7.526 against 17.21, dig 1.626/0.831 against 1.901.
			expect(math.abs(Boar.kindRow("female", on).clipScale - 0.8553) < EPSILON).to.equal(true)
			expect(math.abs(Boar.kindRow("cub", on).clipScale - 0.4372) < EPSILON).to.equal(true)
			expect(Boar.kindRow("male", on).clipScale).to.equal(1)

			-- ...AND THE RATE DIVIDES BY IT, which is the whole reason the number exists: a cub
			-- trotting at the male's trot speed plays the clip faster, because its own legs cover
			-- less ground per cycle. Driven through the real `clipFor` at one speed, three animals.
			local model = table.clone(CONFIG.MODEL)
			local ids = table.clone(model.ANIMATION_IDS)
			for name in pairs(model.CLIPS) do
				ids[name] = 30000 + #name
			end
			model.ANIMATION_IDS = ids
			local drawn = table.clone(on)
			drawn.MODEL = model

			local function info(scale: number)
				return {
					collapsed = false,
					deadFor = 0,
					crippled = false,
					alert = false,
					activity = nil,
					activityFor = 0,
					exitClip = nil,
					exitFor = 0,
					hitFor = 0,
					hitFromBehind = false,
					-- 12 studs/s: inside the trot band for both animals (TROT_FROM is ~11, RUN_FROM 28)
					-- and chosen so NEITHER rate is clamped -- the cub's comes to 2.68 against a
					-- MAX_RATE of 2.8, which is itself the measurement worth having: a cub keeping up
					-- with an adult is at the top of what its legs can be played at.
					speed = 12,
					yawRate = 0,
					currentClip = nil,
					heldFor = 10,
					clipScale = scale,
				}
			end

			local maleClip, maleRate = Boar.clipFor(info(1), drawn)
			local cubClip, cubRate = Boar.clipFor(info(Boar.kindRow("cub", on).clipScale), drawn)
			-- The same clip -- the gait is chosen on the world speed and that has not changed -- at a
			-- different rate, which is the whole of this number's job.
			expect(cubClip).to.equal(maleClip)
			expect(cubRate > maleRate).to.equal(true)
			expect(math.abs(cubRate - maleRate / 0.4372) < 1e-3).to.equal(true)
			expect(cubRate <= CONFIG.MODEL.MAX_RATE).to.equal(true)
			TestKit.note(
				string.format(
					"boar-kinds: at 12 studs/s both play %s, the male at %.2f and a cub at %.2f",
					tostring(maleClip),
					maleRate,
					cubRate
				)
			)
		end)

		it("makes a sounder a sow with young, and a lone animal a male", function()
			-- The rolls are the parameter, so "an occasional young male" is a case and not a chance.
			local never = { 1, 1, 1, 1, 1 }
			local always = { 0, 0, 0, 0, 0 }
			expect(Boar.sounderKinds(4, never, on)).to.never.equal(nil)
			local plain = Boar.sounderKinds(4, never, on)
			expect(plain[1]).to.equal("female")
			for index = 2, 4 do
				expect(plain[index]).to.equal("cub")
			end
			local yearlings = Boar.sounderKinds(4, always, on)
			expect(yearlings[1]).to.equal("female") -- the sow is the sow whatever the roll says
			for index = 2, 4 do
				expect(yearlings[index]).to.equal("male")
			end
			-- A LONE ANIMAL IS A MALE, which is the other half of the makeup.
			expect(CONFIG.SOUNDER.MAKEUP.LONE).to.equal("male")
		end)

		it("with the FLAG off, every animal is the male-sized box this game has always spawned", function()
			-- This is what keeps every spec written before task 119 true, and the grey-box world the
			-- one Milestone 1.2 shipped: the flag gates the whole block, kinds included.
			for _, kind in ipairs({ "male", "female", "cub" }) do
				local geometry = Boar.kindGeometry(kind, off)
				expect((geometry.bodySize - CONFIG.BODY_SIZE).Magnitude < EPSILON).to.equal(true)
				expect(geometry.scale).to.equal(1)
				expect(geometry.clipScale).to.equal(1)
				for _, name in ipairs(CONFIG.ZONES.ORDER) do
					expect((geometry.zones[name].size - CONFIG.ZONES[name].size).Magnitude < EPSILON).to.equal(true)
					expect((geometry.zones[name].offset - CONFIG.ZONES[name].offset).Magnitude < EPSILON).to.equal(true)
				end
			end
			local lone = Boar.sounderKinds(5, { 0, 0, 0, 0, 0 }, off)
			for _, kind in ipairs(lone) do
				expect(kind).to.equal("male")
			end
		end)
	end)
end

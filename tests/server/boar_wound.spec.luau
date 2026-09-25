-- boar_wound.spec: the whole damage model, with no Instances, no physics and no waiting. Boar.Wound
-- is pure, so every number Karen will retune -- the damage table, the two thresholds, the flight
-- formula, the speed ramp, the kill record -- is checked here in microseconds instead of with a live
-- boar and a physics frame.
--
-- The config is written out HERE rather than read from Boar.CONFIG, following
-- tests/server/test_arena.spec.luau: a spec that imports the numbers it is checking can only ever
-- agree with itself. The one exception is the last describe, which deliberately compares this table
-- against production's, so a config change is a finding rather than a silent drift.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/hit-zones.md (sections 5, 8.2, 12.1)
-- Note:   docs/research/2026-09-25-hit-zones.md
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))
local Wound = Boar.Wound

local WOUND = {
	LETHAL = 100,
	MORTAL = 50,
	DAMAGE = {
		head = { Slug = 100, Pellet = 34 },
		chest = { Slug = 100, Pellet = 25 },
		body = { Slug = 55, Pellet = 11 },
		legs = { Slug = 30, Pellet = 6 },
	},
	FLIGHT = { head = 0, chest = 0, body = 120, legs = 420 },
	BLEED_OUT_MAX_SECONDS = 25,
	WOUND_SPEED_START = 1.0,
	WOUND_SPEED_END = 0.45,
	LIMP_SCALE = 0.75,
	BOLT_SECONDS = 3.0,
	BOLT_KICK = 0.8,
	CARCASS_SECONDS = 120,
}

local EPSILON = 1e-4

local function hit(zone: string, ammo: string, pellets: number?, extra)
	local h = { zone = zone, ammo = ammo, pellets = pellets or 1, at = 0 }
	for key, value in pairs(extra or {}) do
		h[key] = value
	end
	return h
end

-- Applies a list of hits to a fresh state and returns the final state.
local function after(hits): any
	local state = Wound.new()
	for _, h in ipairs(hits) do
		state = (Wound.apply(state, h, WOUND))
	end
	return state
end

local function near(actual: number, expected: number): boolean
	return math.abs(actual - expected) < 0.5
end

return function()
	describe("a fresh wound state", function()
		it("is zero, healthy and frozen", function()
			local state = Wound.new()
			expect(state.damage).to.equal(0)
			expect(state.severity).to.equal("healthy")
			expect(state.flightStuds).to.equal(0)
			expect(state.flightRun).to.equal(0)
			expect(#state.wounds).to.equal(0)
			-- Frozen means frozen: a writable "immutable" state is the bug this is here to prevent.
			expect(function()
				state.damage = 99
			end).to.throw()
			expect(function()
				state.byZone.head = 1
			end).to.throw()
		end)
	end)

	describe("the damage table", function()
		it("charges a slug at the slug column, in every zone", function()
			expect(Wound.damageFor("head", "Slug", 1, WOUND)).to.equal(100)
			expect(Wound.damageFor("chest", "Slug", 1, WOUND)).to.equal(100)
			expect(Wound.damageFor("body", "Slug", 1, WOUND)).to.equal(55)
			expect(Wound.damageFor("legs", "Slug", 1, WOUND)).to.equal(30)
		end)

		it("charges every buckshot pellet separately", function()
			expect(Wound.damageFor("head", "Buck", 1, WOUND)).to.equal(34)
			expect(Wound.damageFor("chest", "Buck", 4, WOUND)).to.equal(100)
			expect(Wound.damageFor("body", "Buck", 9, WOUND)).to.equal(99)
			expect(Wound.damageFor("legs", "Buck", 2, WOUND)).to.equal(12)
		end)

		it("charges an unknown zone at the body row, and never for free", function()
			-- The weapon reports "unknown" when it found no HitZone attribute at all. An attribute
			-- typo must show up as a counter, not as an animal that will not die.
			expect(Wound.damageFor("unknown", "Slug", 1, WOUND)).to.equal(55)
			local state = after({ hit("unknown", "Slug") })
			expect(state.damage).to.equal(55)
			expect(state.severity).to.equal("mortal")
			expect(state.wounds[1].unknownPellets).to.equal(1)
			expect(state.byZone.body).to.equal(55) -- charged AS body, so the flight is the body's
		end)
	end)

	describe("the thresholds", function()
		it("kills on a head or a chest slug", function()
			expect(after({ hit("head", "Slug") }).severity).to.equal("lethal")
			expect(after({ hit("chest", "Slug") }).severity).to.equal("lethal")
		end)

		it("is mortal on a body slug and only grazed on one leg slug", function()
			expect(after({ hit("body", "Slug") }).severity).to.equal("mortal")
			expect(after({ hit("legs", "Slug") }).severity).to.equal("grazed")
		end)

		it("needs several leg hits, which is the whole point of the legs zone", function()
			expect(after({ hit("legs", "Slug"), hit("legs", "Slug") }).severity).to.equal("mortal")
		end)
	end)

	describe("the flight distance", function()
		it("is 108 studs for a body slug", function()
			-- 120 * (1 - (55 - 50)/50)
			expect(near(after({ hit("body", "Slug") }).flightStuds, 108)).to.equal(true)
		end)

		it("is 336 studs for two leg slugs: far enough to reach the exit line", function()
			-- 420 * (1 - (60 - 50)/50)
			expect(near(after({ hit("legs", "Slug"), hit("legs", "Slug") }).flightStuds, 336)).to.equal(true)
		end)

		it("is 126 studs for a body slug plus a leg slug", function()
			-- 420 * (1 - (85 - 50)/50): the worst flight zone hit, shortened by the total damage
			expect(near(after({ hit("body", "Slug"), hit("legs", "Slug") }).flightStuds, 126)).to.equal(true)
		end)

		it("is zero for anything lethal, and for a mortal chest hit", function()
			expect(after({ hit("head", "Slug") }).flightStuds).to.equal(0)
			local chest = after({ hit("chest", "Buck", 2, { zones = { chest = 2 } }) })
			expect(chest.severity).to.equal("mortal") -- 2 x 25
			expect(chest.flightStuds).to.equal(0) -- a lung hit is a lung hit: it drops here
		end)
	end)

	describe("buckshot, per pellet", function()
		it("charges each pellet in the zone it landed in", function()
			local state = after({ hit("chest", "Buck", 9, { zones = { chest = 4, body = 3, legs = 2 } }) })
			expect(state.damage).to.equal(4 * 25 + 3 * 11 + 2 * 6) -- 145
			expect(state.severity).to.equal("lethal")
			expect(state.byZone.chest).to.equal(100)
			expect(state.byZone.body).to.equal(33)
			expect(state.byZone.legs).to.equal(12)
			expect(state.wounds[1].tallyless).to.equal(false)
		end)

		it("falls back to the dominant zone with no tally, and SAYS SO", function()
			local state = after({ hit("chest", "Buck", 9) })
			expect(state.damage).to.equal(9 * 25)
			-- The fallback is honest, not silent: this flag is what the runtime counts, so
			-- "buckshot zones stopped working" is a number in the harness report.
			expect(state.wounds[1].tallyless).to.equal(true)
		end)
	end)

	describe("apply", function()
		it("never mutates its input and returns a frozen state", function()
			local first = after({ hit("legs", "Slug") })
			local before = first.damage
			local second = Wound.apply(first, hit("legs", "Slug"), WOUND)
			expect(first.damage).to.equal(before) -- the old state is untouched
			expect(second.damage).to.equal(before + 30)
			expect(second).never.to.equal(first)
			expect(function()
				second.flightRun = 5
			end).to.throw()
		end)

		it("keeps the wounds in order and adds up each shooter's damage", function()
			local state = Wound.new()
			state = (Wound.apply(state, hit("legs", "Slug", 1, { shooterUserId = 11, at = 1 }), WOUND))
			state = (Wound.apply(state, hit("body", "Slug", 1, { shooterUserId = 22, at = 2 }), WOUND))
			state = (Wound.apply(state, hit("legs", "Slug", 1, { shooterUserId = 11, at = 3 }), WOUND))
			expect(#state.wounds).to.equal(3)
			expect(state.wounds[1].at).to.equal(1)
			expect(state.wounds[3].at).to.equal(3)
			expect(state.contributors[11]).to.equal(60)
			expect(state.contributors[22]).to.equal(55)
		end)

		it("records the hit that crossed the line, and never replaces it", function()
			local state = Wound.new()
			state = (Wound.apply(state, hit("legs", "Slug", 1, { shooterUserId = 11, at = 1 }), WOUND))
			expect(state.mortalWound == nil).to.equal(true) -- grazed: nothing has killed it yet
			state = (Wound.apply(state, hit("body", "Slug", 1, { shooterUserId = 22, at = 2 }), WOUND))
			expect(state.mortalWound).to.be.ok()
			expect(state.mortalWound.shooterUserId).to.equal(22)
			state = (Wound.apply(state, hit("head", "Slug", 1, { shooterUserId = 33, at = 3 }), WOUND))
			-- Later pellets into a dying animal do not steal the kill.
			expect(state.mortalWound.shooterUserId).to.equal(22)
		end)
	end)

	describe("the speed while wounded", function()
		it("is 1.0 while healthy or grazed", function()
			expect(Wound.speedScale(Wound.new(), WOUND)).to.equal(1)
			expect(Wound.speedScale(after({ hit("body", "Buck", 1, { zones = { body = 1 } }) }), WOUND)).to.equal(1)
		end)

		it("limps after any damage in the legs", function()
			local grazed = after({ hit("legs", "Slug") })
			expect(math.abs(Wound.speedScale(grazed, WOUND) - 0.75) < EPSILON).to.equal(true)
		end)

		it("ramps from 1.0 to 0.45 across the flight, and never reaches zero", function()
			local state = after({ hit("body", "Slug") }) -- mortal, 108 studs, no leg damage
			expect(math.abs(Wound.speedScale(state, WOUND) - 1) < EPSILON).to.equal(true)

			local half = (Wound.advance(state, state.flightStuds / 2, 1, WOUND))
			expect(math.abs(Wound.speedScale(half, WOUND) - 0.725) < 1e-2).to.equal(true)

			local done = (Wound.advance(state, state.flightStuds, 1, WOUND))
			expect(math.abs(Wound.speedScale(done, WOUND) - 0.45) < EPSILON).to.equal(true)
			expect(Wound.speedScale(done, WOUND) > 0).to.equal(true)
		end)
	end)

	describe("a later hit", function()
		it("never lengthens the run it has left", function()
			local state = after({ hit("legs", "Slug"), hit("legs", "Slug") }) -- mortal, 336 studs
			local ran = (Wound.advance(state, 100, 3, WOUND))
			expect(ran.flightRun).to.equal(100)
			local remainingBefore = ran.flightStuds - ran.flightRun

			local hurt = (Wound.apply(ran, hit("legs", "Buck", 1, { zones = { legs = 1 } }), WOUND))
			expect(hurt.flightRun).to.equal(100) -- the distance already run is NOT reset
			expect(hurt.flightStuds < ran.flightStuds).to.equal(true)
			expect(hurt.flightStuds - hurt.flightRun < remainingBefore).to.equal(true)
		end)
	end)

	describe("advance", function()
		it("collapses exactly when the flight is run out", function()
			local state = after({ hit("body", "Slug") }) -- 108 studs
			local nearly, collapse = Wound.advance(state, 107, 1, WOUND)
			expect(collapse).to.equal(false)
			local _, collapsed = Wound.advance(nearly, 2, 1, WOUND)
			expect(collapsed).to.equal(true)
		end)

		it("collapses at the bleed-out ceiling even if the boar never moved", function()
			local state = after({ hit("legs", "Slug"), hit("legs", "Slug") }) -- 336 studs
			local collapse = false
			for _ = 1, 24 do
				state, collapse = Wound.advance(state, 0, 1, WOUND)
				expect(collapse).to.equal(false) -- 24 s of standing still is not yet the ceiling
			end
			state, collapse = Wound.advance(state, 0, 1, WOUND)
			expect(collapse).to.equal(true)
			expect(state.flightSeconds >= WOUND.BLEED_OUT_MAX_SECONDS).to.equal(true)
		end)

		it("never collapses a healthy or a grazed boar, however far it runs", function()
			local healthy, a = Wound.advance(Wound.new(), 10000, 100, WOUND)
			expect(a).to.equal(false)
			expect(healthy.flightRun).to.equal(0) -- and nothing accumulates for it either

			local _, b = Wound.advance(after({ hit("legs", "Slug") }), 10000, 100, WOUND)
			expect(b).to.equal(false)
		end)

		it("collapses a lethal hit immediately", function()
			local _, collapse = Wound.advance(after({ hit("head", "Slug") }), 0, 0, WOUND)
			expect(collapse).to.equal(true)
		end)
	end)

	describe("the kill record", function()
		it("carries the killing shot, the shooter and the run", function()
			local state = Wound.new()
			state = (Wound.apply(state, hit("legs", "Slug", 1, { shooterUserId = 11, at = 1 }), WOUND))
			state = (Wound.apply(state, hit("body", "Slug", 1, { shooterUserId = 22, at = 2, distance = 42 }), WOUND))
			state = (Wound.advance(state, 60, 2, WOUND))

			local record = Wound.killRecord(state, "Boar7", Vector3.new(1, 2, 3), 30, WOUND)
			expect(record.id).to.equal("Boar7")
			expect(record.killingZone).to.equal("body")
			expect(record.killingAmmo).to.equal("Slug")
			expect(record.killedByUserId).to.equal(22)
			expect(record.killingDistance).to.equal(42)
			expect(record.instant).to.equal(false) -- it bled out; it did not drop on the spot
			expect(record.flightStuds).to.equal(60)
			expect(record.damage).to.equal(85)
			expect(record.shots).to.equal(2)
			expect(record.shots).to.equal(#record.wounds)
			expect(record.contributors[11]).to.equal(30)
			expect(record.aliveFor).to.equal(30)
		end)

		it("says instant only when the boar dropped on the spot", function()
			local state = after({ hit("head", "Slug", 1, { shooterUserId = 5 }) })
			local record = Wound.killRecord(state, "Boar1", Vector3.zero, 1, WOUND)
			expect(record.instant).to.equal(true)
			expect(record.flightStuds).to.equal(0)
			expect(record.killingZone).to.equal("head")
		end)
	end)

	describe("performance", function()
		it("applies 10000 hits in under 100 ms", function()
			local state = Wound.new()
			local shot = hit("legs", "Buck", 2, { zones = { legs = 2 } })
			local started = os.clock()
			for _ = 1, 10000 do
				state = (Wound.apply(state, shot, WOUND))
			end
			local elapsed = (os.clock() - started) * 1000
			print(string.format("[boar_wound] 10000 applies in %.1f ms", elapsed))
			expect(elapsed < 100).to.equal(true)
		end)
	end)

	describe("the numbers this spec asserts", function()
		it("are the numbers production actually ships", function()
			-- Every other assertion here is against the table at the top of this file, so that a
			-- spec cannot agree with a broken config by construction. This one test closes the loop
			-- the other way: if Karen retunes a feel value, this is what says so, in one place.
			local live = Boar.CONFIG.WOUND
			expect(live.LETHAL).to.equal(WOUND.LETHAL)
			expect(live.MORTAL).to.equal(WOUND.MORTAL)
			for zone, row in pairs(WOUND.DAMAGE) do
				expect(live.DAMAGE[zone].Slug).to.equal(row.Slug)
				expect(live.DAMAGE[zone].Pellet).to.equal(row.Pellet)
				expect(live.FLIGHT[zone]).to.equal(WOUND.FLIGHT[zone])
			end
			expect(live.BLEED_OUT_MAX_SECONDS).to.equal(WOUND.BLEED_OUT_MAX_SECONDS)
			expect(live.LIMP_SCALE).to.equal(WOUND.LIMP_SCALE)
			expect(live.WOUND_SPEED_END).to.equal(WOUND.WOUND_SPEED_END)
		end)
	end)
end

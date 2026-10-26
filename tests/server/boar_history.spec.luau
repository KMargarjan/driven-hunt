-- boar_history.spec: WHERE AN ANIMAL WAS (task 266)
--
-- KAREN, 2026-10-24/25: *"we need to aim in empty space to get hit in head neck or heart like in
-- real life"* / *"all shooting has to be like in real life / this is a key of this game"*. The
-- weapon now asks the Boar where an animal WAS when the shooter's own screen drew it, and compares
-- that with the hit the client claimed. `Boar.sampleAt` is the whole of that rewind.
--
-- PURE, AND THAT IS THE POINT OF THE SHAPE. `Boar.sampleAt(ring, count, at)` takes a hand-written
-- ring and three numbers: no world, no Instance, no clock, no runtime. So the interpolation, the
-- ring's wrap and -- most of all -- the REFUSAL outside its span can each be driven at values the
-- running game never produces, which is what makes "nil is never an extrapolation" an assertion
-- rather than a sentence in a comment.
--
-- WHAT IS DELIBERATELY NOT HERE: `Runtime:cframeAt`'s own live walk (it needs a spawned animal and a
-- Brain state, and `boar_shot.spec` / `weapon_shot.spec` are where a real body is driven). What this
-- file owns is the arithmetic every one of those answers is built out of.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/ballistics.md (sections 3.2, 4.6)
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))

return function()
	local function near(actual: number, expected: number, tolerance: number)
		expect(math.abs(actual - expected) <= tolerance).to.equal(true)
	end

	-- A RING WRITTEN THE WAY `Runtime:step` WRITES ONE: in place, at `count % SAMPLES + 1`, so a
	-- wrapped ring in this spec is wrapped exactly as a wrapped ring in the game is.
	-- `{ { any } }` and not `{ { number, Vector3 } }`: Luau has no tuple table type, and the pair is
	-- positional here on purpose so the cases read as a table of stamps.
	local function ringOf(size: number, samples: { { any } })
		local ring = {}
		local count = 0
		for _, sample in ipairs(samples) do
			count += 1
			local slot = (count - 1) % size + 1
			ring[slot] = { at = sample[1], cframe = CFrame.new(sample[2]) }
		end
		return ring, count
	end

	describe("Boar.sampleAt -- the rewind", function()
		it("hands back a sample that sits exactly on a stamp", function()
			local ring, count = ringOf(8, { { 100.0, Vector3.new(0, 0, 0) }, { 100.1, Vector3.new(1, 0, 0) } })
			local at = Boar.sampleAt(ring, count, 100.1)
			expect(at).to.be.ok()
			near((at :: CFrame).Position.X, 1, 1e-6)
		end)

		it("INTERPOLATES between the two samples that bracket the instant", function()
			-- Three stamps 0.1 s apart, the animal travelling +10 studs/s in X. Half way between the
			-- second and the third it must read 1.5, which no single sample holds -- so a
			-- "nearest sample" implementation fails this case and a lerp passes it.
			local ring, count = ringOf(8, {
				{ 100.0, Vector3.new(0, 0, 0) },
				{ 100.1, Vector3.new(1, 0, 0) },
				{ 100.2, Vector3.new(2, 0, 0) },
			})
			local at = Boar.sampleAt(ring, count, 100.15)
			expect(at).to.be.ok()
			near((at :: CFrame).Position.X, 1.5, 1e-4)
		end)

		it("INTERPOLATES THE ROTATION TOO, because the zones are welded in trunk space", function()
			-- An animal that turns moves its own chest sideways. Two stamps, 90 degrees apart about
			-- Y: half way must be 45 degrees, not either end.
			local ring = {
				{ at = 10.0, cframe = CFrame.Angles(0, 0, 0) },
				{ at = 10.2, cframe = CFrame.Angles(0, math.rad(90), 0) },
			}
			local at = Boar.sampleAt(ring, 2, 10.1)
			expect(at).to.be.ok()
			local _, y = (at :: CFrame):ToEulerAnglesYXZ()
			near(math.deg(y), 45, 0.5)
		end)

		-- THE NEWEST EDGE (task 266b), and it is the case the whole feature failed on. MEASURED in
		-- the Forest Test: every honest claim was refused because the claimed arrival was **27 ms
		-- newer than the newest sample** -- the ring is stamped once per step and the claim is judged
		-- in another Heartbeat handler, so the instant asked about always falls in the gap between
		-- the last sample and the present.
		it("INTERPOLATES between the newest sample and the PRESENT, which is not extrapolation", function()
			local ring, count = ringOf(8, { { 100.0, Vector3.new(0, 0, 0) }, { 100.1, Vector3.new(1, 0, 0) } })
			-- The animal is at x = 2 now, at t = 100.2. Half way between the last sample and now it
			-- must read 1.5 -- a point no sample holds, bracketed on both sides.
			local at = Boar.sampleAt(ring, count, 100.15, 100.2, CFrame.new(2, 0, 0))
			expect(at).to.be.ok()
			near((at :: CFrame).Position.X, 1.5, 1e-4)
		end)

		it("answers the PRESENT exactly at now", function()
			local ring, count = ringOf(8, { { 100.0, Vector3.new(0, 0, 0) }, { 100.1, Vector3.new(1, 0, 0) } })
			local at = Boar.sampleAt(ring, count, 100.2, 100.2, CFrame.new(2, 0, 0))
			expect(at).to.be.ok()
			near((at :: CFrame).Position.X, 2, 1e-6)
		end)

		it("STILL REFUSES past the present -- the future is never guessed", function()
			local ring, count = ringOf(8, { { 100.0, Vector3.new(0, 0, 0) }, { 100.1, Vector3.new(1, 0, 0) } })
			expect(Boar.sampleAt(ring, count, 100.3, 100.2, CFrame.new(2, 0, 0))).to.equal(nil)
		end)

		it("without the present it is exactly what it was: past the newest sample is a refusal", function()
			local ring, count = ringOf(8, { { 100.0, Vector3.new(0, 0, 0) }, { 100.1, Vector3.new(1, 0, 0) } })
			expect(Boar.sampleAt(ring, count, 100.15)).to.equal(nil)
			expect(Boar.sampleAt(ring, count, 100.15, 100.2, nil)).to.equal(nil)
			expect(Boar.sampleAt(ring, count, 100.15, nil, CFrame.new(2, 0, 0))).to.equal(nil)
		end)

		it("REFUSES an instant before the oldest sample, and never extrapolates", function()
			local ring, count = ringOf(8, { { 100.0, Vector3.new(0, 0, 0) }, { 100.1, Vector3.new(1, 0, 0) } })
			expect(Boar.sampleAt(ring, count, 99.9)).to.equal(nil)
		end)

		it("REFUSES an instant after the newest sample when no present is given", function()
			local ring, count = ringOf(8, { { 100.0, Vector3.new(0, 0, 0) }, { 100.1, Vector3.new(1, 0, 0) } })
			expect(Boar.sampleAt(ring, count, 100.2)).to.equal(nil)
		end)

		it("REFUSES an instant that has been overwritten by the ring's wrap", function()
			-- A ring of 4 written 6 times: samples 1 and 2 no longer exist. Asking for sample 1's
			-- own stamp must be a refusal and NOT sample 5's position, which is what a reader that
			-- ignored `count` would answer.
			local samples = {}
			for index = 1, 6 do
				table.insert(samples, { 200 + index * 0.1, Vector3.new(index, 0, 0) })
			end
			local ring, count = ringOf(4, samples)
			expect(count).to.equal(6)
			expect(Boar.sampleAt(ring, count, 200.1)).to.equal(nil) -- sample 1, overwritten
			expect(Boar.sampleAt(ring, count, 200.2)).to.equal(nil) -- sample 2, overwritten
			local kept = Boar.sampleAt(ring, count, 200.3) -- sample 3, the oldest still live
			expect(kept).to.be.ok()
			near((kept :: CFrame).Position.X, 3, 1e-6)
			local newest = Boar.sampleAt(ring, count, 200.6)
			expect(newest).to.be.ok()
			near((newest :: CFrame).Position.X, 6, 1e-6)
		end)

		it("reads a WRAPPED ring in the right order, which is the whole of the index arithmetic", function()
			-- 5 samples in a ring of 4: slot 1 holds the NEWEST and slot 2 the oldest. Interpolating
			-- across the seam (between samples 4 and 5, i.e. slots 4 and 1) is where an off-by-one
			-- shows up as a position from a second ago.
			local samples = {}
			for index = 1, 5 do
				table.insert(samples, { 300 + index * 0.1, Vector3.new(index * 10, 0, 0) })
			end
			local ring, count = ringOf(4, samples)
			local at = Boar.sampleAt(ring, count, 300.45) -- between 40 and 50
			expect(at).to.be.ok()
			near((at :: CFrame).Position.X, 45, 1e-3)
		end)

		it("answers nil for an empty ring, a zero count, and a NaN instant", function()
			expect(Boar.sampleAt({}, 0, 100)).to.equal(nil)
			local ring, count = ringOf(8, { { 100.0, Vector3.zero } })
			expect(Boar.sampleAt(ring, 0, 100)).to.equal(nil)
			expect(Boar.sampleAt(ring, count, 0 / 0)).to.equal(nil)
			expect(Boar.sampleAt(nil :: any, 1, 100)).to.equal(nil)
		end)

		it("a single live sample answers itself, at its own stamp and nowhere else", function()
			local ring, count = ringOf(8, { { 50.0, Vector3.new(7, 0, 0) } })
			local at = Boar.sampleAt(ring, count, 50.0)
			expect(at).to.be.ok()
			near((at :: CFrame).Position.X, 7, 1e-6)
			expect(Boar.sampleAt(ring, count, 50.001)).to.equal(nil)
			expect(Boar.sampleAt(ring, count, 49.999)).to.equal(nil)
		end)
	end)

	describe("the ring's own numbers", function()
		it("is declared in samples, not seconds, and is enabled", function()
			local history = Boar.CONFIG.HISTORY
			expect(history).to.be.ok()
			expect(history.SAMPLES).to.equal(96)
			expect(history.ENABLED).to.equal(true)
		end)

		-- THE CROSS-SYSTEM INVARIANT -- that a claim the weapon will judge is inside the span the
		-- animal can remember -- IS NOT ASSERTED HERE. It belongs to one file,
		-- `tests/server/zz_claim_window.spec.luau` (design 3.3), because it is a fact about TWO configs
		-- a second copy of it could pass while the real one failed. What this file owns is the ring.
		it("spans about a second at a 60 Hz Heartbeat, which is what the window is sized against", function()
			near(Boar.CONFIG.HISTORY.SAMPLES / 60, 1.6, 0.001)
		end)
	end)
end

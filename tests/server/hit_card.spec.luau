-- hit_card.spec: THE HIT CARD'S SERVER HALF (task 198) -- one dot per pellet, the same projection
-- the drive report uses, and nothing at all for a miss, a beater or a tree.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- Karen, 2026-10-16: *"so once we hit boar we can show where it has been hitted / red dot will
-- indicate so if shells then several of them / so somewhere in corner after hit we indicate where it
-- landed"*.
--
-- WHAT IT PROVES, AND WHY EACH CASE CAN FAIL. The dispatch names five, and none of them is a
-- function reading its own answer back:
--   * n pellets on the animal -> n dots, and the count comes from `Weapon.Hits.group`'s own
--     grouping of hand-written impacts, not from a number this file also wrote;
--   * a slug -> exactly one dot;
--   * a miss -> no card at all, because `Hits.group` makes no report and `recordHit` returns false;
--   * a hit on something that is not an animal (a beater, a tree) -> a RECORD but no card;
--   * the card's dots come out of `HitLog.Shape.dot` -- the drive report's own projection -- which
--     is asserted by computing the report's dot independently and finding it among the card's.
--
-- Design: docs/design/drive-report.md (sections 6.2, 6.3). Note: docs/research/2026-10-17-hit-card.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HitLog = require(ServerScriptService:WaitForChild("HitLog"))
local Shape = require(ServerScriptService:WaitForChild("HitLog"):WaitForChild("Shape"))
local Hits = require(ServerScriptService:WaitForChild("Weapon"):WaitForChild("Hits"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local BODY = Vector3.new(2, 3, 5.5)

-- A boar's trunk, as `Boar.Body.create` publishes it: a `BasePart` carrying `Damageable`, which is
-- the one definition of an animal this game has (`Weapon.Hits.targetOf`).
local function fakeBoar(id: string): BasePart
	local part = Instance.new("Part")
	part.Name = id
	part.Size = BODY
	part.CFrame = CFrame.new(0, 3, 0)
	part.Anchored = true
	part:SetAttribute("Damageable", true)
	part:SetAttribute("HitZone", "body")
	part:SetAttribute("Kind", "male")
	return part
end

-- A beater: a part with no `Damageable`. `Hits.targetOf` finds no root in it, so a shot that strikes
-- one makes no report at all -- and if anything ever did reach `recordHit` with it, `cardWorthy` is
-- the line that refuses the card.
local function fakeBeater(): BasePart
	local part = Instance.new("Part")
	part.Name = "BeaterTorso"
	part.Size = Vector3.new(2, 2, 1)
	part.CFrame = CFrame.new(20, 3, 0)
	part.Anchored = true
	return part
end

-- One impact, as `Weapon.Flight` hands them to `Hits.group`.
local function impact(instance: Instance, position: Vector3, distance: number)
	return { instance = instance, position = position, normal = Vector3.new(0, 0, -1), distance = distance }
end

local function report(part: BasePart, shooter: any, points: { any }?, extra: any?)
	return {
		target = part,
		shooter = shooter,
		zone = (extra and extra.zone) or "body",
		position = (extra and extra.position) or (part.Position + Vector3.new(-1, 0.4, 1)),
		nearest = (extra and extra.nearest) or 40,
		pellets = (extra and extra.pellets) or (if points then #points else 1),
		ammo = (extra and extra.ammo) or "Buck",
		weapon = (extra and extra.weapon) or "shotgun",
		points = points,
		at = (extra and extra.at) or 10.0,
	}
end

return function()
	-- THE PER-PELLET DETAIL, AT THE PLACE IT ENTERS THE SYSTEM. `Hits.group` is still ONE report per
	-- (shot, target) -- that contract is what `HitLog`, `Match` and the hit marker all read -- and
	-- task 198 hangs the pellets underneath it rather than beside it.
	describe("Weapon.Hits.group carries every pellet's landing place", function()
		it("gives one point per pellet that struck the target, and keeps one report", function()
			local boar = fakeBoar("B1")
			local shooter = { UserId = 1, Name = "A" } :: any
			local impacts = {
				impact(boar, Vector3.new(0, 3.2, -1.0), 44),
				impact(boar, Vector3.new(0, 3.6, 0.5), 41),
				impact(boar, Vector3.new(0, 2.8, 1.4), 46),
				impact(boar, Vector3.new(0, 3.0, 2.0), 48),
			}
			local reports = Hits.group(shooter, impacts, "Buck", 5.0, "shotgun")
			expect(#reports).to.equal(1)
			expect(reports[1].pellets).to.equal(4)
			expect(#(reports[1].points :: any)).to.equal(4)
			-- The report's own `position` is still the NEAREST impact, which is what the drive
			-- report's single dot has always been made from.
			expect((reports[1].position - Vector3.new(0, 3.6, 0.5)).Magnitude < 1e-4).to.equal(true)
			boar:Destroy()
		end)

		it("makes no report and no points at all for a miss", function()
			local shooter = { UserId = 1, Name = "A" } :: any
			local tree = Instance.new("Part")
			tree.Name = "Trunk"
			tree.Anchored = true
			-- No `Damageable` anywhere above it: `targetOf` finds nothing, so there is no report,
			-- so `recordHit` is never called and no card can exist.
			local reports = Hits.group(shooter, { impact(tree, Vector3.new(5, 3, 5), 20) }, "Buck", 5.0, "shotgun")
			expect(#reports).to.equal(0)
			tree:Destroy()
		end)
	end)

	-- THE PROJECTION. One function, `Shape.dot`, used by the drive report's single dot and by every
	-- dot on the card -- the dispatch's *"do not make a second projection"*.
	describe("HitLog.Shape.cardDots", function()
		it("gives one dot per pellet, at exactly what Shape.dot answers for that pellet", function()
			local cf = CFrame.new(0, 3, 0)
			local points = {
				{ position = Vector3.new(-1, 3.4, -1.5), zone = "chest" },
				{ position = Vector3.new(-1, 3.0, 0.0), zone = "body" },
				{ position = Vector3.new(-1, 2.6, 1.6), zone = "rear" },
			}
			local dots = Shape.cardDots(cf, BODY, points, points[2].position, "body")
			expect(#dots).to.equal(3)
			for index, point in ipairs(points) do
				local u, v, side = Shape.dot(cf, BODY, point.position)
				expect(math.abs(dots[index].u - u) < 1e-9).to.equal(true)
				expect(math.abs(dots[index].v - v) < 1e-9).to.equal(true)
				expect(dots[index].side).to.equal(side)
				expect(dots[index].zone).to.equal(point.zone)
			end
		end)

		it("marks exactly one lead dot, and it is the one the drive report draws", function()
			local cf = CFrame.new(0, 3, 0)
			local points = {
				{ position = Vector3.new(-1, 3.4, -1.5), zone = "chest" },
				{ position = Vector3.new(-1, 3.0, 0.0), zone = "body" },
				{ position = Vector3.new(-1, 2.6, 1.6), zone = "rear" },
			}
			-- `Hits.group` reports the NEAREST impact as the shot's position; the report's dot is
			-- `Shape.dot` of that point, computed here independently of the card.
			local nearest = points[3].position
			local dots = Shape.cardDots(cf, BODY, points, nearest, "body")
			local leads, lead = 0, nil
			for _, dot in ipairs(dots) do
				if dot.lead then
					leads += 1
					lead = dot
				end
			end
			expect(leads).to.equal(1)
			local u, v = Shape.dot(cf, BODY, nearest)
			expect(math.abs((lead :: any).u - u) < 1e-9).to.equal(true)
			expect(math.abs((lead :: any).v - v) < 1e-9).to.equal(true)
		end)

		it("gives a slug exactly one dot", function()
			local cf = CFrame.new(0, 3, 0)
			local hit = Vector3.new(-1, 3.5, -1.0)
			local dots = Shape.cardDots(cf, BODY, { { position = hit, zone = "chest" } }, hit, "chest")
			expect(#dots).to.equal(1)
			expect(dots[1].lead).to.equal(true)
			-- ...and a report with no per-pellet detail at all -- everything written before this
			-- task -- still gets that one dot rather than an empty picture.
			local older = Shape.cardDots(cf, BODY, nil, hit, "chest")
			expect(#older).to.equal(1)
			expect(older[1].zone).to.equal("chest")
			expect(math.abs(older[1].u - dots[1].u) < 1e-9).to.equal(true)
		end)

		it("never carries more dots than the ceiling", function()
			local cf = CFrame.new(0, 3, 0)
			local points = {}
			for index = 1, Report.CONFIG.CARD.DOTS_MAX + 20 do
				table.insert(points, { position = Vector3.new(-1, 3, index % 3), zone = "body" })
			end
			expect(#Shape.cardDots(cf, BODY, points, points[1].position, "body")).to.equal(Report.CONFIG.CARD.DOTS_MAX)
		end)
	end)

	-- WHICH WAY ROUND THE ANIMAL IS DRAWN. Pure and shared, so the card and this file agree without
	-- a screen.
	describe("Report.cardFacing", function()
		it("mirrors only when most of the shot landed on the far flank", function()
			expect(Report.cardFacing({ { side = 1 }, { side = 1 }, { side = -1 } })).to.equal(false)
			expect(Report.cardFacing({ { side = -1 }, { side = -1 }, { side = 1 } })).to.equal(true)
			-- A tie keeps the report's own facing, so the default is always the one the player knows.
			expect(Report.cardFacing({ { side = 1 }, { side = -1 } })).to.equal(false)
			expect(Report.cardFacing({})).to.equal(false)
			expect(Report.cardFacing(nil)).to.equal(false)
		end)
	end)

	describe("Report.cardLabel", function()
		it("prints a fraction for a pattern and none for a single projectile", function()
			expect(Report.cardLabel("BUCK", 4, 9)).to.equal("HIT · BUCK 4/9")
			expect(Report.cardLabel("SLUG", 1, 1)).to.equal("HIT · SLUG")
			expect(Report.cardLabel(".416", 1, nil)).to.equal("HIT · .416")
		end)
	end)

	-- WHO GETS A CARD. The dispatch names two things it must never draw for.
	describe("HitLog.cardWorthy", function()
		it("is true only for a damageable target hit by a real shooter", function()
			local boar = fakeBoar("B2")
			local beater = fakeBeater()
			local shooter = Players:GetPlayers()[1]
			expect(shooter ~= nil).to.equal(true)
			expect(HitLog.cardWorthy(boar, shooter)).to.equal(true)
			-- A BEATER AND A TREE: no `Damageable`, so no card.
			expect(HitLog.cardWorthy(beater, shooter)).to.equal(false)
			-- Nobody fired it.
			expect(HitLog.cardWorthy(boar, nil)).to.equal(false)
			boar:Destroy()
			beater:Destroy()
		end)
	end)

	-- THE WHOLE SERVER PATH, with the real player this harness run has: a hit on an animal sends a
	-- card and a hit on anything else does not.
	describe("HitLog.recordHit and the card", function()
		it("sends one card per hit on an animal, and none for a beater or a miss", function()
			local shooter = Players:GetPlayers()[1]
			expect(shooter ~= nil).to.equal(true)
			HitLog.clear()
			HitLog.openDrive(9, 0)
			local boar = fakeBoar("B3")
			local beater = fakeBeater()

			local before = HitLog.stats()
			expect(before.cards).to.equal(0)

			local points = {
				{ position = Vector3.new(-1, 3.4, -1.5), zone = "chest" },
				{ position = Vector3.new(-1, 3.0, 0.0), zone = "body" },
			}
			expect(HitLog.recordHit(report(boar, shooter, points, { at = 1.0 }))).to.equal(true)
			expect(HitLog.stats().cards).to.equal(1)
			expect(HitLog.stats().cardlessHits).to.equal(0)

			-- A BEATER: the record is kept (that is `recordHit`'s own, older contract), the card is
			-- not sent, and the refusal is COUNTED rather than silent.
			expect(HitLog.recordHit(report(beater, shooter, points, { at = 2.0 }))).to.equal(true)
			expect(HitLog.stats().cards).to.equal(1)
			expect(HitLog.stats().cardlessHits).to.equal(1)

			-- A MISS: there is no report, so nothing reaches this function at all. `recordHit(nil)`
			-- is the nearest thing a spec can say, and it changes neither counter.
			expect(HitLog.recordHit(nil)).to.equal(false)
			expect(HitLog.stats().cards).to.equal(1)
			expect(HitLog.stats().cardlessHits).to.equal(1)

			boar:Destroy()
			beater:Destroy()
			HitLog.clear()
		end)

		it("puts one dot on the card per pellet, and a slug gets one", function()
			local shooter = Players:GetPlayers()[1]
			HitLog.clear()
			HitLog.openDrive(10, 0)
			local boar = fakeBoar("B4")
			-- The card is built inside `recordHit`, so it is read back the way the client would see
			-- it: the same arithmetic over the same part at the same instant.
			local points = {}
			for index = 1, 4 do
				table.insert(points, { position = Vector3.new(-1, 3.0 + index * 0.1, index * 0.5), zone = "body" })
			end
			local buck = Shape.cardDots(boar.CFrame, boar.Size, points, points[1].position, "body")
			expect(#buck).to.equal(4)
			local slug = Shape.cardDots(boar.CFrame, boar.Size, { points[1] }, points[1].position, "chest")
			expect(#slug).to.equal(1)
			expect(HitLog.recordHit(report(boar, shooter, points, { at = 3.0 }))).to.equal(true)
			expect(HitLog.stats().cards).to.equal(1)
			TestKit.note(string.format("hit card: %d dot(s) for a 4-pellet pattern, %d for a slug", #buck, #slug))
			boar:Destroy()
			HitLog.clear()
		end)
	end)
end

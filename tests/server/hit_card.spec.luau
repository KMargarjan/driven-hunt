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
local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
-- TASK 304: the range is FREE, so the one case that could disprove it reads the real purse.
local Economy = require(ServerScriptService:WaitForChild("Economy"))
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
		-- TASK 308: the CFrame the position and the points are expressed in, or nil for a
		-- present-tense impact (which is every case written before that task).
		targetCFrame = extra and extra.targetCFrame,
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
			expect(Report.cardLabel("BUCK", 4, 9)).to.equal("HIT - BUCK 4/9")
			expect(Report.cardLabel("SLUG", 1, 1)).to.equal("HIT - SLUG")
			expect(Report.cardLabel(".416", 1, nil)).to.equal("HIT - .416")
			-- ASCII ONLY, and a frame is why (see `Report.cardLabel`): a middle dot came out of
			-- BuilderSans as two missing-glyph boxes.
			for _, text in ipairs({ Report.cardLabel("BUCK", 4, 9), Report.cardLabel("SLUG", 1, 1) }) do
				for index = 1, #text do
					expect(string.byte(text, index) < 128).to.equal(true)
				end
			end
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
	-- TASK 308 BUG 3. Karen's Playtester, 2026-10-28: a nose shot at a RUNNING boar drew the dot in
	-- the white space behind the rump. `Weapon.Rewind` reports a rewound impact WHERE THE SHOOTER
	-- DREW the animal, and the card used to divide it down by the trunk's CFrame as read when the
	-- report arrived -- flight time plus replication later. At 24 studs/s that is ~13 studs on a
	-- 5.5-stud body, so u ran off the end.
	describe("the card's dots are in the frame the shot was judged in (task 308)", function()
		it("puts a nose hit at the nose even though the animal has travelled since", function()
			local shooter = Players:GetPlayers()[1]
			HitLog.clear()
			HitLog.openDrive(11, 0)
			local boar = fakeBoar("B308")
			-- WHERE THE SHOOTER SAW IT, and the nose is the front tip: `Shape.dot` puts -Z forward.
			local drawn = CFrame.new(0, 3, 0)
			local nose = drawn.Position + Vector3.new(0, 0, -BODY.Z / 2)
			-- ...AND WHERE THE SERVER HAS IT NOW: 13 studs further along its own travel.
			boar.CFrame = drawn + Vector3.new(0, 0, -13)

			expect(HitLog.recordHit(report(boar, shooter, { { position = nose, zone = "head" } }, {
				zone = "head",
				position = nose,
				at = 3.0,
				targetCFrame = drawn,
			}))).to.equal(true)
			local card = HitLog.lastCard() :: any
			expect(card).to.be.ok()
			expect(#card.dots).to.equal(1)
			-- THE NOSE END OF THE SILHOUETTE. Without the frame this reads 1.0 -- clamped off the
			-- tail -- which is the white space Karen's frame shows.
			expect(card.dots[1].u < 0.1).to.equal(true)

			-- THE KNOWN-BAD INPUT, from the same instrument: the same point with NO frame carried
			-- is still divided down by the present CFrame, and it lands at the far end.
			HitLog.clear()
			HitLog.openDrive(12, 0)
			expect(HitLog.recordHit(report(boar, shooter, { { position = nose, zone = "head" } }, {
				zone = "head",
				position = nose,
				at = 4.0,
			}))).to.equal(true)
			local stale = HitLog.lastCard() :: any
			expect(stale.dots[1].u > 0.9).to.equal(true)
			HitLog.clear()
		end)
	end)

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

		it("puts one dot on the card per pellet, and the card it SENT carries them", function()
			local shooter = Players:GetPlayers()[1]
			HitLog.clear()
			HitLog.openDrive(10, 100.0)
			local boar = fakeBoar("B4")
			local points = {}
			for index = 1, 4 do
				table.insert(points, { position = Vector3.new(-1, 3.0 + index * 0.1, index * 0.5), zone = "body" })
			end
			-- THE CARD `recordHit` ACTUALLY BUILT, not one this file rebuilds beside it (the
			-- Reviewer's note, round 1). `HitLog.lastCard()` is the window onto the real one.
			expect(HitLog.lastCard()).to.equal(nil)
			expect(HitLog.recordHit(report(boar, shooter, points, { at = 103.0 }))).to.equal(true)
			local card = HitLog.lastCard()
			expect(card).to.be.ok()
			expect((card :: any).kind).to.equal("hit")
			expect((card :: any).drive).to.equal(10)
			expect((card :: any).animal).to.equal("B4")
			expect((card :: any).hits).to.equal(4)
			-- ONE DOT PER PELLET, on the payload that went out.
			expect(#(card :: any).dots).to.equal(4)
			local leads = 0
			for _, dot in ipairs((card :: any).dots) do
				if dot.lead then
					leads += 1
				end
			end
			expect(leads).to.equal(1)

			-- AND `at` IS SECONDS SINCE THE DRIVE OPENED, NEVER A SERVER CLOCK -- the Reviewer's
			-- blocking finding of round 1, which this case is here to stop coming back. The drive
			-- opened at 100 and the shot is at 103, so the wire carries 3.
			expect(math.abs((card :: any).at - 3.0) < 1e-9).to.equal(true)
			TestKit.note(
				string.format(
					"hit card: %d dot(s) for a 4-pellet pattern, at=%.2f s since the drive opened",
					#(card :: any).dots,
					(card :: any).at
				)
			)

			-- A SLUG GETS ONE, through the same function.
			expect(HitLog.recordHit(report(boar, shooter, { points[1] }, { at = 104.0, zone = "chest" }))).to.equal(
				true
			)
			expect(#(HitLog.lastCard() :: any).dots).to.equal(1)
			boar:Destroy()
			HitLog.clear()
		end)
	end)

	-- ---------------------------------------------------------------- task 278
	--
	-- **WHERE THE PICTURE ACTUALLY IS INSIDE THE FRAME.** Karen, 2026-10-26: the card's red mark sat
	-- in empty space in front of a stag's chest, and behind a walking one. Measured on her own frame
	-- (`<runs-dir>/design/karen-hitcard-2026-10-26.png`): the stag's INK spans u 0.236..0.757 of the
	-- 148 x 80 art frame and the dot was drawn at u 0.118.
	--
	-- **THE ARITHMETIC BELOW IS THIS FILE'S OWN AND NEVER `Report.imageFit`'s**, which is the one
	-- thing that makes these cases worth running: a case that computes the expected answer with the
	-- function under test passes whatever that function does. `drawn()` is written out from the
	-- engine's documented rule for `ScaleType.Fit` -- "the image is scaled to fit inside the UI
	-- element while preserving its aspect ratio" -- and the numbers it produces for a stag
	-- (0.2326..0.7674) are the numbers measured off Karen's screenshot to three decimals.
	describe("the unit square sits on the drawn picture, not on the frame (task 278)", function()
		-- Where an image of `iw` x `ih` is drawn inside a `fw` x `fh` frame under `Fit`, as frame
		-- fractions. Independent of the code under test.
		local function drawn(iw: number, ih: number, fw: number, fh: number)
			local image, frame = iw / ih, fw / fh
			if image > frame then
				local tall = frame / image
				return { u0 = 0, u1 = 1, v0 = (1 - tall) / 2, v1 = (1 + tall) / 2 }
			end
			local wide = image / frame
			return { u0 = (1 - wide) / 2, u1 = (1 + wide) / 2, v0 = 0, v1 = 1 }
		end

		it("Report.imageFit answers the letterbox, the pillarbox and the unmeasured image", function()
			-- A STAG (750 x 758) IN THE CARD'S ART FRAME (148 x 80): pillarboxed into the middle
			-- 53.5 % of the width. This is the number that was missing.
			local stag = Report.imageFit({ w = 750, h = 758 }, 148, 80)
			local want = drawn(750, 758, 148, 80)
			expect(math.abs(stag.u0 - want.u0) < 1e-9).to.equal(true)
			expect(math.abs(stag.u1 - want.u1) < 1e-9).to.equal(true)
			expect(stag.v0).to.equal(0)
			expect(stag.v1).to.equal(1)
			expect(math.abs(stag.u0 - 0.232582) < 1e-5).to.equal(true)

			-- A MALE BOAR (946 x 474) IS WIDER THAN THE FRAME, so it letterboxes instead -- a bar
			-- above and below, and the full width. That is why the two boars looked nearly right.
			local male = Report.imageFit({ w = 946, h = 474 }, 148, 80)
			local wantMale = drawn(946, 474, 148, 80)
			expect(male.u0).to.equal(0)
			expect(male.u1).to.equal(1)
			expect(math.abs(male.v0 - wantMale.v0) < 1e-9).to.equal(true)

			-- NO MEASUREMENT -> THE WHOLE FRAME, which is every caller before this task.
			for _, bad in ipairs({ "nothing", 0 }) do
				local none = Report.imageFit(if bad == 0 then { w = 0, h = 0 } else nil, 148, 80)
				expect(none.u0).to.equal(0)
				expect(none.u1).to.equal(1)
				expect(none.v0).to.equal(0)
				expect(none.v1).to.equal(1)
			end
			TestKit.note(
				string.format("hit card: a stag is drawn across u %.3f..%.3f of the art frame", stag.u0, stag.u1)
			)
		end)

		it("puts every kind's unit square inside the rectangle its picture is drawn in", function()
			-- THE CASE THAT FAILS ON THE COMMIT BEFORE THIS ONE. The stag's box was being written
			-- as u 0.000..1.000 of the FRAME while the picture only reaches 0.2326..0.7674 of it,
			-- so the first third of every stag card was bare plate that dots were drawn on.
			local width, height = Report.CONFIG.CARD.ART_WIDTH, Report.CONFIG.CARD.ART_HEIGHT
			local worst = 0
			for _, kind in ipairs({ "male", "female", "cub", "stag", "hind", "calf" }) do
				local chosen = Report.boarImage(kind)
				expect(chosen.px).to.be.ok()
				local box = Report.imageBox(chosen, width, height)
				-- The LABEL is `chosen.scale` of the frame, centred; the IMAGE is drawn inside the
				-- label. Both steps, this file's own arithmetic.
				local inset = (1 - chosen.scale) / 2
				local fit = drawn(chosen.px.w, chosen.px.h, width, height)
				local lo = { u = inset + chosen.scale * fit.u0, v = inset + chosen.scale * fit.v0 }
				local hi = { u = inset + chosen.scale * fit.u1, v = inset + chosen.scale * fit.v1 }
				expect(box.u0 >= lo.u - 1e-9).to.equal(true)
				expect(box.u1 <= hi.u + 1e-9).to.equal(true)
				expect(box.v0 >= lo.v - 1e-9).to.equal(true)
				expect(box.v1 <= hi.v + 1e-9).to.equal(true)
				-- ...AND IT STILL SPANS THE ANIMAL. A box shrunk onto the torso keeps every dot on
				-- black and stops meaning where the shot landed -- task 205's own refusal, kept.
				local spanU = (box.u1 - box.u0) / (hi.u - lo.u)
				local spanV = (box.v1 - box.v0) / (hi.v - lo.v)
				-- THE FLOOR IS 0.75 SINCE TASK 283, and the hind is why: her body's ends, measured on
				-- her own picture, are u 0.140..0.918 of it (0.778), because her head and neck are drawn
				-- forward of her chest and reach the left edge. The guard still refuses a box shrunk onto
				-- the torso; it no longer refuses the measurement.
				expect(spanU >= 0.75).to.equal(true)
				expect(spanV >= 0.45).to.equal(true)
				worst = math.max(worst, math.abs(box.u0 - lo.u))
				TestKit.note(
					string.format(
						"hit card: %s box u %.3f..%.3f v %.3f..%.3f, picture drawn at u %.3f..%.3f v %.3f..%.3f",
						kind,
						box.u0,
						box.u1,
						box.v0,
						box.v1,
						lo.u,
						hi.u,
						lo.v,
						hi.v
					)
				)
			end
			expect(worst < 0.2).to.equal(true)
		end)

		it("writes one hit-log line per hit, with the offset the dot was measured from", function()
			-- `Shape.traceLine` IS PURE, so the format is checked here and the ring is checked where
			-- it is written. Every field is one the hit already carries.
			local line = Shape.traceLine({
				index = 3,
				at = 12.8437,
				kind = "stag",
				id = "Animal_7",
				zone = "chest",
				offset = Vector3.new(-0.42, 0.91, -1.07),
				u = 0.3512,
				v = 0.3107,
				distance = 118.63,
				weapon = "rifle.scoped",
				ammo = "Slug",
				pellets = 1,
				fatal = false,
			})
			expect(string.find(line, "#3 t=12.84s stag id=Animal_7 zone=chest", 1, true)).to.be.ok()
			expect(string.find(line, "local=(-0.42,0.91,-1.07)", 1, true)).to.be.ok()
			expect(string.find(line, "uv=(0.351,0.311)", 1, true)).to.be.ok()
			expect(string.find(line, "dist=118.6 rifle.scoped/Slug pellets=1 fatal=no", 1, true)).to.be.ok()
			-- A ROW WITH NOTHING IN IT STILL MAKES A LINE rather than raising on the server at the
			-- instant of a shot, which is the one thing an instrument must never do.
			expect(#Shape.traceLine({}) > 0).to.equal(true)
			TestKit.note("hit card: " .. line)
		end)

		it("keeps the last ten hits, newest last, and clears with the drive", function()
			-- THE RING, WHERE IT IS WRITTEN. `recordHit` is the one caller, so this drives the real
			-- function with a real part and reads what came out -- not a second copy of the format.
			HitLog.clear()
			HitLog.openDrive(1, 100.0)
			local boar = fakeBoar("B_LOG")
			-- A REAL PLAYER, because `recordHit` sends the card to the shooter and `FireClient`
			-- refuses anything that is not one ("Unable to cast value to Object"). The cases above
			-- that pass a table never reach that line.
			local shooter = Players:GetPlayers()[1]
			for n = 1, 12 do
				expect(HitLog.recordHit(report(boar, shooter, nil, { at = 100.0 + n, zone = "chest" }))).to.equal(true)
			end
			local kept = HitLog.lastHits()
			expect(#kept).to.equal(10)
			-- NEWEST LAST, and the index is the hit's own count -- so a gap in the numbers is a shot
			-- that never reached the server.
			expect(string.find(kept[1], "#3 ", 1, true)).to.equal(1)
			expect(string.find(kept[10], "#12 ", 1, true)).to.equal(1)
			expect(string.find(kept[10], "zone=chest", 1, true)).to.be.ok()
			expect(string.find(kept[10], "id=B_LOG", 1, true)).to.be.ok()
			TestKit.note("hit card: ring tail -> " .. kept[10])
			HitLog.clear()
			expect(#HitLog.lastHits()).to.equal(0)
			boar:Destroy()
		end)
	end)
	-- ---------------------------------------------------------------- TASK 304: THE RANGE'S CARD
	--
	-- KAREN, 2026-10-28, shooting the lobby range: *"hit card will be usefull"*. A range hit gets the
	-- SAME card off the SAME builder, and the range is scored by NOTHING (shooting-range design
	-- section 1), so it writes no drive row, no dot, no kill and no money.
	--
	-- EVERY CASE BITES. `sendCard` stubbed to send nothing leaves `HitLog.lastCard()` nil and
	-- `stats.cards` at 0; the row guard removed puts the animal back in the drive's own record.
	describe("HitLog.sendCard: the range's hit card, with no row behind it", function()
		-- THE LANE'S ANIMAL: the same trunk, inside the folder `RangeBoot` names
		-- (`RangeData.TARGETS_FOLDER`), which is the one thing that tells it from the drive's.
		local function laneTarget(id: string, kind: string): (BasePart, Folder)
			local folder = Instance.new("Folder")
			folder.Name = RangeData.TARGETS_FOLDER
			local part = fakeBoar(id)
			part:SetAttribute("Kind", kind)
			part.Parent = folder
			return part, folder
		end

		it("sends ONE card for a boar and for a red deer, and writes no row, no dot and no money", function()
			local shooter = Players:GetPlayers()[1]
			expect(shooter ~= nil).to.equal(true)
			for _, kind in ipairs({ "male", "hind" }) do
				HitLog.clear()
				-- A DRIVE IS OPEN, which is Karen's own case: her place runs drives while she stands
				-- at the lobby range, and that is exactly when a lane hit used to be written a row.
				HitLog.openDrive(304, 0)
				local part, folder = laneTarget("R-" .. kind, kind)

				-- BEFORE, OFF THE REAL STORES.
				local before = HitLog.stats()
				local coinsBefore = Economy.balanceOf((shooter :: any).UserId)
				expect(before.cards).to.equal(0)
				expect(before.hits).to.equal(0)
				expect(HitLog.lastCard()).to.equal(nil)
				expect((HitLog.currentDrive() :: any).animalCount).to.equal(0)

				local points = {
					{ position = part.Position + Vector3.new(-1, 0.4, -1.5), zone = "chest" },
					{ position = part.Position + Vector3.new(-1, 0.0, 0.0), zone = "body" },
				}
				local fired = report(part, shooter, points, { at = 1.0, zone = "chest", nearest = 125 })
				expect(HitLog.sendCard(fired)).to.equal(true)

				-- AFTER: ONE CARD, and it is the card that WENT OUT (`lastCard`), not one rebuilt here.
				local after = HitLog.stats()
				expect(after.cards).to.equal(1)
				expect(after.rangeCards).to.equal(1)
				local card = HitLog.lastCard() :: any
				expect(card).to.be.ok()
				expect(card.kind).to.equal("hit")
				expect(card.animal).to.equal(part.Name)
				expect(card.animalKind).to.equal(kind)
				expect(card.hits).to.equal(2)
				expect(#card.dots).to.equal(2)
				expect(card.distance).to.equal(125)
				-- THE SAME PROJECTION THE HUNT USES, computed here off `Shape.dot` and found on the
				-- card: the card re-derives nothing (`buildCard` is the one builder).
				local u, v = Shape.dot(part.CFrame, part.Size, points[1].position)
				local found = false
				for _, dot in ipairs(card.dots) do
					if math.abs(dot.u - u) < 1e-6 and math.abs(dot.v - v) < 1e-6 then
						found = true
					end
				end
				expect(found).to.equal(true)

				-- ...AND NOTHING WAS SCORED. No row, no dot, no kill line, no money.
				expect(after.hits).to.equal(before.hits)
				expect(after.downs).to.equal(before.downs)
				expect((HitLog.currentDrive() :: any).animalCount).to.equal(0)
				expect(Economy.balanceOf((shooter :: any).UserId)).to.equal(coinsBefore)

				-- ...BUT IT DOES WRITE THE RING (task 309a). The range's hit path was the one hit
				-- path with no `DHLastHits` line, so `tools/aim_bench.py` could print a zone word
				-- and never the LOCAL OFFSET that zone was read out of (CLAUDE.md rule L).
				expect(after.traced).to.equal(before.traced + 1)
				local ring = HitLog.lastHits()
				expect(#ring).to.equal(1)
				-- THE OFFSET IS THE STRUCK POINT IN THE ANIMAL'S OWN FRAME, and it is checked against
				-- the arithmetic rather than against a substring. It is the REPORT'S OWN `position`
				-- -- the nearest impact of the pattern, which is what `recordHit` divides down too --
				-- and not `points[1]`, which is one pellet of it.
				local want = part.CFrame:PointToObjectSpace(fired.position)
				expect(
					string.find(ring[1], string.format("local=(%.2f,%.2f,%.2f)", want.X, want.Y, want.Z), 1, true)
						~= nil
				).to.equal(true)
				expect(string.find(ring[1], "zone=chest", 1, true) ~= nil).to.equal(true)
				expect(string.find(ring[1], "id=" .. part.Name, 1, true) ~= nil).to.equal(true)
				expect(string.find(ring[1], "fatal=no", 1, true) ~= nil).to.equal(true)

				-- ...AND IT IS THE REPORT'S OWN TENSE, which is the whole of task 309a (round 1,
				-- note). The pass above leaves `targetCFrame` nil, so it reads the same whether the
				-- line divides down by `frameOf` or by `part.CFrame`; this one hands in the frame
				-- the shooter DREW the animal in -- 6 studs back, the distance a boar covers over
				-- the rewind -- so the two answers differ by 6 studs and only the carried one is
				-- inside the body.
				HitLog.clear()
				HitLog.openDrive(309, 0)
				local drawnFrame = part.CFrame * CFrame.new(0, 0, 6)
				local rewound = report(part, shooter, points, {
					at = 2.0,
					zone = "chest",
					nearest = 125,
					position = drawnFrame.Position + Vector3.new(-1, 0.4, 1),
					targetCFrame = drawnFrame,
				})
				expect(HitLog.sendCard(rewound)).to.equal(true)
				local tensed = HitLog.lastHits()
				expect(#tensed).to.equal(1)
				local wantTense = drawnFrame:PointToObjectSpace(rewound.position)
				expect(
					string.find(
						tensed[1],
						string.format("local=(%.2f,%.2f,%.2f)", wantTense.X, wantTense.Y, wantTense.Z),
						1,
						true
					) ~= nil
				).to.equal(true)
				-- THE KNOWN-BAD HALF: the SAME point divided by the present trunk is 6 studs away,
				-- so a line that had ignored `targetCFrame` could not pass the case above.
				local wrongTense = part.CFrame:PointToObjectSpace(rewound.position)
				expect(math.abs(wrongTense.Z - wantTense.Z)).to.be.near(6, 1e-3)

				part:Destroy()
				folder:Destroy()
				HitLog.clear()
			end
		end)

		it("sends NOTHING for a miss, for a shot by nobody and for a part that is not an animal", function()
			local shooter = Players:GetPlayers()[1]
			HitLog.clear()
			HitLog.openDrive(304, 0)
			local part, folder = laneTarget("R-miss", "male")
			local coinsBefore = Economy.balanceOf((shooter :: any).UserId)

			-- A MISS: `Weapon.Hits.group` makes no report at all, so nothing reaches this function.
			-- `sendCard(nil)` is the nearest thing a spec can say, and it sends nothing.
			expect(HitLog.sendCard(nil)).to.equal(false)
			expect(HitLog.sendCard({ shooter = shooter })).to.equal(false)
			expect(HitLog.lastCard()).to.equal(nil)
			expect(HitLog.stats().cards).to.equal(0)
			-- NOBODY FIRED IT, and a part with no `Damageable`: `cardWorthy` refuses both, counted.
			expect(HitLog.sendCard(report(part, nil, nil, {}))).to.equal(false)
			expect(HitLog.sendCard(report(fakeBeater(), shooter, nil, {}))).to.equal(false)
			expect(HitLog.stats().cards).to.equal(0)
			expect(HitLog.stats().cardlessHits).to.equal(2)
			expect(HitLog.lastCard()).to.equal(nil)
			-- ...AND NO RING LINE EITHER (task 309a). The known-bad half of the new instrument: a
			-- shot the range refuses a card for must leave `DHLastHits` empty, or every bench row
			-- would read "the server answered" whatever the bullet did.
			expect(HitLog.stats().traced).to.equal(0)
			expect(#HitLog.lastHits()).to.equal(0)
			-- THE MISS SIDE OF THE STORE READ (the same instrument as the hit case above).
			expect(HitLog.stats().hits).to.equal(0)
			expect((HitLog.currentDrive() :: any).animalCount).to.equal(0)
			expect(#HitLog.lastHits()).to.equal(0)
			expect(Economy.balanceOf((shooter :: any).UserId)).to.equal(coinsBefore)

			part:Destroy()
			folder:Destroy()
			HitLog.clear()
		end)

		it("refuses a ROW for a lane target while writing one for the drive's own animal", function()
			local shooter = Players:GetPlayers()[1]
			HitLog.clear()
			HitLog.openDrive(304, 0)
			local lane, folder = laneTarget("R-row", "male")
			local wild = fakeBoar("W-row")

			-- THE LANE'S: refused, and COUNTED rather than silent.
			expect(HitLog.rowWorthy(lane)).to.equal(false)
			expect(HitLog.recordHit(report(lane, shooter, nil, { at = 1.0 }))).to.equal(false)
			expect(HitLog.stats().rangeHits).to.equal(1)
			expect(HitLog.stats().hits).to.equal(0)
			expect(HitLog.stats().cards).to.equal(0)
			expect((HitLog.currentDrive() :: any).animalCount).to.equal(0)

			-- THE DRIVE'S OWN, THE SAME CALL, THE SAME FRAME: a row and a card. This is the half
			-- that makes the case above a difference and not a tautology.
			expect(HitLog.rowWorthy(wild)).to.equal(true)
			expect(HitLog.recordHit(report(wild, shooter, nil, { at = 2.0 }))).to.equal(true)
			expect(HitLog.stats().hits).to.equal(1)
			expect(HitLog.stats().cards).to.equal(1)
			expect((HitLog.currentDrive() :: any).animalCount).to.equal(1)
			expect(HitLog.stats().rangeHits).to.equal(1)

			lane:Destroy()
			folder:Destroy()
			wild:Destroy()
			HitLog.clear()
		end)
	end)
end

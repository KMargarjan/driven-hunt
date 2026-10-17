-- hit_card.spec: THE HIT CARD, in the real client, on the real Hud (task 198).
--
-- Karen, 2026-10-16: *"so once we hit boar we can show where it has been hitted / red dot will
-- indicate so if shells then several of them / so somewhere in corner after hit we indicate where it
-- landed"*.
--
-- WHAT IT PROVES AND WHAT IT CANNOT. No harness run makes a real shot land on a real boar, so this
-- does what `report_panel.spec` does: it hands the card the exact payload the wire would carry and
-- then reads the SCREEN -- the frame's visibility, the label, and a `Frame` per dot at the (u, v)
-- the payload asked for. That is the one check `docs/PROJECT_CONTEXT.md`'s *"a visibility audit
-- certified a blank screen twice"* demands.
--
-- THE CASE THAT MATTERS MOST is the last one: ONE payload is shown on the card and the SAME dot is
-- sent through the drive report's own detail view, and the two pictures are then read with the same
-- reader. The card and the TAB report cannot put one hit in two places and have this pass.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-10-17-hit-card.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Report = require(ReplicatedStorage:WaitForChild("Report"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))

local Card = Hud.HitCard
local CONFIG = Report.CONFIG.CARD

-- Four pellets on the near flank, as `HitLog.Shape.cardDots` builds them.
local function buckPayload()
	return {
		kind = "hit",
		drive = 4,
		animal = "B-198",
		animalKind = "male",
		weapon = "shotgun",
		ammo = "Buck",
		hits = 4,
		fired = 9,
		distance = 54,
		at = 12.5,
		dots = {
			{ u = 0.31, v = 0.34, side = 1, zone = "chest", lead = false },
			{ u = 0.44, v = 0.41, side = 1, zone = "body", lead = true },
			{ u = 0.52, v = 0.29, side = 1, zone = "chest", lead = false },
			{ u = 0.63, v = 0.55, side = 1, zone = "body", lead = false },
		},
	}
end

local function slugPayload()
	return {
		kind = "hit",
		drive = 4,
		animal = "B-199",
		animalKind = "female",
		weapon = "shotgun",
		ammo = "Slug",
		hits = 1,
		fired = 1,
		distance = 143,
		at = 20.0,
		dots = { { u = 0.40, v = 0.30, side = 1, zone = "chest", lead = true } },
	}
end

local function overlaps(a: GuiObject, b: GuiObject): boolean
	local ap, as = a.AbsolutePosition, a.AbsoluteSize
	local bp, bs = b.AbsolutePosition, b.AbsoluteSize
	return ap.X < bp.X + bs.X and bp.X < ap.X + as.X and ap.Y < bp.Y + bs.Y and bp.Y < ap.Y + as.Y
end

return function()
	afterEach(function()
		Card.hide()
	end)

	describe("the frame", function()
		it("exists, is empty at rest, and sits over the scope's mask and under the report", function()
			local frame = Hud.hitCard()
			expect(frame).to.be.ok()
			expect((frame :: Frame).Visible).to.equal(false)
			expect((frame :: Frame).ZIndex).to.equal(CONFIG.Z_INDEX)
			-- OVER THE SCOPE'S MASK (11-13): a hunter who has just fired through the scope is the
			-- player this card is for. UNDER the report (15), which the player opened on purpose.
			expect(CONFIG.Z_INDEX > 13).to.equal(true)
			expect(CONFIG.Z_INDEX < Report.CONFIG.PANEL_Z_INDEX).to.equal(true)
			expect(#Card.dots()).to.equal(0)
		end)

		it("draws nothing for anything that is not a payload", function()
			Card.show(nil)
			expect(Card.isVisible()).to.equal(false)
			Card.show("not a table")
			expect(Card.isVisible()).to.equal(false)
			expect(#Card.dots()).to.equal(0)
		end)
	end)

	describe("one shot", function()
		it("puts one red dot per pellet, at the (u, v) the server measured", function()
			local payload = buckPayload()
			Card.show(payload)
			expect(Card.isVisible()).to.equal(true)
			local dots = Card.dots()
			expect(#dots).to.equal(4)
			for index, dot in ipairs(dots) do
				expect(math.abs(dot.u - payload.dots[index].u) < 1e-6).to.equal(true)
				expect(math.abs(dot.v - payload.dots[index].v) < 1e-6).to.equal(true)
				expect(dot.zone).to.equal(payload.dots[index].zone)
			end
			-- RED, and Karen's reference is why: *"a black boar image ... and red dot"*. Read off the
			-- Instance rather than off the config, so a dot drawn in the report's white would fail.
			local art = (Hud.hitCard() :: Frame):FindFirstChild("Plate")
			local pip = (art :: Frame):FindFirstChild("Art"):FindFirstChild("Dot")
			expect((pip :: Frame).BackgroundColor3).to.equal(CONFIG.DOT_COLOR)
		end)

		it("gives a slug exactly one dot and a label with no fraction", function()
			Card.show(slugPayload())
			expect(#Card.dots()).to.equal(1)
			expect(string.find(Card.labelText(), "/") == nil).to.equal(true)
			expect(string.find(Card.labelText(), "S L U G") ~= nil).to.equal(true)
		end)

		it("names the pattern and how much of it landed", function()
			Card.show(buckPayload())
			expect(Card.labelText()).to.equal(string.gsub(string.gsub("HIT · BUCK 4/9", "(.)", "%1 "), "%s+$", ""))
		end)

		it("replaces the card rather than stacking a second one", function()
			Card.show(buckPayload())
			expect(#Card.dots()).to.equal(4)
			Card.show(slugPayload())
			-- One card, one shot: the second hit left exactly its own dot behind.
			expect(#Card.dots()).to.equal(1)
			expect(Card.isVisible()).to.equal(true)
		end)

		it("turns the animal round when the shot came in on the far flank", function()
			-- The drawn x of every dot, in the order they were made, off the Instances themselves.
			local function drawnX(artName: string): { number }
				local plate = (Hud.hitCard() :: Frame):FindFirstChild("Plate") :: Frame
				local art = plate:FindFirstChild(artName) :: Frame
				local out = {}
				for _, child in ipairs(art:GetChildren()) do
					if child:IsA("Frame") and child.Name == "Dot" then
						table.insert(out, child.Position.X.Scale)
					end
				end
				return out
			end

			Card.show(buckPayload())
			expect(Card.mirrored()).to.equal(false)
			local near = drawnX("Art")
			expect(#near).to.equal(4)

			local far = buckPayload()
			for _, dot in ipairs(far.dots) do
				dot.side = -1
			end
			Card.show(far)
			expect(Card.mirrored()).to.equal(true)
			local mirrored = drawnX("ArtMirrored")
			expect(#mirrored).to.equal(4)
			-- EVERY MARK WENT WITH THE PICTURE: the drawn x is exactly 1 - x, which is the only way
			-- a dot can stay on the part of the animal it hit when the animal is turned round.
			for index, x in ipairs(mirrored) do
				expect(math.abs(x - (1 - near[index])) < 1e-5).to.equal(true)
			end
			-- ...and the near-flank picture was cleared, so one card never shows two animals.
			expect(#drawnX("Art")).to.equal(0)
		end)
	end)

	describe("the clock", function()
		it("holds for about three seconds, fades, and then is gone", function()
			Card.show(buckPayload())
			Card.step(CONFIG.HOLD_SECONDS - 0.1)
			expect(Card.isVisible()).to.equal(true)
			expect(math.abs((Hud.hitCard() :: Frame).BackgroundTransparency - CONFIG.PANEL_TRANSPARENCY) < 1e-4).to.equal(
				true
			)
			-- Into the fade: still up, but on its way out.
			Card.step(0.2 + CONFIG.FADE_SECONDS / 2)
			expect(Card.isVisible()).to.equal(true)
			expect((Hud.hitCard() :: Frame).BackgroundTransparency > CONFIG.PANEL_TRANSPARENCY + 1e-3).to.equal(true)
			Card.step(CONFIG.FADE_SECONDS)
			expect(Card.isVisible()).to.equal(false)
			expect(#Card.dots()).to.equal(0)
		end)
	end)

	describe("the kill", function()
		it("marks the lead dot when the shot turns out to be the fatal one", function()
			local payload = buckPayload()
			Card.show(payload)
			local fatals = 0
			for _, dot in ipairs(Card.dots()) do
				if dot.fatal then
					fatals += 1
				end
			end
			expect(fatals).to.equal(0)
			Card.markFatal({ kind = "hitFatal", animal = payload.animal, at = payload.at })
			fatals = 0
			local marked = nil
			for _, dot in ipairs(Card.dots()) do
				if dot.fatal then
					fatals += 1
					marked = dot
				end
			end
			expect(fatals).to.equal(1)
			-- ...and it is the LEAD dot, which is the one the drive report draws for this shot.
			expect(math.abs((marked :: any).u - payload.dots[2].u) < 1e-6).to.equal(true)
		end)

		it("ignores a kill that belongs to another animal or another shot", function()
			local payload = buckPayload()
			Card.show(payload)
			Card.markFatal({ kind = "hitFatal", animal = "SOMEBODY-ELSE", at = payload.at })
			Card.markFatal({ kind = "hitFatal", animal = payload.animal, at = payload.at + 5 })
			for _, dot in ipairs(Card.dots()) do
				expect(dot.fatal).to.equal(false)
			end
		end)
	end)

	-- THE CASE THE DISPATCH ASKS FOR IN WORDS: *"the card next to the TAB report for the same hit:
	-- the dots must match"*. ONE hit, put through BOTH screens, read back with the same reader.
	describe("the card and the drive report agree about where the hit was", function()
		it("draws the lead dot of one shot in the same place on both", function()
			local payload = buckPayload()
			local lead = payload.dots[2]
			Card.show(payload)
			-- The drive report's detail row for the SAME animal and the SAME shot: `HitLog` records
			-- one dot per (shot, target), and it is the lead one.
			local Panel = Hud.Report
			local was = Panel.isOpen()
			Panel.render({
				view = "detail",
				drive = payload.drive,
				userId = player.UserId,
				name = player.Name,
				page = 1,
				pages = 1,
				rows = {
					{
						id = payload.animal,
						kind = payload.animalKind,
						result = "wounded",
						zone = lead.zone,
						distance = payload.distance,
						hits = 1,
						droppedHits = 0,
						at = payload.at,
						weapon = payload.weapon,
						dots = {
							{
								userId = player.UserId,
								name = player.Name,
								zone = lead.zone,
								u = lead.u,
								v = lead.v,
								side = lead.side,
								distance = payload.distance,
								pellets = payload.hits,
								at = payload.at,
								fatal = false,
							},
						},
					},
				},
			})
			local reportDots = Panel.dots()
			expect(#reportDots).to.equal(1)
			local found = false
			for _, dot in ipairs(Card.dots()) do
				if math.abs(dot.u - reportDots[1].u) < 1e-6 and math.abs(dot.v - reportDots[1].v) < 1e-6 then
					found = true
				end
			end
			expect(found).to.equal(true)
			expect(reportDots[1].zone).to.equal(lead.zone)
			Panel.setOpen(was)
		end)
	end)

	describe("the rectangles do not overlap", function()
		it("keeps the card clear of the feed, the readout, the compass, the bar and the map", function()
			-- The same measurement `map_ui.spec` makes, and for the same reason: task 125 round 2
			-- shipped a strip over the clock and the frames did not show it. Every other element is
			-- made visible for the measurement and put back exactly as it was.
			local screen = Hud.gui() :: ScreenGui
			local card = Hud.hitCard() :: Frame
			local others = {}
			for _, name in ipairs({ "Feed", "Readout", "Compass", "DriveBar", "ObjectiveLine", "MiniMap", "Rail" }) do
				local node = screen:FindFirstChild(name)
				if node ~= nil and node:IsA("GuiObject") then
					table.insert(others, { node = node :: GuiObject, was = (node :: GuiObject).Visible })
				end
			end
			for _, entry in ipairs(others) do
				entry.node.Visible = true
			end
			Card.show(buckPayload())
			task.wait()
			local clashes = {}
			for _, entry in ipairs(others) do
				if overlaps(card, entry.node) then
					table.insert(clashes, entry.node.Name)
				end
			end
			for _, entry in ipairs(others) do
				entry.node.Visible = entry.was
			end
			expect(table.concat(clashes, ", ")).to.equal("")
		end)
	end)
end

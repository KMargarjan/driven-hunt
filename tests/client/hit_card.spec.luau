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
-- THE CARD-AGAINST-REPORT CASE PROVES ONE THING AND NOT ANOTHER, and the Reviewer was right to say
-- so (round 1): both sides are read through `BoarArt.dotsOf`, which returns the `U`/`V` ATTRIBUTES --
-- the true `(u, v)` the server measured -- and not the drawn pixel. So it proves that one hit put on
-- both screens leaves a dot carrying the SAME `(u, v)` and the same zone on each, which is what
-- "the dots must match" means for a record; it does NOT prove the two pixels coincide, and a card
-- that drew every pip in the wrong place would still pass it. The drawn position is checked
-- separately, against arithmetic this file does itself, in the mirror case.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note: docs/research/2026-10-17-hit-card.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Report = require(ReplicatedStorage:WaitForChild("Report"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

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

-- ONE PAYLOAD, ONE KIND (task 205): the card picks Karen's male or female silhouette from the
-- record's own `animalKind`, so a case about the picture needs to vary exactly that.
local function payloadFor(kind: string)
	local payload = slugPayload()
	payload.animalKind = kind
	return payload
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
			expect(Card.labelText()).to.equal(string.gsub(string.gsub("HIT - BUCK 4/9", "(.)", "%1 "), "%s+$", ""))
		end)

		it("replaces the card rather than stacking a second one", function()
			Card.show(buckPayload())
			expect(#Card.dots()).to.equal(4)
			Card.show(slugPayload())
			-- One card, one shot: the second hit left exactly its own dot behind.
			expect(#Card.dots()).to.equal(1)
			expect(Card.isVisible()).to.equal(true)
		end)

		-- IT USED TO TURN THE ANIMAL ROUND, AND IT NO LONGER CAN (task 205 round 2). This case was
		-- written for the fourteen-`Frame` drawing, which mirrors by LAYING THE PARTS OUT THE OTHER
		-- WAY; Karen's silhouette is one image, and this engine cannot flip one -- measured in Play
		-- with three labels on one plate (`.screenshots/20261018T173406Z-t205-mirror-probe.png`): a
		-- negative `Size.X` draws the image unflipped and a negative `ImageRectSize` draws nothing.
		--
		-- SO THE CLAIM CHANGES WITH THE DRAWING, and it is the same claim underneath: THE DOTS AND
		-- THE PICTURE AGREE. They used to agree at `1 - x`; they now agree at `x`, because neither
		-- is flipped -- which is what keeps a head shot on the head. What is lost is the facing,
		-- and that is stated in `BoarArt.setKind` rather than hidden here.
		it("keeps every mark where it struck when the shot came in on the far flank", function()
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
			-- EVERY MARK IS WHERE IT STRUCK, which is the drawn x of the near flank: the picture is
			-- not flipped (it cannot be) and neither are the dots, so the two agree.
			local plateFar = (Hud.hitCard() :: Frame):FindFirstChild("Plate") :: Frame
			local artFar = plateFar:FindFirstChild("ArtMirrored") :: Frame
			expect(artFar:GetAttribute("Mirrored")).to.equal(false)
			for index, x in ipairs(mirrored) do
				expect(math.abs(x - near[index]) < 1e-5).to.equal(true)
			end
			-- ...and the near-flank picture was cleared, so one card never shows two animals.
			expect(#drawnX("Art")).to.equal(0)
		end)
	end)

	-- TASK 205. Karen, 2026-10-18, looking at `karen-2026-10-18/shot-4.png`: *"and what is that? you
	-- need proper image for wildboar when showing hit now it feels mess unclear wtf ? / it's in
	-- download male named"*. Her two silhouettes replace the fourteen `Frame`s.
	describe("Karen's silhouette", function()
		it("draws ONE image and picks it by the record's kind", function()
			local male = Report.boarImage("male")
			local female = Report.boarImage("female")
			-- THE TWO ARE DIFFERENT PICTURES, which is the whole point of sending the kind.
			expect(male.id).never.to.equal(female.id)
			expect(string.find(male.id, "rbxassetid://", 1, true)).to.equal(1)
			expect(string.find(female.id, "rbxassetid://", 1, true)).to.equal(1)
			-- A PIGLET IS THE SOW, SMALLER, and it is said out loud rather than hidden.
			local piglet = Report.boarImage("cub")
			expect(piglet.id).to.equal(female.id)
			expect(piglet.scale).to.equal(Report.CONFIG.PIGLET_SCALE)
			expect(piglet.scale < 1).to.equal(true)
			expect(male.scale).to.equal(1)
			-- An unknown kind -- a record from before the kinds, or a world with KINDS off -- is a
			-- boar and never nothing.
			expect(Report.boarImage(nil).id).to.equal(male.id)
			expect(Report.boarImage("wildebeest").id).to.equal(male.id)

			-- ...AND THE SCREEN FOLLOWS. The card is handed a female's payload and the drawn
			-- `ImageLabel` is the sow.
			Hud.HitCard.show(payloadFor("female"))
			local art = Hud.HitCard.art()
			expect(art).to.be.ok()
			local picture = (art :: Frame):FindFirstChild("Silhouette")
			expect(picture).to.be.ok()
			expect((picture :: ImageLabel):IsA("ImageLabel")).to.equal(true)
			expect((picture :: ImageLabel).Image).to.equal(female.id)
			Hud.HitCard.show(payloadFor("male"))
			local after = (Hud.HitCard.art() :: Frame):FindFirstChild("Silhouette") :: ImageLabel
			expect(after.Image).to.equal(male.id)
			-- `Fit`, because the two PNGs are different shapes and a stretched boar is the thing
			-- she could not read.
			expect(after.ScaleType).to.equal(Enum.ScaleType.Fit)
			TestKit.note("hit_card: male " .. male.id .. " female " .. female.id)
		end)

		it("SPREADS pellets that landed in the same place, so every hit is visible", function()
			-- KAREN, 2026-10-17: *"if same place spread if not same show spread"*. A buckshot
			-- pattern puts up to eighteen pellets inside a hand's width of animal and at this scale
			-- they land on top of one another -- one dot, and no way to tell a graze from a pattern.
			local BoarArt = Hud.BoarArt
			local same = {}
			for _ = 1, 9 do
				table.insert(same, { u = 0.5, v = 0.5 })
			end
			local fanned = BoarArt.spread(same, 7, 148, 80)
			expect(#fanned).to.equal(#same)
			-- EVERY ONE OF THEM IS SOMEWHERE ELSE: nine pellets at one point draw nine dots.
			local seen = {}
			for _, dot in ipairs(fanned) do
				local key = string.format("%.4f,%.4f", dot.u, dot.v)
				expect(seen[key]).to.equal(nil)
				seen[key] = true
			end
			-- ...AND THEY STAY WHERE THE SHOT WAS: the fan is about the group's own centre.
			local cu, cv = 0, 0
			for _, dot in ipairs(fanned) do
				cu += dot.u
				cv += dot.v
			end
			expect(cu / #fanned).to.be.near(0.5, 1e-6)
			expect(cv / #fanned).to.be.near(0.5, 1e-6)
			-- A PELLET ON ITS OWN IS NOT MOVED. Karen's rule has two halves and this is the other.
			local apart = BoarArt.spread({ { u = 0.2, v = 0.3 }, { u = 0.8, v = 0.7 } }, 7, 148, 80)
			expect(apart[1].u).to.equal(0.2)
			expect(apart[1].v).to.equal(0.3)
			expect(apart[2].u).to.equal(0.8)
			expect(apart[2].v).to.equal(0.7)
			-- IT IS DETERMINISTIC: the same shot draws the same picture twice, so two screenshots of
			-- one hit cannot disagree. A jitter would have been the easy way and the wrong one.
			local again = BoarArt.spread(same, 7, 148, 80)
			for index, dot in ipairs(fanned) do
				expect(again[index].u).to.equal(dot.u)
				expect(again[index].v).to.equal(dot.v)
			end

			-- AND ON THE SCREEN: nine pellets at one point draw nine dots at nine positions.
			local payload = payloadFor("male")
			payload.dots = {}
			for _ = 1, 9 do
				table.insert(payload.dots, { u = 0.5, v = 0.5, zone = "chest", side = 1 })
			end
			Hud.HitCard.show(payload)
			local art = Hud.HitCard.art() :: Frame
			local places = {}
			local pips = 0
			for _, node in ipairs(art:GetChildren()) do
				if node:IsA("Frame") and node.Name == "Dot" then
					pips += 1
					local key = string.format("%.3f,%.3f", node.Position.X.Scale, node.Position.Y.Scale)
					expect(places[key]).to.equal(nil)
					places[key] = true
				end
			end
			expect(pips).to.equal(9)
			TestKit.note(string.format("hit_card: 9 pellets at one point -> %d distinct dots", pips))
		end)

		it("keeps every dot inside the box the animal occupies on the image", function()
			-- THE MEASUREMENT THIS TASK RESTS ON. The dots' unit square is the boar's TRUNK and the
			-- image is the whole animal -- legs, tail and mane outside it -- so a dot placed in the
			-- whole frame would land in the air beside the silhouette. `BoarArt.setKind` writes the
			-- measured box onto the frame and `drawDots` maps into it.
			Hud.HitCard.show(payloadFor("male"))
			local art = Hud.HitCard.art() :: Frame
			for _, key in ipairs({ "BoxU0", "BoxU1", "BoxV0", "BoxV1" }) do
				expect(art:GetAttribute(key)).to.be.ok()
			end
			local u0 = art:GetAttribute("BoxU0") :: number
			local u1 = art:GetAttribute("BoxU1") :: number
			local v0 = art:GetAttribute("BoxV0") :: number
			local v1 = art:GetAttribute("BoxV1") :: number
			-- The box is INSIDE the frame and still SPANS the animal -- a box shrunk onto the torso
			-- would keep every dot on black and stop meaning where the shot landed.
			expect(u0 >= 0 and u1 <= 1 and v0 >= 0 and v1 <= 1).to.equal(true)
			expect(u1 - u0 >= 0.6).to.equal(true)
			expect(v1 - v0 >= 0.35).to.equal(true)
			-- EVERY DRAWN DOT IS IN IT, at the four corners of the unit square and the centre.
			local payload = payloadFor("male")
			payload.dots = {
				{ u = 0, v = 0, zone = "head", side = 1 },
				{ u = 1, v = 0, zone = "rear", side = 1 },
				{ u = 0, v = 1, zone = "legs", side = 1 },
				{ u = 1, v = 1, zone = "legs", side = 1 },
				{ u = 0.5, v = 0.5, zone = "chest", side = 1 },
			}
			Hud.HitCard.show(payload)
			art = Hud.HitCard.art() :: Frame
			local drawn = 0
			for _, node in ipairs(art:GetChildren()) do
				if node:IsA("Frame") and node.Name == "Dot" then
					drawn += 1
					local x, y = node.Position.X.Scale, node.Position.Y.Scale
					expect(x >= u0 - 1e-6 and x <= u1 + 1e-6).to.equal(true)
					expect(y >= v0 - 1e-6 and y <= v1 + 1e-6).to.equal(true)
				end
			end
			expect(drawn).to.equal(5)
			TestKit.note(string.format("hit_card: box u %.3f..%.3f v %.3f..%.3f", u0, u1, v0, v1))
		end)

		-- THE FAR FLANK, WHICH IS THE CARD NOBODY HAD EVER DRAWN (round 1, finding 1). Every case
		-- above uses `side = 1`, so `Report.cardFacing` was false and the MIRRORED frame -- the one
		-- the old `UDim2.fromScale(-scale, scale)` was in -- was never shown or asserted. Roughly
		-- half of all shots take it.
		--
		-- WHAT IS ASSERTED IS WHAT THE ENGINE CAN ACTUALLY DO, measured in Play on 2026-10-18 with
		-- three labels on one plate (`.screenshots/20261018T173406Z-t205-mirror-probe.png`): a
		-- negative `Size.X` draws the image UNMIRRORED, and a negative `ImageRectSize` draws
		-- nothing at all. So the picture is never flipped, its drawn box stays positive, and the
		-- dots are not flipped either -- which is what keeps a head shot on the head.
		it("draws the far flank with a real picture and the marks still on the right end", function()
			local payload = payloadFor("male")
			-- ALL FAR-SIDE, so `Report.cardFacing` is true and the mirrored frame is the one shown.
			payload.dots = {
				{ u = 0.08, v = 0.35, side = -1, zone = "head", lead = true },
				{ u = 0.92, v = 0.45, side = -1, zone = "rear" },
			}
			expect(Report.cardFacing(payload.dots)).to.equal(true)
			Hud.HitCard.show(payload)
			expect(Hud.HitCard.mirrored()).to.equal(true)
			local art = Hud.HitCard.art() :: Frame
			local picture = art:FindFirstChild("Silhouette") :: ImageLabel
			expect(picture).to.be.ok()
			expect(picture.Visible).to.equal(true)
			-- A DRAWN SIZE, NOT A NEGATIVE ONE: `AbsoluteSize` is what the player sees, and the old
			-- line put a negative scale in here.
			expect(picture.Size.X.Scale > 0).to.equal(true)
			expect(picture.AbsoluteSize.X > 1).to.equal(true)
			expect(picture.AbsoluteSize.Y > 1).to.equal(true)
			-- ...AND IT IS INSIDE THE ART FRAME, which a mirrored origin moved it out of.
			expect(picture.AbsolutePosition.X >= art.AbsolutePosition.X - 1).to.equal(true)
			expect(
				picture.AbsolutePosition.X + picture.AbsoluteSize.X <= art.AbsolutePosition.X + art.AbsoluteSize.X + 1
			).to.equal(true)
			-- THE HEAD DOT IS STILL AT THE HEAD END. `u = 0.08` is the nose; with the picture
			-- unflipped and the dots unflipped it draws in the left third of the box, and the rump
			-- dot in the right third. Flipping ONE of the two is what would swap them.
			expect(art:GetAttribute("Mirrored")).to.equal(false)
			local u0 = art:GetAttribute("BoxU0") :: number
			local u1 = art:GetAttribute("BoxU1") :: number
			local xs = {}
			for _, node in ipairs(art:GetChildren()) do
				if node:IsA("Frame") and node.Name == "Dot" then
					table.insert(xs, node.Position.X.Scale)
				end
			end
			expect(#xs).to.equal(2)
			table.sort(xs)
			expect(xs[1] < u0 + (u1 - u0) * 0.34).to.equal(true)
			expect(xs[2] > u0 + (u1 - u0) * 0.66).to.equal(true)
			TestKit.note(
				string.format("hit_card: far flank, head %.3f rump %.3f in box %.3f..%.3f", xs[1], xs[2], u0, u1)
			)
		end)

		-- THE ASSET IS AN IMAGE AND NOT A DECAL, which is what made the card draw nothing at all
		-- (round 2). An `ImageLabel` cannot render a Decal id: measured in Play, every label with
		-- the decal ids was `IsLoaded = false` on an empty plate while a built-in control loaded.
		-- A spec cannot ask the engine to fetch an asset, so what it CAN guard is the shape of the
		-- id -- that both silhouettes are the ids `InsertService:LoadAsset` answered with, and not
		-- the decal ids in `assets/uploads.json`.
		it("points at the IMAGE behind each decal, not the decal", function()
			local male = Report.boarImage("male")
			local female = Report.boarImage("female")
			expect(male.id).to.equal("rbxassetid://135789362198066")
			expect(female.id).to.equal("rbxassetid://121961957713451")
			for _, decal in ipairs({ "80206901277832", "108874258373849" }) do
				expect(string.find(male.id, decal, 1, true)).to.equal(nil)
				expect(string.find(female.id, decal, 1, true)).to.equal(nil)
			end
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
			-- EVERY CHILD GOES WITH IT, WHATEVER CLASS IT IS (round 2's blocking finding). The walk
			-- used to ask `IsA("Frame")`, and the silhouette is an `ImageLabel` -- so the panel, the
			-- plate, the words and the dots faded while Karen's black boar stayed at full strength
			-- over the world for the last half-second and then vanished.
			--
			-- ASSERTED BY CLASS, over every descendant of the card, so the next child type added to
			-- it cannot slip through the same hole: an image by its `ImageTransparency`, a label by
			-- its `TextTransparency`, a stroke and a frame by their own. Each must be PAST its
			-- resting value and not yet gone, which is what "fading" means and what a hard-coded
			-- `== at` could not say for the panel (its rest is `PANEL_TRANSPARENCY`).
			local kinds = {}
			for _, node in ipairs((Hud.hitCard() :: Frame):GetDescendants()) do
				local visible = node:IsA("GuiObject") and node.Visible
				local inside = node:FindFirstAncestorWhichIsA("GuiObject")
				while inside ~= nil and visible do
					visible = inside.Visible
					inside = inside:FindFirstAncestorWhichIsA("GuiObject")
				end
				if node:IsA("ImageLabel") and visible then
					kinds.image = true
					expect(node.ImageTransparency > 1e-3).to.equal(true)
					expect(node.ImageTransparency < 1 - 1e-3).to.equal(true)
				elseif node:IsA("TextLabel") and visible and node.Text ~= "" then
					kinds.text = true
					expect(node.TextTransparency > 1e-3).to.equal(true)
					expect(node.TextTransparency < 1 - 1e-3).to.equal(true)
				elseif node:IsA("Frame") and node.Name == "Dot" and visible then
					kinds.dot = true
					expect(node.BackgroundTransparency > 1e-3).to.equal(true)
					expect(node.BackgroundTransparency < 1 - 1e-3).to.equal(true)
					local ring = node:FindFirstChildOfClass("UIStroke")
					if ring ~= nil then
						kinds.stroke = true
						expect(ring.Transparency > 1e-3).to.equal(true)
					end
				end
			end
			-- ...and all four kinds were really on screen to be checked, so this cannot pass by
			-- finding nothing.
			for _, kind in ipairs({ "image", "text", "dot", "stroke" }) do
				expect(kinds[kind]).to.equal(true)
			end
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

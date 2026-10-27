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

		-- TASK 219. Karen, 2026-10-10: *"Legendary animals: one or a few, e.g. a legendary boar"*. The
		-- card draws the MALE's silhouette for a trophy -- it IS a male boar and there is no third
		-- picture -- so without a word on it, the one animal in four drives looks exactly like the
		-- ones beside it.
		it("names the LEGENDARY BOAR on the plate, and nothing else wears that tag", function()
			-- THE WORD IS A PURE DECISION in one place, so the card cannot say "legendary" for a sow.
			expect(Report.trophyWord("legendary")).to.equal("LEGENDARY BOAR")
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Report.trophyWord(kind)).to.equal(nil)
			end
			expect(Report.trophyWord(nil)).to.equal(nil)

			-- ...AND THE SCREEN FOLLOWS, which is the half a data table cannot promise (L-093, from
			-- task 205's two art frames that both drew `kind = "male"`).
			Card.show(payloadFor("legendary"))
			local plate = Card.frame() :: Frame
			local tag = plate:FindFirstChild("Trophy", true) :: TextLabel
			expect(tag).to.be.ok()
			expect(tag.Visible).to.equal(true)
			expect(Hud.Style.unspaced(tag.Text)).to.equal("LEGENDARY BOAR")

			-- IT IS NOT IN THE HEADLINE, and that is a MEASUREMENT and not a preference: spaced,
			-- `LEGENDARY - BUCKSHOT 4/9` is 167 px in a 164 px label, so the headline keeps saying
			-- what the SHOT was and the plate says what the ANIMAL was.
			expect(string.find(Card.labelText(), "L E G E N D", 1, true)).to.equal(nil)
			local params = Instance.new("GetTextBoundsParams")
			params.Text = tag.Text
			params.Font = tag.FontFace
			params.Size = tag.TextSize
			params.Width = 10000
			local measured = game:GetService("TextService"):GetTextBoundsAsync(params)
			-- AGAINST THE LABEL'S OWN BOX and not the plate's width (round 1, note 6): the thing that
			-- truncates text is the box it is in.
			expect(measured.X <= tag.AbsoluteSize.X).to.equal(true)

			-- ...AND IT IS CLEAR OF THE PICTURE, which round 1's was not (round 1, finding 4). The
			-- tag sat at plate y 76..90 inside an art box spanning 8..88, in the animal's own ink,
			-- above the animal AND the dots -- and no frame of it had ever been taken. Asserted as
			-- rectangles, so "it does not cover the animal" is arithmetic and not an opinion.
			local art = Card.art() :: Frame
			local tagTop = tag.AbsolutePosition.Y
			local artBottom = art.AbsolutePosition.Y + art.AbsoluteSize.Y
			expect(tagTop >= artBottom).to.equal(true)
			-- ...and every pellet dot is above it too, which is the one thing this card exists for.
			for _, node in ipairs(art:GetDescendants()) do
				if node:IsA("GuiObject") and node.Name == "Dot" then
					expect(node.AbsolutePosition.Y + node.AbsoluteSize.Y <= tagTop).to.equal(true)
				end
			end
			TestKit.note(
				string.format(
					"hit_card: the trophy tag measures %.1f px in its own %d px box, starting %.0f px below the picture",
					measured.X,
					tag.AbsoluteSize.X,
					tagTop - artBottom
				)
			)

			-- ...AND IT IS GONE ON THE NEXT ORDINARY SHOT. A tag that survived one card would label
			-- the next animal a trophy, which is worse than never drawing it.
			Card.show(payloadFor("male"))
			local after = (Card.frame() :: Frame):FindFirstChild("Trophy", true) :: TextLabel
			expect(after.Visible).to.equal(false)
			expect(after.Text).to.equal("")
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

		it("draws a stag's dots on the stag, not on the bare plate beside it (task 278)", function()
			-- **KAREN'S DEFECT, 2026-10-26, AS A CASE.** She shot a stag in the chest with the
			-- scoped rifle and the card's red mark sat in empty space in front of it
			-- (`<runs-dir>/design/karen-hitcard-2026-10-26.png`: the ink spans u 0.236..0.757 of the
			-- art frame and the dot was drawn at u 0.118).
			--
			-- WHY it happened: the silhouette is drawn with `ScaleType.Fit`, which preserves the
			-- image's aspect and CENTRES it, and the stag PNG is 750 x 758 in a 148 x 80 frame -- so
			-- the picture only occupies the middle 53.5 % of the width and the box was being written
			-- across all of it.
			--
			-- THE EXPECTED RECTANGLE IS THIS FILE'S OWN ARITHMETIC and never `Report.imageFit`'s: a
			-- case that asks the code under test where the picture is cannot fail when it is wrong.
			local chosen = Report.boarImage("stag")
			expect(chosen.px).to.be.ok()
			local image, frame = chosen.px.w / chosen.px.h, CONFIG.ART_WIDTH / CONFIG.ART_HEIGHT
			local wide = image / frame
			expect(wide < 1).to.equal(true) -- a stag is pillarboxed; this case is about that
			local lo, hi = (1 - wide) / 2, (1 + wide) / 2
			local payload = payloadFor("stag")
			payload.dots = {
				{ u = 0, v = 0, zone = "head", side = 1 },
				{ u = 0.35, v = 0.45, zone = "chest", side = 1 },
				{ u = 1, v = 0.3, zone = "rear", side = 1 },
			}
			Card.show(payload)
			local art = Card.art() :: Frame
			local xs = {}
			for _, node in ipairs(art:GetChildren()) do
				if node:IsA("Frame") and node.Name == "Dot" then
					table.insert(xs, node.Position.X.Scale)
				end
			end
			expect(#xs).to.equal(3)
			table.sort(xs)
			-- EVERY dot inside the rectangle the picture is actually drawn in. Before task 278 the
			-- nose dot drew at about 0.03 and this line failed.
			for _, x in ipairs(xs) do
				expect(x >= lo - 1e-6 and x <= hi + 1e-6).to.equal(true)
			end
			-- ...AND THEY ARE STILL IN ORDER along the animal: nose, chest, rump.
			expect(xs[1] < xs[2] and xs[2] < xs[3]).to.equal(true)
			TestKit.note(
				string.format(
					"hit_card: stag dots at u %.3f/%.3f/%.3f, picture drawn across %.3f..%.3f",
					xs[1],
					xs[2],
					xs[3],
					lo,
					hi
				)
			)
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
			-- A **LEGENDARY** PAYLOAD (task 219 round 1, finding 3), and that is the whole reason this
			-- line changed: the trophy tag is drawn only for one, and this case only ever asserts over
			-- a `TextLabel` that is VISIBLE with text in it -- so driven with `buckPayload()` the tag
			-- was hidden and empty and the walk below stepped straight over it. `setFade` never
			-- touched it (it is a child of the CARD, not of an art frame), so for the whole
			-- `FADE_SECONDS` it stayed at full strength over the world and then snapped away. That is
			-- the defect this file was blocked for in round 2 of task 198, recurred on the next child
			-- type added -- exactly as `fadeInk`'s own header predicted.
			local fading = buckPayload()
			fading.animalKind = "legendary"
			Card.show(fading)
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
			-- ...AND THE TROPHY TAG IS ONE OF THE LABELS IT FOUND, named rather than left to the
			-- class walk: "some TextLabel was fading" is what passed while this one did not exist.
			local tag = (Hud.hitCard() :: Frame):FindFirstChild("Trophy", true) :: TextLabel
			expect(tag).to.be.ok()
			expect(tag.Visible).to.equal(true)
			expect(tag.Text ~= "").to.equal(true)
			expect(tag.TextTransparency > 1e-3).to.equal(true)
			expect(tag.TextTransparency < 1 - 1e-3).to.equal(true)
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

	-- **TASK 283: A DOT LANDS ON THE ANIMAL IT IS DRAWN OVER, measured against the PICTURE'S OWN
	-- PIXELS.** Karen, 2026-10-27, of a buckshot card at a broadside boar she aimed at the chest:
	-- *"wrong I hit the chest shows outside"*.
	--
	-- WHY THIS CASE IS NOT A TAUTOLOGY, which is the thing that makes it worth its length. Three
	-- independent instruments meet in it and none of them is the code under test:
	--   1. `reviews/task-283/probes/283-flank.luau` found each point by RAY against the frozen DRAWN
	--      mesh in Play -- so every `uv` below is a place the player can actually hit;
	--   2. `HitCardInk` is the uploaded PNGs' own alpha, sampled by `tools/silhouette_ink.py` off the
	--      bytes whose sha256 `assets/uploads.json` records;
	--   3. the pixel is read off the DRAWN `Dot` frame's `Position`, and the composition is undone
	--      with this file's own arithmetic. Asking `Report.imageBox` where the picture is would make
	--      a case that cannot fail when the answer is wrong.
	describe("a dot lands on the animal (task 283)", function()
		local Ink = require(ReplicatedStorage:WaitForChild("ClientTests"):WaitForChild("HitCardInk"))

		-- WHICH PICTURE EACH KIND IS DRAWN ON, and at what scale -- `Report.boarImage`'s own rule,
		-- written out here so the case does not read it from the thing it is checking. A cub is the
		-- sow's drawing and a calf the hind's, so each shares that picture's measured rectangle.
		local DRAWN = {
			male = { picture = "male", scale = 1 },
			legendary = { picture = "male", scale = 1 },
			female = { picture = "female", scale = 1 },
			cub = { picture = "female", scale = Report.CONFIG.PIGLET_SCALE },
			stag = { picture = "stag", scale = 1 },
			hind = { picture = "hind", scale = 1 },
			calf = { picture = "hind", scale = Report.CONFIG.CALF_SCALE },
		}

		-- POINTS ON THE DRAWN FLANK, found by ray (`283-flank.luau`, 2026-10-27, DEV): four stations
		-- along each animal -- the withers, the chest, the belly line and the rump -- as the (u, v)
		-- `HitLog.Shape.dot` makes of them. The stag's withers is absent on purpose: the ray at that
		-- station came back `MESH=false` (it fell in the gap under his antlers), and a point the probe
		-- did not confirm is not evidence.
		--
		-- **THE WITHERS STATION IS NOT IN HERE FOR FOUR OF THE SEVEN, AND THE REASON IS A FINDING.**
		-- On the male, the legendary, the hind and the calf the ray met the mesh ABOVE the trunk box
		-- (the male's at y 1.510 against a box top of 1.500), so `Shape.dot` CLAMPS it to v = 0 --
		-- the box's own top line -- and the unit square cannot represent where it struck at all.
		-- Three of those four land on ink anyway and the hind's does not; the case below measures
		-- that rather than hiding it, and the band itself is task 282a's.
		local ON_FLANK = {
			male = { { 0.4000, 0.3290 }, { 0.5200, 0.5456 }, { 0.7800, 0.4210 } },
			female = { { 0.2800, 0.0448 }, { 0.4000, 0.3440 }, { 0.5200, 0.5480 }, { 0.7800, 0.4340 } },
			cub = { { 0.2800, 0.0024 }, { 0.4000, 0.3820 }, { 0.5200, 0.5128 }, { 0.7800, 0.3890 } },
			legendary = { { 0.4000, 0.3290 }, { 0.5200, 0.5456 }, { 0.7800, 0.4210 } },
			stag = { { 0.4000, 0.0910 }, { 0.5200, 0.4600 }, { 0.7800, 0.1940 } },
			hind = { { 0.4000, 0.4250 }, { 0.5200, 0.3920 }, { 0.7800, 0.1340 } },
			calf = { { 0.4000, 0.3840 }, { 0.5200, 0.2672 }, { 0.7800, 0.0280 } },
		}

		-- THE DORSAL BAND, MEASURED THROUGH THE CARD. Every one of these four points is a place the
		-- ray met the DRAWN animal ABOVE that animal's trunk box, so each arrives here as v = 0 --
		-- the box's own top line, which IS the picture's back line now the rectangle is measured on
		-- the picture. All four must therefore draw on the animal; round 1's rows came off the game
		-- MESH, which put the hind's 0.09 of her picture above her back (`RESULT.md` finding 1).
		local ABOVE_THE_BOX = {
			{ "male", 0.2800 },
			{ "legendary", 0.2800 },
			{ "hind", 0.2800 },
			{ "calf", 0.2800 },
		}

		-- THE PIXEL OF THE PICTURE A DRAWN PIP SITS ON. `pip.Position` is a fraction of the ART
		-- FRAME; the label is `scale` of that frame, centred; and the image inside the label is
		-- `ScaleType.Fit`, so it keeps its own aspect and is centred with a bar down two sides. All
		-- three are undone here, in this file, with no call into `Report`'s composition.
		local function pictureUV(kind: string, pipU: number, pipV: number): (number, number)
			local drawn = DRAWN[kind]
			local art = Ink.PICTURES[drawn.picture]
			local inset = (1 - drawn.scale) / 2
			local labelU = (pipU - inset) / drawn.scale
			local labelV = (pipV - inset) / drawn.scale
			local image = art.w / art.h
			local frame = CONFIG.ART_WIDTH / CONFIG.ART_HEIGHT
			local u0, u1, v0, v1 = 0, 1, 0, 1
			if image > frame then
				local tall = frame / image
				v0, v1 = (1 - tall) / 2, (1 + tall) / 2
			else
				local wide = image / frame
				u0, u1 = (1 - wide) / 2, (1 + wide) / 2
			end
			return (labelU - u0) / (u1 - u0), (labelV - v0) / (v1 - v0)
		end

		-- WHERE THE PICTURE IS DRAWN IN THE ART FRAME, as fractions of that frame: `ScaleType.Fit`
		-- keeps the image's aspect and centres it. The arithmetic `pictureUV` undoes, forwards.
		local function fitOf(kind: string): { u0: number, u1: number, v0: number, v1: number }
			local art = Ink.PICTURES[DRAWN[kind].picture]
			local image = art.w / art.h
			local frame = CONFIG.ART_WIDTH / CONFIG.ART_HEIGHT
			if image > frame then
				local tall = frame / image
				return { u0 = 0, u1 = 1, v0 = (1 - tall) / 2, v1 = (1 + tall) / 2 }
			end
			local wide = image / frame
			return { u0 = (1 - wide) / 2, u1 = (1 + wide) / 2, v0 = 0, v1 = 1 }
		end

		-- THE IMAGE v A DOT AT BOX v MUST BE DRAWN AT, predicted from THE PICTURE and from the drawn
		-- pip's own size: `Ink.trunkBox` plus `BoarArt`'s half-dot inset, which is half a dot of the
		-- ANIMAL'S height. Nothing in `Report.CONFIG.TRUNK_IN_INK` is consulted, so a case that uses
		-- this fails if that table is deleted or wrong.
		local function expectedV(kind: string, pip: GuiObject, boxV: number): number
			local trunk = Ink.trunkBox(DRAWN[kind].picture) :: any
			local fit = fitOf(kind)
			local tall = DRAWN[kind].scale * (fit.v1 - fit.v0) * (trunk.v1 - trunk.v0)
			local insetV = (pip.Size.Y.Offset / 2) / math.max(1, tall * CONFIG.ART_HEIGHT)
			return trunk.v0 + (insetV + boxV * (1 - 2 * insetV)) * (trunk.v1 - trunk.v0)
		end

		local function drawCard(kind: string, dots)
			local payload = payloadFor(kind)
			payload.dots = dots
			Card.show(payload)
			local art = Card.art() :: Frame
			expect(art).to.be.ok()
			local pips = {}
			for _, child in ipairs(art:GetChildren()) do
				if child:IsA("Frame") and child.Name == "Dot" then
					table.insert(pips, child)
				end
			end
			return pips
		end

		it("draws every point of the drawn flank ON the picture, for all seven kinds", function()
			local misses = {}
			local counted = 0
			for _, kind in ipairs({ "male", "female", "cub", "legendary", "stag", "hind", "calf" }) do
				for index, point in ipairs(ON_FLANK[kind]) do
					local pips = drawCard(kind, { { u = point[1], v = point[2], zone = "chest", side = 1 } })
					expect(#pips).to.equal(1)
					local pipU = pips[1].Position.X.Scale
					local pipV = pips[1].Position.Y.Scale
					local iu, iv = pictureUV(kind, pipU, pipV)
					counted += 1
					if not Ink.isInk(DRAWN[kind].picture, iu, iv) then
						table.insert(
							misses,
							string.format(
								"%s#%d uv(%.3f,%.3f)->img(%.3f,%.3f)",
								kind,
								index,
								point[1],
								point[2],
								iu,
								iv
							)
						)
					end
					Card.hide()
				end
			end
			TestKit.note(string.format("hit_card 283: %d flank points, %d off the ink", counted, #misses))
			expect(table.concat(misses, " ")).to.equal("")
		end)

		it("draws the dots in the PICTURE'S OWN trunk box, to a cell, for all seven kinds", function()
			-- THE NUMBER, per picture (Director, 2026-10-27: the rectangle is measured ON THE
			-- PICTURE). `Ink.trunkBox` reads it off the 120 x 60 grid of the uploaded PNG's alpha;
			-- the card's rectangle comes from `Report.CONFIG.TRUNK_IN_INK`, measured on the same
			-- PNG at full resolution by `tools/silhouette_ink.py measure`. Two resolutions, one
			-- rule: they must agree to one cell. Delete that table and the card's box becomes the
			-- whole picture (0..1 on both axes), which fails on every one of the four pictures.
			local cell = 1 / Ink.ROWS
			for _, kind in ipairs({ "male", "female", "stag", "hind", "calf", "cub", "legendary" }) do
				local pips = drawCard(kind, { { u = 0.5, v = 0.5, zone = "chest", side = 1 } })
				expect(#pips).to.equal(1)
				local art = Card.art() :: Frame
				-- The box as the renderer wrote it, in FRAME fractions, undone to the picture's own
				-- fractions by this file's arithmetic (`pictureUV`) and never by `Report`'s.
				local u0 = art:GetAttribute("BoxU0") :: number
				local u1 = art:GetAttribute("BoxU1") :: number
				local v0 = art:GetAttribute("BoxV0") :: number
				local v1 = art:GetAttribute("BoxV1") :: number
				local gotU0, gotV0 = pictureUV(kind, u0, v0)
				local gotU1, gotV1 = pictureUV(kind, u1, v1)
				local want = Ink.trunkBox(DRAWN[kind].picture) :: any
				TestKit.note(
					string.format(
						"hit_card 283: %s box u %.4f..%.4f v %.4f..%.4f, the picture's own u %.4f..%.4f v %.4f..%.4f",
						kind,
						gotU0,
						gotU1,
						gotV0,
						gotV1,
						want.u0,
						want.u1,
						want.v0,
						want.v1
					)
				)
				expect(gotV0).to.be.near(want.v0, cell)
				expect(gotV1).to.be.near(want.v1, cell)
				expect(gotU0).to.be.near(want.u0, cell)
				expect(gotU1).to.be.near(want.u1, cell)
				Card.hide()
			end
		end)

		it("clamps a hit ABOVE the box onto the picture's back line, and draws it ON the animal", function()
			local offInk, wrongV = {}, {}
			local cell = 1 / Ink.ROWS
			for _, row in ipairs(ABOVE_THE_BOX) do
				local kind, u = row[1], row[2]
				local pips = drawCard(kind, { { u = u, v = 0, zone = "head", side = 1 } })
				expect(#pips).to.equal(1)
				local iu, iv = pictureUV(kind, pips[1].Position.X.Scale, pips[1].Position.Y.Scale)
				local want = expectedV(kind, pips[1], 0)
				local where = string.format("%s img(%.3f,%.3f) want v %.3f", kind, iu, iv, want)
				if not Ink.isInk(DRAWN[kind].picture, iu, iv) then
					table.insert(offInk, where)
				end
				if math.abs(iv - want) > cell then
					table.insert(wrongV, where)
				end
				TestKit.note("hit_card 283: above the box -- " .. where)
				Card.hide()
			end
			-- THE NUMBER FIRST: a dot on the box's top line is drawn at the picture's own back line
			-- plus half a dot, for every one of them. Then the picture: all four land on the animal.
			expect(table.concat(wrongV, " ")).to.equal("")
			expect(table.concat(offInk, " ")).to.equal("")
		end)

		it("draws KAREN'S OWN PELLET inside the boar and below its crest", function()
			-- THE KNOWN-BAD CASE, and it is a reading rather than an example: the lead pellet of the
			-- buckshot shot in `reviews/task-282/MEASURED.md` 2b, server local offset
			-- (1.06, 1.41, -0.21) on a male, which `282-why2.luau` proved CROSSED the drawn mesh
			-- (the back line at that z is 1.60). u = -0.21 / 5.5 + 0.5, v = 0.5 - 1.41 / 3.
			local pips = drawCard("male", { { u = 0.46182, v = 0.03, zone = "chest", side = 1, lead = true } })
			expect(#pips).to.equal(1)
			local iu, iv = pictureUV("male", pips[1].Position.X.Scale, pips[1].Position.Y.Scale)
			-- THE NUMBER, so the case cannot pass on a different rectangle: with his measured box
			-- this pellet is drawn at image v 0.21, with round 1's rows at 0.15, with the rows
			-- before this task at 0.27 and with no rectangle at all at 0.07.
			expect(iv).to.be.near(expectedV("male", pips[1], 0.03), 1 / Ink.ROWS)
			expect(Ink.isInk("male", iu, iv)).to.equal(true)
			-- ...AND BELOW THE CREST: there is ink ABOVE it in the same column, which is the mane she
			-- was shown the dot on. A dot drawn ON the crest line has none.
			local column = math.clamp(math.floor(iu * Ink.COLS) + 1, 1, Ink.COLS)
			local row = math.clamp(math.floor(iv * Ink.ROWS) + 1, 1, Ink.ROWS)
			local above = 0
			for r = 1, row - 1 do
				if string.sub(Ink.PICTURES.male.rows[r], column, column) == "#" then
					above += 1
				end
			end
			TestKit.note(
				string.format(
					"hit_card 283: lead pellet img(%.3f,%.3f) row %d, %d ink rows above it",
					iu,
					iv,
					row,
					above
				)
			)
			expect(above >= 2).to.equal(true)
		end)

		it("leaves a point that is INSIDE the box but OFF the animal off the ink", function()
			-- THE OTHER HALF, and without it the case above passes for a card that draws everything
			-- on the torso. `282-why2.luau` measured the male's back line at z -2.6 as y 0.74, so
			-- (y 1.00, z -2.60) is air -- inside the trunk box (half-height 1.50) and above the
			-- drawn animal. u = -2.6 / 5.5 + 0.5, v = 0.5 - 1.0 / 3.
			local pips = drawCard("male", { { u = 0.027273, v = 0.166667, zone = "head", side = 1 } })
			expect(#pips).to.equal(1)
			local iu, iv = pictureUV("male", pips[1].Position.X.Scale, pips[1].Position.Y.Scale)
			TestKit.note(
				string.format(
					"hit_card 283: air in the box -> img(%.3f,%.3f) ink=%s",
					iu,
					iv,
					tostring(Ink.isInk("male", iu, iv))
				)
			)
			expect(Ink.isInk("male", iu, iv)).to.equal(false)
		end)

		it("keeps a FANNED group of eight on the animal", function()
			-- KAREN'S FRAME WAS EIGHT PELLETS. `BoarArt.spread` fans a group that shares a spot, and
			-- until this task it measured the fan in the FRAME's pixels and drew it into the picture's
			-- smaller rectangle -- an 11.9 px ring on an animal 37 px tall, half of it off the ink.
			local tight = {}
			for index = 1, 8 do
				table.insert(tight, { u = 0.40 + index * 0.001, v = 0.06 + index * 0.001, zone = "chest", side = 1 })
			end
			local pips = drawCard("male", tight)
			expect(#pips).to.equal(8)
			local off = {}
			local middle = 0
			for index, pip in ipairs(pips) do
				local iu, iv = pictureUV("male", pip.Position.X.Scale, pip.Position.Y.Scale)
				middle += iv / #pips
				if not Ink.isInk("male", iu, iv) then
					table.insert(off, string.format("#%d img(%.3f,%.3f)", index, iu, iv))
				end
			end
			-- THE NUMBER, for the group: `BoarArt.spread` fans about the centre, so the eight dots'
			-- mean image v is where their shared v is drawn -- on the measured box and on no other.
			expect(middle).to.be.near(expectedV("male", pips[1], 0.0645), 1 / Ink.ROWS)
			TestKit.note(string.format("hit_card 283: 8 fanned pellets, %d off the ink", #off))
			expect(table.concat(off, " ")).to.equal("")
		end)

		it("fans inside the ANIMAL'S rectangle and not the frame's", function()
			-- THE ARITHMETIC, with no screen: a group on the back line has almost no room above it,
			-- so the ring shrinks instead of reaching off the picture, and every fanned dot stays in
			-- the unit square.
			local BoarArt = Hud.BoarArt
			local tight = {}
			for _ = 1, 8 do
				table.insert(tight, { u = 0.5, v = 0.02 })
			end
			local fanned = BoarArt.spread(tight, 7, 148, 37)
			for _, dot in ipairs(fanned) do
				expect(dot.u >= 0 and dot.u <= 1).to.equal(true)
				expect(dot.v >= 0 and dot.v <= 1).to.equal(true)
			end
			-- ...AND A GROUP WITH ROOM IS UNTOUCHED BY THE NEW CAP: the same eight at mid-animal
			-- still fan onto the full ring, so the fix took nothing away.
			local roomy = {}
			for _ = 1, 8 do
				table.insert(roomy, { u = 0.5, v = 0.5 })
			end
			local wide = BoarArt.spread(roomy, 7, 148, 37)
			local far = 0
			for _, dot in ipairs(wide) do
				far = math.max(far, math.abs(dot.u - 0.5) * 148)
			end
			expect(far).to.be.near(7 * 0.6 * math.sqrt(8), 1e-3)
		end)
	end)
end

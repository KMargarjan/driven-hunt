--!strict
-- Hud.BoarArt: THE ONE BUILDER of the side-on boar picture and THE ONE PLACER of a dot on it
-- (CLAUDE.md rule 3). Two screens draw that animal now -- the TAB drive report's detail rows and the
-- hit card in the corner -- and the dispatch for task 198 says it in one line: *"ONE owner for the
-- silhouette and the dot projection: reuse them, do not make a second boar drawing or a second
-- projection"*.
--
-- IT IS A MOVE, NOT A NEW SYSTEM. Every line below was `ReportPanel`'s `buildSilhouette`,
-- `clearDots` and `drawDots`, unchanged in what it draws: the same fourteen `Frame`s out of
-- `Report.CONFIG.BOAR`, the same half-dot inset, the same `Report.ontoBoar` nudge, the same zone
-- ring lifted by `Report.ringColor`, the same attributes read back by
-- `tests/client/report_panel.spec.luau`. What is new is that the colours, the size and the facing
-- are now ARGUMENTS, because the card wants a black animal on a pale plate and the report wants a
-- pale animal on a dark one.
--
-- THE PROJECTION IS NOT IN HERE AND NEVER WILL BE. `(u, v, side)` is measured once on the server, at
-- the instant of the shot, by `HitLog.Shape.dot`; this file turns a `(u, v)` into a pixel and
-- decides nothing about where a pellet went.
--
-- Design: docs/design/drive-report.md (sections 8.2, 8.3)
-- Note:   docs/research/2026-10-05-drive-report.md, docs/research/2026-10-17-hit-card.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local CONFIG = Report.CONFIG

local BoarArt = {}

export type Look = {
	-- The animal's one fill, and the ground it is drawn on.
	fill: Color3,
	backing: Color3,
	backingTransparency: number?,
	-- Nose-LEFT (false, the report's own facing) or nose-RIGHT (true). See `Report.cardFacing`.
	mirror: boolean?,
	width: number,
	height: number,
	zIndex: number,
	corner: number?,
	-- THE RECORD'S OWN `kind` (task 205): "male", "female", "cub", or nil. With a kind this draws
	-- KAREN'S IMAGE through `Report.boarImage`; without one it draws the fourteen `Frame`s, which is
	-- every caller before task 205 and is the fallback for a world with no asset.
	kind: string?,
}

export type DotLook = {
	fill: Color3, -- what the dots are drawn ON, for the zone ring's contrast lift
	width: number,
	height: number,
	zIndex: number,
	mirror: boolean?,
	pixels: number?,
	-- `nil` means the drive report's own scheme: a white dot with a ring in the zone's colour, the
	-- fatal one turned 45 degrees in the kill marker's red. A colour here means every dot is that
	-- colour with one fixed `ring`, which is the hit card: Karen's *"red dot"*.
	dot: Color3?,
	ring: Color3?,
	ringThickness: number?,
	-- Half-fade a dot that landed on the FAR flank. The report does; the card turns the animal
	-- around instead, so it does not.
	fadeFarSide: boolean?,
}

-- THE RING COLOUR PER ZONE, built once from the list of zones the report draws (task 135).
--
-- `Report.CONFIG.ZONES` is that list, and this is its reader: it lost its old one when the five
-- tinted rectangles stopped being the picture, and a list in a shared config that nothing reads is
-- the kind of lie `Penalty.expired`'s own comment warns about. It is also the right shape for the
-- job -- a string off the wire indexes one small table, built at load, rather than two.
local RING: { [string]: Color3 } = {}
for _, zone in ipairs(CONFIG.ZONES) do
	local rect = CONFIG.SILHOUETTE[zone]
	if rect ~= nil then
		-- ...LIFTED UNTIL IT CAN BE READ ON THE ANIMAL (task 137). `body`'s tint is 16 of 255 per
		-- channel from `BOAR_FILL`, so that ring was not a ring; see `Report.ringColor`.
		RING[zone] = Report.ringColor(rect.tint, CONFIG.BOAR_FILL)
	end
end

BoarArt.RING = RING

-- ONE SILHOUETTE: a side-view boar, from `Report.CONFIG.BOAR`, in the single fill `look.fill`.
-- Fourteen `Frame`s with a `UICorner` each and no art, no mesh and no `ViewportFrame` -- a 104-px
-- picture of a boar does not need a camera, and a `ViewportFrame` per row would be eight of them.
--
-- `ReportPanel` DREW `Report.CONFIG.SILHOUETTE` ITSELF UNTIL TASK 135 -- five tinted zone
-- rectangles, which task 124 round 3's own note called "a colour-coded bar, not a boar's outline".
-- Those rectangles are still the record every dot is placed against; they are no longer the picture.
--
-- MIRRORING IS `u -> 1 - u` ON EVERY PART, and it is done here rather than with a transform because
-- Roblox GUI has none: a `Frame` cannot be flipped, so the parts are laid out the other way round.
-- `drawDots` mirrors the dots with the same one line, so the two cannot disagree.
function BoarArt.build(parent: Instance, name: string, position: UDim2, look: Look): Frame
	local art = Instance.new("Frame")
	art.Name = name
	-- ITS OWN BACKING, and the report's first frame is why: over a sunlit forest the zone rectangles
	-- were being read against leaves, and a picture of an animal that competes with a tree is not a
	-- picture of an animal.
	art.BackgroundColor3 = look.backing
	art.BackgroundTransparency = look.backingTransparency or 0
	art.BorderSizePixel = 0
	art.ZIndex = look.zIndex
	art.Position = position
	art.Size = UDim2.fromOffset(look.width, look.height)
	art.Parent = parent
	if look.corner ~= nil then
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, look.corner)
		round.Parent = art
	end
	-- ONE IMAGE SINCE TASK 205, AND IT IS KAREN'S OWN. She played on 2026-10-18 and said of the
	-- card this draws: *"and what is that? you need proper image for wildboar when showing hit now
	-- it feels mess unclear wtf ?"* -- `karen-2026-10-18/shot-4.png`. What she was looking at is the
	-- fourteen `Frame`s below, which at 148 x 80 read as two rounded blobs with four stubs.
	--
	-- `look.kind` IS THE RECORD'S OWN WORD and `Report.boarImage` is the one place it becomes a
	-- picture, so the hit card and the drive report cannot show two different animals for one shot.
	-- The fourteen parts are KEPT and are the fallback for a caller that passes no kind at all
	-- (rule 7: the old drawing is not deleted, and a world with no asset still draws an animal).
	if look.kind ~= nil then
		local picture = Instance.new("ImageLabel")
		picture.Name = "Silhouette"
		picture.BackgroundTransparency = 1
		picture.BorderSizePixel = 0
		-- `Fit` AND NOT `Stretch`: the two PNGs have different aspect ratios (1.99 and 1.72) and a
		-- stretched boar is a boar nobody recognises, which is the whole of what she complained of.
		picture.ScaleType = Enum.ScaleType.Fit
		picture.ImageColor3 = look.fill
		picture.ZIndex = look.zIndex + 1
		picture.Parent = art
		BoarArt.setKind(art, look.kind, look.mirror)
		return art
	end
	for _, piece in ipairs(CONFIG.BOAR) do
		local part = Instance.new("Frame")
		part.Name = piece.name
		part.BackgroundColor3 = look.fill
		part.BackgroundTransparency = 0
		part.BorderSizePixel = 0
		local u0 = if look.mirror then 1 - piece.u1 else piece.u0
		part.Position = UDim2.fromScale(u0, piece.v0)
		part.Size = UDim2.fromScale(piece.u1 - piece.u0, piece.v1 - piece.v0)
		-- ONE ZINDEX FOR THE WHOLE ANIMAL: the parts are the same colour, so there is nothing for a
		-- stacking order to decide, and the dots sit above all of them at +2.
		part.ZIndex = look.zIndex + 1
		-- THE CORNER IS A FRACTION OF THE PART'S OWN SHORTER SIDE, in SCALE, so a leg does not turn
		-- into a lozenge when the silhouette is drawn larger. `UICorner`'s Scale is relative to the
		-- shorter side already (https://create.roblox.com/docs/reference/engine/classes/UICorner).
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(piece.corner, 0)
		corner.Parent = part
		part.Parent = art
	end
	return art
end

-- WHICH ANIMAL THIS FRAME IS SHOWING, and the ONE writer of the picture and of the box the dots
-- are placed in -- so the two can never describe different animals.
--
-- IT IS CALLED AT SHOW TIME AND NOT ONLY AT BUILD TIME, because the hit card builds its two art
-- frames (nose-left and nose-right) before any shot has been fired and learns the kind from the
-- payload. `Report.boarImage` decides; this draws.
function BoarArt.setKind(art: Frame, kind: string?, mirror: boolean?)
	local picture = art:FindFirstChild("Silhouette")
	if picture == nil or not picture:IsA("ImageLabel") then
		return
	end
	local chosen = Report.boarImage(kind)
	picture.Image = chosen.id
	-- A PIGLET IS THE SOW AT 70 %, centred, which `Report.boarImage` decides and this draws.
	local inset = (1 - chosen.scale) / 2
	if mirror then
		-- A NEGATIVE WIDTH IS THE MIRROR, and the origin moves with it -- the same one line the
		-- dots are mirrored by, so a boar facing the other way keeps its marks on the right end.
		picture.Position = UDim2.fromScale(inset + chosen.scale, inset)
		picture.Size = UDim2.fromScale(-chosen.scale, chosen.scale)
	else
		picture.Position = UDim2.fromScale(inset, inset)
		picture.Size = UDim2.fromScale(chosen.scale, chosen.scale)
	end
	-- WHERE THE DOTS' UNIT SQUARE SITS ON THIS PICTURE, written on the frame so `drawDots` reads it
	-- back rather than being told the same thing twice. `Report.CONFIG.BOAR_IMAGE`'s measured box,
	-- scaled by the piglet's own scale so a cub's hit lands in the same place on the same body.
	art:SetAttribute("BoxU0", inset + chosen.box.u0 * chosen.scale)
	art:SetAttribute("BoxU1", inset + chosen.box.u1 * chosen.scale)
	art:SetAttribute("BoxV0", inset + chosen.box.v0 * chosen.scale)
	art:SetAttribute("BoxV1", inset + chosen.box.v1 * chosen.scale)
end

-- KAREN'S RULE, 2026-10-17: *"if same place spread if not same show spread"*. A buckshot pattern
-- puts up to eighteen pellets inside a hand's width of animal, and at the card's scale they land on
-- top of one another: the player sees ONE dot and cannot tell a graze from a pattern.
--
-- PURE, AND IT MOVES THE DRAWING AND NEVER THE RECORD. Dots closer together than `gap` (in the
-- frame's own pixels) are FANNED onto a ring about their own centre, in index order, so the same
-- shot always draws the same picture -- a random jitter would make two screenshots of one hit
-- disagree. A group of one is left exactly where it was.
--
-- THE RING'S RADIUS GROWS WITH THE GROUP so eighteen pellets do not sit on a circle meant for
-- three, and it is capped at `gap` x 2 so a pattern stays a pattern rather than becoming a halo.
function BoarArt.spread(dots: { any }, gap: number, width: number, height: number): { any }
	local out = {}
	local taken = {}
	for index, dot in ipairs(dots or {}) do
		table.insert(out, { u = dot.u or 0, v = dot.v or 0, source = index })
	end
	for index, dot in ipairs(out) do
		if taken[index] then
			continue
		end
		local group = { index }
		taken[index] = true
		for other = index + 1, #out do
			if taken[other] then
				continue
			end
			local dx = (out[other].u - dot.u) * width
			local dy = (out[other].v - dot.v) * height
			if dx * dx + dy * dy < gap * gap then
				taken[other] = true
				table.insert(group, other)
			end
		end
		if #group < 2 then
			continue
		end
		-- THE GROUP'S OWN CENTRE, so the fan stays where the pellets actually struck.
		local cu, cv = 0, 0
		for _, which in ipairs(group) do
			cu += out[which].u
			cv += out[which].v
		end
		cu, cv = cu / #group, cv / #group
		local radius = math.min(gap * 2, gap * 0.6 * math.sqrt(#group))
		for place, which in ipairs(group) do
			local angle = (place - 1) * (2 * math.pi / #group)
			out[which].u = cu + (radius * math.cos(angle)) / math.max(1, width)
			out[which].v = cv + (radius * math.sin(angle)) / math.max(1, height)
		end
	end
	return out
end

function BoarArt.clearDots(art: Frame)
	for _, child in ipairs(art:GetChildren()) do
		if child:IsA("Frame") and child.Name == "Dot" then
			child:Destroy()
		end
	end
end

-- ONE DOT PER HIT, at the (u, v) the server measured in the animal's own frame at the moment of the
-- shot. The fatal one is the marker's own kill colour and a little larger; on the report a dot on
-- the FAR flank is half transparent, so a report of a broadside shows which side the animal was hit
-- from.
function BoarArt.drawDots(art: Frame, dots: { any }?, look: DotLook)
	BoarArt.clearDots(art)
	local pixels = look.pixels or CONFIG.DOT_PIXELS
	-- SAME PLACE -> SPREAD (Karen, 2026-10-17). The fan is computed on the DRAWN positions, in this
	-- frame's own pixels, because "a dot's width apart" is a thing about the picture and not about
	-- the animal. The record is untouched: the attributes written below still carry the true (u, v).
	local placed = BoarArt.spread(dots or {}, pixels, look.width, look.height)
	-- WHERE THE UNIT SQUARE SITS ON THE PICTURE. With Karen's image it is the measured box
	-- (`build` wrote it onto the frame); with the fallback drawing it is the whole frame, which is
	-- what every dot before task 205 was placed in.
	local boxU0 = art:GetAttribute("BoxU0") or 0
	local boxU1 = art:GetAttribute("BoxU1") or 1
	local boxV0 = art:GetAttribute("BoxV0") or 0
	local boxV1 = art:GetAttribute("BoxV1") or 1
	for index, dot in ipairs(dots or {}) do
		local pip = Instance.new("Frame")
		pip.Name = "Dot"
		pip.AnchorPoint = Vector2.new(0.5, 0.5)
		local size = if dot.fatal then pixels + 3 else pixels
		-- INSET BY HALF A DOT, so a hit at u = 0 -- a nose-on shot, which the zone measurement of
		-- 2026-10-05 showed is the commonest kind there is -- is drawn ON the animal instead of
		-- hanging half outside it. The shift is at most 5 px of 104, under 5% of the body's length,
		-- and it is a drawing decision: the record itself is untouched and the attributes below
		-- still carry the true (u, v).
		local insetU = (size / 2) / look.width
		local insetV = (size / 2) / look.height
		-- ...AND THEN ONTO THE ANIMAL, if the inset still leaves it in the air (task 138). The
		-- nudge is applied to the DRAWN position, because that is the space `Report.CONFIG.BOAR`'s
		-- parts are laid out in; the attributes below still carry the true `(u, v)`.
		-- THE FANNED POSITION, not the raw one (see `BoarArt.spread` above).
		local fanned = placed[index] or { u = dot.u or 0, v = dot.v or 0 }
		local drawnU, drawnV = Report.ontoBoar(
			insetU + math.clamp(fanned.u, 0, 1) * (1 - 2 * insetU),
			insetV + math.clamp(fanned.v, 0, 1) * (1 - 2 * insetV)
		)
		-- ...AND THEN INTO THE BOX THE UNIT SQUARE OCCUPIES ON THIS PICTURE. Before task 205 the
		-- animal filled the frame and the two were the same rectangle; Karen's image carries legs,
		-- a tail and a mane outside the trunk, so a dot placed in the whole frame would land in the
		-- air beside the animal.
		drawnU = boxU0 + drawnU * (boxU1 - boxU0)
		drawnV = boxV0 + drawnV * (boxV1 - boxV0)
		-- THE SAME ONE LINE THE ANIMAL WAS LAID OUT WITH (see `build`): mirror the picture, mirror
		-- the marks, or the dot would be on the wrong end of a boar facing the other way.
		pip.Position = UDim2.fromScale(if look.mirror then 1 - drawnU else drawnU, drawnV)
		pip.Size = UDim2.fromOffset(size, size)
		local plain = look.dot or Color3.new(1, 1, 1)
		pip.BackgroundColor3 = if dot.fatal then Shotgun.CONFIG.HIT_MARK_KILL_COLOR else plain
		pip.BackgroundTransparency = if look.fadeFarSide and (dot.side or 1) < 0
			then CONFIG.FAR_SIDE_TRANSPARENCY
			else 0
		pip.BorderSizePixel = 0
		pip.ZIndex = look.zIndex + 2
		-- AN OUTLINE (task 135). On the report it is the ZONE's own colour -- head, chest, rear,
		-- legs or body at a glance -- which is the one thing the old tinted rectangles told you that
		-- a plain silhouette does not; the tints are `Boar.CONFIG.ZONES`' own, mirrored into
		-- `Report.CONFIG.SILHOUETTE` and asserted against the source by
		-- `tests/server/report_silhouette.spec.luau`. On the hit card it is one fixed pale ring,
		-- because there the animal is one fixed near-black and a red dot needs separating from it
		-- rather than naming.
		local edge = Instance.new("UIStroke")
		edge.Thickness = look.ringThickness or CONFIG.RING_THICKNESS
		-- A zone this panel does not draw falls back to the trunk's own colour rather than erroring
		-- on a string that came off the wire.
		edge.Color = look.ring or RING[tostring(dot.zone or "")] or RING.body or Color3.new(0, 0, 0)
		edge.Parent = pip
		pip.Rotation = if dot.fatal then 45 else 0 -- the fatal dot reads as an X at a glance
		-- ...WHICH ONLY WORKS IF THE OTHERS ARE ROUND (task 135). They were all squares, so the
		-- fatal one was a square turned 45 degrees among squares; a round hit beside a turned one
		-- reads as a different KIND of mark rather than the same mark at a different angle. The
		-- fatal marker itself is untouched -- same size, same kill colour, same turn.
		if not dot.fatal then
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = pip
		end
		-- The numbers a spec reads, on the thing itself: no second table to drift from the picture.
		pip:SetAttribute("U", dot.u or 0)
		pip:SetAttribute("V", dot.v or 0)
		pip:SetAttribute("Zone", tostring(dot.zone or ""))
		pip:SetAttribute("Fatal", dot.fatal == true)
		-- WHICH DOT THE DRIVE REPORT DRAWS (task 198). A hit card carries one dot per PELLET and the
		-- report carries one per SHOT -- the nearest impact -- so `lead` is the mark the two have in
		-- common, set by `HitLog.Shape.cardDots` and read here by the card when the kill arrives a
		-- tick later. Always false on the report's own dots, which have no such thing.
		pip:SetAttribute("Lead", dot.lead == true)
		pip.Parent = art
	end
end

-- Every dot drawn on one piece of art, as the attributes above carry them. The one check that "the
-- hit is shown where it landed" is a check and not a hope, and it is here rather than in either
-- screen so both read the picture the same way.
function BoarArt.dotsOf(art: Instance?): { { u: number, v: number, zone: string, fatal: boolean } }
	local out = {}
	for _, child in ipairs(if art then art:GetChildren() else {}) do
		if child:IsA("Frame") and child.Name == "Dot" then
			table.insert(out, {
				u = (child:GetAttribute("U") :: number?) or 0,
				v = (child:GetAttribute("V") :: number?) or 0,
				zone = (child:GetAttribute("Zone") :: string?) or "",
				fatal = (child:GetAttribute("Fatal") :: boolean?) == true,
			})
		end
	end
	return out
end

return BoarArt

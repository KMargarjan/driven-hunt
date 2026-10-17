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
	-- ONE COLOUR, FOURTEEN PARTS, NO ART FILE. Every number is a SCALE of this frame, so the same
	-- fourteen parts draw the same animal at 104 x 56 in a report row and at 148 x 80 on the card.
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
	for _, dot in ipairs(dots or {}) do
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
		local drawnU, drawnV = Report.ontoBoar(
			insetU + math.clamp(dot.u or 0, 0, 1) * (1 - 2 * insetU),
			insetV + math.clamp(dot.v or 0, 0, 1) * (1 - 2 * insetV)
		)
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

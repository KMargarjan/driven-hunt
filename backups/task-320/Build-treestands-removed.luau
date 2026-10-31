-- ONE CLIMB PROMPT (step B10, item 6). It is `makePrompt`'s shape with its own key and its own two
-- words, because the way up is not the way into the menu: the key is DATA (`CLIMB.UP_KEY` /
-- `DOWN_KEY`) and the two must differ on the deck, where both are in reach -- see the note's 8.2.
local function makeClimbPrompt(
	name: string,
	host: BasePart,
	localAt: Vector3,
	action: string,
	key: Enum.KeyCode,
	layout
)
	local at = Instance.new("Attachment")
	at.Name = "RangeClimbAt"
	at.Position = localAt
	at.Parent = host
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = layout.CLIMB.OBJECT_TEXT
	prompt.KeyboardKeyCode = key
	prompt.MaxActivationDistance = layout.CLIMB.MaxActivationDistance
	prompt.HoldDuration = layout.CLIMB.HoldDuration
	prompt.RequiresLineOfSight = false
	prompt.Parent = at
	return prompt

-- ONE PART FROM ONE `HighSeats.Piece`, and every flag comes from the plan rather than from a
-- default here -- `ForestTest.Seats`' own `build`, which is the only other writer of a seat.
-- The class is the plan's: a `TrussPart` is what a Humanoid climbs, with no script and no key.
local function makePiece(spec: any, parent: Instance): BasePart
	local part = Instance.new(spec.class) :: any
	part.Name = spec.name
	part.Size = spec.size
	part.CFrame = spec.cframe
	part.Anchored = true
	part.CanCollide = spec.canCollide
	part.CanQuery = spec.canQuery
	part.CanTouch = false
	part.CastShadow = spec.castShadow
	part.Color = spec.color
	part.Material = spec.material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if spec.style ~= nil then
		part.Style = spec.style
	end
	part.Parent = parent
	return part :: BasePart
end

	-- THE SECOND FIRING POSITION, STATION BY STATION (design 7.1-7.3). The ground under the seat's
	-- OWN five footprint points is measured and handed to `HighSeats.plan`, which REFUSES a seat on
	-- ground it cannot build on (`MAX_FOOT_SPREAD_STUDS` 4.0) -- and a refused station is a bench
	-- only, as DATA: `deckTops[spot]` is simply absent and `Range.spotAt` can then never answer
	-- `treestand` there. No branch anywhere.
	local facing = RangeData.standFacing(layout, dir)
	local samples = HighSeats.footprint(facing)
	local deckTops: { [number]: number } = {}
	local stands, refusedStands = 0, 0
	local standRefusals: { string } = {}
	for spot = 1, layout.SPOT_COUNT do
		local at = RangeData.standPosition(anchor, spot, layout, dir)
		local grounds: { number? } = {}
		for index, offset in ipairs(samples) do
			if row.plate == true then
				-- A PLATE IS ONE FLAT SHELF, so the five readings are one number and the spread is
				-- zero: the DEV arm takes no ray at all (`shelfAt`'s own rule).
				grounds[index] = shelf
			elseif opts.groundAt ~= nil then
				grounds[index] = opts.groundAt(at.X + offset.dx, at.Z + offset.dz)
			end
		end
		-- `plan` reads the stand point's X and Z only -- every height it builds comes from the five
		-- readings -- so the shelf in `at.Y` changes nothing it lays.
		local pieces, why = HighSeats.plan(at, grounds, facing)
		local ladder: BasePart? = nil
		if pieces == nil then
			refusedStands += 1
			table.insert(standRefusals, string.format("%d: %s", spot, tostring(why)))
		else
			local seat = Instance.new("Folder")
			seat.Name = RangeData.standName(spot)
			local deck: BasePart? = nil
			for _, spec in ipairs(pieces :: { any }) do
				local part = makePiece(spec, seat)
				if part.Name == "Deck" then
					deck = part
				elseif part.Name == "Ladder" then
					ladder = part
				end
			end
			seat.Parent = folder
			stands += 1
			local deckTop = HighSeats.deckTopFor(grounds)
			if deckTop ~= nil then
				deckTops[spot] = deckTop :: number
			end
			-- THE STAND'S PROMPT, at the rail's own top on the UPRANGE face. It hangs on the DECK
			-- and not on the rail board, which is a stated deviation from design 7.3: the deck is
			-- the one piece whose NAME does not move when `facing` mirrors the rail, and
			-- `Range.promptPointOf` reads the attachment's WorldPosition -- so the prompt's world
			-- point is the design's number either way, and `range.spec` asserts that identity.
			if deck ~= nil and deckTop ~= nil then
				local point = Vector3.new(
					(deck :: BasePart).Position.X,
					(deckTop :: number) + layout.STAND.promptRise,
					(deck :: BasePart).Position.Z - dir * HighSeats.DIMS.RAIL_PLANE_STUDS
				)
				makePrompt(
					RangeData.promptName(spot, RangeData.POSITION.TREESTAND),
					deck :: BasePart,
					point - (deck :: BasePart).Position,
					layout
				)
				-- THE WAY DOWN, on `CLIMB.DOWN_KEY` (F) over the rail's gap. On the DECK and not on
				-- the rail board, for `makePrompt`'s own stated reason: the deck is the one piece
				-- whose name does not move when `facing` mirrors the rail.
				makeClimbPrompt(
					RangeData.climbPromptName(spot, "down"),
					deck :: BasePart,
					RangeData.downPromptPosition(anchor, spot, layout, dir, deckTop) - (deck :: BasePart).Position,
					layout.CLIMB.DOWN_ACTION,
					layout.CLIMB.DOWN_KEY,
					layout
				)
			end
			-- THE WAY UP, on `CLIMB.UP_KEY` (E) at the ladder's foot (step B10, item 6). B9 measured
			-- TWICE that a real `W` against this `TrussPart` never climbs (`ESCALATE.md`, B9), so the
			-- climb is a prompt and the server moves the body -- `Range.onClimb` is its one handler.
			if ladder ~= nil then
				local foot = RangeData.ladderFootPosition(anchor, spot, layout, dir)
				local point = Vector3.new(foot.X, groundAtOr(foot.X, foot.Z) + layout.CLIMB.footRise, foot.Z)
				makeClimbPrompt(
					RangeData.climbPromptName(spot, "up"),
					ladder :: BasePart,
					point - (ladder :: BasePart).Position,
					layout.CLIMB.UP_ACTION,
					layout.CLIMB.UP_KEY,
					layout
				)
			end
		end
	end

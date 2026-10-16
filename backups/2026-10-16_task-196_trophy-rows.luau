	TROPHIES = {
		HEIGHT_STUDS = 4.8, -- above the floorboards: above a standing player's head
		-- THE SHIELD IS LIGHTER THAN THE WALL BEHIND IT and the antlers are not white: at RGB
		-- 228,219,198 on a 72,50,34 plaque the first photograph showed white twigs floating on a dark
		-- wall. Weathered antler is a warm grey-bone, and a `Trophaeenschild` is polished linden.
		PLAQUE_COLOR = Color3.fromRGB(104, 72, 44),
		BONE_COLOR = Color3.fromRGB(186, 173, 146),
		ROE = {
			PLAQUE = Vector3.new(1.8, 2.4, 0.35),
			SEGMENTS = 3,
			SEGMENT_STUDS = 0.9,
			TINE_STUDS = 0.7,
			TINES = 2,
			THICK = 0.34,
			SPREAD = 0.45,
			CURVE = -0.16,
		},
		-- OVER THE DOOR, AND IT IS SMALL BECAUSE THE BAND IT HANGS IN IS (round 3): the lintel's top
		-- below it and the south roof slope's own underside above, which is barely three studs. A
		-- lodge's door carries a modest roe plate; the big trophy goes where there is room for one.
		DOOR = {
			PLAQUE = Vector3.new(1.9, 1.2, 0.4),
			SEGMENTS = 2,
			SEGMENT_STUDS = 0.5,
			TINE_STUDS = 0.4,
			TINES = 1,
			THICK = 0.24,
			SPREAD = 0.5,
			CURVE = -0.12,
		},
		-- THE BIG ONE, ON THE EAST GABLE: eight studs above a man's head, read from the truck pads,
		-- where the indoor stag is read from four studs away across a table.
		GABLE = {
			PLAQUE = Vector3.new(4.2, 4.6, 0.6),
			SEGMENTS = 4,
			SEGMENT_STUDS = 1.6,
			TINE_STUDS = 1.3,
			TINES = 3,
			THICK = 0.6,
			SPREAD = 0.5,
			CURVE = -0.16,
		},
		STAG = {
			PLAQUE = Vector3.new(2.8, 3.2, 0.5),
			SEGMENTS = 3,
			SEGMENT_STUDS = 1.15,
			TINE_STUDS = 0.9,
			TINES = 3,
			THICK = 0.42,
			SPREAD = 0.5,
			CURVE = -0.18,
		},
		BOAR = {
			PLAQUE = Vector3.new(2.2, 2.6, 0.4),
			TUSK_STUDS = 1.15,
			THICK = 0.32,
			SEGMENTS = 2,
			SEGMENT_STUDS = 1.15,
		},
		-- THE ROWS. The east wall carries the classic grid, the north wall's west half the rest, and
		-- the two beside the door are what a player sees first from inside. Nothing hangs on the
		-- south wall's windows, the counter's half of the north wall, or the west wall except the
		-- stag over the fire -- those are spoken for.
		--
		-- TWO HEIGHTS AND TWO HEIGHTS ONLY, AND EVERY ROW SYMMETRIC ABOUT ITS WALL'S CENTRE (task
		-- 195). Karen asked for *"nice inside"* and the Director for *"even rows"*; before this the
		-- east wall carried four plaques at 4.8 and two more at 8.2 on `along` values that matched
		-- neither row, and the north wall's boar hung at 5 between two roe at 4.8. A row is a row
		-- when the eye can see it is one, so `HEIGHT_STUDS` and `UPPER_STUDS` are the only two
		-- heights in this table and `lobby.spec` asserts exactly that.
		UPPER_STUDS = 8.2,
		MOUNTS = {
			-- THE EAST GABLE: a 2 x 4 grid, two each side of its one window on each of the two rows.
			{ kind = "roe", wall = "east", along = -9.4 },
			{ kind = "roe", wall = "east", along = -6.6 },
			{ kind = "roe", wall = "east", along = 6.6 },
			{ kind = "roe", wall = "east", along = 9.4 },
			{ kind = "roe", wall = "east", along = -9.4, height = 8.2 },
			{ kind = "roe", wall = "east", along = -6.6, height = 8.2 },
			{ kind = "roe", wall = "east", along = 6.6, height = 8.2 },
			{ kind = "roe", wall = "east", along = 9.4, height = 8.2 },
			-- THE NORTH WALL'S WEST HALF, clear of the counter and of its window: one row of three,
			-- the boar in the middle at the SAME height as the two roe beside it.
			{ kind = "roe", wall = "north", along = -7 },
			{ kind = "boar", wall = "north", along = -3.5 },
			{ kind = "roe", wall = "north", along = 0 },
			-- EITHER SIDE OF THE DOOR, between it and the front windows: the two a player sees
			-- first when he turns round inside.
			{ kind = "roe", wall = "south", along = -6 },
			{ kind = "roe", wall = "south", along = 6 },
			-- AND THE RED STAG OVER THE FIRE, on the chimney breast rather than inside it.
			{ kind = "stag", wall = "west", along = 4, height = 8.2, standoff = 3.2 },
		},
	},

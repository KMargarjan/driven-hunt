	-- THE GUN RACK on the west wall, south of the fireplace: a board, its pegs, and two long guns.
	-- It is scenery and holds nothing -- `Weapon.Hardware` is the only thing in this game that builds
	-- a gun a player can touch. `face` looks INTO the room, the same convention every trophy uses.
	local rack = cfg.LODGE.RACK
	local face = CFrame.new(origin.X - room.halfX, origin.Y + rack.HEIGHT_STUDS, origin.Z + rack.ALONG_STUDS)
		* CFrame.Angles(0, -math.pi / 2, 0)
	part(
		"GunRackBoard",
		Vector3.new(rack.WIDTH, 3.6, 0.4),
		face * CFrame.new(0, 0, -0.2),
		cfg.TROPHIES.PLAQUE_COLOR,
		Enum.Material.Wood,
		false,
		inside
	)
	for index = 1, 3 do
		local along = -rack.WIDTH / 2 + index * rack.WIDTH / 4
		for peg, dy in ipairs({ -1.2, 1.2 }) do
			local hook = part(
				string.format("GunRackPeg%d_%d", index, peg),
				Vector3.new(0.9, 0.3, 0.3),
				-- -0.8 AND NOT -0.9 (task 195): a 0.9-long peg centred 0.9 out from a board whose
				-- face is 0.4 away begins 0.05 studs clear of it -- two pegs hanging in the air,
				-- which the live scan found and nothing else could.
				face * CFrame.new(along, dy, -0.8) * CFrame.Angles(0, math.pi / 2, 0),
				cfg.LODGE.TIMBER_COLOR,
				Enum.Material.Wood,
				false,
				inside
			)
			hook.Shape = Enum.PartType.Cylinder
		end
		if index < 3 then
			part(
				string.format("GunRackBarrel%d", index),
				Vector3.new(0.35, 4.6, 0.35),
				face * CFrame.new(along + 0.4, 0.6, -1.1) * CFrame.Angles(0, 0, 0.06),
				Color3.fromRGB(46, 46, 48),
				Enum.Material.Metal,
				false,
				inside
			)
			part(
				string.format("GunRackStock%d", index),
				Vector3.new(0.7, 2.1, 0.5),
				face * CFrame.new(along + 0.4, -2.1, -1.1),
				Color3.fromRGB(96, 62, 38),
				Enum.Material.Wood,
				false,
				inside
			)
		end
	end


		it("OVERFLOWS the clearing that was measured for ONE station, which is design 2.3's finding", function()
			local built, _, parent = buildWith(FOREST_ROW, function()
				return FAKE_SHELF
			end)
			local b = built :: any
			local parts = partsOf(b.folder)
			local names = {}
			for _, part in ipairs(parts) do
				table.insert(names, part.Name)
			end
			table.sort(names)
			local box = footprintOf(parts)
			-- THE RECTANGLE WAS RIGHT FOR ONE STATION ON THE 125 LANE, and this arm proves the
			-- measurement was not wrong -- the SHAPE changed under it (design 2.3).
			local one = layoutWith({ SPOT_COUNT = 1, DISTANCES_STUDS = { LAYOUT.DISTANCE_STUDS } })
			local oneParent = Instance.new("Folder")
			local oneBuilt = Range.Build.build({
				parent = oneParent,
				row = FOREST_ROW,
				layout = one,
				groundAt = function()
					return FAKE_SHELF
				end,
			})
			local oneBox = footprintOf(partsOf((oneBuilt :: any).folder))
			expect(oneBox.minX >= MEASURED.minX).to.equal(true)
			expect(oneBox.maxX <= MEASURED.maxX).to.equal(true)
			expect(oneBox.minZ >= MEASURED.minZ).to.equal(true)
			-- A THIRD OVERFLOW, AND IT IS NEW IN STEP B3: the rectangle was sampled for a firing
			-- line with NOTHING behind it, and the treestand stands `standReach` UPRANGE of the mat.
			-- So one station no longer fits the measured clearing either -- not east or south, but
			-- BEHIND the shooter. B8's census must cover it.
			local overStand = oneBox.maxZ - MEASURED.maxZ
			expect(overStand > 0).to.equal(true)
			local ladderEdge = LAYOUT.STAND.backStuds
				+ math.abs(HighSeats.DIMS.LADDER_OFFSET_STUDS)
				+ HighSeats.DIMS.LADDER_SIZE_STUDS / 2
			expect(math.abs(overStand - (((FOREST_ROW :: any).z + ladderEdge) - MEASURED.maxZ)) < 1e-6).to.equal(true)
			expect(ladderEdge <= RangeData.standReach(LAYOUT)).to.equal(true)
			TestKit.note(
				string.format(
					"range B3: the treestand overflows the clearing measured for one station by %.1f studs UPRANGE (z %.1f against %d)",
					overStand,
					oneBox.maxZ,
					MEASURED.maxZ
				)
			)
			oneParent:Destroy()
			-- ...AND SIX DO NOT FIT IT, east by the station span and south by the 179 lane. Step B8
			-- moves the row to the site design 2.1 chose and re-samples it; nothing is built in her
			-- place until it does, because `Range.ENABLED` is dark.
			local overX = box.maxX - MEASURED.maxX
			local overZ = MEASURED.minZ - box.minZ
			expect(overX > 0).to.equal(true)
			expect(overZ > 0).to.equal(true)
			expect(math.abs(overX - (oneBox.maxX + RangeData.spotSpan(LAYOUT) - MEASURED.maxX)) < 1e-6).to.equal(true)
			expect(
				math.abs(overZ - (MEASURED.minZ - (oneBox.minZ - (RangeData.distanceMax(LAYOUT) - one.DISTANCE_STUDS))))
					< 1e-6
			).to.equal(true)
			TestKit.note(
				string.format(
					"range forest footprint: x %.1f..%.1f z %.1f..%.1f -- OVERFLOWS the measured x %d..%d z %d..%d by %.1f east and %.1f south (one station fits: x %.1f..%.1f); parts %s",
					box.minX,
					box.maxX,
					box.minZ,
					box.maxZ,
					MEASURED.minX,
					MEASURED.maxX,
					MEASURED.minZ,
					MEASURED.maxZ,
					overX,
					overZ,
					oneBox.minX,
					oneBox.maxX,
					table.concat(names, ", ")
				)
			)
			parent:Destroy()
		end)

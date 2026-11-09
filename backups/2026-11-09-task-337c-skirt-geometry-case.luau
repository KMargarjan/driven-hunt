-- ARCHIVED BY TASK 337c (rule 7). `tests/server/grid.spec.luau` case 16 at main efe88ab2: the
-- skirt reached into BARE neighbours only, so the case asserted `hitEach[planted] == nil` and
-- `count > 0 == bare > 0`. 337c skirts all four roads, outer edges included, and the
-- replacement asserts that instead. Design: cell-loading.md 8.1.

		it("reaches into every BARE neighbour from the shared road and stops at skirtStuds", function()
			local half = Grid.CONFIG.roadClearStuds / 2
			local lines = {}
			for _, id in ipairs(Grid.cellIds()) do
				local plan = Plan.cellPlanFor(id)
				local mine = Grid.boundsOf(id)
				local near = Plan.neighboursOf(id)
				-- A 2 x 4 GRID HAS NO CELL WITH FOUR NEIGHBOURS (design 8.3's skirt row is wrong
				-- about that, lesson L-167): a corner cell has 2 and a middle one 3.
				expect(#near >= 2 and #near <= 3).to.equal(true)
				local count, reach = 0, 0
				local hitEach: { [string]: number } = {}
				for _, item in ipairs(woods[id]) do
					if item.side < 0 then
						count += 1
						-- A ROW CARRIES THE WORLD POINT AND EVERY BOX HERE IS A GRID RECT
						-- (task 328r): the skirt is placed in grid space, so that is where it is
						-- inside exactly one neighbour.
						local gx, gz = Grid.toGrid(item.x, item.z)
						-- IT IS OUTSIDE THE ACTIVE CELL...
						local inside = gx > mine.minX and gx < mine.maxX and gz > mine.minZ and gz < mine.maxZ
						expect(inside).to.equal(false)
						-- ...AND INSIDE EXACTLY ONE NEIGHBOUR, within `skirtStuds` of the road the
						-- two of them share.
						local found = nil
						for _, other in ipairs(near) do
							local box = Grid.boundsOf(other.id)
							if gx >= box.minX and gx <= box.maxX and gz >= box.minZ and gz <= box.maxZ then
								expect(found).to.equal(nil)
								found = other
							end
						end
						expect(found ~= nil).to.equal(true)
						hitEach[found.id] = (hitEach[found.id] or 0) + 1
						-- THE DISTANCE FROM THE SHARED ROAD'S OWN CENTRE LINE. The band starts at
						-- the neighbour's inset edge, which is `roadClear / 2 + CELL_EDGE_STUDS`
						-- from that centre, and runs `skirtStuds` further.
						local gap
						if found.axis == "z" then
							local centre = if gx > mine.maxX then mine.maxX + half else mine.minX - half
							gap = math.abs(gx - centre)
						else
							local centre = if gz > mine.maxZ then mine.maxZ + half else mine.minZ - half
							gap = math.abs(gz - centre)
						end
						expect(gap >= half + Plan.CELL_EDGE_STUDS).to.equal(true)
						expect(gap <= half + Plan.CELL_EDGE_STUDS + plan.skirtStuds).to.equal(true)
						reach = math.max(reach, gap)
						-- AND IT IS THE NEIGHBOUR'S OWN WOOD, not this cell's: the species came from
						-- the zone the point is in over THERE, which is what makes two sections
						-- either side of one road read differently.
						local zoneThere = Plan.zoneAt(found.id, gx, gz)
						expect(zoneThere ~= nil).to.equal(true)
						expect(zoneThere.spacingStuds > 0).to.equal(true)
						-- ...THROUGH THE FRONTAGE RULE (task 328f): within 60 studs of a road or a
						-- ride centreline only `frontage.groups` are drawn, so the mix a skirt
						-- planting comes from is the neighbour zone's mix AS THAT RULE LEAVES IT.
						-- `frontageRows` returns the mix unchanged outside the band.
						local theirPlan = Plan.cellPlanFor(found.id)
						local rows = Plan.cellMixNamed(zoneThere.mix)
						if Plan.inFrontage(found.id, item.x, item.z) then
							rows = Plan.frontageRows(theirPlan, rows)
						end
						local names = {}
						for _, row in ipairs(rows) do
							for _, name in ipairs((Plan.SPECIES :: any)[row.group]) do
								names[name] = true
							end
						end
						expect(names[item.model]).to.equal(true)
					end
				end
				-- EVERY BARE NEIGHBOUR IS DRESSED, not just the first one found -- AND NO PLANTED
				-- ONE IS (task 328i): a skirt over a wood that is already there is a second wood
				-- laid on the first, and `minGapStuds` runs over one cell's own grid and cannot
				-- see it. Both halves are asserted, so neither "it skirts everything" nor "it
				-- skirts nothing" can pass.
				for _, other in ipairs(near) do
					if Plan.hasOwnWood(other.id) then
						expect(hitEach[other.id]).to.equal(nil)
					else
						expect((hitEach[other.id] or 0) > 0).to.equal(true)
					end
				end
				-- A CELL WITH A BARE NEIGHBOUR SKIRTS; A CELL WHOSE NEIGHBOURS ARE ALL PLANTED
				-- DRAWS NOTHING AT ALL. C1 is the second kind, and it is the only one today.
				local bare = 0
				for _, other in ipairs(near) do
					if not Plan.hasOwnWood(other.id) then
						bare += 1
					end
				end
				expect(count > 0).to.equal(bare > 0)
				table.insert(
					lines,
					string.format(
						"%s %d into %d bare of %d (reach %.0f/%d)",
						id,
						count,
						bare,
						#near,
						reach,
						plan.skirtStuds
					)
				)
			end
			TestKit.note("skirt: " .. table.concat(lines, " "))
		end)

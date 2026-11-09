-- ARCHIVED BY TASK 337c (rule 7). `tests/server/grid.spec.luau` case 18c as it stood at main
-- efe88ab2, asserting task 328i's rule: a cell draws NO skirt into a planted neighbour. Task
-- 337c inverts that rule -- under one cell at a time a neighbour's wood is never standing, so
-- every one of a cell's four roads is skirted -- and the replacement case asserts the inverse.
-- Karen, 2026-11-09: "behind the road always has to be forest". Design: cell-loading.md 8.1.

		-- THE SKIRT RULE, which is what keeps two planted cells' woods out of each other. MEASURED
		-- in Karen's place with the skirt still drawn and all five cells standing: 199 pairs of
		-- trunks inside 6 studs and 59 inside 3, worst 0.54 -- against 0 and 0 WITHIN a cell, same
		-- instrument, same run (`<runs-dir>/328i-overlap-after.txt`).
		it("draws no skirt into a planted neighbour, and still skirts a bare one", function()
			-- C1's three neighbours are ALL planted, so it draws none.
			for _, near in ipairs(Plan.neighboursOf(Grid.DEFAULT_CELL)) do
				expect(Plan.hasOwnWood(near.id)).to.equal(true)
			end
			local c1Skirt = 0
			for _, item in ipairs(woods[Grid.DEFAULT_CELL]) do
				if item.side < 0 then
					c1Skirt += 1
				end
			end
			expect(c1Skirt).to.equal(0)
			-- ...AND A CELL WITH A BARE NEIGHBOUR STILL DRESSES IT, so the case fails if `plantCell`
			-- simply stopped skirting. C2's B2 and D2 are not planted; A1 is in no list at all.
			-- ...AND A CELL WITH A BARE NEIGHBOUR STILL DRESSES IT. **THAT CELL IS B1 SINCE TASK 336**
			-- (it was C2, whose B2 and D2 are now planted): A1 is the one cell with no ground, so it
			-- is the one bare neighbour left in the world, and B1 is beside it.
			expect(Plan.hasOwnWood("B2")).to.equal(true)
			expect(Plan.hasOwnWood("A1")).to.equal(false)
			expect(Plan.hasOwnWood("Z9")).to.equal(false)
			local c2Skirt = 0
			for _, item in ipairs(woods.B1) do
				if item.side < 0 then
					c2Skirt += 1
				end
			end
			expect(c2Skirt > 0).to.equal(true)
			-- ...AND NOT ONE SKIRT SITE OF C2's LANDS INSIDE A PLANTED CELL'S OWN GROUND, which is
			-- the fact the collision measurement is about. Asked of the rectangle rather than of
			-- "the nearest cell", so a site in the road between two cells cannot flip the answer.
			local stray = 0
			for _, item in ipairs(woods.B1) do
				if item.side < 0 then
					for _, id in ipairs(Grid.PLANTED_CELLS) do
						local g = Plan.cellGround(id)
						if item.x >= g.minX and item.x <= g.maxX and item.z >= g.minZ and item.z <= g.maxZ then
							stray += 1
						end
					end
				end
			end
			expect(stray).to.equal(0)
			TestKit.note(string.format("skirt: C1 %d (3 planted neighbours), B1 %d into bare A1", c1Skirt, c2Skirt))
		end)

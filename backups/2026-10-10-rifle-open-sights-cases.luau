		it("is the SAME rifle with the glass off, and three things differ", function()
			-- Karen: *"and also we need to have option rifle without scope ... where aiming true
			-- nozzle"*. Everything that is not about the SIGHT must be the scoped rifle's, or it is
			-- a second gun rather than the same one carried differently.
			local scoped = Weapons.ROWS.rifle
			local open = Weapons.ROWS.rifle_open
			for _, key in ipairs({
				"RANGE_STUDS",
				"PELLETS",
				"SPREAD_FULL_DEG",
				"AMMO_KINDS",
				"START_RESERVE",
				"BARRELS",
				"BARREL_DELAY",
				"CYCLE",
				"CYCLE_TOTAL",
				"CYCLE_EJECTS",
				"RELOAD",
				"MAGAZINE",
				"READOUT",
				"HANDLE_SIZE",
				"SOUND",
			}) do
				expect((open :: any)[key]).to.equal((scoped :: any)[key])
			end
			-- ...AND THE THREE THAT DO. (1) no scope at all, which is what hands it the shotgun's
			-- bead zoom with no reticle, no mask and no sway.
			expect(scoped.scope).to.be.ok()
			expect(open.scope).to.equal(nil)
			-- (2) it does not wear the scope's upload.
			expect(#open.ASSET_KEYS).to.equal(#scoped.ASSET_KEYS - 1)
			for _, key in ipairs(open.ASSET_KEYS) do
				expect(key).never.to.equal("rifle.scope")
			end
			-- (3) its geometry draws a BEAD instead of the tube.
			expect(open.SIGHT).to.equal("bead")
			expect(scoped.SIGHT).to.equal("scope")
			local geometry = Weapons.geometry("rifle_open")
			local names = {}
			for _, piece in ipairs(geometry.pieces(open)) do
				names[piece.name] = true
			end
			expect(names.Bead).to.equal(true)
			expect(names.Scope).to.equal(nil)
			-- ...and the scoped one is the mirror of that, from the SAME piece list.
			local scopedNames = {}
			for _, piece in ipairs(geometry.pieces(scoped)) do
				scopedNames[piece.name] = true
			end
			expect(scopedNames.Scope).to.equal(true)
			expect(scopedNames.Bead).to.equal(nil)
			-- THE EYE LOOKS SOMEWHERE ELSE, and that is the whole of "aiming true nozzle": down the
			-- barrel to a bead at the muzzle instead of into an ocular lens at the back.
			local beadSight = geometry.sight(open)
			local scopeSight = geometry.sight(scoped)
			expect(beadSight.Z < scopeSight.Z).to.equal(true)
			expect(math.abs(beadSight.Z - (-open.HANDLE_SIZE.Z / 2)) < 0.1).to.equal(true)
			-- ...on the gun's own centre line, so it looks exactly where the barrel points.
			expect(math.abs(beadSight.X) < 1e-9).to.equal(true)
			-- ...AND IT IS THE SAME EXPRESSION THE DRAWN BEAD USES, not a copy of it (the Reviewer's
			-- round-1 note, and the rule `Gun.beadOffset` already keeps for the shotgun).
			local drawn = nil
			for _, piece in ipairs(geometry.pieces(open)) do
				if piece.name == "Bead" then
					drawn = piece.offset.Position
				end
			end
			expect(drawn).to.be.ok()
			expect((drawn :: Vector3) - geometry.beadOffset(open)).to.equal(Vector3.zero)
			expect(beadSight.Position).to.equal(geometry.beadOffset(open))
		end)


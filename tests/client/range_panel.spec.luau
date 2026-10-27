-- The range's MENU and its BOARD, on the client (design 11.2). Every list is asserted against the
-- SHIPPED table it is read from and never against a literal in this file.
--
-- Task 298 step B4. Fakes for the prompt: *"a spec cannot fire a real ProximityPrompt"*
-- (`ShopPanel.setPrompt`), so the open is driven through the shipped `setPrompt` seam.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterPlayer = game:GetService("StarterPlayer")

	local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
	local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
	local Report = require(ReplicatedStorage:WaitForChild("Report"))
	local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local Hud = scripts:WaitForChild("Hud")
	local RangePanel = require(Hud:WaitForChild("RangePanel"))
	local RangeBoard = require(Hud:WaitForChild("RangeBoard"))
	local Cursor = require(scripts:WaitForChild("Camera"):WaitForChild("Cursor"))
	local WeaponInput = require(scripts:WaitForChild("Weapon"):WaitForChild("Input"))

	-- A PLAIN SYNCHRONOUS SIGNAL, because a `BindableEvent` fires DEFERRED and a spec driving one
	-- could never read the result in the same frame (measured, task 181).
	local function fakePrompt()
		local handlers = {}
		return {
			Triggered = {
				Connect = function(_, handler)
					table.insert(handlers, handler)
					return { Disconnect = function() end }
				end,
			},
			fire = function()
				for _, handler in ipairs(handlers) do
					handler()
				end
			end,
		}
	end

	local function freshPanel(): ({ any }, Frame)
		local frame = Instance.new("Frame")
		local sent = {}
		RangePanel.start(frame, {
			Cursor = Cursor,
			Input = WeaponInput,
			send = function(request)
				table.insert(sent, request)
			end,
		})
		return sent, frame
	end

	local function lists(): any
		local weapons = {}
		for _, id in ipairs(Weapons.ORDER) do
			local row = Weapons.row(id)
			table.insert(weapons, {
				id = id,
				label = row.label,
				ammo = row.AMMO_KINDS,
				ammoLabel = row.AMMO_LABEL,
			})
		end
		return {
			species = { "boar", "reddeer" },
			kinds = { "male", "female", "cub" },
			pace = RangeData.PACE_ORDER,
			weapons = weapons,
			distances = RangeData.DISTANCES_STUDS,
		}
	end

	describe("the range menu", function()
		afterEach(function()
			RangePanel.stop()
			RangeBoard.stop()
		end)

		it("opens and closes through the prompt, and holds the two doors by the tag range", function()
			local _, frame = freshPanel()
			local prompt = fakePrompt()
			RangePanel.setPrompt(prompt)
			expect(RangePanel.hasPrompt()).to.equal(true)
			expect(RangePanel.isOpen()).to.equal(false)
			-- WHAT WAS ALREADY OUT, so the claim is "the range added its own tag and gave it back"
			-- and not "nothing else in this live client ever holds one" (which is not this task's).
			local reassertsBefore = Cursor.stats().reasserts
			local cursorBefore = #Cursor.stats().tags
			local heldBefore = #WeaponInput.holdTags()

			prompt.fire()
			expect(RangePanel.isOpen()).to.equal(true)
			expect(frame.Visible).to.equal(true)
			-- THE TWO DOORS, BY TAG (design 11.2 item 2).
			expect(Cursor.isFree()).to.equal(true)
			local function hasTag(list, wanted: string): boolean
				for _, tag in ipairs(list) do
					if tag == wanted then
						return true
					end
				end
				return false
			end
			expect(hasTag(Cursor.stats().tags, "range")).to.equal(true)
			expect(#Cursor.stats().tags).to.equal(cursorBefore + 1)
			expect(WeaponInput.isHeld()).to.equal(true)
			expect(hasTag(WeaponInput.holdTags(), "range")).to.equal(true)
			expect(#WeaponInput.holdTags()).to.equal(heldBefore + 1)
			-- `Cursor.apply` IS THE ONE PER-FRAME WRITER and the panel is not a second one.
			expect(Cursor.stats().reasserts).to.equal(reassertsBefore)

			prompt.fire()
			expect(RangePanel.isOpen()).to.equal(false)
			-- BOTH RELEASED BY TAG, AND NOTHING ELSE'S TAG TOUCHED.
			expect(hasTag(Cursor.stats().tags, "range")).to.equal(false)
			expect(#Cursor.stats().tags).to.equal(cursorBefore)
			expect(hasTag(WeaponInput.holdTags(), "range")).to.equal(false)
			expect(#WeaponInput.holdTags()).to.equal(heldBefore)
			expect(Cursor.stats().reasserts).to.equal(reassertsBefore)
		end)

		it("offers exactly the four pace words, STAND among them", function()
			local _, _frame = freshPanel()
			RangePanel.setState({ lists = lists() })
			local values = RangePanel.valuesFor("pace")
			expect(#values).to.equal(4)
			local seen = {}
			for _, entry in ipairs(values) do
				seen[entry.value] = true
			end
			-- KAREN, 2026-10-27: *"walk trot stand run"*. Asserted against `Range.WORD`, the shipped
			-- table the words cross the wire as, not against four strings typed here.
			expect(seen[RangeData.WORD.STAND]).to.equal(true)
			expect(seen[RangeData.WORD.WALK]).to.equal(true)
			expect(seen[RangeData.WORD.TROT]).to.equal(true)
			expect(seen[RangeData.WORD.RUN]).to.equal(true)
		end)

		it("reads the gun rows and each gun's own cartridges from Weapons", function()
			local _, _frame = freshPanel()
			RangePanel.setState({ lists = lists() })
			local guns = RangePanel.valuesFor("weapon")
			expect(#guns).to.equal(#Weapons.ORDER)
			for index, entry in ipairs(guns) do
				expect(entry.value).to.equal(Weapons.ORDER[index])
			end
			-- THE CARTRIDGE ROWS ARE THE CHOSEN GUN'S OWN, and they CHANGE with the gun.
			for _, id in ipairs(Weapons.ORDER) do
				RangePanel.select("weapon", id)
				local loads = RangePanel.valuesFor("ammo")
				expect(#loads).to.equal(#Weapons.row(id).AMMO_KINDS)
				for index, entry in ipairs(loads) do
					expect(entry.value).to.equal(Weapons.row(id).AMMO_KINDS[index])
				end
			end
			-- ...AND A LOAD THE GUN DOES NOT CARRY IS REFUSED BY THE SENDER ITSELF, through the one
			-- shared whitelist (`Lobby.roleAllowed`'s rule).
			RangePanel.select("weapon", "rifle")
			RangePanel.select("ammo", "buck")
			expect(RangePanel.selected("ammo")).never.to.equal("buck")
		end)

		it("sends exactly one request, carrying the selected trial", function()
			local sent = freshPanel()
			RangePanel.setState({ lists = lists() })
			RangePanel.select("pace", RangeData.WORD.STAND)
			RangePanel.select("weapon", "lever")
			RangePanel.select("ammo", Weapons.row("lever").AMMO_KINDS[1])
			expect(RangePanel.confirm()).to.equal(true)
			expect(#sent).to.equal(1)
			expect(sent[1].go).to.equal(true)
			expect(sent[1].pace).to.equal(RangeData.WORD.STAND)
			expect(sent[1].weapon).to.equal("lever")
			expect(sent[1].ammo).to.equal(Weapons.row("lever").AMMO_KINDS[1])
		end)
	end)

	describe("the board", function()
		local function record(extra: any): any
			local base = {
				spot = 1,
				species = "boar",
				kind = "male",
				pace = RangeData.WORD.TROT,
				weapon = "shotgun",
				ammo = "slug",
				distanceStuds = 125,
				paceStudsPerSecond = 12,
				issuedStudsPerSecond = 12,
				shots = 3,
				hits = 1,
				miss = 2,
				zoneOrder = { "head", "chest", "body", "rear", "legs" },
				zones = { head = 0, chest = 1, body = 0, rear = 0, legs = 0 },
				lastDistanceStuds = 125,
				crossingSeconds = 3.6,
				leadBallisticStuds = 1.83,
				leadViewStuds = 3.6,
				leadViewMeasured = false,
				lastGapStuds = nil,
				lastGapText = nil,
			}
			for key, value in pairs(extra or {}) do
				base[key] = value
			end
			return base
		end

		it("prints the animal's own zone columns, MISS, and the two lead numbers", function()
			local frame = Instance.new("Frame")
			RangeBoard.start(frame, { send = function() end })
			RangeBoard.setRecord(record({}))
			local text = table.concat(RangeBoard.rowText(), "\n")
			expect(string.find(text, "SHOTS 3") ~= nil).to.equal(true)
			expect(string.find(text, "HITS 1") ~= nil).to.equal(true)
			expect(string.find(text, "MISS 2") ~= nil).to.equal(true)
			-- A BOAR HAS FIVE ZONES AND NO `neck`: the columns are the animal's own (design 9.1).
			expect(string.find(text, "LEGS 0") ~= nil).to.equal(true)
			expect(string.find(text, "NECK") ~= nil).to.equal(false)
			expect(string.find(text, "LEAD BALLISTIC 1.83") ~= nil).to.equal(true)
			-- THE VIEW LEAD IS A BOUND, not a measurement, so it carries the marker.
			expect(string.find(text, "LEAD VIEW <=") ~= nil).to.equal(true)
			RangeBoard.stop()
		end)

		it("prints a red deer's six columns from the order it was sent", function()
			local frame = Instance.new("Frame")
			RangeBoard.start(frame, { send = function() end })
			RangeBoard.setRecord(record({
				species = "reddeer",
				kind = "hind",
				zoneOrder = { "head", "neck", "chest", "body", "rear", "legs" },
				zones = { head = 0, neck = 1, chest = 0, body = 0, rear = 0, legs = 0 },
			}))
			local text = table.concat(RangeBoard.rowText(), "\n")
			expect(string.find(text, "NECK 1") ~= nil).to.equal(true)
			RangeBoard.stop()
		end)

		it("prints the signed miss gap in metres, through the shared conversion", function()
			local frame = Instance.new("Frame")
			RangeBoard.start(frame, { send = function() end })
			-- THE SIGN: a shot BEHIND the target reads "behind" and one AHEAD reads "ahead". The two
			-- gaps are the same magnitude with opposite signs, which is what the lane's two
			-- directions produce (the server projects onto the target's own travel).
			RangeBoard.setRecord(record({ lastGapStuds = -3.2, lastGapText = RangeData.gapText(-3.2) }))
			local behind = table.concat(RangeBoard.rowText(), "\n")
			expect(string.find(behind, "behind") ~= nil).to.equal(true)
			expect(string.find(behind, "ahead") ~= nil).to.equal(false)
			RangeBoard.setRecord(record({ lastGapStuds = 3.2, lastGapText = RangeData.gapText(3.2) }))
			local ahead = table.concat(RangeBoard.rowText(), "\n")
			expect(string.find(ahead, "ahead") ~= nil).to.equal(true)
			expect(string.find(ahead, "behind") ~= nil).to.equal(false)
			-- ...AND THE METRES ARE THE REPOSITORY'S ONE CONVERSION, not a number typed here.
			local expected =
				string.format("%.1f", math.floor(math.abs(3.2 * Report.CONFIG.METRES_PER_STUD) * 10 + 0.5) / 10)
			expect(string.find(ahead, expected, 1, true) ~= nil).to.equal(true)
			RangeBoard.stop()
		end)

		it("asks the server to reset, through the same door as a pick", function()
			local frame = Instance.new("Frame")
			local sent = {}
			RangeBoard.start(frame, {
				send = function(request)
					table.insert(sent, request)
				end,
			})
			RangeBoard.setRecord(record({}))
			expect(RangeBoard.reset()).to.equal(true)
			expect(#sent).to.equal(1)
			expect(sent[1].reset).to.equal(true)
			expect(sent[1].spot).to.equal(1)
			RangeBoard.stop()
		end)
	end)
end

-- The range's MENU and its BOARD, on the client (design 11.2). Every list is asserted against the
-- SHIPPED table it is read from and never against a literal in this file.
--
-- Task 298 step B4. Fakes for the prompt: *"a spec cannot fire a real ProximityPrompt"*
-- (`ShopPanel.setPrompt`), so the open is driven through the shipped `setPrompt` seam.

return function()
	local ContextActionService = game:GetService("ContextActionService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterPlayer = game:GetService("StarterPlayer")

	local RangeData = require(ReplicatedStorage:WaitForChild("Range"))
	local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
	local Report = require(ReplicatedStorage:WaitForChild("Report"))
	local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
	local scripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local Hud = scripts:WaitForChild("Hud")
	-- THE RUNNING HUD (task 304), which is `player.PlayerScripts` and NOT `StarterPlayerScripts`:
	-- the engine COPIES the starter scripts into the player, so the module required off the starter
	-- copy is a second instance that never built a frame -- the first run of this case proved it,
	-- `rangeBoard()` there answered nil. `hud_clarity.spec`'s shape. These two drew Karen's screen,
	-- and the board is already bound to its frame by `Hud.start`.
	local livePlayer = game:GetService("Players").LocalPlayer
	local liveScripts = (livePlayer :: any):WaitForChild("PlayerScripts")
	local LiveHud = require(liveScripts:WaitForChild("Hud"))
	local LiveBoard = require((liveScripts :: any).Hud:WaitForChild("RangeBoard"))
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

		-- THE MENU CLOSES ON THE CONFIRM EDGE (Director's default for Karen; the proof found it
		-- still open over the released target, frame 11).
		it("closes on RELEASE THE TARGET and gives both doors back on that edge", function()
			local sent, frame = freshPanel()
			local prompt = fakePrompt()
			RangePanel.setPrompt(prompt)
			local cursorBefore = #Cursor.stats().tags
			local heldBefore = #WeaponInput.holdTags()
			prompt.fire()
			expect(RangePanel.isOpen()).to.equal(true)
			expect(#Cursor.stats().tags).to.equal(cursorBefore + 1)
			expect(#WeaponInput.holdTags()).to.equal(heldBefore + 1)

			expect(RangePanel.confirm()).to.equal(true)
			-- THE PICK STILL WENT, and then the menu went away.
			expect(#sent).to.equal(1)
			expect(sent[1].go).to.equal(true)
			expect(RangePanel.isOpen()).to.equal(false)
			expect(frame.Visible).to.equal(false)
			-- BOTH DOORS BACK, by tag, with nothing else's tag touched.
			expect(#Cursor.stats().tags).to.equal(cursorBefore)
			expect(#WeaponInput.holdTags()).to.equal(heldBefore)
			-- ...and the prompt still opens it again: closing is not disabling.
			prompt.fire()
			expect(RangePanel.isOpen()).to.equal(true)
		end)

		-- THE WAY IN IS ON HER SCREEN. A ProximityPrompt is drawn only while its own position is in
		-- view, so the prompt that hung on the mat was invisible down the lane and E did nothing
		-- (Director's proof, frames 03/04/06). The projection is `Range.viewportPointOf` -- the pinhole
		-- arithmetic `Camera:WorldToViewportPoint` performs -- asked about KAREN'S viewport, 969 x 792
		-- with a 58-pixel inset, and cross-checked against the engine on this machine's own camera.
		it("puts the prompt inside Karen's 969 x 792 viewport, above the hotbar, from the firing line", function()
			local KAREN_VIEWPORT = Vector2.new(969, 792)
			-- The bottom band the backpack hotbar occupies at that height, measured off frame
			-- 14-walk-crop.png (the row of gun slots runs from y ~= 735 to the bottom).
			local HOTBAR_BAND = 792 - 735
			local camera = workspace.CurrentCamera
			local row = RangeData.anchorFor("forest-test")
			expect(row).to.be.ok()
			local anchor = Vector3.new((row :: any).x, 0, (row :: any).z)
			local dir = RangeData.downrangeOf(row)
			local mat = RangeData.matPosition(anchor, 1, RangeData.LAYOUT)
			local promptAt = RangeData.promptPosition(anchor, 1, RangeData.LAYOUT, dir)
			local lane = RangeData.laneCentre(anchor, RangeData.LAYOUT, dir)
			-- A STANDING MAN'S EYE, and the claim is asserted over a BAND of eye heights rather than
			-- one number, so it is not knife-edge on a character rig's exact head offset.
			local rows = {}
			for _, eye in ipairs({ 4.0, 4.5, 5.0, 5.5, 6.0 }) do
				local from = mat + Vector3.new(0, eye, 0)
				local look = CFrame.lookAt(from, lane)
				local at, inFront = RangeData.viewportPointOf(look, promptAt, KAREN_VIEWPORT, camera.FieldOfView)
				expect(inFront).to.equal(true)
				expect(at.X > 0 and at.X < KAREN_VIEWPORT.X).to.equal(true)
				expect(at.Y > 0 and at.Y < KAREN_VIEWPORT.Y - HOTBAR_BAND).to.equal(true)
				table.insert(rows, string.format("eye %.1f -> (%.0f, %.0f)", eye, at.X, at.Y))
			end
			-- THE ARITHMETIC IS THE ENGINE'S, proved WITHOUT writing the camera (it has one owner):
			-- points are placed in the live camera's own frame and both projections must agree.
			for _, offset in ipairs({ Vector3.new(0, 0, -20), Vector3.new(3, -1, -7), Vector3.new(-6, 2, -40) }) do
				local point = camera.CFrame * offset
				local engine = camera:WorldToViewportPoint(point)
				local mine = RangeData.viewportPointOf(camera.CFrame, point, camera.ViewportSize, camera.FieldOfView)
				expect(math.abs(engine.X - mine.X) <= 1.5).to.equal(true)
				expect(math.abs(engine.Y - mine.Y) <= 1.5).to.equal(true)
			end
			local from = mat + Vector3.new(0, 5, 0)
			local look = CFrame.lookAt(from, lane)
			-- ...AND THE MAT IS NOT: the defect itself, as a case. The old prompt point (the mat's
			-- own top) falls below the hotbar band or off the bottom from the same eye.
			local matTop = mat + Vector3.new(0, RangeData.LAYOUT.MAT.size.Y / 2, 0)
			local floor = RangeData.viewportPointOf(look, matTop, KAREN_VIEWPORT, camera.FieldOfView)
			expect(floor.Y > KAREN_VIEWPORT.Y - HOTBAR_BAND).to.equal(true)
			TestKit.note(
				string.format(
					"range: prompt on screen at 969x792 -- %s · the mat's own point was at y %.0f (hotbar from %d)",
					table.concat(rows, ", "),
					floor.Y,
					792 - HOTBAR_BAND
				)
			)
		end)

		it("gives both doors back when he walks off the spot", function()
			local _, frame = freshPanel()
			local prompt = fakePrompt()
			RangePanel.setPrompt(prompt)
			local cursorBefore = #Cursor.stats().tags
			local heldBefore = #WeaponInput.holdTags()
			prompt.fire()
			expect(RangePanel.isOpen()).to.equal(true)
			expect(#Cursor.stats().tags).to.equal(cursorBefore + 1)
			expect(#WeaponInput.holdTags()).to.equal(heldBefore + 1)
			-- `setNear` ONLY EVER CLOSES (design 8.5), and it is what gives the two doors back:
			-- without its caller the cursor stayed free and the trigger held for ever (round 1,
			-- finding 3; the case itself was missing in round 2, finding 3).
			RangePanel.setNear(true)
			expect(RangePanel.isOpen()).to.equal(true)
			RangePanel.setNear(false)
			expect(RangePanel.isOpen()).to.equal(false)
			expect(frame.Visible).to.equal(false)
			expect(#Cursor.stats().tags).to.equal(cursorBefore)
			expect(#WeaponInput.holdTags()).to.equal(heldBefore)
			-- ...AND WALKING BACK ON OPENS NOTHING: the prompt is the one way in.
			RangePanel.setNear(true)
			expect(RangePanel.isOpen()).to.equal(false)
		end)

		-- TASK 308 BUG 2. MEASURED in Karen's place on 46cbd787: standing 1.90 studs from the
		-- prompt, `Enabled=true`, `MaxActivationDistance=12`, turning the camera off the post fired
		-- `PromptHidden` and four real `E` presses produced `trig=0` -- the keys arrived
		-- (`InputBegan` counted them, `gameProcessed=false`) and the engine answered none, because a
		-- hidden prompt does not answer its key. So the panel binds `E` itself while he is there.
		it("holds its own E while he is at the spot, and one press toggles once", function()
			local _, frame = freshPanel()
			-- THE ENGINE'S OWN BOOKKEEPING AND NOT THIS MODULE'S FLAG (round 1, finding 4):
			-- `hasKey` would still read true with the `BindAction` call deleted, and E in Karen's
			-- place would answer nothing -- which is the bug. `input_driving.spec`'s own check.
			local function bound()
				return ContextActionService:GetAllBoundActionInfo()[RangePanel.KEY_ACTION]
			end
			expect(bound()).to.equal(nil)
			expect(RangePanel.hasKey()).to.equal(false)
			RangePanel.setNear(true)
			expect(bound()).to.be.ok()
			expect(RangePanel.hasKey()).to.equal(true)

			-- THE KEY OPENS IT WITH NO PROMPT AT ALL: there is none set in this case, which is
			-- exactly the state a hidden prompt leaves the player in.
			expect(RangePanel.hasPrompt()).to.equal(false)
			RangePanel.onKeyPressed()
			expect(RangePanel.isOpen()).to.equal(true)
			expect(frame.Visible).to.equal(true)

			-- ...AND ONE PRESS CANNOT TOGGLE TWICE. While the engine IS showing the prompt it
			-- answers the keystroke itself, so the binding stands down.
			RangePanel.onKeyPressed()
			expect(RangePanel.isOpen()).to.equal(false)
			RangePanel.setPromptShown(true)
			local swallowedBefore = RangePanel.stats().swallowed
			RangePanel.onKeyPressed()
			expect(RangePanel.isOpen()).to.equal(false)
			expect(RangePanel.stats().swallowed).to.equal(swallowedBefore + 1)
			-- ...and the prompt's own trigger is what opens it in that state.
			RangePanel.onPromptTriggered()
			expect(RangePanel.isOpen()).to.equal(true)
			RangePanel.onPromptTriggered()
			expect(RangePanel.isOpen()).to.equal(false)
			RangePanel.setPromptShown(false)

			-- ...AND IT STANDS DOWN FOR THE **CLIMB** PROMPT TOO (task 306 step B10). That one is on
			-- `E` as well, at the ladder's foot -- and the station's own RANGE prompt is 11.95 studs
			-- from a man standing there, inside its reach of 12 -- so without this one press would
			-- climb AND open the menu.
			expect(RangePanel.isClimbShown()).to.equal(false)
			RangePanel.setClimbShown(true)
			expect(RangePanel.isClimbShown()).to.equal(true)
			local beforeClimb = RangePanel.stats().swallowed
			RangePanel.onKeyPressed()
			expect(RangePanel.isOpen()).to.equal(false)
			expect(RangePanel.stats().swallowed).to.equal(beforeClimb + 1)
			-- ...and the OTHER arm: with it clear, the same press opens the menu again.
			RangePanel.setClimbShown(false)
			RangePanel.onKeyPressed()
			expect(RangePanel.isOpen()).to.equal(true)
			RangePanel.onKeyPressed()
			expect(RangePanel.isOpen()).to.equal(false)
			-- WHICH PROMPTS COUNT AS A CLIMB, by NAME and nothing else: a station's climb prompts do
			-- and its menu prompt does not, so the stand-down cannot swallow E at the bench.
			local climbUp = Instance.new("ProximityPrompt")
			climbUp.Name = RangeData.climbPromptName(2, "up")
			expect(RangePanel.isClimbPrompt(climbUp)).to.equal(true)
			local climbDown = Instance.new("ProximityPrompt")
			climbDown.Name = RangeData.climbPromptName(5, "down")
			expect(RangePanel.isClimbPrompt(climbDown)).to.equal(true)
			local menu = Instance.new("ProximityPrompt")
			menu.Name = RangeData.promptName(2, RangeData.POSITION.BENCH)
			expect(RangePanel.isClimbPrompt(menu)).to.equal(false)
			expect(RangePanel.isClimbPrompt(nil)).to.equal(false)
			-- AND THE WATCH STANDS DOWN WITH THE PANEL: a climb prompt destroyed while shown fires no
			-- `PromptHidden`, so a `climbShown` left true would swallow E for the rest of the session.
			RangePanel.setClimbShown(true)
			RangePanel.unwatchClimbPrompts()
			expect(RangePanel.isClimbShown()).to.equal(false)
			local afterUnwatch = RangePanel.stats().swallowed
			RangePanel.onKeyPressed()
			expect(RangePanel.isOpen()).to.equal(true)
			expect(RangePanel.stats().swallowed).to.equal(afterUnwatch)
			RangePanel.onKeyPressed()
			expect(RangePanel.isOpen()).to.equal(false)

			-- THE KEY GOES WITH HIM: off the spot it is unbound, so nothing answers E in the wood.
			RangePanel.setNear(false)
			expect(bound()).to.equal(nil)
			expect(RangePanel.hasKey()).to.equal(false)
			expect(RangePanel.isOpen()).to.equal(false)
			RangePanel.setNear(true)
			RangePanel.setEnabled(false)
			expect(bound()).to.equal(nil)
			-- ...AND IT COMES BACK, or an enabled cycle at the post leaves E dead.
			RangePanel.setEnabled(true)
			expect(bound()).to.be.ok()
			-- `start` owns nothing: the key goes with the old session.
			freshPanel()
			expect(bound()).to.equal(nil)
			RangePanel.setNear(false)
		end)

		it("clears the kind when the animal changes, so a stale word cannot ride along", function()
			local sent = freshPanel()
			RangePanel.setState({ lists = lists() })
			RangePanel.select("kind", "male")
			expect(RangePanel.selected("kind")).to.equal("male")
			-- ROUND 2, FINDING 1: the KIND row still shows the boar's words when the animal changes,
			-- so without this the refused pair was sent on every CONFIRM for ever.
			RangePanel.select("species", "reddeer")
			expect(RangePanel.selected("kind")).to.equal(nil)
			expect(RangePanel.confirm()).to.equal(true)
			expect(sent[1].species).to.equal("reddeer")
			expect(sent[1].kind).to.equal(nil)
		end)

		it("offers exactly the seven pace words, STAND first and ISSF's three last", function()
			local _, frame = freshPanel()
			RangePanel.setState({ lists = lists() })
			local values = RangePanel.valuesFor("pace")
			expect(#values).to.equal(7)
			local seen = {}
			for _, entry in ipairs(values) do
				seen[entry.value] = true
			end
			-- KAREN, 2026-10-27: *"walk trot stand run"*. Asserted against `Range.WORD`, the shipped
			-- table the words cross the wire as, not against strings typed here.
			expect(seen[RangeData.WORD.STAND]).to.equal(true)
			expect(seen[RangeData.WORD.WALK]).to.equal(true)
			expect(seen[RangeData.WORD.TROT]).to.equal(true)
			expect(seen[RangeData.WORD.RUN]).to.equal(true)
			-- ...AND B4's THREE, in the order the menu shows them (design 6).
			expect(seen[RangeData.WORD.SLOW]).to.equal(true)
			expect(seen[RangeData.WORD.FAST]).to.equal(true)
			expect(seen[RangeData.WORD.MIXED]).to.equal(true)
			expect(values[5].value).to.equal(RangeData.WORD.SLOW)
			expect(values[7].value).to.equal(RangeData.WORD.MIXED)
			-- EVERY BUTTON IS ON THE PANEL. Seven at the shipped 94 px pitch would end 238 px off
			-- the right edge of a 416 px strip, so the pitch is derived from the count. Measured
			-- off the REAL buttons, which is what a player can click.
			local strip = frame:FindFirstChild("pace") :: Frame
			expect(strip).to.be.ok()
			local widest = 0
			for index = 1, #values do
				local at, size = RangePanel.rowRect("pace", index)
				expect(at).to.be.ok()
				widest = math.max(widest, ((at :: Vector2).X - strip.AbsolutePosition.X) + (size :: Vector2).X)
			end
			expect(widest <= RangePanel.STRIP_WIDTH).to.equal(true)
			TestKit.note(
				string.format(
					"range menu: 7 pace buttons span %.0f px of a %d px strip",
					widest,
					RangePanel.STRIP_WIDTH
				)
			)
		end)

		-- THE PITCH ITSELF, AS ARITHMETIC, so both arms are entered by their own case: the shipped
		-- 94 while it fits (every row that is four values or fewer is bit-for-bit today's), and the
		-- strip divided by the count once it does not.
		it("keeps the shipped 94 px pitch while it fits and shrinks it only when it cannot", function()
			local pitch, width = RangePanel.buttonLayout(4)
			expect(pitch).to.equal(94)
			expect(width).to.equal(90)
			expect(select(1, RangePanel.buttonLayout(1))).to.equal(94)
			-- 416 / 7 = 59.4 -> 59, and 7 x 59 = 413 <= 416.
			local sevenPitch, sevenWidth = RangePanel.buttonLayout(7)
			expect(sevenPitch).to.equal(math.floor(RangePanel.STRIP_WIDTH / 7))
			expect(sevenPitch * 7 <= RangePanel.STRIP_WIDTH).to.equal(true)
			expect(sevenWidth).to.equal(sevenPitch - RangePanel.BUTTON_GAP)
			-- The count where it turns over is the last one that fits at 94.
			expect(select(1, RangePanel.buttonLayout(math.floor(RangePanel.STRIP_WIDTH / 94)))).to.equal(94)
			expect(select(1, RangePanel.buttonLayout(math.floor(RangePanel.STRIP_WIDTH / 94) + 1)) < 94).to.equal(true)
			-- A nonsense count cannot divide by zero or hand back a negative width.
			expect(select(2, RangePanel.buttonLayout(0)) > 0).to.equal(true)
			expect(select(2, RangePanel.buttonLayout(400)) > 0).to.equal(true)
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

		-- THE MUST-FIX OF 306b NOTE (i) (step B6): the two senders carried the literal `spot = 1`,
		-- so all six menus named station 1. The station is TOLD by `Hud.step`, which is the one
		-- evaluation that already resolves which of the twelve prompts he is standing at.
		it("carries the station it was TOLD, in both senders, and defaults to 1", function()
			local sent = freshPanel()
			RangePanel.setState({ lists = lists() })
			expect((RangePanel.stationOf())).to.equal(1)
			RangePanel.setStation(5, RangeData.POSITION.TREESTAND)
			local spot, position = RangePanel.stationOf()
			expect(spot).to.equal(5)
			expect(position).to.equal(RangeData.POSITION.TREESTAND)
			expect(RangePanel.confirm()).to.equal(true)
			expect(sent[1].spot).to.equal(5)
			expect(RangePanel.reset()).to.equal(true)
			expect(sent[2].spot).to.equal(5)
			expect(sent[2].reset).to.equal(true)
			-- TOLD NOTHING IS STATION 1, which is the one-station answer this file shipped with.
			RangePanel.setStation(nil, nil)
			expect((RangePanel.stationOf())).to.equal(1)
			expect(RangePanel.confirm()).to.equal(true)
			expect(sent[3].spot).to.equal(1)
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

		-- THE CARTRIDGE THE TRIAL REALLY HAS, not the wire word. The proof's board read
		-- "BOAR male at rifle / Slug" with .416 picked and the ammo chip reading .416 (frame
		-- 14-walk-crop.png): both guns send "Slug" because `Boar.Wound.damageFor` branches on it.
		it("prints the gun's OWN cartridge label, which is not the wire word", function()
			local frame = Instance.new("Frame")
			RangeBoard.start(frame, { send = function() end })
			for _, id in ipairs(Weapons.ORDER) do
				local gun = Weapons.row(id)
				for _, kind in ipairs(gun.AMMO_KINDS) do
					RangeBoard.setRecord(record({ weapon = id, ammo = kind }))
					local text = table.concat(RangeBoard.rowText(), "\n")
					local wanted = gun.AMMO_LABEL[kind]
					expect(type(wanted)).to.equal("string")
					expect(string.find(text, wanted, 1, true) ~= nil).to.equal(true)
					-- The wire word itself is NOT what the last line says, unless the row's own
					-- label happens to be that word.
					if wanted ~= kind then
						expect(string.find(text, "/ " .. kind, 1, true)).to.equal(nil)
					end
				end
			end
			-- KAREN'S OWN CASE: the rifle with .416 chosen.
			RangeBoard.setRecord(record({ weapon = "rifle", ammo = "Slug", kind = "male" }))
			local line = RangeBoard.rowText()[8]
			expect(string.find(line, Weapons.row("rifle").AMMO_LABEL.Slug, 1, true) ~= nil).to.equal(true)
			TestKit.note("range board: last line -- " .. line)
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

		it("leaves the screen when he walks off the spot", function()
			local frame = Instance.new("Frame")
			RangeBoard.start(frame, { send = function() end })
			RangeBoard.setMenuOpen(true)
			RangeBoard.setRecord(record({}))
			expect(RangeBoard.isVisible()).to.equal(true)
			-- WALKING OFF DROPS THE COPY (round 1, finding 3) AND CLOSES THE MENU, which is what
			-- takes the board off the screen since task 304: `RangePanel.setNear(false)` closes the
			-- panel and `Hud.step` tells this module what the panel says.
			RangeBoard.setNear(false)
			expect(RangeBoard.lastRecord()).to.equal(nil)
			RangeBoard.setMenuOpen(false)
			expect(RangeBoard.isVisible()).to.equal(false)
			-- THE NEXT PUSH BRINGS THE RECORD BACK, and the board with the menu.
			RangeBoard.setRecord(record({}))
			expect(RangeBoard.isVisible()).to.equal(false)
			RangeBoard.setMenuOpen(true)
			expect(RangeBoard.isVisible()).to.equal(true)
			RangeBoard.stop()
		end)

		-- ---------------------------------------------------------------- TASK 304, KAREN'S CASE
		--
		-- KAREN, 2026-10-28, playing the range with the board over the left third of her view:
		-- *"if you remove this shit will be good I will see where I hit"*. The frame is the one the
		-- RUNNING Hud built (`Hud.rangeBoard()`), so this is her screen and not a frame this file made.
		it(
			"puts NOTHING of the board on screen while the menu is shut, and the numbers in it when it is open",
			function()
				local board = LiveHud.rangeBoard()
				local menu = LiveHud.rangePanel()
				expect(board).to.be.ok()
				expect(menu).to.be.ok()
				expect((board :: Frame):IsDescendantOf((livePlayer :: any).PlayerGui)).to.equal(true)
				-- AS THE HUD LEFT IT: hidden, before anything is told.
				expect((board :: Frame).Visible).to.equal(false)

				-- THE REAL PATH: the Hud hands this module that frame, the server pushes a record, and
				-- `Hud.step` tells it what `RangePanel.isOpen()` says.
				LiveBoard.setRecord(record({}))
				LiveBoard.setMenuOpen(false)
				expect((board :: Frame).Visible).to.equal(false)
				-- ...AND NOT ONE LABEL OF IT EITHER: a hidden frame hides its children, and the frame is
				-- the only thing this module draws into.
				local labels = 0
				for _, node in ipairs((board :: Frame):GetDescendants()) do
					if node:IsA("TextLabel") or node:IsA("TextButton") then
						labels += 1
						expect((node :: any):IsDescendantOf(board :: Frame)).to.equal(true)
					end
				end
				expect(labels >= 9).to.equal(true)

				-- SHE PRESSES E: the numbers are there, in the frame's own labels.
				LiveBoard.setMenuOpen(true)
				expect((board :: Frame).Visible).to.equal(true)
				local shown = {}
				for _, node in ipairs((board :: Frame):GetChildren()) do
					if node:IsA("TextLabel") then
						table.insert(shown, (node :: TextLabel).Text)
					end
				end
				local text = table.concat(shown, " | ")
				expect(string.find(text, "SHOTS 3", 1, true) ~= nil).to.equal(true)
				expect(string.find(text, "CHEST 1", 1, true) ~= nil).to.equal(true)
				expect(string.find(text, "LEAD BALLISTIC", 1, true) ~= nil).to.equal(true)
				expect(string.find(text, "MISS GAP", 1, true) ~= nil).to.equal(true)
				-- PUT KAREN'S OWN SCREEN BACK. `Hud.step` would do it on the next frame anyway
				-- (it tells a shut menu and an off-the-spot `setNear`); this does not leave it to luck.
				LiveBoard.setMenuOpen(false)
				LiveBoard.setNear(false)
				expect((board :: Frame).Visible).to.equal(false)
			end
		)

		it("sits INSIDE the menu's own rectangle, so it is a page of the menu and not a panel over the lane", function()
			local board = LiveHud.rangeBoard()
			local menu = LiveHud.rangePanel()
			expect(board).to.be.ok()
			expect(menu).to.be.ok()
			-- BOTH ARE ANCHORED TO THE SCREEN CENTRE, so the containment is arithmetic on the
			-- offsets and holds at EVERY viewport -- which is the only way to answer for a phone
			-- (`hud_clarity.spec`'s own stated reason: no tool here can resize a Studio viewport).
			expect((board :: Frame).Position.X.Scale).to.equal(0.5)
			expect((board :: Frame).Position.Y.Scale).to.equal(0.5)
			expect((menu :: Frame).Position.X.Scale).to.equal(0.5)
			expect((menu :: Frame).Position.Y.Scale).to.equal(0.5)
			expect((board :: Frame).AnchorPoint).to.equal(Vector2.new(0, 0))
			expect((menu :: Frame).AnchorPoint).to.equal(Vector2.new(0.5, 0.5))
			local left = (board :: Frame).Position.X.Offset
			local top = (board :: Frame).Position.Y.Offset
			local right = left + (board :: Frame).Size.X.Offset
			local bottom = top + (board :: Frame).Size.Y.Offset
			local halfW = (menu :: Frame).Size.X.Offset / 2
			local halfH = (menu :: Frame).Size.Y.Offset / 2
			expect(left >= -halfW).to.equal(true)
			expect(right <= halfW).to.equal(true)
			expect(top >= -halfH).to.equal(true)
			expect(bottom <= halfH).to.equal(true)
			-- ...AND BELOW THE HINT, so it covers no row and not the CONFIRM bar: the bar is centred
			-- on the panel with `CONFIRM_HEIGHT`, and the hint sits under it.
			expect(top > RangePanel.LOOK.CONFIRM_HEIGHT / 2 + 48).to.equal(true)
			-- ABOVE THE MENU'S OWN CHILDREN, or it would be invisible behind the panel
			-- (`ZIndexBehavior.Sibling` compares a child's ZIndex globally).
			expect((board :: Frame).ZIndex > (menu :: Frame).ZIndex + 2).to.equal(true)
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

-- hitlog.spec: THE RECORD OF WHO HIT WHAT, WHERE, AND WHETHER IT DIED. Pure-ish: one fake boar part
-- and hand-written reports, no weapon, no drive, no client.
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
--
-- IT EXISTS BECAUSE THE SERVER HALF OF TASK 124 SHIPPED WITH NO TEST AT ALL (round 2, the Reviewer's
-- second finding): a repo-wide grep for `recordHit`, `recordDown`, `openDrive`, `closeDrive` or
-- `hunterRows` over `tests/` returned one line, and that was `Shape` being required for geometry.
-- The join of the two signals -- a hit reported by the weapon, a death reported by the boar -- is
-- the whole of what the drive report draws, and it was unasserted.
--
-- THE JOIN IS THE CASE THAT MATTERS. Round 2 found the fatal dot pointing at the shooter's LAST hit
-- instead of the killing one, because the dot's clock and the wound's clock were two different
-- `os.clock()` samples: the X on Karen's silhouette, and the range printed beside it, were the wrong
-- shot's. These cases pin that down.
--
-- Design: docs/design/drive-report.md (sections 6.3 and 12). TASKS.md row 124.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HitLog = require(ServerScriptService:WaitForChild("HitLog"))
local Shape = require(ServerScriptService:WaitForChild("HitLog"):WaitForChild("Shape"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local function fakeBoar(id: string, kind: string?): BasePart
	local part = Instance.new("Part")
	part.Name = id
	part.Size = Vector3.new(2, 3, 5.5)
	part.CFrame = CFrame.new(0, 3, 0)
	part.Anchored = true
	if kind ~= nil then
		part:SetAttribute("Kind", kind)
	end
	return part
end

-- One hit, as `Weapon.Hits.group` reports it: the time is the SHOT's, and it travels with the report.
local function report(part: BasePart, userId: number, name: string, zone: string, at: number, extra)
	local row = {
		target = part,
		shooter = { UserId = userId, Name = name },
		zone = zone,
		position = part.Position + Vector3.new(0, 0.4, 1),
		nearest = (extra and extra.nearest) or 40,
		pellets = (extra and extra.pellets) or 3,
		-- WHICH GUN MADE IT (task 140): nil unless a case says otherwise, because nil on the wire is
		-- legal and means "a record from before the rifle" -- which is what every fixture here was.
		weapon = extra and extra.weapon,
		at = at,
	}
	return row
end

return function()
	-- THE WEAPON TRAVELS WITH THE SHOT (task 140). `Weapon.Hits.group` is the one constructor of a
	-- `HitReport` and puts the id on it; this file's claim is that `HitLog` COPIES it, exactly as it
	-- copies the zone, and derives nothing -- so the drive report can name the gun and a record
	-- written before the rifle existed is still legal.
	describe("the weapon on the record", function()
		it("copies the shot's weapon onto the dot, and nil is legal", function()
			local part = fakeBoar("Boar1", "male")
			HitLog.openDrive(1, 0)
			HitLog.recordHit(report(part, 101, "Anna", "chest", 10.0, { weapon = "rifle" }))
			HitLog.recordHit(report(part, 101, "Anna", "rear", 11.0))
			local record = (HitLog.currentDrive() :: any).animals["Boar1"]
			expect(record).to.be.ok()
			expect(record.dots[1].weapon).to.equal("rifle")
			-- NIL IS A LEGAL VALUE ON THE WIRE and means "a record from before the rifle", which is
			-- what keeps every fixture written before task 140 valid.
			expect(record.dots[2].weapon).to.equal(nil)
			part:Destroy()
			HitLog.closeDrive(20)
		end)

		it("marks the FATAL dot with the gun of the shot that KILLED it", function()
			local part = fakeBoar("Boar2", "female")
			HitLog.openDrive(2, 0)
			-- Two guns on one animal: a shotgun hit in the rear first, then the rifle's chest shot,
			-- which is the mortal one. The row carries the FATAL dot's weapon, which is the shot
			-- whose zone and range the panel prints beside it -- and the fatal dot is the MORTAL
			-- wound rather than the last one that landed (task 124 round 2).
			HitLog.recordHit(report(part, 101, "Anna", "rear", 10.0, { weapon = "shotgun", nearest = 90 }))
			HitLog.recordHit(report(part, 101, "Anna", "chest", 12.0, { weapon = "rifle", nearest = 30 }))
			HitLog.recordDown({
				id = "Boar2",
				kind = "female",
				killedByUserId = 101,
				killedByName = "Anna",
				killingZone = "chest",
				killingDistance = 30,
				at = 12.0,
				instant = true,
				wounds = { { zone = "rear", at = 10.0 }, { zone = "chest", at = 12.0 } },
			}, 12.0)
			local record = (HitLog.currentDrive() :: any).animals["Boar2"]
			expect(record).to.be.ok()
			-- THE FATAL DOT IS THE RIFLE'S, which is the fact this case measures. The ROW that
			-- carries it onto the screen is built by `detailPayload`, which is local to the module
			-- and reachable only through `onRequest`'s remote, so the row's own copy of the weapon
			-- is not asserted here (the Reviewer's note, round 2: the old name claimed it was).
			-- What IS asserted of the screen half is `ReportPanel.detailRowText` in
			-- `tests/client/rifle_client.spec.luau`.
			local fatal = nil
			for _, dot in ipairs(record.dots) do
				if dot.fatal then
					fatal = dot
				end
			end
			expect(fatal).to.be.ok()
			expect(fatal.weapon).to.equal("rifle")
			expect(fatal.zone).to.equal("chest")
			part:Destroy()
			HitLog.closeDrive(20)
		end)
	end)

	describe("one drive's record", function()
		it("joins the death to the shot that caused it, not to the last one", function()
			HitLog.openDrive(1, 0)
			local part = fakeBoar("Boar1", "female")

			-- Two hunters, two hits, and the MORTAL one is the first: `Wound` latches it, because
			-- later pellets into a dying animal do not steal the kill.
			HitLog.recordHit(report(part, 101, "Anna", "chest", 10.0, { nearest = 35 }))
			HitLog.recordHit(report(part, 101, "Anna", "rear", 12.0, { nearest = 70 }))

			HitLog.recordDown({
				id = "Boar1",
				kind = "female",
				killedByUserId = 101,
				killingZone = "chest",
				at = 10.0, -- `Wound.killRecord`'s own clock: the MORTAL wound's
				instant = true,
				wounds = {
					{ zone = "chest", at = 10.0 },
					{ zone = "rear", at = 12.0 },
				},
			})

			local record = (HitLog.currentDrive() :: any).animals["Boar1"]
			expect(record).to.be.ok()
			expect(record.result).to.equal("down")
			expect(#record.dots).to.equal(2)
			-- THE X IS ON THE KILLING SHOT: the chest hit at 35 studs, not the rear hit at 70.
			expect(record.dots[1].fatal).to.equal(true)
			expect(record.dots[2].fatal).to.equal(false)
			expect(record.dots[1].zone).to.equal("chest")
			expect(record.dots[1].distance).to.equal(35)
			-- ...and the join really happened, rather than the shooter fallback picking by luck.
			expect(HitLog.stats().unmatchedFatal).to.equal(0)
			part:Destroy()
			HitLog.closeDrive(20)
		end)

		it("counts a death it cannot join, instead of inventing one", function()
			HitLog.openDrive(2, 100)
			local part = fakeBoar("Boar2", "male")
			local before = HitLog.stats().unmatchedFatal
			HitLog.recordHit(report(part, 101, "Anna", "chest", 110.0))
			-- A kill record whose mortal wound matches no dot at all: a different zone AND a
			-- different clock. The fallback marks the shooter's last dot so the report still draws
			-- something, and the miss is COUNTED -- which is the number design section 12 reads.
			HitLog.recordDown({
				id = "Boar2",
				kind = "male",
				killedByUserId = 101,
				killingZone = "head",
				at = 999.0,
				wounds = { { zone = "head", at = 999.0 } },
			})
			expect(HitLog.stats().unmatchedFatal).to.equal(before + 1)
			local record = (HitLog.currentDrive() :: any).animals["Boar2"]
			expect(record.dots[1].fatal).to.equal(true) -- drawn anyway, on the shooter's own hit
			part:Destroy()
			HitLog.closeDrive(120)
		end)

		it("counts a death with no record at all and changes nothing else", function()
			HitLog.openDrive(3, 200)
			local before = HitLog.stats().unmatchedDowns
			expect(HitLog.recordDown({ id = "GhostBoar", killedByUserId = 101, at = 201 })).to.equal(false)
			expect(HitLog.stats().unmatchedDowns).to.equal(before + 1)
			HitLog.closeDrive(220)
		end)

		it("refuses a hit that names no boar", function()
			HitLog.openDrive(4, 300)
			expect(HitLog.recordHit({ shooter = { UserId = 1, Name = "A" } })).to.equal(false)
			expect(HitLog.recordHit(nil)).to.equal(false)
			HitLog.closeDrive(320)
		end)
	end)

	describe("the hunters' rows", function()
		it("counts a hunter's kills and the ones he hit and lost", function()
			HitLog.openDrive(5, 400)
			local down = fakeBoar("Boar10", "female")
			local lost = fakeBoar("Boar11", "cub")
			HitLog.recordHit(report(down, 101, "Anna", "chest", 401.0))
			HitLog.recordHit(report(lost, 101, "Anna", "rear", 402.0))
			HitLog.recordDown({
				id = "Boar10",
				kind = "female",
				killedByUserId = 101,
				killingZone = "chest",
				at = 401.0,
				wounds = { { zone = "chest", at = 401.0 } },
			})
			-- `Boar11` is left wounded: the drive closes with it still on the books, which IS Karen's
			-- *"wounded-lost"* and needs no third signal.
			local drive = HitLog.currentDrive()
			HitLog.closeDrive(420)

			local rows = Shape.hunterRows(drive, Report.CONFIG.HUNTERS_LISTED or 8)
			expect(#rows).to.equal(1)
			expect(rows[1].name).to.equal("Anna")
			expect(rows[1].kills).to.equal(1)
			expect(rows[1].lost).to.equal(1)
			expect(rows[1].hits).to.equal(2)
			-- NO POINTS FIELD: Match owns the score and this record must not grow a second one.
			expect(rows[1].points).to.equal(nil)
			TestKit.note(
				string.format(
					"hitlog: one hunter, %d hit(s), %d kill(s), %d lost",
					rows[1].hits,
					rows[1].kills,
					rows[1].lost
				)
			)
			down:Destroy()
			lost:Destroy()
		end)

		it("opens and closes a drive once, and says so", function()
			HitLog.openDrive(9, 900)
			local drive = HitLog.currentDrive()
			expect(drive).to.be.ok()
			expect((drive :: any).number).to.equal(9)
			-- A SECOND OPEN CLOSES THE FIRST, which is the contract and the right one: the drive
			-- that was running is finished at that instant rather than left open for ever, and the
			-- new one starts clean. Two reports can never share a record.
			HitLog.openDrive(10, 905)
			expect((drive :: any).closedAt).to.equal(905)
			local second = HitLog.currentDrive()
			expect((second :: any).number).to.equal(10)
			expect((second :: any).animals["Boar1"]).to.equal(nil)
			drive = second
			HitLog.closeDrive(960)
			expect((drive :: any).closedAt).to.equal(960)
			-- ...and closing twice does not move the time it closed at.
			HitLog.closeDrive(970)
			expect((drive :: any).closedAt).to.equal(960)
		end)
	end)
end

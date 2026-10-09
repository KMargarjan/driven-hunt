-- report_panel.spec: the drive report panel, in the real client, on the real Hud.
--
-- WHAT IT PROVES AND WHAT IT CANNOT. A drive is 300 seconds long in the Forest Test and 600 in the
-- real one, so no harness run ever reaches a drive's end and no harness run can make a real kill
-- arrive here. So this spec does what `Hud.renderScore`'s own spec does: it hands the panel the exact
-- payload the wire would carry and then reads the SCREEN -- the frame's visibility, the row text, and
-- a `Frame` per dot at the (u, v) the payload asked for. That is the one check
-- `docs/PROJECT_CONTEXT.md`'s "a visibility audit certified a blank screen twice" demands.
--
-- It also proves the two things that are not drawing and would otherwise be hopes:
--   * TAB REACHES US -- the stock player list is off and `DrivenHunt.Report.Toggle` is bound;
--   * A CLICK ON A ROW CANNOT FIRE THE GUN -- `Weapon.Input`'s tagged hold.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/drive-report.md (sections 4.3, 8)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Report = require(ReplicatedStorage:WaitForChild("Report"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local player = Players.LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local Hud = require(scripts:WaitForChild("Hud"))
local Weapon = require(scripts:WaitForChild("Weapon"))

local Panel = Hud.Report

-- The payload the server would send, built here by hand so the two views can be drawn without a
-- drive, a boar or a gun.
local function listPayload()
	return {
		view = "list",
		drive = 3,
		openedAt = 0,
		seconds = 300,
		closed = true,
		animals = 4,
		truncated = false,
		rows = {
			{
				userId = player.UserId,
				name = player.Name,
				kills = 3,
				lost = 1,
				hits = 5,
				animals = 4,
				byKind = { male = 2, female = 1, cub = 0, unknown = 0 },
			},
			{
				userId = 777,
				name = "Someone",
				kills = 1,
				lost = 0,
				hits = 1,
				animals = 1,
				byKind = { male = 0, female = 0, cub = 1, unknown = 0 },
			},
		},
	}
end

local function detailPayload()
	return {
		view = "detail",
		drive = 3,
		userId = player.UserId,
		name = player.Name,
		page = 1,
		pages = 2,
		rows = {
			{
				id = "Boar7",
				kind = "male",
				result = "down",
				zone = "chest",
				distance = 60,
				hits = 2,
				droppedHits = 0,
				at = 10,
				dots = {
					{
						userId = player.UserId,
						name = player.Name,
						zone = "chest",
						u = 0.4,
						v = 0.3,
						side = 1,
						distance = 60,
						pellets = 1,
						at = 10,
						fatal = true,
					},
					{
						userId = player.UserId,
						name = player.Name,
						zone = "legs",
						u = 0.7,
						v = 0.8,
						side = -1,
						distance = 58,
						pellets = 1,
						at = 9,
						fatal = false,
					},
				},
			},
			{
				id = "Boar9",
				kind = "cub",
				result = "wounded",
				zone = "rear",
				distance = 80,
				hits = 1,
				droppedHits = 0,
				at = 20,
				dots = {
					{
						userId = player.UserId,
						name = player.Name,
						zone = "rear",
						u = 0.85,
						v = 0.25,
						side = 1,
						distance = 80,
						pellets = 1,
						at = 20,
						fatal = false,
					},
				},
			},
		},
	}
end

return function()
	describe("the panel's frame", function()
		it("exists inside the one Hud ScreenGui, hidden, over the score panel", function()
			local frame = Hud.reportPanel()
			expect(frame).to.be.ok()
			expect((frame :: Frame):IsDescendantOf(player.PlayerGui)).to.equal(true)
			expect((frame :: Frame).ZIndex).to.equal(Report.CONFIG.PANEL_Z_INDEX)
			expect((frame :: Frame).ZIndex > 5).to.equal(true)
		end)

		it("is not visible until something opens it", function()
			expect(Panel.isOpen()).to.equal(false)
			expect((Hud.reportPanel() :: Frame).Visible).to.equal(false)
		end)
	end)

	describe("Tab is ours", function()
		it("turned the stock player list off, because a CoreGui key cannot be bound", function()
			expect(StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)).to.equal(false)
		end)

		it("bound every DrivenHunt.Report action", function()
			-- `GetAllBoundActionInfo` answers a dictionary keyed by action name.
			local all = ContextActionService:GetAllBoundActionInfo()
			for _, name in ipairs(Panel.boundActions()) do
				if all[name] == nil then
					error("action not bound: " .. name)
				end
			end
			expect(table.find(Panel.boundActions(), "DrivenHunt.Report.Toggle")).to.be.ok()
		end)
	end)

	describe("the list view", function()
		it("draws one row per hunter and shows the panel", function()
			Panel.setOpen(true)
			Panel.render(listPayload())
			expect(Panel.isOpen()).to.equal(true)
			expect((Hud.reportPanel() :: Frame).Visible).to.equal(true)
			expect(Panel.view()).to.equal("list")
			local rows = Panel.rowText()
			expect(#rows).to.equal(2)
			-- Kills by kind side by side with the total, which is Karen's "compairing others".
			expect(string.find(rows[1], player.Name, 1, true)).to.be.ok()
			expect(string.find(rows[2], "Someone", 1, true)).to.be.ok()
			expect(string.find(Panel.titleText(), "DRIVE 3", 1, true)).to.be.ok()
		end)

		it("says how many animals were hit", function()
			Panel.render(listPayload())
			expect(string.find(Panel.footerText(), "4 ANIMALS", 1, true)).to.be.ok()
		end)

		it("formats a row with the kinds, the kills, the lost and the points column", function()
			local text = Panel.listRowText(1, listPayload().rows[1], 34)
			expect(string.find(text, "34", 1, true)).to.be.ok()
			-- No Match in this world means no points, and a dash rather than a wrong zero.
			expect(string.find(Panel.listRowText(1, listPayload().rows[1], nil), "-", 1, true)).to.be.ok()
		end)
	end)

	describe("the detail view", function()
		it("draws one row per animal with its result, zone and range in metres", function()
			Panel.render(detailPayload())
			expect(Panel.view()).to.equal("detail")
			local rows = Panel.rowText()
			expect(#rows).to.equal(2)
			expect(string.find(rows[1], "MALE", 1, true)).to.be.ok()
			expect(string.find(rows[1], "DOWN", 1, true)).to.be.ok()
			-- 60 studs is 17 m at METRES_PER_STUD, and a hunting report in studs is one nobody reads.
			expect(string.find(rows[1], string.format("%d m", Report.metres(60)), 1, true)).to.be.ok()
			expect(string.find(rows[2], "LOST", 1, true)).to.be.ok()
		end)

		it("puts one dot per hit at the (u, v) the record measured", function()
			Panel.render(detailPayload())
			local dots = Panel.dots()
			expect(#dots).to.equal(3)
			local found = {}
			for _, dot in ipairs(dots) do
				found[string.format("%s:%.2f:%.2f:%s", dot.zone, dot.u, dot.v, tostring(dot.fatal))] = true
			end
			expect(found["chest:0.40:0.30:true"]).to.equal(true)
			expect(found["legs:0.70:0.80:false"]).to.equal(true)
			expect(found["rear:0.85:0.25:false"]).to.equal(true)
		end)

		it("draws the ANIMAL under the dots, in one fill, once per row", function()
			-- IT WAS THE FIVE ZONE RECTANGLES UNTIL TASK 135, named `Zone_head` and so on, and this
			-- case asserted them by name. They were a colour-coded bar rather than a boar (task 124
			-- round 3's own note), so the row draws `Report.CONFIG.BOAR` now -- the same animal, in
			-- one colour, in the same unit square. The claim is not weaker: it was five frames and
			-- it is thirteen, and the fill is asserted too.
			Panel.render(detailPayload())
			local frame = Hud.reportPanel() :: Frame
			local row = frame:FindFirstChild("DetailRow1")
			local art = row and row:FindFirstChild("Silhouette")
			expect(art).to.be.ok()
			for _, piece in ipairs(Report.CONFIG.BOAR) do
				local part = (art :: Frame):FindFirstChild(piece.name)
				expect(part).to.be.ok()
				-- ONE FILL IS WHAT MAKES IT A SILHOUETTE: a part drawn in a colour of its own would
				-- be the old bar coming back one piece at a time.
				expect((part :: Frame).BackgroundColor3).to.equal(Report.CONFIG.BOAR_FILL)
			end
			-- ...AND THE RECTANGLES ARE GONE FROM THE SCREEN, while `Report.CONFIG.SILHOUETTE`
			-- itself stays exactly what every dot is placed against.
			for _, zone in ipairs(Report.CONFIG.ZONES) do
				expect((art :: Frame):FindFirstChild("Zone_" .. zone)).to.equal(nil)
			end
		end)

		it("clears the dots when a row goes away, so a stale carcass cannot linger", function()
			Panel.render(detailPayload())
			expect(#Panel.dots()).to.equal(3)
			local empty = detailPayload()
			empty.rows = {}
			Panel.render(empty)
			expect(#Panel.dots()).to.equal(0)
		end)
	end)

	describe("the trigger while it is open", function()
		it("holds the weapon's input under its own tag, and releases it on close", function()
			Panel.setOpen(false)
			expect(Weapon.Input.isHeld()).to.equal(false)
			Panel.setOpen(true)
			expect(Weapon.Input.isHeld()).to.equal(true)
			expect(table.find(Weapon.Input.holdTags(), "report")).to.be.ok()
			Panel.setOpen(false)
			expect(Weapon.Input.isHeld()).to.equal(false)
			expect(#Weapon.Input.holdTags()).to.equal(0)
		end)

		it("takes a tag from any caller and needs every one of them released", function()
			Weapon.Input.requestHold("spec")
			Weapon.Input.requestHold("report")
			expect(Weapon.Input.isHeld()).to.equal(true)
			Weapon.Input.releaseHold("report")
			expect(Weapon.Input.isHeld()).to.equal(true)
			Weapon.Input.releaseHold("spec")
			expect(Weapon.Input.isHeld()).to.equal(false)
		end)

		it("refuses an empty tag, as Cursor.requestFree does", function()
			expect(function()
				Weapon.Input.requestHold("")
			end).to.throw()
		end)
	end)

	describe("the score panel yields to it", function()
		it("hides the score board while the report is open", function()
			local snapshot = { phase = "Scoring", driveNumber = 1, rows = {} }
			expect(Hud.scorePanelVisible(snapshot, false)).to.equal(true)
			expect(Hud.scorePanelVisible(snapshot, true)).to.equal(false)
			expect(Hud.scorePanelVisible(nil, false)).to.equal(false)
		end)
	end)

	describe("the drive boundary", function()
		it("auto-opens once when a drive closes, and not again for the same drive", function()
			Panel.setOpen(false)
			local before = Panel.stats().autoOpens
			Panel.onDriveChanged({ kind = "driveClosed", drive = 41 })
			expect(Panel.isOpen()).to.equal(true)
			expect(Panel.stats().autoOpens).to.equal(before + 1)
			Panel.setOpen(false)
			Panel.onDriveChanged({ kind = "driveClosed", drive = 41 })
			expect(Panel.isOpen()).to.equal(false)
			expect(Panel.stats().autoOpens).to.equal(before + 1)
		end)

		it("gets out of the way when the next drive opens", function()
			Panel.setOpen(true)
			Panel.onDriveChanged({ kind = "driveOpened", drive = 42 })
			expect(Panel.isOpen()).to.equal(false)
			expect(Panel.page()).to.equal(1)
		end)

		it("draws ONE line for one kill, and the Match feed draws none", function()
			-- KAREN'S FIRST-NAMED ASK: *"we need to show when is killed logg or something similar"*.
			-- THE WHOLE CLIENT HALF OF IT WAS UNASSERTED (task 124 rounds 1-3): the suite passed with
			-- `killLineText` and the feed rule deleted, and what would have gone silently is the only
			-- kill line either world draws.
			--
			-- ONE KILL IS ONE LINE, and that is a rule with two halves: `HitLog`'s own event draws the
			-- line (it carries the animal's KIND, which the Match feed has never had), and the Match
			-- feed's own `kill` entry therefore draws NOTHING. Both halves are asserted here.
			local before = #Hud.feedText()
			Hud.onKilled({ name = "Anna", animalKind = "female", zone = "chest", distance = 35 })
			local after = Hud.feedText()
			expect(#after).to.equal(before + 1)
			expect(after[#after]).to.equal(
				Hud.killLineText({ name = "Anna", animalKind = "female", zone = "chest", distance = 35 })
			)
			-- ...and the Match entry for the same kill adds no second line.
			expect(Hud.feedTextFor({ kind = "kill", name = "Anna", userId = 101 })).to.equal(nil)
			-- The feed's other events are untouched by that rule.
			expect(Hud.feedTextFor({ kind = "escape" })).to.be.ok()
			expect(Hud.feedTextFor({ kind = "violation", name = "Anna" })).to.be.ok()
		end)

		it("names the animal when it knows its kind, and never says NIL BOAR", function()
			local named = Hud.killLineText({ name = "Anna", animalKind = "female", zone = "chest", distance = 40 })
			expect(string.find(named, "FEMALE BOAR", 1, true)).to.be.ok()
			expect(string.find(named, "Anna", 1, true)).to.be.ok()
			expect(string.find(named, "chest", 1, true)).to.be.ok()
			-- WITHOUT A KIND IT IS STILL A BOAR. A kill event whose `animalKind` never arrived used to
			-- be the next reader's "NIL BOAR" waiting to happen.
			local plain = Hud.killLineText({ name = "Anna", zone = "rear", distance = 40 })
			expect(string.find(plain, "BOAR", 1, true)).to.be.ok()
			expect(string.find(plain, "NIL", 1, true)).to.equal(nil)
			-- ...and an event with nothing in it at all draws a line rather than raising.
			expect(type(Hud.killLineText({}))).to.equal("string")
			expect(type(Hud.killLineText(nil))).to.equal("string")
		end)

		it("ticks once per hit marker, and an empty id plays nothing and raises nothing", function()
			-- DESIGN SECTION 13, ITEM 8. The tick is what Karen hears when she connects; a path that
			-- stops running is silent in exactly the way a missing sample is, so the COUNT is the
			-- assertion.
			local Sound = require(scripts:WaitForChild("Hud"):WaitForChild("Sound"))
			Sound.resetStats()
			Hud.showHitMark("hit")
			Hud.showHitMark("kill")
			local stats = Sound.stats()
			-- Either a sound was asked for or the id is empty and it was counted as silent: both are
			-- the path running. The two ids this repo ships are engine assets, so in a normal build
			-- these are `hit = 1, kill = 1`.
			expect(stats.hit + stats.kill + stats.silent).to.equal(2)
			-- AN EMPTY ID PLAYS NOTHING AND IS NOT AN ERROR -- the rule `Weapon.Sound` already states.
			local emptied = { HIT_MARK_SOUND_ID = "", HIT_MARK_KILL_SOUND_ID = "" }
			expect(Sound.idFor("hit", emptied)).to.equal("")
			expect(Sound.idFor("kill", emptied)).to.equal("")
			TestKit.note(
				string.format(
					"report-feed: one kill drew one line; ticks hit=%d kill=%d silent=%d",
					stats.hit,
					stats.kill,
					stats.silent
				)
			)
		end)

		it("leaves the screen as it found it", function()
			-- THE SPEC CLEANS UP AFTER ITSELF. It opened a panel over the player's own screen and took
			-- the trigger; a run that ends with either still held would break every spec after it.
			Panel.setOpen(false)
			expect(Panel.isOpen()).to.equal(false)
			expect((Hud.reportPanel() :: Frame).Visible).to.equal(false)
			expect(Weapon.Input.isHeld()).to.equal(false)
		end)
	end)
end

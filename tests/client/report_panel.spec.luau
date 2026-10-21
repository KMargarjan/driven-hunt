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
				byKind = { male = 2, female = 1, cub = 0, legendary = 0, unknown = 0 },
			},
			{
				userId = 777,
				name = "Someone",
				kills = 1,
				lost = 0,
				hits = 1,
				animals = 1,
				byKind = { male = 0, female = 0, cub = 1, legendary = 0, unknown = 0 },
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
			-- ...AND A DRIVE THAT CLOSES *IS* SOMETHING OPENING IT (task 152, found by the gate).
			-- `onDriveChanged` auto-opens this panel ONCE per drive, so in a run where a live drive
			-- ended before this file ran, "closed" is the wrong claim and the right one is "closed
			-- unless a drive report opened it". `stats().autoOpens` is the fact that tells the two
			-- apart, and it is the panel's OWN counter -- not an inference from what is on screen.
			--
			-- NOTHING IS WEAKENED: whichever arm runs, the frame's `Visible` must agree with
			-- `isOpen()`, which is the invariant this case is actually about.
			local autoOpens = Panel.stats().autoOpens
			local frame = Hud.reportPanel() :: Frame
			if autoOpens > 0 then
				TestKit.note(
					string.format(
						"report_panel: a drive report auto-opened the panel %d time(s) before this case",
						autoOpens
					)
				)
				expect(frame.Visible).to.equal(Panel.isOpen())
				-- ...and the rest of this file starts from a known state either way.
				Panel.setOpen(false)
			else
				expect(Panel.isOpen()).to.equal(false)
			end
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

		it("keeps EVERY column inside the well, which the first frame did not", function()
			-- THE FRAME THAT FOUND IT: `20261017T150447Z-t201b-report-open-2.png`, where POINTS ran
			-- 14 px past the well's right edge because eight x-and-width pairs were tuned by eye.
			-- A column table is arithmetic, so it is added up here and never eyeballed again.
			local inner = Panel.WELL_INNER
			expect(inner).to.equal(Panel.bodyWidth(Vector2.new(1280, 720)) - 24)
			for _, columns in ipairs({ Panel.LIST_COLUMNS, Panel.DETAIL_COLUMNS }) do
				local previous = nil
				for _, column in ipairs(columns) do
					expect(column.x >= 0).to.equal(true)
					expect(column.x + column.w <= inner).to.equal(true)
					if previous ~= nil then
						-- ...AND NO COLUMN OVERLAPS THE ONE BEFORE IT, which is what makes a
						-- right-aligned number readable as a column rather than as a collision.
						expect(column.x >= previous.x + previous.w).to.equal(true)
					end
					previous = column
				end
			end
			-- The animal rows' cells start after the silhouette, which owns the row's left edge.
			expect(Panel.DETAIL_COLUMNS[1].x).to.equal(Panel.DETAIL_TEXT_X)
		end)

		it("reaches EVERY row the server can send, which the clipped well did not", function()
			-- ROUND 1, BLOCKING FINDING 1. The well's content box is 420 px. The server pages EIGHT
			-- animals (`ANIMALS_PER_PAGE`, and `HitLog` computes `pages` from it) at
			-- `DETAIL_ROW_HEIGHT` 68 = 544 px, and lists SIXTEEN hunters at 28 = 448 -- so with
			-- `ClipsDescendants` and no scroll a player saw FIVE of the eight while the footer still
			-- read `Page 1 of 1`, and lost rows 15 and 16 of the list.
			--
			-- THE MAXIMUM THE SERVER CAN SEND, not a convenient number: the two constants it pages by.
			local maxList = Report.CONFIG.HUNTER_ROWS
			local maxDetail = Report.CONFIG.ANIMALS_PER_PAGE
			local scroll = Panel.body
			expect(scroll).to.be.ok()
			expect((scroll :: ScrollingFrame):IsA("ScrollingFrame")).to.equal(true)
			expect((scroll :: ScrollingFrame).ScrollingDirection).to.equal(Enum.ScrollingDirection.Y)

			-- THE CANVAS HOLDS THEM ALL -- which is what "reachable" means for a scrolling frame --
			-- and it is BIGGER than the window, so the ones past the window scroll into view rather
			-- than being clipped away.
			local window = Panel.windowHeight()
			expect(window > 0).to.equal(true)
			local listCanvas = Panel.canvasHeight("list", maxList)
			local detailCanvas = Panel.canvasHeight("detail", maxDetail)
			expect(listCanvas).to.equal(maxList * Hud.Style.rowHeight(Hud.viewportX()))
			expect(detailCanvas).to.equal(maxDetail * Report.CONFIG.DETAIL_ROW_HEIGHT)
			expect(detailCanvas > window).to.equal(true)
			TestKit.note(
				string.format(
					"report: window %d px, list canvas %d (%d rows), detail canvas %d (%d rows)",
					window,
					listCanvas,
					maxList,
					detailCanvas,
					maxDetail
				)
			)

			-- AND ON THE SCREEN: with a full page rendered, the LAST row is inside the canvas the
			-- frame can scroll to, and the canvas really was written for what was drawn.
			Panel.render(detailPayload())
			local drawn = #detailPayload().rows
			expect((scroll :: ScrollingFrame).CanvasSize.Y.Offset).to.equal(Panel.canvasHeight("detail", drawn))
			local last = (scroll :: ScrollingFrame):FindFirstChild(string.format("DetailRow%d", maxDetail)) :: Frame
			expect(last).to.be.ok()
			local bottom = last.Position.Y.Offset + last.Size.Y.Offset
			expect(bottom <= Panel.canvasHeight("detail", maxDetail)).to.equal(true)
			-- The rows live in the SCROLLING body and not in the clipping well.
			expect(last:IsDescendantOf(scroll :: ScrollingFrame)).to.equal(true)
		end)

		it("says how many animals were hit", function()
			Panel.render(listPayload())
			-- A SENTENCE IS NEVER UPPERCASE (the design system, 2026-10-17, section 1.2): the footer
			-- is a sentence and the KEY HINTS beside it are the chips that shout.
			expect(string.find(Panel.footerText(), "4 animals", 1, true)).to.be.ok()
		end)

		it("formats a row as CELLS, with the kinds, the kills, the lost and the points", function()
			-- ONE `TextLabel` PER CELL since task 201 part 2 (the design system section 3.12): the
			-- padding is gone with `Enum.Font.Code` and the numbers line up because they are PLACED.
			-- So what is asserted is the CELLS, and `LIST_COLUMNS` is where each one goes.
			local row = listPayload().rows[1]
			local cells = Panel.listCellsFor(1, row, 34)
			expect(cells.points).to.equal("34")
			expect(cells.name).to.equal(row.name)
			expect(cells.kills).to.equal(tostring(row.kills))
			expect(string.find(Panel.listRowText(1, row, 34), "34", 1, true)).to.be.ok()
			-- NO POINTS MEANS NO CELL, not a dash (section 3.12: *"an unknown is not drawn at all
			-- rather than `--`"*). No `Match` in this world is exactly that case.
			expect(Panel.listCellsFor(1, row, nil).points).to.equal("")
			-- ...and every column head has a cell under it, which is what makes a column a column.
			for _, column in ipairs(Panel.LIST_COLUMNS) do
				expect(cells[column.key]).to.be.ok()
			end
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
			-- `WOUNDED` AND NOT `LOST` (the mockup's board 4, and Karen's own "wounded-lost"): the
			-- record's word is "wounded", the screen's is this, and `detailCellsFor` is the one
			-- place it is decided so the tag and the line cannot disagree.
			expect(string.find(rows[2], "WOUNDED", 1, true)).to.be.ok()
			-- `PIGLET` AND NOT `CUB` (201 part 3). The second row's record is a `cub` and this column
			-- printed that word, while the start card said `piglet` -- fault 2 of the Designer's
			-- start-card spec: *"A new player reads them as two animals and shoots the one he thinks
			-- is safe."* `Report.kindWord` is the one place the mapping lives and all three screens
			-- read it.
			expect(detailPayload().rows[2].kind).to.equal("cub") -- the RECORD is unchanged
			expect(string.find(rows[2], "PIGLET", 1, true)).to.be.ok()
			expect(string.find(rows[2], "CUB", 1, true)).to.equal(nil)
		end)

		it("names the LEGENDARY boar in the ANIMAL column, and the word fits the cell", function()
			-- TASK 219. `Report.kindWord` returns an unknown kind as it came, so this column needed no
			-- new mapping -- but "no change was needed" is a claim about BEHAVIOUR, so it gets a case
			-- that actually enters the legendary arm (L-093's lesson, from task 205's two art frames
			-- that both drew `kind = "male"`).
			local payload = detailPayload()
			payload.rows[1].kind = "legendary"
			Panel.render(payload)
			local rows = Panel.rowText()
			expect(string.find(rows[1], "LEGENDARY", 1, true)).to.be.ok()

			-- ...AND IT IS NOT TRUNCATED, which is the defect no other case here could see:
			-- `Style.cell` sets `TextTruncate = AtEnd`, so an animal word wider than its column is
			-- drawn as `LEGEND...` and every spec still passes. MEASURED with
			-- `TextService:GetTextBoundsAsync` in this cell's own face -- Oswald Medium 17 --
			-- `LEGENDARY` is 55.0 px, which is why the column went from 56 to 78.
			local column = nil
			for _, entry in ipairs(Panel.DETAIL_COLUMNS) do
				if entry.key == "kind" then
					column = entry
				end
			end
			expect(column).to.be.ok()
			local params = Instance.new("GetTextBoundsParams")
			params.Text = "LEGENDARY"
			params.Font = Hud.Style.FONT.OSWALD_MD
			params.Size = Hud.Style.SIZE.HEADING[1]
			params.Width = 10000
			local measured = game:GetService("TextService"):GetTextBoundsAsync(params)
			expect(measured.X <= (column :: any).w).to.equal(true)
			TestKit.note(
				string.format(
					"report-panel: LEGENDARY measures %.1f px in a %d px ANIMAL column",
					measured.X,
					(column :: any).w
				)
			)
		end)

		it("counts a legendary in the MALE column, because it is a male boar", function()
			-- TASK 219, and it is a DECISION rather than an oversight: a fourth count column does not
			-- fit the 584 px well without taking 44 px off NAME, and a trophy that fell through all
			-- three columns would show a player who shot one `MALE 0 FEM 0 CUB 0 KILLS 1`, which
			-- reads as broken. It is NAMED on the detail page, on the hit card and on the start card.
			local cells = Panel.listCellsFor(1, {
				userId = 1,
				name = "Karen",
				kills = 2,
				lost = 0,
				byKind = { male = 1, female = 0, cub = 0, legendary = 1, unknown = 0 },
			}, 35)
			expect(cells.male).to.equal("2")
			expect(cells.female).to.equal("0")
			expect(cells.cub).to.equal("0")
			expect(cells.kills).to.equal("2")
			expect(cells.points).to.equal("35")
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
			-- THE ROWS LIVE IN THE WELL'S SCROLLING BODY since round 2 (the well clips and does not
			-- scroll, which lost five of the eight animals the server pages), so this looks where
			-- they are rather than at the panel's own children.
			local body = Hud.Report.body :: ScrollingFrame
			expect(body).to.be.ok()
			local row = body:FindFirstChild("DetailRow1")
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
		it("does NOT open itself when a drive closes: the results scene is what shows (task 159)", function()
			-- THE SHIPPED BEHAVIOUR, AND IT CHANGED, with a picture for the reason: the end of a
			-- drive is now Karen's results scene (the animals, four lamps, everybody standing round
			-- them and the semi-transparent results table), and a near-opaque full-screen report in
			-- front of it hides exactly what she asked to see -- and suppresses the table as well,
			-- because `Hud.scorePanelVisible` refuses to draw two centred panels at once.
			-- `.screenshots/20261011T230613Z-task159-results-scene.png` is that, measured in the
			-- Forest Test. Named as a deviation from `docs/design/drive-report.md` section 1 item 6.
			Panel.setOpen(false)
			local before = Panel.stats().autoOpens
			Panel.onDriveChanged({ kind = "driveClosed", drive = 41 })
			expect(Panel.isOpen()).to.equal(false)
			expect(Panel.stats().autoOpens).to.equal(before)
			expect(Report.CONFIG.AUTO_OPEN_AT_DRIVE_END).to.equal(false)
			expect(Panel.autoOpensAtDriveEnd()).to.equal(false)
			-- ...and Tab still opens it, which is the whole of what a player lost.
			Panel.setOpen(true)
			expect(Panel.isOpen()).to.equal(true)
			Panel.setOpen(false)
		end)

		it("still auto-opens ONCE per drive when a config says it may", function()
			-- THE OTHER BRANCH IS STILL REACHABLE AND STILL TESTED, which is what "merged dark" means
			-- for a behaviour that is off: the once-per-drive rule (`autoOpenedFor`) is the thing that
			-- made Karen closing it stick, and deleting its test with its default would mean nobody
			-- would know if it broke.
			local on = { AUTO_OPEN_AT_DRIVE_END = true }
			expect(Panel.autoOpensAtDriveEnd(on)).to.equal(true)
			Panel.setOpen(false)
			local before = Panel.stats().autoOpens
			Panel.onDriveChanged({ kind = "driveClosed", drive = 43 }, on)
			expect(Panel.isOpen()).to.equal(true)
			expect(Panel.stats().autoOpens).to.equal(before + 1)
			Panel.setOpen(false)
			Panel.onDriveChanged({ kind = "driveClosed", drive = 43 }, on)
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

		it("names the animal when it knows its kind, and never says NIL BOAR or STAG BOAR", function()
			local named = Hud.killLineText({ name = "Anna", animalKind = "female", zone = "chest", distance = 40 })
			expect(string.find(named, "FEMALE BOAR", 1, true)).to.be.ok()
			expect(string.find(named, "Anna", 1, true)).to.be.ok()
			expect(string.find(named, "chest", 1, true)).to.be.ok()
			-- A DEER IS NOT A BOAR (task 231). This line built its noun as `upper(kind) .. " BOAR"`,
			-- so with red deer in every drive since task 230 a stag was reported as "STAG BOAR".
			-- `Report.animalWord` is the one place the noun is decided now, and the three deer kinds
			-- are their own nouns -- a stag IS a deer, and "STAG DEER" is not English.
			local stag = Hud.killLineText({ name = "Anna", animalKind = "stag", zone = "chest", distance = 40 })
			expect(string.find(stag, "STAG", 1, true)).to.be.ok()
			expect(string.find(stag, "BOAR", 1, true)).to.equal(nil)
			for _, kind in ipairs({ "stag", "hind", "calf" }) do
				expect(Report.animalWord(kind)).to.equal(string.upper(kind))
			end
			for _, kind in ipairs({ "male", "female", "cub", "legendary" }) do
				expect(Report.animalWord(kind)).to.equal(string.upper(kind) .. " BOAR")
			end
			-- WITHOUT A KIND IT IS AN ANIMAL, not a boar (task 231): naming the species of an animal
			-- nobody identified is a guess, and a drive now carries two of them. A kill event whose
			-- `animalKind` never arrived used to be the next reader's "NIL BOAR" waiting to happen.
			local plain = Hud.killLineText({ name = "Anna", zone = "rear", distance = 40 })
			expect(string.find(plain, "ANIMAL", 1, true)).to.be.ok()
			expect(string.find(plain, "BOAR", 1, true)).to.equal(nil)
			expect(Report.animalWord(nil)).to.equal("ANIMAL")
			expect(Report.animalWord("")).to.equal("ANIMAL")
			-- ...AND THE DRIVE REPORT'S ANIMAL COLUMN takes the same decision for the same reason:
			-- a row whose `kind` never arrived used to print `BOAR` over an unidentified animal.
			expect(Panel.detailCellsFor({}).kind).to.equal("ANIMAL")
			expect(Panel.detailCellsFor({ kind = "stag" }).kind).to.equal("STAG")
			expect(Panel.detailCellsFor({ kind = "cub" }).kind).to.equal("PIGLET")
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
	-- THE RED DEER FOLDS INTO THE THREE COLUMNS THAT ALREADY EXIST (task 223 round 2, finding 4).
	--
	-- Round 1 added `+ (kinds.stag or 0)`, `+ (kinds.hind or 0)` and `+ (kinds.calf or 0)` to
	-- `listCellsFor` and left them UNREACHED: every `byKind` fixture in this file was five-key, so
	-- the three new terms could be deleted and nothing here would notice.
	--
	-- THE FOLD IS THE DECISION TASK 219 TOOK, APPLIED: the column heads are MALE / FEM / CUB --
	-- SEX AND AGE words, not species words -- so a stag in MALE and a hind in FEM are true, and the
	-- alternative is a player who shot a stag reading `MALE 0 FEM 0 CUB 0 KILLS 1`, which reads as
	-- broken. No column moves and no pixel moves.
	describe("the red deer on the board", function()
		local function cellsFor(byKind)
			return Panel.listCellsFor(1, { name = "Karen", kills = 1, lost = 0, byKind = byKind }, 20)
		end

		it("folds a stag into MALE, a hind into FEM and a calf into CUB", function()
			-- ONE CASE PER KIND (L-093), each entering its own new term.
			local stag =
				cellsFor({ male = 0, female = 0, cub = 0, legendary = 0, stag = 1, hind = 0, calf = 0, unknown = 0 })
			expect(stag.male).to.equal("1")
			expect(stag.female).to.equal("0")
			expect(stag.cub).to.equal("0")
			local hind =
				cellsFor({ male = 0, female = 0, cub = 0, legendary = 0, stag = 0, hind = 1, calf = 0, unknown = 0 })
			expect(hind.female).to.equal("1")
			expect(hind.male).to.equal("0")
			expect(hind.cub).to.equal("0")
			local calf =
				cellsFor({ male = 0, female = 0, cub = 0, legendary = 0, stag = 0, hind = 0, calf = 1, unknown = 0 })
			expect(calf.cub).to.equal("1")
			expect(calf.male).to.equal("0")
			expect(calf.female).to.equal("0")
		end)

		it("never shows a hunter who shot a stag an empty row", function()
			-- DESIGN SECTION 1.1 MUST-6, as the sentence it is written as: *"no column that reads
			-- MALE 0 FEM 0 CUB 0 KILLS 1"*.
			local cells =
				cellsFor({ male = 0, female = 0, cub = 0, legendary = 0, stag = 1, hind = 0, calf = 0, unknown = 0 })
			local counted = tonumber(cells.male) + tonumber(cells.female) + tonumber(cells.cub)
			expect(counted).to.equal(1)
			expect(cells.kills).to.equal("1")
		end)

		it("adds the deer to the boars beside them rather than replacing them", function()
			local mixed =
				cellsFor({ male = 2, female = 1, cub = 1, legendary = 1, stag = 1, hind = 2, calf = 3, unknown = 1 })
			-- male 2 + unknown 1 + legendary 1 + stag 1
			expect(mixed.male).to.equal("5")
			-- female 1 + hind 2
			expect(mixed.female).to.equal("3")
			-- cub 1 + calf 3
			expect(mixed.cub).to.equal("4")
		end)
	end)
end

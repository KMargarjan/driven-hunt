--!strict
-- Hud.HitCard: THE ONE WRITER of everything inside the `HitCard` frame (CLAUDE.md rule 3).
--
-- Karen, 2026-10-16, with a reference frame of somebody else's video: *"there is a black boar image
-- as you can see and red dot / so once we hit boar we can show where it has been hitted / red dot
-- will indicate so if shells then several of them / so somewhere in corner after hit we indicate
-- where it landed"*.
--
-- WHAT IT IS. One shot of YOURS lands on an animal; a small dark card appears in the lower left with
-- a solid black boar on a bone plate and a red dot wherever each pellet struck. It holds for
-- `CARD.HOLD_SECONDS` and fades. A miss draws nothing, a hit on anything that is not an animal draws
-- nothing, and somebody else's shot draws nothing -- the server sends the card to the shooter and to
-- nobody else (`HitLog.toShooter`).
--
-- IT DRAWS WHAT ARRIVED AND COMPUTES NOTHING, which is `ReportPanel`'s own rule and for the same
-- reason: every `(u, v, side)` on this card was measured on the SERVER at the instant of the shot by
-- `HitLog.Shape.dot`, the one projection in the game. The only arithmetic here is pixels, the fade,
-- and which way round the animal goes -- and that last one is `Report.cardFacing`, pure and shared.
--
-- THE ANIMAL IS `Hud.BoarArt`'s, NOT A SECOND DRAWING OF A BOAR. Two frames of it are built once at
-- startup, one nose-left and one nose-right, and a hit shows whichever flank was struck; Roblox GUI
-- has no transform, so a mirror is a second layout rather than a flip.
--
-- THE FRAME IS NOT ITS OWN. `Hud.build` creates `HitCard` with the rest of the screen -- one
-- ScreenGui, built once, so a visibility audit has one place to look.
--
-- Note: docs/research/2026-10-17-hit-card.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

local BoarArt = require(script.Parent.BoarArt)
local ShopPanel = require(script.Parent.ShopPanel)

local CONFIG = Report.CONFIG.CARD

local HitCard = {}

-- ---------------------------------------------------------------- state (one writer)
local started = false
local card: Frame? = nil
local plate: Frame? = nil
local label: TextLabel? = nil
local artNear: Frame? = nil -- nose-LEFT, the report's own facing
local artFar: Frame? = nil -- nose-RIGHT, for a hit that came in on the other flank
local shown: Frame? = nil -- which of the two is carrying the dots right now
-- The shot the card is showing, so a `hitFatal` that arrives a tick later can tell whether it is
-- about THIS card or about one that has already been replaced.
local showing: { animal: string, at: number }? = nil
local age = 0
local alive = false
local connection: RBXScriptConnection? = nil
-- The two wire connections, held so `stop` can undo exactly what `start` made: without them a
-- stop/start pair would connect `show` twice and draw every hit twice (the Reviewer's note,
-- round 1).
local wires: { RBXScriptConnection } = {}

local stats = { shows = 0, fatals = 0, replaced = 0, hides = 0 }

function HitCard.stats()
	return table.clone(stats)
end

function HitCard.frame(): Frame?
	return card
end

function HitCard.isVisible(): boolean
	return card ~= nil and card.Visible
end

function HitCard.labelText(): string
	return if label then label.Text else ""
end

-- Which way the animal is drawn right now: false is nose-LEFT, the report's facing.
function HitCard.mirrored(): boolean
	return shown ~= nil and shown == artFar
end

-- Every dot on the card, as `BoarArt` wrote them: the seam a spec reads instead of guessing, and the
-- same reader `ReportPanel.dots` uses -- so "the card and the report put the same hit in the same
-- place" is one comparison of two lists rather than two different ways of looking.
-- THE ART FRAME THAT IS ACTUALLY SHOWN -- nose-left or nose-right -- so a spec can read the drawn
-- picture and the drawn dots rather than the renderer's input (task 205).
function HitCard.art(): Frame?
	return shown
end

function HitCard.dots(): { { u: number, v: number, zone: string, fatal: boolean } }
	if shown == nil or not HitCard.isVisible() then
		return {}
	end
	return BoarArt.dotsOf(shown)
end

-- ---------------------------------------------------------------- the picture, built once

-- THE HOUSE STYLE'S OWN PALETTE AND FONTS, from the one file that holds them (`Hud.ShopPanel`'s
-- header says why: a second copy of a palette is a second answer to *"what colour is blaze
-- orange"*). The card's own colours -- the bone plate, the black animal, the red dot -- are in
-- `Report.CONFIG.CARD`, because they are the ones the shop has no opinion about.
local function build(frame: Frame)
	card = frame
	local Z = CONFIG.Z_INDEX

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, CONFIG.CORNER)
	round.Parent = frame

	-- ONE BRASS HAIRLINE (the Designer's spec, section 8.2). A card this small has no header to
	-- separate from a body, so its one rule is its edge -- which is also what keeps a dark box from
	-- vanishing into a dark wood.
	local edge = Instance.new("UIStroke")
	edge.Thickness = CONFIG.EDGE_THICKNESS
	edge.Color = CONFIG.EDGE_COLOR
	edge.Transparency = CONFIG.EDGE_TRANSPARENCY
	edge.Parent = frame

	-- THE LABEL: BuilderSans Bold, uppercase, letter-spaced at 10 px -- the house style's micro-label
	-- (spec 8.3), set with the same `spaced()` the shop uses because a `TextLabel` has no tracking.
	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.FontFace = ShopPanel.FONT.SANS_BOLD
	text.TextSize = CONFIG.LABEL_SIZE
	text.TextColor3 = CONFIG.LABEL_COLOR
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Position = UDim2.fromOffset(CONFIG.LABEL_X, CONFIG.LABEL_Y)
	text.Size = UDim2.fromOffset(CONFIG.WIDTH - 2 * CONFIG.LABEL_X, CONFIG.LABEL_SIZE + 6)
	text.Text = ""
	-- EVERY LABEL OF A PANEL SITS ABOVE THE PANEL'S OWN ZINDEX (`Hud.build`'s `panelLabel`, task
	-- 159): a label at the default 1 under a panel at 14 is text drawn behind its own background,
	-- which this repo has now paid for twice.
	text.ZIndex = Z + 1
	text.Parent = frame
	label = text

	-- THE PLATE THE ANIMAL IS PRINTED ON. Karen's reference is a SOLID BLACK boar, and black on
	-- `#1C1915` is not a picture of anything -- so the animal gets a pale ground of its own, the way
	-- a paper hit card has one. It is the one place this card leaves the dark surface ladder, and it
	-- is named here rather than argued about later.
	local ground = Instance.new("Frame")
	ground.Name = "Plate"
	ground.BackgroundColor3 = CONFIG.PLATE_COLOR
	ground.BackgroundTransparency = 0
	ground.BorderSizePixel = 0
	ground.Position = UDim2.fromOffset(CONFIG.ART_INSET_X, CONFIG.ART_TOP)
	ground.Size = UDim2.fromOffset(CONFIG.PLATE_WIDTH, CONFIG.PLATE_HEIGHT)
	ground.ZIndex = Z + 1
	ground.Parent = frame
	local groundCorner = Instance.new("UICorner")
	groundCorner.CornerRadius = UDim.new(0, CONFIG.PLATE_CORNER)
	groundCorner.Parent = ground
	plate = ground

	-- BOTH FACINGS, BUILT ONCE. The alternative is fourteen `Instance.new`s per shot, and a buckshot
	-- volley is a lot of shots; this costs twenty-eight frames for the session and a `Visible`.
	local function art(name: string, mirror: boolean): Frame
		local made = BoarArt.build(ground, name, UDim2.fromOffset(CONFIG.ART_PAD, CONFIG.ART_PAD), {
			fill = CONFIG.BOAR_FILL,
			-- THE PLATE IS THE GROUND AND THE ART HAS NONE OF ITS OWN: inset by `ART_PAD`, it is
			-- the plate that shows round the animal, so there is no second rectangle to line up.
			backing = CONFIG.PLATE_COLOR,
			backingTransparency = 1,
			mirror = mirror,
			width = CONFIG.ART_WIDTH,
			height = CONFIG.ART_HEIGHT,
			zIndex = Z + 2,
			-- KAREN'S OWN SILHOUETTE (task 205), and `male` only until a payload says otherwise:
			-- this frame is built before any shot is fired, and `HitCard.show` calls
			-- `BoarArt.setKind` with the record's own kind.
			kind = "male",
		})
		made.Visible = false
		return made
	end
	artNear = art("Art", false)
	artFar = art("ArtMirrored", true)

	frame.Visible = false
end

-- ---------------------------------------------------------------- showing one shot

local function hide()
	alive = false
	showing = nil
	if card ~= nil then
		card.Visible = false
	end
	if artNear ~= nil then
		artNear.Visible = false
		BoarArt.clearDots(artNear)
	end
	if artFar ~= nil then
		artFar.Visible = false
		BoarArt.clearDots(artFar)
	end
	shown = nil
end

-- THE WHOLE CARD AT ONE TRANSPARENCY, so the fade is one number and not six that can drift apart.
-- `UIStroke` and `TextLabel` do not inherit a parent's transparency, so each is set from the same
-- `fade` -- the thing a frame of the fade would otherwise show as a hairline still at full strength
-- around a card that has gone.
local function setFade(fade: number)
	local at = math.clamp(fade, 0, 1)
	if card == nil then
		return
	end
	card.BackgroundTransparency = CONFIG.PANEL_TRANSPARENCY + (1 - CONFIG.PANEL_TRANSPARENCY) * at
	local edge = card:FindFirstChildOfClass("UIStroke")
	if edge ~= nil then
		edge.Transparency = CONFIG.EDGE_TRANSPARENCY + (1 - CONFIG.EDGE_TRANSPARENCY) * at
	end
	if label ~= nil then
		label.TextTransparency = at
	end
	if plate ~= nil then
		plate.BackgroundTransparency = at
	end
	for _, art in ipairs({ artNear, artFar }) do
		if art ~= nil and art.Visible then
			-- THE ART FRAME'S OWN BACKING IS LEFT ALONE: `build` made it transparent on purpose (the
			-- plate is the ground), and writing `at` into it made it an opaque rectangle that only
			-- happened to match the plate's colour -- a seam waiting for the next palette change
			-- (the Reviewer's note, round 1).
			for _, child in ipairs(art:GetChildren()) do
				if child:IsA("Frame") then
					child.BackgroundTransparency = at
					local stroke = child:FindFirstChildOfClass("UIStroke")
					if stroke ~= nil then
						stroke.Transparency = at
					end
				end
			end
		end
	end
end

-- THE LABEL'S WORDS. The wire carries the weapon's id and the ammunition's key; the SCREEN carries
-- the words, which `Weapons.row(id).AMMO_LABEL` resolves -- the same split `WireDot.weapon` already
-- has, and the reason this is the only place a card knows what a gun is called.
function HitCard.textFor(payload: any): string
	local row = Weapons.row(payload and payload.weapon)
	local ammo = payload and payload.ammo
	local word = if row ~= nil and ammo ~= nil then row.AMMO_LABEL[ammo] else ammo
	return ShopPanel.spaced(Report.cardLabel(word, (payload and payload.hits) or 0, payload and payload.fired))
end

-- ONE SHOT, SHOWN NOW. **A SECOND HIT REPLACES THE FIRST** rather than stacking beside it, and that
-- is the whole reason: a buckshot volley into a sounder is two or three reports inside a quarter of
-- a second, and a stack would be three cards racing each other off the screen with the newest at the
-- bottom. Karen asked for *"where it landed"* -- singular, the shot you just took -- so the card is
-- always the LAST thing that happened, and the TAB report is where the whole drive is kept.
function HitCard.show(payload: any)
	if card == nil or type(payload) ~= "table" then
		return
	end
	if alive then
		stats.replaced += 1
	end
	local dots = if type(payload.dots) == "table" then payload.dots else {}
	-- MIRROR IF THE SHOT CAME IN ON THE FAR FLANK, so the dot is on the side that was hit
	-- (`Report.cardFacing`). The report fades a far-side dot instead, because its rows have to be
	-- the same way round to compare; one card of one animal does not.
	local mirror = Report.cardFacing(dots)
	local art = if mirror then artFar else artNear
	if art == nil then
		return
	end
	if artNear ~= nil then
		artNear.Visible = art == artNear
		if art ~= artNear then
			BoarArt.clearDots(artNear)
		end
	end
	if artFar ~= nil then
		artFar.Visible = art == artFar
		if art ~= artFar then
			BoarArt.clearDots(artFar)
		end
	end
	shown = art
	-- WHICH ANIMAL THIS SHOT WAS (task 205). The record carries the kind and `Report.boarImage` is
	-- the one place it becomes a picture, so the card and the drive report cannot show two
	-- different animals for one hit. It is set HERE and not at build time: the two art frames are
	-- built before any shot is fired.
	-- `animalKind` AND NOT `kind`: the payload's own `kind` is the MESSAGE's ("hit"), and the
	-- animal's is beside it. One wrong field here would draw a boar for every sow.
	BoarArt.setKind(art, payload and payload.animalKind, mirror)
	BoarArt.drawDots(art, dots, {
		fill = CONFIG.BOAR_FILL,
		width = CONFIG.ART_WIDTH,
		height = CONFIG.ART_HEIGHT,
		zIndex = CONFIG.Z_INDEX + 2,
		mirror = mirror,
		pixels = CONFIG.DOT_PIXELS,
		dot = CONFIG.DOT_COLOR,
		ring = CONFIG.RING_COLOR,
		ringThickness = CONFIG.RING_THICKNESS,
		-- Not faded: the picture was turned round instead, so every dot on it is on the flank you
		-- are looking at.
		fadeFarSide = false,
	});
	(label :: TextLabel).Text = HitCard.textFor(payload)
	showing = { animal = tostring(payload.animal or ""), at = (payload.at :: number?) or 0 }
	age = 0
	alive = true
	card.Visible = true
	setFade(0)
	stats.shows += 1
end

-- THE KILL, WHICH ARRIVES AFTER THE CARD (task 198). The animal goes down on the Brain's NEXT tick,
-- so the card was drawn before anybody knew the shot was fatal; `HitLog` sends the mark on after it,
-- naming the animal and the shot's own clock. Only the dot the drive report marks is marked here --
-- the `lead` one, which is the nearest impact and the one pellet the report draws -- so a glance at
-- the card and a glance at the TAB row say the same thing about which shot killed.
function HitCard.markFatal(event: any)
	if not alive or showing == nil or shown == nil or type(event) ~= "table" then
		return
	end
	if tostring(event.animal or "") ~= showing.animal then
		return
	end
	-- The shot's own clock, to a looser tolerance than `Shape.fatalDot`'s 1e-6: this number has been
	-- through a RemoteEvent and back, and a card marked for the wrong shot of the same animal within
	-- a millisecond is not a thing that can happen at a rate of fire of one shell a second.
	if math.abs(((event.at :: number?) or 0) - showing.at) > 1e-3 then
		return
	end
	local lead = nil
	for _, child in ipairs(shown:GetChildren()) do
		if child:IsA("Frame") and child.Name == "Dot" and child:GetAttribute("Lead") == true then
			lead = child
		end
	end
	if lead == nil then
		return
	end
	lead:SetAttribute("Fatal", true)
	-- THE REPORT'S OWN KILL COLOUR, which is what claim 9 said and what the code did not do: this
	-- line wrote `DOT_COLOR`, the colour `drawDots` had already painted it (the Reviewer's note,
	-- round 1), so the fatal mark differed by shape alone.
	lead.BackgroundColor3 = Shotgun.CONFIG.HIT_MARK_KILL_COLOR
	lead.Rotation = 45
	lead.Size = UDim2.fromOffset(CONFIG.DOT_PIXELS + 3, CONFIG.DOT_PIXELS + 3)
	local corner = lead:FindFirstChildOfClass("UICorner")
	if corner ~= nil then
		corner:Destroy()
	end
	stats.fatals += 1
end

-- ---------------------------------------------------------------- the clock

-- THE ONE THING ON THIS CARD THAT MOVES, and the house style allows exactly this: a fade. `step` is
-- public and takes its own `dt` so a spec can run three seconds of it in no time at all -- the same
-- shape `Hud`'s own timed pieces use, and the only way "it stays about three seconds" is a check
-- rather than a stopwatch held against a video.
function HitCard.step(dt: number)
	if not alive then
		return
	end
	age += math.max(0, dt)
	if age <= CONFIG.HOLD_SECONDS then
		setFade(0)
		return
	end
	local into = age - CONFIG.HOLD_SECONDS
	if into >= CONFIG.FADE_SECONDS then
		stats.hides += 1
		hide()
		return
	end
	setFade(into / math.max(1e-6, CONFIG.FADE_SECONDS))
end

function HitCard.hide()
	hide()
end

-- Wired by `Hud.start`, once. `ReportSystem` is optional for the reason every other collaborator
-- there is: a world that has not booted the report replica still gets a Hud, it just never gets a
-- card.
function HitCard.start(frame: Frame, collaborators: any)
	if started then
		return
	end
	started = true
	build(frame)
	local ReportSystem = collaborators and collaborators.Report
	if ReportSystem ~= nil then
		table.insert(wires, ReportSystem.Hit:Connect(HitCard.show))
		table.insert(wires, ReportSystem.HitFatal:Connect(HitCard.markFatal))
	end
	connection = RunService.RenderStepped:Connect(HitCard.step)
end

function HitCard.stop()
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	for _, wire in ipairs(wires) do
		wire:Disconnect()
	end
	table.clear(wires)
	hide()
	started = false
end

return HitCard

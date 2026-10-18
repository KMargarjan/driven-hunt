--!strict
-- PlayerScripts.Hud: THE OWNER OF ANYTHING DRAWN (CLAUDE.md rule 3, GAME_DESIGN.md "UI / anything
-- drawn", which this system fills). It is the only writer of PlayerGui.HunterHud and everything in
-- it: the crosshair, one barrel/ammo readout, the hit marker, the drive bar and the event feed
-- (Milestone 1.7a), and the SCORE SCREEN and the TIED banner (1.7b).
--
-- renderScore and renderTied are public for one reason, stated so nobody widens it: a drive is 600
-- seconds long, so no harness run reaches the Scoring phase, and a spec that cannot hand this module
-- a Scoring snapshot cannot check that the panel really is on screen -- which is the one check
-- docs/PROJECT_CONTEXT.md's "a visibility audit certified a blank screen twice" demands.
--
-- THE HIT MARKER is Karen's playtest answered ("I cannot tell whether I hit"): a short white tick on
-- a confirmed hit, a longer red one on a kill. The server tells the shooter alone, one way, over
-- Shotgun.Remotes.HitMarker; the weapon owns that remote and fires it when its own cast confirmed a
-- damageable target, and the BOAR's runtime -- through BoarBoot -- is what turns a hit into a kill.
-- Nothing about it is decided here: this module only draws.
--
-- THE DEPENDENCY DIRECTION IS ONE-WAY AND IT IS THE POINT. The Hud READS PlayerScripts.Weapon and
-- is never called by it; the weapon has no reference to the Hud and does not know it exists. The
-- previous project died partly of "one predicate answered two unrelated questions, so mounting hid
-- both the crosshair and the weapon" (docs/PROJECT_CONTEXT.md). Here the crosshair has exactly one
-- writer and that writer's only input is published state.
--   ScreenGui   https://create.roblox.com/docs/reference/engine/classes/ScreenGui
--   GuiObject   https://create.roblox.com/docs/reference/engine/classes/GuiObject
--   UIStroke    https://create.roblox.com/docs/reference/engine/classes/UIStroke
--
-- Design: docs/design/shotgun.md (sections 3.4, 5.6), docs/design/camera.md (section 6.2),
--         docs/design/drive.md (section 9.3)
-- Note:   docs/research/2026-09-24-shotgun.md
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
-- WHETHER THIS DEVICE HAS A TOUCHSCREEN, which only `Hud.Rail` asks (task 165).
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Drive = require(ReplicatedStorage:WaitForChild("Drive"))
-- Which world this is, so the compass knows whether anybody has said where the drive comes from
-- (task 125). Read, never written: `Map.EXPECTED_WORLD` is a commit, not a flag.
local Map = require(ReplicatedStorage:WaitForChild("Map"))
local Report = require(ReplicatedStorage:WaitForChild("Report"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
-- THE SHOP'S CATALOGUE AND ITS ONE PURE GEOMETRY QUESTION (task 178): `Shop.withinReach`, asked
-- once per frame in `Hud.renderObjective` -- the one place in this file that reads where the player
-- is standing -- and handed to `ShopPanel.setNear`, which now only ever CLOSES the panel: since
-- task 181 the shopkeeper's `ProximityPrompt` is the one thing that opens it, and that prompt is
-- resolved in the same place and handed over by `ShopPanel.setPrompt`.
local Shop = require(ReplicatedStorage:WaitForChild("Shop"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))

-- THE ONE SOURCE for every colour, face, size, radius and duration this screen draws with (task
-- 201). The Designer's design system, 2026-10-17 is the spec: Karen, ~12:30, *"all menus all
-- information (timer  what to shoot who you are ect. ) has to be same design as menu colors loading
-- ect ... we need one unified design system and colours and style across all game"*.
--
-- WHAT THAT MEANS IN THIS FILE: `Enum.Font.Code` and the black `UIStroke` leave the status bar, the
-- ammo readout and the event feed, and every word drawn over the 3-D world sits on a SLATE instead
-- (§2). An outline thickens every letter, halves the apparent size of 11 px type, and still fails
-- over a bright sky because the outline itself is only 1 px; a slate was measured against the six
-- worst grounds this game makes and clears 4.5 : 1 on all of them.
local Style = require(script.Style)
-- The beater's horn, for its cooldown and the attribute the SERVER stamps on the Tool at each
-- accepted blast (task 201 surface 7). Read-only: `Weapon.Horn` owns the Tool and the blast, and
-- this file draws the answer it published -- the arrangement `Camera.Viewmodel` already has.
local Horn = require(ReplicatedStorage:WaitForChild("Horn"))

-- The Hud's own 2-D feedback sounds have one writer, and this is it (task 124).
local Sound = require(script.Sound)
-- THE REPORT PANEL (task 124 stage B). It is a sibling module and not a second ScreenGui: the Hud
-- builds the frame with everything else here, and `ReportPanel` is the one writer of what goes inside
-- it. One ScreenGui, built once, so a visibility audit has one place to look.
local ReportPanel = require(script.ReportPanel)
-- THE HIT CARD (task 198): created here with the rest of the screen, filled by `Hud.HitCard`, which
-- -- not this file -- is the only writer of what goes in it and of its `Visible`.
local HitCard = require(script.HitCard)
-- ...AND THE ONE BUILDER OF THE BOAR PICTURE (task 198), required here only so the Hud can publish
-- it the way it publishes every other sibling module -- a spec reads it off the Hud rather than
-- walking PlayerScripts for it. Nothing in this file draws with it; `HitCard` and `ReportPanel` do.
local BoarArt = require(script.BoarArt)
-- ...and the compass strip (task 125). Same shape as the report panel: the Hud builds the frame
-- with everything else, and `Compass` is the one writer of what goes inside it.
local Compass = require(script.Compass)
-- ...and the map (task 155). Karen: *"I am missing map, we need a map when click M"*. Same shape
-- again: the Hud builds the two frames and the button, and `MapUi` is the one writer of everything
-- inside them -- including their `Visible`, which is the ONE place this file does NOT copy the
-- compass's two-writer arrangement (see `Hud.renderScope` and `docs/design/map-ui.md` section 3.3).
--
-- IT IS CALLED `MapUi` AND NOT `Map` because `Map` above is the WORLD contract
-- (`ReplicatedStorage.Map`), and this file needs both at once. The world, and the picture of it.
local MapUi = require(script.MapUi)
-- ...AND THE TWO THINGS TASK 165 ADDED, in the same shape as the three above: the Hud builds the
-- nodes and each module is the one writer of everything inside its own.
--
-- `Objective` owns the objective LINE and the WAYPOINT chevron, which are one answer rendered twice
-- ("what must I do" and "where"); `Rail` owns the right-edge button column. Karen, 2026-10-12:
-- *"we need to have better map or direction that people has to walk we need to improve design that
-- it will be clear to understand what happening / could be buttons on the side for M - map ect"*.
local Objective = require(script.Objective)
local Rail = require(script.Rail)
-- ...AND THE SHOP PANEL (task 178), in the same shape: the Hud builds the frame and `ShopPanel` is
-- the one writer of everything inside it. It follows `MapUi` rather than the compass in the one
-- respect that matters -- it owns its own `Visible` -- because whether the shop is open is a thing
-- the player and the counter decide (docs/design/shop.md section 5.1).
local ShopPanel = require(script.ShopPanel)
-- THE TRUCK PADS' SIZE DIALOG (task 182), in the same shape as the shop panel: this file builds the
-- frame and that module fills it and owns its `Visible`.
local PadPanel = require(script.PadPanel)

local Hud = {}

-- WHERE THE SIGHT PICTURE SITS IN THE STACK (task 141). The mask blacks out the screen, so it must
-- be over everything the Hud draws on top of the world -- and the compass reaches `Z_INDEX + 4`, so
-- 11 rather than the 7 the first version used. MEASURED: at 7 the compass strip, the DRIVE marker
-- and both bearing labels were drawn INSIDE the eyepiece, floating in the glass.
--
-- The duplex is over the mask, because a reticle is etched on the glass and not behind it. The
-- drive report's panel is over BOTH (`Report.CONFIG.PANEL_Z_INDEX`): the player opened that.
local SCOPE_Z = 11
local RETICLE_Z = SCOPE_Z + 2

local gui: ScreenGui? = nil
local crosshair: Frame? = nil
-- THE AMMO CHIP (surface 6) and THE HORN CHIP (surface 7), bottom right, and ONLY ONE OF THE TWO
-- EVER EXISTS (§4.3): a beater carries no gun and a hunter carries no horn, so they share a corner
-- rather than fight for it. `readout` is gone as a `TextLabel`; `Hud.readoutText` now answers
-- `readoutWords`, which is the chip's own content as one line.
local ammoChip: Frame? = nil
-- The two shells the chip can wear, by `Style.glyph` kind. Built once with the chip; see §3.10.
local ammoShells: { [string]: Frame } = {}
local ammoPips: { Frame } = {}
local ammoValue: TextLabel? = nil
local ammoCaption: TextLabel? = nil
local ammoBarFill: Frame? = nil
local ammoBarTrack: Frame? = nil
-- THE ROW INSIDE EACH CORNER CHIP, held because the BAR under it is sized from the row's measured
-- width every frame. A bar sized in SCALE cannot be used here: the slate is `AutomaticSize.X`, so a
-- scale-width child and the box that measures it chase each other and settle wide -- measured
-- TWICE, as the horn's bar running the whole screen (`...133631Z-t201-beater-running-2.png`) and
-- then, with the row moved into its own frame, still 430 px (`...134503Z-t201c-beater-cooldown.png`).
-- An OFFSET width read off the row terminates: the row does not depend on the bar, and the slate
-- settles at max(row, bar) = row.
local ammoBody: Frame? = nil
local hornBody: Frame? = nil
local readoutWords = ""
-- WHEN THIS CLIENT SAW THE RELOAD START, and how long it was going to take. The snapshot carries
-- `busyFor` and nothing ticks it down between publications, so the BAR is predicted from this
-- client's own clock -- which is what a readiness bar is for. Latched on the rising edge only.
local reloadStartedAt: number? = nil
local reloadTotal = 0
local hornChip: Frame? = nil
local hornValue: TextLabel? = nil
local hornCaption: TextLabel? = nil
local hornBarFill: Frame? = nil
-- THE LAST BLAST THIS CLIENT HAS SEEN, and when it noticed -- `Camera.Viewmodel`'s own arrangement
-- for the same attribute. `Horn.BLOW_ATTRIBUTE` is an increasing number the SERVER stamps inside
-- `Weapon.Horn.blowTool`, the one door every accepted blast goes through, so the bar starts EMPTY
-- and FILLS from the server's reply. The design's §7 names the alternative and refuses it: *"a bar
-- that drains from full and then jumps is worse than no bar"*.
local hornBlowSeen: number? = nil
local hornBlowAt: number? = nil
-- HAS THIS TOOL BEEN PRIMED YET? A SEPARATE FLAG AND NOT `hornBlowSeen ~= nil`, because nil is a
-- REAL value of it: a horn that has never been blown carries no attribute at all
-- (`Weapon.Horn.blowTool` creates it inside the blast), so overloading the two swallows the FIRST
-- blast of every freshly-equipped horn -- the chip reading `READY` with a full bar for the whole
-- 1.5 s the server is refusing, which is the one question it exists to answer. Round 2's fix for
-- round 1's note did exactly that, and `src/client/Camera/Viewmodel.luau` had already written the
-- reason down for its own copy of this latch (`hornBlowPrimed`).
local hornBlowPrimed = false
local hornThrough = false
local hitMark: Frame? = nil
local hitKind: string? = nil
local hitToken = 0 -- so a second hit during the first mark's life cannot hide it early
local markerConnection: RBXScriptConnection? = nil
-- WHETHER THE DRIVE BAR IS ACTUALLY WIRED TO THE MATCH (task 134). Not a cache of what is drawn --
-- `renderDrive` is that -- but the answer to "did the Hud ever find the system it draws from", which
-- was silently NO for a whole session whenever `PlayerScripts.Match` lost a replication race.
local matchConnected = false
-- ...AND THE SYSTEM ITSELF, kept because two things need it at two different times: the connections
-- in `Hud.useMatch`, and the report panel, which is handed its collaborators further down `start`.
-- When `Match` wins its race -- the common case -- this is set before the panel is built and the
-- panel gets it the way it always did; when it loses, `useMatch` hands it over afterwards.
local matchSystem: any = nil
-- THE STATUS BAR IS A SLATE OF CHIPS SINCE TASK 201 (surface 1), and not one 20 px line of
-- `Enum.Font.Code` with a black outline. The frame is still called `DriveBar`, because
-- `tests/client/match_client.spec.luau` walks for it by name and that spec is in `TWO_PLAYER_PATHS`.
local driveBar: Frame? = nil
local statusChips: { [string]: { chip: Frame, value: TextLabel, caption: TextLabel } } = {}
local statusDividers: { Frame } = {}
local statusPill: Frame? = nil
local statusPillText: TextLabel? = nil
local statusCoin: Frame? = nil
-- WHAT THE CHIPS SAY, IN ORDER, AS PLAIN WORDS. `Hud.driveBarText` answers this and not the drawn
-- strings, and the difference is one thing only: §1.2 LETTER-SPACES an uppercase caption at 11 px
-- and smaller ("T I M E"), which is tracking and not content. A spec asserting `DRIVE %d` is
-- asserting the FACT. Written in the same pass as the labels, by the same writer, so the two can
-- never drift.
local statusWords: { string } = {}
local feedFrame: Frame? = nil -- kept for the client spec's ancestor walk
local feedLines: { TextLabel } = {}
local feedToasts: { Frame } = {}
local feedDots: { Frame } = {}
local feedEntries: { { text: string, at: number, meaning: string? } } = {}
local scorePanel: Frame? = nil
local reportFrame: Frame? = nil
-- THE REPORT'S SCRIM (task 201 part 2): the report is a MODAL and a modal lays one. Created here,
-- written by `ReportPanel`, which is the one owner of whether the report is open.
local reportScrimFrame: Frame? = nil
local hitCardFrame: Frame? = nil
-- THE SHOP PANEL'S FRAME (task 178): created here, filled by `Hud.ShopPanel`, and that module --
-- not this one -- writes its `Visible`.
local shopFrame: Frame? = nil
-- THE PAD DIALOG'S FRAME (task 182): created here, filled by `Hud.PadPanel`, and that module -- not
-- this one -- writes its `Visible`. The shop panel's arrangement, one task later.
local padFrame: Frame? = nil
-- THE LOADING BANNER'S FRAME (task 197): created here with the rest of the screen, filled by
-- `Hud.PadPanel`, which also owns its `Visible` -- the dialog's own arrangement, one frame over.
local padLeavingFrame: Frame? = nil
-- WHICH PAD THIS CLIENT HAS ALREADY TURNED TO FACE (task 197 part 2). One number, so the camera is
-- asked ONCE per walk-on and not once a frame -- `ShopPanel.setNear`'s edge discipline.
local facedPad: number? = nil
local compassFrame: Frame? = nil
-- Did the scope's own mask hide the compass strip? See `Hud.renderScope`.
local compassHiddenByScope = false
-- THE MAP'S THREE NODES (task 155). The Hud creates them and writes their size, position and
-- `ZIndex`; `MapUi` writes everything inside them and their `Visible`.
local miniMapFrame: Frame? = nil
local fullMapFrame: Frame? = nil
-- THE MAP'S LEGEND (task 165): a fourth node of the map's, created here and filled by `MapUi`.
local mapLegendFrame: Frame? = nil
-- THE MAP'S OWN TOUCH BUTTON IS GONE (task 165, design 7.2 item 1). It was `touchEnabled and
-- BUTTON_ENABLED`, so it never appeared in a single one of Karen's PC sessions -- which is why she
-- asked for *"buttons on the side for M - map ect"* for a button that was already written. It is the
-- first button of `Hud.Rail` now, which calls the same `MapUi.toggle` the M key calls. The removed
-- block is archived with its reason in `backups/2026-10-12_mapui-touch-button.txt` (rule 7).
-- TASK 165'S OWN NODES: the objective line, the waypoint chevron and its word, and the rail.
-- THE OBJECTIVE'S SLATE AND ITS LABEL (surface 2). The label is still the thing `Objective` writes
-- and `Hud.objectiveLine` answers; the slate is what carries it over the world, and `Objective` --
-- the one writer of the line -- writes its `Visible` too.
local objectiveSlate: Frame? = nil
local objectiveLine: TextLabel? = nil
local waypointMark: Frame? = nil
local waypointWord: TextLabel? = nil
local railFrame: Frame? = nil
-- WHERE THE WORLD SAYS THE DRIVE IS, resolved once by the closure in `Hud.start` and read every
-- frame by `Hud.renderObjective`. Module-level because the per-frame pass is now the ONE writer of
-- the compass's bearing and the map's push arrow -- see `Hud.renderObjective`.
local worldBearing: number? = nil
local worldBearingLabel: string? = nil
-- Has this player reached the place the objective sends them? Latched, so the chevron cannot
-- flicker: `Objective.arrived` holds the hysteresis and this is the state it is applied to.
local arrivedAtTarget = false
-- THE LOBBY'S DATA MODULE (task 177), reached through the door this file already uses for a
-- world-specific module (`Hud.whenReady`, the same call that waits for `ForestTest`). nil in a world
-- that has no such module, and then every lobby branch of `Objective` is simply never taken.
--
-- IT IS THE PRESENCE OF THE **PART** AND NOT OF THE MODULE that says a world has a lobby: the module
-- replicates to every client in every place, and `Lobby.spotPosition()` answers nil until the server
-- has actually built one. So the Hud learns nothing about worlds and reads no flag.
local lobbyData: any = nil
-- THE RESULTS BOARD'S PARTS (task 201 part 2). A slot is a section HEAD or a ROW and both are
-- built for every line the body can hold; `scoreCells` is that row's `TextLabel` per column, which
-- is what §3.12's *"one `TextLabel` per cell"* means in this file.
local scoreEyebrow: TextLabel? = nil
local scoreTitle: TextLabel? = nil
local scoreBody: ScrollingFrame? = nil
local scoreLines: { Frame } = {}
local scoreHeads: { Frame } = {}
local scoreCells: { { [string]: TextLabel } } = {}
local scoreFooterWord: TextLabel? = nil
local scoreFooterValue: TextLabel? = nil
local scoreFooterFill: Frame? = nil
local tiedBanner: Frame? = nil
local tiedText: TextLabel? = nil
-- WHAT THE COUNTDOWN BAR IS A FRACTION OF. Latched from the clock itself while the board is up and
-- cleared when it goes down -- `Match.CONFIG.SCORE_SECONDS` is the SERVER's and this client cannot
-- require it, and a constant copied here would be a number that can disagree with the gap the
-- drive actually used.
local scoreCountdownFrom = 0
-- THE START CARD (task 158): built once with everything else, shown only by `Hud.renderStartCard`.
-- EIGHT CHILDREN AND FOUR ROWS SINCE 201 PART 3 (the Designer's `startcard-spec.md`), each handle
-- held here because the card is built once and written per frame -- the rule every surface in this
-- file follows.
local startCard: Frame? = nil
local startCardPad: UIPadding? = nil
local startCardTitle: TextLabel? = nil -- the eyebrow: `DRIVE 1`
local startCardRole: TextLabel? = nil
local startCardRules: { Frame } = {}
local startCardSection: Frame? = nil
local startCardSectionWord: TextLabel? = nil
local startCardSectionRule: Frame? = nil
local startCardRowsBox: Frame? = nil
local startCardTimer: TextLabel? = nil -- the countdown's label
local startCardSecondsLabel: TextLabel? = nil
local startCardCount: Frame? = nil
local startCardBarSlot: Frame? = nil
local startCardFill: Frame? = nil
-- ONE ROW'S PARTS. Every glyph is BUILT and one is SHOWN -- the discipline the board's badge and
-- leaver tag already use, because a renderer that creates instances per frame is the one thing a
-- HUD must never do.
type StartRowParts = {
	row: Frame,
	icons: { [string]: Frame },
	text: TextLabel,
	value: TextLabel,
	word: TextLabel,
	tag: Frame,
	tagText: TextLabel,
}
local startCardRowParts: { StartRowParts } = {}
-- WHAT THE COUNTDOWN BAR IS FULL AT, latched. See `Drive.CONFIG`'s own note: the phase's length is
-- `Match.CONFIG.INTERMISSION_SECONDS` and the client is never told it, so the largest `secondsLeft`
-- this card has seen IS the length, and the first frame is full by construction.
local startCardFullSeconds = 0
local started = false

-- HOW WIDE THE SCREEN IS, ASKED ONCE AND IN ONE PLACE. Every size on this screen comes off the
-- scale (`Style.sizeFor`) and the scale has exactly one break point, so "is this a phone" must have
-- exactly one reader too. `CurrentCamera` may be nil for a frame at boot, and then the desktop step
-- is the answer -- which is the step this game is played at.
-- A VIEWPORT THAT HAS NOT RENDERED YET IS NOT A PHONE, and that cost the first Play of this task.
-- `Camera.ViewportSize` is **(1, 1)** until the engine has drawn a frame, and `Hud.build` runs
-- before that -- so every size on the screen came out at the phone step and the compass was built
-- 120 px wide instead of 420 (`20261017T133606Z-t201-hunter-running.png`). Anything under
-- `MIN_SENSIBLE_PX` is "not yet", not "small", and the desktop step is the right guess for a game
-- Karen plays on a PC. `Hud.applyViewportLayout` then corrects it on the first real frame, and on
-- every resize after that.
-- IT LIVES IN `Style` SINCE TASK 201 PART 2 and this is the alias. The report panel needed the
-- same guard and cannot require this file (the Hud requires IT), so the reader moved to the one
-- source -- and the second ungated copy it had built 24 px rows on a 969 px screen, which is the
-- same defect at a different surface.
Hud.MIN_SENSIBLE_PX = Style.MIN_SENSIBLE_PX

function Hud.viewportX(): number
	return Style.viewportX()
end

-- EVERY LABEL THAT TAKES ITS SIZE FROM THE SCALE, with the step it takes. Registered as it is
-- built, so `Hud.applyViewportLayout` can move the whole screen to the other step with no list to
-- keep in two places -- and so a label added later cannot be forgotten, because it is registered
-- where it is created.
local sizedLabels: { { label: TextLabel, step: string } } = {}

local function sized(label: TextLabel, step: string): TextLabel
	table.insert(sizedLabels, { label = label, step = step })
	return label
end

-- WHAT FOLLOWS THE WINDOW. Edge-triggered on the width -- `ShopPanel.setNear`'s own discipline --
-- so the per-frame caller costs one comparison and never a write.
--
-- THREE THINGS DEPEND ON THE VIEWPORT and nothing else does: every label's step, the compass
-- strip's width (420 on a desktop, `screenW - 24` on a phone), and the ceiling the status slate may
-- not grow past (§4.3 rule 2). The rest of the layout is anchored to an edge or to the centre.
local lastViewportX = 0

-- ---------------------------------------------------------------- the start card's two layouts
--
-- EVERY NUMBER THE DESIGNER MEASURED, in one table, desktop then phone (`startcard-spec.md`
-- section 3: *"Measured on `startcard-mockups.png`, after the fonts load"*). The card is the only
-- surface in the game whose whole geometry changes at the break point -- it is 440 wide and centred
-- on a desktop and 264 wide against the left margin on a phone -- so the two steps are written out
-- rather than derived, and `layoutStartCard` is the one writer of all of them.
--
-- WHY IT IS NOT CENTRED ON A PHONE (the spec's amendment 2): a 368-wide card centred on 400 px runs
-- x 16..384, which buries the minimap (x 288..384) and sits under the rail that draws OVER it.
-- 16..280 stops 8 px short of the map, so a hunter keeps the map he needs to find his stand.
Hud.START_CARD = {
	{
		width = 440,
		height = 274,
		pad = 14,
		side = 16,
		eyebrow = 12,
		role = 30,
		roleTop = 4,
		ruleTop = 10,
		section = 11,
		sectionTop = 10,
		rowsTop = 6,
		rowH = 24,
		glyph = 16,
		gap = 12,
		value = 40,
		rule2Top = 10,
		countTop = 11,
		count = 30,
		barTop = 8,
		top = 150,
		left = nil :: number?,
	},
	{
		width = 264,
		height = 239,
		pad = 12,
		side = 14,
		eyebrow = 11,
		role = 26,
		roleTop = 3,
		ruleTop = 8,
		section = 10,
		sectionTop = 8,
		rowsTop = 5,
		rowH = 21,
		glyph = 14,
		gap = 10,
		value = 34,
		rule2Top = 9,
		countTop = 10,
		count = 26,
		barTop = 7,
		top = 124,
		left = 16 :: number?,
	},
}

function Hud.startCardStep(viewX: number)
	return if Style.isPhone(viewX) then Hud.START_CARD[2] else Hud.START_CARD[1]
end

-- THE CONTENT BOX'S WIDTH: the card less its own padding, which is what every cell inside is
-- measured against. One function, because `Style.cardInset`'s own lesson in part 2 was a surface
-- measured WITHOUT the padding that indents it.
function Hud.startCardContentWidth(viewX: number): number
	local step = Hud.startCardStep(viewX)
	return step.width - 2 * step.side
end

-- HOW WIDE A ROW'S TEXT CELL IS. `reserve` is what the right-hand cell takes (0 when the row has
-- nothing to say, which is the spec's rule 2: *"the right-hand cell is dropped first and the text
-- keeps the width"*). PURE, so the one rule that a row never wraps can be asserted without a frame.
function Hud.startCardTextWidth(viewX: number, reserve: number): number
	local step = Hud.startCardStep(viewX)
	local x = step.glyph + step.gap
	local slack = Hud.startCardContentWidth(viewX) - x
	if reserve > 0 then
		slack -= reserve + step.gap
	end
	return math.max(1, slack)
end

local function layoutStartCard(viewX: number)
	local card = startCard
	if card == nil then
		return
	end
	local step = Hud.startCardStep(viewX)
	card.Size = UDim2.fromOffset(step.width, step.height)
	if step.left ~= nil then
		card.AnchorPoint = Vector2.new(0, 0)
		card.Position = UDim2.fromOffset(step.left, step.top)
	else
		card.AnchorPoint = Vector2.new(0.5, 0)
		card.Position = UDim2.new(0.5, 0, 0, step.top)
	end
	if startCardPad ~= nil then
		local pad = startCardPad :: UIPadding
		pad.PaddingTop = UDim.new(0, step.pad)
		pad.PaddingBottom = UDim.new(0, step.pad)
		pad.PaddingLeft = UDim.new(0, step.side)
		pad.PaddingRight = UDim.new(0, step.side)
	end
	if startCardTitle ~= nil then
		(startCardTitle :: TextLabel).Size = UDim2.new(1, 0, 0, step.eyebrow)
	end
	if startCardRole ~= nil then
		local role = startCardRole :: TextLabel
		role.Size = UDim2.new(1, 0, 0, step.role + step.roleTop)
		local pad = role:FindFirstChildOfClass("UIPadding")
		if pad ~= nil then
			(pad :: UIPadding).PaddingTop = UDim.new(0, step.roleTop)
		end
	end
	-- FULL-BLEED, which is why the card's list is centre-aligned: a child 2 x `side` wider than the
	-- content box overhangs it equally on both sides, so the hairline runs to the card's own edges.
	for index, slot in ipairs(startCardRules) do
		local above = if index == 1 then step.ruleTop else step.rule2Top
		slot.Size = UDim2.new(1, 2 * step.side, 0, 1 + above)
	end
	if startCardSection ~= nil then
		local head = startCardSection :: Frame
		head.Size = UDim2.new(1, 0, 0, step.section + step.sectionTop)
		local pad = head:FindFirstChildOfClass("UIPadding")
		if pad ~= nil then
			(pad :: UIPadding).PaddingTop = UDim.new(0, step.sectionTop)
		end
	end
	if startCardRowsBox ~= nil then
		local box = startCardRowsBox :: Frame
		local pad = box:FindFirstChildOfClass("UIPadding")
		if pad ~= nil then
			(pad :: UIPadding).PaddingTop = UDim.new(0, step.rowsTop)
		end
	end
	for _, parts in ipairs(startCardRowParts) do
		parts.row.Size = UDim2.new(1, 0, 0, if parts.row.Visible then step.rowH else 0)
		local icon = parts.row:FindFirstChild("Icon") :: Frame?
		if icon ~= nil then
			icon.Size = UDim2.fromOffset(step.glyph, step.glyph)
		end
		for _, glyph in pairs(parts.icons) do
			glyph.Size = UDim2.fromOffset(step.glyph, step.glyph)
		end
		parts.text.Position = UDim2.fromOffset(step.glyph + step.gap, 0)
		parts.value.Size = UDim2.new(0, step.value, 1, 0)
	end
	if startCardCount ~= nil then
		local count = startCardCount :: Frame
		count.Size = UDim2.new(1, 0, 0, step.count + step.countTop)
		local pad = count:FindFirstChildOfClass("UIPadding")
		if pad ~= nil then
			(pad :: UIPadding).PaddingTop = UDim.new(0, step.countTop)
		end
	end
	if startCardBarSlot ~= nil then
		(startCardBarSlot :: Frame).Size = UDim2.new(1, 0, 0, 4 + step.barTop)
	end
end

function Hud.applyViewportLayout(viewX: number)
	if viewX == lastViewportX then
		return
	end
	lastViewportX = viewX
	for _, entry in ipairs(sizedLabels) do
		entry.label.TextSize = Style.sizeFor(entry.step, viewX)
	end
	if compassFrame ~= nil then
		(compassFrame :: Frame).Size = UDim2.fromOffset(Compass.widthFor(viewX), Compass.CONFIG.HEIGHT)
	end
	if driveBar ~= nil then
		local cap = (driveBar :: Frame):FindFirstChild("MaxWidth")
		if cap ~= nil then
			local _, _, width = Hud.statusRect(Vector2.new(viewX, 1));
			(cap :: UISizeConstraint).MaxSize = Vector2.new(math.max(1, width), math.huge)
		end
	end
	-- ...AND THE START CARD, WHOLE. It is the fourth thing that follows the window and the only one
	-- whose own box changes: 440 x 274 centred, or 264 x 239 at the left margin (the spec's
	-- section 3). Edge-triggered with the rest, so it costs one comparison per frame.
	layoutStartCard(viewX)
end

-- HOW TALL THE WHOLE TOAST FEED IS, and it is the REAL stack and not a guess at it. The hit card's
-- position is computed from this one number, so §4.3's *"BOTTOM LEFT hit card | toast feed --
-- stacked; hit card bottom = feed top - 8"* holds only if the number is true.
--
-- ROUND 1'S SECOND BLOCKING FINDING WAS THAT IT WAS NOT. 28 px a line was written against a toast
-- that measures 30 (6 + 6 of slate padding around an 18 px line box) with a 6 px gap between them,
-- so five lines came to 174 px inside a 140 px reservation -- the stack grew 34 px above its own
-- frame, which has no `ClipsDescendants`, onto a 138 px hit card. Five entries inside
-- `FEED_SECONDS` is reachable: `renderFeed` trims only past `FEED_LINES`.
--
-- `Style.toastHeight` is the one source for a toast's height and `Style.toast` builds to it.
function Hud.feedHeight(viewportX: number?): number
	local lines = Drive.CONFIG.FEED_LINES
	local height = Style.toastHeight(viewportX or Hud.viewportX())
	return lines * height + math.max(0, lines - 1) * Style.TOAST_GAP
end

-- ---------------------------------------------------------------- the top band (task 201 §4.1)
--
-- WHERE THE STATUS SLATE SITS, AND HOW WIDE IT IS ALLOWED TO GET. The Designer's §4.1 asks for
-- y 50, h 40 and a maximum width of `screenW - 332`; what is below is that shape fitted into the
-- band this repo actually has, and the one number that could not move is why.
--
-- `Drive.CONFIG.TIED_TOP_OFFSET` IS 74 AND LIVES IN `src/shared/Drive/`, WHICH IS IN
-- `TWO_PLAYER_PATHS` (CLAUDE.md, Director 2026-10-03) -- so the tied banner cannot be moved by a
-- task whose gate is the one-player run. The band is therefore: objective 8..38, THIS 40..74, tied
-- banner 74..104, compass 108..138, minimap 140. The slate is 34 px rather than 40, and the
-- difference is reported rather than hidden. Moving the banner (surface 13) is the system's own
-- task C, and the band's final geometry goes with it.
--
-- `SIDE_INSET` IS THE RIGHT COLUMN, APPLIED TO BOTH SIDES SO THE SLATE STAYS CENTRED (§4.3 rule 2):
-- nothing may enter the 68 px the minimap and the rail own. On a PHONE the minimap drops BELOW the
-- compass, so there is no column beside the bar and the slate gets the full width less a gutter --
-- which is the design's own §4.2 (max w 376 at 400 px).
-- ---------------------------------------------------------------- the results board (surface 11)
--
-- THE BOARD IS A CARD OF TABLE ROWS SINCE TASK 201 PART 2, and its HEIGHT FOLLOWS THE ROW COUNT.
-- Until now it was 20 fixed row slots and drew a 480 x 574 box to hold three of them --
-- `191-gathering-aimed-1.png` is most of the problem in one picture, and §3.12 names it.
--
-- ONE `TextLabel` PER CELL. The monospace alignment is gone with `Enum.Font.Code`: the numbers line
-- up because they are PLACED, which is why a column here is an x and a width rather than a
-- `%7d` inside one string.
-- LEFT TO RIGHT, which `pairs` over `COLUMNS` cannot answer: a table has no order and a board read
-- back out of order would be a board nobody could compare with the screen.
Hud.BOARD_ORDER = { "rank", "name", "kills", "points", "coins" }

Hud.BOARD = {
	WIDTH = 520,
	-- IT IS `Style.cardInset`'s 12 AND NOT 16 (round 1 note): the board IS a card, the card's own
	-- `UIPadding` is what indents it, and a second, larger number here pushed the whole table 8 px
	-- left of centre inside that padding. One inset, read from one place.
	PADDING = 12,
	-- The eyebrow + title pair, the column head, and the footer with its countdown bar.
	HEADER_H = 54,
	FOOTER_H = 52,
	-- IT SCROLLS PAST 14 ROWS (§3.12). A roster of 16 in two rankings plus two section heads is 18
	-- lines, which is the one case the designer could not fit on a phone (§7) -- so the body is a
	-- `ScrollingFrame` whose own height is the content's, capped here.
	MAX_VISIBLE_ROWS = 14,
	-- x, width and alignment of every column, inside the padded body (488 px at 520 wide).
	COLUMNS = {
		rank = { x = 0, w = 20, right = true },
		name = { x = 28, w = 186, right = false },
		kills = { x = 214, w = 74, right = true },
		points = { x = 292, w = 78, right = true },
		coins = { x = 374, w = 66, right = true },
		badge = { x = 448, w = 40, right = false },
	},
}

-- HOW TALL THE BOARD IS FOR A GIVEN NUMBER OF LINES. PURE AND EXPORTED, because "the height follows
-- the row count" is the whole of what §3.12 asks for and a spec cannot reach `Scoring`.
--
-- A SECTION HEAD IS SHORTER THAN A ROW, so the two are counted separately rather than averaged.
-- ...AND IT COUNTS THE CARD'S OWN PADDING, which round 1's second blocking finding was about.
-- `Style.card` ends with a `UIPadding` of `Style.cardInset` all round, so a board of height H has a
-- CONTENT box of H - 2 x inset; this returned the content height as the whole height, and the
-- footer -- anchored to the bottom of that content box -- was therefore drawn `2 x inset` up, over
-- the last row of the table. `Style.cardInset` is the one source for the number.
function Hud.boardHeight(rows: number, heads: number, viewportX: number?): number
	local view = viewportX or Hud.viewportX()
	local rowH = Style.rowHeight(view)
	local headH = if Style.isPhone(view) then 18 else 20
	local body = math.max(0, rows) * rowH + math.max(0, heads) * headH
	local cap = Hud.BOARD.MAX_VISIBLE_ROWS * rowH
	local content = Hud.BOARD.HEADER_H + rowH + math.min(body, cap) + Hud.BOARD.FOOTER_H
	return content + 2 * Style.cardInset(view)
end

-- THE CONTENT BOX the three bands are laid out in -- the card's height less its own padding. The
-- renderer positions the header, the column head and the body from the TOP of this box and the
-- footer from its BOTTOM, so this is the one number that says they cannot collide.
function Hud.boardContentHeight(rows: number, heads: number, viewportX: number?): number
	local view = viewportX or Hud.viewportX()
	return Hud.boardHeight(rows, heads, view) - 2 * Style.cardInset(view)
end

-- HOW MANY CHAMBER PIPS ARE BUILT. A ceiling, not a claim: the break-action has two and the rifle's
-- magazine shows three, and a wider gun later draws more of the same Frames.
Hud.PIP_MAX = 8

Hud.STATUS = {
	TOP = 40,
	HEIGHT = 34,
	SIDE_INSET = 166,
	SIDE_INSET_PHONE = 12,
	Z_INDEX = 6,
}

-- THE SLATE'S RECTANGLE at a given viewport: x, y, width, height. PURE AND EXPORTED, for the reason
-- `Objective.lineRect` and `Rail.rect` are -- `AbsolutePosition` can only answer for whatever size
-- the Studio window happens to be, and the no-overlap claim is about 400 x 800 as well.
--
-- IT IS THE MAXIMUM AND NOT THE DRAWN WIDTH. The slate is `AutomaticSize.X` and is the size of its
-- chips; this is the box it may never grow past, so an overlap test against it is conservative.
function Hud.statusRect(viewport: Vector2): (number, number, number, number)
	local config = Hud.STATUS
	local inset = if Style.isPhone(viewport.X) then config.SIDE_INSET_PHONE else config.SIDE_INSET
	local width = math.max(0, viewport.X - 2 * inset)
	return viewport.X / 2 - width / 2, config.TOP, width, config.HEIGHT
end

function Hud.gui(): ScreenGui?
	return gui
end

function Hud.isCrosshairVisible(): boolean
	return crosshair ~= nil and crosshair.Visible
end

-- WHAT THE AMMO CHIP SAYS, AS ONE LINE: the chamber glyphs, the shell word, the pocket, and " R"
-- while it is reloading -- which is exactly what the chip draws, with the glyphs as Frames (§3.10
-- chamber pips) instead of characters. `""` when there is no gun, which is the contract
-- `tests/client/weapon_client.spec.luau` and `zz_tie_to_a_tree.spec.luau` both assert.
function Hud.readoutText(): string
	return readoutWords
end

-- WHAT THE STATUS BAR SAYS, AS PLAIN WORDS, in chip order. See `statusWords`: the screen
-- letter-spaces an uppercase caption at 11 px and smaller and this does not, because that is
-- typography and not content.
function Hud.driveBarText(): string
	return table.concat(statusWords, "   ")
end

-- The chips themselves, for a spec that wants to read a colour or a face off the real screen rather
-- than off this file's own table.
function Hud.statusChip(name: string): Frame?
	local entry = statusChips[name]
	return if entry then entry.chip else nil
end

function Hud.statusRolePill(): Frame?
	return statusPill
end

-- THE BOTTOM-RIGHT CORNER, and the rule that only one of the two is ever drawn (§4.3).
function Hud.ammoChip(): Frame?
	return ammoChip
end

function Hud.hornChip(): Frame?
	return hornChip
end

function Hud.isDriveBarVisible(): boolean
	return driveBar ~= nil and driveBar.Visible
end

function Hud.feed(): Frame?
	return feedFrame
end

-- THE TOASTS THEMSELVES (§3.11), so a spec can read a line's slate and its meaning dot off the real
-- screen. In feed order, bottom-up, exactly as `renderFeed` stacks them.
function Hud.feedToasts(): { Frame }
	return feedToasts
end

-- WHAT A FEED ENTRY MEANS, AS ONE WORD, and the dot and the words are coloured from it together so
-- they can never disagree (§3.11's table). PURE, so the mapping is assertable with no wire and no
-- drive -- the reason `Hud.feedTextFor` and `Hud.killLineText` are pure.
--
--   something happened          -> info   (BODY)
--   you did well                -> good   (PINE_TEXT)  a kill
--   you lost something          -> bad    (CLAY)       an escape, a penalty, a refusal
--   money moved                 -> money  (COIN_TEXT)
--   the game is telling you to  -> go     (BLAZE_HI)
function Hud.feedMeaningFor(entry): string
	local kind = entry and entry.kind
	if kind == "kill" then
		return "good"
	elseif kind == "escape" or kind == "violation" or kind == "refusal" then
		return "bad"
	elseif kind == "coins" then
		return "money"
	end
	return "info"
end

function Hud.objectiveSlate(): Frame?
	return objectiveSlate
end

function Hud.feedText(): { string }
	local out = {}
	for _, line in ipairs(feedLines) do
		if line.Visible and line.Text ~= "" then
			table.insert(out, line.Text)
		end
	end
	return out
end

function Hud.scorePanel(): Frame?
	return scorePanel
end

-- The compass strip, and the module that fills it (task 125).
function Hud.compass(): Frame?
	return compassFrame
end

Hud.Compass = Compass

-- The report's frame, so a spec can read its visibility without reaching through PlayerGui by name.
-- THE SHOP PANEL, published where the Hud starts it -- the `Hud.Rail` / `Hud.Shop` shape a spec
-- reaches it through.
Hud.Shop = ShopPanel

-- ...AND THE PAD DIALOG (task 182), published the same way and for the same reason.
Hud.PadPanel = PadPanel

function Hud.shopPanel(): Frame?
	return shopFrame
end

function Hud.padPanel(): Frame?
	return padFrame
end

function Hud.padLeaving(): Frame?
	return padLeavingFrame
end

function Hud.reportPanel(): Frame?
	return reportFrame
end

function Hud.reportScrim(): Frame?
	return reportScrimFrame
end

function Hud.hitCard(): Frame?
	return hitCardFrame
end

-- The panel module itself, for the same reason: the Hud starts it, so the Hud is where it is found.
Hud.Report = ReportPanel
Hud.HitCard = HitCard
-- THE ONE BUILDER OF THE BOAR PICTURE AND THE ONE PLACER OF A DOT ON IT (task 198), published here
-- the way every other sibling module is -- a spec reads it off the Hud rather than walking
-- PlayerScripts. Task 205 made its spread rule pure, and that is what a case asks.
Hud.BoarArt = BoarArt

-- THE MAP (task 155): its two frames and its button, so a spec reads them off the Hud instead of
-- walking `PlayerGui` by name -- the `Hud.compass()` / `Hud.reportPanel()` shape.
function Hud.minimap(): Frame?
	return miniMapFrame
end

function Hud.fullMap(): Frame?
	return fullMapFrame
end

function Hud.mapLegend(): Frame?
	return mapLegendFrame
end

Hud.MapUi = MapUi

-- TASK 165's THREE NODES AND TWO MODULES, read off the Hud for the reason every accessor above is:
-- a spec must never walk `PlayerGui` by name.
function Hud.objectiveLine(): TextLabel?
	return objectiveLine
end

function Hud.waypoint(): Frame?
	return waypointMark
end

function Hud.waypointWord(): TextLabel?
	return waypointWord
end

function Hud.rail(): Frame?
	return railFrame
end

Hud.Objective = Objective
Hud.Rail = Rail
-- THE ONE SOURCE, published where the Hud starts it (task 201), the `Hud.Compass` / `Hud.Rail`
-- shape: a spec reads the tokens off the Hud rather than walking `PlayerScripts` for a sibling.
Hud.Style = Style

function Hud.isScorePanelVisible(): boolean
	return scorePanel ~= nil and scorePanel.Visible
end

-- WHAT THE BOARD'S EYEBROW SAYS -- `DRIVE 1` -- which is the small brass word above the title
-- saying what kind of thing this is (§3.4).
function Hud.scoreEyebrowText(): string
	return if scoreEyebrow then scoreEyebrow.Text else ""
end

function Hud.scoreBody(): ScrollingFrame?
	return scoreBody
end

-- HOW FULL THE COUNTDOWN BAR IS, 0..1. The drawn fraction, so a spec reads the bar rather than
-- recomputing what the bar should have been.
function Hud.scoreCountdownFraction(): number
	return if scoreFooterFill then (scoreFooterFill :: Frame).Size.X.Scale else 0
end

function Hud.scoreTitleText(): string
	return if scoreTitle then scoreTitle.Text else ""
end

function Hud.scoreFooterText(): string
	-- The words and the number as one line, which is what the footer SAYS: the bar beside them is
	-- the same fact drawn, and `Hud.scoreCountdownFraction` is how a spec asks that.
	-- THE DRAWN WORD AND NOT THE CONSTANT (round 1 note). It read the label, stripped its spacing
	-- and then threw it away for `Drive.CONFIG.SCORE_FOOTER_WORD` -- so the one case that asserts
	-- this line would have passed with ANY word on screen, which is a seam that cannot fail.
	local word = if scoreFooterWord then Style.unspaced((scoreFooterWord :: TextLabel).Text) else ""
	local value = if scoreFooterValue then (scoreFooterValue :: TextLabel).Text else ""
	if word == "" and value == "" then
		return ""
	end
	return string.format("%s %s", word, value)
end

-- Only the lines that are actually showing something, in board order.
-- WHAT THE BOARD'S BODY SAYS, LINE BY LINE, as plain words -- a section head's word, or a row's
-- cells joined in column order. It reads the DRAWN labels, which is the whole point of it: the
-- board is one `TextLabel` per cell now, and a spec that asked the renderer's input instead would
-- be asserting the thing it is trying to check.
--
-- THE SCREEN LETTER-SPACES an uppercase head at 10 px (§1.2) and this does not, for the reason
-- `Hud.driveBarText` gives: that is tracking, not content.
function Hud.scoreRowText(): { string }
	local out = {}
	for index, row in ipairs(scoreLines) do
		local head = scoreHeads[index]
		if head ~= nil and head.Visible then
			local word = head:FindFirstChild("Word")
			table.insert(out, if word then Style.unspaced((word :: TextLabel).Text) else "")
		end
		if row.Visible then
			local cells = scoreCells[index]
			local parts = {}
			for _, key in ipairs(Hud.BOARD_ORDER) do
				local cell = cells and cells[key]
				if cell ~= nil and cell.Text ~= "" then
					table.insert(parts, cell.Text)
				end
			end
			local badge = row:FindFirstChild("Badge")
			if badge ~= nil and (badge :: Frame).Visible then
				table.insert(parts, Drive.CONFIG.SCORE_FIRST_BADGE)
			end
			local gone = row:FindFirstChild("Left")
			if gone ~= nil and (gone :: Frame).Visible then
				table.insert(parts, "LEFT")
			end
			table.insert(out, table.concat(parts, " "))
		end
	end
	return out
end

function Hud.tiedBanner(): Frame?
	return tiedBanner
end

function Hud.isTiedBannerVisible(): boolean
	return tiedBanner ~= nil and tiedBanner.Visible
end

function Hud.tiedBannerText(): string
	return if tiedText then (tiedText :: TextLabel).Text else ""
end

-- ------------------------------------------------------------------ the start card (task 158)

function Hud.startCard(): Frame?
	return startCard
end

function Hud.isStartCardVisible(): boolean
	return startCard ~= nil and startCard.Visible
end

function Hud.startCardTitleText(): string
	return if startCardTitle then Style.unspaced(startCardTitle.Text) else ""
end

-- THE ROLE LINE, DRAWN. Its own accessor since 201 part 3: the eyebrow and the role are two labels
-- now (`DRIVE 1` over `YOU ARE A HUNTER`), because one line carrying both was the card's old
-- `DRIVE 1   YOU MAY SHOOT` -- two facts in one line, which is what the spec took apart.
function Hud.startCardRoleText(): string
	return if startCardRole then startCardRole.Text else ""
end

-- THE SECTION HEAD, DRAWN -- `WHAT TO SHOOT` or `WHAT TO DO`.
function Hud.startCardSectionText(): string
	return if startCardSectionWord then Style.unspaced(startCardSectionWord.Text) else ""
end

-- WHAT EACH DRAWN ROW SAYS, in order and only the visible ones: the glyph that is showing, the
-- words, and whatever is in the right-hand cell. The ONE accessor a spec reads the card's body
-- through, so a case asserts what is on the screen and not what a pure function returned.
function Hud.startCardRowText(): { { glyph: string, text: string, value: string } }
	local out = {}
	for _, parts in ipairs(startCardRowParts) do
		if not parts.row.Visible then
			continue
		end
		local glyph = ""
		for _, kind in ipairs(Style.GLYPHS) do
			local frame = parts.icons[kind]
			if frame ~= nil and frame.Visible then
				glyph = kind
			end
		end
		local value = ""
		if parts.value.Visible then
			value = parts.value.Text
		elseif parts.tag.Visible then
			-- A TAG'S WORD IS NOT LETTER-SPACED (§3.7 draws it plain), so it is read back plain.
			value = parts.tagText.Text
		elseif parts.word.Visible then
			value = Style.unspaced(parts.word.Text)
		end
		table.insert(out, { glyph = glyph, text = parts.text.Text, value = value })
	end
	return out
end

-- Only the lines actually showing something, in order -- the same shape as `Hud.scoreRowText`.
function Hud.startCardText(): { string }
	local out = {}
	for _, entry in ipairs(Hud.startCardRowText()) do
		table.insert(out, entry.text)
	end
	return out
end

-- THE COUNTDOWN AS ONE READABLE LINE, out of the TWO labels that draw it. The card's last line is
-- an instruction and a number at opposite ends of the card now (the spec's section 2), so a caller
-- that wants "what does the countdown say" is given the pair joined -- the shape every spec and
-- every console line already expects.
function Hud.startCardTimerText(): string
	if startCardTimer == nil or startCardSecondsLabel == nil then
		return ""
	end
	local label = Style.unspaced((startCardTimer :: TextLabel).Text)
	local seconds = (startCardSecondsLabel :: TextLabel).Text
	if label == "" and seconds == "" then
		return ""
	end
	return string.format("%s  %s", label, seconds)
end

function Hud.isHitMarkVisible(): boolean
	return hitMark ~= nil and hitMark.Visible
end

-- "hit", "kill", or nil when nothing is showing.
function Hud.hitMarkKind(): string?
	return hitKind
end

-- Whether this Hud is actually listening to the server's one-way marker remote.
function Hud.hitMarkerConnected(): boolean
	return markerConnection ~= nil and markerConnection.Connected
end

-- ...AND WHETHER IT IS LISTENING TO THE DRIVE (task 134), which is the same question for the bar, the
-- clock and the feed. Read by `tests/client/hud_boot.spec.luau`, and the one honest answer to "is
-- there going to be a drive bar this session".
function Hud.driveConnected(): boolean
	return matchConnected
end

local function arm(parent: Frame, name: string, size: UDim2, anchor: Vector2, position: UDim2, color: Color3)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.AnchorPoint = anchor
	frame.Position = position
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = frame
	frame.Parent = parent
	return frame
end

local function build(): ScreenGui
	local config = Shotgun.CONFIG
	local arms = config.CROSSHAIR_ARM_PX
	local gap = config.CROSSHAIR_GAP_PX
	local thick = config.CROSSHAIR_THICK_PX

	local screen = Instance.new("ScreenGui")
	screen.Name = "HunterHud"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 1

	local container = Instance.new("Frame")
	container.Name = "Crosshair"
	container.BackgroundTransparency = 1
	container.Size = UDim2.fromOffset(2 * (gap + arms), 2 * (gap + arms))
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Visible = false
	container.Parent = screen

	arm(
		container,
		"Top",
		UDim2.fromOffset(thick, arms),
		Vector2.new(0.5, 1),
		UDim2.new(0.5, 0, 0.5, -gap),
		config.CROSSHAIR_COLOR
	)
	arm(
		container,
		"Bottom",
		UDim2.fromOffset(thick, arms),
		Vector2.new(0.5, 0),
		UDim2.new(0.5, 0, 0.5, gap),
		config.CROSSHAIR_COLOR
	)
	arm(
		container,
		"Left",
		UDim2.fromOffset(arms, thick),
		Vector2.new(1, 0.5),
		UDim2.new(0.5, -gap, 0.5, 0),
		config.CROSSHAIR_COLOR
	)
	arm(
		container,
		"Right",
		UDim2.fromOffset(arms, thick),
		Vector2.new(0, 0.5),
		UDim2.new(0.5, gap, 0.5, 0),
		config.CROSSHAIR_COLOR
	)

	-- THE SCOPE'S RETICLE: the INSTANCES for every element any scope in this game draws -- a ring,
	-- a thin cross and four thick outer posts -- of which each one is drawn only if the weapon's own
	-- data carries it (task 146: Karen's cross has neither ring nor posts). Built from UI primitives
	-- with NO upload, exactly as the drive report's silhouette is.
	-- A SIBLING of the crosshair and of the hit marker, for the reason the hit marker
	-- is one: three marks, three questions, and no predicate that answers two of them.
	--
	-- EVERY SIZE IS IN DEGREES AND IS CONVERTED ONCE (`Hud.reticleDegToPx`). Roblox's field of view
	-- is VERTICAL, so `px = deg / fov * viewportY` is exact -- which is what makes one duplex true
	-- at any screen size AND at any magnification: change the scope's `aimFovDeg` and every element
	-- of the sight picture grows by exactly the magnification, as a real scope's does.
	-- THE SIGHT PICTURE (task 141): black everywhere except a round eyepiece, with the magnified
	-- world inside it. A SIBLING of the reticle and of the crosshair, for the reason they are
	-- siblings of each other -- a mark and a mask are two things, and no predicate answers for both.
	--
	-- THE MASK IS A `UIStroke` ON A CIRCLE, which is the one way to paint "everything except a
	-- circle" out of UI primitives with no upload: a `UICorner` of 0.5 scale makes the frame a
	-- circle, and a stroke is drawn OUTSIDE that border, so a stroke thicker than the screen's own
	-- diagonal fills the whole screen and leaves the circle untouched. The alternative needed an
	-- uploaded mask image, which needs Karen's OK and a moderation wait for a shape four lines of
	-- UI already make. MEASURED on screen -- see the frames in the request.
	local overlay = Instance.new("Frame")
	overlay.Name = "ScopeOverlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.AnchorPoint = Vector2.new(0.5, 0.5)
	overlay.Position = UDim2.fromScale(0.5, 0.5)
	overlay.ZIndex = SCOPE_Z
	overlay.Visible = false
	overlay.Parent = screen

	local mask = Instance.new("Frame")
	mask.Name = "Mask"
	mask.BackgroundTransparency = 1
	mask.AnchorPoint = Vector2.new(0.5, 0.5)
	mask.Position = UDim2.fromScale(0.5, 0.5)
	mask.Size = UDim2.fromOffset(2, 2)
	mask.ZIndex = SCOPE_Z
	mask.Parent = overlay
	local maskRound = Instance.new("UICorner")
	maskRound.CornerRadius = UDim.new(0.5, 0)
	maskRound.Parent = mask
	local maskEdge = Instance.new("UIStroke")
	maskEdge.Name = "Edge"
	maskEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	maskEdge.Thickness = 1
	maskEdge.Parent = mask

	-- The ocular lens's own rim, drawn INSIDE the circle: a stroke goes outward, so this frame is
	-- smaller than the mask by exactly its own thickness and its stroke lands against the mask's
	-- edge. Without it the sight picture ends on a hard mathematical line, which no glass does.
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.fromOffset(2, 2)
	rim.ZIndex = SCOPE_Z + 1
	rim.Parent = overlay
	local rimRound = Instance.new("UICorner")
	rimRound.CornerRadius = UDim.new(0.5, 0)
	rimRound.Parent = rim
	local rimEdge = Instance.new("UIStroke")
	rimEdge.Name = "Edge"
	rimEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rimEdge.Thickness = 1
	rimEdge.Parent = rim

	local reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.BackgroundTransparency = 1
	reticle.Size = UDim2.fromScale(1, 1)
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.fromScale(0.5, 0.5)
	-- ON TOP OF THE MASK, which is the whole point of a reticle: it is etched on the glass.
	reticle.ZIndex = RETICLE_Z
	reticle.Visible = false
	reticle.Parent = screen

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(2, 2)
	ring.Parent = reticle
	ring.ZIndex = RETICLE_Z
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = ring
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Thickness = 1
	edge.Parent = ring

	-- THE ILLUMINATED DOT (task 142), two frames: a soft halo and the core on top of it. Last in
	-- build order and highest in the stack, because it is the thing the eye goes to.
	for _, name in ipairs({ "DotHalo", "Dot" }) do
		local dot = Instance.new("Frame")
		dot.Name = name
		dot.BorderSizePixel = 0
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(1, 1)
		dot.ZIndex = if name == "Dot" then RETICLE_Z + 2 else RETICLE_Z + 1
		dot.Parent = reticle
		local dotRound = Instance.new("UICorner")
		dotRound.CornerRadius = UDim.new(0.5, 0)
		dotRound.Parent = dot
	end

	for _, piece in ipairs({
		{ name = "CrossTop", vertical = true, sign = -1, post = false },
		{ name = "CrossBottom", vertical = true, sign = 1, post = false },
		{ name = "CrossLeft", vertical = false, sign = -1, post = false },
		{ name = "CrossRight", vertical = false, sign = 1, post = false },
		{ name = "PostTop", vertical = true, sign = -1, post = true },
		{ name = "PostBottom", vertical = true, sign = 1, post = true },
		{ name = "PostLeft", vertical = false, sign = -1, post = true },
		{ name = "PostRight", vertical = false, sign = 1, post = true },
	}) do
		local bar = Instance.new("Frame")
		bar.Name = piece.name
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(0.5, 0.5)
		bar.Size = UDim2.fromOffset(1, 1)
		bar.ZIndex = RETICLE_Z
		bar.Parent = reticle
	end

	-- The hit marker: four diagonal arms around the centre, hidden until something lands. It is a
	-- sibling of the crosshair and not a child, because it must still show in ADS, where the
	-- crosshair is deliberately hidden (camera design section 6.2).
	local mark = Instance.new("Frame")
	mark.Name = "HitMark"
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromOffset(
		2 * (config.HIT_MARK_GAP_PX + config.HIT_MARK_ARM_PX),
		2 * (config.HIT_MARK_GAP_PX + config.HIT_MARK_ARM_PX)
	)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.Visible = false
	mark.Parent = screen

	local reach = config.HIT_MARK_GAP_PX + config.HIT_MARK_ARM_PX / 2
	for _, corner in ipairs({
		{ name = "TopLeft", x = -reach, y = -reach, rotation = 45 },
		{ name = "TopRight", x = reach, y = -reach, rotation = -45 },
		{ name = "BottomLeft", x = -reach, y = reach, rotation = -45 },
		{ name = "BottomRight", x = reach, y = reach, rotation = 45 },
	}) do
		local diagonal = arm(
			mark,
			corner.name,
			UDim2.fromOffset(config.HIT_MARK_THICK_PX, config.HIT_MARK_ARM_PX),
			Vector2.new(0.5, 0.5),
			UDim2.new(0.5, corner.x, 0.5, corner.y),
			config.HIT_MARK_COLOR
		)
		diagonal.Rotation = corner.rotation
	end

	-- ---------------------------------------------------------------- the status bar (surface 1)
	--
	-- ONE SLATE, FOUR OR FIVE STAT CHIPS AND A ROLE PILL (the system §3.9 / §5 surface 1). It was one
	-- 20 px line of `Enum.Font.Code` in a black outline: *"From one 20 px `Enum.Font.Code` line with
	-- a black stroke to chips on a slate. The clock becomes `STAT` Oswald 20, the biggest number on
	-- screen."*
	--
	-- THE FRAME IS STILL NAMED `DriveBar`. `tests/client/match_client.spec.luau` walks `PlayerGui`
	-- for that name and checks every ancestor's `Visible`, and that spec is in `TWO_PLAYER_PATHS`
	-- (CLAUDE.md), so renaming it would cost a two-player run for a word.
	--
	-- NO CHIP EVER WRAPS AND NO CHIP IS EVER SHRUNK (§3.9). Every label is `TextWrapped = false`, the
	-- slate is `AutomaticSize.X`, and when the row will not fit a WHOLE CHIP IS DROPPED -- the phone
	-- drops `COINS` during a drive (§4.2 item 1). Drawing the phone mockup found this the hard way:
	-- at 400 px the chips squeezed and each caption stacked one letter per line.
	local viewX = Hud.viewportX()
	local statusPhone = Style.isPhone(viewX)
	local status = Style.slate(screen, "DriveBar", false, statusPhone)
	status.AutomaticSize = Enum.AutomaticSize.X
	status.Size = UDim2.fromOffset(0, Hud.STATUS.HEIGHT)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.new(0.5, 0, 0, Hud.STATUS.TOP)
	status.ZIndex = Hud.STATUS.Z_INDEX
	status.Visible = false
	-- The slate's own padding, tighter than `Style.slate`'s default because the chips carry their
	-- own: 34 px of band less 4 leaves 30 for a chip, which is the phone step of §3.9.
	local statusPad = status:FindFirstChildOfClass("UIPadding")
	if statusPad then
		statusPad.PaddingTop = UDim.new(0, 2)
		statusPad.PaddingBottom = UDim.new(0, 2)
		statusPad.PaddingLeft = UDim.new(0, 2)
		statusPad.PaddingRight = UDim.new(0, 2)
	end
	local statusRow = Instance.new("UIListLayout")
	statusRow.FillDirection = Enum.FillDirection.Horizontal
	statusRow.VerticalAlignment = Enum.VerticalAlignment.Center
	statusRow.SortOrder = Enum.SortOrder.LayoutOrder
	statusRow.Padding = UDim.new(0, 0)
	statusRow.Parent = status
	-- A ceiling and never a width: the slate is the size of its chips, and this is the box §4.3
	-- rule 2 says it may not grow past -- the right column the minimap and the rail own, applied to
	-- both sides so it stays centred.
	local statusCap = Instance.new("UISizeConstraint")
	statusCap.Name = "MaxWidth"
	local _, _, statusMaxWidth = Hud.statusRect(Vector2.new(viewX, 1))
	statusCap.MaxSize = Vector2.new(statusMaxWidth, math.huge)
	statusCap.Parent = status

	table.clear(statusChips)
	table.clear(statusDividers)
	-- THE ORDER THEY ARE DRAWN IN, left to right, and it is the mockup's: which drive, the phase
	-- while there is one, the clock, how many boars are left, who you are, what you have.
	local order = { "Drive", "Phase", "Clock", "Boars", "Role", "Coins" }
	for index, name in ipairs(order) do
		if index > 1 then
			local divider = Style.chipDivider(status, "Divider" .. name)
			divider.LayoutOrder = index * 10 - 1
			divider.Visible = false
			table.insert(statusDividers, divider)
		end
		if name == "Role" then
			-- A ROLE IS AN IDENTITY, SO IT IS A PILL AND NOT A CHIP (§3.6, and §3.9's own table:
			-- *"a role -> the team colour, and the chip becomes a pill"*). Its colour is the only
			-- place a team is coloured on this bar, and `Style.teamColor` is the one reader of that
			-- mapping, so a pill, a roster and a map marker cannot disagree about whose orange it is.
			local pill, text = Style.pill(status, "Role", Style.LOOK.HUNTER, viewX)
			sized(text, "MICRO")
			pill.LayoutOrder = index * 10
			pill.Visible = false
			statusPill = pill
			statusPillText = text
			continue
		end
		local chip, value, caption = Style.statChip(status, name, viewX)
		chip.LayoutOrder = index * 10
		chip.Visible = false
		-- THE DRIVE NUMBER IS THE BAR'S EYEBROW AND NOT ONE OF ITS NUMBERS, so it is the one chip
		-- whose value takes the `HEADING` step. Decided here, before the branch below, so the
		-- registry and the label agree by construction rather than by index arithmetic.
		sized(value, if name == "Drive" then "HEADING" else "STAT")
		sized(caption, "MICRO")
		if name == "Drive" then
			-- THE ONE CHIP WHOSE CAPTION COMES FIRST, because the phrase is "DRIVE 1" and not
			-- "1 DRIVE". It is the bar's eyebrow (§3.4): the small word saying what kind of thing
			-- this screen is about, so it is `BRASS` and it is quieter than every number beside it.
			caption.LayoutOrder = 1
			caption.TextColor3 = Style.LOOK.BRASS
			value.TextColor3 = Style.LOOK.FIELD_MUTED
			value.TextSize = Style.sizeFor("HEADING", viewX)
			value.FontFace = Style.faceFor("HEADING")
		elseif name == "Coins" then
			-- THE COIN DISC (§3.10): a 14 px circle with the brass gradient, and the number beside
			-- it in `COIN_TEXT`. Money is the one thing brass means.
			local coin = Instance.new("Frame")
			coin.Name = "Coin"
			coin.BackgroundColor3 = Style.LOOK.BRASS
			coin.BorderSizePixel = 0
			coin.Size = UDim2.fromOffset(14, 14)
			coin.LayoutOrder = 1
			coin.ZIndex = chip.ZIndex + 1
			local disc = Instance.new("UICorner")
			disc.CornerRadius = UDim.new(0, 7)
			disc.Parent = coin
			local shine = Instance.new("UIGradient")
			shine.Rotation = 55
			shine.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Style.LOOK.BRASS_HI),
				ColorSequenceKeypoint.new(0.5, Style.LOOK.BRASS),
				ColorSequenceKeypoint.new(1, Style.LOOK.BRASS_LO),
			})
			shine.Parent = coin
			Style.stroke(coin, Color3.fromHex("6E5526"), 0)
			coin.Parent = chip
			statusCoin = coin
			value.TextColor3 = Style.LOOK.COIN_TEXT
		elseif name == "Phase" then
			-- A PHASE WORD IS "LATER / HOLDING", WHICH IS AMBER (§1.1), and it is a chip of its own
			-- rather than a word buried in a sentence.
			value.TextColor3 = Style.LOOK.AMBER
		end
		statusChips[name] = { chip = chip, value = value, caption = caption }
	end

	-- ---------------------------------------------------------------- the toast feed (surface 8)
	--
	-- EACH LINE IS ITS OWN SLATE WITH A MEANING DOT (§3.11), stacked UPWARD from the bottom left with
	-- a 6 px gap, each fading on its own. It was white monospace with a black stroke on bare sky.
	--
	-- `UIListLayout` WITH `VerticalAlignment = Bottom` AND `SortOrder = LayoutOrder`, so a feed of
	-- two lines sits on the bottom edge and a feed of five grows upward into the screen -- which is
	-- what "stacked bottom-up" means and what a fixed 20 px per slot could not do once a toast is
	-- `AutomaticSize` and therefore not all one height.
	local feed = Instance.new("Frame")
	feed.Name = "Feed"
	feed.BackgroundTransparency = 1
	feed.AnchorPoint = Vector2.new(0, 1)
	feed.Position = UDim2.new(0, Drive.CONFIG.FEED_LEFT_OFFSET, 1, -Drive.CONFIG.FEED_BOTTOM_OFFSET)
	feed.Size = UDim2.fromOffset(440, Hud.feedHeight())
	feed.ZIndex = Hud.STATUS.Z_INDEX
	feed.Parent = screen
	local feedStack = Instance.new("UIListLayout")
	feedStack.FillDirection = Enum.FillDirection.Vertical
	feedStack.HorizontalAlignment = Enum.HorizontalAlignment.Left
	feedStack.VerticalAlignment = Enum.VerticalAlignment.Bottom
	feedStack.SortOrder = Enum.SortOrder.LayoutOrder
	feedStack.Padding = UDim.new(0, Style.TOAST_GAP)
	feedStack.Parent = feed

	table.clear(feedLines)
	table.clear(feedToasts)
	table.clear(feedDots)
	for index = 1, Drive.CONFIG.FEED_LINES do
		local toast, dot, text = Style.toast(feed, string.format("Line%d", index), viewX, nil, feed.ZIndex)
		sized(text, "LABEL")
		toast.LayoutOrder = index
		toast.Visible = false
		table.insert(feedToasts, toast)
		table.insert(feedDots, dot)
		table.insert(feedLines, text)
	end

	-- THE RESULTS BOARD (surface 11), a CARD over the world at the gathering. Karen, task 159:
	-- *"showing image transperent with results table"* -- this IS that table, and since task 201
	-- part 2 it is built from §3.12's row: an eyebrow and a title, a column head, a section per
	-- ranking in its team's colour, one `TextLabel` per cell, and a footer counting the next drive
	-- in over a blaze bar.
	--
	-- `Hud.renderScore` is the one writer of every word in it AND of its height.
	local board = Style.card(screen, "ScorePanel", statusPhone)
	board.AnchorPoint = Vector2.new(0.5, 0.5)
	board.Position = UDim2.fromScale(0.5, 0.5)
	board.Size = UDim2.fromOffset(Hud.BOARD.WIDTH, Hud.boardHeight(0, 0, viewX))
	-- OVER THE FEED AND THE BAR, because it is the thing to read -- AND OVER THE SCOPE'S MASK
	-- (task 141): this is drawn at the centre of the screen, which is inside the eyepiece, so at the
	-- old 5 a player who could still hold the aim in `Scoring` would read a board cut off at the
	-- glass. Same class as the compass and the drive report: a panel the GAME put up outranks a
	-- sight picture, and it shares the report's own number for that reason.
	board.ZIndex = Report.CONFIG.PANEL_Z_INDEX
	board.Visible = false
	local boardBody = Hud.BOARD.WIDTH - 2 * Hud.BOARD.PADDING

	local _, boardEyebrow, boardTitle = Style.header(board, boardBody, viewX, false)
	local boardHeaderFrame = boardEyebrow.Parent :: Frame
	boardHeaderFrame.Size = UDim2.fromOffset(boardBody, Hud.BOARD.HEADER_H)
	boardEyebrow.Position = UDim2.fromOffset(0, 0)
	boardEyebrow.Size = UDim2.fromOffset(boardBody, 12)
	boardTitle.Position = UDim2.fromOffset(0, 14)
	boardTitle.Size = UDim2.fromOffset(boardBody, Hud.BOARD.HEADER_H - 18)
	sized(boardEyebrow, "MICRO")
	sized(boardTitle, "TITLE")

	-- THE COLUMN HEAD, its own row with the brass hairline under it (§3.12).
	local boardHead = Style.columnHead(board, "ColumnHead", viewX, boardBody, true)
	boardHead.Position = UDim2.fromOffset(0, Hud.BOARD.HEADER_H)
	for key, column in pairs(Hud.BOARD.COLUMNS) do
		if key == "badge" then
			continue
		end
		local cell = Style.cell(boardHead, key, viewX, column.x, column.w, column.right, "MICRO")
		cell.TextColor3 = Style.LOOK.FIELD_MUTED
		cell.Text = Style.spaced(if key == "rank" then "#" else string.upper(key))
		sized(cell, "MICRO")
	end

	-- THE BODY SCROLLS PAST 14 ROWS and is the size of its own content below that (§3.12). A
	-- `ScrollingFrame` and not a clipped Frame, because a roster of 16 in two rankings is 18 lines
	-- and the alternative is a board that silently drops the last of them.
	local boardScroll = Instance.new("ScrollingFrame")
	boardScroll.Name = "Body"
	boardScroll.BackgroundTransparency = 1
	boardScroll.BorderSizePixel = 0
	boardScroll.Position = UDim2.fromOffset(0, Hud.BOARD.HEADER_H + Style.rowHeight(viewX))
	boardScroll.Size = UDim2.fromOffset(boardBody, Style.rowHeight(viewX))
	boardScroll.CanvasSize = UDim2.fromOffset(0, 0)
	boardScroll.ScrollBarThickness = 3
	boardScroll.ScrollBarImageColor3 = Style.LOOK.BRASS
	boardScroll.ScrollBarImageTransparency = 0.5
	boardScroll.ZIndex = board.ZIndex + 1
	boardScroll.Parent = board

	-- ONE SLOT PER LINE THE BODY CAN EVER HOLD, built once and shown as the snapshot needs them --
	-- the arrangement every other surface in this Hud already has. A slot is a section HEAD or a
	-- ROW; which one it is, is decided per render, so a roster of one beater costs the same tree as
	-- a roster of sixteen.
	table.clear(scoreLines)
	table.clear(scoreHeads)
	table.clear(scoreCells)
	for index = 1, Drive.CONFIG.SCORE_ROWS_MAX do
		local head = Style.sectionHead(boardScroll, string.format("Head%d", index), viewX, boardBody)
		sized(head:FindFirstChild("Word") :: TextLabel, "MICRO")
		table.insert(scoreHeads, head)

		local row = Style.tableRow(boardScroll, string.format("Row%d", index), viewX, boardBody)
		local cells: { [string]: TextLabel } = {}
		for key, column in pairs(Hud.BOARD.COLUMNS) do
			if key == "badge" then
				continue
			end
			local cell = Style.cell(row, key, viewX, column.x, column.w, column.right)
			sized(cell, "HEADING")
			cells[key] = cell
		end
		-- THE BADGE IS A PILL AND THE LEAVER'S MARK IS A TAG, which is §3.6 against §3.7: `1st` is
		-- an IDENTITY (a rank) and `LEFT` is a STATE. Both are built and only one is ever shown.
		local badgeColumn = Hud.BOARD.COLUMNS.badge
		local badge, badgeText = Style.pill(row, "Badge", Style.LOOK.BRASS, viewX)
		badge.AnchorPoint = Vector2.new(0, 0.5)
		badge.Position = UDim2.new(0, badgeColumn.x, 0.5, 0)
		badge.Visible = false
		sized(badgeText, "MICRO")
		local gone, goneText = Style.tag(row, "Left", Style.LOOK.FAINT, viewX)
		gone.AnchorPoint = Vector2.new(0, 0.5)
		gone.Position = UDim2.new(0, badgeColumn.x, 0.5, 0)
		gone.Visible = false
		goneText.Text = Style.spaced("LEFT")
		sized(goneText, "MICRO")

		table.insert(scoreLines, row)
		table.insert(scoreCells, cells)
	end

	-- THE FOOTER: the words, the number, and a blaze bar draining over the countdown (§3.8). NO
	-- TWEEN -- it is a clock, and a bar that eases is a bar that lies.
	local boardFoot = Instance.new("Frame")
	boardFoot.Name = "Footer"
	boardFoot.BackgroundTransparency = 1
	boardFoot.BorderSizePixel = 0
	boardFoot.AnchorPoint = Vector2.new(0, 1)
	boardFoot.Position = UDim2.fromScale(0, 1)
	boardFoot.Size = UDim2.fromOffset(boardBody, Hud.BOARD.FOOTER_H)
	boardFoot.ZIndex = board.ZIndex + 1
	boardFoot.Parent = board

	local boardFooterWord = Style.label(boardFoot, "Word", "MICRO", viewX)
	boardFooterWord.Position = UDim2.fromOffset(0, 10)
	boardFooterWord.Size = UDim2.fromOffset(boardBody - 90, 14)
	boardFooterWord.TextColor3 = Style.LOOK.FIELD_MUTED
	sized(boardFooterWord, "MICRO")

	local boardFooterValue = Style.label(boardFoot, "Value", "DISPLAY", viewX)
	boardFooterValue.Position = UDim2.fromOffset(boardBody - 90, 0)
	boardFooterValue.Size = UDim2.fromOffset(90, 30)
	boardFooterValue.TextXAlignment = Enum.TextXAlignment.Right
	sized(boardFooterValue, "DISPLAY")

	local boardTrack, boardFill =
		Style.bar(boardFoot, "Countdown", Style.LOOK.BLAZE_LO, Style.LOOK.BLAZE, Style.LOOK.BLAZE_HI, 4)
	boardTrack.AnchorPoint = Vector2.new(0, 1)
	boardTrack.Position = UDim2.new(0, 0, 1, -8)
	boardTrack.Size = UDim2.new(1, 0, 0, 4)

	-- ---------------------------------------------------------------- THE START CARD
	--
	-- Task 158, AND REBUILT HERE TO THE DESIGNER'S OWN SPEC (`startcard-spec.md`, 2026-10-18, an
	-- amendment to `design-system.md` surface 10). Karen, having played that day: *"this message has
	-- to be improved maybe each from new line ask designer more user friendly"*.
	--
	-- WHAT IT WAS: a 440-wide panel of four 24 px lines of `Enum.Font.Code` with a black stroke, and
	-- the body was ONE SENTENCE from the server -- `WILD BOAR, POINTS: male 10, female 6, cub -10`.
	-- `startcard-before.png` is that card and the spec's section 0 lists its five faults: three
	-- prices in one run of commas, two words for one animal (`cub` and `piglet`), a penalty that
	-- looks like a price, a BEATER handed the hunter's shopping list, and the monospace §2 deleted.
	--
	-- WHAT IT IS: eight children in a `UIListLayout`, four rows of glyph + words + number, and one
	-- instruction per line. Every colour, face, radius and opacity is `Style`'s; every word and both
	-- layouts are `Drive.CONFIG`'s; the RULE -- which kinds are quarry and what each is worth -- is
	-- the server's, on the snapshot (`Match.quarryRows`). `Hud.renderStartCard` is the one writer.
	--
	-- THE LIST IS CENTRE-ALIGNED AND EVERY GAP IS A `UIPadding` (the spec's section 2: *"Padding 0 --
	-- every gap is a UIPadding below"*). Centred, because the two hairlines are FULL-BLEED: they are
	-- `2 x side` wider than the content box and a centred list overhangs it equally on both sides.
	local card = Style.card(screen, "StartCard")
	card.ZIndex = Report.CONFIG.PANEL_Z_INDEX
	card.Visible = false
	local cardPad = card:FindFirstChildOfClass("UIPadding")
	local cardList = Instance.new("UIListLayout")
	cardList.FillDirection = Enum.FillDirection.Vertical
	cardList.SortOrder = Enum.SortOrder.LayoutOrder
	cardList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardList.Padding = UDim.new(0, 0)
	cardList.Parent = card

	-- 1. THE EYEBROW. `DRIVE 1`, brass, letter-spaced -- the same pair (eyebrow over title) that
	-- names every surface in the game (§3.4).
	local cardTitle = sized(Style.label(card, "Eyebrow", "MICRO", viewX), "MICRO")
	cardTitle.LayoutOrder = 1
	cardTitle.TextColor3 = Style.LOOK.BRASS
	cardTitle.TextXAlignment = Enum.TextXAlignment.Left

	-- 2. THE ROLE, and it is the card's first second. In the team's colour at `DISPLAY`, which makes
	-- it the only coloured heading on screen -- so the player learns the two team colours here and
	-- reads the status pill, the roster and the map markers with them afterwards (the spec's §1.3).
	local cardRole = sized(Style.label(card, "Role", "DISPLAY", viewX), "DISPLAY")
	cardRole.LayoutOrder = 2
	cardRole.TextXAlignment = Enum.TextXAlignment.Left
	Style.padding(cardRole, 4, 0, 0, 0)

	-- 3 and 6. THE TWO HAIRLINES, each a transparent slot carrying its own gap above a 1 px rule.
	-- The gradient is the system's own: clear at both ends, so the line does not end in a hard stop
	-- against the card's edge.
	table.clear(startCardRules)
	for index = 1, 2 do
		local slot = Instance.new("Frame")
		slot.Name = string.format("Rule%d", index)
		slot.BackgroundTransparency = 1
		slot.BorderSizePixel = 0
		slot.LayoutOrder = if index == 1 then 3 else 6
		slot.ZIndex = card.ZIndex + 1
		slot.Parent = card

		local line = Instance.new("Frame")
		line.Name = "Line"
		line.BackgroundColor3 = Style.LOOK.BRASS
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0, 1)
		line.Position = UDim2.fromScale(0, 1)
		line.Size = UDim2.new(1, 0, 0, 1)
		line.ZIndex = slot.ZIndex
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.12, 0.58),
			NumberSequenceKeypoint.new(0.88, 0.58),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = line
		line.Parent = slot
		table.insert(startCardRules, slot)
	end

	-- 4. THE SECTION HEAD -- `WHAT TO SHOOT` or `WHAT TO DO` -- and it is `Style.sectionHead`, the
	-- same component the results board's `HUNTERS` / `BEATERS` bands use. `FIELD_MUTED` here: it
	-- labels a list on a card that already has one coloured heading, and §1.1 allows one.
	local cardSection, cardSectionWord, cardSectionRule =
		Style.sectionHead(card, "Section", viewX, 0, Style.LOOK.FIELD_MUTED)
	cardSection.LayoutOrder = 4
	cardSection.Visible = true
	cardSection.Size = UDim2.new(1, 0, 0, 21)
	sized(cardSectionWord, "MICRO")
	Style.padding(cardSection, 10, 0, 0, 0)

	-- 5. THE FOUR ROWS. `AutomaticSize = Y` over a vertical list, so a role with three rows draws
	-- three and the card does not reserve a fourth -- and an invisible row is ALSO given zero
	-- height, because `UIListLayout` is not relied on to skip it.
	local cardRows = Instance.new("Frame")
	cardRows.Name = "Rows"
	cardRows.BackgroundTransparency = 1
	cardRows.BorderSizePixel = 0
	cardRows.AutomaticSize = Enum.AutomaticSize.Y
	cardRows.Size = UDim2.fromScale(1, 0)
	cardRows.LayoutOrder = 5
	cardRows.ZIndex = card.ZIndex + 1
	cardRows.Parent = card
	Style.padding(cardRows, 6, 0, 0, 0)
	local rowsList = Instance.new("UIListLayout")
	rowsList.FillDirection = Enum.FillDirection.Vertical
	rowsList.SortOrder = Enum.SortOrder.LayoutOrder
	rowsList.Padding = UDim.new(0, 0)
	rowsList.Parent = cardRows

	table.clear(startCardRowParts)
	for index = 1, Drive.CONFIG.START_CARD_ROWS_MAX do
		local row = Instance.new("Frame")
		row.Name = string.format("Row%d", index)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, 24)
		row.LayoutOrder = index
		row.ZIndex = cardRows.ZIndex + 1
		row.Visible = false
		row.Parent = cardRows

		-- THE CELLS ARE AN x AND A WIDTH, which is §3.12's own idiom (*"the numbers line up because
		-- they are PLACED"*) and not the spec's `UIListLayout` + slack: "take the rest of the width"
		-- needs a `UIFlexItem`, which nothing in this repo uses and which I have not proved in this
		-- Studio version. The picture is the same and the arithmetic is testable without a frame
		-- (`Hud.startCardTextWidth`).
		local icon = Instance.new("Frame")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.BorderSizePixel = 0
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.fromScale(0, 0.5)
		icon.Size = UDim2.fromOffset(16, 16)
		icon.ZIndex = row.ZIndex + 1
		icon.Parent = row

		-- ALL FOUR GLYPHS ARE BUILT AND ONE IS SHOWN. A renderer that made instances per frame is
		-- the one thing a HUD must not do, and the board's badge/tag pair already works this way.
		local icons: { [string]: Frame } = {}
		for _, kind in ipairs(Style.GLYPHS) do
			local glyph = Style.glyph(icon, kind, kind, 16)
			glyph.Position = UDim2.fromScale(0, 0)
			glyph.Visible = false
			icons[kind] = glyph
		end

		local text = sized(Style.label(row, "Text", "BODY", viewX), "BODY")
		text.Position = UDim2.fromOffset(28, 0)
		text.Size = UDim2.new(0, 1, 1, 0)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextTruncate = Enum.TextTruncate.AtEnd
		text.TextColor3 = Style.LOOK.BODY

		-- THE RIGHT-HAND CELL IS THREE THINGS IN ONE SLOT, and exactly one of them is ever shown: a
		-- signed NUMBER (the hunter's price), a TAG (`NEEDS LICENCE`, §3.7), or a WORD (`DRIVE OVER`,
		-- a cost that is not points). All three are right-aligned to the same edge.
		local value = sized(Style.label(row, "Value", "HEADING", viewX), "HEADING")
		value.AnchorPoint = Vector2.new(1, 0.5)
		value.Position = UDim2.fromScale(1, 0.5)
		value.Size = UDim2.new(0, 40, 1, 0)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.Visible = false

		local word = sized(Style.label(row, "Word", "MICRO", viewX), "MICRO")
		word.AnchorPoint = Vector2.new(1, 0.5)
		word.Position = UDim2.fromScale(1, 0.5)
		word.AutomaticSize = Enum.AutomaticSize.X
		word.Size = UDim2.fromScale(0, 1)
		word.TextXAlignment = Enum.TextXAlignment.Right
		word.TextColor3 = Style.LOOK.CLAY
		word.Visible = false

		local tag, tagText = Style.tag(row, "Tag", Style.LOOK.AMBER, viewX)
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.fromScale(1, 0.5)
		tag.Visible = false
		sized(tagText, "MICRO")

		table.insert(startCardRowParts, {
			row = row,
			icons = icons,
			text = text,
			value = value,
			word = word,
			tag = tag,
			tagText = tagText,
		})
	end

	-- 7. THE COUNTDOWN: the instruction on the left, the number on the right. The role and the
	-- seconds are the only two things at `DISPLAY` -- the card's two answers, WHO AM I and HOW LONG
	-- HAVE I GOT -- and they sit at opposite corners so they never compete (the spec's section 2).
	local cardCount = Instance.new("Frame")
	cardCount.Name = "Countdown"
	cardCount.BackgroundTransparency = 1
	cardCount.BorderSizePixel = 0
	cardCount.Size = UDim2.new(1, 0, 0, 41)
	cardCount.LayoutOrder = 7
	cardCount.ZIndex = card.ZIndex + 1
	cardCount.Parent = card
	Style.padding(cardCount, 11, 0, 0, 0)

	local cardTimer = sized(Style.label(cardCount, "Label", "MICRO", viewX), "MICRO")
	cardTimer.AnchorPoint = Vector2.new(0, 1)
	cardTimer.Position = UDim2.fromScale(0, 1)
	cardTimer.Size = UDim2.new(0.7, 0, 0, 14)
	cardTimer.TextColor3 = Style.LOOK.FIELD_MUTED
	cardTimer.TextXAlignment = Enum.TextXAlignment.Left
	cardTimer.TextYAlignment = Enum.TextYAlignment.Bottom
	-- 3 px of bottom padding, so the word sits on the number's baseline and not on the card's.
	Style.padding(cardTimer, 0, 3, 0, 0)

	local cardSeconds = sized(Style.label(cardCount, "Seconds", "DISPLAY", viewX), "DISPLAY")
	cardSeconds.AnchorPoint = Vector2.new(1, 1)
	cardSeconds.Position = UDim2.fromScale(1, 1)
	cardSeconds.Size = UDim2.fromScale(0.3, 1)
	cardSeconds.TextXAlignment = Enum.TextXAlignment.Right
	cardSeconds.TextYAlignment = Enum.TextYAlignment.Bottom

	-- 8. THE BAR (§3.8), in a slot that carries its gap above it. NO TWEEN: it is a clock, and a
	-- tweened clock lies about the time for the length of the tween.
	local cardBarSlot = Instance.new("Frame")
	cardBarSlot.Name = "Bar"
	cardBarSlot.BackgroundTransparency = 1
	cardBarSlot.BorderSizePixel = 0
	cardBarSlot.Size = UDim2.new(1, 0, 0, 12)
	cardBarSlot.LayoutOrder = 8
	cardBarSlot.ZIndex = card.ZIndex + 1
	cardBarSlot.Parent = card

	local cardTrack, cardFill =
		Style.bar(cardBarSlot, "Track", Style.LOOK.BLAZE_LO, Style.LOOK.BLAZE, Style.LOOK.BLAZE_HI, 4)
	cardTrack.AnchorPoint = Vector2.new(0, 1)
	cardTrack.Position = UDim2.fromScale(0, 1)
	cardTrack.Size = UDim2.new(1, 0, 0, 4)

	-- The tied banner, for the local player alone and only while they are tied. The comedy is the
	-- point and so is the teaching: it says what they did.
	-- ...AND IT IS ONE CENTRED CLAY TOAST SINCE TASK 201 PART 2 (§5 surface 13). It was
	-- `#FF5F4B` monospace 24 on bare sky; it is a REFUSAL, so it is clay, and it uses the component
	-- every other refusal in the game uses -- at the `TITLE` step, because it is the one notice
	-- that has to be read at a glance while something is happening to you.
	--
	-- `Hud.tiedBanner()` answers this FRAME now and not a `TextLabel`: `zz_tie_to_a_tree.spec` walks
	-- its ancestors for `Visible` and asks nothing about its class.
	-- THE BAND GOES IN AT BUILD TIME (round 1, finding 3). `screen` is a `ScreenGui` and not a
	-- `GuiObject`, so there was nothing for the toast to inherit and its dot and its words were
	-- created under a slate that was raised a line later.
	local tied, tiedDot, tiedText_ = Style.toast(screen, "TiedBanner", viewX, "TITLE", Hud.STATUS.Z_INDEX + 1)
	tied.AnchorPoint = Vector2.new(0.5, 0)
	tied.Position = UDim2.new(0.5, 0, 0, Drive.CONFIG.TIED_TOP_OFFSET)
	tied.Visible = false
	tiedDot.BackgroundColor3 = Style.LOOK.CLAY
	tiedText_.TextColor3 = Style.LOOK.CLAY
	sized(tiedText_, "TITLE")

	-- THE COMPASS (task 125). Karen: *"we need to indicate from what side drive is comming"*. Top
	-- centre, thin, and built empty -- `Compass.start` fills it and this file writes nothing inside.
	--
	-- IT IS A QUIET SLATE SINCE TASK 201 (§3.3): corner 11, a brass hairline at 0.55, and the
	-- charcoal every other field surface uses. It carries 10-11 px type, which is what the QUIET
	-- variant exists for. Its width follows the viewport (`Compass.widthFor`): 420 on a desktop so
	-- a 120 degree span is not cramped, `screenW - 24` on a phone so it is not wider than the screen.
	local compass = Instance.new("Frame")
	compass.Name = "Compass"
	compass.BackgroundColor3 = Compass.CONFIG.BACKGROUND
	compass.BackgroundTransparency = Compass.CONFIG.TRANSPARENCY
	compass.BorderSizePixel = 0
	compass.AnchorPoint = Vector2.new(0.5, 0)
	compass.Position = UDim2.new(0.5, 0, 0, Compass.CONFIG.TOP)
	compass.Size = UDim2.fromOffset(Compass.widthFor(viewX), Compass.CONFIG.HEIGHT)
	Style.corner(compass, Style.RADIUS.ROW)
	Style.stroke(compass, Style.LOOK.BRASS, Style.EDGE_T.SLATE)
	compass.ZIndex = Compass.CONFIG.Z_INDEX
	compass.ClipsDescendants = true -- a mark that has scrolled off the end must not spill onto the sky
	compass.Visible = false
	compass.Parent = screen

	-- THE REPORT, over everything: it is a thing you stop and read. Empty and hidden until
	-- `ReportPanel.start` fills it -- this file creates the box and writes nothing inside it.
	-- THE MODAL'S SCRIM (§1.3: *"A modal lays `SCRIM` over the whole screen at 0.42"*). Built here
	-- with the rest of the screen and written by `ReportPanel`, which owns whether the report is
	-- open -- the division the panel itself already has. A non-modal surface lays NO scrim: the
	-- results board is a field surface and carries its own card.
	local reportScrim = Instance.new("Frame")
	reportScrim.Name = "ReportScrim"
	reportScrim.BackgroundColor3 = Style.LOOK.SCRIM
	reportScrim.BackgroundTransparency = Style.SCRIM_T
	reportScrim.BorderSizePixel = 0
	reportScrim.Size = UDim2.fromScale(1, 1)
	reportScrim.Position = UDim2.fromScale(0.5, 0.5)
	reportScrim.AnchorPoint = Vector2.new(0.5, 0.5)
	reportScrim.ZIndex = Report.CONFIG.PANEL_Z_INDEX - 1
	reportScrim.Visible = false
	reportScrim.Parent = screen

	local report = Instance.new("Frame")
	report.Name = "ReportPanel"
	report.BackgroundColor3 = Report.CONFIG.PANEL_COLOR
	report.BackgroundTransparency = Report.CONFIG.PANEL_TRANSPARENCY
	report.BorderSizePixel = 0
	report.AnchorPoint = Vector2.new(0.5, 0.5)
	report.Position = UDim2.fromScale(0.5, 0.5)
	report.Size = UDim2.fromOffset(Report.CONFIG.PANEL_WIDTH, Report.CONFIG.PANEL_HEIGHT)
	report.ZIndex = Report.CONFIG.PANEL_Z_INDEX
	report.Visible = false
	report.Parent = screen

	-- THE HIT CARD (task 198), in the LOWER LEFT, stacked on top of the event feed. Karen,
	-- 2026-10-16: *"so somewhere in corner after hit we indicate where it landed"*.
	--
	-- WHY THAT CORNER AND NOT ANOTHER: the minimap and the button rail own the top right, the ammo
	-- readout owns the very bottom right (`Readout`, anchored (1,1) at -16, -16), and the whole top
	-- band is the objective line (y 8), the drive bar (y 44) and the compass (y 108, 360 px wide,
	-- which on a 400 px phone is the entire width). What is left is the bottom left, where the
	-- player already looks for what just happened -- the kill feed -- so the card sits directly on
	-- top of it. Its bottom is computed from the FEED's own two constants, so the two cannot overlap
	-- at any viewport instead of being eyeballed at one.
	local hitCard = Instance.new("Frame")
	hitCard.Name = "HitCard"
	hitCard.BackgroundColor3 = Report.CONFIG.CARD.PANEL_COLOR
	hitCard.BackgroundTransparency = Report.CONFIG.CARD.PANEL_TRANSPARENCY
	hitCard.BorderSizePixel = 0
	hitCard.AnchorPoint = Vector2.new(0, 1)
	hitCard.Position = UDim2.new(
		0,
		Report.CONFIG.CARD.MARGIN_LEFT,
		1,
			-- THE FEED'S OWN HEIGHT AND NOT A SECOND COPY OF IT (task 201). A toast is `AutomaticSize`
			-- and taller than the 20 px line it replaces, so this reads `Hud.feedHeight` -- the one
			-- number the feed frame is built from, and since round 2 the REAL height of five toasts
			-- and their four gaps rather than a guess at it.
		-(Drive.CONFIG.FEED_BOTTOM_OFFSET + Hud.feedHeight() + Report.CONFIG.CARD.FEED_GAP)
	)
	hitCard.Size = UDim2.fromOffset(Report.CONFIG.CARD.WIDTH, Report.CONFIG.CARD.HEIGHT)
	hitCard.ZIndex = Report.CONFIG.CARD.Z_INDEX
	hitCard.Visible = false
	hitCard.Parent = screen

	-- THE SHOP (task 178, two columns since task 196). Karen: *"Hunting house where inside can shop
	-- things"*, and 2026-10-15: *"side menu with click and then shows in right side image and
	-- explanation what is that"*. Centred, and AS BIG AS THE SCREEN ALLOWS between the panel's own
	-- bounds -- 640 px on a monitor, 376 on a 400 px phone -- which is `ShopPanel.panelSize()`, the
	-- panel's own pure arithmetic. Empty and hidden until `ShopPanel.start` fills it. This file
	-- creates the box from that one number and writes nothing inside it; after `build` the panel is
	-- the only writer of its `Visible` AND of its `Size`, because the size now follows the screen.
	local shop = Instance.new("Frame")
	shop.Name = "ShopPanel"
	shop.BackgroundColor3 = ShopPanel.LOOK.PANEL
	shop.BackgroundTransparency = 0
	shop.BorderSizePixel = 0
	shop.AnchorPoint = Vector2.new(0.5, 0.5)
	shop.Position = UDim2.fromScale(0.5, 0.5)
	shop.Size = ShopPanel.panelSize()
	shop.ZIndex = Shop.CONFIG.PANEL.Z_INDEX
	shop.Visible = false
	shop.Parent = screen

	-- THE TRUCK PADS' SIZE DIALOG (task 182). Karen: *"you come to truck back rectangle and can click
	-- and select how many players"*. Centred, 300 wide so it fits the 400 px phone
	-- `hud_clarity.spec` measures, empty and hidden until `PadPanel.start` fills it. This file
	-- creates the box and writes nothing inside it, and after `build` it does not write the `Visible`
	-- either.
	--
	-- THE RECTANGLE COMES FROM THE PANEL AND NOT FROM A SECOND READER OF `Lobby.CONFIG`, which is
	-- `ShopPanel.panelSize`'s own arrangement: ONE function decides both the rows and the box.
	local padDialog = Instance.new("Frame")
	padDialog.Name = "PadPanel"
	padDialog.BackgroundColor3 = PadPanel.LOOK.PANEL_COLOR
	padDialog.BackgroundTransparency = 0
	padDialog.BorderSizePixel = 0
	padDialog.AnchorPoint = Vector2.new(0.5, 0.5)
	padDialog.Position = UDim2.fromScale(0.5, 0.5)
	padDialog.Size = UDim2.fromOffset(PadPanel.widthFor(), PadPanel.heightFor())
	padDialog.ZIndex = PadPanel.zIndex()
	padDialog.Visible = false
	padDialog.Parent = screen

	-- ...AND THE LOADING BANNER (task 197). KAREN, 2026-10-15: *"we need clear message that game is
	-- loading once clicked 1/1 or other now is delay"*. The same division as the dialog above it:
	-- this file creates the box, `Hud.PadPanel` fills it and owns its `Visible`, and the two can never
	-- be up together. FULL WIDTH less a margin, capped inside the panel so a wide screen gets a
	-- banner rather than a letterbox -- a SCALE, so nothing has to re-measure on a resize.
	local padLeaving = Instance.new("Frame")
	padLeaving.Name = "PadLeaving"
	padLeaving.BackgroundColor3 = PadPanel.LOOK.LEAVING_COLOR
	padLeaving.BackgroundTransparency = 0
	padLeaving.BorderSizePixel = 0
	padLeaving.AnchorPoint = Vector2.new(0.5, 0.5)
	padLeaving.Position = PadPanel.leavingPosition()
	padLeaving.Size = PadPanel.leavingSize()
	padLeaving.ZIndex = PadPanel.leavingZIndex()
	padLeaving.Visible = false
	padLeaving.Parent = screen

	-- THE MAP (task 155). Karen: *"small map in left or right corner circle like is on another
	-- games"* and *"a map when click M"*. Two frames and a button, created empty and filled by
	-- `MapUi` -- the same division the compass and the report panel already have.
	--
	-- THE ROUND ONE IS A SQUARE FRAME WITH A `UICorner` OF HALF ITS SIDE, which is how a circle is
	-- drawn in Roblox GUI without an uploaded image. `ClipsDescendants` is what keeps the road
	-- inside it; whether the engine clips to the ROUNDED rect or to the square is the one thing an
	-- Architect run could not verify, so screenshot 1 of this task is the check (design section 17).
	local miniMap = Instance.new("Frame")
	miniMap.Name = "MiniMap"
	miniMap.BackgroundColor3 = MapUi.CONFIG.BACKGROUND
	miniMap.BackgroundTransparency = MapUi.CONFIG.MINIMAP_TRANSPARENCY
	miniMap.BorderSizePixel = 0
	miniMap.AnchorPoint = Vector2.new(1, 0)
	miniMap.Position = UDim2.new(1, -MapUi.CONFIG.MINIMAP_MARGIN, 0, MapUi.CONFIG.MINIMAP_TOP)
	miniMap.Size = UDim2.fromOffset(MapUi.CONFIG.MINIMAP_DIAMETER_PX, MapUi.CONFIG.MINIMAP_DIAMETER_PX)
	miniMap.ZIndex = MapUi.CONFIG.Z_INDEX
	miniMap.ClipsDescendants = true
	miniMap.Visible = false
	local miniCorner = Instance.new("UICorner")
	miniCorner.CornerRadius = UDim.new(0.5, 0)
	miniCorner.Parent = miniMap
	local miniRim = Instance.new("UIStroke")
	miniRim.Thickness = MapUi.CONFIG.RIM_THICKNESS
	miniRim.Color = MapUi.CONFIG.RIM_COLOR
	miniRim.Transparency = 0.25
	miniRim.Parent = miniMap
	miniMap.Parent = screen

	-- THE FULL MAP, top-anchored at the same line as the minimap so it clears the compass above it
	-- and the ammo readout below it at every viewport. Its size is written by `MapUi` from the
	-- world's own span -- a wide, shallow world gets a wide, shallow panel -- so the offset here is
	-- only what it starts at.
	local fullMap = Instance.new("Frame")
	fullMap.Name = "FullMap"
	fullMap.BackgroundColor3 = MapUi.CONFIG.BACKGROUND
	fullMap.BackgroundTransparency = MapUi.CONFIG.PANEL_TRANSPARENCY
	fullMap.BorderSizePixel = 0
	fullMap.AnchorPoint = Vector2.new(0.5, 0)
	fullMap.Position = UDim2.new(0.5, 0, 0, MapUi.CONFIG.FULL_TOP)
	fullMap.Size = UDim2.fromOffset(MapUi.CONFIG.FULL_MAX_WIDTH_PX, MapUi.CONFIG.FULL_MAX_HEIGHT_PX)
	fullMap.ZIndex = MapUi.CONFIG.Z_INDEX
	fullMap.Visible = false
	local fullRim = Instance.new("UIStroke")
	fullRim.Thickness = 1
	fullRim.Color = MapUi.CONFIG.RIM_COLOR
	fullRim.Transparency = 0.4
	fullRim.Parent = fullMap
	fullMap.Parent = screen

	-- THE MAP'S LEGEND (task 165), a frame of the map's inside the map's own panel: created here
	-- with everything else and filled by `MapUi.legendRows` -- the division the two map frames, the
	-- compass strip and the report panel all already have.
	local legend = Instance.new("Frame")
	legend.Name = "MapLegend"
	legend.BackgroundTransparency = 1
	legend.AnchorPoint = Vector2.new(1, 1)
	legend.Size = UDim2.fromOffset(MapUi.CONFIG.LEGEND_WIDTH_PX, MapUi.CONFIG.LEGEND_HEIGHT_PX)
	legend.ZIndex = MapUi.CONFIG.Z_INDEX + 1
	legend.Visible = false
	legend.Parent = fullMap

	-- ---------------------------------------------------------------- task 165: the objective line
	--
	-- THE TOP LINE OF THE SCREEN, AND THE FIRST THING READ. Karen, 2026-10-12: *"we need to improve
	-- design that it will be clear to understand what happening"*. Everything else in this Hud is a
	-- FACT; this is the only INSTRUCTION, so it is the biggest text in the band and it is at the top
	-- of it (`docs/design/hud-clarity.md` section 3).
	--
	-- Created empty. `Objective` is the one writer of its text, its size and its `Visible`.
	--
	-- IT SITS ON A SLATE SINCE TASK 201 (§2, §5 surface 2). BOTH the slate and the label inside it
	-- are the size of the sentence and nothing more -- *"a band that touches both edges is a
	-- letterbox, and this game is played in first person"* -- which is exactly why
	-- `hud_clarity.spec`'s `TextFits` probe clones the label with `AutomaticSize.None` and
	-- `Objective.lineRect`'s width: what that case measures is the BAND the slate may not exceed,
	-- and an auto-sizing clone would report `TextFits` true for any string.
	-- `Objective` is the one writer of both `Visible`s.
	local objectiveBack = Style.slate(screen, "ObjectiveSlate", false, statusPhone)
	objectiveBack.AutomaticSize = Enum.AutomaticSize.XY
	objectiveBack.Size = UDim2.fromOffset(0, 0)
	objectiveBack.AnchorPoint = Vector2.new(0.5, 0)
	objectiveBack.Position = UDim2.new(0.5, 0, 0, Objective.CONFIG.TOP)
	objectiveBack.ZIndex = Objective.CONFIG.Z_INDEX
	objectiveBack.Visible = false

	local objective = Instance.new("TextLabel")
	objective.Name = "ObjectiveLine"
	objective.BackgroundTransparency = 1
	objective.BorderSizePixel = 0
	-- OSWALD MEDIUM, SENTENCE CASE, `PAPER` (§5 surface 2). A sentence is never uppercase: the
	-- objective line, the blurb and the toast feed stay exactly as Karen wrote them.
	objective.FontFace = Style.FONT.OSWALD_MD
	objective.TextScaled = false
	objective.TextWrapped = false
	objective.AutomaticSize = Enum.AutomaticSize.X
	objective.TextSize = Objective.CONFIG.TEXT_SIZE
	objective.TextColor3 = Objective.CONFIG.TEXT_COLOR
	objective.TextXAlignment = Enum.TextXAlignment.Center
	-- FULL WIDTH LESS A MARGIN, IN SCALE, so a 400 px phone gets 368 px of sentence and a 1080p
	-- screen gets 1888 -- the one thing a fixed `fromOffset` width could not do, and the reason
	-- `Objective.lineRect` is pure and asserted at three viewports.
	objective.AnchorPoint = Vector2.new(0, 0)
	objective.Position = UDim2.fromOffset(0, 0)
	objective.Size = UDim2.fromOffset(0, Objective.CONFIG.HEIGHT - 12)
	objective.ZIndex = Objective.CONFIG.Z_INDEX + 1
	objective.Text = ""
	objective.Visible = false
	-- AND NO BLACK OUTLINE (§2). The slate behind it is what makes it readable over a sunlit wood,
	-- and it was measured: `PAPER` on `SLATE` at 0.18 is 10.7 : 1 over the brightest sky this engine
	-- makes, against the 4.5 : 1 floor.
	objective.Parent = objectiveBack

	-- ...AND THE WAYPOINT: a chevron over the world, and its word with the distance under it.
	--
	-- A ROTATED SQUARE, WHICH IS A CHEVRON WITH NO ASSET -- the hit marker's own technique. Small on
	-- purpose: theHunter: Call of the Wild's players ask for theirs to be smaller (*"massive and
	-- orange"*), and this one has a whole screen to cross.
	--
	-- UNDER THE FURNITURE AND OVER THE WORLD (`MARK_Z_INDEX` 5): a mark that travels the screen must
	-- pass BEHIND the compass and the map rather than scribble on them.
	local waypoint = Instance.new("Frame")
	waypoint.Name = "Waypoint"
	waypoint.AnchorPoint = Vector2.new(0.5, 0.5)
	waypoint.Size = UDim2.fromOffset(Objective.CONFIG.MARK_PX, Objective.CONFIG.MARK_PX)
	waypoint.Position = UDim2.fromScale(0.5, 0.5)
	waypoint.BackgroundColor3 = Objective.CONFIG.MARK_COLOR
	waypoint.BorderSizePixel = 0
	waypoint.Rotation = 45
	waypoint.ZIndex = Objective.CONFIG.MARK_Z_INDEX
	waypoint.Visible = false
	local waypointStroke = Instance.new("UIStroke")
	waypointStroke.Thickness = 1
	waypointStroke.Color = Color3.new(0, 0, 0)
	waypointStroke.Parent = waypoint
	waypoint.Parent = screen

	-- THE WORD AND THE DISTANCE, A SIBLING AND NOT A CHILD. A child would inherit the chevron's
	-- 45-degree `Rotation` and read at an angle, which is the kind of thing only a screenshot finds.
	local waypointLabel = Instance.new("TextLabel")
	waypointLabel.Name = "WaypointWord"
	waypointLabel.BackgroundTransparency = 1
	waypointLabel.Font = Enum.Font.Code
	waypointLabel.TextSize = Objective.CONFIG.MARK_LABEL_SIZE
	waypointLabel.TextColor3 = Objective.CONFIG.MARK_COLOR
	waypointLabel.AnchorPoint = Vector2.new(0.5, 0)
	waypointLabel.Position = UDim2.fromScale(0.5, 0.5)
	waypointLabel.Size = UDim2.fromOffset(140, Objective.CONFIG.MARK_LABEL_SIZE + 4)
	waypointLabel.ZIndex = Objective.CONFIG.MARK_Z_INDEX
	waypointLabel.Text = ""
	waypointLabel.Visible = false
	local waypointWordStroke = Instance.new("UIStroke")
	waypointWordStroke.Thickness = 1
	waypointWordStroke.Color = Color3.new(0, 0, 0)
	waypointWordStroke.Parent = waypointLabel
	waypointLabel.Parent = screen

	-- ...AND THE BUTTON RAIL, right edge, under the minimap. Karen: *"could be buttons on the side
	-- for M - map ect"*. Created empty: `Rail` builds the buttons inside it and is the one writer of
	-- every one of them. Its `Position` is rewritten by `MapUi.applyLayout`, because the rail hangs
	-- below the minimap and the minimap's RENDERED diameter is 150 on a screen and 96 on a phone.
	local rail = Instance.new("Frame")
	rail.Name = "Rail"
	rail.BackgroundTransparency = 1
	rail.AnchorPoint = Vector2.new(1, 0)
	rail.Position =
		UDim2.new(1, -Rail.CONFIG.MARGIN, 0, Rail.topFor(MapUi.CONFIG.MINIMAP_DIAMETER_PX, MapUi.CONFIG.MINIMAP_TOP))
	rail.Size = UDim2.fromOffset(Rail.CONFIG.BUTTON_PX, Rail.heightFor(#Rail.BUTTONS))
	rail.ZIndex = Rail.CONFIG.Z_INDEX
	rail.Visible = false
	rail.Parent = screen

	-- ---------------------------------------------------------------- the corner (surfaces 6 and 7)
	--
	-- BOTTOM RIGHT, AND ONLY ONE OF THE TWO IS EVER DRAWN (§4.3: *"BOTTOM RIGHT ammo chip OR horn
	-- chip -- alone, and only one of the two ever exists"*). A hunter carries a gun and no horn; a
	-- beater carries a horn and no gun. `Hud.renderCorner` is the one writer of both.
	--
	-- THE AMMO CHIP (§5 surface 6): `[*]* BUCK 12 R` in monospace becomes two CHAMBER PIPS -- Frames,
	-- live `PAPER`, spent `LINE`, the selected one underlined in `BLAZE_HI` (§3.10) -- then the
	-- pocket at `STAT`, then the shell word at `MICRO` spaced, and the `R` becomes a reload bar
	-- across the chip's bottom.
	local ammo = Style.slate(screen, "Readout", false, statusPhone)
	ammo.AutomaticSize = Enum.AutomaticSize.X
	ammo.Size = UDim2.fromOffset(0, if statusPhone then 42 else 46)
	ammo.AnchorPoint = Vector2.new(1, 1)
	ammo.Position = UDim2.new(1, -Style.MARGIN, 1, -Style.MARGIN)
	ammo.ZIndex = Hud.STATUS.Z_INDEX
	ammo.Visible = false
	-- THE ROW LIVES IN ITS OWN FRAME AND THE BAR SITS BESIDE IT, and that is not tidiness.
	-- `UIListLayout` lays out EVERY visible child and has no opt-out, so a Scale-width bar dropped
	-- into the row stretches the row -- measured, as the horn's cooldown bar running the whole
	-- width of the screen (`20261017T133631Z-t201-beater-running-2.png`). With the row in a frame
	-- of its own the slate measures the row (`AutomaticSize` ignores a child sized in Scale) and
	-- the bar spans whatever the row came to.
	local ammoBodyRow = Instance.new("Frame")
	ammoBodyRow.Name = "Content"
	ammoBodyRow.BackgroundTransparency = 1
	ammoBodyRow.BorderSizePixel = 0
	-- EXACTLY THE SHAPE THE STATUS BAR'S CHIPS ALREADY HAVE, and that is why it is this shape:
	-- `AutomaticSize.X` with the HEIGHT in scale, measured three levels deep (slate -> chip ->
	-- label) and demonstrably coming out at the width of its own words. The row and the bar below
	-- it are siblings, and the bar is sized and positioned in pure OFFSETS -- a scale-width or
	-- scale-x-positioned bar and the box that measures it chase each other, which is what made the
	-- horn chip 430 px wide (`...134503Z-t201c-beater-cooldown.png`).
	ammoBodyRow.AutomaticSize = Enum.AutomaticSize.X
	ammoBodyRow.Size = UDim2.fromScale(0, 1)
	ammoBodyRow.ZIndex = ammo.ZIndex + 1
	ammoBodyRow.Parent = ammo
	local ammoRow = Instance.new("UIListLayout")
	ammoRow.FillDirection = Enum.FillDirection.Horizontal
	ammoRow.VerticalAlignment = Enum.VerticalAlignment.Center
	ammoRow.SortOrder = Enum.SortOrder.LayoutOrder
	ammoRow.Padding = UDim.new(0, 7)
	ammoRow.Parent = ammoBodyRow

	-- THE SHELL (task 204), AT THE HEAD OF THE ROW. Karen, 2026-10-18: *"please diferenciate slug
	-- from shells"*. BOTH are built and ONE is shown -- the discipline the start card's row glyphs
	-- and the chamber pips below already use (*"every glyph is BUILT and one is SHOWN"*) -- because
	-- a chip that destroys and rebuilds a Frame every time the player presses X is a chip that
	-- flickers, and `Hud.renderCorner` runs once a frame.
	--
	-- `LayoutOrder = 0` puts it BEFORE `Pip1`, so the row reads left to right as "this shell, in
	-- these chambers, this many left, called this". The box is sized by `Style.glyph` from one `px`,
	-- which is the phone step on a phone and the desktop step otherwise -- the same single number
	-- the rest of §3.10 is drawn from.
	table.clear(ammoShells)
	for _, kind in ipairs({ "slug", "buck" }) do
		local shell = Style.glyph(
			ammoBodyRow,
			"Shell" .. string.upper(string.sub(kind, 1, 1)) .. string.sub(kind, 2),
			kind,
			if statusPhone then 14 else 16
		)
		shell.LayoutOrder = 0
		shell.Visible = false
		ammoShells[kind] = shell
	end

	-- THE PIPS, BUILT ONCE AND SHOWN AS THE WEAPON NEEDS THEM. `PIP_MAX` is a ceiling and not a
	-- claim about any gun: a break-action has two chambers and the rifle's magazine shows three, and
	-- a wider gun later draws more of the same Frames rather than a different readout.
	table.clear(ammoPips)
	for index = 1, Hud.PIP_MAX do
		local pip = Instance.new("Frame")
		pip.Name = string.format("Pip%d", index)
		pip.BackgroundColor3 = Style.LOOK.PAPER
		pip.BorderSizePixel = 0
		pip.Size = UDim2.fromOffset(9, 14)
		pip.LayoutOrder = index
		pip.ZIndex = ammoBodyRow.ZIndex + 1
		pip.Visible = false
		Style.corner(pip, Style.RADIUS.BAR)
		-- THE SELECTED CHAMBER GETS A 2 px BAR UNDER IT (§3.10), and it is a child so it travels
		-- with the pip and cannot be left behind pointing at the wrong barrel.
		local under = Instance.new("Frame")
		under.Name = "Selected"
		under.BackgroundColor3 = Style.LOOK.BLAZE_HI
		under.BorderSizePixel = 0
		under.AnchorPoint = Vector2.new(0.5, 1)
		under.Position = UDim2.new(0.5, 0, 1, 4)
		under.Size = UDim2.fromOffset(9, 2)
		under.ZIndex = ammoBodyRow.ZIndex + 2
		under.Visible = false
		under.Parent = pip
		pip.Parent = ammoBodyRow
		table.insert(ammoPips, pip)
	end

	local ammoCount = sized(Style.label(ammoBodyRow, "Value", "STAT", viewX), "STAT")
	ammoCount.AutomaticSize = Enum.AutomaticSize.X
	ammoCount.Size = UDim2.fromOffset(0, Style.SIZE.STAT[1] + 4)
	ammoCount.LayoutOrder = Hud.PIP_MAX + 1
	ammoCount.TextXAlignment = Enum.TextXAlignment.Left

	local ammoWord = sized(Style.label(ammoBodyRow, "Caption", "MICRO", viewX), "MICRO")
	ammoWord.AutomaticSize = Enum.AutomaticSize.X
	ammoWord.Size = UDim2.fromOffset(0, Style.SIZE.STAT[1] + 4)
	ammoWord.LayoutOrder = Hud.PIP_MAX + 2
	ammoWord.TextColor3 = Style.LOOK.FIELD_MUTED
	ammoWord.TextXAlignment = Enum.TextXAlignment.Left
	ammoWord.TextYAlignment = Enum.TextYAlignment.Bottom
	Style.padding(ammoWord, 0, 3, 0, 0)

	-- THE RELOAD BAR, across the chip's bottom (§3.8's reload row: track `LINE`, fill `LINE -> PAPER`).
	-- NO TWEEN: it is a clock and moves with the number, and a bar that eases is a bar that lies.
	local ammoTrack, ammoFill = Style.bar(ammo, "Reload", Style.LOOK.LINE, Style.LOOK.LINE, Style.LOOK.PAPER, 3)
	-- ANCHORED LEFT AND POSITIONED IN OFFSETS. A bar centred with `0.5` scale reaches
	-- `parentW / 2 + w / 2`, which depends on the parent the parent is measuring FROM -- a loop, and
	-- the one that settled at 430 px. Pure offset in x, so the slate measures `max(row, bar) = row`.
	ammoTrack.AnchorPoint = Vector2.new(0, 1)
	ammoTrack.Position = UDim2.new(0, 0, 1, 3)
	-- ZERO UNTIL IT IS MEASURED (see `ammoBody`): `Hud.renderCorner` writes the row's own width.
	ammoTrack.Size = UDim2.fromOffset(0, 3)
	ammoTrack.Visible = false

	-- THE HORN CHIP (§5 surface 7), which does not exist today: *"a beater's bottom-right corner is
	-- empty"*. Karen's beater has had no answer at all to "why did my horn stop working"; this is it.
	local horn = Style.slate(screen, "HornChip", false, statusPhone)
	horn.AutomaticSize = Enum.AutomaticSize.X
	horn.Size = UDim2.fromOffset(0, if statusPhone then 42 else 46)
	horn.AnchorPoint = Vector2.new(1, 1)
	horn.Position = UDim2.new(1, -Style.MARGIN, 1, -Style.MARGIN)
	horn.ZIndex = Hud.STATUS.Z_INDEX
	horn.Visible = false
	local hornBodyRow = Instance.new("Frame")
	hornBodyRow.Name = "Content"
	hornBodyRow.BackgroundTransparency = 1
	hornBodyRow.BorderSizePixel = 0
	-- EXACTLY THE SHAPE THE STATUS BAR'S CHIPS ALREADY HAVE, and that is why it is this shape:
	-- `AutomaticSize.X` with the HEIGHT in scale, measured three levels deep (slate -> chip ->
	-- label) and demonstrably coming out at the width of its own words. The row and the bar below
	-- it are siblings, and the bar is sized and positioned in pure OFFSETS -- a scale-width or
	-- scale-x-positioned bar and the box that measures it chase each other, which is what made the
	-- horn chip 430 px wide (`...134503Z-t201c-beater-cooldown.png`).
	hornBodyRow.AutomaticSize = Enum.AutomaticSize.X
	hornBodyRow.Size = UDim2.fromScale(0, 1)
	hornBodyRow.ZIndex = horn.ZIndex + 1
	hornBodyRow.Parent = horn
	local hornRow = Instance.new("UIListLayout")
	hornRow.FillDirection = Enum.FillDirection.Horizontal
	hornRow.VerticalAlignment = Enum.VerticalAlignment.Center
	hornRow.SortOrder = Enum.SortOrder.LayoutOrder
	hornRow.Padding = UDim.new(0, 7)
	hornRow.Parent = hornBodyRow

	-- THE HORN ICON IS TWO FRAMES (§3.10): an 18 x 7 brass body rotated -8 degrees with a 9 x 9 bell
	-- at its right end in `BRASS_HI`. No upload, no glyph, and nothing a font has to carry.
	local hornIcon = Instance.new("Frame")
	hornIcon.Name = "Icon"
	hornIcon.BackgroundTransparency = 1
	hornIcon.Size = UDim2.fromOffset(28, 16)
	hornIcon.LayoutOrder = 1
	hornIcon.ZIndex = hornBodyRow.ZIndex + 1
	hornIcon.Parent = hornBodyRow
	local hornShape = Instance.new("Frame")
	hornShape.Name = "Body"
	hornShape.BackgroundColor3 = Style.LOOK.BRASS
	hornShape.BorderSizePixel = 0
	hornShape.AnchorPoint = Vector2.new(0, 0.5)
	hornShape.Position = UDim2.fromScale(0, 0.5)
	hornShape.Size = UDim2.fromOffset(18, 7)
	hornShape.Rotation = -8
	hornShape.ZIndex = hornIcon.ZIndex
	Style.corner(hornShape, 4)
	hornShape.Parent = hornIcon
	local hornBell = Instance.new("Frame")
	hornBell.Name = "Bell"
	hornBell.BackgroundColor3 = Style.LOOK.BRASS_HI
	hornBell.BorderSizePixel = 0
	hornBell.AnchorPoint = Vector2.new(1, 0.5)
	hornBell.Position = UDim2.fromScale(1, 0.5)
	hornBell.Size = UDim2.fromOffset(9, 9)
	hornBell.ZIndex = hornIcon.ZIndex + 1
	Style.corner(hornBell, 4)
	hornBell.Parent = hornIcon

	local hornWord = sized(Style.label(hornBodyRow, "Value", "STAT", viewX), "STAT")
	hornWord.AutomaticSize = Enum.AutomaticSize.X
	hornWord.Size = UDim2.fromOffset(0, Style.SIZE.STAT[1] + 4)
	hornWord.LayoutOrder = 2
	hornWord.TextXAlignment = Enum.TextXAlignment.Left

	local hornState = sized(Style.label(hornBodyRow, "Caption", "MICRO", viewX), "MICRO")
	hornState.AutomaticSize = Enum.AutomaticSize.X
	hornState.Size = UDim2.fromOffset(0, Style.SIZE.STAT[1] + 4)
	hornState.LayoutOrder = 3
	hornState.TextColor3 = Style.LOOK.FIELD_MUTED
	hornState.TextXAlignment = Enum.TextXAlignment.Left
	hornState.TextYAlignment = Enum.TextYAlignment.Bottom
	Style.padding(hornState, 0, 3, 0, 0)

	-- THE READINESS BAR (§3.8's horn row: track `BRASS_LO`, fill `BRASS_LO -> BRASS`). It starts
	-- EMPTY on a blast and FILLS over `Horn.CONFIG.COOLDOWN`, which is §7's own instruction.
	local _, hornFill = Style.bar(horn, "Cooldown", Style.LOOK.BRASS_LO, Style.LOOK.BRASS_LO, Style.LOOK.BRASS, 3)
	local hornTrack = hornFill.Parent :: Frame
	hornTrack.AnchorPoint = Vector2.new(0, 1)
	hornTrack.Position = UDim2.new(0, 0, 1, 3)
	hornTrack.Size = UDim2.fromOffset(0, 3)

	crosshair = container
	ammoChip = ammo
	ammoBody = ammoBodyRow
	hornBody = hornBodyRow
	ammoValue = ammoCount
	ammoCaption = ammoWord
	ammoBarTrack = ammoTrack
	ammoBarFill = ammoFill
	hornChip = horn
	hornValue = hornWord
	hornCaption = hornState
	hornBarFill = hornFill
	hitMark = mark
	driveBar = status
	feedFrame = feed
	scorePanel = board
	reportFrame = report
	reportScrimFrame = reportScrim
	hitCardFrame = hitCard
	shopFrame = shop
	padFrame = padDialog
	padLeavingFrame = padLeaving
	compassFrame = compass
	scoreEyebrow = boardEyebrow
	scoreTitle = boardTitle
	scoreBody = boardScroll
	scoreFooterWord = boardFooterWord
	scoreFooterValue = boardFooterValue
	scoreFooterFill = boardFill
	tiedBanner = tied
	tiedText = tiedText_
	startCard = card
	startCardPad = cardPad
	startCardTitle = cardTitle
	startCardRole = cardRole
	startCardSection = cardSection
	startCardSectionWord = cardSectionWord
	startCardSectionRule = cardSectionRule
	startCardRowsBox = cardRows
	startCardTimer = cardTimer
	startCardSecondsLabel = cardSeconds
	startCardCount = cardCount
	startCardBarSlot = cardBarSlot
	startCardFill = cardFill
	miniMapFrame = miniMap
	fullMapFrame = fullMap
	mapLegendFrame = legend
	objectiveSlate = objectiveBack
	objectiveLine = objective
	waypointMark = waypoint
	waypointWord = waypointLabel
	railFrame = rail
	return screen
end

-- Shows the marker for its own lifetime. The ONE writer of the marker's colour and visibility.
-- `kind` is "kill" or anything else, which means "hit": an unknown payload must still draw
-- something, because a marker that silently does nothing is the failure this exists to fix.
function Hud.showHitMark(kind: string?)
	local mark = hitMark
	if not mark or not Shotgun.CONFIG.HIT_MARK_ENABLED then
		return
	end
	local config = Shotgun.CONFIG
	local kill = kind == "kill"
	hitKind = if kill then "kill" else "hit"

	for _, child in ipairs(mark:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundColor3 = if kill then config.HIT_MARK_KILL_COLOR else config.HIT_MARK_COLOR
		end
	end
	mark.Visible = true
	-- THE TICK RIDES WITH THE PICTURE (task 124). It is called from here and nowhere else, because
	-- this is the one writer of the marker -- so what you hear and what you see cannot disagree about
	-- what happened. An empty id plays nothing and counts itself; see `Hud.Sound`.
	Sound.tick(hitKind)

	hitToken += 1
	local token = hitToken
	task.delay(if kill then config.HIT_MARK_KILL_SECONDS else config.HIT_MARK_SECONDS, function()
		if token ~= hitToken then
			return -- a later hit owns the marker now
		end
		hitKind = nil
		if hitMark then
			hitMark.Visible = false
		end
	end)
end

-- What the server's remote is bound to. It is a named function rather than an inline closure so a
-- client spec can drive exactly the code path the wire drives.
function Hud.onHitMarker(payload: any)
	Hud.showHitMark(if type(payload) == "table" then payload.kind else nil)
end

-- `[*]* SLUG 24`: barrel glyphs (* Live, x Spent, - Empty) with the selected barrel in brackets,
-- then the ammo the NEXT load uses, the reserve, and " R" while an action is running.
-- `row` IS THE WEAPON THIS STATE BELONGS TO (task 140), and all it decides is the WORD: the wire
-- says `Slug` for both guns because `Boar.Wound.damageFor` branches on that string, and a rifle
-- printing "SLUG" would be a lie on screen. `row.AMMO_LABEL` is the one mapping, here in the one
-- module that draws. nil is the shotgun's own words, which is every caller before the rifle.
local function textFor(state: Shotgun.WeaponSnapshot, row: any?): string
	local resolvedRow = row or Weapons.row(state.weapon)
	local glyphs = ""
	if resolvedRow ~= nil and resolvedRow.READOUT == "magazine" then
		-- A MAGAZINE RIFLE SHOWS ROUNDS LEFT, NOT ONE GLYPH PER CHAMBER (task 142). Karen asked for
		-- *"3 shells"* in the magazine and the readout she would check it against is `3/3`; three
		-- bracketed asterisks is what a THREE-BARRELLED SHOTGUN would print, which is not this gun.
		local live = 0
		for _, chamber in ipairs(state.barrels) do
			if chamber == "Live" then
				live += 1
			end
		end
		glyphs = string.format("%d/%d", live, resolvedRow.MAGAZINE or #state.barrels)
	else
		for index, barrel in ipairs(state.barrels) do
			local glyph = if barrel == "Live" then "*" elseif barrel == "Spent" then "x" else "-"
			glyphs ..= if index == state.selected then "[" .. glyph .. "]" else glyph
		end
	end
	local busyMark = if state.busyFor > 0 then " R" else ""
	-- Shells are carried per type, so the count shown is the pocket the next load comes from, and
	-- the server's one-line notice ("NO BUCK") is what tells the player why X did nothing.
	local pocket = state.reserve[state.ammo] or 0
	local notice = if state.notice then " " .. state.notice else ""
	local resolved = resolvedRow
	local label = (resolved and resolved.AMMO_LABEL and resolved.AMMO_LABEL[state.ammo]) or string.upper(state.ammo)
	return string.format("%s %s %d%s%s", glyphs, label, pocket, busyMark, notice)
end

-- PURE, AND EXPORTED (task 112, round 3). The readout case could only ever ask the LIVE text, and
-- the live player is tied to a tree by the last scenario, so the text is empty and the case had
-- nothing to assert -- round 2 made it return early, which is a case that proves nothing. Exporting
-- the formatter lets a spec hand it a state it owns and assert the SHAPE, and still check that the
-- live text is empty exactly when there is no gun.
function Hud.readoutFor(state: Shotgun.WeaponSnapshot, row: any?): string
	return textFor(state, row)
end

local function clockText(seconds: number): string
	local whole = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

-- WHICH ROW IS FIRST PLACE IS NO LONGER DECIDED HERE (task 170). `Hud.firstPlaceRank` was this
-- Hud's own implementation of *"a tie at the top is not a first place"* (task 160, after ioquake3's
-- `RANK_TIED_FLAG`); from task 170 the SERVER pays a first-place bonus off the same question, so the
-- rule moved to `Drive.Rank` -- ONE implementation, two readers -- and the old function is archived
-- in backups/2026-10-13_task-170_hud-firstplacerank.txt (rule 7). Two correct pieces of code
-- disagreeing is this project's named failure mode (docs/PROJECT_CONTEXT.md).
local Rank = Drive.Rank

-- ONE ROW OF THE RESULTS TABLE.
--
-- THE `TEAM` COLUMN IS GONE AND THE COINS COLUMN IS WHAT IT PAID FOR (task 170). With a
-- `-- HUNTERS --` heading over the list, printing the role on every row under it says one
-- fact twice -- and the panel had no spare width: `SCORE_PANEL_WIDTH` is already 480 against the
-- 400-px screen `tests/client/hud_clarity.spec.luau` measures, so widening it would make an existing
-- problem worse. 41 characters plus badge and star, against today's 42.
--
-- `rank` RESTARTS AT 1 INSIDE EACH RANKING, because that is what "two first places" means.
-- ONE ROW OF THE RESULTS TABLE, AS CELLS (§3.12: *"one `TextLabel` per cell"*). The padding is
-- gone with `Enum.Font.Code` -- the numbers line up because they are PLACED -- so what this answers
-- is the WORDS, and `Hud.BOARD.COLUMNS` says where each one goes.
--
-- AN UNKNOWN IS NOT DRAWN AT ALL RATHER THAN `--` (§3.12). That is the one behaviour change in the
-- data: a leaver is not paid (`Economy.Coins.forDrive` skips `row.left`), and the `LEFT` tag beside
-- his row is what says why -- a `--` in the coins column was the same fact said twice and badly.
local function scoreCellsFor(rank: number, row): { [string]: string }
	local coins = if type(row.earned) == "number"
		then string.format(Drive.CONFIG.SCORE_EARNED_FORMAT, row.earned)
		else ""
	return {
		rank = tostring(rank),
		name = string.sub(tostring(row.name or "?"), 1, 18),
		kills = tostring(row.kills or 0),
		points = tostring(row.points or 0),
		coins = coins,
	}
end

-- ...AND THE SAME ROW AS ONE LINE, for `ScoreLine.text`. Kept because it is what a spec reads when
-- it wants the row's FACTS rather than its pixels, and because the tie between the two is one
-- function rather than two formatters that can disagree.
local function scoreRowText(rank: number, row, first: boolean?): string
	local cells = scoreCellsFor(rank, row)
	local parts = {}
	for _, key in ipairs(Hud.BOARD_ORDER) do
		if cells[key] ~= "" then
			table.insert(parts, cells[key])
		end
	end
	if first then
		table.insert(parts, Drive.CONFIG.SCORE_FIRST_BADGE)
	end
	if row.left then
		table.insert(parts, "LEFT")
	end
	return table.concat(parts, " ")
end

-- `cells` IS WHAT THE BOARD DRAWS and `text` is the same row as one line; `badge`, `left` and
-- `team` are the three things the ROW ITSELF wears -- the brass `1st` pill, the faint `LEFT` tag and
-- the colour of your own row's 3 px left bar.
export type ScoreLine = {
	text: string,
	heading: boolean,
	mine: boolean,
	cells: { [string]: string }?,
	badge: boolean?,
	left: boolean?,
	team: string?,
}

-- THE WHOLE BODY OF THE RESULTS TABLE, AS DATA (task 170). Karen, 2026-10-12: separate rankings for
-- hunters and beaters. PURE and exported for the reason every other string on this panel is -- a
-- drive is 600 seconds long, so no CLIENT suite ever reaches the `Scoring` phase, and the only way
-- to assert what the panel says is to hand this the snapshot the wire would.
--
-- TWO RANKINGS, TWO FIRST PLACES, ONE RULE. `Drive.Rank.splitByTeam` cuts the board's own TOTAL
-- order into hunters, beaters and the rows that are in neither, and `Rank.firstPlaceRank` is asked
-- ONCE PER RANKING -- the same function the server asked to pay the two bonuses, so a badge and a
-- bonus can never land on different rows.
--
-- THE `OTHERS` HEADING IS DRAWN ONLY WHEN THAT LIST HAS A ROW IN IT, which is the rule
-- the retired `Match.quarryLines` applied to its own POINTS label: *"THE WORD ONLY WHEN THERE IS A
-- NUMBER UNDER IT"*. `others` gets no first place either, because it is not a ranking -- it is the
-- people who were not in one (a player who joined outside `Assigning`/`Running` has no team yet).
--
-- IT TRUNCATES BY DROPPING TRAILING ROWS AND NEVER A HEADING: a list cut short is still readable,
-- a list whose heading was dropped tells the reader the wrong ranking.
function Hud.scorePanelLines(snapshot, myUserId: number?): { ScoreLine }
	local out: { ScoreLine } = {}
	local rows = if snapshot then snapshot.rows else nil
	local hunters, beaters, others = Rank.splitByTeam(rows)
	local budget = Drive.CONFIG.SCORE_ROWS_MAX

	-- `ranked` IS FALSE FOR `others` AND THAT IS NOT A DETAIL: the server pays a first-place bonus to
	-- the top HUNTER and the top BEATER only (`Economy.Coins.forDrive` asks `Rank.firstPlaceUserId` of
	-- those two lists and of no third), so a badge over `others` would be a winner the game never
	-- paid. Asking the rule of every list is exactly how the two sides came to disagree.
	local function section(heading: string, list, ranked: boolean)
		if #list == 0 or #out >= budget then
			return
		end
		table.insert(out, { text = heading, heading = true, mine = false })
		local firstRank = if ranked then Rank.firstPlaceRank(list) else nil
		for index, row in ipairs(list) do
			if #out >= budget then
				return
			end
			table.insert(out, {
				text = scoreRowText(index, row, index == firstRank),
				heading = false,
				mine = myUserId ~= nil and (row :: any).userId == myUserId,
				cells = scoreCellsFor(index, row),
				badge = index == firstRank,
				left = (row :: any).left == true,
				team = (row :: any).team,
			})
		end
	end

	section(Drive.CONFIG.SCORE_HUNTERS_HEADING, hunters, true)
	section(Drive.CONFIG.SCORE_BEATERS_HEADING, beaters, true)
	section(Drive.CONFIG.SCORE_OTHERS_HEADING, others, false)
	return out
end

-- THE LOCAL PLAYER'S BALANCE, for the drive bar, in every phase (the dispatch: the balance on the
-- HUD). PURE and exported for the same reason as everything else on this screen.
--
-- `""` WHENEVER THIS BUILD HAS NO MONEY IN IT, and `snapshot.coinsOn` is the one fact that says so.
-- ROUND 1 OF THE GATE FOUND THIS THE HARD WAY and the old comment here was simply wrong: it said
-- `""` happened when the player "has no row at all", *"which is the whole of today's game with the
-- `COINS` flag off"*. He always has a row -- `Match.snapshot` builds one per `Score.leaderboard`
-- entry and `watchPlayer` joins every player to the board -- so with the flag off every bar in the
-- game gained a dead `COINS --`, and OFF was not the game before task 170 at all.
--
-- THE TWO ABSENCES ARE DIFFERENT QUESTIONS AND THE ROWS CANNOT TELL THEM APART, which is why the
-- answer is on the snapshot and not inferred here: `row.coins` is absent both when there IS no money
-- and when this player's profile did not open. `coinsOn` separates them --
--   no `coinsOn`            -> `""`. There is no money in this build; draw nothing.
--   `coinsOn`, no `coins`   -> `COINS --`. There IS money and his balance is UNKNOWN, which is a
--                              real thing to tell him and is not zero.
--   `coinsOn` and a number  -> `COINS 1240`.
function Hud.coinsText(snapshot, userId: number?): string
	local rows = if snapshot then snapshot.rows else nil
	-- ONE SOURCE, AND IT IS THE SERVER'S: this reads no flag of its own. A Hud that read `Flags` would
	-- be a second answer to "is there money", and the client's copy of a server rule is the thing
	-- `ReplicatedStorage.Drive`'s header exists to prevent.
	if rows == nil or userId == nil or snapshot.coinsOn ~= true then
		return ""
	end
	for _, row in ipairs(rows) do
		if row.userId == userId then
			local value = row.coins
			if type(value) == "number" then
				return string.format("%s %d", Drive.CONFIG.SCORE_COINS_LABEL, value)
			end
			return string.format("%s %s", Drive.CONFIG.SCORE_COINS_LABEL, Drive.CONFIG.SCORE_COINS_UNKNOWN)
		end
	end
	return ""
end

-- WHETHER THE SCORE PANEL SHOWS -- which since task 159 is KAREN'S RESULTS TABLE, up for the whole of
-- `Scoring` over the results scene. The one extra clause: NOT WHILE THE REPORT IS OPEN. Two centred
-- panels at once is two panels nobody can read, and the report is the one the player asked for by
-- pressing Tab -- which since task 159 is the ONLY way it opens (`Report.CONFIG`'s
-- `AUTO_OPEN_AT_DRIVE_END`, false, with the screenshot that says why). Before that it opened itself
-- when a drive closed, and this clause then hid the results table behind it every single time. Pure and exported for the same reason the renderer below is -- a drive is 600
-- seconds long, so no harness run ever reaches the Scoring phase.
function Hud.scorePanelVisible(snapshot, reportOpen: boolean?): boolean
	return snapshot ~= nil and snapshot.phase == "Scoring" and Drive.CONFIG.SCOREBOARD_ENABLED and reportOpen ~= true
end

-- THE ONE WRITER of the score panel, and it is PUBLIC on purpose: a drive is 600 seconds long, so no
-- harness run ever reaches the Scoring phase, and the design's visibility assertion (section 12.7
-- item 4) could not be written at all unless a spec can hand this the snapshot the wire would. It is
-- the same reason Hud.onHitMarker is a named function and not an inline closure. Nothing else in the
-- repo calls it but renderDrive.
-- THE ONE WRITER of the results board: its words, its row states, its footer bar AND its height.
--
-- THE HEIGHT FOLLOWS THE ROW COUNT (§3.12). Until task 201 part 2 the board was 20 fixed slots and
-- drew a 480 x 574 box to hold three of them. Now it is `header + rows + footer`, measured by the
-- pure `Hud.boardHeight`, and the body scrolls past 14 rows.
function Hud.renderScore(snapshot, secondsLeft: number?)
	local board = scorePanel
	if not board then
		return
	end
	local show = Hud.scorePanelVisible(snapshot, ReportPanel.isOpen())
	board.Visible = show
	if not show then
		-- Cleared, not just hidden: a stale board must not flash for a frame at the next Scoring.
		for index, row in ipairs(scoreLines) do
			row.Visible = false
			local head = scoreHeads[index]
			if head ~= nil then
				head.Visible = false
			end
		end
		scoreCountdownFrom = 0
		return
	end
	local viewX = Hud.viewportX()
	if scoreEyebrow then
		-- THE EYEBROW IS WHICH DRIVE and the title is WHAT THIS IS (§3.4), which is the pair the
		-- whole game's panels share. The wording is `Drive.CONFIG`'s and not this renderer's.
		(scoreEyebrow :: TextLabel).Text =
			Style.spaced(string.format(Drive.CONFIG.SCORE_EYEBROW_FORMAT, snapshot.driveNumber))
	end
	if scoreTitle then
		(scoreTitle :: TextLabel).Text = Drive.CONFIG.SCORE_TITLE_WORD
	end

	local me = Players.LocalPlayer.UserId
	-- THE BODY IS DECIDED BY ONE PURE CALL AND THIS LOOP DECIDES NOTHING (task 170): the rankings,
	-- the ranks, the badges and the headings are all `Hud.scorePanelLines`'s -- which is also the
	-- only way a spec can assert them, since no client suite reaches `Scoring`.
	local lines = Hud.scorePanelLines(snapshot, me)
	local rowH = Style.rowHeight(viewX)
	local headH = if Style.isPhone(viewX) then 18 else 20
	local y = 0
	local rows, heads = 0, 0
	for index, row in ipairs(scoreLines) do
		local head = scoreHeads[index]
		local entry = lines[index]
		local isHead = entry ~= nil and entry.heading
		if head ~= nil then
			head.Visible = isHead
		end
		row.Visible = entry ~= nil and not entry.heading
		if entry == nil then
			continue
		end
		if isHead then
			heads += 1
			local word = head and head:FindFirstChild("Word")
			if word ~= nil then
				(word :: TextLabel).Text = Style.spaced(entry.text);
				-- A SECTION HEAD IS ITS TEAM'S COLOUR and nothing else on this board is coloured by
				-- team except your own row's bar. `others` is neither side, so it takes `PAPER`.
				(word :: TextLabel).TextColor3 = if entry.text == Drive.CONFIG.SCORE_HUNTERS_HEADING
					then Style.LOOK.HUNTER
					elseif entry.text == Drive.CONFIG.SCORE_BEATERS_HEADING then Style.LOOK.BEATER
					else Style.LOOK.PAPER
			end
			(head :: Frame).Position = UDim2.fromOffset(0, y)
			y += headH
			continue
		end
		rows += 1
		row.Position = UDim2.fromOffset(0, y)
		y += rowH
		Style.rowState(row, entry.mine == true, entry.team)
		local cells = scoreCells[index]
		for key, cell in pairs(cells or {}) do
			local word = (entry.cells or {})[key] or ""
			cell.Text = word
			cell.TextColor3 = Hud.scoreCellColor(key, word, entry.mine == true)
		end
		local badge = row:FindFirstChild("Badge")
		if badge ~= nil then
			(badge :: Frame).Visible = entry.badge == true
			local text = (badge :: Frame):FindFirstChild("Text")
			if text ~= nil then
				(text :: TextLabel).Text = Style.spaced(Drive.CONFIG.SCORE_FIRST_BADGE)
			end
		end
		local gone = row:FindFirstChild("Left")
		if gone ~= nil then
			-- ONE OR THE OTHER, NEVER BOTH: they share the same x, and a first-placed leaver reads
			-- as a leaver -- which is the fact that explains why he is not in the next drive.
			(gone :: Frame).Visible = entry.left == true
			if entry.left == true and badge ~= nil then
				(badge :: Frame).Visible = false
			end
		end
	end
	-- THE LAST DRAWN ROW WEARS NO RULE (§3.12: *"between rows, not after the last"*).
	for index = #scoreLines, 1, -1 do
		local row = scoreLines[index]
		if row.Visible then
			local rule = row:FindFirstChild("Rule")
			if rule ~= nil then
				(rule :: Frame).Visible = false
			end
			break
		end
	end
	for index, row in ipairs(scoreLines) do
		local rule = row:FindFirstChild("Rule")
		if rule ~= nil and row.Visible and index < #lines then
			(rule :: Frame).Visible = true
		end
	end

	-- THE HEIGHT, AND THE BODY'S OWN. Both from the one pure measure, so the board a spec computes
	-- and the board on screen are the same board.
	local body = scoreBody
	if body ~= nil then
		local cap = Hud.BOARD.MAX_VISIBLE_ROWS * rowH;
		(body :: ScrollingFrame).Size = UDim2.fromOffset(Hud.BOARD.WIDTH - 2 * Hud.BOARD.PADDING, math.min(y, cap));
		(body :: ScrollingFrame).CanvasSize = UDim2.fromOffset(0, y)
	end
	board.Size = UDim2.fromOffset(Hud.BOARD.WIDTH, Hud.boardHeight(rows, heads, viewX))

	local left = math.max(0, math.floor(secondsLeft or 0))
	if scoreFooterWord then
		(scoreFooterWord :: TextLabel).Text = Style.spaced(Drive.CONFIG.SCORE_FOOTER_WORD)
	end
	if scoreFooterValue then
		(scoreFooterValue :: TextLabel).Text = tostring(left)
	end
	-- THE BAR'S DENOMINATOR IS LATCHED FROM THE CLOCK ITSELF and is not a second copy of
	-- `Match.CONFIG.SCORE_SECONDS` -- which is the SERVER's and which this client cannot require.
	-- The first frame of `Scoring` carries the whole gap, so the bar starts full and drains; a
	-- constant here would be a number that can disagree with the one the drive actually used.
	scoreCountdownFrom = math.max(scoreCountdownFrom, left)
	if scoreFooterFill then
		-- IT DRAINS, and it is a CLOCK (§3.8): no tween.
		local whole = math.max(1, scoreCountdownFrom);
		(scoreFooterFill :: Frame).Size = UDim2.fromScale(math.clamp(left / whole, 0, 1), 1)
	end
end

-- WHAT COLOUR A CELL'S NUMBER IS (§3.12). PURE, because it is four rules and a spec can hold all
-- four: a coin number is `COIN_TEXT` and carries its `+`; a NEGATIVE points number is `CLAY`; a
-- zero is `FIELD_MUTED`; your own name is `PAPER` and everybody else's is `BODY`.
function Hud.scoreCellColor(key: string, word: string, mine: boolean): Color3
	if key == "coins" then
		return Style.LOOK.COIN_TEXT
	end
	if key == "name" then
		return if mine then Style.LOOK.PAPER else Style.LOOK.BODY
	end
	if key == "points" and string.sub(word, 1, 1) == "-" then
		return Style.LOOK.CLAY
	end
	if word == "0" then
		return Style.LOOK.FIELD_MUTED
	end
	return if mine then Style.LOOK.PAPER else Style.LOOK.BODY
end

-- THE ONE WRITER of the tied banner. The local player only: everybody else's tie is in the feed and
-- in the rope you can see across the arena.
function Hud.renderTied(isTied: boolean)
	local banner = tiedBanner
	if not banner then
		return
	end
	banner.Visible = isTied
	if tiedText ~= nil then
		-- Cleared, not just hidden, which is this file's rule everywhere: the next tie must not
		-- flash the last one's sentence for a frame.
		(tiedText :: TextLabel).Text = if isTied then Drive.CONFIG.TIED_TEXT else ""
	end
end

-- ---------------------------------------------------------------- the start card (task 158)
--
-- KAREN'S WORDS FOR THE TWO SIDES, and this is the one place they are said -- BY THE WHOLE HUD since
-- 201 part 3, not just by the start card. `Hud.roleBadge` (the status bar's pill) returns this, so
-- the two surfaces that name a side cannot print two vocabularies for one fact. Her design doc and
-- every message she sends say hunter and beater; `Shooters` / `Drivers` stay the TEAM names in
-- `Match.CONFIG` and on the wire, which is a different string and a different job.
function Hud.roleWord(team: string?): string
	if team == "Shooters" then
		return "HUNTER"
	elseif team == "Drivers" then
		return "BEATER"
	end
	return ""
end

-- WHAT THE STATUS BAR'S ROLE PILL SAYS, AND IT IS `Hud.roleWord` -- the same words as the start
-- card's, out of the same function. ONE PLACE, so the bar and the card cannot drift apart.
--
-- IT SAID `SHOOTER` / `DRIVER` UNTIL 201 PART 3, and that was the design system's §5 surface 1
-- written down as a defect: *"the start card's own words, because the HUD says two different things
-- for one fact today"*. Karen's doc and every message she sends say hunter and beater; the card has
-- said so since task 158 while the pill two inches above it said SHOOTER, which is one fact printed
-- twice in two vocabularies. The reason it survived three tasks is in `TWO_PLAYER_PATHS`: the word
-- is asserted by `tests/client/match_client.spec.luau` through `tests/client/Role.luau`'s
-- `Role.badge()`, so the flip costs a two-player run -- and THIS task pays for one already (the
-- wire's quarry rows), which is why the Director called it here (TASKS.md 201a).
--
-- `Shooters` / `Drivers` ARE UNTOUCHED, and the two are not the same string: the TEAM names are the
-- server's (`Match.CONFIG`, `Players.Team`, `Match.myTeam`, `Style.teamColor`, `MapUi`'s marker
-- table, every `team == "Drivers"` branch in this file) and only the DISPLAYED word changed. The
-- pill's colour is `Style.teamColor(team)`, keyed by the team name and not by this string, so
-- nothing in the game keys off the word that moved.
function Hud.roleBadge(team: string?): string
	return Hud.roleWord(team)
end

-- WHETHER THE CARD SHOWS: the start of a drive is the `Assigning` phase and nothing else. Pure and
-- exported for the score panel's own reason -- a drive is 600 seconds long, so no harness run sees
-- the real transition and a spec has to be able to hand this the snapshot the wire would.
--
-- NOT WHILE THE REPORT IS OPEN, the same clause the score panel has: two panels at once is two
-- panels nobody reads. Since task 159 the report opens on `Tab` and nowhere else, so this is the
-- player's own choice rather than something that happened to him seconds before the drive started.
function Hud.startCardVisible(snapshot, reportOpen: boolean?): boolean
	return snapshot ~= nil and snapshot.phase == "Assigning" and reportOpen ~= true
end

-- ---------------------------------------------------------------- the card's body, pure
--
-- ONE IDEA PER ROW, which is the whole of what Karen asked for: *"this message has to be improved
-- maybe each from new line"*. A row is a GLYPH (tick, cross, chevron, horn), the WORDS, and at most
-- one right-hand cell -- a signed number, a tag, or a word.
--
-- THE RULE IS STILL THE SERVER'S. `snapshot.quarry` is `Match.quarryRows`: one entry per kind with
-- what that kind is worth. This side decides nothing about what is legal -- it decides where the
-- number is drawn, which is the division task 158 already stated and the spec repeats
-- (*"The rule stays the server's; only the layout is the client's"*).
--
-- `meaning` IS THE SECOND READING AND THE GLYPH IS THE FIRST (the spec's rule 3): a tick and a
-- cross say may / must not before any colour is read, and the number then carries its own sign.
--
-- `phone` DROPS THE BEATER'S RIGHT-HAND CELLS, and only his (the spec's amendment 2 and rule 2):
-- at 264 wide `Push the boars to the hunters` needs the whole row, so the cell goes and the text
-- keeps the width -- the same way the status bar drops a whole chip rather than squeezing one.
export type StartRow = {
	glyph: string,
	text: string,
	value: string?,
	meaning: string?,
	tag: string?,
	word: string?,
}

function Hud.startCardRows(snapshot, team: string?, phone: boolean?): { StartRow }
	local rows: { StartRow } = {}
	local max = Drive.CONFIG.START_CARD_ROWS_MAX
	if team == "Drivers" then
		for _, source in ipairs(Drive.CONFIG.START_CARD_BEATER_ROWS) do
			if #rows >= max then
				break
			end
			table.insert(rows, {
				glyph = source.glyph,
				text = source.text,
				-- A CROSS ROW IS CLAY AND A ROW THAT IS A JOB IS NOT: `meaning` is read for the
				-- text's colour as well as the number's, so "you do not shoot" and "do not cross"
				-- are the two clay lines on his card and the push and the horn are not.
				meaning = if source.glyph == "cross" then "bad" else nil,
				tag = if phone then nil else source.tag,
				word = if phone then nil else source.word,
			})
		end
		return rows
	end
	-- THE HUNTER'S LIST IS THE WIRE'S, IN THE WIRE'S ORDER. A kind with no price is drawn with no
	-- number rather than with a wrong one -- the retired `QUARRY_NOTE`'s own rule.
	for _, entry in ipairs((snapshot and snapshot.quarry) or {}) do
		if #rows >= max then
			break
		end
		local kind = tostring(entry.kind or "")
		local points = entry.points
		local word = Drive.CONFIG.START_CARD_QUARRY_WORDS[kind]
		if word == nil then
			-- `Report.kindWord` IS THE ONE PLACE A DATA KIND BECOMES A NOUN, so even a kind this
			-- card has no copy for is never printed as `cub` (the spec's rule 4).
			local noun = Report.kindWord(kind)
			word = string.upper(string.sub(noun, 1, 1)) .. string.sub(noun, 2)
		end
		table.insert(rows, {
			glyph = if points ~= nil and points > 0 then "tick" else "cross",
			text = word,
			value = if points ~= nil then string.format("%+d", points) else nil,
			meaning = if points ~= nil and points > 0 then "good" else "bad",
		})
	end
	-- THE PERSON ROW, and it is the one the Designer added: *"`SAFETY_PENALTY = -10` and a tie to a
	-- tree for the rest of the drive is a real rule the card never mentioned, and the beaters are
	-- walking toward the hunter while this card is up"*. Drawn only when the SERVER sent the
	-- number -- a typed -10 here would be a second copy of a penalty.
	local safety = snapshot and snapshot.safetyPenalty
	if safety ~= nil and #rows < max then
		table.insert(rows, {
			glyph = "cross",
			text = Drive.CONFIG.START_CARD_PERSON,
			value = string.format("%+d", safety),
			meaning = "bad",
		})
	end
	return rows
end

-- WHICH LIST THIS ROLE IS READING. The same two words start both heads, so a player who has played
-- the other side finds the list in the same place (the spec's §1.3).
function Hud.startCardSectionFor(team: string?): string
	return if team == "Drivers" then Drive.CONFIG.START_CARD_SECTION_BEATER else Drive.CONFIG.START_CARD_SECTION_HUNTER
end

-- THE LAST LINE'S INSTRUCTION, in the words of the role it is for. BOTH are instructions now:
-- `DRIVE STARTS IN` was a clock with no job in it, and `WAIT FOR THE HORN` is the phrase the
-- objective line already shows a beater in `Assigning`.
function Hud.startCardTimerFor(team: string?, secondsLeft: number?): string
	local label = if team == "Drivers"
		then Drive.CONFIG.START_CARD_BEATER_TIMER
		else Drive.CONFIG.START_CARD_HUNTER_TIMER
	return string.format("%s  %d", label, Hud.startCardSecondsFor(secondsLeft))
end

-- THE NUMBER BESIDE IT. `math.ceil`, so the card shows `1` for the whole last second and never `0`
-- while it is still up (the spec's rule 5), and never a negative.
function Hud.startCardSecondsFor(secondsLeft: number?): number
	return math.max(0, math.ceil(secondsLeft or 0))
end

-- HOW FULL THE BAR IS. `full` is the largest `secondsLeft` this card has seen, which IS the phase's
-- length -- see `Drive.CONFIG`'s note: the client is never told `INTERMISSION_SECONDS`, and a typed
-- 10 would draw a bar two thirds full on the frame the card appears.
function Hud.startCardBarScale(secondsLeft: number?, full: number?): number
	local left = math.max(0, secondsLeft or 0)
	local span = math.max(left, full or 0)
	if span <= 0 then
		return 0
	end
	return math.clamp(left / span, 0, 1)
end

-- THE ONE WRITER of the start card. Public for the same reason `Hud.renderScore` is.
function Hud.renderStartCard(snapshot, team: string?, secondsLeft: number?)
	local cardFrame = startCard
	if not cardFrame then
		return
	end
	local show = Hud.startCardVisible(snapshot, ReportPanel.isOpen())
	cardFrame.Visible = show
	if not show then
		-- Cleared, not just hidden: the next drive must not flash the last one's card for a frame.
		-- THE LATCH GOES WITH IT, so the next card's bar starts full again.
		startCardFullSeconds = 0
		if startCardTitle then
			startCardTitle.Text = ""
		end
		if startCardRole then
			startCardRole.Text = ""
		end
		if startCardSectionWord then
			startCardSectionWord.Text = ""
		end
		if startCardTimer then
			startCardTimer.Text = ""
		end
		if startCardSecondsLabel then
			startCardSecondsLabel.Text = ""
		end
		for _, parts in ipairs(startCardRowParts) do
			parts.row.Visible = false
			parts.row.Size = UDim2.fromScale(1, 0)
			parts.text.Text = ""
		end
		return
	end
	local viewX = Hud.viewportX()
	local step = Hud.startCardStep(viewX)
	if startCardTitle then
		startCardTitle.Text = Style.spaced(string.format(Drive.CONFIG.START_CARD_EYEBROW, snapshot.driveNumber))
	end
	-- THE ROLE LINE, in the team's colour. A player with no team yet is given no role line rather
	-- than `YOU ARE A ` -- the same rule the status bar's chips follow (§3.9: an unknown fact is not
	-- drawn).
	local role = Hud.roleWord(team)
	if startCardRole then
		local label = startCardRole :: TextLabel
		label.Text = if role ~= "" then string.format(Drive.CONFIG.START_CARD_ROLE, role) else ""
		label.TextColor3 = Style.teamColor(team)
	end
	if startCardSectionWord and startCardSectionRule then
		local wordLabel = startCardSectionWord :: TextLabel
		wordLabel.Text = Style.spaced(Hud.startCardSectionFor(team))
		-- THE RULE FILLS WHAT THE WORD LEAVES (§3.12). Written per frame off the drawn bounds,
		-- because the face loads after the build and a rule sized at build time runs under the word.
		Style.ruleAfter(wordLabel, startCardSectionRule :: Frame, 9)
	end
	local rows = Hud.startCardRows(snapshot, team, Style.isPhone(viewX))
	for index, parts in ipairs(startCardRowParts) do
		local row = rows[index]
		parts.row.Visible = row ~= nil
		parts.row.Size = UDim2.new(1, 0, 0, if row ~= nil then step.rowH else 0)
		if row == nil then
			parts.text.Text = ""
			continue
		end
		for kind, glyph in pairs(parts.icons) do
			glyph.Visible = kind == row.glyph
		end
		parts.text.Text = row.text
		-- CLAY ON A CROSS ROW, `BODY` ON A TICK ROW (the spec's row table): the words of a thing you
		-- must not do are the same colour as the number it costs.
		parts.text.TextColor3 = if row.meaning == "bad" then Style.LOOK.CLAY else Style.LOOK.BODY
		parts.value.Visible = row.value ~= nil
		parts.value.Text = row.value or ""
		parts.value.TextColor3 = Style.meaningColor(row.meaning)
		parts.tag.Visible = row.tag ~= nil
		parts.tagText.Text = row.tag or ""
		parts.word.Visible = row.word ~= nil
		parts.word.Text = if row.word ~= nil then Style.spaced(row.word) else ""
		-- A ROW NEVER WRAPS AND NEVER TRUNCATES BEHIND ITS OWN RIGHT-HAND CELL. The reserve is what
		-- that cell actually MEASURES -- a tag is `AutomaticSize` -- so the text cannot run under it.
		local reserve = 0
		if row.value ~= nil then
			reserve = step.value
		elseif row.tag ~= nil then
			reserve = math.max(step.value, math.ceil(parts.tag.AbsoluteSize.X))
		elseif row.word ~= nil then
			reserve = math.max(step.value, math.ceil(parts.word.TextBounds.X))
		end
		parts.text.Size = UDim2.new(0, Hud.startCardTextWidth(viewX, reserve), 1, 0)
	end
	local seconds = Hud.startCardSecondsFor(secondsLeft)
	startCardFullSeconds = math.max(startCardFullSeconds, seconds)
	if startCardTimer then
		startCardTimer.Text = Style.spaced(
			if team == "Drivers" then Drive.CONFIG.START_CARD_BEATER_TIMER else Drive.CONFIG.START_CARD_HUNTER_TIMER
		)
	end
	if startCardSecondsLabel then
		(startCardSecondsLabel :: TextLabel).Text = tostring(seconds)
	end
	if startCardFill then
		(startCardFill :: Frame).Size = UDim2.fromScale(Hud.startCardBarScale(secondsLeft, startCardFullSeconds), 1)
	end
end

-- The bar's whole content. `MatchSystem` may be nil -- the Hud works with no drive at all, exactly
-- as it works with no camera -- and then the bar is simply hidden.
-- ONE CHIP, WRITTEN OR HIDDEN. `value == nil` means the fact is unknown and THE WHOLE CHIP IS NOT
-- DRAWN -- §3.9's rule, stated once here so no caller can decide to print `--` instead. The caption
-- is letter-spaced on the way to the screen (§1.2) and the plain word is what goes into
-- `statusWords`, which is what `Hud.driveBarText` answers.
local function chip(name: string, value: string?, caption: string?, color: Color3?)
	local entry = statusChips[name]
	if entry == nil then
		return
	end
	local show = value ~= nil and value ~= ""
	entry.chip.Visible = show
	if not show then
		-- CLEARED, NOT JUST HIDDEN, which is `Hud.renderStartCard`'s rule: the next phase must not
		-- flash the last one's number for a frame.
		entry.value.Text = ""
		entry.caption.Text = ""
		return
	end
	local word = value :: string
	entry.value.Text = word
	if color ~= nil then
		entry.value.TextColor3 = color
	end
	local label = caption or ""
	entry.caption.Text = if label == "" then "" else Style.spaced(label)
	entry.caption.Visible = label ~= ""
	if name == "Drive" then
		table.insert(statusWords, string.format("%s %s", label, word))
	elseif label == "" then
		table.insert(statusWords, word)
	else
		table.insert(statusWords, string.format("%s %s", word, label))
	end
end

-- THE DIVIDERS FOLLOW THE CHIPS. A 1 px rule between two chips is only a rule if there is something
-- on both sides of it: the first thing drawn never wears one, and a hidden chip must not leave its
-- divider behind as a hairline floating in the middle of the bar.
local function applyStatusDividers()
	local seen = false
	for _, divider in ipairs(statusDividers) do
		local name = string.sub(divider.Name, #"Divider" + 1)
		local entry = statusChips[name]
		local drawn = if name == "Role"
			then (statusPill ~= nil and (statusPill :: Frame).Visible)
			else (entry ~= nil and entry.chip.Visible)
		divider.Visible = seen and drawn
		if drawn then
			seen = true
		end
	end
end

-- THE ONE WRITER of the status bar, the score board, the tied banner and the start card: four
-- things that could disagree about which phase it is, drawn from ONE read of ONE snapshot.
local function renderDrive(MatchSystem)
	local bar = driveBar
	if not bar then
		return
	end
	local snapshot = if MatchSystem then MatchSystem.get() else nil
	-- The score screen and the tied banner are driven from the same snapshot as the bar, in one pass,
	-- so the three can never disagree about which phase it is.
	local left = if MatchSystem then MatchSystem.secondsLeft() else 0
	Hud.renderScore(snapshot, left)
	Hud.renderTied(MatchSystem ~= nil and MatchSystem.isTied())
	-- IN THE SAME PASS, from the same snapshot and the same clock as the bar and the board: three
	-- things that could disagree about which phase it is, drawn from one read (task 158).
	Hud.renderStartCard(snapshot, if MatchSystem then MatchSystem.myTeam() else nil, left)
	-- ...AND WHETHER THIS BEATER IS THROUGH THE LINE, which is the horn chip's one other fact and
	-- comes off the SAME read, for the same reason (§5 surface 7: *"Once he is through the line it
	-- reads THROUGH in CLAY with an empty bar"*).
	hornThrough = MatchSystem ~= nil and MatchSystem.isThrough() == true
	if not snapshot then
		bar.Visible = false
		table.clear(statusWords)
		for _, entry in pairs(statusChips) do
			entry.chip.Visible = false
		end
		if statusPill then
			(statusPill :: Frame).Visible = false
		end
		applyStatusDividers()
		return
	end

	local viewX = Hud.viewportX()
	local team = MatchSystem.myTeam()
	local phase = snapshot.phase
	table.clear(statusWords)

	chip("Drive", tostring(snapshot.driveNumber), "DRIVE")
	-- THE PHASE IS ITS OWN AMBER CHIP and only while there IS one to say: a drive that is running
	-- says so with a clock, not with the word "RUNNING".
	if phase == "Waiting" then
		-- WHY it is waiting, in the words the server used: "players", or the missing tag names.
		chip("Phase", "WAITING", table.concat(snapshot.waitingFor, ","), Style.LOOK.AMBER)
	elseif phase ~= "Running" then
		chip("Phase", string.upper(phase), nil, Style.LOOK.AMBER)
	else
		chip("Phase", nil, nil)
	end
	-- THE CLOCK IS THE BIGGEST NUMBER ON SCREEN (§5 surface 1), and its caption says which clock it
	-- is: the drive's own `TIME` while it runs, and what is `LEFT` of a phase otherwise.
	if phase == "Waiting" then
		chip("Clock", nil, nil)
	else
		chip(
			"Clock",
			clockText(MatchSystem.secondsLeft()),
			if phase == "Running" then "TIME" else "LEFT",
			Style.LOOK.PAPER
		)
	end
	chip("Boars", if snapshot.boarsLeft ~= nil then tostring(snapshot.boarsLeft) else nil, "BOARS", Style.LOOK.PAPER)

	-- THE ROLE PILL. `Hud.roleBadge` is the one place the word is decided; the colour beside it is
	-- `Style.teamColor`'s, which is the one place a team becomes a colour.
	local badge = Hud.roleBadge(team)
	local pill, pillText = statusPill, statusPillText
	if pill ~= nil and pillText ~= nil then
		local show = badge ~= ""
		pill.Visible = show
		if show then
			local tint = Style.teamColor(team)
			pill.BackgroundColor3 = tint
			pillText.TextColor3 = tint
			local edge = pill:FindFirstChildOfClass("UIStroke")
			if edge then
				edge.Color = tint
			end
			pillText.Text = Style.spaced(badge)
			table.insert(statusWords, badge)
		else
			pillText.Text = ""
		end
	end

	-- THE BALANCE, IN EVERY PHASE (task 170). Karen, 2026-10-11: *"get money"* -- and a currency you
	-- cannot see between drives is one a player cannot count. `""` with the flag off, so the bar
	-- carries no coins column at all in that state.
	--
	-- ...AND THE PHONE DROPS IT WHILE A DRIVE IS RUNNING (§4.2 item 1): coins live on the pad and in
	-- the shop, and during a drive the clock and the count are what matter. A CHIP IS DROPPED WHOLE
	-- AND NEVER SHRUNK, which is §3.9's rule and what keeps a caption from stacking one letter per
	-- line at 400 px.
	local coins = Hud.coinsText(snapshot, Players.LocalPlayer.UserId)
	local dropCoins = Style.isPhone(viewX) and phase == "Running"
	if coins ~= "" and not dropCoins then
		-- `Hud.coinsText` answers "COINS 2000" -- the LABEL first -- and the chip wants the number
		-- and the word apart, with the number leading (§3.9: *"the caption sits AFTER the number"*).
		-- AN UNKNOWN BALANCE DRAWS NO CHIP AT ALL rather than `--`, which is §3.9's own rule and is
		-- the one behaviour change here: the old bar printed `COINS --`.
		local amount = string.match(coins, "(%S+)$")
		if amount == Drive.CONFIG.SCORE_COINS_UNKNOWN then
			amount = nil
		end
		chip("Coins", amount, Drive.CONFIG.SCORE_COINS_LABEL, Style.LOOK.COIN_TEXT)
	else
		chip("Coins", nil, nil)
	end
	if statusCoin then
		local entry = statusChips.Coins;
		(statusCoin :: Frame).Visible = entry ~= nil and entry.chip.Visible
	end

	applyStatusDividers()
	bar.Visible = true
end

-- THE KILL LINE, AS A PURE FORMATTER (task 124). Karen: *"we need to show when is killed logg or
-- something similar"*, and her shape: who, which animal, where it was hit, how far.
--
--     KAREN         MALE BOAR   chest   42 m
--     <name,-12>    <KIND> BOAR <zone>  <metres> m
--
-- `animalKind == nil` -- which is what a world with `KINDS` off sends -- reads `BOAR` with no kind
-- word rather than `NIL BOAR`.
--
-- Exported and pure so a spec can assert the shape with no wire, no drive and no kill: the same
-- reason `Hud.crosshairVisible` and `Hud.renderScore`'s predicate are exported.
function Hud.killLineText(event): string
	local who = tostring((event and event.name) or (event and event.userId) or "?")
	local kind = event and event.animalKind
	local animal = if type(kind) == "string" and kind ~= "" then string.upper(kind) .. " BOAR" else "BOAR"
	local zone = tostring((event and event.zone) or "?")
	-- ...AND WHICH GUN (task 140). The WIRE carries the weapon's id and the SCREEN carries its word:
	-- `Weapons.row(id).label`, the same split `AMMO_LABEL` has. A record from before the rifle has
	-- no id, and prints nothing rather than the word "nil" -- the rule this function already follows
	-- for `animalKind`.
	local row = Weapons.row(event and event.weapon)
	local gun = if row ~= nil then " " .. row.label else ""
	return string.format("%-12s %-11s %-6s %d m%s", who, animal, zone, Report.metres(event and event.distance), gun)
end

-- WHAT ONE FEED ENTRY READS AS, or nil when another owner draws it. Exported for the same reason
-- `Hud.killLineText` is (task 124 round 3): the rule "a Match `kill` entry draws NO line, because
-- `HitLog`'s own line draws it with the animal's kind" is the whole of why one kill is not two, and
-- a local function cannot be asserted.
function Hud.feedTextFor(entry): string?
	local who = entry.name or (if entry.userId then tostring(entry.userId) else "")
	if entry.kind == "kill" then
		-- `Match`'s FEED OWNS THE DRIVE'S EVENTS -- escape, violation, join, leave. `HitLog`'s line
		-- OWNS THE KILL, in both worlds, over its own remote (design section 4.2): its line carries
		-- the animal's KIND, which Karen's report needs and which this entry has never had. Returning
		-- nil here is how the duplicate goes away without touching `src/server/Match/`, which is in
		-- TWO_PLAYER_PATHS and not in this task's blast radius.
		return nil
	elseif entry.kind == "escape" then
		return "a boar got away"
	elseif entry.kind == "violation" then
		return string.format("%s tied to a tree", who)
	elseif entry.kind == "join" then
		return string.format("%s joined", who)
	elseif entry.kind == "leave" then
		return string.format("%s left", who)
	elseif entry.kind == "signal" then
		-- THE DRIVE'S HORN DRAWS NO LINE (task 163). Its `text` is the server's word for WHICH
		-- signal it is ("start" / "end") and not something to read: `Hud.Sound.driveSignal` answers
		-- it, and the phase entry beside it ("Drive on", "Drive over") is what the feed says in
		-- words. Without this the feed would print the bare word "start".
		return nil
	end
	return tostring(entry.text or entry.kind)
end

-- EACH LINE IS ITS OWN TOAST, AND EACH CARRIES ITS OWN MEANING (§3.11). The per-line fade already
-- existed and is kept; what is new is that the dot and the words are coloured from ONE answer
-- (`Hud.feedMeaningFor`), so a kill cannot be green with a grey bullet beside it.
local function renderFeed(atClock: number)
	local cutoff = atClock - Drive.CONFIG.FEED_SECONDS
	while #feedEntries > 0 and feedEntries[1].at < cutoff do
		table.remove(feedEntries, 1)
	end
	while #feedEntries > Drive.CONFIG.FEED_LINES do
		table.remove(feedEntries, 1)
	end
	for index, line in ipairs(feedLines) do
		local entry = feedEntries[index]
		local toast = feedToasts[index]
		local dot = feedDots[index]
		line.Text = if entry then entry.text else ""
		line.Visible = entry ~= nil
		if toast ~= nil then
			toast.Visible = entry ~= nil
		end
		if entry ~= nil then
			local tint = Style.meaningColor(entry.meaning)
			line.TextColor3 = tint
			if dot ~= nil then
				dot.BackgroundColor3 = tint
			end
		end
	end
end

-- WHEN THE CROSSHAIR IS DRAWN, as a pure predicate so a spec can assert all eight combinations
-- without a camera, a gun or a flag (camera design section 6.2; the same reason Hud.renderScore and
-- Hud.onHitMarker are public).
--
-- Hidden while aiming: in ADS the gun's own line is the aiming reference, and leaving a hipfire
-- cross on top of it is the double-reticle mistake.
--
-- AND NEVER IN FIRST PERSON, at all, aiming or not (Karen, 2026-09-27: no crosshair at any time).
-- `firstPerson` comes from `Camera.isFirstPerson()` and NOT from a second `Flags.isOn` call: the
-- camera owns the switch and republishes it as a fact about the view, the Hud decides the drawing,
-- and there is one writer of the crosshair and one source for the fact.
-- THE ONE CONVERSION from an angle to pixels (task 140). Roblox's `FieldOfView` is the VERTICAL
-- angle, so a fraction of it is the same fraction of the viewport's height -- and `Camera.Config`'s
-- own `BEAD_CENTRE_TOLERANCE_DEG` comment measures the same thing the same way (50 degrees over
-- 1080 px). One site, which is the rule the task 19 cone-unit defect bought.
function Hud.reticleDegToPx(deg: number, fovDeg: number, viewportY: number): number
	if fovDeg <= 0 or viewportY <= 0 then
		return 0
	end
	return deg / fovDeg * viewportY
end

-- IS THE SCOPE'S RETICLE ON SCREEN? PURE, and a different question from the crosshair's: this one
-- is about the VIEW's optics (what `Camera.scope()` resolved for this frame) and the mode, and the
-- crosshair's is about the gun and first person. Two predicates, two questions -- the rule the
-- previous project's "one predicate answered two unrelated questions" is made of.
-- HAS THE SIGHT PICTURE ARRIVED? One number compared, and it is the blend rather than a clock: the
-- raise's own easing is what decides when the eye is at the glass. (This had the RETICLE's header
-- over it for one round -- a comment describing the function below the one it sat on.)
--
-- `blend` nil means "assume it has", which is what a caller without one means: the question THEY are
-- asking is the other half -- is this a scoped weapon at all.
local function eyepieceIn(optics: any, blend: number?): boolean
	local at = if optics ~= nil and optics.eyepiece ~= nil then optics.eyepiece.atBlend else nil
	if at == nil then
		return true
	end
	return (blend or 1) >= at
end

-- IS THE SCOPE'S SIGHT PICTURE ON SCREEN? PURE and public, and a THIRD question beside the
-- crosshair's and the reticle's: this one is "is the eye at the glass", and its answer blacks out
-- the screen, so it may never be the same predicate as "does this gun have a reticle".
function Hud.scopeVisible(mode: string?, optics: any, blend: number?): boolean
	if optics == nil or optics.eyepiece == nil or mode ~= "Aiming" then
		return false
	end
	return eyepieceIn(optics, blend)
end

-- IS THE SCOPE'S RETICLE ON SCREEN? PURE, and a different question from the crosshair's: this one
-- is about the VIEW's optics (what `Camera.scope()` resolved for this frame) and the mode, and the
-- crosshair's is about the gun and first person. Two predicates, two questions -- the rule the
-- previous project's "one predicate answered two unrelated questions" is made of.
--
-- IT WAITS FOR THE EYEPIECE (task 141): a duplex drawn over the gun half way through the raise is a
-- mark floating in the world, which is what the Director's frames of task 140 show.
function Hud.reticleVisible(mode: string?, optics: any, blend: number?): boolean
	return optics ~= nil and optics.reticle ~= nil and mode == "Aiming" and eyepieceIn(optics, blend)
end

-- THE EYEPIECE, LAID OUT IN PIXELS FROM ITS DEGREES -- the same conversion and the same
-- recompute-only-on-change rule as the duplex's.
local lastScopeFov, lastScopeX, lastScopeY, lastScopeSpec = -1, -1, -1, nil :: any
function Hud.layoutScope(overlay: Frame, optics: any, fovDeg: number)
	local camera = Workspace.CurrentCamera
	local spec = if optics ~= nil then optics.eyepiece else nil
	local viewport = if camera then camera.ViewportSize else Vector2.zero
	if spec == nil or viewport.Y <= 0 then
		return
	end
	-- THE WIDTH IS IN THE KEY TOO (the Reviewer's note, round 1): both the diameter clamp and the
	-- stroke's thickness are computed from X as well as Y, so a width-only resize must re-lay-out.
	if
		math.abs(fovDeg - lastScopeFov) < 1e-3
		and viewport.X == lastScopeX
		and viewport.Y == lastScopeY
		and spec == lastScopeSpec
	then
		return
	end
	lastScopeFov, lastScopeX, lastScopeY, lastScopeSpec = fovDeg, viewport.X, viewport.Y, spec
	-- THE CLAMP IS ON THE GLASS, NOT ON THE WHOLE CIRCLE (task 146, the Reviewer's finding 1). What
	-- must never run off the screen is the part you LOOK THROUGH -- a lens wider than the viewport
	-- would put the reticle's degrees somewhere off the edge and make the sight picture a lie. The
	-- SCOPE BODY around it may run off, and in Karen's own reference frame it does: the tube is cut
	-- by the top and bottom of the picture rather than floating inside it. Before this task the two
	-- were the same clamp, because the rim was a 0.45-degree hairline and the difference was a pixel.
	local rimPx = math.max(1, Hud.reticleDegToPx(spec.rimThickDeg, fovDeg, viewport.Y))
	local diameter = math.max(
		2,
		math.min(Hud.reticleDegToPx(spec.diameterDeg, fovDeg, viewport.Y), math.min(viewport.X, viewport.Y) + 2 * rimPx)
	)
	local mask = overlay:FindFirstChild("Mask")
	if mask and mask:IsA("Frame") then
		mask.Size = UDim2.fromOffset(diameter, diameter)
		local edge = mask:FindFirstChild("Edge")
		if edge and edge:IsA("UIStroke") then
			edge.Color = spec.maskColor
			-- ...AND IT IS NOT NECESSARILY OPAQUE (task 146). Karen's reference keeps the forest
			-- outside the scope body visible, just dark. `maskTransparency` nil is task 141's solid
			-- black, so every scope written before this task is unchanged.
			edge.Transparency = spec.maskTransparency or 0
			-- THE SCREEN'S DIAGONAL: the smallest thickness certain to reach every corner from the
			-- circle's edge, whatever the aspect ratio.
			edge.Thickness = math.ceil(math.sqrt(viewport.X * viewport.X + viewport.Y * viewport.Y))
		end
	end
	local rim = overlay:FindFirstChild("Rim")
	if rim and rim:IsA("Frame") then
		local inner = math.max(2, diameter - 2 * rimPx)
		rim.Size = UDim2.fromOffset(inner, inner)
		local edge = rim:FindFirstChild("Edge")
		if edge and edge:IsA("UIStroke") then
			edge.Color = spec.rimColor
			edge.Thickness = rimPx
		end
	end
end

-- THE WHOLE SIGHT PICTURE FOR THIS FRAME -- the mask, and the duplex on it.
--
-- IT IS ONCE A FRAME AND NOT ON AN EVENT (task 141), which is the second half of the Director's
-- "the scope view is wrong". Everything else in this file is event-driven, and `Camera.Changed`
-- fires on a MODE TRANSITION: at the instant `Third -> Aiming` arrives the blend is still 0, so a
-- sight picture that waits for the blend was computed exactly once, at the only moment it is false,
-- and never again. MEASURED in the Forest Test: the camera read fov 19.87 and the gun had already
-- taken itself out of the view, while the overlay was still hidden. This is the same reason the
-- compass has a `RenderStepped` of its own -- a thing that tracks the VIEW cannot be told by an
-- event about the MODE.
--
-- It is still called from `render` as well, so a mode change that happens between two frames (a
-- death, a weapon taken away) turns the mask off on that frame rather than the next.
--
-- The per-frame cost is two `FindFirstChild`s on the ScreenGui plus three camera reads and a
-- boolean; `layoutScope` and `layoutReticle` both return immediately unless the field of view, the
-- viewport or the spec actually moved. (The two lookups are counted here because this file throttles
-- its own staleness tick for exactly that kind of cost.)
function Hud.renderScope(CameraSystem)
	local reticle = Hud.reticle()
	local overlay = Hud.scopeOverlay()
	if reticle == nil and overlay == nil then
		return
	end
	local optics = if CameraSystem ~= nil and CameraSystem.scope then CameraSystem.scope() else nil
	local mode = if CameraSystem ~= nil then CameraSystem.getMode() else nil
	-- THE RAISE'S OWN PROGRESS, from the camera that is doing it. `getBlend` reads the state this
	-- frame resolved, so the mask arrives on the frame the eye does.
	local blend = if CameraSystem ~= nil and CameraSystem.getBlend then CameraSystem.getBlend() else nil
	-- THE FRAME'S OWN FIELD OF VIEW, not the weapon's target (the Reviewer's note, task 140 round
	-- 1): the mode is `Aiming` from the first frame of the raise while the blend is still easing, so
	-- laying the duplex out at `aimFovDeg` would draw the wrong degrees for the 0.2 s of
	-- `AIM_RAISE_SECONDS`. The camera is the one that knows what it is rendering.
	local camera = Workspace.CurrentCamera
	local liveFov = if camera then camera.FieldOfView else (if optics ~= nil then optics.aimFovDeg else nil) or 0
	if overlay ~= nil then
		local scoped = Hud.scopeVisible(mode, optics, blend)
		overlay.Visible = scoped
		if scoped then
			Hud.layoutScope(overlay, optics, liveFov)
		end
		-- THE COMPASS IS HIDDEN, NOT COVERED (task 141). A mask blacks out everything OUTSIDE the
		-- eyepiece, so no ZIndex in the world can take a mark that is drawn in the middle of the
		-- screen out of the glass -- and the compass strip is the one Hud element that is. MEASURED:
		-- with the mask at 11, over the compass's own 6-10, the band and its labels vanished and the
		-- red DRIVE marker and three ticks went on floating in the sight picture.
		--
		-- IT PUTS BACK EXACTLY WHAT IT HID, which is why the flag exists rather than a plain
		-- `not scoped`: the strip is invisible until `Compass.start` runs, and a Hud that switched
		-- it on would draw an empty band in a world that has no compass yet.
		--
		-- `compassFrame.Visible` therefore has TWO writers and that is deliberate (rule 3): both are
		-- in this file -- `Compass.start`'s single switch-on at boot, and this, per frame -- and
		-- `Compass` itself never touches it. It also self-heals: a strip switched on while the mask
		-- is in is hidden again on the next frame.
		local compass = Hud.compass()
		if compass ~= nil then
			if scoped then
				if compass.Visible then
					compassHiddenByScope = true
					compass.Visible = false
				end
			elseif compassHiddenByScope then
				compassHiddenByScope = false
				compass.Visible = true
			end
		end
		-- THE MAP IS HIDDEN TOO, AND BY A DIFFERENT MECHANISM ON PURPOSE (task 155, design section
		-- 3.3). The compass above needs the `compassHiddenByScope` flag because this file is a
		-- SECOND writer of its `Visible` and has to put back exactly what it hid. The map does not
		-- have that problem: this line STATES A NEED and `MapUi` performs the single write, which is
		-- this repo's own `Camera.Cursor.requestFree` pattern (borrowed once already by
		-- `Input.requestHold`). So `MapUi` stays the one writer of its own frames and nothing here
		-- has to remember what it did.
		--
		-- WHY HIDE IT AT ALL, when the minimap is in the corner and the eyepiece is in the middle:
		-- at 1080p the disc is well clear of the glass, but at 400 x 800 the eyepiece spans y
		-- 200..600 and the disc's bottom edge is at 204 -- four pixels inside. A minimap with its
		-- corner blacked out is worse than no minimap, and "is it outside the circle" is not
		-- provable at every viewport.
		MapUi.setSuppressed(scoped)
		-- ...AND THE OBJECTIVE LINE, THE WAYPOINT AND THE RAIL, on the same line and by the same
		-- mechanism (task 165). All three STATE A NEED and each module performs its own single write,
		-- so none of them needs the compass's `compassHiddenByScope` remember-what-I-hid arrangement.
		--
		-- WHY THE RAIL HIDES AT ALL, when it is at the right edge and the eyepiece is in the middle:
		-- the same measurement that put the map behind the mask -- at 400 x 800 the eyepiece spans
		-- y 200..600 and the rail runs 244..460, so it is INSIDE the glass on a phone. A sight picture
		-- with four buttons floating in it is the picture task 141 exists to prevent.
		Objective.setSuppressed(scoped)
		Rail.setSuppressed(scoped)
	end
	if reticle ~= nil then
		local visible = Hud.reticleVisible(mode, optics, blend)
		reticle.Visible = visible
		if visible then
			Hud.layoutReticle(reticle, optics, liveFov)
		end
	end
end

function Hud.scopeOverlay(): Frame?
	local screen = gui
	local found = screen and screen:FindFirstChild("ScopeOverlay")
	return if found and found:IsA("Frame") then found :: Frame else nil
end

-- THE DUPLEX, LAID OUT IN PIXELS FROM ITS DEGREES. Recomputed only when the field of view or the
-- viewport has changed -- two numbers compared -- so a scoped frame costs no more per-frame work
-- than an unscoped one.
-- ...AND WHICH SPEC IT DREW, not only at what size (the Reviewer's note, round 1): two scopes at
-- the same magnification with different reticles would otherwise reuse the first one's pixels.
local lastReticleFov, lastReticleY, lastReticleSpec = -1, -1, nil :: any
-- `optics` IS THE WHOLE SCOPE BLOCK SINCE TASK 146, not just `optics.reticle`: Karen's cross runs
-- from one side of the GLASS to the other, so the arms are a function of the eyepiece and the two
-- cannot be given separately without letting them disagree.
function Hud.layoutReticle(reticle: Frame, optics: any, fovDeg: number)
	local camera = Workspace.CurrentCamera
	local viewportY = if camera then camera.ViewportSize.Y else 0
	local spec = if optics ~= nil then optics.reticle else nil
	local eyepiece = if optics ~= nil then optics.eyepiece else nil
	if viewportY <= 0 or spec == nil then
		return
	end
	if math.abs(fovDeg - lastReticleFov) < 1e-3 and viewportY == lastReticleY and spec == lastReticleSpec then
		return
	end
	lastReticleFov, lastReticleY, lastReticleSpec = fovDeg, viewportY, spec
	local function px(deg: number): number
		return Hud.reticleDegToPx(deg, fovDeg, viewportY)
	end

	-- A RETICLE DRAWS WHAT ITS DATA CARRIES (task 146). Karen's reference has no ring around the
	-- centre, so her scope leaves `ringOuterDeg` out and this element simply is not there. The same
	-- rule the dot has followed since task 142, applied to the rest of the furniture.
	local ring = reticle:FindFirstChild("Ring")
	if ring and ring:IsA("Frame") then
		ring.Visible = spec.ringOuterDeg ~= nil and spec.ringOuterDeg > 0
		if ring.Visible then
			local outer = math.max(2, px(spec.ringOuterDeg))
			ring.Size = UDim2.fromOffset(outer, outer)
			local edge = ring:FindFirstChild("Edge")
			if edge and edge:IsA("UIStroke") then
				edge.Thickness = math.max(1, px(spec.ringThickDeg or 0.1))
				edge.Color = spec.color
			end
		end
	end

	-- Each bar hangs from the centre: a gap, then its own length, on its own side.
	local function place(
		name: string,
		vertical: boolean,
		sign: number,
		thickDeg: number?,
		armDeg: number?,
		gapDeg: number?
	)
		local bar = reticle:FindFirstChild(name)
		if not (bar and bar:IsA("Frame")) then
			return
		end
		if thickDeg == nil or thickDeg <= 0 or armDeg == nil or armDeg <= 0 then
			bar.Visible = false -- the data does not carry this element (task 146)
			return
		end
		bar.Visible = true
		local thick = math.max(1, px(thickDeg))
		local length = math.max(1, px(armDeg))
		local gap = px(gapDeg or 0)
		bar.BackgroundColor3 = spec.color
		if vertical then
			bar.Size = UDim2.fromOffset(thick, length)
			bar.Position = UDim2.new(0.5, 0, 0.5, sign * (gap + length / 2))
		else
			bar.Size = UDim2.fromOffset(length, thick)
			bar.Position = UDim2.new(0.5, sign * (gap + length / 2), 0.5, 0)
		end
	end

	-- EDGE TO EDGE, CUT TO THE GLASS (task 146). The eyepiece's own radius minus the tube's
	-- thickness is where the clear lens stops, so an arm of exactly that length starts at the centre
	-- and ends against the inside of the scope body -- which is Karen's reference line for line. The
	-- gap is zero, because a hair that stops short of the middle is a duplex and she asked for the
	-- other thing.
	local crossArm, crossGap = spec.crossArmDeg, spec.crossGapDeg
	if spec.spanLens then
		crossGap = 0
		-- NO EYEPIECE, NO LENS TO CUT TO -- but a reticle that asked to span one must still draw a
		-- cross rather than nothing (the Reviewer's note, round 1). Half the field of view reaches
		-- the edge of any screen, which is what "spans it" means with no glass in the way.
		crossArm = if eyepiece ~= nil
			then math.max(0.01, eyepiece.diameterDeg / 2 - (eyepiece.rimThickDeg or 0))
			else fovDeg / 2
	end
	place("CrossTop", true, -1, spec.crossThickDeg, crossArm, crossGap)
	place("CrossBottom", true, 1, spec.crossThickDeg, crossArm, crossGap)
	place("CrossLeft", false, -1, spec.crossThickDeg, crossArm, crossGap)
	place("CrossRight", false, 1, spec.crossThickDeg, crossArm, crossGap)
	-- THE POSTS START WHERE THE THIN CROSS ENDS, which is what a duplex IS: a thick bar from the
	-- edge of the view in to a point, and a hair from there to the centre. A reticle with no posts
	-- in its data has none drawn.
	local postGap = (crossGap or 0) + (crossArm or 0)
	-- THE DOT, IN THE SAME DEGREES (task 142). A weapon whose reticle carries no `dot` draws none,
	-- which is what keeps this one conversion honest for a scope that is a plain duplex.
	local function circle(name: string, deg: number?, color: Color3?, transparency: number)
		local node = reticle:FindFirstChild(name)
		if not (node and node:IsA("Frame")) then
			return
		end
		if deg == nil or deg <= 0 or color == nil then
			node.Visible = false
			return
		end
		node.Visible = true
		local size = math.max(1, px(deg))
		node.Size = UDim2.fromOffset(size, size)
		node.BackgroundColor3 = color
		node.BackgroundTransparency = transparency
	end
	-- `enabled = false` IS THE ONE LINE THAT TURNS IT OFF (task 146): Karen asked for the red dot
	-- and the reference she then sent has none, so it is a data toggle and not an argument.
	local dot = if spec.dot ~= nil and spec.dot.enabled ~= false then spec.dot else nil
	circle("DotHalo", dot and dot.haloDeg, dot and dot.haloColor, (dot and dot.haloTransparency) or 0.5)
	circle("Dot", dot and dot.deg, dot and dot.color, 0)

	place("PostTop", true, -1, spec.postThickDeg, spec.postArmDeg, postGap)
	place("PostBottom", true, 1, spec.postThickDeg, spec.postArmDeg, postGap)
	place("PostLeft", false, -1, spec.postThickDeg, spec.postArmDeg, postGap)
	place("PostRight", false, 1, spec.postThickDeg, spec.postArmDeg, postGap)
end

function Hud.reticle(): Frame?
	local screen = gui
	local found = screen and screen:FindFirstChild("Reticle")
	return if found and found:IsA("Frame") then found :: Frame else nil
end

function Hud.crosshairVisible(state, aiming: boolean, firstPerson: boolean): boolean
	if not Shotgun.CONFIG.CROSSHAIR_ENABLED or firstPerson or aiming then
		return false
	end
	return state ~= nil and state.equipped == true
end

-- WHEN THIS CLIENT SAW A BLAST, as a pure latch over three values. PURE AND EXPORTED because the
-- whole of it is an EDGE and an edge is exactly what a live case cannot arrange: `renderCorner`'s
-- only use of it is the one call below.
--
-- THE FIRST LOOK AT A TOOL STARTS NO CLOCK AND THE FIRST BLAST ALWAYS DOES. Both halves have been
-- got wrong once each in this task:
--   * round 1 started the clock on the first stamp it saw, so a horn handed back carrying a stamp
--     from an earlier drive read `WAIT` with an empty bar although it was ready -- this client does
--     not know WHEN that blast was, and a readiness bar that is wrong about readiness is worse
--     than none;
--   * round 2 gated that on `hornBlowSeen ~= nil`, which SWALLOWED the first blast of every fresh
--     horn, because a horn that has never been blown carries no attribute at all and nil is
--     therefore a real value of `seen`.
-- `primed` is the separate flag that makes both true, and it is the latch
-- `src/client/Camera/Viewmodel.luau` already uses for the same attribute.
function Hud.hornBlowLatch(
	seen: number?,
	primed: boolean,
	blowAt: number?,
	stamped: any,
	now: number
): (number?, boolean, number?)
	local value: number? = if type(stamped) == "number" then stamped else nil
	if not primed then
		-- The frame the Tool is first seen: remember what it carries, nil included, and start nothing.
		return value, true, blowAt
	end
	if value == seen then
		return seen, true, blowAt
	end
	-- ANY change after priming is a blast this client watched happen -- including nil -> 1, which is
	-- the player's own first blast on a brand-new horn.
	return value, true, if value ~= nil then now else blowAt
end

-- THE LOAD'S OWN ACCENT, one entry per `Style.glyph` shell kind (task 204). It is the HULL colour
-- the glyph is drawn in, so the word under a green shell is green and the word under a red one is
-- red: the chip says "slug" twice, in two ways, and a player who reads neither still has the
-- cluster against the single nose. A load with no shell keeps `FIELD_MUTED`, which is the caption
-- every chip wore before this task.
Hud.AMMO_ACCENT = {
	slug = Style.SHELL.slug.hull,
	buck = Style.SHELL.buck.hull,
}

-- WHAT THE AMMO CHIP SHOWS, AS DATA (§3.10 chamber pips). PURE and exported for the reason
-- `Hud.readoutFor` is: a spec can hand it a state it owns and assert the shape with no gun in the
-- world. `pips` is one entry per chamber -- "live", "spent" or "empty" -- `selected` is which one
-- the next trigger pull uses, `pocket` is the reserve the next load comes from, and `label` is the
-- shell's own word.
--
-- A MAGAZINE RIFLE IS NOT TWO BARRELS AND IS NOT DRAWN AS THEM (task 142's own lesson): its pips
-- are one per round the magazine holds, lit for the rounds actually in it, and nothing is selected.
function Hud.ammoChipFor(
	state: Shotgun.WeaponSnapshot,
	row: any?
): {
	pips: { string },
	selected: number?,
	pocket: number,
	label: string,
	glyph: string?,
	busy: boolean,
}
	local resolved = row or Weapons.row(state.weapon)
	local pips: { string } = {}
	local selected: number? = nil
	if resolved ~= nil and resolved.READOUT == "magazine" then
		local live = 0
		for _, chamber in ipairs(state.barrels) do
			if chamber == "Live" then
				live += 1
			end
		end
		local held = resolved.MAGAZINE or #state.barrels
		for index = 1, math.min(held, Hud.PIP_MAX) do
			table.insert(pips, if index <= live then "live" else "empty")
		end
	else
		for index, barrel in ipairs(state.barrels) do
			if index > Hud.PIP_MAX then
				break
			end
			table.insert(pips, if barrel == "Live" then "live" elseif barrel == "Spent" then "spent" else "empty")
		end
		selected = state.selected
	end
	local label = (resolved and resolved.AMMO_LABEL and resolved.AMMO_LABEL[state.ammo]) or string.upper(state.ammo)
	-- WHICH SHELL THIS LOAD IS (task 204), off the WEAPON'S row and not off the wire word: the wire
	-- says `Slug` for both guns, and the rifle's row names no glyph at all, so its chip is exactly
	-- the chip it has always had. nil is "draw no shell", never a wrong one.
	local glyph = if resolved ~= nil and resolved.AMMO_GLYPH ~= nil then resolved.AMMO_GLYPH[state.ammo] else nil
	return {
		pips = pips,
		selected = selected,
		pocket = state.reserve[state.ammo] or 0,
		label = label,
		glyph = glyph,
		busy = state.busyFor > 0,
	}
end

-- THE ONE WRITER OF THE BOTTOM-RIGHT CORNER, and the one place the "only one of the two" rule of
-- §4.3 is enforced: the horn wins, because a beater holding a gun is a bug and a beater with two
-- chips in one corner would hide it.
--
-- CALLED ONCE A FRAME. Everything else about the weapon is event-driven, but the two BARS are
-- clocks -- a reload and a horn cooldown -- and a clock drawn on an event is a clock that stops.
function Hud.renderCorner(Weapon)
	local ammo, horn = ammoChip, hornChip
	if ammo == nil or horn == nil then
		return
	end
	local state = if Weapon ~= nil then Weapon.get() else nil
	local now = os.clock()

	-- THE HORN. The Tool is the server's and so is the blast; this reads the attribute
	-- `Weapon.Horn.blowTool` stamps -- the one door every accepted blast goes through -- and starts
	-- its own clock from it. `Camera.Viewmodel` reads the same attribute for the same reason.
	local character = Players.LocalPlayer.Character
	local tool = if character then character:FindFirstChild(Horn.TOOL_NAME) else nil
	local hasHorn = tool ~= nil
	if hasHorn then
		local stamped = (tool :: any):GetAttribute(Horn.BLOW_ATTRIBUTE)
		hornBlowSeen, hornBlowPrimed, hornBlowAt =
			Hud.hornBlowLatch(hornBlowSeen, hornBlowPrimed, hornBlowAt, stamped, now)
	else
		hornBlowSeen = nil
		hornBlowAt = nil
		hornBlowPrimed = false
	end

	local showHorn = hasHorn
	local showAmmo = (not showHorn) and state ~= nil and state.equipped == true
	horn.Visible = showHorn
	ammo.Visible = showAmmo

	if showHorn then
		local word, caption, tint = "HORN", "READY", Style.LOOK.PAPER
		-- A BAR THAT IS FULL MEANS "YOU MAY BLOW IT". It empties the instant the server accepts a
		-- blast and fills over `Horn.CONFIG.COOLDOWN`, never the other way round (§7).
		local filled = 1
		if hornBlowAt ~= nil then
			filled = math.clamp((now - (hornBlowAt :: number)) / Horn.CONFIG.COOLDOWN, 0, 1)
			if filled < 1 then
				caption = "WAIT"
			end
		end
		if hornThrough then
			-- THE ONLY ON-SCREEN ANSWER TO "WHY DID MY HORN STOP WORKING" (§5 surface 7). A beater
			-- who is through the line is done, and a refusal is clay.
			word, caption, tint, filled = "THROUGH", "", Style.LOOK.CLAY, 0
		end
		if hornValue then
			(hornValue :: TextLabel).Text = word;
			(hornValue :: TextLabel).TextColor3 = tint
		end
		if hornCaption then
			(hornCaption :: TextLabel).Text = if caption == "" then "" else Style.spaced(caption)
		end
		if hornBarFill then
			local hornTrack = (hornBarFill :: Frame).Parent :: Frame
			if hornBody ~= nil then
				hornTrack.Size = UDim2.fromOffset((hornBody :: Frame).AbsoluteSize.X, 3)
			end
			(hornBarFill :: Frame).Size = UDim2.fromScale(filled, 1)
		end
	end

	if not showAmmo then
		-- NO GUN, NO READOUT (TASKS.md 35b(a)). The server publishes a reset state when it revokes a
		-- Tool, so a player tied to a tree stops reading an ammo count for a gun that is not in
		-- their hands -- and `Hud.readoutText` answers "" exactly then.
		readoutWords = ""
		reloadStartedAt = nil
		return
	end

	local snapshot = state :: Shotgun.WeaponSnapshot
	local data = Hud.ammoChipFor(snapshot)
	readoutWords = Hud.readoutFor(snapshot)
	for index, pip in ipairs(ammoPips) do
		local kind = data.pips[index]
		pip.Visible = kind ~= nil
		if kind == nil then
			continue
		end
		if kind == "live" then
			pip.BackgroundColor3 = Style.LOOK.PAPER
			pip.BackgroundTransparency = 0
		elseif kind == "spent" then
			pip.BackgroundColor3 = Style.LOOK.LINE
			pip.BackgroundTransparency = 0
		else
			pip.BackgroundColor3 = Style.LOOK.LINE
			pip.BackgroundTransparency = 0.6
		end
		local under = pip:FindFirstChild("Selected")
		if under ~= nil then
			(under :: Frame).Visible = data.selected == index
		end
	end
	if ammoValue then
		(ammoValue :: TextLabel).Text = tostring(data.pocket)
	end
	-- THE SHELL AND THE WORD SAY THE SAME THING (task 204): one glyph visible, and the word in that
	-- load's own hull colour. A row with no `AMMO_GLYPH` -- the rifle's -- shows neither shell and
	-- keeps the muted caption it has always had, which is why `Hud.AMMO_ACCENT` falls back to it.
	for kind, shell in pairs(ammoShells) do
		shell.Visible = data.glyph == kind
	end
	if ammoCaption then
		(ammoCaption :: TextLabel).Text = Style.spaced(data.label);
		(ammoCaption :: TextLabel).TextColor3 = Hud.AMMO_ACCENT[data.glyph or ""] or Style.LOOK.FIELD_MUTED
	end

	-- THE RELOAD BAR, PREDICTED FROM THIS CLIENT'S OWN CLOCK. `busyFor` is published once and
	-- nothing ticks it down between publications, so a bar driven straight off it would sit still
	-- and then vanish. Latched on the rising edge, which is also where its total comes from.
	local track, fill = ammoBarTrack, ammoBarFill
	if track ~= nil and fill ~= nil then
		if ammoBody ~= nil then
			track.Size = UDim2.fromOffset((ammoBody :: Frame).AbsoluteSize.X, 3)
		end
		if data.busy and reloadStartedAt == nil then
			reloadStartedAt = now
			reloadTotal = math.max(0.05, snapshot.busyFor)
		elseif not data.busy then
			reloadStartedAt = nil
		end
		local busy = reloadStartedAt ~= nil
		track.Visible = busy
		if busy then
			fill.Size = UDim2.fromScale(math.clamp((now - (reloadStartedAt :: number)) / reloadTotal, 0, 1), 1)
		end
	end
end

local function render(Weapon, CameraSystem)
	local state = Weapon.get()
	if crosshair then
		-- The Hud asks the CAMERA, which is the state, not the weapon's aim flag, which is the
		-- request -- and it asks the same camera which view this build is running.
		local aiming = CameraSystem ~= nil and CameraSystem.getMode() == "Aiming"
		-- NO CAMERA MEANS NO CROSSHAIR, AND THE ASYMMETRY IS DELIBERATE (task 123 round 7). `aiming`
		-- defaults to false because an unknown aim is a hipfire; `firstPerson` defaults to TRUE
		-- because Karen's rule is "no crosshair at any time" in first person and a question nobody
		-- can answer must not be the thing that overrides her. The crosshair exists for the
		-- third-person shoulder camera, so no camera system is also no third person to draw it for.
		local firstPerson = CameraSystem == nil or CameraSystem.isFirstPerson()
		crosshair.Visible = Hud.crosshairVisible(state, aiming, firstPerson)
	end
	-- THE SCOPE'S RETICLE, from the VIEW's own optics (task 140). `Camera.scope()` is what the
	-- camera resolved for this frame, so the Hud never reads the weapon table to decide whether to
	-- draw it -- exactly as it never reads the weapon to decide whether it is in first person.
	Hud.renderScope(CameraSystem)
	-- THE CORNER IS DRAWN BY ITS OWN WRITER (task 201). It is called here as well as once a frame,
	-- so a `Changed` event redraws the chip immediately rather than on the next tick.
	Hud.renderCorner(Weapon)
	-- ...AND THE RAIL LEARNS WHETHER THERE IS A GUN FROM THE SAME READ (task 165). One reader of the
	-- weapon state in this file; the rail is told and reads nothing. A button whose action cannot run
	-- is not drawn, which is the dispatch's "no dead buttons".
	Rail.setWeapon(state ~= nil and state.equipped == true)
end
-- ONE KILL, ONE LINE. The replica hears the server and fires `Killed`; this draws it. A NAMED
-- handler rather than a closure, exactly as `Hud.onHitMarker` is, so the client half of the kill log
-- can be driven in a spec instead of only by a live drive (task 124 round 3).
function Hud.onKilled(event)
	-- A KILL IS "YOU DID WELL", SO ITS DOT AND ITS WORDS ARE PINE (§3.11). The meaning travels WITH
	-- the entry and is resolved by the one pure mapping, so the line and the bullet beside it cannot
	-- end up two different colours -- which is what the first run of `hud_style.spec` caught: this
	-- call carried no meaning at all and a kill drew in `BODY`.
	table.insert(feedEntries, {
		text = Hud.killLineText(event),
		at = os.clock(),
		-- THROUGH THE MAPPING AND NOT A LITERAL `"good"` (round 1 note): "both writers carry it" is
		-- only true if both ask the same function.
		meaning = Hud.feedMeaningFor({ kind = "kill" }),
	})
	renderFeed(os.clock())
end

-- HOW LONG THE HUD WILL WAIT FOR A SYSTEM IT DRAWS, before it says out loud that it gave up.
-- Ten seconds, the same bound `CameraBoot` uses for the same race (task 133).
local LATE_MODULE_SECONDS = 10

-- WHICH BEARING THIS PLAYER'S COMPASS MARKS (task 153). PURE: the world's data and the team the
-- player is on, in; the bearing the drive marker sits at, out.
--
-- TWO DIRECTIONS, ONE FACT. `DRIVE_BEARING_DEG` is where the drive comes FROM and is what a hunter
-- watches; `PUSH_BEARING_DEG` is the way a beater walks, and the world derives the second from the
-- first so they can never disagree. A world that has said neither gets no marker at all, which is
-- what `Compass.setBearing(nil)` means and what every place but the Forest Test does.
-- IT ANSWERS THE WORD TOO (task 153 round 2, the Reviewer's blocking finding): a marker that moved
-- without its label told a beater the drive was south. nil for the label means "the compass's own
-- word", which is what a hunter and every other world get.
function Hud.driveBearing(data, team: string?): (number?, string?)
	if data == nil then
		return nil, nil
	end
	if team ~= nil and team == data.PUSH_TEAM then
		return data.PUSH_BEARING_DEG, data.PUSH_LABEL
	end
	return data.DRIVE_BEARING_DEG, nil
end

-- WHERE THE LOCAL PLAYER IS, flat, read off the engine and never cached (task 165). `MapUi`'s own
-- private `roster` reads the same state for its markers: two readers of the engine, no writer of
-- anything, and neither derives state from the other. nil means "no character yet" -- joining or
-- respawning -- and then there is no target at all, which is `MapUi.pointsFor`'s rule: *"a stale dot
-- is a lie about where somebody is"*.
function Hud.localPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character.PrimaryPart
	return if root then (root :: BasePart).Position else nil
end

-- WHAT THE COMPASS MARKER AND THE MAP ARROW POINT AT, WHICH IS THE SAME PLACE THE CHEVRON DOES
-- (task 165). PURE: the live target and the player's position in, a bearing and a word out.
--
-- THIS IS WHAT MAKES THE THREE PICTURES AGREE -- the dispatch's *"a marker that shows distance, plus
-- the minimap/compass agreeing with it"* -- while keeping EXACTLY ONE MARKER on a 360 px strip. A
-- second marker is clutter, and the dispatch forbids clutter in the same breath.
--
-- NO TARGET MEANS THE WORLD'S OWN ANSWER, UNCHANGED, which is `Hud.driveBearing`'s (where the drive
-- comes from, or the way a beater pushes). That is not a fallback, it is the right answer: a hunter
-- standing ON his stand has arrived, so the strip goes back to saying where the drive is coming
-- from, which is the thing he is actually watching.
--
-- NORTH IS +Z AND BEARINGS RUN CLOCKWISE THROUGH EAST (+X) -- `Compass.headingDeg`'s convention,
-- which was settled against a PHOTOGRAPH of four neon posts in task 129 and is written `atan2(x, z)`
-- in exactly one other place. This is the second, and `hud_clarity.spec` compares it against
-- `Compass.headingDeg` of the same vector rather than copying the expression into its own case.
function Hud.markerFor(target: any?, me: Vector3?, worldDeg: number?, worldLabel: string?): (number?, string?)
	if target == nil or me == nil then
		return worldDeg, worldLabel
	end
	local to = target.point
	local here = me :: Vector3
	local dx, dz = to.X - here.X, to.Z - here.Z
	if math.abs(dx) < 1e-6 and math.abs(dz) < 1e-6 then
		-- Standing exactly on it: a bearing to where you are is noise, so the world's answer stands.
		return worldDeg, worldLabel
	end
	return (math.deg(math.atan2(dx, dz)) + 360) % 360, target.word
end

-- THE ONE EVALUATION OF "WHAT MUST I DO, AND WHERE", AND THE ONE CALL TO EACH DRAWER (task 165).
--
-- Called once a frame from its OWN `RenderStepped` connection -- not the compass's, for the reason
-- task 141 wrote down about the scope: *"a scope that only worked in a world with a compass strip is
-- a bug waiting for the next place"*.
--
-- ONE RULE, ONE EVALUATION, THREE DRAWERS. The chevron, the compass marker and the map's target mark
-- are all written from the ONE `target` resolved here; two readers of one fact that could be handed
-- different teams is how task 153 round 2's finding (*"a marker that moved without its label told a
-- beater the drive was south"*) comes back. This function is now the only caller of
-- `Compass.setBearing` and `MapUi.setPush` after boot -- the `whenReady` closure in `Hud.start` used
-- to call both directly, and no longer does, so this REMOVES a two-writer arrangement.
--
-- `Hud.startCardVisible` IS THE ONE WRITER OF "IS A CARD UP", and it is called here with the same
-- snapshot and the same `ReportPanel.isOpen()` that `Hud.renderStartCard` calls it with. One
-- function, two callers, no second rule -- so the card and the objective line can never disagree
-- about whether a card is up, which is what lets the LINE stand down while the card says
-- `GET TO YOUR STAND` and the CHEVRON carry on (design section 5.4).
function Hud.renderObjective(CameraSystem)
	local snapshot = if matchSystem then matchSystem.get() else nil
	local phase = if snapshot then snapshot.phase else nil
	-- `Player.Team` IS THE ONE REPRESENTATION OF THE TEAM (`Match.myTeam`'s own header says so), and
	-- it is read directly when there is no match replica at all -- the Hud works with no drive,
	-- exactly as it works with no camera.
	local team = if matchSystem
		then matchSystem.myTeam()
		else (if Players.LocalPlayer.Team then Players.LocalPlayer.Team.Name else nil)
	local me = Hud.localPosition()
	-- WHAT THE LOBBY IS DOING RIGHT NOW (task 177): where the truck spot is, and how long until this
	-- player leaves for the hunt. One table per frame, built from the one definition of each -- the
	-- PART the server built, and the deadline the server wrote on this player.
	-- WHICH PAD IS ASKING THIS PLAYER, read ONCE a frame and used by three things: the dialog's
	-- visibility, the objective line standing down for it, and the camera's turn toward that pad's
	-- truck (task 197 part 2). Two reads would be two answers to one question.
	local asking = if lobbyData then lobbyData.padAsking(Players.LocalPlayer.UserId) else nil
	local lobby = if lobbyData
		then {
			spot = lobbyData.spotPosition(),
			secondsLeft = lobbyData.secondsLeft(
				Players.LocalPlayer:GetAttribute(lobbyData.LEAVE_AT_ATTRIBUTE),
				Workspace:GetServerTimeNow()
			),
			-- EVERY TRUCK PAD (task 182), so the chevron points at the NEAREST one. Four memoised
			-- part lookups and four `Position` reads -- the same order as the one subtraction
			-- `ShopPanel.setNear` below already costs this function.
			pads = lobbyData.padPositions(),
			-- ...AND WHETHER EITHER OF THE PAD'S PANELS IS UP (task 197 part 2), so the objective
			-- line can stand down for them. `asking` is the one read above and `loading` is the same
			-- attribute the banner itself is told from, so the line and the panels can never
			-- disagree about whether a panel is up.
			asking = asking,
			loading = Players.LocalPlayer:GetAttribute(lobbyData.PAD_MINE_ATTRIBUTE),
		}
		else nil
	-- IS HE AT THE SHOP COUNTER (task 178)? ONE EVALUATION, HERE, because this function is already
	-- *"THE ONE EVALUATION OF 'WHAT MUST I DO, AND WHERE', AND THE ONE CALL TO EACH DRAWER"* and it
	-- already holds both facts: where he is, and where the lobby's parts are. The panel is TOLD
	-- (`Rail.setWeapon`'s rule) and `setNear` is edge-triggered inside it, so this costs one
	-- subtraction a frame and one write per walk-in.
	ShopPanel.setNear(
		Shop.withinReach(me, if lobbyData then lobbyData.counterPosition() else nil, Shop.CONFIG.REACH_STUDS)
	)
	-- ...AND WHO OPENS IT (task 181). The shopkeeper's `ProximityPrompt` is the one way into the
	-- panel since this task took task 178's auto-open away, and it is resolved HERE for `setNear`'s
	-- own stated reason: one reader of the lobby's parts on this client, and a panel that is TOLD.
	-- `Lobby.shopPrompt()` is memoised and drops its cache with the instance, so this is a cached
	-- field read a frame and `ShopPanel.setPrompt` does nothing at all unless the prompt CHANGED.
	ShopPanel.setPrompt(if lobbyData then lobbyData.shopPrompt() else nil)
	-- ...AND ONE STEP OF THE SHOP WINDOW'S TURNING PICTURE (task 196). HERE, and not in a
	-- `RenderStepped` of its own, for this function's own stated reason: it is *"THE ONE EVALUATION"*
	-- and a second per-frame loop on this client would be a second owner of the frame. It returns
	-- immediately while the panel is shut, which is every frame of a hunt.
	ShopPanel.step()
	-- ...AND THE RAIL GETS OUT OF THE SHOP'S WAY ON A PHONE (task 196 part 3f, corrected in review
	-- round 1). On a 400-wide screen the panel is the whole screen and the MAP / REPORT column sits
	-- ON TOP of it.
	--
	-- IT STATES A NEED; `Rail` DOES THE WRITING. Part 3f wrote `railFrame.Visible` here, every
	-- frame, which made a second writer of another owner's frame -- and because it wrote `true`
	-- whenever the shop was shut, the first frame after a sight picture went up turned four buttons
	-- back on inside the eyepiece, undoing `Rail.setSuppressed` and beating `SHOW_ON_DESKTOP` with
	-- it. `Rail.setCovered` is edge-triggered, so this costs one comparison a frame and
	-- `Rail.applyVisibility` stays the one place `Visible` is written.
	local screen = Workspace.CurrentCamera
	Rail.setCovered(screen ~= nil and ShopPanel.hidesRail(screen.ViewportSize.X))
	-- ...AND WHETHER A TRUCK PAD IS ASKING HIM HOW MANY (task 182). ONE server-measured fact, read
	-- here for `setNear`'s own stated reason -- this function is already *"THE ONE EVALUATION"* --
	-- and the panel is TOLD. `setAsk` is edge-triggered inside it, so this costs four memoised part
	-- lookups and eight cached attribute reads a frame, and one write per walk-on. A world with no
	-- lobby asks nobody anything. (The REMOTE is resolved once in `Hud.whenReady`, not here: it
	-- waits, and nothing on a render tick may.)
	PadPanel.setAsk(asking)
	-- ...AND THE VIEW TURNS TO FACE THAT PAD'S TRUCK (task 197 part 2). The Director, after looking
	-- at the first frames: the truck is SOUTH of the pad and a player arrives facing NORTH, so the
	-- engine start, the headlights and the smoke all happened behind her.
	--
	-- **IT ASKS; THE CAMERA DECIDES.** `Camera.faceTowards` is a request of exactly the shape
	-- `Camera.lookAt` and `Cursor.requestFree` are -- it eases the turn over `FACE_TURN_SECONDS` and
	-- drops it the instant a mouse delta arrives -- and `Rig.apply` is still the one writer of
	-- `workspace.CurrentCamera`. Nothing here touches an angle.
	--
	-- ONCE PER WALK-ON, on the edge, through `facedPad`: a request every frame would be a camera
	-- that could never be turned away from.
	--
	-- IT IS THE *DIALOG'S* EDGE AND NOT THE PICK'S, and the limit is honest: the client is told which
	-- pad only while that pad is ASKING it (`DHPadFirst`). The first man on a pad is always asked, so
	-- he always gets the turn; a late joiner who was never asked is never told an index, and this
	-- does not invent one (the same limit that took the number off the banner's eyebrow).
	if asking ~= facedPad then
		facedPad = asking
		if asking ~= nil and CameraSystem ~= nil and lobbyData ~= nil then
			local truck = lobbyData.truckPosition(asking :: number)
			if truck ~= nil then
				CameraSystem.faceTowards(truck)
			end
		end
	end
	-- ...AND WHETHER A TRUCK IS ALREADY TAKING HIM (task 197). ONE server-measured fact again --
	-- `DHPadMine`, the state word of the pad he is loading onto -- read HERE for `setAsk`'s own
	-- stated reason, and the panel is TOLD both it and the seconds. The seconds are the ONES THIS
	-- FUNCTION ALREADY HAS: `lobby.secondsLeft` is converted three lines up for the objective line,
	-- so the banner's countdown and the line's countdown are the same number and cannot disagree
	-- (task 153 round 2's finding: *"a marker that moved without its label told a beater the drive
	-- was south"*). A world with no lobby is loading nobody.
	-- ...AND THE CLOCK, since task 209. The banner now goes up on the CLICK and comes back down if
	-- the server never answers, and the window that bounds that is measured in SECONDS -- so this
	-- function, which already has the only clock on this tick, hands one over rather than letting a
	-- renderer start one of its own.
	PadPanel.setLeaving(
		if lobbyData then Players.LocalPlayer:GetAttribute(lobbyData.PAD_MINE_ATTRIBUTE) else nil,
		if lobby then lobby.secondsLeft else nil,
		os.clock()
	)
	local target = Objective.targetFor(team, phase, MapUi.geometry(), me, lobby)
	local far = Objective.distanceStuds(target, me)
	arrivedAtTarget = Objective.arrived(far, arrivedAtTarget)
	if arrivedAtTarget then
		target = nil
	end

	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	-- THE ORIENTATION FROM THE CAMERA SYSTEM AND THE ANGLE FROM THE PROPERTY, and the asymmetry is
	-- deliberate: `Rig.apply` counts FOREIGN WRITES to `CurrentCamera.CFrame` and has warned about one
	-- since task 123, so the engine's CFrame is not reliably ours and `Camera.viewCFrame()`
	-- (`Rig.appliedCFrame`) is. There is no `appliedFov` accessor and adding one is a camera change;
	-- the field of view is read off the property, which is exactly what `Hud.renderScope` already
	-- does for the mask, and whose one writer is `Rig.apply`.
	local view = if CameraSystem ~= nil and CameraSystem.viewCFrame then CameraSystem.viewCFrame() else nil
	local fov = if camera then camera.FieldOfView else 70
	local reportOpen = ReportPanel.isOpen()
	local mapOpen = MapUi.isOpen()
	local scoped = Objective.isSuppressed()
	local cardUp = Hud.startCardVisible(snapshot, reportOpen)
	-- WHAT THE DRIVE IS DOING RIGHT NOW, read from the one replica and handed to the one pure rule
	-- (task 168). All three are local subtractions off server timestamps the snapshot already
	-- carries, so a beater's countdown ticks at render rate and costs no push.
	local drive = if matchSystem
		then {
			secondsLeft = matchSystem.secondsLeft(),
			holdLeft = matchSystem.holdSecondsLeft(),
			goAge = matchSystem.goAgeSeconds(),
			through = matchSystem.isThrough(),
		}
		else nil
	Objective.render({
		text = Objective.text(phase, team, drive, lobby),
		target = target,
		distanceStuds = far,
		view = view,
		fovDeg = fov,
		viewport = viewport,
		lineVisible = Objective.lineVisible(phase, team, reportOpen, mapOpen, scoped, cardUp, lobby),
		markVisible = Objective.markVisible(target, reportOpen, mapOpen, scoped, view ~= nil),
	})
	-- THE MAP GETS THE POINT, FLAT: it draws in x/z and has no use for the height.
	MapUi.setTarget(
		if target then Vector2.new(target.point.X, target.point.Z) else nil,
		if target then target.word else nil
	)
	local deg, word = Hud.markerFor(target, me, worldBearing, worldBearingLabel)
	if compassFrame then
		Compass.setBearing(deg, word)
	end
	MapUi.setPush(deg, word)
end

-- "NOT THERE YET" IS NOT "NOT THERE AT ALL", AND THAT WAS THE BUG (task 134).
--
-- `Hud.start` read `PlayerScripts.Match` with `FindFirstChild` -- on the line after it WAITED for
-- `PlayerScripts.Camera`, in a comment that describes this exact race and was written because of it
-- (task 123 round 7: the crosshair that would not go away). `PlayerScripts` is replicated, so when
-- `Match` had not arrived yet `MatchSystem` was nil FOR THE SESSION and none of the three
-- connections below was ever made: no drive bar, no clock, no feed, all drive, and not a word
-- anywhere saying why. It is the same shape as task 133's gunless session, in a different owner --
-- found while fixing that one and queued as TASKS row 133c.
--
-- SO IT CONNECTS WHENEVER THE MODULE LANDS: at once when it is already there -- which is the common
-- case and costs exactly the `FindFirstChild` it costs today -- and otherwise from a spawned wait,
-- so `Hud.start` is never blocked by a system the Hud is designed to work without. A module that
-- never arrives is a WARNING and not a silence.
--
-- IT TAKES THE CONTAINER AND THE NAME, not a module, because the thing being tested is the RACE:
-- a spec cannot create a requireable ModuleScript (`Source` is not writable outside a plugin), but
-- it can hand this a folder, add a child to it a moment later, and prove the callback still ran.
-- Returns whether the child was already there, which is what "did this cost a frame" means.
function Hud.whenReady(container: Instance, name: string, use: (Instance) -> ()): boolean
	local existing = container:FindFirstChild(name)
	if existing ~= nil then
		use(existing)
		return true
	end
	task.spawn(function()
		local late = container:WaitForChild(name, LATE_MODULE_SECONDS)
		if late == nil then
			warn(
				string.format(
					"[Hud] no %s.%s after %d s: the Hud will draw nothing for it this session (task 134)",
					container.Name,
					name,
					LATE_MODULE_SECONDS
				)
			)
			return
		end
		use(late)
	end)
	return false
end

-- EVERYTHING THE HUD DRAWS FROM THE DRIVE, AS ONE CALL. It was inline in `Hud.start`, which is why
-- it could only ever happen at start: pulled out so it can also happen a quarter of a second later,
-- when `Match` wins its race late. IDEMPOTENT -- a second call connects nothing twice, so the early
-- path and the late path cannot both land.
function Hud.useMatch(MatchSystem): boolean
	if matchConnected or MatchSystem == nil then
		return false
	end
	matchConnected = true
	matchSystem = MatchSystem
	-- THE PANEL READS THE SCORE OFF THE MATCH (design section 8.1), and it may already have been
	-- built with nothing. One setter, so a late match reaches it too rather than leaving the report
	-- without points for the session.
	ReportPanel.setMatch(MatchSystem)
	MatchSystem.Changed:Connect(function()
		renderDrive(MatchSystem)
	end)
	MatchSystem.Feed:Connect(function(entry)
		-- THE DRIVE'S HORN (task 163): a `signal` entry is a SOUND, and `Hud.Sound` is the one
		-- writer of it. No early return -- `feedTextFor` answers nil for it on its own, so the "no
		-- text, no line" rule below stays the only place that decides what is drawn.
		if entry.kind == "signal" then
			Sound.driveSignal(entry.text)
		end
		-- NO TEXT, NO LINE: `feedTextFor` answers nil for an entry another owner now draws.
		local text = Hud.feedTextFor(entry)
		if text ~= nil then
			-- ...AND ITS MEANING COMES WITH IT (task 201, §3.11): one pure mapping, read once here,
			-- so the dot and the words are one answer. An escape and a tie-to-a-tree are clay; a
			-- join or a phase line is `BODY`.
			table.insert(feedEntries, { text = text, at = os.clock(), meaning = Hud.feedMeaningFor(entry) })
			renderFeed(os.clock())
		end
	end)
	-- The timer is the one thing that has to be redrawn without an event, because it counts
	-- down locally from a server timestamp (docs/design/drive.md section 9.1). Once a second,
	-- not once a frame: the text only changes that often.
	local sinceTick = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceTick += dt
		if sinceTick < 0.25 then
			return
		end
		sinceTick = 0
		renderDrive(MatchSystem)
		renderFeed(os.clock())
	end)
	renderDrive(MatchSystem)
	return true
end

function Hud.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local scripts = player:WaitForChild("PlayerScripts")
	local Weapon = require(scripts:WaitForChild("Weapon"))
	-- `WaitForChild` AND NOT `FindFirstChild`, AND THAT WAS THE BUG (task 123 round 7). Karen, in a
	-- first-person session: *"why there is corss? we dont need a cross, I mentione crossing road"*.
	-- MEASURED in her own running client: `Camera.isFirstPerson()` answered TRUE and
	-- `HunterHud.Crosshair.Visible` was TRUE anyway -- because this line ran before the engine had
	-- copied `Camera` into `PlayerScripts` (it was the LAST of thirteen children in that session),
	-- so `CameraSystem` was nil, `firstPerson` read false, and the `CameraSystem.Changed` connection
	-- below was never made either, so nothing ever corrected it.
	--
	-- IT IS A RACE AND NOT A PROPERTY OF THAT WORLD: `WeaponBoot` and `CameraBoot` are two scripts
	-- with no defined order, so the DEV place is exposed to exactly the same one and has simply been
	-- winning it. A bounded wait keeps the old promise -- the Hud still works if the camera never
	-- arrives -- and removes the race. One-way: the camera has no reference to the Hud.
	local cameraModule = scripts:WaitForChild("Camera", 5)
	if cameraModule == nil then
		-- NEVER A SILENT NIL (task 134). The wait below is left exactly as task 123 round 7 measured
		-- it -- the Hud reads `CameraSystem` synchronously a few lines down, so this one cannot move
		-- to `whenReady` without moving what reads it -- but giving up is now said out loud.
		warn("[Hud] no PlayerScripts.Camera after 5 s: the crosshair will not follow the camera this session")
	end
	local CameraSystem = if cameraModule then require(cameraModule) else nil

	gui = build();
	(gui :: ScreenGui).Parent = player:WaitForChild("PlayerGui")

	-- One way: the server tells this client that something of theirs landed. The Hud never fires it.
	markerConnection = Shotgun.remotes().HitMarker.OnClientEvent:Connect(Hud.onHitMarker)

	-- THE DRIVE BAR, THE CLOCK AND THE FEED (task 134). The drive may not exist -- it is its own
	-- system, and 1.7a is the first task that ships it -- and the Hud works without it and simply
	-- draws no bar. But "not shipped" and "not replicated YET" are different things, and this line
	-- used to answer both with nil: see `Hud.whenReady`. One-way: the match has no reference to the
	-- Hud.
	Hud.whenReady(scripts, "Match", function(module)
		Hud.useMatch(require(module))
	end)

	-- THE KILL LOG (task 124). `PlayerScripts.Report` is the replica that hears the server; the Hud
	-- draws. It may not exist yet in a world that has not booted it, and the Hud works without it --
	-- the same shape as the camera and the match above.
	local reportModule = scripts:WaitForChild("Report", 5)
	if reportModule == nil then
		warn("[Hud] no PlayerScripts.Report after 5 s: there will be no kill log this session")
	end
	local ReportSystem = if reportModule then require(reportModule) else nil
	if ReportSystem then
		ReportSystem.Killed:Connect(Hud.onKilled)
	end

	-- TAB BELONGS TO THE ROBLOX PLAYER LIST ON PC, and a `ContextActionService` binding cannot take a
	-- CoreGui key -- so the stock list is turned off and the key becomes ours. The Hud is the ONE
	-- writer of `SetCoreGuiEnabled` (it already owns screen space) and this is its only call.
	--
	-- `pcall`, because `SetCoreGuiEnabled` is one of the calls that errors when the CoreGui is not
	-- ready yet, and a Hud that fails to boot over a player list is a blank screen -- the exact
	-- failure `docs/PROJECT_CONTEXT.md` records twice.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)

	-- THE REPORT PANEL, handed its frame and its collaborators. Every one of them may be nil and the
	-- panel says so in its own header: with no camera there is no `Cursor`, and then the keyboard is
	-- the only way to drive it -- which is why the keyboard path exists.
	-- THE COMPASS, AND WHERE ITS DRIVE BEARING COMES FROM (task 125).
	--
	-- THE WORLD STATES IT AND THE HUD DRAWS IT. `ForestTest.DRIVE_BEARING_DEG` is derived in that
	-- world's own data from `DRIVERS.startNorthStuds` -- the beaters begin 700 studs north of the
	-- road -- so the HUD never works out a direction from a position. Any other world has not said
	-- yet, and then the strip is a plain compass with no marker rather than a marker pointing at a
	-- guess; `Compass.setBearing` is the one line a later Match drive needs.
	-- ONCE A FRAME, FOR THE SIGHT PICTURE (task 141): see `Hud.renderScope`. Its own connection
	-- rather than the compass's, because the compass's lives inside `if compassFrame then` and a
	-- scope that only worked in a world with a compass strip is a bug waiting for the next place.
	if CameraSystem then
		RunService.RenderStepped:Connect(function()
			Hud.renderScope(CameraSystem)
		end)
	end

	-- THE MAP (task 155). Karen: *"I am missing map, we need a map when click M"*. It is started
	-- BEFORE the bearing closure below, because that closure hands it the push direction.
	--
	-- IN THE DEV WORLD THE GEOMETRY IS READY NOW: `Map` is required synchronously at the top of this
	-- file. In the Forest Test it arrives with `ForestTest`, through the same `whenReady` door the
	-- compass's bearing uses -- `MapUi.setGeometry` is public exactly so it can be told later.
	if miniMapFrame ~= nil and fullMapFrame ~= nil then
		MapUi.start({
			miniMap = miniMapFrame :: Frame,
			fullMap = fullMapFrame :: Frame,
			-- THE LEGEND IS THE MAP'S (task 165), handed over with its two frames: the Hud created it
			-- and `MapUi` is the one writer of everything inside it. The standalone touch button that
			-- used to be this field is gone -- it is `Hud.Rail`'s first button now
			-- (`backups/2026-10-12_mapui-touch-button.txt`).
			legend = mapLegendFrame,
			rail = railFrame,
		}, {
			-- FOR `viewHeadingDeg` ONLY, and it may be nil: then there is no facing wedge and the
			-- rest of the map is unchanged. One-way, like every other thing the Hud reads.
			Camera = CameraSystem,
			-- READ, NEVER WRITTEN: `ReportPanel.isOpen()`, so two full-screen panels are never up at
			-- once -- the reason `Hud.scorePanelVisible` already takes `reportOpen`.
			Report = ReportPanel,
			geometry = if Map.EXPECTED_WORLD == "forest-test"
				then nil
				else MapUi.geometryFor(Map.EXPECTED_WORLD, nil, Map),
			userId = player.UserId,
		})
	end

	-- THE WORLD'S DIRECTION AND ITS WORD, RESOLVED ONCE AND HANDED TO BOTH DRAWERS (task 155).
	--
	-- IT IS NO LONGER INSIDE `if compassFrame then`, and that is deliberate: this closure now feeds
	-- the map as well, and a map whose push arrow only worked in a world that happens to have a
	-- compass strip is the bug task 141 fixed for the scope (*"a scope that only worked in a world
	-- with a compass strip is a bug waiting for the next place"*).
	--
	-- ONE RULE, ONE EVALUATION, TWO DRAWERS. `Hud.driveBearing` is called here and nowhere else:
	-- two readers of one fact that could be handed different teams is how task 153 round 2's
	-- finding (*"a marker that moved without its label told a beater the drive was south"*) comes
	-- back.
	local bearing = nil
	-- ...and the WORD under the marker, which travels with it (task 153 round 2).
	local bearingLabel = nil
	if Map.EXPECTED_WORLD == "forest-test" then
		-- WAITED FOR, FOR THE SAME REASON AS THE MATCH (task 134). This was the Hud's SECOND
		-- `FindFirstChild` on a replicated module, found by the sweep this task asked for, and it
		-- fails the same silent way: no `ForestTest` yet means no bearing, and a compass with no
		-- DRIVE marker on it is the thing Karen asked for in task 125 -- *"we need to indicate
		-- from what side drive is comming"* -- quietly not there. `Compass.setBearing` is public
		-- exactly so it can be told later; in the common case this closure runs here and now, and
		-- `Compass.start` further down sets the same number again.
		-- ...AND A BEATER'S MARKER IS THE ROAD (task 153). Karen, 2026-10-11: *"beater are behind
		-- animals and moving towards hunter line (road) like in real life"* -- so the direction
		-- that matters to her is the one she is PUSHING, which is the opposite of the one the
		-- drive comes from. `Hud.driveBearing` is the whole rule and it is pure.
		--
		-- `player.Team` IS THE ONE REPRESENTATION OF THE TEAM, which is the same door
		-- `Match.myTeam` reads (and says so in its own header); the client match system does not
		-- boot in this world at all, so there is nothing else to ask. Re-read on change, because
		-- `/beater` switches the team mid-session and a marker that still pointed north would be
		-- a lie in the shape of a fact.
		Hud.whenReady(ReplicatedStorage, "ForestTest", function(module)
			local data = require(module)
			-- THE MAP'S GEOMETRY COMES OFF THE SAME MODULE, through the same door. `setGeometry` is
			-- idempotent and builds once.
			--
			-- ...AND IT IS REDRAWN WHEN THE DRIVE LAYOUT CHANGES (task 179). This world deals one of
			-- several layouts per drive, so the geometry is a function of a string the SERVER
			-- publishes on the module's own Rojo-owned `Live` child -- the client never chooses and
			-- never derives, because a map drawn on a layout the hunter is not standing on is wrong
			-- in a way no screenshot shows.
			--
			-- `MapUi.setGeometry` IS STILL THE ONE WRITER of the map's geometry (task 165's rule);
			-- this is a second CALLER of a public door, not a second drawer.
			-- WAITED FOR, NOT ASKED FOR ONCE (round 3's note). `whenReady` fires when the MODULE
			-- has replicated, and its Rojo-owned `Live` child is a separate instance that may not
			-- have arrived in the same frame -- in which case a `FindFirstChild` answers nil for the
			-- session, the warn fires and the hunter has no map for the whole drive. That is round
			-- 1's finding 4 in another shape, and the fix is the door Roblox already provides.
			-- `Flags` is the cited precedent for the HOST's shape, not for how it is found: it waits
			-- on the attribute, which is a different question.
			--
			-- BOUNDED, because an unbounded `WaitForChild` in a closure would hang this branch of the
			-- Hud for ever in a world that really has no `Live` child, and the honest answer there is
			-- the warn below.
			local live = module:WaitForChild(data.LIVE_NAME, 10)
			local function drawMap()
				MapUi.setGeometry(
					MapUi.geometryFor(
						Map.EXPECTED_WORLD,
						data,
						Map,
						if live then live:GetAttribute(data.LAYOUT_ATTRIBUTE) else nil
					)
				)
			end
			drawMap()
			if live then
				live:GetAttributeChangedSignal(data.LAYOUT_ATTRIBUTE):Connect(drawMap)
			else
				warn(
					string.format(
						"[Hud] ReplicatedStorage.ForestTest.%s is missing: no map in this world",
						tostring(data.LIVE_NAME)
					)
				)
			end
			-- IT WRITES THE TWO LOCALS AND NOTHING DRAWN (task 165). It used to call
			-- `Compass.setBearing` and `MapUi.setPush` itself, which made two writers of each of
			-- those -- this closure and the per-frame pass. `Hud.renderObjective` is the one writer
			-- now and this is the one place the WORLD's answer is resolved, so a `/beater` mid-session
			-- still moves the marker: the next frame reads these.
			local function apply()
				local team = player.Team
				bearing, bearingLabel = Hud.driveBearing(data, if team then team.Name else nil)
				worldBearing, worldBearingLabel = bearing, bearingLabel
			end
			apply()
			player:GetPropertyChangedSignal("Team"):Connect(apply)
		end)
	end

	-- THE LOBBY (task 177), through the same `whenReady` door as `ForestTest` above and for the same
	-- reason: it is a world-specific module that may not have replicated yet, and the Hud is designed
	-- to work without it. It is read and never written -- the only thing the Hud asks it is where the
	-- truck spot is and how long this player has left.
	Hud.whenReady(ReplicatedStorage, "Lobby", function(module)
		lobbyData = require(module)
		-- THE PAD DIALOG'S REMOTE, RESOLVED HERE AND ONCE (task 182). It is NOT read in
		-- `renderObjective`, and that is a correctness point rather than a saving: `Lobby.remotes`
		-- is `Shop.remotes`' shape, `WaitForChild` included, and a `WaitForChild` on a render tick
		-- would block the frame -- for ever, in a world whose folder never arrives. This callback is
		-- the one place in this file that is allowed to wait, which is what `whenReady` is FOR.
		PadPanel.setRemotes((lobbyData :: any).remotes())
	end)

	-- TASK 165: THE OBJECTIVE AND THE RAIL, started after the map because the per-frame pass below
	-- hands the map its target and the rail is laid out under the minimap.
	if objectiveLine ~= nil and waypointMark ~= nil and waypointWord ~= nil then
		Objective.start({
			line = objectiveLine :: TextLabel,
			slate = objectiveSlate,
			mark = waypointMark :: Frame,
			markLabel = waypointWord :: TextLabel,
		})
	end
	if railFrame ~= nil then
		Rail.start(railFrame :: Frame, {
			-- EVERY ONE OF THESE IS READ, NEVER CALLED BACK. A missing collaborator means that button
			-- is not built at all, which is the same rule as `needsWeapon`: no dead buttons.
			Map = MapUi,
			Report = ReportPanel,
			Input = Weapon.Input,
			touchEnabled = UserInputService.TouchEnabled,
		})
		-- IS THERE A GUN IN HAND? The Hud already reads `Weapon.get().equipped` for the ammo readout,
		-- so there is ONE reader of the weapon state here and the rail is TOLD. `render` below sets
		-- it every time the weapon changes; this is the first answer.
		local state = Weapon.get()
		Rail.setWeapon(state ~= nil and state.equipped == true)
	end

	-- ONE CONNECTION, OUTSIDE EVERY `if`, for the reason task 141 gives for the scope's own: a thing
	-- that only worked in a world with a compass strip is a bug waiting for the next place. The
	-- objective line and the waypoint exist in every world; what the WORLD has stated decides whether
	-- there is a target, and `Objective.targetFor` answers nil rather than guessing.
	RunService.RenderStepped:Connect(function()
		-- THE WINDOW FIRST, and it is one comparison when nothing moved. `Hud.build` runs before the
		-- engine has drawn a frame, when `Camera.ViewportSize` is still (1, 1), so the FIRST real
		-- frame is what puts the whole screen on the right step of the scale.
		Hud.applyViewportLayout(Hud.viewportX())
		Hud.renderObjective(CameraSystem)
		-- THE BOTTOM-RIGHT CORNER IN THE SAME PASS (task 201): the reload bar and the horn's
		-- readiness bar are CLOCKS, and a clock drawn on an event is a clock that stops.
		Hud.renderCorner(Weapon)
	end)

	if compassFrame then
		-- BOTH, OR `start` UNDOES THE WORD. In the common case the closure above has already run and
		-- `Compass.start` sets the bearing a second time; passing only the number would put a
		-- beater's marker back under the hunter's label on the first frame (task 153 round 2).
		Compass.start(compassFrame, bearing, bearingLabel)
		-- ONCE A FRAME, because it tracks the view: everything else in this file is event-driven,
		-- and a compass that updates on an event is a compass that lags the turn that caused it.
		-- `RenderStepped` is the client's own draw tick and this writes nothing but its own frame.
		RunService.RenderStepped:Connect(function()
			-- ASK THE SYSTEM THAT OWNS THE VIEW (task 125 round 3). Neither `CurrentCamera` (a second
			-- writer flips it) nor the character's body (in first person the camera turns the VIEW
			-- and not the body, so the strip never moved) is the view. `Camera.viewCFrame` is.
			-- See `Compass.headingFrom` for both measurements.
			Compass.render(Compass.headingFrom(CameraSystem))
		end)
	end

	-- THE SHOP PANEL (task 178), handed its frame, the two doors it borrows and its own remotes. Every
	-- collaborator may be nil and the panel says so in its own header: with no camera there is no
	-- `Cursor`, and then the mouse is the player's own problem -- which is why the `E` key exists.
	if shopFrame then
		ShopPanel.start(shopFrame :: Frame, {
			Cursor = if CameraSystem then CameraSystem.Cursor else nil,
			Input = Weapon.Input,
			remotes = Shop.remotes(),
		})
	end

	-- THE PAD DIALOG (task 182), handed its frame and the two doors it borrows. Its remotes are TOLD
	-- to it per frame instead (`PadPanel.setRemotes`), because `ReplicatedStorage.Lobby` is resolved
	-- by `Hud.whenReady` and may land after this runs.
	if padFrame then
		PadPanel.start(padFrame :: Frame, {
			Cursor = if CameraSystem then CameraSystem.Cursor else nil,
			Input = Weapon.Input,
			leaving = padLeavingFrame,
		})
	end

	if hitCardFrame then
		HitCard.start(hitCardFrame :: Frame, { Report = ReportSystem })
	end

	if reportFrame then
		ReportPanel.start(reportFrame, {
			Report = ReportSystem,
			Input = Weapon.Input,
			Cursor = if CameraSystem then CameraSystem.Cursor else nil,
			Match = matchSystem,
			userId = player.UserId,
			-- THE MODAL'S SCRIM, created with the rest of the screen and written by the panel: one
			-- owner of "is the report open", two frames that follow from it.
			scrim = reportScrimFrame,
		})
	end

	Weapon.Changed:Connect(function()
		render(Weapon, CameraSystem)
	end)
	if CameraSystem then
		CameraSystem.Changed:Connect(function()
			render(Weapon, CameraSystem)
		end)
	end
	render(Weapon, CameraSystem)
end

return Hud

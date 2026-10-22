--!strict
-- Hud.LicenceCard: THE CARD THAT SAYS *"NO DEER LICENCE"*, AND THE BUTTON THAT BUYS ONE (task 238).
--
-- KAREN, 2026-10-21, verbatim: *"if you dont have a license when you aim and what to shoot it shows
-- popup you dont have license and then you want to buy and roblox popup like they do to purchase"*.
--
-- IT DECIDES NOTHING, WHICH IS THE WHOLE OF ITS JOB (CLAUDE.md rule 3). Three facts arrive from
-- three owners that already exist and this module owns none of them:
--
--   * **is he aiming at something he may not shoot** -- `ServerScriptService.Weapon`. It casts ONE
--     ray (`lookAhead`, the same one the trigger casts) when the client asks on aim-on, and answers
--     in `WeaponSnapshot.advice`. This file reads that string and nothing else; it has no raycast,
--     no idea what a deer is and no copy of the licence rule.
--   * **what the card costs and whether he owns it** -- `Hud.ShopPanel`, off the server's own
--     `WireRow` (`ShopPanel.rowFor`). No second reader of a price: the amount shown is the one the
--     server sent, and until one has arrived the button shows no amount at all.
--   * **the purchase** -- `ShopPanel.press`, the client's ONE firer of `ShopRequest`, so this card
--     adds no second purchase writer at either end. The $ / Robux switch lives inside that one
--     function, not here.
--
-- WHAT IT OWNS: when the card is on screen, and nothing else. `LicenceCard.onAdvice` is the pure
-- edge-and-cooldown rule, so "once per aim-on, not every frame" is drivable with numbers.
--
-- **IT NEVER BLOCKS SHOOTING, AND THAT HALF IS TESTABLE.** No `Input.requestHold`, no cursor grab,
-- no modal scrim, no input binding: a player who ignores it keeps aiming and keeps pulling the
-- trigger, and the trigger does exactly what it did before this task.
-- `tests/client/licence_card.spec.luau` asserts `Input.isHeld()` is false while it is open.
--
-- **WHAT THE CARD SAYS IS WHAT THE GAME DOES, and the dispatch's own sentence is not** (the note's
-- section 1.1, Learning Agent L-073). Task 238's dispatch asked for *"shooting a deer without it
-- costs points"*. MEASURED: an unlicensed shot is a hard SERVER REFUSAL -- `Weapon.onFireRequest`
-- publishes `state` and not `fired` and returns before `setState`, so no shell is spent, no pellet
-- is cast and no hit happens, and its own comment reads *"No punishment -- Karen asked for none,
-- twice"*. There is no points cost anywhere in the repository. So `TEXT.WHY` says what is true, and
-- NOTHING in this task un-blocks the shot or adds a penalty. The Director's to overrule
-- (`ESCALATE.md`, 2026-10-22).
--
--   TextButton   https://create.roblox.com/docs/reference/engine/classes/TextButton
--   UIListLayout https://create.roblox.com/docs/reference/engine/classes/UIListLayout
--
-- Design: the Designer's design system, 2026-10-17 (`Hud.Style` is the one source for every colour,
--         face and size below; this file hard-codes none)
-- Note:   docs/research/2026-10-22-licence-popup-and-robux.md
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
local Money = require(ReplicatedStorage:WaitForChild("Money"))
local ShopData = require(ReplicatedStorage:WaitForChild("Shop"))

local Style = require(script.Parent.Style)

local LicenceCard = {}

-- THE ROW THIS CARD SELLS, FROM THE CATALOGUE AND NOT TYPED AGAIN. `Shop.ITEM.RED_STAG` is
-- `"licence.reddeer"`, and the id is what a saved purchase is stored under -- a literal here would
-- be the second copy of a key that `Shop.ITEM`'s own header refuses.
LicenceCard.ITEM = ShopData.ITEM.RED_STAG

-- WHICH GATE THIS CARD ANSWERS. One of `Weapon.Rules.REASON`, and the string is the WIRE VALUE the
-- server publishes in `WeaponSnapshot.advice`. It is NOT required from `ServerScriptService.Weapon`
-- -- a client cannot see that module -- so it is written here, once, and
-- `tests/server/licence_popup.spec.luau` asserts the two are the same string from the server's side.
LicenceCard.ADVICE = "no-licence"

-- THE ACTION THIS MODULE BINDS, AND THE PREFIX IS RESERVED TO IT -- `Weapon.Input`'s own rule
-- (*"a grep for `DrivenHunt.Weapon.` finds every binding it owns, and no other system may use it"*),
-- applied to the Hud's. `MapUi` binds `M` and `ReportPanel` binds Tab and five more, so a Hud module
-- binding its own key is this repository's pattern rather than a new one.
--
-- **IT IS BOUND ONLY WHILE THE CARD IS UP AND UNBOUND THE MOMENT IT COMES DOWN**, so `B` is the
-- player's own key for every other second of the game.
local BUY_ACTION = "DrivenHunt.Hud.LicenceBuy"

-- READ ONCE, AT THE BOUNDARY, exactly as `docs/design/feature-flags.md` section 11 step 2 requires
-- (`TIE_UNTIL_DRIVE_END = Flags.isOn(...)` is the shape it names). `LicenceCard.start` takes the
-- value as a parameter, so both states are reachable while the row sits at false.
LicenceCard.ENABLED = Flags.isOn("LICENCE_POPUP")

LicenceCard.CONFIG = table.freeze({
	-- 300 px: `PadPanel`'s measured width, which is what fits the 400 px phone `hud_clarity.spec`
	-- asserts. Not a new number.
	WIDTH = 300,
	-- ABOVE THE CROSSHAIR AND NOT OVER IT. 0.5 would sit the card on the reticle of the gun the
	-- player is aiming -- the one thing on screen he is using. 0.27 puts it in the upper third,
	-- clear of the reticle and clear of the top band.
	Y_SCALE = 0.27,
	-- Above the hit card and below a modal panel: it is a field surface over the world, and nothing
	-- it draws may cover the shop or the report if one is open.
	Z_INDEX = 6,
	-- 12 s BEFORE IT MAY SAY THE SAME THING AGAIN. Long enough that a man working a line of deer is
	-- told once rather than nagged; short enough that the next drive's first deer tells him again.
	-- Source 4 of the note has no number; this is ours, and Karen's to retune.
	REPEAT_SECONDS = 12,
	-- `B` FOR BUY, AND THE KEY IS WHY THE BUTTON IS USABLE AT ALL. In first person `Camera.Cursor`
	-- locks the mouse to the centre of the screen, so a `GuiButton` receives no click -- which is
	-- exactly why `Hud.Rail`'s on-screen buttons each carry a key chip and why `MapUi` is `M`. The
	-- button still works wherever the cursor is free (a phone's tap, and any unlocked state), and
	-- the key works always. `B` is free: the fifteen `Enum.KeyCode`s bound anywhere in `src/` are
	-- Backspace, E, M, R, Tab, X, Return, the four arrows and four gamepad buttons.
	BUY_KEY = Enum.KeyCode.B,
	-- 7 s AND THEN IT LEAVES BY ITSELF. It is ADVICE: it must not need a click to go away, and the
	-- hit card's own order of magnitude is the house rate for a card that fades.
	SHOW_SECONDS = 7,
})

-- EVERY WORD ON THE CARD, IN ONE TABLE, which is `Shop.CONFIG.TEXT`'s own arrangement: a string a
-- spec can assert and Karen can have rewritten without reading the drawing code.
LicenceCard.TEXT = table.freeze({
	TITLE = "NO DEER LICENCE",
	-- WHAT THE RULE ACTUALLY IS. See this file's header: the shot is REFUSED, it costs nothing, and
	-- it is not a penalty. One sentence, in the player's own words.
	WHY = "You cannot shoot red deer without it. The gun will not fire at one.",
	BUY = "BUY",
	-- WHILE NO `ShopState` HAS ARRIVED YET the price is not known, so the button says the word and
	-- no amount. It is never a guessed number: `Shop.Row.blurb`'s own rule, applied to a price.
	ASKING = "...",
	-- The shop said no. Its own line is printed instead (`Shop.NOTICE`), so the voice stays in one
	-- table and this card invents no refusal of its own.
	BOUGHT = "LICENCE BOUGHT",
	-- WHAT IS ACTUALLY TRUE OF THE CARD, and the first version of this line was not: it read
	-- *"Esc or wait"*, and **Escape is not bound and cannot be** -- it belongs to the Roblox menu,
	-- which `ReportPanel.bind`'s own comment says. The frame of 2026-10-22 is what caught it.
	-- `%s` is `CONFIG.BUY_KEY`'s own name, so the chip and the binding cannot drift.
	HINT = "%s to buy, or wait",
})

local stats = {
	advices = 0, -- every `onAdvice` call carrying this card's string
	shown = 0,
	suppressedRepeat = 0, -- within `REPEAT_SECONDS` of the last showing
	suppressedOwned = 0, -- he already holds the card
	suppressedOff = 0, -- the flag is off, or the shop is not wired in this world
	presses = 0,
	sent = 0,
	hides = 0,
}

local enabled = false
local root: Frame? = nil
-- THE CARD THIS MODULE BUILT INSIDE `root`, so `stop` can take it away again. Without it a restart
-- -- which is what every case in `licence_card.spec` does -- would stack a second card on the first
-- inside the Hud's own frame, and the spec would walk away leaving a pile of them in the live
-- player's screen.
local built: Frame? = nil
local titleLabel: TextLabel? = nil
local whyLabel: TextLabel? = nil
local buyButton: TextButton? = nil
local buyWord: TextLabel? = nil
local hintLabel: TextLabel? = nil
local closeNode: TextButton? = nil

-- THE COLLABORATORS, EVERY ONE OPTIONAL, which is `ShopPanel.start`'s own contract: a world with no
-- shop hands no `shop`, and then the card never shows (`suppressedOff`).
type Shop = {
	rowFor: ((string?) -> any)?,
	press: ((string?) -> boolean)?,
	isEnabled: (() -> boolean)?,
	-- `ShopPanel.ask`: the OPEN request, which is how this client gets a `ShopState` at all. A
	-- player who has never walked up to the counter has no wallet on this side, so the card has no
	-- price to print -- and `Shop.onRequest`'s `OPEN` is NOT gated on the counter (only `BUY` is),
	-- so asking from a drive is the door working as written rather than an exception to it.
	ask: (() -> ())?,
}
local shop: Shop? = nil

-- HAS THIS CARD ASKED FOR A WALLET YET? Once per session, so a licensed player aiming at deer all
-- afternoon sends one OPEN and not one per 12 s.
local asked = false
local shownAt: number? = nil -- when the card went up, or nil for "it is down"
local lastShownAt: number? = nil -- when it last went up, kept after it comes down
local message: string? = nil -- the shop's own last line, printed under the button

function LicenceCard.stats()
	return table.clone(stats)
end

function LicenceCard.frame(): Frame?
	return root
end

function LicenceCard.isVisible(): boolean
	return root ~= nil and root.Visible == true
end

function LicenceCard.isEnabled(): boolean
	return enabled
end

-- ---------------------------------------------------------------- the pure rules

-- WHAT THE BUTTON SAYS: the word, and the price only when the server has sent one. PURE, so the
-- "no state yet" case is a case rather than a race nobody can reproduce.
--
-- `row` IS THE SERVER'S OWN `WireRow` or nil. `Money.text` is the one formatter -- the `$` exists in
-- exactly one module (task 221) and this does not put one in front of a number itself.
function LicenceCard.buttonTextFor(row: any): string
	if type(row) ~= "table" or type((row :: any).price) ~= "number" then
		return string.format("%s  %s", LicenceCard.TEXT.BUY, LicenceCard.TEXT.ASKING)
	end
	return string.format("%s  %s", LicenceCard.TEXT.BUY, Money.text((row :: any).price))
end

-- MAY THE CARD GO UP? PURE, and it is the whole of "once per aim-on, with a cooldown".
--
-- The four answers, in order, and each is a different `suppressed*` counter above:
--   1. the advice is not this card's -- some other gate, or none;
--   2. he already owns the licence (the server would not have advised him, but a stale `advice`
--      arriving just after a purchase must not put the card up);
--   3. it went up less than `REPEAT_SECONDS` ago;
--   4. otherwise, yes.
--
-- A NIL `last` IS "NEVER SHOWN", which is always due -- the call `Input.aimAdviceDue` makes.
function LicenceCard.shouldShow(
	advice: any,
	owned: boolean?,
	last: number?,
	now: number,
	repeatSeconds: number?
): boolean
	if advice ~= LicenceCard.ADVICE then
		return false
	end
	if owned == true then
		return false
	end
	if type(now) ~= "number" then
		return false
	end
	if last ~= nil and now - last < (repeatSeconds or LicenceCard.CONFIG.REPEAT_SECONDS) then
		return false
	end
	return true
end

-- IS IT TIME TO COME DOWN? PURE. `shownAt` nil means it is already down.
function LicenceCard.expired(at: number?, now: number, showSeconds: number?): boolean
	if at == nil or type(now) ~= "number" then
		return false
	end
	return now - at >= (showSeconds or LicenceCard.CONFIG.SHOW_SECONDS)
end

-- ---------------------------------------------------------------- the drawing

local function build(frame: Frame)
	local viewX = Style.viewportX()
	local phone = Style.isPhone(viewX)

	-- `Style.card` IS THE HOUSE CARD: the panel colour, `CARD_T`, the brass edge, the corner radius
	-- and the inset, all from the one source. Nothing below picks a colour or a size of its own.
	local card = Style.card(frame, "Card", phone)
	card.Size = UDim2.fromScale(1, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.ZIndex = frame.ZIndex + 1

	-- THE LIST LIVES ON AN INNER FRAME, NOT ON THE CARD, AND THE FRAME OF 2026-10-22 IS WHY. A
	-- `UIListLayout` positions EVERY GuiObject sibling, so the close button -- which must sit in the
	-- top-right corner -- was laid out as a fifth row and drew over the title in the top LEFT. One
	-- box for the flow, one corner for the control that is not in it.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.fromScale(1, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.ZIndex = card.ZIndex + 1
	body.Parent = card

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, Style.SPACE.S)
	list.Parent = body

	local title = Style.label(body, "Title", "HEADING", viewX)
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, -Style.SPACE.XXL, 0, Style.sizeFor("HEADING", viewX) + 4)
	title.TextXAlignment = Enum.TextXAlignment.Left
	-- BLAZE, the game's own attention colour, at 17 px -- which is why `Style.LOOK`'s header says
	-- blaze over the world is used at 14 px and up.
	title.TextColor3 = Style.LOOK.BLAZE_HI
	title.Text = LicenceCard.TEXT.TITLE

	local why = Style.label(body, "Why", "BODY", viewX)
	why.LayoutOrder = 2
	why.Size = UDim2.fromScale(1, 0)
	why.AutomaticSize = Enum.AutomaticSize.Y
	why.TextWrapped = true
	why.TextXAlignment = Enum.TextXAlignment.Left
	why.TextColor3 = Style.LOOK.BODY
	why.Text = LicenceCard.TEXT.WHY

	-- THE BUTTON. `BUY_TOP` is the shop's own buy colour, so the one button in the game that takes
	-- money looks the same wherever it is.
	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Text = ""
	buy.AutoButtonColor = false
	buy.BackgroundColor3 = Style.LOOK.BUY_TOP
	buy.BorderSizePixel = 0
	buy.LayoutOrder = 3
	buy.Size = UDim2.new(1, 0, 0, Style.rowHeight(viewX) + Style.SPACE.M)
	buy.ZIndex = body.ZIndex + 1
	Style.corner(buy, Style.RADIUS.ROW)
	Style.stroke(buy, Style.LOOK.BLAZE_EDGE, 0)
	buy.Parent = body

	local word = Style.label(buy, "Word", "LABEL", viewX)
	word.Size = UDim2.fromScale(1, 1)
	word.TextXAlignment = Enum.TextXAlignment.Center
	word.TextColor3 = Style.LOOK.PAPER
	word.Text = LicenceCard.buttonTextFor(nil)

	local hint = Style.label(body, "Hint", "MICRO", viewX)
	hint.LayoutOrder = 4
	hint.Size = UDim2.new(1, 0, 0, Style.sizeFor("MICRO", viewX) + 2)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Style.LOOK.FAINT
	hint.Text = Style.spaced(string.format(LicenceCard.TEXT.HINT, LicenceCard.CONFIG.BUY_KEY.Name))

	-- THE CLOSE, THE HOUSE ONE. On the CARD and not in `body`, so the list layout above leaves it
	-- alone: top right, over the title's reserved gutter -- which is why the title's width is
	-- `1, -XXL` and not `1, 0`.
	local close = Style.closeButton(card, "Close")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.Size = UDim2.fromOffset(24, 24)
	close.ZIndex = card.ZIndex + 2

	-- THE TWO CONTROLS, WIRED. Both go through the SAME public functions a spec drives, so what the
	-- spec proves and what a tap does are one code path -- `Rail`'s own rule (*"`Activated` is still
	-- the only thing that RUNS anything"*).
	buy.Activated:Connect(function()
		LicenceCard.press()
	end)
	close.Activated:Connect(function()
		LicenceCard.hide()
	end)

	built = card
	titleLabel = title
	whyLabel = why
	buyButton = buy
	buyWord = word
	hintLabel = hint
	closeNode = close
end

-- WHAT THE PLAYER OWNS AND WHAT IT COSTS, ASKED OF THE ONE OWNER OF THAT PAYLOAD. nil for "no state
-- has arrived", which is every client that has not opened the shop yet.
local function rowNow(): any
	local current = shop
	if current == nil or current.rowFor == nil then
		return nil
	end
	local ok, row = pcall(current.rowFor :: any, LicenceCard.ITEM)
	-- A COLLABORATOR THAT THREW SAYS NOTHING, which is `Weapon.askTarget`'s own rule: a panel that
	-- errored must not be able to stop a card appearing, and must not remove the rule either.
	return if ok and type(row) == "table" then row else nil
end

local function shopOn(): boolean
	local current = shop
	if current == nil or current.isEnabled == nil then
		return false
	end
	local ok, on = pcall(current.isEnabled :: any)
	return ok and on == true
end

function LicenceCard.render()
	local node = root
	if node == nil then
		return
	end
	local row = rowNow()
	if buyWord then
		(buyWord :: TextLabel).Text = if message ~= nil then message else LicenceCard.buttonTextFor(row)
	end
	if buyButton then
		-- THE BUTTON GOES QUIET WHILE A MESSAGE IS ON IT: he has been answered, and a lit BUY under
		-- the shop's refusal would invite the same press again.
		(buyButton :: TextButton).BackgroundColor3 = if message ~= nil then Style.LOOK.ROW else Style.LOOK.BUY_TOP
	end
end

-- THE KEY IS BOUND ONLY WHILE THE CARD IS UP. Two call sites, `show` and `hide`, which are the two
-- places its visibility changes -- so `B` belongs to the player again the instant the card leaves,
-- and a card that never appeared never took a key at all.
local function bindBuyKey(on: boolean)
	if on then
		ContextActionService:BindAction(BUY_ACTION, function(_name, state)
			if state == Enum.UserInputState.Begin then
				LicenceCard.press()
			end
			-- `Pass`, DELIBERATELY, and it is `Weapon.Input`'s own rule applied here: this card must
			-- not swallow an input, because swallowing one is how an advisory card would start
			-- blocking something. Nothing else binds `B`, so passing costs nothing today and is the
			-- safe answer the day something does.
			return Enum.ContextActionResult.Pass
		end, false, LicenceCard.CONFIG.BUY_KEY)
	else
		ContextActionService:UnbindAction(BUY_ACTION)
	end
end

function LicenceCard.hide()
	local node = root
	shownAt = nil
	message = nil
	bindBuyKey(false)
	if node == nil or node.Visible == false then
		return
	end
	stats.hides += 1
	node.Visible = false
end

function LicenceCard.show(now: number?)
	local node = root
	if node == nil then
		return
	end
	local at = now or os.clock()
	stats.shown += 1
	shownAt = at
	lastShownAt = at
	message = nil
	LicenceCard.render()
	node.Visible = true
	bindBuyKey(true)
end

-- THE ONE DOOR THE SNAPSHOT COMES IN BY. `Hud` hands it `snapshot.advice` on every arriving weapon
-- snapshot, which is one call per publish and never a per-frame poll -- the arrangement
-- `CameraBoot`'s own `refused` reader states the reason for: *"an edge detector reading it every
-- frame would either miss it or repeat it"*.
function LicenceCard.onAdvice(advice: any, now: number?): boolean
	if advice ~= LicenceCard.ADVICE then
		return false
	end
	stats.advices += 1
	if not enabled or not shopOn() then
		-- OFF, OR A WORLD WITH NO SHOP AT ALL (task 235: `Shop.start` answers false where there is
		-- no counter, which is the DEV place). A card offering to sell a licence nothing can sell
		-- would be the shop window lying.
		stats.suppressedOff += 1
		return false
	end
	local at = now or os.clock()
	local row = rowNow()
	if row == nil then
		-- NO WALLET ON THIS SIDE YET, so no price. ASK FOR ONE, ONCE, and put the card up anyway
		-- with the word and no amount: the reply lands in a few tens of milliseconds and
		-- `onShopState` -> `render` fills the number in while he is still reading the title. A card
		-- held back until the price arrived would be a card that never appeared at all for a player
		-- who has never visited the lodge.
		local current = shop
		if not asked and current ~= nil and current.ask ~= nil then
			asked = true
			pcall(current.ask :: any)
		end
	end
	local owned = if type(row) == "table" then (row :: any).owned == true else nil
	if owned == true then
		stats.suppressedOwned += 1
		return false
	end
	if not LicenceCard.shouldShow(advice, owned, lastShownAt, at) then
		stats.suppressedRepeat += 1
		return false
	end
	LicenceCard.show(at)
	return true
end

-- THE CLOCK, ONCE A FRAME, and the only thing it does is take the card down. `Hud` already runs a
-- `RenderStepped` pass and calls this from it: a card that leaves by itself needs a clock, and a
-- clock driven by an event is a clock that stops (the Hud's own `renderCorner` rule).
function LicenceCard.step(now: number?)
	if shownAt == nil then
		return
	end
	if LicenceCard.expired(shownAt, now or os.clock()) then
		LicenceCard.hide()
	end
end

-- THE PRESS, AND IT SENDS NOTHING ITSELF. `ShopPanel.press` is the client's one firer of
-- `ShopRequest` and the one place the $ / Robux switch lives, so this card can neither charge a
-- player nor prompt Roblox: it asks the owner to.
--
-- PUBLIC AND NAMED, for `ShopPanel.press`'s own stated reason: a spec cannot fire
-- `GuiButton.Activated` and the harness cannot synthesise a tap, so this is the seam that makes the
-- button testable at all -- and what it proves is the ACTION, not the touch. That limit is reported.
function LicenceCard.press(): boolean
	stats.presses += 1
	local current = shop
	if current == nil or current.press == nil then
		return false
	end
	local ok, sent = pcall(current.press :: any, LicenceCard.ITEM)
	if not (ok and sent == true) then
		return false
	end
	stats.sent += 1
	return true
end

-- WHAT THE SERVER SAID ABOUT THE PURCHASE. `Hud` hands it the `ShopState` payload it already
-- receives; this card reads two fields of it and keeps none.
--
-- IT PRINTS THE SHOP'S OWN LINE AND NEVER ONE OF ITS OWN (`Shop.noticeFor`), so there is one voice
-- for a refusal wherever it is read -- the register `Rules.NOTICE` set.
function LicenceCard.onShopState(state: any)
	if not LicenceCard.isVisible() or type(state) ~= "table" then
		return
	end
	local bought = (state :: any).bought
	if bought == LicenceCard.ITEM then
		message = LicenceCard.TEXT.BOUGHT
		LicenceCard.render()
		return
	end
	local refused = (state :: any).refused
	if type(refused) == "string" then
		message = ShopData.noticeFor(refused, (state :: any).refusedNumber)
		LicenceCard.render()
	end
end

function LicenceCard.start(frame: Frame, collaborators: any)
	if root ~= nil then
		return
	end
	local given = if type(collaborators) == "table" then collaborators else {}
	-- THE FLAG, READ AT THE BOUNDARY AND PASSED INWARD -- and overridable by parameter, so both
	-- states are reachable while the row sits at false (feature-flags.md section 11 step 2).
	enabled = if (given :: any).enabled ~= nil then (given :: any).enabled == true else LicenceCard.ENABLED
	shop = (given :: any).Shop
	root = frame
	build(frame)
	frame.Visible = false
	LicenceCard.render()
end

function LicenceCard.stop()
	-- THE KEY GOES BACK TO THE PLAYER FIRST, whatever state the card was in: a module that stopped
	-- holding a binding would leave `B` dead for the rest of the session.
	bindBuyKey(false)
	-- WHAT THIS MODULE MADE, AND ONLY THAT. `root` is the Hud's frame and is NOT destroyed -- this
	-- module did not create it and `Hud.build` is its one owner (`ShopPanel.start`'s own division).
	if root ~= nil then
		(root :: Frame).Visible = false
	end
	if built ~= nil then
		(built :: Frame):Destroy()
	end
	built = nil
	root = nil
	titleLabel = nil
	whyLabel = nil
	buyButton = nil
	buyWord = nil
	hintLabel = nil
	closeNode = nil
	shop = nil
	asked = false
	shownAt = nil
	lastShownAt = nil
	message = nil
	enabled = false
	for key, value in pairs(stats) do
		if type(value) == "number" then
			stats[key] = 0
		end
	end
end

-- THE DRAWN PARTS, for a spec to read rather than to walk the PlayerGui for -- the arrangement
-- `HitCard.art` and `ShopPanel.rowFor` already use.
function LicenceCard.parts(): {
	title: TextLabel?,
	why: TextLabel?,
	buy: TextButton?,
	word: TextLabel?,
	hint: TextLabel?,
	close: TextButton?,
}
	return {
		title = titleLabel,
		why = whyLabel,
		buy = buyButton,
		word = buyWord,
		hint = hintLabel,
		close = closeNode,
	}
end

return LicenceCard

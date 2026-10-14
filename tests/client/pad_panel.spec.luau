-- pad_panel.spec: THE TRUCK PADS' SIZE DIALOG, on the client that draws it (task 182).
--
-- KAREN, 2026-10-14: *"you come to truck back rectangle and can click and select how many players
-- ... can be 1/1 or 4/4 you can select on dialiog how many like in roblox games"*.
--
-- WHAT IT CAN PROVE AND WHAT IT CANNOT, stated rather than discovered: a spec cannot fire
-- `GuiButton.Activated` and the harness's input scenarios cannot synthesise a tap
-- (`tools/studio_mcp.py`'s docstring: keys, mouse buttons, mouse moves and gaps only). So
-- `PadPanel.press` is the seam these cases drive -- `Rail.press`' and `ShopPanel.press`' own stated
-- limit -- and what they prove is the ACTION behind the button, not the touch that reaches it.
--
-- IT RUNS IN THE DEV PLACE, WHICH HAS NO LOBBY AT ALL (`Lobby.ANCHORS` has one row), so there is no
-- pad part, no attribute and no remote here. That is exactly why the panel is TOLD which pad is
-- asking (`PadPanel.setAsk`) instead of reading the world: the dialog is drivable with no lobby, and
-- a client that could decide it was first would be a client that could put eight strangers in a
-- truck.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/truck-pads.md (sections 8.1, 10.3)
-- Note:   docs/research/2026-10-14-truck-pads.md (section 5.4)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyData = require(ReplicatedStorage:WaitForChild("Lobby"))
local PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local Hud = require(PlayerScripts:WaitForChild("Hud"))

local PADS = LobbyData.CONFIG.PADS
local PANEL = PADS.PANEL

return function()
	describe("the truck pads' size dialog", function()
		local PadPanel = Hud.PadPanel

		-- THE LIVE PANEL, the one `Hud.build` made, because *"the panel reads"* is only a claim about
		-- the real thing. Each case restores the `ask` it found, so a spec cannot leave a dialog on
		-- Karen's screen.
		local restore: number? = nil

		beforeEach(function()
			restore = PadPanel.padIndex()
			PadPanel.setAsk(nil)
		end)

		afterEach(function()
			PadPanel.setAsk(restore)
		end)

		it("is built, hidden, and the right rectangle for a phone", function()
			local frame = Hud.padPanel()
			expect(frame).to.be.ok()
			local panel = frame :: Frame
			expect(panel.Visible).to.equal(false)
			-- ONE NUMBER DECIDES BOTH THE ROWS AND THE BOX (`ShopPanel.heightFor`'s rule, and the
			-- Reviewer's task-178 round-1 note: they used to be two, and a sixth row would have been
			-- drawn outside the frame in silence).
			expect(panel.Size.X.Offset).to.equal(PadPanel.widthFor())
			expect(panel.Size.Y.Offset).to.equal(PadPanel.heightFor())
			-- IT FITS A 400 px PHONE, which is the width `hud_clarity.spec` measures everything at.
			expect(PadPanel.widthFor() <= 400).to.equal(true)
			-- `Rail.CONFIG.Z_INDEX` IS 16 AND STAYS PRESSABLE OVER IT -- the shop panel's own band.
			expect(PadPanel.zIndex()).to.equal(PANEL.Z_INDEX)
			expect(PANEL.Z_INDEX < 16).to.equal(true)
		end)

		it("opens because the SERVER asked, and closes when it stops asking", function()
			expect(PadPanel.isOpen()).to.equal(false)
			local before = PadPanel.stats().opens
			PadPanel.setAsk(2)
			expect(PadPanel.isOpen()).to.equal(true)
			expect(PadPanel.padIndex()).to.equal(2)
			expect((Hud.padPanel() :: Frame).Visible).to.equal(true)
			expect(PadPanel.titleText()).to.equal(PANEL.TITLE)
			-- EDGE-TRIGGERED: the same answer twice is one open.
			PadPanel.setAsk(2)
			expect(PadPanel.stats().opens).to.equal(before + 1)
			-- ...AND STEPPING OFF IS THE SERVER'S OWN CANCEL, not a second rule on this side.
			PadPanel.setAsk(nil)
			expect(PadPanel.isOpen()).to.equal(false)
			expect((Hud.padPanel() :: Frame).Visible).to.equal(false)
			-- ANYTHING THAT IS NOT A PAD NUMBER IS "NOBODY IS ASKING".
			PadPanel.setAsk("2" :: any)
			expect(PadPanel.isOpen()).to.equal(false)
		end)

		it("draws Karen's own four labels, in order, each big enough for a thumb", function()
			PadPanel.setAsk(1)
			local rows = PadPanel.rowText()
			expect(#rows).to.equal(#PADS.SIZES)
			for index, row in ipairs(PADS.SIZES) do
				-- THE LABEL IS THE DATA'S OWN. Karen wrote `1 / 1` and `4 / 4` herself, so the panel
				-- applies no format of its own -- which is what makes the words hers to retune.
				expect(rows[index]).to.equal(row.label)
			end
			-- 48 px OR MORE, over the 44 Roblox's own tutorial sets as a touch minimum. Measured off
			-- the real buttons rather than off the config, because what matters is what was BUILT.
			local frame = Hud.padPanel() :: Frame
			local found = 0
			for _, child in ipairs(frame:GetChildren()) do
				if child:IsA("TextButton") then
					found += 1
					expect((child :: TextButton).Size.Y.Offset >= 44).to.equal(true)
					expect((child :: TextButton).Size.Y.Offset).to.equal(PANEL.BUTTON_PX)
					-- AND NONE OF THEM IS WIDER THAN THE PANEL.
					expect((child :: TextButton).Size.X.Offset <= PadPanel.widthFor()).to.equal(true)
				end
			end
			expect(found).to.equal(#PADS.SIZES)
			-- THERE IS NO CLOSE BUTTON, AND THAT IS DELIBERATE: `1 / 1  alone` is the "leave me
			-- alone" button, stepping off the pad is the other exit, and the eight-second timeout
			-- does it by itself -- so the dialog can never be a dead end.
			expect(frame:FindFirstChild("Close")).to.equal(nil)
		end)

		it("sends ONE message per press, naming the pad the server asked about", function()
			local sent: { any } = {}
			PadPanel.setRemotes({
				PadRequest = {
					FireServer = function(_self, payload: any)
						table.insert(sent, payload)
					end,
				},
			})
			-- NO ASK, NO MESSAGE: the dialog cannot be pressed when nobody is being asked.
			expect(PadPanel.press(4)).to.equal(false)
			expect(#sent).to.equal(0)

			PadPanel.setAsk(3)
			expect(PadPanel.press(4)).to.equal(true)
			expect(#sent).to.equal(1)
			-- THE PAYLOAD IS TWO NUMBERS AND NOTHING ELSE. The server measures everything else off
			-- the character it can see, so anything extra here would be a field nobody reads.
			expect(sent[1].pad).to.equal(3)
			expect(sent[1].size).to.equal(4)
			local fields = 0
			for _ in pairs(sent[1]) do
				fields += 1
			end
			expect(fields).to.equal(2)

			-- A DOUBLE TAP IS ONE MESSAGE.
			expect(PadPanel.press(4)).to.equal(false)
			expect(#sent).to.equal(1)

			-- A SIZE THAT IS NOT IN THE DATA IS NOT SENT AT ALL. The server would count it as a
			-- forgery, and a client that sent one would be lying about its own catalogue.
			expect(PadPanel.press(3)).to.equal(false)
			expect(PadPanel.press(99)).to.equal(false)
			expect(#sent).to.equal(1)

			-- A NEW PAD IS A NEW QUESTION, so the size already sent is forgotten with the old one --
			-- without which, stepping off pad 3 after picking 4 and onto pad 1 would leave the dialog
			-- unable to send anything.
			PadPanel.setAsk(1)
			expect(PadPanel.press(4)).to.equal(true)
			expect(#sent).to.equal(2)
			expect(sent[2].pad).to.equal(1)
			PadPanel.setRemotes(nil)
		end)

		it("asks for the mouse and holds the trigger under its own name, and hands both back", function()
			-- BOTH DOORS ARE REASON-KEYED, so this dialog releases exactly its own request and never
			-- the shop's or the report's (`ShopPanel.setOpen`'s shape, tag `"padsize"`). Without the
			-- hold, the click that picks a party size would also fire the gun.
			local freed: { string } = {}
			local released: { string } = {}
			local held: { string } = {}
			local unheld: { string } = {}
			PadPanel.stop()
			PadPanel.start(Instance.new("Frame"), {
				Cursor = {
					requestFree = function(reason: string)
						table.insert(freed, reason)
					end,
					release = function(reason: string)
						table.insert(released, reason)
					end,
				},
				Input = {
					requestHold = function(reason: string)
						table.insert(held, reason)
					end,
					releaseHold = function(reason: string)
						table.insert(unheld, reason)
					end,
				},
			})
			PadPanel.setAsk(2)
			expect(freed[1]).to.equal("padsize")
			expect(held[1]).to.equal("padsize")
			expect(#released).to.equal(0)
			PadPanel.setAsk(nil)
			expect(released[1]).to.equal("padsize")
			expect(unheld[1]).to.equal("padsize")

			-- ...AND THE LIVE PANEL IS PUT BACK, because this case took it over. `PadPanel.stop` EMPTIES
			-- the frame it was given (the Reviewer's round-1 note: without that, re-starting on the
			-- live frame left it with doubled children), so the re-start below rebuilds exactly one
			-- title and four buttons -- and the assertion is what proves it rather than the comment.
			PadPanel.stop()
			local frame = Hud.padPanel()
			expect(frame).to.be.ok()
			PadPanel.start(frame :: Frame, { remotes = nil })
			local rebuilt = 0
			for _, child in ipairs((frame :: Frame):GetChildren()) do
				if child:IsA("TextButton") then
					rebuilt += 1
				end
			end
			expect(rebuilt).to.equal(#PADS.SIZES)
		end)
	end)
end

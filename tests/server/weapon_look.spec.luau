-- weapon_look.spec: the gun's SHAPE, and the Tool that is actually built from it (Task 71).
--
-- TWO HALVES, and the split is the same one map_contract.spec makes about the wood: the first half
-- asserts the pure list (`Weapon.Shape.pieces`) against the published dimensions of the gun Karen
-- asked for, and the second BUILDS a real Tool with `Weapon.Hardware.build()` and asserts what came
-- out -- because a list nobody builds is a claim about arithmetic, and Task 68 was the last time
-- that distinction cost a round.
--
-- Every number here is written out rather than imported from the module under test: a spec that
-- reads `Shape.BARREL_FRACTION` and asserts the barrel is `total * Shape.BARREL_FRACTION` asserts
-- nothing at all. The published figures are barrel 28 in, overall 45.0 in, length of pull 14.5 in.
--   https://www.gunmart.net/gun-reviews/shotguns/side-by-side-shotgun/beretta-a486-parallelo
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Note:   docs/research/2026-09-26-shotgun-model.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))
local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))

local Shape = Weapon.Shape
local Hardware = Weapon.Hardware
local CONFIG = Shotgun.CONFIG

-- The ten pieces the design of this gun is: two barrels, the rib and its bead, the action and its
-- top lever, the walnut forend and stock, and a single trigger in its guard.
local EXPECTED = {
	"BarrelLeft",
	"BarrelRight",
	"Rib",
	"Bead",
	"Action",
	"TopLever",
	"Forend",
	"Stock",
	"TriggerGuard",
	"Trigger",
}

local function byName(pieces)
	local out = {}
	for _, piece in ipairs(pieces) do
		out[piece.name] = piece
	end
	return out
end

return function()
	describe("the shotgun's shape", function()
		it("is the ten pieces of a side-by-side, and nothing else", function()
			local pieces = Shape.pieces(CONFIG)
			expect(#pieces).to.equal(#EXPECTED)
			local found = byName(pieces)
			for _, name in ipairs(EXPECTED) do
				if found[name] == nil then
					error(string.format("the gun has no %s", name), 0)
				end
			end
		end)

		it("keeps the real gun's proportions: barrels 28 of 45, pull 14.5 of 45", function()
			local pieces = byName(Shape.pieces(CONFIG))
			local total = CONFIG.HANDLE_SIZE.Z
			local half = total / 2

			-- THE BARRELS ARE 28/45 OF THE GUN and they start at the muzzle. A cylinder's length is
			-- its X, which is why the barrel is turned a quarter turn to lie along Z.
			local barrel = pieces.BarrelLeft
			local barrelLength = barrel.size.X
			expect(math.abs(barrelLength - total * 28 / 45) < 1e-6).to.equal(true)
			local muzzleEnd = barrel.offset.Position.Z - barrelLength / 2
			expect(math.abs(muzzleEnd - -half) < 1e-6).to.equal(true)
			-- ...and the muzzle attachment is at the end of the barrels, not merely at -2.2 by
			-- coincidence: the two numbers have to be the same number.
			expect(math.abs(CONFIG.MUZZLE_OFFSET.Z - muzzleEnd) < 1e-6).to.equal(true)
			expect(math.abs(Shape.muzzleZ(CONFIG) - muzzleEnd) < 1e-6).to.equal(true)

			-- THE TRIGGER IS ONE LENGTH-OF-PULL FROM THE BUTT: 14.5 of 45, measured back from +half.
			local triggerZ = pieces.Trigger.offset.Position.Z
			expect(math.abs((half - triggerZ) - total * 14.5 / 45) < 1e-6).to.equal(true)
			-- ...which puts it 2.5 of 45 behind the breech, the third published number, and the one
			-- that proves the other two were read off the same gun.
			local breechZ = barrel.offset.Position.Z + barrelLength / 2
			expect(math.abs((triggerZ - breechZ) - total * 2.5 / 45) < 1e-6).to.equal(true)
			expect(pieces.TriggerGuard.offset.Position.Z).to.equal(triggerZ)
		end)

		it("is a SIDE-BY-SIDE: two barrels level with each other, one left one right", function()
			local pieces = byName(Shape.pieces(CONFIG))
			local left, right = pieces.BarrelLeft, pieces.BarrelRight
			-- THE WHOLE POINT OF THE TASK. Two Meshy previews came back over-unders, which is
			-- exactly this assertion failing: same height, different x, and the pair no wider than
			-- the Handle's envelope.
			expect(left.offset.Position.Y).to.equal(right.offset.Position.Y)
			expect(left.offset.Position.Z).to.equal(right.offset.Position.Z)
			expect(left.offset.Position.X < 0).to.equal(true)
			expect(right.offset.Position.X > 0).to.equal(true)
			expect(left.size).to.equal(right.size)
			expect(left.shape).to.equal(Enum.PartType.Cylinder)
			expect(right.shape).to.equal(Enum.PartType.Cylinder)
			local pairWidth = (right.offset.Position.X - left.offset.Position.X) + left.size.Y
			expect(pairWidth <= CONFIG.HANDLE_SIZE.X).to.equal(true)
			-- The tubes touch rather than float apart: a gap wider than a barrel is two rifles.
			local gap = (right.offset.Position.X - left.offset.Position.X) - left.size.Y
			expect(gap < left.size.Y / 2).to.equal(true)

			-- The rib lies BETWEEN them and above them, and the bead is at its muzzle end.
			expect(pieces.Rib.offset.Position.X).to.equal(0)
			expect(pieces.Rib.offset.Position.Y > left.offset.Position.Y).to.equal(true)
			expect(math.abs(pieces.Rib.size.Z - left.size.X) < 1e-6).to.equal(true)
			expect(pieces.Bead.offset.Position.Y > pieces.Rib.offset.Position.Y).to.equal(true)
			expect(pieces.Bead.offset.Position.Z < pieces.Rib.offset.Position.Z).to.equal(true)
		end)

		it("is walnut where it is held and metal where it is not", function()
			local pieces = byName(Shape.pieces(CONFIG))
			for _, name in ipairs({ "Stock", "Forend" }) do
				expect(pieces[name].material).to.equal(Enum.Material.Wood)
				expect(pieces[name].color).to.equal(CONFIG.LOOK.wood)
			end
			for _, name in ipairs({ "BarrelLeft", "BarrelRight", "Rib" }) do
				expect(pieces[name].material).to.equal(Enum.Material.Metal)
				expect(pieces[name].color).to.equal(CONFIG.LOOK.barrel)
			end
			for _, name in ipairs({ "Action", "TopLever", "TriggerGuard", "Trigger" }) do
				expect(pieces[name].color).to.equal(CONFIG.LOOK.action)
			end
			-- A STRAIGHT ENGLISH STOCK, dropping at the heel: the stock is the only rotated piece,
			-- and it is rotated nose-up so the butt sits below the bore line.
			local stock = pieces.Stock
			local rx = select(1, stock.offset:ToEulerAnglesXYZ())
			expect(rx > 0).to.equal(true)
			expect(math.deg(rx) < 15).to.equal(true) -- a stock, not a hockey stick
			local butt = stock.offset * CFrame.new(0, 0, stock.size.Z / 2)
			expect(butt.Position.Y < stock.offset.Position.Y).to.equal(true)
			expect(math.abs(butt.Position.Z - CONFIG.HANDLE_SIZE.Z / 2) < 0.2).to.equal(true)
		end)
	end)

	describe("the shotgun Tool that is built", function()
		it("welds every piece to the Handle, and the Handle alone answers a ray", function()
			local tool = Hardware.build()
			local handle = tool:FindFirstChild("Handle") :: BasePart
			expect(handle).to.be.ok()
			-- THE HANDLE IS THE ENVELOPE: invisible, but still the size, the grip and the muzzle's
			-- anchor. Nothing about how the gun is held changed in Task 71.
			expect(handle.Size).to.equal(CONFIG.HANDLE_SIZE)
			expect(handle.Transparency).to.equal(1)
			expect(tool.Grip).to.equal(CONFIG.GRIP)
			expect(handle:FindFirstChild("Muzzle")).to.be.ok()

			local parts, welds = {}, {}
			for _, child in ipairs(handle:GetChildren()) do
				if child:IsA("BasePart") then
					parts[child.Name] = child
				elseif child:IsA("Weld") then
					welds[(child :: Weld).Part1 and ((child :: Weld).Part1 :: Instance).Name or "?"] = child
				end
			end
			local pieces = byName(Shape.pieces(CONFIG))
			local count = 0
			for _, name in ipairs(EXPECTED) do
				local part = parts[name]
				if part == nil then
					error(string.format("the built Tool has no %s", name), 0)
				end
				count += 1
				-- APPEARANCE ONLY. The Handle is still the one part of the gun a ray can hit: ten new
				-- boxes that answered a raycast would be ten new things another player's slug stops
				-- against, which is a gameplay change wearing a cosmetic task's clothes.
				expect(part.CanQuery).to.equal(false)
				expect(part.CanCollide).to.equal(false)
				expect(part.Massless).to.equal(true)
				expect(part.Anchored).to.equal(false)
				-- THE WELD CARRIES THE OFFSET AS DATA, so the geometry comes from Weapon.Shape and not
				-- from wherever the part happened to be when it was joined.
				local weld = welds[name]
				expect(weld).to.be.ok()
				expect((weld :: Weld).Part0).to.equal(handle)
				expect((weld :: Weld).C0).to.equal(pieces[name].offset)
				expect(part.Size).to.equal(pieces[name].size)
			end
			expect(count).to.equal(#EXPECTED)
			expect(handle.CanQuery).to.equal(true)
			TestKit.note(string.format("shotgun: %d parts welded to the Handle, plus the Handle", count))
			tool:Destroy()
		end)

		it("hands the ADS viewmodel the same gun, because the viewmodel clones it", function()
			-- The viewmodel is a CLIENT module (PlayerScripts.Camera.Viewmodel) and this is a server
			-- spec, so what is asserted here is the property that makes its clone work: the whole gun
			-- hangs off the Handle, so `handle:Clone()` carries every visible piece with it. If a
			-- piece were ever parented to the Tool instead, the first-person gun would silently lose
			-- it. tests/client/camera_client.spec.luau asserts the clone itself, on screen.
			local tool = Hardware.build()
			local handle = tool:FindFirstChild("Handle") :: BasePart
			local loose = {}
			for _, child in ipairs(tool:GetChildren()) do
				if child:IsA("BasePart") and child ~= handle then
					table.insert(loose, child.Name)
				end
			end
			expect(#loose).to.equal(0)
			local clone = handle:Clone()
			local cloned = 0
			for _, descendant in ipairs(clone:GetDescendants()) do
				if descendant:IsA("BasePart") then
					cloned += 1
				end
			end
			expect(cloned).to.equal(#EXPECTED)
			clone:Destroy()
			tool:Destroy()
		end)
	end)
end

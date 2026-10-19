--!strict
-- The lighting owner (task 215): the Designer's numbers as data, the pure flag boundary, the
-- adopt-don't-duplicate writer, and the two claims a hunting game cannot get wrong -- a boar must
-- stay visible in shade, and the lodge's lamps must be brighter than the room around them.
--
-- EVERY CASE BUILDS ITS OWN INSTANCES AND DESTROYS THEM, and not one of them touches the real
-- `Lighting` service: `Light.apply` takes its target as an argument, so a parentless `Folder` with
-- real children stands in for the service and a failed run cannot leave this place dark. (The writes
-- onto a Folder itself are expected to be refused -- that is asserted, because the refusal path is
-- what keeps a lighting owner from throwing and leaving the world half-lit.)
--
-- Note: docs/research/2026-10-19-one-owner-for-the-lighting.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Light = require(ServerScriptService:WaitForChild("Light"))
local Lobby = require(ReplicatedStorage:WaitForChild("Lobby"))

local CFG = Light.CONFIG

local function rgb(colour: Color3): string
	return string.format(
		"%d,%d,%d",
		math.floor(colour.R * 255 + 0.5),
		math.floor(colour.G * 255 + 0.5),
		math.floor(colour.B * 255 + 0.5)
	)
end

return function()
	describe("the table is the Designer's spec", function()
		it("declares no fault", function()
			local problems = Light.problems(CFG)
			expect(#problems).to.equal(0)
			if #problems > 0 then
				error(table.concat(problems, "; "))
			end
		end)

		it("carries the exact numbers of the lighting spec, 2026-10-19", function()
			-- §1. The hero change and the cool sky it is paired with.
			expect(rgb(CFG.LIGHTING.Ambient)).to.equal("44,40,34")
			expect(rgb(CFG.LIGHTING.OutdoorAmbient)).to.equal("104,116,132")
			expect(CFG.LIGHTING.Brightness).to.equal(2.0)
			expect(rgb(CFG.LIGHTING.ColorShift_Top)).to.equal("46,30,12")
			expect(rgb(CFG.LIGHTING.ColorShift_Bottom)).to.equal("10,16,28")
			expect(CFG.LIGHTING.EnvironmentDiffuseScale).to.equal(0.35)
			expect(CFG.LIGHTING.EnvironmentSpecularScale).to.equal(0.2)
			expect(CFG.LIGHTING.ClockTime).to.equal(8.2)
			expect(CFG.LIGHTING.GeographicLatitude).to.equal(50)
			expect(CFG.LIGHTING.ExposureCompensation).to.equal(0.15)
			expect(CFG.LIGHTING.ShadowSoftness).to.equal(0.35)
			expect(CFG.LIGHTING.GlobalShadows).to.equal(true)
			-- §3.
			expect(CFG.ATMOSPHERE.Density).to.equal(0.28)
			expect(CFG.ATMOSPHERE.Offset).to.equal(0.25)
			expect(rgb(CFG.ATMOSPHERE.Color)).to.equal("186,190,196")
			expect(rgb(CFG.ATMOSPHERE.Decay)).to.equal("92,100,112")
			expect(CFG.ATMOSPHERE.Glare).to.equal(0.25)
			expect(CFG.ATMOSPHERE.Haze).to.equal(1.6)
			-- §4.
			expect(CFG.COLOR_CORRECTION.Enabled).to.equal(true)
			expect(CFG.COLOR_CORRECTION.Brightness).to.equal(-0.02)
			expect(CFG.COLOR_CORRECTION.Contrast).to.equal(0.16)
			expect(CFG.COLOR_CORRECTION.Saturation).to.equal(0.14)
			expect(rgb(CFG.COLOR_CORRECTION.TintColor)).to.equal("255,248,238")
			expect(CFG.BLOOM.Enabled).to.equal(true)
			expect(CFG.BLOOM.Intensity).to.equal(0.35)
			expect(CFG.BLOOM.Size).to.equal(18)
			expect(CFG.BLOOM.Threshold).to.equal(1.6)
			-- §4 again: SunRays is NOT USED, and the two the spec never saw go with it.
			expect(CFG.SUN_RAYS.Enabled).to.equal(false)
			expect(CFG.BLUR.Enabled).to.equal(false)
			expect(CFG.DEPTH_OF_FIELD.Enabled).to.equal(false)
		end)

		it("is frozen all the way down, rows included", function()
			expect(table.isfrozen(CFG)).to.equal(true)
			expect(table.isfrozen(CFG.LIGHTING)).to.equal(true)
			expect(table.isfrozen(CFG.ATMOSPHERE)).to.equal(true)
			expect(function()
				(CFG.LIGHTING :: any).Brightness = 3.0
			end).to.throw()
		end)

		it("never names Technology, which this engine refuses even to read from a script", function()
			-- Deviation 1 of the note's section 4. A probe on 2026-10-19 answered "cannot read
			-- 'Technology' (lacking capability RobloxScript)", so the spec's ShadowMap row is a
			-- comment and not a write. This case is what stops somebody adding it back.
			expect((CFG.LIGHTING :: any).Technology).to.equal(nil)
			local plan = Light.plan(true, CFG)
			expect(plan).never.to.equal(nil)
			expect(((plan :: any).service :: any).Technology).to.equal(nil)
		end)

		it("never names the fog, which an Atmosphere supersedes", function()
			for _, name in ipairs({ "FogStart", "FogEnd", "FogColor" }) do
				expect((CFG.LIGHTING :: any)[name]).to.equal(nil)
			end
		end)

		it("fails a faulty table rather than writing it", function()
			-- `problems` is the tripwire, so it has to be shown catching something.
			local bad = {
				LIGHTING = table.clone(CFG.LIGHTING),
				ATMOSPHERE = table.clone(CFG.ATMOSPHERE),
				COLOR_CORRECTION = table.clone(CFG.COLOR_CORRECTION),
				BLOOM = table.clone(CFG.BLOOM),
				SUN_RAYS = table.clone(CFG.SUN_RAYS),
				BLUR = table.clone(CFG.BLUR),
				DEPTH_OF_FIELD = table.clone(CFG.DEPTH_OF_FIELD),
			}
			bad.LIGHTING.ClockTime = 26 -- not a time of day
			bad.ATMOSPHERE.Density = 1.5 -- over the engine's documented 0..1
			bad.LIGHTING.GlobalShadows = false -- and every value above assumes it is on
			local problems = Light.problems(bad :: any)
			expect(#problems).to.equal(3)
		end)
	end)

	describe("the flag boundary is pure, and OFF means nothing is written", function()
		it("answers nil when the flag is off", function()
			expect(Light.plan(false, CFG)).to.equal(nil)
		end)

		it("answers a frozen plan when the flag is on", function()
			local plan = Light.plan(true, CFG)
			expect(plan).never.to.equal(nil)
			expect(table.isfrozen(plan :: any)).to.equal(true)
		end)

		it("puts every LIGHTING row on the service and nothing else", function()
			local plan = (Light.plan(true, CFG) :: any) :: Light.Plan
			local count = 0
			for name, value in pairs(plan.service) do
				count += 1
				expect((CFG.LIGHTING :: any)[name]).to.equal(value)
			end
			local declared = 0
			for _ in pairs(CFG.LIGHTING) do
				declared += 1
			end
			expect(count).to.equal(declared)
		end)

		it("creates the three the look needs and only adopts the three it switches off", function()
			local plan = (Light.plan(true, CFG) :: any) :: Light.Plan
			local create: { [string]: boolean } = {}
			for _, write in ipairs(plan.children) do
				create[write.className] = write.create
			end
			expect(create.Atmosphere).to.equal(true)
			expect(create.ColorCorrectionEffect).to.equal(true)
			expect(create.BloomEffect).to.equal(true)
			-- A place that has no SunRays must never GAIN one just so it can be switched off.
			expect(create.SunRaysEffect).to.equal(false)
			expect(create.BlurEffect).to.equal(false)
			expect(create.DepthOfFieldEffect).to.equal(false)
		end)
	end)

	describe("apply adopts, never duplicates, and never throws", function()
		local function target(): Instance
			-- A parentless stand-in for the service: real children, no place state.
			return Instance.new("Folder")
		end

		it("creates one of each owned class in a container that has none", function()
			local into = target()
			local report = Light.apply(into, Light.plan(true, CFG) :: any)
			expect(#report.created).to.equal(3)
			expect(#report.adopted).to.equal(0)
			-- and the three it will not create are reported absent, not created
			expect(#report.absent).to.equal(3)
			expect(into:FindFirstChildOfClass("Atmosphere")).never.to.equal(nil)
			expect(into:FindFirstChildOfClass("ColorCorrectionEffect")).never.to.equal(nil)
			expect(into:FindFirstChildOfClass("BloomEffect")).never.to.equal(nil)
			expect((into:FindFirstChildOfClass("Atmosphere") :: Atmosphere).Density).to.equal(CFG.ATMOSPHERE.Density)
			expect((into:FindFirstChildOfClass("BloomEffect") :: BloomEffect).Threshold).to.equal(CFG.BLOOM.Threshold)
			into:Destroy()
		end)

		it("adopts what is already there instead of adding a second one, whatever it is called", function()
			local into = target()
			-- The Forest Test's own shape, measured 2026-10-19: a plain `Atmosphere` and a
			-- `ColorCorrection` running Saturation -0.5, plus a SunRays that is ON.
			local existing = Instance.new("Atmosphere")
			existing.Name = "Atmosphere"
			existing.Density = 0.23
			existing.Parent = into
			local grade = Instance.new("ColorCorrectionEffect")
			grade.Name = "ColorCorrection"
			grade.Saturation = -0.5
			grade.Parent = into
			local rays = Instance.new("SunRaysEffect")
			rays.Enabled = true
			rays.Parent = into

			local report = Light.apply(into, Light.plan(true, CFG) :: any)

			local atmospheres = 0
			for _, child in ipairs(into:GetChildren()) do
				if child:IsA("Atmosphere") then
					atmospheres += 1
				end
			end
			expect(atmospheres).to.equal(1) -- adopted, not duplicated
			expect(existing.Density).to.equal(CFG.ATMOSPHERE.Density)
			expect(existing.Name).to.equal("Atmosphere") -- an adopted instance keeps its own name
			expect(grade.Saturation).to.equal(CFG.COLOR_CORRECTION.Saturation)
			expect(rays.Enabled).to.equal(false) -- §4: SunRays is not used
			expect(#report.created).to.equal(1) -- the Bloom only
			expect(#report.adopted).to.equal(3)
			expect(#report.absent).to.equal(2) -- Blur and DepthOfField are not here and are not added
			into:Destroy()
		end)

		it("is idempotent: twice writes the same thing and adds nothing", function()
			local into = target()
			Light.apply(into, Light.plan(true, CFG) :: any)
			local before = #into:GetChildren()
			local second = Light.apply(into, Light.plan(true, CFG) :: any)
			expect(#into:GetChildren()).to.equal(before)
			expect(#second.created).to.equal(0)
			expect(#second.adopted).to.equal(3)
			into:Destroy()
		end)

		it("reports a second instance of an owned class and does not touch it", function()
			local into = target()
			local one = Instance.new("Atmosphere")
			one.Parent = into
			local two = Instance.new("Atmosphere")
			two.Density = 0.9
			two.Parent = into
			local report = Light.apply(into, Light.plan(true, CFG) :: any)
			expect(#report.extra).to.equal(1)
			expect(two.Density).to.equal(0.9) -- untouched: deleting Studio content is not this owner's call
			into:Destroy()
		end)

		it("counts a refused property instead of throwing", function()
			-- A Folder has no `Ambient`, so every service write is refused. The whole point is that
			-- the children still get written: an owner that threw on one property would leave the
			-- world half-lit.
			local into = target()
			local report = Light.apply(into, Light.plan(true, CFG) :: any)
			expect(#report.failed > 0).to.equal(true)
			expect(into:FindFirstChildOfClass("BloomEffect")).never.to.equal(nil)
			into:Destroy()
		end)
	end)

	describe("a boar stays visible in shade", function()
		-- The spec's §2, re-derived rather than quoted. `Light.shade` is the ambient term alone --
		-- the WORST case, before EnvironmentDiffuseScale, the ColorShifts, the exposure and the
		-- grade lift it -- so a ratio that holds here holds in the frame.
		local SKY = CFG.LIGHTING.OutdoorAmbient
		local BOAR = Color3.fromRGB(198, 158, 110) -- Boar.CONFIG.BODY_COLOR, Karen's dial, untouched
		local GRASS = Color3.fromRGB(112, 124, 72)
		local DIRT = Color3.fromRGB(120, 104, 82)

		it("reproduces the spec's own two checkable rows to the digit", function()
			expect(math.floor(Light.luminance(Light.shade(BOAR, SKY)))).to.equal(72)
			expect(math.floor(Light.luminance(Light.shade(DIRT, SKY)))).to.equal(47)
		end)

		it("is 1.43 : 1 over grass on the ambient term ALONE, which is the spec's table corrected", function()
			-- The spec's §2 prints 45 for the grass and therefore claims 1.6 : 1. 112,124,72 under
			-- 104,116,132 renders 46,56,37, whose BT.601 luma is 51.0 -- so the honest worst-case
			-- figure is 1.43, UNDER the >= 1.5 this task was given. It is recorded here as a number
			-- rather than a sentence so nobody re-derives it twice, and the >= 1.5 claim is settled
			-- on the FRAME (reviews/task-215/REQUEST.md), which carries the grade this does not.
			local ratio = Light.ratio(Light.shade(BOAR, SKY), Light.shade(GRASS, SKY))
			expect(ratio > 1.4 and ratio < 1.46).to.equal(true)
		end)

		it("keeps the boar BRIGHTER than the ground it stands on, which is the thing that matters", function()
			-- Whatever the ratio, the sign must never flip: a boar darker than its grass is a boar
			-- you look past. Both grounds, on the ambient term alone.
			expect(Light.luminance(Light.shade(BOAR, SKY)) > Light.luminance(Light.shade(GRASS, SKY))).to.equal(true)
			expect(Light.luminance(Light.shade(BOAR, SKY)) > Light.luminance(Light.shade(DIRT, SKY))).to.equal(true)
		end)

		it("is warm where the ground is not: the hue gap the grade then widens", function()
			local boar = Light.shade(BOAR, SKY)
			local grass = Light.shade(GRASS, SKY)
			expect(boar.R > boar.B).to.equal(true) -- warm-neutral
			expect(grass.G > grass.R).to.equal(true) -- green
		end)

		it("names its own escape hatch, and it is Ambient and not the boar", function()
			-- §2's one risk: under sealed spruce canopy a boar falls toward `Ambient`. The knob is
			-- `Ambient` -> 54,49,43, NOT the boar's albedo and NOT OutdoorAmbient -- raising either
			-- of those would undo the lodge. This case asserts the fallback still reads the boar
			-- brighter than the litter under it, so the documented fix is known to work.
			local SEALED = Color3.fromRGB(54, 49, 43)
			expect(Light.luminance(Light.shade(BOAR, SEALED)) > Light.luminance(Light.shade(GRASS, SEALED))).to.equal(
				true
			)
		end)
	end)

	describe("the lodge falls to its own lamps", function()
		local LODGE = Lobby.CONFIG.LODGE

		it("carries the spec's three nudges", function()
			expect(LODGE.FIRE_LIGHT.rangeStuds).to.equal(30)
			expect(LODGE.LANTERN.brightness).to.equal(1.25)
			expect(LODGE.LANTERN.rangeStuds).to.equal(20)
		end)

		it("keeps the fire reaching further than a lantern, so the room has a gradient", function()
			-- The whole reason for two kinds of light in one room: the hearth end is the fire's, the
			-- counter end is the lanterns'. If a lantern ever out-ranged the fire there would be one
			-- even wash again, which is what §5 exists to undo.
			expect(LODGE.FIRE_LIGHT.rangeStuds > LODGE.LANTERN.rangeStuds).to.equal(true)
			expect(LODGE.FIRE_LIGHT.brightness > LODGE.LANTERN.brightness).to.equal(true)
		end)

		it("is brighter than the ambient it now sits in", function()
			-- The measured failure this whole task is fixing: at Ambient 159,159,159 the six lamps
			-- were dimmer than the flat light already on every surface, so none of them could be
			-- seen. A lamp's colour at full brightness against the new Ambient is the check.
			local ambient = Light.luminance(CFG.LIGHTING.Ambient)
			expect(Light.luminance(LODGE.LANTERN.color) > ambient).to.equal(true)
			expect(Light.luminance(LODGE.FIRE_LIGHT.color) > ambient).to.equal(true)
			expect(ambient < 60).to.equal(true) -- a warm near-black, not a floor of light
		end)
	end)
end

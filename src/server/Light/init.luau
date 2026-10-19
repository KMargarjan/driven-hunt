--!strict
-- Light: THE OWNER OF THE GAME'S LIGHT. The one writer of `Lighting`, of the one `Atmosphere` under
-- it, and of every `PostEffect` under it -- in EVERY world, from ONE data table.
--
-- KAREN, 2026-10-17, asked whether the Designer should tune the lighting; the cabin and the boar
-- heads read pale: *"yes"*. The numbers below are the Designer's lighting spec, 2026-10-19
-- (`<runs-dir>/design/lighting-spec.md` plus `lighting-mockups.png`), applied as written except for
-- the three deviations named in the research note's section 4 and repeated beside the rows they
-- affect.
--
-- WHY THIS FILE EXISTS AT ALL, which is not the same as why the numbers changed. Before it,
-- `Lighting` was PLACE CONTENT THAT NOBODY OWNED: no file in `src/`, `tests/` or `tools/` mentioned
-- `Lighting`, `Atmosphere`, `Bloom` or `SunRays` (grep, empty), so the only record of the game's
-- light was whatever was last typed into a Studio property box -- in two places, differently. Read
-- live on 2026-10-19: the Forest Test was `Ambient` 159,159,159 / `Brightness` 3.0 / `ClockTime` 15,
-- and DEV was 110,100,90 / 2.6 / 13. A reviewer could not read either and a commit could not change
-- either. One owner, one table, one diff.
--
-- OWNERSHIP (rule 3), and the boundary stated in both directions:
--   * THIS module writes `Lighting`'s own properties, the `Atmosphere`, the `ColorCorrectionEffect`
--     and the `BloomEffect`, and switches OFF a `SunRaysEffect`, `BlurEffect` or
--     `DepthOfFieldEffect` it finds. Nothing else in the game may write any of them.
--   * IT NEVER touches a `PointLight`, a `SpotLight`, a `Fire` or a `Beam`. The lodge's six warm
--     lamps are `Lobby.Build`'s, from `Lobby.CONFIG.LODGE`, and they stay there: the spec's §5 is
--     three numbers in THAT table, not a light this module adds. A lamp belongs to the thing it
--     hangs from.
--   * It owns no `Sky` either. The place's skybox is Studio content and the spec does not name it.
--
-- NOTHING HAPPENS ON REQUIRE -- the rule `Match`, `Boar`, `Weapon`, `Lobby` and `Economy` all
-- follow. `ServerScriptService.LightBoot` is the one caller, and it calls `plan` then `apply`.
--
-- THE PATTERN: a frozen data table, a PURE `plan`, and a thin `apply` -- Unity's "Lighting Settings
-- Asset" (https://docs.unity3d.com/Manual/class-LightingSettings.html) in a language with no
-- assets: the environment is one serialised table with a name, not a state somebody left behind.
-- The flag lands in `plan`, at this owner's boundary, which is Pete Hodgson's release-toggle rule
-- (https://martinfowler.com/articles/feature-toggles.html) and is what keeps BOTH branches
-- reachable by parameter while the row sits at `true`.
-- Property semantics: Roblox Creator Docs, CC BY 4.0 --
--   https://create.roblox.com/docs/environment/lighting
--   https://create.roblox.com/docs/environment/atmosphere
--   https://create.roblox.com/docs/environment/post-processing-effects
-- Note: docs/research/2026-10-19-one-owner-for-the-lighting.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
-- `deepFreeze` only: `table.freeze` is shallow and this table is nested three deep.
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Light = {}

-- THE ONE FLAG READ, AT THIS OWNER'S BOUNDARY, passed inward as `plan`'s first argument -- the only
-- permitted shape (CLAUDE.md, feature flags). It is BORN ON, which no other dark path in the table
-- is: there is no point merging a look nobody can look at, and the row exists so the Director can
-- take it off live the moment Karen says it is too dark.
Light.ENABLED = Flags.isOn("AUTUMN_LIGHT")

-- The names this module gives the instances it CREATES. It adopts whatever is already there first
-- (see `apply`), so these only ever appear in a place that had none -- DEV already carries a
-- hand-made `DrivenHuntAtmosphere` and `DrivenHuntColorCorrection`, and the Forest Test carries a
-- plain `Atmosphere` and `ColorCorrection`. Both are taken over rather than duplicated.
Light.NAMES = table.freeze({
	Atmosphere = "DrivenHuntAtmosphere",
	ColorCorrectionEffect = "DrivenHuntColorCorrection",
	BloomEffect = "DrivenHuntBloom",
})

export type Write = {
	className: string,
	-- The name to give it IF this module has to create it. An adopted instance keeps its own name:
	-- renaming somebody else's instance is a second kind of write and buys nothing.
	name: string,
	-- `false` means ADOPT ONLY: switch one off if it is there, and never add one to a place that
	-- does not have it. The three effects the spec does not use are all like this.
	create: boolean,
	props: { [string]: any },
}

export type Plan = {
	-- Written on the `Lighting` service itself.
	service: { [string]: any },
	-- One entry per child class, in the order they are applied.
	children: { Write },
}

-- ---------------------------------------------------------------- the Designer's spec, as data
--
-- EVERY NUMBER BELOW IS THE DESIGNER'S, 2026-10-19, and the comment beside it is the Designer's
-- reason in one line. The one idea the whole table runs on is in that spec's §0: *the sky is cool
-- and the sun is warm*. Today both are the same flat grey, which is why shade reads as a dimmer
-- copy of sun instead of as shade.
Light.CONFIG = {
	LIGHTING = {
		-- THE HERO CHANGE (spec §1): 159,159,159 -> a warm near-black. This is the light in places
		-- OCCLUDED FROM THE SKY -- the lodge, and deep under spruce -- so the lodge falls to its own
		-- six lamps for the first time. Warm (R > G > B) so the dark end of a room is brown-black.
		-- NOT 0,0,0: Roblox's occlusion grid is coarse and a true zero gives black blotches.
		Ambient = Color3.fromRGB(44, 40, 34),
		-- The light in places OPEN TO THE SKY: a cool overcast blue-grey. Lower than today's 159
		-- (0.46 against 0.62) so the open field stops being flat, and COOL, which is the whole
		-- trick -- shade now has a colour instead of being a dimmer copy of sun.
		OutdoorAmbient = Color3.fromRGB(104, 116, 132),
		-- Down from 3.0. With the outdoor floor at 0.46 the sun no longer has to fight it, and 2.0
		-- gives a lit:shaded ratio of about 2.7 : 1 -- a soft morning. Also the engine default.
		Brightness = 2.0,
		-- An additive warm amber on faces turned toward the sun: the ochre back in sunlit grass and
		-- the gold edge on a birch trunk.
		ColorShift_Top = Color3.fromRGB(46, 30, 12),
		-- A faint cool lift on faces turned away -- the half-stop that makes a shaded flank read
		-- BLUE rather than merely dark.
		ColorShift_Bottom = Color3.fromRGB(10, 16, 28),
		-- Sky-direction fill from the skybox: the top of a boar's back lighter than its belly, so
		-- SHAPE and not just value. Kept well under 1.0 so the skybox cannot hijack the shade colour
		-- `OutdoorAmbient` just set.
		EnvironmentDiffuseScale = 0.35,
		-- A faint sky sheen on the barrel, the wet track and the lantern glass. Low, because
		-- late-autumn wood and wet leaf are matte and a glinting forest is a plastic forest.
		EnvironmentSpecularScale = 0.2,
		-- ~2 h after sunrise. The sun lands near 22 degrees of elevation -- low enough to rake
		-- through trunks and throw long shadows, high enough that the ground is not all shadow. A
		-- drive starts in the morning; this is the time it starts.
		ClockTime = 8.2,
		-- Central Europe (Bohemia / Lower Saxony). The default is 41.73 and both places had drifted
		-- to 52 and 54. At 50 the sun's arc tilts south and stays lower, so the place can never
		-- slide back into the flat overhead look.
		GeographicLatitude = 50,
		-- `ColorCorrection` adds contrast, which darkens midtones; this brings them back WITHOUT
		-- raising the black point, which is what `Brightness` would have done.
		ExposureCompensation = 0.15,
		-- ONLY HAS ANY EFFECT UNDER `Future`, and this game runs `ShadowMap`: recorded so the value
		-- exists if that experiment is ever run, and INERT in the shipped setup. Lower than the 0.5
		-- default because a soft sun plus soft shadows is mush.
		ShadowSoftness = 0.35,
		-- Must be on: everything above assumes it.
		GlobalShadows = true,
		-- `Technology` IS DELIBERATELY ABSENT, and that is deviation 1 of the note's section 4. The
		-- spec's §1 asks for `ShadowMap`, which is already what both places run -- but the property
		-- cannot be touched from a script AT ALL: a probe on 2026-10-19 came back *"cannot read
		-- 'Technology' (lacking capability RobloxScript)"* for a read, let alone a write. The look
		-- does not depend on it: the spec builds the softness out of a weak sun against a strong sky
		-- (2.7 : 1) precisely so it survives a device that renders hard shadows.
		--
		-- `FogStart` / `FogEnd` / `FogColor` ARE DELIBERATELY ABSENT TOO, as the spec's §1 asks: an
		-- `Atmosphere` supersedes them entirely, so they are dead properties once one exists.
	},
	-- The cheapest depth in the engine, and where the forest stops being a wall of trees and becomes
	-- a wood with a far side. ~0.1 ms, folded into the sky pass the renderer already runs.
	ATMOSPHERE = {
		-- The near 80 studs stay clear and the far treeline separates. Held under 0.3 deliberately:
		-- a shooter must read a boar at 150 studs and `Density` is very sensitive past there.
		Density = 0.28,
		-- Pushes the density curve away from the camera, so the clearing in front of a stand is not
		-- hazed and only distance is. This is the property that keeps the boar-in-shade measurement
		-- honest.
		Offset = 0.25,
		-- The colour of the air itself: cool pale grey, off Karen's overcast reference.
		Color = Color3.fromRGB(186, 190, 196),
		-- The colour the air decays to away from the sun -- what makes the far woods go BLUE with
		-- distance instead of white, and the single property doing most of the depth work.
		Decay = Color3.fromRGB(92, 100, 112),
		-- The halo around the low sun. Restrained: this is what replaces `SunRays` for free, and a
		-- large value would wash the HUD's top band.
		Glare = 0.25,
		-- A soft warm lift at the horizon. Range is 0-10; 1.6 is "there" without milk.
		Haze = 1.6,
	},
	-- ~0.05 ms: three arithmetic ops in a post chain that already runs.
	COLOR_CORRECTION = {
		Enabled = true,
		-- The faintest pull on the lift, so blacks land on black.
		Brightness = -0.02,
		-- The "deep, not grey" knob, and the one that pushes boar and ground apart in shade: both
		-- sit below the contrast pivot, so contrast separates them rather than collapsing them.
		Contrast = 0.16,
		-- Puts the brown back in the leaf litter and the warmth back in the boar. The references'
		-- richness is albedo, not light; this is how a flat-lit engine fakes it.
		--
		-- AND IT IS A SWING OF +0.64, NOT +0.14, IN THE PLACE KAREN PLAYS. The Forest Test was
		-- running `Saturation = -0.5` on an unowned `ColorCorrection` -- half the colour taken out
		-- of every frame by an effect nothing recorded. That is a second, independent cause of
		-- "pale and washed out" which the spec's §0 never saw, and it is the clearest single
		-- argument for this file existing (note, section 2).
		Saturation = 0.14,
		-- A whisper of warm, deliberately almost nothing: a strong tint would fight the cool shade
		-- set above, and the warmth belongs in the SUN, not over the whole frame.
		TintColor = Color3.fromRGB(255, 248, 238),
	},
	-- THE ONE ADDED RENDER TARGET, and the only item in the spec that is not free: ~0.4 ms on a mid
	-- phone, a fixed cost whether or not anything exceeds the threshold. **If frames suffer this is
	-- the first and only thing to cut** -- the rest of the setup stands without it.
	--
	-- It stays because the lodge's whole look is three pools of warm light: without it the hanging
	-- lantern is a flat white rectangle and the fire a flat yellow triangle, painted shapes rather
	-- than things that emit.
	BLOOM = {
		Enabled = true,
		Intensity = 0.35,
		Size = 18,
		-- High on purpose: only the sun disc, the fire and the lantern glass ever reach it. Nothing
		-- else in the game blooms.
		Threshold = 1.6,
	},
	-- ---------------------------------------------------------------- the three that are switched OFF
	--
	-- DEVIATION 2 OF THE NOTE'S SECTION 4, and the only part of this table that is not the
	-- Designer's own sentence. The spec's §4 says `SunRays` is NOT USED -- and the Forest Test was
	-- running it ON. It never saw the `Blur` (Size 1.0, on) or the `DepthOfField` (on, both
	-- intensities 0) at all, because they were not in the brief. An unowned post effect that
	-- silently changes every frame is the exact thing this file exists to end, so all three are
	-- named here with an explicit `Enabled = false` and a reason.
	--
	-- `create = false` ON ALL THREE: a place that has none must not gain one. Switching off
	-- something that is there is this owner's job; adding something to switch off is not.
	SUN_RAYS = {
		-- ~1.0 ms on a phone, the most expensive of the three (a multi-tap radial blur); it only
		-- fires when the sun is on screen and this camera is level or looking down at a boar; and
		-- Roblox's `SunRays` occludes badly against thin birch trunks -- it smears rather than
		-- shafts, and the grey wash lands exactly where the HUD's objective line lives.
		-- `Atmosphere.Glare` gives the low sun its halo instead, inside a pass that already runs.
		Enabled = false,
	},
	BLUR = {
		-- A full-screen blur on every frame, at `Size = 1.0`, that no document in this repo asks
		-- for and no design names. Nothing in the Designer's four scenes is soft-focus.
		Enabled = false,
	},
	DEPTH_OF_FIELD = {
		-- On in both places with `FarIntensity` and `NearIntensity` at 0, so it draws nothing today.
		-- It is switched off rather than left alone because "it happens to be inert" is a property
		-- of the numbers beside it, and those numbers belong to nobody.
		Enabled = false,
	},
}

-- deepFreeze, REQUIRED and not copied: `table.freeze` is shallow, and this repo has already paid for
-- that once (src/shared/Drive/init.luau, Task 23a note (b)). Every nested row must be frozen too.
Shotgun.deepFreeze(Light.CONFIG)

-- ---------------------------------------------------------------- pure

-- BT.601 luma (ITU-R BT.601), on 0..255. **It is this and not Rec. 709 because it is the arithmetic
-- the Designer's §2 table was computed with, and that is checkable rather than assumed**: the boar
-- flank's "72" and the dirt track's "47" both reproduce to the digit from the albedos printed beside
-- them, while Rec. 709 gives 73.8 and 48.5. (§2's GRASS row does not reproduce under either -- see
-- `tests/server/light.spec.luau`, which asserts the real figure rather than the printed one.)
function Light.luminance(colour: Color3): number
	return (0.299 * colour.R + 0.587 * colour.G + 0.114 * colour.B) * 255
end

-- What `OutdoorAmbient` ALONE makes of an albedo: a surface in open shade, flank turned from the
-- sun, lit by the sky and nothing else. Component-wise albedo x ambient, which is the engine's own
-- ambient term and is what the Designer's §2 "renders at" column is.
--
-- IT IS A FLOOR AND NOT A PREDICTION OF THE FRAME. The rendered pixel also carries
-- `EnvironmentDiffuseScale`, the `ColorShift`s, the exposure and the `ColorCorrection` grade, every
-- one of which lifts it. So a ratio computed here is the WORST case, and the frame is measured as
-- well (the request's own evidence) rather than inferred from this.
function Light.shade(albedo: Color3, outdoorAmbient: Color3): Color3
	return Color3.new(albedo.R * outdoorAmbient.R, albedo.G * outdoorAmbient.G, albedo.B * outdoorAmbient.B)
end

-- The luminance ratio of two colours, brighter over darker, so it is always >= 1.
function Light.ratio(a: Color3, b: Color3): number
	local la, lb = Light.luminance(a), Light.luminance(b)
	if la < lb then
		la, lb = lb, la
	end
	if lb <= 0 then
		return math.huge
	end
	return la / lb
end

-- Every declaration fault in ONE list, so a bad row is one spec failure and not five runs --
-- `Flags.problems`'s own shape. Only the bounds the Roblox docs actually state are checked: a bound
-- somebody guessed would fail a legal value one day and teach nobody anything.
function Light.problems(config: typeof(Light.CONFIG)): { string }
	local out: { string } = {}

	local function number_(where: string, value: any, low: number?, high: number?)
		if type(value) ~= "number" then
			table.insert(out, string.format("%s is a %s, not a number", where, type(value)))
			return
		end
		if low and value < low then
			table.insert(out, string.format("%s is %.3f, under %.3f", where, value, low))
		end
		if high and value > high then
			table.insert(out, string.format("%s is %.3f, over %.3f", where, value, high))
		end
	end

	local function colour_(where: string, value: any)
		if typeof(value) ~= "Color3" then
			table.insert(out, string.format("%s is a %s, not a Color3", where, typeof(value)))
		end
	end

	local lighting = config.LIGHTING
	for _, name in ipairs({ "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom" }) do
		colour_("LIGHTING." .. name, (lighting :: any)[name])
	end
	number_("LIGHTING.Brightness", lighting.Brightness, 0, nil)
	number_("LIGHTING.EnvironmentDiffuseScale", lighting.EnvironmentDiffuseScale, 0, 1)
	number_("LIGHTING.EnvironmentSpecularScale", lighting.EnvironmentSpecularScale, 0, 1)
	-- The engine's own documented ranges: a 24-hour clock, and a latitude.
	number_("LIGHTING.ClockTime", lighting.ClockTime, 0, 24)
	number_("LIGHTING.GeographicLatitude", lighting.GeographicLatitude, -90, 90)
	number_("LIGHTING.ExposureCompensation", lighting.ExposureCompensation, -5, 5)
	number_("LIGHTING.ShadowSoftness", lighting.ShadowSoftness, 0, 1)
	if type(lighting.GlobalShadows) ~= "boolean" then
		table.insert(out, "LIGHTING.GlobalShadows is not a boolean")
	elseif not lighting.GlobalShadows then
		table.insert(out, "LIGHTING.GlobalShadows is false, and every value above assumes it is on")
	end

	local atmosphere = config.ATMOSPHERE
	number_("ATMOSPHERE.Density", atmosphere.Density, 0, 1)
	number_("ATMOSPHERE.Offset", atmosphere.Offset, 0, 1)
	number_("ATMOSPHERE.Glare", atmosphere.Glare, 0, 10)
	number_("ATMOSPHERE.Haze", atmosphere.Haze, 0, 10)
	colour_("ATMOSPHERE.Color", atmosphere.Color)
	colour_("ATMOSPHERE.Decay", atmosphere.Decay)

	local grade = config.COLOR_CORRECTION
	number_("COLOR_CORRECTION.Brightness", grade.Brightness, -1, 1)
	number_("COLOR_CORRECTION.Contrast", grade.Contrast, -1, 1)
	number_("COLOR_CORRECTION.Saturation", grade.Saturation, -1, 5)
	colour_("COLOR_CORRECTION.TintColor", grade.TintColor)

	number_("BLOOM.Intensity", config.BLOOM.Intensity, 0, nil)
	number_("BLOOM.Size", config.BLOOM.Size, 0, nil)
	number_("BLOOM.Threshold", config.BLOOM.Threshold, 0, nil)

	return out
end

-- THE FLAG LANDS HERE, and this is the whole off-switch: `plan(false, ...)` answers **nil**, so
-- `apply` is never reached and the place keeps its own `Lighting` untouched -- not restored, not
-- overwritten with a second set of numbers, NOT WRITTEN AT ALL.
--
-- A restore-from-snapshot off-switch was refused in the note (section 4): a snapshot taken after
-- something else has already written is a snapshot of the wrong thing, and the override is set in
-- EDIT and read at BOOT, so the answer is always known before the first write.
--
-- Pure: no service, no Instance, no yield. `tests/server/light.spec.luau` drives both branches with
-- no Play session at all, which is what keeps the OFF branch reachable while the row sits at ON.
function Light.plan(enabled: boolean, config: typeof(Light.CONFIG)): Plan?
	if not enabled then
		return nil
	end

	-- `table.clone`, not a hand-rolled loop: it is shallow, which is exactly right for a flat map of
	-- property values, and it returns an UNFROZEN copy of a frozen argument (`Flags.resolve`'s own
	-- reason for using it).
	local service: { [string]: any } = table.clone(config.LIGHTING) :: any

	local children: { Write } = {
		{
			className = "Atmosphere",
			name = Light.NAMES.Atmosphere,
			create = true,
			props = table.clone(config.ATMOSPHERE) :: { [string]: any },
		},
		{
			className = "ColorCorrectionEffect",
			name = Light.NAMES.ColorCorrectionEffect,
			create = true,
			props = table.clone(config.COLOR_CORRECTION) :: { [string]: any },
		},
		{
			className = "BloomEffect",
			name = Light.NAMES.BloomEffect,
			create = true,
			props = table.clone(config.BLOOM) :: { [string]: any },
		},
		-- ADOPT ONLY (`create = false`): switch one off if the place has one, never add one.
		{ className = "SunRaysEffect", name = "SunRays", create = false, props = table.clone(config.SUN_RAYS) },
		{ className = "BlurEffect", name = "Blur", create = false, props = table.clone(config.BLUR) },
		{
			className = "DepthOfFieldEffect",
			name = "DepthOfField",
			create = false,
			props = table.clone(config.DEPTH_OF_FIELD),
		},
	}

	return table.freeze({ service = service, children = children }) :: any
end

-- ---------------------------------------------------------------- the one write

export type Report = {
	written: number, -- properties actually set on the service
	created: { string }, -- class names this call had to create
	adopted: { string }, -- class names it found and took over
	absent: { string }, -- adopt-only classes the place does not have, so nothing was done
	extra: { string }, -- a SECOND instance of an owned class: reported, never touched
	failed: { string }, -- a property the engine refused, with its error
}

local function first(lighting: Instance, className: string): (Instance?, number)
	local found: Instance? = nil
	local count = 0
	for _, child in ipairs(lighting:GetChildren()) do
		if child.ClassName == className then
			count += 1
			if found == nil then
				found = child
			end
		end
	end
	return found, count
end

-- Walks a plan and writes it. The ONLY function in this module that touches an Instance.
--
-- IDEMPOTENT BY CONSTRUCTION: it adopts the first child of each class that is already there and
-- creates one only when there is none, so applying twice writes the same values and adds nothing.
-- That matters because the engine's own `Lighting` is shared state and this is a server that may be
-- booted beside a spec.
--
-- EVERY WRITE IS GUARDED. A property this engine version does not have, or refuses, is counted in
-- `failed` and does not stop the rest -- a lighting owner that throws on one unknown property would
-- leave the world half-lit, which is worse than the look it was fixing.
--
-- A SECOND INSTANCE OF AN OWNED CLASS IS REPORTED AND NEVER TOUCHED (`extra`): two `Atmosphere`s
-- stack, so it is worth saying out loud -- but deleting somebody's Studio content is not this
-- module's call (rule 7), and the console line is what makes it visible.
function Light.apply(lighting: Instance, plan: Plan): Report
	local report: Report = { written = 0, created = {}, adopted = {}, absent = {}, extra = {}, failed = {} }

	local function set(target: Instance, name: string, value: any, where: string)
		local ok, err = pcall(function()
			(target :: any)[name] = value
		end)
		if ok then
			report.written += 1
		else
			table.insert(report.failed, string.format("%s.%s: %s", where, name, tostring(err)))
		end
	end

	-- A stable order, so two runs report the same list and a diff of two console lines means
	-- something (`Flags.resolve`'s own reason for sorting).
	local names: { string } = {}
	for name in pairs(plan.service) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		set(lighting, name, plan.service[name], "Lighting")
	end

	for _, write in ipairs(plan.children) do
		local found, count = first(lighting, write.className)
		if found == nil and not write.create then
			table.insert(report.absent, write.className)
			continue
		end
		local target = found
		if target == nil then
			target = Instance.new(write.className);
			(target :: Instance).Name = write.name;
			(target :: Instance).Parent = lighting
			table.insert(report.created, write.className)
		else
			table.insert(report.adopted, write.className)
			if count > 1 then
				table.insert(report.extra, string.format("%s x%d", write.className, count))
			end
		end
		local keys: { string } = {}
		for key in pairs(write.props) do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			set(target :: Instance, key, write.props[key], write.className)
		end
	end

	return report
end

return Light

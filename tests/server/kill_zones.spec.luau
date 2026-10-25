-- kill_zones.spec: SHOTS TO DROP IT, per zone, per cartridge, per animal kind -- all of them (task 259).
--
-- KAREN, 2026-10-24, verbatim: *"when boar is running we need to aim in empty space to get hit in
-- head neck or heart like in real life smae with other animals"*, *"all shooting has to be like in
-- real life / this is a key of this game"*.
--
-- WHAT THE DOCTRINE SAYS, and it is the bar this file asserts against -- the Deutscher Jagdverband's
-- own *Jagdschein* material, read in `docs/research/2026-10-24-real-shooting.md` section 7 and
-- `docs/research/2026-09-25-hit-zones.md` source C/E, in the order a hunting education teaches it:
--   * BRAIN / NECK          instant. A small target.
--   * KAMMER (heart+lungs)  *the* shot. Dead in seconds; the animal may still run 20-80 m.
--   * BLATT (shoulder)      stops it, may not be lethal alone.
--   * WAIDWUND (paunch)     wounds; it runs a long way. Stokke et al. (2018) `mfd` ~ 429 studs.
--   * LEGS                  cripples, never kills.
-- So the ORDERING is the claim, and it is a claim about every animal in the game and every gun that
-- can be pointed at one: head and chest kill with one shot from anything; the paunch and the
-- hindquarters take more; a leg never kills on its own.
--
-- WHY A WHOLE FILE FOR IT (the Learning Agent's L-093, from task 219): the damage model is now FOUR
-- tables deep -- `WOUND.DAMAGE` keyed by the ammo WORD, `WOUND.DAMAGE_BY_WEAPON` keyed by the gun,
-- `WOUND.CLASS` deciding which zones `toughness` may not armour, and `KINDS[kind].toughness` -- and
-- task 250 shipped THREE severities that were wrong in the comment beside them, every one on the
-- DEER side, because that column is the boar's number divided by 1.2 and a severity there has to be
-- read off the DIVIDED number. Three cells, found by the Reviewer and not by a spec. This file is
-- the spec: it walks `KINDS.ORDER` x the guns x the zones and counts the shots, so a cell cannot be
-- wrong in silence and a NEW KIND cannot be added with only the arm that is already on screen tested.
--
-- THE METRIC IS "SHOTS TO DROP", AND THE WORD MATTERS. `Wound.severityFor` has three answers:
-- `lethal` (>= 100) is DOWN ON THE SPOT, `mortal` (>= 50) is *"it runs out `Wound.flightStuds` and
-- then dies"*, and `grazed` is a wound it survives. So one MORTAL hit also kills the animal -- after
-- a run of up to 420 studs -- and "shots to drop" is the number counted below because it is the one
-- a player experiences as the shot working. Where the doctrine's claim is about the RUN rather than
-- about the drop, the case asserts the SEVERITY instead and says so.
--
-- IT IS PURE AND IT NEEDS NO ANIMAL. `Wound.apply` is a reducer over a frozen state and a hit table,
-- and `Boar.toughnessFor` is a lookup -- so every number below is the shipped arithmetic over the
-- shipped tables, with no Workspace, no model and no drive.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/hit-zones.md (sections 3.1, 5, 11.2)
-- Note:   docs/research/2026-10-24-real-shooting.md (section 7), docs/research/2026-09-25-hit-zones.md
local ServerScriptService = game:GetService("ServerScriptService")

local Boar = require(ServerScriptService:WaitForChild("Boar"))

local Wound = Boar.Wound
local WOUND = Boar.CONFIG.WOUND
local KINDS = Boar.CONFIG.KINDS

-- A hard ceiling, so a data fault that makes an animal unkillable fails as a NUMBER rather than
-- hanging the suite in a while-loop. 40 is far past anything the tables can produce: the smallest
-- non-zero charge in the whole grid is one buckshot pellet into a legendary's legs, 6/2 = 3 points,
-- which reaches LETHAL in 34.
local MAX_SHOTS = 40

-- THE GUNS, AS THE WIRE SEES THEM. `weapon` is `hit.weapon` -- the `Weapons.WeaponId` the
-- `HitReport` has carried since task 140 -- and `nil` is every gun with no `DAMAGE_BY_WEAPON` row:
-- the shotgun, the semi-auto, and every hit written before task 250.
local GUNS = {
	{ label = "shotgun/semi-auto slug", weapon = nil, ammo = "Slug", pellets = 1 },
	{ label = "shotgun/semi-auto buck (9)", weapon = nil, ammo = "Buck", pellets = 9 },
	{ label = ".416 Rigby (rifle)", weapon = "rifle", ammo = "Slug", pellets = 1 },
	{ label = ".45-70 (lever)", weapon = "lever", ammo = "Slug", pellets = 1 },
}

-- Every zone the damage table knows, in the doctrine's own order of preference.
local ZONES = { "head", "chest", "rear", "body", "legs" }

-- HOW MANY OF THAT SHOT IT TAKES. `Wound.apply` is applied until the severity is `lethal`, exactly
-- as `Runtime:takeHit` does it, so the count is the game's and not a division.
local function shotsToDrop(kind: string, gun, zone: string): number
	local toughness = Boar.toughnessFor(kind, Boar.CONFIG)
	local state = Wound.new()
	for shot = 1, MAX_SHOTS do
		local severity
		state, severity = Wound.apply(state, {
			zone = zone,
			ammo = gun.ammo,
			pellets = gun.pellets,
			weapon = gun.weapon,
			at = shot,
		}, WOUND, toughness)
		if severity == "lethal" then
			return shot
		end
	end
	return MAX_SHOTS + 1
end

local function severityAfterOne(kind: string, gun, zone: string): string
	local toughness = Boar.toughnessFor(kind, Boar.CONFIG)
	local _, severity = Wound.apply(Wound.new(), {
		zone = zone,
		ammo = gun.ammo,
		pellets = gun.pellets,
		weapon = gun.weapon,
		at = 1,
	}, WOUND, toughness)
	return severity
end

return function()
	describe("the grid is complete -- every kind, every gun, every zone", function()
		-- L-093'S OWN REQUIREMENT, and it is the first `it` on purpose: a new animal kind added to
		-- `KINDS.ORDER` with no number of its own must still ENTER this file, or the table below
		-- tests the kind that happens to be on screen and nothing else.
		it("walks all seven kinds and drops the animal in every single cell", function()
			local cells = 0
			for _, kind in ipairs(KINDS.ORDER) do
				for _, gun in ipairs(GUNS) do
					for _, zone in ipairs(ZONES) do
						local shots = shotsToDrop(kind, gun, zone)
						if shots > MAX_SHOTS then
							error(string.format("[kill zones] %s is UNKILLABLE by %s in the %s", kind, gun.label, zone))
						end
						cells += 1
					end
				end
			end
			-- 7 kinds x 4 guns x 5 zones. Written out so a kind quietly dropped from `ORDER` fails
			-- here rather than shrinking the sweep.
			expect(#KINDS.ORDER).to.equal(7)
			expect(cells).to.equal(7 * #GUNS * #ZONES)
		end)
	end)

	describe("the doctrine: head and chest kill, the paunch wounds, a leg never kills", function()
		it("drops every kind with ONE shot in the head or the chest, from every gun", function()
			-- *the* shot in every hunting education in the German-speaking world, and the one Karen
			-- named ("head neck or heart"). `Wound.damageFor`'s own rule is that `toughness` may not
			-- armour a zone `WOUND.CLASS` calls `vital`, so this must hold for the legendary boar at
			-- toughness 2.0 and the deer at 1.2 as well as for a young sow.
			for _, kind in ipairs(KINDS.ORDER) do
				for _, gun in ipairs(GUNS) do
					for _, zone in ipairs({ "head", "chest" }) do
						local shots = shotsToDrop(kind, gun, zone)
						if shots ~= 1 then
							error(
								string.format(
									"[kill zones] %s in the %s with %s took %d shots, not 1",
									kind,
									zone,
									gun.label,
									shots
								)
							)
						end
					end
				end
			end
		end)

		it("never drops any kind with one shot in a LEG, from any gun", function()
			-- *"cripples, never kills"*. The strongest single charge into a leg in the whole grid is
			-- the .416's 60 points, which is MORTAL and 40 short of LETHAL -- so the animal is alive
			-- to be finished, which is the reaction the doctrine describes and task 116 built.
			for _, kind in ipairs(KINDS.ORDER) do
				for _, gun in ipairs(GUNS) do
					local shots = shotsToDrop(kind, gun, "legs")
					if shots < 2 then
						error(string.format("[kill zones] %s: one %s in a leg dropped it", kind, gun.label))
					end
				end
			end
		end)

		it("takes strictly more shots in the paunch and the hindquarters than in the vitals", function()
			-- The ORDERING is the claim, not the individual numbers: a `body` or `rear` hit may never
			-- be as good as a chest hit, for any animal, with any gun. That is what makes aiming at
			-- the vitals worth doing, which is the whole of Karen's sentence.
			for _, kind in ipairs(KINDS.ORDER) do
				for _, gun in ipairs(GUNS) do
					local chest = shotsToDrop(kind, gun, "chest")
					for _, zone in ipairs({ "body", "rear", "legs" }) do
						local shots = shotsToDrop(kind, gun, zone)
						if shots <= chest then
							error(
								string.format(
									"[kill zones] %s with %s: the %s (%d shots) is no worse than the chest (%d)",
									kind,
									gun.label,
									zone,
									shots,
									chest
								)
							)
						end
					end
				end
			end
		end)

		it("leaves a paunch-shot animal MORTAL and running, not grazed, for every centre-fire rifle", function()
			-- TASK 250'S OWN DEFECT, PINNED. A .416 through a stag's paunch was a GRAZE
			-- (55 / 1.2 = 45.8, under MORTAL 50) -- *"the one number this task exists to fix"*. It is
			-- 90 / 1.2 = 75 now (task 259 brought the cell down from 100 because 100 is `LETHAL`),
			-- which is still mortal, and the animal runs out `Wound.flightStuds` first. A graze there
			-- would mean a rifle bullet through the guts that the animal shrugs off, which is the
			-- opposite of the doctrine's *"runs on for a long way"*.
			for _, kind in ipairs(KINDS.ORDER) do
				local toughness = Boar.toughnessFor(kind, Boar.CONFIG) or 1
				for _, gun in ipairs({ GUNS[3], GUNS[4] }) do
					local severity = severityAfterOne(kind, gun, "body")
					-- THE LEGENDARY IS THE ONE EXCEPTION AND IT IS ASSERTED RATHER THAN EXCLUDED
					-- (task 259): at `toughness = 2.0` a .416's 90 points become 45, under MORTAL,
					-- so a gut shot on a `Schild` is a graze. The two cannot both hold -- the
					-- legendary's paunch is mortal only at 100 or above and a boar's paunch is
					-- non-lethal only below it -- and `Boar.CONFIG.WOUND` says why this is the half
					-- that was kept. His head and chamber are untouched, which the case above pins.
					if toughness >= 2 then
						expect(severity).to.equal("grazed")
					elseif severity ~= "mortal" and severity ~= "lethal" then
						error(string.format("[kill zones] %s: one %s in the paunch is %s", kind, gun.label, severity))
					end
				end
			end
		end)

		it("keeps the hindquarters short of lethal on both rifles -- Karen's crippling shot", function()
			-- `WOUND.CLASS.rear` is `crippling` and task 116 is Karen's *"can be hit to back part
			-- start to do circles with first legs on"*. At 100 points a rifle rump shot would be
			-- instant death and that reaction would never happen with a rifle in your hands, which
			-- is why 75 and 65 are deliberate and not a rounding. Asserted so a later "the rifle
			-- needs more damage" pass cannot delete the reaction by accident.
			for _, kind in ipairs(KINDS.ORDER) do
				local toughness = Boar.toughnessFor(kind, Boar.CONFIG) or 1
				for _, gun in ipairs({ GUNS[3], GUNS[4] }) do
					local severity = severityAfterOne(kind, gun, "rear")
					-- 75/2 = 37.5 and 65/2 = 32.5 on the legendary, so his rump is a graze for the
					-- same reason his paunch is: the armour. Asserted, not skipped.
					if toughness >= 2 then
						expect(severity).to.equal("grazed")
					else
						expect(severity).to.equal("mortal")
					end
				end
			end
		end)
	end)

	describe("toughness armours the hide and never the vitals", function()
		it("makes the legendary boar harder everywhere but the head and the chest", function()
			-- `toughness = 2.0`, and `Wound.damageFor` divides only where `WOUND.CLASS` does not say
			-- `vital`. So the legendary's chest is a male's chest and his flank is twice the work --
			-- which is the real animal's `Schild` (research note 2026-10-20-legendary-boar.md).
			for _, gun in ipairs(GUNS) do
				expect(shotsToDrop("legendary", gun, "chest")).to.equal(shotsToDrop("male", gun, "chest"))
				expect(shotsToDrop("legendary", gun, "head")).to.equal(shotsToDrop("male", gun, "head"))
				expect(shotsToDrop("legendary", gun, "body") > shotsToDrop("male", gun, "body")).to.equal(true)
			end
		end)

		it("makes every red deer kind 20 % harder than a boar outside the vitals", function()
			-- Karen, task 240: *"deer need more hits before die a bit more like 20% more"*. All three
			-- deer kinds carry 1.2 and the boar kinds carry none, so this is the one assertion that
			-- says the species differ at all -- and it would catch a deer row that lost its
			-- `toughness` in an edit.
			for _, kind in ipairs({ "stag", "hind", "calf" }) do
				expect(Boar.toughnessFor(kind, Boar.CONFIG)).to.equal(1.2)
				for _, gun in ipairs(GUNS) do
					expect(shotsToDrop(kind, gun, "chest")).to.equal(shotsToDrop("male", gun, "chest"))
				end
			end
			for _, kind in ipairs({ "male", "female", "cub" }) do
				expect(Boar.toughnessFor(kind, Boar.CONFIG)).to.equal(nil)
			end
		end)
	end)

	describe("the flight distances follow the wound, not the zone's name", function()
		it("gives the vitals no run and the paunch the longest one", function()
			-- Validated against Stokke et al. (2018): `efd = 1.14*M^0.73` m and
			-- `mfd = 4.92*M^0.73` m give 100 and 429 studs at 80 kg, against the shipped
			-- `FLIGHT.body = 120` and `FLIGHT.legs = 420`. A vital hit is 0: *"a short dash or a
			-- stumble, then down"*.
			expect(WOUND.FLIGHT.head).to.equal(0)
			expect(WOUND.FLIGHT.chest).to.equal(0)
			expect(WOUND.FLIGHT.legs > WOUND.FLIGHT.body).to.equal(true)
			expect(WOUND.FLIGHT.body > WOUND.FLIGHT.rear).to.equal(true)
		end)
	end)

	describe("the table the dispatch asked for", function()
		it("prints shots-to-drop for every kind, gun and zone", function()
			-- NOT AN ASSERTION, A REPORT -- the bounds above are the assertions. It is generated from
			-- the same `shotsToKill` they use, so the table a human reads and the table the harness
			-- enforces cannot disagree.
			for _, kind in ipairs(KINDS.ORDER) do
				local toughness = Boar.toughnessFor(kind, Boar.CONFIG)
				for _, gun in ipairs(GUNS) do
					local cells = {}
					for _, zone in ipairs(ZONES) do
						table.insert(cells, string.format("%s=%d", zone, shotsToDrop(kind, gun, zone)))
					end
					print(
						string.format(
							"[kill zones] %-9s tough=%-4s %-26s %s",
							kind,
							tostring(toughness),
							gun.label,
							table.concat(cells, " ")
						)
					)
				end
			end
			expect(true).to.equal(true)
		end)
	end)
end

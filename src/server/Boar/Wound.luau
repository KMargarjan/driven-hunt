-- Boar.Wound: the whole damage model, and nothing else. PURE: it holds no state, touches no
-- Instance, reads no clock, knows no Player and never calls a service. A wound state goes in, a new
-- frozen wound state comes out. That is what lets tests/server/boar_wound.spec.luau run the entire
-- model -- thresholds, flight distances, buckshot tallies, the speed ramp, the kill record -- in
-- microseconds with no world, exactly as Brain is driven with no physics.
--
-- TWO QUANTITIES, and that split IS the model. A single health pool cannot express Karen's spec:
-- under one pool more damage always means a shorter run, so a leg hit (which needs MORE hits) would
-- drop the boar SOONER than a body hit. So every zone carries
--   * damage (points, toward LETHAL) -- decides WHETHER it dies
--   * flight (studs)                 -- decides HOW FAR it gets first
-- Placement, not only energy, sets the distance. That is the finding taken from the wounding
-- literature; the reactions (bolt, slow while bleeding, limp on a leg hit) come from hunting
-- practice. Neither gives studs for a 400-stud arena, so the flight formula itself is invented and
-- says so in the research note -- but the two numbers it interpolates between are independently
-- validated there:
--   Stokke, Arnemo, Brainerd, Soderberg, Kraabol, Ytrehus (2018), "Defining animal welfare standards
--   in hunting: body mass determines thresholds for incapacitation time and flight distance",
--   Scientific Reports 8, CC BY 4.0. https://doi.org/10.1038/s41598-018-32102-0
--   efd = 1.14 * M^0.73 m and mfd = 4.92 * M^0.73 m give 100 and 429 studs at 80 kg, against this
--   config's FLIGHT.body = 120 and FLIGHT.legs = 420.
--
-- Design: docs/design/hit-zones.md (sections 5, 8.2)
-- Note:   docs/research/2026-09-25-hit-zones.md (source C)
local Wound = {}

export type Severity = "healthy" | "grazed" | "mortal" | "lethal"

export type WoundRecord = {
	at: number,
	zone: string,
	ammo: string,
	pellets: number,
	damage: number,
	distance: number?,
	shooterUserId: number?,
	shooterName: string?,
	tallyless: boolean,
	unknownPellets: number,
}

export type WoundState = {
	damage: number,
	byZone: { [string]: number },
	severity: Severity,
	flightStuds: number,
	flightRun: number,
	flightSeconds: number,
	wounds: { WoundRecord },
	contributors: { [number]: number },
	mortalWound: WoundRecord?,
}

export type KillRecord = {
	id: string,
	at: number,
	position: Vector3,
	killedByUserId: number?,
	killedByName: string?,
	killingZone: string,
	killingAmmo: string,
	killingDistance: number?,
	instant: boolean,
	flightStuds: number,
	flightSeconds: number,
	damage: number,
	shots: number,
	wounds: { WoundRecord },
	contributors: { [number]: number },
	aliveFor: number,
}

-- The zone charged when the weapon found no HitZone attribute (shotgun design section 5.3). It is
-- never free and never a crash: it is charged at the `body` row and counted, so a typo in an
-- attribute name shows up as Runtime:stats().unknownZoneHits instead of as an animal that will not
-- die.
local FALLBACK_ZONE = "body"

-- The zone a hit is CHARGED to, which is the zone it should be tallied under as well: an attribute
-- typo used to make its own bucket in Runtime:stats().zoneHits while its damage went to `body`, so
-- the two disagreed about the same pellets (TASKS.md 28a(g)). One function, one answer.
function Wound.chargedZone(zone: string, config): string
	return if config.DAMAGE[zone] then zone else FALLBACK_ZONE
end

local function freeze<T>(value: T): T
	if type(value) == "table" and not table.isfrozen(value :: any) then
		table.freeze(value :: any)
	end
	return value
end

-- table.freeze is shallow (https://luau.org/library#table-library), so the nested tables are frozen
-- too. A spec that writes into a returned state must error, or "apply never mutates its input" is
-- a comment rather than a property.
local function freezeState(state: WoundState): WoundState
	freeze(state.byZone)
	freeze(state.contributors)
	for _, record in ipairs(state.wounds) do
		freeze(record)
	end
	freeze(state.wounds)
	if state.mortalWound then
		freeze(state.mortalWound)
	end
	return freeze(state)
end

function Wound.new(): WoundState
	return freezeState({
		damage = 0,
		byZone = {},
		severity = "healthy" :: Severity,
		flightStuds = 0,
		flightRun = 0,
		flightSeconds = 0,
		wounds = {},
		contributors = {},
		mortalWound = nil,
	})
end

local function row(config, zone: string)
	return config.DAMAGE[zone] or config.DAMAGE[FALLBACK_ZONE]
end

-- Points for `pellets` projectiles of `ammo` in `zone`. A slug is one projectile charged at the
-- Slug column; every buckshot pellet is charged separately at the Pellet column.
function Wound.damageFor(zone: string, ammo: string, pellets: number, config): number
	local zoneRow = row(config, zone)
	local each = if ammo == "Slug" then zoneRow.Slug else zoneRow.Pellet
	return each * math.max(0, pellets)
end

function Wound.severityFor(damage: number, config): Severity
	if damage >= config.LETHAL then
		return "lethal"
	elseif damage >= config.MORTAL then
		return "mortal"
	elseif damage > 0 then
		return "grazed"
	end
	return "healthy"
end

function Wound.severity(state: WoundState, config): Severity
	return Wound.severityFor(state.damage, config)
end

-- Studs the boar runs before it collapses, from the WORST flight zone it has been hit in, shortened
-- as the damage climbs from MORTAL toward LETHAL. 0 when it is not going to die of this.
function Wound.flightStuds(state: WoundState, config): number
	local severity = Wound.severityFor(state.damage, config)
	if severity ~= "mortal" then
		return 0 -- lethal drops on the spot; grazed and healthy are not running out a wound
	end
	local maxFlight = 0
	for zone, damage in pairs(state.byZone) do
		if damage > 0 then
			local flight = config.FLIGHT[zone] or config.FLIGHT[FALLBACK_ZONE]
			maxFlight = math.max(maxFlight, flight)
		end
	end
	local span = config.LETHAL - config.MORTAL
	if span <= 0 then
		return 0
	end
	local over = math.clamp(state.damage - config.MORTAL, 0, span)
	return maxFlight * (1 - over / span)
end

-- Applies one hit. Returns a NEW frozen state and the severity AFTER the hit; never mutates its
-- input. `hit.zones` is the weapon's per-pellet tally: each pellet is charged in the zone it landed
-- in. When it is absent (an older caller, or a hand-written spec hit) every pellet is charged at the
-- dominant zone, the record says `tallyless`, and the Runtime counts it -- a degradation that is a
-- number in the harness report rather than a feeling in a playtest (design section 5.4).
function Wound.apply(state: WoundState, hit, config): (WoundState, Severity)
	local ammo = hit.ammo or "Slug"
	local pellets = if type(hit.pellets) == "number" then hit.pellets else 1
	local byZone = table.clone(state.byZone)

	local added = 0
	local unknownPellets = 0
	local tallyless = true

	local function charge(zone: string, count: number)
		if count <= 0 then
			return
		end
		local known = config.DAMAGE[zone] ~= nil
		if not known then
			unknownPellets += count
		end
		local key = if known then zone else FALLBACK_ZONE
		local points = Wound.damageFor(zone, ammo, count, config)
		byZone[key] = (byZone[key] or 0) + points
		added += points
	end

	if type(hit.zones) == "table" and next(hit.zones) ~= nil then
		tallyless = false
		for zone, count in pairs(hit.zones) do
			charge(zone, count)
		end
	else
		charge(hit.zone or FALLBACK_ZONE, pellets)
	end

	local record: WoundRecord = {
		at = hit.at or 0,
		zone = hit.zone or FALLBACK_ZONE,
		ammo = ammo,
		pellets = pellets,
		damage = added,
		distance = hit.distance,
		shooterUserId = hit.shooterUserId,
		shooterName = hit.shooterName,
		tallyless = tallyless,
		unknownPellets = unknownPellets,
	}

	local wounds = table.clone(state.wounds)
	table.insert(wounds, record)

	local contributors = table.clone(state.contributors)
	if hit.shooterUserId then
		contributors[hit.shooterUserId] = (contributors[hit.shooterUserId] or 0) + added
	end

	local damage = state.damage + added
	local severity = Wound.severityFor(damage, config)

	local next_: WoundState = {
		damage = damage,
		byZone = byZone,
		severity = severity,
		flightStuds = 0,
		flightRun = state.flightRun,
		flightSeconds = state.flightSeconds,
		wounds = wounds,
		contributors = contributors,
		-- The hit that crossed MORTAL (or LETHAL) is the killing shot, and it is recorded once:
		-- later pellets into a dying animal do not steal the kill.
		mortalWound = state.mortalWound or (if severity == "mortal" or severity == "lethal" then record else nil),
	}
	next_.flightStuds = Wound.flightStuds(next_, config)

	return freezeState(next_), severity
end

-- 1.0 while healthy or grazed. While mortal: bleeding out ramps the speed down across the flight,
-- and any damage in the legs multiplies a limp on top. Applied by the Brain to its speed SETPOINT,
-- never to the physics, so it is assertable with no physics at all (design section 5.5).
function Wound.speedScale(state: WoundState, config): number
	local severity = Wound.severityFor(state.damage, config)
	local bleed = 1
	if severity == "mortal" then
		local ratio = if state.flightStuds > 0 then math.clamp(state.flightRun / state.flightStuds, 0, 1) else 1
		bleed = config.WOUND_SPEED_START + (config.WOUND_SPEED_END - config.WOUND_SPEED_START) * ratio
	end
	local limp = if (state.byZone.legs or 0) > 0 then config.LIMP_SCALE else 1
	return bleed * limp
end

-- Accumulates the distance and the time a dying boar has covered since its mortal wound, and says
-- when it has run out. `collapse` is a boolean the Brain reacts to: the "has it run far enough"
-- arithmetic stays here, so the Brain never holds a copy of the damage model.
function Wound.advance(state: WoundState, movedStuds: number, dt: number, config): (WoundState, boolean)
	local severity = Wound.severityFor(state.damage, config)
	if severity ~= "mortal" and severity ~= "lethal" then
		return state, false
	end
	if severity == "lethal" then
		return state, true -- it dropped where it stood; there is nothing to run out
	end

	local next_: WoundState = {
		damage = state.damage,
		byZone = state.byZone,
		severity = state.severity,
		flightStuds = state.flightStuds,
		flightRun = state.flightRun + math.max(0, movedStuds),
		flightSeconds = state.flightSeconds + math.max(0, dt),
		wounds = state.wounds,
		contributors = state.contributors,
		mortalWound = state.mortalWound,
	}

	-- BLEED_OUT_MAX_SECONDS is the ceiling: a wounded boar wedged against a wall cannot live forever.
	local collapse = next_.flightRun >= next_.flightStuds or next_.flightSeconds >= config.BLEED_OUT_MAX_SECONDS
	return freezeState(next_), collapse
end

-- Everything Milestone 1.7 needs to score a kill, assembled once when the boar goes down. It carries
-- userIds and names, never Player instances: a boar can outlive a disconnect by 16 seconds and a
-- stored Player pins the instance (design section 8.4).
function Wound.killRecord(state: WoundState, id: string, position: Vector3, aliveFor: number, config): KillRecord
	local killing = state.mortalWound
	return freeze({
		id = id,
		at = if killing then killing.at else 0,
		position = position,
		killedByUserId = killing and killing.shooterUserId,
		killedByName = killing and killing.shooterName,
		killingZone = if killing then killing.zone else "unknown",
		killingAmmo = if killing then killing.ammo else "unknown",
		killingDistance = killing and killing.distance,
		instant = Wound.severityFor(state.damage, config) == "lethal",
		flightStuds = state.flightRun,
		flightSeconds = state.flightSeconds,
		damage = state.damage,
		shots = #state.wounds,
		wounds = state.wounds,
		contributors = state.contributors,
		aliveFor = aliveFor,
	})
end

return Wound

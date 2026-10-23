-- rifle.spec: the weapon TABLE, the rifle's row, the reducer driven with a row, and the scope's own
-- arithmetic. Pure: no Instances, no clock, no Player, no client.
--
-- WHAT THIS FILE IS FOR, in one sentence: a second weapon must not be able to change the first one.
-- So the shotgun's row is asserted field by field against `Shotgun.CONFIG` -- a number that moves
-- fails here rather than drifting -- and no row is allowed to carry a rule that belongs to the drive
-- or to the protocol.
--
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/rifle.md (sections 4, 8, 12, 13.1)
-- Note:   docs/research/2026-10-09-rifle-scope.md
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(ReplicatedStorage:WaitForChild("TestKit"))
local Lever = require(ReplicatedStorage:WaitForChild("Lever"))
local Rifle = require(ReplicatedStorage:WaitForChild("Rifle"))
local SemiAuto = require(ReplicatedStorage:WaitForChild("SemiAuto"))
local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Viewmodel = require(ReplicatedStorage:WaitForChild("Viewmodel"))
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local StateMachine = Weapon.StateMachine
local Validator = Weapon.Validator
local Hits = Weapon.Hits
local Shapes = Weapon.Shapes
local CONFIG = Shotgun.CONFIG

local function equipped(row)
	return StateMachine.setEquipped(StateMachine.initial(row), true)
end

return function()
	describe("the weapon table", function()
		it("holds exactly the four weapons, in hotbar order, frozen all the way down", function()
			local ids = Weapons.ids()
			-- FOUR SINCE TASK 225. It was two from task 148 -- Karen took the open-sighted Rigby out
			-- (*"please remove rifle without scope so we don't implement now"*) -- slot 3 was
			-- re-occupied by the LEVER-ACTION rifle in task 224, and slot 4 is the SEMI-AUTOMATIC
			-- SHOTGUN. The ORDER is the hotbar's (task 141), and slot 4 was APPENDED rather than
			-- inserted: a slot a player already knows must not move under him.
			expect(#ids).to.equal(4)
			expect(ids[1]).to.equal("shotgun")
			expect(ids[2]).to.equal("rifle")
			expect(ids[3]).to.equal("lever")
			expect(ids[4]).to.equal("semiauto")
			expect(Weapons.row("rifle_open")).to.equal(nil)
			expect(Weapons.row("nope")).to.equal(nil)
			expect(Weapons.row(nil)).to.equal(nil)
			expect(Weapons.PRIMARY).to.equal("shotgun")
			-- DEEP-FROZEN, which is defect (b) of the Task 23 review made into an assertion: a
			-- shallow freeze leaves the nested tables writable, and a weapon row is nested two deep.
			expect(table.isfrozen(Weapons.ROWS)).to.equal(true)
			expect(function()
				(Weapons.ROWS.rifle.RANGE_STUDS :: any).Slug = 1
			end).to.throw()
		end)

		it("carries the rifle only when the flag says so, and the rule is PURE", function()
			-- The flag is read in exactly one place (`Weapons.loadout`), and this is the function it
			-- reads into -- so both worlds are reachable in a spec with no flag set anywhere.
			local off = Weapons.loadoutFor(false)
			expect(#off).to.equal(1)
			expect(off[1]).to.equal("shotgun")
			local on = Weapons.loadoutFor(true)
			-- STILL TWO AFTER TASK 224, AND THAT IS THE POINT OF `OWNED_ONLY`. The table holds three
			-- weapons now, but the FREE PATH -- no ownership set, which is every un-wired world and
			-- every weapon spec -- is bit-for-bit what it was before the lever rifle existed. The
			-- Director's rule, 2026-10-20: *"a player who has NOT bought the lever rifle must never
			-- hold it"*.
			expect(#on).to.equal(2)
			expect(on[1]).to.equal("shotgun")
			expect(on[2]).to.equal("rifle")
			expect(Weapons.FLAG).to.equal("RIFLE")
		end)

		it("names a Tool for each weapon, and answers which id a Tool name is", function()
			expect(Weapons.ROWS.shotgun.toolName).to.equal("Shotgun")
			expect(Weapons.ROWS.rifle.toolName).to.equal("Rifle")
			expect(Weapons.isToolName("Shotgun")).to.equal(true)
			expect(Weapons.isToolName("Rifle")).to.equal(true)
			expect(Weapons.isToolName("Bucket")).to.equal(false)
			expect(Weapons.isToolName(nil)).to.equal(false)
			expect(Weapons.idForToolName("Rifle")).to.equal("rifle")
		end)
	end)

	describe("the shotgun's row is the shotgun's own numbers", function()
		it("reads every ballistic field out of Shotgun.CONFIG", function()
			local row = Weapons.ROWS.shotgun
			expect(row.RANGE_STUDS.Slug).to.equal(CONFIG.RANGE_STUDS.Slug)
			expect(row.RANGE_STUDS.Buck).to.equal(CONFIG.RANGE_STUDS.Buck)
			expect(row.PELLETS.Slug).to.equal(CONFIG.PELLETS.Slug)
			expect(row.PELLETS.Buck).to.equal(CONFIG.PELLETS.Buck)
			expect(row.SPREAD_FULL_DEG.Slug).to.equal(CONFIG.SPREAD_FULL_DEG.Slug)
			expect(row.SPREAD_FULL_DEG.Buck).to.equal(CONFIG.SPREAD_FULL_DEG.Buck)
			expect(row.BARRELS).to.equal(CONFIG.BARRELS)
			expect(row.BARREL_DELAY).to.equal(CONFIG.BARREL_DELAY)
			expect(row.INITIAL_AMMO).to.equal(CONFIG.INITIAL_AMMO)
			expect(row.START_RESERVE.Slug).to.equal(CONFIG.START_RESERVE.Slug)
			expect(row.HANDLE_SIZE).to.equal(CONFIG.HANDLE_SIZE)
			expect(row.GRIP).to.equal(CONFIG.GRIP)
			expect(row.MUZZLE_OFFSET).to.equal(CONFIG.MUZZLE_OFFSET)
			-- THE THREE BALLISTIC NUMBERS OF TASK 185, out of this gun's own CONFIG like every
			-- field above: the muzzle velocity, the drag coefficient and the zero.
			expect(row.MUZZLE_STUDS_PER_S.Slug).to.equal(CONFIG.MUZZLE_STUDS_PER_S.Slug)
			expect(row.MUZZLE_STUDS_PER_S.Buck).to.equal(CONFIG.MUZZLE_STUDS_PER_S.Buck)
			expect(row.DRAG_PER_STUD.Slug).to.equal(CONFIG.DRAG_PER_STUD.Slug)
			expect(row.DRAG_PER_STUD.Buck).to.equal(CONFIG.DRAG_PER_STUD.Buck)
			expect(row.ZERO_STUDS.Slug).to.equal(CONFIG.ZERO_STUDS.Slug)
			expect(row.ZERO_STUDS.Buck).to.equal(CONFIG.ZERO_STUDS.Buck)
		end)

		it("EVERY ammo of EVERY row flies, and is zeroed inside its own range (task 185)", function()
			-- The data fault `Ballistics.shotFor` refuses the shot for, asserted as unreachable in
			-- the shipped build. A zero beyond the range cap would mean a trajectory that never
			-- reaches the distance it is zeroed at, so a still target could be dead centre nowhere.
			for _, id in ipairs(Weapons.ids()) do
				local row = Weapons.ROWS[id]
				for _, ammo in ipairs(row.AMMO_KINDS) do
					expect(type(row.MUZZLE_STUDS_PER_S[ammo])).to.equal("number")
					expect(row.MUZZLE_STUDS_PER_S[ammo] > 0).to.equal(true)
					expect(type(row.DRAG_PER_STUD[ammo])).to.equal("number")
					expect(row.DRAG_PER_STUD[ammo] >= 0).to.equal(true)
					expect(type(row.ZERO_STUDS[ammo])).to.equal("number")
					expect(row.ZERO_STUDS[ammo] > 0).to.equal(true)
					expect(row.ZERO_STUDS[ammo] <= row.RANGE_STUDS[ammo]).to.equal(true)
				end
			end
		end)

		it("rebuilds the reload as data, with the four numbers it always had", function()
			local row = Weapons.ROWS.shotgun
			expect(#row.CYCLE).to.equal(4)
			expect(row.CYCLE[1].kind).to.equal("Break")
			expect(row.CYCLE[1].wait).to.equal(CONFIG.RELOAD_BREAK)
			expect(row.CYCLE[2].kind).to.equal("Load")
			expect(row.CYCLE[2].wait).to.equal(CONFIG.RELOAD_SHELL)
			expect(row.CYCLE[3].kind).to.equal("Load")
			expect(row.CYCLE[4].kind).to.equal("Close")
			expect(row.CYCLE[4].wait).to.equal(CONFIG.RELOAD_CLOSE)
			local sum = 0
			for _, step in ipairs(row.CYCLE) do
				sum += step.wait
			end
			expect(math.abs(sum - CONFIG.RELOAD_TOTAL) < 1e-9).to.equal(true)
			expect(row.CYCLE_TOTAL).to.equal(CONFIG.RELOAD_TOTAL)
			-- ...AND IT IS NOT AUTOMATIC. `R` runs the shotgun's reload and always has.
			expect(row.AUTO_CYCLE).to.equal(false)
		end)

		it("carries NO rule that belongs to the drive or to the protocol", function()
			-- A per-weapon safety arc would let a new weapon widen its own licence to shoot down the
			-- line. These live in `Shotgun.CONFIG` and the owner reads them there.
			for _, id in ipairs(Weapons.ids()) do
				local row = Weapons.ROWS[id] :: any
				expect(row.SAFETY_ARC_HALF_DEG).to.equal(nil)
				expect(row.CAMERA_ORIGIN_TOLERANCE).to.equal(nil)
				expect(row.MIN_AIM_DISTANCE).to.equal(nil)
				expect(row.FIRE_RATE_LIMIT).to.equal(nil)
				expect(row.ACTION_RATE_LIMIT).to.equal(nil)
				expect(row.STATE_RATE_LIMIT).to.equal(nil)
				expect(row.AUTO_EQUIP).to.equal(nil)
				expect(row.shouldArm).to.equal(nil)
				-- ...AND NO ROW CARRIES A FLIGHT NUMBER OR A GRAVITY (task 185). How finely the
				-- SERVER integrates, and how many projectiles it will carry at once, are properties
				-- of the server: a per-weapon step cap would let a new gun buy itself more server
				-- time, exactly as a per-weapon arc would widen its own licence.
				expect(row.FLIGHT_STEP_MAX_SECONDS).to.equal(nil)
				expect(row.FLIGHT_MAX_SUBSTEPS).to.equal(nil)
				expect(row.FLIGHT_MAX_SECONDS).to.equal(nil)
				expect(row.FLIGHT_MAX_LIVE_PELLETS).to.equal(nil)
				expect(row.GRAVITY_STUDS_PER_S2).to.equal(nil)
			end
		end)
	end)

	describe("the rifle's own numbers", function()
		it("reaches further and spreads less than the slug, with one projectile", function()
			local row = Weapons.ROWS.rifle
			expect(row.PELLETS.Slug).to.equal(1)
			expect(row.RANGE_STUDS.Slug > CONFIG.RANGE_STUDS.Slug).to.equal(true)
			expect(row.RANGE_STUDS.Slug).to.equal(800)
			-- FLATTER IS A SPREAD HERE AND NOT A DROP CURVE: nothing in this game models bullet
			-- drop, which the research note records as considered and rejected (FastCast2).
			expect(row.SPREAD_FULL_DEG.Slug < CONFIG.SPREAD_FULL_DEG.Slug).to.equal(true)
			-- THREE CHAMBERS SINCE TASK 142, because the magazine holds three (Karen).
			expect(row.BARRELS).to.equal(3)
			expect(row.MAGAZINE).to.equal(3)
		end)

		it("reaches 200 m, which is the distance Karen named", function()
			-- KAREN, 2026-10-14: *"hit it has to be precist and on 200m acurat"*. 200 m is 714.29
			-- studs at this game's 0.28 m/stud, and the shot flies `RANGE_STUDS[ammo]` studs
			-- from the MUZZLE -- so a range under that is a shot that cannot arrive however well it
			-- is aimed. THE OLD 450 WAS EXACTLY THAT, measured in Play before the change: 440 studs
			-- hit the plate, 455 and 470 produced no impact at all.
			local row = Weapons.ROWS.rifle
			local wanted = 200 / 0.28
			expect(row.RANGE_STUDS.Slug >= wanted).to.equal(true)
			TestKit.note(
				string.format(
					"rifle: range %d studs = %.0f m at 0.28 m/stud; 200 m needs %.0f",
					row.RANGE_STUDS.Slug,
					row.RANGE_STUDS.Slug * 0.28,
					wanted
				)
			)
		end)

		it("has NO random cone: the one bullet comes out exactly along the aim", function()
			-- THE SECOND HALF OF *"precist"* (task 183). TWO CLAIMS, AND ONLY ONE OF THEM IS A
			-- LITERAL. The pattern is bounded by the ROW's own half-cone, so a cone that appears
			-- when the data says zero fails whatever the data says; and the datum itself is pinned
			-- at zero here, in ONE place, because that is Karen's *"precist"* and a dial nobody
			-- should move by accident. A Director who decides on 1.2 MOA changes `Rifle.CONFIG` and
			-- this one line -- not three (the Reviewer's note, round 1, which counted three).
			local row = Weapons.ROWS.rifle
			expect(row.SPREAD_FULL_DEG.Slug).to.equal(0)
			local aim = Vector3.new(0.3, 0.1, -1).Unit
			local worst = 0
			for seed = 1, 50 do
				local directions = Weapon.Pattern.directions("Slug", aim, Random.new(seed), row)
				expect(#directions).to.equal(1)
				local cosine = math.clamp(directions[1]:Dot(aim), -1, 1)
				worst = math.max(worst, math.deg(math.acos(cosine)))
			end
			-- The whole half-cone the data allows, and nothing beyond it. At zero that is a
			-- floating-point hair, which is what "on the dot" means in a ray cast.
			expect(worst <= row.SPREAD_FULL_DEG.Slug / 2 + 1e-6).to.equal(true)
			TestKit.note(
				string.format(
					"rifle: spread %.3f deg FULL -> worst %.2e deg over 50 seeds = %.3f cm at 714 studs",
					row.SPREAD_FULL_DEG.Slug,
					worst,
					math.tan(math.rad(worst)) * 714.29 * 0.28 * 100
				)
			)
		end)

		it("kicks harder than the shotgun, and comes home inside half a second", function()
			-- KAREN, 2026-10-14: *"so recoil has to be more"*. The numbers are DATA
			-- (`weapons.rifle.fire` in src/shared/Viewmodel/poses.json), so this case asserts the
			-- RELATION she asked for -- more than the shotgun -- rather than nine literals.
			local rifleView = Viewmodel.view(Viewmodel.DATA, "rifle")
			local shotgunView = Viewmodel.view(Viewmodel.DATA, "shotgun")
			for _, field in ipairs({ "RECOIL_GUN_PITCH_DEG", "RECOIL_GUN_BACK_STUDS", "RECOIL_CAM_PITCH_DEG" }) do
				expect((rifleView :: any)[field] > (shotgunView :: any)[field]).to.equal(true)
			end
			-- A CEILING IS A CEILING ON SOMETHING: one kick has to fit under it, or the clamp eats
			-- the very shot it is there to bound. This is the case that would have caught shipping
			-- `gunPitchDeg` 19 against the old `maxGunPitchDeg` 12.5.
			expect(rifleView.RECOIL_GUN_PITCH_DEG < rifleView.RECOIL_MAX_GUN_PITCH_DEG).to.equal(true)
			expect(rifleView.RECOIL_GUN_BACK_STUDS < rifleView.RECOIL_MAX_GUN_BACK_STUDS).to.equal(true)
			expect(rifleView.RECOIL_CAM_PITCH_DEG < rifleView.RECOIL_MAX_CAM_PITCH_DEG).to.equal(true)
			-- AND IT RECOVERS, in the band the Director asked for (0.3 to 0.5 s): the spring's
			-- envelope is `exp(-zeta * omega * t)`, so the time to fall to a hundredth of the kick
			-- is `ln(100) / (zeta * omega)`. Asserted off the data, not off a stopwatch --
			-- `camera_mode.spec` is what drives the integrator itself.
			local omega = 2 * math.pi * rifleView.RECOIL_FREQUENCY_HZ
			local toOnePercent = math.log(100) / (rifleView.RECOIL_DAMPING_RATIO * omega)
			expect(toOnePercent > 0.25 and toOnePercent < 0.6).to.equal(true)
			-- ...and it does not go PAST the aim point on the way back, which is what keeps the
			-- reticle honest: under-damped below 1, but not so far that the view dips.
			expect(rifleView.RECOIL_DAMPING_RATIO >= 0.8).to.equal(true)
			TestKit.note(
				string.format(
					"rifle recoil: gun %.1f deg / %.2f studs, view %.1f deg (shotgun %.1f / %.2f / %.1f); "
						.. "%.2f Hz zeta %.2f -> 1%% in %.2f s",
					rifleView.RECOIL_GUN_PITCH_DEG,
					rifleView.RECOIL_GUN_BACK_STUDS,
					rifleView.RECOIL_CAM_PITCH_DEG,
					shotgunView.RECOIL_GUN_PITCH_DEG,
					shotgunView.RECOIL_GUN_BACK_STUDS,
					shotgunView.RECOIL_CAM_PITCH_DEG,
					rifleView.RECOIL_FREQUENCY_HZ,
					rifleView.RECOIL_DAMPING_RATIO,
					toOnePercent
				)
			)
		end)

		it("speaks with its own heavy-calibre voice, louder than the shotgun", function()
			-- KAREN, 2026-10-14: *"sound has to be harder like strong caliber"*. What a spec can
			-- assert about a sound is its SHAPE -- an id, a cut, a fade and a pitch -- plus the two
			-- comparisons her sentence actually makes: lower than the sample was recorded at, and
			-- louder than the other gun. NOBODY HERE HAS HEARD IT; her ears decide.
			local voice = Rifle.CONFIG.SOUND.shot
			expect(typeof(voice.id)).to.equal("string")
			expect(string.match(voice.id, "^rbxassetid://%d+$")).to.be.ok()
			-- EVERY SAMPLE IS CUT, and that is not optional: a clip from a gunfire library is a
			-- TAKE and may hold more than one bang (`Rifle.CONFIG.SOUND`'s own comment).
			expect(voice.cut > 0).to.equal(true)
			expect(voice.fade > 0 and voice.fade <= voice.cut).to.equal(true)
			-- A BIGGER BORE IS A LOWER BANG: the pitch is what turns a sample into a calibre.
			expect(voice.pitch < 1).to.equal(true)
			-- ------------------------------------------------- TASK 250
			-- KAREN, 2026-10-23: *"we need to change rifle sound and make more ... sound"*. THE
			-- RECORDING DID NOT CHANGE, because the whole licensed catalogue was swept and measured
			-- again and this sample is 2.3x the peak and 1.3x the length of every alternative -- so
			-- what changed is the WINDOW and the LEVEL, and those are what this case now pins.
			--
			-- THE CUT COVERS THE WHOLE MEASURED TAIL. The clip is 4.95 s with ONE bang at t=0 and a
			-- smooth decay that is silent from 2.8 s (PlaybackLoudness per 0.1 s on the client,
			-- 2026-10-23). `cut * pitch` is the seconds OF SOURCE played, and it must reach 2.8.
			expect(voice.cut * voice.pitch > 2.8).to.equal(true)
			-- ...AND THE FADE MUST NOT EAT ANY OF IT: the last `fade * pitch` seconds of source are
			-- going quiet, and that has to stay inside the dead part of the clip (from 2.35 s the
			-- sample is at loudness 2 of 442, half a per cent).
			expect((voice.cut - voice.fade) * voice.pitch > 2.3).to.equal(true)
			-- IT ASKS FOR A GAIN, which is the one dial that makes it louder (task 248's mechanism).
			expect(voice.gain > 1).to.equal(true)
			local rifleView = Viewmodel.view(Viewmodel.DATA, "rifle")
			local shotgunView = Viewmodel.view(Viewmodel.DATA, "shotgun")
			expect(rifleView.FIRE.volume.shot > shotgunView.FIRE.volume.shot).to.equal(true)
			-- AND THE SEMI-AUTO NO LONGER SHARES IT (task 250's item 1). This gun's voice is the
			-- one both rifles use and nothing else: a third gun on this sample is the bug Karen
			-- heard, and it is asserted from both ends.
			expect(voice.id).to.equal(Lever.CONFIG.SOUND.shot.id)
			expect(voice.id).never.to.equal(SemiAuto.CONFIG.SOUND.shot.id)
			TestKit.note(
				string.format(
					"rifle voice: %s cut %.2f fade %.2f pitch %.2f, volume %.2f (shotgun %.2f)",
					voice.id,
					voice.cut,
					voice.fade,
					voice.pitch,
					rifleView.FIRE.volume.shot,
					shotgunView.FIRE.volume.shot
				)
			)
		end)

		it("carries ONE ammo kind, and that kind is Slug on the wire", function()
			local row = Weapons.ROWS.rifle
			expect(#row.AMMO_KINDS).to.equal(1)
			expect(row.AMMO_KINDS[1]).to.equal("Slug")
			-- `Boar.Wound.damageFor` branches on exactly this string; a new word would be charged as
			-- a buckshot PELLET. The WORD on screen is the Hud's business and is not this.
			expect(row.INITIAL_AMMO).to.equal("Slug")
			expect(row.AMMO_LABEL.Slug).never.to.equal("SLUG")
		end)

		it("works its bolt in TWO steps and changes its magazine in three, and both totals are sums", function()
			local row = Weapons.ROWS.rifle
			expect(row.AUTO_CYCLE).to.equal(true)
			-- BACK, THEN FORWARD. There is no `Load` in a bolt cycle since task 142: the magazine
			-- already holds the rounds, which is the whole difference from the shotgun.
			expect(#row.CYCLE).to.equal(2)
			expect(row.CYCLE[1].kind).to.equal("Break")
			expect(row.CYCLE[2].kind).to.equal("Close")
			local function sumOf(steps)
				local sum = 0
				for _, step in ipairs(steps) do
					sum += step.wait
				end
				return sum
			end
			expect(math.abs(sumOf(row.CYCLE) - row.CYCLE_TOTAL) < 1e-9).to.equal(true)
			-- KAREN'S DIAL, PINNED (task 184). 2026-10-14: *"I think it reloads to fast has to be 1 s
			-- slower"*, of *"Bolt after each shot"* -- so 0.62 + 1. The literal is here and NOT in a
			-- second copy of the step waits: the sum above is what ties the list to this number.
			expect(row.CYCLE_TOTAL).to.equal(1.62)
			-- ...AND THE MAGAZINE CHANGE DID NOT FOLLOW IT, which is the half of task 184 Karen has
			-- not ruled on: she named the bolt after a shot and nothing else. If the two ever have to
			-- match, this case is where it will fail first.
			expect(row.RELOAD[2].wait < row.CYCLE[1].wait).to.equal(true)
			expect(row.RELOAD[3].wait < row.CYCLE[2].wait).to.equal(true)
			-- THE MAGAZINE CHANGE IS ITS OWN SEQUENCE, and it ends by chambering a round.
			expect(#row.RELOAD).to.equal(3)
			expect(row.RELOAD[1].kind).to.equal("Magazine")
			expect(row.RELOAD[2].kind).to.equal("Break")
			expect(row.RELOAD[3].kind).to.equal("Close")
			expect(math.abs(sumOf(row.RELOAD) - row.RELOAD_TOTAL) < 1e-9).to.equal(true)
			-- ...and the SHOTGUN has no second sequence at all, which is what keeps its four steps
			-- the only thing `R` has ever run on it.
			expect(Weapons.ROWS.shotgun.RELOAD).to.equal(nil)
			expect(Weapons.ROWS.shotgun.CYCLE_EJECTS).to.equal(nil)
			expect(row.CYCLE_EJECTS).to.equal("spent")
			-- THE SWAP'S LENGTH HAS TWO HOMES AND THEY MUST AGREE (the Reviewer's note): the SERVER
			-- times the window with `RELOAD[1].wait` and the CLIENT animates the box over
			-- `cycle.magazine.seconds`, so a drift between them is a box still sliding when the gun
			-- is ready, or home before it is. One of them is the pose data the Director tunes live,
			-- which is why this is asserted rather than one of them deleted.
			local swap = Viewmodel.DATA.weapons.rifle.cycle.magazine
			expect(math.abs(swap.seconds - row.RELOAD[1].wait) < 1e-9).to.equal(true)
		end)

		it("states a magnification that IS its field of view", function()
			-- THE ARITHMETIC, NOT A LABEL: m = tan(fovThird/2) / tan(fov/2). A hand-typed FOV that
			-- does not match the stated magnification fails here rather than shipping as a lie.
			local scope = Rifle.CONFIG.scope
			local m = math.tan(math.rad(70) / 2) / math.tan(math.rad(scope.aimFovDeg) / 2)
			-- 5e-3 AND NOT 1e-3, BECAUSE THE FOV IS WRITTEN TO TWO DECIMALS: 19.87 gives 3.998 and
			-- the exact 4x is 19.8694..., so a tighter tolerance would be asserting the rounding
			-- rather than the arithmetic. What this refuses is a magnification that is a LABEL.
			expect(math.abs(m - scope.magnification) < 5e-3).to.equal(true)
			-- ...and the shotgun has no scope at all, which is what `nil` means here.
			expect(Weapons.ROWS.shotgun.scope).to.equal(nil)
		end)

		it("describes its reticle in DEGREES, and is the CROSS Karen asked for", function()
			local r = Rifle.CONFIG.scope.reticle
			local eye = Rifle.CONFIG.scope.eyepiece
			-- KAREN, 2026-10-10: *"scope aiming has to be different cross look at the exaple I
			-- attached"*. Her reference is two hairlines across the whole lens: no ring round the
			-- centre, no duplex posts (task 146).
			expect(r.kind).to.equal("crosshair")
			expect(r.spanLens).to.equal(true)
			expect(r.ringOuterDeg).to.equal(nil)
			expect(r.postThickDeg).to.equal(nil)
			expect(r.postArmDeg).to.equal(nil)
			-- Every size that IS carried is an angle, so one reticle is true at any screen size and
			-- any zoom.
			expect(type(r.crossThickDeg)).to.equal("number")
			expect(r.crossThickDeg > 0).to.equal(true)
			-- A HAIR, NOT A BAR: `px = deg / fov * viewportY`, so at this scope's own FOV the line is
			-- a few pixels on a 1080-high viewport, which is what her frame measures. The conversion
			-- itself lives on the client (`Hud.reticleDegToPx`) and `rifle_client.spec` drives it;
			-- this is the same arithmetic without requiring a client module from the server.
			expect(r.crossThickDeg / Rifle.CONFIG.scope.aimFovDeg * 1080 < 6).to.equal(true)
			-- ...AND THE CROSS IS CUT TO THE GLASS, not to a number of its own: `spanLens` makes
			-- `Hud.layoutReticle` run the arms from the centre to the inside of the tube, so the
			-- eyepiece is what decides how long they are.
			expect(eye.diameterDeg / 2 > eye.rimThickDeg).to.equal(true)
			-- THE DOT IS A TOGGLE, defaulting ON and small (task 146): she asked for it on
			-- 2026-10-09 and the reference she sent has none.
			expect((r.dot :: any).enabled).to.equal(true)
			expect((r.dot :: any).deg < r.crossThickDeg * 2).to.equal(true)
		end)

		it("keeps the world outside the tube, and the tube is a scope body", function()
			-- The other two halves of her frame (task 146): a THICK dark ring round the glass, and
			-- the forest past it still visible rather than painted out.
			local eye = Rifle.CONFIG.scope.eyepiece
			-- 0.085 of a 1080-high frame is 92 px, measured off the reference; task 141 drew 0.45
			-- degrees, a hairline bevel.
			expect(eye.rimThickDeg > 1.0).to.equal(true)
			expect(eye.maskTransparency).to.be.ok()
			expect((eye.maskTransparency :: number) > 0).to.equal(true)
			expect((eye.maskTransparency :: number) < 1).to.equal(true)
			-- ...AND THE NUMBER THAT MATTERS IS THE GLASS, NOT THE CIRCLE ROUND IT (the Reviewer's
			-- finding 1, round 1). `diameterDeg` is the OUTER edge and the tube is drawn inward from
			-- it, so what the eye looks through is `diameterDeg - 2 * rimThickDeg`. Asserting the
			-- outer circle is what let round 1 ship a 0.716 lens while claiming 0.886.
			local glass = (eye.diameterDeg - 2 * eye.rimThickDeg) / Rifle.CONFIG.scope.aimFovDeg
			-- 0.889 is Karen's own frame: 960 px of clear glass in a 1080-high picture.
			expect(math.abs(glass - 0.889) < 0.02).to.equal(true)
			-- ...and the WHOLE circle is wider than the screen is tall, which is why her tube is cut
			-- off at the top and bottom instead of floating inside the frame.
			expect(eye.diameterDeg / Rifle.CONFIG.scope.aimFovDeg > 1.0).to.equal(true)
		end)
	end)

	describe("the reducer, driven with a row", function()
		it("fires once and is then busy for the rifle's OWN delay", function()
			local row = Weapons.ROWS.rifle
			local state = equipped(row)
			local fired, reason = StateMachine.apply(state, { kind = "Fire" }, 100, row)
			expect(reason).to.equal(nil)
			expect(fired.barrels[1]).to.equal("Spent")
			expect(math.abs(fired.busyUntil - (100 + row.BARREL_DELAY)) < 1e-9).to.equal(true)
			-- ...and a second trigger pull inside that window is refused, by the reducer and not by
			-- a flag somewhere else.
			local _, busy = StateMachine.apply(fired, { kind = "Fire" }, 100.01, row)
			expect(busy).to.equal("busy")
		end)

		it("works the bolt without touching the rest of the magazine", function()
			-- THE DEFECT THIS CASE EXISTS FOR (task 142): the shotgun's `Break` empties EVERY chamber
			-- and returns the unfired shells to the pocket, which on a magazine would throw two live
			-- rounds on the ground after every shot. `CYCLE_EJECTS = "spent"` is the whole fix and
			-- this is what proves it.
			local row = Weapons.ROWS.rifle
			local fired = StateMachine.apply(equipped(row), { kind = "Fire" }, 0, row)
			expect(fired.barrels[1]).to.equal("Spent")
			local open = StateMachine.apply(fired, { kind = "Break" }, 1, row)
			expect(open.open).to.equal(true)
			expect(open.barrels[1]).to.equal("Empty")
			-- THE OTHER TWO ARE STILL IN IT, and the pocket did not grow.
			expect(open.barrels[2]).to.equal("Live")
			expect(open.barrels[3]).to.equal("Live")
			expect(open.reserve.Slug).to.equal(row.START_RESERVE.Slug)
			expect(math.abs(open.busyUntil - (1 + row.CYCLE[1].wait)) < 1e-9).to.equal(true)
			-- THE ONE RULE EVERY SECOND TRIGGER PULL MEETS, and it lives in one place.
			local _, isOpen = StateMachine.apply(open, { kind = "Fire" }, 2, row)
			expect(isOpen).to.equal("is-open")
			-- Closing chambers the next round: no `Load`, because the magazine fed it.
			local shut = StateMachine.apply(open, { kind = "Close" }, 3, row)
			expect(shut.open).to.equal(false)
			expect(shut.selected).to.equal(2)
			expect(Weapon.roundsLeft(shut)).to.equal(2)
		end)

		it("empties in three shots and a magazine change fills it from the pocket", function()
			local row = Weapons.ROWS.rifle
			local state = equipped(row)
			expect(Weapon.roundsLeft(state)).to.equal(3)
			local clock = 0
			for shot = 1, 3 do
				local fired = StateMachine.apply(state, { kind = "Fire" }, clock, row)
				clock += 1
				local open = StateMachine.apply(fired, { kind = "Break" }, clock, row)
				clock += 1
				state = StateMachine.apply(open, { kind = "Close" }, clock, row)
				clock += 1
				expect(Weapon.roundsLeft(state)).to.equal(3 - shot)
			end
			-- EMPTY, AND THE POCKET IS UNTOUCHED: three fired cases went on the ground.
			expect(Weapon.roundsLeft(state)).to.equal(0)
			expect(state.reserve.Slug).to.equal(row.START_RESERVE.Slug)
			-- ...and a fourth trigger pull has nothing to fire.
			local _, dry = StateMachine.apply(state, { kind = "Fire" }, clock, row)
			expect(dry).to.equal("barrel-empty")
			-- THE MAGAZINE CHANGE: three rounds out of the pocket in ONE step.
			local full = StateMachine.apply(state, { kind = "Magazine" }, clock, row)
			expect(Weapon.roundsLeft(full)).to.equal(3)
			expect(full.reserve.Slug).to.equal(row.START_RESERVE.Slug - 3)
			expect(math.abs(full.busyUntil - (clock + row.RELOAD[1].wait)) < 1e-9).to.equal(true)
			-- ...and a FULL magazine refuses one, so the sequence cannot empty the pocket by itself.
			local _, refused = StateMachine.apply(full, { kind = "Magazine" }, clock + 10, row)
			expect(refused).to.equal("barrel-full")
		end)

		it("takes what the pocket has when it cannot fill the magazine", function()
			local row = Weapons.ROWS.rifle
			local state = table.clone(equipped(row)) :: any
			state.barrels = { "Empty", "Empty", "Empty" }
			state.loaded = { "None", "None", "None" }
			state.reserve = { Slug = 2 }
			local part = StateMachine.apply(Shotgun.deepFreeze(state), { kind = "Magazine" }, 0, row)
			expect(Weapon.roundsLeft(part)).to.equal(2)
			expect(part.reserve.Slug).to.equal(0)
			-- ...AND THE THIRD CHAMBER IS STILL EMPTY, so the rejection is the POCKET's and not the
			-- magazine's: `no-reserve`, which is the one the sequence walks past. (This case asserted
			-- `barrel-full` for one gate run -- the spec was wrong, not the reducer: a magazine with
			-- a hole in it is not full.)
			local _, why = StateMachine.apply(part, { kind = "Magazine" }, 10, row)
			expect(why).to.equal("no-reserve")
			-- ...and a magazine that really IS full refuses for the other reason, pocket or no pocket.
			local full = table.clone(part) :: any
			full.barrels = { "Live", "Live", "Live" }
			full.loaded = { "Slug", "Slug", "Slug" }
			local _, nope = StateMachine.apply(Shotgun.deepFreeze(full), { kind = "Magazine" }, 10, row)
			expect(nope).to.equal("barrel-full")
		end)

		it("charges each sequence its OWN window, now that the two disagree", function()
			-- TASK 184. `Break` and `Close` are in BOTH of the rifle's lists, and until Karen made the
			-- bolt a second slower they carried the same waits in each -- so the reducer's `waitFor`
			-- searched them in a fixed order and the order decided nothing. It decides everything now.
			-- Walk the magazine change and the gun must be busy for the MAGAZINE change's 0.26 s, not
			-- the bolt's 0.68: a window three times too long means `runCycle` waits out the step,
			-- asks for `Close`, is refused "busy", and finishes the reload down its error-recovery
			-- path instead of its own.
			local row = Weapons.ROWS.rifle
			local state = equipped(row)
			local reloadBreak = StateMachine.apply(state, { kind = "Break" }, 0, row, row.RELOAD)
			expect(math.abs(reloadBreak.busyUntil - row.RELOAD[2].wait) < 1e-9).to.equal(true)
			local reloadClose = StateMachine.apply(reloadBreak, { kind = "Close" }, 10, row, row.RELOAD)
			expect(math.abs(reloadClose.busyUntil - (10 + row.RELOAD[3].wait)) < 1e-9).to.equal(true)
			-- ...and the BOLT, walked as the bolt, gets the slower pair Karen asked for.
			local boltBreak = StateMachine.apply(state, { kind = "Break" }, 0, row, row.CYCLE)
			expect(math.abs(boltBreak.busyUntil - row.CYCLE[1].wait) < 1e-9).to.equal(true)
			local boltClose = StateMachine.apply(boltBreak, { kind = "Close" }, 10, row, row.CYCLE)
			expect(math.abs(boltClose.busyUntil - (10 + row.CYCLE[2].wait)) < 1e-9).to.equal(true)
			-- NO SEQUENCE NAMED IS THE OLD BEHAVIOUR, UNCHANGED: `CYCLE` first, which is what every
			-- caller that is not walking a list still gets.
			local guessed = StateMachine.apply(state, { kind = "Break" }, 0, row)
			expect(math.abs(guessed.busyUntil - row.CYCLE[1].wait) < 1e-9).to.equal(true)
			-- ...AND THE SHOTGUN CANNOT TELL THE DIFFERENCE: it has one sequence, so both answers are
			-- the same number and this is the half of the change that must stay invisible.
			local gun = Weapons.ROWS.shotgun
			local shotOpen = StateMachine.apply(equipped(gun), { kind = "Break" }, 0, gun)
			local shotOpen2 = StateMachine.apply(equipped(gun), { kind = "Break" }, 0, gun, gun.CYCLE)
			expect(shotOpen.busyUntil).to.equal(shotOpen2.busyUntil)
		end)

		it("leaves the SHOTGUN's break action exactly as it was", function()
			-- THE HALF THAT MUST NOT CHANGE. `CYCLE_EJECTS` is nil on the shotgun's row, so `Break`
			-- takes its old path: every chamber emptied and every UNFIRED shell back in its pocket.
			local row = Weapons.ROWS.shotgun
			local state = equipped(row)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 0, row)
			local open = StateMachine.apply(fired, { kind = "Break" }, 1, row)
			expect(open.barrels[1]).to.equal("Empty")
			expect(open.barrels[2]).to.equal("Empty")
			-- The unfired one went back: one more in the pocket than it started with.
			expect(open.reserve[state.ammo]).to.equal(state.reserve[state.ammo] + 1)
		end)

		it("refuses to feed an empty pocket, which is the one rejection the sequence walks past", function()
			local row = Weapons.ROWS.rifle
			local state = equipped(row)
			local empty = table.clone(state) :: any
			empty.reserve = { Slug = 0 }
			empty.barrels = { "Empty", "Empty", "Empty" }
			empty.loaded = { "None", "None", "None" }
			empty.open = true
			local _, reason = StateMachine.apply(Shotgun.deepFreeze(empty), { kind = "Load" }, 5, row)
			expect(reason).to.equal("no-reserve")
		end)

		it("refuses SelectAmmo on a weapon with one kind, at the wire", function()
			local ok, why = Validator.checkRequest("SelectAmmo", "Buck", Weapons.ROWS.rifle)
			expect(ok).to.equal(false)
			expect(why).to.equal("bad-request")
			expect((Validator.checkRequest("SelectAmmo", "Slug", Weapons.ROWS.rifle))).to.equal(true)
			-- ...and the shotgun still takes both, which is the half that must not change.
			expect((Validator.checkRequest("SelectAmmo", "Buck", Weapons.ROWS.shotgun))).to.equal(true)
			expect((Validator.checkRequest("Reload", nil, Weapons.ROWS.rifle))).to.equal(true)
		end)
	end)

	describe("the drawn gun and the world gun", function()
		it("resolves a geometry and a shape for every weapon, and they are not the same ones", function()
			for _, id in ipairs(Weapons.ids()) do
				local row = Weapons.ROWS[id]
				local geometry = Weapons.geometry(id)
				expect(geometry).to.be.ok()
				expect(#geometry.pieces(row) > 0).to.equal(true)
				local shape = Shapes.for_(id)
				expect(shape).to.be.ok()
				expect(#shape.pieces(row) > 0).to.equal(true)
			end
			-- THE WRONG GUN IS WORSE THAN A BOX. A rifle whose upload did not load must not fall
			-- back to the shotgun's parts list: that is a wrong gun that measures perfectly.
			expect(Shapes.for_("rifle")).never.to.equal(Shapes.for_("shotgun"))
			expect(Weapons.geometry("rifle")).never.to.equal(Weapons.geometry("shotgun"))
		end)

		it("reads any row written before this task as the SCOPED rifle", function()
			-- `SIGHT` is a field task 143 added, so every row and every caller that predates it has
			-- nil there -- and nil must mean the gun this repo already had, never a rifle that
			-- silently lost its scope. The Reviewer asked for this one by name.
			local geometry = Weapons.geometry("rifle")
			expect(geometry.sightKind(nil)).to.equal("scope")
			expect(geometry.sightKind({})).to.equal("scope")
			expect(geometry.sightKind({ SIGHT = "bead" })).to.equal("bead")
			expect(geometry.sightKind(Weapons.ROWS.rifle)).to.equal("scope")
			-- ...AND THE BEAD BRANCH IS STILL REACHABLE BY PARAMETER, which is why it survives task
			-- 148 taking the open-sighted ROW away: a table with `SIGHT = "bead"` is all it ever
			-- needed, and the next sight Karen asks for arrives the same way.
			expect(geometry.sightKind({ SIGHT = "bead" })).to.equal("bead")
			-- ...AND THE WORLD GUN OTHER PLAYERS SEE FOLLOWS IT. The fallback silhouette is what is
			-- drawn until the uploads land, so a scope tube on the open-sighted rifle would be a gun
			-- that changes shape as it loads.
			local function tubed(row): boolean
				for _, piece in ipairs(Shapes.for_(row.id).pieces(row)) do
					if piece.name == "RifleScope" then
						return true
					end
				end
				return false
			end
			expect(tubed(Weapons.ROWS.rifle)).to.equal(true)
			-- ...and a row that carries a bead gets no tube, driven by parameter now that the
			-- open-sighted row is gone (task 148).
			local beaded = table.clone(Weapons.ROWS.rifle) :: any
			beaded.SIGHT = "bead"
			expect(tubed(beaded)).to.equal(false)
		end)

		it("gives the rifle a cycle group that SLIDES, and the shotgun one that hinges", function()
			local rifleGeometry = Weapons.geometry("rifle")
			expect(rifleGeometry.CYCLE_KIND).to.equal("slide")
			expect(rifleGeometry.CYCLE_GROUP_NAME).to.equal("Bolt")
			-- The piece that moves is in the group that moves, and it is the only one.
			local moving = 0
			for _, piece in ipairs(rifleGeometry.pieces(Weapons.ROWS.rifle)) do
				if piece.group == "barrels" then
					moving += 1
					expect(piece.name).to.equal("Bolt")
				end
			end
			expect(moving).to.equal(1)
		end)

		it("puts the eye at the OCULAR lens, behind the scope and above the bore", function()
			local at = Weapons.geometry("rifle").layout(Weapons.ROWS.rifle)
			local sight = Weapons.geometry("rifle").sight(Weapons.ROWS.rifle)
			-- The eye looks into the rear of the tube: +Z is the butt end in the Handle's frame.
			expect(sight.Position.Z > 0).to.equal(true)
			expect(math.abs(sight.Position.Z - at.scopeOcularZ) < 1e-6).to.equal(true)
			-- ...and a scope sits well above the bore line, which is why its own axis is measured.
			expect(sight.Position.Y > 0.12).to.equal(true)
		end)
	end)

	describe("the drawn bolt, as data", function()
		it("BRINGS THE RIFLE BACK AND ROLLS IT TO WORK THE BOLT, which it did not until task 147", function()
			-- KAREN, 2026-10-10: *"after each shoot right hand has to reload like it does after 3
			-- shoots"*. MEASURED FIRST, and the premise turned out to be wrong: the per-shot bolt and
			-- the one that chambers after the magazine change are ONE definition and already
			-- identical -- `driven-hunt-runs/t147-bolt.luau` logged the right glove leaving the grip
			-- by 0.817 / 0.816 / 0.817 studs over 0.65 s after each shot, against 0.824 studs over
			-- 0.65 s after the magazine. Nor was recoil hiding it: the gun stops moving 0.23 s after
			-- the shot and the bolt starts at 0.28.
			--
			-- WHAT WAS ACTUALLY WRONG IS IN THIS CASE'S OWN OLD COMMENT. `cycle.gun` was seeded
			-- bit-for-bit equal to `carry.gun` -- "the Director may make them differ later, and then
			-- this case is the thing that says so out loud" -- so the rifle did not move at all while
			-- the bolt was worked, and all there was to see was a thumbnail-sized glove sliding ALONG
			-- the gun's own axis, behind the scope, foreshortened into nothing. The magazine change
			-- reads because the magazine drops 0.42 studs straight down into open space.
			--
			-- So the gun now comes back and rolls the action toward the eye for the cycle, which is
			-- what a shooter does and what makes the hand's travel something the eye can follow. It
			-- is the SAME pose for both bolts, because there is still only one of them.
			local cycle = Viewmodel.DATA.weapons.rifle.cycle
			local carry = Viewmodel.DATA.weapons.rifle.carry
			-- IT COMES BACK TOWARD THE SHOOTER and up, out of the corner of the screen.
			expect(cycle.gun.pos.z > carry.gun.pos.z).to.equal(true)
			expect(cycle.gun.pos.y > carry.gun.pos.y).to.equal(true)
			-- ...AND ROLLS, so the right side of the action -- the side the bolt handle is on --
			-- turns toward the camera instead of away from it.
			expect(cycle.gun.rot.z < carry.gun.rot.z).to.equal(true)
			expect(cycle.gun.rot.y > carry.gun.rot.y).to.equal(true)
			-- THESE FOUR PIN THE DIRECTION AND NOT THE DISTANCE, on purpose: the pose is content-lane
			-- data and the Director tunes it live, so a case that asserted the shipped numbers would
			-- fail on every tune. What must not come back is the gun standing still.
			-- `rot.x` IS THE ONE AXIS WITH NO ASSERTION, and that is a choice (the Reviewer's note,
			-- task 147): the pitch is the same 23.9 in both poses, because bringing the rifle out of
			-- the shoulder is a move and a roll rather than a tilt. If it ever needs to change, this
			-- is where to say so.
			expect(cycle.gun.rot.x).to.equal(carry.gun.rot.x)
		end)

		it("draws faster than the server's own steps, so the motion always finishes first", function()
			local row = Weapons.ROWS.rifle
			local cycle = Viewmodel.DATA.weapons.rifle.cycle
			expect(cycle.openSeconds < row.CYCLE[1].wait).to.equal(true)
			expect(cycle.closeSeconds < row.CYCLE[#row.CYCLE].wait).to.equal(true)
			expect(cycle.liftFraction > 0 and cycle.liftFraction < 1).to.equal(true)
		end)

		it("publishes the same flat names for both weapons, so no reader can get a nil", function()
			local shotgunView = Viewmodel.view(Viewmodel.DATA, "shotgun")
			local rifleView = Viewmodel.view(Viewmodel.DATA, "rifle")
			for key in pairs(shotgunView) do
				expect(rifleView[key]).never.to.equal(nil)
			end
			-- ...and the rifle's own two are there, which the shotgun's view does not have.
			expect(rifleView.BOLT_LIFT_DEG).to.be.ok()
			expect(rifleView.BOLT_DRAW_STUDS).to.be.ok()
		end)
	end)

	describe("the report carries the weapon", function()
		it("puts the weapon id on every report of a shot", function()
			local target = Instance.new("Part")
			target:SetAttribute("Damageable", true)
			target:SetAttribute("HitZone", "chest")
			local impacts = {
				{ instance = target, position = Vector3.new(0, 0, -10), normal = Vector3.new(0, 0, 1), distance = 10 },
			}
			local reports = Hits.group(nil :: any, impacts, "Slug", 123, "rifle")
			expect(#reports).to.equal(1)
			expect(reports[1].weapon).to.equal("rifle")
			-- ...and a caller that names no weapon still works, which is what keeps every record
			-- written before this task valid on the wire.
			local older = Hits.group(nil :: any, impacts, "Slug", 123)
			expect(older[1].weapon).to.equal(nil)
			target:Destroy()
		end)
	end)
end

--!strict
-- PlayerScripts.Weapon: the client's replica of the server's weapon state, and the owner of the
-- weapon's input bindings and cosmetics (CLAUDE.md rule 3).
--
-- THE REPLICA HAS NO SETTER. This module subscribes to StateChanged itself and stores a deep-frozen
-- snapshot; Weapon.get() returns it. Nothing else can write it -- rule 3 enforced by the engine
-- rather than by policy, and the reason the Hud can read weapon state without being able to corrupt
-- it (design section 3.2).
--
-- It writes NO camera. The aim ray reads workspace.CurrentCamera.CFrame in Input.luau; reading
-- creates no writer, and ROADMAP 1.4b's camera owner changes nothing here (design section 9).
--   RemoteEvent  https://create.roblox.com/docs/reference/engine/classes/RemoteEvent
--   BindableEvent https://create.roblox.com/docs/reference/engine/classes/BindableEvent
--
-- Design: docs/design/shotgun.md (sections 3.2, 5.6)
-- Note:   docs/research/2026-09-24-shotgun.md
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Flags = require(ReplicatedStorage:WaitForChild("Flags"))
-- EVERY WEAPON'S FOLDER NAME (task 294): the warm sweep below asks for all of them, not just the one
-- in the hand.
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local AssetFetch = require(ReplicatedStorage:WaitForChild("AssetFetch"))

local Effects = require(script.Effects)
local SoundOwner = require(script.Sound)
local Input = require(script.Input)
-- EXPORTED SO A SPEC CAN DRIVE THE CLIENT'S OWN SIMULATION with a scripted world and no boar
-- (task 266), the same reason `Weapon.Input` is exported above it. `Input` requires it too, and that
-- is one module requiring a sibling rather than two paths into it: `Input` is still the only firer
-- of `FireRequest`, and this is still the only place `Claim` is reached from outside.
local Claim = require(script.Claim)

local Weapon = {}

Weapon.Input = Input
Weapon.Claim = Claim
Weapon.Effects = Effects
-- The gun's sounds for the local player (task 112): one owner, like `Effects` one line up.
Weapon.Sound = SoundOwner

local snapshot: Shotgun.WeaponSnapshot? = nil
-- ...AND ONE PER WEAPON BESIDE IT (task 143). The server publishes PER TOOL, so a switch sends two
-- snapshots -- the gun being put away (`equipped = false`) and the gun being taken out -- and with
-- one variable the LAST one to arrive wins. MEASURED in the Forest Test with three Tools: switching
-- to slot 3 left `Weapon.get()` holding the rifle's un-equipped snapshot, so the readout went blank
-- and `CameraBoot`'s aim source refused to aim, for the open rifle AND for the shotgun after it.
-- With two weapons the ordering happened to come out right, which is why task 142 never saw it.
local byWeapon: { [string]: Shotgun.WeaponSnapshot } = {}
-- The id of the weapon whose newest snapshot claimed the hand. See `Weapon.get`.
local heldId: string? = nil
local signal = Instance.new("BindableEvent")
Weapon.Changed = signal.Event

-- MY OWN SHOT, THE MOMENT IT LANDS (task 92). Karen, after playing S2: "shooting has to have recoil a
-- bit" -- and recoil is the camera's, not the weapon's. This module still writes no camera: it says
-- "a shot of mine happened, out of this barrel" and `CameraBoot`, the composition root that knows both
-- owners, connects it to `Camera.kick`. Other players' shots do not fire it, because a kick belongs to
-- the person who pulled the trigger.
local firedSignal = Instance.new("BindableEvent")
Weapon.Fired = firedSignal.Event

local started = false

-- THE GUN IN THE PLAYER'S HANDS, which is the question every caller is really asking: the Hud's
-- readout, the aim source, the break source and the magazine edge all mean "the one I am holding".
-- The weapon whose newest snapshot said `equipped` is that one; with none equipped the newest
-- snapshot of any weapon is the honest answer, which is also what every caller written before three
-- weapons got.
-- ...AND THE CHOICE ITSELF IS PURE, so the two orderings a real switch produces can be driven by a
-- case instead of being hoped for in a session (`weapon_client.spec`, "answers with the gun whose
-- newest snapshot claimed the hand"). Pressing 1/2/3 cannot be replayed at all -- `VirtualInput`
-- refuses those keys, "permanently bound to a CoreGUI core action" (task 141) -- so a function is
-- the only honest way to pin it.
function Weapon.heldFrom(
	replicas: { [string]: Shotgun.WeaponSnapshot },
	id: string?,
	newest: Shotgun.WeaponSnapshot?
): Shotgun.WeaponSnapshot?
	-- THE ONE THAT SAID SO LAST, not whichever `pairs` reaches first (the Reviewer's note, round 1).
	-- A switch sends two snapshots and for the instant between them BOTH can say `equipped`, so an
	-- unordered scan answers at random; and a dropped un-equip -- `publish(..., "equip")` spends
	-- `EQUIP_RATE_LIMIT` per second and a switch costs two -- would leave a stale `equipped = true`
	-- that an unordered scan could keep choosing for ever. `id` is overwritten by every arriving
	-- snapshot that claims the hand, so the newest claim wins and a stale one is simply passed over.
	local held = if id ~= nil then replicas[id] else nil
	if held ~= nil and held.equipped then
		return held
	end
	return newest
end

function Weapon.get(): Shotgun.WeaponSnapshot?
	return Weapon.heldFrom(byWeapon, heldId, snapshot)
end

-- ---------------------------------------------------------------- ASK EARLY (task 294)
--
-- Karen, 2026-10-27: *"weapons loaded at first in game is rectangles"*. Nothing on a client asks for
-- a gun's meshes until something DRAWS one, so on a cold start the first gun handed over is drawn
-- while its meshes are still coming down. This asks for every weapon in the game at the LOBBY, long
-- before the hand-over -- the same door task 244 opened for the shop case (`Hud.ShopDisplay.warm`),
-- through the same owner (`AssetFetch`), so there is no second asking mechanism.
--
-- A FOLDER THAT HAS NOT REPLICATED YET IS SIMPLY NOT THERE: the server publishes them about 1.6 s in,
-- so the sweep repeats on a slow cadence until every weapon has been asked for, bounded by
-- `WARM_TRIES`. Returns how many ids this call asked for.
Weapon.WARM_TRIES = 30
Weapon.WARM_SECONDS = 1

function Weapon.warmWeapons(): number
	local holders: { Instance } = {}
	for id in pairs(Weapons.ROWS) do
		local geometry = Weapons.geometry(id)
		local folder = if geometry then ReplicatedStorage:FindFirstChild(geometry.FOLDER_NAME) else nil
		if folder ~= nil then
			table.insert(holders, folder)
		end
	end
	return AssetFetch.warm(holders)
end

function Weapon.start()
	if started then
		return
	end
	started = true

	-- THE WARM SWEEP, on its own thread: `PreloadAsync` yields and a gunless player must not wait
	-- for it (`WeaponBoot.server`'s own ordering rule, one layer over).
	task.spawn(function()
		for _ = 1, Weapon.WARM_TRIES do
			Weapon.warmWeapons()
			task.wait(Weapon.WARM_SECONDS)
		end
	end)

	local remotes = Shotgun.remotes()
	remotes.StateChanged.OnClientEvent:Connect(function(state)
		-- Deep-frozen on arrival: a shallow freeze would leave state.barrels writable, which was
		-- defect (b) of the Task 23 review.
		snapshot = Shotgun.deepFreeze(state)
		-- `weapon` has been on the wire since task 140; this is the first reader that needs it to
		-- keep the two guns apart rather than to name one.
		if snapshot ~= nil and snapshot.weapon ~= nil then
			byWeapon[snapshot.weapon] = snapshot
			if snapshot.equipped then
				heldId = snapshot.weapon
			elseif heldId == snapshot.weapon then
				heldId = nil
			end
		end
		signal:Fire(Weapon.get())
	end)
	remotes.ShotFired.OnClientEvent:Connect(function(payload)
		Effects.play(payload)
		if type(payload) == "table" and payload.shooterUserId == Players.LocalPlayer.UserId then
			firedSignal:Fire(payload)
		end
	end)
	-- THE BULLET ARRIVED (task 185). `ShotFired` above is the TRIGGER -- the flash, the smoke, the
	-- sound and, through `firedSignal`, the recoil; this is up to 0.365 s later and draws the dust
	-- where the shot actually landed, and nothing else. `firedSignal:Fire` is deliberately NOT here:
	-- the kick belongs to the trigger, and a grep for it in this file must find the one site above.
	remotes.ShotLanded.OnClientEvent:Connect(function(payload)
		Effects.playLanded(payload)
	end)

	-- WHETHER THIS CLIENT SENDS A HIT CLAIM, READ ONCE AT THIS OWNER'S BOUNDARY and handed inward
	-- (task 266) -- the only shape `docs/design/feature-flags.md` permits, and the same shape the
	-- server's own `ORIGIN_TOLERANCE_STUDS` and `CLAIMS_ON` already use.
	--
	-- THE SNAPSHOT GETTER GOES WITH IT, because the claim needs to know which load is in the chamber
	-- (the ammo decides the flight time, the range, and whether a claim is allowed at all) and
	-- `Input` may not require this module -- it is the child. One arrow per pair.
	Input.setClaimSource(Flags.isOn("HIT_CLAIM"), Weapon.get)

	Input.start()
end

return Weapon

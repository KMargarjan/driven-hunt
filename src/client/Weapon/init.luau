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

local Effects = require(script.Effects)
local SoundOwner = require(script.Sound)
local Input = require(script.Input)

local Weapon = {}

Weapon.Input = Input
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
-- A weapon that says `equipped` is that one; with none equipped the newest snapshot is the honest
-- answer, which is also what every caller written before three weapons got.
function Weapon.get(): Shotgun.WeaponSnapshot?
	for _, held in pairs(byWeapon) do
		if held.equipped then
			return held
		end
	end
	return snapshot
end

-- One named weapon's own replica, for a caller that means a specific gun rather than the held one.
function Weapon.getFor(id: string?): Shotgun.WeaponSnapshot?
	if id == nil then
		return nil
	end
	return byWeapon[id]
end

function Weapon.start()
	if started then
		return
	end
	started = true

	local remotes = Shotgun.remotes()
	remotes.StateChanged.OnClientEvent:Connect(function(state)
		-- Deep-frozen on arrival: a shallow freeze would leave state.barrels writable, which was
		-- defect (b) of the Task 23 review.
		snapshot = Shotgun.deepFreeze(state)
		-- `weapon` has been on the wire since task 140; this is the first reader that needs it to
		-- keep the two guns apart rather than to name one.
		if snapshot ~= nil and snapshot.weapon ~= nil then
			byWeapon[snapshot.weapon] = snapshot
		end
		signal:Fire(Weapon.get())
	end)
	remotes.ShotFired.OnClientEvent:Connect(function(payload)
		Effects.play(payload)
		if type(payload) == "table" and payload.shooterUserId == Players.LocalPlayer.UserId then
			firedSignal:Fire(payload)
		end
	end)

	Input.start()
end

return Weapon

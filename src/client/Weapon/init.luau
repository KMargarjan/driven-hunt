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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))

local Effects = require(script.Effects)
local Input = require(script.Input)

local Weapon = {}

Weapon.Input = Input
Weapon.Effects = Effects

local snapshot: Shotgun.WeaponSnapshot? = nil
local signal = Instance.new("BindableEvent")
Weapon.Changed = signal.Event

local started = false

function Weapon.get(): Shotgun.WeaponSnapshot?
	return snapshot
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
		signal:Fire(snapshot)
	end)
	remotes.ShotFired.OnClientEvent:Connect(function(payload)
		Effects.play(payload)
	end)

	Input.start()
end

return Weapon

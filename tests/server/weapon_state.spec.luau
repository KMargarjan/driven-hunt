-- weapon_state.spec: the pure reducer, the per-player registry, the rate limiter and the snapshot
-- converter. No Instances, no clock, no Player: every number below is written out rather than
-- imported from CONFIG, so a config that disagrees with the design is a finding and not a tautology
-- (the rule tests/server/test_arena.spec.luau already follows).
-- Pattern: TestEZ describe/it/expect (https://roblox.github.io/testez/api-reference/).
-- Design: docs/design/shotgun.md (sections 5.3, 13.1)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shotgun = require(ReplicatedStorage:WaitForChild("Shotgun"))
local Weapon = require(ServerScriptService:WaitForChild("Weapon"))

local StateMachine = Weapon.StateMachine
local Registry = Weapon.Registry
local Limits = Weapon.Limits
local CONFIG = Shotgun.CONFIG
-- THE WEAPON'S ROW (task 140). `StateMachine.apply` takes it and has no default, so every one of
-- these cases says which weapon it means -- and `ROW` is built from `Shotgun.CONFIG`, so every
-- number this file has ever asserted is still that config's.
local Weapons = require(ReplicatedStorage:WaitForChild("Weapons"))
local ROW = Weapons.ROWS.shotgun

return function()
	-- NOTHING IS LEFT IN THE AIR WHEN THIS SPEC IS DONE (task 185). `Weapon.forget`'s own leak
	-- claim is about tables KEYED BY a player (`Registry:count()`); the flight is keyed by SHOT and
	-- drains on its own, so this is the second, separate statement: a server at rest carries no
	-- projectiles. Every range cap in the game is reached inside 0.37 s, so by the time TestEZ gets
	-- here anything this suite fired has landed.
	describe("the shots in the air", function()
		it("has drained: a server at rest carries no projectiles", function()
			local deadline = os.clock() + 1
			while Weapon.flightCount() > 0 and os.clock() < deadline do
				task.wait()
			end
			expect(Weapon.flightCount()).to.equal(0)
			expect(Weapon.flightShots()).to.equal(0)
			-- NOTHING EVER REACHED THE CEILING: it is 5.5x the longest legitimate flight, so a
			-- non-zero count here is a bug and not a slow shot.
			expect(Weapon.stats().flightTimeouts).to.equal(0)
			expect(Weapon.stats().flightRefused).to.equal(0)
			-- ...AND NO WEAPON ROW IS MISSING ITS BALLISTICS, which would have refused every shot.
			expect(Weapon.stats().noBallistics).to.equal(0)
		end)
	end)

	describe("weapon state machine", function()
		it("starts closed, loaded and unequipped, and is frozen all the way down", function()
			local state = StateMachine.initial(ROW)
			expect(state.open).to.equal(false)
			expect(state.equipped).to.equal(false)
			expect(state.barrels[1]).to.equal("Live")
			expect(state.barrels[2]).to.equal("Live")
			expect(state.loaded[1]).to.equal("Slug")
			expect(state.selected).to.equal(1)
			-- THE DRIVE'S OWN ALLOWANCE, FROM THE CONFIG AND NOT FROM A LITERAL (task 171). It was 24
			-- of each from task 24 until Karen asked for *"limited ammon per round"*; reading
			-- `DRIVE_SHELLS` means the number can move again without this case saying something
			-- false, and one pocket per type (Karen, 2026-09-25) is still the shape being asserted.
			expect(Shotgun.CONFIG.DRIVE_SHELLS).to.equal(12)
			expect(state.reserve.Slug).to.equal(Shotgun.CONFIG.DRIVE_SHELLS)
			expect(state.reserve.Buck).to.equal(Shotgun.CONFIG.DRIVE_SHELLS)
			expect(state.busyUntil).to.equal(0)
			-- Defect (b): a shallow freeze left the arrays writable.
			expect(function()
				state.barrels[1] = "Spent"
			end).to.throw()
			expect(function()
				(state :: any).reserve = 99
			end).to.throw()
			expect(function()
				state.reserve.Slug = 99
			end).to.throw()
		end)

		it("keeps CONFIG frozen to its nested tables", function()
			expect(function()
				CONFIG.SPREAD_FULL_DEG.Buck = 9
			end).to.throw()
			expect(function()
				(CONFIG :: any).BARREL_DELAY = 9
			end).to.throw()
		end)

		it("refuses to fire an unequipped gun, and changes nothing", function()
			local state = StateMachine.initial(ROW)
			local next, reason = StateMachine.apply(state, { kind = "Fire" }, 0, ROW)
			expect(reason).to.equal("not-equipped")
			expect(next).to.equal(state)
		end)

		it("fires the selected barrel, spends it, and moves to the other one", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local next, reason = StateMachine.apply(state, { kind = "Fire" }, 100, ROW)
			expect(reason).to.equal(nil)
			expect(next.barrels[1]).to.equal("Spent")
			expect(next.loaded[1]).to.equal("None") -- a value, never a hole
			expect(next.barrels[2]).to.equal("Live")
			expect(next.selected).to.equal(2)
			expect(next.busyUntil).to.equal(100.25)
		end)

		it("rejects a second shot inside the barrel delay, returning the same table", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 100, ROW)
			local next, reason = StateMachine.apply(fired, { kind = "Fire" }, 100.1, ROW)
			expect(reason).to.equal("busy")
			expect(next).to.equal(fired)
		end)

		it("rejects a spent barrel and does not shuffle the selection when both are spent", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local one = StateMachine.apply(state, { kind = "Fire" }, 100, ROW)
			local two = StateMachine.apply(one, { kind = "Fire" }, 101, ROW)
			expect(two.barrels[2]).to.equal("Spent")
			local selected = two.selected
			local next, reason = StateMachine.apply(two, { kind = "Fire" }, 102, ROW)
			expect(reason).to.equal("barrel-empty")
			expect(next.selected).to.equal(selected)
		end)

		it("runs break, load, load, close and never lets a second break in", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 0, ROW)
			local open = StateMachine.apply(fired, { kind = "Break" }, 1, ROW)
			expect(open.open).to.equal(true)
			expect(open.barrels[1]).to.equal("Empty")
			expect(open.loaded[2]).to.equal("None")

			-- This rejection IS the uninterruptible reload (feel default 2).
			local again, reason = StateMachine.apply(open, { kind = "Break" }, 2, ROW)
			expect(reason).to.equal("is-open")
			expect(again).to.equal(open)

			local one = StateMachine.apply(open, { kind = "Load" }, 2, ROW)
			local two = StateMachine.apply(one, { kind = "Load" }, 3, ROW)
			expect(two.barrels[1]).to.equal("Live")
			expect(two.barrels[2]).to.equal("Live")
			expect(two.loaded[1]).to.equal("Slug")
			-- THE DRIVE'S ALLOWANCE, minus the two loaded here, plus the ONE unfired shell Break
			-- returned (the other barrel was spent by the Fire above). Karen, 2026-09-25 for the
			-- returned shell; task 171 for the allowance, which is 12 and was 24.
			expect(two.reserve.Slug).to.equal(Shotgun.CONFIG.DRIVE_SHELLS - 1)

			local full, closeReason = StateMachine.apply(two, { kind = "Load" }, 4, ROW)
			expect(closeReason).to.equal("barrel-full")
			expect(full).to.equal(two)

			local closed = StateMachine.apply(two, { kind = "Close" }, 5, ROW)
			expect(closed.open).to.equal(false)
			expect(closed.selected).to.equal(1)

			local firing, fireReason = StateMachine.apply(open, { kind = "Fire" }, 6, ROW)
			expect(fireReason).to.equal("is-open")
			expect(firing).to.equal(open)
		end)

		it("will not load a closed gun, or one with nothing left", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local closedReason = select(2, StateMachine.apply(state, { kind = "Load" }, 0, ROW))
			expect(closedReason).to.equal("is-closed")

			local empty = table.clone(state) :: any
			empty.open = true
			empty.reserve = { Slug = 0, Buck = 0 }
			empty.barrels = { "Empty", "Empty" }
			empty.loaded = { "None", "None" }
			local next, reason = StateMachine.apply(Shotgun.deepFreeze(empty), { kind = "Load" }, 0, ROW)
			expect(reason).to.equal("no-reserve")
			expect(next.barrels[1]).to.equal("Empty")
		end)

		it("selects the kind the NEXT load uses, and rejects an unknown action", function()
			-- The primitive still does one thing. Since Karen's playtest the OWNER follows it with a
			-- full Break/Load/Load/Close, which is what makes X change the shells in the gun.
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local next = StateMachine.apply(state, { kind = "SelectAmmo", ammo = "Buck" }, 0, ROW)
			expect(next.ammo).to.equal("Buck")
			expect(next.loaded[1]).to.equal("Slug") -- this primitive alone does not rewrite them
			expect(select(2, StateMachine.apply(state, { kind = "Nope" :: any }, 0, ROW))).to.equal("bad-action")
			expect(select(2, StateMachine.apply(state, { kind = "SelectAmmo", ammo = "Grenade" :: any }, 0, ROW))).to.equal(
				"bad-action"
			)
		end)

		it("never mutates the state it was given", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local before = { state.barrels[1], state.barrels[2], state.loaded[1], state.reserve.Slug }
			local next = StateMachine.apply(state, { kind = "Fire" }, 0, ROW)
			expect(next).never.to.equal(state)
			expect(state.barrels[1]).to.equal(before[1])
			expect(state.barrels[2]).to.equal(before[2])
			expect(state.loaded[1]).to.equal(before[3])
			expect(state.reserve.Slug).to.equal(before[4])
		end)

		it("returns unfired shells to their own pocket when the action is broken", function()
			-- Karen, 2026-09-25: "the unfired shells of the old type go back to the reserve".
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local open = StateMachine.apply(state, { kind = "Break" }, 0, ROW)
			local shells = Shotgun.CONFIG.DRIVE_SHELLS
			expect(open.reserve.Slug).to.equal(shells + 2) -- the two live slugs came back
			expect(open.reserve.Buck).to.equal(shells)

			local fired = StateMachine.apply(state, { kind = "Fire" }, 0, ROW)
			local half = StateMachine.apply(fired, { kind = "Break" }, 1, ROW)
			-- one spent case is gone, one live shell returned
			expect(half.reserve.Slug).to.equal(shells + 1)
		end)

		it("swaps the gun to the other type, pocket by pocket", function()
			-- The sequence the owner runs on X: SelectAmmo, then Break/Load/Load/Close.
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local swapped = StateMachine.apply(state, { kind = "SelectAmmo", ammo = "Buck" }, 0, ROW)
			local open = StateMachine.apply(swapped, { kind = "Break" }, 1, ROW)
			local one = StateMachine.apply(open, { kind = "Load" }, 2, ROW)
			local two = StateMachine.apply(one, { kind = "Load" }, 3, ROW)
			local closed = StateMachine.apply(two, { kind = "Close" }, 4, ROW)

			expect(closed.ammo).to.equal("Buck")
			expect(closed.loaded[1]).to.equal("Buck")
			expect(closed.loaded[2]).to.equal("Buck")
			expect(closed.barrels[1]).to.equal("Live")
			local shells = Shotgun.CONFIG.DRIVE_SHELLS
			expect(closed.reserve.Slug).to.equal(shells + 2) -- two slugs back in the pocket
			expect(closed.reserve.Buck).to.equal(shells - 2) -- two buckshot out of it
			expect(closed.open).to.equal(false)
		end)

		it("cannot load a type the player has none of", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local drained = table.clone(state) :: any
			drained.reserve = { Slug = Shotgun.CONFIG.DRIVE_SHELLS, Buck = 0 }
			drained.ammo = "Buck"
			drained.open = true
			drained.barrels = { "Empty", "Empty" }
			drained.loaded = { "None", "None" }
			local next, reason = StateMachine.apply(Shotgun.deepFreeze(drained), { kind = "Load" }, 0, ROW)
			expect(reason).to.equal("no-reserve")
			expect(next.barrels[1]).to.equal("Empty")
		end)

		it("agrees with the 2.0 s reload Karen asked for", function()
			expect(CONFIG.RELOAD_BREAK + 2 * CONFIG.RELOAD_SHELL + CONFIG.RELOAD_CLOSE).to.equal(CONFIG.RELOAD_TOTAL)
			expect(CONFIG.RELOAD_TOTAL).to.equal(2.0)
			expect(0.5 + 2 * 0.45 + 0.6).to.equal(2.0)
		end)

		it("applies 10000 times in under 100 ms", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local started = os.clock()
			for index = 1, 10000 do
				StateMachine.apply(state, { kind = "Fire" }, index, ROW)
			end
			expect(os.clock() - started < 0.1).to.equal(true)
		end)
	end)

	describe("weapon snapshot", function()
		it("turns the deadline into a duration, drops the server-only fields, and freezes", function()
			local state = StateMachine.setEquipped(StateMachine.initial(ROW), true)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 10, ROW)
			local snapshot = Shotgun.snapshot(fired, 10.1, "NO BUCK")
			expect(snapshot.notice).to.equal("NO BUCK")
			expect(Shotgun.snapshot(fired, 10.1).notice).to.equal(nil)
			expect(snapshot.busyFor > 0.14 and snapshot.busyFor < 0.16).to.equal(true)
			expect(Shotgun.snapshot(fired, 99).busyFor).to.equal(0)
			expect((snapshot :: any).busyUntil).to.equal(nil)
			expect((snapshot :: any).epoch).to.equal(nil)
			expect(function()
				snapshot.barrels[1] = "Live"
			end).to.throw()
		end)
	end)

	describe("weapon registry", function()
		it("holds and then completely forgets everything keyed by one key", function()
			local registry = Registry.new()
			local key = {}
			registry:set(key, { reserve = 1 })
			registry:setBucket(key, "fire", { windowStart = 0, count = 1 })
			expect(registry:get(key).reserve).to.equal(1)
			expect(registry:bucket(key, "fire").count).to.equal(1)
			expect(registry:count()).to.equal(1)

			registry:forget(key) -- defect (c): the leak, closed by a tested function
			expect(registry:get(key)).to.equal(nil)
			expect(registry:bucket(key, "fire")).to.equal(nil)
			expect(registry:count()).to.equal(0)
		end)
	end)

	describe("weapon rate limit", function()
		it("allows the budget in a window, refuses the rest, and rolls over", function()
			local bucket = nil
			local allowed
			for _ = 1, 6 do
				allowed, bucket = Limits.allow(bucket, 100, 6)
				expect(allowed).to.equal(true)
			end
			allowed, bucket = Limits.allow(bucket, 100, 6)
			expect(allowed).to.equal(false)
			allowed = Limits.allow(bucket, 101.5, 6)
			expect(allowed).to.equal(true)
		end)

		it("never mutates the caller's bucket", function()
			local bucket = { windowStart = 100, count = 1 }
			local _, next = Limits.allow(bucket, 100, 6)
			expect(next).never.to.equal(bucket)
			expect(bucket.count).to.equal(1)
		end)
	end)

	-- ---------------------------------------------------------------- the pocket that does not go
	-- down (task 221)
	--
	-- KAREN, 2026-10-20: *"Unlimited amunition"*. It is the POCKET and not the gun: the barrels
	-- still hold two and he still breaks and loads, because a reload that no longer costs a
	-- keypress would change the FEEL of the weapon and that is Karen's to judge.
	describe("unlimited ammunition", function()
		-- `apply` answers `(state, reason)`; every case here expects the action to be legal, so a
		-- refusal fails loudly with its own reason rather than as a confusing later assertion.
		local function ok(state, reason)
			expect(reason).to.equal(nil)
			return state
		end

		-- EQUIPPED, because `apply` refuses every action on a gun nobody is holding
		-- (`"not-equipped"`) -- the idiom every other case in this file uses.
		local function boundless()
			return StateMachine.setEquipped(
				StateMachine.initial(ROW, {
					ammo = "Buck",
					reserve = table.clone(ROW.START_RESERVE),
					unlimited = { Buck = true },
				}),
				true
			)
		end

		it("never empties the pocket it is bought for, and never refuses for want of one", function()
			local state = boundless()
			local pocket = state.reserve.Buck
			expect(pocket).to.equal(ROW.START_RESERVE.Buck)
			-- BREAK, LOAD, LOAD: the two barrels are filled and the NUMBER DOES NOT MOVE.
			local broken = ok(StateMachine.apply(state, { kind = "Break" }, 100, ROW))
			local one = ok(StateMachine.apply(broken, { kind = "Load" }, 200, ROW))
			expect(one.reserve.Buck).to.equal(pocket)
			local two = ok(StateMachine.apply(one, { kind = "Load" }, 300, ROW))
			expect(two.reserve.Buck).to.equal(pocket)
			expect(two.barrels[1]).to.equal("Live")
			expect(two.barrels[2]).to.equal("Live")
			-- ...AND A POCKET AT ZERO STILL LOADS, which is the whole of what was bought: the
			-- `"no-reserve"` refusal is skipped rather than worked around.
			local empty = StateMachine.setEquipped(
				StateMachine.initial(ROW, {
					ammo = "Buck",
					reserve = { Buck = 0, Slug = 0 },
					unlimited = { Buck = true },
				}),
				true
			)
			local openEmpty = ok(StateMachine.apply(empty, { kind = "Break" }, 100, ROW))
			local loaded, reason = StateMachine.apply(openEmpty, { kind = "Load" }, 200, ROW)
			expect(reason).to.equal(nil)
			expect(loaded.barrels[1]).to.equal("Live")
			expect(loaded.reserve.Buck).to.equal(0)
		end)

		it("does not put an unfired shell back either, so the number never climbs", function()
			-- `Break` returns a LIVE shell to its own pocket -- Karen, 2026-09-25: *"the unfired
			-- shells of the old type go back to the reserve"*. Nothing was taken out of an
			-- unlimited pocket, so putting one back would make the readout climb for ever.
			local state = boundless()
			local pocket = state.reserve.Buck
			local broken = ok(StateMachine.apply(state, { kind = "Break" }, 100, ROW))
			expect(broken.reserve.Buck).to.equal(pocket)
			-- ...AND A LIMITED POCKET STILL DOES, which is the rule this does not change.
			local plain = StateMachine.setEquipped(StateMachine.initial(ROW, nil), true)
			local plainBroken = ok(StateMachine.apply(plain, { kind = "Break" }, 100, ROW))
			expect(plainBroken.reserve[plain.ammo]).to.equal(plain.reserve[plain.ammo] + #plain.barrels)
		end)

		it("fills the magazine without spending one, and leaves the barrels alone", function()
			local state = boundless()
			local pocket = state.reserve.Buck
			local fired = ok(StateMachine.apply(state, { kind = "Fire" }, 100, ROW))
			local topped = ok(StateMachine.apply(fired, { kind = "Magazine" }, 200, ROW))
			expect(topped.reserve.Buck).to.equal(pocket)
			-- THE BARRELS ARE NOT TOUCHED BY ANY OF THIS: two chambers, and the gun is still a
			-- break action that has to be reloaded.
			expect(#topped.barrels).to.equal(ROW.BARRELS)
			expect(ROW.BARRELS).to.equal(2)
		end)

		it("is today's game for every state written before it existed", function()
			-- nil ALLOWANCE IS NO UNLIMITED POCKETS, which is every caller before the entitlement.
			local plain = StateMachine.setEquipped(StateMachine.initial(ROW, nil), true)
			expect(next(plain.unlimited)).to.equal(nil)
			local broken = ok(StateMachine.apply(plain, { kind = "Break" }, 100, ROW))
			local loaded = ok(StateMachine.apply(broken, { kind = "Load" }, 200, ROW))
			-- Break put two live shells back and the load took one: the pocket moved, as it always
			-- did.
			expect(loaded.reserve[plain.ammo]).to.equal(plain.reserve[plain.ammo] + #plain.barrels - 1)
			-- A REFILL WITH NO ALLOWANCE CLEARS IT, so a drive boundary cannot leave a pocket
			-- boundless after the entitlement is gone.
			local refilled = ok(StateMachine.apply(boundless(), { kind = "Refill" }, 300, ROW))
			expect(next(refilled.unlimited)).to.equal(nil)
			local kept = ok(StateMachine.apply(plain, { kind = "Refill", unlimited = { Buck = true } }, 300, ROW))
			expect(kept.unlimited.Buck).to.equal(true)
		end)

		it("prints a word and not a number on the readout", function()
			-- THE SNAPSHOT CARRIES IT ONLY WHEN THERE IS ONE, so a build where nobody bought it is
			-- byte-identical to the one before this task.
			local plain = Shotgun.snapshot(StateMachine.initial(ROW, nil), 0)
			expect(plain.unlimited).to.equal(nil)
			local rich = Shotgun.snapshot(boundless(), 0)
			expect(rich.unlimited).to.be.ok()
			expect((rich.unlimited :: any).Buck).to.equal(true)
			expect(Shotgun.CONFIG.POCKET_UNLIMITED_TEXT).to.equal("INF")
			-- ...AND IT IS NOT `--`, which in this repo means UNKNOWN. An unlimited pocket is the
			-- opposite of unknown.
			expect(Shotgun.CONFIG.POCKET_UNLIMITED_TEXT).never.to.equal("--")
		end)
	end)
end

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

return function()
	describe("weapon state machine", function()
		it("starts closed, loaded and unequipped, and is frozen all the way down", function()
			local state = StateMachine.initial(CONFIG)
			expect(state.open).to.equal(false)
			expect(state.equipped).to.equal(false)
			expect(state.barrels[1]).to.equal("Live")
			expect(state.barrels[2]).to.equal("Live")
			expect(state.loaded[1]).to.equal("Slug")
			expect(state.selected).to.equal(1)
			expect(state.reserve.Slug).to.equal(24)
			expect(state.reserve.Buck).to.equal(24) -- one pocket per type (Karen, 2026-09-25)
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
			local state = StateMachine.initial(CONFIG)
			local next, reason = StateMachine.apply(state, { kind = "Fire" }, 0)
			expect(reason).to.equal("not-equipped")
			expect(next).to.equal(state)
		end)

		it("fires the selected barrel, spends it, and moves to the other one", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local next, reason = StateMachine.apply(state, { kind = "Fire" }, 100)
			expect(reason).to.equal(nil)
			expect(next.barrels[1]).to.equal("Spent")
			expect(next.loaded[1]).to.equal("None") -- a value, never a hole
			expect(next.barrels[2]).to.equal("Live")
			expect(next.selected).to.equal(2)
			expect(next.busyUntil).to.equal(100.25)
		end)

		it("rejects a second shot inside the barrel delay, returning the same table", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 100)
			local next, reason = StateMachine.apply(fired, { kind = "Fire" }, 100.1)
			expect(reason).to.equal("busy")
			expect(next).to.equal(fired)
		end)

		it("rejects a spent barrel and does not shuffle the selection when both are spent", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local one = StateMachine.apply(state, { kind = "Fire" }, 100)
			local two = StateMachine.apply(one, { kind = "Fire" }, 101)
			expect(two.barrels[2]).to.equal("Spent")
			local selected = two.selected
			local next, reason = StateMachine.apply(two, { kind = "Fire" }, 102)
			expect(reason).to.equal("barrel-empty")
			expect(next.selected).to.equal(selected)
		end)

		it("runs break, load, load, close and never lets a second break in", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 0)
			local open = StateMachine.apply(fired, { kind = "Break" }, 1)
			expect(open.open).to.equal(true)
			expect(open.barrels[1]).to.equal("Empty")
			expect(open.loaded[2]).to.equal("None")

			-- This rejection IS the uninterruptible reload (feel default 2).
			local again, reason = StateMachine.apply(open, { kind = "Break" }, 2)
			expect(reason).to.equal("is-open")
			expect(again).to.equal(open)

			local one = StateMachine.apply(open, { kind = "Load" }, 2)
			local two = StateMachine.apply(one, { kind = "Load" }, 3)
			expect(two.barrels[1]).to.equal("Live")
			expect(two.barrels[2]).to.equal("Live")
			expect(two.loaded[1]).to.equal("Slug")
			-- 24, minus the two loaded here, plus the ONE unfired shell Break returned (the other
			-- barrel was spent by the Fire above): 23. Karen, 2026-09-25.
			expect(two.reserve.Slug).to.equal(23)

			local full, closeReason = StateMachine.apply(two, { kind = "Load" }, 4)
			expect(closeReason).to.equal("barrel-full")
			expect(full).to.equal(two)

			local closed = StateMachine.apply(two, { kind = "Close" }, 5)
			expect(closed.open).to.equal(false)
			expect(closed.selected).to.equal(1)

			local firing, fireReason = StateMachine.apply(open, { kind = "Fire" }, 6)
			expect(fireReason).to.equal("is-open")
			expect(firing).to.equal(open)
		end)

		it("will not load a closed gun, or one with nothing left", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local closedReason = select(2, StateMachine.apply(state, { kind = "Load" }, 0))
			expect(closedReason).to.equal("is-closed")

			local empty = table.clone(state) :: any
			empty.open = true
			empty.reserve = { Slug = 0, Buck = 0 }
			empty.barrels = { "Empty", "Empty" }
			empty.loaded = { "None", "None" }
			local next, reason = StateMachine.apply(Shotgun.deepFreeze(empty), { kind = "Load" }, 0)
			expect(reason).to.equal("no-reserve")
			expect(next.barrels[1]).to.equal("Empty")
		end)

		it("selects the kind the NEXT load uses, and rejects an unknown action", function()
			-- The primitive still does one thing. Since Karen's playtest the OWNER follows it with a
			-- full Break/Load/Load/Close, which is what makes X change the shells in the gun.
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local next = StateMachine.apply(state, { kind = "SelectAmmo", ammo = "Buck" }, 0)
			expect(next.ammo).to.equal("Buck")
			expect(next.loaded[1]).to.equal("Slug") -- this primitive alone does not rewrite them
			expect(select(2, StateMachine.apply(state, { kind = "Nope" :: any }, 0))).to.equal("bad-action")
			expect(select(2, StateMachine.apply(state, { kind = "SelectAmmo", ammo = "Grenade" :: any }, 0))).to.equal(
				"bad-action"
			)
		end)

		it("never mutates the state it was given", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local before = { state.barrels[1], state.barrels[2], state.loaded[1], state.reserve.Slug }
			local next = StateMachine.apply(state, { kind = "Fire" }, 0)
			expect(next).never.to.equal(state)
			expect(state.barrels[1]).to.equal(before[1])
			expect(state.barrels[2]).to.equal(before[2])
			expect(state.loaded[1]).to.equal(before[3])
			expect(state.reserve.Slug).to.equal(before[4])
		end)

		it("returns unfired shells to their own pocket when the action is broken", function()
			-- Karen, 2026-09-25: "the unfired shells of the old type go back to the reserve".
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local open = StateMachine.apply(state, { kind = "Break" }, 0)
			expect(open.reserve.Slug).to.equal(26) -- the two live slugs came back
			expect(open.reserve.Buck).to.equal(24)

			local fired = StateMachine.apply(state, { kind = "Fire" }, 0)
			local half = StateMachine.apply(fired, { kind = "Break" }, 1)
			expect(half.reserve.Slug).to.equal(25) -- one spent case is gone, one live shell returned
		end)

		it("swaps the gun to the other type, pocket by pocket", function()
			-- The sequence the owner runs on X: SelectAmmo, then Break/Load/Load/Close.
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local swapped = StateMachine.apply(state, { kind = "SelectAmmo", ammo = "Buck" }, 0)
			local open = StateMachine.apply(swapped, { kind = "Break" }, 1)
			local one = StateMachine.apply(open, { kind = "Load" }, 2)
			local two = StateMachine.apply(one, { kind = "Load" }, 3)
			local closed = StateMachine.apply(two, { kind = "Close" }, 4)

			expect(closed.ammo).to.equal("Buck")
			expect(closed.loaded[1]).to.equal("Buck")
			expect(closed.loaded[2]).to.equal("Buck")
			expect(closed.barrels[1]).to.equal("Live")
			expect(closed.reserve.Slug).to.equal(26) -- two slugs back in the pocket
			expect(closed.reserve.Buck).to.equal(22) -- two buckshot out of it
			expect(closed.open).to.equal(false)
		end)

		it("cannot load a type the player has none of", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local drained = table.clone(state) :: any
			drained.reserve = { Slug = 24, Buck = 0 }
			drained.ammo = "Buck"
			drained.open = true
			drained.barrels = { "Empty", "Empty" }
			drained.loaded = { "None", "None" }
			local next, reason = StateMachine.apply(Shotgun.deepFreeze(drained), { kind = "Load" }, 0)
			expect(reason).to.equal("no-reserve")
			expect(next.barrels[1]).to.equal("Empty")
		end)

		it("agrees with the 2.0 s reload Karen asked for", function()
			expect(CONFIG.RELOAD_BREAK + 2 * CONFIG.RELOAD_SHELL + CONFIG.RELOAD_CLOSE).to.equal(CONFIG.RELOAD_TOTAL)
			expect(CONFIG.RELOAD_TOTAL).to.equal(2.0)
			expect(0.5 + 2 * 0.45 + 0.6).to.equal(2.0)
		end)

		it("applies 10000 times in under 100 ms", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local started = os.clock()
			for index = 1, 10000 do
				StateMachine.apply(state, { kind = "Fire" }, index)
			end
			expect(os.clock() - started < 0.1).to.equal(true)
		end)
	end)

	describe("weapon snapshot", function()
		it("turns the deadline into a duration, drops the server-only fields, and freezes", function()
			local state = StateMachine.setEquipped(StateMachine.initial(CONFIG), true)
			local fired = StateMachine.apply(state, { kind = "Fire" }, 10)
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
end

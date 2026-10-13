# Archived in task 178: `Store.save`'s derivation, and `Store.memory`'s number-only seed

Rule 7: nothing is deleted. Both shapes below were correct for task 170 and are replaced in task
178, with the reason and the rollback.

Replaced at commit `f994887`'s parent line of work, in `src/server/Economy/Store.luau`.
Design: `docs/design/shop.md` section 8.2b, hazard 2.

## 1. `save(userId, balance)` derived two fields itself

```luau
-- the memory store
save = function(userId: number, balance: number): boolean
    counts.save += 1
    if not open[userId] then
        return false
    end
    local key = Store.keyFor(userId)
    local data = Store.read(saved[key])
    data.coinsEarnedTotal += math.max(0, balance - data.coins)
    data.coins = balance
    data.drivesPaid += 1
    saved[key] = data
    return true
end,

-- the live store
save = function(userId: number, balance: number): boolean
    counts.save += 1
    local profile = profiles[userId]
    if not profile then
        return false
    end
    local data = profile.Data
    data.coinsEarnedTotal += math.max(0, balance - (data.coins or 0))
    data.coins = balance
    data.drivesPaid = (data.drivesPaid or 0) + 1
    return true
end,
```

**Why it goes.** `data.drivesPaid += 1` on EVERY call was correct while `Economy.payDrive` was the
only caller. Task 178 gives the store a second caller -- `Economy.purchase` -- and `drivesPaid` is
the number the shop's hunt gates read, so buying a hat would have counted as a completed hunt. The
interface is now `save(userId, fields)`: it writes exactly the named fields and derives nothing, and
both increments live in `Economy.payDrive`, where the delta and the event are both known.

**Rollback.** Restore the two bodies above, change the type back to
`save: (userId: number, balance: number) -> boolean`, and move the `coinsEarnedTotal` and
`drivesPaid` lines out of `Economy.payDrive` -- at which point a purchase must stop calling `save`,
or it counts as a hunt again.

## 2. `Store.memory{ seed = { [userId] = balance } }`

```luau
function Store.memory(options: { seed: { [number]: number }?, refuse: { [number]: boolean }? }?): Store
    ...
    for userId, balance in pairs(opts.seed or {}) do
        saved[Store.keyFor(userId)] = { coins = balance }
    end
```

**Why it widens.** A shop spec needs a player with a balance, a hunt count AND an ownership set in
one line. The seed is now `userId -> a whole profile`, read through `Store.read`.

**Nothing is lost:** a NUMBER is still accepted and read as `{ coins = n }`, so every call written
before task 178 (`Store.memory({ seed = { [11] = 400 } })`) behaves exactly as it did.

**Rollback.** Delete the `type(seeded) == "number"` branch and the widened annotation.

# Task 34 — deltas from `docs/design/drive.md` §8.5 and the shotgun design

The Architect owns `docs/design/`, so nothing there was amended. This is what Task 34 added to the
weapon owner's public surface and its behaviour, and why, for the next design regeneration.

## 1. `Weapon.armingAction(allowed: boolean, holding: boolean): string?` — NEW, public

The whole arming decision as a pure function: `"grant"`, `"revoke"`, or nil. `Weapon.refreshArming`
is now a thin wrapper around it. It is public so the decision can be asserted without taking a live
player's gun away — a spec that did exactly that broke three client specs that were right
(`weapon_rearm.spec` explains it). The design's §8.5 lists `refreshArming` and not this.

## 2. `Hardware.give(tool, player)` returns `boolean` — CHANGED

It used to return nothing and silently leave the Tool parented to nil when the Backpack was not
there. That is how a two-player drive left its Shooter with no gun at all. It now says whether the
tool landed, and `Weapon.grant` records nothing when it did not (`stats.grantsMissed`).

**It never yields.** A version that waited for the Backpack made the grant interleavable (two Tools
for one player, only one of them recorded) and parked the drive's Heartbeat step, which applies
`refreshArming` synchronously. The "Backpack is not there yet" case is covered by the hook in delta 4
instead. Reviewer, Task 34 round 1, findings 1 and 2.

## 3. `Hardware.TOOL_NAME` and `Hardware.toolsOf(player)` — NEW

One gun per player is now enforced rather than assumed: `grant` destroys any stray Shotgun the
player is carrying before building a new one. A stray one survives a revoke, because `revoke`
destroys the *recorded* Tool — which is a player keeping a gun the drive says they may not carry.

## 4. An arming SWEEP every 2 s, inside `Weapon.start` — NEW behaviour

Every grant in this system was edge-triggered: the drive's phase transitions and the player's
`CharacterAdded`. A two-player drive found the hole between those edges twice — `mayCarryWeapon`
said the shooter was armed and no Tool existed anywhere in the place, for a whole ten-minute drive.
The sweep asks the same question the same way, grants nothing a `refreshArming` would not, and
costs one table scan; `stats.armingSweeps` and `stats.armingRepairs` count it. `watchPlayer` also
re-checks when a **new Backpack** appears on the player, which is what a placement's respawn creates.

The design describes arming as edge-driven (§8.5). This makes it eventually consistent instead.

## 5. `holdsTool` — the record is no longer trusted on its own

A Tool goes with whatever it is parented to, so a respawn destroys it. `refreshArming` now asks
whether the player *holds* a Tool (`Parent ~= nil`), and `watchTool` clears the record when the
granted Tool is destroyed. One watcher per player, replaced at each grant.

## 6. `Weapon.grant` returns `Tool?` — CHANGED

nil when nothing landed, rather than a destroyed Tool. Both callers ignore the return.

## Test-system deltas (the docstring is the source of truth and carries them in full)

- `TestKit.awaitToken` applies the same gate but waits up to `TOKEN_WAIT` (60 s) instead of reading
  once at startup, because a two-player run can only deliver the token after its processes exist.
- `TestKit.note` and the first five failure messages ride in the report, because a long session's
  Studio console comes back truncated and took the evidence with it.

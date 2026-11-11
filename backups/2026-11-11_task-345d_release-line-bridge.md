# Archived: the T2 bridge -- `Placement.bridgeMustRelease` and `releaseLine`'s spawn half on the ON path

Task 345d (T4 of `docs/design/animal-placement.md`), 2026-11-11. Rule 7: never delete.

## What it was

T2 (task 345b) left `ForestTest.releaseLine` able to SPAWN a scheduled slot's group on the flag-ON
path, for one case only: a row the WOOD had refused a bed to (`skipped == "nobed"`). That kept the
drive working end to end at every commit while the roster was only half-wired. The rule was one pure
function, `src/shared/ForestTest/Placement.luau`:

```luau
-- THE BRIDGE'S WHOLE RULE (design 17's T2 row), named here so it is one answer and a spec can drive
-- it: **the only hole `ForestTest.releaseLine` still fills is one the WOOD refused.**
--
-- A GROUP THE **BUDGET** REFUSED MUST NOT BE RELEASED, and that is measured rather than argued.
-- `345b-ON3-C1-track.txt`, one live drive at C1: the bridge released every group the live cap had
-- just refused a bed to, which put **31 bodies against a `LIVE_CAP` of 24** -- and those bodies then
-- refused the NEXT group's bed, so the two doors fed each other: 7 of 13 groups skipped and **6 ring
-- searches spent in a whole drive**. A budget refusal is the world saying "there is no room for a
-- body right now"; a second door past it is not a bridge, it is the bug the cap exists to stop.
--
-- A record still waiting for room is therefore the ROSTER's, and it comes out at its own bed when
-- the room appears. T4 retires this function with the spawn half it guards.
function Placement.bridgeMustRelease(row: any): boolean
	return type(row) == "table" and row.skipped == "nobed"
end
```

and one condition in `ForestTest.releaseLine`:

```luau
	local inRoster = if staged == nil and onNow then ForestTest.rosterSlot(slot) else nil
	if inRoster ~= nil and not Placement.bridgeMustRelease(inRoster) then
```

## Why it is archived

Design section 4.6: on the flag-ON path `releaseLine` keeps its ROUTE half and loses its SPAWN half.
A group the wood refused is **a hole in the wood, and it is REPORTED, not hidden** (design 4.3) --
`placementStats().skipped.nobed` and one console line per skip. Spawning it 25-85 studs north of the
road is exactly the magic appearance Karen's *"animals has to be in palces not just apear
magically"* is about, so the last door that could do it is shut. The condition becomes
`if inRoster ~= nil then`, and `bridgeMustRelease` has no caller.

The spawn half itself is NOT archived: it still runs for the Director's staged instrument
(`Data.stagedRow`, Studio-only) and for the whole flag-OFF path, which is byte-for-byte today's
drive.

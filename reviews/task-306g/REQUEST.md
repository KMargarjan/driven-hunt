# Task 306 step B7: one animal per OCCUPIED station

Task: 306g
Round: 1
Base: task-306b6-isolation-picture @ b703f92d
Code commit: (filled in below, after the harness)

Design: `docs/design/shooting-range-lobby.md` §7.4, §16 row B7. DEV only; Karen's place is B8.

## PLAN

**CORE-NA** (Director, 2026-10-28): this step changes WHO HAS AN ANIMAL AND WHEN. No shot rule, no
motion rule, no kill zone, no ballistics. Steps 1-3 of the core protocol are therefore scoped to the
occupancy sentence, and the live proof is the DEV click proof the dispatch names.

(a) **REAL LIFE.** A running-boar range runs a target for the bay that is being shot. BSRC's own
page describes a firing hut of bays with **a light per bay** -- the installation is driven per
occupied bay, not all six at once (`docs/research/2026-10-28-the-range-in-the-lobby.md` §2).

(b) **MEASURED NOW.** `tests/server/range.spec.luau` "clears a killed target after CARCASS_SECONDS"
asserts, at b703f92d, `fake.spawns == LAYOUT.SPOT_COUNT` (**6**) after 2 s with **nobody anywhere**,
then `2 * LAYOUT.SPOT_COUNT` (**12**) spawns and `lostTargets == 5` after ONE carcass -- the two
defects B2 wrote in as numbers. Live DEV reading is the click proof below.

(c) **TARGET.** Empty range: **0** spawns. One man at station 2: **exactly 1** target, at station 2.
He leaves: **1** idle clear after `IDLE_CLEAR_SECONDS` = **30 s** (design §7.4) and not before.
One carcass at station 1: **1** clear, **0** lost targets, **7** spawns total (6 + 1), the other five
animals untouched. 30 s because it is the design's number, and it is long enough that a man who
steps off the mat to reload does not lose his animal.

(d) **LEVER.** `src/server/Range/init.luau`'s `scan` -- the unconditional `release(trial)` at the
`trial.targetId == nil` arm -- and the two range-WIDE clears:
```
$ grep -n "boars.clear(" src/server/Range/init.luau
604:			state.boars.clear("range stop")
777:				boars.clear("range carcass")
1489:				boars.clear("range pick")
$ grep -n "function Runtime:clear" src/server/Boar/init.luau
5673:function Runtime:clear(reason: string?)
```
There is **no per-id despawn**, so the lever for must-fix 1 does not exist yet and is built:
`Runtime:clearOne(id, reason)`, through the same `_despawn` path `clear` and the out-of-bounds step
already use (`src/server/Boar/init.luau:7848`). The occupancy lever is a new `players` seam on
`Range.start`, measured through the owner's own `playerSpot` + `Range.spotAt`.

(e) **HOW IT IS MEASURED AFTER.** The same two instruments: `range.spec` group 12 (`fake.spawns`,
`stats.idleClears`, `stats.lostTargets`, `fake.at(n)`), and live `Range.stats()` in DEV Play.

**THE FUNCTIONAL INSTRUMENT IS NAMED (L-152).** The dispatch cites T10/T11, but design §12 defines
T10 as step cost (<= 2 ms/step) and T11 as draw cost (<= 3 ms) **plus** "an empty range costs 0
spawns". Only that last clause is occupancy. The instrument for the *sentence* -- arrival releases,
idle clears, station 4 unaffected -- is **§11.2 group 12** plus `Range.stats().occupied/spawns/
idleClears/targets` read live. T10 and T11 are reported as the cost targets they are.

## WHAT CHANGED

Code commit: `73c79b48864776d88a65cb61149dc7904514d813`

```
[harness] PASS: 34/34 checks @ 73c79b48864776d88a65cb61149dc7904514d813 (clean tree) scope=all
```

`test2`: **N/A**. No changed path is in `TWO_PLAYER_PATHS` (`tools/agents.py`) -- `src/server/Range/`,
`src/server/RangeBoot.server.luau`, `src/server/Boar/init.luau`, `tests/server/range.spec.luau`.
The range is "the weapon, the boar and the hud" (design 11.6, CLAUDE.md's explicit list).

Four files: `src/server/Range/init.luau`, `src/server/Boar/init.luau`,
`src/server/RangeBoot.server.luau`, `tests/server/range.spec.luau`.

## CLAIMS

1. **A station releases a target only when a player is MEASURED at it.** `scan` takes `occupancy()`
   once per tick; the `targetId == nil` arm releases only when `occupied`. Verify: `range.spec`
   "one animal per occupied station" -> "releases NOTHING with nobody at the range" (120 s, 0 spawns)
   and "gives a man who arrives at station 2 exactly ONE animal, at station 2".
   **LIVE DEV** (RANGE on, one Play session, `Workspace.RangeTargets` children -- an INSTANCE fact,
   not module state, because a probe's `require` gets a fresh module):
   player 1760 studs away -> **0 targets**; 0.25 s after standing on station 2's mat (1224, 0.5, 0)
   -> **1 target** (`Boar1`), in station 2's own lane (z 125).

2. **It clears `IDLE_CLEAR_SECONDS` (30) after the last man left, and not before.** Verify:
   `range.spec` "clears HIS animal IDLE_CLEAR_SECONDS after he leaves, not before, and leaves
   station 4 alone". **LIVE DEV, same session**: he walks to mat 4 -> **2 targets** (`Boar1` station
   2's, `Boar2` station 4's new one); at **27 s** idle -> still **2**; at **34 s** -> **1**, and it is
   **`Boar2`** -- station 2's went, station 4's is the same animal and still moving (x1303).

3. **MUST-FIX 1: the clear is per station, carcass AND pick.** New `Boar.Runtime:clearOne(id, reason)`
   despawns one animal through the same `_despawn` path `Runtime:clear` uses; `Range`'s `clearTarget`
   prefers it. Verify: the rewritten carcass case asserts `spawns == SPOT_COUNT + 1` (was
   `2 * SPOT_COUNT`), `lostTargets == 0` (was `SPOT_COUNT - 1`), `clearOnes == 1`, and the other five
   stations hold **the same animal ids** as before the carcass. `grep -n "boars.clear(" src/server/Range/init.luau`
   now shows only `Range.stop`'s range-wide one.

4. **MUST-FIX 1, the pick path too** (306b round-2 note (viii)): `Range.onRequest`'s respawn calls
   `clearTarget(trial, "range pick")`. Verify: "clears only HIS animal when he picks a new species"
   -- station 6's animal id is unchanged after station 1 picks `reddeer`.

5. **MUST-FIX 2: the owner no longer runs six trials with nobody there.** `state.players` is a seam;
   `nil` means no measurement and then **nothing** is released. Verify: "releases nothing at all when
   the root wired no player list" (0 spawns in 60 s), and `RangeBoot` wires
   `players = function() return Players:GetPlayers() end`.

6. **Both arms of `clearTarget` are reachable by parameter, and the bad one is COUNTED.** A root that
   wires only range-wide `clear` raises `stats.wideClears`. Verify: "counts a range-WIDE clear when
   the root wired no clearOne" -- `fake.clearOne = nil`, then `wideClears == 1` and station 1's
   animal goes with station 2's. Every other case asserts `wideClears == 0`.

7. **`SOUND` off.** `RangeBoot` sets `world.config.SOUND` to a FULL clone of `Boar.CONFIG.SOUND` with
   `ENABLED = false` (`newRuntime` merges only MODEL, SENSE and KINDS key by key).
   `Body.attachSounds` returns early on `not sound.ENABLED`. Verify: **LIVE DEV**, `0` `Sound`
   instances anywhere under `Workspace.RangeTargets` with a target on the lane.

8. **Occupancy is measured off the character, never claimed.** `occupancy()` -> `playerSpot` ->
   `Range.spotAt`; no payload field is read and this module still reaches no DataModel (`Players` is
   required by the ROOT, not here). Verify by reading `occupancy` and `playerSpot`.

9. **T9, measured live:** `[range] built in 2 ms (106 parts, 6 stands, 0 refused)` -- bounds 300 ms
   and `MAX_PARTS` 160.

10. **T10, measured:** **0.0209 ms per step with six targets** over 200 forced scans, bound **2 ms**.
    `<runs-dir>/306b7-t10.luau`, run on the live DEV server: the real `Range` code on a fresh
    instance started into an UNPARENTED folder (nothing enters Workspace), six fake men on the six
    mats, a fake runtime. Six men -> six targets, `wideClears=0`.

## FRAMES, LOOKED AT

- `.screenshots/306b7-mat4-one-animal.png` -- first person on station 4's mat, shotgun in hand.
  **Exactly one animal** on the whole firing line: the dark boar silhouette at the centre of his own
  lane, inside his window (x1273 against 1254..1290), held at `stand`. The berm band runs unbroken
  left and right with nothing else on it. Station 2's was cleared 34 s after he left.
- `.screenshots/306b7-empty-lane2.png` -- first person, 28 studs BEHIND the line (outside the
  station box, whose reach is 19.1) and 12 studs west of mat 2, looking down lane 2. Two mats with
  their posts and benches in the foreground, two treestand trusses framing it, the berm across the
  middle -- **no animal anywhere**. The probe read **0 targets** at that instant.
- `.screenshots/306b7-empty-range.png` -- the same empty state from behind mat 4; station 4's
  treestand occludes the lane centre, which is why the frame above was taken as well. Reported for
  completeness, not relied on.

## WHAT I COULD NOT VERIFY

- **T11's draw clause.** "Six DRAWN animals cost <= 3 ms of one server frame" is **not measurable in
  DEV**: the DEV row has no `drawn = true`, so its targets are the grey boxes. Its other clause --
  "an empty range costs 0 spawns" -- is MET and measured live (claim 1). The draw cost belongs to
  B8/B9 in Karen's place.
- **T10's own instrument.** Design 12 names `Range.stats()` for T10, and `Range.stats()` carries no
  step-time field. The number above was taken with `os.clock()` round 200 forced `Range.step` calls.
  **For the Director:** either design 12's T10 row names that, or the owner publishes a step-time
  stat. Not fixed here -- it is a design line, not this step's code.
- **A live "before" at the parent commit.** Re-syncing b703f92d needs Karen's Rojo **Connect**
  click, so the before/after pair for the empty range is: the committed assertions at b703f92d
  (6 spawns with nobody there; 12 spawns and 5 lost targets after one carcass), against the live
  readings above and the rewritten assertions -- the same counters, read two ways.
- Two real players at two stations at once: the design routes that to the Director's ops step (T3,
  11.4), and `src/client/Range/` is not in `TWO_PLAYER_PATHS`.

# Task 306 step B7: one animal per OCCUPIED station

Task: 306g
Round: 2
Base: task-306b6-isolation-picture @ b703f92d
Code commit: 123e2256a7dfa0bd46a19d3e06a6d87b4f686728

```
[harness] PASS: 34/34 checks @ 123e2256a7dfa0bd46a19d3e06a6d87b4f686728 (clean tree) scope=all
```

`test2`: **N/A**. No changed path is in `TWO_PLAYER_PATHS` (`tools/agents.py`) -- `src/server/Range/`,
`src/server/RangeBoot.server.luau`, `src/server/Boar/init.luau`, `tests/server/range.spec.luau`.
The range is "the weapon, the boar and the hud" (design 11.6, CLAUDE.md's explicit list).

Design: `docs/design/shooting-range-lobby.md` 7.4, 16 row B7. DEV only; Karen's place is B8.

## PLAN

**CORE-NA** (Director, 2026-10-28): this step changes WHO HAS AN ANIMAL AND WHEN. No shot rule, no
motion rule, no kill zone, no ballistics.

(a) **REAL LIFE.** A running-boar range runs a target for the bay being shot: BSRC's firing hut is
bays with **a light per bay** (`docs/research/2026-10-28-the-range-in-the-lobby.md` section 2).

(b) **MEASURED NOW.** At b703f92d `range.spec` asserted `fake.spawns == SPOT_COUNT` (**6**) after 2 s
with **nobody anywhere**, then **12** spawns and `lostTargets == 5` after ONE carcass -- the two
defects B2 wrote in as numbers.

(c) **TARGET.** Empty range **0** spawns. One man at station 2: **1** target, at station 2. He leaves:
**1** idle clear after `IDLE_CLEAR_SECONDS` = **30 s** and not before. One carcass: **1** clear,
**0** lost targets, **7** spawns, the other five animals untouched.

(d) **LEVER.** `scan`'s unconditional `release(trial)`, and the two range-WIDE clears
(`src/server/Range/init.luau` 777 `boars.clear("range carcass")`, 1489 `boars.clear("range pick")` at
b703f92d). No per-id despawn existed (`grep -n "function Runtime:clear" src/server/Boar/init.luau`
gave one line, 5673), so that lever is BUILT: `Runtime:clearOne`, through the same `_despawn` path.

(e) **MEASURED AFTER** with the same instruments: `range.spec` group 12 and live DEV.

**THE FUNCTIONAL INSTRUMENT, NAMED (L-152).** The dispatch cites T10/T11; design 12 defines T10 as
step cost (<= 2 ms/step) and T11 as draw cost (<= 3 ms) **plus** "an empty range costs 0 spawns".
Only that last clause is occupancy. The instrument for the sentence -- arrival releases, idle clears,
station 4 unaffected -- is **11.2 group 12** plus the live `Workspace.RangeTargets` child count.
T10 and T11 are reported below as the cost targets they are.

## CLAIMS

1. **A station releases a target only when a player is MEASURED at it.** `scan` takes `occupancy()`
   once per tick; the `targetId == nil` arm releases only when `occupied`. Verify: `range.spec`
   "one animal per occupied station" -> "releases NOTHING with nobody at the range" (120 s, 0 spawns)
   and "gives a man who arrives at station 2 exactly ONE animal, at station 2".
   **LIVE DEV** (RANGE on, one Play session; the instrument is `Workspace.RangeTargets` children --
   an INSTANCE fact, because a probe's `require` gets a FRESH `Range` whose `started` read `false`):
   player 1760 studs away gave **0 targets**; 0.25 s after standing on station 2's mat (1224, 0.5, 0)
   it gave **1 target**, `Boar1` at x1186 -- station 2's own west lane end (1224 - 38), 24 studs from
   station 1's (1162).

2. **It clears `IDLE_CLEAR_SECONDS` (30) after the last man left, and not before.** Verify:
   `range.spec` "clears HIS animal IDLE_CLEAR_SECONDS after he leaves, not before, and leaves
   station 4 alone". **LIVE DEV, same session**: he walks to mat 4 -> **2 targets** (`Boar1`
   station 2's, `Boar2` station 4's new one); at **27 s** idle -> still **2**; at **34 s** -> **1**,
   and it is **`Boar2`** -- station 2's went, station 4's is the same animal and still moving.

3. **MUST-FIX 1: the clear is per station, carcass AND pick.** New `Boar.Runtime:clearOne(id, reason)`
   despawns one animal through the same `_despawn` path `Runtime:clear` uses; `Range`'s `clearTarget`
   prefers it and branches on the seam's own boolean. Verify: the rewritten carcass case asserts
   `spawns == SPOT_COUNT + 1` (was `2 * SPOT_COUNT`), `lostTargets == 0` (was `SPOT_COUNT - 1`),
   `clearOnes == 1`, `wideClears == 0`, and the other five stations hold **the same animal ids**.
   `grep -n "boars.clear(" src/server/Range/init.luau` now shows **two** lines: `Range.stop`'s
   range-wide one, and `clearTarget`'s counted fallback arm, which is claim 6's subject.

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
   `Body.attachSounds` returns early on `not sound.ENABLED`, and it is reached from `attachVisual`,
   which runs because the DEV target IS dressed -- `Boar.CONFIG.MODEL.ENABLED` is
   `Flags.isOn("BOAR_MODEL")`, lit since 2026-10-21, and `newRuntime` merges `MODEL` key by key even
   though the DEV row has no `drawn = true` (round-1 note; the frame shows the silhouette). So the
   reading is real proof: **LIVE DEV, 0 `Sound` instances anywhere under `Workspace.RangeTargets`**
   with a target on the lane.

8. **Occupancy is measured off the character, never claimed.** `occupancy()` -> `playerSpot` ->
   `Range.spotAt`; no payload field is read and this module still reaches no DataModel.

9. **T9, measured live:** `[range] built in 2 ms (106 parts, 6 stands, 0 refused)` -- bounds 300 ms
   and `MAX_PARTS` 160. Whole-session console: **0 errors, 0 warnings**.

10. **T10, measured:** **0.0209 ms per step with six targets** over 200 forced scans, bound **2 ms**
    (`<runs-dir>/306b7-t10.luau`, on the live DEV server: the real `Range` code on a fresh instance
    started into an UNPARENTED folder, six fake men on the six mats). Six men gave six targets and
    `wideClears=0`. **Design 12 names `Range.stats()` as T10's instrument and `Range.stats()`
    carries no step-time field** -- the number above is `os.clock()` round 200 `Range.step` calls.
    For the Director: either that row names this, or the owner publishes a step-time stat.

## FAIL FIRST (L-093)

Round 1 finding 1: the "his own lane" assertions compared Z (identical for all six stations --
`laneCentre`'s Z is `anchor.Z + DISTANCE_STUDS` -- so `0 < 1` whatever the code does) and an X
tolerance of a whole `laneLength`, which station 1's west end also satisfies. They now compare the
release point with station 2's **own** lane end, assert that end differs from station 1's by
`SPOT_SPACING_STUDS`, and read the position on the step that RELEASED it.

**Shown red, run, not argued:** commit `aa8e0d20` (in this branch's history, reverted by the next
commit) changed `release` to use station 1's lane for every station --
`[harness] FAIL: 32/34 checks @ aa8e0d200f5d532849e94427be5316168ab1df0f (clean tree) scope=all`,
`failed [server] range.spec:1704 Expected value "true" (boolean), got "false" (boolean)`. That is the
new `|released.X - end2.X| < 0.001` line. The four other reds in that run are the later group-12
cases: the aborted case never reached its `Range.stop()`, so their `startRange` returned false.

## WHAT I COULD NOT VERIFY

- **Karen's place.** Nothing here has been seen in her Forest Test: claims 1, 2 and 7 were seen live
  in **DEV only**, and claims 3 and 4 (carcass, pick) in **no live run at all** -- their evidence is
  `range.spec`. Her place is B8 and the proof is B9. **NOT PROVEN in Karen's place: 1, 2, 3, 4, 7.**
- **T11's draw clause** ("six DRAWN animals <= 3 ms of one server frame"): design 12 names the
  Studio microprofiler and a Director ops step, which is B8/B9 in her place. Its other clause --
  "an empty range costs 0 spawns" -- is MET and measured live (claim 1).
- **A live "before" at the parent commit.** Re-syncing b703f92d needs Karen's Rojo **Connect** click,
  so the before/after pair for the empty range is the committed assertions at b703f92d (6 spawns with
  nobody there; 12 spawns and 5 lost targets after one carcass) against the live readings and the
  rewritten assertions -- the same counters, read two ways.
- **Two real players at two stations at once:** the design routes that to the Director's ops step
  (T3, 11.4), and `src/client/Range/` is not in `TWO_PLAYER_PATHS`.
- **Design 7.4 and 9.2 are now stale** and were not in this step's scope: 7.4 says the clear goes
  "through the shipped `boars.spawn` / `boars.clear` verbs" and 9.2 says the narrow `boars` view
  "gains exactly two readers". Must-fix 1 required a third (`clearOne`) and `Range.start` gains a
  `players` seam. Queued for the Director (round-1 note).

## FRAMES, LOOKED AT

- `.screenshots/306b7-mat4-one-animal.png` -- first person on station 4's mat, shotgun in hand.
  **Exactly one animal** on the whole firing line: the dark boar silhouette at the centre of his own
  lane, inside his window (x1273 against 1254..1290), held at `stand`. The berm band runs unbroken
  left and right with nothing else on it. Station 2's was cleared 34 s after he left.
- `.screenshots/306b7-empty-lane2.png` -- first person, 28 studs BEHIND the line (outside the station
  box, whose reach is 19.1) and 12 studs west of mat 2, looking down lane 2. Two mats with their
  posts and benches in the foreground, two treestand trusses framing it, the berm across the middle
  -- **no animal anywhere**. The probe read **0 targets** at that instant.
- `.screenshots/306b7-empty-range.png` -- the same empty state from behind mat 4; station 4's
  treestand occludes the lane centre, which is why the frame above was taken too. Not relied on.

# Task 168: the beater's drive and the gathering

Task: 168
Round: 1
Base: `37d8ba0` (main, #151 merged)
Code commit: `28ed6a64a19328383f1700b7a745937dd88dcf4f`

Harness, the clean tree, TWICE at the code commit:

```
[harness] PASS: 33/33 checks @ 2f68eb9f69e04ff74de943c95a5d6720f9f8605e (clean tree) scope=all
[harness] PASS: 33/33 checks @ 2f68eb9f69e04ff74de943c95a5d6720f9f8605e (clean tree) scope=all
```

```
[harness] PASS: 33/33 checks @ 28ed6a64a19328383f1700b7a745937dd88dcf4f (clean tree) scope=all
[harness2] PASS: 35/35 checks @ 28ed6a64a19328383f1700b7a745937dd88dcf4f (clean tree)
```

`TWO_PLAYER_PATHS` is touched (`src/server/Match/`, `src/client/Match/`, `src/shared/Drive/`,
`tests/server/match_*.spec.luau`), and the Director runs `test2` and this review -- his own
instruction in the dispatch. The placeholder above is the only line in this file that is not a
measurement.

Smoke, the Forest Test, 90 s, after everything below was in:

```
gun in hand @15s=1 @90s=1 | stacks=0 errorLines=0 | waves=5 | worst playing sounds over 10 s: 2 (boars=6)
SMOKE PASS
```

**AND THE SMOKE EARNED ITS KEEP THIS ROUND:** the first version of the sweep called
`ForestTest.lineFrontAt` where it had to call `Data.lineFrontAt` -- the server module and the shared
data module are both named `ForestTest` -- so `spookNearBeaters` errored every tick, the wood never
re-stocked, and the live count came back a beautiful **0 behind the line** because almost nothing was
alive to be behind it. `SMOKE FAIL ... Stack Begin ... attempt to call a nil value` is what found it.
Neither `selene` nor a spec could: it is a table index, and no spec drives `spookNearBeaters` against
a live runtime. The numbers below are from after the fix.

Karen, 2026-10-12 ~21:45 and ~21:50, is quoted in full in `PLAYTEST.md` and in the task row. Five of
her six items are here; the horn MODEL is a separate asset task and is not.

---

## What changed

**The drive's start.** `Match.CONFIG.GO_HOLD_SECONDS` = `Horn.signalSeconds("start")` (2.18 s) and
`Phase` holds the line for it after GO with two new state fields (`goFreeAt`, `goFreed`), the shape
`nextReleaseAt` already has. `Phase.lineHeld` is the window a beater may be held in -- the countdown
OR the fanfare -- and `Body.holdWhenLoaded` makes the re-apply after a placement respawn survive the
task-157 parent race. The snapshot carries `holdUntil` and `through`; `Hud.Objective` gains four
beater sentences and a `drive` argument.

**The horn.** `Weapon.Horn.setBlowPolicy` (injected at both composition roots to
`Match.mayBlowHorn`) is asked inside `Horn.blowTool`; `Match.beaterCrossing` records who is through
in the walk it already takes. `Weapon.Horn.raise` plays the bugler's pose on a player's character;
the pose, the sequence and the registered id moved from `Bots.Rig` to `src/shared/Horn` and `Rig`
keeps three aliases.

**The gathering.** `Match.Scene` lays the animals in rows, grows the ring and the corner square to
contain them, and builds four torches (post + `Flame` + `Fire` + `PointLight`).

**The line as a wall.** `Boar.CONFIG.BEATER_WALL` plus `Brain.exitSign`, `Brain.beaterWallZ` and
`Brain.forwardOfWall`, applied once at the end of `Brain:step`.

---

## Claims, and how to verify each

**1. GO is the end of the fanfare, and the hold is one deadline in the state, not a timer.**
`Phase.enterRunning` emits the `signal` and NO `free`; the time section emits the `free` when
`now >= goFreeAt`, once, latched by `goFreed`. There is still no `task.delay` and no second clock in
`Match.Phase`. See `match_phase.spec` → *"holds the line through the start fanfare and lets it go at
the end of the phrase"*, which asserts `countKind(effects, "free") == 0` at GO and `== 1` after
2 seconds of simulated time. `GO_HOLD_SECONDS` is not a number typed here: the same spec asserts it
equals `Horn.signalSeconds("start")` to 1e-9, and `Phase.goHoldSeconds({})` is 0 -- this file before
task 168, reachable by parameter.

**2. A PLAYER beater is really held now, and the two reasons she was not are both in the code with
their measurements.** `Phase.lineHeld` (the window, not the phase) and `Body.holdWhenLoaded` (the
bounded parent wait). Verify by reading the two headers -- each carries the live numbers -- and
`match_phase.spec` → *"holds a player who is MADE a beater at GO, which is how the Forest Test does
it"* and *"holds a PLAYER beater, not just a bot"*. The live measurement, Forest Test, a player
beater at her start line, before and after:

```
before:  t=7.62 team=Drivers ws=16 anch=false   (and ws=16 for the next 40 s)
after:   t=7.62 team=Drivers ws=16 anch=false
         t=7.90 team=Drivers ws=0  anch=true    (the hold lands on the respawned character)
         t=9.79 team=Drivers ws=16 anch=false   (freed, 2.18 s after GO)
```

**3. A beater through the hunters' line cannot sound his horn, player or bot, and keeps the Tool.**
One predicate (`Match.crossedLine`, task 159's, unchanged) recorded once a tick by
`Match.beaterCrossing`, one injected policy, one refusal inside `Horn.blowTool` -- which is the only
implementation of a blast, so a player's `Tool.Activated` and `Bots.blowFor` are refused by the same
line. `zz_horn.spec` → *"refuses a blast from a beater who is through the line, and keeps the horn in
his hand"*: no `Blown` fires, `refusedThrough` counts it, the Tool is still in the Backpack, a
refusal takes no cooldown, a bot key is refused the same way, and with no policy wired everybody may
blow (this file before task 168). Harness note: `zz_horn: refusedThrough=2 (task 168), blasts=3`.

**4. A player's arm raises the horn to her face and lowers it, by the same mechanism a bot uses.**
One definition (`Horn.BLOW_POSE`, `Horn.blowSequence`, `Horn.blowAnimationId` in `src/shared/Horn`),
two players of it, one writer of each `Animator`: `Bots.Rig` for a rig, `Weapon.Horn` for a player.
`zz_horn.spec` asserts `Rig.BLOW == Horn.BLOW_POSE` and `Rig.blowSequence == Horn.blowSequence` --
one table, two files -- plus the raise state machine (tries on an accepted blast, nothing at all on a
refused one, a miss and not an error with no Humanoid). Measured live through the real
`Tool.Activated` door, Forest Test:

```
BEFORE: handle-to-head 3.42 studs, no Action track
DURING: handle-to-head 1.77 studs, one track w=1.00 priority=Action, Grip=GRIP_BLOW
AFTER:  handle-to-head 3.42 studs, no Action track,                Grip=GRIP
```

**5. It is one mechanism for third person AND first person, and there is no second writer.** An
animation played on the character's `Animator` on the server replicates to every client, and
`Camera.Rig` hides the local body in first person but deliberately not a non-weapon Tool (its own
comment: *"the beater's horn has no viewmodel"*). So nothing in `src/client` was touched for this,
and the dispatch's "viewmodel owner" is not needed. What I could NOT do is photograph it in her own
view -- see *What could not be verified*.

**6. The gathering lays several rows, and the ring and the torches contain them.** `Scene.rowLayout`
fills `PER_ROW` to a row and steps back `ROW_SPACING_STUDS`; `Scene.layoutExtent` is the one
measurement of the block and both `Scene.ringRadiusFor` and `Scene.cornerReachFor` read it.
`match_scene.spec` → *"lays 1, 5 and 12 animals out in 1, 1 and 2 rows"*, *"splits a bag of twelve
into two rows, the second one behind the first"* (every animal's row and depth, the nearest pair, and
the short last row centred on its own width) and *"stands the people AROUND the animals, however big
the bag is"* (every animal inside the ring, every person on it, every torch outside it). **A SMALL
BAG DOES NOT MOVE:** the same spec asserts `ringRadiusFor(3) == RING_RADIUS_STUDS` and
`cornerReachFor(3) == CORNER_STUDS`, so the scene Karen has already seen is unchanged. Harness note:
`match_scene: 12 animals -> 2 rows, half 15.0 x 4.0, ring 21.5 (was 14.0), corners 23.5`.

**7. A torch is a real fire, and nothing writes a light per frame.** Post + `Flame` part + `Fire` +
`PointLight`, and the flicker is `Fire`'s own animation -- there is no per-frame writer anywhere in
the task. `match_scene.spec` → *"burns a real fire on each of the four corners, at the top of the
post"*: four flames, each with a `Fire` at the config's size and heat and a `PointLight` with shadows
off, each at the post's top face, each `CanQuery = false`. `LIGHT_BRIGHTNESS` 4 → 2.5 because the
lamp moved up onto the flame and the first photograph came back washed out (rule 5; the comment says
so).

**8. A boar's chosen direction never points behind the beaters' line.** `Brain.forwardOfWall` is
applied ONCE, to `self._desired`, at the end of `Brain:step` -- after the route, the whiskers, both
sidesteps and the slew -- so it cannot be outvoted, and `_desired` is also what the animal FACES.
`boar_brain.spec` → *"leaves a heading alone until the animal is at the wall, and then takes the back
out of it"* drives all four cases plus the off state and the degenerate inputs, and *"never faces a
live boar behind the line"* runs 3,600 ticks against a line walking at 5 studs/s with a flank spook
every ten seconds. Harness note: `task 168: 3600 ticks against a walking line -- faced back 0 times,
worst backward step 0.0000 studs`.

**9. The wall is the line the game already has, and a phantom is not part of it.**
`Brain.beaterWallZ` reads `obs.threats` -- the list the Brain is handed every step, filled by
`Match.boarThreats` in DEV and `ForestTest.boarThreats` in the forest -- for the nearest `driver`
across the drive that is BEHIND the animal, and skips any marked `phantom`. That exclusion is
load-bearing: the Forest Test invents a "driver" 11 studs behind every wave, and a wall there would
pin every animal in the wood. `boar_brain.spec` → *"takes the wall from the nearest beater ACROSS the
drive, and only from one behind"* asserts the lane choice, the level-slack boundary at 4 studs, a
hunter, a phantom, a beater who is through, and both off states.

**10. Nothing spawns behind the line, and that is a property of two tables rather than a new rule.**
`forest_stand.spec` → *"spawns NOTHING behind the beaters' line"*: the resting band's far edge and
every resting group and every ambient wave are nearer the road than a beater's own start. Harness
note: `task 168: a beater starts 580 studs north of the road; the deepest spawn of any kind is 460`.
**And nothing is RE-STOCKED behind it either** (the Director's second pass): `restSpot` refuses, on a
first pass, any candidate the sweep would catch -- the same pure rule the flush asks -- and falls back
to today's search when the whole wood is behind the line, because a refusal with no fallback would
leave the wood empty until the next drive, which is a feel decision nobody has made.
`forest_stand.spec` → *"refuses a RE-STOCK spot the line has reached or passed"*.

**11. The line SWEEPS what it passes, so nothing is LEFT behind it either** (the Director's second
pass; this is Karen's item 5 and not a note). The flush stopped being a row of circles: the front is
a LINE (`ForestTest.lineFrontAt`, the beaters' own z interpolated across it, so coverage is gapless by
construction and there is no gap between two lanes to tune), the depth is DERIVED from the lane
spacing (`sqrt(BEATER_STUDS^2 - (laneSpacing/2)^2)` = 47.9 studs -- the depth the old circle really
had at the worst place on the front, promoted to the whole front, so the band is no weaker than the
circles anywhere), and **everything behind the front is swept with no limit**. The point an animal
runs FROM is still a real body: the front decides WHO is flushed, a man decides WHICH WAY.
`forest_stand.spec` has four cases -- the front's interpolation, clamping and sort; the derivation and
its floor; what the band catches in front, at the front and behind it; and the whole wood walked down
a tick at a time with `missed 0, ticks behind the line uncaught 0`. Harness note: `task 168 sweep: 6
resting groups, front depth 47.9 studs (lanes 150 apart, reach 89) -- missed 0, ticks behind the line
uncaught 0`.

---

## What could not be verified, and what is not fixed

**(a) The live count: 0 animals are LEFT behind the line, and 7 of 30 were momentarily behind it.**
Measured after the sweep went in, same place, same bots, **220 samples over 110 s, 30 animals**:

```
EVER behind the front = 7, of which NEVER RAN AFTERWARDS = 0 | deepest behind: front 55 studs
```

against **13 of 27 behind and standing still** before it. **The exception, named:** those seven are a
re-stocked group that the fallback placed behind the line -- the fallback is deliberate, because
refusing every spot once the line is at the road would leave the wood empty until the next drive --
and the sweep took them on the next tick and they all ran out. The console carries that group going:
`-76 ahead of the front, took 9 with it`. So **nothing is left behind**, which is the Director's own
wording, and the residual is "a group can exist behind the line for one tick of the push before it is
swept". Closing even that means refusing the fallback and letting the wood empty, which is Karen's
call and not mine.

**(b) The first-person raise was measured but not photographed.** `tools/studio_mcp.py capture`
cannot move a camera during Play -- `Camera.Rig` owns `CurrentCamera` and overwrites a foreign write
every frame -- so every capture is the player's own view, and at rest the horn sits at the very
bottom-right corner of it (measured: the horn's parts are 2.3-2.8 studs from the camera at 0.71-0.84
of the view axis, un-hidden, `LocalTransparencyModifier = 0`). It IS in frame -- the gathering
screenshot shows it lit by the torches -- but whether the raise reads well from inside her own head
is Karen's eye, and moving it is one `GRIP` line. Queued as **168b**.

**(c) The beater's countdown in the FOREST TEST is the fanfare, not the 15 seconds.** That world
honours a role request at GO on purpose (task 157: the intermission has already respawned everybody
once). In the DEV drive -- the real game -- a beater is assigned in `enterAssigning` and is held for
the whole countdown plus the fanfare. Moving the Forest Test's switch into `Assigning` costs a second
`LoadCharacter` and is the Director's call. Queued as **168c**.

**(d) Nothing here was heard or judged for feel.** The fanfare, the raise, the rows, the torch light
and whether a walled drive feels right are Karen's. One screenshot of the gathering was taken and
inspected (`.screenshots/20261012T204820Z-t168-gathering2.png`): twelve animals in two rows, two
torches burning in frame, the ring clear of the bodies.

**(e) Two defects in this task's own new code were found by measuring it, not by reading it**, and
both are recorded where they were fixed: `AnimationTrack.Parent` is nil for a track from
`Animator:LoadAnimation`, so a `Parent`-guarded `Stop` never ran (the arm stayed up for ever) and the
same guard on the per-character cache loaded a second track on every blast.

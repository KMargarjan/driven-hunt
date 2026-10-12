# Task 168: the beater's drive, the horn at her mouth, the line as a wall, and the gathering

**Date:** 2026-10-12. **Builder.** Five things from one playtest, so one note with five sections. Each
names what the system must do, the sources, what they do well and badly, the pattern adopted and the
numbers. Rule 1 and rule 2: nothing here is invented where something could be borrowed.

Karen, 2026-10-12 ~21:45, verbatim:

> "you can't move as a beater before horn made signal and there should be countdown / when beater
> cross the line of hunter it's done for him cant use sound anymore / We need better horn and we need
> when I am playing beater to make animation when raising horn to face and blow / and on the end we
> need to gather all animals in one place everyone around and torches 4 in corners / animals layed
> down in front in several lines if more"

and ~21:50:

> "and another thing / animals can't come behind beaters"

and ~21:55, clarifying:

> "so animals in map already and once beater push they go or turn around but not after beaters ahead
> and they come from backs"

"Better horn" is the MODEL and is a separate asset task; it is not in this one.

---

## 1. The beaters wait for the horn, and there is a countdown

### What it must do

A beater -- a player as much as a bot -- cannot move until the start fanfare has SOUNDED, and can see
how long is left. GO is the END of the phrase, not the start of it.

### Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | [waidwissen.com, *Jagdleitsignale*](https://waidwissen.com/lexikon/jagdleitsignale) | German hunting lexicon | Web page, no reuse licence; current | Names the signal a drive is OPENED with (*Anblasen des Treibens*) and says two of the three are safety-relevant -- which is the whole argument for "nobody moves until it has sounded" | No note lengths, no timing |
| 2 | ioquake3, `code/game/g_main.c` (`BeginIntermission`, `MoveClientToIntermission`) | id Software's arena shooter, the canonical "everybody is frozen while the game says something" | GPL-2.0, maintained | The repo already borrows this for the results scene (`Match.Scene`'s header): one freeze, applied to a list of clients, with the state machine deciding when | It freezes at the END of a match; the START of one is `g_warmup`, which is a second timer rather than a phase |
| 3 | [Roblox `Sound.PlaybackLoudness`](https://create.roblox.com/docs/reference/engine/classes/Sound) | Engine reference | Current | The only way to measure where a phrase sits inside an asset, which is where `Horn.signalSeconds` comes from | Reports only while the sound is playing, and not at all in Edit |

### The pattern adopted, and why

**The hold is the one task 158 already built, and the window is widened rather than a second timer
added.** Task 163 emits the start signal at the instant `Running` begins and task 158 freed the
beaters at that same instant, so the line walked THROUGH its own fanfare. The fix is one number and
one deadline in the state:

* `Match.CONFIG.GO_HOLD_SECONDS` = `Horn.signalSeconds("start")` = **2.18 s** -- the measured cut of
  "Bugle Call (a)" (0.42 -> 2.60), read from the file that owns the sound rather than retyped;
* `Phase`'s state gains `goFreeAt` and `goFreed`, exactly the shape `nextReleaseAt` already has, so
  the machine still has no `task.delay` and a spec still runs a whole drive in milliseconds.

**The countdown was already there and is now a sentence.** The start card has counted the
intermission down since task 158 (*"Drive starts in 10..."*); what was missing is the line Karen
reads first -- the objective line (task 165) -- so `Objective.text` gains four beater rows: the
countdown, the fanfare, GO, and "you are through".

### Why she could move, which is a different bug and was MEASURED

The dispatch asked for the mechanism, not a guess. Two defects, both found in a live Play session of
the Forest Test (2026-10-12), both now with a case in `match_phase.spec`:

1. **The hold rule was a PHASE and the Forest Test switches roles at GO.** `ForestTestBoot` honours a
   `/beater` request on `PhaseChanged -> Running` on purpose (task 157: the intermission has already
   respawned everybody once, and honouring inside it would be a second `LoadCharacter`). So Karen
   arrived on the beaters' side one step AFTER `Assigning`, and the `team` branch only held during
   `Assigning`. Measured: `team=Drivers walkSpeed=16 anchored=false` from the moment she was made a
   beater. Fix: `Phase.lineHeld` -- the countdown OR the fanfare -- is the window, not the phase.
2. **The re-apply after the placement respawn lost the race.** `Body.place` calls `LoadCharacter`, so
   the character the hold was applied to is destroyed; `Match`'s character watch re-applies it to the
   new one. But in this place `CharacterAdded` fires with `character.Parent == nil` -- the finding
   task 157 already recorded for the PLACEMENT path -- and `Body.holdCharacter` rightly refuses an
   unparented character, so the re-apply did nothing. Measured: `t=7.7 walkSpeed=0 anchored=true` on
   the old character, `t=7.9 walkSpeed=16 anchored=false` on the one that replaced it. Fix:
   `Body.holdWhenLoaded`, which waits for the parent the bounded way `Body.place` already does.

After both: `t=7.62 Drivers ws=16`, `t=7.90 ws=0 anchored=true`, `t=9.79 ws=16` -- held from the
respawn to GO + 2.18 s, then let go with everybody.

### The numbers

| Number | Value | Why |
|---|---|---|
| `GO_HOLD_SECONDS` | 2.18 s | the measured length of the start phrase, read from `Horn.CONFIG.SIGNAL` |
| `Objective.CONFIG.GO_FLASH_SECONDS` | 5 s | long enough to read `GO` and connect it to the fanfare, short enough that a ten-minute drive is not spent being told to start |
| `PARENT_WAIT_SECONDS` | 2 s (existing) | `Body.place`'s own bound for "has this character arrived yet" |

---

## 2. A beater who is through the line is finished

### What it must do

Once a beater is past the hunters, his horn does nothing -- for a player and for a bot -- and his
screen says why. "Crossed" must mean exactly one thing.

### Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | The repo's own `Match.crossedLine` (task 159) | the predicate that ends a drive | ours | It is already the ONE answer to "is this beater through", measured against the nearest STAND because the forest's road is a sine | Nothing: this task reuses it unchanged |
| 2 | ioquake3, `code/game/g_weapon.c` / `bg_pmove.c` (`pm->ps->weapon` gating) | how an arena shooter refuses a weapon | GPL-2.0, maintained | The refusal is at the ONE place the weapon fires, not at the input: a client that fakes the click still fires nothing | Nothing applicable |
| 3 | [`Tool.Activated`](https://create.roblox.com/docs/reference/engine/classes/Tool#Activated) | Engine reference | Current | Fires on the SERVER for a server-owned Tool, so there is no remote to forge | Says nothing about refusing one |

### The pattern adopted

**One policy, injected, asked at the one door.** `Weapon.Horn.setBlowPolicy` is the shape
`setCarryPolicy` and `Weapon.setArmingPolicy` already have, and both composition roots wire it to
`Match.mayBlowHorn`. The refusal is inside `Horn.blowTool` -- the single implementation of what a
blast is -- so a player's click and a bot's rhythm are refused by the same line, and a refused blast
takes no cooldown, sounds nothing, tilts nothing and publishes no `Blown` (so it cannot move an
animal either).

**The Tool stays in his hand.** Of the Director's two options, revoking it would have meant teaching
the CARRY rule about the line as well -- and a man who walked back north would be handed a new horn --
plus a Tool vanishing from a hand with nothing on screen to say why. The objective line says *"you are
through - wait"*.

**One measurement, not two.** `Match.beaterCrossing` already walks every beater against
`Match.crossedLine` once a tick to decide whether the drive is over; it now records WHICH of them are
through in the same walk. Asking the geometry again at the instant of a blast would be a second answer
to one question.

---

## 3. The horn goes to the mouth, for a player as well as a bot

### What it must do

When a player blows, her arm raises the horn to her face and lowers it again -- seen by everybody in
third person, and by her in first person.

### Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | [`KeyframeSequenceProvider:RegisterKeyframeSequence`](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider) | Engine reference | Current | The documented way to make a usable animation content id with no upload -- which matters because an animation asset id can otherwise only be made by hand in Studio's Animation Editor | The id is temporary and session-local (which is exactly what a pose rebuilt from numbers wants) |
| 2 | [`Animator:LoadAnimation`](https://create.roblox.com/docs/reference/engine/classes/Animator) | Engine reference | Current | An animation played on a character's Animator on the SERVER replicates to every client, so one write gives third person and first person at once | Says nothing about priority against the stock `Animate` script |
| 3 | Task 166's own measurements (this repo) | three mechanisms tried against a live rig | ours | `AnimationConstraint.Transform` moved the hand 0.01 studs, the same write every Heartbeat 0.12, the rig attachment's CFrame 0.3 -- because the animator re-solves the joint every frame. Only another ANIMATION, above the gait, poses an arm | It was built for bots only, in `Bots.Rig`, where a player cannot reach it |

### The pattern adopted

**One definition of the gesture, two players of it.** The pose, the sequence and the one registered id
moved to `src/shared/Horn` -- the file that already owns the other half of the same gesture, the
Tool's `GRIP_BLOW` tilt. `Bots.Rig.BLOW`, `Rig.blowSequence` and `Rig.blowAnimationId` are now aliases
of them, so a bot plays what it played before. `Weapon.Horn` plays it on a PLAYER's character and
`Bots.Rig` on a rig's: one writer of each Animator, no overlap.

**Measured live** (Forest Test, 2026-10-12, through the real `Tool.Activated` door):

```
BEFORE: handle-to-head 3.42 studs, no Action track
DURING: handle-to-head 1.77 studs, one track w=1.00 priority=Action, Grip=GRIP_BLOW
AFTER:  handle-to-head 3.42 studs, no Action track, Grip=GRIP
```

Two defects were found by that measurement and fixed: the lower never ran (the stop was guarded on
`track.Parent ~= nil`, and `LoadAnimation` returns a track whose Parent is nil -- so the arm stayed
up for ever), and the per-character cache was guarded the same way, so a second track was loaded on
every blast.

---

## 4. The gathering: rows, a ring that contains them, and four torches

### What it must do

Every animal shot in the drive laid out in front, in several rows if there are more than fit one;
everybody standing round them; four real torches at the corners.

### Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | *Strecke legen* (the German hunt's own laying-out of the bag), as the task-159 note already cites | practice | -- | A day's bag is laid in rows, same way round, in front of the people -- which is exactly what Karen described without naming it | Prescribes an order by species and rank this game has no concept of |
| 2 | [Roblox `Fire`](https://create.roblox.com/docs/reference/engine/classes/Fire) | Engine reference | Current | A particle flame that ANIMATES ITSELF: the flicker costs no per-frame writer, which is the whole reason it is a `Fire` and not a scripted light | `Size` and `Heat` are in the engine's own units with no conversion documented, so what it looks like is a screenshot |
| 3 | [Roblox `PointLight`](https://create.roblox.com/docs/reference/engine/classes/PointLight) | Engine reference | Current | Three numbers and a documented parent-position emission -- which is why moving the lamp onto the flame changed what the scene looks like | No falloff curve documented |

### The pattern adopted

**Rows, and the ring grows to hold them.** `PER_ROW` 6 at `SPACING_STUDS` 6 is 30 studs of front;
`ROW_SPACING_STUDS` 8 is deeper than the sideways spacing because an animal is 4 studs long and lies
across the row. `Scene.layoutExtent` is the ONE measurement of how big the block is, and both the ring
and the corners read it: `RING_RADIUS_STUDS` 14 against a 15-stud half-width is why a bag of twelve
used to stand the people inside the row.

**`CORNER_STUDS` became a floor rather than the answer**, so that with a small bag the scene Karen has
already looked at does not move: ring 14 + `CORNER_MARGIN_STUDS` 2 = 16 = `CORNER_STUDS`.

**A torch is a post, a `Flame` part at the top, and on the flame a `Fire` and the `PointLight`.** The
lamp moved off the post because a `PointLight` emits from its parent's position -- on a 10-stud post
it was lighting the bodies from knee height. `LIGHT_BRIGHTNESS` 4 -> 2.5 followed, and the reason is a
screenshot: the first photograph of the new scene came back washed out.

---

## 5. The beaters' line is a wall

### What it must do

An animal never moves to the beaters' side of the line. Pushed, it goes forward or breaks sideways;
it never slips between two beaters and comes out behind them. Nothing spawns or rests behind the line.

### Sources

| # | Source | What it is | Licence / maintenance | Good | Bad |
|---|---|---|---|---|---|
| 1 | ioquake3, `code/game/bg_pmove.c` (`PM_ClipVelocity`, `PM_SlideMove`) | the canonical "you may not pass through this plane" | GPL-2.0, maintained | Takes the component of the motion INTO the plane away and keeps the rest, so the body SLIDES along the surface instead of stopping dead or bouncing -- which is exactly Karen's *"they go or turn around"* | It is a collision response; there is no surface here, only a line of men |
| 2 | Reynolds, [*Steering Behaviors For Autonomous Characters*](https://www.red3d.com/cwr/steer/gdc99/) (GDC 1999), `containment` | the steering literature this repo already borrows from | Paper, read-and-borrow | Names the shape of the problem: keeping a character inside a region without the region fighting the other behaviours | Reynolds' own containment is a FORCE, which is the thing that would lose the argument here (see below) |
| 3 | Sodeikat & Pohlmeyer (2003), *Wildlife Biology* 9(s1), on driven wild boar | the field study the sounder note already cites | Journal, paywalled abstract | Family groups flee as a unit ALONG A KNOWN TRAIL and stay in the home range -- they do not mill about behind the beaters | Says nothing about a line of men as a barrier; the barrier is a game rule, not an observation |

### The pattern adopted, and why it is a constraint and not a force

**A steering term would have lost.** Everything that decides a boar's heading already pulls on it --
the route to the exit, the sounder's slot, the latched flight, two whisker deflections, a wedge
sidestep, a stuck sidestep and a slew. A "stay in front" vector would have been a ninth vote; a
CONSTRAINT applied to the FINISHED heading cannot be outvoted. So `Brain.forwardOfWall` is applied
once, at the end of `Brain:step`, to `self._desired` -- which is both where the animal goes and where
it FACES, so it never even turns to look for a way back.

**`PM_ClipVelocity` is the arithmetic.** Within `MARGIN_STUDS` of the wall, the component of the
heading pointing away from the exit is removed and the rest is kept; an animal heading straight back
has nothing left, so it breaks on its own side (`_whiskerSide`, drawn once at birth, the same tie-break
`_latchFlight` uses so a herd does not split and re-split). One already behind gets the slide plus a
full step toward the exit, so it comes back out through the line at about 45 degrees.

**Where the line IS comes through the threat seam that already exists.** `Brain.beaterWallZ` reads
`obs.threats` -- the list the Brain is handed every step -- for the nearest `driver` ACROSS the drive,
and only one BEHIND the animal (`LEVEL_SLACK_STUDS` 4 of tolerance so one exactly abreast still
counts). A beater who is THROUGH is not a wall, or he would pin the wood behind him. **A phantom is
not a wall either**, and that exclusion is load-bearing: the Forest Test invents a "driver" 11 studs
behind every wave, and a wall there would pin every animal to the spot it was standing on.

### The numbers

| Number | Value | Why |
|---|---|---|
| `MARGIN_STUDS` | 10 | six ticks of a `PACE.RUN_SPEED` sprint, so the wall cannot be crossed between two steps; also about the distance at which an animal is already fleeing (`SPOOK_STUDS` 30) |
| `LEVEL_SLACK_STUDS` | 4 | one stride, so a beater exactly abreast is still a wall |
| `ENABLED` | true | a RULE Karen asked for in her own words, not an experiment -- the call `END_ON_BEATERS_CROSS` and `SCENE.ENABLED` already are. Both states reachable by parameter from a spec |

### What was measured, and the one thing this does not fix

`boar_brain.spec` drives 3,600 ticks against a line of three beaters walking at 5 studs/s, with a
flank spook every ten seconds: **faced back 0 times, worst backward step 0.0000 studs**.

A live drive in the Forest Test (27 animals, 4 beater bodies, 50 s sampled twice a second) found **one**
boar of 27 that moved 1 stud north at the moment a beater walked level with it -- a body settling, not
a chosen heading -- and **13** that ended up behind the line WITHOUT MOVING, because the line walked
past them: the beaters flush at 89 studs (`SPOOK.BEATER_STUDS`) and the lanes are 150 studs apart, so a
group in between is never touched. **That is a real gap and it is not one a direction constraint can
close** -- it needs the push to be wider or the line to sweep what it passes. Queued as 168a. Nothing
SPAWNS behind the line: the resting band's far edge is 460 studs from the road and a beater starts at
580, which `forest_stand.spec` now asserts rather than assumes.

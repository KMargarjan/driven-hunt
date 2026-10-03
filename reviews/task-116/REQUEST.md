# Task 116 -- the shot, the death and the sound of a boar, behind `BOAR_MODEL`

Task: 116
Round: 1
Base: `main` (`39da8ea`)
Code commit: 9b2c58db2c42064ceee1e6579fd40c261d4537fc

```
[harness] PASS: 33/33 checks @ 9b2c58db2c42064ceee1e6579fd40c261d4537fc (clean tree) scope=all
```

**ONE LINE IS THE WHOLE GATE.** `needs_two_player` over `git diff --name-only origin/main...HEAD`
returns **`[]`**: nothing changed is in `TWO_PLAYER_PATHS`. It is boar, assets and tools -- no
`src/server/Match/`, no `MatchBoot`, no `src/client/Match/`, no `src/shared/Drive/`, no
`tests/client/Role.luau`, none of the match / tie / outfit specs. `test2` is **N/A**, with that as
the reason.

The code commit above is a paperwork commit one step after the last commit that changed `src/`,
`tests/` or `tools/` (`61e8719`); it is the commit the full clean-tree run names, which is the
definition the gate uses, and only `TASKS.md` changed between them.

## What this is

Karen, 2026-10-03: *"when hit not head (heart) sound, can fall on side and legs moving like in real
life / can be hit to back part start to do circles with first legs on"*, and *"I just need that once
they walk you can hear"*. Three rounds of work: the first build, a fix round after her first look
(*"body shot is a bit odd now feels late hit and odd / no cicrcle but I can see back legs
disabled"*), and the wiring of three animation clips this project authored and the Director
published. Her second look, on this head: ***"I thin kwe good"***.

## Claims

1. **The zone decides a CLASS and the class decides the reaction; no code holds a list of zone
   names.** `Wound.hitClass` is a pure lookup in `Boar.CONFIG.WOUND.CLASS` -- `vital` (head, chest),
   `crippling` (the new `rear`), `nonVital` (body, legs) -- and anything unclassed is `nonVital`,
   which is what every zone did before this task. `Brain._reactToHit` reads the class, `Boar`'s
   `takeHit` reads it to pick the sound. *Verify:* `boar_shot.spec`, "what a hit in each zone MEANS"
   -- every class, the `nonVital` fallback for an unknown zone, for `nil`, and for a config with no
   `CLASS` table at all; plus "every zone the boar actually HAS is classed".

2. **The hindquarters zone is added the way every zone exists, and nothing else moved.** A row in
   `Boar.CONFIG.ZONES` plus its `ORDER` entry, charged at the trunk's own 55 / 11 -- the rump *is*
   trunk -- so one slug is `MORTAL` and short of `LETHAL`. The existing three zone parts, their
   boxes, the `body` fallback and every other damage number are untouched. *Verify:*
   `boar_zones.spec`, "is one trunk and one zone part per declared zone" (counted from
   `ZONES.ORDER`, not a literal) and "is reachable by a real ray: the hindquarters, from behind and
   from the flank"; `boar_wound.spec`, "are the numbers production actually ships".

3. **A graze does not cripple, and that is what stops a boar circling for ever.** A crippled boar is
   taken out of the escape test in `Brain._outcome` (it is going nowhere) and `Wound.advance` never
   collapses a *grazed* animal, so crippling on a graze would leave one turning in the arena with no
   way out. `Brain._reactToHit` requires `event.severity ~= "grazed"`. *Verify:* `boar_shot.spec`,
   "CRIPPLING: a GRAZE to the rump is a graze, so no boar can circle for ever", "it cannot escape,
   because it is not going anywhere" (and still despawns out of bounds), and "a second shot still
   kills it, and the wound still finishes it".

4. **The circle is now wider than the animal, and that number is why it changed.** MEASURED on a
   real crippled boar, every Heartbeat for 12 s: at 3 studs/s and 70 deg/s the radius is
   `v / w` = **2.45 studs** -- a circle 4.9 studs across on an animal 5.5 studs long, a pivot and not
   a circle, which is exactly what Karen reported. 4.5 studs/s and 45 deg/s give radius **5.73**,
   **11.5 studs across**, an **8.0 s** lap; `FLIGHT.rear` went 60 to 90 so it still lasts the same
   20 s. **This is the opposite of what the fix round asked for (a *tighter* turn) and the
   measurement is the reason.** *Verify:* `boar_shot.spec`, "a crippled boar draws a circle a player
   can SEE" -- the radius against `CONFIG.BODY_SIZE.Z`, the lap under 12 s, and the crawl still
   slower than a trot and still faster than the walk clip's own ground speed.

5. **The late hit was two things and neither was logic.** MEASURED on the client that fired, at
   `RenderStepped`: click at 0.000; the server's answer at **0.069** with the `cry` Sound
   `IsLoaded = false` and the flinch track at `WeightCurrent` 0.00 / `TimePosition` 0.00; both
   finally moving at **0.433**; full flinch weight at **0.568**. The client was fetching an audio and
   an animation asset nothing had ever asked it for. `Body.warmAssets` now plays every clip at
   weight 0 and every sound at volume 0 when the coat goes on, and `Body.coolAssets` ends it
   `WARM_SECONDS` later -- re-measured, `hit` and `cry` are both `IsLoaded` from frame 0, before any
   shot. The second half: the 0.833 s IN-PLACE flinch held the animation while the body bolted at
   sprint speed, so the animal slid ~30 studs with still legs before it ran. *Verify:*
   `boar_shot.spec`, "the hit lands on the frame the player expects" -- `Boar.flinchWindow` gives a
   standing animal the whole clip and a running one `HIT_MOVING_SECONDS`, `clipFor` hands over to
   the gait at exactly that point, `Boar.fadeFor` cuts a hit and a death in at `HIT_FADE_SECONDS`
   and blends a gait, and "every clip and every sound is ASKED FOR before the first shot" asserts
   the pre-roll happens AND that every volume is back afterwards.

6. **Sound is `Sound` objects in the trunk, and every id is data.** 3D for free, replicated with the
   boar, no new owner and no remote -- `Body` creates them because `Body` is the only writer of a
   boar's Instances. Footsteps by gait, rated off the clips' own measured ground speeds
   (*referenced*, not copied, so a re-measured clip moves its sound and its legs together); grunts
   when calm and breathing when working, never both, with the first interval **armed** rather than
   fired so a sounder does not grunt in chorus; hit, cry, death, body fall and a delayed last breath.
   *Verify:* `boar_shot.spec`, "every sound is configured, spatial and swappable" and "the sounds
   live on the boar" -- flag OFF has no folder and no `Sound` at all; flag ON has one folder on the
   TRUNK with exactly ten Sounds, `InverseTapered`, `NEAR_STUDS`, each row's own range, and only the
   three footstep loops looped; at most one footstep loop audible at a time; a real `takeHit` plays
   the hit and the cry from the configured ids; a dead boar has no footsteps, screams, and breathes
   out once a second later; and "is rated off the CLIP'S OWN measured ground speed" asserts
   `stepSoundFor` and `clipFor` return the same rate at every speed a boar can reach.

7. **Three clips this project authored, out of the clips the package has.** `Bone.Transform` is the
   Animator's output and a script's write to it survived **0 of 122** frames on the server and
   **0 of 121** on the client, so paddling legs and a dragged hindquarter need CLIPS.
   `tools/boar_prep.py`'s `SYNTH_CLIPS` builds each authored frame as a blend between two poses the
   package's own animator made -- nothing is invented, and no guess is made about which axis a leg
   bone bends on. MEASURED per hoof: `Cripple_Drag`'s **front** hooves travel 2.866 and 2.863
   studs/s (`Walk_F_IP`'s own 2.853 -- a real walk cycle) and its **hind** 0.826 and 0.931, a third
   of it, dragging; the paddles move the up-side legs 1.74-4.64 studs/s and the two against the
   ground 0.30-0.37, because a leg under a lying animal cannot swing. *Verify:*
   `tools/boar_prep.py` `SYNTH_CLIPS` and `tools/boar_prep_blender.py` `synth_actions`;
   `boar_shot.spec`, "the clips this project authored" -- `Boar.hasClip`, `Boar.deathClips`, the
   death becoming fall-then-paddle only when the paddle has an id, the drag only when it has one,
   and the drag's rate off its FRONT hooves.

8. **With no id published, every one of those paths is exactly what it was.** `Body.hasClip` is the
   single test, and the whole-body `TimePosition` twitch stays as the fallback and is skipped the
   moment a real paddle clip exists. The three ids are now in `Assets.ROWS` with `source = "own"`,
   and their lengths were **read back off the live assets**: 1.0000 s and 4.0000, not the 1.042 and
   4.042 the prep tool reported. A clip's length is its INTERVALS, not its keys -- the same one-frame
   error the ten package clips had after Task 115 -- and `boar_prep_blender.py` now reports
   `(frames - 1) / fps` and agrees with Roblox on all thirteen. All three were published
   `Loop = true`; `Body.play` writes `Looped` from the config before every `Play`. *Verify:*
   `boar_shot.spec`, "WITH NO ID the death is one clip and a crippled boar walks, exactly as before"
   against "WITH AN ID the death becomes fall then paddle, and a crippled boar drags"; "plays the two
   paddles ONCE and the drag for ever, whatever the asset says"; "plays each authored clip at the id
   the manifest published" (each id, and each published `clipSeconds` against the length the boar
   plays by, to half a frame); and `boar_model.spec`, "has a row with a real asset id for every one
   of them" -- now thirteen -- plus `source == "own"` on the three.

## What I looked at (rule 5)

Frames in `.screenshots/`, each inspected:

- **`boar-116-aimed.png`** -- a live boar seen from behind at 14 studs, flag ON: dark coat, four legs,
  standing on the surface. This is the view the new `rear` zone is shot from.
- **`boar-116-carcass-1s.png`** and **`-6s.png`** -- a boar killed by a replayed click, ~1 s and ~6 s
  after death. At 1 s it is mid-settle, body on its flank, legs out to one side, head twisted down
  and forward; at 6 s it is flat on its side, still, ON the surface and not in it. The kill feed
  reads "BOAR body".
- **`boar-116d-death-1.png`** (+0.6 s) and **`-3.png`** (+4.0 s), after the authored paddle was
  wired: the animal flat on its left side on the surface, legs out, head low. The two frames are
  near-identical, which is the right end state -- the paddle has decayed to nothing. The recorded
  track log for that same kill is the other half: `Death_L`, then `Death_Paddle_L` from about 1.2 s,
  holding at `TimePosition` **3.98-4.00** from 5.2 s on. Fall, paddle, still.
- **`boar-116d-drag-2.png`** and **`-4.png`** -- `Cripple_Drag` played on a live boar's own Animator:
  the hind legs tucked and trailing while the front end walks, plainly different from a walking boar.

## What I could NOT see, and what that leaves unproved

- **The rear reaction from a real click.** I could not steer a replayed mouse shot onto a chosen hit
  zone. The camera ray meets `ZoneRear` and the slug still charges the trunk or the legs: the gun's
  `Muzzle` attachment sits at camera-space **(-0.71, -1.69, +5.84)**, so the shot's ray and the
  camera's ray are not the same ray, and correcting the aim by that offset did not fix it either
  (five staged attempts across three sessions, each confirmed by casting the camera ray before
  clicking). Shots land reliably; WHICH zone they land in does not, from this harness. So the
  crippled reaction is evidenced by `boar_shot.spec` -- pure, and live through `Runtime:takeHit` in a
  Play session with real physics (699 deg of turn in one direction over 10 s; strayed 4.91 studs in
  3 s) -- and NOT by a click. **This is the one claim in the drawn half that rests on specs alone.**
- **The staged drag and walk frames show the animal about a stud above its shadow**, and my first
  reading of that was a defect in the authored clip. It is not: I shot a **control** -- the package's
  own `Walk_F_IP` played by the identical method, at the same weight and priority
  (`boar-116e-walkcontrol-2.png`) -- and it floats identically. The shadow is the physics box's. What
  the frames therefore show is the clip's POSE, not its height, and the height is unproved either
  way by them. In Blender the drag's lowest hoof is 0.052 m against the walk's 0.099 and `Death_L`'s
  0.045, so it is not floating there.
- **Nobody has heard any of it.** No tool in this repository can listen. Every sound is evidenced by
  its Instance's properties and by which `Sound` was playing; whether 9117369876 *sounds* like a boar
  is Karen's ears. She has now played it twice and said *"its good"* of hearing them coming and
  *"I thin kwe good"* of the whole thing.
- **The vital "short dash" the fix round asked for is absent**, and the reason is the same dispatch's
  own constraint: a chest slug charges 100, which IS `LETHAL`, and `FLIGHT.chest` is 0, so a dash
  means changing damage numbers the brief forbade changing. Queued as 116a(a).
- **No spec can load a real animation or an audio asset**, which is why `clipFor`, `flinchWindow`,
  `fadeFor`, `hasClip`, `deathClips`, `stepSoundFor`, `jitteredPitch` and `paddleOffset` are pure
  functions with their own cases, and why the warm-up is asserted through `Sound.Volume` rather than
  through anything being heard.
- **`Body.warmAssets` is a server-side substitute for `ContentProvider:PreloadAsync`**, which is a
  client call. There is no client-side boar code to put the documented one in, and inventing some
  would be a new owner for a job that needs no owner. The measurement says the substitute works; it
  is not the documented tool.

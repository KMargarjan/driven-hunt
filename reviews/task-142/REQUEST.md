# Task 142 - Karen's five rifle fixes

Task: 142
Round: 3
Base: main (`b95d8a7`, task 141 merged as PR #124)
Code commit: `7ea2e5cd59e6b75483c0b4803d92b47184275d9a`

```
[harness] PASS: 33/33 checks @ 7ea2e5cd59e6b75483c0b4803d92b47184275d9a (clean tree) scope=all
```

`test2` is N/A: nothing in this diff touches `TWO_PLAYER_PATHS` (`src/server/Match/`, `MatchBoot`,
`src/client/Match/`, `src/shared/Drive/`, `tests/client/Role.luau` or their specs).

Karen, after playing the merged rifle: *"we need a dot in scope center red dot / next is reload has
to be done for rifle with right hand like it happen in real life / and in magazine 3 shells then it
changes with left hand magazine / in front of scope when not aiming has circle transperent it
shouldn't be like that / for rifle has to be another gun fire sound"*. Transcribed in `PLAYTEST.md`.
The **scopeless rifle she asked for in the same message is Task 143**, by the Director's cut, and is
not here. **No Architect run:** no new owner — the mask and the dot are the Hud's, the hands and the
drawn box are the viewmodel's, the magazine is the reducer's. The note is
`docs/research/2026-10-10-rifle-bolt-magazine-sound.md`.

## Round 3: the cycle pose, and a spec that could not fail

**1. The cycle pose still held the OLD left hand, and this is the sharpest finding of the task.**
Round 2 moved the rifle's left hand onto the fore-end in `carry` and `aim` and left
`weapons.rifle.cycle.left` at the value it replaced — **bit for bit the pose claim 1 identifies as
the circle Karen complained about**. `Mode.handFrame` lerps toward the action pose on `openTilt`, so
the glove slid a stud back up the stock and returned on **every bolt cycle**: the motion claim 2 says
no longer happens, landing on the pose claim 1 says is gone, at the exact moment round 2 made the
scope come down and she is looking at it. Before round 2 `carry.left == cycle.left` so the lerp was
identity; my own change created the jump. A hand holding the stock does not move while the bolt is
worked, so `cycle.left` is the fore-end now and the lerp is identity again.
**MEASURED, scoped, firing:** the left hand moves **0.0008 studs** from rest across the whole cycle,
against the 1.019 studs in Z the Reviewer computed.

**2. The shell-feed case could not fail.** It asserted 0 from a function that returns 0 on an
EARLIER guard — `reload.open` is false and the spec never called `setReload` — so it passed with the
round-2 fix deleted, while the request named it as that fix's verification. It drives the player's
path now: the state `Camera.breakFrom` produces after a rifle `Break` (open, one case spent, chamber
2 still loaded), on the module's own clock, asserting a **non-zero** weight without `MAGAZINE_SWAP`
and **zero** with it, and restoring the state afterwards. (Its first version then failed the gate
with *"pos is not a valid member of CFrame"* — `SHELL_LOAD` is the raw pose block out of
`poses.json`, not engine values — so it uses the real one.)

**The magazine voice is the SERVER's own step now, not a count of rounds at all.** Round 1 counted
live chambers, round 2 counted them per weapon, and the Reviewer was right both times: per-weapon
still fires on a RE-GRANT, where a fresh full magazine steps the stored count with no magazine
changed. A round count is simply not the question — `snapshot.action` is, and the edge into
`"Magazine"` is exactly one magazine change. `liveIn`/`wasLive` are gone.

**`Camera.leavesScopeFor(action, scope)` is pure and public**, so both branches of the adopted
behaviour are driven by a spec instead of by a pasted trace — including the "stay scoped" branch,
which is one number. **One assertion pins the swap's two homes equal** (the server times the window
with `RELOAD[1].wait`, the client animates over `cycle.magazine.seconds`). The comment that named the
bolt part's frame now names the one `hinge` actually returns, and the `Magazine` step says out loud
that it discards a spent case with the box.

## The ten claims

1. **The circle in front of the scope was the LEFT GLOVE, and I had the wrong suspect first.** The
   drawn `Lens` disc was the obvious candidate, so I removed it — and the circle was still there,
   with `box=0` and all four meshes drawn. Hiding `HandLeft` and re-capturing is what settled it: the
   rifle's `carry.left` was the SHOTGUN's numbers, copied at the version-4 migration and never tuned,
   and on a 4.4-stud rifle they put the glove up by the scope's objective, where end-on it reads as a
   pale translucent disc with a dark cone in it. **Verify:** `weapons.rifle.carry.left` and `aim.left`
   in `poses.json` (six lines); `.screenshots/t142-rifle-carry.png` against task 141's. The Lens stays
   removed and archived (`backups/2026-10-10-rifle-drawn-lens.md`) for task 141's own reason, but it
   was **not** what she saw and the note says so.

2. **The left hand no longer rides the bolt.** `poseHands` placed it from the cycle group's
   transform — right for a break action whose barrels it is holding, wrong for a bolt, where a
   fore-end hand would slide up and down the stock every shot. `CYCLE_KIND` decides, as it already
   decides how that group moves at all. **Verify:** the `follows` line in `Viewmodel.poseHands`.

3. **The red dot is data, in degrees, like every other length in that reticle.**
   `Rifle.CONFIG.scope.reticle.dot` is a 0.085° core with a 0.26° halo at 0.55 transparency — about
   4.6 px on a 1080-high viewport, a dot you can hold on a chest at 150 studs. A reticle with no `dot`
   draws none. **Verify:** `Hud.layoutReticle`'s `circle()`; `.screenshots/t142-rifle-scoped.png`.

4. **The magazine is three chambers in the reducer this repo already has** (rule 2). `barrels` is
   already an array of Live/Spent/Empty and `reserve` already a pocket, so a box of three is that
   array with three entries. Two row fields carry the difference: **`CYCLE_EJECTS = "spent"`**,
   because the shotgun's `Break` empties EVERY chamber and on a magazine that would dump two live
   rounds after every shot; and **one new `Magazine` action** that fills every empty chamber in one
   step, because feeding three through `Load` is a stripper clip and not what she described. The bolt
   is two steps now, not three — there is nothing to feed by hand. **Verify:** `rifle.spec`, "works
   the bolt without touching the rest of the magazine", "empties in three shots and a magazine change
   fills it from the pocket", and **"leaves the SHOTGUN's break action exactly as it was"**, which is
   the half that must not move.

5. **MEASURED END TO END in the Forest Test, through the player's own `FireRequest`:**

   ```
   +0.08 action=nil      busy=0.12 live=2 res=9      +3.06 action=Magazine busy=1.35 live=3 res=6
   +0.20 action=Break    busy=0.26 live=2 res=9      +4.43 action=Break    busy=0.26 live=3 res=6
   +0.45 action=Close    busy=0.36 live=2 res=9      +4.71 action=Close    busy=0.36 live=3 res=6
   ... three shots, live 2 -> 1 -> 0 ...             maxExtraDrop=0.380 of dropStuds 0.42
   ```
   (Round 1's trace read `0.550`, which was that build's `dropStuds`; **0.42 ships**, lowered after
   looking at the frame. The Reviewer caught the mismatch.)
   `3/3 → 2/3 → 1/3 → 0/3 →` the empty rifle changes its own magazine (Karen: *"when empty (or on
   R)"*) `→ 3/3`, pocket 9 → 6, and the bolt chambers the first round after it.

6. **The right hand works the bolt, placed from the BOLT GROUP'S OWN TRANSFORM.** Weighted by the
   same `cycleProgress` the bolt mesh moves on, so "the bolt moves with the hand" is true by
   construction rather than by two timelines that agree until they do not. Timings and the grip pose
   are `poses.json` data (content lane). **Verify:** `Viewmodel.boltHandWeight` and the `onBolt` block
   in `poseHands`, plus the round-2 case that pins the hand to the knob at full travel. MEASURED live: the right hand goes from the grip `(-0.046, -0.198, 0.992)` to
   `(0.035, -0.031, 0.42)` while the bolt sits at `(-0.095, 0.055, 0.737) roll -60` — drawn back and
   turned up — and both are home 0.62 s later.

7. **THE VIEW COMES OUT OF THE SCOPE FOR THE CYCLE** — built in round 2, measured above; the note's
   §2 says why (three sources fetched). PUBG's own community asks how to STAY scoped through a bolt cycle — the question is the
   evidence that the default is to leave it, and the answer is a workaround; Battlefield 1 requires
   coming out of the sight. For THIS game it is not close, for a reason the sources need not supply:
   our sight picture is a full-screen black mask with the gun hidden behind it (task 141), so "stay
   scoped" means watching a black circle while the thing Karen asked to see happens behind it. **The
   other branch is reachable by a parameter and not by an edit.** Enlisted's dev forum settles the
   SPEED, not the camera — *"Can cycle that bolt every bit has fast. Hard and fast."* — so the cycle
   is **0.62 s** against the shotgun's 2.0.

8. **The sounds are per WEAPON.** One id for the whole game was the bug Karen heard. Every id is
   Roblox-provided licensed library audio, **verified by name and creator** through the public
   asset-details endpoint and **measured to load** here: shot `9118173739` "Rifle Single Shots 1
   (SFX)", ProSoundEffects, a Barrett .50 — `loaded=true 3.36 s` against the shotgun's **0.92 s**,
   which IS the longer tail — plus a bolt and a magazine voice. **Every sample is CUT**, because
   "Single Shot**s**" is a take and not a round; the `cut`/`fade` mechanism is the one
   `Boar.CONFIG.SOUND` already uses for the death squeal. **Verify:** `Rifle.CONFIG.SOUND`,
   `Sound.voiceFor`, and `CameraBoot`'s two edges. **Nobody here has heard any of them.**

9. **The scoped shot's smoke is out of the glass** (queued 141a). `Viewmodel.muzzle` answers nil
   while the gun is behind the mask, so `Effects` draws from the payload's own world muzzle instead
   of from where the gun was when the eye arrived — which is what put a 0.55-stud ball over ~11 of
   the eyepiece's 17 degrees for 1.1 s after every scoped shot. **Verify:** the `hiddenNow` guard.

10. **The running step is on the wire, because it cannot be inferred.** `snapshot.action` names the
    sequence step the server is executing. The magazine change applies at the START of its window —
    the chambers are full for the whole 1.35 s the hands are still swapping the box — so a client
    watching the replica sees a full gun and a `busyFor`, which is also what the first moments of a
    bolt cycle look like. **Verify:** `Shotgun.snapshot`'s new parameter and `publish`'s.

## Three defects the live trace found, each invisible without measuring

* **`waitFor` searched only `row.CYCLE`**, and `Magazine` lives in `row.RELOAD` — so that step
  published `action=Magazine busy=0.00` and its whole 1.35 s window did not exist. Measured before:
  the drawn box never moved, at all. After: `busy=1.35` and it drops its full 0.55.
* **The client cleared the swap on any snapshot with no action**, and the arming sweep publishes
  those on its own schedule — so the animation was cut off 0.31 s in and the box reached 0.313 studs
  of its 0.55. It ends on its own clock now, or when the server starts a different step.
* **The box hung under the BARREL.** The `action` group spans -2.2 to +0.909 — it holds the barrel
  too — so its centre is a stud and a half out along the bore, and a magazine placed from it hangs in
  mid-air beside the fore-end. That is exactly what the first frame showed; it is placed from the
  BOLT's box now, which is what sits over the receiver.

## The frames, looked at (rule 5)

| frame | what it shows, wrong first |
|---|---|
| `t142-rifle-carry.png` | The left glove now reads as a shapeless khaki lump sitting slightly below and left of the fore-end rather than wrapped around it — it does not clearly touch the wood, and that is a pose refinement for the Director. What the frame is FOR is there: **the pale translucent circle in front of the scope is gone**, the objective end is clean black mesh, and the hand is nowhere near it |
| `t142-rifle-scoped.png` | The dot is **small** — 4-5 px — and against this mid-tone birch the halo is hard to separate from the core, so it reads as a single red cluster rather than an illuminated dot with a glow. It is dead centre, crisp, and clearly red on both the pale trunk and the dark grass. One number if Karen wants it bigger |
| `t142-mag-mid.png` | The magazine reads as a **plain dark slab** with no taper and no feed lips, and at this moment it is half out of the bottom of the frame; the left glove is beside it rather than visibly closed on it. But it IS under the receiver (not out under the barrel, which is where the first build put it), it IS out of the gun, the left hand HAS left the fore-end, and the readout reads `3/3 .416 6 R` — reloaded, three in the magazine, six in the pocket, action busy |
| `t142-boltburst-1.png` | The shot itself: muzzle flash at the END OF THE BARREL and the tracer going out from it, gun kicked up, readout `2/3 .416 3 R`. This is the frame that shows the flash is at the muzzle and not at the shoulder |
| `t142-boltburst-2.png` | Mid-cycle — readout `2/3 .416 3 R`, and the right glove is **gone from the grip**. I could not land a crisp "hand on the knob" frame: the cycle is 0.62 s and a capture round-trip through the harness is about half of that. The numbers in claim 6 are the evidence for the hand, not this frame |

## Standing rule A, Forest Test, 85 s, with RIFLE ON (how the Director is testing it)

* the Tool is in the CHARACTER at 15 s and at 85 s (`gun in hand @15s=1 @85s=1`)
* **0 "Stack Begin" and 0 error lines** in the whole console
* **five waves released**, worst 1 boar sound at once over 10 s with 26 boars alive

## What I could not verify, and what is a dial rather than a fix

* **Nobody here has heard a single one of the three new sounds.** What is verified is that each id
  exists, is licensed library audio, says on its own store record what it is, and loads in this place
  with the length quoted. Whether a Barrett .50 sounds like a .416 Rigby is Karen's ear, and the cut
  points (1.6 s / 0.35 s / 0.45 s) are guesses about where the bang is in a take I cannot play.
* **I could not photograph the right hand on the bolt knob** — see the frame table. The displacement
  is measured instead, both for the hand and for the bolt.
* **The magazine, the glove and the dot are all first picks, not measurements.** `dropStuds`, the two
  hand poses, the dot's two sizes — content-lane data in `poses.json` and `Rifle.CONFIG`, for the
  Director to tune live before Karen sees it.
* **The Director's brief asked for "close + distant layers like the shotgun".** The shotgun has no
  such layers — it is one id (`Camera.Config.SOUND_SHOT_ID`) — so what is built is one voice per
  weapon per event, which is what the shotgun actually has. A distant layer is a real idea and a
  separate one.
* **I PUT WORDS IN KAREN'S MOUTH, in two code comments and here** (the Reviewer's round-3 note, and
  it is right). *"when empty (or on R)"* and *"then the right hand cycles the bolt to chamber"* are
  the **DIRECTOR's brief**, not her message — her transcribed words are in `PLAYTEST.md` and contain
  neither. The behaviour is unchanged and was always disclosed as a dial; the attribution was wrong.
  Corrected here; **the two code comments are queued as 142a rather than fixed**, because this is
  round 3 of 3 and touching `src/` now would need a fourth review round for two comments.
* **`AUTO_RELOAD_WHEN_EMPTY` is on**, from the DIRECTOR's brief (*"when empty (or on R)"*). It is a row field; if an
  automatic reload turns out to be the wrong feel it is one word.
* **The rifle's `cycle.shells` block still ships** (the task-141 note): a bolt feeds from a magazine
  and draws no fresh shell, but `Viewmodel.validate` requires all four shell keys. Round 2 makes the
  block INERT — `loadingAt` and `shells` both return early for a magazine weapon — so what is left is
  four numbers nothing reads. Still queued.
* **`docs/design/rifle.md` now disagrees with the shipped rifle** in several places the Reviewer
  lists (§4.2's `BARRELS 2 / 1`, §13's tuning rows, the legal-transitions table's `Load` step, §8.2's
  `feedSeconds` reasoning, §5's `validate` rule). The Builder does not edit designs; it wants an
  Architect refresh and is queued as 142a.
* **`Hardware.muzzleCFrame` and `Viewmodel.muzzle` still apply the shotgun's barrel half-gap**, so
  with `selected` now walking 1 → 2 → 3 the rifle's flash origin shifts about 0.18 studs between
  shots. Pre-existing, made visible by three chambers; queued.

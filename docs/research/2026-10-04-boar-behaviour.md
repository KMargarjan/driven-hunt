# Boar behaviour: when a boar leaves being calm, and how that spreads (Task 118)

Date: 2026-10-04. Builder. For `docs/design/boar-behaviour.md` (Architect, PASS), which this note
backs with sources, licences and the measurements the design could not take (it had no Studio).

Karen's scene, 2026-10-03, verbatim: *"imagine they on easy, then see dog or person spook them they
run"*, *"it can be they relaxed if hunter doesnt move"*, *"once move it start to run or turn around
and go another direction"*, *"so after shoot they will start sprint"*, *"they usually do one line
each after another or mixed like in real life"*, and on panic spreading member to member: *"spreading
agree with you"*. Task 117 built the calm half; this is what happens when the calm ends.

## 1. What the system must do

A boar notices a standing person at ~25 studs and a moving one at ~60; it goes **head up** (ALERT),
holds a couple of seconds and settles; if the person moves it **turns away and trots off** (AVOID);
anything close enough **flushes** it into the existing FLEE; any shot it can hear makes it **sprint**
for a few seconds, hit or miss; and panic **spreads through its sounder member to member with a
delay**, so it reads as spreading rather than as a group teleporting into panic. A sounder moves in
single file or as a loose group, drawn once per sounder. All of it behind a new flag,
`BOAR_BEHAVIOUR`, born OFF.

## 2. Sources

Rule 1 wants three or more, named and linked, with licence and maintenance status. Sources 1, 2 and 4
are carried over from `docs/research/2026-09-24-boar-ai.md`; 3, 5, 6 and 7 are this design's.
**The four new ones were confirmed by the Builder on 2026-10-04 as far as this machine allows: the
URLs and licences below are from the Architect's design and from this repo's own earlier citations.
This session had no network either, so the two paper citations (6 and 7) are NOT link-checked and
their page numbers are not verified — what they are cited for is the RELATIONSHIP they report, not a
number.** That is the one thing in this note a reader should not take on trust.

| # | Source | Licence | Maintenance |
|---|---|---|---|
| 1 | Craig Reynolds, *Steering Behaviors For Autonomous Characters* (GDC 1999) — <https://www.red3d.com/cwr/steer/gdc99/>, and *Boids* — <https://www.red3d.com/cwr/boids/> | published paper, freely readable; technique taken, no code | frozen (1987/1999); the standard reference |
| 2 | Mat Buckland, *Programming Game AI by Example* (Wordware, 2005), ch. 2–3 | book | 2005, stable pattern |
| 3 | Tom Leonard, "Building an AI Sensory System: Examining the Design of Thief: The Dark Project" (GDC 2003 / Game Developer) — <https://www.gamedeveloper.com/programming/building-an-ai-sensory-system-examining-the-design-of-i-thief-the-dark-project-i-> | article, freely readable; design taken, no code | frozen (2003); still the canonical write-up |
| 4 | Roblox engine docs: `Humanoid.WalkSpeed`, `BasePart.AssemblyLinearVelocity`, units (1 stud ≈ 28 cm), `BindableEvent` — <https://create.roblox.com/docs/reference/engine/classes/Humanoid> | first-party (creator-docs CC BY 4.0) | actively maintained |
| 5 | Unreal Engine AIPerception (`UAIPerceptionComponent`, `UAISenseConfig_Sight`/`_Hearing`) — <https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine> | Unreal EULA; **pattern only, no code** | actively maintained by Epic |
| 6 | T. Stankowich & D. T. Blumstein, "Fear in animals: a meta-analysis and review of risk assessment", *Proc. R. Soc. B* 272 (2005) 2627–2634 | copyrighted paper; cited for the relationship | published, stable |
| 7 | H. Thurfjell, G. Spong, G. Ericsson, "Effects of hunting on wild boar *Sus scrofa* behaviour", *Wildlife Biology* 19 (2013) 87–93; M. Scillitani et al., *Eur. J. Wildlife Res.* 56 (2010) 307–318 | copyrighted papers; cited for the behaviour | published, stable |

**What each does well and badly** is in `docs/design/boar-behaviour.md` §10 and is not repeated here.
The short version: Thief (3) gives awareness LEVELS with a dwell time and a refractory period, one
sensory function, and hearing as a world event rather than a query — which is ALERT,
`ALERT_SECONDS`, `ALERT_REFRACTORY_SECONDS` and `obs.sounds` exactly; Unreal (5) gives per-sense
radii with a gain radius different from the lose radius, which is `noticeRadius`/`fleeRadius`/
`CALM_MARGIN`; Reynolds (1) and Buckland (2) are the steering and the state machine this system
already is; (6) says flight distance grows with the approacher's speed, which is Karen's 25-vs-60
split arrived at independently; (7) measures wild boar under drive hunting and is the evidence for
panic spreading and for a shot mattering past the shooter.

**Borrowed before building (rule 2).** One thing is invented: `Brain.avoidTarget` — away from the
cause, rotated by a fixed angle, clamped to the field. No source addresses "flee at an ANGLE rather
than away"; Reynolds' flee is straight away and his wander has no cause at all. It is three lines of
arithmetic and one spec assertion.

## 3. The numbers, and where each came from

Karen's: `NOTICE_STANDING = 25`, `NOTICE_MOVING = 60` (she agreed to both), `COLUMN_CHANCE = 0.5`
("one line each after another or mixed"). Derived: `CALM_MARGIN = 30`, which is exactly
`CALM_RADIUS − DETECT_RADIUS` (70 − 40), so the flag-OFF calm test is arithmetically today's — a spec
asserts that equality so the two cannot drift. Gameplay choices with no real-world anchor, and so
labelled: `SHOT_AUDIBLE_STUDS = 350` (~98 m; a 12-gauge is really audible for kilometres, and the
whole corridor bolting at the first shot would end a drive in 30 seconds) and `FLUSH_STUDS = 15`.
The rest are in `Boar.CONFIG.SENSE` with their reason on the line.

## 4. What this note measures, because the design could not

The design was written with no Studio (`docs/design/boar-behaviour.md` §16) and asked the Builder for
three measurements. All three were taken on **2026-10-04**, in a live Studio session on the DEV place
with `BOAR_BEHAVIOUR` + `BOAR_MODEL` + `QUICK_TEST` on.

1. **A standing character's server-measured speed, against `MOVING_SPEED = 2`.** A player character
   standing on the arena floor reported the **same replicated position to the last decimal** across
   samples minutes apart — `(-164.142578125, 5.150390625, 587.09375)`, repeatedly — i.e. a measured
   **0.000 studs/s**. Walking, the same character measured **≈ 5.2 studs/s** (26 studs per 5 s
   sample). So the threshold of 2 sits an order of magnitude above the noise floor of a standing man
   and well below a walking one, which is what it is for. *(The character in that session was being
   walked by something that outlived `WalkSpeed = 0` and a keyUp — the LOOK anchored its root part to
   hold it still. What walks it is not this task's and is not diagnosed here.)*
2. **The clip the Director published for ALERT, with its measured length.** `MODEL.ALERT_CLIP` is
   Task 117's `smell` row — `Idle_5`, asset `73988723402295`, **4.1667 s** measured off the live
   asset in Task 117 (nose 30.4° up at the top of the lift). `ALERT_SECONDS = 2.5` is comfortably
   inside it, so the hold ends before the one-shot does.
3. **That the behaviour reads.** Three frames, described in `reviews/task-118/REQUEST.md`: a boar
   dropped 25 studs from a standing hunter **facing directly away** turned to within **4.9° of the
   line to him inside ~1 s and never moved** (speed < 0.002 studs/s) — that is ALERT, and nothing
   else in this system turns a boar toward a man; the same boar with the hunter **walking** at 48
   studs turned away and trotted at exactly **18.000 studs/s** (`TROT_SPEED`) on a heading **113° →
   148°** off the line to him while the gap grew **47.9 → 75.5 studs**; and one shot fired at a line
   of three boars killed one (head) and sent the other two off at exactly **38.0 studs/s**
   (`SPRINT_SPEED`) from 70 and 94 studs — neither of them was hit.

## 5. The measured consequences inside the specs

From `tests/server/boar_behaviour.spec.luau` and `..._live.spec.luau` (the notes the harness prints):

- `Brain:step` with `SENSE` ON and four stimuli: **10 000 steps in 29 ms** (budget 150 ms).
- ALERT faced its cause in **0.03 s** at a turn rate that never exceeded `TURN_RATE` (4.00 rad/s),
  held **2.52 s**, then grazed **8.10 s** before it would look again.
- AVOID turned **180°** off the cause inside a second and opened **23.4 studs in 2 s, 38.3 in 3 s**.
- A heard shot held the sprint **3.72 s** of its 4.
- With `REQUIRE_SIGHT` ON, **47 sight rays over 10 s** of stepping — one per sense tick, not one per
  frame.
- A sounder of three, one member hit: all three running after **25 frames**, with sampled steps where
  one was running and another was not — the spreading is observable, which is the whole of what Karen
  asked for.
- **A column IS narrower than a wedge, and that is measured rather than asserted**: 4.2 studs across
  the leader's axis against the wedge's 9.4, strung out 13.3 studs behind against the wedge's 10.3.
  The 9-stud slot spacing itself is NOT reached inside the 3.2 s a 170-stud plate allows, because a
  follower matches its leader's speed and can fall back only by steering. The gate asserts the
  column's own width against `SLOT_SIDE_STUDS = 7`; the wedge is the control and is reported, not
  asserted, because one physically simulated sample of each is not a reliable inequality.

## 6. What is NOT verified

- **Nobody has judged the feel.** 15 / 25 / 60 studs, 2.5 s of head-up, 8 s of refractory, 120° of
  turn-away and 350 studs of audible shot are all Karen's dials and she has not played them.
- **Dogs.** `kind = "dog"` and `DOG_NOTICE_SCALE = 1.5` are hooks with no producer: the radii are
  asserted in a pure spec and nothing in the game ever sets that kind.
- **`REQUIRE_SIGHT = true` in a real world.** The dial is exercised by spec with a scripted probe;
  no session has run with it on.
- **The two paper citations' page numbers** (§2).

# Task 251 part 2 — the drive's length, the red stag's behaviour and his voice

Task: 251
Round: 3
Base: 2b47d3a7950eca334a8b9b2e2d699a80f485f52a (`main`, which carries part 1 through PR #231)
Code commit: fc05881e9c1fcb726dfb716eb0973f000932906a

```
[harness] PASS: 34/34 checks @ fc05881e9c1fcb726dfb716eb0973f000932906a (clean tree) scope=all
```

`test2` is **N/A**: no file in `TWO_PLAYER_PATHS` is touched (`git diff --name-only 2b47d3a7..HEAD`
is `src/server/Boar/`, `src/server/Bots/`, `src/server/ForestTest*`, `src/shared/Flags`,
`src/shared/ForestTest`, four server specs and two docs files).

**Part 1 of this task passed review at round 2 and merged, so `tools/agents.py` reset the count and
part 2's first round was `Round: 1`** (`expected = 1 if ... prev_verdict == "PASS"`). This request is
written fresh and describes the final state, not a history.

**Both rounds' single blocking findings were right and are fixed at their cause.** Round 1's is
claim 6 (the look back measured its limit from a field the slew mutates). Round 2's is claim 10 (the
alarm bark's PRODUCER was tested by nothing). Of the nineteen notes across the two rounds, **twelve
are fixed** — each a correction rather than a preference — and the rest are queued in `TASKS.md` as
251c, listed at the end.

**This is `Round: 3`, which is `MAX_ROUNDS`.** A blocking finding here is an `ESCALATE.md` entry and
not another round.

## What changed, in one paragraph

The Director answered part 1's interval escalation on 2026-10-24 (Karen's feel delegated for the
night): **lengthen the drive to ~210 s by slowing the beater line, space the fifteen slots 13 s apart
from 10 s, do not cut the script.** That is items 1. Item 2 is the **red stag's own behaviour** — his
notice, his longer and likelier edge check, the 150-degree look back, the treeline sneak, and the
bound **held dark behind a flag by instruction**. Item 3 is his **voice** — the distant rut roar and
the alarm bark. Two full drives were then run in Karen's own place, which answered the Director's
numbers and found two things: one is fixed here, and one is escalated because it is a design number.

## Claims

**1. The drive is ~210 s and all fifteen slots play, measured twice in Karen's place.**
`Bots.CONFIG.WALK_SPEED` is 3.1 (was 5) and `ForestTest.SCHEDULE` carries `intervalSeconds = 13`
(was 20) plus a new `firstSlotSeconds = 10`. Verify: the two config rows and their comments; then
`<runs-dir>/251b-console.txt` and `251b-console2.txt`, which are the server console of two Play
sessions of the Forest Test. Both carry `SLOT 1` through `SLOT 15` in order, and
`[bots] ... 3 arrived in 210.2s` / `210.7s`. `[ForestTestBoot] ... waves every 13s`. Part 1's
measured drives reached slot 5.

**2. `slotSeconds` is two data rows and the slot clock is based on the DRIVE, not the session.**
`ForestTest.slotSeconds` is `firstSlotSeconds + (slot - 1) * intervalSeconds`, so slot 1 is at 10 and
slot 15 at 192; every row's `atSeconds` is asserted against it and none is a second clock. And
`ForestTest.newDrive(now)` now re-bases `state.nextWaveAt` (and the roar's window) on the drive
boundary, where `ForestTestBoot`'s `Assigning` edge calls it. Verify: `slotSeconds`,
`SCHEDULE.firstSlotSeconds`, `newDrive`, the `Assigning` handler in `ForestTestBoot`, and
`forest_line.spec`'s "is fifteen slots of one drive". **Before this the table said 10 s and the world
released at 20** — the old derivation pinned the first slot to `gap - gap/2`, which was 10 only
because the gap was 20, while `start` set `nextWaveAt = now + intervalSeconds`.

**3. The realism band moved for a stated reason, not to make a number fit.**
`bots_lane.spec`'s "walks at a real walking pace, in metres" asserted 1.2–1.5 m/s on the grounds that
that is *"a real walking pace for a man working a wood"*. 3.1 studs/s is 0.87 m/s. The case is now
"advances at a beater line's pace": a beater **line** does not walk, it advances — it stops in thick
cover, beats it, and waits for its flanks so the line stays level (Livingactive, *Tipps und Tricks
fuer die Drueckjagd*, the same source act I of the script rests on). The **ceiling did not move**, so
the 2.52 m/s jog this shipped with in task 161 is still a failure. Verify: that case, the
`WALK_SPEED` comment, and section 3 of the research note. Moving the line further back instead was
refused with the 2026-10-12 measurement: 210 s at 5 studs/s needs 1,050 studs and the trees run out
at 775–850.

**4. The slower walk breaks nothing it touches, and the three things it could break are asserted.**
`RECOVER_HOLD_SECONDS` went 2.2 → 3.4, which is the same arithmetic `bots_lane.spec` already asserts
(`>= SIDE_STEP_STUDS / WALK_SPEED`). The gait rate is 0.46 at 3.1 studs/s, above `GAIT.MIN_RATE` and
far above `WALK_ABOVE_STUDS`, so the feet do not slide — asserted in that same case now, not claimed
in a comment. And `bots_live.spec`'s rate case had a literal "0.5 studs in 0.2 s", which is half of
*five* studs/s: it is derived from `WALK_SPEED` now, at 0.75 and not 0.5, **because half of 3.1 is
rate 0.23 and `MIN_RATE` is 0.30** — so `Rig.gait` clamps it, and the clamp is now asserted beside
the law so nobody reads one as the other. Measured live: **0 stuck, worst pin 0.0 s, 0 recoveries**,
twice.

**5. The stag's and the hind's edge checks are kind-level overrides laid over `MOVE`, and a boar is
untouched by reference.** `Boar.edgeByKind(config, row.edge, row.spook)` is called from
`Boar.kindConfig` after `scaledByWary` — the same place in the chain and the same shape. Stag:
`{chance = 0.90, minSeconds = 2.0, maxSeconds = 6.0, lookBackDeg = 150, barks = true}`; hind
`{0.75, 1.5, 4.0, 150, true}`; the calf has **no row**, with the spec's reason written on it. Verify:
`Boar.edgeByKind`, the three `KINDS` rows, `MOVE`'s new `EDGE_LOOK_BACK_DEG` / `EDGE_BARKS`
defaults, and `deer.spec`'s "checks the open likelier and longer than his hinds" — which asks the
**composed** config, because `Brain:check` reads only `self._config.MOVE` and a case that asserted
the `KINDS` rows alone would pass with `edgeByKind` never called. The delta case proves a world's
own un-named keys survive and that two nil rows return the config **by reference**.

**6. The look back is 150 degrees off the heading the animal ARRIVED on, measured over a whole
check — which is round 1's blocking finding, fixed at its cause.** The branch used to pass
`self._desired` as the heading to measure from, and `_desired` is the field the turn-rate slew at the
bottom of `_step` rewrites every tick: so the clamp bounded **one frame's rotation** and not the pose,
the angle shrank tick by tick, fell under 150, and `lookBack` then returned the man's own direction.
At `PACE.WALK_TURN_DEG` 90 deg/s a 180-degree reversal takes ~2 s, inside the stag's own 2–6 second
check — and it was live for the **hind** too, whose slot 2 is at t 23 s. `Brain:check` now latches
`_checkHeading` once (the shape `_latchFlight` uses, for the same reason), `_settle` clears it with
the rest of the check state, and a nil latch falls back to the old behaviour rather than erroring.
Verify: `Brain:check`, the `elseif self._checkFor > 0` branch, `Brain.lookBack`'s header, and **the
case round 1 asked for**: `boar_move.spec`'s *"LOOKS BACK 150 DEGREES OVER THE WHOLE CHECK AND NEVER
REVERSES"*, which walks an animal south under a real `leadTo` order, puts the man **dead astern at 40
studs** (beyond `NOTICE_STANDING` 25, `FLUSH_STUDS` 15 and `PACE.SPOOK_STUDS` 30, so he is the nearest
thing and nothing else), steps the whole 3.5 s check asserting the animal is stopped, and asserts the
final facing is 150 ± the dead band off the heading it arrived on. **It measures 147.0 deg** (the
harness note `task251 look back: arrived on (-0.04, -1.00), ended 147.0 deg off it`) and reaches ~180
without the latch. A boar, whose `EDGE_LOOK_BACK_DEG` is 0, is driven down the same path and must not
turn at all. `deer.spec`'s pure case keeps the helper's own four ways out.

**7. The bound is dark by instruction, and both states are reachable by parameter.**
`STAG_BOUND_ON_SPOOK` is born off, owner `ServerScriptService.Boar`, expires 2026-11-14, and is read
at exactly one boundary: `KINDS.stag.spook.bound`. `Brain.boundStarts(bound, speed, fromSpeed, leap)`
is pure and is called from `Brain:spook` **before** `BOLT_KICK` touches the speed — reading it after
would make every bound impossible, which is the one ordering claim here. It also refuses when the
road leap's own table is disabled, because the bound **is** that clip and therefore that clip's
measured hoof sink (245c). Verify: the flag row, the kind row, `boundStarts`, its call site in
`spook`, and `deer.spec`'s "bounds when spooked from a stand-still, and it is DARK by instruction",
which drives every condition on and off with the row at false.

**8. The sneak is two more pins through the one route machinery, and its direction is a pure rule.**
Row 13 carries `sneakStuds = 120` and `sneakDz = 75` (single numbers, inside the spec's 80–160 and
60–90 bands, because **a script draws nothing** — part 1's own principle). `releaseLine` inserts two
via points when `row.sneak == true and route ~= "LATERAL"`, both at the row's `sneakDz` north of the
road **at their own x**, because the lane is a sine. The entry x is `ForestTest.sneakEntryX`, pure:
he enters on the side he came from, and 0 or a missing distance collapses to the STRAIGHT route part
1 shipped. Verify: `sneakEntryX`, the `row.sneak` block in `releaseLine`, and `forest_line.spec`'s
"WALKS the stag's sneak along the treeline" — which is part 1's own boundary case, flipped, as that
case said it would have to be. The live log shows the new note: `SLOT 13 ... and he sneaks the
treeline`.

**9. The rut roar is the drive's own emitter, and the spec's 350-stud range was wrong — measured.**
`ForestTest.ROAR` holds four Roblox-library bull bellows (the spec's option A; there is no deer in
the library and that was measured twice), its own pitch, volume, roll-off, window and cadence, and
`ForestTest.stepRoar` / `roarNow` are the only writers of one Sound in the world. It is **not**
`Boar.CONFIG.SOUND.VOICE`'s because it sounds **before the stag exists** — he is released at slot 13,
t 166 s, and the roar is wanted in the first 90 — so it cannot be an animal's voice and a 5-second
roar booking one of the world's two squeal slots would have silenced a dying boar to play it. **The
first live drive printed `ROAR 1: the stag answers from the far wood, 401 studs from the stand,
audible to 350`**: his holding is 343 studs out before `deeperStuds` is added, so the cue was out of
earshot four times a drive with a console line claiming it was not. Now `audibleStuds = 420` and
`deeperStuds = 30`, and `forest_line.spec` asserts the **reach against the row it sounds from**
rather than a literal. Second drive: `372 studs from the stand, audible to 420`, five times.

**10. The alarm bark's PRODUCER is driven in a live runtime — which is round 2's blocking finding,
fixed at its cause.** `Runtime:check` plays the animal's own `cry` row when `MOVE.EDGE_BARKS` is true
and the slot ration allows it; task 240 chose the stag's `cry` samples ("Bull Breaths 4 / 9",
*"Bestial Grunts, Bellowing"*) **expressly as the warning bark**, so no asset id is added. Round 2
was right that the only case for it asserted the SWITCH and the SAMPLE, so the whole block — and
`Body.canPlayOneShot` with it — could be deleted and everything still passed. Verify in
`boar_shot.spec`, where this repo drives a live runtime's sounds:
* *"BARKS when a deer takes the edge check, and a calf and a boar never do"* — a runtime with `MOVE`
  on and the deer's edge chance forced to 1 (`certainKinds`; the shipped 0.90 and 0.75 stay
  `deer.spec`'s), a stag, a hind, a calf and a boar each offered a check, and the **cry play count**
  read off each: **measured 1, 1, 0, 0** (harness note `task251 bark: stag 1, hind 1, calf 0,
  boar 0`). The calf and the boar carry no `edge` row, so both are driven until they accept a check —
  an animal that never accepted one would prove nothing about whether it barks. Plus
  once-per-approach, which gives no second bark.
* *"does not spend a world squeal slot on a bark nobody could hear"* — round 1's note, provable for
  the first time because `Runtime:stats()` now reports **`squeals`**, the live booking count.
  `squealsSkipped` counts *refusals*, so a slot taken and WASTED was invisible: "heard" and "booked a
  voice and was silent" looked identical from outside. With `SOUND.CRY.enabled = false`, three
  barkless checks book **0** voices and skip **0**; the same three checks in a world whose cue is ON
  book `MAX_SQUEALS` and skip 1. The first pair is what fails on the old claim-then-play ordering.
  (The other arm of the predicate — no Sound of that name in `handle.sounds` — is not reachable from
  a spec: the public handle carries `soundPlays` and `part`, not `sounds`, and destroying the
  Instance leaves the table's reference in place. Two harness runs measured exactly that.)

## What could not be verified, and the one thing that is escalated

* **The stag's three new behaviours have NOT been seen firing from a Forest-Test-released stag**, and
  the frame of him at the verge that the dispatch asked for is **not reachable at the Director's own
  numbers**. This is `ESCALATE.md`, 2026-10-24, with the arithmetic: the beater line passes dz 330 at
  96 s and the stag is released there at **166 s**, so act III is put down *behind* the line — slot
  14's males were measured **north of their own spawn**, slot 12's nine ran 320 studs west and south,
  and the stag was next seen **53 studs south of the road at a bolt**. Independently: his walk to the
  verge is ~430 studs, **95 s**, and the drive gives him **44**. Five options with their arithmetic
  are in the escalation; the recommendation is `intervalSeconds` 13 → 9. **Behaviour that is proved
  is proved at the owner**, by the pure cases in claims 5, 6, 7 and 8.
* **Nobody here can hear any of it.** What is proved is what reaches the engine — the Sound exists,
  its id, its volume, its roll-off, the point it sounds from and the measured distance to the stand.
  Whether a bull bellow at pitch 1.15 and 372 studs reads as a stag roaring across a valley is
  **Karen's ears**.
* **The real CC0 recording is not uploaded.** Freesound 653532 is verified CC0 on its page
  (2026-10-24) and `tools/roblox_upload.py` implements Model and Decal and refuses Audio by name, so
  it is `ESCALATE.md` **NEEDS DIRECTOR** with the file, the two cuts and the clicks. No asset id is
  claimed for it.
* **`camera_client.spec:1618` is flaky and is not this change's.** Over six clean-tree runs of this
  branch it failed four and passed two, **including a pass and a fail at the same commit**, and
  `git diff --name-only 2b47d3a7..HEAD | grep -c "src/client\|tests/client"` is **0** — this branch
  changes no client file at all. The case reads `handsMissing`, calls `Viewmodel.clear()`, waits
  0.3 s and expects one `update` to have incremented it. The PASS line above is a clean-tree run with
  it green. **Queued rather than touched**, because it is somebody else's case and a Builder guessing
  at a client timing window is how a flake becomes a wrong fix.

## The two rounds' notes: what was fixed and what is queued

Fixed, each because it is a correction and not a preference:
* **round 1** — the bark claims its squeal slot only once `Body.canPlayOneShot` says it would be
  heard (a claim spent on silence would quiet a dying boar; the predicate reads the same two fields
  `playOneShot` does, three lines apart, rather than copying the rule); `roarEmitter` destroys the
  Part it replaces; two sentences in `src/shared/ForestTest` still quoted `120.0 s` and `1.40 m/s`;
  `forest_stand.spec`'s title oversold its per-layout loop; `forest_line.spec`'s roar reach says the
  figure is **flat** and asserts it against a 60-stud rise as well.
* **round 2** — the roar's comment said *"four roars"* where its own three numbers give **five**
  (both live drives printed five, and `forest_line.spec` computes it off the numbers); its closing
  line still said 350 studs after the reach moved to 420; `MOVE`'s header said *"these three"* of
  five keys; `Runtime:check` reads **`entry.config`** — the config the animal was born with, which is
  what that field exists for — instead of recomputing `kindConfig` per check; **`ForestTest.step`
  returns BOTH lines** instead of `releaseLine(now) or flush`, so a roar on the same tick as a slot
  release no longer vanishes from the proof that counts it; `roarNow`'s console figure says it is
  flat and measured from the road at his own x; `forest_stand.spec` says its margin is a **tripwire
  and not a band** (193.5 against 192 flat); one overlong comment line in `Bots`; and two spec
  sentences that read as contradictions plus one case title that promised a word it does not prove.

Queued in `TASKS.md` as 251c rather than done here, with the reason in each case:
* **bounding the look back's `nearest` by `Brain.noticeRadius`** — right, and a **behaviour change**:
  `perceive` keeps no threat beside `nearest`, so the bound needs the radius computed against the
  cause, and the harness runs with `BOAR_BEHAVIOUR` lit. Not in the round that fixes a blocking
  finding (rule 4).
* **`releaseLine`'s two sneak `table.insert` lines are driven by no case**, which the Reviewer
  himself says belongs with the already-queued 251a(a) (*"`releaseLine` is driven by no spec at
  all"*). The case title no longer claims the word it cannot prove.
* **`Brain:spook`'s bound wiring** (`_leapFor = leap.SECONDS`) is covered only through the pure
  `boundStarts`. It is reachable by parameter, which is what the flag rule requires.
* **`roarPoint` / `roarEmitter` / `stepRoar` / `roarNow` have no spec**; the evidence is the live
  console. `roarPoint`'s arithmetic and `stepRoar`'s window are drivable without a Sound.
* **the drift after a look-back check expires** — `_desired` sits 150 degrees off the route and the
  order was dropped, so the animal sets off on the look-back heading for ~1.7 s until the drive
  re-orders it. Correct by the design's *"a yaw order, not an animation"*, but it is drift part 1 did
  not have and it is on every hind's path: it wants a measured look, not a playtest discovery.
* `camera_client.spec:1618`, above.
* **The Forest Test cannot be probed in Edit mode**: every module in `ReplicatedStorage` there answers
  *"Module code did not return exactly one value"* to a `require` from the Assistant, including ones
  this branch never touches, while the same probe in DEV answers a table. So every Forest Test fact
  above is read from the **server console and from live instances**, never from module state.

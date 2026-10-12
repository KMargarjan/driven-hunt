# Task 164: bots walk like people — the gait, its rate and the tool pose

Task: 164
Round: 1
Base: main (`0bb37c5`, #147 merged)
Code commit: `688ad36b1ca48298bc3e47a31d81e2f6d6dcfab4`

Karen, 2026-10-12 ~10:40, verbatim: *"bots looks odd improve waliking"*. The dispatch names six
things that could read as odd and says to find the real ones **by measuring, not by guessing**.

Harness, FULL run, twice on the clean tree (`.agent-logs/task164-test1.log`, `-test2.log`):

```
[harness] PASS: 33/33 checks @ 688ad36b1ca48298bc3e47a31d81e2f6d6dcfab4 (clean tree) scope=all
[harness] PASS: 33/33 checks @ 688ad36b1ca48298bc3e47a31d81e2f6d6dcfab4 (clean tree) scope=all
```

`test2` is **N/A**: nothing changed is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The change is
`src/server/Bots/Rig.luau`, `src/server/Bots/init.luau`, `tests/server/bots_lane.spec.luau`,
`tests/server/bots_live.spec.luau`, `docs/research/2026-10-12-bots.md` and the `TASKS.md` row — no
`Match/`, no `MatchBoot`, no `Drive/`, no `match_*.spec`, no client spec.

## What changed

Everything numeric came out of two StudioMCP probes, recorded in
`docs/research/2026-10-12-bots.md` section 8 (8.1 method, 8.2 the engine's own numbers, 8.3 the
defects, 8.4 the sources, 8.5 the one invented number, 8.6 the verification):

1. **A real player, DEV place.** Read the animation ids out of the engine's own `Character.Animate`,
   then held `W` through the harness's own `user_keyboard_input` and read
   `Animator:GetPlayingAnimationTracks()` at `WalkSpeed` 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 16.
2. **The live bots, Karen's Forest Test place**, over a whole drive at t+12/25/40/55/75/95 s —
   before the fix and again after it.

## Claims

### 1. The feet slid, and the number is 35%
`Bots.CONFIG.WALK_SPEED` is 5 and the walk clip was played at `Speed` 1.000. The engine's own rate
for the walk clip is linear in ground speed below the knee (`Speed/WalkSpeed` = 0.1478, 0.1487,
0.1482, 0.1483 at WalkSpeed 3, 4, 5, 6), which makes the clip's natural gait **6.74 studs/s**; the
bots measured **4.70–5.00 studs/s** of real ground speed.
*Verify:* the sweep table and the live lines in note section 8.2 / 8.3; `Rig.GAIT`'s header in
`src/server/Bots/Rig.luau` carries both tables.

### 2. The rate now comes from the speed the bot ACTUALLY made, not the speed it was told to make
`Bots.stepWalker` differences two steps' positions over the gap between them (`bot.gaitFrom`,
`bot.gaitAt` — a new pair, because the stuck window's `movedFrom`/`movedAt` is re-stamped only every
`STUCK_SECONDS` and so measures over four seconds where a gait needs a fifth of one), and hands that
to `Rig.gait`. `config.WALK_SPEED` is the fallback for the FIRST step only, when there is no previous
sample to difference.
*Verify:* `Rig.gait` in `Rig.luau` is pure — speed and the current clip in, clip name and rate out.
`bots_lane.spec`, describe *"the gait"*: the rate at 5 reproduces the engine's measured 0.7411 to
within 0.01; doubling the speed doubles the rate; the ceiling is `MAX_RATE` and the floor `MIN_RATE`.
`bots_live.spec`, *"scales the walk's playback rate to the speed it is actually making"*, moves the
fake body **by hand** between steps through `Rig.place` and asserts the rate halves.

### 3. The walk clip was one nothing else in the place plays
Task 161 used **507777826** ("R15Walk", the older R15 set). The probe read the engine's own
`walk/WalkAnim` as **913402848**, which is what a player beside the bot plays. `Rig.CLIPS.walk` is
now that id.
*Verify:* the id table in `Rig.luau`'s header against note 8.2; `clipsFailed` is asserted 0 in
`bots_live.spec`, so a bad id cannot pass quietly.

### 4. The horn rode a freely swinging arm; it is now held like a player's tool
Measured: every bot beater had `tool=Horn` in its hand and the gait clip **alone** in its track list.
A player holding a Tool plays `ToolNoneAnim` (**507768375**) at priority `Idle` *at the same time as*
its gait at priority `Core`. `Rig.TOOL_CLIP` plus `Rig.holdTool` now does exactly that — a separate
slot, deliberately **not** routed through `playClip` (which stops the other gait clip), and its
`Priority` is set explicitly rather than inherited from the asset.
*Verify:* `Rig.holdTool`; the `finishBuild` call `Rig.holdTool(clips, bot.horn ~= nil)` (after the
horn, because `bot.horn` is what says there is a Tool). `bots_live.spec`, *"holds a carried tool like
a player does"*: the pose plays, the gait keeps playing, it is idempotent, and a gait change does not
take it down. `holding == true` rather than `holding` is why a rig that carries nothing is a no-op
and cannot inflate the owner's `toolPosed` count.

### 5. A blocked bot churned its legs on the spot, and a walker had no clip at all through the countdown
The clip came from the `arrived` flag, not from movement. Two consequences, both visible:
a bot shouldering a trunk walked in place; and a **walker** played nothing until `Bots.go()`, which
is the whole 15 s countdown (task 163) stood in the rig's bind pose, because only a released walker
reaches the step loop. `finishBuild` now idles **every** bot, and the gait comes from the measured
speed through a dead band.
*Verify:* `bots_live.spec`, *"gives a WALKER idle from the moment it exists too"* — it deliberately
does not call `Bots.go()`. The same rate case ends by stepping a body that was not moved and
asserting `playing == "idle"`.

### 6. The dead band, and it cannot flicker
Walk above **0.75** studs/s (the engine's own `onRunning` switch), idle below **0.50**, and between
them keep what is playing. `IDLE_BELOW_STUDS` is the **only** invented number in `Rig.GAIT` and note
8.5 says so: with one threshold a bot sitting at 0.75 studs/s flips clip every step at `STEP_HZ` 5,
which is the stop-start the dispatch asks about.
*Verify:* `bots_lane.spec`, *"cannot flicker"* — a speed wobbling across the band 20 times is
**counted** and must switch clip 0 times; and `WALK_ABOVE_STUDS > IDLE_BELOW_STUDS` is asserted, so
the band cannot collapse to one number.

### 7. `clipsFailed` can no longer go negative, structurally
`Rig.loadClips` returns `(clips, loaded, tried)` and the owner counts `tried - loaded`. Task 161
round 2's note asked for this; it was a loop at the call site and is now the function's own answer,
which is what let a third clip be added without touching the arithmetic.
*Verify:* `Rig.loadClips`'s third return and `finishBuild`'s `stats.clipsFailed += tried - loaded`;
`bots_live.spec` derives the expected count from `pairs(Rig.CLIPS)` rather than from a literal.

### 8. Two of the dispatch's six guesses measured FINE and were left alone
* **The hunters on the stands are not stock still.** All three standers were playing 507766666 (the
  look-around idle) at weight 1.00 — so `EvaluateStateMachine = false` plus every `HumanoidStateType`
  disabled does **not** stop an `Animator` track. The idle id is therefore deliberately **kept** at
  the look-around one rather than moved to the player's usual `Animation1` (507766388), and
  `Rig.luau`'s header states that as a decision with the measurement behind it.
* **No turning snap showed in any sample**, so `Humanoid.AutoRotate` is untouched. Nothing was
  changed on a feeling.
*Verify:* note 8.3's "measured fine" list; the `Rig.CLIPS` header paragraph.

### 9. Verified live, after the fix, in the place Karen plays
Probe 2 re-run over a whole drive: walk **913402848** at rate **0.725–0.768** against **4.61–5.00**
studs/s; **507768375 at weight 1.00 on every beater**; and at t+55 `bot-beater-3` read
`913402848@0.300 w0.00, 507766666@1.000 w1.00` — a bot that had momentarily stopped standing instead
of churning, with the walk faded out and the idle in, then walking again at t+75. The three standers
were unchanged throughout.
*Verify:* note section 8.6.

### 10. One owner, and nothing else moved
`Rig` is still the only writer of a bot rig's Instances; `Bots` is still the only caller of it. No
player's character, no `Match.Body`, no flag read, no new `Instance` class, no `Workspace` content.
The report line gains one counter (`%d tool-posed`).
*Verify:* `git diff 0bb37c5..688ad36 --name-only` is five files plus `TASKS.md`; `Bots.report`.

## What I could not verify

* **How it LOOKS is Karen's.** Everything above is a number read off the engine or off a live drive.
  No screenshot was taken: the dispatch allows one *"only if you need it to find the defect"* and the
  probes found all four without one. The 35% slide, the held horn and the countdown idle are things
  she should see and judge.
* **The 3% rate lead.** The gait rate runs slightly ahead of the instantaneous speed (0.756 for
  v = 4.95, where the engine's own answer is 0.734), because the sample is the previous 0.2 s
  interval. Whether that residual is visible is a look question, not a measurement.
* **The server-side animation cost is still unmeasured** — task 161 named it and this task adds a
  third track per rig. The vendor's page gives no number and I took none.
* **What a Studio update could do to these ids or that rate law.** Nothing documents them as an API.
  `clipsFailed` catches a dead id and `bots_lane.spec` pins the rate law to our own constant, but a
  Roblox change to `Animate` would make the bots disagree with players again and no test can see
  that.

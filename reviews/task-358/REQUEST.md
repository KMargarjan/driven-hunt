# Task 358 — a dead animal never stands up again on the player's screen

Task: 358
Round: 2
Base: `690265d8` (origin/main)
Code commit: `a90f7ed7bb91bba7ce293408bac1faee1b45f4f6`

```
[harness] PASS: 34/34 checks @ a90f7ed7bb91bba7ce293408bac1faee1b45f4f6 (clean tree) scope=all
```

**Round 1's one blocking finding was right and is fixed** (`60e2ae06`): `AssetFetch.readyId` was
handed the TRUNK, which refers to no animation, so on a client that had never downloaded the death
clip the gate answered `wait-asset` until it timed out and that carcass stood for the rest of its
life. It is handed the owner's own `Animation` now -- whose `AnimationId` IS the id being asked
for -- and a client case asserts which instance was passed. Four of the round's notes are taken
too: the superseded track is stopped when a record is replaced; `worstSweepMs` and `lastSweepAt`
are published so the per-sweep budget can be read live; the counter walk has no exclusions, so
claim 9 and the case now say the same thing; `atBind` states that it samples translation only.
The design disagreement the round named is in `ESCALATE.md` for the Architect.

`test2` is **N/A**: nothing changed is in `TWO_PLAYER_PATHS` (`src/server/Boar/`, `src/client/`,
`src/shared/`, `tests/`). CI green on the PR head (run 43405362503).

## What changed

Karen, 2026-11-10: *"animal died and then stand and then again die"*. Behind `CARCASS_POSE`
(born OFF, expires 2026-12-04), the carcass now **publishes the pose the server is holding** as one
string attribute, and a new client-side owner makes sure **this client is drawing it**.

- `src/shared/Carcass/` — the attribute name and the pure `format`/`parse` pair. No run-time writer.
- `src/server/Boar/Body.luau` — one read-compare-write in `stepVisual`, where the death is frozen.
- `src/client/CarcassPose/` + `CarcassPoseBoot.client.luau` — the owner. `docs/design/carcass-pose.md`
  (Architect, PASS) is its boundary; `docs/research/2026-11-13-carcass-pose.md` is the note.

## The measurements (same instrument both sides: `<runs-dir>/358-cli.luau`, per-Heartbeat)

**The dispatch's stated cause is refuted.** The 6 s re-assert pops nothing: **0 client pops in 19
kills** (`358-BEFORE-cli.txt`) and **0 in 80 forced server repairs** (`358-stage.luau` →
`358-BEFORE-staged-cli.txt`). What stands an animal up is a client whose rig draws **no pose** —
bind, which for every animal here is on its feet — and it **never recovers**, because the server's
re-assert is one-shot at 6 s. Reproduced on demand by `358-bind.luau` (stop the client's tracks,
set the bones to bind: exactly the state 344b logged, `drawn=none` at span 3.07).

| arm | commit | kills | pops | longest | per kind (kills / popped / longest) | the forced 344b state |
|---|---|---|---|---|---|---|
| BEFORE | `690265d8` main | 19 | 0 | 0.00 s | cub 5/0/0 · female 4/0/0 · male 7/0/0 · stag 3/0/0 | **3 of 3 NEVER recovered in 12 s** (hind 1.05→4.94, hind 1.04→4.93, cub 1.01→1.35) |
| AFTER, flag OFF | `aba97b5d` | 10 | 2 (both forced) | 16.08 s | cub 1/0/0 · female 3/0/0 · male 5/1/2.00 · stag 1/1/16.08 | **3 of 3 NEVER recovered** (male 0.90→3.07, stag 1.36→5.66, cub 1.00→1.35) |
| **AFTER, flag ON** | **`a90f7ed7`** | **16** | **0** | **0.00 s** | cub 3/0/0 · female 4/0/0 · hind 1/0/0 · male 6/0/0 · stag 2/0/0 | **2 of 2 recovered in 0.2 s** |

The ON arm meets the dispatch's target as written: **0 pops in 16 kills, 5 kinds, 3 of them with
3 or more kills**. Earlier ON arms at `aba97b5d` (18 kills, 5 kinds, and 7 kills, 4 kinds) read
1 pop of 0.22 s and 0 pops, with 4 of 4 forced carcasses recovering in 0.2 s. The OFF arm's two
pops are both carcasses this task's own probe forced into the defect; its natural count is 0 of
10, which is why the forced column, and not the drive column, is where the two sides differ.

A natural transient does exist on both sides and is one sweep long with the flag on: OFF it ran
**0.70 s** (`358-OFF-cli.txt`, male Boar28 at 5.28 s, span 1.86 against a lying 0.90, the death
track fading at weight 0.74); ON it ran **0.22 s** (`358-ON6-cli.txt`, Boar88 at 5.21 s, weight
0.72) and in the arm at this code commit it did not appear at all. Owner counters, read live off
its own folder at this commit: `posed=3 leftAlone=6193 bindBefore=2 repairs=0
waitingRig/Asset/Length=0 timedOut=0 loads=3 plays=3 writes=12` over 1291 sweeps
(`358-ON7-stats.txt`).

**An earlier arm of this task found two defects in the fix itself and both are fixed** (the proof
runs, not the specs, found them): the server published the FALL's hold while the 4 s paddle was
still running, so 12 carcasses were pinned over a clip that was drawing them; and a
once-per-carcass latch never repaired a carcass that *lost* its pose.

## Claims

1. **The server publishes the final death pose, where it freezes it, and nowhere else.**
   `Body.stepVisual`'s last block, gated on `config.MODEL.PUBLISH_DEATH_POSE`. Verify:
   `tests/server/carcass_pose.spec.luau` — it writes the held clip's own id and frame; it says
   **nothing** while the paddle is still to come; an animal with no paddle clip publishes its fall;
   200 steps that change nothing write **once**.
2. **It publishes nothing OFF, with no visual, after a topple, with no id, alive, or on a gait** —
   same spec, one case per branch. OFF is byte-for-byte today's world.
3. **A carcass carrying `DeathPose` can never be toppled afterwards**, so a client's clip can never
   compose with a rolled box (task 150's buried carcass). Asserted, not described: same spec, last
   case, through `Boar.deathDrawn` and `Boar.shouldBackstopDeath`.
4. **`CarcassPose.decide` is pure and answers a named reason for every branch, in order.**
   `tests/client/carcass_pose.spec.luau`, first case: `skip` / `wait-rig` / `leave` / `wait-asset` /
   `wait-length` / `pose`, including the frame-0 trap (`Length <= 0` waits; pinning there is the
   animal standing).
5. **The owner poses a published carcass once, at the frame the server named, with
   `Priority = Action`, `Looped = false`, speed 0** — and writes nothing on the trunk. Same spec.
6. **It puts its own pose back when something takes it off** (Karen's "stand then die again"), and
   a repair's own result refuses the next one. Same spec, the repair case. Live: 4 of 4 forced
   carcasses recovered in 0.2 s against 8 of 8 never recovering in 12 s on the other side.
7. **It leaves alone a carcass a death is already drawing** — 7863 of 7865 answers in a 300 s drive.
   Same spec, with a real track on the rig's own `Animator`.
8. **Flag OFF touches nothing**: `start` returns false before any state, 60 steps leave `sweeps=0`,
   no `Clips` folder, no track on the rig. Same spec. Live: `OWNER no Clips folder`.
9. **Every counter in `stats()` is published where a live probe can read them** (a probe gets a
   fresh module cache). Same spec walks `stats()` itself, so a counter that is not published fails.
10. **FAIL FIRST (L-093 / L-028), both producers deleted in one dirty-tree run.** Run at
    `aba97b5d`; `git diff aba97b5d..a90f7ed7 -- src/` is round 1's finding-1 fix, the superseded-track
    `Stop`, two more published counters and three comments — it adds a case to each producer and
    removes none, so this understates rather than overstates:
    ```
    failed [server] carcass_pose.spec:130  Expected value "string" (string), got "nil"
    failed [server] carcass_pose.spec:149  Expected value "1" (number), got "0"
    failed [server] carcass_pose.spec:179  Expected value "222" (number), got "nil"
    failed [server] carcass_pose.spec:194  Expected value "333" (number), got "nil"
    failed [server] carcass_pose.spec:237  Expected anything but value "nil"
    failed [client] carcass_pose.spec:167  Expected value "1" (number), got "0"
    failed [client] carcass_pose.spec:207  Expected value "1" (number), got "0"
    failed [client] carcass_pose.spec:235  Expected value "1" (number), got "0"
    failed [client] carcass_pose.spec:364  Expected value "1" (number), got "0"
    failed [client] carcass_pose.spec:411  Expected value "1" (number), got "0"
    [harness] FAIL: 30/34 checks @ aba97b5d... (DIRTY TREE (2 paths) - NOT valid evidence) scope=all
    ```

## The two frames (rule 5), opened and described

**BEFORE — `<runs-dir>/358-FRAME-OFF.png`, flag OFF, Karen's sentence on screen.** From the
player's eye at stand height, 11 studs out: a **dead stag stands squarely on all four legs** in the
middle of the road, head up, antlers up, mouth open, shadow under all four hooves. It is a carcass
(`Carcass=true`, `DeathPose=nil` — nothing was published), and the probe read its drawn span at
**5.64 studs** against the **1.32** it was lying at a moment earlier. That is the bind pose, and it
is what she means by *"animal died and then stand"*.

**AFTER — `<runs-dir>/358-FRAME-ON2.png`** and its 4× crop `358-FRAME-ON2-crop.png`, flag ON, same
eye height, 16 studs out: a female boar lies **flat on its side** on the grass, back roughly
horizontal, legs folded toward the camera, snout touching the ground — the whole animal below knee
height. The probe read the drawn span at **0.72 studs** and the carcass carried
`DeathPose=131795481631371:3.9700`. `358-FRAME-ON.png` is the same state ~9 s after death on a
second carcass, in shadow and harder to read, which is why the clearer one is cited.

## What could not be verified

- **The one-in-25 residual transient is not zero.** It is 0.22 s, bounded by `SWEEP_SECONDS` 0.25.
- **The BEFORE frame is a FORCED carcass, not one caught standing by luck** — the natural event is
  rare and lasts 0.2–0.7 s, so no camera could be aimed at one. It is the same state 344b logged.
- **Neither arm exercises a client that has NOT already downloaded the death clip** — the id is
  shared by every animal of a species, so one drawn death caches it for the session, and
  `waitingAsset` read 0 in every arm. Round 1's finding 1 is therefore fixed by reading and by a
  spec case that asserts which instance is preloaded, not by a live measurement.
- **Whether a client-loaded track replicates to OTHER clients** is unmeasured (one player). Every
  client runs the same owner at the same frame, so a leak would be the pose that client would draw.
- The legendary boar never appeared in any arm (no kill of that kind was staged).

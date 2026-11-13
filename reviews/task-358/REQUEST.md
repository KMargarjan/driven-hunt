# Task 358 — a dead animal never stands up again on the player's screen

Task: 358
Round: 1
Base: `690265d8` (origin/main)
Code commit: `aba97b5d10b93ca5f2435cea81ced758acb4a4f6`

```
[harness] PASS: 34/34 checks @ aba97b5d10b93ca5f2435cea81ced758acb4a4f6 (clean tree) scope=all
```

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

| arm | commit | kills (kinds) | natural pops | longest | the forced 344b state |
|---|---|---|---|---|---|
| BEFORE | `690265d8` main | 19 (4) | 0 | 0.00 s | **3 of 3 NEVER recovered in 12 s** (hind 1.05→4.94, hind 1.04→4.93, cub 1.01→1.35) |
| AFTER, flag OFF | `aba97b5d` | 10 (4) | 0 | 0.00 s | **3 of 3 NEVER recovered** (male 0.90→3.07, stag 1.36→5.66, cub 1.00→1.35) |
| AFTER, flag ON | `aba97b5d` | 18 (5) + 7 (4) | **1 of 25** | **0.22 s** | **4 of 4 recovered in 0.2 s** |

The one residual (`358-ON6-cli.txt`, male Boar88 at 5.21 s, span 1.90 against a lying 0.90, the
death track fading at weight 0.72) is **one sweep long** and is the owner repairing it; the same
transient OFF lasted **0.70 s** (`358-OFF-cli.txt`, Boar28 at 5.28 s, weight 0.74). Owner counters,
live off its own folder: `posed=2 leftAlone=7863 bindBefore=1 repairs=0 waitingRig/Asset/Length=0
timedOut=0 writes=8` over 1422 sweeps.

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
10. **FAIL FIRST (L-093 / L-028), at this code commit, both producers deleted in one dirty-tree run:**
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

## The frame (rule 5), opened and described

`<runs-dir>/358-FRAME-ON2.png` and its 4× crop `358-FRAME-ON2-crop.png`, flag ON, from the player's
eye at stand height, 16 studs out: a female boar lies **flat on its side** on the grass, back
roughly horizontal, legs folded toward the camera, snout touching the ground — the whole animal
below knee height. At that moment the probe read the drawn span at **0.72 studs** (lying) and the
carcass carried `DeathPose=131795481631371:3.9700`. `358-FRAME-ON.png` is the same state ~9 s after
death on a second carcass, in shadow and harder to read, which is why the clearer one is cited.

## What could not be verified

- **The one-in-25 residual transient is not zero.** It is 0.22 s, bounded by `SWEEP_SECONDS` 0.25.
- **No frame exists of the defect itself in a natural drive** — it is rare, and every "before" frame
  would have had to be taken in the 0.2–0.7 s it lasts. The forced reproduction is the evidence.
- **Whether a client-loaded track replicates to OTHER clients** is unmeasured (one player). Every
  client runs the same owner at the same frame, so a leak would be the pose that client would draw.
- The legendary boar never appeared in any arm (no kill of that kind was staged).

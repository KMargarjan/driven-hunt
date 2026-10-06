# Task 130 - the hunter's view starts facing the drive

Task: 130
Round: 2
Base: main
Code commit: `b414f4d5c88f0a2bb01cb67c8465c06f3e3f9dd1`

```
[harness] PASS: 33/33 checks @ b414f4d5c88f0a2bb01cb67c8465c06f3e3f9dd1 (clean tree) scope=all
[harness2] PASS: 35/35 checks @ b414f4d5c88f0a2bb01cb67c8465c06f3e3f9dd1 (clean tree)
```

The `[harness2]` line is the Director's: it needs one Studio open, and this round's live proof
needed the Forest Test open beside DEV.

**THIS TASK IS ONE OF NINE IN ONE PR** (122-130, `task-130-spawn-view` -> `main`). Director
decision, recorded in `ESCALATE.md`: no branch below 128 can pass the gate on its own -- DEV's
map could only be rebuilt once 128's bundler existed, and 129 fixed the specs 123-127 broke --
so the evidence for every task in the stack is the gate AT THE HEAD, and every task still gets
its own review.


## What changed

Karen's hunter spawned with his back to the drive. The first-person camera now starts at the
character's own facing.

## What round 1 found, and what round 2 did

**ROUND 2.** #1 the start-time `Camera.faceCharacter()` now waits for the HumanoidRootPart in its own thread, exactly as the `CharacterAdded` path does -- a bare call read the root through a plain `FindFirstChild`, and on a character whose root had not replicated it returned false with nothing left to re-run it, which is the original bug on the one spawn that matters.

## Claims

1. **The cause was a constant.** `Mode.initial` opened the view at yaw 0, and this system's yaw 0
   looks down **-Z** (`Mode.cameraCFrame` builds `fromEulerAnglesYXZ(pitch, yaw, 0)`, LookVector
   `(-sin y cos p, sin p, -cos y cos p)`), while the Forest Test spawns the shooter facing +Z. Verify:
   `src/client/Camera/Mode.luau`.
2. **It is not a second writer and not a `+180`.** `Mode.yawForLook` is the one place that knows
   where this system's zero points, and `Mode.anglesToward` now calls it instead of repeating the
   same inverse. `Rig.apply` is still the only thing that writes `workspace.CurrentCamera`, and the
   foreign-write counter is untouched by this.
3. **The camera follows the BODY, so no world knows about it.** `Camera.faceCharacter` reads the
   HumanoidRootPart and sets the state's yaw through `Mode.withYaw`; a place that spawns its players
   another way is right by construction, which is why DEV needed no second rule. Verify:
   `src/client/Camera/init.luau`.
4. **It runs once per spawn**, on `CharacterAdded` after the root part arrives, and once at start for
   a character that already exists -- `CharacterAdded` has already fired by the time the module starts
   on a slow client, and that first spawn is the one Karen sees. The player's mouse owns the view from
   the next frame.
5. **Measured in BOTH places** with neon posts on each world axis, reading the body's facing, the
   engine camera's and the strip's published heading at one instant: Forest Test `body=0.0 |
   view=0.0 | strip=0 | centred=plusZ_RED (0 px off centre)` with the DRIVE marker dead centre on the
   strip (`.screenshots/t130-forest-after-spawn.png`); DEV the same on the rebuilt map
   (`.screenshots/t130-dev-after-spawn.png`). The BEFORE frame is `.screenshots/t129-turn-A.png`,
   where the blue (-Z) post filled the view at spawn while the body faced +Z.
6. **The rule is a pure round trip in a spec**: body facing in, yaw out, `cameraCFrame` back to the
   same direction, for five directions, plus the two vectors that name no yaw and must answer nil.
   Verify: `tests/server/camera_mode.spec.luau`.

## What could not be verified

- **A spawn where the body itself faces the wrong way.** This task makes the view agree with the
  body; whether the body's facing is the one Karen wants at each stand is the drive's business and
  her judgement.

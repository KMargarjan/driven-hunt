# BRIEF for the Architect -- task 260, `docs/design/shotgun.md`

**Written by the Builder, carrying the Director. This overrides anything older in `docs/`,
`TASKS.md` or an earlier design (`docs/ARCHITECT_PROMPT.md` reads this first).**

## The decision, already taken. It is not open.

The Director decided `ESCALATE.md`'s 2026-10-25 entry, **option 1**, verbatim in the task-260
dispatch:

> *"THE TRUE SIGHT: `BORE_ON_SIGHT_LINE = true`. ... a BRIEF.md stating the decision: the shot leaves
> from the sight line, because Karen's 'a bit off' is that offset and real sights are zeroed to the
> line of sight."*

So **the design has to say that the bore starts on the sight line**, and the code already does
(`Shotgun.CONFIG.BORE_ON_SIGHT_LINE = true`, commit on branch `task-260-true-sight`). What is wanted
from this run is the design document brought into agreement with a decision that has been made --
not a re-examination of it.

## What the design says today, and why it has to change

`docs/design/shotgun.md` section 5.5 **step 7** reads:

> *"**Aim from the muzzle.** `aim = (aimPoint - muzzle).Unit`. If
> `(aimPoint - muzzle).Magnitude < CONFIG.MIN_AIM_DISTANCE` use `direction` instead..."*

and the paragraph under step 11 gives its reason:

> *"Pellets originate at the muzzle and converge on the point the crosshair is over. **That is the
> standard third-person shooter geometry**, and the reason tracers will look right in the
> screenshot."*

**That premise expired with task 89.** The game has been first person since then: the camera is in
the player's head, the gun he SEES is the viewmodel (which `Camera.Mode.aimOffset` lays on the camera
axis by construction), and the world Tool whose `Muzzle` attachment the design means is an invisible
prop welded to the character's right hand.

**The measurement (task 259, research note `docs/research/2026-10-24-real-shooting.md` section 12):**

- the world muzzle is **0.73 studs (20 cm) to the RIGHT of the eye** and 5 cm below it -- measured in
  a DEV Play session on both guns;
- convergence onto the aim point cancels that offset **exactly at the aim point and nowhere else**;
- so when the aim ray hits nothing -- which is **every shot led into empty space at a running
  animal**, which is the shot Karen asked for -- the shot lands **18.6 cm right at 25 m, 16.2 at
  50 m, 11.6 at 100 m**, always to the right, worst at the shortest range, and by a different amount
  depending on what happens to be behind the animal.

## What the design must contain after this run

1. **Section 5.5 steps 6 and 7 rewritten to the shipped path**, which is:
   - step 6, the muzzle, unchanged: `muzzle = muzzleAttachment.WorldPosition`, the server's own Tool;
   - **a new step: the bore ORIGIN.** `Ballistics.boreOrigin(req.origin, req.direction, muzzle,
     CONFIG.BORE_ON_SIGHT_LINE)` -- the muzzle projected onto the camera ray **at its own depth**
     (`max(0, (muzzle - eye) dot look)`), so the flight time, the range cap and what the first
     segment cast can strike are unchanged and only the offset ACROSS the sight line goes away;
   - step 7, the aim: `Ballistics.convergeAim(origin, aimPoint, req.direction,
     CONFIG.MIN_AIM_DISTANCE)`. The `MIN_AIM_DISTANCE` guard is unchanged and still explicit.
2. **`false` recorded as the rollback**, bit for bit (the same `Vector3` back, asserted by identity),
   because that is what makes both states testable while the shipped value sits at one of them --
   the shape `docs/design/ballistics.md` already accepted BY NAME in place of a flag for task 256's
   `FLIGHT_CATCHUP_*`.
3. **The third-person justification removed or marked as history.** The sentence under step 11 is the
   thing a future reader would follow back to the muzzle.
4. **`muzzle` stays what every COSMETIC reads** -- `ShotFired`, `shotSignal` (the bang the boars
   hear) and `Hardware.muzzleCFrame` (another player's flash) -- and the design should say which
   consumers take `origin` and which take `muzzle`, because they now differ. The three that take
   `origin` are: the `Flight` launch, `stopAt`, and `askLineUnsafe`. **`safetySignal` still publishes
   `muzzle` and that is a known gap, queued as TASKS.md 259b(a)** -- its consumers are
   `src/server/Match/`, a `TWO_PLAYER_PATH`. Please name it in the design rather than leave it to be
   discovered.
5. **The config table (section 11 / the `CONFIG` table) gains three rows:**
   `BORE_ON_SIGHT_LINE`, `CAMERA_ORIGIN_TOLERANCE_FIRST_PERSON` (**6** studs) and the retuned
   `CAMERA_ORIGIN_TOLERANCE` (**16**, from 30). The second and third are task 260's security half and
   are a consequence of the first: the bullet now LEAVES from a client claim, so the bound on that
   claim matters in a way it did not when the launch point was a server-read attachment. Measured by
   sweeping `Mode.cameraCFrame`: in first person the eye is **1.209 to 1.993 studs** from the root
   over the whole clamped pitch range, at every yaw and every blend; in the third-person rollback the
   client's own `MAX_DISTANCE_STUDS` clamps it at 14.5. `tests/server/camera_mode.spec.luau`
   ("the honest spread of the fire origin") is the assertion.
6. **Section 11's own open question is answered.** It currently asks *"Whether
   `CAMERA_ORIGIN_TOLERANCE = 30` is generous or tight"*. It was generous; it is 6 and 16 now, and
   `Weapon.stats.originFarthest` is the instrument that would justify moving either again.

## What must NOT change

- `Weapon.Cast` stays the only caller of `Workspace:Raycast` under that folder.
- The hit still happens in `onShotLanded`, one or more Heartbeats later (task 185), not at the
  trigger.
- No weapon row gains a system rule: `MIN_AIM_DISTANCE`, the arc, the rate limits and both origin
  tolerances stay in `Shotgun.CONFIG` (`docs/design/rifle.md` section 3 item 3).
- **Nothing in the document that this brief does not name.** The file is ~1,900 lines and covers the
  whole weapon; a heading-by-heading diff is taken before and after this run (the Learning Agent's
  L-111: *"a single Architect run against `shotgun.md` still overwrites the whole file from
  scratch"*), and anything dropped that is not listed above is a finding against the run, not an
  improvement.

# BRIEF for the Architect: lag compensation is ALLOWED; rewinding targets is still FORBIDDEN

Task 256. Written by the Builder, carrying the Director. **This brief overrides anything older in
`docs/`, `TASKS.md` or an earlier design** (`docs/ARCHITECT_PROMPT.md`).

**It is the input to TWO design runs, not one**, and they must be run and committed separately:

```
powershell -ExecutionPolicy Bypass -File tools/architect.ps1 design shotgun    --task 256
powershell -ExecutionPolicy Bypass -File tools/architect.ps1 design ballistics --task 256
```

`tools/agents.py`'s `cmd_architect` writes exactly ONE `docs/design/<system>.md` per invocation,
keyed to its single `system` argument, and both runs write the SAME `reviews/task-256/ARCH_RESULT.md`
— so the first verdict is committed before the second run starts, or it is silently overwritten.

## 1. THE DECISION, VERBATIM FROM THE DIRECTOR (2026-10-24)

> **YOUR ESCALATION (finding 3, lag compensation versus the designs) IS DECIDED by the Director:
> OPTION (b).**
>
> The decision, for the BRIEF: forward prediction of the shot by the shooter's measured one-way
> delay (FLIGHT_CATCHUP_PING_FACTOR, shipped at 1.0) is ALLOWED, because it preserves the lead. What
> the designs forbid, and still forbid, is REWINDING targets (that deletes the lead Karen asked
> for). Karen 2026-10-24: "all shooting has to be like in real life / this is a key of this game".

**This is a decision already taken. It is not open for the Architect to re-litigate.** The question
the Architect is being asked is *how the two designs should now read*, not *whether forward
prediction is allowed*.

## 2. WHY IT WAS ESCALATED, AND WHAT IS ALREADY IN THE TREE

The Reviewer's round-1 finding 3 (`reviews/task-256/RESULT.md`) was **correct**: the shipped code
contradicts both designs for this system and neither was amended. The Builder could not fix it,
because the Builder may not write `docs/design/` (CLAUDE.md role table).

**The shipped mechanism, already committed, gated and reviewed on this branch:**

- `Shotgun.CONFIG.FLIGHT_CATCHUP_MAX_SECONDS = 0.15` — the bound.
- `Shotgun.CONFIG.FLIGHT_CATCHUP_PING_FACTOR = 1.0` — the conversion from `Player:GetNetworkPing()`.
- `Weapon.catchUpFor(player, ping, config)` — the one thing that computes the correction, pure when
  `ping` is supplied.
- `Flight.launch(shot, directions, ballistic, catchUpSeconds)` — a fourth argument, clamped at the
  one door into the module.
- `live.catchUp`, spent ONCE on the first `advance`, added to that shot's own `dt` and cut into
  sub-steps by the new pure `Flight.substeps(total, config)`.
- `Weapon.stats().flightCatchUpSeconds` — what it has granted, asserted near zero in
  `weapon_state.spec` with a per-shot bound.

Research note: `docs/research/2026-10-24-real-shooting.md`, sections 5, 5.1–5.5.

## 3. WHAT THE TWO DESIGNS SAY NOW, AND EXACTLY WHICH LINES ARE WRONG

### `docs/design/shotgun.md` section 11

> **Lag, stated as a number because it will be felt.** There is no lag compensation in v1 — state
> rewind is a system of its own. At 100 ms RTT a boar at `Boar.CONFIG.SPRINT_SPEED` (38 studs/s) is
> ~3.8 studs from where the shooter saw it, and the boar is 5.5 studs long (`Boar.CONFIG.BODY_SIZE`).
> That is most of a body length: shots that looked good will miss. This is the single most likely
> thing Karen reports as "the gun feels wrong". Mitigation order: (1) the slug `Spherecast` dial
> above, (2) lag compensation as its own designed system — **never** a fudge inside the weapon.

**This paragraph was RIGHT and its prediction has now come true.** It called the complaint, and it
called the number: ~3.8 studs at 100 ms RTT. Karen reported exactly that on 2026-10-24, and the
research note measured the same quantity independently from the same constants and also got
**3.8 studs**. The design should keep that credit and record that the predicted event happened and
what was done about it — not be rewritten as though it had been wrong.

What must change: *"There is no lag compensation in v1"* is now false, and *"never a fudge inside the
weapon"* needs to become a statement of where the mechanism DOES live and why that is not a fudge.

### `docs/design/ballistics.md` section 1.2 ("Must not")

> - **No lag compensation.** Rewinding hitboxes exists to remove the feeling Karen asked for.

### `docs/design/ballistics.md` section B ("named and deliberately not adopted")

> **Badly, for us:** per-target position history, a trusted client timestamp and a rewind window —
> and it exists to defeat exactly the feeling Karen asked FOR. Lag-compensated hitscan removes lead.
> The target here is an AI boar, nobody shoots players, and a drive is not ranked. **Source's own
> projectile classes are not lag-compensated**, and that is the shape we want.

Also §9, which lists *"no lag compensation (B)"* among the adopted decisions.

**THE DISTINCTION THAT RESOLVES ALL OF THIS, and it is the Director's decision in one line:** both
ballistics passages object to **REWINDING**, and their stated reason is that *"lag-compensated
hitscan removes lead"*. That reason is still in force and the prohibition on rewinding stands. What
ships is the opposite mechanism with the opposite effect — **forward prediction of a PROJECTILE,
which preserves the true lead and removes only the ping**. Section B's own closing sentence is
already half of the new answer: *"Source's own projectile classes are not lag-compensated, and that
is the shape we want."*

## 4. WHAT THE AMENDED DESIGNS MUST CONTAIN

Both docs:

1. **The prohibition on REWINDING targets stays, with its reason intact** — it deletes the lead
   Karen asked for. Rewinding is still a "must not". Say so in the same words it is said in now.
2. **Forward prediction of the shot by the shooter's measured one-way delay is ADOPTED**, with the
   reason: it preserves the lead and removes only the ping. Karen 2026-10-24: *"all shooting has to
   be like in real life / this is a key of this game"*.
3. **Where the owner is, and why that is not "a fudge inside the weapon"**: the correction is one
   multiplication inside a loop `Weapon.Flight` already runs, over the cast seam the system already
   has. `ballistics.md` §1.2's neighbouring rule — *"No second writer of hits"* — is an argument for
   keeping it where the hit already lives. If the Architect concludes the owner IS wrong, say so
   plainly as a blocking open decision in `ARCH_RESULT.md` rather than designing a new owner in
   passing; the Director will take that as a new escalation.
4. **The bound and why it exists**: `FLIGHT_CATCHUP_MAX_SECONDS = 0.15`. Unbounded forward prediction
   lets a high-ping client reach into the future for free lead that other players would see as a shot
   which hit nothing. 0.15 s caps the reach at 5.7 studs on a sprinting boar — about one body length.
5. **The limit, which is a real property and was found by measurement**: forward prediction can only
   give back time the bullet actually SPENDS in the air, so where the round trip exceeds the flight
   time the correction is PARTIAL. At 50 m with the rifle (flight 71 ms vs a 100 ms trip) it cuts the
   miss from 4.26 to 1.73 studs instead of clearing it; beyond 100 m it is exact. Note section 5.5
   has the table. This belongs in the design because it is a thing a player can feel.
6. **The one uncertain number, as a data row**: `Player:GetNetworkPing()`'s own docs say only *"the
   network ping in seconds"* and do not state whether that is the round trip or one way, while the
   correction wanted is the round trip. Hence `FLIGHT_CATCHUP_PING_FACTOR`, shipped at the
   conservative **1.0**. A loopback Studio session reads only **0.51 ms per shot** (measured), which
   cannot distinguish 1.0 from 2.0 — so this needs a real server and is the Director's to confirm.

`shotgun.md` additionally: section 11's mitigation list no longer ends at "its own designed system".

`ballistics.md` additionally — **the module contracts are now stale and the Reviewer's non-blocking
notes name them**:

- `Flight:launch(shot, directions, ballistic): number` has a **fourth** argument, `catchUpSeconds`.
- `Flight:stats(): { launched, resolved, timedOut, refused, casts }` has a **sixth** field,
  `catchUpSeconds`.
- `Flight.substeps(total, config) -> (subs, step)` is **new**, pure and exported, because the
  sub-step split became a per-shot question.

## 5. SCOPE — WHAT THIS BRIEF DOES NOT ASK FOR

- **Do not redesign the ballistics.** Time of flight, drag, the zero, `GRAVITY_SCALE` and the
  pattern are all unchanged by task 256 and were measured as already correct (note sections 3, 4).
- **Do not touch the hit-zone or hit-mark designs.** Item 5's fix is in
  `src/client/Weapon/Effects.luau` and changes no design claim; item 4 (the kill zones) is part 2.
- **Do not design the scope fix.** That is item 3, part 2, a separate session after part 1 merges.
- **Keep every other section of both documents as it is.** `cmd_architect` OVERWRITES the whole file
  with the `DOCUMENT` block, so the rest of each doc must come back intact —
  `docs/design/shotgun.md` is 1548 lines and `docs/design/ballistics.md` is 1018. The Builder will
  diff both after each run and treat a truncation, or the loss of any unrelated section, as a
  blocking fault.

# Task 154 — the beater's drive feels real

Task: 154
Round: 1
Base: `94b4349` (main)
Code commit: `f86e6023755f61493c0c524d5694db5913b4a358`

Harness, DEV place, clean tree, run **twice** at the code commit:

```
[harness] PASS: 33/33 checks @ f86e6023755f61493c0c524d5694db5913b4a358 (clean tree) scope=all
[harness] PASS: 33/33 checks @ f86e6023755f61493c0c524d5694db5913b4a358 (clean tree) scope=all
```

`test2` is **N/A**: nothing here is in `TWO_PLAYER_PATHS` (`tools/agents.py`). The change is the
Forest Test playtest world, the boar's own sense rules and the horn — all one-player paths by the
Director's 2026-10-03 decision.

## What changed, and why

Karen's first playtest **as a beater** (2026-10-11, verbatim in `PLAYTEST.md`): the wood was empty
when she got to the road, a flush wore off instead of being final, the horn's reach was short and
its voice was a four-note phrase rather than *"short one like beeep"*. The Director also measured
that a beater spawned **holding the shotgun**.

Everything is in **beater mode in the Forest Test**. The hunter's world is untouched, and so is the
Match world (`MatchBoot` deliberately does not pass the new latch argument).

Note: `docs/research/2026-10-11-beater-spook.md`.

## Claims

1. **A flush that does not wear off is the SAME rule as a heard shot, not a second one.**
   `Brain:spook`'s third argument is renamed `shot` to `untilExit`; the config switch
   (`SENSE.SHOT_FLIGHT_UNTIL_EXIT`) and every effect of `_heardShot` are unchanged.
   *Verify:* `src/server/Boar/Brain.luau`, `Brain:spook`; grep `_heardShot` — still only
   `_settle`, `_senseAware` row 6b, `_flightActive` and the pace clamp.
   *Spec:* `tests/server/boar_move.spec.luau`, "latches on what the CALLER asked for, not on what
   frightened it" — with one config, `spook(..., true)` leaves and never settles while `spook(...)`
   and `spook(..., false)` still calm down.

2. **The world asks for the latch; the Brain does not decide it.** `Runtime:spook(id, from,
   untilExit)` and `Runtime:hearHorn(at, radius, untilExit)` forward it; both arguments are
   optional, so every caller written before today behaves exactly as it did.
   *Verify:* `src/server/Boar/init.luau`, `Runtime:spook` / `Runtime:hearHorn`;
   `src/server/MatchBoot.server.luau` still calls `hearHorn` with two arguments.
   *Spec:* `tests/server/zz_horn.spec.luau`, "latches the flight only when the WORLD asks for it".

3. **`PACE.LEAVE_AFTER_CROSSING` counted the beater as a gun the animal had walked past — a defect
   outside this task's scope, found by building it.** A beater is always on the far side from the
   exit, so all 27 resting animals read as "past the guns" on their first sense tick and marched
   south at a walk with nobody within 110 studs. The rule now counts only a stimulus that is **not**
   a driver, which is what "past the GUNS" always meant; a nil kind is a driver, the same reading
   `Brain.perceive` gives it. It had **no spec coverage at all**.
   *Verify:* `src/server/Boar/Brain.luau`, the `_crossed` latch in `Brain:_senseAware`.
   *Spec:* `tests/server/boar_behaviour.spec.luau`, "counts a GUN it has walked past, and never the
   beater pushing it" — both stimuli at 60 studs, outside every notice and flush radius, so row 10b
   is the only rule that can fire.

4. **The wood is already full in beater mode, and nothing is released on a timer.**
   `ForestTest.stepRest` stocks five resting sounders on the first heartbeat after someone is a
   beater and re-stocks `REST.restockSeconds` after the last of them has left; `ForestTest.step`
   skips `releaseLine` while `beaterMode()`. A hunter's world keeps the 20-second schedule.
   *Verify:* `src/server/ForestTest/init.luau` — `beaterMode`, `stockWood`, `restAlive`, `stepRest`,
   and the `beaterMode()` branch in `ForestTest.step`.
   *Spec:* `tests/server/forest_stand.spec.luau`, "is in beater mode only while somebody has asked
   to be a beater", and "names a real composition for every group..." (27 animals, cap 60).

5. **A resting group goes on the ground, in the trees, between her and the road, and never inside
   her own reach.** The whole rule is pure (`ForestTest.restSpotOk`); `restSpot` only takes the five
   measurements and walks rings until one passes.
   *Verify:* `src/server/ForestTest/init.luau` — `restSpotOk`, `restSpot`, `nearestSolid`.
   *Spec:* `tests/server/forest_stand.spec.luau`, "takes a spot that is on the ground and in the
   trees, and refuses every other kind" — both band edges in, one stud outside each out, inside a
   trunk out, open ground (`math.huge`) out, a canopy disagreement out, either ground answer nil out.
   *Also:* "puts every group between her and the road, and none of them inside her reach" asserts
   the shipped `REST.groups` data against that rule. **It bit:** the first gate run failed this case
   because the group at `offsetX +55` was nominally 96 studs from her start against a 119-stud
   keep-away; the data moved (`northStuds` 140 to 108, now 124 studs) and the assertion did not.

6. **One rule for "how close is too close", in one place.** Task 153 put a copy of the beater flush
   inside `stepLines`; it is now `ForestTest.spookNearBeaters`, run once per step over every live
   animal, so a beater meeting a file and a beater meeting a resting sounder get the same answer.
   The whole sounder goes with the member she reached (`Runtime:sounderOf`), because the Brain's own
   panic spread carries no latch and half a latched group is two rules again.
   *Verify:* `src/server/ForestTest/init.luau`, `spookNearBeaters`; `stepLines` no longer reads
   `PACE.DRIVER_RUN_STUDS`, and `state.latched` makes it once per animal.

7. **The reach is data, in metres and in studs, and one function converts.**
   `ForestTest.SPOOK.BEATER_M` 25 / `BEATER_STUDS` 89; `ForestTest.beaterSpookStuds` is
   `Horn.spookStuds`'s twin.
   *Spec:* `tests/server/forest_stand.spec.luau`, "writes the beater's reach in metres AND in
   studs...", "resolves the reach from either unit, like the horn's", "makes the horn reach further
   than her own feet do".

8. **The horn: 100 m, one note, 1.5 s cooldown.** `SPOOK_M` 80 to 100 (= `ROLLOFF_MAX_STUDS` and the
   shot's own audible radius), `SOUND_START`/`SOUND_CUT` 0.12/4.4 to 3.4/4.4, `COOLDOWN` 5 to 1.5,
   `BLOW_SECONDS` 3 to 0.9. The cut is measured off the asset's own loudness at 0.02 s resolution
   (profile in the data file and in the note section 5): the phrase's last note is the only single
   note in the clip that reaches 0.5-1 s and the only one whose end is real silence rather than the
   next note's attack.
   *Verify:* `src/shared/Horn/init.luau`, `Horn.CONFIG`.
   *Spec:* `tests/server/zz_horn.spec.luau`'s existing number cases still hold — the blast finishes
   before the next may start (`playSeconds` 1.00 <= `COOLDOWN` 1.5), `BLOW_SECONDS` < `COOLDOWN`, the
   cut is before the second call, the roll-off still carries as far as a gunshot.

9. **A beater carries the horn and no guns, and the two policies are one fact.** `Horn.gunFor(team)`
   is the exact complement of `Horn.carriesFor`, beside it; `ForestTestBoot` reads it as its arming
   policy and calls `Weapon.refreshArming` on the role switch so `/beater` is immediate.
   *Verify:* `src/shared/Horn/init.luau`, `Horn.gunFor`; `src/server/ForestTestBoot.server.luau`,
   `Weapon.setArmingPolicy` and `applyRole`.
   *Spec:* `tests/server/zz_horn.spec.luau`, "gives a beater the horn and NOT a gun..." — complements
   for every team, no team is not a beater, and the gun does not follow the `HORN` flag.
   *Live:* the smoke below, `hand=[Horn] bag=[]` (it was `hand=[Shotgun] bag=[Rifle,Horn]`).

10. **Smoke in the Forest Test** (standing rule A), fresh Play of 85 s on the code commit:
    - Tool in the **character**, not the backpack: `@15s team=Drivers hand=[Horn] bag=[]`,
      `@85s team=Drivers hand=[Horn] bag=[]`
    - Console: `stacks=0 errorLines=0` over the whole server + client output
    - The feature ran: `the wood is stocked: 27 animal(s) in 5 group(s) -- ... 9 at -115/+150 studs
      (trunk 16); ... 6 at -24/+105 (trunk 10); ... 9 at +55/+107 (trunk 15); ... 2 at +125/+94
      (trunk 17); ...` plus 194 `[rest]` reports.

## What I could not verify

- **Whether 25 m, 100 m and the one-note horn FEEL right.** They are the Director's start values
  (25 m against a literature figure of 84-93 m — the note section 3 records why the game is lower),
  they are data, and only Karen can judge them. Per Karen's rule for this task — *"for visual
  testing I can do that and we save tokens and 2h"* — no frames and no scripted walk traces were
  produced this round: the look and the feel are hers.
- **Two players.** There is none in the Forest Test, so the horn reaching a hunter 100 m away is
  untested.
- **The Match world.** `MatchBoot` is deliberately unchanged — it passes no latch and keeps its own
  arming policy — so whether a beater in the real drive should carry no gun is the rotation task's
  question, not this one's.
- **27 animals on Karen's machine.** A measured session has carried 32 in this place, but she has
  not played this build.

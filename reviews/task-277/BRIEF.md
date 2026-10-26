# Task 277 BRIEF — an honest hit accepted by construction, and real vital organs

**Written by:** the Builder, carrying the Director (dispatch 2026-10-26), for
`tools/architect.ps1 design ballistics --task 277` and
`tools/architect.ps1 design hit-zones --task 277`.

**This file is the input to BOTH design runs and overrides anything older in `docs/`, `TASKS.md`
and the existing `docs/design/ballistics.md` (v4) and `docs/design/hit-zones.md` (v1).**

**TWO RUNS, TWO DOCUMENTS, ONE TASK FOLDER.**

- Run 1 writes `docs/design/ballistics.md` — **direction A** (claim validation).
- Run 2 writes `docs/design/hit-zones.md` — **direction B** (vital organs). The zones' system name
  on disk is **`hit-zones`**, not `boar-zones`; `docs/design/boar-zones.md` does not exist and must
  not be created.
- Direction **C** (the acceptance criteria) belongs in **both** documents' numeric-targets section,
  each stating the half it is accountable for.
- Each run's `ARCH_RESULT` is `reviews/task-277/ARCH_RESULT.md` and the second run **overwrites** it.
  The Builder commits run 1's verdict before starting run 2 and records both in the review request.

**Design only. No gameplay code in this task.** The next task builds it.

---

## KAREN, the key of the game (verbatim)

> "all shooting has to be like in real life"

> "when boar is running we need to aim in empty space to get hit in head neck or heart like in real
> life smae with other animals"

> "I need quality results"

---

## MEASURED NOW (tasks 265–276; ledgers in `<runs-dir>/ledgers/`, and `TASKS.md` rows 265–276a)

1. **Without claims, a chest-aimed shot at a running deer lands ~5 studs behind**, which is
   `v × ~0.19 s` (the view lag), **in both the led and the unled arms** (task 276). Signed along the
   animal's velocity it is −3.6 to −7.1 studs, unled mean −5.19 against led mean −5.49, while the
   lead in dispute is ~1 stud (`v × flight` = 0.45–0.92 studs at these ranges).
2. **With `HIT_CLAIM`: the client claims `ZoneChest`; the server refuses chest claims at
   `claim-line`** — 4.09 studs against a 2.00 budget in task 274, 2 of 2 refused in task 276 —
   **although the sweep reaches its whole window and picks the best instant** (task 272:
   `sweep=19/19 win=0.301s spread=8.046`, and `took == best` on every trial, so no other instant in
   the window is better). Task 275 established that `claim-line` is already judged at the swept
   instant, so the sweep is not the missing piece.
3. **An accepted claim DOES decide the hit** (task 274): `judgeClaimFor` returns
   `Validator.claimImpact(...)` with `instance = claim.part`, `onShotLanded` passes it to
   `Hits.group`, and `Hits.targetOf` reads that part's own `HitZone`. One running chest hit was
   accepted and **photographed** (`274-core-core.10.1.png`: a hind in mid-stride at 11 m, card
   `HIT - .416`, red diamond on the chest). The mechanism is proven; the **rate** is not.
4. **The chest zone is reachable only 40–115° off the nose** (task 276, swept by ray at 5° steps on a
   live animal): it is **1.54 studs long against a 6.03-stud trunk** and clears the trunk by
   **0.05 studs a side**. Head-on and tail-on chest shots read `body` and `rear`. Nine tasks of
   "0 of 5 chest" were largely reporting the animal's **aspect**, not the shooter's aim.
5. **Tasks 269b–276 iterated on the validator piece by piece without converging.** That is the
   reason this task is a design and not another trial.

### Supporting readings the designs may rely on

- The error is **not vertical and not ballistic drop**: `sightOffsetAt(150)` is +0.034 studs ABOVE
  the sight line with `GRAVITY_SCALE = 0.12`, and the miss decomposes as `up` 0.002–0.156 studs
  against `right` 0.18–3.05 (task 273).
- `Claim.simulate` already advances each target to the arrival instant (task 270, worst |error|
  0.009 studs over twelve rows), so **a shooter who also leads applies the compensation twice**
  (task 275). Task 276 withdrew 275's 0/5-vs-2/5 signal as sampling (1 of 5 against 1 of 5).
- **The commonest no-claim cause is `static-blocked`** (task 275: every no-claim shot in ten) — the
  CLIENT's own line of sight closing on grass or a trunk in front of a deer crossing low ground.
- The mark is drawn a body length behind the zone it names (task 276a(c)): `Effects.puff` converts
  the world hit with the part's CURRENT CFrame and then locks the emitter to the part, so it is off
  by the animal's travel — 5.033 studs, measured. Pre-existing, non-blocking, and it is a **client
  drawing** defect, not a validation one; name its owner, do not fold it into the rule set.

---

## THE DIRECTOR'S DIRECTION (verbatim)

### A. CLAIM VALIDATION, SIMPLE AND HONEST BY CONSTRUCTION

An honest client's claim must pass by construction; only cheats must fail. One clear rule set, each
check stated as what it protects against:

- the shooter could fire (state, ammo, rate, safety lock);
- the claimed muzzle is within the origin tolerance of the server's character;
- the claimed line is consistent with the claimed muzzle and direction: the claim's OWN line, which
  an honest client satisfies exactly;
- the claimed target was, at SOME instant in the server's history window (the view-lag window),
  within a body-sized tolerance of the claimed hit point;
- there is line of sight from the muzzle to the claimed point at that instant, ignoring the target's
  own parts and foliage.

Remove or redefine any check that refuses an honest claim (`claim-line` as it is today is the
suspect). State the cheat each remaining check stops, and the worst honest case each must pass.

### B. REAL VITAL ORGANS, HITTABLE FROM ANY ANGLE

Replace the surface hit boxes with zones that model the anatomy: heart/lungs (the vitals, low and
forward in the chest behind the shoulder), neck, head (brain), spine, paunch, legs. Each is a VOLUME
inside the body; the shot's path through the body decides which volumes it crosses (a frontal chest
shot reaches the heart and lungs; a quartering shot can pass the paunch into the vitals), with the
damage by the most vital volume crossed, per cartridge (the existing doctrine: head, neck and
heart/lungs kill fast; paunch and legs wound and the animal runs on). For boar kinds and red deer
kinds, with real proportions from the research (cite it).

### C. THE ACCEPTANCE CRITERIA the build must meet on Karen's path

- honest claims accepted **≥ 95 %** on running animals at **20–60 m**;
- a forged claim refused;
- the vitals hit from **broadside, quartering and frontal** aspects;
- **the lead equals the bullet's flight time only.**

---

## What the Architect must also do in this design (the Builder's framing of the above; not new policy)

### For run 1 (`ballistics`) — direction A

1. **State the rule set as a numbered list, each check with three lines**: what it protects against
   (the named cheat), the worst HONEST case it must pass (with a number from MEASURED NOW), and the
   measured quantity and budget it refuses on. A check with no cheat behind it is deleted in the
   document, not kept "for safety".
2. **`claim-line` must be resolved explicitly, by name.** Today (`Validator.judgeClaim`, check 4) it
   measures `(facts.trajectoryPoint - facts.serverPoint).Magnitude` against
   `limits.LINE_TOLERANCE_STUDS` — **the SERVER's own trajectory against the SERVER's own rewind**,
   which is not the claim's own line, and it is exactly the quantity measured at 4.09 of 2.00 on
   honest chest claims. The direction says the check is *"the claim's OWN line, which an honest
   client satisfies exactly"*. Say which it becomes: redefined to the claim's own
   muzzle/direction/point consistency, removed because another check already bounds the cheat it was
   stopping, or kept with a derived budget. If it is removed, name **which remaining check stops the
   cheat it was stopping**, and show that the enumerated worst case of a modified client is still
   bounded (`ballistics.md` §5.4 is the existing enumeration and must be rewritten, not cited
   unchanged).
3. **The body-sized tolerance in direction A's fourth bullet is a number**, derived from the trunk
   the zones actually have (6.03 studs long, per MEASURED NOW 4), not a guess, and it must be stated
   for each of the seven kinds or as one rule over their measured boxes.
4. **The lag the fifth bullet's "at that instant" means** must be the same instant the fourth bullet
   chose, named once, with the owner that chooses it. Task 275 found `claim-line` already at the
   swept instant and `claim-blocked` not; the document must not leave two clocks.
5. **"Ignoring the target's own parts and foliage"** is a raycast filter. Say the exact mechanism and
   **verify it exists before asserting it** (see item 11). The existing waiver
   (`stoppedByClaimedTarget` plus `span + REACH_SLACK_STUDS + displacementStuds`) is the thing it
   replaces; say whether the waiver survives.
6. **Direction C's "the lead equals the bullet's flight time only"** is a statement about what the
   SHOOTER must do. `Claim.simulate` already advances the target to the arrival instant. Say, in one
   paragraph, whether the shooter's own lead and the claim path's compensation are the same
   compensation applied twice, and if so which one is removed and who owns the removal.

### For run 2 (`hit-zones`) — direction B

7. **It is a change of KIND, not of numbers.** Today the zones are **surface boxes welded to the
   trunk, each standing `PROTRUSION = 0.06` studs proud so the ray meets it first**
   (`Boar.CONFIG.ZONES`, built by `Boar.Body`), and the zone is whatever box the ray touches FIRST —
   which is why the chest is unreachable head-on and tail-on. Direction B asks for **volumes the path
   crosses**. Say what replaces the protruding boxes, what happens to `HitZone` on an Instance, and
   whether `Hits.targetOf` (`src/server/Weapon/Hits.luau`) still reads a part attribute or is given a
   path.
8. **Name every volume, with its box or shape, per kind.** The seven kinds are
   `Boar.CONFIG.SPECIES.ORDER` = `male, female, cub, legendary, stag, hind, calf` (the boar kinds use
   `Boar.CONFIG.ZONES` and `BODY_SIZE` directly; the three deer kinds are the stag's measured boxes
   scaled). The existing measured anatomy (bone positions in the trunk's frame, read off the loaded
   rigs) is in the comments above `Boar.CONFIG.ZONES` and `SPECIES.reddeer.ZONES` and is **the
   measurement to build on, not to re-guess**: front legs attach at z −0.53 to −0.70, brisket +0.05,
   back +2.45, `hip_b` +2.79, `Spine_base` +2.18, nose z −2.388, `Neck` z −0.866, trunk 6.03 long.
9. **The damage model keeps its existing doctrine and its existing table shape.** `Boar.CONFIG.WOUND`
   is `LETHAL = 100`, `MORTAL = 50`, `DAMAGE[zone][ammo]` plus the per-weapon sibling table
   (`hit.weapon` selects it, because both rifles send `Slug` on the wire). Say what the new volume
   names do to those keys, and how "the damage by the most vital volume crossed" is computed — the
   function, its owner, and whether a path crossing two volumes adds or takes the maximum.
10. **A frontal chest shot must reach the heart and lungs**, and a quartering shot must be able to
    pass the paunch into the vitals. State both as assertions with the aspect in degrees, against
    MEASURED NOW 4's 40–115° window, so the spec can hold them.

### For both runs

11. **Do not assert an engine API, property or behaviour you have not verified exists** — not for
    volume containment, not for raycast part filtering, not for anything. `docs/design/ambience.md`
    shipped a nonexistent `SoundService.Volume` this way and it reached the build. Where the
    mechanism is not verifiable from the repo or from documentation you can cite, put it in **"What I
    could not verify"** and give the Builder the probe that settles it.
12. **Direction C's four criteria go in the numeric-targets section of both documents**, each as an
    assertion with the instrument that reads it, and each marked as to whether a spec can hold it or
    only a live trial in Karen's place can. Task 276a(a) measured that the current instrument
    **cannot** fire a trigger fast enough to hold an aspect: 1–2 s pass between the gate reading and
    the real focused click, and 6 of 10 shots were tail-on at the trigger although all 10 passed a
    chest gate. If a criterion needs an instrument that does not exist, say so and say what it is.
13. **Carry forward, do not absorb:** the next (build) task must grep every caller and spec of
    `claim-line` once it is redefined or removed (`src/server/Weapon/Validator.luau`,
    `src/server/Weapon/init.luau`, `src/shared/Shotgun/init.luau`'s `CONFIG.CLAIM`,
    `tests/server/weapon_hits.spec.luau`, `zz_claim_window.spec.luau`, `weapon_shot.spec.luau`).
    Name that as a build-order step in the document; this design-only task does not do it.
14. **Still owed from the 265–276 run**, each to be placed or explicitly deferred by the design that
    owns it, not silently dropped: 269a(b) (the instrument's `no-ammo`), 270a(a) (the coarse gate at
    `SPRINT_SPEED` 38), 271's round-1 findings 5–7, 272a(b) (the window-0 case that accepts),
    274a(b) (the `claim-blocked` waiver at 7.275 against a 3.40 bound), 276a(c) (the mark drawn a
    body length behind), 276a(d) (**is a head-on chest shot supposed to read `body`?** — direction B
    answers this one).

---

## What this task delivers

`reviews/task-277/BRIEF.md` (this file), `docs/design/ballistics.md` (rewritten for A and C),
`docs/design/hit-zones.md` (rewritten for B and C), `reviews/task-277/ARCH_RESULT.md` for both runs,
and one review round (docs only). **Stop at 2 h.**

# Review request — Task 266: TRUE HITS

Task: 266
Round: 3
Base: 670416e6 (main at the branch point; task 265's comment fix cherry-picked by the Director as fb4e201c)
Code commit: 5a634c489436ec5203bdd32ab203f134a6818cd6

```
[harness]  PASS: 34/34 checks @ 5a634c489436ec5203bdd32ab203f134a6818cd6 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 5a634c489436ec5203bdd32ab203f134a6818cd6 (clean tree)
```

`test2` is required and is **not** avoidable: `src/server/MatchBoot.server.luau` is a
`TWO_PLAYER_PATH`, and the design (§13.2) says why only a composition root may hand the Boar's
history to the Weapon.

**Each of the design's four build steps has its own green full run**, which is what §13.3 asks for:
step 1 `2ee070ac`, step 2 `8fb91198`, step 3 `1f2a0725`, step 4 `9ec9ec2e`, the live fix `a64b1944`
(itself gated both ways), and round 2's finding `5a634c48` above.

## PLAN (core quality protocol step 0) — committed at `10543f83`, before any `src/` edit

**(a) REAL LIFE.** A bullet goes where the sights were when the trigger broke, after its own flight
time. A .416 at 131 studs flies **0.052 s**, so a hind at 28 studs/s needs **1.5 studs** of lead.
That, and nothing else, is the lead real shooting asks for.

**(b) MEASURED NOW** (`<runs-dir>/266shot.py`, Forest Test, this session): aiming at the chest of an
animal running at 24 studs/s puts the server's impact **+3.94 and +4.14 studs along the animal's own
+Z** — its rump — at 148.7 and 108.1 studs. The ballistic lead at those ranges is 1.0–1.4 studs and
does not close it.

**(c) TARGET.** Not a number: **the shot hits what the shooter saw**, whatever the offset is. The
numbers the design puts against it are `CLAIM.POSITION_TOLERANCE_STUDS` 6.0 (check 2),
`LINE_TOLERANCE_STUDS` 2.0 (check 3, the one that makes the zone geometric), `AGE_MAX_SECONDS` 0.5,
`FLIGHT_TOLERANCE_SECONDS` 0.03 and `HISTORY.SAMPLES` 64.

**(d) LEVER.** `Weapon.onShotLanded`'s impact list is what `Hits.group` is given; an accepted claim
truncates it to one impact. `Input.fire` is the one firer of `FireRequest` and gains one optional
field. Pasted grep is in the PLAN commit and the symbols are unchanged.

**(e) HOW IT WILL BE MEASURED AFTER.** The same instruments: `266shot.py` for the three numbers of a
real click, and `<runs-dir>/266-claimprobe2.luau` for whether the client's own simulation produces a
claim at all.

**(f) OUT OF SCOPE, SAID SO IT IS NOT SILENTLY DROPPED (L-090):** the nine clicks at the stand that
produced `ShotFired=0` in round 1 are still undiagnosed. What the dispatch required instead —
`aimshot --selftest` at 5/5 — **passed this session** (5 clicks → 5 ShotLanded).

## Claims

1. **The two round-1 findings are answered, and neither is disputed.**
   `reviews/task-266/probes/MEASURED-R2.md` withdraws round 1's `offTarget` metric (it compared the
   camera against the attribute the probe itself wrote) and replaces it with the **trigger-frame
   camera against the animal's own position on that frame**, computed from readings round 1 had
   already taken; and it withdraws the stated cause of the "6 clicks, 0 shots" silence, because the
   cited run says `tool=Shotgun` at the shooter's own position.
   *Verify:* `probes/MEASURED-R2.md`, both sections.

2. **The design's four steps are built, in order, each green on its own.**
   *Verify:* `git log --oneline fb4e201c..a64b1944`; the five harness lines above and in the ledger.

3. **`Ballistics.segment` is a MOVE, not a rewrite, and the spec proves it bit for bit.**
   `ballistics.spec`'s first new case rebuilds the expression `Flight.advance` used to run inline and
   demands `(position - want).Magnitude == 0` on all three vectors; the others pin the exact range
   cap and that nothing is mutated.
   *Verify:* `tests/server/ballistics.spec.luau` → `describe("Ballistics.segment -- the moved sub-step")`.

4. **The Boar is the one owner of where an animal was.** The ring is written in the loop that
   already reads every animal's position, with ONE reading of the shared clock per step; `cframeAt`
   is the only reader; the Weapon is handed a CFrame and can neither enumerate animals nor ask where
   one is now. `Boar.sampleAt` REFUSES outside its span and never extrapolates.
   *Verify:* `src/server/Boar/init.luau` → `Boar.sampleAt`, `Runtime:cframeAt`, and the write inside
   `Runtime:step`; `tests/server/boar_history.spec.luau` (both refusals, the wrap, the rotation).

5. **The claim is judged at the RESOLUTION, and the shot in the air is the pending queue.** No second
   remote, no shot id, no pending table, no timeout. An accepted claim truncates the impact list to
   one impact; a refused one leaves the shot to resolve from the flight exactly as today, which is
   also the flag's OFF state by the same code path.
   *Verify:* `src/server/Weapon/init.luau` → `judgeClaimFor`, and that `onShotLanded` builds both the
   report AND the dust from the same `impacts` local.

6. **Six checks, pure, each refusable by name, and the forged claim among them.**
   `weapon_shot.spec` drives an honest claim through `judgeClaim` first — so every refusal below it
   is the one thing that case moved — then the 30-stud forgery (`claim-moved`, a factor of five over
   the tolerance), the line, the offset, the line of sight, the future, the stale, the flight time,
   the nine-pellet pattern off the row, and five malformed payloads.
   *Verify:* `tests/server/weapon_shot.spec.luau` → `describe("the hit claim")`.

7. **THE FEATURE WAS INERT WHEN IT SHIPPED GREEN, and a live reading is what caught it.** With step 4
   gated and all four client cases passing, `<runs-dir>/266-claimprobe2.luau` read **`NO CLAIM`**
   with a rifle in hand aiming at a chest 58 studs away. The static pass returned nil the moment the
   cast answered anything, and one sub-step at 2612 studs/s is **87 studs** — so the ground beyond
   the animal was in the same segment as the animal. After the fix (nearest wins, as the server's own
   flight already resolves a segment), the same probe reads
   **`CLAIM part=ZoneRear zone=rear offset=-1.06,0.08,-0.81 dist=26.1 flight=0.0100`**.
   *Verify:* `src/client/Weapon/Claim.luau` → the `(1) THE STATIC WORLD` block and its measured
   comment; commit `a64b1944`; `probes/266-claimprobe2.luau`.

8. **ACCEPTANCE (1), a still animal: MET, with all three numbers — and it does NOT prove the claim.**
   `Boar33/cub`, chest, `offTarget=0.000 deg`, 100.2 studs, v=0.00 → server
   `ZoneChest zone=chest local 0.477,0.056,0.002`, client mark `hit/chest` then `kill/chest`. A still
   animal is exactly the case where a claim changes nothing, so this shot would have landed in the
   same place with the feature off. It proves the aim and the mark agree, and nothing more. **One
   shot, not three**: the other two re-picked moving targets.
   *Verify:* the ledger's §2(1); `probes/266shot.py`'s `READ`.

9. **ACCEPTANCE (2), a running animal: HALF MET. The miss behind is measured twice; the led chest hit
   is NOT obtained.** `+3.942` and `+4.138` studs along the animal's own +Z — its rump — while the
   ballistic lead at those ranges is 1.0–1.4. Three attempts at the led half failed for reasons that
   are not the gun (a tree in the lead line, a different animal of the same sounder, a staged target
   behind a trunk). **Nobody has yet seen the pair complete.**

10. **ACCEPTANCE (3), a forged claim: MET IN THE GATE, NOT LIVE.** The live case in `weapon_shot.spec`
    noted `nobody is holding a gun that can fire` — the honest-note branch the sight-line case has
    used since task 185 — so the wiring half ran only as the policy-parameter case.

11. **ROUND 2's ONE BLOCKING FINDING IS FIXED, AND IT WAS RIGHT.** The design's §12.1 cases 26-29
    were dropped, so deleting `judgeClaimFor`'s accept branch — or pinning `Flight`'s `live.reached`
    at 0, which would make check 5 refuse every claim in the shipped game — left the WHOLE suite
    green. `Validator.claimImpact` is the truncation extracted as a **pure exported function of three
    facts**, so the branch can no longer be deleted silently, and `weapon_hits.spec` gains five cases:
    `reachedStuds` three ways (stopped at 40, unobstructed to the cap, the GREATEST of nine pellets),
    `Flight` carrying a claim whose every field would fail every check and resolving identically to
    the unclaimed shot, and the truncation through `claimImpact` into `Hits.group` — one report,
    `pellets = 1`, the zone read off the part's own `HitZone`. Server assertions 2317 → 2322.
    **Case 27 is NOT written**, and the spec says so in place: "a refused claim changes nothing" is a
    property of a module local reachable only through a live handler. What IS executed of it is every
    refusal reason by name plus case 29; what is not is the owner's `return res.impacts`. Queued.
    *Verify:* `src/server/Weapon/Validator.luau` → `claimImpact`; `tests/server/weapon_hits.spec.luau`
    → `describe("the hit claim's own facts")`; and that `judgeClaimFor`'s accept branch is now one line.

## What I could not verify (rule 8)

- **No shot has been seen whose hit was decided by an ACCEPTED claim.** The client produces one and
  the server's judge is driven by specs on both sides, but the end-to-end acceptance is **NOT
  PROVEN**, and claim 8 is not it.
- **The led chest hit** (acceptance 2's second half) was not obtained.
- **The shared clock** is still unestablished (task 265 round 3). The design depends on it only
  inside a tolerance and a window, and `POSITION_TOLERANCE_STUDS` is 6.0 for that reason.
- **The harness cannot produce latency**: a loopback Studio session reads 1–2 ms of ping, so the
  claim path's magnitude cannot be exercised in the gate at all. Everything about it is proved by
  injected times and positions in the pure specs and only bounded in the live ones.
- **Case 27**, above: the refused path's `return res.impacts` is executed by nothing that can fail.
- **259b still has no regression guard** (queued 266a(a)), and `src/server/Match/` was not exercised
  by a live two-player case for it.
- **Rule 5:** `266-acc1-still.png` and `266-acc-claim.png` were saved but are **not offered as
  evidence**: the acceptance frames show the shooter's eye, and I did not obtain a frame showing a
  hit mark on a running animal. L-109's limit (Play capture renders only the player's own view)
  stands.
- The Forest Test's `ServerStorage` attributes were set for the acceptance (`DHFlag_HIT_CLAIM`,
  `DHTestOwns`) and **removed afterwards**; the attribute set reads character for character what it
  read before. Said here because the standing block asks for it.

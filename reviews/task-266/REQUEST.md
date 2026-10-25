# Review request — Task 266: TRUE HITS

Task: 266
Round: 1
Base: main (fb4e201c, task 265's comment fix cherry-picked by the Director)
Code commit: c2751924ab63680b114e63b9e10f7a096242e7cd

```
[harness] PASS: 34/34 checks @ c2751924ab63680b114e63b9e10f7a096242e7cd (clean tree) scope=all
```

`[harness2]`: **N/A.** Nothing in the change touches `TWO_PLAYER_PATHS` — the one code file is
`src/server/Weapon/init.luau`, and `src/server/Match/` is untouched (`git diff --stat
fb4e201c..c2751924` shows one file). Note that `docs/design/ballistics.md` §13.2 says the FULL task
will need `test2`, because step 3 wires the history provider in `MatchBoot`; **this round does not
reach that step.**

## What this round is, in one paragraph

The dispatch's own contingency happened: *"if the design run alone takes most of it, commit the design
and stop."* The Architect design run is in (PASS, and it forbids the second run), the dispatch's
item 4 is **diagnosed and the instrument is rebuilt and proved**, and the design's one named
shipped-behaviour fix (259b) is built and gated. **The claim system itself is NOT built**, so
acceptance cases (1), (2) and (3) are NOT met and nothing here claims they are.

## PLAN (core quality protocol step 0)

Written for the whole task. **It is out of order and I am saying so:** the 259b one-liner was
committed before this file existed, because the design names it as a single `Vector3` at a single
call site whose whole proof is arithmetic. The CORE item — the claim — is designed and unbuilt, and
its plan is what the next round builds to.

**(a) REAL LIFE.** A bullet goes where the shooter's sights were when he pulled, after its own
flight time. A .416 at 131 studs flies **0.052 s** (`Ballistics.timeToRange`, task 265 round 2), so
a hind at 28 studs/s needs **1.5 studs** of lead — that, and nothing else, is the lead real shooting
asks for.

**(b) MEASURED NOW.** Task 265 round 3 (`<runs-dir>/265-lagrec.luau` + `265lag.py`, five animals,
1049 samples): the client's copy of a moving animal sits **~0.17 s along its own travel** from the
server's, **0 of 1049 samples the other way** — 2.5-4.3 studs at 15-25 studs/s. **That number is NOT
ESTABLISHED** (its own round-3 review: the only control was a motionless part, which reads 0.000
under any clock skew). This round adds its own reading, from the client's side only: a real focused
click with the held view **on a running animal's chest, `offTarget=0.307 deg`**, produced
`ShotFired=1, ShotLanded=0` — the trigger worked and the shot hit **nothing at all**
(`reviews/task-266/probes/MEASURED.md` §2).

**(c) TARGET.** The shot hits what the shooter saw, **whatever that offset turns out to be**. That is
the Director's decision and the reason it is the right one: the target is not a number to tune but a
construction — the client simulates against its own view and the server validates by rewinding its
own history (`docs/design/ballistics.md` §§1.2, 5.2). The design's own numbers:
`CLAIM.POSITION_TOLERANCE_STUDS`, `CLAIM.VIEW_WINDOW_SECONDS`, `Boar.CONFIG.HISTORY` (§§3.1, 3.2).

**(d) LEVER.** The writers exist. Pasted:

```
$ grep -n "aimPoint = \|local origin = \|local aim = \|safetySignal:Fire" src/server/Weapon/init.luau
1392:	local aimPoint = if aimImpact then aimImpact.position else req.origin + req.direction * range
1405:	local origin = Ballistics.boreOrigin(req.origin, req.direction, muzzle, CONFIG.BORE_ON_SIGHT_LINE)
1406:	local aim = Ballistics.convergeAim(origin, aimPoint, req.direction, CONFIG.MIN_AIM_DISTANCE)
1592:			safetySignal:Fire(player, aim, origin, stopAt)
$ grep -n "FireRequest:FireServer" src/client/Weapon/Input.luau
139:	remotes().FireRequest:FireServer({ origin = cframe.Position, direction = cframe.LookVector.Unit })
```

**Read those by symbol, not by number** (CLAUDE.md: cite files and symbols, never line numbers — the
numbers are here only because the protocol's step 0(d) asks for pasted `grep` output, and they are
stale the moment anything above them moves). The lever for the CORE item is **`aimPoint` inside
`Weapon.onFireRequest`**: it is where the server decides what the shot was aimed at, and the claim
replaces it. The lever for 259b is the **`safetySignal:Fire` call inside the `driveLineProvider`
block of the same function**, and it is the one line this round changes. The client's half is
**`Weapon.Input.fire`**, the only firer of `FireRequest`, which is where the claim's fields are added
in the design's step 4.

**(e) HOW IT WILL BE MEASURED AFTER.** The same instrument as (b): `<runs-dir>/266shot.py`, which
prints, for one real click, the aim point, the server's impact **in the animal's own frame**, and the
client's mark — with `ShotFired` counted separately from `ShotLanded` so a miss cannot read as a dead
click.

## Claims

1. **The BRIEF carries the Director's decision and Karen's words, and the Architect designed to it.**
   `reviews/task-266/BRIEF.md` §2 is the dispatch verbatim; §2.1 is the argument that a validated
   projectile claim does not delete the lead; §4's table checks each primitive the design would need
   against the tree **before** it could be written in as a requirement (L-108).
   *Verify:* read it, and `docs/design/ballistics.md` §1.4 against BRIEF §2.1.

2. **The design run landed and says NOT to make the second one.** `reviews/task-266/ARCH_RESULT.md`
   line 1 is `PASS`; the `shotgun.md` delta is inside the design at §14. Two runs were authorised in
   the brief; one was made, which is what the verdict instructs (L-111 is the reason the brief said to
   commit between runs).
   *Verify:* `ARCH_RESULT.md`, then `docs/design/ballistics.md` §14.

3. **259b is fixed, and it is one Vector3 at one call site.** `safetySignal:Fire(player, aim, origin,
   stopAt)` where it published `muzzle`, so the ray `Match.Penalty.judge` measures off is now the ray
   `askLineUnsafe` tested. The two were **parallel** (same `aim`, different start) and 0.73 studs
   apart at EVERY range — a range-independent flip band around `SAFETY_MISS_STUDS = 12`.
   *Verify:* `git diff fb4e201c..c2751924 -- src/server/Weapon/init.luau`; `grep -n "safetySignal:Fire\|askLineUnsafe(player" src/server/Weapon/init.luau` — both now name `origin`;
   `docs/design/ballistics.md` §8 for the arithmetic.

4. **Nothing under `src/server/Match/` changed, and nothing else in `src/` changed.**
   `Match.onSafetyViolation` and `Match.lineIsUnsafe` already take the ray's start as an argument.
   *Verify:* `git diff --stat fb4e201c..c2751924` — one `src/` file.

5. **`ShotFired` and `ShotLanded` keep the Tool's `muzzle`, deliberately.** A flash comes out of the
   gun; a penalty measures the bullet's line.
   *Verify:* the two `FireAllClients` calls in `onFireRequest` still pass `muzzle`.

6. **Item 4 is DIAGNOSED, not worked around.** A real focused click in the Forest Test reached
   `UserInputService.InputBegan` 5 times of 5 with `gameProcessed=false`, produced `ShotFired=0`,
   `ShotLanded=0` and **no `refused` at all** — because the player was a **beater holding a horn**
   (`team=Drivers held=[Horn]`, 580 studs from the road) after the drive rolled over to drive 2, and
   `onFireRequest`'s first gate answers `return "untracked"` **with no publish of any kind**. The
   binding was never the fault (`DrivenHunt.Weapon.Fire{MouseButton1}` was bound throughout).
   *Verify:* `reviews/task-266/probes/MEASURED.md` §1 for every pasted reading, then
   `src/server/Weapon/init.luau` — `local id = Weapon.heldId(player) or Weapons.PRIMARY`, then
   `if not state then return "untracked" end`, and confirm no `publish` runs on that path.

7. **The instrument now flags its own known-bad input, shown in BOTH directions.** `266shot.py` reads
   the SERVER's team + the tool actually in the character immediately before every click and refuses
   otherwise; the same Play session produced `PRE OK ... team=Shooters held=[Shotgun]` and, after the
   drive rolled over, `PRE FAIL (not a shooter) team=Drivers held=[Horn]` → `REFUSED: ... This is an
   INSTRUMENT fault, not data.`
   *Verify:* `MEASURED.md` §2, and `reviews/task-266/probes/266shot.py`'s `PRECHECK` / the
   `if not pre.startswith("PRE OK")` gate.

8. **Two instrument faults behind task 265's numbers are fixed, and each is a measured fault, not a
   tidy-up.** (i) the held view was a FIXED point, so a 2.6 s reload let an animal walk out of the
   aim — it now **tracks the target's chest every rendered frame** (`DHTestLook` is re-read per
   frame: `src/client/Camera/TestLook.luau`, `TestLook.current`); (ii) `ShotLanded` is fired only
   when `#res.impacts > 0`, so counting it as the trigger made every clean miss read as a dead
   click.
   *Verify:* `onShotLanded` in `src/server/Weapon/init.luau` — the whole `FireAllClients` block is
   inside `if #res.impacts > 0`; `266shot.py`'s `RenderStepped` tracker.

9. **The Forest Test shooter cannot reach the drive's animals with what he carries, measured.**
   `reserve{Buck=12 Slug=0}` with `RANGE_STUDS = { Slug = 330, Buck = 100 }`, against 19 animals
   read at **137-230 studs**, which then crossed at **17-64 studs for about ten seconds** and left
   nothing within 90 studs for the next minute. One shot in this batch was fired at 183 studs and
   landed on a trunk and the ground.
   *Verify:* `MEASURED.md` §3; `src/shared/Shotgun/init.luau`'s `RANGE_STUDS`.

10. **NOT MET, said plainly:** acceptance (1) a still animal's three chest shots, (2) the running
    animal's miss-behind / hit-with-lead pair, and (3) the forged claim rejected, are **not
    obtained**. (3) is not even attemptable: there is no claim payload in the game yet. (1) and (2)
    were attempted and the shooter window is one drive long — the role alternates to beater at the
    next drive, which is the same fact item 4 diagnosed.
    *Verify:* `git diff --stat fb4e201c..c2751924` — no claim code exists; `MEASURED.md` §§2-3.

## What I could not verify (rule 8)

- **The acceptance.** Nobody has yet seen a shot hit what the shooter saw, because the mechanism is
  designed and unbuilt.
- **The ~0.17 s view error** is still unestablished (task 265 round 3's own finding). The design is
  deliberately independent of it (§1.4, §15), and this round neither confirms nor refutes it.
- **259b's fix is arithmetic, not a live two-player reading.** Its two rays are parallel by
  construction and the fix makes them one ray; `src/server/Match/` is a `TWO_PLAYER_PATH` and no
  such run was made. `tests/server/match_safety.spec.luau` drives `Penalty.judge` with its own
  hand-built `Shot` tables, so **no spec asserts which start point the weapon publishes** — that gap
  is pre-existing and is NOT closed here.
- **No "before" read of the Forest Test's `ServerStorage` attributes** was taken at the start of the
  session (`MEASURED.md` §4). The two reads taken are identical to each other and nothing this task
  ran writes one.
- Rule 5 (screenshot): the frames `266shot.py` saved are the shooter's eye during these shots, but
  **none of them shows a hit mark on an animal**, because no shot in this session hit an animal. They
  are not offered as evidence of anything.

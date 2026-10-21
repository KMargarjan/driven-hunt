# Task 230 -- the animals are on by default: `BOAR_MODEL` flipped to `true`

Task: 230
Round: 1
Base: `main` at `7a731e3d` (the merge of task 232's deer clips)
Code commit: `54b085b4624862493658b3521423f7b2d490a191`

```
[harness] PASS: 33/33 checks @ 54b085b4624862493658b3521423f7b2d490a191 (clean tree) scope=all
```
(1944 server + 494 client assertions, 65 server spec files, 25 client.)

`test2`: **N/A.** `TWO_PLAYER_PATHS` in `tools/agents.py` is the match, the drive, the tie and the
teams; this change is `src/shared/Flags/init.luau` plus eleven `tests/server/` specs, none of them in
that list and none of them a `tests/server/match_*.spec.luau`, `zz_drive_boundary.spec.luau` or a
client spec. CI green on the pushed branch (run 39587825077).

## What changed, and why

Karen, 2026-10-21: *"add deer in a game"* -- on top of her OK of the drawn boar (*"looks good now"*,
task 115) and of its death (*"I thin kwe good"*, task 116). Every animal kind this game has sits
behind `BOAR_MODEL`, so with the row at `false` a fresh server showed grey boxes and **no deer at
all**. This is step 6 of the flag lifecycle: her OK flips the default, in a small commit, and the row
stays as the rollback.

## Claims

1. **The row is flipped, and only the row.** `Flags.DEFAULTS.BOAR_MODEL.default` is `true`; `owner`,
   `born` and the row itself are unchanged, nothing is deleted, and `Flags.DEFAULTS` still holds
   fourteen rows. *Verify:* `src/shared/Flags/init.luau`, the `BOAR_MODEL` row; `git diff
   7a731e3d..54b085b4 -- src/shared/Flags/init.luau` shows `default`, `expires`, `why` and comments
   and nothing else.

2. **`expires` moved to 2026-12-31, and it had to.** Every ACCEPTED row in this table carries that
   date for the same stated reason (`BOAR_SOUNDERS`, `ORANGE_OUTFITS`, `RIFLE`, `FIRST_PERSON`): the
   21-day ceiling is for a path nobody has judged. Left at 2026-10-24 the row fails
   `tests/server/flags.spec.luau`'s rot tripwire on the 25th -- four days from now -- which fails the
   harness and blocks whatever gate runs that day, the exact bomb task 149b defused for `RIFLE` and
   `FIRST_PERSON`. *Verify:* the `expires` comment in the row; `flags.spec`'s expiry case.

3. **`boar_model.spec`'s declaration case asserts the LIT row and still discriminates.** It was
   `default == false` / `expires == "2026-10-24"`; it is now `default == true` /
   `expires == "2026-12-31"`, with `owner` and `born` still asserted unchanged so a flip cannot be
   mistaken for a row somebody rewrote. *Verify:* `tests/server/boar_model.spec.luau`, describe *"the
   flag is declared, and since task 230 it is LIT"*.

4. **`boar_hit.spec` takes `MODEL.ENABLED = false` by parameter, and that file is about the BOX.**
   `Body.boxFalls` is `not hasVisual or not hasDeathTrack`: with a drawn animal on the box the death
   CLIP lays it down and `Body.collapse` deliberately keeps `Upright` **on**, because the two
   rotations compose (its own comment carries the -90.2 deg measurement). *The evidence that this
   discriminates rather than weakens (L-028):* on the flip's first gate run, with nothing else
   changed, `boar_hit.spec`'s *"dies on a head slug"* failed at `expect(upright.Enabled).to.equal(false)`
   with **"Expected false, got true"** -- the flag alone turned it red, and `specModel()` turns it
   green again by naming the world the case means. *Verify:* `specModel` in
   `tests/server/boar_hit.spec.luau` and its two `config = { WOUND = specWound(), MODEL = specModel() }`
   worlds; `Body.boxFalls` and `Body.collapse` in `src/server/Boar/Body.luau`.

5. **The DEER is pinned out of four specs' releases, by parameter, and that pin is what five red
   cases asked for.** With the flag lit, `Runtime:spawnSounder` rolls for a red deer group **before it
   places anything** whenever the caller named no composition (`Boar.deerComposition`, task 223): the
   release then comes out the deer's size and makes a sounder record of its own. *The pre-flip
   evidence (L-028):* the first gate run after the flip failed exactly these, and nothing else --
   `boar_behaviour.spec` *"releases the alarm"*, `expect(#handles).to.equal(3)` got **1**;
   `boar_body.spec` *"creates NOTHING when the whole sounder does not fit"* spawned **2**;
   *"a size of one is a lone boar"* saw **2** sounders; *"runs as a group when a driver appears"*
   reported *one route per sounder: leader Boar1, but the askers were Boar1 x6, Boar6 x7, Boar8 x6*;
   and the break and mortal cases each saw **2** sounders where they assert 1. `noDeer()` sets
   `SPECIES.reddeer.RELEASE.CHANCE_PER_RELEASE = 0`, which is **never, exactly** (`NextNumber` returns
   [0, 1), the gate is `roll >= chance`) -- the same shape and the same argument as task 219's
   `LEGENDARY = { CHANCE_PER_DRIVE = 0 }` pin, which sits a few lines away in two of these files.
   *Verify:* `noDeer` in `boar_body.spec`, `boar_behaviour.spec`, `boar_behaviour_live.spec` and
   `boar_shot.spec`, and each `SPECIES = noDeer()` use; `Runtime:spawnSounder` and
   `Boar.deerComposition` in `src/server/Boar/init.luau`.

6. **`KINDS` is deliberately NOT turned off in those four.** The pin removes the deer and leaves the
   flag's own world standing, so the sounder machinery is now asserted on the sow-and-her-young
   sounder the game actually releases rather than on the uniform male box it used to be. That is a
   strengthening, and it is measured rather than hoped: every one of those cases was green on the
   sow-led sounder in the flip's first gate run -- the only red ones were the five above, all of them
   deer. *Verify:* the `config` of each runtime named in claim 5; the first gate run's failure list
   (claim 5) against the full pass at the code commit.

7. **One case really did assume the OFF default, and now says which world it means.**
   `boar_behaviour.spec`'s *"is exactly the old rule when every animal is the same kind"* took
   `Boar.sounderKinds(4, {}, CONFIG)` from the MODULE config: with the flag lit that answers a sow and
   her young, so the uniform rank the case is about cannot occur. It builds a `kindsOff` config by
   parameter. *Verify:* that case in `tests/server/boar_behaviour.spec.luau`; `Boar.sounderKinds`'
   own `local on = config.KINDS ~= nil and config.KINDS.ENABLED == true`.

8. **Six comment-only corrections**, because five specs said in words *"a harness run only ever sees
   `BOAR_MODEL`'s OFF default"* and that stopped being true today -- `boar_calm.spec`,
   `boar_kinds.spec`, `boar_legendary.spec`, `deer.spec`, `boar_behaviour_live.spec` -- and
   `light.spec`'s shade block said `BOAR_MODEL` *"is still `default = false`, so this is the animal a
   default server shows"*, where the grey box is now the FALLBACK animal. No assertion moved in any of
   them. *Verify:* `git diff 7a731e3d..54b085b4 -- tests/server/boar_calm.spec.luau
   tests/server/boar_kinds.spec.luau tests/server/boar_legendary.spec.luau tests/server/deer.spec.luau
   tests/server/light.spec.luau` -- comment lines only.

9. **THE PLAYER'S PATH IN DEV, WITH NO OVERRIDE, LOOKED AT (rules E, F, H).**
   `python tools/flags.py --place dev` printed *place 136410205938347 (Driven Hunt DEV)*,
   `BOAR_MODEL default on / override none`, and no override on any row.
   - **Before** (the same place, the pre-flip tree): three `kind=male` boxes, `meshes=0`,
     `transp=0.00`, and no deer -- `.screenshots/230-before-greybox-eye1.png`, camera eye **6.67**,
     15 studs from the animal: a grey box with its coloured hit zones.
   - **After**: the first release was a **sow and two cubs**, each drawn (`meshes=1`,
     `BoarFemale_NoAlpha` / `BoarCub_NoAlpha`, trunk `transp=1.00`), and a later release was a **red
     deer hind and calf** (`Red_Deer_Doe_NoAlpha`, `Red_Deer_Calf_NoAlpha`). Frames, each from a
     standing player's own eye at **6.60-6.63**, 9-11 studs away:
     `.screenshots/230-after-sow-eye.png`, `230-after-hind-eye.png`, `230-after-calf-eye.png`.
   - **On the ground, measured, worst case over five footprint rays per animal** (the lowest visible
     corner of everything drawn, minus the ground under it): sow **-0.037**, cubs **-0.043** and
     **-0.047**, hind **-0.034**, calf **-0.039** studs. Every animal's feet are in the surface by
     four to five hundredths of a stud: nothing floats, nothing sinks, and no figure reads a
     suspicious 0.00.
   - Console over the whole session: **0** "Stack Begin" and **0** error / "attempt to" /
     "invalid argument" lines. `BoarAssetsBoot` loaded all six models and reported *all 19 boar clips*
     and *all 11 reddeer clips have an animation asset id*.
   *Verify:* the four frames; `driven-hunt-runs/230-console-after.txt`.

10. **It closes `TASKS.md` row 223b (L-100), and that was checked on the path rather than argued.**
    223b is *"with `BOAR_MODEL` off no deer can spawn, while the DEER LICENCE is on sale for $750"*:
    with the row lit, a default DEV drive released a hind and a calf (claim 9), so the licence now
    sells an animal the build shows. Nothing in the shop changed. *Verify:* `TASKS.md` row 223b;
    `docs/design/red-deer.md` section 16 item 1, whose own text makes this flip the resolution.

## What I could NOT verify

- **Karen has not seen this build.** She OK'd the boar (tasks 115, 116) and asked for the deer; she
  has not played a default server with both in it. The frames above are mine.
- **The sounder cases now run on a sow-and-young sounder** (claim 6). Two full runs were green and
  the five deer failures are accounted for one by one -- but a mixed-size sounder is new ground for
  `boar_body.spec`'s scatter and break cases, which this repo has watched go red on timing before
  (their own comments record the week of 2026-10-18). If they ever flake, the one-word fallback is
  `KINDS = { ENABLED = false }` beside the `noDeer` pin.
- **A HARNESS FAULT, reported rather than worked around (rule 6).** `python tools/studio_mcp.py
  capture` wrote its frame from the **Forest Test** Studio (`studio d6b63574, place 130094961655666`)
  although its own docstring -- and `ftplay.py`'s comment -- both say it pins DEV. Two frames came out
  of the wrong place before it was noticed; neither is used as evidence here, and every frame in
  claim 9 was taken through `ftplay.py capture` with the DEV Studio id passed explicitly. It is the
  same place-ambiguity class `tools/flags.py` was fixed for in task 226, in a command that was not.

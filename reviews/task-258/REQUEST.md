# Task 258 (= task 256 part 2, filed fresh because 256 is at its round cap): the BARK preload, and what part 2's three big items actually cost

Task: 258
Round: 1
Base: 4ed06ceb (main, includes task 256 part 1)
Code commit: 6925edf1b2b2010d232a2297a25b7c5b2eb13982

Harness, clean tree, full suite:

```
[harness] PASS: 34/34 checks @ 6925edf1b2b2010d232a2297a25b7c5b2eb13982 (clean tree) scope=all
```

`[harness2]` is **N/A**: the change is `src/server/Boar/init.luau` and
`tests/server/deer.spec.luau`, neither in `TWO_PLAYER_PATHS`.

Filed as task **258** rather than `reviews/task-256/` Round 3, on the Director's instruction and the
233b -> 235 precedent: task 256 is at its round cap and `tools/agents.py` counts rounds from that
folder's own committed `RESULT.md`.

## READ THIS FIRST: ONE OF FOUR ITEMS SHIPPED, AND THE OTHER THREE ARE MEASURED RATHER THAN GUESSED

The dispatch carried four independently-judged items. **One is done; three are not, and this request
is mostly about what measuring them cost and which routes are now eliminated.** I sequenced rather
than pushing all four through (the dispatch's own "if near it, commit and stop with the state", and
the Learning Agent's L-012 on this exact bundling shape). Nothing is claimed as done that is not.

| item | state |
|---|---|
| 4, `SOUND.BARK.ids` | **DONE, gated, with a new spec case** |
| 1, the true scope | **NOT DONE.** Cannot be measured on her path: the rifle/lever/semi-auto are not armable there. Two causes newly ruled out, one new candidate found |
| 3, the real-click lead proof | **NOT OBTAINABLE by the probe route, and that is now proved rather than suspected** |
| 2, the kill zones | **NOT STARTED.** Named as untouched |

## Claims

**1. `SOUND.BARK.ids` made every boar fetch a 177-second recording, and no boar can ever play it.**
Verify: on the BASE commit the row is `ids = { 85634523415950 }`, and
`SOUND.VOICE.LENGTHS[85634523415950]` is **177.3483** by the table's own measurement.
`Body.oneShotSpecs` returns `bark = sound.BARK` unconditionally for every animal, and
`Body.warmAssets` passes every built Sound to `ContentProvider:PreloadAsync`. Yet
`Runtime:check` plays the cue only where `MOVE.EDGE_BARKS` is true, which is the stag's and the
hind's `edge` rows alone — `Boar.CONFIG.MOVE.EDGE_BARKS` is `false`, so every boar kind and the
calf answer false. So a sounder of boars each pulled down a 177 s asset for a sound they cannot make.

**2. The fix is one data row and nothing audible changes.**
Verify: `ids = { 9113629809, 9113629973 }` — "Bull Breaths 4 / 9", 0.87 s and 0.93 s in the same
`LENGTHS` table. `VOICE.stag.bark` and `VOICE.hind.bark` both still begin `85634523415950`, and
`VOICE.APPLIES.bark` is true, so `Body.voiceIds` answers their own list and never this row. The only
resolution that reaches the default in the shipped game is the **calf**, who has no `bark` row and
no `edge` row either. Harness notes from the run above, which are the before/after pair:
```
boar-shot: bark = 2 id(s) (9113629809), vol 0.90, 110 studs
task257 bark: stag 1, hind 1, calf 0, boar 0 bark play(s) at the edge check; stag sounded 85634523415950 region 39.88-41.12 gain 2.37 speed 0.995 volume 0.296
```
The default is the breath; the stag still sounds the real recording, by region, unchanged.

**3. The two ids were chosen so the existing clash check cannot break, and the sweep was done
(L-030).** Verify: every reader of the field was grepped before narrowing it —
`Body.oneShotSpecs`, `Runtime:check` via `MOVE.EDGE_BARKS`, and four spec sites. `deer.spec`
collects every boar id from `SOUND.CRY/DEATH/GRUNTS` plus each boar kind's `cry/death/grunt` and
asserts no deer cue id is among them; the calf's bark falls through to **this** row, so the row's
ids are inside that check. Both chosen ids already sit in `VOICE.stag.bark` and already pass it
today, so they are known not to be a boar's.

**4. A new case pins the claim through the real resolver, not by reading the table.**
Verify: `deer.spec`, "NO BOAR PRELOADS THE 177-SECOND BARK: the default row is library breaths
(task 258)". For every `BOAR_KINDS` entry it asserts `Boar.voiceIds("bark", kind, sound.BARK, on)`
resolves only to ids under 10 s by `LENGTHS`, **and** that the stag and the hind still resolve to an
id over 10 s with a `VOICE.CLIPS` entry — so the case fails both if the long id returns to the
default and if somebody quietly downgrades the thing Karen asked for. It also requires `LENGTHS` to
carry a measurement for every id in the row, so an unmeasured id cannot be added silently.

**5. ITEM 3 IS NOT OBTAINABLE BY THE PROBE ROUTE, AND THIS IS THE MEASUREMENT (L-109).**
The dispatch asked for a client probe that points the camera at a computed lead point and then fires
with a real OS click. `Camera.lookAt(point)` is the designed route and its own header says so:
*"It exists so a test can aim: the camera's yaw comes from mouse movement, and under
MouseBehavior = LockCenter the harness cannot deliver usable deltas (design section 9.3)."*
I ran L-109's required landmark check **before** building anything on it
(`<runs-dir>/258-cam-test.luau`, Forest Test, in Play, aimed 100 studs to the player's +X):
```
lookAt=true reqBefore=0 reqAfter=1
before=0.000,-0.139,-0.990  after=0.000,-0.139,-0.990  want=1.000,-0.015,0.004
dotAfterWant=-0.0018  moved=0.0000
```
`moved=0.0000` — the real `workspace.CurrentCamera` did not turn at all, and `reqBefore=0` shows
why: `execute_luau` has its **own module cache**, so the probe's `require(PlayerScripts.Camera)`
returned a FRESH Camera module and `lookAt` incremented that copy's counter instead of the running
owner's (memory: `studio-mcp-execute-luau-single-line`). **So a Forest Test probe cannot aim the
running camera, and I did not retry it blind.**
The route that CAN work, named for whoever picks this up: a **client spec** under `tests/client/`,
which runs inside the player's own client and therefore shares its module cache, combined with a
click line in `tests/client/input_scenarios.txt` — the harness already replays real input into the
Play client and a client spec already asserts on what `ContextActionService` delivered. That is in
DEV rather than on her path, and it is a real click through the real input stack.

**6. 256a(c)'s puff frame is NOT OBTAINABLE either, for the same reason plus L-109's own.**
StudioMCP renders only the player's own camera in Play (L-109: already lost in 251, 251c and 253),
and claim 5 shows the player's camera cannot be pointed from a probe. So there is no route to put a
sprinting animal in frame at the moment its dust is in the air. **Marked NOT OBTAINABLE rather than
retried.** What I attempted instead, and what stopped it, is claim 7.

**7. What I could measure on her path, and the one new item-1 candidate it found.**
`<runs-dir>/258-aimray.luau` and `258-aimray2.luau` cast the player's own aim ray at every animal in
`workspace.Boars` from his stand and reported the first thing it hits. Two readings:
```
Boar17 284 st (79 m) animal=false first=Branch(MeshPart) at 280.5   (3.5 studs short of the animal)
Boar20 283 st (79 m) animal=false first=Branch(MeshPart) at 276.4   (6.6 studs short)
Boar16 214 st (60 m) animal=false first=SM_Trunk(MeshPart) at 88.3  (a real tree, 126 studs short)
Boar18 231 st (65 m) animal=true  first=ZoneChest(Part) at 229.2
```
A `Branch` MeshPart intercepting the aim ray a few studs in front of an animal is a **new candidate
cause for Karen's "a bit off"**, and it is the long-queued "leaves vs shots" item
(`overnight-run-2026-10-05-queue`): `Weapon.onFireRequest` converges the bore on `aimPoint`, so a
reticle that looks clear on the boar sends the shot into foliage the player cannot see at 79 m.
**I am NOT calling it a defect**: whether thin foliage stops a bullet is a feel decision and
Karen's, and the second reading (after the animals moved) showed the same ray landing on the
animals' own zone parts, so it is intermittent and position-dependent. It is evidence for part 2,
not a finding.

**8. Item 1 cannot be measured on her path at all, and the reason is a grant.**
Verify: in the Forest Test the player is armed with the **Shotgun** only —
`258-state.luau` reported `team=Shooters tool=Shotgun backpack=[]`. `Weapons.loadout(askOwned(player))`
gates on OWNERSHIP, and the Forest Test's `DHShopTestGrant` grants **coins and hunts**, not weapons
(`Economy.testGrantFor` returns `{ coins, hunts }`). So the scoped rifle, the lever and the
semi-auto would each have to be bought through the shop flow first, and the read-only block forbids
changing an attribute to shortcut it. **What part 1 already settled by code proof stands**: for a
target the aim ray HITS, the bore is converged on that point and the only deviation is the
elevation, measured at <= 1.5 cm at 100 m (`docs/research/2026-10-24-real-shooting.md` sections 4
and 6).

**9. The Forest Test read-only block was honoured exactly.**
Verify: attributes read first and re-read at the end, byte-identical both times —
```
placeId=130094961655666 DHFlag_BOAR_BEHAVIOUR=true DHFlag_BOAR_MODEL=true DHFlag_COINS=true
DHFlag_DEER_ROAD_LEAP=true DHFlag_DRIVE_BOTS=true DHFlag_HORN=true DHFlag_LICENCE_POPUP=true
DHFlag_LOBBY=true DHFlag_SHOP=true DHForestStartRole=hunter DHShopTestGrant=true
```
Play was stopped, the place left in Edit, and the window closed (`CloseMainWindow`, process confirmed
gone) before the harness. The harness log says `ok Studio has the DEV place open` and
`1 Studio connected`, and both reports came from `136410205938347`.

## What I could NOT verify (rule 8)

1. **Items 1 and 2 are not done.** Item 1 needs the three weapons armable on her path (claim 8);
   item 2 — the kill zones, the per-kind anatomy and the before/after shots-to-kill table — was not
   started, and I am not reporting any part of it. Both are named in `TASKS.md` with this state.
2. **No real-click proof of anything**, and claim 5 is the measurement of why rather than an excuse.
   The dispatch's CLICK PROOF line for this step is therefore unmet; the working route is named.
3. **No puff frame** (claim 6), so 256a(c) is still owed and rule 5 is still unmet for part 1's
   item 5 — the Reviewer said so inside part 1's round-2 PASS and it remains true.
4. **The live hit-mark proof on her path was attempted and did not land.**
   `258-mark-live.luau` was to fire at a boar and then read back an `Impact` Attachment parented to
   its body — the real-game version of part 1's spec. It fired nothing: no animal held clear LOS
   inside 300 studs over 25 attempts, and by the time I re-probed, the continuous drive loop had
   rotated the player to `team=Drivers tool=Horn boars=0`, which closes the shooting window. Not a
   failure of the fix; a failure to catch a window. The probe is kept for whoever has one.
5. **The foliage finding in claim 7 is evidence, not a verdict** — one intermittent reading on one
   stand, and whether foliage should stop a bullet is Karen's call.

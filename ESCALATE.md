# DIRECTOR DECISION, 2026-10-27 09:15 UTC -- task 287's round-3 findings

Task 287 used its three rounds (MAX_ROUNDS 3). Its round-3 findings are code, not documentation, so no extra round is
authorised. They are real (a pad restart pays the aborted drive every time -- a coin faucet; an Assigning->Assigning
restart skips the per-drive work), and both come from the round-2 pay-out. DECISION: the Builder's own shortest fix is
taken -- the restart ENTERS `Scoring`, so the loop's existing Scoring edge pays exactly once and runs the per-drive work.
It is built as task 299 on branch `task-299-pad-restart-scoring`, stacked on `task-287-pad-fresh-hunt` (head a28bafbb),
with its own review rounds. 287 is not merged on its own: it would ship the faucet.

# ESCALATE -- task 287: round 3 returned FINDINGS, so I stop (the dispatch's rule). For the Director.

**Builder, 2026-10-27 09:11 UTC.** Branch `task-287-pad-fresh-hunt`. Code commit `96d932c9`; the
verdict is against `0a3f679d` (the request commit; only paperwork after the code).

## THE GATE IS COMPLETE, THREE LINES, ONE COMMIT

```
[harness]  PASS: 34/34 checks @ 96d932c9898a2435f3eb82e0faca3f4bc2201cd9 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 96d932c9898a2435f3eb82e0faca3f4bc2201cd9 (clean tree)   (287r3a)
[harness2] PASS: 36/36 checks @ 96d932c9898a2435f3eb82e0faca3f4bc2201cd9 (clean tree)   (287r3b)
```
Two CONSECUTIVE clean two-player runs, no failure of any kind in any of the three. The Players
spinner was read off `<runs-dir>/287r3-spinner.png` first (mode `Server`, count `2`), which is why
both started on the first try after the two that did not.

## ROUND 2'S TWO FINDINGS ARE CLOSED, AND SHOWN FAILING FIRST

With the finding-3 fix reverted to the lobby's own latch:
`[harness] FAIL: 32/34 @ 96d932c9 (DIRTY TREE (1 paths)) scope=all` --
`lobby_live.spec:1219` *"Expected true, got nil"* (the new teardown case's live notice) and
`lobby_live.spec:1261` *"Expected sizing, got empty"* (the solo case's pad). Both pass at the commit.

## ROUND 3 RETURNED **FINDINGS** (2), BOTH ABOUT THE PAY-OUT I ADDED IN ROUND 2

`reviews/task-287/RESULT.md`:
1. **The restart pay-out is REPEATABLE** -- `payDrive`'s only guard is `driveNumber <= paidUpTo`,
   and a restart pays drive N and then raises the number, so a man who respawns and steps on a pad
   again and again is a coin faucet. (My live case saw `paid 1 -> 2` once and never twice.)
2. **A restart from `Assigning` into `Assigning` moves the drive number without the owner's
   per-drive work**, because every per-drive reset in `dispatch` hangs off a PHASE edge -- and that
   is the branch the live evidence actually took (`phase Assigning -> Assigning`).

**Both are real and both are mine** (round 2's finding-2 fix, and the `Assigning` restart branch
from round 1). Neither is in Karen's own sentence -- the solo restart and the multi-player refusal
are proven live in both harnesses -- but finding 1 is an economy hole and must not merge as it is.
I have NOT touched them: round 3 is the last round. **The Director decides**: a fourth round under
`DIRECTOR_MAX_ROUNDS=4` with the authorisation recorded here, or he takes the two fixes. The
shortest honest fix for both, if it helps: pay through the same `Scoring` edge the loop already has
(enter `Scoring` on the restart instead of `Assigning`), which closes the faucet and gives the
per-drive work its edge back.

---

# ESCALATE -- task 287: round 2 returned FINDINGS, so I stop (the dispatch's rule). For the Director.

**Builder, 2026-10-27 08:12 UTC.** Branch `task-287-pad-fresh-hunt`. Code commit `9d343ffa`; the
verdict was written against `4502baaa` (the request commit, paperwork only after the code).

## THE GATE IS COMPLETE AT ONE COMMIT

```
[harness]  PASS: 34/34 checks @ 9d343ffaafd54fc836f33f9d02dfc42bf6ec9e51 (clean tree) scope=all
[harness2] PASS: 36/36 checks @ 9d343ffaafd54fc836f33f9d02dfc42bf6ec9e51 (clean tree)
```
One-player server 2408/0/0, client 612/0/0. Two-player server 2408/0/0, shooter 612/0/0, driver
606/0/0 (`<runs-dir>/test2-287b1.log`). Both live doors ran, each in the harness that can reach it:
`task287 SOLO branch ... drive 2 -> 3 ... restarts 0 -> 1, economy true paid 1 -> 2` and
`task287 MULTI-PLAYER branch (still in the drive: Player2): refused=true enrolled=false drive 2
(unchanged) ... rejoinsRefused 0 -> 1, paid 1 (unchanged)`.

## 1. THE SECOND `test2` RUN DID NOT HAPPEN -- INSTRUMENT, NOT CODE

`run-test2.sh 287b2` and `287b3`, back to back, both ended:
`FAIL A 2-player local test appeared within 180 s (0 new studio(s) beside the editor)` --
`[harness2] FAIL: 12/13 checks @ 9d343ffa (clean tree)`, `exit=1 took=190s studios_after=1`. The
Start click did not land. Studio was in **Edit** with exactly **one** instance before each try
(`studio_mcp.py state`), and I opened and closed nothing. The first run, at the same commit, passed
36/36. **Most likely the Test tab's Players spinner is no longer 2** -- it is set by hand and the
Director set it for `287a`; `start_stop_play` cannot ask for a player count, so F7 alone cannot fix
it. It needs one look at that spinner.

## 2. ROUND 2 RETURNED **FINDINGS** (2), AND THE DISPATCH SAYS STOP

`reviews/task-287/RESULT.md`, verdict at `4502baaa`:
1. `Lobby.stop` never hands `DHPadLate` back, so a stopped owner leaves `LobbyLate` on a screen with
   no writer left to clear it -- the row task 249 added to that same loop for `DHLeftDrive`. Fix is
   one line in the `touched` loop plus the `or` guard.
2. `lobby_live.spec`'s *"hands the man alone in a dead drive back to a pad"* -- the second withdrawn
   man (57) is never written into `seen.withdrawn` or `seen.inDrive`, so that half of claim 8 passes
   with the finding-3 fix reverted. It is a vacuous arrangement, and the Reviewer is right.

**Both are real; neither is in the shipped game's solo or multi-player behaviour** (finding 1 is a
teardown path, finding 2 is a test arrangement). I have NOT touched them: round 2 is the last round
the dispatch allows, so the Director decides whether to authorise a third
(`DIRECTOR_MAX_ROUNDS=3`, CLAUDE.md's one-extra-round rule) or to take the two fixes himself.

---

# ESCALATE -- task 287. **NEEDS KAREN: the two-player click, and it now blocks the REVIEW too.**

**Builder, 2026-10-27 07:22 UTC.** Branch `task-287-pad-fresh-hunt`, code commit `55a978fb`. The work is
done and GREEN; round 2 of the review cannot be STARTED, and the reason is a gate, not a defect.

```
[harness] PASS: 34/34 checks @ 55a978fb85b10aac69c5f31b3e52e16dda1a7b66 (clean tree) scope=all
[harness] PASS: 34/34 checks @ f68f9a49cfc24a03db39e137a0c981953dbe87a7 (clean tree) scope=all
```
Server 2408 / 0 / 0, client 612 / 0 / 0, both runs. `weapon_shot.spec:476` and
`zz_drive_boundary.spec` are green: the branch regression is fixed (`reviews/task-287/REQUEST.md`
round 2 has the three measurements that found it).

**WHY ROUND 2 IS REFUSED.** `tools/review.ps1 287` says:

> REFUSED: this change touches src/server/Match/Phase.luau, src/server/Match/init.luau,
> tests/server/match_live.spec.luau, tests/server/match_phase.spec.luau, which a one-player run
> cannot evidence. Paste the TWO-PLAYER line for the code commit as well:
>   [harness2] PASS: n/m checks @ 55a978fb85b10aac69c5f31b3e52e16dda1a7b66 (clean tree)

(Re-confirmed at 07:21 UTC against the `Round: 2` request at `55a978fb`. CI is green on the head,
and `git diff --name-only 55a978fb..HEAD` is `ESCALATE.md`, `TASKS.md`,
`reviews/task-287/REQUEST.md` -- paperwork only.)

Round 1 got past it with a `scope=auto:...` line, which `tools/agents.py` accepts for a round. **That
door is shut for this branch now:** fixing the regression put the new spec file into `SCOPE_SPECS`,
which is in `tools/studio_mcp.py`, and that path resolves to `all` in `BLAST_RADIUS` -- so
`test --scope auto` can only ever print `scope=all` here, and a hand-named scope is refused as
evidence (correctly). The only remaining key is the `[harness2]` line.

**THE CLICKS, UNCHANGED, AND NOW NEEDED ONCE FOR THE ROUND AND TWICE FOR THE MERGE:**

1. Studio on **Driven Hunt DEV**, **Edit** mode, Rojo connected, at `55a978fb` or the branch head.
2. `python tools/studio_mcp.py test2`
3. Studio -> **Test** -> **Clients and Servers** -> **Players: 2** -> **Start**; leave the windows
   alone; press **Cleanup** when the harness says so. Repeat once for the second clean run.
4. Then `powershell -ExecutionPolicy Bypass -File tools/review.ps1 287` (the request is `Round: 2`;
   its `Code commit:` is `55a978fb`).

I did not attempt the click: the dispatch says *"test2 stays NEEDS KAREN / the Director's -- do not
wait on it"*. Everything else in the definition of done is met.

---

# ESCALATE -- task 287. **NEEDS KAREN**: the two-player run. For the Director.

**Builder, 2026-10-27.** Branch `task-287-pad-fresh-hunt`. Code commit
`c26c375c9030cf86577a816239fa1d49e0bae050`. The task is BUILT and the one-player gate is PASS twice
over; what is missing is `test2`, which no tool on this machine can start.

**WHY IT CANNOT BE WORKED AROUND.** `tools/studio_mcp.py`'s own measurement: StudioMCP's
`start_stop_play` takes `is_start` and `studio_id` and NOTHING else, so there is no way to ask for a
player count. The mode prints the clicks and waits 180 s for the windows.

**THE EXACT CLICKS, and they are needed TWICE (the dispatch asks for two consecutive clean runs,
because the multi-player path is a race with a live roster):**

1. Studio on **Driven Hunt DEV**, in **Edit** mode, Rojo connected, at `c26c375c`.
2. In a terminal: `python tools/studio_mcp.py test2`
3. Studio -> **Test** tab -> **Clients and Servers** -> **Players: 2** -> **Start**.
4. Leave the windows alone until the harness says so, then press **Cleanup** in the Test tab.
5. Repeat 2-4 once more. Both lines must read
   `[harness2] PASS: n/n checks @ c26c375c9030cf86577a816239fa1d49e0bae050 (clean tree)`.

**WHAT THE ROUND DOES NOT NEED IT FOR.** The change touches `src/server/Match/`, so it is in
`TWO_PLAYER_PATHS` and the MERGE gate wants the pair. The REVIEW round does not: CLAUDE.md accepts a
`scope=auto:...` line for a round and then asks for no `[harness2]` line at all, and this task has
one at the same commit (`reviews/task-287/REQUEST.md`). So the review ran; **the merge is the
Director's call**, exactly as the dispatch put it (*"if test2 cannot run tonight, say so; the
Director decides"*).

Lines in hand, both clean-tree and both naming the code commit:

```
[harness] PASS: 34/34 checks @ c26c375c9030cf86577a816239fa1d49e0bae050 (clean tree) scope=all
[harness] PASS: 34/34 checks @ c26c375c9030cf86577a816239fa1d49e0bae050 (clean tree) scope=auto:economy,hud,lobby,match
```

---

# ESCALATE -- task 282, at the hard stop. For the Director.

**Builder, 2026-10-27.** Branch `task-282-boar-hitbox`. **Item 2's cause is measured and named;
items 1, 2's FIX and 5 are NOT done.** I am writing this AT the hard stop, before designing any
workaround, exactly as the dispatch asks.

(The previous entry, task 269b, is archived at `backups/ESCALATE-2026-10-26-task-269b.md`.)

## WHAT THE BOX BOUGHT

**Dispatch item 2's cause was unknown and is now measured** -- and it is NOT the pellets' spread and
NOT the card's mapping. Both were candidates in the dispatch; both are refuted by readings in
`reviews/task-282/MEASURED.md`:

- the pattern measures 1.8 x 1.1 studs at 88.7 studs, which is what `SPREAD_FULL_DEG.Buck = 1.6`
  gives -- correct;
- every one of the eight dots is drawn where `HitLog.Shape.dot` put it, through the measured ink box
  -- correct;
- **and the pellets WERE honest hits** -- round 2's Reviewer refused my first answer for asserting a
  back line nobody had measured, and he was right. Measured: at z -0.21 the drawn back is **1.60**
  and the pellet struck **1.41**, 0.19 studs inside the animal at the withers.

**THE CAUSE IS THE CARD'S RECTANGLE, AND IT IS A SMALLER FIX THAN ITEM 1.** `HitLog.Shape.dot`
normalises y by the **TRUNK** (half-height 1.50); `BoarArt.drawDots` maps the result onto the
picture's whole **INK** box (`Report.imageBox`, v 0.250..0.713), whose top edge is the mane crest at
y 1.74. Three studs of trunk stretched over 3.257 studs of animal, all the error at the top: **an
honest withers hit draws on the mane at every u**, and a hit on the trunk's own top (v = 0) draws ON
the crest line. That is Karen's "bunched on the HEAD/NECK" and her "half outside the silhouette".
The two candidate fixes are one rectangle each -- divide by the drawn extent in `Shape.dot`, or map
the unit square onto the TRUNK's rectangle inside the picture rather than the whole ink -- and
either needs the drawn extent per kind, which is the one thing it shares with item 1.

And the complement, before, all four kinds (round 2, after the Reviewer caught a bug in the probe --
`FilterDescendantsInstances` takes DESCENDANTS, so the drawn mesh was in the box cast and `uncovered`
could not be anything but 0): **49.5 %-59.2 % of every ray that meets a hittable boar meets NO
ANIMAL**, on every kind from every direction. **And the male and the legendary have holes too** --
2.2 %/3.9 % and 1.8 %/3.6 % of the visible animal is a MISS, where the mane crest (1.757) stands
0.107 studs above `ZoneHead`'s top of 1.650. Female 0.2 %, cub 1.9 %. That is the dorsal band task
280a already names for the deer, smaller.

## WHY ITEM 1 DID NOT FIT, WITH THE ARITHMETIC

Turning the trunk off (`TRUNK_HITTABLE = false`) is three characters. **What it costs is everything
that `body` means today**, because the boar's four boxes do not tile the animal: `chest` ends at
z +0.25 and `rear` begins at z +1.10, so an 0.85-stud band of the barrel -- the broadest part of a
broadside boar -- is TRUNK ONLY. Switch the trunk off without adding a `body` box and that band
becomes a MISS, which is worse than the air. So item 1 is the deer's job again, whole:

1. a per-kind mesh fit for four kinds (male, female, cub, legendary -- `male` and `legendary` share
   a model at two scales, `female` and `cub` are their own meshes and are NOT the male scaled:
   measured 1.202/1.401 = 0.858 wide against 2.647/3.257 = 0.813 tall);
2. a `body` box added to `ZONES.ORDER`, which renames nothing but adds a fifth zone part;
3. `TRUNK_HITTABLE = false`;
4. `Report.CONFIG.SILHOUETTE` re-derived -- `tests/server/report_silhouette.spec.luau` recomputes
   every rectangle from `Boar.CONFIG.ZONES` through `Shape.rectOf` and fails the harness otherwise;
5. the specs that encode the OLD contract, each of which asserts the thing that changes:
   `boar_zones.spec.luau` (the exact child list `"ZoneChest,ZoneHead,ZoneLegs,ZoneRear"`, plus twelve
   real rays that expect the trunk to answer `body`), `deer_hitbox.spec.luau:136`
   (`expect(handle.part:GetAttribute("ZonesOnly")).to.equal(nil)` FOR A BOAR), `boar_hit.spec.luau`,
   `boar_behaviour_live.spec.luau`, `weapon_client.spec.luau:1971` ("...AND A BOAR IS UNTOUCHED").

That is task 280's shape, and task 280 was its own task. Doing it in the time left would have meant
committing a half-fitted hitbox with a green suite -- the exact self-identity trap L-121 names, and
the one that let eight "chest" acceptances pass over air across tasks 265-278.

## WHAT I ASK FOR

**TWO tasks, not one, because the measurement split them.**

**282b -- the card's rectangle. Small, and it is the one Karen photographed.** One projection, one
spec, no hitbox change: the dots must land on the drawn animal they are drawn over. It needs the
drawn extent per kind (above) and nothing else from 282a.

**282a -- the hitbox, with task 280's box**, dispatched against the numbers in
`reviews/task-282/MEASURED.md`. The instruments are built and committed
(`reviews/task-282/probes/`): `282-stage.luau` stages a frozen broadside boar of any kind with the
shooter frozen and prints the camera ray's entry in the trunk's own frame, `282-fit.luau` prints the
complement from four directions, `282-pose.luau` puts one kind at the player's eye with the volumes
drawn, and `282-shotcard.luau` fires one real buckshot and dumps every pellet's true `(u, v)` and
its drawn position. Before and after come off the same four.

**Two things the Director should decide, not me:**

1. **Does the boar get a `body` box, or do the four boxes grow to tile the animal?** The deer got a
   `body` part (fifteen volumes in six zones). The boar's `body` is the trunk's fallback today and
   `Report.CONFIG.ZONES` lists it, so a fifth part is the smaller change to everything that reads a
   zone word -- but it is a new part on every boar in a drive.
2. **`legendary` is `male` at `meshScale` 1.35 on a trunk scaled 1.35**, and it is now measured:
   FLANK 53.7 % air, 1.8 % miss -- the male's profile, scaled, as expected. So its boxes can be the
   male's fitted boxes x 1.35 and it needs no fit of its own. The two that cannot share are `female`
   and `cub`: measured 1.202/1.401 = 0.858 wide against 2.647/3.257 = 0.813 tall, so neither is the
   male scaled.

## NEEDS KAREN

Nothing. No click is missing; this is a size problem, not a tooling one.

## 2026-10-27 -- Task 283, the hard stop, and a refuted premise

**Written at the 90-minute hard stop** (dispatch: *"At the hard stop, write ESCALATE.md AT THAT
MOMENT and report"*). The fix is built, measured and committed (`78770e71`); what is NOT done is the
proof Karen's frame asks for, and one of the dispatch's own statements is refuted.

**1. THE DISPATCH'S DIRECTION OF THE ERROR IS WRONG, and it changes what task 282 round 2 concluded.**
The dispatch (and `TASKS.md` 282b) says the rectangle mismatch means *"an honest hit on the withers
draws on the mane at every u"* -- the dot pushed UP. The arithmetic says the opposite. The old male
`box` is v 0.230..0.730 **of the image**, so v = 0 maps to 23.0 % down the PNG, not to its top; the
crest is at the top (row 0). Karen's lead pellet (y 1.41, v 0.030) drew at image v **0.266**
(measured, `hit_card 283` note on the pre-fix run) where the drawn geometry puts it at **0.107**. The
old card drew that withers hit **14 % of the picture's height too LOW**, not too high.

So the rectangle IS two rectangles and the fix is real -- but **the card was not what put her dots up
on the mane. The pellets were up on the mane**: task 282 measured them at y 1.41 on a trunk whose top
is 1.50, honest hits on the withers, and the OLD card drew them lower than they really were. The open
question is therefore **why a shot she aimed at the chest struck the withers**, which is about aim or
about the hitbox (282a), not about the drawing.

**2. NOT PROVEN, and nobody has seen it:** no card frame of any kind was drawn and looked at (rule 5),
and no three-cycle iteration table exists (CORE QUALITY protocol step 2). The proof route the dispatch
named (`282-shotcard.luau`) stages a BOAR with the shotgun only; the Learning Agent's L-121/L-123
note is right that there is no deer-capable staging probe, and I did not build one. What I did
instead was measure the DRAWN geometry of all seven kinds by ray
(`reviews/task-283/probes/283-extent.luau`, `283-flank.luau`) and assert the card's pixels against
the uploaded PNGs' own alpha. That is a stronger instrument for item 1 than one card frame, and it is
not a substitute for Karen's eye.

**3. The harness is RED at the hard stop:** `[harness] FAIL: 32/34 @ 78770e71 (clean tree) scope=all`
-- one named failure, `hit_card.spec` `hind#1`, which is a MEASURED finding for 282a rather than a
bug in the fix (a hit on the hind's raised neck is ABOVE her trunk box, `Shape.dot` clamps it to the
box's top line, and on her picture that line is air at that u), plus one unidentified client error.

**For the Director:** (a) 282b's stated cause needs correcting in `TASKS.md` with the arithmetic
above; (b) the real question behind Karen's sentence -- chest aim, withers hit -- is unanswered and
belongs with 282a or with an aim task; (c) a deer-capable shot-staging probe is still missing and the
next card or deer-shooting task will lose a session to it.

### Round 1's verdict, and why I am stopping rather than starting round 2

`reviews/task-283/RESULT.md`: three blocking findings, and **finding 1 is right and it reverses the
method**. I derived each kind's rectangle from the MESH (the trunk's top as a fraction of the drawn
height) and cross-checked only the stag, where it agreed with the hand-measured back line to 0.014.
The Reviewer checked the HIND against `HitCardInk`'s pixels: her picture's back line is row 18 of 60
(image v >= 0.283) where my geometry says 0.1951, so a hit on her box top now draws 0.09 of the
picture's height ABOVE her back -- and the old 0.276 drew it on ink. **Her card is worse than before
this change.** The artwork's proportions are not the mesh's: her drawn head sits higher over her body
in Karen's picture than in the asset.

That is a decision I should not take at 2.5x the hard stop, because it undoes claim 2 of my own
request: **if the rectangle is measured on the PICTURE it is per-PICTURE, and the cub/female and
calf/hind distinction I argued for disappears** (a cub is the sow's picture; the picture has one back
line). The two candidate answers are (a) measure `v0` as each picture's own back line and accept one
rectangle per picture, with the mesh as a cross-check that must agree, or (b) keep per-kind rows but
require every one of the seven to be confirmed against its picture's pixels, geometry only where the
two agree.

Findings 2 and 3 are also right: the dorsal case asserts the defect as the required state, and two of
my five cases pass with `TRUNK_IN_INK` deleted. Both are fixed by the same thing -- asserting the
NUMBER (the drawn image v of a dot at box v = 0, per kind) instead of "somewhere on a black blob".

**For the Director:** this is one more build round on a question that is now well posed, not a third
unknown. Nothing is merged. `main` is untouched; the branch is `task-283-card-dot` at `234a6c8d`.

## 2026-10-27 -- Task 284: one item open, and it is the Director's own next step

Branch `task-284-boar-fit`, code commit `e71ddef4`, Reviewer **PASS round 1**
(`reviews/task-284/RESULT.md`), `[harness] PASS: 34/34 checks @ e71ddef4 (clean tree) scope=all`.
The first session's entry -- written at a hard stop that was really minute 32 -- is archived at
`backups/ESCALATE-2026-10-27-task-284-hard-stop.md`; everything it listed as open is done.

**STILL OPEN: RULE 5, AND IT IS NOT BLOCKED, IT IS NEXT.** No shot has been fired at a boar with
this hitbox on Karen's path. The dispatch assigns that to the Director's `onray.py` after this
review, so it is handed over rather than escalated -- but it is the step that decides whether Karen's
sentence is true on screen, and L-010 is on record that every prior "fixed" claim on this exact
defect was measured and still wrong on her path. The Reviewer makes the same point and goes further:
with `BOAR_MODEL` on, the zone parts are drawn at `Transparency = 1`, so **nothing this change does
is visible in her game** -- the only thing she can judge is where her pellets connect.

**THE ONE NUMBER TO PUT IN FRONT OF HER BESIDE "AIR 0"** (Reviewer's note, and it is the honest half
of the trade): the flank MISS went from 2.2 % to 24.1 % on the male and from 1.9 % to 46.2 % on the
cub. That is in family with the shipped deer (31-43 %) and it is the trade this task set out to
make -- a miss she can see, instead of a kill in empty space -- but roughly one flank shot in four
at a boar, and one in two at a cub, now connects with nothing.

**NEEDS KAREN:** nothing clickable. Her judgement, after the Director's shoot.

---

## 2026-10-27 — TASK 299, ROUND 1 = FINDINGS (3). STOPPED AT THE DEADLINE, NOT AT A DISAGREEMENT

`reviews/task-299/RESULT.md` @ `8eb985d7`, round 1, three blocking findings. The dispatch allows a
round 2; the deadline (10:26 UTC) does not — a code change costs the full one-player gate plus
`test2` twice plus a review, ~25 minutes from here. So the branch stands at `df70c86b` with the
verdict committed and nothing hidden.

**I AGREE WITH ALL THREE, AND THE FIRST ONE IS THE ONE THAT MATTERS.** I checked each against the
code before writing this:

1. **In the only world that has pads, my fix does not deal the fresh drive at all.**
   `Lobby.onPhase("Scoring")` sets `dismissPending` (`src/server/Lobby/init.luau`), the next
   `Lobby.step` at 10 Hz calls `world.dismissAll()`, the roster is empty ~0.1 s into the scene, and
   `Phase`'s `Scoring` exit then takes `enterWaiting`, not `enterAssigning`. Karen's pad step would
   buy her the results scene of the drive she abandoned and a walk back to the lodge. Nothing live
   caught it: `zz_pad_restart.spec` drives `Match` with no lobby wired (`hasLobby = false` in DEV),
   and the Forest Test is where the lobby exists. **This is a real defect in my design, found by
   reading, and I could not have shipped it.**
2. **The faucet is slowed, not shut.** A withdrawn man's board row is never marked `left`
   (`Score.leave` is called only in `Match.forget`), so the aborted drive still pays him
   `PARTICIPATION = 10` and increments `drivesPaid`. One paid drive per restart cycle (~15-20 s)
   against one per 600 s for a drive that is played.
3. **The `Assigning` arm still skips the per-drive work** (`measureMarkers`, `stats.drives`,
   `driveKills`, the board rebuild), which is 287 round 3's finding 2 — the arm all four runs took.

**WHAT ROUND 2 HAS TO DO** (one task, and it is bigger than "enter Scoring"):
- key the per-drive block on the drive NUMBER changing rather than on the `Assigning` edge, so both
  restart arms run it (finding 3) — that is the shape the dispatch wanted and it needs no lobby;
- pay on the drive-number edge too, and REFUSE the pay-out for a drive an abandonment ended (pass
  `enterScoring`'s `reason`, or mark the abandoned rows `left`) (finding 2);
- and then either keep the fresh drive on the restart's own path, or stop `Lobby`'s dismissal firing
  for a restart-induced `Scoring` (finding 1) — proven with a case that wires `Lobby.onPhase` +
  `Lobby.step` the way `lobby_live.spec` does, because nothing else can see it.

**NEEDS KAREN:** nothing clickable. **For the Director:** 299 is not mergeable; 287 is still blocked
behind it.

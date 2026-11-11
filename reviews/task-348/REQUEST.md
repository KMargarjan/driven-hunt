# Task 348 — a bot stands next to the player after a map stand change, then vanishes

Task: 348
Round: 1
Base: 0c1dd2ac
Code commit: 66de5029955d6560ffaa62606b9be6f1198770b4

Karen, 2026-11-11: *"bug at the begining when I change place on map position standing I can see
bot next to me but then he is gone"*. **Reproduced on her path, measured, fixed, re-measured.**

Harness, one player, clean tree, at the code commit:

    [harness] PASS: 34/34 checks @ 66de5029955d6560ffaa62606b9be6f1198770b4 (clean tree) scope=auto:match

## PLAN (step 0)

**(a) REAL LIFE.** No ballistics figure applies. The rule is a fact about a drive line: **a stand
carries exactly one hunter** — `Bots.Fill`'s own stated reason for `standsFree` (*"two hunters on
one post is one hunter"*). The number is **0** other bodies on the post a player holds.

**(b) MEASURED NOW** — her Forest Test, her flags (DRIVE_BOTS on, STAND_PICK on), base 0c1dd2ac,
served to the place from `driven-hunt-karen`. Probe `<runs-dir>/348-arm.luau` + `348-read.luau`:
a Heartbeat sampler at 10 Hz over the whole 15 s pick window, reading INSTANCE facts only
(`Workspace.DriveBots` roots vs the player's `HumanoidRootPart`). **Two windows, six stand changes
by real mouse clicks on the map's own stand rows**: a bot was within 10 studs of the player in
**188 of 268 samples**, closest **0.8 studs**, `nearMe12=1`.

**(c) TARGET.** **0** samples with a bot within 10 studs, over the same number of changes. 10 studs
because `STAND_RADIUS_STUDS` is 12 — a body inside that circle is "next to me".

**(d) LEVER.** `syncBots` in `src/server/Match/init.luau`, the one writer of how many bots a drive
places:

    2303:  local want = bots.fillCounts(real, config, standsFree)
    2327:  local slots = Match.botSlotsFor(markerSet, place, real, want, config, botLine)
    2328:  local made = bots.fill(slots, nil)

**(e) MEASURED AFTER:** the same probe, same place, same clicks.

## The defect, with every writer named (no guess)

1. `syncBots` is **level**-triggered — called at the end of every `dispatch` — and deals the bot
   hunters' stands out of `hunterLine.picks`, the **live** claim table (`StandPick.picksFor`).
2. `HighSeats.dealLine` sweep A gives the claimant his new stand; sweep B hands the stand he
   **released** to the first bot index whose pass-1 scan finds it free.
3. `Bots.fill`'s *"the same slot, moved"* branch **teleports** that rig onto it (`Rig.place`).
4. The player is **not** carried until `applyStandSettle`, on the `Running` edge — so the rig lands
   on the post his body is still standing on. At `Running` every rig is destroyed and rebuilt and he
   is carried away: *"then he is gone"*.

**Tick/event model.** The rebuild is **edge**-triggered on the drive number; the fill is **level**-
triggered per dispatch. This is **not** a missing reconcile — it is a reconcile running against an
**unsettled input**. `Match.botsNeedRebuild`'s `pickOpen` (task 323) was written for exactly this
hazard — *"a line dealt while a human could still claim would hand a rig the stand he was about to
take"* — but it defers only the clear-and-rebuild, never the fill, which is the path that places a
body.

## Claims

1. **The fix is one pure rule at the owner.** `Match.botFillDuringPick(want, pickOpen)` returns
   `{hunters = 0, beaters = want.beaters}` while the window is open, and its argument unchanged
   otherwise. `syncBots` is its only caller. *Verify:* read `Match.botFillDuringPick` and line 2303.
2. **Beaters are untouched** — they hold the start line through the countdown (task 158/163).
   *Verify:* the `beaters` field in the rule; case 15 asserts both 4 and 0.
3. **Flag off is identity.** `STAND_PICK` off ⇒ `STAND_PICK_SECONDS = 0` ⇒ `Phase.pickWindow` false
   ⇒ the rule returns its argument; `nil` ("nobody measured") is the same. *Verify:* `init.luau:865`
   plus the last two assertions of case 15.
4. **Case 15 has a bite** (`tests/server/match_stand_pick.spec.luau`): with the rule off, the deal
   that follows a change hands the released stand **to a bot**; with it on, no bot hunter is dealt
   at all. Delete `botFillDuringPick` and the case fails. *Verify:* read it; it is `dealLine` over
   this file's own `walkOf("road")`, so it holds no geometry of its own.
5. **BEFORE, her place, base 0c1dd2ac** — 2 windows, 6 changes: `within10=101/135 minDist=0.8
   nearMe12=1` and `within10=87/133 minDist=0.9 nearMe12=1`.
6. **AFTER, her place, code commit 66de5029** — 2 windows, the same 6 changes:
   `within10=0/141 minDist=401.6 nearMe12=0` and `within10=0/146 minDist=150.7 nearMe12=0`.
   The fix was proven present in that place first: `botFillDuringPick(..., true) -> hunters=0 beaters=4`.
7. **CLICK PROOF, her path.** Every change is a real mouse click on a map stand row, and the row
   text turns `FREE` into `YOURS` in the same probe (`11 WEST YOURS`, `3 MAIN YOURS`,
   `7 MAIN YOURS`). No remote was called.
8. **FRAMES, a matched pair, each opened.** `348-before-B-frame.png`: *DRIVE 5 · ASSIGNING · 0:10
   LEFT*, row `2 MAIN YOURS`, caption *"stand 2 is yours"*, a GO HERE diamond on stand 2 and the
   pale YOU circle still on stand 4. `348-after-B-frame.png`: *DRIVE 1 · ASSIGNING · 0:11 LEFT*,
   row `7 MAIN YOURS`, diamond on 7, YOU circle still on 4. The map draws no bot markers in either,
   so the bot is the probe's number and not the picture's — said here rather than implied.
9. **Her settings were never touched.** Attributes read before any action and again at the end:
   token-level diff **EMPTY** (`DHFlag_STAND_PICK=true`, `DHFlag_DRIVE_BOTS=true`,
   `DHFlag_PLACEMENT_IN_PLACE=true`, `DHForestLayout=D1`). The FT ends on :34873 from
   `driven-hunt-karen`, Edit. Nothing was ever checked out in `driven-hunt-karen`.
10. **No flag.** A plain bug fix on today's path; it does not change how bots pick stands, only
    **when** they are dealt one.

## What is NOT verified

* `python tools/studio_mcp.py test2` does **not** pass at this commit. One server spec errors:
  `forest_placement.spec:1310` reaching `ForestTest:2743 spookNearBeaters`, *attempt to call a nil
  value* (`handle.position` on that spec's stub runtime, a path reached only when a real beater
  exists, which needs two players). I did **not** run a control at the merge base, so I make no
  claim about whether it predates this branch — only that this branch touches no `ForestTest` file
  and the one-player run at the same commit is 34/34 with that spec green. It blocks the merge
  gate; the Director decides.
* `DHFlag_PLACEMENT_IN_PLACE` is **true** in her place; the dispatch said "NOT set". Reported, not
  changed.
* `perStand` could not be measured: `GetTagged("DrivenHunt.ShooterPost")` answers **0** in the
  Forest Test (that world provides its markers by function, not by tag). `nearMe12` and `pairs12`
  stand in for it, and both are reported above.

ANSWERED: L-136 no spec in the dispatch's list fired; both harness runs were green first time, count 0.
ANSWERED: L-127 every claim above is MET or carries its own line in "What is NOT verified".
ANSWERED: L-162 the AFTER set is at the code commit, proven present in that place before the trials;
the BEFORE set is at base 0c1dd2ac — a fix cannot have both sides at one commit — and both were
taken in this session, same place, same probe, same clicks.
ANSWERED: L-014 nothing was checked out in `driven-hunt-karen`; the fixed build was served from
`driven-hunt-rev`, which was restored to dacb75e4, and the FT ends on :34873 from
`driven-hunt-karen`, in Edit.
ANSWERED: L-101 the attribute reading was taken BEFORE any action and again at the end; diff EMPTY.
ANSWERED: L-093 deleting `Match.botFillDuringPick` makes case 15 fail.
ANSWERED: L-029 the tick/event model is named above: a level-triggered fill over an unsettled input.
ANSWERED: L-146 the BEFORE runs are not a quiet state — the bot was actually there, at 0.8 studs.

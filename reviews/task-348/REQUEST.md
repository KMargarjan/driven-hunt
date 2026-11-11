# Task 348 — a bot stands next to the player after a map stand change, then vanishes

Task: 348
Round: 1
Base: 0c1dd2ac
Code commit: (filled in the final request)

Karen, 2026-11-11: *"bug at the begining when I change place on map position standing I can see
bot next to me but then he is gone"*.

## PLAN

**(a) REAL LIFE.** No ballistics figure applies; the rule is a fact about a drive line: **a stand
carries exactly one hunter**, which is `Bots.Fill`'s own stated reason for `standsFree`
(*"two hunters on one post is one hunter"*, `src/server/Bots/Fill.luau`). The number is **0** other
bodies on the post a player holds.

**(b) MEASURED NOW.** *Live reading pending: Studio has no place open at 10:14 UTC 2026-11-11
(`get_studio_state: Place is not open`), Karen is restarting it. The reading goes in the final
request and the fix is not claimed proven until it is there.*

The mechanism, read off the code (not a guess — every writer named):

1. `syncBots` (`src/server/Match/init.luau:2303,2327,2328`) is **level-triggered**, called at the
   end of **every** `dispatch` (`init.luau:2594`), and deals the bot hunters' stands out of
   `hunterLine.picks` — the **live** claim table (`StandPick.picksFor`).
2. `HighSeats.dealLine` sweep A gives the claimant his new stand; sweep B then hands the stand he
   **released** to the first bot index whose pass-1 scan finds it free
   (`src/shared/HighSeats/init.luau`, sweeps A and B).
3. `Bots.fill`'s *"the same slot, moved"* branch **teleports** that rig onto it —
   `Rig.place(bot.model, Bots.groundedFrom(from, cfg), ...)`, `src/server/Bots/init.luau`.
4. The player himself is **not** carried until `applyStandSettle`, on the `Running` edge
   (`init.luau:2126`). So between his click and the horn his body is still on the released post —
   and a rig lands on it. At `Running` the deferred rebuild (`botsNeedRebuild`'s `Running` arm)
   destroys and rebuilds every rig and the player is carried away: **"then he is gone"**.

**TICK/EVENT MODEL (L-029), named.** The rebuild is **edge**-triggered on the drive number; the
fill is **level**-triggered per dispatch. This is **not** a missing reconcile — it is a reconcile
running against an **unsettled input**. `Match.botsNeedRebuild`'s `pickOpen` argument (task 323)
was written for exactly this hazard — *"a line dealt while a human could still claim would hand a
rig the stand he was about to take"* (`init.luau:3563`) — but it only defers the **clear-and-
rebuild**. `bots.fill` still runs every dispatch with picks-derived slots, so the guard never
covered the path that actually places a bot.

**(c) TARGET.** **0** bot bodies within 10 studs of the player at any sample in the 5 s after a
stand change, over 5 changes — and **0** bot rigs seated on a stand and then removed inside that
window. 10 studs because `Match.CONFIG.STAND_RADIUS_STUDS` is the circle a hunter is bound to; a
body inside it is "next to me".

**(d) LEVER.** `syncBots`, the **one** writer of how many bots a drive places:

    2287:  if Match.botsNeedRebuild(phase, drive, botsRebuiltForDrive, Phase.pickWindow(...)) then
    2303:  local want = bots.fillCounts(real, config, standsFree)
    2327:  local slots = Match.botSlotsFor(markerSet, place, real, want, config, botLine)
    2328:  local made = bots.fill(slots, nil)

The change is at line 2303's answer: **while the pick window is open, `want.hunters` is 0**. Bot
**beaters** are untouched — they hold the start line through the countdown (task 158/163). At the
window close the `Running` arm already rebuilds every rig from the settled deal, and
`applyStandSettle` has already carried the player, so the bot hunters appear on their final stands
**after** he is on his and never on his. No flag: with `STAND_PICK` off `STAND_PICK_SECONDS` is 0,
`Phase.pickWindow` is false and the change is identity (`init.luau:865`).

**(e) HOW IT IS MEASURED AFTER.** The same probe as (b), same place, same commit.

# Task 306 step B6 -- ISOLATION, THE PICTURE

Task: 306f
Round: 1
Base: task-306b5-isolation-shot @ 7683369c
Code commit: (pending)

## PLAN

CORE QUALITY PROTOCOL: **CORE-NA** (the Director's own line). B6 changes no animal behaviour, no
ballistics, no kill zone and no shot rule -- B5 owns the shot. What it changes is the PICTURE
(`LocalTransparencyModifier`, client-local, not replicated) and the board payload's three fields.
The steps below are therefore stated as owner/instrument, not as a real-life number.

(a) **WHAT IT MUST DO.** Design section 16 row B6 + 4.4 + 9.4 + 9.5: `src/client/Range/Mask.luau`
    hides every range target that is not this player's own station's, and his own while it is
    outside his station's window; `src/client/RangeBoot.client.luau` starts it and hands it the
    board payload's `mine` and `window`; the server adds those two fields beside the shipped
    `position`.
(b) **MEASURED NOW** (before the change): nothing masks anything -- `src/client/Range/` does not
    exist (`ls` empty), `grep -rn LocalTransparencyModifier src/client` names only
    `src/client/Camera/Rig.luau`, and `publish` in `src/server/Range/init.luau` sends
    `{ record = record, lists = ... }` with no `mine` and no `window`. So six men at six stations
    see all six animals.
(c) **TARGET.** Exactly 1 target drawn per occupied station (T3); `Mask.stats().writes` flat across
    60 idle steps and `Cursor.stats().reasserts` unchanged (T12).
(d) **LEVER.** `BasePart.LocalTransparencyModifier`, written in `Mask.apply` and nowhere else in
    `src/client/Range/`; the window predicate is the SHIPPED `RangeData.inWindow`, the same one
    `Range.ignoredFor` reads, so the shot's door and the picture ask one question.
(e) **HOW IT IS MEASURED AFTER.** `tests/client/range_mask.spec.luau` (the live client spec, T12's
    instrument) plus the two click frames; T3 is the Director's two-client step after PASS.

## MUST-FIX THIS STEP ALSO OWNS (306b note (i) / 306c NOT PROVEN item 1)

`src/client/Hud/init.luau` resolved `RangeData.promptFor(1)` only, so 11 of the 12 prompts opened
nothing, and `RangePanel.confirm`/`reset` sent a hard-coded `spot = 1`. Both are fixed here.

# Task 339 -- only the stag leaps: the hind and the calf never jump

Task: 339
Round: 1
Base: d91d65e9
Code commit: TBD

## PLAN (core quality protocol step 0)

**(a) REAL LIFE.** A bound -- all four feet off the ground together -- is the gait a red deer uses to
clear an obstacle (Lingle 1993, `docs/research/2026-10-23-deer-road-leap.md` section 8); a stag
clears a 1.8 m fence routinely. Karen's rule for this game, 2026-11-09: *"deer famale and kid doesnt
jumt you need to remove that only male jump"*. So the number for a hind and a calf is **0 leaps per
crossing**, and the stag's 6.0 studs (1.68 m) stays.

**(b) MEASURED NOW** -- her Forest Test, 215 s, 8 staged `herd@120,-140,60,run` releases, probe
`<runs-dir>/339-instrument.luau` (task 334's instrument 6, unchanged), raw
`<runs-dir>/339-BEFORE-raw.txt`, summary `<runs-dir>/339-BEFORE.txt`. The FT was served from
`driven-hunt-karen` at `5cc51f81`, and `git diff --stat 5cc51f81 d91d65e9 -- src tests tools` is
EMPTY, so this reading is main `d91d65e9`'s code.

| kind | crossings | leaps inside the road band | LEAP lines | median apex | median length |
|---|---|---|---|---|---|
| stag | 16 | 6 | 10 | 5.274 | 20.69 |
| hind | 56 | 9 | 23 | 4.918 | 17.76 |
| calf | 30 | 5 | 21 | 4.428 | 32.78 |

Karen's defect is reproduced: **the hind leaps 23 times and the calf 21 times.**

**(c) TARGET.** hind **0** LEAP lines, calf **0** LEAP lines, both still crossing (CROSS lines > 0);
stag LEAP lines > 0 with apex and length unchanged. Not "smaller" and not "rarer": zero, because
Karen's sentence is that they do not jump at all.

**(d) LEVER.** `MODEL.LEAP.APEX_STUDS` is the one table that says how high a kind bounds, and
`Boar.leapByKind` is the one per-kind overlay of a kind's leap config. `grep -n`:

    src/server/Boar/init.luau:3583:		APEX_STUDS = { stag = 6.0, hind = 5.132, calf = 3.336 },
    src/server/Boar/init.luau:4728:function Boar.leapByKind(config, kind: string?)
    src/server/Boar/Body.luau:1619:	local apex = leap.APEX_STUDS[kind or ""]

The rule becomes **no apex row, no bound**: the hind's and the calf's rows are deleted, and
`Boar.leapByKind` switches `MODEL.LEAP.ENABLED` OFF in the config of a kind whose arc is 0. That is
upstream of every state -- `Brain.leapStarts` (road crossing), `Brain.boundStarts` (spook/flight)
and `intent.leaping` (what `Body` draws) all read that one switched-off table -- so there is no
Hud-side or animation-side hiding and nothing to suppress per state.

**(e) HOW IT WILL BE MEASURED AFTER.** The same probe as (b), `339-instrument.luau`, same place,
same 8 staged herds, at the code commit.

## What changed

(filled in with the claims after the fix)

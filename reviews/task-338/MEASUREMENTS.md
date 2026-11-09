# Task 338 -- the raw probe output, one live session, main 5cc51f81

Forest Test place 130094961655666, cell C1 (exit line z = -5402), 2026-11-09 05:40-05:52 UTC, one
hunter, **no shot fired**. Both probes installed in the same Play session by
`reviews/task-338/338-run.sh`; their sources are beside this file. The two clocks are 4.0 s apart
(the gap between the two installs), so a server `DEL` at +T is the wire entry at +T-4.0.

Transcribed from this session's own stdout (the Play session has since been stopped, so these lines
cannot be re-printed; `338-console-before.txt` in the runs dir is the matching server console).

## Drive 1 -- the three timepoints the dispatch asked for

| drive clock (elapsed) | released (ADD) | left the cell (DEL at the line) | toast / `escape` entries |
|---|---|---|---|
| 15 s  | 6   | 0   | **0** |
| 60 s  | 18  | 0   | **0** |
| 150 s | 55  | 15  | **19** |
| 300 s (drive end) | **130** | **114** | **108** |

Server line at t+300 (counters): `added=130 removed=114 pastExit=114 exitZ=-2377 layout=?`
Wire line at t+300: `escape=108 | escape=108 join=1 phase=3 signal=1`

`exitZ=-2377` in the counter line is the probe's FALLBACK (the layout attribute was not yet
published when it installed) and `pastExit` is therefore not evidence. **The evidence is the z of
each removal**, which the probe logged per animal and which is read against the cell's own exit
line of -5402 printed by the server: `[ForestTest] layout=C1 (rotation): 15 stands 150 apart,
centre (-3899, -5107), exit -5402`.

The first six removals of drive 1, verbatim:

```
+76.8  DEL Boar1  z=-5401   +98.2  DEL Boar7  z=-5401   +114.6 DEL Boar3  z=-5402
+133.9 DEL Boar4  z=-5401   +134.2 DEL Boar20 z=-5401   +134.4 DEL Boar19 z=-5402
```

and the first six wire entries: `+72.8 ; +94.3 ; +110.6 ; +129.9 ; +130.3 ; +130.4`.
Every one of the 114 logged removals read z between **-5397 and -5402**. Across the whole drive the
smallest |z| of any removal was -5397 and the largest -5402.

## The 6 removals that fired no toast

At +338.8/+338.9 nineteen animals were removed in one batch at z = -4940 … -5391 -- mid-field, not
at the line. That is `promote`'s `runtime:clear("layoutChanged")` at the drive-2 layout swap, and it
produced **no** escape entry, which is correct. The same thing accounts for drive 1's 114 - 108 = 6.

## Drive 2 -- the second consecutive drive (L-033)

| drive clock (elapsed) | released | left the cell | toast entries |
|---|---|---|---|
| 61 s  | +34 (164 cum.) | 0 | **+2** (both drive-1 animals reaching the line at +311 s and +315 s) |
| 145 s | +78 (208 cum.) | 0 | **+2** |
| drive end | **+80** (210 cum.) | +61 | **+55** (165 cum.) |

Drive 2 therefore ended reading exactly **"an animal got away x55"** -- the figure the ESCALATE
evidence photographed at `DRIVE 5 · 0:49 TIME` (= 251 s in).

## The frames

* `327d-F1-stand-beaters.png` (the dispatch's evidence, opened): first-person from a HUNTER on
  stand, shotgun up, orange beater in the trees; HUD `DRIVE 1 · 0:11 TIME · 0 ANIMALS · HUNTER ·
  $13500`; bottom-left toast **"an animal got away x80"**; `INF SLUG` bottom-right.
* `338-F1.png` (mine, this session, drive 2 at 87 s, kept in the runs dir): first-person from a
  BEATER, horn in hand, objective *"walk to the road, push animals"*; HUD `DRIVE 2 · 3:33 TIME ·
  0 ANIMALS · BEATER · $13510`; compass with `ROAD 400 m`; `HORN READY`. **The toast area is empty
  -- there is no got-away line on screen.**

The `TIME` field is the same field in both, and it counts DOWN
(`Match.secondsLeft() = phaseEndsAt - GetServerTimeNow()`).

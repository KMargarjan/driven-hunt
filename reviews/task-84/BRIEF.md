# Task 84 — brief for the Architect: the MATCH (several drives), a delta to `docs/design/drive.md`

Written by the Director, 2026-09-27. Decisions already taken; the design must contain what is listed.

## Why now

`ROADMAP.md` Milestone 3: "a match loop with several drives". Karen, 2026-09-27: "core is important" —
the game loop must be complete before any polish. Today a drive loops forever (`Assigning → Running →
Scoring → Assigning`), roles swap each drive, and **scores are zeroed at every `Assigning`**, so a
session never ends and nobody ever wins anything.

## Decisions (Director picks; numbers are changeable `CONFIG` values)

1. **A match is `DRIVES_PER_MATCH` drives, default 4**, so with `SWAP_TEAMS_EACH_DRIVE` every player
   shoots twice and drives twice.
2. **Points accumulate across the match** per player (keyed by `UserId`, as today). The per-drive score
   screen stays and also shows the running match total.
3. **Match end:** after the last drive's `Scoring`, a **match result screen** for `MATCH_RESULT_SECONDS`
   (default 30): ranking by match points, the top player named the winner, ties shared. Then a new match
   starts with all totals at 0.
4. **Joiners mid-match:** take the smaller team at the next `Assigning` (as today), start at 0 match
   points, and are ranked like everyone else.
5. **Leavers:** their points leave with them (no ghost rows on the result screen).
6. **Too few players mid-match:** fall back to `Waiting` as today; the match counter is **kept** (the
   match resumes when enough players return) unless `Waiting` lasts longer than `MATCH_ABANDON_SECONDS`
   (default 120), then the match resets.
7. **Owner:** `ServerScriptService.Match` stays the one writer (the phase machine in `Phase.luau` stays
   pure; the match counter and totals live where the design says, no second writer). The Hud draws the
   result screen (the client replica is read-only, as today).
8. **`MIN_PLAYERS`:** stays 1 in Studio for testing; for a live server it must be 2 (`ROADMAP`
   "before release"). Say how the design keeps both without a flag the harness must flip.

## What the design must contain

- The phase additions (or the counter on the existing phases), with every transition's condition and
  effect, as the rest of `drive.md` does.
- The snapshot fields the client needs (match number, drive k of N, totals, the result list).
- The specs that prove it (pure `Phase` specs for the counter and reset; a server spec for totals across
  drives and the joiner/leaver rules; a client spec that the result screen is visible iff its phase).
- Numeric targets in the numbers table.
- What this change does **not** touch (boars, weapon, map, outfits).

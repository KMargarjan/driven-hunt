# Task 77 — M2.8d: the outfits

Task: 77
Round: 1
Base: `main` (`1be1174`)
Code commit: `3edb986a13e48a640c26cd7252f9ea3fbaab4dcb`

```
[harness]  PASS: 30/30 checks @ 3edb986a13e48a640c26cd7252f9ea3fbaab4dcb (clean tree)
[harness2] PASS: 32/32 checks @ 3edb986a13e48a640c26cd7252f9ea3fbaab4dcb (clean tree)
```

Both are the Director's runs at this branch's head. `src/` and `tests/client/` both changed, so
`test2` is part of the gate. The head is a paperwork commit — at or after the last commit that
touched `src/` or `tests/` (`a5f8feb`), with only `TASKS.md` and this file between them — which only
makes the bound stricter. My own clean-tree `[harness] PASS: 30/30 @ a5f8feb` covers the same code
and reported `[tests:server] PASS: 419 passed` (408 before: eleven new), client 88 (86 before: two
new).

**What changed.** `src/server/Match/Body.luau` (`OUTFIT_NAME`, the `OUTFITS` table, `dressFor`,
`dress`, and the three call sites), `src/server/Match/init.luau`
(`Match.CONFIG.OUTFITS_ENABLED`, and `setTeam` gets the config), `src/shared/Flags/init.luau` (the
`ORANGE_OUTFITS` row), `tests/server/match_outfit.spec.luau`,
`tests/client/zz_outfit_client.spec.luau`, `GAME_DESIGN.md`'s placement row, `TASKS.md` rows 77/77a.

## Claims

1. **The owner is `Match.Body` and nothing else writes an outfit.** Design 10.1's reasoning, kept:
   it is already the only writer of a player's team, of where their character stands and of what is
   attached to it. Three call sites, all inside it — `Body.place`'s `CharacterAdded` handler,
   `Body.setTeam`, and `Body.tie` (the re-tie the design names). `GAME_DESIGN.md`'s placement row is
   amended to say so.
2. **Right item per role.** `match_outfit.spec`, "gives a shooter a hat on the head and a driver a
   vest on the torso": `dressFor("Shooters", ON)` is a hat on `Head`, `dressFor("Drivers", ON)` is a
   vest on `UpperTorso` with `Torso` as the R6 fallback, both RGB(255, 112, 0).
3. **Swapped when teams swap, and never two.** "swaps the item when the team swaps, and never wears
   two": dress as a shooter, then as a driver — one part, named `Vest`, one `HuntOutfit` folder.
   `Body.dress` destroys the folder before it rebuilds, which is also what makes all three call
   sites safe to call again.
4. **Removed on leave and on respawn, structurally.** The folder is parented to the CHARACTER, so a
   respawn replaces it and leaving takes it — there is no cleanup path to forget to run. Asserted
   indirectly by claim 3's rebuild and directly by the flag-off case, which clears it.
5. **Nothing is added with the flag off.** "adds nothing with the flag off, and takes off what is
   already there", plus `dressFor` returning `{}` for `OFF`, for a nil team and for a nil config.
   And the assertion that bites on a real server: **"leaves the live server undressed"** counts the
   running session's own characters and requires zero. A merged-dark path that dresses people is not
   merged dark.
6. **`CanQuery = false` on every part, which is the one this rests on.** A hat that stops a pellet
   changes what the shot hit, and what the shot hit is what `Match.Penalty.judge` reads. Asserted
   server-side over every part of an outfit, and client-side in `zz_outfit_client.spec` over what
   actually reached the client, together with `CanCollide` false, `Massless` true and not anchored.
7. **The flag is a proper row and is read once.** `default = false`, owner
   `ServerScriptService.Match`, born 2026-09-27, `expires = "2026-10-18"` — 21 days, the ceiling —
   and the spec asserts both the default and the expiry bound. `Match.CONFIG.OUTFITS_ENABLED` is a
   **boolean**, and a case asserts it equals `Flags.isOn("ORANGE_OUTFITS")`: one read, at the
   boundary, passed inward, which is what makes every ON case above testable with the flag off.
8. **The first hat measured perfectly and looked wrong (rule 5).** The design's single flat cylinder
   at +0.8 came out as an orange disc at the hair line with the avatar's hair through it
   (`.screenshots/20260927T031301Z-task77-hat-2.png`). It is a brim plus a crown now
   (`...031545Z-task77-hat-b2.png`), and the spec asserts the crown is narrower than the brim and
   that its underside meets the brim's top rather than floating. **Deviation from design 10.2's
   one-row table, recorded as 77a(b).**
9. **Three mutations applied, run and restored.** `CanQuery = true` → two cases fail; the folder not
   destroyed → the swap wears two and the off-case still finds one; **the flag ignored → the LIVE
   player was dressed**, caught by three server assertions and the client spec, with the notes
   reading `1 dressed` and `mine=dressed`. That third one is also the end-to-end proof that the ON
   path works on a real character in a real session.
10. **A harness fragility, reported not hidden (rule 6).** As `outfit_client.spec` this file loaded
    before `weapon_client.spec`, which asserts on what the harness's scripted input had done by the
    time it ran; the same commit came back with 23 slugs instead of 24 and three shots instead of
    two, with nothing about the weapon changed. Worked around by the `zz_` prefix and by scanning
    characters rather than every descendant of a 2,700-tree map. Queued as 77a(a).

## What I could not verify

- **The two-player screenshot the M2.8d row asks for was NOT taken, and the reason is a harness
  bug.** The Director tried and reports it verbatim: *"`python tools/flags.py set ORANGE_OUTFITS on`
  REFUSES 'no such flag ORANGE_OUTFITS' in Edit mode while a Play session resolves it fine —
  QUERY_SET_FLAG's `require(Flags)` in the Edit-mode MCP context returns a module CACHED before the
  flag existed (Rojo updated the Source of the same ModuleScript). That is a harness bug (rule 6);
  the Director queues it as Task 78, and the two-player screenshot is taken after 78 for Karen's
  playtest."*

  That trap has now bitten this project a fourth time — `reviews/task-75/REQUEST.md` records the
  same one layer up (*"Studio's Edit-mode require cache is stale for a module required earlier in
  the session"*), which is why this task's own evidence never went through `flags set` at all.
  **Nothing about this task's code is affected**: `Flags.DEFAULTS.ORANGE_OUTFITS` is asserted by a
  server spec on a running server, and the ON path is exercised by parameter everywhere else.

  I could not take the screenshot either, for a second and independent reason: `test` and `test2`
  both **refuse to start while a flag override is set**, and a two-player session is a human click.
- **The vest has never been rendered.** The single player in a one-player session is a Shooter, so
  every screenshot is of the hat. The vest is asserted on Instances only (77a(d)). **What I could
  photograph, I did**: the hat was captured in Play by flipping the flag's `default` for a throwaway
  run — which needs no override and so is not blocked by either problem above — and that is how the
  halo in claim 8 was found.
- **Whether orange-on-orange reads at eighty metres** is Karen's eye at a playtest, not a
  measurement. Colours and sizes are one line each in `Body`'s `OUTFITS` table.
- **`test2` is the Director's run**, and a second player exercises one path this task adds that one
  does not: two different teams dressed at once.

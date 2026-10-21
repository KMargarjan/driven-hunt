# Task 226 — the flags tool must never touch Karen's place

Task: 226
Round: 1
Base: `main` @ `37dd0e1d` (branch `task-226-flags-pin-dev`, created by the Director)
Code commit: `eaf717a404b620dcce4fe3be0f7536edd2309ffb`

```
[harness] PASS: 33/33 checks @ eaf717a404b620dcce4fe3be0f7536edd2309ffb (clean tree) scope=all
```

`[harness2]` **N/A**: the change touches `tools/` only — no `src/`, no `tests/`. `tools/studio_mcp.py`
is explicitly NOT in `TWO_PLAYER_PATHS` (Director decision 2026-10-03, written into that list's own
comment), and nothing here is about who the OTHER player is.

## What changed, and why

**The incident, 2026-10-21 ~01:50.** Karen's Forest Test place (`130094961655666`) lost four of its
six `ServerStorage` attributes — `DHFlag_COINS`, `DHFlag_DRIVE_BOTS`, `DHFlag_LOBBY`, `DHFlag_SHOP`
— when `flags.py clear` was typed during task 225 to clear the **DEV** place before a harness run.
The cause class was queued as **216b** and had already fired once, in task 201-4.

**The exact line.** `studio_for_role`'s one-entry shortcut, `if len(entries) == 1: return
entries[0]["id"]` — a single-entry listing returned with no place check and no mode check at all.
`run_flags` asked it for `"edit"`, StudioMCP's listing happened to hold only the Forest Test, and
the clear went there. A role is not a place: with two places served by one Rojo project, **both of
them are editors**, so "the first Studio in Edit mode" distinguishes nothing.

Four files: `tools/studio_mcp.py` (the owner), `tools/pose.py`, `tools/flags.py` (docstring),
`TASKS.md` (the 226 row).

## Claims, and how to verify each

1. **`studio_for_place` resolves by a LIVE `game.PlaceId` read, with no shortcut and no fallback.**
   Read it in `tools/studio_mcp.py`: it lists the Studios, asks each for `QUERY_PLACE_AND_NAME`
   through `place_of`, and returns only an exact id match. There is no "the only entry" branch, no
   listing-name branch and no use of `default_studio_id`. A Studio that cannot answer is recorded as
   `unreadable` and is never treated as a match.

2. **Every override WRITE goes through it.** `run_flags`' `set`, `clear` and `show` resolve with
   `studio_for_place` (not `studio_for_role`); `pose.py`'s `clear` resolves its EDIT-place write the
   same way. `grep -n "studio_for_role" tools/studio_mcp.py tools/pose.py` — every remaining caller
   is a READ or a capture (`flags live`, `capture`, `pose.running`), none of them writes a
   `DHFlag_*` or a `DHPose`.

3. **The four dispatch cases are in `selftest` (case 9d) and they FAILED before the fix.** Run
   `python tools/studio_mcp.py selftest`. The cases drive the real `run_flags` against a scripted
   two-place StudioMCP and assert both which Studio was written to and that the output names the
   place id. The same case bodies run against the pre-226 commit in the block below: **4 of 4 fail
   there, 0 of 4 here**, and the DEV-absent case reproduces the incident's own line verbatim.

4. **`--place forest` is the explicit way to write Karen's place, and it is never ignored.**
   `flags set/clear/show --place forest` resolves `130094961655666`; `flags live --place <x>`
   REFUSES (exit 2) when the running session is in another place rather than silently reading it;
   `place_choice` exits with the known list on an unknown word and accepts a raw numeric id.
   Verified live: with only DEV open, `python tools/flags.py --place forest` printed
   `REFUSED: no connected Studio has place 130094961655666 open; connected: 2d853ea5=136410205938347
   (Driven Hunt DEV)` and `nothing was written`.

5. **Every write prints the place id and name, read live out of the Studio it addressed.** Live, with
   BOTH places open:
   `[flags] place 136410205938347 (Driven Hunt DEV), Studio 2d853ea5 -- read live from that Studio, not assumed`
   then `[flags] cleared in 136410205938347 (Driven Hunt DEV): DHFlag_AUTUMN_LIGHT`. Not the
   harness banner — that banner said "defaults to DEV" on the same screen as the deletion.

6. **The label is the one on the Studio title bar, and that needed a second commit.** Measured during
   the gate: before Rojo's Connect the DEV editor answered `game.Name` = `Driven Hunt DEV`; the
   moment the plugin attached it answered `DrivenHunt`, the `name` field of `default.project.json`
   that Rojo writes onto the DataModel. So the **id** is what is matched (live, unchanged) and the
   label is `PLACE_ALIASES`' name for a known id, falling back to the DataModel's own name for one
   we do not know. See commit `eaf717a4`.

7. **The attribute set is recorded BEFORE every write (lesson L-101).** `attr_log` dumps
   `ServerStorage`, `ReplicatedStorage` and `ReplicatedStorage.Viewmodel` plus the place id and name
   to `<runs-dir>/attr-<label>-<ts>.log` before `flags set`, `flags clear`, `pose set`, `pose save`
   and `pose clear`'s edit write. Proved live end to end: `flags.py set AUTUMN_LIGHT off` then
   `flags.py clear` on DEV, and the clear's own BEFORE file holds
   `{"ServerStorage": {"DHFlag_AUTUMN_LIGHT": "false"}, "placeId": "136410205938347", ...}` — the
   state a restore has to diff against, not a read taken after the damage. It never blocks the
   command: a dump that fails prints one line and the clear still runs, because a `clear` that
   refuses leaves the harness unable to start with no way out.

8. **It re-lists before refusing, and that is a measurement not a nicety.** `studio_for_place` retries
   `PLACE_RESOLVE_ATTEMPTS` (5) times. On this machine today, two `flags` calls seconds apart saw two
   different ONE-ENTRY listings — the first held only the Forest Test, the next only DEV. A
   single-shot resolver would refuse a good command about half the time and teach a Director to
   retype `clear` until it went through. The guarantee is unchanged: an answer still has to BE the
   place asked for. A selftest case asserts a refusal asked for the listing more than once; another
   early-out means `pose.py clear` during Play is not made to wait 8 s for an answer Studio has
   already given (`not available in Play mode` for every entry is definite, not a flake).

9. **`studio_for_role`'s shortcut is the second lock, patched explicitly.** It now checks the place
   when the caller names one (`place=`) and the mode when the caller names a role — `edit` must be
   Edit, `server`/`client` must not be. `role=None` still means "whatever is there", so `capture`
   during a Play-solo session behaves as before. Two selftest cases: a lone wrong-place Studio is
   refused for `("edit", place=DEV)`, a lone right-place one is still returned.

10. **The harness pins its own editor by place.** `run_test` and `run_test2` replace
    `studio.query("Edit", QUERY_PLACE_ID) == place` with `studio_for_place(studio, place)` and set
    `default_studio_id` to what it returns, so the flag guard, the pose guard and verdict()'s
    "appeared during the run" checks provably address the DEV place. Same check name, same position,
    stronger claim. The gate ran **with both places connected** and the new line reads
    `[harness] place 136410205938347 (Driven Hunt DEV), Studio 2d853ea5: every unnamed call goes there`.

## The four cases, failing on the pre-226 commit (L-028)

Same case bodies as `selftest` case 9d, run against a worktree of `37dd0e1d`:

```
###### PRE-226 (37dd0e1d) ######
  [FAIL] two Studios, FOREST listed first -> the clear must go to DEV and name the place
         wrote to: ['FOREST']   exit 0
         place printed in the output: NO
         | [flags] cleared: DHFlag_COINS, DHFlag_DRIVE_BOTS, DHFlag_LOBBY, DHFlag_SHOP
  [FAIL] two Studios, DEV listed first -> same answer, place named either way
         wrote to: ['DEV']   exit 0
         place printed in the output: NO
  [FAIL] DEV absent, only Karen's place connected -> REFUSE, write nothing (the incident)
         wrote to: ['FOREST']   exit 0
         place printed in the output: NO
         | [flags] cleared: DHFlag_COINS, DHFlag_DRIVE_BOTS, DHFlag_LOBBY, DHFlag_SHOP
  [FAIL] --place forest -> the Forest Test id, on purpose
         wrote to: ['DEV']   exit 0
         place printed in the output: NO
== 4 of 4 cases FAIL against pre226
```

Note case 2: the pre-226 code wrote to the right place **by luck** — the answer depended on which
way round the listing came. It fails on the second half of the assertion (it names no place), which
is the bug stated exactly.

After the fix, 0 of 4 fail; case 3 is the incident and now reads
`REFUSED: no connected Studio has place 136410205938347 open; connected:
forest-s=130094961655666 (Driven Hunt Forest Test)` with `wrote to: nothing`, exit 2.

## What I could NOT verify

- **A real two-place WRITE collision.** Both proof blocks are driven against a scripted StudioMCP,
  because reproducing the real one needs the listing to hold the wrong place at the exact moment of
  a write, which no run can arrange. The live half that IS real: the flaky listing itself (observed
  twice today), the refusal with only one place open, and a `set`+`clear` round trip on DEV with
  both places connected.
- **`pose.py clear --place forest`, and the pose paths generally, were not exercised against a live
  Studio.** The dispatch says not to touch the Forest Test at all, and `pose set`/`save` need a Play
  session with a gun. The code paths share `studio_for_place` with the flags paths, which ARE proven
  live, but that is reasoning, not a measurement.
- **`flags live --place` refusing a wrong-place session** is unexercised live for the same reason.
- `docs/design/feature-flags.md` sections 2 and 7.2 describe the override mechanism and do not
  mention the place. That is the Architect's file, not mine; queued rather than edited.

## Rule G

`python tools/studio_mcp.py selftest`, `python tools/pose.py selftest`, `python tools/agents.py
selftest`, `python tools/privacy_scan.py selftest` + `scan` — all PASS. No new spec file, so no
`SCOPE_SPECS` entry is needed; `tools/studio_mcp.py` already resolves to `all`.

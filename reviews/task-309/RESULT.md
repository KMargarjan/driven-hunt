PASS (items 1, 2 NOT PROVEN)

Rule 5, stated so this PASS is not read as rule 5 having been met: the core item is shooting. What has
been seen in Karen's place is 180 scripted bench shots in her Forest Test (`placeId=130094961655666`,
`DHFlag_AIM_REWIND=true` and the same thirteen `DHFlag_*` in all five bench files) counted by the
server's own zone; what has NOT been seen is any human firing at an animal on this build, any frame
(the request says "No screenshot", and nothing visual changed), or any of the four dispatch targets met
-- claims 1 and 2 state all four as NOT MET. `src/shared/Flags/init.luau`'s `AIM_REWIND` row reads
`default = false`, and its own comment says it must stay dark "until `SetNetworkOwner(nil)` ... has
landed", so as merged this constant reaches nobody.

Checked and true: harness line names `Code commit: ea709503` with "(clean tree)" and
`paperwork-after-code-commit.txt` reads OK; `Weapon.rewindFor` returns 0 before `cfg` is read
(`if rewindPolicy == false or (rewindPolicy == nil and not REWIND_ON) then return 0`), with a red-able
case ("is 0 when the policy says off"); claim 4 -- `changed-files.txt` contains no `src/server/Boar/`
path; the five `trail()` keys are literals (`rewind-zero`, `no-provider`, `no-roots`, `no-history`,
`rewound`) and every call site is inside `if STUDIO then`; `run_cell`'s new format string is 17
placeholders against 17 arguments in order; every per-cell rate in claim 1 is the `hit=True` count in
its own rows (after-A 17/27/2, after-B 27/16/28/2, diag-A 5/21, d6 0/5/0), the pools 5/36, 26/36,
55/60, 4/60 and the z of 3.67 and 2.54 all recompute; `summarise`'s empty-note branch (CONTROL >= 0.50,
KNOWN-BAD <= 0.20, disjoint Wilson intervals) is what prints the `Self-check:` line in after-A,
after-B and d6, and `bench-after-A.json`'s `"notes": []` corroborates after-A's.

Producer deletion, duty (a): revert `FLIGHT_REWIND_BASE_SECONDS` to 0.18 and the AFTER cells read as the
BEFORE ones -- the two sides are not the same engine identity (see note 1 for what separates them).
`tests/server/weapon_rewind.spec.luau` asserts against `CONFIG.FLIGHT_REWIND_BASE_SECONDS`
symbolically and so survives the revert, which is exactly what claim 6 says it does, so it is not
offered as proof of the fix.

## Notes (non-blocking)
- `reviews/task-309/REQUEST.md` claim 1, the BEFORE column label — "BEFORE `8e5c0f76`" is the
  game-code commit only; the tool was already patched. `bench-diag-A.txt` and `bench-d6.txt` rows print
  `across=... aim=... impact=...`, which only `run_cell`'s format changed in `eb4be65f` emits
  (`tools/aim_bench.py`, the diff's one hunk), while `bench-before-A.txt` row #1 prints the old
  `along=... up=... card=(...)` and so is the only before file consistent with `8e5c0f76`. What
  separates the two sides of the comparison is the `gen` sequence -- before-A `gen=2`, diag-A `gen=3`,
  d6 `gen=4`, then after-A `gen=1`, after-B `gen=2`, i.e. a session restart where a Rojo-synced module
  change takes effect -- and nothing in any row, header or JSON names the build or the constant. Print
  the live `FLIGHT_REWIND_BASE_SECONDS` in the header beside the thirteen `DHFlag_*` (the same
  mechanism already reads those), and label the before column with the tree it actually ran on.
- claim 1, "dropping it is the conservative direction" — it is the opposite. Including before-A gives
  the BEFORE chest 11/66 = 17 %, a HIGHER before rate and a SMALLER move (z = 4.00, which is what
  `ESCALATE.md`'s own table prints); dropping it gives 14 % and a bigger move. The drop is right on
  admissibility and wrong on this justification. The strongest form of the claim is the one the request
  does not use: `bench-d6.txt`, the only fully self-checked BEFORE run, reads chest 0/6 against
  after-A's 17/30, which is significant on its own.
- claim 1, `bench-diag-A.txt` called "admissible" on its CONTROL alone — it has no `rifle/run/ahead~boar`
  rows at all (the file ends at `CELL rifle/run/ahead~boar` / `held=Rifle`), so `summarise` would have
  printed "NO KNOWN-BAD CELL RAN -- nothing proves the rig can miss" for it. Say so: the entire BEFORE
  pool's negative control is d6's `0/6` at n = 6.
- `ESCALATE.md` 2026-10-29 and `TASKS.md` row 309 still carry the pre-drop pool that claim 1 rules
  inadmissible — "RUN chest centre | 11/66 = **17 %**", "CONTROL | 40/66 = **61 %**", z 4.00/4.04, and
  "STAND chest centre | 29/30 = **97 %**" as a BEFORE reading. `ESCALATE.md` is what the Director reads
  to choose 309a's instrument; it should carry 5/36, 26/36 and "no admissible BEFORE for STAND".
- `docs/research/2026-10-28-lag-compensation.md`, "What this does NOT explain" — the shipped budget is
  built on the inadmissible run ("a chest-centre shot at a RUNNING boar at 20 % and the same shot plus
  `Ballistics.leadStuds` at 47 %" is before-A alone), and its row "slug cone, 0.16 deg full at 130 studs
  | 0.18 | `Shotgun.CONFIG.SPREAD_FULL_DEG`" cites the wrong gun: every cell in all five files is
  `rifle/...` with `ammo=Slug`, and `src/shared/Rifle/init.luau` reads `SPREAD_FULL_DEG = { Slug = 0 }`.
  Both are disclosed and queued as 309a(b); this is the one shipped deliverable document, so fix it
  before the budget is read as measured.
- `bench-after-A.txt` and `bench-after-B.txt` were edited after the tested code commit — `log.txt` shows
  `bench-after-A.txt | 2 +-` and `bench-after-B.txt | 2 +-` in `e01c7f6c`, and those two are the only
  bench files carrying a `written: <runs-dir>/309/after-*.json` line. Editing a captured log after
  capture is indistinguishable from fabrication unless the edit is stated; say what was changed. (The
  tables themselves hold up: both reproduce from their own rows, and after-A's from its JSON.)
- claim 6 cites `Weapon.rewindFor` for two off-states but only one has a case: `weapon_rewind.spec`
  covers `setRewindPolicy(false)`; the `rewindPolicy == nil and not REWIND_ON` half is module state and
  is not reachable from a spec, so it is read-verified only.
- claim (d)'s pasted grep cites `src/server/Weapon/init.luau:581`; the read site is at 588.

---
REVIEWER verdict on commit `e01c7f6caa8172c0bdea7ac189f1963fc0f81f74` (round 2) · 2026-10-29 04:27 UTC · session cost $3.08, 34 turns · written by tools/agents.py

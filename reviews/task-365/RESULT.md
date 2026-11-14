PASS

Rule 5, stated so this PASS is not read as rule 5 having been met: nothing was seen in Karen's place,
and no item of this task is a core item. Verified, not assumed: `Flags.problems` in
`src/shared/Flags/init.luau` is the ONLY reader of `expires` in the whole of `src/` (grep for
`problems` across `src/` returns `Light.problems`, `Poses`, `Shop`, `Viewmodel` and the Flags
definition — no boot script calls `Flags.problems`), and `Flags.publish` replicates flags + `Digest`
+ `Source` only, never a date. So no drawn thing, no animal behaviour and no shot path can move with
these four strings. The four rows' `default` is still `false` and the STAG row's boundary
(`CONFIG.KINDS.stag.spook.bound == Flags.isOn("STAG_BOUND_ON_SPOOK") == false`, `deer.spec`) still
asserts dark. Nothing in Karen's place needed opening and none was opened.

Checked directly, not taken from the request: all four rows (`HIT_CLAIM`, `RANGE`, `RANGE_SOLO`,
`STAG_BOUND_ON_SPOOK`) now read `expires = "2026-12-01"` with `default = false`, `owner`, `born` and
`why` unchanged; `2026-12-01` is the only such date among the 30 declared rows and the four `MOVED to
2026-12-01` comments sit in exactly those four rows; no other test or tool pins any of the four old
dates (`2026-11-14|15|17|20` across `tests/`, `src/`, `tools/` returns only comment text and task
364's own row); `src/shared/Flags/` and `tests/server/deer.spec.luau` are absent from
`TWO_PLAYER_PATHS` in `tools/agents.py`, so claim 9's N/A holds; the harness line names the request's
`Code commit:` `0b2069d3642a84d511ff6cd186837a91f279e044`, is "(clean tree)" with `scope=all`, and
`paperwork-after-code-commit.txt` says OK (only `TASKS.md` and `REQUEST.md` followed it); selene and
stylua are clean in the evidence.

Delete the producer: revert the four `expires` lines and `deer.spec`'s
`expect(row.expires).to.equal("2026-12-01")` fails ("Expected 2026-12-01, got 2026-11-14"), and
claims 1-3's diff/grep return nothing — those cases do not survive the deletion. Note 2 names the one
place where no case fails under the deletion.

## Notes (non-blocking)
- `reviews/task-365/REQUEST.md` claim 4 / `ANSWERED: L-127` — "The live game agrees with the file"
  and "two instruments" overstate the instrument count for the dates. `tools/flags.py` is "a THIN
  WRAPPER ... All of the logic ... live in `tools/studio_mcp.py` (`run_flags`)", and `run_flags`
  builds its rows from `declared_flag_rows()` → `flag_rows_in_text`, whose own docstring says "PARSED
  FROM THE FILE, NOT EVALUATED IN STUDIO (Task 101)". Only the `override` column (and therefore
  `effective`) is a live read of the `DHFlag_*` attributes; `expires` and `default` are the same file
  text the diff shows, through a second name, so they cannot disagree. The live game carries no date
  at all. Fix: say the live read confirms `override none` / `effective off` and nothing more.
- `src/shared/Flags/init.luau` + `tests/server/flags.spec.luau` — nothing fails if `HIT_CLAIM`,
  `RANGE` and `RANGE_SOLO` are reverted. The tripwire is `elseif ... row.expires < today`, so on
  2026-11-14 the old `2026-11-15`/`-17`/`-20` are all future and even `2026-11-14` is not `<`
  `2026-11-14`; claim 8's green gate is byte-identical with those three dates put back. Only the STAG
  row is pinned anywhere. `Flags.problems(defaults, today)` takes `today` as a parameter, so one line
  in `flags.spec` — `expect(#Flags.problems(Flags.DEFAULTS, <today + 7 days>)).to.equal(0)` — would
  make "no row rots this week" assertable instead of a thing someone has to remember. Beyond this
  dispatch (rule 4), so: queue it. Not blocking because the EXPIRED branch itself is already proved
  against a synthetic row in flags.spec's "problems() catches each fault it is there to catch", and
  the four values are verifiable by reading the rows.
- `src/shared/Flags/init.luau`, the `HIT_CLAIM`, `RANGE` and `RANGE_SOLO` rows — each keeps the line
  `-- 21 days, the ceiling in docs/design/feature-flags.md section 12.` directly above a date that is
  37, 35 and 32 days from its own `born`. Design §12 states the target as "**≤ 21 days** from `born`
  to `expires`" and §11's Rot row licenses the move, so the dates are legitimate; the three comments
  now read as a false arithmetic claim. The STAG row's trailing comment was reworded ("inside the
  21-day ceiling") and these three were not — same fix, three lines.
- `src/shared/Flags/init.luau`, the four rows' `why` — design §11 step 6b wants the new `expires`
  carried by "a one-line reason in `why`", and task 364's own `DEER_ROAD_LEAP` row put it in both
  places (`why = "... DATE MOVED 2026-11-14 (task 364): still held dark ..."`). Task 365 put it in
  comments only, and claim 1 offers the untouched `why` as a virtue. The dispatch did ask for "a
  one-line comment", so this followed instruction — but `run_flags` prints `row["why"]` and not the
  comments, so the Director reading `tools/flags.py` to make the keep/retire call sees no sign the
  date was moved or why.
- `reviews/task-365/REQUEST.md`, the no-screenshot bullet — "The four rows stay `off` and `effective
  off`" is unqualified, while `tools/terrainbake.py` carries `KARENS_FLAGS = ("GRID_PREVIEW",
  "RANGE_SOLO")` with "Karen has set on purpose in the Forest Test". The MEASURED table's override
  column is the DEV place's (136410205938347) and her place was correctly not read, so `RANGE_SOLO`'s
  effective value there is unknown. It changes nothing — no runtime path reads `expires` — but the
  sentence claims more than the measurement covers.
- `reviews/task-365/REQUEST.md`, "What I could not verify" — the unnamed single server failure in the
  middle run at `0b2069d3` is disclosed honestly and answers L-136, and this change cannot be its
  cause (no runtime reader of `expires`; the one case that reads it is deterministic in its `today`
  argument). Queue a named re-run so the flake has an identity before it lands in a round where it
  matters.

---
REVIEWER verdict on commit `f508fba5894aa61db4f09adc634edb0be98d4179` (round 1) · 2026-11-14 01:56 UTC · session cost $1.80, 35 turns · written by tools/agents.py

# Task 101 -- the harness works when execute_luau cannot require

Task: 101
Round: 1
Base: task-99-new-gun (`208e70a`)
Code commit: c102a7c5ab1ea854f7b9f6cc65b37e866fe127dc

```
[harness]  PASS: 32/32 checks @ c102a7c5ab1ea854f7b9f6cc65b37e866fe127dc (clean tree)
[harness2] FAIL: 10/11 checks @ c102a7c5ab1ea854f7b9f6cc65b37e866fe127dc (clean tree)
```

**The two-player line is not a pass and this is not ready to merge.** It failed BEFORE anything was
run, twice, on "A 2-player local test appeared within 180 s (0 new studio(s) beside the editor)" --
nobody pressed Start, because the automated F7 did not land during the run. It is not this task's
code: the one-player run is green at the same commit, and those 32 checks exercise every path this
task rewrote. See the report's "Needs".

## Claims

1. **Nothing the MCP thread sends requires or invokes any more.** Verify: `selftest`'s "no query
   sends `require` or `:Invoke`", which walks every `QUERY_*` constant -- a property of the source,
   checked in CI where there is no Studio. The four crossings and their replacements are in the
   docstring with the measurement that forced them, dated 2026-10-02.
2. **A JSON module is compared by its SOURCE, parsed back.** `luau_table_value` reads Rojo's
   generated table literal and `same_json` compares it with the file. It is a parser of Rojo's
   output, not a copy of its formatter, so indentation, key order and number spelling are free to
   change. Verify: `selftest` round-trips the shipped `poses.json` and refuses four malformed
   inputs; the live `[harness]` run compares the real one.
3. **The flag table comes off the file, the overrides off Studio.** Verify: `python tools/flags.py`
   printed all six rows with defaults, expiries, owners and whys; `set NEW_GUN on` wrote it and the
   table then showed `override on`; `set NOPE on` was refused by name against the file; `clear`
   removed it. `selftest` drives `run_flags` against a scripted Studio for each.
4. **The two Task 78 checks are gone, not replaced, and the reason is written down.** What they
   protected -- a stale `require` handing back a flag table missing a flag the file had just gained
   -- cannot occur when nothing requires. What stands behind "Studio has the file the repo has" is
   check 4's byte-for-byte Source comparison, which says it of the flag module and of every other
   synced file. Verify: the docstring, and the check count falling 34 to 32.
5. **The stage asks the camera by attribute, and the clear is the handshake.** `Camera` watches
   `DHLookAt` on the LocalPlayer, aims through the same `Camera.lookAt`, then clears it; the stage
   reports the same failure the old `Invoke` returned false for. Verify: `selftest`'s stage cases --
   which caught their own fake routing the new query to the wrong answer -- and that `Camera.Rig` is
   still the only writer of `workspace.CurrentCamera`.
6. **The streaming radius is read in Python, off `src/shared/Map/init.luau`.** NOT off Workspace:
   Luau cannot read that property, an older `selftest` guard still proves it, and that guard caught
   the first version of this change. Verify: `map_streaming_radius() == 1024` and the guard.

Not verified: the two-player run. Everything else this task touched is exercised either by the green
one-player run or by `selftest` with no Studio at all.

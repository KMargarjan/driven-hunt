# Task 101 -- the harness works when execute_luau cannot require

Task: 101
Round: 1
Base: task-99-new-gun (`208e70a`)
Code commit: 675da419b20d9eb315b422e7add1950f7b8b2090

```
[harness2] PASS: 34/34 checks @ 675da419b20d9eb315b422e7add1950f7b8b2090 (clean tree)
[harness] PASS: 32/32 checks @ 675da419b20d9eb315b422e7add1950f7b8b2090 (clean tree)
```

Both run by the Director at this branch's head, which is the request commit itself: only paperwork
follows the last code change (`c102a7c`), so the evidence covers everything under it (git step 4).

The earlier `[harness2] FAIL: 10/11` -- "0 new studio(s) beside the editor" -- was Studio's own
player count reset to 0 by the restart, not a code fault; set back to 2, the run is green.

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

Not verified: nothing. Every path this task touched is exercised by one of the two green runs or by
`selftest`, which needs no Studio at all.

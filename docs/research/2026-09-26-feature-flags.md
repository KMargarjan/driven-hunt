# Research: feature flags (Task 52)

Written 2026-09-26, by the Builder, **while building** — the design
(`docs/design/feature-flags.md`, Architect, Task 51) already carried the external survey in its §9,
so rule 1's survey is not repeated here. What this note adds is the part only a run could produce:
**the two measurements the design could not make** (its §15), the numbers §12 asked for, and what
came out different from what the design assumed.

Design: `docs/design/feature-flags.md` · Brief: `reviews/task-51/BRIEF.md`

## What the system must do

Feel-critical work (shooting, camera, penalty, the map switch) used to wait for Karen's playtest
before merging, so ten PRs stacked on one unmerged PR. A flagged path must **merge as soon as it is
reviewed and green, switched OFF**; the Director turns it ON for a playtest **without a commit**;
Karen's OK flips the default in a later three-line commit. Both sides of the wire must agree on a
flag's value, specs must be able to test both states, and a run made under an override must never be
reported as evidence for the reviewed build.

## Sources

The design's §9 survey is the sources list and is not duplicated. The two that decided the shape of
what was built:

1. **Pete Hodgson, "Feature Toggles (aka Feature Flags)"** —
   <https://martinfowler.com/articles/feature-toggles.html>. Maintained article on martinfowler.com,
   no licence needed (prose, cited not copied). **Good:** names the failure this repo is at risk of —
   toggle debt, the flags nobody removes — and prescribes the fix as a process one (an owner and an
   expiry per toggle), not a technical one. **Bad:** it assumes a deployment pipeline with a config
   service; none of its delivery mechanisms transfer to a Roblox place.
   **Adopted:** `born`/`expires`/`owner`/`why` per row, and expiry as a **build failure** rather than
   a reminder — `Flags.problems` is called by `tests/server/flags.spec.luau`, which fails the harness,
   which blocks the merge gate.
2. **Roblox attributes and `RunService:IsStudio`** —
   <https://create.roblox.com/docs/studio/properties#attributes>,
   <https://create.roblox.com/docs/reference/engine/classes/RunService#IsStudio>. First-party,
   current. **Good:** attributes are replicated with their instance and are typed; `IsStudio` is the
   one honest "am I on a developer's machine" test. **Bad:** the docs do not state what a *Studio
   play session* inherits from the *edit* DataModel, which is exactly what the override mechanism
   rests on — hence measurement 2 below.
   **Adopted:** the mirror is attributes on a Rojo-owned `Configuration`; the override is attributes
   on the `ServerStorage` service, read only when `IsStudio()`.

**Borrowed, not invented (rule 2):** the lifecycle, the expiry tripwire and the "read at the
boundary, pass the value inward" rule are all Hodgson's. The transport is Roblox's own. The only
piece with no external model is the `Digest`-written-last protocol, and it is a straight copy of the
harness's own sync-token idea already in this repo (`tools/studio_mcp.py`): one value written last
whose presence means "the set before it is complete".

## The two measurements the design could not make (its §15, items 1 and 2)

Run 2026-09-26 in Studio on the DEV place, before a line of flags code was written, with a throwaway
`Folder` the server created in `ReplicatedStorage` during Play and destroyed afterwards. Nothing was
written to disk, and the Edit-mode attribute was cleared either way.

| # | Assumption | Result |
|---|---|---|
| 1 | Attributes written by the **server** on a `ReplicatedStorage` instance replicate to **clients** | **CONFIRMED.** The client read `Digest=probe-digest-1 SOMETHING_OFF=false TIE_UNTIL_DRIVE_END=true` — booleans and strings both |
| 1b | …and a **later change** replicates too | **CONFIRMED.** After the server set `SOMETHING_OFF=true` and rewrote `Digest`, the client read `Digest=probe-digest-2 SOMETHING_OFF=true` |
| 2 | An attribute set on **`ServerStorage` in Edit mode** reaches the **server process of a Play session** | **CONFIRMED.** The play server read `isServer=true isStudio=true bool=true str=edit-side` |

**So the design's §5 replication path stands and no fallback was needed.** The named fallback — a
`StringValue` child of `State` holding the digest — was not built, and `Flags` has no code for it.

Measurement 2 was made with **one player (F5)**. The **two-client** half (Karen's F7 "Server and
Clients") is the Director's `test2` run: the same mechanism carries it, but that is inference until
`test2` is green, and it is listed as unverified in `reviews/task-52/REQUEST.md`.

Design §15 item 3 — "does harness check 4 fail on an *extra* attribute on `State`" — was **not**
probed. Nothing lost: nothing writes `State` in Edit, and the two new guard checks cover the case the
question was really about.

## The numbers (design §12), measured

| Target | Design | Measured |
|---|---|---|
| Live flags at once | ≤ 12 (`MAX_FLAGS`) | **1** declared (`TIE_UNTIL_DRIVE_END`) |
| Resolution cost per process | ≤ 1 ms at boot | **reported by `flags: … ms per all()`** in the server spec's note; `Flags` itself warns if the first, real resolution exceeds 1 ms, so the budget is enforced in production and not only in a test |
| `Flags.isOn` | one hash lookup, 0 allocations | a table index by construction (`Flags.all()[name]`), called once per consumer per boot |
| Publish | 1 instance, ≤ 14 attributes, ≤ 1 KB | **3 attributes** (1 flag + `Digest` + `Source`); the spec asserts the count is exactly `#flags + 2` |
| Client wait for the mirror | `WAIT_SECONDS = 10`, target 0 timeouts | 0 timeouts: every client spec run asserts `source() == "published"` |
| Harness overhead | ≤ 2 s per run (two constant queries) | two `execute_luau` calls; an `execute_luau` against Edit was measured at **0.067 s** in Task 50, so this is ~0.13 s |
| Default flip diff | ≤ 3 lines in one file | 1 line (`default = true` → `false`) plus a dated reason |
| Overrides during a run | exactly 0, before and after | two checks, and the "before" one was **proved to bite**: with `DHFlag_TIE_UNTIL_DRIVE_END=false` set, the run stopped before Play with `FAIL: 3/5 checks`, exit 1 |

## Where the built thing differs from the design, and why

1. **`tools/flags.py` exists.** The design put the `flags` command in `tools/studio_mcp.py` (§7.2);
   the Director's dispatch asked for `python tools/flags.py set <flag> on|off` and `clear`. Both:
   every line of logic, the Edit-mode gate and the MCP transport stay in `studio_mcp.py`
   (`run_flags`), which remains the one owner of the `DHFlag_*` attributes, and `tools/flags.py` is a
   thin wrapper over it — the same shape `tools/review.sh` already has over `tools/agents.py`. The
   two names are one implementation.
2. **`State` is found through `script`, not by searching `ReplicatedStorage`.** It is a child of the
   `Flags` module folder, so `script:FindFirstChild("State")` is the whole lookup: one file, one
   instance, and Rojo owns both.
3. **The client's wait uses the signal *and* a deadline**, as §5 says, with a connection that sets a
   flag and a 0.05 s poll that bounds it. A bare poll would cost an interval of latency on every
   boot; a bare `signal:Wait()` would hang a client for ever if the server never published.
4. **`Flags.resolve` uses `table.clone`.** Selene's `manual_table_clone` lint asked for it, and it is
   better than the hand-rolled loop the design sketched: it is shallow (right for a map of booleans)
   and it returns an *unfrozen* copy of a frozen argument, which is exactly what applying overrides
   to it needs.
5. **A hazard StyLua introduced, and the fix.** Two spec statements began with `(` on the line after
   a `local x = {…}`; StyLua removes the guarding semicolon, and Luau then reads the pair as a call
   on the table. Rewritten to build the row through a named local, so no statement in either new spec
   starts with a parenthesis.

## What is still not proved, and cannot be by the harness

* **A published (non-Studio) place ignores `DHFlag_*`.** No harness run can make `IsStudio()` false.
  It is proved only through the injected parameter (`Flags.readOverrides(host, false)` returns `{}`
  with an attribute present). This is why the test is a parameter rather than a call.
* **`flags set` / `clear` / `live` are not covered by the harness.** The harness cannot test its own
  subcommand, and `live` needs a running Play session. `set`, `clear`, the two refusals (an unknown
  flag, a value that is not `on`/`off`) and the guard were driven by hand; `live` was not, and is
  listed unverified.
* **While a flag is OFF, CI and the harness run the on-disk defaults only.** A dark path's wired,
  live behaviour is proved by the Director's override plus Karen's playtest, and by pure specs before
  that — never by the harness. A dark path whose pure core is not fully unit-tested is not ready to
  merge, flag or no flag.

# Design: feature-flags (merge dark, switch on for a playtest, flip the default in git)

Task 51. Written to `reviews/task-51/BRIEF.md` (Director, Karen green-lit 2026-09-26), which overrides
anything older in `docs/`, `TASKS.md` and any earlier design. Rules referenced are `CLAUDE.md`'s.

**The problem this exists for**, in the brief's words: feel-critical work (shooting, camera, penalty,
map switch) waited for Karen's playtest before merging, so ten PRs stacked on one unmerged PR. The
stacking is visible in `TASKS.md` (row 24: "**reviewed: PASS, 2 rounds. NOT MERGEABLE until Karen
plays it**"; row 18: "Branch `task-18-boar-ai`, **stacked on `task-17-test-area`** because Task 17 is
not on `main` yet"). The goal is that a reviewed, green change **merges immediately with its new path
switched OFF**, the Director switches it ON in Studio for Karen, and Karen's OK becomes a later
three-line commit.

---

## 1. What the system must do, and what it must not do

### 1.1 Must do

1. Hold **one boolean per dark code path**, declared exactly once, on disk, in git, reviewed as a
   diff — with the flag's owner, birth, expiry and one line saying what ON does.
2. Answer "is this path live" identically on the **server and every client**, over a **named**
   replication path, with no new remote.
3. Let the **Director** turn a flag on and off **for one Studio session** without touching the git
   tree (the harness refuses a dirty tree: `tools/studio_mcp.py`, `run_test`/`verdict`, exit 3 "PASS
   on a dirty tree, which is **not valid evidence**").
4. Make an override **impossible in a live server**: the override is read only when
   `RunService:IsStudio()`, and the Studio test is an argument to a pure function so a spec can prove
   the production branch without leaving Studio.
5. Make it **impossible for the harness to run against an overridden flag**: the run refuses before
   Play, and refuses again if an override appeared during the run.
6. Let specs assert **both states of a flag with nothing to restore afterwards** — no live global is
   mutated, so no failure can leak a state into the next spec (the failure to avoid is audit-004 F1,
   whose fix is visible in `tests/server/zz_drive_boundary.spec.luau`, the
   `it("falls back to the weapon's own rule when the drive's policy errors (32a(d))")` block: it
   installs a throwing policy through `Weapon.setArmingPolicy` and had to be rewritten so the restore
   is reachable even when an `expect` abandons the `it`).
7. Say, out loud and once per process, which set it resolved and where it came from.
8. Have a written retirement: a flag that defaults ON and is accepted is deleted, and the dead branch
   is archived, never deleted (rule 7).

### 1.2 Must not

1. **Must not hold game numbers.** Flags are booleans only. Karen's feel values stay where their
   owners already keep them (`Shotgun.CONFIG` in `src/shared/Shotgun/init.luau`, `Match.CONFIG` in
   `src/server/Match/init.luau`, `Drive.CONFIG` in `src/shared/Drive/init.luau`,
   `Boar.CONFIG`, `MapGen.Settings`). A flag system that swallows numbers becomes a second owner of
   every config table — exactly the "overlapping owners" failure in `docs/PROJECT_CONTEXT.md`.
2. **Must not be per player.** No targeting, no percentage rollout, no experiment buckets. One value
   per place, per session.
3. **Must not change at run time.** Resolution happens once per process, at require time, and the
   result is deep-frozen. No listener, no re-resolve, no flag flip mid-match.
4. **Must not be read per frame.** A flag is read at the owner's boundary and passed inward as data.
   No `Flags.isOn` inside a `RenderStepped`/`Heartbeat`/`Stepped` callback, and none inside a pure
   module — pure modules keep taking `config` as a parameter, which is already this repo's rule
   (`src/server/Match/Penalty.luau` header: "PURE — no service, no Instance, no clock, no Player, no
   Random; `config` is a parameter, not a lookup").
5. **Must not gate anything that protects the game.** Never a flag on the test gate
   (`TestKit.openToken`), the request validators (`src/server/Weapon/Validator.luau`), the rate
   limits (`Limits`), the place check (`servePlaceIds`), or anything whose OFF state would let a
   client do something the server should refuse. A flag may gate a *new* rule; it may never disable
   an existing check.
6. **Must not offer a test seam that writes the live set.** There is no `Flags.setForTests`, no
   `Flags.override`, no mutable table. There is nothing to restore, so nothing can leak.
7. **Must not read a network service.** No DataStore, no `HttpService`, no Open Cloud. The defaults
   are the repo; a value that cannot be reviewed in a PR is not a value this project has.
8. **Must not need a `default.project.json` change.** Every new file lands under paths Rojo already
   maps, so no Rojo restart and no Karen **Connect** click (the reason Task 6 put its scenarios in a
   `.txt`: `TASKS.md` row 6).

---

## 2. Owner, and the files on disk

Rule 3: exactly one writer, named. This system has **three distinct things** and each gets one owner.

| Thing | Owner (the only writer) | Location |
|---|---|---|
| The flag **declarations and defaults** (the reviewed truth) | **nobody at run time.** Frozen data; the Builder edits the file and git records it. Same shape as the map contract row in `GAME_DESIGN.md` ("**nobody at run time.** It is frozen data with no writer at all") and as `Shotgun.CONFIG` | `src/shared/Flags/init.luau` → `ReplicatedStorage.Flags` |
| The **published mirror** every client reads (`ReplicatedStorage.Flags.State` attributes) | `ServerScriptService.FlagsBoot`, the only caller of `Flags.publish`, once per server lifetime | `src/server/FlagsBoot.server.luau`, with the empty host instance `src/shared/Flags/State.model.json` |
| The **Studio override** (`ServerStorage` attributes `DHFlag_*`) | `tools/studio_mcp.py` (the harness), through `flags set` / `flags clear`, **in Edit mode only**. Same ownership shape as the sync token row in `GAME_DESIGN.md` ("Test gate / sync token … `tools/studio_mcp.py` (the harness)") | `tools/studio_mcp.py` |

Files, complete:

| File | New/changed | Becomes |
|---|---|---|
| `src/shared/Flags/init.luau` | NEW | `ReplicatedStorage.Flags` (ModuleScript) |
| `src/shared/Flags/State.model.json` | NEW | `ReplicatedStorage.Flags.State`, `className: "Configuration"`, **no attributes and no children on disk** |
| `src/server/FlagsBoot.server.luau` | NEW | `ServerScriptService.FlagsBoot` |
| `tests/server/flags.spec.luau` | NEW | `ServerStorage.Tests.flags.spec` |
| `tests/client/flags_client.spec.luau` | NEW | `ReplicatedStorage.ClientTests.flags_client.spec` |
| `tools/studio_mcp.py` | CHANGED | two new checks in `run_test` and `run_test2`, the `flags` command, docstring |
| `src/server/Match/init.luau` | CHANGED, **one line** | the worked example, §10 |
| `GAME_DESIGN.md` | CHANGED | the three owner rows in §2, pasted (rule 3's mirror) |
| `CLAUDE.md` | CHANGED | a short "Feature flags" section: merged dark, how the Director switches one on, and that `flags clear` comes before any harness run |
| `docs/research/2026-09-26-feature-flags.md` + `docs/research/INDEX.md` | NEW | rule 1. It may reuse §9's sources; it must record the numbers in §12 and anything measured that contradicts this design (rule 6/8) |

`src/shared/` and `src/server/` are already `$path`-mapped in `default.project.json`
(`ReplicatedStorage` → `src/shared`, `ServerScriptService` → `src/server`), so nothing here needs a
project-file change.

**Why the host for the mirror is a Rojo-owned, empty `Configuration` and not a run-time-created
instance:** every Rojo-owned container defaults to `$ignoreUnknownInstances: false`, so an instance
created in `ReplicatedStorage` with no file on disk is *deleted* at the next Connect (`CLAUDE.md`,
"Rojo DELETES Studio-created instances in Rojo-owned containers"). `Workspace.DriveMarkers` can be
created at run time only because Workspace is not mapped. An empty `.model.json` costs one file and
makes the instance exist in Edit, where the `flags` command and the harness can see it.

---

## 3. The data model

```lua
-- src/shared/Flags/init.luau
export type FlagRow = {
	default: boolean, -- the reviewed value. A new dark path is born `false`.
	owner: string,    -- the module that READS it, e.g. "ServerScriptService.Match"
	born: string,     -- "2026-09-26 task 52"
	expires: string,  -- "2026-10-17": retire, flip, or re-justify by this date (§11, §12)
	why: string,      -- one line: what turning it ON does, in the player's terms
}

Flags.DEFAULTS: { [string]: FlagRow }
```

* Flag names match `Flags.NAME_PATTERN = "^[A-Z][A-Z0-9_]*$"`, ≤ 40 characters. All-caps means a flag
  name can never collide with the mirror's own `Digest`/`Source` attributes, and it satisfies Roblox's
  attribute-name rules (no leading digit, no `RBX` prefix, ≤ 100 characters).
* `Flags.DEFAULTS` is deep-frozen with `Shotgun.deepFreeze`, **required, not copied** — `table.freeze`
  is shallow and this repo has already paid for that once (`src/shared/Drive/init.luau`:
  `Drive.deepFreeze = Shotgun.deepFreeze`, "a defect this repo has already paid for once (Task 23a
  note (b))").
* `Flags` requires `ReplicatedStorage.Shotgun` for `deepFreeze` and nothing else. It requires no
  server module, no client module, and never `ServerScriptService`.

---

## 4. Public interface

```lua
--!strict
-- ReplicatedStorage.Flags

Flags.NAME_PATTERN     = "^[A-Z][A-Z0-9_]*$"
Flags.OVERRIDE_PREFIX  = "DHFlag_"     -- attribute prefix on ServerStorage, Studio only
Flags.MAX_FLAGS        = 12            -- §12
Flags.WAIT_SECONDS     = 10            -- a client's wait for the published mirror
Flags.DEFAULTS: { [string]: FlagRow }

-- PURE. No service, no Instance, no clock. Both are testable with tables the spec owns.
function Flags.defaults(): { [string]: boolean }                      -- frozen projection of DEFAULTS
function Flags.resolve(
	defaults: { [string]: boolean },
	overrides: { [string]: any }?
): ({ [string]: boolean }, { string })
	-- returns a NEW frozen table, and the list of rejected override keys with a reason each
	-- ("unknown flag NOPE", "TIE_UNTIL_DRIVE_END is not a boolean (string)").
	-- It never mutates either argument and never coerces a value.
function Flags.digest(resolved: { [string]: boolean }): string         -- "A=1|B=0", sorted by name
function Flags.problems(defaults: { [string]: FlagRow }, today: string): { string }
	-- every declaration fault in one list: a bad name, a missing field, a non-boolean default,
	-- more than MAX_FLAGS rows, an `expires` that is not an ISO date, an `expires` before `today`.

-- THE STUDIO TEST IS AN ARGUMENT, so the production branch is provable inside Studio.
function Flags.readOverrides(host: Instance?, isStudio: boolean): { [string]: any }
	-- {} when isStudio is false or host is nil. Otherwise every ServerStorage attribute whose name
	-- starts with OVERRIDE_PREFIX, keyed by the name with the prefix removed, value as stored.

-- THIS PROCESS. Computed once, memoised, frozen. Server and client take different branches (§5).
function Flags.all(): { [string]: boolean }
function Flags.isOn(name: string): boolean   -- ERRORS when `name` is not in DEFAULTS (§4.1)
function Flags.source(): "defaults" | "override" | "published" | "published-timeout"
function Flags.line(): string                -- the one boot line, §4.2

-- SERVER ONLY. Errors when RunService:IsServer() is false. FlagsBoot is its only caller.
function Flags.publish(resolved: { [string]: boolean }, source: string): ()
```

There is no setter, no `setForTests`, no listener, no event, and no remote.

### 4.1 `isOn` on an unknown name is an error, not `false`

A typo that reads as `false` is a dark path that silently never runs and a spec that passes for the
wrong reason. It raises, matching the repo's habit of refusing a lie in a table
(`src/server/Match/Penalty.luau`, `Penalty.expired`: "a config number that nothing reads is a lie in
a table").

### 4.2 The boot line

`FlagsBoot` on the server, and `Flags` on each client the first time `all()` is called, print exactly
one line:

```
[flags] server defaults 1 flag: TIE_UNTIL_DRIVE_END=1  digest=TIE_UNTIL_DRIVE_END=1
[flags] client published 1 flag: TIE_UNTIL_DRIVE_END=1  digest=TIE_UNTIL_DRIVE_END=1
```

With an override active, the server's line is a `warn` and says so first:

```
[flags] OVERRIDE ACTIVE (Studio only) 1 of 1: TIE_UNTIL_DRIVE_END=0 (default 1)
```

Rejected overrides are a separate `warn` naming each one. A silently ignored override is how a
playtest gets run against the wrong build and reported as the right one.

---

## 5. The replication path, named

```
  src/shared/Flags/init.luau        (git: the reviewed default)
            |
            |  Rojo  ->  ReplicatedStorage.Flags
            v
  SERVER:  Flags.all()  =  resolve( defaults , readOverrides(ServerStorage, RunService:IsStudio()) )
            |
            |  FlagsBoot calls Flags.publish(resolved, source)
            v
  ReplicatedStorage.Flags.State   attributes:  <FLAG_NAME> = boolean ... then Digest, then Source
            |
            |  ordinary Roblox attribute replication (server-created values on a replicated instance)
            v
  CLIENT:  Flags.all()  =  read State's attributes, after waiting for `Digest`
```

* **The server is the only resolver.** The overrides live on `ServerStorage`, which is never
  replicated, so a client cannot see or influence them, and the design does not depend on whether a
  *service's* own attributes replicate.
* **`Digest` is written LAST**, after every flag attribute. "Digest present" therefore means "the set
  is complete", so a client can never read half a set. The client recomputes
  `Flags.digest` over what it read and compares; a mismatch is a loud `warn` and
  `source() == "published-timeout"`, never a silent disagreement.
* **The client waits, then falls back to defaults** (`Flags.WAIT_SECONDS = 10`, via
  `GetAttributeChangedSignal("Digest")` plus a deadline) and warns if it had to. The fallback cannot
  cause a real disagreement: overrides exist only in Studio, so in a live server the defaults **are**
  the server's answer. In Studio, the boot line and `flags live` (§7.2) show it.
* No new RemoteEvent. `src/shared/Drive/init.luau` notes the drive deliberately has no inbound
  remote ("its inbound exploit surface is zero, and that is worth keeping"); an attribute mirror keeps
  it that way.

---

## 6. The Studio override, and its guard

**Where.** Attributes on the **`ServerStorage` service**, named `DHFlag_<FLAG_NAME>`, value a
boolean. Reasons: the service exists in Edit mode (so the Director can set it before Play, and the
harness can see it before Play); a service is not an instance Rojo can delete; `ServerStorage`
is never replicated to a client; and the harness already reads and writes service attributes —
`tools/studio_mcp.py` `QUERY_SET_CLIENTS_DONE` (`ServerStorage:SetAttribute("ClientsFinished", …)`)
and `QUERY_REPORT["server"]` (`ServerStorage:GetAttribute("TestReport")`). No harness check compares
service attributes: check 4 compares attributes only for instances backed by `.model.json` /
`.meta.json`, and `$attributes` in `default.project.json` is refused outright.

**How it reaches a playtest.** A Studio play session (F5, or Karen's F7 "Server and Clients") builds
its DataModel from the edit place, so the attribute set in Edit is there when the server resolves.
This is the same mechanism by which every Rojo-synced script reaches those processes (measured
2026-09-25, `tools/studio_mcp.py` docstring, "WHAT THE COPIED PLACE CARRIES"). That same measurement
found a `StringValue`'s **Value** carried only sometimes, which is why nothing here depends on a
*client* process carrying the override: the server resolves, the mirror replicates (§5), and the
Director confirms with `flags live` before Karen plays.

**Three guards, so an override cannot outlive the session it was made for.**

1. **`RunService:IsStudio()`.** `Flags.readOverrides(host, isStudio)` returns `{}` when `isStudio` is
   false, so a published place ignores `DHFlag_*` even if one were saved into the place file. The test
   is a parameter, so `tests/server/flags.spec.luau` proves the production branch from inside Studio
   (§13.1 case 7) — the trick `TestKit.openToken` cannot use and pays for with an untestable branch.
2. **The harness refuses to run.** §7.1.
3. **The publish step.** `TASKS.md` row 2 (strip test code before the first public release) gains one
   line: clear every `DHFlag_*` attribute on `ServerStorage` as part of the strip, beside TestKit and
   the runners. An attribute saved with the place is otherwise published with it.

**Refuse, do not reset.** The brief allows either. The harness refuses, because silently clearing the
Director's overrides mid-session destroys a playtest setup and hides the fact that the run was almost
made against the wrong build. It prints the exact command to clear them.

---

## 7. Harness interaction

### 7.1 Two new checks in `test` and `test2`

In `tools/studio_mcp.py` `run_test`, immediately after the `"Studio has the DEV place open"` check and
**before** `write_token(token)`; in `run_test2`, at the equivalent point, **before** the disk token is
written and cleared and therefore before Karen's click:

```
  ok   No flag override is set   (ServerStorage has no DHFlag_* attribute)
```

* On failure the check names every override and its value, prints
  `python tools/studio_mcp.py flags clear`, and **returns `verdict()`** — the run stops before Play,
  final line `[harness] FAIL: n/m checks @ <sha> …`, exit 1. Not exit 2: 2 means "Studio not in Edit
  mode" and that meaning stays single.
* A second check at the end of the run, beside `"HEAD unchanged during the run"` in `verdict`:
  `"No flag override appeared during the run"`. Same reasoning as re-reading HEAD.

The query is a constant, read-only one, in the `QUERY_*` block with the others:

```python
QUERY_FLAG_OVERRIDES = (
    'local SS = game:GetService("ServerStorage") local out = {} '
    'for name, value in pairs(SS:GetAttributes()) do '
    '  if string.sub(name, 1, 7) == "DHFlag_" then out[#out + 1] = name .. "=" .. tostring(value) end '
    'end table.sort(out) return table.concat(out, ",")'
)
```

### 7.2 The `flags` command

`python tools/studio_mcp.py flags [set <NAME> on|off | clear | live [role]]`

| Form | Mode | What it does |
|---|---|---|
| `flags` | Edit | Reads `Flags.DEFAULTS` out of Studio's synced copy (`require` through `execute_luau` — its own module cache is *correct* here: `Flags` is frozen data, and check 4 has already proved Studio's copy is the disk copy byte-for-byte) and the `DHFlag_*` attributes, and prints NAME, default, override, effective, owner, expires. Read-only |
| `flags set <NAME> on\|off` | **Edit only**, else exit 2 | Refuses a `NAME` that is not in `Flags.DEFAULTS` (an override for a flag that does not exist is a typo the resolver would only log), refuses anything but `on`/`off`, then `ServerStorage:SetAttribute("DHFlag_<NAME>", true\|false)` and reads it back. Templated exactly like `QUERY_SET_CLIENTS_DONE`: the name is validated against `Flags.NAME_PATTERN` in Python first, the value is a Luau boolean literal, so no arbitrary Luau is ever sent |
| `flags clear` | Edit | `SetAttribute(name, nil)` for every `DHFlag_*`, prints what it removed |
| `flags live [role]` | during Play | Reads `ReplicatedStorage.Flags.State`'s `Digest` and `Source` from the **Server** DataModel, and from a client with `client`/`client:Player2`, using the same `studio_for_role` classification `capture` uses. This is how the Director confirms the playtest is running the intended set before telling Karen to go |

`set`/`clear` are Edit-only so an override can never be injected into a *running* server: resolution
happens once at boot, so a mid-session write would be invisible anyway, and an invisible write is a
lie about what was tested.

The docstring's **Safety** paragraph is amended honestly: the harness writes
`tests/sync-token.txt`, `.screenshots/`, and — only through `flags set`/`flags clear`, only in Edit
mode, only with a validated flag name and a boolean — `ServerStorage`'s `DHFlag_*` attributes. That is
the same kind of write `QUERY_SET_TOKEN` and `QUERY_SET_CLIENTS_DONE` already are.

---

## 8. What it reads and writes across systems

| Direction | What | Owner of the other side |
|---|---|---|
| reads | `ReplicatedStorage.Shotgun` → `Shotgun.deepFreeze` | `ReplicatedStorage.Shotgun`, frozen, no writer (`src/shared/Shotgun/init.luau`) |
| reads | `ServerStorage` attributes `DHFlag_*` (server, Studio only) | `tools/studio_mcp.py` (§2). No collision with `TestReport` or `ClientsFinished`: different names, and only `DHFlag_*` is ever read or written by either side |
| reads | `RunService:IsStudio()`, `RunService:IsServer()` | Roblox |
| writes | `ReplicatedStorage.Flags.State` attributes | itself, through `FlagsBoot` alone |
| writes | nothing else. No Workspace instance, no `Player`, no `Team`, no camera, no mouse, no `Tool`, no boar, no remote, no DataStore | — |
| is read by | `ServerScriptService.Match` (§10), and later any owner with a dark path. Each consumer reads at its boundary and passes the value inward | the consumer's own owner row in `GAME_DESIGN.md` |

`GAME_DESIGN.md` rows to add (rule 3's mirror):

* **Feature flag declarations and defaults (`ReplicatedStorage.Flags`: `Flags.DEFAULTS`, the pure
  resolver, `isOn`)** | **nobody at run time.** Frozen data with no writer: the Builder edits
  `src/shared/Flags/init.luau` and git records the change. Booleans only — no game number and no
  string ever lives here | `src/shared/Flags/init.luau` | [feature flags](docs/design/feature-flags.md)
* **The resolved flag set as clients see it (`ReplicatedStorage.Flags.State` attributes, and the
  `Digest`/`Source` pair)** | `ServerScriptService.FlagsBoot`, the only caller of `Flags.publish`,
  once per server lifetime. Clients read it and never write it | `src/server/FlagsBoot.server.luau`,
  `src/shared/Flags/State.model.json` | [feature flags](docs/design/feature-flags.md)
* **The Studio flag override (`ServerStorage` attributes `DHFlag_*`)** | `tools/studio_mcp.py`
  (`flags set`/`flags clear`), Edit mode only. Read only when `RunService:IsStudio()`; the harness
  refuses to run while any is set | `tools/studio_mcp.py` | [feature flags](docs/design/feature-flags.md)

---

## 9. External sources, and the pattern adopted (rules 1 and 2)

Where I borrow, in one line each: the **toggle point / toggle configuration split and the expiry
discipline** come from Fowler/Hodgson; **declare-once-with-a-default, session-scoped override outside
the source tree, resolve-once-then-immutable, unknown-flag-is-an-error** come from Chromium's
`FeatureList`; **always answer with a default and say where the answer came from** comes from
OpenFeature; **archive rather than delete, and a row that carries owner and lifecycle** comes from
Unleash; the **attribute transport and `IsStudio`** come from Roblox's own documentation.

1. **Pete Hodgson, "Feature Toggles (aka Feature Flags)"** — <https://martinfowler.com/articles/feature-toggles.html>
   *Licence:* editorial article, © martinfowler.com, no code licence. *Maintenance:* published
   2017-10-09, unchanged since; still the canonical reference.
   *Good:* separates the **toggle point** from the **toggle router** and **toggle configuration**, so
   the decision is made once and injected instead of looked up deep inside logic; categorises toggles
   by lifetime (release / experiment / ops / permission) and says release toggles are the short-lived
   ones; names **toggle debt** as the real cost and says to remove them aggressively.
   *Bad:* every example assumes a long-lived web service with dynamic config and per-request context;
   nothing about two processes that must agree, nothing about a build that cannot be reconfigured
   without a publish.
   *Adopted:* release toggles only (§1.2 item 2); configuration in one reviewed place (§2); the
   decision read at the boundary and passed inward (§1.2 item 4), which is already this repo's
   `config`-as-a-parameter rule; toggle debt handled by a dated `expires` with a spec tripwire
   (§12, §13.1 case 6).
2. **Chromium `base::Feature` / `base::FeatureList`** —
   <https://chromium.googlesource.com/chromium/src/+/HEAD/base/feature_list.h>
   *Licence:* BSD-3-Clause. *Maintenance:* actively maintained, shipping in Chrome.
   *Good:* every feature is **declared once in code with its default state**; overrides arrive from
   the command line (and `about:flags`) **for that session only** and are never written into the
   product; `FeatureList` is initialised once and then immutable, and querying before initialisation
   is a hard error rather than a default; one API for every check.
   *Bad:* Finch/field trials add a server-driven layer with its own trust model; the C++ static
   initialisation and thread-safety machinery does not transfer to a single-threaded Luau module.
   *Adopted:* declare once with a default (§3); the override is session-scoped and lives **outside**
   the source tree, as Studio attributes (§6), which is what keeps the git tree clean for the harness;
   resolve once then freeze (§1.2 item 3); an undeclared flag raises (§4.1).
3. **OpenFeature specification (CNCF)** — <https://openfeature.dev/specification/>, repo
   <https://github.com/open-feature/spec>
   *Licence:* Apache-2.0. *Maintenance:* actively maintained, CNCF incubating project.
   *Good:* the **static-context paradigm** (one context for the whole client process) is exactly a
   game client's situation; typed getters fix a flag's type at the call site; every evaluation returns
   **the default when resolution fails** and carries a **reason** for the value it gave.
   *Bad:* providers, hooks, telemetry and an event model are a large SDK surface for twelve booleans;
   there is no Luau or Roblox implementation, so adopting the API itself would mean writing one.
   *Adopted:* boolean-only typed access with a compulsory on-disk default, and `Flags.source()`
   returning `"defaults" | "override" | "published" | "published-timeout"` so the answer always says
   where it came from (§4, §5).
4. **Unleash** — <https://github.com/Unleash/unleash>, docs <https://docs.getunleash.io/>
   *Licence:* Apache-2.0 (server and SDKs; an enterprise edition exists separately).
   *Maintenance:* actively maintained.
   *Good:* SDKs **fail to the last known default** when the service is unreachable rather than
   guessing; **archiving** a flag is a first-class lifecycle step, kept and searchable rather than
   deleted; every flag carries an owner and metadata, and stale flags are reported.
   *Bad:* a service, a database, polling and per-user activation strategies — none of which applies to
   a 16-player place; "gradual rollout" is meaningless here.
   *Adopted:* the client falls back to the on-disk default and says so (§5); each row carries
   `owner`/`born`/`expires`/`why` (§3); retirement is an archive under `backups/`, which is rule 7
   anyway (§11).
5. **Roblox Creator Documentation — Attributes, and `RunService:IsStudio`** —
   <https://create.roblox.com/docs/studio/properties#attributes>,
   <https://create.roblox.com/docs/reference/engine/classes/RunService#IsStudio>
   *Licence:* docs source `Roblox/creator-docs`, CC BY 4.0. *Maintenance:* actively maintained.
   *Good:* attributes are a first-class instance API, settable in Edit, saved with the place,
   replicated with the instance, and need no new remote; `IsStudio` is the documented answer to "am I
   in Studio".
   *Bad:* "saved with the place" is exactly the leak risk an override must not have — which is why
   the read is `IsStudio`-gated, the harness refuses while one is set, and the publish step clears
   them (§6); attribute names are restricted (no leading digit, no `RBX` prefix, ≤ 100 characters),
   which `NAME_PATTERN` respects.
6. **TestEZ 0.4.1** — <https://github.com/Roblox/testez>
   *Licence:* Apache-2.0. *Maintenance:* **archived upstream**, pinned in `wally.lock`.
   *Good:* `beforeEach`/`afterEach` exist for state isolation.
   *Bad:* a failed `expect` **abandons the rest of the `it`**, which is precisely how the
   arming-policy leak happened — `tests/server/zz_drive_boundary.spec.luau` had to gather its
   observations, restore `Weapon.setArmingPolicy` unconditionally, and only then assert, because "one
   failure became four".
   *Adopted:* **do not rely on hooks at all.** Flag states are tested through the pure `Flags.resolve`
   and through owners that take the value as a parameter, so there is no live state to restore and no
   ordering to get right (§13.1).

**Invented here (rule 2), with the reason:** nothing structural. The only piece with no external
counterpart is the **harness refusal while an override is set**, because no external flag system has a
test harness whose evidence is invalidated by a local override. It is the same shape as the existing
dirty-tree and `HEAD unchanged during the run` guards in `tools/studio_mcp.py` `verdict`.

**Alternatives rejected:** a toggle inside each system's own CONFIG (the status quo: no single place,
no override path, and every owner invents its own switch — `Drive.CONFIG.SCOREBOARD_ENABLED`,
`Shotgun.CONFIG.HIT_MARK_ENABLED`, `Shotgun.CONFIG.CROSSHAIR_ENABLED`,
`Match.CONFIG.DRIVERS_MAY_SHOOT` already are that); attributes with no defaults module (not reviewed
in git, so a flag's value would exist only in one person's Studio); a DataStore or Open Cloud remote
config (a network call, unreviewable in a PR, and it could change behaviour mid-match); a
Rojo-synced override file (it dirties the tree, and the harness refuses a dirty tree — the brief's
constraint).

---

## 10. Worked example: `TIE_UNTIL_DRIVE_END`

`Match.CONFIG.TIE_UNTIL_DRIVE_END` (`src/server/Match/init.luau`) is already the right shape: a
boolean Karen owns, with `Penalty.expired(tiedAt, now, config)` taking it as a parameter
(`src/server/Match/Penalty.luau`) and the drive's own `applyRelease` implementing the ON behaviour.
**The flags task migrates exactly this one flag and no other.** It is the safest possible proof of the
wiring — the value is `true` today and stays `true`, so the behaviour diff is nil — and it gives the
plumbing a real consumer with an existing live suite (`tests/server/match_safety.spec.luau`,
`tests/server/match_live.spec.luau`, `tests/server/zz_drive_boundary.spec.luau`) instead of shipping
untested plumbing.

**Declaration** (`src/shared/Flags/init.luau`):

```lua
Flags.DEFAULTS = {
	TIE_UNTIL_DRIVE_END = {
		default = true,
		owner = "ServerScriptService.Match",
		born = "2026-09-25 task 32 (as Match.CONFIG), 2026-09-26 task 52 (as a flag)",
		expires = "2026-12-31", -- ACCEPTED by Karen; it stays until the TIE_SECONDS path is archived
		why = "A tied player stays tied until the drive ends. OFF frees him after TIE_SECONDS.",
	},
}
```

**The one changed line in the owner** (`src/server/Match/init.luau`, inside `Match.CONFIG`, before
`Drive.deepFreeze(Match.CONFIG)` — resolution happens at require time, which is exactly when
`Match.CONFIG` is built and frozen):

```lua
	TIE_UNTIL_DRIVE_END = Flags.isOn("TIE_UNTIL_DRIVE_END"), -- K, Karen's rule as written; flag: docs/design/feature-flags.md
```

This is the **only permitted shape**: a read, never a literal beside a flag of the same name. There is
still one source of truth for the value (`Flags.DEFAULTS`), and `Match.CONFIG` is still the one table
the drive reads. `Penalty.expired` is untouched — it already takes `config`.

**The loop, end to end:**

1. The Builder lands the flag OFF-by-default for a *new* path (here the value is `true` because Karen
   already accepted it; a new dark path would be `false`). Reviewed, green, merged — no waiting for
   Karen, which is the whole point.
2. Director, Edit mode: `python tools/studio_mcp.py flags set TIE_UNTIL_DRIVE_END off`. The git tree
   is untouched.
3. Director: `python tools/studio_mcp.py flags` shows `override off, effective off`. Start the session
   (F5, or `press-f7.ps1` for two players), then `python tools/studio_mcp.py flags live` →
   `Digest=TIE_UNTIL_DRIVE_END=0  Source=override`. The server's console carries the
   `[flags] OVERRIDE ACTIVE` warn, and each client's `[flags] client published …` line agrees.
4. Karen plays and says whether being freed after 60 s feels right. The Builder transcribes it into
   `PLAYTEST.md`. If the change is visible, a screenshot during that session (rule 5).
5. `python tools/studio_mcp.py flags clear` — before any harness run. Forget it and the harness
   refuses with the command printed (§7.1).
6. Karen accepts the OFF behaviour → a three-line commit flips `default = false` and dates it. That
   commit touches `src/`, so it needs `test` **and** `test2` (`CLAUDE.md` git workflow step 4), which
   is the cheapest gate this project has.
7. Retirement (§11): a later task deletes the losing branch — here `Penalty.expired`'s
   `TIE_UNTIL_DRIVE_END` early return and the `Match.CONFIG.TIE_SECONDS` loop in the drive's tick, or
   `applyRelease`'s untie loop, whichever lost — archives the removed code to
   `backups/2026-<mm>-<dd>_tie-until-drive-end.md` with a note (rule 7), and removes the flag row.

---

## 11. How a flag is born, switched, flipped and retired

| Step | Who | What happens | Where it is recorded |
|---|---|---|---|
| 1. Born | Builder | One row in `Flags.DEFAULTS`, `default = false`, with `owner`, `born`, `expires` (≤ 21 days out), `why`. The new path is reachable **by parameter as well as by flag** (§13.3) | the code commit, and the task's `REQUEST.md` claim |
| 2. Merged dark | Director | Reviewer `PASS`, harness `PASS` (+ `[harness2]` when `src/`/`tests/client/`/`tools/studio_mcp.py` is touched), CI green → merged. **No playtest in the gate** | `reviews/task-<N>/` |
| 3. Switched on | Director | `flags set <NAME> on` in Edit, `flags live` to confirm, session started | nothing in git — that is the point |
| 4. Judged | Karen | Plays. Accept, reject, or "change this number" | `PLAYTEST.md` (Builder transcribes) |
| 5. Cleared | Director | `flags clear` before the next harness run | the harness refuses otherwise |
| 6a. Accepted | Builder | ≤ 3-line commit: `default = true`, `expires` moved out to the retirement task's date. `test` + `test2` | the flip commit |
| 6b. Rejected | Director | Either the flag stays `false` with a **new `expires` and a one-line reason in `why`**, or the whole new path is removed and archived (rule 7) | `TASKS.md` row |
| 7. Retired | Builder | The losing branch is deleted from the code, the removed code is archived under `backups/<date>_<flag>.md` with a note (rule 7, `backups/README.md`), the flag row is removed, and any spec that only tested the dead state is archived with it. `GAME_DESIGN.md` needs no change: the flag never had an owner row of its own | the retirement commit |
| Rot | the spec | An `expires` date in the past **fails `tests/server/flags.spec.luau`**, which fails the harness, which blocks the merge gate. The fix is one of: retire it, flip it, or move the date with a reason | §13.1 case 6 |

The rot tripwire is deliberate and it is the one part of this design that can interrupt unrelated
work. That is the trade: `TASKS.md` currently carries rows 6a, 21a, 23a, 24a, 26a and 28a of deferred
notes, and a flag that nobody is forced to look at becomes one of them, except that a forgotten flag
is a dark code path in a shipped game rather than a wording fix. Moving a date costs one line and is
always available, so the tripwire can never actually block a task — it can only force someone to say
the flag still has a reason to exist.

---

## 12. Numeric targets

| Target | Value | Why, and how it is checked |
|---|---|---|
| Live flags at once | **≤ 12** (`Flags.MAX_FLAGS`) | More than twelve dark paths in a 16-player grey-box game means the stack problem moved rather than went away. A 13th is the Director's call. `Flags.problems` fails the spec |
| Flag lifetime | **≤ 21 days** from `born` to `expires` | Hodgson's toggle debt, made mechanical. Spec tripwire (§13.1 case 6) |
| Flag name | matches `^[A-Z][A-Z0-9_]*$`, **≤ 40 chars** | Attribute-name safety (`DHFlag_` + 40 ≤ 100) and no collision with `Digest`/`Source` |
| Resolution cost, per process | **≤ 1 ms** at boot: one pass over ≤ 12 rows plus ≤ 12 `GetAttribute` calls | Measured with `os.clock` in the spec and reported through `TestKit.note` (the report survives a truncated console: `tests/TestKit.luau`, `TestKit.note`) |
| `Flags.isOn` | **one hash lookup on a frozen table, 0 allocations**, ≤ 0.001 ms | It is a table index by construction. Called at most once per consumer per boot, never in a frame loop (§1.2 item 4) |
| Publish | **1 instance, ≤ 14 attributes, ≤ 1 KB**, once per server lifetime | `Flags.publish` writes flags + `Digest` + `Source`; the spec counts the attributes on `State` |
| Client wait for the mirror | `Flags.WAIT_SECONDS = 10`; **target 0 timeouts** in a gated run | `FlagsBoot` runs at server start, before any player exists, so the real wait is ~0. `tests/client/flags_client.spec.luau` asserts `source() == "published"` |
| Harness overhead | **≤ 2 s** per run (two constant queries) | Two `studio.query` calls, no Play involvement |
| Default flip diff | **≤ 3 lines** in one file | §11 step 6a; it is what makes Karen's OK cheap |
| Cross-process agreement | **digest identical** on the server and every client in `test2` | Both client processes run `flags_client.spec` and assert the same digest string (§13.2) |
| Overrides during a harness run | **exactly 0**, before and after | §7.1, two checks |

---

## 13. How it is tested

### 13.1 `tests/server/flags.spec.luau` — NEW; pure, plus two live reads

Every case below builds its own tables. Nothing installs anything, so nothing needs restoring and no
`beforeEach`/`afterEach` is required — the audit-004 F1 shape (`Weapon.setArmingPolicy` in
`tests/server/zz_drive_boundary.spec.luau`) cannot occur here.

1. `resolve(defaults, nil)` returns the defaults, frozen, as a **new** table; the input is unchanged
   and writing to the result raises.
2. **Both states, both ways:** `resolve({A = false}, {A = true})` → `A == true`;
   `resolve({A = true}, {A = false})` → `A == false`. The defaults table passed in is byte-identical
   afterwards.
3. An override for a name not in `defaults` is **ignored** and appears in the rejected list, and does
   not create a key.
4. A non-boolean override (`"true"`, `1`, `{}`) is **rejected, never coerced**, and named in the
   rejected list.
5. `isOn("NOT_A_FLAG")` raises (§4.1). `Flags.DEFAULTS` is frozen: assigning a row raises, and so
   does assigning a field inside a row (deep, not shallow — the Task 23a(b) defect).
6. `Flags.problems(Flags.DEFAULTS, os.date("!%Y-%m-%d"))` is empty: every row has all five fields, a
   legal name, a boolean default, a parseable `expires` **not in the past**, and there are
   ≤ `MAX_FLAGS` rows. This is the rot tripwire (§11).
7. **The production branch, proved inside Studio:** `readOverrides(ServerStorage, false)` is `{}`
   even with an attribute present — the spec sets `DHFlag_ZZ_SPEC_ONLY` on a **`Configuration` it
   creates and destroys itself**, never on `ServerStorage` (nothing may leave an override behind on
   the service the harness guards), and asserts it is read when `isStudio` is true and ignored when
   false.
8. **The live process:** `Flags.source() == "defaults"`, `readOverrides(ServerStorage, true)` is
   empty, and `Flags.digest(Flags.all()) == Flags.digest(Flags.defaults())`. This is the spec-level
   mirror of the harness guard: it catches an override the harness check somehow missed.
9. `digest` is stable and sorted, and `State`'s attributes match it: each flag name carries the same
   boolean, `Source` is a legal value, and `Digest` was written last (assert the attribute count is
   `#flags + 2`).
10. There is no writer: `Flags.setForTests == nil`, `Flags.override == nil`, and `Flags.publish`
    called twice does not change the digest.
11. **The worked example's wiring:** `Match.CONFIG.TIE_UNTIL_DRIVE_END == Flags.isOn("TIE_UNTIL_DRIVE_END")`,
    and `Penalty.expired(0, 999, { TIE_UNTIL_DRIVE_END = false, TIE_SECONDS = 60 })` is still `true`
    while the same call with `TIE_UNTIL_DRIVE_END = true` is `false` — both states of the *behaviour*,
    through the parameter, with the live config untouched.

### 13.2 `tests/client/flags_client.spec.luau` — NEW; runs in every client, in `test` and `test2`

1. `Flags.source() == "published"` — the mirror arrived, nothing fell back.
2. `Flags.digest(Flags.all()) == State:GetAttribute("Digest")`, and the flag names the client knows
   are exactly the names the mirror carries.
3. `Flags.publish({}, "defaults")` **raises on a client** (server-only, §4).
4. The client cannot see an override: `game:GetService("ServerStorage"):GetAttribute("DHFlag_" .. name)`
   is `nil` for every declared flag. `ServerStorage` is not replicated, and this asserts it.
5. No client module writes `State`: assert `State:GetAttribute("Source")` still says what the server
   wrote after the suite has run.

In `test2` this spec runs in **both** client processes (`tools/studio_mcp.py` docstring: all three
reports are checked since Task 36), so "the server and every client agree" is asserted across three
processes, which is the one thing a one-player run cannot show.

### 13.3 The rule that makes a dark path testable at all

**A flagged code path must be reachable by parameter, not only by the live flag.** The owner reads
`Flags.isOn` once at its boundary and passes the value into a function that takes it — exactly as
`Penalty.judge`/`Penalty.expired`, `Weapon.StateMachine`, `Boar.Wound` and `Camera.Mode` already take
`config`, `now`, `rng` and `cast`. A spec then exercises **both** states by calling that function
twice with different tables.

This is also the honest limit of the evidence, stated plainly (rule 8): while a flag is OFF, CI and
the harness run the **on-disk defaults only**, so a dark path's *wired, live* behaviour is proved by
the Director's override plus Karen's playtest, and by pure specs before that — not by the harness. A
dark path whose pure core is not fully unit-tested is not ready to merge, flag or no flag.

### 13.4 Harness input and screenshots

* **No new input scenario.** This system binds no input and draws nothing, so
  `tests/client/input_scenarios.txt` is unchanged.
* **Rule 5: N/A for the flags system itself** — nothing is drawn. The *flagged feature* still needs
  its screenshot, and a playtest run under an override needs one if the change is visible.
* **Not tested by the harness, and say so in the request:** the `flags set` / `flags clear` /
  `flags live` commands are driven by hand (the harness cannot test its own new subcommand, and
  `flags live` needs a running Play session); and "a published place ignores `DHFlag_*`" is proved
  only through the injected `isStudio` parameter (§13.1 case 7), because no harness run can produce a
  non-Studio server. `TASKS.md` rows 6 and 7 are the standing record of what the harness cannot do;
  this adds two lines to it.

---

## 14. Open decisions — none of them blocks building

1. **Karen (feel):** nothing. This system is invisible to a player. The first flag that reaches her is
   whatever the next feel-critical task puts behind one.
2. **Director (scope):** the rot tripwire fails the harness when an `expires` date passes (§11).
   Decided here as **yes, it fails**, because a silent stale flag is a dark path in a shipped game,
   and moving the date is one line. If the Director would rather it only warned, say so before the
   build — it is one `expect` either way.
3. **Director (scope):** `Flags.MAX_FLAGS = 12`. A number picked to be uncomfortable before it is
   dangerous; raise it in one line if 1.7c-2.2 needs more.
4. **Director (scope):** the existing pseudo-flags stay where they are —
   `Drive.CONFIG.SCOREBOARD_ENABLED`, `Shotgun.CONFIG.HIT_MARK_ENABLED`,
   `Shotgun.CONFIG.CROSSHAIR_ENABLED`, `Shotgun.CONFIG.AUTO_EQUIP`,
   `Match.CONFIG.DRIVERS_MAY_SHOOT`, `Match.CONFIG.END_ON_LAST_BOAR`,
   `Match.CONFIG.SWAP_TEAMS_EACH_DRIVE`, `Map.EXPECTED_WORLD`. Migrating them would touch five owners
   for no behavioural gain; **exactly one** migration is in scope (§10). If the Director wants
   `DRIVERS_MAY_SHOOT` migrated too, it is one more row and one more line — but it belongs to a task
   that has a reason to play with it.
5. **Director (scope), before the first public release:** `TASKS.md` row 2's strip list gains "clear
   every `ServerStorage` `DHFlag_*` attribute" (§6 guard 3).

---

## 15. What I could not verify

Read-only run, no Studio, no commands (`.agent-evidence/INDEX.md`: "Roblox Studio is not available").
The following are assumptions a Builder must confirm by running it, and report either way (rule 6/8):

1. **That attributes written by the server on `ReplicatedStorage.Flags.State` replicate to clients.**
   It is the documented behaviour of attributes on a replicated instance and it is the design's named
   path (§5), but nothing in this repo exercises it today: the token that reaches clients in `test2`
   is a `StringValue.Value`, not an attribute, and the only attributes crossing a boundary so far
   (`TestReport`, `ClientsFinished`, `StagedTarget`, `InputProbeReady`) are read in the process that
   wrote them. `tests/client/flags_client.spec.luau` case 1 is the test that proves it; if it fails,
   the fallback is a `StringValue` child of `State` holding the digest, which `test2` has already
   shown replicates, and the design changes by one instance.
2. **That an attribute set on `ServerStorage` in Edit mode reaches the server process of a Play or a
   two-client session.** The measurement recorded in `tools/studio_mcp.py` (2026-09-25) says every
   *script* carried and a `StringValue`'s **Value** carried only sometimes; attributes were not
   probed. If they do not carry, the override mechanism needs a different transport and §6 must be
   redesigned — this is the one assumption that could invalidate part of the design, and it is
   checkable in one minute with `flags set` plus `flags live`. **Do that first.**
3. **Whether harness check 4 fails on an *extra* attribute** on an instance backed by an
   attribute-free `.model.json` (`State`). If it does, that is a free extra guard against anything
   writing `State` in Edit; if it does not, nothing is lost, because nothing writes it in Edit.
4. **`audit-004` itself.** It is not in this worktree (`.agent-evidence/ls-files.txt` has
   `audit-001`…`audit-003`; `TASKS.md` row 47 says it lives on branch `task-46-audit`). I took F1 from
   the fix that is in the tree — `tests/server/zz_drive_boundary.spec.luau`'s restore-before-assert
   comment, which names it — and from `TASKS.md` rows 47/48.
5. **The resolution and publish timings** in §12. Nothing was measured; they are budgets for the
   Builder to confirm with `os.clock` and `TestKit.note`.

# Task 24 — where the code now differs from `docs/design/shotgun.md`

For the Architect, at the next `design shotgun` run. The Builder never edits `docs/design/`
(CLAUDE.md rule 3), so the deltas live here.

1. **§12, feel default "Ammo swap" — changed by Karen after playing it (2026-09-25).** The design has
   `SelectAmmo` change only the next load's kind. Karen: *"no, it has to change to shells after X, so
   it reloads to shells."* **X now switches the type and reloads to it**: break open, the unfired
   shells of the old type return to their own pocket, two of the new type go in, close — the same
   2.0 s uninterruptible window as `R`, and no firing during it. Every X press does this.

2. **Shells are carried per type.** `CONFIG.START_RESERVE` is `{ Slug = 24, Buck = 24 }` and
   `WeaponState.reserve` is a table keyed by `AmmoKind`, because Karen's rule *"if there is no reserve
   of the new type, X does nothing and the Hud says so"* needs a per-type pocket to be refusable.
   24 of each is the Builder's number, not hers: one dial for the Director.

3. **`Break` returns unfired shells** to the pocket of their own type, for `R` as well as `X`. Karen
   asked for it on the swap; making it a property of the action rather than of one request keeps the
   rule in the reducer, where uninterruptibility already lives.

4. **`WeaponSnapshot` gains `notice: string?`** — one short line for the Hud, `nil` most of the time.
   The only sender today is an X into an empty pocket (`"NO BUCK"`). The Hud's readout is now
   `glyphs AMMO <pocket for that ammo>[ R][ NOTICE]`.

5. **The reload sequence publishes once more after its final window.** Without it the newest snapshot
   a client ever saw was the one made at `Close`, whose `busyFor` is `RELOAD_CLOSE`, so the Hud kept
   its `R` until something else moved the state — a gun that looks stuck reloading. Found by running
   the X change.

6. **§13.3's scenario** remains three clicks and one `R` rather than five and two (measured: a
   replayed step costs ~1 s, so nothing can be placed reliably inside a 0.25 s or 2.0 s window), and
   `X` now needs 2.6 s of scenario after it. Carried from the round-1 note.

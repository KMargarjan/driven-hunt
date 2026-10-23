# docs/design/

The Architect's system designs, one file per system: `docs/design/<system>.md`. Each is written by
`tools/architect.sh design <system>` **before** the Builder writes any code for that system.
The format is in `docs/ARCHITECT_PROMPT.md` ("Mode: design").

Only the Architect writes here (through the script). The Builder builds to these files. If the
Builder disagrees with a design, it writes `ESCALATE.md` and stops. It never edits the design.

- `ambience.md` -- the ambience bed (task 250): the lodge's quiet birds and wind, the hunt bed, and
  the crossfade between them. Its section 0 records that there was no ambience owner in `src/` at
  all, and that `Workspace.Ambience` in the Forest Test is Karen's own Studio-made Sound with no
  owner in git.

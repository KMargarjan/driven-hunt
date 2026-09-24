-- SyncCheck: boot marker proving the Rojo sync loop (disk -> Studio -> running server).
-- Pattern: startup sentinel log line + attribute, asserted by tests/server/sync.spec.luau.
-- Note: docs/research/2026-09-24-toolchain.md
script:SetAttribute("Ran", true)
print("sync ok")

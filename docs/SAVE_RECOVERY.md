# Save diagnostics and explicit recovery

Build identity is 0.1.10-alpha.1 (Android version code 11). Save format remains 4.
Older and newer formats are preserved rather than imported automatically.
An unsupported format is a confirmed reproduction of the old generic failure
message; the screenshots alone do not establish the cause on the user's phone.

The HUD now distinguishes unsupported versions, integrity failures, current
snapshot validation and storage operations. Local Details show build, encountered
and required format, operation, storage error and file size. Structured logs
contain only reason, stage, numeric error, format numbers and byte count.
Identical diagnostics are not repeatedly emitted. Save payloads and archive paths
are never included in those logs.

Recovery is offered only for preserved, blocked file cases. Invalid current
snapshots and write-permission failures show Details instead. The user opens
Recovery and explicitly selects **Back up & start fresh**. Cancel changes no
save files or live progress. The launcher is below the right-side travel button,
outside the joystick's capture zone. Confirmation pauses gameplay and releases
held touch input; it retains readable paged text and pinned actions.

The fresh candidate is built independently from roster defaults and the exact
geometry-free floor generator. Preparing it does not reset the live singleton.
Recovery copies the primary, backup and both owned temporary files when present
into a unique app-local archive. It verifies original/copy byte counts and SHA256
before and after copying, then writes and reads back a manifest. Fresh primary
and backup are staged in unique files in the active save directory, flushed,
validated and checked before a verified pending journal permits replacement.

After both atomic replacements and verification succeed, the journal is marked
complete and the fresh snapshot is applied to live state. Archives are retained.
On a replacement failure, recovery attempts byte-identical rollback. If rollback
cannot complete, the archive and pending journal remain and automatic saving is
blocked. Startup never automatically replays a journal, imports a save or resets
progress. A second request cannot overwrite a pending recovery.

Archive locations are shown only in local UI. These backups remain in this app's
storage; clearing app data or uninstalling can remove them. They are not cloud
backups or exported files.

Owned paths are anchored to the app's user-data root and reject descendant links
before file operations. Desktop also checks the root against its readable
parent. Android trusts its exact normalized OS-provided private root because
DirAccess cannot open that root's parent; all descendant checks remain active.
Native Windows symlink creation was unavailable. A guarded Windows junction
attempt was rejected by automatic approval review and was not retried through
another shell. Linux CI requires the isolated native symlink regression to pass.

Validation evidence, actual command outcomes and device limitations are recorded
outside source in the task's results report. Android tests use an isolated QA
package and owned fixture saves; existing shipping and unknown phone saves are
not erased.

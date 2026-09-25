# Omarchy update process

This document describes the intended update behavior now that Omarchy is
package-backed. It covers the blessed update path plus what happens when a user attempts to
bypass it:

1. `omarchy update` — the blessed interactive Omarchy update flow.
2. `sudo dnf upgrade` — guarded by Omarchy and aborted with instructions unless
   the user explicitly bypasses the guard.

The design goal is:

- `omarchy update` owns the visible update pipeline: package transaction,
  migrations, post-update hooks, update-state refresh, and restart checks.
- Migrations run per-user after dnf finishes, because they may need `$HOME`,
  DBus/session state, a graphical session, sudo, or user interaction.
- Users who bypass `omarchy update` are nudged back by the dnf guard; if they
  explicitly bypass it, their session is notified when migrations are pending.

## State and coordination files

| Path | Owner | Purpose |
| --- | --- | --- |
| `${XDG_RUNTIME_DIR:-/tmp}/omarchy-update.lock` | user | Prevent overlapping update runs. Owned by `omarchy-update-lock`; compatibility wrappers inherit/respect it. |
| `/tmp/omarchy-update.log` | user | Transcript of `omarchy update`, used by `omarchy-update-analyze-logs`. |
| `~/.local/state/omarchy/current/` | user | Generated active theme, selected theme name, and current background symlink. |
| `~/.local/state/omarchy/migrations/` | user | Per-user migration markers. |
| `~/.local/state/omarchy/reboot-required` | user | Optional reboot marker checked by `omarchy-update-restart`. |
| `~/.local/state/omarchy/restart-*-required` | user | Optional service/app restart markers checked by `omarchy-update-restart`. The shell needs no marker: it is restarted unconditionally after every update. |

## Migration layout

See [`migrations.md`](../agents/skills/migrations.md) for the full migration model, authoring
guidelines, and troubleshooting notes.

Migrations live in:

```text
migrations/*.sh
```

They run as the current user through:

```bash
omarchy-migrate
```

Completion state is per-user:

```text
~/.local/state/omarchy/migrations/<migration filename>
```

Every user gets a chance to run every migration. Migrations run as the user;
privileged work should invoke the appropriate helper or privilege prompt.
Migrations must be idempotent; if one user already applied a machine-wide repair,
the migration should no-op for other users.

For watchers and diagnostics, `omarchy-migrate --pending` prints pending
migration names and exits `0` when any are pending. When no migrations are
pending, it prints nothing and exits non-zero.

## Dnf guard

dnf has no ALPM-style pre-transaction hooks, so there is no hook file: the
guard is a check run by wrappers around direct upgrades. `bin/omarchy-update`
brackets its package transaction with the Hyprland reload guard instead:

```bash
omarchy-hyprland-reload-guard pause
omarchy-update-system-pkgs
omarchy-hyprland-reload-guard resume
```

which replaces the Arch ALPM pause/resume hooks that disabled live Hyprland
config reloads while `/usr/share/omarchy/default/hypr/**` was replaced.

`omarchy-update-system-pkgs`, `omarchy-refresh-pacman`, `omarchy-reinstall-pkgs`,
and `omarchy-channel-set` run their transactions through the hidden
`omarchy-update-dnf` helper:

```bash
omarchy-update-dnf dnf ...
```

The helper sets `OMARCHY_UPDATE_DNF=1` (which is what the guard allows) and
registers the transaction as a PID 1 scope (`systemd-run --scope`) when booted
under systemd, so a mid-transaction systemd reexec cannot SIGKILL it out of
the user session's cgroups; without systemd it runs the transaction directly.
It takes the full transaction command, so the Nobara `nobara-sync cli` branch
of `omarchy-update-system-pkgs` gets the same shielding (the legacy
`OMARCHY_UPDATE_PACMAN` / `OMARCHY_ALLOW_DIRECT_PACMAN` markers are still
honored for old hooks). A user can intentionally bypass the guard with:

```bash
sudo env OMARCHY_ALLOW_DIRECT_DNF=1 dnf upgrade
```

The guard does not start `omarchy update` itself; it only aborts with
instructions.

## Path 1: `omarchy update`

High-level flow:

```text
omarchy-update
  ├─ ensure transcript logging through script(1) → /tmp/omarchy-update.log
  ├─ omarchy-update-lock
  │    └─ acquire the update lock and run omarchy-update inside it
  ├─ omarchy-update-requires-free-space
  │    └─ abort below the configured free-space threshold on /
  ├─ confirm unless -y
  ├─ omarchy-update-pkg-prune
  │    └─ clean downloaded dnf packages, deliberately before the snapshot
  │       since the cache lives on the snapshotted subvolume
  ├─ create snapper snapshot (skipped silently without snapper; snapper
  │  installed but unconfigured fails the snapshot loudly, pointing at
  │  install/config/snapper.sh, and the update continues without one)
  ├─ omarchy-update-stay-awake start
  ├─ run package updates, migrations, hooks, and log analysis
  ├─ omarchy-update-status
  │    └─ refresh or clear the shell update indicator
  ├─ omarchy-update-stay-awake stop
  │    └─ release the sleep inhibitor and restore shell idle state, if changed
  └─ omarchy-update-restart
```

Important behavior:

- In dev-link mode, `omarchy update` fast-forwards the active checkout from its
  configured upstream before changing system packages or running migrations.
- `-y` exports `OMARCHY_UPDATE_UNATTENDED=1` — a promise not to ask anything.
  Steps that would prompt (orphan removal, conflict handoff) report and skip
  instead of blocking.
- The free-space requirement uses a 10 GiB threshold and stops the update before
  confirmation when it is not met. If free space cannot be determined, the
  check is silently skipped. Set `OMARCHY_UPDATE_FORCE=1` to bypass the check.
- `omarchy update` checks/runs migrations in the same visible terminal via
  `omarchy-migrate` after dnf finishes.
- A failure should leave enough output in `/tmp/omarchy-update.log` and the
  terminal transcript to debug.

## Path 2: direct `sudo dnf upgrade` attempt

High-level flow:

```text
sudo dnf upgrade
  ├─ guard aborts and tells the user to run omarchy update
  └─ if explicitly bypassed, upgrades omarchy and related packages
  └─ at that user's next login
       ├─ graphical-session.target starts
       ├─ omarchy-migrate-notify.service starts after it
       ├─ omarchy-migrate-notify checks omarchy-migrate --pending
       ├─ if this user has missing migration state, show notification
       └─ click opens terminal: omarchy-migrate
```

Login is deliberately the only trigger. A watcher on the packaged migration
directory cannot distinguish a bypassed `dnf upgrade` from the package
transaction inside a normal `omarchy update`, so it fired notifications for
migrations that `omarchy-migrate` was about to apply in the visible update
terminal. The retired unit was `omarchy-update-user-notify.path`.

Retiring that watcher through a migration cannot come in time for the update
that retires it: dnf writes the migration directory, the watcher fires, and
only then does `omarchy-migrate` reach the migration that stops it. So the
notifier also refuses to run while `omarchy update` holds its
`$XDG_RUNTIME_DIR/omarchy-update.lock`, which covers the stale watcher and any
trigger added later — during an update, every pending migration is by
definition already being applied a step away. It checks again after waiting for
the notification server, since that wait is long enough for an update to start
underneath it.

The notifier reads only its own user's runtime directory, never the `/tmp` path
`omarchy-update` falls back to when `XDG_RUNTIME_DIR` is unset. A shared lock
file belongs to whoever created it first, so honouring it would let one user
silence another user's notification. Missing an update and showing a redundant
toast is the better failure.

Suppression is why `omarchy-update-stay-awake` starts its sleep inhibitor with
the lock descriptor closed. That inhibitor outlives the step that starts it, so
an update killed before cleanup would otherwise leave it holding the flock
indefinitely — blocking later updates and, now that the notifier reads the same
lock, silencing migration notifications at every login.

Fallbacks:

- `omarchy-provision-first-run` enables `omarchy-migrate-notify.service`, which also
  covers users created after install: their per-user migration markers are
  missing, so their first login prompts them to run every shipped migration.
- The package ships `omarchy-update-user-notify.service` as a symlink onto
  `omarchy-migrate-notify.service`. Users set up before the rename hold an
  absolute `graphical-session.target.wants` symlink to the old path, and the
  migration that repoints it only runs for users who run an update — the
  opposite of who the notifier is for. The alias can be dropped once installs
  have run migration `1785095882`.
- The notifier is ordered after `graphical-session.target`, so an action that
  launches through `uwsm-app` cannot block the target that gates UWSM's app
  daemon.
- The notifier waits for a live notification server before sending, because
  `graphical-session.target` can be reached before the shell claims
  `org.freedesktop.Notifications`.
- The notifier is only a prompt. It does not run migrations in the background.
- A session that is already open when another user updates is not re-checked;
  it picks the migrations up at its next login, or whenever that user runs
  `omarchy-migrate` or `omarchy update`.
- Direct dnf updates do not run `omarchy-hook post-update` unless the user
  explicitly runs that hook; without a package-update marker, the only pending
  state we can derive is missing per-user migration markers.

## Shell update indicator

The bar widget `omarchy.system-update` runs:

```bash
omarchy-update-available
```

`omarchy-update-available` checks the active Omarchy sources for updates:

- new upstream commits for the active dev-linked checkout
- `omarchy-dev`, when installed
- otherwise `omarchy`, when installed

The dev check fetches the checkout's configured upstream before comparing it
with `HEAD`. A failed fetch is quiet and falls back to the existing remote-
tracking state.

Exit codes:

- `0` — Omarchy updates are available; stdout is the update list.
- non-zero — no Omarchy updates are available; stdout says Omarchy is up to date.

The widget runs this check on shell startup and every six hours. Clicking the
update icon launches `omarchy-update` in a floating terminal.

## Channels and versions

Updates install whatever the active channel points at. `omarchy-channel-set
<stable|rc|edge|dev>` switches channels: the three package channels refresh
dnf metadata (and install the `omarchy` / `omarchy-dev` RPMs once omadora RPM
repos ship; until then `omarchy-version-channel` reports `unknown`), while
`dev` links the runtime to a git checkout via the dev-link mechanism, after
which `omarchy update` fast-forwards that checkout instead of upgrading a
package.

There is no version file at runtime. `omarchy-version` derives the version from
`rpm -q` on whichever package is installed, or reports `dev (<hash>)` for a
linked checkout, and `omarchy-version-channel` sniffs `/etc/yum.repos.d` to
answer which channel is active.

## Update-related binaries

This inventory is intentionally opinionated. Some commands are useful as stable
leaf commands; others exist mostly because the old update flow accreted small
scripts.

| Binary | Current purpose | Keep? / Question |
| --- | --- | --- |
| `omarchy-update` | Public user command. Adds transcript logging, confirmation, snapshot, and restart checks around the locked, sleep-inhibited update pipeline. | **Keep.** This is the blessed entry point and orchestrates the update pipeline. |
| `omarchy-update-lock` | Hidden command wrapper that holds the per-user update lock while its child runs. | **Keep internal/hidden.** Isolates update concurrency and lock descriptor handling. |
| `omarchy-update-stay-awake` | Hidden helper that starts or stops update-owned sleep and idle inhibition, restoring only the state it changed. | **Keep internal/hidden.** Keeps inhibitor ownership and cleanup together. |
| `omarchy-update-status` | Hidden helper that refreshes or clears the shell update indicator after rechecking available updates. | **Keep internal/hidden.** Keeps shell status synchronization out of the main pipeline. |
| `omarchy-update-confirm` | Gum confirmation copy for `omarchy update`. | **Question.** Could be inlined into `omarchy-update`; separate file only helps keep copy isolated. |
| `omarchy-update-dev` | Fast-forwards the active dev-linked checkout from its configured upstream; no-ops for package-backed installs. | **Keep.** Runs before package updates so a checkout conflict stops the update before system mutation. |
| `omarchy-update-keyring` | Ensures Fedora RPM signing keys are current before the main transaction. | **Keep, but review.** It reinstalls `fedora-gpg-keys`; acceptable for this special case but should remain tightly scoped. |
| `omarchy-update-system-pkgs` | Runs `omarchy-update-dnf` (`dnf upgrade -y`, or `nobara-sync cli` on Nobara) with `LC_ALL=C`, capturing stderr to a report file; on failure it execs `omarchy-update-system-pkgs-when-conflicted`. | **Keep for now.** Small leaf command, clear/testable. |
| `omarchy-update-system-pkgs-when-conflicted` | Hidden conflict handler: quarantines unowned conflicting files under `/var/lib/omarchy/replaced`, retries the upgrade once, restores files the upgrade didn't claim, and hands package-vs-package conflicts to an interactive dnf run (never under `-y`). | **Keep internal/hidden.** Keeps conflict recovery out of the happy path. |
| `omarchy-update-pkg-prune` | Cleans downloaded dnf packages (`dnf clean packages`) before the snapshot, keeping the offline downgrade path while capping snapshot growth. | **Keep internal/hidden.** |
| `omarchy-update-requires-free-space` | Aborts the update below a 10 GiB free-space threshold on `/`; silently skipped when free space cannot be determined; `OMARCHY_UPDATE_FORCE=1` bypasses. | **Keep internal/hidden.** |
| `omarchy-migrate` | Public migration command. Waits for dnf, then runs all pending migrations for the current user. Supports `--pending` and `--baseline`. | **Keep.** This replaces the discarded `omarchy-update-user-finalize` name and no longer needs `--force`. |
| `omarchy-update-pacman-guard` | Guard (historical name) that aborts direct `dnf upgrade` style upgrades unless Omarchy set `OMARCHY_UPDATE_DNF=1` or the user explicitly set `OMARCHY_ALLOW_DIRECT_DNF=1`. | **Keep internal/hidden.** This is what nudges users back to `omarchy update`. |
| `omarchy-update-dnf` | Hidden helper that runs a guard-approved update transaction (`dnf` or `nobara-sync`) as a PID 1 scope (`systemd-run --scope`) so a mid-transaction systemd reexec cannot kill it; runs the transaction directly when not booted under systemd. | **Keep internal/hidden.** Single place that owns how Omarchy invokes privileged update transactions. |
| `omarchy-migrate-notify` | Internal login-time notification helper. Uses `omarchy-migrate --pending` and shows a notification only when this user has pending migrations. | **Keep internal/hidden.** Clear name now that the public command is `omarchy-migrate`. |
| `omarchy-update-user-notify` | Hidden compatibility wrapper for `omarchy-migrate-notify`. | **Temporary.** Keep only for old callers. |
| `omarchy-update-available` | Update checker for shell widget and post-update refresh. | **Keep.** Could eventually be renamed `omarchy-update-check`, but current name matches widget semantics. |
| `omarchy-update-aur-pkgs` | Updates the user's Flathub apps with `flatpak update --user` when Flathub is reachable. | **Keep.** Fedora has no AUR; per-user Flatpaks are the third-party story. |
| `omarchy-update-mise` | Runs `MISE_MINIMUM_RELEASE_AGE=0 mise up` for mise-managed tools — the override of mise's release-age cooldown is the point. | **Keep.** Mise-managed tools are intentionally part of the blessed update path. |
| `omarchy-update-orphan-pkgs` | Lists orphans and prompts before removal; noninteractive mode never removes. | **Keep for now.** Safe because it is prompt-only. |
| `omarchy-update-analyze-logs` | Scans `/tmp/omarchy-update.log` for known failure patterns, currently initramfs generation. | **Keep/expand.** Useful safety net; should grow only for high-signal checks. |
| `omarchy-update-restart` | Prompts for reboot after kernel/Hyprland updates, restarts components with `restart-*-required` markers, and always restarts the shell. | **Keep.** Important final step; may eventually include service-restart checks. |
| `omarchy-update-firmware` | Manual firmware update command using fwupd. Not part of the normal update pipeline. | **Keep separate.** Firmware is not a routine system update step. |
| `omarchy-update-time` | Restarts `systemd-timesyncd`. | **Question.** Not really an update command. Consider renaming/moving under system/time maintenance. |

## Closed decisions

1. **Migrations run per-user from the update pipeline**
   - `omarchy update` runs `omarchy-migrate` after dnf finishes.
   - Package-time migration runners do not apply migrations inside pacman.
   - Every user has per-user migration markers, and migrations must be
     idempotent when they repair machine-wide state.

2. **Migration notification naming**
   - The real helper is `omarchy-migrate-notify`, started by
     `omarchy-migrate-notify.service`.
   - `omarchy-update-user-notify` remains only as a hidden compatibility wrapper.

3. **Update pipeline ownership**
   - `omarchy-update` owns the full update pipeline now.

4. **Mise remains in the blessed update path**
   - `omarchy-update-mise` intentionally runs as part of `omarchy update`.

5. **Orphan cleanup stays in the update path for now**
   - It is prompt-only and never removes packages noninteractively.

6. **Direct dnf user follow-up is based on actual migration state**
   - Direct `sudo dnf upgrade` no longer uses a fake user-update marker.
   - User notifications are shown only when `omarchy-migrate --pending` finds
     missing per-user migration state.

## Remaining concerns

1. **Dnf guard scope**
   - The guard detects direct dnf upgrade invocations and allows Omarchy
     commands that set `OMARCHY_UPDATE_DNF=1`.
   - We may regret blocking some legitimate package-manager frontends or
     maintenance flows. Keep an eye on what should be allowed versus redirected
     to `omarchy update`.

2. **Rpmnew/rpmsave handling is still missing**
   - Package-backed Omarchy should warn about or help process `.rpmnew` and
     `.rpmsave` files after updates.

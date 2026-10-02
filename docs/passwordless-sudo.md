# Temporary passwordless sudo

`omarchy-sudo-passwordless` publishes a bounded grant for the numeric UID authenticated by sudo. Its user interface runs without a reusable sudo timestamp; fixed installed internal actions run as root and serialize on `/run/lock/omarchy-sudo-passwordless.lock`.

## Grant lifecycle

The sudoers rule is the only grant record: it contains the resolved account name and a UTC `NOTAFTER` deadline enforced by sudo itself, including after suspend. Publication validates a dot-prefixed temporary file with `visudo`, arms a calendar cleanup timer, then atomically renames the complete rule into place. There is no separate per-user state file to publish, parse, or reconcile. Failure after renewal starts removes the old grant; failed revocation remains an error and leaves the cleanup timer armed.

An internal status result is `0` for an active, validated grant and `3` for confirmed inactive access. All other results are errors, including failed authentication and failed revocation. The user interface only offers a new grant after result `3`. It must not turn an inspection failure into a claim that no grant exists.

Calendar timers clean up expired files; their liveness does not define authorization. Callbacks read the current rule and remove it only when expired. Earlier callbacks cannot shorten a renewed grant, so no timer identity needs to be persisted. Old UID-only and token-bearing callbacks remain accepted. Pending callbacks after renewal or manual disable are harmless and expire within the maximum 24-hour grant window. Boot-time tmpfiles cleanup removes the reserved generated filename namespace before users log in; routine non-boot tmpfiles maintenance leaves live grants alone.

Legacy cleanup uses a root-owned machine marker under `/var/lib/omarchy/migrations/`, written only after successful cleanup under the grant lock. Later accounts can finish their migration queues without sudo and without revoking grants created after the repair. Old grant state files are no longer consulted. A legacy grant is recognized by its exact filename and rule relationship, since the old command wrote the caller's unvalidated name into both, so accounts outside the current name policy are still cleaned up. The generated filename prefix is reserved: boot cleanup and the package scriptlets already remove everything under it, and the old writer could emit a rule whose body differs from its filename, so the migration moves any other file found there into a fresh root-only directory under `/var/lib/omarchy/sudoers-quarantine/`, as `policy` with the original name stored beside it, rather than leaving it live or deleting its content.

## Package ownership

The packaging companion must put the publication/expiry command, `omarchy-security-functions`, `omarchy-nopasswd-sudo.conf`, and the revocation scriptlets in the settings package together. Removing the desktop runtime alone must leave a working expiry command behind. Stable and development package pairs must transfer ownership in one transaction without duplicate files.

Omadora packages this as the `omarchy-settings` (or `omarchy-settings-dev`) RPM. Upstream Omarchy uses an ALPM `PreTransaction` hook with `AbortOnFail`; RPM gives the same guarantee through scriptlets, because a failing `%pre` stops that package from being installed or upgraded and a failing `%preun` stops its erase. The whole contract lives in the helper, so the spec only calls fixed actions:

```spec
%pre
if [ -x /usr/bin/omarchy-sudo-passwordless ]; then
  /usr/bin/omarchy-sudo-passwordless __package-removing || exit 1
fi

%preun
/usr/bin/omarchy-sudo-passwordless __package-removing || exit 1

%posttrans
/usr/bin/omarchy-sudo-passwordless __package-installed
```

`%pre` of the incoming package runs before its files replace the installed ones, so on upgrade it calls the helper that is still installed; on a fresh install there is no helper yet and nothing to revoke. `__package-removing` sets `/run/omarchy-sudo-passwordless-package-removing` before it waits for the grant lock, so a publisher that already holds the lock is refused instead of publishing a rule the removal would delete, then revokes existing policy under the lock. `__package-installed` runs once the transaction has finished: it sets the same marker, sweeps the reserved namespace under the lock, and clears the marker only when nothing is left and the boot cleanup rule exists. A failed `%pre` can still be followed by other transaction work, so completion never clears the marker while a rule remains.

Before publishing a grant, the helper verifies with `rpm` that it is owned by `omarchy-settings` or `omarchy-settings-dev` and that the owning package's `%pre` and `%preun` scriptlets call `__package-removing` and its `%posttrans` calls `__package-installed`. New grants therefore require both the boot rule and the package revocation. Failed or interrupted transactions leave the marker set; retry the package transaction successfully before requesting another grant.

The runtime marker need not survive reboot: pre-removal revokes the old grants before package files disappear, and a new invocation independently verifies boot cleanup. Both root operations use fixed machine paths. The marker is not a user-controlled mode switch.

Root actions, including the unattended expiry timer, only ever run the packaged `/usr/bin/omarchy-sudo-passwordless`; root never executes user-writable checkout code. Until Omadora ships the settings RPM, an install that runs only from a checkout has no such copy, so the command refuses before any sudo prompt. The legacy-grant migration is the one exception: it reaches the helper through `$OMARCHY_PATH/bin`, which is the package's `/usr/bin` link on an install and the checkout's copy under a dev link, and runs its one-shot cleanup under the user's own authenticated sudo, the same trust `omarchy-dev-link` already extends to the checkout.

## Validation

The two passwordless-sudo test suites share a private filesystem and command fixture, with `rpm` answered by a stand-in so the package ownership and scriptlet checks run without an installed package. They cover caller validation, the checkout-only refusal, the public prompt boundary, atomic publication, renewal failures, expiry, old callbacks, machine migration through `$OMARCHY_PATH`, the package scriptlet actions, the source/package lock, and the shipped boot cleanup rule applied by `systemd-tmpfiles` to a disposable root. An optional `OMARCHY_TEST_SUDOERS` path to sudo's upstream `testsudoers` executable evaluates the generated policy before and after its deadline without root or changing host policy.

These local tests do not establish release readiness. The candidate needs fresh installed-package, suspend/resume, boot-cleanup, and package-removal validation in a disposable VM once the settings RPM exists. The shared security library and its interface are unchanged from upstream Omarchy.

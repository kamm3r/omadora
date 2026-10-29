# Fedora boot and update parity

The behavioral reference is the sibling upstream Omarchy checkout and limine-entry-tool 1.40.0. Fedora replaces the package-manager and image-builder integration, while using the same Limine entry tool and snapshot service.

| Upstream contract | Fedora implementation |
| --- | --- |
| One system package-manager transaction inside `omarchy update` | `omarchy-update-dnf dnf upgrade -y`; no `omadora-sync` invocation or grouped rollback |
| Preserve update confirmation, snapshot, migration, hook and reboot ordering | Existing `omarchy-update` orchestration; DNF's transaction boundary substitutes for the ALPM Hyprland reload hooks |
| Build UKIs when `ENABLE_UKI=yes` | `limine-dracut` 0.2.0 uses dracut and Fedora's systemd EFI stub, then upstream `limine-entry-tool --add-uki` |
| Keep working boot files if image generation fails | Build and sign in a temporary directory; register the UKI before retiring its split-image files |
| Register and remove kernels through package hooks | Fedora kernel-install plugins, including removal of UKI and split entries |
| Rebuild after dracut, firmware, modules, systemd, cryptsetup or LVM changes | RPM transaction file triggers in `limine-dracut`, replacing upstream ALPM triggers |
| Redeploy the EFI loader after Limine changes | RPM transaction file trigger using `limine-install --no-efi-register` |
| `limine-update` deploys firmware and refreshes images | Fedora compatibility command performs both steps |
| Boot the updated primary kernel by default | Generated `zz-fedora-kernel.conf` prefers the newest installed Fedora kernel version; `/etc/default/limine` retains administrator override priority |
| Direct Boot uses a UKI on the ESP | `bootctl --print-esp-path` resolves Fedora's separate `/boot/efi`; upstream hardware guards remain in force |
| Boot snapshots and offer restoration | Upstream `limine-snapper-sync`, `limine-snapper-restore` and the existing desktop autostart entries |

## Runtime and packaging boundaries

The generic boot integration belongs to the sibling `limine-pkg` repository, under `packages/limine-dracut/`. Matching helper sources remain under `install/fedora/` for historical migration compatibility. New installation requires `limine-dracut >= 0.2.0`; publish that package before deploying an Omadora revision that requires it. Local RPM installation does not publish COPR packages.

The main and fallback EFI binaries are both Limine. Retained Fedora kernels and dracut are the operating-system substrate, rather than a second desktop setup. Keeping older kernel entries provides recovery without changing the primary kernel preference.

## Existing-machine capacity and firmware

The development machine has a 600 MB ESP, a separate ext4 `/boot`, and AMI firmware. The upstream Direct Boot command deliberately refuses this firmware; generating UKIs does not bypass that restriction or create a Direct Boot NVRAM entry.

This ESP cannot hold several distinct sets of kernel images and their recovery copies. Its local `/etc/default/limine` uses `MAX_SNAPSHOT_ENTRIES=auto` and the standard 85% space limit. The snapshot service rotates boot-image history to fit. This does not change Snapper's root snapshot retention. A larger ESP is necessary to guarantee the same boot-snapshot capacity as an upstream installation with a larger boot partition; no partition resizing is performed here.

## Verification

Focused tests cover UKI versus split-image selection, embedded command-line resolution, preservation of old entries on build failure, natural version selection, kernel-install delegation and separate-ESP Direct Boot registration. The RPM build runs syntax checks and produces the helper files and transaction triggers. On the development machine, inspect UKI identities, embedded command lines, all menu file references and BLAKE2 checksums after conversion.

A successful image build is not a successful boot test. Normal UKI startup, entering a snapshot session and restoring from that session require a reboot or a disposable VM. Do not mark those verified from static checks. In particular, this development machine's snapshot restore also restores the earlier development-path and package state captured by that snapshot.

References: [upstream Limine entry tool](https://gitlab.com/Zesko/limine-entry-tool), [dracut UKI options](https://dracut-ng.github.io/dracut/dracut.8.html).

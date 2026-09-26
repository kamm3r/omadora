# omadora-sync

`omadora-sync` is Omadora's system updater. It upgrades pending packages one group at a time (kernel, graphics stack, system core, desktop environment, everything else), rebuilds kernel modules and boot images after a kernel or driver change, and rolls a group's exact DNF transaction back when it fails or leaves modules or boot images invalid. `omarchy update` runs it through `omarchy-update-system-pkgs`.

```text
omadora-sync [cli]        check repositories, then install updates group by group
omadora-sync check-updates list pending system updates (no root needed)
omadora-sync check-repos  probe every enabled repository (no root needed)
omadora-sync repair       resync every package with dnf distro-sync
```

The entrypoint is `bin/omadora-sync`; the package lives in `omadora_sync/` and the group inventory in `package-groups.txt`. An administrator copy at `/etc/omadora-sync/package-groups.txt` replaces the shipped inventory. Each run logs to `/var/log/omadora-sync.log`, keeping five older logs.

## License and origin

`omadora-sync` is a modified copy of `nobara-sync` from nobara-updater 2.0.1 by the Nobara Project (https://github.com/nobara-project/nobara-core-packages), and like it is licensed under the GNU General Public License, version 3 or later; see `LICENSE` in this directory. The rest of Omadora keeps its own license. `omadora_sync/dnf.py` and `omadora_sync/grouped_updates.py` are the upstream `nobara_updater` modules with the changes below; `bin/omadora-sync` is a rewrite of the `nobara-updater` CLI path.

## Changes from nobara-sync (2026)

- Terminal only: the GTK window, the codec wizard, and every GTK, GObject, Flatpak, dnf4, `requests` and `psutil` import are gone. The only runtime dependency beyond Python is `python3-libdnf5`.
- No Nobara quirk fixups, notices download, yumex tray refresh, or `/etc/nobara` markers. On Nobara hosts `omarchy-update-system-pkgs` still runs `nobara-sync install-fixups` before `omadora-sync`, so those repairs stay Nobara's.
- No Flatpak updates: Omadora updates the user's Flatpaks separately in `omarchy-update-aur-pkgs`.
- Boot images go through `limine-mkinitcpio` when it exists, which regenerates every initramfs and re-registers each kernel with Limine; a bare `dracut --regenerate-all` would leave Limine booting stale copies. Plain `dracut` remains the fallback.
- `repair` no longer deletes `/lib/modules` directories that lack a `/boot/vmlinuz-*`: with Limine the kernels live on the ESP, so that rule would delete every module directory. It also no longer re-executes itself.
- Package groups describe Omadora's Hyprland desktop instead of Nobara's KDE and GNOME kickstarts.
- A reboot after a kernel or driver update is recorded with `omarchy-state set reboot-required` for the invoking user, so `omarchy-update-restart` asks for it, instead of being announced here.
- Elevation goes through `sudo` on `PATH` (the command-scoped wrapper inside `omarchy update`) rather than `sudo -E`, `pkexec`, or `xhost`. Listing updates and checking repositories run as the caller.
- Progress goes to stdout and problems to stderr, so the update's conflict handler reads resolve problems and file conflicts without swallowing the progress.
- The log is a root-owned file in `/var/log`, never a file root writes into the invoking user's home. Python runs isolated (`-I`) and writes no bytecode into the checkout.

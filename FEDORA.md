# Omadora on Fedora

Omadora is a Fedora 44 port of [Omarchy](https://omarchy.org) (Arch-based).
Command names, `$OMARCHY_PATH`, config layouts, themes, and the Quickshell
desktop are unchanged; only the OS substrate was swapped. The Arch upstream is
a readonly reference and is never modified.

## Package management: dnf5 instead of pacman

- `bin/omarchy-pkg-add/drop/present/missing/install/remove` keep their CLI
  surface but are backed by `dnf install/remove` and `rpm -q` instead of
  `pacman -S/-R/-Q`.
- There is no AUR on Fedora. The `bin/omarchy-pkg-aur-*` helpers install
  per-user Flathub apps (`flatpak install --user`, never `--system`) and take
  Flathub app IDs (`md.obsidian.Obsidian`, `com.moonlight_stream.Moonlight`,
  `io.github.zen_browser.zen`, ...); `omarchy-pkg-aur-accessible` probes the
  Flathub repo, and `omarchy-update-aur-pkgs` runs `flatpak update --user`.
  RPM-land third-party sources (COPR, RPM Fusion, Terra) ride along with the
  regular `dnf upgrade`.
- `bin/omarchy-update-system-pkgs` runs `dnf upgrade -y`. On Nobara hosts
  (detected via `nobara-sync` on PATH) it runs `nobara-sync cli` instead:
  Nobara quirk fixups plus grouped transactions with per-group rollback and
  kernel-module validation, safer for Nobara kernels and akmods. No `--all`:
  user Flatpaks stay on `omarchy-update-aur-pkgs`. The conflict handler only
  parses dnf-format errors; a nobara-sync failure already rolled itself back,
  so anything unmatched lands with a human, as before.
- dnf5 CLI quirks the port works around: a bare `dnf list available` prints
  nothing (it wants a package-spec pattern), so the package picker lists
  candidates with `dnf repoquery --available --queryformat '%{name}\n'`
  instead; and global flags like `--quiet` must precede the subcommand
  (`dnf list --quiet available <spec>`, not `dnf list available --quiet
  <spec>`).
- `bin/omarchy-update-orphan-pkgs` uses `dnf repoquery --unneeded` +
  `dnf autoremove`; `bin/omarchy-update-pkg-prune` runs `dnf clean packages`;
  `bin/omarchy-update-available` uses `dnf check-upgrade`;
  `bin/omarchy-version-pkgs` reads `dnf history`.
- `bin/omarchy-refresh-pacman` keeps its name (callers depend on it) but
  refreshes dnf metadata and upgrades instead of rewriting `/etc/pacman.conf`.
  `default/pacman/*.conf` is frozen Arch reference; live repo config lives in
  `/etc/yum.repos.d` via `install/fedora/repos.sh`.
- `bin/omarchy-update-keyring` ensures `fedora-gpg-keys` instead of
  `archlinux-keyring`/`pacman-key`, and fails loudly like upstream when the
  install or the verification fails instead of printing success anyway.
- `bin/omarchy-update-dnf` is the Fedora analog of upstream's hidden
  `bin/omarchy-update-pacman`: it runs update transactions (`dnf ...`,
  `nobara-sync cli`) as a PID 1 `systemd-run --scope` so a mid-transaction
  systemd reexec cannot SIGKILL them, and sets `OMARCHY_UPDATE_DNF=1` for the
  guard. All update-flow callers (`update-system-pkgs`, `refresh-pacman`,
  `reinstall-pkgs`, `channel-set`) go through it.
- `bin/omarchy-update-pacman-guard` keeps its filename but watches for direct
  `dnf upgrade`/`distro-sync` (override: `OMARCHY_ALLOW_DIRECT_DNF=1`). The
  ALPM `PreTransaction` hook (`default/libalpm/...-update-guard.hook`) is
  deleted: dnf has no equivalent. The Hyprland reload pause/resume ALPM hooks
  are likewise inert files; `bin/omarchy-update` brackets the package
  transaction with `omarchy-hyprland-reload-guard pause/resume` instead.
- Channels (`stable/rc/edge`) have no RPM repos yet, so `omarchy-channel-set`
  only switches the dev-checkout state and refreshes metadata;
  `omarchy-version-channel` reports `unknown` until omadora RPM repos ship.
- `bin/omarchy-dev-pkg-test` builds RPMs with `rpmbuild -bb` from
  `$OMARCHY_SPECS_DIR/<pkg>/<pkg>.spec` instead of `makepkg` from PKGBUILDs.
- `bin/omarchy-migrate` waits on the RPM lock instead of `/var/lib/pacman/db.lck`
  and gains `--baseline`, which marks every present migration done without
  running any. Fresh Fedora installs must baseline: pre-port Arch-era
  migrations (pacman/mkinitcpio/limine-Arch-isms) are frozen history and must
  never execute here.
- Migrations that repair the Neovim remote clipboard provider
  (`1781587663.sh`, `1788996284.sh`) install from
  `/usr/share/omarchy-nvim`, which only exists once an `omarchy-nvim` RPM
  ships. Until then they skip the Neovim repair and exit 0 instead of stopping
  every later migration; `1788996284.sh` checks the package version with
  `rpm -q` and `rpm.vercmp` instead of `pacman -Q`/`vercmp`.
- `bin/omarchy-upgrade-to-quattro` refuses non-pacman systems by itself and is
  unchanged (Arch-to-Arch upgrader, out of scope).

## Repositories: `install/fedora/repos.sh`

Beyond Fedora proper: Terra (limine, mise, `usage-cli`, `localsend-bin`,
`uwsm`, lazygit, asusctl, broadcom-wl, xpadneo, v4l2-relayd),
lionheartp/Hyprland COPR (hyprland stack, quickshell), RPM Fusion free/nonfree
(codecs, obs-studio, intel-media-driver, akmod-nvidia, v4l2loopback, sunshine).
Verified against Fedora 44 package names; see the header comments in
`install/omarchy-base.packages` and `install/omarchy-other.packages` for the
full Arch-to-Fedora map and the dropped list.

## Bootloader: Limine from Terra, dracut underneath

Per project decision the Limine stack is kept, not replaced with GRUB:

- `limine` itself installs from Terra (`install/fedora/bootloader.sh`).
- `limine-entry-tool` / `limine-snapper-sync` / `limine-snapper-restore` have
  no RPMs and are built from source into `/usr/local/bin` (same recipe as the
  reference working set); the installer verifies each one exists.
- `install/fedora/limine-mkinitcpio` is the vendored dracut-backed
  implementation of the Arch `limine-mkinitcpio-hook` helper (`dracut -f
  --regenerate-all`, then re-register kernels with `limine-entry-tool`), and
  `install/fedora/limine-update` re-deploys the bootloader binaries (like
  Arch's helper of the same name), so all existing callers work unchanged.
  Both install to `/usr/local/bin` via `install/fedora/bootloader.sh`.
- `etc/dracut.conf.d/omarchy.conf` replaces the mkinitcpio `HOOKS=` list
  (`etc/mkinitcpio.conf.d/omarchy_hooks.conf` stays in tree as reference).
  Hardware quirks that wrote `/etc/mkinitcpio.conf.d/*.conf` (nvidia, apple-t2,
  spi keyboard, surface) now write `/etc/dracut.conf.d/*.conf`
  (`add_drivers+=`) instead.
- Hibernation keeps the mkinitcpio drop-in as its setup marker (the
  available/remove helpers check it) and additionally writes
  `/etc/dracut.conf.d/omarchy-resume.conf` (`add_dracutmodules+=" resume "`),
  which is what actually matters.
- `etc/limine-entry-tool.d/`, `default/limine/limine.conf`, snapshot, and
  factory-reset flows are unchanged.
- `bin/omarchy-update-firmware` stages the fwupd EFI binary at
  `/boot/EFI/omarchy/fwupdx64.efi` instead of `/boot/EFI/arch/`.

## Hardware and services

- NVIDIA via RPM Fusion akmods (`akmod-nvidia`, `.i686` multilib instead of
  `lib32-*`); legacy pre-GSP branch uses `akmod-nvidia-470xx`.
- Firewall is firewalld, not UFW: `install/config/firewall.sh` opens LocalSend
  ports via `firewall-cmd`; sshd/sunshine scripts use rich rules (Tailscale
  covered by its `100.64.0.0/10` CGNAT range). `ufw`/`ufw-docker` are dropped.
- Vulkan drivers are the single `mesa-vulkan-drivers`; `linux-firmware-marvell`
  is bundled in Fedora's `linux-firmware`; no Panther Lake kernel swap
  (stock kernel covers it); `sof-firmware` is `alsa-sof-firmware`;
  `inetutils` is split (`hostname`/`telnet`/`tftp`/`ftp`).
- No-RPM hardware items are documented no-ops with their fallback noted in
  place: T2 kernel/audio/fan, `macbook12-spi` DKMS, `yt6801` DKMS,
  `tuxedo-drivers` (vendor repo), `qmk-hid` (upstream binary),
  `dell-xps-touchpad-haptics`, `dell-xps13-sidecar-amps`, `intel-ipu7-camera`.
- `install/config/enable-services.sh` no longer enables
  `linux-modules-cleanup.service` (Arch `kernel-modules-hook` artifact;
  `installonly_limit`/`autoremove` cover it).
- Browsers: Brave via its vendor repo, Chrome/Edge via vendor repos created on
  demand, Firefox/Chromium from Fedora, Zen via Flathub
  (`app.zen_browser.zen`). Brave Origin (an Omarchy AUR rebuild) has no
  equivalent; its menu entries fail gracefully with an explanation.
- Editors: VSCode (Microsoft repo), Cursor (`cursor` from Terra), Zed (`zed`
  from Terra; `omazed` theme helper pending an RPM), Sublime Text (official
  Sublime repo via `omarchy-install-editor-sublime`), stock `emacs`,
  `vim-enhanced`, `neovim`, `helix`.
- Services: NordVPN via its official release RPM
  (`nordvpn-release-1.0.0-1.noarch.rpm`); Bitwarden via Flathub
  (`com.bitwarden.desktop`) plus the Terra `bitwarden-cli` RPM; Spotify via
  Flathub (`com.spotify.Client`); ONCE via the upstream release binary
  (`ONCE_VERSION`, default 0.3.2) plus the vendored
  `default/systemd/system/once-background.service`; Voxtype needs a manual
  install from https://voxtype.io/ (installer configures it afterwards);
  LM Studio via Flathub (`ai.lmstudio.lm-studio`); Xbox controllers via the
  Terra `xpadneo` RPM (plus `kernel-devel`, not `linux-headers`).
- AI desktop apps: `hermes-desktop` and `claude-desktop` are Omarchy
  repackagings with no Fedora RPM or Flathub build yet, so Install > AI keeps
  upstream's entries and scripts unchanged and they fail at `omarchy-pkg-add`
  until an omadora COPR ships them. Choosing Hermes as the default agent
  installs Hermes Desktop the same way. The Hermes migrations only retire the
  old mise build and never install the app, so they run cleanly without it.
- Development: Symfony CLI via its upstream release RPM (`SYMFONY_VERSION`,
  default 5.20.0, provides `symfony-cli`). Dropbox has no Fedora path yet
  (`dropbox`/`nautilus-dropbox`/`dropbox-cli` are all unpackaged).
- Gaming: Steam (`steam` from Terra), Heroic (`heroic-games-launcher` from
  Terra), RetroArch (Fedora's 14-core set; full set via Flatpak
  `org.libretro.RetroArch`), 32-bit drivers via `.i686` multilib
  (`mesa-vulkan-drivers.i686`, `xorg-x11-drv-nvidia-libs.i686`).
- Flatpak fills gaps with no RPM, always `--user`: Obsidian
  (`md.obsidian.Obsidian`), Moonlight (`com.moonlight_stream.Moonlight`), Zen
  browser (`app.zen_browser.zen`, via `omarchy install browser zen`),
  Sunshine fallback (`dev.lizardbyte.app.Sunshine`), LM Studio
  (`ai.lmstudio.lm-studio`), full RetroArch core set
  (`org.libretro.RetroArch`); `lazydocker`/`tzupdate` install from
  upstream/pipx. The Flathub user remote is added by
  `install/fedora/repos.sh` (as the login user, never root). Omarchy's own
  tools (aether, cliamp, herdr, omacalc, omacut, omawrite, omarchy-nvim,
  tensaku, tobi-try, ttfx) stay commented in the package list until an omadora
  COPR or source build ships them.

## Install order on Fedora

1. `install/fedora/repos.sh` (third-party repos + metadata)
2. `install/omarchy-base.packages` + `install/omarchy-other.packages`
   (`dnf install`, groups `@core`/`@development-tools` cover Arch `base`/`base-devel`)
3. `install/fedora/bootloader.sh` (limine + dracut shim + snapper service)
4. `install/config/*`, `install/hardware/*` (repos step renamed
   `hardware/fedora-repos.sh`, `post-install/pacman.sh` replaced by
   `post-install/dnf.sh`)
5. `omarchy-migrate --baseline` on fresh installs, then per-user setup.

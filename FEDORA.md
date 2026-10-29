# Omadora on Fedora

Omadora is a Fedora 44 port of [Omarchy](https://omarchy.org) (Arch-based).
Command names, `$OMARCHY_PATH`, config layouts, themes, and the Quickshell
desktop are unchanged; only the OS substrate was swapped. The Arch upstream is
a readonly reference and is never modified.

Upstream changes are synced through `84782475a` (October 29, 2026), preserving the Fedora differences below. Arch-only upstream work is left out: the Dell XPS 13 Panther Lake speaker firmware and display commits (pacman firmware packages and an `omarchy-update-pacman` retention step) and the OPR repository priority in `pacman.conf`.

- The October 29 sync carries the native Wayland screensaver, persistent per-monitor scaling and GDK scaling, touchpad gestures with a migration preserving custom gestures, background-intro sequencing for theme and background changes, calmer clock press feedback, subscription-only agent sections with stale-usage tooltips, bounded wallpaper sampling, capture and download notification refinements, T3 Code mount recovery, and desktop test fixes. The native screensaver uses the published Fedora RPM; its optional Amiga demo bundle remains unshipped. PipeWire client and JACK drop-ins bypass stale portal realtime budgets, and a DNF-backed repair preserves noninteractive authorization and interrupted-repair recovery. Fedora retains its platform boot lifecycle; Surface Pro 11 Arch kernel/device-tree setup, Arch-only Quattro changes, and the upstream Arch VM/oligarchy CI remain excluded.

- On Nobara, automatic orphan removal is skipped while `nobara-updater` is installed. Nobara protects codec packages and their installed dependencies even when DNF marks one unneeded; generic `dnf autoremove` can therefore be rejected. The codec guard stays enabled, and ordinary Fedora installs retain orphan cleanup.

- Fedora's default inotify instance limit of 128 can be exhausted by the Quickshell desktop alongside Electron apps or a second development shell. The shipped limit is 1024, and migration `1793081529.sh` raises an existing lower runtime limit without reducing a higher one. Plugin discovery waits for watcher readiness, compositor-dependent tests run serially, and the idle-spawn guard reports a noisy measurement as skipped instead of treating desktop activity as polling.

- The October 27 sync protects unreadable shell configuration from being overwritten, restores a panel-disabled laptop display when its last external display is unplugged, keeps unresolved FIDO2 authfile repairs pending and rechecks earlier completions, and stops background-intro frame polling once nothing is covered. It also carries upstream test cleanup and shared QML harnesses while retaining Fedora-specific hardware and privilege coverage. Arch-only Quattro and kernel migrations, N1x firmware/audio repairs, Snapdragon mkinitcpio modules, and removal of workarounds now handled by linux-omarchy 7.3-3 remain excluded; Fedora keeps its platform lifecycle and dracut setup.

- The October 26 sync carries the translation refresh, notification action-aware shortcuts, anchored clock/weather popups, closing-popup input guards, agent shim discovery, monitor FALLBACK filtering, About localization, Git setup polish, and Jade Horse replacing Osaka Jade. The update keeps one authorization through the boot check; Fedora's third-party step remains unprivileged per-user Flatpaks. Hibernation resume uses a filesystem UUID on unencrypted devices and retains device-mapper names, with retryable boot rebuilds through Fedora's dracut-backed shim. Herdr starts with the graphical session only when its optional command is installed.
- The new native `omarchy-speedtest` client has no Fedora RPM, so the existing fast.com helper and panel remain. Screenshot Open/Edit notifications require Omasnap's new `--notify` option, absent from the current Fedora 1.21.0 build; the existing screenshot and clipboard flows remain until a compatible RPM ships. About keeps Fedora's DNF/RPM package-update date lookup.

- The October 25 sync carries browser recovery when a configured handler disappears, separate full-size scratchpad and Quake-console workspaces, persistent floating-workspace titlebar loading when the plugin is installed, bar press feedback and indicator hover fixes, improved notification grouping, a normal 30-second low-battery toast, translated setup forms and first-run notifications, and bounded error-body reads in agent usage requests. A failed mise tool download now warns while the system update still completes boot verification and its reboot prompt.
- Fedora retains stock `power-profiles-daemon` and the system-Python shebang repair. Upstream's `omarchy-power-profiles-daemon` replacement and migration `1791554699.sh` are deferred pending Fedora hardware patch assessment and an RPM; pacman's replacement flags are not carried. Fedora's DNF reinstall path stays unchanged.

- The follow-up October 24 sync adds coding-agent and provider usage collectors, additional default agents and branded glyphs, notification action buttons and keyboard control, saved-recording Open/Omacut actions, first-login Git identity and GitHub setup, and portable fingerprint enable/disable lifecycle hooks. The shell carries reduced-motion-aware panel transitions, tooltip handoff, button feedback, dock motion, bar theme fades, and drag-off widget removal. Video backgrounds use a still poster on the lock screen, so `owe-lockfeed` leaves the default package list. Fedora's RPM dispatch and package mappings remain intact.
- New agent CLIs are lazy mise declarations in the companion settings RPM's `etc/mise/conf.d/omarchy-tools.toml`. Deploy a rebuilt settings RPM before migration `1792504295.sh`; the migration intentionally stays pending until the Qwen declaration is installed. The new agents do not require additional Fedora RPMs.

- The October 24 sync removes the notification history panel, notification preferences, per-source snoozing, and the screen-sharing prompt; grouped toasts, actions, and Do Not Disturb remain. Fingerprint removal deletes device-stored prints before stopping fprintd, and enrollment instructions fit the setup terminal. Hermes seeds its desktop app into the ARM build directory while preserving existing installations; its Fedora package availability remains unchanged. Upstream's migration-test cleanup is carried without changing the migrations themselves or Fedora's runtime adaptations.

- The October 23 sync carries instant notification show/dismiss, simplified notification controls, restored Taildrop image previews and home-relative paths, fuller battery status text, robust menu reloads, safe keybinding scans, the indicator-peek hover fix, and virtualized Tailscale machine lists. The branded font includes the Tailscale mark. Fcitx stays inactive where its binary is absent, and the Taildrop receiver waits for the session environment before starting.
- Connectivity checks use the `ping.omacom.io` NetworkManager drop-in, owned by the companion settings RPM spec. The captive-portal command opens a floating sign-in window and temporarily pauses an active Tailscale exit node, restoring it afterwards; migration `1792507034.sh` reloads NetworkManager after the new settings package is installed. The notification cleanup migration preserves Do Not Disturb while removing obsolete message and image files.
- China timezone aliases are carried for the existing region marker. Arch China mirror lists, pacman rendering helpers, and their channel/update changes remain excluded; Fedora's repository setup remains authoritative.

- The October 22 sync carries verified fingerprint enrollment with step-by-step prompts, confirmation of resumed drive-password changes before retiring a key, display-layout preservation, late personal-rule exclusions for floating workspaces, non-Latin keyboard ordering, synchronous initial translation loading, and test isolation fixes. Lutris and Battle.net install Fedora multilib GPU libraries before their other dependencies; first-run update prompts check DNF's update status and the development checkout. Weather auto-location and installer timezone lookup use `geo.omarchy.org`.
- Arch pacman channel templates and channel transaction changes remain excluded. The new kernel picker depends on Arch's `/usr/lib/modules/*/pkgbase` naming and is deferred rather than advertising a nonfunctional Fedora menu. Fedora keeps its existing kernel/Limine/dracut flow and chrony clock setup; the new systemd-timesyncd fallback-server drop-in is not shipped.

- The follow-up October 20 sync promotes Appearance to the top-level menu, carries its translated menus, and updates its callers. Themes use `Super + Ctrl + T`, backgrounds `Super + Ctrl + W`, Network `Super + Ctrl + N`, Activity `Super + Shift + T`, and Calculator `Super + Shift + Q`. Install media can preset the desktop language, keyboard and timezone; Fedora generates the chosen language through `glibc-langpack-*`, and user setup seeds the language without a session or notifications. Existing language choices and named user folders are preserved. Owner setup settles the region marker without rendering pacman repositories; the Arch-only Quattro upgrader remains unchanged.

- The October 20 sync carries the new notification stacks, snoozes and history panel, Elsewhen place search and people, media-title scrolling, consistent touchpad scrolling for TUIs, and factory-reset rollback and shared-ESP safeguards. Notifications resolve icons locally and never fetch site icons; KDE Connect is an ordinary sender. The default Fedora package set already provides the final notification engine's dependencies.
- Node is now a native lazy mise default, and upgrade pruning is disabled in the shipped system mise configuration. The Node and auto-prune migrations preserve pinned versions, preinstall opt-outs, and user configuration overrides. T3 Code's migration installs and themes without prompting or launching, and removes the old Fedora/current RPM names only after theming succeeds. The superseded interactive T3 theme migration is removed.
- Keyboard screenshots now use `Super + Ctrl + Alt + C`; `Super + Shift + S` opens Google Maps again. Calculator shortcuts follow the preinstalled-app opt-out. The Neovim transparency migration skips user-managed configurations without `omarchy-nvim`. Fedora's Zen Flatpak guard, package helpers, boot adaptations, and T3 Code RPM compatibility are retained.

- The October 19 sync carries per-monitor workspaces and bar labels, Codex spend-limit details, language changes propagated into Hyprland, safe Taildrop notification glyphs, Bitwarden window rules, gaming architecture guards, background-selection repair, and platform-declared fingerprint readers. Fedora keeps its libfprint packages, Spotify uses Flatpak on x86 and the web player on ARM, and Dropbox remains x86-only until a Fedora ARM installation path exists.
- Default CLI tools now use mise's native lazy shims instead of generated wrappers. The companion `omadora-pkg` settings spec owns `etc/mise/conf.d/omarchy-tools.toml`; deploy the rebuilt settings RPM before running migration `1791382872.sh`, which deliberately stays pending until those declarations exist. This needs mise 2026.10.11 or newer; Terra provides it.
- T3 Code installs as a per-user self-updating AppImage, with stable/nightly selection and a migration covering both current RPM names and the older Fedora `t3code` package. Existing threads and settings stay in the user's home. Arch pacman channel changes, mkinitcpio/Plymouth vconsole hooks and their rebuild migration, and the seed-dependent OpenClaw move remain excluded. Fedora retains its dracut setup and OpenClaw RPM/npm fallback; portable OpenClaw launcher recovery and removal bookkeeping fixes are carried.

- The October 17 sync carries setup for already-installed NVIDIA AI Workbench and DGX Dashboard, Snapdragon T14s camera access with Fedora's `pipewire-plugin-libcamera`, the HP EliteBook Ultra G1q microphone UCM profiles, and Snapdragon mpv V4L2 decoding. NVIDIA app packages remain optional and are not added to the Fedora package set. The HP profiles are reference assets for platform packaging; this tree does not install them into the host ALSA directory. Chromium's decoder flags are deferred pending validation against Fedora's Chromium build; upstream targets Arch Linux ARM, and Fedora browser flags remain unchanged. The ARM recovery migration is excluded because it marks Arch Limine packages explicit with pacman, while Fedora uses its existing RPM/dracut boot stack.

- The October 15 sync adds `Super + Shift + S` for screenshots and moves Google Maps to `Super + Shift + Alt + S`, with matching manual updates. The optional `asus-proart-p14-speaker-firmware` package remains deferred: it targets the aarch64 ProArt P14 H7407BA, while the current Omadora COPR target is Fedora 44 x86_64 (see `omadora-pkg/catalog.tsv`).
- Dictation: upstream ships `superwhisper-bin` and selects Superwhisper by default through `config/omarchy/defaults/dictation`. Superwhisper has no Fedora RPM yet, so neither the package nor the default file is shipped; fresh installs pick a backend in Setup > Defaults > Dictation, and the Superwhisper entries stay and fail at `omarchy-pkg-add`, like the AI desktop apps below. Migration `1791479273.sh` keeps Voxtype selected when the `voxtype` command exists rather than only for the `voxtype-bin` package.
- Background intros play through OWE. Older OWE RPMs require the package named `ffmpeg` and conflict with Nobara’s `ffmpeg-free`; the corrected recipe requires `/usr/bin/ffmpeg`. Until the corrected RPM is published and installed, `omarchy-theme-bg-boot-intro` treats a missing `owe` like the intros toggle being off instead of waiting out its five second boot deadline.
- The install list uses the COPR RPM names `localsend`, `ttf-ia-writer`, and `ttf-jetbrains-mono-nerd-basic`. The default list requests `/usr/bin/ffmpeg`, accepting Fedora’s `ffmpeg-free` or an installed full FFmpeg package; the Cliamp, Hype, Monologue, Omacut, and OWE recipes in `omadora-pkg` accept `/usr/bin/ffmpeg` at runtime so they also work with Nobara’s existing codec libraries once those RPM releases are published.
- Disktree replaces the Disk Usage TUI as `disktree-bin` from the Omadora COPR.
- The latest sync carries Kimi selection and usage collection, subscription-account sign-in recovery and SSH copying, browser link routing and default-browser policies, language-specific CJK font fallback, quiet one-second Limine menus (the explicit reboot-to-menu action was removed in the October 19 sync), shell startup fixes, and the parallel shell test runner. The app-building skill keeps RPM/COPR publishing and Fedora dependencies; Limine defaults and tests keep Fedora kernel ordering.
- SSH account copying now matches source names and command IDs and supplies a receiver in memory for older destinations. Fingerprint retries pause while the lock has the displays off and resume on wake; Rust removal calls the real rustup before clearing mise links and shims. The shell test runner overlaps its idle guard with the parallel pool, and test fixtures use shorter waits while retaining the same checks.
- The October 15 sync carries 50-language UI catalogs and translated manuals, bar dragging and section/orientation changes, click clipping, floating-workspace minimization fixes, locale-safe audio/memory parsing, CJK glyph preferences, Hong Kong Cangjie input, and Fcitx theming. Language setup installs Fedora `glibc-langpack-*` RPMs; Norwegian maps to `nb`, both Chinese editions to `zh`, and both Portuguese editions to `pt`. Fedora's split script fonts are in the base set and migration `1792047786.sh` adds them to existing installs. Newly added upstream CJK strings use English until their translations land.
- Platform detection recognizes Snapdragon, NVIDIA N1x, and GB10. Portable touchpad, GB10 sleep, interface ARP, and Surface fixes are carried, with Surface modules written as dracut `add_drivers` and Qualcomm Vulkan provided by `mesa-vulkan-drivers`. Arch ARM manifests/keyrings, custom N1x kernels and firmware-memory changes, nvPCR overrides, Qualcomm DTB/UKI provisioning, Yoga remoteproc setup, the Gliff ARM install migration (its Fedora spec is still x86-only), and firmware-dependent ProArt audio/function-key changes remain deferred until Fedora packages and boot support exist.

- Menu guards cache an RPM package-style names/provides snapshot until the SQLite database or its WAL changes, and avoid storing queries that overlap the RPM lock. Platform lifecycle dispatch queries RPM ownership/version state rather than pacman's local database.
- The portable appearance controls, floating workspace mode, input-method setup, event-driven shell services, screen recording fixes, and Starship theme are carried. `omarchy-hyprland-titlebars` has no Fedora RPM yet, so floating workspaces work without titlebars and its install migration is deferred. Signed now has a published Fedora RPM and is included in the base package list alongside Xournal++; Xournal++ defaults remain in place and the Signed migration is deferred. Gliff has an Omadora RPM and joins the defaults. OBS Studio, Kdenlive, Clang, and LLVM leave the base package set; Rust setup installs Clang and LLVM when needed.
- Arch Linux ARM/Apple Silicon package manifests, pacman keyring/image provisioning, mkinitcpio platform hooks, and Arch channel changes are not carried. The portable LUKS re-key journal and keyboard provisioning changes are carried with their shared helpers. USB/Thunderbolt authorization was added and reverted within this upstream range; neither its setup nor its cleanup migration is carried because Omadora never shipped it. Fedora's existing Limine/dracut implementation stays in charge; the console query boot fix applies through its compatible `limine-mkinitcpio` shim.
- Input methods install Fedora's `fcitx5-mozc`, `fcitx5-hangul`, `fcitx5-chinese-addons`, and `fcitx5-chewing`. Locale repair installs `glibc-langpack-en` instead of editing `locale.gen` or running `locale-gen`.

The default package list explicitly includes `hyprland-preview-share-picker` for the configured portal picker, plus `chrony`, `firewalld`, `flatpak`, and `systemd-resolved` for the Fedora setup and runtime helpers.

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
- `bin/omarchy-update-system-pkgs` runs `omadora-sync cli` on every host:
  Omadora's terminal-only copy of Nobara's `nobara-sync` (GPL-3.0-or-later,
  kept with its license and change list in `default/omadora-sync/`). It
  upgrades in groups (kernel, graphics stack, system core, Hyprland desktop,
  the rest) with per-group rollback, rebuilds akmods/dkms modules and boot
  images through `limine-mkinitcpio` so Limine never boots stale images, and
  records `reboot-required` for `omarchy-update-restart` instead of prompting.
  It needs `python3-libdnf5`; until migration `1790412898.sh` installs it, an
  older install's first update runs plain `dnf upgrade -y`. It is command-line
  only, and the update never launches `nobara-sync`, a GTK application even in
  its CLI modes: on Nobara hosts, Nobara's own repairs are
  `nobara-sync install-fixups`, run by hand.
  User Flatpaks stay on `omarchy-update-aur-pkgs`. The conflict handler parses
  the dnf-format problems omadora-sync writes to stderr; a failed group has
  already rolled itself back, so anything unmatched lands with a human. The
  handler's interactive retry is plain `dnf upgrade --allowerasing`.
  `omadora-sync` is the one command in `bin/` outside the `omarchy-` prefix,
  by name.
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
  `omadora-sync cli`) as a PID 1 `systemd-run --scope` so a mid-transaction
  systemd reexec cannot SIGKILL them, and sets `OMARCHY_UPDATE_DNF=1` for the
  guard. All update-flow callers (`update-system-pkgs`, `refresh-pacman`,
  `reinstall-pkgs`, `channel-set`) go through it.
- `bin/omarchy-update-pacman-guard` keeps its filename but watches for direct
  `dnf upgrade`/`distro-sync` (override: `OMARCHY_ALLOW_DIRECT_DNF=1`). The
  ALPM `PreTransaction` hook (`default/libalpm/...-update-guard.hook`) is
  deleted: dnf has no equivalent. The Hyprland reload pause/resume ALPM hooks
  are likewise inert files; `bin/omarchy-update` brackets the package
  transaction with `omarchy-hyprland-reload-guard pause/resume` instead.
- `bin/omarchy-sudo-passwordless` keeps upstream's hardened grant (sudo
  `NOTAFTER` deadline, boot tmpfiles cleanup, root actions only from the
  packaged `/usr/bin` copy), but the ALPM passwordless-revoke hook becomes
  `omarchy-settings` RPM scriptlets: `%pre`/`%preun` call
  `__package-removing` and `%posttrans` calls the Fedora-only
  `__package-installed`, which holds the removal marker while it sweeps and
  lifts it only once no grant remains. Before publishing a grant the helper
  checks with `rpm` that the settings package owns it and carries those three
  scriptlets (see `docs/passwordless-sudo.md`). Checkout-only installs have no
  packaged helper, so the command refuses there; the legacy-grant migration
  `1788163635.sh` still runs its one-shot cleanup, through the helper at
  `$OMARCHY_PATH/bin` as upstream does, which is the checkout's copy under a
  dev link.
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

Beyond Fedora proper: Omadora COPR (`omarchy`, `omarchy-settings`, and ported
Omarchy apps), Terra (limine, mise, `usage-cli`,
`uwsm`, lazygit, asusctl, broadcom-wl, xpadneo, v4l2-relayd),
lionheartp/Hyprland COPR (hyprland stack, quickshell), RPM Fusion free/nonfree
(codecs, obs-studio, intel-media-driver, akmod-nvidia, v4l2loopback, sunshine).
Verified against Fedora 44 package names; see the header comments in
`install/omarchy-base.packages` and `install/omarchy-other.packages` for the
full Arch-to-Fedora map and the dropped list.

## Bootloader: Limine COPR, dracut underneath

The Limine stack is packaged in [kamm3r/limine-pkg](https://github.com/kamm3r/limine-pkg) and published in `kammer/limine` for Fedora 44 x86_64.

- `install/fedora/repos.sh` enables the repository. `install/fedora/bootloader.sh` also enables it when run independently and explicitly selects it to install `limine`, `limine-entry-tool`, `limine-snapper-sync`, and `limine-dracut`.
- `limine-dracut` owns `/usr/bin/limine-mkinitcpio` (the dracut-backed compatibility command), `/usr/bin/limine-update`, kernel-install configuration, the dracut override, and `/usr/lib/kernel/install.d/96-limine.install`. The installer no longer copies source helpers over those files or installs commands under `/usr/local`.
- Kernel-install uses `layout=other` and `/boot` image paths; the dracut plugin explicitly names `/boot/initramfs-<kver>.img`, and the Limine plugin registers added kernels and removes deleted ones. Other layouts are delegated to Fedora's dracut plugin.
- Omadora keeps its boot-menu defaults, entry-tool drop-ins, dracut policy, hardware settings, and explicit first-install image rebuild. Existing source-installed machines require an explicit helper migration; old migration scripts and their source fixtures remain for historical compatibility.
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
  factory-reset flows are unchanged, except that `BOOT_ORDER` keeps
  `"*, *fallback, Snapshots"`: upstream's preference for `linux-t2` and
  `linux-omarchy` names Arch kernels Fedora does not have.
- Fedora boots its own `kernel` package (Nobara's on Nobara hosts), which
  already carries Panther Lake support. Upstream's kernel migrations
  (`1789325478.sh` moving to `linux-omarchy`, `1789444024.sh` adding its
  headers) are not carried, and neither is the claim that the base install
  guarantees matching headers: akmod and DKMS installers add `kernel-devel`
  themselves. Nor is `1788279117.sh`, which retires the vendor `yt6801-dkms`
  module in favor of the kernel's `dwmac-motorcomm` driver: that DKMS package
  never had a Fedora RPM, so Fedora machines already use the kernel driver.
- `bin/omarchy-update-firmware` stages the fwupd EFI binary at
  `/boot/EFI/omarchy/fwupdx64.efi` instead of `/boot/EFI/arch/`.

## Hardware and services

- NVIDIA via RPM Fusion akmods (`akmod-nvidia`, `.i686` multilib instead of
  `lib32-*`); legacy pre-GSP branch uses `akmod-nvidia-470xx`.
- Firewall is firewalld, not UFW: `install/config/firewall.sh` opens LocalSend
  ports via `firewall-cmd`; sshd/sunshine scripts use rich rules (Tailscale
  covered by its `100.64.0.0/10` CGNAT range). `ufw`/`ufw-docker` are dropped.
  Where upstream's SSH removal deletes every standard UFW rule for port 22,
  `omarchy-remove-security-sshd` removes the setup's rich rule, the `ssh`
  service (which Fedora's default zone enables), and `22/tcp` from the default
  zone, querying each first so absent entries stay quiet and real errors stop
  the removal.
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
  `omarchy-cmd-browser-handoff` recognizes the Fedora binaries too
  (`chromium-browser`, Brave's `brave-browser` and `brave-browser-stable`), so
  launches reach the running browser directly as they do upstream.
  Firefox installs its policies in Fedora's `/usr/lib64/firefox/distribution`; the default-browser policy migration checks that directory as well as the legacy `/usr/lib` location.
- Editors: VSCode (Microsoft repo), Cursor (`cursor` from Terra), Zed (`zed`
  from Terra; `omazed` theme helper from Omadora COPR), Sublime Text (official
  Sublime repo via `omarchy-install-editor-sublime`), stock `emacs`,
  `vim-enhanced`, `neovim`, `helix`.
- Services: NordVPN via its official release RPM
  (`nordvpn-release-1.0.0-1.noarch.rpm`); Bitwarden via Flathub
  (`com.bitwarden.desktop`) plus the Terra `bitwarden-cli` RPM; Spotify via
  Flathub (`com.spotify.Client`); ONCE via the upstream release binary
  (`ONCE_VERSION`, default 0.3.2) plus the vendored
  `default/systemd/system/once-background.service`; Voxtype installs as
  `voxtype-bin` from the Omadora COPR, and an existing install from
  https://voxtype.io/ (RPM name `voxtype`) is recognized by its command;
  LM Studio via Flathub (`ai.lmstudio.lm-studio`); Xbox controllers via the
  Terra `xpadneo` RPM (plus `kernel-devel`, not `linux-headers`).
- OpenClaw keeps the existing npm fallback until a Fedora RPM ships the seed installer and archive under `/usr/share/openclaw`; upstream's new self-updating runtime migration is deferred with that packaging dependency.
- AI desktop apps: `hermes-desktop` and `claude-desktop` are Omarchy
  repackagings with no Fedora RPM or Flathub build yet, so Install > AI keeps
  upstream's entries and scripts unchanged and they fail at `omarchy-pkg-add`
  until an omadora COPR ships them. Choosing Hermes as the default agent
  installs Hermes Desktop the same way. The Hermes migrations only retire the
  old mise build and never install the app, so they run cleanly without it.
- App building: the `omarchy-app` agent skill packages a new app as an RPM
  (`rpm/<name>.spec`, built by `rpmbuild` and installed with `dnf`, with a
  timestamp release so every run upgrades) instead of a PKGBUILD and
  `makepkg -fsi`. Its build set is `gcc-c++`, `make`, the Qt `-devel`
  packages (`qmake6` comes with `qt6-qtbase-devel`), and `/usr/bin/ffmpeg` (provided by `ffmpeg-free` or full FFmpeg). Migration `1790702362.sh` adds `ffmpeg-free` only when no `ffmpeg` is installed.
- Development: Symfony CLI via its upstream release RPM (`SYMFONY_VERSION`,
  default 5.20.0, provides `symfony-cli`). Dropbox has no Fedora path yet
  (`dropbox`/`nautilus-dropbox`/`dropbox-cli` are all unpackaged).
- Gaming: Steam (`steam` from Terra), Heroic (`heroic-games-launcher` from
  Terra), RetroArch (Fedora's 14-core set; full set via Flatpak
  `org.libretro.RetroArch`), 32-bit drivers via `.i686` multilib
  (`mesa-vulkan-drivers.i686`, `xorg-x11-drv-nvidia-libs.i686`).
- Flatpak fills gaps with no RPM, always `--user`: Obsidian (`md.obsidian.Obsidian`), Moonlight (`com.moonlight_stream.Moonlight`), Zen browser (`app.zen_browser.zen`, via `omarchy install browser zen`), Sunshine fallback (`dev.lizardbyte.app.Sunshine`), LM Studio (`ai.lmstudio.lm-studio`), and the full RetroArch core set (`org.libretro.RetroArch`). The Flathub user remote is added by `install/fedora/repos.sh` as the login user. `lazydocker` is no longer preinstalled; users can still install its upstream binary.
- Omarchy's tools `aether`, `cliamp`, `hype`, `monologue`, `omacalc`, `omacut`, `omasnap`, `omawrite`, `owe`, `owe-lockfeed`, `tobi-try`, and `ttfx` ship from `kammer/omadora` COPR and are in the base package list. The `omasnap` and `cliamp` migrations install them on existing Fedora systems.
- Optional Omadora COPR RPMs include `omarchy-audio-tuner`, `omazed`, `omarchy-emacs`, `omarchy-fish`, `omarchy-zsh`, `tensaku`, `ttf-ia-writer`, `python-terminaltexteffects`, `python-sounddevice`, `tzupdate`, and `wayfreeze`. The base package list already includes `xdg-terminal-exec`, which also has an Omadora COPR build.
- `herdr`, `omarchy-nvim`, and `tensaku` are published in the Omadora COPR and remain optional, commented entries in the base package list. Their install migrations run only once dnf can find the package. The separate `omadora-pkg` repository tracks the upstream package inventory and Fedora ports.
- fzf shell integration: `default/bash/init` loads it with
  `eval "$(fzf --bash)"` instead of sourcing upstream's Arch paths
  (`/usr/share/fzf/completion.bash`, `/usr/share/fzf/key-bindings.bash`).
  Fedora's `fzf` ships only `/usr/share/fzf/shell/key-bindings.bash` and no
  completion script, so the Arch paths left Ctrl+R, Ctrl+T, and `**`
  completion unset.
- Split subpackages: Arch's `libxkbcommon`, `plymouth`, and `util-linux`
  carry `xkbcli`, the Plymouth script plugin, and `script(1)`, which Fedora
  ships as `libxkbcommon-utils`, `plymouth-plugin-script`, and
  `util-linux-script`. All three are in the base package list, migration
  `1790573551.sh` adds them to existing installs, and the RPMs require the
  two they depend on: `omarchy` needs `util-linux-script` for the update
  transcript and `omarchy-settings` needs `plymouth-plugin-script` for its
  boot theme. Likewise Arch's `gnome-keyring` brings `gcr` 4 with
  `gcr-ssh-agent`, while Fedora's requires only `gcr3`, so
  `omarchy-setup-security-ssh-agent` installs `gcr` itself. Arch's `libvips`
  also carries `vipsthumbnail`, which `omarchy-menu-images` uses for picker
  thumbnails; Fedora ships it in `vips-tools`, which the base package list
  installs and migration `1791536173.sh` adds to existing installs.

## Packaging: RPM specs and COPR

- Upstream builds its two Arch packages from PKGBUILDs in a separate
  `omarchy-pkgs` repository. Omadora likewise keeps its RPM specs out of this
  tree, in [omadora-pkg](https://github.com/kamm3r/omadora-pkg) under
  `packaging/rpm/omarchy{,-settings}/`, which builds them on the
  kammer/omadora COPR from the Omadora commit pinned in its
  `omadora-revision`; its `packaging/README.md` covers publishing. Versions
  follow `version` with the pre-release after a tilde (`4.0.0~alpha`), and
  COPR releases are `0.<commit count>.git<sha>` of the pinned commit.
- The layout follows `docs/file-layout.md` with Fedora changes: no ALPM hooks
  or pacman trees, no `mkinitcpio.conf.d`, no `nsswitch.conf` override (the
  settings `%post` enables authselect's `with-mdns4` instead),
  `cups-files.conf` joins the `etc-overrides`, the session file goes to
  `/usr/share/wayland-sessions`, and the passwordless-sudo helper and
  `omarchy-security-functions` ship with `omarchy-settings` together with the
  `%pre`/`%preun`/`%posttrans` scriptlets the helper checks for.
- `omarchy dev pkg-test` builds those specs, read from the `omadora-pkg`
  checkout beside this one, against this checkout (`-dev` variants via
  `dev_suffix`); omadora-pkg's `test/core-packaging-test.sh` builds both
  packages and checks their contents and scriptlets.

## Install order on Fedora

1. `install/fedora/repos.sh` (third-party repos + metadata)
2. `install/omarchy-base.packages` + `install/omarchy-other.packages`
   (`dnf install`, groups `@core`/`@development-tools` cover Arch `base`/`base-devel`)
3. `install/fedora/bootloader.sh` (limine + dracut shim + snapper service)
4. `install/config/*`, `install/hardware/*` (repos step renamed
   `hardware/fedora-repos.sh`, `post-install/pacman.sh` replaced by
   `post-install/dnf.sh`)
5. `omarchy-migrate --baseline` on fresh installs, then per-user setup.

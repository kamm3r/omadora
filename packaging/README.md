# Packaging Omadora for COPR

Omadora ships as two noarch RPMs built from this repository:

- `omarchy-settings` (`packaging/rpm/omarchy-settings/omarchy-settings.spec`): everything that must exist before the runtime and before the first user: `/etc` drop-ins, the `/etc/skel` defaults, package-owned files under `/usr`, fonts, the Plymouth and SDDM themes, branding, and the passwordless-sudo helper with its expiry support and scriptlets.
- `omarchy` (`packaging/rpm/omarchy/omarchy.spec`): every command in `/usr/bin` (linked back from `/usr/share/omarchy/bin`), the install and migration scripts, themes, the Quickshell desktop, and `omadora-sync`. It requires the `omarchy-settings` built from the same commit.

`docs/file-layout.md` maps every repository path to its package and installed location. Both specs also build `-dev` variants (`--define "dev_suffix -dev"`) that provide and replace the release packages, which is what `omarchy dev pkg-test` installs.

## Versions

The version comes from `version`, with a pre-release suffix turned into RPM's tilde so it sorts before the release: `4.0.0.alpha` becomes `4.0.0~alpha`. COPR builds get the release `0.<commit count>.git<short sha>`, so every push sorts after the one before. `.copr/Makefile` writes both into the spec it packs, because COPR rebuilds the source RPM without this checkout.

## Setting up the COPR (once)

1. Create a Fedora account at https://accounts.fedoraproject.org and log in to https://copr.fedorainfracloud.org with it.
2. Install the client and save your API token: `sudo dnf install copr-cli`, then copy the token from https://copr.fedorainfracloud.org/api/ into `~/.config/copr`.
3. Create the project. The packages are noarch and need nothing beyond Fedora to build:

   ```bash
   copr-cli create omadora --chroot fedora-44-x86_64 \
     --description "Omadora: an Omarchy Hyprland desktop for Fedora"
   ```

4. Add both packages as SCM sources using the make-srpm method. Replace the clone URL with your repository; the specs' `URL:` field assumes `https://github.com/kamm3r/omadora`, so change that too if it differs.

   ```bash
   for pkg in omarchy-settings omarchy; do
     copr-cli add-package-scm omadora --name "$pkg" \
       --clone-url https://github.com/kamm3r/omadora.git --commit main \
       --method make_srpm --spec "packaging/rpm/$pkg/$pkg.spec" \
       --webhook-rebuild on
   done
   ```

5. Build them once: `copr-cli build-package omadora --name omarchy-settings` and then the same for `omarchy`.
6. Rebuild on every push: in the COPR project open Settings → Integrations, copy the GitHub webhook URL, and add it under the GitHub repository's Settings → Webhooks (content type `application/json`, push events). Each push then rebuilds both packages from the same commit, so their versions stay in step.

Adding `fedora-45-x86_64` (or `fedora-rawhide-x86_64`) to the project later is `copr-cli edit-chroot` or the project settings page; nothing in the specs is release-specific.

## Installing from the COPR

```bash
sudo dnf copr enable kamm3r/omadora
sudo dnf install omarchy
```

The runtime still expects the third-party repositories `install/fedora/repos.sh` sets up (Terra, RPM Fusion, the Hyprland and Quickshell sources).

On a machine that runs Omadora from a checkout, run `omarchy dev link <checkout>` before installing the packages. The packages add a system-wide environment bootstrap (`/etc/profile.d/omarchy.sh`, `/usr/share/uwsm/env.d/10-omarchy`) that sets `OMARCHY_PATH` to `/usr/share/omarchy` unless `/etc/omarchy.conf`, which `omarchy dev link` writes, points it at a checkout; an `OMARCHY_PATH` set by hand in `~/.bashrc` or `~/.config/uwsm/env.d/` would otherwise compete with it. With the link in place the checkout stays in charge, and the packages add what a checkout cannot provide: the `/etc` drop-ins, the boot cleanup rule, and the packaged passwordless-sudo helper.

## Checking a change before pushing

```bash
# Build and install the -dev packages from your checkout.
omarchy dev pkg-test

# Only build, as COPR will: a source RPM, then binary RPMs from it.
make -f .copr/Makefile srpm outdir=/tmp/srpm spec=packaging/rpm/omarchy/omarchy.spec
rpmbuild --rebuild --define "_topdir /tmp/rpmbuild" /tmp/srpm/*.src.rpm

# Lint; the filters list the findings that are deliberate.
rpmlint -r packaging/rpm/omadora.rpmlintrc /tmp/rpmbuild/RPMS/noarch/*.rpm

# The packaging regression test.
bash test/shell.d/rpm-packaging-test.sh
```

`make srpm` archives the committed `HEAD`, so commit first. For a build in a clean Fedora root like COPR's, add yourself to the `mock` group and run `mock -r fedora-44-x86_64 --rebuild /tmp/srpm/*.src.rpm`.

## Adding files

A new file under `etc/`, `config/`, `default/`, or `bin/` is picked up by the spec's `%install` rules; if it lands somewhere `%files` does not cover, the build fails with "Installed (but unpackaged)". A file under `etc/` that another Fedora package owns belongs in the settings spec's `etc_overrides` list instead, and a command that must exist before the runtime (or runs as root unattended) belongs in `settings_commands` in both specs.

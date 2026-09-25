# Other Packages

Fedora has an enormous wealth of packages available between the official repositories and the third-party COPR, RPM Fusion, and Terra repositories Omadora enables.

It couldn't be easier to use either. You install a new Fedora package by going to _Install > Package_ in the Omarchy menu (`Super + Space`) and typing the package you want. It'll automatically fuzzy filter the list of all packages. (You can also do it manually using `omarchy pkg add [package]` in the terminal).

You can do the same with Flathub, just use _Install > Flatpak_. Just remember that Flathub isn't vetted by the Fedora team. It's like RubyGems or npm. Anyone can upload. Flatpak installs are always per-user, never system-wide.

If you want to remove a package, you can use _Remove > Package_ from the Omarchy menu. It'll remove package, config files, and dependencies. (You can also do it manually using `omarchy pkg drop [package]`).

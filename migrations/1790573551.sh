echo "Install the xkbcli, Plymouth script plugin, and script(1) packages that Fedora splits out"

# Arch's libxkbcommon, plymouth, and util-linux carry xkbcli, the script theme
# plugin, and script(1). Fedora ships them separately: the keyboard layout
# widget and keybindings menu call xkbcli, the Omarchy boot theme is a script
# theme, and omarchy update records its transcript through script(1). An
# install without script(1) cannot start omarchy update at all, so this reaches
# it through the login migration notifier instead.
omarchy-pkg-add libxkbcommon-utils plymouth-plugin-script util-linux-script

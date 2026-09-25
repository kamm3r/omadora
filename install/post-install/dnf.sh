# Refresh dnf metadata after package installation completes so the installed
# system starts from current repo state.

# Wait for CUPS to own the file, the way omarchy-settings does, so a later
# reinstall does not leave a stale override behind.
if [[ -f $OMARCHY_PATH/etc-overrides/cups-cups-files.conf && -f /etc/cups/cups-files.conf ]]; then
  install -m 0640 -o root -g cups "$OMARCHY_PATH/etc-overrides/cups-cups-files.conf" /etc/cups/cups-files.conf
  rm -f /etc/cups/cups-files.conf.rpmnew /etc/cups/cups-files.conf.pacnew
fi

source "$OMARCHY_INSTALL/hardware/fedora-repos.sh"

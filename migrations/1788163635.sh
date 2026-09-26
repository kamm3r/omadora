echo "Remove legacy temporary passwordless sudo grants"

# Omadora ships no RPM yet, so most installs lack the packaged helper. This
# one-shot repair then runs the checkout's copy under the user's own
# authenticated sudo, the trust omarchy-dev-link already extends to it. Only
# unattended root work, such as the expiry timer, is confined to /usr/bin.
if [[ -f /usr/bin/omarchy-sudo-passwordless && -x /usr/bin/omarchy-sudo-passwordless ]]; then
  helper=/usr/bin/omarchy-sudo-passwordless
else
  helper="$OMARCHY_PATH/bin/omarchy-sudo-passwordless"
fi

# Migration queues are per-user; the privileged repair is once per machine.
if ! "$helper" __migration-complete; then
  sudo "$helper" __migrate
fi

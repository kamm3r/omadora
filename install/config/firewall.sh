# Firewalld is Fedora's default firewall; the stock public zone already drops
# unsolicited incoming traffic and allows everything out, which is the
# "allow nothing in, everything out" posture the Arch install expressed with
# `ufw default deny incoming`.

# Allow ports for LocalSend.
firewall-cmd --permanent --add-port=53317/tcp --add-port=53317/udp >/dev/null

# Docker manages its own iptables/nftables rules for container traffic,
# including container DNS on the docker0 bridge, so no extra rules are needed
# for containers to reach the host resolver. (The Arch install punched
# explicit UFW holes for this; firewalld leaves Docker's own chains alone.)

# Installs are followed by reboot, so enable the firewall for the installed
# system instead of mutating the live session mid-install.
systemctl enable firewalld.service

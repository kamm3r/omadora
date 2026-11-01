# Firewall

Omadora follows official Omarchy's UFW configuration. Fedora supplies `ufw`; `ufw-docker` is built from its pinned upstream source in the sibling omadora-pkg repository. Firewalld may remain installed for other desktop tools, but only UFW should run or start at boot.

Fresh installation sources `install/config/firewall.sh`: incoming traffic is denied, outgoing traffic allowed, LocalSend uses TCP/UDP 53317, and Docker bridge DNS is allowed. The ufw-docker helper installs DOCKER-USER forwarding protections. Setup writes target configuration and enables UFW for the next boot; it does not activate a firewall in the live installer's kernel.

SSH setup adds a rate-limited port 22 rule. Sunshine setup opens its streaming ports only to private LANs and the Tailscale interface, following upstream. Removal commands delete their standard UFW rules.

## Switching an existing computer

A package update does not automatically translate firewalld policy or switch firewall managers. Back up `/etc/firewalld`, `/etc/ufw`, `/var/lib/ufw`, `/etc/default/ufw`, and the current IPv4/IPv6 rules first. Review custom zones, services, rich rules, direct rules, and NetworkManager zone assignments, then translate the required policy to UFW. Keep the backup until incoming access, Docker, and any sharing services have been checked.

Install `ufw` and `ufw-docker`, preserve existing UFW rules, configure the defaults and application ports, and run `ufw-docker install`. Authorize SSH before enabling the firewall if SSH is in use. Disable firewalld at boot, enable UFW, and restart `ufw.service` after installing or changing the Docker block (an already-enabled `ufw --force enable` does not necessarily reload those chains); verify `ufw status verbose`, `systemctl is-enabled ufw`, and `systemctl is-active ufw`. Check the DOCKER-USER chain for the ufw-user-forward jump and test any published container services. Explicit UFW route rules are needed for container ports that should be reachable outside trusted networks.

The setup leaf is intended for fresh installation. Source it on an existing system only after reviewing its policy and backing up custom configuration. A live switch can change access to services immediately.

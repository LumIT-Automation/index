The iptables.sh script can be useful to obtain an host firewall configuration. The script use the mangle table because the conman process launched by podman load some iptables rules dynamically and can conflicts with a normal iptables script using the nat or the filter tables. So this script is think up to work externally from these tables.
The script allow ssh connections to the host and http/https to the automation tool.
The two service files for debian and redhat8 are configured to exec iptables.sh as one of the last services of the host system, when podman is already started. In order to activate the service just copy the right service file in /etc/systemd/system and enable it:
        systemctl enable /etc/systemd/system/iptables.service



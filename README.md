# oVPN IPtables Anti-Leak v0.0.8

Blocks everything except connections to VPN Server-IPs with matching port and protocol only.

## SETUP Instructions:

Fire up a terminal and enter these lines:

    # if you're not root, you will need to open a root shell:
    'sudo -s' or 'su'
    wget https://github.com/ovpn-to/oVPN.to-IPtables-Anti-Leak/raw/master/iptables.sh -O /root/iptables.sh
    chmod +x /root/iptables.sh
    exit
Now to activate the script run `sudo /root/iptables.sh`, to deactivate it run `sudo /root/iptables.sh unload`.

## Configuration
    You can enable connections to your local network, but this could make DNS leaks possible!
    Set `ALLOWLAN` to 1 at the top of `/root/iptables.sh` to enable all traffic to 192.168.0.0/16.

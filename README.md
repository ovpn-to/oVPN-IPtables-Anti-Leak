oVPN-IPtables-Anti-Leak
=======================

Blocks everything, except connections to VPN Server-IPs with matching port and protocol only.

SETUP Instructions:

Fire up a terminal and enter those lines

as "root":
- :~$ wget https://github.com/ovpn-to/oVPN.to-IPtables-Anti-Leak/raw/master/iptables.sh -O /root/iptables.sh
- :~$ chmod +x /root/iptables.sh
- :~$ sh /root/iptables.sh
- :~$ sh /root/iptables.sh unload

as user with "sudo":
- :~$ sudo wget https://github.com/ovpn-to/oVPN.to-IPtables-Anti-Leak/raw/master/iptables.sh -O /root/iptables.sh
- :~$ sudo chmod +x /root/iptables.sh
- :~$ sudo sh /root/iptables.sh
- :~$ sudo sh /root/iptables.sh unload

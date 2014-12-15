# IPTABLES BLOCK SCRIPT v0.0.2
#!/bin/bash

EXTIF="eth0";
TUNIF="tun0";
OVPNDIR="/etc/openvpn";
LANRANGE="192.168.0.0/16"
ALLOWLAN="0";
IPTABLES="/sbin/iptables";

# SETUP: chmod +x iptables.sh 
# START: ./iptables.sh
# UNLOAD: ./iptables.sh unload

##############################

if [ "$1" = "unload" ]; then
$IPTABLES -F
$IPTABLES -Z
$IPTABLES -P INPUT ACCEPT
$IPTABLES -P FORWARD ACCEPT
$IPTABLES -P OUTPUT ACCEPT
echo "Rules unloaded" && exit 0;
fi;

# Flush iptables
$IPTABLES -F
# Zero all packets and counters.
$IPTABLES -Z
# Set POLICY DROP
$IPTABLES -P INPUT DROP
$IPTABLES -P FORWARD DROP
$IPTABLES -P OUTPUT DROP

# Allow related connections
$IPTABLES -A INPUT -i $EXTIF -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A INPUT -i $TUNIF -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -o $EXTIF -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback interface to do anything
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT

if [ $ALLOWLAN -eq "1" ]; then
# Allow LAN access
$IPTABLES -A INPUT -i $EXTIF -s $LANRANGE -d $LANRANGE -j ACCEPT 
$IPTABLES -A OUTPUT -o $EXTIF -s $LANRANGE -d $LANRANGE -j ACCEPT
fi;

# Allow OUT over tunIF
$IPTABLES -A OUTPUT -o $TUNIF -p tcp -j ACCEPT;
$IPTABLES -A OUTPUT -o $TUNIF -p udp -j ACCEPT;
$IPTABLES -A OUTPUT -o $TUNIF -p icmp -j ACCEPT;

# ALLOW OUTPUT to oVPN-IPs over $EXTIF at VPN-Port with PROTO
LIST=`grep -E "proto|remote\ " $OVPNDIR/*.ovpn $OVPNDIR/*.conf|cut -d" " -f2,3|tr ' ' ':'`;
I="1";
for LINE in $LIST; do
if [ $I -eq "3" ]; then 
	DATA="$IP $PR"; 
	IPDATA=`echo $IP | cut -d":" -f1`;
	IPPORT=`echo $IP | cut -d":" -f2`;
	PROTO=$PR;
	$IPTABLES -A OUTPUT -o $EXTIF -d $IPDATA -p $PROTO --dport $IPPORT -j ACCEPT;
	I=1; L=$(expr $L + 1); 
fi;
if [ $I -eq "1" ]; then IP=$LINE; fi;
if [ $I -eq "2" ]; then PR=$LINE; fi;
I=$(expr $I + 1);
done;
if [ $L -gt "0" ]; then
	echo "LOADED $L IPs TO TRUSTED IP-POOL";
else
	echo "ERROR: COULD NOT LOAD IPs FROM CONFIGS. UNLOADING RULES";
	$IPTABLES -F;
	$IPTABLES -P INPUT ACCEPT;
	$IPTABLES -P OUTPUT ACCEPT;
	$IPTABLES -P FORWARD ACCEPT;
	exit 1
fi;


# STATUS
$IPTABLES -nvL

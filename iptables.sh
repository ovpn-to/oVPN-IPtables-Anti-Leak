#!/bin/bash
#
# oVPN.to IPtables Anti-Leak Script v0.0.9
#
# Setup Instructions and ReadMe here: https://github.com/ovpn-to/oVPN.to-IPtables-Anti-Leak

EXTIF="wlan0 p4p1 eth0";
TUNIF="tun0";
OVPNDIR="/etc/openvpn";
LANRANGE="192.168.0.0/16"
ALLOWLAN="0";
ALLOW_LAN_TCP_PORTS="8888 9999"
ALLOW_LAN_UDP_PORTS=""
IP4TABLES="/sbin/iptables";
IP6TABLES="/sbin/ip6tables";

IP4TABSSAVE="/sbin/iptables-save";
IP4TRESTORE="/sbin/iptables-restore";
IP4FILESAVE="/root/save.ip4tables.txt";

IP6TABSSAVE="/sbin/ip6tables-save";
IP6TRESTORE="/sbin/ip6tables-restore";
IP6FILESAVE="/root/save.ip6tables.txt";

DEBUGOUTPUT="0";

##############################

# Check if we're root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (e.g. sudo $0)";
   exit 1;
fi;

#Doing Backup from existing IPtables
$IP4TABSSAVE > $IP4FILESAVE && echo "Backuped ip4tables to $IP4FILESAVE";
$IP6TABSSAVE > $IP6FILESAVE && echo "Backuped ip6tables to $IP6FILESAVE";

if [ "$1" = "unload" ]; then
$IP4TABLES -F
$IP4TABLES -Z
$IP4TABLES -P INPUT ACCEPT
$IP4TABLES -P FORWARD ACCEPT
$IP4TABLES -P OUTPUT ACCEPT
$IP6TABLES -F
$IP6TABLES -Z
$IP6TABLES -P INPUT ACCEPT
$IP6TABLES -P FORWARD ACCEPT
$IP6TABLES -P OUTPUT ACCEPT
echo "Rules unloaded" && exit 0;
fi;

# Select external Interface if defined multiple EXTIF="wlan0 p4p1 eth0";
if [ `echo $EXTIF |wc -w` -gt 1 ]; then
   echo -n "Multiple external Interfaces found, try: ";
    for IF in $EXTIF; do
      echo -n " $IF ";
      ifconfig $IF >/dev/null 2>/dev/null && EXT=$IF && break;
      echo -n "(down),";
    done;
    if [ ! -z $EXT ]; then
       EXTIF=$EXT;
       echo -e "\nUsing $EXTIF as external Interface";
       sleep 3;
    else
       echo -e "\nCould not find Interface, trying from route"
       EXT=`route -n |tr -s ' ' | awk '$3=="0.0.0.0" { print $0 }' | cut -d" " -f8`;
       if [ `echo $EXT |wc -w` -eq 1 ]; then
          EXTIF=$EXT;
          echo "Using $EXTIF as external Interface";
       else
          echo "Error: Could not detect any external Interface";
          exit 1;
       fi;
    fi;
fi;

# Flush iptables
$IP4TABLES -F
$IP6TABLES -F
# Zero all packets and counters.
$IP4TABLES -Z
$IP6TABLES -Z
# Set POLICY DROP
$IP4TABLES -P INPUT DROP
$IP4TABLES -P FORWARD DROP
$IP4TABLES -P OUTPUT DROP
$IP6TABLES -P INPUT DROP
$IP6TABLES -P FORWARD DROP
$IP6TABLES -P OUTPUT DROP

# Allow related connections
$IP4TABLES -A INPUT -i $EXTIF -m state --state ESTABLISHED,RELATED -j ACCEPT
$IP4TABLES -A INPUT -i $TUNIF -m state --state ESTABLISHED,RELATED -j ACCEPT
$IP4TABLES -A OUTPUT -o $EXTIF -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow loopback interface to do anything
$IP4TABLES -A INPUT -i lo -j ACCEPT
$IP4TABLES -A OUTPUT -o lo -j ACCEPT

if [ $ALLOWLAN -eq "1" ]; then
# Allow LAN access
$IP4TABLES -A INPUT -i $EXTIF -s $LANRANGE -j ACCEPT 
$IP4TABLES -A OUTPUT -o $EXTIF -d $LANRANGE -j ACCEPT
fi;

# Allow OUT over tunIF
$IP4TABLES -A OUTPUT -o $TUNIF -p tcp -j ACCEPT;
$IP4TABLES -A OUTPUT -o $TUNIF -p udp -j ACCEPT;
$IP4TABLES -A OUTPUT -o $TUNIF -p icmp -j ACCEPT;

# ALLOW OUTPUT to oVPN-IPs over $EXTIF at VPN-Port with PROTO

OVPNCONFIGS=`ls $OVPNDIR/*.ovpn $OVPNDIR/*.conf`;
test $DEBUGOUTPUT -eq "1" && echo -e "DEBUG OVPNCONFIGS=\n$OVPNCONFIGS";

L=0;
while read CONFIGFILE; do 
 test $DEBUGOUTPUT -eq "1" && echo "$CONFIGFILE";
 REMOTE=`grep "remote\ " "$CONFIGFILE"`;
 test $DEBUGOUTPUT -eq "1" && echo "$REMOTE";
 getPROTO=`echo $REMOTE|cut -d" " -f4`;
 IPDATA=`echo $REMOTE|cut -d" " -f2`;
 IPPORT=`echo $REMOTE|cut -d" " -f3`;
 test $DEBUGOUTPUT -eq "1" && echo "DEBUG: wc -m `echo $getPROTO | wc -m`";
 if [ `echo $getPROTO | wc -m` -eq "4" ]&&([ $getPROTO = "udp" ]||[ $getPROTO = "tcp" ]||[ $getPROTO = "UDP" ]||[ $getPROTO = "TCP" ]); then
  PROTO=$getPROTO;
 else
  PROTO=`grep "proto\ " "$CONFIGFILE" | cut -d" " -f2`;
 fi;
 test $DEBUGOUTPUT -eq "1" && echo "$IPDATA $IPPORT $PROTO";
 $IP4TABLES -A OUTPUT -o $EXTIF -d $IPDATA -p $PROTO --dport $IPPORT -j ACCEPT;
 L=$(expr $L + 1);
done < <(echo "$OVPNCONFIGS");

if [ $L -gt "0" ]; then
 echo "LOADED $L IPs TO TRUSTED IP-POOL";
else
 echo "ERROR: COULD NOT LOAD IPs FROM CONFIGS. RESTORING FROM BACKUP";
 $IP4TRESTORE $IP4TABSSAVE && echo "FAILED: reloaded from backup: $IP4FILESAVE";
 $IP6TRESTORE $IP6TABSSAVE && echo "FAILED: reloaded from backup: $IP6FILESAVE";
 exit 1
fi;

for PORT in $ALLOW_LAN_TCP_PORTS; do
 $IP4TABLES -A INPUT -i $EXTIF -p tcp --dport $PORT -j ACCEPT;
 $IP6TABLES -A INPUT -i $EXTIF -p tcp --dport $PORT -j ACCEPT;
done

for PORT in $ALLOW_LAN_UDP_PORTS; do
 $IP4TABLES -A INPUT -i $EXTIF -p udp --dport $PORT -j ACCEPT;
 $IP6TABLES -A INPUT -i $EXTIF -p udp --dport $PORT -j ACCEPT;
done

# STATUS
$IP4TABLES -nvL
$IP6TABLES -nvL

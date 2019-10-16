#!/bin/bash

set -e

################################################################################
# Debian Version check
################################################################################

SUPPORTED_VERSION="10"

if [ -e /etc/debian_version ]
then
    DEBIAN_MAIN_VERSION=$(cat /etc/debian_version | cut -d "." -f 1)
    if [ "$DEBIAN_MAIN_VERSION" != "$SUPPORTED_VERSION" ]
    then
	echo "Only Debian $SUPPORTED_VERSION supported: apparently debian $DEBIAN_MAIN_VERSION"
	exit 1
    fi
else
    echo "Only Debian 9 is supported: apparently not a debian"
    exit 1
fi


if [[ $EUID -ne 0 ]]
then
    echo "This script must be run as root"
    exit 1
fi


################################################################################
# install packages for this script
################################################################################

apt install -y dialog sudo


################################################################################
# sudo configuration
################################################################################

DIALOGOUT=/tmp/dialogs.$$
function dialog_result() {
    cat $DIALOGOUT
    rm $DIALOGOUT
    touch $DIALOGOUT
}
function finish {
    rm $DIALOGOUT
}
trap finish EXIT

dialog --title "Sudo configuration" --inputbox "Please enter a comma separated list of uses to add to sudo group" 10 60 2>$DIALOGOUT

to_add=$(dialog_result | cut -d "," -f 1- --output-delimiter "
")

for a in $to_add
do
    addgroup $a sudo
done

################################################################################
#
################################################################################

ifs=""
ifs_menu=""
n_ifs=0
for if in $(ls /sys/class/net)
do
    if [ $if == "lo" ]
    then
	continue
    fi
    inets=$(ip addr show $if | grep inet | cut -d " " -f 6 | tr '\n' '|' )
    if [ "$inets" == "" ]
    then
	inets="<disconnected>"
    fi
    ifs="$ifs $if"
    ifs_menu="$ifs_menu $if $inets OFF"
    n_ifs=$((n_ifs+1))
done

if [[ $n_ifs -lt 2 ]]
then
    echo "System requires at least 2 interfaces"
    exit 1
fi

dialog --title "Gateway Configuration - WAN interface" --radiolist "Please select the interface to share accross local network" 10 60 $n_ifs $ifs_menu 2>$DIALOGOUT


wan_interface=$(dialog_result)
rifs=""
ifs_menu=""
n_ifs=0
for if in $ifs
do
    if [ "$if" == "$wan_interface" ]
    then
	continue
    fi
    inets=$(ip addr show $if | grep inet | cut -d " " -f 6 | tr '\n' '|' )
    if [ "$inets" == "" ]
    then
	inets="<disconnected>"
    fi
    rifs="$rifs $if"
    ifs_menu="$ifs_menu $if $inets OFF"
    n_ifs=$((n_ifs+1))
done

lan_interface=""
if [[ $n_ifs == 1 ]]
then
    lan_interface=$rifs
else
    dialog --title "Gateway Configuration - LAN interface" --radiolist "Please select the interface connected to the Local networf" 10 60 $n_ifs $ifs_menu 2>$DIALOGOUT
    lan_interface=$(dialog_result)
fi

cp /etc/network/interfaces /etc/network/interfaces.backup.$$

echo "
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

allow-hotplug $wan_interface
auto $wan_interface
iface $wan_interface inet dhcp

allow-hotplug $lan_interface
auto $lan_interface
iface $lan_interface inet static
	address 192.168.42.1
	netmask 255.255.255.0
" > /etc/network/interfaces

ip link set $lan_interface up

sed -i.backup 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

echo 1 > /proc/sys/net/ipv4/ip_forward

sudo apt install -y iptables-persistent isc-dhcp-server

iptables --table nat --append POSTROUTING --out-interface $wan_interface -j MASQUERADE
iptables --append FORWARD --in-interface $lan_interface --out-interface $wan_interface -j ACCEPT
iptables --append FORWARD --in-interface $wan_interface --out-interface $lan_interface -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables-save > /etc/iptables/rules.v4

upstream_dns=$(cat /var/lib/dhcp/dhclient.$wan_interface.leases |  grep domain-name-servers | cut -d " " -f 5 | uniq | tr -d ';' )


dialog --title "DNS Configuration" --inputbox "Please enter a comma separated list of DNS server to use" 10 60 $upstream_dns 2>$DIALOGOUT

dns_servers=$(dialog_result | sed 's/,/, /g')

cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.back.$$


echo "option domain-name \"lan\";
option domain-name-servers $dns_servers;

default-lease-time 86400;
max-lease-time 172800;

ddns-update-style none;

authoritative;


subnet 192.168.42.0 netmask 255.255.255.0 {
    range 192.168.42.100 192.168.42.200;
    option routers 192.168.42.1;
}
" > /etc/dhcp/dhcpd.conf

cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.backup.$$

echo "INTERFACESv4=\"$lan_interface\"
" >> /etc/default/isc-dhcp-server

sudo service isc-dhcp-server restart

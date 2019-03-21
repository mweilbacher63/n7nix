#!/bin/bash
#
# Install a host access point
#
# hosts, resolv.conf /etc/network/interfaces /etc/dhcpcd.conf
DEBUG=1

scriptname="`basename $0`"
UDR_INSTALL_LOGFILE="/var/log/udr_install.log"
SSID="NOT_SET"

# Required pacakges
PKGLIST="hostapd dnsmasq iptables iptables-persistent"
SERVICELIST="hostapd dnsmasq"

function dbgecho { if [ ! -z "$DEBUG" ] ; then echo "$*"; fi }

# ===== function is_pkg_installed

function is_pkg_installed() {

return $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed" >/dev/null 2>&1)
}

# ===== function determine if RPi version has WiFi

function get_has_WiFi() {
# Initialize product ID
HAS_WIFI=
prgram="piver.sh"
which $prgram
if [ "$?" -eq 0 ] ; then
   dbgecho "Found $prgram in path"
   $prgram > /dev/null 2>&1
   HAS_WIFI=$?
else
   currentdir=$(pwd)
   # Get path one level down
   pathdn1=$( echo ${currentdir%/*})
   dbgecho "Test pwd: $currentdir, path: $pathdn1"
   if [ -e "$pathdn1/bin/$prgram" ] ; then
       dbgecho "Found $prgram here: $pathdn1/bin"
       $pathdn1/bin/$prgram > /dev/null 2>&1
       HAS_WIFI=$?
   else
       echo "Could not locate $prgram default to no WiFi found"
       HAS_WIFI=0
   fi
fi
}


# ===== main

echo "Install hostap on an RPi 3"

# Be sure we're running as root
if [[ $EUID != 0 ]] ; then
   echo "Must be root."
   exit 1
fi

get_has_WiFi
if [ $? -ne "0" ] ; then
   echo "No WiFi found ... exiting"
   exit 1
fi

echo "Found WiFi"

# check if packages are installed
dbgecho "Check packages: $PKGLIST"

# Fix for iptables-persistent broken
#  https://discourse.osmc.tv/t/failed-to-start-load-kernel-modules/3163/14
#  https://www.raspberrypi.org/forums/viewtopic.php?f=63&t=174648

sed -i -e 's/^#*/#/' /etc/modules-load.d/cups-filters.conf

for pkg_name in `echo ${PKGLIST}` ; do

   is_pkg_installed $pkg_name
   if [ $? -ne 0 ] ; then
      echo "$scriptname: Need to Install $pkg_name program"
      apt-get -qy install $pkg_name
   fi
done

echo "$(date "+%Y %m %d %T %Z"): $scriptname: hostap install script FINISHED" >> $UDR_INSTALL_LOGFILE
echo
echo "hostap install FINISHED"
echo

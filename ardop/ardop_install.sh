#!/bin/bash
#
# Download the ardop suite of programs to /usr/local/src
# ardop programs include:
#  piARDOP_GUI
#  piardop2
#  piardopc
# Also download arim (Amateur Radio Instant Messaging) for
# verification
#
# Uncomment this statement for debug echos
# DEBUG=1

force_update=false
scriptname="`basename $0`"
user=$(whoami)
UDR_INSTALL_LOGFILE="/var/log/udr_install.log"

SRC_DIR="/usr/local/src/"
BUILD_PKG_REQUIRE="build-essential ncurses-dev zlib1g-dev"

function dbgecho { if [ ! -z "$DEBUG" ] ; then echo "$*"; fi }

# ===== function is_pkg_installed

function is_pkg_installed() {

return $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c "ok installed" >/dev/null 2>&1)
}

# ===== function get_user

function get_user() {
   # Check if there is only a single user on this system
   if (( `ls /home | wc -l` == 1 )) ; then
      USER=$(ls /home)
   else
      echo "Enter user name ($(echo $USERLIST | tr '\n' ' ')), followed by [enter]:"
      read -e USER
   fi
}

# ==== function check_user
# verify user name is legit

function check_user() {
   userok=false
   dbgecho "$scriptname: Verify user name: $USER"
   for username in $USERLIST ; do
      if [ "$USER" = "$username" ] ; then
         userok=true;
      fi
   done

   if [ "$userok" = "false" ] ; then
      echo "User name ($USER) does not exist,  must be one of: $USERLIST"
      exit 1
   fi

   dbgecho "using USER: $USER"
}

# ===== function get_user_name
function get_user_name() {

    # Get list of users with home directories
    USERLIST="$(ls /home)"
    USERLIST="$(echo $USERLIST | tr '\n' ' ')"

    # Check if user name was supplied on command line
    if [ -z "$USER" ] ; then
        # prompt for call sign & user name
        # Check if there is only a single user on this system
        get_user
    fi
    # Verify user name
    check_user
}

# ==== function wiseman_download
function wiseman_download() {
if [ ! -e "$download_filename" ] || $force_update ; then

    if [ -e "$download_filename" ] ; then
        echo "Deleting $(stat -c "%y %s %n" $download_filename)"
        rm $download_filename
    fi

    wget http://www.cantab.net/users/john.wiseman/Downloads/Beta/$download_filename
    if [ $? -ne 0 ] ; then
        echo -e "\n$(tput setaf 1)FAILED to download file: $download_filename$(tput setaf 7)\n"
    else
        echo -e "\n$(tput setaf 1)Successfully downloaded: $download_filename $(tput setaf 7)\n"
        # Make executable
        chmod +x $download_filename
    fi
else
    val=$(stat -c "%y %s %n" $download_filename)

    val2=$(echo $val | tr ' ' '\n' | tail -2 | xargs -n2)
    val=${val%.*}
    echo "Using existing file: $val $val2"
fi
}

# ===== main

echo -e "\n\t$(tput setaf 4) Install ardop$(tput setaf 7)\n"

# Check for any arguments
if (( $# != 0 )) ; then
   USER="$1"
fi

get_user_name

BIN_DIR="/home/$USER/bin"
cd $BIN_DIR

# Note:
#   piardopc is version 1 of the ardop TNC
#   piardop2 is version 2 of the ardop TNC

PROGLIST="piARDOP_GUI piardop2 piardopc"
for prog_name in `echo ${PROGLIST}` ; do
    download_filename="$prog_name"
    wiseman_download
done

# Set up virtual sound device ARDOP
mod_file="/home/$USER/.asoundrc"
grep -i "pcm.ARDOP" $mod_file > /dev/null 2>&1
if [ $? -ne 0 ] ; then
    # Add to bottom of file
    cat << EOT >> $mod_file

pcm.ARDOP {
        type rate
        slave {
        pcm "hw:1,0"
        rate 12000
        }
}
EOT
else
    echo -e "\n\t$(tput setaf 4)File: $mod_file NOT modified $(tput setaf 7)\n"
fi

# check if build packages are installed
dbgecho "Check build packages: $BUILD_PKG_REQUIRE"
needs_pkg=false

for pkg_name in `echo ${BUILD_PKG_REQUIRE}` ; do

   is_pkg_installed $pkg_name
   if [ $? -ne 0 ] ; then
      echo "$scriptname: Will Install $pkg_name package"
      needs_pkg=true
      break
   fi
done

if [ "$needs_pkg" = "true" ] ; then
   echo
   echo -e "=== Installing build tools"

   apt-get install -y -q $BUILD_PKG_REQUIRE
   if [ "$?" -ne 0 ] ; then
      echo "Build tool install failed. Please try this command manually:"
      echo "apt-get -y $BUILD_PKG_REQUIRE"
      exit 1
   fi
fi

arim_ver="2.7"
download_filename="arim-${arim_ver}.tar.gz"
ARIM_SRC_DIR=$SRC_DIR/arim-$arim_ver

# Should check if there is a previous installation

if [ ! -d "$ARIM_SRC_DIR" ] ; then
    cd "$SRC_DIR"
    sudo chown $USER:$USER .

    sudo wget https://www.whitemesa.net/arim/src/$download_filename
        if [ $? -ne 0 ] ; then
            echo "$(tput setaf 1)FAILED to download file: $download_filename $(tput setaf 7)"
        else
            sudo tar xzvf $download_filename
            if [ $? -ne 0 ] ; then
                echo "$(tput setaf 1)FAILED to untar file: $download_filname $(tput setaf 7)"
            else
                sudo chown -R $USER:$USER $ARIM_SRC_DIR
                cd $ARIM_SRC_DIR
                ./configure
                echo -e "\n$(tput setaf 4)Starting arim build $(tput setaf 7)\n"
                make
                echo -e "\n$(tput setaf 4)Starting arim install $(tput setaf 7)\n"
                sudo make install
            fi
        fi
else
    echo -e "Using previously built arim-$arim_ver\n"
    echo
fi


echo
echo "$(date "+%Y %m %d %T %Z"): $scriptname: arim & ardop install script FINISHED" | sudo tee -a $UDR_INSTALL_LOGFILE
echo



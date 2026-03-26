#!/usr/bin/env bash

set -e -o pipefail

## default installation folder
INSTALL_DIR=/opt/

###########################################

ALL_TOOLS="catnip"

SYSTEM_DEPS="bash python pip"


###########################################
#
function pinfo {
    echo "[INFO] $*"
}

###########################################
# 

function check_system_deps {
    local bin
    pinfo "Checking dependencies..."
    local MISSING=0
    for bin in $SYSTEM_DEPS; do
        local PATH2BIN=`which $bin 2> /dev/null`
        if [ "$PATH2BIN-" == "-" ]; then
            pinfo " $bin not found!"
            #
            MISSING=1
        else
            pinfo " $bin found: $PATH2BIN"
        fi
    done
    pinfo "Checking dependencies...done."
    if [ $MISSING == 1 ]; then
        pinfo "ERROR: Unable to proceed"
        exit 1
    fi

}

#whereis python
#check_system_deps

###########################################
#
function install_catnip {
    pinfo "Installing catnip..."
    if [ "$INSTALL_DIR-" = "-" ]; then
	pip install .
    else
	#pip install --prefix $INSTALL_DIR .
	PY_VERSION=$(python3 -c "import sys; print(f'python{sys.version_info.major}.{sys.version_info.minor}')")
	# override catnip script
	mkdir -p $INSTALL_DIR/bin
	cat <<EOF > "$INSTALL_DIR/bin/catnip"
#!/usr/bin/env bash
# -*- coding: utf-8 -*-
set -e
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PREFIX="\$(dirname "\$SCRIPT_DIR")"
LIB_PATH="\$PREFIX/lib/$PY_VERSION/site-packages"

if [ -d "\$LIB_PATH" ]; then
    export PYTHONPATH="\$LIB_PATH:\$PYTHONPATH"
fi

exec python3 -m catnip.catnip_cli "\$@"
EOF
    fi
    # pip show catnip
    # whereis catnip
    pinfo "Installing catnip...done."    
}

function usage {
    echo "Usage: install.sh [-i toplevel_folder_to_install_catnip -x soft name -h -H]
Options:
  -h     - print this help information"
}

## by default install all software
MODE=all
DEBUG=0

while getopts "i:x:CThH"  Option
do
    case $Option in
	i ) INSTALL_DIR=$OPTARG;;
	x ) MODE=$OPTARG;;
	h ) usage; exit;;
	H ) usage; exit;;
	* ) usage; exit 1;;
    esac
done

if [ ! -e  $INSTALL_DIR ]; then
    echo "Creating $INSTALL_DIR..."
    mkdir -p $INSTALL_DIR
    echo "Creating $INSTALL_DIR...done."
fi

if [ "x`uname`" == "xLinux" ] ; then
    ## readlink does not work in MacOS
    ## 
    INSTALL_DIR=$(readlink -f $INSTALL_DIR)
fi

TMP_DIR=$(mktemp -d)
mkdir -p $TMP_DIR

if [ "$MODE-" == "all-" ]; then
    for t in $ALL_TOOLS; do
	varn="SKIP_$t"
	case ${!varn} in
	    1 ) echo "skipping installation of $t ";;
	    * ) install_$t
	esac
    done
else
    install_$MODE
fi


echo "---------------------------------------------------"
echo "catnit and dependecies installed on $INSTALL_DIR"
echo "All done."
exit 0

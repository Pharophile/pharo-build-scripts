#!/bin/bash

# stop the script if a single command fails
set -e 

VM_TYPE="nbcog"
VM_BINARY_NAME="NBCog"

# ARHUMENT HANDLING ===========================================================

if { [ "$1" = "-h" ] || [ "$1" = "--help" ]; }; then
    echo "This script will download the latest NativeBoost enabled VM for Pharo

Result in the current directory:
    vm               directory containing the NativeBoost enabled VM
    vm.sh            script forwarding to the VM inside the vm directory running headlessly
    vm-ui.sh         script running the VM interactively with a UI"
    exit 0
elif [ $# -gt 0 ]; then
    echo "--help is the only argument allowed"
    exit 1
fi

# SYSTEM PROPERTIES ===========================================================
if [ -z "$OS" ] ; then
    #try to extract the os name
    TMP_OS=`uname | tr '[:upper:]' '[:lower:]'`
    if [[ "{$TMP_OS}" = *windows* ]]; then
        OS='win'
    elif [[ "{$TMP_OS}" = *darwin* ]]; then
        OS='mac'
    elif [[ "{$TMP_OS}" = *linux* ]]; then
        OS='linux'
    else
        echo "Unsupported OS"
        exit 1
    fi
fi

if [ -z "$ARCHITECTURE" ] ; then
    ARCHITECTURE=32
fi

# DOWNLOAD THE LATEST VM ======================================================
VM_URL="http://files.pharo.org/vm/${VM_TYPE}/${OS}/${VM_TYPE}-${OS}-latest.zip"

wget --progress=bar:force --output-document=vm.zip $VM_URL

unzip -qo -d vm vm.zip
rm -rf vm.zip

if [ "$OS" == "win" ]; then
    PHARO_VM=`find vm -name ${VM_BINARY_NAME}.exe`
else
    PHARO_VM=`find vm -name ${VM_BINARY_NAME}`
fi

echo $PHARO_VM

# DOWNLOAD THE PharoV10.sources ===============================================
SOURCES_URL="http://files.pharo.org/image/PharoV10.sources.zip"
wget --progress=bar:force --output-document=sources.zip $SOURCES_URL
if [ "$OS" = "mac" ]; then
	SOURCES_DIR='vm';
else
	SOURCES_DIR=`dirname $PHARO_VM`;
fi
unzip -qo -d $SOURCES_DIR sources.zip
rm -rf sources.zip

# VM BASH LAUNCHER ============================================================
# create a local executable file which forwads to the found vm ================
create_vm_script() {
	VM_SCRIPT=$1
	
	echo "#!/bin/bash" > $VM_SCRIPT
	echo '# some magic to find out the real location of this script dealing with symlinks
DIR=`readlink "$0"` || DIR="$0";
DIR=`dirname "$DIR"`;
cd "$DIR"
DIR=`pwd`
cd - > /dev/null 
# disable parameter expansion to forward all arguments unprocessed to the VM
set -f
# run the VM and pass along all arguments as is' >> $VM_SCRIPT
	
	# make sure we only substite $PHARO_VM but put '$DIR' in the script
	echo -n \"\$DIR\"/\"$PHARO_VM\" >> $VM_SCRIPT
	
	# only output the headless option if the VM_SCRIPT name doesn't include 'ui'
	if [[ "{$VM_SCRIPT}" != *ui* ]]; then
		# output the headless option, which varies under each platform
		if [ "$OS" == "linux" ]; then
		    echo -n " -vm-display-null " >> $VM_SCRIPT
		else
		    echo -n " -headless" >> $VM_SCRIPT
		fi
	fi
	
	# forward all arguments unprocessed using $@
	echo " \"\$@\"" >> $VM_SCRIPT
	
	# make the script executable
	chmod +x $VM_SCRIPT
}

create_vm_script 'vm.sh'
create_vm_script 'vm-ui.sh'

# test that the script actually runs under linux =============================
if [ "$OS" == "linux" ]; then
	$PHARO_VM -help -vm-display-null 2>&1 > /dev/null || (\
		echo "Please install the 32bit libraries"; \
		echo "   sudo aptitude install ia32-libs" )
fi
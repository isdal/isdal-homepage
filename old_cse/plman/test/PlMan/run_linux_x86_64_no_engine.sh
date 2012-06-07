#!/bin/sh
## config file to use
export CONFIG="pl_manager.conf"

## additional parameters
export PARAMETERS=""

## do not edit below if you don't know what you are doing
#############################################################
export MAIN="edu.washington.cs.pl_if.gui.GuiMain"
export OS_TYPE="linux_x86_64"
export LIB_PATH="./dll/$OS_TYPE"

export C_PATH="PlMan.jar"
export C_PATH="$C_PATH:lib/xmlrpc-common-3.0.jar"
export C_PATH="$C_PATH:lib/xmlrpc-server-3.0.jar"
export C_PATH="$C_PATH:lib/xmlrpc-client-3.0.jar"
export C_PATH="$C_PATH:lib/ws-commons-util-1.0.1.jar"
export C_PATH="$C_PATH:lib/commons-logging-1.1.jar"
export C_PATH="$C_PATH:lib/ganymed-ssh2.jar"
export C_PATH="$C_PATH:lib/com.twmacinta.FastMD5.jar"
export C_PATH="$C_PATH:lib/jface.jar"
export C_PATH="$C_PATH:lib/org.eclipse.equinox.common_3.2.0.v20060603.jar"
export C_PATH="$C_PATH:lib/org.eclipse.core.commands_3.2.0.I20060605-1400.jar"
export C_PATH="$C_PATH:lib/swt-$OS_TYPE.jar"
"

export FLAGS="-Xmx256m -Djava.library.path=$LIB_PATH -classpath $C_PATH"
java $FLAGS $MAIN --config $CONFIG $PARAMETERS
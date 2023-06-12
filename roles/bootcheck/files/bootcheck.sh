#!/bin/bash

NUM_BOOTS=10
HOSTNAME=$(hostname)

function get_boot_logs() {
	/usr/bin/last -Fxn $NUM_BOOTS reboot shutdown
}

function last_shutdown_was_graceful() {
	local BOOT_LOGS=$1
	if [ -z "$BOOT_LOGS" ]
	then
		BOOT_LOGS=$(get_boot_logs)
	fi

	local LAST_BOOT=$(echo "$BOOT_LOGS" | head -n 2 | cut -d " " -f 1 | tr '\n' ' ')
	if [ "$LAST_BOOT" == "reboot shutdown " ]
	then
		return 0
	else
		return 1
	fi
}

function mail_to_admin() {
	local BOOT_LOGS=$1
	if [ -z "$BOOT_LOGS" ]
	then
		BOOT_LOGS=$(get_boot_logs)
	fi
	{
		mail -s "[FORT] Reboot of $HOSTNAME after non-graceful shutdown" admins <<EOF
Hello admins,

A potential non-graceful shutdown was detected on $HOSTNAME.

Here is the output of 'last -Fxn $NUM_BOOTS reboot shutdown':
${BOOT_LOGS}
EOF
    } 1>/dev/null
}

BOOT_LOGS=$(get_boot_logs)
if last_shutdown_was_graceful "$BOOT_LOGS"
then
	echo "last shutdown was graceful, exiting"
	post_to_slack "graceful"
	exit 0
fi

echo "NON-GRACEFUL SHUTDOWN DETECTED"

mail_to_admin "$BOOT_LOGS"

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

function post_to_slack() {
	if [ -z $SLACK_URL ]
	then
		return 0
	fi
	local MESSAGE=":warning: *$HOSTNAME* started after non-graceful shutdown."

	if [ $1 == "graceful" ]
	then
		MESSAGE=":spock-hand: *$HOSTNAME* started."
	fi
	/usr/bin/curl -X POST \
				  -H 'Content-type: application/json' \
				  --data "{\"text\":\"$MESSAGE\"}" \
				  $SLACK_URL 2>/dev/null 1>/dev/null
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
post_to_slack "non-graceful"

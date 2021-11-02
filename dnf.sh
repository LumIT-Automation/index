#!/bin/bash

dnf='/usr/bin/dnf'
echo "$*"

if echo "$*" | grep -Eq '(remove|install|update)\sautomation-interface[a-zA-Z0-9-]+container' || \
    echo "$*" | grep -Eq '(install|update)\s.*automation-interface[a-zA-Z0-9-]+container'; then
    if getenforce | grep -q Enforcing;then
        echo -e "\t\nWarning: \e[32mselinux enabled\e[0m. Disable it temporarily to allow the installation process."
	echo -e "\t(Command: setenforce 0|1 to disable enable|selinux).\n "
        exit 1
    fi
fi

$dnf "$@"



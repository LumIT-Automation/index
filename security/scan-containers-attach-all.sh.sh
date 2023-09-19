#!/bin/bash

script=trivy-scan-attach-all.sh
#fromMail=automation@lumit.it
#dest=networkmanagement@crif.com
fromMail=m.sartori@lumit.it
dest=m.sartori@lumit.it
concertoEnv=prod
mta=127.0.0.1

declare -A outputFiles

[ -r scan-containers.conf ]  && . scan-containers.conf

containerList=$(podman ps --format="{{.Image}}"| sed 's#localhost/##g' | awk -F':' '{print $1}')

export fromMail dest mta concertoEnv


if [ -z "$fromMail" ]; then
    echo "\$fromMail variable undefined"
    exit 1
fi
if [ -z "$dest" ]; then
    echo "\$dest variable undefined"
    exit 1
fi
if [ -z "$mta" ]; then
    echo "\$mta variable undefined"
    exit 1
fi

boundary="_$(echo ${RANDOM}${RANDOM}${RANDOM}${RANDOM}| md5sum | cut -d' ' -f1)"
toDay=$(date '+%Y-%m-%d')

helo="HELO `hostname`"
from="MAIL FROM: <$fromMail>"
rcpt="RCPT TO: <$dest>"
cc="RCPT TO: <$fromMail>"
messageStart="DATA"
messageEnd="QUIT"
messageSubject="Subject: Concerto Automation ($concertoEnv): trivy report"

# Warning: another header is REQUIRED: Message-Id. It can be added here or (for postfix users)
#   set the parameter:  always_add_missing_headers = yes in /etc/postfix/main.cf
#   see https://www.postfix.org/postconf.5.html#always_add_missing_headers


send_mail() {
    local -n files_ref=$1

    sleep 1
    printf "$helo\r\n"
    sleep 0.3

    printf "$from\r\n"
    sleep 0.3

    printf "$rcpt\r\n"
    sleep 0.3

    printf "$cc\r\n"
    sleep 0.3

    printf "$messageStart\r\n"
    sleep 0.3

    printf "$messageSubject\r\n"
    sleep 0.3

    echo "Content-Type: multipart/mixed;
        boundary=\"$boundary\"
MIME-Version: 1.0

--$boundary
Content-Type: multipart/alternative;
        boundary=\"$boundary\"

--$boundary
Content-Type: text/plain; charset=\"utf-8\"
Content-Transfer-Encoding: quoted-printable

Containers: $containerList.

Logs attached.

"
    for c in $containerList; do
        echo "
--$boundary
Content-Type: text/plain; name=\"${toDay}_Concerto_${concertoEnv}_trivy_report_${c}\"
Content-Disposition: attachment; filename=\"${toDay}_Concerto_${concertoEnv}_trivy_report_${c}.txt\";
Content-Transfer-Encoding: base64

        "
        podman exec -e=log=${files_ref[$c]} $c bash -c 'cat $log' | base64
        sleep 0.3
    done

echo "

--${boundary}--
"


    sleep 0.3

    printf ".\r\n"
    sleep 1

    printf "$messageEnd\r\n"
    sleep 0.3
}


for container in $containerList; do
    export container

    podman cp ./${script} ${container}:/root/
    podman exec $container chmod 755 /root/${script}

    ( podman exec -e=container -it $container /root/$script )
    outputFiles[$container]+=/tmp/trivy-${container}-output.log

    podman exec $container rm -f /root/${script}
done

sleep 1

send_mail outputFiles | nc $mta  25

for c in $containerList; do
    export c
    podman exec -e=log=${files_ref[$c]} $c bash -c 'rm -f $log'
done


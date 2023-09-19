#!/bin/bash

container=$container
fromMail=$fromMail
dest=$dest
concertoEnv=$concertoEnv
mta=$mta

if [ -z "$container" ]; then
    echo "\$container variable undefined"
    exit 1
fi
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

helo="HELO $container"
from="MAIL FROM: <$fromMail>"
rcpt="RCPT TO: <$dest>"
cc="RCPT TO: <$fromMail>"
messageStart="DATA"
messageEnd="QUIT"
messageSubject="Subject: Concerto Automation ($concertoEnv): trivy report for container $container"

# Warning: another header is REQUIRED: Message-Id. It can be added here or (for postfix users)
# 	set the parameter:  always_add_missing_headers = yes in /etc/postfix/main.cf
#	see https://www.postfix.org/postconf.5.html#always_add_missing_headers

if ! dpkg -l | grep -q netcat; then
    apt update
    apt install netcat -y
fi

if ! dpkg -l | grep -q trivy; then
    apt install apt-transport-https gnupg lsb-release -y
    curl -s https://aquasecurity.github.io/trivy-repo/deb/public.key -o /tmp/key 
    apt-key --keyring /etc/apt/trusted.gpg.d/trivy.gpg add /tmp/key
    echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | tee -a /etc/apt/sources.list.d/trivy.list
fi

apt update
apt install trivy -y


outFile=$(mktemp --suffix=-trivy-output.log)
if ! trivy --scanners vuln fs / > $outFile; then
    echo "Trivy scan failed!"
    exit 1
fi

boundary="_$(echo ${RANDOM}${RANDOM}${RANDOM}${RANDOM}| md5sum | cut -d' ' -f1)"
toDay=$(date '+%Y-%m-%d')

echo_message() {
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

Log attached.


--$boundary
Content-Type: text/plain; name="${toDay}_Concerto_${concertoEnv}_trivy_report_${container}"
Content-Disposition: attachment; filename="${toDay}_Concerto_${concertoEnv}_trivy_report_${container}.txt";
Content-Transfer-Encoding: base64

"
    cat $outFile | base64

echo "

--${boundary}--
"


    sleep 0.3

    printf ".\r\n"
    sleep 1

    printf "$messageEnd\r\n"
    sleep 0.3
}

echo_message | nc $mta 25

rm -f $outFile


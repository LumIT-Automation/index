#!/bin/bash

container=$container

if [ -z "$container" ]; then
    echo "\$container variable undefined"
    exit 1
fi

outFile=/tmp/trivy-${container}-output.log

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

if ! trivy --scanners vuln fs / > $outFile; then
    echo "Trivy scan failed!"
    exit 1
fi



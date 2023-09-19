#!/bin/bash

script=trivy-scan.sh
fromMail=automation@lumit.it
dest=mydestination@mydest.org
concertoEnv=produzione
mta=10.88.0.1

[ -r scan-containers.conf ]  && . scan-containers.conf

containerList=$(podman ps --format="{{.Image}}"| sed 's#localhost/##g' | awk -F':' '{print $1}')

export fromMail dest mta concertoEnv

for container in $containerList; do
    export container
    # podman exec $container rm -fr /tmp/${script} || continue

    podman cp ./${script} ${container}:/root/
    podman exec $container chmod 755 /root/${script}

    ( podman exec -e=fromMail -e=container -e=dest -e=concertoEnv -e=mta -e=container -it $container /root/$script )

    podman exec $container rm -f /root/${script}
done


#!/bin/bash

hostip=`ifconfig eth0 | grep "inet " | awk -F " " '{print $2}'`

if [ "x$hostip" == "x" ]; then
    echo "cann't resolve host ip address"
    exit 1
fi

mkdir -p log
CODIS=/gopath/src/github.com/CodisLabs/codis

case "$1" in
zookeeper)
    docker rm -f      "Codis-Z2181" &> /dev/null
    docker run --name "Codis-Z2181" -d \
            --read-only \
            -p 2181:2181 \
            jplock/zookeeper
    ;;

dashboard)
    docker rm -f      "Codis-D28080" &> /dev/null
    docker run --name "Codis-D28080" -d \
        -p 28080:18080 \
        codis-image \
        codis-dashboard -l log/dashboard.log -c ${CODIS}/config/dashboard.toml --host-admin ${hostip}:28080 --zookeeper ${hostip}:2181
    ;;

proxy)
    docker rm -f      "Codis-P29000" &> /dev/null
    docker run --name "Codis-P29000" -d \
        -p 29000:19000 -p 21080:11080 \
        codis-image \
        codis-proxy -l log/proxy.log -c ${CODIS}/config/proxy.toml --host-admin ${hostip}:21080 --host-proxy ${hostip}:29000
    ;;

server)
    for ((i=0;i<4;i++)); do
        let port="26379 + i"
        docker rm -f      "Codis-S${port}" &> /dev/null
        docker run --name "Codis-S${port}" -d \
            -p $port:6379 \
            codis-image \
            codis-server --logfile redis.log
    done
    ;;

fe)
    docker rm -f      "Codis-F8080" &> /dev/null
    docker run --name "Codis-F8080" -d \
         -p 8080:8080 \
     codis-image \
     codis-fe -l log/fe.log --zookeeper ${hostip}:2181 --listen=0.0.0.0:8080 --assets=${CODIS}/bin/assets
    ;;

buildup)
    docker exec -it Codis-D28080 codis-admin --dashboard=${hostip}:28080 --create-proxy -x ${hostip}:21080
    sleep 2
    for ((i=1;i<5;i++)); do
        let port="26378 + i"
        docker exec -it Codis-D28080 codis-admin --dashboard=${hostip}:28080 --create-group   --gid=$i
        sleep 2
        docker exec -it Codis-D28080 codis-admin --dashboard=${hostip}:28080 --group-add --gid=$i --addr=${hostip}:${port}
        sleep 2
    done
    docker exec -it Codis-D28080 codis-admin -v --dashboard=${hostip}:28080 --rebalance --confirm
    ;;

cleanup)
    docker rm -f      "Codis-D28080" &> /dev/null
    docker rm -f      "Codis-P29000" &> /dev/null
    for ((i=0;i<4;i++)); do
        let port="26379 + i"
        docker rm -f      "Codis-S${port}" &> /dev/null
    done
    docker rm -f      "Codis-Z2181" &> /dev/null
    ;;

*)
    echo "wrong argument(s)"
    ;;

esac

#!/bin/bash

### PRODUCT_NAME="codis-demo"
### sed -i  "/name: CODIS_PRODUCT/{n;s/\".*\"/\"${PRODUCT_NAME}\"/}" codis-dashboard.yaml
### sed -i  "/name: CODIS_PRODUCT/{n;s/\".*\"/\"${PRODUCT_NAME}\"/}" codis-proxy.yaml

### 清理原来codis遗留数据
function cleanup() {
    kubectl delete -f .
    kubectl exec -it zk-0 -- zkCli.sh -server zk-0:2181 rmr /codis3/"codis-demo"
}

### 创建新的codis集群
function buildup() {
    kubectl create -f codis-service.yaml
    kubectl create -f codis-dashboard.yaml
    kubectl create -f codis-proxy.yaml
    kubectl create -f codis-server.yaml
    servers=$(grep "replicas" codis-server.yaml |awk  '{print $2}')
    while [ $(kubectl get pods -l app=codis-server -o name |wc -l) != $servers ]; do sleep 1; done;
    kubectl exec -it codis-server-0 -- codis-admin  --dashboard=codis-dashboard:18080 --rebalance --confirm
    kubectl create -f codis-ha.yaml
    kubectl create -f codis-fe.yaml
    sleep 60
    kubectl exec -it codis-dashboard-0 -- redis-cli -h codis-proxy -p 19000 PING
    if [ $? != 0 ]; then
        echo "buildup codis cluster with problems, plz check it!!"
    fi
}


case "$1" in
cleanup)
    cleanup
    ;;

buildup)
    cleanup
    buildup
    ;;

scale-proxy)
    kubectl scale rc codis-proxy --replicas=$2
    ;;

scale-server)
    cur=$(kubectl get statefulset codis-server |tail -n 1 |awk '{print $3}')
    des=$2
    echo $cur
    echo $des
    if [ $cur == $des ]; then
        echo "current server == desired server, return"
    elif [ $cur < $des ]; then
        kubectl scale statefulsets codis-server --replicas=$des
        while [ $(kubectl get pods -l app=codis-server -o name |wc -l) != $2 ]; do sleep 1; done;
        kubectl exec -it codis-server-0 -- codis-admin  --dashboard=codis-dashboard:18080 --rebalance --confirm
    else
        while [ $cur > $des ]
        do
            cur=`expr $cur - 2`
            gid=$(expr $cur / 2 + 1)
            kubectl exec -it codis-server-0 -- codis-admin  --dashboard=codis-dashboard:18080 --group-slots-expel --gid=$gid --confirm
        done
        kubectl scale statefulsets codis-server --replicas=$des
    fi

    ;;    

*)
    echo "wrong argument(s)"
    ;;

esac


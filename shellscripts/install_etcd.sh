#!/bin/bash

docker volume create etcd-data

docker run -d --name etcd-server \
  -p 2379:2379 \
  -e ETCD_DATA_DIR=/etcd-data \
  -e ETCD_ADVERTISE_CLIENT_URLS=http://127.0.0.1:2379 \
  -e ETCD_LISTEN_CLIENT_URLS=http://0.0.0.0:2379 \
  -v etcd-data:/etcd-data \
  quay.io/coreos/etcd:v3.5.9

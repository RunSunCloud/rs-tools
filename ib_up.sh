#!/bin/bash
# Script to bring up all InfiniBand interfaces

for iface in $(ibdev2netdev  | egrep -v 'bond|ens' | awk '{print $5}'); do
    if ! ip link show $iface | grep -q 'state UP'; then
        ip link set $iface up
    fi
done

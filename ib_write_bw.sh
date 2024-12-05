#!/bin/bash

# run ib_write_bw between two nodes
# If on bastion: ./ibbw.sh <server> <client>
# If on one compute node:  ./ibbw.sh <server>

Server=$1
Client=${2:-localhost}

cmd_ibs="ibdev2netdev | egrep -v 'bond|ens'| awk '{print \$1}' | xargs"
cmd_base="/usr/bin/ib_write_bw -a -F -q 2 --report_gbits"
S_HCA=$(ssh $Server exec $cmd_ibs)
C_HCA=$(ssh $Client exec $cmd_ibs)

for s_dev in $S_HCA; do
   for c_dev in $C_HCA; do
   	echo -e "$Server $s_dev $Client $c_dev \c"
   	ssh $Server exec $cmd_base -d $s_dev > /dev/null 2>&1 &
   	# make sure the server start listening before client make requests
   	sleep 1
   	BW=`ssh $Client exec $cmd_base -d $c_dev $Server | grep "65536      10000" | awk '{print $3}'`
   	echo "$BW"
   done
done

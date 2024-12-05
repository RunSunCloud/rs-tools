#!/bin/bash

 
items=3
sum_out_max=0
sum_in_max=0
sum_avg=0
log="/tmp/.nccl.log"
current_time=$(date -d "now" +%Y%m%d$H)
ipmi_ip=$(ipmitool lan print 1 | grep "IP Address   " | awk -F': ' '{print $2}')
host=$(hostname)

function standadr_deviation () {
  count=$1
  shift
  avg=$1
  shift
  numbers=$@
  squared_diff_sum=0
  for num in $numbers
  do
         diff=$(echo "$num - $avg" | bc )
         squared_diff=$(echo "$diff * $diff" | bc)
         squared_diff_sum=$(echo "$squared_diff_sum + $squared_diff")
  done
  variance=$(echo "$squared_diff_sum / $count" | bc)
  standard_devication=$(echo "sqrt($variance)" | bc)

  echo $variance
}

function get_avg() {
 sum=$1
 count=$2
 avg=$(echo "scale=3;$sum / $count" | bc)
 echo $avg
}

function get_sum() {
 num=$@
 sum=0
 for i in $@
 do
  sum=$(echo "$sum+ $i" | bc )
 done
 echo $sum
}

function exec_commands() {
 cmd=$@
 res=$($cmd | tee $log)
 cat /tmp/.nccl.log  >> $logfile
 out_max_bw=$(cat $log | egrep -v ^# | egrep -v ^$ | awk '{print $8}' | sort -r | head -1)
 in_max_bw=$(cat $log | egrep -v ^# | egrep -v ^$ | awk '{print $12}' | sort -r | head -1)
 avg=$(cat $log | egrep Avg | awk '{print $6}')
 echo $out_max_bw $in_max_bw $avg
}

function get_allreduce() {
 cmd="/opt/nccl-tests/build/all_reduce_perf -b 8M -e 16G -f 2 -g 8 -t 1"
 exec_commands $cmd
}

function get_allgather() {
 cmd="/opt/nccl-tests/build/all_gather_perf -b 8M -e 16G -f 2 -g 8 -t 1"
 exec_commands $cmd
}

function get_alltoall() {
 cmd="/opt/nccl-tests/build/alltoall_perf -b 8M -e 16G -f 2 -g 8 -t 1"
 exec_commands $cmd 
}

function get_reducescatter() {
 cmd="/opt/nccl-tests/build/reduce_scatter_perf -b 8M -e 16G -f 2 -g 8 -t 1"
 exec_commands $cmd
}

function start_reduce() {
 read out_max_bw_1 in_max_bw_1 avg_1 <<< $(get_allreduce)
 read out_max_bw_2 in_max_bw_2 avg_2 <<< $(get_allreduce)
 read out_max_bw_3 in_max_bw_3 avg_3 <<< $(get_allreduce)
 sum_out_max=$(get_sum $out_max_bw_1 $out_max_bw_2 $out_max_bw_3)
 sum_in_max=$(get_sum $in_max_bw_1 $in_max_bw_2 $in_max_bw_3)
 sum_avg=$(get_sum $avg_1 $avg_2 $avg_3)

 avg_out_max=$(get_avg $sum_out_max $items)
 avg_in_max=$(get_avg $sum_in_max $items)
 avg_avg=$(get_avg $sum_avg $items)

 avg_out_stand=$(standadr_deviation $items $avg_out_max $out_max_bw_1 $out_max_bw_2 $out_max_bw_3)
 avg_in_stand=$(standadr_deviation $items $avg_in_max $in_max_bw_1 $in_max_bw_2 $in_max_bw_3)
 avg_stand=$(standadr_deviation $items $avg_avg $avg_1 $avg_2 $avg_3)

 msg="out-of-place busbw max: $out_max_bw_1 $out_max_bw_2 $out_max_bw_3 avg: $avg_out_max variance: $avg_out_stand\nin-of-place busbw max: $in_max_bw_1 $in_max_bw_2 $in_max_bw_3 avg: $avg_in_max variance: $avg_in_stand\navg bus bandwidth: $avg_1 $avg_2 $avg_3 avg: $avg_avg variance: $avg_stand"
 echo -e $msg
 output_to_file $msg
}

function start_gather() {
 read out_max_bw_1 in_max_bw_1 avg_1 <<< $(get_allgather)
 read out_max_bw_2 in_max_bw_2 avg_2 <<< $(get_allgather)
 read out_max_bw_3 in_max_bw_3 avg_3 <<< $(get_allgather)
 sum_out_max=$(get_sum $out_max_bw_1 $out_max_bw_2 $out_max_bw_3)
 sum_in_max=$(get_sum $in_max_bw_1 $in_max_bw_2 $in_max_bw_3)
 sum_avg=$(get_sum $avg_1 $avg_2 $avg_3)

 avg_out_max=$(get_avg $sum_out_max $items)
 avg_in_max=$(get_avg $sum_in_max $items)
 avg_avg=$(get_avg $sum_avg $items)

 avg_out_stand=$(standadr_deviation $items $avg_out_max $out_max_bw_1 $out_max_bw_2 $out_max_bw_3)
 avg_in_stand=$(standadr_deviation $items $avg_in_max $in_max_bw_1 $in_max_bw_2 $in_max_bw_3)
 avg_stand=$(standadr_deviation $items $avg_avg $avg_1 $avg_2 $avg_3)

 msg="out-of-place busbw max: $out_max_bw_1 $out_max_bw_2 $out_max_bw_3 avg: $avg_out_max variance: $avg_out_stand\nin-of-place busbw max: $in_max_bw_1 $in_max_bw_2 $in_max_bw_3 avg: $avg_in_max variance: $avg_in_stand\navg bus bandwidth: $avg_1 $avg_2 $avg_3 avg: $avg_avg variance: $avg_stand\n"
 echo -e $msg
 output_to_file $msg
}

function start_alltoall() {
 read out_max_bw_1 in_max_bw_1 avg_1 <<< $(get_alltoall)
 read out_max_bw_2 in_max_bw_2 avg_2 <<< $(get_alltoall)
 read out_max_bw_3 in_max_bw_3 avg_3 <<< $(get_alltoall)
 sum_out_max=$(get_sum $out_max_bw_1 $out_max_bw_2 $out_max_bw_3)
 sum_in_max=$(get_sum $in_max_bw_1 $in_max_bw_2 $in_max_bw_3)
 sum_avg=$(get_sum $avg_1 $avg_2 $avg_3)

 avg_out_max=$(get_avg $sum_out_max $items)
 avg_in_max=$(get_avg $sum_in_max $items)
 avg_avg=$(get_avg $sum_avg $items)

 avg_out_stand=$(standadr_deviation $items $avg_out_max $out_max_bw_1 $out_max_bw_2 $out_max_bw_3)
 avg_in_stand=$(standadr_deviation $items $avg_in_max $in_max_bw_1 $in_max_bw_2 $in_max_bw_3)
 avg_stand=$(standadr_deviation $items $avg_avg $avg_1 $avg_2 $avg_3)

 msg="out-of-place busbw max: $out_max_bw_1 $out_max_bw_2 $out_max_bw_3 avg: $avg_out_max variance: $avg_out_stand\nin-of-place busbw max: $in_max_bw_1 $in_max_bw_2 $in_max_bw_3 avg: $avg_in_max variance: $avg_in_stand\navg bus bandwidth: $avg_1 $avg_2 $avg_3 avg: $avg_avg variance: $avg_stand\n"
 echo -e $msg
 output_to_file $msg
}

function start_reducescatter() {
 read out_max_bw_1 in_max_bw_1 avg_1 <<< $(get_reducescatter)
 read out_max_bw_2 in_max_bw_2 avg_2 <<< $(get_reducescatter)
 read out_max_bw_3 in_max_bw_3 avg_3 <<< $(get_reducescatter)
 sum_out_max=$(get_sum $out_max_bw_1 $out_max_bw_2 $out_max_bw_3)
 sum_in_max=$(get_sum $in_max_bw_1 $in_max_bw_2 $in_max_bw_3)
 sum_avg=$(get_sum $avg_1 $avg_2 $avg_3)

 avg_out_max=$(get_avg $sum_out_max $items)
 avg_in_max=$(get_avg $sum_in_max $items)
 avg_avg=$(get_avg $sum_avg $items)

 avg_out_stand=$(standadr_deviation $items $avg_out_max $out_max_bw_1 $out_max_bw_2 $out_max_bw_3)
 avg_in_stand=$(standadr_deviation $items $avg_in_max $in_max_bw_1 $in_max_bw_2 $in_max_bw_3)
 avg_stand=$(standadr_deviation $items $avg_avg $avg_1 $avg_2 $avg_3)

 msg="out-of-place busbw max: $out_max_bw_1 $out_max_bw_2 $out_max_bw_3 avg: $avg_out_max variance: $avg_out_stand\nin-of-place busbw max: $in_max_bw_1 $in_max_bw_2 $in_max_bw_3 avg: $avg_in_max variance: $avg_in_stand\navg bus bandwidth: $avg_1 $avg_2 $avg_3 avg: $avg_avg variance: $avg_stand\n"
 echo -e $msg
 output_to_file $msg
}

function output_to_file() {
 context=$@
 echo -e $context >> $results_file
}

function show_usage(){
    cat <<EOF
Usage: $0 <reduce/gather/alltoall/reducescatter>
Options:
   --help, -h                       show usage
EOF
}

function get_opts() {
    while [ "$#" -gt 0 ];do
        case $1 in 
            (--help|-h)
                show_usage
                exit 0
                ;;
            (reduce)
		start_reduce
                exit 0
                ;;
            (gather)
                start_gather
                exit 0
                ;;
            (reducescatter)
                start_reducescatter
                exit 0
                ;;
            (*)
                echo "[ERROR] Invalid option !"
                show_usage
                exit 1
                ;;
        esac
    done
 
    if [ -z $1 ];then
       echo "[ERROR] Invalid options"
       show_usage
       exit 0
    fi
}

logfile="/tmp/${ipmi_ip}_${host}_$1_${current_time}.log"
results_file="/tmp/${ipmi_ip}_${host}_$1_result_${current_time}.log"
get_opts "$@"


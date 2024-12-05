#!/bin/bash

ibstat_info() {
    # 获取ibstat输出
    output=$(ibstat)

    # 定义正则表达式模式
    ca_pattern="CA '(\w+)'"
    state_pattern="State:\s+(\w+)"
    rate_pattern="Rate:\s+([0-9]+)"
    link_pattern="Link layer:\s+(\w+)"

    # 初始化变量
    ca_name=""
    state=""
    rate=""
    link=""

    # 遍历ibstat输出的每一行
    while IFS= read -r line; do
        if [[ "$line" =~ $ca_pattern ]]; then
            # 如果是CA行，打印上一个CA的信息
            if [[ -n "$ca_name" && "$link" == "InfiniBand" ]]; then
                echo "$ca_name: State=$state, Rate=$rate, Link=$link"
            fi
            # 提取新的CA名称
            ca_name="${BASH_REMATCH[1]}"
            # 重置状态和速率
            state=""
            rate=""
            link=""
        elif [[ "$line" =~ $state_pattern ]]; then
            state="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ $rate_pattern ]]; then
              rate="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ $link_pattern ]]; then
            link="${BASH_REMATCH[1]}"
        fi
    done <<< "$output"

    # 打印最后一个CA的信息
    if [[ -n "$ca_name" && "$link" == "InfiniBand" ]]; then
        echo "$ca_name: State=$state, Rate=$rate, Link=$link"
    fi
}

# 获取 nvidia-smi topo -m 输出中的 GPU 和 NIC 对应关系
get_gpu_topo_mapping() {
    # 读取 nvidia-smi topo -m 输出
    nvidia_smi_output=$(nvidia-smi topo -m)
    ibdev2netdev_output=$(ibdev2netdev)

    # 创建一个空的关联数组
    declare -A nic_mlx_map

    # 使用 grep 和 awk 提取数据并填充到关联数组中
    while IFS=": " read -r nic mlx; do
        nic_mlx_map["$nic"]="$mlx"
    done < <(echo "$nvidia_smi_output" | grep -oP 'NIC\d+: mlx5_[\w-]+')

    # 创建 mlx -> ib 映射的关联数组
    declare -A mlx_ib_map

    # 过滤和提取 mlx -> ibp* 的映射
    while IFS=" ==> " read -r mlx_device ib_device_str; do
        # 只处理包含 ibp 的行
        ib_device=$(echo "$ib_device_str" | awk -F '==> ' '{print $2}')
        if [[ "$ib_device" =~ ^ib ]]; then
            mlx_ib_map["$mlx_device"]="$ib_device"
        fi
    done < <(echo "$ibdev2netdev_output" | grep -oP 'mlx[\w-]+ port 1 ==> \S+')

    # 获取矩阵行列数
    gpu_count=$(echo "$nvidia_smi_output" | grep -c "^GPU")
    nic_count=$(echo "$nvidia_smi_output" | grep -c "^NIC")

    # 初始化计数器
    counter=0
    # 遍历行列，提取 GPU 和 NIC 之间的物理连接信息
    for i in $(seq 1 $gpu_count); do
        for j in $(seq 1 $nic_count); do
            # 提取矩阵中每个位置的连接状态
            cell_value=$(echo "$nvidia_smi_output" | awk -v row=$((i+1)) -v col=$((j+gpu_count+1)) 'NR == row {print $col}')

            # 如果位置为 PIX，则表示该 GPU 和 NIC 之间有物理连接
            if [[ "$cell_value" == "PIX" ]]; then
                gpu_id="GPU$((i-1))"
                nic_id="NIC$((j-1))"
                mlx_device="${nic_mlx_map[$nic_id]}"
                ib_device="${mlx_ib_map[$mlx_device]}"
                if [ -n "$ib_device" ]; then
                    ((counter++))
                fi
                echo "$gpu_id is connected to $nic_id, $mlx_device, $ib_device"
            fi
        done
    done
    # 判断计数器是否为 8，如果为 8 则输出 Pass
    if [ "$counter" -eq 8 ]; then
        echo -e "\033[32mPass\033[0m"
    else
        echo -e "\033[31mFail\033[0m"
    fi
}

ib_and_eth_count() {
    # 初始化InfiniBand和Ethernet的带宽统计数组
    declare -A ib_bandwidths
    declare -A ethernet_bandwidths

    # 获取网卡列表，过滤掉带bond的网卡
    ibdev2netdev_output=$(ibdev2netdev)

    # 获取ibstat的设备列表，过滤掉bond接口（包括 mlx5_bond_0）
    devices=$(echo "$ibdev2netdev_output" | grep -v "bond" | awk '{print $1}')

    # 遍历每个InfiniBand设备，获取其Rate信息
    for device in $devices; do
        # 使用 ibstat 获取设备的详细信息
        ibstat_output=$(ibstat "$device")

        # 提取 Link layer 和 Rate 信息
        link_layer=$(echo "$ibstat_output" | grep "Link layer" | awk '{print $3}')
        rate=$(echo "$ibstat_output" | grep "Rate" | awk '{print $2}')

        # 根据 Link layer 区分 InfiniBand 和 Ethernet
        if [[ "$link_layer" == "InfiniBand" ]]; then
            # InfiniBand带宽统计
            ib_bandwidths["$rate"]=$((ib_bandwidths["$rate"] + 1))
        elif [[ "$link_layer" == "Ethernet" ]]; then
            # Ethernet带宽统计
            ethernet_bandwidths["$rate"]=$((ethernet_bandwidths["$rate"] + 1))
        fi
    done

    # 获取以太网和InfiniBand设备的Speed信息并存储到数组
    for device in /sys/class/net/*; do
        if [[ -d "$device" && ( "$(basename $device)" == en*) ]]; then
            device_name=$(basename "$device")

            # 处理以太网网卡
            if [[ "$device_name" == en* ]]; then
                # 尝试使用 ethtool 获取以太网卡的带宽信息
                eth_speed=$(ethtool "$device_name" 2>/dev/null | grep -i "Speed" | awk '{print $2}' | sed 's/Mb\/s//g')

                # 如果 ethtool 返回 Unknown!，则跳过该网卡或标记为 Unknown
                if [[ "$eth_speed" == "Unknown!" ]]; then
                    eth_speed="Unknown"
                fi

                # 如果 speed 有有效数据，则处理
                if [[ -n "$eth_speed" && "$eth_speed" != "Unknown" ]]; then
                    rate=$(expr $eth_speed / 1000)
                    ethernet_bandwidths["$rate"]=$((ethernet_bandwidths["$rate"] + 1))
                fi
            fi
        fi
    done

    # 输出统计信息
    echo "InfiniBand:"
    for rate in "${!ib_bandwidths[@]}"; do
        echo "$rate Gb/s x ${ib_bandwidths[$rate]}"
    done

    echo "Ethernet:"
    for rate in "${!ethernet_bandwidths[@]}"; do
        echo "$rate Gb/s x ${ethernet_bandwidths[$rate]}"
    done
}

else_outputs=()

cpu_count=$(lscpu | grep "^Socket(s):" | awk '{print $2}')
cpu_cores=$(lscpu | grep "^Core(s) per socket:" | awk '{print $4}')
cpu_model=$(lscpu | grep "^Model name:" | cut -d ':' -f 2 | sed 's/^ *//g')
echo -e "CPU: ${cpu_model} ${cpu_cores}Cores x ${cpu_count}"

ram_count=$(sudo dmidecode --type memory | grep "^[[:space:]]*Size:" | grep -v "No Module Installed" | wc -l)
per_ram_size=$(sudo dmidecode --type memory | grep -E "^[[:space:]]*Size:" | grep -v "No Module Installed" | awk  '{print $2}' | head -n 1)
per_mem_rate=$(sudo dmidecode --type memory | grep "^[[:space:]]*Speed:" | grep -v "Unknown" | awk  '{print $2}' | head -n 1)
echo -e "RAM: ${per_ram_size}GB ${per_mem_rate} MT/s x ${ram_count}"

gpu_count=$(nvidia-smi --query-gpu=count --id=0 --format=csv,noheader,nounits)
gpu_model=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -n 1)
echo -e "GPU: ${gpu_model} x ${gpu_count}"

disks=$(lsblk -d -n -o NAME,ROTA,SIZE | grep -vE "loop|sr|nbd" | awk '{print ($2 == 1 ? "HDD" : "SSD")"-"$3}')
declare -A diskstats
for disk in $disks
do
  diskstats[$disk]=$[ ${diskstats[$disk]} + 1 ]
done
diskstr="DISKS:"
for dkey in ${!diskstats[@]}
do
  diskstr=$diskstr" $dkey x ${diskstats[$dkey]}"
done
echo -e $diskstr

ibs=$(ibstat_info)
net_info=$(ib_and_eth_count)
echo -e "$net_info"

# gpu topo check
echo "Topo:"
topo=$(nvidia-smi topo -mp)
echo -e "$topo"

# output to spec_check.txt
cat << EOF > spec_check.txt
CPU: ${cpu_model} ${cpu_cores}Cores x ${cpu_count}
RAM: ${per_ram_size}GB ${per_mem_rate} MT/s x ${ram_count}
GPU: ${gpu_model} x ${gpu_count}
DISK: $diskstr
$net_info
Topo:
$topo
EOF

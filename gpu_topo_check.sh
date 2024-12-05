#!/bin/bash

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

# 执行函数
get_gpu_topo_mapping

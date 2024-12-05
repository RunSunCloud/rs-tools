#!/bin/bash

# 1. ulimit
ulimit_value=$(ulimit -n)

# 2. SSHD settings (PermitRootLogin and PasswordAuthentication)
sshd_config="/etc/ssh/sshd_config"
permit_root_login=$(grep "^PermitRootLogin" $sshd_config | awk '{print $2}')
password_authentication=$(grep "^PasswordAuthentication" $sshd_config | awk '{print $2}')

# 3. OS version
os_version=$(lsb_release -d | awk -F"\t" '{print $2}')

# 4. Kernel version
kernel_version=$(uname -r)

# 5. GCC version
gcc_version=$(gcc --version | head -n 1)

# 6. Timezone
timezone=$(timedatectl show --property=Timezone --value)

# 7. OFED version
ofed_version=$(ofed_info -s | tr -d ':')

# 8. CUDA version
cuda_version=$(nvcc --version | grep "release" | awk '{print $5}' | sed 's/,//')

# 9. NVIDIA Driver version
nvidia_driver_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)

# 10. NVIDIA Fabric Manager status
fabric_manager_status=$(systemctl is-active nvidia-fabricmanager)

# 11. NVIDIA Peer Memory status
peer_memory_status=$(lsmod | grep nvidia_peermem &> /dev/null && echo "active" || echo "inactive")

# 12. Chrony service status
chronyd_status=$(systemctl is-enabled chrony)

# 13. GPU Persistence Mode status
gpu_persistence_mode=$(nvidia-smi --query-gpu=persistence_mode --format=csv,noheader | head -n 1)

# 14. CPU Performance Mode status
cpu_performance_mode=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)

# Output results
echo "ulimit: $ulimit_value"
echo "sshd: PermitRootLogin $permit_root_login  PasswordAuthentication $password_authentication"
echo "OS version: $os_version"
echo "Kernel version: $kernel_version"
echo "gcc version: $gcc_version"
echo "timezone: $timezone"
echo "OFED version: $ofed_version"
echo "CUDA version: $cuda_version"
echo "NVIDIA Driver version: $nvidia_driver_version"
echo "NVIDIA Fabric Manager: $fabric_manager_status"
echo "NVIDIA Peer Memory: $peer_memory_status"
echo "chronyd: $chronyd_status"
echo "GPU Persistence Mode: $gpu_persistence_mode"
echo "CPU Performance Mode: $cpu_performance_mode"

# output to system_check.txt
cat << EOF > system_check.txt
ulimit: $ulimit_value
sshd: PermitRootLogin $permit_root_login  PasswordAuthentication $password_authentication
OS version: $os_version
Kernel version: $kernel_version
gcc version: $gcc_version
timezone: $timezone
OFED version: $ofed_version
CUDA version: $cuda_version
NVIDIA Driver version: $nvidia_driver_version
NVIDIA Fabric Manager: $fabric_manager_status
NVIDIA Peer Memory: $peer_memory_status
chronyd: $chronyd_status
GPU Persistence Mode: $gpu_persistence_mode
CPU Performance Mode: $cpu_performance_mode
EOF
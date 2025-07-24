#!/bin/bash
PREFILL_JOB_NAME='run_prefill.sh'

PREFILL_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $PREFILL_JOB_NAME -h -o "%N") | head -n1)
# 配置部分
BOOTSTRAP_ADDR="$PREFILL_MASTER_NODE:8998"  # 替换为实际的bootstrap服务器地址
SSH_USER="tianr"  # 替换为你的SSH用户名

CURL_TIMEOUT=5

# 目标IP列表 - 请根据实际情况修改
# 正确的数组定义（去掉逗号）
IP_LIST=(
    "g0006"
    "g0009"
    "g0017"
    "g0018"
    "g0021"
    "g0027"
    "g0028"
    "g0029"
    "g0030"
)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Starting health check for bootstrap server: ${BOOTSTRAP_ADDR}${NC}"
echo "========================================================"

# 函数：单个节点健康检查
check_node() {
    local ip=$1
    local node_name="${ip}"
    
    echo -e "${YELLOW}[${node_name}] Connecting via SSH...${NC}"
    
    # SSH连接并执行curl命令
    ssh_result=$(ssh "${ip}" \
                     "curl -v --connect-timeout 2 --max-time ${CURL_TIMEOUT} http://${BOOTSTRAP_ADDR}/health" 2>&1)
    
    ssh_exit_code=$?
    
    if [ $ssh_exit_code -eq 0 ]; then
        if echo "$ssh_result" | grep -q "200 OK\|< HTTP.*200"; then
            echo -e "${GREEN}[${node_name}] ✓ Health check PASSED${NC}"
            echo -e "${GREEN}[${node_name}] Response: $(echo "$ssh_result" | grep -E "< HTTP|OK" | head -1)${NC}"
        else
            echo -e "${RED}[${node_name}] ✗ Health check FAILED${NC}"
            echo -e "${RED}[${node_name}] Error: $ssh_result${NC}"
        fi
    else
        echo -e "${RED}[${node_name}] ✗ SSH connection FAILED${NC}"
        echo -e "${RED}[${node_name}] Error: $ssh_result${NC}"
    fi
    echo "----------------------------------------"
}

# 并行执行健康检查
for ip in "${IP_LIST[@]}"; do
    check_node "$ip" &
done

# 等待所有后台任务完成
wait

echo -e "${BLUE}Health check completed!${NC}"
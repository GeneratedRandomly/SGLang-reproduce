#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <num_nodes> <num_gpus_per_node> [your command after torchrun]..."
    exit 1
fi

JOB_NAME=$USER-sglang-decode
NODES=$1
NTASKS_PER_NODE=1
CPUS_PER_TASK=32
GPUS_PER_TASK=$2

THIS_SCRIPT=$(realpath $0)

if [[ "$3" != "--node" ]]; then
    COMMAND=${@:3}
    PARAMS="--job-name $JOB_NAME --nodes $NODES --ntasks-per-node $NTASKS_PER_NODE --cpus-per-task $CPUS_PER_TASK --gres=gpu:$GPUS_PER_TASK"
    exec srun $PARAMS $THIS_SCRIPT $1 $2 --node 
fi

CONDA_ENV="sglang-pd"
CONDA_PATH="/ssd/tianr/miniconda3"

# 初始化conda
source "$CONDA_PATH/etc/profile.d/conda.sh"

# 激活环境并检查是否成功
conda activate "$CONDA_ENV"
echo "Activated conda environment: $CONDA_ENV"

# Get the full list of nodes in the job
NODELIST=$(scontrol show hostnames "$SLURM_JOB_NODELIST")
# Convert to array
NODES_ARRAY=($NODELIST)
# Get current node's rank
NODE_RANK=0
for i in "${!NODES_ARRAY[@]}"; do
    if [[ "${NODES_ARRAY[$i]}" == "$(hostname)" ]]; then
        NODE_RANK=$i
        break
    fi
done

MASTER_ADDR=${NODES_ARRAY[0]}

## decode instructions
export NVSHMEM_HCA_LIST=mlx5_0,mlx5_1,mlx5_3,mlx5_4
export MC_TE_METRIC=true
export SGLANG_TBO_DEBUG=1
export SGLANG_NUM_RESERVED_DECODE_TOKENS=102



COMMAND="python3 -m sglang.launch_server \
--model-path /ssd/DeepSeek-R1 \
--disaggregation-ib-device mlx5_0,mlx5_1,mlx5_3,mlx5_4 \
--disaggregation-mode decode \
--dist-init-addr ${MASTER_ADDR}:5757 \
--nnodes $SLURM_NNODES \
--node-rank $NODE_RANK \
--tp-size $((SLURM_NNODES * GPUS_PER_TASK)) \
--dp-size $((SLURM_NNODES * GPUS_PER_TASK)) \
--enable-dp-attention \
--decode-log-interval 1 \
--enable-deepep-moe \
--page-size 1 \
--host 0.0.0.0 \
--trust-remote-code \
--moe-dense-tp-size 1 \
--enable-dp-lm-head \
--disable-radix-cache \
--watchdog-timeout 1000000 \
--enable-two-batch-overlap \
--deepep-mode low_latency \
--mem-fraction-static 0.835 \
--max-running-requests $((SLURM_NNODES * 2048)) \
--context-length 4500 \
--cuda-graph-bs 128 \
--ep-num-redundant-experts 32
"
export TZ=UTC-8
date=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_DIR="/ssd/tianr/log_decode/${SLURM_NNODES}_${date}"
mkdir -p $LOG_DIR
echo "Command to run: $COMMAND"


$COMMAND 2>&1 | tee -a $LOG_DIR/decode_srun_${NODE_RANK}.log
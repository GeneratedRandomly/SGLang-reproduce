#!/bin/bash

MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
# Get current node's rank
NODE_RANK=$SLURM_PROCID

echo "RANK_ID: $SLURM_PROCID"

GPUS_PER_NODE=8

# prefill instructionss
# deep_ep environment variables
export NVSHMEM_HCA_LIST=mlx5_0,mlx5_3,mlx5_4,mlx5_7

# CUDA
export CUDA_HOME=/usr/local/cuda-12.9
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# NCCL
export NCCL_HOME=/home/zhangrq/Programs/nccl_2.27.7-1+cuda12.9_x86_64
export LD_LIBRARY_PATH=$NCCL_HOME/lib:$LD_LIBRARY_PATH
export NCCL_DEBUG=WARN

export TORCH_CUDA_ARCH_LIST="9.0"

# export CUDA_DEVICE_MAX_CONNECTIONS=1
export MC_TE_METRIC=true
export SGLANG_TBO_DEBUG=1
export TRITON_CACHE_DIR=/tmp/${USER}/triton_cache
export SGL_DG_CACHE_DIR=/tmp/${USER}/sgl_deepgemm_cache
# export SGLANG_DISAGGREGATION_BOOTSTRAP_TIMEOUT=6000

# mooncake
# export LD_LIBRARY_PATH=/home/zjx23/Mooncake/mooncakelib:$LD_LIBRARY_PATH
# export PYTHONPATH=~/dkmc:$PYTHONPATH

export MODEL_PATH=/data/nfs/DeepSeek-R1
export SGLANG_REPRODUCE_HOME=$HOME/SGLang-reproduce

COMMAND="python3 -m sglang.launch_server \
--model-path $MODEL_PATH \
--disaggregation-ib-device ${NVSHMEM_HCA_LIST} \
--disaggregation-mode prefill \
--dist-init-addr ${MASTER_ADDR}:5757 \
--nnodes $SLURM_NNODES \
--node-rank $NODE_RANK \
--tp-size $((SLURM_NNODES * GPUS_PER_NODE)) \
--dp-size $((SLURM_NNODES * GPUS_PER_NODE)) \
--enable-dp-attention \
--decode-log-interval 1 \
--moe-a2a-backend deepep \
--page-size 1 \
--host 0.0.0.0 \
--trust-remote-code \
--moe-dense-tp-size 1 \
--enable-dp-lm-head \
--disable-radix-cache \
--watchdog-timeout 1000000 \
--dist-timeout 600000 \
--deepep-mode normal \
--mem-fraction-static 0.84 \
--chunked-prefill-size $((SLURM_NNODES * 131072)) \
--max-running-requests $((SLURM_NNODES * 2048)) \
--max-total-tokens 131072 \
--context-length 8192 \
--enable-two-batch-overlap \
--ep-num-redundant-experts 32 \
--ep-dispatch-algorithm dynamic \
--eplb-algorithm deepseek \
--attention-backend flashmla \
--init-expert-location $SGLANG_REPRODUCE_HOME/attachment_ep_statistics/prefill_in4096.json
"

export TZ=UTC-8
date=$(date '+%Y-%m-%d_%H-%M')
LOG_DIR="$SGLANG_REPRODUCE_HOME/log_prefill/${SLURM_NNODES}_${date}"
mkdir -p $LOG_DIR
echo "Command to run: $COMMAND"

eval $COMMAND 2>&1 | tee -a $LOG_DIR/prefill_srun_${NODE_RANK}.log

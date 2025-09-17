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
export SGLANG_DEEPEP_NUM_MAX_DISPATCH_TOKENS_PER_RANK=256
export SGLANG_DISAGGREGATION_WAITING_TIMEOUT=6000
export MODEL_PATH=/data/nfs/DeepSeek-R1
export DATASET_PATH=/data/nfs/ShareGPT_V3_unfiltered_cleaned_split.json
export SGLANG_REPRODUCE_HOME=$HOME/SGLang-reproduce
export SGLANG_LOG_DIR=$SGLANG_REPRODUCE_HOME/log
export SGLANG_RESULT_DIR=$SGLANG_REPRODUCE_HOME/result
export SGLANG_TORCH_PROFILER_DIR=$SGLANG_REPRODUCE_HOME/profile

COMMAND="python3 -m sglang.bench_offline_throughput \
--model-path $MODEL_PATH \
--tokenizer-path $MODEL_PATH \
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
--deepep-mode auto \
--ep-num-redundant-experts 0 \
--mem-fraction-static 0.78 \
--chunked-prefill-size $((SLURM_NNODES * 32768)) \
--max-running-requests $((SLURM_NNODES * 16)) \
--context-length 6144 \
--attention-backend flashmla \
--skip-warmup \
--sharegpt-output-len 100 \
--dataset-path $DATASET_PATH \
--cuda-graph-bs 2 \
--cuda-graph-max-bs 2 \
--ep-dispatch-algorithm fake \
--result-filename $SGLANG_RESULT_DIR/result_sglang_32.txt \
"

export TZ=UTC-8
date=$(date '+%Y-%m-%d_%H-%M')
LOG_DIR="$SGLANG_LOG_DIR/${SLURM_NNODES}_${date}"
mkdir -p $LOG_DIR
echo "Command to run: $COMMAND"

eval $COMMAND 2>&1 | tee -a $LOG_DIR/decode_srun_${NODE_RANK}.log

#!/bin/bash

PREFILL_NODES=$1
DECODE_NODES=$2
GPUS_PER_TASK=8

PREFILL_JOB_NAME=$USER-sglang-prefill
DECODE_JOB_NAME=$USER-sglang-decode
CONDA_ENV="sglang-pd"
CONDA_PATH="/ssd/tianr/miniconda3"

# 初始化conda
source "$CONDA_PATH/etc/profile.d/conda.sh"

bash ./run_prefill_srun.sh $PREFILL_NODES $GPUS_PER_TASK &
sleep 10  
bash ./run_decode_srun.sh $DECODE_NODES $GPUS_PER_TASK &
sleep 10


PREFILL_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $PREFILL_JOB_NAME -h -o "%N") | head -n1)
DECODE_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $DECODE_JOB_NAME -h -o "%N") | head -n1)
echo "Prefill master node: $PREFILL_MASTER_NODE"
echo "Decode master node: $DECODE_MASTER_NODE"


# JOB_NAME=$USER-sglang-load-balance
# NTASKS_PER_NODE=1
# CPUS_PER_TASK=32
# PARAMS="--job-name $JOB_NAME --nodes 1 --ntasks-per-node $NTASKS_PER_NODE --cpus-per-task $CPUS_PER_TASK"

LB_COMMAMD="python3 -m sglang.srt.disaggregation.mini_lb \
--prefill "http://$PREFILL_MASTER_NODE:30000" \
--decode "http://$DECODE_MASTER_NODE:30000" \
"

echo "Load balancing command: $LB_COMMAMD"

$LB_COMMAMD &
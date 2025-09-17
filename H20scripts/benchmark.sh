#!/bin/bash

[[ $# -lt 2 ]] && { echo "Usage: $0 <mode> <profile>"; echo "mode: prefill or decode"; echo "profile: true or false"; exit 1; }
MODE=$1
PROFILE=$2

get_master_node() {
    scontrol show hostnames $(squeue -u $USER -n $1 -h -o "%N") | head -n1
}


DECODE_MASTER_NODE=$(get_master_node 'sgl_d')
PREFILL_MASTER_NODE=$(get_master_node 'sgl_p')
LB_IP=$(get_master_node 'lb')
LB_IP=${LB_IP: -2}
TRACE_PREFIX=$HOME/trace
export TORCH_CUDA_ARCH_LIST="9.0"

if [ "$MODE" == "prefill" ]; then
    BATCH_SIZE=64
    INPUT_LEN=32
    MASTER_NODE=$PREFILL_MASTER_NODE
    TRACE_PREFIX=$TRACE_PREFIX/prefill
    PROFILE_STEPS=3
elif [ "$MODE" == "decode" ]; then
    BATCH_SIZE=10000
    INPUT_LEN=250
    MASTER_NODE=$DECODE_MASTER_NODE
    TRACE_PREFIX=$TRACE_PREFIX/decode
    PROFILE_STEPS=10

	curl -H 'Content-Type: application/json' -d '{"forward_sleep_time": 90.0}' -X POST "http://$DECODE_MASTER_NODE:30000/slow_down"
    sleep 5
else
    echo "Error: Invalid mode '$MODE'. Use 'prefill' or 'decode'."
    exit 1
fi

COMMAND="python -m sglang.bench_one_batch_server \
    --model-path /data/nfs/DeepSeek-R1 \
    --base-url http://172.31.0.${LB_IP}:8000 \
    --batch-size $BATCH_SIZE \
    --input-len $INPUT_LEN \
    --output-len 5 \
    --skip-warmup &
"

if [ "$MODE" == "decode" ]; then
    sleep 260
    curl -H 'Content-Type: application/json' -d '{"forward_sleep_time": null}' -X POST "http://$DECODE_MASTER_NODE:30000/slow_down"
fi

if [ "$PROFILE" == "true" ]; then
    TRACE_DIR="$TRACE_PREFIX/$USER/$(date '+%Y-%m-%d_%H-%M')"
    mkdir -p $TRACE_DIR
    echo "Trace saved to $TRACE_DIR"
    curl -X POST "http://$MASTER_NODE:30000/start_profile" \
        -H 'Content-Type: application/json' \
        -d "{\"output_dir\": \"$TRACE_DIR\", \"num_steps\": $PROFILE_STEPS, \"record_shapes\": true}"
fi

export TZ=UTC-8
export SGLANG_REPRODUCE_HOME=$HOME/SGLang-reproduce
date=$(date '+%Y-%m-%d_%H-%M')
LOG_DIR="$SGLANG_REPRODUCE_HOME/log_bm/${SLURM_NNODES}_${date}"
mkdir -p $LOG_DIR
echo "Command to run: $COMMAND"

eval $COMMAND 2>&1 | tee -a $LOG_DIR/bm_${NODE_RANK}.log
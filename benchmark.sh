#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <mode> <profile>"
    echo "mode: prefill or decode"
    echo "profile: true or false"
    exit 1
fi

MODE=$1
PROFILE=$2

PREFILL_JOB_NAME='run_prefill.sh'
DECODE_JOB_NAME='run_decode.sh'

DECODE_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $DECODE_JOB_NAME -h -o "%N") | head -n1)
PREFILL_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $PREFILL_JOB_NAME -h -o "%N") | head -n1)

# 根据模式设置参数
if [ "$MODE" == "prefill" ]; then
    BATCH_SIZE=8192
    INPUT_LEN=4096
elif [ "$MODE" == "decode" ]; then
    BATCH_SIZE=40000
    INPUT_LEN=2000
    SLOW_COMMAND="curl -H 'Content-Type: application/json' -d '{\"forward_sleep_time\": 90.0}' -X POST 'http://$DECODE_MASTER_NODE:30000/slow_down'"
    echo "Slow command: $SLOW_COMMAND"
    eval $SLOW_COMMAND
    sleep 5
else
    echo "Error: Invalid mode '$MODE'. Use 'prefill' or 'decode'."
    exit 1
fi

COMMAND="python3 -m sglang.bench_one_batch_server \
--model-path /ssd/DeepSeek-R1  \
--base-url http://localhost:8000 \
--batch-size $BATCH_SIZE \
--input-len $INPUT_LEN \
--output-len 100 \
--skip-warmup
"

echo "Running command: $COMMAND"
eval $COMMAND &

if [ "$MODE" == "decode" ]; then
    sleep 260
    DESLOW_COMMAND="curl -H 'Content-Type: application/json' -d '{\"forward_sleep_time\": null}' -X POST 'http://$DECODE_MASTER_NODE:30000/slow_down'"
    echo "Deslow command: $DESLOW_COMMAND"
    eval $DESLOW_COMMAND
fi

if [ "$PROFILE" == true ]; then
    if [ "$MODE" == "prefill" ]; then
        echo "Profiling prefill job"
        date=$(date '+%Y-%m-%d_%H-%M')
        TRACE_DIR="/ssd/tianr/trace/prefill/$USER/$date"
        mkdir -p $TRACE_DIR
        PROFILE_COMMAND="curl -X POST http://$PREFILL_MASTER_NODE:30000/start_profile \
        -H 'Content-Type: application/json' \
        -d '{
            \"output_dir\": \"$TRACE_DIR\",
            \"num_steps\": 8,
            \"record_shapes\": true
        }'"
        echo "Profile command: $PROFILE_COMMAND"
        eval $PROFILE_COMMAND 
    elif [ "$MODE" == "decode" ]; then
        echo "Profiling decode job"
        date=$(date '+%Y-%m-%d_%H-%M')
        TRACE_DIR="/ssd/tianr/trace/decode/$USER/$date"
        mkdir -p $TRACE_DIR
        PROFILE_COMMAND="curl -X POST http://$DECODE_MASTER_NODE:30000/start_profile \
        -H 'Content-Type: application/json' \
        -d '{
            \"output_dir\": \"$TRACE_DIR\",
            \"num_steps\": 10,
            \"record_shapes\": true
        }'"     
        echo "Profile command: $PROFILE_COMMAND"
        eval $PROFILE_COMMAND
    fi
else
    echo "Profiling not enabled"
fi
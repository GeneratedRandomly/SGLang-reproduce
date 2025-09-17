#!/bin/bash
PREFILL_JOB_NAME='sgl_p'
DECODE_JOB_NAME='sgl_d'

PREFILL_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $PREFILL_JOB_NAME -h -o "%N") | head -n1)
DECODE_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $DECODE_JOB_NAME -h -o "%N") | head -n1)
echo "Prefill master node: $PREFILL_MASTER_NODE"
echo "Decode master node: $DECODE_MASTER_NODE"

COMMAND="python3 -m sglang.srt.disaggregation.mini_lb \
--prefill "http://172.31.0.${PREFILL_MASTER_NODE: -2}:30000" \
--decode "http://172.31.0.${DECODE_MASTER_NODE: -2}:30000" \
"

echo "Load balancing command: $COMMAND"

eval $COMMAND
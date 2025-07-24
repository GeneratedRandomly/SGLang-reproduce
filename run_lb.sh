#!/bin/bash
PREFILL_JOB_NAME='run_prefill.sh'
DECODE_JOB_NAME='run_decode.sh'

PREFILL_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $PREFILL_JOB_NAME -h -o "%N") | head -n1)
DECODE_MASTER_NODE=$(scontrol show hostnames $(squeue -u $USER -n $DECODE_JOB_NAME -h -o "%N") | head -n1)
echo "Prefill master node: $PREFILL_MASTER_NODE"
echo "Decode master node: $DECODE_MASTER_NODE"

LB_COMMAMD="python3 -m sglang.srt.disaggregation.mini_lb \
--prefill "http://$PREFILL_MASTER_NODE:30000" \
--decode "http://$DECODE_MASTER_NODE:30000" \
"

echo "Load balancing command: $LB_COMMAMD"

eval $LB_COMMAMD
#!/bin/bash
                                                                                                     
# srun -N 2 -n 2 --gres=gpu:8 xxx

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <test_partition>"
    echo "Available partitions: intranode, internode, low_latency"
    exit 1
fi

TEST_PARTITION=$1   

if [ $(hostname) == "g0002" ]; then                                 
    export NVSHMEM_HCA_LIST=mlx5_0,mlx5_3,mlx5_4,mlx5_5             
elif [ $(hostname) == "g0004" ]; then                               
    export NVSHMEM_HCA_LIST=mlx5_0,mlx5_3,mlx5_4,mlx5_5             
elif [ $(hostname) == "g0029" ]; then                               
    export NVSHMEM_HCA_LIST=mlx5_0,mlx5_3,mlx5_4,mlx5_5             
else                                                                
    export NVSHMEM_HCA_LIST=mlx5_0,mlx5_1,mlx5_3,mlx5_4             
fi                                                                  

export CUDA_DEVICE_MAX_CONNECTIONS=1  

if [ "$TEST_PARTITION" == "intranode" ]; then                         
    # COMMAND="python /ssd/tianr/test-sglang/Deepep_new/DeepEP/tests/test_intranode.py" 
    COMMAND="python /ssd/tianr/test-sglang/test-deepep/DeepEP/tests/test_internode.py"         
    # COMMAND="python /ssd/tianr/deep_ep_version/deepep_yhy/DeepEP/tests/test_intranode.py"                                       
elif [ "$TEST_PARTITION" == "internode" ]; then                         
    COMMAND="python /ssd/tianr/test-sglang/test-deepep/DeepEP/tests/test_internode.py"
    # COMMAND="python /ssd/tianr/test-sglang/Deepep_new/DeepEP/tests/test_internode.py"
    # COMMAND="python /ssd/tianr/deep_ep_version/deepep_yhy/DeepEP/tests/test_internode.py"                        
    export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)                                                          
    export MASTER_PORT=$(($SLURM_JOB_ID+32000))                         
    export WORLD_SIZE=$SLURM_NPROCS                                     
    export RANK=$SLURM_PROCID                             
elif [ "$TEST_PARTITION" == "low_latency" ]; then          
    export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" |
    head -n 1)                                                          
    export MASTER_PORT=$(($SLURM_JOB_ID+32000))                         
    export WORLD_SIZE=$SLURM_NPROCS                                     
    export RANK=$SLURM_PROCID                                                     
    # COMMAND="python /ssd/tianr/test-sglang/Deepep_new/DeepEP/tests/test_low_latency.py"         
    COMMAND="python /ssd/tianr/test-sglang/test-deepep/DeepEP/tests/test_low_latency.py"            
    # COMMAND="python /ssd/tianr/deep_ep_version/deepep_yhy/DeepEP/tests/test_low_latency.py"                                             
else                                                                
    echo "Invalid test partition: $TEST_PARTITION"                 
    exit 1                                                                                                                                            
fi
export TZ=UTC-8
date=$(date '+%Y-%m-%d_%H-%M')
LOG_DIR="/ssd/tianr/log_test_deepep/${SLURM_NNODES}_${date}"
mkdir -p $LOG_DIR
echo "Command to run: $COMMAND"

eval $COMMAND 2>&1 | tee -a $LOG_DIR/test_deepep_${TEST_PARTITION}_${SLURM_NNODES}_${SLURM_PROCID}.log                                     

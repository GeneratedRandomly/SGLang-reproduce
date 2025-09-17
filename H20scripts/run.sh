#!/bin/bash
# lb.sh 和 benchmark.sh 会通过 job-name 来找 prefill 和 decode 节点
# 先跑前三条 srun，最后再跑 benchmark
srun -N 2 -n 2 -x bjdb-h20-node-[021,040,038] --job-name=sgl_p --gres=gpu:8 --cpus-per-task=32 ./prefill.sh &
# srun -N 4 -n 4 -x bjdb-h20-node-[021,040,038] --job-name=sgl_p --gres=gpu:8 --cpus-per-task=32 ./prefill.sh
srun -N 1 -n 1 -x bjdb-h20-node-[021,040,038] --job-name=sgl_d --gres=gpu:8 --cpus-per-task=32 ./decode.sh &
# srun -N 4 -n 4 -x bjdb-h20-node-[021,040,038] --job-name=sgl_d --gres=gpu:8 --cpus-per-task=32 ./decode.sh
# srun -N 9 -n 9 -x bjdb-h20-node-[021,040,038] --job-name=sgl_d --gres=gpu:8 --cpus-per-task=32 ./decode.sh

srun -N 1 -n 1 -x bjdb-h20-node-[021,040,038] --job-name=lb --cpus-per-task=32 ./lb.sh &
srun -N 1 -n 1 -x bjdb-h20-node-[021,040,038] --job-name=bm --gres=gpu:8 --cpus-per-task=32 ./benchmark.sh prefill false &

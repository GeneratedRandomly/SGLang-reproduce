# SGLang小规模复现说明
## 复现账号

## 复现环境
* 复现结点:g0009,g0018,g0021,g0027  
登录g0018后可以直接通过ssh g00xx登录相应结点

* conda环境配置
  ```bash
  source /ssd/tianr/miniconda3/bin/activate
  conda activate sglang-pd
  ```
* 其他注意事项
  *  注意这份sglang代码中hard code DeepSeek-R1的层数为20（考虑到卡数内存限制），不影响分析单layer内部的性能
  * mooncake与deepep(以及其他rdma操作)都需要屏蔽网卡mlx_2，否则会卡死，在下面的脚本中通过环境变量实现
  * 如果发生deepgemm编译cache路径有关问题，可以尝试修改环境变量SGL_DG_CACHE_DIR
## 复现指令
### prefill
* 三机作为P结点，一机作为D结点
```bash
## for prefill
## 假设选取g0009,g0018,g0021作为P结点，其中g0021(172.16.21.80)为主节点

## 启动prefill server
### g0021
NVSHMEM_HCA_LIST=mlx5_0,mlx5_1,mlx5_3,mlx5_4 MC_TE_METRIC=true SGLANG_TBO_DEBUG=1 python3 -m sglang.launch_server --model-path /ssd/DeepSeek-R1 --disaggregation-ib-device mlx5_0,mlx5_1,mlx5_3,mlx5_4 --disaggregation-mode prefill --dist-init-addr 172.16.21.80:5757 --nnodes 3 --node-rank 0 --tp-size 24 --dp-size 24 --enable-dp-attention --decode-log-interval 1 --enable-deepep-moe --page-size 1 --host 0.0.0.0 --trust-remote-code --moe-dense-tp-size 1 --enable-dp-lm-head --disable-radix-cache --watchdog-timeout 1000000 --deepep-mode normal --mem-fraction-static 0.85 --chunked-prefill-size 393216 --max-running-requests 6144 --max-total-tokens 131072 --context-length 8192 --enable-two-batch-overlap --ep-num-redundant-experts 32 --ep-dispatch-algorithm dynamic --eplb-algorithm deepseek --init-expert-location /ssd/tianr/test-sglang/sglang/attachment_ep_statistics/prefill_in4096.json

### g0009,g0018
修改上面指令中的--node-rank即可

## 启动decode server，g0027为decode结点
### g0027
NVSHMEM_HCA_LIST=mlx5_0,mlx5_1,mlx5_3,mlx5_4 SGLANG_NUM_RESERVED_DECODE_TOKENS=130 MC_TE_METRIC=true SGLANG_TBO_DEBUG=1 python3 -m sglang.launch_server --model-path /ssd/DeepSeek-R1 --disaggregation-ib-device mlx5_0,mlx5_1,mlx5_3,mlx5_4 --disaggregation-mode decode --dist-init-addr 172.16.21.86:5757 --nnodes 1 --node-rank 0 --tp-size 8 --dp-size 8 --enable-dp-attention --decode-log-interval 1 --enable-deepep-moe --page-size 1 --host 0.0.0.0 --trust-remote-code --moe-dense-tp-size 1 --enable-dp-lm-head --disable-radix-cache --watchdog-timeout 1000000 --disable-overlap-schedule --deepep-mode low_latency --mem-fraction-static 0.835 --max-running-requests 2048 --context-length 4500 --cuda-graph-bs 256

## 启动load-balancer
### g0021
python3 -m sglang.srt.disaggregation.mini_lb --prefill "http://172.16.21.80:30000" --decode "http://172.16.21.86:30000"

## benchmark脚本
python3 -m sglang.bench_one_batch_server --model-path /ssd/DeepSeek-R1  --base-url http://172.16.21.80:8000 --batch-size 8192 --input-len 4096 --output-len 128 --skip-warmup 

## start profile prefill instance
## 注意自行设置output_dir(trace路径)!!!!!
curl -X POST http://172.16.21.80:30000/start_profile \
  -H "Content-Type: application/json" \
  -d '{
    "output_dir": "xxxxx",
    "num_steps": 5,
    "record_shapes": true
  }'
```
### decode
* 三机作为D结点，一机作为P结点
```bash
## for prefill
## 假设选取g0021作为P结点

## 启动prefill server
### g0021
MC_TE_METRIC=true SGLANG_TBO_DEBUG=1 python3 -m sglang.launch_server --model-path /ssd/DeepSeek-R1 --disaggregation-ib-device mlx5_0,mlx5_1,mlx5_3,mlx5_4 --disaggregation-mode prefill --dist-init-addr 172.16.21.80:5757 --nnodes 1 --node-rank 0 --tp-size 8 --dp-size 8 --enable-dp-attention --decode-log-interval 1 --enable-deepep-moe --page-size 1 --host 0.0.0.0 --trust-remote-code --moe-dense-tp-size 1 --enable-dp-lm-head --disable-radix-cache --watchdog-timeout 1000000 --deepep-mode normal --mem-fraction-static 0.85 --chunked-prefill-size 131072 --max-running-requests 2048 --max-total-tokens 131072 --context-length 8192 --disable-overlap-schedule

## 假设选取g0009,g0018,g0027作为decode结点，其中g0027(172.16.21.86)为主节点
### g0027
NVSHMEM_HCA_LIST=mlx5_0,mlx5_1,mlx5_3,mlx5_4 SGLANG_NUM_RESERVED_DECODE_TOKENS=102 MC_TE_METRIC=true SGLANG_TBO_DEBUG=1 python3 -m sglang.launch_server --model-path /ssd/DeepSeek-R1 --disaggregation-ib-device mlx5_0,mlx5_1,mlx5_3,mlx5_4 --disaggregation-mode decode --dist-init-addr 172.16.21.86:5757 --nnodes 3 --node-rank 0 --tp-size 24 --dp-size 24 --enable-dp-attention --decode-log-interval 1 --enable-deepep-moe --page-size 1 --host 0.0.0.0 --trust-remote-code --moe-dense-tp-size 1 --enable-dp-lm-head --disable-radix-cache --watchdog-timeout 1000000 --enable-two-batch-overlap --deepep-mode low_latency --mem-fraction-static 0.8 --max-running-requests 6144 --context-length 4500 --cuda-graph-bs 128 --ep-num-redundant-experts 32

### g0009,g0018
修改上面指令中的--node-rank即可

## 启动load-balancer
### g0021
python3 -m sglang.srt.disaggregation.mini_lb --prefill "http://172.16.21.80:30000" --decode "http://172.16.21.86:30000"

## slow down decode instance
### 这里我们需要测试decode阶段的性能，需要保证decode instance有足够多的request待处理
curl -H "Content-Type: application/json" -d '{"forward_sleep_time": 90.0}' -X POST "http://172.16.21.86:30000/slow_down"

## benchmark脚本
python3 -m sglang.bench_one_batch_server --model-path /ssd/DeepSeek-R1  --base-url http://172.16.21.86:8000 --batch-size 9000 --input-len 4000 --output-len 100 --skip-warmup

## after some time, the D nodes are saturated, then this command should be executed
## finish slowing down D nodes
curl -H "Content-Type: application/json" -d '{"forward_sleep_time": null}' -X POST "http://172.16.21.86:30000/slow_down"

## start profile decode instance
## 注意自行设置output_dir(trace路径)!!!!!
curl -X POST http://172.16.21.86:30000/start_profile \
  -H "Content-Type: application/json" \
  -d '{
    "output_dir": "xxxxxx",
    "num_steps": 10,
    "record_shapes": true
  }'
```
## 复现性能查看方式
* 不要去看benchmark script outputs!!!(原因sglang blog中有详细说明)
* server logs会给出少量信息，例如gap_latency，throught put等，粒度比较差，可以略作参考
* 主要通过可视化分析profile得到的trace即可，可以得到各算子对应的性能
  * 注：当前复现主要基于pytorch profiler，分析算子性能也可采用cuda profiler，sglang也有支持，修改profile对应的脚本参数即可
  * 注：decode阶段two batch overlap不是很稳定，主要分析其中稳定部分
  * 注：如有需要可以联系我提供参考trace
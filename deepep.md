单机intranode均能跑通
11机 low_latency卡死

g0002 g0004 g0006 g0009 low latency卡死（跑了10min还卡在Allocating buffer size: 2115.111296 MB ... ）
g0002 g0004 g0006 low latency正常
g0002 g0004 g0009 low latency正常
g0002 g0006 g0009 low latency正常
g0004 g0006 g0009 low latency正常

g0002 g0004 g0006 g0017 low latency卡死（跑了10min还卡在Allocating buffer size: 2115.111296 MB ... ）
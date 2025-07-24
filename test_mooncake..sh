# g0021,use http-python
./transfer_engine_bench --mode=target --metadata_server=http://g0021:8080/metadata --device_name=mlx5_0,mlx5_1,mlx5_3,mlx5_4   

# g0018
./transfer_engine_bench --metadata_server=http://g0021:8080/metadata --segment_id=g0021 --device_name=mlx5_0,mlx5_1,mlx5_3,mlx5_4   

# I0722 02:00:03.725140 2543054 transfer_engine_bench.cpp:352] Test completed: duration 10.00, batch count 196316, throughput 164.66 GB/s                                             


DP3 TP3
DP11 TP11
DP19 TP19
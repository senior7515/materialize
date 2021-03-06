# Copyright Materialize, Inc. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.

# Test the creation and removal of entries in mz_kafka_consumer_partitions

$ set schema={
    "type": "record",
    "name": "row",
    "fields": [
      {"name": "a", "type": "long"},
      {"name": "b", "type": "long"}
    ]
  }

$ kafka-create-topic topic=data

> CREATE SOURCE data
  FROM KAFKA BROKER '${testdrive.kafka-addr}' TOPIC 'testdrive-data-${testdrive.seed}'
  FORMAT AVRO USING SCHEMA '${schema}'

> CREATE MATERIALIZED VIEW test1 AS
  SELECT b, sum(a) FROM data GROUP BY b

> SELECT * FROM test1
b  sum
------

$ kafka-ingest format=avro topic=data schema=${schema} timestamp=1
{"a": 1, "b": 1}
{"a": 2, "b": 1}
{"a": 3, "b": 1}
{"a": 1, "b": 2}

> SELECT * FROM test1
b  sum
------
1  6
2  1

# There should only be metrics from a single consumer / partition
> SELECT count(*) FROM mz_kafka_consumer_partitions
1

# We should have read 4 messages
> SELECT count(*) FROM mz_kafka_consumer_partitions where rx_msgs = 4
1

# and they should have non-zero bytes
> SELECT count(*) FROM mz_kafka_consumer_partitions where rx_bytes = 0
0

# We have not transmitted anything
> SELECT count(*) FROM mz_kafka_consumer_partitions where tx_msgs = 0
1

> SELECT count(*) FROM mz_kafka_consumer_partitions where tx_bytes = 0
1

# Lo Offset should not exceed Hi offset
> SELECT count(*) FROM mz_kafka_consumer_partitions where lo_offset > hi_offset
0

# Lo Offset should not exceed Ls offset
> SELECT count(*) FROM mz_kafka_consumer_partitions where lo_offset > ls_offset
0

# Ls Offset should not exceed Hi Offset
> SELECT count(*) FROM mz_kafka_consumer_partitions where ls_offset > hi_offset
0

# We should have read 4 records
> SELECT count(*) FROM mz_kafka_consumer_partitions where app_offset = 4
1

# And we should not be lagging
> SELECT count(*) FROM mz_kafka_consumer_partitions where consumer_lag = 0
1

# If we change the message encoding and/or the broker version, these results may change
> SELECT partition_id, rx_msgs, rx_bytes, tx_msgs, tx_bytes, lo_offset, hi_offset, ls_offset, app_offset, consumer_lag FROM mz_kafka_consumer_partitions;
partition_id  rx_msgs  rx_bytes  tx_msgs  tx_bytes  lo_offset  hi_offset  ls_offset  app_offset  consumer_lag
-------------------------------------------------------------------------------------------------------------
0  4  28  0  0  0  4  4  4 0

# Verify that we can join against mz_source_info
> SELECT mz_kafka_consumer_partitions.rx_msgs FROM mz_kafka_consumer_partitions INNER JOIN mz_source_info USING (source_id, dataflow_id, partition_id) WHERE mz_source_info.source_name like 'testdrive-data-%%';
rx_msgs
-------
4

# Just assert that our source created a metrics object for one broker
# RTT metrics are all timing dependent and there's no method to assert on the values
# The broker name cannot be easily determined due to differences in test environments
> SELECT count(*) FROM mz_kafka_broker_rtt WHERE broker_name IS NOT NULL AND broker_name != '';
count
-----
1

> SELECT value FROM mz_metrics
  WHERE metric = 'mz_kafka_partition_offset_max' AND labels->>'topic' = 'testdrive-data-${testdrive.seed}'
  ORDER BY time DESC LIMIT 1
0

> SELECT value FROM mz_metrics
  WHERE metric = 'mz_partition_offset_received' AND labels->>'topic' = 'testdrive-data-${testdrive.seed}'
  ORDER BY time DESC LIMIT 1
4

# Drop the sources and verify that metrics have been removed
> DROP VIEW test1

> DROP SOURCE data

> SELECT count(*) FROM mz_kafka_consumer_partitions
0

> SELECT count(*) FROM mz_kafka_broker_rtt;
0

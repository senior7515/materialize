# Copyright Materialize, Inc. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.

#
# Make sure that the ENUM type is replicated correctly
#

$ postgres-execute connection=postgres://postgres:postgres@postgres
CREATE TYPE enum1 AS ENUM ('val1', 'val2');
CREATE TABLE enum_type ( f1 enum1);
INSERT INTO enum_type VALUES ('val1'), ('val2');

> CREATE MATERIALIZED SOURCE enum_type
  FROM KAFKA BROKER '${testdrive.kafka-addr}' TOPIC 'postgres.public.enum_type'
  FORMAT AVRO USING CONFLUENT SCHEMA REGISTRY '${testdrive.schema-registry-url}'
  ENVELOPE DEBEZIUM;

> SELECT pg_typeof(f1), f1 FROM enum_type;
text val1
text val2

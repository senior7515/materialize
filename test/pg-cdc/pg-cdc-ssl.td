# Copyright Materialize, Inc. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.

# We test interesting combinations of server and client SSL configs
# (part of the CREATE SOURCE statement).
#
# The important bit is that each user is named after the record type
# in `pg_hba.conf`. The record type indicates what kind of connection
# is allowed, e.g. `host` allows SSL and plaintext whereas `hostssl`
# only allows SSL.
#
# Check out https://www.postgresql.org/docs/13/auth-pg-hba-conf.html
# for more details.

# Bootstrap users and data
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

DROP USER IF EXISTS host;
CREATE USER host LOGIN SUPERUSER;

DROP USER IF EXISTS hostssl;
CREATE USER hostssl LOGIN SUPERUSER;

DROP USER IF EXISTS hostnossl;
CREATE USER hostnossl LOGIN SUPERUSER;

DROP TABLE IF EXISTS numbers;
CREATE TABLE numbers (number int PRIMARY KEY, is_prime bool, name text);
ALTER TABLE numbers REPLICA IDENTITY FULL;

DROP PUBLICATION IF EXISTS mz_source;
CREATE PUBLICATION mz_source FOR ALL TABLES;

INSERT INTO numbers VALUES (1, true, 'one');

$ set-regex match=(\d{1,3}\.){3}\d{1,3} replacement=(HOST)

# server: host, client: disable => OK
> CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=host sslmode=disable dbname=postgres'
  PUBLICATION 'mz_source';
> CREATE VIEWS FROM SOURCE "mz_source" ("numbers")
> SELECT * FROM "numbers";
1 true one
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
INSERT INTO numbers VALUES (2, true, 'two');
> SELECT * FROM "numbers";
1 true one
2 true two
> DROP VIEW "numbers";
> DROP SOURCE "mz_source";
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
DELETE FROM numbers WHERE number = 2;

# server: host, client: prefer => OK
> CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=host sslmode=prefer dbname=postgres'
  PUBLICATION 'mz_source';
> CREATE VIEWS FROM SOURCE "mz_source" ("numbers")
> SELECT * FROM "numbers";
1 true one
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
INSERT INTO numbers VALUES (2, true, 'two');
> SELECT * FROM "numbers";
1 true one
2 true two
> DROP VIEW "numbers";
> DROP SOURCE "mz_source";
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
DELETE FROM numbers WHERE number = 2;

# server: host, client: require => OK
> CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=host sslmode=require dbname=postgres'
  PUBLICATION 'mz_source';
> CREATE VIEWS FROM SOURCE "mz_source" ("numbers")
> SELECT * FROM "numbers";
1 true one
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
INSERT INTO numbers VALUES (2, true, 'two');
> SELECT * FROM "numbers";
1 true one
2 true two
> DROP VIEW "numbers";
> DROP SOURCE "mz_source";
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
DELETE FROM numbers WHERE number = 2;

# server: hostssl, client: disable => ERROR
! CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=hostssl sslmode=disable dbname=postgres'
  PUBLICATION 'mz_source';
db error: FATAL: no pg_hba.conf entry for host "(HOST)", user "hostssl", database "postgres", SSL off

# server: hostssl, client: prefer => OK
> CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=hostssl sslmode=prefer dbname=postgres'
  PUBLICATION 'mz_source';
> CREATE VIEWS FROM SOURCE "mz_source" ("numbers")
> SELECT * FROM "numbers";
1 true one
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
INSERT INTO numbers VALUES (2, true, 'two');
> SELECT * FROM "numbers";
1 true one
2 true two
> DROP VIEW "numbers";
> DROP SOURCE "mz_source";
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
DELETE FROM numbers WHERE number = 2;

# server: hostssl, client: require => OK
> CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=hostssl sslmode=require dbname=postgres'
  PUBLICATION 'mz_source';
> CREATE VIEWS FROM SOURCE "mz_source" ("numbers")
> SELECT * FROM "numbers";
1 true one
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
INSERT INTO numbers VALUES (2, true, 'two');
> SELECT * FROM "numbers";
1 true one
2 true two
> DROP VIEW "numbers";
> DROP SOURCE "mz_source";
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
DELETE FROM numbers WHERE number = 2;

# server: hostnossl, client: disable => OK
> CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=hostnossl sslmode=disable dbname=postgres'
  PUBLICATION 'mz_source';
> CREATE VIEWS FROM SOURCE "mz_source" ("numbers")
> SELECT * FROM "numbers";
1 true one
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
INSERT INTO numbers VALUES (2, true, 'two');
> SELECT * FROM "numbers";
1 true one
2 true two
> DROP VIEW "numbers";
> DROP SOURCE "mz_source";
$ postgres-execute connection=postgres://postgres:postgres@postgres:5432
DELETE FROM numbers WHERE number = 2;

# server: hostnossl, client: prefer => OK
# todo(uce): rust-postgres does not fall back to no SSL
! CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=hostnossl sslmode=prefer dbname=postgres'
  PUBLICATION 'mz_source';
db error: FATAL: no pg_hba.conf entry for host "(HOST)", user "hostnossl", database "postgres", SSL on

# server: hostnossl, client: require => ERROR
! CREATE MATERIALIZED SOURCE "mz_source"
  FROM POSTGRES HOST 'host=postgres port=5432 user=hostnossl sslmode=require dbname=postgres'
  PUBLICATION 'mz_source';
db error: FATAL: no pg_hba.conf entry for host "(HOST)", user "hostnossl", database "postgres", SSL on

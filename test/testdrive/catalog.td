# Copyright Materialize, Inc. and contributors. All rights reserved.
#
# Use of this software is governed by the Business Source License
# included in the LICENSE file at the root of this repository.
#
# As of the Change Date specified in that file, in accordance with
# the Business Source License, use of this software will be governed
# by the Apache License, Version 2.0.

$ set-sql-timeout duration=1s

# Test \d <object> command
> CREATE TABLE tbl (a int, b text)

> CREATE INDEX tbl_ind ON tbl (b)

> CREATE INDEX tbl_lower_ind ON tbl (lower(b), a)

$ psql-execute command="\d tbl"
\                Table "public.tbl"
 Column |  Type   | Collation | Nullable | Default
--------+---------+-----------+----------+---------
 a      | integer |           |          | NULL
 b      | text    |           |          | NULL
Indexes:
    "tbl_ind" arrangement (b)
    "tbl_lower_ind" arrangement (pg_catalog.lower(b),a)

> DROP TABLE tbl CASCADE

# What schemas do we have by default?
> SHOW SCHEMAS FROM materialize
public
information_schema
mz_catalog
mz_internal
pg_catalog
> SHOW SCHEMAS
name
------------------
information_schema
public
mz_catalog
mz_internal
pg_catalog
$ psql-execute command=\dn
\   List of schemas
    Name     | Owner
-------------+-------
 mz_catalog  |
 mz_internal |
 public      |

$ psql-execute command="\dn mz_catalog"
\  List of schemas
    Name    | Owner
------------+-------
 mz_catalog |


$ psql-execute command="\dn mz_*"
\   List of schemas
    Name     | Owner
-------------+-------
 mz_catalog  |
 mz_internal |

# What objects do we have by default?
> SHOW OBJECTS
name    type
-------------

# Creating a schema should be reflected in the output of SHOW SCHEMAS.
> CREATE SCHEMA s
> SHOW SCHEMAS
name
------------------
public
s
information_schema
mz_catalog
mz_internal
pg_catalog


# Creating a schema with a name that already exists should fail.
! CREATE SCHEMA s
contains:schema 's' already exists

# Dropping a schema with a view should only succeed with CASCADE.
> CREATE VIEW s.v AS SELECT 1
! DROP SCHEMA s
contains:schema 'materialize.s' cannot be dropped without CASCADE while it contains objects
> DROP SCHEMA s CASCADE

# Dropping a schema with no objects should succeed without CASCADE.
> CREATE SCHEMA s
> CREATE VIEW s.v AS SELECT 1
> DROP VIEW s.v
> DROP SCHEMA s

# What databases do we have by default?
> SHOW DATABASES
name
------------
materialize

> SELECT name FROM mz_databases
name
-----------
materialize

# Creating a database should be reflected in the output of SHOW DATABASES.
> CREATE DATABASE d
> SHOW DATABASES
name
-----------
d
materialize

# ...and also in `\l`
$ psql-execute command="\l"
\                          List of databases
    Name     | Owner | Encoding | Collate | Ctype | Access privileges
-------------+-------+----------+---------+-------+-------------------
 d           |       | UTF8     | C       | C     |
 materialize |       | UTF8     | C       | C     |


> SELECT name FROM mz_databases
name
-----------
materialize
d

# The same catalog information should be accessible with any amount of
# database or schema qualification.
> SELECT count(*) FROM materialize.mz_catalog.mz_databases
2
> SELECT count(*) FROM d.mz_catalog.mz_databases
2

# SHOW DATABASES should filter its output according to the provided LIKE or
# WHERE clause.
> SHOW DATABASES LIKE 'foo'
> SHOW DATABASES LIKE 'd'
d
> SHOW DATABASES LIKE 'mat%'
materialize
> SHOW DATABASES WHERE (SELECT name = name)
materialize
d
> SHOW DATABASES WHERE (name = (SELECT min(name) FROM mz_databases))
d
! SHOW DATABASES WHERE 7
contains:WHERE clause must have type boolean, not type integer

# Creating a database with a name that already exists should fail.
! CREATE DATABASE d
contains:database 'd' already exists

# The new database should have a default public schema.
> SHOW SCHEMAS FROM d
name
------------------
public
information_schema
mz_catalog
mz_internal
pg_catalog

# New schemas in the database should appear in the output of SHOW SCHEMAS FROM.
> CREATE SCHEMA d.s
> SHOW SCHEMAS FROM d
name
-------------------
public
s
information_schema
mz_catalog
mz_internal
pg_catalog

# SHOW SCHEMAS should filter its output based on the provided LIKE or WHERE
# clause.
> SHOW SCHEMAS LIKE 'pub%'
public
> SHOW SCHEMAS LIKE 'private'
> SHOW SCHEMAS WHERE name = 'public'
public

# New views in the database should work.
> CREATE VIEW d.public.v1 AS SELECT 1
> SHOW VIEWS FROM d.public
name
----
v1

# Setting the session database should update name resolution appropriately.
> SET DATABASE = d
> SHOW DATABASE
d
> SHOW SCHEMAS
public
s
information_schema
mz_catalog
mz_internal
pg_catalog
> CREATE VIEW v2 AS SELECT 2
> SHOW VIEWS
v1
v2
> SELECT * FROM v1 UNION ALL SELECT * FROM v2
1
2

> SHOW OBJECTS
name    type
-------------
v1      view
v2      view

# Test minimizing name qualification

> CREATE TYPE int_list AS list (ELEMENT TYPE = int4)

> SELECT pg_typeof('{1}'::d.public.int_list)
int_list

> CREATE SCHEMA other
> CREATE TYPE other.int_list AS list (ELEMENT TYPE = int4)
> SELECT pg_typeof('{1}'::d.other.int_list)
other.int_list

> CREATE DATABASE foo
> CREATE SCHEMA foo.other
> CREATE TYPE foo.other.int_list AS LIST (ELEMENT TYPE = int4)
> SELECT pg_typeof('{1}'::foo.other.int_list)
foo.other.int_list

> CREATE TYPE bool AS LIST (ELEMENT TYPE = int4)
! SELECT '{1}'::bool
contains:invalid input syntax for type boolean: "{1}"

> SELECT pg_typeof('{1}'::public.bool);
public.bool

> SELECT pg_typeof('{1}'::d.public.bool);
public.bool

> DROP DATABASE foo

! DROP OBJECT v1
contains:Expected one of CONNECTION or CLUSTER or DATABASE or INDEX or MATERIALIZED or ROLE or SECRET or SCHEMA or SINK or SOURCE or TABLE or TYPE or USER or VIEW, found identifier

> SHOW OBJECTS
name        type
-----------------
bool        type
int_list    type
v1          view
v2          view

# Create one of every mz_object type
$ set schema={
    "name": "row",
    "type": "record",
    "fields": [
      {"name": "a", "type": "long"}
    ]
  }
$ kafka-create-topic topic=data
$ kafka-ingest format=avro topic=data schema=${schema} timestamp=1
{"a": 1}

> CREATE TABLE tbl (a int, b text);
> CREATE SECRET pass_secret AS 'pass';

> CREATE CONNECTION IF NOT EXISTS csr_conn TO CONFLUENT SCHEMA REGISTRY (
    URL '${testdrive.schema-registry-url}'
  );

> CREATE MATERIALIZED VIEW mv AS SELECT (1);

> CREATE CONNECTION kafka_conn
  TO KAFKA (BROKER '${testdrive.kafka-addr}');

> CREATE SOURCE source_data
  FROM KAFKA CONNECTION kafka_conn (TOPIC 'testdrive-data-${testdrive.seed}')
  FORMAT AVRO USING CONFLUENT SCHEMA REGISTRY CONNECTION csr_conn;
> CREATE SINK snk FROM source_data
  INTO KAFKA CONNECTION kafka_conn (TOPIC 'testdrive-catalog-sink-${testdrive.seed}')
  FORMAT AVRO USING CONFLUENT SCHEMA REGISTRY CONNECTION csr_conn
  ENVELOPE DEBEZIUM;

> SHOW OBJECTS
name        type
----------------
bool        type
csr_conn    connection
int_list    type
v1          view
v2          view
tbl         table
pass_secret secret
kafka_conn  connection
mv          materialized-view
source_data source
source_data_progress source
snk         sink

> SELECT DISTINCT(TYPE) FROM mz_objects
type
----
table
source
view
materialized-view
sink
index
connection
type
function
secret

> SELECT * FROM (SHOW OBJECTS) ORDER BY name DESC
bool        type
csr_conn    connection
int_list    type
kafka_conn  connection
mv          materialized-view
pass_secret secret
snk         sink
source_data source
source_data_progress source
tbl         table
v1          view
v2          view

> SELECT create_sql FROM (SHOW CREATE TABLE tbl)
"CREATE TABLE \"d\".\"public\".\"tbl\" (\"a\" \"pg_catalog\".\"int4\", \"b\" \"pg_catalog\".\"text\")"

! SHOW COLUMNS FROM pass_secret
contains:d.public.pass_secret is a secret and so does not have columns
! SHOW COLUMNS FROM kafka_conn
contains:d.public.kafka_conn is a connection and so does not have columns

# DROP DATABASE does not support both RESTRICT and CASCADE.
! DROP DATABASE d RESTRICT CASCADE
contains:Cannot specify both RESTRICT and CASCADE in DROP
! DROP DATABASE d CASCADE RESTRICT
contains:Cannot specify both CASCADE and RESTRICT in DROP
! DROP DATABASE d CASCADE CASCADE
contains:Expected end of statement, found CASCADE

! DROP DATABASE d RESTRICT
contains:database 'd' cannot be dropped with RESTRICT while it contains schemas

# DROP DATABASE should succeed even when there are objects in the database.
> DROP DATABASE d
# SHOW DATABASES should work, even if the current database has been dropped.
> SHOW DATABASES
name
-----------
materialize

> SELECT name FROM mz_databases
name
-----------
materialize

# The session database should remain set to the dropped database, but future
# queries that depend on the session database should fail with sensible error
# messages.
> SHOW DATABASE
d
! SELECT * FROM v
contains:unknown catalog item 'v'

# But queries that do not depend on the session database should work fine.
> CREATE VIEW materialize.public.v AS SELECT 1
> CREATE DATABASE d

# Dropping the public schema is okay, but dropping the catalog schemas is not.
> DROP SCHEMA public
! DROP SCHEMA mz_catalog
contains:cannot drop schema mz_catalog because it is required by the database system
! DROP SCHEMA pg_catalog
contains:cannot drop schema pg_catalog because it is required by the database system

# Schema names that start with "mz_" or "pg_" are reserved for future use by the
# system.
! CREATE SCHEMA mz_foo
contains:unacceptable schema name 'mz_foo'
! CREATE SCHEMA pg_bar
contains:unacceptable schema name 'pg_bar'

# The search path is configurable.
> SHOW search_path
"public"
> SET search_path = foo
> SET SCHEMA foo
> SET search_path to public

# Creating views in non-existent databases should fail.
! CREATE VIEW noexist.ignored AS SELECT 1
contains:unknown schema 'noexist'
! CREATE VIEW materialize.noexist.ignored AS SELECT 1
contains:unknown schema 'noexist'
! CREATE VIEW noexist.ignored.ignored AS SELECT 1
contains:unknown database 'noexist'

# As should showing views.
! SHOW VIEWS FROM noexist
contains:unknown schema 'noexist'
! SHOW VIEWS FROM noexist_db.noexist_schema
contains:unknown database 'noexist_db'

# Dropping database with cross-schema dependencies is ok.
> CREATE DATABASE d1;
> CREATE SCHEMA d1.s1;
> CREATE VIEW d1.s1.t as select 1;
> CREATE VIEW d1.public.tt as select * from d1.s1.t;
> DROP DATABASE d1;

# Dropping database with cross-database dependencies is ok and drops the
# dependent views.
> CREATE DATABASE d1;
> CREATE VIEW d1.public.t as select 1;
> CREATE DATABASE d2;
> CREATE VIEW d2.public.t AS SELECT * FROM d1.public.t;
> DROP DATABASE d1;
> SHOW DATABASES
name
-----------
d
d2
materialize
> SELECT name FROM mz_databases
name
-----------
materialize
d
d2

> SHOW VIEWS FROM d2.public;
 name
-----

# Check default sources, tables, and views in mz_catalog.

> SHOW SOURCES FROM mz_catalog
name  type  size
----------------

> SHOW TABLES FROM mz_catalog
name
-----------------------------
mz_array_types
mz_audit_events
mz_aws_privatelink_connections
mz_base_types
mz_clusters
mz_cluster_replicas
mz_columns
mz_connections
mz_databases
mz_egress_ips
mz_functions
mz_index_columns
mz_indexes
mz_kafka_connections
mz_kafka_sinks
mz_list_types
mz_map_types
mz_materialized_views
mz_operators
mz_pseudo_types
mz_roles
mz_schemas
mz_secrets
mz_sinks
mz_sources
mz_ssh_tunnel_connections
mz_tables
mz_types
mz_views

> SHOW VIEWS FROM mz_catalog
name
-----------------------------------
mz_objects
mz_relations
mz_storage_usage

# Check default sources, tables, and views in mz_internal.

# The sources in the catalog depend on the number of replicas
$ skip-if
SELECT ${arg.replicas} > 1;

> SHOW SOURCES FROM mz_internal
name                                           type   size
------------------------------------------------------------
mz_arrangement_batches_internal                 log   <null>
mz_arrangement_records_internal                 log   <null>
mz_arrangement_sharing_internal                 log   <null>
mz_dataflow_channels                            log   <null>
mz_dataflow_addresses                           log   <null>
mz_dataflow_operator_reachability_internal      log   <null>
mz_dataflow_operators                           log   <null>
mz_worker_compute_dependencies                  log   <null>
mz_compute_exports                              log   <null>
mz_message_counts_received_internal             log   <null>
mz_message_counts_sent_internal                 log   <null>
mz_raw_peek_durations                           log   <null>
mz_raw_worker_compute_delays                    log   <null>
mz_active_peeks                                 log   <null>
mz_scheduling_elapsed_internal                  log   <null>
mz_raw_compute_operator_durations_internal      log   <null>
mz_scheduling_parks_internal                    log   <null>
mz_sink_status_history                          source <null>
mz_source_status_history                        source <null>
mz_source_statistics                            source <null>
mz_sink_statistics                              source <null>
mz_storage_shards                               source <null>
mz_worker_compute_frontiers                     log   <null>
mz_worker_compute_import_frontiers              log   <null>

> SHOW TABLES FROM mz_internal
name
----
mz_cluster_links
mz_cluster_replica_frontiers
mz_cluster_replica_heartbeats
mz_cluster_replica_metrics
mz_cluster_replica_sizes
mz_cluster_replica_statuses
mz_postgres_sources
mz_storage_usage_by_shard
mz_subscriptions
mz_view_foreign_keys
mz_view_keys
mz_object_dependencies

> SHOW VIEWS FROM mz_internal
name
-------------------------------------
mz_arrangement_sharing
mz_arrangement_sizes
mz_dataflows
mz_dataflow_channel_operators
mz_dataflow_operator_dataflows
mz_dataflow_operator_reachability
mz_cluster_replica_utilization
mz_compute_frontiers
mz_compute_import_frontiers
mz_compute_operator_durations
mz_message_counts
mz_peek_durations
mz_raw_compute_operator_durations
mz_records_per_dataflow
mz_records_per_dataflow_global
mz_records_per_dataflow_operator
mz_scheduling_elapsed
mz_scheduling_parks
mz_sink_statuses
mz_source_statuses
mz_worker_compute_delays
mz_show_cluster_replicas
mz_show_indexes
mz_show_materialized_views

> SET database = materialize

> CREATE SCHEMA tester

> SHOW TABLES FROM tester

> CREATE TABLE tester.test_table (a int)

> SHOW TABLES FROM tester
test_table

# `SHOW TABLES` and `mz_tables` should agree.
> SELECT COUNT(*) FROM mz_tables WHERE id LIKE 's%'
41

# There is one entry in mz_indexes for each field_number/expression of the index.
> SELECT COUNT(id) FROM mz_indexes WHERE id LIKE 's%'
72

# Create a second schema with the same table name as above
> CREATE SCHEMA tester2

> CREATE TABLE tester2.test_table (a int)

$ psql-execute command="\dt tester.*"
\          List of relations
 Schema |    Name    | Type  | Owner
--------+------------+-------+-------
 tester | test_table | table |

$ psql-execute command="\dt tester.test_table"
\          List of relations
 Schema |    Name    | Type  | Owner
--------+------------+-------+-------
 tester | test_table | table |

$ psql-execute command="\dt *.test_table"
\          List of relations
 Schema  |    Name    | Type  | Owner
---------+------------+-------+-------
 tester  | test_table | table |
 tester2 | test_table | table |

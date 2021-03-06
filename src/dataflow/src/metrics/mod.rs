// Copyright Materialize, Inc. All rights reserved.
//
// Use of this software is governed by the Business Source License
// included in the LICENSE file.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the Apache License, Version 2.0.

use lazy_static::lazy_static;

use prometheus::register_uint_gauge_vec;
use prometheus::UIntGaugeVec;
use prometheus::{register_int_counter_vec, IntCounterVec};
use prometheus_static_metric::make_static_metric;

make_static_metric! {
    pub struct EventsRead: IntCounter {
        "format" => { avro, csv, protobuf, raw, text, regex },
        "status" => { success, error }
    }
}

lazy_static! {
    static ref EVENTS_COUNTER_INTERNAL: IntCounterVec = register_int_counter_vec!(
        "mz_dataflow_events_read_total",
        "Count of events we have read from the wire",
        &["format", "status"]
    )
    .unwrap();
    pub static ref EVENTS_COUNTER: EventsRead = EventsRead::from(&EVENTS_COUNTER_INTERNAL);
    pub(crate) static ref DEBEZIUM_UPSERT_COUNT: UIntGaugeVec = register_uint_gauge_vec!(
        "mz_source_debezium_upsert_state_size",
        "The number of keys that we are tracking in an upsert map.",
        &["source_id", "worker_id"]
    )
    .unwrap();
}

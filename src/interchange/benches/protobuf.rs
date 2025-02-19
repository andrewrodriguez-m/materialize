// Copyright Materialize, Inc. and contributors. All rights reserved.
//
// Use of this software is governed by the Business Source License
// included in the LICENSE file.
//
// As of the Change Date specified in that file, in accordance with
// the Business Source License, use of this software will be governed
// by the Apache License, Version 2.0.

// BEGIN LINT CONFIG
// DO NOT EDIT. Automatically generated by bin/gen-lints.
// Have complaints about the noise? See the note in misc/python/materialize/cli/gen-lints.py first.
#![allow(clippy::style)]
#![allow(clippy::complexity)]
#![allow(clippy::large_enum_variant)]
#![allow(clippy::mutable_key_type)]
#![allow(clippy::stable_sort_primitive)]
#![allow(clippy::map_entry)]
#![allow(clippy::box_default)]
#![warn(clippy::bool_comparison)]
#![warn(clippy::clone_on_ref_ptr)]
#![warn(clippy::no_effect)]
#![warn(clippy::unnecessary_unwrap)]
#![warn(clippy::dbg_macro)]
#![warn(clippy::todo)]
#![warn(clippy::wildcard_dependencies)]
#![warn(clippy::zero_prefixed_literal)]
#![warn(clippy::borrowed_box)]
#![warn(clippy::deref_addrof)]
#![warn(clippy::double_must_use)]
#![warn(clippy::double_parens)]
#![warn(clippy::extra_unused_lifetimes)]
#![warn(clippy::needless_borrow)]
#![warn(clippy::needless_question_mark)]
#![warn(clippy::needless_return)]
#![warn(clippy::redundant_pattern)]
#![warn(clippy::redundant_slicing)]
#![warn(clippy::redundant_static_lifetimes)]
#![warn(clippy::single_component_path_imports)]
#![warn(clippy::unnecessary_cast)]
#![warn(clippy::useless_asref)]
#![warn(clippy::useless_conversion)]
#![warn(clippy::builtin_type_shadow)]
#![warn(clippy::duplicate_underscore_argument)]
#![warn(clippy::double_neg)]
#![warn(clippy::unnecessary_mut_passed)]
#![warn(clippy::wildcard_in_or_patterns)]
#![warn(clippy::collapsible_if)]
#![warn(clippy::collapsible_else_if)]
#![warn(clippy::crosspointer_transmute)]
#![warn(clippy::excessive_precision)]
#![warn(clippy::overflow_check_conditional)]
#![warn(clippy::as_conversions)]
#![warn(clippy::match_overlapping_arm)]
#![warn(clippy::zero_divided_by_zero)]
#![warn(clippy::must_use_unit)]
#![warn(clippy::suspicious_assignment_formatting)]
#![warn(clippy::suspicious_else_formatting)]
#![warn(clippy::suspicious_unary_op_formatting)]
#![warn(clippy::mut_mutex_lock)]
#![warn(clippy::print_literal)]
#![warn(clippy::same_item_push)]
#![warn(clippy::useless_format)]
#![warn(clippy::write_literal)]
#![warn(clippy::redundant_closure)]
#![warn(clippy::redundant_closure_call)]
#![warn(clippy::unnecessary_lazy_evaluations)]
#![warn(clippy::partialeq_ne_impl)]
#![warn(clippy::redundant_field_names)]
#![warn(clippy::transmutes_expressible_as_ptr_casts)]
#![warn(clippy::unused_async)]
#![warn(clippy::disallowed_methods)]
#![warn(clippy::disallowed_macros)]
#![warn(clippy::disallowed_types)]
#![warn(clippy::from_over_into)]
// END LINT CONFIG

use criterion::{black_box, Criterion, Throughput};
use prost::Message;

use mz_interchange::protobuf::{DecodedDescriptors, Decoder};
use mz_ore::cast::CastFrom;

use self::gen::benchmark::{Connector, Record, Value};

mod gen {
    include!(concat!(env!("OUT_DIR"), "/mod.rs"));
}

pub fn bench_protobuf(c: &mut Criterion) {
    let value = Value {
        l_orderkey: 155_190,
        l_suppkey: 7706,
        l_linenumber: 1,
        l_quantity: 17.0,
        l_extendedprice: 21168.23,
        l_discount: 0.04,
        l_tax: 0.02,
        l_returnflag: "N".into(),
        l_linestatus: "O".into(),
        l_shipdate: 9567,
        l_commitdate: 9537,
        l_receiptdate: 9537,
        l_shipinstruct: "DELIVER IN PERSON".into(),
        l_shipmode: "TRUCK".into(),
        l_comment: "egular courts above the".into(),
        ..Default::default()
    };

    let connector = Connector {
        version: "0.9.5.Final".into(),
        connector: "mysql".into(),
        name: "tcph".into(),
        server_id: 0,
        ts_sec: 0,
        gtid: "".into(),
        file: "binlog.000004".into(),
        pos: 951_896_181,
        row: 0,
        snapshot: true,
        thread: 0,
        db: "tcph".into(),
        table: "lineitem".into(),
        query: "".into(),
    };

    let record = Record {
        tcph_tcph_lineitem_value: Some(value),
        source: Some(connector),
        op: "c".into(),
        ts_ms: 1_560_886_948_093,
    };

    let buf = record.encode_to_vec();
    let len = u64::cast_from(buf.len());
    let mut decoder = Decoder::new(
        DecodedDescriptors::from_bytes(
            &include_bytes!(concat!(env!("OUT_DIR"), "/file_descriptor_set.pb"))[..],
            ".benchmark.Record".to_string(),
        )
        .unwrap(),
        false,
    )
    .unwrap();

    let mut bg = c.benchmark_group("protobuf");
    bg.throughput(Throughput::Bytes(len));
    bg.bench_function("decode", move |b| {
        b.iter(|| black_box(decoder.decode(&buf).unwrap()))
    });
    bg.finish();
}
